# Battle AI Withdrawal Decision Report

Slice: `battle-ai-withdrawal-decision-20260523-10184`

## Scope

Enemy tactical battle AI now has a focused force-preservation scorer, `battle_ai_enemy_withdrawal_decision_v1`, for clearly losing non-town field battles. It can choose `retreat` or `surrender` when the battle exit is allowed, while leaving player autoplay on the existing non-spell tactical order scorer.

The runtime enemy turn resolver handles those choices directly instead of falling through to attack/advance fallback behavior. Enemy retreat and surrender mark enemy-side exit animation events before finalization, preserve a `battle_exit_animation_snapshot`, clear the battle, and record `enemy_retreat` or `enemy_surrender` as the last battle outcome.

## Guardrails

- No player autoplay withdrawal.
- No final combat balance approval.
- No broad strategic AI rewrite.
- No new economy/reward model for enemy surrender.
- Town-defense and town-assault contexts remain locked out of enemy withdrawal decisions.

## Validation

`tests/battle_ai_withdrawal_decision_report.tscn` covers:

- retreat selection with `retreat_allowed=true`;
- surrender selection with only `surrender_allowed=true`;
- locked withdrawal in town-defense context;
- runtime enemy retreat preserving `battle_exit_animation_snapshot` with `battle_unit_retreat` / `retreat_withdraw_column`.

This is a narrow tactical-AI behavior increment. It does not approve final combat pacing, encounter difficulty, or strategic campaign AI quality.
