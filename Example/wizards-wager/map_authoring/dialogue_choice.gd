@tool
class_name DialogueChoice
extends Resource

@export var choice_id := "choice_1"
@export_multiline var text := "Continue"
@export var destination_node_id := ""
@export_multiline var disabled_explanation := ""
@export var requires_confirmation := false
@export_enum("all", "any") var condition_logic := "all"
@export var conditions: Array[StoryCondition] = []
@export var actions: Array[StoryAction] = []


func get_definition() -> Dictionary:
	var condition_definitions: Array = []
	for condition in conditions:
		if condition != null:
			condition_definitions.append(condition.get_definition())
	var action_definitions: Array = []
	for action in actions:
		if action != null:
			action_definitions.append(action.get_definition())
	return {
		"choice_id": choice_id,
		"text": text,
		"destination_node_id": destination_node_id,
		"disabled_explanation": disabled_explanation,
		"requires_confirmation": requires_confirmation,
		"condition_logic": condition_logic,
		"conditions": condition_definitions,
		"actions": action_definitions
	}
