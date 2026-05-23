# Battle Autoplay Hard Difficulty Watch Pass Report

Slice: `battle-autoplay-hard-difficulty-watch-pass-20260523-10184`

## Purpose

Use the hard row from `battle_autoplay_difficulty_sweep_v1` as a focused combat-feel follow-up after the normal queue was cleared. This pass reduces hard-mode watch noise without changing authored encounter rosters or weakening the strategic hard-mode penalties.

## Baseline

Before this pass, the normal queue was clear with queue_signature `829808c9`, while hard reported seven medium watch items with queue_signature `f59ef772`.

The hard baseline contributors were:

- `formation_guard`, `bloodrush`, and `stonewake-watch` outcome-bias cohort watches.
- `river_pass_hollow_mire` and `causeway_gate_marshals` terminal-margin sample watches.
- `sluice_band` and `causeway_reed_camp` burst-pacing sample watches.

## Change

Hard battle damage multipliers were narrowed from a broad 0.9 / 1.1 damage skew to a smaller 0.95 / 1.05 combat skew. In validation language, the hard battle damage multipliers now preserve the hard-mode signal without reopening the normal queue:

- `player_damage_multiplier`: `0.95`
- `enemy_damage_multiplier`: `1.05`

Hard still keeps its strategic pressure profile and `enemy_initiative_bonus: 1`, so the launch difficulty remains observably harder than normal.

## Gate

`tests/battle_autoplay_difficulty_sweep_report.gd` now carries queue metadata per difficulty row and asserts:

- normal queue remains clear;
- hard queue stays at or below `MAX_HARD_TUNING_QUEUE_ITEMS := 3`;
- resolved hard watches for `bloodrush`, `formation_guard`, and `stonewake-watch` do not reopen.

Current focused evidence:

- Normal row: queue_signature `829808c9`, item_count `0`, status `clear`.
- Hard row: queue_signature `8a238ca3`, item_count `3`, status `watch`.
- Normal-vs-hard remains observable: hard has higher enemy remaining health, lower player remaining health, and a non-zero terminal-margin delta.

## Non-Goals

No final combat balance approval.
No automatic tuning or content writeback.
No global unit-stat rewrite.
No campaign completion or RMG parity claim.
