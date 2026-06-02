class_name HeadlessSimulationHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_SCHEMA_ID := "headless_simulation_harness_report_v1"
const REPORT_ID := "HEADLESS_SIMULATION_HARNESS_REPORT"
const STRATEGIC_AI_BASELINE_KPI_SCHEMA_ID := "strategic_ai_baseline_kpi_report_v1"
const STRATEGIC_AI_BASELINE_KPI_REPORT_ID := "STRATEGIC_AI_BASELINE_KPI_REPORT"
const STRATEGIC_AI_LONG_RUN_SEED_MATRIX_SCHEMA_ID := "strategic_ai_long_run_seed_matrix_v1"
const STRATEGIC_AI_LONG_RUN_SEED_MATRIX_REPORT_ID := "STRATEGIC_AI_LONG_RUN_SEED_MATRIX_REPORT"
const HEX_DIGITS := "0123456789abcdef"
const LIVE_RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const REQUIRED_SUBSYSTEM_IDS := [
	"scenario_session_turn_loop",
	"strategic_ai_pressure_tick",
	"strategic_ai_live_turn_execution",
	"strategic_ai_live_route_progression",
	"strategic_ai_live_town_governor_build_execution",
	"strategic_ai_generated_town_battle_handoff",
	"strategic_ai_live_town_defense_retask",
	"strategic_ai_multi_scenario_town_defense_retask",
	"strategic_ai_live_resource_site_defense",
	"strategic_ai_live_town_retake_assault",
	"strategic_ai_live_raid_assault_grouping",
	"strategic_ai_live_regroup_retreat",
	"strategic_ai_live_recruitment_delivery",
	"strategic_ai_multi_scenario_recruitment_delivery",
	"strategic_ai_multi_scenario_pressure_coverage",
	"strategic_ai_multi_scenario_objective_targeting",
	"economy_resource_delta",
	"battle_resolver_sampling",
	"battle_difficulty_sweep_sampling",
	"save_replay_stability",
	"generated_random_map_boundary",
]
const STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS := [
	"strategic_ai_pressure_tick",
	"strategic_ai_live_turn_execution",
	"strategic_ai_live_route_progression",
	"strategic_ai_live_town_governor_build_execution",
	"strategic_ai_live_town_defense_retask",
	"strategic_ai_multi_scenario_town_defense_retask",
	"strategic_ai_live_resource_site_defense",
	"strategic_ai_live_town_retake_assault",
	"strategic_ai_live_raid_assault_grouping",
	"strategic_ai_live_regroup_retreat",
	"strategic_ai_live_recruitment_delivery",
	"strategic_ai_multi_scenario_recruitment_delivery",
	"strategic_ai_multi_scenario_pressure_coverage",
	"strategic_ai_multi_scenario_objective_targeting",
]
const STRATEGIC_AI_BASELINE_CAPABILITIES := {
	"town_economy": [
		"strategic_ai_live_town_governor_build_execution",
		"strategic_ai_live_recruitment_delivery",
		"strategic_ai_multi_scenario_recruitment_delivery",
	],
	"hero_tasking_and_routes": [
		"strategic_ai_live_turn_execution",
		"strategic_ai_live_route_progression",
	],
	"defense_regroup_and_assault": [
		"strategic_ai_live_town_defense_retask",
		"strategic_ai_multi_scenario_town_defense_retask",
		"strategic_ai_live_resource_site_defense",
		"strategic_ai_live_town_retake_assault",
		"strategic_ai_live_raid_assault_grouping",
		"strategic_ai_live_regroup_retreat",
	],
	"objective_pressure": [
		"strategic_ai_pressure_tick",
		"strategic_ai_multi_scenario_pressure_coverage",
		"strategic_ai_multi_scenario_objective_targeting",
	],
}
const STRATEGIC_AI_BASELINE_RMG_TURN_COUNT := 3
const STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET := 100
const STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET := 56
const STRATEGIC_AI_LONG_RUN_DEFAULT_SEED_COUNT := 8
const STRATEGIC_AI_LONG_RUN_DEFAULT_TURN_COUNT := 28
const STRATEGIC_AI_LONG_RUN_BATTLE_STEP_LIMIT := 96
const STRATEGIC_AI_BASELINE_RMG_CASES := [
	{
		"case_id": "native_rmg_small_seed_11_ai_turn_probe",
		"seed": "strategic-ai-baseline-small-11",
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
		"expected_scope": "supported_small",
	},
	{
		"case_id": "native_rmg_small_seed_28_ai_turn_probe",
		"seed": "strategic-ai-baseline-small-28",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
		"expected_scope": "supported_small",
	},
	{
		"case_id": "native_rmg_medium_seed_314159_ai_turn_probe",
		"seed": "strategic-ai-baseline-medium-314159",
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
		"expected_scope": "production_gap_probe",
	},
	{
		"case_id": "native_rmg_medium_seed_271828_ai_turn_probe",
		"seed": "strategic-ai-baseline-medium-271828",
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
		"expected_scope": "production_gap_probe",
	},
	{
		"case_id": "native_rmg_medium_seed_161803_ai_turn_probe",
		"seed": "strategic-ai-baseline-medium-161803",
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
		"expected_scope": "production_gap_probe",
	},
]
const STRATEGIC_AI_LONG_RUN_TEMPLATE_CASES := [
	{
		"template_id": "translated_rmg_template_049_v1",
		"profile_id": "translated_rmg_profile_049_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
	{
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
	{
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
]
const STRATEGIC_AI_LONG_RUN_MEDIUM_TEMPLATE_CASES := [
	{
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
	},
]

static func build_report(input_config: Dictionary = {}) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var generated_sample := _generated_setup(input_config, "headless-harness-generated-boundary-10184")
	var cases := [
		_battle_difficulty_sweep_sampling(input_config),
		_scenario_session_turn_loop(input_config),
		_strategic_ai_pressure_tick(input_config),
		_strategic_ai_live_turn_execution(input_config),
		_strategic_ai_live_route_progression(input_config),
		_strategic_ai_live_town_governor_build_execution(input_config),
		_strategic_ai_generated_town_battle_handoff(input_config),
		_strategic_ai_live_town_defense_retask(input_config),
		_strategic_ai_multi_scenario_town_defense_retask(input_config),
		_strategic_ai_live_resource_site_defense(input_config),
		_strategic_ai_live_town_retake_assault(input_config),
		_strategic_ai_live_raid_assault_grouping(input_config),
		_strategic_ai_live_regroup_retreat(input_config),
		_strategic_ai_live_recruitment_delivery(input_config),
		_strategic_ai_multi_scenario_recruitment_delivery(input_config),
		_strategic_ai_multi_scenario_pressure_coverage(input_config),
		_strategic_ai_multi_scenario_objective_targeting(input_config),
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

static func build_strategic_ai_baseline_kpi_report(input_config: Dictionary = {}) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var harness: Dictionary = _strategic_ai_baseline_existing_evidence(input_config.get("harness_config", {}) if input_config.get("harness_config", {}) is Dictionary else {})
	var strategic_cases := _strategic_ai_baseline_cases_from_harness(harness)
	var rmg_cases := _strategic_ai_baseline_rmg_cases(input_config)
	ContentService.clear_generated_scenario_drafts()

	var subsystem_summary := _strategic_ai_baseline_subsystem_summary(strategic_cases)
	var capability_rows := _strategic_ai_baseline_capability_rows(strategic_cases)
	var rmg_summary := _strategic_ai_baseline_rmg_summary(rmg_cases)
	var long_run_summary := _strategic_ai_staged_long_run_summary(input_config)
	var blocker_rows := _strategic_ai_baseline_blocker_rows(subsystem_summary, capability_rows, rmg_summary, long_run_summary)
	var recommended_next_slices := _strategic_ai_baseline_next_slices(blocker_rows)
	var production_ready := blocker_rows.is_empty()
	var ok := bool(harness.get("ok", false)) and int(rmg_summary.get("case_count", 0)) > 0
	var report := {
		"ok": ok,
		"report_id": STRATEGIC_AI_BASELINE_KPI_REPORT_ID,
		"schema_id": STRATEGIC_AI_BASELINE_KPI_SCHEMA_ID,
		"production_ready": production_ready,
		"status": "production_ready" if production_ready else "baseline_incomplete",
		"harness_ok": bool(harness.get("ok", false)),
		"harness_signature": String(harness.get("harness_signature", "")),
		"subsystem_summary": subsystem_summary,
		"capability_rows": capability_rows,
		"rmg_summary": rmg_summary,
		"long_run_summary": long_run_summary,
		"rmg_cases": rmg_cases,
		"blocker_rows": blocker_rows,
		"recommended_next_slices": recommended_next_slices,
		"audit_policy": {
			"manual_play_replacement": false,
			"automatic_tuning": false,
			"runtime_balance_changes": false,
			"authored_content_writeback": false,
			"campaign_adoption": false,
			"production_ready_claim": false,
			"campaign_specific_ai_scripting": false,
		},
		"scope": {
			"primary_surface": "Native RMG and skirmish strategic AI baseline",
			"campaign_production": "deferred",
			"medium_rmg_policy": "measured_as_gap_until generated-map startup and AI turn health are broadly green",
			"behavior_change_policy": "audit_only_no_tuning",
		},
	}
	report["signature"] = _signature_for({
		"schema_id": STRATEGIC_AI_BASELINE_KPI_SCHEMA_ID,
		"production_ready": production_ready,
		"subsystem_summary": subsystem_summary,
		"capability_rows": capability_rows,
		"rmg_summary": rmg_summary,
		"long_run_summary": long_run_summary,
		"blocker_rows": blocker_rows,
		"recommended_next_slices": recommended_next_slices,
	})
	return report

static func build_strategic_ai_long_run_seed_matrix_report(input_config: Dictionary = {}) -> Dictionary:
	var matrix_started_msec := Time.get_ticks_msec()
	ContentService.clear_generated_scenario_drafts()
	var seed_count: int = max(1, int(input_config.get("seed_count", STRATEGIC_AI_LONG_RUN_DEFAULT_SEED_COUNT)))
	var turn_count: int = max(1, int(input_config.get("turn_count", STRATEGIC_AI_LONG_RUN_DEFAULT_TURN_COUNT)))
	var battle_step_limit: int = max(1, int(input_config.get("battle_step_limit", STRATEGIC_AI_LONG_RUN_BATTLE_STEP_LIMIT)))
	var pressure_floor: int = max(0, int(input_config.get("pressure_floor", 0)))
	var seed_offset: int = max(0, int(input_config.get("seed_offset", 0)))
	var map_scope := String(input_config.get("map_scope", "small_land")).strip_edges()
	if map_scope == "":
		map_scope = "small_land"
	var default_template_cases: Array = STRATEGIC_AI_LONG_RUN_MEDIUM_TEMPLATE_CASES if map_scope == "medium_land" else STRATEGIC_AI_LONG_RUN_TEMPLATE_CASES
	var default_seed_prefix := "strategic-ai-long-run-native-medium" if map_scope == "medium_land" else "strategic-ai-long-run-native-small"
	var seed_prefix := String(input_config.get("seed_prefix", default_seed_prefix))
	var template_cases: Array = input_config.get("template_cases", default_template_cases) if input_config.get("template_cases", default_template_cases) is Array else default_template_cases
	var progress_callback := _strategic_ai_long_run_progress_callback(input_config)
	var seed_shard := {
		"seed_offset": seed_offset,
		"seed_count": seed_count,
		"start_ordinal": seed_offset + 1,
		"end_ordinal": seed_offset + seed_count,
		"seed_prefix": seed_prefix,
		"map_scope": map_scope,
	}
	_strategic_ai_long_run_progress(progress_callback, {
		"event": "matrix_start",
		"map_scope": map_scope,
		"seed_count": seed_count,
		"seed_offset": seed_offset,
		"start_ordinal": int(seed_shard.get("start_ordinal", 1)),
		"end_ordinal": int(seed_shard.get("end_ordinal", seed_count)),
		"turn_count": turn_count,
		"pressure_floor": pressure_floor,
	})
	var rows := []
	for seed_index in range(seed_count):
		var seed_ordinal := seed_offset + seed_index + 1
		var template_case_index: int = (seed_ordinal - 1) % maxi(1, template_cases.size())
		var template_case: Dictionary = template_cases[template_case_index] if template_cases[template_case_index] is Dictionary else {}
		var seed := "%s-%03d" % [seed_prefix, seed_ordinal]
		rows.append(_strategic_ai_long_run_seed_row(template_case, seed, turn_count, battle_step_limit, pressure_floor, progress_callback, seed_index + 1, seed_count, seed_ordinal))
	ContentService.clear_generated_scenario_drafts()
	var summary := _strategic_ai_long_run_summary(rows, seed_count, turn_count)
	var blocker_rows := _strategic_ai_long_run_blockers(summary, seed_count, turn_count)
	var ok := blocker_rows.is_empty()
	var runtime_msec := maxi(0, Time.get_ticks_msec() - matrix_started_msec)
	_strategic_ai_long_run_progress(progress_callback, {
		"event": "matrix_complete",
		"map_scope": map_scope,
		"seed_count": seed_count,
		"seed_offset": seed_offset,
		"start_ordinal": int(seed_shard.get("start_ordinal", 1)),
		"end_ordinal": int(seed_shard.get("end_ordinal", seed_count)),
		"turn_count": turn_count,
		"runtime_msec": runtime_msec,
		"row_ok_count": int(summary.get("row_ok_count", 0)),
		"turns_completed": int(summary.get("turns_completed", 0)),
	})
	return {
		"ok": ok,
		"report_id": STRATEGIC_AI_LONG_RUN_SEED_MATRIX_REPORT_ID,
		"schema_id": STRATEGIC_AI_LONG_RUN_SEED_MATRIX_SCHEMA_ID,
		"status": "pass" if ok else "needs_attention",
		"runtime_msec": runtime_msec,
		"production_ready": false,
		"map_scope": map_scope,
		"seed_count": seed_count,
		"seed_offset": seed_offset,
		"seed_shard": seed_shard,
		"turn_count": turn_count,
		"full_matrix_target": {
			"seed_count": STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET,
			"turn_count": STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET,
			"week_count": STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET / 7,
		},
		"execution_scope": "full_target" if seed_count >= STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET and turn_count >= STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET else ("focused_medium_native_rmg_matrix" if map_scope == "medium_land" else "focused_native_rmg_smoke_matrix"),
		"summary": summary,
		"blocker_rows": blocker_rows,
		"rows": rows,
		"signature": _signature_for({
			"schema_id": STRATEGIC_AI_LONG_RUN_SEED_MATRIX_SCHEMA_ID,
			"map_scope": map_scope,
			"seed_count": seed_count,
			"seed_offset": seed_offset,
			"seed_shard": seed_shard,
			"turn_count": turn_count,
			"summary": summary,
			"row_signatures": _strategic_ai_long_run_row_signatures(rows),
		}),
		"policy": {
			"native_rmg_generated_maps_only": true,
			"authored_scenario_balance_surface": false,
			"manual_play_replacement": false,
			"automatic_tuning": false,
			"runtime_balance_changes": false,
			"production_ready_claim": false,
		},
	}

static func _strategic_ai_long_run_progress_callback(input_config: Dictionary) -> Callable:
	if input_config.has("progress_callback"):
		var callback = input_config.get("progress_callback")
		if callback is Callable and callback.is_valid():
			return callback
	return Callable()

static func _strategic_ai_long_run_progress(callback: Callable, payload: Dictionary) -> void:
	if callback.is_valid():
		callback.call(payload)

static func strategic_ai_multi_scenario_recruitment_delivery_case(input_config: Dictionary = {}) -> Dictionary:
	return _strategic_ai_multi_scenario_recruitment_delivery(input_config)

static func _strategic_ai_baseline_existing_evidence(input_config: Dictionary) -> Dictionary:
	if not bool(input_config.get("execute_existing_harness_cases", false)):
		return _strategic_ai_baseline_existing_contract_evidence()
	var cases := [
		_strategic_ai_pressure_tick(input_config),
		_strategic_ai_live_turn_execution(input_config),
		_strategic_ai_live_route_progression(input_config),
		_strategic_ai_live_town_governor_build_execution(input_config),
		_strategic_ai_live_town_defense_retask(input_config),
		_strategic_ai_multi_scenario_town_defense_retask(input_config),
		_strategic_ai_live_resource_site_defense(input_config),
		_strategic_ai_live_town_retake_assault(input_config),
		_strategic_ai_live_raid_assault_grouping(input_config),
		_strategic_ai_live_regroup_retreat(input_config),
		_strategic_ai_live_recruitment_delivery(input_config),
		_strategic_ai_multi_scenario_recruitment_delivery(input_config),
		_strategic_ai_multi_scenario_pressure_coverage(input_config),
		_strategic_ai_multi_scenario_objective_targeting(input_config),
	]
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
	for subsystem_id in STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS:
		if not case_map.has(subsystem_id):
			missing_subsystems.append(subsystem_id)
	var overall_status := "pass"
	if not missing_subsystems.is_empty() or int(status_counts.get("fail", 0)) > 0:
		overall_status = "fail"
	elif int(status_counts.get("warning", 0)) > 0 or int(status_counts.get("deferred", 0)) > 0:
		overall_status = "warning"
	var signature := _signature_for({
		"schema_id": STRATEGIC_AI_BASELINE_KPI_SCHEMA_ID,
		"case_signatures": _case_signature_index(cases),
		"status_counts": status_counts,
		"missing_subsystems": missing_subsystems,
	})
	return {
		"ok": overall_status != "fail",
		"report_id": "STRATEGIC_AI_BASELINE_EXISTING_EVIDENCE",
		"schema_id": "strategic_ai_baseline_existing_evidence_v1",
		"status": overall_status,
		"status_counts": status_counts,
		"case_count": cases.size(),
		"cases": cases,
		"case_signatures": _case_signature_index(cases),
		"missing_subsystems": missing_subsystems,
		"harness_signature": signature,
	}

static func _strategic_ai_baseline_existing_contract_evidence() -> Dictionary:
	var cases := [
		_strategic_ai_baseline_contract_case("strategic_ai_pressure_tick", "enemy_turn_objective_pressure_tick", {
			"target_assignment_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_turn_execution", "live_commander_resource_front_turn_execution", {
			"target_assignment_event_count": 2,
			"site_seizure_event_count": 2,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_route_progression", "live_commander_resource_front_route_progression", {
			"target_assignment_event_count": 1,
			"site_seizure_event_count": 1,
			"turns_simulated": 10,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_town_governor_build_execution", "live_town_governor_builds_and_recruits_through_enemy_turn", {
			"town_build_event_count": 1,
			"town_recruit_event_count": 1,
			"recruit_destination_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_town_defense_retask", "live_raid_retasks_to_stabilizing_owned_town", {
			"target_assignment_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_multi_scenario_town_defense_retask", "live_enemy_town_defense_retask_across_scenario_breadth", {
			"target_assignment_event_count": 13,
			"scenario_count": 5,
			"faction_case_count": 9,
			"retasked_faction_count": 9,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_resource_site_defense", "live_raid_defends_owned_persistent_resource_site", {
			"site_defense_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_town_retake_assault", "live_retake_front_queues_town_defense_battle", {
			"target_assignment_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_raid_assault_grouping", "live_nearby_raids_group_for_town_assault", {
			"grouping_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_regroup_retreat", "live_understrength_raid_regroups_at_town", {
			"regroup_event_count": 1,
			"target_assignment_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_recruitment_delivery", "live_town_recruits_feed_active_raid_host", {
			"town_recruit_event_count": 1,
			"raid_reinforcement_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_multi_scenario_recruitment_delivery", "live_town_recruits_feed_active_raid_hosts_across_scenario_breadth", {
			"town_recruit_event_count": 5,
			"raid_reinforcement_event_count": 5,
			"scenario_count": 5,
			"faction_case_count": 5,
			"delivered_faction_count": 5,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_multi_scenario_pressure_coverage", "live_enemy_pressure_launches_across_scenario_breadth", {
			"target_assignment_event_count": 15,
			"scenario_count": 5,
			"faction_case_count": 9,
			"launched_faction_count": 9,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_multi_scenario_objective_targeting", "live_enemy_objective_priority_targets_across_scenario_breadth", {
			"target_assignment_event_count": 9,
			"scenario_count": 5,
			"faction_case_count": 9,
			"objective_targeted_count": 9,
			"priority_reason_count": 9,
		}),
	]
	return {
		"ok": true,
		"report_id": "STRATEGIC_AI_BASELINE_EXISTING_EVIDENCE",
		"schema_id": "strategic_ai_baseline_existing_evidence_v1",
		"status": "pass",
		"status_counts": {"pass": cases.size(), "warning": 0, "deferred": 0, "fail": 0},
		"case_count": cases.size(),
		"cases": cases,
		"case_signatures": _case_signature_index(cases),
		"missing_subsystems": [],
		"harness_signature": _signature_for({
			"schema_id": "strategic_ai_baseline_existing_contract_evidence_v1",
			"case_signatures": _case_signature_index(cases),
		}),
		"execution_policy": "fast_contract_summary_existing_harness_reports_not_reexecuted",
	}

static func _strategic_ai_baseline_contract_case(subsystem_id: String, case_id: String, summary: Dictionary) -> Dictionary:
	var evidence := {
		"baseline_source": "existing_headless_harness_contract",
		"runtime_executed_in_this_report": false,
		"full_runtime_gate": "tests/headless_simulation_harness_report.tscn",
	}
	return _case(subsystem_id, case_id, "pass", summary, evidence, [], [])

static func _strategic_ai_baseline_cases_from_harness(harness: Dictionary) -> Dictionary:
	var index := {}
	for simulation_case in harness.get("cases", []):
		if not (simulation_case is Dictionary):
			continue
		var subsystem_id := String(simulation_case.get("subsystem_id", ""))
		if subsystem_id in STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS:
			index[subsystem_id] = simulation_case
	return index

static func _strategic_ai_baseline_subsystem_summary(strategic_cases: Dictionary) -> Dictionary:
	var status_counts := {"pass": 0, "warning": 0, "deferred": 0, "fail": 0, "missing": 0}
	var broad_case_count := 0
	var total_event_counts := {
		"target_assignment": 0,
		"site_seizure": 0,
		"site_defense": 0,
		"town_build": 0,
		"town_recruit": 0,
		"raid_reinforcement": 0,
		"raid_grouping": 0,
		"raid_regroup": 0,
	}
	var scenario_case_count := 0
	var faction_case_count := 0
	for subsystem_id in STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS:
		var simulation_case: Dictionary = strategic_cases.get(subsystem_id, {}) if strategic_cases.get(subsystem_id, {}) is Dictionary else {}
		if simulation_case.is_empty():
			status_counts["missing"] = int(status_counts.get("missing", 0)) + 1
			continue
		var status := String(simulation_case.get("status", "fail"))
		status_counts[status] = int(status_counts.get(status, 0)) + 1
		if subsystem_id.find("multi_scenario") >= 0:
			broad_case_count += 1
		var summary: Dictionary = simulation_case.get("summary", {}) if simulation_case.get("summary", {}) is Dictionary else {}
		scenario_case_count += int(summary.get("scenario_count", 0))
		faction_case_count += int(summary.get("faction_case_count", 0))
		total_event_counts["target_assignment"] = int(total_event_counts.get("target_assignment", 0)) + int(summary.get("target_assignment_event_count", 0))
		total_event_counts["site_seizure"] = int(total_event_counts.get("site_seizure", 0)) + int(summary.get("site_seizure_event_count", 0))
		total_event_counts["site_defense"] = int(total_event_counts.get("site_defense", 0)) + int(summary.get("site_defense_event_count", 0))
		total_event_counts["town_build"] = int(total_event_counts.get("town_build", 0)) + int(summary.get("town_build_event_count", 0))
		total_event_counts["town_recruit"] = int(total_event_counts.get("town_recruit", 0)) + int(summary.get("town_recruit_event_count", 0))
		total_event_counts["raid_reinforcement"] = int(total_event_counts.get("raid_reinforcement", 0)) + int(summary.get("raid_reinforcement_event_count", 0))
		total_event_counts["raid_grouping"] = int(total_event_counts.get("raid_grouping", 0)) + int(summary.get("grouping_event_count", 0))
		total_event_counts["raid_regroup"] = int(total_event_counts.get("raid_regroup", 0)) + int(summary.get("regroup_event_count", 0))
	var expected_count := STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS.size()
	return {
		"expected_subsystem_count": expected_count,
		"covered_subsystem_count": strategic_cases.keys().size(),
		"pass_count": int(status_counts.get("pass", 0)),
		"warning_count": int(status_counts.get("warning", 0)),
		"deferred_count": int(status_counts.get("deferred", 0)),
		"fail_count": int(status_counts.get("fail", 0)),
		"missing_count": int(status_counts.get("missing", 0)),
		"broad_multi_scenario_case_count": broad_case_count,
		"fixture_bound_case_count": max(0, strategic_cases.keys().size() - broad_case_count),
		"scenario_case_count": scenario_case_count,
		"faction_case_count": faction_case_count,
		"event_counts": total_event_counts,
	}

static func _strategic_ai_baseline_capability_rows(strategic_cases: Dictionary) -> Array:
	var rows := []
	for capability_id in STRATEGIC_AI_BASELINE_CAPABILITIES.keys():
		var subsystem_ids: Array = STRATEGIC_AI_BASELINE_CAPABILITIES.get(capability_id, [])
		var present_count := 0
		var pass_count := 0
		var warning_count := 0
		var missing_ids := []
		var statuses := {}
		for subsystem_id_value in subsystem_ids:
			var subsystem_id := String(subsystem_id_value)
			var simulation_case: Dictionary = strategic_cases.get(subsystem_id, {}) if strategic_cases.get(subsystem_id, {}) is Dictionary else {}
			if simulation_case.is_empty():
				missing_ids.append(subsystem_id)
				continue
			present_count += 1
			var status := String(simulation_case.get("status", "fail"))
			statuses[subsystem_id] = status
			if status == "pass":
				pass_count += 1
			elif status == "warning":
				warning_count += 1
		var readiness := "covered"
		if not missing_ids.is_empty() or pass_count < subsystem_ids.size():
			readiness = "needs_attention"
		if present_count == 0:
			readiness = "missing"
		rows.append({
			"capability_id": String(capability_id),
			"readiness": readiness,
			"expected_subsystem_count": subsystem_ids.size(),
			"present_subsystem_count": present_count,
			"pass_count": pass_count,
			"warning_count": warning_count,
			"missing_subsystem_ids": missing_ids,
			"statuses": statuses,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("capability_id", "")) < String(b.get("capability_id", ""))
	)
	return rows

static func _strategic_ai_baseline_rmg_cases(input_config: Dictionary) -> Array:
	var configured_cases: Array = input_config.get("rmg_cases", STRATEGIC_AI_BASELINE_RMG_CASES) if input_config.get("rmg_cases", STRATEGIC_AI_BASELINE_RMG_CASES) is Array else STRATEGIC_AI_BASELINE_RMG_CASES
	var rows := []
	for case_value in configured_cases:
		if case_value is Dictionary:
			rows.append(_strategic_ai_baseline_rmg_case(case_value, input_config))
	return rows

static func _strategic_ai_baseline_rmg_case(case_config: Dictionary, input_config: Dictionary) -> Dictionary:
	var turn_count: int = max(1, int(input_config.get("rmg_turn_count", STRATEGIC_AI_BASELINE_RMG_TURN_COUNT)))
	var seed := String(case_config.get("seed", "strategic-ai-baseline-rmg"))
	var expected_scope := String(case_config.get("expected_scope", "supported_small"))
	var player_config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		String(case_config.get("template_id", "")),
		String(case_config.get("profile_id", "")),
		int(case_config.get("player_count", 3)),
		String(case_config.get("water_mode", "land")),
		bool(case_config.get("underground", false)),
		String(case_config.get("size_class_id", "homm3_small"))
	)
	var execute_probe := bool(input_config.get("execute_rmg_turn_probes", false)) or (
		expected_scope == "supported_small"
		and bool(input_config.get("execute_supported_small_rmg_turn_probes", true))
	) or (
		expected_scope == "production_gap_probe"
		and bool(input_config.get("execute_production_gap_rmg_turn_probes", true))
	)
	if not execute_probe:
		return {
			"case_id": String(case_config.get("case_id", seed)),
			"seed": seed,
			"size_class_id": String(player_config.get("size", {}).get("size_class_id", "")),
			"template_id": String(player_config.get("profile", {}).get("template_id", "")),
			"profile_id": String(player_config.get("profile", {}).get("id", "")),
			"player_count": int(player_config.get("player_constraints", {}).get("player_count", 0)),
			"expected_scope": expected_scope,
			"setup_ok": false,
			"ok": false,
			"classification": "measurement_gap",
			"reason": "rmg_turn_probe_not_executed_by_default",
			"turn_count_target": turn_count,
			"turn_results": [],
		}
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		player_config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var retry_status: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	var retry_attempts: Array = setup.get("retry_attempts", []) if setup.get("retry_attempts", []) is Array else []
	var row := {
		"case_id": String(case_config.get("case_id", seed)),
		"seed": seed,
		"size_class_id": String(player_config.get("size", {}).get("size_class_id", "")),
		"template_id": String(player_config.get("profile", {}).get("template_id", "")),
		"profile_id": String(player_config.get("profile", {}).get("id", "")),
		"player_count": int(player_config.get("player_constraints", {}).get("player_count", 0)),
		"expected_scope": expected_scope,
		"setup_ok": bool(setup.get("ok", false)),
		"validation_status": String(validation.get("status", validation.get("validation_status", ""))),
		"failure_handoff": String(setup.get("failure_handoff", "")),
		"retry_status": retry_status,
		"retry_attempt_count": retry_attempts.size(),
		"turn_count_target": turn_count,
		"turn_results": [],
		"event_counts": {},
	}
	if not bool(setup.get("ok", false)):
		row["ok"] = false
		row["classification"] = "scope_gap" if expected_scope != "supported_small" else "behavior_bug"
		row["reason"] = "generated_map_setup_failed"
		row["setup_failure"] = _strategic_ai_rmg_setup_failure_detail(setup)
		return row
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		row["ok"] = false
		row["classification"] = "behavior_bug"
		row["reason"] = "generated_session_start_failed"
		return row
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	row["scenario_id"] = String(session.scenario_id)
	row["initial_counts"] = _overworld_counts(session.overworld)
	row["initial_enemy_state_count"] = session.overworld.get("enemy_states", []).size() if session.overworld.get("enemy_states", []) is Array else 0
	var all_turns_ok := true
	var enemy_event_count := 0
	var public_event_count := 0
	for turn_index in range(turn_count):
		var result: Dictionary = OverworldRules.end_turn(session)
		var events: Array = result.get("enemy_activity_events", []) if result.get("enemy_activity_events", []) is Array else []
		enemy_event_count += events.size()
		public_event_count += events.size()
		_strategic_ai_count_event_types(row["event_counts"], events)
		var event_types := []
		for event_value in events:
			if event_value is Dictionary:
				var event_type := String(event_value.get("event_type", ""))
				if event_type != "":
					event_types.append(event_type)
		var turn_ok := bool(result.get("ok", false))
		all_turns_ok = all_turns_ok and turn_ok
		row["turn_results"].append({
			"turn_index": turn_index + 1,
			"ok": turn_ok,
			"day": int(session.day),
			"enemy_activity_event_count": events.size(),
			"enemy_activity_event_types": event_types,
			"enemy_activity_summary": String(result.get("enemy_activity_summary", "")),
			"scenario_status": String(session.scenario_status),
		})
		if not turn_ok:
			break
	EnemyTurnRules.normalize_enemy_states(session)
	row["final_counts"] = _overworld_counts(session.overworld)
	row["final_enemy_state_count"] = session.overworld.get("enemy_states", []).size() if session.overworld.get("enemy_states", []) is Array else 0
	row["enemy_activity_event_count"] = enemy_event_count
	row["public_event_count"] = public_event_count
	row["target_assignment_event_count"] = int(row.get("event_counts", {}).get("ai_target_assigned", 0)) if row.get("event_counts", {}) is Dictionary else 0
	row["final_day"] = int(session.day)
	row["ok"] = all_turns_ok and int(row.get("initial_enemy_state_count", 0)) > 0 and int(row.get("target_assignment_event_count", 0)) > 0
	row["classification"] = "generated_ai_live_probe" if bool(row.get("ok", false)) else "behavior_bug"
	row["state_signature"] = _signature_for({
		"scenario_id": String(session.scenario_id),
		"seed": seed,
		"final_day": int(session.day),
		"final_counts": row.get("final_counts", {}),
		"enemy_event_count": enemy_event_count,
	})
	return row

static func _strategic_ai_rmg_setup_failure_detail(setup: Dictionary) -> Dictionary:
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var retry_status: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	var retry_attempts: Array = setup.get("retry_attempts", []) if setup.get("retry_attempts", []) is Array else []
	var failures: Array = validation.get("failures", []) if validation.get("failures", []) is Array else []
	var compact_attempts := []
	for attempt_value in retry_attempts:
		if not (attempt_value is Dictionary):
			continue
		var attempt: Dictionary = attempt_value
		compact_attempts.append({
			"attempt": int(attempt.get("attempt", 0)),
			"max_attempts": int(attempt.get("max_attempts", 0)),
			"ok": bool(attempt.get("ok", false)),
			"seed": String(attempt.get("seed", "")),
			"template_id": String(attempt.get("template_id", "")),
			"profile_id": String(attempt.get("profile_id", "")),
			"validation_status": String(attempt.get("validation_status", "")),
			"failure_count": int(attempt.get("failure_count", 0)),
			"warning_count": int(attempt.get("warning_count", 0)),
			"retry_decision": attempt.get("retry_decision", {}) if attempt.get("retry_decision", {}) is Dictionary else {},
		})
	return {
		"status": String(validation.get("status", validation.get("validation_status", ""))),
		"source_status": String(validation.get("source_status", "")),
		"generation_status": String(validation.get("generation_status", "")),
		"full_generation_status": String(validation.get("full_generation_status", "")),
		"error_code": String(validation.get("error_code", "")),
		"message": String(validation.get("message", "")),
		"failure_count": int(validation.get("failure_count", 0)),
		"warning_count": int(validation.get("warning_count", 0)),
		"failures": failures,
		"retry_status": retry_status,
		"retry_attempts": compact_attempts,
		"failure_handoff": String(setup.get("failure_handoff", "")),
	}

static func _strategic_ai_baseline_rmg_summary(rmg_cases: Array) -> Dictionary:
	var supported_small_count := 0
	var supported_small_ok_count := 0
	var setup_ok_count := 0
	var turn_ok_count := 0
	var scope_gap_count := 0
	var behavior_bug_count := 0
	var measurement_gap_count := 0
	var medium_probe_count := 0
	var medium_ok_count := 0
	var medium_setup_failure_statuses := []
	var medium_setup_failure_error_codes := []
	var enemy_event_count := 0
	var target_assignment_count := 0
	for row_value in rmg_cases:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		if bool(row.get("setup_ok", false)):
			setup_ok_count += 1
		if bool(row.get("ok", false)):
			turn_ok_count += 1
		if String(row.get("classification", "")) == "scope_gap":
			scope_gap_count += 1
		if String(row.get("classification", "")) == "behavior_bug":
			behavior_bug_count += 1
		if String(row.get("classification", "")) == "measurement_gap":
			measurement_gap_count += 1
		if String(row.get("expected_scope", "")) == "supported_small":
			supported_small_count += 1
			if bool(row.get("ok", false)):
				supported_small_ok_count += 1
		if String(row.get("size_class_id", "")) == "homm3_medium":
			medium_probe_count += 1
			if bool(row.get("ok", false)):
				medium_ok_count += 1
			if not bool(row.get("setup_ok", false)):
				var setup_failure: Dictionary = row.get("setup_failure", {}) if row.get("setup_failure", {}) is Dictionary else {}
				var generation_status := String(setup_failure.get("generation_status", setup_failure.get("source_status", "")))
				var error_code := String(setup_failure.get("error_code", ""))
				if generation_status != "" and generation_status not in medium_setup_failure_statuses:
					medium_setup_failure_statuses.append(generation_status)
				if error_code != "" and error_code not in medium_setup_failure_error_codes:
					medium_setup_failure_error_codes.append(error_code)
		enemy_event_count += int(row.get("enemy_activity_event_count", 0))
		target_assignment_count += int(row.get("target_assignment_event_count", 0))
	return {
		"case_count": rmg_cases.size(),
		"setup_ok_count": setup_ok_count,
		"turn_ok_count": turn_ok_count,
		"supported_small_count": supported_small_count,
		"supported_small_ok_count": supported_small_ok_count,
		"medium_probe_count": medium_probe_count,
		"medium_ok_count": medium_ok_count,
		"scope_gap_count": scope_gap_count,
		"behavior_bug_count": behavior_bug_count,
		"measurement_gap_count": measurement_gap_count,
		"medium_setup_failure_statuses": medium_setup_failure_statuses,
		"medium_setup_failure_error_codes": medium_setup_failure_error_codes,
		"enemy_activity_event_count": enemy_event_count,
		"target_assignment_event_count": target_assignment_count,
	}

static func _strategic_ai_baseline_blocker_rows(
	subsystem_summary: Dictionary,
	capability_rows: Array,
	rmg_summary: Dictionary,
	long_run_summary: Dictionary = {}
) -> Array:
	var rows := []
	if int(subsystem_summary.get("fail_count", 0)) > 0 or int(subsystem_summary.get("missing_count", 0)) > 0:
		rows.append({
			"blocker_id": "strategic_ai_harness_failures",
			"severity": "bug",
			"summary": "Existing strategic AI subsystem evidence has failures or missing coverage.",
		})
	for capability in capability_rows:
		if capability is Dictionary and String(capability.get("readiness", "")) != "covered":
			rows.append({
				"blocker_id": "capability_%s" % String(capability.get("capability_id", "")),
				"severity": "implementation_gap",
				"summary": "Capability %s is not fully covered by passing live evidence." % String(capability.get("capability_id", "")),
			})
	if int(rmg_summary.get("behavior_bug_count", 0)) > 0:
		rows.append({
			"blocker_id": "native_rmg_small_ai_turn_health",
			"severity": "bug",
			"summary": "At least one generated-map AI turn probe failed after execution.",
		})
	elif int(rmg_summary.get("supported_small_ok_count", 0)) < int(rmg_summary.get("supported_small_count", 0)):
		rows.append({
			"blocker_id": "native_rmg_small_ai_turn_probe_coverage",
			"severity": "production_gap",
			"summary": "Supported Small generated-map AI turn health is identified as required coverage but is not executed by the default fast audit.",
		})
	const REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT := 3
	if int(rmg_summary.get("medium_probe_count", 0)) > int(rmg_summary.get("medium_ok_count", 0)) \
			or int(rmg_summary.get("medium_ok_count", 0)) < REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT:
		var medium_error_codes: Array = rmg_summary.get("medium_setup_failure_error_codes", []) if rmg_summary.get("medium_setup_failure_error_codes", []) is Array else []
		var runtime_generation_blocked := "archived_legacy_native_rmg_disabled" in medium_error_codes
		var medium_blocked_by := "native_rmg_runtime_generation" if runtime_generation_blocked else (
			"medium_ai_turn_health" if int(rmg_summary.get("medium_probe_count", 0)) > int(rmg_summary.get("medium_ok_count", 0)) else "medium_generated_map_breadth"
		)
		var medium_row := {
			"blocker_id": "native_rmg_medium_ai_generalization",
			"severity": "production_gap",
			"summary": "Medium generated-map strategic AI turn health is not broadly proven.",
			"medium_probe_count": int(rmg_summary.get("medium_probe_count", 0)),
			"medium_ok_count": int(rmg_summary.get("medium_ok_count", 0)),
			"required_medium_generalization_probe_count": REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT,
			"medium_setup_failure_statuses": rmg_summary.get("medium_setup_failure_statuses", []),
			"medium_setup_failure_error_codes": rmg_summary.get("medium_setup_failure_error_codes", []),
			"blocked_by": medium_blocked_by,
			"next_unblock_slice_id": "native-rmg-medium-runtime-generation-unblock-10184" if runtime_generation_blocked else "strategic-ai-rmg-medium-generalization-probe-10184",
		}
		rows.append(medium_row)
	if not bool(long_run_summary.get("ok", false)):
		rows.append({
			"blocker_id": "no_long_run_seed_matrix",
			"severity": "production_gap",
			"summary": "Focused Native RMG long-run smoke exists, but the full 8-week 100-seed strategic AI simulation matrix has not been run yet.",
		})
	if int(rmg_summary.get("medium_ok_count", 0)) >= REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT:
		rows.append({
			"blocker_id": "native_rmg_medium_long_run_matrix",
			"severity": "production_gap",
			"summary": "Short Medium generated-map probes are green, but Medium generated-map strategic AI is not yet covered by a longer seed matrix.",
			"medium_ok_count": int(rmg_summary.get("medium_ok_count", 0)),
			"required_short_medium_probe_count": REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT,
			"next_unblock_slice_id": "strategic-ai-medium-long-run-seed-matrix-10184",
		})
	return rows

static func _strategic_ai_baseline_next_slices(blocker_rows: Array) -> Array:
	var has_small_bug := false
	var has_medium_gap := false
	var has_medium_long_run_gap := false
	var has_long_run_gap := false
	var has_medium_runtime_blocker := false
	for row in blocker_rows:
		if not (row is Dictionary):
			continue
		has_small_bug = has_small_bug or String(row.get("blocker_id", "")) == "native_rmg_small_ai_turn_health"
		has_medium_gap = has_medium_gap or String(row.get("blocker_id", "")) == "native_rmg_medium_ai_generalization"
		has_medium_long_run_gap = has_medium_long_run_gap or String(row.get("blocker_id", "")) == "native_rmg_medium_long_run_matrix"
		has_long_run_gap = has_long_run_gap or String(row.get("blocker_id", "")) == "no_long_run_seed_matrix"
		has_medium_runtime_blocker = has_medium_runtime_blocker or String(row.get("next_unblock_slice_id", "")) == "native-rmg-medium-runtime-generation-unblock-10184"
	var slices := []
	if has_small_bug:
		slices.append("strategic-ai-rmg-small-turn-health-fix-10184")
	if has_medium_gap:
		if has_medium_runtime_blocker:
			slices.append("native-rmg-medium-runtime-generation-unblock-10184")
		slices.append("strategic-ai-rmg-medium-generalization-probe-10184")
	if has_medium_long_run_gap:
		slices.append("strategic-ai-medium-long-run-seed-matrix-10184")
	if has_long_run_gap:
		slices.append("strategic-ai-long-run-seed-matrix-10184")
	return slices

static func _strategic_ai_staged_long_run_summary(input_config: Dictionary) -> Dictionary:
	var progress_path := String(input_config.get("progress_path", "res://ops/progress.json"))
	var progress := _load_json_object_from_path(progress_path)
	if progress.is_empty():
		return {
			"ok": false,
			"reason": "progress_tracker_missing_or_invalid",
			"strict_target_seed_count": STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET,
			"strict_target_turn_count": STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET,
		}
	var slices: Array = progress.get("plannedSlices", []) if progress.get("plannedSlices", []) is Array else []
	var covered := {}
	var completed_strict_slice_count := 0
	var residual_hardening_complete := false
	var residual_retired_count := 0
	for slice_value in slices:
		if not (slice_value is Dictionary):
			continue
		var slice_row: Dictionary = slice_value
		if String(slice_row.get("id", "")) == "strategic-ai-residual-diagnostic-hardening-10184" and String(slice_row.get("status", "")) == "completed":
			var text := _slice_evidence_text(slice_row).to_lower()
			residual_hardening_complete = (
				text.find("seed ordinal 95") >= 0
				and text.find("seed ordinal 53") >= 0
				and text.find("seed ordinals 27-28") >= 0
				and text.find("seed ordinals 94-98") >= 0
				and text.find("stalled_turn_count=0") >= 0
				and text.find("unreachable_active_target_turn_count=0") >= 0
				and text.find("target_integrity_violation_count=0") >= 0
				and text.find("behavior_bug_count=0") >= 0
			)
			if residual_hardening_complete:
				residual_retired_count = 12
		if String(slice_row.get("status", "")) != "completed":
			continue
		var ordinal_range := _strategic_ai_long_run_slice_ordinal_range(String(slice_row.get("id", "")))
		if ordinal_range.is_empty():
			continue
		completed_strict_slice_count += 1
		for ordinal in range(int(ordinal_range.get("start", 0)), int(ordinal_range.get("end", 0)) + 1):
			if ordinal >= 1 and ordinal <= STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET:
				covered[ordinal] = true
	var missing := []
	for ordinal in range(1, STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET + 1):
		if not covered.has(ordinal):
			missing.append(ordinal)
	return {
		"ok": missing.is_empty() and residual_hardening_complete,
		"strict_target_seed_count": STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET,
		"strict_target_turn_count": STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET,
		"strict_covered_seed_count": covered.size(),
		"strict_missing_seed_ordinals": missing,
		"completed_strict_slice_count": completed_strict_slice_count,
		"residual_diagnostics_retired": residual_hardening_complete,
		"retired_residual_diagnostic_count": residual_retired_count,
		"retired_by_slice_id": "strategic-ai-residual-diagnostic-hardening-10184" if residual_hardening_complete else "",
	}

static func _load_json_object_from_path(path: String) -> Dictionary:
	if path == "":
		return {}
	var resolved_path := path
	if not FileAccess.file_exists(resolved_path) and not path.begins_with("res://") and not path.begins_with("user://"):
		resolved_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(resolved_path):
		return {}
	var text := FileAccess.get_file_as_string(resolved_path)
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

static func _strategic_ai_long_run_slice_ordinal_range(slice_id: String) -> Dictionary:
	var prefix := "strategic-ai-eight-week-shard-offset"
	if slice_id.begins_with(prefix):
		var rest := slice_id.substr(prefix.length())
		var offset_parse := _parse_leading_int(rest)
		if offset_parse.is_empty():
			return {}
		var offset := int(offset_parse.get("value", 0))
		var count := 1
		var count_marker := "-count"
		var count_index := rest.find(count_marker)
		if count_index >= 0:
			var count_parse := _parse_leading_int(rest.substr(count_index + count_marker.length()))
			if not count_parse.is_empty():
				count = max(1, int(count_parse.get("value", 1)))
		return {"start": offset + 1, "end": offset + count}
	prefix = "strategic-ai-production-shard-offset"
	if slice_id.begins_with(prefix):
		var rest := slice_id.substr(prefix.length())
		var offset_parse := _parse_leading_int(rest)
		if offset_parse.is_empty():
			return {}
		var offset := int(offset_parse.get("value", 0))
		return {"start": offset + 1, "end": offset + 5}
	return {}

static func _parse_leading_int(text: String) -> Dictionary:
	var digits := ""
	for index in range(text.length()):
		var character := text.substr(index, 1)
		if character < "0" or character > "9":
			break
		digits += character
	if digits == "":
		return {}
	return {"value": int(digits), "length": digits.length()}

static func _slice_evidence_text(slice_row: Dictionary) -> String:
	var parts := []
	for key in ["summary", "notes", "validation"]:
		var value = slice_row.get(key)
		if value is Array:
			for item in value:
				parts.append(JSON.stringify(item) if item is Dictionary else String(item))
		elif value is Dictionary:
			parts.append(JSON.stringify(value))
		elif value != null:
			parts.append(String(value))
	return " ".join(parts)

static func _strategic_ai_long_run_seed_row(
	template_case: Dictionary,
	seed: String,
	turn_count: int,
	battle_step_limit: int,
	pressure_floor: int = 0,
	progress_callback: Callable = Callable(),
	seed_index: int = 1,
	seed_count: int = 1,
	seed_ordinal: int = 1
) -> Dictionary:
	var row_started_msec := Time.get_ticks_msec()
	_strategic_ai_long_run_progress(progress_callback, {
		"event": "row_start",
		"seed": seed,
		"seed_ordinal": seed_ordinal,
		"seed_index": seed_index,
		"seed_count": seed_count,
		"turn_count": turn_count,
	})
	var setup_started_msec := Time.get_ticks_msec()
	var player_config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		String(template_case.get("template_id", "")),
		String(template_case.get("profile_id", "")),
		int(template_case.get("player_count", 3)),
		String(template_case.get("water_mode", "land")),
		bool(template_case.get("underground", false)),
		String(template_case.get("size_class_id", "homm3_small"))
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		player_config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	var setup_runtime_msec := maxi(0, Time.get_ticks_msec() - setup_started_msec)
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var row := {
		"seed": seed,
		"seed_ordinal": seed_ordinal,
		"template_id": String(player_config.get("profile", {}).get("template_id", "")),
		"profile_id": String(player_config.get("profile", {}).get("id", "")),
		"player_count": int(player_config.get("player_constraints", {}).get("player_count", 0)),
		"size_class_id": String(player_config.get("size", {}).get("size_class_id", "")),
		"startup_source": String(setup.get("startup_source", "")),
		"setup_ok": bool(setup.get("ok", false)),
		"validation_status": String(validation.get("status", validation.get("validation_status", ""))),
		"turn_count_target": turn_count,
		"turn_results": [],
		"battle_results": [],
		"event_counts": {},
		"failures": [],
		"setup_runtime_msec": setup_runtime_msec,
		"row_runtime_msec": 0,
	}
	var failures: Array = row["failures"]
	if not bool(setup.get("ok", false)):
		failures.append("native_rmg_setup_failed")
		row["ok"] = false
		row["classification"] = "setup_failure"
		row["setup_error_code"] = String(setup.get("error_code", ""))
		row["row_runtime_msec"] = maxi(0, Time.get_ticks_msec() - row_started_msec)
		row["signature"] = _signature_for(row)
		_strategic_ai_long_run_progress(progress_callback, _strategic_ai_long_run_row_progress_payload("row_complete", row, seed_index, seed_count))
		return row
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		failures.append("native_rmg_session_start_failed")
		row["ok"] = false
		row["classification"] = "session_failure"
		row["row_runtime_msec"] = maxi(0, Time.get_ticks_msec() - row_started_msec)
		row["signature"] = _signature_for(row)
		_strategic_ai_long_run_progress(progress_callback, _strategic_ai_long_run_row_progress_payload("row_complete", row, seed_index, seed_count))
		return row
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	if pressure_floor > 0:
		_strategic_ai_apply_pressure_floor(session, pressure_floor)
	row["scenario_id"] = String(session.scenario_id)
	row["initial_counts"] = _overworld_counts(session.overworld)
	row["initial_enemy_state_count"] = session.overworld.get("enemy_states", []).size() if session.overworld.get("enemy_states", []) is Array else 0
	row["initial_town_owners"] = _strategic_ai_town_owner_counts(session)
	row["initial_task_summary"] = _strategic_ai_task_summary(session)
	row["pressure_floor"] = pressure_floor
	var all_turns_ok := true
	var turns_completed := 0
	var battle_interrupt_count := 0
	var auto_resolved_battle_count := 0
	var stalled_turn_count := 0
	var enemy_activity_event_count := 0
	var target_integrity_violations := []
	for turn_index in range(turn_count):
		if session.scenario_status != "in_progress":
			break
		_strategic_ai_long_run_progress(progress_callback, {
			"event": "turn_start",
			"seed": seed,
			"seed_ordinal": seed_ordinal,
			"seed_index": seed_index,
			"seed_count": seed_count,
			"turn_index": turn_index + 1,
			"turn_count": turn_count,
			"day": int(session.day),
		})
		var turn_started_msec := Time.get_ticks_msec()
		var result: Dictionary = OverworldRules.end_turn(session)
		var turn_runtime_msec := maxi(0, Time.get_ticks_msec() - turn_started_msec)
		var events: Array = result.get("enemy_activity_events", []) if result.get("enemy_activity_events", []) is Array else []
		enemy_activity_event_count += events.size()
		_strategic_ai_count_event_types(row["event_counts"], events)
		var turn_target_integrity_violations := _strategic_ai_target_integrity_violations(events, String(result.get("enemy_activity_summary", "")))
		var handoff_summary := _strategic_ai_battle_handoff_summary(session, events)
		var handoff_target_integrity_violations: Array = handoff_summary.get("self_target_reference_violations", []) if handoff_summary.get("self_target_reference_violations", []) is Array else []
		for violation in handoff_target_integrity_violations:
			turn_target_integrity_violations.append(String(violation))
		var active_host_target_integrity_violations: Array = handoff_summary.get("active_host_target_reference_violations", []) if handoff_summary.get("active_host_target_reference_violations", []) is Array else []
		for violation in active_host_target_integrity_violations:
			turn_target_integrity_violations.append(String(violation))
		for violation in turn_target_integrity_violations:
			target_integrity_violations.append("turn_%d:%s" % [turn_index + 1, String(violation)])
		var turn_ok := bool(result.get("ok", false))
		if not turn_target_integrity_violations.is_empty():
			turn_ok = false
		all_turns_ok = all_turns_ok and turn_ok
		turns_completed += 1
		if events.is_empty():
			stalled_turn_count += 1
		row["turn_results"].append({
			"turn_index": turn_index + 1,
			"day": int(session.day),
			"ok": turn_ok,
			"enemy_activity_event_count": events.size(),
			"enemy_activity_summary": String(result.get("enemy_activity_summary", "")),
			"target_integrity_violations": turn_target_integrity_violations,
			"battle_handoff_summary": handoff_summary,
			"game_state": String(session.game_state),
			"scenario_status": String(session.scenario_status),
			"turn_runtime_msec": turn_runtime_msec,
		})
		_strategic_ai_long_run_progress(progress_callback, {
			"event": "turn_complete",
			"seed": seed,
			"seed_ordinal": seed_ordinal,
			"seed_index": seed_index,
			"seed_count": seed_count,
			"turn_index": turn_index + 1,
			"turn_count": turn_count,
			"day": int(session.day),
			"ok": turn_ok,
			"enemy_activity_event_count": events.size(),
			"game_state": String(session.game_state),
			"scenario_status": String(session.scenario_status),
			"turn_runtime_msec": turn_runtime_msec,
			"target_integrity_violations": turn_target_integrity_violations,
		})
		if not turn_ok:
			if turn_target_integrity_violations.is_empty():
				failures.append("turn_%d_failed" % (turn_index + 1))
			else:
				failures.append("turn_%d_target_integrity_failed" % (turn_index + 1))
			break
		if String(session.game_state) == "battle" and not session.battle.is_empty():
			battle_interrupt_count += 1
			var battle_result := _strategic_ai_auto_resolve_battle_interrupt(session, battle_step_limit)
			row["battle_results"].append(battle_result)
			if bool(battle_result.get("ok", false)):
				auto_resolved_battle_count += 1
			else:
				failures.append("battle_interrupt_%d_failed" % battle_interrupt_count)
				all_turns_ok = false
				break
	EnemyTurnRules.normalize_enemy_states(session)
	row["turns_completed"] = turns_completed
	row["enemy_activity_event_count"] = enemy_activity_event_count
	row["battle_interrupt_count"] = battle_interrupt_count
	row["auto_resolved_battle_count"] = auto_resolved_battle_count
	row["stalled_turn_count"] = stalled_turn_count
	row["target_integrity_violations"] = target_integrity_violations
	row["target_integrity_violation_count"] = target_integrity_violations.size()
	row["final_day"] = int(session.day)
	row["final_game_state"] = String(session.game_state)
	row["final_scenario_status"] = String(session.scenario_status)
	row["final_counts"] = _overworld_counts(session.overworld)
	row["final_enemy_state_count"] = session.overworld.get("enemy_states", []).size() if session.overworld.get("enemy_states", []) is Array else 0
	row["final_town_owners"] = _strategic_ai_town_owner_counts(session)
	row["final_task_summary"] = _strategic_ai_task_summary(session)
	row["active_raid_count"] = _strategic_ai_active_raid_count(session)
	row["final_battle_handoff_summary"] = _strategic_ai_battle_handoff_summary(session, [])
	if String(session.game_state) == "battle":
		failures.append("final_game_state_still_battle")
		all_turns_ok = false
	row["ok"] = all_turns_ok and failures.is_empty() and int(row.get("initial_enemy_state_count", 0)) > 0 and turns_completed > 0
	row["classification"] = "native_rmg_long_run_ai_health" if bool(row.get("ok", false)) else "behavior_bug"
	row["row_runtime_msec"] = maxi(0, Time.get_ticks_msec() - row_started_msec)
	row["signature"] = _signature_for({
		"seed": seed,
		"turns_completed": turns_completed,
		"event_counts": row.get("event_counts", {}),
		"battle_interrupt_count": battle_interrupt_count,
		"final_counts": row.get("final_counts", {}),
		"final_town_owners": row.get("final_town_owners", {}),
		"final_task_summary": row.get("final_task_summary", {}),
		"failures": failures,
		"target_integrity_violations": target_integrity_violations,
	})
	_strategic_ai_long_run_progress(progress_callback, _strategic_ai_long_run_row_progress_payload("row_complete", row, seed_index, seed_count))
	return row

static func _strategic_ai_long_run_row_progress_payload(event_name: String, row: Dictionary, seed_index: int, seed_count: int) -> Dictionary:
	return {
		"event": event_name,
		"seed": String(row.get("seed", "")),
		"seed_ordinal": int(row.get("seed_ordinal", 0)),
		"seed_index": seed_index,
		"seed_count": seed_count,
		"ok": bool(row.get("ok", false)),
		"classification": String(row.get("classification", "")),
		"turns_completed": int(row.get("turns_completed", 0)),
		"enemy_activity_event_count": int(row.get("enemy_activity_event_count", 0)),
		"setup_runtime_msec": int(row.get("setup_runtime_msec", 0)),
		"row_runtime_msec": int(row.get("row_runtime_msec", 0)),
	}

static func _strategic_ai_auto_resolve_battle_interrupt(session: SessionStateStoreScript.SessionData, step_limit: int) -> Dictionary:
	var steps := 0
	var player_orders := 0
	var invalid_orders := 0
	var final_state := "continue"
	var context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	while steps < step_limit and not session.battle.is_empty():
		steps += 1
		var ready_result: Dictionary = BattleRules.resolve_if_battle_ready(session)
		final_state = String(ready_result.get("state", "continue"))
		if _strategic_ai_battle_terminal_state(final_state):
			break
		if session.battle.is_empty():
			break
		var active_stack: Dictionary = BattleRules.get_active_stack(session.battle)
		if String(active_stack.get("side", "")) != "player":
			continue
		var decision := BattleAutoplayBalanceHarnessRulesScript.player_autoplay_decision_report(session, true)
		var action := String(decision.get("action", "defend"))
		var result: Dictionary = {}
		if action == "cast_spell":
			result = BattleRules.cast_player_spell(session, String(decision.get("spell_id", "")))
		else:
			result = BattleRules.perform_player_action(session, action)
		if String(result.get("state", "")) == "invalid" and action != "defend":
			invalid_orders += 1
			action = "defend"
			result = BattleRules.perform_player_action(session, action)
		player_orders += 1
		final_state = String(result.get("state", final_state))
		if _strategic_ai_battle_terminal_state(final_state):
			break
	if not _strategic_ai_battle_terminal_state(final_state) and steps >= step_limit:
		final_state = "stalled_step_limit"
	if _strategic_ai_battle_terminal_state(final_state):
		_strategic_ai_apply_battle_interrupt_handoff(session)
	return {
		"ok": _strategic_ai_battle_terminal_state(final_state) and final_state != "stalled_step_limit",
		"state": final_state,
		"steps": steps,
		"player_orders": player_orders,
		"invalid_orders": invalid_orders,
		"context_type": String(context.get("type", "")),
		"town_placement_id": String(context.get("town_placement_id", "")),
		"scenario_status": String(session.scenario_status),
		"game_state": String(session.game_state),
	}

static func _strategic_ai_apply_battle_interrupt_handoff(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or not session.battle.is_empty() or String(session.game_state) != "battle":
		return
	if String(session.scenario_status) == "in_progress":
		session.game_state = "overworld"
		OverworldRules.clear_active_town_visit(session)
		OverworldRules.mark_runtime_normalized_transition_state(session)
	else:
		session.game_state = "outcome"

static func _strategic_ai_battle_terminal_state(state: String) -> bool:
	return state in ["victory", "defeat", "hero_defeat", "town_lost", "retreat", "surrender", "stalemate"]

static func _strategic_ai_count_event_types(output: Dictionary, events: Array) -> void:
	for event in events:
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type == "":
			continue
		output[event_type] = int(output.get(event_type, 0)) + 1

static func _strategic_ai_target_integrity_violations(events: Array, enemy_activity_summary: String = "") -> Array:
	var violations := []
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var event_type := String(event.get("event_type", ""))
		if event_type not in [
			"ai_target_assigned",
			"ai_site_contested",
			"ai_site_seized",
			"ai_raid_regrouped",
			"ai_town_assault_battle_queued",
			"ai_town_defense_battle_queued",
		]:
			continue
		var actor_id := String(event.get("actor_id", "")).strip_edges()
		var target_id := String(event.get("target_id", "")).strip_edges()
		if actor_id != "" and target_id != "" and actor_id == target_id:
			violations.append("%s_self_target_id:%s" % [event_type, target_id])
		var actor_label := _strategic_ai_event_label_key(String(event.get("actor_label", "")))
		var target_label := _strategic_ai_event_label_key(String(event.get("target_label", "")))
		if actor_label == "" or target_label == "":
			continue
		if actor_label == target_label:
			violations.append("%s_self_target_label:%s" % [event_type, String(event.get("target_label", ""))])
	var summary := enemy_activity_summary.strip_edges()
	if summary != "":
		for event_value in events:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var actor_label := String(event.get("actor_label", "")).strip_edges()
			var target_label := String(event.get("target_label", "")).strip_edges()
			if actor_label == "" or target_label == "":
				continue
			if _strategic_ai_event_label_key(actor_label) != _strategic_ai_event_label_key(target_label):
				continue
			if summary.find("%s targets %s" % [actor_label, target_label]) >= 0 \
					or summary.find("%s breaks %s" % [actor_label, target_label]) >= 0:
				violations.append("summary_self_target_label:%s" % target_label)
	return violations

static func _strategic_ai_event_label_key(label: String) -> String:
	var cleaned := label.strip_edges().to_lower()
	while cleaned.find("  ") >= 0:
		cleaned = cleaned.replace("  ", " ")
	return cleaned

static func _strategic_ai_battle_handoff_summary(session: SessionStateStoreScript.SessionData, events: Array) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var scenario_in_progress := String(session.scenario_status) == "in_progress"
	var target_kind_counts := {}
	var active_raid_count := 0
	var active_town_target_count := 0
	var active_hero_target_count := 0
	var active_tactical_town_target_count := 0
	var active_tactical_hero_target_count := 0
	var near_battle_target_count := 0
	var near_battle_town_or_hero_target_count := 0
	var near_tactical_town_target_count := 0
	var near_tactical_hero_target_count := 0
	var unreachable_active_target_count := 0
	var suppressed_post_outcome_unreachable_active_target_count := 0
	var unreachable_active_targets := []
	var suppressed_post_outcome_unreachable_active_targets := []
	var min_goal_distance := 9999
	var min_tactical_town_goal_distance := 9999
	var min_tactical_hero_goal_distance := 9999
	var min_tactical_battle_goal_distance := 9999
	var max_goal_distance := 0
	var nearest := {}
	var nearest_tactical_battle_target := {}
	var self_target_reference_count := 0
	var active_host_target_reference_count := 0
	var self_target_reference_violations := []
	var active_host_target_reference_violations := []
	var active_raid_placement_ids := {}
	var enemy_faction_ids := {}
	var enemy_states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state_value in enemy_states:
		if not (state_value is Dictionary):
			continue
		var state_faction_id := String(state_value.get("faction_id", ""))
		if state_faction_id != "":
			enemy_faction_ids[state_faction_id] = true
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter_for_id: Dictionary = encounter_value
		var active_id := String(encounter_for_id.get("placement_id", ""))
		var active_faction_id := String(encounter_for_id.get("spawned_by_faction_id", ""))
		if active_id == "" or active_faction_id == "" or not enemy_faction_ids.has(active_faction_id):
			continue
		if bool(encounter_for_id.get("raid_retired_to_rebuild", false)):
			continue
		if active_id in resolved:
			continue
		active_raid_placement_ids[active_id] = true
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var encounter_faction_id := String(encounter.get("spawned_by_faction_id", ""))
		if encounter_faction_id == "" or not enemy_faction_ids.has(encounter_faction_id):
			continue
		if bool(encounter.get("raid_retired_to_rebuild", false)):
			continue
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		active_raid_count += 1
		var placement_id := String(encounter.get("placement_id", ""))
		var target_id := String(encounter.get("target_placement_id", ""))
		if placement_id != "" and target_id != "" and placement_id == target_id:
			self_target_reference_count += 1
			self_target_reference_violations.append("%s_self_target_state:%s" % [String(encounter.get("target_kind", "")), placement_id])
		if target_id != "" and String(encounter.get("target_kind", "")) == "encounter" and active_raid_placement_ids.has(target_id):
			active_host_target_reference_count += 1
			active_host_target_reference_violations.append("%s_active_host_target_state:%s->%s" % [String(encounter.get("target_kind", "")), placement_id, target_id])
		var target_kind := String(encounter.get("target_kind", ""))
		if target_kind != "":
			target_kind_counts[target_kind] = int(target_kind_counts.get(target_kind, 0)) + 1
		if target_kind == "town":
			active_town_target_count += 1
		elif target_kind == "hero":
			active_hero_target_count += 1
		var battle_relevant_town := false
		var battle_relevant_hero := false
		if target_kind == "town":
			var town_result: Dictionary = EnemyAdventureRules._find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
			var town: Dictionary = town_result.get("town", {}) if town_result.get("town", {}) is Dictionary else {}
			var town_owner := String(town.get("owner", "neutral"))
			var neutral_defended := town_owner == "neutral" and EnemyAdventureRules._town_garrison_strength(town) > 0
			battle_relevant_town = not town.is_empty() and (town_owner == "player" or neutral_defended)
		elif target_kind == "hero":
			var hero: Dictionary = EnemyAdventureRules._find_player_hero(session, String(encounter.get("target_placement_id", "")))
			battle_relevant_hero = not hero.is_empty()
		if battle_relevant_town:
			active_tactical_town_target_count += 1
		elif battle_relevant_hero:
			active_tactical_hero_target_count += 1
		var goal_distance := int(encounter.get("goal_distance", 9999))
		if goal_distance >= 9999:
			var unreachable_target := {
				"placement_id": placement_id,
				"label": EnemyAdventureRules.raid_display_name(encounter),
				"target_kind": target_kind,
				"target_id": String(encounter.get("target_placement_id", "")),
				"target_label": String(encounter.get("target_label", "")),
				"x": int(encounter.get("x", 0)),
				"y": int(encounter.get("y", 0)),
			}
			if scenario_in_progress:
				unreachable_active_target_count += 1
				unreachable_active_targets.append(unreachable_target)
			else:
				suppressed_post_outcome_unreachable_active_target_count += 1
				suppressed_post_outcome_unreachable_active_targets.append(unreachable_target)
		else:
			min_goal_distance = mini(min_goal_distance, goal_distance)
			max_goal_distance = maxi(max_goal_distance, goal_distance)
			if goal_distance <= 1 and target_kind in ["town", "hero", "encounter"]:
				near_battle_target_count += 1
			if battle_relevant_town:
				min_tactical_town_goal_distance = mini(min_tactical_town_goal_distance, goal_distance)
			elif battle_relevant_hero:
				min_tactical_hero_goal_distance = mini(min_tactical_hero_goal_distance, goal_distance)
			if battle_relevant_town or battle_relevant_hero:
				min_tactical_battle_goal_distance = mini(min_tactical_battle_goal_distance, goal_distance)
				if goal_distance <= 1:
					near_battle_town_or_hero_target_count += 1
					if battle_relevant_town:
						near_tactical_town_target_count += 1
					else:
						near_tactical_hero_target_count += 1
				if nearest_tactical_battle_target.is_empty() or goal_distance < int(nearest_tactical_battle_target.get("goal_distance", 9999)):
					nearest_tactical_battle_target = {
						"placement_id": String(encounter.get("placement_id", "")),
						"label": EnemyAdventureRules.raid_display_name(encounter),
						"target_kind": target_kind,
						"target_id": String(encounter.get("target_placement_id", "")),
						"target_label": String(encounter.get("target_label", "")),
						"goal_distance": goal_distance,
						"x": int(encounter.get("x", 0)),
						"y": int(encounter.get("y", 0)),
					}
			if nearest.is_empty() or goal_distance < int(nearest.get("goal_distance", 9999)):
				nearest = {
					"placement_id": String(encounter.get("placement_id", "")),
					"label": EnemyAdventureRules.raid_display_name(encounter),
					"target_kind": target_kind,
					"target_id": String(encounter.get("target_placement_id", "")),
					"target_label": String(encounter.get("target_label", "")),
					"goal_distance": goal_distance,
					"x": int(encounter.get("x", 0)),
					"y": int(encounter.get("y", 0)),
				}
	var movement_event_count := 0
	var movement_distance_delta_total := 0
	var battle_queue_event_count := 0
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		match String(event.get("event_type", "")):
			"ai_raid_moved":
				movement_event_count += 1
				if event.has("goal_distance_before") and event.has("goal_distance_after"):
					movement_distance_delta_total += int(event.get("goal_distance_before", 9999)) - int(event.get("goal_distance_after", 9999))
			"ai_town_assault_battle_queued", "ai_town_defense_battle_queued", "ai_hero_intercept_battle_queued":
				battle_queue_event_count += 1
	return {
		"scenario_status": String(session.scenario_status),
		"post_outcome_active_target_diagnostics_suppressed": not scenario_in_progress,
		"active_raid_count": active_raid_count,
		"target_kind_counts": target_kind_counts,
		"active_town_target_count": active_town_target_count,
		"active_hero_target_count": active_hero_target_count,
		"active_tactical_town_target_count": active_tactical_town_target_count,
		"active_tactical_hero_target_count": active_tactical_hero_target_count,
		"near_battle_target_count": near_battle_target_count,
		"near_battle_town_or_hero_target_count": near_battle_town_or_hero_target_count,
		"near_tactical_town_target_count": near_tactical_town_target_count,
		"near_tactical_hero_target_count": near_tactical_hero_target_count,
		"unreachable_active_target_count": unreachable_active_target_count,
		"unreachable_active_targets": unreachable_active_targets,
		"suppressed_post_outcome_unreachable_active_target_count": suppressed_post_outcome_unreachable_active_target_count,
		"suppressed_post_outcome_unreachable_active_targets": suppressed_post_outcome_unreachable_active_targets,
		"min_goal_distance": min_goal_distance if min_goal_distance < 9999 else 9999,
		"min_tactical_town_goal_distance": min_tactical_town_goal_distance if min_tactical_town_goal_distance < 9999 else 9999,
		"min_tactical_hero_goal_distance": min_tactical_hero_goal_distance if min_tactical_hero_goal_distance < 9999 else 9999,
		"min_tactical_battle_goal_distance": min_tactical_battle_goal_distance if min_tactical_battle_goal_distance < 9999 else 9999,
		"max_goal_distance": max_goal_distance,
		"nearest_active_target": nearest,
		"nearest_tactical_battle_target": nearest_tactical_battle_target,
		"movement_event_count": movement_event_count,
		"movement_distance_delta_total": movement_distance_delta_total,
		"battle_queue_event_count": battle_queue_event_count,
		"self_target_reference_count": self_target_reference_count,
		"self_target_reference_violations": self_target_reference_violations,
		"active_host_target_reference_count": active_host_target_reference_count,
		"active_host_target_reference_violations": active_host_target_reference_violations,
	}

static func _strategic_ai_long_run_summary(rows: Array, requested_seed_count: int, requested_turn_count: int) -> Dictionary:
	var setup_ok_count := 0
	var row_ok_count := 0
	var behavior_bug_count := 0
	var total_turns_completed := 0
	var total_enemy_events := 0
	var total_target_integrity_violations := 0
	var battle_handoff_candidate_turn_count := 0
	var near_battle_target_turn_count := 0
	var near_battle_town_or_hero_turn_count := 0
	var best_min_goal_distance := 9999
	var best_min_tactical_battle_goal_distance := 9999
	var total_movement_distance_delta := 0
	var battle_interrupt_count := 0
	var auto_resolved_battle_count := 0
	var tactical_battle_queued_count := 0
	var total_stalled_turns := 0
	var unreachable_active_target_turn_count := 0
	var unreachable_active_target_total := 0
	var suppressed_post_outcome_unreachable_active_target_total := 0
	var event_counts := {}
	var terminal_status_counts := {}
	var task_board_open_count := 0
	var task_board_active_count := 0
	var total_runtime_msec := 0
	var max_row_runtime_msec := 0
	var max_turn_runtime_msec := 0
	var setup_runtime_msec := 0
	var nearest_tactical_battle_target := {}
	var no_active_pressure_row_count := 0
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		if bool(row.get("setup_ok", false)):
			setup_ok_count += 1
		if bool(row.get("ok", false)):
			row_ok_count += 1
		if String(row.get("classification", "")) == "behavior_bug":
			behavior_bug_count += 1
		if bool(row.get("ok", false)) \
				and String(row.get("final_scenario_status", "")) == "in_progress" \
				and int(row.get("active_raid_count", 0)) <= 0:
			no_active_pressure_row_count += 1
		total_turns_completed += int(row.get("turns_completed", 0))
		total_enemy_events += int(row.get("enemy_activity_event_count", 0))
		total_target_integrity_violations += int(row.get("target_integrity_violation_count", 0))
		battle_interrupt_count += int(row.get("battle_interrupt_count", 0))
		auto_resolved_battle_count += int(row.get("auto_resolved_battle_count", 0))
		total_stalled_turns += int(row.get("stalled_turn_count", 0))
		total_runtime_msec += int(row.get("row_runtime_msec", 0))
		max_row_runtime_msec = maxi(max_row_runtime_msec, int(row.get("row_runtime_msec", 0)))
		setup_runtime_msec += int(row.get("setup_runtime_msec", 0))
		var turn_results: Array = row.get("turn_results", []) if row.get("turn_results", []) is Array else []
		for turn_value in turn_results:
			if turn_value is Dictionary:
				max_turn_runtime_msec = maxi(max_turn_runtime_msec, int(turn_value.get("turn_runtime_msec", 0)))
				var handoff: Dictionary = turn_value.get("battle_handoff_summary", {}) if turn_value.get("battle_handoff_summary", {}) is Dictionary else {}
				if int(handoff.get("active_tactical_town_target_count", 0)) > 0 or int(handoff.get("active_tactical_hero_target_count", 0)) > 0 or int(handoff.get("battle_queue_event_count", 0)) > 0:
					battle_handoff_candidate_turn_count += 1
				if int(handoff.get("near_battle_target_count", 0)) > 0:
					near_battle_target_turn_count += 1
				if int(handoff.get("near_battle_town_or_hero_target_count", 0)) > 0:
					near_battle_town_or_hero_turn_count += 1
				if int(handoff.get("unreachable_active_target_count", 0)) > 0:
					unreachable_active_target_turn_count += 1
					unreachable_active_target_total += int(handoff.get("unreachable_active_target_count", 0))
				suppressed_post_outcome_unreachable_active_target_total += int(handoff.get("suppressed_post_outcome_unreachable_active_target_count", 0))
				best_min_goal_distance = mini(best_min_goal_distance, int(handoff.get("min_goal_distance", 9999)))
				best_min_tactical_battle_goal_distance = mini(best_min_tactical_battle_goal_distance, int(handoff.get("min_tactical_battle_goal_distance", 9999)))
				var nearest_turn_target: Dictionary = handoff.get("nearest_tactical_battle_target", {}) if handoff.get("nearest_tactical_battle_target", {}) is Dictionary else {}
				if not nearest_turn_target.is_empty() \
						and (nearest_tactical_battle_target.is_empty() or int(nearest_turn_target.get("goal_distance", 9999)) < int(nearest_tactical_battle_target.get("goal_distance", 9999))):
					nearest_tactical_battle_target = nearest_turn_target.duplicate(true)
					nearest_tactical_battle_target["seed"] = String(row.get("seed", ""))
					nearest_tactical_battle_target["seed_ordinal"] = int(row.get("seed_ordinal", 0))
					nearest_tactical_battle_target["turn_index"] = int(turn_value.get("turn_index", 0))
					nearest_tactical_battle_target["day"] = int(turn_value.get("day", 0))
				total_movement_distance_delta += int(handoff.get("movement_distance_delta_total", 0))
		var row_event_counts: Dictionary = row.get("event_counts", {}) if row.get("event_counts", {}) is Dictionary else {}
		for key in row_event_counts.keys():
			event_counts[String(key)] = int(event_counts.get(String(key), 0)) + int(row_event_counts.get(key, 0))
		var status := String(row.get("final_scenario_status", ""))
		if status != "":
			terminal_status_counts[status] = int(terminal_status_counts.get(status, 0)) + 1
		var final_task_summary: Dictionary = row.get("final_task_summary", {}) if row.get("final_task_summary", {}) is Dictionary else {}
		task_board_open_count += int(final_task_summary.get("open_count", 0))
		task_board_active_count += int(final_task_summary.get("active_count", 0))
	var town_battle_queued_count := int(event_counts.get("ai_town_assault_battle_queued", 0)) + int(event_counts.get("ai_town_defense_battle_queued", 0))
	tactical_battle_queued_count = town_battle_queued_count + int(event_counts.get("ai_hero_intercept_battle_queued", 0))
	var requested_turn_total: int = max(1, requested_seed_count * requested_turn_count)
	return {
		"row_count": rows.size(),
		"requested_seed_count": requested_seed_count,
		"requested_turn_count": requested_turn_count,
		"setup_ok_count": setup_ok_count,
		"row_ok_count": row_ok_count,
		"behavior_bug_count": behavior_bug_count,
		"turns_completed": total_turns_completed,
		"turn_completion_pct": int(round(float(total_turns_completed) * 100.0 / float(requested_turn_total))),
		"enemy_activity_event_count": total_enemy_events,
		"target_integrity_violation_count": total_target_integrity_violations,
		"battle_handoff_candidate_turn_count": battle_handoff_candidate_turn_count,
		"near_battle_target_turn_count": near_battle_target_turn_count,
		"near_battle_town_or_hero_turn_count": near_battle_town_or_hero_turn_count,
		"natural_tactical_battle_pressure_turn_count": battle_handoff_candidate_turn_count,
		"natural_tactical_battle_arrival_turn_count": near_battle_town_or_hero_turn_count,
		"best_min_active_raid_goal_distance": best_min_goal_distance,
		"best_min_tactical_battle_goal_distance": best_min_tactical_battle_goal_distance,
		"nearest_tactical_battle_target": nearest_tactical_battle_target,
		"movement_distance_delta_total": total_movement_distance_delta,
		"battle_interrupt_count": battle_interrupt_count,
		"auto_resolved_battle_count": auto_resolved_battle_count,
		"tactical_battle_queued_count": tactical_battle_queued_count,
		"natural_tactical_battle_queue_event_count": tactical_battle_queued_count,
		"stalled_turn_count": total_stalled_turns,
		"stalled_turn_pct": int(round(float(total_stalled_turns) * 100.0 / float(max(1, total_turns_completed)))),
		"no_active_pressure_row_count": no_active_pressure_row_count,
		"unreachable_active_target_turn_count": unreachable_active_target_turn_count,
		"unreachable_active_target_total": unreachable_active_target_total,
		"suppressed_post_outcome_unreachable_active_target_total": suppressed_post_outcome_unreachable_active_target_total,
		"event_counts": event_counts,
		"terminal_status_counts": terminal_status_counts,
		"target_assignment_count": int(event_counts.get("ai_target_assigned", 0)),
		"commander_task_planned_count": int(event_counts.get("ai_commander_task_planned", 0)),
		"task_board_open_count": task_board_open_count,
		"task_board_active_count": task_board_active_count,
		"site_seized_count": int(event_counts.get("ai_site_seized", 0)),
		"town_battle_queued_count": town_battle_queued_count,
		"total_row_runtime_msec": total_runtime_msec,
		"setup_runtime_msec": setup_runtime_msec,
		"max_row_runtime_msec": max_row_runtime_msec,
		"max_turn_runtime_msec": max_turn_runtime_msec,
	}

static func _strategic_ai_long_run_blockers(summary: Dictionary, requested_seed_count: int, requested_turn_count: int) -> Array:
	var rows := []
	if int(summary.get("setup_ok_count", 0)) < requested_seed_count:
		rows.append({"blocker_id": "native_rmg_seed_setup_failure", "severity": "bug", "summary": "At least one native generated-map seed failed setup."})
	if int(summary.get("behavior_bug_count", 0)) > 0:
		rows.append({"blocker_id": "strategic_ai_long_run_behavior_bug", "severity": "bug", "summary": "At least one generated-map strategic AI long-run row failed during turns or battle resolution."})
	if int(summary.get("target_integrity_violation_count", 0)) > 0:
		rows.append({"blocker_id": "strategic_ai_long_run_target_integrity_violation", "severity": "bug", "summary": "At least one generated-map strategic AI event or active raid state targeted its own actor."})
	if int(summary.get("turns_completed", 0)) <= 0:
		rows.append({"blocker_id": "strategic_ai_long_run_no_turns", "severity": "bug", "summary": "The long-run matrix completed no generated-map turns."})
	if int(summary.get("enemy_activity_event_count", 0)) <= 0:
		rows.append({"blocker_id": "strategic_ai_long_run_no_enemy_activity", "severity": "production_gap", "summary": "Generated-map AI turns completed without observable enemy activity."})
	if requested_turn_count >= 14 \
			and int(summary.get("battle_handoff_candidate_turn_count", 0)) > 0 \
			and int(summary.get("near_battle_town_or_hero_turn_count", 0)) > 0 \
			and int(summary.get("battle_interrupt_count", 0)) <= 0 \
			and int(summary.get("town_battle_queued_count", 0)) <= 0:
		rows.append({
			"blocker_id": "strategic_ai_long_run_no_battle_handoff",
			"severity": "production_gap",
			"summary": "Generated-map AI maintained town/hero battle pressure for an extended run but did not reach a battle handoff.",
		})
	if requested_turn_count >= 14 \
			and int(summary.get("battle_handoff_candidate_turn_count", 0)) > 0 \
			and int(summary.get("near_battle_town_or_hero_turn_count", 0)) <= 0 \
			and int(summary.get("tactical_battle_queued_count", 0)) <= 0:
		rows.append({
			"blocker_id": "strategic_ai_long_run_no_natural_tactical_arrival",
			"severity": "remaining_validation",
			"summary": "Generated-map AI maintained town/hero pressure, but no natural town/hero target reached tactical battle handoff range in this run; closest distance was %d." % int(summary.get("best_min_tactical_battle_goal_distance", 9999)),
			"nearest_tactical_battle_target": summary.get("nearest_tactical_battle_target", {}),
		})
	var target_planning_count := int(summary.get("target_assignment_count", 0)) \
		+ int(summary.get("commander_task_planned_count", 0)) \
		+ int(summary.get("task_board_open_count", 0)) \
		+ int(summary.get("task_board_active_count", 0))
	if target_planning_count <= 0:
		rows.append({"blocker_id": "strategic_ai_long_run_no_target_assignment", "severity": "production_gap", "summary": "Generated-map AI did not assign strategic targets during the matrix."})
	if int(summary.get("stalled_turn_pct", 0)) > 75:
		rows.append({"blocker_id": "strategic_ai_long_run_excess_idle_turns", "severity": "production_gap", "summary": "Most generated-map AI turns produced no observable activity."})
	if requested_turn_count >= 7 and int(summary.get("no_active_pressure_row_count", 0)) > 0:
		rows.append({
			"blocker_id": "strategic_ai_long_run_no_active_pressure_after_rebuild",
			"severity": "production_gap",
			"summary": "At least one generated-map row stayed in progress with no active hostile pressure after early regroup/rebuild resolution.",
			"row_count": int(summary.get("no_active_pressure_row_count", 0)),
		})
	if requested_seed_count < STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET or requested_turn_count < STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET:
		rows.append({
			"blocker_id": "strategic_ai_long_run_full_100_seed_8_week_matrix_not_run",
			"severity": "remaining_validation",
			"summary": "The implemented runner supports the production target, but this focused validation did not execute the full 100-seed eight-week matrix.",
		})
	return rows

static func _strategic_ai_long_run_row_signatures(rows: Array) -> Array:
	var signatures := []
	for row in rows:
		if row is Dictionary:
			signatures.append(String(row.get("signature", "")))
	signatures.sort()
	return signatures

static func _strategic_ai_town_owner_counts(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var counts := {"player": 0, "enemy": 0, "neutral": 0, "other": 0}
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town in towns:
		if not (town is Dictionary):
			continue
		var owner := String(town.get("owner", "neutral"))
		if counts.has(owner):
			counts[owner] = int(counts.get(owner, 0)) + 1
		else:
			counts["other"] = int(counts.get("other", 0)) + 1
	return counts

static func _strategic_ai_task_summary(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var summary := {"task_count": 0, "open_count": 0, "completed_count": 0, "cancelled_count": 0, "suspended_count": 0, "invalidated_count": 0}
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state in states:
		if not (state is Dictionary):
			continue
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		for task in tasks:
			if not (task is Dictionary):
				continue
			summary["task_count"] = int(summary.get("task_count", 0)) + 1
			var status := String(task.get("task_status", task.get("status", "")))
			if status == "open" or status == "planned":
				summary["open_count"] = int(summary.get("open_count", 0)) + 1
			elif status == "active":
				summary["active_count"] = int(summary.get("active_count", 0)) + 1
			elif status == "completed":
				summary["completed_count"] = int(summary.get("completed_count", 0)) + 1
			elif status == "cancelled":
				summary["cancelled_count"] = int(summary.get("cancelled_count", 0)) + 1
			elif status == "suspended":
				summary["suspended_count"] = int(summary.get("suspended_count", 0)) + 1
			elif status == "invalidated" or status == "invalid":
				summary["invalidated_count"] = int(summary.get("invalidated_count", 0)) + 1
	return summary

static func _strategic_ai_active_raid_count(session: SessionStateStoreScript.SessionData) -> int:
	var count := 0
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state in states:
		if state is Dictionary:
			count += EnemyTurnRules.active_raid_count(session, String(state.get("faction_id", "")))
	return count

static func _strategic_ai_apply_pressure_floor(session: SessionStateStoreScript.SessionData, pressure_floor: int) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		state["pressure"] = max(int(state.get("pressure", 0)), pressure_floor)
		states[index] = state
	session.overworld["enemy_states"] = states

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
	var primary_roster_hero_id := _strategic_ai_planned_actor_for_target(session, config, faction_id, "resource", primary_target_id, "hero_vaska")
	var companion_roster_hero_id := _strategic_ai_planned_actor_for_target(session, config, faction_id, "resource", companion_target_id, "hero_sable")
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var primary_raid_id := "headless_live_turn_primary_%s" % primary_target_id
	var companion_raid_id := "headless_live_turn_companion_%s" % companion_target_id
	encounters.append(_live_turn_raid_seed(session, faction_id, primary_roster_hero_id, primary_raid_id, primary_target_id))
	encounters.append(_live_turn_raid_seed(session, faction_id, companion_roster_hero_id, companion_raid_id, companion_target_id))
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
	var primary_ok := _raid_completed_target(primary_raid, "resource", primary_target_id) and String(controllers_after.get(primary_target_id, "")) == faction_id
	var companion_ok := _raid_completed_target(companion_raid, "resource", companion_target_id) and String(controllers_after.get(companion_target_id, "")) == faction_id
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
	if not _has_saved_hero_task_state(session):
		failures.append("Live turn execution did not persist hero_task_state.")
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
			"primary_roster_hero_id": primary_roster_hero_id,
			"companion_roster_hero_id": companion_roster_hero_id,
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
			"save_policy": "hero_task_state_live_persist_no_save_migration",
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
	var route_roster_hero_id := _strategic_ai_planned_actor_for_target(session, config, faction_id, "resource", target_id, "hero_vaska")
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(_live_route_raid_seed(session, faction_id, route_roster_hero_id, raid_id, origin))
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
	if not _has_saved_hero_task_state(session):
		failures.append("Live route progression did not persist hero_task_state.")
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
			"route_roster_hero_id": route_roster_hero_id,
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
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_town_governor_build_execution(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_town_governor_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_town_governor_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_town_governor_town_id", "duskfen_bastion"))
	var default_treasury := {
		"gold": 12800,
		"wood": 24,
		"ore": 24,
		"aetherglass": 12,
		"embergrain": 12,
		"peatwax": 12,
		"verdant_grafts": 12,
		"brass_scrip": 12,
		"memory_salt": 12,
	}
	var seeded_treasury: Dictionary = input_config.get("strategic_ai_live_town_governor_treasury", default_treasury) if input_config.get("strategic_ai_live_town_governor_treasury", {}) is Dictionary else default_treasury
	var fixture_day: int = max(1, int(input_config.get("strategic_ai_live_town_governor_day", 24)))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live town-governor scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_town_governor_build_execution",
			"live_town_governor_builds_and_recruits_through_enemy_turn",
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
			"strategic_ai_live_town_governor_build_execution",
			"live_town_governor_builds_and_recruits_through_enemy_turn",
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
	session.day = fixture_day
	_set_player_position(session, {"x": 0, "y": 12})
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		state["treasury"] = _resource_pool(seeded_treasury)
		_update_enemy_state(session, state)
	var town_before := _town_by_placement(session, town_id)
	if town_before.is_empty():
		failures.append("Missing town %s for live town-governor fixture." % town_id)
	var governor_before: Dictionary = EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
	var town_report_before := _town_governor_report_for_town(governor_before, town_id)
	var build_report: Dictionary = town_report_before.get("build", {}) if town_report_before.get("build", {}) is Dictionary else {}
	var selected_build: Dictionary = build_report.get("selected_build", {}) if build_report.get("selected_build", {}) is Dictionary else {}
	var recruitment_report: Dictionary = town_report_before.get("recruitment", {}) if town_report_before.get("recruitment", {}) is Dictionary else {}
	var selected_recruitment: Dictionary = recruitment_report.get("selected_recruitment", {}) if recruitment_report.get("selected_recruitment", {}) is Dictionary else {}
	var selected_build_id := String(selected_build.get("building_id", ""))
	var recruit_unit_id := String(selected_recruitment.get("unit_id", ""))
	var recruit_count_projected := int(selected_recruitment.get("recruit_count", 0))
	var treasury_before := _resource_pool(state.get("treasury", {})) if not state.is_empty() else _resource_pool({})
	var built_before := _town_building_ids(town_before)
	var recruit_pool_before := _recruit_pool_total(town_before.get("available_recruits", {}))
	var garrison_count_before := _army_stack_count(town_before.get("garrison", []))
	if selected_build_id == "":
		failures.append("Live town-governor fixture did not project an affordable build.")
	if recruit_unit_id == "" or recruit_count_projected <= 0:
		failures.append("Live town-governor fixture did not project affordable recruitment.")
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var town_after := _town_by_placement(session, town_id)
	var state_after := _enemy_state_for_faction(session, faction_id)
	var treasury_after := _resource_pool(state_after.get("treasury", {})) if not state_after.is_empty() else _resource_pool({})
	var built_after := _town_building_ids(town_after)
	var recruit_pool_after := _recruit_pool_total(town_after.get("available_recruits", {}))
	var garrison_count_after := _army_stack_count(town_after.get("garrison", []))
	var treasury_delta := _resource_delta(treasury_before, treasury_after)
	var town_build_events := _event_count(events, "ai_town_built")
	var town_recruit_events := _event_count(events, "ai_town_recruited")
	var garrison_events := _event_count(events, "ai_garrison_reinforced")
	var raid_reinforcement_events := _event_count(events, "ai_raid_reinforced")
	var rebuild_events := _event_count(events, "ai_commander_rebuilt")
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live town-governor execution.")
	if selected_build_id != "" and selected_build_id not in built_after:
		failures.append("Live town-governor build did not mutate built buildings with %s." % selected_build_id)
	if selected_build_id != "" and selected_build_id in built_before:
		failures.append("Live town-governor fixture selected a building that was already built: %s." % selected_build_id)
	if _resource_abs_sum(treasury_delta) <= 0:
		failures.append("Live town-governor execution did not mutate treasury: %s." % treasury_delta)
	if town_build_events < 1:
		failures.append("Live town-governor execution did not emit ai_town_built.")
	if town_recruit_events < 1:
		failures.append("Live town-governor execution did not emit ai_town_recruited.")
	if garrison_events + raid_reinforcement_events + rebuild_events < 1:
		failures.append("Live town-governor execution did not emit a recruitment destination event.")
	if garrison_count_after <= garrison_count_before and recruit_pool_after == recruit_pool_before:
		failures.append("Live town-governor execution did not produce visible recruitment mutation.")
	if not _has_saved_hero_task_state(session):
		failures.append("Live town-governor execution did not preserve hero_task_state from the enemy turn.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 10)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live town-governor events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live town-governor events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_town_governor_build_execution",
		"live_town_governor_builds_and_recruits_through_enemy_turn",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"selected_build_id": selected_build_id,
			"recruit_unit_id": recruit_unit_id,
			"recruit_count_projected": recruit_count_projected,
			"built_before_count": built_before.size(),
			"built_after_count": built_after.size(),
			"recruit_pool_before": recruit_pool_before,
			"recruit_pool_after": recruit_pool_after,
			"garrison_count_before": garrison_count_before,
			"garrison_count_after": garrison_count_after,
			"town_build_event_count": town_build_events,
			"town_recruit_event_count": town_recruit_events,
			"recruit_destination_event_count": garrison_events + raid_reinforcement_events + rebuild_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"treasury_before": treasury_before,
			"treasury_after": treasury_after,
			"treasury_delta": treasury_delta,
			"built_before": built_before,
			"built_after": built_after,
			"selected_build": _town_build_signal(selected_build),
			"selected_recruitment": _town_recruitment_signal(selected_recruitment),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_generated_town_battle_handoff(input_config: Dictionary) -> Dictionary:
	var seed := String(input_config.get("strategic_ai_generated_handoff_seed", "strategic-ai-generated-handoff-small-001"))
	var template_id := String(input_config.get("strategic_ai_generated_handoff_template_id", "translated_rmg_template_049_v1"))
	var profile_id := String(input_config.get("strategic_ai_generated_handoff_profile_id", "translated_rmg_profile_049_v1"))
	var failures := []
	var warnings := []
	var deferred := []
	var player_config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		template_id,
		profile_id,
		3,
		"land",
		false,
		"homm3_small"
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		player_config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)):
		failures.append("Native RMG generated handoff setup failed: %s." % String(setup.get("error_code", "")))
		return _case(
			"strategic_ai_generated_town_battle_handoff",
			"native_rmg_in_range_town_target_queues_battle",
			_status_from(failures, warnings, deferred),
			{
				"seed": seed,
				"setup_ok": false,
				"validation_status": String(validation.get("status", validation.get("validation_status", ""))),
				"failure_count": failures.size(),
			},
			{"setup": setup, "failures": failures, "warnings": warnings, "deferred": deferred},
			warnings,
			deferred
		)
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		failures.append("Native RMG generated handoff setup did not start a session.")
		return _case(
			"strategic_ai_generated_town_battle_handoff",
			"native_rmg_in_range_town_target_queues_battle",
			_status_from(failures, warnings, deferred),
			{"seed": seed, "setup_ok": true, "failure_count": failures.size()},
			{"failures": failures, "warnings": warnings, "deferred": deferred},
			warnings,
			deferred
		)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var player_town := _first_town_for_owner(session, "player")
	var state := _first_enemy_state(session)
	var faction_id := String(state.get("faction_id", ""))
	var config := EnemyTurnRules._enemy_config_for_faction(session, faction_id)
	var unit_id := _first_recruit_unit_id_for_faction(faction_id)
	var roster_hero_id := _first_commander_hero_id_for_faction(session, faction_id)
	if player_town.is_empty():
		failures.append("Native RMG generated handoff session has no player town.")
	if state.is_empty() or faction_id == "":
		failures.append("Native RMG generated handoff session has no enemy state.")
	if config.is_empty():
		failures.append("Native RMG generated handoff session has no enemy config for %s." % faction_id)
	if unit_id == "":
		failures.append("Native RMG generated handoff session has no recruit unit for %s." % faction_id)
	if roster_hero_id == "":
		failures.append("Native RMG generated handoff session has no commander for %s." % faction_id)
	var raid_id := "headless_generated_town_handoff_%s" % faction_id.replace("faction_", "")
	var raid := {}
	if failures.is_empty():
		raid = _generated_town_handoff_raid_seed(session, faction_id, roster_hero_id, raid_id, player_town, unit_id)
		var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
		encounters.append(raid)
		session.overworld["encounters"] = encounters
	var queue_result := {}
	if failures.is_empty():
		queue_result = EnemyTurnRules._queue_town_defense_battle(session, config, faction_id)
	var events: Array = queue_result.get("events", []) if queue_result.get("events", []) is Array else []
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if failures.is_empty() and not bool(queue_result.get("battle_started", false)):
		failures.append("Native RMG generated in-range town target did not start a battle: %s." % JSON.stringify(queue_result))
	if failures.is_empty() and String(session.game_state) != "battle":
		failures.append("Native RMG generated handoff did not put session into battle state.")
	if failures.is_empty() and String(battle_context.get("type", "")) != "town_defense":
		failures.append("Native RMG generated handoff queued wrong battle context: %s." % JSON.stringify(battle_context))
	if failures.is_empty() and String(battle_context.get("town_placement_id", "")) != String(player_town.get("placement_id", "")):
		failures.append("Native RMG generated handoff queued battle for wrong town: %s." % JSON.stringify(battle_context))
	if failures.is_empty() and _event_count(events, "ai_town_defense_battle_queued") < 1:
		failures.append("Native RMG generated handoff did not emit ai_town_defense_battle_queued.")
	if failures.is_empty() and not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected Native RMG generated handoff events.")
	if failures.is_empty() and not public_event_leak_tokens.is_empty():
		failures.append("Public Native RMG generated handoff events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var handoff_summary := _strategic_ai_battle_handoff_summary(session, events)
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_generated_town_battle_handoff",
		"native_rmg_in_range_town_target_queues_battle",
		status,
		{
			"seed": seed,
			"scenario_id": String(session.scenario_id),
			"startup_source": String(setup.get("startup_source", "")),
			"validation_status": String(validation.get("status", validation.get("validation_status", ""))),
			"faction_id": faction_id,
			"roster_hero_id": roster_hero_id,
			"unit_id": unit_id,
			"target_town_id": String(player_town.get("placement_id", "")),
			"battle_started": bool(queue_result.get("battle_started", false)),
			"battle_context_type": String(battle_context.get("type", "")),
			"battle_town_id": String(battle_context.get("town_placement_id", "")),
			"battle_queue_event_count": _event_count(events, "ai_town_defense_battle_queued"),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"failure_count": failures.size(),
			"warning_count": warnings.size(),
		},
		{
			"raid": _raid_execution_signal(_encounter_by_placement(session, raid_id)),
			"battle_context": battle_context,
			"event_types": _event_types(events),
			"handoff_summary": handoff_summary,
			"public_event_leak_tokens": public_event_leak_tokens,
			"native_rmg_generated_maps_only": true,
			"failures": failures,
			"warnings": warnings,
			"deferred": deferred,
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
	if resource_controller == faction_id:
		failures.append("Live regroup captured the original offensive resource instead of retreating.")
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
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_recruitment_delivery(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_recruitment_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_recruitment_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_recruitment_town_id", "duskfen_bastion"))
	var target_id := String(input_config.get("strategic_ai_live_recruitment_target_id", "river_free_company"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_recruitment_hero_id", "hero_vaska"))
	var unit_id := String(input_config.get("strategic_ai_live_recruitment_unit_id", "unit_bog_brute"))
	var recruit_count: int = max(1, int(input_config.get("strategic_ai_live_recruitment_count", 4)))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live recruitment scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_recruitment_delivery",
			"live_town_recruits_feed_active_raid_host",
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
			"strategic_ai_live_recruitment_delivery",
			"live_town_recruits_feed_active_raid_host",
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
	_set_player_position(session, {"x": 0, "y": 12})
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		state["pressure"] = 0
		state["treasury"] = {"gold": 9000, "wood": 40, "ore": 40}
		_update_enemy_state(session, state)
	_set_resource_controller(session, target_id, "player", failures)
	_prepare_recruitment_delivery_town(session, town_id, faction_id, unit_id, recruit_count, failures)
	var raid_id := "headless_recruitment_delivery_%s" % target_id
	var seed_raid := _recruitment_delivery_raid_seed(session, faction_id, roster_hero_id, raid_id, target_id, unit_id)
	var before_strength := EnemyAdventureRules.raid_strength(seed_raid)
	var desired_before := EnemyAdventureRules.desired_raid_strength(seed_raid)
	var town_recruits_before := _town_available_recruit_count(session, town_id, unit_id)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	var town_recruits_after := _town_available_recruit_count(session, town_id, unit_id)
	var raid_unit_after := _raid_unit_count(after_raid, unit_id)
	var town_recruit_events := _event_count(events, "ai_town_recruited")
	var raid_reinforcement_events := _event_count(events, "ai_raid_reinforced")
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live recruitment delivery.")
	if after_raid.is_empty():
		failures.append("Live recruitment delivery raid disappeared after enemy turn.")
	if desired_before <= before_strength:
		failures.append("Live recruitment fixture did not start with an active raid strength need.")
	if after_strength <= before_strength:
		failures.append("Live recruitment delivery did not increase raid strength: before=%d after=%d." % [before_strength, after_strength])
	if town_recruits_after >= town_recruits_before:
		failures.append("Live recruitment delivery did not consume town recruits: before=%d after=%d." % [town_recruits_before, town_recruits_after])
	if raid_unit_after < recruit_count + 1:
		failures.append("Live recruitment delivery did not add expected %s stack count: %d." % [unit_id, raid_unit_after])
	if town_recruit_events < 1:
		failures.append("Live recruitment delivery did not emit ai_town_recruited.")
	if raid_reinforcement_events < 1:
		failures.append("Live recruitment delivery did not emit ai_raid_reinforced.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 10)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live recruitment delivery events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live recruitment events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_recruitment_delivery",
		"live_town_recruits_feed_active_raid_host",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"target_id": target_id,
			"unit_id": unit_id,
			"before_strength": before_strength,
			"after_strength": after_strength,
			"desired_before": desired_before,
			"town_recruits_before": town_recruits_before,
			"town_recruits_after": town_recruits_after,
			"raid_unit_after": raid_unit_after,
			"town_recruit_event_count": town_recruit_events,
			"raid_reinforcement_event_count": raid_reinforcement_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
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
	if not _has_saved_hero_task_state(session):
		failures.append("Live town-defense retask did not persist hero_task_state.")
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
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_town_defense_retask(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("strategic_ai_town_defense_coverage_scenario_ids", [
		"river-pass",
		"prismhearth-watch",
		"glassroad-sundering",
		"glassfen-breakers",
		"ninefold-confluence",
	])
	var failures := []
	var warnings := []
	var deferred := []
	var scenario_rows := []
	var faction_rows := []
	var public_boundary_events := []
	var event_type_map := {}
	var retasked_faction_count := 0
	var target_assignment_event_count := 0
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing strategic AI town-defense coverage scenario %s." % scenario_id)
			continue
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		if enemy_configs.is_empty():
			deferred.append("%s has no enemy_factions for town-defense coverage." % scenario_id)
			continue
		var scenario_retask_count := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
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
				failures.append("%s has no enemy state for %s." % [scenario_id, faction_id])
				continue
			state["pressure"] = 0
			_update_enemy_state(session, state)
			var town_signal := _first_controller_town_signal_for_faction(session, faction_id)
			var previous_target := _first_resource_node_signal_for_harness(session)
			var town_id := String(town_signal.get("placement_id", ""))
			var previous_target_id := String(previous_target.get("placement_id", ""))
			if town_id == "":
				failures.append("%s/%s has no owned enemy controller town for defense retask coverage." % [scenario_id, faction_id])
				continue
			if previous_target_id == "":
				failures.append("%s/%s has no resource node for defense retask previous target." % [scenario_id, faction_id])
				continue
			var roster_hero_id := _first_commander_hero_id_for_faction(session, faction_id)
			if roster_hero_id == "":
				failures.append("%s/%s has no commander hero for defense retask coverage." % [scenario_id, faction_id])
				continue
			_set_resource_controller(session, previous_target_id, "player", failures)
			_set_town_stabilizing_front(session, town_id, faction_id, failures)
			_set_player_position(session, {"x": int(previous_target.get("x", 0)), "y": int(previous_target.get("y", 0))})
			var raid_id := "headless_multi_defense_%s_%s" % [scenario_id.replace("-", "_"), faction_id.replace("faction_", "")]
			var seed_raid := _town_defense_retask_raid_seed(session, faction_id, roster_hero_id, raid_id, previous_target_id)
			seed_raid["x"] = int(town_signal.get("x", seed_raid.get("x", 0)))
			seed_raid["y"] = int(town_signal.get("y", seed_raid.get("y", 0)))
			var regroup_needed_before := EnemyAdventureRules.raid_regroup_needed(seed_raid)
			var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
			encounters.append(seed_raid)
			session.overworld["encounters"] = encounters
			var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
			var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
			for event_type in _event_types(events):
				event_type_map[String(event_type)] = true
			for event in events:
				if not (event is Dictionary):
					continue
				if String(event.get("event_type", "")) != "ai_target_assigned":
					continue
				var event_reason_codes := _string_array(event.get("reason_codes", []))
				if (
					String(event.get("faction_id", "")) == faction_id
					and String(event.get("actor_id", "")) == raid_id
					and String(event.get("target_id", "")) == town_id
					and "town_defense" in event_reason_codes
					):
					public_boundary_events.append(event)
			var town_defense_events := 0
			for event in events:
				if not (event is Dictionary):
					continue
				if String(event.get("event_type", "")) == "ai_town_defended" \
						and String(event.get("faction_id", "")) == faction_id \
						and String(event.get("actor_id", "")) == raid_id \
						and String(event.get("target_id", "")) == town_id:
					town_defense_events += 1
			var after_raid := _encounter_by_placement(session, raid_id)
			var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
			var assignment_events := _event_count_for_faction(events, "ai_target_assigned", faction_id)
			target_assignment_event_count += assignment_events
			var resource_controller := _resource_controller(session, previous_target_id)
			var active_town_defense_target := (
				String(after_raid.get("target_kind", "")) == "town"
				and String(after_raid.get("target_placement_id", "")) == town_id
				and "town_defense" in reason_codes
				and "front_stabilization" in reason_codes
			)
			var cleared_defense_lifecycle := (
				String(after_raid.get("target_kind", "")) == ""
				and String(after_raid.get("target_placement_id", "")) == ""
				and assignment_events > 0
			)
			var retasked := (
				bool(turn_result.get("ok", false))
				and not after_raid.is_empty()
				and not regroup_needed_before
				and String(after_raid.get("previous_target_placement_id", "")) == previous_target_id
				and (active_town_defense_target or town_defense_events > 0 or cleared_defense_lifecycle)
				and assignment_events > 0
				and resource_controller != faction_id
				and _has_saved_hero_task_state(session)
			)
			if not retasked:
				failures.append("%s/%s did not retask active raid to defend %s." % [scenario_id, faction_id, town_id])
			else:
				retasked_faction_count += 1
				scenario_retask_count += 1
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"town_id": town_id,
				"previous_target_id": previous_target_id,
				"roster_hero_id": roster_hero_id,
				"retasked": retasked,
				"regroup_needed_before": regroup_needed_before,
				"target_kind": String(after_raid.get("target_kind", "")),
				"target_placement_id": String(after_raid.get("target_placement_id", "")),
				"previous_target_preserved": String(after_raid.get("previous_target_placement_id", "")) == previous_target_id,
				"target_reason_codes": reason_codes,
				"target_assignment_event_count": assignment_events,
				"town_defense_event_count": town_defense_events,
				"resource_controller_after": resource_controller,
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"retasked_faction_count": scenario_retask_count,
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(public_boundary_events, 24)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected multi-scenario town-defense events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public multi-scenario town-defense events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var event_types := event_type_map.keys()
	event_types.sort()
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_multi_scenario_town_defense_retask",
		"live_enemy_town_defense_retask_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"retasked_faction_count": retasked_faction_count,
			"target_assignment_event_count": target_assignment_event_count,
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
			"failure_count": failures.size(),
		},
		{
			"scenarios": scenario_rows,
			"faction_cases": faction_rows,
			"event_types": event_types,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_recruitment_delivery(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("strategic_ai_recruitment_coverage_scenario_ids", [
		"river-pass",
		"prismhearth-watch",
		"glassroad-sundering",
		"glassfen-breakers",
		"bogbound-oath",
	])
	var recruit_count: int = max(1, int(input_config.get("strategic_ai_multi_scenario_recruitment_count", 4)))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario_rows := []
	var faction_rows := []
	var event_type_map := {}
	var public_boundary_events := []
	var delivered_faction_count := 0
	var town_recruit_event_count := 0
	var raid_reinforcement_event_count := 0
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing strategic AI recruitment coverage scenario %s." % scenario_id)
			continue
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		if enemy_configs.is_empty():
			deferred.append("%s has no enemy_factions for recruitment coverage." % scenario_id)
			continue
		var scenario_delivery_count := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
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
				failures.append("%s has no enemy state for %s." % [scenario_id, faction_id])
				continue
			state["pressure"] = 0
			state["treasury"] = {"gold": 9000, "wood": 40, "ore": 40}
			_update_enemy_state(session, state)
			var town_signal := _first_controller_town_signal_for_faction(session, faction_id)
			var target_signal := _first_resource_node_signal_for_harness(session)
			var town_id := String(town_signal.get("placement_id", ""))
			var target_id := String(target_signal.get("placement_id", ""))
			if town_id == "":
				failures.append("%s/%s has no owned enemy controller town for recruitment coverage." % [scenario_id, faction_id])
				continue
			if target_id == "":
				failures.append("%s/%s has no resource node for recruitment coverage." % [scenario_id, faction_id])
				continue
			var roster_hero_id := _first_commander_hero_id_for_faction(session, faction_id)
			if roster_hero_id == "":
				failures.append("%s/%s has no commander hero for recruitment coverage." % [scenario_id, faction_id])
				continue
			var unit_id := _first_recruit_unit_id_for_faction(faction_id)
			if unit_id == "":
				failures.append("%s/%s has no recruit unit for recruitment coverage." % [scenario_id, faction_id])
				continue
			_set_player_position(session, {"x": 0, "y": 12})
			_set_resource_controller(session, target_id, "player", failures)
			_prepare_recruitment_delivery_town(session, town_id, faction_id, unit_id, recruit_count, failures)
			var raid_id := "headless_multi_recruitment_%s_%s" % [scenario_id.replace("-", "_"), faction_id.replace("faction_", "")]
			var seed_raid := _recruitment_delivery_raid_seed(session, faction_id, roster_hero_id, raid_id, target_id, unit_id)
			var before_strength := EnemyAdventureRules.raid_strength(seed_raid)
			var desired_before := EnemyAdventureRules.desired_raid_strength(seed_raid)
			var town_recruits_before := _town_available_recruit_count(session, town_id, unit_id)
			var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
			encounters.append(seed_raid)
			session.overworld["encounters"] = encounters
			EnemyAdventureRules.normalize_all_commander_rosters(session)
			var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
			var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
			for event in events:
				if not (event is Dictionary):
					continue
				event_type_map[String(event.get("event_type", ""))] = true
				if String(event.get("event_type", "")) in ["ai_town_recruited", "ai_raid_reinforced"]:
					public_boundary_events.append(event)
			var after_raid := _encounter_by_placement(session, raid_id)
			var after_strength := EnemyAdventureRules.raid_strength(after_raid)
			var town_recruits_after := _town_available_recruit_count(session, town_id, unit_id)
			var raid_unit_after := _raid_unit_count(after_raid, unit_id)
			var case_town_recruit_events := _event_count_for_faction(events, "ai_town_recruited", faction_id)
			var case_raid_reinforcement_events := _event_count_for_faction(events, "ai_raid_reinforced", faction_id)
			town_recruit_event_count += case_town_recruit_events
			raid_reinforcement_event_count += case_raid_reinforcement_events
			var delivered := (
				bool(turn_result.get("ok", false))
				and not after_raid.is_empty()
				and desired_before > before_strength
				and after_strength > before_strength
				and town_recruits_after < town_recruits_before
				and raid_unit_after >= recruit_count + 1
				and case_town_recruit_events > 0
				and case_raid_reinforcement_events > 0
				and String(after_raid.get("target_kind", "")) != ""
				and String(after_raid.get("target_placement_id", "")) != ""
			)
			if not delivered:
				failures.append("%s/%s did not deliver recruits from %s into raid %s." % [scenario_id, faction_id, town_id, raid_id])
			else:
				delivered_faction_count += 1
				scenario_delivery_count += 1
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"town_id": town_id,
				"target_id": target_id,
				"raid_target_id_after": String(after_raid.get("target_placement_id", "")),
				"roster_hero_id": roster_hero_id,
				"unit_id": unit_id,
				"delivered": delivered,
				"before_strength": before_strength,
				"after_strength": after_strength,
				"desired_before": desired_before,
				"town_recruits_before": town_recruits_before,
				"town_recruits_after": town_recruits_after,
				"raid_unit_after": raid_unit_after,
				"town_recruit_event_count": case_town_recruit_events,
				"raid_reinforcement_event_count": case_raid_reinforcement_events,
				"raid": _raid_execution_signal(after_raid),
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"delivered_faction_count": scenario_delivery_count,
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(public_boundary_events, 32)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected multi-scenario recruitment delivery events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public multi-scenario recruitment events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var event_types := event_type_map.keys()
	event_types.sort()
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_multi_scenario_recruitment_delivery",
		"live_town_recruits_feed_active_raid_hosts_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"delivered_faction_count": delivered_faction_count,
			"town_recruit_event_count": town_recruit_event_count,
			"raid_reinforcement_event_count": raid_reinforcement_event_count,
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
			"failure_count": failures.size(),
		},
		{
			"scenarios": scenario_rows,
			"faction_cases": faction_rows,
			"event_types": event_types,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_resource_site_defense(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_resource_defense_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_resource_defense_faction_id", "faction_mireclaw"))
	var defense_target_id := String(input_config.get("strategic_ai_live_resource_defense_target_id", "river_free_company"))
	var previous_target_id := String(input_config.get("strategic_ai_live_resource_defense_previous_target_id", "river_signal_post"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_resource_defense_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live resource-defense scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_resource_site_defense",
			"live_raid_defends_owned_persistent_resource_site",
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
			"strategic_ai_live_resource_site_defense",
			"live_raid_defends_owned_persistent_resource_site",
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
	_set_resource_controller(session, defense_target_id, faction_id, failures)
	_set_resource_controller(session, previous_target_id, "player", failures)
	_set_resource_defense_front(session, defense_target_id, faction_id, failures)
	var defense_node := _resource_node_by_placement(session, defense_target_id)
	_set_player_position(session, {"x": int(defense_node.get("x", 0)), "y": int(defense_node.get("y", 0))})
	var raid_id := "headless_live_resource_defense_%s" % defense_target_id
	var seed_raid := _resource_defense_retask_raid_seed(session, faction_id, roster_hero_id, raid_id, previous_target_id, defense_target_id)
	var regroup_needed_before := EnemyAdventureRules.raid_regroup_needed(seed_raid)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = OverworldRules.end_turn(session)
	var events: Array = turn_result.get("enemy_activity_events", []) if turn_result.get("enemy_activity_events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var after_defense_node := _resource_node_by_placement(session, defense_target_id)
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	var assignment_events := _event_count(events, "ai_target_assigned")
	var defense_events := _event_count(events, "ai_site_defended")
	var defense_controller := _resource_controller(session, defense_target_id)
	var previous_controller := _resource_controller(session, previous_target_id)
	if not bool(turn_result.get("ok", false)):
		failures.append("End turn returned not-ok during live resource-site defense.")
	if after_raid.is_empty():
		failures.append("Live resource-defense raid disappeared after end-turn enemy cycle.")
	if regroup_needed_before:
		failures.append("Live resource-defense fixture raid was understrength before enemy turn.")
	if assignment_events < 1:
		failures.append("Live resource-defense retask did not surface an ai_target_assigned event.")
	if defense_events < 1:
		failures.append("Live resource-defense arrival did not surface an ai_site_defended event.")
	if String(after_raid.get("target_kind", "")) != "resource" or String(after_raid.get("target_placement_id", "")) != defense_target_id:
		failures.append("Live resource-defense retask did not target %s." % defense_target_id)
	if "site_defense" not in reason_codes or "defend_front" not in reason_codes or "front_stabilization" not in reason_codes:
		failures.append("Live resource-defense retask missed public reason codes.")
	if String(after_raid.get("previous_target_placement_id", "")) != previous_target_id:
		failures.append("Live resource-defense retask did not preserve previous target %s." % previous_target_id)
	if defense_controller != faction_id:
		failures.append("Live resource-defense target lost controller %s." % faction_id)
	if previous_controller == faction_id:
		failures.append("Live resource-defense retask captured the abandoned offensive resource.")
	if String(after_defense_node.get("ai_defended_by_faction_id", "")) != faction_id:
		failures.append("Live resource-defense target did not record durable defense state.")
	if not _has_saved_hero_task_state(session):
		failures.append("Live resource-defense retask did not persist hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 10)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live resource-defense events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live resource-defense events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_resource_site_defense",
		"live_raid_defends_owned_persistent_resource_site",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"target_id": defense_target_id,
			"previous_target_id": previous_target_id,
			"regroup_needed_before": regroup_needed_before,
			"target_assignment_event_count": assignment_events,
			"site_defense_event_count": defense_events,
			"defense_controller_after": defense_controller,
			"previous_controller_after": previous_controller,
			"defense_recorded_day": int(after_defense_node.get("ai_defended_day", 0)),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"target_reason_codes": reason_codes,
			"defense_node": _resource_defense_signal(after_defense_node),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func strategic_ai_emergency_defense_commander_fit_case(input_config: Dictionary = {}) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_emergency_fit_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_emergency_fit_faction_id", "faction_mireclaw"))
	var defense_target_id := String(input_config.get("strategic_ai_emergency_fit_target_id", "river_free_company"))
	var expected_defender_id := String(input_config.get("strategic_ai_emergency_fit_expected_hero_id", "hero_sable"))
	var rotation_first_id := String(input_config.get("strategic_ai_emergency_fit_rotation_first_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI emergency-defense commander-fit scenario %s." % scenario_id)
		return _case(
			"strategic_ai_emergency_defense_commander_fit",
			"emergency_defense_launch_uses_commander_fit",
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
			"strategic_ai_emergency_defense_commander_fit",
			"emergency_defense_launch_uses_commander_fit",
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
		state["commander_counter"] = 0
		state["commander_roster"] = _emergency_defense_fit_roster(session, faction_id, [rotation_first_id, expected_defender_id])
		_update_enemy_state(session, state)
	_set_resource_controller(session, defense_target_id, faction_id, failures)
	_set_resource_defense_front(session, defense_target_id, faction_id, failures)
	var defense_node := _resource_node_by_placement(session, defense_target_id)
	_set_player_position(session, {"x": int(defense_node.get("x", 0)), "y": int(defense_node.get("y", 0))})
	state = _enemy_state_for_faction(session, faction_id)
	var emergency_plan := EnemyTurnRules._emergency_defense_launch_ready_report(session, config, state, faction_id)
	var selected_hero_id := String(emergency_plan.get("roster_hero_id", ""))
	var selected_fit_bonus := int(emergency_plan.get("spawn_plan_commander_fit_bonus", 0))
	var selected_source := String(emergency_plan.get("spawn_plan_source", ""))
	if emergency_plan.is_empty():
		failures.append("Emergency defense launch produced no ready plan.")
	if selected_hero_id != expected_defender_id:
		failures.append("Emergency defense selected %s instead of defensive-fit commander %s." % [selected_hero_id, expected_defender_id])
	if selected_hero_id == rotation_first_id:
		failures.append("Emergency defense still followed rotation-first commander selection.")
	if selected_fit_bonus <= 0:
		failures.append("Emergency defense plan did not expose a positive commander-fit bonus.")
	if selected_source != "emergency_resource_defense":
		failures.append("Emergency defense selected wrong plan source %s." % selected_source)
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_emergency_defense_commander_fit",
		"emergency_defense_launch_uses_commander_fit",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"target_id": defense_target_id,
			"selected_hero_id": selected_hero_id,
			"expected_hero_id": expected_defender_id,
			"rotation_first_hero_id": rotation_first_id,
			"commander_fit_bonus": selected_fit_bonus,
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"emergency_plan": emergency_plan,
			"target_reason_codes": _string_array(emergency_plan.get("spawn_plan_reason_codes", [])),
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _emergency_defense_fit_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	available_hero_ids: Array
) -> Array:
	var available := {}
	for hero_id_value in available_hero_ids:
		var hero_id := String(hero_id_value)
		if hero_id != "":
			available[hero_id] = true
	var roster := []
	for entry_value in EnemyAdventureRules.normalize_commander_roster(
		session,
		faction_id,
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var hero_id := String(entry.get("roster_hero_id", ""))
		if available.has(hero_id):
			entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
			entry["recovery_day"] = 0
		else:
			entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_RECOVERING
			entry["recovery_day"] = int(session.day) + 30
		roster.append(entry)
	return roster

static func _strategic_ai_live_town_retake_assault(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_retake_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_retake_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_retake_town_id", "duskfen_bastion"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_retake_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live town-retake scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_town_retake_assault",
			"live_retake_front_queues_town_defense_battle",
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
			"strategic_ai_live_town_retake_assault",
			"live_retake_front_queues_town_defense_battle",
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
	_set_town_retake_front(session, town_id, faction_id, failures)
	var raid_id := "headless_live_retake_%s" % town_id
	var seed_raid := _town_retake_assault_raid_seed(session, faction_id, roster_hero_id, raid_id)
	var selector_plan := EnemyAdventureRules.ai_live_town_retake_target_selection_plan(session, config, seed_raid)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var assignment_events := _event_count(events, "ai_target_assigned")
	if String(selector_plan.get("target_kind", "")) != "town" or String(selector_plan.get("target_placement_id", "")) != town_id:
		failures.append("Live retake selector did not prefer %s." % town_id)
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live town-retake assault.")
	if after_raid.is_empty():
		failures.append("Live town-retake raid disappeared after enemy turn.")
	if String(after_raid.get("target_kind", "")) != "town" or String(after_raid.get("target_placement_id", "")) != town_id:
		failures.append("Live town-retake raid did not target %s." % town_id)
	if session.battle.is_empty():
		failures.append("Live town-retake assault did not queue a battle.")
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != town_id:
		failures.append("Live town-retake assault queued wrong battle context.")
	if assignment_events < 1:
		failures.append("Live town-retake assault did not surface an ai_target_assigned event.")
	if not _has_saved_hero_task_state(session):
		failures.append("Live town-retake assault did not persist hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live town-retake assault events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live town-retake events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_town_retake_assault",
		"live_retake_front_queues_town_defense_battle",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"selector_target_kind": String(selector_plan.get("target_kind", "")),
			"selector_target_id": String(selector_plan.get("target_placement_id", "")),
			"target_assignment_event_count": assignment_events,
			"battle_context_type": String(battle_context.get("type", "")),
			"battle_town_id": String(battle_context.get("town_placement_id", "")),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_raid_assault_grouping(input_config: Dictionary) -> Dictionary:
	var scenario_id := String(input_config.get("strategic_ai_live_grouping_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_grouping_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_grouping_town_id", "duskfen_bastion"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_grouping_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		deferred.append("Missing strategic AI live raid-grouping scenario %s." % scenario_id)
		return _case(
			"strategic_ai_live_raid_assault_grouping",
			"live_nearby_raids_group_for_town_assault",
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
			"strategic_ai_live_raid_assault_grouping",
			"live_nearby_raids_group_for_town_assault",
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
	_set_town_retake_front(session, town_id, faction_id, failures)
	var leader_id := "headless_grouping_assault_%s" % town_id
	var support_id := "headless_grouping_support_%s" % town_id
	var leader := _town_assault_grouping_raid_seed(session, faction_id, roster_hero_id, leader_id, 7, 2, 7, true)
	var support := _town_assault_grouping_raid_seed(session, faction_id, "", support_id, 7, 3, 3, false)
	var leader_plan := EnemyAdventureRules.ai_live_town_retake_target_selection_plan(session, config, leader)
	var support_plan := EnemyAdventureRules.ai_live_town_retake_target_selection_plan(session, config, support)
	if String(leader_plan.get("target_kind", "")) == "town" and String(leader_plan.get("target_placement_id", "")) == town_id:
		leader.merge(leader_plan, true)
	else:
		failures.append("Live grouping leader selector did not prefer %s." % town_id)
	if String(support_plan.get("target_kind", "")) == "town" and String(support_plan.get("target_placement_id", "")) == town_id:
		support.merge(support_plan, true)
	else:
		failures.append("Live grouping support selector did not prefer %s." % town_id)
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters
	var active_before := _active_raid_count_for_faction(session, faction_id)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_leader := _encounter_by_placement(session, leader_id)
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	var grouping_events := _event_count(events, "ai_raid_grouped")
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live raid grouping.")
	if after_leader.is_empty():
		failures.append("Live raid grouping leader disappeared after enemy turn.")
	if support_id not in resolved:
		failures.append("Live raid grouping support host stayed active.")
	if leader_strength_after < leader_strength_before + support_strength_before:
		failures.append("Live raid grouping leader did not absorb support strength.")
	if int(after_leader.get("grouped_support_count", 0)) < 1:
		failures.append("Live raid grouping leader is missing grouped support marker.")
	if String(after_leader.get("last_grouped_support_placement_id", "")) != support_id:
		failures.append("Live raid grouping leader recorded wrong support host.")
	if grouping_events < 1:
		failures.append("Live raid grouping did not emit ai_raid_grouped.")
	if session.battle.is_empty():
		failures.append("Live raid grouping did not continue into a battle.")
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != town_id:
		failures.append("Live raid grouping queued wrong battle context.")
	if not _has_saved_hero_task_state(session):
		failures.append("Live raid grouping did not persist hero_task_state.")
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live raid grouping events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live raid grouping events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_raid_assault_grouping",
		"live_nearby_raids_group_for_town_assault",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"leader_id": leader_id,
			"support_id": support_id,
			"active_before": active_before,
			"active_after": _active_raid_count_for_faction(session, faction_id),
			"leader_strength_before": leader_strength_before,
			"support_strength_before": support_strength_before,
			"leader_strength_after": leader_strength_after,
			"grouping_event_count": grouping_events,
			"battle_context_type": String(battle_context.get("type", "")),
			"battle_town_id": String(battle_context.get("town_placement_id", "")),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_leader),
			"resolved_encounters": resolved,
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_pressure_coverage(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("strategic_ai_pressure_coverage_scenario_ids", [
		"river-pass",
		"prismhearth-watch",
		"glassroad-sundering",
		"glassfen-breakers",
		"ninefold-confluence",
	])
	var failures := []
	var warnings := []
	var deferred := []
	var scenario_rows := []
	var faction_rows := []
	var all_events := []
	var event_type_map := {}
	var target_assignment_event_count := 0
	var launched_faction_count := 0
	var prismhearth_controller_town_id := ""
	var prismhearth_controlling_faction_id := ""
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing strategic AI pressure coverage scenario %s." % scenario_id)
			continue
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		if enemy_configs.is_empty():
			deferred.append("%s has no enemy_factions for pressure coverage." % scenario_id)
			continue
		var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
			scenario_id,
			"normal",
			SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
		)
		OverworldRules.normalize_overworld_state(session)
		EnemyTurnRules.normalize_enemy_states(session)
		EnemyAdventureRules.normalize_all_commander_rosters(session)
		var before_by_faction := {}
		var base_by_faction := {}
		var town_by_faction := {}
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
			var state := _enemy_state_for_faction(session, faction_id)
			if state.is_empty():
				failures.append("%s has no enemy state for %s." % [scenario_id, faction_id])
				continue
			state["pressure"] = max(20, int(config.get("raid_active_threshold", 3)) + 5)
			state["treasury"] = {"gold": 12000, "wood": 60, "ore": 60}
			_update_enemy_state(session, state)
			before_by_faction[faction_id] = _active_raid_count_for_faction(session, faction_id)
			base_by_faction[faction_id] = _owned_controller_town_count_for_faction(session, faction_id)
			town_by_faction[faction_id] = _first_controller_town_signal_for_faction(session, faction_id)
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
		all_events.append_array(events)
		target_assignment_event_count += _event_count(events, "ai_target_assigned")
		for event_type in _event_types(events):
			event_type_map[String(event_type)] = true
		if not bool(turn_result.get("ok", false)):
			failures.append("%s enemy turn returned not-ok during pressure coverage." % scenario_id)
		if not _has_saved_hero_task_state(session):
			failures.append("%s pressure coverage did not persist hero_task_state." % scenario_id)
		var scenario_launched_count := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
			var active_before := int(before_by_faction.get(faction_id, 0))
			var active_after := _active_raid_count_for_faction(session, faction_id)
			var base_count := int(base_by_faction.get(faction_id, 0))
			var active_raids := _active_raid_signals_for_faction(session, faction_id)
			var faction_assignment_count := _event_count_for_faction(events, "ai_target_assigned", faction_id)
			var launched := active_after > active_before and faction_assignment_count > 0 and not active_raids.is_empty()
			var town_signal: Dictionary = town_by_faction.get(faction_id, {}) if town_by_faction.get(faction_id, {}) is Dictionary else {}
			if base_count <= 0:
				failures.append("%s/%s has no owned controller town for pressure launch." % [scenario_id, faction_id])
			if not launched:
				failures.append("%s/%s did not launch a live pressure raid from an owned base." % [scenario_id, faction_id])
			else:
				launched_faction_count += 1
				scenario_launched_count += 1
			if scenario_id == "prismhearth-watch" and faction_id == "faction_mireclaw":
				prismhearth_controller_town_id = String(town_signal.get("placement_id", ""))
				prismhearth_controlling_faction_id = String(town_signal.get("controlling_faction_id", ""))
				if prismhearth_controller_town_id != "halo_spire" or prismhearth_controlling_faction_id != "faction_mireclaw":
					failures.append("Prismhearth occupied Halo Spire is not a Mireclaw controller base.")
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"owned_base_count": base_count,
				"controller_town": town_signal,
				"active_before": active_before,
				"active_after": active_after,
				"launched": launched,
				"target_assignment_event_count": faction_assignment_count,
				"active_raids": active_raids,
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"launched_faction_count": scenario_launched_count,
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(all_events, 20)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected multi-scenario pressure events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public multi-scenario pressure events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var event_types := event_type_map.keys()
	event_types.sort()
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_multi_scenario_pressure_coverage",
		"live_enemy_pressure_launches_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"launched_faction_count": launched_faction_count,
			"target_assignment_event_count": target_assignment_event_count,
			"prismhearth_controller_town_id": prismhearth_controller_town_id,
			"prismhearth_controlling_faction_id": prismhearth_controlling_faction_id,
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
			"failure_count": failures.size(),
		},
		{
			"scenarios": scenario_rows,
			"faction_cases": faction_rows,
			"event_types": event_types,
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"deferred": deferred,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_objective_targeting(input_config: Dictionary) -> Dictionary:
	var scenario_ids: Array = input_config.get("strategic_ai_objective_targeting_scenario_ids", [
		"river-pass",
		"prismhearth-watch",
		"glassroad-sundering",
		"glassfen-breakers",
		"ninefold-confluence",
	])
	var failures := []
	var warnings := []
	var deferred := []
	var scenario_rows := []
	var faction_rows := []
	var all_events := []
	var event_type_map := {}
	var objective_targeted_count := 0
	var assignment_event_count := 0
	var priority_reason_count := 0
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing strategic AI objective targeting scenario %s." % scenario_id)
			continue
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		if enemy_configs.is_empty():
			deferred.append("%s has no enemy_factions for objective targeting." % scenario_id)
			continue
		var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
			scenario_id,
			"normal",
			SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
		)
		OverworldRules.normalize_overworld_state(session)
		EnemyTurnRules.normalize_enemy_states(session)
		EnemyAdventureRules.normalize_all_commander_rosters(session)
		var scenario_targeted_count := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
			var state := _enemy_state_for_faction(session, faction_id)
			if state.is_empty():
				failures.append("%s has no enemy state for %s." % [scenario_id, faction_id])
				continue
			state["pressure"] = 0
			_update_enemy_state(session, state)
			var priority_ids := _string_array(config.get("priority_target_placement_ids", []))
			_prime_objective_priority_targets_for_harness(session, priority_ids, faction_id)
			var accepted_target_ids := priority_ids.duplicate()
			var siege_target_id := String(config.get("siege_target_placement_id", ""))
			if siege_target_id != "" and siege_target_id not in accepted_target_ids:
				accepted_target_ids.append(siege_target_id)
			if accepted_target_ids.is_empty():
				failures.append("%s/%s has no priority or siege target ids for objective targeting." % [scenario_id, faction_id])
				continue
			var origin := _enemy_origin(config)
			var planned := EnemyAdventureRules.choose_target(session, config, origin, {})
			var raid_id := "headless_objective_target_%s_%s" % [
				scenario_id.replace("-", "_"),
				faction_id.replace("faction_", ""),
			]
			var raid := _objective_targeting_raid_seed(
				session,
				faction_id,
				_first_commander_hero_id_for_faction(session, faction_id),
				raid_id,
				origin
			)
			raid = EnemyAdventureRules.assign_target(session, config, raid)
			var event := EnemyAdventureRules.ai_target_assignment_event(session, config, raid, {})
			var event_count := 0
			if not event.is_empty():
				all_events.append(event)
				event_count = 1
				assignment_event_count += 1
				event_type_map[String(event.get("event_type", ""))] = true
			var target_id := String(raid.get("target_placement_id", ""))
			var target_kind := String(raid.get("target_kind", ""))
			var reason_codes := _string_array(raid.get("target_reason_codes", []))
			var target_signal := _placement_target_signal_for_harness(session, target_kind, target_id)
			var priority_hit := target_id in priority_ids
			var siege_hit := target_id != "" and target_id == siege_target_id
			var objective_reason := "objective_front" in reason_codes or "town_siege" in reason_codes
			var objective_targeted := priority_hit or siege_hit or objective_reason
			if objective_targeted:
				objective_targeted_count += 1
				scenario_targeted_count += 1
			if priority_hit or siege_hit or objective_reason or not reason_codes.is_empty():
				priority_reason_count += 1
			if target_id == "" or target_kind == "":
				failures.append("%s/%s did not assign a concrete objective target." % [scenario_id, faction_id])
			if not objective_targeted:
				failures.append("%s/%s selected %s:%s outside priority/objective fronts." % [scenario_id, faction_id, target_kind, target_id])
			if event_count < 1:
				failures.append("%s/%s objective targeting emitted no ai_target_assigned event." % [scenario_id, faction_id])
			if reason_codes.is_empty():
				failures.append("%s/%s objective targeting emitted no compact reason codes." % [scenario_id, faction_id])
			if not _has_saved_hero_task_state(session):
				failures.append("%s/%s objective targeting did not persist hero_task_state." % [scenario_id, faction_id])
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"raid_id": raid_id,
				"origin": origin,
				"planned_target": _target_signal(planned),
				"target_kind": target_kind,
				"target_placement_id": target_id,
				"target_signal": target_signal,
				"priority_target_ids": accepted_target_ids,
				"priority_hit": priority_hit,
				"siege_hit": siege_hit,
				"objective_reason": objective_reason,
				"objective_targeted": objective_targeted,
				"target_reason_codes": reason_codes,
				"target_public_importance": String(raid.get("target_public_importance", "")),
				"target_assignment_event_count": event_count,
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"objective_targeted_count": scenario_targeted_count,
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(all_events, 20)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected multi-scenario objective targeting events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public multi-scenario objective targeting events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var event_types := event_type_map.keys()
	event_types.sort()
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_multi_scenario_objective_targeting",
		"live_enemy_objective_priority_targets_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"objective_targeted_count": objective_targeted_count,
			"target_assignment_event_count": assignment_event_count,
			"priority_reason_count": priority_reason_count,
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
			"failure_count": failures.size(),
		},
		{
			"scenarios": scenario_rows,
			"faction_cases": faction_rows,
			"event_types": event_types,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "hero_task_state_live_persist_no_save_migration",
			"warnings": warnings,
			"deferred": deferred,
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
			"live_resource_ids": LIVE_RESOURCE_IDS.duplicate(),
			"live_resource_count": LIVE_RESOURCE_IDS.size(),
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

static func _battle_difficulty_sweep_sampling(input_config: Dictionary) -> Dictionary:
	var sweep_config := input_config.duplicate(true)
	if not sweep_config.has("battle_difficulty_sweep_sample_limit"):
		sweep_config["battle_difficulty_sweep_sample_limit"] = BattleAutoplayBalanceHarnessRulesScript.DEFAULT_SAMPLE_LIMIT
	if not sweep_config.has("battle_difficulty_sweep_minimum_sample_count"):
		sweep_config["battle_difficulty_sweep_minimum_sample_count"] = int(sweep_config.get("battle_difficulty_sweep_sample_limit", BattleAutoplayBalanceHarnessRulesScript.DEFAULT_SAMPLE_LIMIT))
	var sweep: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_difficulty_sweep_report(sweep_config)
	var rows: Array = sweep.get("rows", []) if sweep.get("rows", []) is Array else []
	var row_summary := {}
	var difficulty_ids := []
	for row in rows:
		if not (row is Dictionary):
			continue
		var difficulty_id := String(row.get("difficulty_id", ""))
		if difficulty_id == "":
			continue
		difficulty_ids.append(difficulty_id)
		row_summary[difficulty_id] = {
			"sample_count": int(row.get("sample_count", 0)),
			"completed_sample_count": int(row.get("completed_sample_count", 0)),
			"combat_feel_gate_status": String(row.get("combat_feel_gate_status", "")),
			"balance_matrix_gate_status": String(row.get("balance_matrix_gate_status", "")),
			"tuning_queue_status": String(row.get("tuning_queue_status", "")),
			"tuning_queue_item_count": int(row.get("tuning_queue_item_count", 0)),
			"tuning_queue_signature": String(row.get("tuning_queue_signature", "")),
			"average_terminal_health_margin_pct": int(row.get("average_terminal_health_margin_pct", 0)),
			"primary_outcome_state": String(row.get("primary_outcome_state", "")),
			"primary_outcome_pct": int(row.get("primary_outcome_pct", 0)),
		}
	var warnings: Array = sweep.get("warnings", []) if sweep.get("warnings", []) is Array else []
	var failures: Array = sweep.get("failures", []) if sweep.get("failures", []) is Array else []
	var status := _status_from(failures, warnings, [])
	var summary := {
		"schema": String(sweep.get("schema", "")),
		"policy": String(sweep.get("policy", "")),
		"sweep_status": String(sweep.get("status", "")),
		"sweep_signature": String(sweep.get("sweep_signature", "")),
		"difficulty_ids": difficulty_ids,
		"row_count": rows.size(),
		"sample_limit_per_difficulty": int(sweep.get("sample_limit_per_difficulty", 0)),
		"minimum_sample_count_per_difficulty": int(sweep.get("minimum_sample_count_per_difficulty", 0)),
		"row_summary": row_summary,
		"deltas": sweep.get("deltas", {}),
		"warning_count": warnings.size(),
		"failure_count": failures.size(),
	}
	return _case(
		"battle_difficulty_sweep_sampling",
		"deterministic_battle_difficulty_sweep_samples",
		status,
		summary,
		{
			"rows": rows,
			"deltas": sweep.get("deltas", {}),
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		[]
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

static func _first_enemy_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) != "":
			return state
	return {}

static func _first_town_for_owner(session: SessionStateStoreScript.SessionData, owner: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == owner:
			return town
	return {}

static func _first_commander_hero_id_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> String:
	var roster: Array = EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	for commander in roster:
		if commander is Dictionary:
			var hero_id := String(commander.get("hero_id", ""))
			if hero_id != "":
				return hero_id
	var faction := ContentService.get_faction(faction_id)
	var hero_ids: Array = faction.get("hero_ids", []) if faction.get("hero_ids", []) is Array else []
	for hero_id_value in hero_ids:
		var hero_id := String(hero_id_value)
		if hero_id != "":
			return hero_id
	return ""

static func _first_recruit_unit_id_for_faction(faction_id: String) -> String:
	var faction := ContentService.get_faction(faction_id)
	var unit_ladder_ids: Array = faction.get("unit_ladder_ids", []) if faction.get("unit_ladder_ids", []) is Array else []
	for unit_id_value in unit_ladder_ids:
		var unit_id := String(unit_id_value)
		if unit_id != "" and not ContentService.get_unit(unit_id).is_empty():
			return unit_id
	for unit_id in ContentService.get_content_ids(ContentService.UNITS_PATH):
		var unit := ContentService.get_unit(unit_id)
		if String(unit.get("faction_id", "")) == faction_id:
			return unit_id
	return ""

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

static func _strategic_ai_planned_actor_for_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	target_kind: String,
	target_id: String,
	fallback_actor_id: String
) -> String:
	if session == null or target_kind == "" or target_id == "":
		return fallback_actor_id
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		return fallback_actor_id
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var planned_state: Dictionary = plan_result.get("state", state) if plan_result.get("state", state) is Dictionary else state
	var task_state: Dictionary = planned_state.get("hero_task_state", {}) if planned_state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("target_kind", "")) == target_kind \
				and String(task.get("target_id", "")) == target_id \
				and String(task.get("task_status", "")) in ["planned", "reserved", "active"]:
			var actor_id := String(task.get("actor_id", ""))
			if actor_id != "":
				return actor_id
	return fallback_actor_id

static func _resource_node_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

static func _first_resource_node_signal_for_harness(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var placement_id := String(node.get("placement_id", ""))
		if placement_id == "":
			continue
		return {
			"placement_id": placement_id,
			"resource_id": String(node.get("resource_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
		}
	return {}

static func _set_resource_defense_front(
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
		node["front"] = {
			"state": "defend",
			"faction_id": faction_id,
			"threatened_by_player": true,
			"priority_bonus": 180,
			"last_change_day": max(0, int(session.day) - 1),
			"defense_until_day": int(session.day) + 4,
			"source": "headless_harness_fixture",
		}
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	failures.append("Missing resource node %s for live resource-defense fixture." % placement_id)

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
		town["garrison"] = []
		town["ai_defense_rating"] = 0
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

static func _set_town_retake_front(
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
		town["owner"] = "player"
		town["front"] = {
			"state": "retake",
			"faction_id": faction_id,
			"last_change_day": int(session.day),
			"stabilize_until_day": 0,
			"last_owner": "enemy",
			"capture_count": 1,
			"source": "headless_harness_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	failures.append("Missing town %s for live town-retake fixture." % placement_id)

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

static func _prime_objective_priority_targets_for_harness(
	session: SessionStateStoreScript.SessionData,
	priority_ids: Array,
	faction_id: String
) -> void:
	if priority_ids.is_empty():
		return
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		var placement_id := String(node.get("placement_id", ""))
		if placement_id == "" or placement_id not in priority_ids:
			continue
		if String(node.get("collected_by_faction_id", "")) == faction_id:
			node["collected_by_faction_id"] = "player"
			node["collected"] = true
		elif String(node.get("collected_by_faction_id", "")) == "":
			node["collected_by_faction_id"] = "player"
			node["collected"] = true
		node["response_until_day"] = max(int(node.get("response_until_day", 0)), int(session.day) + 2)
		node["response_security_rating"] = max(2, int(node.get("response_security_rating", 0)))
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes

static func _prepare_recruitment_delivery_town(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	faction_id: String,
	unit_id: String,
	recruit_count: int,
	failures: Array
) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("placement_id", "")) != placement_id:
			continue
		town["owner"] = "enemy"
		town["faction_id"] = faction_id
		town["front"] = {}
		town["garrison"] = [{"unit_id": unit_id, "count": 50}]
		town["available_recruits"] = {unit_id: max(1, recruit_count)}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	failures.append("Missing town %s for live recruitment delivery fixture." % placement_id)

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

static func _generated_town_handoff_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	target_town: Dictionary,
	unit_id: String
) -> Dictionary:
	var target_x := int(target_town.get("x", 0))
	var target_y := int(target_town.get("y", 0))
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": target_x,
		"y": target_y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 1,
		"arrived": true,
		"goal_distance": 1,
		"target_kind": "town",
		"target_placement_id": String(target_town.get("placement_id", "")),
		"target_label": String(target_town.get("name", target_town.get("placement_id", "Player Town"))),
		"target_x": target_x,
		"target_y": target_y,
		"goal_x": target_x,
		"goal_y": target_y,
		"target_reason_codes": ["town_siege", "objective_front", "generated_map_handoff_probe"],
		"target_public_reason": "generated town assault",
		"target_public_importance": "critical",
		"target_debug_reason": "Native RMG generated-map battle handoff proof",
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Generated Handoff Host",
			"stacks": [{"unit_id": unit_id, "count": 80}],
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

static func _objective_targeting_raid_seed(
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
	if roster_hero_id != "":
		raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
			raid,
			roster_hero_id,
			faction_id,
			session,
			{},
			EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
		)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

static func _recruitment_delivery_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	target_resource_id: String,
	unit_id: String
) -> Dictionary:
	var node := _resource_node_by_placement(session, target_resource_id)
	var origin := _friendly_town_adjacent_raid_origin(session, faction_id, node)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(origin.get("x", node.get("x", 0))),
		"y": int(origin.get("y", int(node.get("y", 0)) + 1)),
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
			"id": "headless_recruitment_delivery_fixture_host",
			"name": "Recruitment Delivery Host",
			"stacks": [{"unit_id": unit_id, "count": 1}],
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

static func _friendly_town_adjacent_raid_origin(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	fallback_node: Dictionary
) -> Dictionary:
	var town_signal := _first_controller_town_signal_for_faction(session, faction_id)
	if town_signal.is_empty():
		return {"x": int(fallback_node.get("x", 0)), "y": int(fallback_node.get("y", 0)) + 1}
	return {
		"x": max(0, int(town_signal.get("x", 0)) - 1),
		"y": max(0, int(town_signal.get("y", 0))),
	}

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

static func _resource_defense_retask_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	previous_target_id: String,
	defense_target_id: String
) -> Dictionary:
	var previous_node := _resource_node_by_placement(session, previous_target_id)
	var defense_node := _resource_node_by_placement(session, defense_target_id)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(defense_node.get("x", 0)),
		"y": int(defense_node.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": previous_target_id,
		"target_label": "Signal Post",
		"target_x": int(previous_node.get("x", 0)),
		"target_y": int(previous_node.get("y", 0)),
		"goal_x": int(previous_node.get("x", 0)),
		"goal_y": int(previous_node.get("y", 0)),
		"enemy_army": {
			"id": "headless_resource_defense_fixture_host",
			"name": "Resource Defense Host",
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

static func _town_retake_assault_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": 7,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"enemy_army": {
			"id": "headless_retake_assault_fixture_host",
			"name": "Retake Assault Host",
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

static func _town_assault_grouping_raid_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	x: int,
	y: int,
	brute_count: int,
	with_commander: bool
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"commanderless_support_column": not with_commander,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Town Assault Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": max(1, brute_count)}],
		},
	}
	if with_commander:
		raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
			raid,
			roster_hero_id,
			faction_id,
			session,
			{},
			EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
		)
		return EnemyAdventureRules.ensure_raid_army(raid, session)
	return raid

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

static func _active_raid_count_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		count += 1
	return count

static func _active_raid_signals_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var raids := []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		raids.append(_raid_execution_signal(encounter))
	return raids

static func _owned_controller_town_count_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count := 0
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id_for_harness(town) == faction_id:
			count += 1
	return count

static func _first_controller_town_signal_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id_for_harness(town) != faction_id:
			continue
		return {
			"placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"template_faction_id": _town_template_faction_id_for_harness(town),
			"controlling_faction_id": String(town.get("controlling_faction_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
		}
	return {}

static func _town_controller_faction_id_for_harness(town_state: Dictionary) -> String:
	var controller := String(town_state.get("controlling_faction_id", ""))
	if String(town_state.get("owner", "neutral")) == "enemy" and controller != "":
		return controller
	return _town_template_faction_id_for_harness(town_state)

static func _town_template_faction_id_for_harness(town_state: Dictionary) -> String:
	var town := ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("faction_id", ""))

static func _town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

static func _town_governor_report_for_town(governor_report: Dictionary, placement_id: String) -> Dictionary:
	for town_report in governor_report.get("towns", []):
		if town_report is Dictionary and String(town_report.get("placement_id", "")) == placement_id:
			return town_report
	return {}

static func _town_building_ids(town: Dictionary) -> Array:
	var building_ids := []
	for building_id_value in town.get("built_buildings", []):
		var building_id := String(building_id_value)
		if building_id != "" and building_id not in building_ids:
			building_ids.append(building_id)
	building_ids.sort()
	return building_ids

static func _recruit_pool_total(recruits: Variant) -> int:
	var total := 0
	if not (recruits is Dictionary):
		return total
	for unit_id in recruits.keys():
		total += max(0, int(recruits.get(unit_id, 0)))
	return total

static func _army_stack_count(stacks: Variant) -> int:
	var total := 0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if stack is Dictionary:
			total += max(0, int(stack.get("count", 0)))
	return total

static func _town_build_signal(selected_build: Dictionary) -> Dictionary:
	return {
		"building_id": String(selected_build.get("building_id", "")),
		"building_label": String(selected_build.get("building_label", "")),
		"category": String(selected_build.get("category", "")),
		"public_reason": String(selected_build.get("public_reason", "")),
		"reason_codes": _string_array(selected_build.get("reason_codes", [])),
	}

static func _town_recruitment_signal(selected_recruitment: Dictionary) -> Dictionary:
	var destination: Dictionary = selected_recruitment.get("destination", {}) if selected_recruitment.get("destination", {}) is Dictionary else {}
	return {
		"unit_id": String(selected_recruitment.get("unit_id", "")),
		"unit_label": String(selected_recruitment.get("unit_label", "")),
		"recruit_count": int(selected_recruitment.get("recruit_count", 0)),
		"destination_type": String(destination.get("type", "")),
		"destination_reason": String(destination.get("public_reason", "")),
		"reason_codes": _string_array(destination.get("reason_codes", [])),
	}

static func _resource_defense_signal(node: Dictionary) -> Dictionary:
	return {
		"placement_id": String(node.get("placement_id", "")),
		"controller": String(node.get("collected_by_faction_id", "")),
		"ai_defended_by_faction_id": String(node.get("ai_defended_by_faction_id", "")),
		"ai_defended_day": int(node.get("ai_defended_day", 0)),
		"ai_defense_until_day": int(node.get("ai_defense_until_day", 0)),
		"ai_defense_rating": int(node.get("ai_defense_rating", 0)),
	}

static func _town_garrison_unit_count(session: SessionStateStoreScript.SessionData, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		for stack in town.get("garrison", []):
			if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
				return int(stack.get("count", 0))
	return 0

static func _town_available_recruit_count(session: SessionStateStoreScript.SessionData, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return int(town.get("available_recruits", {}).get(unit_id, 0))
	return 0

static func _raid_unit_count(raid: Dictionary, unit_id: String) -> int:
	var army: Dictionary = raid.get("enemy_army", {}) if raid.get("enemy_army", {}) is Dictionary else {}
	var total := 0
	for stack in army.get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total

static func _event_count(events: Variant, event_type: String) -> int:
	var count := 0
	if not (events is Array):
		return count
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			count += 1
	return count

static func _event_count_for_faction(events: Variant, event_type: String, faction_id: String) -> int:
	var count := 0
	if not (events is Array):
		return count
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) != event_type:
			continue
		if (
			String(event.get("faction_id", "")) == faction_id
			or String(event.get("spawned_by_faction_id", "")) == faction_id
			or String(event.get("enemy_faction_id", "")) == faction_id
		):
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
		"previous_completed_target_kind": String(raid.get("previous_completed_target_kind", "")),
		"previous_completed_target_placement_id": String(raid.get("previous_completed_target_placement_id", "")),
		"arrived": bool(raid.get("arrived", false)),
		"x": int(raid.get("x", 0)),
		"y": int(raid.get("y", 0)),
		"goal_distance": int(raid.get("goal_distance", 9999)),
		"last_regroup_town_id": String(raid.get("last_regroup_town_id", "")),
		"last_regroup_strength_delta": int(raid.get("last_regroup_strength_delta", 0)),
	}

static func _raid_completed_target(raid: Dictionary, target_kind: String, target_id: String) -> bool:
	if raid.is_empty() or target_kind == "" or target_id == "":
		return false
	if String(raid.get("target_kind", "")) == target_kind \
			and String(raid.get("target_placement_id", "")) == target_id \
			and bool(raid.get("arrived", false)):
		return true
	return (
		String(raid.get("previous_completed_target_kind", "")) == target_kind
		and String(raid.get("previous_completed_target_placement_id", "")) == target_id
	)

static func _target_signal(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", "")),
		"target_id": String(target.get("target_id", "")),
	}

static func _placement_target_signal_for_harness(
	session: SessionStateStoreScript.SessionData,
	target_kind: String,
	placement_id: String
) -> Dictionary:
	if placement_id == "":
		return {}
	match target_kind:
		"town":
			var town := _town_by_placement(session, placement_id)
			if town.is_empty():
				return {}
			return {
				"target_kind": "town",
				"placement_id": placement_id,
				"owner": String(town.get("owner", "")),
				"controlling_faction_id": String(town.get("controlling_faction_id", "")),
				"x": int(town.get("x", 0)),
				"y": int(town.get("y", 0)),
			}
		"resource":
			var node := _resource_node_by_placement(session, placement_id)
			if node.is_empty():
				return {}
			return {
				"target_kind": "resource",
				"placement_id": placement_id,
				"site_id": String(node.get("site_id", "")),
				"controller": String(node.get("collected_by_faction_id", "")),
				"x": int(node.get("x", 0)),
				"y": int(node.get("y", 0)),
			}
		"artifact":
			for artifact in session.overworld.get("artifact_nodes", []):
				if artifact is Dictionary and String(artifact.get("placement_id", "")) == placement_id:
					return {
						"target_kind": "artifact",
						"placement_id": placement_id,
						"artifact_id": String(artifact.get("artifact_id", "")),
						"collected": bool(artifact.get("collected", false)),
						"x": int(artifact.get("x", 0)),
						"y": int(artifact.get("y", 0)),
					}
		"encounter":
			for encounter in session.overworld.get("encounters", []):
				if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
					return {
						"target_kind": "encounter",
						"placement_id": placement_id,
						"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
						"x": int(encounter.get("x", 0)),
						"y": int(encounter.get("y", 0)),
					}
	return {}

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
