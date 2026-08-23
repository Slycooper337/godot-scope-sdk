# Wizards Wager — Dialogue and Storytelling Builder Milestone

## Goal

Allow the designer to create conversations, choices, conditional story branches, quest and reputation reactions, story flags, and cinematic sequences from the Godot World Builder without writing code.

Dialogue content is authored in Godot. The backend remains authoritative over available choices, conditions, story flags, quest consequences, rewards, and persistent outcomes. The frontend presents the approved conversation and plays cinematic presentation.

## Recommended First-Scope Rules

- Conversations and cinematics are private to the interacting player.
- Other players and the world continue running during a conversation.
- Important dialogue actions are validated and executed by the backend.
- Cinematics may temporarily lock the local player’s movement and combat input.
- Cinematics are skippable unless explicitly marked otherwise.
- Skipping presentation does not skip authoritative story consequences.
- Initial story flags are player-scoped.
- World-wide and faction-wide story flags are deferred until a later milestone.
- Dialogue uses written text only for the first version; voice-over and localization tooling are deferred.
- Dialogue and cinematic definitions never execute arbitrary scripts. They use a safe list of authored conditions and actions.

## Designer Workflow

The completed workflow should be:

1. Select an authored NPC character.
2. Create or assign a conversation.
3. Add dialogue nodes in a visual conversation graph.
4. Write the NPC text and player choices.
5. Connect choices to later dialogue nodes.
6. Add conditions such as quest state, reputation, faction, level, or story flags.
7. Add approved actions such as setting a flag, offering a quest, or starting a cinematic.
8. Create a cinematic timeline using camera and character commands.
9. Preview the dialogue and cinematic locally.
10. Validate all references across the world.
11. Publish the map and storytelling definitions together.

## Deliverable 1: Conversation Resources

Add the following editable Godot resources.

### Dialogue Conversation

A `DialogueConversation` resource contains:

- Stable `conversation_id`
- Display name
- Optional owning map
- Starting node ID
- Conversation nodes
- Whether the player may exit
- Whether the conversation pauses local input
- Optional default cinematic
- Optional fallback text

Conversation files live under:

`res://maps/<map_id>/dialogue/`

### Dialogue Node

A `DialogueNode` contains:

- Stable `node_id`
- Speaker character ID
- Speaker display-name override
- Dialogue text
- Optional portrait or expression ID
- Conditions required to enter the node
- Actions executed when the node is entered
- Player choices
- Optional automatic next node
- Optional cinematic cue
- Optional end-conversation flag

### Dialogue Choice

A `DialogueChoice` contains:

- Stable `choice_id`
- Player-facing text
- Conditions required for the choice to appear
- Conditions required for the choice to remain selectable
- Destination node ID
- Actions executed when selected
- Optional disabled explanation
- Optional confirmation requirement for permanent choices

Choices are ordered manually by the designer.

## Deliverable 2: Safe Conditions

Create reusable `StoryCondition` resources. Multiple conditions may be combined using:

- All conditions must pass
- Any condition may pass
- Negated condition

Initial condition types:

- Quest has not started
- Quest is active
- Quest is at a specific stage
- Quest is complete
- Quest is failed
- Player belongs to a faction
- Player does not belong to a faction
- Reputation is at least a value
- Reputation is at most a value
- Player level is at least a value
- Player has a story flag
- Player does not have a story flag
- Player has an item and quantity
- Player lacks an item
- Previous dialogue choice was selected

Conditions reference discovered quests, factions, NPCs, and flags through editor selectors instead of manually typed IDs whenever possible.

The backend evaluates every condition. The client may preview conditions in the editor but cannot authorize a branch.

## Deliverable 3: Safe Dialogue Actions

Create reusable `StoryAction` resources.

Initial action types:

- Set a player story flag
- Clear a player story flag
- Increment a numeric player story value
- Offer a quest
- Advance a quest when explicitly allowed by that quest stage
- Complete a talk or interact objective
- Give an item
- Remove an item
- Give gold
- Give experience
- Change faction reputation
- Commit the player to a faction
- Start a cinematic
- Transition the player to an authored map and spawn
- End the conversation

Permanent or economy-affecting actions must be:

- Executed by the backend
- Idempotent
- Recorded with the dialogue session and choice ID
- Returned through an authoritative result event

The action system must not allow arbitrary method calls or arbitrary GDScript.

## Deliverable 4: Story Flags

Add a Story Flag Catalog to the World Builder.

Each flag contains:

- Stable flag ID
- Display name
- Description
- Value type: boolean, integer, or string
- Default value
- Whether it is visible in development tools
- Optional category

Initial flags are stored per player.

Example flags:

- `met_sewer_guide`
- `learned_about_endless_war`
- `refused_justice_commander`
- `spared_goblin_scout`
- `commander_introduction_seen`

The editor should show where each flag is read and where it is changed.

World validation must detect:

- References to undeclared flags
- Flags that are written but never read
- Flags that are read but never written and have no useful default
- Type mismatches

## Deliverable 5: NPC Conversation Assignment

Expand `AuthoredCharacter` with:

- Default conversation ID
- Conditional conversation entry points
- Conversation priority
- Optional one-time greeting
- Optional repeat greeting
- Optional ambient lines

An NPC may select a different starting conversation based on:

- Quest state
- Faction commitment
- Reputation
- Story flags
- Player level

The backend chooses the highest-priority eligible conversation.

The same NPC may remain a quest giver. Pressing interact opens the authoritative conversation first; quest offers and completions may be presented through dialogue actions.

## Deliverable 6: Visual Dialogue Graph Editor

Add a **Dialogue Builder** section to the World Builder.

It should provide:

- Conversation list
- Create, duplicate, rename, and delete
- Visual node graph
- Draggable dialogue nodes
- Choice connections
- Starting-node marker
- End-node marker
- Condition editor
- Action editor
- Speaker selector
- Quest, faction, flag, item, NPC, map, and spawn selectors
- Search by text or ID
- Direct navigation to the owning NPC
- Readable conversation outline
- Orphaned-node detection
- Loop detection and intentional-loop marking

The designer should not need to edit dialogue JSON.

## Deliverable 7: Dialogue Runtime UI

Add a reusable dialogue presentation layer that supports:

- Speaker name
- Dialogue text
- Portrait or expression
- Ordered player choices
- Disabled choices with explanations
- Continue and exit controls
- Keyboard, mouse, and controller navigation
- Optional typewriter presentation
- Fast-forward
- Skip cinematic
- Reconnect recovery
- Duplicate event protection

The UI sends intents such as:

- `dialogue_interact`
- `dialogue_continue`
- `dialogue_choose`
- `dialogue_exit`
- `cinematic_skip`

Every command includes:

- Unique `command_id`
- Dialogue session ID
- Conversation ID
- Current node ID
- Choice ID when applicable

The frontend must not choose the next authoritative node by itself.

## Deliverable 8: Cinematic Timeline

Add a `CinematicSequence` resource and a timeline editor.

Cinematic files live under:

`res://maps/<map_id>/cinematics/`

Initial timeline commands:

- Lock player input
- Unlock player input
- Save current camera state
- Restore camera state
- Pan camera to a world position
- Follow an authored NPC
- Follow the player
- Zoom camera
- Hold for a duration
- Fade in
- Fade out
- Show dialogue text
- Show a title card
- Make an NPC face left or right
- Play an NPC animation
- Move an NPC to an authored marker
- Play a sound
- Complete the cinematic

Every cinematic must restore the normal camera and input state when it:

- Completes
- Is skipped
- Is interrupted
- Loses connection
- Changes maps
- Encounters an invalid target

The first version should not move authoritative NPCs directly from the client. When a cinematic needs an NPC to move, the backend approves and broadcasts a cinematic movement state. Camera motion remains client-side presentation.

## Deliverable 9: Cinematic Markers

Add visually placeable `CinematicMarker` nodes to map scenes.

Each marker contains:

- Stable marker ID
- Display name
- Position
- Optional facing
- Optional camera zoom
- Optional camera framing size

Timeline commands select markers from the current or target map rather than requiring hand-entered coordinates.

Markers are editor/debug objects and do not render during ordinary gameplay.

## Deliverable 10: Validation and Preview

Expand world validation to check:

- Conversation IDs are unique
- Node and choice IDs are unique within their conversation
- Starting nodes exist
- Destination nodes exist
- Speakers exist
- Referenced NPCs, quests, factions, maps, spawns, items, flags, cinematics, and markers exist
- Required story flags have compatible types
- Conversations contain a reachable ending or an intentional loop
- No unreachable nodes exist
- Permanent choices request confirmation
- Cinematics restore camera and input
- Timeline targets exist
- No unsafe or unsupported actions are present

Add a Dialogue Preview mode that allows the designer to:

- Start from any conversation node
- Supply simulated quest, faction, reputation, level, item, and flag state
- See which conditions pass
- See which choices appear
- Play cinematics using the current map
- Inspect intended actions without applying real rewards or persistence

## Deliverable 11: Publishing

Map definitions gain optional collections:

- `dialogue_conversations`
- `story_flags`
- `cinematic_sequences`
- `cinematic_markers`

Authored characters gain optional conversation assignments.

Publishing should show:

- Added and removed conversations
- Added and removed nodes
- Changed choice destinations
- Changed conditions
- Changed authoritative actions
- Added and removed flags
- Changed cinematics

Removing or changing a published story flag, permanent choice, quest action, or active conversation should produce a high-visibility warning.

## Backend Responsibilities

The backend must own:

- Dialogue-session creation
- Eligible conversation selection
- Condition evaluation
- Choice availability
- Current authoritative node
- Choice idempotency
- Story flag persistence
- Quest and economy actions
- Reputation consequences
- Map transitions
- Reconnect recovery
- Conversation and cinematic revision ordering

Suggested server events:

- `dialogue_started`
- `dialogue_node_presented`
- `dialogue_choice_result`
- `dialogue_ended`
- `dialogue_rejected`
- `story_flags_snapshot`
- `story_flag_changed`
- `cinematic_started`
- `cinematic_cue`
- `cinematic_completed`
- `cinematic_interrupted`

## Implementation Order

### Step 1 — Dialogue Data and Graph Builder

Implement conversation, node, choice, condition, action, and flag resources. Add NPC assignment, graph editing, selectors, and world validation.

### Step 2 — Authoritative Dialogue Runtime

Implement backend dialogue sessions, condition evaluation, choices, actions, persistence, idempotency, reconnect recovery, and frontend dialogue presentation.

### Step 3 — Cinematic Builder and Runtime

Implement cinematic resources, markers, timeline editing, camera playback, input safety, backend-approved NPC cues, skipping, and interruption recovery.

### Step 4 — Preview and Safe Publishing

Implement simulated-state dialogue preview, cinematic preview, complete validation, structural diffs, warnings, and publishing.

## First Vertical Slice

Use three conversations to prove the system:

### Sewer Guide

- First greeting is different from repeat greetings.
- Explains the war through optional player questions.
- Sets `met_sewer_guide` and `learned_about_endless_war`.
- Offers the first tutorial quest through dialogue.

### Justice or Avenger Guard

- Reacts to faction commitment and reputation.
- Rejects an uncommitted player.
- Directs an eligible player to the commander.

### Faction Commander

- Plays a short camera pan from the player to the commander and nearby soldiers.
- Offers at least two player responses.
- Records the selected response as a story flag.
- Starts or advances the faction quest.
- Restores camera and input correctly after completion or skipping.

## Acceptance Criteria

This milestone is complete when the designer can:

1. Create a branching conversation without editing JSON.
2. Assign it to any authored character.
3. Show or hide choices using quest, faction, reputation, level, item, and flag conditions.
4. Set persistent player story flags.
5. Trigger authoritative quest, reward, reputation, and transition actions.
6. Create and preview a cinematic using map markers.
7. Recover the correct conversation after reconnecting.
8. Skip or interrupt a cinematic without leaving the camera or player input broken.
9. Validate all storytelling references across the world.
10. Publish dialogue and cinematic changes with a clear change summary.

## Out of Scope

- Voice acting and lip synchronization
- Translation/localization pipeline
- World-wide shared story flags
- Faction-wide shared story state
- Multiplayer synchronized cinematics
- Arbitrary scripting from dialogue
- Full animation-state authoring
- Procedural dialogue generation
- Romance or relationship systems
- Complex visual-novel presentation
