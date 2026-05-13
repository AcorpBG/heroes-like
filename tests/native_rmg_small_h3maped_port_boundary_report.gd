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

	var supported_config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var report: Dictionary = service.inspect_h3maped_small_rmg_port(supported_config)
	if not bool(report.get("ok", false)):
		_fail("Strict small h3maped boundary rejected the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1" \
			or String(report.get("implementation_policy", "")) != "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback" \
			or String(report.get("scope", "")) != "small_36x36_surface_land_only":
		_fail("Strict restart boundary metadata drifted: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) \
			or bool(report.get("partial_materialized_payload_public_api", true)) \
			or report.has("active_generation_state") \
			or report.has("small_generation_state") \
			or report.has("private_generation_context"):
		_fail("Strict restart boundary exposed active generation payload: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("path", "")) != "/root/Downloads/h3maped.exe" \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37" \
			or int(binary.get("actual_size_bytes", -1)) != 2134016 \
			or not bool(binary.get("mz_header_present", false)):
		_fail("h3maped.exe binary anchor is not verified: %s" % JSON.stringify(binary))
		return

	var selection: Dictionary = report.get("selection_identity", {})
	if not bool(selection.get("ok", false)) \
			or String(selection.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(selection.get("rng_function_address", "")) != "0x4e7276" \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or String(selection.get("adapted_template_id", "")) != "translated_rmg_template_019_v1":
		_fail("Strict h3maped template selection drifted: %s" % JSON.stringify(selection))
		return

	var player_slots: Dictionary = report.get("player_slot_assignment", {})
	if String(player_slots.get("status", "")) != "active_strict_executable_port" \
			or String(player_slots.get("source_range", "")) != "0x4ac62a..0x4ac6ec" \
			or String(player_slots.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(player_slots.get("mapped_slots_offset", "")) != "generator+0xee4" \
			or String(player_slots.get("binary_byte_prefix_0x4ac62a", "")) != "6a 09 8d be e0 0e 00 00 59 83 c8 ff f3 ab 33 d2" \
			or Array(player_slots.get("raw_ee0_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(player_slots.get("mapped_ee4_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or int(player_slots.get("assigned_player_count", -1)) != 3:
		_fail("Strict h3maped player-slot assignment drifted: %s" % JSON.stringify(player_slots))
		return
	var assignments: Array = player_slots.get("assignment_records", [])
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
		_fail("Strict h3maped player-slot records drifted: %s" % JSON.stringify(assignments))
		return

	var runtime_zone_phase: Dictionary = report.get("runtime_zone_records", {})
	if String(runtime_zone_phase.get("status", "")) != "active_strict_executable_port" \
			or String(runtime_zone_phase.get("source_range", "")) != "0x4a218c/0x49b452" \
			or String(runtime_zone_phase.get("runtime_zone_vector_begin_offset", "")) != "generator+0x10e0" \
			or String(runtime_zone_phase.get("runtime_zone_vector_end_offset", "")) != "generator+0x10e4" \
			or String(runtime_zone_phase.get("runtime_zone_vector_capacity_offset", "")) != "generator+0x10e8" \
			or int(runtime_zone_phase.get("runtime_zone_record_size_bytes", -1)) != 0x414 \
			or String(runtime_zone_phase.get("binary_byte_prefix_0x4a218c", "")) != "55 8b ec 83 ec 28 53 8b d9 56 57 ff b3 e8 10 00" \
			or String(runtime_zone_phase.get("binary_byte_prefix_0x49b452", "")) != "55 8b ec 53 56 8b f1 33 db 8a 4d 0b 57 8d 86 e4" \
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
			or bool(runtime_zone_phase.get("materializes_runtime_players", true)) \
			or bool(runtime_zone_phase.get("materializes_public_output", true)):
		_fail("Strict h3maped runtime-zone record port drifted: %s" % JSON.stringify(runtime_zone_phase))
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
		_fail("Strict h3maped runtime-zone records changed: %s" % JSON.stringify(runtime_records))
		return

	var link_phase: Dictionary = report.get("link_seed_setup", {})
	var link_seeds: Array = link_phase.get("link_seeds", [])
	if String(link_phase.get("status", "")) != "active_strict_executable_port" \
			or String(link_phase.get("source_range", "")) != "0x4a1f3b" \
			or String(link_phase.get("binary_byte_prefix_0x4a1f3b", "")) != "b8 54 a7 52 00 e8 8b 41 04 00 83 ec 2c 8a 45 0b" \
			or String(link_phase.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(link_phase.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(link_phase.get("late_payload_consumer_anchor", "")) != "0x4a79a3" \
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
		_fail("Strict h3maped link-seed setup drifted: %s" % JSON.stringify(link_phase))
		return

	var coordinate_phase: Dictionary = report.get("coordinate_replay", {})
	var bbox: Dictionary = coordinate_phase.get("bounding_box_rescale", {})
	var scaled_coords: Array = coordinate_phase.get("scaled_zone_coordinates", [])
	if String(coordinate_phase.get("status", "")) != "active_strict_executable_port" \
			or String(coordinate_phase.get("source_range", "")) != "0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed" \
			or String(coordinate_phase.get("binary_byte_prefix_0x4a17f5", "")) != "55 8b ec 83 ec 38 8b 45 08 53 56 57 8b 5d 0c 8d" \
			or String(coordinate_phase.get("binary_byte_prefix_0x4a1701", "")) != "55 8b ec 83 ec 34 8b 55 08 53 56 57 8d 72 10 8d" \
			or String(coordinate_phase.get("binary_byte_prefix_0x4a1ad8", "")) != "55 8b ec 83 ec 40 83 65 f0 00 83 79 20 01 53 8b" \
			or String(coordinate_phase.get("binary_byte_prefix_0x4a19ed", "")) != "55 8b ec 83 ec 14 8b 55 10 53 8b 5d 08 8b c1 8b" \
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
		_fail("Strict h3maped coordinate replay drifted: %s" % JSON.stringify(coordinate_phase))
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
			_fail("Strict h3maped scaled coordinate replay changed: %s" % JSON.stringify(scaled_coords))
			return

	var zone_source_nodes: Dictionary = report.get("zone_footprint_source_nodes", {})
	var split_steps: Array = zone_source_nodes.get("split_steps", [])
	if String(zone_source_nodes.get("status", "")) != "active_strict_executable_port" \
			or String(zone_source_nodes.get("source_range", "")) != "0x4a3a03/0x4cc788/0x4cc955/0x4ccb64/0x4ccdfc" \
			or String(zone_source_nodes.get("binary_byte_prefix_0x4a3a03", "")) != "b8 ea a7 52 00 e8 c3 26 04 00 81 ec 64 05 00 00" \
			or String(zone_source_nodes.get("binary_byte_prefix_0x4cc788", "")) != "b8 f3 ca 52 00 e8 3e 99 01 00 83 ec 1c 8a 45 f3" \
			or String(zone_source_nodes.get("binary_byte_prefix_0x4cc955", "")) != "b8 0a cb 52 00 e8 71 97 01 00 51 51 56 8b f1 6a" \
			or String(zone_source_nodes.get("binary_byte_prefix_0x4ccb64", "")) != "55 8b ec 83 ec 0c 53 56 57 8b 7d 08 ff 75 0c 8b" \
			or String(zone_source_nodes.get("binary_byte_prefix_0x4ccdfc", "")) != "55 8b ec 83 ec 0c 83 65 fc 00 53 56 57 8b d9 8b" \
			or int(zone_source_nodes.get("total_matching_runtime_zones", -1)) != 6 \
			or int(zone_source_nodes.get("total_polygon_split_calls", -1)) != 6 \
			or int(zone_source_nodes.get("pre_crossing_inserted_node_pair_count", -1)) != 6 \
			or int(zone_source_nodes.get("pre_crossing_inserted_bridge_pair_count", -1)) != 12 \
			or int(zone_source_nodes.get("crossing_cleanup_scan_count", -1)) != 34 \
			or int(zone_source_nodes.get("crossing_test_count", -1)) != 24 \
			or int(zone_source_nodes.get("crossing_collapse_count", -1)) != 8 \
			or int(zone_source_nodes.get("post_crossing_cleanup_allocated_node_pair_count", -1)) != 23 \
			or int(zone_source_nodes.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(zone_source_nodes.get("finalized_triplet_count", -1)) != 14 \
			or int(zone_source_nodes.get("finalized_node_count", -1)) != 42 \
			or int(zone_source_nodes.get("active_payload_node_count", -1)) != 28 \
			or int(zone_source_nodes.get("source_node_walk_count", -1)) != 6 \
			or int(zone_source_nodes.get("source_node_walk_guard_exhausted_count", -1)) != 0 \
			or split_steps.size() != 6 \
			or int(split_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(split_steps[0].get("x", -1)) != 23 \
			or int(split_steps[0].get("y", -1)) != 11 \
			or int(split_steps[5].get("runtime_zone_index", -1)) != 5 \
			or int(split_steps[5].get("x", -1)) != 12 \
			or int(split_steps[5].get("y", -1)) != 11 \
			or bool(zone_source_nodes.get("materializes_boundary_trace", true)) \
			or bool(zone_source_nodes.get("materializes_span_fill", true)) \
			or bool(zone_source_nodes.get("materializes_private_zone_cell_buffer", true)) \
			or bool(zone_source_nodes.get("materializes_terrain", true)) \
			or bool(zone_source_nodes.get("materializes_map_cells", true)) \
			or bool(zone_source_nodes.get("materializes_public_output", true)):
		_fail("Strict h3maped zone source-node port drifted: %s" % JSON.stringify(zone_source_nodes))
		return

	var zone_boundary_span: Dictionary = report.get("zone_boundary_and_span_fill", {})
	var cells_by_zone_word: Array = zone_boundary_span.get("cells_by_zone_word", [])
	if String(zone_boundary_span.get("status", "")) != "active_strict_executable_port" \
			or String(zone_boundary_span.get("source_range", "")) != "0x4a2777/0x4a2b33/0x4a261a/0x4a2413/0x4a325d" \
			or String(zone_boundary_span.get("binary_byte_prefix_0x4a2777", "")) != "55 8b ec 81 ec 88 00 00 00 53 8b 5d 08 56 57 8b" \
			or String(zone_boundary_span.get("binary_byte_prefix_0x4a2b33", "")) != "55 8b ec 83 ec 18 53 8b 5d 1c 56 8b 75 0c 8b 13" \
			or String(zone_boundary_span.get("binary_byte_prefix_0x4a261a", "")) != "55 8b ec 83 ec 20 8b 55 10 53 56 8b f1 8b 4d 08" \
			or String(zone_boundary_span.get("binary_byte_prefix_0x4a2413", "")) != "b8 68 a7 52 00 e8 b3 3c 04 00 83 ec 30 8a 45 1f" \
			or String(zone_boundary_span.get("binary_byte_prefix_0x4a325d", "")) != "b8 a4 a7 52 00 e8 69 2e 04 00 83 ec 60 8b 45 08" \
			or int(zone_boundary_span.get("boundary_runtime_zone_walk_count", -1)) != 6 \
			or int(zone_boundary_span.get("boundary_blocked_zone_count", -1)) != 0 \
			or int(zone_boundary_span.get("boundary_fallback_zone_count", -1)) != 0 \
			or int(zone_boundary_span.get("boundary_connector_segment_count", -1)) != 6 \
			or int(zone_boundary_span.get("boundary_wrap_segment_count", -1)) != 0 \
			or int(zone_boundary_span.get("boundary_final_segment_count", -1)) != 12 \
			or int(zone_boundary_span.get("boundary_flagged_writer_segment_count", -1)) != 6 \
			or int(zone_boundary_span.get("boundary_deterministic_writer_segment_count", -1)) != 12 \
			or int(zone_boundary_span.get("boundary_randomized_rng_call_count", -1)) != 106 \
			or int(zone_boundary_span.get("boundary_randomized_inserted_midpoint_count", -1)) != 138 \
			or int(zone_boundary_span.get("boundary_randomized_max_pending_point_count", -1)) != 8 \
			or int(zone_boundary_span.get("boundary_rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(zone_boundary_span.get("boundary_trace_write_count", -1)) != 301 \
			or int(zone_boundary_span.get("boundary_unique_cell_count", -1)) != 238 \
			or int(zone_boundary_span.get("boundary_out_of_bounds_write_count", -1)) != 0 \
			or bool(zone_boundary_span.get("boundary_loop_guard_exhausted", true)) \
			or int(zone_boundary_span.get("span_fill_filled_zone_count", -1)) != 6 \
			or int(zone_boundary_span.get("span_fill_seed_blocked_count", -1)) != 1 \
			or int(zone_boundary_span.get("span_fill_unique_filled_cell_count", -1)) != 869 \
			or int(zone_boundary_span.get("span_fill_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(zone_boundary_span.get("span_fill_remaining_unassigned_cell_count", -1)) != 189 \
			or int(zone_boundary_span.get("span_fill_reserved_cell_count", -1)) != 1107 \
			or int(zone_boundary_span.get("span_fill_pushed_span_count", -1)) != 93 \
			or int(zone_boundary_span.get("span_fill_popped_span_count", -1)) != 93 \
			or int(zone_boundary_span.get("span_fill_max_pending_span_count", -1)) != 3 \
			or int(zone_boundary_span.get("span_fill_out_of_bounds_span_count", -1)) != 0 \
			or int(zone_boundary_span.get("span_fill_blocked_initial_span_count", -1)) != 0 \
			or cells_by_zone_word.size() != 6 \
			or int(cells_by_zone_word[0].get("cell_count", -1)) != 177 \
			or int(cells_by_zone_word[1].get("cell_count", -1)) != 91 \
			or int(cells_by_zone_word[2].get("cell_count", -1)) != 226 \
			or int(cells_by_zone_word[3].get("cell_count", -1)) != 177 \
			or int(cells_by_zone_word[4].get("cell_count", -1)) != 207 \
			or int(cells_by_zone_word[5].get("cell_count", -1)) != 229 \
			or not bool(zone_boundary_span.get("materializes_boundary_trace", false)) \
			or not bool(zone_boundary_span.get("materializes_span_fill", false)) \
			or not bool(zone_boundary_span.get("materializes_private_zone_cell_buffer", false)) \
			or bool(zone_boundary_span.get("materializes_terrain", true)) \
			or bool(zone_boundary_span.get("materializes_map_cells", true)) \
			or bool(zone_boundary_span.get("materializes_public_output", true)):
		_fail("Strict h3maped boundary/span-fill port drifted: %s" % JSON.stringify(zone_boundary_span))
		return

	var zone_finalizer: Dictionary = report.get("zone_footprint_finalizer", {})
	var finalizer_steps: Array = zone_finalizer.get("phases", [])
	if String(zone_finalizer.get("status", "")) != "active_strict_executable_port" \
			or String(zone_finalizer.get("h3maped_status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported" \
			or String(zone_finalizer.get("source_range", "")) != "0x4a3710/0x4a3efc/0x4a3f05/0x4cca55/0x49b61b/0x4a3554" \
			or String(zone_finalizer.get("binary_byte_prefix_0x4a3710", "")) != "55 8b ec 83 ec 70 53 8b d9 83 65 ac 00 83 65 b0" \
			or String(zone_finalizer.get("binary_byte_prefix_0x4a3efc", "")) != "8d 45 90 8b ce 50 ff 75 d4 e8 06 f8 ff ff 83 4d" \
			or String(zone_finalizer.get("binary_byte_prefix_0x4a3f05", "")) != "e8 06 f8 ff ff 83 4d fc ff 8d 4d 90 e8 08 8a 02" \
			or String(zone_finalizer.get("binary_byte_prefix_0x4cca55", "")) != "55 8b ec 51 51 8b 01 53 56 57 8b 08 8b 50 04 39" \
			or String(zone_finalizer.get("binary_byte_prefix_0x49b61b", "")) != "55 8b ec 51 83 65 fc 00 56 57 8b 7d 08 8b f1 8d" \
			or String(zone_finalizer.get("binary_byte_prefix_0x4a3554", "")) != "b8 c0 a7 52 00 e8 72 2b 04 00 83 ec 40 8a 45 0b" \
			or int(zone_finalizer.get("level_count", -1)) != 1 \
			or int(zone_finalizer.get("h3maped_water_mode_code", -1)) != 0 \
			or bool(zone_finalizer.get("synthetic_branch_allowed_by_0x4a3a9d", true)) \
			or int(zone_finalizer.get("original_same_level_runtime_zone_count", -1)) != 6 \
			or int(zone_finalizer.get("final_runtime_zone_count", -1)) != 6 \
			or int(zone_finalizer.get("appended_runtime_zone_count", -1)) != 0 \
			or finalizer_steps.size() != 3 \
			or String(finalizer_steps[0].get("address_range", "")) != "0x4a3735..0x4a3874" \
			or String(finalizer_steps[0].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or int(finalizer_steps[0].get("materialized_adjacency_insert_count", -1)) != 0 \
			or String(finalizer_steps[1].get("address_range", "")) != "0x4a3879..0x4a38be" \
			or String(finalizer_steps[1].get("status", "")) != "0x49b61b_reset_and_0x4a3554_rebuild_scheduled" \
			or int(finalizer_steps[1].get("zone_order_reset_call_count", -1)) != 6 \
			or int(finalizer_steps[1].get("per_zone_order_helper_call_count", -1)) != 6 \
			or String(finalizer_steps[2].get("address_range", "")) != "0x4a38be..0x4a39fc" \
			or String(finalizer_steps[2].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or int(finalizer_steps[2].get("materialized_adjacency_insert_count", -1)) != 0 \
			or int(zone_finalizer.get("zone_order_reset_call_count", -1)) != 6 \
			or int(zone_finalizer.get("per_zone_order_helper_call_count", -1)) != 6 \
			or int(zone_finalizer.get("materialized_adjacency_count", -1)) != 0 \
			or bool(zone_finalizer.get("materializes_adjacency", true)) \
			or bool(zone_finalizer.get("materializes_terrain", true)) \
			or bool(zone_finalizer.get("materializes_map_cells", true)) \
			or bool(zone_finalizer.get("materializes_runtime_players", true)) \
			or bool(zone_finalizer.get("materializes_public_output", true)) \
			or String(zone_finalizer.get("blocked_next", "")) != "runtime_terrain_selection_0x49b53d":
		_fail("Strict h3maped footprint finalizer port drifted: %s" % JSON.stringify(zone_finalizer))
		return

	var runtime_terrain: Dictionary = report.get("runtime_terrain_selection", {})
	var terrain_selections: Array = runtime_terrain.get("selections", [])
	if String(runtime_terrain.get("phase_id", "")) != "runtime_terrain_selection" \
			or String(runtime_terrain.get("status", "")) != "active_strict_executable_port" \
			or String(runtime_terrain.get("h3maped_anchor", "")) != "0x49b53d" \
			or String(runtime_terrain.get("source_range", "")) != "0x49b53d/0x49b54c/0x49b586/0x49b5b7/0x540908" \
			or String(runtime_terrain.get("binary_byte_prefix_0x49b53d", "")) != "56 8b f1 57 8b 06 80 b8 84 00 00 00 00 74 11 8b" \
			or String(runtime_terrain.get("town_to_terrain_table_address", "")) != "0x540908" \
			or String(runtime_terrain.get("allowed_terrain_flags_source", "")) != "source_zone+0x85..0x8c" \
			or int(runtime_terrain.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or Array(runtime_terrain.get("town_choice_to_terrain_table", [])) != [2, 2, 3, 7, 0, 0, 5, 4, 2] \
			or int(runtime_terrain.get("selection_count", -1)) != 6 \
			or Array(runtime_terrain.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(runtime_terrain.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(runtime_terrain.get("match_to_town_count", -1)) != 4 \
			or int(runtime_terrain.get("allowed_flag_choice_count", -1)) != 2 \
			or int(runtime_terrain.get("blank_allowed_mask_count", -1)) != 0 \
			or int(runtime_terrain.get("forced_subterranean_count", -1)) != 0 \
			or int(runtime_terrain.get("terrain_rng_call_count", -1)) != 2 \
			or int(runtime_terrain.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160 \
			or not bool(runtime_terrain.get("materializes_runtime_zone_terrain_ids", false)) \
			or bool(runtime_terrain.get("materializes_terrain_cells", true)) \
			or bool(runtime_terrain.get("materializes_terrain_art", true)) \
			or bool(runtime_terrain.get("materializes_map_cells", true)) \
			or bool(runtime_terrain.get("materializes_runtime_players", true)) \
			or bool(runtime_terrain.get("materializes_package_tiles", true)) \
			or bool(runtime_terrain.get("materializes_public_output", true)) \
			or bool(runtime_terrain.get("public_package_output_allowed", true)) \
			or String(runtime_terrain.get("blocked_next", "")) != "terrain_cell_writeout_0x4a3f27" \
			or terrain_selections.size() != 6:
		_fail("Strict h3maped runtime terrain selection port drifted: %s" % JSON.stringify(runtime_terrain))
		return
	if String(terrain_selections[0].get("faction_id", "")) != "elemental" \
			or int(terrain_selections[0].get("town_choice_index", -1)) != 8 \
			or int(terrain_selections[0].get("selected_h3maped_terrain_id", -1)) != 2 \
			or String(terrain_selections[0].get("source", "")) != "0x49b54c_0x49b55b_match_to_town_table_0x540908" \
			or int(terrain_selections[2].get("rng_value", -1)) != 153 \
			or int(terrain_selections[2].get("selected_allowed_ordinal", -1)) != 6 \
			or int(terrain_selections[2].get("selected_h3maped_terrain_id", -1)) != 7 \
			or String(terrain_selections[4].get("faction_id", "")) != "fortress" \
			or int(terrain_selections[5].get("rng_value", -1)) != 292 \
			or int(terrain_selections[5].get("selected_h3maped_terrain_id", -1)) != 5:
		_fail("Strict h3maped runtime terrain selections drifted: %s" % JSON.stringify(terrain_selections))
		return

	var terrain_cell: Dictionary = report.get("terrain_cell_writeout", {})
	var owner_low_counts: Array = terrain_cell.get("owner_low_byte_counts", [])
	var terrain_code_counts: Array = terrain_cell.get("terrain_code_counts", [])
	var terrain_project_counts: Dictionary = terrain_cell.get("terrain_project_counts", {})
	if String(terrain_cell.get("phase_id", "")) != "terrain_cell_writeout" \
			or String(terrain_cell.get("status", "")) != "active_strict_executable_port" \
			or String(terrain_cell.get("h3maped_anchor", "")) != "0x4a3f27" \
			or String(terrain_cell.get("source_range", "")) != "0x4a3f27/0x4a4025/0x4a4082/0x4a415a" \
			or String(terrain_cell.get("binary_byte_prefix_0x4a3f27", "")) != "b8 1c a8 52 00 e8 9f 21 04 00 83 ec 5c 53 56 57" \
			or String(terrain_cell.get("binary_byte_prefix_0x4a4025", "")) != "8d 43 0c 6a 04 6a 08 50 8d 4d e8 e8 c0 8f 01 00" \
			or String(terrain_cell.get("binary_byte_prefix_0x4a4082", "")) != "8b 83 e4 10 00 00 85 c0 0f 84 15 01 00 00 8b 8b" \
			or String(terrain_cell.get("binary_byte_prefix_0x4a415a", "")) != "56 56 57 8d 4d e0 ff 75 d4 e8 31 8f 01 00 ff 45" \
			or String(terrain_cell.get("full_map_water_prefill_anchor", "")) != "0x4a4025" \
			or String(terrain_cell.get("runtime_zone_scan_anchor", "")) != "0x4a4082" \
			or String(terrain_cell.get("per_cell_repaint_anchor", "")) != "0x4a415a" \
			or Array(terrain_cell.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(terrain_cell.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(terrain_cell.get("terrain_rng_call_count", -1)) != 2 \
			or int(terrain_cell.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or int(terrain_cell.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160 \
			or int(terrain_cell.get("tile_count", -1)) != 1296 \
			or int(terrain_cell.get("full_map_water_prefill_cell_count", -1)) != 1296 \
			or int(terrain_cell.get("private_zone_word_cell_count", -1)) != 1296 \
			or int(terrain_cell.get("assigned_owner_cell_count", -1)) != 1107 \
			or int(terrain_cell.get("zone_repaint_cell_count", -1)) != 1107 \
			or int(terrain_cell.get("unassigned_water_cell_count", -1)) != 189 \
			or int(terrain_cell.get("reserved_cell_count", -1)) != 1107 \
			or int(terrain_cell.get("span_fill_boundary_or_filled_cell_count", -1)) != 1107 \
			or owner_low_counts.size() != 6 \
			or int(owner_low_counts[0].get("cell_count", -1)) != 177 \
			or int(owner_low_counts[1].get("cell_count", -1)) != 91 \
			or int(owner_low_counts[2].get("cell_count", -1)) != 226 \
			or int(owner_low_counts[3].get("cell_count", -1)) != 177 \
			or int(owner_low_counts[4].get("cell_count", -1)) != 207 \
			or int(owner_low_counts[5].get("cell_count", -1)) != 229 \
			or terrain_code_counts.size() != 6 \
			or int(terrain_code_counts[0].get("h3maped_terrain_id", -1)) != 0 \
			or int(terrain_code_counts[0].get("cell_count", -1)) != 91 \
			or int(terrain_code_counts[1].get("h3maped_terrain_id", -1)) != 2 \
			or int(terrain_code_counts[1].get("cell_count", -1)) != 177 \
			or int(terrain_code_counts[2].get("h3maped_terrain_id", -1)) != 4 \
			or int(terrain_code_counts[2].get("cell_count", -1)) != 207 \
			or int(terrain_code_counts[3].get("h3maped_terrain_id", -1)) != 5 \
			or int(terrain_code_counts[3].get("cell_count", -1)) != 229 \
			or int(terrain_code_counts[4].get("h3maped_terrain_id", -1)) != 7 \
			or int(terrain_code_counts[4].get("cell_count", -1)) != 403 \
			or int(terrain_code_counts[5].get("h3maped_terrain_id", -1)) != 8 \
			or int(terrain_code_counts[5].get("cell_count", -1)) != 189 \
			or int(terrain_project_counts.get("water", -1)) != 189 \
			or int(terrain_project_counts.get("grass", -1)) != 177 \
			or int(terrain_project_counts.get("dirt", -1)) != 91 \
			or int(terrain_project_counts.get("lava", -1)) != 403 \
			or int(terrain_project_counts.get("swamp", -1)) != 207 \
			or int(terrain_project_counts.get("rough", -1)) != 229 \
			or not bool(terrain_cell.get("materializes_private_terrain_cell_buffer", false)) \
			or bool(terrain_cell.get("materializes_terrain_art", true)) \
			or bool(terrain_cell.get("materializes_roads", true)) \
			or bool(terrain_cell.get("materializes_objects", true)) \
			or bool(terrain_cell.get("materializes_map_cells", true)) \
			or bool(terrain_cell.get("materializes_runtime_players", true)) \
			or bool(terrain_cell.get("materializes_package_tiles", true)) \
			or bool(terrain_cell.get("materializes_public_output", true)) \
			or bool(terrain_cell.get("public_package_output_allowed", true)) \
			or String(terrain_cell.get("blocked_next", "")) != "terrainplacement_visual_tables_0x4bcff5":
		_fail("Strict h3maped terrain cell writeout port drifted: %s" % JSON.stringify(terrain_cell))
		return

	var terrainplacement_visual: Dictionary = report.get("terrainplacement_visual_tables", {})
	var visual_tables: Array = terrainplacement_visual.get("tables", [])
	var toolkit_records: Array = terrainplacement_visual.get("toolkit_constructor_records", [])
	var visual_samples: Array = terrainplacement_visual.get("visual_row_selection_samples", [])
	var scratch_samples: Array = terrainplacement_visual.get("scratch_write_samples", [])
	if String(terrainplacement_visual.get("phase_id", "")) != "terrainplacement_visual_tables" \
			or String(terrainplacement_visual.get("status", "")) != "active_strict_executable_port" \
			or String(terrainplacement_visual.get("h3maped_anchor", "")) != "0x4bcff5" \
			or String(terrainplacement_visual.get("source_range", "")) != "0x4bcff5/0x4bb5ce/0x4bd099/0x4bb74b/0x4bc5f0/0x4bcfc3/0x4bce6d/0x543108/0x543380/0x5434f0/0x5435b0/0x542f88" \
			or String(terrainplacement_visual.get("binary_byte_prefix_0x4bcff5", "")) != "b8 8a ba 52 00 e8 d1 90 02 00 83 ec 28 56 8b f1" \
			or String(terrainplacement_visual.get("binary_byte_prefix_0x4bb74b", "")) != "55 8b ec 83 ec 28 53 56 8b f1 57 8b 7d 08 ff 76" \
			or String(terrainplacement_visual.get("binary_byte_prefix_0x4bc5f0", "")) != "55 8b ec 83 ec 10 53 56 57 8b f1 33 db 39 5e 20" \
			or String(terrainplacement_visual.get("binary_byte_prefix_0x4bcfc3", "")) != "56 8b 74 24 0c 56 ff 74 24 0c e8 9b fe ff ff 8b" \
			or String(terrainplacement_visual.get("binary_byte_prefix_0x4bce6d", "")) != "55 8b ec 83 ec 0c 53 56 57 8b 75 08 8b f9 8b 47" \
			or int(terrainplacement_visual.get("visual_table_count", -1)) != 5 \
			or int(terrainplacement_visual.get("total_visual_row_count", -1)) != 230 \
			or int(terrainplacement_visual.get("expected_total_row_count", -1)) != 230 \
			or int(terrainplacement_visual.get("toolkit_constructor_record_count", -1)) != 10 \
			or int(terrainplacement_visual.get("visual_row_selection_sample_count", -1)) != 4 \
			or int(terrainplacement_visual.get("scratch_write_sample_count", -1)) != 4 \
			or bool(terrainplacement_visual.get("terrain_art_hash_fallback_allowed", true)) \
			or bool(terrainplacement_visual.get("materializes_visual_record", true)) \
			or bool(terrainplacement_visual.get("materializes_visual_records", true)) \
			or bool(terrainplacement_visual.get("materializes_full_terrain_art_grid", true)) \
			or bool(terrainplacement_visual.get("materializes_package_tiles", true)) \
			or bool(terrainplacement_visual.get("materializes_public_output", true)) \
			or bool(terrainplacement_visual.get("public_package_output_allowed", true)) \
			or String(terrainplacement_visual.get("blocked_next", "")) != "terrainplacement_live_feedback_0x4bb74b_0x4bc5f0":
		_fail("Strict TerrainPlacement visual-table port drifted: %s" % JSON.stringify(terrainplacement_visual))
		return
	if visual_tables.size() != 5 \
			or String(visual_tables[0].get("table_address", "")) != "0x543108" \
			or int(visual_tables[0].get("expected_row_count", -1)) != 79 \
			or int(visual_tables[0].get("decoded_row_count", -1)) != 79 \
			or String(visual_tables[1].get("table_address", "")) != "0x543380" \
			or int(visual_tables[1].get("decoded_row_count", -1)) != 46 \
			or String(visual_tables[2].get("table_address", "")) != "0x5434f0" \
			or int(visual_tables[2].get("decoded_row_count", -1)) != 24 \
			or String(visual_tables[3].get("table_address", "")) != "0x5435b0" \
			or int(visual_tables[3].get("decoded_row_count", -1)) != 33 \
			or String(visual_tables[4].get("table_address", "")) != "0x542f88" \
			or int(visual_tables[4].get("decoded_row_count", -1)) != 48:
		_fail("TerrainPlacement visual table decode rows drifted: %s" % JSON.stringify(visual_tables))
		return
	if toolkit_records.size() != 10 \
			or String(toolkit_records[0].get("object_address", "")) != "0x5a4130" \
			or String(toolkit_records[0].get("constructor_address", "")) != "0x4ba868" \
			or int(toolkit_records[0].get("terrain_id", -1)) != 0 \
			or String(toolkit_records[0].get("table_address", "")) != "0x543380" \
			or String(toolkit_records[9].get("object_address", "")) != "0x5a4128" \
			or String(toolkit_records[9].get("constructor_address", "")) != "0x4baa66" \
			or int(toolkit_records[9].get("terrain_id", -1)) != 9 \
			or String(toolkit_records[9].get("table_address", "")) != "none":
		_fail("TerrainPlacement toolkit constructor records drifted: %s" % JSON.stringify(toolkit_records))
		return
	if visual_samples.size() != 4 \
			or int(visual_samples[0].get("selected_row", -1)) != 60 \
			or int(visual_samples[1].get("selected_row", -1)) != 77 \
			or int(visual_samples[2].get("selected_row", -1)) != 20 \
			or int(visual_samples[3].get("selected_row", -1)) != 11 \
			or not bool(visual_samples[0].get("selected_special_bucket", false)) \
			or int(visual_samples[0].get("probability_rng_value", -1)) != 41 \
			or int(visual_samples[0].get("art_rng_value", -1)) != 18467:
		_fail("TerrainPlacement visual selector samples drifted: %s" % JSON.stringify(visual_samples))
		return
	if scratch_samples.size() != 4 \
			or int(scratch_samples[0].get("scratch_word_u16", -1)) != 1925 \
			or int(scratch_samples[1].get("scratch_word_u16", -1)) != 6565 \
			or int(scratch_samples[2].get("scratch_word_u16", -1)) != 657 \
			or int(scratch_samples[3].get("scratch_word_u16", -1)) != 371 \
			or int(scratch_samples[0].get("generated_cell_word_0x24_u32", -1)) != 3842 \
			or int(scratch_samples[1].get("generated_cell_word_0x24_u32", -1)) != 4930 \
			or int(scratch_samples[2].get("generated_cell_word_0x24_u32", -1)) != 1288 \
			or int(scratch_samples[3].get("generated_cell_word_0x24_u32", -1)) != 713 \
			or int(scratch_samples[1].get("generated_cell_word_0x28_u32", -1)) != 32768:
		_fail("TerrainPlacement scratch/writeback samples drifted: %s" % JSON.stringify(scratch_samples))
		return

	var terrainplacement_live: Dictionary = report.get("terrainplacement_live_feedback", {})
	var live_samples: Array = terrainplacement_live.get("sample_records", [])
	var live_seed_samples: Array = terrainplacement_live.get("seed_samples", [])
	var live_drain_samples: Array = terrainplacement_live.get("drain_samples", [])
	var live_neighbor_histogram: Dictionary = terrainplacement_live.get("neighbor_mask_histogram", {})
	var live_selector_histogram: Dictionary = terrainplacement_live.get("selector_kind_histogram", {})
	if String(terrainplacement_live.get("phase_id", "")) != "terrainplacement_live_feedback" \
			or String(terrainplacement_live.get("status", "")) != "active_strict_executable_port" \
			or String(terrainplacement_live.get("h3maped_anchor", "")) != "0x4bb74b/0x4bc5f0" \
			or String(terrainplacement_live.get("source_range", "")) != "0x4a4025/0x4a4082/0x4a415a/0x4bb74b/0x4bba59/0x4bbd01/0x4bc5f0/0x4bc988/0x4bcfc3/0x4bce6d/0x4bad0f/0x49acf6" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bb74b", "")) != "55 8b ec 83 ec 28 53 56 8b f1 57 8b 7d 08 ff 76" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bba59", "")) != "55 8b ec 83 ec 18 53 56 57 8b 7d 08 6a 0f 8b f1" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bbd01", "")) != "55 8b ec 83 ec 64 53 8b 5d 08 56 8b f1 53 89 75" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bc5f0", "")) != "55 8b ec 83 ec 10 53 56 57 8b f1 33 db 39 5e 20" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bc988", "")) != "56 57 8b 7c 24 0c 8b f1 57 e8 7d f0 ff ff 84 c0" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bcfc3", "")) != "56 8b 74 24 0c 56 ff 74 24 0c e8 9b fe ff ff 8b" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bce6d", "")) != "55 8b ec 83 ec 0c 53 56 57 8b 75 08 8b f9 8b 47" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x4bad0f", "")) != "53 8b 5c 24 08 56 8b 74 24 10 57 8b f9 56 53 8b" \
			or String(terrainplacement_live.get("binary_byte_prefix_0x49acf6", "")) != "8b 41 24 8b 54 24 04 66 25 00 c0 83 e2 3f 33 c2" \
			or int(terrainplacement_live.get("tile_count", -1)) != 1296 \
			or int(terrainplacement_live.get("live_full_native_cell_count", -1)) != 1326 \
			or int(terrainplacement_live.get("live_initial_water_attempt_count", -1)) != 1296 \
			or int(terrainplacement_live.get("live_repaint_attempt_count", -1)) != 942 \
			or int(terrainplacement_live.get("live_queue_attempt_count", -1)) != 607 \
			or int(terrainplacement_live.get("live_visual_attempt_count", -1)) != 2845 \
			or int(terrainplacement_live.get("live_visual_write_count", -1)) != 2845 \
			or int(terrainplacement_live.get("live_visual_missing_bucket_count", -1)) != 0 \
			or int(terrainplacement_live.get("live_dirty_cell_count", -1)) != 1296 \
			or int(terrainplacement_live.get("changed_cell_update_count", -1)) != 1107 \
			or int(terrainplacement_live.get("post_queue_terrain_difference_count", -1)) != 181 \
			or int(terrainplacement_live.get("set_a_drain_count", -1)) != 176 \
			or int(terrainplacement_live.get("set_b_drain_count", -1)) != 10522 \
			or int(terrainplacement_live.get("set_b_candidate_true_count", -1)) != 386 \
			or int(terrainplacement_live.get("retouched_cell_write_count", -1)) != 221 \
			or int(terrainplacement_live.get("live_roundtrip_mismatch_count", -1)) != 0 \
			or int(terrainplacement_live.get("live_terrain_mismatch_count", -1)) != 0 \
			or int(terrainplacement_live.get("live_terrain_art_nonzero_cell_count", -1)) != 2785 \
			or int(terrainplacement_live.get("live_terrain_flag_cell_count", -1)) != 1255 \
			or int(terrainplacement_live.get("rng_state_after_live_visual_selection_uint32", -1)) != 1452413421 \
			or int(live_neighbor_histogram.get("0", -1)) != 183 \
			or int(live_neighbor_histogram.get("1", -1)) != 2066 \
			or int(live_neighbor_histogram.get("2", -1)) != 448 \
			or int(live_neighbor_histogram.get("4", -1)) != 148 \
			or int(live_selector_histogram.get("full_native_special_frequency_masked_by_0x4bce6d", -1)) != 1326 \
			or int(live_selector_histogram.get("transition_class_bucket", -1)) != 1519 \
			or live_samples.size() != 16 \
			or live_seed_samples.size() != 12 \
			or live_drain_samples.size() != 24 \
			or not bool(terrainplacement_live.get("visual_tables_decoded", false)) \
			or not bool(terrainplacement_live.get("uses_live_scratch_neighbor_mask", false)) \
			or not bool(terrainplacement_live.get("live_feedback_materialized", false)) \
			or not bool(terrainplacement_live.get("materializes_private_generated_cell_words", false)) \
			or not bool(terrainplacement_live.get("exact_queue_drain_complete", false)) \
			or bool(terrainplacement_live.get("drain_guard_exhausted", true)) \
			or bool(terrainplacement_live.get("materializes_package_tiles", true)) \
			or bool(terrainplacement_live.get("materializes_public_output", true)) \
			or bool(terrainplacement_live.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrainplacement_live.get("public_package_output_allowed", true)) \
			or String(terrainplacement_live.get("blocked_next", "")) != "terrain_tile_byte_writeback_0x49b2b6":
		_fail("Strict TerrainPlacement live-feedback port drifted: %s" % JSON.stringify(terrainplacement_live))
		return
	if int(live_samples[0].get("selected_row", -1)) != 25 \
			or int(live_samples[0].get("scratch_word_u16", -1)) != 817 \
			or int(live_samples[0].get("generated_cell_word_0x24_u32", -1)) != 1608 \
			or int(live_samples[0].get("terrain_id", -1)) != 8 \
			or int(live_samples[0].get("neighbor_mask", -1)) != 4 \
			or int(live_seed_samples[0].get("x", -1)) != 33 \
			or int(live_seed_samples[0].get("y", -1)) != 2 \
			or String(live_seed_samples[0].get("source_branch", "")) != "0x4bba59_north_south_cardinal" \
			or String(live_drain_samples[1].get("branch", "")) != "0x4bbd01_horizontal_left" \
			or int(live_drain_samples[1].get("target_x", -1)) != 32 \
			or int(live_drain_samples[1].get("target_y", -1)) != 0:
		_fail("TerrainPlacement live-feedback samples drifted: %s / %s / %s" % [JSON.stringify(live_samples), JSON.stringify(live_seed_samples), JSON.stringify(live_drain_samples)])
		return

	var terrain_tile_byte: Dictionary = report.get("terrain_tile_byte_writeback", {})
	var terrain_tile_histogram: Dictionary = terrain_tile_byte.get("tile_byte_0_histogram", {})
	var terrain_art_histogram: Dictionary = terrain_tile_byte.get("tile_byte_1_art_histogram", {})
	var terrain_flag_histogram: Dictionary = terrain_tile_byte.get("tile_byte_6_flag_histogram", {})
	var terrain_tile_samples: Array = terrain_tile_byte.get("sample_tile_byte_records", [])
	if String(terrain_tile_byte.get("phase_id", "")) != "terrain_tile_byte_writeback" \
			or String(terrain_tile_byte.get("status", "")) != "active_strict_executable_port" \
			or String(terrain_tile_byte.get("h3maped_anchor", "")) != "0x49b2b6" \
			or String(terrain_tile_byte.get("source_range", "")) != "0x49b2b6/0x49acf6" \
			or String(terrain_tile_byte.get("binary_byte_prefix_0x49b2b6", "")) != "55 8b ec 51 53 56 57 8b 75 08 8b f9 6a 01 5b 8d" \
			or String(terrain_tile_byte.get("binary_byte_prefix_0x49acf6", "")) != "8b 41 24 8b 54 24 04 66 25 00 c0 83 e2 3f 33 c2" \
			or int(terrain_tile_byte.get("tile_count", -1)) != 1296 \
			or int(terrain_tile_byte.get("terrain_byte_candidate_count", -1)) != 1296 \
			or int(terrain_tile_byte.get("terrain_byte_mismatch_count", -1)) != 0 \
			or int(terrain_tile_byte.get("terrain_art_nonzero_cell_count", -1)) != 1238 \
			or int(terrain_tile_byte.get("terrain_flag_nonzero_cell_count", -1)) != 1033 \
			or int(terrain_tile_byte.get("road_river_nonzero_byte_count", -1)) != 0 \
			or int(terrain_tile_histogram.get("0", -1)) != 97 \
			or int(terrain_tile_histogram.get("2", -1)) != 138 \
			or int(terrain_tile_histogram.get("4", -1)) != 262 \
			or int(terrain_tile_histogram.get("5", -1)) != 269 \
			or int(terrain_tile_histogram.get("7", -1)) != 444 \
			or int(terrain_tile_histogram.get("8", -1)) != 86 \
			or int(terrain_art_histogram.get("0", -1)) != 58 \
			or int(terrain_art_histogram.get("23", -1)) != 184 \
			or int(terrain_art_histogram.get("43", -1)) != 36 \
			or int(terrain_flag_histogram.get("0", -1)) != 263 \
			or int(terrain_flag_histogram.get("1", -1)) != 112 \
			or int(terrain_flag_histogram.get("2", -1)) != 150 \
			or int(terrain_flag_histogram.get("3", -1)) != 771 \
			or terrain_tile_samples.size() != 16 \
			or not bool(terrain_tile_byte.get("materializes_private_tile_byte_candidates", false)) \
			or bool(terrain_tile_byte.get("road_river_bytes_materialized", true)) \
			or bool(terrain_tile_byte.get("object_bytes_materialized", true)) \
			or bool(terrain_tile_byte.get("materializes_package_tiles", true)) \
			or bool(terrain_tile_byte.get("materializes_public_output", true)) \
			or bool(terrain_tile_byte.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrain_tile_byte.get("public_package_output_allowed", true)) \
			or String(terrain_tile_byte.get("blocked_next", "")) != "town_object_placement_0x4a8d2c_0x4a8db2_0x4a93a2":
		_fail("Strict terrain tile-byte writeback port drifted: %s" % JSON.stringify(terrain_tile_byte))
		return
	if int(terrain_tile_samples[0].get("generated_cell_word_0x24_u32", -1)) != 1477 \
			or int(terrain_tile_samples[0].get("generated_cell_word_0x28_u32", -1)) != 98304 \
			or int(terrain_tile_samples[0].get("tile_byte_0_terrain_id", -1)) != 5 \
			or int(terrain_tile_samples[0].get("tile_byte_1_terrain_art", -1)) != 23 \
			or int(terrain_tile_samples[0].get("tile_byte_6_terrain_flags", -1)) != 3 \
			or int(terrain_tile_samples[8].get("tile_byte_0_terrain_id", -1)) != 7 \
			or int(terrain_tile_samples[8].get("tile_byte_1_terrain_art", -1)) != 20:
		_fail("Terrain tile-byte writeback samples drifted: %s" % JSON.stringify(terrain_tile_samples))
		return

	var town_castle: Dictionary = report.get("town_castle_phase", {})
	var town_stamping: Dictionary = town_castle.get("direct_stamping_projection", {})
	var town_adoption: Dictionary = town_castle.get("project_town_adoption_candidate", {})
	var town_records: Array = town_adoption.get("town_records", [])
	var player_starts: Array = town_adoption.get("player_starts", [])
	var town_scheduled: Array = town_castle.get("scheduled_records", [])
	var town_skipped: Array = town_castle.get("skipped_records", [])
	var town_projection_records: Array = town_stamping.get("records", [])
	if String(town_castle.get("phase_id", "")) != "town_castle_phase" \
			or String(town_castle.get("status", "")) != "active_strict_executable_port" \
			or String(town_castle.get("h3maped_anchor", "")) != "0x4a8d2c/0x4a8db2/0x4a93a2" \
			or String(town_castle.get("source_range", "")) != "0x4a8d2c/0x4a8db2/0x4a93a2/0x49aa93/0x49a09c/0x49b3c1/0x49ba89" \
			or String(town_castle.get("binary_byte_prefix_0x4a8d2c", "")) != "55 8b ec 51 53 56 57 8b 7d 08 8b d9 8b 37 8b 47" \
			or String(town_castle.get("binary_byte_prefix_0x4a8db2", "")) != "55 8b ec 83 ec 48 8b 45 08 53 56 33 db 8b 30 8b" \
			or String(town_castle.get("binary_byte_prefix_0x4a93a2", "")) != "b8 72 aa 52 00 e8 24 cd 03 00 83 ec 48 83 7d 0c" \
			or String(town_castle.get("binary_byte_prefix_0x49aa93", "")) != "55 8b ec 51 51 89 4d fc 53 8b 4d 18 56 57 6a 00" \
			or String(town_castle.get("binary_byte_prefix_0x49a09c", "")) != "55 8b ec 51 51 8b 45 1c 80 65 ff 00 53 56 83 78" \
			or String(town_castle.get("binary_byte_prefix_0x49b3c1", "")) != "56 57 33 ff 8b f1 33 c0 80 7c 06 41 00 74 01 47" \
			or String(town_castle.get("binary_byte_prefix_0x49ba89", "")) != "8b 44 24 04 56 8b f1 c7 06 74 0a 54 00 89 46 04" \
			or int(town_castle.get("source_player_min_castle_count", -1)) != 4 \
			or int(town_castle.get("assigned_player_min_castle_count", -1)) != 3 \
			or int(town_castle.get("skipped_unassigned_player_start_min_castle_count", -1)) != 1 \
			or int(town_castle.get("scheduled_direct_minimum_object_count", -1)) != 3 \
			or int(town_castle.get("scheduled_owned_player_town_count", -1)) != 3 \
			or int(town_castle.get("project_town_record_candidate_count", -1)) != 3 \
			or int(town_castle.get("project_player_start_candidate_count", -1)) != 3 \
			or int(town_stamping.get("direct_candidate_scan_count", -1)) != 3 \
			or int(town_stamping.get("direct_candidate_total", -1)) != 445 \
			or int(town_stamping.get("direct_footprint_eligible_total", -1)) != 85 \
			or int(town_stamping.get("direct_footprint_marked_cell_count", -1)) != 39 \
			or int(town_stamping.get("direct_unique_selection_count", -1)) != 2 \
			or int(town_stamping.get("direct_random_tie_selection_count", -1)) != 1 \
			or int(town_stamping.get("direct_random_tie_rng_call_count", -1)) != 1 \
			or int(town_stamping.get("direct_record_projection_count", -1)) != 3 \
			or int(town_stamping.get("object_rng_state_before_0x4a93a2_uint32", -1)) != 2166683160 \
			or int(town_stamping.get("object_rng_state_after_0x4a93a2_uint32", -1)) != 811474043 \
			or int(town_adoption.get("town_record_count", -1)) != 3 \
			or int(town_adoption.get("player_start_count", -1)) != 3 \
			or int(town_adoption.get("synchronized_player_start_count", -1)) != 3 \
			or town_records.size() != 3 \
			or player_starts.size() != 3 \
			or town_scheduled.size() != 3 \
			or town_skipped.size() != 1 \
			or town_projection_records.size() != 3 \
			or not bool(town_castle.get("materializes_private_town_candidates", false)) \
			or bool(town_castle.get("materializes_town_objects", true)) \
			or bool(town_castle.get("materializes_package_tiles", true)) \
			or bool(town_castle.get("adopts_into_runtime_grid", true)) \
			or bool(town_castle.get("public_package_output_allowed", true)) \
			or String(town_castle.get("blocked_next", "")) != "object_vector_prerequisite_phase_4a9d6a_4aab7e":
		_fail("Strict town/castle phase port drifted: %s" % JSON.stringify(town_castle))
		return
	if int(town_records[0].get("owner_slot", -1)) != 1 \
			or String(town_records[0].get("owner", "")) != "player" \
			or int(town_records[0].get("x", -1)) != 26 \
			or int(town_records[0].get("y", -1)) != 16 \
			or int(player_starts[0].get("x", -2)) != int(town_records[0].get("x", -1)) \
			or int(player_starts[0].get("y", -2)) != int(town_records[0].get("y", -1)) \
			or int(town_records[1].get("owner_slot", -1)) != 2 \
			or int(town_records[1].get("x", -1)) != 23 \
			or int(town_records[1].get("y", -1)) != 23 \
			or int(player_starts[1].get("x", -2)) != int(town_records[1].get("x", -1)) \
			or int(player_starts[1].get("y", -2)) != int(town_records[1].get("y", -1)) \
			or int(town_records[2].get("owner_slot", -1)) != 3 \
			or int(town_records[2].get("x", -1)) != 18 \
			or int(town_records[2].get("y", -1)) != 5 \
			or int(player_starts[2].get("x", -2)) != int(town_records[2].get("x", -1)) \
			or int(player_starts[2].get("y", -2)) != int(town_records[2].get("y", -1)) \
			or int(town_projection_records[2].get("random_tie_rng_value", -1)) != 12382:
		_fail("Town/player-start synchronization drifted: %s / %s" % [JSON.stringify(town_records), JSON.stringify(player_starts)])
		return

	var strict_state: Dictionary = report.get("strict_restart_state", {})
	if String(strict_state.get("schema_id", "")) != "aurelion_h3maped_small_strict_executable_restart_state_v1" \
			or String(strict_state.get("status", "")) != "strict_executable_restart_scaffold_active" \
			or not bool(strict_state.get("binary_verified", false)) \
			or bool(strict_state.get("active_public_generation_state", true)) \
			or bool(strict_state.get("legacy_private_phase_ledgers_exposed", true)) \
			or not bool(strict_state.get("legacy_private_phase_ledgers_archived_only", false)) \
			or String(strict_state.get("next_required_port", "")) != "mines_rewards_and_object_vector_0x4a9d6a_0x4a9911_0x4aa354_0x4a9f1c_0x4aa9b7":
		_fail("Strict executable restart state drifted: %s" % JSON.stringify(strict_state))
		return

	var pending_ports: Array = strict_state.get("pending_strict_ports", [])
	if pending_ports.size() != 3 \
			or not pending_ports.has("mines_rewards_and_object_vector:0x4a9d6a_0x4a9911_0x4aa354_0x4a9f1c_0x4aa9b7") \
			or not pending_ports.has("roads_rivers_blockers_guards:0x4ab52a_0x4aae7b_0x4a79a3_0x4a61bc_0x4a696b_0x4a6cf2"):
		_fail("Strict restart pending executable ports changed: %s" % JSON.stringify(pending_ports))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 18 \
			or String(backlog[0].get("status", "")) != "active_strict_boundary" \
			or String(backlog[1].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[2].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[3].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[4].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[5].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[6].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[7].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[8].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[9].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[10].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[11].get("id", "")) != "terrainplacement_live_feedback" \
			or String(backlog[11].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[12].get("id", "")) != "terrain_tile_byte_writeback" \
			or String(backlog[12].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[13].get("id", "")) != "town_object_placement" \
			or String(backlog[13].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[14].get("status", "")) != "pending_strict_executable_port" \
			or String(backlog[15].get("status", "")) != "pending_runtime_port" \
			or String(backlog[16].get("status", "")) != "pending_runtime_port" \
			or String(backlog[17].get("status", "")) != "pending_runtime_port":
		_fail("Strict phase backlog drifted: %s" % JSON.stringify(backlog))
		return

	var generated: Dictionary = service.generate_random_map(supported_config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or bool(generated.get("runtime_generation_allowed", true)) \
			or generated.has("active_generation_state"):
		_fail("Supported small map generation bypassed the reset gate: %s" % JSON.stringify(generated))
		return

	var explicit_config := supported_config.duplicate(true)
	explicit_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_result: Dictionary = service.generate_random_map(explicit_config)
	if bool(explicit_result.get("ok", true)) \
			or String(explicit_result.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Explicit translated-template request bypassed the reset gate: %s" % JSON.stringify(explicit_result))
		return

	var out_of_scope_config := supported_config.duplicate(true)
	out_of_scope_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var out_of_scope: Dictionary = service.generate_random_map(out_of_scope_config)
	if bool(out_of_scope.get("ok", true)) \
			or String(out_of_scope.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope map did not stay on the archived-native disabled gate: %s" % JSON.stringify(out_of_scope))
		return

	print("%s: ok" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
