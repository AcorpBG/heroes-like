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
		_fail("Small h3maped clean-restart inspection did not accept the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_clean_restart_v2":
		_fail("Small h3maped inspection did not use the reset v2 boundary: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "h3maped_small_clean_restart_template_selection_ready":
		_fail("Unexpected small h3maped clean-restart status: %s" % JSON.stringify(report))
		return
	if String(report.get("archive_status", "")) != "previous_native_catalog_auto_generator_archived_debug_only":
		_fail("The previous native catalog-auto generator was not explicitly archived: %s" % JSON.stringify(report))
		return
	if String(report.get("legacy_inspection_ledger_path", "")) != "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp":
		_fail("The old inspection ledger was not moved out of the active h3maped port file: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)):
		_fail("Runtime generation must stay blocked until clean executable phase ports materialize map cells: %s" % JSON.stringify(report))
		return
	if bool(report.get("partial_materialized_payload_public_api", true)) \
			or String(report.get("partial_materialized_payload_status", "")) != "archived_inspection_blocked_not_exported":
		_fail("The reset boundary must not expose a public partial package-generation API: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) or String(binary.get("status", "")) != "verified_reset_anchor":
		_fail("The reset boundary did not verify the local h3maped.exe anchor: %s" % JSON.stringify(report))
		return
	if int(report.get("size_score", -1)) != 1 or int(report.get("h3maped_water_mode_code", -1)) != 0:
		_fail("Small land size score/water code did not follow the recovered formula: %s" % JSON.stringify(report))
		return
	if int(report.get("accepted_template_count", -1)) != 13:
		_fail("Small 1-human/3-player accepted-template vector drifted from recovered catalog evidence: %s" % JSON.stringify(report))
		return
	if String(report.get("selected_template_status", "")) != "h3maped_rng_selected" or int(report.get("selected_template_vector_index", -1)) != 2:
		_fail("The port did not select through the recovered h3maped RNG: %s" % JSON.stringify(report))
		return

	var rng: Dictionary = report.get("h3maped_rng", {})
	if int(rng.get("first_value", -1)) != 41 or int(rng.get("selected_vector_index", -1)) != 2:
		_fail("The recovered h3maped RNG first step drifted from 0x4e7276: %s" % JSON.stringify(report))
		return
	var selected_template: Dictionary = report.get("selected_template", {})
	if String(selected_template.get("id", "")) != "h3maped_template_018":
		_fail("The recovered h3maped RNG selected the wrong accepted template for seed 1: %s" % JSON.stringify(report))
		return

	var selected_payload: Dictionary = report.get("selected_template_payload", {})
	if String(selected_payload.get("status", "")) != "adapted_template_found":
		_fail("The selected h3maped source template was not resolved through adapted-catalog provenance: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("adapted_template_id", "")) != "translated_rmg_template_019_v1":
		_fail("The selected h3maped source template resolved to the wrong adapted template id: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("zone_count", -1)) != 6 or int(selected_payload.get("link_count", -1)) != 5:
		_fail("The selected h3maped source template payload lost zone/link topology: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("player_start_zone_count", -1)) != 4 \
			or int(selected_payload.get("treasure_zone_count", -1)) != 2 \
			or int(selected_payload.get("minimum_player_castles_before_assignment", -1)) != 4:
		_fail("The selected h3maped source template payload lost source roles: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("materialization_status", "")) != "blocked_until_TerrainPlacement_art_index_flip_and_project_grid_adoption":
		_fail("The clean restart must stop before TerrainPlacement/project-grid adoption until the next executable phase is ported: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("assignment_status", "")) != "0x4ac62a_player_slot_assignment_ported":
		_fail("The h3maped player-slot assignment phase did not run: %s" % JSON.stringify(selected_payload))
		return
	var assignment: Dictionary = selected_payload.get("player_slot_assignment", {})
	if String(assignment.get("source", "")).find("0x4ac62a..0x4ac6ec") == -1 \
			or String(assignment.get("selected_color_bitmap_offset", "")) != "generator+0xed8" \
			or String(assignment.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(assignment.get("mapped_slots_offset", "")) != "generator+0xee4":
		_fail("The player-slot assignment report lost executable-derived field evidence: %s" % JSON.stringify(assignment))
		return
	if Array(assignment.get("human_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(assignment.get("player_capable_source_owner_indices", [])) != [0, 1, 2, 3]:
		_fail("The selected template source-owner capability bitmaps drifted: %s" % JSON.stringify(assignment))
		return
	if Array(assignment.get("selected_color_bitmap", [])) != [false, false, false, false, false, false, false, false] \
			or Array(assignment.get("selected_color_order", [])) != [0, 1, 2, 3, 4, 5, 6, 7] \
			or Array(assignment.get("actual_colors_by_source_owner", [])) != [0, 1, 2, -1, -1, -1, -1, -1]:
		_fail("Default selected-color player assignment drifted: %s" % JSON.stringify(assignment))
		return
	var assignments: Array = assignment.get("assignments", [])
	if assignments.size() != 3 \
			or int(assignments[0].get("source_owner_index", -1)) != 0 \
			or int(assignments[0].get("actual_player_color", -1)) != 0 \
			or String(assignments[0].get("player_type", "")) != "human" \
			or int(assignments[1].get("source_owner_index", -1)) != 1 \
			or int(assignments[1].get("actual_player_color", -1)) != 1 \
			or String(assignments[1].get("player_type", "")) != "computer" \
			or int(assignments[2].get("source_owner_index", -1)) != 2 \
			or int(assignments[2].get("actual_player_color", -1)) != 2 \
			or String(assignments[2].get("player_type", "")) != "computer":
		_fail("Default human/computer player assignment slots drifted: %s" % JSON.stringify(assignment))
		return
	if bool(assignment.get("materializes_runtime_players", true)):
		_fail("Player-slot assignment must remain inspection-only until runtime-zone/player materialization is ported: %s" % JSON.stringify(assignment))
		return
	var runtime_zones: Dictionary = selected_payload.get("runtime_zone_build", {})
	if String(selected_payload.get("runtime_zone_build_status", "")) != "0x4a218c_runtime_zone_record_setup_and_0x4a17f5_coordinate_replay_ported" \
			or String(runtime_zones.get("owner_color_mapping_source", "")) != "generator+0xee4" \
			or int(runtime_zones.get("runtime_zone_count", -1)) != 6 \
			or int(runtime_zones.get("assigned_start_zone_count", -1)) != 3 \
			or int(runtime_zones.get("unassigned_start_zone_count", -1)) != 1 \
			or int(runtime_zones.get("treasure_zone_count", -1)) != 2 \
			or int(runtime_zones.get("minimum_player_castles", -1)) != 4:
		_fail("The 0x4a218c runtime-zone setup boundary drifted: %s" % JSON.stringify(runtime_zones))
		return
	if bool(runtime_zones.get("materializes_runtime_zone_coordinates", true)) \
			or bool(runtime_zones.get("materializes_terrain", true)) \
			or bool(runtime_zones.get("materializes_map_cells", true)):
		_fail("Runtime-zone setup must not materialize coordinates, terrain, or cells yet: %s" % JSON.stringify(runtime_zones))
		return
	if Array(runtime_zones.get("actual_owner_colors_by_runtime_zone", [])) != [0, 1, -1, 2, -1, -1]:
		_fail("Runtime-zone owner-color mapping drifted from player assignment: %s" % JSON.stringify(runtime_zones))
		return
	var runtime_records: Array = runtime_zones.get("runtime_zone_records", [])
	if runtime_records.size() != 6 \
			or String(runtime_records[0].get("role", "")) != "human_start" \
			or int(runtime_records[0].get("source_owner_index", -1)) != 0 \
			or int(runtime_records[0].get("actual_owner_color", -2)) != 0 \
			or int(runtime_records[2].get("actual_owner_color", -2)) != -1 \
			or String(runtime_records[2].get("role", "")) != "treasure" \
			or String(runtime_records[0].get("coordinate_status", "")) != "inspection_0x4a17f5_0x4a1701_replay_available":
		_fail("Runtime-zone records lost selected-template/source-owner identity: %s" % JSON.stringify(runtime_zones))
		return
	var early_links: Dictionary = runtime_zones.get("early_link_placement", {})
	if String(runtime_zones.get("early_link_placement_status", "")) != "0x4a1f3b_endpoint_control_flow_ported" \
			or int(early_links.get("link_seed_count", -1)) != 5 \
			or int(early_links.get("creation_pass_count", -1)) != 6 \
			or int(early_links.get("stabilization_pass_count", -1)) != 2 \
			or int(early_links.get("call_count", -1)) != 18 \
			or int(early_links.get("explicit_endpoint_attempt_count", -1)) != 25 \
			or int(early_links.get("fallback_attempt_count_if_no_valid_endpoint", -1)) != 3:
		_fail("The 0x4a1f3b early endpoint schedule drifted: %s" % JSON.stringify(early_links))
		return
	if bool(early_links.get("materializes_coordinates", true)) \
			or bool(early_links.get("materializes_connection_guards", true)):
		_fail("The 0x4a1f3b schedule must not materialize coordinates or guards: %s" % JSON.stringify(early_links))
		return
	var link_seeds: Array = early_links.get("link_seeds", [])
	if link_seeds.size() != 5 \
			or int(link_seeds[0].get("runtime_zone_a", -1)) != 0 \
			or int(link_seeds[0].get("runtime_zone_b", -1)) != 3 \
			or int(link_seeds[3].get("guard_value", -1)) != 6000 \
			or String(link_seeds[0].get("early_consumer", "")) != "0x4a1f3b_endpoint_only" \
			or String(link_seeds[0].get("late_payload_consumer", "")) != "0x4a79a3":
		_fail("The 0x4a1f3b link-seed identity or late payload preservation drifted: %s" % JSON.stringify(early_links))
		return
	var link_calls: Array = early_links.get("calls", [])
	if link_calls.size() != 18 \
			or String(link_calls[0].get("pass", "")) != "creation" \
			or Array(link_calls[3].get("available_endpoint_runtime_zones", [])) != [0] \
			or Array(link_calls[4].get("available_endpoint_runtime_zones", [])) != [1, 3, 2] \
			or String(link_calls[6].get("pass", "")) != "stabilization_1":
		_fail("The 0x4a1f3b creation/stabilization call order drifted: %s" % JSON.stringify(early_links))
		return
	var coordinate_replay: Dictionary = runtime_zones.get("coordinate_replay", {})
	if String(runtime_zones.get("coordinate_replay_status", "")) != "0x4a17f5_0x4a1701_coordinate_candidate_replay_ported" \
			or not bool(coordinate_replay.get("ok", false)) \
			or int(coordinate_replay.get("placement_step_count", -1)) != 18 \
			or int(coordinate_replay.get("town_rng_calls_during_0x49b452", -1)) != 4 \
			or int(coordinate_replay.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18 \
			or int(coordinate_replay.get("rng_event_count", -1)) != 22:
		_fail("The 0x4a17f5 coordinate replay drifted: %s" % JSON.stringify(coordinate_replay))
		return
	if bool(coordinate_replay.get("materializes_map_cells", true)) \
			or bool(coordinate_replay.get("materializes_zone_footprints", true)):
		_fail("Coordinate replay must not materialize cells or footprints: %s" % JSON.stringify(coordinate_replay))
		return
	var coordinate_bbox: Dictionary = coordinate_replay.get("bounding_box_rescale", {})
	if int(coordinate_bbox.get("selected_span_before_rescale", -1)) != 84 \
			or int(coordinate_bbox.get("map_span", -1)) != 36:
		_fail("The 0x4a19ed coordinate bbox rescale drifted: %s" % JSON.stringify(coordinate_replay))
		return
	var terrain_selection: Dictionary = runtime_zones.get("terrain_selection", {})
	if String(runtime_zones.get("terrain_selection_status", "")) != "0x49b53d_runtime_terrain_selection_ported" \
			or int(terrain_selection.get("selection_count", -1)) != 6 \
			or int(terrain_selection.get("match_to_town_count", -1)) != 4 \
			or int(terrain_selection.get("allowed_flag_choice_count", -1)) != 2 \
			or int(terrain_selection.get("rng_call_count", -1)) != 2:
		_fail("The 0x49b53d runtime terrain selection drifted: %s" % JSON.stringify(terrain_selection))
		return
	if bool(terrain_selection.get("materializes_terrain_cells", true)) \
			or bool(terrain_selection.get("materializes_terrain_art", true)):
		_fail("Runtime terrain selection must not paint cells or terrain art yet: %s" % JSON.stringify(terrain_selection))
		return
	if Array(terrain_selection.get("selected_project_terrain_ids", [])) != ["dirt", "dirt", "snow", "grass", "dirt", "rough"]:
		_fail("The selected runtime terrain sequence drifted: %s" % JSON.stringify(terrain_selection))
		return
	var footprint_schedule: Dictionary = runtime_zones.get("zone_footprint_schedule", {})
	if String(runtime_zones.get("zone_footprint_schedule_status", "")) != "0x4a3a03_zone_footprint_schedule_ported" \
			or int(footprint_schedule.get("level_count", -1)) != 1 \
			or int(footprint_schedule.get("h3maped_water_mode_code", -1)) != 0 \
			or int(footprint_schedule.get("total_matching_runtime_zones", -1)) != 6 \
			or int(footprint_schedule.get("total_polygon_split_calls", -1)) != 6 \
			or int(footprint_schedule.get("appended_synthetic_runtime_zone_count", -1)) != 0:
		_fail("The 0x4a3a03 zone footprint schedule drifted: %s" % JSON.stringify(footprint_schedule))
		return
	if bool(footprint_schedule.get("materializes_zone_cells", true)) \
			or bool(footprint_schedule.get("materializes_boundary_cells", true)) \
			or bool(footprint_schedule.get("materializes_span_fill", true)):
		_fail("Zone footprint scheduling must not materialize cells yet: %s" % JSON.stringify(footprint_schedule))
		return
	var polygon_seed: Dictionary = footprint_schedule.get("polygon_seed", {})
	var polygon_bounds: Dictionary = polygon_seed.get("initial_bounds", {})
	var polygon_edges: Array = polygon_seed.get("initial_edges", [])
	if String(footprint_schedule.get("polygon_seed_status", "")) != "0x4cc788_initial_source_node_bounds_ported_inspection_only" \
			or String(footprint_schedule.get("polygon_constructor_address", "")) != "0x4cc788" \
			or String(footprint_schedule.get("polygon_split_address", "")) != "0x4ccb64" \
			or String(footprint_schedule.get("polygon_finalize_address", "")) != "0x4ccdfc" \
			or String(footprint_schedule.get("polygon_locator_address", "")) != "0x4cca55" \
			or int(polygon_bounds.get("min_x", 0)) != -200 \
			or int(polygon_bounds.get("min_y", 0)) != -200 \
			or int(polygon_bounds.get("max_x", 0)) != 400 \
			or int(polygon_bounds.get("max_y", 0)) != 400 \
			or int(polygon_seed.get("initial_edge_count", -1)) != 4 \
			or polygon_edges.size() != 4:
		_fail("The 0x4cc788 source-node seed bounds drifted: %s" % JSON.stringify(footprint_schedule))
		return
	if bool(polygon_seed.get("materializes_project_grid", true)) \
			or bool(polygon_seed.get("feeds_real_0x4a2777_boundary", true)):
		_fail("The 0x4cc788 seed report must remain inspection-only until split/finalize traversal is ported: %s" % JSON.stringify(polygon_seed))
		return
	var first_polygon_edge: Dictionary = polygon_edges[0]
	var last_polygon_edge: Dictionary = polygon_edges[3]
	if int(first_polygon_edge.get("from_x", 0)) != -200 \
			or int(first_polygon_edge.get("from_y", 0)) != -200 \
			or int(first_polygon_edge.get("to_x", 0)) != 400 \
			or int(first_polygon_edge.get("to_y", 0)) != -200 \
			or int(last_polygon_edge.get("from_x", 0)) != -200 \
			or int(last_polygon_edge.get("from_y", 0)) != 400 \
			or int(last_polygon_edge.get("to_x", 0)) != -200 \
			or int(last_polygon_edge.get("to_y", 0)) != -200:
		_fail("The 0x4cc788 initial source-node edge order drifted: %s" % JSON.stringify(polygon_seed))
		return
	var polygon_split: Dictionary = footprint_schedule.get("polygon_split", {})
	var polygon_split_calls: Array = polygon_split.get("scheduled_calls", [])
	if String(footprint_schedule.get("polygon_split_status", "")) != "0x4ccb64_locator_insertion_cleanup_ported_inspection_only" \
			or int(polygon_split.get("scheduled_split_call_count", -1)) != 6 \
			or int(polygon_split.get("locator_call_count", -1)) != 6 \
			or int(polygon_split.get("locator_materialized_count", -1)) != 6 \
			or int(polygon_split.get("locator_guard_failed_count", -1)) != 0 \
			or int(polygon_split.get("duplicate_skip_count", -1)) != 0 \
			or int(polygon_split.get("executed_split_call_count", -1)) != 6 \
			or int(polygon_split.get("pre_crossing_inserted_node_pair_count", -1)) != 6 \
			or int(polygon_split.get("pre_crossing_inserted_bridge_pair_count", -1)) != 12 \
			or int(polygon_split.get("first_pre_crossing_insertion_count", -1)) != 1 \
			or int(polygon_split.get("first_pre_crossing_bridge_pair_count", -1)) <= 0 \
			or int(polygon_split.get("first_post_pre_crossing_allocated_node_pair_count", -1)) <= 5 \
			or int(polygon_split.get("first_post_pre_crossing_active_node_pair_count", -1)) <= 5 \
			or int(polygon_split.get("first_post_crossing_cleanup_allocated_node_pair_count", -1)) <= 5 \
			or int(polygon_split.get("first_post_crossing_cleanup_active_node_pair_count", -1)) <= 5 \
			or int(polygon_split.get("first_crossing_cleanup_scan_count", -1)) <= 0 \
			or bool(polygon_split.get("first_crossing_cleanup_guard_exhausted", true)) \
			or int(polygon_split.get("post_crossing_cleanup_allocated_node_pair_count", -1)) != 23 \
			or int(polygon_split.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(polygon_split.get("crossing_cleanup_scan_count", -1)) != 34 \
			or int(polygon_split.get("crossing_test_count", -1)) != 24 \
			or int(polygon_split.get("crossing_collapse_count", -1)) != 8 \
			or bool(polygon_split.get("crossing_cleanup_guard_exhausted", true)) \
			or String(polygon_split.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_all_scheduled_crossing_cleanup_materialized" \
			or not bool(polygon_split.get("duplicate_endpoint_guard_materialized", false)) \
			or not bool(polygon_split.get("materializes_source_node_graph", false)) \
			or not bool(polygon_split.get("materializes_first_source_node_graph_mutation", false)) \
			or not bool(polygon_split.get("materializes_first_crossing_cleanup", false)) \
			or String(polygon_split.get("function_address", "")) != "0x4ccb64" \
			or String(polygon_split.get("locator_address", "")) != "0x4cca55" \
			or String(polygon_split.get("node_constructor_address", "")) != "0x4cc955" \
			or String(polygon_split.get("crossing_test_address", "")) != "0x4ccc7a" \
			or String(polygon_split.get("intersection_helper_address", "")) != "0x4ccd69" \
			or polygon_split_calls.size() != 6:
		_fail("The 0x4ccb64 split insertion gate drifted: %s" % JSON.stringify(polygon_split))
		return
	var first_polygon_split_call: Dictionary = polygon_split_calls[0]
	var second_polygon_split_call: Dictionary = polygon_split_calls[1]
	if String(first_polygon_split_call.get("locator_status", "")) != "0x4cca55_initial_graph_locator_materialized" \
			or String(first_polygon_split_call.get("duplicate_endpoint_guard_result", "")) != "0x4ccb64_not_duplicate_endpoint" \
			or String(first_polygon_split_call.get("insertion_status", "")) != "0x4ccb64_first_split_pre_crossing_inserted" \
			or int(first_polygon_split_call.get("bridge_pair_count", -1)) <= 0 \
			or bool(first_polygon_split_call.get("bridge_loop_guard_exhausted", true)) \
			or String(first_polygon_split_call.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_crossing_cleanup_materialized" \
			or int(first_polygon_split_call.get("crossing_cleanup_scan_count", -1)) <= 0 \
			or int(first_polygon_split_call.get("allocated_node_pair_count_after_crossing_cleanup", -1)) <= 5 \
			or int(first_polygon_split_call.get("active_node_pair_count_after_crossing_cleanup", -1)) <= 5 \
			or bool(first_polygon_split_call.get("crossing_cleanup_guard_exhausted", true)) \
			or String(first_polygon_split_call.get("located_node_id", "")) == "" \
			or String(first_polygon_split_call.get("located_pair_id", "")) == "" \
			or String(second_polygon_split_call.get("locator_status", "")) != "0x4cca55_current_graph_locator_materialized" \
			or String(second_polygon_split_call.get("insertion_status", "")) != "0x4ccb64_split_pre_crossing_inserted" \
			or int(second_polygon_split_call.get("crossing_cleanup_scan_count", -1)) <= 0 \
			or bool(second_polygon_split_call.get("crossing_cleanup_guard_exhausted", true)):
		_fail("The 0x4cca55/0x4ccb64 locator and cleanup materialization drifted: %s" % JSON.stringify(polygon_split))
		return
	if bool(polygon_split.get("feeds_real_0x4a2777_boundary", true)):
		_fail("The 0x4ccb64 split graph must not feed 0x4a2777 until finalizer traversal is ported: %s" % JSON.stringify(polygon_split))
		return
	var polygon_finalizer: Dictionary = footprint_schedule.get("polygon_finalizer", {})
	if String(footprint_schedule.get("polygon_finalizer_status", "")) != "0x4ccdfc_source_node_finalizer_materialized_inspection_only" \
			or String(polygon_finalizer.get("function_address", "")) != "0x4ccdfc" \
			or String(polygon_finalizer.get("intersection_helper_address", "")) != "0x4ccd69" \
			or int(polygon_finalizer.get("scheduled_split_call_count", -1)) != 6 \
			or not bool(polygon_finalizer.get("eligible_node_scan_materialized", false)) \
			or not bool(polygon_finalizer.get("finalized_coordinate_write_materialized", false)) \
			or bool(polygon_finalizer.get("split_graph_blocked", true)) \
			or int(polygon_finalizer.get("split_graph_executed_split_call_count", -1)) != 6 \
			or int(polygon_finalizer.get("split_graph_locator_materialized_count", -1)) != 6 \
			or int(polygon_finalizer.get("split_graph_crossing_cleanup_scan_count", -1)) != 34 \
			or int(polygon_finalizer.get("split_graph_crossing_test_count", -1)) != 24 \
			or int(polygon_finalizer.get("split_graph_crossing_collapse_count", -1)) != 8 \
			or int(polygon_finalizer.get("split_graph_active_node_pair_count", -1)) != 23 \
			or String(polygon_finalizer.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_materialized" \
			or int(polygon_finalizer.get("finalized_triplet_count", -1)) != 14 \
			or int(polygon_finalizer.get("finalized_node_count", -1)) != 42 \
			or int(polygon_finalizer.get("active_payload_node_count", -1)) != 28 \
			or String(polygon_finalizer.get("source_node_walk_status", "")) != "0x4cca55_to_0x4a2777_source_node_cycles_recovered" \
			or int(polygon_finalizer.get("source_node_walk_count", -1)) != 6 \
			or int(polygon_finalizer.get("source_node_walk_guard_exhausted_count", -1)) != 0 \
			or int(polygon_finalizer.get("source_node_walk_finalized_coordinate_count", -1)) <= 0 \
			or Array(polygon_finalizer.get("write_sequence", [])).size() != 6:
		_fail("The 0x4ccdfc source-node finalizer gate drifted: %s" % JSON.stringify(polygon_finalizer))
		return
	if not bool(polygon_finalizer.get("materializes_source_node_graph", false)) \
			or not bool(polygon_finalizer.get("materializes_finalized_cycles", false)) \
			or bool(polygon_finalizer.get("feeds_real_0x4a2777_boundary", true)):
		_fail("The 0x4ccdfc finalizer must materialize finalized cycles but must not feed 0x4a2777 yet: %s" % JSON.stringify(polygon_finalizer))
		return
	var boundary_traversal: Dictionary = footprint_schedule.get("boundary_traversal", {})
	if String(footprint_schedule.get("boundary_traversal_status", "")) != "0x4a2777_real_source_node_cycle_traversal_ported_boundary_materialized" \
			or int(boundary_traversal.get("runtime_zone_walk_count", -1)) != 6 \
			or int(boundary_traversal.get("blocked_zone_count", -1)) != 0 \
			or int(boundary_traversal.get("fallback_zone_count", -1)) != 0 \
			or int(boundary_traversal.get("connector_segment_count", -1)) != 6 \
			or int(boundary_traversal.get("final_segment_count", -1)) != 12 \
			or int(boundary_traversal.get("wrap_segment_count", -1)) != 0 \
			or int(boundary_traversal.get("appended_vertex_count", -1)) != 18 \
			or int(boundary_traversal.get("flagged_writer_segment_count", -1)) != 6 \
			or int(boundary_traversal.get("deterministic_writer_segment_count", -1)) != 12 \
			or int(boundary_traversal.get("randomized_rng_call_count", -1)) != 101 \
			or int(boundary_traversal.get("randomized_inserted_midpoint_count", -1)) != 130 \
			or int(boundary_traversal.get("trace_write_count", -1)) != 293 \
			or int(boundary_traversal.get("unique_cell_count", -1)) != 221 \
			or int(boundary_traversal.get("reserved_flag_cell_count", -1)) != 221 \
			or int(boundary_traversal.get("out_of_bounds_write_count", -1)) != 0 \
			or bool(boundary_traversal.get("loop_guard_exhausted", true)) \
			or not bool(boundary_traversal.get("uses_real_source_node_walk", false)) \
			or bool(boundary_traversal.get("feeds_0x4a325d_span_fill", true)) \
			or bool(boundary_traversal.get("materializes_project_grid", true)):
		_fail("The real 0x4a2777 finalized-cycle boundary traversal drifted: %s" % JSON.stringify(boundary_traversal))
		return
	var real_span_fill: Dictionary = footprint_schedule.get("real_span_fill", {})
	var cells_by_zone_word: Dictionary = real_span_fill.get("cells_by_zone_word", {})
	var zone_fill_reports: Array = real_span_fill.get("zone_fill_reports", [])
	if String(footprint_schedule.get("real_span_fill_status", "")) != "0x4a325d_real_0x4a2777_boundary_span_fill_executed" \
			or int(real_span_fill.get("boundary_unique_cell_count", -1)) != 221 \
			or int(real_span_fill.get("runtime_zone_fill_attempt_count", -1)) != 6 \
			or int(real_span_fill.get("filled_zone_count", -1)) != 6 \
			or int(real_span_fill.get("seed_blocked_count", -1)) != 1 \
			or int(real_span_fill.get("missing_seed_count", -1)) != 0 \
			or String(real_span_fill.get("seed_relocation_status", "")) != "0x4a32b2_relocation_ported_not_needed_for_current_in_bounds_seed_span_scan" \
			or int(real_span_fill.get("unique_filled_cell_count", -1)) != 890 \
			or int(real_span_fill.get("total_boundary_or_filled_cell_count", -1)) != 1111 \
			or int(real_span_fill.get("remaining_unassigned_cell_count", -1)) != 185 \
			or int(real_span_fill.get("reserved_flag_cell_count", -1)) != 1111 \
			or int(real_span_fill.get("pushed_span_count", -1)) != 88 \
			or int(real_span_fill.get("popped_span_count", -1)) != 88 \
			or int(real_span_fill.get("max_pending_span_count", -1)) != 4 \
			or int(real_span_fill.get("out_of_bounds_span_count", -1)) != 0 \
			or int(real_span_fill.get("blocked_initial_span_count", -1)) != 0 \
			or not bool(real_span_fill.get("uses_real_0x4a2777_boundary", false)) \
			or bool(real_span_fill.get("materializes_project_grid", true)):
		_fail("The real 0x4a325d span fill over the 0x4a2777 boundary drifted: %s" % JSON.stringify(real_span_fill))
		return
	if int(cells_by_zone_word.get("0", -1)) != 174 \
			or int(cells_by_zone_word.get("1", -1)) != 112 \
			or int(cells_by_zone_word.get("2", -1)) != 222 \
			or int(cells_by_zone_word.get("3", -1)) != 165 \
			or int(cells_by_zone_word.get("4", -1)) != 206 \
			or int(cells_by_zone_word.get("5", -1)) != 232:
		_fail("The real 0x4a325d zone-word cell distribution drifted: %s" % JSON.stringify(real_span_fill))
		return
	if zone_fill_reports.size() != 6 \
			or int(zone_fill_reports[0].get("filled_cell_count", -1)) != 152 \
			or int(zone_fill_reports[1].get("filled_cell_count", -1)) != 69 \
			or String(zone_fill_reports[2].get("status", "")) != "0x4a325d_span_fill_executed" \
			or String(zone_fill_reports[2].get("seed_relocation_status", "")) != "0x4a325d_seed_in_bounds_relocation_not_used" \
			or bool(zone_fill_reports[2].get("seed_unassigned_before_fill", true)) \
			or int(zone_fill_reports[2].get("filled_cell_count", -1)) != 184 \
			or int(zone_fill_reports[3].get("filled_cell_count", -1)) != 126 \
			or int(zone_fill_reports[4].get("filled_cell_count", -1)) != 174 \
			or int(zone_fill_reports[5].get("filled_cell_count", -1)) != 185:
		_fail("The real 0x4a325d per-zone fill reports drifted: %s" % JSON.stringify(real_span_fill))
		return
	var terrain_cell_writeout: Dictionary = footprint_schedule.get("terrain_cell_writeout", {})
	var terrain_counts: Dictionary = terrain_cell_writeout.get("terrain_name_counts", {})
	var h3_terrain_counts: Dictionary = terrain_cell_writeout.get("h3_terrain_code_counts", {})
	var terrain_grid: Dictionary = terrain_cell_writeout.get("terrain_grid", {})
	var terrain_levels: Array = terrain_grid.get("levels", [])
	var terrain_codes: PackedInt32Array = terrain_cell_writeout.get("terrain_code_u16", PackedInt32Array())
	var generated_cell_0x24: PackedInt32Array = terrain_cell_writeout.get("generated_cell_word_0x24_u32", PackedInt32Array())
	var generated_cell_0x28: PackedInt32Array = terrain_cell_writeout.get("generated_cell_word_0x28_u32", PackedInt32Array())
	var tile_byte_0: PackedInt32Array = terrain_cell_writeout.get("tile_byte_0_terrain_id_u8", PackedInt32Array())
	var tile_byte_1: PackedInt32Array = terrain_cell_writeout.get("tile_byte_1_terrain_art_u8", PackedInt32Array())
	var tile_byte_6: PackedInt32Array = terrain_cell_writeout.get("tile_byte_6_flags_u8", PackedInt32Array())
	var tile_serializer_contract: Dictionary = terrain_cell_writeout.get("tile_serializer_contract", {})
	var terrain_art_blocker: Dictionary = terrain_cell_writeout.get("terrain_art_index_flip_blocker", {})
	var terrain_art_required_addresses: Array = terrain_art_blocker.get("required_addresses", [])
	var terrain_repaint_boundary: Dictionary = terrain_art_blocker.get("terrainplacement_repaint_boundary", {})
	var changed_cell_update: Dictionary = terrain_repaint_boundary.get("changed_cell_update", {})
	var visual_classifier: Dictionary = changed_cell_update.get("visual_classifier", {})
	var visual_classifier_toolkit_objects: Array = visual_classifier.get("toolkit_object_addresses", [])
	var visual_classifier_vtables: Array = visual_classifier.get("toolkit_vtable_addresses", [])
	var visual_classifier_static_tables: Array = visual_classifier.get("static_visual_table_addresses", [])
	var visual_classifier_constructor_records: Array = visual_classifier.get("toolkit_constructor_records", [])
	var visual_static_lookup_contract: Dictionary = visual_classifier.get("static_range_lookup_contract", {})
	var copyback_gate: Dictionary = changed_cell_update.get("copyback_gate", {})
	var adapter_writeback: Dictionary = copyback_gate.get("adapter_writeback", {})
	if String(footprint_schedule.get("terrain_cell_writeout_status", "")) != "0x4a3f27_terrain_cell_writeout_from_real_0x4a325d_zone_words_ported_inspection_only" \
			or int(terrain_cell_writeout.get("cell_count", -1)) != 1296 \
			or int(terrain_cell_writeout.get("tile_byte_zero_terrain_cell_count", -1)) != 1296 \
			or int(terrain_cell_writeout.get("tile_byte_zero_non_water_terrain_cell_count", -1)) != 1111 \
			or int(terrain_cell_writeout.get("tile_byte_one_nonzero_art_cell_count", -1)) != 0 \
			or int(terrain_cell_writeout.get("tile_byte_six_terrain_flip_cell_count", -1)) != 0 \
			or int(terrain_cell_writeout.get("reserved_flag_cell_count", -1)) != 1111 \
			or int(terrain_cell_writeout.get("unassigned_water_cell_count", -1)) != 185 \
			or String(terrain_cell_writeout.get("tile_byte_writeout_status", "")) != "0x49b2b6_terrain_id_byte_packed_art_flip_pending" \
			or String(terrain_cell_writeout.get("tile_serializer_contract_status", "")) != "0x49b2b6_generated_cell_tile_serializer_bit_contract_ported" \
			or String(terrain_cell_writeout.get("terrain_art_index_flip_status", "")) != "pending_TerrainPlacement_0x4bcff5_0x4bd099_art_index_flip_writeout" \
			or not bool(terrain_cell_writeout.get("materializes_project_grid", false)) \
			or bool(terrain_cell_writeout.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrain_cell_writeout.get("materializes_package_tiles", true)):
		_fail("The 0x4a3f27 terrain-cell writeout inspection drifted: %s" % JSON.stringify(terrain_cell_writeout))
		return
	if terrain_codes.size() != 1296 \
			or generated_cell_0x24.size() != 1296 \
			or generated_cell_0x28.size() != 1296 \
			or tile_byte_0.size() != 1296 \
			or tile_byte_1.size() != 1296 \
			or tile_byte_6.size() != 1296 \
			or tile_byte_0 != terrain_codes \
			or generated_cell_0x24 != terrain_codes:
		_fail("The 0x49b2b6 terrain byte-zero inspection arrays drifted: %s" % JSON.stringify(terrain_cell_writeout))
		return
	if String(tile_serializer_contract.get("status", "")) != "0x49b2b6_generated_cell_tile_serializer_bit_contract_ported" \
			or Array(tile_serializer_contract.get("sample_expected_tile_bytes", [])) != [7, 171, 12, 93, 9, 110, 91] \
			or int(tile_serializer_contract.get("sample_expected_tile_byte_count", -1)) != 7 \
			or bool(tile_serializer_contract.get("materializes_package_tiles", true)):
		_fail("The 0x49b2b6 serializer bit contract drifted: %s" % JSON.stringify(tile_serializer_contract))
		return
	if String(terrain_art_blocker.get("status", "")) != "blocked_until_exact_h3maped_TerrainPlacement_classifier_recovered" \
			or bool(terrain_art_blocker.get("legacy_visual_classifier_reuse_allowed", true)) \
			or not terrain_art_required_addresses.has("0x4bcff5") \
			or not terrain_art_required_addresses.has("0x4bd099") \
			or not terrain_art_required_addresses.has("0x4bb681") \
			or not terrain_art_required_addresses.has("0x49b2b6"):
		_fail("The clean port must reject legacy hashed TerrainPlacement art/flip approximation: %s" % JSON.stringify(terrain_art_blocker))
		return
	if String(terrain_repaint_boundary.get("status", "")) != "0x4bd099_0x4bb681_TerrainPlacement_repaint_rectangle_loop_recovered_boundary_only" \
			or String(terrain_repaint_boundary.get("constructor_address", "")) != "0x4bb5ce" \
			or String(terrain_repaint_boundary.get("wrapper_address", "")) != "0x4bd099" \
			or String(terrain_repaint_boundary.get("rectangle_loop_address", "")) != "0x4bb681" \
			or String(terrain_repaint_boundary.get("cell_ensure_address", "")) != "0x4bb71b" \
			or String(terrain_repaint_boundary.get("changed_cell_update_address", "")) != "0x4bb74b" \
			or bool(terrain_repaint_boundary.get("materializes_art_flip", true)):
		_fail("The TerrainPlacement repaint boundary evidence drifted: %s" % JSON.stringify(terrain_repaint_boundary))
		return
	if String(changed_cell_update.get("status", "")) != "0x4bb74b_changed_cell_update_boundary_recovered_no_art_flip_materialization" \
			or String(changed_cell_update.get("entry_address", "")) != "0x4bb74b" \
			or String(changed_cell_update.get("visual_record_resolve_address", "")) != "0x4bcfc3" \
			or String(changed_cell_update.get("visual_record_table_address", "")) != "0x5436b8" \
			or String(changed_cell_update.get("scratch_write_address", "")) != "0x4bad0f" \
			or String(changed_cell_update.get("neighbor_touch_address", "")) != "0x4bba59" \
			or String(changed_cell_update.get("fallback_neighbor_table_range", "")) != "0x5a5028..0x5a5068" \
			or bool(changed_cell_update.get("materializes_tile_byte_1", true)) \
			or bool(changed_cell_update.get("materializes_tile_byte_6_terrain_flags", true)):
		_fail("The TerrainPlacement changed-cell update evidence drifted: %s" % JSON.stringify(changed_cell_update))
		return
	if String(visual_classifier.get("status", "")) != "0x4bcfc3_0x4bce6d_toolkit_visual_selector_recovered_boundary_only" \
			or String(visual_classifier.get("selector_address", "")) != "0x4bcfc3" \
			or String(visual_classifier.get("neighbor_mask_address", "")) != "0x4bce6d" \
			or String(visual_classifier.get("toolkit_table_address", "")) != "0x5436b8" \
			or String(visual_classifier.get("toolkit_constructor_address", "")) != "0x4ba868" \
			or String(visual_classifier.get("simple_toolkit_constructor_address", "")) != "0x4ba9c8" \
			or String(visual_classifier.get("simple_toolkit_zero_constructor_address", "")) != "0x4baa66" \
			or String(visual_classifier.get("neighbor_probe_vfunc_offset", "")) != "+0x08" \
			or String(visual_classifier.get("visual_record_resolve_vfunc_offset", "")) != "+0x10" \
			or String(visual_classifier.get("complex_toolkit_vtable_address", "")) != "0x543780" \
			or String(visual_classifier.get("complex_neighbor_probe_vfunc_plus_0x08", "")) != "0x4ba91d" \
			or String(visual_classifier.get("complex_direct_record_reader_vfunc_plus_0x0c", "")) != "0x4ba92b" \
			or String(visual_classifier.get("complex_visual_resolve_vfunc_plus_0x10", "")) != "0x4ba938" \
			or String(visual_classifier.get("complex_visual_writeback_vfunc_plus_0x14", "")) != "0x4ba989" \
			or String(visual_classifier.get("simple_toolkit_vtable_address", "")) != "0x54379c" \
			or String(visual_classifier.get("simple_neighbor_probe_vfunc_plus_0x08", "")) != "0x4baa81" \
			or String(visual_classifier.get("simple_direct_record_reader_vfunc_plus_0x0c", "")) != "0x4baa86" \
			or String(visual_classifier.get("simple_visual_resolve_vfunc_plus_0x10", "")) != "0x4baa94" \
			or String(visual_classifier.get("simple_visual_writeback_vfunc_plus_0x14", "")) != "0x4baabf" \
			or visual_classifier_toolkit_objects.size() != 10 \
			or not visual_classifier_toolkit_objects.has("0x5a4130") \
			or not visual_classifier_toolkit_objects.has("0x5a4128") \
			or not visual_classifier_vtables.has("0x543780") \
			or not visual_classifier_vtables.has("0x54379c") \
			or not visual_classifier_static_tables.has("0x543108") \
			or not visual_classifier_static_tables.has("0x543380") \
			or bool(visual_classifier.get("materializes_visual_record", true)):
		_fail("The TerrainPlacement visual classifier selector evidence drifted: %s" % JSON.stringify(visual_classifier))
		return
	if visual_classifier_constructor_records.size() != 10:
		_fail("The TerrainPlacement toolkit constructor record count drifted: %s" % JSON.stringify(visual_classifier_constructor_records))
		return
	var first_toolkit_constructor: Dictionary = visual_classifier_constructor_records[0]
	var simple_toolkit_constructor: Dictionary = visual_classifier_constructor_records[9]
	if String(first_toolkit_constructor.get("object_address", "")) != "0x5a4130" \
			or String(first_toolkit_constructor.get("constructor_address", "")) != "0x4ba868" \
			or int(first_toolkit_constructor.get("terrain_id", -1)) != 0 \
			or int(first_toolkit_constructor.get("range_probability", -1)) != 0x32 \
			or int(first_toolkit_constructor.get("row_count", -1)) != 0x2e \
			or String(first_toolkit_constructor.get("table_address", "")) != "0x543380" \
			or String(simple_toolkit_constructor.get("object_address", "")) != "0x5a4128" \
			or String(simple_toolkit_constructor.get("constructor_address", "")) != "0x4baa66" \
			or String(simple_toolkit_constructor.get("table_address", "")) != "none":
		_fail("The TerrainPlacement toolkit constructor inputs drifted: %s" % JSON.stringify(visual_classifier_constructor_records))
		return
	if String(visual_static_lookup_contract.get("status", "")) != "0x4ba868_0x4ba938_static_range_lookup_contract_ported_sample" \
			or String(visual_static_lookup_contract.get("constructor_address", "")) != "0x4ba868" \
			or String(visual_static_lookup_contract.get("resolve_address", "")) != "0x4ba938" \
			or String(visual_static_lookup_contract.get("rng_address", "")) != "0x4e7276" \
			or String(visual_static_lookup_contract.get("toolkit_object_address", "")) != "0x5a3988" \
			or int(visual_static_lookup_contract.get("terrain_id", -1)) != 2 \
			or int(visual_static_lookup_contract.get("constructor_row_count", -1)) != 0x4f \
			or int(visual_static_lookup_contract.get("sample_neighbor_mask", -1)) != 8 \
			or int(visual_static_lookup_contract.get("sample_probability_rng_value", -1)) != 41 \
			or int(visual_static_lookup_contract.get("sample_probability_threshold", -1)) != 50 \
			or not bool(visual_static_lookup_contract.get("sample_selected_alternate_range", false)) \
			or int(visual_static_lookup_contract.get("sample_art_rng_value", -1)) != 18467 \
			or int(visual_static_lookup_contract.get("sample_selected_art_index", -1)) != 60 \
			or bool(visual_static_lookup_contract.get("materializes_full_terrain_art_grid", true)):
		_fail("The TerrainPlacement static range lookup contract drifted: %s" % JSON.stringify(visual_static_lookup_contract))
		return
	if String(copyback_gate.get("status", "")) != "0x4bc988_TerrainPlacement_retouch_gate_recovered_copyback_pending" \
			or String(copyback_gate.get("gate_address", "")) != "0x4bc988" \
			or String(copyback_gate.get("ordered_insert_helper_address", "")) != "0x4bd1c1" \
			or String(copyback_gate.get("container_insert_address", "")) != "0x4bd374" \
			or String(copyback_gate.get("container_lookup_address", "")) != "0x4bd3c5" \
			or bool(copyback_gate.get("copyback_to_generated_cell_0x24_0x28", true)):
		_fail("The TerrainPlacement copyback gate evidence drifted: %s" % JSON.stringify(copyback_gate))
		return
	if String(adapter_writeback.get("status", "")) != "0x49acc5_0x49acf6_type_random_map_terrain_writeback_recovered_not_materialized" \
			or String(adapter_writeback.get("adapter_vtable_address", "")) != "0x540a14" \
			or String(adapter_writeback.get("adapter_constructor_address", "")) != "0x499f60" \
			or String(adapter_writeback.get("virtual_write_entry_address", "")) != "0x49acc5" \
			or String(adapter_writeback.get("cell_write_helper_address", "")) != "0x49acf6" \
			or String(adapter_writeback.get("read_full_record_address", "")) != "0x49ad83" \
			or String(adapter_writeback.get("read_terrain_id_address", "")) != "0x49adde" \
			or String(adapter_writeback.get("read_terrain_art_address", "")) != "0x49ae01" \
			or bool(adapter_writeback.get("materializes_generated_cell_words", true)):
		_fail("The type_random_map terrain writeback evidence drifted: %s" % JSON.stringify(adapter_writeback))
		return
	if String(terrain_grid.get("schema_id", "")) != "aurelion_native_rmg_terrain_grid_v1" \
			or String(terrain_grid.get("generation_status", "")) != "h3maped_0x4a3f27_terrain_grid_adopted_inspection_only" \
			or String(terrain_grid.get("public_runtime_adoption_status", "")) != "blocked_until_TerrainPlacement_art_index_flip_and_later_rmg_phases" \
			or int(terrain_grid.get("width", -1)) != 36 \
			or int(terrain_grid.get("height", -1)) != 36 \
			or int(terrain_grid.get("level_count", -1)) != 1 \
			or int(terrain_grid.get("tile_count", -1)) != 1296 \
			or terrain_levels.size() != 1:
		_fail("The inspection terrain-grid adoption record drifted: %s" % JSON.stringify(terrain_grid))
		return
	if int(terrain_counts.get("dirt", -1)) != 492 \
			or int(terrain_counts.get("grass", -1)) != 165 \
			or int(terrain_counts.get("snow", -1)) != 222 \
			or int(terrain_counts.get("rough", -1)) != 232 \
			or int(terrain_counts.get("water", -1)) != 185:
		_fail("The 0x4a3f27 project-terrain cell counts drifted: %s" % JSON.stringify(terrain_cell_writeout))
		return
	if int(h3_terrain_counts.get("0", -1)) != 492 \
			or int(h3_terrain_counts.get("2", -1)) != 165 \
			or int(h3_terrain_counts.get("3", -1)) != 222 \
			or int(h3_terrain_counts.get("5", -1)) != 232 \
			or int(h3_terrain_counts.get("8", -1)) != 185:
		_fail("The 0x4a3f27 h3 terrain-code cell counts drifted: %s" % JSON.stringify(terrain_cell_writeout))
		return
	var footprint_levels: Array = footprint_schedule.get("levels", [])
	if footprint_levels.size() != 1 \
			or Array(footprint_levels[0].get("matching_runtime_zone_indices", [])) != [0, 1, 2, 3, 4, 5] \
			or bool(footprint_levels[0].get("synthetic_fallback_zone_allowed_by_0x4a3a9d", true)) \
			or bool(footprint_levels[0].get("synthetic_fallback_zone_created", true)) \
			or Array(footprint_levels[0].get("helper_call_sequence", [])) != ["0x4a2777", "0x4a325d", "0x4a3710"]:
		_fail("The 0x4a3a03 per-level schedule drifted: %s" % JSON.stringify(footprint_schedule))
		return
	var footprint_finalizer: Dictionary = footprint_schedule.get("finalizer", {})
	if String(footprint_schedule.get("finalizer_status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported" \
			or int(footprint_finalizer.get("original_same_level_runtime_zone_count", -1)) != 6 \
			or int(footprint_finalizer.get("final_runtime_zone_count", -1)) != 6 \
			or int(footprint_finalizer.get("appended_runtime_zone_count", -1)) != 0 \
			or int(footprint_finalizer.get("zone_order_reset_call_count", -1)) != 6 \
			or int(footprint_finalizer.get("per_zone_order_helper_call_count", -1)) != 6 \
			or int(footprint_finalizer.get("materialized_adjacency_count", -1)) != 0:
		_fail("The 0x4a3710 small-land finalizer drifted: %s" % JSON.stringify(footprint_finalizer))
		return
	if bool(footprint_finalizer.get("materializes_zone_cells", true)) \
			or bool(footprint_finalizer.get("materializes_boundary_cells", true)) \
			or bool(footprint_finalizer.get("materializes_span_fill", true)):
		_fail("The 0x4a3710 finalizer must not paint cells: %s" % JSON.stringify(footprint_finalizer))
		return
	var span_fill: Dictionary = footprint_schedule.get("span_fill_primitive", {})
	var span_sample: Dictionary = span_fill.get("sample_contract", {})
	if String(footprint_schedule.get("span_fill_primitive_status", "")) != "0x4a325d_standalone_span_fill_primitive_ported_real_boundary_pending" \
			or int(span_sample.get("boundary_cell_count", -1)) != 24 \
			or int(span_sample.get("filled_cell_count", -1)) != 24 \
			or int(span_sample.get("filled_zone_word_count", -1)) != 24 \
			or int(span_sample.get("remaining_unassigned_cell_count", -1)) != 72 \
			or int(span_sample.get("reserved_flag_cell_count", -1)) != 48 \
			or int(span_sample.get("pushed_span_count", -1)) != 4 \
			or int(span_sample.get("popped_span_count", -1)) != 4 \
			or int(span_sample.get("max_pending_span_count", -1)) != 1 \
			or int(span_sample.get("out_of_bounds_span_count", -1)) != 0 \
			or int(span_sample.get("blocked_initial_span_count", -1)) != 0:
		_fail("The 0x4a325d standalone span fill primitive drifted: %s" % JSON.stringify(span_fill))
		return
	if bool(span_fill.get("uses_real_0x4a2777_boundary", true)) \
			or bool(span_fill.get("materializes_project_grid", true)):
		_fail("The standalone 0x4a325d primitive sample must remain disconnected from project-grid output: %s" % JSON.stringify(span_fill))
		return
	var boundary_helpers: Dictionary = footprint_schedule.get("boundary_helper_primitives", {})
	var line_sample: Dictionary = boundary_helpers.get("line_sample", {})
	if String(footprint_schedule.get("boundary_helper_primitives_status", "")) != "0x4a2b33_clip_and_0x4a261a_line_writer_primitives_ported" \
			or int(boundary_helpers.get("clip_sample_count", -1)) != 5 \
			or int(line_sample.get("write_count", -1)) != 7 \
			or int(line_sample.get("unique_cell_count", -1)) != 7 \
			or int(line_sample.get("zone_word_cell_count", -1)) != 7 \
			or int(line_sample.get("reserved_flag_write_count", -1)) != 7 \
			or int(line_sample.get("reserved_flag_cell_count", -1)) != 7 \
			or int(line_sample.get("out_of_bounds_write_count", -1)) != 0:
		_fail("The 0x4a2b33/0x4a261a boundary helper primitives drifted: %s" % JSON.stringify(boundary_helpers))
		return
	var clip_samples: Array = boundary_helpers.get("clip_samples", [])
	if clip_samples.size() != 5 \
			or int(clip_samples[1].get("out_x", -1)) != 0 \
			or int(clip_samples[2].get("out_y", -1)) != 0 \
			or int(clip_samples[3].get("out_x", -1)) != 35 \
			or int(clip_samples[4].get("out_y", -1)) != 35:
		_fail("The 0x4a2b33 sample clipping outputs drifted: %s" % JSON.stringify(boundary_helpers))
		return
	if bool(boundary_helpers.get("uses_real_0x4a2777_source_node_walk", true)) \
			or bool(boundary_helpers.get("materializes_project_grid", true)):
		_fail("Boundary helper primitives must remain disconnected from runtime output until 0x4a2777 is assembled: %s" % JSON.stringify(boundary_helpers))
		return
	var rectangle_fallback: Dictionary = footprint_schedule.get("rectangle_fallback", {})
	var rectangle_sample: Dictionary = rectangle_fallback.get("sample_contract", {})
	if String(footprint_schedule.get("rectangle_fallback_status", "")) != "0x4a2777_rectangle_fallback_branch_ported_standalone" \
			or int(rectangle_sample.get("edge_call_count", -1)) != 4 \
			or int(rectangle_sample.get("edge_write_count", -1)) != 26 \
			or int(rectangle_sample.get("edge_unique_write_count", -1)) != 22 \
			or int(rectangle_sample.get("unique_zone_word_cell_count", -1)) != 22 \
			or int(rectangle_sample.get("reserved_flag_cell_count", -1)) != 22 \
			or int(rectangle_sample.get("out_of_bounds_write_count", -1)) != 0 \
			or int(rectangle_sample.get("footprint_vertex_count", -1)) != 4:
		_fail("The 0x4a2777 rectangle fallback branch drifted: %s" % JSON.stringify(rectangle_fallback))
		return
	if bool(rectangle_fallback.get("uses_real_source_node_walk", true)) \
			or bool(rectangle_fallback.get("materializes_project_grid", true)):
		_fail("The 0x4a2777 rectangle fallback must remain standalone until real source-node traversal is ported: %s" % JSON.stringify(rectangle_fallback))
		return
	var connector_segment: Dictionary = footprint_schedule.get("connector_segment", {})
	var connector_clipped: Dictionary = connector_segment.get("sample_clipped_segment", {})
	if String(footprint_schedule.get("connector_segment_status", "")) != "0x4a2777_connector_segment_deterministic_branch_ported_standalone" \
			or int(connector_clipped.get("from_x", -1)) != 0 \
			or int(connector_clipped.get("from_y", -1)) != 9 \
			or int(connector_clipped.get("to_x", -1)) != 33 \
			or int(connector_clipped.get("to_y", -1)) != 27 \
			or int(connector_segment.get("sample_appended_vertex_count", -1)) != 1 \
			or int(connector_segment.get("deterministic_write_count", -1)) != 34 \
			or int(connector_segment.get("deterministic_unique_cell_count", -1)) != 34 \
			or int(connector_segment.get("deterministic_reserved_flag_write_count", -1)) != 34 \
			or int(connector_segment.get("deterministic_out_of_bounds_write_count", -1)) != 0:
		_fail("The 0x4a2777 deterministic connector segment branch drifted: %s" % JSON.stringify(connector_segment))
		return
	if bool(connector_segment.get("uses_real_source_node_walk", true)) \
			or bool(connector_segment.get("materializes_project_grid", true)) \
			or String(connector_segment.get("randomized_line_writer_status", "")) != "0x4a2413_randomized_line_writer_ported_standalone_not_dispatched_here":
		_fail("The 0x4a2777 connector segment must stay standalone and not dispatch the flagged branch here: %s" % JSON.stringify(connector_segment))
		return

	var boundary_wrapping: Dictionary = footprint_schedule.get("boundary_wrapping", {})
	var boundary_clipped: Dictionary = boundary_wrapping.get("sample_clipped_continuation", {})
	if String(footprint_schedule.get("boundary_wrapping_status", "")) != "0x4a2777_boundary_wrapping_continuation_ported_standalone" \
			or int(boundary_clipped.get("current_x", -1)) != 0 \
			or int(boundary_clipped.get("current_y", -1)) != 19 \
			or int(boundary_clipped.get("target_x", -1)) != 35 \
			or int(boundary_clipped.get("target_y", -1)) != 28 \
			or int(boundary_wrapping.get("wrap_segment_count", -1)) != 2 \
			or int(boundary_wrapping.get("final_segment_count", -1)) != 1 \
			or int(boundary_wrapping.get("sample_appended_vertex_count", -1)) != 3 \
			or int(boundary_wrapping.get("write_count", -1)) != 85 \
			or int(boundary_wrapping.get("unique_write_count", -1)) != 83 \
			or int(boundary_wrapping.get("zone_word_cell_count", -1)) != 83 \
			or int(boundary_wrapping.get("reserved_flag_write_count", -1)) != 85 \
			or int(boundary_wrapping.get("reserved_flag_cell_count", -1)) != 83 \
			or int(boundary_wrapping.get("out_of_bounds_write_count", -1)) != 0 \
			or bool(boundary_wrapping.get("loop_guard_exhausted", true)):
		_fail("The 0x4a2777 boundary wrapping continuation drifted: %s" % JSON.stringify(boundary_wrapping))
		return
	if bool(boundary_wrapping.get("uses_real_source_node_walk", true)) \
			or bool(boundary_wrapping.get("materializes_project_grid", true)):
		_fail("The 0x4a2777 boundary wrapping continuation must stay standalone until real source-node traversal is assembled: %s" % JSON.stringify(boundary_wrapping))
		return

	var randomized_line_writer: Dictionary = footprint_schedule.get("randomized_line_writer", {})
	var randomized_sample: Dictionary = randomized_line_writer.get("sample_contract", {})
	if String(footprint_schedule.get("randomized_line_writer_status", "")) != "0x4a2413_randomized_line_writer_ported_standalone" \
			or int(randomized_sample.get("write_count", -1)) != 64 \
			or int(randomized_sample.get("unique_cell_count", -1)) != 63 \
			or int(randomized_sample.get("zone_word_cell_count", -1)) != 63 \
			or int(randomized_sample.get("reserved_flag_write_count", -1)) != 64 \
			or int(randomized_sample.get("reserved_flag_cell_count", -1)) != 63 \
			or int(randomized_sample.get("out_of_bounds_write_count", -1)) != 0 \
			or int(randomized_sample.get("rng_call_count", -1)) != 51 \
			or int(randomized_sample.get("inserted_midpoint_count", -1)) != 63 \
			or int(randomized_sample.get("max_pending_point_count", -1)) != 7 \
			or int(randomized_sample.get("rng_state_after_uint32", -1)) != 3821795434:
		_fail("The 0x4a2413 standalone randomized line writer drifted: %s" % JSON.stringify(randomized_line_writer))
		return
	if bool(randomized_line_writer.get("uses_real_source_node_walk", true)) \
			or bool(randomized_line_writer.get("materializes_project_grid", true)):
		_fail("The 0x4a2413 randomized writer must remain standalone until real source-node traversal is assembled: %s" % JSON.stringify(randomized_line_writer))
		return

	var color_config := config.duplicate(true)
	color_config["player_constraints"]["selected_color_bitmap"] = [false, false, true, false, false, false, false, false]
	var color_report: Dictionary = service.inspect_h3maped_small_rmg_port(color_config)
	var color_assignment: Dictionary = Dictionary(color_report.get("selected_template_payload", {})).get("player_slot_assignment", {})
	if Array(color_assignment.get("selected_color_bitmap", [])) != [false, false, true, false, false, false, false, false] \
			or Array(color_assignment.get("selected_color_order", [])) != [2, 0, 1, 3, 4, 5, 6, 7] \
			or Array(color_assignment.get("actual_colors_by_source_owner", [])) != [2, 0, 1, -1, -1, -1, -1, -1]:
		_fail("Selected-color bitmap did not reorder h3maped assignment colors: %s" % JSON.stringify(color_assignment))
		return
	var color_runtime_zones: Dictionary = Dictionary(color_report.get("selected_template_payload", {})).get("runtime_zone_build", {})
	if Array(color_runtime_zones.get("actual_owner_colors_by_runtime_zone", [])) != [2, 0, -1, 1, -1, -1]:
		_fail("Selected-color runtime-zone owner mapping did not follow generator+0xee4: %s" % JSON.stringify(color_runtime_zones))
		return

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Supported small generation must remain blocked instead of emitting partial maps: %s" % JSON.stringify(generated))
		return
	var generated_port: Dictionary = generated.get("h3maped_small_port", {})
	if String(generated_port.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_clean_restart_v2":
		_fail("Blocked small generation did not route through the new clean h3maped port: %s" % JSON.stringify(generated))
		return

	var explicit_template_config := config.duplicate(true)
	explicit_template_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_generated: Dictionary = service.generate_random_map(explicit_template_config)
	if bool(explicit_generated.get("ok", true)) \
			or String(explicit_generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Explicit translated-template generation bypassed the reset gate: %s" % JSON.stringify(explicit_generated))
		return

	var medium_config := {
		"seed": "1",
		"size": {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var out_of_scope: Dictionary = service.generate_random_map(medium_config)
	if bool(out_of_scope.get("ok", true)) \
			or String(out_of_scope.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope generation did not stay archived-disabled: %s" % JSON.stringify(out_of_scope))
		return

	print("%s: status=pass clean_schema=%s selected_template=%s generation_status=%s out_of_scope_generation_status=%s" % [
		REPORT_ID,
		String(report.get("schema_id", "")),
		String(selected_template.get("id", "")),
		String(generated.get("generation_status", "")),
		String(out_of_scope.get("generation_status", "")),
	])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	print("%s: status=fail reason=%s" % [REPORT_ID, message])
	get_tree().quit(1)
