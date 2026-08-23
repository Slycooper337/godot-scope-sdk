# Backend Request: Map Authoring and Behavior Integration

## Objective

Connect the backend world runtime to the versioned map definitions authored by
the Godot map-authoring tools.

The Godot frontend now authors map geometry, combatant spawn definitions,
faction targeting, behavior profiles, stat overrides, and map metadata. The
backend remains authoritative for physics validation, movement, targeting,
combat, death, respawn, and behavior execution.

The first target map is:

```text
world_id: main_world
map_id: forest
```

## Frontend definition contract

The editor exports a map definition with this top-level shape:

```json
{
  "map_id": "forest",
  "world_id": "main_world",
  "version": 0,
  "coordinate_system": "godot_2d",
  "physics_surfaces": [],
  "combatant_spawns": []
}
```

### Physics surface

Each surface contains:

```json
{
  "surface_id": "platform_01",
  "shape": "rectangle",
  "position": {"x": 608, "y": 390},
  "size": {"x": 260, "y": 16},
  "rotation": 0,
  "one_way": true,
  "collision_layer": 1,
  "collision_mask": 1
}
```

The server should use stable `surface_id` values for grounded-spawn and
physics configuration. Do not identify surfaces by array index.

### Combatant spawn

Each combatant spawn contains:

```json
{
  "spawn_id": "justice_knights_spawn",
  "combatant_kind": "npc",
  "archetype_id": "justice_knight",
  "faction_id": "justice",
  "spawn_count": 1,
  "placement_mode": "random_in_bounds",
  "position": {"x": 9743, "y": -4038},
  "bounds": {"x": 8912, "y": 78},
  "surface_id": "ground_upper_4",
  "behavior_profile_id": "justice_knight_battle",
  "respawn_delay_seconds": 30,
  "leash_distance": 900,
  "aggro_distance": 360,
  "stat_overrides": {},
  "hostile_factions": [],
  "hostile_archetypes": [],
  "behavior_profile": {}
}
```

`spawn_count: 1` is a supported and important case. It represents one
individual combatant, especially when `placement_mode` is `fixed`.

## Required storage and API

Add a versioned map-definition store scoped by `world_id` and `map_id`.

Required operations:

```text
GET /worlds/{world_id}/maps/{map_id}/definition
PUT /worlds/{world_id}/maps/{map_id}/definition
POST /worlds/{world_id}/maps/{map_id}/validate
GET /worlds/{world_id}/maps/{map_id}/versions
```

Publishing must:

- validate the complete definition before saving;
- assign a monotonically increasing version;
- preserve the author and publish timestamp;
- reject writes based on an older `expected_version`;
- retain the previous published version for rollback;
- return the published version and validation summary.

The storage format may use normalized tables or one versioned document, but
the API must preserve stable IDs and the exported shape above.

## Validation requirements

Reject a map definition when:

- `map_id` or `world_id` is missing;
- any object ID is duplicated;
- a surface has invalid dimensions;
- a spawn has `spawn_count < 1`;
- an archetype is unknown;
- a faction is unknown;
- a behavior profile is missing or malformed;
- a referenced surface does not exist;
- a fixed spawn is outside the map bounds, if map bounds are enforced;
- a patrol route or waypoint is malformed;
- a stat override is not supported by the archetype;
- a target faction or target archetype is unknown.

Return field-level validation errors suitable for display in the editor.

## Runtime loading

When the authoritative world starts or a player joins an area:

1. Load the published definition for `main_world/forest`.
2. Include the active map version in the world state or snapshot.
3. Build server physics from `physics_surfaces`.
4. Register combatant spawn groups from `combatant_spawns`.
5. Preserve `spawn_id` as the stable spawn-group identifier.
6. Continue publishing the existing legacy event family during migration.

The server must not trust client-authored map data, positions, faction values,
behavior values, or stat overrides during gameplay.

## Behavior execution

Behavior profiles must be executed server-side. The client only renders the
resulting state.

Required behavior states:

```text
spawn
idle
patrol
pursue
attack
return
flee
dead
respawn
```

Behavior fields include:

- `initial_state`;
- patrol mode, direction, distance, and optional waypoints;
- aggro distance;
- leash distance;
- target factions;
- target archetypes;
- target combatant kinds;
- faction-specific reactions;
- behavior when a target is lost;
- behavior when the leash is exceeded.

Target selection must use stable semantic filters such as faction, archetype,
combatant kind, and spawn group. Do not persist or author runtime combatant
IDs as behavior targets.

### Required behavior examples

Justice Knights must be able to:

- spawn in `justice_knights_spawn`;
- patrol their authored area;
- attack Avenger combatants;
- ignore players when their relationship is neutral;
- return to their patrol/home area after losing a target or exceeding leash.

Avenger Knights must mirror this behavior while targeting Justice combatants.

Ordinary enemies must support the equivalent of:

```text
spawn at this point/area
walk left
attack hostile faction Y when within aggro range
return to route/home when the target is lost
```

## Runtime events and snapshots

Include the published map version where practical in:

- `world_snapshot`;
- `mob_snapshot`;
- `mob_spawned`;
- `mob_died`;
- combatant/NPC snapshot events.

For spawned combatants, preserve or expose:

```text
spawn_id
behavior_profile_id
faction_id
combatant_kind
archetype_id
state
target_id
movement_state
facing
```

The client should be able to render patrol, pursuit, attack, return, hit, and
death states without simulating the behavior itself.

## Migration requirements

Keep the current hardcoded Forest behavior working until the published map
definition is explicitly enabled for the map. Provide a feature flag or
equivalent migration switch so the deployment can compare:

```text
legacy Forest configuration
published Forest map definition
```

The first published map should preserve the existing Forest collision,
spawn-area, enemy, Skeleton, Justice Knight, and Avenger Knight behavior.

The canonical populations for `enemy_spawn_area_1` and
`enemy_spawn_area_2` must be confirmed before publishing. The frontend currently
uses temporary editor values of `1` for those two groups.

## Acceptance criteria

1. A valid Forest map definition can be published and fetched by version.
2. An older editor cannot overwrite a newer published version.
3. The server rejects duplicate IDs and invalid references with field-level
   errors.
4. Server physics matches the authored surface IDs, positions, sizes,
   rotations, and one-way settings.
5. A spawn group with `spawn_count: 1` creates exactly one combatant.
6. Fixed placement and random-in-bounds placement behave distinctly.
7. Justice Knights attack Avenger Knights but ignore neutral players.
8. Avenger Knights attack Justice Knights but ignore neutral players.
9. Patrol, pursue, attack, return, death, and respawn remain server-authoritative.
10. Reconnects and full snapshots use the published map version and preserve
    stable spawn-group metadata.
11. Existing Zombie, Goblin, Skeleton, player combat, XP, death, respawn, and
    realtime behavior tests remain passing.
