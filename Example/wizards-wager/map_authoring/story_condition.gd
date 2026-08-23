@tool
class_name StoryCondition
extends Resource

@export var condition_id := "condition_1"
@export_enum(
	"quest_not_started",
	"quest_active",
	"quest_stage",
	"quest_complete",
	"quest_failed",
	"faction_is",
	"faction_is_not",
	"reputation_at_least",
	"reputation_at_most",
	"level_at_least",
	"flag_is_set",
	"flag_is_not_set",
	"flag_value",
	"has_item",
	"lacks_item",
	"choice_selected"
) var condition_type := "flag_is_set"
@export var target_id := ""
@export var secondary_id := ""
@export_enum("equals", "not_equals", "at_least", "at_most", "contains") var comparison := "equals"
@export var text_value := ""
@export var number_value := 0
@export_range(1, 999999, 1) var quantity := 1
@export var negated := false


func get_definition() -> Dictionary:
	return {
		"condition_id": condition_id,
		"condition_type": condition_type,
		"target_id": target_id,
		"secondary_id": secondary_id,
		"comparison": comparison,
		"text_value": text_value,
		"number_value": number_value,
		"quantity": quantity,
		"negated": negated
	}


func summary() -> String:
	var value := target_id
	if condition_type in ["reputation_at_least", "reputation_at_most", "level_at_least"]:
		value = "%s %d" % [target_id, number_value]
	elif condition_type in ["has_item", "lacks_item"]:
		value = "%s x%d" % [target_id, quantity]
	elif condition_type == "flag_value":
		value = "%s %s %s" % [target_id, comparison, text_value]
	return "%s%s: %s" % ["NOT " if negated else "", condition_type, value]
