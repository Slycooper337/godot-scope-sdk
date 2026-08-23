class_name CinematicDirector
extends Node

signal cinematic_finished(cinematic_id: String, skipped: bool)

var player: Node2D
var camera: Camera2D
var map_root: Node
var overlay_layer: CanvasLayer
var fade_rect: ColorRect
var text_label: Label
var active_cinematic_id := ""
var active_session_id := ""
var active := false
var skippable := true
var saved_camera_position := Vector2.ZERO
var saved_camera_zoom := Vector2.ONE
var saved_camera_position_smoothing := false
var input_locked := false
var running_tween: Tween
var cue_generation := 0


func setup(player_node: Node2D, camera_node: Camera2D, authored_map: Node, canvas: CanvasLayer) -> void:
	player = player_node
	camera = camera_node
	map_root = authored_map
	overlay_layer = canvas
	_ensure_overlay()


func update_map(authored_map: Node) -> void:
	map_root = authored_map
	if active:
		interrupt()


func play_sequence(data: Dictionary) -> void:
	interrupt()
	active = true
	active_cinematic_id = str(data.get("cinematic_id", ""))
	active_session_id = str(data.get("dialogue_session_id", data.get("session_id", "")))
	skippable = bool(data.get("skippable", true))
	cue_generation += 1
	var generation := cue_generation
	_save_camera()
	var cues_value: Variant = data.get("cues", [])
	if cues_value is Array:
		_run_cues(cues_value, generation)


func apply_cue(data: Dictionary) -> void:
	if not active:
		active = true
		active_cinematic_id = str(data.get("cinematic_id", ""))
		active_session_id = str(data.get("dialogue_session_id", ""))
		_save_camera()
	await _run_cue(data, cue_generation)


func skip() -> void:
	if not active or not skippable:
		return
	var finished_id := active_cinematic_id
	_cleanup(true)
	cinematic_finished.emit(finished_id, true)


func interrupt() -> void:
	if not active:
		return
	var finished_id := active_cinematic_id
	_cleanup(false)
	cinematic_finished.emit(finished_id, false)


func stop_from_server() -> void:
	if active:
		_cleanup(false)


func is_active() -> bool:
	return active


func is_input_locked() -> bool:
	return input_locked


func _run_cues(cues: Array, generation: int) -> void:
	for cue_value in cues:
		if generation != cue_generation or not active:
			return
		if cue_value is Dictionary:
			await _run_cue(cue_value, generation)
	if generation == cue_generation and active:
		var finished_id := active_cinematic_id
		_cleanup(false)
		cinematic_finished.emit(finished_id, false)


func _run_cue(cue: Dictionary, generation: int) -> void:
	if generation != cue_generation or not active:
		return
	var cue_type := str(cue.get("cue_type", "hold"))
	var duration := maxf(float(cue.get("duration_seconds", 0.0)), 0.0)
	match cue_type:
		"lock_input":
			_set_input_locked(true)
		"unlock_input":
			_set_input_locked(false)
		"save_camera":
			_save_camera()
		"restore_camera":
			await _restore_camera(duration)
		"pan_to_marker":
			await _pan_to_marker(str(cue.get("marker_id", "")), duration)
		"follow_npc":
			await _pan_to_npc(str(cue.get("npc_id", "")), duration)
		"follow_player":
			await _restore_camera(duration)
		"zoom_camera":
			var zoom_value: Variant = cue.get("zoom", {})
			if zoom_value is Dictionary:
				await _tween_camera_zoom(Vector2(float((zoom_value as Dictionary).get("x", 1.0)), float((zoom_value as Dictionary).get("y", 1.0))), duration)
		"hold":
			await _wait(duration)
		"fade_in":
			await _fade(0.0, duration)
		"fade_out":
			await _fade(1.0, duration)
		"show_text", "title_card":
			await _show_text(str(cue.get("text", "")), duration)
		"face_npc":
			_face_npc(str(cue.get("npc_id", "")), str(cue.get("animation_id", "")))
		"play_npc_animation":
			_play_npc_animation(str(cue.get("npc_id", "")), str(cue.get("animation_id", "")))
			await _wait(duration)
		"move_npc_to_marker":
			await _move_npc_to_marker(str(cue.get("npc_id", "")), str(cue.get("marker_id", "")), duration)
		"play_sound":
			_play_sound(str(cue.get("sound_path", "")))
		"complete":
			return


func _save_camera() -> void:
	if camera == null:
		return
	saved_camera_position = camera.position
	saved_camera_zoom = camera.zoom
	saved_camera_position_smoothing = camera.position_smoothing_enabled


func _restore_camera(duration: float) -> void:
	if camera == null:
		return
	if duration <= 0.0:
		camera.position = saved_camera_position
		camera.zoom = saved_camera_zoom
	else:
		if running_tween != null:
			running_tween.kill()
		running_tween = create_tween().set_parallel(true)
		running_tween.tween_property(camera, "position", saved_camera_position, duration)
		running_tween.tween_property(camera, "zoom", saved_camera_zoom, duration)
		await running_tween.finished
	camera.position_smoothing_enabled = saved_camera_position_smoothing


func _pan_to_marker(marker_id: String, duration: float) -> void:
	var marker := _find_map_node("marker_id", marker_id) as Node2D
	if marker == null or camera == null or player == null:
		return
	var local_target := player.to_local(marker.global_position)
	var target_zoom := camera.zoom
	if _has_property(marker, "camera_zoom"):
		var marker_zoom: Variant = marker.get("camera_zoom")
		if marker_zoom is Vector2:
			target_zoom = marker_zoom
	camera.position_smoothing_enabled = false
	if duration <= 0.0:
		camera.position = local_target
		camera.zoom = target_zoom
		return
	if running_tween != null:
		running_tween.kill()
	running_tween = create_tween().set_parallel(true)
	running_tween.tween_property(camera, "position", local_target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	running_tween.tween_property(camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await running_tween.finished


func _pan_to_npc(npc_id: String, duration: float) -> void:
	var npc := _find_map_node("npc_id", npc_id) as Node2D
	if npc == null or camera == null or player == null:
		return
	var local_target := player.to_local(npc.global_position)
	camera.position_smoothing_enabled = false
	if duration <= 0.0:
		camera.position = local_target
		return
	if running_tween != null:
		running_tween.kill()
	running_tween = create_tween()
	running_tween.tween_property(camera, "position", local_target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await running_tween.finished


func _move_npc_to_marker(npc_id: String, marker_id: String, duration: float) -> void:
	var npc := _find_map_node("npc_id", npc_id) as Node2D
	var marker := _find_map_node("marker_id", marker_id) as Node2D
	if npc == null or marker == null:
		return
	if duration <= 0.0:
		npc.global_position = marker.global_position
		return
	if running_tween != null:
		running_tween.kill()
	running_tween = create_tween()
	running_tween.tween_property(npc, "global_position", marker.global_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await running_tween.finished


func _tween_camera_zoom(target_zoom: Vector2, duration: float) -> void:
	if camera == null:
		return
	if duration <= 0.0:
		camera.zoom = target_zoom
		return
	if running_tween != null:
		running_tween.kill()
	running_tween = create_tween()
	running_tween.tween_property(camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await running_tween.finished


func _fade(target_alpha: float, duration: float) -> void:
	_ensure_overlay()
	if duration <= 0.0:
		fade_rect.modulate.a = target_alpha
		return
	if running_tween != null:
		running_tween.kill()
	running_tween = create_tween()
	running_tween.tween_property(fade_rect, "modulate:a", target_alpha, duration)
	await running_tween.finished


func _show_text(text: String, duration: float) -> void:
	_ensure_overlay()
	text_label.text = text
	text_label.visible = true
	await _wait(maxf(duration, 0.1))
	text_label.visible = false


func _wait(duration: float) -> void:
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout


func _set_input_locked(locked: bool) -> void:
	input_locked = locked
	if player != null and player.has_method("set_story_input_locked"):
		player.call("set_story_input_locked", locked)


func _face_npc(npc_id: String, facing: String) -> void:
	var npc := _find_map_node("npc_id", npc_id)
	if npc == null:
		return
	var visual := npc.get_node_or_null("Visual") as AnimatedSprite2D
	if visual != null:
		visual.flip_h = facing.to_lower() == "left"


func _play_npc_animation(npc_id: String, animation_id: String) -> void:
	var npc := _find_map_node("npc_id", npc_id)
	if npc == null:
		return
	var visual := npc.get_node_or_null("Visual") as AnimatedSprite2D
	if visual != null and visual.sprite_frames != null and visual.sprite_frames.has_animation(animation_id):
		visual.play(animation_id)


func _play_sound(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player_node := AudioStreamPlayer.new()
	player_node.stream = stream
	add_child(player_node)
	player_node.finished.connect(player_node.queue_free)
	player_node.play()


func _find_map_node(property_name: String, value: String) -> Node:
	if map_root == null or value.is_empty():
		return null
	for node in map_root.find_children("*", "", true, false):
		for property_value in node.get_property_list():
			if property_value is Dictionary and str((property_value as Dictionary).get("name", "")) == property_name and str(node.get(property_name)) == value:
				return node
	return null


func _has_property(node: Object, property_name: String) -> bool:
	for property_value in node.get_property_list():
		if property_value is Dictionary and str((property_value as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _ensure_overlay() -> void:
	if overlay_layer == null or fade_rect != null:
		return
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(fade_rect)
	text_label = Label.new()
	text_label.set_anchors_preset(Control.PRESET_CENTER)
	text_label.position = Vector2(-360.0, -60.0)
	text_label.size = Vector2(720.0, 120.0)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 26)
	text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	text_label.add_theme_constant_override("outline_size", 8)
	text_label.visible = false
	overlay_layer.add_child(text_label)


func _cleanup(_skipped: bool) -> void:
	cue_generation += 1
	if running_tween != null:
		running_tween.kill()
		running_tween = null
	_restore_camera(0.0)
	_set_input_locked(false)
	if fade_rect != null:
		fade_rect.modulate.a = 0.0
	if text_label != null:
		text_label.visible = false
	active = false
	active_session_id = ""
	active_cinematic_id = ""
