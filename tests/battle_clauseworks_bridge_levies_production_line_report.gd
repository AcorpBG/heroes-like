extends Node

const Harness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_CLAUSEWORKS_BRIDGE_LEVIES_PRODUCTION_LINE_REPORT"
const SCENARIO_ID := "clauseworks-counterclaim"
const PLACEMENT_ID := "clauseworks_bridge_levies"
const SAVE_SLOT := 8
const PRODUCTION_STACKS := [
	{"unit_id": "unit_embercourt_fordhook_cadets", "count": 5},
	{"unit_id": "unit_embercourt_bargebow_crews", "count": 5},
	{"unit_id": "unit_embercourt_sluicefire_lindworms", "count": 1},
]
const LEGACY_STACKS := [
	{"unit_id": "unit_river_guard", "count": 5},
	{"unit_id": "unit_citadel_pikeward", "count": 4},
	{"unit_id": "unit_ember_archer", "count": 6},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var progression_before: Dictionary = SaveService.load_progression()
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var scenario_authority_before: Dictionary = scenario.duplicate(true)
	var encounter: Dictionary = _scenario_encounter(scenario, PLACEMENT_ID)
	var archive_before: Dictionary = _scenario_encounter(scenario, "clauseworks_archive_wardens").duplicate(true)
	var beacon_before: Dictionary = _scenario_encounter(scenario, "clauseworks_beacon_wardens").duplicate(true)
	var resources_before: Array = scenario.get("resource_nodes", []).duplicate(true)
	var enemy_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if (
		String(encounter.get("encounter_id", "")) != "encounter_bridgeward_levies"
		or String(encounter.get("difficulty", "")) != "high"
		or int(encounter.get("combat_seed", 0)) != 21102
		or Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) != Vector2i(6, 4)
		or String(enemy_army.get("id", "")) != "army_clauseworks_bridge_levies"
		or String(enemy_army.get("faction_id", "")) != "faction_embercourt"
		or _stack_contract(enemy_army.get("stacks", [])) != PRODUCTION_STACKS
		or not _objective_exact(scenario)
	):
		_fail("Clauseworks Bridge Levies production identity or objective authority drifted.", {"encounter": encounter})
		return
	var session: SessionStateStore.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	if session == null:
		_fail("Clauseworks could not create a live skirmish session.", {})
		return
	OverworldRules.normalize_overworld_state(session)
	var session_authority_before: Dictionary = session.to_dict()
	var battle_payload: Dictionary = BattleRules.create_battle_payload(session, encounter)
	var expected_abilities := {
		"unit_embercourt_fordhook_cadets": ["brace", "reach"],
		"unit_embercourt_bargebow_crews": ["volley"],
		"unit_embercourt_sluicefire_lindworms": ["bloodrush"],
	}
	if session.to_dict() != session_authority_before or _battle_enemy_stack_contract(battle_payload) != PRODUCTION_STACKS or _battle_enemy_ability_contract(battle_payload) != expected_abilities:
		_fail("Public battle payload missed the exact Clauseworks Bridge production line or mutated the session.", {"stacks": _battle_enemy_stack_contract(battle_payload), "abilities": _battle_enemy_ability_contract(battle_payload)})
		return
	if _save_restore(session) == null:
		return
	if _stack_health(PRODUCTION_STACKS) != 155 or _stack_health(LEGACY_STACKS) != 151:
		_fail("Clauseworks Bridge production/legacy stack-health contract drifted.", {})
		return
	var legacy_encounter: Dictionary = encounter.duplicate(true)
	legacy_encounter["placement_id"] = "%s:legacy_control" % PLACEMENT_ID
	var legacy_army: Dictionary = enemy_army.duplicate(true)
	legacy_army["id"] = "army_clauseworks_bridge_levies_legacy_control"
	legacy_army["stacks"] = LEGACY_STACKS.duplicate(true)
	legacy_encounter["enemy_army"] = legacy_army
	var production_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var production_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, encounter, 72, "hard")
	var legacy_normal: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "normal")
	var legacy_hard: Dictionary = Harness.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "hard")
	var outcomes := _outcome_contract()
	if (
		not _sample_exact(production_normal, "extended", 6, 12, 24)
		or not _sample_exact(production_hard, "standard", 4, 31, 26)
		or not _sample_exact(legacy_normal, "extended", 6, 30, 21)
		or not _sample_exact(legacy_hard, "standard", 4, 48, 21)
		or _scenario_encounter(scenario, "clauseworks_archive_wardens") != archive_before
		or _scenario_encounter(scenario, "clauseworks_beacon_wardens") != beacon_before
		or scenario.get("resource_nodes", []) != resources_before
		or scenario != scenario_authority_before
		or outcomes != {"victory": "reachable", "defeat": "reachable"}
		or JSON.stringify(progression_before) != JSON.stringify(SaveService.load_progression())
	):
		_fail("Clauseworks Bridge production, legacy, adjacent-front, or scenario contract drifted.", {"production_normal": _compact_sample(production_normal), "production_hard": _compact_sample(production_hard), "legacy_normal": _compact_sample(legacy_normal), "legacy_hard": _compact_sample(legacy_hard)})
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"production_stacks": PRODUCTION_STACKS.duplicate(true),
		"legacy_stacks": LEGACY_STACKS.duplicate(true),
		"production_health": 155,
		"legacy_health": 151,
		"production_normal": _compact_sample(production_normal),
		"production_hard": _compact_sample(production_hard),
		"legacy_normal": _compact_sample(legacy_normal),
		"legacy_hard": _compact_sample(legacy_hard),
		"public_abilities": expected_abilities,
		"objective_exact": true,
		"guarded_resources_exact": true,
		"adjacent_fronts_exact": true,
		"scenario_authority_exact": true,
		"session_authority_exact": true,
		"save_resume_exact": true,
		"outcomes": outcomes,
		"campaign_progression_unchanged": true,
	})])
	get_tree().quit(0)

func _scenario_encounter(scenario: Dictionary, placement_id: String) -> Dictionary:
	for value in scenario.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _objective_exact(scenario: Dictionary) -> bool:
	for value in scenario.get("objectives", {}).get("victory", []):
		if value is Dictionary and String(value.get("id", "")) == "break_clauseworks_bridge_levies":
			return value == {"id": "break_clauseworks_bridge_levies", "label": "Break the Clauseworks Bridge Levies", "type": "encounter_resolved", "placement_id": PLACEMENT_ID}
	return false

func _save_restore(session: SessionStateStore.SessionData) -> SessionStateStore.SessionData:
	var signature_before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Clauseworks Bridge runtime save failed.", {"save_result": save_result})
		return null
	var summary: Dictionary = SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored: SessionStateStore.SessionData = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("Clauseworks Bridge runtime save did not restore.", {})
		return null
	OverworldRules.normalize_overworld_state(restored)
	if _session_signature(restored) != signature_before or String(summary.get("resume_target", "")) != "overworld":
		_fail("Clauseworks Bridge runtime save/restore authority drifted.", {"before": signature_before, "after": _session_signature(restored), "summary": summary})
		return null
	return restored

func _outcome_contract() -> Dictionary:
	var victory: SessionStateStore.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	_set_town_owner(victory, "highwater_audit_front", "player")
	victory.overworld["resolved_encounters"] = ["clauseworks_archive_wardens", PLACEMENT_ID, "clauseworks_beacon_wardens"]
	var victory_result: Dictionary = ScenarioRules.evaluate_session(victory)
	var defeat: SessionStateStore.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	defeat.day = 13
	var defeat_result: Dictionary = ScenarioRules.evaluate_session(defeat)
	if String(victory_result.get("status", "")) != "victory" or String(defeat_result.get("status", "")) != "defeat":
		_fail("Clauseworks Bridge victory/defeat boundaries are not independently reachable.", {"victory": victory_result, "defeat": defeat_result})
		return {}
	return {"victory": "reachable", "defeat": "reachable"}

func _session_signature(session: SessionStateStore.SessionData) -> Dictionary:
	return {"scenario_id": session.scenario_id, "launch_mode": session.launch_mode, "game_state": session.game_state, "hero_id": String(session.overworld.get("active_hero_id", "")), "army": session.overworld.get("army", {}), "resources": session.overworld.get("resources", {}), "target_encounter": _scenario_encounter({"encounters": session.overworld.get("encounters", [])}, PLACEMENT_ID)}

func _set_town_owner(session: SessionStateStore.SessionData, placement_id: String, owner: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

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

func _sample_exact(sample: Dictionary, pacing: String, rounds: int, player_health: int, enemy_damage: int) -> bool:
	return bool(sample.get("completed", false)) and String(sample.get("outcome_state", "")) == "victory" and String(sample.get("pacing_band", "")) == pacing and int(sample.get("round_reached", 0)) == rounds and int(sample.get("player_health_remaining_pct", -1)) == player_health and int(sample.get("enemy_health_remaining_pct", -1)) == 0 and int(sample.get("damage_per_round", {}).get("enemy", -1)) == enemy_damage and int(sample.get("invalid_order_count", -1)) == 0

func _compact_sample(sample: Dictionary) -> Dictionary:
	return {"outcome": String(sample.get("outcome_state", "")), "pacing_band": String(sample.get("pacing_band", "")), "rounds": int(sample.get("round_reached", 0)), "player_health_remaining_pct": int(sample.get("player_health_remaining_pct", -1)), "enemy_damage_per_round": int(sample.get("damage_per_round", {}).get("enemy", -1)), "invalid_order_count": int(sample.get("invalid_order_count", -1))}

func _fail(message: String, details: Dictionary) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "details": details})])
	get_tree().quit(1)
