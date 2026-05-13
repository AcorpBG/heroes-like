extends Node

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_PORT_BOUNDARY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("native_rmg_generation_authority", "")) != "h3maped_small_reset_only" \
			or bool(metadata.get("native_rmg_runtime_generation_allowed", true)):
		_fail("Native RMG reset gate is not active: %s" % JSON.stringify(metadata))
		return

	var config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}

	var report: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	if not bool(report.get("ok", false)):
		_fail("Fresh small h3maped boundary rejected the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1":
		_fail("The active report is not the fresh-start boundary: %s" % JSON.stringify(report))
		return
	if String(report.get("implementation_policy", "")) != "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback":
		_fail("Fresh-start policy drifted: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) or bool(report.get("partial_materialized_payload_public_api", true)):
		_fail("Fresh-start boundary exposed runtime output: %s" % JSON.stringify(report))
		return
	if report.has("small_generation_state") or report.has("private_generation_context"):
		_fail("Fresh-start boundary still exposes the old private phase ledger: %s" % JSON.stringify(report))
		return
	var active_state: Dictionary = report.get("active_generation_state", {})
	if String(active_state.get("schema_id", "")) != "aurelion_h3maped_small_active_generation_state_v1" \
			or String(active_state.get("status", "")) != "object_vector_prerequisite_active_internal_state" \
			or Array(active_state.get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay", "zone_footprints", "terrain_cell_writeout", "terrainplacement_visual_tables", "terrainplacement_live_feedback", "terrain_tile_byte_writeback", "town_castle_phase", "mines_rewards_and_object_vector"] \
			or bool(active_state.get("runtime_generation_allowed", true)) \
			or bool(active_state.get("materializes_runtime_players", true)) \
			or bool(active_state.get("materializes_map_cells", true)) \
			or bool(active_state.get("materializes_public_output", true)) \
			or String(active_state.get("blocked_next", "")) != "private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9":
		_fail("Fresh active generation state phase boundary drifted: %s" % JSON.stringify(active_state))
		return
	var player_phase: Dictionary = active_state.get("player_slot_assignment", {})
	if String(player_phase.get("h3maped_anchor", "")) != "0x4ac62a..0x4ac6ec" \
			or String(player_phase.get("status", "")) != "active_internal_state" \
			or String(player_phase.get("selected_color_bitmap_offset", "")) != "generator+0xed8" \
			or String(player_phase.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(player_phase.get("mapped_slots_offset", "")) != "generator+0xee4" \
			or int(player_phase.get("human_capable_source_owner_mask", -1)) != 15 \
			or int(player_phase.get("player_capable_source_owner_mask", -1)) != 15 \
			or Array(player_phase.get("raw_ee0_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(player_phase.get("mapped_ee4_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or int(player_phase.get("assigned_player_count", -1)) != 3:
		_fail("h3maped player-slot phase drifted: %s" % JSON.stringify(player_phase))
		return
	var assignments: Array = player_phase.get("assignment_records", [])
	if assignments.size() != 3 \
			or String(assignments[0].get("player_type", "")) != "human" \
			or int(assignments[0].get("source_owner_index", -1)) != 0 \
			or int(assignments[0].get("actual_player_color", -1)) != 0 \
			or String(assignments[1].get("player_type", "")) != "computer" \
			or int(assignments[1].get("source_owner_index", -1)) != 1 \
			or int(assignments[1].get("actual_player_color", -1)) != 1 \
			or String(assignments[2].get("player_type", "")) != "computer" \
			or int(assignments[2].get("source_owner_index", -1)) != 2 \
			or int(assignments[2].get("actual_player_color", -1)) != 2:
		_fail("h3maped player-slot assignments drifted: %s" % JSON.stringify(assignments))
		return
	var runtime_zone_phase: Dictionary = active_state.get("runtime_zone_records", {})
	if String(runtime_zone_phase.get("h3maped_anchor", "")) != "0x4a218c" \
			or String(runtime_zone_phase.get("initializer_anchor", "")) != "0x49b452" \
			or String(runtime_zone_phase.get("status", "")) != "active_internal_state" \
			or int(runtime_zone_phase.get("runtime_zone_record_size_bytes", -1)) != 0x414 \
			or int(runtime_zone_phase.get("runtime_zone_count", -1)) != 6 \
			or int(runtime_zone_phase.get("assigned_start_zone_count", -1)) != 3 \
			or int(runtime_zone_phase.get("unassigned_start_zone_count", -1)) != 1 \
			or int(runtime_zone_phase.get("treasure_zone_count", -1)) != 2 \
			or int(runtime_zone_phase.get("minimum_player_castles", -1)) != 4 \
			or int(runtime_zone_phase.get("minimum_source_base_size", -1)) != 11 \
			or Array(runtime_zone_phase.get("actual_owner_colors_by_runtime_zone", [])) != [0, 1, -1, 2, -1, -1] \
			or bool(runtime_zone_phase.get("materializes_runtime_zone_coordinates", true)) \
			or bool(runtime_zone_phase.get("materializes_terrain", true)) \
			or bool(runtime_zone_phase.get("materializes_map_cells", true)) \
			or bool(runtime_zone_phase.get("materializes_public_output", true)):
		_fail("h3maped runtime-zone records drifted: %s" % JSON.stringify(runtime_zone_phase))
		return
	var runtime_records: Array = runtime_zone_phase.get("runtime_zone_records", [])
	if runtime_records.size() != 6 \
			or String(runtime_records[0].get("role", "")) != "human_start" \
			or int(runtime_records[0].get("source_owner_index", -1)) != 0 \
			or int(runtime_records[0].get("actual_owner_color", -1)) != 0 \
			or int(runtime_records[0].get("min_player_castles", -1)) != 1 \
			or String(runtime_records[2].get("role", "")) != "treasure" \
			or int(runtime_records[2].get("actual_owner_color", 99)) != -1 \
			or String(runtime_records[2].get("terrain_policy", "")) != "all_land_h3" \
			or int(runtime_records[2].get("minimum_rare_mines", -1)) != 5 \
			or int(runtime_records[4].get("source_owner_index", -1)) != 3 \
			or int(runtime_records[4].get("actual_owner_color", 99)) != -1 \
			or String(runtime_records[5].get("role", "")) != "treasure":
		_fail("h3maped runtime-zone records changed: %s" % JSON.stringify(runtime_records))
		return
	var link_phase: Dictionary = active_state.get("link_seed_setup", {})
	var link_seeds: Array = link_phase.get("link_seeds", [])
	if String(link_phase.get("h3maped_anchor", "")) != "0x4a1f3b" \
			or String(link_phase.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(link_phase.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(link_phase.get("late_payload_consumer_anchor", "")) != "0x4a79a3" \
			or String(link_phase.get("status", "")) != "active_internal_state" \
			or int(link_phase.get("link_seed_count", -1)) != 5 \
			or link_seeds.size() != 5 \
			or int(link_seeds[0].get("source_zone_a", -1)) != 1 \
			or int(link_seeds[0].get("source_zone_b", -1)) != 4 \
			or int(link_seeds[0].get("runtime_zone_a", -1)) != 0 \
			or int(link_seeds[0].get("runtime_zone_b", -1)) != 3 \
			or int(link_seeds[0].get("guard_value", -1)) != 3000 \
			or int(link_seeds[3].get("guard_value", -1)) != 6000 \
			or bool(link_phase.get("materializes_coordinates", true)) \
			or bool(link_phase.get("materializes_connection_guards", true)) \
			or bool(link_phase.get("materializes_roads", true)) \
			or bool(link_phase.get("materializes_blockers", true)) \
			or bool(link_phase.get("materializes_public_output", true)):
		_fail("h3maped link seed setup drifted: %s" % JSON.stringify(link_phase))
		return
	var coordinate_phase: Dictionary = active_state.get("coordinate_replay", {})
	var bbox: Dictionary = coordinate_phase.get("bounding_box_rescale", {})
	var scaled_coords: Array = coordinate_phase.get("scaled_zone_coordinates", [])
	if String(coordinate_phase.get("h3maped_anchor", "")) != "0x4a218c" \
			or String(coordinate_phase.get("link_endpoint_consumer_anchor", "")) != "0x4a1f3b" \
			or String(coordinate_phase.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(coordinate_phase.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(coordinate_phase.get("candidate_prune_anchor", "")) != "0x4a1ad8" \
			or String(coordinate_phase.get("bbox_rescale_anchor", "")) != "0x4a19ed" \
			or String(coordinate_phase.get("status", "")) != "active_internal_state" \
			or int(coordinate_phase.get("placement_step_count", -1)) != 18 \
			or int(coordinate_phase.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18 \
			or int(coordinate_phase.get("town_choice_rng_calls_during_0x4a218c", -1)) != 4 \
			or int(coordinate_phase.get("total_interleaved_rng_calls_during_0x4a218c", -1)) != 22 \
			or int(coordinate_phase.get("rng_event_count", -1)) != 22 \
			or int(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", -1)) != 255755822 \
			or int(bbox.get("selected_span_before_rescale", -1)) != 84 \
			or scaled_coords.size() != 6 \
			or bool(coordinate_phase.get("materializes_zone_footprints", true)) \
			or bool(coordinate_phase.get("materializes_terrain", true)) \
			or bool(coordinate_phase.get("materializes_map_cells", true)) \
			or bool(coordinate_phase.get("materializes_public_output", true)):
		_fail("h3maped coordinate replay drifted: %s" % JSON.stringify(coordinate_phase))
		return
	var expected_coords := [
		{"x": 23, "y": 11},
		{"x": 21, "y": 22},
		{"x": 12, "y": 23},
		{"x": 18, "y": 4},
		{"x": 18, "y": 30},
		{"x": 12, "y": 11},
	]
	for coord_index in expected_coords.size():
		if int(scaled_coords[coord_index].get("runtime_zone_index", -1)) != coord_index \
				or int(scaled_coords[coord_index].get("x_after_bbox_rescale", -1)) != int(expected_coords[coord_index]["x"]) \
				or int(scaled_coords[coord_index].get("y_after_bbox_rescale", -1)) != int(expected_coords[coord_index]["y"]) \
				or int(scaled_coords[coord_index].get("level", -1)) != 0:
			_fail("h3maped scaled coordinate replay changed: %s" % JSON.stringify(scaled_coords))
			return
	var footprint_phase: Dictionary = active_state.get("zone_footprints", {})
	var cells_by_zone_word: Array = footprint_phase.get("cells_by_zone_word", [])
	if String(footprint_phase.get("h3maped_anchor", "")) != "0x4a3a03" \
			or String(footprint_phase.get("polygon_constructor_anchor", "")) != "0x4cc788" \
			or String(footprint_phase.get("polygon_split_anchor", "")) != "0x4ccb64" \
			or String(footprint_phase.get("polygon_finalize_anchor", "")) != "0x4ccdfc" \
			or String(footprint_phase.get("boundary_traversal_anchor", "")) != "0x4a2777" \
			or String(footprint_phase.get("span_fill_anchor", "")) != "0x4a325d" \
			or String(footprint_phase.get("small_land_finalizer_anchor", "")) != "0x4a3710" \
			or String(footprint_phase.get("status", "")) != "active_internal_state" \
			or int(footprint_phase.get("level_count", -1)) != 1 \
			or int(footprint_phase.get("h3maped_water_mode_code", -1)) != 0 \
			or bool(footprint_phase.get("synthetic_fallback_zone_allowed_by_0x4a3a9d", true)) \
			or int(footprint_phase.get("appended_synthetic_runtime_zone_count", -1)) != 0 \
			or int(footprint_phase.get("initial_bounds_min_x", 0)) != -200 \
			or int(footprint_phase.get("initial_bounds_min_y", 0)) != -200 \
			or int(footprint_phase.get("initial_bounds_max_x", 0)) != 400 \
			or int(footprint_phase.get("initial_bounds_max_y", 0)) != 400 \
			or int(footprint_phase.get("initial_node_pair_count", -1)) != 5 \
			or int(footprint_phase.get("total_matching_runtime_zones", -1)) != 6 \
			or int(footprint_phase.get("total_polygon_split_calls", -1)) != 6 \
			or int(footprint_phase.get("pre_crossing_inserted_node_pair_count", -1)) != 6 \
			or int(footprint_phase.get("pre_crossing_inserted_bridge_pair_count", -1)) != 12 \
			or int(footprint_phase.get("crossing_cleanup_scan_count", -1)) != 34 \
			or int(footprint_phase.get("crossing_test_count", -1)) != 24 \
			or int(footprint_phase.get("crossing_collapse_count", -1)) != 8 \
			or int(footprint_phase.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(footprint_phase.get("finalized_triplet_count", -1)) != 14 \
			or int(footprint_phase.get("finalized_node_count", -1)) != 42 \
			or int(footprint_phase.get("source_node_walk_count", -1)) != 6 \
			or int(footprint_phase.get("source_node_walk_guard_exhausted_count", -1)) != 0 \
			or String(footprint_phase.get("boundary_traversal_status", "")) != "0x4a2777_private_boundary_materialized" \
			or int(footprint_phase.get("boundary_runtime_zone_walk_count", -1)) != 6 \
			or int(footprint_phase.get("boundary_trace_write_count", -1)) != 301 \
			or int(footprint_phase.get("boundary_unique_cell_count", -1)) != 238 \
			or bool(footprint_phase.get("boundary_loop_guard_exhausted", true)) \
			or String(footprint_phase.get("span_fill_status", "")) != "0x4a325d_private_span_fill_materialized" \
			or int(footprint_phase.get("span_fill_filled_zone_count", -1)) != 6 \
			or int(footprint_phase.get("span_fill_unique_filled_cell_count", -1)) != 869 \
			or int(footprint_phase.get("span_fill_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(footprint_phase.get("span_fill_remaining_unassigned_cell_count", -1)) != 189 \
			or int(footprint_phase.get("reserved_cell_count", -1)) != 1107 \
			or cells_by_zone_word.size() != 6 \
			or not bool(footprint_phase.get("materializes_private_zone_cell_buffer", false)) \
			or bool(footprint_phase.get("materializes_terrain", true)) \
			or bool(footprint_phase.get("materializes_map_cells", true)) \
			or bool(footprint_phase.get("materializes_public_output", true)):
		_fail("h3maped zone-footprint phase drifted: %s" % JSON.stringify(footprint_phase))
		return
	var expected_zone_cells := [177, 91, 226, 177, 207, 229]
	for zone_index in expected_zone_cells.size():
		if int(cells_by_zone_word[zone_index].get("zone_word_id", -1)) != zone_index \
				or int(cells_by_zone_word[zone_index].get("cell_count", -1)) != expected_zone_cells[zone_index]:
			_fail("h3maped zone cell ownership counts changed: %s" % JSON.stringify(cells_by_zone_word))
			return
	var terrain_phase: Dictionary = active_state.get("terrain_cell_writeout", {})
	if String(terrain_phase.get("runtime_terrain_selection_anchor", "")) != "0x49b53d" \
			or String(terrain_phase.get("h3maped_anchor", "")) != "0x4a3f27" \
			or String(terrain_phase.get("span_fill_anchor", "")) != "0x4a325d" \
			or String(terrain_phase.get("status", "")) != "active_internal_state" \
			or Array(terrain_phase.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(terrain_phase.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(terrain_phase.get("terrain_rng_call_count", -1)) != 2 \
			or int(terrain_phase.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or int(terrain_phase.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160 \
			or int(terrain_phase.get("tile_count", -1)) != 1296 \
			or int(terrain_phase.get("private_zone_word_cell_count", -1)) != 1296 \
			or int(terrain_phase.get("assigned_owner_cell_count", -1)) != 1107 \
			or int(terrain_phase.get("unassigned_water_cell_count", -1)) != 189 \
			or int(terrain_phase.get("reserved_cell_count", -1)) != 1107 \
			or int(terrain_phase.get("span_fill_boundary_or_filled_cell_count", -1)) != 1107 \
			or not bool(terrain_phase.get("materializes_private_terrain_cell_buffer", false)) \
			or bool(terrain_phase.get("materializes_terrain_art", true)) \
			or bool(terrain_phase.get("materializes_roads", true)) \
			or bool(terrain_phase.get("materializes_objects", true)) \
			or bool(terrain_phase.get("materializes_map_cells", true)) \
			or bool(terrain_phase.get("materializes_public_output", true)) \
			or String(terrain_phase.get("blocked_next", "")) != "terrainplacement_visual_tables_0x4bcff5":
		_fail("h3maped terrain writeout phase drifted: %s" % JSON.stringify(terrain_phase))
		return
	var owner_low_byte_counts: Array = terrain_phase.get("owner_low_byte_counts", [])
	if owner_low_byte_counts.size() != 6:
		_fail("h3maped terrain owner-byte count size changed: %s" % JSON.stringify(owner_low_byte_counts))
		return
	for owner_index in expected_zone_cells.size():
		if int(owner_low_byte_counts[owner_index].get("owner_low_byte", -1)) != owner_index \
				or int(owner_low_byte_counts[owner_index].get("cell_count", -1)) != expected_zone_cells[owner_index]:
			_fail("h3maped terrain owner-byte counts changed: %s" % JSON.stringify(owner_low_byte_counts))
			return
	var terrain_counts: Dictionary = terrain_phase.get("terrain_project_counts", {})
	if int(terrain_counts.get("water", -1)) != 189 \
			or int(terrain_counts.get("grass", -1)) != 177 \
			or int(terrain_counts.get("dirt", -1)) != 91 \
			or int(terrain_counts.get("lava", -1)) != 403 \
			or int(terrain_counts.get("swamp", -1)) != 207 \
			or int(terrain_counts.get("rough", -1)) != 229:
		_fail("h3maped terrain project counts changed: %s" % JSON.stringify(terrain_counts))
		return
	var visual_phase: Dictionary = active_state.get("terrainplacement_visual_tables", {})
	if String(visual_phase.get("phase_id", "")) != "terrainplacement_visual_tables" \
			or String(visual_phase.get("h3maped_anchor", "")) != "0x4bcff5" \
			or String(visual_phase.get("terrainplacement_constructor_address", "")) != "0x4bb5ce" \
			or String(visual_phase.get("terrainplacement_wrapper_address", "")) != "0x4bd099" \
			or String(visual_phase.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or String(visual_phase.get("queue_drain_address", "")) != "0x4bc5f0" \
			or String(visual_phase.get("visual_selector_address", "")) != "0x4bcfc3" \
			or String(visual_phase.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(visual_phase.get("toolkit_table_address", "")) != "0x5436b8" \
			or String(visual_phase.get("status", "")) != "active_internal_state" \
			or bool(visual_phase.get("terrain_art_hash_fallback_allowed", true)) \
			or bool(visual_phase.get("materializes_visual_record", true)) \
			or bool(visual_phase.get("materializes_full_terrain_art_grid", true)) \
			or bool(visual_phase.get("materializes_package_tiles", true)) \
			or bool(visual_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(visual_phase.get("public_package_output_allowed", true)) \
			or int(visual_phase.get("table_count", -1)) != 5 \
			or int(visual_phase.get("decoded_total_row_count", -1)) != 230 \
			or int(visual_phase.get("expected_total_row_count", -1)) != 230 \
			or int(visual_phase.get("toolkit_constructor_record_count", -1)) != 10 \
			or int(visual_phase.get("visual_row_selection_sample_count", -1)) != 4 \
			or int(visual_phase.get("scratch_write_sample_count", -1)) != 4 \
			or String(visual_phase.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(visual_phase.get("generated_cell_write_address", "")) != "0x49acf6" \
			or String(visual_phase.get("blocked_next", "")) != "live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback":
		_fail("h3maped TerrainPlacement visual table phase drifted: %s" % JSON.stringify(visual_phase))
		return
	var visual_tables: Array = visual_phase.get("tables", [])
	var expected_table_rows := [79, 46, 24, 33, 48]
	var expected_table_addresses := ["0x543108", "0x543380", "0x5434f0", "0x5435b0", "0x542f88"]
	if visual_tables.size() != expected_table_rows.size():
		_fail("h3maped visual table count changed: %s" % JSON.stringify(visual_tables))
		return
	for table_index in expected_table_rows.size():
		if String(visual_tables[table_index].get("table_address", "")) != expected_table_addresses[table_index] \
				or int(visual_tables[table_index].get("decoded_row_count", -1)) != expected_table_rows[table_index] \
				or String(visual_tables[table_index].get("status", "")) != "decoded_from_h3maped_exe":
			_fail("h3maped visual table decode changed: %s" % JSON.stringify(visual_tables))
			return
	var row_samples: Array = visual_phase.get("visual_row_selection_samples", [])
	var expected_selected_rows := [60, 77, 20, 11]
	if row_samples.size() != expected_selected_rows.size():
		_fail("h3maped visual selector sample count changed: %s" % JSON.stringify(row_samples))
		return
	for sample_index in expected_selected_rows.size():
		if String(row_samples[sample_index].get("status", "")) != "visual_row_selected_from_decoded_h3maped_table" \
				or int(row_samples[sample_index].get("selected_row", -1)) != expected_selected_rows[sample_index]:
			_fail("h3maped visual selector samples changed: %s" % JSON.stringify(row_samples))
			return
	var scratch_samples: Array = visual_phase.get("scratch_write_samples", [])
	var expected_scratch_words := [1925, 6565, 657, 371]
	var expected_generated_0x24 := [3842, 4930, 1288, 713]
	var expected_generated_0x28 := [0, 32768, 0, 0]
	if scratch_samples.size() != expected_scratch_words.size():
		_fail("h3maped scratch sample count changed: %s" % JSON.stringify(scratch_samples))
		return
	for sample_index in expected_scratch_words.size():
		if int(scratch_samples[sample_index].get("scratch_word_u16", -1)) != expected_scratch_words[sample_index] \
				or int(scratch_samples[sample_index].get("generated_cell_word_0x24_u32", -1)) != expected_generated_0x24[sample_index] \
				or int(scratch_samples[sample_index].get("generated_cell_word_0x28_u32", -1)) != expected_generated_0x28[sample_index]:
			_fail("h3maped scratch/writeback samples changed: %s" % JSON.stringify(scratch_samples))
			return
	var live_feedback: Dictionary = active_state.get("terrainplacement_live_feedback", {})
	if String(live_feedback.get("phase_id", "")) != "terrainplacement_live_feedback" \
			or String(live_feedback.get("h3maped_anchor", "")) != "0x4bb74b/0x4bc5f0" \
			or String(live_feedback.get("full_water_repaint_address", "")) != "0x4a4025" \
			or String(live_feedback.get("zone_repaint_loop_address", "")) != "0x4a4082" \
			or String(live_feedback.get("single_cell_repaint_address", "")) != "0x4a415a" \
			or String(live_feedback.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or String(live_feedback.get("neighbor_seed_address", "")) != "0x4bba59" \
			or String(live_feedback.get("frontier_retouch_address", "")) != "0x4bbd01" \
			or String(live_feedback.get("queue_drain_address", "")) != "0x4bc5f0" \
			or String(live_feedback.get("candidate_gate_address", "")) != "0x4bc988" \
			or String(live_feedback.get("visual_selector_address", "")) != "0x4bcfc3" \
			or String(live_feedback.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(live_feedback.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(live_feedback.get("generated_cell_write_address", "")) != "0x49acf6" \
			or String(live_feedback.get("status", "")) != "active_internal_state" \
			or not bool(live_feedback.get("uses_live_scratch_neighbor_mask", false)) \
			or not bool(live_feedback.get("materializes_private_generated_cell_words", false)) \
			or bool(live_feedback.get("materializes_package_tiles", true)) \
			or bool(live_feedback.get("project_grid_public_runtime_adoption", true)) \
			or bool(live_feedback.get("public_package_output_allowed", true)) \
			or not bool(live_feedback.get("visual_tables_decoded", false)) \
			or int(live_feedback.get("tile_count", -1)) != 1296 \
			or not bool(live_feedback.get("exact_queue_drain_complete", false)) \
			or not bool(live_feedback.get("live_feedback_materialized", false)) \
			or int(live_feedback.get("live_visual_attempt_count", -1)) != 2845 \
			or int(live_feedback.get("live_visual_write_count", -1)) != 2845 \
			or int(live_feedback.get("live_visual_missing_bucket_count", -1)) != 0 \
			or int(live_feedback.get("live_initial_water_attempt_count", -1)) != 1296 \
			or int(live_feedback.get("live_repaint_attempt_count", -1)) != 942 \
			or int(live_feedback.get("live_queue_attempt_count", -1)) != 607 \
			or int(live_feedback.get("live_dirty_cell_count", -1)) != 1296 \
			or int(live_feedback.get("live_roundtrip_mismatch_count", -1)) != 0 \
			or int(live_feedback.get("live_terrain_mismatch_count", -1)) != 0 \
			or int(live_feedback.get("live_full_native_cell_count", -1)) != 1326 \
			or int(live_feedback.get("live_terrain_art_nonzero_cell_count", -1)) != 2785 \
			or int(live_feedback.get("live_terrain_flag_cell_count", -1)) != 1255 \
			or int(live_feedback.get("post_queue_terrain_difference_count", -1)) != 181 \
			or int(live_feedback.get("changed_cell_update_count", -1)) != 1107 \
			or int(live_feedback.get("initial_set_a_candidate_count", -1)) != 1 \
			or int(live_feedback.get("initial_set_b_candidate_count", -1)) != 46 \
			or int(live_feedback.get("total_set_a_insert_count", -1)) != 176 \
			or int(live_feedback.get("total_set_b_insert_count", -1)) != 10522 \
			or int(live_feedback.get("set_a_drain_count", -1)) != 176 \
			or int(live_feedback.get("set_b_drain_count", -1)) != 10522 \
			or int(live_feedback.get("set_b_candidate_true_count", -1)) != 386 \
			or int(live_feedback.get("retouched_cell_write_count", -1)) != 221 \
			or bool(live_feedback.get("drain_guard_exhausted", true)) \
			or int(live_feedback.get("rng_state_after_live_visual_selection_uint32", -1)) != 1452413421 \
			or String(live_feedback.get("blocked_next", "")) != "private_0x49b2b6_tile_byte_writeback_candidate":
		_fail("h3maped TerrainPlacement live feedback phase drifted: %s" % JSON.stringify(live_feedback))
		return
	var tile_byte_phase: Dictionary = active_state.get("terrain_tile_byte_writeback", {})
	if String(tile_byte_phase.get("phase_id", "")) != "terrain_tile_byte_writeback" \
			or String(tile_byte_phase.get("h3maped_anchor", "")) != "0x49b2b6" \
			or String(tile_byte_phase.get("generated_cell_write_address", "")) != "0x49acf6" \
			or String(tile_byte_phase.get("status", "")) != "active_internal_state" \
			or not bool(tile_byte_phase.get("materializes_private_tile_byte_candidates", false)) \
			or bool(tile_byte_phase.get("materializes_package_tiles", true)) \
			or bool(tile_byte_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(tile_byte_phase.get("public_package_output_allowed", true)) \
			or bool(tile_byte_phase.get("road_river_bytes_materialized", true)) \
			or bool(tile_byte_phase.get("object_bytes_materialized", true)) \
			or int(tile_byte_phase.get("tile_count", -1)) != 1296 \
			or int(tile_byte_phase.get("terrain_byte_candidate_count", -1)) != 1296 \
			or int(tile_byte_phase.get("terrain_byte_mismatch_count", -1)) != 0 \
			or int(tile_byte_phase.get("terrain_art_nonzero_cell_count", -1)) != 1238 \
			or int(tile_byte_phase.get("terrain_flag_nonzero_cell_count", -1)) != 1033 \
			or int(tile_byte_phase.get("road_river_nonzero_byte_count", -1)) != 0 \
			or int(tile_byte_phase.get("sample_tile_byte_record_count", -1)) != 16 \
			or String(tile_byte_phase.get("blocked_next", "")) != "town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2":
		_fail("h3maped terrain tile-byte writeback phase drifted: %s" % JSON.stringify(tile_byte_phase))
		return
	var terrain_histogram: Dictionary = tile_byte_phase.get("tile_byte_0_histogram", {})
	var flag_histogram: Dictionary = tile_byte_phase.get("tile_byte_6_flag_histogram", {})
	if int(terrain_histogram.get("0", -1)) != 97 \
			or int(terrain_histogram.get("2", -1)) != 138 \
			or int(terrain_histogram.get("4", -1)) != 262 \
			or int(terrain_histogram.get("5", -1)) != 269 \
			or int(terrain_histogram.get("7", -1)) != 444 \
			or int(terrain_histogram.get("8", -1)) != 86 \
			or int(flag_histogram.get("0", -1)) != 263 \
			or int(flag_histogram.get("1", -1)) != 112 \
			or int(flag_histogram.get("2", -1)) != 150 \
			or int(flag_histogram.get("3", -1)) != 771:
		_fail("h3maped terrain tile-byte histograms changed: %s / %s" % [JSON.stringify(terrain_histogram), JSON.stringify(flag_histogram)])
		return
	var town_phase: Dictionary = active_state.get("town_castle_phase", {})
	if String(town_phase.get("phase_id", "")) != "town_castle_phase" \
			or String(town_phase.get("h3maped_anchor", "")) != "0x4a8d2c/0x4a8db2/0x4a93a2" \
			or String(town_phase.get("direct_object_helper_anchor", "")) != "0x4a93a2" \
			or String(town_phase.get("candidate_gate_anchor", "")) != "0x49aa93" \
			or String(town_phase.get("footprint_gate_anchor", "")) != "0x49a09c" \
			or String(town_phase.get("town_type_chooser_anchor", "")) != "0x49b3c1" \
			or String(town_phase.get("object_record_constructor_anchor", "")) != "0x49ba89" \
			or String(town_phase.get("town_vtable_anchor", "")) != "0x540a9c" \
			or String(town_phase.get("status", "")) != "active_internal_state" \
			or not bool(town_phase.get("materializes_private_town_candidates", false)) \
			or bool(town_phase.get("materializes_town_objects", true)) \
			or bool(town_phase.get("materializes_package_tiles", true)) \
			or bool(town_phase.get("adopts_into_runtime_grid", true)) \
			or bool(town_phase.get("public_package_output_allowed", true)) \
			or int(town_phase.get("map_width", -1)) != 36 \
			or int(town_phase.get("map_height", -1)) != 36 \
			or int(town_phase.get("level_count", -1)) != 1 \
			or int(town_phase.get("cell_count", -1)) != 1296 \
			or int(town_phase.get("source_player_min_town_count", -1)) != 0 \
			or int(town_phase.get("source_player_min_castle_count", -1)) != 4 \
			or int(town_phase.get("assigned_player_min_town_count", -1)) != 0 \
			or int(town_phase.get("assigned_player_min_castle_count", -1)) != 3 \
			or int(town_phase.get("skipped_unassigned_player_start_min_town_count", -1)) != 0 \
			or int(town_phase.get("skipped_unassigned_player_start_min_castle_count", -1)) != 1 \
			or int(town_phase.get("neutral_minimum_town_castle_count", -1)) != 0 \
			or int(town_phase.get("density_schedule_count", -1)) != 0 \
			or int(town_phase.get("scheduled_direct_minimum_object_count", -1)) != 3 \
			or int(town_phase.get("scheduled_owned_player_town_count", -1)) != 3 \
			or int(town_phase.get("project_town_record_candidate_count", -1)) != 3 \
			or int(town_phase.get("project_player_start_candidate_count", -1)) != 3 \
			or String(town_phase.get("blocked_next", "")) != "object_vector_prerequisite_phase_4a9d6a_4aab7e":
		_fail("h3maped town/castle phase drifted: %s" % JSON.stringify(town_phase))
		return
	var direct_stamping: Dictionary = town_phase.get("direct_stamping_projection", {})
	if String(direct_stamping.get("status", "")) != "0x4a93a2_0x49ba89_direct_town_object_stamping_projection_private" \
			or int(direct_stamping.get("direct_candidate_scan_count", -1)) != 3 \
			or int(direct_stamping.get("direct_candidate_total", -1)) != 445 \
			or int(direct_stamping.get("direct_candidate_missing_count", -1)) != 0 \
			or int(direct_stamping.get("direct_footprint_eligible_total", -1)) != 85 \
			or int(direct_stamping.get("direct_footprint_missing_count", -1)) != 0 \
			or int(direct_stamping.get("direct_footprint_rejected_bounds_count", -1)) != 134 \
			or int(direct_stamping.get("direct_footprint_rejected_zone_count", -1)) != 222 \
			or int(direct_stamping.get("direct_footprint_rejected_terrain_count", -1)) != 0 \
			or int(direct_stamping.get("direct_footprint_rejected_collision_count", -1)) != 4 \
			or int(direct_stamping.get("direct_footprint_marked_cell_count", -1)) != 39 \
			or int(direct_stamping.get("direct_unique_selection_count", -1)) != 2 \
			or int(direct_stamping.get("direct_random_tie_selection_count", -1)) != 1 \
			or int(direct_stamping.get("direct_random_tie_rng_call_count", -1)) != 1 \
			or int(direct_stamping.get("direct_record_projection_count", -1)) != 3 \
			or int(direct_stamping.get("object_rng_state_before_0x4a93a2_uint32", -1)) != 2166683160 \
			or int(direct_stamping.get("object_rng_state_after_0x4a93a2_uint32", -1)) != 811474043 \
			or bool(direct_stamping.get("runtime_package_adoption", true)) \
			or bool(direct_stamping.get("stamps_generated_cell_state", true)):
		_fail("h3maped direct town stamping drifted: %s" % JSON.stringify(direct_stamping))
		return
	var project_towns: Dictionary = town_phase.get("project_town_adoption_candidate", {})
	var town_records: Array = project_towns.get("town_records", [])
	var player_starts: Array = project_towns.get("player_starts", [])
	if String(project_towns.get("status", "")) != "h3maped_project_town_adoption_candidate_private" \
			or bool(project_towns.get("public_package_adoption", true)) \
			or bool(project_towns.get("runtime_grid_adoption", true)) \
			or int(project_towns.get("town_record_count", -1)) != 3 \
			or int(project_towns.get("player_start_count", -1)) != 3 \
			or int(project_towns.get("expected_player_count", -1)) != 3 \
			or int(project_towns.get("synchronized_player_start_count", -1)) != 3 \
			or Array(project_towns.get("owner_slots", [])) != [1, 2, 3] \
			or town_records.size() != 3 \
			or player_starts.size() != 3:
		_fail("h3maped project town candidate bridge drifted: %s" % JSON.stringify(project_towns))
		return
	var expected_town_points := [
		{"slot": 1, "x": 26, "y": 16, "town": "town_riverwatch", "faction": "faction_embercourt", "owner": "player"},
		{"slot": 2, "x": 23, "y": 23, "town": "town_duskfen", "faction": "faction_mireclaw", "owner": "enemy"},
		{"slot": 3, "x": 18, "y": 5, "town": "town_prismhearth", "faction": "faction_sunvault", "owner": "enemy"},
	]
	for town_index in expected_town_points.size():
		var expected: Dictionary = expected_town_points[town_index]
		if int(town_records[town_index].get("player_slot", -1)) != int(expected["slot"]) \
				or int(town_records[town_index].get("x", -1)) != int(expected["x"]) \
				or int(town_records[town_index].get("y", -1)) != int(expected["y"]) \
				or String(town_records[town_index].get("town_id", "")) != String(expected["town"]) \
				or String(town_records[town_index].get("faction_id", "")) != String(expected["faction"]) \
				or String(town_records[town_index].get("owner", "")) != String(expected["owner"]) \
				or not bool(town_records[town_index].get("is_start_town", false)) \
				or not bool(town_records[town_index].get("is_castle", false)) \
				or int(player_starts[town_index].get("player_slot", -1)) != int(expected["slot"]) \
				or int(player_starts[town_index].get("x", -1)) != int(expected["x"]) \
				or int(player_starts[town_index].get("y", -1)) != int(expected["y"]):
			_fail("h3maped town/start coordinates drifted: %s / %s" % [JSON.stringify(town_records), JSON.stringify(player_starts)])
			return
	var object_vector_phase: Dictionary = active_state.get("mines_rewards_and_object_vector", {})
	if String(object_vector_phase.get("phase_id", "")) != "mines_rewards_and_object_vector" \
			or String(object_vector_phase.get("status", "")) != "active_internal_state" \
			or String(object_vector_phase.get("mine_phase_anchor", "")) != "0x4a9d6a" \
			or String(object_vector_phase.get("mine_coordinate_attempt_anchor", "")) != "0x4a9911/0x4a9641" \
			or String(object_vector_phase.get("reward_scheduler_anchor", "")) != "0x4aab7e/0x4aa354" \
			or String(object_vector_phase.get("candidate_vector_builder_anchor", "")) != "0x49f95a..0x4a1701" \
			or String(object_vector_phase.get("candidate_selector_anchor", "")) != "0x4a9f1c" \
			or String(object_vector_phase.get("reward_coordinate_anchor", "")) != "0x4aa9b7" \
			or not bool(object_vector_phase.get("materializes_private_object_vector_prerequisites", false)) \
			or bool(object_vector_phase.get("materializes_private_mine_records", true)) \
			or bool(object_vector_phase.get("materializes_private_reward_coordinate_records", true)) \
			or bool(object_vector_phase.get("materializes_public_objects", true)) \
			or bool(object_vector_phase.get("adopts_into_runtime_grid", true)) \
			or bool(object_vector_phase.get("public_package_output_allowed", true)) \
			or int(object_vector_phase.get("candidate_vector_single_level_total_count", -1)) != 704 \
			or int(object_vector_phase.get("candidate_vector_materialized_static_subset_count", -1)) != 110 \
			or int(object_vector_phase.get("candidate_vector_materialized_monster_count", -1)) != 118 \
			or int(object_vector_phase.get("candidate_vector_type10_count", -1)) != 40 \
			or int(object_vector_phase.get("candidate_vector_type17_count", -1)) != 58 \
			or int(object_vector_phase.get("candidate_vector_type53_count", -1)) != 378 \
			or int(object_vector_phase.get("selector_global_limit_override_count", -1)) != 30 \
			or int(object_vector_phase.get("selector_per_zone_limit_override_count", -1)) != 24 \
			or bool(object_vector_phase.get("reward_coordinate_commit_materialized", true)) \
			or int(object_vector_phase.get("project_object_adoption_candidate_count", -1)) != 0 \
			or String(object_vector_phase.get("blocked_next", "")) != "private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9":
		_fail("h3maped object-vector prerequisite phase drifted: %s" % JSON.stringify(object_vector_phase))
		return
	var mine_boundary: Dictionary = object_vector_phase.get("mine_requirements_boundary", {})
	var min_by_category: Dictionary = mine_boundary.get("minimum_by_category", {})
	var density_by_category: Dictionary = mine_boundary.get("density_by_category", {})
	if int(mine_boundary.get("runtime_zone_record_count", -1)) != 6 \
			or int(mine_boundary.get("total_minimum_mine_count", -1)) != 18 \
			or int(mine_boundary.get("total_density_weight", -1)) != 18 \
			or int(min_by_category.get("wood", -1)) != 4 \
			or int(min_by_category.get("ore", -1)) != 4 \
			or int(min_by_category.get("gold", -1)) != 2 \
			or int(min_by_category.get("mercury", -1)) != 2 \
			or int(min_by_category.get("sulfur", -1)) != 2 \
			or int(min_by_category.get("crystal", -1)) != 2 \
			or int(min_by_category.get("gems", -1)) != 2 \
			or int(density_by_category.get("wood", -1)) != 4 \
			or int(density_by_category.get("ore", -1)) != 4 \
			or int(density_by_category.get("gold", -1)) != 2 \
			or bool(mine_boundary.get("private_coordinate_attempts_materialized", true)):
		_fail("h3maped mine prerequisite boundary drifted: %s" % JSON.stringify(mine_boundary))
		return
	var reward_scheduler: Dictionary = object_vector_phase.get("reward_scheduler_boundary", {})
	if String(reward_scheduler.get("status", "")) != "0x4aab7e_per_zone_reward_band_scheduler_preview_private" \
			or int(reward_scheduler.get("total_treasure_band_count", -1)) != 18 \
			or int(reward_scheduler.get("eligible_reward_band_count", -1)) != 18 \
			or int(reward_scheduler.get("eligible_reward_density_sum", -1)) != 96 \
			or String(reward_scheduler.get("coordinate_commit_anchor", "")) != "0x4aa9b7" \
			or String(reward_scheduler.get("coordinate_filter_anchor", "")) != "0x4aa603" \
			or String(reward_scheduler.get("final_object_commit_anchor", "")) != "0x4aa3e9" \
			or bool(reward_scheduler.get("materializes_private_reward_coordinate_records", true)) \
			or bool(reward_scheduler.get("materializes_public_reward_objects", true)):
		_fail("h3maped reward scheduler boundary drifted: %s" % JSON.stringify(reward_scheduler))
		return
	var vector_order: Dictionary = object_vector_phase.get("candidate_vector_order_boundary", {})
	if String(vector_order.get("status", "")) != "single_level_candidate_vector_order_materialized_public_commit_pending" \
			or int(vector_order.get("single_level_total_candidate_record_count", -1)) != 704 \
			or int(vector_order.get("first_type10_candidate_vector_index", -1)) != 138 \
			or int(vector_order.get("first_type17_candidate_vector_index", -1)) != 192 \
			or int(vector_order.get("first_type53_candidate_vector_index", -1)) != 297 \
			or int(vector_order.get("last_type53_candidate_vector_index", -1)) != 674 \
			or not bool(vector_order.get("candidate_vector_indices_materialized", false)) \
			or bool(vector_order.get("candidate_records_fully_materialized", true)) \
			or bool(vector_order.get("public_coordinate_commit_materialized", true)):
		_fail("h3maped candidate-vector order boundary drifted: %s" % JSON.stringify(vector_order))
		return
	var monster_boundary: Dictionary = object_vector_phase.get("single_level_monster_candidate_boundary", {})
	if String(monster_boundary.get("status", "")) != "single_level_monster_candidate_loop_materialized_from_crtraits_and_static_table" \
			or String(monster_boundary.get("load_status", "")) != "loaded" \
			or int(monster_boundary.get("candidate_record_count", -1)) != 118 \
			or int(monster_boundary.get("first_candidate_vector_index", -1)) != 2 \
			or int(monster_boundary.get("last_candidate_vector_index", -1)) != 119 \
			or int(monster_boundary.get("missing_source_row_count", -1)) != 0 \
			or int(monster_boundary.get("inactive_gate_count", -1)) != 0 \
			or int(monster_boundary.get("invalid_ai_value_count", -1)) != 0:
		_fail("h3maped monster candidate boundary drifted: %s" % JSON.stringify(monster_boundary))
		return
	if String(report.get("archived_report_treadmill_path", "")) != "src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp":
		_fail("The report-treadmill implementation was not archived: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("status", "")) != "verified_reset_anchor" \
			or not bool(binary.get("mz_header_present", false)) \
			or not bool(binary.get("sha256_matches", false)) \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("h3maped.exe anchor verification failed: %s" % JSON.stringify(binary))
		return

	if int(report.get("size_score", -1)) != 1 \
			or int(report.get("h3maped_water_mode_code", -1)) != 0 \
			or int(report.get("accepted_template_count", -1)) != 13:
		_fail("Small land template boundary changed: %s" % JSON.stringify(report))
		return

	var selection: Dictionary = report.get("selection_identity", {})
	if not bool(selection.get("ok", false)) \
			or String(selection.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or int(selection.get("source_catalog_index", -1)) != 18 \
			or String(selection.get("adapted_template_id", "")) != "translated_rmg_template_019_v1" \
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("rng_state_after_selection_uint32", -1)) != 2745024:
		_fail("h3maped RNG template selection drifted: %s" % JSON.stringify(selection))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 12 \
			or String(backlog[0].get("id", "")) != "template_selection" \
			or String(backlog[0].get("status", "")) != "active_boundary" \
			or String(backlog[1].get("id", "")) != "player_slot_assignment" \
			or String(backlog[1].get("status", "")) != "active_internal_state" \
			or String(backlog[2].get("id", "")) != "runtime_zone_records" \
			or String(backlog[2].get("status", "")) != "active_internal_state" \
			or String(backlog[3].get("id", "")) != "link_seed_setup" \
			or String(backlog[3].get("status", "")) != "active_internal_state" \
			or String(backlog[4].get("id", "")) != "coordinate_replay" \
			or String(backlog[4].get("status", "")) != "active_internal_state" \
			or String(backlog[5].get("id", "")) != "zone_footprints" \
			or String(backlog[5].get("status", "")) != "active_internal_state" \
			or String(backlog[6].get("id", "")) != "terrain_and_terrainplacement" \
			or String(backlog[6].get("status", "")) != "terrain_tile_byte_writeback_active_internal_state" \
			or String(backlog[7].get("id", "")) != "town_object_placement" \
			or String(backlog[7].get("status", "")) != "active_internal_state_private_candidates" \
			or String(backlog[8].get("id", "")) != "mines_rewards_and_object_vector" \
			or String(backlog[8].get("status", "")) != "active_internal_state_private_prerequisite_boundary" \
			or String(backlog[9].get("id", "")) != "roads_and_rivers" \
			or String(backlog[10].get("id", "")) != "connections_blockers_and_guards" \
			or String(backlog[11].get("id", "")) != "final_h3m_writeout":
		_fail("Fresh h3maped phase backlog drifted: %s" % JSON.stringify(backlog))
		return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Fresh backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var generated: Dictionary = service.generate_random_map(config, {})
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or bool(generated.get("runtime_generation_allowed", true)):
		_fail("Fresh h3maped boundary must keep runtime generation blocked: %s" % JSON.stringify(generated))
		return

	print("%s: PASS" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
