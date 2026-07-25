# Backend Request: Authoritative Player Power-Up and Multi-Target Swings

## Goal

Support the Godot client's new player power-up:

- Activation costs 20 mana.
- Activation lasts 10 seconds.
- A normal basic-attack swing can damage one mob.
- A powered basic-attack swing can damage multiple distinct mobs in range.
- The server remains authoritative for mana, duration, range, cooldown, stamina, damage, and duplicate protection.

## Client protocol now emitted

### Activate

```json
{
  "type": "activate_power_up",
  "data": {
    "activation_id": "1915725675-123456789-1",
    "client_position": {
      "x": 175,
      "y": 424
    }
  }
}
```

The client sends this after `character_power_up` finishes. Do not trust a client-supplied cost or duration; the backend constants must be 20 mana and 10 seconds.

### Attack

Each target still receives a unique `attack_id`. Targets hit by the same animation share `attack_swing_id` and `power_up_id`.

```json
{
  "type": "attack_mob",
  "data": {
    "mob_id": "mob-a",
    "attack_id": "user-attack-000123",
    "attack_type": "basic",
    "power_up_id": "1915725675-123456789-1",
    "attack_swing_id": "1915725675-123456789-1-swing-4",
    "client_position": {
      "x": 175,
      "y": 424
    },
    "client_facing": 1
  }
}
```

Normal attacks send an empty `power_up_id`. Powered attacks send one `attack_mob` command per distinct overlapping mob.

## Required server changes

1. Add an `activate_power_up` realtime command in `api/internal/realtime/handler.go`.
2. Add server-owned power-up state keyed by application and player:
   - `active_power_up_id`
   - `power_up_expires_at`
   - processed `activation_id` for idempotency
3. In one transaction:
   - lock `player_progression`;
   - reject dead players, duplicate/conflicting activations, or mana below 20;
   - deduct exactly 20 mana once;
   - set expiry to server time plus 10 seconds;
   - return the authoritative remaining mana and remaining duration.
4. Extend `world.AttackInput` with:
   - `PowerUpID string`
   - `AttackSwingID string`
5. For every powered target, validate that:
   - `power_up_id` matches the player's active server record;
   - server time is before `power_up_expires_at`;
   - the player is alive and joined to the map;
   - the target is active, in range, and on the valid facing side under the existing combat rules;
   - the target has not already been processed for this player and `attack_swing_id`.
6. Charge basic-attack stamina and advance `last_basic_attack_at` once per `attack_swing_id`, not once per target. Additional valid targets in that same powered swing bypass the per-player basic cooldown and stamina charge, but still run range, state, damage, death, XP, and duplicate validation independently.
7. Normal attacks must retain current behavior and must not be allowed to use one swing ID to damage multiple mobs.
8. Keep each target's `attack_id` idempotent through `world_processed_attacks`. Add swing-level persistence/locking so concurrent target commands cannot double-charge resources or bypass the one-hit-per-mob-per-swing rule.
9. Clear active power-up state when the player dies. Expired state must never authorize another target, even if the client has not received an expiry event.

## Responses

Successful activation:

```json
{
  "type": "player_power_up_activated",
  "data": {
    "player_id": 1,
    "activation_id": "1915725675-123456789-1",
    "remaining_mana": 95,
    "remaining_seconds": 10,
    "expires_at": "2026-07-25T12:00:10Z"
  }
}
```

Rejected activation:

```json
{
  "type": "player_power_up_rejected",
  "data": {
    "player_id": 1,
    "activation_id": "1915725675-123456789-1",
    "remaining_mana": 15,
    "reason": "not enough mana"
  }
}
```

Optional expiry notification:

```json
{
  "type": "player_power_up_expired",
  "data": {
    "player_id": 1,
    "activation_id": "1915725675-123456789-1"
  }
}
```

Continue returning one `attack_ack`, `mob_damaged`, and—when applicable—`mob_died` per target. Include `power_up_id` and `attack_swing_id` in results for tracing.

## Acceptance tests

1. Activation at 20+ mana deducts exactly 20 and lasts 10 seconds by server time.
2. Activation below 20 mana is rejected without changing state.
3. Retrying the same `activation_id` never deducts mana twice.
4. A normal swing damages at most one mob.
5. One powered swing damages every distinct in-range submitted target.
6. A powered swing charges stamina and cooldown once, regardless of target count.
7. The same mob cannot be damaged twice by the same swing.
8. Out-of-range, wrong-map, dead, expired, or forged power-up requests are rejected.
9. Concurrent target commands remain race-safe and idempotent.
10. Death clears the power-up immediately; revival does not restore it.
11. Existing basic-attack, critical-hit, knockback, death, XP, and respawn tests continue to pass.
