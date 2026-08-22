extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_BOGBOUND_ARCHIVE_WARDENS_BALANCE_REGRESSION"
const SCENARIO_ID := "bogbound-oath"
const PLACEMENT_IDS := ["bogbound_lantern_patrol", "bogbound_survey_guard", "bogbound_archive_wardens"]
const LOCAL_ARMY_ID := "army_bogbound_archive_wardens_watch"
const LOCAL_STACK_COUNTS := {"unit_river_guard": 8, "unit_ember_archer": 12, "unit_citadel_pikeward": 6}
const SHARED_ARMY_ID := "army_archive_wardens"
const SHARED_STACK_COUNTS := {"unit_river_guard": 7, "unit_ember_archer": 7, "unit_citadel_pikeward": 2}
const UNCHANGED_SAMPLE_CONTRACTS := {
	"bogbound_lantern_patrol": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 71, "enemy_damage_per_round": 8},
	"bogbound_survey_guard": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 33, "enemy_damage_per_round": 25},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	var shared_army := ContentService.get_army_group(SHARED_ARMY_ID)
	if _stack_counts(shared_army) != SHARED_STACK_COUNTS:
		failures.append("Shared Archive Wardens changed with the Bogbound placement-local correction")
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(placement_id)
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		if placement_id == "bogbound_archive_wardens":
			var local_army: Dictionary = encounter.get("enemy_army", {})
			if String(local_army.get("id", "")) != LOCAL_ARMY_ID or _stack_counts(local_army) != LOCAL_STACK_COUNTS:
				failures.append("Bogbound Archive Wardens placement-local army drifted")
		var sample := Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(placement_id, sample))
		if placement_id == "bogbound_archive_wardens":
			if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "defeat" or not String(sample.get("pacing_band", "")) in ["standard", "extended"]:
				failures.append("Bogbound Archive Wardens are not a bounded defeat")
			var profile: Dictionary = sample.get("initial_stack_profile", {})
			var enemy_dpr := int(sample.get("damage_per_round", {}).get("enemy", 0))
			var round_reached := int(sample.get("round_reached", 0))
			if String(profile.get("matchup_band", "")) != "player_disadvantaged" or int(profile.get("player_enemy_power_ratio_pct", 0)) < 60 or round_reached < 3 or round_reached > 8 or int(sample.get("terminal_health_margin_pct", 100)) > 65 or enemy_dpr > 50:
				failures.append("Bogbound Archive Wardens remain outside their matchup, pacing, or pressure target")
		else:
			var expected: Dictionary = UNCHANGED_SAMPLE_CONTRACTS[placement_id]
			if String(sample.get("outcome_state", "")) != String(expected.get("outcome_state", "")) or String(sample.get("pacing_band", "")) != String(expected.get("pacing_band", "")) or int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
				failures.append("%s changed outside the Archive Wardens correction" % placement_id)
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
