@tool
class_name QuestCatalog
extends Node

@export var quests: Array[QuestDefinition] = []


func get_definitions() -> Array:
	var definitions: Array = []
	for quest in quests:
		if quest != null:
			definitions.append(quest.get_definition())
	return definitions
