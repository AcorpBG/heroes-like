extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "OVERWORLD_RASTER_TERRAIN_BLOCKER_MASS_REPORT"
const SEED := "medium-random-screenshot-10230"
const SIZE_CLASS_ID := "homm3_medium"
const PLAYER_COUNT := 4
const VIEWPORT_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const CAPTURE_DIR := "res://.artifacts/overworld_cohesive_biome_blocker_mass_10232"

var _failures: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			SEED,
			"translated_rmg_template_042_v1",
			"translated_rmg_profile_042_v1",
			PLAYER_COUNT,
			"land",
			false,
			SIZE_CLASS_ID
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		return _finish({"setup": setup})
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null:
		_failures.append("deterministic Medium session did not start")
		return _finish({})
	OverworldRules.normalize_overworld_state(session)
	_reveal_all(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var blocked_before: Dictionary = OverworldRules._blocked_tile_index(session).duplicate(true)
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		_failures.append("Overworld map view is missing")
		return _finish({})
	var first_summary: Dictionary = map_view.validation_generated_object_visual_summary()
	_validate_body_summary(first_summary)
	var terrain_summary := _terrain_summary(map_view, session)
	_validate_terrain_summary(terrain_summary)
	var focus_tile := _densest_body_focus(first_summary)
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		shell.validation_minimap_recenter(focus_tile.x, focus_tile.y)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture_path := _capture(viewport_size)
		var metrics: Dictionary = map_view.validation_view_metrics()
		rows.append({
			"viewport": {"width": viewport_size.x, "height": viewport_size.y},
			"capture_path": capture_path,
			"capture_written": capture_path != "",
			"focus_tile": {"x": focus_tile.x, "y": focus_tile.y},
			"map_viewport_rect": metrics.get("viewport_rect", {}).duplicate(true),
			"visible_tile_bounds": metrics.get("visible_tile_bounds", {}).duplicate(true),
		})
		if capture_path == "":
			_failures.append("capture failed at %dx%d" % [viewport_size.x, viewport_size.y])
	var redraw_summary: Dictionary = map_view.validation_generated_object_visual_summary()
	if String(redraw_summary.get("composition_signature", "")) != String(first_summary.get("composition_signature", "")):
		_failures.append("unchanged redraw changed blocker composition")
	if session.to_dict() != authority_before:
		_failures.append("terrain/blocker presentation changed session authority")
	if OverworldRules._blocked_tile_index(session) != blocked_before:
		_failures.append("terrain/blocker presentation changed collision authority")
	shell.queue_free()
	await get_tree().process_frame
	_finish({
		"seed": SEED,
		"size_class_id": SIZE_CLASS_ID,
		"map_size": {"width": OverworldRules.derive_map_size(session).x, "height": OverworldRules.derive_map_size(session).y},
		"generated_record_count": int(first_summary.get("generated_record_count", 0)),
		"expected_body_tile_count": int(first_summary.get("expected_body_tile_count", 0)),
		"visual_anchor_count": int(first_summary.get("visual_anchor_count", 0)),
		"uncovered_body_tile_count": int(first_summary.get("uncovered_body_tile_count", -1)),
		"all_body_cells_visually_covered": bool(first_summary.get("all_body_cells_visually_covered", false)),
		"all_body_assets_loaded": bool(first_summary.get("all_body_assets_loaded", false)),
		"all_body_assets_terrain_matched": bool(first_summary.get("all_body_assets_terrain_matched", false)),
		"distinct_body_asset_count": int(first_summary.get("distinct_body_asset_count", 0)),
		"composition_signature": String(first_summary.get("composition_signature", "")),
		"terrain": terrain_summary,
		"rows": rows,
		"session_authority_exact": session.to_dict() == authority_before,
		"collision_authority_exact": OverworldRules._blocked_tile_index(session) == blocked_before,
		"native_rmg_output_changed": false,
	})

func _validate_body_summary(summary: Dictionary) -> void:
	if String(summary.get("presentation_model", "")) != "cohesive_biome_exact_body_raster_mass_v6":
		_failures.append("generated body presentation model is stale")
	var expected := int(summary.get("expected_body_tile_count", 0))
	var indexed := int(summary.get("indexed_body_tile_count", 0))
	var visible := int(summary.get("visual_anchor_count", 0))
	if expected <= 0 or expected != indexed or indexed != visible:
		_failures.append("body-cell raster coverage is not exact: %d/%d/%d" % [expected, indexed, visible])
	if int(summary.get("uncovered_body_tile_count", -1)) != 0 or not bool(summary.get("all_body_cells_visually_covered", false)):
		_failures.append("an authoritative blocker body cell remains visually uncovered")
	for key in ["body_tile_keys_exact", "all_body_assets_loaded", "all_body_assets_terrain_matched", "all_generated_records_anchored", "all_transformed_bounds_within_mass_margin"]:
		if not bool(summary.get(key, false)):
			_failures.append("generated blocker invariant failed: %s" % key)
	if int(summary.get("distinct_body_asset_count", 0)) < 8:
		_failures.append("generated blocker palette is not varied")
	for value in summary.get("body_entries", []):
		if value is Dictionary and not String(value.get("asset_id", "")).begins_with("cohesive_"):
			_failures.append("generated body resolved outside dedicated cohesive palette")
			break
	if String(summary.get("composition_signature", "")).length() != 64:
		_failures.append("generated blocker composition signature is missing")

func _terrain_summary(map_view, session) -> Dictionary:
	var map_size := OverworldRules.derive_map_size(session)
	var sampled := 0
	var raster_loaded := 0
	var procedural_microtexture_drawn := 0
	var procedural_microtexture_calls := 0
	var raster_detail_drawn := 0
	for y in range(map_size.y):
		for x in range(map_size.x):
			var payload: Dictionary = map_view.call("_terrain_visual_payload", Vector2i(x, y), true, true)
			sampled += 1
			if bool(payload.get("texture_loaded", false)):
				raster_loaded += 1
			var micro: Dictionary = payload.get("terrain_microtexture", {}) if payload.get("terrain_microtexture", {}) is Dictionary else {}
			if bool(micro.get("drawn", false)) or int(micro.get("stroke_count", 0)) != 0:
				procedural_microtexture_drawn += 1
			procedural_microtexture_calls += int(micro.get("procedural_draw_calls", 0))
			var detail: Dictionary = payload.get("terrain_detail_decal", {}) if payload.get("terrain_detail_decal", {}) is Dictionary else {}
			if bool(detail.get("drawn", false)):
				raster_detail_drawn += 1
	return {
		"sampled_tile_count": sampled,
		"raster_base_loaded_count": raster_loaded,
		"procedural_microtexture_tile_count": procedural_microtexture_drawn,
		"procedural_microtexture_draw_calls": procedural_microtexture_calls,
		"raster_detail_drawn_count": raster_detail_drawn,
		"microtexture_model": "disabled_original_raster_surface_only_v2",
		"detail_model": "biome_specific_painterly_landmark_clusters_denser_v4",
	}

func _validate_terrain_summary(summary: Dictionary) -> void:
	if int(summary.get("sampled_tile_count", 0)) <= 0:
		_failures.append("no terrain tiles were sampled")
	if int(summary.get("raster_base_loaded_count", 0)) != int(summary.get("sampled_tile_count", -1)):
		_failures.append("a normal generated terrain tile lacks raster base art")
	if int(summary.get("procedural_microtexture_tile_count", -1)) != 0 or int(summary.get("procedural_microtexture_draw_calls", -1)) != 0:
		_failures.append("procedural ground scratches remain active")
	if int(summary.get("raster_detail_drawn_count", 0)) <= 0:
		_failures.append("original raster terrain detail did not draw")

func _densest_body_focus(summary: Dictionary) -> Vector2i:
	var tiles: Array = []
	for value in summary.get("body_entries", []):
		if value is Dictionary:
			tiles.append(Vector2i(int(value.get("x", 0)), int(value.get("y", 0))))
	var best := Vector2i(36, 36)
	var best_count := -1
	for candidate_value in tiles:
		var candidate: Vector2i = candidate_value
		var count := 0
		for tile_value in tiles:
			var tile: Vector2i = tile_value
			if abs(tile.x - candidate.x) <= 10 and abs(tile.y - candidate.y) <= 6:
				count += 1
		if count > best_count:
			best_count = count
			best = candidate
	return best

func _capture(viewport_size: Vector2i) -> String:
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var path := absolute_dir.path_join("medium_generated_%dx%d.png" % [viewport_size.x, viewport_size.y])
	return path if image.save_png(path) == OK else ""

func _reveal_all(session) -> void:
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

func _finish(payload: Dictionary) -> void:
	payload["ok"] = _failures.is_empty()
	payload["failures"] = _failures.duplicate()
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var report_path := absolute_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(0)
		return
	push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
