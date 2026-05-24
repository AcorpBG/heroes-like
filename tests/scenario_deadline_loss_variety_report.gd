extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SCENARIO_DEADLINE_LOSS_VARIETY_REPORT"
const MIN_ACTIVE_DEADLINE_SCENARIO_COUNT := 16
const SKIRMISH_ONLY_SCENARIO_ID := "mireford-skirmish"
const FINALE_SCENARIO_ID := "ninefold-confluence"
const FORBIDDEN_CLAIM_TOKENS := [
	"alpha_or_parity_claim\":true",
	"final_scenario_balance\":true",
	"campaign_breadth_complete\":true",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario_ids := _active_authored_scenario_ids()
	if scenario_ids.size() < MIN_ACTIVE_DEADLINE_SCENARIO_COUNT:
		_fail("Active authored scenario deadline set is too small: %s" % JSON.stringify(scenario_ids))
		return
	var rows := []
	for scenario_id in scenario_ids:
		var row := _deadline_row(String(scenario_id))
		if row.is_empty():
			return
		rows.append(row)
	var campaign_deadline_count := 0
	var skirmish_deadline_count := 0
	var finale_deadline_count := 0
	for row in rows:
		if bool(row.get("campaign_available", false)):
			campaign_deadline_count += 1
		if bool(row.get("skirmish_available", false)):
			skirmish_deadline_count += 1
		if String(row.get("scenario_id", "")) == FINALE_SCENARIO_ID:
			finale_deadline_count += 1
	var expected_counts := _active_availability_counts(scenario_ids)
	if campaign_deadline_count != int(expected_counts.get("campaign", 0)) or skirmish_deadline_count != int(expected_counts.get("skirmish", 0)) or finale_deadline_count != 1:
		_fail("Deadline loss objectives do not cover campaign, skirmish, and finale surfaces: %s" % JSON.stringify(rows))
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": "scenario_deadline_loss_variety_report_v2",
		"deadline_scenario_count": rows.size(),
		"active_deadline_count": scenario_ids.size(),
		"expected_campaign_deadline_count": int(expected_counts.get("campaign", 0)),
		"expected_skirmish_deadline_count": int(expected_counts.get("skirmish", 0)),
		"campaign_deadline_count": campaign_deadline_count,
		"skirmish_deadline_count": skirmish_deadline_count,
		"finale_deadline_count": finale_deadline_count,
		"skirmish_only_scenario_id": SKIRMISH_ONLY_SCENARIO_ID,
		"finale_scenario_id": FINALE_SCENARIO_ID,
		"rows": rows,
		"boundary": {
			"authored_deadline_loss_objectives": true,
			"final_scenario_balance": false,
			"new_campaign_arc": false,
			"campaign_breadth_complete": false,
			"alpha_or_parity_claim": false,
		},
	}
	var compact_text := JSON.stringify(payload).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if compact_text.contains(String(token)):
			_fail("Report payload contains forbidden claim token: %s." % token)
			return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

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

func _active_availability_counts(scenario_ids: Array) -> Dictionary:
	var counts := {"campaign": 0, "skirmish": 0}
	for scenario_id in scenario_ids:
		var scenario := ContentService.get_authored_scenario(String(scenario_id))
		var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if bool(availability.get("campaign", false)):
			counts["campaign"] = int(counts.get("campaign", 0)) + 1
		if bool(availability.get("skirmish", false)):
			counts["skirmish"] = int(counts.get("skirmish", 0)) + 1
	return counts

func _deadline_row(scenario_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		_fail("Missing scenario %s." % scenario_id)
		return {}
	var deadline_objective := _deadline_objective(scenario)
	if deadline_objective.is_empty():
		_fail("Scenario %s is missing a day_at_least defeat objective." % scenario_id)
		return {}
	var day := int(deadline_objective.get("day", 0))
	if day < 5:
		_fail("Scenario %s has an unrealistically low deadline day: %d." % [scenario_id, day])
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null or session.scenario_id != scenario_id:
		_fail("Scenario %s did not boot a live skirmish session." % scenario_id)
		return {}
	ScenarioRulesScript.normalize_scenario_state(session)
	session.day = day - 1
	var before_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(before_result.get("status", "")) != "in_progress":
		_fail("Scenario %s deadline resolved before the authored day: %s" % [scenario_id, JSON.stringify(before_result)])
		return {}
	session.scenario_status = "in_progress"
	session.scenario_summary = ""
	session.day = day
	var deadline_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(deadline_result.get("status", "")) != "defeat" or session.scenario_status != "defeat":
		_fail("Scenario %s deadline did not resolve as defeat on day %d: %s" % [scenario_id, day, JSON.stringify(deadline_result)])
		return {}
	var objective_text := ScenarioRulesScript.describe_objectives(session)
	if objective_text.find(String(deadline_objective.get("label", ""))) < 0:
		_fail("Scenario %s deadline label is not visible in objective text: %s" % [scenario_id, objective_text])
		return {}
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return {
		"scenario_id": scenario_id,
		"deadline_objective_id": String(deadline_objective.get("id", "")),
		"deadline_label": String(deadline_objective.get("label", "")),
		"day": day,
		"pre_deadline_status": String(before_result.get("status", "")),
		"deadline_status": String(deadline_result.get("status", "")),
		"campaign_available": bool(availability.get("campaign", false)),
		"skirmish_available": bool(availability.get("skirmish", false)),
	}

func _deadline_objective(scenario: Dictionary) -> Dictionary:
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var defeat: Array = objectives.get("defeat", []) if objectives.get("defeat", []) is Array else []
	for objective in defeat:
		if objective is Dictionary and String(objective.get("type", "")) == "day_at_least":
			return objective
	return {}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
