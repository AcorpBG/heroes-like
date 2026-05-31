# Battle Autoplay Expanded Sample Breadth Report

Date: 2026-05-23
Task: #10184

## Scope

This slice strengthens the automated combat-feel harness by widening the default deterministic battle autoplay gate from 6 samples to 12 samples. The goal is broader authored-encounter evidence before scaling scenarios and balance content, not final combat balance approval.

## Implementation

- `BattleAutoplayBalanceHarnessRules.DEFAULT_SAMPLE_LIMIT` is now `12`.
- `BattleAutoplayBalanceHarnessRules.DEFAULT_MINIMUM_SAMPLE_COUNT` is now `6`, so optional custom reports still warn on narrow authored coverage while the focused gates require the full default breadth.
- `tests/battle_autoplay_combat_balance_report.gd` now requires `requested_sample_limit >= 12` and `sample_count >= 12`.
- `tests/balance_regression_report_suite.gd` and `tests/headless_simulation_harness_report.gd` assert that shared reports use the expanded default sample limit.
- `tests/validate_repo.py` gates the expanded constants, report assertions, and this evidence document.

## Observed Evidence

The focused combat balance report now completes all 12 requested samples across four authored scenarios:

- `sample_count`: `12`
- `scenario_distribution`: `river-pass: 3`, `causeway-stand: 3`, `fen-crown: 3`, `stonewake-watch: 3`
- `distribution`: `defeat: 8`, `victory: 4`
- `action_diversity_count`: `4`
- `average_terminal_health_margin_pct`: `48`
- `average_total_damage_per_round`: `43`
- `combat_feel_gate.status`: `pass`
- `balance_matrix_gate.status`: structural pass; terminal-margin warnings remain report-only diagnostics.
- `terminal_margin_outliers`: retained as diagnostics rather than automatic failure conditions.
- `stalled_sample_count`: `0`
- `invalid_order_count`: `0`

## Non-Goals

- No automatic tuning or content writeback.
- No final combat balance approval.
- No broad encounter or campaign retune.
