# Backend handoff: Milestone 1 canonical sewer-to-faction contract

The previous handoff is superseded. Forest remains the main war map; sewer is a distinct authored map.

## Canonical location

- application: `wizards-wager`
- world: `main_world`
- new players: `main_world/sewer/player_start`
- existing players: restore the saved authoritative location without overwriting it
- forest destination: `main_world/forest/central_battle_spawn`
- sewer return: `main_world/sewer/sewer_return`

## Canonical transitions

`sewer_exit_to_forest` originates in `main_world/sewer` and targets `main_world/forest/central_battle_spawn`.
`forest_entrance_to_sewer` originates in `main_world/forest` and targets `main_world/sewer/sewer_return`.

Each definition must include `destination_spawn_id`, `required_proximity`, `required_player_state`, and `one_way`. The sewer exit requires `alive`, `tutorial_exit_unlocked`, and `not_transition_locked`; the forest entrance requires `alive` and `not_transition_locked`.

## Canonical quests

- `sewer_first_hunt`, giver `sewer_guide`: kill 3 zombies, then talk to `sewer_guide`.
- `sewer_deeper_threats`, prerequisite `sewer_first_hunt`: kill 3 goblins, kill 3 skeletons, then talk to `sewer_guide`.
- `sewer_find_exit`, prerequisite `sewer_deeper_threats`: use `sewer_exit_to_forest` and arrive at `forest/central_battle_spawn`.
- `justice_report_to_commander`: `justice_starting_guard` to `justice_commander`, requires justice faction.
- `avenger_report_to_commander`: `avenger_starting_guard` to `avenger_commander`, requires avenger faction.

Quest stages must support `kill`, `talk`/`interact`, `use_transition`, and `enter_map`, with stable NPC, transition, map, and spawn target IDs.

## Commands and revisions

Quest, interaction, and transition commands must include a client-generated `command_id`. Enforce durable idempotency on `(application_id, player_id, command_id)`.

Do not require the client to send a hard-coded map ID. Validate against the player’s current authoritative `world_map_id`.

Publish absolute state with independent revisions: `quest.revision`, `faction_state.revision`, and `location.location_revision`. A revision in one domain must never suppress an event in another.

Quest snapshots and relevant quest events should also include absolute quest
giver presentation state:

```json
{
  "quest_giver_states": [
    {"npc_id": "sewer_guide", "state": "available"}
  ]
}
```

Supported presentation states are `none`, `available`, `active`, and
`completable`. These values are presentation hints only; the backend must still
validate every interaction and quest command authoritatively.

Every authoritative combatant snapshot should include the receiving player's
resolved presentation contract:

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

`attack_legal` and `reputation_effects` are presentation data. The backend
remains responsible for validating attacks and awarding reputation.

The frontend expects location snapshots/events to provide `world_map_id`/`map_id`, `spawn_id`, and map definition version when available. It sends `join_area` only after receiving that authoritative location.

## Published frontend definitions

- `forest` published version: `5`
- `sewer` published version: `1`

The backend must reject stale definitions and return the active `map_version`
with location and world state.
