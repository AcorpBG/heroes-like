extends Node

const REPORT_ID := "SETTINGS_RESTORE_DEFAULTS_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/settings_restore_defaults_regression"

var _original_settings := {}
var _original_settings_file := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_settings_file = _file_state(SettingsService.SETTINGS_FILE)

	var custom := SettingsService.build_default_settings()
	custom["audio"]["master_volume_percent"] = 31
	custom["audio"]["music_volume_percent"] = 42
	custom["audio"]["effects_volume_percent"] = 53
	var capture_resolution := OS.get_environment("SETTINGS_RESTORE_TEST_RESOLUTION")
	if capture_resolution != "":
		custom["presentation"]["resolution"] = capture_resolution
	custom["presentation"]["render_quality"] = SettingsService.RENDER_QUALITY_LOW
	custom["presentation"]["vsync_enabled"] = false
	custom["presentation"]["frame_rate_limit"] = 120
	custom["gameplay"]["battle_playback_speed"] = SettingsService.BATTLE_PLAYBACK_SPEED_FAST
	custom["gameplay"]["keyboard_navigation_layout"] = SettingsService.KEYBOARD_NAVIGATION_LAYOUT_IJKL
	custom["gameplay"]["hero_movement_bindings"] = {"hero_move_up": KEY_P}
	custom["accessibility"]["ui_scale_percent"] = 115
	custom["accessibility"]["large_ui_text"] = true
	custom["accessibility"]["high_contrast_ui"] = true
	custom["accessibility"]["color_cue_mode"] = SettingsService.COLOR_CUE_MODE_ASSISTED
	custom["accessibility"]["battle_camera_shake"] = SettingsService.BATTLE_CAMERA_SHAKE_REDUCED
	custom["accessibility"]["reduce_flashes"] = true
	custom["accessibility"]["reduce_motion"] = true
	custom["accessibility"]["reduce_repetitive_sounds"] = true
	SettingsService.settings = custom.duplicate(true)
	SettingsService.apply_settings()
	if SettingsService.save_settings() != SettingsService.SETTINGS_FILE:
		_fail("Could not persist the non-default settings fixture.")
		return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _settle()
	var protected_files := _protected_file_states()
	var active_session_before = SessionState.active_session
	var active_session_payload := active_session_before.to_dict() if active_session_before != null else {}
	var campaign_before := CampaignProgression.ensure_profile().duplicate(true)
	var support_before := RuntimeIssueLog.support_bundle_snapshot().duplicate(true)
	var custom_memory := SettingsService.settings.duplicate(true)
	var custom_file := _file_state(SettingsService.SETTINGS_FILE)

	var request: Dictionary = shell.call("validation_request_settings_restore_defaults")
	if not bool(request.get("pending", false)) or not bool(request.get("dialog_visible", false)):
		_fail("Restore Defaults did not open a pending confirmation: %s." % JSON.stringify(request))
		return
	var confirmation_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	for token in ["presentation", "sound", "gameplay", "custom movement keys", "readability", "Campaign progress", "expedition saves"]:
		if not confirmation_text.contains(token):
			_fail("Restore confirmation omitted %s: %s." % [token, confirmation_text])
			return
	await _capture("restore_defaults_confirmation")

	shell.call("validation_cancel_settings_restore_defaults")
	if SettingsService.settings != custom_memory or _file_state(SettingsService.SETTINGS_FILE) != custom_file:
		_fail("Canceling Restore Defaults changed settings in memory or on disk.")
		return

	request = shell.call("validation_request_settings_restore_defaults")
	if not bool(request.get("pending", false)):
		_fail("Restore confirmation could not be reopened after cancellation.")
		return
	var result: Dictionary = shell.call("validation_confirm_settings_restore_defaults")
	var defaults := SettingsService.build_default_settings()
	if bool(result.get("pending", true)) or SettingsService.settings != defaults:
		_fail("Confirmed restore did not apply the complete default settings object: %s." % JSON.stringify(result))
		return
	if not String(result.get("status", "")).contains("restored and saved"):
		_fail("Confirmed restore did not report successful persistence: %s." % JSON.stringify(result))
		return
	if SettingsService.has_custom_hero_movement_bindings() or not _action_has_key(&"hero_move_up", KEY_W) or _action_has_key(&"hero_move_up", KEY_P):
		_fail("Default WASD movement did not replace the custom movement binding.")
		return
	if not is_equal_approx(get_tree().root.content_scale_factor, 1.0) or SettingsService.high_contrast_ui_enabled() or SettingsService.color_cue_mode_id() != SettingsService.COLOR_CUE_MODE_STANDARD:
		_fail("Default readability settings were not applied to the live runtime.")
		return
	if Engine.max_fps != 0 or SettingsService.battle_playback_speed_id() != SettingsService.BATTLE_PLAYBACK_SPEED_NORMAL:
		_fail("Default pacing and gameplay settings were not applied to the live runtime.")
		return
	if SettingsService.reduced_repetitive_sounds_enabled():
		_fail("Restore Defaults did not restore normal sound repetition.")
		return

	SettingsService.settings = {}
	SettingsService.load_settings()
	if SettingsService.settings != defaults:
		_fail("Restored defaults did not survive a settings service reload.")
		return
	if _protected_file_states() != protected_files:
		_fail("Restoring device defaults changed campaign progression or an expedition save file.")
		return
	var active_session_after = SessionState.active_session
	var active_payload_after := active_session_after.to_dict() if active_session_after != null else {}
	if active_payload_after != active_session_payload or CampaignProgression.ensure_profile() != campaign_before:
		_fail("Restoring device defaults changed the active session or campaign profile.")
		return
	if RuntimeIssueLog.support_bundle_snapshot() != support_before or SessionState.SAVE_VERSION != 9:
		_fail("Restoring device defaults changed support diagnostics or the save-version contract.")
		return

	_restore_original_settings()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"defaults_persisted": true,
		"cancel_preserved_exact_bytes": true,
		"custom_movement_keys_cleared": true,
		"player_state_preserved": true,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _protected_file_states() -> Dictionary:
	var paths := [
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
	]
	for slot in SaveService.MANUAL_SLOT_IDS:
		paths.append("%s/manual_slot_%d.json" % [SaveService.SAVE_DIR, int(slot)])
	var states := {}
	for path in paths:
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode):
			return true
	return false

func _capture(stem: String) -> void:
	if OS.get_environment("SETTINGS_RESTORE_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [absolute_dir, stem, image.get_width(), image.get_height()])

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _restore_original_settings() -> void:
	var existed := bool(_original_settings_file.get("exists", false))
	if existed:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR))
		var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_original_settings_file.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE))
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()

func _fail(message: String) -> void:
	_restore_original_settings()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
