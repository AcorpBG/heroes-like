extends Node

const SCENARIO_ID := "ninefold-confluence"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_FACTION_ASSETS := {
	"faction_embercourt": "hero_faction_embercourt",
	"faction_mireclaw": "hero_faction_mireclaw",
	"faction_sunvault": "hero_faction_sunvault",
	"faction_thornwake": "hero_faction_thornwake",
	"faction_brasshollow": "hero_faction_brasshollow",
	"faction_veilmourn": "hero_faction_veilmourn",
}
const REPRESENTATIVE_HERO_IDS := {
	"faction_embercourt": "hero_lyra",
	"faction_mireclaw": "hero_mireclaw_zhorra_fenwake",
	"faction_sunvault": "hero_sunvault_ilyr_glassmarshal",
	"faction_thornwake": "hero_thornwake_ardren_briarmarshal",
	"faction_brasshollow": "hero_brasshollow_daxis_chaincaptain",
	"faction_veilmourn": "hero_veilmourn_ruln_vanehook",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld faction hero sprite row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FACTION_HERO_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"production_hero_count": 60,
		"faction_count": EXPECTED_FACTION_ASSETS.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback": "procedural_hero_marker",
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_hero_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_hero_presentation_profiles") or not map_view.has_method("validation_hero_draw_layout") or not map_view.has_method("validation_tile_focus_layout"):
		shell.queue_free()
		return {"ok": false, "failure": "validation_surface_missing"}
	var authority_before: Dictionary = session.to_dict()
	var profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var exact := _validate_profiles(profiles, map_view)
	if not bool(exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "hero_profiles", "detail": exact}

	var active_tile_value: Dictionary = exact.get("active_tile", {})
	var active_tile := Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
	var moving_layout: Dictionary = map_view.call("validation_hero_draw_layout", active_tile, true)
	var moving_layout_exact: bool = String(moving_layout.get("mode", "")) == "full_tile_world_hero" \
		and not bool(moving_layout.get("town_footprint_colocated", true)) \
		and is_equal_approx(float(moving_layout.get("hero_rect_extent_fraction", 0.0)), 1.0) \
		and is_equal_approx(float(moving_layout.get("sprite_extent_fraction", 0.0)), 0.60)
	if not moving_layout_exact:
		shell.queue_free()
		return {"ok": false, "failure": "moving_layout_control", "layout": moving_layout}
	var focus_exact: Dictionary = _validate_focus_layouts(map_view, exact)
	if not bool(focus_exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "focus_layouts", "detail": focus_exact}

	var heroes: Array = session.overworld.get("player_heroes", [])
	var first_hero: Dictionary = heroes[0]
	first_hero["id"] = "hero_missing_faction_sprite_fixture"
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var first_position: Dictionary = first_hero.get("position", {})
	var fallback_tile := Vector2i(int(first_position.get("x", -1)), int(first_position.get("y", -1)))
	var fallback_presentation: Dictionary = map_view.call("validation_tile_presentation", fallback_tile)
	var fallback: Dictionary = fallback_presentation.get("hero_presentation", {})
	var fallback_exact: bool = String(fallback.get("hero_id", "")) == "hero_missing_faction_sprite_fixture" \
		and String(fallback.get("faction_id", "")) == "" \
		and String(fallback.get("sprite_asset_id", "")) == "" \
		and bool(fallback.get("uses_procedural_fallback", false)) \
		and not bool(fallback.get("uses_faction_sprite", true)) \
		and String(fallback.get("layout", {}).get("mode", "")) == "compact_town_footprint_visitor" \
		and bool(fallback.get("layout", {}).get("sprite_contained_in_tile", false))

	session.from_dict(authority_before)
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var restored_focus_exact: bool = map_view.call("validation_tile_focus_layout", active_tile) == focus_exact.get("town_layout", {}) \
		and map_view.call("validation_tile_focus_layout", focus_exact.get("ordinary_tile", Vector2i(-1, -1))) == focus_exact.get("ordinary_layout", {})
	var restored_exact: bool = restored_profiles == profiles and restored_focus_exact and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact := viewport_rect.encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": fallback_exact and restored_exact and containment_exact and moving_layout_exact and bool(focus_exact.get("ok", false)),
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"asset_ids": exact.get("asset_ids", []),
		"active_identity_exact": exact.get("active_identity_exact", false),
		"grounding_exact": exact.get("grounding_exact", false),
		"town_footprint_layout_exact": exact.get("town_footprint_layout_exact", false),
		"ordinary_layout_exact": exact.get("ordinary_layout_exact", false),
		"moving_layout_exact": moving_layout_exact,
		"town_focus_layout_exact": focus_exact.get("town_focus_layout_exact", false),
		"ordinary_focus_layout_exact": focus_exact.get("ordinary_focus_layout_exact", false),
		"town_selection_interior_fill": focus_exact.get("town_selection_interior_fill", true),
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	}

func _validate_profiles(profiles: Array, map_view: Node) -> Dictionary:
	if profiles.size() != EXPECTED_FACTION_ASSETS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var seen_factions: Dictionary = {}
	var seen_assets: Dictionary = {}
	var active_count := 0
	var grounding_exact := true
	var town_footprint_layout_count := 0
	var ordinary_layout_count := 0
	var active_tile := Vector2i(-1, -1)
	var ordinary_tile := Vector2i(-1, -1)
	var geometry_exact := true
	var view_metrics: Dictionary = map_view.call("validation_view_metrics")
	var board_rect := _rect_from_payload(view_metrics.get("board_rect", {}))
	var map_size_value: Dictionary = view_metrics.get("map_size", {})
	var map_size := Vector2i(int(map_size_value.get("x", 0)), int(map_size_value.get("y", 0)))
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var hero_id := String(profile.get("hero_id", ""))
		var faction_id := String(profile.get("faction_id", ""))
		var expected_hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var expected_asset_id := String(EXPECTED_FACTION_ASSETS.get(faction_id, ""))
		var expected_path := "res://art/overworld/runtime/heroes/factions/%s.png" % faction_id.trim_prefix("faction_")
		if hero_id != expected_hero_id or String(profile.get("sprite_asset_id", "")) != expected_asset_id:
			return {"ok": false, "reason": "identity", "profile": profile}
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture", "profile": profile}
		if not bool(profile.get("uses_faction_sprite", false)) or bool(profile.get("uses_procedural_fallback", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		if bool(profile.get("is_active", false)):
			active_count += 1
			var active_tile_value: Dictionary = profile.get("tile", {})
			active_tile = Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
		grounding_exact = grounding_exact \
			and String(profile.get("grounding_model", "")) == "hero_foot_contact_without_base_ellipse" \
			and String(profile.get("depth_cue_model", "")) == "hero_foot_contact_shadow_with_boot_occlusion"
		seen_factions[faction_id] = true
		seen_assets[expected_asset_id] = true
		var layout: Dictionary = profile.get("layout", {})
		var tile_value: Dictionary = profile.get("tile", {})
		var tile := Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))
		if bool(layout.get("town_footprint_colocated", false)):
			town_footprint_layout_count += 1
			var tile_presentation: Dictionary = map_view.call("validation_tile_presentation", tile)
			var town_presentation: Dictionary = tile_presentation.get("town_presentation", {})
			var tile_rect := _tile_rect_from_metrics(board_rect, map_size, tile)
			var hero_rect := _rect_from_payload(layout.get("hero_rect", {}))
			var sprite_rect := _rect_from_payload(layout.get("sprite_rect", {}))
			geometry_exact = geometry_exact \
				and bool(profile.get("is_active", false)) \
				and String(layout.get("mode", "")) == "compact_town_footprint_visitor" \
				and is_equal_approx(float(layout.get("hero_rect_extent_fraction", 0.0)), 0.76) \
				and is_equal_approx(float(layout.get("sprite_extent_fraction", 0.0)), 0.4484) \
				and bool(layout.get("sprite_contained_in_tile", false)) \
				and tile_rect.encloses(hero_rect) and tile_rect.encloses(sprite_rect) \
				and float(layout.get("ground_anchor_y_fraction", 0.0)) > 0.75 \
				and bool(tile_presentation.get("has_visible_hero", false)) \
				and bool(tile_presentation.get("has_town_non_entry", false)) \
				and String(town_presentation.get("presentation_model", "")) == "town_3x2_footprint_bottom_middle_entry" \
				and String(town_presentation.get("tile_role", "")) == "blocked_non_entry_footprint"
		else:
			ordinary_layout_count += 1
			if ordinary_tile.x < 0:
				ordinary_tile = tile
			geometry_exact = geometry_exact \
				and String(layout.get("mode", "")) == "full_tile_world_hero" \
				and is_equal_approx(float(layout.get("hero_rect_extent_fraction", 0.0)), 1.0) \
				and is_equal_approx(float(layout.get("sprite_extent_fraction", 0.0)), 0.60)
	return {
		"ok": seen_factions.size() == 6 and seen_assets.size() == 6 and active_count == 1 and grounding_exact and town_footprint_layout_count == 1 and ordinary_layout_count == 5 and geometry_exact,
		"asset_ids": seen_assets.keys(),
		"active_identity_exact": active_count == 1,
		"grounding_exact": grounding_exact,
		"town_footprint_layout_exact": town_footprint_layout_count == 1 and geometry_exact,
		"ordinary_layout_exact": ordinary_layout_count == 5 and geometry_exact,
		"active_tile": {"x": active_tile.x, "y": active_tile.y},
		"ordinary_tile": {"x": ordinary_tile.x, "y": ordinary_tile.y},
	}

func _validate_focus_layouts(map_view: Node, profiles_exact: Dictionary) -> Dictionary:
	var active_tile_value: Dictionary = profiles_exact.get("active_tile", {})
	var active_tile := Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
	var ordinary_tile_value: Dictionary = profiles_exact.get("ordinary_tile", {})
	var ordinary_tile := Vector2i(int(ordinary_tile_value.get("x", -1)), int(ordinary_tile_value.get("y", -1)))
	if active_tile.x < 0 or ordinary_tile.x < 0:
		return {"ok": false, "reason": "missing_control_tiles"}
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var board_rect := _rect_from_payload(metrics.get("board_rect", {}))
	var map_size_value: Dictionary = metrics.get("map_size", {})
	var map_size := Vector2i(int(map_size_value.get("x", 0)), int(map_size_value.get("y", 0)))
	var active_tile_rect := _tile_rect_from_metrics(board_rect, map_size, active_tile)
	var ordinary_tile_rect := _tile_rect_from_metrics(board_rect, map_size, ordinary_tile)
	var hero_layout: Dictionary = map_view.call("validation_hero_draw_layout", active_tile, false)
	var town_tile_presentation: Dictionary = map_view.call("validation_tile_presentation", active_tile)
	var town_presentation: Dictionary = town_tile_presentation.get("town_presentation", {})
	var expected_town_rect := _footprint_rect_from_presentation(town_presentation, board_rect, map_size)
	var town_layout: Dictionary = map_view.call("validation_tile_focus_layout", active_tile)
	var ordinary_layout: Dictionary = map_view.call("validation_tile_focus_layout", ordinary_tile)
	var town_selection_visual_profile: Dictionary = town_layout.get("town_selection_visual_profile", {})
	var town_tile_selection_visual_profile: Dictionary = town_layout.get("tile_selection_visual_profile", {})
	var ordinary_town_selection_visual_profile: Dictionary = ordinary_layout.get("town_selection_visual_profile", {})
	var ordinary_tile_selection_visual_profile: Dictionary = ordinary_layout.get("tile_selection_visual_profile", {})
	var town_command_marker_profile: Dictionary = town_layout.get("hero_command_marker_profile", {})
	var ordinary_command_marker_profile: Dictionary = ordinary_layout.get("hero_command_marker_profile", {})
	var town_hero_focus_rect := _rect_from_payload(town_layout.get("hero_focus_rect", {}))
	var town_selection_rect := _rect_from_payload(town_layout.get("selection_rect", {}))
	var town_hover_rect := _rect_from_payload(town_layout.get("hover_rect", {}))
	var ordinary_hero_focus_rect := _rect_from_payload(ordinary_layout.get("hero_focus_rect", {}))
	var ordinary_selection_rect := _rect_from_payload(ordinary_layout.get("selection_rect", {}))
	var ordinary_hover_rect := _rect_from_payload(ordinary_layout.get("hover_rect", {}))
	var town_hero_sprite_rect := _rect_from_payload(hero_layout.get("sprite_rect", {}))
	var town_command_marker_exact := _hero_command_marker_profile_exact(town_command_marker_profile, town_hero_focus_rect, town_hero_sprite_rect)
	var ordinary_command_marker_exact := _hero_command_marker_profile_exact(ordinary_command_marker_profile, ordinary_hero_focus_rect)
	var expected_town_selection_extent := minf(expected_town_rect.size.x, expected_town_rect.size.y)
	var expected_town_selection_inset := maxf(4.0, expected_town_selection_extent * 0.045)
	var expected_town_selection_perimeter := expected_town_rect.grow(-expected_town_selection_inset)
	var expected_tile_selection_extent := minf(ordinary_tile_rect.size.x, ordinary_tile_rect.size.y)
	var expected_tile_selection_inset := maxf(4.0, expected_tile_selection_extent * 0.085)
	var expected_tile_selection_perimeter := ordinary_tile_rect.grow(-expected_tile_selection_inset)
	var town_focus_layout_exact: bool = bool(town_layout.get("hero_uses_compact_town_footprint_rect", false)) \
		and town_command_marker_exact \
		and town_hero_focus_rect == _rect_from_payload(hero_layout.get("hero_rect", {})) \
		and active_tile_rect.encloses(town_hero_focus_rect) \
		and bool(town_layout.get("selection_uses_town_footprint_rect", false)) \
		and not bool(town_layout.get("selection_uses_interior_fill", true)) \
		and bool(town_layout.get("selection_uses_cartographic_town_perimeter", false)) \
		and not bool(town_layout.get("selection_uses_cartographic_tile_reticle", true)) \
		and String(town_layout.get("selection_visual_model", "")) == "open_cartographic_footprint_corner_and_midpoint_ticks" \
		and town_selection_rect == expected_town_rect \
		and _rect_from_payload(town_selection_visual_profile.get("perimeter_rect", {})) == expected_town_selection_perimeter \
		and is_equal_approx(float(town_selection_visual_profile.get("perimeter_inset_px", 0.0)), expected_town_selection_inset) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_alpha", 0.0)), 0.78) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_length_px", 0.0)), maxf(10.0, expected_town_selection_extent * 0.10)) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_width_px", 0.0)), maxf(1.5, expected_town_selection_extent * 0.010)) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_alpha", 0.0)), 0.34) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_length_px", 0.0)), maxf(6.0, expected_town_selection_extent * 0.035)) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_width_px", 0.0)), maxf(1.25, expected_town_selection_extent * 0.008)) \
		and not bool(town_selection_visual_profile.get("continuous_outline", true)) \
		and is_zero_approx(float(town_selection_visual_profile.get("interior_fill_alpha", -1.0))) \
		and town_tile_selection_visual_profile.is_empty() \
		and bool(town_layout.get("hover_uses_town_footprint_rect", false)) \
		and town_hover_rect == expected_town_rect \
		and town_selection_rect.size == active_tile_rect.size * Vector2(3.0, 2.0) \
		and town_layout.get("town_entry_tile", {}) == town_presentation.get("entry_tile", {})
	var ordinary_focus_layout_exact: bool = not bool(ordinary_layout.get("hero_uses_compact_town_footprint_rect", true)) \
		and ordinary_command_marker_exact \
		and ordinary_hero_focus_rect == ordinary_tile_rect \
		and not bool(ordinary_layout.get("selection_uses_town_footprint_rect", true)) \
		and not bool(ordinary_layout.get("selection_uses_interior_fill", true)) \
		and not bool(ordinary_layout.get("selection_uses_cartographic_town_perimeter", true)) \
		and bool(ordinary_layout.get("selection_uses_cartographic_tile_reticle", false)) \
		and String(ordinary_layout.get("selection_visual_model", "")) == "open_cartographic_tile_corner_and_midpoint_ticks" \
		and ordinary_town_selection_visual_profile.is_empty() \
		and _rect_from_payload(ordinary_tile_selection_visual_profile.get("perimeter_rect", {})) == expected_tile_selection_perimeter \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("perimeter_inset_px", 0.0)), expected_tile_selection_inset) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_alpha", 0.0)), 0.82) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_length_px", 0.0)), maxf(8.0, expected_tile_selection_extent * 0.18)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_width_px", 0.0)), maxf(1.5, expected_tile_selection_extent * 0.022)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_alpha", 0.0)), 0.42) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_length_px", 0.0)), maxf(5.0, expected_tile_selection_extent * 0.08)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_width_px", 0.0)), maxf(1.25, expected_tile_selection_extent * 0.016)) \
		and not bool(ordinary_tile_selection_visual_profile.get("continuous_outline", true)) \
		and is_zero_approx(float(ordinary_tile_selection_visual_profile.get("interior_fill_alpha", -1.0))) \
		and ordinary_selection_rect == ordinary_tile_rect \
		and not bool(ordinary_layout.get("hover_uses_town_footprint_rect", true)) \
		and ordinary_hover_rect == ordinary_tile_rect \
		and (ordinary_layout.get("town_entry_tile", {}) as Dictionary).is_empty()
	return {
		"ok": town_focus_layout_exact and ordinary_focus_layout_exact,
		"town_focus_layout_exact": town_focus_layout_exact,
		"ordinary_focus_layout_exact": ordinary_focus_layout_exact,
		"town_command_marker_exact": town_command_marker_exact,
		"ordinary_command_marker_exact": ordinary_command_marker_exact,
		"town_selection_interior_fill": bool(town_layout.get("selection_uses_interior_fill", true)),
		"town_selection_visual_model": String(town_layout.get("selection_visual_model", "")),
		"town_selection_visual_profile": town_selection_visual_profile.duplicate(true),
		"ordinary_tile_selection_visual_profile": ordinary_tile_selection_visual_profile.duplicate(true),
		"town_layout": town_layout.duplicate(true),
		"ordinary_layout": ordinary_layout.duplicate(true),
		"ordinary_tile": ordinary_tile,
	}

func _footprint_rect_from_presentation(presentation: Dictionary, board_rect: Rect2, map_size: Vector2i) -> Rect2:
	var cells: Array = presentation.get("footprint_cells", [])
	var result := Rect2()
	var has_cell := false
	for cell_value in cells:
		if not (cell_value is Dictionary) or not bool(cell_value.get("in_bounds", false)):
			continue
		var tile := Vector2i(int(cell_value.get("x", -1)), int(cell_value.get("y", -1)))
		var cell_rect := _tile_rect_from_metrics(board_rect, map_size, tile)
		result = result.merge(cell_rect) if has_cell else cell_rect
		has_cell = true
	return result

func _rect_from_payload(value: Variant) -> Rect2:
	var payload: Dictionary = value if value is Dictionary else {}
	return Rect2(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("width", 0.0)),
		float(payload.get("height", 0.0))
	)

func _hero_command_marker_profile_exact(profile: Dictionary, focus_rect: Rect2, sprite_rect: Rect2 = Rect2()) -> bool:
	var extent := minf(focus_rect.size.x, focus_rect.size.y)
	var marker_rect := _rect_from_payload(profile.get("marker_rect", {}))
	var wing_length := float(profile.get("wing_length_px", 0.0))
	var wing_depth := float(profile.get("wing_depth_px", 0.0))
	var center_y := float(profile.get("center_y", 0.0))
	var ground_y := float(profile.get("ground_y", 0.0))
	var tick_length := float(profile.get("ground_tick_length_px", 0.0))
	var notch := float(profile.get("ground_notch_px", 0.0))
	var clears_sprite := true
	if sprite_rect.has_area():
		clears_sprite = marker_rect.position.x + wing_length <= sprite_rect.position.x \
			and marker_rect.end.x - wing_length >= sprite_rect.end.x \
			and ground_y > sprite_rect.end.y
	return String(profile.get("model", "")) == "open_lateral_command_wings_and_ground_tick" \
		and _rect_from_payload(profile.get("focus_rect", {})) == focus_rect \
		and marker_rect == focus_rect.grow(-maxf(1.25, extent * 0.035)) \
		and focus_rect.encloses(marker_rect) \
		and is_equal_approx(center_y, focus_rect.position.y + focus_rect.size.y * 0.48) \
		and is_equal_approx(wing_length, maxf(2.5, extent * 0.075)) \
		and is_equal_approx(wing_depth, maxf(3.0, extent * 0.085)) \
		and center_y - wing_depth >= marker_rect.position.y \
		and center_y + wing_depth <= marker_rect.end.y \
		and is_equal_approx(ground_y, focus_rect.position.y + focus_rect.size.y * 0.82) \
		and is_equal_approx(tick_length, maxf(6.0, extent * 0.18)) \
		and is_equal_approx(notch, maxf(1.5, extent * 0.035)) \
		and marker_rect.position.x <= marker_rect.get_center().x - tick_length * 0.5 \
		and marker_rect.end.x >= marker_rect.get_center().x + tick_length * 0.5 \
		and ground_y - notch >= marker_rect.position.y \
		and ground_y <= marker_rect.end.y \
		and float(profile.get("line_width_px", 0.0)) >= 1.25 \
		and float(profile.get("shadow_width_px", 0.0)) > float(profile.get("line_width_px", 0.0)) \
		and is_equal_approx(float(profile.get("marker_alpha", 0.0)), 0.82) \
		and is_equal_approx(float(profile.get("shadow_alpha", 0.0)), 0.40) \
		and bool(profile.get("antialiased", false)) \
		and not bool(profile.get("continuous_outline", true)) \
		and is_zero_approx(float(profile.get("interior_fill_alpha", -1.0))) \
		and clears_sprite

func _tile_rect_from_metrics(board_rect: Rect2, map_size: Vector2i, tile: Vector2i) -> Rect2:
	var cell_size := board_rect.size / Vector2(float(maxi(map_size.x, 1)), float(maxi(map_size.y, 1)))
	return Rect2(board_rect.position + Vector2(tile.x, tile.y) * cell_size, cell_size)

func _configure_hero_fixture(session) -> void:
	var source_heroes: Array = session.overworld.get("player_heroes", [])
	var source: Dictionary = source_heroes[0].duplicate(true)
	var heroes: Array = []
	var faction_ids: Array = EXPECTED_FACTION_ASSETS.keys()
	var town_footprint_tile := _player_town_footprint_hero_tile(session)
	for index in range(faction_ids.size()):
		var faction_id := String(faction_ids[index])
		var hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var template := ContentService.get_hero(hero_id)
		var hero := source.duplicate(true)
		hero["id"] = hero_id
		hero["name"] = String(template.get("name", hero_id))
		hero["is_primary"] = index == 0
		hero["position"] = {"x": town_footprint_tile.x, "y": town_footprint_tile.y} if index == 0 else {"x": 3 + index * 3, "y": 4}
		heroes.append(hero)
	session.hero_id = String(heroes[0].get("id", ""))
	session.overworld["player_heroes"] = heroes
	session.overworld["active_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["primary_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["hero"] = heroes[0].duplicate(true)
	session.overworld["hero_position"] = heroes[0].get("position", {}).duplicate(true)
	session.overworld["army"] = heroes[0].get("army", {}).duplicate(true)
	session.overworld["movement"] = heroes[0].get("movement", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for hero in heroes:
		var position: Dictionary = hero.get("position", {})
		var x := int(position.get("x", -1))
		var y := int(position.get("y", -1))
		visible_tiles[y][x] = true
		explored_tiles[y][x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": heroes.size(),
		"explored_count": heroes.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _player_town_footprint_hero_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			var entry := Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1)))
			var right_footprint_cell := entry + Vector2i(1, 0)
			return right_footprint_cell if right_footprint_cell.x < map_size.x else entry - Vector2i(1, 0)
	return Vector2i(-1, -1)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
