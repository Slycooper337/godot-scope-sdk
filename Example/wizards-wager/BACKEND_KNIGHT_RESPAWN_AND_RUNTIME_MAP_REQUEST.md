# Backend Request: Knight Respawn and Runtime Map Verification

The frontend can collide with authored combatants, but their visuals are not consistently present and the first killed combatants do not visibly respawn.

Please verify the published Forest runtime path for the active map version.

## Required checks

1. Confirm the server is loading the latest published Forest definition, not a stale version.
2. Confirm `justice_knights_spawn` and `avenger_knights_spawn` are loaded as authoritative NPC spawn groups.
3. Confirm each group has `spawn_count: 1` and `respawn_delay_seconds: 8`.
4. Confirm a death schedules respawn for the same group and does not permanently remove the group.
5. Confirm respawn emits either a `mob_spawned` event or a `mob_snapshot`/`world_snapshot` entry using the same stable ID or a documented replacement ID.

## Required payload fields

Every initial spawn and respawn should include:

```json
{
  "mob_id": "stable-id",
  "combatant_id": "stable-id",
  "mob_type": "justice_knight",
  "archetype_id": "justice_knight",
  "visual_id": "justice_knight",
  "combatant_kind": "npc",
  "faction_id": "justice",
  "spawn_group_id": "justice_knights_spawn",
  "map_id": "forest",
  "map_version": 2,
  "position": {"x": 6000, "y": -3999},
  "velocity": {"x": 0, "y": 0},
  "state": "respawning",
  "alive": true,
  "health": 100,
  "max_health": 100,
  "surface_id": "justice_ground",
  "resolved_surface_id": "justice_ground",
  "resolved_ground_y": -3999
}
```

`mob_died` must be followed by a respawn payload after 8 seconds. If the server intentionally assigns a new ID, include the new ID consistently in all subsequent snapshots and events.

## Requested diagnostics

Please return, for one Justice and one Avenger combatant:

- active published map version;
- spawn group ID and authored respawn delay;
- death timestamp;
- scheduled respawn timestamp;
- respawn event type and payload;
- whether the combatant appears in the next `world_snapshot` and `mob_snapshot`.

Also confirm whether the current runtime map is expected to contain the authored `ForestMap/PhysicsSurfaces` layout or any legacy level geometry.
