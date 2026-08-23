@tool
class_name StoryFlagDefinition
extends Resource

@export var flag_id := "story_flag_1"
@export var display_name := "Story Flag"
@export_multiline var description := ""
@export_enum("boolean", "integer", "string") var value_type := "boolean"
@export var default_boolean := false
@export var default_integer := 0
@export var default_string := ""
@export var category := "story"
@export var visible_in_development := true


func default_value() -> Variant:
	match value_type:
		"integer":
			return default_integer
		"string":
			return default_string
	return default_boolean


func get_definition() -> Dictionary:
	return {
		"flag_id": flag_id,
		"display_name": display_name,
		"description": description,
		"value_type": value_type,
		"default_value": default_value(),
		"category": category,
		"visible_in_development": visible_in_development
	}
