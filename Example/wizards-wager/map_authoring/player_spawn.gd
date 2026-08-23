@tool
class_name MapPlayerSpawn
extends Node2D

@export var spawn_id := "player_start"
@export var surface_id := ""

func get_definition() -> Dictionary:
	return {
		"spawn_id": spawn_id,
		"surface_id": surface_id,
		"position": {"x": global_position.x, "y": global_position.y}
	}

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 12.0, Color(0.3, 0.9, 0.5, 0.35))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.6), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(20.0, 5.0), spawn_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
