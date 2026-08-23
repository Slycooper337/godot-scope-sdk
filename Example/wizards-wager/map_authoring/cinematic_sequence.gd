@tool
class_name CinematicSequence
extends Resource

@export var cinematic_id := "cinematic_1"
@export var display_name := "New Cinematic"
@export var owning_map_id := ""
@export var skippable := true
@export var restore_camera_on_end := true
@export var restore_input_on_end := true
@export var cues: Array[CinematicCue] = []


func get_definition() -> Dictionary:
	var cue_definitions: Array = []
	for cue in cues:
		if cue != null:
			cue_definitions.append(cue.get_definition())
	return {
		"cinematic_id": cinematic_id,
		"display_name": display_name,
		"owning_map_id": owning_map_id,
		"skippable": skippable,
		"restore_camera_on_end": restore_camera_on_end,
		"restore_input_on_end": restore_input_on_end,
		"cues": cue_definitions
	}
