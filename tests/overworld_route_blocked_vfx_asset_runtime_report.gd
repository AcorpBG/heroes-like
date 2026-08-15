extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const BLOCKED_TILE := Vector2i(3, 1)
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/route_blocked.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld route-blocked VFX row failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_ROUTE_BLOCKED_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
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
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var authority_before: Dictionary = session.to_dict()
	var map_size := OverworldRules.derive_map_size(session)
	var map_view: Control = MapViewScript.new()
	map_view.size = Vector2(viewport_size)
	add_child(map_view)
	await get_tree().process_frame

	_set_state(map_view, session, map_size, _presentation(1, false))
	await get_tree().process_frame
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	var imported: Dictionary = map_view.call("validation_route_blocked_presentation")
	if not _summary_exact(summary) or not _imported_exact(imported, map_view.size):
		return await _finish(map_view, {"ok": false, "failure": "imported", "summary": summary, "actual": imported})

	map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	_set_state(map_view, session, map_size, _presentation(2, false))
	await get_tree().process_frame
	var missing: Dictionary = map_view.call("validation_route_blocked_presentation")
	if not _fallback_exact(missing, false):
		return await _finish(map_view, {"ok": false, "failure": "missing_fallback", "actual": missing})

	map_view.set("_overworld_vfx_texture_missing", {})
	_set_state(map_view, session, map_size, _presentation(3, true))
	await get_tree().process_frame
	var reduced: Dictionary = map_view.call("validation_route_blocked_presentation")
	if not _fallback_exact(reduced, true):
		return await _finish(map_view, {"ok": false, "failure": "reduced_motion", "actual": reduced})

	_set_state(map_view, session, map_size, {"serial": 4})
	await get_tree().process_frame
	var cleared: Dictionary = map_view.call("validation_route_blocked_presentation")
	var authority_exact: bool = session.to_dict() == authority_before
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(map_view.get_global_rect())
	return await _finish(map_view, {
		"ok": not bool(cleared.get("active", true)) and cleared.get("vfx_draw", {}) == {} and authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"asset_summary": summary,
		"imported": imported,
		"missing": missing,
		"reduced": reduced,
		"cleared": not bool(cleared.get("active", true)),
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	})

func _set_state(map_view: Control, session, map_size: Vector2i, blocked: Dictionary) -> void:
	map_view.call(
		"set_map_state",
		session,
		session.overworld.get("map", []),
		map_size,
		BLOCKED_TILE,
		{},
		{},
		{},
		blocked,
		{},
		{}
	)

func _presentation(serial: int, reduced_motion: bool) -> Dictionary:
	return {
		"serial": serial,
		"event_id": "overworld_route_blocked",
		"status": "blocked",
		"tile": {"x": BLOCKED_TILE.x, "y": BLOCKED_TILE.y},
		"blocked_reason": "Mountain blocks travel.",
		"source_reason": "route_blocked_vfx_asset_report",
		"selected_animation_state": "blocked_route_icon" if reduced_motion else "route_blocked",
		"selected_visual_policy": "reduced_motion_fallback" if reduced_motion else "authored_animation_state",
		"selected_fallback_tag": "blocked_route_icon" if reduced_motion else "",
		"selected_vfx_cue_ids": ["blocked_route_icon"] if reduced_motion else ["vfx_placeholder_blocked_route_marker"],
		"allows_large_motion": not reduced_motion,
		"duration_ms": 260 if reduced_motion else 420,
		"max_duration_ms": 700,
	}

func _imported_exact(snapshot: Dictionary, view_size: Vector2) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var rect_payload: Dictionary = draw.get("rect", {}) if draw.get("rect", {}) is Dictionary else {}
	var draw_rect := Rect2(
		Vector2(float(rect_payload.get("x", -1.0)), float(rect_payload.get("y", -1.0))),
		Vector2(float(rect_payload.get("width", 0.0)), float(rect_payload.get("height", 0.0)))
	)
	return bool(snapshot.get("active", false)) \
		and snapshot.get("tile", {}) == {"x": BLOCKED_TILE.x, "y": BLOCKED_TILE.y} \
		and String(snapshot.get("blocked_reason", "")) == "Mountain blocks travel." \
		and snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_blocked_route_marker"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_procedural_fallback", true)) \
		and String(asset.get("texture_path", "")) == TEXTURE_PATH \
		and String(draw.get("mode", "")) == "imported_texture" \
		and String(draw.get("texture_path", "")) == TEXTURE_PATH \
		and Rect2(Vector2.ZERO, view_size).encloses(draw_rect) \
		and float(draw.get("alpha", 0.0)) > 0.0 \
		and int(snapshot.get("duration_ms", 0)) == 420 \
		and bool(snapshot.get("allows_large_motion", false))

func _fallback_exact(snapshot: Dictionary, reduced_motion: bool) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_mode := "blocked_route_icon" if reduced_motion else "existing_procedural_route_blocked_marker"
	return bool(asset.get("uses_procedural_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_procedural_route_blocked_marker" \
		and String(draw.get("mode", "")) == expected_mode \
		and String(draw.get("texture_path", "missing")) == "" \
		and int(draw.get("circle_count", 0)) == 1 \
		and int(draw.get("cross_line_count", 0)) == 2 \
		and snapshot.get("selected_vfx_cue_ids", []) == (["blocked_route_icon"] if reduced_motion else ["vfx_placeholder_blocked_route_marker"]) \
		and bool(snapshot.get("allows_large_motion", true)) == not reduced_motion

func _summary_exact(summary: Dictionary) -> bool:
	return String(summary.get("manifest_path", "")) == "res://content/overworld_vfx_manifest.json" \
		and bool(summary.get("manifest_loaded", false)) \
		and String(summary.get("schema_id", "")) == "overworld_vfx_manifest_v1" \
		and int(summary.get("mapped_cue_count", 0)) == 7 \
		and summary.get("mapped_cue_ids", []) == ["vfx_placeholder_adventure_spell", "vfx_placeholder_blocked_route_marker", "vfx_placeholder_capture_flag", "vfx_placeholder_depleted_dim", "vfx_placeholder_guard_warning", "vfx_placeholder_object_visit", "vfx_placeholder_route_step"] \
		and int(summary.get("unique_texture_count", 0)) == 7 \
		and int(summary.get("loaded_texture_count", 0)) == 7 \
		and summary.get("missing_texture_paths", []) == []

func _finish(map_view: Control, result: Dictionary) -> Dictionary:
	if map_view != null and is_instance_valid(map_view):
		map_view.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("OVERWORLD_ROUTE_BLOCKED_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
