extends Node

const REPORT_ID := "SAVE_SLOT_DELETE_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/save_slot_delete_regression"

var _original_file_states := {}
var _original_active_session = null
var _original_campaign_profile := {}
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tracked_paths := _tracked_paths()
	_original_file_states = _capture_file_states(tracked_paths)
	_original_active_session = SessionState.active_session
	_original_campaign_profile = CampaignProgression.ensure_profile().duplicate(true)
	_original_settings = SettingsService.settings.duplicate(true)

	var active_fixture = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	active_fixture.day = 11
	SessionState.active_session = active_fixture
	var active_payload_before: Dictionary = active_fixture.to_dict()

	var save_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	save_fixture.day = 7
	for slot in SaveService.get_manual_slot_ids():
		if SaveService.save_manual_session(save_fixture.to_dict(), int(slot)) == "":
			_fail("Could not seed manual slot %s." % slot)
			return
	if SaveService.save_autosave_session(save_fixture.to_dict()) == "":
		_fail("Could not seed autosave.")
		return

	var autosave_path := _autosave_path()
	var slot1_path := _manual_slot_path(1)
	var slot2_path := _manual_slot_path(2)
	var slot3_path := _manual_slot_path(3)
	var progression_path := _progression_path()
	var settings_path := String(SettingsService.SETTINGS_FILE)
	var protected_after_seed := _capture_file_states([
		autosave_path,
		slot1_path,
		slot3_path,
		progression_path,
		settings_path,
	])
	var campaign_before_delete := CampaignProgression.ensure_profile().duplicate(true)
	var settings_before_delete := SettingsService.settings.duplicate(true)

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _settle()
	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, "2")):
		_fail("Manual Slot 2 was not selectable.")
		return
	var manual_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(manual_snapshot.get("save_delete_visible", false)) or not bool(manual_snapshot.get("save_delete_enabled", false)):
		_fail("Occupied manual slot did not expose Delete Save: %s." % JSON.stringify(manual_snapshot))
		return

	var manual_request: Dictionary = shell.call("validation_request_selected_save_delete")
	if not bool(manual_request.get("dialog_visible", false)) or manual_request.get("pending_identity", {}) != {"slot_type": SaveService.SLOT_TYPE_MANUAL, "slot_id": "2"}:
		_fail("Manual deletion did not require exact slot-bound confirmation: %s." % JSON.stringify(manual_request))
		return
	var manual_confirmation_text := "%s\n%s" % [String(manual_request.get("title", "")), String(manual_request.get("text", ""))]
	for token in ["Manual Slot 2", "River Pass", "permanently removes only this expedition save", "campaign progress", "active expedition"]:
		if not manual_confirmation_text.contains(token):
			_fail("Manual delete confirmation omitted %s: %s." % [token, manual_confirmation_text])
			return
	await _capture("delete_manual_confirmation")

	shell.call("validation_cancel_selected_save_delete")
	if not FileAccess.file_exists(slot2_path):
		_fail("Canceling manual deletion removed the selected file.")
		return
	manual_request = shell.call("validation_request_selected_save_delete")
	if not bool(manual_request.get("dialog_visible", false)) or not FileAccess.file_exists(slot2_path):
		_fail("Reopened manual confirmation mutated the selected file.")
		return
	var manual_result: Dictionary = shell.call("validation_confirm_selected_save_delete")
	if FileAccess.file_exists(slot2_path):
		_fail("Confirmed manual deletion left Manual Slot 2 on disk: %s." % JSON.stringify(manual_result))
		return
	if String(manual_result.get("selected_key_after", "")) != "manual:2" or not String(manual_result.get("notice", "")).contains("Manual Slot 2 was deleted"):
		_fail("Manual deletion did not keep the empty slot selected with clear feedback: %s." % JSON.stringify(manual_result))
		return
	var manual_after: Dictionary = shell.call("validation_snapshot")
	if bool(manual_after.get("save_delete_visible", true)) or bool(manual_after.get("save_delete_enabled", true)):
		_fail("Empty Manual Slot 2 still exposed Delete Save: %s." % JSON.stringify(manual_after))
		return
	if not _require_file_states(protected_after_seed, "manual deletion changed protected files"):
		return
	if not _require_runtime_state(active_payload_before, campaign_before_delete, settings_before_delete):
		return
	await _capture("delete_manual_complete")

	var forged_result := SaveService.delete_session_from_summary({
		"slot_type": "unknown",
		"slot_id": "forged",
		"path": slot1_path,
	})
	if bool(forged_result.get("ok", false)) or _file_state(slot1_path) != protected_after_seed.get(slot1_path, {}):
		_fail("A forged summary path could delete or alter Manual Slot 1: %s." % JSON.stringify(forged_result))
		return
	var invalid_manual_result := SaveService.delete_session_from_summary({
		"slot_type": SaveService.SLOT_TYPE_MANUAL,
		"slot_id": "99",
		"path": slot1_path,
	})
	if bool(invalid_manual_result.get("ok", false)) or _file_state(slot1_path) != protected_after_seed.get(slot1_path, {}):
		_fail("An invalid manual slot id could delete or alter Manual Slot 1: %s." % JSON.stringify(invalid_manual_result))
		return

	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_AUTOSAVE, SaveService.SLOT_TYPE_AUTOSAVE)):
		_fail("Autosave was not selectable after manual deletion.")
		return
	var autosave_request: Dictionary = shell.call("validation_request_selected_save_delete")
	var autosave_text := "%s\n%s" % [String(autosave_request.get("title", "")), String(autosave_request.get("text", ""))]
	if not bool(autosave_request.get("dialog_visible", false)) or not autosave_text.contains("Autosave"):
		_fail("Autosave deletion did not require named confirmation: %s." % JSON.stringify(autosave_request))
		return
	shell.call("validation_confirm_selected_save_delete")
	if FileAccess.file_exists(autosave_path):
		_fail("Confirmed autosave deletion left the autosave on disk.")
		return
	var autosave_after: Dictionary = shell.call("validation_snapshot")
	var latest_after_autosave: Dictionary = autosave_after.get("latest_save_summary", {}) if autosave_after.get("latest_save_summary", {}) is Dictionary else {}
	if String(autosave_after.get("selected_save_key", "")) != "autosave:autosave" or String(latest_after_autosave.get("slot_type", "")) != SaveService.SLOT_TYPE_MANUAL or not SaveService.can_load_summary(latest_after_autosave):
		_fail("Autosave deletion did not refresh the empty selection and latest manual fallback: %s." % JSON.stringify(autosave_after))
		return
	var protected_after_autosave := protected_after_seed.duplicate(true)
	protected_after_autosave.erase(autosave_path)
	if not _require_file_states(protected_after_autosave, "autosave deletion changed protected files"):
		return
	if not _require_runtime_state(active_payload_before, campaign_before_delete, settings_before_delete):
		return

	var corrupt_file := FileAccess.open(slot2_path, FileAccess.WRITE)
	if corrupt_file == null:
		_fail("Could not create corrupt-slot fixture.")
		return
	corrupt_file.store_string(JSON.stringify({"not_a_session": true}))
	corrupt_file.close()
	shell.call("validation_refresh_save_browser")
	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, "2")):
		_fail("Corrupt Manual Slot 2 was not selectable.")
		return
	var corrupt_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(corrupt_snapshot.get("load_selected_enabled", true)) or not bool(corrupt_snapshot.get("save_delete_enabled", false)):
		_fail("Corrupt slot did not remain deletable while loading stayed blocked: %s." % JSON.stringify(corrupt_snapshot))
		return
	var corrupt_request: Dictionary = shell.call("validation_request_selected_save_delete")
	if not String(corrupt_request.get("text", "")).contains("unreadable save"):
		_fail("Corrupt-slot confirmation did not explain the unreadable file: %s." % JSON.stringify(corrupt_request))
		return
	shell.call("validation_confirm_selected_save_delete")
	if FileAccess.file_exists(slot2_path):
		_fail("Confirmed corrupt-slot deletion left the file on disk.")
		return
	if not _require_file_states(protected_after_autosave, "corrupt-slot deletion changed protected files"):
		return
	if not _require_runtime_state(active_payload_before, campaign_before_delete, settings_before_delete):
		return

	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"manual_slot_deleted": 2,
		"autosave_deleted": true,
		"corrupt_slot_deleted": true,
		"confirmation_required": true,
		"forged_path_rejected": true,
		"unrelated_save_files_preserved": 3,
		"campaign_progress_preserved": true,
		"device_settings_preserved": true,
		"active_session_preserved": true,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _require_file_states(expected: Dictionary, context: String) -> bool:
	for path_value in expected.keys():
		var path := String(path_value)
		if _file_state(path) != expected.get(path, {}):
			_fail("%s: %s." % [context, path])
			return false
	return true

func _require_runtime_state(active_payload: Dictionary, campaign_profile: Dictionary, settings_state: Dictionary) -> bool:
	if SessionState.active_session == null or SessionState.active_session.to_dict() != active_payload:
		_fail("Save deletion changed the active in-memory expedition.")
		return false
	if CampaignProgression.ensure_profile() != campaign_profile:
		_fail("Save deletion changed in-memory campaign progression.")
		return false
	if SettingsService.settings != settings_state:
		_fail("Save deletion changed in-memory device settings.")
		return false
	if SessionState.SAVE_VERSION != 9:
		_fail("Save deletion changed the runtime save-version contract.")
		return false
	return true

func _tracked_paths() -> Array:
	return [
		_autosave_path(),
		_manual_slot_path(1),
		_manual_slot_path(2),
		_manual_slot_path(3),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	]

func _autosave_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]

func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]

func _progression_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]

func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _restore_original_state() -> void:
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("bytes", PackedByteArray()))
				file.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_campaign_profile.duplicate(true)
	SettingsService.settings = _original_settings.duplicate(true)

func _capture(stem: String) -> void:
	if OS.get_environment("SAVE_SLOT_DELETE_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [absolute_dir, stem, image.get_width(), image.get_height()])

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _fail(message: String) -> void:
	_restore_original_state()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
