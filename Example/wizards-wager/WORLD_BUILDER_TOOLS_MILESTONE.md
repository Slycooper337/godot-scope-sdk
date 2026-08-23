# Wizards Wager — World Builder Tools Milestone

## Goal

Before expanding the game, make the Godot editor a practical world-building tool that allows the designer to create, connect, populate, configure, validate, test, and publish maps without editing JSON or manually coordinating IDs.

Godot `.tscn` map scenes and `.tres` quest/behavior resources remain the editable source of truth. Exported `.definition.json` files remain generated handoff artifacts for the backend.

## Desired Designer Workflow

The finished workflow should be:

1. Create a map from a standard template.
2. Build its visuals and collision normally in the Godot 2D editor.
3. Place player spawn points visually.
4. Place a transition visually and choose its destination map and spawn from lists.
5. Place NPCs and enemy spawn regions visually.
6. Create quests with a guided editor and select their targets from authored objects.
7. Draw named quest areas directly on the map.
8. run a local validation that checks the entire connected world.
9. preview the map and its links.
10. publish the map from Godot with a clear summary of what changed.

The designer should not need to hand-edit a `.definition.json` file.

## Deliverable 1: Map Creation and Organization

Expand the Map Authoring dock with a **Create New Map** workflow.

The workflow asks for:

- Map ID
- Display name
- World ID
- Area type
- Whether players may enter it
- Starting dimensions or template

It creates:

- `res://maps/<map_id>/<map_id>_map.tscn`
- `res://maps/<map_id>/<map_id>_map.gd`
- `res://maps/<map_id>/quests/`
- `res://maps/<map_id>/behaviors/`
- A standard `MapRoot` hierarchy:
  - `Visuals`
  - `PhysicsSurfaces`
  - `PlayerSpawns`
  - `Transitions`
  - `NPCSpawns`
  - `EnemySpawns`
  - `QuestAreas`
  - `Quests`

The tool should automatically discover every `MapRoot` scene under `res://maps/` and build a local map catalog. There should not be a second hand-maintained map list.

## Deliverable 2: Visual Map Transitions

Transitions remain draggable `Area2D` objects in the map scene.

The transition editor should allow the designer to:

- Add a transition at the current 2D editor cursor.
- Move it visually.
- Resize its interaction area with handles.
- Choose a destination map from a dropdown populated from the local map catalog.
- Choose a destination spawn from a dropdown populated from that map.
- Choose whether the transition is one-way or paired.
- Set required player conditions.
- Open the destination map directly.
- Jump to the selected destination spawn in the editor.

For paired transitions, the tool should be able to create the return transition in the destination map and wire both ends automatically.

The origin world and map IDs should be derived from the current `MapRoot`; the designer should not type them.

Validation must catch:

- Missing destination maps
- Missing destination spawns
- Duplicate transition IDs
- A transition whose origin does not match its map
- A paired transition whose return link is missing or incorrect

## Deliverable 3: NPC and Enemy Placement

Add a small placement palette in the Map Authoring dock.

### General NPCs

Create a general `AuthoredNpc` node instead of requiring every NPC to be a quest giver.

The designer can set:

- NPC ID and display name
- Visual/archetype
- Faction
- Surface
- Combat stats or stat profile
- Interaction type
- Dialogue
- Whether the NPC is invulnerable
- Optional quests offered or completed here

`QuestGiver` may either become a specialized `AuthoredNpc` or its quest fields may be moved into the general NPC definition.

### Enemy and Knight Spawn Areas

Keep `CombatantSpawnArea` as a visible, draggable, resizable region.

The designer can set:

- Spawn ID
- Enemy/NPC archetype
- Faction
- Number alive at once
- Placement mode
- Respawn delay
- Aggro and leash distance
- Surface
- Behavior profile
- Stat overrides
- Hostile factions and archetypes
- Optional level or difficulty range

Add duplicate, enable/disable, and preview buttons. The editor overlay should clearly show the archetype, count, faction, and region bounds.

Where possible, archetypes, factions, surfaces, and behavior profiles should be selected from discovered lists rather than typed.

## Deliverable 4: Quest Builder

Add a dedicated quest editor inside the Map Authoring dock. The underlying format remains `QuestDefinition` and `QuestStage` resources.

The quest builder should support:

- Create, duplicate, rename, and delete quest resources.
- Set offer, description, completion text, repeatability, faction requirements, prerequisites, and rewards.
- Add, remove, duplicate, and reorder stages.
- Select stage targets from the authored world instead of typing IDs.
- Assign quests to NPCs from the quest editor or NPC inspector.
- Show a readable progression summary before saving.

Initially supported stage types:

- Kill an archetype
- Talk to an NPC
- Interact with an NPC or authored object
- Use a transition
- Enter a map
- Enter a quest area

Target selectors should be filtered by stage type. For example, a talk stage lists NPCs, while a transition stage lists transitions.

Cross-map stages are allowed. The quest resource should record the target map where needed so validation and editor navigation can find the target.

## Deliverable 5: Visual Quest Areas

Add a `QuestArea` node based on `Area2D`.

The designer can:

- Draw and resize the region visually.
- Give it a stable area ID and display name.
- Mark it visible only in the editor or optionally visible during gameplay.
- Use it as an `enter_area` quest-stage target.
- Optionally use it as a kill zone so kills count only while the player or enemy is inside the region.
- Optionally attach interaction text or an authored world-object ID.

The published map definition gains a `quest_areas` collection. Quest stages gain:

- `objective_type: "enter_area"` for entering a region
- `target_area_id`
- `target_map_id`
- Optional `required_kill_area_id` for location-restricted kill stages

This is a backend schema addition and must be agreed before the frontend publishes maps containing these fields.

## Deliverable 6: World-Wide Validation

Replace current-map-only checking with two levels:

### Validate Current Map

Checks IDs, required fields, surfaces, spawn bounds, local NPC targets, quest assignments, and local transitions.

### Validate Entire World

Loads all discovered map definitions and checks:

- Every transition destination exists.
- Every destination spawn exists.
- Every cross-map quest target exists.
- Every prerequisite quest exists.
- Quest prerequisites contain no cycles.
- Quest stage IDs are unique within their quest.
- NPC quest assignments agree with quest giver IDs.
- Referenced archetypes, factions, surfaces, behaviors, maps, NPCs, transitions, and quest areas exist.
- IDs that must be globally unique do not collide.
- Every enterable map has at least one player spawn.

Validation results should be clickable. Clicking an error opens the responsible map or resource and selects the affected object.

Warnings should be separate from publishing errors. Examples of warnings include an unusually large spawn count, an unreachable-looking quest, or a one-way transition with no return route.

## Deliverable 7: Preview and Publishing

Add a **Play Current Map** action that launches the player at a selected authored spawn in a development preview mode.

The preview should show optional editor/debug overlays for:

- Transition bounds and destinations
- Player spawns
- NPC interaction ranges
- Enemy spawn regions
- Aggro and leash ranges
- Quest areas
- Surface IDs

Publishing should:

1. Save the current scene and quest resources.
2. Validate the current map.
3. Validate the entire local world.
4. Validate with the backend.
5. Show a summary of additions, removals, and changes.
6. Ask for final confirmation.
7. Publish using the current backend version.
8. Save the returned version into the map scene.
9. Export the matching `.definition.json`.

The publish screen should make it difficult to accidentally remove live spawns, NPCs, transitions, or quests by clearly listing removals.

## Implementation Order

### Step 1 — World Catalog and Map Wizard

Build map discovery, standard containers, new-map creation, shared selectors, and scene navigation. This provides the data needed by every later editor.

### Step 2 — Placement Tools

Finish visual transitions, destination selection, player spawns, general NPCs, combatant spawn regions, and editor overlays.

### Step 3 — Quest and Area Tools

Build the quest editor, stage reordering, target pickers, `QuestArea`, cross-map target lookup, and readable quest summaries.

### Step 4 — Validation, Preview, and Safe Publish

Add world-wide validation, clickable errors, development preview overlays, change summaries, and the final publishing workflow.

These are intentionally large implementation steps. Each one should leave the tool usable rather than introducing a collection of incomplete buttons.

## Backend Work Required

Most of this milestone is frontend/editor tooling and can continue using the current map publishing API.

The backend needs a focused extension for:

- General authored NPC definitions if the backend currently assumes every authored NPC is a quest giver.
- The `quest_areas` map collection.
- The `enter_area` quest objective.
- Optional location-restricted kill credit using `required_kill_area_id`.
- Validation for those new fields.
- Authoritative area-entry and area-exit detection based on player position.
- Quest progress events when an authoritative player enters the required area.

The frontend should not publish the new area fields until the backend supports and validates them.

## Acceptance Criteria

This milestone is complete when the designer can perform the following without editing JSON:

1. Create two new maps from Godot.
2. Place spawn points on both maps.
3. Draw a transition in the first map and select the second map and spawn as its destination.
4. Automatically create or manually configure the return transition.
5. Place a non-quest NPC, a quest NPC, and multiple enemy regions.
6. Create a multi-stage quest that talks to an NPC, kills enemies, enters a marked area, and uses a transition.
7. Reorder and edit its stages.
8. Validate the entire connected world and navigate directly to any reported problem.
9. Preview the map with authoring overlays.
10. Publish successfully and receive an updated version without losing the editable Godot scene.

## Out of Scope

This milestone does not add:

- New player combat or faction progression
- Procedural map generation
- A separate external world editor
- Live collaborative editing
- Runtime editing by normal players
- Dialogue trees beyond basic authored interaction text
- Item, shop, crafting, or loot-table editors

Those systems can use the same catalog, selector, validation, and publishing foundation later.
