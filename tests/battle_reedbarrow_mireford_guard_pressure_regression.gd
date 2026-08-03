extends Node

const BalanceHarness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_REEDBARROW_MIREFORD_GUARD_PRESSURE_REGRESSION"
const MAX_TERMINAL_MARGIN_PCT := 89
const MIN_ROUND := 2
const MAX_ROUND := 8
const ENCOUNTER_CONTRACTS := {
	"reedbarrow-ferry": {
		"placement_id": "barrow_pickets",
		"local_army_id": "army_reedbarrow_barrow_pickets_watch",
		"local_stack_counts": {"unit_blackbranch_cutthroat": 15, "unit_mire_slinger": 12},
		"shared_army_id": "army_barrow_pickets",
		"shared_stack_counts": {"unit_blackbranch_cutthroat": 14, "unit_mire_slinger": 9},
	},
	"mireford-skirmish": {
		"placement_id": "mireford_reed_totemists",
		"local_army_id": "army_mireford_reed_totemists_watch",
		"local_stack_counts": {"unit_mire_slinger": 12, "unit_blackbranch_cutthroat": 12, "unit_gorefen_ripper": 3},
		"shared_army_id": "army_muckveil_harriers",
		"shared_stack_counts": {"unit_mire_slinger": 10, "unit_blackbranch_cutthroat": 6, "unit_gorefen_ripper": 2},
	},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var payload := {"ok": true, "report_id": REPORT_ID, "samples": []}
	var failures := []
	var failed_turn_logs := {}
	for scenario_id in ENCOUNTER_CONTRACTS:
		var contract: Dictionary = ENCOUNTER_CONTRACTS[scenario_id]
		var placement_id := String(contract.get("placement_id", ""))
		var encounter := _encounter(String(scenario_id), placement_id)
		if encounter.is_empty():
			failures.append("%s is missing %s" % [scenario_id, placement_id])
			continue
		var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
		if String(local_army.get("id", "")) != String(contract.get("local_army_id", "")) or _stack_counts(local_army) != contract.get("local_stack_counts", {}):
			failures.append("%s placement-local army drifted from its bounded pressure roster" % placement_id)
		var shared_army := ContentService.get_army_group(String(contract.get("shared_army_id", "")))
		if String(shared_army.get("id", "")) != String(contract.get("shared_army_id", "")) or _stack_counts(shared_army) != contract.get("shared_stack_counts", {}):
			failures.append("%s changed with the placement-local correction" % contract.get("shared_army_id", ""))
		var sample := BalanceHarness.run_battle_sample(String(scenario_id), encounter, 72, "normal")
		payload["samples"].append(_compact_sample(String(scenario_id), placement_id, sample))
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
			failures.append("%s no longer resolves as a bounded player victory" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
			continue
		var round_reached := int(sample.get("round_reached", 0))
		if round_reached < MIN_ROUND or round_reached > MAX_ROUND:
			failures.append("%s left its bounded battle-pacing window" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
		elif int(sample.get("terminal_health_margin_pct", 100)) > MAX_TERMINAL_MARGIN_PCT:
			failures.append("%s remains in the high-priority terminal-margin band" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
		elif int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
			failures.append("%s does not apply meaningful enemy pressure" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
	if not failures.is_empty():
		payload["failures"] = failures
		payload["turn_logs"] = failed_turn_logs
		_fail("Reedbarrow and Mireford guard pressure regression failed.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(scenario_id: String, placement_id: String) -> Dictionary:
	for encounter in ContentService.get_scenario(scenario_id).get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _compact_sample(scenario_id: String, placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": scenario_id,
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
