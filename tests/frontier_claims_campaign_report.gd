extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FRONTIER_CLAIMS_CAMPAIGN_REPORT"
const CAMPAIGN_ID := "campaign_frontier_claims"
const MIREFORD_ID := "mireford-skirmish"
const OREVEIN_ID := "orevein-contract"
const BELLWAKE_ID := "bellwake-wreck-claim"
const ROOTGATE_ID := "rootgate-toll"
const FOGCHART_ID := "fogchart-mooring"
const CLAUSEWORKS_ID := "clauseworks-counterclaim"
const NIGHTGLASS_ID := "nightglass-ledger-reversal"
const HALO_RESERVE_ID := "halo-reserve-refraction-claim"
const CHARTER_COUNTERSEAL_ID := "charter-bastion-counterseal"
const MIREFORD_HERO_ID := "hero_thornwake_silsa_bramblehound"
const OREVEIN_HERO_ID := "hero_brasshollow_marka_ironclause"
const BELLWAKE_HERO_ID := "hero_veilmourn_ivara_blacktide"
const ROOTGATE_HERO_ID := "hero_thornwake_tova_rootwright"
const FOGCHART_HERO_ID := "hero_veilmourn_ruln_vanehook"
const CLAUSEWORKS_HERO_ID := "hero_brasshollow_oren_bellfounder"
const NIGHTGLASS_HERO_ID := "hero_mireclaw_kessa_chainboom"
const HALO_RESERVE_HERO_ID := "hero_neral"
const CHARTER_COUNTERSEAL_HERO_ID := "hero_seren"
const SAVE_SLOT := 2

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var profile := CampaignRulesScript.normalize_profile({})
	if not _assert_campaign_browser(profile):
		return

	var mireford_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		profile, MIREFORD_ID, "hard", CAMPAIGN_ID
	)
	if not _assert_campaign_session(mireford_session, MIREFORD_ID, MIREFORD_HERO_ID, "hard"):
		return
	var save_evidence := _save_restore_evidence(mireford_session)
	if save_evidence.is_empty():
		return

	mireford_session.overworld["resources"] = {
		"gold": 4000,
		"wood": 20,
		"ore": 20,
		"verdant_grafts": 10,
	}
	mireford_session.flags["ford_reavers_broken"] = true
	mireford_session.flags["silt_hunters_broken"] = true
	_mark_victory(mireford_session, "Silsa rooted the first frontier claim.")
	var after_mireford := CampaignRulesScript.record_session_completion(profile, mireford_session)
	if not _assert_unlocked(after_mireford, OREVEIN_ID):
		return

	var orevein_baseline := ScenarioFactoryScript.create_session(
		OREVEIN_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var orevein_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_mireford, OREVEIN_ID, "normal", CAMPAIGN_ID
	)
	if not _assert_campaign_session(orevein_session, OREVEIN_ID, OREVEIN_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(
		orevein_session,
		orevein_baseline,
		{"gold": 1000, "wood": 3, "ore": 3, "verdant_grafts": 2},
		"carryover_ford_reavers_broken",
		MIREFORD_ID
	):
		return
	if String(orevein_session.overworld.get("active_hero_id", "")) == MIREFORD_HERO_ID:
		_fail("Mireford commander leaked into the Brasshollow chapter.")
		return
	if not _assert_skirmish_isolation(after_mireford, OREVEIN_ID):
		return

	orevein_session.overworld["resources"] = {
		"gold": 5000,
		"wood": 20,
		"ore": 20,
		"brass_scrip": 10,
	}
	orevein_session.flags["archive_wardens_broken"] = true
	orevein_session.flags["bridgeward_levies_broken"] = true
	_mark_victory(orevein_session, "Marka stamped the second frontier claim.")
	var after_orevein := CampaignRulesScript.record_session_completion(after_mireford, orevein_session)
	if not _assert_unlocked(after_orevein, BELLWAKE_ID):
		return

	var bellwake_baseline := ScenarioFactoryScript.create_session(
		BELLWAKE_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var bellwake_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_orevein, BELLWAKE_ID, "normal", CAMPAIGN_ID
	)
	if not _assert_campaign_session(bellwake_session, BELLWAKE_ID, BELLWAKE_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(
		bellwake_session,
		bellwake_baseline,
		{"gold": 1200, "wood": 3, "ore": 3, "brass_scrip": 2},
		"carryover_archive_wardens_broken",
		OREVEIN_ID
	):
		return
	if String(bellwake_session.overworld.get("active_hero_id", "")) == OREVEIN_HERO_ID:
		_fail("Orevein commander leaked into the Veilmourn chapter.")
		return

	bellwake_session.flags["relay_pickets_broken"] = true
	bellwake_session.flags["mirror_lancers_broken"] = true
	bellwake_session.flags["drowned_chart_recorded"] = true
	bellwake_session.overworld["resources"] = {
		"gold": 5000,
		"wood": 20,
		"ore": 20,
		"memory_salt": 10,
	}
	_mark_victory(bellwake_session, "Ivara entered the third wreck claim.")
	var after_bellwake := CampaignRulesScript.record_session_completion(after_orevein, bellwake_session)
	if not _assert_unlocked(after_bellwake, ROOTGATE_ID):
		return

	var rootgate_baseline := ScenarioFactoryScript.create_session(
		ROOTGATE_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var rootgate_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_bellwake, ROOTGATE_ID, "normal", CAMPAIGN_ID
	)
	if not _assert_campaign_session(rootgate_session, ROOTGATE_ID, ROOTGATE_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(
		rootgate_session,
		rootgate_baseline,
		{"gold": 1200, "wood": 3, "ore": 3, "memory_salt": 2},
		"carryover_drowned_chart_recorded",
		BELLWAKE_ID
	):
		return
	if String(rootgate_session.overworld.get("active_hero_id", "")) == BELLWAKE_HERO_ID:
		_fail("Bellwake commander leaked into the Thornwake chapter.")
		return
	if not _assert_skirmish_isolation(after_bellwake, ROOTGATE_ID):
		return

	rootgate_session.flags["charter_guard_broken"] = true
	rootgate_session.flags["charter_bastion_reserve_broken"] = true
	rootgate_session.flags["rootgate_toll_recorded"] = true
	rootgate_session.flags["boiler_scrap_grafted"] = true
	rootgate_session.overworld["resources"] = {
		"gold": 5000,
		"wood": 20,
		"ore": 20,
		"verdant_grafts": 10,
	}
	_mark_victory(rootgate_session, "Tova rooted the fourth frontier claim.")
	var after_rootgate := CampaignRulesScript.record_session_completion(after_bellwake, rootgate_session)
	if not _assert_unlocked(after_rootgate, FOGCHART_ID):
		return

	var fogchart_baseline := ScenarioFactoryScript.create_session(
		FOGCHART_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var fogchart_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_rootgate, FOGCHART_ID, "normal", CAMPAIGN_ID
	)
	if not _assert_campaign_session(fogchart_session, FOGCHART_ID, FOGCHART_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(
		fogchart_session,
		fogchart_baseline,
		{"gold": 1000, "wood": 3, "ore": 3},
		"carryover_rootgate_toll_recorded",
		ROOTGATE_ID
	):
		return
	if int(fogchart_session.overworld.get("resources", {}).get("verdant_grafts", 0)) != int(fogchart_baseline.overworld.get("resources", {}).get("verdant_grafts", 0)):
		_fail("Rootgate verdant grafts leaked into the Veilmourn chapter.")
		return
	if String(fogchart_session.overworld.get("active_hero_id", "")) == ROOTGATE_HERO_ID:
		_fail("Rootgate commander leaked into the Fogchart chapter.")
		return
	if not _assert_skirmish_isolation(after_rootgate, FOGCHART_ID):
		return

	fogchart_session.flags["fogchart_relay_pickets_broken"] = true
	fogchart_session.flags["fogchart_mirror_lancers_broken"] = true
	fogchart_session.flags["fogchart_claim_recorded"] = true
	fogchart_session.flags["aurora_glass_salted"] = true
	fogchart_session.overworld["resources"] = {
		"gold": 5000,
		"wood": 20,
		"ore": 20,
		"memory_salt": 10,
	}
	_mark_victory(fogchart_session, "Ruln drowned the fifth frontier claim.")
	var after_fogchart := CampaignRulesScript.record_session_completion(after_rootgate, fogchart_session)
	if not _assert_unlocked(after_fogchart, CLAUSEWORKS_ID):
		return

	var clauseworks_baseline := ScenarioFactoryScript.create_session(
		CLAUSEWORKS_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var clauseworks_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		after_fogchart, CLAUSEWORKS_ID, "normal", CAMPAIGN_ID
	)
	if not _assert_campaign_session(clauseworks_session, CLAUSEWORKS_ID, CLAUSEWORKS_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(
		clauseworks_session,
		clauseworks_baseline,
		{"gold": 1000, "wood": 3, "ore": 3},
		"carryover_fogchart_claim_recorded",
		FOGCHART_ID
	):
		return
	if int(clauseworks_session.overworld.get("resources", {}).get("memory_salt", 0)) != int(clauseworks_baseline.overworld.get("resources", {}).get("memory_salt", 0)):
		_fail("Fogchart memory salt leaked into the Brasshollow chapter.")
		return
	if String(clauseworks_session.overworld.get("active_hero_id", "")) == FOGCHART_HERO_ID:
		_fail("Fogchart commander leaked into the Clauseworks chapter.")
		return
	if not _assert_skirmish_isolation(after_fogchart, CLAUSEWORKS_ID):
		return

	clauseworks_session.flags["clauseworks_archive_wardens_broken"] = true
	clauseworks_session.flags["clauseworks_bridge_levies_broken"] = true
	clauseworks_session.flags["clauseworks_claim_recorded"] = true
	clauseworks_session.flags["beacon_plate_assayed"] = true
	clauseworks_session.overworld["resources"] = {
		"gold": 5000,
		"wood": 20,
		"ore": 20,
		"brass_scrip": 10,
	}
	_mark_victory(clauseworks_session, "Oren stamped the sixth frontier claim.")
	var after_clauseworks := CampaignRulesScript.record_session_completion(after_fogchart, clauseworks_session)
	if not _assert_unlocked(after_clauseworks, NIGHTGLASS_ID):
		return

	var nightglass_baseline := ScenarioFactoryScript.create_session(NIGHTGLASS_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var nightglass_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(after_clauseworks, NIGHTGLASS_ID, "normal", CAMPAIGN_ID)
	if not _assert_campaign_session(nightglass_session, NIGHTGLASS_ID, NIGHTGLASS_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(nightglass_session, nightglass_baseline, {"gold": 1000, "wood": 3, "ore": 3}, "carryover_clauseworks_claim_recorded", CLAUSEWORKS_ID):
		return
	if int(nightglass_session.overworld.get("resources", {}).get("brass_scrip", 0)) != int(nightglass_baseline.overworld.get("resources", {}).get("brass_scrip", 0)):
		_fail("Clauseworks brass scrip leaked into the Mireclaw chapter.")
		return
	if String(nightglass_session.overworld.get("active_hero_id", "")) == CLAUSEWORKS_HERO_ID:
		_fail("Clauseworks commander leaked into the Nightglass chapter.")
		return
	if not _assert_skirmish_isolation(after_clauseworks, NIGHTGLASS_ID):
		return

	nightglass_session.flags["nightglass_ledger_guard_broken"] = true
	nightglass_session.flags["nightglass_rivet_auditors_broken"] = true
	nightglass_session.flags["nightglass_claim_recorded"] = true
	nightglass_session.flags["furnace_scrip_drowned"] = true
	nightglass_session.overworld["resources"] = {"gold": 5000, "wood": 20, "ore": 20, "peatwax": 10}
	_mark_victory(nightglass_session, "Kessa reversed the seventh frontier claim.")
	var after_nightglass := CampaignRulesScript.record_session_completion(after_clauseworks, nightglass_session)
	if not _assert_unlocked(after_nightglass, HALO_RESERVE_ID):
		return

	var halo_baseline := ScenarioFactoryScript.create_session(HALO_RESERVE_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var halo_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(after_nightglass, HALO_RESERVE_ID, "normal", CAMPAIGN_ID)
	if not _assert_campaign_session(halo_session, HALO_RESERVE_ID, HALO_RESERVE_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(halo_session, halo_baseline, {"gold": 1000, "wood": 3, "ore": 3}, "carryover_nightglass_claim_recorded", NIGHTGLASS_ID):
		return
	if int(halo_session.overworld.get("resources", {}).get("peatwax", 0)) != int(halo_baseline.overworld.get("resources", {}).get("peatwax", 0)):
		_fail("Nightglass peatwax leaked into the Sunvault chapter.")
		return
	if String(halo_session.overworld.get("active_hero_id", "")) == NIGHTGLASS_HERO_ID:
		_fail("Nightglass commander leaked into the Halo Reserve chapter.")
		return
	if not _assert_skirmish_isolation(after_nightglass, HALO_RESERVE_ID):
		return

	halo_session.flags["halo_refraction_claim_recorded"] = true
	halo_session.flags["barkmantle_lens_recovered"] = true
	halo_session.overworld["resources"] = {"gold": 5000, "wood": 20, "ore": 20, "aetherglass": 10}
	_mark_victory(halo_session, "Neral refracted the eighth frontier claim.")
	var after_halo := CampaignRulesScript.record_session_completion(after_nightglass, halo_session)
	if not _assert_unlocked(after_halo, CHARTER_COUNTERSEAL_ID):
		return

	var counterseal_baseline := ScenarioFactoryScript.create_session(CHARTER_COUNTERSEAL_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var counterseal_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(after_halo, CHARTER_COUNTERSEAL_ID, "normal", CAMPAIGN_ID)
	if not _assert_campaign_session(counterseal_session, CHARTER_COUNTERSEAL_ID, CHARTER_COUNTERSEAL_HERO_ID, "normal"):
		return
	if not _assert_cross_faction_import(counterseal_session, counterseal_baseline, {"gold": 1000, "wood": 3, "ore": 3}, "carryover_halo_refraction_claim_recorded", HALO_RESERVE_ID):
		return
	if int(counterseal_session.overworld.get("resources", {}).get("aetherglass", 0)) != int(counterseal_baseline.overworld.get("resources", {}).get("aetherglass", 0)):
		_fail("Halo aetherglass leaked into the Embercourt chapter.")
		return
	if String(counterseal_session.overworld.get("active_hero_id", "")) == HALO_RESERVE_HERO_ID:
		_fail("Halo commander leaked into the Charter Bastion chapter.")
		return
	if not _assert_skirmish_isolation(after_halo, CHARTER_COUNTERSEAL_ID):
		return

	counterseal_session.flags["charter_counterseal_recorded"] = true
	_mark_victory(counterseal_session, "Seren countersealed the ninth frontier claim.")
	var completed_profile := CampaignRulesScript.record_session_completion(after_halo, counterseal_session)
	if not _assert_completion_and_replay(completed_profile, counterseal_session):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"campaign_id": CAMPAIGN_ID,
		"chapter_ids": [MIREFORD_ID, OREVEIN_ID, BELLWAKE_ID, ROOTGATE_ID, FOGCHART_ID, CLAUSEWORKS_ID, NIGHTGLASS_ID, HALO_RESERVE_ID, CHARTER_COUNTERSEAL_ID],
		"campaign_count": CampaignRulesScript.campaign_ids().size(),
		"save_resume": save_evidence,
		"mireford_to_orevein_resources": {"gold": 1000, "wood": 3, "ore": 3, "verdant_grafts": 2},
		"orevein_to_bellwake_resources": {"gold": 1200, "wood": 3, "ore": 3, "brass_scrip": 2},
		"bellwake_to_rootgate_resources": {"gold": 1200, "wood": 3, "ore": 3, "memory_salt": 2},
		"rootgate_to_fogchart_resources": {"gold": 1000, "wood": 3, "ore": 3},
		"fogchart_to_clauseworks_resources": {"gold": 1000, "wood": 3, "ore": 3},
		"clauseworks_to_nightglass_resources": {"gold": 1000, "wood": 3, "ore": 3},
		"nightglass_to_halo_resources": {"gold": 1000, "wood": 3, "ore": 3},
		"halo_to_charter_resources": {"gold": 1000, "wood": 3, "ore": 3},
		"rootgate_rare_resource_transfer": false,
		"fogchart_rare_resource_transfer": false,
		"clauseworks_rare_resource_transfer": false,
		"nightglass_rare_resource_transfer": false,
		"halo_rare_resource_transfer": false,
		"cross_faction_hero_progression": false,
		"cross_faction_spell_progression": false,
		"cross_faction_artifact_progression": false,
		"skirmish_progression_isolated": true,
		"campaign_completed": true,
		"replay_available": true,
	})])
	get_tree().quit(0)

func _assert_campaign_browser(profile: Dictionary) -> bool:
	if CAMPAIGN_ID not in CampaignRulesScript.campaign_ids():
		_fail("Frontier Claims is missing from the live campaign roster.")
		return false
	if CampaignRulesScript.campaign_ids().size() != 6:
		_fail("Campaign roster did not expose six player-facing arcs.")
		return false
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	if String(campaign.get("starting_scenario_id", "")) != MIREFORD_ID:
		_fail("Frontier Claims did not start at Mireford.")
		return false
	var entries := CampaignRulesScript.build_campaign_chapter_entries(profile, CAMPAIGN_ID)
	if entries.size() != 9:
		_fail("Frontier Claims did not expose nine chapters: %s" % JSON.stringify(entries))
		return false
	if bool(entries[0].get("disabled", true)) or not bool(entries[1].get("disabled", false)) or not bool(entries[2].get("disabled", false)) or not bool(entries[3].get("disabled", false)) or not bool(entries[4].get("disabled", false)) or not bool(entries[5].get("disabled", false)) or not bool(entries[6].get("disabled", false)) or not bool(entries[7].get("disabled", false)) or not bool(entries[8].get("disabled", false)):
		_fail("Initial Frontier Claims locks are wrong: %s" % JSON.stringify(entries))
		return false
	var action := CampaignRulesScript.build_start_action(profile, CAMPAIGN_ID, "hard")
	if bool(action.get("disabled", true)) or String(action.get("scenario_id", "")) != MIREFORD_ID:
		_fail("Frontier Claims start action did not target Mireford: %s" % JSON.stringify(action))
		return false
	return true

func _assert_campaign_session(
	session: SessionStateStoreScript.SessionData,
	scenario_id: String,
	hero_id: String,
	difficulty: String
) -> bool:
	if session == null or session.scenario_id != scenario_id:
		_fail("Campaign session did not boot %s." % scenario_id)
		return false
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		_fail("%s did not launch in campaign mode." % scenario_id)
		return false
	if session.difficulty != difficulty or String(session.flags.get("campaign_id", "")) != CAMPAIGN_ID:
		_fail("%s missed campaign identity or selected difficulty." % scenario_id)
		return false
	if String(session.flags.get("campaign_name", "")) != "Frontier Claims" or String(session.flags.get("campaign_chapter_label", "")) == "":
		_fail("%s missed campaign display metadata." % scenario_id)
		return false
	if String(session.overworld.get("active_hero_id", "")) != hero_id:
		_fail("%s did not retain its authored faction commander." % scenario_id)
		return false
	return true

func _save_restore_evidence(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Frontier Claims campaign session did not save: %s" % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("Frontier Claims campaign session did not restore.")
		return {}
	if String(summary.get("campaign_id", "")) != CAMPAIGN_ID or String(summary.get("launch_mode", "")) != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		_fail("Saved Frontier Claims summary missed campaign metadata: %s" % JSON.stringify(summary))
		return {}
	if restored.scenario_id != MIREFORD_ID or String(restored.flags.get("campaign_id", "")) != CAMPAIGN_ID:
		_fail("Restored Frontier Claims session lost campaign identity.")
		return {}
	return {
		"slot": SAVE_SLOT,
		"scenario_id": restored.scenario_id,
		"campaign_id": String(restored.flags.get("campaign_id", "")),
		"difficulty": restored.difficulty,
		"resume_target": String(summary.get("resume_target", "")),
	}

func _assert_unlocked(profile: Dictionary, scenario_id: String) -> bool:
	var action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, scenario_id)
	if bool(action.get("disabled", true)) or String(action.get("scenario_id", "")) != scenario_id:
		_fail("Recorded campaign victory did not unlock %s: %s" % [scenario_id, JSON.stringify(action)])
		return false
	return true

func _assert_cross_faction_import(
	campaign_session: SessionStateStoreScript.SessionData,
	baseline_session: SessionStateStoreScript.SessionData,
	expected_resources: Dictionary,
	expected_flag: String,
	previous_scenario_id: String
) -> bool:
	var campaign_resources: Dictionary = campaign_session.overworld.get("resources", {})
	var baseline_resources: Dictionary = baseline_session.overworld.get("resources", {})
	for resource_id in expected_resources.keys():
		var delta := int(campaign_resources.get(resource_id, 0)) - int(baseline_resources.get(resource_id, 0))
		if delta != int(expected_resources.get(resource_id, 0)):
			_fail("Carryover resource %s changed by %d instead of %d." % [resource_id, delta, int(expected_resources.get(resource_id, 0))])
			return false
	if not bool(campaign_session.flags.get(expected_flag, false)):
		_fail("Campaign objective evidence %s was not imported." % expected_flag)
		return false
	if String(campaign_session.flags.get("campaign_previous_scenario_id", "")) != previous_scenario_id:
		_fail("Campaign carryover source scenario was not preserved.")
		return false
	var campaign_hero: Dictionary = campaign_session.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline_session.overworld.get("hero", {})
	var campaign_spell_ids: Array = campaign_hero.get("spellbook", {}).get("known_spell_ids", [])
	var baseline_spell_ids: Array = baseline_hero.get("spellbook", {}).get("known_spell_ids", [])
	if int(campaign_hero.get("level", 0)) != int(baseline_hero.get("level", 0)):
		_fail("Cross-faction hero level leaked into %s." % campaign_session.scenario_id)
		return false
	if campaign_spell_ids != baseline_spell_ids:
		_fail("Cross-faction spellbook leaked into %s." % campaign_session.scenario_id)
		return false
	if JSON.stringify(campaign_hero.get("artifacts", {})) != JSON.stringify(baseline_hero.get("artifacts", {})):
		_fail("Cross-faction artifacts leaked into %s." % campaign_session.scenario_id)
		return false
	return true

func _assert_skirmish_isolation(profile: Dictionary, scenario_id: String) -> bool:
	var before := JSON.stringify(profile)
	var setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(scenario_id, "hard")
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id, "hard", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if setup.is_empty() or session == null or session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Dual-mode scenario did not remain skirmish-launchable.")
		return false
	if session.flags.has("campaign_id") or session.flags.has("campaign_previous_scenario_id"):
		_fail("Skirmish launch imported campaign state.")
		return false
	if before != JSON.stringify(profile):
		_fail("Skirmish launch mutated campaign progression.")
		return false
	return true

func _assert_completion_and_replay(profile: Dictionary, final_session: SessionStateStoreScript.SessionData) -> bool:
	for scenario_id in [MIREFORD_ID, OREVEIN_ID, BELLWAKE_ID, ROOTGATE_ID, FOGCHART_ID, CLAUSEWORKS_ID, NIGHTGLASS_ID, HALO_RESERVE_ID, CHARTER_COUNTERSEAL_ID]:
		var record := CampaignRulesScript.get_scenario_record(profile, CAMPAIGN_ID, scenario_id)
		if String(record.get("status", "")) != "victory":
			_fail("Campaign completion missed victory record for %s." % scenario_id)
			return false
	var start_action := CampaignRulesScript.build_start_action(profile, CAMPAIGN_ID)
	if bool(start_action.get("disabled", true)) or String(start_action.get("scenario_id", "")) != CHARTER_COUNTERSEAL_ID or not String(start_action.get("label", "")).begins_with("Replay"):
		_fail("Completed campaign did not expose finale replay: %s" % JSON.stringify(start_action))
		return false
	var outcome_actions := CampaignRulesScript.build_outcome_actions(profile, final_session)
	if outcome_actions.is_empty() or String(outcome_actions[0].get("label", "")).find("Campaign Complete") < 0:
		_fail("Final outcome did not expose campaign completion: %s" % JSON.stringify(outcome_actions))
		return false
	return true

func _mark_victory(session: SessionStateStoreScript.SessionData, summary: String) -> void:
	session.scenario_status = "victory"
	session.scenario_summary = summary

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
