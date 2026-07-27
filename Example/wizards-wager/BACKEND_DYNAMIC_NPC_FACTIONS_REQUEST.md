# Backend Request: Authoritative NPC Factions and Perpetual Battle Areas

## Goal

Add server-authoritative NPC combatants with dedicated NPC textures on the
Godot client. Each NPC texture follows the player's established visual and
animation framework, but NPCs do **not** reuse the player texture. NPCs can
fight players and other NPCs, and can change their relationships at runtime.
The immediate gameplay use case is one battle area that continuously spawns two
NPC factions and keeps them fighting each other.

This must be a generic combatant system, not a one-off `red_team` versus
`blue_team` feature. It must support future PvP, co-op teams, neutral NPCs,
guards, temporary alliances, and per-character hostility overrides without
changing the combat protocol again.

The server remains authoritative for actor identity, faction membership,
relationship resolution, target selection, combat timing, damage, death, and
respawn. Clients render state and submit player attack intent only.

## Terms

| Term | Meaning |
|---|---|
| `combatant` | Any attackable actor: player, NPC, or future summon/pet. |
| `faction` | A server-owned relationship group such as `player`, `ironward`, or `emberclaw`. |
| `relationship` | `friendly`, `neutral`, or `hostile`; resolved for an ordered pair of combatants. |
| `NPC archetype` | Data-driven stats, AI, and visual mapping for an NPC. |
| `battle area` | A spawn area configured to maintain NPC populations and fight rules. |

## Relationship model

Resolve relationships in this priority order:

1. Explicit per-combatant override: `(source_combatant_id, target_combatant_id)`.
2. Temporary relationship effect, if active (quest, truce, event, party, etc.).
3. Faction-to-faction relationship: `(source_faction_id, target_faction_id)`.
4. Same combatant: always `friendly` and never a valid target.
5. Default: `neutral`.

Only `hostile` combatants are valid normal attack targets. `friendly` and
`neutral` damage must be rejected unless a future server-owned game mode
explicitly enables friendly fire. Relationship checks must occur at target
acquisition *and again* when each attack is resolved.

Relationships must be directional in storage and resolution. Configure the
initial two battle factions as mutually hostile in both directions, but do not
assume all relationships are symmetric.

## Initial content to register

Create these data-driven records for `application_id: wizards-wager`:

### Factions

| faction_id | display_name | default_player_relationship |
|---|---|---|
| `ironward` | Ironward | neutral |
| `emberclaw` | Emberclaw | neutral |

Register `ironward -> emberclaw` and `emberclaw -> ironward` as `hostile`.
Both factions are neutral to `player` initially; this lets a player watch the
battle without being attacked. The relationship table must be editable at
runtime so the frontend can later receive a faction that becomes hostile to the
player.

### NPC archetypes

Every archetype has its own dedicated NPC sprite sheet. Each sheet must follow
the same player-compatible visual contract: frame size/layout and the animation
names already used by the Godot project: `character_idle`, `character_walk`,
`character_attack`, `character_die`, and `character_power_up` where applicable.
This lets the frontend use one animation-loading/presentation framework for
players and NPCs while selecting a distinct texture for each NPC archetype.

The backend does not own texture files. It must publish a stable `visual_id`
that the client maps to a locally packaged dedicated NPC sprite sheet. The
`visual_id` is an asset identifier, not a color/tint or a reference to the
player asset.

| archetype_id | faction_id | visual_id | AI | Notes |
|---|---|---|---|---|
| `ironward_skirmisher` | ironward | `npc_ironward_skirmisher` | `battle` | Baseline melee fighter with its own sprite sheet. |
| `emberclaw_skirmisher` | emberclaw | `npc_emberclaw_skirmisher` | `battle` | Same baseline initially, with its own sprite sheet. |

Start both at the current Zombie melee baseline (movement, gravity, attack
windup/cooldown, range, knockback), with health, damage, experience, speed, and
AI parameters stored per archetype. Do not embed values in code: balancing
must be changed by configuration or migrations.

### Perpetual battle-area registration

Create a battle-area record and two faction spawn groups:

```text
application_id: wizards-wager
world_id: main_world
map_id: forest
battle_area_id: npc_faction_battle_1
enabled: true
combat_enabled: true
```

The level editor geometry is not yet available. Make the area's bounds,
ground/surface id, and the two spawn subregion bounds configuration fields. Do
not hard-code provisional coordinates. Once supplied, configure:

```text
ironward group:  archetype=ironward_skirmisher, desired_active=6, respawn=8s
emberclaw group: archetype=emberclaw_skirmisher, desired_active=6, respawn=8s
```

Each group must respawn independently until it reaches `desired_active`; a
dead NPC must respawn at a valid random point in only its own subregion. Spawn
selection must avoid solid geometry and avoid spawning immediately inside an
enemy attack range. The area remains active even if no player is nearby, unless
the existing world lifecycle explicitly pauses an entire map.

## Required authoritative simulation

### Combatant identity and state

Give every player and NPC a stable `combatant_id` with a `combatant_kind` of
`player` or `npc`. NPC IDs must survive a snapshot for the actor's lifetime;
an NPC gets a new ID only after death and respawn. Keep the existing player ID
and mob ID fields in compatibility payloads where required.

Every NPC has server-owned:

- faction, archetype, visual ID, display name, spawn group/area;
- position, velocity, facing, grounded state, health/max health, alive state;
- combat state (`idle`, `patrol`, `acquire`, `chase`, `attack`, `hit`, `dead`,
  `respawning`), target ID, cooldowns, windup, and last attacker;
- spawn origin/leash bounds and respawn time.

### Battle AI

Implement a `battle` AI behavior that:

1. Finds only alive, valid, hostile combatants on the same world/map.
2. Prioritizes a current valid target; otherwise chooses the nearest hostile.
3. Breaks ties deterministically (for example, lowest `combatant_id`) so
   simulation is reproducible.
4. Chases until in server-defined melee range and correct facing.
5. Applies the existing server-authoritative windup, cooldown, hit, knockback,
   death, and recovery rules.
6. Retargets when its target dies, leaves the map, becomes non-hostile, or
   exceeds leash distance.
7. Returns to its own subregion when no valid target exists or it exceeds its
   leash; it must not drift into the opposing spawn region while idle.

NPC-to-NPC attacks use the same validation and damage pipeline as NPC-to-player
attacks. Never have a client decide an NPC's target or submit NPC damage.

### Dynamic relationship updates

Provide an internal/admin/gameplay service for creating, replacing, expiring,
and removing faction and per-combatant relationship rules. This service is not
client-authoritative. On a relationship change:

- recompute affected NPC targets immediately or by the next simulation tick;
- cancel an in-progress attack that is no longer valid before its damage frame;
- publish relationship/state updates to clients in the affected map;
- persist finite-duration overrides with server expiration, and clean them up
  safely without depending on a connected client.

## Realtime protocol for the frontend

Introduce generic combatant events. The frontend will consume these for NPCs
and can later use the same data for remote-player PvP. Continue publishing the
existing player/mob events during migration so current Zombie/Goblin gameplay
does not break; do not make the client infer NPC relationships from colors.

### Snapshot

Include a `combatants` array in `world_snapshot` and `combatant_snapshot`:

```json
{
  "combatant_id": "npc:8fd1",
  "combatant_kind": "npc",
  "legacy_mob_id": "8fd1",
  "archetype_id": "ironward_skirmisher",
  "visual_id": "npc_ironward_skirmisher",
  "display_name": "Ironward Skirmisher",
  "faction_id": "ironward",
  "battle_area_id": "npc_faction_battle_1",
  "spawn_group_id": "npc_faction_battle_1:ironward",
  "position": {"x": 100, "y": 200},
  "velocity": {"x": 0, "y": 0},
  "health": 100,
  "max_health": 100,
  "state": "chase",
  "facing": 1,
  "grounded": true,
  "alive": true,
  "target_combatant_id": "npc:7ab2"
}
```

Never include hidden server combat values such as exact cooldown expiry,
damage, target scoring, or an NPC's future respawn point.

### Lifecycle and combat events

Publish these map-scoped events:

- `combatant_spawned` — complete initial combatant presentation state.
- `combatant_snapshot` — current state for one or more combatants.
- `combatant_damaged` — attacker/target IDs, damage, critical flag, remaining
  health, knockback, attack ID, and optional swing ID.
- `combatant_died` — target ID, killer ID if known, death position, and
  `respawn_at` only if revealing it is acceptable.
- `combatant_respawned` — complete presentation state for a newly active NPC.
- `combatant_relationship_changed` — source/target IDs or factions,
  resolved relationship, optional expiration, and revision.
- `battle_area_state` — enabled state plus desired/active counts per spawn
  group, suitable for debugging UI but not required for ordinary rendering.

The server must sequence each combatant's messages with a monotonically
increasing `revision` (or snapshot sequence) so the client can ignore
out-of-order updates. A reconnecting client receives a full `world_snapshot`
before applying deltas.

### Relationship presentation payload

For any combatant visible to a player, publish the relationship *as resolved
for that viewer*:

```json
{
  "viewer_combatant_id": "player:42",
  "target_combatant_id": "npc:8fd1",
  "relationship": "neutral",
  "revision": 18
}
```

This allows the client to choose UI markers (hostile red, neutral amber,
friendly green) without implementing game rules locally. Faction-to-faction
rules alone are insufficient once overrides and PvP teams exist.

### Player attack command

Add a generic, future-compatible command while retaining `attack_mob`:

```json
{
  "type": "attack_combatant",
  "data": {
    "target_combatant_id": "npc:8fd1",
    "attack_id": "player-attack-000123",
    "attack_type": "basic",
    "attack_swing_id": "basic-swing-4",
    "client_position": {"x": 175, "y": 424},
    "client_facing": 1
  }
}
```

Validate player life, map membership, target life, resolved hostility, server
range/facing, cooldown, stamina, attack IDs, and swing idempotency. Reject with
`attack_rejected` including a machine-readable `reason_code` such as
`not_hostile`, `out_of_range`, `invalid_target`, `target_dead`, or `cooldown`.
An accepted attack emits `attack_ack` and the appropriate generic combatant
damage/death events. `attack_mob` must continue to work against legacy mobs.

## Persistence and migrations

Add an up/down migration after the current latest migration for:

1. Factions and directed faction-relationship rules.
2. NPC archetypes, visual IDs, and data-driven combat/AI configuration.
3. Battle areas, spawn groups, bounds, population state, and respawn state.
4. Per-combatant relationship overrides, source, created/expiry timestamps,
   and a revision/version field.
5. Generic combatant event/idempotency records if they do not already exist.

Update bootstrap/repair registration as well as migrations, so a fresh
application gets the schema and baseline factions/archetypes. The down
migration must remove only these feature-owned records and must not delete
players, existing Zombie/Goblin rows, or unrelated world state.

## Acceptance tests

1. Twelve configured NPCs spawn as six Ironward and six Emberclaw fighters,
   each inside its own configured spawn subregion.
2. Each faction acquires and attacks only the other faction; neither attacks a
   neutral player.
3. NPC-to-NPC damage, knockback, death, and target loss are authoritative and
   visible through `combatant_*` events.
4. Death respawns only the affected faction's NPC after eight seconds, without
   exceeding each group's desired active count.
5. An NPC immediately stops pursuing/attacking when a directed relationship is
   changed from hostile to neutral or friendly.
6. A temporary override expires by server time and relationships/AI update
   correctly without client participation.
7. A player cannot damage a neutral/friendly NPC; an accepted hostile attack
   passes all existing range, facing, cooldown, stamina, and idempotency checks.
8. Snapshots plus out-of-order delta messages produce the correct final state
   on a reconnecting client.
9. Two viewers with different relationship overrides receive their own resolved
   relationship presentation for the same NPC.
10. Legacy Zombie/Goblin spawn, player attack, power-up, XP, death, and respawn
    tests remain passing.
11. The schema supports assigning individual player combatants or teams to
    factions, permitting future PvP without a new relationship or damage model.

## Frontend assumptions enabled by this request

The Godot frontend will build a single NPC presentation scene that maps each
`visual_id` to its dedicated, locally packaged NPC sprite sheet. Every sheet
uses the same frame layout and animation framework as the player, so the scene
can drive the shared `character_*` animation names from authoritative combatant
state. It may apply a faction/relationship marker or tint for readability, but
the marker is supplementary and never substitutes for a dedicated NPC texture.
It will not run NPC AI or locally decide whether damage is legal.
