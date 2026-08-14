# Battle Movement Path Presentation Report

Date: 2026-05-23

## Status

Implementation evidence. Battle movement already selected the `move_path_step` animation state, but the event did not preserve the stack's source and destination hexes. The board could only show movement at the final cell. This slice carries movement path context through the battle animation queue and uses it to draw a path ghost between the real start and destination cells.

## What Changed

- `BattleRules._resolve_move_action()` now records `from_q`, `from_r`, `to_q`, and `to_r` on `battle_unit_move` event records.
- Battle animation state and event-queue normalization preserve the movement path coordinates.
- `BattleBoardView` copies those coordinates into cue playback records and uses them for `vfx_placeholder_battle_path_ghost`.
- The move path ghost now spans the event source and destination cells instead of only pulsing on the final stack cell.
- `tests/battle_event_animation_state_report.tscn` now proves a real move action emits path coordinates and a distinct source-to-destination path ghost.
- The later `presentation-battle-state-path-vfx-asset-adoption-10184` slice maps the existing movement and withdrawal path cue ids to distinct original transparent textures while preserving these exact event coordinates and both procedural fallback paths.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

## Boundaries

This fixes movement path presentation context. It does not add interpolated stack-token travel, camera motion, final authored motion curves, particles/shaders, audio changes, or combat balance tuning.
