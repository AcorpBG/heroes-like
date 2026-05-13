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

	var strict_state: Dictionary = report.get("strict_restart_state", {})
	if String(strict_state.get("schema_id", "")) != "aurelion_h3maped_small_strict_executable_restart_state_v1" \
			or String(strict_state.get("status", "")) != "strict_executable_restart_scaffold_active" \
			or not bool(strict_state.get("binary_verified", false)) \
			or bool(strict_state.get("active_public_generation_state", true)) \
			or bool(strict_state.get("legacy_private_phase_ledgers_exposed", true)) \
			or not bool(strict_state.get("legacy_private_phase_ledgers_archived_only", false)) \
			or String(strict_state.get("next_required_port", "")) != "runtime_terrain_selection_0x49b53d":
		_fail("Strict executable restart state drifted: %s" % JSON.stringify(strict_state))
		return

	var pending_ports: Array = strict_state.get("pending_strict_ports", [])
	if pending_ports.size() != 6 \
			or not pending_ports.has("runtime_terrain_selection:0x49b53d") \
			or not pending_ports.has("roads_rivers_blockers_guards:0x4ab52a_0x4aae7b_0x4a79a3_0x4a61bc_0x4a696b_0x4a6cf2"):
		_fail("Strict restart pending executable ports changed: %s" % JSON.stringify(pending_ports))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 14 \
			or String(backlog[0].get("status", "")) != "active_strict_boundary" \
			or String(backlog[1].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[2].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[3].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[4].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[5].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[6].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[7].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[8].get("status", "")) != "pending_strict_executable_port" \
			or String(backlog[10].get("status", "")) != "pending_strict_executable_port" \
			or String(backlog[11].get("status", "")) != "pending_runtime_port":
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
