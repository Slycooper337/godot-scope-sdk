# Backend Request: Support Map-Declared Archetypes, Factions, and Behaviors

## Objective

Update the map-definition validator and runtime loader so authored maps can
declare and reference the combatants and behaviors they use.

The map-authoring workflow needs to support:

- individual enemies and NPCs;
- configurable spawn populations;
- physics surface references;
- faction relationships;
- archetype references;
- behavior profiles;
- patrol routes and movement intent;
- target filters and aggro/leash rules;
- server-authoritative behavior execution.

## Current validation problem

The backend currently reports errors such as:

```json
{
  "path": "combatant_spawns[0].archetype_id",
  "code": "missing_reference",
  "message": "unknown archetype: zombie"
}
```

The frontend map definition now declares the referenced IDs at the map level,
but the backend validator must explicitly support and resolve those
declarations.

## Required map-definition shape

The backend should accept this top-level structure:

```json
{
  "map_id": "forest",
  "world_id": "main_world",
  "version": 0,
  "coordinate_system": "godot_2d",
  "archetypes": [
    "zombie",
    "goblin",
    "skeleton",
    "justice_knight",
    "avenger_knight"
  ],
  "factions": [
    "player",
    "enemy",
    "justice",
    "avenger"
  ],
  "behavior_profiles": [],
  "physics_surfaces": [],
  "combatant_spawns": []
}
```

The first implementation may treat `archetypes` and `factions` as arrays of
stable IDs referencing global registries. It must not require the frontend to
duplicate the complete global archetype/stat definitions inside every map.

If the backend requires object declarations instead of string IDs, support a
documented equivalent such as:

```json
"archetypes": [
  {"archetype_id": "zombie"}
],
"factions": [
  {"faction_id": "enemy"}
]
```

Please choose one canonical form and document it. The validator, publish path,
runtime loader, and frontend contract must use the same form.

## Behavior profile contract

The backend should accept map-local behavior profiles with stable IDs:

```json
{
  "profile_id": "justice_knight_battle",
  "initial_state": "patrol",
  "patrol": {
    "mode": "direction",
    "direction": -1,
    "distance": 500,
    "waypoints": []
  },
  "aggro_distance": 360,
  "leash_distance": 900,
  "target_factions": ["avenger"],
  "target_archetypes": [],
  "target_combatant_kinds": ["npc"],
  "faction_reactions": {
    "avenger": "attack_on_sight",
    "player": "ignore"
  },
  "on_target_lost": "return_to_patrol",
  "on_leash_exceeded": "return_home"
}
```

Behavior profile requirements:

- `profile_id` must be unique within the map;
- every `combatant_spawns[*].behavior_profile_id` must resolve to a profile;
- target faction IDs must resolve to declared or globally known factions;
- target archetype IDs must resolve to declared or globally known archetypes;
- empty target arrays must be valid;
- patrol direction must support `-1` and `1`;
- random-in-bounds and fixed placement must remain distinct;
- `spawn_count: 1` must be valid.

## Combatant spawn validation

Each spawn must support:

```json
{
  "spawn_id": "enemy_spawn_area_1",
  "combatant_kind": "enemy",
  "archetype_id": "zombie",
  "faction_id": "enemy",
  "spawn_count": 1,
  "placement_mode": "random_in_bounds",
  "position": {"x": 2220, "y": 290},
  "bounds": {"x": 2109.5, "y": 336},
  "surface_id": "ground_main",
  "behavior_profile_id": "forest_enemy_patrol",
  "respawn_delay_seconds": 30,
  "leash_distance": 900,
  "aggro_distance": 360,
  "stat_overrides": {},
  "hostile_factions": [],
  "hostile_archetypes": []
}
```

Validate that:

- `spawn_id` is unique;
- `archetype_id` resolves;
- `faction_id` resolves;
- `behavior_profile_id` resolves;
- `surface_id` resolves to a physics surface;
- `spawn_count >= 1`;
- fixed placement has a valid position;
- random placement has positive bounds;
- stat overrides are allowed for the selected archetype;
- respawn, aggro, and leash values are valid.

## Physics surface references

`physics_surfaces` must be available to spawn validation and runtime grounded
spawn logic. Surface IDs must be stable and map-local:

```json
{
  "surface_id": "ground_main",
  "shape": "rectangle",
  "position": {"x": 7310, "y": 678.5},
  "size": {"x": 20384, "y": 329},
  "rotation": 0,
  "one_way": false,
  "collision_layer": 1,
  "collision_mask": 1
}
```

The backend should preserve the surface definition in the published version
and use `surface_id` for grounded spawn and map-physics lookup.

## Faction behavior

Support explicit faction relationship and response rules:

```text
Justice → Avenger = attack_on_sight
Avenger → Justice = attack_on_sight
Justice → Player = ignore
Avenger → Player = ignore
```

Supported responses should include at minimum:

```text
ignore
assist
defend
attack_on_sight
pursue
flee
```

The backend remains authoritative for all target acquisition and attacks. The
client only receives and renders the resulting state.

## Runtime requirements

When loading a published map:

1. Resolve declared archetypes against the global archetype registry.
2. Resolve declared factions against the global faction registry.
3. Register map-local behavior profiles.
4. Register physics surfaces by stable ID.
5. Create spawn groups from `combatant_spawns`.
6. Execute behavior profiles server-side.
7. Include map version and behavior metadata in snapshots/events.

Runtime combatants should preserve:

```text
spawn_id
behavior_profile_id
archetype_id
faction_id
combatant_kind
state
target_id
movement_state
facing
```

## Required diagnostics

For any invalid definition, return field-level errors:

```json
{
  "error": "invalid map definition",
  "errors": [
    {
      "path": "combatant_spawns[0].archetype_id",
      "code": "missing_reference",
      "message": "unknown archetype: zombie",
      "expected": "declared or globally registered archetype",
      "received": "zombie"
    }
  ]
}
```

Use the same validation function for `/validate` and publish. Do not allow a
definition to pass validation and then fail during runtime loading.

## Acceptance criteria

1. The Forest definition with declared archetypes, factions, behavior profiles,
   surfaces, and combatant spawns validates successfully.
2. `spawn_count: 1` creates exactly one combatant.
3. A fixed individual spawn and a random-area spawn behave distinctly.
4. Surface references resolve and are used for grounded spawning.
5. Justice and Avenger profiles target only the opposing faction.
6. Empty stat and target-filter arrays are accepted.
7. Behavior profiles execute server-side for patrol, pursue, attack, return,
   death, and respawn.
8. Published map versions retain all declarations and rollback correctly.
9. Snapshots/events expose the map version and behavior metadata.
10. Existing legacy Forest runtime behavior remains available during migration.
