# Target Cycling Handoff

## Issue

Target cycling works while combatants are alive, but stops responding after the currently selected enemy is killed. The target panel closes, yet pressing Tab again does not select the next visible enemy. The same lifecycle may affect controller RB/LB cycling.

## Reproduction

1. Start the game and wait for visible enemies.
2. Press Tab to select an enemy.
3. Kill the selected enemy.
4. Confirm that the target panel closes.
5. Press Tab again.
6. Expected: the next visible enemy is selected and receives the target indicator.
7. Actual: no target is selected and cycling appears stuck.

## Relevant implementation

- Input entry point: `game.gd:125` (`_input`)
- Keyboard/controller handling: `game.gd:156` (`_handle_target_cycle_event`)
- Candidate selection: `game.gd:203` (`_cycle_target`)
- Target cleanup/indicator management: `game.gd:292` (`_set_current_target`)
- Server damage event: `game.gd:1121` (`_apply_authoritative_mob_damage`)
- Server death event: `game.gd:1129` (`_apply_authoritative_mob_death`)
- Snapshot-based removal: `game.gd:1162` (`_remove_authoritative_mob`)

## Current behavior flow

The selected enemy is stored in `current_target`. On lethal damage or death, the code calls `_clear_current_target_and_retarget()`, clears the status panel, waits one frame, and attempts to select the next candidate. A per-frame `_validate_current_target()` check also clears targets that are invalid, dying, or at zero health.

Despite those safeguards, the next Tab press still fails. This suggests the failure is probably not only stale target state. The next investigation should verify whether:

- `_handle_target_cycle_event()` is reached after the kill;
- `_visible_target_candidates()` still returns valid entities after removal;
- `get_viewport().set_input_as_handled()` or GUI focus is preventing later Tab events;
- the enemy removal/death event clears or rebuilds `$Enemies`/`authoritative_mobs` in a way that leaves no candidates;
- the target panel or target button changes input mode after it is closed.

## Important diagnostic logging

Add temporary logs at the start/end of `_handle_target_cycle_event()` and `_cycle_target()`:

```gdscript
print("target input: ", event, " current=", current_target)
print("target candidates: ", candidates.size(), " names=", candidates.map(func(item): return item.name))
```

Also log `authoritative_mobs.size()` and `$Enemies.get_child_count()` immediately before and after enemy death/removal. This will distinguish an input-delivery problem from a candidate-list problem.

## Previous fixes attempted

- Direct Tab/RB/LB handling was added in `_input`.
- GUI focus is released before cycling.
- Dead, dying, invisible, and off-screen entities are filtered out.
- The selected target indicator and status panel are cleared on lethal damage, death, and authoritative removal.
- Retargeting was deferred by one frame to avoid selecting an enemy before its death state was applied.
- A per-frame target validity check was added for stale/freed targets.

## Recommended next step

Instrument the input and candidate paths first, then test one of these controlled fixes depending on the logs:

1. If Tab is not received, move the cycle handling to `_unhandled_input()` or add a dedicated `InputMap` action handled from `_process`.
2. If Tab is received but candidates are empty, fix the authoritative mob/removal lifecycle or candidate visibility filtering.
3. If candidates exist but selection does not update, inspect `_select_target_entity()`, `PlayerStatusFrame.clear_target()`, and target indicator creation for a post-death state overwrite.
