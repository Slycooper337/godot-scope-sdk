extends Node2D

var map_root: MapRoot
var conversation: DialogueConversation
var dialogue_ui: DialoguePresentation
var director: CinematicDirector
var preview_player: Node2D
var camera: Camera2D
var canvas: CanvasLayer

var current_node: DialogueNode
var simulated_level := 1
var simulated_faction := ""
var simulated_reputation := 0
var simulated_active_quests: PackedStringArray = []
var simulated_completed_quests: PackedStringArray = []
var simulated_items: Dictionary = {}
var simulated_flags: Dictionary = {}

var level_input: SpinBox
var faction_input: LineEdit
var reputation_input: SpinBox
var active_quests_input: LineEdit
var completed_quests_input: LineEdit
var items_input: LineEdit
var flags_input: LineEdit
var node_input: OptionButton


func _ready() -> void:
	_load_content()
	_build_preview_world()
	_build_state_panel()
	_restart_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _load_content() -> void:
	var map_path := str(ProjectSettings.get_setting("map_authoring/preview_map_scene", ""))
	var conversation_path := str(ProjectSettings.get_setting("map_authoring/preview_conversation_path", ""))
	var packed := load(map_path) as PackedScene
	if packed != null:
		map_root = packed.instantiate() as MapRoot
		if map_root != null:
			add_child(map_root)
	conversation = load(conversation_path) as DialogueConversation


func _build_preview_world() -> void:
	preview_player = Node2D.new()
	preview_player.name = "PreviewPlayer"
	preview_player.position = _first_spawn_position()
	add_child(preview_player)
	camera = Camera2D.new()
	camera.enabled = true
	preview_player.add_child(camera)
	canvas = CanvasLayer.new()
	add_child(canvas)
	director = CinematicDirector.new()
	add_child(director)
	director.setup(preview_player, camera, map_root, canvas)
	dialogue_ui = DialoguePresentation.new()
	canvas.add_child(dialogue_ui)
	dialogue_ui.dialogue_action.connect(_on_dialogue_action)
	dialogue_ui.move_to_front()


func _build_state_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14.0, 14.0)
	panel.size = Vector2(330.0, 390.0)
	canvas.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "DIALOGUE PREVIEW STATE"
	content.add_child(title)
	node_input = OptionButton.new()
	if conversation != null:
		for node in conversation.nodes:
			if node != null:
				node_input.add_item(node.node_id)
				node_input.set_item_metadata(node_input.item_count - 1, node.node_id)
				if node.node_id == conversation.starting_node_id:
					node_input.select(node_input.item_count - 1)
	content.add_child(_field("Starting node", node_input))
	level_input = SpinBox.new()
	level_input.min_value = 1
	level_input.max_value = 999
	level_input.value = 1
	content.add_child(_field("Level", level_input))
	faction_input = LineEdit.new()
	faction_input.placeholder_text = "justice, avenger, or blank"
	content.add_child(_field("Faction", faction_input))
	reputation_input = SpinBox.new()
	reputation_input.min_value = -1000
	reputation_input.max_value = 1000
	content.add_child(_field("Reputation", reputation_input))
	active_quests_input = LineEdit.new()
	active_quests_input.placeholder_text = "quest_a, quest_b"
	content.add_child(_field("Active quests", active_quests_input))
	completed_quests_input = LineEdit.new()
	completed_quests_input.placeholder_text = "quest_a, quest_b"
	content.add_child(_field("Completed quests", completed_quests_input))
	items_input = LineEdit.new()
	items_input.placeholder_text = "key:1, potion:3"
	content.add_child(_field("Items", items_input))
	flags_input = LineEdit.new()
	flags_input.placeholder_text = "met_guide, chose_mercy"
	content.add_child(_field("True flags", flags_input))
	var restart := Button.new()
	restart.text = "Apply State and Restart"
	restart.pressed.connect(_restart_preview)
	content.add_child(restart)
	var help := Label.new()
	help.text = "Choices display condition failures.\nPreview actions affect only this preview.\nEsc closes."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)


func _field(label_text: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(control)
	return box


func _restart_preview() -> void:
	if conversation == null:
		return
	simulated_level = int(level_input.value)
	simulated_faction = faction_input.text.strip_edges()
	simulated_reputation = int(reputation_input.value)
	simulated_active_quests = _csv(active_quests_input.text)
	simulated_completed_quests = _csv(completed_quests_input.text)
	simulated_items = _key_values(items_input.text)
	simulated_flags.clear()
	for flag_id in _csv(flags_input.text):
		simulated_flags[flag_id] = true
	var starting_node_id := conversation.starting_node_id
	if node_input.item_count > 0 and node_input.selected >= 0:
		starting_node_id = str(node_input.get_item_metadata(node_input.selected))
	current_node = _find_node(starting_node_id)
	_show_current_node()


func _show_current_node() -> void:
	if current_node == null:
		dialogue_ui.hide_dialogue()
		return
	var node_result := _conditions_result(current_node.conditions, current_node.condition_logic)
	if not bool(node_result.get("passed", false)):
		dialogue_ui.show_node({
			"dialogue_session_id": "preview",
			"conversation_id": conversation.conversation_id,
			"node_id": current_node.node_id,
			"speaker_name": "Preview",
			"text": "This node is unavailable with the simulated state.",
			"choices": [],
			"can_continue": false,
			"player_may_exit": true,
			"message": str(node_result.get("reason", "")),
			"dialogue_revision": Time.get_ticks_usec()
		})
		return
	_apply_actions(current_node.actions)
	var choice_definitions: Array = []
	for choice in current_node.choices:
		if choice == null:
			continue
		var result := _conditions_result(choice.conditions, choice.condition_logic)
		choice_definitions.append({
			"choice_id": choice.choice_id,
			"text": choice.text,
			"available": bool(result.get("passed", false)),
			"disabled_explanation": choice.disabled_explanation if not choice.disabled_explanation.is_empty() else str(result.get("reason", "")),
			"requires_confirmation": choice.requires_confirmation
		})
	dialogue_ui.show_node({
		"dialogue_session_id": "preview",
		"conversation_id": conversation.conversation_id,
		"node_id": current_node.node_id,
		"speaker_name": _speaker_name(current_node),
		"text": current_node.text,
		"choices": choice_definitions,
		"can_continue": not current_node.automatic_next_node_id.is_empty(),
		"player_may_exit": conversation.player_may_exit,
		"dialogue_revision": Time.get_ticks_usec()
	})
	if not current_node.cinematic_id.is_empty():
		_play_cinematic(current_node.cinematic_id)


func _on_dialogue_action(action: String, _session_id: String, _conversation_id: String, _node_id: String, choice_id: String) -> void:
	match action:
		"choose":
			var choice := _find_choice(choice_id)
			if choice == null:
				return
			_apply_actions(choice.actions)
			current_node = _find_node(choice.destination_node_id)
			_show_current_node()
		"continue":
			current_node = _find_node(current_node.automatic_next_node_id)
			_show_current_node()
		"exit":
			dialogue_ui.hide_dialogue()


func _conditions_result(conditions: Array[StoryCondition], condition_logic := "all") -> Dictionary:
	if conditions.is_empty():
		return {"passed": true, "reason": ""}
	var failed_reasons: PackedStringArray = []
	var any_passed := false
	for condition in conditions:
		if condition == null:
			continue
		var passed := _condition_passes(condition)
		if condition.negated:
			passed = not passed
		if passed:
			any_passed = true
		else:
			failed_reasons.append(condition.summary())
	if condition_logic == "any":
		return {"passed": any_passed, "reason": "" if any_passed else "Requires any: %s" % ", ".join(failed_reasons)}
	return {"passed": failed_reasons.is_empty(), "reason": "" if failed_reasons.is_empty() else "Requires %s" % ", ".join(failed_reasons)}


func _condition_passes(condition: StoryCondition) -> bool:
	match condition.condition_type:
		"quest_not_started":
			return not simulated_active_quests.has(condition.target_id) and not simulated_completed_quests.has(condition.target_id)
		"quest_active", "quest_stage":
			return simulated_active_quests.has(condition.target_id)
		"quest_complete":
			return simulated_completed_quests.has(condition.target_id)
		"quest_failed":
			return false
		"faction_is":
			return simulated_faction == condition.target_id
		"faction_is_not":
			return simulated_faction != condition.target_id
		"reputation_at_least":
			return simulated_faction == condition.target_id and simulated_reputation >= condition.number_value
		"reputation_at_most":
			return simulated_faction == condition.target_id and simulated_reputation <= condition.number_value
		"level_at_least":
			return simulated_level >= condition.number_value
		"flag_is_set":
			return bool(simulated_flags.get(condition.target_id, false))
		"flag_is_not_set":
			return not bool(simulated_flags.get(condition.target_id, false))
		"flag_value":
			return str(simulated_flags.get(condition.target_id, "")) == condition.text_value
		"has_item":
			return int(simulated_items.get(condition.target_id, 0)) >= condition.quantity
		"lacks_item":
			return int(simulated_items.get(condition.target_id, 0)) < condition.quantity
		"choice_selected":
			return bool(simulated_flags.get("choice:%s" % condition.target_id, false))
	return true


func _apply_actions(actions: Array[StoryAction]) -> void:
	for action in actions:
		if action == null:
			continue
		match action.action_type:
			"set_flag":
				simulated_flags[action.target_id] = true if action.text_value.is_empty() else action.text_value
			"clear_flag":
				simulated_flags.erase(action.target_id)
			"increment_flag":
				simulated_flags[action.target_id] = int(simulated_flags.get(action.target_id, 0)) + action.amount
			"change_reputation":
				if simulated_faction == action.target_id:
					simulated_reputation += action.amount
			"commit_faction":
				simulated_faction = action.target_id
			"give_item":
				simulated_items[action.target_id] = int(simulated_items.get(action.target_id, 0)) + action.amount
			"remove_item":
				simulated_items[action.target_id] = maxi(0, int(simulated_items.get(action.target_id, 0)) - action.amount)
			"start_cinematic":
				_play_cinematic(action.target_id)


func _play_cinematic(cinematic_id: String) -> void:
	if map_root == null:
		return
	var definition := map_root.collect_definition()
	for cinematic_value in definition.get("cinematic_sequences", []):
		if cinematic_value is Dictionary and str((cinematic_value as Dictionary).get("cinematic_id", "")) == cinematic_id:
			director.play_sequence(cinematic_value)
			return


func _find_node(node_id: String) -> DialogueNode:
	if conversation == null:
		return null
	for node in conversation.nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func _find_choice(choice_id: String) -> DialogueChoice:
	if current_node == null:
		return null
	for choice in current_node.choices:
		if choice != null and choice.choice_id == choice_id:
			simulated_flags["choice:%s" % choice_id] = true
			return choice
	return null


func _speaker_name(node: DialogueNode) -> String:
	if not node.speaker_name_override.is_empty():
		return node.speaker_name_override
	if map_root != null:
		for character in map_root.collect_definition().get("quest_givers", []):
			if character is Dictionary and str((character as Dictionary).get("npc_id", "")) == node.speaker_npc_id:
				return str((character as Dictionary).get("display_name", node.speaker_npc_id))
	return node.speaker_npc_id


func _first_spawn_position() -> Vector2:
	if map_root == null:
		return Vector2.ZERO
	for spawn in map_root.collect_definition().get("player_spawns", []):
		if spawn is Dictionary:
			var position: Dictionary = (spawn as Dictionary).get("position", {})
			return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
	return Vector2.ZERO


func _csv(value: String) -> PackedStringArray:
	var values: PackedStringArray = []
	for part in value.split(",", false):
		var normalized := part.strip_edges()
		if not normalized.is_empty():
			values.append(normalized)
	return values


func _key_values(value: String) -> Dictionary:
	var values: Dictionary = {}
	for part in value.split(",", false):
		var sections := part.split(":", false, 1)
		var key := sections[0].strip_edges()
		if key.is_empty():
			continue
		values[key] = int(sections[1]) if sections.size() > 1 else 1
	return values
