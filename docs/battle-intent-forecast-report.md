# Battle Intent Forecast Report

Slice: `battle-intent-forecast-20260523-10184`

## Scope

This slice adds a compact, testable battle intent forecast for the active order window. It is a UX and combat-feel surface over existing battle rules, not a final combat-balance pass or a new tactical AI policy.

## Runtime Behavior

- `BattleRules.intent_forecast_payload(...)` returns the preferred order, target, expected result, reason, likely hostile reply, score-confidence text, and tooltip copy.
- The forecast uses `BattleAiRules.choose_stack_tactical_order(...)` for the active player stack when possible, then falls back to the existing order surface.
- Attack forecasts use the live damage preview path, so visible consequences reflect current stack counts, commander modifiers, abilities, field objectives, terrain, and retaliation pressure.
- Enemy initiative returns a locked forecast that explains the incoming hostile action instead of implying that the player can act.
- Forecast inspection is read-only: it does not mutate selection, movement, initiative, or battle resolution state.

## UI Surface

`BattleShell` keeps the existing compact action-guide visible contract intact, then adds the intent forecast to the action-guide tooltip and validation snapshot. The battle screen remains scenery/board-first; the forecast is contextual detail rather than another permanent panel.

## Validation

`tests/battle_intent_forecast_report.tscn` proves:

- the adjacent ranged fixture prefers the scored melee `Strike` order over legacy shoot-first behavior;
- the forecast includes target, expected damage consequence, risk, confidence, and non-mutating inspection copy;
- enemy initiative locks the forecast as player input unavailable.

This improves player comprehension of the next tactical order. It does not claim final damage pacing, full encounter balance, final VFX/audio, or finished battle UX.
