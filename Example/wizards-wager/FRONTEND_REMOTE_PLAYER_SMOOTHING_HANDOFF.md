# Frontend Engineering Handoff: Remote Player Smoothing

## Objective

Smooth the movement and animation of other connected player sprites in
`wizards-wager` without changing local-player responsiveness or mob rendering.

Remote players currently jump directly to every received position. Movement is
published approximately every 100 ms, so immediate packet application produces
visible 10 Hz stepping even when the game renders at a much higher frame rate.

The target implementation should buffer remote-player movement snapshots and
render slightly behind the newest packet, interpolating between known states.
Short packet gaps may use limited extrapolation. Teleports, respawns, and map
changes must snap immediately.

## Current implementation

Primary file:

```text
Example/wizards-wager/game.gd
```

Relevant code:

- `MOVEMENT_UPDATE_INTERVAL` is `0.1`, producing an intended 10 Hz send rate.
- `_process_movement_sync()` publishes local movement on
  `match/movement-test`.
- `_handle_movement_message()` immediately assigns:

  ```gdscript
  remote_entity.position = position
  remote_entity.rotation = rotation
  ```

- Remote animation is selected by comparing the previous packet position with
  the new packet position.
- `_create_remote_player()` dynamically creates the visual entity.
- `_remove_remote_player()` and `_clear_remote_players()` own cleanup.
- Remote sprite downloads are handled by `_ensure_remote_sprite()`.

Mob interpolation in `enemy_sprite.gd` is separate and should not be modified
for this task.

## Required design

Create a dedicated script:

```text
Example/wizards-wager/remote_player.gd
```

Attach it to every entity created by `_create_remote_player()`. The script
should own:

- Snapshot buffering
- Position and rotation interpolation
- Limited extrapolation
- Teleport detection
- Facing direction
- Movement animation transitions
- Stale packet handling

`game.gd` should remain responsible for:

- Sending the local player's movement
- Creating and removing remote entities
- Routing received movement packets to the correct remote player
- Loading remote sprite resources

## Movement packet contract

Extend the frontend-published movement payload while preserving all existing
fields:

```json
{
  "user_id": 7,
  "position": {
    "x": 175,
    "y": 424
  },
  "velocity": {
    "x": 220,
    "y": 0
  },
  "rotation": 0,
  "facing": 1,
  "grounded": true,
  "movement_state": "walk",
  "sequence": 42,
  "timestamp": 1785012345.125,
  "sprite_file_id": 123
}
```

The movement channel is a generic realtime relay, so these additional fields
are frontend protocol data and do not require a backend gameplay change.

Requirements:

- Maintain a local movement sequence counter and increment it for every
  successfully submitted movement update.
- Use sequence numbers to reject duplicate and out-of-order packets.
- Continue accepting older clients that omit velocity, facing, grounded state,
  movement state, or sequence.
- Do not use another player's wall-clock timestamp as the local render clock.
  Device clocks may differ. Record local monotonic arrival time with
  `Time.get_ticks_msec()`.
- Estimate velocity from consecutive positions when the packet does not contain
  velocity.

## Snapshot representation

Each remote player should retain a small ordered buffer. A snapshot should
contain at least:

```gdscript
{
    "sequence": 42,
    "received_at": 123.456,
    "position": Vector2(175, 424),
    "velocity": Vector2(220, 0),
    "rotation": 0.0,
    "facing": 1,
    "grounded": true,
    "movement_state": "walk"
}
```

Recommended limits:

```text
snapshot buffer size:       8
render delay:               0.12 seconds
maximum extrapolation:      0.18 seconds
teleport threshold:         250 pixels
remote stale timeout:       3 seconds
walk-enter speed:           15 pixels/second
walk-exit speed:            5 pixels/second
idle transition delay:      0.12 seconds
```

Expose these as exported variables on `remote_player.gd` so they can be tuned
without rewriting the interpolation logic.

## Snapshot ingestion

Implement a method similar to:

```gdscript
func push_movement_snapshot(data: Dictionary) -> void
```

Behavior:

1. Parse the incoming position and optional movement fields.
2. Record local monotonic arrival time.
3. Reject a packet when it has a sequence less than or equal to the most recent
   accepted sequence.
4. For legacy packets without a sequence, accept them in arrival order.
5. On the first packet, snap to its position and initialize the render state.
6. If the new position is more than the teleport threshold from the newest
   buffered position:
   - Clear the buffer.
   - Snap position and rotation.
   - Reset extrapolation and animation hysteresis.
7. Otherwise append the snapshot and keep only the newest configured number of
   entries.
8. Estimate velocity from position delta and arrival-time delta when velocity
   is absent.
9. Clamp unreasonable estimated velocity so a malformed or delayed packet does
   not launch the visual across the map.

Do not assign the remote entity's rendered position for every ordinary packet.
Packet ingestion updates the buffer; frame rendering moves the visual.

## Frame rendering

Run remote rendering every frame from `_process(delta)`.

Calculate:

```text
render_time = current_monotonic_time - snapshot_render_delay
```

Then:

### Interpolation

When two snapshots bracket `render_time`:

- Interpolate position with `Vector2.lerp()`.
- Interpolate rotation with `lerp_angle()`.
- Interpolate velocity for animation decisions.
- Use the newer snapshot's discrete fields such as grounded state and explicit
  movement state once the interpolation ratio crosses an appropriate boundary.

### Before the oldest snapshot

Use the oldest snapshot. This should occur only during initial buffer warm-up.

### After the newest snapshot

- Extrapolate position using the newest velocity.
- Limit extrapolation to `maximum_extrapolation`.
- After the limit, hold the last extrapolated position.
- Do not continue drifting indefinitely.

### Stale players

If no packet has arrived for the configured stale timeout:

- Stop extrapolation.
- Play idle unless an explicit non-looping action animation is active.
- Keep the entity until presence reports it offline or the existing cleanup
  path removes it.

## Animation and facing

Do not restart an animation every packet or frame.

Movement animation rules:

- Enter `character_walk` when smoothed horizontal speed exceeds the walk-enter
  threshold.
- Return to `character_idle` only after speed remains below the walk-exit
  threshold for the idle transition delay.
- Update `flip_h` only when horizontal velocity exceeds a small facing
  threshold.
- If velocity is effectively zero, retain the last facing direction.
- Prefer explicit packet facing when available.

Action priority:

```text
death/hit/attack/power-up > walk > idle
```

Movement updates must not interrupt explicit action animations. If action
animations are not yet replicated for remote players, structure the state
handling so they can be added later without replacing interpolation.

Changing a remote player's downloaded `SpriteFrames` must not clear its
snapshot buffer or snap its position.

## `game.gd` integration

### Sending

Update `_process_movement_sync()` to include velocity, facing, grounded state,
movement state, and sequence.

The local player's `CharacterBody2D.velocity` should be used directly.

Continue sending immediately when meaningful state changes occur, including:

- Starting or stopping movement
- Changing facing direction
- Jumping or landing
- Beginning a teleport or respawn

The existing 100 ms interval remains the regular movement cadence.

### Receiving

Update `_handle_movement_message()` so it:

1. Validates the user and position fields.
2. Creates the remote entity if needed.
3. Preserves remote sprite loading behavior.
4. Calls `push_movement_snapshot(movement)` on the remote-player component.
5. Does not directly assign position, rotation, animation, or facing.

### Creation

Update `_create_remote_player()` to instantiate the remote entity with
`remote_player.gd` attached. Preserve:

- Existing sprite frames and scale
- Z-index
- Name label
- Asynchronous profile-name loading
- Asynchronous custom sprite loading

### Cleanup

Ensure `_remove_remote_player()` and `_clear_remote_players()` remove all
snapshot and diagnostic state along with the entity.

## Teleports, respawns, and map transitions

Ordinary movement must interpolate. Discontinuous movement must snap.

Snap when:

- Distance from the latest snapshot exceeds the teleport threshold.
- A future movement packet explicitly includes a teleport or respawn flag.
- The remote player changes map.
- The remote entity is created for the first time.

Clearing the buffer during a snap prevents interpolation through walls or
between different vertical sections of the Forest map.

## Diagnostics

During development, track per-player or aggregate counters for:

- Packets received
- Packets rejected as old or duplicate
- Interpolated frames
- Extrapolated frames
- Teleport snaps
- Stale holds

Debug output should be disabled by default and controlled by an exported flag.
Do not print every movement frame in production.

## Implementation sequence

1. Add the richer outgoing movement fields and sequence counter.
2. Create `remote_player.gd` with snapshot ingestion and initial snapping.
3. Add delayed interpolation.
4. Add limited extrapolation and stale holding.
5. Move walk/idle and facing decisions into the remote-player script.
6. Add teleport detection and buffer resets.
7. Update creation, receiving, sprite loading, and cleanup integration.
8. Add debug counters and tune values under simulated latency.

## Acceptance tests

### Normal movement

- Two clients observe smooth remote walking at the existing 10 Hz packet rate.
- Local movement remains immediate and unchanged.
- Remote sprites do not visibly step between packet positions.

### Packet timing

- A 100–200 ms packet delay produces bounded extrapolation rather than a
  freeze followed by a large jump.
- A longer packet interruption stops movement instead of causing endless
  sliding.
- Out-of-order and duplicate sequence numbers do not move the sprite backward.

### Animation

- Walk animation does not restart on every packet.
- Idle/walk transitions do not flicker near zero velocity.
- Facing remains stable while stopped.
- Horizontal direction changes update facing smoothly and correctly.

### Discontinuous movement

- Teleports and respawns snap immediately.
- Players never interpolate between the lower Forest level and the Skeleton
  level.
- Rejoining or changing maps clears old buffered positions.

### Lifecycle

- Remote sprite customization can finish loading during movement without a
  position reset.
- Presence disconnect removes the remote entity and its buffered state.
- Reconnection creates a clean interpolation buffer.

### Compatibility

- Legacy movement packets containing only position and rotation still render.
- Mob interpolation and local-player movement are unchanged.
- No backend gameplay or authoritative combat behavior is modified.

## Definition of done

The work is complete when remote players render smoothly at normal frame rate
from the existing 10 Hz movement stream, tolerate short network jitter without
large corrections, stop safely during packet loss, snap correctly for
discontinuous movement, and maintain stable animations and facing.
