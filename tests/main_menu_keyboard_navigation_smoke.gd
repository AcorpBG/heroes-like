extends Node

const REPORT_ID := "MAIN_MENU_KEYBOARD_NAVIGATION_SMOKE"
const CAPTURE_DIR := "res://.artifacts/main_menu_keyboard_navigation_smoke"
const RESTART_CAMPAIGN_ID := "campaign_reedfall"
const RESTART_SCENARIO_ID := "river-pass"
const DESTRUCTIVE_MANUAL_SLOT := 2

var _failed := false
var _destructive_fixture_active := false
var _destructive_original_profile := {}
var _destructive_original_progression_file := {}
var _destructive_original_manual_file := {}
var _destructive_original_selected_slot := 1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect_focus("OpenCampaign", "initial menu entry")
	var campaign_button: Button = shell.get_node("BackdropCommandHotspots/OpenCampaign")
	if campaign_button.focus_mode != Control.FOCUS_ALL:
		_fail("Campaign command is not keyboard focusable.")
		return
	if campaign_button.get_theme_stylebox("focus") == null:
		_fail("Campaign command has no visible focus style.")
		return
	await _capture_if_requested("first_view_campaign_focus")
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_expect_focus("OpenSkirmish", "first-view controller D-pad navigation")
	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	_expect_focus("OpenCampaign", "first-view controller D-pad return")
	await _press_joypad_button(JOY_BUTTON_A)
	await get_tree().process_frame
	var controller_campaign_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(controller_campaign_snapshot.get("stage_dock_visible", false)) or int(controller_campaign_snapshot.get("current_tab", -1)) != 0:
		_fail("Controller accept did not open the focused Campaign board: %s" % controller_campaign_snapshot)
		return
	await _press_joypad_button(JOY_BUTTON_B)
	await get_tree().process_frame
	if bool(shell.call("validation_snapshot").get("stage_dock_visible", true)):
		_fail("Controller cancel did not close the Campaign board.")
		return
	_expect_focus("OpenCampaign", "controller board focus return")

	await _press_action("ui_down")
	_expect_focus("OpenSkirmish", "first-view down navigation")
	await _press_action("ui_up")
	_expect_focus("OpenCampaign", "first-view up navigation")
	await _press_action("ui_accept")
	await get_tree().process_frame
	var campaign_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(campaign_snapshot.get("stage_dock_visible", false)) or int(campaign_snapshot.get("current_tab", -1)) != 0:
		_fail("Accept did not open the focused Campaign board: %s" % campaign_snapshot)
		return
	_expect_focus("CampaignList", "campaign board entry")

	await _press_action("ui_cancel")
	await get_tree().process_frame
	if bool(shell.call("validation_snapshot").get("stage_dock_visible", true)):
		_fail("Cancel did not close the Campaign board.")
		return
	_expect_focus("OpenCampaign", "campaign board focus return")
	if not await _check_destructive_dialog_controller_cancel(shell):
		return
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	_expect_focus("OpenCampaign", "first-view return after destructive dialog checks")

	for _step in range(3):
		await _press_action("ui_down")
	_expect_focus("OpenSettings", "settings command navigation")
	await _press_action("ui_accept")
	await get_tree().process_frame
	var settings_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("stage_dock_visible", false)) or int(settings_snapshot.get("current_tab", -1)) != 4:
		_fail("Accept did not open the focused Settings board: %s" % settings_snapshot)
		return
	_expect_focus("PresentationModePicker", "settings board entry")
	var speed_items: Array = settings_snapshot.get("battle_playback_speed_picker_items", []) if settings_snapshot.get("battle_playback_speed_picker_items", []) is Array else []
	if speed_items != ["Normal", "Fast", "Instant"]:
		_fail("Settings board did not expose all battle playback choices: %s" % speed_items)
		return
	if not String(settings_snapshot.get("battle_playback_speed_tooltip", "")).contains("without changing combat results"):
		_fail("Battle playback setting did not explain its presentation-only boundary: %s" % settings_snapshot)
		return
	for display_tooltip_key in ["presentation_mode_tooltip", "presentation_resolution_tooltip"]:
		var display_tooltip := String(settings_snapshot.get(display_tooltip_key, ""))
		if not display_tooltip.contains("stored only after Keep") or not display_tooltip.contains("Revert or timeout"):
			_fail("Display selector did not explain its preview persistence boundary: %s" % display_tooltip)
			return
	var original_resolution := SettingsService.presentation_resolution_id()
	var preview_resolution := ""
	for option_value in settings_snapshot.get("presentation_resolution_options", []):
		var option: Dictionary = option_value if option_value is Dictionary else {}
		var option_id := String(option.get("id", ""))
		if option_id != "" and option_id != original_resolution:
			preview_resolution = option_id
			break
	if preview_resolution == "":
		_fail("Settings board has no alternate resolution for rollback validation.")
		return
	var committed_settings_before := JSON.stringify(SettingsService.ensure_settings())
	var settings_file_before := _settings_file_state()
	if not bool(shell.call("validation_select_resolution", preview_resolution)):
		_fail("Resolution picker could not start a display preview for %s." % preview_resolution)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	settings_snapshot = shell.call("validation_snapshot")
	var display_dialog: ConfirmationDialog = shell.get_node("DisplayChangeConfirmationDialog")
	if not bool(settings_snapshot.get("display_change_dialog_visible", false)) \
			or not bool(settings_snapshot.get("display_change_snapshot", {}).get("pending", false)) \
			or String(settings_snapshot.get("display_change_ok_text", "")) != "Keep" \
			or String(settings_snapshot.get("display_change_cancel_text", "")) != "Revert" \
			or "automatically" not in String(settings_snapshot.get("display_change_dialog_text", "")).to_lower():
		_fail("Resolution preview omitted its Keep/Revert countdown dialog: %s" % settings_snapshot)
		return
	if display_dialog.get_viewport().gui_get_focus_owner() != display_dialog.get_cancel_button():
		_fail("Display preview did not put initial focus on Revert: owner=%s." % display_dialog.get_viewport().gui_get_focus_owner())
		return
	if SettingsService.presentation_resolution_id() != original_resolution \
			or JSON.stringify(SettingsService.ensure_settings()) != committed_settings_before \
			or _settings_file_state() != settings_file_before:
		_fail("Display preview changed committed settings before Keep.")
		return
	await _press_joypad_button(JOY_BUTTON_B)
	await get_tree().process_frame
	if SettingsService.display_change_pending() or display_dialog.visible:
		_fail("Controller B did not revert and close the display preview.")
		return
	if SettingsService.presentation_resolution_id() != original_resolution \
			or JSON.stringify(SettingsService.ensure_settings()) != committed_settings_before \
			or _settings_file_state() != settings_file_before:
		_fail("Reverting the display preview changed committed settings or config bytes.")
		return
	_expect_focus("ResolutionPicker", "display preview Revert focus return")
	await _capture_if_requested("settings_entry_focus")
	if OS.get_environment("MAIN_MENU_KEYBOARD_CAPTURE") == "1":
		var original_ui_scale := SettingsService.ui_scale_percent()
		var original_shake_mode := SettingsService.battle_camera_shake_mode_id()
		if not bool(shell.call("validation_select_ui_scale", 130)) or not bool(shell.call("validation_select_battle_camera_shake", "reduced")):
			_fail("Could not prepare the 130 percent Reduced battle-shake settings capture.")
			return
		shell.call("validation_reveal_reduced_flashes")
		await get_tree().process_frame
		await _capture_if_requested("settings_130_reduced_shake")
		shell.call("validation_select_ui_scale", original_ui_scale)
		shell.call("validation_select_battle_camera_shake", original_shake_mode)

	await _press_action("ui_cancel")
	await get_tree().process_frame
	_expect_focus("OpenSettings", "settings board focus return")
	if _failed:
		return
	_restore_destructive_fixture()
	print("%s PASS" % REPORT_ID)
	shell.queue_free()
	get_tree().quit(0)

func _check_destructive_dialog_controller_cancel(shell: Node) -> bool:
	if not _prepare_destructive_fixture():
		return false
	shell.call("validation_open_campaign_stage")
	if not bool(shell.call("validation_select_campaign", RESTART_CAMPAIGN_ID)):
		return _fail_bool("Could not select the seeded campaign for controller restart confirmation.")
	await _settle()
	var restart_button: Button = shell.get_node_or_null("%RestartCampaignArc")
	var restart_dialog: ConfirmationDialog = shell.get_node_or_null("CampaignRestartDialog")
	if restart_button == null or restart_dialog == null or restart_button.disabled:
		return _fail_bool("Seeded campaign did not expose a live Restart Arc confirmation origin.")
	if not await _exercise_destructive_cancel(shell, restart_button, restart_dialog, "Keep Progress", "campaign_restart"):
		return false

	if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, str(DESTRUCTIVE_MANUAL_SLOT))):
		return _fail_bool("Could not select the seeded manual save for controller deletion confirmation.")
	await _settle()
	var delete_button: Button = shell.get_node_or_null("%DeleteSelectedSave")
	var delete_dialog: ConfirmationDialog = shell.get_node_or_null("SaveDeleteDialog")
	if delete_button == null or delete_dialog == null or delete_button.disabled:
		return _fail_bool("Seeded manual save did not expose a live Delete Save confirmation origin.")
	if not await _exercise_destructive_cancel(shell, delete_button, delete_dialog, "Keep Save", "save_delete"):
		return false

	shell.call("validation_open_settings_stage")
	await _settle()
	var restore_button: Button = shell.get_node_or_null("%RestoreSettingsDefaults")
	var restore_dialog: ConfirmationDialog = shell.get_node_or_null("SettingsRestoreDefaultsDialog")
	if restore_button == null or restore_dialog == null or restore_button.disabled:
		return _fail_bool("Settings did not expose a live Restore Defaults confirmation origin.")
	if not await _exercise_destructive_cancel(shell, restore_button, restore_dialog, "Keep Settings", "settings_restore"):
		return false
	return true

func _exercise_destructive_cancel(
	shell: Node,
	origin: Button,
	dialog: ConfirmationDialog,
	expected_cancel_text: String,
	context: String
) -> bool:
	var protected_before := _destructive_protected_state()
	for cancel_kind in ["controller_b", "escape"]:
		origin.grab_focus()
		await get_tree().process_frame
		if get_viewport().gui_get_focus_owner() != origin:
			return _fail_bool("%s could not establish exact origin focus before %s." % [context, cancel_kind])
		await _press_joypad_button(JOY_BUTTON_A)
		await _settle()
		if not dialog.visible:
			return _fail_bool("Controller A did not open the live %s confirmation." % context)
		if dialog.get_cancel_button().text != expected_cancel_text:
			return _fail_bool("%s safe-cancel action expected '%s', got '%s'." % [context, expected_cancel_text, dialog.get_cancel_button().text])
		var dialog_viewport := dialog.get_cancel_button().get_viewport()
		var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
		if dialog_focus_owner != dialog.get_cancel_button():
			return _fail_bool("%s did not initially focus its safe cancel action in the native dialog viewport: %s." % [context, dialog_focus_owner])
		if not _dialog_fits_root_viewport(dialog):
			return _fail_bool("%s confirmation exceeded the live viewport: position=%s size=%s viewport=%s." % [context, dialog.position, dialog.size, get_viewport().get_visible_rect().size])
		if not _destructive_pending_matches(shell, context, true):
			return _fail_bool("%s did not retain its live pending action while open: %s." % [context, shell.call("validation_snapshot")])
		if _destructive_protected_state() != protected_before:
			return _fail_bool("Opening %s mutated protected game/settings/save state." % context)
		if cancel_kind == "controller_b":
			await _press_joypad_button(JOY_BUTTON_B)
		else:
			await _press_key(KEY_ESCAPE)
		await _settle()
		if dialog.visible or not _destructive_pending_matches(shell, context, false):
			return _fail_bool("%s did not close and clear its pending action after %s." % [context, cancel_kind])
		if _destructive_protected_state() != protected_before:
			return _fail_bool("Canceling %s with %s mutated protected game/settings/save state." % [context, cancel_kind])
		if get_viewport().gui_get_focus_owner() != origin:
			return _fail_bool("Canceling %s with %s did not restore the exact origin focus: expected=%s got=%s." % [context, cancel_kind, origin.name, _focus_name()])
	var final_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(final_snapshot.get("%s_request_count" % context, -1)) != 2 \
			or int(final_snapshot.get("%s_cancel_count" % context, -1)) != 2 \
			or int(final_snapshot.get("%s_confirm_count" % context, -1)) != 0 \
			or String(final_snapshot.get("%s_return_focus_name" % context, "")) != "" \
			or String(final_snapshot.get("%s_origin_focus_owner" % context, "")) != String(origin.name):
		return _fail_bool("%s controller cancel counts/origin snapshot were not exact: %s." % [context, final_snapshot.get("%s_confirmation" % context, {})])
	return true

func _destructive_pending_matches(shell: Node, context: String, expected_pending: bool) -> bool:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	match context:
		"campaign_restart":
			return bool(snapshot.get("campaign_restart_dialog_visible", false)) == expected_pending \
				and (String(snapshot.get("campaign_restart_pending_id", "")) != "") == expected_pending
		"save_delete":
			var identity_value: Variant = snapshot.get("save_delete_pending_identity", {})
			var identity: Dictionary = identity_value if identity_value is Dictionary else {}
			return bool(snapshot.get("save_delete_dialog_visible", false)) == expected_pending \
				and (not identity.is_empty()) == expected_pending
		"settings_restore":
			return bool(snapshot.get("settings_restore_dialog_visible", false)) == expected_pending \
				and bool(snapshot.get("settings_restore_pending", false)) == expected_pending
	return false

func _prepare_destructive_fixture() -> bool:
	if _destructive_fixture_active:
		return true
	_destructive_original_profile = CampaignProgression.ensure_profile().duplicate(true)
	_destructive_original_progression_file = _file_state(_progression_path())
	_destructive_original_manual_file = _file_state(_manual_slot_path(DESTRUCTIVE_MANUAL_SLOT))
	_destructive_original_selected_slot = SaveService.get_selected_manual_slot()
	_destructive_fixture_active = true

	var seeded_profile := CampaignRules.normalize_profile(_destructive_original_profile)
	seeded_profile["campaign_states"][RESTART_CAMPAIGN_ID] = {
		"scenario_records": {
			RESTART_SCENARIO_ID: {
				"status": "victory",
				"summary": "Controller confirmation fixture",
				"day": 4,
				"attempts": 1,
				"hero_level": 2,
				"known_spell_ids": [],
				"artifact_ids": [],
				"specialties": [],
				"exported_flags": {"pass_cleared": true},
			},
		},
		"carryover_bundles": {},
		"last_selected_scenario_id": RESTART_SCENARIO_ID,
		"last_completed_scenario_id": RESTART_SCENARIO_ID,
	}
	seeded_profile["last_campaign_id"] = RESTART_CAMPAIGN_ID
	seeded_profile["last_scenario_id"] = RESTART_SCENARIO_ID
	seeded_profile = CampaignRules.normalize_profile(seeded_profile)
	if SaveService.save_progression(seeded_profile) == "":
		return _fail_bool("Could not persist the campaign restart controller fixture.")
	CampaignProgression.profile = seeded_profile

	var save_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	save_fixture.day = 6
	if SaveService.save_manual_session(save_fixture.to_dict(), DESTRUCTIVE_MANUAL_SLOT) == "":
		return _fail_bool("Could not persist the save-delete controller fixture.")
	SaveService.set_selected_manual_slot(DESTRUCTIVE_MANUAL_SLOT)
	return true

func _destructive_protected_state() -> Dictionary:
	var active_session = SessionState.active_session
	return {
		"active_session": active_session.to_dict() if active_session != null else {},
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
		"progression_file": _file_state(_progression_path()),
		"manual_file": _file_state(_manual_slot_path(DESTRUCTIVE_MANUAL_SLOT)),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_file": _settings_file_state(),
	}

func _restore_destructive_fixture() -> void:
	if not _destructive_fixture_active:
		return
	_restore_file_state(_progression_path(), _destructive_original_progression_file)
	_restore_file_state(_manual_slot_path(DESTRUCTIVE_MANUAL_SLOT), _destructive_original_manual_file)
	CampaignProgression.profile = CampaignRules.normalize_profile(_destructive_original_profile)
	SaveService.set_selected_manual_slot(_destructive_original_selected_slot)
	SaveService.validation_clear_summary_cache()
	_destructive_fixture_active = false

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _restore_file_state(path: String, state: Dictionary) -> void:
	if bool(state.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _progression_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]

func _manual_slot_path(slot: int) -> String:
	return "%s/manual_slot_%d.json" % [SaveService.SAVE_DIR, slot]

func _press_action(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

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
	await get_tree().process_frame

func _settings_file_state() -> Dictionary:
	return {
		"exists": FileAccess.file_exists(SettingsService.SETTINGS_FILE),
		"bytes": FileAccess.get_file_as_bytes(SettingsService.SETTINGS_FILE) if FileAccess.file_exists(SettingsService.SETTINGS_FILE) else PackedByteArray(),
	}

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _focus_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return "none" if focus_owner == null else String(focus_owner.name)

func _dialog_fits_root_viewport(dialog: Window) -> bool:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return true
	var dialog_end := dialog.position + dialog.size
	return dialog.position.x >= 0 and dialog.position.y >= 0 \
		and dialog_end.x <= viewport_size.x and dialog_end.y <= viewport_size.y

func _capture_if_requested(stem: String) -> void:
	if OS.get_environment("MAIN_MENU_KEYBOARD_CAPTURE") != "1":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_fail("Could not save visual capture %s: %s" % [path, error])

func _expect_focus(expected_name: String, context: String) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or focus_owner.name != expected_name:
		_fail("%s expected focus on %s, got %s." % [context, expected_name, "none" if focus_owner == null else focus_owner.name])

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_restore_destructive_fixture()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)

func _fail_bool(message: String) -> bool:
	_fail(message)
	return false
