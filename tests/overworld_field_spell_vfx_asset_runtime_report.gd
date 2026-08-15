extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const HERO_TILE := Vector2i(1, 2)
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/field_spell.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld field-spell VFX row failed.", {"row": row})
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FIELD_SPELL_VFX_ASSET_RUNTIME_REPORT %s" % JSON.stringify({
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
	var session = _field_spell_session()
	var before: Dictionary = session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(before.duplicate(true))
	var control_result: Dictionary = OverworldRules.cast_overworld_spell(control, "spell_waystride")
	var live_result: Dictionary = OverworldRules.cast_overworld_spell(session, "spell_waystride")
	var consequence_exact: bool = bool(control_result.get("ok", false)) \
		and live_result == control_result \
		and session.to_dict() == control.to_dict()
	if not consequence_exact:
		return {"ok": false, "failure": "spell_consequence", "live": live_result, "control": control_result}
	var authority_after_cast: Dictionary = session.to_dict()
	var map_size := OverworldRules.derive_map_size(session)
	var map_rows: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	var hero_tile_valid: bool = HERO_TILE.x >= 0 \
		and HERO_TILE.y >= 0 \
		and HERO_TILE.x < map_size.x \
		and HERO_TILE.y < map_size.y \
		and HERO_TILE.y < map_rows.size() \
		and map_rows[HERO_TILE.y] is Array \
		and HERO_TILE.x < map_rows[HERO_TILE.y].size() \
		and OverworldRules.terrain_id_is_passable(String(map_rows[HERO_TILE.y][HERO_TILE.x]))
	if not hero_tile_valid:
		return {"ok": false, "failure": "hero_tile_valid", "hero_tile": HERO_TILE, "map_size": map_size}
	var map_view: Control = MapViewScript.new()
	map_view.size = Vector2(viewport_size)
	add_child(map_view)
	await get_tree().process_frame
	map_view.call("set_map_state", session, session.overworld.get("map", []), map_size, HERO_TILE)
	await get_tree().process_frame
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	if not _summary_exact(summary):
		return await _finish(map_view, {"ok": false, "failure": "asset_summary", "actual": summary})

	map_view.call("present_spell_cast_presentation", _presentation(1, live_result, false))
	await get_tree().process_frame
	var imported: Dictionary = map_view.call("validation_spell_cast_presentation")
	if not _imported_exact(imported, map_view.size):
		return await _finish(map_view, {"ok": false, "failure": "imported", "actual": imported})

	map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	map_view.call("present_spell_cast_presentation", _presentation(2, live_result, false))
	await get_tree().process_frame
	var missing: Dictionary = map_view.call("validation_spell_cast_presentation")
	if not _fallback_exact(missing, false):
		return await _finish(map_view, {"ok": false, "failure": "missing_fallback", "actual": missing})

	map_view.set("_overworld_vfx_texture_missing", {})
	map_view.call("present_spell_cast_presentation", _presentation(3, live_result, true))
	await get_tree().process_frame
	var reduced: Dictionary = map_view.call("validation_spell_cast_presentation")
	if not _fallback_exact(reduced, true):
		return await _finish(map_view, {"ok": false, "failure": "reduced_motion", "actual": reduced})
	var authority_exact: bool = session.to_dict() == authority_after_cast
	var containment_exact: bool = Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(map_view.get_global_rect())
	return await _finish(map_view, {
		"ok": consequence_exact and authority_exact and containment_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"asset_summary": summary,
		"imported": imported,
		"missing": missing,
		"reduced": reduced,
		"consequence_exact": consequence_exact,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	})

func _presentation(serial: int, result: Dictionary, reduced_motion: bool) -> Dictionary:
	return {
		"serial": serial,
		"event_id": "spell_cast_overworld",
		"cue_id": "cue_spell_cast_overworld",
		"spell_id": "spell_waystride",
		"spell_name": String(ContentService.get_spell("spell_waystride").get("name", "")),
		"result_message": String(result.get("message", "")),
		"selected_animation_state": "adventure_spell_icon" if reduced_motion else "adventure_cast_anchor",
		"selected_visual_policy": "reduced_motion_fallback" if reduced_motion else "authored_animation_state",
		"selected_fallback_tag": "adventure_spell_icon" if reduced_motion else "",
		"selected_playback_policy": "queue_resolved",
		"selected_blocking_policy": "nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout",
		"selected_vfx_cue_ids": ["adventure_spell_icon"] if reduced_motion else ["vfx_placeholder_adventure_spell"],
		"selected_audio_cue_ids": ["audio_placeholder_spell_school_soft"],
		"allows_large_motion": not reduced_motion,
		"hero_tile": {"x": HERO_TILE.x, "y": HERO_TILE.y},
		"duration_ms": 260 if reduced_motion else 620,
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
		and snapshot.get("hero_tile", {}) == {"x": HERO_TILE.x, "y": HERO_TILE.y} \
		and snapshot.get("vfx_cue_ids", []) == ["vfx_placeholder_adventure_spell"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and not bool(asset.get("uses_procedural_fallback", true)) \
		and String(asset.get("texture_path", "")) == TEXTURE_PATH \
		and String(draw.get("mode", "")) == "imported_texture" \
		and String(draw.get("texture_path", "")) == TEXTURE_PATH \
		and float(draw.get("alpha", 0.0)) > 0.0 \
		and Rect2(Vector2.ZERO, view_size).encloses(draw_rect) \
		and bool(snapshot.get("blocks_input", false))

func _fallback_exact(snapshot: Dictionary, reduced_motion: bool) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_mode := "adventure_spell_icon" if reduced_motion else "existing_procedural_adventure_cast_rings"
	return bool(asset.get("uses_procedural_fallback", false)) \
		and not bool(asset.get("uses_imported_asset", true)) \
		and String(asset.get("fallback_mode", "")) == "existing_procedural_adventure_cast_rings" \
		and String(draw.get("mode", "")) == expected_mode \
		and String(draw.get("texture_path", "missing")) == "" \
		and int(draw.get("ring_count", 2)) == 2 \
		and bool(snapshot.get("blocks_input", false)) == not reduced_motion \
		and bool(snapshot.get("allows_large_motion", true)) == not reduced_motion

func _summary_exact(summary: Dictionary) -> bool:
	return String(summary.get("manifest_path", "")) == "res://content/overworld_vfx_manifest.json" \
		and bool(summary.get("manifest_loaded", false)) \
		and String(summary.get("schema_id", "")) == "overworld_vfx_manifest_v1" \
		and int(summary.get("mapped_cue_count", 0)) == 12 \
		and summary.get("mapped_cue_ids", []) == ["vfx_placeholder_adventure_spell", "vfx_placeholder_artifact_claim", "vfx_placeholder_blocked_route_marker", "vfx_placeholder_capture_flag", "vfx_placeholder_depleted_dim", "vfx_placeholder_guard_warning", "vfx_placeholder_object_focus_ring", "vfx_placeholder_object_visit", "vfx_placeholder_resource_delta", "vfx_placeholder_route_step", "vfx_placeholder_slot_equip", "vfx_placeholder_slot_unequip"] \
		and int(summary.get("unique_texture_count", 0)) == 12 \
		and int(summary.get("loaded_texture_count", 0)) == 12 \
		and summary.get("missing_texture_paths", []) == []

func _field_spell_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var position := {"x": HERO_TILE.x, "y": HERO_TILE.y}
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero = SpellRules.ensure_hero_spellbook(hero)
	hero["position"] = position.duplicate(true)
	hero["movement"] = {"current": 2, "max": 12}
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	spellbook["known_spell_ids"] = ["spell_waystride"]
	spellbook["mana"] = {"current": 40, "max": 40}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
	session.overworld["movement"] = {"current": 2, "max": 12}
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

func _finish(map_view: Control, result: Dictionary) -> Dictionary:
	if map_view != null and is_instance_valid(map_view):
		map_view.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("OVERWORLD_FIELD_SPELL_VFX_ASSET_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
