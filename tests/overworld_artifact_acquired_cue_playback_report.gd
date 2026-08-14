extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "OVERWORLD_ARTIFACT_ACQUIRED_CUE_PLAYBACK_REPORT"
const ARTIFACT_ID := "artifact_trailsinger_boots"
const PLACEMENT_ID := "artifact_acquired_fixture"
const ARTIFACT_TILE := Vector2i(2, 1)
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
			var preference_result: Dictionary = SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(preference_result.get("ok", false)):
				_fail("Could not set motion preference: %s" % preference_result, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Artifact-acquired cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "rows": rows})])
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

	var authored_session = _artifact_session()
	var active_session = SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = active_session
	var primary_action := shell.get_node_or_null("%PrimaryAction") as Button
	var artifact_cue := shell.get_node_or_null("%ArtifactActionCue") as Label
	var artifact_blocker := shell.get_node_or_null("%ArtifactAcquiredInputBlocker") as Control
	var menu := shell.get_node_or_null("%Menu") as Button
	var open_command := shell.get_node_or_null("%OpenCommand") as Button
	if primary_action == null or artifact_cue == null or artifact_blocker == null or menu == null or open_command == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})

	var selected: Dictionary = shell.validation_snapshot()
	await get_tree().process_frame
	var primary_action_exact: bool = (
		String(selected.get("primary_action_id", "")) == "collect_artifact"
		and String(selected.get("active_context_type", "")) == "artifact"
		and not primary_action.disabled
		and primary_action.is_visible_in_tree()
		and primary_action.get_global_rect().size.x > 0.0
		and primary_action.get_global_rect().size.y > 0.0
	)
	var malformed_before := _acquired_presentation(shell)
	var malformed_after: Dictionary = shell.present_artifact_acquired_presentation({
		"serial": 991,
		"event_id": "artifact_acquired",
		"cue_id": "cue_artifact_acquired",
		"artifact_id": ARTIFACT_ID,
	})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not artifact_cue.visible and not artifact_blocker.visible

	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result: Dictionary = OverworldRules.perform_context_action(control, "collect_artifact")
	var control_recap: Dictionary = (control_result.get("post_action_recap", {}) as Dictionary).duplicate(true) if control_result.get("post_action_recap", {}) is Dictionary else {}
	if String(control_recap.get("kind", "")) != "artifact":
		return await _finish_case(shell, {"ok": false, "failure": "control_recap_missing", "control_result": control_result})
	control.flags["last_overworld_action_recap"] = control_recap.duplicate(true)
	var return_count_before := int(shell.get("_validation_return_to_menu_request_count"))
	primary_action.emit_signal("pressed")
	var active := _acquired_presentation(shell)
	var object_resolution := _object_resolution(shell)
	var live_after: Dictionary = live_session.to_dict()
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var expected_blocking := "nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout"
	var expected_state := "artifact_badge_added" if reduced_motion else "artifact_claim"
	var expected_visual := "reduced_motion_fallback" if reduced_motion else "authored_animation_state"
	var expected_fallback := "artifact_badge_added" if reduced_motion else ""
	var expected_vfx := ["artifact_badge_added"] if reduced_motion else ["vfx_placeholder_artifact_claim"]
	var location: Dictionary = ArtifactRules.locate_artifact(live_session.overworld.get("hero", {}), ARTIFACT_ID)
	var node: Dictionary = live_session.overworld.get("artifact_nodes", [])[0]
	var presentation_exact: bool = (
		primary_action_exact
		and bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active.get("active", false))
		and bool(active.get("visible", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "artifact_acquired"
		and String(active.get("cue_id", "")) == "cue_artifact_acquired"
		and String(active.get("action_id", "")) == "collect_artifact"
		and String(active.get("artifact_id", "")) == ARTIFACT_ID
		and String(active.get("artifact_name", "")) == "Trailsinger Boots"
		and String(active.get("placement_id", "")) == PLACEMENT_ID
		and active.get("tile", {}) == {"x": ARTIFACT_TILE.x, "y": ARTIFACT_TILE.y}
		and String(active.get("location", "")) == "equipped"
		and String(active.get("slot", "")) == "boots"
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and active.get("post_action_recap", {}) == control_recap
		and String(active.get("selected_animation_state", "")) == expected_state
		and String(active.get("selected_visual_policy", "")) == expected_visual
		and String(active.get("selected_fallback_tag", "")) == expected_fallback
		and String(active.get("selected_playback_policy", "")) == "queue_resolved"
		and String(active.get("selected_blocking_policy", "")) == expected_blocking
		and Array(active.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_artifact_claim"]
		and bool(active.get("allows_large_motion", true)) == not reduced_motion
		and bool(active.get("blocks_input", false)) == not reduced_motion
		and bool(active.get("input_blocker_visible", false)) == not reduced_motion
		and artifact_blocker.visible == not reduced_motion
		and int(active.get("duration_ms", 0)) == (260 if reduced_motion else 620)
		and String(active.get("text", "")) == "Recovered: Trailsinger Boots • Boots"
		and String(active.get("tooltip_text", "")) == String(control_result.get("message", ""))
		and bool(node.get("collected", false))
		and String(node.get("collected_by_faction_id", "")) == "player"
		and String(location.get("location", "")) == "equipped"
		and String(location.get("slot", "")) == "boots"
	)
	var map_depletion_exact: bool = (
		String(object_resolution.get("event_id", "")) == "overworld_object_depleted"
		and String(object_resolution.get("family", "")) == "artifact"
		and String(object_resolution.get("placement_id", "")) == PLACEMENT_ID
		and object_resolution.get("tile", {}) == {"x": ARTIFACT_TILE.x, "y": ARTIFACT_TILE.y}
	)

	var input_policy_exact := true
	if reduced_motion:
		open_command.emit_signal("pressed")
		var active_after_command: Dictionary = _acquired_presentation(shell)
		input_policy_exact = String(shell.get("_active_drawer")) == "command" and bool(active_after_command.get("active", false))
		await get_tree().process_frame
	else:
		await _click_global_position(menu.get_global_rect().get_center())
		input_policy_exact = (
			shell.is_inside_tree()
			and int(shell.get("_validation_return_to_menu_request_count")) == return_count_before
			and live_session.to_dict() == live_after
		)

	var serial := int(active.get("serial", 0))
	var progress_before_refresh := float(active.get("progress", 0.0))
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _acquired_presentation(shell)
	var refresh_exact: bool = (
		int(refreshed.get("serial", 0)) == serial
		and String(refreshed.get("artifact_id", "")) == ARTIFACT_ID
		and float(refreshed.get("progress", -1.0)) >= progress_before_refresh
		and live_session.to_dict() == live_after
	)

	var skipped := false
	if not reduced_motion and bool(refreshed.get("active", false)):
		await _press_action("ui_cancel")
		skipped = true
	var settle_frames := 0
	while bool(_acquired_presentation(shell).get("active", false)) and settle_frames < 90:
		await get_tree().process_frame
		settle_frames += 1
	var settled := _acquired_presentation(shell)
	await get_tree().process_frame
	var focus_owner := get_viewport().gui_get_focus_owner()
	var completion_exact: bool = (
		not bool(settled.get("active", true))
		and int(settled.get("serial", 0)) == serial
		and not bool(settled.get("input_blocker_visible", true))
		and not artifact_blocker.visible
		and focus_owner != artifact_blocker
		and live_session.to_dict() == live_after
	)

	var failed_authority_before: Dictionary = live_session.to_dict()
	var failed_result: Dictionary = shell.validation_perform_context_action("collect_artifact")
	await get_tree().process_frame
	var failed_presentation := _acquired_presentation(shell)
	var failed_published_nothing: bool = (
		not bool(failed_result.get("ok", true))
		and int(failed_presentation.get("serial", 0)) == serial
		and not bool(failed_presentation.get("active", true))
		and live_session.to_dict() == failed_authority_before
	)

	var row := {
		"ok": malformed_fail_closed and presentation_exact and map_depletion_exact and input_policy_exact and refresh_exact and completion_exact and failed_published_nothing,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"malformed_fail_closed": malformed_fail_closed,
		"presentation_exact": presentation_exact,
		"map_depletion_exact": map_depletion_exact,
		"input_policy_exact": input_policy_exact,
		"refresh_exact": refresh_exact,
		"completion_exact": completion_exact,
		"failed_published_nothing": failed_published_nothing,
		"session_matches_independent_control": live_after == control.to_dict(),
		"skipped": skipped,
		"settle_frames": settle_frames,
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["object_resolution"] = object_resolution
		row["refreshed"] = refreshed
		row["settled"] = settled
		row["failed_result"] = failed_result
		row["failed_presentation"] = failed_presentation
		row["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _artifact_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(3):
		var row := []
		for _x in range(5):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": 5, "height": 3, "x": 5, "y": 3}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["artifact_nodes"] = [{
		"placement_id": PLACEMENT_ID,
		"artifact_id": ARTIFACT_ID,
		"x": ARTIFACT_TILE.x,
		"y": ARTIFACT_TILE.y,
		"collected": false,
	}]
	var position := {"x": ARTIFACT_TILE.x, "y": ARTIFACT_TILE.y}
	var movement := {"current": 6, "max": 6}
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	hero["movement"] = movement.duplicate(true)
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({})
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
	session.overworld["movement"] = movement.duplicate(true)
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

func _acquired_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	return snapshot.get("artifact_acquired_presentation", {}).duplicate(true) if snapshot.get("artifact_acquired_presentation", {}) is Dictionary else {}

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

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
