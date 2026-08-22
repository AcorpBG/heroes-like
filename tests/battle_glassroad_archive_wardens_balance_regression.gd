extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_GLASSROAD_ARCHIVE_WARDENS_BALANCE_REGRESSION"
const SCENARIO_ID := "glassroad-sundering"
const PLACEMENT_IDS := ["glassroad_archive_wardens", "glassroad_bridgeward_levies", "glassroad_beacon_wardens"]
const LOCAL_STACK_COUNTS := {"unit_river_guard": 5, "unit_ember_archer": 7, "unit_citadel_pikeward": 3}
const SHARED_STACK_COUNTS := {"unit_river_guard": 7, "unit_ember_archer": 7, "unit_citadel_pikeward": 2}
const UNCHANGED_SAMPLE_CONTRACTS := {
	"glassroad_bridgeward_levies": {"outcome_state": "defeat", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 44, "enemy_damage_per_round": 24},
	"glassroad_beacon_wardens": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 4, "terminal_health_margin_pct": 39, "enemy_damage_per_round": 22},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var failures := []
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": []}
	if _stack_counts(ContentService.get_army_group("army_archive_wardens")) != SHARED_STACK_COUNTS:
		failures.append("army_archive_wardens changed with the placement-local correction")
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(placement_id)
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		if placement_id == "glassroad_archive_wardens":
			var local_army: Dictionary = encounter.get("enemy_army", {})
			if String(local_army.get("id", "")) != "army_glassroad_archive_line_watch" or _stack_counts(local_army) != LOCAL_STACK_COUNTS:
				failures.append("Glassroad Archive Wardens placement-local army drifted")
		var sample := Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(placement_id, sample))
		if placement_id == "glassroad_archive_wardens":
			var round_reached := int(sample.get("round_reached", 0))
			var enemy_dpr := int(sample.get("damage_per_round", {}).get("enemy", 0))
			if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "defeat" or not String(sample.get("pacing_band", "")) in ["standard", "extended"] or round_reached < 3 or round_reached > 8 or int(sample.get("terminal_health_margin_pct", 100)) > 74 or enemy_dpr <= 2 or enemy_dpr > 50:
				failures.append("Glassroad Archive Wardens remains outside its pacing and pressure target")
		else:
			var expected: Dictionary = UNCHANGED_SAMPLE_CONTRACTS[placement_id]
			if String(sample.get("outcome_state", "")) != String(expected.get("outcome_state", "")) or String(sample.get("pacing_band", "")) != String(expected.get("pacing_band", "")) or int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)) or int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)) or int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
				failures.append("%s changed outside the Archive Wardens correction" % placement_id)
	if not failures.is_empty():
		payload["ok"] = false
		payload["failures"] = failures
		_fail("Glassroad Archive Wardens balance regression failed.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(placement_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _compact_sample(placement_id: String, sample: Dictionary) -> Dictionary:
	return {"placement_id": placement_id, "outcome_state": sample.get("outcome_state", ""), "pacing_band": sample.get("pacing_band", ""), "round_reached": sample.get("round_reached", 0), "terminal_health_margin_pct": sample.get("terminal_health_margin_pct", 0), "damage_per_round": sample.get("damage_per_round", {}), "initial_stack_profile": sample.get("initial_stack_profile", {})}

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
