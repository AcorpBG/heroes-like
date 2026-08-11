extends Node

const REPORT_ID := "CUSTOM_HERO_KEYBINDINGS_SMOKE"
const CAPTURE_PATH := "res://.artifacts/custom_hero_keybindings_smoke/dialog-1280x720-130.png"

var _errors: Array[String] = []
var _dismissed_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_file := _read_original_settings_file()
	await _check_custom_bindings()
	_restore_original_settings_file(original_file)
	if _errors.is_empty():
		print("%s PASS" % REPORT_ID)
	else:
		for error in _errors:
			push_error("%s failed: %s" % [REPORT_ID, error])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _check_custom_bindings() -> void:
	SettingsService.set_ui_scale_percent(130)
	SettingsService.set_presentation_resolution("1280x720")
	get_window().size = Vector2i(1280, 720)
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var move := _legal_cardinal_move(session)
	if move.is_empty():
		_expect(false, "River Pass has no exact legal cardinal move for custom binding validation.")
		return
	var delta: Vector2i = move.get("delta", Vector2i.ZERO)
	var live_action := _action_for_delta(delta)
	var preset_key := _ijkl_key_for_delta(delta)

	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await _settle()
	_expect(bool(menu.call("validation_select_keyboard_navigation_layout", SettingsService.KEYBOARD_NAVIGATION_LAYOUT_IJKL)), "Could not select the IJKL preset.")
	var dialog_snapshot: Dictionary = menu.call("validation_open_hero_keybindings_dialog")
	await _settle()
	var dialog: HeroKeybindingsDialog = menu.get_node("HeroKeybindingsDialog")
	dialog_snapshot = dialog.call("validation_snapshot")
	_expect(bool(dialog_snapshot.get("visible", false)), "Custom movement dialog did not open.")
	_expect(int(dialog_snapshot.get("button_count", 0)) == 8, "Custom movement dialog must expose all eight directions: %s." % dialog_snapshot)
	_expect(bool(dialog_snapshot.get("fits_viewport", false)), "Custom movement dialog does not fit a 1280x720 viewport at 130%% UI scaling: %s." % dialog_snapshot)
	dialog.dismissed.connect(_on_dialog_dismissed)
	var disabled_cycle := _binding_focus_cycle(false)
	_expect(disabled_cycle.size() == 9, "Default keybindings cycle must contain eight bindings plus Close: %s." % [disabled_cycle])
	await _check_focus_containment(menu, dialog, session, disabled_cycle, "reset-disabled")
	await _check_boundary_accept_capture(menu, dialog, session, disabled_cycle[0], false)
	await _check_boundary_accept_capture(menu, dialog, session, disabled_cycle[0], true)
	await _check_capture_controller_ownership(menu, dialog, session, &"hero_move_up")

	_expect(bool(menu.call("validation_begin_hero_key_capture", &"hero_move_up")), "Could not begin Up binding capture.")
	var unchanged_result: Dictionary = menu.call("validation_capture_hero_key", KEY_I)
	_expect(bool(unchanged_result.get("ok", false)) and bool(unchanged_result.get("unchanged", false)), "Selecting the current preset key was not treated as unchanged: %s." % unchanged_result)
	_expect(not SettingsService.has_custom_hero_movement_bindings(), "Selecting the current preset key falsely created a custom binding profile.")
	_expect(bool(menu.call("validation_begin_hero_key_capture", &"hero_move_up")), "Could not restart Up binding capture.")
	var reserved_result: Dictionary = menu.call("validation_capture_hero_key", KEY_ESCAPE)
	_expect(not bool(reserved_result.get("ok", false)) and String(reserved_result.get("reason", "")) == "reserved_key", "Escape was not rejected as a reserved key: %s." % reserved_result)
	_expect(SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_I, "Reserved-key rejection mutated the Up binding.")

	var first_result: Dictionary = menu.call("validation_capture_hero_key", KEY_P)
	_expect(bool(first_result.get("ok", false)), "Valid Up reassignment failed: %s." % first_result)
	_expect(_action_has_key(&"hero_move_up", KEY_P) and not _action_has_key(&"hero_move_up", KEY_I), "Up reassignment did not immediately replace the preset key in InputMap.")
	_expect(_action_has_key(&"ui_up", KEY_I), "Hero movement reassignment changed independent menu navigation.")
	_expect(_action_has_joypad_button(&"ui_up", JOY_BUTTON_DPAD_UP), "Hero movement reassignment removed controller D-pad navigation.")
	await _settle()
	var enabled_cycle := _binding_focus_cycle(true)
	_expect(enabled_cycle.size() == 10, "Custom keybindings cycle must contain eight bindings, Reset, and Close: %s." % [enabled_cycle])
	await _check_focus_containment(menu, dialog, session, enabled_cycle, "reset-enabled")
	await _check_capture_controller_ownership(menu, dialog, session, &"hero_move_up")

	_expect(bool(menu.call("validation_begin_hero_key_capture", &"hero_move_down")), "Could not begin Down binding capture.")
	var swap_result: Dictionary = menu.call("validation_capture_hero_key", KEY_P)
	_expect(bool(swap_result.get("ok", false)) and String(swap_result.get("swapped_action", "")) == "hero_move_up", "Duplicate movement key did not swap directions: %s." % swap_result)
	_expect(SettingsService.hero_movement_keycode(&"hero_move_down") == KEY_P and SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_K, "Duplicate-key swap did not preserve a complete unique movement set.")

	var reset_button: Button = dialog.get_node("%ResetBindings")
	reset_button.grab_focus()
	await _settle()
	menu.call("validation_reset_hero_keybindings")
	await _settle()
	_expect(not SettingsService.has_custom_hero_movement_bindings(), "Reset Preset did not clear custom movement bindings.")
	_expect(SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_I and SettingsService.hero_movement_keycode(&"hero_move_down") == KEY_K, "Reset Preset did not restore IJKL movement keys.")
	_expect(reset_button.disabled, "Reset Preset remained enabled after restoring the active preset.")
	_expect(_focus_name() == "CloseBindings", "Disabling a focused Reset did not move focus to Close: %s." % _focus_name())
	await _check_focus_containment(menu, dialog, session, disabled_cycle, "reset-disabled-after-reset")

	_expect(bool(menu.call("validation_begin_hero_key_capture", live_action)), "Could not begin live-direction binding capture for %s." % live_action)
	var live_result: Dictionary = menu.call("validation_capture_hero_key", KEY_P)
	_expect(bool(live_result.get("ok", false)), "Live-direction reassignment failed: %s." % live_result)
	_expect(SettingsService.save_settings() == SettingsService.SETTINGS_FILE, "Custom movement settings did not save to the device config.")
	await _settle()
	var authority_before_close := _background_authority_signature(menu, session)
	var close_count_before := _dismissed_count
	await _press_joypad_button(JOY_BUTTON_B)
	_expect(not bool(dialog.call("validation_snapshot").get("visible", true)), "Final physical B did not close the keybindings dialog.")
	_expect(_dismissed_count == close_count_before + 1, "Final close did not emit exactly one dismissed signal: before=%d after=%d." % [close_count_before, _dismissed_count])
	_expect(_focus_name() == "CustomizeMovementKeys", "Final close did not restore focus to the visible Customize Movement Keys button: %s." % _focus_name())
	_expect(_background_authority_signature(menu, session) == authority_before_close, "Final close changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority.")
	dialog.call("close_dialog")
	await _settle()
	_expect(_dismissed_count == close_count_before + 1, "Idempotent hidden close emitted an extra dismissed signal: %d." % _dismissed_count)
	_expect(_focus_name() == "CustomizeMovementKeys", "Idempotent hidden close changed returned Customize focus: %s." % _focus_name())
	await _capture_if_requested()
	menu.queue_free()
	await get_tree().process_frame

	SettingsService.settings = {}
	SettingsService.load_settings()
	_expect(SettingsService.SETTINGS_VERSION == 14, "Custom keybindings must use current device settings schema 14.")
	_expect(SettingsService.hero_movement_keycode(live_action) == KEY_P, "Custom movement key did not survive SettingsService reload.")
	_expect(_action_has_key(live_action, KEY_P) and not _action_has_key(live_action, preset_key), "Reloaded InputMap did not replace the selected preset key.")

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var before := OverworldRules.hero_position(session)
	await _press_key(KEY_P)
	var after := OverworldRules.hero_position(session)
	_expect(after == before + delta, "Custom physical key did not move the live hero: before=%s after=%s delta=%s action=%s." % [before, after, delta, live_action])
	await _press_key(preset_key)
	_expect(OverworldRules.hero_position(session) == after, "Replaced IJKL preset key still moved the live hero after custom reload.")
	_expect(_action_has_key(&"hero_move_up_right", KEY_KP_9), "Custom movement bindings removed the layout-independent numpad diagonal.")
	shell.queue_free()
	await get_tree().process_frame

	SettingsService.set_keyboard_navigation_layout_id(SettingsService.KEYBOARD_NAVIGATION_LAYOUT_WASD)
	_expect(not SettingsService.has_custom_hero_movement_bindings(), "Selecting a preset did not clear custom movement bindings.")
	_expect(SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_W, "WASD preset did not restore its movement keys after customization.")

func _check_focus_containment(menu, dialog: Control, session, expected_cycle: Array, label: String) -> void:
	var reverse_cycle := [expected_cycle[0]]
	for index in range(expected_cycle.size() - 1, 0, -1):
		reverse_cycle.append(expected_cycle[index])
	await _check_key_cycle(menu, dialog, session, KEY_TAB, false, expected_cycle, "%s Tab/next" % label)
	await _check_key_cycle(menu, dialog, session, KEY_TAB, true, reverse_cycle, "%s Shift+Tab/previous" % label)
	await _check_key_cycle(menu, dialog, session, KEY_DOWN, false, expected_cycle, "%s Arrow Down" % label)
	await _check_key_cycle(menu, dialog, session, KEY_UP, false, reverse_cycle, "%s Arrow Up" % label)
	await _check_button_cycle(menu, dialog, session, JOY_BUTTON_RIGHT_SHOULDER, expected_cycle, "%s right shoulder/next" % label)
	await _check_button_cycle(menu, dialog, session, JOY_BUTTON_LEFT_SHOULDER, reverse_cycle, "%s left shoulder/previous" % label)
	await _check_button_cycle(menu, dialog, session, JOY_BUTTON_DPAD_DOWN, expected_cycle, "%s D-pad Down" % label)
	await _check_button_cycle(menu, dialog, session, JOY_BUTTON_DPAD_UP, reverse_cycle, "%s D-pad Up" % label)

func _check_key_cycle(menu, dialog: Control, session, keycode: Key, shift_pressed: bool, expected_cycle: Array, label: String) -> void:
	_seed_focus(dialog, String(expected_cycle[0]))
	await _settle()
	var authority_before := _background_authority_signature(menu, session)
	var visited := {}
	for expected_value in expected_cycle:
		var expected_name := String(expected_value)
		_expect(_focus_name() == expected_name, "%s expected focus %s and found %s." % [label, expected_name, _focus_name()])
		visited[expected_name] = true
		await _press_key(keycode, shift_pressed)
		_expect(_focus_is_inside(dialog), "%s escaped the visible keybindings dialog after %s." % [label, expected_name])
	_expect(visited.size() == expected_cycle.size() and _focus_name() == String(expected_cycle[0]), "%s did not close its exact %d-control cycle: visited=%s focus=%s." % [label, expected_cycle.size(), visited.keys(), _focus_name()])
	_expect(_background_authority_signature(menu, session) == authority_before, "%s changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority." % label)

func _check_button_cycle(menu, dialog: Control, session, button_index: int, expected_cycle: Array, label: String) -> void:
	_seed_focus(dialog, String(expected_cycle[0]))
	await _settle()
	var authority_before := _background_authority_signature(menu, session)
	var visited := {}
	for expected_value in expected_cycle:
		var expected_name := String(expected_value)
		_expect(_focus_name() == expected_name, "%s expected focus %s and found %s." % [label, expected_name, _focus_name()])
		visited[expected_name] = true
		await _press_joypad_button(button_index)
		_expect(_focus_is_inside(dialog), "%s escaped the visible keybindings dialog after %s." % [label, expected_name])
	_expect(visited.size() == expected_cycle.size() and _focus_name() == String(expected_cycle[0]), "%s did not close its exact %d-control cycle: visited=%s focus=%s." % [label, expected_cycle.size(), visited.keys(), _focus_name()])
	_expect(_background_authority_signature(menu, session) == authority_before, "%s changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority." % label)

func _check_boundary_accept_capture(menu, dialog: Control, session, control_name: String, keyboard_enter: bool) -> void:
	_seed_focus(dialog, control_name)
	await _settle()
	var authority_before := _background_authority_signature(menu, session)
	if keyboard_enter:
		await _press_key(KEY_ENTER)
	else:
		await _press_joypad_button(JOY_BUTTON_A)
	var capture_snapshot: Dictionary = dialog.call("validation_snapshot")
	_expect(bool(capture_snapshot.get("visible", false)) and String(capture_snapshot.get("waiting_action", "")) != "", "%s on the wrapped first boundary did not begin modal capture: %s." % ["Enter" if keyboard_enter else "A", capture_snapshot])
	_expect(_focus_name() == control_name and _focus_is_inside(dialog), "%s boundary Accept did not retain focus inside the keybindings dialog: %s." % ["Enter" if keyboard_enter else "A", _focus_name()])
	_expect(_background_authority_signature(menu, session) == authority_before, "%s boundary Accept changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority." % ["Enter" if keyboard_enter else "A"])
	await _press_key(KEY_ESCAPE)
	var cancelled_snapshot: Dictionary = dialog.call("validation_snapshot")
	_expect(bool(cancelled_snapshot.get("visible", false)) and String(cancelled_snapshot.get("waiting_action", "")) == "", "Escape did not cancel boundary capture while keeping the dialog open: %s." % cancelled_snapshot)
	_expect(_focus_name() == control_name, "Escape capture cancellation did not return to the same binding control: %s." % _focus_name())

func _check_capture_controller_ownership(menu, dialog: Control, session, action: StringName) -> void:
	_expect(bool(menu.call("validation_begin_hero_key_capture", action)), "Could not begin controller-ownership capture for %s." % action)
	await _settle()
	var focus_before := _focus_name()
	var binding_before := SettingsService.hero_movement_keycode(action)
	var authority_before := _background_authority_signature(menu, session)
	for button_index in [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _press_joypad_button(button_index)
		var snapshot: Dictionary = dialog.call("validation_snapshot")
		_expect(bool(snapshot.get("visible", false)) and StringName(snapshot.get("waiting_action", "")) == action, "Capture lost ownership after controller button %d: %s." % [button_index, snapshot])
		_expect(_focus_name() == focus_before and _focus_is_inside(dialog), "Capture controller button %d moved focus outside its binding: before=%s after=%s." % [button_index, focus_before, _focus_name()])
		_expect(SettingsService.hero_movement_keycode(action) == binding_before, "Capture controller button %d changed the pending binding." % button_index)
		_expect(_background_authority_signature(menu, session) == authority_before, "Capture controller button %d changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority." % button_index)
	await _press_joypad_button(JOY_BUTTON_B)
	var cancelled_snapshot: Dictionary = dialog.call("validation_snapshot")
	_expect(bool(cancelled_snapshot.get("visible", false)) and String(cancelled_snapshot.get("waiting_action", "")) == "", "Physical B did not cancel capture while keeping keybindings open: %s." % cancelled_snapshot)
	_expect(_focus_name() == focus_before and _focus_is_inside(dialog), "Physical B capture cancel did not return focus to the pending binding: before=%s after=%s." % [focus_before, _focus_name()])
	_expect(_background_authority_signature(menu, session) == authority_before, "Physical B capture cancel changed hidden Main Menu page/action, session, save-cache, route, settings, or file authority.")

func _binding_focus_cycle(include_reset: bool) -> Array:
	var cycle := []
	for option in SettingsService.build_hero_movement_binding_options():
		cycle.append("Binding_%s" % String(option.get("action", "")))
	if include_reset:
		cycle.append("ResetBindings")
	cycle.append("CloseBindings")
	return cycle

func _seed_focus(dialog: Control, control_name: String) -> void:
	var control := dialog.find_child(control_name, true, false) as Control
	_expect(control != null, "Missing keybindings focus control %s." % control_name)
	if control != null:
		control.grab_focus()

func _focus_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return "none" if focus_owner == null else String(focus_owner.name)

func _focus_is_inside(dialog: Control) -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner != null and (focus_owner == dialog or dialog.is_ancestor_of(focus_owner))

func _background_authority_signature(menu, session) -> String:
	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	return JSON.stringify({
		"session": session.to_dict(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": SettingsService.settings.duplicate(true),
		"settings_file": _settings_file_content(),
		"current_tab": int(menu_snapshot.get("current_tab", -1)),
		"stage_dock_visible": bool(menu_snapshot.get("stage_dock_visible", false)),
		"stage_help_return_tab": int(menu_snapshot.get("stage_help_return_tab", -1)),
		"help_topic_id": String(menu_snapshot.get("help_topic_id", "")),
		"help_intro": String(menu_snapshot.get("help_intro", "")),
		"help_details": String(menu_snapshot.get("help_details", "")),
		"settings_scroll_page": float(menu_snapshot.get("settings_scroll_page", 0.0)),
		"settings_scroll_value": int(menu_snapshot.get("settings_scroll_value", 0)),
		"safe_quit_route": AppRouter.validation_safe_quit_snapshot(),
		"active_play_route": AppRouter.validation_active_play_return_snapshot(),
		"battle_entry_route": AppRouter.validation_battle_entry_snapshot(),
		"battle_resolution_route": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
	})

func _settings_file_content() -> String:
	if not FileAccess.file_exists(SettingsService.SETTINGS_FILE):
		return ""
	var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content

func _on_dialog_dismissed() -> void:
	_dismissed_count += 1

func _legal_cardinal_move(session) -> Dictionary:
	for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var before := OverworldRules.hero_position(probe)
		var result: Dictionary = OverworldRules.try_move(probe, delta.x, delta.y)
		if bool(result.get("ok", false)) and String(result.get("route", "")) == "" and OverworldRules.hero_position(probe) == before + delta:
			return {"delta": delta}
	return {}

func _action_for_delta(delta: Vector2i) -> StringName:
	return {
		Vector2i.UP: &"hero_move_up",
		Vector2i.DOWN: &"hero_move_down",
		Vector2i.LEFT: &"hero_move_left",
		Vector2i.RIGHT: &"hero_move_right",
	}.get(delta, &"")

func _ijkl_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i.UP: KEY_I,
		Vector2i.DOWN: KEY_K,
		Vector2i.LEFT: KEY_J,
		Vector2i.RIGHT: KEY_L,
	}.get(delta, KEY_NONE)

func _action_has_key(action: StringName, keycode: Key) -> bool:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if int(key_event.physical_keycode) == int(keycode) or int(key_event.keycode) == int(keycode):
				return true
	return false

func _action_has_joypad_button(action: StringName, button_index: int) -> bool:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventJoypadButton and int(input_event.button_index) == button_index:
			return true
	return false

func _press_key(keycode: Key, shift_pressed: bool = false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.shift_pressed = shift_pressed
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.shift_pressed = shift_pressed
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

func _read_original_settings_file() -> Dictionary:
	if not FileAccess.file_exists(SettingsService.SETTINGS_FILE):
		return {"existed": false, "content": ""}
	var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return {"existed": false, "content": ""}
	var content := file.get_as_text()
	file.close()
	return {"existed": true, "content": content}

func _restore_original_settings_file(original: Dictionary) -> void:
	if bool(original.get("existed", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR))
		var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.WRITE)
		if file != null:
			file.store_string(String(original.get("content", "")))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE))
	SettingsService.settings = {}
	SettingsService.load_settings()

func _capture_if_requested() -> void:
	if OS.get_environment("CUSTOM_KEYBINDINGS_CAPTURE") != "1":
		return
	await _settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_PATH.get_base_dir()))
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_expect(false, "Custom keybinding capture returned no viewport image.")
		return
	var error := image.save_png(CAPTURE_PATH)
	_expect(error == OK, "Could not save custom keybinding capture: %s." % error)

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
