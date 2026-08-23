@tool
class_name CinematicMarker
extends Node2D

@export var marker_id := "cinematic_marker_1"
@export var display_name := "Cinematic Marker"
@export_enum("left", "right", "unchanged") var facing := "unchanged"
@export var camera_zoom := Vector2.ONE
@export var framing_size := Vector2(640.0, 360.0)


func get_definition() -> Dictionary:
	return {
		"marker_id": marker_id,
		"display_name": display_name,
		"position": {"x": global_position.x, "y": global_position.y},
		"facing": facing,
		"camera_zoom": {"x": camera_zoom.x, "y": camera_zoom.y},
		"framing_size": {"x": framing_size.x, "y": framing_size.y}
	}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := framing_size
	draw_rect(Rect2(-size * 0.5, size), Color(0.65, 0.35, 1.0, 0.06), true)
	draw_rect(Rect2(-size * 0.5, size), Color(0.75, 0.5, 1.0, 0.8), false, 2.0)
	draw_circle(Vector2.ZERO, 10.0, Color(0.85, 0.65, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -size.y * 0.5 - 8.0), "%s [%s]" % [display_name, marker_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
