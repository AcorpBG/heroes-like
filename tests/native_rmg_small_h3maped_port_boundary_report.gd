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
		_fail("Small h3maped fresh boundary did not accept the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_boundary_v1":
		_fail("Small h3maped inspection did not use the fresh boundary schema: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "h3maped_small_fresh_boundary_ready":
		_fail("Unexpected small h3maped fresh status: %s" % JSON.stringify(report))
		return
	if String(report.get("implementation_policy", "")) != "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_runtime_fallback":
		_fail("The fresh reset policy is not explicit enough: %s" % JSON.stringify(report))
		return
	if String(report.get("archive_status", "")) != "previous_phase_ledger_archived_out_of_build":
		_fail("The previous phase ledger was not archived out of the build: %s" % JSON.stringify(report))
		return
	if String(report.get("archived_phase_ledger_path", "")) != "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp":
		_fail("Unexpected archived phase ledger path: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) or bool(report.get("partial_materialized_payload_public_api", true)):
		_fail("The fresh boundary must not expose runtime or partial package output: %s" % JSON.stringify(report))
		return

	for forbidden_key in [
		"player_slot_assignment",
		"runtime_zone_record_setup",
		"link_seed_setup",
		"coordinate_replay",
		"terrain_cell_writeout_4a3f27",
		"town_castle_phase_schedule",
		"same_level_connection_transition_vectors",
	]:
		if report.has(forbidden_key):
			_fail("Fresh boundary leaked old inspection-ledger key '%s': %s" % [forbidden_key, JSON.stringify(report)])
			return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("status", "")) != "verified_reset_anchor" \
			or not bool(binary.get("mz_header_present", false)) \
			or not bool(binary.get("sha256_matches", false)) \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("The fresh boundary did not verify the local h3maped.exe anchor: %s" % JSON.stringify(binary))
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
			or String(backlog[1].get("status", "")) != "private_context_ready" \
			or String(backlog[2].get("id", "")) != "runtime_zone_records" \
			or String(backlog[2].get("status", "")) != "private_context_ready" \
			or String(backlog[3].get("id", "")) != "coordinate_replay_and_zone_footprints" \
			or String(backlog[3].get("status", "")) != "private_context_ready" \
			or String(backlog[4].get("status", "")) != "private_terrain_writeout_ready_visuals_pending" \
			or String(backlog[9].get("id", "")) != "final_h3m_writeout":
		_fail("Fresh restart backlog drifted: %s" % JSON.stringify(backlog))
		return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Fresh backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var private_context: Dictionary = report.get("private_generation_context", {})
	var completed_private_phases := ["template_selection", "player_slot_assignment", "runtime_zone_records", "link_seed_setup", "coordinate_replay_and_zone_footprints", "zone_footprint_phase_boundary", "source_node_rectangle", "polygon_split_model", "source_node_boundary_traversal", "span_fill_4a325d", "footprint_finalizer_4a3710", "runtime_terrain_selection_49b53d", "terrain_cell_writeout_4a3f27"]
	if String(private_context.get("schema_id", "")) != "aurelion_h3maped_small_private_generation_context_v1" \
			or String(private_context.get("status", "")) != "terrain_cell_writeout_private_context_ready" \
			or Array(private_context.get("completed_phase_ids", [])) != completed_private_phases \
			or int(private_context.get("completed_phase_count", -1)) != completed_private_phases.size() \
			or bool(private_context.get("runtime_generation_allowed", true)) \
			or bool(private_context.get("partial_materialized_payload_public_api", true)):
		_fail("Private generation context did not stop at the h3maped terrain-cell writeout phase: %s" % JSON.stringify(private_context))
		return
	var player_context: Dictionary = private_context.get("player_context", {})
	if String(player_context.get("h3maped_anchor", "")) != "0x4ac62a..0x4ac6ec" \
			or String(player_context.get("status", "")) != "private_context_ready" \
			or String(player_context.get("selected_color_bitmap_offset", "")) != "generator+0xed8" \
			or String(player_context.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(player_context.get("mapped_slots_offset", "")) != "generator+0xee4" \
			or int(player_context.get("human_capable_source_owner_mask", -1)) != 15 \
			or int(player_context.get("player_capable_source_owner_mask", -1)) != 15 \
			or Array(player_context.get("human_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(player_context.get("player_capable_source_owner_indices", [])) != [0, 1, 2, 3] \
			or Array(player_context.get("raw_ee0_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(player_context.get("mapped_ee4_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or int(player_context.get("assigned_player_count", -1)) != 3 \
			or bool(player_context.get("materializes_runtime_players", true)) \
			or bool(player_context.get("materializes_public_output", true)):
		_fail("h3maped player-slot private context drifted: %s" % JSON.stringify(player_context))
		return
	var assignments: Array = player_context.get("assignment_records", [])
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
		_fail("h3maped player-slot assignment records drifted: %s" % JSON.stringify(assignments))
		return
	var runtime_zone_context: Dictionary = private_context.get("runtime_zone_context", {})
	if String(runtime_zone_context.get("h3maped_anchor", "")) != "0x4a218c" \
			or String(runtime_zone_context.get("initializer_anchor", "")) != "0x49b452" \
			or String(runtime_zone_context.get("status", "")) != "private_context_ready" \
			or String(runtime_zone_context.get("runtime_zone_vector_begin_offset", "")) != "generator+0x10e0" \
			or String(runtime_zone_context.get("runtime_zone_vector_end_offset", "")) != "generator+0x10e4" \
			or String(runtime_zone_context.get("runtime_zone_vector_capacity_offset", "")) != "generator+0x10e8" \
			or int(runtime_zone_context.get("runtime_zone_record_size_bytes", -1)) != 0x414 \
			or int(runtime_zone_context.get("runtime_zone_count", -1)) != 6 \
			or int(runtime_zone_context.get("assigned_start_zone_count", -1)) != 3 \
			or int(runtime_zone_context.get("unassigned_start_zone_count", -1)) != 1 \
			or int(runtime_zone_context.get("treasure_zone_count", -1)) != 2 \
			or int(runtime_zone_context.get("minimum_player_castles", -1)) != 4 \
			or int(runtime_zone_context.get("minimum_source_base_size", -1)) != 11 \
			or Array(runtime_zone_context.get("actual_owner_colors_by_runtime_zone", [])) != [0, 1, -1, 2, -1, -1] \
			or bool(runtime_zone_context.get("materializes_runtime_zone_coordinates", true)) \
			or bool(runtime_zone_context.get("materializes_terrain", true)) \
			or bool(runtime_zone_context.get("materializes_map_cells", true)) \
			or bool(runtime_zone_context.get("materializes_runtime_players", true)) \
			or bool(runtime_zone_context.get("materializes_public_output", true)):
		_fail("h3maped runtime-zone private context drifted: %s" % JSON.stringify(runtime_zone_context))
		return
	var runtime_records: Array = runtime_zone_context.get("runtime_zone_records", [])
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
	var link_context: Dictionary = private_context.get("link_context", {})
	if String(link_context.get("h3maped_anchor", "")) != "0x4a1f3b" \
			or String(link_context.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(link_context.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(link_context.get("late_payload_consumer_anchor", "")) != "0x4a79a3" \
			or String(link_context.get("status", "")) != "private_context_ready" \
			or int(link_context.get("link_seed_count", -1)) != 5 \
			or bool(link_context.get("materializes_coordinates", true)) \
			or bool(link_context.get("materializes_connection_guards", true)) \
			or bool(link_context.get("materializes_roads", true)) \
			or bool(link_context.get("materializes_blockers", true)) \
			or bool(link_context.get("materializes_public_output", true)):
		_fail("h3maped link-seed private context drifted: %s" % JSON.stringify(link_context))
		return
	var link_seeds: Array = link_context.get("link_seeds", [])
	if link_seeds.size() != 5 \
			or int(link_seeds[0].get("runtime_zone_a", -1)) != 0 \
			or int(link_seeds[0].get("runtime_zone_b", -1)) != 3 \
			or int(link_seeds[0].get("guard_value", -1)) != 3000 \
			or int(link_seeds[3].get("runtime_zone_a", -1)) != 2 \
			or int(link_seeds[3].get("runtime_zone_b", -1)) != 4 \
			or int(link_seeds[3].get("guard_value", -1)) != 6000 \
			or int(link_seeds[4].get("runtime_zone_a", -1)) != 5 \
			or int(link_seeds[4].get("runtime_zone_b", -1)) != 3:
		_fail("h3maped link seeds drifted: %s" % JSON.stringify(link_seeds))
		return
	var coordinate_context: Dictionary = private_context.get("coordinate_replay_context", {})
	if String(coordinate_context.get("status", "")) != "private_context_ready" \
			or String(coordinate_context.get("link_endpoint_consumer_anchor", "")) != "0x4a1f3b" \
			or String(coordinate_context.get("candidate_generator_anchor", "")) != "0x4a17f5" \
			or String(coordinate_context.get("distance_validation_anchor", "")) != "0x4a1701" \
			or String(coordinate_context.get("candidate_prune_anchor", "")) != "0x4a1ad8" \
			or String(coordinate_context.get("bbox_rescale_anchor", "")) != "0x4a19ed" \
			or int(coordinate_context.get("rng_state_before_0x4a218c_replay_uint32", -1)) != 2745024 \
			or int(coordinate_context.get("placement_step_count", -1)) != 18 \
			or int(coordinate_context.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18 \
			or int(coordinate_context.get("town_choice_rng_calls_during_0x4a218c", -1)) != 4 \
			or int(coordinate_context.get("total_interleaved_rng_calls_during_0x4a218c", -1)) != 22 \
			or int(coordinate_context.get("rng_event_count", -1)) != 22 \
			or int(coordinate_context.get("rng_state_after_0x4a218c_replay_uint32", -1)) != 255755822 \
			or bool(coordinate_context.get("materializes_map_cells", true)) \
			or bool(coordinate_context.get("materializes_zone_footprints", true)) \
			or bool(coordinate_context.get("materializes_terrain", true)) \
			or bool(coordinate_context.get("materializes_public_output", true)):
		_fail("h3maped coordinate-replay private context drifted: %s" % JSON.stringify(coordinate_context))
		return
	var bbox: Dictionary = coordinate_context.get("bounding_box_rescale", {})
	if int(bbox.get("selected_span_before_rescale", -1)) != 84 \
			or int(bbox.get("map_span", -1)) != 36:
		_fail("h3maped coordinate bbox rescale drifted: %s" % JSON.stringify(bbox))
		return
	var scaled: Array = coordinate_context.get("scaled_zone_coordinates", [])
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
		_fail("h3maped scaled zone coordinates drifted: %s" % JSON.stringify(scaled))
		return
	var rng_events: Array = coordinate_context.get("rng_events", [])
	if rng_events.size() != 22 \
			or String(rng_events[0].get("consumer", "")) != "0x49b3c1" \
			or String(rng_events[0].get("selected_faction_id", "")) != "elemental" \
			or String(rng_events[2].get("selected_faction_id", "")) != "necropolis" \
			or String(rng_events[5].get("selected_faction_id", "")) != "inferno" \
			or String(rng_events[7].get("selected_faction_id", "")) != "fortress":
		_fail("h3maped interleaved RNG events drifted: %s" % JSON.stringify(rng_events))
		return

	var zone_footprint_context: Dictionary = private_context.get("zone_footprint_context", {})
	if String(zone_footprint_context.get("phase_id", "")) != "zone_footprint_phase_boundary" \
			or String(zone_footprint_context.get("h3maped_anchor", "")) != "0x4a3a03" \
			or String(zone_footprint_context.get("helper_sequence", "")) != "0x4a2777 -> 0x4a325d -> 0x4a3710" \
			or String(zone_footprint_context.get("status", "")) != "private_context_ready" \
			or int(zone_footprint_context.get("level_count", -1)) != 1 \
			or int(zone_footprint_context.get("h3maped_water_mode_code", -1)) != 0 \
			or int(zone_footprint_context.get("total_collected_runtime_zone_count", -1)) != 6 \
			or int(zone_footprint_context.get("synthetic_zone_appended_count", -1)) != 0 \
			or String(zone_footprint_context.get("blocked_next", "")) != "source_node_rectangle_0x4cc788" \
			or bool(zone_footprint_context.get("materializes_boundaries", true)) \
			or bool(zone_footprint_context.get("materializes_span_fill", true)) \
			or bool(zone_footprint_context.get("materializes_terrain", true)) \
			or bool(zone_footprint_context.get("materializes_map_cells", true)) \
			or bool(zone_footprint_context.get("materializes_public_output", true)):
		_fail("h3maped zone-footprint scheduling context drifted: %s" % JSON.stringify(zone_footprint_context))
		return
	var per_level: Array = zone_footprint_context.get("per_level", [])
	if per_level.size() != 1:
		_fail("h3maped zone-footprint levels drifted: %s" % JSON.stringify(per_level))
		return
	var level_zero: Dictionary = per_level[0]
	if int(level_zero.get("level", -1)) != 0 \
			or Array(level_zero.get("collected_runtime_zone_indices", [])) != [0, 1, 2, 3, 4, 5] \
			or int(level_zero.get("collected_runtime_zone_count", -1)) != 6 \
			or int(level_zero.get("helper_call_input_count", -1)) != 6 \
			or bool(level_zero.get("synthetic_zone_appended", true)) \
			or String(level_zero.get("synthetic_zone_status", "")) != "not_applicable_small_one_level_land" \
			or String(level_zero.get("helper_status", "")) != "0x4a2777_inputs_queued_0x4a325d_0x4a3710_materialization_pending":
		_fail("h3maped zone-footprint level-zero context drifted: %s" % JSON.stringify(level_zero))
		return
	var helper_inputs: Array = level_zero.get("helper_call_inputs", [])
	if helper_inputs.size() != 6 \
			or String(helper_inputs[0].get("helper_address", "")) != "0x4a2777" \
			or int(helper_inputs[0].get("runtime_zone_index", -1)) != 0 \
			or int(helper_inputs[0].get("source_zone_id", -1)) != 1 \
			or int(helper_inputs[0].get("level", -1)) != 0 \
			or String(helper_inputs[0].get("input_status", "")) != "queued_for_0x4a2777_no_boundary_materialization" \
			or int(helper_inputs[5].get("runtime_zone_index", -1)) != 5 \
			or int(helper_inputs[5].get("source_zone_id", -1)) != 6:
		_fail("h3maped zone-footprint helper inputs drifted: %s" % JSON.stringify(helper_inputs))
		return

	var source_node_rectangle: Dictionary = private_context.get("source_node_rectangle", {})
	if String(source_node_rectangle.get("phase_id", "")) != "source_node_rectangle" \
			or String(source_node_rectangle.get("h3maped_anchor", "")) != "0x4cc788" \
			or String(source_node_rectangle.get("node_constructor_anchor", "")) != "0x4cc955" \
			or String(source_node_rectangle.get("splitter_anchor", "")) != "0x4ccb64" \
			or String(source_node_rectangle.get("locator_anchor", "")) != "0x4cca55" \
			or String(source_node_rectangle.get("finalizer_anchor", "")) != "0x4ccdfc" \
			or String(source_node_rectangle.get("status", "")) != "private_context_ready" \
			or String(source_node_rectangle.get("blocked_next", "")) != "polygon_split_model_0x4ccb64_0x4ccdfc" \
			or bool(source_node_rectangle.get("materializes_source_node_graph", true)) \
			or bool(source_node_rectangle.get("materializes_boundaries", true)) \
			or bool(source_node_rectangle.get("materializes_span_fill", true)) \
			or bool(source_node_rectangle.get("materializes_terrain", true)) \
			or bool(source_node_rectangle.get("materializes_map_cells", true)) \
			or bool(source_node_rectangle.get("materializes_public_output", true)) \
			or bool(source_node_rectangle.get("feeds_real_0x4a2777_boundary", true)):
		_fail("h3maped source-node rectangle context drifted: %s" % JSON.stringify(source_node_rectangle))
		return
	var bounds: Dictionary = source_node_rectangle.get("initial_bounds", {})
	if int(bounds.get("min_x", 0)) != -200 \
			or int(bounds.get("min_y", 0)) != -200 \
			or int(bounds.get("max_x", 0)) != 400 \
			or int(bounds.get("max_y", 0)) != 400 \
			or String(bounds.get("constant_min_hex", "")) != "0xffffff38" \
			or String(bounds.get("constant_max_hex", "")) != "0x190":
		_fail("h3maped source-node rectangle bounds drifted: %s" % JSON.stringify(bounds))
		return
	var initial_edges: Array = source_node_rectangle.get("initial_edges", [])
	if int(source_node_rectangle.get("initial_edge_count", -1)) != 4 \
			or initial_edges.size() != 4 \
			or String(initial_edges[0].get("id", "")) != "top" \
			or int(initial_edges[0].get("from_x", 0)) != -200 \
			or int(initial_edges[0].get("to_x", 0)) != 400 \
			or String(initial_edges[0].get("next", "")) != "right" \
			or String(initial_edges[1].get("id", "")) != "right" \
			or String(initial_edges[1].get("next", "")) != "bottom" \
			or String(initial_edges[2].get("id", "")) != "bottom" \
			or String(initial_edges[2].get("next", "")) != "left" \
			or String(initial_edges[3].get("id", "")) != "left" \
			or String(initial_edges[3].get("next", "")) != "top":
		_fail("h3maped source-node rectangle edges drifted: %s" % JSON.stringify(initial_edges))
		return

	var polygon_split: Dictionary = private_context.get("polygon_split_context", {})
	if String(polygon_split.get("phase_id", "")) != "polygon_split_model" \
			or String(polygon_split.get("h3maped_anchor", "")) != "0x4ccb64" \
			or String(polygon_split.get("locator_anchor", "")) != "0x4cca55" \
			or String(polygon_split.get("splitter_anchor", "")) != "0x4ccb64" \
			or String(polygon_split.get("node_constructor_anchor", "")) != "0x4cc955" \
			or String(polygon_split.get("node_relink_anchor", "")) != "0x4cc643" \
			or String(polygon_split.get("edge_side_test_anchor", "")) != "0x4cc6f2" \
			or String(polygon_split.get("edge_erase_anchor", "")) != "0x4cc9cc" \
			or String(polygon_split.get("bridge_anchor", "")) != "0x4ccb1f" \
			or String(polygon_split.get("crossing_test_anchor", "")) != "0x4ccc7a" \
			or String(polygon_split.get("crossing_collapse_anchor", "")) != "0x4cc68e" \
			or String(polygon_split.get("intersection_writer_anchor", "")) != "0x4ccd69" \
			or String(polygon_split.get("finalizer_anchor", "")) != "0x4ccdfc" \
			or String(polygon_split.get("status", "")) != "private_context_ready" \
			or not bool(polygon_split.get("materializes_source_node_graph", false)) \
			or bool(polygon_split.get("materializes_boundaries", true)) \
			or bool(polygon_split.get("materializes_span_fill", true)) \
			or bool(polygon_split.get("materializes_terrain", true)) \
			or bool(polygon_split.get("materializes_map_cells", true)) \
			or bool(polygon_split.get("materializes_public_output", true)) \
			or bool(polygon_split.get("feeds_real_0x4a2777_boundary", true)):
		_fail("h3maped polygon split context drifted: %s" % JSON.stringify(polygon_split))
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
			or int(polygon_split.get("post_crossing_cleanup_allocated_node_count", -1)) != 46 \
			or int(polygon_split.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23 \
			or int(polygon_split.get("post_crossing_cleanup_active_node_count", -1)) != 46 \
			or String(polygon_split.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_crossing_cleanup_ported" \
			or String(polygon_split.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_ported" \
			or int(polygon_split.get("finalized_triplet_count", -1)) != 14 \
			or int(polygon_split.get("finalized_node_count", -1)) != 42 \
			or int(polygon_split.get("active_payload_node_count", -1)) != 28 \
			or String(polygon_split.get("source_node_walk_status", "")) != "0x4cca55_to_0x4a2777_source_node_cycles_recovered_private_only" \
			or int(polygon_split.get("source_node_walk_count", -1)) != 6 \
			or int(polygon_split.get("source_node_walk_guard_exhausted_count", -1)) != 0 \
			or String(polygon_split.get("blocked_next", "")) != "feed_finalized_0x4ccdfc_source_node_cycles_into_real_0x4a2777_traversal":
		_fail("h3maped polygon split counts drifted: %s" % JSON.stringify(polygon_split))
		return
	var split_steps: Array = polygon_split.get("split_steps", [])
	if split_steps.size() != 6 \
			or int(split_steps[0].get("runtime_zone_index", -1)) != 0 \
			or int(split_steps[0].get("bridge_pair_count", -1)) != 2 \
			or String(split_steps[0].get("status", "")) != "0x4ccb64_pre_crossing_inserted" \
			or int(split_steps[5].get("runtime_zone_index", -1)) != 5 \
			or int(split_steps[5].get("bridge_pair_count", -1)) != 2:
		_fail("h3maped polygon split steps drifted: %s" % JSON.stringify(split_steps))
		return
	var finalized_steps: Array = polygon_split.get("finalized_steps", [])
	var source_node_walks: Array = polygon_split.get("source_node_walks", [])
	if finalized_steps.size() != 14 \
			or source_node_walks.size() != 6 \
			or int(source_node_walks[0].get("runtime_zone_index", -1)) != 0 \
			or int(source_node_walks[0].get("cycle_node_count", -1)) <= 0 \
			or bool(source_node_walks[0].get("guard_exhausted", true)):
		_fail("h3maped polygon finalized source-node walks drifted: %s" % JSON.stringify(source_node_walks))
		return

	var boundary_traversal: Dictionary = private_context.get("boundary_traversal_context", {})
	if String(boundary_traversal.get("phase_id", "")) != "source_node_boundary_traversal" \
			or String(boundary_traversal.get("h3maped_anchor", "")) != "0x4a2777" \
			or String(boundary_traversal.get("caller_anchor", "")) != "0x4a3e58..0x4a3e8c" \
			or String(boundary_traversal.get("source_node_cycle_source", "")) != "polygon_split_model.source_node_walks_from_0x4cca55_after_0x4ccdfc_finalization" \
			or String(boundary_traversal.get("clip_helper_anchor", "")) != "0x4a2b33" \
			or String(boundary_traversal.get("deterministic_line_writer_anchor", "")) != "0x4a261a" \
			or String(boundary_traversal.get("flagged_line_writer_anchor", "")) != "0x4a2413" \
			or String(boundary_traversal.get("runtime_vertex_vector_offset", "")) != "runtime_zone+0x3f4" \
			or String(boundary_traversal.get("status", "")) != "private_context_ready" \
			or not bool(boundary_traversal.get("materializes_boundaries", false)) \
			or bool(boundary_traversal.get("materializes_span_fill", true)) \
			or bool(boundary_traversal.get("materializes_terrain", true)) \
			or bool(boundary_traversal.get("materializes_map_cells", true)) \
			or bool(boundary_traversal.get("materializes_public_output", true)) \
			or int(boundary_traversal.get("project_materialized_cell_count", -1)) != 0 \
			or int(boundary_traversal.get("map_width", -1)) != 36 \
			or int(boundary_traversal.get("map_height", -1)) != 36 \
			or int(boundary_traversal.get("level_count", -1)) != 1 \
			or int(boundary_traversal.get("h3maped_water_mode_code", -1)) != 0:
		_fail("h3maped source-node boundary traversal identity drifted: %s" % JSON.stringify(boundary_traversal))
		return
	if int(boundary_traversal.get("rng_state_before_0x4a2777_uint32", -1)) != 255755822 \
			or int(boundary_traversal.get("runtime_zone_walk_count", -1)) != 6 \
			or int(boundary_traversal.get("blocked_zone_count", -1)) != 0 \
			or int(boundary_traversal.get("fallback_zone_count", -1)) != 0 \
			or int(boundary_traversal.get("connector_segment_count", -1)) != 6 \
			or int(boundary_traversal.get("wrap_segment_count", -1)) != 0 \
			or int(boundary_traversal.get("final_segment_count", -1)) != 12 \
			or int(boundary_traversal.get("appended_vertex_count", -1)) != 18 \
			or int(boundary_traversal.get("skipped_unfinalized_node_count", -1)) != 0 \
			or int(boundary_traversal.get("skipped_out_of_bounds_clip_count", -1)) != 12 \
			or int(boundary_traversal.get("flagged_writer_segment_count", -1)) != 6 \
			or int(boundary_traversal.get("deterministic_writer_segment_count", -1)) != 12 \
			or int(boundary_traversal.get("randomized_rng_call_count", -1)) != 106 \
			or int(boundary_traversal.get("randomized_inserted_midpoint_count", -1)) != 138 \
			or int(boundary_traversal.get("randomized_max_pending_point_count", -1)) != 8 \
			or int(boundary_traversal.get("rng_state_after_0x4a2777_uint32", -1)) != 264218432 \
			or int(boundary_traversal.get("trace_write_count", -1)) != 301 \
			or int(boundary_traversal.get("unique_cell_count", -1)) != 238 \
			or int(boundary_traversal.get("out_of_bounds_write_count", -1)) != 0 \
			or bool(boundary_traversal.get("loop_guard_exhausted", true)) \
			or String(boundary_traversal.get("blocked_next", "")) != "0x4a325d_span_fill":
		_fail("h3maped source-node boundary traversal counts drifted: %s" % JSON.stringify(boundary_traversal))
		return
	var zone_reports: Array = boundary_traversal.get("zone_reports", [])
	if zone_reports.size() != 6 \
			or String(zone_reports[0].get("status", "")) != "0x4a2777_real_source_cycle_consumed" \
			or int(zone_reports[0].get("runtime_zone_index", -1)) != 0 \
			or int(zone_reports[0].get("segment_count", -1)) != 3 \
			or int(zone_reports[1].get("runtime_zone_index", -1)) != 1 \
			or int(zone_reports[1].get("segment_count", -1)) != 4 \
			or int(zone_reports[5].get("runtime_zone_index", -1)) != 5:
		_fail("h3maped source-node boundary traversal zone reports drifted: %s" % JSON.stringify(zone_reports))
		return

	var span_fill: Dictionary = private_context.get("span_fill_context", {})
	if String(span_fill.get("phase_id", "")) != "span_fill_4a325d" \
			or String(span_fill.get("h3maped_anchor", "")) != "0x4a325d" \
			or String(span_fill.get("boundary_source_anchor", "")) != "0x4a2777" \
			or String(span_fill.get("seed_source", "")) != "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale" \
			or String(span_fill.get("status", "")) != "private_context_ready" \
			or not bool(span_fill.get("uses_real_0x4a2777_boundary", false)) \
			or not bool(span_fill.get("materializes_span_fill", false)) \
			or bool(span_fill.get("materializes_terrain", true)) \
			or bool(span_fill.get("materializes_map_cells", true)) \
			or bool(span_fill.get("materializes_runtime_players", true)) \
			or bool(span_fill.get("materializes_package_tiles", true)) \
			or bool(span_fill.get("project_grid_public_runtime_adoption", true)) \
			or bool(span_fill.get("public_package_output_allowed", true)) \
			or int(span_fill.get("map_width", -1)) != 36 \
			or int(span_fill.get("map_height", -1)) != 36 \
			or int(span_fill.get("level_count", -1)) != 1 \
			or int(span_fill.get("h3maped_water_mode_code", -1)) != 0:
		_fail("h3maped span-fill identity drifted: %s" % JSON.stringify(span_fill))
		return
	if String(span_fill.get("boundary_status", "")) != "private_context_ready" \
			or int(span_fill.get("boundary_unique_cell_count", -1)) != 238 \
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
			or int(span_fill.get("blocked_initial_span_count", -1)) != 1 \
			or String(span_fill.get("blocked_next", "")) != "0x4a3710_ordering_finalizer":
		_fail("h3maped span-fill counts drifted: %s" % JSON.stringify(span_fill))
		return
	var cells_by_zone_word: Dictionary = span_fill.get("cells_by_zone_word", {})
	if int(cells_by_zone_word.get("0", -1)) != 177 \
			or int(cells_by_zone_word.get("1", -1)) != 91 \
			or int(cells_by_zone_word.get("2", -1)) != 226 \
			or int(cells_by_zone_word.get("3", -1)) != 177 \
			or int(cells_by_zone_word.get("4", -1)) != 207 \
			or int(cells_by_zone_word.get("5", -1)) != 229:
		_fail("h3maped span-fill zone-word distribution drifted: %s" % JSON.stringify(cells_by_zone_word))
		return
	var zone_fill_reports: Array = span_fill.get("zone_fill_reports", [])
	if zone_fill_reports.size() != 6 \
			or String(zone_fill_reports[0].get("status", "")) != "0x4a325d_span_fill_executed" \
			or int(zone_fill_reports[0].get("runtime_zone_index", -1)) != 0 \
			or int(zone_fill_reports[0].get("filled_cell_count", -1)) != 151 \
			or int(zone_fill_reports[1].get("filled_cell_count", -1)) != 48 \
			or int(zone_fill_reports[2].get("blocked_initial_span_count", -1)) != 1 \
			or int(zone_fill_reports[5].get("runtime_zone_index", -1)) != 5:
		_fail("h3maped span-fill zone reports drifted: %s" % JSON.stringify(zone_fill_reports))
		return

	var footprint_finalizer: Dictionary = private_context.get("footprint_finalizer_context", {})
	if String(footprint_finalizer.get("phase_id", "")) != "footprint_finalizer_4a3710" \
			or String(footprint_finalizer.get("h3maped_anchor", "")) != "0x4a3710" \
			or String(footprint_finalizer.get("call_site_anchor", "")) != "0x4a3efc..0x4a3f05" \
			or String(footprint_finalizer.get("polygon_locator_anchor", "")) != "0x4cca55" \
			or String(footprint_finalizer.get("clip_helper_anchor", "")) != "0x4a2b33" \
			or String(footprint_finalizer.get("zone_order_reset_anchor", "")) != "0x49b61b" \
			or String(footprint_finalizer.get("per_zone_order_helper_anchor", "")) != "0x4a3554" \
			or String(footprint_finalizer.get("adjacency_vector_offset", "")) != "runtime_zone+0xc4" \
			or String(footprint_finalizer.get("ordering_vector_offset", "")) != "runtime_zone+0x3e8" \
			or String(footprint_finalizer.get("status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported_private" \
			or int(footprint_finalizer.get("level_count", -1)) != 1 \
			or int(footprint_finalizer.get("h3maped_water_mode_code", -1)) != 0 \
			or bool(footprint_finalizer.get("synthetic_branch_allowed_by_0x4a3a9d", true)) \
			or int(footprint_finalizer.get("original_same_level_runtime_zone_count", -1)) != 6 \
			or int(footprint_finalizer.get("final_runtime_zone_count", -1)) != 6 \
			or int(footprint_finalizer.get("appended_runtime_zone_count", -1)) != 0:
		_fail("h3maped footprint finalizer identity drifted: %s" % JSON.stringify(footprint_finalizer))
		return
	if int(footprint_finalizer.get("zone_order_reset_call_count", -1)) != 6 \
			or int(footprint_finalizer.get("per_zone_order_helper_call_count", -1)) != 6 \
			or int(footprint_finalizer.get("materialized_adjacency_count", -1)) != 0 \
			or bool(footprint_finalizer.get("materializes_zone_cells", true)) \
			or bool(footprint_finalizer.get("materializes_boundary_cells", true)) \
			or bool(footprint_finalizer.get("materializes_span_fill", true)) \
			or bool(footprint_finalizer.get("materializes_terrain", true)) \
			or bool(footprint_finalizer.get("materializes_map_cells", true)) \
			or bool(footprint_finalizer.get("public_package_output_allowed", true)) \
			or String(footprint_finalizer.get("blocked_next", "")) != "0x4a3f27_terrain_cell_writeout":
		_fail("h3maped footprint finalizer counts drifted: %s" % JSON.stringify(footprint_finalizer))
		return
	var finalizer_phases: Array = footprint_finalizer.get("phases", [])
	if finalizer_phases.size() != 3 \
			or String(finalizer_phases[0].get("address_range", "")) != "0x4a3735..0x4a3874" \
			or String(finalizer_phases[0].get("status", "")) != "skipped_no_appended_runtime_zones" \
			or String(finalizer_phases[1].get("address_range", "")) != "0x4a3879..0x4a38be" \
			or int(finalizer_phases[1].get("zone_order_reset_call_count", -1)) != 6 \
			or int(finalizer_phases[1].get("per_zone_order_helper_call_count", -1)) != 6 \
			or String(finalizer_phases[2].get("status", "")) != "skipped_no_appended_runtime_zones":
		_fail("h3maped footprint finalizer phase reports drifted: %s" % JSON.stringify(finalizer_phases))
		return

	var runtime_terrain: Dictionary = private_context.get("runtime_terrain_selection_context", {})
	if String(runtime_terrain.get("phase_id", "")) != "runtime_terrain_selection_49b53d" \
			or String(runtime_terrain.get("h3maped_anchor", "")) != "0x49b53d" \
			or String(runtime_terrain.get("town_to_terrain_table_address", "")) != "0x540908" \
			or String(runtime_terrain.get("status", "")) != "private_context_ready" \
			or int(runtime_terrain.get("selection_count", -1)) != 6 \
			or Array(runtime_terrain.get("selected_h3maped_terrain_ids", [])) != [2, 0, 7, 7, 4, 5] \
			or Array(runtime_terrain.get("selected_project_terrain_ids", [])) != ["grass", "dirt", "lava", "lava", "swamp", "rough"] \
			or int(runtime_terrain.get("match_to_town_count", -1)) != 4 \
			or int(runtime_terrain.get("allowed_flag_choice_count", -1)) != 2 \
			or int(runtime_terrain.get("blank_allowed_mask_count", -1)) != 0 \
			or int(runtime_terrain.get("forced_subterranean_count", -1)) != 0 \
			or int(runtime_terrain.get("rng_call_count", -1)) != 2 \
			or int(runtime_terrain.get("rng_state_before_0x49b53d_uint32", -1)) != 255755822 \
			or int(runtime_terrain.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160 \
			or bool(runtime_terrain.get("materializes_terrain_cells", true)) \
			or bool(runtime_terrain.get("materializes_terrain_art", true)) \
			or bool(runtime_terrain.get("materializes_map_cells", true)) \
			or bool(runtime_terrain.get("public_package_output_allowed", true)) \
			or String(runtime_terrain.get("blocked_next", "")) != "0x4a3f27_terrain_cell_writeout":
		_fail("h3maped runtime terrain selection drifted: %s" % JSON.stringify(runtime_terrain))
		return
	var terrain_selections: Array = runtime_terrain.get("selections", [])
	if terrain_selections.size() != 6 \
			or String(terrain_selections[0].get("faction_id", "")) != "elemental" \
			or int(terrain_selections[0].get("selected_h3maped_terrain_id", -1)) != 2 \
			or String(terrain_selections[1].get("faction_id", "")) != "necropolis" \
			or int(terrain_selections[1].get("selected_h3maped_terrain_id", -1)) != 0 \
			or int(terrain_selections[2].get("rng_value", -1)) != 153 \
			or int(terrain_selections[2].get("selected_h3maped_terrain_id", -1)) != 7 \
			or String(terrain_selections[3].get("faction_id", "")) != "inferno" \
			or String(terrain_selections[4].get("faction_id", "")) != "fortress" \
			or int(terrain_selections[5].get("rng_value", -1)) != 292 \
			or int(terrain_selections[5].get("selected_h3maped_terrain_id", -1)) != 5:
		_fail("h3maped runtime terrain selection records drifted: %s" % JSON.stringify(terrain_selections))
		return

	var terrain_writeout: Dictionary = private_context.get("terrain_cell_writeout_context", {})
	if String(terrain_writeout.get("phase_id", "")) != "terrain_cell_writeout_4a3f27" \
			or String(terrain_writeout.get("h3maped_anchor", "")) != "0x4a3f27" \
			or String(terrain_writeout.get("full_map_water_repaint_address", "")) != "0x4a4025" \
			or String(terrain_writeout.get("per_zone_repaint_loop_address", "")) != "0x4a4082" \
			or String(terrain_writeout.get("per_cell_repaint_call_address", "")) != "0x4a415a" \
			or String(terrain_writeout.get("owner_byte_gate_address", "")) != "0x4a4142" \
			or String(terrain_writeout.get("reserved_flag_gate_address", "")) != "0x4a4150" \
			or String(terrain_writeout.get("tile_serializer_address", "")) != "0x49b2b6" \
			or String(terrain_writeout.get("status", "")) != "private_context_ready" \
			or int(terrain_writeout.get("cell_count", -1)) != 1296 \
			or int(terrain_writeout.get("tile_byte_zero_terrain_cell_count", -1)) != 1296 \
			or int(terrain_writeout.get("tile_byte_zero_non_water_terrain_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("unassigned_water_cell_count", -1)) != 189 \
			or int(terrain_writeout.get("reserved_flag_cell_count", -1)) != 1107 \
			or int(terrain_writeout.get("owner_low_byte_materialized_count", -1)) != 1107 \
			or int(terrain_writeout.get("tile_byte_one_nonzero_art_cell_count", -1)) != 0 \
			or int(terrain_writeout.get("tile_byte_six_terrain_flip_cell_count", -1)) != 0 \
			or bool(terrain_writeout.get("materializes_terrain_art", true)) \
			or bool(terrain_writeout.get("materializes_roads", true)) \
			or bool(terrain_writeout.get("materializes_objects", true)) \
			or bool(terrain_writeout.get("materializes_package_tiles", true)) \
			or bool(terrain_writeout.get("project_grid_public_runtime_adoption", true)) \
			or bool(terrain_writeout.get("public_package_output_allowed", true)) \
			or String(terrain_writeout.get("blocked_next", "")) != "TerrainPlacement_0x4bcff5_0x4bd099_art_index_flip_writeout":
		_fail("h3maped terrain-cell writeout identity/counts drifted: %s" % JSON.stringify(terrain_writeout))
		return
	var terrain_counts: Dictionary = terrain_writeout.get("terrain_name_counts", {})
	if int(terrain_counts.get("water", -1)) != 189 \
			or int(terrain_counts.get("grass", -1)) != 177 \
			or int(terrain_counts.get("dirt", -1)) != 91 \
			or int(terrain_counts.get("lava", -1)) != 403 \
			or int(terrain_counts.get("swamp", -1)) != 207 \
			or int(terrain_counts.get("rough", -1)) != 229:
		_fail("h3maped terrain name counts drifted: %s" % JSON.stringify(terrain_counts))
		return
	var h3_terrain_counts: Dictionary = terrain_writeout.get("h3_terrain_code_counts", {})
	if int(h3_terrain_counts.get("8", -1)) != 189 \
			or int(h3_terrain_counts.get("2", -1)) != 177 \
			or int(h3_terrain_counts.get("0", -1)) != 91 \
			or int(h3_terrain_counts.get("7", -1)) != 403 \
			or int(h3_terrain_counts.get("4", -1)) != 207 \
			or int(h3_terrain_counts.get("5", -1)) != 229:
		_fail("h3maped terrain code counts drifted: %s" % JSON.stringify(h3_terrain_counts))
		return
	var repaint_schedule: Dictionary = terrain_writeout.get("terrain_repaint_schedule", {})
	if String(repaint_schedule.get("status", "")) != "0x4a3f27_water_then_zone_single_cell_repaint_schedule_ported_private" \
			or int(repaint_schedule.get("initial_water_full_map_cell_count", -1)) != 1296 \
			or int(repaint_schedule.get("single_cell_repaint_count", -1)) != 1107 \
			or bool(repaint_schedule.get("two_level_rock_prefill_executed", true)) \
			or bool(repaint_schedule.get("materializes_visual_art", true)):
		_fail("h3maped terrain repaint schedule drifted: %s" % JSON.stringify(repaint_schedule))
		return

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Supported small generation must remain blocked by the fresh h3maped boundary: %s" % JSON.stringify(generated))
		return
	if Array(generated.get("private_generation_context", {}).get("completed_phase_ids", [])) != completed_private_phases:
		_fail("Blocked generation result did not carry the same private phase context: %s" % JSON.stringify(generated))
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

	print("%s: PASS fresh h3maped small RMG boundary blocks runtime generation and legacy fallback" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
