@tool
class_name DialogueNode
extends Resource

@export var node_id := "node_1"
@export var speaker_npc_id := ""
@export var speaker_name_override := ""
@export_multiline var text := ""
@export var portrait_id := ""
@export var expression_id := ""
@export var editor_position := Vector2.ZERO
@export var automatic_next_node_id := ""
@export var cinematic_id := ""
@export var cinematic_cue_id := ""
@export var ends_conversation := false
@export var intentional_loop := false
@export_enum("all", "any") var condition_logic := "all"
@export var conditions: Array[StoryCondition] = []
@export var actions: Array[StoryAction] = []
@export var choices: Array[DialogueChoice] = []


func get_definition() -> Dictionary:
	var condition_definitions: Array = []
	for condition in conditions:
		if condition != null:
			condition_definitions.append(condition.get_definition())
	var action_definitions: Array = []
	for action in actions:
		if action != null:
			action_definitions.append(action.get_definition())
	var choice_definitions: Array = []
	for choice in choices:
		if choice != null:
			choice_definitions.append(choice.get_definition())
	return {
		"node_id": node_id,
		"speaker_npc_id": speaker_npc_id,
		"speaker_name_override": speaker_name_override,
		"text": text,
		"portrait_id": portrait_id,
		"expression_id": expression_id,
		"editor_position": {"x": editor_position.x, "y": editor_position.y},
		"automatic_next_node_id": automatic_next_node_id,
		"cinematic_id": cinematic_id,
		"cinematic_cue_id": cinematic_cue_id,
		"ends_conversation": ends_conversation,
		"intentional_loop": intentional_loop,
		"condition_logic": condition_logic,
		"conditions": condition_definitions,
		"actions": action_definitions,
		"choices": choice_definitions
	}
