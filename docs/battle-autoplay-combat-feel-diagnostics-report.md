# Battle Autoplay Combat-Feel Diagnostics Report

Date: 2026-05-23

## Status

Implementation evidence. This slice expands the shared deterministic battle autoplay sampler so balance work has concrete combat-feel diagnostics instead of only outcome counts. It does not tune authored encounters, change unit stats, rewrite AI, or claim final combat balance.

## What Changed

- `BattleAutoplayBalanceHarnessRules` now records per-sample combat diagnostics:
  - terrain and encounter difficulty;
  - initial stack counts and unit counts by side;
  - ranged-stack counts;
  - role distribution;
  - ability id distribution;
  - initiative min, max, average, and spread;
  - player action mix and invalid-order count;
  - damage dealt by each side;
  - damage per round;
  - pacing band;
  - terminal health margin.
- The aggregate sampler summary now exposes:
  - average player and enemy damage dealt;
  - average total damage per round;
  - average terminal health margin;
  - average initial initiative spread;
  - action diversity, dominant action, and dominant-action percentage;
  - terrain, difficulty, pacing-band, role, and ability distributions.
- `BalanceRegressionReportRules` and `HeadlessSimulationHarnessRules` consume the same richer sampler output, so balance and headless evidence stay aligned.
- `tests/balance_regression_report_suite.tscn` and `tests/headless_simulation_harness_report.tscn` assert the new diagnostic fields.

## Validation Evidence

Focused commands:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
```

Observed balance summary now includes terrain distribution, difficulty distribution, pacing-band distribution, role and ability distributions, average damage dealt, average damage per round, average terminal margin, action diversity, and primary action percentage.

## Boundaries

This is instrumentation for future tuning passes. Remaining combat work includes authored encounter retuning, stack-size pacing passes, ability-power adjustments, tactical AI quality work, terrain-value tuning, difficulty curve work, and manual playtest approval.
