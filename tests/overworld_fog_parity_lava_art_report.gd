extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "OVERWORLD_FOG_PARITY_LAVA_ART_REPORT"
const SEED := "live-render-move-10184"
const SIZE_CLASS_ID := "homm3_small"
const PLAYER_COUNT := 4
const CAPTURE_DIR := "res://.artifacts/overworld_fog_parity_lava_art_10233"
const VIEWPORT_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const HARSH_ATLAS_PATH := "res://art/overworld/runtime/objects/decorations/cohesive_blocker_mass_v3/harsh_atlas.png"

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
		_failures.append("deterministic generated setup failed: %s" % JSON.stringify(setup))
		return _finish({})
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null:
		_failures.append("deterministic generated session did not start")
		return _finish({})
	OverworldRules.normalize_overworld_state(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(8):
		await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		_failures.append("Overworld map view is missing")
		return _finish({})

	var authority_before := session.to_dict()
	var fog_before := _fog_parity_summary(shell, session)
	_validate_fog_parity(fog_before, "before_move")
	var normal_captures: Array = []
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		shell.validation_focus_map_on_hero()
		await get_tree().process_frame
		var capture_path := await _capture("normal_fog_%dx%d" % [viewport_size.x, viewport_size.y])
		var layout: Dictionary = shell.validation_map_first_layout_snapshot()
		_validate_layout(layout, viewport_size)
		normal_captures.append({
			"viewport": {"width": viewport_size.x, "height": viewport_size.y},
			"capture_path": capture_path,
			"capture_written": capture_path != "",
			"layout": layout,
		})

	var move_result := _try_one_step_move(session)
	if not bool(move_result.get("ok", false)):
		_failures.append("deterministic fog movement step failed: %s" % JSON.stringify(move_result))
	else:
		shell.call("_refresh_map_view")
		await get_tree().process_frame
	var fog_after := _fog_parity_summary(shell, session)
	_validate_fog_parity(fog_after, "after_move")
	if int(fog_after.get("explored_count", 0)) <= int(fog_before.get("explored_count", 0)):
		_failures.append("deterministic movement did not expand permanent exploration")

	var body_summary: Dictionary = map_view.validation_generated_object_visual_summary()
	var harsh_summary := _harsh_body_summary(body_summary)
	_validate_harsh_body_summary(harsh_summary)
	var atlas_summary := _harsh_atlas_summary()
	_validate_harsh_atlas_summary(atlas_summary)

	var harsh_capture := ""
	var harsh_focus: Vector2i = harsh_summary.get("focus_tile", Vector2i(-1, -1))
	if harsh_focus.x >= 0:
		var normal_fog: Dictionary = session.overworld.get("fog", {}).duplicate(true)
		var authority_before_art_review := session.to_dict()
		_reveal_all_for_explicit_art_review(session)
		shell.call("_refresh_map_view")
		await get_tree().process_frame
		get_window().size = Vector2i(1920, 1080)
		await get_tree().process_frame
		shell.validation_minimap_recenter(harsh_focus.x, harsh_focus.y)
		await get_tree().process_frame
		harsh_capture = await _capture("harsh_art_review_reveal_all_1920x1080")
		session.overworld["fog"] = normal_fog
		shell.call("_refresh_map_view")
		await get_tree().process_frame
		var restored_authority := session.to_dict()
		if restored_authority != authority_before_art_review:
			_failures.append("explicit reveal-all art review did not restore normal session authority")

	if session.to_dict() == authority_before:
		_failures.append("movement validation did not mutate the authoritative hero/fog state")
	if harsh_capture == "":
		_failures.append("harsh replacement-art review capture was not written")

	_finish({
		"seed": SEED,
		"size_class_id": SIZE_CLASS_ID,
		"map_size": fog_before.get("map_size", {}),
		"fog_model": "authoritative_permanent_exploration",
		"fog_before_move": fog_before,
		"fog_after_move": fog_after,
		"move_result": move_result,
		"normal_fog_captures": normal_captures,
		"harsh_art_review_capture": {
			"path": harsh_capture,
			"reveal_all_explicitly_art_review_only": true,
			"normal_fog_restored": true,
		},
		"harsh_body": harsh_summary,
		"harsh_atlas": atlas_summary,
		"native_rmg_output_changed": false,
		"save_version_changed": false,
	})


func _fog_parity_summary(shell, session) -> Dictionary:
	var map_size := OverworldRules.derive_map_size(session)
	var explored_count := 0
	var hidden_count := 0
	var main_explored_count := 0
	var main_hidden_shroud_count := 0
	var minimap_explored_count := 0
	var minimap_hidden_count := 0
	var minimap_unexplored_color_count := 0
	var main_mismatch_count := 0
	var minimap_mismatch_count := 0
	var cross_surface_mismatch_count := 0
	for y in range(map_size.y):
		for x in range(map_size.x):
			var authoritative := OverworldRules.is_tile_explored(session, x, y)
			if authoritative:
				explored_count += 1
			else:
				hidden_count += 1
			var main: Dictionary = shell.validation_tile_presentation(x, y)
			var main_terrain: Dictionary = main.get("terrain_presentation", {}) if main.get("terrain_presentation", {}) is Dictionary else {}
			var main_explored := bool(main.get("explored", false))
			var main_hidden := bool(main_terrain.get("unexplored_hidden", false))
			main_explored_count += int(main_explored)
			main_hidden_shroud_count += int(main_hidden)
			if main_explored != authoritative or main_hidden == authoritative:
				main_mismatch_count += 1
			var minimap: Dictionary = shell.validation_minimap_tile_presentation(x, y)
			var minimap_explored := bool(minimap.get("explored", false))
			var minimap_hidden := bool(minimap.get("hidden", false))
			minimap_explored_count += int(minimap_explored)
			minimap_hidden_count += int(minimap_hidden)
			minimap_unexplored_color_count += int(bool(minimap.get("uses_unexplored_color", false)))
			if minimap_explored != authoritative or minimap_hidden == authoritative:
				minimap_mismatch_count += 1
			if main_explored != minimap_explored or main_hidden != minimap_hidden:
				cross_surface_mismatch_count += 1
	var shell_snapshot: Dictionary = shell.validation_snapshot()
	var minimap_snapshot: Dictionary = shell_snapshot.get("minimap", {}) if shell_snapshot.get("minimap", {}) is Dictionary else {}
	return {
		"map_size": {"width": map_size.x, "height": map_size.y},
		"total_tiles": map_size.x * map_size.y,
		"explored_count": explored_count,
		"hidden_count": hidden_count,
		"main_explored_count": main_explored_count,
		"main_hidden_shroud_count": main_hidden_shroud_count,
		"minimap_explored_count": minimap_explored_count,
		"minimap_hidden_count": minimap_hidden_count,
		"minimap_unexplored_color_count": minimap_unexplored_color_count,
		"main_mismatch_count": main_mismatch_count,
		"minimap_mismatch_count": minimap_mismatch_count,
		"cross_surface_mismatch_count": cross_surface_mismatch_count,
		"minimap_snapshot_fog": minimap_snapshot.get("fog", {}).duplicate(true),
	}


func _validate_fog_parity(summary: Dictionary, label: String) -> void:
	var total := int(summary.get("total_tiles", 0))
	var explored := int(summary.get("explored_count", 0))
	var hidden := int(summary.get("hidden_count", 0))
	if total <= 0 or explored <= 0 or hidden <= 0 or explored + hidden != total:
		_failures.append("%s authoritative fog is not a bounded partially explored map: %s" % [label, JSON.stringify(summary)])
	for key in ["main_explored_count", "minimap_explored_count"]:
		if int(summary.get(key, -1)) != explored:
			_failures.append("%s %s does not match authoritative explored count" % [label, key])
	for key in ["main_hidden_shroud_count", "minimap_hidden_count", "minimap_unexplored_color_count"]:
		if int(summary.get(key, -1)) != hidden:
			_failures.append("%s %s does not match authoritative hidden count" % [label, key])
	for key in ["main_mismatch_count", "minimap_mismatch_count", "cross_surface_mismatch_count"]:
		if int(summary.get(key, -1)) != 0:
			_failures.append("%s %s is nonzero" % [label, key])
	var minimap_fog: Dictionary = summary.get("minimap_snapshot_fog", {}) if summary.get("minimap_snapshot_fog", {}) is Dictionary else {}
	if (
		int(minimap_fog.get("explored_count", -1)) != explored
		or int(minimap_fog.get("hidden_count", -1)) != hidden
		or int(minimap_fog.get("total_tiles", -1)) != total
		or not bool(minimap_fog.get("visible_aliases_explored", false))
	):
		_failures.append("%s minimap snapshot fog does not match authority: %s" % [label, JSON.stringify(minimap_fog)])


func _try_one_step_move(session) -> Dictionary:
	var start := OverworldRules.hero_position(session)
	for delta in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var target: Vector2i = start + delta
		if target.x < 0 or target.y < 0 or OverworldRules.tile_is_blocked(session, target.x, target.y):
			continue
		var result: Dictionary = OverworldRules.try_move(session, delta.x, delta.y)
		if bool(result.get("ok", false)):
			return result
	return {"ok": false, "message": "No adjacent passable deterministic movement tile."}


func _harsh_body_summary(body_summary: Dictionary) -> Dictionary:
	var harsh_entries := 0
	var loaded_entries := 0
	var terrain_matched_entries := 0
	var distinct_assets: Dictionary = {}
	var harsh_tiles: Array[Vector2i] = []
	var ash_lava_tiles: Array[Vector2i] = []
	var ash_lava_distinct_assets: Dictionary = {}
	for value in body_summary.get("body_entries", []):
		if not (value is Dictionary):
			continue
		var asset_id := String(value.get("asset_id", ""))
		if not asset_id.begins_with("cohesive_harsh_"):
			continue
		harsh_entries += 1
		loaded_entries += int(bool(value.get("asset_loaded", false)))
		terrain_matched_entries += int(bool(value.get("terrain_matched_asset", false)))
		distinct_assets[asset_id] = true
		harsh_tiles.append(Vector2i(int(value.get("x", -1)), int(value.get("y", -1))))
		if String(value.get("biome_id", "")) == "biome_ash_lava_wastes":
			ash_lava_tiles.append(Vector2i(int(value.get("x", -1)), int(value.get("y", -1))))
			ash_lava_distinct_assets[asset_id] = true
	return {
		"entry_count": harsh_entries,
		"loaded_entry_count": loaded_entries,
		"terrain_matched_entry_count": terrain_matched_entries,
		"distinct_asset_ids": distinct_assets.keys(),
		"ash_lava_entry_count": ash_lava_tiles.size(),
		"ash_lava_distinct_asset_ids": ash_lava_distinct_assets.keys(),
		"focus_tile": _densest_tile_focus(ash_lava_tiles if not ash_lava_tiles.is_empty() else harsh_tiles),
		"all_generated_body_assets_loaded": bool(body_summary.get("all_body_assets_loaded", false)),
		"all_generated_body_assets_terrain_matched": bool(body_summary.get("all_body_assets_terrain_matched", false)),
		"uncovered_body_tile_count": int(body_summary.get("uncovered_body_tile_count", -1)),
	}


func _validate_harsh_body_summary(summary: Dictionary) -> void:
	var count := int(summary.get("entry_count", 0))
	if count <= 0 or int(summary.get("loaded_entry_count", -1)) != count or int(summary.get("terrain_matched_entry_count", -1)) != count:
		_failures.append("generated harsh body does not resolve exact terrain-matched art: %s" % JSON.stringify(summary))
	if summary.get("distinct_asset_ids", []).size() < 4:
		_failures.append("generated harsh body did not exercise enough replacement atlas cells")
	if not bool(summary.get("all_generated_body_assets_loaded", false)) or not bool(summary.get("all_generated_body_assets_terrain_matched", false)) or int(summary.get("uncovered_body_tile_count", -1)) != 0:
		_failures.append("generated body art invariant failed while validating lava replacement")


func _densest_tile_focus(tiles: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_count := -1
	for candidate in tiles:
		var count := 0
		for tile in tiles:
			if abs(tile.x - candidate.x) <= 10 and abs(tile.y - candidate.y) <= 6:
				count += 1
		if count > best_count:
			best = candidate
			best_count = count
	return best


func _harsh_atlas_summary() -> Dictionary:
	var image := Image.load_from_file(ProjectSettings.globalize_path(HARSH_ATLAS_PATH))
	if image == null or image.is_empty():
		return {"loaded": false}
	var opaque_cell_corner_count := 0
	for row in range(4):
		for column in range(4):
			for offset in [Vector2i(2, 2), Vector2i(125, 2), Vector2i(2, 125), Vector2i(125, 125)]:
				var pixel: Vector2i = Vector2i(column * 128, row * 128) + offset
				opaque_cell_corner_count += int(image.get_pixelv(pixel).a > 0.12)
	return {
		"loaded": true,
		"path": HARSH_ATLAS_PATH,
		"size": {"width": image.get_width(), "height": image.get_height()},
		"has_alpha": image.detect_alpha() != Image.ALPHA_NONE,
		"transparent_canvas_corners": image.get_pixel(0, 0).a <= 0.01 and image.get_pixel(511, 0).a <= 0.01 and image.get_pixel(0, 511).a <= 0.01 and image.get_pixel(511, 511).a <= 0.01,
		"opaque_cell_corner_count": opaque_cell_corner_count,
		"provenance_manifest": "res://art/overworld/source/generated/terrain/cohesive_blocker_mass_v3/manifest.json",
		"source_model": "built_in_image_gen_original_cohesive_blocker_mass",
	}


func _validate_harsh_atlas_summary(summary: Dictionary) -> void:
	if (
		not bool(summary.get("loaded", false))
		or summary.get("size", {}) != {"width": 512, "height": 512}
		or not bool(summary.get("has_alpha", false))
		or not bool(summary.get("transparent_canvas_corners", false))
		or int(summary.get("opaque_cell_corner_count", 99)) > 8
	):
		_failures.append("replacement harsh atlas failed raster/alpha contract: %s" % JSON.stringify(summary))


func _validate_layout(layout: Dictionary, viewport_size: Vector2i) -> void:
	var map_rect: Dictionary = layout.get("map", {}) if layout.get("map", {}) is Dictionary else {}
	var rail_rect: Dictionary = layout.get("rail", {}) if layout.get("rail", {}) is Dictionary else {}
	var footer_rect: Dictionary = layout.get("footer", {}) if layout.get("footer", {}) is Dictionary else {}
	if not bool(layout.get("minimap_visible", false)) or not bool(layout.get("rail_visible", false)):
		_failures.append("responsive layout hid the minimap or command rail at %s" % viewport_size)
	if float(map_rect.get("end_x", 0.0)) > float(rail_rect.get("x", -1.0)) + 1.0:
		_failures.append("map and command rail overlap at %s" % viewport_size)
	if float(footer_rect.get("end_y", 0.0)) > float(viewport_size.y) + 1.0:
		_failures.append("footer clips below viewport at %s" % viewport_size)


func _reveal_all_for_explicit_art_review(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var explored: Array = []
	for _y in range(map_size.y):
		var row: Array = []
		for _x in range(map_size.x):
			row.append(true)
		explored.append(row)
	session.overworld["fog"] = {
		"visible_tiles": explored.duplicate(true),
		"explored_tiles": explored,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}


func _capture(label: String) -> String:
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var path := absolute_dir.path_join("%s.png" % label)
	return path if image.save_png(path) == OK else ""


func _finish(payload: Dictionary) -> void:
	payload["ok"] = _failures.is_empty()
	payload["failures"] = _failures.duplicate()
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(absolute_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(0)
		return
	push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
