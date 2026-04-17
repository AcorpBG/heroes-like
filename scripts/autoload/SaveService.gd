class_name HeroesSaveService
extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
# Validation markers: ScenarioSelectRules.launch_mode_label / ScenarioSelectRules.difficulty_label

const SAVE_DIR := "user://saves"
const SAVE_PREFIX := "slot"
const MANUAL_SLOT_IDS := [1, 2, 3]
const SLOT_TYPE_MANUAL := "manual"
const SLOT_TYPE_AUTOSAVE := "autosave"
const AUTOSAVE_FILE := "autosave.json"
const PROGRESSION_FILE := "campaign_progression.json"
const SAVE_METADATA_TIMESTAMP_KEY := "saved_at_unix"
const SAVE_METADATA_SLOT_TYPE_KEY := "save_slot_type"
const SAVE_METADATA_GAME_STATE_KEY := "saved_from_game_state"
const SAVE_METADATA_SCENARIO_STATUS_KEY := "saved_from_scenario_status"
const SAVE_METADATA_LAUNCH_MODE_KEY := "saved_from_launch_mode"

var _selected_manual_slot := int(MANUAL_SLOT_IDS[0])

func save_session(payload: Dictionary, slot: int = 1) -> String:
	return save_manual_session(payload, slot)

func save_runtime_selected_manual_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return save_runtime_manual_session(session, _selected_manual_slot)

func save_runtime_manual_session(session: SessionStateStoreScript.SessionData, slot: int = 1) -> Dictionary:
	return _save_runtime_session(session, SLOT_TYPE_MANUAL, slot)

func save_runtime_autosave_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _save_runtime_session(session, SLOT_TYPE_AUTOSAVE)

func save_manual_session(payload: Dictionary, slot: int = 1) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty session payload.")
		return ""

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	if String(normalized.get("scenario_id", "")) == "":
		push_warning("Refusing to save a session without a scenario id.")
		return ""

	var normalized_slot := _normalize_manual_slot(slot)
	var path := _save_payload(normalized, _slot_path(normalized_slot), SLOT_TYPE_MANUAL)
	if path != "":
		_selected_manual_slot = normalized_slot
	return path

func save_autosave_session(payload: Dictionary) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty autosave payload.")
		return ""

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	if String(normalized.get("scenario_id", "")) == "":
		push_warning("Refusing to save an autosave without a scenario id.")
		return ""
	return _save_payload(normalized, _autosave_path(), SLOT_TYPE_AUTOSAVE)

func load_session(slot: int = 1) -> Dictionary:
	return _summary_payload(inspect_manual_slot(slot))

func load_autosave() -> Dictionary:
	return _summary_payload(inspect_autosave())

func restore_manual_session(slot: int = 1):
	return restore_session_from_summary(inspect_manual_slot(slot))

func restore_autosave_session():
	return restore_session_from_summary(inspect_autosave())

func restore_session_from_summary(summary: Dictionary):
	var live_summary := refresh_summary(summary)
	if not can_load_summary(live_summary):
		return null
	return _session_from_payload(_summary_payload(live_summary))

func refresh_summary(summary: Dictionary) -> Dictionary:
	if summary.is_empty():
		return {}
	var slot_type := String(summary.get("slot_type", ""))
	match slot_type:
		SLOT_TYPE_AUTOSAVE:
			return inspect_autosave()
		SLOT_TYPE_MANUAL:
			return inspect_manual_slot(int(summary.get("slot_id", MANUAL_SLOT_IDS[0])))
		_:
			return _inspect_slot(slot_type, String(summary.get("slot_id", "")), String(summary.get("path", "")))

func save_progression(payload: Dictionary) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty campaign progression payload.")
		return ""
	return _save_raw_dictionary(payload, _progression_path())

func load_progression() -> Dictionary:
	return _load_raw_dictionary(_progression_path(), false)

func has_progression() -> bool:
	return FileAccess.file_exists(_progression_path())

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(_normalize_manual_slot(slot)))

func has_any_loadable_session() -> bool:
	return not latest_loadable_summary().is_empty()

func get_manual_slot_ids() -> Array:
	return MANUAL_SLOT_IDS.duplicate()

func get_selected_manual_slot() -> int:
	return _selected_manual_slot

func set_selected_manual_slot(slot: int) -> void:
	_selected_manual_slot = _normalize_manual_slot(slot)

func inspect_manual_slot(slot: int = 1) -> Dictionary:
	var normalized_slot := _normalize_manual_slot(slot)
	return _inspect_slot(SLOT_TYPE_MANUAL, str(normalized_slot), _slot_path(normalized_slot))

func inspect_autosave() -> Dictionary:
	return _inspect_slot(SLOT_TYPE_AUTOSAVE, SLOT_TYPE_AUTOSAVE, _autosave_path())

func list_session_summaries() -> Array:
	var summaries := [inspect_autosave()]
	for slot in MANUAL_SLOT_IDS:
		summaries.append(inspect_manual_slot(int(slot)))
	return summaries

func list_loadable_session_summaries() -> Array:
	var summaries := []
	for summary in list_session_summaries():
		if can_load_summary(summary):
			summaries.append(summary)
	return summaries

func latest_loadable_summary() -> Dictionary:
	var latest := {}
	for summary in list_session_summaries():
		if not can_load_summary(summary):
			continue
		if latest.is_empty() or _summary_sort_timestamp(summary) > _summary_sort_timestamp(latest):
			latest = summary
	return latest

func build_in_session_save_surface(session: SessionStateStoreScript.SessionData, manual_slot: int = -1) -> Dictionary:
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var slot_summary := inspect_manual_slot(selected_slot)
	var latest_summary := latest_loadable_summary()
	var current_target := _resume_target_for_session(session)
	return {
		"selected_slot": selected_slot,
		"slot_summary": slot_summary,
		"latest_summary": latest_summary,
		"save_button_label": _in_session_save_label(current_target, selected_slot),
		"save_button_tooltip": _in_session_save_tooltip(current_target, slot_summary),
		"latest_context": _latest_context_line(latest_summary, current_target),
		"menu_button_label": "Return to Menu",
		"menu_button_tooltip": _return_to_menu_tooltip(current_target, latest_summary),
	}

func resume_target_for_session(session: SessionStateStoreScript.SessionData) -> String:
	return _resume_target_for_session(session)

func can_load_summary(summary: Dictionary) -> bool:
	return bool(summary.get("valid", false)) and bool(summary.get("loadable", false)) and not _summary_payload(summary).is_empty()

func load_action_label(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Load Selected"
	match String(summary.get("resume_target", "overworld")):
		"battle":
			return "Resume Battle"
		"town":
			return "Resume Town"
		"outcome":
			return "Review Outcome"
		_:
			return "Resume Expedition"

func continue_action_label(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Continue Latest"
	match String(summary.get("resume_target", "overworld")):
		"battle":
			return "Resume Latest Battle"
		"town":
			return "Resume Latest Town"
		"outcome":
			return "Review Latest Outcome"
		_:
			return "Continue Latest"

func load_action_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "No loadable saves are available."
	if not can_load_summary(summary):
		return String(summary.get("status_text", "This save cannot be resumed."))
	return "%s\n%s" % [
		String(summary.get("status_text", "Ready to load.")),
		describe_slot_details(summary),
	]

func describe_slot(summary: Dictionary) -> String:
	var slot_label := _slot_label(summary)
	if not bool(summary.get("valid", false)):
		return "%s | Blocked | %s" % [slot_label, String(summary.get("status_text", "Unavailable"))]

	var parts := [slot_label, _summary_status_badge(summary)]
	var modified_label := format_modified_timestamp(_summary_sort_timestamp(summary))
	if modified_label != "":
		parts.append(modified_label)
	var scenario_name := String(summary.get("scenario_name", summary.get("scenario_id", "Unknown Scenario")))
	if scenario_name != "":
		parts.append(scenario_name)
	parts.append(ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))))
	parts.append(ScenarioSelectRulesScript.difficulty_label(String(summary.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))))
	parts.append(_resume_target_label(summary))
	var battle_name := String(summary.get("battle_name", ""))
	if battle_name != "" and String(summary.get("resume_target", "")) == "battle":
		parts.append(battle_name)
	var day := int(summary.get("day", 0))
	if day > 0:
		parts.append("Day %d" % day)
	return " | ".join(parts)

func describe_slot_details(summary: Dictionary) -> String:
	var lines := [_slot_label(summary)]
	var modified_label := format_modified_timestamp(int(summary.get("modified_timestamp", 0)))
	if modified_label != "":
		lines.append("Updated: %s" % modified_label)
	var recorded_label := format_modified_timestamp(int(summary.get("recorded_timestamp", 0)))
	if recorded_label != "" and recorded_label != modified_label:
		lines.append("Recorded in save: %s" % recorded_label)

	var scenario_id := String(summary.get("scenario_id", ""))
	if scenario_id != "":
		lines.append(
			"Scenario: %s (%s)"
			% [String(summary.get("scenario_name", scenario_id)), scenario_id]
		)
	lines.append(
		"Mode: %s | Difficulty: %s"
		% [
			ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))),
			ScenarioSelectRulesScript.difficulty_label(String(summary.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))),
		]
	)

	var campaign_name := String(summary.get("campaign_name", ""))
	var chapter_label := String(summary.get("chapter_label", ""))
	if campaign_name != "" and chapter_label != "":
		lines.append("Campaign: %s | %s" % [campaign_name, chapter_label])
	elif campaign_name != "":
		lines.append("Campaign: %s" % campaign_name)
	elif chapter_label != "":
		lines.append("Chapter: %s" % chapter_label)

	var hero_name := String(summary.get("hero_name", ""))
	var hero_id := String(summary.get("hero_id", ""))
	if hero_name != "" and hero_id != "":
		lines.append("Hero: %s (%s)" % [hero_name, hero_id])
	elif hero_name != "":
		lines.append("Hero: %s" % hero_name)
	elif hero_id != "":
		lines.append("Hero: %s" % hero_id)
	var hero_specialties_summary := String(summary.get("hero_specialties_summary", ""))
	if hero_specialties_summary != "":
		lines.append("Specialties: %s" % hero_specialties_summary)
	var battle_name := String(summary.get("battle_name", ""))
	if battle_name != "" and String(summary.get("resume_target", "")) == "battle":
		lines.append("Battle: %s" % battle_name)

	var day := int(summary.get("day", 0))
	if day > 0:
		lines.append("Day: %d" % day)
	lines.append("Integrity: %s" % _validity_label(String(summary.get("validity", "missing"))))
	lines.append("Load state: %s" % _resume_target_label(summary))

	if not bool(summary.get("valid", false)):
		lines.append("Status: %s" % String(summary.get("status_text", "Unavailable")))
		var invalid_warnings = summary.get("warnings", [])
		if invalid_warnings is Array and not invalid_warnings.is_empty():
			lines.append("Notes: %s" % "; ".join(invalid_warnings))
		return "\n".join(lines)

	lines.append(
		"Scenario status: %s"
		% _humanize_label(String(summary.get("scenario_status", "in_progress")))
	)
	lines.append(
		"Scene state: %s"
		% _humanize_label(String(summary.get("game_state", "overworld")))
	)
	lines.append(
		"Resume: %s"
		% String(summary.get("status_text", "Unavailable"))
	)

	var warnings = summary.get("warnings", [])
	if warnings is Array and not warnings.is_empty():
		lines.append("Notes: %s" % "; ".join(warnings))

	return "\n".join(lines)

func format_modified_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return ""
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	if datetime.is_empty():
		return str(timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
	]

func _slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SAVE_DIR, SAVE_PREFIX, _normalize_manual_slot(slot)]

func _autosave_path() -> String:
	return "%s/%s" % [SAVE_DIR, AUTOSAVE_FILE]

func _progression_path() -> String:
	return "%s/%s" % [SAVE_DIR, PROGRESSION_FILE]

func _ensure_save_dir() -> bool:
	var absolute_path := ProjectSettings.globalize_path(SAVE_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create save directory: %s" % absolute_path)
		return false
	return true

func _save_payload(payload: Dictionary, file_path: String, slot_type: String = SLOT_TYPE_MANUAL) -> String:
	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	normalized["save_version"] = SessionStateStoreScript.SAVE_VERSION
	normalized[SAVE_METADATA_TIMESTAMP_KEY] = Time.get_unix_time_from_system()
	normalized[SAVE_METADATA_SLOT_TYPE_KEY] = slot_type
	normalized[SAVE_METADATA_GAME_STATE_KEY] = String(normalized.get("game_state", "overworld"))
	normalized[SAVE_METADATA_SCENARIO_STATUS_KEY] = String(normalized.get("scenario_status", "in_progress"))
	normalized[SAVE_METADATA_LAUNCH_MODE_KEY] = String(normalized.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	return _save_raw_dictionary(normalized, file_path)

func _save_runtime_session(session: SessionStateStoreScript.SessionData, slot_type: String, slot: int = 1) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {"ok": false, "path": "", "summary": {}, "message": "No active expedition is available to save."}

	var restore_result := _normalize_restore_result(session.to_dict(), slot_type)
	if not bool(restore_result.get("ok", false)):
		return {
			"ok": false,
			"path": "",
			"summary": {},
			"message": String(restore_result.get("message", "This session cannot be saved safely right now.")),
		}

	var sanitized_session: SessionStateStoreScript.SessionData = restore_result.get("session", null)
	if sanitized_session == null:
		return {"ok": false, "path": "", "summary": {}, "message": "This session could not be prepared for saving."}

	var path := ""
	var summary := {}
	match slot_type:
		SLOT_TYPE_AUTOSAVE:
			path = _save_payload(sanitized_session.to_dict(), _autosave_path(), SLOT_TYPE_AUTOSAVE)
			summary = inspect_autosave()
		_:
			var normalized_slot := _normalize_manual_slot(slot)
			path = _save_payload(sanitized_session.to_dict(), _slot_path(normalized_slot), SLOT_TYPE_MANUAL)
			if path != "":
				_selected_manual_slot = normalized_slot
			summary = inspect_manual_slot(normalized_slot)

	if path == "":
		return {"ok": false, "path": "", "summary": summary, "message": "Save write failed."}

	return {
		"ok": true,
		"path": path,
		"summary": summary,
		"message": _runtime_save_message(slot_type, summary),
	}

func _save_raw_dictionary(payload: Dictionary, file_path: String) -> String:
	if not _ensure_save_dir():
		return ""

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open save file for writing: %s" % file_path)
		return ""
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return file_path

func _load_raw_dictionary(file_path: String, warn_if_missing: bool) -> Dictionary:
	if !FileAccess.file_exists(file_path):
		if warn_if_missing:
			push_warning("Missing save file: %s" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Unable to read save file: %s" % file_path)
		return {}

	var text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		push_error(
			"Invalid save JSON in %s at line %d: %s"
			% [file_path, parser.get_error_line(), parser.get_error_message()]
		)
		return {}

	var payload = parser.data
	return payload.duplicate(true) if payload is Dictionary else {}

func _inspect_slot(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	var summary := _empty_summary(slot_type, slot_id, file_path)
	if not FileAccess.file_exists(file_path):
		return _finalize_summary(summary)

	summary["modified_timestamp"] = FileAccess.get_modified_time(file_path)
	var raw_payload := _load_raw_dictionary(file_path, false)
	if raw_payload.is_empty():
		summary["validity"] = "corrupt_json"
		summary["status_text"] = "Corrupt or unreadable save data."
		return _finalize_summary(summary)

	summary = _populate_summary_from_payload(summary, raw_payload)
	var restore_result := _normalize_restore_result(raw_payload, slot_type)
	if not bool(restore_result.get("ok", false)):
		summary["validity"] = String(restore_result.get("validity", "invalid_payload"))
		summary["status_text"] = String(restore_result.get("message", "Save cannot be restored."))
		summary["warnings"] = restore_result.get("warnings", [])
		summary["resume_target"] = "blocked"
		summary["loadable"] = false
		return _finalize_summary(summary)

	var session = restore_result.get("session", null)
	if session == null:
		summary["validity"] = "invalid_payload"
		summary["status_text"] = "Save session could not be restored."
		summary["resume_target"] = "blocked"
		return _finalize_summary(summary)

	summary["payload"] = session.to_dict()
	summary = _populate_summary_from_payload(summary, _summary_payload(summary))
	summary["valid"] = true
	summary["validity"] = String(restore_result.get("validity", "ok"))
	summary["warnings"] = restore_result.get("warnings", [])
	summary["resume_target"] = String(restore_result.get("resume_target", _resume_target_for_session(session)))
	summary["loadable"] = summary["resume_target"] != "blocked"
	summary["status_text"] = _status_text_for_summary(summary)
	return _finalize_summary(summary)

func _normalize_restore_result(payload: Dictionary, slot_type: String = "") -> Dictionary:
	var source_save_version: int = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	if source_save_version > SessionStateStoreScript.SAVE_VERSION:
		return {
			"ok": false,
			"validity": "newer_version",
			"message": "Written by a newer save version.",
			"warnings": [],
		}

	var structure_report := _payload_structure_report(payload, slot_type)
	if not bool(structure_report.get("ok", false)):
		return structure_report

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	var scenario_id := String(normalized.get("scenario_id", ""))
	if scenario_id == "":
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing scenario id.",
			"warnings": [],
		}

	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		return {
			"ok": false,
			"validity": "missing_scenario",
			"message": "Scenario content is unavailable in this build.",
			"warnings": [],
		}

	var session: SessionStateStoreScript.SessionData = _session_from_payload(normalized)
	if session == null:
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Session payload could not be normalized.",
			"warnings": [],
		}

	OverworldRulesScript.normalize_overworld_state_bridge(session)

	var warnings = structure_report.get("warnings", [])
	if not (warnings is Array):
		warnings = []
	var validity := String(structure_report.get("validity", "ok"))
	if source_save_version < SessionStateStoreScript.SAVE_VERSION:
		if validity == "ok":
			validity = "legacy"
		else:
			validity = _degraded_validity(validity)
		warnings.append("Normalized legacy save version %d." % source_save_version)

	var requested_resume_target := _resume_target_for_session(session)
	match requested_resume_target:
		"battle":
			if session.battle.is_empty():
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Battle payload was missing and the session was returned to the overworld.")
			elif not BattleRulesScript.normalize_battle_state_bridge(session):
				session.battle = {}
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Battle payload could not be restored and the session was returned to the overworld.")
		"town":
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because its overworld anchors were already resolved.")
			if not TownRulesScript.can_visit_active_town_bridge(session):
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Town visit state was invalid and the session was returned to the overworld.")
		"outcome":
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because the scenario is already resolved.")
			session.game_state = "outcome"
		_:
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because its overworld anchors were already resolved.")
			session.game_state = "overworld"

	var resume_target := _resume_target_for_session(session)
	match resume_target:
		"battle":
			session.game_state = "battle"
		"town":
			session.game_state = "town"
		"outcome":
			session.game_state = "outcome"
		_:
			if session.scenario_status == "in_progress":
				session.game_state = "overworld"

	return {
		"ok": true,
		"validity": validity,
		"warnings": warnings,
		"session": session,
		"resume_target": resume_target,
	}

func _populate_summary_from_payload(summary: Dictionary, payload: Dictionary) -> Dictionary:
	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	var scenario_id := String(normalized.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var launch_mode := String(normalized.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	var campaign_metadata := _campaign_metadata_for_scenario(scenario_id, launch_mode)
	var session_flags = normalized.get("flags", {})
	if session_flags is Dictionary and SessionStateStoreScript.normalize_launch_mode(launch_mode) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var flagged_campaign_id := String(session_flags.get("campaign_id", ""))
		if flagged_campaign_id != "":
			campaign_metadata["campaign_id"] = flagged_campaign_id
			if String(campaign_metadata.get("campaign_name", "")) == "":
				var flagged_campaign := ContentService.get_campaign(flagged_campaign_id)
				campaign_metadata["campaign_name"] = String(flagged_campaign.get("name", flagged_campaign_id))
		var flagged_campaign_name := String(session_flags.get("campaign_name", ""))
		if flagged_campaign_name != "":
			campaign_metadata["campaign_name"] = flagged_campaign_name
		var flagged_chapter_label := String(session_flags.get("campaign_chapter_label", ""))
		if flagged_chapter_label != "":
			campaign_metadata["chapter_label"] = flagged_chapter_label
	var hero_id := String(normalized.get("hero_id", ""))
	var overworld_state = normalized.get("overworld", {})
	var hero_state_value = overworld_state.get("hero", {}) if overworld_state is Dictionary else {}
	var hero_state: Dictionary = hero_state_value if hero_state_value is Dictionary else {}
	var hero_template := ContentService.get_hero(hero_id)

	summary["source_save_version"] = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	summary["save_version"] = int(normalized.get("save_version", SessionStateStoreScript.SAVE_VERSION))
	summary["recorded_timestamp"] = _recorded_timestamp_from_payload(payload, int(summary.get("modified_timestamp", 0)))
	summary["scenario_id"] = scenario_id
	summary["scenario_name"] = String(scenario.get("name", scenario_id))
	summary["campaign_id"] = String(campaign_metadata.get("campaign_id", ""))
	summary["campaign_name"] = String(campaign_metadata.get("campaign_name", ""))
	summary["chapter_label"] = String(campaign_metadata.get("chapter_label", ""))
	summary["day"] = max(0, int(normalized.get("day", 0)))
	summary["hero_id"] = hero_id
	summary["hero_name"] = _hero_name(hero_state, hero_template, hero_id)
	summary["hero_specialties_summary"] = HeroProgressionRulesScript.brief_summary(hero_state)
	summary["difficulty"] = String(normalized.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	summary["launch_mode"] = launch_mode
	summary["scenario_status"] = String(normalized.get("scenario_status", "in_progress"))
	summary["game_state"] = String(normalized.get("game_state", "overworld"))
	summary["battle_name"] = _battle_name_from_payload(normalized)
	summary["saved_from_game_state"] = String(payload.get(SAVE_METADATA_GAME_STATE_KEY, summary.get("game_state", "overworld")))
	summary["saved_from_scenario_status"] = String(payload.get(SAVE_METADATA_SCENARIO_STATUS_KEY, summary.get("scenario_status", "in_progress")))
	summary["saved_from_launch_mode"] = String(payload.get(SAVE_METADATA_LAUNCH_MODE_KEY, summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)))
	return summary

func _campaign_metadata_for_scenario(scenario_id: String, launch_mode: String) -> Dictionary:
	var metadata := {
		"campaign_id": "",
		"campaign_name": "",
		"chapter_label": "",
	}
	if scenario_id == "" or SessionStateStoreScript.normalize_launch_mode(launch_mode) != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return metadata

	var campaign_id: String = CampaignRulesScript.get_campaign_id_for_scenario(scenario_id)
	if campaign_id == "":
		return metadata

	var campaign := ContentService.get_campaign(campaign_id)
	metadata["campaign_id"] = campaign_id
	metadata["campaign_name"] = String(campaign.get("name", campaign_id))
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		if String(scenario_entry.get("scenario_id", "")) != scenario_id:
			continue
		metadata["chapter_label"] = String(scenario_entry.get("label", ""))
		break
	return metadata

func _hero_name(hero_state: Variant, hero_template: Dictionary, hero_id: String) -> String:
	if hero_state is Dictionary:
		var hero_name := String(hero_state.get("name", ""))
		if hero_name != "":
			return hero_name
	return String(hero_template.get("name", hero_id))

func _battle_name_from_payload(normalized_payload: Dictionary) -> String:
	var battle_state = normalized_payload.get("battle", {})
	if not (battle_state is Dictionary) or battle_state.is_empty():
		return ""
	return String(battle_state.get("encounter_name", battle_state.get("encounter_id", "")))

func _empty_summary(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	return {
		"slot_type": slot_type,
		"slot_id": slot_id,
		"path": file_path,
		"modified_timestamp": 0,
		"recorded_timestamp": 0,
		"source_save_version": 0,
		"save_version": 0,
		"scenario_id": "",
		"scenario_name": "",
		"campaign_id": "",
		"campaign_name": "",
		"chapter_label": "",
		"day": 0,
		"hero_id": "",
		"hero_name": "",
		"battle_name": "",
			"difficulty": ScenarioSelectRulesScript.default_difficulty_id(),
			"launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN,
		"scenario_status": "in_progress",
		"game_state": "overworld",
		"saved_from_game_state": "overworld",
		"saved_from_scenario_status": "in_progress",
			"saved_from_launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN,
		"resume_target": "blocked",
		"validity": "missing",
		"valid": false,
		"loadable": false,
		"warnings": [],
		"status_text": "Empty slot.",
		"summary": "",
		"detail": "",
		"payload": {},
	}

func _finalize_summary(summary: Dictionary) -> Dictionary:
	summary["summary"] = describe_slot(summary)
	summary["detail"] = describe_slot_details(summary)
	return summary

func _summary_payload(summary: Dictionary) -> Dictionary:
	var payload = summary.get("payload", {})
	return payload.duplicate(true) if payload is Dictionary else {}

func _summary_sort_timestamp(summary: Dictionary) -> int:
	return max(int(summary.get("modified_timestamp", 0)), int(summary.get("recorded_timestamp", 0)))

func _session_from_payload(payload: Dictionary) -> SessionStateStoreScript.SessionData:
	if payload.is_empty():
		return null
	var session := SessionStateStoreScript.new_session_data()
	session.from_dict(payload)
	return session

func _slot_label(summary: Dictionary) -> String:
	if String(summary.get("slot_type", "")) == SLOT_TYPE_AUTOSAVE:
		return "Autosave"
	return "Manual %s" % String(summary.get("slot_id", "1"))

func _summary_status_badge(summary: Dictionary) -> String:
	if not bool(summary.get("valid", false)):
		return "Blocked"
	if String(summary.get("resume_target", "overworld")) == "outcome":
		return "Outcome"
	match String(summary.get("validity", "ok")):
		"degraded":
			return "Recovered"
		"legacy":
			return "Legacy"
		_:
			return "Ready"

func _runtime_save_message(slot_type: String, summary: Dictionary) -> String:
	if slot_type == SLOT_TYPE_AUTOSAVE:
		return "Autosaved. %s" % _main_menu_continue_hint(summary)
	return "Saved %s. %s" % [_slot_label(summary), _main_menu_continue_hint(summary)]

func _main_menu_continue_hint(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Main menu continue is unavailable for this snapshot."
	match String(summary.get("resume_target", "blocked")):
		"battle":
			var battle_name := String(summary.get("battle_name", ""))
			if battle_name != "":
				return "Continue Latest will resume %s." % battle_name
			return "Continue Latest will resume the active battle."
		"town":
			return "Continue Latest will resume town management."
		"outcome":
			return "Continue Latest will review this outcome."
		"overworld":
			return "Continue Latest will resume the expedition."
		_:
			return "This snapshot cannot be resumed safely."

func _resume_target_noun(target: String) -> String:
	match target:
		"battle":
			return "battle"
		"town":
			return "town"
		"outcome":
			return "outcome"
		_:
			return "expedition"

func _in_session_save_label(current_target: String, selected_slot: int) -> String:
	match current_target:
		"battle":
			return "Save Battle to Manual %d" % selected_slot
		"town":
			return "Save Town to Manual %d" % selected_slot
		"outcome":
			return "Save Outcome to Manual %d" % selected_slot
		_:
			return "Save Expedition to Manual %d" % selected_slot

func _in_session_save_tooltip(current_target: String, slot_summary: Dictionary) -> String:
	var lines := [
		"Write a safe %s snapshot into %s." % [_resume_target_noun(current_target), _slot_label(slot_summary)],
		_main_menu_continue_hint({"resume_target": current_target, "valid": true, "loadable": true, "payload": {"scenario_id": "active"}}),
	]
	var existing_status := String(slot_summary.get("status_text", ""))
	if existing_status != "":
		lines.append("Current slot: %s" % existing_status)
	return "\n".join(lines)

func _latest_context_line(latest_summary: Dictionary, current_target: String = "") -> String:
	if latest_summary.is_empty() or not can_load_summary(latest_summary):
		return "Latest ready save: none."
	var prefix := "Latest ready"
	if current_target != "" and String(latest_summary.get("resume_target", "")) == current_target:
		prefix = "Latest ready %s snapshot" % _resume_target_noun(current_target)
	return "%s: %s | %s | %s" % [
		prefix,
		_slot_label(latest_summary),
		_resume_target_label(latest_summary),
		format_modified_timestamp(_summary_sort_timestamp(latest_summary)),
	]

func _return_to_menu_tooltip(current_target: String, latest_summary: Dictionary) -> String:
	var lines := [
		"Return to the main menu after refreshing autosave for this %s state." % _resume_target_noun(current_target),
	]
	if latest_summary.is_empty():
		lines.append("A fresh autosave will become the latest continue target.")
	else:
		lines.append(_main_menu_continue_hint({"resume_target": current_target, "valid": true, "loadable": true, "payload": {"scenario_id": "active"}}))
		lines.append("Latest before return: %s" % _slot_label(latest_summary))
	return "\n".join(lines)

func _resume_target_label(summary: Dictionary) -> String:
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "Battle Resume"
		"town":
			return "Town Resume"
		"outcome":
			return "Outcome Review"
		"overworld":
			return "Overworld Resume"
		_:
			return "Blocked"

func _status_text_for_summary(summary: Dictionary) -> String:
	if not bool(summary.get("valid", false)):
		return String(summary.get("status_text", "Unavailable"))
	match String(summary.get("resume_target", "blocked")):
		"battle":
			var battle_name := String(summary.get("battle_name", ""))
			if battle_name != "":
				return "Ready to resume %s." % battle_name
			return "Ready to resume the active battle."
		"town":
			return "Ready to resume town management."
		"outcome":
			return "Outcome is ready to review."
		"overworld":
			match String(summary.get("validity", "ok")):
				"degraded":
					return "Recovered expedition is ready to resume."
				"legacy":
					return "Legacy expedition is ready to resume."
				_:
					return "Ready to resume expedition."
		_:
			return "This save cannot be loaded."

func _normalize_manual_slot(slot: int) -> int:
	for slot_id in MANUAL_SLOT_IDS:
		if int(slot_id) == slot:
			return slot
	return int(MANUAL_SLOT_IDS[0])

func _resume_target_for_session(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "blocked"
	if session.scenario_status != "in_progress":
		return "outcome"
	if not session.battle.is_empty() and BattleRulesScript.battle_payload_can_resume_bridge(session):
		return "battle"
	if String(session.game_state) == "town" and TownRulesScript.can_visit_active_town_bridge(session):
		return "town"
	return "overworld"

func _recorded_timestamp_from_payload(payload: Dictionary, fallback: int = 0) -> int:
	var recorded: int = max(0, int(payload.get(SAVE_METADATA_TIMESTAMP_KEY, 0)))
	return recorded if recorded > 0 else max(0, fallback)

func _payload_structure_report(payload: Dictionary, slot_type: String = "") -> Dictionary:
	var warnings := []
	var validity := "ok"
	var scenario_id := String(payload.get("scenario_id", ""))
	if scenario_id == "":
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing scenario id.",
			"warnings": warnings,
		}

	var overworld = payload.get("overworld", {})
	if not (overworld is Dictionary) or overworld.is_empty():
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing overworld expedition state.",
			"warnings": warnings,
		}
	if not _has_core_overworld_state(overworld):
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "The save is missing core expedition state and cannot be recovered safely.",
			"warnings": warnings,
		}

	if not payload.has("save_version"):
		validity = "legacy"
		warnings.append("Save version marker was missing and compatibility fallback was applied.")
	if not payload.has("session_id") or String(payload.get("session_id", "")) == "":
		validity = _degraded_validity(validity)
		warnings.append("Session id was missing and a new runtime id will be issued.")
	if not payload.has("hero_id") or String(payload.get("hero_id", "")) == "":
		validity = _degraded_validity(validity)
		warnings.append("Commander id was missing and will be derived from restored overworld state.")
	if not (payload.get("flags", {}) is Dictionary):
		validity = _degraded_validity(validity)
		warnings.append("Session flags were missing or invalid and were reset.")

	var missing_overworld_fields := _missing_overworld_fields(overworld)
	if not missing_overworld_fields.is_empty():
		validity = _degraded_validity(validity)
		warnings.append(
			"Overworld save fields were incomplete (%s); missing data was restored from authored defaults."
			% ", ".join(missing_overworld_fields)
		)

	var raw_difficulty := String(payload.get("difficulty", ""))
	if raw_difficulty == "" or ScenarioSelectRulesScript.normalize_difficulty(raw_difficulty) != raw_difficulty:
		validity = _degraded_validity(validity)
		warnings.append("Difficulty metadata was missing or invalid and was normalized.")
	var raw_launch_mode := String(payload.get("launch_mode", ""))
	if raw_launch_mode == "" or SessionStateStoreScript.normalize_launch_mode(raw_launch_mode) != raw_launch_mode:
		validity = _degraded_validity(validity)
		warnings.append("Launch-mode metadata was missing or invalid and was normalized.")
	var raw_game_state := String(payload.get("game_state", ""))
	if raw_game_state == "" or raw_game_state not in SessionStateStoreScript.SUPPORTED_GAME_STATES:
		validity = _degraded_validity(validity)
		warnings.append("Scene-state metadata was missing or invalid and the session will resume through a safer route.")
	var raw_scenario_status := String(payload.get("scenario_status", ""))
	if raw_scenario_status == "" or raw_scenario_status not in SessionStateStoreScript.SUPPORTED_SCENARIO_STATUSES:
		validity = _degraded_validity(validity)
		warnings.append("Scenario-status metadata was missing or invalid and was normalized.")

	var recorded_slot_type := String(payload.get(SAVE_METADATA_SLOT_TYPE_KEY, ""))
	if recorded_slot_type != "" and slot_type != "" and recorded_slot_type != slot_type:
		validity = _degraded_validity(validity)
		warnings.append("Recorded slot metadata no longer matches this slot; the live file location was trusted instead.")

	return {
		"ok": true,
		"validity": validity,
		"warnings": warnings,
	}

func _has_core_overworld_state(overworld: Dictionary) -> bool:
	var has_world_state := false
	for key in ["resources", "towns", "encounters", "map"]:
		if overworld.has(key):
			has_world_state = true
			break
	var has_commander_state := false
	for key in ["hero", "player_heroes", "hero_position", "active_hero_id"]:
		if overworld.has(key):
			has_commander_state = true
			break
	return has_world_state and has_commander_state

func _missing_overworld_fields(overworld: Dictionary) -> Array:
	var missing := []
	for key in ["resources", "towns", "resource_nodes", "artifact_nodes", "encounters", "resolved_encounters", "map", "map_size"]:
		if not overworld.has(key):
			missing.append(key)
	if not overworld.has("hero") and not overworld.has("player_heroes"):
		missing.append("hero_roster")
	return missing

func _degraded_validity(current_validity: String) -> String:
	return "degraded" if current_validity in ["ok", "legacy"] else current_validity

func _humanize_label(value: String) -> String:
	return value.replace("_", " ").capitalize()

func _validity_label(validity: String) -> String:
	match validity:
		"ok":
			return "Valid"
		"legacy":
			return "Legacy save normalized"
		"degraded":
			return "Recovered with fallback"
		"missing":
			return "Empty slot"
		"corrupt_json":
			return "Corrupt or unreadable JSON"
		"invalid_payload":
			return "Invalid session payload"
		"missing_scenario":
			return "Missing scenario content"
		"newer_version":
			return "Written by a newer build"
		_:
			return _humanize_label(validity)
