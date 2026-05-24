# Battle Event Presentation Shell Surface Report

Slice: `battle-event-presentation-shell-surface-20260524-10184`

This slice connects the existing battle animation event queue to the BattleShell dispatch surface, so resolved actions are visible as a first-class presentation cue outside the board renderer.

## Implementation

- Added `BattleRules.latest_animation_event_presentation_payload(...)` (`latest_animation_event_presentation_payload`), which selects the latest serialized battle animation event and turns it into compact player-facing cue text plus a validation-safe tooltip.
- Updated `BattleShell` to show the cue in the event/dispatch rail and expose the payload through `validation_snapshot()` as `battle_presentation_event`.
- Extended `tests/battle_event_animation_state_report.tscn` with a shell-level case that performs a real strike, opens `BattleShell`, and proves the cue is visible in the shell snapshot.

## Validation

- `tests/battle_event_animation_state_report.tscn` verifies rule payload generation, shell visibility, tooltip text, event id preservation, and actor/target names.
- `tests/validate_repo.py` gates the new rule, report, and documentation tokens.

## Non-Claims

No combat balance tuning. No final authored animation timing, final VFX art, final audio design, broad battle UI redesign, or new tactical mechanics are claimed by this slice.
