# Headless Strategic AI Live Turn Harness Report

Status: implementation evidence.

This slice promotes the live commander resource-front execution proof into the shared headless simulation harness. The harness now has required `strategic_ai_live_turn_execution` and `strategic_ai_live_route_progression` subsystems, so strategic AI quality work can be checked alongside economy, save/replay, random-map boundary, and battle balance evidence.

Implemented behavior:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_turn_execution`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs a River Pass live-turn case through `EnemyTurnRules.run_enemy_turn(...)`.
- The case starts Vaska on `river_free_company` and Sable on `river_signal_post` with no stored raid targets.
- The harness requires live target assignment, companion target reservation, site seizure, and Mireclaw control of both resource fronts.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_route_progression`.
- `HeadlessSimulationHarnessRules.build_report(...)` also runs `live_commander_resource_front_route_progression` through repeated `OverworldRules.end_turn(...)` calls.
- The route case starts Vaska at `(7, 1)` with no stored raid target, lets live AI choose `river_free_company`, records each turn in `route_records`, and requires the route to close before seizure.
- The case checks public AI event output for internal score/task/reservation leak tokens.
- The evidence keeps the existing report-only harness boundaries: no automatic tuning, no authored content writeback, no manual play replacement, and no alpha/parity claim.
- No save migration.

Validation evidence:
- `HEADLESS_SIMULATION_HARNESS_REPORT`
- `live_commander_resource_front_turn_execution`
- `live_commander_resource_front_route_progression`
- `strategic_ai_live_turn_execution`
- `strategic_ai_live_route_progression`
- `resource_fronts_seized = 2`
- `reserved_unique_targets = true`
- `initial_goal_distance = 9`
- `final_goal_distance = 0`
- `turns_simulated = 10`
- `assigned_target = true`
- `seized_target = true`
- `target_assignment_event_count >= 2`
- `site_seizure_event_count >= 2`
- `save_policy = no_hero_task_state_write_no_save_migration`

Remaining gaps:
- This is a deterministic harness fixture for one strategic AI behavior, not a full AI quality claim.
- This route case proves one long-route resource-front progression fixture, not broad path quality.
- Town assault priorities, recruitment grouping, defense rotation, retreat timing, objective handling across scenarios, and difficulty tuning still need broader harness cases.
