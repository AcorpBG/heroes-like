extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TILE := Vector2i(3, 2)
const EXPECTED_CUES := {
	"overworld_object_captured": {
		"cue_id": "vfx_placeholder_capture_flag",
		"fallback_cue_id": "ownership_badge_swap",
		"family": "town_capture",
		"animation_state": "ownership_capture",
		"texture_path": "res://art/overworld/runtime/vfx/object_resolution/captured.png",
	},
	"overworld_object_visited": {
		"cue_id": "vfx_placeholder_object_visit",
		"fallback_cue_id": "visited_check_icon",
		"family": "resource_site",
		"animation_state": "repeatable_service_visit",
		"texture_path": "res://art/overworld/runtime/vfx/object_resolution/visited.png",
	},
	"overworld_object_depleted": {
		"cue_id": "vfx_placeholder_depleted_dim",
		"fallback_cue_id": "depleted_static_dim",
		"family": "artifact",
		"animation_state": "object_depleted",
		"texture_path": "res://art/overworld/runtime/vfx/object_resolution/depleted.png",
	},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Object-resolution VFX viewport failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_OBJECT_RESOLUTION_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"events": EXPECTED_CUES.keys(),
		"normal_imported_rows": 6,
		"missing_asset_fallback_rows": 6,
		"reduced_motion_fallback_rows": 6,
		"save_version": SessionStateStore.SAVE_VERSION,
		"rows": rows,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = _session_with_map(8, 6)
	var authority_before: Dictionary = session.to_dict()
	var map_view: Control = MapViewScript.new()
	map_view.size = Vector2(viewport_size)
	add_child(map_view)
	await get_tree().process_frame
	var asset_summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	if not _asset_summary_exact(asset_summary):
		return await _finish_viewport(map_view, {"ok": false, "failure": "asset_summary", "actual": asset_summary})

	var serial := 1000
	var normal_rows: Array = []
	for event_id_value in EXPECTED_CUES:
		var event_id := String(event_id_value)
		serial += 1
		var presentation := _presentation(event_id, serial, false)
		map_view.call("set_map_state", session, session.overworld.get("map", []), Vector2i(8, 6), TILE, {}, {}, presentation)
		await get_tree().process_frame
		var snapshot: Dictionary = map_view.call("validation_object_resolution_presentation")
		var row := _normal_row(event_id, snapshot, map_view.size)
		normal_rows.append(row)
		if not bool(row.get("exact", false)):
			return await _finish_viewport(map_view, {"ok": false, "failure": "normal_imported", "event_id": event_id, "actual": snapshot})

	var missing_paths: Dictionary = {}
	for event_id_value in EXPECTED_CUES:
		var event_id := String(event_id_value)
		missing_paths[String(EXPECTED_CUES[event_id].get("texture_path", ""))] = true
	map_view.set("_overworld_vfx_texture_missing", missing_paths)
	var fallback_rows: Array = []
	for event_id_value in EXPECTED_CUES:
		var event_id := String(event_id_value)
		serial += 1
		map_view.call("set_map_state", session, session.overworld.get("map", []), Vector2i(8, 6), TILE, {}, {}, _presentation(event_id, serial, false))
		await get_tree().process_frame
		var snapshot: Dictionary = map_view.call("validation_object_resolution_presentation")
		var row := _fallback_row(event_id, snapshot, false)
		fallback_rows.append(row)
		if not bool(row.get("exact", false)):
			return await _finish_viewport(map_view, {"ok": false, "failure": "missing_asset_fallback", "event_id": event_id, "actual": snapshot})

	map_view.set("_overworld_vfx_texture_missing", {})
	var reduced_rows: Array = []
	for event_id_value in EXPECTED_CUES:
		var event_id := String(event_id_value)
		serial += 1
		map_view.call("set_map_state", session, session.overworld.get("map", []), Vector2i(8, 6), TILE, {}, {}, _presentation(event_id, serial, true))
		await get_tree().process_frame
		var snapshot: Dictionary = map_view.call("validation_object_resolution_presentation")
		var row := _fallback_row(event_id, snapshot, true)
		reduced_rows.append(row)
		if not bool(row.get("exact", false)):
			return await _finish_viewport(map_view, {"ok": false, "failure": "reduced_motion_fallback", "event_id": event_id, "actual": snapshot})

	var authority_exact: bool = session.to_dict() == authority_before
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(map_view.get_global_rect())
	return await _finish_viewport(map_view, {
		"ok": authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"normal_rows": normal_rows,
		"missing_asset_fallback_rows": fallback_rows,
		"reduced_motion_fallback_rows": reduced_rows,
		"asset_summary": asset_summary,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
		"save_version": SessionStateStore.SAVE_VERSION,
	})

func _presentation(event_id: String, serial: int, reduced_motion: bool) -> Dictionary:
	var expected: Dictionary = EXPECTED_CUES.get(event_id, {})
	return {
		"serial": serial,
		"event_id": event_id,
		"selected_animation_state": String(expected.get("animation_state", "")),
		"selected_visual_policy": "reduced_motion_fallback" if reduced_motion else "authored_animation_state",
		"selected_fallback_tag": String(expected.get("fallback_cue_id", "")) if reduced_motion else "",
		"selected_vfx_cue_ids": [String(expected.get("fallback_cue_id", ""))] if reduced_motion else [String(expected.get("cue_id", ""))],
		"allows_large_motion": not reduced_motion,
		"family": String(expected.get("family", "")),
		"placement_id": "object_resolution_vfx_fixture:%s" % event_id,
		"tile": {"x": TILE.x, "y": TILE.y},
		"duration_ms": 700,
	}

func _normal_row(event_id: String, snapshot: Dictionary, view_size: Vector2) -> Dictionary:
	var expected: Dictionary = EXPECTED_CUES.get(event_id, {})
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var draw_payload: Dictionary = draw.get("rect", {}) if draw.get("rect", {}) is Dictionary else {}
	var draw_rect := Rect2(
		Vector2(float(draw_payload.get("x", -1.0)), float(draw_payload.get("y", -1.0))),
		Vector2(float(draw_payload.get("width", 0.0)), float(draw_payload.get("height", 0.0)))
	)
	var exact: bool = String(snapshot.get("event_id", "")) == event_id \
		and snapshot.get("tile", {}) == {"x": TILE.x, "y": TILE.y} \
		and snapshot.get("selected_vfx_cue_ids", []) == [String(expected.get("cue_id", ""))] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_procedural_fallback", true)) \
		and bool(asset.get("texture_loaded", false)) \
		and String(asset.get("texture_path", "")) == String(expected.get("texture_path", "")) \
		and String(draw.get("mode", "")) == "imported_texture" \
		and String(draw.get("texture_path", "")) == String(expected.get("texture_path", "")) \
		and float(draw.get("alpha", 0.0)) > 0.0 \
		and Rect2(Vector2.ZERO, view_size).encloses(draw_rect)
	return {"event_id": event_id, "exact": exact, "draw_rect": draw_payload, "texture_path": asset.get("texture_path", "")}

func _fallback_row(event_id: String, snapshot: Dictionary, reduced_motion: bool) -> Dictionary:
	var expected: Dictionary = EXPECTED_CUES.get(event_id, {})
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_cue := String(expected.get("fallback_cue_id", "")) if reduced_motion else String(expected.get("cue_id", ""))
	var exact: bool = snapshot.get("selected_vfx_cue_ids", []) == [expected_cue] \
		and bool(asset.get("uses_procedural_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_procedural_object_resolution_body" \
		and String(draw.get("mode", "")) == "existing_procedural_object_resolution_body" \
		and String(draw.get("texture_path", "missing")) == "" \
		and bool(snapshot.get("allows_large_motion", true)) == not reduced_motion \
		and String(snapshot.get("visual_policy", "")) == ("reduced_motion_fallback" if reduced_motion else "authored_animation_state")
	return {"event_id": event_id, "exact": exact, "cue_id": expected_cue, "reduced_motion": reduced_motion}

func _asset_summary_exact(summary: Dictionary) -> bool:
	return String(summary.get("manifest_path", "")) == "res://content/overworld_vfx_manifest.json" \
		and bool(summary.get("manifest_loaded", false)) \
		and String(summary.get("schema_id", "")) == "overworld_vfx_manifest_v1" \
		and int(summary.get("mapped_cue_count", 0)) == 4 \
		and summary.get("mapped_cue_ids", []) == ["vfx_placeholder_adventure_spell", "vfx_placeholder_capture_flag", "vfx_placeholder_depleted_dim", "vfx_placeholder_object_visit"] \
		and int(summary.get("unique_texture_count", 0)) == 4 \
		and int(summary.get("loaded_texture_count", 0)) == 4 \
		and summary.get("missing_texture_paths", []) == []

func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows: Array = []
	for _y in range(height):
		var row: Array = []
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
	OverworldRules.refresh_fog_of_war(session)
	return session

func _finish_viewport(map_view: Control, result: Dictionary) -> Dictionary:
	if map_view != null and is_instance_valid(map_view):
		map_view.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("OVERWORLD_OBJECT_RESOLUTION_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
