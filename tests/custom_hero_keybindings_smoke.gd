extends Node

const REPORT_ID := "CUSTOM_HERO_KEYBINDINGS_SMOKE"
const CAPTURE_PATH := "res://.artifacts/custom_hero_keybindings_smoke/dialog-1280x720-130.png"

var _errors: Array[String] = []

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
	dialog_snapshot = menu.get_node("HeroKeybindingsDialog").call("validation_snapshot")
	_expect(bool(dialog_snapshot.get("visible", false)), "Custom movement dialog did not open.")
	_expect(int(dialog_snapshot.get("button_count", 0)) == 8, "Custom movement dialog must expose all eight directions: %s." % dialog_snapshot)
	_expect(bool(dialog_snapshot.get("fits_viewport", false)), "Custom movement dialog does not fit a 1280x720 viewport at 130%% UI scaling: %s." % dialog_snapshot)

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

	_expect(bool(menu.call("validation_begin_hero_key_capture", &"hero_move_down")), "Could not begin Down binding capture.")
	var swap_result: Dictionary = menu.call("validation_capture_hero_key", KEY_P)
	_expect(bool(swap_result.get("ok", false)) and String(swap_result.get("swapped_action", "")) == "hero_move_up", "Duplicate movement key did not swap directions: %s." % swap_result)
	_expect(SettingsService.hero_movement_keycode(&"hero_move_down") == KEY_P and SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_K, "Duplicate-key swap did not preserve a complete unique movement set.")

	menu.call("validation_reset_hero_keybindings")
	_expect(not SettingsService.has_custom_hero_movement_bindings(), "Reset Preset did not clear custom movement bindings.")
	_expect(SettingsService.hero_movement_keycode(&"hero_move_up") == KEY_I and SettingsService.hero_movement_keycode(&"hero_move_down") == KEY_K, "Reset Preset did not restore IJKL movement keys.")

	_expect(bool(menu.call("validation_begin_hero_key_capture", live_action)), "Could not begin live-direction binding capture for %s." % live_action)
	var live_result: Dictionary = menu.call("validation_capture_hero_key", KEY_P)
	_expect(bool(live_result.get("ok", false)), "Live-direction reassignment failed: %s." % live_result)
	_expect(SettingsService.save_settings() == SettingsService.SETTINGS_FILE, "Custom movement settings did not save to the device config.")
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
