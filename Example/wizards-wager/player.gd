extends CharacterBody2D

signal level_up(new_level: int, available_points: int)
signal stats_changed
signal game_over_finished

@export var walk_speed := 180.0
@export var sprint_speed := 300.0
@export var acceleration := 2400.0
@export var friction := 1800.0
@export var gravity := 1200.0
@export var jump_velocity := -550.0
@export var jump_cut_multiplier := 0.35
@export var camera_lead := 6.0
@export var camera_smoothing := 5.0
@export var hit_knockback_speed := 180.0
@export var hit_knockback_jump_velocity := -180.0
@export var hit_stun_duration := 0.35
@export var base_damage := 1
@export var enemy_bite_damage := 10
@export var base_attack_animation_speed := 2.0
@export var attack_speed_per_agility := 0.05
@export var stamina_regen_rate := 2.0
@export var stamina_regen_per_endurance := 0.5
@export var jump_stamina_cost := 10.0
@export var attack_stamina_cost := 20.0
@export var mana_regen_rate := 8.0
@export var power_up_mana_cost := 20.0
@export var power_up_duration := 10.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var player_animations: AnimationPlayer = $Visual/PlayerAnimations
@onready var camera: Camera2D = $Camera2D
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var damage_label_template: Label = $DamageLabel
@onready var dead_animation_player: AnimationPlayer = $DeadAnimationPlayer

var attacking = false
var facing_direction := 1.0
var camera_rest_position := Vector2.ZERO
var drop_through_timer := 0.0
var attack_direction := 1.0
var attack_hit_targets: Dictionary = {}
var hit_stun_timer := 0.0
var last_attack_was_critical := false
var stats: Dictionary = {
	"str": 1,
	"agi": 1,
	"int": 1,
	"luk": 1,
	"end": 1
}
var max_health := 100.0
var max_stamina := 100.0
var max_mana := 100.0
var magic_power := 1.0
var current_health := 100.0
var current_stamina := 100.0
var current_mana := 100.0
var state_dirty := false
var level := 1
var experience := 0
var unspent_stat_points := 0
var dead := false
var powering_up := false
var powered_up_remaining := 0.0
var power_up_sequence := 0
var active_power_up_id := ""
var attack_swing_sequence := 0
var current_attack_swing_id := ""

func _ready() -> void:
	_recalculate_derived_stats()
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana
	damage_label_template.visible = false
	camera.make_current()
	camera_rest_position = camera.position
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	dead_animation_player.animation_finished.connect(_on_dead_animation_finished)
	visual.play("character_idle")

func _physics_process(delta: float) -> void:
	if dead:
		return
	var stunned := hit_stun_timer > 0.0
	if stunned:
		hit_stun_timer -= delta
	if powered_up_remaining > 0.0:
		powered_up_remaining = maxf(powered_up_remaining - delta, 0.0)
		if powered_up_remaining <= 0.0:
			active_power_up_id = ""

	if drop_through_timer > 0.0:
		drop_through_timer -= delta
		if drop_through_timer <= 0.0:
			body_collision.set_deferred("disabled", false)

	if not stunned and not attacking and not powering_up and not is_powered_up() and Input.is_action_just_pressed("power_up") and current_mana >= power_up_mana_cost:
		_start_power_up()

	if not stunned and not powering_up and Input.is_action_just_pressed("ui_select") and not attacking and current_stamina >= attack_stamina_cost:
		_start_attack()

	if attacking:
		for overlapping_area: Area2D in attack_hitbox.get_overlapping_areas():
			_try_register_attack_area(overlapping_area)

	if Input.is_action_just_pressed("ui_down") and _is_standing_on_drop_through_platform():
		drop_through_timer = 0.35
		body_collision.set_deferred("disabled", true)

	var direction := Input.get_axis("ui_left", "ui_right")
	var sprinting := not stunned and not attacking and not powering_up and Input.is_action_pressed("sprint") and direction != 0.0 and is_on_floor() and current_stamina > 0.0
	var target_speed := _movement_speed(sprinting)
	_update_resources(delta, sprinting)
	if sprinting and current_stamina <= 0.0:
		sprinting = false
		target_speed = _movement_speed(false)

	if stunned:
		# Preserve the hit impulse through the stun window so the knockback is visible.
		pass
	elif (attacking or powering_up) and is_on_floor():
		velocity.x = 0.0
	elif direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
		visual.flip_h = direction < 0.0
		facing_direction = sign(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if not stunned and not attacking and not powering_up and Input.is_action_just_pressed("ui_up") and is_on_floor() and current_stamina >= jump_stamina_cost:
		current_stamina -= jump_stamina_cost
		velocity.y = _jump_velocity()
	elif Input.is_action_just_released("ui_up") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()
	# Ground attacks stop horizontal momentum, while airborne attacks carry
	# momentum until the body lands.
	if attacking and is_on_floor():
		velocity.x = 0.0

	_update_camera(delta)
	_update_animation(direction, sprinting)


func _update_animation(direction: float, sprinting: bool) -> void:
	if attacking or powering_up:
		return

	if not is_on_floor():
		if visual.animation != "character_walk":
			visual.play("character_walk")
		visual.speed_scale = 1.0
	elif direction != 0.0:
		if visual.animation != "character_walk":
			visual.play("character_walk")
		visual.speed_scale = 2.5 if sprinting else 2.0
	else:
		if visual.animation != "character_idle":
			visual.play("character_idle")
		visual.speed_scale = 1.0



func _on_animation_finished() -> void:
	if visual.animation == "character_die":
		dead_animation_player.play("game_over")
	elif visual.animation == "character_attack":
		attacking = false
		attack_hitbox.set_deferred("monitoring", false)
		_resume_movement_animation()
	elif visual.animation == "character_power_up":
		powering_up = false
		powered_up_remaining = power_up_duration
		var game := get_tree().current_scene
		if game != null and game.has_method("request_player_power_up"):
			game.call("request_player_power_up", active_power_up_id, global_position)
		_resume_movement_animation()


func hit(attacker: Node2D = null) -> void:
	take_damage(enemy_bite_damage, attacker)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if dead:
		return

	current_health = maxf(current_health - float(amount), 0.0)
	_show_damage_number(amount)
	if current_health <= 0.0:
		_begin_death()
		return
	_apply_hit_knockback(attacker)

func apply_authoritative_damage(amount: int, knockback: Dictionary = {}, authoritative_remaining_health: int = -1) -> void:
	if dead:
		return

	if authoritative_remaining_health >= 0:
		current_health = clampf(float(authoritative_remaining_health), 0.0, max_health)
	else:
		current_health = maxf(current_health - float(amount), 0.0)
	_show_damage_number(amount)
	if current_health <= 0.0:
		apply_authoritative_death()
		return
	if attacking:
		attacking = false
		attack_hitbox.set_deferred("monitoring", false)
	velocity.x = float(knockback.get("x", 0.0))
	velocity.y = float(knockback.get("y", 0.0))
	hit_stun_timer = hit_stun_duration
	player_animations.stop()
	player_animations.play("player_hit")


func apply_authoritative_death(_data: Dictionary = {}) -> void:
	if dead:
		return
	current_health = 0.0
	_begin_death()


func _begin_death() -> void:
	if dead:
		return
	dead = true
	attacking = false
	powering_up = false
	powered_up_remaining = 0.0
	active_power_up_id = ""
	attack_hitbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	visual.speed_scale = 1.0
	player_animations.stop()
	dead_animation_player.stop()
	visual.stop()
	if visual.sprite_frames == null or not visual.sprite_frames.has_animation(&"character_die"):
		push_error("[Player] Visual is missing the character_die SpriteFrames animation.")
		# Do not strand the player in the dead state if a malformed custom
		# SpriteFrames resource reaches this point.
		dead_animation_player.play(&"game_over")
		return
	visual.visible = true
	visual.play(&"character_die")
	visual.set_frame_and_progress(0, 0.0)


func _on_dead_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"game_over":
		game_over_finished.emit()


func revive(server_data: Dictionary = {}) -> void:
	dead = false
	body_collision.set_deferred("disabled", false)
	velocity = Vector2.ZERO
	hit_stun_timer = 0.0
	attacking = false
	powering_up = false
	powered_up_remaining = 0.0
	active_power_up_id = ""
	attack_hitbox.set_deferred("monitoring", false)
	dead_animation_player.play("RESET")
	var resources_value: Variant = server_data.get("resources", server_data)
	if resources_value is Dictionary and (resources_value as Dictionary).has("health"):
		current_health = clampf(float((resources_value as Dictionary).get("health", max_health)), 0.0, max_health)
	elif server_data.has("health"):
		current_health = clampf(float(server_data.get("health", max_health)), 0.0, max_health)
	else:
		current_health = max_health
	visual.play("character_idle")


func _show_damage_number(amount: int) -> void:
	var damage_label := damage_label_template.duplicate() as Label
	damage_label.visible = true
	damage_label.z_index = 100
	damage_label.text = str(amount)
	damage_label.position = damage_label_template.position + Vector2(randf_range(-4.0, 4.0), 0.0)
	add_child(damage_label)

	var tween := create_tween()
	tween.tween_property(damage_label, "position", damage_label.position + Vector2(0.0, -16.0), 0.65)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(damage_label.queue_free)


func _apply_hit_knockback(attacker: Node2D = null) -> void:
	if attacking:
		attacking = false
		attack_hitbox.set_deferred("monitoring", false)

	var direction_away_from_attacker := facing_direction
	if attacker != null:
		direction_away_from_attacker = sign(global_position.x - attacker.global_position.x)
		if direction_away_from_attacker == 0.0:
			direction_away_from_attacker = -facing_direction

	velocity.x = direction_away_from_attacker * hit_knockback_speed
	velocity.y = hit_knockback_jump_velocity
	hit_stun_timer = hit_stun_duration
	player_animations.play("player_hit")


func _start_attack() -> void:
	attacking = true
	current_stamina -= attack_stamina_cost
	attack_direction = facing_direction
	attack_hit_targets.clear()
	attack_swing_sequence += 1
	current_attack_swing_id = "%s-swing-%d" % [active_power_up_id if is_powered_up() else "basic", attack_swing_sequence]
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * attack_direction
	attack_hitbox.set_deferred("monitoring", true)
	visual.play("character_attack")
	visual.speed_scale = _attack_animation_speed()


func _start_power_up() -> void:
	current_mana -= power_up_mana_cost
	powering_up = true
	power_up_sequence += 1
	active_power_up_id = "%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), power_up_sequence]
	velocity.x = 0.0
	if visual.sprite_frames != null and visual.sprite_frames.has_animation(&"character_power_up"):
		visual.play(&"character_power_up")
		visual.set_frame_and_progress(0, 0.0)
		return
	push_error("[Player] Visual is missing the character_power_up SpriteFrames animation.")
	powering_up = false
	powered_up_remaining = power_up_duration
	var game := get_tree().current_scene
	if game != null and game.has_method("request_player_power_up"):
		game.call("request_player_power_up", active_power_up_id, global_position)


func is_powered_up() -> bool:
	return powered_up_remaining > 0.0 and not active_power_up_id.is_empty()


func apply_authoritative_power_up(data: Dictionary) -> void:
	if str(data.get("activation_id", active_power_up_id)) != active_power_up_id:
		return
	if data.has("remaining_mana"):
		current_mana = clampf(float(data.get("remaining_mana", current_mana)), 0.0, max_mana)
	if data.has("remaining_seconds"):
		powered_up_remaining = clampf(float(data.get("remaining_seconds", powered_up_remaining)), 0.0, power_up_duration)


func apply_authoritative_power_up_rejected(data: Dictionary) -> void:
	if str(data.get("activation_id", active_power_up_id)) != active_power_up_id:
		return
	powering_up = false
	powered_up_remaining = 0.0
	active_power_up_id = ""
	if data.has("remaining_mana"):
		current_mana = clampf(float(data.get("remaining_mana", current_mana)), 0.0, max_mana)
	else:
		current_mana = minf(current_mana + power_up_mana_cost, max_mana)


func apply_authoritative_power_up_expired(data: Dictionary) -> void:
	if str(data.get("activation_id", active_power_up_id)) != active_power_up_id:
		return
	powering_up = false
	powered_up_remaining = 0.0
	active_power_up_id = ""


func _resume_movement_animation() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		visual.play("character_walk")
		visual.speed_scale = 2.0
	else:
		visual.play("character_idle")
		visual.speed_scale = 1.0


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	_try_register_attack_area(area)


func _try_register_attack_area(area: Area2D) -> void:
	if not attacking or attack_hit_targets.has(area):
		return
	if area.name != "EnemyArea":
		return
	var enemy: Node = area.get_parent()
	if not enemy.has_method("get_server_mob_id"):
		return
	var mob_id := str(enemy.call("get_server_mob_id"))
	if mob_id.is_empty() or (not is_powered_up() and not attack_hit_targets.is_empty()):
		return
	attack_hit_targets[area] = true
	var game := get_tree().current_scene
	if game != null and game.has_method("request_mob_attack"):
		game.call("request_mob_attack", mob_id, global_position, int(facing_direction), active_power_up_id if is_powered_up() else "", current_attack_swing_id)


func _recalculate_derived_stats() -> void:
	max_health = 100.0 + _stat("end") * 10.0
	max_stamina = 100.0 + _stat("end") * 5.0
	max_mana = 100.0 + _stat("int") * 15.0
	magic_power = 1.0 + float(_stat("int"))
	current_health = clampf(current_health, 0.0, max_health)
	current_stamina = clampf(current_stamina, 0.0, max_stamina)
	current_mana = clampf(current_mana, 0.0, max_mana)


func _stat(stat_name: String) -> int:
	return maxi(int(stats.get(stat_name, 1)), 1)


func _movement_speed(sprinting: bool) -> float:
	var agility_bonus := float(_stat("agi")) * 2.0
	return sprint_speed + agility_bonus if sprinting else walk_speed + agility_bonus


func _jump_velocity() -> float:
	return jump_velocity - float(_stat("agi")) * 8.0


func _attack_animation_speed() -> float:
	var agility_levels_above_start := maxi(_stat("agi") - 1, 0)
	return base_attack_animation_speed * (1.0 + float(agility_levels_above_start) * attack_speed_per_agility)


func _update_resources(delta: float, sprinting: bool) -> void:
	if sprinting:
		var stamina_drain := maxf(2.0, 12.0 - float(_stat("agi")) * 0.5)
		current_stamina = maxf(current_stamina - stamina_drain * delta, 0.0)
	else:
		var stamina_regen := stamina_regen_rate + float(_stat("end")) * stamina_regen_per_endurance
		current_stamina = minf(current_stamina + stamina_regen * delta, max_stamina)

	current_mana = minf(current_mana + mana_regen_rate * delta, max_mana)


func get_physical_damage() -> int:
	var damage_value := base_damage + (_stat("str") - 1)
	last_attack_was_critical = randf() < get_crit_rate()
	if last_attack_was_critical:
		damage_value *= 2
	return damage_value


func get_crit_rate() -> float:
	return clampf(0.01 + float(_stat("luk")) * 0.01, 0.0, 0.75)


func get_magic_power() -> float:
	return magic_power


func set_stat(stat_name: String, value: int) -> void:
	if not stats.has(stat_name):
		return
	stats[stat_name] = maxi(value, 1)
	_recalculate_derived_stats()
	state_dirty = true
	stats_changed.emit()


func spend_stat_point(stat_name: String) -> bool:
	if unspent_stat_points <= 0 or not stats.has(stat_name):
		return false

	stats[stat_name] = _stat(stat_name) + 1
	unspent_stat_points -= 1
	_recalculate_derived_stats()
	state_dirty = true
	stats_changed.emit()
	return true

func apply_authoritative_stats(server_state: Dictionary) -> void:
	var previous_level := level
	var had_authoritative_points := server_state.has("unspent_stat_points") or server_state.has("stat_points") or server_state.has("available_stat_points")
	var server_stats: Variant = server_state.get("stats", {})
	if server_stats is Dictionary:
		var stats_dictionary: Dictionary = server_stats
		for stat_name: String in stats.keys():
			stats[stat_name] = maxi(int(stats_dictionary.get(stat_name, stats[stat_name])), 1)
	var flat_stat_names := {
		"str": "strength",
		"agi": "agility",
		"int": "intelligence",
		"luk": "luck",
		"end": "endurance"
	}
	for stat_name: String in flat_stat_names.keys():
		var server_field: String = flat_stat_names[stat_name]
		if server_state.has(server_field):
			stats[stat_name] = maxi(int(server_state.get(server_field, stats[stat_name])), 1)
		elif server_state.has(stat_name):
			stats[stat_name] = maxi(int(server_state.get(stat_name, stats[stat_name])), 1)
	if server_state.has("level"):
		level = maxi(int(server_state.get("level", level)), 1)
	if server_state.has("experience"):
		experience = maxi(int(server_state.get("experience", experience)), 0)
	if server_state.has("unspent_stat_points"):
		unspent_stat_points = maxi(int(server_state.get("unspent_stat_points", unspent_stat_points)), 0)
	elif server_state.has("stat_points"):
		unspent_stat_points = maxi(int(server_state.get("stat_points", unspent_stat_points)), 0)
	elif server_state.has("available_stat_points"):
		unspent_stat_points = maxi(int(server_state.get("available_stat_points", unspent_stat_points)), 0)
	_recalculate_derived_stats()
	var resources_value: Variant = server_state.get("resources", server_state)
	if resources_value is Dictionary:
		var resources: Dictionary = resources_value
		if resources.has("health"):
			current_health = clampf(float(resources.get("health", current_health)), 0.0, max_health)
		if resources.has("stamina"):
			current_stamina = clampf(float(resources.get("stamina", current_stamina)), 0.0, max_stamina)
		if resources.has("mana"):
			current_mana = clampf(float(resources.get("mana", current_mana)), 0.0, max_mana)
	if level > previous_level and not had_authoritative_points:
		unspent_stat_points += (level - previous_level) * 5
	state_dirty = false
	if level > previous_level:
		level_up.emit(level, unspent_stat_points)
	stats_changed.emit()


func gain_experience(amount: int) -> void:
	if amount <= 0:
		return

	experience += amount
	state_dirty = true
	while experience >= get_experience_to_next_level():
		experience -= get_experience_to_next_level()
		level += 1
		unspent_stat_points += 5
		level_up.emit(level, unspent_stat_points)

func apply_authoritative_experience(new_experience: int, authoritative_level: int = -1) -> void:
	var previous_level := level
	experience = maxi(new_experience, 0)
	if authoritative_level > 0:
		level = authoritative_level
	if level > previous_level:
		unspent_stat_points += (level - previous_level) * 5
		level_up.emit(level, unspent_stat_points)
	state_dirty = false


func get_experience_to_next_level() -> int:
	return maxi(level * 10, 10)


func get_persistent_state() -> Dictionary:
	return {
		"level": level,
		"experience": experience,
		"unspent_stat_points": unspent_stat_points,
		"stats": stats.duplicate(),
		"resources": {
			"health": current_health,
			"stamina": current_stamina,
			"mana": current_mana
		}
	}


func apply_persistent_state(saved_state: Dictionary) -> void:
	level = maxi(int(saved_state.get("level", 1)), 1)
	experience = maxi(int(saved_state.get("experience", 0)), 0)
	unspent_stat_points = maxi(int(saved_state.get("unspent_stat_points", 0)), 0)
	var saved_stats: Variant = saved_state.get("stats", {})
	if saved_stats is Dictionary:
		for stat_name: String in stats.keys():
			stats[stat_name] = maxi(int(saved_stats.get(stat_name, stats[stat_name])), 1)

	_recalculate_derived_stats()
	var resources: Variant = saved_state.get("resources", {})
	if resources is Dictionary:
		current_health = clampf(float(resources.get("health", max_health)), 0.0, max_health)
		current_stamina = clampf(float(resources.get("stamina", max_stamina)), 0.0, max_stamina)
		current_mana = clampf(float(resources.get("mana", max_mana)), 0.0, max_mana)
	state_dirty = false


func is_state_dirty() -> bool:
	return state_dirty


func clear_state_dirty() -> void:
	state_dirty = false


func _update_camera(delta: float) -> void:
	var target_position := camera_rest_position + Vector2(facing_direction * camera_lead, 0.0)
	var lerp_weight := 1.0 - exp(-camera_smoothing * delta)
	camera.position = camera.position.lerp(target_position, lerp_weight)


func _is_standing_on_drop_through_platform() -> bool:
	if not is_on_floor():
		return false

	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collision.get_normal().y < -0.7 and collider is Node and (collider as Node).is_in_group("drop_through_platforms"):
			return true

	return false
