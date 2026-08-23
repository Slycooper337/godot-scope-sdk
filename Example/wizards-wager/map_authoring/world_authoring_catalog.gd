@tool
class_name WorldAuthoringCatalog
extends RefCounted


static func discover_map_scene_paths(root_path := "res://maps") -> PackedStringArray:
	var paths: PackedStringArray = []
	_scan_directory(root_path, paths)
	paths.sort()
	return paths


static func _scan_directory(path: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := path.path_join(entry)
			if directory.current_is_dir():
				_scan_directory(entry_path, paths)
			elif entry.ends_with("_map.tscn"):
				paths.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func build_catalog() -> Dictionary:
	var maps: Dictionary = {}
	var scene_paths := discover_map_scene_paths()
	for scene_path in scene_paths:
		var packed := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		if not instance is MapRoot:
			instance.free()
			continue
		var map_root := instance as MapRoot
		var definition := map_root.collect_definition()
		var local_errors := map_root.validate_definition()
		var map_id := str(definition.get("map_id", ""))
		maps[map_id] = {
			"scene_path": scene_path,
			"definition": definition,
			"local_errors": local_errors
		}
		instance.free()
	return {"maps": maps, "scene_paths": scene_paths}


static func map_ids(catalog: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	var maps: Dictionary = catalog.get("maps", {})
	for map_id_value in maps.keys():
		ids.append(str(map_id_value))
	ids.sort()
	return ids


static func definition_for_map(catalog: Dictionary, map_id: String) -> Dictionary:
	var maps: Dictionary = catalog.get("maps", {})
	var entry_value: Variant = maps.get(map_id, {})
	if not entry_value is Dictionary:
		return {}
	var entry: Dictionary = entry_value
	var definition_value: Variant = entry.get("definition", {})
	return definition_value if definition_value is Dictionary else {}


static func scene_path_for_map(catalog: Dictionary, map_id: String) -> String:
	var maps: Dictionary = catalog.get("maps", {})
	var entry_value: Variant = maps.get(map_id, {})
	return str((entry_value as Dictionary).get("scene_path", "")) if entry_value is Dictionary else ""


static func object_ids(definition: Dictionary, collection: String, id_field: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	var values: Variant = definition.get(collection, [])
	if values is Array:
		for value in values:
			if value is Dictionary:
				var object_id := str((value as Dictionary).get(id_field, ""))
				if not object_id.is_empty():
					ids.append(object_id)
	ids.sort()
	return ids


static func validate_world(catalog: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var maps: Dictionary = catalog.get("maps", {})
	var quests: Dictionary = {}
	for map_id_value in maps.keys():
		var map_id := str(map_id_value)
		var entry: Dictionary = maps[map_id]
		var definition: Dictionary = entry.get("definition", {})
		var scene_path := str(entry.get("scene_path", ""))
		for local_error_value in entry.get("local_errors", []):
			errors.append("%s: %s" % [scene_path, str(local_error_value)])
		if map_id.is_empty():
			errors.append("%s: map_id is empty." % scene_path)
			continue
		var player_spawns_value: Variant = definition.get("player_spawns", [])
		if bool(definition.get("enterable", false)) and (not player_spawns_value is Array or (player_spawns_value as Array).is_empty()):
			errors.append("%s: enterable map %s has no player spawn." % [scene_path, map_id])
		for quest_value in definition.get("quests", []):
			if not quest_value is Dictionary:
				continue
			var quest: Dictionary = quest_value
			var quest_id := str(quest.get("quest_id", ""))
			if quests.has(quest_id):
				errors.append("%s: quest ID %s also exists in another map." % [scene_path, quest_id])
			else:
				quests[quest_id] = {"map_id": map_id, "quest": quest, "scene_path": scene_path}
	for map_id_value in maps.keys():
		var map_id := str(map_id_value)
		var entry: Dictionary = maps[map_id]
		var definition: Dictionary = entry.get("definition", {})
		var scene_path := str(entry.get("scene_path", ""))
		_validate_transitions(map_id, definition, catalog, scene_path, errors)
		_validate_quest_targets(map_id, definition, catalog, scene_path, errors)
		_validate_quest_assignments(definition, scene_path, errors)
	for quest_id_value in quests.keys():
		var quest_id := str(quest_id_value)
		var quest_entry: Dictionary = quests[quest_id]
		var quest: Dictionary = quest_entry["quest"]
		for prerequisite_value in quest.get("prerequisite_quest_ids", []):
			var prerequisite_id := str(prerequisite_value)
			if not quests.has(prerequisite_id):
				errors.append("%s: quest %s requires missing quest %s." % [str(quest_entry["scene_path"]), quest_id, prerequisite_id])
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for quest_id_value in quests.keys():
		var path: Array[String] = []
		_check_quest_cycle(str(quest_id_value), quests, visiting, visited, path, errors)
	_validate_world_storytelling(catalog, errors)
	return errors


static func _validate_transitions(map_id: String, definition: Dictionary, catalog: Dictionary, scene_path: String, errors: PackedStringArray) -> void:
	for transition_value in definition.get("area_transitions", []):
		if not transition_value is Dictionary:
			continue
		var transition: Dictionary = transition_value
		var transition_id := str(transition.get("transition_id", ""))
		var destination_value: Variant = transition.get("destination", {})
		var destination: Dictionary = destination_value if destination_value is Dictionary else {}
		var destination_map_id := str(destination.get("map_id", ""))
		var destination_spawn_id := str(destination.get("spawn_id", transition.get("destination_spawn_id", "")))
		var destination_definition := definition_for_map(catalog, destination_map_id)
		if destination_definition.is_empty():
			errors.append("%s: transition %s points to missing map %s." % [scene_path, transition_id, destination_map_id])
			continue
		var destination_spawns := object_ids(destination_definition, "player_spawns", "spawn_id")
		if not destination_spawns.has(destination_spawn_id):
			errors.append("%s: transition %s points to missing spawn %s/%s." % [scene_path, transition_id, destination_map_id, destination_spawn_id])
		var paired_id := str(transition.get("paired_transition_id", ""))
		if not paired_id.is_empty():
			var paired_transitions := object_ids(destination_definition, "area_transitions", "transition_id")
			if not paired_transitions.has(paired_id):
				errors.append("%s: transition %s expects missing paired transition %s/%s." % [scene_path, transition_id, destination_map_id, paired_id])
		elif not bool(transition.get("one_way", true)):
			errors.append("%s: two-way transition %s has no paired_transition_id." % [scene_path, transition_id])


static func _validate_quest_targets(map_id: String, definition: Dictionary, catalog: Dictionary, scene_path: String, errors: PackedStringArray) -> void:
	for quest_value in definition.get("quests", []):
		if not quest_value is Dictionary:
			continue
		var quest: Dictionary = quest_value
		var quest_id := str(quest.get("quest_id", ""))
		for stage_value in quest.get("stages", []):
			if not stage_value is Dictionary:
				continue
			var stage: Dictionary = stage_value
			var stage_id := str(stage.get("stage_id", ""))
			var objective_type := str(stage.get("objective_type", ""))
			var target_map_id := str(stage.get("target_map_id", ""))
			if target_map_id.is_empty():
				target_map_id = map_id
			# Existing transition stages store the destination in target_map_id,
			# while the transition object is authored on the quest's map.
			var lookup_map_id := map_id if objective_type == "use_transition" else target_map_id
			var target_definition := definition_for_map(catalog, lookup_map_id)
			if target_definition.is_empty():
				errors.append("%s: quest %s/%s targets missing map %s." % [scene_path, quest_id, stage_id, lookup_map_id])
				continue
			var collection := ""
			var id_field := ""
			var target_id := ""
			match objective_type:
				"talk":
					collection = "quest_givers"
					id_field = "npc_id"
					target_id = str(stage.get("target_npc_id", ""))
				"interact":
					if not str(stage.get("target_object_id", "")).is_empty():
						collection = "interactable_objects"
						id_field = "object_id"
						target_id = str(stage.get("target_object_id", ""))
					else:
						collection = "quest_givers"
						id_field = "npc_id"
						target_id = str(stage.get("target_npc_id", ""))
				"use_transition":
					collection = "area_transitions"
					id_field = "transition_id"
					target_id = str(stage.get("target_transition_id", ""))
				"enter_map":
					continue
				"enter_area":
					collection = "quest_areas"
					id_field = "area_id"
					target_id = str(stage.get("target_area_id", ""))
				"kill":
					var kill_area_id := str(stage.get("required_kill_area_id", ""))
					if not kill_area_id.is_empty() and not object_ids(target_definition, "quest_areas", "area_id").has(kill_area_id):
						errors.append("%s: quest %s/%s references missing kill area %s/%s." % [scene_path, quest_id, stage_id, target_map_id, kill_area_id])
					continue
			if not collection.is_empty() and not object_ids(target_definition, collection, id_field).has(target_id):
				errors.append("%s: quest %s/%s references missing %s target %s/%s." % [scene_path, quest_id, stage_id, objective_type, target_map_id, target_id])


static func _validate_quest_assignments(definition: Dictionary, scene_path: String, errors: PackedStringArray) -> void:
	var assignments: Dictionary = {}
	for giver_value in definition.get("quest_givers", []):
		if not giver_value is Dictionary:
			continue
		var giver: Dictionary = giver_value
		for quest_id_value in giver.get("quest_ids", []):
			assignments[str(quest_id_value)] = str(giver.get("npc_id", ""))
	for quest_value in definition.get("quests", []):
		if not quest_value is Dictionary:
			continue
		var quest: Dictionary = quest_value
		var quest_id := str(quest.get("quest_id", ""))
		var giver_npc_id := str(quest.get("giver_npc_id", ""))
		if not giver_npc_id.is_empty() and str(assignments.get(quest_id, "")) != giver_npc_id:
			errors.append("%s: quest %s giver is %s but that character does not list the quest." % [scene_path, quest_id, giver_npc_id])


static func _check_quest_cycle(quest_id: String, quests: Dictionary, visiting: Dictionary, visited: Dictionary, path: Array[String], errors: PackedStringArray) -> void:
	if visited.has(quest_id) or not quests.has(quest_id):
		return
	if visiting.has(quest_id):
		var cycle := path.duplicate()
		cycle.append(quest_id)
		errors.append("Quest prerequisite cycle: %s." % " -> ".join(cycle))
		return
	visiting[quest_id] = true
	path.append(quest_id)
	var quest_entry: Dictionary = quests[quest_id]
	var quest: Dictionary = quest_entry["quest"]
	for prerequisite_value in quest.get("prerequisite_quest_ids", []):
		_check_quest_cycle(str(prerequisite_value), quests, visiting, visited, path, errors)
	path.pop_back()
	visiting.erase(quest_id)
	visited[quest_id] = true


static func _validate_world_storytelling(catalog: Dictionary, errors: PackedStringArray) -> void:
	var maps: Dictionary = catalog.get("maps", {})
	var conversations: Dictionary = {}
	var flags: Dictionary = {}
	var cinematics: Dictionary = {}
	for map_id_value in maps.keys():
		var map_id := str(map_id_value)
		var entry: Dictionary = maps[map_id]
		var definition: Dictionary = entry.get("definition", {})
		var scene_path := str(entry.get("scene_path", ""))
		for conversation_value in definition.get("dialogue_conversations", []):
			if not conversation_value is Dictionary:
				continue
			var conversation_id := str((conversation_value as Dictionary).get("conversation_id", ""))
			if conversations.has(conversation_id):
				errors.append("%s: conversation %s also exists in %s." % [scene_path, conversation_id, str((conversations[conversation_id] as Dictionary).get("map_id", ""))])
			else:
				conversations[conversation_id] = {"map_id": map_id, "scene_path": scene_path}
		for flag_value in definition.get("story_flags", []):
			if not flag_value is Dictionary:
				continue
			var flag: Dictionary = flag_value
			var flag_id := str(flag.get("flag_id", ""))
			if flags.has(flag_id):
				var existing: Dictionary = flags[flag_id]
				if str(existing.get("value_type", "")) != str(flag.get("value_type", "")) or existing.get("default_value") != flag.get("default_value"):
					errors.append("%s: story flag %s conflicts with its definition in %s." % [scene_path, flag_id, str(existing.get("map_id", ""))])
			else:
				flags[flag_id] = {"map_id": map_id, "value_type": flag.get("value_type"), "default_value": flag.get("default_value")}
		for cinematic_value in definition.get("cinematic_sequences", []):
			if not cinematic_value is Dictionary:
				continue
			var cinematic_id := str((cinematic_value as Dictionary).get("cinematic_id", ""))
			if cinematics.has(cinematic_id):
				errors.append("%s: cinematic %s also exists in %s." % [scene_path, cinematic_id, str((cinematics[cinematic_id] as Dictionary).get("map_id", ""))])
			else:
				cinematics[cinematic_id] = {"map_id": map_id, "scene_path": scene_path}
	for map_id_value in maps.keys():
		var map_id := str(map_id_value)
		var entry: Dictionary = maps[map_id]
		var definition: Dictionary = entry.get("definition", {})
		var scene_path := str(entry.get("scene_path", ""))
		for conversation_value in definition.get("dialogue_conversations", []):
			if not conversation_value is Dictionary:
				continue
			var conversation: Dictionary = conversation_value
			for node_value in conversation.get("nodes", []):
				if not node_value is Dictionary:
					continue
				var node: Dictionary = node_value
				_validate_world_story_actions(node.get("actions", []), catalog, scene_path, errors)
				for choice_value in node.get("choices", []):
					if choice_value is Dictionary:
						_validate_world_story_actions((choice_value as Dictionary).get("actions", []), catalog, scene_path, errors)


static func _validate_world_story_actions(action_values: Variant, catalog: Dictionary, scene_path: String, errors: PackedStringArray) -> void:
	if not action_values is Array:
		return
	for action_value in action_values:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		if str(action.get("action_type", "")) != "transition_player":
			continue
		var target_map_id := str(action.get("target_map_id", ""))
		var target_spawn_id := str(action.get("target_spawn_id", ""))
		var target_definition := definition_for_map(catalog, target_map_id)
		if target_definition.is_empty():
			errors.append("%s: dialogue action targets missing map %s." % [scene_path, target_map_id])
		elif not object_ids(target_definition, "player_spawns", "spawn_id").has(target_spawn_id):
			errors.append("%s: dialogue action targets missing spawn %s/%s." % [scene_path, target_map_id, target_spawn_id])
