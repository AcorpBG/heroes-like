extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_ACTIVE_SCENARIO_BREADTH_REPORT"
const SCHEMA_ID := "battle_autoplay_active_scenario_breadth_report_v1"
const MIN_ACTIVE_SCENARIO_COUNT := 16
const MIN_AUTHORED_ENCOUNTER_COUNT := 51
const ACTIVE_QUEUE_CLEAR_REQUIRED := true
const FORBIDDEN_POLICY_FLAGS := [
	"automatic_tuning",
	"runtime_balance_changes",
	"authored_content_writeback",
	"manual_play_replacement",
	"final_combat_balance_approval",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario_ids := _active_authored_scenario_ids()
	var expected_encounter_count := _encounter_count_for_scenarios(scenario_ids)
	if scenario_ids.size() < MIN_ACTIVE_SCENARIO_COUNT:
		_fail("Active scenario set is too small for combat-breadth evidence: %s" % scenario_ids, {})
		return
	if expected_encounter_count < MIN_AUTHORED_ENCOUNTER_COUNT:
		_fail("Active authored encounter set is too small for combat-breadth evidence: %d" % expected_encounter_count, {})
		return
	var config := {
		"battle_scenario_ids": scenario_ids,
		"battle_sample_limit": expected_encounter_count,
		"battle_minimum_sample_count": expected_encounter_count,
	}
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report(config)
	var repeat_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report(config)
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var repeat_summary: Dictionary = repeat_report.get("summary", {}) if repeat_report.get("summary", {}) is Dictionary else {}
	var queue: Dictionary = summary.get("balance_tuning_queue", {}) if summary.get("balance_tuning_queue", {}) is Dictionary else {}
	var repeat_queue: Dictionary = repeat_summary.get("balance_tuning_queue", {}) if repeat_summary.get("balance_tuning_queue", {}) is Dictionary else {}
	var scenario_distribution: Dictionary = summary.get("scenario_distribution", {}) if summary.get("scenario_distribution", {}) is Dictionary else {}
	var missing_scenarios := _missing_distribution_scenarios(scenario_ids, scenario_distribution)
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": SCHEMA_ID,
		"policy": "report_only_active_scenario_combat_breadth_probe",
		"active_scenario_count": scenario_ids.size(),
		"expected_encounter_count": expected_encounter_count,
		"sample_count": int(summary.get("sample_count", 0)),
		"completed_sample_count": int(summary.get("completed_sample_count", 0)),
		"stalled_sample_count": int(summary.get("stalled_sample_count", 0)),
		"invalid_order_count": int(summary.get("invalid_order_count", 0)),
		"scenario_distribution": scenario_distribution,
		"missing_scenario_ids": missing_scenarios,
		"combat_feel_gate_status": String((summary.get("combat_feel_gate", {}) as Dictionary).get("status", "")) if summary.get("combat_feel_gate", {}) is Dictionary else "",
		"balance_matrix_gate_status": String((summary.get("balance_matrix_gate", {}) as Dictionary).get("status", "")) if summary.get("balance_matrix_gate", {}) is Dictionary else "",
		"runtime_consequence_gate_status": String((summary.get("runtime_consequence_gate", {}) as Dictionary).get("status", "")) if summary.get("runtime_consequence_gate", {}) is Dictionary else "",
		"runtime_consequence_matrix_gate_status": String((summary.get("runtime_consequence_matrix_gate", {}) as Dictionary).get("status", "")) if summary.get("runtime_consequence_matrix_gate", {}) is Dictionary else "",
		"average_terminal_health_margin_pct": int(summary.get("average_terminal_health_margin_pct", 0)),
		"average_total_damage_per_round": int(summary.get("average_total_damage_per_round", 0)),
		"primary_outcome_state": String(summary.get("primary_outcome_state", "")),
		"primary_outcome_pct": int(summary.get("primary_outcome_pct", 0)),
		"primary_pacing_band": String(summary.get("primary_pacing_band", "")),
		"primary_pacing_band_pct": int(summary.get("primary_pacing_band_pct", 0)),
		"balance_tuning_queue": {
			"schema": String(queue.get("schema", "")),
			"policy": String(queue.get("policy", "")),
			"status": String(queue.get("status", "")),
			"item_count": int(queue.get("item_count", 0)),
			"high_priority_count": int(queue.get("high_priority_count", 0)),
			"medium_priority_count": int(queue.get("medium_priority_count", 0)),
			"queue_signature": String(queue.get("queue_signature", "")),
			"repeat_queue_signature": String(repeat_queue.get("queue_signature", "")),
			"coverage": queue.get("coverage", {}),
			"top_contributors": queue.get("top_contributors", []),
		},
		"active_queue_clear_gate": {
			"required": ACTIVE_QUEUE_CLEAR_REQUIRED,
			"status": String(queue.get("status", "")),
			"item_count": int(queue.get("item_count", 0)),
			"high_priority_count": int(queue.get("high_priority_count", 0)),
			"medium_priority_count": int(queue.get("medium_priority_count", 0)),
		},
		"reporting_policy": {
			"automatic_tuning": false,
			"runtime_balance_changes": false,
			"authored_content_writeback": false,
			"manual_play_replacement": false,
			"final_combat_balance_approval": false,
		},
		"warnings": report.get("warnings", []),
		"deferred": report.get("deferred", []),
	}
	if not _assert_payload(payload, summary, queue, repeat_queue):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_payload(payload: Dictionary, summary: Dictionary, queue: Dictionary, repeat_queue: Dictionary) -> bool:
	if int(payload.get("sample_count", 0)) != int(payload.get("expected_encounter_count", -1)):
		_fail("Active-scenario combat breadth did not sample every authored encounter placement.", payload)
		return false
	if int(payload.get("completed_sample_count", 0)) != int(payload.get("sample_count", -1)):
		_fail("Active-scenario combat breadth did not complete every sampled battle.", payload)
		return false
	if int(payload.get("stalled_sample_count", 0)) != 0:
		_fail("Active-scenario combat breadth has stalled samples.", payload)
		return false
	if int(payload.get("invalid_order_count", 0)) != 0:
		_fail("Active-scenario combat breadth produced invalid orders.", payload)
		return false
	var missing_scenarios: Array = payload.get("missing_scenario_ids", []) if payload.get("missing_scenario_ids", []) is Array else []
	if not missing_scenarios.is_empty():
		_fail("Active-scenario combat breadth missed scenario samples: %s" % missing_scenarios, payload)
		return false
	if String(queue.get("schema", "")) != "battle_autoplay_balance_tuning_queue_v1":
		_fail("Active-scenario combat breadth is missing tuning queue schema evidence.", payload)
		return false
	if String(queue.get("policy", "")) != "report_only_no_runtime_tuning":
		_fail("Active-scenario combat breadth must keep tuning queue report-only.", payload)
		return false
	if String(queue.get("queue_signature", "")) == "" or String(queue.get("queue_signature", "")) != String(repeat_queue.get("queue_signature", "")):
		_fail("Active-scenario combat breadth queue signature is missing or non-deterministic.", payload)
		return false
	if ACTIVE_QUEUE_CLEAR_REQUIRED and not _assert_active_queue_clear(queue, payload):
		return false
	for gate_key in ["combat_feel_gate", "balance_matrix_gate", "runtime_consequence_gate", "runtime_consequence_matrix_gate"]:
		var gate: Dictionary = summary.get(gate_key, {}) if summary.get(gate_key, {}) is Dictionary else {}
		if String(gate.get("status", "")) == "fail":
			_fail("Active-scenario combat breadth has a failed %s: %s" % [gate_key, gate], payload)
			return false
	var policy: Dictionary = payload.get("reporting_policy", {}) if payload.get("reporting_policy", {}) is Dictionary else {}
	for flag in FORBIDDEN_POLICY_FLAGS:
		if bool(policy.get(flag, true)):
			_fail("Active-scenario combat breadth reported forbidden policy flag: %s" % flag, payload)
			return false
	return true

func _assert_active_queue_clear(queue: Dictionary, payload: Dictionary) -> bool:
	if String(queue.get("status", "")) != "clear":
		_fail("Active-scenario combat breadth tuning queue must remain clear; reopened status: %s top_contributors=%s" % [String(queue.get("status", "")), JSON.stringify(queue.get("top_contributors", []))], payload)
		return false
	if int(queue.get("item_count", 0)) != 0:
		_fail("Active-scenario combat breadth tuning queue reopened with item_count=%d." % int(queue.get("item_count", 0)), payload)
		return false
	if int(queue.get("high_priority_count", 0)) != 0 or int(queue.get("medium_priority_count", 0)) != 0:
		_fail("Active-scenario combat breadth tuning queue reopened priority items: high=%d medium=%d." % [int(queue.get("high_priority_count", 0)), int(queue.get("medium_priority_count", 0))], payload)
		return false
	var top_contributors: Array = queue.get("top_contributors", []) if queue.get("top_contributors", []) is Array else []
	if not top_contributors.is_empty():
		_fail("Active-scenario combat breadth tuning queue clear status had top contributors: %s" % JSON.stringify(top_contributors), payload)
		return false
	var coverage: Dictionary = queue.get("coverage", {}) if queue.get("coverage", {}) is Dictionary else {}
	for watch_key in ["sample_watch_count", "cohort_watch_count", "gate_item_count", "balance_matrix_failure_count", "combat_feel_failure_count"]:
		if int(coverage.get(watch_key, 0)) != 0:
			_fail("Active-scenario combat breadth tuning queue coverage reopened %s=%d." % [watch_key, int(coverage.get(watch_key, 0))], payload)
			return false
	var categories: Array = coverage.get("categories", []) if coverage.get("categories", []) is Array else []
	if not categories.is_empty():
		_fail("Active-scenario combat breadth tuning queue clear status had categories: %s" % JSON.stringify(categories), payload)
		return false
	return true

func _active_authored_scenario_ids() -> Array:
	var ids := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario := ContentService.get_authored_scenario(String(scenario_id))
		var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false)):
			ids.append(String(scenario_id))
	ids.sort()
	return ids

func _encounter_count_for_scenarios(scenario_ids: Array) -> int:
	var total := 0
	for scenario_id in scenario_ids:
		var scenario := ContentService.get_authored_scenario(String(scenario_id))
		var encounters: Array = scenario.get("encounters", []) if scenario.get("encounters", []) is Array else []
		total += encounters.size()
	return total

func _missing_distribution_scenarios(scenario_ids: Array, scenario_distribution: Dictionary) -> Array:
	var missing := []
	for scenario_id in scenario_ids:
		if int(scenario_distribution.get(String(scenario_id), 0)) <= 0:
			missing.append(String(scenario_id))
	return missing

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
