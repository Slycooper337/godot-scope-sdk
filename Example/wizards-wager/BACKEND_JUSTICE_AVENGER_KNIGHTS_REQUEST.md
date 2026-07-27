# Backend Request: Authoritative Justice Knight vs. Avenger Knight Battle

## Goal

Implement the first perpetual NPC faction battle for `wizards-wager`. The
server must continuously maintain two groups of NPCs in the Forest map:

- Justice Knights (`justice_knight`) belonging to the `justice` faction.
- Avenger Knights (`avenger_knight`) belonging to the `avenger` faction.

They must acquire, chase, attack, kill, and respawn against each other without
client AI or client-authored NPC damage. They remain neutral to players for the
initial release. This is the concrete first deployment of the dynamic,
directed faction-relationship model described in
`BACKEND_DYNAMIC_NPC_FACTIONS_REQUEST.md`.

## Frontend contract already implemented

The Godot client has one hidden template at:

```text
Game/Enemies/NPC
```

The template is duplicated only when the authoritative world sends an NPC. It
does not act as a live local NPC.

The client maps these stable `mob_type`/`visual_id` values to dedicated local
sprite sheets:

| ID | Sprite sheet |
|---|---|
| `justice_knight` | `res://assets/NPCSHEETS/JusticeKnight.png` |
| `avenger_knight` | `res://assets/NPCSHEETS/AvengerKnight.png` |

Both sheets use the same 360x288, 36x36-frame sequence/layout as the player,
under dedicated `npc_*` animation names. The client creates the following animations
from each sheet:

| Animation | Row Y | Frames | Loop |
|---|---:|---:|---|
| `npc_walk` | 0 | 6 | yes |
| `npc_idle` | 36 | 6 | yes |
| `npc_attack` | 108 | 8 | no |
| `npc_hit` | 180 | 3 | no |
| `npc_die` | 216 | 8 | no |
| `npc_power_up` | 252 | 10 | no |

Do not upload, download, or otherwise send textures through realtime. The
server sends only stable type/visual identifiers.

## Exact Forest geometry

Use the following scene-derived bounds. The collision rectangle used by both
areas is 8912x78; positions below are world-space bounds.

| Spawn group | Scene node | min_x | max_x | min_y | max_y / ground_y |
|---|---|---:|---:|---:|---:|
| Justice Knights | `Game/JusticeKnightsSpawn` | 5287 | 14199 | -4077 | -3999 |
| Avenger Knights | `Game/AvengerKnightSpawn` | -1074 | 7838 | -4077 | -3999 |

Both areas overlap horizontally from x=5287 through x=7838. This overlap is
intentional: it is the initial engagement band. NPCs must spawn in their own
group's bounds, not arbitrarily in the overlap, and may enter the overlap while
chasing a valid hostile target.

Register a solid Forest collision surface at y=-3999 covering x=-1074 through
x=14199, or equivalent non-overlapping surfaces that produce exactly the same
ground behavior. NPCs must use the normal authoritative gravity/grounded
simulation and settle at y=-3999.

## Data registration

Add an up/down migration and bootstrap/repair registration for:

```text
application_id: wizards-wager
world_id: main_world
map_id: forest
battle_area_id: justice_avenger_knights
enabled: true
```

Register directed relationship rows:

```text
justice -> avenger: hostile
avenger -> justice: hostile
justice -> player: neutral
avenger -> player: neutral
```

Register two NPC archetypes. All numbers below are initial configuration,
stored in data rather than hard-coded so they can be balanced later:

| Field | Justice Knight | Avenger Knight |
|---|---:|---:|
| `mob_type` / `visual_id` | `justice_knight` | `avenger_knight` |
| faction | `justice` | `avenger` |
| AI | `battle` | `battle` |
| max health | 100 | 100 |
| melee damage | 15 | 15 |
| patrol speed | 45 | 45 |
| chase speed | 110 | 110 |
| attack range | 60 | 60 |
| attack windup | 0.25 seconds | 0.25 seconds |
| attack cooldown | 0.75 seconds | 0.75 seconds |
| experience reward | 10 | 10 |

Register separate spawn groups with a desired population of 6 each and an
8-second respawn delay:

```text
justice_knights_spawn: archetype=justice_knight, desired_active=6
avenger_knights_spawn: archetype=avenger_knight, desired_active=6
```

The counts and respawn delay must be configuration fields, not code constants.

## Required server behavior

1. Spawn each group only in its own bounds. Use a valid grounded spawn position
   and avoid solid geometry and an immediate overlapping enemy body.
2. Run `battle` AI server-side. It chooses only alive, same-map, hostile
   combatants; it keeps a valid current target, otherwise uses nearest hostile
   with a deterministic ID tie-breaker.
3. NPCs may cross into the engagement overlap while chasing. When no hostile
   target is valid or the target exceeds leash distance, they return to their
   home group bounds instead of drifting into the other faction's spawn area.
4. Re-check the current directed relationship immediately before damage. A
   dynamic rule change from hostile to neutral/friendly cancels an invalid
   attack and causes retargeting no later than the next world tick.
5. Use the existing server-authoritative movement, gravity, range, facing,
   windup, cooldown, knockback, damage, death, and respawn paths. NPC-to-NPC
   damage must never be routed through a client command.
6. On death, decrement only that spawn group's active count, publish death,
   and replace it after its own configured delay. Reconciliation must never
   exceed six active NPCs per group.
7. Players are neutral observers initially. A player attack against a neutral
   Knight must be rejected by the server as `not_hostile`; Knights do not
   acquire a neutral player target.

## Realtime protocol

Use the current authoritative world event family so this works with the
already-implemented frontend:

- `world_snapshot`
- `mob_snapshot`
- `mob_spawned`
- `mob_damaged`
- `mob_died`

Every Knight payload must include:

```json
{
  "mob_id": "stable-NPC-instance-id",
  "mob_type": "justice_knight",
  "visual_id": "justice_knight",
  "faction_id": "justice",
  "battle_area_id": "justice_avenger_knights",
  "spawn_group_id": "justice_knights_spawn",
  "position": {"x": 6000, "y": -3999},
  "velocity": {"x": 110, "y": 0},
  "health": 100,
  "max_health": 100,
  "state": "chase",
  "facing": 1,
  "grounded": true,
  "alive": true,
  "sequence": 1234
}
```

`state` must be one of `idle`, `patrol`, `acquire`, `chase`, `return`,
`attack`, `hit`, `dead`, or `respawning`. `facing` is `-1` or `1`.

For smooth rendering, send authoritative NPC movement snapshots at the same
cadence as existing mobs, with a monotonic world `sequence`, position,
velocity, state, and facing on every movement update. Do not omit velocity or
substitute client-side path prediction. The client buffers two snapshots,
renders 120 ms behind, and caps extrapolation at 200 ms. Send an explicit
spawn/respawn snapshot before deltas and set `teleport: true` only for a true
relocation, not ordinary chase movement.

`mob_damaged` must include `mob_id`, `attacker_mob_id` when the attacker is an
NPC, `damage`, `remaining_health`, `critical`, `knockback`, `attack_id`, and
`sequence`. `mob_died` must include the victim `mob_id`, optional killer ID,
death position, and `sequence`.

Also include the server-resolved relationship to the receiving player, for
example `relationship_to_player: "neutral"`. This is presentation data only;
the server remains responsible for legality. It will let the frontend show a
team/hostility marker when relationships become dynamic.

## Tests

1. Fresh registration creates exactly six Justice Knights and six Avenger
   Knights in the Forest map, each inside the correct source bounds.
2. All Knights settle at y=-3999 using authoritative gravity and the new
   collision surface.
3. Justice Knights select only Avenger Knights, and Avenger Knights select
   only Justice Knights; neutral players are ignored.
4. NPC-to-NPC attacks enforce range, facing, windup, cooldown, damage,
   knockback, death, and idempotency server-side.
5. A death respawns only the correct faction/group after eight seconds and the
   active population never exceeds six per group, including concurrent ticks.
6. Changing one directed relationship to neutral immediately invalidates attack
   targeting and the relevant NPCs return or retarget.
7. Every lifecycle/movement payload has `mob_type`, `visual_id`, velocity,
   state, facing, grounded state, and an increasing sequence suitable for
   smooth client interpolation.
8. The current Zombie, Goblin, Skeleton, player attack, power-up, player death,
   XP, respawn, and existing world snapshot tests stay passing.
