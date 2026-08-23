@tool
class_name DialogueConversation
extends Resource

@export var conversation_id := "conversation_1"
@export var display_name := "New Conversation"
@export var owning_map_id := ""
@export var starting_node_id := ""
@export var player_may_exit := true
@export var lock_local_input := true
@export var default_cinematic_id := ""
@export_multiline var fallback_text := "They have nothing to say right now."
@export var nodes: Array[DialogueNode] = []


func get_definition() -> Dictionary:
	var node_definitions: Array = []
	for node in nodes:
		if node != null:
			node_definitions.append(node.get_definition())
	return {
		"conversation_id": conversation_id,
		"display_name": display_name,
		"owning_map_id": owning_map_id,
		"starting_node_id": starting_node_id,
		"player_may_exit": player_may_exit,
		"lock_local_input": lock_local_input,
		"default_cinematic_id": default_cinematic_id,
		"fallback_text": fallback_text,
		"nodes": node_definitions
	}
