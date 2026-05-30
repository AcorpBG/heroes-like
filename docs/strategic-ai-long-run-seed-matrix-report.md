# Strategic AI Long-Run Seed Matrix Report

Slice: `strategic-ai-long-run-seed-matrix-10184`

This slice adds an executable Native RMG generated-map strategic AI seed-matrix runner. It is implementation evidence, not a release-readiness claim.

## Implemented

- Added `HeadlessSimulationHarnessRules.build_strategic_ai_long_run_seed_matrix_report(...)`.
- Added `tests/strategic_ai_long_run_seed_matrix_report.gd/.tscn`.
- The runner starts Native RMG disk-package skirmish sessions only, advances real `OverworldRules.end_turn(...)` turns, tracks enemy activity, task-board state, town ownership, raid counts, and battle interrupts.
- Battle interrupts are auto-resolved through the existing scored battle autoplay path so queued strategic fights do not stop the long-run turn simulation.
- Native/generated enemy faction configs now receive runtime strategic AI defaults when package configs are skeletal: pressure cadence, raid thresholds, raid encounter pools, pillage policy, and spawn points from owned enemy towns.

## Focused Evidence

Focused smoke command:

`GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 90 --scene res://tests/strategic_ai_long_run_seed_matrix_report.tscn`

Current focused Native RMG smoke surface:

- `startup_source = native_rmg_disk_package`
- `size_class_id = homm3_small`
- `turns_completed = 1`
- enemy activity is observed through real `OverworldRules.end_turn(...)`
- `target_assignment_count` tracks active raid target assignment events
- `commander_task_planned_count` tracks coordinated planner events when commanders receive durable pre-deployment tasks
- `task_board_open_count` and `task_board_active_count` track durable planned/active work even when compact public turn events only surface pressure summaries
- if no assignment or planned commander task occurs during the one-turn smoke, the report preserves `strategic_ai_long_run_no_target_assignment` as a production-gap blocker rather than hiding it

## Remaining Validation

The runner supports the production target of 100 seeds over 56 turns, but the committed smoke intentionally does not execute the full 100-seed eight-week matrix. That remains tracked as `strategic_ai_long_run_full_100_seed_8_week_matrix_not_run`.

No production-ready claim. Full strategic AI still needs the full matrix, long-run generated-map quality review, stronger economy timing, retreat judgment, and live-client pacing checks.
