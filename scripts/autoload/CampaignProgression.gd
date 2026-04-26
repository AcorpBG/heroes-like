class_name HeroesCampaignProgression
extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

var profile: Dictionary = {}

func _ready() -> void:
	load_profile()

func ensure_profile() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile

func load_profile() -> void:
	profile = CampaignRulesScript.normalize_profile(SaveService.load_progression())

func save_profile() -> void:
	SaveService.save_progression(ensure_profile())

func selected_campaign_id() -> String:
	return CampaignRulesScript.selected_campaign_id(ensure_profile())

func selected_scenario_id(campaign_id: String = "") -> String:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.selected_scenario_id(ensure_profile(), resolved_campaign_id)

func select_campaign(campaign_id: String) -> void:
	profile = CampaignRulesScript.mark_selected_campaign(ensure_profile(), campaign_id)
	save_profile()

func select_scenario(campaign_id: String, scenario_id: String) -> void:
	profile = CampaignRulesScript.mark_selected_scenario(ensure_profile(), scenario_id, campaign_id)
	save_profile()

func campaign_browser_entries() -> Array:
	return CampaignRulesScript.build_campaign_browser_entries(ensure_profile())

func campaign_details(campaign_id: String = "") -> String:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.describe_campaign_details(ensure_profile(), resolved_campaign_id)

func campaign_arc_status(campaign_id: String = "") -> String:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.describe_campaign_arc_status(ensure_profile(), resolved_campaign_id)

func campaign_journal(campaign_id: String = "") -> String:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.describe_campaign_journal(ensure_profile(), resolved_campaign_id)

func campaign_chapter_entries(campaign_id: String = "") -> Array:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.build_campaign_chapter_entries(ensure_profile(), resolved_campaign_id)

func chapter_details(campaign_id: String, scenario_id: String) -> String:
	return CampaignRulesScript.describe_campaign_chapter(ensure_profile(), campaign_id, scenario_id)

func chapter_commander_preview(campaign_id: String, scenario_id: String) -> String:
	return CampaignRulesScript.describe_campaign_commander_preview(ensure_profile(), campaign_id, scenario_id)

func chapter_operational_board(campaign_id: String, scenario_id: String) -> String:
	return CampaignRulesScript.describe_campaign_operational_board(ensure_profile(), campaign_id, scenario_id)

func primary_campaign_action(campaign_id: String = "") -> Dictionary:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.build_start_action(ensure_profile(), resolved_campaign_id)

func chapter_action(campaign_id: String, scenario_id: String) -> Dictionary:
	return CampaignRulesScript.build_chapter_action(ensure_profile(), campaign_id, scenario_id)

func campaign_id_for_session(session: SessionStateStoreScript.SessionData) -> String:
	return CampaignRulesScript.campaign_id_for_session_bridge(session)

func outcome_recap(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return CampaignRulesScript.build_outcome_recap_bridge(ensure_profile(), session)

func outcome_continuity_choice(session: SessionStateStoreScript.SessionData) -> String:
	return CampaignRulesScript.build_outcome_continuity_choice_bridge(ensure_profile(), session)

func outcome_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return CampaignRulesScript.build_outcome_actions_bridge(ensure_profile(), session)

func describe_default_campaign() -> String:
	return CampaignRulesScript.describe_campaign(ensure_profile(), selected_campaign_id())

func default_start_action() -> Dictionary:
	return CampaignRulesScript.build_start_action(ensure_profile(), selected_campaign_id())

func default_campaign_actions() -> Array:
	return CampaignRulesScript.build_menu_actions(ensure_profile(), selected_campaign_id())

func start_default_scenario(difficulty: String = "normal") -> SessionStateStoreScript.SessionData:
	var campaign_id := selected_campaign_id()
	var scenario_id: String = CampaignRulesScript.first_available_scenario(ensure_profile(), campaign_id)
	return start_scenario(scenario_id, difficulty, campaign_id)

func start_primary_campaign_scenario(campaign_id: String, difficulty: String = "normal") -> SessionStateStoreScript.SessionData:
	var scenario_id: String = CampaignRulesScript.first_available_scenario(ensure_profile(), campaign_id)
	return start_scenario(scenario_id, difficulty, campaign_id)

func start_scenario(scenario_id: String, difficulty: String = "normal", campaign_id: String = "") -> SessionStateStoreScript.SessionData:
	if scenario_id == "":
		push_warning("No scenario is available to start.")
		return SessionStateStoreScript.new_session_data()

	var resolved_campaign_id: String = campaign_id if campaign_id != "" else CampaignRulesScript.get_campaign_id_for_scenario(scenario_id)
	if resolved_campaign_id != "" and not CampaignRulesScript.is_scenario_unlocked(ensure_profile(), resolved_campaign_id, scenario_id):
		push_warning("Scenario %s is still locked in campaign %s." % [scenario_id, resolved_campaign_id])
		return SessionStateStoreScript.new_session_data()

	profile = CampaignRulesScript.mark_selected_scenario(ensure_profile(), scenario_id, resolved_campaign_id)
	save_profile()

	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session_bridge(
		profile,
		scenario_id,
		ScenarioSelectRulesScript.normalize_difficulty(difficulty),
		resolved_campaign_id
	)
	SessionState.active_session = session
	return session

func record_session_completion(session: SessionStateStoreScript.SessionData) -> void:
	profile = CampaignRulesScript.record_session_completion_bridge(ensure_profile(), session)
	save_profile()
