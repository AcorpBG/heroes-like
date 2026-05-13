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
			or String(active_state.get("status", "")) != "zone_footprints_active_internal_state" \
			or Array(active_state.get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay", "zone_footprints"] \
			or bool(active_state.get("runtime_generation_allowed", true)) \
			or bool(active_state.get("materializes_runtime_players", true)) \
			or bool(active_state.get("materializes_map_cells", true)) \
			or bool(active_state.get("materializes_public_output", true)) \
			or String(active_state.get("blocked_next", "")) != "terrain_cell_writeout_0x4a3f27":
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
