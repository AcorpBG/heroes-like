extends Node

const REPORT_ID := "MAIN_MENU_CREDITS_NOTICES_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const NOTICE_PATH := "res://content/third_party_notices.json"
const VENDORED_LICENSE_PATH := "res://third_party/godot-cpp/LICENSE.md"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _validate_notice_authority():
		return
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport_case(viewport_size)
		if row.is_empty():
			return
		rows.append(row)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewport_rows": rows,
		"engine_version": String(Engine.get_version_info().get("string", "")),
		"notice_schema": "aurelion_third_party_notices",
		"godot_cpp_license_exact": true,
		"engine_notices_runtime_sourced": true,
	})])
	get_tree().quit(0)

func _validate_notice_authority() -> bool:
	var authored: Dictionary = ContentService.load_json(NOTICE_PATH)
	var items: Array = authored.get("items", []) if authored.get("items", []) is Array else []
	if String(authored.get("schema_id", "")) != "aurelion_third_party_notices" \
			or int(authored.get("schema_version", 0)) != 1 \
			or items.size() != 1:
		_fail("Exported notice resource has invalid schema or item count: %s" % JSON.stringify(authored))
		return false
	var godot_cpp: Dictionary = items[0] if items[0] is Dictionary else {}
	var vendored_text := FileAccess.get_file_as_string(VENDORED_LICENSE_PATH)
	var expected_license := vendored_text.trim_prefix("# MIT License\n\n").strip_edges()
	if String(godot_cpp.get("id", "")) != "godot_cpp" \
			or String(godot_cpp.get("version", "")) != "10.0.0-rc1" \
			or String(godot_cpp.get("license_id", "")) != "MIT" \
			or String(godot_cpp.get("license_text", "")).strip_edges() != expected_license:
		_fail("Exported godot-cpp notice does not exactly match the vendored MIT notice.")
		return false
	var payload: Dictionary = SettingsService.credits_notices_payload()
	var notice_text := SettingsService.credits_notices_text()
	var engine_license := Engine.get_license_text()
	if String(payload.get("schema_id", "")) != "aurelion_third_party_notices" \
			or String(payload.get("engine_license_text", "")) != engine_license \
			or engine_license == "" \
			or not notice_text.contains(engine_license) \
			or not notice_text.contains(expected_license) \
			or not notice_text.contains("Aurelion Reach contributors") \
			or not notice_text.contains("does not state or change a license for Aurelion Reach"):
		_fail("Runtime notice text omitted product scope, Godot, or godot-cpp authority.")
		return false
	var license_info: Dictionary = Engine.get_license_info()
	for license_text_value in license_info.values():
		if not notice_text.contains(String(license_text_value)):
			_fail("Runtime notice text omitted an Engine component license text.")
			return false
	var copyright_info: Array = Engine.get_copyright_info()
	for component_value in copyright_info:
		if component_value is Dictionary and not notice_text.contains(String(component_value.get("name", ""))):
			_fail("Runtime notice text omitted Engine component %s." % String(component_value.get("name", "")))
			return false
	return true

func _run_viewport_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await _frames(3)
	if get_window().size != viewport_size:
		_fail("Could not establish requested viewport %s, got %s." % [viewport_size, get_window().size])
		return {}
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _frames(4)
	var dialog: Window = shell.get_node("CreditsNoticesDialog")
	var body: TextEdit = shell.get_node("CreditsNoticesDialog/CreditsNoticesPanel/CreditsNoticesPad/CreditsNoticesBox/CreditsNoticesBody")
	var close_button: Button = shell.get_node("CreditsNoticesDialog/CreditsNoticesPanel/CreditsNoticesPad/CreditsNoticesBox/CreditsNoticesClose")
	var panel: PanelContainer = shell.get_node("CreditsNoticesDialog/CreditsNoticesPanel")
	var startup_snapshot: Dictionary = shell.call("validation_snapshot")
	if dialog.visible \
			or bool(startup_snapshot.get("credits_notices_dialog_visible", true)) \
			or dialog.has_focus() \
			or body.has_focus() \
			or close_button.has_focus():
		_fail("Credits modal entered the native focus lifecycle before user open at %s: %s" % [viewport_size, JSON.stringify(startup_snapshot)])
		return {}
	shell.call("validation_open_contextual_guide_stage")
	await _frames(2)
	shell.call("validation_select_help_topic", "credits_notices")
	await _frames(2)
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var command: Button = shell.get_node("StageDockPanel/StageDockPad/StageDockBox/MenuTabs/Guide/GuidePanel/GuidePad/GuideBox/OpenCreditsNotices")
	if not bool(before_snapshot.get("stage_dock_visible", false)) \
			or int(before_snapshot.get("current_tab", -1)) != 3 \
			or String(before_snapshot.get("help_topic_id", "")) != "credits_notices" \
			or "Credits & Notices" not in before_snapshot.get("help_items", []) \
			or not bool(before_snapshot.get("credits_notices_command_visible", false)) \
			or bool(before_snapshot.get("credits_notices_command_disabled", true)) \
			or not command.is_visible_in_tree():
		_fail("Guide did not expose the secondary Credits & Notices command at %s: %s" % [viewport_size, JSON.stringify(before_snapshot)])
		return {}
	var authority_before := _authority_snapshot()
	command.grab_focus()
	await get_tree().process_frame
	if viewport_size.x == 1280:
		await _press_key(KEY_ENTER)
	else:
		await _press_joypad(JOY_BUTTON_A)
	await _frames(3)
	var open_snapshot: Dictionary = shell.call("validation_snapshot")
	if not dialog.visible \
			or not bool(open_snapshot.get("credits_notices_dialog_visible", false)) \
			or body.editable \
			or body.context_menu_enabled \
			or body.text != SettingsService.credits_notices_text() \
			or String(open_snapshot.get("credits_notices_body_accessibility_name", "")) != "Credits and third-party notices" \
			or not String(open_snapshot.get("credits_notices_body_accessibility_description", "")).contains("Scrollable credits") \
			or dialog.size.x > viewport_size.x \
			or dialog.size.y > viewport_size.y \
			or panel.size != Vector2(dialog.size) \
			or not close_button.has_focus():
		_fail("Credits modal content, containment, read-only state, semantics, or initial focus failed at %s: %s" % [viewport_size, JSON.stringify(open_snapshot)])
		return {}
	if viewport_size.x == 1280:
		await _press_key(KEY_TAB)
	else:
		await _press_joypad(JOY_BUTTON_DPAD_UP)
	if not body.has_focus():
		_fail("Credits notice keyboard/controller focus cycle did not move from Close to the scrollable body at %s." % viewport_size)
		return {}
	if viewport_size.x == 1280:
		await _press_key(KEY_PAGEDOWN)
	else:
		await _press_joypad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	var scroll_after := body.scroll_vertical
	if body.get_v_scroll_bar().max_value <= body.get_v_scroll_bar().page or scroll_after <= 0:
		_fail("Credits notice body was not scrollable through keyboard/controller page input at %s: max=%s page=%s scroll=%s" % [viewport_size, body.get_v_scroll_bar().max_value, body.get_v_scroll_bar().page, scroll_after])
		return {}
	if viewport_size.x == 1280:
		await _press_key(KEY_PAGEUP)
	else:
		await _press_joypad(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	if body.scroll_vertical >= scroll_after:
		_fail("Credits notice keyboard/controller page-up did not reverse page-down at %s: before=%s after=%s" % [viewport_size, scroll_after, body.scroll_vertical])
		return {}
	if viewport_size.x == 1280:
		await _press_key(KEY_ESCAPE)
	else:
		await _press_joypad(JOY_BUTTON_B)
	await _frames(3)
	var closed_snapshot: Dictionary = shell.call("validation_snapshot")
	if dialog.visible \
			or bool(closed_snapshot.get("credits_notices_dialog_visible", true)) \
			or not command.has_focus() \
			or _authority_snapshot() != authority_before:
		_fail("Credits modal close, focus return, or authority preservation failed at %s: %s" % [viewport_size, JSON.stringify(closed_snapshot)])
		return {}
	var result := {
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"dialog_size": {"width": dialog.size.x, "height": dialog.size.y},
		"notice_character_count": body.text.length(),
		"scroll_after_page_down": scroll_after,
		"scroll_after_page_up": body.scroll_vertical,
		"keyboard_or_controller_close": true,
		"startup_dialog_hidden_without_focus": true,
		"focus_return_exact": true,
		"authority_exact": true,
	}
	remove_child(shell)
	shell.queue_free()
	await get_tree().process_frame
	return result

func _authority_snapshot() -> Dictionary:
	return {
		"session": SessionState.ensure_active_session().to_dict(),
		"campaign_storage": CampaignProgression.storage_state(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_committed": SettingsService.validation_settings_transaction_snapshot().get("committed_settings", {}).duplicate(true),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"input_map": _input_map_snapshot(),
		"routes": {
			"battle_resolution": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
			"battle_entry": AppRouter.validation_battle_entry_snapshot(),
			"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
			"return_to_menu": AppRouter.validation_active_play_return_snapshot(),
			"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		},
	}

func _input_map_snapshot() -> Array:
	var rows: Array = []
	for action_value in InputMap.get_actions():
		var action := StringName(action_value)
		var events: Array[String] = []
		for input_event in InputMap.action_get_events(action):
			events.append(input_event.as_text())
		rows.append({
			"action": String(action),
			"deadzone": InputMap.action_get_deadzone(action),
			"events": events,
		})
	return rows

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _press_joypad(button_index: JoyButton) -> void:
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

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
