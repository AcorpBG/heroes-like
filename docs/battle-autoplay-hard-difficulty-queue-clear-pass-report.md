# Battle Autoplay Hard Difficulty Queue Clear Pass Report

Date: 2026-05-23  
Slice: `battle-autoplay-hard-difficulty-queue-clear-pass-20260523-10184`

## Purpose

The previous hard difficulty pass accepted a bounded queue budget while keeping the normal battle-autoplay queue clear. This pass resolves the remaining hard launch row watches and tightens the deterministic difficulty sweep so hard mode must stay clear.

## What Changed

- `river_pass_hollow_mire` now uses placement-local `army_river_pass_hollow_mire_watch` instead of the shared full Mireclaw pack.
- `causeway_reed_camp` now uses placement-local `army_causeway_reed_camp_pickets` instead of the shared Reedward camp roster.
- `tests/battle_autoplay_difficulty_sweep_report.gd` now records `tuning_queue_top_contributors` in compact row output.
- The hard difficulty gate now requires `MAX_HARD_TUNING_QUEUE_ITEMS := 0`.

## Baseline

- Prior hard queue signature: `8a238ca3`
- Prior hard queue item count: `3`
- Top contributors were a hard `player_advantaged` terminal-margin watch, `river_pass_hollow_mire` terminal-margin watch, and `causeway_reed_camp` burst-pacing watch.

## Current Evidence

- `sweep_signature`: `bc42c7b1`
- Normal row queue signature: `829808c9`
- Normal row `tuning_queue_item_count`: `0`
- Normal row status: `clear`
- Hard row queue signature: `829808c9`
- Hard row `tuning_queue_item_count`: `0`
- Hard row status: `clear`
- `normal-vs-hard` keeps an observed effect: enemy remaining health delta `20`, player remaining health delta `-12`, terminal margin delta `8`, total damage per round delta `2`, primary outcome percentage delta `17`, and `no_observed_effect: false`.

## Boundaries

- No broad faction rebalance.
- No automatic tuning or content writeback.
- No final combat balance approval.
- No campaign or random-map generation parity claim.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_difficulty_sweep_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_balance_tuning_queue_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_runtime_consequence_matrix_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_runtime_consequence_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
