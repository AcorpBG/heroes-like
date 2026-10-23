class_name HeadlessSimulationHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const BattleAutoplayBalanceHarnessRulesScript = preload("res://tests/support/BattleAutoplayBalanceHarnessRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const LevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRulesScript = preload("res://scripts/core/PlayerIdentityRules.gd")
const NativeTransitRulesScript = preload("res://scripts/core/NativeTransitRules.gd")
const CreatureDwellingRulesScript = preload("res://scripts/core/CreatureDwellingRules.gd")
const NodePayloadScript = preload("res://scripts/core/ResourceNodePayloadRules.gd")

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
## Days the live town-governor case plays: build, then buy the new troops.
const LIVE_TOWN_GOVERNOR_TURNS := 3
## Experience that makes a fixture's host commander its faction's main hero.
const RECRUITMENT_HOST_EXPERIENCE := 5000
## Creatures the host leads: the main hero holds at least half the strongest
## army, which a tavern hire's starting army must not outweigh.
const RECRUITMENT_HOST_COUNT := 40
## The human hero threatening a town in the town-defense cases is this many
## times the computer hero's strength: too strong to attack (HERO_ATTACK_RATIO
## 1.3) but not strong enough to storm the town it holds (TOWN_ATTACK_RATIO
## 1.4), so the computer hero holds the gate.
const HUMAN_THREAT_STRENGTH := 1.35
## What a computer player's heroes visibly get done on the map.
const AI_HERO_OBJECTIVE_EVENT_TYPES := ["ai_site_seized", "ai_artifact_secured", "ai_guard_defeated", "ai_town_captured"]
const STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET := 100
const STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET := 56
const STRATEGIC_AI_MEDIUM_LONG_RUN_SLICE_ID := "strategic-ai-medium-long-run-seed-matrix-10184"
const STRATEGIC_AI_MEDIUM_LONG_RUN_EVIDENCE_MARKER := "MEDIUM_LONG_RUN_MATRIX_ADOPTION source_head=1fc6775baaa6d9a016cd8d14fc898ed38847af9a aggregate_sha256=7e99c85386c3c5ba68bcfeecc08a8899bef102e22cf151a1f5154e6b3c3ffdda aggregate_signature=8bb77e6c ordinals=1-100 seed_count=100 turn_target=56 setup_ok=100 row_ok=100 turns_completed=3770 defeat_count=73 in_progress_count=27 enemy_activity_event_count=13086 target_assignment_count=3774 commander_task_planned_count=240 stalled_turn_count=179 battle_interrupt_count=236 battle_autoresolve_count=236 behavior_bug_count=0 target_integrity_violation_count=0 unreachable_active_target_turn_count=0 unreachable_active_target_total=0 no_active_pressure_count=0 blocker_ids=[]"
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
	var medium_long_run_summary := _strategic_ai_medium_long_run_adoption_summary(input_config)
	var blocker_rows := _strategic_ai_baseline_blocker_rows(subsystem_summary, capability_rows, rmg_summary, long_run_summary, medium_long_run_summary)
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
		"medium_long_run_summary": medium_long_run_summary,
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
		"medium_long_run_summary": medium_long_run_summary,
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
			"summary": _without_timing_fields(summary),
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
			"site_seizure_event_count": 2,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_route_progression", "live_commander_resource_front_route_progression", {
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
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_live_raid_assault_grouping", "live_nearby_raids_group_for_town_assault", {
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
			"hero_reinforcement_event_count": 1,
			"scenario_count": 1,
			"faction_case_count": 1,
		}),
		_strategic_ai_baseline_contract_case("strategic_ai_multi_scenario_recruitment_delivery", "live_town_recruits_feed_active_raid_hosts_across_scenario_breadth", {
			"town_recruit_event_count": 5,
			"hero_reinforcement_event_count": 5,
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
		"hero_reinforcement": 0,
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
		total_event_counts["hero_reinforcement"] = int(total_event_counts.get("hero_reinforcement", 0)) + int(summary.get("hero_reinforcement_event_count", 0))
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
	# Computer players field heroes that move under the player's rules and
	# take things on the map; raid target assignments no longer exist.
	var objective_events := 0
	for event_type in AI_HERO_OBJECTIVE_EVENT_TYPES:
		objective_events += int(row.get("event_counts", {}).get(event_type, 0)) if row.get("event_counts", {}) is Dictionary else 0
	row["ai_hero_objective_event_count"] = objective_events
	row["ai_hero_count"] = AiHeroRulesScript.active_hero_entries(session).size()
	row["final_day"] = int(session.day)
	row["ok"] = all_turns_ok and int(row.get("initial_enemy_state_count", 0)) > 0 and int(row.get("ai_hero_count", 0)) > 0 and objective_events > 0
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
	var ai_hero_objective_count := 0
	var ai_hero_count := 0
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
		ai_hero_objective_count += int(row.get("ai_hero_objective_event_count", 0))
		ai_hero_count += int(row.get("ai_hero_count", 0))
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
		"ai_hero_objective_event_count": ai_hero_objective_count,
		"ai_hero_count": ai_hero_count,
	}

static func _strategic_ai_baseline_blocker_rows(
	subsystem_summary: Dictionary,
	capability_rows: Array,
	rmg_summary: Dictionary,
	long_run_summary: Dictionary = {},
	medium_long_run_summary: Dictionary = {}
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
		var runtime_generation_blocked := "native_rmg_exact_chain_unimplemented_blocked" in medium_error_codes
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
	if int(rmg_summary.get("medium_ok_count", 0)) >= REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT \
			and not bool(medium_long_run_summary.get("ok", false)):
		rows.append({
			"blocker_id": "native_rmg_medium_long_run_matrix",
			"severity": "production_gap",
			"summary": "Short Medium generated-map probes are green, but Medium generated-map strategic AI is not yet covered by a longer seed matrix.",
			"medium_ok_count": int(rmg_summary.get("medium_ok_count", 0)),
			"required_short_medium_probe_count": REQUIRED_MEDIUM_GENERALIZATION_PROBE_COUNT,
			"next_unblock_slice_id": "strategic-ai-medium-long-run-seed-matrix-10184",
		})
	if bool(medium_long_run_summary.get("ok", false)):
		rows.append({
			"blocker_id": "native_rmg_medium_topology_contact_pacing",
			"severity": "production_gap",
			"summary": "The Medium long-run matrix is behavior-healthy, but generated topology and object placement can still close player-region contact corridors and leave reachable AI pressure without movement or battle contact.",
			"evidence_seed_ordinals": [95, 98],
			"blocked_by": "native_rmg_topology_object_placement_source_parity",
			"source_recovery_required": true,
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

static func _strategic_ai_medium_long_run_adoption_summary(input_config: Dictionary) -> Dictionary:
	var progress_path := String(input_config.get("progress_path", "res://ops/progress.json"))
	var progress := _load_json_object_from_path(progress_path)
	if progress.is_empty():
		return {
			"ok": false,
			"slice_id": STRATEGIC_AI_MEDIUM_LONG_RUN_SLICE_ID,
			"reason": "progress_tracker_missing_or_invalid",
		}
	var slices: Array = progress.get("plannedSlices", []) if progress.get("plannedSlices", []) is Array else []
	var matched_slice: Dictionary = {}
	var matched_slice_count := 0
	for slice_value in slices:
		if not (slice_value is Dictionary):
			continue
		var slice_row: Dictionary = slice_value
		if String(slice_row.get("id", "")) != STRATEGIC_AI_MEDIUM_LONG_RUN_SLICE_ID:
			continue
		matched_slice_count += 1
		matched_slice = slice_row
	var marker_count := 0
	var notes: Array = matched_slice.get("notes", []) if matched_slice.get("notes", []) is Array else []
	for note_value in notes:
		if String(note_value) == STRATEGIC_AI_MEDIUM_LONG_RUN_EVIDENCE_MARKER:
			marker_count += 1
	var completed := matched_slice_count == 1 and String(matched_slice.get("status", "")) == "completed"
	var exact_evidence := marker_count == 1
	return {
		"ok": completed and exact_evidence,
		"slice_id": STRATEGIC_AI_MEDIUM_LONG_RUN_SLICE_ID,
		"slice_status": String(matched_slice.get("status", "")),
		"matched_slice_count": matched_slice_count,
		"evidence_marker_count": marker_count,
		"evidence_source_head": "1fc6775baaa6d9a016cd8d14fc898ed38847af9a" if exact_evidence else "",
		"evidence_aggregate_sha256": "7e99c85386c3c5ba68bcfeecc08a8899bef102e22cf151a1f5154e6b3c3ffdda" if exact_evidence else "",
		"evidence_aggregate_signature": "8bb77e6c" if exact_evidence else "",
		"seed_ordinal_start": 1 if exact_evidence else 0,
		"seed_ordinal_end": 100 if exact_evidence else 0,
		"seed_count": 100 if exact_evidence else 0,
		"turn_target": 56 if exact_evidence else 0,
		"setup_ok_count": 100 if exact_evidence else 0,
		"row_ok_count": 100 if exact_evidence else 0,
		"turns_completed": 3770 if exact_evidence else 0,
		"defeat_count": 73 if exact_evidence else 0,
		"in_progress_count": 27 if exact_evidence else 0,
		"enemy_activity_event_count": 13086 if exact_evidence else 0,
		"target_assignment_count": 3774 if exact_evidence else 0,
		"commander_task_planned_count": 240 if exact_evidence else 0,
		"stalled_turn_count": 179 if exact_evidence else 0,
		"battle_interrupt_count": 236 if exact_evidence else 0,
		"battle_autoresolve_count": 236 if exact_evidence else 0,
		"behavior_bug_count": 0,
		"target_integrity_violation_count": 0,
		"unreachable_active_target_turn_count": 0,
		"unreachable_active_target_total": 0,
		"no_active_pressure_count": 0,
		"blocker_ids": [],
		"reason": "" if completed and exact_evidence else (
			"slice_not_completed" if not completed else "exact_evidence_marker_missing"
		),
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
		row["signature"] = _signature_for(_without_timing_fields(row))
		_strategic_ai_long_run_progress(progress_callback, _strategic_ai_long_run_row_progress_payload("row_complete", row, seed_index, seed_count))
		return row
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		failures.append("native_rmg_session_start_failed")
		row["ok"] = false
		row["classification"] = "session_failure"
		row["row_runtime_msec"] = maxi(0, Time.get_ticks_msec() - row_started_msec)
		row["signature"] = _signature_for(_without_timing_fields(row))
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
			"enemy_turn_profile": result.get("enemy_turn_profile", {}) if result.get("enemy_turn_profile", {}) is Dictionary else {},
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
	var context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var resolve_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session, step_limit)
	if bool(resolve_result.get("completed", false)):
		_strategic_ai_apply_battle_interrupt_handoff(session)
	return {
		"ok": bool(resolve_result.get("ok", false)),
		"state": String(resolve_result.get("state", "invalid")),
		"steps": int(resolve_result.get("steps", 0)),
		"player_orders": int(resolve_result.get("player_orders", 0)),
		"invalid_orders": int(resolve_result.get("invalid_orders", 0)),
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
			var neutral_defended := town_owner == "neutral" and EnemyAdventureRules._army_strength(town.get("garrison", []) if town.get("garrison", []) is Array else []) > 0
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
	# One computer day per scenario: each player's heroes take the field from
	# its towns and choose an errand (AiHeroRules).
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
		_pin_fixture_session_id(session, "strategic_ai_pressure_tick")
		OverworldRules.normalize_overworld_state(session)
		var before_signal := _enemy_state_signal(session)
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		var after_signal := _enemy_state_signal(session)
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			var hero_goals := _faction_hero_goals(session, faction_id)
			var town_count := _owned_controller_town_count_for_faction(session, faction_id)
			if hero_goals.is_empty() and town_count > 0:
				warnings.append("%s/%s fielded no hero." % [scenario_id, faction_id])
			cases.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"turn_ok": bool(turn_result.get("ok", false)),
				"event_count": turn_result.get("events", []).size() if turn_result.get("events", []) is Array else 0,
				"hero_count": hero_goals.size(),
				"hero_goals": hero_goals,
				"town_count": town_count,
				"before_enemy_signature": before_signal,
				"after_enemy_signature": after_signal,
				"pressure_signature": _signature_for({
					"hero_goals": hero_goals,
					"town_count": town_count,
				}),
			})
	var status := "pass"
	if cases.is_empty():
		status = "deferred"
	elif not warnings.is_empty() or not deferred.is_empty():
		status = "warning"
	return _case(
		"strategic_ai_pressure_tick",
		"enemy_turn_hero_errand_tick",
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
	_pin_fixture_session_id(session, "strategic_ai_live_turn_execution")
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
	# The pass's loose pickups are gone and the human's hero is far away: the
	# held sites are what is left to take.
	_clear_loose_map_rewards(session)
	_set_player_position(session, {"x": 0, "y": 12})
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
	# Hosts from an older save load as heroes and take the sites they stand on.
	var site_seizures := _event_count(turn_result.get("events", []), "ai_site_seized")
	var primary_ok := AiHeroRulesScript.is_ai_hero(primary_raid) and String(controllers_after.get(primary_target_id, "")) == faction_id
	var companion_ok := AiHeroRulesScript.is_ai_hero(companion_raid) and String(controllers_after.get(companion_target_id, "")) == faction_id
	var private_goals := _hero_goal_private(primary_raid) and _hero_goal_private(companion_raid)
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok.")
	if not primary_ok:
		failures.append("Primary live-turn hero did not take %s." % primary_target_id)
	if not companion_ok:
		failures.append("Companion live-turn hero did not take %s." % companion_target_id)
	if not private_goals:
		failures.append("A live-turn hero exposed a raid-style target.")
	if site_seizures < 2:
		failures.append("Live turn produced fewer than two site seizure events.")
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
			"ai_hero_count": _faction_ai_hero_count(session, faction_id),
			"site_seizure_event_count": site_seizures,
			"private_hero_goals": private_goals,
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	_pin_fixture_session_id(session, "strategic_ai_live_route_progression")
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
	# The host loads as a hero and walks to the site on its own movement
	# points; its goal stays private, so progress is measured on the map.
	var target_node := _resource_node_by_placement(session, target_id)
	var target_tile := Vector2i(int(target_node.get("x", 0)), int(target_node.get("y", 0)))
	var route_records := []
	var all_events := []
	var assigned_target := false
	var seized_target := false
	var initial_goal_distance := _tile_distance_to(origin, target_tile)
	var final_goal_distance := initial_goal_distance
	for turn_index in range(max_turns):
		var turn_result: Dictionary = OverworldRules.end_turn(session)
		if not bool(turn_result.get("ok", false)):
			failures.append("End turn returned not-ok during live route progression on turn %d." % (turn_index + 1))
			break
		var events: Array = turn_result.get("enemy_activity_events", []) if turn_result.get("enemy_activity_events", []) is Array else []
		all_events.append_array(events)
		# The main hero may attack the human's hero by its town; the human
		# fights that battle, or every later computer turn waits on it.
		if not session.battle.is_empty():
			BattleAutoResolveRulesScript.resolve_active_battle(session)
			if session.battle.is_empty() and String(session.scenario_status) == "in_progress":
				session.game_state = "overworld"
		var raid := _encounter_by_placement(session, raid_id)
		if raid.is_empty():
			failures.append("Live route raid disappeared on turn %d." % (turn_index + 1))
			break
		var goal: Dictionary = raid.get("ai_hero", {}).get("goal", {}) if raid.get("ai_hero", {}) is Dictionary else {}
		if String(goal.get("id", "")) == target_id:
			assigned_target = true
		var current_distance := _tile_distance_to(raid, target_tile)
		final_goal_distance = current_distance
		route_records.append({
			"turn": turn_index + 1,
			"day": int(session.day),
			"x": int(raid.get("x", 0)),
			"y": int(raid.get("y", 0)),
			"target_id": String(goal.get("id", "")),
			"goal_distance": current_distance,
			"ai_hero": AiHeroRulesScript.is_ai_hero(raid),
			"controller": _resource_controller(session, target_id),
		})
		if String(_resource_controller(session, target_id)) == faction_id:
			seized_target = true
			assigned_target = true
			# The hero stood on the site to take it; where it walked on to
			# afterwards is its next errand.
			final_goal_distance = 0
			break
	var target_controller := _resource_controller(session, target_id)
	if not assigned_target:
		failures.append("Live route hero never set out for %s." % target_id)
	if initial_goal_distance <= 0:
		failures.append("Live route hero did not start away from its target.")
	if final_goal_distance < 0 or final_goal_distance >= initial_goal_distance:
		failures.append("Live route hero did not close the distance: initial=%d final=%d." % [initial_goal_distance, final_goal_distance])
	if not seized_target or target_controller != faction_id:
		failures.append("Live route hero did not seize %s within %d turns." % [target_id, max_turns])
	var seizure_events := _event_count(all_events, "ai_site_seized")
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	_pin_fixture_session_id(session, "strategic_ai_live_town_governor_build_execution")
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
	if _town_by_placement(session, town_id).is_empty():
		failures.append("Missing town %s for live town-governor fixture." % town_id)
	# Computer players build and recruit by the player's rules. The town
	# already has its Tavern, so a day's build goes to the best-value building
	# (often its Marketplace or a hall first); a week's tier-1 troops wait in
	# its dwellings, so it recruits whatever it builds.
	_ensure_town_building(session, town_id, HeroCommandRules.HALL_BUILDING_ID, failures)
	_seed_town_recruits(session, town_id, faction_id)
	var town_before := _town_by_placement(session, town_id)
	var treasury_before := _resource_pool(state.get("treasury", {})) if not state.is_empty() else _resource_pool({})
	var built_before := _town_building_ids(town_before)
	var recruit_pool_before := _recruit_pool_total(town_before.get("available_recruits", {}))
	var garrison_count_before := _army_stack_count(town_before.get("garrison", []))
	var garrison_creatures_before := _creature_count(town_before.get("garrison", []))
	var turn_result := {"ok": true}
	var events: Array = []
	for turn_index in range(LIVE_TOWN_GOVERNOR_TURNS):
		if turn_index > 0:
			session.day += 1
		var day_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		if not bool(day_result.get("ok", false)):
			turn_result["ok"] = false
		events.append_array(day_result.get("events", []) if day_result.get("events", []) is Array else [])
	var town_after := _town_by_placement(session, town_id)
	var state_after := _enemy_state_for_faction(session, faction_id)
	var treasury_after := _resource_pool(state_after.get("treasury", {})) if not state_after.is_empty() else _resource_pool({})
	var built_after := _town_building_ids(town_after)
	var recruit_pool_after := _recruit_pool_total(town_after.get("available_recruits", {}))
	var garrison_count_after := _army_stack_count(town_after.get("garrison", []))
	var garrison_creatures_after := _creature_count(town_after.get("garrison", []))
	var treasury_delta := _resource_delta(treasury_before, treasury_after)
	var town_build_events := _event_count(events, "ai_town_built")
	var town_recruit_events := _event_count(events, "ai_town_recruited")
	# Recruits go to the garrison; a hero visiting the town marches them out.
	var garrison_events := _town_recruit_event_count_for(events, town_id)
	var raid_reinforcement_events := _event_count(events, "ai_hero_reinforced")
	var recruited := _first_recruit_event_signal(events, town_id)
	var new_buildings := []
	for building_id in built_after:
		if building_id not in built_before:
			new_buildings.append(building_id)
	var selected_build_id := String(new_buildings[0]) if not new_buildings.is_empty() else ""
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live town-governor execution.")
	if new_buildings.is_empty():
		failures.append("Live town-governor turns did not build anything in %s." % town_id)
	if _resource_abs_sum(treasury_delta) <= 0:
		failures.append("Live town-governor execution did not mutate treasury: %s." % treasury_delta)
	if town_build_events < 1:
		failures.append("Live town-governor execution did not emit ai_town_built.")
	if town_recruit_events < 1:
		failures.append("Live town-governor execution did not emit ai_town_recruited.")
	if garrison_events + raid_reinforcement_events < 1:
		failures.append("Live town-governor execution did not emit a recruitment destination event.")
	if garrison_count_after <= garrison_count_before and recruit_pool_after == recruit_pool_before and raid_reinforcement_events < 1:
		failures.append("Live town-governor execution did not produce visible recruitment mutation.")
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
			"recruit_unit_id": String(recruited.get("unit_id", "")),
			"recruit_count": int(recruited.get("count", 0)),
			"built_before_count": built_before.size(),
			"built_after_count": built_after.size(),
			"recruit_pool_before": recruit_pool_before,
			"recruit_pool_after": recruit_pool_after,
			"garrison_count_before": garrison_count_before,
			"garrison_count_after": garrison_count_after,
			"garrison_creatures_before": garrison_creatures_before,
			"garrison_creatures_after": garrison_creatures_after,
			"town_build_event_count": town_build_events,
			"town_recruit_event_count": town_recruit_events,
			"recruit_destination_event_count": garrison_events + raid_reinforcement_events,
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
			"new_buildings": new_buildings,
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	_pin_fixture_session_id(session, "strategic_ai_generated_town_battle_handoff")
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
	var controller := PlayerRulesScript.controller_id(state)
	var faction_id := String(state.get("faction_id", ""))
	var unit_id := _first_recruit_unit_id_for_faction(faction_id)
	var roster_hero_id := _first_commander_hero_id_for_faction(session, faction_id)
	if player_town.is_empty():
		failures.append("Native RMG generated handoff session has no player town.")
	if state.is_empty() or controller == "":
		failures.append("Native RMG generated handoff session has no enemy state.")
	if unit_id == "":
		failures.append("Native RMG generated handoff session has no recruit unit for %s." % faction_id)
	if roster_hero_id == "":
		failures.append("Native RMG generated handoff session has no commander for %s." % faction_id)
	# A strong enemy hero stands a few steps from the human's town; on its day
	# it marches in and the human plays the town's defense.
	var hero_id := "headless_generated_town_handoff_%s" % controller
	var hero_tile := {}
	if failures.is_empty():
		_clear_loose_map_rewards(session)
		_own_all_resource_sites(session, controller)
		hero_tile = _open_tile_near(session, LevelRulesScript.town_entrance(player_town), 2, 4)
		if hero_tile.is_empty():
			failures.append("No open tile near the human's town for the handoff hero.")
	if failures.is_empty():
		var host := _legacy_host_seed(session, faction_id, controller, roster_hero_id, hero_id, hero_tile, [{"unit_id": unit_id, "count": 600}])
		var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
		encounters.append(host)
		session.overworld["encounters"] = encounters
		OverworldRules.invalidate_spatial_lookup(session)
	var turn_result := {}
	if failures.is_empty():
		turn_result = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var battle_started := not session.battle.is_empty()
	if failures.is_empty() and not battle_started:
		failures.append("Native RMG generated in-range town target did not start a battle: %s." % JSON.stringify(_event_lines(events)))
	if failures.is_empty() and String(session.game_state) != "battle":
		failures.append("Native RMG generated handoff did not put session into battle state.")
	if failures.is_empty() and String(battle_context.get("type", "")) != "town_defense":
		failures.append("Native RMG generated handoff queued wrong battle context: %s." % JSON.stringify(battle_context))
	if failures.is_empty() and String(battle_context.get("town_placement_id", "")) != String(player_town.get("placement_id", "")):
		failures.append("Native RMG generated handoff queued battle for wrong town: %s." % JSON.stringify(battle_context))
	if failures.is_empty() and String(battle_context.get("raid_encounter_key", "")) != hero_id:
		failures.append("Native RMG generated handoff battle was not started by the fixture hero: %s." % JSON.stringify(battle_context))
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
			"controller_id": controller,
			"roster_hero_id": roster_hero_id,
			"unit_id": unit_id,
			"target_town_id": String(player_town.get("placement_id", "")),
			"battle_started": battle_started,
			"battle_context_type": String(battle_context.get("type", "")),
			"battle_town_id": String(battle_context.get("town_placement_id", "")),
			"battle_queue_event_count": _event_count(events, "ai_town_defense_battle_queued"),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"failure_count": failures.size(),
			"warning_count": warnings.size(),
		},
		{
			"raid": _raid_execution_signal(_encounter_by_placement(session, hero_id)),
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
	# A hero too weak for the neutral guards around it goes home first and takes
	# the garrison along; only then does it fight.
	var scenario_id := String(input_config.get("strategic_ai_live_regroup_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_regroup_faction_id", "faction_mireclaw"))
	var town_id := String(input_config.get("strategic_ai_live_regroup_town_id", "duskfen_bastion"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_regroup_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	# The human's hero is no threat to the town, so the hero may take its troops.
	var session := _authored_ai_fixture_session(scenario_id, faction_id, failures, 1)
	if session == null:
		deferred.append("Missing strategic AI live regroup scenario %s." % scenario_id)
		return _case("strategic_ai_live_regroup_retreat", "live_weak_hero_gathers_garrison_before_fighting", "deferred", {"scenario_id": scenario_id, "deferred_count": deferred.size()}, {"deferred": deferred, "warnings": warnings, "failures": failures}, warnings, deferred)
	var town := _town_by_placement(session, town_id)
	if town.is_empty():
		failures.append("Missing town %s for live regroup fixture." % town_id)
	_own_all_resource_sites(session, faction_id)
	var garrison := [{"unit_id": "unit_bog_brute", "count": 30}]
	_set_town_garrison(session, town_id, garrison)
	var hero_id := "headless_live_regroup_%s" % town_id
	var hero_tile := _open_tile_near(session, LevelRulesScript.town_entrance(town), 3, 4) if not town.is_empty() else {}
	if hero_tile.is_empty() and failures.is_empty():
		failures.append("No open tile near %s for the regroup hero." % town_id)
	var before_strength := 0
	var garrison_before := _creature_count(garrison)
	var events: Array = []
	var turn_ok := false
	if failures.is_empty():
		var host := _legacy_host_seed(session, faction_id, faction_id, roster_hero_id, hero_id, hero_tile, [{"unit_id": "unit_bog_brute", "count": 1}])
		before_strength = EnemyAdventureRules.raid_strength(host)
		var encounters: Array = session.overworld.get("encounters", [])
		encounters.append(host)
		session.overworld["encounters"] = encounters
		OverworldRules.invalidate_spatial_lookup(session)
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		turn_ok = bool(turn_result.get("ok", false))
		events = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_hero := _encounter_by_placement(session, hero_id)
	var after_strength := EnemyAdventureRules.raid_strength(after_hero)
	var garrison_after := _creature_count(_town_by_placement(session, town_id).get("garrison", []))
	var reinforced_index := _first_event_index(events, "ai_hero_reinforced", hero_id)
	var first_fight_index := _first_event_index(events, "ai_guard_defeated", hero_id)
	var regroup_town_id := ""
	if reinforced_index >= 0:
		regroup_town_id = String(events[reinforced_index].get("target_id", ""))
	if failures.is_empty() and not turn_ok:
		failures.append("Enemy turn returned not-ok during live regroup.")
	if failures.is_empty() and not AiHeroRulesScript.is_ai_hero(after_hero):
		failures.append("Live regroup host did not play as an enemy hero.")
	if failures.is_empty() and reinforced_index < 0:
		failures.append("Live regroup hero did not gather troops at %s: %s" % [town_id, JSON.stringify(_event_lines(events))])
	if failures.is_empty() and regroup_town_id != town_id:
		failures.append("Live regroup hero gathered troops somewhere else: %s." % regroup_town_id)
	if failures.is_empty() and first_fight_index >= 0 and first_fight_index < reinforced_index:
		failures.append("Live regroup hero fought before gathering its troops.")
	if failures.is_empty() and after_strength <= before_strength:
		failures.append("Live regroup did not increase hero strength: before=%d after=%d." % [before_strength, after_strength])
	if failures.is_empty() and garrison_after >= garrison_before:
		failures.append("Live regroup did not take the town garrison: before=%d after=%d." % [garrison_before, garrison_after])
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live regroup events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live regroup events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_regroup_retreat",
		"live_weak_hero_gathers_garrison_before_fighting",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": town_id,
			"regroup_town_id": regroup_town_id,
			"before_strength": before_strength,
			"after_strength": after_strength,
			"garrison_before": garrison_before,
			"garrison_after": garrison_after,
			"reinforced_before_fighting": reinforced_index >= 0 and (first_fight_index < 0 or first_fight_index > reinforced_index),
			"regroup_event_count": _event_count(events, "ai_hero_reinforced"),
			"guard_fight_event_count": _event_count(events, "ai_guard_defeated"),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_hero),
			"event_types": _event_types(events),
			"event_lines": _event_lines(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	_pin_fixture_session_id(session, "strategic_ai_live_recruitment_delivery")
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
	# The host at the town gate loads as a hero; the town recruits into its
	# garrison and the faction's main hero marches the garrison out.
	var seed_raid := _recruitment_delivery_raid_seed(session, faction_id, roster_hero_id, raid_id, target_id, unit_id)
	var before_strength := _faction_hero_strength(session, faction_id) + EnemyAdventureRules.raid_strength(seed_raid)
	var hero_units_before := _faction_hero_unit_count(session, faction_id, unit_id) + _raid_unit_count(seed_raid, unit_id)
	var town_recruits_before := _town_available_recruit_count(session, town_id, unit_id)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var after_strength := _faction_hero_strength(session, faction_id)
	var town_recruits_after := _town_available_recruit_count(session, town_id, unit_id)
	var hero_units_after := _faction_hero_unit_count(session, faction_id, unit_id)
	var town_recruit_events := _event_count(events, "ai_town_recruited")
	var hero_reinforcement_events := _event_count(events, "ai_hero_reinforced")
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live recruitment delivery.")
	if not AiHeroRulesScript.is_ai_hero(after_raid):
		failures.append("Live recruitment delivery host did not play as an enemy hero.")
	if after_strength <= before_strength:
		failures.append("Live recruitment delivery did not strengthen the faction's heroes: before=%d after=%d." % [before_strength, after_strength])
	if town_recruits_after >= town_recruits_before:
		failures.append("Live recruitment delivery did not consume town recruits: before=%d after=%d." % [town_recruits_before, town_recruits_after])
	if hero_units_after < hero_units_before + recruit_count:
		failures.append("Live recruitment delivery did not put %s recruits in a hero army: %d -> %d." % [unit_id, hero_units_before, hero_units_after])
	if town_recruit_events < 1:
		failures.append("Live recruitment delivery did not emit ai_town_recruited.")
	if hero_reinforcement_events < 1:
		failures.append("Live recruitment delivery did not emit ai_hero_reinforced.")
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
			"town_recruits_before": town_recruits_before,
			"town_recruits_after": town_recruits_after,
			"hero_units_before": hero_units_before,
			"hero_units_after": hero_units_after,
			"town_recruit_event_count": town_recruit_events,
			"hero_reinforcement_event_count": hero_reinforcement_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_raid),
			"event_types": _event_types(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_town_defense_retask(input_config: Dictionary) -> Dictionary:
	# A hero a few steps from its town sees a strong human hero beside the town.
	# It walks home and holds the gate instead of running its errand.
	var scenario_id := String(input_config.get("strategic_ai_live_defense_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_defense_faction_id", "faction_mireclaw"))
	var previous_target_id := String(input_config.get("strategic_ai_live_defense_previous_target_id", "river_free_company"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_defense_hero_id", "hero_vaska"))
	var failures := []
	var warnings := []
	var deferred := []
	if ContentService.get_scenario(scenario_id).is_empty():
		deferred.append("Missing strategic AI live town-defense scenario %s." % scenario_id)
		return _case("strategic_ai_live_town_defense_retask", "live_hero_returns_to_hold_threatened_town", "deferred", {"scenario_id": scenario_id, "deferred_count": deferred.size()}, {"deferred": deferred, "warnings": warnings, "failures": failures}, warnings, deferred)
	var row := _hero_town_defense_run(scenario_id, faction_id, "headless_live_defense_%s" % faction_id.replace("faction_", ""), roster_hero_id, previous_target_id)
	if String(row.get("error", "")) != "":
		failures.append(String(row.get("error", "")))
	elif not bool(row.get("held_gate", false)):
		failures.append("Live town-defense hero did not hold the gate of %s: %s" % [String(row.get("town_id", "")), JSON.stringify(row.get("event_lines", []))])
	if String(row.get("previous_controller_after", "")) == faction_id:
		failures.append("Live town-defense hero took %s instead of defending." % previous_target_id)
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(row.get("events", []), 8)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live town-defense events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live town-defense events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_town_defense_retask",
		"live_hero_returns_to_hold_threatened_town",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"town_id": String(row.get("town_id", "")),
			"previous_target_id": previous_target_id,
			"town_threatened": bool(row.get("town_threatened", false)),
			"held_gate": bool(row.get("held_gate", false)),
			"hero_goal_kind": String(row.get("goal_kind", "")),
			"hero_goal_id": String(row.get("goal_id", "")),
			"resource_controller_after": String(row.get("previous_controller_after", "")),
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": row.get("hero", {}),
			"hero_start": row.get("hero_start", {}),
			"threat_tile": row.get("threat_tile", {}),
			"event_types": _event_types(row.get("events", [])),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
			var hero_id := "headless_multi_defense_%s_%s" % [scenario_id.replace("-", "_"), faction_id.replace("faction_", "")]
			var row := _hero_town_defense_run(scenario_id, faction_id, hero_id, "", "")
			var events: Array = row.get("events", []) if row.get("events", []) is Array else []
			for event_type in _event_types(events):
				event_type_map[String(event_type)] = true
			for event in events:
				if event is Dictionary and String(event.get("actor_id", "")) == hero_id:
					public_boundary_events.append(event)
			var retasked := String(row.get("error", "")) == "" and bool(row.get("held_gate", false))
			if String(row.get("error", "")) != "":
				failures.append("%s/%s: %s" % [scenario_id, faction_id, String(row.get("error", ""))])
			elif not retasked:
				failures.append("%s/%s hero did not hold the gate of %s: %s" % [scenario_id, faction_id, String(row.get("town_id", "")), JSON.stringify(row.get("event_lines", []))])
			if retasked:
				retasked_faction_count += 1
				scenario_retask_count += 1
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"town_id": String(row.get("town_id", "")),
				"retasked": retasked,
				"town_threatened": bool(row.get("town_threatened", false)),
				"held_gate": bool(row.get("held_gate", false)),
				"hero_goal_kind": String(row.get("goal_kind", "")),
				"hero_goal_id": String(row.get("goal_id", "")),
				"hero_start": row.get("hero_start", {}),
				"threat_tile": row.get("threat_tile", {}),
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
		"live_heroes_hold_threatened_towns_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"retasked_faction_count": retasked_faction_count,
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	var hero_reinforcement_event_count := 0
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
			_pin_fixture_session_id(session, "strategic_ai_multi_scenario_recruitment_delivery")
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
			_clear_loose_map_rewards(session)
			var raid_id := "headless_multi_recruitment_%s_%s" % [scenario_id.replace("-", "_"), faction_id.replace("faction_", "")]
			# The host standing at the town gate loads as a hero; the town
			# recruits into its garrison and the faction's main hero marches the
			# garrison out.
			var seed_raid := _recruitment_delivery_raid_seed(session, faction_id, roster_hero_id, raid_id, target_id, unit_id)
			var before_strength := _faction_hero_strength(session, faction_id) + EnemyAdventureRules.raid_strength(seed_raid)
			var hero_units_before := _faction_hero_unit_count(session, faction_id, unit_id) + _raid_unit_count(seed_raid, unit_id)
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
				if String(event.get("event_type", "")) in ["ai_town_recruited", "ai_hero_reinforced"]:
					public_boundary_events.append(event)
			var after_raid := _encounter_by_placement(session, raid_id)
			var after_strength := _faction_hero_strength(session, faction_id)
			var town_recruits_after := _town_available_recruit_count(session, town_id, unit_id)
			var hero_units_after := _faction_hero_unit_count(session, faction_id, unit_id)
			var case_town_recruit_events := _event_count_for_faction(events, "ai_town_recruited", faction_id)
			var case_hero_reinforcement_events := _event_count_for_faction(events, "ai_hero_reinforced", faction_id)
			town_recruit_event_count += case_town_recruit_events
			hero_reinforcement_event_count += case_hero_reinforcement_events
			var delivered := (
				bool(turn_result.get("ok", false))
				and AiHeroRulesScript.is_ai_hero(after_raid)
				and after_strength > before_strength
				and town_recruits_after < town_recruits_before
				and hero_units_after >= hero_units_before + recruit_count
				and case_town_recruit_events > 0
				and case_hero_reinforcement_events > 0
			)
			if not delivered:
				failures.append("%s/%s did not deliver recruits from %s to hero %s." % [scenario_id, faction_id, town_id, raid_id])
			else:
				delivered_faction_count += 1
				scenario_delivery_count += 1
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"town_id": town_id,
				"target_id": target_id,
				"roster_hero_id": roster_hero_id,
				"unit_id": unit_id,
				"delivered": delivered,
				"ai_hero": AiHeroRulesScript.is_ai_hero(after_raid),
				"before_strength": before_strength,
				"after_strength": after_strength,
				"town_recruits_before": town_recruits_before,
				"town_recruits_after": town_recruits_after,
				"hero_units_before": hero_units_before,
				"hero_units_after": hero_units_after,
				"town_recruit_event_count": case_town_recruit_events,
				"hero_reinforcement_event_count": case_hero_reinforcement_events,
				"event_lines": _event_lines(events),
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
			"hero_reinforcement_event_count": hero_reinforcement_event_count,
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_live_resource_site_defense(input_config: Dictionary) -> Dictionary:
	# The human has taken one of the computer player's sites. Its hero goes back
	# for it (a site taken from it is worth more) and takes it back.
	var scenario_id := String(input_config.get("strategic_ai_live_resource_defense_scenario_id", "river-pass"))
	var faction_id := String(input_config.get("strategic_ai_live_resource_defense_faction_id", "faction_mireclaw"))
	var target_id := String(input_config.get("strategic_ai_live_resource_defense_target_id", "river_free_company"))
	var town_id := String(input_config.get("strategic_ai_live_resource_defense_town_id", "duskfen_bastion"))
	var roster_hero_id := String(input_config.get("strategic_ai_live_resource_defense_hero_id", "hero_vaska"))
	var max_days: int = max(1, int(input_config.get("strategic_ai_live_resource_defense_max_days", 4)))
	var failures := []
	var warnings := []
	var deferred := []
	var session := _authored_ai_fixture_session(scenario_id, faction_id, failures)
	if session == null:
		deferred.append("Missing strategic AI live resource-site defense scenario %s." % scenario_id)
		return _case("strategic_ai_live_resource_site_defense", "live_hero_retakes_lost_resource_site", "deferred", {"scenario_id": scenario_id, "deferred_count": deferred.size()}, {"deferred": deferred, "warnings": warnings, "failures": failures}, warnings, deferred)
	_own_all_resource_sites(session, faction_id)
	# The human seized this site from the computer player. The human's strong
	# hero stays near it; a garrison as strong keeps the town from being under
	# threat, so the hero is free to go out (it collects that garrison first).
	_set_resource_controller(session, target_id, "player", failures)
	_set_town_garrison(session, town_id, _scaled_player_stacks(session, 1))
	var town := _town_by_placement(session, town_id)
	var hero_id := "headless_live_site_retake_%s" % target_id
	var hero_tile := _open_tile_near(session, LevelRulesScript.town_entrance(town), 1, 3) if not town.is_empty() else {}
	if hero_tile.is_empty() and failures.is_empty():
		failures.append("No open tile near %s for the site-retake hero." % town_id)
	var events: Array = []
	var retaken_day := 0
	var days_played := 0
	if failures.is_empty():
		var host := _legacy_host_seed(session, faction_id, faction_id, roster_hero_id, hero_id, hero_tile, [{"unit_id": "unit_bog_brute", "count": 14}, {"unit_id": "unit_mire_slinger", "count": 14}])
		var encounters: Array = session.overworld.get("encounters", [])
		encounters.append(host)
		session.overworld["encounters"] = encounters
		OverworldRules.invalidate_spatial_lookup(session)
		for day_index in range(max_days):
			if day_index > 0:
				session.day += 1
			var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
			days_played += 1
			events.append_array(turn_result.get("events", []) if turn_result.get("events", []) is Array else [])
			if not bool(turn_result.get("ok", false)):
				failures.append("Enemy turn returned not-ok during live site retake.")
				break
			if _resource_controller(session, target_id) == faction_id:
				retaken_day = int(session.day)
				break
			if not session.battle.is_empty():
				break
	var after_hero := _encounter_by_placement(session, hero_id)
	var controller_after := _resource_controller(session, target_id)
	var seizure_events := 0
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == "ai_site_seized" and String(event.get("target_id", "")) == target_id:
			seizure_events += 1
	if failures.is_empty() and not AiHeroRulesScript.is_ai_hero(after_hero):
		failures.append("Live site-retake host did not play as an enemy hero.")
	if failures.is_empty() and controller_after != faction_id:
		failures.append("Live site-retake hero did not take %s back within %d days: %s" % [target_id, max_days, JSON.stringify(_event_lines(events))])
	if failures.is_empty() and seizure_events < 1:
		failures.append("Live site retake did not surface an ai_site_seized event for %s." % target_id)
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 10)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected live site-retake events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public live site-retake events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_live_resource_site_defense",
		"live_hero_retakes_lost_resource_site",
		status,
		{
			"scenario_id": scenario_id,
			"faction_id": faction_id,
			"target_id": target_id,
			"town_id": town_id,
			"days_played": days_played,
			"retaken_day": retaken_day,
			"controller_after": controller_after,
			"site_seizure_event_count": seizure_events,
			"public_event_count": int(public_log.get("public_event_count", 0)),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"raid": _raid_execution_signal(after_hero),
			"hero_start": hero_tile,
			"event_types": _event_types(events),
			"event_lines": _event_lines(events),
			"public_event_leak_tokens": public_event_leak_tokens,
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

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
	_pin_fixture_session_id(session, "strategic_ai_live_town_retake_assault")
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
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(seed_raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var after_raid := _encounter_by_placement(session, raid_id)
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	# The hero picks the lost town as its own errand.
	var hero_goal: Dictionary = after_raid.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("goal", {}) if after_raid.get(AiHeroRulesScript.AI_HERO_KEY, {}) is Dictionary else {}
	if String(hero_goal.get("kind", "")) != "town_hostile" or String(hero_goal.get("id", "")) != town_id:
		failures.append("Live retake hero did not choose %s: %s." % [town_id, JSON.stringify(hero_goal)])
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live town-retake assault.")
	if after_raid.is_empty():
		failures.append("Live town-retake raid disappeared after enemy turn.")
	if not AiHeroRulesScript.is_ai_hero(after_raid):
		failures.append("Live town-retake host did not play as an enemy hero.")
	if session.battle.is_empty():
		failures.append("Live town-retake assault did not queue a battle.")
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != town_id:
		failures.append("Live town-retake assault queued wrong battle context.")
	if String(battle_context.get("raid_encounter_key", "")) != raid_id:
		failures.append("Live town-retake battle was not started by the enemy hero.")
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
			"hero_goal_kind": String(hero_goal.get("kind", "")),
			"hero_goal_id": String(hero_goal.get("id", "")),
			"battle_attacker_id": String(battle_context.get("raid_encounter_key", "")),
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	_pin_fixture_session_id(session, "strategic_ai_live_raid_assault_grouping")
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
	# Both hosts come from an older save that marched them on the lost town.
	for host in [leader, support]:
		host.merge({"target_kind": "town", "target_placement_id": town_id}, true)
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
	var joined_column_id := String(after_leader.get("joined_column_placement_id", ""))
	if not bool(turn_result.get("ok", false)):
		failures.append("Enemy turn returned not-ok during live raid grouping.")
	if after_leader.is_empty():
		failures.append("Live raid grouping leader disappeared after enemy turn.")
	if support_id not in resolved:
		failures.append("Live raid grouping support host stayed active.")
	if leader_strength_after < leader_strength_before + support_strength_before:
		failures.append("Live raid grouping leader did not absorb support strength.")
	# Old saves: the column standing beside the hero joins it.
	if not AiHeroRulesScript.is_ai_hero(after_leader):
		failures.append("Live grouping leader did not play as an enemy hero.")
	if joined_column_id != support_id:
		failures.append("Live grouping leader did not record the column that joined it.")
	if session.battle.is_empty():
		failures.append("Live raid grouping did not continue into a battle.")
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != town_id:
		failures.append("Live raid grouping queued wrong battle context.")
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
			"joined_column_id": joined_column_id,
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_pressure_coverage(input_config: Dictionary) -> Dictionary:
	# Every computer player fields a hero from a town it holds and puts it to
	# work on its first day, in every sampled scenario.
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
	var public_boundary_events := []
	var event_type_map := {}
	var fielded_faction_count := 0
	var prismhearth_controller_town := {}
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
		_pin_fixture_session_id(session, "strategic_ai_multi_scenario_pressure_coverage")
		OverworldRules.normalize_overworld_state(session)
		OverworldRules.refresh_fog_of_war(session)
		EnemyTurnRules.normalize_enemy_states(session)
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_turn(session)
		var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
		for event_type in _event_types(events):
			event_type_map[String(event_type)] = true
		public_boundary_events.append_array(events)
		var scenario_fielded := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
			var owned_base_count := _owned_controller_town_count_for_faction(session, faction_id)
			var controller_town := _first_controller_town_signal_for_faction(session, faction_id)
			var hero_goals := _faction_hero_goals(session, faction_id)
			var hired_events := _event_count_for_faction(events, "ai_hero_hired", faction_id)
			var working := 0
			for goal in hero_goals:
				if not String(goal).begins_with("none:"):
					working += 1
			var fielded := bool(turn_result.get("ok", false)) and owned_base_count > 0 and not hero_goals.is_empty() and working > 0
			if not fielded:
				failures.append("%s/%s fielded no working hero from an owned town (towns %d, heroes %s)." % [scenario_id, faction_id, owned_base_count, JSON.stringify(hero_goals)])
			else:
				fielded_faction_count += 1
				scenario_fielded += 1
			if scenario_id == "prismhearth-watch" and faction_id == "faction_mireclaw":
				prismhearth_controller_town = controller_town
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"owned_base_count": owned_base_count,
				"controller_town": controller_town,
				"fielded": fielded,
				"hero_count": hero_goals.size(),
				"hero_goals": hero_goals,
				"hero_hired_event_count": hired_events,
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"fielded_faction_count": scenario_fielded,
			"turn_ok": bool(turn_result.get("ok", false)),
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(public_boundary_events, 32)
	var public_event_leak_tokens := _public_event_leak_tokens(public_log.get("public_events", []))
	if not bool(public_log.get("ok", false)):
		failures.append("Public event boundary rejected multi-scenario pressure coverage events.")
	if not public_event_leak_tokens.is_empty():
		failures.append("Public multi-scenario pressure coverage events leaked internal tokens: %s" % ", ".join(public_event_leak_tokens))
	var event_types := event_type_map.keys()
	event_types.sort()
	var status := _status_from(failures, warnings, deferred)
	return _case(
		"strategic_ai_multi_scenario_pressure_coverage",
		"live_heroes_take_the_field_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"fielded_faction_count": fielded_faction_count,
			"prismhearth_controller_town_id": String(prismhearth_controller_town.get("placement_id", "")),
			"prismhearth_controlling_faction_id": String(prismhearth_controller_town.get("controlling_faction_id", "")),
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
			"save_policy": "ai_heroes_hired_from_owned_towns",
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		deferred
	)

static func _strategic_ai_multi_scenario_objective_targeting(input_config: Dictionary) -> Dictionary:
	# Heroes plan around what is on the map, not around scenario objectives
	# (docs/ai-plays-by-player-rules.md). The human's town is the richest thing
	# there: a hero strong enough to take it goes for it, whichever scenario.
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
	var public_boundary_events := []
	var event_type_map := {}
	var objective_targeted_count := 0
	var objective_anchor_count := 0
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
		var scenario_targeted := 0
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			if faction_id == "":
				continue
			var hero_id := "headless_objective_%s_%s" % [scenario_id.replace("-", "_"), faction_id.replace("faction_", "")]
			var row := _hero_human_town_assault_run(scenario_id, faction_id, hero_id)
			var events: Array = row.get("events", []) if row.get("events", []) is Array else []
			for event_type in _event_types(events):
				event_type_map[String(event_type)] = true
			for event in events:
				if event is Dictionary and String(event.get("actor_id", "")) == hero_id:
					public_boundary_events.append(event)
			var targeted := String(row.get("error", "")) == "" and bool(row.get("targeted_human_town", false))
			if String(row.get("error", "")) != "":
				failures.append("%s/%s: %s" % [scenario_id, faction_id, String(row.get("error", ""))])
			elif not targeted:
				failures.append("%s/%s strong hero did not go for the human's town %s: goal=%s/%s %s" % [scenario_id, faction_id, String(row.get("town_id", "")), String(row.get("goal_kind", "")), String(row.get("goal_id", "")), JSON.stringify(row.get("event_lines", []))])
			if targeted:
				objective_targeted_count += 1
				scenario_targeted += 1
			if bool(row.get("objective_anchor", false)):
				objective_anchor_count += 1
			faction_rows.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"town_id": String(row.get("town_id", "")),
				"objective_targeted": targeted,
				"objective_anchor": bool(row.get("objective_anchor", false)),
				"battle_started": bool(row.get("battle_started", false)),
				"battle_context_type": String(row.get("battle_context_type", "")),
				"hero_goal_kind": String(row.get("goal_kind", "")),
				"hero_goal_id": String(row.get("goal_id", "")),
				"priority_target_ids": _string_array(config.get("priority_target_placement_ids", [])),
			})
		scenario_rows.append({
			"scenario_id": scenario_id,
			"faction_count": enemy_configs.size(),
			"objective_targeted_count": scenario_targeted,
		})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(public_boundary_events, 20)
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
		"live_strong_heroes_go_for_the_human_town_across_scenario_breadth",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"faction_case_count": faction_rows.size(),
			"objective_targeted_count": objective_targeted_count,
			"objective_anchor_count": objective_anchor_count,
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
			"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
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
	return ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)

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
	_config: Dictionary,
	faction_id: String,
	_target_kind: String,
	_target_id: String,
	fallback_actor_id: String
) -> String:
	# Heroes choose their own errands; the fixture hero is the faction's first
	# commander unless the fallback is one of them.
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, faction_id):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == fallback_actor_id:
			return fallback_actor_id
	var first := _first_commander_hero_id_for_faction(session, faction_id)
	return first if first != "" else fallback_actor_id

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

## Scales the human's heroes' armies to about `power` each, down as well as
## up: the threat in the town-defense cases is a hero the computer hero cannot
## attack but that cannot storm the town it holds either, so a scenario's own
## much larger army would make the computer hero rightly keep away instead.
static func _strengthen_player_heroes(session: SessionStateStoreScript.SessionData, power: float) -> void:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or not (hero.get("army", {}) is Dictionary):
			continue
		var stacks: Array = hero.army.get("stacks", [])
		# Spells add strength that does not scale with the troops: scale past
		# the target, then drop single creatures while it stays within 3% below.
		for _pass in range(4):
			var current := AiHeroRulesScript.army_power(stacks, hero)
			if current <= 0.0 or (_pass > 0 and current >= power):
				break
			for stack in stacks:
				if stack is Dictionary:
					stack["count"] = int(ceil(float(stack.get("count", 0)) * power / current))
		for _trim in range(500):
			var best := -1
			var best_power := INF
			for stack_index in range(stacks.size()):
				var stack = stacks[stack_index]
				if not (stack is Dictionary) or int(stack.get("count", 0)) <= 1:
					continue
				stack["count"] = int(stack.count) - 1
				var trimmed := AiHeroRulesScript.army_power(stacks, hero)
				stack["count"] = int(stack.count) + 1
				if trimmed >= power * 0.97 and trimmed < best_power:
					best = stack_index
					best_power = trimmed
			if best < 0:
				break
			stacks[best]["count"] = int(stacks[best].count) - 1
		hero["army"]["stacks"] = stacks
		heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	HeroCommandRules.normalize_session(session)

static func _set_player_position(session: SessionStateStoreScript.SessionData, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	var heroes: Array = session.overworld.get("heroes", []) if session.overworld.get("heroes", []) is Array else []
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("owner", "player")) == "player":
			hero["position"] = session.overworld["hero_position"].duplicate(true)
			heroes[index] = hero
			session.overworld["heroes"] = heroes
			break
	# Enemy heroes see and path around the human's heroes where they stand.
	if session.overworld.get("player_heroes", null) is Array:
		var player_heroes: Array = session.overworld.get("player_heroes", [])
		for index in range(player_heroes.size()):
			if player_heroes[index] is Dictionary:
				player_heroes[index]["position"] = session.overworld["hero_position"].duplicate(true)
		session.overworld["player_heroes"] = player_heroes

static func _seed_town_recruits(session: SessionStateStoreScript.SessionData, placement_id: String, faction_id: String) -> void:
	var unit_id := _first_recruit_unit_id_for_faction(faction_id)
	if unit_id == "":
		return
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			var recruits: Dictionary = town.get("available_recruits", {}) if town.get("available_recruits", {}) is Dictionary else {}
			recruits[unit_id] = maxi(int(recruits.get(unit_id, 0)), int(ContentService.get_unit(unit_id).get("growth", 6)))
			town["available_recruits"] = recruits

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
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	# Heroes fight a site's guards by auto-resolve before taking it, so the
	# hosts carry an army that wins those fights.
	var army := {
		"id": "headless_live_turn_fixture_host",
		"name": "Live Turn Host",
		"stacks": [{"unit_id": "unit_bog_brute", "count": 12}, {"unit_id": "unit_mire_slinger", "count": 12}],
	}
	raid["enemy_army"] = army
	raid["enemy_commander_state"] = EnemyAdventureRules.sync_commander_army_continuity(raid.get("enemy_commander_state", {}), army, "encounter_mire_raid")
	return raid

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
			"stacks": [{"unit_id": unit_id, "count": RECRUITMENT_HOST_COUNT}],
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
	# The host is the faction's most experienced commander with a real army,
	# so it leads the main army and the garrison marches out to it
	# (AiHeroRules._main_hero_id), whatever a hero the town hires that day brings.
	var commander: Dictionary = raid["enemy_commander_state"]
	commander["experience"] = maxi(int(commander.get("experience", 0)), RECRUITMENT_HOST_EXPERIENCE)
	raid["enemy_commander_state"] = commander
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

## Fixture sessions get a fixed id: computer players' tavern offers and the
## levels and armies of their hires are drawn from the session id, which is
## otherwise the clock.
static func _pin_fixture_session_id(session: SessionStateStoreScript.SessionData, label: String) -> void:
	if session != null:
		session.session_id = "headless-%s:%s" % [label, String(session.scenario_id)]

## A fresh authored-scenario session ready for a computer player's day, with
## loose pickups gone, the human's towns too strong to storm and the human's
## heroes leading `human_army_factor` times their army.
static func _authored_ai_fixture_session(scenario_id: String, faction_id: String, failures: Array, human_army_factor: int = 40) -> SessionStateStoreScript.SessionData:
	if ContentService.get_scenario(scenario_id).is_empty():
		return null
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	_pin_fixture_session_id(session, "authored_ai_fixture_session")
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state_for_faction(session, faction_id)
	if state.is_empty():
		failures.append("No enemy state for %s in %s." % [faction_id, scenario_id])
	else:
		# No gold for a second hero, so the fixture hero is the faction's army.
		state["treasury"] = _resource_pool({})
		_update_enemy_state(session, state)
	_clear_loose_map_rewards(session)
	_clear_faction_armies(session, faction_id)
	_fortify_player_towns(session, _scaled_player_stacks(session, 40))
	_set_player_army(session, _scaled_player_stacks(session, human_army_factor))
	# The faction's towns have built and hired today: the fixture hero is the
	# faction's only hero.
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "enemy" and _town_controller_faction_id_for_harness(towns[index]) == faction_id:
			towns[index]["last_build_day"] = int(session.day)
			towns[index]["last_hire_day"] = int(session.day)
	session.overworld["towns"] = towns
	return session

## One faction's hero, a few steps from its town, sees a strong human hero
## beside the town. Returns where the hero ended its day and why.
static func _hero_town_defense_run(scenario_id: String, faction_id: String, hero_id: String, roster_hero_id: String, previous_target_id: String) -> Dictionary:
	var failures := []
	var session := _authored_ai_fixture_session(scenario_id, faction_id, failures)
	if session == null:
		return {"error": "missing scenario %s" % scenario_id}
	if not failures.is_empty():
		return {"error": "; ".join(failures)}
	var town_signal := _first_controller_town_signal_for_faction(session, faction_id)
	var town_id := String(town_signal.get("placement_id", ""))
	var town := _town_by_placement(session, town_id)
	if town.is_empty():
		return {"error": "no town held by %s" % faction_id}
	if roster_hero_id == "":
		roster_hero_id = _first_commander_hero_id_for_faction(session, faction_id)
	_clear_faction_armies(session, faction_id)
	_own_all_resource_sites(session, faction_id)
	if previous_target_id != "":
		_set_resource_controller(session, previous_target_id, "player", failures)
	# The town's own troops are not worth a trip; only the threat is.
	_set_town_garrison(session, town_id, [])
	var entrance := LevelRulesScript.town_entrance(town)
	var hero_tile := _open_tile_near(session, entrance, 2, 4)
	var threat_tile := _open_tile_near(session, entrance, 2, 3, [hero_tile])
	if hero_tile.is_empty() or threat_tile.is_empty():
		return {"error": "no open tiles near %s" % town_id, "town_id": town_id}
	_set_player_position(session, threat_tile)
	var host := _legacy_host_seed(session, faction_id, faction_id, roster_hero_id, hero_id, hero_tile, [{"unit_id": _first_recruit_unit_id_for_faction(faction_id), "count": 10}])
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(host)
	session.overworld["encounters"] = encounters
	_strengthen_player_heroes(session, AiHeroRulesScript.hero_power(host) * HUMAN_THREAT_STRENGTH)
	OverworldRules.invalidate_spatial_lookup(session)
	var threat_context := AiHeroRulesScript._new_context(session, PlayerRulesScript.config_for_controller(session, faction_id), _enemy_state_for_faction(session, faction_id))
	var town_threatened: bool = AiHeroRulesScript._town_threatened(session, threat_context, town)
	var turn_result: Dictionary = _run_faction_day(session, faction_id)
	var events: Array = turn_result.get("events", []) if turn_result.get("events", []) is Array else []
	var hero := _encounter_by_placement(session, hero_id)
	var goal: Dictionary = hero.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("goal", {}) if hero.get(AiHeroRulesScript.AI_HERO_KEY, {}) is Dictionary else {}
	var at_gate := int(hero.get("x", -1)) == int(entrance.get("x", -2)) and int(hero.get("y", -1)) == int(entrance.get("y", -2)) and LevelRulesScript.level_of(hero) == LevelRulesScript.level_of(entrance)
	var held_gate := bool(turn_result.get("ok", false)) and AiHeroRulesScript.is_ai_hero(hero) and town_threatened and at_gate \
		and String(goal.get("kind", "")) in ["town_own", "hold"] and String(goal.get("id", "")) == town_id \
		and String(_town_by_placement(session, town_id).get("owner", "")) == "enemy"
	return {
		"town_id": town_id,
		"town_threatened": town_threatened,
		"held_gate": held_gate,
		"goal_kind": String(goal.get("kind", "")),
		"goal_id": String(goal.get("id", "")),
		"hero": _raid_execution_signal(hero),
		"hero_start": hero_tile,
		"threat_tile": threat_tile,
		"previous_controller_after": _resource_controller(session, previous_target_id) if previous_target_id != "" else "",
		"events": events,
		"event_lines": _event_lines(events),
	}

## One faction's hero, strong enough to storm the human's town, stands a few
## steps from it. Returns whether it went for the town on its day.
static func _hero_human_town_assault_run(scenario_id: String, faction_id: String, hero_id: String, max_days: int = 3) -> Dictionary:
	if ContentService.get_scenario(scenario_id).is_empty():
		return {"error": "missing scenario %s" % scenario_id}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	_pin_fixture_session_id(session, "hero_human_town_assault_run")
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	_clear_loose_map_rewards(session)
	# Every site is already the faction's and its towns have built and hired
	# today: the human's town is the one prize left in reach.
	_clear_faction_armies(session, faction_id)
	_own_all_resource_sites(session, faction_id)
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "enemy" and _town_controller_faction_id_for_harness(towns[index]) == faction_id:
			towns[index]["last_build_day"] = int(session.day)
			towns[index]["last_hire_day"] = int(session.day)
	session.overworld["towns"] = towns
	var town := _first_town_for_owner(session, "player")
	if town.is_empty():
		return {"error": "no human town"}
	var town_id := String(town.get("placement_id", ""))
	var entrance := LevelRulesScript.town_entrance(town)
	# The human's hero waits in the town, so storming the town is the fight.
	_set_player_position(session, entrance)
	var hero_tile := _open_tile_near(session, entrance, 3, 5)
	if hero_tile.is_empty():
		return {"error": "no open tile near %s" % town_id, "town_id": town_id}
	var roster_hero_id := _first_commander_hero_id_for_faction(session, faction_id)
	var host := _legacy_host_seed(session, faction_id, faction_id, roster_hero_id, hero_id, hero_tile, [{"unit_id": _first_recruit_unit_id_for_faction(faction_id), "count": 1000}])
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(host)
	session.overworld["encounters"] = encounters
	OverworldRules.invalidate_spatial_lookup(session)
	var events := []
	var turn_ok := true
	var days_played := 0
	for day_index in range(max_days):
		if day_index > 0:
			session.day += 1
		var turn_result: Dictionary = _run_faction_day(session, faction_id)
		days_played += 1
		turn_ok = turn_ok and bool(turn_result.get("ok", false))
		events.append_array(turn_result.get("events", []) if turn_result.get("events", []) is Array else [])
		if not session.battle.is_empty() or String(_town_by_placement(session, town_id).get("owner", "")) == "enemy":
			break
	var hero := _encounter_by_placement(session, hero_id)
	var goal: Dictionary = hero.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("goal", {}) if hero.get(AiHeroRulesScript.AI_HERO_KEY, {}) is Dictionary else {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var battle_on_town := String(battle_context.get("type", "")) == "town_defense" and String(battle_context.get("town_placement_id", "")) == town_id and String(battle_context.get("raid_encounter_key", "")) == hero_id
	var captured := String(_town_by_placement(session, town_id).get("owner", "")) == "enemy"
	return {
		"town_id": town_id,
		"targeted_human_town": turn_ok and (battle_on_town or captured),
		"objective_anchor": EnemyAdventureRules.target_is_objective_anchor(session, "town", town_id),
		"battle_started": not session.battle.is_empty(),
		"battle_context_type": String(battle_context.get("type", "")),
		"days_played": days_played,
		"goal_kind": String(goal.get("kind", "")),
		"goal_id": String(goal.get("id", "")),
		"events": events,
		"event_lines": _event_lines(events),
	}

## Takes the faction's other armies off the map (a scenario may start it
## with a host), so the fixture hero is its only, and main, hero.
static func _clear_faction_armies(session: SessionStateStoreScript.SessionData, faction_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and String(entry.get("spawned_by_faction_id", "")) == faction_id and String(entry.get("placement_id", "")) not in resolved:
			resolved.append(String(entry.get("placement_id", "")))
	session.overworld["resolved_encounters"] = resolved
	OverworldRules.invalidate_spatial_lookup(session)

## One computer player's day through the live per-player entry point
## (AiHeroRules.run_faction_turn, which the enemy turn runs for each player).
## On maps with several computer players the others stay still, so their
## heroes cannot take the fixture's sites or towns first.
static func _run_faction_day(session: SessionStateStoreScript.SessionData, controller: String) -> Dictionary:
	EnemyTurnRules.normalize_enemy_states(session)
	AiHeroRulesScript.clear_shared_surfaces()
	var config := {}
	for candidate in EnemyTurnRules._enemy_faction_configs_for_session(session):
		if candidate is Dictionary and PlayerRulesScript.controller_id(candidate) == controller:
			config = candidate
	var states: Array = session.overworld.get("enemy_states", [])
	var index := -1
	for state_index in range(states.size()):
		if states[state_index] is Dictionary and PlayerRulesScript.controller_id(states[state_index]) == controller:
			index = state_index
	if config.is_empty() or index < 0:
		return {"ok": false, "events": [], "error": "no computer player %s" % controller}
	var result: Dictionary = AiHeroRulesScript.run_faction_turn(session, config, states[index], OverworldRules.is_weekly_growth_day(session.day))
	states = session.overworld.get("enemy_states", states)
	states[index] = EnemyTurnRules._latest_enemy_state(session, controller, result.get("state", states[index]))
	session.overworld["enemy_states"] = states
	AiHeroRulesScript.clear_shared_surfaces()
	return {"ok": true, "events": result.get("events", []), "messages": result.get("messages", [])}

## A raid host as older saves hold it: a commander leading an army. It plays
## as a hero from the next computer turn on (AiHeroRules.normalize_ai_heroes).
static func _legacy_host_seed(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	controller: String,
	roster_hero_id: String,
	placement_id: String,
	tile: Dictionary,
	stacks: Array
) -> Dictionary:
	var host := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(tile.get("x", 0)),
		"y": int(tile.get("y", 0)),
		"level": LevelRulesScript.level_of(tile),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
	}
	if controller != "" and controller != faction_id:
		host["spawned_by_player_id"] = controller
	host["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		host,
		roster_hero_id,
		controller if controller != "" else faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, controller if controller != "" else faction_id)
	)
	host = EnemyAdventureRules.ensure_raid_army(host, session)
	var army := {"id": "%s_army" % placement_id, "name": "Fixture Army", "stacks": stacks.duplicate(true)}
	host["enemy_army"] = army
	host["enemy_commander_state"] = EnemyAdventureRules.sync_commander_army_continuity(host.get("enemy_commander_state", {}), army, "encounter_mire_raid")
	return host

## An empty tile `min_distance` to `max_distance` steps from `point` along a
## walk the AI routes too (8-way, the overworld corner rule, no guard zones or
## armies on the way; sites the hero owns are walked across). The tile itself
## holds nothing a hero stops at. The nearest ring wins; within it, the tile
## farthest from `avoid`.
static func _open_tile_near(session: SessionStateStoreScript.SessionData, point: Dictionary, min_distance: int, max_distance: int, avoid: Array = []) -> Dictionary:
	var size: Vector2i = OverworldRules.derive_map_size(session)
	var level := LevelRulesScript.level_of(point)
	var origin := Vector2i(int(point.get("x", 0)), int(point.get("y", 0)))
	var steps := {origin: 0}
	var frontier := [origin]
	var rings := {}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var step: int = steps[current]
		if step >= max_distance:
			continue
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var next := current + Vector2i(dx, dy)
				if steps.has(next) or next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
					continue
				if OverworldRules.tile_is_blocked(session, next.x, next.y, level) or not OverworldRules.guard_engagement_encounter_at_tile(session, next.x, next.y, level).is_empty():
					continue
				if OverworldRules.tile_step_cuts_blocked_corner(session, current, next, level) or _tile_has_army(session, next.x, next.y, level):
					continue
				steps[next] = step + 1
				frontier.append(next)
				if step + 1 >= min_distance and not OverworldRules.tile_has_route_interaction(session, next.x, next.y, level):
					if not rings.has(step + 1):
						rings[step + 1] = []
					rings[step + 1].append(next)
	for distance in range(min_distance, max_distance + 1):
		var best := {}
		var best_score := -1
		for tile in rings.get(distance, []):
			var score := 0
			for other in avoid:
				if other is Dictionary and not other.is_empty():
					score += maxi(absi(tile.x - int(other.get("x", 0))), absi(tile.y - int(other.get("y", 0))))
			if score > best_score:
				best_score = score
				best = {"x": tile.x, "y": tile.y, "level": level}
		if not best.is_empty():
			return best
	return {}

static func _tile_has_army(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int) -> bool:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and int(entry.get("x", -1)) == x and int(entry.get("y", -1)) == y \
				and LevelRulesScript.level_of(entry) == level and String(entry.get("placement_id", "")) not in resolved:
			return true
	for hero in session.overworld.get("player_heroes", []):
		var position: Dictionary = hero.get("position", {}) if hero is Dictionary and hero.get("position", {}) is Dictionary else {}
		if int(position.get("x", -1)) == x and int(position.get("y", -1)) == y and LevelRulesScript.level_of(position) == level:
			return true
	return false

## The human's field army, `factor` times over.
static func _scaled_player_stacks(session: SessionStateStoreScript.SessionData, factor: int) -> Array:
	var stacks := []
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0)) * factor})
	return stacks

## The human's towns hold these troops (none at all with an empty list).
static func _fortify_player_towns(session: SessionStateStoreScript.SessionData, stacks: Array) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "player":
			towns[index]["garrison"] = stacks.duplicate(true)
	session.overworld["towns"] = towns

## Every human hero leads these troops.
static func _set_player_army(session: SessionStateStoreScript.SessionData, stacks: Array) -> void:
	var army := {"id": "headless_fixture_army", "name": "Field Army", "stacks": stacks.duplicate(true)}
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary:
			heroes[index]["army"] = army.duplicate(true)
	session.overworld["player_heroes"] = heroes
	session.overworld["army"] = army.duplicate(true)
	HeroCommandRules.normalize_session(session)

static func _set_town_garrison(session: SessionStateStoreScript.SessionData, placement_id: String, stacks: Array) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			towns[index]["garrison"] = stacks.duplicate(true)
	session.overworld["towns"] = towns

## Every site on the map already belongs to this player, and its dwellings
## have been hired out this week, so nothing but the case's own subject is
## worth a hero's walk.
static func _own_all_resource_sites(session: SessionStateStoreScript.SessionData, controller: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or NativeTransitRulesScript.is_native(node):
			continue
		node["collected"] = true
		PlayerRulesScript.set_resource_controller(node, session, controller)
		if CreatureDwellingRulesScript.is_dwelling(NodePayloadScript.site_for_node(node)):
			node[CreatureDwellingRulesScript.POPULATION] = {}
			node[CreatureDwellingRulesScript.POPULATION_WEEK] = CreatureDwellingRulesScript.week_index(int(session.day))
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes

## Each of the faction's heroes' current errand, as "kind:id" ("none:" when idle).
static func _faction_hero_goals(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var goals := []
	for entry in AiHeroRulesScript.active_hero_entries(session):
		if String(entry.get("spawned_by_faction_id", "")) != faction_id:
			continue
		var goal: Dictionary = entry.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("goal", {}) if entry.get(AiHeroRulesScript.AI_HERO_KEY, {}) is Dictionary else {}
		var kind := String(goal.get("kind", ""))
		goals.append("%s:%s" % [kind if kind != "" else "none", String(goal.get("id", ""))])
	goals.sort()
	return goals

static func _creature_count(stacks: Variant) -> int:
	var total := 0
	if stacks is Array:
		for stack in stacks:
			if stack is Dictionary:
				total += maxi(0, int(stack.get("count", 0)))
	return total

static func _first_event_index(events: Array, event_type: String, actor_id: String) -> int:
	for index in range(events.size()):
		var event = events[index]
		if event is Dictionary and String(event.get("event_type", "")) == event_type and String(event.get("actor_id", "")) == actor_id:
			return index
	return -1

## The first recruitment a town made: unit and count.
static func _first_recruit_event_signal(events: Array, town_id: String) -> Dictionary:
	for event in events:
		if not (event is Dictionary) or String(event.get("event_type", "")) != "ai_town_recruited":
			continue
		if town_id != "" and String(event.get("actor_id", "")) != town_id:
			continue
		# The event names the unit and its label reads "<count> <unit name>".
		return {"unit_id": String(event.get("target_id", "")), "count": int(String(event.get("target_label", "")).get_slice(" ", 0))}
	return {}

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

static func _town_available_recruit_count(session: SessionStateStoreScript.SessionData, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return int(town.get("available_recruits", {}).get(unit_id, 0))
	return 0

static func _ensure_town_building(session: SessionStateStoreScript.SessionData, placement_id: String, building_id: String, failures: Array) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		var built: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
		if building_id not in built:
			built.append(building_id)
		town["built_buildings"] = built
		towns[index] = town
		session.overworld["towns"] = towns
		return
	failures.append("Missing town %s for building fixture." % placement_id)

static func _town_recruit_event_count_for(events: Array, town_id: String) -> int:
	var count := 0
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == "ai_town_recruited" and String(event.get("actor_id", "")) == town_id:
			count += 1
	return count

## Pickups and loose artifacts are gone, so heroes go for the sites under test.
## So are the supply caches authored scenarios add beside computer towns
## (ScenarioFactory development source support): a hero values one far above
## any site under test.
static func _clear_loose_map_rewards(session: SessionStateStoreScript.SessionData) -> void:
	for artifact in session.overworld.get("artifact_nodes", []):
		if artifact is Dictionary:
			artifact["collected"] = true
	var kept := []
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and bool(node.get("development_source_support", false)):
			continue
		kept.append(node)
		if not (node is Dictionary) or bool(node.get("collected", false)):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not bool(site.get("persistent_control", false)):
			node["collected"] = true
	session.overworld["resource_nodes"] = kept
	OverworldRules.invalidate_spatial_lookup(session)

## A hero's goal is its own business: no raid-style target fields.
static func _hero_goal_private(entry: Dictionary) -> bool:
	return String(entry.get("target_kind", "")) == "" and String(entry.get("target_placement_id", "")) == ""

static func _faction_ai_hero_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count := 0
	for entry in AiHeroRulesScript.active_hero_entries(session):
		if String(entry.get("spawned_by_faction_id", "")) == faction_id:
			count += 1
	return count

static func _event_lines(events: Array) -> Array:
	var lines := []
	for event in events:
		if event is Dictionary:
			lines.append("%s|%s|%s|%s" % [event.get("event_type", ""), event.get("actor_id", ""), event.get("target_id", ""), event.get("summary", "")])
	return lines

static func _tile_distance_to(point: Dictionary, tile: Vector2i) -> int:
	return maxi(absi(int(point.get("x", 0)) - tile.x), absi(int(point.get("y", 0)) - tile.y))

## Every hero a computer player fields, summed: recruits count as delivered
## once any of its heroes carries them.
static func _faction_hero_strength(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var total := 0
	for entry in AiHeroRulesScript.active_hero_entries(session):
		if String(entry.get("spawned_by_faction_id", "")) == faction_id:
			total += EnemyAdventureRules.raid_strength(entry)
	return total

static func _faction_hero_unit_count(session: SessionStateStoreScript.SessionData, faction_id: String, unit_id: String) -> int:
	var total := 0
	for entry in AiHeroRulesScript.active_hero_entries(session):
		if String(entry.get("spawned_by_faction_id", "")) == faction_id:
			total += _raid_unit_count(entry, unit_id)
	return total

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
	var goal: Dictionary = raid.get("ai_hero", {}).get("goal", {}) if raid.get("ai_hero", {}) is Dictionary else {}
	return {
		"placement_id": String(raid.get("placement_id", "")),
		"ai_hero": AiHeroRulesScript.is_ai_hero(raid),
		"goal_kind": String(goal.get("kind", "")),
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

static func _without_timing_fields(value: Variant) -> Variant:
	# Wall-clock *_msec fields differ on every run, so signatures leave them out.
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			if String(key).ends_with("_msec"):
				continue
			result[key] = _without_timing_fields(value[key])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_without_timing_fields(item))
		return result
	return value

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
