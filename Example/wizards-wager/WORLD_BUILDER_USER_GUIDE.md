# Wizards Wager World Builder

The **World Builder** dock inside Godot is now the main place for manually creating the game world.

Godot map scenes and quest resources are always the editable source of truth. Do not hand-edit generated `.definition.json` files.

## Creating a Map

1. Open the **World Builder** dock.
2. Select **Create New Map**.
3. Enter a lowercase `snake_case` map ID, display name, world ID, and area type.
4. Select **Create**.

The tool creates a complete map with:

- A starting ground surface
- A player spawn
- Containers for visuals, surfaces, characters, character regions, transitions, quest areas, interactables, and quests
- Quest and behavior folders

Build art, tiles, and normal Godot collision in the scene as usual.

## Placing Characters

Every living character is authored through one of two tools:

- **Character** creates one fixed character, such as a guard, civilian, commander, boss, or quest character.
- **Character Region** creates one or more server-controlled characters inside a resizable spawn region.

Enemies are NPC characters too. Their faction and behavior determine whether they are hostile.

Select a character or region and edit its properties in the normal Godot Inspector:

- Stable ID
- Display name
- Archetype
- Faction
- Sprite-sheet visual ID
- Surface
- Behavior
- Spawn count and region
- Respawn time
- Aggro and leash distance
- Stats
- Hostile factions and archetypes
- Quest assignments

### Adding Character Art

Place a character animation sheet in:

`res://assets/NPCSHEETS/`

The PNG filename becomes its visual ID:

- `JusticeKnight.png` becomes `justice_knight`
- `SewerZombie.png` becomes `sewer_zombie`

The sheet currently uses the shared 36-by-36 character animation layout used by `npc.gd`.

Refresh the World Builder catalog, select the archetype, faction, surface, and sheet, select a Character or Character Region node, and choose **Apply Setup to Selected Character/Region**.

## Connecting Maps

1. Add player spawns to the destination map.
2. Save both maps and refresh the World Builder catalog.
3. Add a **Transition** to the origin map.
4. Drag the transition to the desired location and resize its `interaction_size`.
5. Select the transition node.
6. Choose its destination map and destination spawn.
7. Select **Apply Link**.

For a two-way connection:

1. Choose a return spawn on the current map.
2. Select **Create Paired Return Transition**.
3. Review and save both map scenes.

The origin IDs are filled from the current map automatically.

## Creating Enemy Areas

1. Select **Character Region**.
2. Drag the region into position.
3. Resize its `bounds`.
4. Select an archetype, faction, sprite sheet, surface, behavior, and spawn count.
5. Set hostile factions or archetypes.

Set `enabled` off to keep the region in the editable scene without publishing it.

## Creating Quests

1. Open the map containing the quest.
2. Use **Quest Builder → New**.
3. Fill in the quest text, giver, faction requirement, prerequisites, and rewards.
4. Select **Save Quest Details**.
5. Add stages in their intended order.
6. Select a stage type, target map, target object, and count.
7. Select **Update** after editing a stage.
8. Use **Up** and **Down** to reorder progression.

Supported objectives are:

- Kill a character archetype
- Talk to a character
- Interact with a character or world object
- Use a transition
- Enter a map
- Enter a quest area

For a location-specific kill quest, select a quest area under **Kill must occur in**.

Quest assignments are synchronized with the selected giver character when quest details are saved.

## Creating Quest Areas

1. Select **Quest Area**.
2. Drag the area into position.
3. Resize its `size`.
4. Give it a stable area ID and display name.
5. Select that area as an `enter_area` stage target or a kill restriction in the Quest Builder.

Quest areas appear as yellow boxes in the editor and preview.

## Creating Dialogue and Story

Open a map and use **Dialogue and Storytelling** in the World Builder dock.

### Conversations

1. Select **New** beside the conversation list.
2. Select a dialogue node and edit its speaker, text, conditions, actions, and end behavior in the Inspector.
3. Add choices to the selected node.
4. Set each choice's text and destination, or drag a graph connection from the choice to another node.
5. Use **Node Condition**, **Node Action**, **Choice Condition**, and **Choice Action** to add safe story logic.
6. Select an authored NPC in the scene tree and choose **Assign to Selected NPC**.
7. Use **Conditional Entry** to make that NPC choose a different conversation based on quests, faction, reputation, level, items, or story flags.

Conditions can require either **all** entries or **any** entry. Individual conditions can also be negated. Permanent choices can require a confirmation prompt.

### Story Flags

Use the Story Flags section to create persistent facts about a player. Flags may be boolean, integer, or text values. Dialogue conditions read them and safe actions change them. Keep IDs stable after publishing.

### Cinematics

1. Place a **Cinematic Marker** on the map and drag it to the desired camera or character position.
2. Create a cinematic in the Storytelling section.
3. Add and order cues such as camera save, input lock, pan to marker, title card, hold, fade, camera restore, and input unlock.
4. Add a `start_cinematic` action to a dialogue node or choice.
5. Choose **Preview Conversation** to test the dialogue and camera sequence with simulated player state.

The preview can start from any dialogue node and simulate level, faction, reputation, quests, items, and story flags. Preview actions never grant real rewards or change persistent player data.

Camera and input are restored when a sequence completes, is skipped, is interrupted, or the map changes.

## Validation

Use **Current Map** while working on one scene.

Use **Entire World** before publishing. World validation checks:

- Map and object IDs
- Missing surfaces and behaviors
- Transition destinations
- Destination spawns
- Cross-map quest targets
- Quest prerequisites and cycles
- Quest giver assignments
- Quest areas
- Enterable maps without spawns
- Dialogue graph destinations, speakers, and endings
- Story flag, quest, faction, and cinematic references
- Unsupported story conditions or actions
- Cinematic markers, targets, camera restoration, and input restoration

Double-click a reported problem to open its map and select the affected scene object or quest when it can be identified.

## Preview

Select **Preview Current Map** to open the authoring preview.

The preview displays:

- Player spawns
- Transition destinations
- Character regions
- Character interaction ranges
- Quest areas

Use the arrow keys or A/D/W/S to move and the mouse wheel to zoom. Press Escape to close it.

## Publishing

1. Save the scene.
2. Validate the current map.
3. Validate the entire world.
4. Log in through the World Builder dock.
5. Select **Backend Validate**.
6. Select **Publish Map**.
7. Review the change summary and confirm.

After a successful publish, the tool:

- Stores the returned published version in the map scene
- Saves the scene
- Exports the matching JSON definition

Maps using quest areas, world interactables, or the expanded authored-character fields require the World Builder backend schema update before they can pass backend validation.
