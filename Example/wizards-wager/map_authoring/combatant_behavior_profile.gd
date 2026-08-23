@tool
class_name CombatantBehaviorProfile
extends Resource

@export var profile_id := ""
@export var initial_state := "patrol"
@export var patrol_mode := "direction"
@export var patrol_direction := -1
@export var patrol_distance := 500.0
@export var patrol_waypoints: Array[Vector2] = []
@export var aggro_distance := 360.0
@export var leash_distance := 900.0
@export var target_factions: PackedStringArray = []
@export var target_archetypes: PackedStringArray = []
@export var target_combatant_kinds: PackedStringArray = []
@export var faction_reactions: Dictionary = {}
@export var on_target_lost := "return_to_patrol"
@export var on_leash_exceeded := "return_home"


func get_definition() -> Dictionary:
	return {
		"profile_id": profile_id,
		"initial_state": initial_state,
		"patrol": {
			"mode": patrol_mode,
			"direction": patrol_direction,
			"distance": patrol_distance,
			"waypoints": _serialize_waypoints()
		},
		"aggro_distance": aggro_distance,
		"leash_distance": leash_distance,
		"target_factions": Array(target_factions),
		"target_archetypes": Array(target_archetypes),
		"target_combatant_kinds": Array(target_combatant_kinds),
		"faction_reactions": faction_reactions,
		"on_target_lost": on_target_lost,
		"on_leash_exceeded": on_leash_exceeded
	}


func _serialize_waypoints() -> Array:
	var serialized: Array = []
	for waypoint in patrol_waypoints:
		serialized.append({"x": waypoint.x, "y": waypoint.y})
	return serialized
