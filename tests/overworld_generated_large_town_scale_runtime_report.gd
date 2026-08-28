extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "OVERWORLD_GENERATED_LARGE_TOWN_SCALE_RUNTIME_REPORT"
const GENERATED_LARGE_SEED := "town-explicit-save-surface-large-10184"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TOWN_VISUAL_EXTENT_TILES := 1.36
const TOWN_EXTENT_FRACTION := 0.68

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			GENERATED_LARGE_SEED,
			"translated_rmg_template_042_v1",
			"translated_rmg_profile_042_v1",
			4,
			"land",
			false,
			"homm3_large"
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		return _fail("Generated Large setup failed: %s" % JSON.stringify(setup))
	print("%s_STAGE setup_ready" % REPORT_ID)
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or OverworldRules.derive_map_size(session) != Vector2i(108, 108) or not bool(session.flags.get("generated_random_map", false)):
		return _fail("Generated Large session identity was not exact.")
	OverworldRules.normalize_overworld_state(session)
	_reveal_town_neighborhoods(session)
	session = SessionState.set_active_session(session)
	print("%s_STAGE session_ready" % REPORT_ID)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("%s_STAGE shell_ready" % REPORT_ID)
	var authority_before: Dictionary = session.to_dict()
	var blocked_before: Dictionary = OverworldRules._blocked_tile_index(session).duplicate(true)
	var interaction_before := _town_interaction_authority(session)
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		print("%s_STAGE viewport_%dx%d_start" % [REPORT_ID, viewport_size.x, viewport_size.y])
		var row := await _viewport_row(session, shell, viewport_size, authority_before, blocked_before, interaction_before)
		rows.append(row)
		if not bool(row.get("ok", false)):
			shell.queue_free()
			return _fail("Generated Large town-scale viewport failed: %s" % row)
		print("%s_STAGE viewport_%dx%d_done" % [REPORT_ID, viewport_size.x, viewport_size.y])
	shell.queue_free()
	await get_tree().process_frame
	if session.to_dict() != authority_before or OverworldRules._blocked_tile_index(session) != blocked_before or _town_interaction_authority(session) != interaction_before:
		return _fail("Generated Large renderer changed session, occupancy, or interaction authority.")
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": session.scenario_id,
		"map_size": {"width": 108, "height": 108},
		"town_count": session.overworld.get("towns", []).size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"town_visual_extent_tiles": TOWN_VISUAL_EXTENT_TILES,
		"town_extent_fraction": TOWN_EXTENT_FRACTION,
		"rows": rows,
		"session_authority_exact": true,
		"blocked_tile_index_exact": true,
		"interaction_authority_exact": true,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _viewport_row(session, shell, viewport_size: Vector2i, authority_before: Dictionary, blocked_before: Dictionary, interaction_before: Array) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_town_sprite_scale_payload") or not map_view.has_method("validation_tile_focus_layout"):
		return {"ok": false, "failure": "validation_surface"}
	var towns: Array = session.overworld.get("towns", [])
	var profiles: Array = map_view.call("validation_town_presentation_profiles")
	var profile_ids: Dictionary = {}
	var scale_exact := profiles.size() == towns.size() and not profiles.is_empty()
	var footprint_exact := scale_exact
	var click_routing_exact := scale_exact
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			scale_exact = false
			footprint_exact = false
			continue
		var profile: Dictionary = profile_value
		profile_ids[String(profile.get("town_placement_id", ""))] = true
		var scale_payload: Dictionary = map_view.call("validation_town_sprite_scale_payload", String(profile.get("sprite_asset_id", "")))
		scale_exact = scale_exact and _scale_payload_exact(scale_payload)
		footprint_exact = footprint_exact \
			and int(profile.get("footprint_width_tiles", 0)) == 3 \
			and int(profile.get("footprint_height_tiles", 0)) == 2 \
			and int(profile.get("blocked_footprint_cell_count", 0)) + int(profile.get("off_map_footprint_cell_count", 0)) == 5 \
			and bool(profile.get("entry_is_visit_tile", false)) \
			and bool(profile.get("non_entry_tiles_blocked", false)) \
			and String(profile.get("presentation_passability", "")) == "entry_only"
		var profile_entry: Dictionary = profile.get("entry_tile", {}) if profile.get("entry_tile", {}) is Dictionary else {}
		var expected_entry := Vector2i(int(profile_entry.get("x", -1)), int(profile_entry.get("y", -1)))
		var profile_cells: Array = profile.get("footprint_cells", []) if profile.get("footprint_cells", []) is Array else []
		click_routing_exact = click_routing_exact and profile_cells.size() > 0
		for cell_value in profile_cells:
			if not (cell_value is Dictionary):
				click_routing_exact = false
				continue
			var cell: Dictionary = cell_value
			if not bool(cell.get("in_bounds", false)):
				continue
			var clicked_tile := Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))
			var click_selection: Dictionary = map_view.call("town_footprint_selection", clicked_tile)
			click_routing_exact = click_routing_exact \
				and String(click_selection.get("town_placement_id", "")) == String(profile.get("town_placement_id", "")) \
				and click_selection.get("entry_tile", Vector2i(-1, -1)) == expected_entry \
				and bool(click_selection.get("is_entry_tile", false)) == bool(cell.get("is_entry_tile", false))
	var player_town := _first_player_town(session)
	if player_town.is_empty() or not profile_ids.has(String(player_town.get("placement_id", ""))):
		return {"ok": false, "failure": "player_town_profile"}
	var entry := Vector2i(int(player_town.get("x", -1)), int(player_town.get("y", -1)))
	var tile_presentation: Dictionary = map_view.call("validation_tile_presentation", entry)
	var focus_layout: Dictionary = map_view.call("validation_tile_focus_layout", entry)
	var hero_layout: Dictionary = map_view.call("validation_hero_draw_layout", entry, false)
	var tile_extent := float(map_view.call("validation_view_metrics").get("tile_extent", 0.0))
	var selection_rect := _rect_from_payload(focus_layout.get("selection_rect", {}))
	var hover_rect := _rect_from_payload(focus_layout.get("hover_rect", {}))
	var town_entry_tile: Dictionary = focus_layout.get("town_entry_tile", {}) if focus_layout.get("town_entry_tile", {}) is Dictionary else {}
	var interaction_geometry_exact := bool(focus_layout.get("selection_uses_town_footprint_rect", false)) \
		and bool(focus_layout.get("hover_uses_town_footprint_rect", false)) \
		and selection_rect == hover_rect \
		and selection_rect.size.x >= tile_extent * 2.0 \
		and selection_rect.size.y >= tile_extent \
		and int(town_entry_tile.get("x", -1)) == entry.x \
		and int(town_entry_tile.get("y", -1)) == entry.y \
		and bool(hero_layout.get("town_footprint_colocated", false)) \
		and bool(tile_presentation.get("has_town_entry", false)) \
		and bool(tile_presentation.get("draws_discoverable_object", false))
	var authority_exact: bool = session.to_dict() == authority_before \
		and OverworldRules._blocked_tile_index(session) == blocked_before \
		and _town_interaction_authority(session) == interaction_before
	await _capture_if_requested(viewport_size)
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var containment_exact := get_viewport().get_visible_rect().encloses(shell_rect)
	return {
		"ok": scale_exact and footprint_exact and click_routing_exact and interaction_geometry_exact and authority_exact and containment_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"tile_extent": tile_extent,
		"town_profile_count": profiles.size(),
		"scale_exact": scale_exact,
		"footprint_exact": footprint_exact,
		"click_routing_exact": click_routing_exact,
		"interaction_geometry_exact": interaction_geometry_exact,
		"authority_exact": authority_exact,
		"containment_exact": containment_exact,
	}

func _scale_payload_exact(payload: Dictionary) -> bool:
	return not payload.is_empty() \
		and is_equal_approx(float(payload.get("visible_extent_tiles", 0.0)), TOWN_VISUAL_EXTENT_TILES) \
		and is_equal_approx(float(payload.get("visible_extent_fraction_of_footprint_depth", 0.0)), TOWN_EXTENT_FRACTION) \
		and is_equal_approx(float(payload.get("town_to_hero_extent_ratio", 0.0)), 2.125) \
		and is_equal_approx(float(payload.get("town_to_largest_other_object_extent_ratio", 0.0)), 1.7) \
		and bool(payload.get("painted_bottom_grounded_exact", false)) \
		and bool(payload.get("sprite_contained_in_footprint", false))

func _town_interaction_authority(session) -> Array:
	var rows: Array = []
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var x := int(town.get("x", -1))
		var y := int(town.get("y", -1))
		rows.append({
			"placement_id": String(town.get("placement_id", "")),
			"x": x,
			"y": y,
			"owner": String(town.get("owner", "")),
			"tile_blocked": OverworldRules.tile_is_blocked(session, x, y),
			"route_interaction": OverworldRules.tile_has_route_interaction(session, x, y),
		})
	return rows

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _reveal_town_neighborhoods(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var center := Vector2i(int(town.get("x", -1)), int(town.get("y", -1)))
		for y in range(maxi(0, center.y - 5), mini(map_size.y, center.y + 6)):
			for x in range(maxi(0, center.x - 6), mini(map_size.x, center.x + 7)):
				visible_tiles[y][x] = true
				explored_tiles[y][x] = true
	var revealed_count := 0
	for row_value in visible_tiles:
		if not (row_value is Array):
			continue
		for visible_value in row_value:
			if bool(visible_value):
				revealed_count += 1
	session.overworld["fog"] = {
		"width": map_size.x,
		"height": map_size.y,
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": revealed_count,
		"explored_count": revealed_count,
		"total_tiles": map_size.x * map_size.y,
	}

func _capture_if_requested(viewport_size: Vector2i) -> void:
	var capture_dir := OS.get_environment("TOWN_SCALE_CAPTURE_DIR").strip_edges()
	if capture_dir == "":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return _fail("Could not create capture directory %s" % absolute_dir)
	var image := get_viewport().get_texture().get_image()
	var path := absolute_dir.path_join("generated_large_%dx%d.png" % [viewport_size.x, viewport_size.y])
	if image == null or image.is_empty() or image.save_png(path) != OK:
		return _fail("Could not save generated Large town capture %s" % path)

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
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
