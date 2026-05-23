# Battle Autoplay Balance Matrix Diagnostics Report

Slice: `battle-autoplay-balance-matrix-diagnostics-20260523-10184`

## Scope

This slice expands the deterministic battle autoplay harness with report-only balance matrix diagnostics. It does not automatically tune units, rewrite encounters, change authored content, or claim final combat balance approval.

## Implemented Gate

- `BattleAutoplayBalanceHarnessRules` now records initial side power, side role maps, side ability maps, and matchup bands for every autoplay sample.
- The shared sampler summary now includes `balance_matrix` using schema `battle_autoplay_balance_matrix_v1`.
- Matrix cohorts cover difficulty, terrain, scenario, army matchup, and ability presence.
- Cohort rows expose sample count, completed count, outcome distribution, pacing distribution, action distribution, average terminal health margin, average round reached, and average total damage per round.
- `balance_matrix_gate` uses policy `report_only_balance_matrix_thresholds_v1` to surface coverage gaps and high terminal-margin outliers without content writeback.
- The focused combat balance report, balance regression suite, and headless simulation harness assert the new matrix evidence.

## Current Evidence

The default authored autoplay sample set currently covers:

- difficulty cohorts: `low`, `medium`, `high`;
- terrain cohorts: `forest`, `grass`, `mire`;
- scenario cohorts: `river-pass`, `causeway-stand`;
- matchup cohorts: `even`, `player_advantaged`;
- ability-presence cohorts for the sampled roster abilities.

The current focused balance and shared harness reports require the default matrix gate to pass without terminal-margin warnings. The calibrated sample set currently reports `terminal_margin_outliers: []` and `balance_matrix_gate.status: pass`, so new extreme terminal-health-margin samples are treated as regressions in these reports.

## Validation Commands

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
```

This is balance instrumentation for future tuning passes. Final combat feel, authored encounter retuning, AI quality, and full automated balance approval remain open.
