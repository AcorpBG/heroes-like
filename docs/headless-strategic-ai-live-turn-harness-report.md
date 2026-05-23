# Headless Strategic AI Live Turn Harness Report

Status: implementation evidence.

This slice promotes the live commander resource-front execution proof into the shared headless simulation harness. The harness now has required `strategic_ai_live_turn_execution`, `strategic_ai_live_route_progression`, `strategic_ai_live_town_defense_retask`, `strategic_ai_live_town_retake_assault`, `strategic_ai_live_raid_assault_grouping`, and `strategic_ai_live_regroup_retreat` subsystems, so strategic AI quality work can be checked alongside economy, save/replay, random-map boundary, and battle balance evidence.

Implemented behavior:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_turn_execution`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs a River Pass live-turn case through `EnemyTurnRules.run_enemy_turn(...)`.
- The case starts Vaska on `river_free_company` and Sable on `river_signal_post` with no stored raid targets.
- The harness requires live target assignment, companion target reservation, site seizure, and Mireclaw control of both resource fronts.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_route_progression`.
- `HeadlessSimulationHarnessRules.build_report(...)` also runs `live_commander_resource_front_route_progression` through repeated `OverworldRules.end_turn(...)` calls.
- The route case starts Vaska at `(7, 1)` with no stored raid target, lets live AI choose `river_free_company`, records each turn in `route_records`, and requires the route to close before seizure.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_town_defense_retask`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs `live_raid_retasks_to_stabilizing_owned_town` through `OverworldRules.end_turn(...)`.
- The town-defense case marks Duskfen Bastion as a stabilizing Mireclaw front, starts a strong Vaska raid aimed at `river_free_company`, and requires the raid to retask to `duskfen_bastion` with `town_defense` and `front_stabilization` reason codes.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_town_retake_assault`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs `live_retake_front_queues_town_defense_battle` through `EnemyTurnRules.run_enemy_turn(...)`.
- The town-retake case marks Duskfen Bastion as a player-captured Mireclaw retake front, starts a no-target Vaska raid in battle range, requires live target selection to choose `duskfen_bastion`, and requires the normal enemy turn to queue a `town_defense` battle for that town.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_raid_assault_grouping`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs `live_nearby_raids_group_for_town_assault` through `EnemyTurnRules.run_enemy_turn(...)`.
- The raid-grouping case marks Duskfen Bastion as a player-captured Mireclaw retake front, starts a commander-led assault host and adjacent commanderless support column assigned to the town, requires support strength to transfer into the leader, resolves the support host out of active pressure, emits `ai_raid_grouped`, and still queues a `town_defense` battle.
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_regroup_retreat`.
- `HeadlessSimulationHarnessRules.build_report(...)` runs `live_understrength_raid_regroups_at_town` through `OverworldRules.end_turn(...)`.
- The regroup case starts a damaged Vaska raid aimed at `river_free_company`, requires a Duskfen Bastion retreat/regroup, proves strength recovery and garrison transfer, and requires the original resource to stay player-controlled on that turn.
- Regroup assignment/completion events are high-importance public activity so `ai_raid_regrouped` survives the standard end-turn event surface without leaking internal score/task fields.
- The case checks public AI event output for internal score/task/reservation leak tokens.
- The evidence keeps the existing report-only harness boundaries: no automatic tuning, no authored content writeback, no manual play replacement, and no alpha/parity claim.
- No save migration.

Validation evidence:
- `HEADLESS_SIMULATION_HARNESS_REPORT`
- `live_commander_resource_front_turn_execution`
- `live_commander_resource_front_route_progression`
- `live_raid_retasks_to_stabilizing_owned_town`
- `live_nearby_raids_group_for_town_assault`
- `live_understrength_raid_regroups_at_town`
- `strategic_ai_live_turn_execution`
- `strategic_ai_live_route_progression`
- `strategic_ai_live_town_defense_retask`
- `strategic_ai_live_town_retake_assault`
- `strategic_ai_live_raid_assault_grouping`
- `strategic_ai_live_regroup_retreat`
- `resource_fronts_seized = 2`
- `reserved_unique_targets = true`
- `initial_goal_distance = 9`
- `final_goal_distance = 0`
- `turns_simulated = 10`
- `assigned_target = true`
- `seized_target = true`
- `town_id = duskfen_bastion`
- `previous_target_id = river_free_company`
- `town_defense`
- `front_stabilization`
- `live_retake_front_queues_town_defense_battle`
- `battle_context_type = town_defense`
- `battle_town_id = duskfen_bastion`
- `grouping_event_count = 1`
- `active_before = 2`
- `active_after = 1`
- `leader_strength_after >= leader_strength_before + support_strength_before`
- `regroup_event_count = 1`
- `garrison_before = 5`
- `garrison_after = 0`
- `before_strength = 21`
- `after_strength = 191`
- `target_assignment_event_count >= 2`
- `site_seizure_event_count >= 2`
- `save_policy = no_hero_task_state_write_no_save_migration`

Remaining gaps:
- This is a deterministic harness fixture for one strategic AI behavior, not a full AI quality claim.
- This route case proves one long-route resource-front progression fixture, not broad path quality.
- This town-defense case proves one stabilizing-front retask fixture, not broad defense rotation.
- This town-retake case proves one live retake-front battle queue fixture, not broad objective sequencing.
- This raid-grouping case proves one adjacent support-column consolidation fixture, not a broad multi-hero army board or general grouping planner.
- This regroup case proves one retreat/rebuild fixture, not broad defense rotation or difficulty tuning.
- Town assault priorities, recruitment grouping, defense rotation, objective handling across scenarios, and difficulty tuning still need broader harness cases.
