# Battle Presentation Runtime Event Stream Report

Status: implementation evidence.
Date: 2026-05-30.
Slice: `battle-layout-smoke-followup-10184`.

## What Changed

- `BattleRules` now emits a structured `battle_presentation_events` queue alongside the existing animation event queue.
- The queue records readable combat consequences for movement, strikes, shots, spell casts, damage, healing, status buffs/debuffs, cleanse, resisted/immune spell outcomes, deaths, retaliation, morale/cohesion, and momentum.
- `BattleShell` consumes the queue in its dispatch surface and exposes it through `validation_snapshot()`.
- Battle playback speed is now live-selectable as normal, fast, or instant.
- `BattleBoardView` uses the selected speed to scale animation/cue timing while leaving battle resolution math unchanged.

## Validation

- `tests/battle_event_animation_state_report.tscn` validates:
  - structured presentation event stream generation;
  - shell consumption of the stream;
  - normal/fast/instant speed state wiring and fast board timing;
  - existing generated unit sheet, VFX, audio, camera, death, retaliation, movement, spell, status, retreat, and surrender cue playback;
  - real-unit Thornwake versus Veilmourn and Brasshollow versus Embercourt shell presentation smoke cases.

## Boundaries

- This slice does not retune combat math, unit stats, spell power, or AI decisions.
- The event stream remains runtime presentation state, not a save-schema migration.
- Final authored animation timing, final VFX, final audio mix, and cinematic direction remain later production work.
