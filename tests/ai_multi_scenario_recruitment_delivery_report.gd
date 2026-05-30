extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "AI_MULTI_SCENARIO_RECRUITMENT_DELIVERY_REPORT"
const OUTPUT_DIR := "res://.artifacts/ai_multi_scenario_recruitment_delivery_report"

var _errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var input_config := {}
	var scenario_ids := _scenario_ids_from_args()
	if not scenario_ids.is_empty():
		input_config["strategic_ai_recruitment_coverage_scenario_ids"] = scenario_ids
	var simulation_case := HeadlessSimulationHarnessRulesScript.strategic_ai_multi_scenario_recruitment_delivery_case(input_config)
	_assert_case(simulation_case)
	var report := {
		"schema_id": "ai_multi_scenario_recruitment_delivery_v1",
		"report_id": REPORT_ID,
		"ok": _errors.is_empty(),
		"case": simulation_case,
		"errors": _errors.duplicate(),
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload(simulation_case))])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _assert_case(simulation_case: Dictionary) -> void:
	if String(simulation_case.get("subsystem_id", "")) != "strategic_ai_multi_scenario_recruitment_delivery":
		_error("Unexpected subsystem id: %s" % simulation_case)
	if String(simulation_case.get("status", "")) != "pass":
		_error("Multi-scenario recruitment delivery did not pass: %s" % simulation_case)
	var summary: Dictionary = simulation_case.get("summary", {}) if simulation_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = simulation_case.get("evidence", {}) if simulation_case.get("evidence", {}) is Dictionary else {}
	if int(summary.get("scenario_count", 0)) < 5:
		_error("Scenario coverage is too narrow: %s" % summary)
	if int(summary.get("faction_case_count", 0)) < 5:
		_error("Faction coverage is too narrow: %s" % summary)
	if int(summary.get("delivered_faction_count", 0)) != int(summary.get("faction_case_count", -1)):
		_error("Not every faction case delivered recruits into its raid host: %s" % summary)
	if int(summary.get("town_recruit_event_count", 0)) < int(summary.get("faction_case_count", 0)):
		_error("Missing ai_town_recruited event coverage: %s" % summary)
	if int(summary.get("raid_reinforcement_event_count", 0)) < int(summary.get("faction_case_count", 0)):
		_error("Missing ai_raid_reinforced event coverage: %s" % summary)
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_town_recruited" not in event_types or "ai_raid_reinforced" not in event_types:
		_error("Event type coverage missing recruitment/reinforcement events: %s" % [event_types])
	if String(evidence.get("save_policy", "")) != "hero_task_state_live_persist_no_save_migration":
		_error("Save policy changed: %s" % evidence)
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_error("Public event leak tokens detected: %s" % leak_tokens)
	for row in evidence.get("faction_cases", []):
		if not (row is Dictionary):
			continue
		if not bool(row.get("delivered", false)):
			_error("Undelivered faction row: %s" % row)
		if int(row.get("after_strength", 0)) <= int(row.get("before_strength", 0)):
			_error("Raid host strength did not increase: %s" % row)
		if int(row.get("town_recruits_after", 9999)) >= int(row.get("town_recruits_before", 0)):
			_error("Town recruit pool was not consumed: %s" % row)
		if int(row.get("town_recruit_event_count", 0)) < 1 or int(row.get("raid_reinforcement_event_count", 0)) < 1:
			_error("Faction row is missing recruitment event evidence: %s" % row)
		var raid: Dictionary = row.get("raid", {}) if row.get("raid", {}) is Dictionary else {}
		if String(raid.get("target_kind", "")) == "" or String(raid.get("target_placement_id", "")) == "":
			_error("Raid host lost its active target after recruitment delivery: %s" % row)

func _summary_payload(simulation_case: Dictionary) -> Dictionary:
	var summary: Dictionary = simulation_case.get("summary", {}) if simulation_case.get("summary", {}) is Dictionary else {}
	return {
		"ok": _errors.is_empty(),
		"scenario_count": int(summary.get("scenario_count", 0)),
		"faction_case_count": int(summary.get("faction_case_count", 0)),
		"delivered_faction_count": int(summary.get("delivered_faction_count", 0)),
		"town_recruit_event_count": int(summary.get("town_recruit_event_count", 0)),
		"raid_reinforcement_event_count": int(summary.get("raid_reinforcement_event_count", 0)),
	}

func _scenario_ids_from_args() -> Array:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if not text.begins_with("--scenario-ids="):
			continue
		var raw_ids := text.trim_prefix("--scenario-ids=").split(",", false)
		var ids := []
		for raw_id in raw_ids:
			var scenario_id := String(raw_id).strip_edges()
			if scenario_id != "":
				ids.append(scenario_id)
		return ids
	return []

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
