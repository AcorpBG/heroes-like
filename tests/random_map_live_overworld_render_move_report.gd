extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_LIVE_OVERWORLD_RENDER_MOVE_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "live-render-move-10184"
const MIN_IDLE_FPS := 9.0
const MOVE_LATENCY_BUDGET_MS := 2500
const POST_MOVE_FRAME_BUDGET_MS := 140.0

var _active_size_class_id := SIZE_CLASS_ID
var _active_seed := EXPLICIT_SEED
var _expected_map_size := Vector2i(36, 36)

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")

func _run() -> void:
	_active_size_class_id = OS.get_environment("RANDOM_MAP_LIVE_SIZE_CLASS").strip_edges()
	if _active_size_class_id == "":
		_active_size_class_id = SIZE_CLASS_ID
	_active_seed = OS.get_environment("RANDOM_MAP_LIVE_SEED").strip_edges()
	if _active_seed == "":
		_active_seed = EXPLICIT_SEED
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_menu_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	shell.call("validation_set_generated_seed", _active_seed)
	shell.call("validation_select_generated_size_class", _active_size_class_id)
	shell.call("validation_select_generated_water_mode", "land")
	shell.call("validation_set_generated_underground", false)
	await get_tree().process_frame

	var launch: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(launch.get("started", false)):
		_fail("Generated map launch did not start: %s" % JSON.stringify(launch))
		return
	var setup: Dictionary = launch.get("setup", {}) if launch.get("setup", {}) is Dictionary else {}
	_expected_map_size = OverworldRules.derive_map_size(SessionState.active_session)
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_live_render_move",
		{
			"scenario_id": String(launch.get("active_scenario_id", "")),
			"size_class_id": _active_size_class_id,
			"seed": _active_seed,
		}
	)
	var prepare_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not bool(prepare_result.get("ok", false)):
		_fail("Generated overworld handoff did not prepare: %s" % JSON.stringify(prepare_result))
		return
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1":
		_reveal_all_for_visual_capture(SessionState.active_session)

	var overworld = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld)
	for _i in range(8):
		await get_tree().process_frame
	var profile: Dictionary = AppRouter.validation_latest_overworld_handoff_profile()
	for _i in range(90):
		if not bool(profile.get("active", false)):
			break
		await get_tree().process_frame
		profile = AppRouter.validation_latest_overworld_handoff_profile()
	if bool(profile.get("active", false)):
		_fail("Generated overworld handoff profile did not finish: %s" % JSON.stringify(profile))
		return
	if overworld == null or not overworld.has_method("validation_snapshot"):
		_fail("Generated route did not instantiate OverworldShell validation hooks.")
		return

	var before_snapshot: Dictionary = overworld.validation_snapshot()
	if not _assert_generated_small_snapshot(before_snapshot, "before_move"):
		return
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_macro_lighting_render_profile(before_snapshot, "before_move"):
		return
	var map_visual_before := _map_visual_summary(overworld)
	if not _assert_generated_visual_summary(map_visual_before, "before_move"):
		return
	var terrain_transition_before := _terrain_transition_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_terrain_transition_summary(terrain_transition_before, "before_move"):
		return
	var fog_frontier_before := _fog_frontier_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") != "1" and not _assert_fog_frontier_summary(fog_frontier_before, "before_move"):
		return
	var road_surface_before := _road_surface_summary(overworld)
	if not _assert_generated_road_surface(road_surface_before, "before_move"):
		return
	var generated_presentation_authority_before := _generated_presentation_authority(SessionState.active_session)
	if not await _capture_if_requested("before_move"):
		return
	var idle_before := await _sample_fps(18)
	var move_start := Time.get_ticks_usec()
	var move_result: Dictionary = overworld.validation_try_progress_action()
	var move_latency_ms := float(Time.get_ticks_usec() - move_start) / 1000.0
	await get_tree().process_frame
	var post_move_frame_ms := await _single_frame_ms()
	var after_snapshot: Dictionary = overworld.validation_snapshot()
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_macro_lighting_render_profile(after_snapshot, "after_move"):
		return
	var map_visual_after := _map_visual_summary(overworld)
	if not _assert_generated_visual_summary(map_visual_after, "after_move"):
		return
	var terrain_transition_after := _terrain_transition_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_terrain_transition_summary(terrain_transition_after, "after_move"):
		return
	var fog_frontier_after := _fog_frontier_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") != "1" and not _assert_fog_frontier_summary(fog_frontier_after, "after_move"):
		return
	var road_surface_after := _road_surface_summary(overworld)
	if not _assert_generated_road_surface(road_surface_after, "after_move"):
		return
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1":
		if terrain_transition_after != terrain_transition_before:
			_fail("Generated terrain transition draw authority changed across movement/redraw.")
			return
	elif not _assert_natural_fog_terrain_transition_progression(terrain_transition_before, terrain_transition_after):
		return
	if road_surface_after != road_surface_before:
		_fail("Generated terrain-integrated road surface authority changed across movement/redraw.")
		return
	if map_visual_after.get("body_entries", []) != map_visual_before.get("body_entries", []):
		_fail("Generated blocker composition changed across movement/redraw.")
		return
	if _generated_presentation_authority(SessionState.active_session) != generated_presentation_authority_before:
		_fail("Generated object/body/map authority changed during presentation and movement validation.")
		return
	if not await _capture_if_requested("after_move"):
		return
	var idle_after := await _sample_fps(18)

	if not _assert_move_result(move_result, before_snapshot, after_snapshot, move_latency_ms, post_move_frame_ms, idle_before, idle_after):
		return
	var save_reload_source_authority := _generated_save_reload_authority(SessionState.active_session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(SessionState.active_session, 3)
	if not bool(save_result.get("ok", false)):
		_fail("Generated presentation authority did not save through the public manual path: %s" % JSON.stringify(save_result))
		return
	var restored_session = SaveService.restore_manual_session(3)
	if restored_session == null:
		_fail("Generated presentation authority did not restore through the public manual path.")
		return
	var save_reload_restored_authority := _generated_save_reload_authority(restored_session)
	if not _save_authority_values_equal(save_reload_restored_authority, save_reload_source_authority):
		_fail("Generated object/body/package authority changed across save and restore.")
		return
	var rebuilt_map_view = load("res://scenes/overworld/OverworldMapView.gd").new()
	add_child(rebuilt_map_view)
	rebuilt_map_view.set_map_state(
		restored_session,
		restored_session.overworld.get("map", []),
		OverworldRules.derive_map_size(restored_session),
		OverworldRules.hero_position(restored_session)
	)
	await get_tree().process_frame
	var rebuilt_visual_summary: Dictionary = rebuilt_map_view.validation_generated_object_visual_summary()
	if not _assert_generated_visual_summary(rebuilt_visual_summary, "save_restore_rebuild"):
		return
	if rebuilt_visual_summary.get("body_entries", []) != map_visual_before.get("body_entries", []):
		_fail("Generated blocker composition changed after a real save/restore session rebuild.")
		return
	rebuilt_map_view.queue_free()

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": _active_seed,
		"size_class_id": _active_size_class_id,
		"effective_seed": String(setup.get("normalized_seed", "")),
		"seed_source": String(setup.get("seed_source", "")),
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"handoff_profile_total_ms": int(profile.get("total_ms", -1)),
		"idle_fps_before_move": idle_before,
		"idle_fps_after_move": idle_after,
		"move_latency_ms": move_latency_ms,
		"post_move_frame_ms": post_move_frame_ms,
		"move_result": move_result,
		"before": _compact_snapshot(before_snapshot),
		"after": _compact_snapshot(after_snapshot),
		"map_viewport": after_snapshot.get("map_viewport", {}),
		"generated_visual_before": _compact_generated_visual_summary(map_visual_before),
		"generated_visual_after": _compact_generated_visual_summary(map_visual_after),
		"terrain_transition": terrain_transition_after,
		"fog_frontier_before": fog_frontier_before,
		"fog_frontier_after": fog_frontier_after,
		"road_surface": road_surface_after,
		"save_reload_authority_exact": true,
	})])
	get_tree().quit(0)

func _assert_menu_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_open_skirmish_stage",
		"validation_set_generated_seed",
		"validation_select_generated_size_class",
		"validation_select_generated_water_mode",
		"validation_set_generated_underground",
		"validation_start_generated_skirmish_staged",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing generated route validation hook %s." % method_name)
			return false
	return true

func _assert_generated_small_snapshot(snapshot: Dictionary, label: String) -> bool:
	if not bool(snapshot.get("generated_random_map", false)):
		_fail("%s snapshot is not generated: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	var map_size: Dictionary = snapshot.get("map_size", {}) if snapshot.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != _expected_map_size.x or int(map_size.get("height", 0)) != _expected_map_size.y:
		_fail("%s snapshot did not preserve generated %dx%d size: %s" % [label, _expected_map_size.x, _expected_map_size.y, JSON.stringify(map_size)])
		return false
	if String(snapshot.get("scenario_status", "")) != "in_progress" or String(snapshot.get("game_state", "")) != "overworld":
		_fail("%s snapshot is not a live overworld: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	return true

func _map_visual_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_generated_object_visual_summary"):
		return {}
	return map_view.call("validation_generated_object_visual_summary")

func _terrain_transition_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_tile_presentation"):
		return {}
	var relationship_tile_count := 0
	var generic_overlay_tile_count := 0
	var self_contained_tile_count := 0
	var inactive_homm3_overlay_tile_count := 0
	var irregular_inner_edge_count := 0
	var deterministic_seed_count := 0
	var explored_tile_count := 0
	var macro_lighting_tile_count := 0
	var macro_lighting_continuous_count := 0
	var macro_lighting_bounded_count := 0
	var macro_lighting_shared_corner_observation_count := 0
	var macro_lighting_corner_mismatch_count := 0
	var terrain_grain_tile_count := 0
	var terrain_grain_exact_count := 0
	var terrain_detail_drawn_count := 0
	var terrain_detail_exact_count := 0
	var terrain_detail_road_excluded_count := 0
	var terrain_detail_water_excluded_count := 0
	var terrain_detail_invalid_count := 0
	var water_ripple_water_tile_count := 0
	var water_ripple_drawn_count := 0
	var water_ripple_road_excluded_count := 0
	var water_ripple_exact_count := 0
	var water_ripple_invalid_count := 0
	var shoreline_tile_count := 0
	var shoreline_source_count := 0
	var shoreline_exact_count := 0
	var policy_ids: Dictionary = {}
	var surface_model_ids: Dictionary = {}
	var feather_band_counts: Dictionary = {}
	var macro_lighting_model_ids: Dictionary = {}
	var macro_lighting_cell_sizes: Dictionary = {}
	var macro_lighting_shadow_alphas: Dictionary = {}
	var macro_lighting_highlight_alphas: Dictionary = {}
	var macro_lighting_samples_by_key: Dictionary = {}
	var terrain_grain_model_ids: Dictionary = {}
	var terrain_grain_source_model_ids: Dictionary = {}
	var terrain_grain_texture_paths: Dictionary = {}
	var terrain_grain_modulate_alphas: Dictionary = {}
	var terrain_detail_model_ids: Dictionary = {}
	var terrain_detail_texture_paths: Dictionary = {}
	var terrain_detail_cell_ids: Dictionary = {}
	var water_ripple_model_ids: Dictionary = {}
	var session = SessionState.active_session
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_explored(session, x, y):
				continue
			explored_tile_count += 1
			var presentation: Dictionary = map_view.call("validation_tile_presentation", Vector2i(x, y))
			var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
			var lighting: Dictionary = terrain.get("terrain_macro_lighting", {}) if terrain.get("terrain_macro_lighting", {}) is Dictionary else {}
			var grain: Dictionary = terrain.get("terrain_grain_overlay", {}) if terrain.get("terrain_grain_overlay", {}) is Dictionary else {}
			var detail: Dictionary = terrain.get("terrain_detail_decal", {}) if terrain.get("terrain_detail_decal", {}) is Dictionary else {}
			var water_ripples: Dictionary = terrain.get("water_surface_ripples", {}) if terrain.get("water_surface_ripples", {}) is Dictionary else {}
			var shoreline: Dictionary = terrain.get("water_shoreline_contour", {}) if terrain.get("water_shoreline_contour", {}) is Dictionary else {}
			var lighting_keys: Array = lighting.get("corner_keys", []) if lighting.get("corner_keys", []) is Array else []
			var lighting_samples: Array = lighting.get("corner_samples", []) if lighting.get("corner_samples", []) is Array else []
			if bool(lighting.get("drawn", false)):
				macro_lighting_tile_count += 1
				macro_lighting_model_ids[String(lighting.get("model", ""))] = true
				macro_lighting_cell_sizes[int(lighting.get("cell_tiles", 0))] = true
				macro_lighting_shadow_alphas[float(lighting.get("shadow_max_alpha", -1.0))] = true
				macro_lighting_highlight_alphas[float(lighting.get("highlight_max_alpha", -1.0))] = true
				if bool(lighting.get("continuous_shared_corners", false)) and String(lighting.get("draw_order", "")) == "after_terrain_transitions_before_roads" and bool(lighting.get("hidden_by_unexplored_shroud", false)):
					macro_lighting_continuous_count += 1
				if float(lighting.get("shadow_max_alpha", 1.0)) <= 0.075 and float(lighting.get("highlight_max_alpha", 1.0)) <= 0.040:
					macro_lighting_bounded_count += 1
				if lighting_keys.size() == 4 and lighting_samples.size() == 4:
					for index in range(4):
						var corner_key := String(lighting_keys[index])
						var sample := float(lighting_samples[index])
						if macro_lighting_samples_by_key.has(corner_key):
							macro_lighting_shared_corner_observation_count += 1
							if not is_equal_approx(float(macro_lighting_samples_by_key.get(corner_key, -1.0)), sample):
								macro_lighting_corner_mismatch_count += 1
						else:
							macro_lighting_samples_by_key[corner_key] = sample
			if bool(grain.get("drawn", false)):
				terrain_grain_tile_count += 1
				terrain_grain_model_ids[String(grain.get("model", ""))] = true
				terrain_grain_source_model_ids[String(grain.get("source_model", ""))] = true
				terrain_grain_texture_paths[String(grain.get("texture_path", ""))] = true
				terrain_grain_modulate_alphas[float(grain.get("modulate_alpha", -1.0))] = true
				if (
					bool(grain.get("texture_loaded", false))
					and grain.get("texture_size", {}) == {"x": 1024, "y": 1024}
					and String(grain.get("mapping", "")) == "whole_board_normalized_once"
					and not bool(grain.get("repeated_per_tile", true))
					and bool(grain.get("seamless_outer_edges", false))
					and not bool(grain.get("terrain_identity_sampled", true))
					and String(grain.get("draw_order", "")) == "after_terrain_transitions_before_macro_lighting_and_roads"
					and bool(grain.get("hidden_by_unexplored_shroud", false))
				):
					terrain_grain_exact_count += 1
			terrain_detail_model_ids[String(detail.get("model", ""))] = true
			if bool(detail.get("road_excluded", false)):
				terrain_detail_road_excluded_count += 1
			if bool(detail.get("water_excluded", false)):
				terrain_detail_water_excluded_count += 1
			var detail_exact: bool = (
				String(detail.get("model", "")) == "sparse_biome_aware_painterly_surface_clusters"
				and bool(detail.get("atlas_texture_loaded", false))
				and detail.get("atlas_size", {}) == {"x": 1024, "y": 1024}
				and detail.get("atlas_grid", {}) == {"x": 4, "y": 4}
				and detail.get("atlas_cell_size", {}) == {"x": 256, "y": 256}
				and int(detail.get("density_modulus", 0)) == 2
				and not bool(detail.get("interactive", true))
				and not bool(detail.get("collision", true))
				and is_equal_approx(float(detail.get("modulate_alpha", 0.0)), 0.78)
				and String(detail.get("draw_order", "")) == "after_macro_lighting_before_roads_objects_and_fog"
				and bool(detail.get("hidden_by_unexplored_shroud", false))
				and String(detail.get("variation_basis", "")) == "tile_coordinate_and_terrain_id_only"
			)
			if bool(detail.get("drawn", false)):
				terrain_detail_drawn_count += 1
				terrain_detail_texture_paths[String(detail.get("atlas_texture_path", ""))] = true
				terrain_detail_cell_ids[int(detail.get("cell_id", -1))] = true
				var source_rect: Dictionary = detail.get("source_rect", {}) if detail.get("source_rect", {}) is Dictionary else {}
				var destination_rect: Dictionary = detail.get("destination_rect", {}) if detail.get("destination_rect", {}) is Dictionary else {}
				var offset: Dictionary = detail.get("offset_factor", {}) if detail.get("offset_factor", {}) is Dictionary else {}
				var cell_id := int(detail.get("cell_id", -1))
				detail_exact = (
					detail_exact
					and cell_id >= 0 and cell_id < 16
					and int(source_rect.get("x", -1)) == (cell_id % 4) * 256
					and int(source_rect.get("y", -1)) == floori(float(cell_id) / 4.0) * 256
					and int(source_rect.get("width", 0)) == 256 and int(source_rect.get("height", 0)) == 256
					and bool(detail.get("destination_contained", false))
					and float(detail.get("extent_factor", 0.0)) >= 0.34 and float(detail.get("extent_factor", 0.0)) <= 0.46
					and float(offset.get("x", -1.0)) >= -0.13 and float(offset.get("x", 1.0)) <= 0.13
					and float(offset.get("y", -1.0)) >= -0.08 and float(offset.get("y", 1.0)) <= 0.12
					and float(destination_rect.get("width", 0.0)) > 0.0
					and is_equal_approx(float(destination_rect.get("width", 0.0)), float(destination_rect.get("height", -1.0)))
					and not bool(detail.get("road_excluded", true))
					and not bool(detail.get("water_excluded", true))
				)
			else:
				detail_exact = detail_exact and int(detail.get("cell_id", -2)) == -1
			if detail_exact:
				terrain_detail_exact_count += 1
			else:
				terrain_detail_invalid_count += 1
			water_ripple_model_ids[String(water_ripples.get("model", ""))] = true
			var water_ripple_profiles: Array = water_ripples.get("profiles", []) if water_ripples.get("profiles", []) is Array else []
			var water_ripple_exact: bool = (
				String(water_ripples.get("model", "")) == "deterministic_broken_painterly_current_pairs"
				and int(water_ripples.get("density_modulus", 0)) == 3
				and water_ripples.get("active_residues", []) == [0, 1]
				and int(water_ripples.get("point_count_per_ripple", 0)) == 5
				and not bool(water_ripples.get("interactive", true))
				and not bool(water_ripples.get("collision", true))
				and not bool(water_ripples.get("animated", true))
				and String(water_ripples.get("variation_basis", "")) == "tile_coordinate_and_ripple_index_only"
				and String(water_ripples.get("draw_order", "")) == "after_macro_lighting_before_causeways_objects_routes_selection_and_fog"
				and bool(water_ripples.get("hidden_by_unexplored_shroud", false))
			)
			var is_water := String(water_ripples.get("terrain_group", "")) == "water"
			if is_water:
				water_ripple_water_tile_count += 1
			if bool(water_ripples.get("road_excluded", false)):
				water_ripple_road_excluded_count += 1
			if bool(water_ripples.get("drawn", false)):
				water_ripple_drawn_count += 1
				water_ripple_exact = water_ripple_exact and is_water and not bool(water_ripples.get("road_excluded", true)) and int(water_ripples.get("ripple_count", 0)) == 2 and water_ripple_profiles.size() == 2 and bool(water_ripples.get("geometry_contained", false))
				for profile_value in water_ripple_profiles:
					var water_ripple_profile: Array = profile_value if profile_value is Array else []
					water_ripple_exact = water_ripple_exact and water_ripple_profile.size() == 5
					for point_value in water_ripple_profile:
						var water_ripple_point: Dictionary = point_value if point_value is Dictionary else {}
						water_ripple_exact = water_ripple_exact and float(water_ripple_point.get("x", -1.0)) >= 0.0 and float(water_ripple_point.get("x", 2.0)) <= 1.0 and float(water_ripple_point.get("y", -1.0)) >= 0.0 and float(water_ripple_point.get("y", 2.0)) <= 1.0
			else:
				water_ripple_exact = water_ripple_exact and int(water_ripples.get("ripple_count", -1)) == 0 and water_ripple_profiles.is_empty() and not bool(water_ripples.get("geometry_contained", true))
			if not is_water:
				water_ripple_exact = water_ripple_exact and not bool(water_ripples.get("drawn", true))
			if water_ripple_exact:
				water_ripple_exact_count += 1
			else:
				water_ripple_invalid_count += 1
			if bool(shoreline.get("active", false)):
				shoreline_tile_count += 1
				shoreline_source_count += int(shoreline.get("source_count", 0))
				var shoreline_profiles: Array = shoreline.get("profiles", []) if shoreline.get("profiles", []) is Array else []
				var profiles_exact := shoreline_profiles.size() == int(shoreline.get("source_count", -1))
				for profile_value in shoreline_profiles:
					var shoreline_profile: Dictionary = profile_value if profile_value is Dictionary else {}
					profiles_exact = profiles_exact and int(shoreline_profile.get("bank_band_point_count", 0)) == 7 and int(shoreline_profile.get("shallow_band_point_count", 0)) == 7 and int(shoreline_profile.get("wet_edge_point_count", 0)) == 5 and int(shoreline_profile.get("foam_segment_count", 0)) == 2 and bool(shoreline_profile.get("geometry_contained", false))
				if String(shoreline.get("model", "")) == "deterministic_layered_bank_shallow_water_wet_edge_and_broken_foam" and String(shoreline.get("authored_edge_art_model", "")) == "authored_texture_clipped_to_deterministic_organic_profile" and is_equal_approx(float(shoreline.get("authored_edge_art_alpha", 0.0)), 0.64) and is_equal_approx(float(shoreline.get("authored_edge_clip_depth_factor", 0.0)), 0.215) and is_equal_approx(float(shoreline.get("bank_band_alpha", 0.0)), 0.30) and profiles_exact and not bool(shoreline.get("continuous_bright_outline", true)) and not bool(shoreline.get("full_tile_fill", true)):
					shoreline_exact_count += 1
			if int(terrain.get("generic_transition_overlay_relationship_count", 0)) <= 0:
				continue
			relationship_tile_count += 1
			var policy := String(terrain.get("transition_draw_policy", ""))
			if policy != "":
				policy_ids[policy] = true
			if bool(terrain.get("homm3_transition_self_contained", false)):
				self_contained_tile_count += 1
			elif bool(terrain.get("generic_transition_overlay_active", false)):
				generic_overlay_tile_count += 1
				var surface_model := String(terrain.get("generic_transition_surface_model", ""))
				if surface_model != "":
					surface_model_ids[surface_model] = true
				feather_band_counts[int(terrain.get("generic_transition_feather_band_count", 0))] = true
				if bool(terrain.get("generic_transition_irregular_inner_edge", false)):
					irregular_inner_edge_count += 1
				if String(terrain.get("generic_transition_deterministic_seed_basis", "")) == "tile_and_direction_only":
					deterministic_seed_count += 1
				if not bool(terrain.get("uses_homm3_local_prototype", false)):
					inactive_homm3_overlay_tile_count += 1
	return {
		"relationship_tile_count": relationship_tile_count,
		"generic_overlay_tile_count": generic_overlay_tile_count,
		"self_contained_tile_count": self_contained_tile_count,
		"inactive_homm3_overlay_tile_count": inactive_homm3_overlay_tile_count,
		"irregular_inner_edge_count": irregular_inner_edge_count,
		"deterministic_seed_count": deterministic_seed_count,
		"explored_tile_count": explored_tile_count,
		"macro_lighting_tile_count": macro_lighting_tile_count,
		"macro_lighting_continuous_count": macro_lighting_continuous_count,
		"macro_lighting_bounded_count": macro_lighting_bounded_count,
		"macro_lighting_shared_corner_observation_count": macro_lighting_shared_corner_observation_count,
		"macro_lighting_unique_corner_count": macro_lighting_samples_by_key.size(),
		"macro_lighting_corner_mismatch_count": macro_lighting_corner_mismatch_count,
		"terrain_grain_tile_count": terrain_grain_tile_count,
		"terrain_grain_exact_count": terrain_grain_exact_count,
		"terrain_detail_drawn_count": terrain_detail_drawn_count,
		"terrain_detail_exact_count": terrain_detail_exact_count,
		"terrain_detail_road_excluded_count": terrain_detail_road_excluded_count,
		"terrain_detail_water_excluded_count": terrain_detail_water_excluded_count,
		"terrain_detail_invalid_count": terrain_detail_invalid_count,
		"water_ripple_water_tile_count": water_ripple_water_tile_count,
		"water_ripple_drawn_count": water_ripple_drawn_count,
		"water_ripple_road_excluded_count": water_ripple_road_excluded_count,
		"water_ripple_exact_count": water_ripple_exact_count,
		"water_ripple_invalid_count": water_ripple_invalid_count,
		"water_ripple_model_ids": water_ripple_model_ids.keys(),
		"shoreline_tile_count": shoreline_tile_count,
		"shoreline_source_count": shoreline_source_count,
		"shoreline_exact_count": shoreline_exact_count,
		"draw_policy_ids": policy_ids.keys(),
		"surface_model_ids": surface_model_ids.keys(),
		"feather_band_counts": feather_band_counts.keys(),
		"macro_lighting_model_ids": macro_lighting_model_ids.keys(),
		"macro_lighting_cell_sizes": macro_lighting_cell_sizes.keys(),
		"macro_lighting_shadow_alphas": macro_lighting_shadow_alphas.keys(),
		"macro_lighting_highlight_alphas": macro_lighting_highlight_alphas.keys(),
		"terrain_grain_model_ids": terrain_grain_model_ids.keys(),
		"terrain_grain_source_model_ids": terrain_grain_source_model_ids.keys(),
		"terrain_grain_texture_paths": terrain_grain_texture_paths.keys(),
		"terrain_grain_modulate_alphas": terrain_grain_modulate_alphas.keys(),
		"terrain_detail_model_ids": terrain_detail_model_ids.keys(),
		"terrain_detail_texture_paths": terrain_detail_texture_paths.keys(),
		"terrain_detail_cell_ids": terrain_detail_cell_ids.keys(),
	}

func _assert_natural_fog_terrain_transition_progression(before: Dictionary, after: Dictionary) -> bool:
	var count_keys := [
		"explored_tile_count",
		"relationship_tile_count",
		"generic_overlay_tile_count",
		"self_contained_tile_count",
		"inactive_homm3_overlay_tile_count",
		"irregular_inner_edge_count",
		"deterministic_seed_count",
		"terrain_grain_tile_count",
		"terrain_detail_drawn_count",
	]
	for key in count_keys:
		if int(after.get(key, -1)) < int(before.get(key, 0)):
			_fail("Generated natural-fog terrain presentation lost %s across exploration: before=%s after=%s" % [key, before, after])
			return false
	for summary in [before, after]:
		var explored_count := int(summary.get("explored_tile_count", 0))
		if (
			explored_count <= 0
			or int(summary.get("macro_lighting_tile_count", -1)) != explored_count
			or int(summary.get("macro_lighting_continuous_count", -1)) != explored_count
			or int(summary.get("macro_lighting_bounded_count", -1)) != explored_count
			or int(summary.get("macro_lighting_corner_mismatch_count", -1)) != 0
			or int(summary.get("terrain_grain_tile_count", -1)) != explored_count
			or int(summary.get("terrain_grain_exact_count", -1)) != explored_count
			or int(summary.get("terrain_detail_exact_count", -1)) != explored_count
			or int(summary.get("terrain_detail_invalid_count", -1)) != 0
			or int(summary.get("terrain_detail_drawn_count", 0)) <= 0
			or int(summary.get("water_ripple_exact_count", -1)) != explored_count
			or int(summary.get("water_ripple_invalid_count", -1)) != 0
			or int(summary.get("irregular_inner_edge_count", -1)) != int(summary.get("generic_overlay_tile_count", -2))
			or int(summary.get("deterministic_seed_count", -1)) != int(summary.get("generic_overlay_tile_count", -2))
		):
			_fail("Generated natural-fog terrain presentation contract changed: %s" % summary)
			return false
	for key in [
		"draw_policy_ids",
		"surface_model_ids",
		"feather_band_counts",
		"macro_lighting_model_ids",
		"macro_lighting_cell_sizes",
		"macro_lighting_shadow_alphas",
		"macro_lighting_highlight_alphas",
		"terrain_grain_model_ids",
		"terrain_grain_source_model_ids",
		"terrain_grain_texture_paths",
		"terrain_grain_modulate_alphas",
		"terrain_detail_model_ids",
		"terrain_detail_texture_paths",
		"water_ripple_model_ids",
	]:
		if after.get(key, []) != before.get(key, []):
			_fail("Generated natural-fog terrain presentation model changed for %s: before=%s after=%s" % [key, before.get(key, []), after.get(key, [])])
			return false
	return true

func _fog_frontier_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_tile_presentation"):
		return {}
	var session = SessionState.active_session
	var map_size := OverworldRules.derive_map_size(session)
	var checks := {
		"N": Vector2i.UP,
		"E": Vector2i.RIGHT,
		"S": Vector2i.DOWN,
		"W": Vector2i.LEFT,
	}
	var explored_tile_count := 0
	var hidden_tile_count := 0
	var active_frontier_tile_count := 0
	var exact_frontier_tile_count := 0
	var interior_explored_tile_count := 0
	var direction_observation_count := 0
	var softened_corner_count := 0
	var hidden_exact_count := 0
	var hidden_textured_shroud_exact_count := 0
	var invalid_direction_count := 0
	var model_ids: Dictionary = {}
	var hidden_shroud_model_ids: Dictionary = {}
	var hidden_shroud_texture_paths: Dictionary = {}
	var hidden_shroud_mapping_ids: Dictionary = {}
	var expected_source_size := Vector2(1024.0 / float(map_size.x), 1024.0 / float(map_size.y))
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			var presentation: Dictionary = map_view.call("validation_tile_presentation", tile)
			var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
			var frontier: Dictionary = terrain.get("fog_frontier", {}) if terrain.get("fog_frontier", {}) is Dictionary else {}
			if not OverworldRules.is_tile_explored(session, x, y):
				hidden_tile_count += 1
				var source_rect: Dictionary = terrain.get("unexplored_shroud_texture_source_rect", {}) if terrain.get("unexplored_shroud_texture_source_rect", {}) is Dictionary else {}
				hidden_shroud_model_ids[String(terrain.get("unexplored_shroud_model", ""))] = true
				hidden_shroud_texture_paths[String(terrain.get("unexplored_shroud_texture_path", ""))] = true
				hidden_shroud_mapping_ids[String(terrain.get("unexplored_shroud_texture_mapping", ""))] = true
				if (
					bool(terrain.get("unexplored_hidden", false))
					and String(terrain.get("terrain", "leaked")) == ""
					and not bool(frontier.get("drawn", true))
					and not bool(frontier.get("hidden_identity_sampled", true))
				):
					hidden_exact_count += 1
				if (
					bool(terrain.get("unexplored_shroud_texture_loaded", false))
					and terrain.get("unexplored_shroud_texture_size", {}) == {"x": 1024, "y": 1024}
					and not bool(terrain.get("unexplored_shroud_repeated_stamps", true))
					and not bool(terrain.get("unexplored_shroud_texture_terrain_identity_sampled", true))
					and is_equal_approx(float(source_rect.get("x", -1.0)), float(x) * expected_source_size.x)
					and is_equal_approx(float(source_rect.get("y", -1.0)), float(y) * expected_source_size.y)
					and is_equal_approx(float(source_rect.get("width", -1.0)), expected_source_size.x)
					and is_equal_approx(float(source_rect.get("height", -1.0)), expected_source_size.y)
				):
					hidden_textured_shroud_exact_count += 1
				continue
			explored_tile_count += 1
			var directions: Array = frontier.get("directions", []) if frontier.get("directions", []) is Array else []
			if directions.is_empty():
				interior_explored_tile_count += 1
				continue
			active_frontier_tile_count += 1
			model_ids[String(frontier.get("model", ""))] = true
			direction_observation_count += directions.size()
			var softened_corners: Array = frontier.get("softened_corners", []) if frontier.get("softened_corners", []) is Array else []
			softened_corner_count += softened_corners.size()
			for direction_value in directions:
				var direction := String(direction_value)
				var neighbor: Vector2i = tile + checks.get(direction, Vector2i.ZERO)
				if not checks.has(direction) or neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y or OverworldRules.is_tile_explored(session, neighbor.x, neighbor.y):
					invalid_direction_count += 1
			if (
				bool(frontier.get("drawn", false))
				and int(frontier.get("gradient_stop_count", 0)) == 2
				and is_equal_approx(float(frontier.get("gradient_depth_factor", 0.0)), 0.32)
				and is_equal_approx(float(frontier.get("gradient_edge_alpha", 0.0)), 0.24)
				and is_equal_approx(float(frontier.get("gradient_inner_alpha", -1.0)), 0.0)
				and is_equal_approx(float(frontier.get("edge_alpha", 0.0)), 0.16)
				and int(frontier.get("contour_point_count", 0)) == 5
				and is_equal_approx(float(frontier.get("contour_min_inset_factor", 0.0)), 0.018)
				and is_equal_approx(float(frontier.get("contour_max_inset_factor", 0.0)), 0.060)
				and bool(frontier.get("contour_endpoints_on_boundary", false))
				and not bool(frontier.get("contour_hidden_side_intrusion", true))
				and String(frontier.get("contour_variation_basis", "")) == "explored_tile_direction_only"
				and String(frontier.get("draw_side", "")) == "explored_inward"
				and String(frontier.get("neighbor_basis", "")) == "cardinal_explored_boolean_only"
				and not bool(frontier.get("hidden_identity_sampled", true))
				and not bool(frontier.get("interior_explored_seams", true))
			):
				exact_frontier_tile_count += 1
	return {
		"explored_tile_count": explored_tile_count,
		"hidden_tile_count": hidden_tile_count,
		"active_frontier_tile_count": active_frontier_tile_count,
		"exact_frontier_tile_count": exact_frontier_tile_count,
		"interior_explored_tile_count": interior_explored_tile_count,
		"direction_observation_count": direction_observation_count,
		"softened_corner_count": softened_corner_count,
		"hidden_exact_count": hidden_exact_count,
		"hidden_textured_shroud_exact_count": hidden_textured_shroud_exact_count,
		"invalid_direction_count": invalid_direction_count,
		"model_ids": model_ids.keys(),
		"hidden_shroud_model_ids": hidden_shroud_model_ids.keys(),
		"hidden_shroud_texture_paths": hidden_shroud_texture_paths.keys(),
		"hidden_shroud_mapping_ids": hidden_shroud_mapping_ids.keys(),
	}

func _assert_fog_frontier_summary(summary: Dictionary, label: String) -> bool:
	var explored_count := int(summary.get("explored_tile_count", 0))
	var hidden_count := int(summary.get("hidden_tile_count", 0))
	var active_count := int(summary.get("active_frontier_tile_count", 0))
	if (
		explored_count <= 0
		or hidden_count <= 0
		or active_count <= 0
		or int(summary.get("exact_frontier_tile_count", 0)) != active_count
		or int(summary.get("interior_explored_tile_count", 0)) <= 0
		or int(summary.get("direction_observation_count", 0)) < active_count
		or int(summary.get("softened_corner_count", 0)) <= 0
		or int(summary.get("hidden_exact_count", 0)) != hidden_count
		or int(summary.get("hidden_textured_shroud_exact_count", 0)) != hidden_count
		or int(summary.get("invalid_direction_count", -1)) != 0
		or summary.get("model_ids", []) != ["inward_gradient_irregular_cartographic_contour"]
		or summary.get("hidden_shroud_model_ids", []) != ["continuous_identity_silent_textured_cartographic_veil"]
		or summary.get("hidden_shroud_texture_paths", []) != ["res://art/overworld/runtime/fog/unexplored_cartographic_veil.png"]
		or summary.get("hidden_shroud_mapping_ids", []) != ["whole_board_normalized_once_clipped_by_hidden_cells"]
	):
		_fail("%s generated natural-fog frontier contract changed: %s" % [label, JSON.stringify(summary)])
		return false
	return true

func _road_surface_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_tile_presentation"):
		return {}
	var session = SessionState.active_session
	var map_size := OverworldRules.derive_map_size(session)
	var road_tiles := []
	var render_models := []
	var ordinary_bypass_count := 0
	var explicit_source_count := 0
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_explored(session, x, y):
				continue
			var presentation: Dictionary = map_view.call("validation_tile_presentation", Vector2i(x, y))
			var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
			if not bool(terrain.get("road_overlay", false)):
				continue
			var render_model := String(terrain.get("road_render_model", ""))
			if render_model not in render_models:
				render_models.append(render_model)
			if bool(terrain.get("road_ordinary_tile_art_bypassed", false)):
				ordinary_bypass_count += 1
			if bool(terrain.get("road_explicit_source_frame_rendered", false)):
				explicit_source_count += 1
			road_tiles.append({
				"x": x,
				"y": y,
				"terrain": String(terrain.get("terrain", "")),
				"render_model": render_model,
				"connection_key": String(terrain.get("road_connection_key", "")),
				"connection_count": int(terrain.get("road_connection_count", 0)),
			})
	return {
		"road_tile_count": road_tiles.size(),
		"render_models": render_models,
		"ordinary_bypass_count": ordinary_bypass_count,
		"explicit_source_count": explicit_source_count,
		"road_tiles": road_tiles,
	}

func _assert_generated_road_surface(summary: Dictionary, label: String) -> bool:
	var road_tile_count := int(summary.get("road_tile_count", 0))
	if road_tile_count <= 0:
		_fail("%s generated map exposed no explored road surface fixture: %s" % [label, JSON.stringify(summary)])
		return false
	if summary.get("render_models", []) != ["layered_wheel_rutted_dirt_path"]:
		_fail("%s generated land roads did not use only the wheel-rutted terrain surface: %s" % [label, JSON.stringify(summary)])
		return false
	if int(summary.get("ordinary_bypass_count", 0)) != road_tile_count or int(summary.get("explicit_source_count", -1)) != 0:
		_fail("%s generated ordinary roads did not bypass timber-bar art exactly: %s" % [label, JSON.stringify(summary)])
		return false
	for tile_value in summary.get("road_tiles", []):
		if not (tile_value is Dictionary):
			_fail("%s generated road summary contains a malformed tile: %s" % [label, JSON.stringify(summary)])
			return false
		var tile: Dictionary = tile_value
		if String(tile.get("terrain", "")) == "water" or String(tile.get("render_model", "")) != "layered_wheel_rutted_dirt_path" or int(tile.get("connection_count", -1)) < 0:
			_fail("%s generated land road tile has invalid terrain/render/topology metadata: %s" % [label, JSON.stringify(tile)])
			return false
	return true

func _assert_terrain_transition_summary(summary: Dictionary, label: String) -> bool:
	var relationship_count := int(summary.get("relationship_tile_count", 0))
	var explored_tile_count := int(summary.get("explored_tile_count", 0))
	var terrain_grain_modulate_alphas: Array = summary.get("terrain_grain_modulate_alphas", []) if summary.get("terrain_grain_modulate_alphas", []) is Array else []
	if (
		relationship_count <= 0
		or int(summary.get("generic_overlay_tile_count", 0)) != relationship_count
		or int(summary.get("inactive_homm3_overlay_tile_count", 0)) != relationship_count
		or int(summary.get("self_contained_tile_count", -1)) != 0
		or summary.get("draw_policy_ids", []) != ["active_homm3_self_contained_else_generic_overlay"]
		or summary.get("surface_model_ids", []) != ["layered_feathered_organic_intrusion"]
		or summary.get("feather_band_counts", []) != [2]
		or int(summary.get("irregular_inner_edge_count", 0)) != relationship_count
		or int(summary.get("deterministic_seed_count", 0)) != relationship_count
		or explored_tile_count <= 0
		or int(summary.get("macro_lighting_tile_count", 0)) != explored_tile_count
		or int(summary.get("macro_lighting_continuous_count", 0)) != explored_tile_count
		or int(summary.get("macro_lighting_bounded_count", 0)) != explored_tile_count
		or int(summary.get("macro_lighting_shared_corner_observation_count", 0)) <= 0
		or int(summary.get("macro_lighting_unique_corner_count", 0)) <= explored_tile_count
		or int(summary.get("macro_lighting_corner_mismatch_count", -1)) != 0
		or summary.get("macro_lighting_model_ids", []) != ["continuous_shared_corner_bilinear_field"]
		or summary.get("macro_lighting_cell_sizes", []) != [12]
		or summary.get("macro_lighting_shadow_alphas", []) != [0.075]
		or summary.get("macro_lighting_highlight_alphas", []) != [0.04]
		or int(summary.get("terrain_grain_tile_count", 0)) != explored_tile_count
		or int(summary.get("terrain_grain_exact_count", 0)) != explored_tile_count
		or int(summary.get("terrain_detail_exact_count", 0)) != explored_tile_count
		or int(summary.get("terrain_detail_invalid_count", -1)) != 0
		or int(summary.get("terrain_detail_drawn_count", 0)) <= 0
		or int(summary.get("water_ripple_exact_count", 0)) != explored_tile_count
		or int(summary.get("water_ripple_invalid_count", -1)) != 0
		or int(summary.get("water_ripple_water_tile_count", 0)) <= 0
		or int(summary.get("water_ripple_drawn_count", 0)) <= 0
		or int(summary.get("shoreline_exact_count", -1)) != int(summary.get("shoreline_tile_count", -2))
		or int(summary.get("shoreline_source_count", 0)) < int(summary.get("shoreline_tile_count", 0))
		or summary.get("terrain_grain_model_ids", []) != ["single_normalized_map_space_seamless_painterly_microtexture"]
		or summary.get("terrain_grain_source_model_ids", []) != ["original_generated_neutral_grain_mirrored_seamless_alpha"]
		or summary.get("terrain_grain_texture_paths", []) != ["res://art/overworld/runtime/terrain_tiles/detail/terrain_grain_overlay.png"]
		or terrain_grain_modulate_alphas.size() != 1
		or not is_equal_approx(float(terrain_grain_modulate_alphas[0]), 0.72)
		or summary.get("terrain_detail_model_ids", []) != ["sparse_biome_aware_painterly_surface_clusters"]
		or summary.get("terrain_detail_texture_paths", []) != ["res://art/overworld/runtime/terrain_tiles/detail/terrain_detail_decal_atlas.png"]
		or summary.get("water_ripple_model_ids", []) != ["deterministic_broken_painterly_current_pairs"]
	):
		_fail("%s generated terrain transitions or continuous macro-lighting contract did not remain exact: %s" % [label, JSON.stringify(summary)])
		return false
	return true

func _assert_macro_lighting_render_profile(snapshot: Dictionary, label: String) -> bool:
	var map_viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	var render_cache: Dictionary = map_viewport.get("render_cache", {}) if map_viewport.get("render_cache", {}) is Dictionary else {}
	var profile: Dictionary = render_cache.get("profile", {}) if render_cache.get("profile", {}) is Dictionary else {}
	var last_static: Dictionary = profile.get("last_draw_session_static", {}) if profile.get("last_draw_session_static", {}) is Dictionary else {}
	var terrain_draws := int(last_static.get("terrain_tile_draws", 0))
	var macro_polygon_draws := int(last_static.get("terrain_macro_lighting_polygon_draws", 0))
	var grain_draws := int(last_static.get("terrain_grain_overlay_draws", 0))
	var detail_draws := int(last_static.get("terrain_detail_decal_draws", 0))
	if terrain_draws <= 0 or grain_draws != 1 or detail_draws <= 0 or detail_draws >= terrain_draws or macro_polygon_draws <= 0 or macro_polygon_draws > 12 or macro_polygon_draws * 8 >= terrain_draws:
		_fail("%s macro-lighting render pass was not materially batched below tile count: %s" % [label, JSON.stringify(last_static)])
		return false
	return true

func _assert_generated_visual_summary(summary: Dictionary, label: String) -> bool:
	if summary.is_empty():
		_fail("%s generated visual summary is unavailable." % label)
		return false
	if String(summary.get("presentation_model", "")) != "exact_body_cell_biome_palette_clustered_original_sprite":
		_fail("%s generated body presentation model is not exact: %s" % [label, JSON.stringify(summary)])
		return false
	var is_default_fixture := _active_size_class_id == SIZE_CLASS_ID and _active_seed == EXPLICIT_SEED
	if is_default_fixture and int(summary.get("generated_record_count", 0)) != 175:
		_fail("%s generated decorative record count changed: %s" % [label, summary.get("generated_record_count", -1)])
		return false
	if is_default_fixture and (int(summary.get("expected_body_tile_count", 0)) != 464 or int(summary.get("indexed_body_tile_count", 0)) != 464):
		_fail("%s exact generated body coverage changed: expected=%s indexed=%s" % [label, summary.get("expected_body_tile_count", -1), summary.get("indexed_body_tile_count", -1)])
		return false
	if int(summary.get("generated_record_count", 0)) <= 0 or int(summary.get("expected_body_tile_count", 0)) <= 0:
		_fail("%s generated fixture has no decorative body authority: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not bool(summary.get("body_tile_keys_exact", false)) or not bool(summary.get("all_body_assets_loaded", false)) or not bool(summary.get("all_body_assets_terrain_matched", false)):
		_fail("%s generated body presentation is incomplete: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not is_equal_approx(float(summary.get("body_sprite_extent_tiles", 0.0)), 0.46):
		_fail("%s generated body sprite extent changed: %s" % [label, summary.get("body_sprite_extent_tiles", -1.0)])
		return false
	if int(summary.get("composition_key_count", 0)) != int(summary.get("indexed_body_tile_count", -1)):
		_fail("%s generated body composition keys are incomplete: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not bool(summary.get("all_transformed_bounds_within_tile", false)):
		_fail("%s generated body composition escaped its owning tiles: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if int(summary.get("distinct_body_asset_count", 0)) < 8 or int(summary.get("repeated_def_multi_asset_count", 0)) <= 0:
		_fail("%s generated body palette did not break repeated-definition stamping: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if (
		float(summary.get("scale_factor_min", 1.0)) >= 0.95
		or float(summary.get("scale_factor_max", 1.0)) <= 1.01
		or float(summary.get("offset_x_min", 0.0)) >= -0.02
		or float(summary.get("offset_x_max", 0.0)) <= 0.02
	):
		_fail("%s generated body composition does not exercise its bounded visual range: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if String(summary.get("composition_signature", "")).length() != 64:
		_fail("%s generated body composition signature is missing: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if (
		not is_equal_approx(float(summary.get("multi_tile_interactive_cap_tiles", 0.0)), 1.32)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_base_min_tiles", 0.0)), 0.74)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_span_min_step_tiles", 0.0)), 0.16)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_depth_min_step_tiles", 0.0)), 0.18)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_base_cap_tiles", 0.0)), 0.82)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_span_cap_step_tiles", 0.0)), 0.20)
		or not is_equal_approx(float(summary.get("multi_tile_interactive_depth_cap_step_tiles", 0.0)), 0.22)
	):
		_fail("%s multi-tile visual cap changed: %s" % [label, summary.get("multi_tile_interactive_cap_tiles", -1.0)])
		return false
	var corrected_multi_tile_count := 0
	var one_tile_control_count := 0
	for entry_value in summary.get("resource_entries", []):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var metrics: Dictionary = entry.get("visual_metrics", {}) if entry.get("visual_metrics", {}) is Dictionary else {}
		var footprint: Dictionary = metrics.get("footprint", {}) if metrics.get("footprint", {}) is Dictionary else {}
		var multi_tile := int(footprint.get("width", 1)) > 1 or int(footprint.get("height", 1)) > 1
		if multi_tile:
			var footprint_span := maxi(int(footprint.get("width", 1)), int(footprint.get("height", 1)))
			var footprint_depth := mini(int(footprint.get("width", 1)), int(footprint.get("height", 1)))
			var expected_min_tiles := minf(0.74 + float(footprint_span - 1) * 0.16 + float(footprint_depth - 1) * 0.18, 1.32)
			var expected_cap_tiles := minf(0.82 + float(footprint_span - 1) * 0.20 + float(footprint_depth - 1) * 0.22, 1.32)
			if not bool(metrics.get("uses_multi_tile_visual_cap", false)):
				_fail("%s multi-tile resource did not use the visual cap: %s" % [label, JSON.stringify(entry)])
				return false
			if (
				not is_equal_approx(float(metrics.get("min_tiles", 0.0)), expected_min_tiles)
				or not is_equal_approx(float(metrics.get("cap_tiles", 0.0)), expected_cap_tiles)
				or float(metrics.get("sprite_extent_tiles", 0.0)) < expected_min_tiles - 0.0001
				or float(metrics.get("sprite_extent_tiles", 99.0)) > expected_cap_tiles + 0.0001
			):
				_fail("%s multi-tile resource escaped its footprint-span bounds: %s" % [label, JSON.stringify(entry)])
				return false
			if float(metrics.get("uncapped_sprite_extent_px", 0.0)) > float(metrics.get("sprite_extent_px", 0.0)) + 0.01:
				corrected_multi_tile_count += 1
		else:
			if bool(metrics.get("uses_multi_tile_visual_cap", true)) or not is_equal_approx(float(metrics.get("uncapped_sprite_extent_px", 0.0)), float(metrics.get("sprite_extent_px", -1.0))):
				_fail("%s one-tile resource presentation changed: %s" % [label, JSON.stringify(entry)])
				return false
			one_tile_control_count += 1
	if corrected_multi_tile_count <= 0 or one_tile_control_count <= 0:
		_fail("%s visual scale fixture lacks corrected multi-tile or unchanged one-tile controls: corrected=%d one_tile=%d" % [label, corrected_multi_tile_count, one_tile_control_count])
		return false
	return true

func _generated_presentation_authority(session) -> Dictionary:
	if session == null:
		return {}
	return {
		"map": session.overworld.get("map", []).duplicate(true),
		"map_objects": session.overworld.get("map_objects", []).duplicate(true),
		"resource_nodes": session.overworld.get("resource_nodes", []).duplicate(true),
		"towns": session.overworld.get("towns", []).duplicate(true),
		"encounters": session.overworld.get("encounters", []).duplicate(true),
	}

func _generated_save_reload_authority(session) -> Dictionary:
	if session == null:
		return {}
	var payload: Dictionary = SessionStateStoreScript.normalize_payload(session.to_dict())
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	return {
		"scenario_id": String(payload.get("scenario_id", "")),
		"launch_mode": String(payload.get("launch_mode", "")),
		"generated_random_map_provenance": flags.get("generated_random_map_provenance", {}).duplicate(true),
		"generated_random_map_replay_metadata": flags.get("generated_random_map_replay_metadata", {}).duplicate(true),
		"map": overworld.get("map", []).duplicate(true),
		"map_objects": overworld.get("map_objects", []).duplicate(true),
		"resource_nodes": overworld.get("resource_nodes", []).duplicate(true),
		"towns": overworld.get("towns", []).duplicate(true),
		"encounters": overworld.get("encounters", []).duplicate(true),
	}

func _save_authority_values_equal(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(float(left), float(right))
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _save_authority_values_equal(left.get(key), right.get(key)):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _save_authority_values_equal(left[index], right[index]):
				return false
		return true
	return left == right

func _compact_generated_visual_summary(summary: Dictionary) -> Dictionary:
	return {
		"presentation_model": String(summary.get("presentation_model", "")),
		"generated_record_count": int(summary.get("generated_record_count", 0)),
		"expected_body_tile_count": int(summary.get("expected_body_tile_count", 0)),
		"indexed_body_tile_count": int(summary.get("indexed_body_tile_count", 0)),
		"body_tile_keys_exact": bool(summary.get("body_tile_keys_exact", false)),
		"all_body_assets_loaded": bool(summary.get("all_body_assets_loaded", false)),
		"all_body_assets_terrain_matched": bool(summary.get("all_body_assets_terrain_matched", false)),
		"collision_tile_count": int(summary.get("collision_tile_count", 0)),
		"body_sprite_extent_tiles": float(summary.get("body_sprite_extent_tiles", 0.0)),
		"distinct_body_asset_count": int(summary.get("distinct_body_asset_count", 0)),
		"repeated_def_multi_asset_count": int(summary.get("repeated_def_multi_asset_count", 0)),
		"composition_key_count": int(summary.get("composition_key_count", 0)),
		"all_transformed_bounds_within_tile": bool(summary.get("all_transformed_bounds_within_tile", false)),
		"scale_factor_min": float(summary.get("scale_factor_min", 0.0)),
		"scale_factor_max": float(summary.get("scale_factor_max", 0.0)),
		"offset_x_min": float(summary.get("offset_x_min", 0.0)),
		"offset_x_max": float(summary.get("offset_x_max", 0.0)),
		"offset_y_min": float(summary.get("offset_y_min", 0.0)),
		"offset_y_max": float(summary.get("offset_y_max", 0.0)),
		"composition_signature": String(summary.get("composition_signature", "")),
		"multi_tile_interactive_cap_tiles": float(summary.get("multi_tile_interactive_cap_tiles", 0.0)),
		"capped_resource_count": int(summary.get("capped_resource_count", 0)),
		"max_capped_resource_extent_tiles": float(summary.get("max_capped_resource_extent_tiles", 0.0)),
	}

func _assert_move_result(
	move_result: Dictionary,
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	move_latency_ms: float,
	post_move_frame_ms: float,
	idle_before: Dictionary,
	idle_after: Dictionary
) -> bool:
	if not _assert_generated_small_snapshot(after_snapshot, "after_move"):
		return false
	if not bool(move_result.get("ok", false)):
		_fail("Generated Small movement did not commit: %s" % JSON.stringify(move_result))
		return false
	var before_pos: Dictionary = before_snapshot.get("hero_position", {})
	var after_pos: Dictionary = after_snapshot.get("hero_position", {})
	if int(before_pos.get("x", -1)) == int(after_pos.get("x", -1)) and int(before_pos.get("y", -1)) == int(after_pos.get("y", -1)):
		_fail("Generated Small movement did not change hero position: before=%s after=%s result=%s" % [
			JSON.stringify(before_pos),
			JSON.stringify(after_pos),
			JSON.stringify(move_result),
		])
		return false
	if String(after_snapshot.get("scenario_status", "")) != "in_progress":
		_fail("Generated Small movement routed to outcome/status %s." % String(after_snapshot.get("scenario_status", "")))
		return false
	if move_latency_ms > MOVE_LATENCY_BUDGET_MS:
		_fail("Generated Small movement latency exceeded budget: %.2fms result=%s" % [move_latency_ms, JSON.stringify(move_result)])
		return false
	if post_move_frame_ms > POST_MOVE_FRAME_BUDGET_MS:
		_fail("Generated Small post-move frame exceeded budget: %.2fms" % post_move_frame_ms)
		return false
	if float(idle_before.get("fps_wall", 0.0)) < MIN_IDLE_FPS or float(idle_after.get("fps_wall", 0.0)) < MIN_IDLE_FPS:
		_fail("Generated Small live FPS below budget: before=%s after=%s" % [JSON.stringify(idle_before), JSON.stringify(idle_after)])
		return false
	return true

func _sample_fps(frames: int) -> Dictionary:
	var start := Time.get_ticks_usec()
	for _i in range(frames):
		await get_tree().process_frame
	var elapsed_us := maxi(1, Time.get_ticks_usec() - start)
	return {
		"frames": frames,
		"elapsed_ms": float(elapsed_us) / 1000.0,
		"fps_wall": float(frames) * 1000000.0 / float(elapsed_us),
		"engine_fps": Engine.get_frames_per_second(),
	}

func _single_frame_ms() -> float:
	var start := Time.get_ticks_usec()
	await get_tree().process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0

func _capture_if_requested(label: String) -> bool:
	var output_dir := OS.get_environment("RANDOM_MAP_LIVE_VISUAL_CAPTURE_DIR").strip_edges()
	if output_dir == "":
		return true
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		_fail("Could not create generated-map visual capture directory %s." % absolute_dir)
		return false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Generated-map visual capture %s returned no viewport image." % label)
		return false
	var result := image.save_png(absolute_dir.path_join("generated_%s.png" % label))
	if result != OK:
		_fail("Could not save generated-map visual capture %s: %s." % [label, result])
		return false
	return true

func _reveal_all_for_visual_capture(session) -> void:
	if session == null:
		return
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

func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"scenario_status": String(snapshot.get("scenario_status", "")),
		"game_state": String(snapshot.get("game_state", "")),
		"day": int(snapshot.get("day", 0)),
		"movement_current": int(snapshot.get("movement_current", 0)),
		"movement_max": int(snapshot.get("movement_max", 0)),
		"map_size": snapshot.get("map_size", {}),
		"hero_position": snapshot.get("hero_position", {}),
		"selected_tile": snapshot.get("selected_tile", {}),
		"map_cue_text": String(snapshot.get("map_cue_text", "")),
	}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
