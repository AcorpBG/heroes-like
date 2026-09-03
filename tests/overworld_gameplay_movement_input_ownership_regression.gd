extends Node

const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "OVERWORLD_GAMEPLAY_MOVEMENT_INPUT_OWNERSHIP_REGRESSION"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"
const OWNER_ROWS := [
	{"id": "drawer", "reason": "drawer_open"},
	{"id": "frontier_drawer", "reason": "drawer_open"},
	{"id": "settings", "reason": "settings_open"},
	{"id": "save_popup", "reason": "save_popup_open"},
	{"id": "manual_overwrite", "reason": "save_confirmation_open"},
	{"id": "end_turn_confirmation", "reason": "end_turn_confirmation_open"},
	{"id": "end_turn_commit", "reason": "end_turn_committing"},
	{"id": "debug_command", "reason": "debug_active"},
]
const OBSERVATION_OVERLAY_CASES := ["debug_overlay", "placement_debug", "combined_debug_overlays"]

var _original_session = null
var _original_slot := 1
var _original_files := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_slot = SaveService.get_selected_manual_slot()
	_original_files = _capture_files([AUTOSAVE_PATH, MANUAL_PATH, AUTOSAVE_PATH + ".candidate", AUTOSAVE_PATH + ".backup", MANUAL_PATH + ".candidate", MANUAL_PATH + ".backup"])
	_clear_save_files()
	var opened: Dictionary = await _create_shell()
	var shell: Node = opened.get("shell")
	var session = opened.get("session")
	if shell == null or session == null or not _require_hooks(shell):
		return
	var seeded: Dictionary = SaveService.save_runtime_manual_session(session, 1)
	if not bool(seeded.get("ok", false)) or not shell.validation_select_save_slot(1):
		await _discard_shell(shell)
		_fail("Could not seed occupied Manual Slot 1.")
		return
	SaveService.inspect_autosave()
	SaveService.inspect_manual_slot(1)
	var rows := {}
	for row_value in OWNER_ROWS:
		var row: Dictionary = row_value
		var proof: Dictionary = await _prove_owner(shell, session, String(row.id), String(row.reason))
		if proof.is_empty():
			await _discard_shell(shell)
			return
		rows[String(row.id)] = proof
	var overlay_rows := {}
	for overlay_id in OBSERVATION_OVERLAY_CASES:
		var overlay_proof: Dictionary = await _prove_nonmodal_observation_overlay(shell, session, overlay_id)
		if overlay_proof.is_empty():
			await _discard_shell(shell)
			return
		overlay_rows[overlay_id] = overlay_proof
	var race: Dictionary = await _prove_activation_race(shell, session)
	if race.is_empty():
		await _discard_shell(shell)
		return
	var ordinary: Dictionary = await _prove_ordinary_focused_movement(shell, session)
	if ordinary.is_empty():
		await _discard_shell(shell)
		return
	await _discard_shell(shell)
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "owners": rows, "nonmodal_observation_overlays": overlay_rows, "activation_race": race, "ordinary": ordinary, "save_version": SessionState.SAVE_VERSION})])
	get_tree().quit(0)


func _prove_owner(shell: Node, session, owner_id: String, expected_reason: String) -> Dictionary:
	var move: Dictionary = _legal_cardinal_move(session, 2)
	if move.is_empty():
		return _fail_dictionary("No two-step legal movement remained for %s." % owner_id)
	shell.validation_reset_gameplay_movement_input_state()
	if not await _open_owner(shell, owner_id):
		return _fail_dictionary("Could not open movement owner %s." % owner_id)
	await _settle(2)
	var blocked_before: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if String(blocked_before.get("blocked_reason", "")) != expected_reason:
		await _close_owner(shell, owner_id)
		return _fail_dictionary("%s exposed %s instead of %s." % [owner_id, blocked_before.get("blocked_reason"), expected_reason])
	var authority_before: Dictionary = _authority_signature(shell, session)
	await _press_physical_key(move.keycode)
	var focus_after_keyboard: Dictionary = _focus_signature(shell)
	if _authority_signature(shell, session) != authority_before \
			or not _focus_belongs_to_owner(shell, owner_id):
		await _close_owner(shell, owner_id)
		return _fail_dictionary("%s configured key escaped its GUI owner or mutated gameplay authority: %s" % [owner_id, JSON.stringify(focus_after_keyboard)])
	var axis: Dictionary = _axis_for_delta(move.delta)
	await _send_axis(int(axis.axis), float(axis.value))
	var delivered_snapshot: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	var controller_intercepted_by_owner := int(delivered_snapshot.get("controller_blocked_count", 0)) == 0
	if controller_intercepted_by_owner:
		shell.validation_controller_move_axis(int(axis.axis), float(axis.value))
	shell.validation_controller_move_repeat()
	var blocked_after: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if _authority_signature(shell, session) != authority_before \
			or _focus_signature(shell) != focus_after_keyboard \
			or int(blocked_after.get("keyboard_blocked_count", -1)) < 0 \
			or int(blocked_after.get("keyboard_blocked_count", 0)) > 1 \
			or int(blocked_after.get("controller_blocked_count", 0)) != 1 \
			or int(blocked_after.get("controller_move_count", -1)) != 0 \
			or bool(blocked_after.get("repeat_timer_active", true)) \
			or blocked_after.get("controller_axis", {}) != {"x": 0.0, "y": 0.0} \
			or blocked_after.get("controller_direction", {}) != {"x": 0, "y": 0}:
		await _close_owner(shell, owner_id)
		return _fail_dictionary("%s did not preserve exact input authority: %s" % [owner_id, JSON.stringify(_compact(blocked_after))])
	await _close_owner(shell, owner_id)
	await _settle(3)
	var closed_authority := _authority_signature(shell, session)
	await get_tree().create_timer(0.40).timeout
	if _authority_signature(shell, session) != closed_authority:
		return _fail_dictionary("%s released into a ghost controller repeat." % owner_id)
	await _press_physical_key(move.keycode)
	var after_key := OverworldRules.hero_position(session)
	if after_key != _tile(authority_before.hero_tile) + move.delta:
		return _fail_dictionary("Configured physical key did not move once after closing %s." % owner_id)
	await _send_axis(int(axis.axis), 0.0)
	await _send_axis(int(axis.axis), float(axis.value))
	await _send_axis(int(axis.axis), 0.0)
	if OverworldRules.hero_position(session) != after_key + move.delta:
		return _fail_dictionary("Fresh left-axis deflection did not move once after closing %s." % owner_id)
	return {"reason": expected_reason, "keyboard_gui_available": true, "controller_intercepted_by_owner": controller_intercepted_by_owner, "axis_consumed_and_cleared": true, "ghost_repeat": false, "released_moves": 2}


func _prove_activation_race(shell: Node, session) -> Dictionary:
	var move: Dictionary = _legal_cardinal_move(session, 1)
	if move.is_empty():
		return _fail_dictionary("No legal activation-race move remained.")
	var axis: Dictionary = _axis_for_delta(move.delta)
	shell.validation_reset_gameplay_movement_input_state()
	await _send_axis(int(axis.axis), float(axis.value))
	var after_initial := OverworldRules.hero_position(session)
	if not await _open_owner(shell, "drawer"):
		return _fail_dictionary("Could not open drawer during armed-repeat race.")
	await _close_owner(shell, "drawer")
	shell.validation_controller_move_repeat()
	await _settle(2)
	var snapshot: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if OverworldRules.hero_position(session) != after_initial \
			or bool(snapshot.get("repeat_timer_active", true)) \
			or snapshot.get("controller_direction", {}) != {"x": 0, "y": 0}:
		return _fail_dictionary("Owner activation did not cancel an already armed repeat: %s" % JSON.stringify(_compact(snapshot)))
	await _send_axis(int(axis.axis), 0.0)
	return {"armed_move_count": 1, "post_owner_repeat_moves": 0}


func _prove_nonmodal_observation_overlay(shell: Node, session, overlay_id: String) -> Dictionary:
	var move: Dictionary = _legal_cardinal_move(session, 6)
	if move.is_empty():
		return _fail_dictionary("No six-step legal movement remained for %s." % overlay_id)
	_set_observation_overlay_case(shell, overlay_id, true)
	await _settle(2)
	var open_snapshot: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if String(open_snapshot.get("blocked_reason", "missing")) != "" \
		or bool(open_snapshot.get("debug_active", true)) \
		or not bool(open_snapshot.get("diagnostic_overlays_visible", false)):
		_set_observation_overlay_case(shell, overlay_id, false)
		return _fail_dictionary("%s still claimed gameplay input ownership: %s" % [overlay_id, JSON.stringify(_compact(open_snapshot))])

	var hero_before := OverworldRules.hero_position(session)
	var movement_before := int(session.overworld.get("movement", {}).get("current", 0))
	await _press_physical_key(move.keycode)
	var after_keyboard := OverworldRules.hero_position(session)
	if after_keyboard != hero_before + move.delta:
		_set_observation_overlay_case(shell, overlay_id, false)
		return _fail_dictionary("Configured physical movement did not pass through %s." % overlay_id)

	var axis: Dictionary = _axis_for_delta(move.delta)
	shell.validation_reset_gameplay_movement_input_state()
	await _send_axis(int(axis.axis), float(axis.value))
	await _send_axis(int(axis.axis), 0.0)
	var after_controller := OverworldRules.hero_position(session)
	if after_controller != after_keyboard + move.delta:
		_set_observation_overlay_case(shell, overlay_id, false)
		return _fail_dictionary("Controller movement did not pass through %s." % overlay_id)

	var route_target: Vector2i = after_controller + move.delta * 2
	var selected: Dictionary = shell.validation_select_tile(route_target.x, route_target.y)
	var primary: Dictionary = shell.validation_perform_primary_action()
	var after_route := OverworldRules.hero_position(session)
	var final_snapshot: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if not bool(selected.get("ok", false)) \
		or not bool(primary.get("ok", false)) \
		or after_route != route_target \
		or String(final_snapshot.get("blocked_reason", "missing")) != "" \
		or bool(final_snapshot.get("debug_active", true)) \
		or not bool(final_snapshot.get("diagnostic_overlays_visible", false)) \
		or int(session.overworld.get("movement", {}).get("current", -1)) != movement_before - 4:
		_set_observation_overlay_case(shell, overlay_id, false)
		return _fail_dictionary("Pointer route movement did not remain live through %s: selected=%s primary=%s snapshot=%s" % [overlay_id, JSON.stringify(selected), JSON.stringify(primary), JSON.stringify(_compact(final_snapshot))])

	_set_observation_overlay_case(shell, overlay_id, false)
	await _settle(2)
	if String(shell.validation_gameplay_movement_input_snapshot().get("blocked_reason", "missing")) != "":
		return _fail_dictionary("Closing %s left a stale movement owner." % overlay_id)
	return {
		"blocked_reason": "",
		"keyboard_steps": 1,
		"controller_steps": 1,
		"pointer_route_steps": 2,
		"movement_spent": 4,
		"overlay_remained_visible_during_commands": true,
		"debug_command_released": true,
	}


func _set_observation_overlay_case(shell: Node, overlay_id: String, enabled: bool) -> void:
	if overlay_id in ["debug_overlay", "combined_debug_overlays"]:
		shell.validation_set_debug_overlay_enabled(enabled)
	if overlay_id in ["placement_debug", "combined_debug_overlays"]:
		shell.validation_set_placement_debug_overlay_enabled(enabled)


func _prove_ordinary_focused_movement(shell: Node, session) -> Dictionary:
	var command: Control = shell.get_node_or_null("%EndTurn")
	if command == null:
		return _fail_dictionary("Ordinary focused command is missing.")
	command.grab_focus()
	await _settle(2)
	var move: Dictionary = _legal_cardinal_move(session, 3)
	if move.is_empty():
		return _fail_dictionary("No legal ordinary movement route remained.")
	var focus_before := get_viewport().gui_get_focus_owner()
	var hero_before := OverworldRules.hero_position(session)
	await _press_physical_key(move.keycode)
	if OverworldRules.hero_position(session) != hero_before + move.delta or get_viewport().gui_get_focus_owner() != focus_before:
		return _fail_dictionary("Focused command prevented ordinary configured-key movement or lost focus.")
	var axis: Dictionary = _axis_for_delta(move.delta)
	shell.validation_reset_gameplay_movement_input_state()
	await _send_axis(int(axis.axis), float(axis.value))
	shell.validation_controller_move_repeat()
	await _send_axis(int(axis.axis), 0.0)
	var snapshot: Dictionary = shell.validation_gameplay_movement_input_snapshot()
	if int(snapshot.get("controller_move_count", -1)) != 2 \
			or OverworldRules.hero_position(session) != hero_before + move.delta * 3 \
			or get_viewport().gui_get_focus_owner() != focus_before:
		return _fail_dictionary("Ordinary left-axis immediate/repeat cadence drifted: %s" % JSON.stringify(_compact(snapshot)))
	var route_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.0)
	var route_after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if int(route_after.get("step_count", 0)) != int(route_before.get("step_count", 0)) + 1:
		return _fail_dictionary("Right-stick route cursor control changed under movement ownership.")
	shell.validation_controller_route_cancel()
	return {"keyboard_moves": 1, "left_axis_moves": 2, "focus_preserved": true, "right_stick_control": true}


func _open_owner(shell: Node, owner_id: String) -> bool:
	match owner_id:
		"drawer":
			shell.validation_open_command_drawer()
		"frontier_drawer":
			shell.validation_open_frontier_drawer()
		"settings":
			shell.validation_open_active_play_settings()
		"save_popup":
			var picker: OptionButton = shell.get_node_or_null("%SaveSlot")
			if picker == null:
				return false
			picker.show_popup()
		"manual_overwrite":
			var snapshot: Dictionary = shell.validation_request_manual_save()
			if not bool(snapshot.get("visible", false)):
				return false
		"end_turn_confirmation":
			var request: Dictionary = shell.validation_request_end_turn()
			if not bool(request.get("confirmation_required", false)):
				return false
		"end_turn_commit":
			shell.validation_set_end_turn_commit_in_progress(true)
		"debug_command":
			shell.validation_set_debug_command_in_progress(true)
		_:
			return false
	return true


func _close_owner(shell: Node, owner_id: String) -> void:
	match owner_id:
		"drawer", "frontier_drawer":
			shell.call("_on_close_drawers_pressed")
		"settings":
			var dialog = shell.validation_active_play_settings_dialog()
			if dialog != null:
				dialog.close_dialog()
		"save_popup":
			var picker: OptionButton = shell.get_node_or_null("%SaveSlot")
			if picker != null:
				picker.get_popup().hide()
		"manual_overwrite":
			shell.validation_cancel_manual_save_overwrite()
		"end_turn_confirmation":
			shell.validation_cancel_end_turn_confirmation()
		"end_turn_commit":
			shell.validation_set_end_turn_commit_in_progress(false)
		"debug_command":
			shell.validation_set_debug_command_in_progress(false)
	await _settle(2)


func _authority_signature(shell: Node, session) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var map_view: Dictionary = snapshot.get("map_viewport", {})
	return {
		"session": _canonical(session.to_dict()),
		"hero_tile": snapshot.get("hero_position", {}),
		"movement": {"current": snapshot.get("movement_current"), "max": snapshot.get("movement_max")},
		"day": snapshot.get("day"),
		"selected_tile": snapshot.get("selected_tile", {}),
		"camera_focus_tile": map_view.get("camera_focus_tile_precise", {}),
		"route_preview": map_view.get("route_preview", {}),
		"autosave": _file_state(AUTOSAVE_PATH),
		"manual": _file_state(MANUAL_PATH),
		"cache": SaveService.validation_summary_cache_snapshot(),
	}


func _focus_signature(shell: Node) -> Dictionary:
	var root_owner := get_viewport().gui_get_focus_owner()
	var result := {"root": root_owner.get_instance_id() if root_owner != null else 0}
	for path in ["ManualSaveOverwriteDialog", "EndTurnConfirmationDialog"]:
		var dialog: ConfirmationDialog = shell.get_node_or_null(path)
		if dialog != null and dialog.visible:
			var owner := dialog.get_cancel_button().get_viewport().gui_get_focus_owner()
			result[path] = owner.get_instance_id() if owner != null else 0
	return result


func _focus_belongs_to_owner(shell: Node, owner_id: String) -> bool:
	var root_owner := get_viewport().gui_get_focus_owner()
	if root_owner != null and (root_owner == shell or shell.is_ancestor_of(root_owner)):
		return true
	var dialog_path: String = String({
		"manual_overwrite": "ManualSaveOverwriteDialog",
		"end_turn_confirmation": "EndTurnConfirmationDialog",
	}.get(owner_id, ""))
	if dialog_path != "":
		var dialog: ConfirmationDialog = shell.get_node_or_null(dialog_path)
		if dialog != null and dialog.visible:
			var dialog_owner := dialog.get_cancel_button().get_viewport().gui_get_focus_owner()
			return dialog_owner != null and (dialog_owner == dialog or dialog.is_ancestor_of(dialog_owner))
	return false


func _create_shell() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var width := 40
	var height := 40
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{"placement_id": "riverwatch_hold", "town_id": "town_riverwatch", "x": 0, "y": 0, "owner": "player"}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["enemy_heroes"] = []
	_set_active_hero_position(session, Vector2i(20, 20))
	_set_active_hero_movement(session, 100)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	var active = SessionState.set_active_session(session)
	var shell := OverworldShellScene.instantiate()
	add_child(shell)
	await _settle(6)
	active = shell.get("_session")
	shell.call("_set_selected_tile", OverworldRules.hero_position(active))
	shell.call("_refresh")
	await _settle(3)
	return {"shell": shell, "session": active}


func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_id:
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _set_active_hero_movement(session, points: int) -> void:
	var movement := {"current": points, "max": points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["base_movement"] = points
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_id:
			heroes[index]["base_movement"] = points
			heroes[index]["movement"] = movement.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _legal_cardinal_move(session, steps: int) -> Dictionary:
	for candidate in [
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_up"), "delta": Vector2i.UP},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_down"), "delta": Vector2i.DOWN},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_left"), "delta": Vector2i.LEFT},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_right"), "delta": Vector2i.RIGHT},
	]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var legal := true
		for _step in range(steps):
			var result: Dictionary = OverworldRules.try_move(probe, candidate.delta.x, candidate.delta.y)
			if not bool(result.get("ok", false)) or String(result.get("route", "")) != "":
				legal = false
				break
		if legal:
			return candidate
	return {}


func _axis_for_delta(delta: Vector2i) -> Dictionary:
	return {
		Vector2i.UP: {"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		Vector2i.DOWN: {"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		Vector2i.LEFT: {"axis": JOY_AXIS_LEFT_X, "value": -1.0},
		Vector2i.RIGHT: {"axis": JOY_AXIS_LEFT_X, "value": 1.0},
	}.get(delta, {})


func _press_physical_key(keycode: Key) -> void:
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
	await _settle(2)


func _send_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = value
	Input.parse_input_event(event)
	await _settle(2)


func _require_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_reset_gameplay_movement_input_state",
		"validation_controller_move_axis",
		"validation_controller_move_repeat",
		"validation_set_end_turn_commit_in_progress",
		"validation_set_debug_command_in_progress",
		"validation_set_debug_overlay_enabled",
		"validation_set_placement_debug_overlay_enabled",
		"validation_select_tile",
		"validation_perform_primary_action",
		"validation_gameplay_movement_input_snapshot",
		"validation_controller_route_cursor_snapshot",
	]:
		if not shell.has_method(method_name):
			return _fail_bool("OverworldShell is missing %s." % method_name)
	return true


func _tile(value: Variant) -> Vector2i:
	return Vector2i(int(value.get("x", -1)), int(value.get("y", -1))) if value is Dictionary else Vector2i(-1, -1)


func _compact(snapshot: Dictionary) -> Dictionary:
	return {"reason": snapshot.get("blocked_reason"), "keyboard": snapshot.get("keyboard_blocked_count"), "controller": snapshot.get("controller_blocked_count"), "repeat": snapshot.get("repeat_blocked_count"), "moves": snapshot.get("controller_move_count"), "axis": snapshot.get("controller_axis"), "direction": snapshot.get("controller_direction"), "timer": snapshot.get("repeat_timer_active"), "focus": snapshot.get("focus_owner"), "debug_active": snapshot.get("debug_active"), "diagnostic_overlays_visible": snapshot.get("diagnostic_overlays_visible")}


func _canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _capture_files(paths: Array) -> Dictionary:
	var result := {}
	for path_value in paths:
		result[String(path_value)] = _file_state(String(path_value))
	return result


func _file_state(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}


func _clear_save_files() -> void:
	for path_value in _original_files.keys():
		_remove_path(String(path_value))
	SaveService.validation_clear_summary_cache()


func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _discard_shell(shell: Node) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await _settle(3)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await get_tree().process_frame


func _cleanup() -> void:
	for path_value in _original_files.keys():
		_remove_path(String(path_value))
		var state: Dictionary = _original_files[path_value]
		if bool(state.get("exists", false)):
			_write_bytes(String(path_value), state.get("bytes", PackedByteArray()))
	SaveService.set_selected_manual_slot(_original_slot)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_session


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
