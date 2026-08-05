extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_REEDBARROW_CHAIN_BALANCE_REGRESSION"
const SCENARIO_ID := "reedbarrow-ferry"
const PLACEMENT_IDS := ["barrow_pickets", "reedbarrow_chain", "reedbarrow_levee_totemists"]
const LOCAL_ARMY_CONTRACTS := {
	"barrow_pickets": {
		"army_id": "army_reedbarrow_barrow_pickets_watch",
		"stack_counts": {"unit_blackbranch_cutthroat": 15, "unit_mire_slinger": 10},
	},
	"reedbarrow_chain": {
		"army_id": "army_reedbarrow_chain_watch",
		"stack_counts": {"unit_bog_brute": 5, "unit_mire_slinger": 7, "unit_blackbranch_cutthroat": 5},
	},
}
const SHARED_ARMY_CONTRACTS := {
	"army_barrow_pickets": {"unit_blackbranch_cutthroat": 14, "unit_mire_slinger": 9},
	"army_reedbarrow_chain": {"unit_bog_brute": 6, "unit_mire_slinger": 7, "unit_blackbranch_cutthroat": 5},
	"army_muckveil_harriers": {"unit_mire_slinger": 10, "unit_blackbranch_cutthroat": 6, "unit_gorefen_ripper": 2},
}
const UNCHANGED_SAMPLE_CONTRACTS := {
	"barrow_pickets": {"outcome_state": "victory", "pacing_band": "extended", "round_reached": 7, "terminal_health_margin_pct": 58, "enemy_damage_per_round": 7},
	"reedbarrow_chain": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 17, "enemy_damage_per_round": 21},
	"reedbarrow_levee_totemists": {"outcome_state": "defeat", "pacing_band": "extended", "round_reached": 7, "terminal_health_margin_pct": 30, "enemy_damage_per_round": 18},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	for army_id in SHARED_ARMY_CONTRACTS:
		if _stack_counts(ContentService.get_army_group(String(army_id))) != SHARED_ARMY_CONTRACTS[army_id]:
			failures.append("%s changed with the Reedbarrow placement-local correction" % army_id)
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(placement_id)
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		if LOCAL_ARMY_CONTRACTS.has(placement_id):
			var local_army: Dictionary = encounter.get("enemy_army", {})
			var army_contract: Dictionary = LOCAL_ARMY_CONTRACTS[placement_id]
			if String(local_army.get("id", "")) != String(army_contract.get("army_id", "")) or _stack_counts(local_army) != army_contract.get("stack_counts", {}):
				failures.append("%s placement-local army drifted" % placement_id)
		var sample := Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(placement_id, sample))
		var expected: Dictionary = UNCHANGED_SAMPLE_CONTRACTS[placement_id]
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != String(expected.get("outcome_state", "")) or String(sample.get("pacing_band", "")) != String(expected.get("pacing_band", "")) or int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
			failures.append("%s changed outside the Barrow Pickets correction" % placement_id)
	if not failures.is_empty():
		payload["ok"] = false
		payload["failures"] = failures
		push_error("%s failed" % REPORT_ID)
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(placement_id: String) -> Dictionary:
	for encounter in ContentService.get_scenario(SCENARIO_ID).get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _compact_sample(placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"placement_id": placement_id,
		"outcome_state": sample.get("outcome_state", ""),
		"pacing_band": sample.get("pacing_band", ""),
		"round_reached": sample.get("round_reached", 0),
		"terminal_health_margin_pct": sample.get("terminal_health_margin_pct", 0),
		"damage_per_round": sample.get("damage_per_round", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts
