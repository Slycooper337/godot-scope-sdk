# Backend Request: Authoritative Skeletons in Forest Spawn Area 3

## Goal

Register the new Skeleton enemy and third forest spawn area so Skeleton instances are created, simulated, attacked, killed, rewarded, respawned, and broadcast through the existing authoritative-world protocol.

The Godot frontend now maps:

```text
mob_type: skeleton
template node: Game/Enemies/Skeleton
```

No Skeleton instance placed in the scene is used as a live local enemy. Like Zombie and Goblin, it is hidden and duplicated only as the visual template for server-provided mobs.

## Scene-derived area geometry

The third editor area is:

```text
Game/EnamySpawnArea3
```

Its transforms are:

```text
Area position:            (7283, -2202)
Collision local position: (4538, 527)
Collision size:           (8912, 78)
```

The resulting world-space bounds are:

```text
min_x:  7365
max_x: 16277
min_y: -1714
max_y: -1636
ground_y: -1636
```

Use these exact values unless the level geometry is intentionally changed again.

## Skeleton configuration

Register this mob type for the `wizards-wager` application. Skeleton must use
the same authoritative movement, targeting, attack timing, and recovery
behavior as Zombie, with the explicit health and damage overrides below.

| Field | Value |
|---|---:|
| `mob_type` | `skeleton` |
| `max_health` | 100 |
| `experience_reward` | copy from `zombie` |
| all movement fields | copy from `zombie` |
| all targeting/aggro fields | copy from `zombie` |
| all attack timing/type fields | copy from `zombie` |
| player damage | 25 |

At the time of this request, the canonical Zombie registration uses 10 XP,
`bite`, movement enabled, patrol speed 45, chase speed 110,
attack range 60, 0.75-second cooldown, and 0.25-second windup. Prefer copying
the current Zombie behavior fields in the migration/bootstrap code instead of
maintaining a second independently tuned behavior profile, then override
Skeleton health to 100 and landed player damage to 25.

## Spawn-area registration

Create:

```text
application_id: wizards-wager
spawn_area_id: enemy_spawn_area_3
world_id: main_world
map_id: forest
mob_type: skeleton
max_active: 20
initial_spawn_count: 20
respawn_delay_seconds: 30
min_x: 7365
max_x: 16277
min_y: -1714
max_y: -1636
enabled: true
```

Also register a solid collision surface:

```text
application_id: wizards-wager
map_id: forest
surface_id: ground_3
surface_type: solid
min_x: 7365
max_x: 16277
y: -1636
```

Spawn and initialize Skeletons through the same path used by Zombies. Do not
include Skeleton in the Goblin grounded-spawn special case. Gravity and
`ground_3` should settle it at y=-1636 using the normal Zombie physics path.

## Required implementation work

1. Add an up/down migration after the current latest migration.
2. Upsert the `skeleton` row in `world_mob_types` by copying the authoritative
   Zombie behavior profile, changing `mob_type`, and setting `max_health=100`.
3. Upsert `enemy_spawn_area_3` and its `world_spawn_area_state`.
4. Upsert the `ground_3` collision surface.
5. Update repository bootstrap/repair registration so a fresh application receives the Skeleton type, area, and surface without relying only on historical migration state.
6. Ensure initial spawn and respawn use the same initialization, movement,
   targeting, gravity, attack, and recovery behavior as Zombies.
7. Keep all existing generic event names:
   - `world_snapshot`
   - `mob_snapshot`
   - `mob_spawned`
   - `mob_damaged`
   - `mob_died`
   - `attack_ack`
   - `attack_rejected`
8. Every Skeleton payload must include:
   - `mob_id`
   - `mob_type: "skeleton"`
   - `spawn_area_id: "enemy_spawn_area_3"`
   - `world_id: "main_world"`
   - `map_id: "forest"`
   - position, velocity, health, max health, state, facing, status, and grounded state
9. Reuse the existing authoritative combat, power-up, death, XP, and respawn paths. Do not add a Skeleton-specific client event. Parameterize mob-to-player damage by mob type/configuration so Skeleton deals 25 while Zombie retains its current damage.
10. Preserve server-side range, facing, cooldown, player-life, target-life, map, power-up, swing, and idempotency validation.

## Tests

Add coverage proving:

1. Forest snapshots include `enemy_spawn_area_3` and active Skeletons.
2. Skeletons spawn within the area-3 bounds and settle on `ground_3` at y=-1636 through the Zombie physics path.
3. Given equivalent inputs, Skeleton and Zombie produce matching movement, targeting, attack, and recovery behavior.
4. Skeletons acquire only valid players in their map and leash area.
5. The current Zombie attack windup and cooldown are enforced for Skeleton.
6. A landed Skeleton attack publishes exactly 25 authoritative player damage.
7. Basic and powered player attacks can damage Skeletons through the existing attack path.
8. Skeleton death awards the same XP as Zombie exactly once and publishes `mob_died`.
9. Skeletons respawn after 30 seconds without exceeding 20 active instances.
10. Initial reconciliation creates 20 active Skeletons and repeated reconciliation never exceeds 20.
11. Migration rollback removes only area 3, `ground_3`, and Skeleton registration/state owned by this feature.
12. Existing Zombie, Goblin, power-up, player-death, and world-physics tests remain passing.
