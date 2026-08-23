@tool
class_name CombatantSpawnArea
extends Node2D

enum PlacementMode { FIXED, RANDOM_IN_BOUNDS }

@export var spawn_id := "spawn_1"
@export var enabled := true
@export var display_name := "Character Spawn"
@export var combatant_kind := "npc"
@export var archetype_id := "zombie"
@export var visual_id := ""
@export var faction_id := "neutral"
@export_range(1, 999, 1) var spawn_count := 1
@export var placement_mode: PlacementMode = PlacementMode.FIXED
@export var bounds := Vector2(256.0, 128.0):

	set(value):
		bounds = value
		queue_redraw()

@export var behavior_profile_id := ""
@export var behavior_profile: CombatantBehaviorProfile
@export var surface_id := ""
@export_range(0, 86400, 1) var respawn_delay_seconds := 30
@export var leash_distance := 900.0
@export var aggro_distance := 360.0
@export_range(1, 999, 1) var minimum_level := 1
@export_range(1, 999, 1) var maximum_level := 1
@export_category("Combat Stats")
@export_range(0, 999999, 1) var max_health := 0
@export_range(0, 999999, 1) var damage := 0
@export_range(0, 999999, 1) var defense := 0
@export_category("Stat Overrides")
@export var stat_overrides: Dictionary = {}
@export_category("Target Filters")
@export var hostile_factions: PackedStringArray = []
@export var hostile_archetypes: PackedStringArray = []


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func get_definition() -> Dictionary:
	var resolved_behavior_profile_id := behavior_profile_id
	var behavior_definition: Dictionary = {}
	if behavior_profile != null:
		resolved_behavior_profile_id = behavior_profile.profile_id
		behavior_definition = behavior_profile.get_definition()
	var resolved_stat_overrides: Dictionary = stat_overrides.duplicate()
	if max_health > 0:
		resolved_stat_overrides["max_health"] = max_health
	if damage > 0:
		resolved_stat_overrides["damage"] = damage
	if defense > 0:
		resolved_stat_overrides["defense"] = defense
	return {
		"spawn_id": spawn_id,
		"combatant_kind": combatant_kind,
		"archetype_id": archetype_id,
		"visual_id": visual_id if not visual_id.is_empty() else archetype_id,
		"faction_id": faction_id,
		"spawn_count": spawn_count,
		"placement_mode": "fixed" if placement_mode == PlacementMode.FIXED else "random_in_bounds",
		"position": {"x": global_position.x, "y": global_position.y},
		"bounds": {"x": bounds.x, "y": bounds.y},
		"surface_id": surface_id,
		"behavior_profile_id": resolved_behavior_profile_id,
		"behavior_profile": behavior_definition,
		"respawn_delay_seconds": int(respawn_delay_seconds),
		"leash_distance": leash_distance,
		"aggro_distance": aggro_distance,
		"stat_overrides": resolved_stat_overrides,
		"hostile_factions": Array(hostile_factions),
		"hostile_archetypes": Array(hostile_archetypes)
	}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(1.0, 0.55, 0.2, 0.22) if faction_id == "enemy" else Color(0.75, 0.35, 1.0, 0.22)
	if not enabled:
		color = Color(0.45, 0.45, 0.45, 0.16)
	if placement_mode == PlacementMode.FIXED:
		draw_circle(Vector2.ZERO, 14.0, color)
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	else:
		draw_rect(Rect2(-bounds * 0.5, bounds), color, true)
		draw_rect(Rect2(-bounds * 0.5, bounds), Color.WHITE, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-bounds.x * 0.5, -bounds.y * 0.5 - 8.0), "%s: %s x%d [%s]" % [spawn_id, archetype_id, spawn_count, faction_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
