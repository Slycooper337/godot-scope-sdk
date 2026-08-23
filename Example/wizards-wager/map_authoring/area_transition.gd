@tool
class_name AreaTransition
extends Area2D

@export var transition_id := "transition_1"
@export var display_name := "Exit"
@export var origin_world_id := "main_world"
@export var origin_map_id := "forest"
@export var destination_world_id := "main_world"
@export var destination_map_id := "forest"
@export var destination_spawn_id := "central_battle_spawn"
@export var required_proximity := 96.0
@export var interaction_size := Vector2(128.0, 160.0):
	set(value):
		interaction_size = Vector2(maxf(value.x, 16.0), maxf(value.y, 16.0))
		queue_redraw()
@export var required_player_state: PackedStringArray = ["alive"]
@export var one_way := true
@export var paired_transition_id := ""


func get_definition() -> Dictionary:
	var definition := {
		"transition_id": transition_id,
		"display_name": display_name,
		"origin_world_id": origin_world_id,
		"origin_map_id": origin_map_id,
		"position": {"x": global_position.x, "y": global_position.y},
		"required_proximity": required_proximity,
		"required_player_state": Array(required_player_state),
		"one_way": one_way,
		"destination": {
			"world_id": destination_world_id,
			"map_id": destination_map_id,
			"spawn_id": destination_spawn_id
		},
		"destination_spawn_id": destination_spawn_id
	}
	if not paired_transition_id.is_empty():
		definition["paired_transition_id"] = paired_transition_id
	return definition


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-interaction_size * 0.5, interaction_size), Color(0.2, 0.65, 1.0, 0.12), true)
	draw_rect(Rect2(-interaction_size * 0.5, interaction_size), Color(0.35, 0.8, 1.0), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-interaction_size.x * 0.5, -interaction_size.y * 0.5 - 8.0), "%s -> %s/%s" % [display_name, destination_map_id, destination_spawn_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
