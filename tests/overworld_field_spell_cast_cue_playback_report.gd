extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const HERO_TILE := Vector2i(5, 5)
const MODES := [
	{"id": "normal", "reduced_motion": false, "spell_id": "spell_waystride"},
	{"id": "reduced_motion", "reduced_motion": true, "spell_id": "spell_survey_chain"},
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
				_fail("Could not set the focused motion preference: %s" % settings_result, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Field-spell cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FIELD_SPELL_CAST_CUE_PLAYBACK_REPORT %s" % JSON.stringify({"ok": true, "rows": rows}))
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

	var spell_id := String(mode.get("spell_id", ""))
	var authored_session = _field_spell_session(spell_id)
	var active_session = SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = active_session
	if live_session.scenario_status != "in_progress" or not live_session.battle.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "live_session_not_active"})
	var map_view = shell.get_node_or_null("%Map")
	var blocker := shell.get_node_or_null("%SpellCastInputBlocker") as Control
	var open_command := shell.get_node_or_null("%OpenCommand") as Button
	var menu := shell.get_node_or_null("%Menu") as Button
	var spell_actions := shell.get_node_or_null("%SpellActions") as Container
	if map_view == null or blocker == null or open_command == null or menu == null or spell_actions == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})

	var malformed_before: Dictionary = map_view.validation_spell_cast_presentation()
	var malformed_after: Dictionary = map_view.present_spell_cast_presentation({
		"serial": 991,
		"event_id": "spell_cast_overworld",
		"cue_id": "cue_spell_cast_overworld",
		"spell_id": spell_id,
	})
	var malformed_fail_closed := malformed_after == malformed_before and not blocker.visible

	open_command.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var spell_button := _enabled_spell_button(spell_actions, live_session, spell_id)
	if spell_button == null:
		return await _finish_case(shell, {"ok": false, "failure": "enabled_spell_button_missing", "spell_id": spell_id})

	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result: Dictionary = OverworldRules.cast_overworld_spell(control, spell_id)
	var control_recap: Dictionary = (control_result.get("post_action_recap", {}) as Dictionary).duplicate(true) if control_result.get("post_action_recap", {}) is Dictionary else {}
	if String(control_recap.get("kind", "")) != "spell":
		return await _finish_case(shell, {"ok": false, "failure": "control_spell_recap_missing", "control_result": control_result})
	control.flags["last_overworld_action_recap"] = control_recap.duplicate(true)
	var return_count_before := int(shell.get("_validation_return_to_menu_request_count"))
	spell_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var active := _spell_presentation(shell)
	var live_after: Dictionary = live_session.to_dict()
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var expected_blocking := "nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout"
	var expected_state := "adventure_spell_icon" if reduced_motion else "adventure_cast_anchor"
	var expected_visual := "reduced_motion_fallback" if reduced_motion else "authored_animation_state"
	var expected_fallback := "adventure_spell_icon" if reduced_motion else ""
	var expected_vfx := ["adventure_spell_icon"] if reduced_motion else ["vfx_placeholder_adventure_spell"]
	var expected_draw := ["adventure_spell_icon"] if reduced_motion else ["adventure_cast_rings", "adventure_spell_icon"]
	var presentation_exact: bool = (
		bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active.get("active", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "spell_cast_overworld"
		and String(active.get("cue_id", "")) == "cue_spell_cast_overworld"
		and String(active.get("spell_id", "")) == spell_id
		and String(active.get("spell_name", "")) == String(ContentService.get_spell(spell_id).get("name", ""))
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and active.get("hero_tile", {}) == {"x": HERO_TILE.x, "y": HERO_TILE.y}
		and String(active.get("animation_state", "")) == expected_state
		and String(active.get("visual_policy", "")) == expected_visual
		and String(active.get("fallback_tag", "")) == expected_fallback
		and String(active.get("playback_policy", "")) == "queue_resolved"
		and String(active.get("blocking_policy", "")) == expected_blocking
		and Array(active.get("vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("audio_cue_ids", [])) == ["audio_placeholder_spell_school_soft"]
		and Array(active.get("draw_entries", [])) == expected_draw
		and bool(active.get("allows_large_motion", true)) == not reduced_motion
		and bool(active.get("blocks_input", false)) == not reduced_motion
		and blocker.visible == not reduced_motion
		and int(active.get("duration_ms", 0)) == (260 if reduced_motion else 620)
		and float(active.get("progress", -1.0)) >= 0.0
		and float(active.get("progress", -1.0)) < 1.0
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
	var progress_before_refresh := float(active.get("progress", 0.0))
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _spell_presentation(shell)
	var refresh_exact: bool = (
		int(refreshed.get("serial", 0)) == serial
		and String(refreshed.get("spell_id", "")) == spell_id
		and float(refreshed.get("progress", -1.0)) >= progress_before_refresh
		and live_session.to_dict() == live_after
	)

	var skipped := false
	if not reduced_motion and viewport_size == VIEWPORT_SIZES[0] and bool(refreshed.get("active", false)):
		await _press_action("ui_cancel")
		skipped = true
	var settle_frames := 0
	while bool(_spell_presentation(shell).get("active", false)) and settle_frames < 12:
		await get_tree().process_frame
		settle_frames += 1
	var settled := _spell_presentation(shell)
	await get_tree().process_frame
	var focus_owner := get_viewport().gui_get_focus_owner()
	var completion_exact: bool = (
		not bool(settled.get("active", true))
		and int(settled.get("serial", 0)) == serial
		and not blocker.visible
		and focus_owner != blocker
		and live_session.to_dict() == live_after
	)

	var failed_authority_before: Dictionary = live_session.to_dict()
	var failed_result: Dictionary = shell.validation_cast_overworld_spell("spell_missing")
	await get_tree().process_frame
	var failed_presentation := _spell_presentation(shell)
	var failed_cast_published_nothing: bool = (
		not bool(failed_result.get("ok", true))
		and int(failed_presentation.get("serial", 0)) == serial
		and not bool(failed_presentation.get("active", true))
		and live_session.to_dict() == failed_authority_before
	)

	var row := {
		"ok": malformed_fail_closed and presentation_exact and pointer_blocked and refresh_exact and completion_exact and failed_cast_published_nothing,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"spell_id": spell_id,
		"malformed_fail_closed": malformed_fail_closed,
		"presentation_exact": presentation_exact,
		"pointer_blocked": pointer_blocked,
		"refresh_exact": refresh_exact,
		"completion_exact": completion_exact,
		"failed_cast_published_nothing": failed_cast_published_nothing,
		"session_matches_independent_control": live_after == control.to_dict(),
		"skipped": skipped,
		"settle_frames": settle_frames,
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["refreshed"] = refreshed
		row["settled"] = settled
		row["failed_result"] = failed_result
		row["failed_presentation"] = failed_presentation
		row["blocker_visible"] = blocker.visible
		row["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _field_spell_session(spell_id: String):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var position := {"x": HERO_TILE.x, "y": HERO_TILE.y}
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero = SpellRules.ensure_hero_spellbook(hero)
	hero["position"] = position.duplicate(true)
	hero["movement"] = {"current": 2, "max": 12}
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	spellbook["known_spell_ids"] = [spell_id]
	spellbook["mana"] = {"current": 40, "max": 40}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
	session.overworld["movement"] = {"current": 2, "max": 12}
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var player_heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(player_heroes.size()):
		if player_heroes[index] is Dictionary and String(player_heroes[index].get("id", "")) == active_hero_id:
			player_heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = player_heroes
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	return session

func _enabled_spell_button(container: Container, session, spell_id: String) -> Button:
	var expected_label := ""
	for action_value in OverworldRules.get_spell_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == "cast_spell:%s" % spell_id:
			if bool(action_value.get("disabled", true)):
				return null
			expected_label = String(action_value.get("label", ""))
			break
	for child in container.get_children():
		if child is Button and not child.disabled and child.text == expected_label:
			return child
	return null

func _spell_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("spell_cast_presentation", {}).duplicate(true) if viewport.get("spell_cast_presentation", {}) is Dictionary else {}

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

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
