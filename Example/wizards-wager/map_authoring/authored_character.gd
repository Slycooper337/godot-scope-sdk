@tool
class_name AuthoredCharacter
extends QuestGiver

## Unified manually placed character. This covers civilians, guards, quest
## characters, allies, and enemies that use the shared character animation
## system. It intentionally remains a QuestGiver subclass so existing runtime
## interaction and backend map definitions stay compatible.

@export var behavior_profile_id := ""
@export var behavior_profile: CombatantBehaviorProfile
@export var respawn_delay_seconds := 0
@export var aggro_distance := 0.0
@export var leash_distance := 0.0
@export var hostile_factions: PackedStringArray = []
@export var hostile_archetypes: PackedStringArray = []


func get_definition() -> Dictionary:
	var definition := super.get_definition()
	var resolved_profile_id := behavior_profile_id
	var behavior_definition: Dictionary = {}
	if behavior_profile != null:
		resolved_profile_id = behavior_profile.profile_id
		behavior_definition = behavior_profile.get_definition()
	definition["behavior_profile_id"] = resolved_profile_id
	definition["behavior_profile"] = behavior_definition
	definition["respawn_delay_seconds"] = respawn_delay_seconds
	definition["aggro_distance"] = aggro_distance
	definition["leash_distance"] = leash_distance
	definition["hostile_factions"] = Array(hostile_factions)
	definition["hostile_archetypes"] = Array(hostile_archetypes)
	return definition


func _draw() -> void:
	if Engine.is_editor_hint():
		var color := Color(0.95, 0.35, 0.25, 0.3) if not hostile_factions.is_empty() else Color(0.2, 0.85, 0.55, 0.25)
		draw_circle(Vector2.ZERO, 16.0, color)
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color.WHITE, 2.0)
		draw_circle(Vector2.ZERO, interaction_radius, Color(color.r, color.g, color.b, 0.06))
		draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 32, color.lightened(0.35), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-70.0, -24.0), "%s [%s/%s]" % [display_name, archetype_id, faction_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return
	super._draw()
