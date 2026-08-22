extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_BELLWAKE_RELAY_PICKETS_PRODUCTION_LINE_REPORT"
const SCENARIO_ID := "bellwake-wreck-claim"
const PLACEMENT_ID := "bellwake_relay_pickets"
const PRODUCTION_STACKS := [
	{"unit_id": "unit_sunvault_shard_wardens", "count": 9},
	{"unit_id": "unit_sunvault_prism_adepts", "count": 7},
	{"unit_id": "unit_sunvault_mirror_duelists", "count": 8},
]
const LEGACY_STACKS := [
	{"unit_id": "unit_shard_guard", "count": 9},
	{"unit_id": "unit_prism_adept", "count": 7},
	{"unit_id": "unit_mirror_duelist", "count": 8},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var scenario_authority_before: Dictionary = scenario.duplicate(true)
	var encounter := _scenario_encounter(scenario, PLACEMENT_ID)
	var mirror_lancers_before: Dictionary = _scenario_encounter(scenario, "bellwake_mirror_lancers").duplicate(true)
	var aurora_battery_before: Dictionary = _scenario_encounter(scenario, "bellwake_aurora_battery").duplicate(true)
	var enemy_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if (
		String(encounter.get("encounter_id", "")) != "encounter_relay_pickets"
		or String(encounter.get("difficulty", "")) != "medium"
		or int(encounter.get("combat_seed", 0)) != 18201
		or Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) != Vector2i(4, 1)
		or String(enemy_army.get("id", "")) != "army_bellwake_relay_pickets_watch"
		or String(enemy_army.get("faction_id", "")) != "faction_sunvault"
		or _stack_contract(enemy_army.get("stacks", [])) != PRODUCTION_STACKS
		or _guarded_resource_ids(scenario, PLACEMENT_ID) != ["bellwake_memory_salt_pan", "bellwake_wreck_claim_bellwake_harbor_rare_exchange"]
		or not _objective_exact(scenario)
	):
		_fail("Bellwake Relay Pickets production identity or scenario authority drifted.", {"encounter": encounter, "guarded_resources": _guarded_resource_ids(scenario, PLACEMENT_ID)})
		return
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		_fail("Bellwake Relay Pickets could not create a live skirmish session.", {})
		return
	OverworldRules.normalize_overworld_state(session)
	var session_authority_before: Dictionary = session.to_dict()
	var battle_payload: Dictionary = BattleRules.create_battle_payload(session, encounter)
	var expected_abilities := {
		"unit_sunvault_shard_wardens": ["shielding"],
		"unit_sunvault_prism_adepts": ["volley"],
		"unit_sunvault_mirror_duelists": ["backstab", "reach"],
	}
	if session.to_dict() != session_authority_before or _battle_enemy_stack_contract(battle_payload) != PRODUCTION_STACKS or _battle_enemy_ability_contract(battle_payload) != expected_abilities:
		_fail("Public battle payload missed the exact Bellwake production line or mutated the session.", {"stacks": _battle_enemy_stack_contract(battle_payload), "abilities": _battle_enemy_ability_contract(battle_payload)})
		return
	if _stack_health(PRODUCTION_STACKS) != 255 or _stack_health(LEGACY_STACKS) != 211:
		_fail("Bellwake production/legacy stack-health contract drifted.", {})
		return
	var legacy_encounter: Dictionary = encounter.duplicate(true)
	legacy_encounter["placement_id"] = "%s:legacy_control" % PLACEMENT_ID
	var legacy_army: Dictionary = enemy_army.duplicate(true)
	legacy_army["id"] = "army_bellwake_relay_pickets_legacy_control"
	legacy_army["stacks"] = LEGACY_STACKS.duplicate(true)
	legacy_encounter["enemy_army"] = legacy_army
	var production_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var production_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "hard")
	var legacy_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "normal")
	var legacy_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "hard")
	if (
		not _sample_exact(production_normal, 5, 61, 16)
		or not _sample_exact(production_hard, 4, 65, 17)
		or not _sample_exact(legacy_normal, 3, 66, 13)
		or not _sample_exact(legacy_hard, 4, 60, 14)
		or _scenario_encounter(scenario, "bellwake_mirror_lancers") != mirror_lancers_before
		or _scenario_encounter(scenario, "bellwake_aurora_battery") != aurora_battery_before
		or scenario != scenario_authority_before
	):
		_fail("Bellwake production, legacy, adjacent-front, or scenario contract drifted.", {"production_normal": _compact_sample(production_normal), "production_hard": _compact_sample(production_hard), "legacy_normal": _compact_sample(legacy_normal), "legacy_hard": _compact_sample(legacy_hard)})
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"production_stacks": PRODUCTION_STACKS.duplicate(true),
		"legacy_stacks": LEGACY_STACKS.duplicate(true),
		"production_health": 255,
		"legacy_health": 211,
		"production_normal": _compact_sample(production_normal),
		"production_hard": _compact_sample(production_hard),
		"legacy_normal": _compact_sample(legacy_normal),
		"legacy_hard": _compact_sample(legacy_hard),
		"public_abilities": expected_abilities,
		"adjacent_fronts_exact": true,
		"scenario_authority_exact": true,
		"session_authority_exact": true,
	})])
	get_tree().quit(0)

func _scenario_encounter(scenario: Dictionary, placement_id: String) -> Dictionary:
	for value in scenario.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _guarded_resource_ids(scenario: Dictionary, guard_front_id: String) -> Array:
	var result: Array = []
	for value in scenario.get("resource_nodes", []):
		if value is Dictionary and String(value.get("guard_front_id", "")) == guard_front_id:
			result.append(String(value.get("placement_id", "")))
	result.sort()
	return result

func _objective_exact(scenario: Dictionary) -> bool:
	for value in scenario.get("objectives", {}).get("victory", []):
		if value is Dictionary and String(value.get("id", "")) == "break_relay_pickets":
			return value == {"id": "break_relay_pickets", "label": "Break the Relay Pickets", "type": "encounter_resolved", "placement_id": PLACEMENT_ID}
	return false

func _stack_contract(stacks_value: Variant) -> Array:
	var result: Array = []
	for value in stacks_value if stacks_value is Array else []:
		if value is Dictionary:
			result.append({"unit_id": String(value.get("unit_id", "")), "count": int(value.get("count", 0))})
	return result

func _stack_health(stacks: Array) -> int:
	var total := 0
	for value in stacks:
		if value is Dictionary:
			var unit: Dictionary = ContentService.get_unit(String(value.get("unit_id", "")))
			total += int(value.get("count", 0)) * int(unit.get("hp", 0))
	return total

func _battle_enemy_stack_contract(battle: Dictionary) -> Array:
	var result: Array = []
	for value in battle.get("stacks", []):
		if value is Dictionary and String(value.get("side", "")) == "enemy":
			result.append({"unit_id": String(value.get("unit_id", "")), "count": int(value.get("base_count", 0))})
	return result

func _battle_enemy_ability_contract(battle: Dictionary) -> Dictionary:
	var result := {}
	for value in battle.get("stacks", []):
		if not value is Dictionary or String(value.get("side", "")) != "enemy":
			continue
		var ids: Array = []
		for ability in value.get("abilities", []):
			if ability is Dictionary:
				ids.append(String(ability.get("id", "")))
		ids.sort()
		result[String(value.get("unit_id", ""))] = ids
	return result

func _sample_exact(sample: Dictionary, rounds: int, player_health: int, enemy_damage: int) -> bool:
	return bool(sample.get("completed", false)) and String(sample.get("outcome_state", "")) == "victory" and String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) == "even" and String(sample.get("pacing_band", "")) == "standard" and int(sample.get("round_reached", 0)) == rounds and int(sample.get("player_health_remaining_pct", -1)) == player_health and int(sample.get("enemy_health_remaining_pct", -1)) == 0 and int(sample.get("damage_per_round", {}).get("enemy", -1)) == enemy_damage and int(sample.get("invalid_order_count", -1)) == 0

func _compact_sample(sample: Dictionary) -> Dictionary:
	return {"outcome": String(sample.get("outcome_state", "")), "matchup_band": String(sample.get("initial_stack_profile", {}).get("matchup_band", "")), "pacing_band": String(sample.get("pacing_band", "")), "rounds": int(sample.get("round_reached", 0)), "player_health_remaining_pct": int(sample.get("player_health_remaining_pct", -1)), "enemy_damage_per_round": int(sample.get("damage_per_round", {}).get("enemy", -1)), "invalid_order_count": int(sample.get("invalid_order_count", -1))}

func _fail(message: String, details: Dictionary) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "details": details})])
	get_tree().quit(1)
