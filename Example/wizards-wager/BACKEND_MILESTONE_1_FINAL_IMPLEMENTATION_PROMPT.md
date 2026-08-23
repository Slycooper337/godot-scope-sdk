# Backend Engineer: Implement Milestone 1 Against the Completed Frontend

Implement the authoritative backend for the complete Wizards Wager
new-player-to-faction vertical slice. Do not stop at a plan, schema, or partial
subsystem. Migrate, implement, test, and document the complete journey.

The frontend contract is complete and statically validated. The backend must
now make this flow playable:

> A new player starts in the sewer, completes three tutorial quests, exits into
> the central faction battle, kills either Knight faction to support its rival,
> reaches +100 reputation, commits to one faction, and completes that faction's
> guard-to-commander handoff.

## Frontend artifacts and versions

Canonical application and world:

```text
application_id: wizards-wager
world_id: main_world
```

Authored definitions:

```text
forest: published version 5
sewer: published version 1
```

The backend implementation must use the published JSON definitions supplied
with the frontend handoff. Reject stale versions and return the active
`map_version` in authoritative location and world state.

## Deliver the backend in four large steps

### 1. Activate and reconcile the authored world

Validate, persist, activate, and serve both published maps with their authored:

- physics surfaces;
- player spawns;
- combatant spawn groups;
- behavior profiles;
- quests and stages;
- quest givers;
- faction requirements;
- transitions.

Use a durable authored-runtime identity equivalent to:

```text
(application_id, world_id, map_id, published_map_version,
 authored_object_type, authored_object_id)
```

For combatant populations, the authored object ID is `spawn_id`.

Activation, restart, repair, and republish must never duplicate combatants,
quests, NPCs, transitions, or other active content. Activating a newer version
must transactionally stop the prior version from producing live content.
Historical rows may remain for audit.

Canonical location IDs:

| Purpose | Location |
|---|---|
| New player | `main_world/sewer/player_start` |
| Sewer return | `main_world/sewer/sewer_return` |
| Central battlefield arrival | `main_world/forest/central_battle_spawn` |

Never overwrite a valid saved location for an existing player. If a saved
location is invalid, atomically relocate the player to
`main_world/sewer/player_start`, persist an audit reason, increment
`location_revision`, and publish the repaired absolute location.

Canonical transitions:

```text
sewer_exit_to_forest
  main_world/sewer
  -> main_world/forest/central_battle_spawn
  proximity: 96
  requires: alive, tutorial_exit_unlocked, not_transition_locked
  one_way: true

forest_entrance_to_sewer
  main_world/forest
  -> main_world/sewer/sewer_return
  proximity: 96
  requires: alive, not_transition_locked
  one_way: true
```

Validate the player's authoritative position, map, life state, quest unlock,
and transition state. For this milestone, ordinary combat does not block
travel.

Transition commands use:

```text
(application_id, player_id, command_id)
```

as their durable idempotency identity. A retry returns the original result and
does not move the player twice.

### 2. Implement persistent authoritative quests

Implement a reusable authored quest engine supporting:

- availability and prerequisite evaluation;
- accept, decline, abandon, status, and completion;
- ordered stages;
- `kill` objectives by combatant archetype;
- `talk` and `interact` objectives by stable NPC ID;
- `use_transition` and `enter_map` objectives;
- XP, gold, and faction-reputation rewards;
- committed-faction requirements;
- persistence across death, reconnect, relog, restart, and deployment;
- idempotent commands and exactly-once rewards.

Only authoritative events advance objectives. The client never declares a
kill, objective update, completion, reward, location, or reputation change.

Use the authoritative killing blow for individual kill credit in this
milestone. Party/shared contribution is deferred.

Combatant death, credited player, XP, quest progress, reputation, and durable
outbox events must commit atomically.

Use:

```text
(application_id, player_id, combatant_id, death_revision)
```

as the death/reward idempotency identity. Increment `death_revision` when a
stable combatant respawns.

Canonical tutorial quests:

```text
sewer_first_hunt
  giver: sewer_guide
  stages:
    kill_sewer_zombies: kill 3 zombie
    return_after_zombies: talk to sewer_guide
  rewards: 20 XP, 10 gold

sewer_deeper_threats
  giver: sewer_guide
  prerequisite: sewer_first_hunt
  stages:
    kill_sewer_goblins: kill 3 goblin
    kill_sewer_skeletons: kill 3 skeleton
    return_after_deeper_threats: talk to sewer_guide
  rewards: 40 XP, 20 gold

sewer_find_exit
  giver: sewer_guide
  prerequisite: sewer_deeper_threats
  stage:
    enter_central_battlefield:
      use sewer_exit_to_forest
      arrive at forest/central_battle_spawn
  rewards: 20 XP, 10 gold
```

The authoritative transition commit completes `sewer_find_exit`.

Canonical faction quests:

```text
justice_report_to_commander
  giver: justice_starting_guard
  prerequisite: sewer_find_exit
  required committed faction: justice
  stages:
    speak_to_justice_guard
    talk_to_justice_commander
  rewards: 50 XP, 25 gold, +10 Justice reputation

avenger_report_to_commander
  giver: avenger_starting_guard
  prerequisite: sewer_find_exit
  required committed faction: avenger
  stages:
    speak_to_avenger_guard
    talk_to_avenger_commander
  rewards: 50 XP, 25 gold, +10 Avenger reputation
```

The validated interaction that accepts a guard quest may satisfy its first
guard-talk stage.

### 3. Implement initial faction choice

Initial state:

```text
justice_reputation: 0
avenger_reputation: 0
committed_faction_id: null
choice_locked: false
reputation range: -1000 through 1000
```

Neutral Justice and Avenger Knights are attackable only in the authored
central faction-choice battle area. Neutral NPCs are not globally attackable.
A legally attacked Knight may defend itself against the aggressor.

Rewards:

| Killing blow | Justice | Avenger | XP |
|---|---:|---:|---:|
| Justice Knight | -10 | +10 | 10 |
| Avenger Knight | +10 | -10 | 10 |

Store these as balance/content data.

Relationships:

| State | Relationship |
|---|---|
| -99 through 0 without commitment | neutral |
| +1 through +99 without rival commitment | friendly |
| committed faction | allied |
| at or below -100 | hostile |
| faction opposing commitment | hostile |

The first faction to reach +100 becomes:

```text
committed_faction_id: justice | avenger
choice_locked: true
```

Commitment remains locked until the later defection system exists. Raw
reputation cannot switch or clear it. The rival guard quest must return
`allegiance_conflict`.

Lock the player faction row during threshold processing. Concurrent updates
must result in exactly one committed faction.

Keep existing Knight-versus-Knight AI, physics, attacks, death, and respawning
working. Do not implement king reinforcement waves yet.

### 4. Complete realtime recovery and prove the slice

Support authenticated commands equivalent to:

```text
join_area
quest_interact
quest_accept
quest_decline
quest_abandon
quest_status
request_area_transition
```

Every mutating command includes a client-generated `command_id`. Validate
current map membership and proximity from server state, not client claims.

Publish focused events equivalent to:

```text
location_snapshot
player_location_changed
player_relocated
quest_state_snapshot
quest_offer
quest_accepted
quest_declined
quest_progress
quest_stage_advanced
quest_completed
quest_abandoned
quest_rejected
area_transition_approved
area_transition_rejected
area_transition_completed
player_faction_reputation_changed
player_faction_committed
```

Use independent monotonic revisions for:

- quest state;
- faction state;
- location state.

Every state-changing event must include enough absolute state to replace the
relevant client state. Login and reconnect must return:

- absolute location and position;
- `spawn_id`;
- active `map_version`;
- active, available, and completed quest state;
- objective progress;
- complete faction state;
- current XP, level, stats, and gold.

Quest snapshots and relevant events should include:

```json
{
  "quest_giver_states": [
    {"npc_id": "sewer_guide", "state": "available"}
  ]
}
```

Supported presentation states are:

```text
none
available
active
completable
```

Every combatant snapshot must include the receiving player's resolved
presentation state:

```json
{
  "faction_id": "justice",
  "relationship_to_player": "neutral",
  "attack_legal": true,
  "reputation_effects": {
    "justice": -10,
    "avenger": 10
  }
}
```

These fields help the frontend explain targeting. They do not replace backend
combat validation.

Use durable transactions, uniqueness constraints, idempotency records, and an
outbox or equivalent reliable event-delivery pattern. Do not rely on
process-local deduplication.

## Required test evidence

Provide unit, database integration, realtime protocol, restart/reconnect,
representative concurrency, and regression tests.

At minimum prove:

1. Forest version 5 and Sewer version 1 activate without duplicate content.
2. Restart, repair, and republish do not duplicate active populations.
3. A new player starts at `main_world/sewer/player_start`.
4. Existing valid saved locations remain unchanged.
5. Invalid saved locations are repaired and published.
6. All three sewer quests progress and reward exactly once.
7. Only authoritative killing blows grant individual kill credit.
8. Both transitions validate proximity/state and are idempotent.
9. The player arrives at the correct authoritative destination position.
10. Neutral Knight attacks are allowed only in the central choice area.
11. Knight kills apply XP and both reputation deltas exactly once.
12. The first faction to +100 becomes the only commitment.
13. Only the committed faction's guard quest is available.
14. Both guard-to-commander variants complete and reward correctly.
15. Reconnect at every major stage restores identical state.
16. Two players progress independently against shared authored populations.
17. Existing combat, stats, death, respawn, snapshots, ordinary enemies, and
    Knight-versus-Knight combat remain working.

Run a representative shared-area concurrency test. This is not final
200-player certification, but correct obvious duplicate simulation,
per-player polling, unbounded events, and database contention.

## Scope exclusions

Do not implement:

- full permadeath reset;
- defection or bounty payment;
- classes or spell trees;
- complex inventory;
- followers;
- resource nodes;
- crafting or trading;
- arena betting;
- king reinforcement waves;
- party/shared kill credit.

## Completion report

When finished, report:

- migrations and constraints;
- authored content activated;
- services and handlers implemented;
- final command and event payloads;
- rejection codes;
- transaction and idempotency boundaries;
- tests and results;
- concurrency conditions and results;
- deployment/configuration steps;
- any incomplete requirement and its exact blocker.

Do not report the milestone complete until the full sewer-to-faction-to-
commander journey passes.
