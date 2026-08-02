extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "BRASSHOLLOW_OREVEIN_PLAYER_SKIRMISH_REPORT"
const SCENARIO_ID := "orevein-contract"
const HERO_ID := "hero_brasshollow_marka_ironclause"
const ARMY_ID := "army_orevein_contract_column"
const PLAYER_TOWN_PLACEMENT_ID := "orevein_gantry"
const PLAYER_TOWN_ID := "town_brasshollow_orevein_gantry"
const SAVE_SLOT := 4

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var progression_before := SaveService.load_progression()
	var setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SCENARIO_ID, "normal")
	_assert_setup(setup)
	if _failed:
		return

	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	_assert_opening_session(session)
	if _failed:
		return

	var town_result := _exercise_town(session)
	if _failed:
		return
	var save_result := _exercise_save_restore(session)
	if _failed:
		return
	var restored: SessionStateStoreScript.SessionData = save_result.get("session", null)
	var battle_result := _exercise_battle_entry(restored)
	if _failed:
		return
	var outcome_result := _exercise_outcomes()
	if _failed:
		return

	if JSON.stringify(progression_before) != JSON.stringify(SaveService.load_progression()):
		_fail("Orevein Contract changed campaign progression storage.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"launch_mode": restored.launch_mode,
		"hero_id": String(restored.overworld.get("active_hero_id", "")),
		"town": town_result,
		"save_resume": save_result.get("report", {}),
		"battle_entry": battle_result,
		"outcomes": outcome_result,
		"campaign_progression_unchanged": true,
	})])
	get_tree().quit(0)

func _assert_setup(setup: Dictionary) -> void:
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Live skirmish setup did not expose Orevein Contract: %s" % JSON.stringify(setup))
		return
	if String(setup.get("difficulty", "")) != "normal":
		_fail("Orevein setup did not preserve normal difficulty.")
		return
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	if bool(availability.get("campaign", true)) or not bool(availability.get("skirmish", false)):
		_fail("Orevein Contract crossed its skirmish-only availability boundary: %s" % JSON.stringify(availability))
		return
	if String(scenario.get("player_faction_id", "")) != "faction_brasshollow":
		_fail("Orevein Contract is not authored for Brasshollow.")

func _assert_opening_session(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id != SCENARIO_ID:
		_fail("ScenarioFactory did not launch Orevein Contract.")
		return
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH or session.flags.has("campaign_id"):
		_fail("Orevein Contract crossed into campaign session state.")
		return
	if String(session.overworld.get("active_hero_id", "")) != HERO_ID:
		_fail("Marka is not the active Orevein commander.")
		return
	var hero: Dictionary = session.overworld.get("hero", {})
	if String(hero.get("id", "")) != HERO_ID:
		_fail("Orevein hero state did not materialize Marka.")
		return
	var army: Dictionary = session.overworld.get("army", {})
	if String(army.get("id", "")) != ARMY_ID or _stack_count(army.get("stacks", []), "unit_brasshollow_scrip_haulers") != 12:
		_fail("Orevein opening army did not materialize its authored Brasshollow column: %s" % JSON.stringify(army))
		return
	var town := _town_by_placement(session, PLAYER_TOWN_PLACEMENT_ID)
	if String(town.get("town_id", "")) != PLAYER_TOWN_ID or String(town.get("owner", "")) != "player":
		_fail("Orevein Gantry did not materialize as the player opening town.")

func _exercise_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	session.flags["active_town_placement_id"] = PLAYER_TOWN_PLACEMENT_ID
	session.game_state = "town"
	var town := TownRulesScript.get_active_town(session)
	if String(town.get("placement_id", "")) != PLAYER_TOWN_PLACEMENT_ID:
		_fail("Orevein Gantry could not be opened through the live town rules.")
		return {}
	var build_actions := TownRulesScript.get_build_actions(session)
	if build_actions.is_empty():
		_fail("Orevein Gantry exposed no development actions.")
		return {}
	var recruit_actions := TownRulesScript.get_recruit_actions(session)
	var recruit_action := {}
	for action in recruit_actions:
		if action is Dictionary and String(action.get("id", "")).contains("unit_brasshollow_") and not bool(action.get("disabled", true)):
			recruit_action = action
			break
	if recruit_action.is_empty():
		_fail("Orevein Gantry exposed no affordable Brasshollow recruit action: %s" % JSON.stringify(recruit_actions))
		return {}
	var unit_id := String(recruit_action.get("id", "")).trim_prefix("recruit:")
	var recruit_result: Dictionary = TownRulesScript.recruit_active_town(session, unit_id, 1)
	if not bool(recruit_result.get("ok", false)):
		_fail("Orevein Gantry recruit action failed: %s" % JSON.stringify(recruit_result))
		return {}
	return {
		"placement_id": PLAYER_TOWN_PLACEMENT_ID,
		"build_action_count": build_actions.size(),
		"recruited_unit_id": unit_id,
	}

func _exercise_save_restore(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Orevein Contract runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary := SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("Orevein Contract runtime save did not restore.")
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var signature_after := _session_signature(restored)
	if JSON.stringify(signature_before) != JSON.stringify(signature_after):
		_fail("Orevein Contract changed across save/restore: before=%s after=%s" % [signature_before, signature_after])
		return {}
	return {
		"session": restored,
		"report": {
			"slot": SAVE_SLOT,
			"resume_target": String(summary.get("resume_target", "")),
			"signature": signature_after,
		},
	}

func _exercise_battle_entry(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var encounter := _encounter_by_placement(session, "orevein_archive_wardens")
	var battle: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if battle.is_empty():
		_fail("Orevein Archive Wardens did not create a live battle payload.")
		return {}
	if String(battle.get("player_commander_state", {}).get("id", "")) != HERO_ID:
		_fail("Archive Wardens battle did not preserve Marka as player commander.")
		return {}
	var player_stack_count := 0
	var enemy_stack_count := 0
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) == "player":
			player_stack_count += 1
		elif String(stack.get("side", "")) == "enemy":
			enemy_stack_count += 1
	if player_stack_count != 4 or enemy_stack_count != 3:
		_fail("Archive Wardens battle missed authored armies: %s" % JSON.stringify(battle.get("stacks", [])))
		return {}
	return {
		"encounter_id": String(battle.get("encounter_id", "")),
		"player_stack_count": player_stack_count,
		"enemy_stack_count": enemy_stack_count,
	}

func _exercise_outcomes() -> Dictionary:
	var victory_session := ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_set_town_owner(victory_session, "riverwatch_contract_crossing", "player")
	victory_session.flags["archive_wardens_broken"] = true
	victory_session.flags["bridgeward_levies_broken"] = true
	victory_session.overworld["resolved_encounters"] = ["orevein_beacon_wardens"]
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(victory_session)
	if String(victory_result.get("status", "")) != "victory":
		_fail("Orevein Contract victory objectives did not resolve: %s" % JSON.stringify(victory_result))
		return {}

	var defeat_session := ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	defeat_session.day = 12
	var defeat_result: Dictionary = ScenarioRulesScript.evaluate_session(defeat_session)
	if String(defeat_result.get("status", "")) != "defeat":
		_fail("Orevein Contract Day 12 defeat boundary did not resolve: %s" % JSON.stringify(defeat_result))
		return {}
	return {"victory": "reachable", "defeat": "reachable"}

func _session_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"game_state": session.game_state,
		"hero_id": String(session.overworld.get("active_hero_id", "")),
		"army": session.overworld.get("army", {}),
		"resources": session.overworld.get("resources", {}),
		"active_town_placement_id": String(session.flags.get("active_town_placement_id", "")),
	}

func _stack_count(stacks: Variant, unit_id: String) -> int:
	if not (stacks is Array):
		return 0
	for stack in stacks:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return int(stack.get("count", 0))
	return 0

func _town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _set_town_owner(session: SessionStateStoreScript.SessionData, placement_id: String, owner: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _fail(message: String) -> void:
	_failed = true
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
