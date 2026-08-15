extends Node

const REPORT_ID := "OVERWORLD_ROUTE_EXPIRY_FEEDBACK_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "rope_lift"
const CLAIM_START_TILE := Vector2i(9, 50)
const HERO_TILE := Vector2i(9, 51)
const OBSERVER_TILE := Vector2i(11, 52)
const SITE_TILE := Vector2i(9, 52)
const AUDIO_PATH := "res://art/audio/runtime/presentation/route_closed.wav"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_session = SessionState.active_session
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(false)
	var rows := []
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var row := await _run_expiry_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			await _finish(original_session, original_window_size, original_reduced_motion, "Live route-expiry row failed", row)
			return
	var controls := await _run_silence_controls()
	if not bool(controls.get("ok", false)):
		await _finish(original_session, original_window_size, original_reduced_motion, "Route-expiry silence controls failed", controls)
		return
	SessionState.set_active_session(original_session)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"rows": rows,
		"controls": controls,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _run_expiry_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var fixture := _final_day_route_session()
	var session = fixture.get("session")
	var response_result: Dictionary = fixture.get("response_result", {})
	var node_before := _resource_node(session)
	var day_before := int(session.day)
	var provenance_before := _response_provenance(node_before)
	var edges_before: Array = OverworldRules.active_linked_transit_edges(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_set_end_turn_resolution_routing_enabled", false)
	var candidates_before: Array = shell.call("_active_route_expiry_candidates")
	PresentationAudio.validation_reset()
	var end_result: Dictionary = shell.call("validation_end_turn")
	await get_tree().process_frame
	var end_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var cue := _cue_from_snapshot(snapshot)
	var raw_presentation: Dictionary = shell.get("_object_resolution_presentation").duplicate(true)
	var node_after := _resource_node(session)
	var edges_after: Array = OverworldRules.active_linked_transit_edges(session)
	var rule_result: Dictionary = end_snapshot.get("last_rule_result", {}) if end_snapshot.get("last_rule_result", {}) is Dictionary else {}
	var events: Array = rule_result.get("enemy_activity_events", []) if rule_result.get("enemy_activity_events", []) is Array else []
	var checks := {
		"response_ok": bool(response_result.get("ok", false)),
		"candidate_exact": candidates_before.size() == 1 and String((candidates_before[0] as Dictionary).get("placement_id", "")) == PLACEMENT_ID,
		"edge_before_exact": edges_before.size() == 1 and String((edges_before[0] as Dictionary).get("placement_id", "")) == PLACEMENT_ID,
		"end_ok": bool(end_result.get("ok", false)),
		"committed": int(end_snapshot.get("commit_count", 0)) == 1 and int(end_snapshot.get("rules_end_turn_call_count", 0)) == 1,
		"autosave_exact": int(end_snapshot.get("autosave_call_count", 0)) == 1 and int(end_snapshot.get("autosave_failure_count", 0)) == 0,
		"not_routed": int(end_snapshot.get("resolution_attempt_count", 0)) == 0 and (end_snapshot.get("last_resolution_route", {}) as Dictionary).is_empty(),
		"day_advanced": int(session.day) == day_before + 1,
		"controller_preserved": String(node_after.get("collected_by_faction_id", "")) == "player",
		"provenance_preserved": _response_provenance(node_after) == provenance_before,
		"response_inactive": not bool(OverworldRules._resource_site_response_state(session, node_after, ContentService.get_resource_site(String(node_after.get("site_id", "")))).get("active", true)),
		"edge_after_absent": edges_after.is_empty(),
		"enemy_closure_absent": _route_closed_event(events).is_empty(),
		"expiry_identity": String(raw_presentation.get("closure_reason", "")) == "natural_expiry",
		"presentation_exact": _presentation_exact(cue),
	}
	var records_after: Array = PresentationAudio.validation_records().duplicate(true)
	var serial_after := int(cue.get("serial", 0))
	shell.call("_record_route_expiry_presentation", candidates_before)
	shell.call("_refresh")
	await get_tree().process_frame
	var repeated := _cue_from_snapshot(shell.call("validation_snapshot"))
	checks["dedupe_exact"] = int(repeated.get("serial", -1)) == serial_after and PresentationAudio.validation_records() == records_after
	var saved: Dictionary = session.to_dict()
	var restored = SessionState.new_session_data()
	restored.from_dict(saved)
	checks["save_exact"] = restored.save_version == SessionState.SAVE_VERSION \
		and _response_provenance(_resource_node(restored)) == provenance_before \
		and OverworldRules.active_linked_transit_edges(restored).is_empty()
	var payload := {
		"ok": not checks.values().has(false),
		"viewport": [viewport_size.x, viewport_size.y],
		"checks": checks,
		"provenance": provenance_before,
		"edges_before": edges_before,
		"edges_after": edges_after,
		"cue": cue,
	}
	shell.queue_free()
	await get_tree().process_frame
	return payload

func _run_silence_controls() -> Dictionary:
	var fixture := _final_day_route_session()
	var session = fixture.get("session")
	var node := _resource_node(session)
	var nodes: Array = (session.overworld.get("resource_nodes", []) as Array).duplicate(true)
	var node_index := _resource_node_index(session)
	node["response_until_day"] = int(session.day) + 1
	nodes[node_index] = node
	session.overworld["resource_nodes"] = nodes
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var non_final_candidates: Array = shell.call("_active_route_expiry_candidates")
	node = _resource_node(session)
	nodes = (session.overworld.get("resource_nodes", []) as Array).duplicate(true)
	node["response_until_day"] = int(session.day) - 1
	nodes[_resource_node_index(session)] = node
	session.overworld["resource_nodes"] = nodes
	var expired_candidates: Array = shell.call("_active_route_expiry_candidates")
	var serial_before: int = int(shell.get("_object_resolution_presentation_serial"))
	shell.call("_record_route_expiry_presentation", [{"placement_id": PLACEMENT_ID}])
	var malformed_silent: bool = int(shell.get("_object_resolution_presentation_serial")) == serial_before
	var result := {
		"ok": non_final_candidates.is_empty() and expired_candidates.is_empty() and malformed_silent,
		"non_final_silent": non_final_candidates.is_empty(),
		"already_expired_silent": expired_candidates.is_empty(),
		"malformed_silent": malformed_silent,
	}
	shell.queue_free()
	await get_tree().process_frame
	return result

func _presentation_exact(cue: Dictionary) -> bool:
	var asset: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = cue.get("vfx_draw", {}) if cue.get("vfx_draw", {}) is Dictionary else {}
	var records: Array = cue.get("audio_playback_records", []) if cue.get("audio_playback_records", []) is Array else []
	var audio: Dictionary = records[0] if records.size() == 1 and records[0] is Dictionary else {}
	return int(cue.get("serial", 0)) > 0 \
		and String(cue.get("event_id", "")) == "overworld_route_closed" \
		and String(cue.get("family", "")) == "route_closure" \
		and String(cue.get("placement_id", "")) == PLACEMENT_ID \
		and cue.get("tile", {}) == {"x": SITE_TILE.x, "y": SITE_TILE.y} \
		and cue.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_route_closed"] \
		and cue.get("selected_audio_cue_ids", []) == ["audio_placeholder_route_closed"] \
		and String(draw.get("mode", "")) == "imported_texture" \
		and bool(asset.get("uses_imported_asset", false)) \
		and records.size() == 1 \
		and String(audio.get("source", "")) == "OverworldMapView.route_closed" \
		and String(audio.get("asset_path", "")) == AUDIO_PATH \
		and int(audio.get("stream_mix_rate", 0)) == 44100 \
		and bool(audio.get("stream_stereo", false))

func _final_day_route_session() -> Dictionary:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_set_position(session, CLAIM_START_TILE)
	_set_movement(session, 20)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	OverworldRules.refresh_fog_of_war(session)
	var claim_result: Dictionary = OverworldRules.try_move_along_route(session, [CLAIM_START_TILE, HERO_TILE], 20)
	if not bool(claim_result.get("ok", false)):
		return {"session": session, "response_result": claim_result}
	var resources: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	resources["gold"] = maxi(500, int(resources.get("gold", 0)))
	resources["ore"] = maxi(5, int(resources.get("ore", 0)))
	session.overworld["resources"] = resources
	_set_movement(session, 10)
	var response_result: Dictionary = OverworldRules.perform_context_action(session, "site_response")
	var nodes: Array = (session.overworld.get("resource_nodes", []) as Array).duplicate(true)
	var node_index := _resource_node_index(session)
	var node: Dictionary = nodes[node_index]
	node["response_until_day"] = int(session.day)
	nodes[node_index] = node
	session.overworld["resource_nodes"] = nodes
	_set_position(session, OBSERVER_TILE)
	_set_movement(session, 10)
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session, "response_result": response_result}

func _response_provenance(node: Dictionary) -> Dictionary:
	return {
		"response_last_day": int(node.get("response_last_day", 0)),
		"response_until_day": int(node.get("response_until_day", 0)),
		"response_origin": String(node.get("response_origin", "")),
		"response_commander_id": String(node.get("response_commander_id", "")),
		"response_security_rating": int(node.get("response_security_rating", 0)),
	}

func _route_closed_event(events: Array) -> Dictionary:
	for event_value in events:
		if event_value is Dictionary and "route_closed" in ((event_value as Dictionary).get("reason_codes", []) as Array):
			return (event_value as Dictionary).duplicate(true)
	return {}

func _cue_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _resource_node(session) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == PLACEMENT_ID:
			return node_value
	return {}

func _resource_node_index(session) -> int:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String((nodes[index] as Dictionary).get("placement_id", "")) == PLACEMENT_ID:
			return index
	return -1

func _set_position(session, tile: Vector2i) -> void:
	OverworldRules._set_active_hero_position(session, tile)

func _set_movement(session, points: int) -> void:
	var movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	movement["current"] = points
	movement["max"] = maxi(points, int(movement.get("max", 0)))
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero

func _finish(original_session, original_window_size: Vector2i, original_reduced_motion: bool, message: String, payload: Dictionary) -> void:
	SessionState.set_active_session(original_session)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
