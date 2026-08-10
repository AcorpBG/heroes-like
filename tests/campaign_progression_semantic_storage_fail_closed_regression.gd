extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "CAMPAIGN_PROGRESSION_SEMANTIC_STORAGE_FAIL_CLOSED_REGRESSION"
const PROGRESSION_PATH := "user://saves/campaign_progression.json"
const CANDIDATE_PATH := "user://saves/campaign_progression.json.candidate"
const BACKUP_PATH := "user://saves/campaign_progression.json.backup"
const CAMPAIGN_ID := "campaign_reedfall"
const SCENARIO_ID := "river-pass"
const BLOCKED_MESSAGE_FRAGMENT := "Existing data was preserved and cannot be overwritten."

var _original_files: Dictionary = {}
var _original_active_session = null
var _original_profile: Dictionary = {}
var _original_storage_state: Dictionary = {}
var _original_storage_warning := ""
var _original_failure_result: Dictionary = {}
var _original_warning_signature := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_original_state()
	if not _require_api():
		return
	var blocked: Dictionary = _validate_blocked_matrix()
	if blocked.is_empty():
		return
	var future: Dictionary = _validate_future_live_preserves_backup()
	if future.is_empty():
		return
	var controls: Dictionary = _validate_allowed_controls()
	if controls.is_empty():
		return
	var main_menu: Dictionary = await _validate_main_menu_blocked_surface()
	if main_menu.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"blocked": blocked,
		"future": future,
		"controls": controls,
		"main_menu": main_menu,
		"profile_version": CampaignRules.PROFILE_VERSION,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_api() -> bool:
	for method_name in ["inspect_progression_storage", "save_progression", "load_progression", "has_progression"]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing %s." % method_name)
	for method_name in [
		"load_profile",
		"storage_state",
		"is_storage_blocked",
		"last_failure_result",
		"select_campaign",
		"select_scenario",
		"start_scenario",
		"restart_campaign",
		"record_session_completion",
	]:
		if not CampaignProgression.has_method(method_name):
			return _fail_bool("CampaignProgression is missing %s." % method_name)
	return true


func _validate_blocked_matrix() -> Dictionary:
	var cases := [
		{
			"id": "partial_top_level",
			"operation": "restart_campaign",
			"raw": JSON.stringify({"version": CampaignRules.PROFILE_VERSION, "last_campaign_id": CAMPAIGN_ID}),
			"reason": "missing_last_scenario_id",
		},
		{
			"id": "top_level_wrong_type",
			"operation": "select_campaign",
			"raw": JSON.stringify({
				"version": CampaignRules.PROFILE_VERSION,
				"last_campaign_id": 17,
				"last_scenario_id": "",
				"campaign_states": {},
			}),
			"reason": "last_campaign_id_wrong_type",
		},
		{
			"id": "nested_state_wrong_type",
			"operation": "select_scenario",
			"raw": JSON.stringify(_profile_with_campaign_state("not-a-dictionary")),
			"reason": "campaign_state_wrong_type",
		},
		{
			"id": "nested_collection_wrong_type",
			"operation": "select_campaign",
			"raw": JSON.stringify(_profile_with_campaign_state({"scenario_records": []})),
			"reason": "scenario_records_wrong_type",
		},
		{
			"id": "nested_entry_wrong_type",
			"operation": "record_session_completion",
			"raw": JSON.stringify(_profile_with_campaign_state({"scenario_records": {SCENARIO_ID: "not-a-record"}})),
			"reason": "scenario_records_entry_wrong_type",
		},
		{
			"id": "malformed_json",
			"operation": "start_scenario",
			"raw": "{ malformed campaign progress",
			"reason": "corrupt_json",
		},
	]
	var rows: Dictionary = {}
	for case_value in cases:
		var case: Dictionary = case_value
		var row: Dictionary = _exercise_blocked_case(case)
		if row.is_empty():
			return {}
		rows[String(case.get("id", ""))] = row
	return rows


func _exercise_blocked_case(case: Dictionary) -> Dictionary:
	_clear_progression_files()
	if not _write_text(PROGRESSION_PATH, String(case.get("raw", ""))):
		_fail("Could not write blocked fixture %s." % case.get("id", ""))
		return {}
	# A valid candidate must never become recovery authority.
	if not _write_json(CANDIDATE_PATH, _valid_profile()):
		_fail("Could not write candidate fixture %s." % case.get("id", ""))
		return {}
	var live_before: Dictionary = _file_state(PROGRESSION_PATH)
	var baseline_profile: Dictionary = _profile_with_progress()
	var baseline_session: SessionStateStoreScript.SessionData = _campaign_session(false)
	CampaignProgression.profile = baseline_profile.duplicate(true)
	CampaignProgression._storage_state = {}
	CampaignProgression._last_failure_result = {}
	SessionState.active_session = baseline_session
	var session_before: Dictionary = _canonical_dictionary(baseline_session.to_dict())
	var session_instance := baseline_session.get_instance_id()
	var inspection: Dictionary = SaveService.inspect_progression_storage()
	if String(inspection.get("status", "")) != "invalid" \
			or bool(inspection.get("ok", true)) \
			or bool(inspection.get("writable", true)) \
			or bool(inspection.get("usable", true)) \
			or String(inspection.get("reason", "")) != String(case.get("reason", "")):
		_fail("Blocked fixture %s returned the wrong storage inspection: %s" % [case.get("id", ""), JSON.stringify(_compact_storage(inspection))])
		return {}
	if FileAccess.file_exists(CANDIDATE_PATH) or FileAccess.file_exists(BACKUP_PATH):
		_fail("Blocked fixture %s retained or promoted a transaction artifact." % case.get("id", ""))
		return {}
	var load_result: Dictionary = CampaignProgression.load_profile()
	if bool(load_result.get("ok", true)) or String(load_result.get("reason", "")) != "invalid_storage":
		_fail("Blocked fixture %s was not retained by CampaignProgression load: %s" % [case.get("id", ""), JSON.stringify(_compact_result(load_result))])
		return {}
	var mutation_result: Dictionary = _invoke_blocked_operation(String(case.get("operation", "")), baseline_session)
	if not _blocked_result_exact(mutation_result, "invalid_storage", "invalid"):
		_fail("Blocked fixture %s mutation was not structured fail-closed: %s" % [case.get("id", ""), JSON.stringify(_compact_result(mutation_result))])
		return {}
	if SaveService.save_progression(_valid_profile()) != "":
		_fail("Blocked fixture %s allowed direct SaveService overwrite." % case.get("id", ""))
		return {}
	if _file_state(PROGRESSION_PATH) != live_before \
			or CampaignProgression.profile != baseline_profile \
			or SessionState.active_session.get_instance_id() != session_instance \
			or _canonical_dictionary(SessionState.active_session.to_dict()) != session_before \
			or not SaveService.load_progression().is_empty() \
			or SaveService.has_progression() \
			or FileAccess.file_exists(CANDIDATE_PATH) \
			or FileAccess.file_exists(BACKUP_PATH):
		_fail("Blocked fixture %s changed bytes/profile/session or became usable." % case.get("id", ""))
		return {}
	return {
		"status": "invalid",
		"reason": case.get("reason", ""),
		"operation": case.get("operation", ""),
		"bytes_exact": true,
		"profile_session_exact": true,
		"candidate_never_adopted": true,
	}


func _validate_future_live_preserves_backup() -> Dictionary:
	_clear_progression_files()
	var future_profile: Dictionary = _valid_profile()
	future_profile["version"] = CampaignRules.PROFILE_VERSION + 1
	var backup_profile: Dictionary = _valid_profile()
	backup_profile["last_scenario_id"] = SCENARIO_ID
	if not _write_json(PROGRESSION_PATH, future_profile) \
			or not _write_json(BACKUP_PATH, backup_profile) \
			or not _write_json(CANDIDATE_PATH, backup_profile):
		_fail("Could not write future-version preservation fixture.")
		return {}
	var live_before: Dictionary = _file_state(PROGRESSION_PATH)
	var backup_before: Dictionary = _file_state(BACKUP_PATH)
	var baseline_profile: Dictionary = _profile_with_progress()
	var baseline_session: SessionStateStoreScript.SessionData = _campaign_session(false)
	CampaignProgression.profile = baseline_profile.duplicate(true)
	CampaignProgression._storage_state = {}
	CampaignProgression._last_failure_result = {}
	SessionState.active_session = baseline_session
	var session_before: Dictionary = _canonical_dictionary(baseline_session.to_dict())
	var inspection: Dictionary = SaveService.inspect_progression_storage()
	if String(inspection.get("status", "")) != "future_version" \
			or int(inspection.get("version", -1)) != CampaignRules.PROFILE_VERSION + 1 \
			or bool(inspection.get("writable", true)) \
			or String(inspection.get("message", "")).find(BLOCKED_MESSAGE_FRAGMENT) < 0:
		_fail("Future storage inspection was not blocked: %s" % JSON.stringify(_compact_storage(inspection)))
		return {}
	if FileAccess.file_exists(CANDIDATE_PATH) or _file_state(PROGRESSION_PATH) != live_before or _file_state(BACKUP_PATH) != backup_before:
		_fail("Future inspection replaced future live/backup bytes or retained candidate staging.")
		return {}
	var restart: Dictionary = CampaignProgression.restart_campaign(CAMPAIGN_ID)
	var completion: Dictionary = CampaignProgression.record_session_completion(_campaign_session(true))
	if not _blocked_result_exact(restart, "future_version", "future_version") \
			or not _blocked_result_exact(completion, "future_version", "future_version"):
		_fail("Future storage did not block restart/completion: %s" % JSON.stringify({
			"restart": _compact_result(restart),
			"completion": _compact_result(completion),
		}))
		return {}
	if SaveService.save_progression(_valid_profile()) != "" \
			or not SaveService.load_progression().is_empty() \
			or SaveService.has_progression() \
			or _file_state(PROGRESSION_PATH) != live_before \
			or _file_state(BACKUP_PATH) != backup_before \
			or CampaignProgression.profile != baseline_profile \
			or _canonical_dictionary(SessionState.active_session.to_dict()) != session_before:
		_fail("Future storage was overwritten, recovered from older backup, or changed live state.")
		return {}
	return {
		"status": "future_version",
		"future_live_exact": true,
		"current_backup_exact": true,
		"candidate_never_adopted": true,
		"restart_completion_blocked": true,
	}


func _validate_allowed_controls() -> Dictionary:
	_clear_progression_files()
	var missing: Dictionary = SaveService.inspect_progression_storage()
	if String(missing.get("status", "")) != "missing" or not bool(missing.get("ok", false)) \
			or not bool(missing.get("writable", false)) or bool(missing.get("usable", true)):
		_fail("Missing progression storage was not writable and non-usable: %s" % JSON.stringify(_compact_storage(missing)))
		return {}
	CampaignProgression.profile = {}
	CampaignProgression._storage_state = {}
	if not bool(CampaignProgression.load_profile().get("ok", false)):
		_fail("Missing progression storage did not load a clean in-memory profile.")
		return {}
	var selected_campaign: Dictionary = CampaignProgression.select_campaign(CAMPAIGN_ID)
	if not bool(selected_campaign.get("ok", false)) or String(selected_campaign.get("reason", "")) != "saved":
		_fail("Missing storage did not allow the first profile mutation: %s" % JSON.stringify(_compact_result(selected_campaign)))
		return {}
	var current: Dictionary = SaveService.inspect_progression_storage()
	if String(current.get("status", "")) != "current_valid" or not bool(current.get("usable", false)):
		_fail("First mutation did not establish current-valid storage: %s" % JSON.stringify(_compact_storage(current)))
		return {}
	var selected_scenario: Dictionary = CampaignProgression.select_scenario(CAMPAIGN_ID, SCENARIO_ID)
	var started: SessionStateStoreScript.SessionData = CampaignProgression.start_scenario(SCENARIO_ID, "normal", CAMPAIGN_ID)
	if not bool(selected_scenario.get("ok", false)) or started.scenario_id != SCENARIO_ID \
			or not CampaignProgression.last_failure_result().is_empty():
		_fail("Current-valid storage did not allow select/start mutations.")
		return {}
	var completion: Dictionary = CampaignProgression.record_session_completion(_campaign_session(true))
	if not bool(completion.get("ok", false)) or String(completion.get("reason", "")) != "recorded":
		_fail("Current-valid storage did not allow completion mutation: %s" % JSON.stringify(_compact_result(completion)))
		return {}
	var restart: Dictionary = CampaignProgression.restart_campaign(CAMPAIGN_ID)
	if not bool(restart.get("ok", false)) or String(restart.get("reason", "")) != "restarted":
		_fail("Current-valid storage did not allow restart mutation: %s" % JSON.stringify(_compact_result(restart)))
		return {}
	if SaveService.load_progression().is_empty() or not _artifacts_absent():
		_fail("Successful current-valid mutations did not leave a usable artifact-free profile.")
		return {}

	var valid_profile: Dictionary = _valid_profile()
	var valid_text := JSON.stringify(valid_profile, "\t")
	_clear_progression_files()
	if not _write_text(BACKUP_PATH, valid_text) \
			or not _write_text(PROGRESSION_PATH, "{ broken live") \
			or not _write_json(CANDIDATE_PATH, _profile_with_campaign_state("candidate-only")):
		_fail("Could not stage valid-backup recovery control.")
		return {}
	var recovered: Dictionary = SaveService.inspect_progression_storage()
	if String(recovered.get("status", "")) != "recovered" or not bool(recovered.get("usable", false)) \
			or FileAccess.get_file_as_string(PROGRESSION_PATH) != valid_text or not _artifacts_absent() \
			or SaveService.load_progression() != _canonical_dictionary(valid_profile):
		_fail("Valid backup did not recover exactly without candidate authority: %s" % JSON.stringify(_compact_storage(recovered)))
		return {}
	return {
		"missing_writable": true,
		"current_valid_mutations": ["select_campaign", "select_scenario", "start_scenario", "record_session_completion", "restart_campaign"],
		"valid_backup_recovered": true,
		"candidate_never_adopted": true,
	}


func _validate_main_menu_blocked_surface() -> Dictionary:
	_clear_progression_files()
	var partial_profile := {
		"version": CampaignRules.PROFILE_VERSION,
		"last_campaign_id": CAMPAIGN_ID,
	}
	if not _write_json(PROGRESSION_PATH, partial_profile):
		_fail("Could not stage MainMenu blocked-storage fixture.")
		return {}
	var live_before: Dictionary = _file_state(PROGRESSION_PATH)
	var baseline_profile: Dictionary = _profile_with_progress()
	var baseline_session: SessionStateStoreScript.SessionData = _campaign_session(false)
	CampaignProgression.profile = baseline_profile.duplicate(true)
	CampaignProgression._storage_state = {}
	CampaignProgression._last_failure_result = {}
	SessionState.active_session = baseline_session
	var session_before: Dictionary = _canonical_dictionary(baseline_session.to_dict())
	var session_instance := baseline_session.get_instance_id()
	var menu: Node = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not menu.has_method("validation_campaign_storage_snapshot"):
		menu.queue_free()
		_fail("MainMenu is missing validation_campaign_storage_snapshot.")
		return {}
	menu.call("validation_open_campaign_stage")
	var blocked: Dictionary = menu.call("validation_campaign_storage_snapshot")
	var storage: Dictionary = blocked.get("storage_state", {}) if blocked.get("storage_state", {}) is Dictionary else {}
	if not bool(blocked.get("blocked", false)) \
			or String(storage.get("status", "")) != "invalid" \
			or String(blocked.get("warning", "")).find(BLOCKED_MESSAGE_FRAGMENT) < 0 \
			or String(blocked.get("warning_surface_full", "")).find(BLOCKED_MESSAGE_FRAGMENT) < 0 \
			or not bool(blocked.get("campaign_browsing_enabled", false)) \
			or not bool(blocked.get("chapter_browsing_enabled", false)) \
			or bool(blocked.get("campaign_list_disabled", true)) \
			or bool(blocked.get("chapter_list_disabled", true)) \
			or not bool(blocked.get("primary_disabled", false)) \
			or not bool(blocked.get("chapter_start_disabled", false)) \
			or not bool(blocked.get("restart_disabled", false)) \
			or bool(blocked.get("restart_dialog_visible", true)):
		menu.queue_free()
		_fail("MainMenu did not surface blocked storage while preserving browsing: %s" % JSON.stringify({
			"status": storage.get("status", ""),
			"blocked": blocked.get("blocked", null),
			"warning": blocked.get("warning", ""),
			"campaign_browsing": blocked.get("campaign_browsing_enabled", null),
			"chapter_browsing": blocked.get("chapter_browsing_enabled", null),
			"primary_disabled": blocked.get("primary_disabled", null),
			"chapter_disabled": blocked.get("chapter_start_disabled", null),
			"restart_disabled": blocked.get("restart_disabled", null),
		}))
		return {}
	menu.call("validation_select_campaign", CAMPAIGN_ID)
	menu.call("validation_select_campaign_chapter", SCENARIO_ID)
	var start_result: Dictionary = menu.call("validation_start_selected_campaign_chapter")
	var restart_result: Dictionary = menu.call("validation_request_campaign_restart")
	var after_commands: Dictionary = menu.call("validation_campaign_storage_snapshot")
	var start_mutation: Dictionary = start_result.get("mutation_result", {}) if start_result.get("mutation_result", {}) is Dictionary else {}
	var restart_mutation: Dictionary = restart_result.get("mutation_result", {}) if restart_result.get("mutation_result", {}) is Dictionary else {}
	if bool(start_result.get("started", true)) \
			or not _blocked_result_exact(start_mutation, "invalid_storage", "invalid") \
			or not _blocked_result_exact(restart_mutation, "invalid_storage", "invalid") \
			or int(after_commands.get("blocked_command_count", 0)) < 2 \
			or bool(after_commands.get("restart_dialog_visible", true)):
		menu.queue_free()
		_fail("MainMenu blocked campaign commands were not structured/no-route: %s" % JSON.stringify({
			"started": start_result.get("started", null),
			"start": _compact_result(start_mutation),
			"restart": _compact_result(restart_mutation),
			"blocked_count": after_commands.get("blocked_command_count", -1),
		}))
		return {}

	menu.call("validation_open_skirmish_stage")
	var skirmish: Dictionary = menu.call("validation_snapshot")
	menu.call("validation_open_saves_stage")
	menu.call("validation_refresh_save_browser")
	var saves: Dictionary = menu.call("validation_snapshot")
	menu.call("validation_open_settings_stage")
	var settings: Dictionary = menu.call("validation_snapshot")
	var distinct_tabs := [
		int(skirmish.get("current_tab", -1)),
		int(saves.get("current_tab", -1)),
		int(settings.get("current_tab", -1)),
	]
	if not bool(skirmish.get("stage_dock_visible", false)) \
			or int(skirmish.get("skirmish_count", 0)) <= 0 \
			or not bool(skirmish.get("start_skirmish_enabled", false)) \
			or not bool(saves.get("stage_dock_visible", false)) \
			or not bool(saves.get("save_browser_loaded", false)) \
			or not bool(settings.get("stage_dock_visible", false)) \
			or String(settings.get("support_bundle_button_text", "")) == "" \
			or String(settings.get("restore_settings_defaults_button_text", "")) == "" \
			or distinct_tabs[0] == distinct_tabs[1] \
			or distinct_tabs[0] == distinct_tabs[2] \
			or distinct_tabs[1] == distinct_tabs[2]:
		menu.queue_free()
		_fail("Blocked campaign storage disabled unrelated MainMenu stages.")
		return {}
	if _file_state(PROGRESSION_PATH) != live_before \
			or CampaignProgression.profile != baseline_profile \
			or SessionState.active_session.get_instance_id() != session_instance \
			or _canonical_dictionary(SessionState.active_session.to_dict()) != session_before \
			or not _artifacts_absent():
		menu.queue_free()
		_fail("MainMenu blocked commands or unrelated stages changed progression/session state.")
		return {}
	menu.queue_free()
	await get_tree().process_frame
	return {
		"warning_visible": true,
		"campaign_browsing_enabled": true,
		"campaign_mutations_disabled": true,
		"blocked_command_count": int(after_commands.get("blocked_command_count", 0)),
		"skirmish_usable": true,
		"saves_usable": true,
		"settings_usable": true,
	}


func _invoke_blocked_operation(operation: String, session: SessionStateStoreScript.SessionData) -> Dictionary:
	match operation:
		"select_campaign":
			return CampaignProgression.select_campaign(CAMPAIGN_ID)
		"select_scenario":
			return CampaignProgression.select_scenario(CAMPAIGN_ID, SCENARIO_ID)
		"start_scenario":
			var started: SessionStateStoreScript.SessionData = CampaignProgression.start_scenario(SCENARIO_ID, "normal", CAMPAIGN_ID)
			if started.scenario_id != "":
				return {"ok": true, "changed": true, "reason": "unexpected_start"}
			return CampaignProgression.last_failure_result()
		"restart_campaign":
			return CampaignProgression.restart_campaign(CAMPAIGN_ID)
		"record_session_completion":
			return CampaignProgression.record_session_completion(session)
		_:
			return {"ok": true, "changed": true, "reason": "unknown_operation"}


func _blocked_result_exact(result: Dictionary, reason: String, status: String) -> bool:
	var storage: Dictionary = result.get("storage_state", {}) if result.get("storage_state", {}) is Dictionary else {}
	return not bool(result.get("ok", true)) \
		and not bool(result.get("changed", true)) \
		and String(result.get("path", "not-empty")) == "" \
		and String(result.get("reason", "")) == reason \
		and String(result.get("message", "")).find(BLOCKED_MESSAGE_FRAGMENT) >= 0 \
		and String(storage.get("status", "")) == status \
		and not bool(storage.get("writable", true))


func _valid_profile() -> Dictionary:
	return CampaignRules.normalize_profile(CampaignRules.build_profile())


func _profile_with_progress() -> Dictionary:
	return CampaignRules.record_session_completion(_valid_profile(), _campaign_session(true))


func _profile_with_campaign_state(state_value: Variant) -> Dictionary:
	return {
		"version": CampaignRules.PROFILE_VERSION,
		"last_campaign_id": CAMPAIGN_ID,
		"last_scenario_id": SCENARIO_ID,
		"campaign_states": {CAMPAIGN_ID: state_value},
	}


func _campaign_session(victory: bool) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_CAMPAIGN
	)
	session.scenario_status = "victory" if victory else "in_progress"
	session.scenario_summary = "Focused semantic progression storage fixture."
	session.game_state = "outcome" if victory else "overworld"
	OverworldRules.normalize_overworld_state(session)
	return session


func _compact_storage(storage: Dictionary) -> Dictionary:
	return {
		"ok": storage.get("ok", null),
		"status": storage.get("status", ""),
		"exists": storage.get("exists", null),
		"usable": storage.get("usable", null),
		"writable": storage.get("writable", null),
		"recovered": storage.get("recovered", null),
		"version": storage.get("version", -1),
		"expected_version": storage.get("expected_version", -1),
		"reason": storage.get("reason", ""),
		"recovery_reason": storage.get("recovery_reason", ""),
	}


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", null),
		"changed": result.get("changed", null),
		"path": result.get("path", ""),
		"operation": result.get("operation", ""),
		"reason": result.get("reason", ""),
		"message": result.get("message", ""),
		"storage": _compact_storage(result.get("storage_state", {}) if result.get("storage_state", {}) is Dictionary else {}),
	}


func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _capture_original_state() -> void:
	for path in [PROGRESSION_PATH, CANDIDATE_PATH, BACKUP_PATH]:
		_original_files[path] = _file_state(path)
	_original_active_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_storage_state = CampaignProgression._storage_state.duplicate(true)
	_original_storage_warning = CampaignProgression._storage_warning
	_original_failure_result = CampaignProgression._last_failure_result.duplicate(true)
	_original_warning_signature = CampaignProgression._last_storage_warning_signature


func _clear_progression_files() -> void:
	for path in [PROGRESSION_PATH, CANDIDATE_PATH, BACKUP_PATH]:
		_remove_path(path)


func _artifacts_absent() -> bool:
	return not FileAccess.file_exists(CANDIDATE_PATH) and not FileAccess.file_exists(BACKUP_PATH)


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _write_json(path: String, payload: Dictionary) -> bool:
	return _write_text(path, JSON.stringify(payload, "\t"))


func _write_text(path: String, value: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	_clear_progression_files()
	for path in _original_files.keys():
		var state: Dictionary = _original_files.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path), state.get("bytes", PackedByteArray()))
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_profile.duplicate(true)
	CampaignProgression._storage_state = _original_storage_state.duplicate(true)
	CampaignProgression._storage_warning = _original_storage_warning
	CampaignProgression._last_failure_result = _original_failure_result.duplicate(true)
	CampaignProgression._last_storage_warning_signature = _original_warning_signature


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
