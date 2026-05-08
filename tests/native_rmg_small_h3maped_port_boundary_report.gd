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
		_fail("Small h3maped port inspection did not accept the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "h3maped_small_template_vector_recovered":
		_fail("Unexpected small h3maped inspection status: %s" % JSON.stringify(report))
		return
	if int(report.get("size_score", -1)) != 1 or int(report.get("h3maped_water_mode_code", -1)) != 0:
		_fail("Small land size score/water code did not follow the recovered formula: %s" % JSON.stringify(report))
		return
	if int(report.get("accepted_template_count", -1)) != 13:
		_fail("Small 1-human/3-player accepted-template vector drifted from recovered catalog evidence: %s" % JSON.stringify(report))
		return
	if String(report.get("selected_template_status", "")) != "h3maped_rng_selected":
		_fail("The port did not select a template through the recovered h3maped RNG: %s" % JSON.stringify(report))
		return
	if int(report.get("selected_template_vector_index", -1)) != 2:
		_fail("The recovered h3maped RNG selected an unexpected vector index for seed 1: %s" % JSON.stringify(report))
		return
	var rng: Dictionary = report.get("h3maped_rng", {})
	if int(rng.get("first_value", -1)) != 41 or int(rng.get("selected_vector_index", -1)) != 2:
		_fail("The recovered h3maped RNG first step drifted from the executable formula: %s" % JSON.stringify(report))
		return
	var selected_template: Dictionary = report.get("selected_template", {})
	if String(selected_template.get("id", "")) != "h3maped_template_018":
		_fail("The recovered h3maped RNG selected the wrong accepted template for seed 1: %s" % JSON.stringify(report))
		return
	var selected_payload: Dictionary = report.get("selected_template_payload", {})
	if String(selected_payload.get("status", "")) != "adapted_template_found":
		_fail("The selected h3maped source template was not resolved through the adapted catalog provenance: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("adapted_template_id", "")) != "translated_rmg_template_019_v1":
		_fail("The selected h3maped source template resolved to the wrong adapted template id: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("zone_count", -1)) != 6 or int(selected_payload.get("link_count", -1)) != 5:
		_fail("The selected h3maped source template payload lost zone/link topology: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("player_start_zone_count", -1)) != 4 or int(selected_payload.get("treasure_zone_count", -1)) != 2:
		_fail("The selected h3maped source template payload lost source zone roles: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("minimum_player_castles_before_assignment", -1)) != 4:
		_fail("The selected h3maped source template payload lost player-town/castle requirements: %s" % JSON.stringify(report))
		return
	if selected_payload.get("human_capable_source_owner_indices", []) != [0, 1, 2, 3]:
		_fail("The selected h3maped source template payload lost the 0x4ac552 human-capable owner bitmap: %s" % JSON.stringify(report))
		return
	if selected_payload.get("player_capable_source_owner_indices", []) != [0, 1, 2, 3]:
		_fail("The selected h3maped source template payload lost the 0x4ac552 player-capable owner bitmap: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("assignment_status", "")) != "0x4ac552_player_slot_assignment_ported":
		_fail("The selected h3maped payload did not port the 0x4ac552 player-slot assignment step: %s" % JSON.stringify(report))
		return
	var assignment: Dictionary = selected_payload.get("player_slot_assignment", {})
	if assignment.get("selected_color_bitmap", []) != [false, false, false, false, false, false, false, false]:
		_fail("Default h3maped selected-color bitmap must follow the constructor-zeroed generator+0xed8 state: %s" % JSON.stringify(report))
		return
	if assignment.get("selected_color_order", []) != [0, 1, 2, 3, 4, 5, 6, 7]:
		_fail("Default h3maped color order drifted from 0x4ac63f..0x4ac66e: %s" % JSON.stringify(report))
		return
	if assignment.get("actual_colors_by_source_owner", []) != [0, 1, 2, -1, -1, -1, -1, -1]:
		_fail("The selected h3maped payload assigned the wrong source-owner to player-color mapping: %s" % JSON.stringify(report))
		return
	if int(assignment.get("assigned_player_count", -1)) != 3:
		_fail("The selected h3maped payload did not assign all requested players: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("runtime_zone_seed_status", "")) != "0x4a218c_runtime_zone_vector_seed_ported":
		_fail("The selected h3maped payload did not port the 0x4a218c runtime-zone seed boundary: %s" % JSON.stringify(report))
		return
	var runtime_zone_seed: Dictionary = selected_payload.get("runtime_zone_seed", {})
	if int(runtime_zone_seed.get("runtime_zone_count", -1)) != 6 or int(runtime_zone_seed.get("runtime_link_seed_count", -1)) != 5:
		_fail("The 0x4a218c runtime-zone seed boundary lost zone/link cardinality: %s" % JSON.stringify(report))
		return
	if int(runtime_zone_seed.get("min_source_zone_size", -1)) != 11:
		_fail("The 0x4a218c runtime-zone seed boundary did not preserve the source +0x08 min-size scan: %s" % JSON.stringify(report))
		return
	if int(runtime_zone_seed.get("scale_divisor", -1)) != 5 or int(runtime_zone_seed.get("link_seed_scale_argument", -1)) != 79:
		_fail("The 0x4a218c runtime-zone seed boundary drifted from the executable land scale argument: %s" % JSON.stringify(report))
		return
	var runtime_zones: Array = runtime_zone_seed.get("runtime_zones", [])
	if runtime_zones.size() < 3:
		_fail("The 0x4a218c runtime-zone seed boundary did not expose runtime zones: %s" % JSON.stringify(report))
		return
	if int(runtime_zones[0].get("actual_player_color", -1)) != 0 or int(runtime_zones[1].get("actual_player_color", -1)) != 1 or int(runtime_zones[2].get("actual_player_color", 99)) != -1:
		_fail("The 0x4a218c runtime-zone seed boundary did not carry player-slot assignment into runtime zones: %s" % JSON.stringify(report))
		return
	if String(runtime_zone_seed.get("coordinate_seed_status", "")) != "0x4a1f3b_0x4a17f5_0x4a1ad8_0x4a19ed_single_level_ported":
		_fail("The 0x4a218c boundary did not port the single-level h3maped coordinate seed and bbox rescale path: %s" % JSON.stringify(report))
		return
	var coordinate_seed: Dictionary = runtime_zone_seed.get("coordinate_seed", {})
	if int(coordinate_seed.get("placement_step_count", -1)) != 18 or int(coordinate_seed.get("rng_calls_after_template_selection", -1)) != 18:
		_fail("The h3maped coordinate seed path did not execute the initial insertion plus two refinement passes: %s" % JSON.stringify(report))
		return
	var bbox: Dictionary = coordinate_seed.get("bounding_box_rescale", {})
	if int(bbox.get("map_span", -1)) != 36 or int(bbox.get("selected_span_before_rescale", 0)) <= 0:
		_fail("The h3maped 0x4a19ed bbox rescale evidence is missing or invalid: %s" % JSON.stringify(report))
		return
	if not runtime_zones[0].has("x_after_bbox_rescale") or not runtime_zones[0].has("y_after_bbox_rescale") or int(runtime_zones[0].get("runtime_size_after_bbox_rescale", 0)) <= 0:
		_fail("Runtime zones did not expose post-0x4a19ed coordinate and size evidence: %s" % JSON.stringify(report))
		return
	if String(runtime_zone_seed.get("level_footprint_phase_status", "")) != "0x4a3a03_level_collection_ported_helpers_blocked":
		_fail("The h3maped 0x4a3a03 level-collection boundary did not run or did not expose the real helper blocker: %s" % JSON.stringify(report))
		return
	var level_footprint_phase: Dictionary = runtime_zone_seed.get("level_footprint_phase", {})
	var levels: Array = level_footprint_phase.get("levels", [])
	if int(level_footprint_phase.get("level_count", -1)) != 1 or levels.size() != 1:
		_fail("The h3maped 0x4a3a03 level loop did not match the small one-level scope: %s" % JSON.stringify(report))
		return
	var level_zero: Dictionary = levels[0]
	if int(level_zero.get("matching_runtime_zone_count", -1)) != 6 or bool(level_zero.get("synthetic_fallback_zone_allowed_by_0x4a3a9d", true)):
		_fail("The h3maped 0x4a3a03 level collection or land synthetic-zone branch drifted from the executable: %s" % JSON.stringify(report))
		return
	if level_zero.get("helper_call_sequence", []) != ["0x4a2777", "0x4a325d", "0x4a3710"]:
		_fail("The h3maped 0x4a3a03 helper trio was not reported as the concrete next blocker: %s" % JSON.stringify(report))
		return
	var first_helper: Dictionary = level_footprint_phase.get("first_helper_evidence", {})
	if String(first_helper.get("status", "")) != "0x4a2777_disassembled_4a261a_line_writer_ported_runtime_layout_blocked":
		_fail("The h3maped 0x4a2777 footprint helper evidence was not exposed with the ported 0x4a261a line-writer boundary: %s" % JSON.stringify(report))
		return
	if String(first_helper.get("clip_helper_address", "")) != "0x4a2b33" or String(first_helper.get("line_cell_writer_address", "")) != "0x4a261a":
		_fail("The h3maped 0x4a2777 helper lost its executable-backed clipping/cell-writer addresses: %s" % JSON.stringify(report))
		return
	if int(first_helper.get("map_cell_stride_bytes", -1)) != 48 or int(first_helper.get("materialized_cell_count", -1)) != 0:
		_fail("The h3maped 0x4a2777 helper report must not fake materialized footprint cells: %s" % JSON.stringify(report))
		return
	if first_helper.get("recovered_operations", []).size() < 6 or first_helper.get("missing_runtime_layout", []).size() < 4:
		_fail("The h3maped 0x4a2777 helper report does not distinguish recovered behavior from missing runtime layout: %s" % JSON.stringify(report))
		return
	if String(first_helper.get("line_writer_status", "")) != "0x4a261a_cell_line_writer_ported":
		_fail("The h3maped 0x4a2777 helper did not expose the ported 0x4a261a line writer: %s" % JSON.stringify(report))
		return
	var line_writer: Dictionary = first_helper.get("line_writer_evidence", {})
	if String(line_writer.get("status", "")) != "0x4a261a_cell_line_writer_ported":
		_fail("The h3maped 0x4a261a line-writer report did not run: %s" % JSON.stringify(report))
		return
	if int(line_writer.get("sample_line_count", -1)) != 5:
		_fail("The h3maped 0x4a261a line-writer report lost sample coverage: %s" % JSON.stringify(report))
		return
	var sample_lines: Array = line_writer.get("sample_lines", [])
	for sample in sample_lines:
		if not sample is Dictionary:
			_fail("The h3maped 0x4a261a sample line report was malformed: %s" % JSON.stringify(report))
			return
		if int(sample.get("trace_write_count", 0)) <= 0 or int(sample.get("unique_cell_count", 0)) <= 0 or int(sample.get("out_of_bounds_write_count", -1)) != 0:
			_fail("The h3maped 0x4a261a sample line did not materialize in-bounds cells: %s" % JSON.stringify(report))
			return
	var second_helper: Dictionary = level_footprint_phase.get("second_helper_evidence", {})
	if String(second_helper.get("status", "")) != "0x4a325d_disassembled_cell_span_fill_blocked":
		_fail("The h3maped 0x4a325d span-fill helper evidence was not exposed as the concrete next runtime-layout blocker: %s" % JSON.stringify(report))
		return
	if String(second_helper.get("unassigned_zone_word_sentinel", "")) != "0x00ff0000" or int(second_helper.get("materialized_cell_count", -1)) != 0:
		_fail("The h3maped 0x4a325d helper report must expose the unassigned cell sentinel without faking filled cells: %s" % JSON.stringify(report))
		return
	var finalizer: Dictionary = level_footprint_phase.get("finalizer_evidence", {})
	if String(finalizer.get("status", "")) != "0x4a3710_disassembled_adjacency_finalizer_blocked":
		_fail("The h3maped 0x4a3710 adjacency finalizer evidence was not exposed as the concrete next runtime-layout blocker: %s" % JSON.stringify(report))
		return
	if String(finalizer.get("adjacency_vector_offset", "")) != "runtime_zone+0xc4" or int(finalizer.get("materialized_adjacency_count", -1)) != 0:
		_fail("The h3maped 0x4a3710 finalizer report must expose adjacency vectors without faking finalized links: %s" % JSON.stringify(report))
		return
	var runtime_layout: Dictionary = level_footprint_phase.get("runtime_layout_evidence", {})
	if String(runtime_layout.get("status", "")) != "runtime_polygon_seed_points_split_cleanup_and_finalizer_ported_span_fill_pending":
		_fail("The h3maped runtime polygon layout evidence did not expose the current executable-backed boundary: %s" % JSON.stringify(report))
		return
	if int(runtime_layout.get("polygon_node_size_bytes", -1)) != 36:
		_fail("The recovered h3maped polygon node size drifted from the 0x4cc5db allocation size: %s" % JSON.stringify(report))
		return
	var runtime_offsets: Dictionary = runtime_layout.get("runtime_zone_offsets", {})
	if String(runtime_offsets.get("+0x3e4", "")).find("short ordering") < 0 or String(runtime_offsets.get("+0x3f4", "")).find("footprint vertices") < 0:
		_fail("The recovered h3maped runtime-zone vector offsets are missing ordering/footprint evidence: %s" % JSON.stringify(report))
		return
	var polygon_offsets: Dictionary = runtime_layout.get("polygon_node_offsets", {})
	if String(polygon_offsets.get("+0x18", "")).find("finalized") < 0 or String(polygon_offsets.get("+0x1c", "")).find("intersection") < 0:
		_fail("The recovered h3maped polygon-node finalized/intersection offsets are missing: %s" % JSON.stringify(report))
		return
	var polygon_seed: Dictionary = level_footprint_phase.get("polygon_seed_evidence", {})
	if String(polygon_seed.get("status", "")) != "0x4a3a03_polygon_tree_seed_calls_split_cleanup_and_finalizer_ported_span_fill_pending":
		_fail("The h3maped 0x4a3a03 polygon seed-call schedule was not exposed: %s" % JSON.stringify(report))
		return
	if int(polygon_seed.get("materialized_primary_split_seed_count", -1)) != 6:
		_fail("The h3maped 0x4a3a03 polygon seed-call count drifted for the selected small template: %s" % JSON.stringify(report))
		return
	var polygon_levels: Array = polygon_seed.get("levels", [])
	if polygon_levels.size() != 1 or int(polygon_levels[0].get("split_call_count", -1)) != 6:
		_fail("The h3maped polygon seed-call report did not match the one-level six-zone selected template: %s" % JSON.stringify(report))
		return
	if String(polygon_seed.get("split_algorithm_status", "")) != "0x4ccb64_insertion_bridge_crossing_cleanup_and_finalizer_ported_span_fill_pending":
		_fail("The h3maped polygon seed-call report must expose the ported split cleanup/finalizer model and remaining span-fill blocker: %s" % JSON.stringify(report))
		return
	var pre_crossing_model: Dictionary = polygon_seed.get("runtime_split_pre_crossing_model", {})
	if int(pre_crossing_model.get("executed_split_call_count", -1)) != 6 or int(pre_crossing_model.get("pre_crossing_inserted_node_pair_count", -1)) != 6:
		_fail("The h3maped pre-crossing split model did not execute the six primary insertions: %s" % JSON.stringify(report))
		return
	if int(pre_crossing_model.get("pre_crossing_inserted_bridge_pair_count", -1)) != 13 or int(pre_crossing_model.get("post_crossing_cleanup_active_node_pair_count", -1)) != 23:
		_fail("The h3maped pre-crossing bridge/node-pair counts drifted from the executable model: %s" % JSON.stringify(report))
		return
	if int(pre_crossing_model.get("post_crossing_cleanup_allocated_node_pair_count", -1)) != 24 or int(pre_crossing_model.get("edge_removal_branch_count", -1)) != 1:
		_fail("The h3maped edge-removal/vector allocation counts drifted from the executable model: %s" % JSON.stringify(report))
		return
	if int(pre_crossing_model.get("duplicate_skip_count", -1)) != 0 or int(pre_crossing_model.get("crossing_test_count", -1)) != 24 or int(pre_crossing_model.get("crossing_collapse_count", -1)) != 6:
		_fail("The h3maped crossing cleanup counts drifted from the executable model: %s" % JSON.stringify(report))
		return
	if String(pre_crossing_model.get("crossing_cleanup_status", "")) != "0x4ccc7a_0x4cc68e_crossing_cleanup_ported":
		_fail("The h3maped split model did not port crossing cleanup: %s" % JSON.stringify(report))
		return
	if String(pre_crossing_model.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_ported":
		_fail("The h3maped split model did not port the 0x4ccdfc finalized-node fanout: %s" % JSON.stringify(report))
		return
	if int(pre_crossing_model.get("finalized_triplet_count", -1)) != 14 or int(pre_crossing_model.get("finalized_node_count", -1)) != 42:
		_fail("The h3maped 0x4ccdfc finalized-node fanout counts drifted from the executable model: %s" % JSON.stringify(report))
		return
	if int(pre_crossing_model.get("active_payload_node_count", -1)) != 28:
		_fail("The h3maped 0x4ccdfc payload-gated node count drifted from the executable model: %s" % JSON.stringify(report))
		return
	var polygon_splitter: Dictionary = level_footprint_phase.get("polygon_splitter_contract", {})
	if String(polygon_splitter.get("status", "")) != "0x4cca55_0x4ccb64_splitter_contract_recovered_mutation_not_executed":
		_fail("The h3maped polygon splitter contract did not expose the recovered locator/splitter boundary: %s" % JSON.stringify(report))
		return
	if String(polygon_splitter.get("locator_address", "")) != "0x4cca55" or String(polygon_splitter.get("splitter_address", "")) != "0x4ccb64":
		_fail("The h3maped polygon splitter contract lost its executable locator/splitter addresses: %s" % JSON.stringify(report))
		return
	if String(polygon_splitter.get("initial_container_status", "")) != "0x4cc788_initial_node_pair_allocations_inline_relinks_and_bridge_ported_splitter_pending":
		_fail("The h3maped initial polygon container allocations were not materialized from 0x4cc788: %s" % JSON.stringify(report))
		return
	if int(polygon_splitter.get("materialized_initial_boundary_node_pair_count", -1)) != 4 or int(polygon_splitter.get("materialized_initial_bridge_node_pair_count", -1)) != 1:
		_fail("The h3maped 0x4cc788 initial boundary/bridge pair counts drifted: %s" % JSON.stringify(report))
		return
	if int(polygon_splitter.get("materialized_initial_node_pair_count", -1)) != 5 or int(polygon_splitter.get("materialized_initial_node_count", -1)) != 10:
		_fail("The h3maped 0x4cc788 initial polygon allocation counts drifted: %s" % JSON.stringify(report))
		return
	if int(polygon_splitter.get("initial_vector_entry_count", -1)) != 10 or String(polygon_splitter.get("initial_root_pointer", "")) != "initial_pair_0_primary":
		_fail("The h3maped initial polygon vector/root evidence drifted: %s" % JSON.stringify(report))
		return
	if int(polygon_splitter.get("initial_inline_relink_swap_count", -1)) != 4 or String(polygon_splitter.get("initial_bridge_call_status", "")) != "0x4ccb1f_initial_constructor_bridge_ported":
		_fail("The h3maped initial polygon inline relink/bridge boundary drifted: %s" % JSON.stringify(report))
		return
	var initial_pairs: Array = polygon_splitter.get("initial_node_pairs", [])
	var initial_bridge_pair: Dictionary = polygon_splitter.get("initial_bridge_node_pair", {})
	if initial_pairs.size() != 4 or String(initial_pairs[0].get("primary", {}).get("+0x10_next", "")) != "initial_bridge_pair_0_primary":
		_fail("The h3maped initial polygon inline next/previous links were not exposed: %s" % JSON.stringify(report))
		return
	if String(initial_bridge_pair.get("primary_node_id", "")) != "initial_bridge_pair_0_primary" or String(initial_bridge_pair.get("paired", {}).get("+0x10_next", "")) != "initial_pair_1_paired":
		_fail("The h3maped 0x4ccb1f initial bridge node pair was not exposed: %s" % JSON.stringify(report))
		return
	if polygon_splitter.get("locator_branches", []).size() < 5 or polygon_splitter.get("split_steps", []).size() < 7:
		_fail("The h3maped polygon splitter contract is missing recovered branch/split steps: %s" % JSON.stringify(report))
		return
	if int(polygon_splitter.get("materialized_split_node_count", -1)) != 0:
		_fail("The h3maped polygon splitter contract must not fake executed topology mutation: %s" % JSON.stringify(report))
		return
	var phase_sequence: Array = selected_payload.get("phase_sequence", [])
	if phase_sequence.size() != 15 or String(selected_payload.get("phase_sequence_status", "")) != "assignment_and_runtime_zone_seed_ported_remaining_phases_documented_not_executed":
		_fail("The selected h3maped payload did not report the recovered 0x4ac552 phase sequence boundary: %s" % JSON.stringify(report))
		return
	var accepted_ids := _accepted_template_ids(report)
	for required_id in ["h3maped_template_000", "h3maped_template_012", "h3maped_template_048"]:
		if not accepted_ids.has(required_id):
			_fail("Recovered accepted-template vector missed %s: %s" % [required_id, JSON.stringify(report)])
			return
	if accepted_ids.has("h3maped_template_010"):
		_fail("Recovered accepted-template vector included a 2-player-only template for 3 players: %s" % JSON.stringify(report))
		return

	var color_config := config.duplicate(true)
	var color_constraints: Dictionary = color_config.get("player_constraints", {}).duplicate(true)
	color_constraints["selected_color_bitmap"] = [false, false, true, false, false, false, false, false]
	color_config["player_constraints"] = color_constraints
	var color_report: Dictionary = service.inspect_h3maped_small_rmg_port(color_config)
	var color_assignment: Dictionary = color_report.get("selected_template_payload", {}).get("player_slot_assignment", {})
	if color_assignment.get("selected_color_order", []) != [2, 0, 1, 3, 4, 5, 6, 7]:
		_fail("Explicit h3maped selected-color bitmap did not control 0x4ac63f..0x4ac66e order: %s" % JSON.stringify(color_report))
		return
	if color_assignment.get("actual_colors_by_source_owner", []) != [2, 0, 1, -1, -1, -1, -1, -1]:
		_fail("Explicit h3maped selected-color bitmap did not flow into 0x4ac552 player assignment: %s" % JSON.stringify(color_report))
		return

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) or String(generated.get("status", "")) != "h3maped_small_port_generation_not_ready":
		_fail("Small native_catalog_auto generation did not route to the h3maped boundary: %s" % JSON.stringify(generated))
		return
	if String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Small h3maped boundary did not expose the concrete missing port step: %s" % JSON.stringify(generated))
		return
	var text_seed_config := config.duplicate(true)
	text_seed_config["seed"] = "small-h3maped-boundary-10184"
	var text_seed_report: Dictionary = service.inspect_h3maped_small_rmg_port(text_seed_config)
	if String(text_seed_report.get("selected_template_status", "")) != "blocked_until_numeric_h3maped_seed":
		_fail("Non-numeric seeds must not be mapped through a custom hash in the h3maped port: %s" % JSON.stringify(text_seed_report))
		return

	var medium_config := config.duplicate(true)
	medium_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var medium_report: Dictionary = service.inspect_h3maped_small_rmg_port(medium_config)
	if bool(medium_report.get("ok", true)) or String(medium_report.get("status", "")) != "unsupported_scope":
		_fail("Small h3maped port inspection accepted an out-of-scope medium config: %s" % JSON.stringify(medium_report))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"status": report.get("status", ""),
		"accepted_template_count": report.get("accepted_template_count", 0),
		"selected_template": selected_template.get("id", ""),
		"adapted_template_id": selected_payload.get("adapted_template_id", ""),
		"selected_zone_count": selected_payload.get("zone_count", 0),
		"selected_link_count": selected_payload.get("link_count", 0),
		"coordinate_seed_status": runtime_zone_seed.get("coordinate_seed_status", ""),
		"coordinate_step_count": coordinate_seed.get("placement_step_count", 0),
		"level_footprint_phase_status": runtime_zone_seed.get("level_footprint_phase_status", ""),
		"first_helper_status": first_helper.get("status", ""),
		"line_writer_status": first_helper.get("line_writer_status", ""),
		"second_helper_status": second_helper.get("status", ""),
		"finalizer_status": finalizer.get("status", ""),
		"runtime_layout_status": runtime_layout.get("status", ""),
		"polygon_seed_status": polygon_seed.get("status", ""),
		"polygon_seed_split_count": polygon_seed.get("materialized_primary_split_seed_count", 0),
		"polygon_finalized_triplet_count": pre_crossing_model.get("finalized_triplet_count", 0),
		"polygon_finalized_node_count": pre_crossing_model.get("finalized_node_count", 0),
		"polygon_splitter_status": polygon_splitter.get("status", ""),
		"initial_polygon_node_pairs": polygon_splitter.get("materialized_initial_node_pair_count", 0),
		"phase_count": phase_sequence.size(),
		"generation_status": generated.get("status", ""),
		"unsupported_scope_status": medium_report.get("status", ""),
	})])
	get_tree().quit(0)

func _accepted_template_ids(report: Dictionary) -> Array:
	var result := []
	for item in report.get("accepted_templates", []):
		if item is Dictionary:
			result.append(String(item.get("id", "")))
	return result

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
