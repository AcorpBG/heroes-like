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
	if not service.get_capabilities().has("native_rmg_small_h3maped_port_boundary"):
		_fail("Native service does not expose the small h3maped port boundary capability.")
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
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_restart_boundary_v1":
		_fail("Small h3maped inspection did not use the restart boundary schema: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "h3maped_small_restart_boundary_ready":
		_fail("Unexpected small h3maped restart status: %s" % JSON.stringify(report))
		return
	if String(report.get("implementation_policy", "")) != "archived_current_native_rmg_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_runtime_fallback":
		_fail("The restart policy is not explicit enough: %s" % JSON.stringify(report))
		return
	if String(report.get("archive_status", "")) != "previous_active_h3maped_boundary_archived_out_of_build":
		_fail("The previous active boundary was not archived out of the build: %s" % JSON.stringify(report))
		return
	if String(report.get("archived_active_boundary_path", "")) != "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp":
		_fail("Unexpected archived active boundary path: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) or bool(report.get("partial_materialized_payload_public_api", true)):
		_fail("The restart must not expose runtime or partial package output: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("status", "")) != "verified_reset_anchor" \
			or not bool(binary.get("mz_header_present", false)) \
			or not bool(binary.get("sha256_matches", false)) \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("The reset boundary did not verify the local h3maped.exe anchor: %s" % JSON.stringify(binary))
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
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("rng_state_after_selection_uint32", -1)) != 2745024:
		_fail("h3maped RNG template selection boundary drifted: %s" % JSON.stringify(selection))
		return

	var assignment: Dictionary = report.get("player_slot_assignment", {})
	if String(assignment.get("status", "")) != "0x4ac62a_player_slot_assignment_ported_inspection_only" \
			or String(assignment.get("selected_color_bitmap_offset", "")) != "generator+0xed8" \
			or String(assignment.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(assignment.get("mapped_slots_offset", "")) != "generator+0xee4":
		_fail("h3maped player-slot assignment boundary drifted: %s" % JSON.stringify(assignment))
		return
	if int(assignment.get("human_capable_source_owner_mask", -1)) != 15 \
			or int(assignment.get("player_capable_source_owner_mask", -1)) != 15 \
			or Array(assignment.get("human_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(assignment.get("player_capable_source_owner_indices", [])) != [0, 1, 2, 3]:
		_fail("Selected source-owner capability masks drifted from recovered h3maped template evidence: %s" % JSON.stringify(assignment))
		return
	if Array(assignment.get("selected_color_order", [])) != [0, 1, 2, 3, 4, 5, 6, 7] \
			or Array(assignment.get("raw_ee0_slots", [])) != [-1, 0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(assignment.get("actual_colors_by_source_owner", [])) != [0, 1, 2, -1, -1, -1, -1, -1]:
		_fail("Default h3maped player-color mapping drifted: %s" % JSON.stringify(assignment))
		return
	var assignments: Array = assignment.get("assignments", [])
	if assignments.size() != 3 \
			or String(assignments[0].get("player_type", "")) != "human" \
			or int(assignments[0].get("source_owner_index", -1)) != 0 \
			or int(assignments[0].get("actual_player_color", -1)) != 0 \
			or String(assignments[1].get("player_type", "")) != "computer" \
			or int(assignments[1].get("source_owner_index", -1)) != 1 \
			or int(assignments[1].get("actual_player_color", -1)) != 1 \
			or String(assignments[2].get("player_type", "")) != "computer" \
			or int(assignments[2].get("source_owner_index", -1)) != 2 \
			or int(assignments[2].get("actual_player_color", -1)) != 2 \
			or bool(assignment.get("materializes_runtime_players", true)):
		_fail("h3maped player assignment records are wrong or materialized runtime players too early: %s" % JSON.stringify(assignment))
		return

	var runtime_zones: Dictionary = report.get("runtime_zone_record_setup", {})
	if String(runtime_zones.get("status", "")) != "0x4a218c_runtime_zone_record_setup_ported_inspection_only" \
			or String(runtime_zones.get("runtime_zone_vector_offsets", "")) != "generator+0x10e0/+0x10e4/+0x10e8" \
			or int(runtime_zones.get("runtime_zone_record_size_bytes", -1)) != 0x414 \
			or String(runtime_zones.get("owner_color_mapping_source", "")) != "generator+0xee4":
		_fail("h3maped runtime-zone setup boundary drifted: %s" % JSON.stringify(runtime_zones))
		return
	if int(runtime_zones.get("runtime_zone_count", -1)) != 6 \
			or int(runtime_zones.get("assigned_start_zone_count", -1)) != 3 \
			or int(runtime_zones.get("unassigned_start_zone_count", -1)) != 1 \
			or int(runtime_zones.get("treasure_zone_count", -1)) != 2 \
			or int(runtime_zones.get("minimum_player_castles", -1)) != 4 \
			or int(runtime_zones.get("minimum_source_base_size", -1)) != 11 \
			or Array(runtime_zones.get("actual_owner_colors_by_runtime_zone", [])) != [0, 1, -1, 2, -1, -1]:
		_fail("h3maped runtime-zone record counts drifted from recovered template 18: %s" % JSON.stringify(runtime_zones))
		return
	if bool(runtime_zones.get("materializes_runtime_zone_coordinates", true)) \
			or bool(runtime_zones.get("materializes_terrain", true)) \
			or bool(runtime_zones.get("materializes_map_cells", true)) \
			or bool(runtime_zones.get("materializes_runtime_players", true)):
		_fail("Runtime-zone setup must not materialize runtime output yet: %s" % JSON.stringify(runtime_zones))
		return
	var zone_records: Array = runtime_zones.get("runtime_zone_records", [])
	if zone_records.size() != 6 \
			or String(zone_records[0].get("role", "")) != "human_start" \
			or int(zone_records[0].get("level", -1)) != 0 \
			or int(zone_records[0].get("actual_owner_color", -1)) != 0 \
			or String(zone_records[2].get("role", "")) != "treasure" \
			or int(zone_records[2].get("actual_owner_color", 0)) != -1 \
			or String(zone_records[4].get("role", "")) != "human_start" \
			or int(zone_records[4].get("source_owner_index", -1)) != 3 \
			or int(zone_records[4].get("actual_owner_color", 0)) != -1:
		_fail("Runtime-zone record projection drifted: %s" % JSON.stringify(zone_records))
		return

	var link_seeds: Dictionary = report.get("link_seed_setup", {})
	if String(link_seeds.get("status", "")) != "0x4a1f3b_endpoint_link_seeds_ported_inspection_only" \
			or String(link_seeds.get("link_endpoint_consumer_address", "")) != "0x4a1f3b" \
			or String(link_seeds.get("candidate_generator_address", "")) != "0x4a17f5" \
			or String(link_seeds.get("distance_validation_address", "")) != "0x4a1701" \
			or String(link_seeds.get("late_payload_consumer_address", "")) != "0x4a79a3":
		_fail("h3maped link seed boundary drifted: %s" % JSON.stringify(link_seeds))
		return
	if bool(link_seeds.get("materializes_coordinates", true)) \
			or bool(link_seeds.get("materializes_connection_guards", true)) \
			or bool(link_seeds.get("materializes_roads", true)) \
			or bool(link_seeds.get("materializes_blockers", true)):
		_fail("Link seed setup must not materialize map output: %s" % JSON.stringify(link_seeds))
		return
	var seed_records: Array = link_seeds.get("link_seeds", [])
	if int(link_seeds.get("link_seed_count", -1)) != 5 \
			or seed_records.size() != 5 \
			or int(seed_records[0].get("source_zone_a", -1)) != 1 \
			or int(seed_records[0].get("source_zone_b", -1)) != 4 \
			or int(seed_records[0].get("runtime_zone_a", -1)) != 0 \
			or int(seed_records[0].get("runtime_zone_b", -1)) != 3 \
			or int(seed_records[0].get("guard_value", -1)) != 3000 \
			or int(seed_records[3].get("source_zone_a", -1)) != 3 \
			or int(seed_records[3].get("source_zone_b", -1)) != 5 \
			or int(seed_records[3].get("guard_value", -1)) != 6000 \
			or int(seed_records[4].get("source_zone_a", -1)) != 6 \
			or int(seed_records[4].get("source_zone_b", -1)) != 4 \
			or int(seed_records[4].get("runtime_zone_a", -1)) != 5 \
			or int(seed_records[4].get("runtime_zone_b", -1)) != 3 \
			or int(seed_records[4].get("guard_value", -1)) != 6000:
		_fail("Recovered template 18 link seed endpoints drifted: %s" % JSON.stringify(seed_records))
		return

	var coordinate_replay: Dictionary = report.get("coordinate_replay", {})
	if String(coordinate_replay.get("status", "")) != "0x4a17f5_0x4a1701_coordinate_candidate_replay_ported_inspection_only" \
			or not bool(coordinate_replay.get("ok", false)) \
			or String(coordinate_replay.get("distance_validation_address", "")) != "0x4a1701" \
			or String(coordinate_replay.get("candidate_prune_address", "")) != "0x4a1ad8" \
			or String(coordinate_replay.get("bbox_rescale_address", "")) != "0x4a19ed":
		_fail("h3maped coordinate replay boundary drifted: %s" % JSON.stringify(coordinate_replay))
		return
	if bool(coordinate_replay.get("materializes_map_cells", true)) \
			or bool(coordinate_replay.get("materializes_zone_footprints", true)) \
			or String(coordinate_replay.get("next_materialization_status", "")) != "pending_0x4ccb64_source_node_split_insertion":
		_fail("Coordinate replay must not materialize map cells or zone footprints: %s" % JSON.stringify(coordinate_replay))
		return
	if int(coordinate_replay.get("placement_step_count", -1)) != 18 \
			or int(coordinate_replay.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18 \
			or int(coordinate_replay.get("rng_event_count", -1)) != 18 \
			or int(coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", -1)) != 316395082:
		_fail("Coordinate replay RNG schedule drifted: %s" % JSON.stringify(coordinate_replay))
		return
	var bbox: Dictionary = coordinate_replay.get("bounding_box_rescale", {})
	if int(bbox.get("min_y_before_rescale", 0)) != -11 \
			or int(bbox.get("min_x_before_rescale", 0)) != -67 \
			or int(bbox.get("max_y_before_rescale", 0)) != 30 \
			or int(bbox.get("max_x_before_rescale", 0)) != 18 \
			or int(bbox.get("height_before_rescale", 0)) != 41 \
			or int(bbox.get("width_before_rescale", 0)) != 85 \
			or int(bbox.get("selected_span_before_rescale", 0)) != 85 \
			or int(bbox.get("map_span", 0)) != 36 \
			or int(bbox.get("offset_y", 0)) != -33 \
			or int(bbox.get("offset_x", 0)) != -67:
		_fail("Coordinate replay bbox rescale drifted: %s" % JSON.stringify(bbox))
		return
	var scaled: Array = coordinate_replay.get("scaled_zone_coordinates", [])
	if scaled.size() != 6 \
			or int(scaled[0].get("x_after_bbox_rescale", -1)) != 30 \
			or int(scaled[0].get("y_after_bbox_rescale", -1)) != 16 \
			or int(scaled[1].get("x_after_bbox_rescale", -1)) != 8 \
			or int(scaled[1].get("y_after_bbox_rescale", -1)) != 13 \
			or int(scaled[2].get("x_after_bbox_rescale", -1)) != 4 \
			or int(scaled[2].get("y_after_bbox_rescale", -1)) != 21 \
			or int(scaled[3].get("x_after_bbox_rescale", -1)) != 23 \
			or int(scaled[3].get("y_after_bbox_rescale", -1)) != 21 \
			or int(scaled[4].get("x_after_bbox_rescale", -1)) != 13 \
			or int(scaled[4].get("y_after_bbox_rescale", -1)) != 21 \
			or int(scaled[5].get("x_after_bbox_rescale", -1)) != 18 \
			or int(scaled[5].get("y_after_bbox_rescale", -1)) != 13:
		_fail("Coordinate replay scaled zone coordinates drifted: %s" % JSON.stringify(scaled))
		return
	var placement_steps: Array = coordinate_replay.get("placement_steps", [])
	if placement_steps.size() != 18 \
			or String(placement_steps[0].get("pass", "")) != "0x4a2226_initial_runtime_zone_insertion" \
			or int(placement_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(placement_steps[0].get("selected_candidate", {}).get("x", -1)) != 0 \
			or int(placement_steps[0].get("selected_candidate", {}).get("y", -1)) != 0:
		_fail("Coordinate replay placement-step schedule drifted: %s" % JSON.stringify(placement_steps))
		return

	var footprint_boundary: Dictionary = report.get("zone_footprint_phase_boundary", {})
	if String(footprint_boundary.get("status", "")) != "0x4a3a03_zone_footprint_phase_boundary_ported_inspection_only" \
			or String(footprint_boundary.get("phase_address", "")) != "0x4a3a03" \
			or String(footprint_boundary.get("helper_sequence", "")) != "0x4a2777 -> 0x4a325d -> 0x4a3710":
		_fail("h3maped zone-footprint phase boundary drifted: %s" % JSON.stringify(footprint_boundary))
		return
	if int(footprint_boundary.get("level_count", -1)) != 1 \
			or int(footprint_boundary.get("h3maped_water_mode_code", -1)) != 0 \
			or int(footprint_boundary.get("total_collected_runtime_zone_count", -1)) != 6 \
			or int(footprint_boundary.get("synthetic_zone_appended_count", -1)) != 0:
		_fail("Small one-level land footprint collection should collect 6 runtime zones with no synthetic source zone: %s" % JSON.stringify(footprint_boundary))
		return
	if bool(footprint_boundary.get("materializes_boundaries", true)) \
			or bool(footprint_boundary.get("materializes_span_fill", true)) \
			or bool(footprint_boundary.get("materializes_terrain", true)) \
			or bool(footprint_boundary.get("materializes_map_cells", true)):
		_fail("Zone-footprint boundary must not materialize geometry or cells yet: %s" % JSON.stringify(footprint_boundary))
		return
	var level_records: Array = footprint_boundary.get("per_level", [])
	if level_records.size() != 1 \
			or Array(level_records[0].get("collected_runtime_zone_indices", [])) != [0, 1, 2, 3, 4, 5] \
			or String(level_records[0].get("synthetic_zone_status", "")) != "not_applicable_small_one_level_land" \
			or String(level_records[0].get("helper_status", "")) != "0x4a2777_inputs_queued_0x4a325d_0x4a3710_materialization_pending":
		_fail("Per-level 0x4a3a03 footprint boundary drifted: %s" % JSON.stringify(level_records))
		return
	var helper_inputs: Array = level_records[0].get("helper_call_inputs", [])
	if int(level_records[0].get("helper_call_input_count", -1)) != 6 \
			or helper_inputs.size() != 6 \
			or String(helper_inputs[0].get("helper_address", "")) != "0x4a2777" \
			or int(helper_inputs[0].get("runtime_zone_index", -1)) != 0 \
			or int(helper_inputs[0].get("source_zone_id", -1)) != 1 \
			or String(helper_inputs[0].get("input_status", "")) != "queued_for_0x4a2777_no_boundary_materialization" \
			or int(helper_inputs[5].get("runtime_zone_index", -1)) != 5 \
			or int(helper_inputs[5].get("source_zone_id", -1)) != 6:
		_fail("0x4a2777 helper input queue drifted: %s" % JSON.stringify(helper_inputs))
		return

	var source_node_rectangle: Dictionary = report.get("source_node_rectangle_4cc788", {})
	if String(source_node_rectangle.get("status", "")) != "0x4cc788_initial_source_node_bounds_ported_inspection_only" \
			or String(source_node_rectangle.get("function_address", "")) != "0x4cc788" \
			or String(source_node_rectangle.get("node_constructor_address", "")) != "0x4cc955" \
			or String(source_node_rectangle.get("splitter_address", "")) != "0x4ccb64" \
			or String(source_node_rectangle.get("locator_address", "")) != "0x4cca55" \
			or String(source_node_rectangle.get("finalizer_address", "")) != "0x4ccdfc":
		_fail("0x4cc788 source-node rectangle boundary drifted: %s" % JSON.stringify(source_node_rectangle))
		return
	if bool(source_node_rectangle.get("materializes_boundaries", true)) \
			or bool(source_node_rectangle.get("materializes_span_fill", true)) \
			or bool(source_node_rectangle.get("materializes_terrain", true)) \
			or bool(source_node_rectangle.get("materializes_map_cells", true)) \
			or bool(source_node_rectangle.get("feeds_real_0x4a2777_boundary", true)):
		_fail("0x4cc788 source-node rectangle must not feed generated output yet: %s" % JSON.stringify(source_node_rectangle))
		return
	var source_node_bounds: Dictionary = source_node_rectangle.get("initial_bounds", {})
	var source_node_edges: Array = source_node_rectangle.get("initial_edges", [])
	if int(source_node_bounds.get("min_x", 0)) != -200 \
			or int(source_node_bounds.get("min_y", 0)) != -200 \
			or int(source_node_bounds.get("max_x", 0)) != 400 \
			or int(source_node_bounds.get("max_y", 0)) != 400 \
			or String(source_node_bounds.get("constant_min_hex", "")) != "0xffffff38" \
			or String(source_node_bounds.get("constant_max_hex", "")) != "0x190" \
			or int(source_node_rectangle.get("initial_edge_count", -1)) != 4 \
			or source_node_edges.size() != 4 \
			or String(source_node_edges[0].get("id", "")) != "top" \
			or int(source_node_edges[0].get("from_x", 0)) != -200 \
			or int(source_node_edges[0].get("to_x", 0)) != 400 \
			or String(source_node_edges[3].get("id", "")) != "left" \
			or int(source_node_edges[3].get("from_y", 0)) != 400 \
			or int(source_node_edges[3].get("to_y", 0)) != -200:
		_fail("0x4cc788 source-node rectangle constants drifted: %s" % JSON.stringify(source_node_rectangle))
		return

	var clip_helper: Dictionary = report.get("clip_helper_4a2b33", {})
	if String(clip_helper.get("status", "")) != "0x4a2b33_clip_helper_ported_inspection_only" \
			or String(clip_helper.get("function_address", "")) != "0x4a2b33" \
			or String(clip_helper.get("caller_address", "")) != "0x4a2777":
		_fail("0x4a2b33 clip helper boundary drifted: %s" % JSON.stringify(clip_helper))
		return
	if bool(clip_helper.get("materializes_boundaries", true)) \
			or bool(clip_helper.get("materializes_span_fill", true)) \
			or bool(clip_helper.get("materializes_terrain", true)) \
			or bool(clip_helper.get("materializes_map_cells", true)) \
			or bool(clip_helper.get("feeds_real_0x4a2777_boundary", true)):
		_fail("0x4a2b33 clip helper must not materialize generated output yet: %s" % JSON.stringify(clip_helper))
		return
	var clip_bounds: Dictionary = clip_helper.get("clip_bounds", {})
	if int(clip_bounds.get("min_x", -1)) != 0 \
			or int(clip_bounds.get("min_y", -1)) != 0 \
			or int(clip_bounds.get("max_x", -1)) != 36 \
			or int(clip_bounds.get("max_y", -1)) != 36:
		_fail("0x4a2b33 clip bounds drifted: %s" % JSON.stringify(clip_helper))
		return
	var clip_samples: Array = clip_helper.get("samples", [])
	if int(clip_helper.get("sample_count", -1)) != 5 \
			or clip_samples.size() != 5 \
			or String(clip_samples[0].get("id", "")) != "inside" \
			or int(clip_samples[0].get("out_x", -1)) != 10 \
			or int(clip_samples[0].get("out_y", -1)) != 10 \
			or not bool(clip_samples[0].get("input_inside", false)) \
			or String(clip_samples[0].get("branch", "")) != "0x4a2b5d_input_inside" \
			or String(clip_samples[1].get("id", "")) != "left_to_inside" \
			or int(clip_samples[1].get("out_x", -1)) != 0 \
			or int(clip_samples[1].get("out_y", -1)) != 10 \
			or String(clip_samples[2].get("id", "")) != "top_to_inside" \
			or int(clip_samples[2].get("out_x", -1)) != 10 \
			or int(clip_samples[2].get("out_y", -1)) != 0 \
			or String(clip_samples[3].get("id", "")) != "right_to_inside" \
			or int(clip_samples[3].get("out_x", -1)) != 35 \
			or int(clip_samples[3].get("out_y", -1)) != 12 \
			or String(clip_samples[4].get("id", "")) != "bottom_to_inside" \
			or int(clip_samples[4].get("out_x", -1)) != 12 \
			or int(clip_samples[4].get("out_y", -1)) != 35:
		_fail("0x4a2b33 clip samples drifted: %s" % JSON.stringify(clip_samples))
		return

	var line_writer: Dictionary = report.get("line_writer_4a261a", {})
	if String(line_writer.get("status", "")) != "0x4a261a_deterministic_line_writer_ported_inspection_only" \
			or String(line_writer.get("function_address", "")) != "0x4a261a" \
			or String(line_writer.get("caller_address", "")) != "0x4a2777" \
			or String(line_writer.get("zone_word_mask", "")) != "0x00ff0000" \
			or String(line_writer.get("zone_word_clear_mask", "")) != "0xff00ffff" \
			or String(line_writer.get("reserved_flag_mask", "")) != "0x10":
		_fail("0x4a261a line-writer boundary drifted: %s" % JSON.stringify(line_writer))
		return
	if bool(line_writer.get("materializes_boundaries", true)) \
			or bool(line_writer.get("materializes_span_fill", true)) \
			or bool(line_writer.get("materializes_terrain", true)) \
			or bool(line_writer.get("materializes_map_cells", true)) \
			or bool(line_writer.get("feeds_real_0x4a2777_boundary", true)):
		_fail("0x4a261a line writer must not materialize generated output yet: %s" % JSON.stringify(line_writer))
		return
	var line_sample: Dictionary = line_writer.get("sample_contract", {})
	var line_trace: Array = line_sample.get("trace_preview", [])
	if int(line_sample.get("map_width", -1)) != 12 \
			or int(line_sample.get("map_height", -1)) != 8 \
			or int(line_sample.get("level_count", -1)) != 1 \
			or int(line_sample.get("h3maped_water_mode_code", -1)) != 0 \
			or int(line_sample.get("from_x", -1)) != 2 \
			or int(line_sample.get("from_y", -1)) != 3 \
			or int(line_sample.get("to_x", -1)) != 8 \
			or int(line_sample.get("to_y", -1)) != 3 \
			or int(line_sample.get("level", -1)) != 0 \
			or int(line_sample.get("zone_word_id", -1)) != 7 \
			or int(line_sample.get("write_count", -1)) != 7 \
			or int(line_sample.get("unique_cell_count", -1)) != 7 \
			or int(line_sample.get("zone_word_cell_count", -1)) != 7 \
			or int(line_sample.get("reserved_flag_write_count", -1)) != 7 \
			or int(line_sample.get("reserved_flag_cell_count", -1)) != 7 \
			or int(line_sample.get("out_of_bounds_write_count", -1)) != 0 \
			or line_trace.size() != 7 \
			or int(line_trace[0].get("x", -1)) != 2 \
			or int(line_trace[0].get("y", -1)) != 3 \
			or int(line_trace[6].get("x", -1)) != 8 \
			or int(line_trace[6].get("y", -1)) != 3:
		_fail("0x4a261a line-writer sample contract drifted: %s" % JSON.stringify(line_writer))
		return

	var backlog: Array = report.get("restart_phase_backlog", [])
	if backlog.size() != 9:
		_fail("The restart backlog should list the required executable phase ports only: %s" % JSON.stringify(backlog))
		return
	if String(backlog[0].get("phase_id", "")) != "template_selection" \
			or String(backlog[0].get("status", "")) != "active_boundary_only":
		_fail("Template selection should be the only active executable boundary after restart: %s" % JSON.stringify(backlog))
		return
	if String(backlog[1].get("phase_id", "")) != "player_slot_assignment" \
			or String(backlog[1].get("status", "")) != "active_inspection_only":
		_fail("Player-slot assignment should be active only as inspection evidence: %s" % JSON.stringify(backlog))
		return
	if String(backlog[2].get("phase_id", "")) != "runtime_zone_records" \
			or String(backlog[2].get("status", "")) != "active_inspection_only":
		_fail("Runtime-zone records should be active only as inspection evidence: %s" % JSON.stringify(backlog))
		return
	if String(backlog[3].get("phase_id", "")) != "coordinate_replay" \
			or String(backlog[3].get("status", "")) != "active_inspection_only":
		_fail("Coordinate replay should be active only as inspection evidence: %s" % JSON.stringify(backlog))
		return
	if String(backlog[4].get("phase_id", "")) != "zone_footprints_and_terrain" \
			or String(backlog[4].get("status", "")) != "active_phase_boundary_only":
		_fail("Zone-footprint phase should be active only as a h3maped phase boundary: %s" % JSON.stringify(backlog))
		return
	for index in range(5, backlog.size()):
		if String(backlog[index].get("status", "")) != "pending_strict_h3maped_port":
			_fail("Non-template phases must remain pending strict executable ports: %s" % JSON.stringify(backlog))
			return

	var generation_result: Dictionary = service.generate_random_map(config)
	if bool(generation_result.get("ok", true)) \
			or String(generation_result.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generation_result.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Supported small generation must stay blocked until h3maped phases are ported: %s" % JSON.stringify(generation_result))
		return

	var out_of_scope := {
		"seed": "1",
		"size": {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"},
		"player_constraints": {"human_count": 1, "player_count": 4, "team_mode": "free_for_all"},
	}
	var out_result: Dictionary = service.generate_random_map(out_of_scope)
	if bool(out_result.get("ok", true)) \
			or String(out_result.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope generation must not fall back to archived native RMG: %s" % JSON.stringify(out_result))
		return

	print("%s: status=pass schema=%s selected_template=%s" % [
		REPORT_ID,
		String(report.get("schema_id", "")),
		String(selection.get("source_template_id", "")),
	])
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	print("%s: status=fail reason=%s" % [REPORT_ID, reason])
	get_tree().quit(1)
