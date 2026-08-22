extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_CAUSEWAY_REED_CAMP_PRODUCTION_LINE_REPORT"
const SCENARIO_ID := "causeway-stand"
const PLACEMENT_ID := "causeway_reed_camp"
const PRODUCTION_STACKS := [
	{"unit_id": "unit_mireclaw_reedsnare_kin", "count": 7},
	{"unit_id": "unit_mireclaw_mudglass_slingers", "count": 4},
	{"unit_id": "unit_mireclaw_bogplate_maulers", "count": 1},
]
const LEGACY_STACKS := [
	{"unit_id": "unit_blackbranch_cutthroat", "count": 7},
	{"unit_id": "unit_mire_slinger", "count": 4},
	{"unit_id": "unit_bog_brute", "count": 1},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var scenario_authority_before: Dictionary = scenario.duplicate(true)
	var encounter := _scenario_encounter(scenario, PLACEMENT_ID)
	var enemy_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if (
		String(encounter.get("encounter_id", "")) != "encounter_reedward_camp"
		or String(encounter.get("difficulty", "")) != "medium"
		or int(encounter.get("combat_seed", 0)) != 2201
		or Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) != Vector2i(4, 1)
		or String(enemy_army.get("id", "")) != "army_causeway_reed_camp_pickets"
		or String(enemy_army.get("faction_id", "")) != "faction_mireclaw"
		or _stack_contract(enemy_army.get("stacks", [])) != PRODUCTION_STACKS
	):
		_fail("Causeway Reed Camp production encounter identity drifted.", {"encounter": encounter})
		return
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_CAMPAIGN)
	if session == null:
		_fail("Causeway Reed Camp could not create a live campaign session.", {})
		return
	OverworldRules.normalize_overworld_state(session)
	var session_authority_before: Dictionary = session.to_dict()
	var battle_payload: Dictionary = BattleRules.create_battle_payload(session, encounter)
	if session.to_dict() != session_authority_before:
		_fail("Public battle payload mutated the Causeway session.", {})
		return
	var expected_abilities := {
		"unit_mireclaw_reedsnare_kin": ["harry"],
		"unit_mireclaw_mudglass_slingers": ["harry"],
		"unit_mireclaw_bogplate_maulers": ["shielding"],
	}
	if _battle_enemy_stack_contract(battle_payload) != PRODUCTION_STACKS or _battle_enemy_ability_contract(battle_payload) != expected_abilities:
		_fail("Public battle payload missed the exact production Mireclaw line.", {"stacks": _battle_enemy_stack_contract(battle_payload), "abilities": _battle_enemy_ability_contract(battle_payload)})
		return
	if _stack_health(PRODUCTION_STACKS) != 107 or _stack_health(LEGACY_STACKS) != 93:
		_fail("Causeway production/legacy stack-health contract drifted.", {})
		return
	var legacy_encounter: Dictionary = encounter.duplicate(true)
	legacy_encounter["placement_id"] = "%s:legacy_control" % PLACEMENT_ID
	var legacy_army: Dictionary = enemy_army.duplicate(true)
	legacy_army["id"] = "army_causeway_reed_camp_legacy_control"
	legacy_army["stacks"] = LEGACY_STACKS.duplicate(true)
	legacy_encounter["enemy_army"] = legacy_army
	var production_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var production_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "hard")
	var legacy_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "normal")
	var legacy_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "hard")
	if (
		not _sample_exact(production_normal, "victory", "player_advantaged", "standard", 3, 73, 0, 11)
		or not _sample_exact(production_hard, "victory", "player_advantaged", "standard", 3, 70, 0, 7)
		or not _sample_exact(legacy_normal, "victory", "player_advantaged", "standard", 3, 72, 0, 12)
		or not _sample_exact(legacy_hard, "victory", "player_advantaged", "standard", 3, 72, 0, 12)
		or scenario != scenario_authority_before
	):
		_fail("Causeway production or independent legacy battle contract drifted.", {"production_normal": _compact_sample(production_normal), "production_hard": _compact_sample(production_hard), "legacy_normal": _compact_sample(legacy_normal), "legacy_hard": _compact_sample(legacy_hard)})
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"production_stacks": PRODUCTION_STACKS.duplicate(true),
		"legacy_stacks": LEGACY_STACKS.duplicate(true),
		"production_health": 107,
		"legacy_health": 93,
		"production_normal": _compact_sample(production_normal),
		"production_hard": _compact_sample(production_hard),
		"legacy_normal": _compact_sample(legacy_normal),
		"legacy_hard": _compact_sample(legacy_hard),
		"public_abilities": expected_abilities,
		"scenario_authority_exact": true,
		"session_authority_exact": true,
	})])
	get_tree().quit(0)

func _scenario_encounter(scenario: Dictionary, placement_id: String) -> Dictionary:
	for encounter_value in scenario.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _stack_contract(stacks_value: Variant) -> Array:
	var result: Array = []
	var stacks: Array = stacks_value if stacks_value is Array else []
	for stack_value in stacks:
		if stack_value is Dictionary:
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("count", 0))})
	return result

func _stack_health(stacks: Array) -> int:
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
		if not stack_value is Dictionary or String(stack_value.get("side", "")) != "enemy":
			continue
		var ability_ids: Array = []
		for ability_value in stack_value.get("abilities", []):
			if ability_value is Dictionary:
				ability_ids.append(String(ability_value.get("id", "")))
		ability_ids.sort()
		result[String(stack_value.get("unit_id", ""))] = ability_ids
	return result

func _sample_exact(sample: Dictionary, outcome: String, matchup: String, pacing: String, rounds: int, player_health: int, enemy_health: int, enemy_damage_per_round: int) -> bool:
	return (
		bool(sample.get("completed", false))
		and String(sample.get("outcome_state", "")) == outcome
		and String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) == matchup
		and String(sample.get("pacing_band", "")) == pacing
		and int(sample.get("round_reached", 0)) == rounds
		and int(sample.get("player_health_remaining_pct", -1)) == player_health
		and int(sample.get("enemy_health_remaining_pct", -1)) == enemy_health
		and int(sample.get("damage_per_round", {}).get("enemy", -1)) == enemy_damage_per_round
		and int(sample.get("invalid_order_count", -1)) == 0
	)

func _compact_sample(sample: Dictionary) -> Dictionary:
	return {
		"outcome": String(sample.get("outcome_state", "")),
		"matchup_band": String(sample.get("initial_stack_profile", {}).get("matchup_band", "")),
		"pacing_band": String(sample.get("pacing_band", "")),
		"rounds": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", -1)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", -1)),
		"enemy_damage_per_round": int(sample.get("damage_per_round", {}).get("enemy", -1)),
		"invalid_order_count": int(sample.get("invalid_order_count", -1)),
	}

func _fail(message: String, details: Dictionary) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "details": details})])
	get_tree().quit(1)
