# Animation Validation Smoke Harness Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `animation-validation-smoke-harness-10184`.
Schema: `animation_validation_smoke_harness_v1`.

## What Changed

- Added `AnimationCueCatalog.animation_validation_smoke_harness_report(...)` as a consolidated validation harness that reuses the event/cue catalog, reduced-motion/fast-mode policy, battle troop state contract, and overworld object state contract reports.
- Added focused Godot report coverage in `tests/animation_validation_smoke_harness_report.gd` and `.tscn`.
- Added `tests/validate_repo.py --animation-validation-smoke-report` coverage for the same smoke matrix.

## Smoke Coverage

The harness proves the existing reports are all ok, then resolves representative event ids across normal, reduced-motion, fast-mode, and combined reduced-motion/fast-mode policy:

- battle troop events: move, melee attack, death.
- overworld object events: captured, guarded, route-open.
- town events: captured and building built.
- spell events: battle cast and damage effect.
- artifact events: acquired and equipped.
- UI events: invalid action and resource delta.

The public payload is checked for blocked debug, score, and internal tokens. Runtime policy flags remain blocked for save migration, final asset imports, renderer asset pipeline work, playback runtime adoption, and broad UI polish.

## Boundaries

- No save migration or `SAVE_VERSION` bump.
- No final sprite, VFX, or audio import.
- No renderer asset pipeline work.
- No final playback runtime.
- No broad UI polish or dashboard surface.
- No P2.9 terrain/editor work.
- No rare-resource activation, economy rebalance, random map work, scenario migration, or AI rewrite.
- `wood` remains canonical.

## Validation

Required validation paths:

- `python3 tests/validate_repo.py --animation-validation-smoke-report`
- `godot --headless --path . tests/animation_validation_smoke_harness_report.tscn`
- the individual animation reports for cue catalog, reduced-motion/fast-mode policy, battle troop contracts, and overworld object contracts.
