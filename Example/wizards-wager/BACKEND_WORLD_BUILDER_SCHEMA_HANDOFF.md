# Backend Handoff — World Builder Schema

## Objective

Support maps authored entirely from the Godot World Builder while keeping the server authoritative over movement, combat, characters, interactions, quests, map membership, and persistence.

This is an additive evolution of the working Milestone 1 contract.

## Character Model

All enemies, allies, guards, civilians, commanders, and quest characters are NPC characters using the shared player-style animation layout.

Do not infer hostility from `combatant_kind`.

Hostility and combat behavior come from:

- `faction_id`
- `hostile_factions`
- `hostile_archetypes`
- behavior profiles
- the player’s authoritative faction relationship

`combatant_spawns` remains the compatibility collection for resizable character spawn regions:

```json
{
  "spawn_id": "sewer_zombies",
  "combatant_kind": "npc",
  "archetype_id": "zombie",
  "visual_id": "sewer_zombie",
  "faction_id": "enemy",
  "spawn_count": 3,
  "placement_mode": "random_in_bounds",
  "position": {"x": 1500, "y": 435},
  "bounds": {"x": 900, "y": 80},
  "surface_id": "sewer_floor",
  "behavior_profile_id": "sewer_enemy_patrol",
  "respawn_delay_seconds": 30,
  "leash_distance": 900,
  "aggro_distance": 360,
  "stat_overrides": {},
  "hostile_factions": ["player"],
  "hostile_archetypes": []
}
```

`quest_givers` remains the compatibility collection for fixed authored characters, including characters that offer no quests:

```json
{
  "npc_id": "village_guard",
  "display_name": "Village Guard",
  "archetype_id": "guard",
  "faction_id": "justice",
  "visual_id": "justice_knight",
  "combatant_kind": "npc",
  "position": {"x": 800, "y": 435},
  "surface_id": "ground",
  "interaction_radius": 96,
  "quest_ids": [],
  "interaction_type": "talk",
  "dialogue_text": "Stay alert.",
  "invulnerable": true,
  "behavior_profile_id": "",
  "behavior_profile": {},
  "respawn_delay_seconds": 0,
  "aggro_distance": 0,
  "leash_distance": 0,
  "hostile_factions": [],
  "hostile_archetypes": []
}
```

Accept absent optional fields with their safe defaults. Continue accepting existing Milestone 1 maps.

Every realtime combatant presentation must preserve:

- `combatant_kind`
- `archetype_id`
- `visual_id`
- `faction_id`
- relationship and attack-legality presentation

## Quest Areas

Accept an optional top-level `quest_areas` array:

```json
{
  "area_id": "old_graveyard",
  "display_name": "Old Graveyard",
  "position": {"x": 3200, "y": 400},
  "size": {"x": 900, "y": 500},
  "runtime_visible": false,
  "interaction_text": "",
  "authored_object_id": ""
}
```

Validation:

- `area_id` is required and unique within the map.
- Width and height must be positive.
- Area IDs must not collide with other authored object IDs on the map.

The server determines area entry and exit from authoritative player position. Do not trust a client claim that it entered an area.

## Quest Objectives

Continue supporting:

- `kill`
- `talk`
- `interact`
- `use_transition`
- `enter_map`

Add:

### Enter Area

```json
{
  "stage_id": "reach_graveyard",
  "objective_type": "enter_area",
  "target_map_id": "forest",
  "target_area_id": "old_graveyard",
  "required_count": 1
}
```

Progress when the authoritative player changes from outside to inside the target area while the stage is active.

### Location-Restricted Kill

A kill stage may include:

```json
{
  "required_kill_area_id": "old_graveyard"
}
```

Award progress only when the authoritative killing blow qualifies and the required location condition is satisfied. At minimum, the defeated character must be inside the area. If the final rule also requires the player to be inside, return that rule explicitly in validation/presentation data.

Cross-map stage validation uses `target_map_id`. If it is absent, use the quest’s authored map.

## World Interactables

Accept an optional top-level `interactable_objects` array:

```json
{
  "object_id": "ancient_lever",
  "display_name": "Ancient Lever",
  "interaction_text": "The mechanism grinds beneath the floor.",
  "required_proximity": 96,
  "position": {"x": 4100, "y": 320}
}
```

Add the client intent:

```json
{
  "type": "world_object_interact",
  "data": {
    "command_id": "unique-command-id",
    "map_id": "forest",
    "object_id": "ancient_lever"
  }
}
```

The server validates:

- Command idempotency
- Current map membership
- The object exists in the active published map
- Authoritative proximity
- Player state permits interaction
- The object is the target of an active quest stage when quest progress is requested

Return an authoritative interaction result and any quest-state revision.

## Transitions

Continue using the existing transition contract.

Accept optional:

```json
{
  "paired_transition_id": "forest_to_sewer"
}
```

This is authoring and validation metadata. Normal transition approval remains based on the selected transition’s explicit destination.

World validation should confirm that the paired ID exists in the destination map when present.

## Publishing and Validation

Keep optimistic concurrency:

- New map publish uses expected version `0`.
- Existing map publish uses the active published version.
- Conflict returns `409`.
- Successful publish returns the new version.

Backend definition validation must:

- Remain backward-compatible with existing maps.
- Accept unknown optional presentation fields where safe.
- Validate all new collections and quest-stage references.
- Return field paths and stable error codes suitable for clickable editor errors.
- Reject duplicate IDs and broken local references.
- Validate cross-map targets against published maps when they exist.

Do not require generated JSON to become the editable source. Godot scenes and resources remain the source of truth.

## Reconnect and Snapshot Requirements

Reconnect snapshots must restore:

- Current map and spawn/location
- Active quest and stage
- `enter_area` progress
- Location-restricted kill progress
- Fixed authored characters
- Spawned character-region instances
- Object interaction consequences
- Independent quest, location, and faction revisions

## Acceptance Tests

1. Publish an unchanged Milestone 1 map successfully.
2. Publish a map containing a fixed non-quest character.
3. Publish a hostile NPC character region using a custom `visual_id`.
4. Publish two maps with paired transitions and validate both destination spawns.
5. Complete an `enter_area` quest from authoritative movement.
6. Reject a false client interaction outside an interactable’s range.
7. Count a location-restricted kill inside its quest area and reject one outside.
8. Reconnect during each new quest type without losing or duplicating progress.
9. Reject definitions with missing cross-map NPC, area, transition, or spawn targets.
10. Preserve command idempotency for world-object interactions and quest progression.
