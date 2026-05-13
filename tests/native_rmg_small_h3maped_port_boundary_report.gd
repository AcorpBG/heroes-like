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
			or int(coordinate_replay.get("town_choice_rng_calls_during_0x4a218c", -1)) != 4 \
			or int(coordinate_replay.get("total_interleaved_rng_calls_during_0x4a218c", -1)) != 22 \
			or int(coordinate_replay.get("rng_event_count", -1)) != 22 \
			or int(coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", -1)) != 255755822 \
			or String(coordinate_replay.get("town_choice_rng_status", "")) != "0x49b3c1_interleaved_allowed_town_choice_ported_inspection_only":
		_fail("Coordinate replay RNG schedule drifted: %s" % JSON.stringify(coordinate_replay))
		return
	var bbox: Dictionary = coordinate_replay.get("bounding_box_rescale", {})
	if int(bbox.get("min_y_before_rescale", 0)) != -26 \
			or int(bbox.get("min_x_before_rescale", 0)) != -36 \
			or int(bbox.get("max_y_before_rescale", 0)) != 58 \
			or int(bbox.get("max_x_before_rescale", 0)) != 12 \
			or int(bbox.get("height_before_rescale", 0)) != 84 \
			or int(bbox.get("width_before_rescale", 0)) != 48 \
			or int(bbox.get("selected_span_before_rescale", 0)) != 84 \
			or int(bbox.get("map_span", 0)) != 36 \
			or int(bbox.get("offset_y", 0)) != -26 \
			or int(bbox.get("offset_x", 0)) != -54:
		_fail("Coordinate replay bbox rescale drifted: %s" % JSON.stringify(bbox))
		return
	var scaled: Array = coordinate_replay.get("scaled_zone_coordinates", [])
	if scaled.size() != 6 \
			or int(scaled[0].get("x_after_bbox_rescale", -1)) != 23 \
			or int(scaled[0].get("y_after_bbox_rescale", -1)) != 11 \
			or int(scaled[1].get("x_after_bbox_rescale", -1)) != 21 \
			or int(scaled[1].get("y_after_bbox_rescale", -1)) != 22 \
			or int(scaled[2].get("x_after_bbox_rescale", -1)) != 12 \
			or int(scaled[2].get("y_after_bbox_rescale", -1)) != 23 \
			or int(scaled[3].get("x_after_bbox_rescale", -1)) != 18 \
			or int(scaled[3].get("y_after_bbox_rescale", -1)) != 4 \
			or int(scaled[4].get("x_after_bbox_rescale", -1)) != 18 \
			or int(scaled[4].get("y_after_bbox_rescale", -1)) != 30 \
			or int(scaled[5].get("x_after_bbox_rescale", -1)) != 12 \
			or int(scaled[5].get("y_after_bbox_rescale", -1)) != 11:
		_fail("Coordinate replay scaled zone coordinates drifted: %s" % JSON.stringify(scaled))
		return
	var runtime_after_towns: Array = coordinate_replay.get("runtime_zone_records_after_0x49b3c1", [])
	if runtime_after_towns.size() != 6 \
			or String(runtime_after_towns[0].get("faction_id", "")) != "elemental" \
			or int(runtime_after_towns[0].get("town_choice_index", -1)) != 8 \
			or String(runtime_after_towns[1].get("faction_id", "")) != "necropolis" \
			or int(runtime_after_towns[1].get("town_choice_index", -1)) != 4 \
			or String(runtime_after_towns[3].get("faction_id", "")) != "inferno" \
			or int(runtime_after_towns[3].get("town_choice_index", -1)) != 3 \
			or String(runtime_after_towns[4].get("faction_id", "")) != "fortress" \
			or int(runtime_after_towns[4].get("town_choice_index", -1)) != 7:
		_fail("0x49b3c1 runtime town choices drifted: %s" % JSON.stringify(runtime_after_towns))
		return
	var placement_steps: Array = coordinate_replay.get("placement_steps", [])
	if placement_steps.size() != 18 \
			or String(placement_steps[0].get("pass", "")) != "0x4a2226_initial_runtime_zone_insertion" \
			or int(placement_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(placement_steps[0].get("selected_candidate", {}).get("x", -1)) != 0 \
			or int(placement_steps[0].get("selected_candidate", {}).get("y", -1)) != 0:
		_fail("Coordinate replay placement-step schedule drifted: %s" % JSON.stringify(placement_steps))
		return

	var terrain_selection: Dictionary = report.get("runtime_terrain_selection_49b53d", {})
	if String(terrain_selection.get("status", "")) != "0x49b53d_runtime_terrain_selection_ported_inspection_only" \
			or String(terrain_selection.get("function_address", "")) != "0x49b53d" \
			or String(terrain_selection.get("town_to_terrain_table_address", "")) != "0x540908" \
			or int(terrain_selection.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or int(terrain_selection.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160:
		_fail("0x49b53d runtime terrain selection identity drifted: %s" % JSON.stringify(terrain_selection))
		return
	if bool(terrain_selection.get("materializes_terrain_cells", true)) \
			or bool(terrain_selection.get("materializes_terrain_art", true)) \
			or bool(terrain_selection.get("materializes_map_cells", true)) \
			or bool(terrain_selection.get("public_package_output_allowed", true)):
		_fail("0x49b53d terrain selection must not materialize map output: %s" % JSON.stringify(terrain_selection))
		return
	if int(terrain_selection.get("selection_count", -1)) != 6 \
			or Array(terrain_selection.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(terrain_selection.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(terrain_selection.get("match_to_town_count", -1)) != 4 \
			or int(terrain_selection.get("allowed_flag_choice_count", -1)) != 2 \
			or int(terrain_selection.get("blank_allowed_mask_count", -1)) != 0 \
			or int(terrain_selection.get("forced_subterranean_count", -1)) != 0 \
			or int(terrain_selection.get("rng_call_count", -1)) != 2 \
			or String(terrain_selection.get("next_materialization_status", "")) != "pending_0x4a3f27_terrain_cell_writeout":
		_fail("0x49b53d terrain selection counts drifted: %s" % JSON.stringify(terrain_selection))
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

	var randomized_line_writer: Dictionary = report.get("randomized_line_writer_4a2413", {})
	if String(randomized_line_writer.get("status", "")) != "0x4a2413_randomized_line_writer_ported_inspection_only" \
			or String(randomized_line_writer.get("function_address", "")) != "0x4a2413" \
			or String(randomized_line_writer.get("caller_address", "")) != "0x4a2777" \
			or String(randomized_line_writer.get("rng_address", "")) != "0x4e7276" \
			or String(randomized_line_writer.get("distance_helper_address", "")) != "0x4cc5ad" \
			or String(randomized_line_writer.get("reserved_flag_mask", "")) != "0x10":
		_fail("0x4a2413 randomized line-writer boundary drifted: %s" % JSON.stringify(randomized_line_writer))
		return
	if bool(randomized_line_writer.get("materializes_boundaries", true)) \
			or bool(randomized_line_writer.get("materializes_span_fill", true)) \
			or bool(randomized_line_writer.get("materializes_terrain", true)) \
			or bool(randomized_line_writer.get("materializes_map_cells", true)) \
			or bool(randomized_line_writer.get("feeds_real_0x4a2777_boundary", true)):
		_fail("0x4a2413 randomized line writer must not materialize generated output yet: %s" % JSON.stringify(randomized_line_writer))
		return
	var randomized_sample: Dictionary = randomized_line_writer.get("sample_contract", {})
	var randomized_trace: Array = randomized_sample.get("trace_preview", [])
	if int(randomized_sample.get("map_width", -1)) != 36 \
			or int(randomized_sample.get("map_height", -1)) != 36 \
			or int(randomized_sample.get("level_count", -1)) != 1 \
			or int(randomized_sample.get("h3maped_water_mode_code", -1)) != 0 \
			or int(randomized_sample.get("from_x", -1)) != 2 \
			or int(randomized_sample.get("from_y", -1)) != 2 \
			or int(randomized_sample.get("to_x", -1)) != 33 \
			or int(randomized_sample.get("to_y", -1)) != 31 \
			or int(randomized_sample.get("level", -1)) != 0 \
			or int(randomized_sample.get("zone_word_id", -1)) != 9 \
			or int(randomized_sample.get("random_span_limit", -1)) != 6 \
			or int(randomized_sample.get("write_count", -1)) != 64 \
			or int(randomized_sample.get("unique_cell_count", -1)) != 63 \
			or int(randomized_sample.get("zone_word_cell_count", -1)) != 63 \
			or int(randomized_sample.get("reserved_flag_write_count", -1)) != 64 \
			or int(randomized_sample.get("reserved_flag_cell_count", -1)) != 63 \
			or int(randomized_sample.get("out_of_bounds_write_count", -1)) != 0 \
			or int(randomized_sample.get("rng_call_count", -1)) != 51 \
			or int(randomized_sample.get("inserted_midpoint_count", -1)) != 63 \
			or int(randomized_sample.get("max_pending_point_count", -1)) < 6 \
			or int(randomized_sample.get("rng_state_after_uint32", -1)) != 3821795434 \
			or randomized_trace.size() != 8 \
			or int(randomized_trace[0].get("x", -1)) != 2 \
			or int(randomized_trace[0].get("y", -1)) != 2:
		_fail("0x4a2413 randomized line-writer sample contract drifted: %s" % JSON.stringify(randomized_line_writer))
		return

	var polygon_split: Dictionary = report.get("polygon_split_model_4ccb64", {})
	if String(polygon_split.get("status", "")) != "0x4ccb64_insertion_bridge_crossing_cleanup_and_finalizer_ported_inspection_only" \
			or String(polygon_split.get("locator_address", "")) != "0x4cca55" \
			or String(polygon_split.get("splitter_address", "")) != "0x4ccb64" \
			or String(polygon_split.get("node_constructor_address", "")) != "0x4cc955" \
			or String(polygon_split.get("node_relink_address", "")) != "0x4cc643" \
			or String(polygon_split.get("edge_side_test_address", "")) != "0x4cc6f2" \
			or String(polygon_split.get("edge_erase_address", "")) != "0x4cc9cc" \
			or String(polygon_split.get("bridge_address", "")) != "0x4ccb1f" \
			or String(polygon_split.get("crossing_test_address", "")) != "0x4ccc7a" \
			or String(polygon_split.get("crossing_collapse_address", "")) != "0x4cc68e" \
			or String(polygon_split.get("intersection_writer_address", "")) != "0x4ccd69" \
			or String(polygon_split.get("finalizer_address", "")) != "0x4ccdfc":
		_fail("0x4ccb64 polygon split/finalizer boundary drifted: %s" % JSON.stringify(polygon_split))
		return
	if not bool(polygon_split.get("materializes_source_node_graph", false)) \
			or bool(polygon_split.get("materializes_boundaries", true)) \
			or bool(polygon_split.get("materializes_span_fill", true)) \
			or bool(polygon_split.get("materializes_terrain", true)) \
			or bool(polygon_split.get("materializes_map_cells", true)) \
			or bool(polygon_split.get("feeds_real_0x4a2777_boundary", true)):
		_fail("0x4ccb64 polygon split model must remain private and not feed generated output yet: %s" % JSON.stringify(polygon_split))
		return
	if int(polygon_split.get("runtime_split_point_count", -1)) != 6 \
			or int(polygon_split.get("executed_split_call_count", -1)) != 6 \
			or int(polygon_split.get("duplicate_skip_count", -1)) != 0 \
			or int(polygon_split.get("edge_removal_branch_count", -1)) != 0 \
			or int(polygon_split.get("pre_crossing_inserted_node_pair_count", -1)) != 6 \
			or int(polygon_split.get("pre_crossing_inserted_bridge_pair_count", -1)) != 12 \
			or int(polygon_split.get("crossing_cleanup_scan_count", -1)) != 34 \
			or int(polygon_split.get("crossing_test_count", -1)) != 24 \
			or int(polygon_split.get("crossing_collapse_count", -1)) != 8 \
			or int(polygon_split.get("initial_node_pair_count", -1)) != 5 \
			or int(polygon_split.get("post_crossing_cleanup_allocated_node_pair_count", -1)) != 23 \
			or int(polygon_split.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(polygon_split.get("post_crossing_cleanup_active_node_count", -1)) != 46 \
			or String(polygon_split.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_crossing_cleanup_ported" \
			or String(polygon_split.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_ported" \
			or int(polygon_split.get("finalized_triplet_count", -1)) != 14 \
			or int(polygon_split.get("finalized_node_count", -1)) != 42 \
			or int(polygon_split.get("active_payload_node_count", -1)) != 28 \
			or String(polygon_split.get("source_node_walk_status", "")) != "0x4cca55_to_0x4a2777_source_node_cycles_recovered_inspection_only" \
			or int(polygon_split.get("source_node_walk_count", -1)) != 6 \
			or int(polygon_split.get("source_node_walk_guard_exhausted_count", -1)) != 0:
		_fail("0x4ccb64 polygon split/finalizer counts drifted: %s" % JSON.stringify(polygon_split))
		return
	var split_steps: Array = polygon_split.get("split_steps", [])
	var source_walks: Array = polygon_split.get("source_node_walks", [])
	var finalized_steps: Array = polygon_split.get("finalized_steps", [])
	if split_steps.size() != 6 \
			or source_walks.size() != 6 \
			or finalized_steps.size() != 14 \
			or int(split_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(split_steps[0].get("x", -1)) != 23 \
			or int(split_steps[0].get("y", -1)) != 11 \
			or bool(split_steps[4].get("edge_removal_branch", true)) \
			or int(split_steps[4].get("bridge_pair_count", -1)) != 2 \
			or int(split_steps[5].get("crossing_collapse_count", -1)) != 2 \
			or int(source_walks[0].get("cycle_node_count", -1)) != 4 \
			or int(source_walks[1].get("cycle_node_count", -1)) != 6 \
			or int(source_walks[5].get("finalized_coordinate_count", -1)) != 5:
		_fail("0x4ccb64 split steps/source-node walks drifted: %s" % JSON.stringify(polygon_split))
		return

	var real_traversal: Dictionary = report.get("real_source_node_cycle_traversal_4a2777", {})
	if String(real_traversal.get("status", "")) != "0x4a2777_real_source_node_cycle_traversal_ported_boundary_buffer_private" \
			or String(real_traversal.get("function_address", "")) != "0x4a2777" \
			or String(real_traversal.get("source_node_cycle_source", "")) != "polygon_split_model_4ccb64.source_node_walks from 0x4cca55 after 0x4ccdfc finalization" \
			or String(real_traversal.get("clip_helper_address", "")) != "0x4a2b33" \
			or String(real_traversal.get("deterministic_line_writer_address", "")) != "0x4a261a" \
			or String(real_traversal.get("flagged_line_writer_address", "")) != "0x4a2413":
		_fail("0x4a2777 real source-node traversal identity drifted: %s" % JSON.stringify(real_traversal))
		return
	if not bool(real_traversal.get("materializes_boundaries", false)) \
			or bool(real_traversal.get("materializes_span_fill", true)) \
			or bool(real_traversal.get("materializes_terrain", true)) \
			or bool(real_traversal.get("materializes_map_cells", true)) \
			or bool(real_traversal.get("public_package_output_allowed", true)) \
			or int(real_traversal.get("project_materialized_cell_count", -1)) != 0:
		_fail("0x4a2777 traversal must remain a private boundary buffer only: %s" % JSON.stringify(real_traversal))
		return
	if int(real_traversal.get("runtime_zone_walk_count", -1)) != 6 \
			or int(real_traversal.get("blocked_zone_count", -1)) != 0 \
			or int(real_traversal.get("fallback_zone_count", -1)) != 0 \
			or int(real_traversal.get("connector_segment_count", -1)) != 6 \
			or int(real_traversal.get("wrap_segment_count", -1)) != 0 \
			or int(real_traversal.get("final_segment_count", -1)) != 12 \
			or int(real_traversal.get("appended_vertex_count", -1)) != 18 \
			or int(real_traversal.get("skipped_unfinalized_node_count", -1)) != 0 \
			or int(real_traversal.get("skipped_out_of_bounds_clip_count", -1)) != 12 \
			or int(real_traversal.get("flagged_writer_segment_count", -1)) != 6 \
			or int(real_traversal.get("deterministic_writer_segment_count", -1)) != 12 \
			or int(real_traversal.get("randomized_rng_call_count", -1)) != 106 \
			or int(real_traversal.get("randomized_inserted_midpoint_count", -1)) != 138 \
			or int(real_traversal.get("randomized_max_pending_point_count", -1)) != 8 \
			or int(real_traversal.get("rng_state_before_0x4a2777_uint32", -1)) != 255755822 \
			or int(real_traversal.get("rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(real_traversal.get("trace_write_count", -1)) != 301 \
			or int(real_traversal.get("unique_cell_count", -1)) != 238 \
			or int(real_traversal.get("out_of_bounds_write_count", -1)) != 0 \
			or bool(real_traversal.get("loop_guard_exhausted", true)):
		_fail("0x4a2777 traversal counts drifted: %s" % JSON.stringify(real_traversal))
		return
	var traversal_zones: Array = real_traversal.get("zone_reports", [])
	if traversal_zones.size() != 6 \
			or String(traversal_zones[0].get("status", "")) != "0x4a2777_real_source_cycle_consumed" \
			or int(traversal_zones[0].get("selected_segment_index", -1)) != 0 \
			or int(traversal_zones[0].get("connector_from_x", -1)) != 18 \
			or int(traversal_zones[0].get("connector_from_y", -1)) != 10 \
			or int(traversal_zones[0].get("connector_to_x", -1)) != 32 \
			or int(traversal_zones[0].get("connector_to_y", -1)) != 0 \
			or int(traversal_zones[0].get("appended_vertex_count", -1)) != 3 \
			or int(traversal_zones[1].get("selected_segment_index", -1)) != 0 \
			or int(traversal_zones[1].get("connector_from_x", -1)) != 18 \
			or int(traversal_zones[1].get("connector_from_y", -1)) != 16 \
			or int(traversal_zones[1].get("connector_to_x", -1)) != 35 \
			or int(traversal_zones[1].get("connector_to_y", -1)) != 20 \
			or int(traversal_zones[1].get("appended_vertex_count", -1)) != 4 \
			or int(traversal_zones[1].get("segment_count", -1)) != 4 \
			or int(traversal_zones[5].get("connector_from_x", -1)) != 18 \
			or int(traversal_zones[5].get("connector_from_y", -1)) != 10 \
			or int(traversal_zones[5].get("connector_to_x", -1)) != 18 \
			or int(traversal_zones[5].get("connector_to_y", -1)) != 16 \
			or int(traversal_zones[5].get("appended_vertex_count", -1)) != 4:
		_fail("0x4a2777 traversal zone cycle reports drifted: %s" % JSON.stringify(traversal_zones))
		return

	var span_fill: Dictionary = report.get("real_boundary_span_fill_4a325d", {})
	if String(span_fill.get("status", "")) != "0x4a325d_real_0x4a2777_boundary_span_fill_ported_private" \
			or String(span_fill.get("function_address", "")) != "0x4a325d" \
			or String(span_fill.get("boundary_source_address", "")) != "0x4a2777" \
			or String(span_fill.get("seed_source", "")) != "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale" \
			or not bool(span_fill.get("uses_real_0x4a2777_boundary", false)):
		_fail("0x4a325d span-fill identity drifted: %s" % JSON.stringify(span_fill))
		return
	if not bool(span_fill.get("materializes_span_fill", false)) \
			or bool(span_fill.get("materializes_terrain", true)) \
			or bool(span_fill.get("materializes_map_cells", true)) \
			or bool(span_fill.get("materializes_package_tiles", true)) \
			or bool(span_fill.get("project_grid_public_runtime_adoption", true)) \
			or bool(span_fill.get("public_package_output_allowed", true)):
		_fail("0x4a325d span-fill must remain private and stop before terrain/package output: %s" % JSON.stringify(span_fill))
		return
	if int(span_fill.get("boundary_unique_cell_count", -1)) != 238 \
			or int(span_fill.get("boundary_trace_write_count", -1)) != 301 \
			or int(span_fill.get("boundary_rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(span_fill.get("runtime_zone_fill_attempt_count", -1)) != 6 \
			or int(span_fill.get("filled_zone_count", -1)) != 6 \
			or int(span_fill.get("seed_blocked_count", -1)) != 1 \
			or int(span_fill.get("missing_seed_count", -1)) != 0 \
			or int(span_fill.get("seed_relocation_count", -1)) != 0 \
			or int(span_fill.get("unique_filled_cell_count", -1)) != 869 \
			or int(span_fill.get("total_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(span_fill.get("remaining_unassigned_cell_count", -1)) != 189 \
			or int(span_fill.get("reserved_flag_cell_count", -1)) != 1107 \
			or int(span_fill.get("pushed_span_count", -1)) != 93 \
			or int(span_fill.get("popped_span_count", -1)) != 93 \
			or int(span_fill.get("max_pending_span_count", -1)) != 3 \
			or int(span_fill.get("out_of_bounds_span_count", -1)) != 0 \
			or int(span_fill.get("blocked_initial_span_count", -1)) != 1:
		_fail("0x4a325d span-fill counts drifted: %s" % JSON.stringify(span_fill))
		return
	var cells_by_zone_word: Dictionary = span_fill.get("cells_by_zone_word", {})
	if int(cells_by_zone_word.get("0", -1)) != 177 \
			or int(cells_by_zone_word.get("1", -1)) != 91 \
			or int(cells_by_zone_word.get("2", -1)) != 226 \
			or int(cells_by_zone_word.get("3", -1)) != 177 \
			or int(cells_by_zone_word.get("4", -1)) != 207 \
			or int(cells_by_zone_word.get("5", -1)) != 229:
		_fail("0x4a325d cells-by-zone distribution drifted: %s" % JSON.stringify(cells_by_zone_word))
		return
	var span_zones: Array = span_fill.get("zone_fill_reports", [])
	if span_zones.size() != 6 \
			or int(span_zones[0].get("seed_x", -1)) != 23 \
			or int(span_zones[0].get("seed_y", -1)) != 11 \
			or int(span_zones[0].get("filled_cell_count", -1)) != 151 \
			or int(span_zones[1].get("seed_x", -1)) != 21 \
			or int(span_zones[1].get("seed_y", -1)) != 22 \
			or int(span_zones[1].get("filled_cell_count", -1)) != 48 \
			or int(span_zones[2].get("filled_cell_count", -1)) != 184 \
			or int(span_zones[3].get("filled_cell_count", -1)) != 127 \
			or int(span_zones[4].get("filled_cell_count", -1)) != 174 \
			or int(span_zones[5].get("seed_x", -1)) != 12 \
			or int(span_zones[5].get("seed_y", -1)) != 11 \
			or int(span_zones[5].get("filled_cell_count", -1)) != 185:
		_fail("0x4a325d per-zone fill reports drifted: %s" % JSON.stringify(span_zones))
		return

	var terrain_writeout: Dictionary = report.get("terrain_cell_writeout_4a3f27", {})
	if String(terrain_writeout.get("status", "")) != "0x4a3f27_terrain_cell_writeout_from_real_0x4a325d_zone_words_ported_inspection_only" \
			or String(terrain_writeout.get("function_address", "")) != "0x4a3f27" \
			or String(terrain_writeout.get("full_map_water_repaint_address", "")) != "0x4a4025" \
			or String(terrain_writeout.get("per_zone_repaint_loop_address", "")) != "0x4a4082" \
			or String(terrain_writeout.get("per_cell_repaint_call_address", "")) != "0x4a415a" \
			or String(terrain_writeout.get("owner_byte_gate_address", "")) != "0x4a4142" \
			or String(terrain_writeout.get("reserved_flag_gate_address", "")) != "0x4a4150" \
			or String(terrain_writeout.get("span_fill_source_address", "")) != "0x4a325d" \
			or String(terrain_writeout.get("tile_serializer_address", "")) != "0x49b2b6":
		_fail("0x4a3f27 terrain writeout identity drifted: %s" % JSON.stringify(terrain_writeout))
		return
	if not bool(terrain_writeout.get("materializes_private_generated_cell_words", false)) \
			or bool(terrain_writeout.get("materializes_terrain_art", true)) \
			or bool(terrain_writeout.get("materializes_roads", true)) \
			or bool(terrain_writeout.get("materializes_objects", true)) \
			or bool(terrain_writeout.get("materializes_package_tiles", true)) \
			or bool(terrain_writeout.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrain_writeout.get("public_package_output_allowed", true)):
		_fail("0x4a3f27 terrain writeout must stay private and stop before art/package output: %s" % JSON.stringify(terrain_writeout))
		return
	if int(terrain_writeout.get("cell_count", -1)) != 1296 \
			or int(terrain_writeout.get("map_width", -1)) != 36 \
			or int(terrain_writeout.get("map_height", -1)) != 36 \
			or int(terrain_writeout.get("level_count", -1)) != 1 \
			or int(terrain_writeout.get("span_fill_total_boundary_or_filled_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("span_fill_remaining_unassigned_cell_count", -1)) != 189 \
			or int(terrain_writeout.get("span_fill_reserved_flag_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("tile_byte_zero_terrain_cell_count", -1)) != 1296 \
			or int(terrain_writeout.get("tile_byte_zero_non_water_terrain_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("tile_byte_one_nonzero_art_cell_count", -1)) != 0 \
			or int(terrain_writeout.get("tile_byte_six_terrain_flip_cell_count", -1)) != 0 \
			or int(terrain_writeout.get("reserved_flag_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("unassigned_water_cell_count", -1)) != 189:
		_fail("0x4a3f27 terrain writeout counts drifted: %s" % JSON.stringify(terrain_writeout))
		return
	var terrain_counts: Dictionary = terrain_writeout.get("terrain_name_counts", {})
	if int(terrain_counts.get("water", -1)) != 189 \
			or int(terrain_counts.get("grass", -1)) != 177 \
			or int(terrain_counts.get("dirt", -1)) != 91 \
			or int(terrain_counts.get("lava", -1)) != 403 \
			or int(terrain_counts.get("swamp", -1)) != 207 \
			or int(terrain_counts.get("rough", -1)) != 229:
		_fail("0x4a3f27 terrain-name distribution drifted: %s" % JSON.stringify(terrain_counts))
		return
	var terrain_code_counts: Dictionary = terrain_writeout.get("h3_terrain_code_counts", {})
	if int(terrain_code_counts.get("8", -1)) != 189 \
			or int(terrain_code_counts.get("2", -1)) != 177 \
			or int(terrain_code_counts.get("0", -1)) != 91 \
			or int(terrain_code_counts.get("7", -1)) != 403 \
			or int(terrain_code_counts.get("4", -1)) != 207 \
			or int(terrain_code_counts.get("5", -1)) != 229:
		_fail("0x4a3f27 h3 terrain-code distribution drifted: %s" % JSON.stringify(terrain_code_counts))
		return
	var repaint_schedule: Dictionary = terrain_writeout.get("terrain_repaint_schedule", {})
	if String(repaint_schedule.get("status", "")) != "0x4a3f27_water_then_zone_single_cell_repaint_schedule_ported_inspection_only" \
			or int(repaint_schedule.get("initial_water_terrain_id", -1)) != 8 \
			or int(repaint_schedule.get("initial_water_full_map_cell_count", -1)) != 1296 \
			or bool(repaint_schedule.get("two_level_rock_prefill_executed", true)) \
			or int(repaint_schedule.get("single_cell_repaint_count", -1)) != 1107 \
			or bool(repaint_schedule.get("materializes_visual_art", true)):
		_fail("0x4a3f27 repaint schedule drifted: %s" % JSON.stringify(repaint_schedule))
		return
	var repaint_by_code: Dictionary = repaint_schedule.get("repaint_cells_by_terrain_code", {})
	var per_zone_repaint: Array = repaint_schedule.get("per_zone_repaint_records", [])
	if int(repaint_by_code.get("2", -1)) != 177 \
			or int(repaint_by_code.get("0", -1)) != 91 \
			or int(repaint_by_code.get("7", -1)) != 403 \
			or int(repaint_by_code.get("4", -1)) != 207 \
			or int(repaint_by_code.get("5", -1)) != 229 \
			or per_zone_repaint.size() != 6 \
			or int(per_zone_repaint[0].get("terrain_code", -1)) != 2 \
			or int(per_zone_repaint[0].get("single_cell_repaint_count", -1)) != 177 \
			or int(per_zone_repaint[1].get("terrain_code", -1)) != 0 \
			or int(per_zone_repaint[1].get("single_cell_repaint_count", -1)) != 91 \
			or int(per_zone_repaint[2].get("terrain_code", -1)) != 7 \
			or int(per_zone_repaint[2].get("single_cell_repaint_count", -1)) != 226 \
			or int(per_zone_repaint[3].get("terrain_code", -1)) != 7 \
			or int(per_zone_repaint[3].get("single_cell_repaint_count", -1)) != 177 \
			or int(per_zone_repaint[4].get("terrain_code", -1)) != 4 \
			or int(per_zone_repaint[4].get("single_cell_repaint_count", -1)) != 207 \
			or int(per_zone_repaint[5].get("terrain_code", -1)) != 5 \
			or int(per_zone_repaint[5].get("single_cell_repaint_count", -1)) != 229:
		_fail("0x4a3f27 per-zone repaint records drifted: %s" % JSON.stringify(repaint_schedule))
		return
	if PackedInt32Array(terrain_writeout.get("terrain_code_u16", PackedInt32Array())).size() != 1296 \
			or PackedInt32Array(terrain_writeout.get("tile_byte_0_terrain_id_u8", PackedInt32Array())).size() != 1296 \
			or PackedInt32Array(terrain_writeout.get("tile_byte_1_terrain_art_u8", PackedInt32Array())).size() != 1296 \
			or PackedInt32Array(terrain_writeout.get("tile_byte_6_flags_u8", PackedInt32Array())).size() != 1296 \
			or String(terrain_writeout.get("tile_byte_writeout_status", "")) != "0x49b2b6_terrain_id_byte_packed_art_flip_pending" \
			or String(terrain_writeout.get("next_materialization_status", "")) != "pending_TerrainPlacement_0x4bcff5_0x4bd099_art_index_flip_writeout":
		_fail("0x4a3f27 terrain arrays/writeout status drifted: %s" % JSON.stringify(terrain_writeout))
		return

	var terrainplacement: Dictionary = report.get("terrainplacement_visual_tables_4bcff5", {})
	if String(terrainplacement.get("status", "")) != "0x4bcff5_terrainplacement_visual_tables_toolkit_ported_inspection_only" \
			or String(terrainplacement.get("terrainplacement_factory_address", "")) != "0x4bcff5" \
			or String(terrainplacement.get("terrainplacement_constructor_address", "")) != "0x4bb5ce" \
			or String(terrainplacement.get("terrainplacement_wrapper_address", "")) != "0x4bd099" \
			or String(terrainplacement.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or String(terrainplacement.get("queue_drain_address", "")) != "0x4bc5f0" \
			or String(terrainplacement.get("visual_selector_address", "")) != "0x4bcfc3" \
			or String(terrainplacement.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(terrainplacement.get("toolkit_table_address", "")) != "0x5436b8":
		_fail("TerrainPlacement visual-table identity drifted: %s" % JSON.stringify(terrainplacement))
		return
	if bool(terrainplacement.get("terrain_art_hash_fallback_allowed", true)) \
			or bool(terrainplacement.get("materializes_visual_record", true)) \
			or bool(terrainplacement.get("materializes_full_terrain_art_grid", true)) \
			or bool(terrainplacement.get("materializes_package_tiles", true)) \
			or bool(terrainplacement.get("project_grid_public_runtime_adoption", true)):
		_fail("TerrainPlacement visual-table boundary must stay executable anchored and inspection only: %s" % JSON.stringify(terrainplacement))
		return
	var toolkit_records: Array = terrainplacement.get("toolkit_constructor_records", [])
	if toolkit_records.size() != 10 \
			or int(toolkit_records[0].get("terrain_id", -1)) != 0 \
			or String(toolkit_records[0].get("table_address", "")) != "0x543380" \
			or int(toolkit_records[2].get("terrain_id", -1)) != 2 \
			or String(toolkit_records[2].get("object_address", "")) != "0x5a3988" \
			or String(toolkit_records[2].get("table_address", "")) != "0x543108" \
			or int(toolkit_records[8].get("terrain_id", -1)) != 8 \
			or String(toolkit_records[8].get("table_address", "")) != "0x5435b0" \
			or int(toolkit_records[9].get("terrain_id", -1)) != 9 \
			or String(toolkit_records[9].get("constructor_address", "")) != "0x4baa66":
		_fail("TerrainPlacement toolkit constructor records drifted: %s" % JSON.stringify(toolkit_records))
		return
	var static_tables: Dictionary = terrainplacement.get("static_table_contracts", {})
	if String(static_tables.get("status", "")) != "h3maped_exe_static_terrain_visual_tables_decoded" \
			or String(static_tables.get("normal_table_address", "")) != "0x543108" \
			or String(static_tables.get("dirt_table_address", "")) != "0x543380" \
			or String(static_tables.get("sand_table_address", "")) != "0x5434f0" \
			or String(static_tables.get("water_table_address", "")) != "0x5435b0" \
			or String(static_tables.get("rock_table_address", "")) != "0x542f88" \
			or int(static_tables.get("table_count", -1)) != 5 \
			or int(static_tables.get("decoded_total_row_count", -1)) != 230 \
			or int(static_tables.get("expected_total_row_count", -1)) != 230:
		_fail("TerrainPlacement static visual table decode drifted: %s" % JSON.stringify(static_tables))
		return
	var tables: Array = static_tables.get("tables", [])
	if tables.size() != 5 \
			or int(tables[0].get("decoded_row_count", -1)) != 79 \
			or int(tables[1].get("decoded_row_count", -1)) != 46 \
			or int(tables[2].get("decoded_row_count", -1)) != 24 \
			or int(tables[3].get("decoded_row_count", -1)) != 33 \
			or int(tables[4].get("decoded_row_count", -1)) != 48:
		_fail("TerrainPlacement static visual table row counts drifted: %s" % JSON.stringify(tables))
		return
	var row_selection: Dictionary = terrainplacement.get("visual_row_selection_contract", {})
	var row_samples: Array = row_selection.get("samples", [])
	if String(row_selection.get("status", "")) != "0x4ba938_0x4ba989_0x4baabf_visual_row_selection_ported_samples" \
			or String(row_selection.get("full_native_selector_address", "")) != "0x4ba938" \
			or String(row_selection.get("normal_transition_selector_address", "")) != "0x4ba989" \
			or String(row_selection.get("rock_selector_address", "")) != "0x4baabf" \
			or int(row_selection.get("sample_count", -1)) != 4 \
			or row_samples.size() != 4:
		_fail("TerrainPlacement row-selection contract drifted: %s" % JSON.stringify(row_selection))
		return
	if String(row_samples[0].get("id", "")) != "normal_full_grass_seed_1" \
			or int(row_samples[0].get("selected_row", -1)) != 60 \
			or int(row_samples[0].get("probability_rng_value", -1)) != 41 \
			or int(row_samples[0].get("art_rng_value", -1)) != 18467 \
			or String(row_samples[1].get("id", "")) != "normal_transition_class_28_seed_1" \
			or int(row_samples[1].get("selected_row", -1)) != 77 \
			or String(row_samples[2].get("id", "")) != "water_transition_class_16_seed_1" \
			or int(row_samples[2].get("selected_row", -1)) != 20 \
			or String(row_samples[3].get("id", "")) != "rock_class_8_flag_1_0_seed_1" \
			or int(row_samples[3].get("selected_row", -1)) != 11 \
			or int(row_samples[3].get("out_flag_a", -1)) != 0 \
			or int(row_samples[3].get("out_flag_b", -1)) != 0:
		_fail("TerrainPlacement row-selection samples drifted: %s" % JSON.stringify(row_samples))
		return
	var scratch_write: Dictionary = terrainplacement.get("scratch_write_contract", {})
	var scratch_samples: Array = scratch_write.get("samples", [])
	if String(scratch_write.get("status", "")) != "0x4bad0f_scratch_word_and_0x49acf6_generated_cell_projection_ported_samples" \
			or String(scratch_write.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(scratch_write.get("generated_cell_write_address", "")) != "0x49acf6" \
			or bool(scratch_write.get("materializes_generated_cell_words", true)) \
			or bool(scratch_write.get("materializes_package_tiles", true)) \
			or int(scratch_write.get("sample_count", -1)) != 4 \
			or scratch_samples.size() != 4:
		_fail("TerrainPlacement scratch/writeback contract drifted: %s" % JSON.stringify(scratch_write))
		return
	if String(scratch_samples[0].get("id", "")) != "grass_full_row_60_flags_0_0" \
			or int(scratch_samples[0].get("scratch_word_u16", -1)) != 1925 \
			or int(scratch_samples[0].get("generated_cell_word_0x24_u32", -1)) != 3842 \
			or int(scratch_samples[0].get("generated_cell_word_0x28_u32", -1)) != 0 \
			or int(scratch_samples[0].get("tile_byte_1_terrain_art", -1)) != 60 \
			or String(scratch_samples[1].get("id", "")) != "grass_class_28_row_77_flags_1_0" \
			or int(scratch_samples[1].get("scratch_word_u16", -1)) != 6565 \
			or int(scratch_samples[1].get("generated_cell_word_0x24_u32", -1)) != 4930 \
			or int(scratch_samples[1].get("generated_cell_word_0x28_u32", -1)) != 32768 \
			or int(scratch_samples[1].get("tile_byte_6_terrain_flags", -1)) != 1 \
			or String(scratch_samples[2].get("id", "")) != "water_class_16_row_20_flags_0_0" \
			or int(scratch_samples[2].get("scratch_word_u16", -1)) != 657 \
			or int(scratch_samples[2].get("tile_byte_0_terrain_id", -1)) != 8 \
			or int(scratch_samples[2].get("tile_byte_1_terrain_art", -1)) != 20 \
			or String(scratch_samples[3].get("id", "")) != "rock_class_8_row_11_cleared_flags" \
			or int(scratch_samples[3].get("scratch_word_u16", -1)) != 371 \
			or int(scratch_samples[3].get("tile_byte_0_terrain_id", -1)) != 9 \
			or int(scratch_samples[3].get("tile_byte_1_terrain_art", -1)) != 11 \
			or int(scratch_samples[3].get("tile_byte_6_terrain_flags", -1)) != 0:
		_fail("TerrainPlacement scratch/writeback samples drifted: %s" % JSON.stringify(scratch_samples))
		return

	var finalizer: Dictionary = report.get("footprint_finalizer_4a3710", {})
	if String(finalizer.get("status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported_private" \
			or String(finalizer.get("function_address", "")) != "0x4a3710" \
			or String(finalizer.get("call_site_address", "")) != "0x4a3efc..0x4a3f05" \
			or String(finalizer.get("polygon_locator_address", "")) != "0x4cca55" \
			or String(finalizer.get("clip_helper_address", "")) != "0x4a2b33" \
			or String(finalizer.get("zone_order_reset_address", "")) != "0x49b61b" \
			or String(finalizer.get("per_zone_order_helper_address", "")) != "0x4a3554" \
			or String(finalizer.get("adjacency_vector_offset", "")) != "runtime_zone+0xc4" \
			or String(finalizer.get("ordering_vector_offset", "")) != "runtime_zone+0x3e8":
		_fail("0x4a3710 finalizer identity drifted: %s" % JSON.stringify(finalizer))
		return
	if int(finalizer.get("level_count", -1)) != 1 \
			or int(finalizer.get("h3maped_water_mode_code", -1)) != 0 \
			or bool(finalizer.get("synthetic_branch_allowed_by_0x4a3a9d", true)) \
			or int(finalizer.get("original_same_level_runtime_zone_count", -1)) != 6 \
			or int(finalizer.get("final_runtime_zone_count", -1)) != 6 \
			or int(finalizer.get("appended_runtime_zone_count", -1)) != 0 \
			or int(finalizer.get("zone_order_reset_call_count", -1)) != 6 \
			or int(finalizer.get("per_zone_order_helper_call_count", -1)) != 6 \
			or int(finalizer.get("materialized_adjacency_count", -1)) != 0:
		_fail("0x4a3710 small-land finalizer counts drifted: %s" % JSON.stringify(finalizer))
		return
	if bool(finalizer.get("materializes_zone_cells", true)) \
			or bool(finalizer.get("materializes_boundary_cells", true)) \
			or bool(finalizer.get("materializes_span_fill", true)) \
			or bool(finalizer.get("materializes_terrain", true)) \
			or bool(finalizer.get("materializes_map_cells", true)) \
			or bool(finalizer.get("public_package_output_allowed", true)):
		_fail("0x4a3710 finalizer must not materialize output: %s" % JSON.stringify(finalizer))
		return
	var finalizer_phases: Array = finalizer.get("phases", [])
	if finalizer_phases.size() != 3 \
			or String(finalizer_phases[0].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or int(finalizer_phases[0].get("start_index", -1)) != 6 \
			or int(finalizer_phases[0].get("end_index", -1)) != 6 \
			or int(finalizer_phases[0].get("materialized_adjacency_insert_count", -1)) != 0 \
			or String(finalizer_phases[1].get("status", "")) != "0x49b61b_reset_and_0x4a3554_rebuild_scheduled" \
			or int(finalizer_phases[1].get("zone_order_reset_call_count", -1)) != 6 \
			or int(finalizer_phases[1].get("per_zone_order_helper_call_count", -1)) != 6 \
			or String(finalizer_phases[2].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or int(finalizer_phases[2].get("materialized_adjacency_insert_count", -1)) != 0:
		_fail("0x4a3710 finalizer phases drifted: %s" % JSON.stringify(finalizer_phases))
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
			or String(backlog[4].get("status", "")) != "active_inspection_only":
		_fail("Zone-footprint and terrain phase should be active only as h3maped inspection evidence: %s" % JSON.stringify(backlog))
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
