# Animation Battle Troop State Contract Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `animation-battle-cue-hook-vertical-slice-10184`.
Schema: `battle_troop_sprite_state_contract_v1`.

## What Changed

- Added explicit battle troop idle and retreat-style entries to `content/animation_event_cues.json`.
- Added `AnimationCueCatalog.battle_troop_sprite_state_contract_report(...)` to validate battle troop sprite state family coverage, representative event ids, producer refs, fallbacks, and cue playback policy selection.
- Added focused report coverage in `tests/animation_battle_troop_state_contract_report.gd` and `tests/validate_repo.py --animation-battle-troop-contract-report`.

## Contract Coverage

The bounded battle troop contract covers these sprite state families:

- idle
- ready
- move
- attack
- hit
- death
- cast
- status
- defend
- retreat

Representative events are limited to resolved battle troop cues with `subject_kind: troop_stack`. The report checks each representative event has battle/troop/resolved-event validation tags, producer references from current battle or spell rule producers, reduced-motion fallback tags, fast-mode fallback tags, and public-safe report payloads.

## Boundaries

- No save migration or save-version bump.
- No final sprite, VFX, or audio import.
- No renderer asset pipeline work.
- No final animation playback runtime.
- No broad UI polish or screen dashboard work.
- No overworld object contracts beyond existing catalog references.
- No terrain/editor/P2.9 work.
- No rare-resource activation or economy rebalance.
- `wood` remains canonical.

## Validation

Required validation paths:

- `python3 tests/validate_repo.py --animation-battle-troop-contract-report`
- `godot --headless --path . tests/animation_battle_troop_state_contract_report.tscn`
- `godot --headless --path . tests/animation_event_cue_catalog_report.tscn`
- `godot --headless --path . tests/animation_reduced_motion_fast_mode_policy_report.tscn`

These checks fail if required battle troop state families are missing, if representative event ids do not map to `troop_stack`, if producer refs or fallback tags are absent, or if reduced-motion/fast-mode policy selection breaks for the covered troop states.
