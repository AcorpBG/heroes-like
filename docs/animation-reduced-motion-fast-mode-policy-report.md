# Animation Reduced-Motion And Fast-Mode Policy Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `animation-reduced-motion-fast-mode-policy-10184`.
Schema: `animation_playback_preference_policy_v1`.

## What Changed

- Added bounded cue playback preference helpers in `scripts/core/AnimationCueCatalog.gd`.
- Added `SettingsService.animation_preferences(...)` as a settings-shaped handoff for reduced-motion plus explicit fast-mode overrides without changing save data.
- Added `preference_policy` metadata to `content/animation_event_cues.json`.
- Added focused report coverage in `tests/animation_reduced_motion_fast_mode_policy_report.gd` and `tests/validate_repo.py --animation-policy-report`.

## Policy Coverage

Normal mode uses the authored animation state and catalog playback/blocking contract.

Reduced-motion mode selects each cue's `reduced_motion_tag`, suppresses large motion, camera motion, loop motion, and strong flash expectations, and keeps compact placeholder audio cue ids only.

Fast-mode selects each cue's `fast_mode_tag`, shortens duration budgets, preserves resolved event order, and relaxes routine blocking policies to fast resolution.

Combined reduced-motion and fast-mode uses reduced-motion visual fallbacks with fast-mode timing/blocking. This avoids forcing motion-heavy fallbacks when both accessibility and speed preferences are enabled.

The focused report proves this behavior for selected battle troop cues, selected overworld map object cues, and representative town, spell, artifact, and UI cues. Battle troop and overworld map object coverage is explicit so reduced-motion and fast-mode are not limited to UI microinteractions.

## Boundaries

- No save migration or save-version bump.
- No final sprite, VFX, or audio import.
- No renderer asset pipeline work.
- No final animation playback runtime.
- No broad UI polish or screen dashboard work.
- No terrain/editor/P2.9 work.
- No rare-resource activation or economy rebalance.
- `wood` remains canonical.

## Validation

Required validation paths:

- `python3 tests/validate_repo.py --animation-policy-report`
- `godot --headless --path . tests/animation_reduced_motion_fast_mode_policy_report.tscn`
- `godot --headless --path . tests/animation_event_cue_catalog_report.tscn`

These checks fail if representative policy coverage does not include battle troop, overworld map object, town, spell, artifact, and UI cues; if reduced-motion does not select reduced fallbacks; if fast-mode does not select fast fallbacks; or if combined mode does not use reduced visuals with fast timing.
