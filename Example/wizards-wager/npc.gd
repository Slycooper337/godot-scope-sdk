extends CharacterBody2D

# NPCs are simulated by the authoritative world server. This script only
# presents server state, using the same 36px frame layout and animation sequence
# as the player, under the dedicated npc_* animation names.
const MOB_FOOT_OFFSET_Y := 78.35
const FRAME_SIZE := Vector2(36.0, 36.0)
const CHARACTER_SHEET_DIRECTORY := "res://assets/NPCSHEETS"
const ANIMATION_ROWS := {
	"npc_walk": {"y": 0, "frames": 6, "loop": true},
	"npc_idle": {"y": 36, "frames": 6, "loop": true},
	"npc_attack": {"y": 108, "frames": 8, "loop": false},
	"npc_hit": {"y": 180, "frames": 3, "loop": false},
	"npc_die": {"y": 216, "frames": 8, "loop": false},
	"npc_power_up": {"y": 252, "frames": 10, "loop": false}
}

@export var snapshot_render_delay := 0.12
@export var max_snapshot_extrapolation := 0.2

@onready var visual: AnimatedSprite2D = $Visual
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var enemy_collision: CollisionShape2D = $EnemyArea/EnemyCollision
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var damage_label_template: Label = $DamageLabel

var server_mob_id := ""
var visual_id := ""
var health := 0
var max_health := 0
var dying := false
var server_position_initialized := false
var snapshot_buffer: Array[Dictionary] = []
var server_velocity := Vector2.ZERO
var last_damage_health := -1
var last_damage_attack_id := ""
var faction_id := "neutral"
var relationship_to_player := "neutral"
var attack_legal := false
var reputation_effects: Dictionary = {}
var death_tween: Tween = null


func _ready() -> void:
	damage_label_template.visible = false
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	visual.animation_finished.connect(_on_visual_animation_finished)


func _physics_process(_delta: float) -> void:
	# The backend is the only NPC movement and combat simulator.
	pass


func _process(_delta: float) -> void:
	if dying or not server_position_initialized or snapshot_buffer.is_empty():
		return
	var now_seconds := float(Time.get_ticks_msec()) / 1000.0
	var render_time := now_seconds - snapshot_render_delay
	var rendered := _sample_render_state(render_time)
	global_position = rendered["position"] as Vector2
	server_velocity = rendered["velocity"] as Vector2
	velocity = server_velocity
	_apply_visual_state(str(rendered["state"]), int(rendered["facing"]))


func set_server_authoritative(mob_id: String) -> void:
	server_mob_id = mob_id
	dying = false
	last_damage_health = -1
	last_damage_attack_id = ""
	snapshot_buffer.clear()
	server_position_initialized = false
	body_collision.set_deferred("disabled", false)
	enemy_collision.set_deferred("disabled", false)
	set_physics_process(false)


func get_server_mob_id() -> String:
	return server_mob_id


func set_visual_id(incoming_visual_id: String) -> void:
	if incoming_visual_id.is_empty() or incoming_visual_id == visual_id:
		return
	var sheet_path := _resolve_visual_sheet_path(incoming_visual_id)
	if sheet_path.is_empty():
		push_warning("[NPC] Unknown visual_id=%s for %s" % [incoming_visual_id, server_mob_id])
		return
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		push_error("[NPC] Could not load NPC sheet: %s" % sheet_path)
		return
	visual_id = incoming_visual_id
	visual.sprite_frames = _create_character_sprite_frames(sheet)
	visual.play(&"npc_idle")


func _resolve_visual_sheet_path(incoming_visual_id: String) -> String:
	var normalized_id := incoming_visual_id.to_snake_case()
	for file_name in DirAccess.get_files_at(CHARACTER_SHEET_DIRECTORY):
		if not file_name.to_lower().ends_with(".png"):
			continue
		if file_name.get_basename().to_snake_case() == normalized_id:
			return CHARACTER_SHEET_DIRECTORY.path_join(file_name)
	return ""


func apply_server_snapshot(data: Dictionary, snapshot_received_at: float = -1.0) -> void:
	faction_id = str(data.get("faction_id", faction_id))
	relationship_to_player = str(data.get("relationship_to_player", data.get("relationship", relationship_to_player)))
	attack_legal = bool(data.get("attack_legal", data.get("player_attack_legal", attack_legal)))
	var reputation_value: Variant = data.get("reputation_effects", data.get("reputation_on_kill", {}))
	if reputation_value is Dictionary:
		reputation_effects = (reputation_value as Dictionary).duplicate(true)
	show()
	visual.show()
	visual.modulate.a = 1.0
	var incoming_state := str(data.get("state", "")).to_lower()
	var incoming_alive := bool(data.get("alive", true))
	var incoming_respawning := incoming_state in ["respawning", "spawned"]
	if dying and (incoming_alive or incoming_respawning) and incoming_state not in ["dead", "death"]:
		dying = false
		body_collision.set_deferred("disabled", false)
		enemy_collision.set_deferred("disabled", false)
		server_position_initialized = false
		snapshot_buffer.clear()
	set_visual_id(str(data.get("visual_id", data.get("mob_type", ""))).to_lower())
	var position_value: Variant = data.get("position", {})
	if position_value is Dictionary:
		var position_data: Dictionary = position_value
		var foot_position := Vector2(float(position_data.get("x", global_position.x)), float(position_data.get("y", global_position.y + MOB_FOOT_OFFSET_Y)))
		var snapshot_position := Vector2(foot_position.x, foot_position.y - MOB_FOOT_OFFSET_Y)
		var velocity_value: Variant = data.get("velocity", {})
		var snapshot_velocity := server_velocity
		if velocity_value is Dictionary:
			var velocity_data: Dictionary = velocity_value
			snapshot_velocity = Vector2(float(velocity_data.get("x", 0.0)), float(velocity_data.get("y", 0.0)))
		var snapshot_time := snapshot_received_at if snapshot_received_at >= 0.0 else float(Time.get_ticks_msec()) / 1000.0
		if snapshot_buffer.is_empty() or snapshot_time > float(snapshot_buffer[-1]["time"]):
			snapshot_buffer.append({
				"time": snapshot_time,
				"position": snapshot_position,
				"velocity": snapshot_velocity,
				"state": str(data.get("state", "idle")),
				"facing": int(data.get("facing", 1))
			})
			while snapshot_buffer.size() > 2:
				snapshot_buffer.pop_front()
		if not server_position_initialized:
			global_position = snapshot_position
			server_position_initialized = true
	health = int(data.get("health", health))
	max_health = int(data.get("max_health", max_health))
	if not snapshot_buffer.is_empty():
		_apply_visual_state(str(snapshot_buffer[-1]["state"]), int(snapshot_buffer[-1]["facing"]))


func apply_server_damage(data: Dictionary) -> void:
	if dying:
		return
	var updated_health := int(data.get("remaining_health", health))
	var attack_id := str(data.get("attack_id", ""))
	if (not attack_id.is_empty() and attack_id == last_damage_attack_id) or (attack_id.is_empty() and updated_health == last_damage_health):
		return
	last_damage_attack_id = attack_id
	last_damage_health = updated_health
	health = updated_health
	var knockback_value: Variant = data.get("knockback", data.get("velocity", {}))
	if knockback_value is Dictionary:
		var knockback_data: Dictionary = knockback_value
		server_velocity = Vector2(float(knockback_data.get("x", server_velocity.x)), float(knockback_data.get("y", server_velocity.y)))
		velocity = server_velocity
		if not snapshot_buffer.is_empty():
			snapshot_buffer[-1]["velocity"] = server_velocity
	_show_damage_number(int(data.get("damage", 0)), bool(data.get("critical", false)))
	_play_if_available(&"npc_hit")


func apply_server_death(_data: Dictionary = {}) -> void:
	if dying:
		return
	dying = true
	attack_hitbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	enemy_collision.set_deferred("disabled", true)
	var death_velocity := _knockback_from_data(_data)
	velocity = death_velocity
	server_velocity = death_velocity
	if death_tween != null:
		death_tween.kill()
	if death_velocity.length() > 1.0:
		death_tween = create_tween()
		death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(self, "global_position", global_position + Vector2(death_velocity.x * 0.12, death_velocity.y * 0.08), 0.14)
		death_tween.tween_callback(_begin_death_animation)
	else:
		_begin_death_animation()


func _begin_death_animation() -> void:
	velocity = Vector2.ZERO
	_play_if_available(&"npc_die")


func _knockback_from_data(data: Dictionary) -> Vector2:
	var value: Variant = data.get("knockback", data.get("velocity", {}))
	if value is Dictionary:
		var knockback: Dictionary = value
		return Vector2(float(knockback.get("x", 0.0)), float(knockback.get("y", 0.0)))
	return Vector2.ZERO


func _sample_render_state(render_time: float) -> Dictionary:
	if snapshot_buffer.size() == 1:
		var only_snapshot: Dictionary = snapshot_buffer[0]
		var elapsed := minf(maxf(render_time - float(only_snapshot["time"]), 0.0), max_snapshot_extrapolation)
		return {
			"position": (only_snapshot["position"] as Vector2) + (only_snapshot["velocity"] as Vector2) * elapsed,
			"velocity": only_snapshot["velocity"], "state": only_snapshot["state"], "facing": only_snapshot["facing"]
		}
	var older: Dictionary = snapshot_buffer[0]
	var newer: Dictionary = snapshot_buffer[1]
	if render_time <= float(older["time"]):
		return older
	if render_time <= float(newer["time"]):
		var ratio := clampf((render_time - float(older["time"])) / maxf(float(newer["time"]) - float(older["time"]), 0.0001), 0.0, 1.0)
		var discrete: Dictionary = newer if ratio >= 0.5 else older
		return {
			"position": (older["position"] as Vector2).lerp(newer["position"] as Vector2, ratio),
			"velocity": (older["velocity"] as Vector2).lerp(newer["velocity"] as Vector2, ratio),
			"state": discrete["state"], "facing": discrete["facing"]
		}
	var extrapolation := minf(render_time - float(newer["time"]), max_snapshot_extrapolation)
	return {
		"position": (newer["position"] as Vector2) + (newer["velocity"] as Vector2) * extrapolation,
		"velocity": newer["velocity"], "state": newer["state"], "facing": newer["facing"]
	}


func _apply_visual_state(server_state: String, facing: int) -> void:
	if facing != 0:
		visual.flip_h = facing < 0
	if dying:
		return
	var animation_name := &"npc_idle"
	match server_state.to_lower():
		"walk", "patrol", "chase", "return": animation_name = &"npc_walk"
		"attack": animation_name = &"npc_attack"
		"hit", "damaged": animation_name = &"npc_hit"
		"power_up": animation_name = &"npc_power_up"
		"dead", "death": animation_name = &"npc_die"
	_play_if_available(animation_name)


func _play_if_available(animation_name: StringName) -> void:
	if visual.sprite_frames != null and visual.sprite_frames.has_animation(animation_name) and visual.animation != animation_name:
		visual.play(animation_name)


func _on_visual_animation_finished() -> void:
	if dying:
		return
	if visual.animation == &"npc_hit":
		_play_if_available(&"npc_idle")


func _show_damage_number(amount: int, critical: bool) -> void:
	if amount <= 0:
		return
	var damage_label := damage_label_template.duplicate() as Label
	damage_label.visible = true
	damage_label.z_index = 100
	damage_label.text = str(amount)
	if critical:
		damage_label.modulate = Color(1.0, 1.0, 0.0, 1.0)
	damage_label.position = damage_label_template.position + Vector2(randf_range(-4.0, 4.0), 0.0)
	add_child(damage_label)
	var tween := create_tween()
	tween.tween_property(damage_label, "position", damage_label.position + Vector2(0.0, -16.0), 0.65)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(damage_label.queue_free)


func _create_character_sprite_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_value: Variant in ANIMATION_ROWS.keys():
		var animation_name := StringName(animation_value)
		var layout: Dictionary = ANIMATION_ROWS[animation_value]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, bool(layout["loop"]))
		frames.set_animation_speed(animation_name, 5.0)
		for index in int(layout["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(float(index) * FRAME_SIZE.x, float(layout["y"]), FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(animation_name, atlas)
	return frames
