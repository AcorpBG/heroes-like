# Battle Autoplay Cohort Balance Pass Report

Date: 2026-05-23
Task: #10184
Slice: `battle-autoplay-cohort-balance-pass-20260523-10184`

## Scope

This slice uses the deterministic `battle_autoplay_balance_tuning_queue_v1` output for one bounded authored encounter pass after the prior queue-driven combat balance work. The focus is cohort-level outcome bias in the default 12-sample autoplay harness, especially `fen-crown`, `grass`, and `high` cohorts.

No final combat balance approval.

## Implementation

- `content/scenarios.json` gives `fen_crown_watch` a placement-local `army_fen_crown_gate_watch` enemy army so the sampled gate watch is no longer forced through the stronger shared marshal roster.
- `content/army_groups.json` increases `army_blackbranch_raiders` pressure by one `unit_mire_slinger` stack count to clear the low-difficulty terminal-margin sample watch without a global unit-stat rewrite.
- `tests/battle_autoplay_balance_tuning_queue_report.gd` tightens the current watch budget to one item and keeps `fen-crown`, `grass`, and `high` cohort regressions as explicit failures.
- `tests/validate_repo.py` gates this evidence report and the stricter queue-report tokens.

## Before

The previous queue-driven pass left five medium-priority cohort watches:

- `queue_signature`: `95f5ac7e`
- `item_count`: `5`
- low-difficulty terminal margin observed at `70`
- `fen-crown` outcome bias at `100`
- `grass` outcome bias at `100`
- `high` outcome bias at `100`
- `forest` outcome bias at `100`

## After

The focused queue report now passes with:

- `queue_signature`: `80bea883`
- `item_count`: `1`
- `high_priority_count`: `0`
- `medium_priority_count`: `1`
- `sample_watch_count`: `0`
- `gate_item_count`: `0`
- `combat_feel_gate.status`: `pass`
- `balance_matrix_gate.status`: `pass`
- `terminal_margin_outlier_count`: `0`

The remaining queue item is the `forest` cohort outcome-bias watch. The default combat report now has mixed outcomes for the targeted cohorts:

- `fen-crown`: two defeats and one victory
- `grass`: three defeats and one victory
- `high`: two defeats and one victory

## Non-Goals

- No final combat balance approval.
- No automatic tuning or content writeback.
- No broad faction-vs-faction balance pass.
- No spell/autocast retune.
- No campaign, strategic AI, or random-map-generation completion claim.
