extends Node

const REPORT_ID := "SETTINGS_RESTORE_DEFAULTS_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/settings_restore_defaults_regression"
# Physical B/Escape exercise the same validation_cancel_settings_restore_defaults production handler.

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
	var origin_button: Button = shell.get_node("%RestoreSettingsDefaults")
	var dialog: ConfirmationDialog = shell.get_node("SettingsRestoreDefaultsDialog")
	shell.call("validation_open_settings_stage")
	await _settle()
	origin_button.grab_focus()

	var request: Dictionary = shell.call("validation_request_settings_restore_defaults")
	await _settle()
	if not bool(request.get("pending", false)) or not bool(request.get("dialog_visible", false)):
		_fail("Restore Defaults did not open a pending confirmation: %s." % JSON.stringify(request))
		return
	var confirmation_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	for token in ["presentation", "sound", "gameplay", "custom movement keys", "readability", "Campaign progress", "expedition saves"]:
		if not confirmation_text.contains(token):
			_fail("Restore confirmation omitted %s: %s." % [token, confirmation_text])
			return
	if not _safe_dialog_ready(dialog, "Keep Settings"):
		_fail("Restore Defaults confirmation did not focus its compact Keep Settings action in the native dialog viewport.")
		return
	await _capture("restore_defaults_confirmation")

	await _press_joypad_button(JOY_BUTTON_B)
	if not _restore_cancel_exact(dialog, origin_button, custom_memory, custom_file, protected_files, active_session_payload, campaign_before, support_before):
		_fail("Joypad B did not cancel Restore Defaults exactly and restore Restore Defaults focus.")
		return

	request = shell.call("validation_request_settings_restore_defaults")
	await _settle()
	if not bool(request.get("pending", false)) or not _safe_dialog_ready(dialog, "Keep Settings"):
		_fail("Restore confirmation could not reopen safely after joypad cancellation.")
		return
	await _press_key(KEY_ESCAPE)
	if not _restore_cancel_exact(dialog, origin_button, custom_memory, custom_file, protected_files, active_session_payload, campaign_before, support_before):
		_fail("Escape did not cancel Restore Defaults exactly and restore Restore Defaults focus.")
		return
	request = shell.call("validation_request_settings_restore_defaults")
	await _settle()
	if not bool(request.get("pending", false)) or not _safe_dialog_ready(dialog, "Keep Settings"):
		_fail("Restore confirmation could not reopen safely for confirmation.")
		return
	var result: Dictionary = shell.call("validation_confirm_settings_restore_defaults")
	var confirmation_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(confirmation_snapshot.get("settings_restore_confirm_count", -1)) != 1:
		_fail("Restore Defaults confirmation did not execute exactly once: %s." % JSON.stringify(confirmation_snapshot.get("settings_restore_confirm_count", -1)))
		return
	var defaults := SettingsService.build_default_settings()
	if bool(result.get("pending", true)):
		_fail("Confirmed restore left the first confirmation pending: %s." % JSON.stringify(result))
		return
	if bool(result.get("display_change_pending", false)):
		var deferred_defaults := defaults.duplicate(true)
		deferred_defaults["presentation"]["mode"] = String(custom.get("presentation", {}).get("mode", SettingsService.PRESENTATION_WINDOWED))
		deferred_defaults["presentation"]["resolution"] = String(custom.get("presentation", {}).get("resolution", SettingsService.PRESENTATION_RESOLUTION_DEFAULT))
		if SettingsService.settings != deferred_defaults or not bool(result.get("display_dialog_visible", false)):
			_fail("Restore Defaults did not keep committed display values while previewing defaults: %s." % JSON.stringify(result))
			return
		var display_result: Dictionary = shell.call("validation_confirm_display_change")
		if bool(display_result.get("pending", true)) or bool(display_result.get("dialog_visible", true)):
			_fail("Keeping the default display preview did not finish the transaction: %s." % JSON.stringify(display_result))
			return
		result = display_result
	if SettingsService.settings != defaults:
		_fail("Confirmed restore did not apply the complete default settings object: %s." % JSON.stringify(result))
		return
	var restore_status := String(result.get("status", ""))
	if not restore_status.contains("restored and saved") and not restore_status.contains("kept and saved"):
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
		"safe_cancel_focus": "Keep Settings",
		"joypad_b_cancel_exact": true,
		"escape_cancel_exact": true,
		"origin_focus_restored": true,
		"confirm_exactly_once": true,
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

func _restore_cancel_exact(
	dialog: ConfirmationDialog,
	origin_button: Button,
	expected_settings: Dictionary,
	expected_settings_file: Dictionary,
	expected_protected_files: Dictionary,
	expected_active_payload: Dictionary,
	expected_campaign_profile: Dictionary,
	expected_support_snapshot: Dictionary
) -> bool:
	var active_session = SessionState.active_session
	var active_payload := active_session.to_dict() if active_session != null else {}
	return not dialog.visible \
		and get_viewport().gui_get_focus_owner() == origin_button \
		and SettingsService.settings == expected_settings \
		and _file_state(SettingsService.SETTINGS_FILE) == expected_settings_file \
		and _protected_file_states() == expected_protected_files \
		and active_payload == expected_active_payload \
		and CampaignProgression.ensure_profile() == expected_campaign_profile \
		and RuntimeIssueLog.support_bundle_snapshot() == expected_support_snapshot

func _safe_dialog_ready(dialog: ConfirmationDialog, expected_cancel_text: String) -> bool:
	if dialog == null or not dialog.visible or dialog.get_cancel_button().text != expected_cancel_text:
		return false
	var dialog_viewport := dialog.get_cancel_button().get_viewport()
	return dialog_viewport != null \
		and dialog_viewport.gui_get_focus_owner() == dialog.get_cancel_button() \
		and dialog.size.x <= 960 and dialog.size.y <= 540

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

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
