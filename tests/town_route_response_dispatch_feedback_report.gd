extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false, "missing_asset": false},
	{"id": "missing_asset", "reduced_motion": false, "missing_asset": true},
	{"id": "reduced_motion", "reduced_motion": true, "missing_asset": false},
]
const TEXTURE_PATH := "res://art/town/runtime/vfx/route_response.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		for mode_value in MODES:
			var mode: Dictionary = mode_value
			var settings_result := SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(settings_result.get("ok", false)):
				_fail("Could not set focused motion preference.", {"mode": mode, "settings_result": settings_result}, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Town route-response dispatch row failed.", {"row": row}, original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_ROUTE_RESPONSE_DISPATCH_FEEDBACK_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_imported_rows": 2,
		"missing_asset_fallback_rows": 2,
		"reduced_motion_rows": 2,
		"public_handler_rows": 6,
		"save_version": SessionDataScript.SAVE_VERSION,
		"rows": rows,
	}))
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, mode: Dictionary) -> Dictionary:
	PresentationAudio.validation_reset()
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
	_seed_route_response_fixture(authored_session, authored_town)
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
	if stage == null or blocker == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	var malformed_before: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_after: Dictionary = stage.present_town_action({"event_id": "town_route_response_ordered"})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not blocker.visible and PresentationAudio.validation_records().is_empty()

	var selected_action := _first_enabled_site_response_action(live_session)
	if selected_action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "enabled_site_response_missing", "actions": TownRules.get_response_actions(live_session)})
	var action_id := String(selected_action.get("id", ""))
	var placement_id := action_id.trim_prefix("site_response:")
	if bool(mode.get("missing_asset", false)):
		stage.set("_town_vfx_texture_missing", {TEXTURE_PATH: true})

	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_before := TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.perform_response_action(control, action_id)
	var control_recap := TownRules.build_town_action_recap(control, "response", action_id, selected_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)
	var control_node_result := OverworldRules._find_resource_node_by_placement(control, placement_id)
	var control_node: Dictionary = control_node_result.get("node", {}) if control_node_result.get("node", {}) is Dictionary else {}
	var control_site := ContentService.get_resource_site(String(control_node.get("site_id", "")))
	var control_response := OverworldRules._resource_site_response_state(control, control_node, control_site)

	var public_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var active: Dictionary = stage.validation_town_action_presentation_snapshot()
	var live_after: Dictionary = live_session.to_dict()
	var audio_records: Array = PresentationAudio.validation_records()
	var live_node_result := OverworldRules._find_resource_node_by_placement(live_session, placement_id)
	var live_node: Dictionary = live_node_result.get("node", {}) if live_node_result.get("node", {}) is Dictionary else {}
	var live_site := ContentService.get_resource_site(String(live_node.get("site_id", "")))
	var live_response := OverworldRules._resource_site_response_state(live_session, live_node, live_site)

	var reduced_motion := bool(mode.get("reduced_motion", false))
	var missing_asset := bool(mode.get("missing_asset", false))
	var expected_vfx := ["route_dispatch_badge"] if reduced_motion else ["vfx_placeholder_town_route_response"]
	var expected_draw_entries := ["route_dispatch_badge"] if reduced_motion else ["route_dispatch_art", "route_dispatch_badge"]
	var expected_draw_mode := "route_dispatch_badge" if reduced_motion else ("procedural_route_dispatch" if missing_asset else "imported_texture")
	var asset: Dictionary = active.get("vfx_asset", {}) if active.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = active.get("vfx_draw", {}) if active.get("vfx_draw", {}) is Dictionary else {}
	var audio_record: Dictionary = audio_records[0] if audio_records.size() == 1 and audio_records[0] is Dictionary else {}
	var audio_exact: bool = (
		audio_records.size() == 1
		and Array(active.get("audio_playback_records", [])) == audio_records
		and String(audio_record.get("cue_id", "")) == "audio_placeholder_town_route_response"
		and String(audio_record.get("source", "")) == "TownStageView.present_town_action"
		and String(Dictionary(audio_record.get("metadata", {})).get("event_id", "")) == "town_route_response_ordered"
		and int(Dictionary(audio_record.get("metadata", {})).get("presentation_serial", 0)) == 1
		and String(Dictionary(audio_record.get("metadata", {})).get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and bool(audio_record.get("played", false))
		and String(audio_record.get("playback_source", "")) == "imported_wav"
		and String(audio_record.get("asset_path", "")) == "res://art/audio/runtime/presentation/town_route_response.wav"
		and String(audio_record.get("role", "")) == "town_route_response_dispatched"
		and int(audio_record.get("duration_msec", 0)) == 380
		and int(audio_record.get("stream_mix_rate", 0)) == 44100
		and bool(audio_record.get("stream_stereo", false))
		and int(audio_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
	)
	var consequence_exact: bool = (
		bool(control_result.get("ok", false))
		and bool(public_result.get("ok", false))
		and String(public_result.get("lane", "")) == "response"
		and String(public_result.get("action_id", "")) == action_id
		and String(Dictionary(public_result.get("town_action_recap", {})).get("kind", "")) == "response"
		and live_after == control.to_dict()
		and live_node == control_node
		and live_response == control_response
		and bool(live_response.get("active", false))
		and String(live_node.get("response_origin", "")) == "town"
		and int(live_node.get("response_last_day", -1)) == live_session.day
	)
	var presentation_exact: bool = (
		bool(active.get("active", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "town_route_response_ordered"
		and String(active.get("cue_id", "")) == "cue_town_route_response_ordered"
		and String(active.get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and String(active.get("response_placement_id", "")) == placement_id
		and String(active.get("response_label", "")) == String(selected_action.get("label", ""))
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and String(active.get("selected_mode", "")) == ("reduced_motion" if reduced_motion else "normal")
		and String(active.get("selected_animation_state", "")) == ("route_dispatch_badge" if reduced_motion else "dispatch_confirmed")
		and String(active.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(active.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_town_route_response"]
		and Array(active.get("draw_entries", [])) == expected_draw_entries
		and not bool(active.get("blocks_input", true))
		and not blocker.visible
		and bool(active.get("draw_rect_contained", false))
		and String(draw.get("mode", "")) == expected_draw_mode
		and bool(asset.get("uses_imported_asset", false)) == (not reduced_motion and not missing_asset)
		and bool(asset.get("uses_procedural_fallback", false)) == (reduced_motion or missing_asset)
		and audio_exact
	)

	var serial := int(active.get("serial", 0))
	var authority_before_repeat: Dictionary = live_session.to_dict()
	var repeat_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	var after_repeat: Dictionary = stage.validation_town_action_presentation_snapshot()
	var repeat_silent: bool = (
		not bool(repeat_result.get("ok", true))
		and int(after_repeat.get("serial", 0)) == serial
		and live_session.to_dict() == authority_before_repeat
		and PresentationAudio.validation_records() == audio_records
	)
	var row := {
		"ok": malformed_fail_closed and consequence_exact and presentation_exact and repeat_silent and SessionDataScript.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"mode": String(mode.get("id", "")),
		"action_id": action_id,
		"placement_id": placement_id,
		"malformed_fail_closed": malformed_fail_closed,
		"consequence_exact": consequence_exact,
		"presentation_exact": presentation_exact,
		"audio_exact": audio_exact,
		"repeat_silent": repeat_silent,
		"response_active": bool(live_response.get("active", false)),
		"response_origin": String(live_node.get("response_origin", "")),
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["asset"] = asset
		row["draw"] = draw
		row["audio_records"] = audio_records
		row["public_result"] = public_result
		row["control_result"] = control_result
		row["repeat_result"] = repeat_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _first_enabled_site_response_action(session) -> Dictionary:
	for action_value in TownRules.get_response_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")).begins_with("site_response:") and not bool(action_value.get("disabled", true)):
			return action_value.duplicate(true)
	return {}

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
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

func _seed_route_response_fixture(session, town: Dictionary) -> void:
	var resource_nodes: Array = session.overworld.get("resource_nodes", []).duplicate(true)
	resource_nodes.append({
		"placement_id": "town_route_response_dispatch_fixture",
		"site_id": "site_brightwood_sawmill",
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"collected_by_faction_id": "player",
	})
	session.overworld["resource_nodes"] = resource_nodes
	var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	for resource_id in resources.keys():
		resources[resource_id] = maxi(999, int(resources.get(resource_id, 0)))
	session.overworld["resources"] = resources

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	PresentationAudio.validation_reset()
	return result

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
	elif expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(mini(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
	elif expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _fail(message: String, payload: Dictionary, original_window_size: Vector2i, original_reduced_motion: bool) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	push_error("TOWN_ROUTE_RESPONSE_DISPATCH_FEEDBACK_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
