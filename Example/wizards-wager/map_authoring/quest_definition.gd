@tool
class_name QuestDefinition
extends Resource

@export var quest_id := "quest_1"
@export var giver_npc_id := ""
@export var title := "New Quest"
@export_multiline var description := ""
@export_multiline var offer_text := ""
@export_multiline var completion_text := ""
@export var repeatable := false
@export var prerequisite_quest_ids: PackedStringArray = []
@export var required_committed_faction_id := ""
@export var rewards: Dictionary = {}
@export var stages: Array[QuestStage] = []


func get_definition() -> Dictionary:
	var stage_definitions: Array = []
	for stage in stages:
		if stage != null:
			stage_definitions.append(stage.get_definition())
	return {
		"quest_id": quest_id,
		"giver_npc_id": giver_npc_id,
		"title": title,
		"description": description,
		"offer_text": offer_text,
		"completion_text": completion_text,
		"repeatable": repeatable,
		"prerequisite_quest_ids": Array(prerequisite_quest_ids),
		"required_committed_faction_id": required_committed_faction_id,
		"rewards": rewards.duplicate(true),
		"stages": stage_definitions
	}
