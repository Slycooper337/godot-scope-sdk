@tool
extends EditorPlugin

const MAPS_ROOT := "res://maps"
const PREVIEW_SCENE := "res://map_authoring/world_preview.tscn"
const OBJECTIVE_TYPES := ["kill", "talk", "interact", "use_transition", "enter_map", "enter_area"]
const STORYTELLING_BUILDER_SCRIPT := preload("res://addons/map_authoring/storytelling_builder_panel.gd")

var _panel: VBoxContainer
var _dock: ScrollContainer
var _status: RichTextLabel
var _email_input: LineEdit
var _password_input: LineEdit
var _catalog: Dictionary = {}
var _map_selector: OptionButton
var _destination_map_selector: OptionButton
var _destination_spawn_selector: OptionButton
var _return_spawn_selector: OptionButton
var _visual_selector: OptionButton
var _archetype_selector: OptionButton
var _faction_selector: OptionButton
var _surface_selector: OptionButton
var _quest_selector: OptionButton
var _quest_id: LineEdit
var _quest_title: LineEdit
var _quest_giver: OptionButton
var _quest_faction: LineEdit
var _quest_prerequisites: LineEdit
var _quest_rewards: LineEdit
var _quest_repeatable: CheckBox
var _quest_description: TextEdit
var _quest_offer: TextEdit
var _quest_completion: TextEdit
var _stage_list: ItemList
var _stage_id: LineEdit
var _stage_type: OptionButton
var _stage_map: OptionButton
var _stage_target: OptionButton
var _stage_kill_area: OptionButton
var _stage_count: SpinBox
var _current_quest: QuestDefinition
var _current_stage_index := -1
var _new_map_dialog: ConfirmationDialog
var _new_map_id: LineEdit
var _new_map_name: LineEdit
var _new_map_world: LineEdit
var _new_map_type: LineEdit
var _new_map_enterable: CheckBox
var _delete_quest_dialog: ConfirmationDialog
var _publish_dialog: ConfirmationDialog
var _pending_publish: Dictionary = {}
var _validation_results: ItemList
var _validation_paths: PackedStringArray = []
var _pending_validation_message := ""
var _storytelling_builder: StorytellingBuilderPanel


func _enter_tree() -> void:
	_build_dock()
	_build_map_dialog()
	_build_delete_dialog()
	_build_publish_dialog()
	scene_changed.connect(_on_edited_scene_changed)
	_refresh_catalog()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_edited_scene_changed):
		scene_changed.disconnect(_on_edited_scene_changed)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
	if _new_map_dialog != null:
		_new_map_dialog.queue_free()
	if _delete_quest_dialog != null:
		_delete_quest_dialog.queue_free()
	if _publish_dialog != null:
		_publish_dialog.queue_free()


func _build_dock() -> void:
	_dock = ScrollContainer.new()
	_dock.name = "World Builder"
	_dock.custom_minimum_size = Vector2(360.0, 0.0)
	_panel = VBoxContainer.new()
	_panel.name = "World Builder"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.add_child(_panel)

	var heading := Label.new()
	heading.text = "Wizards Wager World Builder"
	heading.add_theme_font_size_override("font_size", 18)
	_panel.add_child(heading)
	_add_help("Scenes and .tres resources are the source of truth. JSON is generated when you export or publish.")

	_add_section("World")
	var world_row := HBoxContainer.new()
	_panel.add_child(world_row)
	_map_selector = OptionButton.new()
	_map_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_child(_map_selector)
	_add_button(world_row, "Open", _open_selected_catalog_map)
	_add_button(world_row, "Refresh", _refresh_catalog)
	_add_button(_panel, "Create New Map", _show_new_map_dialog)

	_add_section("Place Objects")
	var placement_grid := GridContainer.new()
	placement_grid.columns = 2
	_panel.add_child(placement_grid)
	_add_button(placement_grid, "Physics Surface", _add_physics_surface)
	_add_button(placement_grid, "Player Spawn", _add_player_spawn)
	_add_button(placement_grid, "Character", _add_authored_character)
	_add_button(placement_grid, "Character Region", _add_character_spawn)
	_add_button(placement_grid, "Transition", _add_area_transition)
	_add_button(placement_grid, "Quest Area", _add_quest_area)
	_add_button(placement_grid, "Interactable", _add_interactable)
	_add_button(placement_grid, "Quest Catalog", _add_quest_catalog)
	_add_button(placement_grid, "Duplicate Character", _duplicate_selected_character)
	_add_button(placement_grid, "Enable / Disable", _toggle_selected_character)
	_add_button(placement_grid, "Cinematic Marker", _add_cinematic_marker)
	_archetype_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Character archetype", _archetype_selector))
	_faction_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Character faction", _faction_selector))
	_surface_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Character surface", _surface_selector))
	_visual_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Character sprite sheet", _visual_selector))
	_add_button(_panel, "Apply Setup to Selected Character/Region", _apply_selected_character_setup)
	_add_button(_panel, "Create Behavior for Selected Character/Region", _create_behavior_for_selected)
	_add_help("New objects appear beside the selected 2D object. Drag and resize them in the normal Godot editor.")

	_add_section("Selected Transition Link")
	_destination_map_selector = OptionButton.new()
	_destination_map_selector.item_selected.connect(_on_destination_map_selected)
	_panel.add_child(_labeled_control("Destination map", _destination_map_selector))
	_destination_spawn_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Destination spawn", _destination_spawn_selector))
	_return_spawn_selector = OptionButton.new()
	_panel.add_child(_labeled_control("Return spawn", _return_spawn_selector))
	var transition_row := HBoxContainer.new()
	_panel.add_child(transition_row)
	_add_button(transition_row, "Apply Link", _apply_transition_link)
	_add_button(transition_row, "Open Destination", _open_transition_destination)
	_add_button(_panel, "Create Paired Return Transition", _create_paired_transition)

	_add_section("Quest Builder")
	var quest_top := HBoxContainer.new()
	_panel.add_child(quest_top)
	_quest_selector = OptionButton.new()
	_quest_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_selector.item_selected.connect(_on_quest_selected)
	quest_top.add_child(_quest_selector)
	_add_button(quest_top, "New", _new_quest)
	_add_button(quest_top, "Duplicate", _duplicate_quest)
	_add_button(quest_top, "Delete", _request_delete_quest)

	_quest_id = LineEdit.new()
	_panel.add_child(_labeled_control("Quest ID", _quest_id))
	_quest_title = LineEdit.new()
	_panel.add_child(_labeled_control("Title", _quest_title))
	_quest_giver = OptionButton.new()
	_panel.add_child(_labeled_control("Giver character", _quest_giver))
	_quest_faction = LineEdit.new()
	_quest_faction.placeholder_text = "blank = any faction"
	_panel.add_child(_labeled_control("Required faction", _quest_faction))
	_quest_prerequisites = LineEdit.new()
	_quest_prerequisites.placeholder_text = "quest_one, quest_two"
	_panel.add_child(_labeled_control("Prerequisites", _quest_prerequisites))
	_quest_rewards = LineEdit.new()
	_quest_rewards.placeholder_text = "{\"xp\": 20, \"gold\": 10}"
	_panel.add_child(_labeled_control("Rewards JSON", _quest_rewards))
	_quest_repeatable = CheckBox.new()
	_quest_repeatable.text = "Repeatable"
	_panel.add_child(_quest_repeatable)
	_quest_description = _text_editor("Description")
	_quest_offer = _text_editor("Offer text")
	_quest_completion = _text_editor("Completion text")
	_add_button(_panel, "Save Quest Details", _save_quest_details)

	var stages_label := Label.new()
	stages_label.text = "Stages (in order)"
	_panel.add_child(stages_label)
	_stage_list = ItemList.new()
	_stage_list.custom_minimum_size.y = 120.0
	_stage_list.item_selected.connect(_on_stage_selected)
	_panel.add_child(_stage_list)
	_stage_id = LineEdit.new()
	_panel.add_child(_labeled_control("Stage ID", _stage_id))
	_stage_type = OptionButton.new()
	for objective_type in OBJECTIVE_TYPES:
		_stage_type.add_item(objective_type)
	_stage_type.item_selected.connect(_on_stage_type_selected)
	_panel.add_child(_labeled_control("Objective", _stage_type))
	_stage_map = OptionButton.new()
	_stage_map.item_selected.connect(_on_stage_map_selected)
	_panel.add_child(_labeled_control("Target map", _stage_map))
	_stage_target = OptionButton.new()
	_panel.add_child(_labeled_control("Target", _stage_target))
	_stage_kill_area = OptionButton.new()
	_panel.add_child(_labeled_control("Kill must occur in", _stage_kill_area))
	_stage_count = SpinBox.new()
	_stage_count.min_value = 1
	_stage_count.max_value = 999999
	_stage_count.value = 1
	_panel.add_child(_labeled_control("Required count", _stage_count))
	var stage_row := HBoxContainer.new()
	_panel.add_child(stage_row)
	_add_button(stage_row, "Add", _add_stage)
	_add_button(stage_row, "Update", _update_stage)
	_add_button(stage_row, "Up", _move_stage.bind(-1))
	_add_button(stage_row, "Down", _move_stage.bind(1))
	_add_button(stage_row, "Remove", _remove_stage)

	_add_section("Dialogue and Storytelling")
	_storytelling_builder = STORYTELLING_BUILDER_SCRIPT.new() as StorytellingBuilderPanel
	_storytelling_builder.setup(self)
	_storytelling_builder.status_changed.connect(_set_status)
	_panel.add_child(_storytelling_builder)

	_add_section("Validate and Preview")
	var validation_row := HBoxContainer.new()
	_panel.add_child(validation_row)
	_add_button(validation_row, "Current Map", _validate_current_map)
	_add_button(validation_row, "Entire World", _validate_entire_world)
	_validation_results = ItemList.new()
	_validation_results.custom_minimum_size.y = 100.0
	_validation_results.item_activated.connect(_open_validation_result)
	_panel.add_child(_validation_results)
	_add_button(_panel, "Preview Current Map", _preview_current_map)

	_add_section("Backend and Publishing")
	_email_input = LineEdit.new()
	_email_input.placeholder_text = "Application email"
	_panel.add_child(_email_input)
	_password_input = LineEdit.new()
	_password_input.placeholder_text = "Password"
	_password_input.secret = true
	_panel.add_child(_password_input)
	_add_button(_panel, "Login", _login_to_backend)
	var publish_grid := GridContainer.new()
	publish_grid.columns = 2
	_panel.add_child(publish_grid)
	_add_button(publish_grid, "Export Definition", _export_current_map)
	_add_button(publish_grid, "Backend Validate", _validate_with_backend)
	_add_button(publish_grid, "Publish Map", _publish_current_map)
	_add_button(publish_grid, "Refresh Version", _refresh_published_version)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.custom_minimum_size.y = 90.0
	_panel.add_child(_status)

func _build_map_dialog() -> void:
	_new_map_dialog = ConfirmationDialog.new()
	_new_map_dialog.title = "Create New Map"
	_new_map_dialog.ok_button_text = "Create"
	var fields := VBoxContainer.new()
	_new_map_dialog.add_child(fields)
	_new_map_id = LineEdit.new()
	fields.add_child(_labeled_control("Map ID", _new_map_id))
	_new_map_name = LineEdit.new()
	fields.add_child(_labeled_control("Display name", _new_map_name))
	_new_map_world = LineEdit.new()
	_new_map_world.text = "main_world"
	fields.add_child(_labeled_control("World ID", _new_map_world))
	_new_map_type = LineEdit.new()
	_new_map_type.text = "instanced_area"
	fields.add_child(_labeled_control("Area type", _new_map_type))
	_new_map_enterable = CheckBox.new()
	_new_map_enterable.text = "Players may enter this map"
	_new_map_enterable.button_pressed = true
	fields.add_child(_new_map_enterable)
	_new_map_dialog.confirmed.connect(_create_new_map)
	get_editor_interface().get_base_control().add_child(_new_map_dialog)


func _build_delete_dialog() -> void:
	_delete_quest_dialog = ConfirmationDialog.new()
	_delete_quest_dialog.title = "Delete Quest"
	_delete_quest_dialog.dialog_text = "Remove this quest from the map and delete its .tres file?"
	_delete_quest_dialog.confirmed.connect(_delete_current_quest)
	get_editor_interface().get_base_control().add_child(_delete_quest_dialog)


func _build_publish_dialog() -> void:
	_publish_dialog = ConfirmationDialog.new()
	_publish_dialog.title = "Publish Map"
	_publish_dialog.ok_button_text = "Publish"
	_publish_dialog.confirmed.connect(_complete_pending_publish)
	_publish_dialog.canceled.connect(_cancel_pending_publish)
	get_editor_interface().get_base_control().add_child(_publish_dialog)


func _add_section(title: String) -> void:
	var separator := HSeparator.new()
	_panel.add_child(separator)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	_panel.add_child(label)


func _add_help(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.75, 0.78, 0.85)
	_panel.add_child(label)


func _add_button(parent: Node, label: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callable)
	parent.add_child(button)
	return button


func _labeled_control(label_text: String, control: Control) -> Control:
	var container := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	container.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(control)
	return container


func _text_editor(label_text: String) -> TextEdit:
	var editor := TextEdit.new()
	editor.placeholder_text = label_text
	editor.custom_minimum_size.y = 58.0
	_panel.add_child(_labeled_control(label_text, editor))
	return editor


func _show_new_map_dialog() -> void:
	_new_map_id.clear()
	_new_map_name.clear()
	_new_map_dialog.popup_centered(Vector2i(480, 330))


func _create_new_map() -> void:
	var map_id := _new_map_id.text.strip_edges().to_snake_case()
	if map_id.is_empty() or map_id != _new_map_id.text.strip_edges():
		_set_status("Map ID must already be lowercase snake_case.")
		return
	if WorldAuthoringCatalog.map_ids(_catalog).has(map_id):
		_set_status("A map named [b]%s[/b] already exists." % map_id)
		return
	var folder := MAPS_ROOT.path_join(map_id)
	var absolute_folder := ProjectSettings.globalize_path(folder)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_folder.path_join("quests"))
	if directory_error != OK:
		_set_status("Could not create %s." % folder)
		return
	DirAccess.make_dir_recursive_absolute(absolute_folder.path_join("behaviors"))
	var root := MapRoot.new()
	root.name = _new_map_name.text.strip_edges().to_pascal_case().validate_node_name()
	if root.name.is_empty():
		root.name = map_id.to_pascal_case() + "Map"
	root.map_id = map_id
	root.world_id = _new_map_world.text.strip_edges()
	root.display_name = _new_map_name.text.strip_edges() if not _new_map_name.text.strip_edges().is_empty() else map_id.capitalize()
	root.area_type = _new_map_type.text.strip_edges()
	root.enterable = _new_map_enterable.button_pressed
	root.published_version = 0
	root.archetype_ids = PackedStringArray(["npc"])
	root.faction_ids = PackedStringArray(["player", "neutral", "enemy", "justice", "avenger"])
	for container_name in ["Visuals", "PhysicsSurfaces", "PlayerSpawns", "Transitions", "Characters", "CharacterSpawns", "QuestAreas", "Interactables", "CinematicMarkers", "Quests", "Storytelling"]:
		var container := Node.new() if container_name in ["Quests", "Storytelling"] else Node2D.new()
		container.name = container_name
		root.add_child(container)
		container.owner = root
	var surface := MapPhysicsSurface.new()
	surface.name = "Ground"
	surface.surface_id = "ground"
	surface.surface_role = "floor"
	surface.position = Vector2(1024.0, 560.0)
	surface.size = Vector2(2048.0, 128.0)
	root.get_node("PhysicsSurfaces").add_child(surface)
	surface.owner = root
	var spawn := MapPlayerSpawn.new()
	spawn.name = "PlayerStart"
	spawn.spawn_id = "player_start"
	spawn.surface_id = "ground"
	spawn.position = Vector2(256.0, 480.0)
	root.get_node("PlayerSpawns").add_child(spawn)
	spawn.owner = root
	var catalog := QuestCatalog.new()
	catalog.name = "QuestCatalog"
	root.get_node("Quests").add_child(catalog)
	catalog.owner = root
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.free()
		_set_status("Could not package the new map scene.")
		return
	var scene_path := folder.path_join("%s_map.tscn" % map_id)
	var save_error := ResourceSaver.save(packed, scene_path)
	root.free()
	if save_error != OK:
		_set_status("Could not save %s." % scene_path)
		return
	_refresh_catalog()
	get_editor_interface().open_scene_from_path(scene_path)
	_set_status("Created [b]%s[/b]. Build visuals normally, then place characters, regions, quests, and transitions from this dock." % scene_path)


func _refresh_catalog() -> void:
	_catalog = WorldAuthoringCatalog.build_catalog()
	var edited_root := get_editor_interface().get_edited_scene_root() as MapRoot
	if edited_root != null:
		var maps: Dictionary = _catalog.get("maps", {})
		maps[edited_root.map_id] = {
			"scene_path": edited_root.scene_file_path,
			"definition": edited_root.collect_definition(),
			"local_errors": edited_root.validate_definition()
		}
		_catalog["maps"] = maps
	_fill_option(_map_selector, WorldAuthoringCatalog.map_ids(_catalog))
	_fill_option(_destination_map_selector, WorldAuthoringCatalog.map_ids(_catalog))
	_fill_option(_visual_selector, _discover_character_visual_ids())
	if edited_root != null:
		var edited_definition := edited_root.collect_definition()
		_fill_option(_archetype_selector, PackedStringArray(edited_definition.get("archetypes", [])))
		_fill_option(_faction_selector, PackedStringArray(edited_definition.get("factions", [])))
		_fill_option(_surface_selector, WorldAuthoringCatalog.object_ids(edited_definition, "physics_surfaces", "surface_id"))
	else:
		_fill_option(_archetype_selector, PackedStringArray())
		_fill_option(_faction_selector, PackedStringArray())
		_fill_option(_surface_selector, PackedStringArray())
	_refresh_destination_spawns()
	_refresh_return_spawns()
	_refresh_quest_builder()
	if _storytelling_builder != null:
		_storytelling_builder.refresh(edited_root, _catalog)
	_set_status("World catalog refreshed: %d map(s)." % WorldAuthoringCatalog.map_ids(_catalog).size())


func _on_edited_scene_changed(_scene_root: Node) -> void:
	call_deferred("_refresh_catalog")
	if not _pending_validation_message.is_empty():
		call_deferred("_select_validation_object", _pending_validation_message)


func _open_selected_catalog_map() -> void:
	var map_id := _selected_text(_map_selector)
	var path := WorldAuthoringCatalog.scene_path_for_map(_catalog, map_id)
	if path.is_empty():
		_set_status("Select a discovered map.")
		return
	get_editor_interface().open_scene_from_path(path)


func _current_map_root() -> MapRoot:
	var edited_scene := get_editor_interface().get_edited_scene_root()
	if edited_scene == null or not edited_scene is MapRoot:
		_set_status("Open a map scene whose root is MapRoot.")
		return null
	return edited_scene as MapRoot


func _container(map_root: MapRoot, preferred_name: String, fallback_name := "") -> Node:
	var existing := map_root.get_node_or_null(preferred_name)
	if existing == null and not fallback_name.is_empty():
		existing = map_root.get_node_or_null(fallback_name)
	if existing != null:
		return existing
	var container := Node.new() if preferred_name == "Quests" else Node2D.new()
	container.name = preferred_name
	map_root.add_child(container)
	container.owner = map_root
	return container


func _placement_position(map_root: MapRoot) -> Vector2:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	for selected_node in selected:
		if selected_node is Node2D and map_root.is_ancestor_of(selected_node):
			return map_root.to_local((selected_node as Node2D).global_position) + Vector2(96.0, 0.0)
	return Vector2.ZERO


func _nearest_surface_id(map_root: MapRoot, position: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := INF
	for node in map_root.find_children("*", "", true, false):
		if node is MapPhysicsSurface:
			var distance := position.distance_squared_to(map_root.to_local((node as MapPhysicsSurface).global_position))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_id = (node as MapPhysicsSurface).surface_id
	return nearest_id


func _finish_add(node: Node, map_root: MapRoot, message: String) -> void:
	node.owner = map_root
	for descendant in node.find_children("*", "", true, false):
		if descendant.owner == null:
			descendant.owner = map_root
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	get_editor_interface().edit_node(node)
	get_editor_interface().mark_scene_as_unsaved()
	_set_status(message)
	call_deferred("_refresh_catalog")


func _add_physics_surface() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "PhysicsSurfaces")
	var surface := MapPhysicsSurface.new()
	surface.name = _unique_child_name(container, "Surface")
	surface.surface_id = surface.name.to_snake_case()
	surface.position = _placement_position(map_root)
	container.add_child(surface)
	_finish_add(surface, map_root, "Added a draggable physics surface.")


func _add_player_spawn() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "PlayerSpawns")
	var spawn := MapPlayerSpawn.new()
	spawn.name = _unique_child_name(container, "PlayerSpawn")
	spawn.spawn_id = spawn.name.to_snake_case()
	spawn.position = _placement_position(map_root)
	spawn.surface_id = _nearest_surface_id(map_root, spawn.position)
	container.add_child(spawn)
	_finish_add(spawn, map_root, "Added a player spawn. Give it a stable spawn_id.")


func _add_authored_character() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "Characters", "NPCSpawns")
	var character := AuthoredCharacter.new()
	character.name = _unique_child_name(container, "Character")
	character.npc_id = character.name.to_snake_case()
	character.display_name = character.name.replace("_", " ")
	character.position = _placement_position(map_root)
	character.surface_id = _nearest_surface_id(map_root, character.position)
	container.add_child(character)
	_finish_add(character, map_root, "Added a fixed character. It may be friendly, hostile, neutral, or a quest participant.")


func _add_character_spawn() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "CharacterSpawns", "EnemySpawns")
	var spawn := CombatantSpawnArea.new()
	spawn.name = _unique_child_name(container, "CharacterRegion")
	spawn.spawn_id = spawn.name.to_snake_case()
	spawn.display_name = spawn.name.replace("_", " ")
	spawn.combatant_kind = "npc"
	spawn.position = _placement_position(map_root)
	spawn.surface_id = _nearest_surface_id(map_root, spawn.position)
	spawn.placement_mode = CombatantSpawnArea.PlacementMode.RANDOM_IN_BOUNDS
	container.add_child(spawn)
	_finish_add(spawn, map_root, "Added a character spawn region. All spawned enemies use the shared character animation system.")


func _apply_selected_character_setup() -> void:
	var visual_id := _selected_text(_visual_selector)
	var archetype_id := _selected_text(_archetype_selector)
	var faction_id := _selected_text(_faction_selector)
	var surface_id := _selected_text(_surface_selector)
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is CombatantSpawnArea:
			var region := node as CombatantSpawnArea
			if not visual_id.is_empty():
				region.visual_id = visual_id
			if not archetype_id.is_empty():
				region.archetype_id = archetype_id
			if not faction_id.is_empty():
				region.faction_id = faction_id
			if not surface_id.is_empty():
				region.surface_id = surface_id
			get_editor_interface().mark_scene_as_unsaved()
			_set_status("Applied the selected character setup to region [b]%s[/b]." % region.spawn_id)
			return
		if node is QuestGiver:
			var character := node as QuestGiver
			if not visual_id.is_empty():
				character.visual_id = visual_id
			if not archetype_id.is_empty():
				character.archetype_id = archetype_id
			if not faction_id.is_empty():
				character.faction_id = faction_id
			if not surface_id.is_empty():
				character.surface_id = surface_id
			get_editor_interface().mark_scene_as_unsaved()
			_set_status("Applied the selected character setup to [b]%s[/b]." % character.npc_id)
			return
	_set_status("Select a Character or Character Region node first.")


func _duplicate_selected_character() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if not node is CombatantSpawnArea and not node is QuestGiver:
			continue
		var parent := node.get_parent()
		var duplicate := node.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
		duplicate.name = _unique_child_name(parent, node.name)
		if duplicate is CombatantSpawnArea:
			(duplicate as CombatantSpawnArea).spawn_id = duplicate.name.to_snake_case()
		elif duplicate is QuestGiver:
			(duplicate as QuestGiver).npc_id = duplicate.name.to_snake_case()
			(duplicate as QuestGiver).quest_ids = PackedStringArray()
		if duplicate is Node2D:
			(duplicate as Node2D).position += Vector2(96.0, 0.0)
		parent.add_child(duplicate)
		_finish_add(duplicate, map_root, "Duplicated the selected character with a new stable ID.")
		return
	_set_status("Select a Character or Character Region to duplicate.")


func _toggle_selected_character() -> void:
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is CombatantSpawnArea:
			(node as CombatantSpawnArea).enabled = not (node as CombatantSpawnArea).enabled
			(node as CombatantSpawnArea).queue_redraw()
			get_editor_interface().mark_scene_as_unsaved()
			_set_status("Character region is now %s." % ("enabled" if (node as CombatantSpawnArea).enabled else "disabled"))
			return
		if node is QuestGiver:
			(node as QuestGiver).enabled = not (node as QuestGiver).enabled
			(node as QuestGiver).queue_redraw()
			get_editor_interface().mark_scene_as_unsaved()
			_set_status("Character is now %s." % ("enabled" if (node as QuestGiver).enabled else "disabled"))
			return
	_set_status("Select a Character or Character Region to enable or disable.")


func _create_behavior_for_selected() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var selected_node: Node = null
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is CombatantSpawnArea or node is AuthoredCharacter:
			selected_node = node
			break
	if selected_node == null:
		_set_status("Select a Character or Character Region first.")
		return
	var base_id := str(selected_node.get("spawn_id")) if selected_node is CombatantSpawnArea else str(selected_node.get("npc_id"))
	base_id = "%s_behavior" % base_id
	var behavior_folder := "res://maps/%s/behaviors" % map_root.map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(behavior_folder))
	var profile_id := base_id
	var index := 2
	var path := behavior_folder.path_join("%s.tres" % profile_id)
	while ResourceLoader.exists(path):
		profile_id = "%s_%d" % [base_id, index]
		path = behavior_folder.path_join("%s.tres" % profile_id)
		index += 1
	var profile := CombatantBehaviorProfile.new()
	profile.profile_id = profile_id
	if ResourceSaver.save(profile, path) != OK:
		_set_status("Could not save the behavior profile.")
		return
	selected_node.set("behavior_profile_id", profile_id)
	selected_node.set("behavior_profile", profile)
	get_editor_interface().mark_scene_as_unsaved()
	get_editor_interface().edit_resource(profile)
	_set_status("Created behavior [b]%s[/b]. Edit it in the Inspector." % profile_id)


func _add_area_transition() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "Transitions")
	var transition := AreaTransition.new()
	transition.name = _unique_child_name(container, "Transition")
	transition.transition_id = transition.name.to_snake_case()
	transition.origin_world_id = map_root.world_id
	transition.origin_map_id = map_root.map_id
	transition.position = _placement_position(map_root)
	container.add_child(transition)
	_finish_add(transition, map_root, "Added a transition. Select its destination below and click Apply Link.")


func _add_quest_area() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "QuestAreas")
	var area := QuestArea.new()
	area.name = _unique_child_name(container, "QuestArea")
	area.area_id = area.name.to_snake_case()
	area.display_name = area.name.replace("_", " ")
	area.position = _placement_position(map_root)
	container.add_child(area)
	_finish_add(area, map_root, "Added a resizable quest area.")


func _add_interactable() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "Interactables")
	var authored_object := WorldInteractable.new()
	authored_object.name = _unique_child_name(container, "Interactable")
	authored_object.object_id = authored_object.name.to_snake_case()
	authored_object.display_name = authored_object.name.replace("_", " ")
	authored_object.position = _placement_position(map_root)
	container.add_child(authored_object)
	_finish_add(authored_object, map_root, "Added an interactable world object.")


func _add_cinematic_marker() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var container := _container(map_root, "CinematicMarkers")
	var marker := CinematicMarker.new()
	marker.name = _unique_child_name(container, "CinematicMarker")
	marker.marker_id = marker.name.to_snake_case()
	marker.display_name = marker.name.replace("_", " ")
	marker.position = _placement_position(map_root)
	container.add_child(marker)
	_finish_add(marker, map_root, "Added a cinematic marker. Camera and movement cues can target this marker.")


func _add_quest_catalog() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	if _quest_catalog(map_root) != null:
		_set_status("This map already has a quest catalog.")
		return
	var container := _container(map_root, "Quests")
	var catalog := QuestCatalog.new()
	catalog.name = "QuestCatalog"
	container.add_child(catalog)
	_finish_add(catalog, map_root, "Added a quest catalog. Use the Quest Builder below.")


func _selected_transition() -> AreaTransition:
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is AreaTransition:
			return node as AreaTransition
	_set_status("Select an AreaTransition node in the scene tree first.")
	return null


func _on_destination_map_selected(_index: int) -> void:
	_refresh_destination_spawns()


func _refresh_destination_spawns() -> void:
	if _destination_spawn_selector == null:
		return
	var definition := WorldAuthoringCatalog.definition_for_map(_catalog, _selected_text(_destination_map_selector))
	_fill_option(_destination_spawn_selector, WorldAuthoringCatalog.object_ids(definition, "player_spawns", "spawn_id"))


func _refresh_return_spawns() -> void:
	if _return_spawn_selector == null:
		return
	var map_root := get_editor_interface().get_edited_scene_root() as MapRoot
	var values: PackedStringArray = []
	if map_root != null:
		values = WorldAuthoringCatalog.object_ids(map_root.collect_definition(), "player_spawns", "spawn_id")
	_fill_option(_return_spawn_selector, values)


func _apply_transition_link() -> void:
	var transition := _selected_transition()
	var map_root := _current_map_root()
	if transition == null or map_root == null:
		return
	transition.origin_world_id = map_root.world_id
	transition.origin_map_id = map_root.map_id
	transition.destination_world_id = map_root.world_id
	transition.destination_map_id = _selected_text(_destination_map_selector)
	transition.destination_spawn_id = _selected_text(_destination_spawn_selector)
	get_editor_interface().mark_scene_as_unsaved()
	transition.queue_redraw()
	_set_status("Linked [b]%s[/b] to %s/%s." % [transition.transition_id, transition.destination_map_id, transition.destination_spawn_id])


func _open_transition_destination() -> void:
	var transition := _selected_transition()
	if transition == null:
		return
	var path := WorldAuthoringCatalog.scene_path_for_map(_catalog, transition.destination_map_id)
	if path.is_empty():
		_set_status("Destination map does not exist locally.")
		return
	get_editor_interface().open_scene_from_path(path)


func _create_paired_transition() -> void:
	var transition := _selected_transition()
	var map_root := _current_map_root()
	if transition == null or map_root == null:
		return
	_apply_transition_link()
	var return_spawn_id := _selected_text(_return_spawn_selector)
	if return_spawn_id.is_empty():
		_set_status("Choose a return spawn on the current map.")
		return
	var destination_path := WorldAuthoringCatalog.scene_path_for_map(_catalog, transition.destination_map_id)
	var packed := ResourceLoader.load(destination_path, "PackedScene") as PackedScene
	if packed == null:
		_set_status("Could not load the destination scene.")
		return
	var destination_root := packed.instantiate() as MapRoot
	if destination_root == null:
		_set_status("Destination scene is not a MapRoot.")
		return
	var destination_container := _container(destination_root, "Transitions")
	var return_transition := AreaTransition.new()
	return_transition.name = _unique_child_name(destination_container, "%sReturn" % map_root.map_id.to_pascal_case())
	return_transition.transition_id = _unique_transition_id(destination_root, "%s_to_%s" % [destination_root.map_id, map_root.map_id])
	var destination_spawn := _find_player_spawn(destination_root, transition.destination_spawn_id)
	if destination_spawn != null:
		return_transition.position = destination_root.to_local(destination_spawn.global_position) + Vector2(96.0, 0.0)
	return_transition.display_name = "Travel to %s" % map_root.display_name
	return_transition.origin_world_id = destination_root.world_id
	return_transition.origin_map_id = destination_root.map_id
	return_transition.destination_world_id = map_root.world_id
	return_transition.destination_map_id = map_root.map_id
	return_transition.destination_spawn_id = return_spawn_id
	return_transition.one_way = false
	return_transition.paired_transition_id = transition.transition_id
	destination_container.add_child(return_transition)
	return_transition.owner = destination_root
	var repacked := PackedScene.new()
	var pack_error := repacked.pack(destination_root)
	if pack_error == OK:
		pack_error = ResourceSaver.save(repacked, destination_path)
	var paired_transition_id := return_transition.transition_id
	destination_root.free()
	if pack_error != OK:
		_set_status("Could not save the paired transition in %s." % destination_path)
		return
	transition.one_way = false
	transition.paired_transition_id = paired_transition_id
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_catalog()
	_set_status("Created paired link [b]%s[/b] in %s. Review both scenes before publishing." % [transition.paired_transition_id, destination_path])


func _find_player_spawn(map_root: MapRoot, spawn_id: String) -> MapPlayerSpawn:
	for node in map_root.find_children("*", "", true, false):
		if node is MapPlayerSpawn and (node as MapPlayerSpawn).spawn_id == spawn_id:
			return node as MapPlayerSpawn
	return null


func _quest_catalog(map_root: MapRoot) -> QuestCatalog:
	for node in map_root.find_children("*", "", true, false):
		if node is QuestCatalog:
			return node as QuestCatalog
	return null


func _refresh_quest_builder() -> void:
	if _quest_selector == null:
		return
	_quest_selector.clear()
	var map_root := get_editor_interface().get_edited_scene_root() as MapRoot
	if map_root == null:
		_clear_quest_form()
		return
	var catalog := _quest_catalog(map_root)
	if catalog != null:
		for quest in catalog.quests:
			if quest == null:
				continue
			_quest_selector.add_item("%s — %s" % [quest.quest_id, quest.title])
			_quest_selector.set_item_metadata(_quest_selector.item_count - 1, quest)
	_fill_quest_givers(map_root)
	_fill_stage_maps(map_root.map_id)
	if _quest_selector.item_count > 0:
		_quest_selector.select(0)
		_on_quest_selected(0)
	else:
		_clear_quest_form()


func _fill_quest_givers(map_root: MapRoot) -> void:
	var ids: PackedStringArray = [""]
	for node in map_root.find_children("*", "", true, false):
		if node is QuestGiver:
			ids.append((node as QuestGiver).npc_id)
	_fill_option(_quest_giver, ids)


func _fill_stage_maps(preferred_map_id := "") -> void:
	var ids := WorldAuthoringCatalog.map_ids(_catalog)
	_fill_option(_stage_map, ids)
	_select_option_text(_stage_map, preferred_map_id)
	_refresh_stage_targets()


func _on_quest_selected(index: int) -> void:
	if index < 0 or index >= _quest_selector.item_count:
		return
	_current_quest = _quest_selector.get_item_metadata(index) as QuestDefinition
	_current_stage_index = -1
	_load_quest_form()


func _load_quest_form() -> void:
	if _current_quest == null:
		_clear_quest_form()
		return
	_quest_id.text = _current_quest.quest_id
	_quest_title.text = _current_quest.title
	_select_option_text(_quest_giver, _current_quest.giver_npc_id)
	_quest_faction.text = _current_quest.required_committed_faction_id
	_quest_prerequisites.text = ", ".join(Array(_current_quest.prerequisite_quest_ids))
	_quest_rewards.text = JSON.stringify(_current_quest.rewards)
	_quest_repeatable.button_pressed = _current_quest.repeatable
	_quest_description.text = _current_quest.description
	_quest_offer.text = _current_quest.offer_text
	_quest_completion.text = _current_quest.completion_text
	_refresh_stage_list()


func _clear_quest_form() -> void:
	_current_quest = null
	_current_stage_index = -1
	if _quest_id == null:
		return
	for editor in [_quest_id, _quest_title, _quest_faction, _quest_prerequisites, _quest_rewards]:
		(editor as LineEdit).clear()
	for editor in [_quest_description, _quest_offer, _quest_completion]:
		(editor as TextEdit).clear()
	_stage_list.clear()


func _new_quest() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var catalog := _quest_catalog(map_root)
	if catalog == null:
		_add_quest_catalog()
		catalog = _quest_catalog(map_root)
	var quest := QuestDefinition.new()
	quest.quest_id = _unique_quest_id(catalog, "%s_quest" % map_root.map_id)
	quest.title = "New Quest"
	var stage := QuestStage.new()
	stage.stage_id = "stage_1"
	stage.target_map_id = map_root.map_id
	quest.stages = [stage]
	var quest_folder := "res://maps/%s/quests" % map_root.map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(quest_folder))
	var save_error := ResourceSaver.save(quest, quest_folder.path_join("%s.tres" % quest.quest_id))
	if save_error != OK:
		_set_status("Could not save the new quest resource.")
		return
	catalog.quests.append(quest)
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_quest_builder()
	_select_quest(quest.quest_id)
	_set_status("Created quest [b]%s[/b]." % quest.quest_id)


func _duplicate_quest() -> void:
	if _current_quest == null:
		_set_status("Select a quest to duplicate.")
		return
	var map_root := _current_map_root()
	var catalog := _quest_catalog(map_root)
	var duplicate := _current_quest.duplicate(true) as QuestDefinition
	duplicate.quest_id = _unique_quest_id(catalog, "%s_copy" % _current_quest.quest_id)
	duplicate.title = "%s Copy" % _current_quest.title
	var path := "res://maps/%s/quests/%s.tres" % [map_root.map_id, duplicate.quest_id]
	if ResourceSaver.save(duplicate, path) != OK:
		_set_status("Could not save the duplicated quest.")
		return
	catalog.quests.append(duplicate)
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_quest_builder()
	_select_quest(duplicate.quest_id)


func _request_delete_quest() -> void:
	if _current_quest == null:
		return
	_delete_quest_dialog.dialog_text = "Delete %s and remove it from every character on this map?" % _current_quest.quest_id
	_delete_quest_dialog.popup_centered(Vector2i(500, 180))


func _delete_current_quest() -> void:
	if _current_quest == null:
		return
	var map_root := _current_map_root()
	var catalog := _quest_catalog(map_root)
	var deleted_id := _current_quest.quest_id
	var resource_path := _current_quest.resource_path
	catalog.quests.erase(_current_quest)
	for node in map_root.find_children("*", "", true, false):
		if node is QuestGiver:
			var giver := node as QuestGiver
			var ids := Array(giver.quest_ids)
			ids.erase(deleted_id)
			giver.quest_ids = PackedStringArray(ids)
	_current_quest = null
	if not resource_path.is_empty() and resource_path.begins_with("res://maps/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_quest_builder()
	_set_status("Deleted quest [b]%s[/b]." % deleted_id)


func _save_quest_details() -> void:
	if _current_quest == null:
		_set_status("Create or select a quest first.")
		return
	var normalized_id := _quest_id.text.strip_edges().to_snake_case()
	if normalized_id.is_empty() or normalized_id != _quest_id.text.strip_edges():
		_set_status("Quest ID must be lowercase snake_case.")
		return
	var rewards_value: Variant = JSON.parse_string(_quest_rewards.text)
	if not rewards_value is Dictionary:
		_set_status("Rewards must be a JSON object, for example {\"xp\": 20, \"gold\": 10}.")
		return
	_current_quest.quest_id = normalized_id
	_current_quest.title = _quest_title.text.strip_edges()
	_current_quest.giver_npc_id = _selected_text(_quest_giver)
	_current_quest.required_committed_faction_id = _quest_faction.text.strip_edges()
	_current_quest.prerequisite_quest_ids = _comma_separated_values(_quest_prerequisites.text)
	_current_quest.rewards = (rewards_value as Dictionary).duplicate(true)
	_current_quest.repeatable = _quest_repeatable.button_pressed
	_current_quest.description = _quest_description.text
	_current_quest.offer_text = _quest_offer.text
	_current_quest.completion_text = _quest_completion.text
	_sync_quest_giver_assignment(_current_quest)
	if ResourceSaver.save(_current_quest, _current_quest.resource_path) != OK:
		_set_status("Quest changed in memory but its resource could not be saved.")
		return
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_quest_builder()
	_select_quest(normalized_id)
	_set_status("Saved quest [b]%s[/b]." % normalized_id)


func _sync_quest_giver_assignment(quest: QuestDefinition) -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	for node in map_root.find_children("*", "", true, false):
		if not node is QuestGiver:
			continue
		var giver := node as QuestGiver
		var ids := Array(giver.quest_ids)
		ids.erase(quest.quest_id)
		if giver.npc_id == quest.giver_npc_id:
			ids.append(quest.quest_id)
		giver.quest_ids = PackedStringArray(ids)


func _refresh_stage_list() -> void:
	_stage_list.clear()
	if _current_quest == null:
		return
	for index in _current_quest.stages.size():
		var stage := _current_quest.stages[index]
		_stage_list.add_item("%d. %s" % [index + 1, _stage_summary(stage)])


func _stage_summary(stage: QuestStage) -> String:
	if stage == null:
		return "(empty)"
	var target := stage.target_archetype_id
	match stage.objective_type:
		"talk": target = stage.target_npc_id
		"interact": target = stage.target_object_id if not stage.target_object_id.is_empty() else stage.target_npc_id
		"use_transition": target = stage.target_transition_id
		"enter_map": target = stage.target_map_id
		"enter_area": target = stage.target_area_id
	return "%s — %s %s x%d" % [stage.stage_id, stage.objective_type, target, stage.required_count]


func _on_stage_selected(index: int) -> void:
	if _current_quest == null or index < 0 or index >= _current_quest.stages.size():
		return
	_current_stage_index = index
	var stage := _current_quest.stages[index]
	_stage_id.text = stage.stage_id
	_select_option_text(_stage_type, stage.objective_type)
	var map_root := _current_map_root()
	var target_map_id := stage.target_map_id if not stage.target_map_id.is_empty() else map_root.map_id
	_select_option_text(_stage_map, target_map_id)
	_refresh_stage_targets()
	_select_option_text(_stage_target, _stage_target_id(stage))
	_refresh_kill_areas()
	_select_option_text(_stage_kill_area, stage.required_kill_area_id)
	_stage_count.value = stage.required_count


func _on_stage_type_selected(_index: int) -> void:
	_refresh_stage_targets()


func _on_stage_map_selected(_index: int) -> void:
	_refresh_stage_targets()


func _refresh_stage_targets() -> void:
	if _stage_target == null:
		return
	var objective_type := _selected_text(_stage_type)
	var target_map_id := _selected_text(_stage_map)
	var definition := WorldAuthoringCatalog.definition_for_map(_catalog, target_map_id)
	var targets: PackedStringArray = []
	match objective_type:
		"kill":
			for archetype_value in definition.get("archetypes", []):
				targets.append(str(archetype_value))
		"talk":
			targets = WorldAuthoringCatalog.object_ids(definition, "quest_givers", "npc_id")
		"interact":
			targets = WorldAuthoringCatalog.object_ids(definition, "interactable_objects", "object_id")
			targets.append_array(WorldAuthoringCatalog.object_ids(definition, "quest_givers", "npc_id"))
		"use_transition":
			targets = WorldAuthoringCatalog.object_ids(definition, "area_transitions", "transition_id")
		"enter_map":
			targets = PackedStringArray([target_map_id])
		"enter_area":
			targets = WorldAuthoringCatalog.object_ids(definition, "quest_areas", "area_id")
	_fill_option(_stage_target, targets)
	_refresh_kill_areas()
	var kill_area_container := _stage_kill_area.get_parent() as Control
	if kill_area_container != null:
		kill_area_container.visible = objective_type == "kill"


func _refresh_kill_areas() -> void:
	var definition := WorldAuthoringCatalog.definition_for_map(_catalog, _selected_text(_stage_map))
	var areas: PackedStringArray = [""]
	areas.append_array(WorldAuthoringCatalog.object_ids(definition, "quest_areas", "area_id"))
	_fill_option(_stage_kill_area, areas)


func _add_stage() -> void:
	if _current_quest == null:
		_set_status("Create or select a quest first.")
		return
	var stage := QuestStage.new()
	stage.stage_id = "stage_%d" % (_current_quest.stages.size() + 1)
	stage.target_map_id = _selected_text(_stage_map)
	_current_quest.stages.append(stage)
	_current_stage_index = _current_quest.stages.size() - 1
	_refresh_stage_list()
	_stage_list.select(_current_stage_index)
	_on_stage_selected(_current_stage_index)
	_save_current_quest_resource()


func _update_stage() -> void:
	if _current_quest == null or _current_stage_index < 0 or _current_stage_index >= _current_quest.stages.size():
		_set_status("Select a stage to update.")
		return
	var stage := _current_quest.stages[_current_stage_index]
	stage.stage_id = _stage_id.text.strip_edges().to_snake_case()
	stage.objective_type = _selected_text(_stage_type)
	stage.target_world_id = _current_map_root().world_id
	stage.target_map_id = _selected_text(_stage_map)
	stage.required_count = int(_stage_count.value)
	stage.target_archetype_id = ""
	stage.target_npc_id = ""
	stage.target_object_id = ""
	stage.target_transition_id = ""
	stage.target_spawn_id = ""
	stage.target_area_id = ""
	stage.required_kill_area_id = ""
	var target_id := _selected_text(_stage_target)
	match stage.objective_type:
		"kill":
			stage.target_archetype_id = target_id
			stage.required_kill_area_id = _selected_text(_stage_kill_area)
		"talk":
			stage.target_npc_id = target_id
		"interact":
			var definition := WorldAuthoringCatalog.definition_for_map(_catalog, stage.target_map_id)
			if WorldAuthoringCatalog.object_ids(definition, "interactable_objects", "object_id").has(target_id):
				stage.target_object_id = target_id
			else:
				stage.target_npc_id = target_id
		"use_transition":
			stage.target_transition_id = target_id
			var definition := WorldAuthoringCatalog.definition_for_map(_catalog, stage.target_map_id)
			for transition_value in definition.get("area_transitions", []):
				if transition_value is Dictionary and str((transition_value as Dictionary).get("transition_id", "")) == target_id:
					var destination: Dictionary = (transition_value as Dictionary).get("destination", {})
					stage.target_spawn_id = str(destination.get("spawn_id", ""))
					break
		"enter_map":
			stage.target_map_id = target_id
		"enter_area":
			stage.target_area_id = target_id
	_save_current_quest_resource()
	_refresh_stage_list()
	_stage_list.select(_current_stage_index)


func _move_stage(direction: int) -> void:
	if _current_quest == null or _current_stage_index < 0:
		return
	var destination := _current_stage_index + direction
	if destination < 0 or destination >= _current_quest.stages.size():
		return
	var stage := _current_quest.stages[_current_stage_index]
	_current_quest.stages.remove_at(_current_stage_index)
	_current_quest.stages.insert(destination, stage)
	_current_stage_index = destination
	_save_current_quest_resource()
	_refresh_stage_list()
	_stage_list.select(destination)


func _remove_stage() -> void:
	if _current_quest == null or _current_stage_index < 0:
		return
	_current_quest.stages.remove_at(_current_stage_index)
	_current_stage_index = mini(_current_stage_index, _current_quest.stages.size() - 1)
	_save_current_quest_resource()
	_refresh_stage_list()
	if _current_stage_index >= 0:
		_stage_list.select(_current_stage_index)
		_on_stage_selected(_current_stage_index)


func _save_current_quest_resource() -> void:
	if _current_quest == null:
		return
	ResourceSaver.save(_current_quest, _current_quest.resource_path)
	get_editor_interface().mark_scene_as_unsaved()


func _stage_target_id(stage: QuestStage) -> String:
	match stage.objective_type:
		"kill": return stage.target_archetype_id
		"talk": return stage.target_npc_id
		"interact": return stage.target_object_id if not stage.target_object_id.is_empty() else stage.target_npc_id
		"use_transition": return stage.target_transition_id
		"enter_map": return stage.target_map_id
		"enter_area": return stage.target_area_id
	return ""


func _validate_current_map() -> void:
	_validation_results.clear()
	_validation_paths.clear()
	var map_root := _current_map_root()
	if map_root == null:
		return
	var errors := map_root.validate_definition()
	_show_validation(errors, get_editor_interface().get_edited_scene_root().scene_file_path)


func _validate_entire_world() -> void:
	_refresh_catalog()
	_validation_results.clear()
	_validation_paths.clear()
	var errors := WorldAuthoringCatalog.validate_world(_catalog)
	_show_validation(errors)


func _show_validation(errors: PackedStringArray, default_path := "") -> void:
	if errors.is_empty():
		_validation_results.add_item("✓ No validation errors")
		_validation_paths.append("")
		_set_status("[color=green]Validation passed.[/color]")
		return
	for error in errors:
		_validation_results.add_item(error)
		var candidate_path := error.get_slice(":", 0)
		_validation_paths.append(candidate_path if candidate_path.begins_with("res://") else default_path)
	_set_status("[color=red]%d validation error(s). Double-click an error to open its map.[/color]" % errors.size())


func _open_validation_result(index: int) -> void:
	if index < 0 or index >= _validation_paths.size():
		return
	var path := _validation_paths[index]
	_pending_validation_message = _validation_results.get_item_text(index)
	if not path.is_empty() and ResourceLoader.exists(path):
		get_editor_interface().open_scene_from_path(path)
	else:
		_select_validation_object(_pending_validation_message)


func _select_validation_object(message: String) -> void:
	var map_root := get_editor_interface().get_edited_scene_root() as MapRoot
	if map_root == null:
		return
	for node in map_root.find_children("*", "", true, false):
		for property_name in ["spawn_id", "npc_id", "transition_id", "area_id", "object_id", "surface_id", "marker_id"]:
			if not _object_has_property(node, property_name):
				continue
			var value: Variant = node.get(property_name)
			if value == null:
				continue
			var object_id := str(value)
			if object_id.length() >= 3 and message.contains(object_id):
				get_editor_interface().get_selection().clear()
				get_editor_interface().get_selection().add_node(node)
				get_editor_interface().edit_node(node)
				_pending_validation_message = ""
				return
	var catalog := _quest_catalog(map_root)
	if catalog != null:
		for quest in catalog.quests:
			if quest != null and message.contains(quest.quest_id):
				get_editor_interface().edit_resource(quest)
				_pending_validation_message = ""
				return
	_pending_validation_message = ""


func _object_has_property(object: Object, property_name: String) -> bool:
	for property_value in object.get_property_list():
		if property_value is Dictionary and str((property_value as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _preview_current_map() -> void:
	var map_root := _current_map_root()
	if map_root == null:
		return
	var errors := map_root.validate_definition()
	if not errors.is_empty():
		_show_validation(errors, map_root.scene_file_path)
		_set_status("Fix current-map validation errors before previewing.")
		return
	ProjectSettings.set_setting("map_authoring/preview_map_scene", map_root.scene_file_path)
	ProjectSettings.set_setting("map_authoring/preview_spawn_id", _selected_text(_return_spawn_selector))
	get_editor_interface().save_scene()
	get_editor_interface().play_custom_scene(PREVIEW_SCENE)
	_set_status("Preview started. Use A/D or arrow keys to move the camera; mouse wheel zooms.")


func _export_current_map() -> void:
	_set_status("Preparing map export...")
	var map_root := _current_map_root()
	if map_root == null:
		return
	var errors := map_root.validate_definition()
	if not errors.is_empty():
		_show_validation(errors, map_root.scene_file_path)
		return
	var export_error := _write_definition_file(map_root)
	_set_status(export_error if not export_error.is_empty() else "Exported res://maps/%s/%s.definition.json." % [map_root.map_id, map_root.map_id])


func _validate_with_backend() -> void:
	_set_status("Preparing backend validation...")
	var map_root := _current_map_root()
	if map_root == null or not _validate_before_backend(map_root):
		return
	if not await _ensure_scope_ready():
		return
	var maps := _map_service()
	if maps == null:
		return
	var result := await maps.validate_definition(map_root.world_id, map_root.map_id, map_root.collect_definition())
	_set_status("Backend validation passed." if result.success else "Backend validation failed (%d): %s" % [result.status, _response_error_text(result)])


func _login_to_backend() -> void:
	if _email_input.text.strip_edges().is_empty() or _password_input.text.is_empty():
		_set_status("Enter an email and password.")
		return
	if not await _ensure_scope_initialized():
		return
	var result := await Scope.call("login", _email_input.text.strip_edges(), _password_input.text)
	_password_input.clear()
	_set_status("Logged in. Publishing is authenticated." if result.success else "Login failed (%d): %s" % [result.status, result.message])


func _publish_current_map() -> void:
	_set_status("Preparing map publication...")
	var map_root := _current_map_root()
	if map_root == null or not _validate_before_backend(map_root):
		return
	if get_editor_interface().save_scene() != OK:
		_set_status("Save the current scene before publishing.")
		return
	if not await _ensure_scope_ready():
		return
	var maps := _map_service()
	if maps == null:
		return
	var current_definition := await maps.get_definition(map_root.world_id, map_root.map_id)
	var expected_version := map_root.published_version
	var change_summary := "New map"
	if current_definition.success:
		var current_data: Dictionary = current_definition.data if current_definition.data is Dictionary else {}
		expected_version = int(current_data.get("version", current_data.get("published_version", expected_version)))
		var remote_definition_value: Variant = current_data.get("definition", current_data)
		var remote_definition: Dictionary = remote_definition_value if remote_definition_value is Dictionary else current_data
		change_summary = _definition_change_summary(map_root.collect_definition(), remote_definition)
	elif current_definition.status == 404:
		expected_version = 0
	else:
		_set_status("Unable to refresh the live version (%d): %s" % [current_definition.status, _response_error_text(current_definition)])
		return
	_pending_publish = {
		"map_root": map_root,
		"expected_version": expected_version,
		"change_summary": change_summary
	}
	_publish_dialog.dialog_text = "Publish %s?\n\nChanges: %s\n\nThe editable Godot scene remains the source of truth." % [map_root.display_name, change_summary]
	_publish_dialog.popup_centered(Vector2i(620, 260))
	_set_status("Publish is ready. Review the change summary and confirm.")


func _complete_pending_publish() -> void:
	if _pending_publish.is_empty():
		return
	var map_root := _pending_publish.get("map_root") as MapRoot
	if map_root == null or not is_instance_valid(map_root):
		_set_status("The map changed before publishing. Start the publish check again.")
		_pending_publish.clear()
		return
	var maps := _map_service()
	if maps == null:
		_pending_publish.clear()
		return
	var expected_version := int(_pending_publish.get("expected_version", map_root.published_version))
	var change_summary := str(_pending_publish.get("change_summary", ""))
	var definition := map_root.collect_definition()
	definition["version"] = expected_version
	var result := await maps.publish_definition(map_root.world_id, map_root.map_id, definition, expected_version)
	if not result.success:
		_set_status("Publish failed (%d): %s" % [result.status, _response_error_text(result)])
		_pending_publish.clear()
		return
	var response_data: Dictionary = result.data if result.data is Dictionary else {}
	map_root.published_version = int(response_data.get("version", response_data.get("published_version", map_root.published_version)))
	get_editor_interface().mark_scene_as_unsaved()
	get_editor_interface().save_scene()
	var export_error := _write_definition_file(map_root)
	_set_status("Published and exported [b]%s[/b] version %d. %s" % [map_root.map_id, map_root.published_version, change_summary] if export_error.is_empty() else "Published, but %s" % export_error)
	_pending_publish.clear()


func _cancel_pending_publish() -> void:
	_pending_publish.clear()
	_set_status("Publish canceled. No backend changes were made.")


func _validate_before_backend(map_root: MapRoot) -> bool:
	var local_errors := map_root.validate_definition()
	if not local_errors.is_empty():
		_show_validation(local_errors, map_root.scene_file_path)
		return false
	_refresh_catalog()
	var world_errors := WorldAuthoringCatalog.validate_world(_catalog)
	if not world_errors.is_empty():
		_show_validation(world_errors)
		return false
	return true


func _refresh_published_version() -> void:
	var map_root := _current_map_root()
	if map_root == null or not await _ensure_scope_ready():
		return
	var result := await _map_service().get_definition(map_root.world_id, map_root.map_id)
	if not result.success:
		_set_status("Unable to fetch the published map (%d): %s" % [result.status, result.message])
		return
	var response_data: Dictionary = result.data if result.data is Dictionary else {}
	map_root.published_version = int(response_data.get("version", response_data.get("published_version", 0)))
	get_editor_interface().mark_scene_as_unsaved()
	_set_status("Published version is %d. Save the scene to keep it in sync." % map_root.published_version)


func _ensure_scope_ready() -> bool:
	if not await _ensure_scope_initialized():
		return false
	if Scope.call("is_logged_in") != true:
		_set_status("Log in before using backend map operations.")
		return false
	return _map_service() != null


func _ensure_scope_initialized() -> bool:
	if not is_instance_valid(Scope):
		_set_status("Scope SDK is unavailable in the editor.")
		return false
	if Scope.get("initialized") != true:
		var result := await Scope.call("initialize")
		if not result.success:
			_set_status("Scope initialization failed: %s" % result.message)
			return false
	return true


func _map_service() -> ScopeMaps:
	var maps := Scope.get("maps") as ScopeMaps
	if maps == null:
		_set_status("Map API is unavailable. Restart Godot after updating the Scope SDK.")
	return maps


func _response_error_text(result: ScopeResponse) -> String:
	if result.data != null:
		var details := JSON.stringify(result.data)
		if not details.is_empty() and details != "null":
			return "%s | %s" % [result.message, details]
	return result.message


func _write_definition_file(map_root: MapRoot) -> String:
	var output_path := "res://maps/%s/%s.definition.json" % [map_root.map_id, map_root.map_id]
	# Build the complete definition before opening the destination. If content
	# collection fails, the last known-good export is not truncated.
	var definition_text := map_root.definition_json()
	if definition_text.is_empty():
		return "Generated definition was empty; the existing export was preserved."
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return "Unable to write %s." % output_path
	file.store_string(definition_text)
	file.close()
	return ""


func _definition_change_summary(local_definition: Dictionary, remote_definition: Dictionary) -> String:
	var parts: PackedStringArray = []
	for collection in ["physics_surfaces", "player_spawns", "combatant_spawns", "quest_givers", "area_transitions", "quest_areas", "interactable_objects", "quests", "cinematic_markers"]:
		var local_value: Variant = local_definition.get(collection, [])
		var remote_value: Variant = remote_definition.get(collection, [])
		var local_count := (local_value as Array).size() if local_value is Array else 0
		var remote_count := (remote_value as Array).size() if remote_value is Array else 0
		if local_count != remote_count:
			parts.append("%s %d→%d" % [collection, remote_count, local_count])
	_append_storytelling_changes(local_definition, remote_definition, parts)
	return "no object-count changes" if parts.is_empty() else ", ".join(Array(parts))


func _append_storytelling_changes(local_definition: Dictionary, remote_definition: Dictionary, parts: PackedStringArray) -> void:
	var local_conversations := _definitions_by_id(local_definition.get("dialogue_conversations", []), "conversation_id")
	var remote_conversations := _definitions_by_id(remote_definition.get("dialogue_conversations", []), "conversation_id")
	_append_added_removed_ids("conversation", local_conversations, remote_conversations, parts, false)
	for conversation_id_value in local_conversations.keys():
		var conversation_id := str(conversation_id_value)
		if not remote_conversations.has(conversation_id):
			continue
		var local_conversation: Dictionary = local_conversations[conversation_id]
		var remote_conversation: Dictionary = remote_conversations[conversation_id]
		var local_nodes := _definitions_by_id(local_conversation.get("nodes", []), "node_id")
		var remote_nodes := _definitions_by_id(remote_conversation.get("nodes", []), "node_id")
		_append_added_removed_ids("%s node" % conversation_id, local_nodes, remote_nodes, parts, false)
		for node_id_value in local_nodes.keys():
			var node_id := str(node_id_value)
			if not remote_nodes.has(node_id):
				continue
			var local_node: Dictionary = local_nodes[node_id]
			var remote_node: Dictionary = remote_nodes[node_id]
			for field in ["speaker_npc_id", "speaker_name_override", "text", "portrait_id", "expression_id", "automatic_next_node_id", "cinematic_id", "ends_conversation"]:
				if local_node.get(field) != remote_node.get(field):
					parts.append("%s/%s content or path changed" % [conversation_id, node_id])
					break
			if JSON.stringify(local_node.get("conditions", [])) != JSON.stringify(remote_node.get("conditions", [])):
				parts.append("%s/%s conditions changed" % [conversation_id, node_id])
			if JSON.stringify(local_node.get("actions", [])) != JSON.stringify(remote_node.get("actions", [])):
				parts.append("WARNING %s/%s actions changed" % [conversation_id, node_id])
			var local_choices := _definitions_by_id(local_node.get("choices", []), "choice_id")
			var remote_choices := _definitions_by_id(remote_node.get("choices", []), "choice_id")
			_append_added_removed_ids("%s/%s choice" % [conversation_id, node_id], local_choices, remote_choices, parts, false)
			for choice_id_value in local_choices.keys():
				var choice_id := str(choice_id_value)
				if not remote_choices.has(choice_id):
					continue
				var local_choice: Dictionary = local_choices[choice_id]
				var remote_choice: Dictionary = remote_choices[choice_id]
				if str(local_choice.get("text", "")) != str(remote_choice.get("text", "")):
					parts.append("%s/%s/%s text changed" % [conversation_id, node_id, choice_id])
				if str(local_choice.get("destination_node_id", "")) != str(remote_choice.get("destination_node_id", "")):
					parts.append("%s/%s/%s destination changed" % [conversation_id, node_id, choice_id])
				if JSON.stringify(local_choice.get("conditions", [])) != JSON.stringify(remote_choice.get("conditions", [])):
					parts.append("%s/%s/%s conditions changed" % [conversation_id, node_id, choice_id])
				if JSON.stringify(local_choice.get("actions", [])) != JSON.stringify(remote_choice.get("actions", [])):
					parts.append("WARNING %s/%s/%s actions changed" % [conversation_id, node_id, choice_id])
	var local_flags := _definitions_by_id(local_definition.get("story_flags", []), "flag_id")
	var remote_flags := _definitions_by_id(remote_definition.get("story_flags", []), "flag_id")
	_append_added_removed_ids("story flag", local_flags, remote_flags, parts, true)
	for flag_id_value in local_flags.keys():
		var flag_id := str(flag_id_value)
		if remote_flags.has(flag_id) and JSON.stringify(local_flags[flag_id]) != JSON.stringify(remote_flags[flag_id]):
			parts.append("WARNING story flag %s changed" % flag_id)
	var local_cinematics := _definitions_by_id(local_definition.get("cinematic_sequences", []), "cinematic_id")
	var remote_cinematics := _definitions_by_id(remote_definition.get("cinematic_sequences", []), "cinematic_id")
	_append_added_removed_ids("cinematic", local_cinematics, remote_cinematics, parts, false)
	for cinematic_id_value in local_cinematics.keys():
		var cinematic_id := str(cinematic_id_value)
		if remote_cinematics.has(cinematic_id) and JSON.stringify(local_cinematics[cinematic_id]) != JSON.stringify(remote_cinematics[cinematic_id]):
			parts.append("cinematic %s changed" % cinematic_id)


func _definitions_by_id(values: Variant, id_field: String) -> Dictionary:
	var indexed: Dictionary = {}
	if not values is Array:
		return indexed
	for value in values:
		if value is Dictionary:
			var object_id := str((value as Dictionary).get(id_field, ""))
			if not object_id.is_empty():
				indexed[object_id] = value
	return indexed


func _append_added_removed_ids(label: String, local_values: Dictionary, remote_values: Dictionary, parts: PackedStringArray, warn_on_remove: bool) -> void:
	for object_id_value in local_values.keys():
		var object_id := str(object_id_value)
		if not remote_values.has(object_id):
			parts.append("%s %s added" % [label, object_id])
	for object_id_value in remote_values.keys():
		var object_id := str(object_id_value)
		if not local_values.has(object_id):
			parts.append("%s%s %s removed" % ["WARNING " if warn_on_remove else "", label, object_id])


func _fill_option(option: OptionButton, values: PackedStringArray) -> void:
	if option == null:
		return
	var previous := _selected_text(option)
	option.clear()
	for value in values:
		option.add_item(value if not value.is_empty() else "(none)")
		option.set_item_metadata(option.item_count - 1, value)
	if not previous.is_empty():
		_select_option_text(option, previous)


func _selected_text(option: OptionButton) -> String:
	if option == null or option.item_count == 0 or option.selected < 0:
		return ""
	var metadata: Variant = option.get_item_metadata(option.selected)
	return str(metadata) if metadata != null else option.get_item_text(option.selected)


func _select_option_text(option: OptionButton, value: String) -> void:
	if option == null:
		return
	for index in option.item_count:
		var metadata: Variant = option.get_item_metadata(index)
		var item_value := str(metadata) if metadata != null else option.get_item_text(index)
		if item_value == value:
			option.select(index)
			return


func _comma_separated_values(value: String) -> PackedStringArray:
	var values: PackedStringArray = []
	for part in value.split(",", false):
		var normalized := part.strip_edges()
		if not normalized.is_empty():
			values.append(normalized)
	return values


func _discover_character_visual_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for file_name in DirAccess.get_files_at("res://assets/NPCSHEETS"):
		if not file_name.to_lower().ends_with(".png"):
			continue
		var visual_id := file_name.get_basename().to_snake_case()
		if not ids.has(visual_id):
			ids.append(visual_id)
	ids.sort()
	return ids


func _unique_child_name(parent: Node, prefix: String) -> String:
	var index := 1
	while parent.get_node_or_null("%s_%02d" % [prefix, index]) != null:
		index += 1
	return "%s_%02d" % [prefix, index]


func _unique_transition_id(map_root: MapRoot, base_id: String) -> String:
	var used: Dictionary = {}
	for node in map_root.find_children("*", "", true, false):
		if node is AreaTransition:
			used[(node as AreaTransition).transition_id] = true
	var candidate := base_id.to_snake_case()
	var index := 2
	while used.has(candidate):
		candidate = "%s_%d" % [base_id.to_snake_case(), index]
		index += 1
	return candidate


func _unique_quest_id(catalog: QuestCatalog, base_id: String) -> String:
	var used: Dictionary = {}
	for quest in catalog.quests:
		if quest != null:
			used[quest.quest_id] = true
	var candidate := base_id.to_snake_case()
	var index := 2
	while used.has(candidate):
		candidate = "%s_%d" % [base_id.to_snake_case(), index]
		index += 1
	return candidate


func _select_quest(quest_id: String) -> void:
	for index in _quest_selector.item_count:
		var quest := _quest_selector.get_item_metadata(index) as QuestDefinition
		if quest != null and quest.quest_id == quest_id:
			_quest_selector.select(index)
			_on_quest_selected(index)
			return


func _set_status(message: String) -> void:
	if _status != null:
		_status.text = message
