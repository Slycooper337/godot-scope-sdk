# Backend Request: Duplicate Authored Spawn Populations

The current Forest definition exports these populations:

- `enemy_spawn_area_1`: zombie, `spawn_count: 1`
- `enemy_spawn_area_2`: goblin, `spawn_count: 1`
- `enemy_spawn_area_3`: skeleton, `spawn_count: 20`
- `justice_knights_spawn`: justice knight, `spawn_count: 1`
- `avenger_knights_spawn`: avenger knight, `spawn_count: 1`

The editor shows those counts, but runtime produces multiple instances for groups configured as one. Please verify the active published version and duplicate suppression.

## Required behavior in published mode

When `WORLD_MAP_DEFINITION_MODE=published`, the published `combatant_spawns` definition must be authoritative. A legacy `world_spawn_area` or battle-group record must not add another population for the same authored `spawn_id`.

Use a stable deduplication key:

```text
(world_id, map_id, published_map_version, spawn_id)
```

If legacy synchronization is retained, it must update/reconcile the authored group rather than append a second group. The following authored IDs must be treated as the same groups as their legacy counterparts:

```text
enemy_spawn_area_1
enemy_spawn_area_2
enemy_spawn_area_3
justice_knights_spawn
avenger_knights_spawn
```

## Diagnostics requested

For the active Forest runtime, return:

- active published map version;
- each resolved spawn group ID;
- source (`published_definition`, `world_spawn_area`, or `battle_group`);
- configured spawn count;
- current live population;
- any duplicate group key;
- whether the client joined a stale map session.

Also confirm that publishing a new map version clears/reconciles old runtime spawn groups instead of leaving their existing populations active.
