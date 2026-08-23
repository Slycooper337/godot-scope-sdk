@tool
class_name QuestGiver
extends Node2D

@export var npc_id := "quest_giver_1"
@export var display_name := "Quest Giver"
@export var archetype_id := "npc"
@export var faction_id := "neutral"
@export var visual_id := "default_character"
@export var combatant_kind := "npc"
@export var interaction_type := "talk"
@export_multiline var dialogue_text := ""
@export_category("Dialogue and Story")
@export var default_conversation_id := ""
@export var conditional_conversations: Array[ConditionalConversation] = []
@export var conversation_priority := 0
@export_multiline var one_time_greeting := ""
@export_multiline var repeat_greeting := ""
@export_multiline var ambient_lines: PackedStringArray = []
@export var invulnerable := true
@export var enabled := true
@export_category("Combat Stats")
@export_range(0, 999999, 1) var max_health := 0
@export_range(0, 999999, 1) var damage := 0
@export_range(0, 999999, 1) var defense := 0
@export_category("Stat Overrides")
@export var stat_overrides: Dictionary = {}
@export var surface_id := ""
@export var quest_ids: PackedStringArray = []
@export var interaction_radius := 96.0

var quest_marker_state := "none"


func get_definition() -> Dictionary:
	var resolved_stat_overrides: Dictionary = stat_overrides.duplicate()
	if max_health > 0:
		resolved_stat_overrides["max_health"] = max_health
	if damage > 0:
		resolved_stat_overrides["damage"] = damage
	if defense > 0:
		resolved_stat_overrides["defense"] = defense
	var definition := {
		"npc_id": npc_id,
		"display_name": display_name,
		"archetype_id": archetype_id,
		"faction_id": faction_id,
		"visual_id": visual_id,
		"combatant_kind": combatant_kind,
		"stat_overrides": resolved_stat_overrides,
		"position": {"x": global_position.x, "y": global_position.y},
		"surface_id": surface_id,
		"interaction_radius": interaction_radius,
		"quest_ids": Array(quest_ids)
	}
	if interaction_type != "talk":
		definition["interaction_type"] = interaction_type
	if not dialogue_text.is_empty():
		definition["dialogue_text"] = dialogue_text
	var conversation_entries: Array = []
	for entry in conditional_conversations:
		if entry != null:
			conversation_entries.append(entry.get_definition())
	if not default_conversation_id.is_empty() or not conversation_entries.is_empty():
		definition["default_conversation_id"] = default_conversation_id
		definition["conditional_conversations"] = conversation_entries
		definition["conversation_priority"] = conversation_priority
		definition["one_time_greeting"] = one_time_greeting
		definition["repeat_greeting"] = repeat_greeting
		definition["ambient_lines"] = Array(ambient_lines)
	if not invulnerable:
		definition["invulnerable"] = false
	return definition


func set_quest_marker_state(state: String) -> void:
	var normalized := state.to_lower()
	if not ["none", "available", "active", "completable"].has(normalized):
		normalized = "none"
	if quest_marker_state == normalized:
		return
	quest_marker_state = normalized
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 14.0, Color(0.2, 0.85, 0.55, 0.25))
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.75), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-70.0, -24.0), "%s [%s]" % [display_name, visual_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return
	if quest_marker_state == "none":
		return
	var marker := "!" if quest_marker_state == "available" else ("?" if quest_marker_state == "completable" else "...")
	var marker_color := Color(1.0, 0.85, 0.2) if quest_marker_state != "active" else Color(0.45, 0.75, 1.0)
	draw_circle(Vector2(0.0, -34.0), 14.0, Color(0.05, 0.05, 0.08, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-7.0, -28.0), marker, HORIZONTAL_ALIGNMENT_CENTER, 14.0, 18, marker_color)
