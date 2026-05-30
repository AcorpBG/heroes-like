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
	if int(rmg_summary.get("measurement_gap_count", 0)) <= 0:
		_fail("Strategic AI baseline must record generated-map turn probe coverage gaps in the fast audit: %s" % JSON.stringify(rmg_summary))
		return false
	if int(rmg_summary.get("medium_probe_count", 0)) < 1:
		_fail("Strategic AI baseline did not record a Medium generated-map generalization probe: %s" % JSON.stringify(rmg_summary))
		return false
	var blocker_rows: Array = report.get("blocker_rows", []) if report.get("blocker_rows", []) is Array else []
	if blocker_rows.is_empty():
		_fail("Strategic AI baseline must identify production blockers.")
		return false
	if not _blocker_row(blocker_rows, "no_persistent_full_hero_task_board").is_empty():
		_fail("Strategic AI baseline should not keep the persistent hero task-board blocker after coordinated task planning landed.")
		return false
	if _blocker_row(blocker_rows, "no_long_run_seed_matrix").is_empty():
		_fail("Strategic AI baseline missed the long-run seed matrix production gap.")
		return false
	if _blocker_row(blocker_rows, "native_rmg_small_ai_turn_probe_coverage").is_empty() and _blocker_row(blocker_rows, "native_rmg_small_ai_turn_health").is_empty():
		_fail("Strategic AI baseline missed generated-map AI turn-health coverage.")
		return false
	var recommendations: Array = report.get("recommended_next_slices", []) if report.get("recommended_next_slices", []) is Array else []
	if "strategic-ai-long-run-seed-matrix-10184" not in recommendations:
		_fail("Strategic AI baseline did not recommend the long-run seed-matrix slice: %s" % JSON.stringify(recommendations))
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

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
