@tool
class_name StoryAction
extends Resource

@export var action_id := "action_1"
@export_enum(
	"set_flag",
	"clear_flag",
	"increment_flag",
	"offer_quest",
	"advance_quest",
	"complete_objective",
	"give_item",
	"remove_item",
	"give_gold",
	"give_experience",
	"change_reputation",
	"commit_faction",
	"start_cinematic",
	"transition_player",
	"end_conversation"
) var action_type := "set_flag"
@export var target_id := ""
@export var secondary_id := ""
@export var text_value := ""
@export var amount := 0
@export var target_map_id := ""
@export var target_spawn_id := ""
@export var requires_confirmation := false


func get_definition() -> Dictionary:
	return {
		"action_id": action_id,
		"action_type": action_type,
		"target_id": target_id,
		"secondary_id": secondary_id,
		"text_value": text_value,
		"amount": amount,
		"target_map_id": target_map_id,
		"target_spawn_id": target_spawn_id,
		"requires_confirmation": requires_confirmation
	}


func summary() -> String:
	var target := target_id
	if action_type in ["give_gold", "give_experience"]:
		target = str(amount)
	elif action_type in ["give_item", "remove_item", "change_reputation", "increment_flag"]:
		target = "%s %s%d" % [target_id, "+" if amount >= 0 else "", amount]
	elif action_type == "transition_player":
		target = "%s/%s" % [target_map_id, target_spawn_id]
	return "%s: %s" % [action_type, target]
