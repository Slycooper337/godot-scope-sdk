@tool
class_name ConditionalConversation
extends Resource

@export var entry_id := "conversation_entry_1"
@export var conversation_id := ""
@export var priority := 0
@export var one_time := false
@export_enum("all", "any") var condition_logic := "all"
@export var conditions: Array[StoryCondition] = []


func get_definition() -> Dictionary:
	var condition_definitions: Array = []
	for condition in conditions:
		if condition != null:
			condition_definitions.append(condition.get_definition())
	return {
		"entry_id": entry_id,
		"conversation_id": conversation_id,
		"priority": priority,
		"one_time": one_time,
		"condition_logic": condition_logic,
		"conditions": condition_definitions
	}
