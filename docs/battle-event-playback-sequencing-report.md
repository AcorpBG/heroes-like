# Battle Event Playback Sequencing Report

Date: 2026-05-23

## Status

Implementation evidence. Battle events already selected generated unit animation states, VFX placeholders, generated audio, and camera records, but newly observed cue records all started at the same board-side timestamp. This slice adds deterministic source-to-reaction sequencing metadata and uses event progress to select generated sheet frames during active event playback.

## What Changed

- `BattleBoardView` now stores `observed_at_msec`, `started_at_msec`, `expires_at_msec`, and `sequence_delay_msec` on active playback and cue records.
- Target reactions for hit, death, status, and retaliation receive a bounded positive sequence delay after the source action.
- Active event animation frame selection now derives from playback progress, so generated sheets advance according to the event window instead of only global wall-clock time.
- Delayed target audio cue records remain scheduled until their cue start rather than being treated as missing.
- `tests/battle_event_animation_state_report.tscn` proves ranged source cues start before target status cues and that delayed target audio carries positive sequencing metadata.

## Boundaries

This is deterministic presentation ordering for generated sheets and placeholder cue playback. It does not add final authored animation timing, imported audio or VFX assets, mixer polish, cinematic camera direction, save migration, combat balance tuning, or broad battle UI redesign.
