extends Node

const REPORT_ID := "MAIN_MENU_KEYBOARD_NAVIGATION_SMOKE"
const CAPTURE_DIR := "res://.artifacts/main_menu_keyboard_navigation_smoke"
const RESTART_CAMPAIGN_ID := "campaign_reedfall"
const RESTART_SCENARIO_ID := "river-pass"
const DESTRUCTIVE_MANUAL_SLOT := 2

var _failed := false
var _destructive_fixture_active := false
var _destructive_original_profile := {}
var _destructive_original_settings := {}
var _destructive_original_files := {}
var _destructive_original_summary_cache := {}
var _destructive_original_selected_slot := 1
var _destructive_parent_probe_counts := {}
var _destructive_expected_default_settings := {}
var _destructive_expected_default_settings_file := {}
var _destructive_expected_default_input_map := {}
var _destructive_expected_default_runtime := {}

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
	if not (shell.call("_active_destructive_confirmation_root_owner") as Dictionary).is_empty():
		_fail("Display confirmation incorrectly exposed a destructive root-input owner.")
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
	var keybindings_before := _destructive_protected_state()
	var keybindings_opened: Dictionary = shell.call("validation_open_hero_keybindings_dialog")
	await _settle()
	if not bool(keybindings_opened.get("visible", false)) \
			or not (shell.call("_active_destructive_confirmation_root_owner") as Dictionary).is_empty():
		_fail("Hero keybindings did not remain the sole native input owner.")
		return
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	var keybindings_closed: Dictionary = shell.call("validation_snapshot").get("hero_keybindings_dialog", {})
	if bool(keybindings_closed.get("visible", true)) or _destructive_protected_state() != keybindings_before:
		_fail("Hero keybindings cancel changed destructive authority or remained visible.")
		return
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
	var original_root_focus: Control = get_viewport().gui_get_focus_owner()
	if original_root_focus == null \
		or original_root_focus.name != &"OpenCampaign" \
		or not shell.is_ancestor_of(original_root_focus):
		return _fail_bool("Destructive dialog matrix did not begin from the exact live OpenCampaign focus owner.")
	if not _prepare_destructive_fixture():
		return false
	var original_window_size := get_window().size
	var cases := [
		{"id": "campaign_restart_1280", "workflow": "campaign_restart", "width": 1280, "cancel": "joypad_b", "confirm": "joypad_a"},
		{"id": "campaign_restart_1920", "workflow": "campaign_restart", "width": 1920, "cancel": "escape", "confirm": "mouse"},
		{"id": "save_delete_1280", "workflow": "save_delete", "width": 1280, "cancel": "escape", "confirm": "enter"},
		{"id": "save_delete_1920", "workflow": "save_delete", "width": 1920, "cancel": "joypad_b", "confirm": "mouse"},
		{"id": "settings_restore_1280", "workflow": "settings_restore", "width": 1280, "cancel": "joypad_b", "confirm": "enter"},
		{"id": "settings_restore_1920", "workflow": "settings_restore", "width": 1920, "cancel": "escape", "confirm": "mouse"},
	]
	for case_value in cases:
		if not _seed_destructive_fixture():
			get_window().size = original_window_size
			return false
		if not await _exercise_destructive_exclusive_case(case_value):
			get_window().size = original_window_size
			return false
	if SaveService.validation_summary_cache_snapshot() != _destructive_original_summary_cache:
		get_window().size = original_window_size
		return _fail_bool("Destructive fixture cleanup did not restore the exact pre-fixture summary cache.")
	get_window().size = original_window_size
	if not is_instance_valid(original_root_focus):
		return _fail_bool("Destructive dialog matrix freed its original OpenCampaign focus owner.")
	original_root_focus.grab_focus()
	await _settle()
	if get_viewport().gui_get_focus_owner() != original_root_focus:
		return _fail_bool("Destructive dialog matrix did not restore its exact original OpenCampaign focus owner.")
	return true


func _exercise_destructive_exclusive_case(case_data: Dictionary) -> bool:
	var case_id := String(case_data.get("id", "destructive_exclusive"))
	var workflow := String(case_data.get("workflow", ""))
	var width := int(case_data.get("width", 1280))
	get_window().size = Vector2i(width, 720)
	await _settle()
	var layout_host := Control.new()
	layout_host.name = "ExclusiveMainMenuHost_%s" % case_id
	layout_host.size = Vector2(float(width), 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "ExclusiveMainMenuParentProbe_%s" % case_id
	parent_probe.text = "Main Menu parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(230.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	_destructive_parent_probe_counts[case_id] = 0
	parent_probe.pressed.connect(_on_destructive_parent_probe_pressed.bind(case_id))
	layout_host.add_child(parent_probe)
	await _settle()
	var surface := await _destructive_workflow_surface(shell, workflow)
	var origin := surface.get("origin") as Button
	var dialog := surface.get("dialog") as ConfirmationDialog
	var expected_cancel_text := String(surface.get("cancel_text", ""))
	if origin == null or dialog == null or origin.disabled:
		return _fail_destructive_case(layout_host, "%s has no actionable origin/dialog." % case_id)
	var fixture_checks := {
		"host_parent_exact": shell.get_parent() == layout_host,
		"host_width_exact": int(layout_host.size.x) == width,
		"host_height_exact": int(layout_host.size.y) == 720,
		"origin_root_viewport_exact": origin.get_viewport() == get_viewport(),
		"probe_root_viewport_exact": parent_probe.get_viewport() == get_viewport(),
	}
	if not _checks_exact(fixture_checks):
		return _fail_destructive_case(layout_host, "%s exact host failed: %s." % [case_id, JSON.stringify(fixture_checks)])
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var opened := _destructive_transaction_snapshot(shell, workflow)
	var geometry := _destructive_parent_click_geometry(parent_probe, dialog)
	var opened_checks := {
		"exclusive_exact": dialog.exclusive,
		"pending_exact": _destructive_pending_matches(shell, workflow, true),
		"request_once": int(opened.get("request_count", -1)) == 1,
		"cancel_zero": int(opened.get("cancel_count", -1)) == 0,
		"confirm_zero": int(opened.get("confirm_count", -1)) == 0,
		"safe_cancel_text_exact": dialog.get_cancel_button().text == expected_cancel_text,
		"safe_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"geometry_exact": bool(geometry.get("exact", false)),
	}
	if not _checks_exact(opened_checks):
		return _fail_destructive_case(layout_host, "%s did not open exact exclusive confirmation: checks=%s geometry=%s opened=%s." % [case_id, JSON.stringify(opened_checks), JSON.stringify(geometry), JSON.stringify(opened)])
	var authority_before_block := _destructive_authority_snapshot(shell)
	var transaction_before_block := _destructive_transaction_snapshot(shell, workflow)
	var parent_before := int(_destructive_parent_probe_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle()
	var first_block_checks := {
		"parent_probe_blocked": int(_destructive_parent_probe_counts.get(case_id, -1)) == parent_before,
		"dialog_transaction_exact": _destructive_transaction_snapshot(shell, workflow) == transaction_before_block,
		"full_authority_exact": _destructive_authority_snapshot(shell) == authority_before_block,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(first_block_checks):
		return _fail_destructive_case(layout_host, "%s first parent click escaped modal: %s." % [case_id, JSON.stringify(first_block_checks)])
	if not await _send_destructive_cancel(String(case_data.get("cancel", "")), dialog):
		return _fail_destructive_case(layout_host, "%s has unsupported cancel input." % case_id)
	await _settle()
	var canceled := _destructive_transaction_snapshot(shell, workflow)
	var canceled_checks := {
		"hidden_exact": not dialog.visible,
		"pending_cleared_exact": _destructive_pending_matches(shell, workflow, false),
		"request_once": int(canceled.get("request_count", -1)) == 1,
		"cancel_once": int(canceled.get("cancel_count", -1)) == 1,
		"confirm_zero": int(canceled.get("confirm_count", -1)) == 0,
		"background_authority_exact": _destructive_authority_snapshot(shell) == authority_before_block,
		"origin_focus_exact": get_viewport().gui_get_focus_owner() == origin,
	}
	if not _checks_exact(canceled_checks):
		return _fail_destructive_case(layout_host, "%s physical cancel was not exact: checks=%s canceled=%s." % [case_id, JSON.stringify(canceled_checks), JSON.stringify(canceled)])
	var positive_before := int(_destructive_parent_probe_counts.get(case_id, 0))
	var positive_authority := _destructive_authority_snapshot(shell)
	await _click_control(parent_probe)
	await _settle()
	var positive_checks := {
		"identical_parent_positive_once": int(_destructive_parent_probe_counts.get(case_id, -1)) == positive_before + 1,
		"background_authority_exact": _destructive_authority_snapshot(shell) == positive_authority,
		"dialog_transaction_exact": _destructive_transaction_snapshot(shell, workflow) == canceled,
	}
	if not _checks_exact(positive_checks):
		return _fail_destructive_case(layout_host, "%s parent probe was not actionable after cancel: %s." % [case_id, JSON.stringify(positive_checks)])

	# Directly enqueue one exact physical press, synchronously replace the request,
	# then deliver the release normally. Generation and pending identity must prevent
	# either stale event from reaching the replacement dialog.
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var stale_owner: Dictionary = shell.call("_active_destructive_confirmation_root_owner")
	var stale_pressed := InputEventKey.new()
	stale_pressed.keycode = KEY_ESCAPE
	stale_pressed.physical_keycode = KEY_ESCAPE
	stale_pressed.pressed = true
	shell.call("_on_root_window_input", stale_pressed)
	_destructive_cancel_validation(shell, workflow)
	_destructive_request_validation(shell, workflow)
	await _settle()
	var replacement_before := _destructive_transaction_snapshot(shell, workflow)
	var replacement_focus_exact := dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button()
	var stale_released := InputEventKey.new()
	stale_released.keycode = KEY_ESCAPE
	stale_released.physical_keycode = KEY_ESCAPE
	stale_released.pressed = false
	Input.parse_input_event(stale_released)
	await _settle()
	var replacement_after := _destructive_transaction_snapshot(shell, workflow)
	var replacement_owner: Dictionary = shell.call("_active_destructive_confirmation_root_owner")
	var stale_checks := {
		"original_owner_exact": String(stale_owner.get("workflow", "")) == workflow,
		"replacement_owner_exact": String(replacement_owner.get("workflow", "")) == workflow,
		"generation_changed": int(replacement_owner.get("generation", -1)) > int(stale_owner.get("generation", -1)),
		"replacement_safe_focus_exact": replacement_focus_exact,
		"transaction_exact": replacement_after == replacement_before,
		"dialog_still_visible": dialog.visible,
		"pending_exact": _destructive_pending_matches(shell, workflow, true),
		"request_three": int(replacement_after.get("request_count", -1)) == 3,
		"cancel_two": int(replacement_after.get("cancel_count", -1)) == 2,
		"confirm_zero": int(replacement_after.get("confirm_count", -1)) == 0,
	}
	if not _checks_exact(stale_checks):
		return _fail_destructive_case(layout_host, "%s stale generation/release reached replacement: checks=%s owner=%s replacement=%s." % [case_id, JSON.stringify(stale_checks), JSON.stringify(replacement_owner), JSON.stringify(replacement_after)])
	var authority_before_second_block := _destructive_authority_snapshot(shell)
	var parent_before_second := int(_destructive_parent_probe_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle()
	var second_block_checks := {
		"parent_probe_blocked": int(_destructive_parent_probe_counts.get(case_id, -1)) == parent_before_second,
		"dialog_transaction_exact": _destructive_transaction_snapshot(shell, workflow) == replacement_after,
		"full_authority_exact": _destructive_authority_snapshot(shell) == authority_before_second_block,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(second_block_checks):
		return _fail_destructive_case(layout_host, "%s second parent click escaped modal: %s." % [case_id, JSON.stringify(second_block_checks)])
	var consequence_before := _destructive_consequence_state(shell, workflow)
	var expected_consequence := _destructive_expected_consequence(workflow, consequence_before)
	if not await _send_destructive_confirm(String(case_data.get("confirm", "")), dialog):
		return _fail_destructive_case(layout_host, "%s has unsupported confirm input." % case_id)
	await _settle()
	if SettingsService.display_change_pending():
		shell.call("validation_revert_display_change", "destructive_exclusive_fixture")
		await _settle()
	var confirmed := _destructive_transaction_snapshot(shell, workflow)
	var consequence_after := _destructive_consequence_state(shell, workflow)
	var consequence_checks := _destructive_consequence_checks(workflow, consequence_after, expected_consequence)
	var unrelated_before := _destructive_unrelated_consequence_authority(workflow, consequence_before)
	var unrelated_after := _destructive_unrelated_consequence_authority(workflow, consequence_after)
	var unrelated_checks := _top_level_equality_checks(unrelated_before, unrelated_after)
	var confirmed_checks := {
		"hidden_exact": not dialog.visible,
		"pending_cleared_exact": _destructive_pending_matches(shell, workflow, false),
		"request_three": int(confirmed.get("request_count", -1)) == 3,
		"cancel_two": int(confirmed.get("cancel_count", -1)) == 2,
		"confirm_once": int(confirmed.get("confirm_count", -1)) == 1,
		"workflow_consequence_exact": _checks_exact(consequence_checks),
		"unrelated_authority_exact": unrelated_before == unrelated_after and _checks_exact(unrelated_checks),
	}
	if not _checks_exact(confirmed_checks):
		return _fail_destructive_case(layout_host, "%s forwarded/native confirm was not exact: checks=%s consequence=%s unrelated=%s differences=%s confirmed=%s." % [case_id, JSON.stringify(confirmed_checks), JSON.stringify(consequence_checks), JSON.stringify(unrelated_checks), JSON.stringify(_top_level_differences(unrelated_before, unrelated_after)), JSON.stringify(confirmed)])
	_cleanup_destructive_case(layout_host)
	await _settle()
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


func _destructive_workflow_surface(shell: Node, workflow: String) -> Dictionary:
	match workflow:
		"campaign_restart":
			shell.call("validation_open_campaign_stage")
			if not bool(shell.call("validation_select_campaign", RESTART_CAMPAIGN_ID)):
				return {}
			await _settle()
			return {
				"origin": shell.get_node_or_null("%RestartCampaignArc"),
				"dialog": shell.get_node_or_null("CampaignRestartDialog"),
				"cancel_text": "Keep Progress",
			}
		"save_delete":
			if not bool(shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, str(DESTRUCTIVE_MANUAL_SLOT))):
				return {}
			await _settle()
			return {
				"origin": shell.get_node_or_null("%DeleteSelectedSave"),
				"dialog": shell.get_node_or_null("SaveDeleteDialog"),
				"cancel_text": "Keep Save",
			}
		"settings_restore":
			shell.call("validation_open_settings_stage")
			await _settle()
			return {
				"origin": shell.get_node_or_null("%RestoreSettingsDefaults"),
				"dialog": shell.get_node_or_null("SettingsRestoreDefaultsDialog"),
				"cancel_text": "Keep Settings",
			}
	return {}


func _destructive_request_validation(shell: Node, workflow: String) -> void:
	match workflow:
		"campaign_restart":
			shell.call("validation_request_campaign_restart")
		"save_delete":
			shell.call("validation_request_selected_save_delete")
		"settings_restore":
			shell.call("validation_request_settings_restore_defaults")


func _destructive_cancel_validation(shell: Node, workflow: String) -> void:
	match workflow:
		"campaign_restart":
			shell.call("validation_cancel_campaign_restart")
		"save_delete":
			shell.call("validation_cancel_selected_save_delete")
		"settings_restore":
			shell.call("validation_cancel_settings_restore_defaults")


func _destructive_transaction_snapshot(shell: Node, workflow: String) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var confirmation_value: Variant = snapshot.get("%s_confirmation" % workflow, {})
	var confirmation: Dictionary = confirmation_value if confirmation_value is Dictionary else {}
	return {
		"pending": bool(confirmation.get("pending", false)),
		"visible": bool(confirmation.get("dialog_visible", false)),
		"request_count": int(confirmation.get("request_count", 0)),
		"cancel_count": int(confirmation.get("cancel_count", 0)),
		"confirm_count": int(confirmation.get("confirm_count", 0)),
		"cancel_text": String(confirmation.get("cancel_text", "")),
		"return_focus_name": String(confirmation.get("return_focus_name", "")),
	}


func _destructive_authority_snapshot(shell: Node) -> Dictionary:
	var active_session = SessionState.active_session
	var snapshot: Dictionary = shell.call("validation_snapshot")
	return {
		"active_session": active_session.to_dict() if active_session != null else {},
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
		"files": _destructive_file_states(),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"selected_manual_slot": SaveService.get_selected_manual_slot(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_transaction": _settings_transaction_authority(),
		"stage": {
			"visible": bool(snapshot.get("stage_dock_visible", false)),
			"tab": int(snapshot.get("current_tab", -1)),
			"campaign_id": String(snapshot.get("selected_campaign_id", "")),
			"scenario_id": String(snapshot.get("selected_campaign_scenario_id", "")),
			"save_key": String(snapshot.get("selected_save_key", "")),
		},
		"active_play_route": AppRouter.validation_active_play_return_snapshot(),
		"battle_route": AppRouter.validation_battle_entry_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}


func _destructive_consequence_state(shell: Node, workflow: String) -> Dictionary:
	var cache_before_inspection := SaveService.validation_summary_cache_snapshot()
	var selected_manual_summary := SaveService.inspect_manual_slot(DESTRUCTIVE_MANUAL_SLOT)
	SaveService._slot_summary_cache = cache_before_inspection.duplicate(true)
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"workflow": workflow,
		"authority": _destructive_authority_snapshot(shell),
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
		"progression_file": _file_state(_progression_path()),
		"manual_file": _file_state(_manual_slot_path(DESTRUCTIVE_MANUAL_SLOT)),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_file": _file_state(SettingsService.SETTINGS_FILE),
		"settings_transaction": {
			"settings": (transaction.get("settings", {}) as Dictionary).duplicate(true),
			"committed_settings": (transaction.get("committed_settings", {}) as Dictionary).duplicate(true),
			"last_result": (transaction.get("last_result", {}) as Dictionary).duplicate(true),
			"input_map": _canonical_input_map(transaction.get("input_map", {})),
			"runtime": _stable_runtime_display(transaction.get("runtime_display", {})),
		},
		"selected_manual_slot": SaveService.get_selected_manual_slot(),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"selected_manual_summary": selected_manual_summary.duplicate(true),
		"progression_artifacts": _transaction_artifact_states(_progression_path()),
		"manual_artifacts": _transaction_artifact_states(_manual_slot_path(DESTRUCTIVE_MANUAL_SLOT)),
		"settings_artifacts": {
			SettingsService.SETTINGS_CANDIDATE_FILE: _file_state(SettingsService.SETTINGS_CANDIDATE_FILE),
			SettingsService.SETTINGS_BACKUP_FILE: _file_state(SettingsService.SETTINGS_BACKUP_FILE),
		},
	}


func _destructive_expected_consequence(workflow: String, before: Dictionary) -> Dictionary:
	match workflow:
		"campaign_restart":
			var before_profile: Dictionary = before.get("campaign_profile", {})
			return {
				"profile": CampaignRules.reset_campaign(before_profile, RESTART_CAMPAIGN_ID),
				"artifacts": (before.get("progression_artifacts", {}) as Dictionary).duplicate(true),
			}
		"save_delete":
			return {
				"selected_manual_slot": int(before.get("selected_manual_slot", -1)),
				"cache_without_slot": _summary_cache_without_path(before.get("summary_cache", {}), _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT)),
				"artifacts": (before.get("manual_artifacts", {}) as Dictionary).duplicate(true),
			}
		"settings_restore":
			return {
				"settings": _destructive_expected_default_settings.duplicate(true),
				"settings_file": _destructive_expected_default_settings_file.duplicate(true),
				"input_map": _destructive_expected_default_input_map.duplicate(true),
				"runtime": _destructive_expected_default_runtime.duplicate(true),
				"artifacts": (before.get("settings_artifacts", {}) as Dictionary).duplicate(true),
			}
	return {}


func _destructive_consequence_checks(workflow: String, after: Dictionary, expected: Dictionary) -> Dictionary:
	match workflow:
		"campaign_restart":
			var expected_profile: Dictionary = expected.get("profile", {})
			return {
				"campaign_live_profile_exact": after.get("campaign_profile") == expected_profile,
				"campaign_persisted_profile_exact": CampaignRules.normalize_profile(SaveService.load_progression()) == expected_profile,
				"campaign_artifacts_exact": after.get("progression_artifacts") == expected.get("artifacts"),
			}
		"save_delete":
			var summary_value: Variant = after.get("selected_manual_summary", {})
			var summary: Dictionary = summary_value if summary_value is Dictionary else {}
			var slot_cache_entries := _summary_cache_entries_for_path(after.get("summary_cache", {}), _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT))
			var slot_cache_wrapper: Dictionary = slot_cache_entries[0] if slot_cache_entries.size() == 1 else {}
			return {
				"save_slot_absent": not bool((after.get("manual_file", {}) as Dictionary).get("exists", true)),
				"save_selection_exact": int(after.get("selected_manual_slot", -1)) == int(expected.get("selected_manual_slot", -2)),
				"save_summary_identity_exact": String(summary.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL and String(summary.get("slot_id", "")) == str(DESTRUCTIVE_MANUAL_SLOT) and String(summary.get("path", "")) == _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT),
				"save_summary_missing_exact": String(summary.get("validity", "")) == "missing" and not bool(summary.get("valid", true)) and not bool(summary.get("loadable", true)),
				"save_cache_slot_wrapper_exact": slot_cache_entries.size() == 1 and String(slot_cache_wrapper.get("file_path", "")) == _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT) and not bool(slot_cache_wrapper.get("exists", true)) and slot_cache_wrapper.get("summary") == summary,
				"save_other_cache_exact": _summary_cache_without_path(after.get("summary_cache", {}), _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT)) == expected.get("cache_without_slot", {}),
				"save_artifacts_exact": after.get("manual_artifacts") == expected.get("artifacts"),
			}
		"settings_restore":
			var transaction_value: Variant = after.get("settings_transaction", {})
			var transaction: Dictionary = transaction_value if transaction_value is Dictionary else {}
			var last_result_value: Variant = transaction.get("last_result", {})
			var last_result: Dictionary = last_result_value if last_result_value is Dictionary else {}
			return {
				"settings_live_exact": after.get("settings") == expected.get("settings"),
				"settings_file_exact": after.get("settings_file") == expected.get("settings_file"),
				"settings_transaction_live_exact": transaction.get("settings") == expected.get("settings"),
				"settings_transaction_committed_exact": transaction.get("committed_settings") == expected.get("settings"),
				"settings_input_map_exact": transaction.get("input_map") == expected.get("input_map"),
				"settings_runtime_exact": transaction.get("runtime") == expected.get("runtime"),
				"settings_commit_exact": bool(last_result.get("ok", false)) and String(last_result.get("path", "")) == SettingsService.SETTINGS_FILE and bool(last_result.get("changed", false)),
				"settings_artifacts_exact": after.get("settings_artifacts") == expected.get("artifacts"),
			}
	return {"known_workflow": false}


func _top_level_equality_checks(before: Dictionary, after: Dictionary) -> Dictionary:
	var checks := {}
	var keys := before.keys()
	for key in after.keys():
		if key not in keys:
			keys.append(key)
	keys.sort()
	for key in keys:
		checks[String(key)] = before.get(key) == after.get(key)
	return checks


func _top_level_differences(before: Dictionary, after: Dictionary) -> Dictionary:
	var differences := {}
	for key in _top_level_equality_checks(before, after):
		if before.get(key) != after.get(key):
			differences[String(key)] = {"before": before.get(key), "after": after.get(key)}
	return differences


func _summary_cache_without_path(cache_value: Variant, path: String) -> Dictionary:
	var cache: Dictionary = (cache_value as Dictionary).duplicate(true) if cache_value is Dictionary else {}
	for key in cache.keys().duplicate():
		var entry_value: Variant = cache.get(key, {})
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		if String(entry.get("file_path", "")) == path:
			cache.erase(key)
	return cache


func _summary_cache_entries_for_path(cache_value: Variant, path: String) -> Array:
	var cache: Dictionary = cache_value if cache_value is Dictionary else {}
	var matches := []
	for entry_value in cache.values():
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		if String(entry.get("file_path", "")) == path:
			matches.append(entry.duplicate(true))
	return matches


func _transaction_artifact_states(base_path: String) -> Dictionary:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(base_path)
	var candidate := String(artifacts.get("candidate", ""))
	var backup := String(artifacts.get("backup", ""))
	return {
		candidate: _file_state(candidate),
		backup: _file_state(backup),
	}


func _stable_runtime_display(value: Variant) -> Dictionary:
	var runtime: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	runtime.erase("size")
	runtime.erase("position")
	return runtime


func _settings_transaction_authority() -> Dictionary:
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	transaction["input_map"] = _canonical_input_map(transaction.get("input_map", {}))
	transaction["runtime_display"] = _stable_runtime_display(transaction.get("runtime_display", {}))
	return transaction


func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var action_id := String(action_value)
		var row_value: Variant = input_map.get(action_value, {})
		var row: Dictionary = row_value if row_value is Dictionary else {}
		var events := []
		var events_value: Variant = row.get("events", [])
		if events_value is Array:
			for event_value in events_value:
				if event_value is InputEvent:
					events.append(_serialize_input_event(event_value))
		result[action_id] = {
			"exists": bool(row.get("exists", false)),
			"deadzone": float(row.get("deadzone", 0.5)),
			"events": events,
		}
	return result


func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name := String(property.get("name", ""))
		if name == "" or name == "script":
			continue
		properties[name] = var_to_str(input_event.get(name))
	return {
		"class": input_event.get_class(),
		"text": input_event.as_text(),
		"properties": properties,
	}


func _destructive_unrelated_consequence_authority(workflow: String, state: Dictionary) -> Dictionary:
	var authority: Dictionary = (state.get("authority", {}) as Dictionary).duplicate(true)
	var files_value: Variant = authority.get("files", {})
	var files: Dictionary = files_value if files_value is Dictionary else {}
	match workflow:
		"campaign_restart":
			authority.erase("campaign_profile")
			authority.erase("stage")
			_erase_transaction_file_family(files, _progression_path())
		"save_delete":
			authority.erase("summary_cache")
			authority.erase("stage")
			_erase_transaction_file_family(files, _manual_slot_path(DESTRUCTIVE_MANUAL_SLOT))
		"settings_restore":
			authority.erase("settings")
			authority.erase("settings_transaction")
			for path in [SettingsService.SETTINGS_FILE, SettingsService.SETTINGS_CANDIDATE_FILE, SettingsService.SETTINGS_BACKUP_FILE]:
				files.erase(path)
	authority["files"] = files
	return authority


func _erase_transaction_file_family(files: Dictionary, base_path: String) -> void:
	files.erase(base_path)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(base_path)
	files.erase(String(artifacts.get("candidate", "")))
	files.erase(String(artifacts.get("backup", "")))


func _send_destructive_cancel(input_id: String, dialog: ConfirmationDialog) -> bool:
	match input_id:
		"joypad_b":
			await _press_joypad_button(JOY_BUTTON_B)
		"escape":
			await _press_key(KEY_ESCAPE)
		_:
			return false
	return true


func _send_destructive_confirm(input_id: String, dialog: ConfirmationDialog) -> bool:
	var ok_button := dialog.get_ok_button()
	match input_id:
		"joypad_a":
			ok_button.grab_focus()
			await get_tree().process_frame
			await _press_joypad_button(JOY_BUTTON_A)
		"enter":
			ok_button.grab_focus()
			await get_tree().process_frame
			await _press_key(KEY_ENTER)
		"mouse":
			if not bool(_destructive_dialog_child_geometry(ok_button, dialog).get("exact", false)):
				return false
			await _click_control(ok_button)
		_:
			return false
	return true


func _destructive_parent_click_geometry(control: Button, dialog: ConfirmationDialog) -> Dictionary:
	var parent_click := _control_root_click_position(control)
	var parent_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var cancel_button := dialog.get_cancel_button()
	var child_click := _control_root_click_position(cancel_button)
	var child_rect := _control_root_rect(cancel_button)
	return {
		"exact": dialog.exclusive \
			and control.get_viewport() == get_viewport() \
			and control.is_visible_in_tree() \
			and not control.disabled \
			and parent_rect.has_point(parent_click) \
			and get_viewport().get_visible_rect().has_point(parent_click) \
			and not dialog_rect.has_point(parent_click) \
			and cancel_button.get_viewport() == dialog \
			and dialog_rect.has_point(child_click) \
			and child_rect.has_point(child_click),
		"parent_click": parent_click,
		"parent_rect": parent_rect,
		"dialog_rect": dialog_rect,
		"child_click": child_click,
		"child_rect": child_rect,
	}


func _destructive_dialog_child_geometry(control: Control, dialog: ConfirmationDialog) -> Dictionary:
	var click_position := _control_root_click_position(control)
	var control_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	return {
		"exact": control.get_viewport() == dialog \
			and control.get_viewport() != get_viewport() \
			and control.is_visible_in_tree() \
			and control_rect.has_point(click_position) \
			and dialog_rect.has_point(click_position),
		"click": click_position,
		"control_rect": control_rect,
		"dialog_rect": dialog_rect,
	}


func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _on_destructive_parent_probe_pressed(case_id: String) -> void:
	_destructive_parent_probe_counts[case_id] = int(_destructive_parent_probe_counts.get(case_id, 0)) + 1


func _cleanup_destructive_case(layout_host: Node) -> void:
	_restore_original_destructive_state()
	if is_instance_valid(layout_host):
		layout_host.queue_free()


func _fail_destructive_case(layout_host: Node, message: String) -> bool:
	_cleanup_destructive_case(layout_host)
	return _fail_bool(message)


func _prepare_destructive_fixture() -> bool:
	if _destructive_fixture_active:
		return true
	_destructive_original_profile = CampaignProgression.ensure_profile().duplicate(true)
	_destructive_original_settings = SettingsService.ensure_settings().duplicate(true)
	_destructive_original_files = _destructive_file_states()
	_destructive_original_summary_cache = SaveService.validation_summary_cache_snapshot()
	_destructive_original_selected_slot = SaveService.get_selected_manual_slot()
	_destructive_fixture_active = true
	return _seed_destructive_fixture()


func _seed_destructive_fixture() -> bool:
	_restore_original_destructive_state()

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
	var seeded_settings: Dictionary = _destructive_original_settings.duplicate(true)
	var accessibility_value: Variant = seeded_settings.get("accessibility", {})
	var accessibility: Dictionary = accessibility_value if accessibility_value is Dictionary else {}
	accessibility["reduce_motion"] = not bool(SettingsService.build_default_settings().get("accessibility", {}).get("reduce_motion", false))
	seeded_settings["accessibility"] = accessibility
	SettingsService.settings = seeded_settings
	if SettingsService.save_settings() == "":
		return _fail_bool("Could not persist the settings-restore exclusive fixture.")
	SettingsService.apply_settings()
	if not _prepare_expected_default_settings_fixture(seeded_settings):
		return false
	SaveService.validation_clear_summary_cache()
	return true


func _prepare_expected_default_settings_fixture(seeded_settings: Dictionary) -> bool:
	var expected := SettingsService.build_default_settings()
	var expected_presentation: Dictionary = expected.get("presentation", {})
	var seeded_presentation: Dictionary = seeded_settings.get("presentation", {})
	expected_presentation["mode"] = String(seeded_presentation.get("mode", SettingsService.PRESENTATION_WINDOWED))
	expected_presentation["resolution"] = String(seeded_presentation.get("resolution", SettingsService.PRESENTATION_RESOLUTION_DEFAULT))
	expected["presentation"] = expected_presentation
	SettingsService.settings = expected.duplicate(true)
	if SettingsService.save_settings() == "":
		return _fail_bool("Could not derive exact persisted default-settings fixture.")
	SettingsService.apply_settings()
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	_destructive_expected_default_settings = expected.duplicate(true)
	_destructive_expected_default_settings_file = _file_state(SettingsService.SETTINGS_FILE)
	_destructive_expected_default_input_map = _canonical_input_map(transaction.get("input_map", {}))
	_destructive_expected_default_runtime = _stable_runtime_display(transaction.get("runtime_display", {}))
	SettingsService.settings = seeded_settings.duplicate(true)
	if SettingsService.save_settings() == "":
		return _fail_bool("Could not restore the seeded settings fixture after deriving defaults.")
	SettingsService.apply_settings()
	return true

func _destructive_protected_state() -> Dictionary:
	var active_session = SessionState.active_session
	return {
		"active_session": active_session.to_dict() if active_session != null else {},
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
		"files": _destructive_file_states(),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"selected_manual_slot": SaveService.get_selected_manual_slot(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_transaction": _settings_transaction_authority(),
		"active_play_route": AppRouter.validation_active_play_return_snapshot(),
		"battle_route": AppRouter.validation_battle_entry_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}

func _restore_destructive_fixture() -> void:
	if not _destructive_fixture_active:
		return
	_restore_original_destructive_state()
	_destructive_fixture_active = false


func _restore_original_destructive_state() -> void:
	if not _destructive_fixture_active:
		return
	if SettingsService.display_change_pending():
		SettingsService.revert_display_change("main_menu_destructive_fixture_cleanup")
	SettingsService.settings = _destructive_original_settings.duplicate(true)
	SettingsService.save_settings()
	SettingsService.apply_settings()
	for path in _destructive_original_files:
		_restore_file_state(String(path), _destructive_original_files[path])
	CampaignProgression.profile = CampaignRules.normalize_profile(_destructive_original_profile)
	SaveService.set_selected_manual_slot(_destructive_original_selected_slot)
	SaveService._slot_summary_cache = _destructive_original_summary_cache.duplicate(true)


func _destructive_authority_paths() -> Array:
	var paths := [
		_progression_path(),
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		SettingsService.SETTINGS_FILE,
		SettingsService.SETTINGS_CANDIDATE_FILE,
		SettingsService.SETTINGS_BACKUP_FILE,
	]
	for slot in SaveService.MANUAL_SLOT_IDS:
		paths.append(_manual_slot_path(int(slot)))
	var base_paths := paths.duplicate()
	for base_path_value in base_paths:
		var base_path := String(base_path_value)
		if not base_path.begins_with(SaveService.SAVE_DIR):
			continue
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(base_path)
		paths.append(String(artifacts.get("candidate", "")))
		paths.append(String(artifacts.get("backup", "")))
	return paths


func _destructive_file_states() -> Dictionary:
	var states := {}
	for path_value in _destructive_authority_paths():
		var path := String(path_value)
		states[path] = _file_state(path)
	return states

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
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]


func _click_control(control: Control) -> void:
	var source_viewport := control.get_viewport()
	var viewport := get_viewport()
	var center := _control_root_click_position(control)
	var window_id: int = int(source_viewport.get_window_id()) if source_viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = center
	motion.global_position = center
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var pressed := InputEventMouseButton.new()
	pressed.window_id = window_id
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = center
	pressed.global_position = center
	pressed.pressed = true
	viewport.push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.window_id = window_id
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = center
	released.global_position = center
	released.pressed = false
	viewport.push_input(released, true)
	await _settle()


func _control_root_click_position(control: Control) -> Vector2:
	var click_position := control.get_global_rect().get_center()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		click_position += Vector2((source_viewport as Window).position)
	return click_position


func _control_root_rect(control: Control) -> Rect2:
	var control_rect := control.get_global_rect()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		control_rect.position += Vector2((source_viewport as Window).position)
	return control_rect

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
