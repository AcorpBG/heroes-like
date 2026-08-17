extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "VEILMOURN_FOGCHART_MOORING_CHAPTER_REPORT"
const SCENARIO_ID := "fogchart-mooring"
const CAMPAIGN_ID := "campaign_frontier_claims"
const PREVIOUS_SCENARIO_ID := "rootgate-toll"
const HERO_ID := "hero_veilmourn_ruln_vanehook"
const PREVIOUS_HERO_ID := "hero_thornwake_tova_rootwright"
const ARMY_ID := "army_bellwake_privateers"
const PLAYER_TOWN_PLACEMENT_ID := "fogchart_mooring"
const PLAYER_TOWN_ID := "town_veilmourn_fogchart_mooring"
const ENEMY_TOWN_PLACEMENT_ID := "halo_registry_front"
const ENEMY_TOWN_ID := "town_halo_spire"
const ENCOUNTER_PLACEMENT_IDS := [
	"fogchart_relay_pickets",
	"fogchart_mirror_lancers",
	"fogchart_aurora_battery",
]
const REQUIRED_RESOURCE_PLACEMENT_IDS := [
	"fogchart_wood",
	"fogchart_ore",
	"fogchart_memory_salt_pan",
	"fogchart_mist_lighthouse",
	"fogchart_mooring_fogchart_mooring_rare_exchange",
	"halo_registry_wood",
	"halo_registry_ore",
	"halo_registry_aetherglass",
	"fogchart_mooring_halo_registry_front_rare_exchange",
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
	var skirmish: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(skirmish)
	var opening_result := _assert_opening_session(skirmish, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var town_result := _exercise_town(skirmish)
	if _failed:
		return
	var skirmish_save := _exercise_save_restore(skirmish, SKIRMISH_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var battle_result := _exercise_battle_entries(skirmish_save.get("session", null))
	if _failed:
		return
	var outcome_result := _exercise_outcomes()
	if _failed:
		return
	var campaign_result := _exercise_campaign_unlock_and_import()
	if _failed:
		return
	var campaign_save := _exercise_save_restore(campaign_result.get("session", null), CAMPAIGN_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	if _failed:
		return
	if JSON.stringify(progression_before) != JSON.stringify(SaveService.load_progression()):
		_fail("Fogchart focused flow mutated durable campaign progression storage.")
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
	if scenario_ids.size() != 24 or SCENARIO_ID not in scenario_ids or scenario_ids[19] != SCENARIO_ID:
		_fail("Active catalog did not retain Fogchart as exact twentieth scenario in the twenty-three scenario roster: %s" % JSON.stringify(scenario_ids))
		return {}
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	if not bool(availability.get("campaign", false)) or not bool(availability.get("skirmish", false)):
		_fail("Fogchart missed campaign/skirmish availability.")
		return {}
	if String(scenario.get("player_faction_id", "")) != "faction_veilmourn" or String(scenario.get("hero_id", "")) != HERO_ID or String(scenario.get("player_army_id", "")) != ARMY_ID:
		_fail("Fogchart changed its authored Veilmourn commander or army identity.")
		return {}
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 11 or int(map_size.get("height", 0)) != 6:
		_fail("Fogchart changed its authored 11x6 map size.")
		return {}
	var setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SCENARIO_ID, "normal")
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SCENARIO_ID or String(setup.get("difficulty", "")) != "normal":
		_fail("Live skirmish setup did not expose Fogchart: %s" % JSON.stringify(setup))
		return {}
	return {"active_scenario_count": scenario_ids.size(), "campaign_available": true, "skirmish_available": true, "map_size": map_size}

func _assert_opening_session(session: SessionStateStoreScript.SessionData, launch_mode: String) -> Dictionary:
	if session == null or session.scenario_id != SCENARIO_ID or session.launch_mode != launch_mode:
		_fail("ScenarioFactory did not launch Fogchart in %s mode." % launch_mode)
		return {}
	if String(session.overworld.get("active_hero_id", "")) != HERO_ID or String(session.overworld.get("hero", {}).get("id", "")) != HERO_ID:
		_fail("Ruln Vanehook is not the active Fogchart commander.")
		return {}
	var army: Dictionary = session.overworld.get("army", {})
	if String(army.get("id", "")) != ARMY_ID or _stack_count(army.get("stacks", []), "unit_veilmourn_bellwake_oars") != 12:
		_fail("Fogchart opening army did not materialize Bellwake Privateers: %s" % JSON.stringify(army))
		return {}
	var player_town := _town_by_placement(session, PLAYER_TOWN_PLACEMENT_ID)
	var enemy_town := _town_by_placement(session, ENEMY_TOWN_PLACEMENT_ID)
	if String(player_town.get("town_id", "")) != PLAYER_TOWN_ID or String(player_town.get("owner", "")) != "player":
		_fail("Fogchart Mooring did not materialize as the player town.")
		return {}
	if String(enemy_town.get("town_id", "")) != ENEMY_TOWN_ID or String(enemy_town.get("owner", "")) != "enemy":
		_fail("Halo Registry Front did not materialize as the hostile town.")
		return {}
	var resource_ids := []
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary:
			resource_ids.append(String(node.get("placement_id", "")))
	for placement_id in REQUIRED_RESOURCE_PLACEMENT_IDS:
		if placement_id not in resource_ids:
			_fail("Fogchart session missed resource placement %s." % placement_id)
			return {}
	return {"launch_mode": launch_mode, "hero_id": HERO_ID, "army_id": ARMY_ID, "player_town_id": PLAYER_TOWN_ID, "enemy_town_id": ENEMY_TOWN_ID, "required_resource_count": REQUIRED_RESOURCE_PLACEMENT_IDS.size()}

func _exercise_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	session.flags["active_town_placement_id"] = PLAYER_TOWN_PLACEMENT_ID
	session.game_state = "town"
	if String(TownRulesScript.get_active_town(session).get("town_id", "")) != PLAYER_TOWN_ID:
		_fail("Fogchart Mooring could not be opened through TownRules.")
		return {}
	var build_actions: Array = TownRulesScript.get_build_actions(session)
	var recruit_action := {}
	for action in TownRulesScript.get_recruit_actions(session):
		if action is Dictionary and String(action.get("id", "")).contains("unit_veilmourn_") and not bool(action.get("disabled", true)):
			recruit_action = action
			break
	if build_actions.is_empty() or recruit_action.is_empty():
		_fail("Fogchart exposed no development or affordable Veilmourn recruitment.")
		return {}
	var unit_id := String(recruit_action.get("id", "")).trim_prefix("recruit:")
	var result: Dictionary = TownRulesScript.recruit_active_town(session, unit_id, 1)
	if not bool(result.get("ok", false)):
		_fail("Fogchart recruit action failed: %s" % JSON.stringify(result))
		return {}
	return {"build_action_count": build_actions.size(), "recruited_unit_id": unit_id}

func _exercise_save_restore(session: SessionStateStoreScript.SessionData, slot: int, launch_mode: String) -> Dictionary:
	var before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, slot)
	if not bool(save_result.get("ok", false)):
		_fail("Fogchart %s save failed: %s" % [launch_mode, JSON.stringify(save_result)])
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(slot)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(slot)
	if restored == null:
		_fail("Fogchart %s save did not restore." % launch_mode)
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var after := _session_signature(restored)
	if JSON.stringify(before) != JSON.stringify(after) or restored.launch_mode != launch_mode:
		_fail("Fogchart changed across %s save/restore: before=%s after=%s" % [launch_mode, before, after])
		return {}
	return {"session": restored, "report": {"slot": slot, "launch_mode": launch_mode, "resume_target": String(summary.get("resume_target", "")), "signature": after}}

func _exercise_battle_entries(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var rows := []
	for placement_id in ENCOUNTER_PLACEMENT_IDS:
		var battle: Dictionary = BattleRulesScript.create_battle_payload(session, _encounter_by_placement(session, placement_id))
		if battle.is_empty() or String(battle.get("player_commander_state", {}).get("id", "")) != HERO_ID:
			_fail("%s did not create a Ruln-owned battle payload." % placement_id)
			return {}
		var player_stacks := 0
		var enemy_stacks := 0
		for stack in battle.get("stacks", []):
			if stack is Dictionary and String(stack.get("side", "")) == "player":
				player_stacks += 1
			elif stack is Dictionary and String(stack.get("side", "")) == "enemy":
				enemy_stacks += 1
		if player_stacks != 3 or enemy_stacks < 3:
			_fail("%s battle missed authored army stacks." % placement_id)
			return {}
		rows.append({"placement_id": placement_id, "player_stacks": player_stacks, "enemy_stacks": enemy_stacks})
	return {"case_count": rows.size(), "rows": rows}

func _exercise_outcomes() -> Dictionary:
	var victory: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_set_town_owner(victory, ENEMY_TOWN_PLACEMENT_ID, "player")
	victory.overworld["resolved_encounters"] = ["fogchart_relay_pickets", "fogchart_mirror_lancers", "fogchart_aurora_battery"]
	if String(ScenarioRulesScript.evaluate_session(victory).get("status", "")) != "victory":
		_fail("Fogchart victory objectives did not resolve.")
		return {}
	var deadline: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	deadline.day = 12
	if String(ScenarioRulesScript.evaluate_session(deadline).get("status", "")) != "in_progress":
		_fail("Fogchart resolved before its authored Day 13 deadline.")
		return {}
	deadline.day = 13
	if String(ScenarioRulesScript.evaluate_session(deadline).get("status", "")) != "defeat":
		_fail("Fogchart Day 13 defeat boundary did not resolve.")
		return {}
	return {"victory": "reachable", "pre_deadline": "in_progress", "defeat": "reachable", "deadline_day": 13}

func _exercise_campaign_unlock_and_import() -> Dictionary:
	var profile := CampaignRulesScript.normalize_profile({})
	if not bool(CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, SCENARIO_ID).get("disabled", false)):
		_fail("Fogchart unlocked before Rootgate victory and recorded-claim evidence.")
		return {}
	var rootgate: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(PREVIOUS_SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	rootgate.flags["rootgate_toll_recorded"] = true
	rootgate.flags["boiler_scrap_grafted"] = true
	rootgate.overworld["resources"] = {"gold": 5000, "wood": 20, "ore": 20, "verdant_grafts": 10}
	rootgate.scenario_status = "victory"
	rootgate.scenario_summary = "Tova recorded the rooted toll claim."
	var completed := CampaignRulesScript.record_session_completion(profile, rootgate)
	var action: Dictionary = CampaignRulesScript.build_chapter_action(completed, CAMPAIGN_ID, SCENARIO_ID)
	if bool(action.get("disabled", true)) or String(action.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Exact Rootgate victory and recorded-claim evidence did not unlock Fogchart: %s" % JSON.stringify(action))
		return {}
	var baseline: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var campaign: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(completed, SCENARIO_ID, "normal", CAMPAIGN_ID)
	var opening := _assert_opening_session(campaign, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	if _failed:
		return {}
	var expected := {"gold": 1000, "wood": 3, "ore": 3}
	for resource_id in expected:
		var delta := int(campaign.overworld.get("resources", {}).get(resource_id, 0)) - int(baseline.overworld.get("resources", {}).get(resource_id, 0))
		if delta != int(expected[resource_id]):
			_fail("Rootgate carryover %s changed by %d instead of %d." % [resource_id, delta, int(expected[resource_id])])
			return {}
	if int(campaign.overworld.get("resources", {}).get("verdant_grafts", 0)) != int(baseline.overworld.get("resources", {}).get("verdant_grafts", 0)):
		_fail("Thornwake verdant grafts leaked into Fogchart.")
		return {}
	if not bool(campaign.flags.get("carryover_rootgate_toll_recorded", false)) or String(campaign.flags.get("campaign_previous_scenario_id", "")) != PREVIOUS_SCENARIO_ID:
		_fail("Fogchart campaign session missed bounded Rootgate flag/source identity.")
		return {}
	var hero: Dictionary = campaign.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline.overworld.get("hero", {})
	if String(campaign.overworld.get("active_hero_id", "")) == PREVIOUS_HERO_ID or int(hero.get("level", 0)) != int(baseline_hero.get("level", 0)) or JSON.stringify(hero.get("spellbook", {})) != JSON.stringify(baseline_hero.get("spellbook", {})) or JSON.stringify(hero.get("artifacts", {})) != JSON.stringify(baseline_hero.get("artifacts", {})):
		_fail("Cross-faction hero, spell, or artifact progression leaked into Fogchart.")
		return {}
	return {"session": campaign, "report": {"locked_before_rootgate": true, "unlocked_after_exact_rootgate_evidence": true, "previous_scenario_id": PREVIOUS_SCENARIO_ID, "imported_resources": expected, "imported_flag": "carryover_rootgate_toll_recorded", "verdant_grafts_transferred": false, "hero_spell_artifact_transfer": false, "opening": opening}}

func _session_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {"scenario_id": session.scenario_id, "launch_mode": session.launch_mode, "game_state": session.game_state, "hero_id": String(session.overworld.get("active_hero_id", "")), "army": session.overworld.get("army", {}), "resources": session.overworld.get("resources", {}), "active_town_placement_id": String(session.flags.get("active_town_placement_id", "")), "campaign_id": String(session.flags.get("campaign_id", "")), "campaign_previous_scenario_id": String(session.flags.get("campaign_previous_scenario_id", ""))}

func _stack_count(stacks: Variant, unit_id: String) -> int:
	if stacks is Array:
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
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index]
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _fail(message: String) -> void:
	_failed = true
	push_error("%s: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
