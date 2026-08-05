extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_ACTIVE_COHORT_QUEUE_CLEAR_REGRESSION"
const SCENARIO_PLACEMENTS := {
	"river-pass": ["river_pass_ghoul_grove", "river_pass_hollow_mire", "river_pass_reed_totemists"],
	"bellwake-wreck-claim": ["bellwake_relay_pickets", "bellwake_mirror_lancers", "bellwake_aurora_battery"],
	"fen-crown": ["fen_crown_watch", "bone_ferry", "fen_crown_bone_ferry_watch"],
	"glassfen-breakers": ["glassfen_relay_pickets", "glassfen_glasswing_sortie", "glassfen_aurora_battery"],
	"orevein-contract": ["orevein_archive_wardens", "orevein_bridgeward_levies", "orevein_beacon_wardens"],
	"mireford-skirmish": ["bridge_ford_reavers", "bridge_silt_hunters", "mireford_reed_totemists"],
}
const TARGET_CONTRACTS := {
	"river-pass/river_pass_ghoul_grove": {
		"army_id": "army_river_pass_ghoul_grove_watch",
		"stack_counts": {"unit_blackbranch_cutthroat": 8, "unit_mire_slinger": 16, "unit_bog_brute": 2, "unit_mireclaw_mudglass_slingers": 1},
		"sample": {"outcome_state": "defeat", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 44, "enemy_damage_per_round": 21},
	},
	"river-pass/river_pass_reed_totemists": {
		"army_id": "army_river_pass_reed_totemists_watch",
		"stack_counts": {"unit_mire_slinger": 11, "unit_blackbranch_cutthroat": 7, "unit_gorefen_ripper": 2},
		"sample": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 57, "enemy_damage_per_round": 18},
	},
	"bellwake-wreck-claim/bellwake_mirror_lancers": {
		"army_id": "army_bellwake_mirror_lancers_watch",
		"stack_counts": {"unit_shard_guard": 9, "unit_prism_adept": 6, "unit_mirror_duelist": 9, "unit_sunvault_resonant_choristers": 4},
		"sample": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 38, "enemy_damage_per_round": 37},
	},
	"fen-crown/fen_crown_watch": {
		"army_id": "army_fen_crown_gate_watch",
		"stack_counts": {"unit_bog_brute": 4, "unit_mire_slinger": 5, "unit_blackbranch_cutthroat": 5},
		"sample": {"outcome_state": "defeat", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 39, "enemy_damage_per_round": 42},
	},
	"glassfen-breakers/glassfen_relay_pickets": {
		"army_id": "army_glassfen_relay_pickets_watch",
		"stack_counts": {"unit_shard_guard": 6, "unit_prism_adept": 2},
		"sample": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 62, "enemy_damage_per_round": 8},
	},
	"orevein-contract/orevein_archive_wardens": {
		"army_id": "army_orevein_archive_wardens_watch",
		"stack_counts": {"unit_river_guard": 11, "unit_ember_archer": 11, "unit_citadel_pikeward": 4},
		"sample": {"outcome_state": "defeat", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 53, "enemy_damage_per_round": 69},
	},
	"mireford-skirmish/bridge_ford_reavers": {
		"army_id": "army_mireford_ford_reavers_watch",
		"stack_counts": {"unit_blackbranch_cutthroat": 13, "unit_mire_slinger": 11, "unit_mireclaw_gorefen_rippers": 2},
		"sample": {"outcome_state": "victory", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 9, "enemy_damage_per_round": 45},
	},
}
const CONTROL_SAMPLE_CONTRACTS := {
	"river-pass/river_pass_hollow_mire": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 34, "enemy_damage_per_round": 27},
	"bellwake-wreck-claim/bellwake_relay_pickets": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 66, "enemy_damage_per_round": 13},
	"bellwake-wreck-claim/bellwake_aurora_battery": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 43, "enemy_damage_per_round": 33},
	"fen-crown/bone_ferry": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 21, "enemy_damage_per_round": 33},
	"fen-crown/fen_crown_bone_ferry_watch": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 72, "enemy_damage_per_round": 12},
	"glassfen-breakers/glassfen_glasswing_sortie": {"outcome_state": "defeat", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 54, "enemy_damage_per_round": 23},
	"glassfen-breakers/glassfen_aurora_battery": {"outcome_state": "defeat", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 62, "enemy_damage_per_round": 30},
	"orevein-contract/orevein_bridgeward_levies": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 62, "enemy_damage_per_round": 35},
	"orevein-contract/orevein_beacon_wardens": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 65, "enemy_damage_per_round": 27},
	"mireford-skirmish/bridge_silt_hunters": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 66, "enemy_damage_per_round": 30},
	"mireford-skirmish/mireford_reed_totemists": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 59, "enemy_damage_per_round": 32},
}
const SHARED_ARMY_CONTRACTS := {
	"army_blackbranch_raiders": {"unit_blackbranch_cutthroat": 11, "unit_mire_slinger": 6, "unit_bog_brute": 2},
	"army_muckveil_harriers": {"unit_mire_slinger": 10, "unit_blackbranch_cutthroat": 6, "unit_gorefen_ripper": 2},
	"army_mirror_lancers": {"unit_mirror_duelist": 6, "unit_shard_guard": 4, "unit_prism_adept": 4},
	"army_blackfen_gateward": {"unit_bog_brute": 3, "unit_mire_slinger": 4, "unit_blackbranch_cutthroat": 5},
	"army_relay_pickets": {"unit_shard_guard": 5, "unit_prism_adept": 2},
	"army_archive_wardens": {"unit_river_guard": 7, "unit_ember_archer": 7, "unit_citadel_pikeward": 2},
	"army_ford_reavers": {"unit_blackbranch_cutthroat": 13, "unit_mire_slinger": 8},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var failed_turn_logs := {}
	var payload := {"ok": true, "report_id": REPORT_ID, "samples": []}
	for army_id in SHARED_ARMY_CONTRACTS:
		var shared_army := ContentService.get_army_group(String(army_id))
		if String(shared_army.get("id", "")) != army_id or _stack_counts(shared_army) != SHARED_ARMY_CONTRACTS[army_id]:
			failures.append("%s changed with placement-local cohort tuning" % army_id)
	for scenario_id in SCENARIO_PLACEMENTS:
		var scenario := ContentService.get_scenario(String(scenario_id))
		for placement_id in SCENARIO_PLACEMENTS[scenario_id]:
			var case_id := "%s/%s" % [scenario_id, placement_id]
			var encounter := _encounter(scenario, String(placement_id))
			if encounter.is_empty():
				failures.append("%s is missing" % case_id)
				continue
			var expected: Dictionary
			if TARGET_CONTRACTS.has(case_id):
				var target: Dictionary = TARGET_CONTRACTS[case_id]
				var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
				if String(local_army.get("id", "")) != String(target.get("army_id", "")) or _stack_counts(local_army) != target.get("stack_counts", {}):
					failures.append("%s placement-local army drifted" % case_id)
				expected = target.get("sample", {})
			else:
				expected = CONTROL_SAMPLE_CONTRACTS.get(case_id, {})
			var sample := Harness.run_battle_sample(String(scenario_id), encounter, 72, "normal")
			payload["samples"].append(_compact_sample(String(scenario_id), String(placement_id), sample))
			if expected.is_empty() or not bool(sample.get("completed", false)) or not _sample_matches(sample, expected):
				failures.append("%s drifted from its deterministic cohort contract" % case_id)
				failed_turn_logs[case_id] = sample.get("turn_log", [])
			elif TARGET_CONTRACTS.has(case_id) and not _within_target_bounds(sample):
				failures.append("%s left its bounded outcome target" % case_id)
				failed_turn_logs[case_id] = sample.get("turn_log", [])
	if not failures.is_empty():
		payload["ok"] = false
		payload["failures"] = failures
		payload["turn_logs"] = failed_turn_logs
		push_error("%s failed" % REPORT_ID)
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _within_target_bounds(sample: Dictionary) -> bool:
	var round_reached := int(sample.get("round_reached", 0))
	var enemy_dpr := int(sample.get("damage_per_round", {}).get("enemy", 0))
	return round_reached >= 3 and round_reached <= 8 and int(sample.get("terminal_health_margin_pct", 100)) <= 70 and enemy_dpr > 2 and enemy_dpr <= 70

func _sample_matches(sample: Dictionary, expected: Dictionary) -> bool:
	return (
		String(sample.get("outcome_state", "")) == String(expected.get("outcome_state", ""))
		and String(sample.get("pacing_band", "")) == String(expected.get("pacing_band", ""))
		and int(sample.get("round_reached", 0)) == int(expected.get("round_reached", -1))
		and int(sample.get("terminal_health_margin_pct", -1)) == int(expected.get("terminal_health_margin_pct", -1))
		and int(sample.get("damage_per_round", {}).get("enemy", -1)) == int(expected.get("enemy_damage_per_round", -1))
	)

func _encounter(scenario: Dictionary, placement_id: String) -> Dictionary:
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _compact_sample(scenario_id: String, placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"placement_id": placement_id,
		"outcome_state": sample.get("outcome_state", ""),
		"pacing_band": sample.get("pacing_band", ""),
		"round_reached": sample.get("round_reached", 0),
		"terminal_health_margin_pct": sample.get("terminal_health_margin_pct", 0),
		"damage_per_round": sample.get("damage_per_round", {}),
	}
