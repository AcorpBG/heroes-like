extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TEXTURE_PATH := "res://art/town/runtime/vfx/build_complete.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Town building-complete VFX row failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_BUILDING_COMPLETE_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
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
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "failure": "town_missing"}
	_move_active_hero_to_town(session, town)
	var authority_before: Dictionary = session.to_dict()
	var stage: Control = TownStageViewScript.new()
	stage.size = Vector2(viewport_size)
	add_child(stage)
	stage.call("set_town_state", session)
	await get_tree().process_frame
	var summary: Dictionary = stage.call("validation_town_building_complete_vfx_asset_summary")
	if not _summary_exact(summary):
		return await _finish(stage, {"ok": false, "failure": "asset_summary", "actual": summary})

	stage.call("present_town_action", _presentation(town, false))
	await get_tree().process_frame
	var imported: Dictionary = stage.call("validation_town_action_presentation_snapshot")
	if not _imported_exact(imported, stage.size):
		return await _finish(stage, {"ok": false, "failure": "imported", "actual": imported})
	stage.call("dismiss_town_action_presentation")

	stage.set("_town_vfx_texture_missing", {TEXTURE_PATH: true})
	stage.call("present_town_action", _presentation(town, false))
	await get_tree().process_frame
	var missing: Dictionary = stage.call("validation_town_action_presentation_snapshot")
	if not _fallback_exact(missing, false):
		return await _finish(stage, {"ok": false, "failure": "missing_fallback", "actual": missing})
	stage.call("dismiss_town_action_presentation")

	stage.set("_town_vfx_texture_missing", {})
	stage.call("present_town_action", _presentation(town, true))
	await get_tree().process_frame
	var reduced: Dictionary = stage.call("validation_town_action_presentation_snapshot")
	if not _fallback_exact(reduced, true):
		return await _finish(stage, {"ok": false, "failure": "reduced_motion", "actual": reduced})
	var authority_exact: bool = session.to_dict() == authority_before
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(stage.get_global_rect())
	return await _finish(stage, {
		"ok": authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"asset_summary": summary,
		"imported": imported,
		"missing": missing,
		"reduced": reduced,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	})

func _presentation(town: Dictionary, reduced_motion: bool) -> Dictionary:
	return {
		"event_id": "town_building_built",
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"building_id": "building_emberwatch",
		"building_name": "Emberwatch",
		"result_message": "Emberwatch completed.",
		"policy": {
			"event_id": "town_building_built",
			"cue_id": "cue_town_building_built",
			"surface": "town",
			"subject_kind": "building",
			"mode": "reduced_motion" if reduced_motion else "normal",
			"selected_animation_state": "building_badge_added" if reduced_motion else "build_complete",
			"selected_fallback_tag": "building_badge_added" if reduced_motion else "",
			"selected_vfx_cue_ids": ["building_badge_added"] if reduced_motion else ["vfx_placeholder_build_complete"],
			"selected_audio_cue_ids": ["audio_placeholder_town_build"],
			"selected_playback_policy": "queue_resolved",
			"selected_blocking_policy": "nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout",
			"allows_large_motion": not reduced_motion,
			"max_duration_ms": 700,
		},
	}

func _imported_exact(snapshot: Dictionary, stage_size: Vector2) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var rect_payload: Dictionary = draw.get("rect", {}) if draw.get("rect", {}) is Dictionary else {}
	var draw_rect := Rect2(
		Vector2(float(rect_payload.get("x", -1.0)), float(rect_payload.get("y", -1.0))),
		Vector2(float(rect_payload.get("width", 0.0)), float(rect_payload.get("height", 0.0)))
	)
	return bool(snapshot.get("active", false)) \
		and snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_build_complete"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_procedural_fallback", true)) \
		and String(asset.get("texture_path", "")) == TEXTURE_PATH \
		and String(draw.get("mode", "")) == "imported_texture" \
		and String(draw.get("texture_path", "")) == TEXTURE_PATH \
		and float(draw.get("alpha", 0.0)) > 0.0 \
		and Rect2(Vector2.ZERO, stage_size).encloses(draw_rect) \
		and bool(snapshot.get("draw_rect_contained", false)) \
		and bool(snapshot.get("blocks_input", false))

func _fallback_exact(snapshot: Dictionary, reduced_motion: bool) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_mode := "building_badge_added" if reduced_motion else "existing_procedural_build_completion_frame"
	return bool(asset.get("uses_procedural_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_procedural_build_completion_frame" \
		and String(draw.get("mode", "")) == expected_mode \
		and String(draw.get("texture_path", "missing")) == "" \
		and bool(snapshot.get("blocks_input", true)) == not reduced_motion \
		and bool(snapshot.get("reduced_motion", false)) == reduced_motion

func _summary_exact(summary: Dictionary) -> bool:
	return String(summary.get("manifest_path", "")) == "res://content/town_vfx_manifest.json" \
		and bool(summary.get("manifest_loaded", false)) \
		and String(summary.get("schema_id", "")) == "town_vfx_manifest_v1" \
		and summary.get("mapped_cue_ids", []) == ["vfx_placeholder_build_complete"] \
		and summary.get("texture_paths", []) == [TEXTURE_PATH] \
		and summary.get("loaded_texture_paths", []) == [TEXTURE_PATH] \
		and summary.get("missing_texture_paths", []) == []

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

func _finish(stage: Control, result: Dictionary) -> Dictionary:
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("TOWN_BUILDING_COMPLETE_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
