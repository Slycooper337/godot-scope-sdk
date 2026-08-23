# Backend Request: Correct Spawn Grounding Against Authored Surfaces

## Observed issue

In published Forest mode, enemies appear above the intended playable area and
then land on or inside a large ceiling/ground collision block. The visual
result shows mobs standing on the top of an unrelated rectangular surface while
the player is below it.

The current map contains large rectangular physics surfaces that represent
solid floors, ceilings, and structural blocks. A combatant spawn also carries an
explicit `surface_id` identifying the intended walkable surface.

## Required server behavior

When a spawn definition contains:

```json
{
  "surface_id": "ground_main",
  "placement_mode": "random_in_bounds",
  "position": {"x": 2220, "y": 290},
  "bounds": {"x": 2109.5, "y": 336}
}
```

the server must use `surface_id` to determine the spawn ground. It must not
choose the nearest, highest, first, or globally intersecting physics surface.

## Rectangle surface semantics

Please confirm and enforce the coordinate convention for rectangle surfaces.
The frontend currently exports rectangle `position` as the rectangle center and
`size` as its full dimensions:

```json
{
  "position": {"x": 7310, "y": 678.5},
  "size": {"x": 20384, "y": 329}
}
```

For a normal floor, the walkable top should be:

```text
top_y = position.y - (size.y / 2)
```

If the backend instead expects `position` to represent the top-left corner or
the walkable line, document that contract and update the validator/runtime
consistently. Do not mix center-based and top-edge semantics.

## Spawn placement requirements

For every authored spawn:

1. Resolve `surface_id` directly.
2. Determine the intended walkable side of that surface.
3. Choose an x coordinate within the authored spawn position/bounds.
4. Place the combatant just above the walkable top, accounting for body height.
5. Reject or clamp positions that begin inside the surface volume.
6. Apply normal gravity only after the initial spawn position is valid.
7. Do not allow an unrelated ceiling, block, or higher surface to become the
   spawn landing surface.

For `spawn_count > 1`, every generated position must use the same authored
surface reference and remain inside the authored bounds.

For `spawn_count = 1` with `placement_mode: fixed`, preserve the authored x
coordinate while grounding vertically against the referenced surface.

## Surface roles

The current map uses rectangles for floors, ceilings, platforms, and structural
blocks. Please add one of the following mechanisms so spawn grounding does not
interpret every solid rectangle as a candidate floor:

### Preferred: explicit surface role

Accept an optional field:

```json
"surface_role": "floor"
```

Supported values should include:

```text
floor
platform
ceiling
wall
solid
```

Only `floor` and `platform` surfaces should be eligible as default spawn
grounds. A spawn with an explicit `surface_id` may reference a configured
surface regardless of default eligibility, subject to validation.

### Alternative: explicit spawn-ground flag

Accept:

```json
"spawn_ground": true
```

and use only surfaces marked `spawn_ground` for grounded spawn selection.

## Validation requirements

The map validator should reject or warn when:

- a spawn references a missing `surface_id`;
- the referenced surface is not usable as a ground surface;
- the spawn bounds do not overlap the referenced surface horizontally;
- a fixed spawn is not horizontally compatible with its surface;
- the authored surface convention is ambiguous;
- the computed spawn point begins inside the referenced rectangle.

Return field-level diagnostics such as:

```json
{
  "path": "combatant_spawns[0].surface_id",
  "code": "spawn_surface_mismatch",
  "message": "spawn bounds do not overlap the referenced surface"
}
```

## Forest-specific checks

Please verify these authored relationships in published Forest mode:

```text
enemy_spawn_area_1 → ground_main
enemy_spawn_area_2 → ground_main
enemy_spawn_area_3 → ground_3
justice_knights_spawn → justice_ground
avenger_knights_spawn → avenger_ground
```

Confirm that the server uses those exact surfaces and does not substitute the
large `ground_upper*` rectangles.

## Runtime diagnostics

For each `mob_spawned` event in a debug or development mode, expose:

```text
spawn_id
surface_id
spawn_position
resolved_ground_y
resolved_surface_id
```

This will make it possible to compare the server’s spawn result with the map
definition and immediately identify coordinate or surface-selection errors.

## Acceptance criteria

1. Forest enemies spawn on the intended walkable surface, not on a ceiling or
   unrelated structural block.
2. Spawned actors never begin inside a physics rectangle.
3. Skeletons use `ground_3`.
4. Justice and Avenger NPCs use their respective battle ground surfaces.
5. Spawn positions remain inside their authored bounds.
6. Existing legacy mode behavior remains unchanged.
7. Published mode emits enough spawn metadata to diagnose future map errors.
