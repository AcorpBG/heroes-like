# Battle Autoplay Runtime Consequence Matrix Report

Date: 2026-05-23  
Slice: `battle-autoplay-runtime-consequence-matrix-20260523-10184`

## Purpose

The prior runtime consequence harness proved that sampled battles produce status, ability, and spell consequences in aggregate. This report adds cohort evidence so combat tuning can see where those consequences appear across authored battle samples instead of relying on one global count.

## Implementation

- `BattleAutoplayBalanceHarnessRules.build_sampling_report()` now emits `runtime_consequence_matrix`.
- Matrix schema: `battle_autoplay_runtime_consequence_matrix_v1`.
- Gate policy: `report_only_runtime_consequence_matrix_thresholds_v1`.
- Cohorts: difficulty, terrain, scenario, matchup, and ability presence.
- Each cohort records sample counts, status consequence samples, ability consequence samples, spell consequence samples, event/effect ids, source-type evidence, active-effect counts, and deterministic cohort signatures.
- The gate fails on missing sections, zero-consequence samples, missing status consequence evidence in a cohort, or no ability-presence cohort with observed ability runtime consequences.

## Current Evidence

- `runtime_consequence_matrix_gate.status`: `pass`
- `matrix_signature`: `cab8ca24`
- `sample_count`: `12`
- `difficulty_cohort_count`: `3`
- `terrain_cohort_count`: `3`
- `scenario_cohort_count`: `4`
- `matchup_cohort_count`: `2`
- `ability_presence_cohort_count`: `8`
- `ability_consequence_cohort_count`: `8`
- `zero_consequence_sample_count`: `0`

## Boundaries

This is report-only balance instrumentation. It does not retune encounters, change unit abilities, change spell rules, add player-facing UI, or claim final combat balance. No final combat balance.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_runtime_consequence_matrix_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_runtime_consequence_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
