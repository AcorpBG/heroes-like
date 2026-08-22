extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_POST_IDENTITY_ACTIVE_OUTLIER_REGRESSION"
const GLASSFEN_PRODUCTION_STACKS := [
	{"unit_id": "unit_sunvault_shard_wardens", "count": 6},
	{"unit_id": "unit_sunvault_prism_adepts", "count": 2},
	{"unit_id": "unit_sunvault_mirror_duelists", "count": 1},
]
const GLASSFEN_LEGACY_STACKS := [
	{"unit_id": "unit_shard_guard", "count": 6},
	{"unit_id": "unit_prism_adept", "count": 2},
	{"unit_id": "unit_mirror_duelist", "count": 1},
]
const CASES := [
	{
		"scenario_id": "glassfen-breakers",
		"placement_id": "glassfen_relay_pickets",
		"local_army_id": "army_glassfen_relay_pickets_watch",
		"local_counts": {"unit_sunvault_shard_wardens": 6, "unit_sunvault_prism_adepts": 2, "unit_sunvault_mirror_duelists": 1},
		"shared_army_id": "army_relay_pickets",
		"shared_counts": {"unit_shard_guard": 5, "unit_prism_adept": 2},
		"matchup_band": "player_advantaged",
		"expected": {"round_reached": 4, "terminal_health_margin_pct": 70, "enemy_damage_per_round": 6},
	},
	{
		"scenario_id": "ninefold-confluence",
		"placement_id": "ninefold_drowned_reliquary_watch",
		"local_army_id": "army_ninefold_drowned_reliquary_watch",
		"local_counts": {"unit_neutral_tidepool_cutters": 6, "unit_neutral_reefbolt_crews": 11},
		"shared_army_id": "army_neutral_tidepool_skiffyard_watch",
		"shared_counts": {"unit_neutral_tidepool_cutters": 7, "unit_neutral_reefbolt_crews": 2},
		"matchup_band": "even",
		"expected": {"round_reached": 4, "terminal_health_margin_pct": 68, "enemy_damage_per_round": 12},
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
		var encounter_authority_before: Dictionary = encounter.duplicate(true)
		var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
		if String(local_army.get("id", "")) != String(case.get("local_army_id", "")) or _stack_counts(local_army) != case.get("local_counts", {}):
			failures.append("%s/%s placement-local army drifted" % [scenario_id, placement_id])
		if placement_id == "glassfen_relay_pickets":
			_validate_glassfen_production_line(encounter, local_army, failures, rows)
		var shared_army := ContentService.get_army_group(String(case.get("shared_army_id", "")))
		if String(shared_army.get("id", "")) != String(case.get("shared_army_id", "")) or _stack_counts(shared_army) != case.get("shared_counts", {}):
			failures.append("%s shared army changed with local tuning" % String(case.get("shared_army_id", "")))
		var sample := Harness.run_battle_sample(scenario_id, encounter, 72, "normal")
		var row := _compact_sample(scenario_id, placement_id, sample)
		rows.append(row)
		var expected: Dictionary = case.get("expected", {})
		if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
			failures.append("%s/%s must remain a completed player victory" % [scenario_id, placement_id])
		if String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) != String(case.get("matchup_band", "")):
			failures.append("%s/%s matchup band drifted" % [scenario_id, placement_id])
		if int(sample.get("round_reached", 0)) != int(expected.get("round_reached", -1)):
			failures.append("%s/%s round contract drifted" % [scenario_id, placement_id])
		if int(sample.get("terminal_health_margin_pct", -1)) != int(expected.get("terminal_health_margin_pct", -1)):
			failures.append("%s/%s terminal margin contract drifted" % [scenario_id, placement_id])
		if int(sample.get("damage_per_round", {}).get("enemy", -1)) != int(expected.get("enemy_damage_per_round", -1)):
			failures.append("%s/%s pressure contract drifted" % [scenario_id, placement_id])
		if placement_id == "glassfen_relay_pickets" and (
			int(sample.get("invalid_order_count", -1)) != 0
			or int(sample.get("player_health_remaining_pct", -1)) != 70
			or int(sample.get("enemy_health_remaining_pct", -1)) != 0
			or String(sample.get("pacing_band", "")) != "standard"
		):
			failures.append("glassfen-breakers/glassfen_relay_pickets left its exact production sample contract")
		if int(sample.get("terminal_health_margin_pct", 100)) > 90 or int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
			failures.append("%s/%s reopened a high-priority pressure outlier" % [scenario_id, placement_id])
		if encounter != encounter_authority_before:
			failures.append("%s/%s runtime controls mutated the authored encounter" % [scenario_id, placement_id])
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

func _validate_glassfen_production_line(encounter: Dictionary, enemy_army: Dictionary, failures: Array, rows: Array) -> void:
	var field_objectives: Array = encounter.get("field_objectives", []) if encounter.get("field_objectives", []) is Array else []
	if (
		String(encounter.get("encounter_id", "")) != "encounter_relay_pickets"
		or String(encounter.get("difficulty", "")) != "medium"
		or int(encounter.get("combat_seed", 0)) != 14201
		or Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) != Vector2i(4, 1)
		or String(enemy_army.get("id", "")) != "army_glassfen_relay_pickets_watch"
		or String(enemy_army.get("faction_id", "")) != "faction_sunvault"
		or _army_stack_contract(enemy_army.get("stacks", [])) != GLASSFEN_PRODUCTION_STACKS
		or field_objectives.size() != 2
		or String(field_objectives[0].get("id", "")) != "relay_kill_lane"
		or String(field_objectives[1].get("id", "")) != "relay_signal_beacon"
	):
		failures.append("Glassfen Relay Pickets production encounter identity or objective authority drifted")
		return
	var payload_session = ScenarioFactory.create_session("glassfen-breakers", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(payload_session)
	var payload_authority_before: Dictionary = payload_session.to_dict()
	var battle_payload: Dictionary = BattleRules.create_battle_payload(payload_session, encounter)
	if payload_session.to_dict() != payload_authority_before:
		failures.append("Glassfen Relay Pickets public battle payload mutated its source session")
	var expected_abilities := {
		"unit_sunvault_shard_wardens": ["shielding"],
		"unit_sunvault_prism_adepts": ["volley"],
		"unit_sunvault_mirror_duelists": ["backstab", "reach"],
	}
	if _battle_enemy_stack_contract(battle_payload) != GLASSFEN_PRODUCTION_STACKS:
		failures.append("Glassfen Relay Pickets public battle payload missed exact production base counts")
	if _battle_enemy_ability_contract(battle_payload) != expected_abilities:
		failures.append("Glassfen Relay Pickets public battle payload missed exact production abilities")
	var production_stack_health := _army_stack_health(GLASSFEN_PRODUCTION_STACKS)
	var legacy_stack_health := _army_stack_health(GLASSFEN_LEGACY_STACKS)
	if production_stack_health != 81 or legacy_stack_health != 83:
		failures.append("Glassfen Relay Pickets production/legacy stack-health contract drifted")
	var legacy_encounter: Dictionary = encounter.duplicate(true)
	legacy_encounter["placement_id"] = "glassfen_relay_pickets:legacy_control"
	var legacy_army: Dictionary = enemy_army.duplicate(true)
	legacy_army["id"] = "army_glassfen_relay_pickets_legacy_control"
	legacy_army["stacks"] = GLASSFEN_LEGACY_STACKS.duplicate(true)
	legacy_encounter["enemy_army"] = legacy_army
	var legacy_sample: Dictionary = Harness.run_battle_sample("glassfen-breakers", legacy_encounter, 72, "normal")
	rows.append(_compact_sample("glassfen-breakers", "glassfen_relay_pickets:legacy_control", legacy_sample))
	if (
		not bool(legacy_sample.get("completed", false))
		or String(legacy_sample.get("outcome_state", "")) != "victory"
		or int(legacy_sample.get("round_reached", 0)) != 5
		or int(legacy_sample.get("invalid_order_count", -1)) != 0
		or int(legacy_sample.get("player_health_remaining_pct", -1)) != 69
		or int(legacy_sample.get("enemy_health_remaining_pct", -1)) != 0
		or int(legacy_sample.get("damage_per_round", {}).get("enemy", -1)) != 6
		or String(legacy_sample.get("pacing_band", "")) != "standard"
	):
		failures.append("Glassfen Relay Pickets legacy method control drifted")

func _army_stack_contract(stacks: Array) -> Array:
	var result: Array = []
	for stack_value in stacks:
		if stack_value is Dictionary:
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("count", 0))})
	return result

func _army_stack_health(stacks: Array) -> int:
	var total := 0
	for stack_value in stacks:
		if stack_value is Dictionary:
			var unit: Dictionary = ContentService.get_unit(String(stack_value.get("unit_id", "")))
			total += int(stack_value.get("count", 0)) * int(unit.get("hp", 0))
	return total

func _battle_enemy_stack_contract(battle: Dictionary) -> Array:
	var result: Array = []
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("base_count", 0))})
	return result

func _battle_enemy_ability_contract(battle: Dictionary) -> Dictionary:
	var result := {}
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary) or String(stack_value.get("side", "")) != "enemy":
			continue
		var ability_ids: Array = []
		for ability_value in stack_value.get("abilities", []):
			if ability_value is Dictionary:
				ability_ids.append(String(ability_value.get("id", "")))
		ability_ids.sort()
		result[String(stack_value.get("unit_id", ""))] = ability_ids
	return result

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
