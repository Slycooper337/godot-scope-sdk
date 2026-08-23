# Backend Request: Forest Knight Spawn Groups Missing

Zombie, Goblin, and Skeleton authored spawns now appear and respawn correctly. Justice and Avenger Knights still do not appear. Please trace the published NPC/battle-group path specifically.

## Expected authored spawn groups

The active Forest definition must contain both entries:

```json
{
  "spawn_id": "justice_knights_spawn",
  "combatant_kind": "npc",
  "archetype_id": "justice_knight",
  "faction_id": "justice",
  "spawn_count": 1,
  "respawn_delay_seconds": 8,
  "behavior_profile_id": "justice_knight_battle",
  "surface_id": "justice_ground"
}
```

```json
{
  "spawn_id": "avenger_knights_spawn",
  "combatant_kind": "npc",
  "archetype_id": "avenger_knight",
  "faction_id": "avenger",
  "spawn_count": 1,
  "respawn_delay_seconds": 8,
  "behavior_profile_id": "avenger_knight_battle",
  "surface_id": "avenger_ground"
}
```

## Required checks

1. Confirm the runtime is loading the latest published Forest map version.
2. Confirm both spawn groups pass validation and are converted into authoritative battle groups.
3. Confirm `spawn_count: 1` is accepted for NPC groups.
4. Confirm `combatant_kind: "npc"` does not route the spawn into a legacy-only path.
5. Confirm `justice_knight` and `avenger_knight` resolve to valid declared archetypes.
6. Confirm the behavior profiles resolve and do not prevent initial spawning because their target filters are empty or faction-specific.
7. Confirm the groups are not filtered out because their authored surfaces are at negative Y coordinates.

## Required runtime payload

The first spawn must appear in `world_snapshot` or `mob_snapshot.combatants`, and/or as `mob_spawned`, with at least:

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
  "position": {"x": 9743, "y": -3999},
  "velocity": {"x": 0, "y": 0},
  "state": "patrol",
  "alive": true,
  "surface_id": "justice_ground",
  "resolved_surface_id": "justice_ground"
}
```

Return diagnostics for both groups: active map version, validation result, group creation result, suppression reason if skipped, and the first runtime spawn payload.
