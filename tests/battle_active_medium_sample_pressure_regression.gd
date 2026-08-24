extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_ACTIVE_MEDIUM_SAMPLE_PRESSURE_REGRESSION"
const CASES := [
	{
		"scenario_id": "bellwake-wreck-claim",
		"placement_id": "bellwake_mirror_lancers",
		"army_id": "army_bellwake_mirror_lancers_watch",
		"counts": {"unit_shard_guard": 9, "unit_prism_adept": 8, "unit_mirror_duelist": 8, "unit_sunvault_resonant_choristers": 5},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 40, "enemy_damage_per_round": 49},
	},
	{
		"scenario_id": "ironbridge-stand",
		"placement_id": "bridge_ford_reavers",
		"army_id": "army_ironbridge_ford_reavers_watch",
		"counts": {"unit_blackbranch_cutthroat": 10, "unit_mire_slinger": 12, "unit_bog_brute": 3},
		"expected": {"outcome_state": "victory", "matchup_band": "even", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 67, "enemy_damage_per_round": 13},
	},
	{
		"scenario_id": "ironbridge-stand",
		"placement_id": "ironbridge_reed_totemists",
		"army_id": "army_ironbridge_reed_totemists_watch",
		"counts": {"unit_mire_slinger": 10, "unit_blackbranch_cutthroat": 6, "unit_gorefen_ripper": 3},
		"expected": {"outcome_state": "victory", "matchup_band": "even", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 72, "enemy_damage_per_round": 14},
	},
	{
		"scenario_id": "orevein-contract",
		"placement_id": "orevein_bridgeward_levies",
		"army_id": "army_orevein_bridgeward_levies",
		"counts": {"unit_river_guard": 5, "unit_citadel_pikeward": 4, "unit_ember_archer": 6},
		"expected": {"outcome_state": "victory", "matchup_band": "player_advantaged", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 74, "enemy_damage_per_round": 18},
	},
	{
		"scenario_id": "ninefold-confluence",
		"placement_id": "ninefold_basalt_gatehouse_watch",
		"army_id": "army_ninefold_basalt_gatehouse_watch",
		"counts": {"unit_neutral_basalt_wardens": 11, "unit_neutral_tunnelmark_bolters": 6},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 59, "enemy_damage_per_round": 31},
	},
	{
		"scenario_id": "ninefold-confluence",
		"placement_id": "ninefold_drowned_reliquary_watch",
		"army_id": "army_ninefold_drowned_reliquary_watch",
		"counts": {"unit_neutral_tidepool_cutters": 6, "unit_neutral_reefbolt_crews": 11},
		"expected": {"outcome_state": "victory", "matchup_band": "even", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 68, "enemy_damage_per_round": 12},
	},
	{
		"scenario_id": "stonewake-watch",
		"placement_id": "sluice_band",
		"army_id": "army_stonewake_sluice_band",
		"counts": {"unit_mire_slinger": 6, "unit_blackbranch_cutthroat": 5, "unit_gorefen_ripper": 1},
		"expected": {"outcome_state": "victory", "matchup_band": "player_advantaged", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 74, "enemy_damage_per_round": 18},
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
		if String(local_army.get("id", "")) != String(case.get("army_id", "")) or _stack_counts(local_army) != case.get("counts", {}):
			failures.append("%s/%s placement-local army drifted" % [scenario_id, placement_id])
		var sample := Harness.run_battle_sample(scenario_id, encounter, 72, "normal")
		rows.append(_compact_sample(scenario_id, placement_id, sample))
		if not bool(sample.get("completed", false)):
			failures.append("%s/%s did not complete" % [scenario_id, placement_id])
		if not _sample_matches(sample, case.get("expected", {})):
			failures.append("%s/%s deterministic sample contract drifted" % [scenario_id, placement_id])
		if not String(sample.get("pacing_band", "")) in ["standard", "extended"]:
			failures.append("%s/%s remains outside bounded pacing" % [scenario_id, placement_id])
		if int(sample.get("terminal_health_margin_pct", 100)) >= 75:
			failures.append("%s/%s remains above the sample margin threshold" % [scenario_id, placement_id])
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

func _sample_matches(sample: Dictionary, expected: Dictionary) -> bool:
	return (
		String(sample.get("outcome_state", "")) == String(expected.get("outcome_state", ""))
		and String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) == String(expected.get("matchup_band", ""))
		and String(sample.get("pacing_band", "")) == String(expected.get("pacing_band", ""))
		and int(sample.get("round_reached", 0)) == int(expected.get("round_reached", -1))
		and int(sample.get("terminal_health_margin_pct", -1)) == int(expected.get("terminal_health_margin_pct", -1))
		and int(sample.get("damage_per_round", {}).get("enemy", -1)) == int(expected.get("enemy_damage_per_round", -1))
	)

func _compact_sample(scenario_id: String, placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"placement_id": placement_id,
		"outcome_state": String(sample.get("outcome_state", "")),
		"matchup_band": String(sample.get("initial_stack_profile", {}).get("matchup_band", "")),
		"pacing_band": String(sample.get("pacing_band", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"enemy_damage_per_round": int(sample.get("damage_per_round", {}).get("enemy", 0)),
	}
