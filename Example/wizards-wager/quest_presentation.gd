extends Control

signal quest_action(action: String, quest_id: String, npc_id: String)

var current_quest_id := ""
var current_npc_id := ""
var secondary_action := ""
var title_label: Label
var description_label: Label
var objectives_label: Label
var rewards_label: Label
var status_label: Label
var accept_button: Button
var secondary_button: Button
var close_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -384.0
	offset_top = 90.0
	offset_right = -24.0
	offset_bottom = 350.0
	_build_ui()
	visible = false


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description_label)
	objectives_label = Label.new()
	objectives_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(objectives_label)
	rewards_label = Label.new()
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rewards_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	accept_button = Button.new()
	accept_button.text = "Accept"
	accept_button.pressed.connect(_emit_accept)
	buttons.add_child(accept_button)
	secondary_button = Button.new()
	secondary_button.text = "Decline"
	secondary_button.pressed.connect(_emit_secondary)
	buttons.add_child(secondary_button)
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close)
	buttons.add_child(close_button)


func show_offer(data: Dictionary) -> void:
	current_quest_id = str(data.get("quest_id", ""))
	current_npc_id = str(data.get("npc_id", data.get("giver_npc_id", "")))
	title_label.text = str(data.get("title", "Quest Offer"))
	description_label.text = str(data.get("description", data.get("offer_text", "")))
	objectives_label.text = _format_objectives(data.get("stages", []), data.get("progress", data.get("objective_progress", [])))
	rewards_label.text = _format_rewards(data.get("rewards", {}))
	status_label.text = "Accept this quest?"
	accept_button.visible = true
	secondary_action = "decline"
	secondary_button.text = "Decline"
	secondary_button.visible = true
	close_button.visible = true
	visible = true
	accept_button.grab_focus()


func show_state(data: Dictionary) -> void:
	_release_owned_focus()
	current_quest_id = str(data.get("quest_id", current_quest_id))
	current_npc_id = str(data.get("npc_id", data.get("giver_npc_id", current_npc_id)))
	title_label.text = str(data.get("title", current_quest_id))
	description_label.text = str(data.get("description", ""))
	objectives_label.text = _format_current_objective(data)
	objectives_label.visible = not objectives_label.text.is_empty()
	rewards_label.text = _format_rewards(data.get("rewards", data.get("rewards_granted", {})))
	var status := str(data.get("status", "active")).to_lower()
	status_label.text = status.capitalize()
	accept_button.visible = false
	secondary_action = "abandon"
	secondary_button.text = "Abandon"
	secondary_button.visible = status == "active" and bool(data.get("can_abandon", true))
	close_button.visible = true
	visible = true


func show_message(message: String) -> void:
	_release_owned_focus()
	status_label.text = message
	accept_button.visible = false
	secondary_button.visible = false
	close_button.visible = true
	visible = true


func _format_current_objective(data: Dictionary) -> String:
	var objective_value: Variant = data.get("objective", null)
	var progress_value: Variant = data.get("objective_progress", data.get("progress", {}))
	if objective_value is Dictionary:
		var objective := objective_value as Dictionary
		var objective_type := str(objective.get("type", objective.get("objective_type", "objective")))
		var target := _objective_target(objective, objective_type)
		var current := 0
		var required := int(objective.get("required_count", 1))
		if progress_value is Dictionary:
			var progress := progress_value as Dictionary
			current = int(progress.get("current", progress.get("current_count", 0)))
			required = int(progress.get("required", required))
		var marker := "[x]" if current >= required else "[ ]"
		return "Objective:\n%s %s: %d / %d" % [marker, "%s %s" % [objective_type.capitalize(), target], current, required]
	return _format_objectives(data.get("stages", []), progress_value)


func _format_objectives(stages_value: Variant, progress_value: Variant) -> String:
	if not stages_value is Array:
		return ""
	var stages := stages_value as Array
	var lines: PackedStringArray = []
	for index in range(stages.size()):
		var stage_value: Variant = stages[index]
		if not stage_value is Dictionary:
			continue
		var stage := stage_value as Dictionary
		var stage_id := str(stage.get("stage_id", ""))
		var current := _objective_progress(progress_value, index, stage_id)
		var objective_type := str(stage.get("type", stage.get("objective_type", "kill")))
		var target := _objective_target(stage, objective_type)
		var required := int(stage.get("required_count", 1))
		var marker := "[x]" if current >= required else "[ ]"
		var label := objective_type.capitalize() + ": " + target
		lines.append("%s %s: %d / %d" % [marker, label, current, required])
	if lines.is_empty():
		return ""
	return "Objectives:\n" + "\n".join(lines)


func _objective_target(objective: Dictionary, objective_type: String) -> String:
	if objective_type in ["talk", "interact"]:
		return str(objective.get("target_npc_id", objective.get("target_object_id", "target")))
	if objective_type == "use_transition":
		return str(objective.get("transition_id", objective.get("target_transition_id", "transition")))
	if objective_type == "enter_map":
		return str(objective.get("target_map_id", objective.get("destination_map_id", "map")))
	if objective_type == "enter_area":
		return str(objective.get("target_area_id", "area"))
	return str(objective.get("target_archetype_id", "target"))


func _objective_progress(progress_value: Variant, index: int, stage_id: String) -> int:
	if progress_value is Array:
		var progress := progress_value as Array
		if index < progress.size() and progress[index] is Dictionary:
			var entry := progress[index] as Dictionary
			return int(entry.get("current_count", entry.get("current", 0)))
	if progress_value is Dictionary:
		var progress_by_stage := progress_value as Dictionary
		var entry_value: Variant = progress_by_stage.get(stage_id, progress_by_stage)
		if entry_value is Dictionary:
			var entry := entry_value as Dictionary
			return int(entry.get("current_count", entry.get("current", 0)))
		if entry_value is int or entry_value is float:
			return int(entry_value)
	return 0


func _format_rewards(rewards_value: Variant) -> String:
	if not rewards_value is Dictionary or (rewards_value as Dictionary).is_empty():
		return ""
	var parts: PackedStringArray = []
	for reward_key_value: Variant in (rewards_value as Dictionary).keys():
		var reward_key := str(reward_key_value)
		var amount := int((rewards_value as Dictionary)[reward_key_value])
		parts.append("%s: %d" % [reward_key.replace("_", " ").capitalize(), amount])
	return "Rewards: %s" % ", ".join(parts)


func _emit_accept() -> void:
	quest_action.emit("accept", current_quest_id, current_npc_id)


func _emit_secondary() -> void:
	if secondary_action.is_empty():
		return
	quest_action.emit(secondary_action, current_quest_id, current_npc_id)


func _close() -> void:
	_release_owned_focus()
	visible = false


func _release_owned_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
