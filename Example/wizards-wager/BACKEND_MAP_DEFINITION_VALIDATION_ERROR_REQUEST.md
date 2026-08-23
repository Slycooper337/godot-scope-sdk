# Backend Request: Diagnose Invalid Map Definition Response

## Current symptom

Authentication and routing now succeed, but the Godot Map Authoring addon
receives a generic response:

```text
invalid map definition
```

The request is reaching:

```text
POST /worlds/main_world/maps/forest/validate
```

The frontend cannot safely correct this without knowing which field the
deployed validator rejects.

## Request

Please inspect the deployed map validator and return the exact validation
failure for the current Forest payload.

The validation response should include field-level information, for example:

```json
{
  "error": "invalid map definition",
  "errors": [
    {
      "path": "combatant_spawns[0].surface_id",
      "code": "required",
      "message": "surface_id is required"
    }
  ]
}
```

If the backend already produces detailed errors internally, please expose them
in the `422` response. Do not collapse all validation failures to one generic
message.

## Current frontend payload contract

The frontend sends this top-level structure:

```json
{
  "definition": {
    "map_id": "forest",
    "world_id": "main_world",
    "version": 0,
    "coordinate_system": "godot_2d",
    "physics_surfaces": [],
    "combatant_spawns": []
  }
}
```

Each physics surface is shaped like:

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

Each combatant spawn is shaped like:

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
  "hostile_archetypes": [],
  "behavior_profile": {}
}
```

## Questions for the backend implementation

Please confirm the following against the deployed validator:

1. Is the expected request body `{ "definition": { ... } }`, or should the
   definition fields be sent directly at the request root?
2. Are `version` and `coordinate_system` accepted top-level fields?
3. Are the required arrays named `physics_surfaces` and
   `combatant_spawns`?
4. Is `surface_id` required for every combatant spawn?
5. Does `surface_id` need to reference a specific surface type or ground-only
   surface?
6. Are `behavior_profile_id` and the nested `behavior_profile` both required?
7. Which behavior fields are accepted by the deployed validator?
8. Are empty arrays and empty objects accepted for optional target filters and
   stat overrides?
9. Are `faction_id: "enemy"`, `archetype_id: "zombie"`, `"goblin"`, and
   `"skeleton"` registered in the deployed environment?
10. Is `spawn_count: 1` valid for both fixed and random-in-bounds placement?
11. Are `collision_layer`, `collision_mask`, and `one_way` accepted surface
    fields?
12. Does the validator require map bounds, player spawns, factions, or behavior
    profiles in separate top-level arrays that are not currently exported?

## Required diagnostic response

Please provide:

- the exact rejected JSON path(s);
- the validator error code(s);
- the expected type/value for each rejected field;
- the deployed schema or DTO for `physics_surfaces`;
- the deployed schema or DTO for `combatant_spawns`;
- one minimal known-good validation payload;
- the deployed backend commit/image version running the validator.

## Suggested temporary diagnostic behavior

For `422` responses, return:

```json
{
  "error": "invalid map definition",
  "errors": [
    {
      "path": "string",
      "code": "string",
      "message": "string",
      "expected": "optional string or object",
      "received": "optional value"
    }
  ]
}
```

This is needed both for the current Forest migration and for future map
authoring. The editor should not have to infer backend schema requirements from
a generic validation message.

## Acceptance criteria

1. The current Forest validation request returns either success or precise
   field-level errors.
2. A minimal known-good map definition is documented.
3. The frontend and deployed backend agree on the request envelope and field
   names.
4. Optional behavior, faction, and stat fields have explicit null/empty-value
   rules.
5. The same validator contract is used by both `/validate` and publish.
