extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "STRATEGIC_AI_BASELINE_KPI_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = HeadlessSimulationHarnessRulesScript.build_strategic_ai_baseline_kpi_report()
	if not _assert_report(report):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if not bool(report.get("ok", false)):
		_fail("Strategic AI baseline KPI report did not build cleanly: %s" % JSON.stringify(report))
		return false
	if String(report.get("schema_id", "")) != HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_BASELINE_KPI_SCHEMA_ID:
		_fail("Strategic AI baseline KPI schema mismatch: %s" % JSON.stringify(report))
		return false
	if String(report.get("report_id", "")) != REPORT_ID:
		_fail("Strategic AI baseline KPI report id mismatch: %s" % JSON.stringify(report))
		return false
	if bool(report.get("production_ready", true)):
		_fail("Baseline audit must not claim strategic AI production readiness.")
		return false
	var subsystem_summary: Dictionary = report.get("subsystem_summary", {}) if report.get("subsystem_summary", {}) is Dictionary else {}
	if int(subsystem_summary.get("covered_subsystem_count", 0)) < HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_BASELINE_SUBSYSTEM_IDS.size():
		_fail("Strategic AI baseline did not cover every existing strategic subsystem: %s" % JSON.stringify(subsystem_summary))
		return false
	if int(subsystem_summary.get("pass_count", 0)) <= 0:
		_fail("Strategic AI baseline did not observe passing subsystem evidence: %s" % JSON.stringify(subsystem_summary))
		return false
	if int(subsystem_summary.get("broad_multi_scenario_case_count", 0)) <= 0:
		_fail("Strategic AI baseline did not include broad multi-scenario evidence: %s" % JSON.stringify(subsystem_summary))
		return false
	var event_counts: Dictionary = subsystem_summary.get("event_counts", {}) if subsystem_summary.get("event_counts", {}) is Dictionary else {}
	for required_key in ["target_assignment", "town_recruit", "raid_reinforcement"]:
		if int(event_counts.get(required_key, 0)) <= 0:
			_fail("Strategic AI baseline missed required event KPI %s: %s" % [required_key, JSON.stringify(event_counts)])
			return false
	var capability_rows: Array = report.get("capability_rows", []) if report.get("capability_rows", []) is Array else []
	if capability_rows.size() < 4:
		_fail("Strategic AI baseline capability rows are too narrow: %s" % JSON.stringify(capability_rows))
		return false
	for capability_id in ["town_economy", "hero_tasking_and_routes", "defense_regroup_and_assault", "objective_pressure"]:
		if _capability_row(capability_rows, capability_id).is_empty():
			_fail("Strategic AI baseline missed capability row %s." % capability_id)
			return false
	var rmg_summary: Dictionary = report.get("rmg_summary", {}) if report.get("rmg_summary", {}) is Dictionary else {}
	if int(rmg_summary.get("supported_small_count", 0)) < 2:
		_fail("Strategic AI baseline did not probe enough supported Small generated maps: %s" % JSON.stringify(rmg_summary))
		return false
	if int(rmg_summary.get("supported_small_ok_count", 0)) < int(rmg_summary.get("supported_small_count", 0)):
		_fail("Supported Small generated-map AI turn probes must execute and pass by default: %s" % JSON.stringify(rmg_summary))
		return false
	if int(rmg_summary.get("target_assignment_event_count", 0)) <= 0:
		_fail("Supported generated-map AI turns did not expose target-assignment threat events: %s" % JSON.stringify(rmg_summary))
		return false
	if int(rmg_summary.get("medium_probe_count", 0)) < 3:
		_fail("Strategic AI baseline did not record enough Medium generated-map generalization probes: %s" % JSON.stringify(rmg_summary))
		return false
	if int(rmg_summary.get("medium_ok_count", 0)) < int(rmg_summary.get("medium_probe_count", 0)):
		_fail("Strategic AI baseline must execute every Medium generated-map probe after the runtime unblock: %s" % JSON.stringify(rmg_summary))
		return false
	var rmg_cases: Array = report.get("rmg_cases", []) if report.get("rmg_cases", []) is Array else []
	for medium_case_id in [
		"native_rmg_medium_seed_314159_ai_turn_probe",
		"native_rmg_medium_seed_271828_ai_turn_probe",
		"native_rmg_medium_seed_161803_ai_turn_probe",
	]:
		var medium_row := _rmg_case_row(rmg_cases, medium_case_id)
		if medium_row.is_empty():
			_fail("Strategic AI baseline did not emit Medium generated-map probe row %s." % medium_case_id)
			return false
		if not bool(medium_row.get("setup_ok", false)) or not bool(medium_row.get("ok", false)):
			_fail("Medium generated-map probe should now pass setup and execute strategic AI turns: %s" % JSON.stringify(medium_row))
			return false
	var long_run_summary: Dictionary = report.get("long_run_summary", {}) if report.get("long_run_summary", {}) is Dictionary else {}
	if not bool(long_run_summary.get("ok", false)):
		_fail("Strategic AI baseline did not consume completed staged long-run evidence: %s" % JSON.stringify(long_run_summary))
		return false
	if int(long_run_summary.get("strict_covered_seed_count", 0)) < 100:
		_fail("Strategic AI baseline long-run evidence is missing strict seed coverage: %s" % JSON.stringify(long_run_summary))
		return false
	if not bool(long_run_summary.get("residual_diagnostics_retired", false)):
		_fail("Strategic AI baseline long-run evidence did not retire residual diagnostics: %s" % JSON.stringify(long_run_summary))
		return false
	var medium_long_run_summary: Dictionary = report.get("medium_long_run_summary", {}) if report.get("medium_long_run_summary", {}) is Dictionary else {}
	if not bool(medium_long_run_summary.get("ok", false)):
		_fail("Strategic AI baseline did not consume the exact completed Medium long-run matrix evidence: %s" % JSON.stringify(medium_long_run_summary))
		return false
	if String(medium_long_run_summary.get("slice_id", "")) != HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_MEDIUM_LONG_RUN_SLICE_ID \
			or String(medium_long_run_summary.get("slice_status", "")) != "completed" \
			or int(medium_long_run_summary.get("matched_slice_count", 0)) != 1 \
			or int(medium_long_run_summary.get("evidence_marker_count", 0)) != 1:
		_fail("Medium long-run adoption must come from one exact completed tracker slice: %s" % JSON.stringify(medium_long_run_summary))
		return false
	if String(medium_long_run_summary.get("evidence_source_head", "")) != "1fc6775baaa6d9a016cd8d14fc898ed38847af9a" \
			or String(medium_long_run_summary.get("evidence_aggregate_sha256", "")) != "7e99c85386c3c5ba68bcfeecc08a8899bef102e22cf151a1f5154e6b3c3ffdda" \
			or String(medium_long_run_summary.get("evidence_aggregate_signature", "")) != "8bb77e6c":
		_fail("Medium long-run adoption evidence provenance is not exact: %s" % JSON.stringify(medium_long_run_summary))
		return false
	for expected_pair in [
		["seed_ordinal_start", 1],
		["seed_ordinal_end", 100],
		["seed_count", 100],
		["turn_target", 56],
		["setup_ok_count", 100],
		["row_ok_count", 100],
		["turns_completed", 3770],
		["defeat_count", 73],
		["in_progress_count", 27],
		["enemy_activity_event_count", 13086],
		["target_assignment_count", 3774],
		["commander_task_planned_count", 240],
		["stalled_turn_count", 179],
		["battle_interrupt_count", 236],
		["battle_autoresolve_count", 236],
	]:
		if int(medium_long_run_summary.get(String(expected_pair[0]), -1)) != int(expected_pair[1]):
			_fail("Medium long-run adoption aggregate mismatch for %s: %s" % [String(expected_pair[0]), JSON.stringify(medium_long_run_summary)])
			return false
	for zero_key in [
		"behavior_bug_count",
		"target_integrity_violation_count",
		"unreachable_active_target_turn_count",
		"unreachable_active_target_total",
		"no_active_pressure_count",
	]:
		if int(medium_long_run_summary.get(zero_key, -1)) != 0:
			_fail("Medium long-run adoption retained failure count %s: %s" % [zero_key, JSON.stringify(medium_long_run_summary)])
			return false
	var medium_blocker_ids: Array = medium_long_run_summary.get("blocker_ids", []) if medium_long_run_summary.get("blocker_ids", []) is Array else ["invalid"]
	if not medium_blocker_ids.is_empty():
		_fail("Medium long-run adoption retained production blocker ids: %s" % JSON.stringify(medium_long_run_summary))
		return false
	var missing_medium_adoption: Dictionary = HeadlessSimulationHarnessRulesScript._strategic_ai_medium_long_run_adoption_summary({
		"progress_path": "res://tests/fixtures/strategic_ai_missing_progress_tracker.json",
	})
	if bool(missing_medium_adoption.get("ok", true)) or String(missing_medium_adoption.get("reason", "")) != "progress_tracker_missing_or_invalid":
		_fail("Medium long-run adoption must fail closed without its tracker authority: %s" % JSON.stringify(missing_medium_adoption))
		return false
	var blocker_rows: Array = report.get("blocker_rows", []) if report.get("blocker_rows", []) is Array else []
	if blocker_rows.is_empty():
		_fail("Strategic AI baseline must identify production blockers.")
		return false
	if not _blocker_row(blocker_rows, "no_persistent_full_hero_task_board").is_empty():
		_fail("Strategic AI baseline should not keep the persistent hero task-board blocker after coordinated task planning landed.")
		return false
	if not _blocker_row(blocker_rows, "no_long_run_seed_matrix").is_empty():
		_fail("Strategic AI baseline should retire the long-run seed matrix gap after staged evidence adoption: %s" % JSON.stringify(blocker_rows))
		return false
	if not _blocker_row(blocker_rows, "native_rmg_medium_ai_generalization").is_empty():
		_fail("Strategic AI baseline should retire the short Medium generated-map generalization blocker after three passing probes: %s" % JSON.stringify(blocker_rows))
		return false
	if not _blocker_row(blocker_rows, "native_rmg_medium_long_run_matrix").is_empty():
		_fail("Strategic AI baseline should retire the completed Medium generated-map matrix blocker: %s" % JSON.stringify(blocker_rows))
		return false
	var medium_topology_blocker := _blocker_row(blocker_rows, "native_rmg_medium_topology_contact_pacing")
	if medium_topology_blocker.is_empty():
		_fail("Strategic AI baseline must retain the observed Medium topology/contact/pacing production gap: %s" % JSON.stringify(blocker_rows))
		return false
	var topology_evidence_ordinals: Array = medium_topology_blocker.get("evidence_seed_ordinals", []) if medium_topology_blocker.get("evidence_seed_ordinals", []) is Array else []
	if topology_evidence_ordinals != [95, 98] \
			or String(medium_topology_blocker.get("blocked_by", "")) != "native_rmg_topology_object_placement_source_parity" \
			or not bool(medium_topology_blocker.get("source_recovery_required", false)):
		_fail("Medium topology/contact/pacing blocker must remain tied to exact rows and source recovery: %s" % JSON.stringify(medium_topology_blocker))
		return false
	if not _blocker_row(blocker_rows, "native_rmg_small_ai_turn_probe_coverage").is_empty() or not _blocker_row(blocker_rows, "native_rmg_small_ai_turn_health").is_empty():
		_fail("Supported Small generated-map AI turn health should be executed and green before this baseline passes: %s" % JSON.stringify(blocker_rows))
		return false
	var recommendations: Array = report.get("recommended_next_slices", []) if report.get("recommended_next_slices", []) is Array else []
	if "strategic-ai-long-run-seed-matrix-10184" in recommendations:
		_fail("Strategic AI baseline should not recommend the completed long-run seed-matrix slice: %s" % JSON.stringify(recommendations))
		return false
	if "native-rmg-medium-runtime-generation-unblock-10184" in recommendations:
		_fail("Strategic AI baseline should not recommend the completed Medium RMG runtime-generation unblock slice after setup succeeds: %s" % JSON.stringify(recommendations))
		return false
	if "strategic-ai-rmg-medium-generalization-probe-10184" in recommendations:
		_fail("Strategic AI baseline should not recommend the completed short Medium generated-map AI generalization slice: %s" % JSON.stringify(recommendations))
		return false
	if "strategic-ai-medium-long-run-seed-matrix-10184" in recommendations:
		_fail("Strategic AI baseline should not recommend the completed Medium generated-map long-run matrix slice: %s" % JSON.stringify(recommendations))
		return false
	if not recommendations.is_empty():
		_fail("Strategic AI baseline must not invent an implementation slice for the source-recovery-owned topology gap: %s" % JSON.stringify(recommendations))
		return false
	var audit_policy: Dictionary = report.get("audit_policy", {}) if report.get("audit_policy", {}) is Dictionary else {}
	for forbidden_true in ["manual_play_replacement", "automatic_tuning", "runtime_balance_changes", "authored_content_writeback", "campaign_adoption", "production_ready_claim"]:
		if bool(audit_policy.get(forbidden_true, true)):
			_fail("Strategic AI baseline policy incorrectly enabled %s: %s" % [forbidden_true, JSON.stringify(audit_policy)])
			return false
	if String(report.get("signature", "")) == "":
		_fail("Strategic AI baseline signature is missing.")
		return false
	return true

func _capability_row(rows: Array, capability_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("capability_id", "")) == capability_id:
			return row
	return {}

func _blocker_row(rows: Array, blocker_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("blocker_id", "")) == blocker_id:
			return row
	return {}

func _rmg_case_row(rows: Array, case_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("case_id", "")) == case_id:
			return row
	return {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
