# Animation Event Cue Catalog Contract Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `animation-event-cue-catalog-contract-10184`.
Schema: `animation_event_cue_catalog_v1`.

## What Changed

- Added `content/animation_event_cues.json` as a bounded event/cue catalog for resolved gameplay events.
- Added `scripts/core/AnimationCueCatalog.gd` to validate the catalog and provide a small lookup helper for normal, reduced-motion, and fast-mode cue selection.
- Added focused report coverage in `tests/animation_event_cue_catalog_report.gd` and `tests/validate_repo.py --animation-cue-catalog-report`.

## Contract Coverage

The catalog maps representative gameplay event ids to animation state families, playback policy, blocking policy, placeholder VFX/audio cue ids, reduced-motion fallback tags, fast-mode fallback tags, validation tags, and current producer references.

Covered surfaces:

- battle troop sprite animation: move, melee/ranged attack, hit, death, cast, status apply/expire, defend, retaliation, active stack.
- overworld map object animation: visited, captured, depleted, blocked route, route-open, route-closed, low-cost ambient, hero route movement.
- town actions: building built and units recruited.
- spell events: battle cast, battle damage effect, overworld cast.
- artifact events: acquired, equipped, unequipped.
- UI/system cues: command confirmation, invalid action, resource delta, save written, load resumed.

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

- `python3 tests/validate_repo.py --animation-cue-catalog-report`
- `godot --headless --path . tests/animation_event_cue_catalog_report.tscn`

These checks fail if required fields are missing, if any required surface is absent, if reduced-motion or fast-mode fallback coverage is incomplete, or if the slice boundary flags indicate save migration, final asset import, renderer pipeline work, playback runtime adoption, or broad UI polish.
