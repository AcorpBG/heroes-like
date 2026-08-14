# Battle Death Animation Retention Report

Date: 2026-05-23

## Status

Implementation evidence. Battle rules already emitted `battle_unit_death` / `death_rout_remove`, but the board filtered defeated stacks out of its visible stack lists before playback could draw the death sheet row or stack-fade VFX. This slice keeps defeated stacks in the board presentation only while their active event playback record is alive, then lets them disappear after the normal playback expiry.

## What Changed

- `BattleBoardView` now treats zero-health stacks with active animation playback as transiently visible presentation stacks.
- Stack-cell assignment and visible-stack enumeration both use the same dynamic visibility filter, so expired defeated stacks do not keep occupying board presentation slots.
- `validation_unit_art_summary()` now reports `alive_count` and `event_playback_visible` for stack entries.
- `tests/battle_event_animation_state_report.tscn` now proves a real killing strike keeps the defeated target visible with `death_rout_remove`, `alive_count` 0, event-playback visibility, and `vfx_placeholder_stack_fade`.
- The later `presentation-battle-state-path-vfx-asset-adoption-10184` slice maps that established fade cue to an original transparent dissolve texture while preserving the exact retention lifetime and procedural missing-asset fallback.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

## Boundaries

This fixes death-event presentation retention. It does not add final authored death timing, camera or audio changes, particles/shaders, corpse persistence, or combat balance tuning.
