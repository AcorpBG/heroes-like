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
			or String(backlog[5].get("status", "")) != "pending_strict_port" \
			or String(backlog[9].get("id", "")) != "final_h3m_writeout":
		_fail("Restart backlog drifted: %s" % JSON.stringify(backlog))
		return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Restart backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var small_state: Dictionary = report.get("small_generation_state", {})
	if String(small_state.get("schema_id", "")) != "aurelion_h3maped_small_generation_state_v1" \
			or String(small_state.get("status", "")) != "runtime_terrain_selection_49b53d_active_runtime_state_ready" \
			or Array(small_state.get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay", "zone_footprint_phase_boundary", "source_node_rectangle", "polygon_split_model", "source_node_boundary_traversal", "span_fill_4a325d", "footprint_finalizer_4a3710", "runtime_terrain_selection_49b53d"] \
			or int(small_state.get("completed_phase_count", -1)) != 12 \
			or bool(small_state.get("runtime_generation_allowed", true)) \
			or bool(small_state.get("materializes_runtime_players", true)) \
			or bool(small_state.get("materializes_map_cells", true)) \
			or bool(small_state.get("materializes_public_output", true)) \
			or String(small_state.get("blocked_next", "")) != "terrain_cell_writeout_4a3f27":
		_fail("Small h3maped generation state did not stop after runtime terrain selection: %s" % JSON.stringify(small_state))
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

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete" \
			or generated.has("private_generation_context"):
		_fail("Supported small generation must remain blocked by the restart boundary: %s" % JSON.stringify(generated))
		return
	if Array(generated.get("small_generation_state", {}).get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay", "zone_footprint_phase_boundary", "source_node_rectangle", "polygon_split_model", "source_node_boundary_traversal", "span_fill_4a325d", "footprint_finalizer_4a3710", "runtime_terrain_selection_49b53d"]:
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
