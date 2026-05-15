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
			or not bool(metadata.get("native_rmg_runtime_generation_allowed", false)) \
			or String(metadata.get("native_rmg_runtime_generation_policy", "")) != "small_36x36_land_validator_gated_only" \
			or not bool(metadata.get("native_rmg_production_ready", false)) \
			or String(metadata.get("native_rmg_production_ready_scope", "")) != "strict_small_36x36_one_level_land_only":
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
			or String(selection.get("template_semantic_source", "")) != "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json" \
			or bool(selection.get("project_template_bridge_enabled", true)) \
			or String(selection.get("rng_function_address", "")) != "0x4e7276" \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or int(selection.get("source_catalog_index", -1)) != 18 \
			or String(selection.get("adapted_template_id", "")) != "":
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
			or String(runtime_records[2].get("terrain_policy", "")) != "original_h3maped_allowed_terrains" \
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
			or int(terrainplacement_live.get("live_cell_word_0x20_owner_byte_materialized_count", -1)) != 1107 \
			or int(terrainplacement_live.get("live_cell_word_0x20_unassigned_sentinel_count", -1)) != 189 \
			or String(terrainplacement_live.get("live_cell_word_0x20_owner_byte_source", "")) != "0x4a325d writes source/runtime owner into cell+0x20 bits16..23 while preserving constructor sentinel 0xffff7fbc for unassigned cells" \
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
			or int(town_stamping.get("direct_footprint_eligible_total", -1)) != 291 \
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
			or int(town_records[0].get("x", -1)) != 23 \
			or int(town_records[0].get("y", -1)) != 11 \
			or int(player_starts[0].get("x", -2)) != int(town_records[0].get("x", -1)) \
			or int(player_starts[0].get("y", -2)) != int(town_records[0].get("y", -1)) \
			or int(town_records[1].get("owner_slot", -1)) != 2 \
			or int(town_records[1].get("x", -1)) != 21 \
			or int(town_records[1].get("y", -1)) != 22 \
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

	var object_vector: Dictionary = report.get("mines_rewards_and_object_vector", {})
	var mine_boundary: Dictionary = object_vector.get("mine_requirements_boundary", {})
	var reward_boundary: Dictionary = object_vector.get("reward_scheduler_boundary", {})
	var selector_boundary: Dictionary = object_vector.get("candidate_selector_boundary", {})
	var vector_boundary: Dictionary = object_vector.get("candidate_vector_order_boundary", {})
	var monster_boundary: Dictionary = object_vector.get("single_level_monster_candidate_boundary", {})
	if String(object_vector.get("phase_id", "")) != "mines_rewards_and_object_vector" \
			or String(object_vector.get("status", "")) != "active_strict_executable_port" \
			or String(object_vector.get("h3maped_anchor", "")) != "0x4a9d6a/0x4a9911/0x4a9641/0x4a9c7c/0x4aab7e/0x4aa354/0x4a9f1c/0x4aa9b7/0x4aa603/0x4aa3e9" \
			or String(object_vector.get("source_range", "")) != "0x4a9d6a/0x4a9911/0x4a9641/0x4a9c7c/0x4aab7e/0x4aa354/0x4a9f1c/0x4aa9b7/0x4aa603/0x4aa3e9/0x49f95a" \
			or String(object_vector.get("binary_byte_prefix_0x4a9d6a", "")) != "55 8b ec 83 ec 14 83 65 ec 00 53 56 57 8b f9 8b" \
			or String(object_vector.get("binary_byte_prefix_0x4a9911", "")) != "b8 ac aa 52 00 e8 b5 c7 03 00 83 ec 40 8a 45 0f" \
			or String(object_vector.get("binary_byte_prefix_0x4a9641", "")) != "b8 84 aa 52 00 e8 85 ca 03 00 83 ec 58 8b 45 08" \
			or String(object_vector.get("binary_byte_prefix_0x4a9c7c", "")) != "55 8b ec 83 ec 4c 8b 45 08 53 56 57 8b 00 89 4d" \
			or String(object_vector.get("binary_byte_prefix_0x4aab7e", "")) != "b8 07 ab 52 00 e8 48 b5 03 00 81 ec 90 00 00 00" \
			or String(object_vector.get("binary_byte_prefix_0x4aa354", "")) != "55 8b ec 53 8b 5d 0c 56 57 8b f9 8b cb e8 fe 2a" \
			or String(object_vector.get("binary_byte_prefix_0x4a9f1c", "")) != "b8 dc aa 52 00 e8 aa c1 03 00 83 ec 3c 53 56 57" \
			or String(object_vector.get("binary_byte_prefix_0x4aa9b7", "")) != "b8 f0 aa 52 00 e8 0f b7 03 00 83 ec 44 89 4d f0" \
			or String(object_vector.get("binary_byte_prefix_0x4aa603", "")) != "55 8b ec 83 ec 48 53 8b 5d 08 56 57 8d 73 18 8d" \
			or String(object_vector.get("binary_byte_prefix_0x4aa3e9", "")) != "55 8b ec 83 ec 3c 53 8b 5d 08 56 57 8d 7b 54 8d" \
			or String(object_vector.get("binary_byte_prefix_0x49f95a", "")) != "55 8b ec 83 ec 3c 53 56 57 6a 14 5f 89 4d f0 57" \
			or not bool(object_vector.get("grid_available", false)) \
			or not bool(object_vector.get("materializes_private_object_vector_prerequisites", false)) \
			or not bool(object_vector.get("materializes_private_mine_records", false)) \
			or not bool(object_vector.get("materializes_private_reward_coordinate_records", false)) \
			or bool(object_vector.get("materializes_public_objects", true)) \
			or bool(object_vector.get("adopts_into_runtime_grid", true)) \
			or bool(object_vector.get("public_package_output_allowed", true)) \
			or int(object_vector.get("materialized_private_mine_coordinate_record_count", -1)) != 17 \
			or int(object_vector.get("materialized_private_reward_coordinate_record_count", -1)) != 3 \
			or int(object_vector.get("partial_coordinate_record_count", -1)) != 23 \
			or int(object_vector.get("candidate_vector_single_level_total_count", -1)) != 704 \
			or int(object_vector.get("candidate_vector_materialized_static_subset_count", -1)) != 110 \
			or int(object_vector.get("candidate_vector_materialized_monster_count", -1)) != 118 \
			or int(object_vector.get("candidate_vector_type10_count", -1)) != 40 \
			or int(object_vector.get("candidate_vector_type17_count", -1)) != 58 \
			or int(object_vector.get("candidate_vector_type53_count", -1)) != 378 \
			or int(object_vector.get("selector_global_limit_override_count", -1)) != 30 \
			or int(object_vector.get("selector_per_zone_limit_override_count", -1)) != 24 \
			or int(object_vector.get("reward_scheduler_preview_attempt_count", -1)) != 18 \
			or int(object_vector.get("reward_value_preview_rng_call_count", -1)) != 18 \
			or int(object_vector.get("reward_scheduler_budget_argument_total", -1)) != 300 \
			or int(object_vector.get("reward_object_lookup_count", -1)) != 18 \
			or int(object_vector.get("reward_object_lookup_selected_count", -1)) != 10 \
			or int(object_vector.get("reward_object_lookup_rng_call_count", -1)) != 10 \
			or int(object_vector.get("reward_candidate_scan_count", -1)) != 18 \
			or int(object_vector.get("reward_candidate_scan_eligible_total", -1)) != 46 \
			or int(object_vector.get("reward_candidate_scan_weight_total", -1)) != 17130 \
			or int(object_vector.get("reward_candidate_scan_rejected_template_total", -1)) != 104 \
			or int(object_vector.get("reward_coordinate_scan_call_count", -1)) != 10 \
			or int(object_vector.get("reward_coordinate_scan_candidate_total", -1)) != 156 \
			or int(object_vector.get("reward_coordinate_rng_call_count", -1)) != 3 \
			or int(object_vector.get("reward_generated_cell_mutated_body_count", -1)) != 4 \
			or int(object_vector.get("reward_generated_cell_mutated_action_count", -1)) != 3 \
			or int(object_vector.get("reward_generated_cell_score_depletion_call_count", -1)) != 3 \
			or int(object_vector.get("reward_generated_cell_score_depletion_mutated_cell_count", -1)) != 3151 \
			or not bool(object_vector.get("reward_coordinate_commit_materialized", false)) \
			or int(object_vector.get("project_object_adoption_candidate_count", -1)) != 0 \
			or String(object_vector.get("blocked_next", "")) != "roads_rivers_blockers_guards_0x4ab52a_0x4aae7b_0x4a79a3_0x4a61bc_0x4a696b_0x4a6cf2":
		_fail("Strict mines/rewards/object-vector phase port drifted: %s" % JSON.stringify(object_vector))
		return
	if int(mine_boundary.get("total_minimum_mine_count", -1)) != 18 \
			or int(mine_boundary.get("total_density_weight", -1)) != 18 \
			or int(mine_boundary.get("mine_template_row_count", -1)) != 46 \
			or int(mine_boundary.get("mine_template_selection_rng_call_count", -1)) != 18 \
			or int(mine_boundary.get("mine_placement_rng_call_count", -1)) != 17 \
			or int(mine_boundary.get("mine_placement_scan_call_count", -1)) != 18 \
			or int(mine_boundary.get("mine_placement_candidate_total", -1)) != 1132 \
			or int(mine_boundary.get("mine_placement_selected_count", -1)) != 17 \
			or int(mine_boundary.get("mine_placement_rejected_owner_count", -1)) != 2795 \
			or int(mine_boundary.get("mine_placement_rejected_49aa93_count", -1)) != 2420 \
			or int(mine_boundary.get("mine_placement_rejected_special_distance_count", -1)) != 27 \
			or int(mine_boundary.get("mine_placement_marked_body_cell_count", -1)) != 78 \
			or int(mine_boundary.get("object_rng_state_before_0x4a9911_uint32", -1)) != 811474043 \
			or int(mine_boundary.get("object_rng_state_after_0x4a9911_0x4a9641_uint32", -1)) != 2954628476 \
			or int(reward_boundary.get("total_treasure_band_count", -1)) != 18 \
			or int(reward_boundary.get("eligible_reward_band_count", -1)) != 18 \
			or int(reward_boundary.get("eligible_reward_density_sum", -1)) != 96 \
			or int(reward_boundary.get("budget_base", -1)) != 800 \
			or int(reward_boundary.get("scheduler_zone_count", -1)) != 6 \
			or int(reward_boundary.get("scheduler_total_density_sum", -1)) != 96 \
			or int(reward_boundary.get("preview_rng_state_before_0x4aa354_uint32", -1)) != 2954628476 \
			or int(reward_boundary.get("preview_rng_state_after_0x4aa354_uint32", -1)) != 2125947405 \
			or int(reward_boundary.get("private_generated_cell_word_0x20_owned_cell_count", -1)) != 1107 \
			or int(reward_boundary.get("coordinate_scan_owner_match_total", -1)) != 1624 \
			or int(reward_boundary.get("coordinate_scan_rejected_owner_count", -1)) != 11336 \
			or int(reward_boundary.get("coordinate_scan_rejected_score_count", -1)) != 1124 \
			or int(reward_boundary.get("coordinate_scan_rejected_filter_count", -1)) != 344 \
			or int(reward_boundary.get("coordinate_selected_count", -1)) != 3 \
			or String(selector_boundary.get("status", "")) != "selector_scan_weighted_choice_materialized_coordinate_commit_boundary_materialized_private_record_pending" \
			or int(selector_boundary.get("global_limit_override_count", -1)) != 30 \
			or int(selector_boundary.get("per_zone_limit_override_count", -1)) != 24 \
			or int(vector_boundary.get("single_level_total_candidate_record_count", -1)) != 704 \
			or Array(vector_boundary.get("segments", [])).size() != 9 \
			or String(monster_boundary.get("load_status", "")) != "loaded" \
			or int(monster_boundary.get("candidate_record_count", -1)) != 118:
		_fail("Mines/rewards/object-vector nested boundaries drifted: %s / %s" % [JSON.stringify(mine_boundary), JSON.stringify(reward_boundary)])
		return

	var roads_rivers: Dictionary = report.get("roads_and_rivers", {})
	var road_coordinate_records: Array = roads_rivers.get("generator_coordinate_records", [])
	var road_pair_records: Array = roads_rivers.get("pair_candidate_records", [])
	var road_final_art: Dictionary = roads_rivers.get("road_final_art_materialization", {})
	var road_serialization: Dictionary = roads_rivers.get("road_overlay_serialization", {})
	var road_type_bytes: PackedInt32Array = road_serialization.get("tile_byte_4_road_type_u8", PackedInt32Array())
	var road_art_bytes: PackedInt32Array = road_serialization.get("tile_byte_5_road_art_u8", PackedInt32Array())
	var road_flag_bytes: PackedInt32Array = road_serialization.get("tile_byte_6_road_flags_u8", PackedInt32Array())
	if String(roads_rivers.get("phase_id", "")) != "roads_and_rivers" \
			or String(roads_rivers.get("status", "")) != "active_strict_private_road_overlay" \
			or String(roads_rivers.get("h3maped_anchor", "")) != "0x4ab52a/0x4aae2f/0x4aae7b/0x4ab37f/0x4b4243" \
			or String(roads_rivers.get("source_range", "")) != "0x4ab52a/0x4aae2f/0x4aae7b/0x4ab37f/0x4b4243" \
			or String(roads_rivers.get("binary_byte_prefix_0x4ab52a", "")) != "55 8b ec 83 ec 2c 53 56 57 8b d9 e8 3c bd 03" \
			or String(roads_rivers.get("binary_byte_prefix_0x4aae7b", "")) != "b8 47 ab 52 00 e8 4b b2 03 00 83 ec 7c 8a 45 13" \
			or String(roads_rivers.get("binary_byte_prefix_0x4ab37f", "")) != "b8 6c ab 52 00 e8 47 ad 03 00 83 ec 64 80 65 f3" \
			or String(roads_rivers.get("binary_byte_prefix_0x4b4243", "")) != "b8 24 b3 52 00 e8 83 1e 03 00 83 ec 0c 56 57 8b" \
			or String(roads_rivers.get("coordinate_vector_begin_offset", "")) != "generator+0x14b0" \
			or String(roads_rivers.get("coordinate_vector_end_offset", "")) != "generator+0x14b4" \
			or String(roads_rivers.get("coordinate_vector_capacity_offset", "")) != "generator+0x14b8" \
			or int(roads_rivers.get("coordinate_record_size_bytes", -1)) != 12 \
			or int(roads_rivers.get("candidate_accept_threshold_low_word", -1)) != 0x7530 \
			or not bool(roads_rivers.get("grid_available", false)) \
			or int(roads_rivers.get("generator_coordinate_record_count", -1)) != 3 \
			or road_coordinate_records.size() != 3 \
			or int(road_coordinate_records[0].get("x", -1)) != int(town_records[0].get("x", -2)) \
			or int(road_coordinate_records[1].get("y", -1)) != int(town_records[1].get("y", -2)) \
			or bool(road_coordinate_records[0].get("complete_executable_vector_claim", true)) \
			or int(roads_rivers.get("pair_candidate_iteration_count", -1)) != 3 \
			or int(roads_rivers.get("candidate_low_word_count", -1)) != 3 \
			or road_pair_records.size() != 3 \
			or bool(roads_rivers.get("complete_executable_vector_claim", true)) \
			or not bool(roads_rivers.get("materializes_private_coordinate_vector_walk", false)) \
			or not bool(roads_rivers.get("materializes_private_candidate_low_words", false)) \
			or not bool(roads_rivers.get("materializes_private_road_geometry", false)) \
			or not bool(roads_rivers.get("materializes_private_road_overlay_candidates", false)) \
			or not bool(roads_rivers.get("materializes_serialized_road_overlay", false)) \
			or bool(roads_rivers.get("materializes_public_roads", true)) \
			or bool(roads_rivers.get("materializes_public_rivers", true)) \
			or bool(roads_rivers.get("adopts_into_runtime_grid", true)) \
			or bool(roads_rivers.get("public_package_output_allowed", true)) \
			or not bool(roads_rivers.get("road_overlay_byte_4_materialized", false)) \
			or not bool(roads_rivers.get("road_overlay_byte_5_materialized", false)) \
			or not bool(roads_rivers.get("road_overlay_byte_6_materialized", false)) \
			or int(roads_rivers.get("selected_road_type", 0)) < 1 \
			or int(roads_rivers.get("selected_road_type", 0)) > 3 \
			or int(roads_rivers.get("accepted_predecessor_chain_count", 0)) <= 0 \
			or int(roads_rivers.get("road_overlay_cell_count", 0)) <= 0 \
			or int(roads_rivers.get("road_overlay_art_nonzero_count", 0)) <= 0 \
			or int(roads_rivers.get("road_overlay_cell_records", []).size()) != int(roads_rivers.get("road_overlay_cell_count", -1)) \
			or String(road_final_art.get("status", "")) != "h3maped_0x458a2f_0x458893_private_road_art_materialized" \
			or not bool(road_final_art.get("materializes_final_road_art", false)) \
			or int(road_final_art.get("final_road_cell_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(road_final_art.get("line_visit_call_count", 0)) <= 0 \
			or int(road_final_art.get("final_write_count", 0)) <= 0 \
			or String(road_serialization.get("status", "")) != "h3maped_0x49b2b6_road_overlay_bytes_materialized_private" \
			or not bool(road_serialization.get("materializes_serialized_road_overlay", false)) \
			or bool(road_serialization.get("materializes_serialized_river_overlay", true)) \
			or int(road_serialization.get("road_overlay_cell_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or road_type_bytes.size() != 1296 \
			or road_art_bytes.size() != 1296 \
			or road_flag_bytes.size() != 1296 \
			or String(roads_rivers.get("blocked_next", "")) != "connections_blockers_guards_0x4a79a3_family_before_runtime_package_output":
		_fail("Strict roads/rivers private road overlay drifted: %s" % JSON.stringify(roads_rivers))
		return

	var connections: Dictionary = report.get("connections_blockers_guards", {})
	var connection_dispatch: Dictionary = connections.get("dispatch_summary", {})
	var high_owner_propagation: Dictionary = connections.get("high_owner_propagation", {})
	var transition_vectors: Dictionary = connections.get("transition_vectors", {})
	var fallback_4a7605: Dictionary = connections.get("fallback_4a7605", {})
	var connection_blockers: PackedInt32Array = connections.get("private_connection_blocker_u8", PackedInt32Array())
	var connection_guards: PackedInt32Array = connections.get("private_connection_guard_u8", PackedInt32Array())
	if String(connections.get("phase_id", "")) != "connections_blockers_and_guards" \
			or String(connections.get("status", "")) != "active_strict_private_connection_guards" \
			or String(connections.get("source_range", "")) != "0x4a79a3/0x4a61bc/0x4a696b/0x4a6cf2/0x4a7605/0x4a65a5/0x4a5e03" \
			or String(connections.get("binary_byte_prefix_0x4a79a3", "")) != "b8 eb a9 52 00 e8 23 e7 03 00 83 ec 78 8a 45 f3" \
			or String(connections.get("binary_byte_prefix_0x4a61bc", "")) != "b8 24 a9 52 00 e8 0a ff 03 00 83 ec 58 53 8b 55" \
			or String(connections.get("binary_byte_prefix_0x4a696b", "")) != "b8 56 a9 52 00 e8 5b f7 03 00 83 ec 5c 8b 55 08" \
			or String(connections.get("binary_byte_prefix_0x4a6cf2", "")) != "b8 7c a9 52 00 e8 d4 f3 03 00 83 ec 64 53 8b 55" \
			or String(connections.get("binary_byte_prefix_0x4a7605", "")) != "b8 c4 a9 52 00 e8 c1 ea 03 00 83 ec 2c 53 56" \
			or String(connections.get("binary_byte_prefix_0x4a65a5", "")) != "8b 44 24 08 56 8b 74 24 08 8b c8 c1 e1 02 57" \
			or not bool(connections.get("grid_available", false)) \
			or int(connections.get("link_seed_count", -1)) != 5 \
			or int(connections.get("connection_record_count", -1)) != 5 \
			or int(connections.get("transition_candidate_total", 0)) <= 0 \
			or int(connections.get("materialized_connection_count", 0)) != 5 \
			or int(connections.get("runtime_zone_relation_record_count_0x49b3fb", -1)) != 10 \
			or int(connections.get("runtime_zone_relation_wide_byte_8_count_0x49b3fb", -1)) != 0 \
			or int(connections.get("private_blocker_cell_count", 0)) != 10 \
			or int(connections.get("private_guard_record_count", 0)) != 6 \
			or int(connections.get("private_connection_guard_materialized_count", 0)) != 6 \
			or not bool(connections.get("materializes_private_connection_geometry", false)) \
			or not bool(connections.get("materializes_private_blocker_cells", false)) \
			or not bool(connections.get("materializes_private_connection_guards", false)) \
			or bool(connections.get("materializes_public_objects", true)) \
			or bool(connections.get("adopts_into_runtime_grid", true)) \
			or bool(connections.get("public_package_output_allowed", true)) \
			or int(connections.get("normal_guard_scaled_nonzero_count", -1)) != 5 \
			or String(high_owner_propagation.get("status", "")) != "0x4a5767_0x49a318_high_owner_channel_materialized_private" \
			or int(high_owner_propagation.get("cross_owner_high_byte_write_count", 0)) <= 0 \
			or String(transition_vectors.get("status", "")) != "0x4a79d8_transition_vectors_materialized_private" \
			or int(transition_vectors.get("transition_candidate_count", 0)) <= 0 \
			or String(fallback_4a7605.get("status", "")) != "0x4a7605_0x4a7312_private_dual_endpoint_fallback_materialized" \
			or int(fallback_4a7605.get("attempt_count", -1)) != 1 \
			or int(fallback_4a7605.get("selected_count", -1)) != 1 \
			or String(connection_dispatch.get("status", "")) != "0x4a79a3_private_connection_dispatch_materialized" \
			or int(connection_dispatch.get("link_count", -1)) != 5 \
			or int(connection_dispatch.get("materialized_connection_count", -1)) != int(connections.get("materialized_connection_count", -2)) \
			or int(connection_dispatch.get("rng_call_count", 0)) <= 0 \
			or int(connection_dispatch.get("no_transition_candidate_count", -1)) != 0 \
			or connection_blockers.size() != 1296 \
			or connection_guards.size() != 1296 \
			or String(connections.get("blocked_next", "")) != "public_package_adoption_after_private_connection_guards":
		_fail("Strict connections/blockers/guards private port drifted: %s" % JSON.stringify(connections))
		return

	var generated_cell_bit_state: Dictionary = report.get("generated_cell_decoration_bit_state", {})
	var upstream_bit_writer_sources: Dictionary = generated_cell_bit_state.get("upstream_bit_writer_sources", {})
	if String(generated_cell_bit_state.get("phase_id", "")) != "generated_cell_decoration_bit_state" \
			or String(generated_cell_bit_state.get("status", "")) != "active_strict_generated_cell_decoration_bit_state" \
			or String(generated_cell_bit_state.get("source_range", "")) != "0x4a4c8e/0x49aa63/0x49a932/0x4a5a23/0x4a4fc5/0x49eb8d" \
			or String(generated_cell_bit_state.get("decor_candidate_helper_anchor", "")) != "0x49aa63" \
			or String(generated_cell_bit_state.get("occupied_blocked_helper_anchor", "")) != "0x49a932" \
			or String(generated_cell_bit_state.get("cleanup_decor_candidate_writer_anchor", "")) != "0x4a8c15/0x49a962" \
			or String(generated_cell_bit_state.get("land_edge_decor_candidate_writer_anchor", "")) != "0x4a4c8e/0x49b3fb" \
			or String(generated_cell_bit_state.get("junction_decor_candidate_writer_anchor", "")) != "0x4a89da" \
			or String(generated_cell_bit_state.get("occupancy_normalizer_anchor", "")) != "0x4a5767" \
			or String(generated_cell_bit_state.get("border_guard_marker_materializer_anchor", "")) != "0x4a5a23" \
			or String(generated_cell_bit_state.get("water_edge_decor_candidate_writer_anchor", "")) != "0x4a4fc5" \
			or String(generated_cell_bit_state.get("binary_byte_prefix_0x49aa63", "")) != "generated_cell_decor_candidate_bit_26_helper_recovered_spec_boundary" \
			or String(generated_cell_bit_state.get("binary_byte_prefix_0x49a932", "")) != "generated_cell_occupied_blocked_bit_27_helper_recovered_spec_boundary" \
			or String(generated_cell_bit_state.get("binary_byte_prefix_0x4a4c8e", "")) != "land_edge_generated_cell_bit_26_writer_recovered_spec_boundary" \
			or String(generated_cell_bit_state.get("binary_byte_prefix_0x4a5a23", "")) != "border_guard_marker_generated_cell_bit_state_recovered_spec_boundary" \
			or String(generated_cell_bit_state.get("binary_byte_prefix_0x4a4fc5", "")) != "water_edge_generated_cell_bit_26_writer_recovered_spec_boundary" \
			or int(upstream_bit_writer_sources.get("junction_0x4a89da_source_bucket_3_runtime_zone_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("junction_0x4a89da_candidate_set_count", -1)) != 0 \
			or not bool(upstream_bit_writer_sources.get("junction_0x4a89da_object_vector_empty_by_phase_order", false)) \
			or int(upstream_bit_writer_sources.get("cleanup_0x4a8c15_scan_cell_count", -1)) != 1296 \
			or int(upstream_bit_writer_sources.get("cleanup_0x4a8c15_signed_owner_match_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("cleanup_0x49a962_call_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("cleanup_0x49a962_candidate_set_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("cleanup_0x49a962_neighbor_0x49a932_false_set_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("cleanup_0x49a962_neighbor_0x49a932_false_clear_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_scan_cell_count", -1)) != 1296 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_owner_low_negative_skip_count", -1)) != 189 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_source_nonwater_cell_count", -1)) != 1107 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_neighbor_probe_cell_count", -1)) != 8461 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_unassigned_water_trigger_count", -1)) != 80 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_relation_lookup_required_count", -1)) != 906 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_relation_lookup_missing_count", -1)) != 332 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_relation_byte8_zero_trigger_count", -1)) != 574 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_relation_byte8_wide_suppressed_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_level_one_trigger_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_triggered_cell_count", -1)) != 377 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_current_0x49aa63_candidate_set_count", -1)) != 17 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_expansion_0x49aa63_scan_count", -1)) != 3345 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_expansion_0x49aa63_candidate_set_count", -1)) != 588 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_0x49a932_false_scan_count", -1)) != 9128 \
			or int(upstream_bit_writer_sources.get("land_edge_0x4a4c8e_0x49a932_false_clear_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("border_guard_marker_0x4a5a23_record_count", -1)) != int(connections.get("border_guard_marker_cell_count", -2)) \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_scan_cell_count", -1)) != 1296 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_owner_low_negative_skip_count", -1)) != 189 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_source_water_cell_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_owner_high_negative_skip_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_neighbor_probe_cell_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_neighbor_bit25_source_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_anchor_after_owner_zone_gate_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_rectangle_scan_cell_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("water_edge_0x4a4fc5_candidate_set_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("occupancy_0x49a932_set_count", -1)) != 119 \
			or int(upstream_bit_writer_sources.get("occupancy_0x49a932_clear_count", -1)) != 0 \
			or bool(upstream_bit_writer_sources.get("temporary_owner_transition_fallback_active", true)) \
			or int(upstream_bit_writer_sources.get("temporary_owner_transition_candidate_scan_count", -1)) != 346 \
			or int(upstream_bit_writer_sources.get("temporary_owner_transition_candidate_new_set_count", -1)) != 0 \
			or int(upstream_bit_writer_sources.get("owner_transition_diagnostic_scan_count", -1)) != 346 \
			or int(upstream_bit_writer_sources.get("owner_transition_diagnostic_new_gap_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("water_edge_0x4a4fc5_candidate_set_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("water_edge_0x4a4fc5_owner_high_negative_skip_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("land_edge_0x4a4c8e_triggered_cell_count", -1)) != 377 \
			or int(generated_cell_bit_state.get("land_edge_0x4a4c8e_relation_lookup_missing_count", -1)) != 332 \
			or int(generated_cell_bit_state.get("land_edge_0x4a4c8e_candidate_set_count", -1)) != 605 \
			or int(generated_cell_bit_state.get("owner_transition_candidate_scan_count", -1)) != 346 \
			or bool(generated_cell_bit_state.get("temporary_owner_transition_fallback_active", true)) \
			or int(generated_cell_bit_state.get("temporary_owner_transition_candidate_scan_count", -1)) != 346 \
			or int(generated_cell_bit_state.get("temporary_owner_transition_candidate_new_set_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("owner_transition_diagnostic_scan_count", -1)) != 346 \
			or int(generated_cell_bit_state.get("owner_transition_diagnostic_new_gap_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("cleanup_0x49a962_candidate_set_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("junction_0x4a89da_candidate_set_count", -1)) != 0 \
			or int(generated_cell_bit_state.get("border_guard_marker_0x4a5a23_record_count", -1)) != int(connections.get("border_guard_marker_cell_count", -2)) \
			or int(generated_cell_bit_state.get("decor_candidate_set_count", -1)) != 605 \
			or int(generated_cell_bit_state.get("occupied_blocked_set_count", -1)) != 119 \
			or int(generated_cell_bit_state.get("final_decor_candidate_bit_26_count", -1)) != 520 \
			or int(generated_cell_bit_state.get("final_occupied_blocked_bit_27_count", -1)) != 119 \
			or not bool(generated_cell_bit_state.get("materializes_generated_cell_bit_26", false)) \
			or not bool(generated_cell_bit_state.get("materializes_generated_cell_bit_27", false)) \
			or not bool(generated_cell_bit_state.get("exact_upstream_bit_source_claim", false)):
		_fail("Strict generated-cell decoration bit-state phase drifted: %s" % JSON.stringify(generated_cell_bit_state))
		return

	var decorative_filler: Dictionary = report.get("decorative_obstacle_filler", {})
	var obstacle_catalog_load: Dictionary = decorative_filler.get("obstacle_catalog_load", {})
	var decorative_records: Array = decorative_filler.get("private_decorative_obstacle_records", [])
	if String(decorative_filler.get("phase_id", "")) != "decorative_obstacle_filler" \
			or String(decorative_filler.get("status", "")) != "active_strict_private_decorative_obstacle_filler" \
			or String(decorative_filler.get("source_range", "")) != "0x49dc9e/0x49eb8d/0x49e700/0x41e951/0x49e1bf/0x49ba89" \
			or String(decorative_filler.get("generated_cell_bit_state_status", "")) != "active_strict_generated_cell_decoration_bit_state" \
			or int(decorative_filler.get("decor_candidate_bit_26_count_before_filler", -1)) != int(generated_cell_bit_state.get("final_decor_candidate_bit_26_count", -2)) \
			or int(decorative_filler.get("occupied_blocked_bit_27_count_before_filler", -1)) != int(generated_cell_bit_state.get("final_occupied_blocked_bit_27_count", -2)) \
			or String(decorative_filler.get("rand_trn_fixture_path", "")) != "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv" \
			or String(decorative_filler.get("object_catalog_source_path", "")) != "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json" \
			or not bool(obstacle_catalog_load.get("ok", false)) \
			or int(decorative_filler.get("rand_trn_obstacle_row_count", -1)) != 109 \
			or int(decorative_filler.get("candidate_template_count", -1)) != 541 \
			or int(decorative_filler.get("obstacle_row_type_limit_rejected_count", -1)) != 6 \
			or int(decorative_filler.get("obstacle_row_template_missing_count", -1)) != 0 \
			or int(decorative_filler.get("candidate_template_body_missing_count", -1)) != 2 \
			or int(decorative_filler.get("generated_flagged_cell_count", -1)) != 520 \
			or int(decorative_filler.get("budget_argument_to_0x49e700", -1)) != 531 \
			or int(decorative_filler.get("budget_gate_denominator", -1)) != 1024 \
			or int(decorative_filler.get("cell_call_count", -1)) != 520 \
			or int(decorative_filler.get("initial_occupied_seed_cell_count", -1)) != 119 \
			or int(decorative_filler.get("private_decorative_object_placement_count", -1)) != 73 \
			or int(decorative_filler.get("private_remaining_candidate_0x49a932_lock_count", -1)) != 446 \
			or int(decorative_filler.get("private_decorative_obstacle_record_count", -1)) != 519 \
			or decorative_records.size() != 519 \
			or int(decorative_filler.get("private_decorative_marked_body_cell_count", -1)) != 590 \
			or not bool(decorative_filler.get("materializes_private_decorative_obstacles", false)) \
			or bool(decorative_filler.get("materializes_public_objects", true)) \
			or bool(decorative_filler.get("public_package_output_allowed", true)):
		_fail("Strict decorative obstacle filler phase drifted: %s" % JSON.stringify(decorative_filler))
		return
	if decorative_records.is_empty() \
			or String(decorative_records[0].get("phase", "")) != "0x49eb8d_0x49e700_rand_trn_decorative_filler" \
			or String(decorative_records[0].get("object_id", "")) == "" \
			or int(decorative_records[0].get("body_tile_count", 0)) <= 0 \
			or not bool(decorative_records[0].get("blocking_body", false)) \
			or String(decorative_records[0].get("package_adoption_source", "")) != "h3maped_private_0x49eb8d_0x49e700_rand_trn_decorative_filler":
		_fail("Strict decorative obstacle record missed package-boundary blocking metadata: %s" % JSON.stringify(decorative_records.slice(0, 3)))
		return

	var package_adoption: Dictionary = report.get("public_package_adoption", {})
	var package_validation: Dictionary = package_adoption.get("structural_validation", {})
	var map_payload: Dictionary = package_adoption.get("map_document_payload", {})
	var terrain_layers: Dictionary = map_payload.get("terrain_layers", {})
	var terrain_layer: Dictionary = terrain_layers.get("terrain", {})
	var road_records: Array = terrain_layers.get("roads", [])
	var package_objects: Array = map_payload.get("objects", [])
	var route_graph: Dictionary = map_payload.get("route_graph", {})
	if String(package_adoption.get("phase_id", "")) != "public_package_adoption" \
			or String(package_adoption.get("schema_id", "")) != "aurelion_h3maped_small_package_adoption_draft_v1" \
			or String(package_adoption.get("status", "")) != "strict_package_adoption_draft_materialized_runtime_blocked" \
			or bool(package_adoption.get("runtime_generation_allowed", true)) \
			or bool(package_adoption.get("public_runtime_authoritative", true)) \
			or not bool(package_adoption.get("materializes_package_draft", false)) \
			or not bool(package_adoption.get("map_document_payload_materialized", false)) \
			or not bool(package_adoption.get("package_tiles_materialized_from_private_state", false)) \
			or not bool(package_adoption.get("package_objects_materialized_from_private_state", false)) \
			or int(package_adoption.get("terrain_layer_level_count", -1)) != 1 \
			or int(package_adoption.get("terrain_tile_count", -1)) != 1296 \
			or int(package_adoption.get("town_package_object_count", -1)) != 3 \
			or int(package_adoption.get("owned_player_town_count", -1)) != 3 \
			or int(package_adoption.get("neutral_town_package_object_count", -1)) != 0 \
			or int(package_adoption.get("player_start_count", -1)) != 3 \
			or int(package_adoption.get("player_start_town_sync_count", -1)) != 3 \
			or int(package_adoption.get("mine_package_object_count", -1)) != 17 \
			or int(package_adoption.get("reward_package_object_count", -1)) != 3 \
			or int(package_adoption.get("connection_blocker_package_object_count", -1)) != 10 \
			or int(package_adoption.get("connection_guard_package_object_count", -1)) != 6 \
			or int(package_adoption.get("decorative_obstacle_package_object_count", -1)) != 519 \
			or int(package_adoption.get("package_object_count", -1)) != 558 \
			or int(package_adoption.get("road_package_segment_count", -1)) != int(roads_rivers.get("accepted_predecessor_chain_count", -2)) \
			or int(package_adoption.get("road_package_tile_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(package_adoption.get("road_package_route_edge_count", -1)) != int(package_adoption.get("road_package_segment_count", -2)) \
			or int(package_adoption.get("road_package_segment_cell_count", -1)) <= int(package_adoption.get("road_package_tile_count", -2)) \
			or int(package_adoption.get("road_package_disconnected_segment_count", -1)) != 0 \
			or String(package_adoption.get("h3maped_road_public_adoption_status", "")) != "h3maped_predecessor_chains_adopted_as_route_segments" \
			or String(package_adoption.get("blocked_next", "")) != "rivers_overlay_writeback_and_final_0x49b2b6_writeout_before_runtime_generation_allowed" \
			or String(package_validation.get("status", "")) != "draft_pass_runtime_blocked" \
			or bool(package_validation.get("runtime_generation_allowed", true)) \
			or bool(package_validation.get("authorizes_public_runtime", true)) \
			or int(package_validation.get("out_of_bounds_object_count", -1)) != 0 \
			or int(package_validation.get("duplicate_placement_id_count", -1)) != 0 \
			or int(package_validation.get("player_start_town_sync_count", -1)) != 3 \
			or int(package_validation.get("road_segment_count", -1)) != int(package_adoption.get("road_package_segment_count", -2)) \
			or int(package_validation.get("road_segment_cell_count", -1)) != int(package_adoption.get("road_package_segment_cell_count", -2)) \
			or int(package_validation.get("road_segment_disconnected_count", -1)) != 0 \
			or int(package_validation.get("road_route_edge_count", -1)) != int(package_adoption.get("road_package_route_edge_count", -2)) \
			or String(map_payload.get("schema_id", "")) != "aurelion_map_document" \
			or String(map_payload.get("source_kind", "")) != "generated_h3maped_small_draft" \
			or bool(map_payload.get("public_runtime_authoritative", true)) \
			or int(map_payload.get("width", -1)) != 36 \
			or int(map_payload.get("height", -1)) != 36 \
			or int(map_payload.get("level_count", -1)) != 1 \
			or String(terrain_layers.get("schema_id", "")) != "aurelion_map_terrain_layers" \
			or String(terrain_layer.get("encoding", "")) != "h3maped_terrain_code_u16_by_level" \
			or int(terrain_layer.get("tile_count", -1)) != 1296 \
			or road_records.size() != int(roads_rivers.get("accepted_predecessor_chain_count", -2)) \
			or int(terrain_layers.get("road_unique_tile_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(terrain_layers.get("road_segment_cell_count", -1)) != int(package_adoption.get("road_package_segment_cell_count", -2)) \
			or String(terrain_layers.get("h3maped_road_public_adoption_status", "")) != "h3maped_predecessor_chains_adopted_as_route_segments" \
			or package_objects.size() != 558 \
			or String(route_graph.get("schema_id", "")) != "aurelion_h3maped_small_route_graph_draft_v1" \
			or bool(route_graph.get("public_runtime_authoritative", true)) \
			or int(route_graph.get("edge_count", -1)) != road_records.size() \
			or int(route_graph.get("road_segment_count", -1)) != road_records.size() \
			or int(route_graph.get("road_segment_cell_count", -1)) != int(package_adoption.get("road_package_segment_cell_count", -2)) \
			or int(route_graph.get("road_unique_tile_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(route_graph.get("road_segment_disconnected_count", -1)) != 0 \
			or String(route_graph.get("road_infrastructure_status", "")) != "h3maped_town_route_segments_connected" \
			or int(route_graph.get("link_count", -1)) != 5 \
			or int(route_graph.get("guarded_link_count", -1)) != 5:
		_fail("Strict public package adoption draft drifted: %s" % JSON.stringify(package_adoption))
		return
	for road_record in road_records:
		if not (road_record is Dictionary):
			_fail("Strict public package road record is invalid: %s" % JSON.stringify(road_records))
			return
		if String(road_record.get("route_edge_id", "")) == "" \
				or String(road_record.get("road_class", "")) != "h3maped_town_route_road" \
				or String(road_record.get("road_type_id", "")) == "" \
				or String(road_record.get("h3maped_road_atlas", "")) == "" \
				or not bool(road_record.get("connected_cell_chain", false)) \
				or int(road_record.get("cell_count", 0)) <= 1:
			_fail("Strict public package road segment missed route metadata: %s" % JSON.stringify(road_record))
			return
		for road_cell in road_record.get("cells", []):
			if not (road_cell is Dictionary) \
					or String(road_cell.get("route_edge_id", "")) != String(road_record.get("route_edge_id", "")) \
					or String(road_cell.get("road_class", "")) != "h3maped_town_route_road" \
					or String(road_cell.get("road_type_id", "")) == "" \
					or String(road_cell.get("h3maped_road_art_frame_id", "")) == "" \
					or String(road_cell.get("h3maped_road_atlas", "")) == "":
				_fail("Strict public package road cell missed h3maped route/art metadata: %s" % JSON.stringify(road_record))
				return

	var final_writeout: Dictionary = report.get("final_h3m_writeout", {})
	var final_writeout_validation: Dictionary = final_writeout.get("structural_validation", {})
	var tile_bytes: Dictionary = final_writeout.get("tile_bytes", {})
	var final_byte_0: PackedInt32Array = tile_bytes.get("byte_0_terrain_u8", PackedInt32Array())
	var final_byte_1: PackedInt32Array = tile_bytes.get("byte_1_terrain_art_u8", PackedInt32Array())
	var final_byte_2: PackedInt32Array = tile_bytes.get("byte_2_river_type_u8", PackedInt32Array())
	var final_byte_3: PackedInt32Array = tile_bytes.get("byte_3_river_art_u8", PackedInt32Array())
	var final_byte_4: PackedInt32Array = tile_bytes.get("byte_4_road_type_u8", PackedInt32Array())
	var final_byte_5: PackedInt32Array = tile_bytes.get("byte_5_road_art_u8", PackedInt32Array())
	var final_byte_6: PackedInt32Array = tile_bytes.get("byte_6_flags_u8", PackedInt32Array())
	if String(final_writeout.get("phase_id", "")) != "final_h3m_writeout" \
			or String(final_writeout.get("schema_id", "")) != "aurelion_h3maped_small_final_49b2b6_writeout_draft_v1" \
			or String(final_writeout.get("status", "")) != "strict_final_0x49b2b6_writeout_draft_runtime_blocked" \
			or String(final_writeout.get("h3maped_anchor", "")) != "0x49b2b6" \
			or bool(final_writeout.get("runtime_generation_allowed", true)) \
			or bool(final_writeout.get("public_runtime_authoritative", true)) \
			or bool(final_writeout.get("materializes_public_h3m", true)) \
			or not bool(final_writeout.get("materializes_final_serializer_draft", false)) \
			or int(final_writeout.get("tile_byte_array_count", -1)) != 7 \
			or int(final_writeout.get("tile_byte_array_size", -1)) != 1296 \
			or int(final_writeout.get("terrain_tile_count", -1)) != 1296 \
			or int(final_writeout.get("package_object_count", -1)) != 558 \
			or int(final_writeout.get("package_route_link_count", -1)) != 5 \
			or int(final_writeout.get("river_overlay_type_nonzero_count", -1)) != 0 \
			or int(final_writeout.get("river_overlay_art_nonzero_count", -1)) != 0 \
			or int(final_writeout.get("road_overlay_type_nonzero_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(final_writeout.get("road_overlay_art_nonzero_count", -1)) != int(roads_rivers.get("road_overlay_art_nonzero_count", -2)) \
			or int(final_writeout.get("road_overlay_flag_nonzero_count", -1)) < 0 \
			or String(final_writeout.get("blocked_next", "")) != "public_generate_random_map_authority_after_package_validation" \
			or String(final_writeout_validation.get("status", "")) != "draft_pass_runtime_blocked" \
			or bool(final_writeout_validation.get("runtime_generation_allowed", true)) \
			or bool(final_writeout_validation.get("authorizes_public_runtime", true)) \
			or int(final_writeout_validation.get("tile_byte_array_count", -1)) != 7 \
			or int(final_writeout_validation.get("tile_byte_array_size", -1)) != 1296 \
			or int(final_writeout_validation.get("package_object_count", -1)) != 558 \
			or final_byte_0.size() != 1296 \
			or final_byte_1.size() != 1296 \
			or final_byte_2.size() != 1296 \
			or final_byte_3.size() != 1296 \
			or final_byte_4.size() != 1296 \
			or final_byte_5.size() != 1296 \
			or final_byte_6.size() != 1296:
		_fail("Strict final 0x49b2b6 writeout draft drifted: %s" % JSON.stringify(final_writeout))
		return

	var fast_validator: Dictionary = report.get("fast_structural_validator", {})
	var validator_metrics: Dictionary = fast_validator.get("metrics", {})
	if String(fast_validator.get("phase_id", "")) != "fast_structural_validator_authority" \
			or String(fast_validator.get("schema_id", "")) != "aurelion_h3maped_small_fast_structural_validator_v1" \
			or String(fast_validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" \
			or not bool(fast_validator.get("runtime_generation_allowed", false)) \
			or not bool(fast_validator.get("public_runtime_authoritative", false)) \
			or not bool(fast_validator.get("authorizes_public_runtime", false)) \
			or not bool(fast_validator.get("validator_authority", false)) \
			or int(fast_validator.get("failure_count", -1)) != 0 \
			or String(fast_validator.get("blocked_next", "")) != "public_generate_random_map_authority_after_package_validation" \
			or int(validator_metrics.get("expected_tile_count", -1)) != 1296 \
			or int(validator_metrics.get("terrain_tile_count", -1)) != 1296 \
			or int(validator_metrics.get("package_object_count", -1)) != 558 \
			or int(validator_metrics.get("player_start_count", -1)) != 3 \
			or int(validator_metrics.get("owned_player_town_count", -1)) != 3 \
			or int(validator_metrics.get("mine_count", -1)) != 17 \
			or int(validator_metrics.get("reward_count", -1)) != 3 \
			or int(validator_metrics.get("connection_blocker_count", -1)) != 10 \
			or int(validator_metrics.get("blocking_connection_blocker_count", -1)) != 10 \
			or int(validator_metrics.get("connection_guard_count", -1)) != 6 \
			or int(validator_metrics.get("blocking_connection_guard_count", -1)) != 6 \
			or int(validator_metrics.get("route_link_count", -1)) != 5 \
			or int(validator_metrics.get("guarded_route_link_count", -1)) != 5 \
			or int(validator_metrics.get("unguarded_route_link_count", -1)) != 0 \
			or int(validator_metrics.get("route_link_without_blocker_count", -1)) != 0 \
			or int(validator_metrics.get("route_link_without_guard_count", -1)) != 0 \
			or int(validator_metrics.get("road_record_count", -1)) != int(roads_rivers.get("accepted_predecessor_chain_count", -2)) \
			or int(validator_metrics.get("road_route_edge_count", -1)) != int(validator_metrics.get("road_record_count", -2)) \
			or int(validator_metrics.get("road_route_node_count", -1)) != 3 \
			or int(validator_metrics.get("road_segment_disconnected_count", -1)) != 0 \
			or int(validator_metrics.get("road_segment_without_route_edge_count", -1)) != 0 \
			or int(validator_metrics.get("road_segment_missing_metadata_count", -1)) != 0 \
			or int(validator_metrics.get("road_segment_short_loop_count", -1)) != 0 \
			or int(validator_metrics.get("road_overlay_type_nonzero_count", -1)) != int(roads_rivers.get("road_overlay_cell_count", -2)) \
			or int(validator_metrics.get("duplicate_placement_id_count", -1)) != 0 \
			or int(validator_metrics.get("out_of_bounds_object_count", -1)) != 0:
		_fail("Strict fast structural validator drifted: %s" % JSON.stringify(fast_validator))
		return

	var strict_state: Dictionary = report.get("strict_restart_state", {})
	if String(strict_state.get("schema_id", "")) != "aurelion_h3maped_small_strict_executable_restart_state_v1" \
			or String(strict_state.get("status", "")) != "strict_executable_restart_scaffold_active" \
			or not bool(strict_state.get("binary_verified", false)) \
			or not bool(strict_state.get("active_public_generation_state", false)) \
			or not bool(strict_state.get("runtime_generation_allowed", false)) \
			or bool(strict_state.get("legacy_private_phase_ledgers_exposed", true)) \
			or not bool(strict_state.get("legacy_private_phase_ledgers_archived_only", false)) \
			or String(strict_state.get("next_required_port", "")) != "authoritative_final_map_package_serialization":
		_fail("Strict executable restart state drifted: %s" % JSON.stringify(strict_state))
		return

	var pending_ports: Array = strict_state.get("pending_strict_ports", [])
	if pending_ports.size() != 6 \
			or not pending_ports.has("authoritative_final_map_package_serialization") \
			or not pending_ports.has("roads_as_route_infrastructure_audit") \
			or not pending_ports.has("blockers_guards_runtime_zoning_audit") \
			or not pending_ports.has("validator_negative_cases") \
			or not pending_ports.has("small_map_corpus_audit") \
			or not pending_ports.has("editor_runtime_adoption_audit"):
		_fail("Strict restart pending executable ports changed: %s" % JSON.stringify(pending_ports))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 23 \
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
			or String(backlog[14].get("id", "")) != "mines_rewards_and_object_vector" \
			or String(backlog[14].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[15].get("id", "")) != "roads_and_rivers" \
			or String(backlog[15].get("status", "")) != "active_strict_private_road_overlay" \
			or String(backlog[16].get("id", "")) != "connections_blockers_and_guards" \
			or String(backlog[16].get("status", "")) != "active_strict_private_connection_guards" \
			or String(backlog[17].get("id", "")) != "generated_cell_decoration_bit_state" \
			or String(backlog[17].get("status", "")) != "active_strict_private_generated_cell_bit_state" \
			or String(backlog[18].get("id", "")) != "decorative_obstacle_filler" \
			or String(backlog[18].get("status", "")) != "active_strict_private_decorative_obstacles" \
			or String(backlog[19].get("id", "")) != "public_package_adoption" \
			or String(backlog[19].get("status", "")) != "active_strict_package_draft_runtime_blocked" \
			or String(backlog[20].get("id", "")) != "final_h3m_writeout" \
			or String(backlog[20].get("status", "")) != "active_strict_writeout_draft_runtime_blocked" \
			or String(backlog[21].get("id", "")) != "fast_structural_validator_authority" \
			or String(backlog[21].get("status", "")) != "active_strict_validator_authority_runtime_blocked" \
			or String(backlog[22].get("id", "")) != "public_generation_authority" \
			or String(backlog[22].get("status", "")) != "active_validator_gated_public_package_production_ready_strict_small_land":
		_fail("Strict phase backlog drifted: %s" % JSON.stringify(backlog))
		return

	var generated: Dictionary = service.generate_random_map(supported_config)
	var generated_map_payload: Dictionary = generated.get("map_document_payload", {})
	var generated_terrain_layers: Dictionary = generated_map_payload.get("terrain_layers", {})
	var generated_roads: Array = generated_terrain_layers.get("roads", [])
	var generated_route_graph: Dictionary = generated_map_payload.get("route_graph", {})
	var generated_objects: Array = generated_map_payload.get("objects", [])
	var generated_player_starts: Array = generated_map_payload.get("player_starts", [])
	var generated_tile_bytes: Dictionary = generated.get("final_tile_bytes", {})
	var generated_metrics: Dictionary = generated.get("validator_metrics", {})
	if not bool(generated.get("ok", false)) \
			or String(generated.get("schema_id", "")) != "aurelion_h3maped_small_validator_gated_generation_result_v1" \
			or String(generated.get("generation_status", "")) != "h3maped_small_validated_package_ready" \
			or String(generated.get("full_generation_status", "")) != "h3maped_small_public_package_production_ready_strict_small_land" \
			or not bool(generated.get("runtime_generation_allowed", false)) \
			or not bool(generated.get("public_runtime_authoritative", false)) \
			or not bool(generated.get("production_ready", false)) \
			or String(generated.get("production_ready_scope", "")) != "strict_small_36x36_one_level_land_only" \
			or bool(generated.get("full_parity_claim", true)) \
			or String(generated_map_payload.get("schema_id", "")) != "aurelion_map_document" \
			or String(generated_map_payload.get("source_kind", "")) != "generated_h3maped_small_validated" \
			or int(generated_map_payload.get("width", -1)) != 36 \
			or int(generated_map_payload.get("height", -1)) != 36 \
			or int(generated_map_payload.get("level_count", -1)) != 1 \
			or String(generated_map_payload.get("source_template_id", "")) != "h3maped_template_018" \
			or not bool(generated_map_payload.get("public_runtime_authoritative", false)) \
			or generated_objects.size() != 558 \
			or generated_player_starts.size() != 3 \
			or generated_roads.size() != int(roads_rivers.get("accepted_predecessor_chain_count", -2)) \
			or int(generated_route_graph.get("edge_count", -1)) != generated_roads.size() \
			or int(generated_route_graph.get("road_segment_disconnected_count", -1)) != 0 \
			or int(generated_route_graph.get("link_count", -1)) != 5 \
			or int(generated_route_graph.get("guarded_link_count", -1)) != 5 \
			or int(generated_tile_bytes.get("byte_0_terrain_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_1_terrain_art_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_2_river_type_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_3_river_art_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_4_road_type_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_5_road_art_u8", []).size()) != 1296 \
			or int(generated_tile_bytes.get("byte_6_flags_u8", []).size()) != 1296 \
			or int(generated_metrics.get("owned_player_town_count", -1)) != 3 \
			or int(generated_metrics.get("package_object_count", -1)) != 558 \
			or int(generated_metrics.get("road_record_count", -1)) != generated_roads.size() \
			or int(generated_metrics.get("road_route_edge_count", -1)) != generated_roads.size() \
			or int(generated_metrics.get("road_segment_disconnected_count", -1)) != 0 \
			or int(generated_metrics.get("unguarded_route_link_count", -1)) != 0 \
			or int(generated_metrics.get("route_link_without_blocker_count", -1)) != 0 \
			or int(generated_metrics.get("route_link_without_guard_count", -1)) != 0:
		_fail("Supported small map generation did not return the validator-gated public package: %s" % JSON.stringify(generated))
		return
	var generated_repeat: Dictionary = service.generate_random_map(supported_config.duplicate(true))
	var repeat_payload: Dictionary = generated_repeat.get("map_document_payload", {})
	if not bool(generated_repeat.get("ok", false)) \
			or String(repeat_payload.get("map_id", "")) != String(generated_map_payload.get("map_id", "")) \
			or String(repeat_payload.get("map_hash", "")) != String(generated_map_payload.get("map_hash", "")) \
			or int(Array(repeat_payload.get("objects", [])).size()) != generated_objects.size() \
			or Dictionary(generated_repeat.get("final_tile_bytes", {})) != generated_tile_bytes:
		_fail("Supported small map generation is not deterministic across repeat calls: %s / %s" % [JSON.stringify(generated), JSON.stringify(generated_repeat)])
		return
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"scenario_id": "h3maped_small_validator_gate_test",
		"feature_gate": "native_rmg_small_h3maped_validator_gated_public_package_test",
	})
	var adopted_map_document: Variant = adoption.get("map_document", null)
	var adopted_scenario_document: Variant = adoption.get("scenario_document", null)
	var adoption_report: Dictionary = adoption.get("report", {})
	var adoption_metrics: Dictionary = adoption_report.get("metrics", {})
	if not bool(adoption.get("ok", false)) \
			or String(adoption.get("status", "")) != "pass" \
			or String(adoption.get("conversion_kind", "")) != "h3maped_small_validated_package_to_package_session_records" \
			or String(adoption.get("adoption_status", "")) != "h3maped_small_package_session_production_ready_strict_small_land" \
			or adopted_map_document == null \
			or adopted_scenario_document == null \
			or int(adopted_map_document.get_width()) != 36 \
			or int(adopted_map_document.get_height()) != 36 \
			or int(adopted_map_document.get_level_count()) != 1 \
			or int(adopted_map_document.get_object_count()) != 558 \
			or String(adopted_map_document.get_source_kind()) != "generated_h3maped_small_validated" \
			or int(adopted_scenario_document.get_start_contract().get("start_count", -1)) != 3 \
			or int(adopted_scenario_document.get_start_contract().get("start_town_count", -1)) != 3 \
			or not bool(adoption_report.get("package_session_adoption_ready", false)) \
			or not bool(adoption_report.get("production_ready", false)) \
			or String(adoption_report.get("production_ready_scope", "")) != "strict_small_36x36_one_level_land_only" \
			or int(adoption_metrics.get("route_link_count", -1)) != 5:
		_fail("Validator-gated public package did not adopt into package/session documents: %s" % JSON.stringify(adoption))
		return
	var map_validation: Dictionary = service.validate_map_document(adopted_map_document)
	if not bool(map_validation.get("ok", false)) \
			or int(map_validation.get("report", {}).get("metrics", {}).get("object_count", -1)) != 558 \
			or int(map_validation.get("report", {}).get("metrics", {}).get("road_count", -1)) != int(roads_rivers.get("accepted_predecessor_chain_count", -2)):
		_fail("Validator-gated h3maped map document did not validate: %s" % JSON.stringify(map_validation))
		return
	var scenario_validation: Dictionary = service.validate_scenario_document(adopted_scenario_document, adopted_map_document)
	if not bool(scenario_validation.get("ok", false)) \
			or int(scenario_validation.get("report", {}).get("metrics", {}).get("player_slot_count", -1)) != 3:
		_fail("Validator-gated h3maped scenario document did not validate: %s" % JSON.stringify(scenario_validation))
		return
	var map_package_path := "user://h3maped_small_validator_gate_test.amap"
	var scenario_package_path := "user://h3maped_small_validator_gate_test.ascenario"
	var save_map: Dictionary = service.save_map_package(adopted_map_document, map_package_path, {"path_policy": "h3maped_small_validator_gate_test", "return_package": false})
	if not bool(save_map.get("ok", false)):
		_fail("Validator-gated h3maped map package save failed: %s" % JSON.stringify(save_map))
		return
	var save_scenario: Dictionary = service.save_scenario_package(adopted_scenario_document, scenario_package_path, {"path_policy": "h3maped_small_validator_gate_test", "return_package": false})
	if not bool(save_scenario.get("ok", false)):
		DirAccess.remove_absolute(map_package_path)
		_fail("Validator-gated h3maped scenario package save failed: %s" % JSON.stringify(save_scenario))
		return
	var load_map: Dictionary = service.load_map_package(map_package_path)
	var load_scenario: Dictionary = service.load_scenario_package(scenario_package_path)
	DirAccess.remove_absolute(map_package_path)
	DirAccess.remove_absolute(scenario_package_path)
	var loaded_map_document: Variant = load_map.get("map_document", null)
	var loaded_scenario_document: Variant = load_scenario.get("scenario_document", null)
	if not bool(load_map.get("ok", false)) \
			or not bool(load_scenario.get("ok", false)) \
			or loaded_map_document == null \
			or loaded_scenario_document == null \
			or String(loaded_map_document.get_map_hash()) != String(adopted_map_document.get_map_hash()) \
			or int(loaded_map_document.get_object_count()) != 558 \
			or int(loaded_scenario_document.get_start_contract().get("start_count", -1)) != 3:
		_fail("Validator-gated h3maped packages did not round-trip through save/load: %s / %s" % [JSON.stringify(load_map), JSON.stringify(load_scenario)])
		return

	var explicit_config := supported_config.duplicate(true)
	explicit_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_result: Dictionary = service.generate_random_map(explicit_config)
	var explicit_payload: Dictionary = explicit_result.get("map_document_payload", {})
	if not bool(explicit_result.get("ok", false)) \
			or String(explicit_result.get("generation_status", "")) != "h3maped_small_validated_package_ready" \
			or String(explicit_payload.get("source_template_id", "")) != "h3maped_template_018" \
			or String(explicit_payload.get("source_kind", "")) != "generated_h3maped_small_validated":
		_fail("Explicit translated-template request did not stay on h3maped source-template authority: %s" % JSON.stringify(explicit_result))
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
