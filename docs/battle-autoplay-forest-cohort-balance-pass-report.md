# Battle Autoplay Forest Cohort Balance Pass Report

Date: 2026-05-23
Task: #10184
Slice: `battle-autoplay-forest-cohort-balance-pass-20260523-10184`

## Scope

This slice follows the remaining `forest` terrain watch from the deterministic `battle_autoplay_balance_tuning_queue_v1` report. The goal is to close the current normal-difficulty tuning queue by retuning only authored Stonewake encounter rosters, while preserving the existing combat-feel, balance-matrix, and difficulty-sweep gates.

No final combat balance approval.

## Implementation

- `content/army_groups.json` strengthens `army_willow_mill_pack` so the Willow Mill forest battle is no longer a guaranteed autoplay player victory.
- `content/scenarios.json` gives `sluice_band` a Stonewake-local `army_stonewake_sluice_band` enemy army so Stonewake remains a mixed-outcome scenario after Willow Mill becomes a loss.
- `tests/battle_autoplay_balance_tuning_queue_report.gd` now gates a clear normal-difficulty queue with `MAX_CURRENT_WATCH_ITEMS := 0`, deterministic repeat signatures, zero sample/gate/cohort watch items, and explicit failure if resolved cohort ids reopen.
- `tests/validate_repo.py` gates this evidence report and the strengthened queue-report tokens.

## Before

The previous cohort pass left one medium-priority watch:

- `queue_signature`: `80bea883`
- `item_count`: `1`
- `status`: `watch`
- `forest` outcome bias at `100`
- `forest` distribution: two victories, zero defeats

## After

The focused queue report now passes with:

- `queue_signature`: `829808c9`
- `item_count`: `0`
- `status`: `clear`
- `high_priority_count`: `0`
- `medium_priority_count`: `0`
- `sample_watch_count`: `0`
- `gate_item_count`: `0`
- `cohort_watch_count`: `0`
- `combat_feel_gate.status`: `pass`
- `balance_matrix_gate.status`: `pass`
- `terminal_margin_outlier_count`: `0`

The default combat report keeps the targeted cohorts mixed:

- `forest`: one victory and one defeat
- `stonewake-watch`: one victory and two defeats
- `formation_guard`: one victory and two defeats
- `grass`: two victories and two defeats

## Non-Goals

- No final combat balance approval.
- No automatic tuning or content writeback.
- No broad faction-vs-faction balance pass.
- No unit-stat rewrite.
- No campaign, strategic AI, or random-map-generation completion claim.
