extends Node2D

@export var snapshot_buffer_size := 8
@export var snapshot_render_delay := 0.12
@export var maximum_extrapolation := 0.18
@export var teleport_threshold := 250.0
@export var stale_timeout := 3.0
@export var walk_enter_speed := 15.0
@export var walk_exit_speed := 5.0
@export var idle_transition_delay := 0.12
@export var facing_speed_threshold := 2.0
@export var maximum_snapshot_speed := 1200.0
@export var debug_remote_movement := false

@onready var sprite: AnimatedSprite2D = $Sprite

var snapshots: Array[Dictionary] = []
var last_sequence := -1
var has_received_sequence := false
var last_received_at := 0.0
var current_map_id := ""
var walking := false
var below_walk_speed_elapsed := 0.0
var action_animation_active := false
var action_state := ""

var packets_received := 0
var packets_rejected := 0
var interpolated_frames := 0
var extrapolated_frames := 0
var teleport_snaps := 0
var stale_holds := 0


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)


func _process(delta: float) -> void:
	if snapshots.is_empty():
		return

	var now := _monotonic_seconds()
	if now - last_received_at >= stale_timeout:
		stale_holds += 1
		if not action_animation_active:
			_update_facing_and_animation(Vector2.ZERO, true, "idle", 0, delta)
		return

	var render_time := now - snapshot_render_delay
	var rendered := _sample_render_state(render_time)
	position = rendered["position"] as Vector2
	rotation = float(rendered["rotation"])
	_update_facing_and_animation(
		rendered["velocity"] as Vector2,
		bool(rendered["grounded"]),
		str(rendered["movement_state"]),
		int(rendered["facing"]),
		delta
	)


func push_movement_snapshot(data: Dictionary) -> bool:
	packets_received += 1
	var position_value: Variant = data.get("position", {})
	if not position_value is Dictionary:
		return false
	var position_data: Dictionary = position_value
	var incoming_position := Vector2(
		float(position_data.get("x", position.x)),
		float(position_data.get("y", position.y))
	)
	var received_at := _monotonic_seconds()

	var has_sequence := data.has("sequence")
	var sequence := int(data.get("sequence", -1))
	if has_sequence and has_received_sequence and sequence <= last_sequence:
		packets_rejected += 1
		_debug("rejected sequence %d after %d" % [sequence, last_sequence])
		return false

	var incoming_map_id := str(data.get("map_id", current_map_id))
	var explicit_snap := bool(data.get("teleport", false)) or bool(data.get("respawn", false))
	var map_changed := not incoming_map_id.is_empty() and not current_map_id.is_empty() and incoming_map_id != current_map_id
	var distance_is_teleport := not snapshots.is_empty() and (snapshots[-1]["position"] as Vector2).distance_to(incoming_position) > teleport_threshold

	var incoming_velocity := Vector2.ZERO
	var velocity_value: Variant = data.get("velocity", null)
	if velocity_value is Dictionary:
		var velocity_data: Dictionary = velocity_value
		incoming_velocity = Vector2(
			float(velocity_data.get("x", 0.0)),
			float(velocity_data.get("y", 0.0))
		)
	elif not snapshots.is_empty():
		var previous: Dictionary = snapshots[-1]
		var elapsed := received_at - float(previous["received_at"])
		if elapsed > 0.0001:
			incoming_velocity = (incoming_position - (previous["position"] as Vector2)) / elapsed
	incoming_velocity = incoming_velocity.limit_length(maximum_snapshot_speed)

	var snapshot := {
		"sequence": sequence,
		"received_at": received_at,
		"position": incoming_position,
		"velocity": incoming_velocity,
		"rotation": float(data.get("rotation", rotation)),
		"facing": int(data.get("facing", 0)),
		"grounded": bool(data.get("grounded", true)),
		"movement_state": str(data.get("movement_state", ""))
	}

	if has_sequence:
		last_sequence = sequence
		has_received_sequence = true
	if not incoming_map_id.is_empty():
		current_map_id = incoming_map_id
	last_received_at = received_at

	if snapshots.is_empty() or explicit_snap or map_changed or distance_is_teleport:
		_snap_to_snapshot(snapshot, not snapshots.is_empty())
		return true

	snapshots.append(snapshot)
	while snapshots.size() > maxi(snapshot_buffer_size, 2):
		snapshots.pop_front()
	return true


func set_sprite_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	sprite.sprite_frames = frames
	var desired_animation := _animation_for_action(action_state)
	if action_animation_active and not desired_animation.is_empty() and frames.has_animation(desired_animation):
		sprite.play(desired_animation)
	elif walking and frames.has_animation(&"character_walk"):
		sprite.play(&"character_walk")
	elif frames.has_animation(&"character_idle"):
		sprite.play(&"character_idle")


func get_movement_diagnostics() -> Dictionary:
	return {
		"packets_received": packets_received,
		"packets_rejected": packets_rejected,
		"interpolated_frames": interpolated_frames,
		"extrapolated_frames": extrapolated_frames,
		"teleport_snaps": teleport_snaps,
		"stale_holds": stale_holds
	}


func _sample_render_state(render_time: float) -> Dictionary:
	var oldest: Dictionary = snapshots[0]
	if render_time <= float(oldest["received_at"]):
		return oldest

	for index in range(snapshots.size() - 1):
		var older: Dictionary = snapshots[index]
		var newer: Dictionary = snapshots[index + 1]
		var older_time := float(older["received_at"])
		var newer_time := float(newer["received_at"])
		if render_time <= newer_time:
			var ratio := clampf((render_time - older_time) / maxf(newer_time - older_time, 0.0001), 0.0, 1.0)
			var discrete: Dictionary = newer if ratio >= 0.5 else older
			interpolated_frames += 1
			return {
				"position": (older["position"] as Vector2).lerp(newer["position"] as Vector2, ratio),
				"velocity": (older["velocity"] as Vector2).lerp(newer["velocity"] as Vector2, ratio),
				"rotation": lerp_angle(float(older["rotation"]), float(newer["rotation"]), ratio),
				"facing": int(discrete["facing"]),
				"grounded": bool(discrete["grounded"]),
				"movement_state": str(discrete["movement_state"])
			}

	var newest: Dictionary = snapshots[-1]
	var extrapolation_time := clampf(render_time - float(newest["received_at"]), 0.0, maximum_extrapolation)
	extrapolated_frames += 1
	return {
		"position": (newest["position"] as Vector2) + (newest["velocity"] as Vector2) * extrapolation_time,
		"velocity": newest["velocity"] as Vector2,
		"rotation": float(newest["rotation"]),
		"facing": int(newest["facing"]),
		"grounded": bool(newest["grounded"]),
		"movement_state": str(newest["movement_state"])
	}


func _snap_to_snapshot(snapshot: Dictionary, count_as_teleport: bool) -> void:
	snapshots.clear()
	snapshots.append(snapshot)
	position = snapshot["position"] as Vector2
	rotation = float(snapshot["rotation"])
	walking = false
	below_walk_speed_elapsed = 0.0
	action_animation_active = false
	action_state = ""
	if count_as_teleport:
		teleport_snaps += 1
	_update_facing_and_animation(
		snapshot["velocity"] as Vector2,
		bool(snapshot["grounded"]),
		str(snapshot["movement_state"]),
		int(snapshot["facing"]),
		0.0
	)


func _update_facing_and_animation(render_velocity: Vector2, _grounded: bool, movement_state: String, explicit_facing: int, delta: float) -> void:
	var normalized_state := movement_state.to_lower()
	var incoming_action := _normalized_action_state(normalized_state)
	if action_animation_active and action_state == "death" and incoming_action != "death":
		action_animation_active = false
		action_state = ""
	if not incoming_action.is_empty():
		_start_action_animation(incoming_action)

	if explicit_facing != 0:
		sprite.flip_h = explicit_facing < 0
	elif absf(render_velocity.x) > facing_speed_threshold:
		sprite.flip_h = render_velocity.x < 0.0

	if action_animation_active:
		return

	var horizontal_speed := absf(render_velocity.x)
	if walking:
		if horizontal_speed < walk_exit_speed:
			below_walk_speed_elapsed += delta
			if below_walk_speed_elapsed >= idle_transition_delay:
				walking = false
				_play_if_changed(&"character_idle")
		else:
			below_walk_speed_elapsed = 0.0
	elif horizontal_speed > walk_enter_speed:
		walking = true
		below_walk_speed_elapsed = 0.0
		_play_if_changed(&"character_walk")
	else:
		_play_if_changed(&"character_idle")


func _start_action_animation(new_action_state: String) -> void:
	if action_animation_active and action_state == new_action_state:
		return
	var animation_name := _animation_for_action(new_action_state)
	if animation_name.is_empty() or not sprite.sprite_frames.has_animation(animation_name):
		return
	action_state = new_action_state
	action_animation_active = true
	_play_if_changed(animation_name)


func _on_sprite_animation_finished() -> void:
	if not action_animation_active or action_state == "death":
		return
	action_animation_active = false
	action_state = ""


func _normalized_action_state(state: String) -> String:
	match state:
		"dead", "death", "die", "character_die":
			return "death"
		"attack", "character_attack":
			return "attack"
		"hit", "character_hit":
			return "hit"
		"power_up", "power-up", "character_power_up":
			return "power_up"
	return ""


func _animation_for_action(state: String) -> StringName:
	match state:
		"death":
			return &"character_die"
		"attack":
			return &"character_attack"
		"hit":
			return &"character_hit"
		"power_up":
			return &"character_power_up"
	return &""


func _play_if_changed(animation_name: StringName) -> void:
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _monotonic_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _debug(message: String) -> void:
	if debug_remote_movement:
		print("[RemotePlayer:%s] %s" % [name, message])
