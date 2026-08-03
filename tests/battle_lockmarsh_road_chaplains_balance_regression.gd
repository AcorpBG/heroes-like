extends Node

const BalanceHarness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_LOCKMARSH_ROAD_CHAPLAINS_BALANCE_REGRESSION"
const SCENARIO_ID := "lockmarsh-surge"
const PLACEMENT_IDS := [
	"surge_road_chaplains",
	"surge_charter_guard",
	"lockmarsh_archive_wardens",
]
const LOCAL_ARMY_CONTRACTS := {
	"surge_road_chaplains": {
		"army_id": "army_lockmarsh_road_chaplains_watch",
		"stack_counts": {"unit_river_guard": 9, "unit_ember_archer": 10, "unit_citadel_pikeward": 6},
	},
	"surge_charter_guard": {
		"army_id": "army_lockmarsh_charter_guard_watch",
		"stack_counts": {"unit_river_guard": 7, "unit_ember_archer": 6, "unit_citadel_pikeward": 2},
	},
	"lockmarsh_archive_wardens": {
		"army_id": "army_lockmarsh_archive_wardens_watch",
		"stack_counts": {"unit_river_guard": 7, "unit_ember_archer": 9, "unit_citadel_pikeward": 2},
	},
}
const UNCHANGED_SAMPLE_CONTRACTS := {
	"surge_charter_guard": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 65, "enemy_damage_per_round": 17},
	"lockmarsh_archive_wardens": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 70, "enemy_damage_per_round": 19},
}
const SHARED_ARMY_CONTRACTS := {
	"army_riverwatch_relief": {"unit_river_guard": 8, "unit_ember_archer": 6},
	"army_charter_bastion_reserve": {"unit_river_guard": 6, "unit_ember_archer": 4, "unit_citadel_pikeward": 2},
	"army_archive_wardens": {"unit_river_guard": 7, "unit_ember_archer": 7, "unit_citadel_pikeward": 2},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	var failures := []
	for army_id in SHARED_ARMY_CONTRACTS:
		var shared_army := ContentService.get_army_group(String(army_id))
		if String(shared_army.get("id", "")) != army_id or _stack_counts(shared_army) != SHARED_ARMY_CONTRACTS[army_id]:
			failures.append("%s changed with the Lockmarsh placement-local correction" % army_id)
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(String(placement_id))
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		if LOCAL_ARMY_CONTRACTS.has(placement_id):
			var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
			var contract: Dictionary = LOCAL_ARMY_CONTRACTS[placement_id]
			if String(local_army.get("id", "")) != String(contract.get("army_id", "")) or _stack_counts(local_army) != contract.get("stack_counts", {}):
				failures.append("%s placement-local army drifted from its bounded pressure roster" % placement_id)
		var sample := BalanceHarness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(String(placement_id), sample))
		if placement_id == "surge_road_chaplains":
			var profile: Dictionary = sample.get("initial_stack_profile", {})
			var round_reached := int(sample.get("round_reached", 0))
			var enemy_dpr := int(sample.get("damage_per_round", {}).get("enemy", 0))
			if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "defeat" or not String(sample.get("pacing_band", "")) in ["standard", "extended"]:
				failures.append("Road Chaplains do not resolve as a bounded defeat")
			if int(profile.get("player_enemy_power_ratio_pct", 0)) < 60 or round_reached < 3 or round_reached > 8 or int(sample.get("terminal_health_margin_pct", 100)) > 65 or enemy_dpr > 50:
				failures.append("Road Chaplains remain outside their matchup, pacing, or pressure target")
		else:
			var expected: Dictionary = UNCHANGED_SAMPLE_CONTRACTS[placement_id]
			if String(sample.get("outcome_state", "")) != String(expected.get("outcome_state", "")) or String(sample.get("pacing_band", "")) != String(expected.get("pacing_band", "")) or int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
				failures.append("%s changed outside the Road Chaplains correction" % placement_id)
	if not failures.is_empty():
		payload["failures"] = failures
		_fail("Lockmarsh Surge balance regression failed.", payload)
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
