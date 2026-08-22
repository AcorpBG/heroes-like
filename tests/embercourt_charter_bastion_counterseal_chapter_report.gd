extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "EMBERCOURT_CHARTER_BASTION_COUNTERSEAL_CHAPTER_REPORT"
const SCENARIO_ID := "charter-bastion-counterseal"
const CAMPAIGN_ID := "campaign_frontier_claims"
const PREVIOUS_SCENARIO_ID := "halo-reserve-refraction-claim"
const HERO_ID := "hero_seren"
const PREVIOUS_HERO_ID := "hero_neral"
const ARMY_ID := "army_charter_bastion_reserve"
const PLAYER_TOWN_PLACEMENT_ID := "charter_bastion_keep"
const PLAYER_TOWN_ID := "town_highwater_keep"
const ENEMY_TOWN_PLACEMENT_ID := "halo_counterseal_front"
const ENEMY_TOWN_ID := "town_halo_spire"
const ENCOUNTER_PLACEMENT_IDS := ["counterseal_relay_pickets", "counterseal_mirror_lancers", "counterseal_aurora_battery"]
const RELAY_PICKETS_STACKS := [
	{"unit_id": "unit_sunvault_shard_wardens", "count": 7},
	{"unit_id": "unit_sunvault_prism_adepts", "count": 5},
	{"unit_id": "unit_sunvault_resonant_choristers", "count": 1},
]
const NEIGHBOR_ENCOUNTER_STACKS := {
	"counterseal_mirror_lancers": [{"unit_id": "unit_shard_guard", "count": 6}, {"unit_id": "unit_prism_adept", "count": 5}, {"unit_id": "unit_mirror_duelist", "count": 3}],
	"counterseal_aurora_battery": [{"unit_id": "unit_shard_guard", "count": 5}, {"unit_id": "unit_mirror_duelist", "count": 4}, {"unit_id": "unit_aurora_ballista", "count": 2}],
}
const REQUIRED_RESOURCE_PLACEMENT_IDS := ["charter_bastion_wood", "charter_bastion_ore", "counterseal_embergrain_granary", "counterseal_signal_post", "charter_bastion_counterseal_charter_rare_exchange", "halo_counterseal_wood", "halo_counterseal_ore", "halo_counterseal_lens_house", "charter_bastion_counterseal_halo_rare_exchange"]
const SKIRMISH_SAVE_SLOT := 2
const CAMPAIGN_SAVE_SLOT := 3

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var progression_before: Dictionary = SaveService.load_progression()
	var catalog := _assert_catalog_and_setup()
	if _failed:
		return
	var skirmish: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(skirmish)
	var opening := _assert_opening_session(skirmish, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var town := _exercise_town(skirmish)
	if _failed:
		return
	var skirmish_save := _exercise_save_restore(skirmish, SKIRMISH_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	if _failed:
		return
	var battles := _exercise_battle_entries(skirmish_save.get("session", null))
	if _failed:
		return
	var outcomes := _exercise_outcomes()
	if _failed:
		return
	var campaign := _exercise_campaign_unlock_and_import()
	if _failed:
		return
	var campaign_save := _exercise_save_restore(campaign.get("session", null), CAMPAIGN_SAVE_SLOT, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	if _failed:
		return
	if JSON.stringify(progression_before) != JSON.stringify(SaveService.load_progression()):
		_fail("Charter Bastion Counterseal focused flow mutated durable campaign progression storage.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "scenario_id": SCENARIO_ID, "catalog": catalog, "opening": opening, "town": town, "skirmish_save_resume": skirmish_save.get("report", {}), "battle_entries": battles, "outcomes": outcomes, "campaign": campaign.get("report", {}), "campaign_save_resume": campaign_save.get("report", {}), "campaign_progression_storage_unchanged": true})])
	get_tree().quit(0)

func _assert_catalog_and_setup() -> Dictionary:
	var scenario_ids: Array = ContentService.get_content_ids(ContentService.SCENARIOS_PATH)
	if scenario_ids.size() != 24 or SCENARIO_ID not in scenario_ids or scenario_ids[-1] != SCENARIO_ID:
		_fail("Active catalog did not expose Charter Bastion Counterseal as exact twenty-fourth scenario: %s" % JSON.stringify(scenario_ids))
		return {}
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	if scenario.get("selection", {}).get("availability", {}) != {"campaign": true, "skirmish": true}:
		_fail("Charter Bastion Counterseal missed exact dual-mode availability.")
		return {}
	if String(scenario.get("player_faction_id", "")) != "faction_embercourt" or String(scenario.get("hero_id", "")) != HERO_ID or String(scenario.get("player_army_id", "")) != ARMY_ID:
		_fail("Charter Bastion Counterseal changed its authored Embercourt commander or army identity.")
		return {}
	var authored_encounters: Dictionary = {}
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary:
			authored_encounters[String(encounter.get("placement_id", ""))] = encounter
	if _army_stack_contract(authored_encounters.get("counterseal_relay_pickets", {}).get("enemy_army", {}).get("stacks", [])) != RELAY_PICKETS_STACKS:
		_fail("Counterseal Relay Pickets did not retain its exact production T1/T2/T4 formation.")
		return {}
	for placement_id in NEIGHBOR_ENCOUNTER_STACKS:
		if _army_stack_contract(authored_encounters.get(placement_id, {}).get("enemy_army", {}).get("stacks", [])) != NEIGHBOR_ENCOUNTER_STACKS[placement_id]:
			_fail("Neighboring Counterseal encounter %s changed while integrating Relay Pickets." % placement_id)
			return {}
	var setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SCENARIO_ID, "normal")
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Live skirmish setup did not expose Charter Bastion Counterseal.")
		return {}
	return {"active_scenario_count": scenario_ids.size(), "campaign_available": true, "skirmish_available": true, "map_size": scenario.get("map_size", {}), "relay_pickets_stacks": RELAY_PICKETS_STACKS.duplicate(true), "neighbor_encounters_exact": true}

func _assert_opening_session(session: SessionStateStoreScript.SessionData, launch_mode: String) -> Dictionary:
	if session == null or session.scenario_id != SCENARIO_ID or session.launch_mode != launch_mode:
		_fail("ScenarioFactory did not launch Charter Bastion Counterseal in %s mode." % launch_mode)
		return {}
	if String(session.overworld.get("active_hero_id", "")) != HERO_ID:
		_fail("Seren Valechant is not the active Charter Bastion Counterseal commander.")
		return {}
	var army: Dictionary = session.overworld.get("army", {})
	if String(army.get("id", "")) != ARMY_ID or _stack_count(army.get("stacks", []), "unit_citadel_pikeward") != 2:
		_fail("Charter Bastion Counterseal opening army did not materialize: %s" % JSON.stringify(army))
		return {}
	var player_town := _town_by_placement(session, PLAYER_TOWN_PLACEMENT_ID)
	var enemy_town := _town_by_placement(session, ENEMY_TOWN_PLACEMENT_ID)
	if String(player_town.get("town_id", "")) != PLAYER_TOWN_ID or String(player_town.get("owner", "")) != "player":
		_fail("Charter Bastion did not materialize as the player town.")
		return {}
	if String(enemy_town.get("town_id", "")) != ENEMY_TOWN_ID or String(enemy_town.get("owner", "")) != "enemy":
		_fail("Halo Counterseal Front did not materialize as the hostile town.")
		return {}
	var resource_ids := []
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary:
			resource_ids.append(String(node.get("placement_id", "")))
	for placement_id in REQUIRED_RESOURCE_PLACEMENT_IDS:
		if placement_id not in resource_ids:
			_fail("Charter Bastion Counterseal session missed resource placement %s." % placement_id)
			return {}
	return {"launch_mode": launch_mode, "hero_id": HERO_ID, "army_id": ARMY_ID, "player_town_id": PLAYER_TOWN_ID, "enemy_town_id": ENEMY_TOWN_ID, "required_resource_count": REQUIRED_RESOURCE_PLACEMENT_IDS.size()}

func _exercise_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	session.flags["active_town_placement_id"] = PLAYER_TOWN_PLACEMENT_ID
	session.game_state = "town"
	if String(TownRulesScript.get_active_town(session).get("town_id", "")) != PLAYER_TOWN_ID:
		_fail("Charter Bastion could not be opened through TownRules.")
		return {}
	var build_actions: Array = TownRulesScript.get_build_actions(session)
	var recruit_action := {}
	for action in TownRulesScript.get_recruit_actions(session):
		var candidate_unit_id := String(action.get("id", "")).trim_prefix("recruit:") if action is Dictionary else ""
		var candidate_unit: Dictionary = ContentService.get_unit(candidate_unit_id)
		if action is Dictionary and String(candidate_unit.get("faction_id", "")) == "faction_embercourt" and not bool(action.get("disabled", true)):
			recruit_action = action
			break
	if build_actions.is_empty() or recruit_action.is_empty():
		_fail("Charter Bastion exposed no development or affordable Embercourt recruitment.")
		return {}
	var unit_id := String(recruit_action.get("id", "")).trim_prefix("recruit:")
	var result: Dictionary = TownRulesScript.recruit_active_town(session, unit_id, 1)
	if not bool(result.get("ok", false)):
		_fail("Charter Bastion recruit action failed: %s" % JSON.stringify(result))
		return {}
	return {"build_action_count": build_actions.size(), "recruited_unit_id": unit_id}

func _exercise_save_restore(session: SessionStateStoreScript.SessionData, slot: int, launch_mode: String) -> Dictionary:
	var before := _session_signature(session)
	if not bool(SaveService.save_runtime_manual_session(session, slot).get("ok", false)):
		_fail("Charter Bastion Counterseal %s save failed." % launch_mode)
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(slot)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(slot)
	if restored == null:
		_fail("Charter Bastion Counterseal %s save did not restore." % launch_mode)
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var after := _session_signature(restored)
	if JSON.stringify(before) != JSON.stringify(after) or restored.launch_mode != launch_mode:
		_fail("Charter Bastion Counterseal changed across %s save/restore." % launch_mode)
		return {}
	return {"session": restored, "report": {"slot": slot, "launch_mode": launch_mode, "resume_target": String(summary.get("resume_target", "")), "signature": after}}

func _exercise_battle_entries(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var rows := []
	var relay_encounter: Dictionary = {}
	for placement_id in ENCOUNTER_PLACEMENT_IDS:
		var encounter: Dictionary = _encounter_by_placement(session, placement_id)
		var battle: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
		if battle.is_empty() or String(battle.get("player_commander_state", {}).get("id", "")) != HERO_ID:
			_fail("%s did not create a Seren-owned battle payload." % placement_id)
			return {}
		var player_stacks := 0
		var enemy_stacks := 0
		for stack in battle.get("stacks", []):
			if stack is Dictionary and String(stack.get("side", "")) == "player":
				player_stacks += 1
			elif stack is Dictionary and String(stack.get("side", "")) == "enemy":
				enemy_stacks += 1
		if player_stacks != 3 or enemy_stacks != 3:
			_fail("%s battle missed exact authored stack counts." % placement_id)
			return {}
		var enemy_contract := _battle_enemy_contract(battle)
		if placement_id == "counterseal_relay_pickets":
			relay_encounter = encounter.duplicate(true)
			var expected_abilities := {
				"unit_sunvault_shard_wardens": ["shielding"],
				"unit_sunvault_prism_adepts": ["volley"],
				"unit_sunvault_resonant_choristers": ["resonance_relay", "harry"],
			}
			if _battle_unit_counts(enemy_contract) != {"unit_sunvault_shard_wardens": 7, "unit_sunvault_prism_adepts": 5, "unit_sunvault_resonant_choristers": 1} or _battle_ability_contract(enemy_contract) != expected_abilities:
				_fail("Relay Pickets public battle payload missed exact production counts or shielding/volley/Resonant Relay/Calibration Cant abilities: %s" % JSON.stringify(enemy_contract))
				return {}
		rows.append({"placement_id": placement_id, "player_stacks": player_stacks, "enemy_stacks": enemy_stacks, "enemy_contract": enemy_contract})
	if relay_encounter.is_empty():
		_fail("Counterseal Relay Pickets was unavailable for live autoplay.")
		return {}
	var sample: Dictionary = BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, relay_encounter, 72, "normal")
	var sample_profile: Dictionary = sample.get("initial_stack_profile", {})
	var sample_consequences: Dictionary = sample.get("runtime_consequence_profile", {})
	if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory" or int(sample.get("invalid_order_count", -1)) != 0:
		_fail("Production Relay Pickets autoplay did not finish as a valid player victory: %s" % JSON.stringify(sample))
		return {}
	if int(sample.get("round_reached", 0)) < 4 or int(sample.get("round_reached", 0)) > 8 or int(sample.get("player_health_remaining_pct", 0)) < 20 or int(sample.get("player_health_remaining_pct", 0)) > 80 or int(sample.get("enemy_health_remaining_pct", -1)) != 0:
		_fail("Production Relay Pickets autoplay left the authored medium player-advantaged pacing band: %s" % JSON.stringify(sample))
		return {}
	if sample_profile.get("side_ability_counts", {}).get("enemy", {}) != {"harry": 1, "resonance_relay": 1, "shielding": 1, "volley": 1}:
		_fail("Production Relay Pickets autoplay did not retain the exact live ability surface.")
		return {}
	if not bool(sample_consequences.get("has_spell_consequence", false)) or not bool(sample_consequences.get("has_status_consequence", false)) or int(sample_consequences.get("effect_observation_count", 0)) <= 0:
		_fail("Production Relay Pickets autoplay did not expose live combat consequences.")
		return {}
	return {"case_count": rows.size(), "rows": rows, "relay_autoplay": {"completed": true, "outcome_state": "victory", "round_reached": int(sample.get("round_reached", 0)), "steps_sampled": int(sample.get("steps_sampled", 0)), "invalid_order_count": 0, "player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)), "enemy_health_remaining_pct": 0, "enemy_ability_counts": sample_profile.get("side_ability_counts", {}).get("enemy", {}), "effect_observation_count": int(sample_consequences.get("effect_observation_count", 0))}}

func _army_stack_contract(stacks: Array) -> Array:
	var result: Array = []
	for stack in stacks:
		if stack is Dictionary:
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	return result

func _battle_enemy_contract(battle: Dictionary) -> Array:
	var result: Array = []
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			var ability_ids: Array = []
			for ability in stack.get("abilities", []):
				if ability is Dictionary:
					ability_ids.append(String(ability.get("id", "")))
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("base_count", 0)), "ability_ids": ability_ids})
	return result

func _battle_unit_counts(contract: Array) -> Dictionary:
	var result := {}
	for row in contract:
		if row is Dictionary:
			result[String(row.get("unit_id", ""))] = int(row.get("count", 0))
	return result

func _battle_ability_contract(contract: Array) -> Dictionary:
	var result := {}
	for row in contract:
		if row is Dictionary:
			result[String(row.get("unit_id", ""))] = row.get("ability_ids", []).duplicate()
	return result

func _exercise_outcomes() -> Dictionary:
	var victory: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_set_town_owner(victory, ENEMY_TOWN_PLACEMENT_ID, "player")
	victory.overworld["resolved_encounters"] = ENCOUNTER_PLACEMENT_IDS.duplicate()
	if String(ScenarioRulesScript.evaluate_session(victory).get("status", "")) != "victory":
		_fail("Charter Bastion Counterseal victory objectives did not resolve.")
		return {}
	var deadline: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	deadline.day = 12
	if String(ScenarioRulesScript.evaluate_session(deadline).get("status", "")) != "in_progress":
		_fail("Charter Bastion Counterseal resolved before its authored Day 13 deadline.")
		return {}
	deadline.day = 13
	if String(ScenarioRulesScript.evaluate_session(deadline).get("status", "")) != "defeat":
		_fail("Charter Bastion Counterseal Day 13 defeat boundary did not resolve.")
		return {}
	return {"victory": "reachable", "pre_deadline": "in_progress", "defeat": "reachable", "deadline_day": 13}

func _exercise_campaign_unlock_and_import() -> Dictionary:
	var profile := CampaignRulesScript.normalize_profile({})
	if not bool(CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, SCENARIO_ID).get("disabled", false)):
		_fail("Charter Bastion Counterseal unlocked before Halo victory and recorded-claim evidence.")
		return {}
	var halo: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(PREVIOUS_SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	halo.flags["halo_refraction_claim_recorded"] = true
	halo.flags["barkmantle_lens_recovered"] = true
	halo.overworld["resources"] = {"gold": 5000, "wood": 20, "ore": 20, "aetherglass": 10}
	halo.scenario_status = "victory"
	halo.scenario_summary = "Neral recorded the Halo refraction claim."
	var completed := CampaignRulesScript.record_session_completion(profile, halo)
	var action: Dictionary = CampaignRulesScript.build_chapter_action(completed, CAMPAIGN_ID, SCENARIO_ID)
	if bool(action.get("disabled", true)) or String(action.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Exact Halo victory and recorded-claim evidence did not unlock Charter Bastion Counterseal.")
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
			_fail("Halo carryover %s changed by %d instead of %d." % [resource_id, delta, int(expected[resource_id])])
			return {}
	if int(campaign.overworld.get("resources", {}).get("aetherglass", 0)) != int(baseline.overworld.get("resources", {}).get("aetherglass", 0)):
		_fail("Halo aetherglass leaked into Charter Bastion Counterseal.")
		return {}
	if not bool(campaign.flags.get("carryover_halo_refraction_claim_recorded", false)) or String(campaign.flags.get("campaign_previous_scenario_id", "")) != PREVIOUS_SCENARIO_ID:
		_fail("Charter Bastion Counterseal missed bounded Halo flag/source identity.")
		return {}
	var hero: Dictionary = campaign.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline.overworld.get("hero", {})
	var campaign_spell_ids: Array = hero.get("spellbook", {}).get("known_spell_ids", [])
	var baseline_spell_ids: Array = baseline_hero.get("spellbook", {}).get("known_spell_ids", [])
	if String(campaign.overworld.get("active_hero_id", "")) == PREVIOUS_HERO_ID or int(hero.get("level", 0)) != int(baseline_hero.get("level", 0)) or campaign_spell_ids != baseline_spell_ids or JSON.stringify(hero.get("artifacts", {})) != JSON.stringify(baseline_hero.get("artifacts", {})):
		_fail("Cross-faction hero, spell, or artifact progression leaked into Charter Bastion Counterseal.")
		return {}
	return {"session": campaign, "report": {"locked_before_halo": true, "unlocked_after_exact_halo_evidence": true, "previous_scenario_id": PREVIOUS_SCENARIO_ID, "imported_resources": expected, "imported_flag": "carryover_halo_refraction_claim_recorded", "aetherglass_transferred": false, "hero_spell_artifact_transfer": false, "opening": opening}}

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
			var town: Dictionary = towns[index].duplicate(true)
			town["owner"] = owner
			towns[index] = town
	session.overworld["towns"] = towns

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("%s: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
