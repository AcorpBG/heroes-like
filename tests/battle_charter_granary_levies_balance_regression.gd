extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_CHARTER_GRANARY_LEVIES_BALANCE_REGRESSION"
const SCENARIO_ID := "charter-pyre"
const PLACEMENT_ID := "charter_granary_levies"
const MAX_TERMINAL_MARGIN_PCT := 74

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var encounter := _encounter()
	if encounter.is_empty():
		_fail("Charter Pyre is missing the Granary Levies encounter placement.", {})
		return
	var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}
	if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "defeat":
		_fail_sample("Granary Levies no longer resolves as a bounded player defeat.", payload, sample)
		return
	if int(sample.get("terminal_health_margin_pct", 100)) > MAX_TERMINAL_MARGIN_PCT:
		_fail_sample("Granary Levies remains above the matrix terminal-margin target.", payload, sample)
		return
	if int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
		_fail_sample("Granary Levies still fails to apply meaningful enemy pressure.", payload, sample)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == PLACEMENT_ID:
			return encounter
	return {}

func _fail_sample(message: String, payload: Dictionary, sample: Dictionary) -> void:
	payload["turn_log"] = sample.get("turn_log", [])
	_fail(message, payload)

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
