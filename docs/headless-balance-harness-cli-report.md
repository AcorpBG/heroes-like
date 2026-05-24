# Headless Balance Harness CLI Report

Slice: `headless-balance-harness-cli-20260523-10184`

This slice adds `tools/run_headless_balance_harness.py`, a single command for running the existing Godot headless balance and simulation reports and writing stable artifacts under `.artifacts/headless_balance_harness_cli/`.

## What It Runs

The default `standard` suite runs:

- `tests/battle_autoplay_combat_balance_report.tscn`
- `tests/battle_autoplay_active_scenario_breadth_report.tscn`
- `tests/balance_regression_report_suite.tscn`
- `tests/headless_simulation_harness_report.tscn`

The `full` suite also runs the difficulty sweep, runtime consequence matrix, and tuning queue report scenes.

## Artifact Contract

The runner writes:

- one log per case;
- `manifest.json` with schema `headless_balance_harness_cli_v1`;
- per-case command, marker, exit code, duration, parsed report summary, report status, report signature, and output path;
- report-only policy flags that remain false for automatic tuning, runtime balance changes, authored content writeback, manual-play replacement, and alpha/parity claims.

## Command

```bash
python3 tools/run_headless_balance_harness.py --suite standard
```

This is a workflow hardening slice for the automated balance harness. It does not tune content, write authored JSON, replace manual playtesting, claim final combat balance, or wire a CI provider.
