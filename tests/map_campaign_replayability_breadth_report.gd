extends Node

const BalanceRegressionReportRulesScript = preload("res://scripts/core/BalanceRegressionReportRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "MAP_CAMPAIGN_REPLAYABILITY_BREADTH_REPORT"
const CAMPAIGN_ID := "campaign_ninefold_survey"
const START_SCENARIO_ID := "ironbridge-stand"
const MID_SCENARIO_ID := "glassfen-breakers"
const SCENARIO_ID := "ninefold-confluence"
const SKIRMISH_ONLY_SCENARIO_ID := "mireford-skirmish"
const CAMPAIGN_SCENARIO_IDS := [START_SCENARIO_ID, MID_SCENARIO_ID, SCENARIO_ID]
const FORBIDDEN_CLAIM_TOKENS := [
	"alpha_or_parity_claim\":true",
	"parity_complete",
	"alpha_complete",
	"production_ready",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	ContentService.clear_generated_scenario_drafts()
	var profile := CampaignRulesScript.normalize_profile({})
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if scenario.is_empty():
		_fail("Missing authored breadth scenario %s." % SCENARIO_ID)
		return
	if not _assert_campaign_content(profile, scenario):
		return
	var final_ready_profile := _profile_ready_for_final_chapter(profile)
	if final_ready_profile.is_empty():
		return
	var final_action := CampaignRulesScript.build_chapter_action(final_ready_profile, CAMPAIGN_ID, SCENARIO_ID)
	if bool(final_action.get("disabled", true)) or String(final_action.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Final chapter was not unlocked by recorded campaign road: %s" % JSON.stringify(final_action))
		return
	var campaign_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(final_ready_profile, SCENARIO_ID, "hard", CAMPAIGN_ID)
	if not _assert_authored_session(campaign_session, true):
		return
	if not _assert_faction_hooks(scenario, campaign_session):
		return
	var skirmish_setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SCENARIO_ID, "hard")
	if not _assert_skirmish_setup(skirmish_setup):
		return
	var skirmish_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_skirmish_session(SCENARIO_ID, "hard")
	if not _assert_authored_session(skirmish_session, false):
		return
	var skirmish_only_setup: Dictionary = ScenarioSelectRulesScript.build_skirmish_setup(SKIRMISH_ONLY_SCENARIO_ID, "normal")
	if not _assert_skirmish_only_setup(skirmish_only_setup):
		return
	var skirmish_only_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_skirmish_session(SKIRMISH_ONLY_SCENARIO_ID, "normal")
	if not _assert_skirmish_only_session(skirmish_only_session):
		return
	var replay_profile := _profile_after_recorded_victory(final_ready_profile, campaign_session)
	if not _assert_recorded_replay(final_ready_profile, replay_profile):
		return
	var random_map_evidence := _random_map_provenance_evidence()
	if random_map_evidence.is_empty():
		return
	var balance_evidence := _balance_reflection_evidence()
	if balance_evidence.is_empty():
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": "map_campaign_replayability_breadth_report_v1",
		"campaign_id": CAMPAIGN_ID,
		"scenario_id": SCENARIO_ID,
		"map_size": campaign_session.overworld.get("map_size", {}),
		"town_count": campaign_session.overworld.get("towns", []).size(),
		"resource_node_count": campaign_session.overworld.get("resource_nodes", []).size(),
		"enemy_state_count": campaign_session.overworld.get("enemy_states", []).size(),
		"skirmish_setup": {
			"scenario_id": skirmish_setup.get("scenario_id", ""),
			"difficulty": skirmish_setup.get("difficulty", ""),
			"recommended_difficulty": skirmish_setup.get("recommended_difficulty", ""),
			"skirmish_only_scenario_id": skirmish_only_setup.get("scenario_id", ""),
		},
		"campaign_replay": {
			"browser_campaign_count": CampaignRulesScript.campaign_ids().size(),
			"chapter_count": CampaignRulesScript.build_campaign_chapter_entries(replay_profile, CAMPAIGN_ID).size(),
			"post_victory_action": CampaignRulesScript.build_start_action(replay_profile, CAMPAIGN_ID).get("label", ""),
			"starting_scenario_id": START_SCENARIO_ID,
			"final_scenario_id": SCENARIO_ID,
		},
		"random_map_provenance": random_map_evidence,
		"balance_reflection": balance_evidence,
		"boundary": {
			"authored_campaign_record": true,
			"authored_skirmish_record": true,
			"generated_campaign_adoption": false,
			"generated_authored_content_writeback": false,
			"alpha_or_parity_claim": false,
		},
	}
	var compact_text := JSON.stringify(payload).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if compact_text.contains(String(token)):
			_fail("Report payload contains forbidden claim token: %s." % token)
			return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_campaign_content(profile: Dictionary, scenario: Dictionary) -> bool:
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	if campaign.is_empty():
		_fail("Missing campaign %s." % CAMPAIGN_ID)
		return false
	if String(campaign.get("starting_scenario_id", "")) != START_SCENARIO_ID:
		_fail("Campaign %s does not start on %s." % [CAMPAIGN_ID, START_SCENARIO_ID])
		return false
	for campaign_scenario_id in CAMPAIGN_SCENARIO_IDS:
		var campaign_scenario := ContentService.get_scenario(String(campaign_scenario_id))
		if campaign_scenario.is_empty():
			_fail("Missing campaign scenario %s." % campaign_scenario_id)
			return false
		var selection: Dictionary = campaign_scenario.get("selection", {}) if campaign_scenario.get("selection", {}) is Dictionary else {}
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if not bool(availability.get("campaign", false)) or not bool(availability.get("skirmish", false)):
			_fail("%s must remain both campaign and skirmish selectable." % campaign_scenario_id)
			return false
		if CampaignRulesScript.get_campaign_id_for_scenario(String(campaign_scenario_id)) != CAMPAIGN_ID:
			_fail("%s is not wired to the new campaign docket." % campaign_scenario_id)
			return false
	var browser_seen := false
	for entry in CampaignRulesScript.build_campaign_browser_entries(profile):
		if entry is Dictionary and String(entry.get("campaign_id", "")) == CAMPAIGN_ID:
			browser_seen = true
			if bool(entry.get("selected", false)):
				break
	if not browser_seen:
		_fail("Campaign browser did not expose %s." % CAMPAIGN_ID)
		return false
	var chapter_entries := CampaignRulesScript.build_campaign_chapter_entries(profile, CAMPAIGN_ID)
	if chapter_entries.size() != 3:
		_fail("Campaign chapter entries did not expose three authored chapters: %s" % JSON.stringify(chapter_entries))
		return false
	if bool(chapter_entries[0].get("disabled", true)) or String(chapter_entries[0].get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Opening chapter entry is not unlocked: %s" % JSON.stringify(chapter_entries))
		return false
	if not bool(chapter_entries[1].get("disabled", false)) or not bool(chapter_entries[2].get("disabled", false)):
		_fail("Downstream chapters unlocked before recorded victories: %s" % JSON.stringify(chapter_entries))
		return false
	var action := CampaignRulesScript.build_start_action(profile, CAMPAIGN_ID)
	if bool(action.get("disabled", true)) or String(action.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Campaign start action did not target %s: %s" % [START_SCENARIO_ID, JSON.stringify(action)])
		return false
	return true

func _assert_authored_session(session: SessionStateStoreScript.SessionData, expect_campaign: bool) -> bool:
	if session == null or session.scenario_id != SCENARIO_ID:
		_fail("Authored session did not boot %s." % SCENARIO_ID)
		return false
	OverworldRules.normalize_overworld_state(session)
	var map_size := OverworldRules.derive_map_size(session)
	if map_size != Vector2i(64, 64):
		_fail("Authored session map size changed: %s." % map_size)
		return false
	if session.overworld.get("towns", []).size() < 6 or session.overworld.get("resource_nodes", []).size() < 47 or session.overworld.get("enemy_states", []).size() < 5:
		_fail("Authored session missed breadth state: towns %d resources %d enemy states %d." % [
			session.overworld.get("towns", []).size(),
			session.overworld.get("resource_nodes", []).size(),
			session.overworld.get("enemy_states", []).size(),
		])
		return false
	if session.overworld.get("terrain_layers", {}).is_empty():
		_fail("Authored session missed terrain layers.")
		return false
	if expect_campaign:
		if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN or String(session.flags.get("campaign_id", "")) != CAMPAIGN_ID:
			_fail("Campaign session missed campaign launch flags: %s / %s." % [session.launch_mode, JSON.stringify(session.flags)])
			return false
	else:
		if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH or session.flags.has("campaign_id"):
			_fail("Skirmish session crossed into campaign flags: %s / %s." % [session.launch_mode, JSON.stringify(session.flags)])
			return false
	return true

func _assert_faction_hooks(scenario: Dictionary, session: SessionStateStoreScript.SessionData) -> bool:
	var expected_enemy_factions := ["faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]
	if ContentService.get_faction(String(scenario.get("player_faction_id", ""))).is_empty():
		_fail("Player faction hook is missing.")
		return false
	if ContentService.get_hero(String(scenario.get("hero_id", ""))).is_empty():
		_fail("Scenario hero hook is missing.")
		return false
	for faction_id in expected_enemy_factions:
		if ContentService.get_faction(faction_id).is_empty():
			_fail("Missing expected rival faction %s." % faction_id)
			return false
		if _enemy_config_for_faction(scenario, faction_id).is_empty():
			_fail("Scenario missed enemy pressure config for %s." % faction_id)
			return false
	for town_state in session.overworld.get("towns", []):
		if not (town_state is Dictionary):
			continue
		var town := ContentService.get_town(String(town_state.get("town_id", "")))
		if town.is_empty():
			_fail("Session town references missing town template: %s." % JSON.stringify(town_state))
			return false
		var faction := ContentService.get_faction(String(town.get("faction_id", "")))
		if faction.is_empty() or String(town.get("id", "")) not in faction.get("town_ids", []):
			_fail("Town/faction hook is incoherent: %s / %s." % [JSON.stringify(town), JSON.stringify(faction)])
			return false
		if (town_state.get("available_recruits", {}) if town_state.get("available_recruits", {}) is Dictionary else {}).is_empty():
			_fail("Town state missed seeded recruits: %s." % JSON.stringify(town_state))
			return false
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and ContentService.get_unit(String(stack.get("unit_id", ""))).is_empty():
			_fail("Player army stack references missing unit: %s." % JSON.stringify(stack))
			return false
	return true

func _assert_skirmish_setup(setup: Dictionary) -> bool:
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Skirmish setup did not expose %s: %s" % [SCENARIO_ID, JSON.stringify(setup)])
		return false
	if String(setup.get("difficulty", "")) != "hard" or String(setup.get("recommended_difficulty", "")) != "hard":
		_fail("Skirmish setup difficulty metadata changed: %s" % JSON.stringify(setup))
		return false
	var consequence := String(setup.get("action_consequence", ""))
	if consequence.find("does not change campaign progression") < 0:
		_fail("Skirmish setup did not preserve campaign-progress boundary.")
		return false
	return true

func _assert_skirmish_only_setup(setup: Dictionary) -> bool:
	if setup.is_empty() or String(setup.get("scenario_id", "")) != SKIRMISH_ONLY_SCENARIO_ID:
		_fail("Skirmish-only setup did not expose %s: %s" % [SKIRMISH_ONLY_SCENARIO_ID, JSON.stringify(setup)])
		return false
	if String(setup.get("difficulty", "")) != "normal" or String(setup.get("recommended_difficulty", "")) != "normal":
		_fail("Skirmish-only setup difficulty metadata changed: %s" % JSON.stringify(setup))
		return false
	var scenario := ContentService.get_scenario(SKIRMISH_ONLY_SCENARIO_ID)
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	if bool(availability.get("campaign", true)) or not bool(availability.get("skirmish", false)):
		_fail("Skirmish-only scenario crossed campaign availability: %s" % JSON.stringify(availability))
		return false
	if CampaignRulesScript.get_campaign_id_for_scenario(SKIRMISH_ONLY_SCENARIO_ID) != "":
		_fail("Skirmish-only scenario was wired into campaign content.")
		return false
	return true

func _assert_skirmish_only_session(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.scenario_id != SKIRMISH_ONLY_SCENARIO_ID:
		_fail("Skirmish-only session did not boot %s." % SKIRMISH_ONLY_SCENARIO_ID)
		return false
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH or session.flags.has("campaign_id"):
		_fail("Skirmish-only session crossed into campaign flags: %s / %s." % [session.launch_mode, JSON.stringify(session.flags)])
		return false
	OverworldRules.normalize_overworld_state(session)
	if OverworldRules.derive_map_size(session) != Vector2i(10, 6):
		_fail("Skirmish-only map size changed.")
		return false
	if session.overworld.get("towns", []).size() < 2 or session.overworld.get("enemy_states", []).size() < 1:
		_fail("Skirmish-only session missed town or enemy state coverage.")
		return false
	return true

func _profile_after_recorded_victory(profile: Dictionary, session: SessionStateStoreScript.SessionData) -> Dictionary:
	var completed_session := session
	completed_session.scenario_status = "victory"
	completed_session.scenario_summary = "Ninefold survey docket validated by focused report."
	return CampaignRulesScript.record_session_completion(profile, completed_session)

func _profile_ready_for_final_chapter(profile: Dictionary) -> Dictionary:
	var ironbridge_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(profile, START_SCENARIO_ID, "normal", CAMPAIGN_ID)
	if ironbridge_session == null or ironbridge_session.scenario_id != START_SCENARIO_ID:
		_fail("Opening campaign session failed to boot.")
		return {}
	ironbridge_session.scenario_status = "victory"
	ironbridge_session.scenario_summary = "Ironbridge road opened by focused replayability report."
	ironbridge_session.flags["ford_reavers_broken"] = true
	ironbridge_session.flags["silt_hunters_broken"] = true
	var after_ironbridge := CampaignRulesScript.record_session_completion(profile, ironbridge_session)
	var mid_action := CampaignRulesScript.build_chapter_action(after_ironbridge, CAMPAIGN_ID, MID_SCENARIO_ID)
	if bool(mid_action.get("disabled", true)) or String(mid_action.get("scenario_id", "")) != MID_SCENARIO_ID:
		_fail("Middle chapter was not unlocked by Ironbridge record: %s" % JSON.stringify(mid_action))
		return {}

	var glassfen_session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(after_ironbridge, MID_SCENARIO_ID, "hard", CAMPAIGN_ID)
	if glassfen_session == null or glassfen_session.scenario_id != MID_SCENARIO_ID:
		_fail("Middle campaign session failed to boot.")
		return {}
	glassfen_session.scenario_status = "victory"
	glassfen_session.scenario_summary = "Glassfen relay line broken by focused replayability report."
	glassfen_session.flags["relay_pickets_broken"] = true
	glassfen_session.flags["aurora_battery_broken"] = true
	return CampaignRulesScript.record_session_completion(after_ironbridge, glassfen_session)

func _assert_recorded_replay(base_profile: Dictionary, replay_profile: Dictionary) -> bool:
	var record := CampaignRulesScript.get_scenario_record(replay_profile, CAMPAIGN_ID, SCENARIO_ID)
	if String(record.get("status", "")) != "victory":
		_fail("Recorded campaign profile did not store victory: %s" % JSON.stringify(record))
		return false
	var start_action := CampaignRulesScript.build_start_action(replay_profile, CAMPAIGN_ID)
	if String(start_action.get("label", "")).find("Replay") < 0:
		_fail("Completed campaign did not offer replay: %s" % JSON.stringify(start_action))
		return false
	var actions := CampaignRulesScript.build_outcome_actions(replay_profile, _completed_session_for_actions(base_profile))
	var saw_replay := false
	for action in actions:
		if action is Dictionary and String(action.get("label", "")).find("Replay") >= 0:
			saw_replay = true
	if not saw_replay:
		_fail("Outcome actions did not expose replay after completion: %s" % JSON.stringify(actions))
		return false
	return true

func _completed_session_for_actions(profile: Dictionary) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(profile, SCENARIO_ID, "hard", CAMPAIGN_ID)
	session.scenario_status = "victory"
	session.scenario_summary = "Ninefold survey docket validated by focused report."
	return session

func _random_map_provenance_evidence() -> Dictionary:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "map-campaign-replayability-10184",
		"size": {"preset": "map_campaign_replayability", "width": 24, "height": 16, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")
	if not bool(setup.get("ok", false)):
		_fail("Generated skirmish setup failed: %s" % JSON.stringify(setup))
		return {}
	var scenario_id := String(setup.get("scenario_id", ""))
	if ContentService.has_authored_scenario(scenario_id) or _appears_in_campaign_content(scenario_id):
		_fail("Generated scenario crossed into authored campaign content: %s." % scenario_id)
		return {}
	var provenance: Dictionary = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	if bool(provenance.get("campaign_adoption", true)) or bool(provenance.get("authored_content_writeback", true)) or bool(provenance.get("alpha_parity_claim", true)):
		_fail("Generated provenance crossed forbidden boundaries: %s" % JSON.stringify(provenance))
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session(config, "normal")
	if session == null or session.scenario_id != scenario_id or session.flags.has("campaign_id"):
		_fail("Generated skirmish session missed identity or gained campaign flags.")
		return {}
	if String(session.flags.get("generated_random_map_boundary", {}).get("adoption_path", "")) != "skirmish_session_only_no_authored_browser_or_campaign":
		_fail("Generated skirmish adoption boundary changed: %s" % JSON.stringify(session.flags.get("generated_random_map_boundary", {})))
		return {}
	ContentService.clear_generated_scenario_drafts()
	return {
		"scenario_id": scenario_id,
		"template_id": setup.get("template_id", ""),
		"profile_id": setup.get("profile_id", ""),
		"normalized_seed": setup.get("normalized_seed", ""),
		"validation_status": setup.get("validation", {}).get("status", ""),
		"replay_boundary": setup.get("replay_metadata", {}).get("replay_boundary", ""),
		"campaign_adoption": false,
		"authored_content_writeback": false,
	}

func _balance_reflection_evidence() -> Dictionary:
	var report: Dictionary = BalanceRegressionReportRulesScript.build_report()
	if not bool(report.get("ok", false)):
		_fail("Balance regression report failed: %s" % JSON.stringify(report))
		return {}
	var policy: Dictionary = report.get("reporting_policy", {}) if report.get("reporting_policy", {}) is Dictionary else {}
	if bool(policy.get("alpha_or_parity_claim", true)) or bool(policy.get("authored_content_writeback", true)):
		_fail("Balance report crossed report-only boundary: %s" % JSON.stringify(policy))
		return {}
	var scenario_row := _balance_scenario_row(report, SCENARIO_ID)
	if scenario_row.is_empty() or not bool(scenario_row.get("available_campaign", false)) or not bool(scenario_row.get("available_skirmish", false)):
		_fail("Balance scenario viability did not reflect campaign+skirmish breadth: %s" % JSON.stringify(scenario_row))
		return {}
	return {
		"schema_id": report.get("schema_id", ""),
		"suite_signature": report.get("suite_signature", ""),
		"scenario_id": SCENARIO_ID,
		"available_campaign": scenario_row.get("available_campaign", false),
		"available_skirmish": scenario_row.get("available_skirmish", false),
		"town_count": scenario_row.get("town_count", 0),
	}

func _balance_scenario_row(report: Dictionary, scenario_id: String) -> Dictionary:
	for section in report.get("sections", []):
		if not (section is Dictionary) or String(section.get("section_id", "")) != "scenario_viability":
			continue
		var evidence: Dictionary = section.get("evidence", {}) if section.get("evidence", {}) is Dictionary else {}
		for row in evidence.get("authored_scenarios", []):
			if row is Dictionary and String(row.get("scenario_id", "")) == scenario_id:
				return row
	return {}

func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

func _appears_in_campaign_content(scenario_id: String) -> bool:
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for scenario_entry in campaign.get("scenarios", []):
			if scenario_entry is Dictionary and String(scenario_entry.get("scenario_id", "")) == scenario_id:
				return true
	return false

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
