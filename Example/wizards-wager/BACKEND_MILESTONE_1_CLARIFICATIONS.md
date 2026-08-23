# Milestone 1 Backend Clarifications

## Purpose and authority

This document resolves the backend review of
`BACKEND_MILESTONE_1_PROMPT.md`. It is part of the Milestone 1 contract and
takes precedence where the original prompt was ambiguous.

The milestone remains one complete vertical slice. The engineer should deliver
it in dependency order with internal test gates, but should not stop after an
intermediate subsystem and present that as completion.

The required sequence is:

1. published authored content and runtime reconciliation;
2. authoritative quest state and player persistence;
3. faction combat, kill attribution, reputation, and allegiance;
4. guard-to-commander handoffs;
5. reconnect, restart, regression, and representative concurrency proof.

## 1. Existing-contract audit

Begin by verifying the current backend contracts for:

- application and player identity;
- published map definitions;
- runtime spawn activation and reconciliation;
- player progression;
- combatant death and kill attribution;
- faction relationships;
- realtime snapshots and focused events.

This audit is an implementation step, not a separate planning deliverable. If
published-mode activation or reconciliation can duplicate live populations,
fix and prove that foundation before attaching quest rewards to combatant
deaths.

## 2. Canonical world and content IDs

Use these stable IDs:

| Concept | Stable ID |
|---|---|
| Application | `wizards-wager` |
| World | `main_world` |
| Sewer map | `sewer` |
| Main war map | `forest` |
| New-player sewer spawn | `player_start` |
| Sewer return spawn | `sewer_return` |
| Central battlefield spawn | `central_battle_spawn` |
| Sewer guide | `sewer_guide` |
| Justice starting guard | `justice_starting_guard` |
| Justice commander | `justice_commander` |
| Avenger starting guard | `avenger_starting_guard` |
| Avenger commander | `avenger_commander` |
| Sewer exit transition | `sewer_exit_to_forest` |
| Sewer entrance transition | `forest_entrance_to_sewer` |

NPC and spawn coordinates are owned by the published map definition because
the frontend level author must place them against real geometry. The backend
must require and validate an explicit `position` and `surface_id` for every NPC
and destination spawn; it must not hard-code substitute coordinates.

The frontend and backend integration fixtures must use the same published test
definition so that proximity and placement are tested against actual authored
positions.

## 3. Published-map reconciliation

The stable authored-runtime reconciliation identity is:

```text
(application_id, world_id, map_id, published_map_version, authored_object_type, authored_object_id)
```

For combatant spawn populations, `authored_object_id` is `spawn_id`.

The same identity rule applies to authored quests, quest givers, transitions,
relationships, and other activated objects. Add database uniqueness protection
appropriate to each object type.

Activating a new published version must transactionally:

1. mark the previous version inactive for new runtime production;
2. reconcile or retire its live authored populations;
3. activate exactly one new version;
4. create or reconcile exactly one runtime representation per authored object;
5. remain safe when the publish/repair command is retried.

Historical definitions and runtime records may remain for audit, but an old
version must never continue spawning or offering active content after the new
version becomes authoritative.

## 4. New-player and invalid-location rules

A genuinely new character starts at:

```text
world_id: main_world
map_id: sewer
spawn_id: player_start
```

Never overwrite a valid saved position for an existing character.

If an existing saved location is invalid because its world, map, published
version, or spawn/surface no longer exists:

1. relocate the character to `main_world/sewer/player_start`;
2. persist the repaired location and a relocation audit reason in the same
   transaction;
3. increment the player's location revision;
4. include the repaired absolute location in the login/world snapshot;
5. emit `player_relocated` when the player is already connected.

The relocation payload must include the previous location when available, the
new world/map/spawn/position, `reason`, `location_revision`, and active
`map_version`.

## 5. Transition contract

Every authored transition contains:

```text
transition_id
origin_world_id
origin_map_id
destination_world_id
destination_map_id
destination_spawn_id
required_proximity
required_player_state
one_way
```

Milestone 1 transitions are:

### Sewer exit

```text
transition_id: sewer_exit_to_forest
origin: main_world/sewer
destination: main_world/forest/central_battle_spawn
required_proximity: 96 world pixels
required_player_state: alive, tutorial exit unlocked, not transition-locked
one_way: true
```

The tutorial exit unlocks after `sewer_deeper_threats` is complete and
`sewer_find_exit` is active.

### Sewer entrance

```text
transition_id: forest_entrance_to_sewer
origin: main_world/forest
destination: main_world/sewer/sewer_return
required_proximity: 96 world pixels
required_player_state: alive, not transition-locked
one_way: true
```

Together these are two explicit one-way transitions, allowing travel in both
directions without assuming that reversing an entrance is valid.

Transition commands include a client-generated `command_id`. The durable
idempotency identity is:

```text
(application_id, player_id, command_id)
```

A retry returns the original result. It must not apply the move twice.

A dead, dying, or already transitioning player cannot transition. For this
milestone, ordinary combat does not block a valid transition; proximity and
alive state still apply. This can be tightened later if combat escape becomes a
problem.

The server validates authoritative player position, never the client-reported
position.

## 6. Kill contribution and atomic rewards

Milestone 1 uses the **last valid player attacker**, equivalent to the
authoritative killing blow, for individual kill credit.

The credited player must:

- have a valid server-accepted damaging attack recorded against the victim;
- be in the same authoritative map/area;
- still identify a valid application player;
- be the player whose accepted damage caused health to reach zero.

NPC killing blows do not grant a player quest progress or player-caused faction
reputation. Party/shared and damage-threshold credit are deferred until party
rules exist.

Combatant death, experience, quest progress, reputation changes, and their
outbox/realtime records must commit atomically.

The durable death/reward idempotency identity is:

```text
(application_id, player_id, combatant_id, death_revision)
```

Respawning the same stable combatant must increment `death_revision`.

## 7. Reputation and relationship rules

Initial state:

```text
justice_reputation: 0
avenger_reputation: 0
committed_faction_id: null
choice_locked: false
```

Reputation range:

```text
minimum: -1000
maximum: 1000
```

Central-battle Knight killing rules:

| Player kills | Justice change | Avenger change | XP |
|---|---:|---:|---:|
| Justice Knight | -10 | +10 | 10 |
| Avenger Knight | +10 | -10 | 10 |

These values must be stored as balance/content data rather than duplicated as
runtime constants.

Relationship presentation:

| State | Relationship |
|---|---|
| Reputation from -99 through 0, no commitment | neutral |
| Reputation from +1 through +99, no rival commitment | friendly |
| Committed faction | allied |
| Reputation at or below -100, or faction opposing the commitment | hostile |

A neutral Knight that receives a legal player attack may defend itself against
that aggressor immediately. This temporary combat target does not globally
change the player's faction relationship. Existing same-faction assist
behavior may be retained if it is bounded and server-authoritative; do not add
a new global reinforcement system in this milestone.

Neutral-player attacks against Justice and Avenger Knights are legal only in
the authored central faction-choice battle area. Neutral attacks elsewhere
remain illegal unless an authored combat rule explicitly permits them.

## 8. Allegiance semantics

The first faction to reach +100 reputation establishes commitment:

```text
committed_faction_id: justice | avenger
choice_locked: true
```

Commitment is locked for Milestone 1. It can later be changed only through the
explicit defection/bounty system described in the scope. That later workflow
is not part of this milestone.

After commitment:

- the committed faction remains allied even if its raw reputation later falls
  below +100;
- the rival faction is treated as hostile;
- the committed faction's guard quest can become available;
- the rival guard quest is rejected with `allegiance_conflict`;
- ordinary reputation changes continue within the configured range;
- raw reputation alone cannot switch or clear commitment.

The commitment transaction must lock the player faction-state record. If
concurrent rewards would place both factions at +100, the first committed
transaction wins and the later transaction applies its allowed reputation
delta without changing commitment. Emit one authoritative committed faction.

The normal symmetric Knight-kill rules should make both sides reaching +100
unlikely, but the backend must still handle admin adjustments and quest rewards
deterministically.

## 9. Authored quest content

All rewards below are initial balance data and must remain editable without
changing quest-engine code.

### Quest: First Hunt

```text
quest_id: sewer_first_hunt
giver_npc_id: sewer_guide
repeatable: false
prerequisites: none
availability: no committed faction required
```

Stages:

1. `kill_sewer_zombies`: kill 3 combatants with archetype `zombie`.
2. `return_after_zombies`: talk to `sewer_guide`.

Completion rewards:

```text
experience: 20
gold: 10
```

Offer text:

> The dead keep crawling in through the lower tunnels. Put down three Zombies
> and come back alive.

Completion text:

> Good. You can handle yourself, but the deeper tunnels are worse.

### Quest: Deeper Threats

```text
quest_id: sewer_deeper_threats
giver_npc_id: sewer_guide
repeatable: false
prerequisite: sewer_first_hunt
```

Stages:

1. `kill_sewer_goblins`: kill 3 combatants with archetype `goblin`.
2. `kill_sewer_skeletons`: kill 3 combatants with archetype `skeleton`.
3. `return_after_deeper_threats`: talk to `sewer_guide`.

Completion rewards:

```text
experience: 40
gold: 20
```

Offer text:

> Goblins are stripping the old passages, and Skeletons guard the way out.
> Clear three of each.

Completion text:

> The surface route is open. What waits above is worse than anything down
> here—and it can choose whom to hate.

### Quest: Find the Surface

```text
quest_id: sewer_find_exit
giver_npc_id: sewer_guide
repeatable: false
prerequisite: sewer_deeper_threats
```

Stages:

1. `enter_central_battlefield`: use transition
   `sewer_exit_to_forest` and arrive on map `forest` at
   `central_battle_spawn`.

This quest completes automatically after the authoritative transition commits.

Completion rewards:

```text
experience: 20
gold: 10
```

Offer text:

> Take the ladder to the surface. Stay near the center until you understand
> the war you are walking into.

### Justice quest: Report to the Commander

```text
quest_id: justice_report_to_commander
giver_npc_id: justice_starting_guard
repeatable: false
prerequisite: sewer_find_exit
required_committed_faction_id: justice
```

Stages:

1. `speak_to_justice_guard`: interact with `justice_starting_guard` to accept.
2. `speak_to_justice_commander`: talk to `justice_commander`.

Completion rewards:

```text
experience: 50
gold: 25
justice_reputation: 10
```

Guard offer text:

> Your actions have reached the commander's ears. Report to the Justice
> warfront command post.

Commander completion text:

> You chose justice through action. Now prove you can serve it with discipline.

### Avenger quest: Report to the Commander

```text
quest_id: avenger_report_to_commander
giver_npc_id: avenger_starting_guard
repeatable: false
prerequisite: sewer_find_exit
required_committed_faction_id: avenger
```

Stages:

1. `speak_to_avenger_guard`: interact with `avenger_starting_guard` to accept.
2. `speak_to_avenger_commander`: talk to `avenger_commander`.

Completion rewards:

```text
experience: 50
gold: 25
avenger_reputation: 10
```

Guard offer text:

> The commander knows what you did for our fallen. Report to the Avenger
> warfront command post.

Commander completion text:

> You answered blood with vengeance. Now show us you have the strength to
> endure the war.

NPC interaction commands must validate authoritative map membership and
proximity. Use an authored default interaction distance of 96 world pixels.

## 10. Realtime and recovery contract

Focused events may describe what changed, but every quest/faction event must
also contain enough absolute state to replace the relevant client state.

At minimum:

```json
{
  "event_type": "quest_progressed",
  "player_id": 123,
  "quest": {
    "quest_id": "sewer_first_hunt",
    "status": "active",
    "stage_id": "kill_sewer_zombies",
    "stage_index": 0,
    "objective_progress": {
      "current": 2,
      "required": 3
    },
    "revision": 4
  },
  "faction_state": {
    "committed_faction_id": null,
    "choice_locked": false,
    "standings": [],
    "revision": 7
  },
  "location": {
    "world_id": "main_world",
    "map_id": "sewer",
    "map_version": 5,
    "location_revision": 3
  }
}
```

Use per-domain monotonic revisions at minimum for quest state, faction state,
and location state. The client ignores an older revision for that domain.

Login and world join return:

- absolute current location;
- active published map version;
- complete active and available quest state;
- completed quest IDs needed for prerequisites;
- complete faction state;
- current player progression and rewards.

This snapshot must match the state recoverable from committed events.

## 11. Required test evidence

Organize the requested proof into:

- unit tests for rules and authored-definition validation;
- database integration tests for transactions, uniqueness, persistence, and
  idempotency;
- realtime protocol tests for snapshots, events, ordering, and stale revisions;
- restart/reconnect tests at every major player-journey boundary;
- representative concurrency tests for shared populations and independent
  player progress.

The shared-area concurrency case must include at least two players fighting the
same authored population. Verify that:

- one live population exists per authored spawn;
- each death has one authoritative death revision;
- only the killing-blow player receives individual XP, quest credit, and
  player-caused faction reputation;
- quest and faction state never crosses between players;
- reconnecting either player restores that player's exact state;
- restart and republish do not duplicate active entities or rewards.

## 12. Completion gate

Milestone 1 is complete only when all of the following are demonstrated:

1. One active published map version produces one live population per authored
   spawn ID.
2. Restart, repair, and republish do not duplicate active entities or content.
3. A new player starts at `main_world/sewer/player_start`.
4. The player can complete all three sewer quests and transition through
   `sewer_exit_to_forest`.
5. The player can legally attack either Knight faction in the central battle.
6. Knight killing applies XP and both reputation deltas exactly once.
7. The first faction to +100 becomes the one committed faction.
8. Only the committed faction's guard quest can be accepted.
9. Both faction variants can complete their guard-to-commander handoff.
10. Reconnecting after every stage restores identical quest, faction, location,
    progression, and reward state.
11. Two players can progress independently against the same shared authored
    populations.
12. Existing combat, stats, death, respawn, world snapshots, and enemy behavior
    pass regression testing.

