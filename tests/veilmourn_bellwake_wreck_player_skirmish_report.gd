extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "VEILMOURN_BELLWAKE_WRECK_PLAYER_SKIRMISH_REPORT"
const SCENARIO_ID := "bellwake-wreck-claim"
const HERO_ID := "hero_veilmourn_ivara_blacktide"
const ARMY_ID := "army_bellwake_wreck_claimants"
const PLAYER_TOWN_PLACEMENT_ID := "bellwake_harbor"
const PLAYER_TOWN_ID := "town_veilmourn_bellwake_harbor"
const SAVE_SLOT := 5

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
		_fail("Bellwake Wreck Claim changed campaign progression storage.")
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
		_fail("Live skirmish setup did not expose Bellwake Wreck Claim: %s" % JSON.stringify(setup))
		return
	if String(setup.get("difficulty", "")) != "normal":
		_fail("Bellwake setup did not preserve normal difficulty.")
		return
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	if not bool(availability.get("campaign", false)) or not bool(availability.get("skirmish", false)):
		_fail("Bellwake Wreck Claim missed dual-mode campaign/skirmish availability: %s" % JSON.stringify(availability))
		return
	if String(scenario.get("player_faction_id", "")) != "faction_veilmourn":
		_fail("Bellwake Wreck Claim is not authored for Veilmourn.")

func _assert_opening_session(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id != SCENARIO_ID:
		_fail("ScenarioFactory did not launch Bellwake Wreck Claim.")
		return
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH or session.flags.has("campaign_id"):
		_fail("Bellwake Wreck Claim crossed into campaign session state.")
		return
	if String(session.overworld.get("active_hero_id", "")) != HERO_ID:
		_fail("Ivara is not the active Bellwake commander.")
		return
	var hero: Dictionary = session.overworld.get("hero", {})
	if String(hero.get("id", "")) != HERO_ID:
		_fail("Bellwake hero state did not materialize Ivara.")
		return
	var army: Dictionary = session.overworld.get("army", {})
	if String(army.get("id", "")) != ARMY_ID or _stack_count(army.get("stacks", []), "unit_veilmourn_bellwake_oars") != 14:
		_fail("Bellwake opening army did not materialize its authored Veilmourn claim crew: %s" % JSON.stringify(army))
		return
	var town := _town_by_placement(session, PLAYER_TOWN_PLACEMENT_ID)
	if String(town.get("town_id", "")) != PLAYER_TOWN_ID or String(town.get("owner", "")) != "player":
		_fail("Bellwake Harbor did not materialize as the player opening town.")

func _exercise_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	session.flags["active_town_placement_id"] = PLAYER_TOWN_PLACEMENT_ID
	session.game_state = "town"
	var town := TownRulesScript.get_active_town(session)
	if String(town.get("placement_id", "")) != PLAYER_TOWN_PLACEMENT_ID:
		_fail("Bellwake Harbor could not be opened through the live town rules.")
		return {}
	var build_actions := TownRulesScript.get_build_actions(session)
	if build_actions.is_empty():
		_fail("Bellwake Harbor exposed no development actions.")
		return {}
	var recruit_actions := TownRulesScript.get_recruit_actions(session)
	var recruit_action := {}
	for action in recruit_actions:
		if action is Dictionary and String(action.get("id", "")).contains("unit_veilmourn_") and not bool(action.get("disabled", true)):
			recruit_action = action
			break
	if recruit_action.is_empty():
		_fail("Bellwake Harbor exposed no affordable Veilmourn recruit action: %s" % JSON.stringify(recruit_actions))
		return {}
	var unit_id := String(recruit_action.get("id", "")).trim_prefix("recruit:")
	var recruit_result: Dictionary = TownRulesScript.recruit_active_town(session, unit_id, 1)
	if not bool(recruit_result.get("ok", false)):
		_fail("Bellwake Harbor recruit action failed: %s" % JSON.stringify(recruit_result))
		return {}
	return {"placement_id": PLAYER_TOWN_PLACEMENT_ID, "build_action_count": build_actions.size(), "recruited_unit_id": unit_id}

func _exercise_save_restore(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Bellwake Wreck Claim runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary := SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("Bellwake Wreck Claim runtime save did not restore.")
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var signature_after := _session_signature(restored)
	if JSON.stringify(signature_before) != JSON.stringify(signature_after):
		_fail("Bellwake Wreck Claim changed across save/restore: before=%s after=%s" % [signature_before, signature_after])
		return {}
	return {"session": restored, "report": {"slot": SAVE_SLOT, "resume_target": String(summary.get("resume_target", "")), "signature": signature_after}}

func _exercise_battle_entry(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var encounter := _encounter_by_placement(session, "bellwake_relay_pickets")
	var battle: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if battle.is_empty():
		_fail("Bellwake Relay Pickets did not create a live battle payload.")
		return {}
	if String(battle.get("player_commander_state", {}).get("id", "")) != HERO_ID:
		_fail("Relay Pickets battle did not preserve Ivara as player commander.")
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
		_fail("Relay Pickets battle missed authored armies: %s" % JSON.stringify(battle.get("stacks", [])))
		return {}
	return {"encounter_id": String(battle.get("encounter_id", "")), "player_stack_count": player_stack_count, "enemy_stack_count": enemy_stack_count}

func _exercise_outcomes() -> Dictionary:
	var victory_session := ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_set_town_owner(victory_session, "prismhearth_wreck_registry", "player")
	victory_session.flags["relay_pickets_broken"] = true
	victory_session.flags["mirror_lancers_broken"] = true
	victory_session.overworld["resolved_encounters"] = ["bellwake_aurora_battery"]
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(victory_session)
	if String(victory_result.get("status", "")) != "victory":
		_fail("Bellwake Wreck Claim victory objectives did not resolve: %s" % JSON.stringify(victory_result))
		return {}

	var defeat_session := ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	defeat_session.day = 13
	var defeat_result: Dictionary = ScenarioRulesScript.evaluate_session(defeat_session)
	if String(defeat_result.get("status", "")) != "defeat":
		_fail("Bellwake Wreck Claim Day 13 defeat boundary did not resolve: %s" % JSON.stringify(defeat_result))
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
