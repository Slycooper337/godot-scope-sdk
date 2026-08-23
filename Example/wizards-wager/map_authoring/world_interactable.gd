@tool
class_name WorldInteractable
extends Area2D

@export var object_id := "interactable_1"
@export var display_name := "Interactable"
@export_multiline var interaction_text := ""
@export var required_proximity := 96.0


func get_definition() -> Dictionary:
	return {
		"object_id": object_id,
		"display_name": display_name,
		"interaction_text": interaction_text,
		"required_proximity": required_proximity,
		"position": {"x": global_position.x, "y": global_position.y}
	}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, required_proximity, Color(0.8, 0.35, 1.0, 0.08))
	draw_arc(Vector2.ZERO, required_proximity, 0.0, TAU, 32, Color(0.85, 0.5, 1.0), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-64.0, -required_proximity - 8.0), "%s [%s]" % [display_name, object_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
