extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "OVERWORLD_PLACEHOLDER_ART_RESOLUTION_REPORT"
const REPORT_SCHEMA_ID := "overworld_placeholder_art_resolution_report_v1"
const SEED := "live-render-move-10184"
const SIZE_CLASS_ID := "homm3_small"
const PLAYER_COUNT := 3
const EXPECTED_MARKER_CANDIDATE_COUNT := 65
const EXACT_PLACEMENT_ID := "native_h3maped_90dbde7a_object_0011"
const EXACT_H3M_DEF_NAME := "AVLmtsw4.def"
const EXACT_PRIMARY_TILE := Vector2i(1, 9)
const EXACT_ASSET_ID := "decor_mire_drum_island_reed_wall"

var _failures: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var menu: Variant = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	menu.call("validation_open_skirmish_stage")
	menu.call("validation_set_generated_seed", SEED)
	menu.call("validation_select_generated_size_class", SIZE_CLASS_ID)
	menu.call("validation_select_generated_water_mode", "land")
	menu.call("validation_set_generated_underground", false)
	await get_tree().process_frame
	var launch: Dictionary = await menu.validation_start_generated_skirmish_staged()
	if not bool(launch.get("started", false)) or SessionState.active_session == null:
		_failures.append("deterministic player-facing generated-map adoption failed: %s" % JSON.stringify(launch))
		_finish({})
		return
	var session: Variant = SessionState.active_session
	OverworldRules.normalize_overworld_state(session)
	_reveal_all(session)
	var authority_before: Dictionary = session.to_dict()
	var view: Variant = OverworldMapViewScript.new()
	view.size = Vector2(1600, 900)
	add_child(view)
	await get_tree().process_frame
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), OverworldRules.hero_position(session))
	await get_tree().process_frame
	var summary: Dictionary = view.validation_generated_object_visual_summary()
	var exact_candidate := _exact_candidate(summary.get("legacy_primary_marker_candidates", []), summary.get("body_entries", []))
	var exact_anchor_rows := _anchor_rows_for_placement(summary.get("body_entries", []), String(exact_candidate.get("placement_id", "")))
	var exact_asset_ids: Dictionary = {}
	for row_value in exact_anchor_rows:
		var row: Dictionary = row_value
		exact_asset_ids[String(row.get("asset_id", ""))] = true
	var exact_asset_id := String(exact_asset_ids.keys()[0]) if exact_asset_ids.size() == 1 else ""
	var art_manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var exact_asset: Dictionary = art_manifest.get("object_assets", {}).get(exact_asset_id, {}) if art_manifest.get("object_assets", {}) is Dictionary else {}
	var exact_asset_path := String(exact_asset.get("path", ""))
	var exact_source_model := String(exact_asset.get("source_model", ""))
	var exact_asset_policy := String(exact_asset.get("asset_policy", ""))
	var exact_texture_loaded := exact_asset_id != "" and view.call("_object_texture_for_asset", exact_asset_id) is Texture2D
	var category_resolution := _category_resolution(view, session)
	var overlay: Dictionary = view.validation_placement_debug_overlay_snapshot()

	_expect(int(summary.get("generated_record_count", 0)) == 175, "deterministic generated decorative record count changed")
	_expect(int(summary.get("legacy_primary_marker_candidate_count", 0)) == EXPECTED_MARKER_CANDIDATE_COUNT, "deterministic legacy-anchor candidate count changed")
	_expect(int(summary.get("indexed_legacy_primary_marker_count", -1)) == 0, "legacy DEF anchors remain indexed as visible procedural objects")
	_expect(bool(summary.get("legacy_primary_markers_suppressed", false)), "legacy DEF anchor suppression is not active")
	_expect(bool(summary.get("body_tile_keys_exact", false)), "generated body tile coverage is not exact")
	_expect(bool(summary.get("all_generated_records_anchored", false)), "a generated decorative placement lost its raster body")
	_expect(bool(summary.get("all_body_assets_loaded", false)), "a generated decorative body asset failed to load")
	_expect(bool(summary.get("all_body_assets_terrain_matched", false)), "a generated decorative body resolved outside its biome art family")
	_expect(not exact_candidate.is_empty(), "the deterministic screenshot-path identity was not reproduced")
	_expect(exact_anchor_rows.size() == 1, "the exact screenshot-path placement did not resolve to one authoritative raster anchor")
	_expect(exact_asset_ids.size() == 1 and exact_asset_id == EXACT_ASSET_ID, "the exact screenshot-path placement did not resolve to its unique expected asset")
	_expect(exact_asset_path.ends_with(".png") and ResourceLoader.exists(exact_asset_path), "the exact resolved raster path is unavailable")
	_expect(exact_texture_loaded, "the exact resolved raster texture did not load")
	_expect("image_gen" in exact_source_model.to_lower() and "original_generated" in exact_asset_policy, "the exact raster lacks original generated-art provenance")
	_expect(int(category_resolution.get("normal_visible_layer_count", 0)) > 0, "the deterministic case exposed no normal visible layers")
	_expect(int(category_resolution.get("procedural_fallback_count", -1)) == 0, "a normal visible object layer still lacks raster resolution")
	_expect(not bool(overlay.get("enabled", true)), "the placement/debug overlay leaked into normal gameplay")
	_expect(session.to_dict() == authority_before, "art resolution changed generated gameplay/save authority")

	_finish({
		"schema_id": REPORT_SCHEMA_ID,
		"seed": SEED,
		"size_class_id": SIZE_CLASS_ID,
		"player_count": PLAYER_COUNT,
		"generated_record_count": int(summary.get("generated_record_count", 0)),
		"legacy_primary_marker_candidate_count": int(summary.get("legacy_primary_marker_candidate_count", 0)),
		"indexed_legacy_primary_marker_count": int(summary.get("indexed_legacy_primary_marker_count", -1)),
		"exact_runtime_identity": exact_candidate,
		"exact_asset_id": exact_asset_id,
		"exact_asset_path": exact_asset_path,
		"exact_source_model": exact_source_model,
		"exact_asset_policy": exact_asset_policy,
		"exact_anchor_row": exact_anchor_rows[0] if exact_anchor_rows.size() == 1 else {},
		"category_resolution": category_resolution,
		"placement_debug_overlay_enabled": bool(overlay.get("enabled", true)),
		"gameplay_authority_unchanged": session.to_dict() == authority_before,
	})

func _exact_candidate(candidates: Variant, body_entries: Variant) -> Dictionary:
	if not (candidates is Array) or not (body_entries is Array):
		return {}
	for value in candidates:
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value
		if String(candidate.get("placement_id", "")) == EXACT_PLACEMENT_ID \
			and String(candidate.get("h3m_def_name", "")) == EXACT_H3M_DEF_NAME \
			and Vector2i(int(candidate.get("x", -1)), int(candidate.get("y", -1))) == EXACT_PRIMARY_TILE \
			and _anchor_rows_for_placement(body_entries, EXACT_PLACEMENT_ID).size() == 1:
			return candidate.duplicate(true)
	return {}

func _anchor_rows_for_placement(entries: Variant, placement_id: String) -> Array:
	var result: Array = []
	if placement_id == "" or not (entries is Array):
		return result
	for value in entries:
		if not (value is Dictionary):
			continue
		var row: Dictionary = value
		if bool(row.get("visual_anchor", false)) and (
			String(row.get("anchor_placement_id", "")) == placement_id
			or placement_id in row.get("source_placement_ids", [])
		):
			result.append(row.duplicate(true))
	return result

func _category_resolution(view: Variant, session: Variant) -> Dictionary:
	var counts := {"town": 0, "resource": 0, "artifact": 0, "encounter": 0}
	var failures: Array = []
	for spec in [
		{"collection": "towns", "kind": "town", "resolver": "_town_sprite_asset_id"},
		{"collection": "resource_nodes", "kind": "resource", "resolver": "_resource_asset_id"},
		{"collection": "artifact_nodes", "kind": "artifact", "resolver": "_artifact_sprite_asset_id"},
		{"collection": "encounters", "kind": "encounter", "resolver": "_encounter_asset_id"},
	]:
		for value in session.overworld.get(String(spec.get("collection", "")), []):
			if not (value is Dictionary):
				continue
			var entry: Dictionary = value
			var kind := String(spec.get("kind", ""))
			var asset_id := String(view.call(String(spec.get("resolver", "")), entry))
			var loaded := asset_id != "" and view.call("_object_texture_for_asset", asset_id) is Texture2D
			counts[kind] = int(counts.get(kind, 0)) + 1
			if not loaded:
				failures.append({
					"kind": kind,
					"identity": String(entry.get("placement_id", entry.get("id", ""))),
					"asset_id": asset_id,
				})
	var body_summary: Dictionary = view.validation_generated_object_visual_summary()
	var visible_body_anchors := int(body_summary.get("visual_anchor_count", 0))
	return {
		"category_counts": counts,
		"generated_body_anchor_count": visible_body_anchors,
		"normal_visible_layer_count": visible_body_anchors + int(counts.get("town", 0)) + int(counts.get("resource", 0)) + int(counts.get("artifact", 0)) + int(counts.get("encounter", 0)),
		"procedural_fallback_count": failures.size(),
		"failures": failures,
	}

func _reveal_all(session: Variant) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish(payload: Dictionary) -> void:
	payload["ok"] = _failures.is_empty()
	payload["failures"] = _failures
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(0)
		return
	push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
