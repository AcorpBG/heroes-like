extends Node

const SCENARIO_ID := "ninefold-confluence"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if scenario.is_empty():
		_fail("Ninefold smoke: scenario was not loaded by ContentService.")
		return

	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"hard",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session = SessionState.set_active_session(session)

	var map_size := OverworldRules.derive_map_size(session)
	if map_size != Vector2i(64, 64):
		_fail("Ninefold smoke: derived map size was %s, expected 64x64." % map_size)
		return
	if session.overworld.get("resource_nodes", []).size() < 47:
		_fail("Ninefold smoke: breadth resource-node placements did not seed into session state.")
		return
	if session.overworld.get("towns", []).size() < 6:
		_fail("Ninefold smoke: six-faction town placements did not seed into session state.")
		return
	if session.overworld.get("enemy_states", []).size() < 5:
		_fail("Ninefold smoke: hostile faction pressure states did not seed into session state.")
		return

	var basalt_profile := OverworldRules.terrain_profile_at(session, 60, 36)
	if String(basalt_profile.get("id", "")) != "biome_subterranean_underways":
		_fail("Ninefold smoke: Basalt Gatehouse did not land in the underway biome band.")
		return

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_snapshot"):
		_fail("Ninefold smoke: OverworldShell did not expose validation_snapshot.")
		return
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_size: Dictionary = snapshot.get("map_size", {})
	if int(snapshot_size.get("x", 0)) != 64 or int(snapshot_size.get("y", 0)) != 64:
		_fail("Ninefold smoke: OverworldShell snapshot did not retain the 64x64 map size.")
		return
	if String(snapshot.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Ninefold smoke: OverworldShell snapshot is not bound to Ninefold Confluence.")
		return
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	if viewport_metrics.is_empty():
		_fail("Ninefold smoke: OverworldShell snapshot did not expose map viewport metrics.")
		return
	if bool(viewport_metrics.get("full_map_visible", true)):
		_fail("Ninefold smoke: 64x64 overworld map is still fully visible instead of using tactical framing.")
		return
	if bool(viewport_metrics.get("fit_entire_map", true)):
		_fail("Ninefold smoke: 64x64 overworld map was treated as a fit-entire-map case.")
		return
	var visible_columns := float(viewport_metrics.get("visible_tile_columns", 0.0))
	var visible_rows := float(viewport_metrics.get("visible_tile_rows", 0.0))
	var visible_area := float(viewport_metrics.get("visible_tile_area", 0.0))
	if visible_columns <= 0.0 or visible_rows <= 0.0 or visible_area <= 0.0:
		_fail("Ninefold smoke: tactical viewport metrics were empty: %s." % viewport_metrics)
		return
	if visible_columns >= 32.0 or visible_rows >= 32.0 or visible_area > 220.0:
		_fail("Ninefold smoke: tactical viewport still shows too much of the 64x64 map: %s." % viewport_metrics)
		return
	var focus_tile: Dictionary = viewport_metrics.get("camera_focus_tile", {})
	if int(focus_tile.get("x", -1)) != 23 or int(focus_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: tactical viewport is not centered on Mira's starting hero tile: %s." % viewport_metrics)
		return
	if not _assert_large_map_marker_readability(shell):
		return
	if not shell.has_method("validation_pan_map") or not shell.has_method("validation_focus_map_on_hero"):
		_fail("Ninefold smoke: OverworldShell did not expose large-map pan validation hooks.")
		return
	var pan_result: Dictionary = shell.call("validation_pan_map", 6, 0)
	if not bool(pan_result.get("ok", false)):
		_fail("Ninefold smoke: 64x64 overworld map did not pan when requested: %s." % pan_result)
		return
	var panned_metrics: Dictionary = pan_result.get("after", {})
	var panned_focus: Dictionary = panned_metrics.get("camera_focus_tile", {})
	if not bool(panned_metrics.get("manual_camera", false)) or int(panned_focus.get("x", 0)) <= int(focus_tile.get("x", 0)):
		_fail("Ninefold smoke: map pan did not move the manual camera east: %s." % pan_result)
		return
	var panned_bounds: Dictionary = panned_metrics.get("visible_bounds", {})
	var original_bounds: Dictionary = viewport_metrics.get("visible_bounds", {})
	if int(panned_bounds.get("x", 0)) <= int(original_bounds.get("x", 0)):
		_fail("Ninefold smoke: visible tile bounds did not scroll east after panning: %s." % pan_result)
		return
	var focus_result: Dictionary = shell.call("validation_focus_map_on_hero")
	var refocused_metrics: Dictionary = focus_result.get("after", {})
	if bool(refocused_metrics.get("manual_camera", true)):
		_fail("Ninefold smoke: Home/focus validation did not return camera control to the active hero: %s." % focus_result)
		return

	var progress_result: Dictionary = shell.call("validation_try_progress_action")
	if not bool(progress_result.get("ok", false)):
		_fail("Ninefold smoke: OverworldShell could not advance one safe step on the 64x64 scenario.")
		return
	if not _assert_homm_road_topology(shell, session):
		return
	if not _assert_neighbor_terrain_transitions(shell, session):
		return

	get_tree().quit(0)

func _assert_neighbor_terrain_transitions(shell: Node, session) -> bool:
	var receiver_tile := Vector2i(23, 23)
	var source_tile := Vector2i(22, 23)
	_reveal_validation_tiles(session, [receiver_tile, source_tile])
	shell.call("validation_select_tile", receiver_tile.x, receiver_tile.y)
	var presentation: Dictionary = shell.call("validation_tile_presentation", receiver_tile.x, receiver_tile.y)
	var terrain: Dictionary = presentation.get("terrain_presentation", {})
	if (
		String(terrain.get("terrain", "")) != "grass"
		or String(terrain.get("terrain_group", "")) != "grasslands"
		or not bool(terrain.get("neighbor_aware_transitions", false))
			or String(terrain.get("transition_calculation_model", "")) != "homm3_table_driven_bridge_base_lookup"
			or String(terrain.get("transition_edge_model", "")) != "bridge_or_shoreline_atlas_frame_lookup"
			or String(terrain.get("transition_edge_mask", "")) != "NW"
			or "plains" not in terrain.get("transition_source_terrain_ids", [])
			or "grasslands" not in terrain.get("transition_source_groups", [])
			or int(terrain.get("edge_transition_count", 0)) != 2
			or String(terrain.get("homm3_selection_kind", "")) != "bridge_transition"
			or String(terrain.get("homm3_bridge_family", "")) != "dirt"
			or String(terrain.get("transition_shape_model", "")) != "homm3_base_atlas_frame"
	):
		_fail("Ninefold smoke: terrain transition was not selected from the HoMM3 bridge-table lookup at the grass/plains boundary: %s." % presentation)
		return false
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	var found_west_plains := false
	for source_value in sources:
		var source: Dictionary = source_value
		if String(source.get("source_terrain", "")) == "plains" and String(source.get("direction", "")) == "W" and String(source.get("relation_kind", "")) == "bridge_base_resolution":
			found_west_plains = true
			break
	if not found_west_plains:
		_fail("Ninefold smoke: terrain transition did not expose its neighboring source terrain and direction: %s." % presentation)
		return false
	var shoreline_tile := Vector2i(49, 0)
	var shoreline_source := Vector2i(48, 0)
	_reveal_validation_tiles(session, [shoreline_tile, shoreline_source])
	var shoreline_presentation: Dictionary = shell.call("validation_tile_presentation", shoreline_tile.x, shoreline_tile.y)
	var shoreline: Dictionary = shoreline_presentation.get("terrain_presentation", {})
	if String(shoreline.get("homm3_selection_kind", "")) != "water_shoreline" or not bool(shoreline.get("homm3_shoreline_specific", false)) or String(shoreline.get("homm3_terrain_atlas", "")) != "watrtl":
		_fail("Ninefold smoke: water/coast terrain did not use shoreline-specific HoMM3 lookup beside land: %s." % shoreline_presentation)
		return false
	if not _assert_direct_dirt_swamp_transition(shell, session):
		return false
	if not _assert_horizontal_transition_orientation(shell, session):
		return false
	return true

func _assert_direct_dirt_swamp_transition(shell: Node, session) -> bool:
	var swamp_receiver := Vector2i(28, 13)
	var dirt_source := Vector2i(27, 13)
	_reveal_validation_tiles(session, [swamp_receiver, dirt_source])
	var swamp_presentation: Dictionary = shell.call("validation_tile_presentation", swamp_receiver.x, swamp_receiver.y)
	var swamp_terrain: Dictionary = swamp_presentation.get("terrain_presentation", {})
	if (
		String(swamp_terrain.get("terrain", "")) != "swamp"
		or String(swamp_terrain.get("homm3_terrain_family", "")) != "swamp"
		or String(swamp_terrain.get("homm3_terrain_atlas", "")) != "swmptl"
		or String(swamp_terrain.get("transition_edge_mask", "")) != "W"
		or String(swamp_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(swamp_terrain.get("homm3_bridge_family", "")) != "dirt"
		or String(swamp_terrain.get("homm3_bridge_resolution_model", "")) != "direct_family_pair_lookup"
		or not _transition_sources_include_bridge(swamp_terrain, "W", "plains", "dirt", "direct_family_pair_lookup")
	):
		_fail("Ninefold smoke: direct swamp/dirt transition routed away from the direct dirt bridge pair: %s." % swamp_presentation)
		return false
	return true

func _assert_horizontal_transition_orientation(shell: Node, session) -> bool:
	var east_receiver := Vector2i(26, 63)
	var east_source := Vector2i(27, 63)
	_reveal_validation_tiles(session, [east_receiver, east_source])
	var east_presentation: Dictionary = shell.call("validation_tile_presentation", east_receiver.x, east_receiver.y)
	var east_terrain: Dictionary = east_presentation.get("terrain_presentation", {})
	if (
		String(east_terrain.get("terrain", "")) != "grass"
		or String(east_terrain.get("transition_edge_mask", "")) != "E"
		or String(east_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(east_terrain.get("homm3_terrain_frame", "")) != "00_15"
		or not _transition_sources_include(east_terrain, "E", "plains")
	):
		_fail("Ninefold smoke: HoMM3 east-side grass/plains transition is horizontally reversed or missing its right-side dirt frame: %s." % east_presentation)
		return false

	var west_receiver := Vector2i(26, 0)
	var west_source := Vector2i(25, 0)
	_reveal_validation_tiles(session, [west_receiver, west_source])
	var west_presentation: Dictionary = shell.call("validation_tile_presentation", west_receiver.x, west_receiver.y)
	var west_terrain: Dictionary = west_presentation.get("terrain_presentation", {})
	if (
		String(west_terrain.get("terrain", "")) != "grass"
		or String(west_terrain.get("transition_edge_mask", "")) != "W"
		or String(west_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(west_terrain.get("homm3_terrain_frame", "")) != "00_04"
		or not _transition_sources_include(west_terrain, "W", "plains")
	):
		_fail("Ninefold smoke: HoMM3 west-side grass/plains transition is horizontally reversed or missing its left-side dirt frame: %s." % west_presentation)
		return false
	return true

func _transition_sources_include(terrain: Dictionary, direction: String, source_terrain: String) -> bool:
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if String(source.get("direction", "")) == direction and String(source.get("source_terrain", "")) == source_terrain:
			return true
	return false

func _transition_sources_include_bridge(terrain: Dictionary, direction: String, source_terrain: String, bridge_family: String, bridge_model: String) -> bool:
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("direction", "")) == direction
			and String(source.get("source_terrain", "")) == source_terrain
			and String(source.get("resolved_bridge_family", "")) == bridge_family
			and String(source.get("bridge_resolution_model", "")) == bridge_model
			and bool(source.get("uses_direct_bridge_pair", false))
		):
			return true
	return false

func _assert_homm_road_topology(shell: Node, session) -> bool:
	var vertical_tile := Vector2i(23, 30)
	var horizontal_tile := Vector2i(26, 42)
	var intersection_tile := Vector2i(23, 42)
	var straight_tile := Vector2i(20, 45)
	_reveal_validation_tiles(session, [vertical_tile, horizontal_tile, intersection_tile, straight_tile])

	shell.call("validation_select_tile", vertical_tile.x, vertical_tile.y)
	var vertical_presentation: Dictionary = shell.call("validation_tile_presentation", vertical_tile.x, vertical_tile.y)
	var vertical_terrain: Dictionary = vertical_presentation.get("terrain_presentation", {})
	if String(vertical_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(vertical_terrain.get("road_same_type_adjacency", false)):
		_fail("Ninefold smoke: vertical road did not rebuild from 4-neighbor same-type road tiles: %s." % vertical_presentation)
		return false
	if String(vertical_terrain.get("road_connection_key", "")) != "N+S" or int(vertical_terrain.get("road_connection_count", 0)) != 2:
		_fail("Ninefold smoke: vertical road run did not expose clean N+S topology: %s." % vertical_presentation)
		return false
	if not bool(vertical_terrain.get("road_vertical_centered", false)) or String(vertical_terrain.get("road_vertical_lane", "")) != "orthogonal_mask_frame" or bool(vertical_terrain.get("road_horizontal_edge_riding", true)) or not bool(vertical_terrain.get("road_straight_tile_piece", false)):
		_fail("Ninefold smoke: vertical road run did not report the HoMM3 orthogonal-mask straight frame: %s." % vertical_presentation)
		return false
	if bool(vertical_terrain.get("road_joint_cap", true)):
		_fail("Ninefold smoke: vertical road straight still reports a center joint cap: %s." % vertical_presentation)
		return false

	shell.call("validation_select_tile", horizontal_tile.x, horizontal_tile.y)
	var horizontal_presentation: Dictionary = shell.call("validation_tile_presentation", horizontal_tile.x, horizontal_tile.y)
	var horizontal_terrain: Dictionary = horizontal_presentation.get("terrain_presentation", {})
	if String(horizontal_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or String(horizontal_terrain.get("road_connection_key", "")) != "E+W":
		_fail("Ninefold smoke: horizontal road run did not use same-type E+W topology: %s." % horizontal_presentation)
		return false
	if bool(horizontal_terrain.get("road_horizontal_edge_riding", true)) or String(horizontal_terrain.get("road_horizontal_lane", "")) != "orthogonal_mask_frame" or bool(horizontal_terrain.get("road_vertical_centered", true)) or not bool(horizontal_terrain.get("road_straight_tile_piece", false)):
		_fail("Ninefold smoke: horizontal road run did not report the HoMM3 orthogonal-mask straight frame: %s." % horizontal_presentation)
		return false
	if bool(horizontal_terrain.get("road_joint_cap", true)):
		_fail("Ninefold smoke: horizontal road straight still reports a center joint cap: %s." % horizontal_presentation)
		return false

	shell.call("validation_select_tile", intersection_tile.x, intersection_tile.y)
	var intersection_presentation: Dictionary = shell.call("validation_tile_presentation", intersection_tile.x, intersection_tile.y)
	var intersection_terrain: Dictionary = intersection_presentation.get("terrain_presentation", {})
	if String(intersection_terrain.get("road_connection_key", "")) != "N+E" or int(intersection_terrain.get("road_connection_count", 0)) != 2:
		_fail("Ninefold smoke: road corner tile did not select from orthogonal same-type neighbors only: %s." % intersection_presentation)
		return false
	if not bool(intersection_terrain.get("road_joint_cap", false)) or bool(intersection_terrain.get("road_horizontal_edge_riding", true)) or not bool(intersection_terrain.get("road_vertical_centered", false)):
		_fail("Ninefold smoke: road corner tile did not keep the 4-neighbor joint metadata: %s." % intersection_presentation)
		return false

	shell.call("validation_select_tile", straight_tile.x, straight_tile.y)
	var straight_presentation: Dictionary = shell.call("validation_tile_presentation", straight_tile.x, straight_tile.y)
	var straight_terrain: Dictionary = straight_presentation.get("terrain_presentation", {})
	if String(straight_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or String(straight_terrain.get("road_connection_key", "")) != "":
		_fail("Ninefold smoke: diagonal-only neighboring road tiles were not suppressed by 4-neighbor topology: %s." % straight_presentation)
		return false
	if int(straight_terrain.get("road_connection_count", 0)) != 0 or bool(straight_terrain.get("road_diagonal_tile_piece", true)) or String(straight_terrain.get("road_diagonal_piece_model", "")) != "":
		_fail("Ninefold smoke: diagonal road metadata still reports diagonal tile pieces: %s." % straight_presentation)
		return false
	if not bool(straight_terrain.get("road_joint_cap", false)) or bool(straight_terrain.get("road_diagonal_connections", true)):
		_fail("Ninefold smoke: isolated 4-neighbor road tile did not report diagonal suppression cleanly: %s." % straight_presentation)
		return false
	return true

func _reveal_validation_tiles(session, tiles: Array) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles := []
	var explored_tiles := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		visible_tiles[tile.y][tile.x] = true
		explored_tiles[tile.y][tile.x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": tiles.size(),
		"explored_count": tiles.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _assert_large_map_marker_readability(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		_fail("Ninefold smoke: OverworldShell did not expose tile marker presentation validation.")
		return false
	var town_tile := Vector2i(23, 26)
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not _assert_marker_style(town_presentation, "town", false):
		return false
	if not _assert_town_footprint_profile(shell, town_presentation):
		return false
	var terrain_presentation: Dictionary = town_presentation.get("terrain_presentation", {})
	if String(terrain_presentation.get("rendering_mode", "")) != "homm3_local_reference_prototype" or bool(terrain_presentation.get("uses_sampled_texture", true)) or bool(terrain_presentation.get("generated_source_primary", true)) or not bool(terrain_presentation.get("uses_homm3_local_prototype", false)):
		_fail("Ninefold smoke: large-map starting terrain is not using the HoMM3 local prototype terrain tile bank: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("primary_base_model", "")) != "homm3_local_reference_prototype" or String(terrain_presentation.get("terrain_noise_profile", "")) != "homm3_extracted_atlas_frame":
		_fail("Ninefold smoke: large-map starting terrain does not expose the HoMM3 extracted-atlas base model: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("terrain_variant_selection", "")) != "table_driven_neighbor_mask_with_stable_interior_base" or String(terrain_presentation.get("homm3_terrain_lookup_model", "")) != "table_driven_bridge_base_8_neighbor":
		_fail("Ninefold smoke: large-map starting grasslands terrain does not expose the table-driven HoMM3 stable-base lookup contract: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("homm3_interior_frame_selection", "")) != "single_stable_base_frame" or bool(terrain_presentation.get("homm3_uses_interior_variant_cycle", true)):
		_fail("Ninefold smoke: large-map starting terrain still reports HoMM3 interior patch-variant cycling: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(terrain_presentation.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(terrain_presentation.get("explored_intertile_seams", true)):
		_fail("Ninefold smoke: large-map visible terrain still reports per-cell black grid seams: %s." % town_presentation)
		return false
	if not bool(terrain_presentation.get("road_overlay", false)) or String(terrain_presentation.get("road_overlay_id", "")) != "road_dirt" or not bool(terrain_presentation.get("road_overlay_art", false)) or String(terrain_presentation.get("road_shape_model", "")) != "homm3_4_neighbor_overlay_lookup":
		_fail("Ninefold smoke: large-map starting road is not represented as a HoMM3 4-neighbor overlay: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(terrain_presentation.get("road_same_type_adjacency", false)) or not bool(terrain_presentation.get("road_orthogonal_mask_only", false)):
		_fail("Ninefold smoke: large-map starting road is not using 4-neighbor same-type adjacency topology: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(terrain_presentation.get("road_joint_cap", false)):
		_fail("Ninefold smoke: large-map starting road intersection does not expose the connection-aware joint cap contract: %s." % town_presentation)
		return false
	var town_readability: Dictionary = town_presentation.get("marker_readability", {})
	if not bool(town_readability.get("hero_emphasis", false)) or not bool(town_readability.get("selection_emphasis", false)):
		_fail("Ninefold smoke: active hero/current-selection emphasis is not readable on the large starting town tile: %s." % town_presentation)
		return false
	if not _assert_hero_presence_correction(town_readability, town_presentation):
		return false
	var town_art: Dictionary = town_presentation.get("art_presentation", {})
	var town_asset_ids: Array = town_art.get("sprite_asset_ids", [])
	if not bool(town_art.get("uses_asset_sprite", false)) or "frontier_town" not in town_asset_ids or bool(town_art.get("fallback_procedural_marker", true)):
		_fail("Ninefold smoke: large-map starting town is not using the default frontier town sprite: %s." % town_presentation)
		return false
	if String(town_art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or bool(town_art.get("town_base_ellipse", true)) or bool(town_art.get("town_cast_shadow", true)):
		_fail("Ninefold smoke: large-map starting town sprite did not use the corrected no-ellipse/no-cast-shadow grounding: %s." % town_presentation)
		return false

	var resource_tile := Vector2i(23, 24)
	var resource_presentation: Dictionary = shell.call("validation_tile_presentation", resource_tile.x, resource_tile.y)
	if not _assert_marker_style(resource_presentation, "resource", false):
		return false
	var art_presentation: Dictionary = resource_presentation.get("art_presentation", {})
	if bool(art_presentation.get("uses_asset_sprite", true)) or not bool(art_presentation.get("fallback_procedural_marker", false)):
		_fail("Ninefold smoke: unmapped large-map resource site did not keep procedural marker fallback: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_silhouette_model", "")) != "family_specific_procedural_world_object":
		_fail("Ninefold smoke: unmapped large-map resource site did not report family-specific procedural world-object fallback: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate" or bool(art_presentation.get("fallback_shared_marker_plate", true)) or bool(art_presentation.get("fallback_upper_mass_backdrop", true)) or bool(art_presentation.get("fallback_foreground_lip", true)):
		_fail("Ninefold smoke: unmapped large-map resource site did not report the corrected no-plate/no-backdrop/no-lip fallback grounding: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_contact_shadow_model", "")) != "localized_object_contact_shadow":
		_fail("Ninefold smoke: unmapped large-map resource site did not report localized contact shadow grounding: %s." % resource_presentation)
		return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	var is_town := expected_kind == "town"
	var uses_procedural_fallback := bool(readability.get("procedural_world_silhouette", false))
	var art: Dictionary = presentation.get("art_presentation", {})
	var uses_mapped_sprite := bool(art.get("uses_asset_sprite", false)) and not is_town
	if expected_kind not in object_kinds:
		_fail("Ninefold smoke: expected %s marker kind was missing on the large map: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("ground_anchor", false)):
		_fail("Ninefold smoke: large-map %s marker lacks terrain-grounded placement metadata: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object":
		_fail("Ninefold smoke: large-map %s marker no longer reports object-first footprint presence: %s." % [expected_kind, presentation])
		return false
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else ("ground_contact_without_foreground_lip" if uses_procedural_fallback else ("sprite_contact_without_foreground_lip" if uses_mapped_sprite else ""))
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		_fail("Ninefold smoke: large-map %s marker no longer reports the expected foreground contact model: %s." % [expected_kind, presentation])
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif uses_procedural_fallback:
		if not _assert_procedural_fallback_grounding(readability, expected_kind, presentation):
			return false
	elif uses_mapped_sprite:
		if not _assert_mapped_sprite_grounding(readability, expected_kind, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		_fail("Ninefold smoke: large-map %s marker lacks a terrain-grounded anchor: %s." % [expected_kind, presentation])
		return false
	else:
		_fail("Ninefold smoke: large-map %s marker used an unsupported non-town/non-procedural/non-mapped grounding path: %s." % [expected_kind, presentation])
		return false
	if int(readability.get("footprint_width_tiles", 0)) <= 0 or int(readability.get("footprint_height_tiles", 0)) <= 0:
		_fail("Ninefold smoke: large-map %s marker does not expose footprint dimensions: %s." % [expected_kind, presentation])
		return false
	if expected_kind == "town":
		if int(readability.get("footprint_width_tiles", 0)) != 3 or int(readability.get("footprint_height_tiles", 0)) != 2:
			_fail("Ninefold smoke: large-map town marker must present as a 3x2 footprint: %s." % presentation)
			return false
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		if not bool(town_presentation.get("has_town_footprint", false)) or String(town_presentation.get("presentation_model", "")) != "town_3x2_footprint_bottom_middle_entry":
			_fail("Ninefold smoke: large-map town metadata does not expose the 3x2 presentation model: %s." % presentation)
			return false
		if String(town_presentation.get("entry_role", "")) != "bottom_middle_visit_approach" or not bool(town_presentation.get("entry_is_visit_tile", false)):
			_fail("Ninefold smoke: large-map town does not expose the bottom-middle visit approach tile: %s." % presentation)
			return false
		if not bool(town_presentation.get("is_entry_tile", false)) or String(town_presentation.get("tile_role", "")) != "bottom_middle_visit_approach":
			_fail("Ninefold smoke: large-map starting town tile is not reported as the entry approach: %s." % presentation)
			return false
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
			_fail("Ninefold smoke: large-map town must preserve blocked non-entry metadata without visible helper apron/gate/glyph cues: %s." % presentation)
			return false
	var min_anchor_width := 0.36 if uses_mapped_sprite else (0.40 if uses_procedural_fallback else 0.60)
	var min_anchor_height := 0.06 if uses_mapped_sprite else (0.12 if uses_procedural_fallback else 0.20)
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < min_anchor_width or float(readability.get("footprint_anchor_height_fraction", 0.0)) < min_anchor_height:
		_fail("Ninefold smoke: large-map %s footprint anchor is too small for object-first tactical framing: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("ui_badge_plate", true)):
		_fail("Ninefold smoke: large-map %s marker regressed to a UI badge plate: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		_fail("Ninefold smoke: large-map %s marker is too small for tactical framing: %s." % [expected_kind, presentation])
		return false
	if remembered:
		if is_town:
			if bool(readability.get("memory_echo", false)) or String(readability.get("town_remembered_treatment", "")) != "ghosted_sprite_without_echo_plate":
				_fail("Ninefold smoke: remembered large-map town should use ghosted sprite treatment without the removed echo plate: %s." % presentation)
				return false
		elif not bool(readability.get("memory_echo", false)) or float(readability.get("remembered_marker_alpha", 0.0)) < 0.80:
			_fail("Ninefold smoke: remembered large-map %s marker is too faint: %s." % [expected_kind, presentation])
			return false
	else:
		var visible_grid_suppressed := String(readability.get("visible_terrain_grid_mode", "")) == "fog_boundary_only" and float(readability.get("grid_alpha", 1.0)) <= 0.08 and not bool(readability.get("explored_intertile_seams", true))
		var anchor_floor := 0.12 if uses_mapped_sprite else (0.16 if uses_procedural_fallback else 0.30)
		if bool(readability.get("memory_echo", false)) or (not is_town and (float(readability.get("anchor_alpha", 0.0)) < anchor_floor or float(readability.get("outline_alpha", 0.0)) < 0.85 or not visible_grid_suppressed)):
			_fail("Ninefold smoke: visible large-map %s marker grounding or map contrast regressed: %s." % [expected_kind, presentation])
			return false
	return true

func _assert_procedural_fallback_grounding(readability: Dictionary, expected_kind: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "family_terrain_contact_scuffs":
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the old terrain-ellipse marker anchor: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("procedural_fallback_grounding", false)) or String(readability.get("procedural_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate":
		_fail("Ninefold smoke: procedural large-map %s fallback does not expose the contact-scuff grounding model: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("contrast_plate", true)) or bool(readability.get("shared_marker_plate", true)) or float(readability.get("plate_alpha", 1.0)) > 0.01 or float(readability.get("ring_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback still exposes the shared marker plate or ring: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the broad terrain quieting bed: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("procedural_contact_disturbance", false)) or String(readability.get("procedural_contact_disturbance_model", "")) != "thin_terrain_contact_disturbance":
		_fail("Ninefold smoke: procedural large-map %s fallback lacks the thin terrain contact disturbance: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("procedural_contact_disturbance_alpha", 0.0)) < 0.16 or float(readability.get("procedural_contact_disturbance_alpha", 1.0)) > 0.24:
		_fail("Ninefold smoke: procedural large-map %s fallback contact disturbance alpha is outside range: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: procedural large-map %s fallback still reports upper-mass backdrop/shadow support: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or not bool(readability.get("procedural_contact_marks", false)):
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the foreground lip instead of contact marks: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("depth_cue_model", "")) != "localized_contact_shadow_without_backdrop":
		_fail("Ninefold smoke: procedural large-map %s fallback does not report localized contact-shadow depth: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("directional_contact_shadow", true)) or not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_object_contact_shadow":
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the shared directional cast shadow: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("contact_shadow_alpha", 0.0)) < 0.24 or bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback lacks localized contact shadow or still reports base occlusion pads: %s." % [expected_kind, presentation])
		return false
	return true

func _assert_town_grounding_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "town_contact_cues_no_base_ellipse":
		_fail("Ninefold smoke: large-map town still reports a base ellipse anchor: %s." % presentation)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports a filled terrain underlay/quieting bed: %s." % presentation)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: large-map town still reports upper-mass shadow/backdrop treatment: %s." % presentation)
		return false
	if String(readability.get("depth_cue_model", "")) != "town_contact_line_without_cast_shadow" or bool(readability.get("directional_contact_shadow", true)) or float(readability.get("contact_shadow_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports directional cast-shadow depth cues: %s." % presentation)
		return false
	if bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports foreground base occlusion pads: %s." % presentation)
		return false
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		_fail("Ninefold smoke: large-map town grounding metadata does not describe the no-ellipse presentation: %s." % presentation)
		return false
	if bool(readability.get("town_base_ellipse", true)) or bool(readability.get("town_underlay", true)) or bool(readability.get("town_cast_shadow", true)) or not bool(readability.get("town_contact_cue", false)):
		_fail("Ninefold smoke: large-map town grounding flags did not remove base ellipse/underlay/cast shadow while preserving contact cues: %s." % presentation)
		return false
	var town_presentation: Dictionary = presentation.get("town_presentation", {})
	if bool(town_presentation.get("base_ellipse", true)) or bool(town_presentation.get("filled_underlay", true)) or bool(town_presentation.get("cast_shadow", true)):
		_fail("Ninefold smoke: large-map town presentation payload still exposes the removed ellipse/underlay/shadow treatment: %s." % presentation)
		return false
	if String(town_presentation.get("footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		_fail("Ninefold smoke: large-map town footprint cue metadata does not describe the cue-free 3x2 contract: %s." % presentation)
		return false
	if bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
		_fail("Ninefold smoke: large-map town presentation payload still exposes visible helper footprint/entry cues: %s." % presentation)
		return false
	return true

func _assert_hero_presence_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("hero_presence_model", "")) != "placed_world_hero_figure":
		_fail("Ninefold smoke: active hero does not report the placed world-figure presence model: %s." % presentation)
		return false
	if String(readability.get("hero_anchor_shape", "")) != "hero_foot_contact_shadow" or String(readability.get("hero_grounding_model", "")) != "hero_foot_contact_without_base_ellipse":
		_fail("Ninefold smoke: active hero still lacks the hero-specific foot-contact grounding model: %s." % presentation)
		return false
	if String(readability.get("hero_depth_cue_model", "")) != "hero_foot_contact_shadow_with_boot_occlusion":
		_fail("Ninefold smoke: active hero does not report boot-level depth/occlusion contact: %s." % presentation)
		return false
	if bool(readability.get("hero_badge_plate", true)) or bool(readability.get("hero_base_ellipse", true)) or bool(readability.get("hero_terrain_quieting_bed", true)) or bool(readability.get("hero_upper_mass_backdrop", true)) or bool(readability.get("hero_shared_marker_plate", true)):
		_fail("Ninefold smoke: active hero regressed toward the staged badge/ellipse support: %s." % presentation)
		return false
	if not bool(readability.get("hero_world_figure", false)) or not bool(readability.get("hero_foot_contact_shadow", false)) or not bool(readability.get("hero_boot_occlusion", false)):
		_fail("Ninefold smoke: active hero lacks world-figure, foot-shadow, or boot-occlusion cues: %s." % presentation)
		return false
	if float(readability.get("hero_contact_shadow_alpha", 0.0)) < 0.30 or float(readability.get("hero_boot_occlusion_alpha", 0.0)) < 0.34:
		_fail("Ninefold smoke: active hero foot-contact depth cues are too faint: %s." % presentation)
		return false
	if float(readability.get("hero_foot_anchor_width_fraction", 0.0)) < 0.50 or float(readability.get("hero_foot_anchor_height_fraction", 0.0)) < 0.12:
		_fail("Ninefold smoke: active hero foot-contact anchor is too small for the large-map tactical view: %s." % presentation)
		return false
	if String(readability.get("hero_selection_ring_source", "")) != "tile_focus":
		_fail("Ninefold smoke: active hero selection readability is no longer tied to the tile focus ring: %s." % presentation)
		return false
	return true

func _assert_town_footprint_profile(shell: Node, entry_presentation: Dictionary) -> bool:
	var profiles: Array = shell.call("validation_town_presentation_profiles")
	var matching_profile := {}
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		if String(profile.get("town_placement_id", "")) == "ninefold_embercourt_survey_camp":
			matching_profile = profile
			break
	if matching_profile.is_empty():
		_fail("Ninefold smoke: town presentation profiles did not include the starting survey camp: %s." % profiles)
		return false
	if int(matching_profile.get("footprint_width_tiles", 0)) != 3 or int(matching_profile.get("footprint_height_tiles", 0)) != 2:
		_fail("Ninefold smoke: starting town profile is not a 3x2 footprint: %s." % matching_profile)
		return false
	if int(matching_profile.get("blocked_footprint_cell_count", 0)) != 5 or int(matching_profile.get("off_map_footprint_cell_count", 0)) != 0:
		_fail("Ninefold smoke: in-bounds starting town should expose five blocked non-entry footprint cells: %s." % matching_profile)
		return false
	var entry_tile: Dictionary = matching_profile.get("entry_tile", {})
	if int(entry_tile.get("x", -1)) != 23 or int(entry_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: starting town entry tile moved away from the actual visit tile: %s." % matching_profile)
		return false
	var blocked_cells: Array = matching_profile.get("blocked_footprint_cells", [])
	if blocked_cells.is_empty():
		_fail("Ninefold smoke: starting town profile did not expose blocked non-entry cells: %s." % matching_profile)
		return false
	var first_blocked: Dictionary = blocked_cells[0]
	var blocked_presentation: Dictionary = shell.call("validation_tile_presentation", int(first_blocked.get("x", -1)), int(first_blocked.get("y", -1)))
	var blocked_town: Dictionary = blocked_presentation.get("town_presentation", {})
	if not bool(blocked_presentation.get("has_town_non_entry", false)) or bool(blocked_town.get("is_visit_tile", true)):
		_fail("Ninefold smoke: blocked town footprint tile did not read as non-entry: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	if not bool(blocked_town.get("presentation_blocked", false)) or String(blocked_town.get("tile_role", "")) != "blocked_non_entry_footprint":
		_fail("Ninefold smoke: blocked town footprint tile is not presentation-blocked: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	var entry_town: Dictionary = entry_presentation.get("town_presentation", {})
	if int(entry_town.get("blocked_footprint_cell_count", 0)) != 5:
		_fail("Ninefold smoke: entry tile did not expose the complete blocked-cell footprint: %s." % entry_presentation)
		return false
	return true

func _assert_mapped_sprite_grounding(readability: Dictionary, label: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "mapped_sprite_local_contact_scuffs" or not bool(readability.get("mapped_sprite_grounding", false)):
		_fail("Ninefold smoke: large-map mapped %s sprite does not report the local contact-scuff anchor: %s." % [label, presentation])
		return false
	if String(readability.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs" or not bool(readability.get("mapped_sprite_contact_disturbance", false)):
		_fail("Ninefold smoke: large-map mapped %s sprite lacks localized contact scuffs: %s." % [label, presentation])
		return false
	if String(readability.get("mapped_sprite_contact_disturbance_model", "")) != "thin_sprite_contact_disturbance" or float(readability.get("mapped_sprite_contact_disturbance_alpha", 0.0)) < 0.12:
		_fail("Ninefold smoke: large-map mapped %s sprite contact scuffs are missing or too faint: %s." % [label, presentation])
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map mapped %s sprite still reports a broad placement bed: %s." % [label, presentation])
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: large-map mapped %s sprite still reports upper-mass backdrop or vertical shadow support: %s." % [label, presentation])
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or bool(readability.get("base_occlusion_pads", true)) or bool(readability.get("shared_marker_plate", true)):
		_fail("Ninefold smoke: large-map mapped %s sprite still reports foreground lip/base pads/shared marker plate: %s." % [label, presentation])
		return false
	if not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_sprite_contact_shadow" or float(readability.get("contact_shadow_alpha", 0.0)) < 0.22:
		_fail("Ninefold smoke: large-map mapped %s sprite lacks localized contact-shadow readability: %s." % [label, presentation])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
