extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_POST_IDENTITY_ACTIVE_OUTLIER_REGRESSION"
const CASES := [
	{
		"scenario_id": "glassfen-breakers",
		"placement_id": "glassfen_relay_pickets",
		"local_army_id": "army_glassfen_relay_pickets_watch",
		"local_counts": {"unit_shard_guard": 6, "unit_prism_adept": 2},
		"shared_army_id": "army_relay_pickets",
		"shared_counts": {"unit_shard_guard": 5, "unit_prism_adept": 2},
		"expected": {"round_reached": 4, "terminal_health_margin_pct": 62, "enemy_damage_per_round": 8},
	},
	{
		"scenario_id": "ninefold-confluence",
		"placement_id": "ninefold_drowned_reliquary_watch",
		"local_army_id": "army_ninefold_drowned_reliquary_watch",
		"local_counts": {"unit_neutral_tidepool_cutters": 4, "unit_neutral_reefbolt_crews": 9},
		"shared_army_id": "army_neutral_tidepool_skiffyard_watch",
		"shared_counts": {"unit_neutral_tidepool_cutters": 7, "unit_neutral_reefbolt_crews": 2},
		"expected": {"round_reached": 3, "terminal_health_margin_pct": 85, "enemy_damage_per_round": 8},
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var rows := []
	for case_value in CASES:
		var case: Dictionary = case_value
		var scenario_id := String(case.get("scenario_id", ""))
		var placement_id := String(case.get("placement_id", ""))
		var encounter := _encounter(scenario_id, placement_id)
		if encounter.is_empty():
			failures.append("%s/%s is missing" % [scenario_id, placement_id])
			continue
		var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
		if String(local_army.get("id", "")) != String(case.get("local_army_id", "")) or _stack_counts(local_army) != case.get("local_counts", {}):
			failures.append("%s/%s placement-local army drifted" % [scenario_id, placement_id])
		var shared_army := ContentService.get_army_group(String(case.get("shared_army_id", "")))
		if String(shared_army.get("id", "")) != String(case.get("shared_army_id", "")) or _stack_counts(shared_army) != case.get("shared_counts", {}):
			failures.append("%s shared army changed with local tuning" % String(case.get("shared_army_id", "")))
		var sample := Harness.run_battle_sample(scenario_id, encounter, 72, "normal")
		var row := _compact_sample(scenario_id, placement_id, sample)
		rows.append(row)
		var expected: Dictionary = case.get("expected", {})
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
			failures.append("%s/%s must remain a completed player victory" % [scenario_id, placement_id])
		if String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) != "player_advantaged":
			failures.append("%s/%s must remain player-advantaged" % [scenario_id, placement_id])
		if int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)):
			failures.append("%s/%s round contract drifted" % [scenario_id, placement_id])
		if int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)):
			failures.append("%s/%s terminal margin contract drifted" % [scenario_id, placement_id])
		if int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
			failures.append("%s/%s pressure contract drifted" % [scenario_id, placement_id])
		if int(sample.get("terminal_health_margin_pct", 100)) > 90 or int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
			failures.append("%s/%s reopened a high-priority pressure outlier" % [scenario_id, placement_id])
	var payload := {"ok": failures.is_empty(), "report_id": REPORT_ID, "rows": rows}
	if not failures.is_empty():
		payload["failures"] = failures
		push_error("%s failed" % REPORT_ID)
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(scenario_id: String, placement_id: String) -> Dictionary:
	for encounter_value in ContentService.get_scenario(scenario_id).get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack_value in army.get("stacks", []):
		if stack_value is Dictionary:
			counts[String(stack_value.get("unit_id", ""))] = int(stack_value.get("count", 0))
	return counts

func _compact_sample(scenario_id: String, placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"placement_id": placement_id,
		"outcome_state": String(sample.get("outcome_state", "")),
		"matchup_band": String(sample.get("initial_stack_profile", {}).get("matchup_band", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"enemy_damage_per_round": int(sample.get("damage_per_round", {}).get("enemy", 0)),
	}
