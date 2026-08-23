@tool
class_name DialogueCatalog
extends Node

@export var conversations: Array[DialogueConversation] = []


func get_definitions() -> Array:
	var definitions: Array = []
	for conversation in conversations:
		if conversation != null:
			definitions.append(conversation.get_definition())
	return definitions
