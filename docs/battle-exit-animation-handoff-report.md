# Battle Exit Animation Handoff Report

Slice: `battle-exit-animation-handoff-20260523-10184`

Status: implementation evidence.

## Scope

Retreat and surrender already had animation states in `BattleRules`, but those actions immediately resolved the battle and cleared `session.battle`. That meant the events existed only transiently inside the rule call and could not be presented by `BattleBoardView`.

This slice preserves a pre-resolution presentation snapshot for exit actions and lets the battle shell show that snapshot briefly before routing to the overworld or outcome flow.

## Behavior

- Retreat actions emit `battle_unit_retreat` and preserve `retreat_withdraw_column` in `battle_exit_animation_snapshot`.
- Surrender actions emit `battle_unit_surrender` and preserve `surrender_stand_down` in `battle_exit_animation_snapshot`.
- `BattleBoardView.set_battle_presentation_snapshot(...)` renders the snapshot without requiring an active live battle payload.
- `BattleShell` disables battle inputs during the exit handoff, renders the snapshot, then routes after a short timer.
- The snapshot is action-result presentation data, not a save migration or durable battle-state replacement.

## Validation

`tests/battle_event_animation_state_report.tscn` now includes retreat and surrender cases. The report verifies that each exit action:

- returns the correct terminal state;
- includes `battle_exit_animation_snapshot`;
- carries the expected event id and animation state in the queue;
- can be rendered by `BattleBoardView` with active playback before expiry.

Focused command:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

## Remaining Gap

This closes the exit-action presentation gap for generated animation sheets. Final authored timing, camera work, imported VFX/audio assets, and combat-feel balance are still separate production work.
