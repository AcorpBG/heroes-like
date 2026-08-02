extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_FORD_REAVERS_BALANCE_REGRESSION"
const PLACEMENT_ID := "bridge_ford_reavers"
const MAX_TERMINAL_MARGIN_PCT := 90
const CASES := [
	{"scenario_id": "ironbridge-stand"},
	{"scenario_id": "mireford-skirmish"},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"placement_id": PLACEMENT_ID,
		"samples": [],
	}
	var failures := []
	var failed_turn_logs := {}
	for case_config in CASES:
		var scenario_id := String(case_config.get("scenario_id", ""))
		var encounter := _encounter(scenario_id)
		if encounter.is_empty():
			failures.append("%s is missing %s" % [scenario_id, PLACEMENT_ID])
			continue
		var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(scenario_id, encounter, 72, "normal")
		var compact := _compact_sample(scenario_id, sample)
		payload["samples"].append(compact)
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
			failures.append("%s no longer resolves as a bounded player victory" % scenario_id)
			failed_turn_logs[scenario_id] = sample.get("turn_log", [])
		elif int(sample.get("terminal_health_margin_pct", 100)) > MAX_TERMINAL_MARGIN_PCT:
			failures.append("%s remains above the matrix terminal-margin target" % scenario_id)
			failed_turn_logs[scenario_id] = sample.get("turn_log", [])
		elif int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
			failures.append("%s still fails to apply meaningful enemy pressure" % scenario_id)
			failed_turn_logs[scenario_id] = sample.get("turn_log", [])
	if not failures.is_empty():
		payload["failures"] = failures
		payload["turn_logs"] = failed_turn_logs
		_fail("Bridge Ford Reavers balance regression failed for one or more authored placements.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(scenario_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == PLACEMENT_ID:
			return encounter
	return {}

func _compact_sample(scenario_id: String, sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
