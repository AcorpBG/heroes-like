extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_NINEFOLD_ROUGH_EXACTORS_BALANCE_REGRESSION"
const SCENARIO_ID := "ninefold-confluence"
const EXACTORS_PLACEMENT_ID := "ninefold_orevein_exactors"
const GATEHOUSE_PLACEMENT_ID := "ninefold_basalt_gatehouse_watch"
const MAX_EXACTORS_TERMINAL_MARGIN_PCT := 64
const MAX_ROUGH_COHORT_TERMINAL_MARGIN_PCT := 69
const LOCAL_ARMY_CONTRACTS := {
	EXACTORS_PLACEMENT_ID: {
		"army_id": "army_ninefold_orevein_exactors_watch",
		"stack_counts": {"unit_brasshollow_scrip_haulers": 9, "unit_brasshollow_rivet_hounds": 6, "unit_brasshollow_furnace_pavis_teams": 6},
	},
	GATEHOUSE_PLACEMENT_ID: {
		"army_id": "army_ninefold_basalt_gatehouse_watch",
		"stack_counts": {"unit_neutral_basalt_wardens": 11, "unit_neutral_tunnelmark_bolters": 6},
	},
}
const SHARED_EXACTORS_CONTRACT := {
	"unit_brasshollow_scrip_haulers": 10,
	"unit_brasshollow_rivet_hounds": 7,
	"unit_brasshollow_furnace_pavis_teams": 4,
}
const GATEHOUSE_SAMPLE_CONTRACT := {
	"outcome_state": "defeat",
	"round_reached": 5,
	"terminal_health_margin_pct": 59,
	"enemy_damage_per_round": 31,
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	var shared_army := ContentService.get_army_group("army_orevein_exactors")
	if _stack_counts(shared_army) != SHARED_EXACTORS_CONTRACT:
		failures.append("Shared Orevein Exactors changed with the Ninefold placement-local correction")
	var terminal_margin_total := 0
	for placement_id in [EXACTORS_PLACEMENT_ID, GATEHOUSE_PLACEMENT_ID]:
		var encounter := _encounter(placement_id)
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		var local_army: Dictionary = encounter.get("enemy_army", {})
		var army_contract: Dictionary = LOCAL_ARMY_CONTRACTS[placement_id]
		if String(local_army.get("id", "")) != String(army_contract.get("army_id", "")) or _stack_counts(local_army) != army_contract.get("stack_counts", {}):
			failures.append("%s placement-local army drifted" % placement_id)
		var sample := Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(placement_id, sample))
		terminal_margin_total += int(sample.get("terminal_health_margin_pct", 100))
		if String(sample.get("terrain", "")) != "rough":
			failures.append("%s is no longer a rough-terrain battle" % placement_id)
		if placement_id == EXACTORS_PLACEMENT_ID:
			if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory" or not String(sample.get("pacing_band", "")) in ["standard", "extended"]:
				failures.append("Orevein Exactors is not a bounded player victory")
			if int(sample.get("terminal_health_margin_pct", 100)) > MAX_EXACTORS_TERMINAL_MARGIN_PCT or int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 10:
				failures.append("Orevein Exactors remains outside its pressure target")
		else:
			if String(sample.get("outcome_state", "")) != String(GATEHOUSE_SAMPLE_CONTRACT.get("outcome_state", "")) or int(sample.get("round_reached", 0)) != int(GATEHOUSE_SAMPLE_CONTRACT.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(GATEHOUSE_SAMPLE_CONTRACT.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(GATEHOUSE_SAMPLE_CONTRACT.get("enemy_damage_per_round", -1)):
				failures.append("Basalt Gatehouse changed outside the Exactors correction")
	var cohort_average := terminal_margin_total / 2
	payload["rough_cohort_average_terminal_health_margin_pct"] = cohort_average
	if cohort_average > MAX_ROUGH_COHORT_TERMINAL_MARGIN_PCT:
		failures.append("Rough-terrain cohort remains above its terminal-margin target")
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
		"terrain": sample.get("terrain", ""),
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
