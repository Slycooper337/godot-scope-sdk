extends Node2D

@export var camera_speed := 900.0
@export var zoom_step := 0.1

var map_root: MapRoot
var definition: Dictionary = {}
var camera: Camera2D


func _ready() -> void:
	var scene_path := str(ProjectSettings.get_setting("map_authoring/preview_map_scene", ""))
	if scene_path.is_empty():
		push_error("No map_authoring/preview_map_scene is configured.")
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load preview map: %s" % scene_path)
		return
	map_root = packed.instantiate() as MapRoot
	if map_root == null:
		push_error("Preview scene is not a MapRoot: %s" % scene_path)
		return
	add_child(map_root)
	definition = map_root.collect_definition()
	camera = Camera2D.new()
	camera.name = "PreviewCamera"
	camera.enabled = true
	add_child(camera)
	var preferred_spawn := str(ProjectSettings.get_setting("map_authoring/preview_spawn_id", ""))
	camera.position = _spawn_position(preferred_spawn)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var help := Label.new()
	help.position = Vector2(18.0, 18.0)
	help.text = "WORLD BUILDER PREVIEW\nA/D or arrows: move   W/S: vertical   Mouse wheel: zoom   Esc: close"
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 2)
	help.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(help)
	queue_redraw()


func _process(delta: float) -> void:
	if camera == null:
		return
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	direction = direction.normalized()
	camera.position += direction * camera_speed * delta / maxf(camera.zoom.x, 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and camera != null:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2.ONE * zoom_step).clamp(Vector2(0.2, 0.2), Vector2(4.0, 4.0))
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2.ONE * zoom_step).clamp(Vector2(0.2, 0.2), Vector2(4.0, 4.0))


func _spawn_position(preferred_spawn: String) -> Vector2:
	var first := Vector2.ZERO
	for spawn_value in definition.get("player_spawns", []):
		if not spawn_value is Dictionary:
			continue
		var spawn: Dictionary = spawn_value
		var position: Dictionary = spawn.get("position", {})
		var point := Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
		if first == Vector2.ZERO:
			first = point
		if str(spawn.get("spawn_id", "")) == preferred_spawn:
			return point
	return first


func _draw() -> void:
	if definition.is_empty():
		return
	for spawn_value in definition.get("player_spawns", []):
		var spawn: Dictionary = spawn_value
		var point := _point(spawn.get("position", {}))
		draw_circle(point, 18.0, Color(0.25, 1.0, 0.45, 0.75))
		_label(point + Vector2(22.0, 5.0), "SPAWN %s" % str(spawn.get("spawn_id", "")), Color(0.5, 1.0, 0.65))
	for transition_value in definition.get("area_transitions", []):
		var transition: Dictionary = transition_value
		var point := _point(transition.get("position", {}))
		draw_rect(Rect2(point - Vector2(64.0, 80.0), Vector2(128.0, 160.0)), Color(0.2, 0.65, 1.0, 0.16), true)
		draw_rect(Rect2(point - Vector2(64.0, 80.0), Vector2(128.0, 160.0)), Color(0.35, 0.8, 1.0), false, 3.0)
		var destination: Dictionary = transition.get("destination", {})
		_label(point + Vector2(-64.0, -90.0), "EXIT → %s/%s" % [str(destination.get("map_id", "")), str(destination.get("spawn_id", ""))], Color(0.55, 0.85, 1.0))
	for area_value in definition.get("quest_areas", []):
		var area: Dictionary = area_value
		var point := _point(area.get("position", {}))
		var size := _point(area.get("size", {}))
		draw_rect(Rect2(point - size * 0.5, size), Color(1.0, 0.8, 0.2, 0.14), true)
		draw_rect(Rect2(point - size * 0.5, size), Color(1.0, 0.85, 0.3), false, 3.0)
		_label(point - size * 0.5 + Vector2(0.0, -8.0), "QUEST AREA %s" % str(area.get("area_id", "")), Color(1.0, 0.9, 0.4))
	for region_value in definition.get("combatant_spawns", []):
		var region: Dictionary = region_value
		var point := _point(region.get("position", {}))
		var size := _point(region.get("bounds", {}))
		if str(region.get("placement_mode", "")) == "fixed":
			size = Vector2(32.0, 32.0)
		draw_rect(Rect2(point - size * 0.5, size), Color(0.95, 0.3, 0.25, 0.12), true)
		draw_rect(Rect2(point - size * 0.5, size), Color(1.0, 0.45, 0.35), false, 2.0)
		_label(point - size * 0.5 + Vector2(0.0, -8.0), "%s x%d" % [str(region.get("archetype_id", "")), int(region.get("spawn_count", 1))], Color(1.0, 0.6, 0.5))
	for character_value in definition.get("quest_givers", []):
		var character: Dictionary = character_value
		var point := _point(character.get("position", {}))
		var radius := float(character.get("interaction_radius", 96.0))
		draw_circle(point, radius, Color(0.3, 1.0, 0.55, 0.05))
		draw_arc(point, radius, 0.0, TAU, 32, Color(0.4, 1.0, 0.65, 0.7), 2.0)
		var character_label := "CHAR %s" % str(character.get("npc_id", ""))
		var conversation_id := str(character.get("default_conversation_id", ""))
		if not conversation_id.is_empty():
			character_label += " | TALK %s" % conversation_id
		_label(point + Vector2(-60.0, -radius - 8.0), character_label, Color(0.55, 1.0, 0.7))
	for marker_value in definition.get("cinematic_markers", []):
		var marker: Dictionary = marker_value
		var point := _point(marker.get("position", {}))
		var size := _point(marker.get("framing_size", {}))
		draw_rect(Rect2(point - size * 0.5, size), Color(0.7, 0.4, 1.0, 0.08), true)
		draw_rect(Rect2(point - size * 0.5, size), Color(0.8, 0.55, 1.0, 0.85), false, 2.0)
		_label(point - size * 0.5 + Vector2(0.0, -8.0), "CAMERA %s" % str(marker.get("marker_id", "")), Color(0.85, 0.65, 1.0))


func _point(value: Variant) -> Vector2:
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _label(position: Vector2, text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
