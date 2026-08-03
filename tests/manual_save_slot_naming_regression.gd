extends Node

const REPORT_ID := "MANUAL_SAVE_SLOT_NAMING_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/manual_save_slot_naming_regression"
const CUSTOM_NAME := "Before the Causeway"

var _original_file_states := {}
var _original_active_session = null
var _original_campaign_profile := {}
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	_original_campaign_profile = CampaignProgression.ensure_profile().duplicate(true)
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	var capture_resolution := OS.get_environment("SAVE_SLOT_NAMING_TEST_RESOLUTION")
	if capture_resolution != "":
		SettingsService.set_presentation_resolution(capture_resolution)

	var active_fixture = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	active_fixture.day = 17
	SessionState.active_session = active_fixture
	var active_payload_before: Dictionary = active_fixture.to_dict()
	for slot in SaveService.MANUAL_SLOT_IDS:
		var fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
		fixture.day = 4 + int(slot)
		if SaveService.save_manual_session(fixture.to_dict(), int(slot)) == "":
			_fail("Could not seed Manual Slot %s." % slot)
			return
	var autosave_fixture = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	autosave_fixture.day = 3
	if SaveService.save_autosave_session(autosave_fixture.to_dict()) == "":
		_fail("Could not seed autosave.")
		return

	var protected_after_seed := _capture_file_states([
		_manual_slot_path(1),
		_manual_slot_path(3),
		_autosave_path(),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	])
	var campaign_before := CampaignProgression.ensure_profile().duplicate(true)
	var settings_before := SettingsService.settings.duplicate(true)
	var support_before := RuntimeIssueLog.support_bundle_snapshot().duplicate(true)
	var slot2_before := _read_dictionary(_manual_slot_path(2))

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _settle()
	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, "2")):
		_fail("Manual Slot 2 was not selectable for naming.")
		return
	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(initial_snapshot.get("save_name_edit_visible", false)) or bool(initial_snapshot.get("apply_save_name_enabled", true)):
		_fail("Valid Manual Slot 2 did not expose an initially unchanged name command: %s." % JSON.stringify(initial_snapshot))
		return

	var named_result: Dictionary = shell.call("validation_set_selected_save_name", CUSTOM_NAME)
	if not String(named_result.get("notice", "")).contains("Named Manual Slot 2"):
		_fail("Naming did not report the canonical target: %s." % JSON.stringify(named_result))
		return
	var named_summary: Dictionary = named_result.get("summary", {}) if named_result.get("summary", {}) is Dictionary else {}
	if String(named_summary.get("manual_slot_name", "")) != CUSTOM_NAME:
		_fail("The refreshed summary did not retain the custom name: %s." % JSON.stringify(named_summary))
		return
	var named_payload := _read_dictionary(_manual_slot_path(2))
	if String(named_payload.get(SaveService.SAVE_METADATA_MANUAL_NAME_KEY, "")) != CUSTOM_NAME:
		_fail("The canonical save payload did not persist the custom name.")
		return
	var payload_without_name := named_payload.duplicate(true)
	payload_without_name.erase(SaveService.SAVE_METADATA_MANUAL_NAME_KEY)
	if payload_without_name != slot2_before:
		_fail("Naming changed expedition payload fields beyond the optional name.")
		return
	if not _require_file_states(protected_after_seed, "naming changed a protected file"):
		return
	if not _require_runtime_state(active_payload_before, campaign_before, settings_before, support_before):
		return
	var named_snapshot: Dictionary = shell.call("validation_snapshot")
	if not _snapshot_contains_name(named_snapshot, CUSTOM_NAME) or not String(named_snapshot.get("save_details_full", "")).contains("%s - Manual 2" % CUSTOM_NAME):
		_fail("The Saves board did not pair the custom name with fixed Manual 2 identity: %s." % JSON.stringify({
			"items": named_snapshot.get("save_browser_items", []),
			"selected": named_snapshot.get("selected_save_summary", {}),
			"details": named_snapshot.get("save_details_full", ""),
			"name_text": named_snapshot.get("save_name_text", ""),
		}))
		return
	var latest_after_name: Dictionary = named_snapshot.get("latest_save_summary", {}) if named_snapshot.get("latest_save_summary", {}) is Dictionary else {}
	if String(latest_after_name.get("slot_type", "")) != SaveService.SLOT_TYPE_AUTOSAVE:
		_fail("Changing display metadata incorrectly promoted Manual Slot 2 to Latest: %s." % JSON.stringify(latest_after_name))
		return
	await _capture("named_manual_slot")

	var replacement = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	replacement.day = 22
	if SaveService.save_manual_session(replacement.to_dict(), 2) == "":
		_fail("Could not overwrite the named manual slot.")
		return
	var overwritten_summary := SaveService.inspect_manual_slot(2)
	if String(overwritten_summary.get("manual_slot_name", "")) != CUSTOM_NAME or int(overwritten_summary.get("day", 0)) != 22:
		_fail("Manual overwrite did not retain the player name with the new snapshot: %s." % JSON.stringify(overwritten_summary))
		return
	var loaded_payload := SaveService.load_session(2)
	if int(loaded_payload.get("day", 0)) != 22 or String(loaded_payload.get("scenario_id", "")) != "river-pass":
		_fail("The named overwritten slot no longer loaded the replacement expedition payload.")
		return

	var named_bytes := _file_state(_manual_slot_path(2))
	var long_result := SaveService.set_manual_slot_name_from_summary(overwritten_summary, "X".repeat(SaveService.MANUAL_SLOT_NAME_MAX_LENGTH + 1))
	if bool(long_result.get("ok", false)) or _file_state(_manual_slot_path(2)) != named_bytes:
		_fail("An overlong name changed Manual Slot 2: %s." % JSON.stringify(long_result))
		return
	var forged_result := SaveService.set_manual_slot_name_from_summary({
		"slot_type": SaveService.SLOT_TYPE_MANUAL,
		"slot_id": "99",
		"path": _manual_slot_path(2),
	}, "Forged")
	if bool(forged_result.get("ok", false)) or _file_state(_manual_slot_path(2)) != named_bytes:
		_fail("A forged slot identity changed Manual Slot 2: %s." % JSON.stringify(forged_result))
		return
	var autosave_result := SaveService.set_manual_slot_name_from_summary(SaveService.inspect_autosave(), "Autosave Name")
	if bool(autosave_result.get("ok", false)) or _file_state(_autosave_path()) != protected_after_seed.get(_autosave_path(), {}):
		_fail("Autosave accepted a manual-slot name: %s." % JSON.stringify(autosave_result))
		return

	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, "2")):
		_fail("Named Manual Slot 2 could not be reselected before clearing.")
		return
	var clear_result: Dictionary = shell.call("validation_set_selected_save_name", "")
	if not String(clear_result.get("notice", "")).contains("Cleared the name from Manual Slot 2"):
		_fail("Clearing did not report the canonical target: %s." % JSON.stringify(clear_result))
		return
	var cleared_payload := _read_dictionary(_manual_slot_path(2))
	if cleared_payload.has(SaveService.SAVE_METADATA_MANUAL_NAME_KEY) or String(SaveService.inspect_manual_slot(2).get("manual_slot_name", "")) != "":
		_fail("Clearing left custom-name metadata in Manual Slot 2.")
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manual_slot_path(3)))
	var empty_result := SaveService.set_manual_slot_name_from_summary({
		"slot_type": SaveService.SLOT_TYPE_MANUAL,
		"slot_id": "3",
	}, "Empty")
	if bool(empty_result.get("ok", false)) or FileAccess.file_exists(_manual_slot_path(3)):
		_fail("An empty manual slot accepted a name or created a file: %s." % JSON.stringify(empty_result))
		return
	var corrupt_file := FileAccess.open(_manual_slot_path(1), FileAccess.WRITE)
	if corrupt_file == null:
		_fail("Could not create corrupt-slot rejection fixture.")
		return
	corrupt_file.store_string("{not valid json")
	corrupt_file.close()
	var corrupt_result := SaveService.set_manual_slot_name_from_summary({
		"slot_type": SaveService.SLOT_TYPE_MANUAL,
		"slot_id": "1",
	}, "Corrupt")
	if bool(corrupt_result.get("ok", false)):
		_fail("A corrupt manual slot accepted a name: %s." % JSON.stringify(corrupt_result))
		return
	if not _require_runtime_state(active_payload_before, campaign_before, settings_before, support_before):
		return
	if SessionState.SAVE_VERSION != 9:
		_fail("Manual save naming changed the save-version contract.")
		return

	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"name_persisted": CUSTOM_NAME,
		"overwrite_retained_name": true,
		"exact_non_name_payload_preserved": true,
		"invalid_targets_rejected": ["overlong", "forged", "autosave", "empty", "corrupt"],
		"player_state_preserved": true,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _snapshot_contains_name(snapshot: Dictionary, expected_name: String) -> bool:
	for label in snapshot.get("save_browser_items", []):
		if String(label).contains(expected_name) and String(label).contains("Manual 2"):
			return true
	return false

func _require_file_states(expected: Dictionary, context: String) -> bool:
	for path_value in expected.keys():
		var path := String(path_value)
		if _file_state(path) != expected.get(path, {}):
			_fail("%s: %s." % [context, path])
			return false
	return true

func _require_runtime_state(active_payload: Dictionary, campaign_profile: Dictionary, settings_state: Dictionary, support_state: Dictionary) -> bool:
	if SessionState.active_session == null or SessionState.active_session.to_dict() != active_payload:
		_fail("Manual save naming changed the active in-memory expedition.")
		return false
	if CampaignProgression.ensure_profile() != campaign_profile or SettingsService.settings != settings_state:
		_fail("Manual save naming changed campaign progression or device settings.")
		return false
	if RuntimeIssueLog.support_bundle_snapshot() != support_state:
		_fail("Manual save naming changed support diagnostics.")
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

func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}

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
	SettingsService.apply_settings()

func _capture(stem: String) -> void:
	if OS.get_environment("SAVE_SLOT_NAMING_CAPTURE") != "1":
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
