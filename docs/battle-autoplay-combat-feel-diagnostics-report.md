# Battle Autoplay Combat-Feel Diagnostics Report

Date: 2026-05-23

## Status

Implementation evidence. This slice expands the shared deterministic battle autoplay sampler so balance work has concrete combat-feel diagnostics instead of only outcome counts. The follow-up tactical order pass replaces the old shoot-first autoplay policy with shared battle-AI non-spell tactical scoring for player-side samples. The default sampler now uses a multi-scenario authored encounter set and reports scenario distribution so the standard harness no longer depends on a single scenario's narrow encounter list. The sampler also exposes a report-only combat-feel threshold gate through `combat_feel_gate`, turning obvious balance risks into structured warning/failure evidence without tuning content. It does not tune authored encounters, change unit stats, enable automatic tuning, or claim final combat balance.

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
  - sample count, requested sample limit, and scenario distribution;
  - average player and enemy damage dealt;
  - average total damage per round;
  - average terminal health margin;
  - average initial initiative spread;
  - action diversity, dominant action, and dominant-action percentage;
  - dominant outcome and dominant pacing-band percentages;
  - terrain, difficulty, pacing-band, role, and ability distributions.
- The aggregate sampler summary now includes `combat_feel_gate`, with `report_only_combat_feel_thresholds_v1` policy metadata and thresholds for:
  - sample breadth;
  - stalled samples;
  - invalid orders;
  - action diversity and dominant-action percentage;
  - damage per round;
  - terminal health margin;
  - outcome bias;
  - burst/grind/stalled pacing dominance.
- `BalanceRegressionReportRules` and `HeadlessSimulationHarnessRules` consume the same richer sampler output, so balance and headless evidence stay aligned.
- `tests/balance_regression_report_suite.tscn` and `tests/headless_simulation_harness_report.tscn` assert the new diagnostic fields.
- The balance and headless reports assert the threshold gate shape, policy id, warning/failure counts, threshold metadata, and alignment with the public summary metrics.
- Default balance/headless report sampling now spans `river-pass`, `causeway-stand`, `fen-crown`, and `stonewake-watch`, with focused tests asserting that the requested default sample count is reached across multiple authored scenarios.
- `BattleAiRules.choose_stack_tactical_order` exposes the same non-spell attack/advance/defend scoring used by runtime battle AI as a side-agnostic helper.
- `BattleAutoplayBalanceHarnessRules.player_autoplay_decision_report` uses that scoring to pick and apply a target before issuing player autoplay orders, and compact turn logs now include the scored autoplay decision.
- `tests/battle_autoplay_tactical_order_report.tscn` covers an adjacent ranged-stack case where both shoot and strike are available and verifies scored autoplay chooses melee strike instead of the legacy shoot-first order.

## Validation Evidence

Focused commands:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_tactical_order_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
```

Observed balance summary now includes requested sample limit, scenario distribution, terrain distribution, difficulty distribution, pacing-band distribution, role and ability distributions, average damage dealt, average damage per round, average terminal margin, action diversity, primary action percentage, dominant outcome percentage, dominant pacing-band percentage, and `combat_feel_gate`. Current focused samples surface `high_terminal_health_margin` as a structured warning, which is balance-triage evidence rather than an automatic retune. The tactical order fixture reports `battle_ai_nonspell_tactical_order_v1` with candidate score evidence.

## Boundaries

This is instrumentation for future tuning passes. Remaining combat work includes authored encounter retuning, stack-size pacing passes, ability-power adjustments, tactical AI quality work, terrain-value tuning, difficulty curve work, and manual playtest approval.
