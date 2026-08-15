extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const END_TILE := Vector2i(4, 1)
const ROUTE_TILES := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), END_TILE]
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/hero_route_step.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld hero route-step VFX row failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_HERO_ROUTE_STEP_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_imported_rows": 2,
		"missing_asset_fallback_rows": 2,
		"reduced_motion_rows": 2,
		"save_version": SessionStateStore.SAVE_VERSION,
		"rows": rows,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	PresentationAudio.validation_reset()
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = _movement_session()
	var authority_before: Dictionary = session.to_dict()
	var map_size := OverworldRules.derive_map_size(session)
	var map_view: Control = MapViewScript.new()
	map_view.size = Vector2(viewport_size)
	add_child(map_view)
	await get_tree().process_frame

	_set_state(map_view, session, map_size, _presentation(1, false))
	await get_tree().process_frame
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	var imported: Dictionary = map_view.call("validation_hero_movement_presentation")
	if not _summary_exact(summary) or not _imported_exact(imported, map_view.size) or not _audio_exact(imported, 1):
		return await _finish(map_view, {"ok": false, "failure": "imported", "summary": summary, "actual": imported})

	map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	_set_state(map_view, session, map_size, _presentation(2, false))
	await get_tree().process_frame
	var missing: Dictionary = map_view.call("validation_hero_movement_presentation")
	if not _fallback_exact(missing) or not _audio_exact(missing, 2):
		return await _finish(map_view, {"ok": false, "failure": "missing_fallback", "actual": missing})

	map_view.set("_overworld_vfx_texture_missing", {})
	_set_state(map_view, session, map_size, _presentation(3, true))
	await get_tree().process_frame
	var reduced: Dictionary = map_view.call("validation_hero_movement_presentation")
	_set_state(map_view, session, map_size, _presentation(3, true))
	await get_tree().process_frame
	var duplicate: Dictionary = map_view.call("validation_hero_movement_presentation")
	var authority_exact: bool = session.to_dict() == authority_before
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(map_view.get_global_rect())
	return await _finish(map_view, {
		"ok": _reduced_exact(reduced) and _audio_exact(reduced, 3) and duplicate == reduced and PresentationAudio.validation_records().size() == 3 and authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"asset_summary": summary,
		"imported": imported,
		"missing": missing,
		"reduced": reduced,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	})

func _movement_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var position := {"x": END_TILE.x, "y": END_TILE.y}
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
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

func _set_state(map_view: Control, session, map_size: Vector2i, movement: Dictionary) -> void:
	map_view.call("set_map_state", session, session.overworld.get("map", []), map_size, END_TILE, {}, movement)

func _presentation(serial: int, reduced_motion: bool) -> Dictionary:
	var route_payloads: Array = []
	for tile in ROUTE_TILES:
		route_payloads.append({"x": tile.x, "y": tile.y})
	return {
		"serial": serial,
		"event_id": "overworld_hero_move",
		"route_tiles": route_payloads,
		"route_step_count": 4,
		"selected_animation_state": "route_endpoint_snap" if reduced_motion else "map_step",
		"selected_visual_policy": "reduced_motion_fallback" if reduced_motion else "authored_animation_state",
		"selected_fallback_tag": "route_endpoint_snap" if reduced_motion else "",
		"selected_vfx_cue_ids": ["route_endpoint_snap"] if reduced_motion else ["vfx_placeholder_route_step"],
		"selected_audio_cue_ids": ["audio_placeholder_map_step"],
		"allows_large_motion": not reduced_motion,
		"duration_ms": 0 if reduced_motion else 440,
		"max_duration_ms": 700,
	}

func _audio_exact(snapshot: Dictionary, record_count: int) -> bool:
	var records: Array = snapshot.get("audio_playback_records", []) if snapshot.get("audio_playback_records", []) is Array else []
	var record: Dictionary = records[0] if records.size() == 1 and records[0] is Dictionary else {}
	return records.size() == 1 and String(record.get("cue_id", "")) == "audio_placeholder_map_step" and String(record.get("asset_path", "")) == "res://art/audio/runtime/presentation/map_step.wav" and String(record.get("source", "")) == "OverworldMapView.hero_movement" and String(record.get("role", "")) == "overworld_route_moved" and String(record.get("playback_source", "")) == "imported_wav" and bool(record.get("played", false)) and int(record.get("stream_mix_rate", 0)) == 44100 and bool(record.get("stream_stereo", false)) and int(record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED and PresentationAudio.validation_records().size() == record_count

func _imported_exact(snapshot: Dictionary, view_size: Vector2) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var center_payload: Dictionary = draw.get("center", {}) if draw.get("center", {}) is Dictionary else {}
	var center := Vector2(float(center_payload.get("x", -1.0)), float(center_payload.get("y", -1.0)))
	return bool(snapshot.get("active", false)) \
		and int(snapshot.get("route_step_count", 0)) == 4 \
		and snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_route_step"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_interpolation_fallback", true)) \
		and String(asset.get("texture_path", "")) == TEXTURE_PATH \
		and String(draw.get("mode", "")) == "imported_texture_behind_hero" \
		and String(draw.get("texture_path", "")) == TEXTURE_PATH \
		and Rect2(Vector2.ZERO, view_size).has_point(center) \
		and float(draw.get("extent", 0.0)) > 0.0 \
		and int(snapshot.get("duration_ms", 0)) == 440 \
		and not bool(snapshot.get("reduced_motion", true))

func _fallback_exact(snapshot: Dictionary) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	return bool(snapshot.get("active", false)) \
		and bool(asset.get("uses_interpolation_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_interpolated_hero_marker_only" \
		and String(draw.get("mode", "")) == "existing_interpolated_hero_marker_only" \
		and String(draw.get("texture_path", "missing")) == ""

func _reduced_exact(snapshot: Dictionary) -> bool:
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	return not bool(snapshot.get("active", true)) \
		and bool(snapshot.get("reduced_motion", false)) \
		and String(snapshot.get("animation_state", "")) == "route_endpoint_snap" \
		and String(snapshot.get("visual_policy", "")) == "reduced_motion_fallback" \
		and snapshot.get("selected_vfx_cue_ids", []) == ["route_endpoint_snap"] \
		and int(snapshot.get("duration_ms", -1)) == 0 \
		and String(draw.get("mode", "")) == "route_endpoint_snap" \
		and String(draw.get("texture_path", "missing")) == ""

func _summary_exact(summary: Dictionary) -> bool:
	return int(summary.get("mapped_cue_count", 0)) == 12 \
		and summary.get("mapped_cue_ids", []) == ["vfx_placeholder_adventure_spell", "vfx_placeholder_artifact_claim", "vfx_placeholder_blocked_route_marker", "vfx_placeholder_capture_flag", "vfx_placeholder_depleted_dim", "vfx_placeholder_guard_warning", "vfx_placeholder_object_focus_ring", "vfx_placeholder_object_visit", "vfx_placeholder_resource_delta", "vfx_placeholder_route_step", "vfx_placeholder_slot_equip", "vfx_placeholder_slot_unequip"] \
		and int(summary.get("unique_texture_count", 0)) == 12 \
		and int(summary.get("loaded_texture_count", 0)) == 12 \
		and summary.get("missing_texture_paths", []) == []

func _finish(map_view: Control, result: Dictionary) -> Dictionary:
	if map_view != null and is_instance_valid(map_view):
		map_view.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("OVERWORLD_HERO_ROUTE_STEP_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
