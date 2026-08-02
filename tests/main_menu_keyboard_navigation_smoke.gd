extends Node

const REPORT_ID := "MAIN_MENU_KEYBOARD_NAVIGATION_SMOKE"
const CAPTURE_DIR := "res://.artifacts/main_menu_keyboard_navigation_smoke"

var _failed := false

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
	await _capture_if_requested("settings_entry_focus")
	if OS.get_environment("MAIN_MENU_KEYBOARD_CAPTURE") == "1":
		var original_ui_scale := SettingsService.ui_scale_percent()
		var original_shake_mode := SettingsService.battle_camera_shake_mode_id()
		if not bool(shell.call("validation_select_ui_scale", 130)) or not bool(shell.call("validation_select_battle_camera_shake", "reduced")):
			_fail("Could not prepare the 130 percent Reduced battle-shake settings capture.")
			return
		await _capture_if_requested("settings_130_reduced_shake")
		shell.call("validation_select_ui_scale", original_ui_scale)
		shell.call("validation_select_battle_camera_shake", original_shake_mode)

	await _press_action("ui_cancel")
	await get_tree().process_frame
	_expect_focus("OpenSettings", "settings board focus return")
	if _failed:
		return
	print("%s PASS" % REPORT_ID)
	shell.queue_free()
	get_tree().quit(0)

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
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
