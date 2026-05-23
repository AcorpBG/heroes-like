# Headless Battle Difficulty Sweep Harness Report

Date: 2026-05-23
Slice: `headless-battle-difficulty-sweep-harness-20260523-10184`

## Purpose

The standalone battle difficulty sweep now proves that the current normal and hard launch rows are clear and still differ. This slice makes that evidence part of the shared headless simulation harness so routine headless balance runs catch difficulty-effect and queue-clear regressions.

## What Changed

- `HeadlessSimulationHarnessRules` now lists `battle_difficulty_sweep_sampling` as a required subsystem.
- The new `deterministic_battle_difficulty_sweep_samples` case wraps `battle_autoplay_difficulty_sweep_v1`.
- The case summary exposes row counts, sample limits, per-difficulty tuning queue status, per-difficulty queue signatures, `normal_vs_hard` deltas, and `sweep_signature`.
- `tests/headless_simulation_harness_report.gd` now asserts normal and hard rows both have `tuning_queue_status: clear`, `tuning_queue_item_count: 0`, passing combat-feel and balance-matrix gates, default sample breadth, and `no_observed_effect: false`.

## Current Evidence

- Headless subsystem: `battle_difficulty_sweep_sampling`
- Case id: `deterministic_battle_difficulty_sweep_samples`
- Sweep schema: `battle_autoplay_difficulty_sweep_v1`
- Sweep policy: `report_only_launch_difficulty_balance_probe`
- Expected current `sweep_signature`: `bc42c7b1`
- Current headless case signature: `f6e32bbf`
- Current headless harness signature: `56ae7622`
- Expected current normal queue signature: `829808c9`
- Expected current hard queue signature: `829808c9`
- Expected current normal and hard queue item count: `0`
- Expected current `tuning_queue_status: clear`
- Expected current `tuning_queue_item_count: 0`
- Expected current `no_observed_effect: false`

## Boundaries

- No new encounter retuning.
- No automatic tuning or authored content writeback.
- No final combat balance approval.
- No manual-play replacement or playable-alpha completion claim.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_difficulty_sweep_report.tscn
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
