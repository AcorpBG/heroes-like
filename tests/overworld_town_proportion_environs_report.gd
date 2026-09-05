extends Node

const REPORT_ID := "OVERWORLD_TOWN_PROPORTION_ENVIRONS_REPORT"
const ARTIFACT_DIR := "res://.artifacts/overworld_town_proportion_environs_10236"
const VIEWPORTS := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const SCENARIO_ID := "ninefold-confluence"
const TOWN_PLACEMENT_ID := "ninefold_embercourt_survey_camp"
const TOWN_ASSET_ID := "town_identity_riverwatch"
const BATCH_ID := "ux-overworld-town-proportion-and-environs-10236"
const EXPECTED_BLOCKER_ASSETS := {
	"town_environs_10236_west_settlement_fence": "decor_low_fence_splinters",
	"town_environs_10236_northeast_orchard_roots": "decor_orchard_root_wall",
	"town_environs_10236_southeast_fence": "decor_low_fence_splinters",
}

var _failures: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SessionState.reset_session()
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(8):
		await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		_failures.append("map view missing")
		_finish({})
		return
	var town_profiles := _town_profiles(shell, map_view)
	var environs := _environs_profile(shell, session)
	var captures := []
	var layouts := []
	for viewport in VIEWPORTS:
		get_window().size = viewport
		get_window().content_scale_size = viewport
		for _frame in range(3):
			await get_tree().process_frame
		shell._focus_active_hero_from_roster()
		await get_tree().process_frame
		var layout: Dictionary = shell.validation_map_first_layout_snapshot()
		if not bool(layout.get("map_first_exact", false)) and not get_viewport().get_visible_rect().encloses(shell.get_global_rect()):
			_failures.append("layout clipped at %s" % viewport)
		layouts.append({"viewport": {"width": viewport.x, "height": viewport.y}, "layout": layout})
		var capture := await _capture("ninefold_town_environs_%dx%d" % [viewport.x, viewport.y])
		captures.append(capture)
		if capture == "":
			_failures.append("capture failed at %s" % viewport)
	var authority_exact := session.to_dict() == authority_before
	if not authority_exact:
		_failures.append("presentation validation mutated authoritative session state")
	_finish({
		"scenario_id": SCENARIO_ID,
		"town": town_profiles,
		"environs": environs,
		"layouts": layouts,
		"captures": captures,
		"session_authority_exact": authority_exact,
		"native_rmg_output_changed": false,
		"save_version": session.save_version,
	})


func _town_profiles(shell: Node, map_view: Node) -> Dictionary:
	var rows := []
	var all_exact := true
	for profile_value in shell.validation_town_presentation_profiles():
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		var asset_id := String(profile.get("sprite_asset_id", ""))
		var scale: Dictionary = map_view.call("validation_town_sprite_scale_payload", asset_id)
		var source_aspect := float(scale.get("source_aspect", 0.0))
		var draw_aspect := float(scale.get("draw_aspect", -1.0))
		var exact := bool(scale.get("town_aspect_preserved", false)) \
			and is_equal_approx(source_aspect, draw_aspect) \
			and float(scale.get("painted_width_tiles", 99.0)) <= 2.9001 \
			and float(scale.get("painted_height_tiles", 99.0)) <= 3.7201 \
			and bool(scale.get("painted_bottom_grounded_exact", false)) \
			and bool(scale.get("sprite_silhouette_contained_in_footprint", false))
		all_exact = all_exact and exact
		rows.append({
			"town_placement_id": String(profile.get("town_placement_id", "")),
			"asset_id": asset_id,
			"source_aspect": source_aspect,
			"draw_aspect": draw_aspect,
			"painted_width_tiles": float(scale.get("painted_width_tiles", 0.0)),
			"painted_height_tiles": float(scale.get("painted_height_tiles", 0.0)),
			"exact": exact,
		})
	var riverwatch: Dictionary = map_view.call("validation_town_sprite_scale_payload", TOWN_ASSET_ID)
	# Compare the actual manifest-resolved texture to the canonical PNG, not a
	# guessed aspect range that can accidentally certify an older imported asset.
	var canonical_path := "res://art/overworld/runtime/objects/towns/identity/town_riverwatch.png"
	var canonical_image := Image.load_from_file(canonical_path)
	var live_texture: Texture2D = map_view.call("_object_texture_for_asset", TOWN_ASSET_ID)
	var live_image := live_texture.get_image() if live_texture != null else null
	var imported_pixels_exact := canonical_image != null and live_image != null
	if imported_pixels_exact:
		canonical_image.convert(Image.FORMAT_RGBA8)
		canonical_image.fix_alpha_edges()
		live_image.convert(Image.FORMAT_RGBA8)
		# The importer fixes RGB in transparent edge pixels; compare visible color
		# and alpha, not irrelevant RGB beneath fully transparent pixels.
		imported_pixels_exact = canonical_image.get_size() == live_image.get_size()
		if imported_pixels_exact:
			for y in range(canonical_image.get_height()):
				for x in range(canonical_image.get_width()):
					var expected := canonical_image.get_pixel(x, y)
					var actual := live_image.get_pixel(x, y)
					if not is_equal_approx(expected.a, actual.a) or (expected.a > 0.0 and not expected.is_equal_approx(actual)):
						imported_pixels_exact = false
	var identity_exact := imported_pixels_exact and bool(riverwatch.get("town_aspect_preserved", false))
	if not all_exact:
		_failures.append("one or more live town sprites lost painted aspect or envelope containment")
	if not identity_exact:
		_failures.append("Riverwatch loaded pixels differ from the canonical land-set raster")
	return {
		"profile_count": rows.size(),
		"all_aspects_preserved": all_exact,
		"riverwatch_landset_exact": identity_exact,
		"imported_pixels_exact": imported_pixels_exact,
		"riverwatch": riverwatch,
		"rows": rows,
	}


func _environs_profile(shell: Node, session) -> Dictionary:
	var authored_scenario: Dictionary = ContentService.get_scenario_readonly(SCENARIO_ID)
	var support: Dictionary = authored_scenario.get("town_environs_support", {})
	var roads := {}
	for road_value in session.overworld.get("roads", []):
		if not (road_value is Dictionary):
			continue
		for tile_value in road_value.get("tiles", []):
			if tile_value is Dictionary:
				roads["%d,%d" % [int(tile_value.get("x", -1)), int(tile_value.get("y", -1))]] = true
	var placements := []
	var road_clear := true
	var all_blocked := true
	var all_visible_art := true
	var within_town_vision := true
	var town_anchor := Vector2i(-1, -1)
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == TOWN_PLACEMENT_ID:
			town_anchor = Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1)))
			break
	for object_value in session.overworld.get("map_objects", []):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if String(object.get("content_batch_id", "")) != BATCH_ID:
			continue
		var placement_id := String(object.get("placement_id", ""))
		var anchor := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		within_town_vision = within_town_vision and town_anchor.x >= 0 and abs(anchor.x - town_anchor.x) + abs(anchor.y - town_anchor.y) <= 5
		var presentation: Dictionary = shell.validation_tile_presentation(anchor.x, anchor.y)
		var art: Dictionary = presentation.get("art_presentation", {})
		var expected_asset := String(EXPECTED_BLOCKER_ASSETS.get(placement_id, ""))
		var art_exact: bool = bool(presentation.get("explored", false)) \
			and bool(presentation.get("has_decorative_object", false)) \
			and expected_asset in art.get("sprite_asset_ids", []) \
			and not bool(art.get("fallback_procedural_marker", true))
		all_visible_art = all_visible_art and art_exact
		for tile_value in object.get("body_tiles", []):
			if not (tile_value is Dictionary):
				continue
			var x := int(tile_value.get("x", -1))
			var y := int(tile_value.get("y", -1))
			road_clear = road_clear and not roads.has("%d,%d" % [x, y])
			all_blocked = all_blocked and OverworldRules.tile_is_blocked(session, x, y)
		placements.append({
			"placement_id": placement_id,
			"anchor": {"x": anchor.x, "y": anchor.y},
			"expected_asset_id": expected_asset,
			"visible_art_exact": art_exact,
			"body_tile_count": object.get("body_tiles", []).size(),
		})
	var exact: bool = placements.size() == 3 \
		and support.get("town_placement_id", "") == TOWN_PLACEMENT_ID \
		and int(support.get("vision_radius", 0)) == 5 \
		and road_clear and all_blocked and all_visible_art and within_town_vision
	if not exact:
		_failures.append("town environs are not three visible raster blockers with exact bodies and clear roads")
	return {
		"exact": exact,
		"support": support,
		"placement_count": placements.size(),
		"roads_clear": road_clear,
		"all_body_tiles_blocked": all_blocked,
		"all_anchor_art_visible": all_visible_art,
		"all_anchors_within_town_vision": within_town_vision,
		"placements": placements,
	}


func _capture(stem: String) -> String:
	var absolute_dir := ProjectSettings.globalize_path(ARTIFACT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var path := absolute_dir.path_join("%s.png" % stem)
	return path if image.save_png(path) == OK else ""


func _finish(payload: Dictionary) -> void:
	payload["ok"] = _failures.is_empty()
	payload["failures"] = _failures.duplicate(true)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	if _failures.is_empty():
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("%s: %s" % [REPORT_ID, String(failure)])
	get_tree().quit(1)
