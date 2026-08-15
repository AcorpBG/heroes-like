extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const GUARDED_TILE := Vector2i(3, 1)
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/guarded_site.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld guarded-site VFX row failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_GUARDED_SITE_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
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
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var authority_before: Dictionary = session.to_dict()
	var map_size := OverworldRules.derive_map_size(session)
	var map_view: Control = MapViewScript.new()
	map_view.size = Vector2(viewport_size)
	add_child(map_view)
	await get_tree().process_frame

	_set_state(map_view, session, map_size, _presentation(false))
	await get_tree().process_frame
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	var imported: Dictionary = map_view.call("validation_guarded_site_presentation")
	if not _summary_exact(summary) or not _imported_exact(imported, map_view.size) or not _audio_exact(imported, 1):
		return await _finish(map_view, {"ok": false, "failure": "imported", "summary": summary, "actual": imported})

	map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	_set_state(map_view, session, map_size, _presentation(false))
	await get_tree().process_frame
	var missing: Dictionary = map_view.call("validation_guarded_site_presentation")
	if not _fallback_exact(missing, false) or not _audio_exact(missing, 1):
		return await _finish(map_view, {"ok": false, "failure": "missing_fallback", "actual": missing})

	map_view.set("_overworld_vfx_texture_missing", {})
	_set_state(map_view, session, map_size, _presentation(true))
	await get_tree().process_frame
	var reduced: Dictionary = map_view.call("validation_guarded_site_presentation")
	if not _fallback_exact(reduced, true) or not _audio_exact(reduced, 1):
		return await _finish(map_view, {"ok": false, "failure": "reduced_motion", "actual": reduced})

	_set_state(map_view, session, map_size, {})
	await get_tree().process_frame
	var cleared: Dictionary = map_view.call("validation_guarded_site_presentation")
	var authority_exact: bool = session.to_dict() == authority_before
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(map_view.get_global_rect())
	return await _finish(map_view, {
		"ok": not bool(cleared.get("active", true)) and Array(cleared.get("audio_playback_records", [])).is_empty() and _guard_audio_service_records().size() == 1 and authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"asset_summary": summary,
		"imported": imported,
		"missing": missing,
		"reduced": reduced,
		"cleared": not bool(cleared.get("active", true)),
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	})

func _set_state(map_view: Control, session, map_size: Vector2i, guarded: Dictionary) -> void:
	map_view.call(
		"set_map_state",
		session,
		session.overworld.get("map", []),
		map_size,
		GUARDED_TILE,
		{},
		{},
		{},
		{},
		guarded,
		{}
	)

func _presentation(reduced_motion: bool) -> Dictionary:
	return {
		"active": true,
		"event_id": "overworld_object_guarded",
		"status": "guarded",
		"tile": {"x": GUARDED_TILE.x, "y": GUARDED_TILE.y},
		"placement_id": "object_guarded_barrow",
		"site_id": "site_barrow_vault",
		"site_name": "Barrow Vault",
		"guard_placement_id": "object_guarded_barrow_watch",
		"guard_name": "Bramble Hedge Watch",
		"control_inspection": "Guard: Guarded by Bramble Hedge Watch; clear guard to use site.",
		"guard_link_surface": "Bramble Hedge Watch blocks Barrow Vault.",
		"playback_policy": "context_visible_only",
		"selected_animation_state": "guard_badge_static" if reduced_motion else "guard_warning_hold",
		"selected_visual_policy": "reduced_motion_fallback" if reduced_motion else "authored_animation_state",
		"selected_fallback_tag": "guard_badge_static" if reduced_motion else "",
		"selected_vfx_cue_ids": ["guard_badge_static"] if reduced_motion else ["vfx_placeholder_guard_warning"],
		"selected_audio_cue_ids": ["audio_placeholder_guard_warning"],
		"allows_large_motion": not reduced_motion,
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
		and snapshot.get("tile", {}) == {"x": GUARDED_TILE.x, "y": GUARDED_TILE.y} \
		and snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_guard_warning"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_procedural_fallback", true)) \
		and String(asset.get("texture_path", "")) == TEXTURE_PATH \
		and String(draw.get("mode", "")) == "imported_texture" \
		and String(draw.get("texture_path", "")) == TEXTURE_PATH \
		and Rect2(Vector2.ZERO, view_size).encloses(draw_rect) \
		and String(snapshot.get("playback_policy", "")) == "context_visible_only" \
		and bool(snapshot.get("allows_large_motion", false))

func _fallback_exact(snapshot: Dictionary, reduced_motion: bool) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_mode := "guard_badge_static" if reduced_motion else "existing_procedural_guard_shield"
	return bool(asset.get("uses_procedural_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_procedural_guard_shield" \
		and String(draw.get("mode", "")) == expected_mode \
		and String(draw.get("texture_path", "missing")) == "" \
		and int(draw.get("shield_count", 0)) == 1 \
		and bool(snapshot.get("allows_large_motion", true)) == not reduced_motion

func _guard_audio_service_records() -> Array:
	var records: Array = []
	for record_value in PresentationAudio.validation_records():
		if record_value is Dictionary and String(record_value.get("source", "")) == "OverworldMapView.guarded_site":
			records.append(record_value.duplicate(true))
	return records

func _audio_exact(snapshot: Dictionary, expected_service_count: int) -> bool:
	var records: Array = snapshot.get("audio_playback_records", []) if snapshot.get("audio_playback_records", []) is Array else []
	var service_records := _guard_audio_service_records()
	if snapshot.get("selected_audio_cue_ids", []) != ["audio_placeholder_guard_warning"] or records.size() != 1 or service_records.size() != expected_service_count:
		return false
	var record: Dictionary = records[0] if records[0] is Dictionary else {}
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	return record == service_records[-1] \
		and String(record.get("cue_id", "")) == "audio_placeholder_guard_warning" \
		and String(record.get("source", "")) == "OverworldMapView.guarded_site" \
		and bool(record.get("played", false)) \
		and String(record.get("playback_source", "")) == "imported_wav" \
		and String(record.get("asset_path", "")) == "res://art/audio/runtime/presentation/guard_warning.wav" \
		and String(record.get("role", "")) == "overworld_object_guarded" \
		and int(record.get("stream_mix_rate", 0)) == 44100 \
		and bool(record.get("stream_stereo", false)) \
		and int(record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED \
		and String(metadata.get("context_signature", "")) == String(snapshot.get("context_signature", "")) \
		and metadata.get("tile", {}) == snapshot.get("tile", {})

func _summary_exact(summary: Dictionary) -> bool:
	return String(summary.get("manifest_path", "")) == "res://content/overworld_vfx_manifest.json" \
		and bool(summary.get("manifest_loaded", false)) \
		and String(summary.get("schema_id", "")) == "overworld_vfx_manifest_v1" \
		and int(summary.get("mapped_cue_count", 0)) == 12 \
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
	push_error("OVERWORLD_GUARDED_SITE_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
