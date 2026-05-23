class_name HeadlessSimulationHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_SCHEMA_ID := "headless_simulation_harness_report_v1"
const REPORT_ID := "HEADLESS_SIMULATION_HARNESS_REPORT"
const HEX_DIGITS := "0123456789abcdef"
const LIVE_RESOURCE_IDS := ["gold", "wood", "ore"]
const REQUIRED_SUBSYSTEM_IDS := [
	"scenario_session_turn_loop",
	"strategic_ai_pressure_tick",
	"strategic_ai_live_turn_execution",
	"strategic_ai_live_route_progression",
	"strategic_ai_live_town_defense_retask",
	"strategic_ai_live_regroup_retreat",
	"economy_resource_delta",
	"battle_resolver_sampling",
	"save_replay_stability",
	"generated_random_map_boundary",
]

static func build_report(input_config: Dictionary = {}) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var generated_sample := _generated_setup(input_config, "headless-harness-generated-boundary-10184")
	var cases := [
		_scenario_session_turn_loop(input_config),
		_strategic_ai_pressure_tick(input_config),
		_strategic_ai_live_turn_execution(input_config),
		_strategic_ai_live_route_progression(input_config),
		_strategic_ai_live_town_defense_retask(input_config),
		_strategic_ai_live_regroup_retreat(input_config),
		_economy_resource_delta(input_config),
		_battle_resolver_sampling(input_config),
		_save_replay_stability(input_config, generated_sample),
		_generated_random_map_boundary(input_config, generated_sample),
	]
	ContentService.clear_generated_scenario_drafts()
	var case_map := {}
	var status_counts := {"pass": 0, "warning": 0, "deferred": 0, "fail": 0}
	for simulation_case in cases:
		if not (simulation_case is Dictionary):
			continue
		var subsystem_id := String(simulation_case.get("subsystem_id", ""))
		var status := String(simulation_case.get("status", "fail"))
		case_map[subsystem_id] = simulation_case
		status_counts[status] = int(status_counts.get(status, 0)) + 1
	var missing_subsystems := []
	for subsystem_id in REQUIRED_SUBSYSTEM_IDS:
		if not case_map.has(subsystem_id):
			missing_subsystems.append(subsystem_id)
	var overall_status := "pass"
	if not missing_subsystems.is_empty() or int(status_counts.get("fail", 0)) > 0:
		overall_status = "fail"
	elif int(status_counts.get("warning", 0)) > 0 or int(status_counts.get("deferred", 0)) > 0:
		overall_status = "warning"
	var harness_signature := harness_signature_for_cases(cases, status_counts, missing_subsystems)
	return {
		"ok": overall_status != "fail",
		"report_id": REPORT_ID,
		"schema_id": REPORT_SCHEMA_ID,
		"status": overall_status,
		"status_counts": status_counts,
		"case_count": cases.size(),
		"required_subsystems": REQUIRED_SUBSYSTEM_IDS,
		"missing_subsystems": missing_subsystems,
		"cases": cases,
		"case_signatures": _case_signature_index(cases),
		"harness_signature": harness_signature,
		"self_signature_check": harness_signature == harness_signature_for_cases(cases, status_counts, missing_subsystems),
		"reporting_policy": {
			"manual_play_replacement": false,
			"automatic_tuning": false,
			"runtime_balance_changes": false,
			"authored_content_writeback": false,
			"generated_campaign_adoption": false,
			"alpha_or_parity_claim": false,
		},
	}

static func compact_summary(report: Dictionary) -> Dictionary:
	var cases := []
	for simulation_case in report.get("cases", []):
		if not (simulation_case is Dictionary):
			continue
		cases.append({
			"subsystem_id": String(simulation_case.get("subsystem_id", "")),
			"case_id": String(simulation_case.get("case_id", "")),
			"status": String(simulation_case.get("status", "")),
			"signature": String(simulation_case.get("signature", "")),
			"summary": simulation_case.get("summary", {}),
			"warnings": simulation_case.get("warnings", []),
			"deferred": simulation_case.get("deferred", []),
		})
	return {
		"ok": bool(report.get("ok", false)),
		"schema_id": String(report.get("schema_id", "")),
		"status": String(report.get("status", "")),
		"status_counts": report.get("status_counts", {}),
		"harness_signature": String(report.get("harness_signature", "")),
		"cases": cases,
		"reporting_policy": report.get("reporting_policy", {}),
	}

static func harness_signature_for_cases(cases: Array, status_counts: Dictionary, missing_subsystems: Array) -> String:
	return _signature_for({
		"schema_id": REPORT_SCHEMA_ID,
		"cases": _case_signature_index(cases),
		"status_counts": status_counts,
		"missing_subsystems": missing_subsystems,
	})

static func _scenario_session_turn_loop(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("scenario_ids", ["river-pass"])
	var bounded_turns: int = max(1, int(input_config.get("turn_loop_days", 2)))
	var rows := []
	var warnings := []
	var failures := []
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
			scenario_id,
			"normal",
			SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
		)
		if session == null or session.scenario_id != scenario_id:
			failures.append("%s did not boot a session." % scenario_id)
			continue
		OverworldRules.normalize_overworld_state(session)
		var turn_results := []
		for _turn_index in range(bounded_turns):
			var result: Dictionary = OverworldRules.end_turn(session)
			turn_results.append({
				"ok": bool(result.get("ok", false)),
				"resource_income_summary": String(result.get("resource_income_summary", "")),
				"enemy_activity_event_count": result.get("enemy_activity_events", []).size() if result.get("enemy_activity_events", []) is Array else 0,
			})
			if not bool(result.get("ok", false)):
				failures.append("%s end-turn loop returned not-ok on day %d." % [scenario_id, int(session.day)])
				break
		var map_size := OverworldRules.derive_map_size(session)
		var row := {
			"scenario_id": scenario_id,
			"final_day": int(session.day),
			"map_size": {"x": map_size.x, "y": map_size.y},
			"town_count": session.overworld.get("towns", []).size(),
			"resource_node_count": session.overworld.get("resource_nodes", []).size(),
			"enemy_state_count": session.overworld.get("enemy_states", []).size(),
			"scenario_status": String(session.scenario_status),
			"turn_results": turn_results,
			"state_signature": _signature_for(_session_signal(session)),
		}
		if int(row.get("enemy_state_count", 0)) <= 0:
			warnings.append("%s booted without enemy states; AI pressure case may defer." % scenario_id)
		rows.append(row)
	var status := _status_from(failures, warnings, [])
	return _case(
		"scenario_session_turn_loop",
		"authored_session_boot_bounded_turn_loop",
		status,
		{
			"scenario_count": rows.size(),
			"bounded_turns": bounded_turns,
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{"scenarios": rows, "warnings": warnings, "failures": failures},
		warnings,
		[]
	)

static func _strategic_ai_pressure_tick(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("ai_scenario_ids", ["river-pass"])
	var cases := []
	var warnings := []
	var deferred := []
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing AI scenario %s." % scenario_id)
			continue
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		if enemy_configs.is_empty():
			deferred.append("%s has no enemy_factions for strategic AI sampling." % scenario_id)
			continue
		var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
			scenario_id,
			"normal",
			SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
		)
		OverworldRules.normalize_overworld_state(session)
		var before_signal := _enemy_state_signal(session)
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		var after_signal := _enemy_state_signal(session)
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			var origin := _enemy_origin(config)
			var resource_report: Dictionary = EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 5)
			var chosen: Dictionary = EnemyAdventureRules.choose_target(session, config, origin)
			var governor: Dictionary = EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
			var target_ids := []
			for target in resource_report.get("targets", []):
				if target is Dictionary:
					target_ids.append(String(target.get("placement_id", "")))
			if target_ids.is_empty() and session.overworld.get("resource_nodes", []).size() > 0:
				warnings.append("%s/%s produced no resource-pressure targets." % [scenario_id, faction_id])
			cases.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"turn_ok": bool(turn_result.get("ok", false)),
				"event_count": turn_result.get("events", []).size() if turn_result.get("events", []) is Array else 0,
				"resource_target_count": int(resource_report.get("target_count", 0)),
				"top_resource_target_ids": target_ids,
				"chosen_target_kind": String(chosen.get("target_kind", "")),
				"chosen_target_placement_id": String(chosen.get("target_placement_id", "")),
				"town_governor_town_count": int(governor.get("town_count", 0)),
				"before_enemy_signature": before_signal,
				"after_enemy_signature": after_signal,
				"pressure_signature": _signature_for({
					"targets": target_ids,
					"chosen": _target_signal(chosen),
					"governor_towns": int(governor.get("town_count", 0)),
				}),
			})
	var status := "pass"
	if cases.is_empty():
		status = "deferred"
	elif not warnings.is_empty() or not deferred.is_empty():
		status = "warning"
	return _case(
		"strategic_ai_pressure_tick",
		"enemy_turn_objective_pressure_tick",
		status,
		{
			"case_count": cases.size(),
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
		},
		{"cases": cases, "warnings": warnings, "deferred": deferred},
		warnings,
		deferred
	)

static func _strategic_ai_live_turn_execution(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_turn_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_turn_faction_id", "faction_mireclaw"))
	var primary_target_id := String(input_config.get("strategic_ai_live_turn_primary_target_id", "river_free_company"))
	var companion_target_id := String(input_config.get("strategic_ai_live_turn_companion_target_id", "river_signal_post"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live-turn scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_turn_execution",
			"live_commander_resource_front_turn_execution",
			"deferred",
			{"scenario_id": scenario_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var config := _enemy_config_for_scenario(scenario, faction_id)
	if config.is_empty():
		deferred.append("%s has no enemy faction config for %s." % [scenario_id, faction_id])
		return _case(
			"strategic_ai_live_turn_execution",
			"live_commander_resource_front_turn_execution",
			"deferred",
			{"scenario_id": scenario_id, "faction_id": faction_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		_update_enemy_state(session, state)
	_set_resource_controller(session, primary_target_id, "player", failures)
	_set_resource_controller(session, companion_target_id, "player", failures)
	var controllers_before := {
		primary_target_id: _resource_controller(session, primary_target_id),
		companion_target_id: _resource_controller(session, companion_target_id),
	}
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var primary_raid_id := "headless_live_turn_primary_%s" % primary_target_id
	var companion_raid_id := "headless_live_turn_companion_%s" % companion_target_id
	encounters.append(_live_turn_raid_seed(session, faction_id, "hero_vaska", primary_raid_id, primary_target_id))
	encounters.append(_live_turn_raid_seed(session, faction_id, "hero_sable", companion_raid_id, companion_target_id))
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var primary_raid := _encounter_by_placement(session, primary_raid_id)
	var companion_raid := _encounter_by_placement(session, companion_raid_id)
	var controllers_after := {
		primary_target_id: _resource_controller(session, primary_target_id),
		companion_target_id: _resource_controller(session, companion_target_id),
	}
	var target_assignments := _event_count(turn_result.get("events", []), "ai_target_assigned")
	var site_seizures := _event_count(turn_result.get("events", []), "ai_site_seized")
	var primary_ok := String(primary_raid.get("target_placement_id", "")) == primary_target_id and bool(primary_raid.get("arrived", false)) and String(controllers_after.get(primary_target_id, "")) == faction_id
	var companion_ok := String(companion_raid.get("target_placement_id", "")) == companion_target_id and bool(companion_raid.get("arrived", false)) and String(controllers_after.get(companion_target_id, "")) == faction_id
	var reserved_unique_targets := (
		String(primary_raid.get("target_placement_id", "")) != ""
		and String(companion_raid.get("target_placement_id", "")) != ""
		and String(primary_raid.get("target_placement_id", "")) != String(companion_raid.get("target_placement_id", ""))
	)
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok.")
	if not primary_ok:
		failures.append("Primary live-turn raid did not assign and seize %s." % primary_target_id)
	if not companion_ok:
		failures.append("Companion live-turn raid did not assign and seize %s." % companion_target_id)
	if not reserved_unique_targets:
		failures.append("Companion reservation did not preserve unique live targets.")
	if target_assignments < 2:
		failures.append("Live turn produced fewer than two target assignment events.")
	if site_seizures < 2:
		failures.append("Live turn produced fewer than two site seizure events.")
	if _has_saved_hero_task_state(session):
		failures.append("Live turn execution wrote forbidden hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(turn_result.get("events", []), 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live-turn events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live-turn events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_turn_execution",
		"live_commander_resource_front_turn_execution",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"primary_target_id": primary_target_id,
			"companion_target_id": companion_target_id,
			"resource_fronts_seized": (1 if primary_ok else 0) + (1 if companion_ok else 0),
			"target_assignment_event_count": target_assignments,
			"site_seizure_event_count": site_seizures,
			"reserved_unique_targets": reserved_unique_targets,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"controllers_before": controllers_before,
			"controllers_after": controllers_after,
			"primary_raid": _raid_execution_signal(primary_raid),
			"companion_raid": _raid_execution_signal(companion_raid),
			"event_types": _event_types(turn_result.get("events", [])),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "no_hero_task_state_write_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_route_progression(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_route_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_route_faction_id", "faction_mireclaw"))
	var target_id := String(input_config.get("strategic_ai_live_route_target_id", "river_free_company"))
	var origin: Dictionary = input_config.get("strategic_ai_live_route_origin", {"x": 7, "y": 1}) if input_config.get("strategic_ai_live_route_origin", {}) is Dictionary else {"x": 7, "y": 1}
	var max_turns: int = max(1, int(input_config.get("strategic_ai_live_route_max_turns", 14)))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live route scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_route_progression",
			"live_commander_resource_front_route_progression",
			"deferred",
			{"scenario_id": scenario_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var config := _enemy_config_for_scenario(scenario, faction_id)
	if config.is_empty():
		deferred.append("%s has no enemy faction config for %s." % [scenario_id, faction_id])
		return _case(
			"strategic_ai_live_route_progression",
			"live_commander_resource_front_route_progression",
			"deferred",
			{"scenario_id": scenario_id, "faction_id": faction_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		_update_enemy_state(session, state)
	_set_resource_controller(session, target_id, "player", failures)
	var raid_id := "headless_live_route_%s" % target_id
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(_live_route_raid_seed(session, faction_id, "hero_vaska", raid_id, origin))
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var route_records := []
	var all_events := []
	var assigned_target := false
	var seized_target := false
	var initial_goal_distance := -1
	var final_goal_distance := -1
	for turn_index in range(max_turns):
		var turn_result: Dictionary = OverworldRules.end_turn(session)
		if not bool(turn_result.get("ok", false)):
			failures.append("End turn returned not-ok during live route progression on turn %d." % (turn_index + 1))
			break
		var events: Array = turn_result.get("enemy_activity_events", []) if turn_result.get("enemy_activity_events", []) is Array else []
		all_events.append_array(events)
		var raid := _encounter_by_placement(session, raid_id)
		if raid.is_empty():
			failures.append("Live route raid disappeared on turn %d." % (turn_index + 1))
			break
		if String(raid.get("target_placement_id", "")) == target_id:
			assigned_target = true
		var current_distance := int(raid.get("goal_distance", 9999))
		if assigned_target and initial_goal_distance < 0:
			initial_goal_distance = current_distance
		final_goal_distance = current_distance
		route_records.append({
			"turn": turn_index + 1,
			"day": int(session.day),
			"x": int(raid.get("x", 0)),
			"y": int(raid.get("y", 0)),
			"target_id": String(raid.get("target_placement_id", "")),
			"goal_distance": current_distance,
			"arrived": bool(raid.get("arrived", false)),
			"controller": _resource_controller(session, target_id),
		})
		if String(_resource_controller(session, target_id)) == faction_id:
			seized_target = true
			break
	var target_controller := _resource_controller(session, target_id)
	if not assigned_target:
		failures.append("Live route raid never assigned the expected resource target %s." % target_id)
	if initial_goal_distance <= 0:
		failures.append("Live route raid did not establish a positive route distance.")
	if final_goal_distance < 0 or final_goal_distance >= initial_goal_distance:
		failures.append("Live route raid did not reduce goal distance: initial=%d final=%d." % [initial_goal_distance, final_goal_distance])
	if not seized_target or target_controller != faction_id:
		failures.append("Live route raid did not seize %s within %d turns." % [target_id, max_turns])
	if _has_saved_hero_task_state(session):
		failures.append("Live route progression wrote forbidden hero_task_state.")
	var assignment_events := _event_count(all_events, "ai_target_assigned")
	var seizure_events := _event_count(all_events, "ai_site_seized")
	if assignment_events < 1:
		failures.append("Live route progression did not surface an ai_target_assigned event.")
	if seizure_events < 1:
		failures.append("Live route progression did not surface an ai_site_seized event.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(all_events, 12)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live route events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live route events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_route_progression",
		"live_commander_resource_front_route_progression",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"target_id": target_id,
			"turns_simulated": route_records.size(),
			"assigned_target": assigned_target,
			"seized_target": seized_target,
			"initial_goal_distance": initial_goal_distance,
			"final_goal_distance": final_goal_distance,
			"target_controller": target_controller,
			"target_assignment_event_count": assignment_events,
			"site_seizure_event_count": seizure_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"origin": {"x": int(origin.get("x", 0)), "y": int(origin.get("y", 0))},
			"route_records": route_records,
			"event_types": _event_types(all_events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "no_hero_task_state_write_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_regroup_retreat(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_regroup_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_regroup_faction_id", "faction_mireclaw"))
	var target_id := String(input_config.get("strategic_ai_live_regroup_target_id", "river_free_company"))
	var regroup_town_id := String(input_config.get("strategic_ai_live_regroup_town_id", "duskfen_bastion"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_regroup_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live regroup scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_regroup_retreat",
			"live_understrength_raid_regroups_at_town",
			"deferred",
			{"scenario_id": scenario_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var config := _enemy_config_for_scenario(scenario, faction_id)
	if config.is_empty():
		deferred.append("%s has no enemy faction config for %s." % [scenario_id, faction_id])
		return _case(
			"strategic_ai_live_regroup_retreat",
			"live_understrength_raid_regroups_at_town",
			"deferred",
			{"scenario_id": scenario_id, "faction_id": faction_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		_update_enemy_state(session, state)
	_set_resource_controller(session, target_id, "player", failures)
	var raid_id := "headless_live_regroup_%s" % target_id
	var seed_raid := _understrength_regroup_raid_seed(session, faction_id, roster_hero_id, raid_id, target_id)
	var before_strength := EnemyAdventureRules.raid_strength(seed_raid)
	var desired_before := EnemyAdventureRules.desired_raid_strength(seed_raid)
	var regroup_needed_before := EnemyAdventureRules.raid_regroup_needed(seed_raid)
	var garrison_before := _town_garrison_unit_count(session, regroup_town_id, "unit_bog_brute")
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = OverworldRules.end_turn(session)
	var events: Array = turn_result.get("enemy_activity_events", []) if turn_result.get("enemy_activity_events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	var garrison_after := _town_garrison_unit_count(session, regroup_town_id, "unit_bog_brute")
	var resource_controller := _resource_controller(session, target_id)
	var assignment_events := _event_count(events, "ai_target_assigned")
	var regroup_events := _event_count(events, "ai_raid_regrouped")
	if not bool(turn_result.get("ok", false)):
		failures.append("End turn returned not-ok during live regroup retreat.")
	if after_raid.is_empty():
		failures.append("Live regroup raid disappeared after end-turn enemy cycle.")
	if not regroup_needed_before:
		failures.append("Live regroup fixture raid was not understrength before enemy turn.")
	if assignment_events < 1:
		failures.append("Live regroup did not surface an ai_target_assigned event.")
	if regroup_events < 1:
		failures.append("Live regroup did not surface an ai_raid_regrouped event.")
	if after_strength <= before_strength:
		failures.append("Live regroup did not increase raid strength: before=%d after=%d." % [before_strength, after_strength])
	if garrison_after >= garrison_before:
		failures.append("Live regroup did not pull from town garrison: before=%d after=%d." % [garrison_before, garrison_after])
	if String(after_raid.get("last_regroup_town_id", "")) != regroup_town_id:
		failures.append("Live regroup did not record regroup town %s." % regroup_town_id)
	if String(after_raid.get("target_kind", "")) != "":
		failures.append("Live regroup raid did not clear regroup target after rebuilding.")
	if resource_controller == faction_id:
		failures.append("Live regroup captured the original offensive resource instead of retreating.")
	if _has_saved_hero_task_state(session):
		failures.append("Live regroup wrote forbidden hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live regroup events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live regroup events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_regroup_retreat",
		"live_understrength_raid_regroups_at_town",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"target_id": target_id,
			"regroup_town_id": regroup_town_id,
			"before_strength": before_strength,
			"after_strength": after_strength,
			"desired_before": desired_before,
			"regroup_needed_before": regroup_needed_before,
			"garrison_before": garrison_before,
			"garrison_after": garrison_after,
			"resource_controller_after": resource_controller,
			"target_assignment_event_count": assignment_events,
			"regroup_event_count": regroup_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "no_hero_task_state_write_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_town_defense_retask(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_defense_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_defense_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_defense_town_id", "duskfen_bastion"))
	var previous_target_id := String(input_config.get("strategic_ai_live_defense_previous_target_id", "river_free_company"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_defense_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live town-defense scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_town_defense_retask",
			"live_raid_retasks_to_stabilizing_owned_town",
			"deferred",
			{"scenario_id": scenario_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var config := _enemy_config_for_scenario(scenario, faction_id)
	if config.is_empty():
		deferred.append("%s has no enemy faction config for %s." % [scenario_id, faction_id])
		return _case(
			"strategic_ai_live_town_defense_retask",
			"live_raid_retasks_to_stabilizing_owned_town",
			"deferred",
			{"scenario_id": scenario_id, "faction_id": faction_id, "deferred_count": deferred.size()},
			{"deferred": deferred, "warnings": warnings, "failures": failures},
			warnings,
			deferred
		)
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		_update_enemy_state(session, state)
	_set_resource_controller(session, previous_target_id, "player", failures)
	_set_town_stabilizing_front(session, town_id, faction_id, failures)
	_set_player_position(session, {"x": 6, "y": 2})
	var raid_id := "headless_live_defense_%s" % town_id
	var seed_raid := _town_defense_retask_raid_seed(session, faction_id, roster_hero_id, raid_id, previous_target_id)
	var regroup_needed_before := EnemyAdventureRules.raid_regroup_needed(seed_raid)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = OverworldRules.end_turn(session)
	var events: Array = turn_result.get("enemy_activity_events", []) if turn_result.get("enemy_activity_events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	var assignment_events := _event_count(events, "ai_target_assigned")
	var resource_controller := _resource_controller(session, previous_target_id)
	if not bool(turn_result.get("ok", false)):
		failures.append("End turn returned not-ok during live town-defense retask.")
	if after_raid.is_empty():
		failures.append("Live town-defense raid disappeared after end-turn enemy cycle.")
	if regroup_needed_before:
		failures.append("Live town-defense fixture raid was understrength before enemy turn.")
	if assignment_events < 1:
		failures.append("Live town-defense retask did not surface an ai_target_assigned event.")
	if String(after_raid.get("target_kind", "")) != "town" or String(after_raid.get("target_placement_id", "")) != town_id:
		failures.append("Live town-defense retask did not target %s." % town_id)
	if "town_defense" not in reason_codes or "front_stabilization" not in reason_codes:
		failures.append("Live town-defense retask missed public reason codes.")
	if String(after_raid.get("previous_target_placement_id", "")) != previous_target_id:
		failures.append("Live town-defense retask did not preserve previous target %s." % previous_target_id)
	if resource_controller == faction_id:
		failures.append("Live town-defense retask captured the previous offensive resource.")
	if _has_saved_hero_task_state(session):
		failures.append("Live town-defense retask wrote forbidden hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live town-defense retask events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live town-defense events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_town_defense_retask",
		"live_raid_retasks_to_stabilizing_owned_town",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"previous_target_id": previous_target_id,
			"regroup_needed_before": regroup_needed_before,
			"target_assignment_event_count": assignment_events,
			"resource_controller_after": resource_controller,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"target_reason_codes": reason_codes,
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "no_hero_task_state_write_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _economy_resource_delta(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("economy_scenario_id", "river-pass"))
	var bounded_turns: int = max(1, int(input_config.get("economy_turns", 3)))
	var warnings := []
	var failures := []
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null or session.scenario_id == "":
		failures.append("Economy scenario %s did not boot." % scenario_id)
		return _case(
			"economy_resource_delta",
			"bounded_end_turn_resource_delta",
			"fail",
			{"scenario_id": scenario_id, "turns": bounded_turns, "failure_count": failures.size()},
			{"warnings": warnings, "failures": failures},
			warnings,
			[]
		)
	OverworldRules.normalize_overworld_state(session)
	var before_resources := _resource_pool(session.overworld.get("resources", {}))
	var turn_income := []
	for _turn_index in range(bounded_turns):
		var result: Dictionary = OverworldRules.end_turn(session)
		turn_income.append(String(result.get("resource_income_summary", "")))
	var after_resources := _resource_pool(session.overworld.get("resources", {}))
	var delta := _resource_delta(before_resources, after_resources)
	if _resource_abs_sum(delta) <= 0:
		warnings.append("%s economy loop produced no live-resource delta over %d turns." % [scenario_id, bounded_turns])
	var status := _status_from(failures, warnings, [])
	return _case(
		"economy_resource_delta",
		"bounded_end_turn_resource_delta",
		status,
		{
			"scenario_id": scenario_id,
			"turns": bounded_turns,
			"delta": delta,
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"before_resources": before_resources,
			"after_resources": after_resources,
			"turn_income_summaries": turn_income,
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		[]
	)

static func _battle_resolver_sampling(input_config: Dictionary) -> Dictionary:
	var sample_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report(
		input_config,
		"battle_scenario_ids",
		"battle_sample_limit"
	)
	var samples: Array = sample_report.get("samples", []) if sample_report.get("samples", []) is Array else []
	var warnings: Array = sample_report.get("warnings", []) if sample_report.get("warnings", []) is Array else []
	var deferred: Array = sample_report.get("deferred", []) if sample_report.get("deferred", []) is Array else []
	var summary: Dictionary = sample_report.get("summary", {}) if sample_report.get("summary", {}) is Dictionary else {}
	var status := "warning"
	if samples.is_empty():
		status = "deferred"
	elif warnings.is_empty() and deferred.is_empty():
		status = "pass"
	return _case(
		"battle_resolver_sampling",
		"deterministic_battle_autoplay_samples",
		status,
		summary,
		{
			"samples": samples,
			"distribution": sample_report.get("distribution", {}),
			"action_distribution": sample_report.get("action_distribution", {}),
			"warnings": warnings,
			"deferred": deferred,
		},
		warnings,
		deferred
	)

static func _save_replay_stability(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var scenario_id := String(input_config.get("save_scenario_id", "river-pass"))
	var checks := []
	var warnings := []
	var deferred := []
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var payload := session.to_dict()
	var normalized := SessionStateStoreScript.normalize_payload(payload)
	var restore_result: Dictionary = SaveService._normalize_restore_result(payload, "manual")
	checks.append({
		"case_id": "authored_session_payload_restore",
		"ok": bool(restore_result.get("ok", false)),
		"scenario_id": scenario_id,
		"save_version": int(normalized.get("save_version", 0)),
		"resume_target": String(restore_result.get("resume_target", "")),
		"signature": _signature_for(_save_payload_signal(normalized)),
	})
	if not bool(restore_result.get("ok", false)):
		warnings.append("Authored session payload did not restore through SaveService.")
	var generated_restore_check := _generated_restore_check(input_config, generated_sample)
	if generated_restore_check.is_empty():
		deferred.append("Generated random-map provenance restore sample is unavailable.")
	else:
		checks.append(generated_restore_check)
		if not bool(generated_restore_check.get("ok", false)):
			warnings.append("Generated random-map provenance restore did not pass.")
	var status := "pass"
	if not warnings.is_empty() or not deferred.is_empty():
		status = "warning"
	return _case(
		"save_replay_stability",
		"payload_normalize_restore_and_provenance_round_trip",
		status,
		{
			"check_count": checks.size(),
			"save_version": int(SessionStateStoreScript.SAVE_VERSION),
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
		},
		{
			"checks": checks,
			"warnings": warnings,
			"deferred": deferred,
			"save_policy": "metadata_restore_report_only_no_save_version_bump",
		},
		warnings,
		deferred
	)

static func _generated_random_map_boundary(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var setup := generated_sample if not generated_sample.is_empty() else _generated_setup(input_config, "headless-harness-generated-boundary-10184")
	var warnings := []
	var deferred := []
	var failures := []
	if not bool(setup.get("ok", false)):
		deferred.append("Generated setup unavailable: %s" % JSON.stringify(setup.get("validation", setup)))
		return _case(
			"generated_random_map_boundary",
			"generated_skirmish_provenance_boundary",
			"deferred",
			{"warning_count": 0, "deferred_count": deferred.size(), "failure_count": 0},
			{"warnings": warnings, "deferred": deferred, "failures": failures},
			warnings,
			deferred
		)
	var scenario_id := String(setup.get("scenario_id", ""))
	var session: SessionStateStoreScript.SessionData = _generated_session_from_setup(setup)
	if session == null or session.scenario_id != scenario_id:
		failures.append("Generated skirmish session did not preserve setup scenario id.")
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session != null and session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	if String(boundary.get("adoption_path", "")) != "skirmish_session_only_no_authored_browser_or_campaign":
		failures.append("Generated session boundary adoption path changed: %s" % JSON.stringify(boundary))
	if ContentService.has_authored_scenario(scenario_id):
		failures.append("Generated scenario appeared as authored content.")
	var provenance: Dictionary = session.flags.get("generated_random_map_provenance", {}) if session != null and session.flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var replay: Dictionary = session.flags.get("generated_random_map_replay_metadata", {}) if session != null and session.flags.get("generated_random_map_replay_metadata", {}) is Dictionary else {}
	if bool(provenance.get("authored_content_writeback", true)) or bool(provenance.get("campaign_adoption", true)) or bool(provenance.get("alpha_parity_claim", true)):
		failures.append("Generated provenance crossed writeback/campaign/parity boundary.")
	if String(replay.get("replay_boundary", "")).find("seed_config_identity") < 0:
		warnings.append("Generated replay metadata is missing the explicit seed/config identity boundary.")
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"generated_random_map_boundary",
		"generated_skirmish_provenance_boundary",
		status,
		{
			"scenario_id": scenario_id,
			"template_id": String(setup.get("template_id", "")),
			"profile_id": String(setup.get("profile_id", "")),
			"normalized_seed": String(setup.get("normalized_seed", "")),
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
			"failure_count": failures.size(),
		},
		{
			"generated_identity": setup.get("generated_identity", {}),
			"validation_status": String(setup.get("validation", {}).get("status", "")),
			"boundary": boundary,
			"provenance_signature": _signature_for(provenance),
			"replay_boundary": String(replay.get("replay_boundary", "")),
			"warnings": warnings,
			"deferred": deferred,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _generated_restore_check(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var setup := generated_sample if not generated_sample.is_empty() else _generated_setup(input_config, "headless-harness-save-replay-10184")
	if not bool(setup.get("ok", false)):
		return {}
	var session: SessionStateStoreScript.SessionData = _generated_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		return {}
	var payload := session.to_dict()
	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(payload, "manual")
	var restored_session: SessionStateStoreScript.SessionData = restore_result.get("session", null)
	return {
		"case_id": "generated_map_seed_config_restore",
		"ok": bool(restore_result.get("ok", false)) and restored_session != null and restored_session.scenario_id == session.scenario_id,
		"scenario_id": String(payload.get("scenario_id", "")),
		"restore_resume_target": String(restore_result.get("resume_target", "")),
		"registered_from_provenance": ContentService.has_generated_scenario_draft(String(payload.get("scenario_id", ""))),
		"replay_boundary": String(payload.get("flags", {}).get("generated_random_map_replay_metadata", {}).get("replay_boundary", "")),
		"provenance_signature": _signature_for(payload.get("flags", {}).get("generated_random_map_provenance", {})),
	}

static func _generated_session_from_setup(setup: Dictionary) -> SessionStateStoreScript.SessionData:
	if not bool(setup.get("ok", false)):
		return SessionStateStoreScript.new_session_data()
	var payload: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_generated_skirmish_session(
		payload,
		String(setup.get("difficulty", "normal")),
		{
			"provenance": setup.get("provenance", {}),
			"replay_metadata": setup.get("replay_metadata", {}),
			"validation": setup.get("validation", {}),
			"retry_status": setup.get("retry_status", {}),
			"generated_identity": setup.get("generated_identity", {}),
			"boundary": {
				"authored_content_writeback": false,
				"campaign_adoption": false,
				"skirmish_browser_authored_listing": false,
				"alpha_parity_claim": false,
			},
		}
	)
	if session.scenario_id == "":
		return session
	session.flags["generated_random_map_provenance"] = setup.get("provenance", {})
	session.flags["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.flags["generated_random_map_validation"] = setup.get("validation", {})
	session.flags["generated_random_map_retry_status"] = setup.get("retry_status", {})
	session.flags["generated_random_map_boundary"]["adoption_path"] = "skirmish_session_only_no_authored_browser_or_campaign"
	session.overworld["generated_random_map_provenance"] = setup.get("provenance", {})
	session.overworld["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.overworld["generated_random_map_validation"] = setup.get("validation", {})
	session.overworld["generated_random_map_retry_status"] = setup.get("retry_status", {})
	OverworldRules.normalize_overworld_state(session)
	return session

static func _generated_setup(input_config: Dictionary, seed: String) -> Dictionary:
	var config: Dictionary = input_config.get("random_map_config", {}) if input_config.get("random_map_config", {}) is Dictionary else {}
	if config.is_empty():
		config = _random_map_config(seed)
	return ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")

static func _random_map_config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "headless_simulation_harness", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

static func _case(
	subsystem_id: String,
	case_id: String,
	status: String,
	summary: Dictionary,
	evidence: Dictionary,
	warnings: Array,
	deferred: Array
) -> Dictionary:
	var payload := {
		"subsystem_id": subsystem_id,
		"case_id": case_id,
		"status": status,
		"summary": summary,
		"evidence": evidence,
		"warnings": warnings,
		"deferred": deferred,
	}
	payload["signature"] = _signature_for({
		"subsystem_id": subsystem_id,
		"case_id": case_id,
		"status": status,
		"summary": summary,
		"evidence": evidence,
		"warnings": warnings,
		"deferred": deferred,
	})
	return payload

static func _status_from(failures: Array, warnings: Array, deferred: Array) -> String:
	if not failures.is_empty():
		return "fail"
	if not warnings.is_empty() or not deferred.is_empty():
		return "warning"
	return "pass"

static func _case_signature_index(cases: Array) -> Dictionary:
	var index := {}
	for simulation_case in cases:
		if simulation_case is Dictionary:
			index[String(simulation_case.get("subsystem_id", ""))] = String(simulation_case.get("signature", ""))
	return index

static func _session_signal(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {
		"scenario_id": String(session.scenario_id),
		"hero_id": String(session.hero_id),
		"day": int(session.day),
		"launch_mode": String(session.launch_mode),
		"scenario_status": String(session.scenario_status),
		"resources": _resource_pool(session.overworld.get("resources", {})),
		"counts": _overworld_counts(session.overworld),
	}

static func _enemy_state_signal(session: SessionStateStoreScript.SessionData) -> String:
	var rows := []
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary):
			continue
		rows.append({
			"faction_id": String(state.get("faction_id", "")),
			"pressure": int(state.get("pressure", 0)),
			"raid_counter": int(state.get("raid_counter", 0)),
			"commander_counter": int(state.get("commander_counter", 0)),
			"siege_progress": int(state.get("siege_progress", 0)),
			"posture": String(state.get("posture", "")),
			"treasury": _resource_pool(state.get("treasury", {})),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("faction_id", "")) < String(b.get("faction_id", ""))
	)
	return _signature_for(rows)

static func _save_payload_signal(payload: Dictionary) -> Dictionary:
	return {
		"save_version": int(payload.get("save_version", 0)),
		"scenario_id": String(payload.get("scenario_id", "")),
		"hero_id": String(payload.get("hero_id", "")),
		"day": int(payload.get("day", 0)),
		"launch_mode": String(payload.get("launch_mode", "")),
		"game_state": String(payload.get("game_state", "")),
		"scenario_status": String(payload.get("scenario_status", "")),
		"overworld_counts": _overworld_counts(payload.get("overworld", {})),
	}

static func _overworld_counts(overworld_value: Variant) -> Dictionary:
	var overworld: Dictionary = overworld_value if overworld_value is Dictionary else {}
	return {
		"towns": overworld.get("towns", []).size() if overworld.get("towns", []) is Array else 0,
		"resource_nodes": overworld.get("resource_nodes", []).size() if overworld.get("resource_nodes", []) is Array else 0,
		"artifact_nodes": overworld.get("artifact_nodes", []).size() if overworld.get("artifact_nodes", []) is Array else 0,
		"encounters": overworld.get("encounters", []).size() if overworld.get("encounters", []) is Array else 0,
		"enemy_states": overworld.get("enemy_states", []).size() if overworld.get("enemy_states", []) is Array else 0,
	}

static func _battle_signal(battle: Dictionary) -> Dictionary:
	if battle.is_empty():
		return {}
	var side_counts := {"player": 0, "enemy": 0}
	var living_counts := {"player": 0, "enemy": 0}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var side := String(stack.get("side", ""))
		side_counts[side] = int(side_counts.get(side, 0)) + 1
		if int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			living_counts[side] = int(living_counts.get(side, 0)) + 1
	return {
		"encounter_id": String(battle.get("encounter_id", "")),
		"round": int(battle.get("round", 0)),
		"distance": int(battle.get("distance", 0)),
		"side_counts": side_counts,
		"living_counts": living_counts,
		"active_stack_side": String(BattleRules.get_active_stack(battle).get("side", "")),
	}

static func _enemy_origin(config: Dictionary) -> Dictionary:
	var spawn_points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if not spawn_points.is_empty() and spawn_points[0] is Dictionary:
		return {"x": int(spawn_points[0].get("x", 0)), "y": int(spawn_points[0].get("y", 0))}
	return {"x": 0, "y": 0}

static func _enemy_config_for_scenario(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

static func _enemy_state_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

static func _update_enemy_state(session: SessionStateStoreScript.SessionData, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return

static func _set_resource_controller(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	faction_id: String,
	failures: Array
) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	failures.append("Missing resource node %s for live-turn harness fixture." % placement_id)

static func _resource_controller(session: SessionStateStoreScript.SessionData, placement_id: String) -> String:
	var node := _resource_node_by_placement(session, placement_id)
	return String(node.get("collected_by_faction_id", "")) if not node.is_empty() else ""

static func _resource_node_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

static func _set_town_stabilizing_front(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	faction_id: String,
	failures: Array
) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("placement_id", "")) != placement_id:
			continue
		town["front"] = {
			"state": "stabilizing",
			"faction_id": faction_id,
			"last_change_day": max(0, int(session.day) - 1),
			"stabilize_until_day": int(session.day) + 4,
			"last_owner": "player",
			"capture_count": 1,
			"source": "headless_harness_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	failures.append("Missing town %s for live town-defense fixture." % placement_id)

static func _set_player_position(session: SessionStateStoreScript.SessionData, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	var heroes: Array = session.overworld.get("heroes", []) if session.overworld.get("heroes", []) is Array else []
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("owner", "player")) == "player":
			hero["position"] = session.overworld["hero_position"].duplicate(true)
			heroes[index] = hero
			session.overworld["heroes"] = heroes
			return

static func _live_turn_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	target_resource_id: String
) -> Dictionary:
	var node := _resource_node_by_placement(session, target_resource_id)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

static func _live_route_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	origin: Dictionary
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

static func _town_defense_retask_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	previous_target_id: String
) -> Dictionary:
	var node := _resource_node_by_placement(session, previous_target_id)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": 6,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": previous_target_id,
		"target_label": "Free Company Camp",
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"enemy_army": {
			"id": "headless_defense_retask_fixture_host",
			"name": "Defense Retask Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 8}],
		},
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

static func _understrength_regroup_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	target_resource_id: String
) -> Dictionary:
	var node := _resource_node_by_placement(session, target_resource_id)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": target_resource_id,
		"target_label": "Free Company Camp",
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"enemy_army": {
			"id": "headless_regroup_fixture_host",
			"name": "Damaged Raid Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 1}],
		},
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

static func _encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

static func _town_garrison_unit_count(session: SessionStateStoreScript.SessionData, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		for stack in town.get("garrison", []):
			if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
				return int(stack.get("count", 0))
	return 0

static func _event_count(events: Variant, event_type: String) -> int:
	var count := 0
	if not (events is Array):
		return count
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			count += 1
	return count

static func _event_types(events: Variant) -> Array:
	var types := []
	if not (events is Array):
		return types
	for event in events:
		if event is Dictionary:
			var event_type := String(event.get("event_type", ""))
			if event_type != "" and event_type not in types:
				types.append(event_type)
	types.sort()
	return types

static func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

static func _has_saved_hero_task_state(session: SessionStateStoreScript.SessionData) -> bool:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and state.has("hero_task_state"):
			return true
	return false

static func _public_event_leak_tokens(public_events: Variant) -> Array:
	var leaks := []
	var forbidden_tokens := [
		"resource_score_breakdown",
		"target_debug_reason",
		"final_priority",
		"hero_task_state",
		"task_id",
		"reservation_key",
	]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(String(token)) >= 0:
			leaks.append(String(token))
	return leaks

static func _raid_execution_signal(raid: Dictionary) -> Dictionary:
	return {
		"placement_id": String(raid.get("placement_id", "")),
		"target_kind": String(raid.get("target_kind", "")),
		"target_placement_id": String(raid.get("target_placement_id", "")),
		"arrived": bool(raid.get("arrived", false)),
		"x": int(raid.get("x", 0)),
		"y": int(raid.get("y", 0)),
		"goal_distance": int(raid.get("goal_distance", 9999)),
		"last_regroup_town_id": String(raid.get("last_regroup_town_id", "")),
		"last_regroup_strength_delta": int(raid.get("last_regroup_strength_delta", 0)),
	}

static func _target_signal(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", "")),
		"target_id": String(target.get("target_id", "")),
	}

static func _resource_pool(value: Variant) -> Dictionary:
	var pool := {}
	for resource_id in LIVE_RESOURCE_IDS:
		pool[resource_id] = 0
	if value is Dictionary:
		for resource_id in LIVE_RESOURCE_IDS:
			pool[resource_id] = int(value.get(resource_id, 0))
	return pool

static func _resource_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for resource_id in LIVE_RESOURCE_IDS:
		delta[resource_id] = int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
	return delta

static func _resource_abs_sum(pool: Dictionary) -> int:
	var total := 0
	for resource_id in LIVE_RESOURCE_IDS:
		total += abs(int(pool.get(resource_id, 0)))
	return total

static func _signature_for(value: Variant) -> String:
	return _hash32_hex(_stable_stringify(value))

static func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts := []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(String(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)

static func _hash32_hex(text: String) -> String:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0xffffffff
	var chars := []
	for shift in [28, 24, 20, 16, 12, 8, 4, 0]:
		chars.append(HEX_DIGITS[(value >> shift) & 0xf])
	return "".join(chars)
