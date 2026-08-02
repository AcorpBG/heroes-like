extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_BELLWAKE_WRECK_BALANCE_REGRESSION"
const SCENARIO_ID := "bellwake-wreck-claim"
const MAX_TERMINAL_MARGIN_PCT := 90
const PLACEMENT_IDS := [
	"bellwake_relay_pickets",
	"bellwake_mirror_lancers",
	"bellwake_aurora_battery",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	var failures := []
	var failed_turn_logs := {}
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(String(placement_id))
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(String(placement_id), sample))
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
			failures.append("%s does not resolve as a bounded player victory" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
		elif int(sample.get("terminal_health_margin_pct", 100)) > MAX_TERMINAL_MARGIN_PCT:
			failures.append("%s exceeds the terminal-margin target" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
		elif int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
			failures.append("%s does not apply meaningful enemy pressure" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
	if not failures.is_empty():
		payload["failures"] = failures
		payload["turn_logs"] = failed_turn_logs
		_fail("Bellwake encounter balance regression failed.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(placement_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _compact_sample(placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"placement_id": placement_id,
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
