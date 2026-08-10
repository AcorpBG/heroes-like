class_name HeroesCampaignProgression
extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const STORAGE_BLOCKED_MESSAGE := "Campaign progress is unavailable. Existing data was preserved and cannot be overwritten."
const LOAD_FAILED_MESSAGE := "Campaign progress could not be loaded. Existing in-memory progress remains unchanged."
const SAVE_FAILED_MESSAGE := "Campaign progression could not be saved. Existing progress remains unchanged."

var profile: Dictionary = {}
var _storage_state: Dictionary = {}
var _storage_warning := ""
var _last_failure_result: Dictionary = {}
var _last_storage_warning_signature := ""

func _ready() -> void:
	load_profile()

func ensure_profile() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile

func load_profile() -> Dictionary:
	var inspection := _refresh_storage_state()
	if _storage_is_blocked(inspection):
		return _blocked_storage_result("load_profile")
	var loaded_profile: Dictionary = SaveService.load_progression()
	if loaded_profile.is_empty() and String(inspection.get("status", "")) != "missing":
		inspection = _refresh_storage_state()
		if _storage_is_blocked(inspection):
			return _blocked_storage_result("load_profile")
		return _set_failure_result({
			"ok": false,
			"changed": false,
			"path": "",
			"operation": "load_profile",
			"reason": "load_failed",
			"message": LOAD_FAILED_MESSAGE,
			"storage_state": inspection,
		})
	var next_profile := CampaignRulesScript.normalize_profile(loaded_profile)
	var changed := next_profile != profile
	profile = next_profile
	_last_failure_result = {}
	return _success_result("load_profile", changed, "loaded")

func save_profile() -> Dictionary:
	var prior_profile := ensure_profile()
	if is_storage_blocked():
		return _blocked_storage_result("save_profile")
	var next_profile := CampaignRulesScript.normalize_profile(prior_profile.duplicate(true))
	var save_result := _save_candidate_profile(next_profile, "save_profile")
	if not bool(save_result.get("ok", false)):
		return save_result
	profile = next_profile
	return save_result

func storage_state() -> Dictionary:
	if _storage_state.is_empty():
		_refresh_storage_state()
	return _storage_state.duplicate(true)

func is_storage_blocked() -> bool:
	return _storage_is_blocked(_refresh_storage_state())

func is_blocked() -> bool:
	return is_storage_blocked()

func storage_warning() -> String:
	if _storage_state.is_empty():
		_refresh_storage_state()
	return _storage_warning

func last_failure_result() -> Dictionary:
	return _last_failure_result.duplicate(true)

func failure_result() -> Dictionary:
	return last_failure_result()

func selected_campaign_id() -> String:
	return CampaignRulesScript.selected_campaign_id(ensure_profile())

func selected_scenario_id(campaign_id: String = "") -> String:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.selected_scenario_id(ensure_profile(), resolved_campaign_id)

func select_campaign(campaign_id: String) -> Dictionary:
	if is_storage_blocked():
		return _blocked_storage_result("select_campaign", {"campaign_id": campaign_id})
	var prior_profile := ensure_profile()
	var next_profile := CampaignRulesScript.mark_selected_campaign(prior_profile, campaign_id)
	var result := _save_candidate_profile(next_profile, "select_campaign", next_profile != prior_profile)
	result["campaign_id"] = campaign_id
	if bool(result.get("ok", false)):
		profile = next_profile
	return result

func select_scenario(campaign_id: String, scenario_id: String) -> Dictionary:
	if is_storage_blocked():
		return _blocked_storage_result("select_scenario", {
			"campaign_id": campaign_id,
			"scenario_id": scenario_id,
		})
	var prior_profile := ensure_profile()
	var next_profile := CampaignRulesScript.mark_selected_scenario(prior_profile, scenario_id, campaign_id)
	var result := _save_candidate_profile(next_profile, "select_scenario", next_profile != prior_profile)
	result["campaign_id"] = campaign_id
	result["scenario_id"] = scenario_id
	if bool(result.get("ok", false)):
		profile = next_profile
	return result

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

func campaign_restart_action(campaign_id: String = "") -> Dictionary:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.build_restart_action(ensure_profile(), resolved_campaign_id)

func restart_campaign(campaign_id: String = "") -> Dictionary:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	if is_storage_blocked():
		return _blocked_storage_result("restart_campaign", {"campaign_id": resolved_campaign_id})
	var action := CampaignRulesScript.build_restart_action(ensure_profile(), resolved_campaign_id)
	if bool(action.get("disabled", true)):
		return {
			"ok": false,
			"changed": false,
			"reason": "restart_unavailable",
			"campaign_id": resolved_campaign_id,
			"message": String(action.get("summary", "Campaign arc has no recorded progress.")),
		}
	var next_profile := CampaignRulesScript.reset_campaign(ensure_profile(), resolved_campaign_id)
	var save_result := _save_candidate_profile(next_profile, "restart_campaign")
	if not bool(save_result.get("ok", false)):
		save_result["campaign_id"] = resolved_campaign_id
		if String(save_result.get("reason", "")) == "save_failed":
			save_result["message"] = "Campaign progression could not be saved; the arc was not restarted."
		_last_failure_result = save_result.duplicate(true)
		return save_result
	profile = next_profile
	return {
		"ok": true,
		"changed": true,
		"reason": "restarted",
		"path": String(save_result.get("path", "")),
		"campaign_id": resolved_campaign_id,
		"starting_scenario_id": CampaignRulesScript.selected_scenario_id(profile, resolved_campaign_id),
		"message": "%s restarted from %s." % [
			String(action.get("campaign_name", resolved_campaign_id)),
			String(action.get("starting_label", "Chapter I")),
		],
	}

func chapter_details(campaign_id: String, scenario_id: String, difficulty: String = "normal") -> String:
	return CampaignRulesScript.describe_campaign_chapter(ensure_profile(), campaign_id, scenario_id, difficulty)

func chapter_commander_preview(campaign_id: String, scenario_id: String, difficulty: String = "normal") -> String:
	return CampaignRulesScript.describe_campaign_commander_preview(ensure_profile(), campaign_id, scenario_id, difficulty)

func chapter_operational_board(campaign_id: String, scenario_id: String, difficulty: String = "normal") -> String:
	return CampaignRulesScript.describe_campaign_operational_board(ensure_profile(), campaign_id, scenario_id, difficulty)

func primary_campaign_action(campaign_id: String = "", difficulty: String = "normal") -> Dictionary:
	var resolved_campaign_id := campaign_id if campaign_id != "" else selected_campaign_id()
	return CampaignRulesScript.build_start_action(ensure_profile(), resolved_campaign_id, difficulty)

func chapter_action(campaign_id: String, scenario_id: String, difficulty: String = "normal") -> Dictionary:
	return CampaignRulesScript.build_chapter_action(ensure_profile(), campaign_id, scenario_id, difficulty)

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
	if is_storage_blocked():
		_blocked_storage_result("start_scenario", {
			"campaign_id": campaign_id,
			"scenario_id": scenario_id,
		})
		return SessionStateStoreScript.new_session_data()
	if scenario_id == "":
		push_warning("No scenario is available to start.")
		_set_failure_result({
			"ok": false,
			"changed": false,
			"reason": "scenario_unavailable",
			"campaign_id": campaign_id,
			"scenario_id": scenario_id,
			"message": "No scenario is available to start.",
		})
		return SessionStateStoreScript.new_session_data()

	var resolved_campaign_id: String = campaign_id if campaign_id != "" else CampaignRulesScript.get_campaign_id_for_scenario(scenario_id)
	if resolved_campaign_id != "" and not CampaignRulesScript.is_scenario_unlocked(ensure_profile(), resolved_campaign_id, scenario_id):
		push_warning("Scenario %s is still locked in campaign %s." % [scenario_id, resolved_campaign_id])
		_set_failure_result({
			"ok": false,
			"changed": false,
			"reason": "scenario_locked",
			"campaign_id": resolved_campaign_id,
			"scenario_id": scenario_id,
			"message": "The requested campaign chapter is still locked.",
		})
		return SessionStateStoreScript.new_session_data()

	var prior_profile := ensure_profile()
	var next_profile := CampaignRulesScript.mark_selected_scenario(prior_profile, scenario_id, resolved_campaign_id)
	var save_result := _save_candidate_profile(next_profile, "start_scenario", next_profile != prior_profile)
	if not bool(save_result.get("ok", false)):
		save_result["campaign_id"] = resolved_campaign_id
		save_result["scenario_id"] = scenario_id
		_set_failure_result(save_result)
		return SessionStateStoreScript.new_session_data()

	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session_bridge(
		next_profile,
		scenario_id,
		ScenarioSelectRulesScript.normalize_difficulty(difficulty),
		resolved_campaign_id
	)
	profile = next_profile
	SessionState.active_session = session
	_last_failure_result = {}
	return session

func record_session_completion(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if is_storage_blocked():
		return _blocked_storage_result("record_session_completion", {
			"campaign_id": CampaignRulesScript.campaign_id_for_session_bridge(session),
			"scenario_id": session.scenario_id,
		})
	var next_profile: Dictionary = CampaignRulesScript.record_session_completion_bridge(ensure_profile(), session)
	var save_result := _save_candidate_profile(next_profile, "record_session_completion")
	if not bool(save_result.get("ok", false)):
		if String(save_result.get("reason", "")) == "save_failed":
			save_result["message"] = "Campaign progression could not be saved. The chapter remains active and will retry completion."
		_last_failure_result = save_result.duplicate(true)
		return save_result
	profile = next_profile
	return {
		"ok": true,
		"changed": true,
		"reason": "recorded",
		"path": String(save_result.get("path", "")),
		"message": "",
	}

func _save_candidate_profile(
	next_profile: Dictionary,
	operation: String,
	changed: bool = true
) -> Dictionary:
	var inspection := _refresh_storage_state()
	if _storage_is_blocked(inspection):
		return _blocked_storage_result(operation)
	var saved_path := SaveService.save_progression(next_profile.duplicate(true))
	if saved_path == "":
		inspection = _refresh_storage_state()
		if _storage_is_blocked(inspection):
			return _blocked_storage_result(operation)
		return _set_failure_result({
			"ok": false,
			"changed": false,
			"path": "",
			"operation": operation,
			"reason": "save_failed",
			"message": SAVE_FAILED_MESSAGE,
			"storage_state": storage_state(),
		})
	_refresh_storage_state()
	_last_failure_result = {}
	return {
		"ok": true,
		"changed": changed,
		"path": saved_path,
		"operation": operation,
		"reason": "saved",
		"message": "",
		"storage_state": storage_state(),
	}

func _refresh_storage_state() -> Dictionary:
	var inspection: Dictionary = SaveService.inspect_progression_storage()
	_storage_state = inspection.duplicate(true)
	_storage_warning = String(_storage_state.get("message", "")).strip_edges()
	if _storage_is_blocked(_storage_state) and _storage_warning != "":
		var signature := "%s|%s|%s" % [
			String(_storage_state.get("status", "")),
			String(_storage_state.get("reason", "")),
			_storage_warning,
		]
		if signature != _last_storage_warning_signature:
			push_warning(_storage_warning)
			_last_storage_warning_signature = signature
	elif not _storage_is_blocked(_storage_state):
		_storage_warning = ""
		_last_storage_warning_signature = ""
	return _storage_state.duplicate(true)

func _storage_is_blocked(value: Dictionary) -> bool:
	return not bool(value.get("ok", false)) or not bool(value.get("writable", false))

func _blocked_storage_result(operation: String, context: Dictionary = {}) -> Dictionary:
	var state := storage_state()
	var message := String(state.get("message", "")).strip_edges()
	if message == "":
		message = STORAGE_BLOCKED_MESSAGE
	var reason := "future_version" if String(state.get("status", "")) == "future_version" else "invalid_storage"
	var result := {
		"ok": false,
		"changed": false,
		"path": "",
		"operation": operation,
		"reason": reason,
		"message": message,
		"storage_state": state,
	}
	for key in context.keys():
		result[key] = context[key]
	return _set_failure_result(result)

func _success_result(operation: String, changed: bool, reason: String) -> Dictionary:
	return {
		"ok": true,
		"changed": changed,
		"path": String(_storage_state.get("path", "")),
		"operation": operation,
		"reason": reason,
		"message": "",
		"storage_state": storage_state(),
	}

func _set_failure_result(result: Dictionary) -> Dictionary:
	_last_failure_result = result.duplicate(true)
	return _last_failure_result.duplicate(true)
