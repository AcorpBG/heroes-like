extends Node

const REPORT_ID := "ACTIVE_PLAY_KEYBOARD_FOCUS_SMOKE"
const CAPTURE_DIR := "res://.artifacts/active_play_keyboard_focus_smoke"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_overworld_focus_and_wasd():
		return
	if not await _check_overworld_controller_movement():
		return
	if not await _check_town_keyboard_build():
		return
	if not await _check_narrow_town_keyboard_entry():
		return
	if not await _check_battle_keyboard_defend():
		return
	print("%s PASS" % REPORT_ID)
	get_tree().quit(0)

func _check_overworld_focus_and_wasd() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or focus_owner.name != "PrimaryAction":
		return _fail("Overworld entry focus expected PrimaryAction, got %s." % _focus_name())
	if focus_owner.get_theme_stylebox("focus") == null:
		return _fail("Overworld entry command has no visible focus style.")
	await _press_action("ui_focus_next")
	var next_owner := get_viewport().gui_get_focus_owner()
	if next_owner == null or next_owner == focus_owner or not shell.is_ancestor_of(next_owner):
		return _fail("Overworld focus cycle did not reach another live command: %s." % _focus_name())

	var move := _legal_cardinal_move(session)
	if move.is_empty():
		return _fail("Overworld fixture has no legal cardinal move for WASD validation.")
	var before := OverworldRules.hero_position(session)
	await _press_key(int(move.get("keycode", 0)))
	var after := OverworldRules.hero_position(session)
	if after != before + move.get("delta", Vector2i.ZERO):
		return _fail("Focused overworld UI swallowed WASD movement: before=%s after=%s move=%s." % [before, after, move])
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Overworld WASD movement discarded keyboard focus.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_town_keyboard_build() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Town fixture has no player-owned town.")
	_move_active_hero_to_town(session, town)
	var built_before: Array = town.get("built_buildings", []).duplicate()
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	session = SessionState.set_active_session(session)
	town = _first_player_town(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await _settle()

	var build_actions: Control = shell.get_node("%BuildActions")
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not build_actions.is_ancestor_of(focus_owner) or not (focus_owner is BaseButton) or focus_owner.disabled:
		return _fail("Town entry focus did not land on a ready construction order: %s." % _focus_name())
	var first_build_focus := focus_owner
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	var next_town_focus := get_viewport().gui_get_focus_owner()
	if next_town_focus == null or next_town_focus == first_build_focus or not shell.is_ancestor_of(next_town_focus):
		return _fail("Town right shoulder did not advance the active-play focus cycle: before=%s after=%s." % [first_build_focus, next_town_focus])
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	if get_viewport().gui_get_focus_owner() != first_build_focus:
		return _fail("Town left shoulder did not return to the original construction order: expected=%s got=%s." % [first_build_focus, get_viewport().gui_get_focus_owner()])
	await _capture_if_requested("town_build_order_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if town.get("built_buildings", []) != built_before or session.overworld.get("resources", {}) != resources_before:
		return _fail("Selecting a focused town order spent resources before confirmation.")

	var confirm: Button = shell.get_node("%ConfirmBuild")
	if confirm.disabled:
		return _fail("Focused town order did not enable its confirmation command.")
	confirm.grab_focus()
	await get_tree().process_frame
	await _capture_if_requested("town_build_confirmation_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var built_after: Array = _first_player_town(session).get("built_buildings", [])
	if built_after.size() != built_before.size() + 1:
		return _fail("Controller-confirmed town construction did not add one building: before=%s after=%s." % [built_before, built_after])
	if session.overworld.get("resources", {}) == resources_before:
		return _fail("Controller-confirmed town construction did not spend resources.")
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Town construction refresh did not restore keyboard focus.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_overworld_controller_movement() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var focus_before_dpad := get_viewport().gui_get_focus_owner()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var focus_after_dpad := get_viewport().gui_get_focus_owner()
	if focus_before_dpad == null or focus_after_dpad == null or focus_after_dpad == focus_before_dpad or not shell.is_ancestor_of(focus_after_dpad):
		return _fail("Overworld D-pad did not remain available for command focus navigation: before=%s after=%s." % [focus_before_dpad, focus_after_dpad])
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	var focus_after_right_shoulder := get_viewport().gui_get_focus_owner()
	if focus_after_right_shoulder == null or focus_after_right_shoulder == focus_after_dpad or not shell.is_ancestor_of(focus_after_right_shoulder):
		return _fail("Overworld right shoulder did not advance the command focus cycle: before=%s after=%s." % [focus_after_dpad, focus_after_right_shoulder])
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	if get_viewport().gui_get_focus_owner() != focus_after_dpad:
		return _fail("Overworld left shoulder did not reverse the command focus cycle: expected=%s got=%s." % [focus_after_dpad, get_viewport().gui_get_focus_owner()])
	var drawer_snapshot: Dictionary = shell.call("validation_open_command_drawer")
	if String(drawer_snapshot.get("active_drawer", "")) != "command":
		return _fail("Overworld controller-back fixture could not open the Command drawer: %s." % drawer_snapshot)
	await _press_joypad_button(JOY_BUTTON_B)
	if shell.get_node("%CommandPanel").visible or shell.get_node("%FrontierPanel").visible:
		return _fail("Overworld controller B did not close the open Command drawer.")
	var move := _legal_cardinal_move(session, 2)
	if move.is_empty():
		return _fail("Overworld fixture has no two-step legal cardinal route for controller repeat validation.")
	var before := OverworldRules.hero_position(session)
	var axis_input := _controller_axis_for_delta(move.get("delta", Vector2i.ZERO))
	var axis := int(axis_input.get("axis", -1))
	var axis_value := float(axis_input.get("value", 0.0))
	await _send_joypad_axis(axis, axis_value * 0.2)
	await _send_joypad_axis(axis, 0.0)
	if OverworldRules.hero_position(session) != before:
		return _fail("Overworld left-stick dead zone moved the hero: before=%s after=%s." % [before, OverworldRules.hero_position(session)])
	await _send_joypad_axis(axis, axis_value)
	var immediate := OverworldRules.hero_position(session)
	if immediate != before + move.get("delta", Vector2i.ZERO):
		return _fail("Overworld left-stick deflection did not move immediately: before=%s immediate=%s move=%s." % [before, immediate, move])
	await get_tree().create_timer(0.42).timeout
	var after := OverworldRules.hero_position(session)
	if after != before + move.get("delta", Vector2i.ZERO) * 2:
		return _fail("Overworld left-stick initial/repeat cadence did not move exactly two steps: before=%s after=%s move=%s." % [before, after, move])
	await _send_joypad_axis(axis, 0.0)
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Overworld left-stick movement discarded focused UI state.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_narrow_town_keyboard_entry() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Narrow town fixture has no player-owned town.")
	_move_active_hero_to_town(session, town)
	session = SessionState.set_active_session(session)
	var frame := Control.new()
	frame.name = "NarrowTownFrame"
	frame.size = Vector2(1024.0, 600.0)
	add_child(frame)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle()
	if _focus_name() != "TownOrdersToggle":
		return _fail("Narrow town entry focus expected TownOrdersToggle, got %s." % _focus_name())
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if not shell.get_node("%SidebarShell").visible or shell.get_node("%StageColumn").visible:
		return _fail("Controller-confirmed Town Orders did not open narrow management.")
	var build_actions: Control = shell.get_node("%BuildActions")
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not build_actions.is_ancestor_of(focus_owner) or not (focus_owner is BaseButton) or focus_owner.disabled:
		return _fail("Narrow town management did not move focus into a ready construction order: %s." % _focus_name())
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	if shell.get_node("%SidebarShell").visible or not shell.get_node("%StageColumn").visible:
		return _fail("Controller B did not return from narrow town orders to the scenic town view.")
	if _focus_name() != "TownOrdersToggle":
		return _fail("Narrow town controller back did not restore TownOrdersToggle focus: %s." % _focus_name())
	frame.queue_free()
	await get_tree().process_frame
	return true

func _check_battle_keyboard_defend() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail("Battle fixture has no encounter.")
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
		BattleRules.advance_turn(session.battle)
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		return _fail("Battle fixture could not advance to a player command turn.")
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var forecast: Dictionary = snapshot.get("intent_forecast", {}) if snapshot.get("intent_forecast", {}) is Dictionary else {}
	var action_id := String(forecast.get("action_id", ""))
	var expected_name := _battle_button_name(action_id)
	if expected_name == "" or _focus_name() != expected_name:
		return _fail("Battle entry focus did not match suggested order %s: expected=%s got=%s." % [action_id, expected_name, _focus_name()])
	var battle_entry_focus := get_viewport().gui_get_focus_owner()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var battle_dpad_focus := get_viewport().gui_get_focus_owner()
	if battle_dpad_focus == null or battle_dpad_focus == battle_entry_focus or not shell.is_ancestor_of(battle_dpad_focus):
		return _fail("Battle D-pad did not advance the active command focus: before=%s after=%s." % [battle_entry_focus, battle_dpad_focus])
	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	if get_viewport().gui_get_focus_owner() != battle_entry_focus:
		return _fail("Battle D-pad did not return to the suggested order: expected=%s got=%s." % [battle_entry_focus, get_viewport().gui_get_focus_owner()])
	await _capture_if_requested("battle_suggested_order_focus")
	var previous_target: Button = shell.get_node("%PrevTarget")
	if not previous_target.disabled:
		previous_target.grab_focus()
		await _press_joypad_button(JOY_BUTTON_A)
		await _settle()
		if _focus_name() != "PrevTarget":
			return _fail("Battle target cycling did not preserve focus on the target command: %s." % _focus_name())

	var defend: Button = shell.get_node("%Defend")
	if defend.disabled:
		return _fail("Battle Defend command is disabled on a player turn.")
	var battle_before := JSON.stringify(session.battle)
	var recent_before := int(session.battle.get("recent_events", []).size())
	defend.grab_focus()
	await get_tree().process_frame
	await _capture_if_requested("battle_defend_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if JSON.stringify(session.battle) == battle_before or int(session.battle.get("recent_events", []).size()) <= recent_before:
		return _fail("Controller-confirmed Battle Defend did not mutate battle state and advance the event stream.")
	var post_owner := get_viewport().gui_get_focus_owner()
	if post_owner == null or not shell.is_ancestor_of(post_owner) or (post_owner is BaseButton and post_owner.disabled):
		return _fail("Battle action refresh did not restore focus to a legal command: %s." % _focus_name())
	var post_snapshot: Dictionary = shell.call("validation_snapshot")
	var post_forecast: Dictionary = post_snapshot.get("intent_forecast", {}) if post_snapshot.get("intent_forecast", {}) is Dictionary else {}
	var post_expected := _battle_button_name(String(post_forecast.get("action_id", "")))
	if post_expected != "" and post_owner.name != post_expected:
		return _fail("Battle post-action focus did not follow the next suggested order: expected=%s got=%s." % [post_expected, post_owner.name])
	shell.queue_free()
	await get_tree().process_frame
	return true

func _legal_cardinal_move(session, minimum_steps: int = 1) -> Dictionary:
	for candidate in [
		{"keycode": KEY_W, "delta": Vector2i.UP},
		{"keycode": KEY_S, "delta": Vector2i.DOWN},
		{"keycode": KEY_A, "delta": Vector2i.LEFT},
		{"keycode": KEY_D, "delta": Vector2i.RIGHT},
	]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var delta: Vector2i = candidate.delta
		var route_is_legal := true
		for _step in range(maxi(1, minimum_steps)):
			var result: Dictionary = OverworldRules.try_move(probe, delta.x, delta.y)
			if not bool(result.get("ok", false)) or String(result.get("route", "")) != "":
				route_is_legal = false
				break
		if route_is_legal:
			return candidate
	return {}

func _battle_button_name(action_id: String) -> String:
	return {
		"advance": "Advance",
		"strike": "Strike",
		"shoot": "Shoot",
		"defend": "Defend",
		"retreat": "Retreat",
		"surrender": "Surrender",
	}.get(action_id, "")

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
	await _settle()

func _send_joypad_axis(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await get_tree().process_frame

func _controller_axis_for_delta(delta: Vector2i) -> Dictionary:
	return {
		Vector2i.UP: {"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		Vector2i.DOWN: {"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		Vector2i.LEFT: {"axis": JOY_AXIS_LEFT_X, "value": -1.0},
		Vector2i.RIGHT: {"axis": JOY_AXIS_LEFT_X, "value": 1.0},
	}.get(delta, {})

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_if_requested(stem: String) -> void:
	if OS.get_environment("ACTIVE_PLAY_KEYBOARD_CAPTURE") != "1":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_fail("Could not save visual capture %s: %s." % [path, error])

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _focus_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return "none" if focus_owner == null else String(focus_owner.name)

func _fail(message: String) -> bool:
	if _failed:
		return false
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
	return false
