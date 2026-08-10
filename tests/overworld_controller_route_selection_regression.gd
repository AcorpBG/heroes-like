extends Node

const REPORT_ID := "OVERWORLD_CONTROLLER_ROUTE_SELECTION_REGRESSION"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_SLOT := 1

var _original_session = null
var _original_files: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_files = _capture_file_states([AUTOSAVE_PATH, _manual_slot_path(MANUAL_SLOT)])
	var preview := await _validate_cursor_preview_and_direction_state()
	if preview.is_empty():
		return
	var actions := await _validate_cancel_accept_left_move_and_boundary()
	if actions.is_empty():
		return
	var blockers := await _validate_interaction_blockers()
	if blockers.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"preview": preview,
		"actions": actions,
		"blockers": blockers,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _validate_cursor_preview_and_direction_state() -> Dictionary:
	_clear_save_files()
	var opened := await _create_shell(Vector2i(12, 8), 30, Vector2i(24, 16))
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null or not _require_hooks(shell):
		await _discard_shell(shell)
		return {}
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(save_result.get("ok", false)):
		_fail("Could not seed the autosave mutation boundary.", _compact(save_result))
		await _discard_shell(shell)
		return {}
	var session_before := _canonical(session.to_dict())
	var day_before: int = session.day
	var movement_before := _movement_snapshot(session)
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var reset: Dictionary = shell.validation_reset_controller_route_cursor()
	var hero_tile: Dictionary = reset.get("hero_tile", {})

	var dead: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.50)
	if bool(dead.get("active", false)) or int(dead.get("step_count", -1)) != 0 \
			or dead.get("selected_tile", {}) != hero_tile:
		_fail("Sub-dead-zone right-stick input moved or activated the route cursor.", _compact_cursor(dead))
		await _discard_shell(shell)
		return {}

	var cardinal: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var expected_right := _offset_tile(hero_tile, Vector2i.RIGHT)
	if not bool(cardinal.get("active", false)) or cardinal.get("selected_tile", {}) != expected_right \
			or int(cardinal.get("step_count", 0)) != 1:
		_fail("Cardinal right-stick input did not move the route cursor exactly once.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}
	if (cardinal.get("route_preview", {}) as Dictionary).is_empty() \
			or String((cardinal.get("primary_action", {}) as Dictionary).get("id", "")) == "":
		_fail("Route-cursor selection did not expose the existing preview and primary action.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}
	if cardinal.get("camera_focus_tile", {}) != expected_right:
		_fail("Route-cursor selection did not pan the camera with the selected tile.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}

	var held: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	if int(held.get("step_count", 0)) != 1 or held.get("selected_tile", {}) != expected_right:
		_fail("A held cardinal axis stepped before the repeat gate.", _compact_cursor(held))
		await _discard_shell(shell)
		return {}
	var opposed: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, -1.0)
	if int(opposed.get("step_count", 0)) != 2 or opposed.get("selected_tile", {}) != hero_tile:
		_fail("An opposed axis did not deterministically reverse one tile.", _compact_cursor(opposed))
		await _discard_shell(shell)
		return {}
	var release: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.0)
	if release.get("direction", {}) != {"x": 0, "y": 0} or bool(release.get("repeat_timer_active", true)):
		_fail("Right-stick release did not re-arm and stop repeat.", _compact_cursor(release))
		await _discard_shell(shell)
		return {}

	var up: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -1.0)
	var expected_up := _offset_tile(hero_tile, Vector2i.UP)
	if up.get("selected_tile", {}) != expected_up or int(up.get("step_count", 0)) != 3:
		_fail("Cardinal vertical input did not move one tile.", _compact_cursor(up))
		await _discard_shell(shell)
		return {}
	var vertical_release: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, 0.0)
	var right_again: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var dominated: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -0.80)
	if dominated.get("selected_tile", {}) != right_again.get("selected_tile", {}) \
			or int(dominated.get("step_count", 0)) != int(right_again.get("step_count", 0)):
		_fail("A weaker opposed cardinal axis overrode the dominant held axis.", _compact_cursor(dominated))
		await _discard_shell(shell)
		return {}
	var tie_opposed: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -1.0)
	if tie_opposed.get("selected_tile", {}) != _offset_tile(right_again.get("selected_tile", {}), Vector2i.UP):
		_fail("Equal opposed axes did not resolve deterministically to the newly dominant vertical axis.", _compact_cursor(tie_opposed))
		await _discard_shell(shell)
		return {}
	var repeated: Dictionary = shell.validation_controller_route_repeat()
	if int(repeated.get("repeat_count", 0)) != 1 \
			or int(repeated.get("step_count", 0)) != int(tie_opposed.get("step_count", 0)) + 1 \
			or not bool((repeated.get("last_step", {}) as Dictionary).get("repeat", false)):
		_fail("Deterministic repeat did not add exactly one held-direction step.", _compact_cursor(repeated))
		await _discard_shell(shell)
		return {}

	if _canonical(session.to_dict()) != session_before or session.day != day_before \
			or _movement_snapshot(session) != movement_before or _file_state(AUTOSAVE_PATH) != autosave_before:
		_fail("Route preview changed the session, day, movement, or autosave bytes before confirmation.", {
			"session_equal": _canonical(session.to_dict()) == session_before,
			"day": session.day,
			"movement": _movement_snapshot(session),
			"autosave_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
		})
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return {
		"dead_zone": true,
		"cardinal": true,
		"opposed": true,
		"release": true,
		"repeat": true,
		"session_unchanged": true,
		"autosave_unchanged": true,
	}


func _validate_cancel_accept_left_move_and_boundary() -> Dictionary:
	var cancel_opened := await _create_shell(Vector2i(6, 4), 20, Vector2i(14, 9))
	var cancel_shell: Node = cancel_opened.get("shell", null)
	var cancel_session = cancel_opened.get("session", null)
	if cancel_shell == null or cancel_session == null or not _require_hooks(cancel_shell):
		await _discard_shell(cancel_shell)
		return {}
	var before_cancel := _canonical(cancel_session.to_dict())
	var before_cancel_save := _file_state(AUTOSAVE_PATH)
	cancel_shell.validation_reset_controller_route_cursor()
	cancel_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _press_joypad_button(JOY_BUTTON_B)
	var canceled: Dictionary = cancel_shell.validation_controller_route_cursor_snapshot()
	if bool(canceled.get("active", true)) or int(canceled.get("cancel_count", 0)) != 1 \
			or canceled.get("selected_tile", {}) != canceled.get("hero_tile", {}) \
			or canceled.get("camera_focus_tile", {}) != canceled.get("hero_tile", {}):
		_fail("Controller B did not reset route selection and camera exactly to the hero.", _compact_cursor(canceled))
		await _discard_shell(cancel_shell)
		return {}
	if _canonical(cancel_session.to_dict()) != before_cancel or _file_state(AUTOSAVE_PATH) != before_cancel_save:
		_fail("Controller B reset mutated gameplay state or autosave bytes.")
		await _discard_shell(cancel_shell)
		return {}
	await _discard_shell(cancel_shell)

	var accept_opened := await _create_shell(Vector2i(4, 3), 20, Vector2i(12, 8))
	var accept_shell: Node = accept_opened.get("shell", null)
	var accept_session = accept_opened.get("session", null)
	if accept_shell == null or accept_session == null or not _require_hooks(accept_shell):
		await _discard_shell(accept_shell)
		return {}
	accept_shell.validation_reset_controller_route_cursor()
	var hero_before_accept := OverworldRules.hero_position(accept_session)
	var movement_before_accept := _movement_snapshot(accept_session)
	var selected: Dictionary = accept_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _press_joypad_button(JOY_BUTTON_A)
	var accepted: Dictionary = accept_shell.validation_controller_route_cursor_snapshot()
	var last_accept: Dictionary = accepted.get("last_accept", {}) if accepted.get("last_accept", {}) is Dictionary else {}
	if int(accepted.get("accept_count", 0)) != 1 or int(accepted.get("primary_action_invocation_count", 0)) != 1 \
			or int(last_accept.get("invocation_count_delta", 0)) != 1 or not bool(last_accept.get("activated", false)) \
			or bool(accepted.get("active", true)):
		_fail("Controller A did not invoke the existing selected primary action exactly once.", _compact_cursor(accepted))
		await _discard_shell(accept_shell)
		return {}
	if OverworldRules.hero_position(accept_session) == hero_before_accept \
			or _movement_snapshot(accept_session) == movement_before_accept \
			or last_accept.get("selected_tile_before", {}) != selected.get("selected_tile", {}):
		_fail("Controller A did not commit the selected route through gameplay movement.", {
			"last_accept": last_accept,
			"hero_before": _tile_payload(hero_before_accept),
			"hero_after": _tile_payload(OverworldRules.hero_position(accept_session)),
			"movement_before": movement_before_accept,
			"movement_after": _movement_snapshot(accept_session),
		})
		await _discard_shell(accept_shell)
		return {}
	await _discard_shell(accept_shell)

	var left_opened := await _create_shell(Vector2i(4, 3), 20, Vector2i(12, 8))
	var left_shell: Node = left_opened.get("shell", null)
	var left_session = left_opened.get("session", null)
	if left_shell == null or left_session == null or not _require_hooks(left_shell):
		await _discard_shell(left_shell)
		return {}
	left_shell.validation_reset_controller_route_cursor()
	var left_hero_before := OverworldRules.hero_position(left_session)
	var left_movement_before := _movement_snapshot(left_session)
	await _send_joypad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _send_joypad_axis(JOY_AXIS_LEFT_X, 0.0)
	var left_snapshot: Dictionary = left_shell.validation_controller_route_cursor_snapshot()
	if OverworldRules.hero_position(left_session) != left_hero_before + Vector2i.RIGHT \
			or _movement_snapshot(left_session) == left_movement_before \
			or int(left_snapshot.get("left_move_count", 0)) != 1 \
			or int(left_snapshot.get("step_count", 0)) != 0:
		_fail("Left-stick immediate movement changed or was replaced by route-cursor behavior.", {
			"cursor": _compact_cursor(left_snapshot),
			"hero_before": _tile_payload(left_hero_before),
			"hero_after": _tile_payload(OverworldRules.hero_position(left_session)),
			"movement_before": left_movement_before,
			"movement_after": _movement_snapshot(left_session),
		})
		await _discard_shell(left_shell)
		return {}
	await _discard_shell(left_shell)

	var boundary_opened := await _create_shell(Vector2i.ZERO, 20, Vector2i(8, 6))
	var boundary_shell: Node = boundary_opened.get("shell", null)
	var boundary_session = boundary_opened.get("session", null)
	if boundary_shell == null or boundary_session == null or not _require_hooks(boundary_shell):
		await _discard_shell(boundary_shell)
		return {}
	boundary_shell.validation_reset_controller_route_cursor()
	var boundary_before := _canonical(boundary_session.to_dict())
	var bounded: Dictionary = boundary_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, -1.0)
	var bounded_step: Dictionary = bounded.get("last_step", {}) if bounded.get("last_step", {}) is Dictionary else {}
	if bounded.get("selected_tile", {}) != {"x": 0, "y": 0} or int(bounded.get("step_count", -1)) != 0 \
			or bool(bounded_step.get("changed", true)) or not bool(bounded_step.get("bounded", false)):
		_fail("Right-stick route cursor crossed or wrapped the map boundary.", _compact_cursor(bounded))
		await _discard_shell(boundary_shell)
		return {}
	if _canonical(boundary_session.to_dict()) != boundary_before:
		_fail("A bounded route-cursor step mutated the session.")
		await _discard_shell(boundary_shell)
		return {}
	await _discard_shell(boundary_shell)
	return {"cancel": true, "accept_once": true, "left_stick_move": true, "boundary": true}


func _validate_interaction_blockers() -> Dictionary:
	var opened := await _create_shell(Vector2i(6, 4), 20, Vector2i(14, 9))
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null or not _require_hooks(shell):
		await _discard_shell(shell)
		return {}
	var session_before := _canonical(session.to_dict())
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var blockers := {}

	shell.validation_reset_controller_route_cursor()
	var drawer: Dictionary = shell.validation_open_command_drawer()
	if String(drawer.get("active_drawer", "")) != "command" or not await _assert_right_input_blocked(shell, "drawer_open"):
		await _discard_shell(shell)
		return {}
	blockers["drawer"] = true
	shell.call("_on_close_drawers_pressed")
	await _settle()

	var settings: Dictionary = shell.validation_open_active_play_settings()
	if not bool(settings.get("visible", false)) or not await _assert_right_input_blocked(shell, "settings_open"):
		await _discard_shell(shell)
		return {}
	blockers["settings"] = true
	var settings_dialog = shell.validation_active_play_settings_dialog()
	settings_dialog.close_dialog()
	await _settle()

	var save_picker: OptionButton = shell.get_node_or_null("%SaveSlot")
	if save_picker == null:
		_fail("Overworld shell is missing its save-slot picker.")
		await _discard_shell(shell)
		return {}
	save_picker.get_popup().popup(Rect2i(20, 20, 180, 120))
	await _settle()
	if not save_picker.get_popup().visible or not await _assert_right_input_blocked(shell, "save_popup_open"):
		await _discard_shell(shell)
		return {}
	blockers["save_popup"] = true
	save_picker.get_popup().hide()
	await _settle()

	if SaveService.save_manual_session(session.to_dict(), MANUAL_SLOT) == "":
		_fail("Could not seed the occupied manual-save confirmation fixture.")
		await _discard_shell(shell)
		return {}
	SaveService.set_selected_manual_slot(MANUAL_SLOT)
	var overwrite: Dictionary = shell.validation_request_manual_save()
	if not bool(overwrite.get("visible", false)) or not await _assert_right_input_blocked(shell, "save_confirmation_open"):
		await _discard_shell(shell)
		return {}
	blockers["manual_overwrite"] = true
	shell.validation_cancel_manual_save_overwrite()
	await _settle()

	var end_turn: Dictionary = shell.validation_request_end_turn()
	var end_turn_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if not bool(end_turn.get("confirmation_required", false)) or not bool(end_turn_snapshot.get("dialog_visible", false)) \
			or not await _assert_right_input_blocked(shell, "end_turn_confirmation_open"):
		_fail("Could not establish the warned End Turn confirmation blocker.", _compact(end_turn_snapshot))
		await _discard_shell(shell)
		return {}
	blockers["end_turn_confirmation"] = true
	shell.validation_cancel_end_turn_confirmation()

	if _canonical(session.to_dict()) != session_before or _file_state(AUTOSAVE_PATH) != autosave_before:
		_fail("Blocked right-stick input changed the session or autosave bytes.", {
			"session_equal": _canonical(session.to_dict()) == session_before,
			"autosave_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
		})
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return blockers


func _assert_right_input_blocked(shell: Node, expected_reason: String) -> bool:
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 0.0)
	var before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 1.0)
	var after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 0.0)
	if String(after.get("blocked_reason", "")) != expected_reason \
			or after.get("selected_tile", {}) != before.get("selected_tile", {}) \
			or int(after.get("step_count", 0)) != int(before.get("step_count", 0)) \
			or bool(after.get("active", false)):
		return _fail("Right-stick input was not blocked by %s." % expected_reason, {
			"before": _compact_cursor(before),
			"after": _compact_cursor(after),
		})
	return true


func _create_shell(hero_tile: Vector2i, movement_points: int, map_size: Vector2i) -> Dictionary:
	var session = _session_with_map(map_size.x, map_size.y)
	_set_active_hero_position(session, hero_tile)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	shell.call("_set_selected_tile", hero_tile)
	shell.call("_refresh")
	await _settle()
	return {"shell": shell, "session": active_session}


func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{
		"placement_id": "riverwatch_hold",
		"town_id": "town_riverwatch",
		"x": 0,
		"y": 0,
		"owner": "player",
	}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["enemy_heroes"] = []
	OverworldRules.refresh_fog_of_war(session)
	return session


func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes


func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["base_movement"] = movement_points
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes


func _require_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_reset_controller_route_cursor",
		"validation_controller_route_axis",
		"validation_controller_route_repeat",
		"validation_controller_route_accept",
		"validation_controller_route_cancel",
		"validation_controller_route_cursor_snapshot",
	]:
		if not shell.has_method(method_name):
			return _fail("OverworldShell is missing controller route hook %s." % method_name)
	return true


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
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await _settle()


func _movement_snapshot(session) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	return {
		"current": int(movement.get("current", session.overworld.get("movement", {}).get("current", 0))),
		"max": int(movement.get("max", session.overworld.get("movement", {}).get("max", 0))),
	}


func _compact_cursor(snapshot: Dictionary) -> Dictionary:
	return {
		"active": bool(snapshot.get("active", false)),
		"axis": snapshot.get("axis", {}),
		"direction": snapshot.get("direction", {}),
		"selected": snapshot.get("selected_tile", {}),
		"hero": snapshot.get("hero_tile", {}),
		"camera": snapshot.get("camera_focus_tile", {}),
		"primary_action_id": String((snapshot.get("primary_action", {}) as Dictionary).get("id", "")),
		"route_preview_empty": (snapshot.get("route_preview", {}) as Dictionary).is_empty(),
		"steps": int(snapshot.get("step_count", 0)),
		"repeats": int(snapshot.get("repeat_count", 0)),
		"accepts": int(snapshot.get("accept_count", 0)),
		"cancels": int(snapshot.get("cancel_count", 0)),
		"blocked": int(snapshot.get("blocked_count", 0)),
		"blocked_reason": String(snapshot.get("blocked_reason", "")),
		"last_step": snapshot.get("last_step", {}),
		"last_accept": snapshot.get("last_accept", {}),
	}


func _compact(value: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["ok", "reason", "message", "path", "pending", "dialog_visible", "confirmation_required"]:
		if value.has(key):
			compact[key] = value[key]
	return compact


func _offset_tile(tile: Dictionary, delta: Vector2i) -> Dictionary:
	return {"x": int(tile.get("x", 0)) + delta.x, "y": int(tile.get("y", 0)) + delta.y}


func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}


func _canonical(value: Variant) -> String:
	return JSON.stringify(value)


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states


func _restore_file_states(states: Dictionary) -> void:
	for path_value in states.keys():
		var path := String(path_value)
		var state: Dictionary = states[path]
		if not bool(state.get("exists", false)):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()


func _clear_save_files() -> void:
	for path in [AUTOSAVE_PATH, _manual_slot_path(MANUAL_SLOT)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _manual_slot_path(slot: int) -> String:
	return "user://saves/manual_%d.json" % slot


func _cleanup() -> void:
	_restore_file_states(_original_files)
	SessionState.active_session = _original_session


func _discard_shell(shell: Node) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail(message: String, payload: Variant = {}) -> bool:
	_cleanup()
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
