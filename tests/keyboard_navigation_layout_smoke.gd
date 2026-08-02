extends Node

const REPORT_ID := "KEYBOARD_NAVIGATION_LAYOUT_SMOKE"
const CAPTURE_DIR := "res://.artifacts/keyboard_navigation_layout_smoke"

var _errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_file := _read_original_settings_file()
	await _check_menu_and_live_input()
	_restore_original_settings_file(original_file)
	if _errors.is_empty():
		print("%s PASS" % REPORT_ID)
	else:
		for error in _errors:
			push_error("%s failed: %s" % [REPORT_ID, error])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _check_menu_and_live_input() -> void:
	_apply_capture_size_if_requested()
	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await _settle()
	_expect(bool(menu.call("validation_select_keyboard_navigation_layout", SettingsService.KEYBOARD_NAVIGATION_LAYOUT_IJKL)), "Menu could not select the IJKL navigation layout.")
	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	_expect(
		menu_snapshot.get("keyboard_navigation_layout_picker_items", []) == ["WASD + Arrows", "IJKL + Arrows", "Arrows Only"],
		"Settings picker does not expose the three navigation layouts: %s." % menu_snapshot
	)
	_expect("Navigation IJKL + Arrows" in String(menu_snapshot.get("settings_summary_full", "")), "Settings summary does not expose the selected keyboard layout.")
	_expect("U/O/M/Period" in String(menu_snapshot.get("keyboard_navigation_layout_tooltip", "")), "IJKL settings tooltip does not expose the configured diagonal cluster.")
	_expect(_action_has_key(&"ui_up", KEY_I) and not _action_has_key(&"ui_up", KEY_W), "IJKL selection did not replace managed ui_up letter input immediately.")
	_expect(_action_has_key(&"hero_move_up", KEY_I) and not _action_has_key(&"hero_move_up", KEY_W), "IJKL selection did not replace managed hero movement input immediately.")
	_expect(_action_has_joypad_button(&"ui_up", JOY_BUTTON_DPAD_UP), "IJKL selection removed controller D-pad input.")
	await _capture_if_requested()
	menu.queue_free()
	await get_tree().process_frame

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var move := _legal_cardinal_move(session)
	if move.is_empty():
		_expect(false, "Overworld fixture has no legal cardinal route for keyboard layout validation.")
		return
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var before := OverworldRules.hero_position(session)
	var delta: Vector2i = move.get("delta", Vector2i.ZERO)
	await _press_key(_ijkl_key_for_delta(delta))
	var after := OverworldRules.hero_position(session)
	_expect(after == before + delta, "IJKL physical key did not drive the live overworld action: before=%s after=%s delta=%s." % [before, after, delta])
	await _press_key(_wasd_key_for_delta(delta))
	_expect(OverworldRules.hero_position(session) == after, "Managed WASD key remained active after selecting IJKL.")
	var diagonal_move := _legal_diagonal_move(session)
	if diagonal_move.is_empty():
		_expect(false, "Overworld fixture has no legal diagonal route for keyboard layout validation.")
	else:
		var diagonal_delta: Vector2i = diagonal_move.get("delta", Vector2i.ZERO)
		var before_diagonal := OverworldRules.hero_position(session)
		await _press_key(_ijkl_diagonal_key_for_delta(diagonal_delta))
		var after_diagonal := OverworldRules.hero_position(session)
		_expect(after_diagonal == before_diagonal + diagonal_delta, "IJKL diagonal key did not move the live overworld hero: before=%s after=%s delta=%s." % [before_diagonal, after_diagonal, diagonal_delta])
		await _press_key(_wasd_diagonal_key_for_delta(diagonal_delta))
		_expect(OverworldRules.hero_position(session) == after_diagonal, "Managed Q/E/Z/C diagonal remained active after selecting IJKL.")
	var numpad_move := _legal_diagonal_move(session)
	if numpad_move.is_empty():
		_expect(false, "Overworld fixture has no second legal diagonal route for numpad validation.")
	else:
		var numpad_delta: Vector2i = numpad_move.get("delta", Vector2i.ZERO)
		var before_numpad := OverworldRules.hero_position(session)
		await _press_key(_numpad_key_for_delta(numpad_delta))
		_expect(OverworldRules.hero_position(session) == before_numpad + numpad_delta, "Numpad diagonal did not remain active under IJKL: before=%s after=%s delta=%s." % [before_numpad, OverworldRules.hero_position(session), numpad_delta])
	shell.queue_free()
	await get_tree().process_frame
	await _check_ijkl_shift_diagonal_pan()

	SettingsService.set_keyboard_navigation_layout_id(SettingsService.KEYBOARD_NAVIGATION_LAYOUT_ARROWS)
	_expect(not _any_managed_letter_key_bound(), "Arrows Only retained a managed WASD or IJKL binding.")
	_expect(_action_has_joypad_button(&"ui_up", JOY_BUTTON_DPAD_UP), "Arrows Only removed controller D-pad input.")

func _legal_cardinal_move(session) -> Dictionary:
	for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var result: Dictionary = OverworldRules.try_move(probe, delta.x, delta.y)
		if bool(result.get("ok", false)) and String(result.get("route", "")) == "":
			return {"delta": delta}
	return {}

func _legal_diagonal_move(session) -> Dictionary:
	for delta in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var before := OverworldRules.hero_position(probe)
		var result: Dictionary = OverworldRules.try_move(probe, delta.x, delta.y)
		if bool(result.get("ok", false)) and String(result.get("route", "")) == "" and OverworldRules.hero_position(probe) == before + delta:
			return {"delta": delta}
	return {}

func _check_ijkl_shift_diagonal_pan() -> void:
	var session = ScenarioFactory.create_session("ninefold-confluence", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_viewport: Dictionary = before_snapshot.get("map_viewport", {})
	var before_focus: Dictionary = before_viewport.get("camera_focus_tile", {})
	var hero_before := OverworldRules.hero_position(session)
	await _press_key(KEY_O, true)
	var after_snapshot: Dictionary = shell.call("validation_snapshot")
	var after_viewport: Dictionary = after_snapshot.get("map_viewport", {})
	var after_focus: Dictionary = after_viewport.get("camera_focus_tile", {})
	_expect(OverworldRules.hero_position(session) == hero_before, "Shift plus IJKL diagonal moved the hero instead of panning.")
	_expect(
		int(after_focus.get("x", 0)) == int(before_focus.get("x", 0)) + 3 and int(after_focus.get("y", 0)) == int(before_focus.get("y", 0)) - 3,
		"Shift plus IJKL diagonal did not pan the large-map camera by three tiles: before=%s after=%s." % [before_viewport, after_viewport]
	)
	shell.queue_free()
	await get_tree().process_frame

func _ijkl_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i.UP: KEY_I,
		Vector2i.DOWN: KEY_K,
		Vector2i.LEFT: KEY_J,
		Vector2i.RIGHT: KEY_L,
	}.get(delta, KEY_NONE)

func _wasd_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i.UP: KEY_W,
		Vector2i.DOWN: KEY_S,
		Vector2i.LEFT: KEY_A,
		Vector2i.RIGHT: KEY_D,
	}.get(delta, KEY_NONE)

func _ijkl_diagonal_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i(-1, -1): KEY_U,
		Vector2i(1, -1): KEY_O,
		Vector2i(-1, 1): KEY_M,
		Vector2i(1, 1): KEY_PERIOD,
	}.get(delta, KEY_NONE)

func _wasd_diagonal_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i(-1, -1): KEY_Q,
		Vector2i(1, -1): KEY_E,
		Vector2i(-1, 1): KEY_Z,
		Vector2i(1, 1): KEY_C,
	}.get(delta, KEY_NONE)

func _numpad_key_for_delta(delta: Vector2i) -> Key:
	return {
		Vector2i(-1, -1): KEY_KP_7,
		Vector2i(1, -1): KEY_KP_9,
		Vector2i(-1, 1): KEY_KP_1,
		Vector2i(1, 1): KEY_KP_3,
	}.get(delta, KEY_NONE)

func _any_managed_letter_key_bound() -> bool:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"hero_move_up", &"hero_move_down", &"hero_move_left", &"hero_move_right", &"hero_move_up_left", &"hero_move_up_right", &"hero_move_down_left", &"hero_move_down_right"]:
		for keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_Z, KEY_C, KEY_I, KEY_J, KEY_K, KEY_L, KEY_U, KEY_O, KEY_M, KEY_PERIOD]:
			if _action_has_key(action, keycode):
				return true
	return false

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
	pressed.pressed = true
	pressed.shift_pressed = shift_pressed
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.pressed = false
	released.shift_pressed = shift_pressed
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

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_if_requested() -> void:
	var stem := OS.get_environment("KEYBOARD_NAVIGATION_CAPTURE_STEM").strip_edges()
	if stem == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_expect(false, "Settings capture renderer returned no viewport image.")
		return
	var path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var error := image.save_png(path)
	_expect(error == OK, "Could not save settings capture %s: %s." % [path, error])

func _apply_capture_size_if_requested() -> void:
	var value := OS.get_environment("KEYBOARD_NAVIGATION_CAPTURE_SIZE").strip_edges().to_lower()
	var parts := value.split("x", false)
	if parts.size() != 2:
		return
	var requested_size := Vector2i(int(parts[0]), int(parts[1]))
	if requested_size.x > 0 and requested_size.y > 0:
		get_window().size = requested_size

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
