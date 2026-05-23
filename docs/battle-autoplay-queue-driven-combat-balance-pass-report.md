# Battle Autoplay Queue-Driven Combat Balance Pass Report

Date: 2026-05-23
Task: #10184

## Scope

This slice uses the `battle_autoplay_balance_tuning_queue_v1` report to make a bounded authored army-group calibration over the current sampled combat-feel outliers. The goal is to reduce concrete queue pressure while preserving the existing deterministic combat-feel and balance-matrix gates.

This is a focused content calibration, not final combat balance approval.

## Implementation

- `content/army_groups.json` retunes `army_blackbranch_raiders`, the low/forest Ghoul Grove sample group, from a pure cutthroat/slinger count increase into a mixed pressure group with two `unit_bog_brute` bodies.
- `content/army_groups.json` retunes `army_ripper_vanguard`, used by Bone Ferry Watch, from four `unit_gorefen_ripper` stacks to three so the high/grass sample no longer ends as a burst-pacing wipe.
- `tests/battle_autoplay_balance_tuning_queue_report.gd` now gates the queue-driven balance pass result: deterministic queue signature, no high-priority action-required items, no sample-level terminal-margin or pacing watches, no gate-derived queue items, and at most five remaining watch items.
- `tests/validate_repo.py` gates this evidence document and the strengthened report tokens.

## Before

The tuning queue produced 9 medium-priority watch items with signature `f8dc048d`:

- high-margin forest/low-difficulty cohort pressure;
- one-sided forest, grass, high-difficulty, and Fen Crown cohorts;
- terminal-margin sample watches for `river_pass_ghoul_grove` and `fen_crown_bone_ferry_watch`;
- one burst-pacing sample watch for `fen_crown_bone_ferry_watch`.

## After

The focused queue report now passes with:

- `queue_signature`: `95f5ac7e`
- `item_count`: `5`
- `high_priority_count`: `0`
- `sample_watch_count`: `0`
- `gate_item_count`: `0`
- `combat_feel_gate.status`: `pass`
- `balance_matrix_gate.status`: `pass`
- `terminal_margin_outlier_count`: `0`
- `pacing_band_distribution`: `extended: 2`, `standard: 10`
- `average_terminal_health_margin_pct`: `43`

Remaining queue items are cohort-level watch items. They are useful next leads, but they no longer indicate immediate sample-level terminal-margin or burst-pacing regressions.

## Non-Goals

- No automatic tuning system.
- No broad faction-vs-faction balance approval.
- No spell/autocast tuning.
- No strategic AI rewrite.
- No final combat balance approval.
