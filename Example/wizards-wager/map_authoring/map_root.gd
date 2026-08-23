@tool
class_name MapRoot
extends Node2D

@export var map_id := "forest"
@export var world_id := "main_world"
@export var display_name := "Map"
@export var area_type := "main_world"
@export var enterable := false
@export var published_version := 0
@export var coordinate_system := "godot_2d"
@export var archetype_ids: PackedStringArray = []
@export var faction_ids: PackedStringArray = []


func collect_definition() -> Dictionary:
	var physics_surfaces: Array = []
	var combatant_spawns: Array = []
	var behavior_profiles: Array = []
	var quests: Array = []
	var quest_givers: Array = []
	var area_transitions: Array = []
	var player_spawns: Array = []
	var quest_areas: Array = []
	var interactable_objects: Array = []
	var dialogue_conversations: Array = []
	var story_flags: Array = []
	var cinematic_sequences: Array = []
	var cinematic_markers: Array = []
	var behavior_profile_ids: Dictionary = {}
	for node in find_children("*", "", true, false):
		if node is MapPhysicsSurface:
			physics_surfaces.append((node as MapPhysicsSurface).get_definition())
		elif node is CombatantSpawnArea:
			if not (node as CombatantSpawnArea).enabled:
				continue
			var spawn_definition := (node as CombatantSpawnArea).get_definition()
			combatant_spawns.append(spawn_definition)
			var profile_value: Variant = spawn_definition.get("behavior_profile", {})
			if profile_value is Dictionary:
				var profile: Dictionary = profile_value
				var profile_id := str(profile.get("profile_id", ""))
				if not profile_id.is_empty() and not behavior_profile_ids.has(profile_id):
					behavior_profile_ids[profile_id] = true
					behavior_profiles.append(profile)
		elif node is QuestCatalog:
			quests.append_array((node as QuestCatalog).get_definitions())
		elif node is DialogueCatalog:
			dialogue_conversations.append_array((node as DialogueCatalog).get_definitions())
		elif node is StoryFlagCatalog:
			story_flags.append_array((node as StoryFlagCatalog).get_definitions())
		elif node is CinematicCatalog:
			cinematic_sequences.append_array((node as CinematicCatalog).get_definitions())
		elif node is AuthoredCharacter:
			if not (node as AuthoredCharacter).enabled:
				continue
			var character_definition := (node as AuthoredCharacter).get_definition()
			quest_givers.append(character_definition)
			var character_profile_value: Variant = character_definition.get("behavior_profile", {})
			if character_profile_value is Dictionary:
				var character_profile: Dictionary = character_profile_value
				var character_profile_id := str(character_profile.get("profile_id", ""))
				if not character_profile_id.is_empty() and not behavior_profile_ids.has(character_profile_id):
					behavior_profile_ids[character_profile_id] = true
					behavior_profiles.append(character_profile)
		elif node is QuestGiver:
			if not (node as QuestGiver).enabled:
				continue
			quest_givers.append((node as QuestGiver).get_definition())
		elif node is AreaTransition:
			area_transitions.append((node as AreaTransition).get_definition())
		elif node is MapPlayerSpawn:
			player_spawns.append((node as MapPlayerSpawn).get_definition())
		elif node is QuestArea:
			quest_areas.append((node as QuestArea).get_definition())
		elif node is WorldInteractable:
			interactable_objects.append((node as WorldInteractable).get_definition())
		elif node is CinematicMarker:
			cinematic_markers.append((node as CinematicMarker).get_definition())
	var definition := {
		"map_id": map_id,
		"world_id": world_id,
		"display_name": display_name,
		"area_type": area_type,
		"enterable": enterable,
		"version": published_version,
		"coordinate_system": coordinate_system,
		"archetypes": Array(archetype_ids),
		"factions": Array(faction_ids),
		"behavior_profiles": behavior_profiles,
		"physics_surfaces": physics_surfaces,
		"combatant_spawns": combatant_spawns,
		"quests": quests,
		"quest_givers": quest_givers,
		"area_transitions": area_transitions,
		"player_spawns": player_spawns
	}
	if not quest_areas.is_empty():
		definition["quest_areas"] = quest_areas
	if not interactable_objects.is_empty():
		definition["interactable_objects"] = interactable_objects
	if not dialogue_conversations.is_empty():
		definition["dialogue_conversations"] = dialogue_conversations
	if not story_flags.is_empty():
		definition["story_flags"] = story_flags
	if not cinematic_sequences.is_empty():
		definition["cinematic_sequences"] = cinematic_sequences
	if not cinematic_markers.is_empty():
		definition["cinematic_markers"] = cinematic_markers
	return definition


func validate_definition() -> PackedStringArray:
	var errors: PackedStringArray = []
	var definition := collect_definition()
	var ids: Dictionary = {}
	if str(definition.get("map_id", "")).is_empty():
		errors.append("Map is missing map_id.")
	if str(definition.get("world_id", "")).is_empty():
		errors.append("Map is missing world_id.")
	if int(definition.get("version", 0)) < 0:
		errors.append("Map published_version cannot be negative.")
	if archetype_ids.is_empty():
		errors.append("Map must declare at least one archetype.")
	if faction_ids.is_empty():
		errors.append("Map must declare at least one faction.")
	var declared_archetypes := {}
	for archetype_id in archetype_ids:
		declared_archetypes[str(archetype_id)] = true
	var declared_factions := {}
	for faction_id in faction_ids:
		declared_factions[str(faction_id)] = true
	var declared_surfaces := {}
	for surface_value in definition["physics_surfaces"]:
		declared_surfaces[str((surface_value as Dictionary).get("surface_id", ""))] = true
	var declared_profiles := {}
	for profile_value in definition["behavior_profiles"]:
		declared_profiles[str((profile_value as Dictionary).get("profile_id", ""))] = true
	var declared_quests := {}
	var declared_givers := {}
	var declared_transitions := {}
	var declared_areas := {}
	var declared_objects := {}
	for quest_value in definition["quests"]:
		var quest: Dictionary = quest_value
		var quest_id := str(quest.get("quest_id", ""))
		if quest_id.is_empty():
			errors.append("Quest is missing quest_id.")
		elif ids.has(quest_id):
			errors.append("Duplicate map object ID: %s" % quest_id)
		else:
			ids[quest_id] = true
		declared_quests[quest_id] = true
		var stages: Array = quest.get("stages", [])
		if stages.is_empty():
			errors.append("Quest %s must have at least one stage." % quest_id)
		var stage_ids: Dictionary = {}
		for stage_value in stages:
			var stage: Dictionary = stage_value
			var stage_id := str(stage.get("stage_id", ""))
			if stage_id.is_empty() or stage_ids.has(stage_id):
				errors.append("Quest %s has an invalid or duplicate stage_id." % quest_id)
			else:
				stage_ids[stage_id] = true
			var objective_type := str(stage.get("objective_type", ""))
			if not ["kill", "talk", "interact", "use_transition", "enter_map", "enter_area"].has(objective_type):
				errors.append("Quest %s stage %s has unsupported objective_type." % [quest_id, stage_id])
			if int(stage.get("required_count", 0)) < 1:
				errors.append("Quest %s stage %s must have required_count >= 1." % [quest_id, stage_id])
			if objective_type == "kill" and not declared_archetypes.has(str(stage.get("target_archetype_id", ""))):
				errors.append("Quest %s stage %s references undeclared archetype %s." % [quest_id, stage_id, str(stage.get("target_archetype_id", ""))])
			if objective_type == "talk" and str(stage.get("target_npc_id", "")).is_empty():
				errors.append("Quest %s stage %s is missing target_npc_id." % [quest_id, stage_id])
			if objective_type == "interact" and str(stage.get("target_npc_id", "")).is_empty() and str(stage.get("target_object_id", "")).is_empty():
				errors.append("Quest %s stage %s is missing target_npc_id or target_object_id." % [quest_id, stage_id])
			if objective_type == "use_transition" and str(stage.get("target_transition_id", "")).is_empty():
				errors.append("Quest %s stage %s is missing target_transition_id." % [quest_id, stage_id])
			if objective_type == "enter_map" and str(stage.get("target_map_id", "")).is_empty():
				errors.append("Quest %s stage %s is missing target_map_id." % [quest_id, stage_id])
			if objective_type == "enter_area" and str(stage.get("target_area_id", "")).is_empty():
				errors.append("Quest %s stage %s is missing target_area_id." % [quest_id, stage_id])
	for giver_value in definition["quest_givers"]:
		var giver: Dictionary = giver_value
		var giver_id := str(giver.get("npc_id", ""))
		if giver_id.is_empty() or ids.has(giver_id):
			errors.append("Quest giver has a missing or duplicate npc_id: %s" % giver_id)
		else:
			ids[giver_id] = true
			declared_givers[giver_id] = true
		if not declared_archetypes.has(str(giver.get("archetype_id", ""))):
			errors.append("Quest giver %s references undeclared archetype %s." % [giver_id, str(giver.get("archetype_id", ""))])
		if not declared_factions.has(str(giver.get("faction_id", ""))):
			errors.append("Quest giver %s references undeclared faction %s." % [giver_id, str(giver.get("faction_id", ""))])
		var giver_surface_id := str(giver.get("surface_id", ""))
		if giver_surface_id.is_empty() or not declared_surfaces.has(giver_surface_id):
			errors.append("Quest giver %s references undeclared surface %s." % [giver_id, giver_surface_id])
		for quest_id_value in giver.get("quest_ids", []):
			if not declared_quests.has(str(quest_id_value)):
				errors.append("Quest giver %s references undeclared quest %s." % [giver_id, str(quest_id_value)])
	for transition_value in definition["area_transitions"]:
		var transition: Dictionary = transition_value
		var transition_id := str(transition.get("transition_id", ""))
		if transition_id.is_empty() or ids.has(transition_id):
			errors.append("Area transition has a missing or duplicate transition_id: %s" % transition_id)
		else:
			ids[transition_id] = true
			declared_transitions[transition_id] = true
		var destination: Dictionary = transition.get("destination", {})
		if str(transition.get("origin_world_id", "")).is_empty() or str(transition.get("origin_map_id", "")).is_empty():
			errors.append("Area transition %s has an incomplete origin." % transition_id)
		elif str(transition.get("origin_world_id", "")) != world_id or str(transition.get("origin_map_id", "")) != map_id:
			errors.append("Area transition %s origin does not match this map." % transition_id)
		if str(destination.get("world_id", "")).is_empty() or str(destination.get("map_id", "")).is_empty() or str(transition.get("destination_spawn_id", "")).is_empty():
			errors.append("Area transition %s has an incomplete destination." % transition_id)
		if float(transition.get("required_proximity", 0.0)) <= 0.0:
			errors.append("Area transition %s must have required_proximity > 0." % transition_id)
	for spawn_value in definition["player_spawns"]:
		var player_spawn: Dictionary = spawn_value
		var player_spawn_id := str(player_spawn.get("spawn_id", ""))
		if player_spawn_id.is_empty() or ids.has(player_spawn_id):
			errors.append("Player spawn has a missing or duplicate spawn_id: %s" % player_spawn_id)
		else:
			ids[player_spawn_id] = true
		var player_spawn_surface_id := str(player_spawn.get("surface_id", ""))
		if player_spawn_surface_id.is_empty() or not declared_surfaces.has(player_spawn_surface_id):
			errors.append("Player spawn %s references undeclared surface %s." % [player_spawn_id, player_spawn_surface_id])
	for area_value in definition.get("quest_areas", []):
		var area: Dictionary = area_value
		var area_id := str(area.get("area_id", ""))
		if area_id.is_empty() or ids.has(area_id):
			errors.append("Quest area has a missing or duplicate area_id: %s" % area_id)
		else:
			ids[area_id] = true
			declared_areas[area_id] = true
		var area_size: Dictionary = area.get("size", {})
		if float(area_size.get("x", 0.0)) <= 0.0 or float(area_size.get("y", 0.0)) <= 0.0:
			errors.append("Quest area %s has invalid size." % area_id)
	for object_value in definition.get("interactable_objects", []):
		var authored_object: Dictionary = object_value
		var object_id := str(authored_object.get("object_id", ""))
		if object_id.is_empty() or ids.has(object_id):
			errors.append("Interactable has a missing or duplicate object_id: %s" % object_id)
		else:
			ids[object_id] = true
			declared_objects[object_id] = true
	for surface_value in definition["physics_surfaces"]:
		var surface: Dictionary = surface_value
		var surface_id := str(surface.get("surface_id", ""))
		if surface_id.is_empty():
			errors.append("Physics surface is missing surface_id.")
		elif ids.has(surface_id):
			errors.append("Duplicate map object ID: %s" % surface_id)
		else:
			ids[surface_id] = true
		if float(surface["size"]["x"]) <= 0.0 or float(surface["size"]["y"]) <= 0.0:
			errors.append("Physics surface %s has invalid size." % surface_id)
	for spawn_value in definition["combatant_spawns"]:
		var spawn: Dictionary = spawn_value
		var spawn_id := str(spawn.get("spawn_id", ""))
		if spawn_id.is_empty():
			errors.append("Combatant spawn is missing spawn_id.")
		elif ids.has(spawn_id):
			errors.append("Duplicate map object ID: %s" % spawn_id)
		else:
			ids[spawn_id] = true
		if int(spawn.get("spawn_count", 0)) < 1:
			errors.append("Combatant spawn %s must have spawn_count >= 1." % spawn_id)
		if int(spawn.get("minimum_level", 1)) > int(spawn.get("maximum_level", 1)):
			errors.append("Character spawn %s minimum_level exceeds maximum_level." % spawn_id)
		if str(spawn.get("archetype_id", "")).is_empty():
			errors.append("Combatant spawn %s is missing archetype_id." % spawn_id)
		elif not declared_archetypes.has(str(spawn.get("archetype_id", ""))):
			errors.append("Combatant spawn %s references undeclared archetype %s." % [spawn_id, str(spawn.get("archetype_id", ""))])
		if str(spawn.get("faction_id", "")).is_empty():
			errors.append("Combatant spawn %s is missing faction_id." % spawn_id)
		elif not declared_factions.has(str(spawn.get("faction_id", ""))):
			errors.append("Combatant spawn %s references undeclared faction %s." % [spawn_id, str(spawn.get("faction_id", ""))])
		if str(spawn.get("behavior_profile_id", "")).is_empty():
			errors.append("Combatant spawn %s is missing behavior_profile_id." % spawn_id)
		elif not declared_profiles.has(str(spawn.get("behavior_profile_id", ""))):
			errors.append("Combatant spawn %s references undeclared behavior profile %s." % [spawn_id, str(spawn.get("behavior_profile_id", ""))])
		var referenced_surface := str(spawn.get("surface_id", ""))
		if referenced_surface.is_empty():
			errors.append("Combatant spawn %s is missing surface_id." % spawn_id)
		elif not declared_surfaces.has(referenced_surface):
			errors.append("Combatant spawn %s references undeclared surface %s." % [spawn_id, referenced_surface])
		if str(spawn.get("placement_mode", "")) == "random_in_bounds":
			var spawn_bounds: Dictionary = spawn.get("bounds", {})
			if float(spawn_bounds.get("x", 0.0)) <= 0.0 or float(spawn_bounds.get("y", 0.0)) <= 0.0:
				errors.append("Combatant spawn %s has invalid random bounds." % spawn_id)
	for quest_value in definition["quests"]:
		var quest := quest_value as Dictionary
		var quest_id := str(quest.get("quest_id", ""))
		var required_faction_id := str(quest.get("required_committed_faction_id", ""))
		if not required_faction_id.is_empty() and not declared_factions.has(required_faction_id):
			errors.append("Quest %s references undeclared required faction %s." % [quest_id, required_faction_id])
		for stage_value in quest.get("stages", []):
			var stage := stage_value as Dictionary
			var stage_id := str(stage.get("stage_id", ""))
			var objective_type := str(stage.get("objective_type", ""))
			var target_map_id := str(stage.get("target_map_id", ""))
			var is_local_target := target_map_id.is_empty() or target_map_id == map_id
			if objective_type in ["talk", "interact"] and is_local_target and not str(stage.get("target_npc_id", "")).is_empty() and not declared_givers.has(str(stage.get("target_npc_id", ""))):
				errors.append("Quest %s stage %s references undeclared NPC %s." % [quest_id, stage_id, str(stage.get("target_npc_id", ""))])
			if objective_type == "use_transition" and not declared_transitions.has(str(stage.get("target_transition_id", ""))):
				errors.append("Quest %s stage %s references undeclared transition %s." % [quest_id, stage_id, str(stage.get("target_transition_id", ""))])
			if objective_type == "enter_area" and is_local_target and not declared_areas.has(str(stage.get("target_area_id", ""))):
				errors.append("Quest %s stage %s references undeclared quest area %s." % [quest_id, stage_id, str(stage.get("target_area_id", ""))])
			var required_kill_area_id := str(stage.get("required_kill_area_id", ""))
			if objective_type == "kill" and not required_kill_area_id.is_empty() and is_local_target and not declared_areas.has(required_kill_area_id):
				errors.append("Quest %s stage %s references undeclared kill area %s." % [quest_id, stage_id, required_kill_area_id])
			if objective_type == "interact":
				var target_object_id := str(stage.get("target_object_id", ""))
				if not target_object_id.is_empty() and is_local_target and not declared_objects.has(target_object_id):
					errors.append("Quest %s stage %s references undeclared interactable %s." % [quest_id, stage_id, target_object_id])
	_validate_storytelling(definition, errors, declared_quests, declared_givers, declared_factions, declared_transitions)
	return errors


func _validate_storytelling(definition: Dictionary, errors: PackedStringArray, declared_quests: Dictionary, declared_givers: Dictionary, declared_factions: Dictionary, declared_transitions: Dictionary) -> void:
	var flags: Dictionary = {}
	for flag_value in definition.get("story_flags", []):
		if not flag_value is Dictionary:
			continue
		var flag: Dictionary = flag_value
		var flag_id := str(flag.get("flag_id", ""))
		if flag_id.is_empty() or flags.has(flag_id):
			errors.append("Story flag has a missing or duplicate flag_id: %s" % flag_id)
		else:
			flags[flag_id] = str(flag.get("value_type", "boolean"))
	var markers: Dictionary = {}
	for marker_value in definition.get("cinematic_markers", []):
		if not marker_value is Dictionary:
			continue
		var marker_id := str((marker_value as Dictionary).get("marker_id", ""))
		if marker_id.is_empty() or markers.has(marker_id):
			errors.append("Cinematic marker has a missing or duplicate marker_id: %s" % marker_id)
		else:
			markers[marker_id] = true
	var cinematics: Dictionary = {}
	for cinematic_value in definition.get("cinematic_sequences", []):
		if not cinematic_value is Dictionary:
			continue
		var cinematic: Dictionary = cinematic_value
		var cinematic_id := str(cinematic.get("cinematic_id", ""))
		if cinematic_id.is_empty() or cinematics.has(cinematic_id):
			errors.append("Cinematic has a missing or duplicate cinematic_id: %s" % cinematic_id)
		else:
			cinematics[cinematic_id] = true
		if not bool(cinematic.get("restore_camera_on_end", false)):
			errors.append("Cinematic %s must restore the camera." % cinematic_id)
		if not bool(cinematic.get("restore_input_on_end", false)):
			errors.append("Cinematic %s must restore player input." % cinematic_id)
		var cue_ids: Dictionary = {}
		for cue_value in cinematic.get("cues", []):
			if not cue_value is Dictionary:
				continue
			var cue: Dictionary = cue_value
			var cue_id := str(cue.get("cue_id", ""))
			if cue_id.is_empty() or cue_ids.has(cue_id):
				errors.append("Cinematic %s has a missing or duplicate cue_id." % cinematic_id)
			else:
				cue_ids[cue_id] = true
			var cue_type := str(cue.get("cue_type", ""))
			var marker_id := str(cue.get("marker_id", ""))
			var npc_id := str(cue.get("npc_id", ""))
			if not [
				"lock_input", "unlock_input", "save_camera", "restore_camera", "pan_to_marker",
				"follow_npc", "follow_player", "zoom_camera", "hold", "fade_in", "fade_out",
				"show_text", "title_card", "face_npc", "play_npc_animation",
				"move_npc_to_marker", "play_sound", "complete"
			].has(cue_type):
				errors.append("Cinematic %s cue %s uses unsupported type %s." % [cinematic_id, cue_id, cue_type])
			if cue_type in ["pan_to_marker", "move_npc_to_marker"] and (marker_id.is_empty() or not markers.has(marker_id)):
				errors.append("Cinematic %s cue %s references missing marker %s." % [cinematic_id, cue_id, marker_id])
			if cue_type in ["follow_npc", "face_npc", "play_npc_animation", "move_npc_to_marker"] and (npc_id.is_empty() or not declared_givers.has(npc_id)):
				errors.append("Cinematic %s cue %s references missing NPC %s." % [cinematic_id, cue_id, npc_id])
		cinematics[cinematic_id] = cue_ids
	var conversations: Dictionary = {}
	for conversation_value in definition.get("dialogue_conversations", []):
		if not conversation_value is Dictionary:
			continue
		var conversation: Dictionary = conversation_value
		var conversation_id := str(conversation.get("conversation_id", ""))
		if conversation_id.is_empty() or conversations.has(conversation_id):
			errors.append("Conversation has a missing or duplicate conversation_id: %s" % conversation_id)
			continue
		conversations[conversation_id] = true
		var nodes: Dictionary = {}
		var node_values: Array = conversation.get("nodes", [])
		for node_value in node_values:
			if not node_value is Dictionary:
				continue
			var dialogue_node: Dictionary = node_value
			var node_id := str(dialogue_node.get("node_id", ""))
			if node_id.is_empty() or nodes.has(node_id):
				errors.append("Conversation %s has a missing or duplicate node_id: %s" % [conversation_id, node_id])
			else:
				nodes[node_id] = dialogue_node
		var starting_node_id := str(conversation.get("starting_node_id", ""))
		if starting_node_id.is_empty() or not nodes.has(starting_node_id):
			errors.append("Conversation %s has an invalid starting node %s." % [conversation_id, starting_node_id])
		var default_cinematic_id := str(conversation.get("default_cinematic_id", ""))
		if not default_cinematic_id.is_empty() and not cinematics.has(default_cinematic_id):
			errors.append("Conversation %s references missing default cinematic %s." % [conversation_id, default_cinematic_id])
		for node_id_value in nodes.keys():
			var node_id := str(node_id_value)
			var dialogue_node: Dictionary = nodes[node_id]
			var speaker_id := str(dialogue_node.get("speaker_npc_id", ""))
			if not speaker_id.is_empty() and not declared_givers.has(speaker_id):
				errors.append("Conversation %s node %s references missing speaker %s." % [conversation_id, node_id, speaker_id])
			var automatic_next := str(dialogue_node.get("automatic_next_node_id", ""))
			if not automatic_next.is_empty() and not nodes.has(automatic_next):
				errors.append("Conversation %s node %s points to missing node %s." % [conversation_id, node_id, automatic_next])
			var cinematic_id := str(dialogue_node.get("cinematic_id", ""))
			if not cinematic_id.is_empty() and not cinematics.has(cinematic_id):
				errors.append("Conversation %s node %s references missing cinematic %s." % [conversation_id, node_id, cinematic_id])
			var cinematic_cue_id := str(dialogue_node.get("cinematic_cue_id", ""))
			if not cinematic_cue_id.is_empty() and (cinematic_id.is_empty() or not cinematics.has(cinematic_id) or not (cinematics[cinematic_id] as Dictionary).has(cinematic_cue_id)):
				errors.append("Conversation %s node %s references missing cinematic cue %s/%s." % [conversation_id, node_id, cinematic_id, cinematic_cue_id])
			if str(dialogue_node.get("condition_logic", "all")) not in ["all", "any"]:
				errors.append("Conversation %s node %s has invalid condition logic." % [conversation_id, node_id])
			_validate_story_conditions(dialogue_node.get("conditions", []), conversation_id, node_id, flags, declared_quests, declared_factions, errors)
			_validate_story_actions(dialogue_node.get("actions", []), conversation_id, node_id, flags, declared_quests, declared_factions, declared_transitions, cinematics, errors)
			var choice_ids: Dictionary = {}
			for choice_value in dialogue_node.get("choices", []):
				if not choice_value is Dictionary:
					continue
				var choice: Dictionary = choice_value
				var choice_id := str(choice.get("choice_id", ""))
				if choice_id.is_empty() or choice_ids.has(choice_id):
					errors.append("Conversation %s node %s has a missing or duplicate choice_id." % [conversation_id, node_id])
				else:
					choice_ids[choice_id] = true
				var destination := str(choice.get("destination_node_id", ""))
				if not destination.is_empty() and not nodes.has(destination):
					errors.append("Conversation %s choice %s points to missing node %s." % [conversation_id, choice_id, destination])
				if str(choice.get("condition_logic", "all")) not in ["all", "any"]:
					errors.append("Conversation %s choice %s has invalid condition logic." % [conversation_id, choice_id])
				_validate_story_conditions(choice.get("conditions", []), conversation_id, choice_id, flags, declared_quests, declared_factions, errors)
				_validate_story_actions(choice.get("actions", []), conversation_id, choice_id, flags, declared_quests, declared_factions, declared_transitions, cinematics, errors)
				if _actions_require_confirmation(choice.get("actions", [])) and not bool(choice.get("requires_confirmation", false)):
					errors.append("Permanent choice %s/%s must require confirmation." % [conversation_id, choice_id])
		_validate_conversation_reachability(conversation_id, starting_node_id, nodes, errors)
	for giver_value in definition.get("quest_givers", []):
		if not giver_value is Dictionary:
			continue
		var giver: Dictionary = giver_value
		var npc_id := str(giver.get("npc_id", ""))
		var default_conversation_id := str(giver.get("default_conversation_id", ""))
		if not default_conversation_id.is_empty() and not conversations.has(default_conversation_id):
			errors.append("NPC %s references missing conversation %s." % [npc_id, default_conversation_id])
		var entry_ids: Dictionary = {}
		for entry_value in giver.get("conditional_conversations", []):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			var entry_id := str(entry.get("entry_id", ""))
			if entry_id.is_empty() or entry_ids.has(entry_id):
				errors.append("NPC %s has a missing or duplicate conversation entry ID." % npc_id)
			else:
				entry_ids[entry_id] = true
			var conversation_id := str(entry.get("conversation_id", ""))
			if not conversations.has(conversation_id):
				errors.append("NPC %s entry %s references missing conversation %s." % [npc_id, entry_id, conversation_id])
			if str(entry.get("condition_logic", "all")) not in ["all", "any"]:
				errors.append("NPC %s entry %s has invalid condition logic." % [npc_id, entry_id])
			_validate_story_conditions(entry.get("conditions", []), npc_id, entry_id, flags, declared_quests, declared_factions, errors)


func _validate_story_conditions(condition_values: Variant, owner_id: String, location_id: String, flags: Dictionary, declared_quests: Dictionary, declared_factions: Dictionary, errors: PackedStringArray) -> void:
	if not condition_values is Array:
		return
	for condition_value in condition_values:
		if not condition_value is Dictionary:
			continue
		var condition: Dictionary = condition_value
		var condition_type := str(condition.get("condition_type", ""))
		var target_id := str(condition.get("target_id", ""))
		if not [
			"quest_not_started", "quest_active", "quest_stage", "quest_complete", "quest_failed",
			"faction_is", "faction_is_not", "reputation_at_least", "reputation_at_most",
			"level_at_least", "flag_is_set", "flag_is_not_set", "flag_value",
			"has_item", "lacks_item", "choice_selected"
		].has(condition_type):
			errors.append("%s/%s uses unsupported condition %s." % [owner_id, location_id, condition_type])
		if condition_type.begins_with("quest_") and not declared_quests.has(target_id):
			errors.append("%s/%s condition references missing quest %s." % [owner_id, location_id, target_id])
		if condition_type in ["faction_is", "faction_is_not", "reputation_at_least", "reputation_at_most"] and not declared_factions.has(target_id):
			errors.append("%s/%s condition references missing faction %s." % [owner_id, location_id, target_id])
		if condition_type.begins_with("flag_") and not flags.has(target_id):
			errors.append("%s/%s condition references undeclared story flag %s." % [owner_id, location_id, target_id])


func _validate_story_actions(action_values: Variant, owner_id: String, location_id: String, flags: Dictionary, declared_quests: Dictionary, declared_factions: Dictionary, declared_transitions: Dictionary, cinematics: Dictionary, errors: PackedStringArray) -> void:
	if not action_values is Array:
		return
	for action_value in action_values:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		var action_type := str(action.get("action_type", ""))
		var target_id := str(action.get("target_id", ""))
		if not [
			"set_flag", "clear_flag", "increment_flag", "offer_quest", "advance_quest",
			"complete_objective", "give_item", "remove_item", "give_gold",
			"give_experience", "change_reputation", "commit_faction", "start_cinematic",
			"transition_player", "end_conversation"
		].has(action_type):
			errors.append("%s/%s uses unsupported story action %s." % [owner_id, location_id, action_type])
		if action_type in ["set_flag", "clear_flag", "increment_flag"] and not flags.has(target_id):
			errors.append("%s/%s action references undeclared story flag %s." % [owner_id, location_id, target_id])
		if action_type == "increment_flag" and flags.has(target_id) and str(flags[target_id]) != "integer":
			errors.append("%s/%s increments non-integer story flag %s." % [owner_id, location_id, target_id])
		if action_type == "set_flag" and flags.has(target_id):
			var flag_type := str(flags[target_id])
			var text_value := str(action.get("text_value", ""))
			if flag_type == "string" and text_value.is_empty():
				errors.append("%s/%s must supply text_value when setting string flag %s." % [owner_id, location_id, target_id])
			elif flag_type != "string" and not text_value.is_empty():
				errors.append("%s/%s supplies text_value for non-string flag %s." % [owner_id, location_id, target_id])
		if action_type in ["offer_quest", "advance_quest", "complete_objective"] and not declared_quests.has(target_id):
			errors.append("%s/%s action references missing quest %s." % [owner_id, location_id, target_id])
		if action_type in ["change_reputation", "commit_faction"] and not declared_factions.has(target_id):
			errors.append("%s/%s action references missing faction %s." % [owner_id, location_id, target_id])
		if action_type == "start_cinematic" and not cinematics.has(target_id):
			errors.append("%s/%s action references missing cinematic %s." % [owner_id, location_id, target_id])
		if action_type == "transition_player" and str(action.get("target_map_id", "")).is_empty():
			errors.append("%s/%s transition action is missing target_map_id." % [owner_id, location_id])


func _actions_require_confirmation(action_values: Variant) -> bool:
	if not action_values is Array:
		return false
	for action_value in action_values:
		if action_value is Dictionary:
			var action: Dictionary = action_value
			if bool(action.get("requires_confirmation", false)) or str(action.get("action_type", "")) in ["remove_item", "change_reputation", "commit_faction", "transition_player"]:
				return true
	return false


func _validate_conversation_reachability(conversation_id: String, starting_node_id: String, nodes: Dictionary, errors: PackedStringArray) -> void:
	if not nodes.has(starting_node_id):
		return
	var reachable: Dictionary = {}
	var pending: Array[String] = [starting_node_id]
	var has_ending := false
	var has_intentional_loop := false
	while not pending.is_empty():
		var node_id: String = pending.pop_back()
		if reachable.has(node_id) or not nodes.has(node_id):
			continue
		reachable[node_id] = true
		var dialogue_node: Dictionary = nodes[node_id]
		has_ending = has_ending or bool(dialogue_node.get("ends_conversation", false))
		has_intentional_loop = has_intentional_loop or bool(dialogue_node.get("intentional_loop", false))
		var automatic_next := str(dialogue_node.get("automatic_next_node_id", ""))
		if not automatic_next.is_empty():
			pending.append(automatic_next)
		for choice_value in dialogue_node.get("choices", []):
			if choice_value is Dictionary:
				var destination := str((choice_value as Dictionary).get("destination_node_id", ""))
				if not destination.is_empty():
					pending.append(destination)
	for node_id_value in nodes.keys():
		if not reachable.has(str(node_id_value)):
			errors.append("Conversation %s contains unreachable node %s." % [conversation_id, str(node_id_value)])
	if not has_ending and not has_intentional_loop:
		errors.append("Conversation %s has no reachable ending or intentional loop." % conversation_id)


func definition_json() -> String:
	return JSON.stringify(collect_definition(), "  ")
