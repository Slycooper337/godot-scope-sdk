@tool
class_name StorytellingBuilderPanel
extends VBoxContainer

signal status_changed(message: String)

var editor_plugin: EditorPlugin
var map_root: MapRoot
var world_catalog: Dictionary = {}

var conversation_selector: OptionButton
var conversation_search: LineEdit
var graph: GraphEdit
var node_list: ItemList
var choice_list: ItemList
var flag_selector: OptionButton
var cinematic_selector: OptionButton
var cue_list: ItemList

var current_conversation: DialogueConversation
var current_node: DialogueNode
var current_choice: DialogueChoice
var current_cinematic: CinematicSequence
var current_cue_index := -1
var graph_choice_ports: Dictionary = {}


func setup(plugin: EditorPlugin) -> void:
	editor_plugin = plugin
	_build_ui()


func refresh(current_map: MapRoot, catalog: Dictionary) -> void:
	map_root = current_map
	world_catalog = catalog
	_refresh_conversations()
	_refresh_flags()
	_refresh_cinematics()


func _build_ui() -> void:
	var conversation_heading := Label.new()
	conversation_heading.text = "Dialogue Conversations"
	conversation_heading.add_theme_font_size_override("font_size", 15)
	add_child(conversation_heading)
	var conversation_row := HBoxContainer.new()
	add_child(conversation_row)
	conversation_selector = OptionButton.new()
	conversation_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation_selector.item_selected.connect(_on_conversation_selected)
	conversation_row.add_child(conversation_selector)
	_button(conversation_row, "New", _new_conversation)
	_button(conversation_row, "Duplicate", _duplicate_conversation)
	_button(conversation_row, "Delete", _delete_conversation)
	conversation_search = LineEdit.new()
	conversation_search.placeholder_text = "Search conversations by ID or text"
	conversation_search.text_changed.connect(_on_conversation_search_changed)
	add_child(conversation_search)
	var conversation_tools := HBoxContainer.new()
	add_child(conversation_tools)
	_button(conversation_tools, "Edit Details", _edit_current_conversation)
	_button(conversation_tools, "Assign to NPC", _assign_to_selected_npc)
	_button(conversation_tools, "Conditional Entry", _add_conditional_entry)
	_button(conversation_tools, "Select Owning NPC", _select_owning_npc)

	graph = GraphEdit.new()
	graph.custom_minimum_size = Vector2(340.0, 360.0)
	graph.show_grid = true
	graph.snapping_enabled = true
	graph.connection_request.connect(_on_graph_connection_requested)
	graph.disconnection_request.connect(_on_graph_disconnection_requested)
	add_child(graph)
	var node_tools := HBoxContainer.new()
	add_child(node_tools)
	_button(node_tools, "Add Node", _add_dialogue_node)
	_button(node_tools, "Edit Node", _edit_current_node)
	_button(node_tools, "Delete Node", _delete_current_node)
	_button(node_tools, "Set as Start", _set_current_node_as_start)
	node_list = ItemList.new()
	node_list.custom_minimum_size.y = 90.0
	node_list.item_selected.connect(_on_node_list_selected)
	add_child(node_list)
	var choice_tools := HBoxContainer.new()
	add_child(choice_tools)
	_button(choice_tools, "Add Choice", _add_choice)
	_button(choice_tools, "Edit Choice", _edit_current_choice)
	_button(choice_tools, "Delete Choice", _delete_current_choice)
	choice_list = ItemList.new()
	choice_list.custom_minimum_size.y = 80.0
	choice_list.item_selected.connect(_on_choice_selected)
	add_child(choice_list)
	var logic_tools := GridContainer.new()
	logic_tools.columns = 2
	add_child(logic_tools)
	_button(logic_tools, "Node Condition", _add_node_condition)
	_button(logic_tools, "Node Action", _add_node_action)
	_button(logic_tools, "Choice Condition", _add_choice_condition)
	_button(logic_tools, "Choice Action", _add_choice_action)
	_button(logic_tools, "Preview Conversation", _preview_conversation)
	_button(logic_tools, "Save Conversation", _save_current_conversation)

	var flag_heading := Label.new()
	flag_heading.text = "Story Flags"
	flag_heading.add_theme_font_size_override("font_size", 15)
	add_child(flag_heading)
	var flag_row := HBoxContainer.new()
	add_child(flag_row)
	flag_selector = OptionButton.new()
	flag_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_row.add_child(flag_selector)
	_button(flag_row, "New", _new_flag)
	_button(flag_row, "Edit", _edit_flag)
	_button(flag_row, "Delete", _delete_flag)

	var cinematic_heading := Label.new()
	cinematic_heading.text = "Cinematic Sequences"
	cinematic_heading.add_theme_font_size_override("font_size", 15)
	add_child(cinematic_heading)
	var cinematic_row := HBoxContainer.new()
	add_child(cinematic_row)
	cinematic_selector = OptionButton.new()
	cinematic_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_selector.item_selected.connect(_on_cinematic_selected)
	cinematic_row.add_child(cinematic_selector)
	_button(cinematic_row, "New", _new_cinematic)
	_button(cinematic_row, "Edit", _edit_current_cinematic)
	_button(cinematic_row, "Delete", _delete_cinematic)
	cue_list = ItemList.new()
	cue_list.custom_minimum_size.y = 90.0
	cue_list.item_selected.connect(_on_cue_selected)
	add_child(cue_list)
	var cue_tools := GridContainer.new()
	cue_tools.columns = 3
	add_child(cue_tools)
	_button(cue_tools, "Add Cue", _add_cue)
	_button(cue_tools, "Edit Cue", _edit_cue)
	_button(cue_tools, "Remove Cue", _remove_cue)
	_button(cue_tools, "Cue Up", _move_cue.bind(-1))
	_button(cue_tools, "Cue Down", _move_cue.bind(1))
	_button(cue_tools, "Save Cinematic", _save_current_cinematic)


func _button(parent: Node, text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callable)
	parent.add_child(button)
	return button


func _dialogue_catalog() -> DialogueCatalog:
	if map_root == null:
		return null
	for node in map_root.find_children("*", "", true, false):
		if node is DialogueCatalog:
			return node as DialogueCatalog
	return null


func _flag_catalog() -> StoryFlagCatalog:
	if map_root == null:
		return null
	for node in map_root.find_children("*", "", true, false):
		if node is StoryFlagCatalog:
			return node as StoryFlagCatalog
	return null


func _cinematic_catalog() -> CinematicCatalog:
	if map_root == null:
		return null
	for node in map_root.find_children("*", "", true, false):
		if node is CinematicCatalog:
			return node as CinematicCatalog
	return null


func _ensure_catalogs() -> void:
	if map_root == null:
		return
	var container := map_root.get_node_or_null("Storytelling")
	if container == null:
		container = Node.new()
		container.name = "Storytelling"
		map_root.add_child(container)
		container.owner = map_root
	if _dialogue_catalog() == null:
		var dialogue_catalog := DialogueCatalog.new()
		dialogue_catalog.name = "DialogueCatalog"
		container.add_child(dialogue_catalog)
		dialogue_catalog.owner = map_root
	if _flag_catalog() == null:
		var flag_catalog := StoryFlagCatalog.new()
		flag_catalog.name = "StoryFlagCatalog"
		container.add_child(flag_catalog)
		flag_catalog.owner = map_root
	if _cinematic_catalog() == null:
		var cinematic_catalog := CinematicCatalog.new()
		cinematic_catalog.name = "CinematicCatalog"
		container.add_child(cinematic_catalog)
		cinematic_catalog.owner = map_root
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()


func _refresh_conversations() -> void:
	conversation_selector.clear()
	current_conversation = null
	current_node = null
	current_choice = null
	var filter := conversation_search.text.strip_edges().to_lower() if conversation_search != null else ""
	var catalog := _dialogue_catalog()
	if catalog != null:
		for conversation in catalog.conversations:
			if conversation == null:
				continue
			var searchable := "%s %s" % [conversation.conversation_id, conversation.display_name]
			for dialogue_node in conversation.nodes:
				if dialogue_node != null:
					searchable += " %s" % dialogue_node.text
			if not filter.is_empty() and not searchable.to_lower().contains(filter):
				continue
			conversation_selector.add_item("%s — %s" % [conversation.conversation_id, conversation.display_name])
			conversation_selector.set_item_metadata(conversation_selector.item_count - 1, conversation)
	if conversation_selector.item_count > 0:
		conversation_selector.select(0)
		_on_conversation_selected(0)
	else:
		_rebuild_graph()


func _on_conversation_search_changed(_value: String) -> void:
	_refresh_conversations()


func _new_conversation() -> void:
	if map_root == null:
		_emit("Open a map before creating dialogue.")
		return
	_ensure_catalogs()
	var catalog := _dialogue_catalog()
	var conversation := DialogueConversation.new()
	conversation.conversation_id = _unique_conversation_id("new_conversation")
	conversation.display_name = "New Conversation"
	conversation.owning_map_id = map_root.map_id
	var start := DialogueNode.new()
	start.node_id = "start"
	start.text = "New dialogue"
	start.editor_position = Vector2(40.0, 80.0)
	start.ends_conversation = true
	conversation.starting_node_id = start.node_id
	conversation.nodes = [start]
	var folder := "res://maps/%s/dialogue" % map_root.map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join("%s.tres" % conversation.conversation_id)
	if ResourceSaver.save(conversation, path) != OK:
		_emit("Could not save the new conversation.")
		return
	catalog.conversations.append(conversation)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_conversations()
	_select_conversation(conversation.conversation_id)
	editor_plugin.get_editor_interface().edit_resource(conversation)


func _duplicate_conversation() -> void:
	if current_conversation == null or map_root == null:
		return
	var duplicate := current_conversation.duplicate(true) as DialogueConversation
	duplicate.conversation_id = _unique_conversation_id("%s_copy" % current_conversation.conversation_id)
	duplicate.display_name = "%s Copy" % current_conversation.display_name
	var path := "res://maps/%s/dialogue/%s.tres" % [map_root.map_id, duplicate.conversation_id]
	if ResourceSaver.save(duplicate, path) != OK:
		_emit("Could not save the duplicated conversation.")
		return
	_dialogue_catalog().conversations.append(duplicate)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_conversations()
	_select_conversation(duplicate.conversation_id)


func _delete_conversation() -> void:
	if current_conversation == null:
		return
	var deleted_id := current_conversation.conversation_id
	var path := current_conversation.resource_path
	_dialogue_catalog().conversations.erase(current_conversation)
	for node in map_root.find_children("*", "", true, false):
		if not node is QuestGiver:
			continue
		var character := node as QuestGiver
		if character.default_conversation_id == deleted_id:
			character.default_conversation_id = ""
		for index in range(character.conditional_conversations.size() - 1, -1, -1):
			if character.conditional_conversations[index] != null and character.conditional_conversations[index].conversation_id == deleted_id:
				character.conditional_conversations.remove_at(index)
	if path.begins_with("res://maps/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_conversations()
	_emit("Deleted conversation %s." % deleted_id)


func _on_conversation_selected(index: int) -> void:
	if index < 0 or index >= conversation_selector.item_count:
		return
	current_conversation = conversation_selector.get_item_metadata(index) as DialogueConversation
	current_node = current_conversation.nodes[0] if current_conversation != null and not current_conversation.nodes.is_empty() else null
	current_choice = null
	_rebuild_graph()
	_refresh_node_list()
	_refresh_choice_list()


func _edit_current_conversation() -> void:
	if current_conversation != null:
		editor_plugin.get_editor_interface().edit_resource(current_conversation)


func _assign_to_selected_npc() -> void:
	if current_conversation == null:
		return
	for node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		if node is QuestGiver:
			(node as QuestGiver).default_conversation_id = current_conversation.conversation_id
			editor_plugin.get_editor_interface().mark_scene_as_unsaved()
			_emit("Assigned %s to %s." % [current_conversation.conversation_id, (node as QuestGiver).npc_id])
			return
	_emit("Select an authored NPC in the scene tree first.")


func _add_conditional_entry() -> void:
	if current_conversation == null:
		return
	for node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		if not node is QuestGiver:
			continue
		var character := node as QuestGiver
		var entry := ConditionalConversation.new()
		entry.entry_id = "%s_entry_%d" % [current_conversation.conversation_id, character.conditional_conversations.size() + 1]
		entry.conversation_id = current_conversation.conversation_id
		character.conditional_conversations.append(entry)
		editor_plugin.get_editor_interface().mark_scene_as_unsaved()
		editor_plugin.get_editor_interface().edit_resource(entry)
		_emit("Added a conditional conversation entry. Configure its priority and conditions in the Inspector.")
		return
	_emit("Select an authored NPC in the scene tree first.")


func _select_owning_npc() -> void:
	if current_conversation == null or map_root == null:
		return
	for node in map_root.find_children("*", "", true, false):
		if not node is QuestGiver:
			continue
		var character := node as QuestGiver
		var owns_conversation := character.default_conversation_id == current_conversation.conversation_id
		if not owns_conversation:
			for entry in character.conditional_conversations:
				if entry != null and entry.conversation_id == current_conversation.conversation_id:
					owns_conversation = true
					break
		if owns_conversation:
			var selection := editor_plugin.get_editor_interface().get_selection()
			selection.clear()
			selection.add_node(character)
			editor_plugin.get_editor_interface().get_inspector().edit(character)
			_emit("Selected owning NPC %s." % character.npc_id)
			return
	_emit("No NPC on this map currently owns the selected conversation.")


func _rebuild_graph() -> void:
	if graph == null:
		return
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	graph_choice_ports.clear()
	if current_conversation == null:
		return
	for dialogue_node in current_conversation.nodes:
		if dialogue_node == null:
			continue
		var graph_node := GraphNode.new()
		graph_node.name = dialogue_node.node_id.validate_node_name()
		graph_node.title = "%s%s" % ["★ " if dialogue_node.node_id == current_conversation.starting_node_id else "", dialogue_node.node_id]
		graph_node.position_offset = dialogue_node.editor_position
		graph_node.resizable = true
		graph_node.custom_minimum_size = Vector2(230.0, 100.0)
		var text_label := Label.new()
		text_label.text = dialogue_node.text.left(90)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		graph_node.add_child(text_label)
		graph_node.set_slot(0, true, 0, Color(0.7, 0.7, 1.0), false, 0, Color.WHITE)
		for choice_index in dialogue_node.choices.size():
			var choice := dialogue_node.choices[choice_index]
			if choice == null:
				continue
			var choice_label := Label.new()
			choice_label.text = "› %s" % choice.text.left(52)
			graph_node.add_child(choice_label)
			graph_node.set_slot(choice_index + 1, false, 0, Color.WHITE, true, 0, Color(0.5, 0.9, 1.0))
			graph_choice_ports["%s:%d" % [graph_node.name, choice_index]] = choice
		graph_node.node_selected.connect(_select_node.bind(dialogue_node))
		graph_node.dragged.connect(_on_graph_node_dragged.bind(dialogue_node))
		graph.add_child(graph_node)
	for dialogue_node in current_conversation.nodes:
		if dialogue_node == null:
			continue
		var from_name := dialogue_node.node_id.validate_node_name()
		for choice_index in dialogue_node.choices.size():
			var choice := dialogue_node.choices[choice_index]
			if choice != null and not choice.destination_node_id.is_empty() and _find_dialogue_node(choice.destination_node_id) != null:
				graph.connect_node(from_name, choice_index, choice.destination_node_id.validate_node_name(), 0)


func _on_graph_connection_requested(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var choice := graph_choice_ports.get("%s:%d" % [str(from_node), from_port]) as DialogueChoice
	var destination := _find_dialogue_node_by_graph_name(str(to_node))
	if choice == null or destination == null:
		return
	choice.destination_node_id = destination.node_id
	_save_current_conversation()
	_rebuild_graph()


func _on_graph_disconnection_requested(from_node: StringName, from_port: int, _to_node: StringName, _to_port: int) -> void:
	var choice := graph_choice_ports.get("%s:%d" % [str(from_node), from_port]) as DialogueChoice
	if choice != null:
		choice.destination_node_id = ""
		_save_current_conversation()
		_rebuild_graph()


func _on_graph_node_dragged(_from: Vector2, to: Vector2, dialogue_node: DialogueNode) -> void:
	dialogue_node.editor_position = to
	_save_current_conversation()


func _add_dialogue_node() -> void:
	if current_conversation == null:
		return
	var node := DialogueNode.new()
	node.node_id = _unique_node_id("node_%d" % (current_conversation.nodes.size() + 1))
	node.text = "New dialogue node"
	node.editor_position = Vector2(80.0 + current_conversation.nodes.size() * 60.0, 100.0 + current_conversation.nodes.size() * 40.0)
	current_conversation.nodes.append(node)
	current_node = node
	_save_current_conversation()
	_rebuild_graph()
	_refresh_node_list()
	editor_plugin.get_editor_interface().edit_resource(node)


func _delete_current_node() -> void:
	if current_conversation == null or current_node == null:
		return
	var deleted_id := current_node.node_id
	current_conversation.nodes.erase(current_node)
	for dialogue_node in current_conversation.nodes:
		if dialogue_node == null:
			continue
		if dialogue_node.automatic_next_node_id == deleted_id:
			dialogue_node.automatic_next_node_id = ""
		for choice in dialogue_node.choices:
			if choice != null and choice.destination_node_id == deleted_id:
				choice.destination_node_id = ""
	if current_conversation.starting_node_id == deleted_id:
		current_conversation.starting_node_id = current_conversation.nodes[0].node_id if not current_conversation.nodes.is_empty() else ""
	current_node = current_conversation.nodes[0] if not current_conversation.nodes.is_empty() else null
	_save_current_conversation()
	_rebuild_graph()
	_refresh_node_list()
	_refresh_choice_list()


func _set_current_node_as_start() -> void:
	if current_conversation == null or current_node == null:
		return
	current_conversation.starting_node_id = current_node.node_id
	_save_current_conversation()
	_rebuild_graph()


func _edit_current_node() -> void:
	if current_node != null:
		editor_plugin.get_editor_interface().edit_resource(current_node)


func _select_node(dialogue_node: DialogueNode) -> void:
	current_node = dialogue_node
	current_choice = null
	_refresh_node_list()
	_refresh_choice_list()


func _refresh_node_list() -> void:
	node_list.clear()
	if current_conversation == null:
		return
	for dialogue_node in current_conversation.nodes:
		if dialogue_node == null:
			continue
		node_list.add_item("%s%s — %s" % ["★ " if dialogue_node.node_id == current_conversation.starting_node_id else "", dialogue_node.node_id, dialogue_node.text.left(48)])
		node_list.set_item_metadata(node_list.item_count - 1, dialogue_node)
		if dialogue_node == current_node:
			node_list.select(node_list.item_count - 1)


func _on_node_list_selected(index: int) -> void:
	current_node = node_list.get_item_metadata(index) as DialogueNode
	current_choice = null
	_refresh_choice_list()


func _add_choice() -> void:
	if current_node == null:
		_emit("Select a dialogue node first.")
		return
	var choice := DialogueChoice.new()
	choice.choice_id = _unique_choice_id(current_node, "choice_%d" % (current_node.choices.size() + 1))
	choice.text = "New choice"
	current_node.choices.append(choice)
	current_choice = choice
	current_node.ends_conversation = false
	_save_current_conversation()
	_rebuild_graph()
	_refresh_choice_list()
	editor_plugin.get_editor_interface().edit_resource(choice)


func _edit_current_choice() -> void:
	if current_choice != null:
		editor_plugin.get_editor_interface().edit_resource(current_choice)


func _delete_current_choice() -> void:
	if current_node == null or current_choice == null:
		return
	current_node.choices.erase(current_choice)
	current_choice = current_node.choices[0] if not current_node.choices.is_empty() else null
	_save_current_conversation()
	_rebuild_graph()
	_refresh_choice_list()


func _refresh_choice_list() -> void:
	choice_list.clear()
	if current_node == null:
		return
	for choice in current_node.choices:
		if choice == null:
			continue
		choice_list.add_item("%s → %s" % [choice.text.left(44), choice.destination_node_id if not choice.destination_node_id.is_empty() else "(end/unlinked)"])
		choice_list.set_item_metadata(choice_list.item_count - 1, choice)
		if choice == current_choice:
			choice_list.select(choice_list.item_count - 1)


func _on_choice_selected(index: int) -> void:
	current_choice = choice_list.get_item_metadata(index) as DialogueChoice


func _add_node_condition() -> void:
	if current_node == null:
		return
	var condition := StoryCondition.new()
	condition.condition_id = "condition_%d" % (current_node.conditions.size() + 1)
	current_node.conditions.append(condition)
	_save_current_conversation()
	editor_plugin.get_editor_interface().edit_resource(condition)


func _add_node_action() -> void:
	if current_node == null:
		return
	var action := StoryAction.new()
	action.action_id = "action_%d" % (current_node.actions.size() + 1)
	current_node.actions.append(action)
	_save_current_conversation()
	editor_plugin.get_editor_interface().edit_resource(action)


func _add_choice_condition() -> void:
	if current_choice == null:
		_emit("Select a player choice first.")
		return
	var condition := StoryCondition.new()
	condition.condition_id = "condition_%d" % (current_choice.conditions.size() + 1)
	current_choice.conditions.append(condition)
	_save_current_conversation()
	editor_plugin.get_editor_interface().edit_resource(condition)


func _add_choice_action() -> void:
	if current_choice == null:
		_emit("Select a player choice first.")
		return
	var action := StoryAction.new()
	action.action_id = "action_%d" % (current_choice.actions.size() + 1)
	current_choice.actions.append(action)
	_save_current_conversation()
	editor_plugin.get_editor_interface().edit_resource(action)


func _preview_conversation() -> void:
	if current_conversation == null or map_root == null:
		return
	ProjectSettings.set_setting("map_authoring/preview_map_scene", map_root.scene_file_path)
	ProjectSettings.set_setting("map_authoring/preview_conversation_path", current_conversation.resource_path)
	editor_plugin.get_editor_interface().save_scene()
	editor_plugin.get_editor_interface().play_custom_scene("res://map_authoring/dialogue_preview.tscn")


func _save_current_conversation() -> void:
	if current_conversation == null:
		return
	if not current_conversation.resource_path.is_empty():
		ResourceSaver.save(current_conversation, current_conversation.resource_path)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_node_list()
	_refresh_choice_list()
	_emit("Saved conversation %s." % current_conversation.conversation_id)


func _refresh_flags() -> void:
	flag_selector.clear()
	var catalog := _flag_catalog()
	if catalog == null:
		return
	for flag in catalog.flags:
		if flag == null:
			continue
		flag_selector.add_item("%s — %s" % [flag.flag_id, flag.display_name])
		flag_selector.set_item_metadata(flag_selector.item_count - 1, flag)


func _new_flag() -> void:
	if map_root == null:
		return
	_ensure_catalogs()
	var flag := StoryFlagDefinition.new()
	flag.flag_id = _unique_flag_id("new_story_flag")
	flag.display_name = "New Story Flag"
	var folder := "res://maps/%s/dialogue/flags" % map_root.map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join("%s.tres" % flag.flag_id)
	if ResourceSaver.save(flag, path) != OK:
		_emit("Could not save the story flag.")
		return
	_flag_catalog().flags.append(flag)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_flags()
	editor_plugin.get_editor_interface().edit_resource(flag)


func _edit_flag() -> void:
	var flag := _selected_resource(flag_selector) as StoryFlagDefinition
	if flag != null:
		editor_plugin.get_editor_interface().edit_resource(flag)


func _delete_flag() -> void:
	var flag := _selected_resource(flag_selector) as StoryFlagDefinition
	if flag == null:
		return
	var path := flag.resource_path
	_flag_catalog().flags.erase(flag)
	if path.begins_with("res://maps/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_flags()


func _refresh_cinematics() -> void:
	cinematic_selector.clear()
	current_cinematic = null
	current_cue_index = -1
	var catalog := _cinematic_catalog()
	if catalog != null:
		for cinematic in catalog.sequences:
			if cinematic == null:
				continue
			cinematic_selector.add_item("%s — %s" % [cinematic.cinematic_id, cinematic.display_name])
			cinematic_selector.set_item_metadata(cinematic_selector.item_count - 1, cinematic)
	if cinematic_selector.item_count > 0:
		cinematic_selector.select(0)
		_on_cinematic_selected(0)
	else:
		_refresh_cue_list()


func _new_cinematic() -> void:
	if map_root == null:
		return
	_ensure_catalogs()
	var cinematic := CinematicSequence.new()
	cinematic.cinematic_id = _unique_cinematic_id("new_cinematic")
	cinematic.display_name = "New Cinematic"
	cinematic.owning_map_id = map_root.map_id
	var save_camera := CinematicCue.new()
	save_camera.cue_id = "save_camera"
	save_camera.cue_type = "save_camera"
	save_camera.duration_seconds = 0.0
	var restore_camera := CinematicCue.new()
	restore_camera.cue_id = "restore_camera"
	restore_camera.cue_type = "restore_camera"
	restore_camera.duration_seconds = 0.0
	var complete := CinematicCue.new()
	complete.cue_id = "complete"
	complete.cue_type = "complete"
	complete.duration_seconds = 0.0
	cinematic.cues = [save_camera, restore_camera, complete]
	var folder := "res://maps/%s/cinematics" % map_root.map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join("%s.tres" % cinematic.cinematic_id)
	if ResourceSaver.save(cinematic, path) != OK:
		_emit("Could not save the cinematic.")
		return
	_cinematic_catalog().sequences.append(cinematic)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_cinematics()
	_select_cinematic(cinematic.cinematic_id)
	editor_plugin.get_editor_interface().edit_resource(cinematic)


func _on_cinematic_selected(index: int) -> void:
	if index < 0 or index >= cinematic_selector.item_count:
		return
	current_cinematic = cinematic_selector.get_item_metadata(index) as CinematicSequence
	current_cue_index = 0 if current_cinematic != null and not current_cinematic.cues.is_empty() else -1
	_refresh_cue_list()


func _edit_current_cinematic() -> void:
	if current_cinematic != null:
		editor_plugin.get_editor_interface().edit_resource(current_cinematic)


func _delete_cinematic() -> void:
	if current_cinematic == null:
		return
	var path := current_cinematic.resource_path
	_cinematic_catalog().sequences.erase(current_cinematic)
	if path.begins_with("res://maps/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()
	_refresh_cinematics()


func _add_cue() -> void:
	if current_cinematic == null:
		return
	var cue := CinematicCue.new()
	cue.cue_id = "cue_%d" % (current_cinematic.cues.size() + 1)
	current_cinematic.cues.append(cue)
	current_cue_index = current_cinematic.cues.size() - 1
	_save_current_cinematic()
	_refresh_cue_list()
	editor_plugin.get_editor_interface().edit_resource(cue)


func _edit_cue() -> void:
	if current_cinematic != null and current_cue_index >= 0 and current_cue_index < current_cinematic.cues.size():
		editor_plugin.get_editor_interface().edit_resource(current_cinematic.cues[current_cue_index])


func _remove_cue() -> void:
	if current_cinematic == null or current_cue_index < 0:
		return
	current_cinematic.cues.remove_at(current_cue_index)
	current_cue_index = mini(current_cue_index, current_cinematic.cues.size() - 1)
	_save_current_cinematic()
	_refresh_cue_list()


func _move_cue(direction: int) -> void:
	if current_cinematic == null or current_cue_index < 0:
		return
	var destination := current_cue_index + direction
	if destination < 0 or destination >= current_cinematic.cues.size():
		return
	var cue := current_cinematic.cues[current_cue_index]
	current_cinematic.cues.remove_at(current_cue_index)
	current_cinematic.cues.insert(destination, cue)
	current_cue_index = destination
	_save_current_cinematic()
	_refresh_cue_list()


func _on_cue_selected(index: int) -> void:
	current_cue_index = index


func _refresh_cue_list() -> void:
	cue_list.clear()
	if current_cinematic == null:
		return
	for index in current_cinematic.cues.size():
		var cue := current_cinematic.cues[index]
		cue_list.add_item("%d. %s" % [index + 1, cue.summary() if cue != null else "(empty)"])
	if current_cue_index >= 0 and current_cue_index < cue_list.item_count:
		cue_list.select(current_cue_index)


func _save_current_cinematic() -> void:
	if current_cinematic == null:
		return
	if not current_cinematic.resource_path.is_empty():
		ResourceSaver.save(current_cinematic, current_cinematic.resource_path)
	editor_plugin.get_editor_interface().mark_scene_as_unsaved()


func _find_dialogue_node(node_id: String) -> DialogueNode:
	if current_conversation == null:
		return null
	for dialogue_node in current_conversation.nodes:
		if dialogue_node != null and dialogue_node.node_id == node_id:
			return dialogue_node
	return null


func _find_dialogue_node_by_graph_name(graph_name: String) -> DialogueNode:
	if current_conversation == null:
		return null
	for dialogue_node in current_conversation.nodes:
		if dialogue_node != null and dialogue_node.node_id.validate_node_name() == graph_name:
			return dialogue_node
	return null


func _selected_resource(option: OptionButton) -> Resource:
	if option.item_count == 0 or option.selected < 0:
		return null
	return option.get_item_metadata(option.selected) as Resource


func _select_conversation(conversation_id: String) -> void:
	for index in conversation_selector.item_count:
		var conversation := conversation_selector.get_item_metadata(index) as DialogueConversation
		if conversation != null and conversation.conversation_id == conversation_id:
			conversation_selector.select(index)
			_on_conversation_selected(index)
			return


func _select_cinematic(cinematic_id: String) -> void:
	for index in cinematic_selector.item_count:
		var cinematic := cinematic_selector.get_item_metadata(index) as CinematicSequence
		if cinematic != null and cinematic.cinematic_id == cinematic_id:
			cinematic_selector.select(index)
			_on_cinematic_selected(index)
			return


func _unique_conversation_id(base_id: String) -> String:
	var used: Dictionary = {}
	var catalog := _dialogue_catalog()
	if catalog != null:
		for conversation in catalog.conversations:
			if conversation != null:
				used[conversation.conversation_id] = true
	return _unique_id(base_id, used)


func _unique_node_id(base_id: String) -> String:
	var used: Dictionary = {}
	if current_conversation != null:
		for dialogue_node in current_conversation.nodes:
			if dialogue_node != null:
				used[dialogue_node.node_id] = true
	return _unique_id(base_id, used)


func _unique_choice_id(node: DialogueNode, base_id: String) -> String:
	var used: Dictionary = {}
	for choice in node.choices:
		if choice != null:
			used[choice.choice_id] = true
	return _unique_id(base_id, used)


func _unique_flag_id(base_id: String) -> String:
	var used: Dictionary = {}
	var catalog := _flag_catalog()
	if catalog != null:
		for flag in catalog.flags:
			if flag != null:
				used[flag.flag_id] = true
	return _unique_id(base_id, used)


func _unique_cinematic_id(base_id: String) -> String:
	var used: Dictionary = {}
	var catalog := _cinematic_catalog()
	if catalog != null:
		for cinematic in catalog.sequences:
			if cinematic != null:
				used[cinematic.cinematic_id] = true
	return _unique_id(base_id, used)


func _unique_id(base_id: String, used: Dictionary) -> String:
	var normalized := base_id.to_snake_case()
	var candidate := normalized
	var index := 2
	while used.has(candidate):
		candidate = "%s_%d" % [normalized, index]
		index += 1
	return candidate


func _emit(message: String) -> void:
	status_changed.emit(message)
