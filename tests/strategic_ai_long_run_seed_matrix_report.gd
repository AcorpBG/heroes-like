extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "STRATEGIC_AI_LONG_RUN_SEED_MATRIX_REPORT"
const DEFAULT_SEED_COUNT := 1
const DEFAULT_TURN_COUNT := 1
const DEFAULT_BATTLE_STEP_LIMIT := 96
const DEFAULT_PRESSURE_FLOOR := 999
const DEFAULT_SEED_OFFSET := 0
const DEFAULT_SEED_PREFIX := "strategic-ai-long-run-smoke-native-small"
const DEFAULT_REQUIRED_EVENT_TYPE := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := _config_from_environment()
	var report: Dictionary = HeadlessSimulationHarnessRulesScript.build_strategic_ai_long_run_seed_matrix_report(config)
	if not _assert_report(report, int(config.get("seed_count", DEFAULT_SEED_COUNT)), int(config.get("turn_count", DEFAULT_TURN_COUNT)), String(config.get("required_event_type", ""))):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _config_from_environment() -> Dictionary:
	var config := {
		"seed_count": _env_int("HEROES_STRATEGIC_AI_LONG_RUN_SEEDS", DEFAULT_SEED_COUNT, 1, HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET),
		"turn_count": _env_int("HEROES_STRATEGIC_AI_LONG_RUN_TURNS", DEFAULT_TURN_COUNT, 1, HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET),
		"battle_step_limit": _env_int("HEROES_STRATEGIC_AI_LONG_RUN_BATTLE_STEP_LIMIT", DEFAULT_BATTLE_STEP_LIMIT, 1, 2048),
		"pressure_floor": _env_int("HEROES_STRATEGIC_AI_LONG_RUN_PRESSURE_FLOOR", DEFAULT_PRESSURE_FLOOR, 0, 9999),
		"seed_offset": _env_int("HEROES_STRATEGIC_AI_LONG_RUN_SEED_OFFSET", DEFAULT_SEED_OFFSET, 0, HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET - 1),
		"seed_prefix": _env_string("HEROES_STRATEGIC_AI_LONG_RUN_SEED_PREFIX", DEFAULT_SEED_PREFIX),
		"required_event_type": _env_string("HEROES_STRATEGIC_AI_LONG_RUN_REQUIRE_EVENT_TYPE", DEFAULT_REQUIRED_EVENT_TYPE),
	}
	if _env_int("HEROES_STRATEGIC_AI_LONG_RUN_PROGRESS", 0, 0, 1) > 0:
		config["progress_callback"] = Callable(self, "_progress_callback")
	return config

func _progress_callback(payload: Dictionary) -> void:
	print("%s_PROGRESS %s" % [REPORT_ID, JSON.stringify(payload)])

func _env_int(name: String, fallback: int, min_value: int, max_value: int) -> int:
	var raw: String = OS.get_environment(name).strip_edges()
	if raw == "" or not raw.is_valid_int():
		return fallback
	var value: int = max(min_value, int(raw))
	if max_value > 0:
		value = min(value, max_value)
	return value

func _env_string(name: String, fallback: String) -> String:
	var raw: String = OS.get_environment(name).strip_edges()
	if raw == "":
		return fallback
	return raw

func _assert_report(report: Dictionary, expected_seed_count: int, expected_turn_count: int, required_event_type: String = "") -> bool:
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
	if int(report.get("runtime_msec", 0)) <= 0:
		_fail("Long-run matrix report is missing runtime telemetry: %s" % JSON.stringify(report))
		return false
	if int(report.get("seed_count", 0)) != expected_seed_count:
		_fail("Long-run matrix requested seed count mismatch: %s" % JSON.stringify(report))
		return false
	var shard: Dictionary = report.get("seed_shard", {}) if report.get("seed_shard", {}) is Dictionary else {}
	if shard.is_empty():
		_fail("Long-run matrix report is missing seed-shard metadata: %s" % JSON.stringify(report))
		return false
	if int(shard.get("seed_count", 0)) != expected_seed_count:
		_fail("Long-run matrix seed-shard count mismatch: %s" % JSON.stringify(shard))
		return false
	if int(shard.get("start_ordinal", 0)) < 1 or int(shard.get("end_ordinal", 0)) < int(shard.get("start_ordinal", 0)):
		_fail("Long-run matrix seed-shard ordinal range is invalid: %s" % JSON.stringify(shard))
		return false
	if int(report.get("turn_count", 0)) != expected_turn_count:
		_fail("Long-run matrix requested turn count mismatch: %s" % JSON.stringify(report))
		return false
	if int(summary.get("row_count", 0)) != expected_seed_count:
		_fail("Long-run matrix row count mismatch: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("setup_ok_count", 0)) != expected_seed_count:
		_fail("Long-run matrix must start every configured Native RMG seed: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("turns_completed", 0)) <= 0:
		_fail("Long-run matrix completed no turns: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("enemy_activity_event_count", 0)) <= 0:
		_fail("Long-run matrix observed no enemy activity: %s" % JSON.stringify(summary))
		return false
	for required_summary_key in [
		"battle_handoff_candidate_turn_count",
		"near_battle_target_turn_count",
		"near_battle_town_or_hero_turn_count",
		"natural_tactical_battle_pressure_turn_count",
		"natural_tactical_battle_arrival_turn_count",
		"best_min_active_raid_goal_distance",
		"best_min_tactical_battle_goal_distance",
		"nearest_tactical_battle_target",
		"movement_distance_delta_total",
		"battle_interrupt_count",
		"auto_resolved_battle_count",
		"tactical_battle_queued_count",
		"natural_tactical_battle_queue_event_count",
		"unreachable_active_target_turn_count",
		"unreachable_active_target_total",
		"suppressed_post_outcome_unreachable_active_target_total",
	]:
		if not summary.has(required_summary_key):
			_fail("Long-run matrix summary missing battle-handoff coverage key %s: %s" % [required_summary_key, JSON.stringify(summary)])
			return false
	if int(summary.get("natural_tactical_battle_pressure_turn_count", 0)) != int(summary.get("battle_handoff_candidate_turn_count", 0)):
		_fail("Long-run matrix natural tactical pressure count diverged from handoff candidate count: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("natural_tactical_battle_arrival_turn_count", 0)) != int(summary.get("near_battle_town_or_hero_turn_count", 0)):
		_fail("Long-run matrix natural tactical arrival count diverged from near town/hero count: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("natural_tactical_battle_queue_event_count", 0)) != int(summary.get("tactical_battle_queued_count", 0)):
		_fail("Long-run matrix natural tactical queue count diverged from tactical queue count: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("target_integrity_violation_count", 0)) > 0:
		_fail("Long-run matrix observed self-looking strategic AI target labels: %s" % JSON.stringify(summary))
		return false
	if required_event_type.strip_edges() != "":
		var event_counts: Dictionary = summary.get("event_counts", {}) if summary.get("event_counts", {}) is Dictionary else {}
		if int(event_counts.get(required_event_type.strip_edges(), 0)) <= 0:
			_fail("Long-run matrix did not observe required event type %s: %s" % [required_event_type.strip_edges(), JSON.stringify(summary)])
			return false
	var rows: Array = report.get("rows", []) if report.get("rows", []) is Array else []
	if rows.size() != expected_seed_count:
		_fail("Long-run matrix emitted %d rows, expected %d." % [rows.size(), expected_seed_count])
		return false
	for row in rows:
		if not (row is Dictionary):
			_fail("Long-run matrix row is not a dictionary.")
			return false
		if String(row.get("startup_source", "")) != "native_rmg_disk_package":
			_fail("Long-run matrix row did not use native disk package startup: %s" % JSON.stringify(row))
			return false
		if int(row.get("seed_ordinal", 0)) < int(shard.get("start_ordinal", 1)) or int(row.get("seed_ordinal", 0)) > int(shard.get("end_ordinal", 1)):
			_fail("Long-run matrix row seed ordinal is outside shard range: row=%s shard=%s" % [JSON.stringify(row), JSON.stringify(shard)])
			return false
		if String(row.get("size_class_id", "")) != "homm3_small":
			_fail("Long-run matrix smoke must stay in strict Small scope: %s" % JSON.stringify(row))
			return false
		if String(row.get("signature", "")) == "":
			_fail("Long-run matrix row missing signature: %s" % JSON.stringify(row))
			return false
		if int(row.get("target_integrity_violation_count", 0)) > 0:
			_fail("Long-run matrix row has strategic AI target-integrity violations: %s" % JSON.stringify(row))
			return false
		if int(row.get("setup_runtime_msec", -1)) < 0 or int(row.get("row_runtime_msec", 0)) <= 0:
			_fail("Long-run matrix row missing setup/row runtime telemetry: %s" % JSON.stringify(row))
			return false
		if bool(row.get("ok", false)) and String(row.get("final_game_state", "")) == "battle":
			_fail("Long-run matrix row remained in battle after terminal auto-resolve: %s" % JSON.stringify(row))
			return false
		var turn_results: Array = row.get("turn_results", []) if row.get("turn_results", []) is Array else []
		for turn_result in turn_results:
			if not (turn_result is Dictionary):
				_fail("Long-run matrix turn result is not a dictionary: %s" % JSON.stringify(row))
				return false
			var handoff_summary: Dictionary = turn_result.get("battle_handoff_summary", {}) if turn_result.get("battle_handoff_summary", {}) is Dictionary else {}
			if handoff_summary.is_empty():
				_fail("Long-run matrix turn result missing battle-handoff summary: %s" % JSON.stringify(turn_result))
				return false
			if not handoff_summary.has("active_raid_count") \
					or not handoff_summary.has("min_goal_distance") \
					or not handoff_summary.has("min_tactical_battle_goal_distance") \
					or not handoff_summary.has("near_battle_town_or_hero_target_count") \
					or not handoff_summary.has("nearest_active_target") \
					or not handoff_summary.has("nearest_tactical_battle_target") \
					or not handoff_summary.has("post_outcome_active_target_diagnostics_suppressed") \
					or not handoff_summary.has("unreachable_active_targets") \
					or not handoff_summary.has("suppressed_post_outcome_unreachable_active_target_count") \
					or not handoff_summary.has("suppressed_post_outcome_unreachable_active_targets"):
				_fail("Long-run matrix battle-handoff summary missing active raid distance evidence: %s" % JSON.stringify(handoff_summary))
				return false
			if int(turn_result.get("turn_runtime_msec", -1)) < 0:
				_fail("Long-run matrix turn result missing runtime telemetry: %s" % JSON.stringify(turn_result))
				return false
			var target_integrity_violations: Array = turn_result.get("target_integrity_violations", []) if turn_result.get("target_integrity_violations", []) is Array else []
			if not target_integrity_violations.is_empty():
				_fail("Long-run matrix turn has strategic AI target-integrity violations: %s" % JSON.stringify(turn_result))
				return false
	if int(summary.get("max_row_runtime_msec", 0)) <= 0 or int(summary.get("max_turn_runtime_msec", -1)) < 0:
		_fail("Long-run matrix summary missing runtime telemetry: %s" % JSON.stringify(summary))
		return false
	var blockers: Array = report.get("blocker_rows", []) if report.get("blocker_rows", []) is Array else []
	var full_matrix_blocker := _blocker_row(blockers, "strategic_ai_long_run_full_100_seed_8_week_matrix_not_run")
	var is_full_matrix := expected_seed_count >= HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_FULL_SEED_TARGET \
		and expected_turn_count >= HeadlessSimulationHarnessRulesScript.STRATEGIC_AI_LONG_RUN_FULL_TURN_TARGET
	if is_full_matrix:
		if not full_matrix_blocker.is_empty():
			_fail("Full-target strategic AI matrix must not preserve the focused-run blocker: %s" % JSON.stringify(blockers))
			return false
	else:
		if full_matrix_blocker.is_empty():
			_fail("Focused strategic AI matrix must preserve the full 100-seed eight-week remaining-validation blocker: %s" % JSON.stringify(blockers))
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
