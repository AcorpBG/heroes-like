# Strategic AI Live Turn Execution Report

Status: implementation evidence.

This slice closes the gap between live commander target selection and actual enemy-turn consequences. It proves that the live target selector is not only producing a plan: `EnemyTurnRules.run_enemy_turn(...)` can assign those targets, persist them into the strategic hero task board, execute arrival resolution, complete captured-site tasks, and change map control in the same turn when a raid is already on the selected target tile.

Validation evidence:
- `AI_HERO_TASK_LIVE_TURN_EXECUTION_REPORT`
- `river_pass_live_target_turn_seizes_reserved_resource_fronts`: Vaska starts without a stored target on `river_free_company`, Sable starts without a stored target on `river_signal_post`, and one enemy turn assigns both live resource-front targets.
- `river_free_company` and `river_signal_post` change from `player` to `faction_mireclaw` through `ai_site_seized` arrival events.
- The report requires both `ai_target_assigned` and `ai_site_seized` events for each target.
- Companion reservation remains active in turn execution: Sable does not duplicate Vaska's Free Company target.
- `enemy_states[].hero_task_state` persists the live assignments, marks the two captured resource tasks completed, and survives `EnemyTurnRules.normalize_enemy_states(...)` without report-only/debug fields.
- `SAVE_VERSION` remains unchanged; this is an optional normalized state field, not a save migration.

Boundaries:
- No route actor rewrite or broad strategic AI quality claim.
- No save migration.
- The test starts raids on target tiles to isolate target selection plus arrival resolution; it does not claim long-route tactical path quality.
- Public event output is checked for internal live-planning leak tokens such as score breakdowns, task ids, reservation keys, and debug fields.
