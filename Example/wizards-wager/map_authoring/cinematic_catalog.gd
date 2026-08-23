@tool
class_name CinematicCatalog
extends Node

@export var sequences: Array[CinematicSequence] = []


func get_definitions() -> Array:
	var definitions: Array = []
	for sequence in sequences:
		if sequence != null:
			definitions.append(sequence.get_definition())
	return definitions
