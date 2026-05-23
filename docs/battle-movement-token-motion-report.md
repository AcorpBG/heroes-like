# Battle Movement Token Motion Report

Date: 2026-05-23

## Status

Implementation evidence. Battle movement events already carried source and destination hexes and could draw a path ghost, but the stack token still rendered at the resolved destination for the whole playback window. This slice uses the same event path context to present the moving stack between its source and destination while the `battle_unit_move` playback record is active.

## What Changed

- `BattleBoardView` now computes a presentation center for active `battle_unit_move` records using `from_q/from_r`, `to_q/to_r`, and cue playback progress.
- Stack token drawing, health bars, count badges, captions, and click hit shapes use the presentation center during movement playback.
- Fast or reduced-motion animation modes snap movement presentation to the destination while normal playback interpolates along the event path.
- `validation_unit_art_summary()` exposes movement presentation fields for focused report coverage.
- `tests/battle_event_animation_state_report.tscn` now proves a real move action keeps the unit in `move_path_step`, draws the path ghost, and presents the token in transit rather than immediately at the destination.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

## Boundaries

This adds runtime token motion for resolved battle movement events. It does not add authored motion curves, per-unit locomotion timing, camera work, imported VFX/audio assets, or combat balance tuning.
