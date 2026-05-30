extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "STRATEGIC_AI_LONG_RUN_SEED_MATRIX_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = HeadlessSimulationHarnessRulesScript.build_strategic_ai_long_run_seed_matrix_report({
		"seed_count": 1,
		"turn_count": 1,
		"battle_step_limit": 96,
		"pressure_floor": 999,
		"seed_prefix": "strategic-ai-long-run-smoke-native-small",
	})
	if not _assert_report(report):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if String(report.get("schema_id", "")) != HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_SEED_MATRIX_SCHEMA_ID:
		_fail("Long-run matrix schema mismatch: %s" % JSON.stringify(report))
		return false
	if String(report.get("report_id", "")) != REPORT_ID:
		_fail("Long-run matrix report id mismatch: %s" % JSON.stringify(report))
		return false
	if bool(report.get("production_ready", true)):
		_fail("Long-run matrix must not claim strategic AI production readiness.")
		return false
	var policy: Dictionary = report.get("policy", {}) if report.get("policy", {}) is Dictionary else {}
	if not bool(policy.get("native_rmg_generated_maps_only", false)):
		_fail("Long-run matrix must use Native RMG generated maps only: %s" % JSON.stringify(policy))
		return false
	if bool(policy.get("authored_scenario_balance_surface", true)):
		_fail("Long-run matrix must not use authored scenarios as the balance surface: %s" % JSON.stringify(policy))
		return false
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	if int(summary.get("row_count", 0)) != 1:
		_fail("Long-run matrix smoke row count mismatch: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("setup_ok_count", 0)) != 1:
		_fail("Long-run matrix must start every Native RMG smoke seed: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("turns_completed", 0)) <= 0:
		_fail("Long-run matrix completed no turns: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("enemy_activity_event_count", 0)) <= 0:
		_fail("Long-run matrix observed no enemy activity: %s" % JSON.stringify(summary))
		return false
	var rows: Array = report.get("rows", []) if report.get("rows", []) is Array else []
	if rows.size() != 1:
		_fail("Long-run matrix rows were not emitted.")
		return false
	for row in rows:
		if not (row is Dictionary):
			_fail("Long-run matrix row is not a dictionary.")
			return false
		if String(row.get("startup_source", "")) != "native_rmg_disk_package":
			_fail("Long-run matrix row did not use native disk package startup: %s" % JSON.stringify(row))
			return false
		if String(row.get("size_class_id", "")) != "homm3_small":
			_fail("Long-run matrix smoke must stay in strict Small scope: %s" % JSON.stringify(row))
			return false
		if String(row.get("signature", "")) == "":
			_fail("Long-run matrix row missing signature: %s" % JSON.stringify(row))
			return false
	var blockers: Array = report.get("blocker_rows", []) if report.get("blocker_rows", []) is Array else []
	if _blocker_row(blockers, "strategic_ai_long_run_full_100_seed_8_week_matrix_not_run").is_empty():
		_fail("Focused smoke must preserve the full 100-seed eight-week remaining-validation blocker: %s" % JSON.stringify(blockers))
		return false
	var target_planning_count := int(summary.get("target_assignment_count", 0)) \
		+ int(summary.get("commander_task_planned_count", 0)) \
		+ int(summary.get("task_board_open_count", 0)) \
		+ int(summary.get("task_board_active_count", 0))
	if target_planning_count <= 0 \
			and _blocker_row(blockers, "strategic_ai_long_run_no_target_assignment").is_empty():
		_fail("Focused smoke must report a target-planning production gap when no assignment or planned commander task occurs: %s" % JSON.stringify(report))
		return false
	if String(report.get("signature", "")) == "":
		_fail("Long-run matrix report signature is missing.")
		return false
	return true

func _blocker_row(rows: Array, blocker_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("blocker_id", "")) == blocker_id:
			return row
	return {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
