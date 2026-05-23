# Battle Decision VFX Cue Coverage Report

Date: 2026-05-23
Slice: `battle-decision-vfx-cue-coverage-20260523-10184`

## Purpose

The battle cue catalog declared several placeholder VFX ids that were not mapped by `BattleBoardView`. This slice closes the remaining battle VFX mapper gaps for decision and fallback cues, then proves real defend and surrender events materialize their board VFX entries.

## What Changed

- `BattleBoardView` now maps `vfx_placeholder_idle_shadow` to `idle_shadow`.
- `BattleBoardView` now maps `vfx_placeholder_active_ring` to `active_ring`.
- `BattleBoardView` now maps `vfx_placeholder_brace_outline` to `brace_outline`.
- `BattleBoardView` now maps `vfx_placeholder_surrender_marker` to `surrender_marker`.
- `tests/battle_event_animation_state_report.gd` now asserts a real defend action emits `brace_outline` VFX.
- The same report now asserts a real surrender exit snapshot emits `surrender_marker` VFX.

## Boundaries

- No final imported VFX art.
- No final sound design.
- No combat balance tuning.
- No broad battle UX redesign.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/battle_event_animation_state_report.tscn
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
