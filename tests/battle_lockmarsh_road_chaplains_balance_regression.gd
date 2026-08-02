extends Node

const BalanceHarness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_LOCKMARSH_ROAD_CHAPLAINS_BALANCE_REGRESSION"
const SCENARIO_ID := "lockmarsh-surge"
const PLACEMENT_ID := "surge_road_chaplains"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var encounter := _encounter()
	if encounter.is_empty():
		_fail("Lockmarsh Surge is missing the Road Chaplains placement.", {})
		return
	var sample := BalanceHarness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}
	if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
		_fail_sample("Road Chaplains does not resolve as a bounded player victory.", payload, sample)
		return
	if int(sample.get("terminal_health_margin_pct", 100)) > 90:
		_fail_sample("Road Chaplains remains above the matrix terminal-margin target.", payload, sample)
		return
	if int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
		_fail_sample("Road Chaplains still fails to apply meaningful enemy pressure.", payload, sample)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter() -> Dictionary:
	for encounter in ContentService.get_scenario(SCENARIO_ID).get("encounters", []):
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
