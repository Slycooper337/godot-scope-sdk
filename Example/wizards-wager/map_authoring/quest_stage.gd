@tool
class_name QuestStage
extends Resource

@export var stage_id := "stage_1"
@export_enum("kill", "talk", "interact", "use_transition", "enter_map", "enter_area") var objective_type := "kill"
@export var target_archetype_id := "zombie"
@export var target_npc_id := ""
@export var target_object_id := ""
@export var target_transition_id := ""
@export var target_world_id := ""
@export var target_map_id := ""
@export var target_spawn_id := ""
@export var target_area_id := ""
@export var required_kill_area_id := ""
@export_range(1, 999999, 1) var required_count := 1


func get_definition() -> Dictionary:
	var definition := {
		"stage_id": stage_id,
		"objective_type": objective_type,
		"target_archetype_id": target_archetype_id,
		"target_npc_id": target_npc_id,
		"target_transition_id": target_transition_id,
		"target_map_id": target_map_id,
		"target_spawn_id": target_spawn_id,
		"required_count": required_count
	}
	if not target_object_id.is_empty():
		definition["target_object_id"] = target_object_id
	if not target_area_id.is_empty():
		definition["target_area_id"] = target_area_id
	if not required_kill_area_id.is_empty():
		definition["required_kill_area_id"] = required_kill_area_id
	return definition
