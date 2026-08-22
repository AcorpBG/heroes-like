extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_ACTIVE_OUTCOME_DIVERSITY_CLEAR_REGRESSION"
const CASES := [
	{
		"scenario_id": "reedbarrow-ferry",
		"placement_id": "barrow_pickets",
		"army_id": "army_reedbarrow_barrow_pickets_watch",
		"counts": {"unit_blackbranch_cutthroat": 15, "unit_mire_slinger": 8},
		"expected": {"outcome_state": "victory", "matchup_band": "player_disadvantaged", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 68, "enemy_damage_per_round": 7},
		"shared_army_id": "army_barrow_pickets",
		"shared_counts": {"unit_blackbranch_cutthroat": 14, "unit_mire_slinger": 9},
	},
	{
		"scenario_id": "charter-pyre",
		"placement_id": "charter_granary_levies",
		"army_id": "army_charter_granary_levies_watch",
		"counts": {"unit_river_guard": 11, "unit_ember_archer": 8, "unit_citadel_pikeward": 2},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 29, "enemy_damage_per_round": 47},
		"shared_army_id": "army_highwater_militia",
		"shared_counts": {"unit_river_guard": 11, "unit_ember_archer": 4, "unit_citadel_pikeward": 1},
	},
	{
		"scenario_id": "prismhearth-watch",
		"placement_id": "prismhearth_halo_reserve",
		"army_id": "army_prismhearth_halo_reserve_watch",
		"counts": {"unit_shard_guard": 5, "unit_prism_adept": 2, "unit_mirror_duelist": 2, "unit_aurora_ballista": 2},
		"expected": {"outcome_state": "defeat", "matchup_band": "player_advantaged", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 32, "enemy_damage_per_round": 28},
		"shared_army_id": "army_halo_reserve",
		"shared_counts": {"unit_shard_guard": 6, "unit_prism_adept": 4, "unit_mirror_duelist": 3, "unit_aurora_ballista": 1},
	},
	{
		"scenario_id": "glassroad-sundering",
		"placement_id": "glassroad_archive_wardens",
		"army_id": "army_glassroad_archive_line_watch",
		"counts": {"unit_river_guard": 5, "unit_ember_archer": 7, "unit_citadel_pikeward": 3},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 35, "enemy_damage_per_round": 24},
		"shared_army_id": "army_archive_wardens",
		"shared_counts": {"unit_river_guard": 7, "unit_ember_archer": 7, "unit_citadel_pikeward": 2},
	},
	{
		"scenario_id": "daybreak-spire",
		"placement_id": "daybreak_array",
		"army_id": "army_daybreak_array_watch",
		"counts": {"unit_shard_guard": 6, "unit_prism_adept": 2, "unit_mirror_duelist": 1, "unit_aurora_ballista": 1},
		"expected": {"outcome_state": "defeat", "matchup_band": "player_advantaged", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 57, "enemy_damage_per_round": 29},
		"shared_army_id": "army_daybreak_array",
		"shared_counts": {"unit_shard_guard": 6, "unit_prism_adept": 6, "unit_mirror_duelist": 3, "unit_aurora_ballista": 2},
	},
	{
		"scenario_id": "mireford-skirmish",
		"placement_id": "bridge_ford_reavers",
		"army_id": "army_mireford_ford_reavers_watch",
		"counts": {"unit_blackbranch_cutthroat": 15, "unit_mire_slinger": 11, "unit_mireclaw_gorefen_rippers": 2},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "extended", "round_reached": 7, "terminal_health_margin_pct": 7, "enemy_damage_per_round": 42},
		"shared_army_id": "army_ford_reavers",
		"shared_counts": {"unit_blackbranch_cutthroat": 13, "unit_mire_slinger": 8},
	},
	{
		"scenario_id": "bellwake-wreck-claim",
		"placement_id": "bellwake_mirror_lancers",
		"army_id": "army_bellwake_mirror_lancers_watch",
		"counts": {"unit_shard_guard": 9, "unit_prism_adept": 8, "unit_mirror_duelist": 8, "unit_sunvault_resonant_choristers": 5},
		"expected": {"outcome_state": "defeat", "matchup_band": "even", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 40, "enemy_damage_per_round": 49},
		"shared_army_id": "army_mirror_lancers",
		"shared_counts": {"unit_mirror_duelist": 6, "unit_shard_guard": 4, "unit_prism_adept": 4},
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
		var shared_army := ContentService.get_army_group(String(case.get("shared_army_id", "")))
		if _stack_counts(shared_army) != case.get("shared_counts", {}):
			failures.append("%s shared army changed with local tuning" % String(case.get("shared_army_id", "")))
		var sample := Harness.run_battle_sample(scenario_id, encounter, 72, "normal")
		rows.append(_compact_sample(scenario_id, placement_id, sample))
		var expected: Dictionary = case.get("expected", {})
		if not bool(sample.get("completed", false)) or not _sample_matches(sample, expected):
			failures.append("%s/%s did not produce its required bounded outcome" % [scenario_id, placement_id])
		if not String(sample.get("pacing_band", "")) in ["standard", "extended"] or int(sample.get("terminal_health_margin_pct", 100)) >= 75:
			failures.append("%s/%s remains outside bounded pacing or margin" % [scenario_id, placement_id])
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
