@tool
class_name StoryFlagCatalog
extends Node

@export var flags: Array[StoryFlagDefinition] = []


func get_definitions() -> Array:
	var definitions: Array = []
	for flag in flags:
		if flag != null:
			definitions.append(flag.get_definition())
	return definitions
