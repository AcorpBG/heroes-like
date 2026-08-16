extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "THORNWAKE_ROOTGATE_TOLL_CHAPTER_REPORT"
const SCENARIO_ID := "rootgate-toll"
const CAMPAIGN_ID := "campaign_frontier_claims"
const PREVIOUS_SCENARIO_ID := "bellwake-wreck-claim"
const HERO_ID := "hero_thornwake_tova_rootwright"
const PREVIOUS_HERO_ID := "hero_veilmourn_ivara_blacktide"
const ARMY_ID := "army_graftroot_wardens"
const PLAYER_TOWN_PLACEMENT_ID := "rootgate_nursery"
const PLAYER_TOWN_ID := "town_thornwake_rootgate_nursery"
const ENEMY_TOWN_PLACEMENT_ID := "clauseworks_toll_depot"
const ENEMY_TOWN_ID := "town_brasshollow_clauseworks_depot"
const ENCOUNTER_PLACEMENT_IDS := [
	"rootgate_charter_guard",
	"rootgate_bastion_reserve",
	"rootgate_boiler_exactors",
]
const REQUIRED_RESOURCE_PLACEMENT_IDS := [
	"rootgate_wood",
	"rootgate_ore",
	"rootgate_verdant_nursery",
	"rootgate_toll_rootgate_nursery_rare_exchange",
	"clauseworks_wood",
	"clauseworks_ore",
	"clauseworks_scrip_mint",
	"rootgate_toll_clauseworks_toll_depot_rare_exchange",
]
const SKIRMISH_SAVE_SLOT := 2
const CAMPAIGN_SAVE_SLOT := 3

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var progression_before: Dictionary = SaveService.load_progression()
	var catalog_result := _assert_catalog_and_setup()
	if _failed:
		return
	var skirmish_session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(skirmish_session)
	var opening_result := _assert_opening_session(skirmish_session, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var town_result := _exercise_town(skirmish_session)
	if _failed:
		return
	var skirmish_save := _exercise_save_restore(skirmish_session, SKIRMISH_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var restored_skirmish: SessionStateStoreScript.SessionData = skirmish_save.get("session", null)
	var battle_result := _exercise_battle_entries(restored_skirmish)
	if _failed:
		return
	var outcome_result := _exercise_outcomes()
	if _failed:
		return
	var campaign_result := _exercise_campaign_unlock_and_import()
	if _failed:
		return
	var campaign_session: SessionStateStoreScript.SessionData = campaign_result.get("session", null)
	var campaign_save := _exercise_save_restore(campaign_session, CAMPAIGN_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	if _failed:
		return
	if JSON.stringify(progression_before) != JSON.stringify(SaveService.load_progression()):
		_fail("Rootgate Toll focused flow mutated durable campaign progression storage.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"catalog": catalog_result,
		"opening": opening_result,
		"town": town_result,
		"skirmish_save_resume": skirmish_save.get("report", {}),
		"battle_entries": battle_result,
		"outcomes": outcome_result,
		"campaign": campaign_result.get("report", {}),
		"campaign_save_resume": campaign_save.get("report", {}),
		"campaign_progression_storage_unchanged": true,
	})])
	get_tree().quit(0)

func _assert_catalog_and_setup() -> Dictionary:
	var scenario_ids: Array = ContentService.get_content_ids(ContentService.SCENARIOS_PATH)
	if scenario_ids.size() != 24 or SCENARIO_ID not in scenario_ids or scenario_ids[18] != SCENARIO_ID:
		_fail("Active scenario catalog did not expose exact nineteenth Rootgate chapter: %s" % JSON.stringify(scenario_ids))
		return {}
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	if not bool(availability.get("campaign", false)) or not bool(availability.get("skirmish", false)):
		_fail("Rootgate Toll missed campaign/skirmish availability.")
		return {}
	if String(scenario.get("player_faction_id", "")) != "faction_thornwake" or String(scenario.get("hero_id", "")) != HERO_ID or String(scenario.get("player_army_id", "")) != ARMY_ID:
		_fail("Rootgate Toll changed its authored Thornwake commander or army identity.")
		return {}
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 11 or int(map_size.get("height", 0)) != 6:
		_fail("Rootgate Toll changed its authored 11x6 map size.")
		return {}
	var setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SCENARIO_ID, "normal")
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SCENARIO_ID or String(setup.get("difficulty", "")) != "normal":
		_fail("Live skirmish setup did not expose Rootgate Toll: %s" % JSON.stringify(setup))
		return {}
	return {
		"active_scenario_count": scenario_ids.size(),
		"campaign_available": true,
		"skirmish_available": true,
		"map_size": scenario.get("map_size", {}),
	}

func _assert_opening_session(session: SessionStateStoreScript.SessionData, launch_mode: String) -> Dictionary:
	if session == null or session.scenario_id != SCENARIO_ID or session.launch_mode != launch_mode:
		_fail("ScenarioFactory did not launch Rootgate Toll in %s mode." % launch_mode)
		return {}
	if String(session.overworld.get("active_hero_id", "")) != HERO_ID or String(session.overworld.get("hero", {}).get("id", "")) != HERO_ID:
		_fail("Tova Rootwright is not the active Rootgate commander.")
		return {}
	var army: Dictionary = session.overworld.get("army", {})
	if String(army.get("id", "")) != ARMY_ID or _stack_count(army.get("stacks", []), "unit_thornwake_seedcutters") != 8:
		_fail("Rootgate opening army did not materialize Graftroot Wardens: %s" % JSON.stringify(army))
		return {}
	var player_town := _town_by_placement(session, PLAYER_TOWN_PLACEMENT_ID)
	var enemy_town := _town_by_placement(session, ENEMY_TOWN_PLACEMENT_ID)
	if String(player_town.get("town_id", "")) != PLAYER_TOWN_ID or String(player_town.get("owner", "")) != "player":
		_fail("Rootgate Nursery did not materialize as the player town.")
		return {}
	if String(enemy_town.get("town_id", "")) != ENEMY_TOWN_ID or String(enemy_town.get("owner", "")) != "enemy":
		_fail("Clauseworks Depot did not materialize as the hostile town.")
		return {}
	var resource_ids := []
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary:
			resource_ids.append(String(node.get("placement_id", "")))
	for placement_id in REQUIRED_RESOURCE_PLACEMENT_IDS:
		if placement_id not in resource_ids:
			_fail("Rootgate live session missed resource placement %s." % placement_id)
			return {}
	return {
		"launch_mode": launch_mode,
		"hero_id": HERO_ID,
		"army_id": ARMY_ID,
		"player_town_id": PLAYER_TOWN_ID,
		"enemy_town_id": ENEMY_TOWN_ID,
		"required_resource_count": REQUIRED_RESOURCE_PLACEMENT_IDS.size(),
	}

func _exercise_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	session.flags["active_town_placement_id"] = PLAYER_TOWN_PLACEMENT_ID
	session.game_state = "town"
	var town := TownRulesScript.get_active_town(session)
	if String(town.get("town_id", "")) != PLAYER_TOWN_ID:
		_fail("Rootgate Nursery could not be opened through TownRules.")
		return {}
	var build_actions: Array = TownRulesScript.get_build_actions(session)
	var recruit_actions: Array = TownRulesScript.get_recruit_actions(session)
	var recruit_action := {}
	for action in recruit_actions:
		if action is Dictionary and String(action.get("id", "")).contains("unit_thornwake_") and not bool(action.get("disabled", true)):
			recruit_action = action
			break
	if build_actions.is_empty() or recruit_action.is_empty():
		_fail("Rootgate Nursery exposed no development or affordable Thornwake recruitment: %s" % JSON.stringify(recruit_actions))
		return {}
	var unit_id := String(recruit_action.get("id", "")).trim_prefix("recruit:")
	var recruit_result: Dictionary = TownRulesScript.recruit_active_town(session, unit_id, 1)
	if not bool(recruit_result.get("ok", false)):
		_fail("Rootgate Nursery recruit action failed: %s" % JSON.stringify(recruit_result))
		return {}
	return {"build_action_count": build_actions.size(), "recruited_unit_id": unit_id}

func _exercise_save_restore(session: SessionStateStoreScript.SessionData, slot: int, launch_mode: String) -> Dictionary:
	var signature_before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, slot)
	if not bool(save_result.get("ok", false)):
		_fail("Rootgate Toll %s save failed: %s" % [launch_mode, JSON.stringify(save_result)])
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(slot)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(slot)
	if restored == null:
		_fail("Rootgate Toll %s save did not restore." % launch_mode)
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var signature_after := _session_signature(restored)
	if JSON.stringify(signature_before) != JSON.stringify(signature_after):
		_fail("Rootgate Toll changed across %s save/restore: before=%s after=%s" % [launch_mode, signature_before, signature_after])
		return {}
	if restored.launch_mode != launch_mode:
		_fail("Rootgate Toll restored under the wrong launch mode.")
		return {}
	return {
		"session": restored,
		"report": {
			"slot": slot,
			"launch_mode": restored.launch_mode,
			"resume_target": String(summary.get("resume_target", "")),
			"signature": signature_after,
		},
	}

func _exercise_battle_entries(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var rows := []
	for placement_id in ENCOUNTER_PLACEMENT_IDS:
		var encounter := _encounter_by_placement(session, placement_id)
		var battle: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
		if battle.is_empty() or String(battle.get("player_commander_state", {}).get("id", "")) != HERO_ID:
			_fail("%s did not create a Tova-owned battle payload." % placement_id)
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
		if player_stack_count != 3 or enemy_stack_count < 2:
			_fail("%s battle missed authored army stacks: %s" % [placement_id, JSON.stringify(battle.get("stacks", []))])
			return {}
		rows.append({"placement_id": placement_id, "player_stacks": player_stack_count, "enemy_stacks": enemy_stack_count})
	return {"case_count": rows.size(), "rows": rows}

func _exercise_outcomes() -> Dictionary:
	var victory_session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	_set_town_owner(victory_session, ENEMY_TOWN_PLACEMENT_ID, "player")
	victory_session.flags["charter_guard_broken"] = true
	victory_session.flags["charter_bastion_reserve_broken"] = true
	victory_session.overworld["resolved_encounters"] = ["rootgate_boiler_exactors"]
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(victory_session)
	if String(victory_result.get("status", "")) != "victory":
		_fail("Rootgate Toll victory objectives did not resolve: %s" % JSON.stringify(victory_result))
		return {}
	var pre_deadline_session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	pre_deadline_session.day = 11
	var pre_deadline_result: Dictionary = ScenarioRulesScript.evaluate_session(pre_deadline_session)
	if String(pre_deadline_result.get("status", "")) != "in_progress":
		_fail("Rootgate Toll resolved before its authored Day 12 deadline.")
		return {}
	pre_deadline_session.day = 12
	var defeat_result: Dictionary = ScenarioRulesScript.evaluate_session(pre_deadline_session)
	if String(defeat_result.get("status", "")) != "defeat":
		_fail("Rootgate Toll Day 12 defeat boundary did not resolve: %s" % JSON.stringify(defeat_result))
		return {}
	return {"victory": "reachable", "pre_deadline": "in_progress", "defeat": "reachable", "deadline_day": 12}

func _exercise_campaign_unlock_and_import() -> Dictionary:
	var profile := CampaignRulesScript.normalize_profile({})
	var locked_action: Dictionary = CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, SCENARIO_ID)
	if not bool(locked_action.get("disabled", false)):
		_fail("Rootgate Toll was unlocked before Bellwake victory and drowned-chart evidence.")
		return {}
	var bellwake: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		PREVIOUS_SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	bellwake.flags["drowned_chart_recorded"] = true
	bellwake.overworld["resources"] = {"gold": 5000, "wood": 20, "ore": 20, "memory_salt": 10}
	bellwake.scenario_status = "victory"
	bellwake.scenario_summary = "Ivara recorded the drowned chart."
	var after_bellwake := CampaignRulesScript.record_session_completion(profile, bellwake)
	var unlocked_action: Dictionary = CampaignRulesScript.build_chapter_action(after_bellwake, CAMPAIGN_ID, SCENARIO_ID)
	if bool(unlocked_action.get("disabled", true)) or String(unlocked_action.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Exact Bellwake victory and drowned-chart evidence did not unlock Rootgate Toll: %s" % JSON.stringify(unlocked_action))
		return {}
	var baseline: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var campaign_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_bellwake, SCENARIO_ID, "normal", CAMPAIGN_ID
	)
	var opening := _assert_opening_session(campaign_session, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	if _failed:
		return {}
	var expected_resources := {"gold": 1200, "wood": 3, "ore": 3, "memory_salt": 2}
	var campaign_resources: Dictionary = campaign_session.overworld.get("resources", {})
	var baseline_resources: Dictionary = baseline.overworld.get("resources", {})
	for resource_id in expected_resources.keys():
		var delta := int(campaign_resources.get(resource_id, 0)) - int(baseline_resources.get(resource_id, 0))
		if delta != int(expected_resources.get(resource_id, 0)):
			_fail("Bellwake carryover %s changed by %d instead of %d." % [resource_id, delta, int(expected_resources.get(resource_id, 0))])
			return {}
	if not bool(campaign_session.flags.get("carryover_drowned_chart_recorded", false)) or String(campaign_session.flags.get("campaign_previous_scenario_id", "")) != PREVIOUS_SCENARIO_ID:
		_fail("Rootgate campaign session missed bounded Bellwake flag/source identity.")
		return {}
	if String(campaign_session.overworld.get("active_hero_id", "")) == PREVIOUS_HERO_ID:
		_fail("Bellwake commander leaked into Rootgate Toll.")
		return {}
	var campaign_hero: Dictionary = campaign_session.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline.overworld.get("hero", {})
	if int(campaign_hero.get("level", 0)) != int(baseline_hero.get("level", 0)) or JSON.stringify(campaign_hero.get("spellbook", {})) != JSON.stringify(baseline_hero.get("spellbook", {})) or JSON.stringify(campaign_hero.get("artifacts", {})) != JSON.stringify(baseline_hero.get("artifacts", {})):
		_fail("Cross-faction hero, spell, or artifact progression leaked into Rootgate Toll.")
		return {}
	return {
		"session": campaign_session,
		"report": {
			"locked_before_bellwake": true,
			"unlocked_after_exact_bellwake_evidence": true,
			"previous_scenario_id": PREVIOUS_SCENARIO_ID,
			"imported_resources": expected_resources,
			"imported_flag": "carryover_drowned_chart_recorded",
			"hero_spell_artifact_transfer": false,
			"opening": opening,
		},
	}

func _session_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"game_state": session.game_state,
		"hero_id": String(session.overworld.get("active_hero_id", "")),
		"army": session.overworld.get("army", {}),
		"resources": session.overworld.get("resources", {}),
		"active_town_placement_id": String(session.flags.get("active_town_placement_id", "")),
		"campaign_id": String(session.flags.get("campaign_id", "")),
		"campaign_previous_scenario_id": String(session.flags.get("campaign_previous_scenario_id", "")),
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
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
