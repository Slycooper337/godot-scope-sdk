# Backend Engineer Prompt: Dialogue and Storytelling Milestone

Implement the authoritative backend for the Dialogue and Storytelling Builder now present in the Wizards Wager Godot client. Treat this as an additive extension of Milestone 1 and the World Builder schema. Preserve all existing map, quest, faction, combat, idempotency, outbox, location-repair, and reconnect guarantees.

The Godot scene and `.tres` resources are designer-editable source files. Published map JSON is the server input. The server must never execute arbitrary script from authored content.

## Outcome

When complete, a player can interact with an authored NPC, receive the highest-priority eligible conversation, select only server-approved choices, persist story flags and consequences exactly once, recover the conversation after reconnecting, and play or skip client-side cinematic presentation without skipping authoritative results.

## Additive Published Map Schema

Accept these optional top-level collections:

- `dialogue_conversations`
- `story_flags`
- `cinematic_sequences`
- `cinematic_markers`

Existing maps that omit them remain valid.

Authored entries in `quest_givers` may add:

```json
{
  "default_conversation_id": "sewer_guide_repeat",
  "conditional_conversations": [
    {
      "entry_id": "sewer_guide_first_meeting",
      "conversation_id": "sewer_guide_intro",
      "priority": 100,
      "one_time": true,
      "condition_logic": "all",
      "conditions": []
    }
  ],
  "conversation_priority": 0,
  "one_time_greeting": "",
  "repeat_greeting": "",
  "ambient_lines": []
}
```

Conversation definitions contain stable IDs, `starting_node_id`, `player_may_exit`, `lock_local_input`, optional `default_cinematic_id`, and ordered nodes. Nodes contain speaker/text/presentation fields, `condition_logic`, conditions, actions, ordered choices, optional automatic next node, optional cinematic IDs, and end/intentional-loop flags. Choices contain stable IDs, text, destination, `condition_logic`, conditions, actions, disabled explanation, and confirmation requirement.

Story flags contain:

```json
{
  "flag_id": "justice_oath_response",
  "display_name": "Justice Oath Response",
  "value_type": "string",
  "default_value": "unanswered",
  "category": "faction_story",
  "visible_in_development": true
}
```

Cinematics contain ordered safe presentation cues. Markers contain authored map positions and framing data. Store the definitions with the activated map version and retire them atomically with that version.

## Allowed Conditions

Support only:

- `quest_not_started`
- `quest_active`
- `quest_stage`
- `quest_complete`
- `quest_failed`
- `faction_is`
- `faction_is_not`
- `reputation_at_least`
- `reputation_at_most`
- `level_at_least`
- `flag_is_set`
- `flag_is_not_set`
- `flag_value`
- `has_item`
- `lacks_item`
- `choice_selected`

Evaluate `condition_logic` as `all` or `any`, then apply each condition's `negated` value. Reject unknown condition types during publication.

## Allowed Actions

Support only:

- `set_flag`
- `clear_flag`
- `increment_flag`
- `offer_quest`
- `advance_quest`
- `complete_objective`
- `give_item`
- `remove_item`
- `give_gold`
- `give_experience`
- `change_reputation`
- `commit_faction`
- `start_cinematic`
- `transition_player`
- `end_conversation`

Validate references and value types during publication. Reuse the existing authoritative quest, inventory/economy, reputation, faction commitment, and location services. Do not create a second implementation of those rules. Never accept arbitrary methods, scripts, SQL, event names, or client-supplied action payloads.

## Persistence

Add durable, player-scoped storage for:

- typed story flag values and revision
- active dialogue session
- session map/version, NPC, conversation, and current node
- selected choice identities needed by `choice_selected`
- processed dialogue command identities
- applied node/choice action identities
- active cinematic presentation state if needed for recovery

Use typed columns or a validated value envelope for boolean, integer, and string flags. Enforce one value per player and flag ID. Defaults come from the active authored definition; do not eagerly write every default unless needed.

## Dialogue Session Rules

For `dialogue_interact`:

1. Validate authentication, current authoritative map membership, living/interaction state, NPC existence, and authoritative proximity.
2. Load the NPC from the player's active map version.
3. Evaluate conditional conversation entries by descending priority with stable authored order as the tie breaker.
4. Ignore a one-time entry already consumed by that player.
5. Use the default conversation only when no conditional entry is eligible.
6. Reject when no eligible conversation exists.
7. Create or resume one active player dialogue session.
8. Evaluate entry-node conditions and apply node-entry actions transactionally and exactly once.
9. Emit the authoritative node and server-computed choice availability.

For every node, return choices in authored order. Include unavailable choices when useful for UI, with `available: false` and a safe `disabled_explanation`. Never reveal secret server data in an explanation.

The server owns the current node. A client cannot name an arbitrary destination.

## Realtime Commands

Accept:

- `dialogue_interact`
  - `command_id`, `npc_id`, `map_id`
- `dialogue_choose`
  - `command_id`, `dialogue_session_id`, `conversation_id`, `node_id`, `choice_id`, `map_id`
- `dialogue_continue`
  - `command_id`, `dialogue_session_id`, `conversation_id`, `node_id`, `map_id`
- `dialogue_exit`
  - `command_id`, `dialogue_session_id`, `conversation_id`, `node_id`, `map_id`
- `cinematic_skip`
  - `command_id`, `dialogue_session_id`, `cinematic_id`, `map_id`
- `cinematic_presentation_complete`
  - `command_id`, `dialogue_session_id`, `cinematic_id`, `map_id`

Use existing durable command-id idempotency. Serialize concurrent commands per player/session. A repeated command returns or re-emits the same authoritative result without applying actions again.

Reject stale or mismatched session, conversation, node, choice, map, and activated-definition-version values.

## Realtime Events

Emit player-private events through the existing transactional outbox:

- `dialogue_started`
- `dialogue_state_snapshot`
- `dialogue_node_presented`
- `dialogue_choice_result`
- `dialogue_ended`
- `dialogue_rejected`
- `story_flags_snapshot`
- `story_flag_changed`
- `cinematic_started`
- `cinematic_cue`
- `cinematic_completed`
- `cinematic_interrupted`

Every event includes the appropriate monotonic revision:

- `dialogue_revision`
- `story_flags_revision`
- `cinematic_revision`

Node presentation should include:

```json
{
  "dialogue_session_id": "opaque-id",
  "conversation_id": "justice_commander_intro",
  "node_id": "start",
  "speaker_name": "Justice Commander",
  "text": "Authoritative authored text",
  "choices": [
    {
      "choice_id": "justice_is_duty",
      "text": "Justice means answering every wrong.",
      "available": true,
      "disabled_explanation": "",
      "requires_confirmation": true
    }
  ],
  "can_continue": false,
  "player_may_exit": true,
  "lock_local_input": true,
  "dialogue_revision": 1
}
```

## Transaction and Idempotency Boundary

Selecting a choice must atomically:

1. lock the player/session row;
2. verify command ID and current node;
3. reevaluate choice conditions against current authoritative state;
4. record the selected choice;
5. apply each authored action once using a stable identity derived from session, node, choice, and action ID;
6. advance to the authored destination or end the conversation;
7. increment revisions;
8. write resulting events to the outbox;
9. commit.

The same rule applies to node-entry actions. Never grant rewards before the transaction commits.

`cinematic_skip` skips presentation only. It must not roll back, bypass, or accelerate story actions. If an action is intended to happen after a cinematic, represent that as an explicit server-controlled continuation state.

## Cinematic Authority Split

The client may locally perform:

- input lock presentation
- camera save/restore/pan/follow/zoom
- holds, fades, text, title cards, and sounds
- visual facing and animation cues

The client must not authoritatively move an NPC. For `move_npc_to_marker`, validate the cue and use the world simulation to approve and broadcast any actual movement state. Camera-only markers are not world collision or teleport authority.

Completion, skip, interruption, disconnect, and map change must always lead to an unlocked player and restored camera on the client. Emit interruption/completion state so reconnect cannot strand a session.

## Publication Validation

Extend atomic map activation validation to reject:

- duplicate or missing conversation, node, choice, flag, cinematic, cue, or marker IDs
- missing starting/destination nodes
- missing speakers, quests, factions, flags, maps, spawns, cinematics, or markers
- unsupported conditions/actions/cues
- invalid flag type use
- unreachable dialogue nodes
- graphs without a reachable ending unless an intentional loop is marked
- permanent/economy/faction/transition choices without required confirmation
- cinematics that do not restore camera and input
- unsafe file paths for sounds

Cross-map transition actions must resolve against the same candidate world version set used by existing world validation.

## Recovery

On authenticated realtime recovery, send:

1. `story_flags_snapshot`;
2. the active `dialogue_state_snapshot`, if any;
3. active cinematic presentation state or a safe `cinematic_interrupted`;
4. existing quest, faction, location, and world snapshots.

The snapshot must contain enough information for the frontend to reconstruct the current node without replaying already-applied actions.

## Required Proof Content

Use the published authored definitions already in the frontend:

- Sewer Guide:
  - `sewer_guide_intro`
  - `sewer_guide_repeat`
  - `met_sewer_guide`
  - `learned_about_endless_war`
- Justice:
  - `justice_guard_neutral`
  - `justice_guard_allied`
  - `justice_commander_intro`
  - `justice_commander_repeat`
  - `justice_commander_met`
  - `justice_oath_response`
  - `justice_commander_audience`
- Avenger:
  - `avenger_guard_neutral`
  - `avenger_guard_allied`
  - `avenger_commander_intro`
  - `avenger_commander_repeat`
  - `avenger_commander_met`
  - `avenger_oath_response`
  - `avenger_commander_audience`

## Required Tests

Add publication, service, transaction, realtime, and recovery tests covering:

- all/any/negated conditions
- reputation and faction conversation selection
- typed flag persistence
- stale node and unavailable choice rejection
- duplicate command and concurrent choice execution
- exactly-once quest, inventory, gold, XP, reputation, and flag actions
- one-time conversations
- disconnect/reconnect recovery
- cinematic skip without consequence loss
- map version replacement while sessions exist
- malicious unknown condition/action/cue rejection
- existing Milestone 1 maps with no storytelling fields

Run `go test ./...`, `go vet ./...`, and `git diff --check`. Return the migration, core services, realtime handlers, canonical published content changes, tests, and an implementation note describing compatibility and recovery behavior.

