extends Node

const REPORT_ID := "OVERWORLD_OBJECT_RESOLUTION_CUE_PLAYBACK_REPORT"
const CAPTURE_ENV := "HEROES_OVERWORLD_OBJECT_RESOLUTION_CAPTURE"
const CAPTURE_DIR_ENV := "HEROES_OVERWORLD_OBJECT_RESOLUTION_CAPTURE_DIR"

var _evidence: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_reduced_motion: bool = SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(false)
	var ok := await _assert_persistent_resource_capture_playback()
	if ok:
		ok = await _assert_repeatable_service_visited_and_revisit()
	if ok:
		ok = await _assert_neutral_town_capture_playback()
	if ok:
		ok = await _assert_artifact_depletion_playback()
	if ok:
		SettingsService.set_reduced_motion_enabled(true)
		ok = await _assert_reduced_motion_capture_and_unsupported_noop()
	if ok and OS.get_environment(CAPTURE_ENV) == "1":
		SettingsService.set_reduced_motion_enabled(false)
		ok = await _capture_object_resolution_viewports()
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	if not ok:
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"evidence": _evidence, "ok": true})])
	get_tree().quit(0)

func _assert_persistent_resource_capture_playback() -> bool:
	var session = _session_with_map(7, 3, true)
	session.overworld["resource_nodes"] = [_wood_wagon_node("object_capture_wagon", Vector2i(4, 1))]
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Persistent resource fixture route was not reachable.", selection)
	var result: Dictionary = shell.call("validation_click_tile", 4, 1)
	var queued := _object_resolution(shell)
	var serial := int(queued.get("serial", 0))
	var cache_after_action := _render_cache(shell)
	var authority_after_action: Dictionary = session.to_dict()
	if (
		not bool(result.get("ok", false))
		or serial <= 0
		or bool(queued.get("active", true))
		or not bool(queued.get("queued", false))
		or String(queued.get("event_id", "")) != "overworld_object_captured"
		or String(queued.get("family", "")) != "resource_site"
		or String(queued.get("placement_id", "")) != "object_capture_wagon"
		or queued.get("tile", {}) != {"x": 4, "y": 1}
		or String(queued.get("animation_state", "")) != "ownership_capture"
		or String(queued.get("visual_policy", "")) != "authored_animation_state"
		or not bool(queued.get("allows_large_motion", false))
		or int(queued.get("duration_ms", 0)) != 620
		or float(queued.get("progress", -1.0)) != 0.0
	):
		return _fail("Persistent resource did not queue one exact captured cue behind route locomotion.", queued)
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed_queued := _object_resolution(shell)
	if int(refreshed_queued.get("serial", -1)) != serial or not bool(refreshed_queued.get("queued", false)) or float(refreshed_queued.get("progress", -1.0)) != 0.0:
		return _fail("Unrelated refresh replayed or consumed the queued captured cue.", refreshed_queued)
	await get_tree().create_timer(0.52).timeout
	var active := _object_resolution(shell)
	var cache_active := _render_cache(shell)
	var active_progress := float(active.get("progress", 0.0))
	if (
		not bool(active.get("active", false))
		or bool(active.get("queued", true))
		or active_progress <= 0.0
		or active_progress >= 1.0
		or int(cache_active.get("session_static_generation", -1)) != int(cache_after_action.get("session_static_generation", -2))
		or int(cache_active.get("state_generation", -1)) != int(cache_after_action.get("state_generation", -2))
		or int(cache_active.get("dynamic_generation", -1)) <= int(cache_after_action.get("dynamic_generation", -1))
		or session.to_dict() != authority_after_action
	):
		return _fail("Captured cue did not advance on only the dynamic layer with exact session authority.", {"queued": queued, "active": active})
	await get_tree().create_timer(0.68).timeout
	var settled := _object_resolution(shell)
	if bool(settled.get("active", true)) or bool(settled.get("queued", true)) or float(settled.get("progress", 0.0)) != 1.0 or session.to_dict() != authority_after_action:
		return _fail("Captured cue did not settle once without mutating authority.", settled)
	var node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	if not bool(node.get("collected", false)) or String(node.get("collected_by_faction_id", "")) != "player":
		return _fail("Persistent resource gameplay result was not retained.", node)
	_evidence["persistent_capture"] = {
		"serial": serial,
		"duration_ms": int(queued.get("duration_ms", 0)),
		"active_progress": active_progress,
		"dynamic_layer_only": true,
		"refresh_replayed": false,
	}
	shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_repeatable_service_visited_and_revisit() -> bool:
	var session = _session_with_map(5, 3, true)
	session.overworld["resource_nodes"] = [_repeatable_service_node("repeatable_infirmary", Vector2i(2, 1))]
	var starting_gold := int(session.overworld.get("resources", {}).get("gold", 0))
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 2)
	var selection: Dictionary = shell.call("validation_select_tile", 2, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Repeatable service fixture route was not reachable.", selection)
	var first_result: Dictionary = shell.call("validation_click_tile", 2, 1)
	var first_cue := _object_resolution(shell)
	var first_serial := int(first_cue.get("serial", 0))
	var first_viewport := _map_viewport(shell)
	var first_node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	if (
		not bool(first_result.get("ok", false))
		or first_serial <= 0
		or String(first_cue.get("event_id", "")) != "overworld_object_visited"
		or String(first_cue.get("animation_state", "")) != "visit_resolved"
		or String(first_cue.get("fallback_tag", "")) != ""
		or not bool(first_cue.get("queued", false))
		or int(first_cue.get("duration_ms", 0)) != 620
		or int(first_viewport.get("spatial_index", {}).get("resource_tiles", 0)) != 1
		or not bool(first_node.get("collected", false))
		or int(session.overworld.get("resources", {}).get("gold", 0)) != starting_gold - 120
	):
		return _fail("Repeatable service did not retain one exact visited cue and live map entry.", {"cue": first_cue, "viewport": first_viewport, "node": first_node})
	await get_tree().create_timer(1.2).timeout
	var authority_before_early_revisit: Dictionary = session.to_dict()
	var early_revisit: Dictionary = shell.call("validation_perform_context_action", "collect_resource")
	var after_early_cue := _object_resolution(shell)
	if (
		bool(early_revisit.get("ok", true))
		or "collect_resource" in early_revisit.get("context_action_ids", [])
		or int(after_early_cue.get("serial", -1)) != first_serial
		or bool(after_early_cue.get("active", true))
		or session.to_dict() != authority_before_early_revisit
	):
		return _fail("Repeatable service cooldown did not fail closed without a new cue or authority drift.", {"result": early_revisit, "cue": after_early_cue})
	var first_collected_day := int(first_node.get("collected_day", session.day))
	session.day = first_collected_day + 7
	SettingsService.set_reduced_motion_enabled(true)
	shell.call("_refresh")
	await get_tree().process_frame
	var authority_before_ready_revisit: Dictionary = session.to_dict()
	var ready_revisit: Dictionary = shell.call("validation_perform_context_action", "collect_resource")
	var revisit_cue := _object_resolution(shell)
	var revisit_viewport := _map_viewport(shell)
	var revisit_node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	SettingsService.set_reduced_motion_enabled(false)
	if (
		not bool(ready_revisit.get("ok", false))
		or int(revisit_cue.get("serial", 0)) != first_serial + 1
		or String(revisit_cue.get("event_id", "")) != "overworld_object_visited"
		or String(revisit_cue.get("animation_state", "")) != "visited_check_icon"
		or String(revisit_cue.get("visual_policy", "")) != "reduced_motion_fallback"
		or String(revisit_cue.get("fallback_tag", "")) != "visited_check_icon"
		or bool(revisit_cue.get("allows_large_motion", true))
		or int(revisit_cue.get("duration_ms", 0)) != 260
		or int(revisit_viewport.get("spatial_index", {}).get("resource_tiles", 0)) != 1
		or int(revisit_node.get("collected_day", 0)) != session.day
		or int(session.overworld.get("resources", {}).get("gold", 0)) != starting_gold - 240
		or session.to_dict() == authority_before_ready_revisit
	):
		return _fail("Ready repeatable service revisit did not publish the exact reduced-motion visited state.", {"result": ready_revisit, "cue": revisit_cue, "viewport": revisit_viewport, "node": revisit_node})
	_evidence["repeatable_service_visited"] = {
		"first_serial": first_serial,
		"revisit_serial": int(revisit_cue.get("serial", 0)),
		"cooldown_days": 7,
		"resource_tiles_after_visit": int(revisit_viewport.get("spatial_index", {}).get("resource_tiles", 0)),
		"reduced_motion_fallback": String(revisit_cue.get("fallback_tag", "")),
	}
	shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_neutral_town_capture_playback() -> bool:
	var session = _session_with_map(7, 3, true)
	session.overworld["towns"].append(_neutral_town("neutral_cue_town", Vector2i(4, 1)))
	var objective_authority_before := OverworldRules.describe_objectives(session)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Neutral-town capture fixture route was not reachable.", selection)
	var result: Dictionary = shell.call("validation_click_tile", 4, 1)
	var queued := _object_resolution(shell)
	var serial := int(queued.get("serial", 0))
	var captured_town := _town_by_placement(session, "neutral_cue_town")
	var authority_after_capture: Dictionary = session.to_dict()
	if (
		not bool(result.get("ok", false))
		or serial <= 0
		or String(queued.get("event_id", "")) != "overworld_object_captured"
		or String(queued.get("family", "")) != "town_capture"
		or String(queued.get("placement_id", "")) != "neutral_cue_town"
		or queued.get("tile", {}) != {"x": 4, "y": 1}
		or String(queued.get("animation_state", "")) != "ownership_capture"
		or not bool(queued.get("queued", false))
		or int(queued.get("duration_ms", 0)) != 620
		or String(captured_town.get("owner", "")) != "player"
		or OverworldRules.describe_objectives(session) != objective_authority_before
	):
		return _fail("Neutral-town result did not queue one exact captured cue with ownership authority.", {"cue": queued, "town": captured_town})
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _object_resolution(shell)
	if int(refreshed.get("serial", -1)) != serial or not bool(refreshed.get("queued", false)) or session.to_dict() != authority_after_capture:
		return _fail("Neutral-town captured cue replayed or changed authority during refresh.", refreshed)
	await get_tree().create_timer(0.52).timeout
	var active := _object_resolution(shell)
	var active_viewport := _map_viewport(shell)
	if (
		not bool(active.get("active", false))
		or bool(active.get("queued", true))
		or float(active.get("progress", 0.0)) <= 0.0
		or int(active_viewport.get("spatial_index", {}).get("town_tiles", 0)) != 2
		or session.to_dict() != authority_after_capture
	):
		return _fail("Neutral-town captured cue did not remain active over the retained town.", {"cue": active, "viewport": active_viewport})
	_evidence["neutral_town_capture"] = {
		"serial": serial,
		"placement_id": String(active.get("placement_id", "")),
		"town_tiles": int(active_viewport.get("spatial_index", {}).get("town_tiles", 0)),
		"owner": String(captured_town.get("owner", "")),
	}
	shell.queue_free()
	await get_tree().process_frame

	SettingsService.set_reduced_motion_enabled(true)
	var reduced_session = _session_with_map(5, 3, true)
	reduced_session.overworld["towns"].append(_neutral_town("reduced_neutral_town", Vector2i(2, 1)))
	var reduced_opened := await _open_shell(reduced_session)
	var reduced_shell: Node = reduced_opened.get("shell", null)
	reduced_session = reduced_opened.get("session", reduced_session)
	_prepare_shell_state(reduced_shell, reduced_session, Vector2i(1, 1), 1)
	var reduced_selection: Dictionary = reduced_shell.call("validation_select_tile", 2, 1)
	if String(reduced_selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		SettingsService.set_reduced_motion_enabled(false)
		return _fail("Reduced neutral-town capture fixture route was not reachable.", reduced_selection)
	var reduced_result: Dictionary = reduced_shell.call("validation_click_tile", 2, 1)
	var reduced_cue := _object_resolution(reduced_shell)
	SettingsService.set_reduced_motion_enabled(false)
	if (
		not bool(reduced_result.get("ok", false))
		or not bool(reduced_cue.get("active", false))
		or bool(reduced_cue.get("queued", true))
		or String(reduced_cue.get("family", "")) != "town_capture"
		or String(reduced_cue.get("fallback_tag", "")) != "ownership_badge_swap"
		or String(reduced_cue.get("visual_policy", "")) != "reduced_motion_fallback"
		or bool(reduced_cue.get("allows_large_motion", true))
		or int(reduced_cue.get("duration_ms", 0)) != 260
		or String(_town_by_placement(reduced_session, "reduced_neutral_town").get("owner", "")) != "player"
	):
		return _fail("Reduced neutral-town capture did not use the exact ownership badge fallback.", reduced_cue)
	_evidence["reduced_neutral_town_capture"] = {
		"serial": int(reduced_cue.get("serial", 0)),
		"fallback_tag": String(reduced_cue.get("fallback_tag", "")),
		"duration_ms": int(reduced_cue.get("duration_ms", 0)),
	}
	reduced_shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_artifact_depletion_playback() -> bool:
	var session = _session_with_map(6, 3, true)
	session.overworld["artifact_nodes"] = [{
		"placement_id": "object_depleted_artifact",
		"artifact_id": "artifact_bastion_gorget",
		"x": 3,
		"y": 1,
		"collected": false,
	}]
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 3)
	var selection: Dictionary = shell.call("validation_select_tile", 3, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Artifact fixture route was not reachable.", selection)
	var result: Dictionary = shell.call("validation_click_tile", 3, 1)
	var queued := _object_resolution(shell)
	var serial := int(queued.get("serial", 0))
	var authority_after_action: Dictionary = session.to_dict()
	if (
		not bool(result.get("ok", false))
		or serial <= 0
		or String(queued.get("event_id", "")) != "overworld_object_depleted"
		or String(queued.get("family", "")) != "artifact"
		or String(queued.get("placement_id", "")) != "object_depleted_artifact"
		or queued.get("tile", {}) != {"x": 3, "y": 1}
		or String(queued.get("animation_state", "")) != "depleted_remove_or_dim"
		or not bool(queued.get("queued", false))
	):
		return _fail("Artifact result did not queue one exact depleted cue.", queued)
	await get_tree().create_timer(0.44).timeout
	var active := _object_resolution(shell)
	if not bool(active.get("active", false)) or float(active.get("progress", 0.0)) <= 0.0 or session.to_dict() != authority_after_action:
		return _fail("Artifact depleted cue did not remain visible after the object left the state index.", active)
	var artifact: Dictionary = session.overworld.get("artifact_nodes", [])[0]
	if not bool(artifact.get("collected", false)):
		return _fail("Artifact gameplay result was not retained.", artifact)
	_evidence["artifact_depleted"] = {
		"serial": serial,
		"placement_id": String(active.get("placement_id", "")),
		"active_after_object_removal": true,
	}
	shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_reduced_motion_capture_and_unsupported_noop() -> bool:
	var session = _session_with_map(6, 3, true)
	session.overworld["resource_nodes"] = [_wood_wagon_node("reduced_capture_wagon", Vector2i(2, 1))]
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(1, 1), 2)
	var selection: Dictionary = shell.call("validation_select_tile", 2, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Reduced-motion fixture route was not reachable.", selection)
	var result: Dictionary = shell.call("validation_click_tile", 2, 1)
	var active := _object_resolution(shell)
	var serial := int(active.get("serial", 0))
	var authority_after_action: Dictionary = session.to_dict()
	if (
		not bool(result.get("ok", false))
		or serial <= 0
		or not bool(active.get("active", false))
		or bool(active.get("queued", true))
		or bool(active.get("allows_large_motion", true))
		or String(active.get("visual_policy", "")) != "reduced_motion_fallback"
		or String(active.get("fallback_tag", "")) != "ownership_badge_swap"
		or int(active.get("duration_ms", 0)) != 260
		or float(active.get("progress", -1.0)) != 0.0
	):
		return _fail("Reduced motion did not select the exact static ownership badge fallback.", active)
	await get_tree().create_timer(0.30).timeout
	var settled := _object_resolution(shell)
	if bool(settled.get("active", true)) or float(settled.get("progress", 0.0)) != 1.0 or session.to_dict() != authority_after_action:
		return _fail("Reduced-motion object cue did not settle without authority drift.", settled)
	_set_active_hero_movement(session, 1)
	shell.call("_refresh")
	var open_selection: Dictionary = shell.call("validation_select_tile", 3, 1)
	if String(open_selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Unsupported open-move control was not reachable.", open_selection)
	var open_result: Dictionary = shell.call("validation_click_tile", 3, 1)
	var unchanged := _object_resolution(shell)
	if not bool(open_result.get("ok", false)) or int(unchanged.get("serial", -1)) != serial or bool(unchanged.get("active", true)):
		return _fail("A successful open move incorrectly issued or replayed an object-result cue.", unchanged)
	_evidence["reduced_motion_capture"] = {
		"serial": serial,
		"fallback_tag": String(active.get("fallback_tag", "")),
		"duration_ms": int(active.get("duration_ms", 0)),
		"unsupported_open_move_noop": true,
	}
	shell.queue_free()
	await get_tree().process_frame
	return true

func _capture_object_resolution_viewports() -> bool:
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir == "":
		capture_dir = "user://object_resolution_captures"
	var absolute_capture_dir := ProjectSettings.globalize_path(capture_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_capture_dir)
	if mkdir_error != OK:
		return _fail("Could not create the object-resolution capture directory.", {"path": absolute_capture_dir, "error": mkdir_error})
	var original_window_size := get_window().size
	var captures := {}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != viewport_size:
			get_window().size = original_window_size
			return _fail("Object-resolution capture did not reach the requested viewport.", {"requested": str(viewport_size), "actual": str(get_window().size)})
		var session = _session_with_map(9, 5, true)
		session.overworld["resource_nodes"] = [_wood_wagon_node("capture_wagon", Vector2i(5, 2))]
		var opened := await _open_shell(session)
		var shell: Node = opened.get("shell", null)
		session = opened.get("session", session)
		_prepare_shell_state(shell, session, Vector2i(1, 2), 4)
		var selection: Dictionary = shell.call("validation_select_tile", 5, 2)
		if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Capture fixture route was not reachable.", selection)
		var result: Dictionary = shell.call("validation_click_tile", 5, 2)
		await get_tree().create_timer(0.58).timeout
		var presentation := _object_resolution(shell)
		if not bool(result.get("ok", false)) or not bool(presentation.get("active", false)) or float(presentation.get("progress", 0.0)) <= 0.0:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Capture fixture did not observe the live captured cue.", presentation)
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		if image == null or image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Object-resolution capture returned the wrong image dimensions.", {"requested": str(viewport_size)})
		var capture_path := absolute_capture_dir.path_join("overworld_object_resolution_%dx%d.png" % [viewport_size.x, viewport_size.y])
		var save_error := image.save_png(capture_path)
		if save_error != OK:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Object-resolution capture could not save the image.", {"path": capture_path, "error": save_error})
		captures["%dx%d" % [viewport_size.x, viewport_size.y]] = {
			"path": capture_path,
			"event_id": String(presentation.get("event_id", "")),
			"progress": float(presentation.get("progress", 0.0)),
		}
		shell.queue_free()
		await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	_evidence["windowed_object_resolution"] = captures
	return true

func _wood_wagon_node(placement_id: String, tile: Vector2i) -> Dictionary:
	return {
		"placement_id": placement_id,
		"site_id": "site_wood_wagon",
		"x": tile.x,
		"y": tile.y,
		"collected": false,
		"collected_by_faction_id": "",
	}

func _repeatable_service_node(placement_id: String, tile: Vector2i) -> Dictionary:
	return {
		"placement_id": placement_id,
		"site_id": "site_wayfarer_infirmary",
		"x": tile.x,
		"y": tile.y,
		"collected": false,
		"collected_by_faction_id": "",
	}

func _neutral_town(placement_id: String, tile: Vector2i) -> Dictionary:
	return {
		"placement_id": placement_id,
		"town_id": "town_duskfen",
		"x": tile.x,
		"y": tile.y,
		"owner": "neutral",
		"controlling_faction_id": "",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _map_viewport(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	return snapshot.get("map_viewport", {}).duplicate(true) if snapshot.get("map_viewport", {}) is Dictionary else {}

func _render_cache(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("render_cache", {}).duplicate(true) if viewport.get("render_cache", {}) is Dictionary else {}

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _session_with_map(width: int, height: int, corridor: bool = false):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(height):
		var row := []
		for _x in range(width):
			row.append("water" if corridor and y != 1 and height == 3 else "grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{"placement_id": "riverwatch_hold", "town_id": "town_riverwatch", "x": 0, "y": 0, "owner": "player"}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
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
	hero["level"] = 1
	hero["experience"] = 0
	hero["specialties"] = []
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["base_movement"] = movement_points
			entry["level"] = 1
			entry["experience"] = 0
			entry["specialties"] = []
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _fail(message: String, payload: Dictionary = {}) -> bool:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
