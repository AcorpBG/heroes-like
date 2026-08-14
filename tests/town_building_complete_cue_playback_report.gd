extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false},
	{"id": "reduced_motion", "reduced_motion": true},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for mode in MODES:
			var settings_result: Dictionary = SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(settings_result.get("ok", false)):
				_fail("Could not set focused motion preference: %s" % settings_result, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Town building cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_BUILDING_COMPLETE_CUE_PLAYBACK_REPORT %s" % JSON.stringify({"ok": true, "rows": rows}))
	get_tree().quit(0)

func _fail(message: String, original_window_size: Vector2i, original_reduced_motion: bool) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)

func _run_case(viewport_size: Vector2i, mode: Dictionary) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var authored_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var authored_town := _first_player_town(authored_session)
	if authored_town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(authored_session, authored_town)
	SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var live_session = SessionState.ensure_active_session()
	var live_town: Dictionary = TownRules.get_active_town(live_session)
	var stage = shell.get_node_or_null("%TownStage")
	var blocker := shell.get_node_or_null("%TownActionInputBlocker") as Control
	var confirm := shell.get_node_or_null("%ConfirmBuild") as Button
	var menu := shell.get_node_or_null("%Menu") as Button
	if stage == null or blocker == null or confirm == null or menu == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	var malformed_before: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_after: Dictionary = stage.present_town_action({"event_id": "town_building_built"})
	var malformed_fail_closed := malformed_after == malformed_before and not blocker.visible

	var actions: Array = TownRules.get_build_actions(live_session)
	var selected_action := {}
	for action_value in actions:
		if action_value is Dictionary and bool(action_value.get("direct_affordable", false)) and not bool(action_value.get("disabled", true)):
			selected_action = action_value.duplicate(true)
			break
	if selected_action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "enabled_build_missing", "actions": actions})
	var full_action_id := String(selected_action.get("id", ""))
	var building_id := full_action_id.trim_prefix("build:")
	var selection: Dictionary = shell.validation_select_build_plan(full_action_id)
	await get_tree().process_frame
	if not bool(selection.get("ok", false)) or confirm.disabled:
		return await _finish_case(shell, {"ok": false, "failure": "live_build_selection_failed", "selection": selection})

	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_before: Dictionary = TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.build_active_town(control, building_id)
	var control_recap: Dictionary = TownRules.build_town_action_recap(control, "build", full_action_id, selected_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)
	var return_count_before := int(shell.get("_validation_return_to_menu_request_count"))
	confirm.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var active: Dictionary = stage.validation_town_action_presentation_snapshot()
	var live_after: Dictionary = live_session.to_dict()
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var expected_blocking := "nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout"
	var expected_state := "building_badge_added" if reduced_motion else "build_complete"
	var expected_vfx := ["building_badge_added"] if reduced_motion else ["vfx_placeholder_build_complete"]
	var expected_draw := ["building_badge_added"] if reduced_motion else ["build_completion_frame", "building_badge_added"]
	var presentation_exact := (
		bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active.get("active", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "town_building_built"
		and String(active.get("cue_id", "")) == "cue_town_building_built"
		and String(active.get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and String(active.get("building_id", "")) == building_id
		and String(active.get("building_name", "")) == String(ContentService.get_building(building_id).get("name", ""))
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and String(active.get("selected_mode", "")) == String(mode.get("id", ""))
		and String(active.get("selected_animation_state", "")) == expected_state
		and String(active.get("selected_blocking_policy", "")) == expected_blocking
		and Array(active.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_town_build"]
		and Array(active.get("draw_entries", [])) == expected_draw
		and bool(active.get("blocks_input", false)) == not reduced_motion
		and blocker.visible == not reduced_motion
		and bool(active.get("draw_rect_contained", false))
		and live_after == control.to_dict()
	)

	var pointer_blocked := true
	if not reduced_motion:
		await _click_global_position(menu.get_global_rect().get_center())
		pointer_blocked = (
			shell.is_inside_tree()
			and int(shell.get("_validation_return_to_menu_request_count")) == return_count_before
			and live_session.to_dict() == live_after
		)

	var serial := int(active.get("serial", 0))
	shell.validation_force_refresh()
	await get_tree().process_frame
	var refreshed: Dictionary = stage.validation_town_action_presentation_snapshot()
	var refresh_exact := int(refreshed.get("serial", 0)) == serial and live_session.to_dict() == live_after
	if bool(refreshed.get("active", false)):
		refresh_exact = refresh_exact and int(refreshed.get("started_msec", 0)) == int(active.get("started_msec", -1))
	else:
		refresh_exact = refresh_exact and Time.get_ticks_msec() >= int(active.get("expires_msec", Time.get_ticks_msec() + 1))

	var skipped := false
	if not reduced_motion and viewport_size == VIEWPORT_SIZES[0] and bool(refreshed.get("active", false)):
		await _press_action("ui_cancel")
		skipped = true
	var deadline := Time.get_ticks_msec() + 1600
	while bool(stage.validation_town_action_presentation_snapshot().get("active", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var expired: Dictionary = stage.validation_town_action_presentation_snapshot()
	await get_tree().process_frame
	var focus_owner := get_viewport().gui_get_focus_owner()
	var completion_exact := (
		not bool(expired.get("active", true))
		and int(expired.get("serial", 0)) == serial
		and not blocker.visible
		and focus_owner != blocker
		and live_session.to_dict() == live_after
	)

	var row := {
		"ok": malformed_fail_closed and presentation_exact and pointer_blocked and refresh_exact and completion_exact,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"building_id": building_id,
		"malformed_fail_closed": malformed_fail_closed,
		"presentation_exact": presentation_exact,
		"pointer_blocked": pointer_blocked,
		"refresh_exact": refresh_exact,
		"completion_exact": completion_exact,
		"skipped": skipped,
		"session_matches_control": live_after == control.to_dict(),
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["refreshed"] = refreshed
		row["expired"] = expired
		row["blocker_visible"] = blocker.visible
		row["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""
		row["refresh_serial_exact"] = int(refreshed.get("serial", 0)) == serial
		row["refresh_started_exact"] = int(refreshed.get("started_msec", 0)) == int(active.get("started_msec", -1)) if bool(refreshed.get("active", false)) else true
		row["refresh_session_exact"] = live_session.to_dict() == live_after
		row["session_differences"] = _recursive_exact_differences(live_after, live_session.to_dict())
	return await _finish_case(shell, row)

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

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
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _click_global_position(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame

func _press_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _recursive_exact_differences(expected: Variant, actual: Variant, path: String = "$") -> Array:
	var differences := []
	if typeof(expected) != typeof(actual):
		return [{"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}]
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(left, right): return String(left) < String(right))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				differences.append({"path": "%s[%s]" % [path, JSON.stringify(key)], "expected_present": expected.has(key), "actual_present": actual.has(key)})
			else:
				differences.append_array(_recursive_exact_differences(expected.get(key), actual.get(key), "%s[%s]" % [path, JSON.stringify(key)]))
		return differences
	if expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(min(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
		return differences
	if expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences
