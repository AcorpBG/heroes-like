extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_FORD_REAVERS_BALANCE_REGRESSION"
const PLACEMENT_ID := "bridge_ford_reavers"
const LOCAL_ARMY_CONTRACTS := {
	"ironbridge-stand": {"army_id": "army_ironbridge_ford_reavers_watch", "stack_counts": {"unit_blackbranch_cutthroat": 10, "unit_mire_slinger": 12, "unit_bog_brute": 2}},
	"mireford-skirmish": {"army_id": "army_mireford_ford_reavers_watch", "stack_counts": {"unit_blackbranch_cutthroat": 13, "unit_mire_slinger": 11, "unit_mireclaw_gorefen_rippers": 2}},
}
const SHARED_STACK_COUNTS := {"unit_blackbranch_cutthroat": 13, "unit_mire_slinger": 8}
const MIREFORD_SAMPLE := {"outcome_state": "defeat", "pacing_band": "extended", "round_reached": 7, "terminal_health_margin_pct": 28, "enemy_damage_per_round": 42}
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
	if _stack_counts(ContentService.get_army_group("army_ford_reavers")) != SHARED_STACK_COUNTS:
		failures.append("army_ford_reavers changed with the placement-local correction")
	for case_config in CASES:
		var scenario_id := String(case_config.get("scenario_id", ""))
		var encounter := _encounter(scenario_id)
		if encounter.is_empty():
			failures.append("%s is missing %s" % [scenario_id, PLACEMENT_ID])
			continue
		var local_army: Dictionary = encounter.get("enemy_army", {})
		var army_contract: Dictionary = LOCAL_ARMY_CONTRACTS[scenario_id]
		if String(local_army.get("id", "")) != String(army_contract.get("army_id", "")) or _stack_counts(local_army) != army_contract.get("stack_counts", {}):
			failures.append("%s placement-local army drifted" % scenario_id)
		var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(scenario_id, encounter, 72, "normal")
		var compact := _compact_sample(scenario_id, sample)
		payload["samples"].append(compact)
		if scenario_id == "ironbridge-stand":
			var round_reached := int(sample.get("round_reached", 0))
			var enemy_dpr := int(sample.get("damage_per_round", {}).get("enemy", 0))
			if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory" or not String(sample.get("pacing_band", "")) in ["standard", "extended"] or round_reached < 3 or round_reached > 8 or int(sample.get("terminal_health_margin_pct", 100)) > 74 or enemy_dpr <= 2 or enemy_dpr > 50:
				failures.append("Ironbridge Ford Reavers remains outside its pacing and pressure target")
				failed_turn_logs[scenario_id] = sample.get("turn_log", [])
		else:
			if String(sample.get("outcome_state", "")) != String(MIREFORD_SAMPLE.get("outcome_state", "")) or String(sample.get("pacing_band", "")) != String(MIREFORD_SAMPLE.get("pacing_band", "")) or int(sample.get("round_reached", 0)) != int(MIREFORD_SAMPLE.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(MIREFORD_SAMPLE.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(MIREFORD_SAMPLE.get("enemy_damage_per_round", -1)):
				failures.append("Mireford Ford Reavers drifted from its bounded cohort outcome")
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
		"pacing_band": String(sample.get("pacing_band", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
