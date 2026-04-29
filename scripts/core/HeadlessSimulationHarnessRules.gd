class_name HeadlessSimulationHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")

const REPORT_SCHEMA_ID := "headless_simulation_harness_report_v1"
const REPORT_ID := "HEADLESS_SIMULATION_HARNESS_REPORT"
const HEX_DIGITS := "0123456789abcdef"
const LIVE_RESOURCE_IDS := ["gold", "wood", "ore"]
const REQUIRED_SUBSYSTEM_IDS := [
	"scenario_session_turn_loop",
	"strategic_ai_pressure_tick",
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
	var scenario_ids: Array = input_config.get("battle_scenario_ids", ["river-pass"])
	var max_samples: int = max(1, int(input_config.get("battle_sample_limit", 1)))
	var samples := []
	var warnings := []
	var deferred := []
	for scenario_id_value in scenario_ids:
		if samples.size() >= max_samples:
			break
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing battle scenario %s." % scenario_id)
			continue
		var encounters: Array = scenario.get("encounters", []) if scenario.get("encounters", []) is Array else []
		if encounters.is_empty():
			deferred.append("%s has no encounter placements for battle sampling." % scenario_id)
			continue
		for encounter in encounters:
			if samples.size() >= max_samples:
				break
			if not (encounter is Dictionary):
				continue
			var sample := _run_battle_sample(scenario_id, encounter)
			if sample.is_empty():
				deferred.append("%s/%s could not create a battle payload." % [scenario_id, String(encounter.get("placement_id", ""))])
			else:
				samples.append(sample)
	var distribution := {}
	for sample in samples:
		var outcome := String(sample.get("outcome_state", "unknown"))
		distribution[outcome] = int(distribution.get(outcome, 0)) + 1
	if samples.size() < 3:
		warnings.append("Battle distribution is a narrow deterministic sample until the deeper Phase 3 runner exists.")
	elif samples.size() < max_samples:
		warnings.append("Battle sampling reached %d/%d requested samples; current authored encounters are sampled narrowly." % [samples.size(), max_samples])
	var status := "warning"
	if samples.is_empty():
		status = "deferred"
	elif warnings.is_empty() and deferred.is_empty():
		status = "pass"
	return _case(
		"battle_resolver_sampling",
		"deterministic_battle_autoplay_samples",
		status,
		{
			"sample_count": samples.size(),
			"requested_sample_limit": max_samples,
			"distribution": distribution,
		},
		{"samples": samples, "distribution": distribution, "warnings": warnings, "deferred": deferred},
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

static func _run_battle_sample(scenario_id: String, encounter: Dictionary) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return {}
	var initial_signature := _signature_for(_battle_signal(session.battle))
	var guard := 0
	var final_state := "continue"
	while guard < 24 and not session.battle.is_empty():
		guard += 1
		var ready_result: Dictionary = BattleRules.resolve_if_battle_ready(session)
		final_state = String(ready_result.get("state", "continue"))
		if final_state not in ["", "continue", "invalid"]:
			break
		if session.battle.is_empty():
			break
		var active_stack: Dictionary = BattleRules.get_active_stack(session.battle)
		if String(active_stack.get("side", "")) != "player":
			continue
		_select_first_living_enemy(session)
		var availability: Dictionary = BattleRules.action_availability(session.battle)
		var action := "defend"
		if bool(availability.get("shoot", false)):
			action = "shoot"
		elif bool(availability.get("strike", false)):
			action = "strike"
		elif bool(availability.get("advance", false)):
			action = "advance"
		var result: Dictionary = BattleRules.perform_player_action(session, action)
		final_state = String(result.get("state", "continue"))
		if final_state not in ["", "continue", "invalid"]:
			break
	return {
		"scenario_id": scenario_id,
		"encounter_placement_id": String(encounter.get("placement_id", "")),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"turns_sampled": guard,
		"outcome_state": final_state,
		"initial_battle_signature": initial_signature,
		"final_signal_signature": _signature_for({
			"state": final_state,
			"battle": _battle_signal(session.battle),
			"status": String(session.scenario_status),
		}),
	}

static func _select_first_living_enemy(session: SessionStateStoreScript.SessionData) -> void:
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) == "enemy" and int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			BattleRules.select_target(session, String(stack.get("battle_id", "")))
			return

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
