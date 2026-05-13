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
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return
	if String(metadata.get("native_rmg_generation_authority", "")) != "h3maped_small_reset_only" \
			or bool(metadata.get("native_rmg_runtime_generation_allowed", true)) \
			or String(metadata.get("native_rmg_active_reset_slice_id", "")) != "native-rmg-small-h3maped-port-10184":
		_fail("Native API metadata does not enforce the h3maped small reset gate: %s" % JSON.stringify(metadata))
		return

	var config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var report: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	if not bool(report.get("ok", false)):
		_fail("Small h3maped restart boundary did not accept the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_restart_boundary_v2" \
			or String(report.get("status", "")) != "h3maped_small_restart_boundary_ready":
		_fail("Small h3maped inspection did not use the restart boundary schema: %s" % JSON.stringify(report))
		return
	if String(report.get("implementation_policy", "")) != "small_only_h3maped_exe_restart_no_catalog_auto_no_hash_selection_no_private_phase_ledger_no_runtime_fallback":
		_fail("The restart policy is not explicit enough: %s" % JSON.stringify(report))
		return
	if String(report.get("archive_status", "")) != "overgrown_active_port_archived_out_of_build" \
			or String(report.get("archived_overgrown_active_path", "")) != "src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp":
		_fail("The overgrown active port was not archived out of the build: %s" % JSON.stringify(report))
		return
	if report.has("private_generation_context"):
		_fail("Restart boundary still exposes the old private phase ledger: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) or bool(report.get("partial_materialized_payload_public_api", true)):
		_fail("The restart boundary must not expose runtime or partial package output: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("status", "")) != "verified_reset_anchor" \
			or not bool(binary.get("mz_header_present", false)) \
			or not bool(binary.get("sha256_matches", false)) \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("The restart boundary did not verify the local h3maped.exe anchor: %s" % JSON.stringify(binary))
		return

	if int(report.get("size_score", -1)) != 1 or int(report.get("h3maped_water_mode_code", -1)) != 0:
		_fail("Small land size score/water code did not follow the recovered formula: %s" % JSON.stringify(report))
		return
	if int(report.get("accepted_template_count", -1)) != 13:
		_fail("Unexpected accepted small-template count: %s" % JSON.stringify(report.get("accepted_templates", [])))
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
		_fail("h3maped RNG template selection boundary drifted: %s" % JSON.stringify(selection))
		return

	var backlog: Array = report.get("restart_phase_backlog", [])
	if backlog.size() != 10 \
			or String(backlog[0].get("id", "")) != "template_selection" \
			or String(backlog[0].get("status", "")) != "active_boundary_only" \
			or String(backlog[1].get("id", "")) != "player_slot_assignment" \
			or String(backlog[1].get("status", "")) != "active_runtime_state_ready" \
			or String(backlog[2].get("id", "")) != "runtime_zone_records" \
			or String(backlog[2].get("status", "")) != "active_runtime_state_ready" \
				or String(backlog[3].get("id", "")) != "coordinate_replay_and_zone_footprints" \
				or String(backlog[3].get("status", "")) != "active_runtime_state_ready" \
				or String(backlog[5].get("id", "")) != "town_object_placement" \
				or String(backlog[5].get("status", "")) != "active_runtime_state_ready" \
				or String(backlog[6].get("id", "")) != "mines_rewards_and_object_vector" \
				or String(backlog[6].get("status", "")) != "active_source_field_schedule_ready" \
				or String(backlog[7].get("id", "")) != "roads_and_rivers" \
				or String(backlog[7].get("status", "")) != "pending_strict_port" \
				or String(backlog[9].get("id", "")) != "final_h3m_writeout":
			_fail("Restart backlog drifted: %s" % JSON.stringify(backlog))
			return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Restart backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var small_state: Dictionary = report.get("small_generation_state", {})
	var expected_completed_phases := ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay", "zone_footprint_phase_boundary", "source_node_rectangle", "polygon_split_model", "source_node_boundary_traversal", "span_fill_4a325d", "footprint_finalizer_4a3710", "runtime_terrain_selection_49b53d", "terrain_cell_writeout_4a3f27", "terrainplacement_visual_tables_4bcff5", "terrainplacement_live_feedback_4bb74b_4bc5f0", "terrain_tile_byte_writeback_49b2b6", "town_castle_phase_4a8d2c", "object_vector_prerequisite_phase_4a9d6a_4aab7e"]
	if String(small_state.get("schema_id", "")) != "aurelion_h3maped_small_generation_state_v1" \
			or String(small_state.get("status", "")) != "object_vector_prerequisite_phase_4a9d6a_4aab7e_active_runtime_state_ready" \
			or Array(small_state.get("completed_phase_ids", [])) != expected_completed_phases \
			or int(small_state.get("completed_phase_count", -1)) != 18 \
			or bool(small_state.get("runtime_generation_allowed", true)) \
			or bool(small_state.get("materializes_runtime_players", true)) \
			or bool(small_state.get("materializes_map_cells", true)) \
			or bool(small_state.get("materializes_public_output", true)) \
			or String(small_state.get("blocked_next", "")) != "port_0x4aab7e_rewards_density_guards_adjacent_resources_before_0x4ab52a":
		_fail("Small h3maped generation state did not stop at the object-vector prerequisite boundary: %s" % JSON.stringify(small_state))
		return
	var player_phase: Dictionary = small_state.get("player_slot_assignment", {})
	if String(player_phase.get("h3maped_anchor", "")) != "0x4ac62a..0x4ac6ec" \
			or String(player_phase.get("status", "")) != "active_runtime_state_ready" \
			or String(player_phase.get("selected_color_bitmap_offset", "")) != "generator+0xed8" \
			or String(player_phase.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(player_phase.get("mapped_slots_offset", "")) != "generator+0xee4" \
			or int(player_phase.get("human_capable_source_owner_mask", -1)) != 15 \
			or int(player_phase.get("player_capable_source_owner_mask", -1)) != 15 \
			or Array(player_phase.get("human_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(player_phase.get("player_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(player_phase.get("raw_ee0_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(player_phase.get("mapped_ee4_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or int(player_phase.get("assigned_player_count", -1)) != 3 \
			or bool(player_phase.get("materializes_runtime_players", true)) \
			or bool(player_phase.get("materializes_public_output", true)):
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
	var runtime_zone_phase: Dictionary = small_state.get("runtime_zone_records", {})
	if String(runtime_zone_phase.get("h3maped_anchor", "")) != "0x4a218c" \
			or String(runtime_zone_phase.get("initializer_anchor", "")) != "0x49b452" \
			or String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready" \
			or String(runtime_zone_phase.get("runtime_zone_vector_begin_offset", "")) != "generator+0x10e0" \
			or String(runtime_zone_phase.get("runtime_zone_vector_end_offset", "")) != "generator+0x10e4" \
			or String(runtime_zone_phase.get("runtime_zone_vector_capacity_offset", "")) != "generator+0x10e8" \
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
			or bool(runtime_zone_phase.get("materializes_runtime_players", true)) \
			or bool(runtime_zone_phase.get("materializes_public_output", true)):
		_fail("h3maped runtime-zone phase drifted: %s" % JSON.stringify(runtime_zone_phase))
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
		_fail("h3maped runtime-zone records drifted: %s" % JSON.stringify(runtime_records))
		return

	var link_phase: Dictionary = small_state.get("link_seed_setup", {})
	var link_seeds: Array = link_phase.get("link_seeds", [])
	if String(link_phase.get("h3maped_anchor", "")) != "0x4a1f3b" \
			or String(link_phase.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(link_phase.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(link_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(link_phase.get("link_seed_count", -1)) != 5 \
			or link_seeds.size() != 5 \
			or int(link_seeds[0].get("source_zone_a", -1)) != 1 \
			or int(link_seeds[0].get("source_zone_b", -1)) != 4 \
			or int(link_seeds[0].get("runtime_zone_a", -1)) != 0 \
			or int(link_seeds[0].get("runtime_zone_b", -1)) != 3 \
			or int(link_seeds[0].get("guard_value", -1)) != 3000 \
			or int(link_seeds[3].get("guard_value", -1)) != 6000 \
			or bool(link_phase.get("materializes_connection_guards", true)) \
			or bool(link_phase.get("materializes_roads", true)) \
			or bool(link_phase.get("materializes_blockers", true)) \
			or bool(link_phase.get("materializes_public_output", true)):
		_fail("h3maped link-seed phase drifted: %s" % JSON.stringify(link_phase))
		return

	var coordinate_phase: Dictionary = small_state.get("coordinate_replay", {})
	var scaled_coordinates: Array = coordinate_phase.get("scaled_zone_coordinates", [])
	var bbox: Dictionary = coordinate_phase.get("bounding_box_rescale", {})
	if String(coordinate_phase.get("h3maped_anchor", "")) != "0x4a218c" \
			or String(coordinate_phase.get("link_endpoint_consumer_anchor", "")) != "0x4a1f3b" \
			or String(coordinate_phase.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(coordinate_phase.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(coordinate_phase.get("candidate_prune_anchor", "")) != "0x4a1ad8" \
			or String(coordinate_phase.get("bbox_rescale_anchor", "")) != "0x4a19ed" \
			or String(coordinate_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(coordinate_phase.get("placement_step_count", -1)) != 18 \
			or int(coordinate_phase.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18 \
			or int(coordinate_phase.get("town_choice_rng_calls_during_0x4a218c", -1)) != 4 \
			or int(coordinate_phase.get("total_interleaved_rng_calls_during_0x4a218c", -1)) != 22 \
			or int(coordinate_phase.get("rng_event_count", -1)) != 22 \
			or int(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", -1)) != 255755822 \
			or int(bbox.get("selected_span_before_rescale", -1)) != 84 \
			or scaled_coordinates.size() != 6 \
			or int(scaled_coordinates[0].get("x_after_bbox_rescale", -1)) != 23 \
			or int(scaled_coordinates[0].get("y_after_bbox_rescale", -1)) != 11 \
			or int(scaled_coordinates[1].get("x_after_bbox_rescale", -1)) != 21 \
			or int(scaled_coordinates[1].get("y_after_bbox_rescale", -1)) != 22 \
			or int(scaled_coordinates[2].get("x_after_bbox_rescale", -1)) != 12 \
			or int(scaled_coordinates[2].get("y_after_bbox_rescale", -1)) != 23 \
			or int(scaled_coordinates[3].get("x_after_bbox_rescale", -1)) != 18 \
			or int(scaled_coordinates[3].get("y_after_bbox_rescale", -1)) != 4 \
			or int(scaled_coordinates[4].get("x_after_bbox_rescale", -1)) != 18 \
			or int(scaled_coordinates[4].get("y_after_bbox_rescale", -1)) != 30 \
			or int(scaled_coordinates[5].get("x_after_bbox_rescale", -1)) != 12 \
			or int(scaled_coordinates[5].get("y_after_bbox_rescale", -1)) != 11 \
			or bool(coordinate_phase.get("materializes_zone_footprints", true)) \
			or bool(coordinate_phase.get("materializes_terrain", true)) \
			or bool(coordinate_phase.get("materializes_map_cells", true)) \
			or bool(coordinate_phase.get("materializes_public_output", true)):
		_fail("h3maped coordinate replay phase drifted: %s" % JSON.stringify(coordinate_phase))
		return

	var zone_footprint_phase: Dictionary = small_state.get("zone_footprint_phase_boundary", {})
	var per_level: Array = zone_footprint_phase.get("per_level", [])
	if String(zone_footprint_phase.get("phase_id", "")) != "zone_footprint_phase_boundary" \
			or String(zone_footprint_phase.get("h3maped_anchor", "")) != "0x4a3a03" \
			or String(zone_footprint_phase.get("helper_sequence", "")) != "0x4a2777 -> 0x4a325d -> 0x4a3710" \
			or String(zone_footprint_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(zone_footprint_phase.get("level_count", -1)) != 1 \
			or int(zone_footprint_phase.get("h3maped_water_mode_code", -1)) != 0 \
			or int(zone_footprint_phase.get("total_collected_runtime_zone_count", -1)) != 6 \
			or int(zone_footprint_phase.get("synthetic_zone_appended_count", -1)) != 0 \
			or per_level.size() != 1 \
			or int(per_level[0].get("collected_runtime_zone_count", -1)) != 6 \
			or Array(per_level[0].get("collected_runtime_zone_indices", [])) != [0, 1, 2, 3, 4, 5] \
			or int(per_level[0].get("helper_call_input_count", -1)) != 6 \
			or String(per_level[0].get("synthetic_zone_status", "")) != "not_applicable_small_one_level_land" \
			or bool(zone_footprint_phase.get("materializes_boundaries", true)) \
			or bool(zone_footprint_phase.get("materializes_span_fill", true)) \
			or bool(zone_footprint_phase.get("materializes_terrain", true)) \
			or bool(zone_footprint_phase.get("materializes_map_cells", true)) \
			or bool(zone_footprint_phase.get("materializes_public_output", true)):
		_fail("h3maped zone-footprint phase boundary drifted: %s" % JSON.stringify(zone_footprint_phase))
		return
	var helper_inputs: Array = per_level[0].get("helper_call_inputs", [])
	if helper_inputs.size() != 6 \
			or String(helper_inputs[0].get("helper_address", "")) != "0x4a2777" \
			or int(helper_inputs[0].get("runtime_zone_index", -1)) != 0 \
			or int(helper_inputs[5].get("runtime_zone_index", -1)) != 5:
		_fail("h3maped zone-footprint helper inputs drifted: %s" % JSON.stringify(helper_inputs))
		return

	var source_node_phase: Dictionary = small_state.get("source_node_rectangle", {})
	var source_node_bounds: Dictionary = source_node_phase.get("initial_bounds", {})
	var source_node_edges: Array = source_node_phase.get("initial_edges", [])
	if String(source_node_phase.get("phase_id", "")) != "source_node_rectangle" \
			or String(source_node_phase.get("h3maped_anchor", "")) != "0x4cc788" \
			or String(source_node_phase.get("node_constructor_anchor", "")) != "0x4cc955" \
			or String(source_node_phase.get("splitter_anchor", "")) != "0x4ccb64" \
			or String(source_node_phase.get("locator_anchor", "")) != "0x4cca55" \
			or String(source_node_phase.get("finalizer_anchor", "")) != "0x4ccdfc" \
			or String(source_node_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(source_node_bounds.get("min_x", 0)) != -200 \
			or int(source_node_bounds.get("min_y", 0)) != -200 \
			or int(source_node_bounds.get("max_x", 0)) != 400 \
			or int(source_node_bounds.get("max_y", 0)) != 400 \
			or String(source_node_bounds.get("constant_min_hex", "")) != "0xffffff38" \
			or String(source_node_bounds.get("constant_max_hex", "")) != "0x190" \
			or int(source_node_phase.get("initial_edge_count", -1)) != 4 \
			or source_node_edges.size() != 4 \
			or String(source_node_edges[0].get("id", "")) != "top" \
			or String(source_node_edges[3].get("next", "")) != "top" \
			or bool(source_node_phase.get("feeds_real_0x4a2777_boundary", true)) \
			or bool(source_node_phase.get("materializes_source_node_graph", true)) \
			or bool(source_node_phase.get("materializes_boundaries", true)) \
			or bool(source_node_phase.get("materializes_span_fill", true)) \
			or bool(source_node_phase.get("materializes_terrain", true)) \
			or bool(source_node_phase.get("materializes_map_cells", true)) \
			or bool(source_node_phase.get("materializes_public_output", true)):
		_fail("h3maped source-node rectangle phase drifted: %s" % JSON.stringify(source_node_phase))
		return

	var polygon_phase: Dictionary = small_state.get("polygon_split_model", {})
	var polygon_steps: Array = polygon_phase.get("split_steps", [])
	var finalized_steps: Array = polygon_phase.get("finalized_steps", [])
	var source_node_walks: Array = polygon_phase.get("source_node_walks", [])
	if String(polygon_phase.get("phase_id", "")) != "polygon_split_model" \
			or String(polygon_phase.get("h3maped_anchor", "")) != "0x4ccb64" \
			or String(polygon_phase.get("locator_anchor", "")) != "0x4cca55" \
			or String(polygon_phase.get("node_relink_anchor", "")) != "0x4cc643" \
			or String(polygon_phase.get("edge_side_test_anchor", "")) != "0x4cc6f2" \
			or String(polygon_phase.get("edge_erase_anchor", "")) != "0x4cc9cc" \
			or String(polygon_phase.get("bridge_anchor", "")) != "0x4ccb1f" \
			or String(polygon_phase.get("crossing_test_anchor", "")) != "0x4ccc7a" \
			or String(polygon_phase.get("crossing_collapse_anchor", "")) != "0x4cc68e" \
			or String(polygon_phase.get("intersection_writer_anchor", "")) != "0x4ccd69" \
			or String(polygon_phase.get("finalizer_anchor", "")) != "0x4ccdfc" \
			or String(polygon_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(polygon_phase.get("runtime_split_point_count", -1)) != 6 \
			or int(polygon_phase.get("executed_split_call_count", -1)) != 6 \
			or int(polygon_phase.get("duplicate_skip_count", -1)) != 0 \
			or int(polygon_phase.get("edge_removal_branch_count", -1)) != 0 \
			or int(polygon_phase.get("pre_crossing_inserted_node_pair_count", -1)) != 6 \
			or int(polygon_phase.get("pre_crossing_inserted_bridge_pair_count", -1)) != 12 \
			or int(polygon_phase.get("crossing_cleanup_scan_count", -1)) != 34 \
			or int(polygon_phase.get("crossing_test_count", -1)) != 24 \
			or int(polygon_phase.get("crossing_collapse_count", -1)) != 8 \
			or int(polygon_phase.get("initial_node_pair_count", -1)) != 5 \
			or int(polygon_phase.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(polygon_phase.get("post_crossing_cleanup_active_node_count", -1)) != 46 \
			or String(polygon_phase.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_crossing_cleanup_ported" \
			or String(polygon_phase.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_ported" \
			or int(polygon_phase.get("finalized_triplet_count", -1)) != 14 \
			or int(polygon_phase.get("finalized_node_count", -1)) != 42 \
			or int(polygon_phase.get("source_node_walk_count", -1)) != 6 \
			or int(polygon_phase.get("source_node_walk_guard_exhausted_count", -1)) != 0 \
			or String(polygon_phase.get("source_node_walk_status", "")) != "0x4cca55_to_0x4a2777_source_node_cycles_recovered_private_only" \
			or bool(polygon_phase.get("feeds_real_0x4a2777_boundary", true)) \
			or not bool(polygon_phase.get("materializes_source_node_graph", false)) \
			or bool(polygon_phase.get("materializes_boundaries", true)) \
			or bool(polygon_phase.get("materializes_span_fill", true)) \
			or bool(polygon_phase.get("materializes_terrain", true)) \
			or bool(polygon_phase.get("materializes_map_cells", true)) \
			or bool(polygon_phase.get("materializes_public_output", true)) \
			or String(polygon_phase.get("blocked_next", "")) != "source_node_boundary_traversal_0x4a2777" \
			or polygon_steps.size() != 6 \
			or finalized_steps.size() != 14 \
			or source_node_walks.size() != 6:
		_fail("h3maped polygon split/finalizer phase drifted: %s" % JSON.stringify(polygon_phase))
		return
	if String(polygon_steps[0].get("status", "")) != "0x4ccb64_pre_crossing_inserted" \
			or int(polygon_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(polygon_steps[0].get("bridge_pair_count", -1)) != 2 \
			or int(polygon_steps[5].get("runtime_zone_index", -1)) != 5 \
			or int(polygon_steps[5].get("bridge_pair_count", -1)) != 2:
		_fail("h3maped polygon split steps drifted: %s" % JSON.stringify(polygon_steps))
		return
	if int(source_node_walks[0].get("runtime_zone_index", -1)) != 0 \
			or int(source_node_walks[0].get("cycle_node_count", -1)) <= 0 \
			or int(source_node_walks[0].get("finalized_coordinate_count", -1)) <= 0 \
			or bool(source_node_walks[0].get("guard_exhausted", true)):
		_fail("h3maped source-node walks drifted: %s" % JSON.stringify(source_node_walks))
		return

	var boundary_phase: Dictionary = small_state.get("source_node_boundary_traversal", {})
	var boundary_zone_reports: Array = boundary_phase.get("zone_reports", [])
	if String(boundary_phase.get("phase_id", "")) != "source_node_boundary_traversal" \
			or String(boundary_phase.get("h3maped_anchor", "")) != "0x4a2777" \
			or String(boundary_phase.get("caller_anchor", "")) != "0x4a3e58..0x4a3e8c" \
			or String(boundary_phase.get("clip_helper_anchor", "")) != "0x4a2b33" \
			or String(boundary_phase.get("deterministic_line_writer_anchor", "")) != "0x4a261a" \
			or String(boundary_phase.get("flagged_line_writer_anchor", "")) != "0x4a2413" \
			or String(boundary_phase.get("runtime_vertex_vector_offset", "")) != "runtime_zone+0x3f4" \
			or String(boundary_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(boundary_phase.get("map_width", -1)) != 36 \
			or int(boundary_phase.get("map_height", -1)) != 36 \
			or int(boundary_phase.get("level_count", -1)) != 1 \
			or int(boundary_phase.get("h3maped_water_mode_code", -1)) != 0 \
			or int(boundary_phase.get("rng_state_before_0x4a2777_uint32", -1)) != 255755822 \
			or int(boundary_phase.get("runtime_zone_walk_count", -1)) != 6 \
			or int(boundary_phase.get("blocked_zone_count", -1)) != 0 \
			or int(boundary_phase.get("fallback_zone_count", -1)) != 0 \
			or int(boundary_phase.get("connector_segment_count", -1)) != 6 \
			or int(boundary_phase.get("wrap_segment_count", -1)) != 0 \
			or int(boundary_phase.get("final_segment_count", -1)) != 12 \
			or int(boundary_phase.get("appended_vertex_count", -1)) != 18 \
			or int(boundary_phase.get("skipped_unfinalized_node_count", -1)) != 0 \
			or int(boundary_phase.get("skipped_out_of_bounds_clip_count", -1)) != 12 \
			or int(boundary_phase.get("flagged_writer_segment_count", -1)) != 6 \
			or int(boundary_phase.get("deterministic_writer_segment_count", -1)) != 12 \
			or int(boundary_phase.get("randomized_rng_call_count", -1)) != 106 \
			or int(boundary_phase.get("randomized_inserted_midpoint_count", -1)) != 138 \
			or int(boundary_phase.get("rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(boundary_phase.get("trace_write_count", -1)) != 301 \
			or int(boundary_phase.get("unique_cell_count", -1)) != 238 \
			or int(boundary_phase.get("out_of_bounds_write_count", -1)) != 0 \
			or bool(boundary_phase.get("loop_guard_exhausted", true)) \
			or not bool(boundary_phase.get("materializes_boundaries", false)) \
			or bool(boundary_phase.get("materializes_span_fill", true)) \
			or bool(boundary_phase.get("materializes_terrain", true)) \
			or bool(boundary_phase.get("materializes_map_cells", true)) \
			or bool(boundary_phase.get("materializes_public_output", true)) \
			or String(boundary_phase.get("blocked_next", "")) != "span_fill_4a325d" \
			or boundary_zone_reports.size() != 6:
		_fail("h3maped source-node boundary traversal drifted: %s" % JSON.stringify(boundary_phase))
		return
	if int(boundary_zone_reports[0].get("runtime_zone_index", -1)) != 0 \
			or String(boundary_zone_reports[0].get("status", "")) != "0x4a2777_real_source_cycle_consumed" \
			or int(boundary_zone_reports[0].get("segment_count", -1)) != 3 \
			or int(boundary_zone_reports[5].get("runtime_zone_index", -1)) != 5 \
			or int(boundary_zone_reports[5].get("segment_count", -1)) != 4:
		_fail("h3maped boundary zone reports drifted: %s" % JSON.stringify(boundary_zone_reports))
		return

	var span_fill_phase: Dictionary = small_state.get("span_fill_4a325d", {})
	var span_fill_zone_reports: Array = span_fill_phase.get("zone_fill_reports", [])
	var cells_by_zone_word: Dictionary = span_fill_phase.get("cells_by_zone_word", {})
	if String(span_fill_phase.get("phase_id", "")) != "span_fill_4a325d" \
			or String(span_fill_phase.get("h3maped_anchor", "")) != "0x4a325d" \
			or String(span_fill_phase.get("boundary_source_anchor", "")) != "0x4a2777" \
			or String(span_fill_phase.get("seed_source", "")) != "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale" \
			or String(span_fill_phase.get("status", "")) != "active_runtime_state_ready" \
			or not bool(span_fill_phase.get("uses_real_0x4a2777_boundary", false)) \
			or int(span_fill_phase.get("map_width", -1)) != 36 \
			or int(span_fill_phase.get("map_height", -1)) != 36 \
			or int(span_fill_phase.get("level_count", -1)) != 1 \
			or int(span_fill_phase.get("h3maped_water_mode_code", -1)) != 0 \
			or int(span_fill_phase.get("boundary_unique_cell_count", -1)) != 238 \
			or int(span_fill_phase.get("boundary_trace_write_count", -1)) != 301 \
			or int(span_fill_phase.get("boundary_rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(span_fill_phase.get("runtime_zone_fill_attempt_count", -1)) != 6 \
			or int(span_fill_phase.get("filled_zone_count", -1)) != 6 \
			or int(span_fill_phase.get("seed_blocked_count", -1)) != 1 \
			or int(span_fill_phase.get("missing_seed_count", -1)) != 0 \
			or int(span_fill_phase.get("seed_relocation_count", -1)) != 0 \
			or int(span_fill_phase.get("unique_filled_cell_count", -1)) != 869 \
			or int(span_fill_phase.get("total_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(span_fill_phase.get("remaining_unassigned_cell_count", -1)) != 189 \
			or int(span_fill_phase.get("reserved_flag_cell_count", -1)) != 1107 \
			or int(span_fill_phase.get("pushed_span_count", -1)) != 93 \
			or int(span_fill_phase.get("popped_span_count", -1)) != 93 \
			or int(span_fill_phase.get("max_pending_span_count", -1)) != 3 \
			or int(span_fill_phase.get("out_of_bounds_span_count", -1)) != 0 \
			or int(span_fill_phase.get("blocked_initial_span_count", -1)) != 1 \
			or int(cells_by_zone_word.get("0", -1)) != 177 \
			or int(cells_by_zone_word.get("1", -1)) != 91 \
			or int(cells_by_zone_word.get("2", -1)) != 226 \
			or int(cells_by_zone_word.get("3", -1)) != 177 \
			or int(cells_by_zone_word.get("4", -1)) != 207 \
			or int(cells_by_zone_word.get("5", -1)) != 229 \
			or not bool(span_fill_phase.get("materializes_span_fill", false)) \
			or bool(span_fill_phase.get("materializes_terrain", true)) \
			or bool(span_fill_phase.get("materializes_map_cells", true)) \
			or bool(span_fill_phase.get("materializes_runtime_players", true)) \
			or bool(span_fill_phase.get("materializes_package_tiles", true)) \
			or bool(span_fill_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(span_fill_phase.get("public_package_output_allowed", true)) \
			or String(span_fill_phase.get("blocked_next", "")) != "footprint_finalizer_4a3710" \
			or span_fill_zone_reports.size() != 6:
		_fail("h3maped span-fill phase drifted: %s" % JSON.stringify(span_fill_phase))
		return
	if int(span_fill_zone_reports[0].get("runtime_zone_index", -1)) != 0 \
			or int(span_fill_zone_reports[0].get("filled_cell_count", -1)) != 151 \
			or int(span_fill_zone_reports[2].get("runtime_zone_index", -1)) != 2 \
			or bool(span_fill_zone_reports[2].get("seed_unassigned_before_fill", true)) \
			or int(span_fill_zone_reports[5].get("filled_cell_count", -1)) != 185:
		_fail("h3maped span-fill zone reports drifted: %s" % JSON.stringify(span_fill_zone_reports))
		return

	var footprint_phase: Dictionary = small_state.get("footprint_finalizer_4a3710", {})
	var footprint_subphases: Array = footprint_phase.get("phases", [])
	if String(footprint_phase.get("phase_id", "")) != "footprint_finalizer_4a3710" \
			or String(footprint_phase.get("h3maped_anchor", "")) != "0x4a3710" \
			or String(footprint_phase.get("call_site_anchor", "")) != "0x4a3efc..0x4a3f05" \
			or String(footprint_phase.get("polygon_locator_anchor", "")) != "0x4cca55" \
			or String(footprint_phase.get("clip_helper_anchor", "")) != "0x4a2b33" \
			or String(footprint_phase.get("zone_order_reset_anchor", "")) != "0x49b61b" \
			or String(footprint_phase.get("per_zone_order_helper_anchor", "")) != "0x4a3554" \
			or String(footprint_phase.get("adjacency_vector_offset", "")) != "runtime_zone+0xc4" \
			or String(footprint_phase.get("ordering_vector_offset", "")) != "runtime_zone+0x3e8" \
			or String(footprint_phase.get("status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported_private" \
			or int(footprint_phase.get("level_count", -1)) != 1 \
			or int(footprint_phase.get("h3maped_water_mode_code", -1)) != 0 \
			or bool(footprint_phase.get("synthetic_branch_allowed_by_0x4a3a9d", true)) \
			or int(footprint_phase.get("original_same_level_runtime_zone_count", -1)) != 6 \
			or int(footprint_phase.get("final_runtime_zone_count", -1)) != 6 \
			or int(footprint_phase.get("appended_runtime_zone_count", -1)) != 0 \
			or int(footprint_phase.get("zone_order_reset_call_count", -1)) != 6 \
			or int(footprint_phase.get("per_zone_order_helper_call_count", -1)) != 6 \
			or int(footprint_phase.get("materialized_adjacency_count", -1)) != 0 \
			or bool(footprint_phase.get("materializes_zone_cells", true)) \
			or bool(footprint_phase.get("materializes_boundary_cells", true)) \
			or bool(footprint_phase.get("materializes_span_fill", true)) \
			or bool(footprint_phase.get("materializes_terrain", true)) \
			or bool(footprint_phase.get("materializes_map_cells", true)) \
			or bool(footprint_phase.get("materializes_runtime_players", true)) \
			or bool(footprint_phase.get("materializes_package_tiles", true)) \
			or bool(footprint_phase.get("public_package_output_allowed", true)) \
			or String(footprint_phase.get("blocked_next", "")) != "runtime_terrain_selection_49b53d" \
			or footprint_subphases.size() != 3:
		_fail("h3maped footprint finalizer phase drifted: %s" % JSON.stringify(footprint_phase))
		return
	if String(footprint_subphases[0].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or int(footprint_subphases[0].get("start_index", -1)) != 6 \
			or int(footprint_subphases[0].get("end_index", -1)) != 6 \
			or int(footprint_subphases[0].get("materialized_adjacency_insert_count", -1)) != 0 \
			or String(footprint_subphases[1].get("status", "")) != "0x49b61b_reset_and_0x4a3554_rebuild_scheduled" \
			or int(footprint_subphases[1].get("zone_order_reset_call_count", -1)) != 6 \
			or int(footprint_subphases[1].get("per_zone_order_helper_call_count", -1)) != 6 \
			or String(footprint_subphases[2].get("status", "")) != "skipped_no_appended_runtime_zones":
		_fail("h3maped footprint finalizer subphases drifted: %s" % JSON.stringify(footprint_subphases))
		return

	var terrain_phase: Dictionary = small_state.get("runtime_terrain_selection_49b53d", {})
	var terrain_selections: Array = terrain_phase.get("selections", [])
	if String(terrain_phase.get("phase_id", "")) != "runtime_terrain_selection_49b53d" \
			or String(terrain_phase.get("h3maped_anchor", "")) != "0x49b53d" \
			or String(terrain_phase.get("town_to_terrain_table_address", "")) != "0x540908" \
			or String(terrain_phase.get("allowed_terrain_flags_source", "")) != "source_zone+0x85..0x8c" \
			or int(terrain_phase.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or String(terrain_phase.get("status", "")) != "active_runtime_state_ready" \
			or Array(terrain_phase.get("town_choice_to_terrain_table", [])) != [2, 2, 3, 7, 0, 0, 5, 4, 2] \
			or int(terrain_phase.get("selection_count", -1)) != 6 \
			or Array(terrain_phase.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(terrain_phase.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(terrain_phase.get("match_to_town_count", -1)) != 4 \
			or int(terrain_phase.get("allowed_flag_choice_count", -1)) != 2 \
			or int(terrain_phase.get("blank_allowed_mask_count", -1)) != 0 \
			or int(terrain_phase.get("forced_subterranean_count", -1)) != 0 \
			or int(terrain_phase.get("rng_call_count", -1)) != 2 \
			or int(terrain_phase.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160 \
			or bool(terrain_phase.get("materializes_terrain_cells", true)) \
			or bool(terrain_phase.get("materializes_terrain_art", true)) \
			or bool(terrain_phase.get("materializes_map_cells", true)) \
			or bool(terrain_phase.get("materializes_runtime_players", true)) \
			or bool(terrain_phase.get("materializes_package_tiles", true)) \
			or bool(terrain_phase.get("public_package_output_allowed", true)) \
			or String(terrain_phase.get("blocked_next", "")) != "terrain_cell_writeout_4a3f27" \
			or terrain_selections.size() != 6:
		_fail("h3maped runtime terrain selection drifted: %s" % JSON.stringify(terrain_phase))
		return
	if String(terrain_selections[0].get("faction_id", "")) != "elemental" \
			or int(terrain_selections[0].get("town_choice_index", -1)) != 8 \
			or int(terrain_selections[0].get("selected_h3maped_terrain_id", -1)) != 2 \
			or int(terrain_selections[2].get("rng_value", -1)) != 153 \
			or int(terrain_selections[2].get("selected_allowed_ordinal", -1)) != 6 \
			or int(terrain_selections[2].get("selected_h3maped_terrain_id", -1)) != 7 \
			or String(terrain_selections[4].get("faction_id", "")) != "fortress" \
			or int(terrain_selections[5].get("rng_value", -1)) != 292 \
			or int(terrain_selections[5].get("selected_h3maped_terrain_id", -1)) != 5:
		_fail("h3maped runtime terrain selections drifted: %s" % JSON.stringify(terrain_selections))
		return

	var terrain_cell_phase: Dictionary = small_state.get("terrain_cell_writeout_4a3f27", {})
	var owner_low_counts: Dictionary = terrain_cell_phase.get("owner_low_byte_counts", {})
	var terrain_name_counts: Dictionary = terrain_cell_phase.get("terrain_name_counts", {})
	var terrain_code_counts: Dictionary = terrain_cell_phase.get("h3_terrain_code_counts", {})
	var terrain_schedule: Dictionary = terrain_cell_phase.get("terrain_repaint_schedule", {})
	var repaint_code_counts: Dictionary = terrain_schedule.get("repaint_cells_by_terrain_code", {})
	var per_zone_repaint_records: Array = terrain_schedule.get("per_zone_repaint_records", [])
	if String(terrain_cell_phase.get("phase_id", "")) != "terrain_cell_writeout_4a3f27" \
			or String(terrain_cell_phase.get("h3maped_anchor", "")) != "0x4a3f27" \
			or String(terrain_cell_phase.get("full_map_water_repaint_address", "")) != "0x4a4025" \
			or String(terrain_cell_phase.get("per_zone_repaint_loop_address", "")) != "0x4a4082" \
			or String(terrain_cell_phase.get("per_cell_repaint_call_address", "")) != "0x4a415a" \
			or String(terrain_cell_phase.get("owner_byte_gate_address", "")) != "0x4a4142" \
			or String(terrain_cell_phase.get("reserved_flag_gate_address", "")) != "0x4a4150" \
			or String(terrain_cell_phase.get("span_fill_source_address", "")) != "0x4a325d" \
			or String(terrain_cell_phase.get("tile_serializer_address", "")) != "0x49b2b6" \
			or String(terrain_cell_phase.get("status", "")) != "active_runtime_state_ready" \
			or int(terrain_cell_phase.get("map_width", -1)) != 36 \
			or int(terrain_cell_phase.get("map_height", -1)) != 36 \
			or int(terrain_cell_phase.get("level_count", -1)) != 1 \
			or int(terrain_cell_phase.get("cell_count", -1)) != 1296 \
			or int(terrain_cell_phase.get("span_fill_total_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(terrain_cell_phase.get("span_fill_remaining_unassigned_cell_count", -1)) != 189 \
			or int(terrain_cell_phase.get("span_fill_reserved_flag_cell_count", -1)) != 1107 \
			or int(terrain_cell_phase.get("owner_low_byte_materialized_count", -1)) != 1107 \
			or int(owner_low_counts.get("0", -1)) != 177 \
			or int(owner_low_counts.get("1", -1)) != 91 \
			or int(owner_low_counts.get("2", -1)) != 226 \
			or int(owner_low_counts.get("3", -1)) != 177 \
			or int(owner_low_counts.get("4", -1)) != 207 \
			or int(owner_low_counts.get("5", -1)) != 229 \
			or int(terrain_cell_phase.get("tile_byte_zero_terrain_cell_count", -1)) != 1296 \
			or int(terrain_cell_phase.get("tile_byte_zero_non_water_terrain_cell_count", -1)) != 1107 \
			or int(terrain_cell_phase.get("tile_byte_one_nonzero_art_cell_count", -1)) != 0 \
			or int(terrain_cell_phase.get("tile_byte_six_terrain_flip_cell_count", -1)) != 0 \
			or int(terrain_cell_phase.get("reserved_flag_cell_count", -1)) != 1107 \
			or int(terrain_cell_phase.get("unassigned_water_cell_count", -1)) != 189 \
			or int(terrain_name_counts.get("water", -1)) != 189 \
			or int(terrain_name_counts.get("grass", -1)) != 177 \
			or int(terrain_name_counts.get("dirt", -1)) != 91 \
			or int(terrain_name_counts.get("lava", -1)) != 403 \
			or int(terrain_name_counts.get("swamp", -1)) != 207 \
			or int(terrain_name_counts.get("rough", -1)) != 229 \
			or int(terrain_code_counts.get("8", -1)) != 189 \
			or int(terrain_code_counts.get("2", -1)) != 177 \
			or int(terrain_code_counts.get("0", -1)) != 91 \
			or int(terrain_code_counts.get("7", -1)) != 403 \
			or int(terrain_code_counts.get("4", -1)) != 207 \
			or int(terrain_code_counts.get("5", -1)) != 229 \
			or not bool(terrain_cell_phase.get("materializes_private_generated_cell_words", false)) \
			or bool(terrain_cell_phase.get("materializes_terrain_art", true)) \
			or bool(terrain_cell_phase.get("materializes_roads", true)) \
			or bool(terrain_cell_phase.get("materializes_objects", true)) \
			or bool(terrain_cell_phase.get("materializes_package_tiles", true)) \
			or bool(terrain_cell_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrain_cell_phase.get("public_package_output_allowed", true)) \
			or String(terrain_cell_phase.get("tile_byte_writeout_status", "")) != "0x49b2b6_terrain_id_byte_packed_art_flip_pending" \
			or String(terrain_cell_phase.get("blocked_next", "")) != "terrainplacement_visual_tables_4bcff5":
		_fail("h3maped terrain cell writeout drifted: %s" % JSON.stringify(terrain_cell_phase))
		return
	if String(terrain_schedule.get("status", "")) != "0x4a3f27_water_then_zone_single_cell_repaint_schedule_ported_private" \
			or int(terrain_schedule.get("initial_water_terrain_id", -1)) != 8 \
			or int(terrain_schedule.get("initial_water_full_map_cell_count", -1)) != 1296 \
			or bool(terrain_schedule.get("two_level_rock_prefill_executed", true)) \
			or int(terrain_schedule.get("single_cell_repaint_count", -1)) != 1107 \
			or int(repaint_code_counts.get("2", -1)) != 177 \
			or int(repaint_code_counts.get("0", -1)) != 91 \
			or int(repaint_code_counts.get("7", -1)) != 403 \
			or int(repaint_code_counts.get("4", -1)) != 207 \
			or int(repaint_code_counts.get("5", -1)) != 229 \
			or bool(terrain_schedule.get("materializes_visual_art", true)) \
			or per_zone_repaint_records.size() != 6:
		_fail("h3maped terrain repaint schedule drifted: %s" % JSON.stringify(terrain_schedule))
		return
	if int(per_zone_repaint_records[0].get("single_cell_repaint_count", -1)) != 177 \
			or int(per_zone_repaint_records[1].get("single_cell_repaint_count", -1)) != 91 \
			or int(per_zone_repaint_records[2].get("single_cell_repaint_count", -1)) != 226 \
			or int(per_zone_repaint_records[3].get("single_cell_repaint_count", -1)) != 177 \
			or int(per_zone_repaint_records[4].get("single_cell_repaint_count", -1)) != 207 \
			or int(per_zone_repaint_records[5].get("single_cell_repaint_count", -1)) != 229:
		_fail("h3maped terrain repaint records drifted: %s" % JSON.stringify(per_zone_repaint_records))
		return

	var visual_tables_phase: Dictionary = small_state.get("terrainplacement_visual_tables_4bcff5", {})
	var visual_tables: Array = visual_tables_phase.get("tables", [])
	var toolkit_records: Array = visual_tables_phase.get("toolkit_constructor_records", [])
	var visual_samples: Array = visual_tables_phase.get("visual_row_selection_samples", [])
	var scratch_samples: Array = visual_tables_phase.get("scratch_write_samples", [])
	if String(visual_tables_phase.get("phase_id", "")) != "terrainplacement_visual_tables_4bcff5" \
			or String(visual_tables_phase.get("h3maped_anchor", "")) != "0x4bcff5" \
			or String(visual_tables_phase.get("terrainplacement_constructor_address", "")) != "0x4bb5ce" \
			or String(visual_tables_phase.get("terrainplacement_wrapper_address", "")) != "0x4bd099" \
			or String(visual_tables_phase.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or String(visual_tables_phase.get("queue_drain_address", "")) != "0x4bc5f0" \
			or String(visual_tables_phase.get("visual_selector_address", "")) != "0x4bcfc3" \
			or String(visual_tables_phase.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(visual_tables_phase.get("toolkit_table_address", "")) != "0x5436b8" \
			or String(visual_tables_phase.get("complex_toolkit_vtable_address", "")) != "0x543780" \
			or String(visual_tables_phase.get("simple_toolkit_vtable_address", "")) != "0x54379c" \
			or String(visual_tables_phase.get("complex_visual_resolve_vfunc_plus_0x10", "")) != "0x4ba938" \
			or String(visual_tables_phase.get("complex_visual_writeback_vfunc_plus_0x14", "")) != "0x4ba989" \
			or String(visual_tables_phase.get("simple_visual_resolve_vfunc_plus_0x10", "")) != "0x4baa94" \
			or String(visual_tables_phase.get("simple_visual_writeback_vfunc_plus_0x14", "")) != "0x4baabf" \
			or String(visual_tables_phase.get("status", "")) != "active_runtime_state_ready" \
			or bool(visual_tables_phase.get("terrain_art_hash_fallback_allowed", true)) \
			or bool(visual_tables_phase.get("materializes_visual_record", true)) \
			or bool(visual_tables_phase.get("materializes_full_terrain_art_grid", true)) \
			or bool(visual_tables_phase.get("materializes_package_tiles", true)) \
			or bool(visual_tables_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(visual_tables_phase.get("public_package_output_allowed", true)) \
			or int(visual_tables_phase.get("table_count", -1)) != 5 \
			or int(visual_tables_phase.get("decoded_total_row_count", -1)) != 230 \
			or int(visual_tables_phase.get("expected_total_row_count", -1)) != 230 \
			or int(visual_tables_phase.get("toolkit_constructor_record_count", -1)) != 10 \
			or int(visual_tables_phase.get("visual_row_selection_sample_count", -1)) != 4 \
			or String(visual_tables_phase.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(visual_tables_phase.get("generated_cell_write_address", "")) != "0x49acf6" \
			or int(visual_tables_phase.get("scratch_write_sample_count", -1)) != 4 \
			or String(visual_tables_phase.get("blocked_next", "")) != "live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback" \
			or visual_tables.size() != 5 \
			or toolkit_records.size() != 10 \
			or visual_samples.size() != 4 \
			or scratch_samples.size() != 4:
		_fail("h3maped TerrainPlacement visual table boundary drifted: %s" % JSON.stringify(visual_tables_phase))
		return
	if String(visual_tables[0].get("table_address", "")) != "0x543108" \
			or int(visual_tables[0].get("decoded_row_count", -1)) != 79 \
			or String(visual_tables[1].get("table_address", "")) != "0x543380" \
			or int(visual_tables[1].get("decoded_row_count", -1)) != 46 \
			or String(visual_tables[2].get("table_address", "")) != "0x5434f0" \
			or int(visual_tables[2].get("decoded_row_count", -1)) != 24 \
			or String(visual_tables[3].get("table_address", "")) != "0x5435b0" \
			or int(visual_tables[3].get("decoded_row_count", -1)) != 33 \
			or String(visual_tables[4].get("table_address", "")) != "0x542f88" \
			or int(visual_tables[4].get("decoded_row_count", -1)) != 48:
		_fail("h3maped TerrainPlacement visual table rows drifted: %s" % JSON.stringify(visual_tables))
		return
	if int(toolkit_records[0].get("terrain_id", -1)) != 0 \
			or int(toolkit_records[0].get("range_probability", -1)) != 0x32 \
			or String(toolkit_records[0].get("table_address", "")) != "0x543380" \
			or int(toolkit_records[8].get("terrain_id", -1)) != 8 \
			or String(toolkit_records[8].get("table_address", "")) != "0x5435b0" \
			or int(toolkit_records[9].get("terrain_id", -1)) != 9 \
			or String(toolkit_records[9].get("constructor_address", "")) != "0x4baa66":
		_fail("h3maped TerrainPlacement toolkit records drifted: %s" % JSON.stringify(toolkit_records))
		return
	if int(visual_samples[0].get("selected_row", -1)) != 60 \
			or int(visual_samples[1].get("selected_row", -1)) != 77 \
			or int(visual_samples[2].get("selected_row", -1)) != 20 \
			or int(visual_samples[3].get("selected_row", -1)) != 11:
		_fail("h3maped TerrainPlacement visual row samples drifted: %s" % JSON.stringify(visual_samples))
		return
	if int(scratch_samples[0].get("scratch_word_u16", -1)) != 1925 \
			or int(scratch_samples[0].get("generated_cell_word_0x24_u32", -1)) != 3842 \
			or int(scratch_samples[1].get("scratch_word_u16", -1)) != 6565 \
			or int(scratch_samples[1].get("generated_cell_word_0x24_u32", -1)) != 4930 \
			or int(scratch_samples[1].get("generated_cell_word_0x28_u32", -1)) != 32768 \
			or int(scratch_samples[2].get("scratch_word_u16", -1)) != 657 \
			or int(scratch_samples[3].get("scratch_word_u16", -1)) != 371:
		_fail("h3maped TerrainPlacement scratch samples drifted: %s" % JSON.stringify(scratch_samples))
		return

	var live_feedback_phase: Dictionary = small_state.get("terrainplacement_live_feedback_4bb74b_4bc5f0", {})
	var live_selector_histogram: Dictionary = live_feedback_phase.get("selector_kind_histogram", {})
	var live_neighbor_histogram: Dictionary = live_feedback_phase.get("neighbor_mask_histogram", {})
	var live_seed_samples: Array = live_feedback_phase.get("seed_samples", [])
	var live_drain_samples: Array = live_feedback_phase.get("drain_samples", [])
	var live_sample_records: Array = live_feedback_phase.get("sample_records", [])
	if String(live_feedback_phase.get("phase_id", "")) != "terrainplacement_live_feedback_4bb74b_4bc5f0" \
			or String(live_feedback_phase.get("h3maped_anchor", "")) != "0x4bb74b/0x4bc5f0" \
			or String(live_feedback_phase.get("full_water_repaint_address", "")) != "0x4a4025" \
			or String(live_feedback_phase.get("zone_repaint_loop_address", "")) != "0x4a4082" \
			or String(live_feedback_phase.get("single_cell_repaint_address", "")) != "0x4a415a" \
			or String(live_feedback_phase.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or String(live_feedback_phase.get("neighbor_seed_address", "")) != "0x4bba59" \
			or String(live_feedback_phase.get("frontier_retouch_address", "")) != "0x4bbd01" \
			or String(live_feedback_phase.get("queue_drain_address", "")) != "0x4bc5f0" \
			or String(live_feedback_phase.get("candidate_gate_address", "")) != "0x4bc988" \
			or String(live_feedback_phase.get("visual_selector_address", "")) != "0x4bcfc3" \
			or String(live_feedback_phase.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(live_feedback_phase.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(live_feedback_phase.get("generated_cell_write_address", "")) != "0x49acf6" \
			or String(live_feedback_phase.get("status", "")) != "active_runtime_state_ready" \
			or not bool(live_feedback_phase.get("visual_tables_decoded", false)) \
			or not bool(live_feedback_phase.get("uses_live_scratch_neighbor_mask", false)) \
			or not bool(live_feedback_phase.get("materializes_private_generated_cell_words", false)) \
			or bool(live_feedback_phase.get("materializes_package_tiles", true)) \
			or bool(live_feedback_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(live_feedback_phase.get("public_package_output_allowed", true)) \
			or not bool(live_feedback_phase.get("exact_queue_drain_complete", false)) \
			or not bool(live_feedback_phase.get("live_feedback_materialized", false)) \
			or int(live_feedback_phase.get("tile_count", -1)) != 1296 \
			or int(live_feedback_phase.get("live_visual_attempt_count", -1)) != 2845 \
			or int(live_feedback_phase.get("live_visual_write_count", -1)) != 2845 \
			or int(live_feedback_phase.get("live_visual_missing_bucket_count", -1)) != 0 \
			or int(live_feedback_phase.get("live_initial_water_attempt_count", -1)) != 1296 \
			or int(live_feedback_phase.get("live_repaint_attempt_count", -1)) != 942 \
			or int(live_feedback_phase.get("live_queue_attempt_count", -1)) != 607 \
			or int(live_feedback_phase.get("live_dirty_cell_count", -1)) != 1296 \
			or int(live_feedback_phase.get("live_roundtrip_mismatch_count", -1)) != 0 \
			or int(live_feedback_phase.get("live_terrain_mismatch_count", -1)) != 0 \
			or int(live_feedback_phase.get("live_full_native_cell_count", -1)) != 1326 \
			or int(live_feedback_phase.get("live_terrain_art_nonzero_cell_count", -1)) <= 0 \
			or int(live_feedback_phase.get("live_terrain_flag_cell_count", -1)) <= 0 \
			or int(live_feedback_phase.get("post_queue_terrain_difference_count", -1)) != 181 \
			or int(live_feedback_phase.get("set_a_drain_count", -1)) != 176 \
			or int(live_feedback_phase.get("set_b_drain_count", -1)) != 10522 \
			or int(live_feedback_phase.get("set_b_candidate_true_count", -1)) != 386 \
			or int(live_feedback_phase.get("retouched_cell_write_count", -1)) != 221 \
			or int(live_feedback_phase.get("drain_guard_limit", -1)) != 32768 \
			or bool(live_feedback_phase.get("drain_guard_exhausted", true)) \
			or String(live_feedback_phase.get("blocked_next", "")) != "private_0x49b2b6_tile_byte_writeback_candidate":
		_fail("h3maped TerrainPlacement live feedback boundary drifted: %s" % JSON.stringify(live_feedback_phase))
		return
	if int(live_selector_histogram.get("full_native_special_frequency_masked_by_0x4bce6d", -1)) != 1326 \
			or int(live_selector_histogram.get("transition_class_bucket", -1)) != 1519 \
			or int(live_neighbor_histogram.get("1", 0)) <= 0 \
			or int(live_neighbor_histogram.get("2", 0)) <= 0 \
			or int(live_neighbor_histogram.get("4", 0)) <= 0 \
			or live_seed_samples.size() != 12 \
			or live_drain_samples.size() != 24 \
			or live_sample_records.size() != 16:
		_fail("h3maped TerrainPlacement live feedback samples drifted: %s" % JSON.stringify(live_feedback_phase))
		return

	var tile_writeback_phase: Dictionary = small_state.get("terrain_tile_byte_writeback_49b2b6", {})
	var terrain_byte_histogram: Dictionary = tile_writeback_phase.get("tile_byte_0_histogram", {})
	var art_byte_histogram: Dictionary = tile_writeback_phase.get("tile_byte_1_art_histogram", {})
	var flag_byte_histogram: Dictionary = tile_writeback_phase.get("tile_byte_6_flag_histogram", {})
	var sample_tile_records: Array = tile_writeback_phase.get("sample_tile_byte_records", [])
	if String(tile_writeback_phase.get("phase_id", "")) != "terrain_tile_byte_writeback_49b2b6" \
			or String(tile_writeback_phase.get("h3maped_anchor", "")) != "0x49b2b6" \
			or String(tile_writeback_phase.get("generated_cell_write_address", "")) != "0x49acf6" \
			or String(tile_writeback_phase.get("status", "")) != "active_runtime_state_ready" \
			or not bool(tile_writeback_phase.get("materializes_private_tile_byte_candidates", false)) \
			or bool(tile_writeback_phase.get("materializes_package_tiles", true)) \
			or bool(tile_writeback_phase.get("project_grid_public_runtime_adoption", true)) \
			or bool(tile_writeback_phase.get("public_package_output_allowed", true)) \
			or bool(tile_writeback_phase.get("road_river_bytes_materialized", true)) \
			or bool(tile_writeback_phase.get("object_bytes_materialized", true)) \
			or int(tile_writeback_phase.get("tile_count", -1)) != 1296 \
			or int(tile_writeback_phase.get("terrain_byte_candidate_count", -1)) != 1296 \
			or int(tile_writeback_phase.get("terrain_byte_mismatch_count", -1)) != 0 \
			or int(tile_writeback_phase.get("terrain_art_nonzero_cell_count", -1)) <= 0 \
			or int(tile_writeback_phase.get("terrain_flag_nonzero_cell_count", -1)) <= 0 \
			or int(tile_writeback_phase.get("road_river_nonzero_byte_count", -1)) != 0 \
			or int(tile_writeback_phase.get("sample_tile_byte_record_count", -1)) != 16 \
			or sample_tile_records.size() != 16 \
			or int(terrain_byte_histogram.get("8", 0)) <= 0 \
			or int(art_byte_histogram.get("0", -1)) < 0 \
			or int(flag_byte_histogram.get("0", -1)) < 0 \
			or String(tile_writeback_phase.get("blocked_next", "")) != "town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2":
		_fail("h3maped terrain tile-byte writeback boundary drifted: %s" % JSON.stringify(tile_writeback_phase))
		return

	var town_phase: Dictionary = small_state.get("town_castle_phase_4a8d2c", {})
	var direct_stamping: Dictionary = town_phase.get("direct_stamping_projection", {})
	var town_candidate: Dictionary = town_phase.get("project_town_adoption_candidate", {})
	var town_records: Array = town_candidate.get("town_records", [])
	var player_starts: Array = town_candidate.get("player_starts", [])
	if String(town_phase.get("phase_id", "")) != "town_castle_phase_4a8d2c" \
			or String(town_phase.get("h3maped_anchor", "")) != "0x4a8d2c/0x4a8db2/0x4a93a2" \
			or String(town_phase.get("direct_object_helper_anchor", "")) != "0x4a93a2" \
			or String(town_phase.get("candidate_gate_anchor", "")) != "0x49aa93" \
			or String(town_phase.get("footprint_gate_anchor", "")) != "0x49a09c" \
			or String(town_phase.get("object_record_constructor_anchor", "")) != "0x49ba89" \
			or String(town_phase.get("town_vtable_anchor", "")) != "0x540a9c" \
			or String(town_phase.get("status", "")) != "active_runtime_state_ready" \
			or not bool(town_phase.get("materializes_private_town_candidates", false)) \
			or bool(town_phase.get("materializes_town_objects", true)) \
			or bool(town_phase.get("materializes_package_tiles", true)) \
			or bool(town_phase.get("adopts_into_runtime_grid", true)) \
			or bool(town_phase.get("public_package_output_allowed", true)) \
			or int(town_phase.get("source_player_min_castle_count", -1)) != 4 \
			or int(town_phase.get("assigned_player_min_castle_count", -1)) != 3 \
			or int(town_phase.get("skipped_unassigned_player_start_min_castle_count", -1)) != 1 \
			or int(town_phase.get("scheduled_direct_minimum_object_count", -1)) != 3 \
			or int(town_phase.get("scheduled_owned_player_town_count", -1)) != 3 \
			or Array(town_phase.get("scheduled_owner_colors", [])) != [0, 1, 2] \
			or int(town_phase.get("project_town_record_candidate_count", -1)) != 3 \
			or int(town_phase.get("project_player_start_candidate_count", -1)) != 3 \
			or String(town_phase.get("project_town_adoption_candidate_status", "")) != "h3maped_project_town_adoption_candidate_private" \
			or String(town_phase.get("blocked_next", "")) != "roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243":
		_fail("h3maped town/castle phase boundary drifted: %s" % JSON.stringify(town_phase))
		return
	if String(direct_stamping.get("status", "")) != "0x4a93a2_0x49ba89_direct_town_object_stamping_projection_private" \
			or int(direct_stamping.get("direct_candidate_scan_count", -1)) != 3 \
			or int(direct_stamping.get("direct_candidate_total", -1)) != 445 \
			or int(direct_stamping.get("direct_footprint_eligible_total", -1)) != 85 \
			or int(direct_stamping.get("direct_record_projection_count", -1)) != 3 \
			or int(direct_stamping.get("direct_unique_selection_count", -1)) != 2 \
			or int(direct_stamping.get("direct_random_tie_selection_count", -1)) != 1 \
			or int(direct_stamping.get("direct_random_tie_rng_call_count", -1)) != 1 \
			or int(direct_stamping.get("direct_footprint_marked_cell_count", -1)) != 39 \
			or bool(direct_stamping.get("runtime_package_adoption", true)) \
			or bool(direct_stamping.get("stamps_generated_cell_state", true)):
		_fail("h3maped direct town stamping projection drifted: %s" % JSON.stringify(direct_stamping))
		return
	if String(town_candidate.get("schema_id", "")) != "aurelion_native_rmg_town_placement_v1" \
			or bool(town_candidate.get("public_package_adoption", true)) \
			or bool(town_candidate.get("runtime_grid_adoption", true)) \
			or int(town_candidate.get("town_record_count", -1)) != 3 \
			or int(town_candidate.get("player_start_count", -1)) != 3 \
			or int(town_candidate.get("expected_player_count", -1)) != 3 \
			or int(town_candidate.get("synchronized_player_start_count", -1)) != 3 \
			or Array(town_candidate.get("owner_slots", [])) != [1, 2, 3] \
			or town_records.size() != 3 \
			or player_starts.size() != 3:
		_fail("h3maped project town adoption candidate drifted: %s" % JSON.stringify(town_candidate))
		return
	if int(town_records[0].get("owner_slot", -1)) != 1 \
			or String(town_records[0].get("owner", "")) != "player" \
			or int(town_records[0].get("x", -1)) != 26 \
			or int(town_records[0].get("y", -1)) != 16 \
			or int(town_records[1].get("owner_slot", -1)) != 2 \
			or String(town_records[1].get("owner", "")) != "enemy" \
			or int(town_records[1].get("x", -1)) != 23 \
			or int(town_records[1].get("y", -1)) != 23 \
			or int(town_records[2].get("owner_slot", -1)) != 3 \
			or int(town_records[2].get("x", -1)) != 18 \
			or int(town_records[2].get("y", -1)) != 5 \
			or not bool(town_records[2].get("h3maped_selected_from_random_tie", false)):
		_fail("h3maped projected town records drifted: %s" % JSON.stringify(town_records))
		return
	for index in range(player_starts.size()):
		var start_record: Dictionary = player_starts[index]
		var town_record: Dictionary = town_records[index]
		if int(start_record.get("owner_slot", -1)) != int(town_record.get("owner_slot", -2)) \
				or int(start_record.get("x", -1)) != int(town_record.get("x", -2)) \
				or int(start_record.get("y", -1)) != int(town_record.get("y", -2)) \
				or String(start_record.get("town_placement_id", "")) != String(town_record.get("placement_id", "missing")):
			_fail("h3maped player start is not synchronized to owned town: %s / %s" % [JSON.stringify(start_record), JSON.stringify(town_record)])
			return

	var object_vector_phase: Dictionary = small_state.get("object_vector_prerequisite_phase_4a9d6a_4aab7e", {})
	var known_vector_gap: Dictionary = object_vector_phase.get("known_coordinate_vector_gap", {})
	if String(object_vector_phase.get("phase_id", "")) != "object_vector_prerequisite_phase_4a9d6a_4aab7e" \
				or String(object_vector_phase.get("status", "")) != "active_runtime_state_ready" \
				or String(object_vector_phase.get("h3maped_mine_phase_address", "")) != "0x4a9d6a" \
				or String(object_vector_phase.get("h3maped_mine_template_selector_address", "")) != "0x4a9911" \
				or String(object_vector_phase.get("h3maped_mine_constraint_address", "")) != "0x4a9641" \
				or String(object_vector_phase.get("h3maped_footprint_gate_address", "")) != "0x49a09c" \
				or String(object_vector_phase.get("h3maped_cell_validity_address", "")) != "0x49a1d8" \
				or String(object_vector_phase.get("h3maped_treasure_phase_address", "")) != "0x4aab7e" \
				or bool(object_vector_phase.get("complete_coordinate_vector_claim", true)) \
				or not bool(object_vector_phase.get("materializes_private_object_coordinate_records", false)) \
				or bool(object_vector_phase.get("materializes_public_objects", true)) \
				or bool(object_vector_phase.get("public_package_output_allowed", true)) \
				or int(object_vector_phase.get("materialized_town_coordinate_record_count", -1)) != 3 \
				or int(object_vector_phase.get("mine_minimum_record_count", -1)) != 18 \
				or int(object_vector_phase.get("materialized_private_mine_coordinate_record_count", -1)) != 18 \
				or String(object_vector_phase.get("mine_placement_constraint_gate_model", "")) != "0x49a09c circular mask scan with one-extra wrap step and 0x49a1d8-style cell validity" \
				or int(object_vector_phase.get("partial_coordinate_record_count", -1)) != 21 \
				or int(object_vector_phase.get("mine_placement_scan_call_count", -1)) != 18 \
				or int(object_vector_phase.get("mine_placement_selected_count", -1)) != 18 \
				or int(object_vector_phase.get("mine_placement_candidate_total", -1)) != 1870 \
				or int(object_vector_phase.get("mine_placement_rejected_49aa93_count", -1)) != 1574 \
				or int(object_vector_phase.get("mine_placement_rejected_special_distance_count", -1)) != 135 \
				or int(object_vector_phase.get("object_rng_state_after_0x4a9911_0x4a9641_uint32", -1)) != 2346411599 \
				or int(object_vector_phase.get("mine_density_weight_total", -1)) != 18 \
				or int(object_vector_phase.get("eligible_reward_band_count", -1)) != 18 \
				or int(object_vector_phase.get("reward_band_weight_total", -1)) != 96 \
				or String(object_vector_phase.get("blocked_next", "")) != "port_0x4aab7e_rewards_density_guards_adjacent_resources_before_0x4ab52a":
		_fail("h3maped object-vector prerequisite phase drifted: %s" % JSON.stringify(object_vector_phase))
		return
	if int(known_vector_gap.get("town_coordinate_record_count", -1)) != 3 \
				or int(known_vector_gap.get("mine_minimum_record_count", -1)) != 18 \
				or int(known_vector_gap.get("materialized_private_mine_coordinate_record_count", -1)) != 18 \
				or int(known_vector_gap.get("mine_density_weight_total", -1)) != 18 \
				or int(known_vector_gap.get("eligible_reward_band_count", -1)) != 18 \
				or int(known_vector_gap.get("reward_band_weight_total", -1)) != 96 \
				or bool(known_vector_gap.get("current_road_vector_only_has_towns", true)) \
				or not bool(known_vector_gap.get("roads_must_not_be_publicly_adopted_from_partial_vector", false)):
		_fail("h3maped known coordinate-vector gap drifted: %s" % JSON.stringify(known_vector_gap))
		return
	var roads_phase: Dictionary = small_state.get("roads_and_rivers_phase_4ab52a", {})
	if String(roads_phase.get("phase_id", "")) != "roads_and_rivers_phase_4ab52a" \
				or String(roads_phase.get("h3maped_phase_runner_address", "")) != "0x4ab52a" \
				or String(roads_phase.get("h3maped_path_state_seed_address", "")) != "0x4aae7b" \
				or String(roads_phase.get("h3maped_road_adapter_entry_address", "")) != "0x4ab37f" \
				or String(roads_phase.get("h3maped_road_toolkit_entry_address", "")) != "0x4b4243" \
				or String(roads_phase.get("status", "")) != "blocked_until_complete_generator_plus_0x14b0_coordinate_vector" \
				or bool(roads_phase.get("materializes_public_roads", true)) \
				or bool(roads_phase.get("materializes_rivers", true)) \
				or bool(roads_phase.get("materializes_package_tiles", true)) \
				or bool(roads_phase.get("public_package_output_allowed", true)) \
				or bool(roads_phase.get("complete_coordinate_vector_claim", true)) \
				or String(roads_phase.get("blocked_next", "")) != "port_0x4aab7e_rewards_density_guards_adjacent_resources_before_0x4ab52a":
		_fail("h3maped roads/rivers boundary should be blocked until complete object vector: %s" % JSON.stringify(roads_phase))
		return

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete" \
			or generated.has("private_generation_context"):
		_fail("Supported small generation must remain blocked by the restart boundary: %s" % JSON.stringify(generated))
		return
	if Array(generated.get("small_generation_state", {}).get("completed_phase_ids", [])) != expected_completed_phases:
		_fail("Blocked generation result did not carry the small source-node rectangle state: %s" % JSON.stringify(generated))
		return

	var explicit_template_config := config.duplicate(true)
	explicit_template_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_generated: Dictionary = service.generate_random_map(explicit_template_config)
	if bool(explicit_generated.get("ok", true)) \
			or String(explicit_generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Explicit translated-template request bypassed the h3maped reset gate: %s" % JSON.stringify(explicit_generated))
		return

	var medium_config := {
		"seed": "1",
		"size": {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var medium_generated: Dictionary = service.generate_random_map(medium_config)
	if bool(medium_generated.get("ok", true)) \
			or String(medium_generated.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope generation must not fall back to archived legacy RMG: %s" % JSON.stringify(medium_generated))
		return

	print("%s: PASS small h3maped restart boundary blocks runtime generation and legacy fallback" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
