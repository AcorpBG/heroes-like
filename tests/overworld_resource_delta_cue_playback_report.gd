extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "OVERWORLD_RESOURCE_DELTA_CUE_PLAYBACK_REPORT"
const PLACEMENT_ID := "north_wood"
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
				return _fail("Could not set motion preference: %s" % preference_result, original_window_size, original_reduced_motion)
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				return _fail("Resource-delta cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
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
	var authored_session = _resource_session()
	if authored_session == null:
		return {"ok": false, "failure": "fixture_missing"}
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
	var cue := shell.get_node_or_null("%ResourceDeltaCue") as Label
	var open_command := shell.get_node_or_null("%OpenCommand") as Button
	if primary_action == null or cue == null or open_command == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	var initial: Dictionary = shell.validation_snapshot()
	var primary_exact := String(initial.get("primary_action_id", "")) == "collect_resource" and not primary_action.disabled and primary_action.is_visible_in_tree()
	var malformed_before := _presentation(shell)
	var malformed_after: Dictionary = shell.present_resource_delta_presentation({
		"serial": 991,
		"event_id": "ui_resource_delta",
		"cue_id": "cue_ui_resource_delta",
		"action_id": "collect_resource",
	})
	var malformed_fail_closed := malformed_after == malformed_before and not cue.visible

	var live_before: Dictionary = live_session.to_dict()
	var resources_before: Dictionary = (live_session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result: Dictionary = OverworldRules.perform_context_action(control, "collect_resource")
	var control_recap: Dictionary = (control_result.get("post_action_recap", {}) as Dictionary).duplicate(true) if control_result.get("post_action_recap", {}) is Dictionary else {}
	if String(control_recap.get("kind", "")) != "resource_site":
		return await _finish_case(shell, {"ok": false, "failure": "control_recap_missing", "control": control_result})
	control.flags["last_overworld_action_recap"] = control_recap.duplicate(true)
	primary_action.emit_signal("pressed")
	var active := _presentation(shell)
	var object_resolution := _object_resolution(shell)
	var live_after: Dictionary = live_session.to_dict()
	var expected_deltas := _resource_deltas(resources_before, control.overworld.get("resources", {}), Array(active.get("deltas", [])))
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var presentation_exact: bool = (
		primary_exact
		and bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active.get("active", false))
		and bool(active.get("visible", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "ui_resource_delta"
		and String(active.get("cue_id", "")) == "cue_ui_resource_delta"
		and String(active.get("action_id", "")) == "collect_resource"
		and String(active.get("placement_id", "")) == PLACEMENT_ID
		and active.get("deltas", []) == expected_deltas
		and not expected_deltas.is_empty()
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and active.get("post_action_recap", {}) == control_recap
		and String(active.get("selected_animation_state", "")) == ("resource_delta_static" if reduced_motion else "resource_delta_tick")
		and String(active.get("selected_fallback_tag", "")) == ("resource_delta_static" if reduced_motion else "")
		and String(active.get("selected_playback_policy", "")) == "queue_resolved"
		and String(active.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(active.get("selected_vfx_cue_ids", [])) == (["resource_delta_static"] if reduced_motion else ["vfx_placeholder_resource_delta"])
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_resource_tick"]
		and bool(active.get("allows_large_motion", true)) == not reduced_motion
		and int(active.get("duration_ms", 0)) == (260 if reduced_motion else 520)
		and cue.visible
		and String(active.get("text", "")) != ""
		and String(active.get("tooltip_text", "")) == String(control_result.get("message", ""))
	)
	var object_resolution_exact := (
		String(object_resolution.get("event_id", "")) == "overworld_object_captured"
		and String(object_resolution.get("family", "")) == "resource_site"
		and String(object_resolution.get("placement_id", "")) == PLACEMENT_ID
	)
	var serial := int(active.get("serial", 0))
	var progress_before := float(active.get("progress", 0.0))
	shell.call("_refresh")
	var refreshed := _presentation(shell)
	var refresh_exact: bool = int(refreshed.get("serial", 0)) == serial and bool(refreshed.get("active", false)) and float(refreshed.get("progress", -1.0)) >= progress_before and live_session.to_dict() == live_after
	open_command.emit_signal("pressed")
	var after_command := _presentation(shell)
	var nonblocking_exact: bool = String(shell.get("_active_drawer")) == "command" and bool(after_command.get("active", false)) and live_session.to_dict() == live_after
	var settle_frames := 0
	while bool(_presentation(shell).get("active", false)) and settle_frames < 120:
		await get_tree().process_frame
		settle_frames += 1
	var settled := _presentation(shell)
	var completion_exact: bool = not bool(settled.get("active", true)) and int(settled.get("serial", 0)) == serial and not cue.visible and live_session.to_dict() == live_after
	var failed_before: Dictionary = live_session.to_dict()
	var failed_result: Dictionary = shell.validation_perform_context_action("collect_resource")
	var failed_after := _presentation(shell)
	var failed_exact: bool = not bool(failed_result.get("ok", true)) and int(failed_after.get("serial", 0)) == serial and not bool(failed_after.get("active", true)) and live_session.to_dict() == failed_before
	var row := {
		"ok": malformed_fail_closed and presentation_exact and object_resolution_exact and refresh_exact and nonblocking_exact and completion_exact and failed_exact,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"presentation_exact": presentation_exact,
		"object_resolution_exact": object_resolution_exact,
		"refresh_exact": refresh_exact,
		"nonblocking_exact": nonblocking_exact,
		"completion_exact": completion_exact,
		"failed_exact": failed_exact,
		"settle_frames": settle_frames,
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["refreshed"] = refreshed
		row["object_resolution"] = object_resolution
		row["expected_deltas"] = expected_deltas
		row["session_equal"] = live_after == control.to_dict()
	return await _finish_case(shell, row)

func _resource_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var node: Dictionary = {}
	for value in session.overworld.get("resource_nodes", []):
		if value is Dictionary and String(value.get("placement_id", "")) == PLACEMENT_ID:
			node = value
			break
	if node.is_empty():
		return null
	var position := {"x": int(node.get("x", 0)), "y": int(node.get("y", 0))}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes
	OverworldRules.refresh_fog_of_war(session)
	return session

func _resource_deltas(before: Dictionary, after_value: Variant, ordered_rows: Array) -> Array:
	var after: Dictionary = after_value if after_value is Dictionary else {}
	var result := []
	for row_value in ordered_rows:
		if not (row_value is Dictionary):
			continue
		var resource_id := String(row_value.get("resource_id", ""))
		var delta := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		if resource_id != "" and delta != 0:
			result.append({"resource_id": resource_id, "before": int(before.get(resource_id, 0)), "after": int(after.get(resource_id, 0)), "delta": delta})
	return result

func _presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	return (snapshot.get("resource_delta_presentation", {}) as Dictionary).duplicate(true) if snapshot.get("resource_delta_presentation", {}) is Dictionary else {}

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return (viewport.get("object_resolution_presentation", {}) as Dictionary).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result
