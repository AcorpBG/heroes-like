extends Node

const SMALL_SCENARIO_ID := "prismhearth-watch"
const LARGE_SCENARIO_ID := "ninefold-confluence"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MAX_SMALL_MAP_TILE_EXTENT := 104.0
const SMALL_MAP_MATTE_MODEL := "quiet_survey_field_below_playable_board"
const SMALL_MAP_MATTE_MIN_GUTTER := 48.0
const TOWN_VISUAL_EXTENT_TILES := 1.20

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var small_rows: Array = []
	var matte_active_rows := 0
	for viewport_size in VIEWPORT_SIZES:
		var row := await _small_map_row(viewport_size)
		small_rows.append(row)
		if bool(row.get("cartographic_matte_active", false)):
			matte_active_rows += 1
		if not bool(row.get("ok", false)):
			_fail("Small-map visual scale row failed: %s" % row)
			return
	if matte_active_rows != VIEWPORT_SIZES.size():
		_fail("Small-map cartographic matte must activate for every material-gutter viewport: %s" % [small_rows])
		return
	var large_row := await _large_map_control(Vector2i(1920, 1080))
	if not bool(large_row.get("ok", false)):
		_fail("Large-map tactical camera control failed: %s" % large_row)
		return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_SMALL_MAP_VISUAL_SCALE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"small_scenario_id": SMALL_SCENARIO_ID,
		"large_scenario_id": LARGE_SCENARIO_ID,
		"maximum_small_map_tile_extent": MAX_SMALL_MAP_TILE_EXTENT,
		"small_map_cartographic_matte_model": SMALL_MAP_MATTE_MODEL,
		"cartographic_matte_active_rows": matte_active_rows,
		"viewports": [[1280, 720], [1920, 1080]],
		"small_rows": small_rows,
		"large_row": large_row,
		"logical_footprints_unchanged": true,
		"gameplay_authority_unchanged": true,
	}))
	get_tree().quit(0)

func _small_map_row(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session(SMALL_SCENARIO_ID, "normal")
	_reveal_all(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_view_metrics"):
		shell.queue_free()
		return {"ok": false, "failure": "map_view_missing"}
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var viewport_rect := _rect_from_payload(metrics.get("viewport_rect", {}))
	var board_rect := _rect_from_payload(metrics.get("board_rect", {}))
	var tile_extent := float(metrics.get("tile_extent", 0.0))
	var uncapped_extent := float(metrics.get("uncapped_whole_map_fit_tile_extent", 0.0))
	var expected_capped := uncapped_extent > MAX_SMALL_MAP_TILE_EXTENT
	var scale_exact := String(metrics.get("whole_map_fit_scale_policy", "")) == "bounded_small_map_fit_extent" \
		and is_equal_approx(float(metrics.get("maximum_small_map_fit_tile_extent", 0.0)), MAX_SMALL_MAP_TILE_EXTENT) \
		and tile_extent <= MAX_SMALL_MAP_TILE_EXTENT \
		and tile_extent >= float(metrics.get("minimum_tile_extent", 0.0)) \
		and bool(metrics.get("small_map_fit_extent_capped", false)) == expected_capped \
		and ((uncapped_extent > tile_extent and is_equal_approx(tile_extent, MAX_SMALL_MAP_TILE_EXTENT)) if expected_capped else is_equal_approx(uncapped_extent, tile_extent))
	var centered_exact := viewport_rect.encloses(board_rect) \
		and viewport_rect.get_center().distance_to(board_rect.get_center()) <= 1.5 \
		and bool(metrics.get("fit_entire_map", false)) \
		and bool(metrics.get("full_map_visible", false)) \
		and not bool(metrics.get("pan_supported", true))
	var matte_gutters: Dictionary = metrics.get("small_map_cartographic_matte_gutters", {})
	var maximum_gutter := maxf(
		maxf(float(matte_gutters.get("left", 0.0)), float(matte_gutters.get("right", 0.0))),
		maxf(float(matte_gutters.get("top", 0.0)), float(matte_gutters.get("bottom", 0.0)))
	)
	var matte_expected := maximum_gutter >= SMALL_MAP_MATTE_MIN_GUTTER
	var matte_exact := bool(metrics.get("small_map_cartographic_matte_active", false)) == matte_expected \
		and String(metrics.get("small_map_cartographic_matte_model", "")) == SMALL_MAP_MATTE_MODEL \
		and is_equal_approx(float(metrics.get("small_map_cartographic_matte_minimum_gutter", 0.0)), SMALL_MAP_MATTE_MIN_GUTTER) \
		and is_equal_approx(float(metrics.get("small_map_cartographic_matte_grid_spacing", 0.0)), 72.0) \
		and is_equal_approx(float(metrics.get("small_map_cartographic_matte_board_shadow_extent", 0.0)), 14.0) \
		and bool(metrics.get("small_map_cartographic_matte_below_terrain", false)) \
		and bool(metrics.get("small_map_cartographic_matte_noninteractive", false)) \
		and not bool(metrics.get("small_map_cartographic_matte_fake_tiles", true))
	var town_exact := _town_footprint_exact(shell)
	var hero_exact := _hero_scale_exact(map_view, tile_extent)
	var object_exact := _one_tile_object_footprints_exact(shell, session)
	var authority_exact := session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var containment_exact := get_viewport().get_visible_rect().encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": scale_exact and centered_exact and matte_exact and town_exact and hero_exact and object_exact and authority_exact and containment_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"tile_extent": tile_extent,
		"uncapped_extent": uncapped_extent,
		"fit_extent_capped": metrics.get("small_map_fit_extent_capped", false),
		"board_centered": centered_exact,
		"cartographic_matte_active": metrics.get("small_map_cartographic_matte_active", false),
		"cartographic_matte_exact": matte_exact,
		"maximum_gutter": maximum_gutter,
		"town_3x2_exact": town_exact,
		"hero_scale_bounded": hero_exact,
		"one_tile_objects_exact": object_exact,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	}

func _large_map_control(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session(LARGE_SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		shell.queue_free()
		return {"ok": false, "failure": "map_view_missing"}
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var tile_extent := float(metrics.get("tile_extent", 0.0))
	var exact := not bool(metrics.get("fit_entire_map", true)) \
		and not bool(metrics.get("full_map_visible", true)) \
		and bool(metrics.get("pan_supported", false)) \
		and not bool(metrics.get("small_map_fit_extent_capped", true)) \
		and tile_extent > 0.0 and tile_extent < MAX_SMALL_MAP_TILE_EXTENT \
		and not bool(metrics.get("small_map_cartographic_matte_active", true)) \
		and session.to_dict() == authority_before
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"tile_extent": tile_extent,
		"fit_entire_map": metrics.get("fit_entire_map", true),
		"pan_supported": metrics.get("pan_supported", false),
		"cartographic_matte_active": metrics.get("small_map_cartographic_matte_active", true),
		"authority_exact": session.to_dict() == authority_before,
	}

func _town_footprint_exact(shell: Node) -> bool:
	var profiles: Array = shell.call("validation_town_presentation_profiles")
	if profiles.is_empty():
		return false
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return false
		var profile: Dictionary = profile_value
		if int(profile.get("footprint_width_tiles", 0)) != 3 \
			or int(profile.get("footprint_height_tiles", 0)) != 2 \
			or int(profile.get("blocked_footprint_cell_count", 0)) + int(profile.get("off_map_footprint_cell_count", 0)) != 5 \
			or not is_equal_approx(float(profile.get("visual_sprite_extent_fraction_of_footprint", 0.0)), 0.60) \
			or not is_equal_approx(float(profile.get("visual_sprite_extent_tiles", 0.0)), TOWN_VISUAL_EXTENT_TILES) \
			or String(profile.get("entry_role", "")) != "bottom_middle_visit_approach" \
			or not bool(profile.get("entry_is_visit_tile", false)) \
			or not bool(profile.get("non_entry_tiles_blocked", false)):
			return false
	return true

func _hero_scale_exact(map_view: Node, tile_extent: float) -> bool:
	var profiles: Array = map_view.call("validation_hero_presentation_profiles")
	if profiles.is_empty():
		return false
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return false
		var layout: Dictionary = profile_value.get("layout", {})
		var sprite_rect := _rect_from_payload(layout.get("sprite_rect", {}))
		if sprite_rect.size.x <= 0.0 or sprite_rect.size.x > tile_extent + 0.01 \
			or not bool(layout.get("sprite_contained_in_tile", false)):
			return false
	return true

func _one_tile_object_footprints_exact(shell: Node, session) -> bool:
	var saw_resource := false
	var saw_encounter := false
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var presentation: Dictionary = shell.call("validation_tile_presentation", int(node.get("x", -1)), int(node.get("y", -1)))
		var readability: Dictionary = presentation.get("marker_readability", {})
		if String(readability.get("dominant_object_family", "")) == "town":
			continue
		if int(readability.get("footprint_width_tiles", 0)) == 1 and int(readability.get("footprint_height_tiles", 0)) == 1:
			saw_resource = true
			break
	for node_value in session.overworld.get("encounters", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var presentation: Dictionary = shell.call("validation_tile_presentation", int(node.get("x", -1)), int(node.get("y", -1)))
		var readability: Dictionary = presentation.get("marker_readability", {})
		if int(readability.get("footprint_width_tiles", 0)) == 1 and int(readability.get("footprint_height_tiles", 0)) == 1:
			saw_encounter = true
			break
	return saw_resource and saw_encounter

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

func _rect_from_payload(payload: Variant) -> Rect2:
	if not (payload is Dictionary):
		return Rect2()
	return Rect2(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("width", 0.0)),
		float(payload.get("height", 0.0))
	)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
