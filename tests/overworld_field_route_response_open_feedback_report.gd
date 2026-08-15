extends Node

const REPORT_ID := "OVERWORLD_FIELD_ROUTE_RESPONSE_OPEN_FEEDBACK_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "rope_lift"
const SITE_ID := "site_rope_lift"
const SITE_TILE := Vector2i(9, 52)
const CLAIM_START_TILE := Vector2i(9, 50)
const HERO_TILE := Vector2i(9, 51)
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/route_open.png"
const AUDIO_PATH := "res://art/audio/runtime/presentation/route_open.wav"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_session = SessionState.active_session
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		SettingsService.set_reduced_motion_enabled(false)
		var row := await _run_case(viewport_size, "normal")
		rows.append(row)
		if not bool(row.get("ok", false)):
			await _finish(original_session, original_window_size, original_reduced_motion, "Normal route-open row failed", row)
			return
	SettingsService.set_reduced_motion_enabled(true)
	var reduced := await _run_case(Vector2i(1280, 720), "reduced")
	if not bool(reduced.get("ok", false)):
		await _finish(original_session, original_window_size, original_reduced_motion, "Reduced route-open row failed", reduced)
		return
	SettingsService.set_reduced_motion_enabled(false)
	var missing := await _run_case(Vector2i(1280, 720), "missing")
	if not bool(missing.get("ok", false)):
		await _finish(original_session, original_window_size, original_reduced_motion, "Missing route-open row failed", missing)
		return
	SessionState.set_active_session(original_session)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_rows": rows,
		"reduced": reduced,
		"missing": missing,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, mode: String) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = _response_ready_session()
	var resources_before: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var movement_before := int((session.overworld.get("movement", {}) as Dictionary).get("current", 0))
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view: Node = shell.get_node("%Map")
	if mode == "missing":
		map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	PresentationAudio.validation_reset()
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var cue := _cue_from_snapshot(snapshot)
	var resources_after: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var active_edges: Array = OverworldRules.active_linked_transit_edges(session)
	var consequence_checks := {
		"result_ok": bool(result.get("ok", false)),
		"action_exact": String(result.get("action_id", "")) == "site_response",
		"gold_exact": int(resources_before.get("gold", 0)) - int(resources_after.get("gold", 0)) == 130,
		"ore_exact": int(resources_before.get("ore", 0)) - int(resources_after.get("ore", 0)) == 1,
		"movement_exact": movement_before - int((session.overworld.get("movement", {}) as Dictionary).get("current", 0)) == 3,
		"edge_count_exact": active_edges.size() == 1,
	}
	var consequence_exact: bool = not consequence_checks.values().has(false)
	var presentation_exact := _presentation_exact(cue, mode)
	var authority_after: Dictionary = session.to_dict()
	var records_after: Array = PresentationAudio.validation_records().duplicate(true)
	var serial := int(cue.get("serial", 0))
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _cue_from_snapshot(shell.call("validation_snapshot"))
	var duplicate_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var duplicated := _cue_from_snapshot(shell.call("validation_snapshot"))
	var dedupe_exact: bool = int(refreshed.get("serial", -1)) == serial \
		and int(duplicated.get("serial", -1)) == serial \
		and PresentationAudio.validation_records() == records_after \
		and not bool(duplicate_result.get("ok", false)) \
		and session.to_dict() == authority_after
	var restored = SessionState.new_session_data()
	restored.from_dict(authority_after)
	var restored_edges: Array = OverworldRules.active_linked_transit_edges(restored)
	var save_checks := {
		"save_version_exact": restored.save_version == SessionState.SAVE_VERSION,
		"edge_count_exact": restored_edges.size() == 1,
	}
	var save_exact: bool = not save_checks.values().has(false)
	var map_rect: Rect2 = map_view.get_global_rect()
	var contained := get_viewport().get_visible_rect().encloses(map_rect)
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	var manifest_exact: bool = int(summary.get("mapped_cue_count", 0)) == 14 \
		and int(summary.get("unique_texture_count", 0)) == 14 \
		and "vfx_placeholder_route_open" in summary.get("mapped_cue_ids", [])
	var payload := {
		"ok": consequence_exact and presentation_exact and dedupe_exact and save_exact and contained and manifest_exact,
		"mode": mode,
		"viewport": [viewport_size.x, viewport_size.y],
		"consequence_exact": consequence_exact,
		"consequence_checks": consequence_checks,
		"result": result,
		"resource_delta": {
			"gold": int(resources_before.get("gold", 0)) - int(resources_after.get("gold", 0)),
			"ore": int(resources_before.get("ore", 0)) - int(resources_after.get("ore", 0)),
			"movement": movement_before - int((session.overworld.get("movement", {}) as Dictionary).get("current", 0)),
		},
		"active_edges": active_edges,
		"presentation_exact": presentation_exact,
		"dedupe_exact": dedupe_exact,
		"save_exact": save_exact,
		"save_checks": save_checks,
		"restored_edges": restored_edges,
		"contained": contained,
		"manifest_exact": manifest_exact,
		"cue": cue,
	}
	shell.queue_free()
	await get_tree().process_frame
	return payload

func _presentation_exact(cue: Dictionary, mode: String) -> bool:
	var asset: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = cue.get("vfx_draw", {}) if cue.get("vfx_draw", {}) is Dictionary else {}
	var records: Array = cue.get("audio_playback_records", []) if cue.get("audio_playback_records", []) is Array else []
	var audio: Dictionary = records[0] if records.size() == 1 and records[0] is Dictionary else {}
	var expected_draw := "route_open_icon" if mode == "reduced" else ("procedural_route_open_marker" if mode == "missing" else "imported_texture")
	var expected_vfx := ["route_open_icon"] if mode == "reduced" else ["vfx_placeholder_route_open"]
	return int(cue.get("serial", 0)) > 0 \
		and String(cue.get("event_id", "")) == "overworld_route_open" \
		and String(cue.get("family", "")) == "site_response" \
		and String(cue.get("placement_id", "")) == PLACEMENT_ID \
		and cue.get("tile", {}) == {"x": SITE_TILE.x, "y": SITE_TILE.y} \
		and cue.get("selected_vfx_cue_ids", []) == expected_vfx \
		and cue.get("selected_audio_cue_ids", []) == ["audio_placeholder_route_open"] \
		and String(draw.get("mode", "")) == expected_draw \
		and bool(asset.get("uses_imported_asset", false)) == (mode == "normal") \
		and bool(asset.get("uses_procedural_fallback", false)) == (mode != "normal") \
		and records.size() == 1 \
		and String(audio.get("cue_id", "")) == "audio_placeholder_route_open" \
		and String(audio.get("source", "")) == "OverworldMapView.route_open" \
		and String(audio.get("asset_path", "")) == AUDIO_PATH \
		and String(audio.get("playback_source", "")) == "imported_wav" \
		and int(audio.get("stream_mix_rate", 0)) == 44100 \
		and bool(audio.get("stream_stereo", false))

func _cue_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _response_ready_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_set_position(session, CLAIM_START_TILE)
	_set_movement(session, 20)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	OverworldRules.refresh_fog_of_war(session)
	var claim_result: Dictionary = OverworldRules.try_move_along_route(session, [CLAIM_START_TILE, HERO_TILE], 20)
	if not bool(claim_result.get("ok", false)) or OverworldRules.hero_position(session) != HERO_TILE:
		return session
	var resources: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	resources["gold"] = maxi(500, int(resources.get("gold", 0)))
	resources["ore"] = maxi(5, int(resources.get("ore", 0)))
	session.overworld["resources"] = resources
	_set_movement(session, 10)
	OverworldRules.refresh_fog_of_war(session)
	return session

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
