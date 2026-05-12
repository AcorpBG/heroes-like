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
	if String(report.get("status", "")) != "h3maped_small_clean_restart_template_selection_ready":
		_fail("Unexpected small h3maped clean-restart status: %s" % JSON.stringify(report))
		return
	if String(report.get("archive_status", "")) != "previous_native_catalog_auto_generator_archived_debug_only":
		_fail("The previous native catalog-auto generator was not explicitly archived: %s" % JSON.stringify(report))
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
	if int(selected_payload.get("player_start_zone_count", -1)) != 4 or int(selected_payload.get("treasure_zone_count", -1)) != 2:
		_fail("The selected h3maped source template payload lost source zone roles: %s" % JSON.stringify(report))
		return
	if int(selected_payload.get("minimum_player_castles_before_assignment", -1)) != 4:
		_fail("The selected h3maped source template payload lost player-town/castle requirements: %s" % JSON.stringify(report))
		return
	var connection_payload: Dictionary = selected_payload.get("connection_payload", {})
	if int(connection_payload.get("connection_count", -1)) != 5 \
			or String(connection_payload.get("normal_guard_materialization_status", "")) != "0x4a65a5_values_scaled_0x4a5e03_guard_inputs_scaled_geometry_pending":
		_fail("0x4a79a3/0x4a65a5 connection guard scaling boundary drifted: %s" % JSON.stringify(connection_payload))
		return
	if int(connection_payload.get("normal_guard_global_strength_mode", -1)) != 3 \
			or int(connection_payload.get("normal_guard_scaled_nonzero_count", -1)) != 5 \
			or int(connection_payload.get("normal_guard_scaled_value_total", -1)) != 16000:
		_fail("0x4a65a5 connection guard values did not scale from raw link Value fields: %s" % JSON.stringify(connection_payload))
		return
	var connection_records: Array = connection_payload.get("connection_records", [])
	if connection_records.size() != 5 \
			or int(connection_records[0].get("raw_guard_value", -1)) != 3000 \
			or int(connection_records[0].get("normal_guard_scaled_value", -1)) != 2000 \
			or int(connection_records[3].get("raw_guard_value", -1)) != 6000 \
			or int(connection_records[3].get("normal_guard_scaled_value", -1)) != 5000:
		_fail("0x4a65a5 per-link scaled guard values drifted: %s" % JSON.stringify(connection_payload))
		return
	if String(connection_payload.get("normal_guard_spawn_intent_status", "")) != "0x4a5e03_guard_inputs_scaled_geometry_endpoint_coordinates_pending" \
			or int(connection_payload.get("normal_guard_spawn_intent_count", -1)) != 5 \
			or int(connection_payload.get("normal_guard_spawn_materialized_count", -1)) != 0 \
			or int(connection_payload.get("normal_guard_spawn_intent_total_value", -1)) != 16000:
		_fail("0x4a5e03 normal guard spawn input boundary drifted: %s" % JSON.stringify(connection_payload))
		return
	if String(connection_payload.get("geometry_dispatch_status", "")) != "0x4a79a3_first_and_second_pass_helper_order_ported_endpoint_geometry_pending" \
			or int(connection_payload.get("geometry_dispatch_link_count", -1)) != 5 \
			or int(connection_payload.get("geometry_endpoint_coordinate_materialized_count", -1)) != 0:
		_fail("0x4a79a3 connection geometry dispatch boundary drifted: %s" % JSON.stringify(connection_payload))
		return
	if String(connection_payload.get("geometry_owner_channel_status", "")) != "0x4a61bc_0x4a696b_high_owner_channel_required_same_level_helpers" \
			or String(connection_payload.get("geometry_4a6cf2_overlap_status", "")) != "0x4a6cf2_same_level_return_false_all_links" \
			or int(connection_payload.get("geometry_4a6cf2_overlap_link_count", -1)) != 5 \
			or int(connection_payload.get("geometry_4a6cf2_same_level_return_false_count", -1)) != 5 \
			or int(connection_payload.get("geometry_4a6cf2_nonempty_overlap_link_count", -1)) != 0 \
			or int(connection_payload.get("geometry_4a6cf2_overlap_cell_total", -1)) != 0 \
			or int(connection_payload.get("geometry_4a6cf2_overlap_high_owner_sentinel_total", -1)) != 0 \
			or int(connection_payload.get("geometry_4a6cf2_overlap_high_owner_materialized_total", -1)) != 0 \
			or int(connection_payload.get("geometry_4a6cf2_endpoint_coordinate_materialized_count", -1)) != 0:
		_fail("0x4a6cf2 same-level gate boundary drifted: %s" % JSON.stringify(connection_payload))
		return
	if String(connection_payload.get("geometry_4a696b_status", "")) != "0x4a696b_same_level_shipyard_lane_helper_identified_all_links_endpoint_geometry_pending" \
			or int(connection_payload.get("geometry_4a696b_link_count", -1)) != 5 \
			or int(connection_payload.get("geometry_4a696b_same_level_ready_count", -1)) != 5 \
			or int(connection_payload.get("geometry_4a696b_endpoint_coordinate_materialized_count", -1)) != 0:
		_fail("0x4a696b same-level helper boundary drifted: %s" % JSON.stringify(connection_payload))
		return
	var geometry_dispatch_plan: Array = connection_payload.get("geometry_dispatch_plan", [])
	if geometry_dispatch_plan.size() != 5:
		_fail("0x4a79a3 dispatch plan did not cover each selected connection: %s" % JSON.stringify(connection_payload))
		return
	var first_dispatch: Dictionary = geometry_dispatch_plan[0]
	var first_pass_helpers: Array = first_dispatch.get("first_pass_helpers", [])
	var second_pass_helpers: Array = first_dispatch.get("second_pass_helpers", [])
	if first_pass_helpers.size() != 3 \
			or String(first_pass_helpers[0]) != "0x4a61bc" \
			or String(first_pass_helpers[1]) != "0x4a696b" \
			or String(first_pass_helpers[2]) != "0x4a6cf2" \
			or second_pass_helpers.size() != 2 \
			or String(second_pass_helpers[0]) != "0x4a696b" \
			or String(second_pass_helpers[1]) != "0x4a7605" \
			or String(first_dispatch.get("wide_geometry_role", "")) != "none_traced_wide_suppresses_normal_guard_after_geometry":
		_fail("0x4a79a3 dispatch helper order or Wide semantics drifted: %s" % JSON.stringify(first_dispatch))
		return
	var first_4a6cf2_overlap: Dictionary = first_dispatch.get("helper_4a6cf2_overlap", {})
	if String(first_4a6cf2_overlap.get("function_address", "")) != "0x4a6cf2" \
			or String(first_4a6cf2_overlap.get("source_range_overlap", "")) != "0x4a6d52..0x4a6ddc" \
			or String(first_4a6cf2_overlap.get("source_range_candidate_scan", "")) != "0x4a6de2..0x4a6f4a" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_source", "")) != "generator+0x6a8" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_begin_offset", "")) != "generator+0x6a8" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_end_offset", "")) != "generator+0x6ac" \
			or int(first_4a6cf2_overlap.get("candidate_shape_vector_pointer_stride_bytes", -1)) != 4 \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_bucket_offset", "")) != "generator+0x34+0x67*0x10" \
			or int(first_4a6cf2_overlap.get("candidate_shape_vector_object_type", -1)) != 103 \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_object_type_name", "")) != "Subterranean Gate" \
			or int(first_4a6cf2_overlap.get("candidate_shape_vector_template_count", -1)) != 1 \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_template_def_name", "")) != "AvTCave.def" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_status", "")) != "0x4a6cf2_type_103_subterranean_gate_bucket_identified" \
			or String(first_4a6cf2_overlap.get("owner_low_byte_source", "")) != "cell+0x20 bits 16..23" \
			or String(first_4a6cf2_overlap.get("owner_high_byte_source", "")) != "cell+0x20 bits 24..31" \
			or String(first_4a6cf2_overlap.get("owner_high_byte_producer", "")) != "0x4a5767 reset plus 0x49a318 anchor/occupancy normalization" \
			or String(first_4a6cf2_overlap.get("same_level_return_false_range", "")) != "0x4a6d3d..0x4a6d40" \
			or String(first_4a6cf2_overlap.get("source_zone_type_gate_range", "")) != "0x4a6d46..0x4a6d4c" \
			or String(first_4a6cf2_overlap.get("owner_channel_status", "")) != "not_read_same_level_return_false" \
			or String(first_4a6cf2_overlap.get("candidate_scan_status", "")) != "0x4a6cf2_skipped_same_level" \
			or String(first_4a6cf2_overlap.get("status", "")) != "0x4a6cf2_same_level_return_false" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_selection_range", "")) != "0x4a6de2..0x4a6e0c" \
			or String(first_4a6cf2_overlap.get("candidate_shape_vector_random_selector_address", "")) != "0x4e7276" \
			or String(first_4a6cf2_overlap.get("validation_helper_address", "")) != "0x49aa93" \
			or int(first_4a6cf2_overlap.get("best_candidate_vector_record_size_bytes", -1)) != 12 \
			or String(first_4a6cf2_overlap.get("best_candidate_vector_clear_helper_address", "")) != "0x4ae52a" \
			or String(first_4a6cf2_overlap.get("best_candidate_vector_append_helper_address", "")) != "0x4ae1fd" \
			or String(first_4a6cf2_overlap.get("best_candidate_random_selection_range", "")) != "0x4a6f50..0x4a6f86" \
			or String(first_4a6cf2_overlap.get("endpoint_record_allocator_address", "")) != "0x5044b1" \
			or String(first_4a6cf2_overlap.get("endpoint_record_constructor_address", "")) != "0x49ba89" \
			or String(first_4a6cf2_overlap.get("endpoint_record_commit_vfunc_slot", "")) != "generator_vtable+0x04" \
			or String(first_4a6cf2_overlap.get("endpoint_vector_offset", "")) != "runtime_zone+0x404" \
			or String(first_4a6cf2_overlap.get("endpoint_vector_append_helper_address", "")) != "0x40bb15" \
			or bool(first_4a6cf2_overlap.get("materializes_endpoint_coordinates", true)) \
			or int(first_4a6cf2_overlap.get("endpoint_coordinate_materialized_count", -1)) != 0 \
			or int(first_4a6cf2_overlap.get("overlap_cell_count", -1)) != 0 \
			or int(first_4a6cf2_overlap.get("overlap_high_owner_a_cell_count", -1)) != 0 \
			or int(first_4a6cf2_overlap.get("overlap_high_owner_b_cell_count", -1)) != 0 \
			or int(first_4a6cf2_overlap.get("overlap_high_other_owner_cell_count", -1)) != 0 \
			or int(first_4a6cf2_overlap.get("overlap_high_owner_sentinel_cell_count", -1)) != 0:
		_fail("0x4a6cf2 same-level gate evidence drifted: %s" % JSON.stringify(first_4a6cf2_overlap))
		return
	var first_4a696b: Dictionary = first_dispatch.get("helper_4a696b", {})
	if String(first_4a696b.get("function_address", "")) != "0x4a696b" \
			or String(first_4a696b.get("source_range_level_gate", "")) != "0x4a69b3..0x4a69bd" \
			or String(first_4a696b.get("source_range_shape_vector", "")) != "0x4a69d3..0x4a6a05" \
			or String(first_4a696b.get("source_range_candidate_scan", "")) != "0x4a6a21..0x4a6b10" \
			or String(first_4a696b.get("source_range_endpoint_record_write", "")) != "0x4a6b2e..0x4a6c4c" \
			or not bool(first_4a696b.get("same_level_required", false)) \
			or String(first_4a696b.get("different_level_return_false_range", "")) != "0x4a69b3..0x4a69bd" \
			or String(first_4a696b.get("candidate_shape_vector_source", "")) != "generator+0x5a8" \
			or String(first_4a696b.get("candidate_shape_vector_begin_offset", "")) != "generator+0x5a8" \
			or String(first_4a696b.get("candidate_shape_vector_end_offset", "")) != "generator+0x5ac" \
			or String(first_4a696b.get("candidate_shape_vector_bucket_offset", "")) != "generator+0x34+0x57*0x10" \
			or int(first_4a696b.get("candidate_shape_vector_object_type", -1)) != 87 \
			or String(first_4a696b.get("candidate_shape_vector_object_type_name", "")) != "Shipyard" \
			or int(first_4a696b.get("candidate_shape_vector_template_count", -1)) != 1 \
			or String(first_4a696b.get("candidate_shape_vector_template_def_name", "")) != "AVXshyd0.def" \
			or String(first_4a696b.get("candidate_shape_vector_status", "")) != "0x4a696b_type_87_shipyard_bucket_identified" \
			or String(first_4a696b.get("owner_low_byte_source", "")) != "cell+0x20 bits 16..23" \
			or String(first_4a696b.get("owner_high_byte_source", "")) != "cell+0x20 bits 24..31" \
			or String(first_4a696b.get("object_presence_reject_source", "")) != "cell+0x28 bit 24" \
			or String(first_4a696b.get("terrain_gate_source", "")) != "cell+0x24 bits 0..5 reject terrain 8" \
			or String(first_4a696b.get("validation_helper_address", "")) != "0x49aa93" \
			or String(first_4a696b.get("lane_helper_address", "")) != "0x4a6795" \
			or String(first_4a696b.get("endpoint_record_allocator_address", "")) != "0x5044b1" \
			or String(first_4a696b.get("endpoint_record_constructor_address", "")) != "0x49ba89" \
			or String(first_4a696b.get("endpoint_record_vtable", "")) != "0x540ab0" \
			or String(first_4a696b.get("road_coordinate_vector_offset", "")) != "generator+0x14b0" \
			or String(first_4a696b.get("runtime_zone_endpoint_vector_offset", "")) != "runtime_zone+0x404" \
			or String(first_4a696b.get("endpoint_vector_append_helper_address", "")) != "0x40bb15" \
			or String(first_4a696b.get("candidate_scan_status", "")) != "0x4a696b_same_level_candidate_scan_recovered_not_materialized" \
			or String(first_4a696b.get("status", "")) != "0x4a696b_same_level_shipyard_lane_helper_identified_endpoint_geometry_pending" \
			or bool(first_4a696b.get("materializes_endpoint_coordinates", true)) \
			or int(first_4a696b.get("endpoint_coordinate_materialized_count", -1)) != 0:
		_fail("0x4a696b same-level helper evidence drifted: %s" % JSON.stringify(first_4a696b))
		return
	var guard_spawn_intents: Array = connection_payload.get("normal_guard_spawn_intents", [])
	if guard_spawn_intents.size() != 5 \
			or String(guard_spawn_intents[0].get("guard_object_helper_address", "")) != "0x4a5e03" \
			or String(guard_spawn_intents[0].get("monster_selector_helper_address", "")) != "0x4a5c07" \
			or int(guard_spawn_intents[0].get("guard_value", -1)) != 2000 \
			or not bool(guard_spawn_intents[0].get("requires_endpoint_coordinates", false)) \
			or bool(guard_spawn_intents[0].get("materializes_guard_object", true)):
		_fail("0x4a5e03 guard spawn intent record did not preserve executable helper inputs and geometry block: %s" % JSON.stringify(connection_payload))
		return
	if String(selected_payload.get("object_category_placement_status", "")) != "0x4a8d2c_0x4a93a2_0x49aa93_town_49a09c_and_writeout_ledger_ported_inspection_only":
		_fail("The clean boundary did not expose h3maped 0x4a8d2c/0x4a93a2/0x49aa93 direct town/castle candidate validity prechecking: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("guard_reward_monster_placement_status", "")) != "0x4a9d6a_0x4a9911_0x4a9641_0x4aab7e_0x4aa354_value_selection_ported_package_adoption_pending":
		_fail("The clean boundary did not expose recovered h3maped mine/reward source fields and 0x4a9641 constraint scanning: %s" % JSON.stringify(report))
		return
	var town_castle_placement: Dictionary = selected_payload.get("town_castle_placement", {})
	if int(town_castle_placement.get("player_min_castle_total", -1)) != 4 or int(town_castle_placement.get("player_min_town_total", -1)) != 0:
		_fail("0x4a8d2c player settlement minimum totals drifted from the selected source fields: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("neutral_min_castle_total", -1)) != 0 or int(town_castle_placement.get("neutral_min_town_total", -1)) != 0:
		_fail("0x4a8d2c neutral settlement minimum totals drifted from the selected source fields: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("minimum_settlement_call_count", -1)) != 4 or int(town_castle_placement.get("density_field_count", -1)) != 24 or int(town_castle_placement.get("positive_density_field_count", -1)) != 0:
		_fail("0x4a8d2c/0x4a8db2 settlement call and density field counts drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("direct_candidate_scan_call_count", -1)) != 4 or int(town_castle_placement.get("direct_candidate_missing_count", -1)) != 1 or int(town_castle_placement.get("direct_owner_minus_one_fail_count", -1)) != 1:
		_fail("0x4a93a2 direct candidate scan did not preserve assigned-owner versus owner-minus-one helper semantics: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("direct_validity_precheck_call_count", -1)) != 3 or int(town_castle_placement.get("direct_validity_precheck_eligible_total", -1)) != 451 or int(town_castle_placement.get("direct_validity_precheck_missing_count", -1)) != 0:
		_fail("0x49a1d8 validity precheck did not preserve the assigned-owner candidate set before full 0x49aa93 collision handling: %s" % JSON.stringify(town_castle_placement))
		return
	if String(town_castle_placement.get("direct_full_eligibility_status", "")) != "0x49aa93_gate_sequence_recovered_data_dependencies_pending":
		_fail("0x49aa93 recovered gate sequence status was not exposed before object stamping: %s" % JSON.stringify(town_castle_placement))
		return
	var full_eligibility_sequence: Array = town_castle_placement.get("direct_full_eligibility_sequence", [])
	if full_eligibility_sequence.size() != 7 or String(full_eligibility_sequence[0].get("address", "")) != "0x49a6f9" or String(full_eligibility_sequence[2].get("address", "")) != "0x49a09c":
		_fail("0x49aa93 recovered gate sequence drifted from executable disassembly: %s" % JSON.stringify(town_castle_placement))
		return
	var object_metadata: Dictionary = town_castle_placement.get("object_metadata_table", {})
	if String(object_metadata.get("status", "")) != "0x57c648_runtime_object_metadata_table_bound_to_text_sources_inspection_only":
		_fail("0x49aa93 object metadata table was not bound to the recovered h3maped runtime source tables: %s" % JSON.stringify(town_castle_placement))
		return
	if int(object_metadata.get("metadata_entry_count", -1)) != 232 or int(object_metadata.get("metadata_entry_size_bytes", -1)) != 16:
		_fail("0x57c648 runtime object metadata table dimensions drifted from recovered executable evidence: %s" % JSON.stringify(object_metadata))
		return
	if String(object_metadata.get("metadata_runtime_table_address", "")) != "0x598300" or String(object_metadata.get("metadata_pointer_global_address", "")) != "0x57c648":
		_fail("0x57c648 metadata pointer/runtime address drifted: %s" % JSON.stringify(object_metadata))
		return
	if int(object_metadata.get("objects_table_declared_row_count", -1)) != 1326 or int(object_metadata.get("objects_table_loaded_row_count", -1)) != 1326:
		_fail("Recovered objects.txt row count drifted: %s" % JSON.stringify(object_metadata))
		return
	if int(object_metadata.get("town_type_id", -1)) != 98 or String(object_metadata.get("town_type_name", "")) != "Town" or int(object_metadata.get("town_template_row_count", -1)) != 9:
		_fail("Recovered Town object template binding drifted: %s" % JSON.stringify(object_metadata))
		return
	if int(object_metadata.get("random_town_type_id", -1)) != 77 or String(object_metadata.get("random_town_type_name", "")) != "Random Town" or int(object_metadata.get("random_town_template_row_count", -1)) != 1:
		_fail("Recovered Random Town object template binding drifted: %s" % JSON.stringify(object_metadata))
		return
	if String(object_metadata.get("town_mask_model_status", "")) != "objects_txt_text_mask_offsets_ported_for_0x49a6f9_inspection" or int(object_metadata.get("town_passability_body_cell_count", -1)) != 13 or int(object_metadata.get("town_action_cell_count", -1)) != 1:
		_fail("Recovered Town passability/action mask model drifted from objects.txt semantics: %s" % JSON.stringify(object_metadata))
		return
	if String(town_castle_placement.get("town_footprint_mask_status", "")) != "0x49a6f9_town_text_mask_body_scan_ported_inspection_only_object_collision_pending":
		_fail("0x49a6f9 Town text mask body scan was not exposed at the town/castle placement boundary: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("town_footprint_mask_scan_call_count", -1)) != 3 or int(town_castle_placement.get("town_footprint_mask_eligible_total", -1)) != 97 or int(town_castle_placement.get("town_footprint_mask_missing_count", -1)) != 0:
		_fail("0x49a6f9 Town text mask body scan candidate totals drifted from the seed-1 boundary: %s" % JSON.stringify(town_castle_placement))
		return
	if String(town_castle_placement.get("object_cell_materialization_status", "")) != "0x4a93a2_direct_town_record_random_tie_and_bit22_body_marking_ported_inspection_only":
		_fail("0x4a93a2 direct town record stamping status drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("object_record_stamped_count", -1)) != 3 or int(town_castle_placement.get("object_occupied_cell_mark_count", -1)) != 39 or int(town_castle_placement.get("object_record_random_tie_pending_count", -1)) != 0:
		_fail("0x4a93a2 direct town record stamping counts drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("object_record_random_tie_selection_count", -1)) != 1 or int(town_castle_placement.get("object_record_random_tie_rng_call_count", -1)) != 1:
		_fail("0x4a93a2 random tie selection counts drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(town_castle_placement.get("project_town_writeout_status", "")) != "0x4a93a2_object_record_writeout_ledger_ported_project_adoption_pending":
		_fail("0x4a93a2 project town writeout ledger status drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("project_town_writeout_record_count", -1)) != 3 or int(town_castle_placement.get("project_town_writeout_record_size_bytes", -1)) != 0x28:
		_fail("0x4a93a2 project town writeout record count/size drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("project_town_writeout_generator_f44_start", -1)) != 0 or int(town_castle_placement.get("project_town_writeout_generator_f44_next", -1)) != 3:
		_fail("0x4a93a2 generator+0xf44 town serial ledger drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(town_castle_placement.get("project_town_writeout_constructor_address", "")) != "0x49ba89" or String(town_castle_placement.get("project_town_writeout_town_vtable_address", "")) != "0x540a9c":
		_fail("0x4a93a2 project town writeout constructor/vtable addresses drifted: %s" % JSON.stringify(town_castle_placement))
		return
	var minimum_calls: Array = town_castle_placement.get("minimum_calls", [])
	if minimum_calls.size() != 4 or int(minimum_calls[0].get("runtime_zone_index", -1)) != 0 or int(minimum_calls[0].get("owner_color", -1)) != 0 or not bool(minimum_calls[0].get("castle", false)):
		_fail("0x4a8d2c first direct minimum castle call did not preserve runtime owner semantics: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("direct_candidate_scan_status", "")) != "0x4a93a2_owner_byte_candidate_scan_ported_eligibility_pending" or int(minimum_calls[0].get("candidate_count", -1)) <= 0 or int(minimum_calls[0].get("closest_distance", -1)) < 0:
		_fail("0x4a93a2 first direct minimum castle call did not expose owner-byte closest-cell candidates: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("direct_validity_precheck_status", "")) != "0x49a1d8_validity_precheck_ported_full_0x49aa93_collision_pending" or int(minimum_calls[0].get("validity_precheck_eligible_count", -1)) != int(minimum_calls[0].get("candidate_count", -2)):
		_fail("0x49a1d8 first direct minimum castle precheck did not preserve valid free-cell candidates: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("direct_full_eligibility_status", "")) != "0x49aa93_0x49a09c_town_footprint_pass_ported_project_writeout_pending":
		_fail("0x49aa93 first direct minimum castle full gate sequence drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(town_castle_placement.get("town_footprint_49a09c_status", "")) != "0x49a09c_town_footprint_pass_ported_for_current_generated_cell_grid":
		_fail("0x49a09c Town footprint pass status drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("town_footprint_49a09c_pass_total", -1)) != 97 or int(town_castle_placement.get("town_footprint_49a09c_rejected_bounds_count", -1)) != 135 or int(town_castle_placement.get("town_footprint_49a09c_rejected_bit22_count", -1)) != 1:
		_fail("0x49a09c Town footprint pass/bounds/bit22 counts drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(town_castle_placement.get("town_footprint_49a09c_rejected_bit25_count", -1)) != 22 or int(town_castle_placement.get("town_footprint_49a09c_rejected_owner_count", -1)) != 196 or int(town_castle_placement.get("town_footprint_49a09c_rejected_terrain9_count", -1)) != 0 or int(town_castle_placement.get("town_footprint_49a09c_rejected_water_class_count", -1)) != 0:
		_fail("0x49a09c Town footprint terrain/owner/water rejection counts drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("town_footprint_49a09c_status", "")) != "0x49a09c_town_body_offsets_bit22_bit25_water_owner_pass_ported":
		_fail("0x49a09c first direct minimum castle footprint gate status drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("town_footprint_mask_status", "")) != "0x49a6f9_town_text_mask_body_scan_ported_object_collision_pending" or int(minimum_calls[0].get("town_footprint_mask_eligible_count", -1)) != 42 or int(minimum_calls[0].get("closest_town_footprint_mask_distance", -1)) != 5:
		_fail("0x49a6f9 first direct minimum castle Town mask body scan drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("selected_candidate_status", "")) != "0x4a93a2_unique_town_candidate_selected_and_bit22_body_cells_marked_inspection_only" or int(minimum_calls[0].get("selected_candidate_x", -1)) != 28 or int(minimum_calls[0].get("selected_candidate_y", -1)) != 14 or int(minimum_calls[0].get("object_occupied_cell_mark_count", -1)) != 13:
		_fail("0x4a93a2 first direct minimum castle unique candidate stamping drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("project_town_writeout_status", "")) != "0x4a93a2_object_record_writeout_ledger_ported_project_adoption_pending" or int(minimum_calls[0].get("h3maped_object_record_size_bytes", -1)) != 0x28 or int(minimum_calls[0].get("h3maped_generator_f44_serial_before_increment", -1)) != 0:
		_fail("0x4a93a2 first direct minimum castle object record writeout ledger drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[0].get("h3maped_object_record_constructor_address", "")) != "0x49ba89" or String(minimum_calls[0].get("h3maped_town_object_record_vtable_address", "")) != "0x540a9c":
		_fail("0x4a93a2 first direct minimum castle object record constructor/vtable drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(minimum_calls[0].get("h3maped_record_offset_0x1c_generator_object_index", -1)) != 0 or int(minimum_calls[0].get("h3maped_record_offset_0x20_owner_color", -1)) != 0 or not bool(minimum_calls[0].get("h3maped_record_offset_0x24_castle_flag", false)):
		_fail("0x4a93a2 first direct minimum castle object record field offsets drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[2].get("selected_candidate_status", "")) != "0x4a93a2_random_tie_town_candidate_selected_and_bit22_body_cells_marked_inspection_only" or int(minimum_calls[2].get("closest_town_footprint_mask_candidate_count", -1)) != 3:
		_fail("0x4a93a2 third direct minimum castle should select through the recovered random tie: %s" % JSON.stringify(town_castle_placement))
		return
	if int(minimum_calls[2].get("random_tie_rng_value", -1)) != 12382 or int(minimum_calls[2].get("random_tie_selected_index", -1)) != 1 or int(minimum_calls[2].get("selected_candidate_x", -1)) != 18 or int(minimum_calls[2].get("selected_candidate_y", -1)) != 5 or int(minimum_calls[2].get("object_occupied_cell_mark_count", -1)) != 13:
		_fail("0x4a93a2 third direct minimum castle random tie result drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if int(minimum_calls[2].get("h3maped_generator_f44_serial_before_increment", -1)) != 2 or int(minimum_calls[2].get("h3maped_record_offset_0x1c_generator_object_index", -1)) != 2:
		_fail("0x4a93a2 third direct minimum castle random-tie object serial drifted: %s" % JSON.stringify(town_castle_placement))
		return
	if String(minimum_calls[3].get("direct_candidate_scan_status", "")) != "0x4a93a2_immediate_fail_owner_minus_one" or int(minimum_calls[3].get("owner_color", 0)) != -1:
		_fail("0x4a93a2 fourth direct minimum castle call should expose the recovered owner-minus-one early-fail boundary for the unassigned player slot: %s" % JSON.stringify(town_castle_placement))
		return
	var mine_reward_placement: Dictionary = selected_payload.get("guard_reward_monster_placement", {})
	if int(mine_reward_placement.get("source_zone_missing_count", -1)) != 0 or int(mine_reward_placement.get("zone_count", -1)) != 6:
		_fail("0x4a9d6a/0x4aab7e recovered source-row binding missed selected template zones: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_minimum_field_count", -1)) != 42 or int(mine_reward_placement.get("mine_density_field_count", -1)) != 42:
		_fail("0x4a9d6a mine field ledger did not expose seven resources per active zone: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("positive_mine_minimum_field_count", -1)) != 18 or int(mine_reward_placement.get("positive_mine_density_field_count", -1)) != 18:
		_fail("0x4a9d6a positive mine minimum/density fields drifted from recovered source rows: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("total_minimum_mine_count", -1)) != 18 or int(mine_reward_placement.get("total_mine_density_weight", -1)) != 18:
		_fail("0x4a9d6a total mine minimum count/density weight drifted from recovered source rows: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(mine_reward_placement.get("mine_guard_scaling_status", "")) != "0x4a960a_0x4a65a5_mine_guard_values_scaled_guard_objects_pending" \
			or int(mine_reward_placement.get("mine_guard_global_strength_mode", -1)) != 3 \
			or int(mine_reward_placement.get("mine_guard_scaled_nonzero_count", -1)) != 10 \
			or int(mine_reward_placement.get("mine_guard_scaled_value_total", -1)) != 59500:
		_fail("0x4a960a/0x4a65a5 mine guard value scaling drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_template_row_count", -1)) != 46 or int(mine_reward_placement.get("adjacent_resource_template_row_count", -1)) != 7:
		_fail("0x4a9911/0x4a9e40 object template bucket row counts drifted from recovered objects.txt: %s" % JSON.stringify(mine_reward_placement))
		return
	var mine_template_counts: Dictionary = mine_reward_placement.get("mine_template_counts_by_subtype", {})
	if int(mine_template_counts.get("0", -1)) != 6 or int(mine_template_counts.get("2", -1)) != 8 or int(mine_template_counts.get("4", -1)) != 9 or int(mine_template_counts.get("6", -1)) != 9:
		_fail("0x4a9911 mine template subtype counts drifted from objects.txt type 53: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_minimum_helper_call_count", -1)) != 18 or int(mine_reward_placement.get("mine_minimum_helper_candidate_template_total", -1)) != 116:
		_fail("0x4a9911 mine minimum helper call/candidate ledger drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_minimum_helper_terrain_filtered_candidate_template_total", -1)) <= 0:
		_fail("0x42cc99 terrain-filtered mine template candidates were not exposed from objects.txt masks: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(mine_reward_placement.get("mine_placement_constraint_status", "")) != "0x4a9641_constraint_scan_executed_inspection_package_adoption_pending":
		_fail("0x4a9641 mine placement constraint scan was not exposed as executed inspection state: %s" % JSON.stringify(mine_reward_placement))
		return
	var mine_constraint: Dictionary = mine_reward_placement.get("mine_placement_constraint", {})
	if String(mine_constraint.get("address", "")) != "0x4a9641" or String(mine_constraint.get("candidate_validity_helper_address", "")) != "0x49aa93" or String(mine_constraint.get("virtual_placement_hook", "")) != "generator_vtable+0x04":
		_fail("0x4a9641 helper addresses drifted from recovered executable evidence: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_constraint.get("neighbor_count_cap", -1)) != 5 or int(mine_constraint.get("special_distance_min_squared", -1)) != 0x10 or int(mine_constraint.get("special_distance_floor_squared", -1)) != 0x90:
		_fail("0x4a9641 neighbor/distance ranking constants drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_placement_constraint_scan_call_count", -1)) <= 0 or int(mine_reward_placement.get("mine_template_selection_rng_call_count", -1)) <= 0:
		_fail("0x4a9911/0x4a9641 mine scan call or template RNG counts drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("mine_placement_constraint_candidate_total", -1)) <= 0 or int(mine_reward_placement.get("mine_placement_constraint_selected_count", -1)) <= 0 or int(mine_reward_placement.get("mine_object_occupied_cell_mark_count", -1)) <= 0:
		_fail("0x4a9641 mine candidate scan did not produce selected occupied body cells: %s" % JSON.stringify(mine_reward_placement))
		return
	var helper_calls: Array = mine_reward_placement.get("mine_minimum_helper_calls", [])
	if helper_calls.size() != 18 or String(helper_calls[0].get("status", "")) != "0x4a9911_template_bucket_record_guard_handoff_and_0x4a9641_scan_ported_package_adoption_pending":
		_fail("0x4a9911 helper calls did not expose the recovered template/record/guard handoff: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(helper_calls[0].get("resource", "")) != "wood" or int(helper_calls[0].get("matched_template_candidate_count_before_terrain_filter", -1)) != 6 or int(helper_calls[0].get("matched_template_candidate_count_after_terrain_filter", -1)) <= 0 or int(helper_calls[0].get("object_record_size_bytes", -1)) != 0x1c:
		_fail("0x4a9911 first helper call did not preserve wood mine template/record semantics: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(helper_calls[0].get("object_record_constructor_address", "")) != "0x49ba89" or String(helper_calls[0].get("object_record_vtable_address", "")) != "0x540ab0" or String(helper_calls[0].get("placement_constraint_helper_address", "")) != "0x4a9641":
		_fail("0x4a9911 first helper call constructor/vtable/placement helper drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if not String(helper_calls[0].get("placement_constraint_status", "")).begins_with("0x4a9641_candidate_scan_executed") or int(helper_calls[0].get("placement_constraint_neighbor_count_cap", -1)) != 5 or String(helper_calls[0].get("placement_constraint_virtual_hook", "")) != "generator_vtable+0x04":
		_fail("0x4a9911 first helper call did not carry the recovered 0x4a9641 constraint boundary: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(helper_calls[0].get("selected_template_def_name", "")) == "":
		_fail("0x4a9911 first helper call did not select a terrain-filtered mine template wrapper: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(helper_calls[0].get("guard_base_value", -1)) != 1500 or String(helper_calls[0].get("adjacent_resource_helper_address", "")) != "0x4a9e40" or int(helper_calls[0].get("adjacent_resource_object_type_id", -1)) != 79:
		_fail("0x4a9911 first helper call guard/adjacent resource handoff drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(helper_calls[0].get("guard_scaling_status", "")) != "0x4a960a_0x4a65a5_guard_value_scaled_guard_object_pending" \
			or int(helper_calls[0].get("guard_source_strength_mode", -1)) != 3 \
			or int(helper_calls[0].get("guard_effective_strength_mode", -1)) != 3 \
			or int(helper_calls[0].get("guard_scaled_value", -1)) != 0:
		_fail("0x4a960a/0x4a65a5 first mine guard scaling drifted: %s" % JSON.stringify(helper_calls[0]))
		return
	if int(mine_reward_placement.get("treasure_band_field_count", -1)) != 18 or int(mine_reward_placement.get("positive_treasure_band_count", -1)) != 18:
		_fail("0x4aab7e treasure band field ledger did not expose three eligible bands per active zone: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("total_treasure_density_weight", -1)) != 96 or int(mine_reward_placement.get("treasure_low_below_100_count", -1)) != 0:
		_fail("0x4aab7e treasure density/low-value eligibility drifted from recovered source rows: %s" % JSON.stringify(mine_reward_placement))
		return
	var mine_minimum_fields: Array = mine_reward_placement.get("mine_minimum_fields", [])
	if mine_minimum_fields.size() != 42 or String(mine_minimum_fields[0].get("resource", "")) != "wood" or String(mine_minimum_fields[0].get("source_field_offset", "")) != "+0x4c" or int(mine_minimum_fields[0].get("count", -1)) != 1:
		_fail("0x4a9d6a first mine minimum field drifted from source +0x4c wood semantics: %s" % JSON.stringify(mine_reward_placement))
		return
	var treasure_band_fields: Array = mine_reward_placement.get("treasure_band_fields", [])
	if treasure_band_fields.size() != 18 or int(treasure_band_fields[0].get("low", -1)) != 10000 or int(treasure_band_fields[0].get("high", -1)) != 15000 or int(treasure_band_fields[0].get("density", -1)) != 1:
		_fail("0x4aab7e first treasure band drifted from recovered low/high/density triplet: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(mine_reward_placement.get("treasure_scheduler_status", "")) != "0x4aab7e_treasure_scheduler_math_materialized_reward_objects_pending":
		_fail("0x4aab7e treasure scheduler status did not expose the recovered scheduler math boundary: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("treasure_scheduler_zone_count", -1)) != 6 or int(mine_reward_placement.get("treasure_scheduler_active_zone_count", -1)) != 6 or int(mine_reward_placement.get("treasure_scheduler_scaled_step_total", -1)) != 42:
		_fail("0x4aab7e treasure scheduler zone/step totals drifted from recovered seed-1 math: %s" % JSON.stringify(mine_reward_placement))
		return
	var treasure_scheduler_zones: Array = mine_reward_placement.get("treasure_scheduler_zones", [])
	if treasure_scheduler_zones.size() != 6:
		_fail("0x4aab7e treasure scheduler did not expose one scheduler record per runtime zone: %s" % JSON.stringify(mine_reward_placement))
		return
	var first_scheduler: Dictionary = treasure_scheduler_zones[0]
	if int(first_scheduler.get("eligible_band_count", -1)) != 3 or int(first_scheduler.get("total_density_weight", -1)) != 16 or int(first_scheduler.get("density_product", -1)) != 54:
		_fail("0x4aab7e first scheduler density math drifted: %s" % JSON.stringify(first_scheduler))
		return
	if int(first_scheduler.get("scale_dividend", -1)) != 0x320 or int(first_scheduler.get("scale_density_divisor", -1)) != 50 or int(first_scheduler.get("scaled_step_after_sqrt_trunc", -1)) != 7:
		_fail("0x4aab7e first scheduler sqrt/trunc scale math drifted: %s" % JSON.stringify(first_scheduler))
		return
	if first_scheduler.get("math_helper_addresses", []) != ["0x4e7d44_sqrt", "0x4e7dec_fistp_trunc"] or String(first_scheduler.get("reward_attempt_helper_address", "")) != "0x4aa354" or String(first_scheduler.get("post_reward_guard_helper_address", "")) != "0x4aa9b7":
		_fail("0x4aab7e scheduler helper addresses drifted from recovered executable evidence: %s" % JSON.stringify(first_scheduler))
		return
	var first_accumulators: Array = first_scheduler.get("accumulator_records", [])
	if first_accumulators.size() != 3 or int(first_accumulators[0].get("step_weight", -1)) != 54 or int(first_accumulators[1].get("step_weight", -1)) != 9 or int(first_accumulators[2].get("step_weight", -1)) != 6:
		_fail("0x4aab7e first scheduler accumulator weights drifted from product/density math: %s" % JSON.stringify(first_scheduler))
		return
	if bool(first_scheduler.get("materializes_reward_objects", true)):
		_fail("0x4aab7e scheduler math boundary must not claim reward object materialization yet: %s" % JSON.stringify(first_scheduler))
		return
	if String(mine_reward_placement.get("treasure_reward_attempt_status", "")) != "0x4aa354_reward_value_selection_materialized_object_lookup_pending":
		_fail("0x4aa354 reward attempt status did not expose the recovered value-selection boundary: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("treasure_reward_attempt_count", -1)) != 42 or int(mine_reward_placement.get("treasure_reward_value_rng_call_count", -1)) != 42:
		_fail("0x4aa354 reward attempt/RNG counts drifted from the seed-1 scheduler steps: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("treasure_reward_rng_state_before_0x4aa354_uint32", -1)) != 2990262233 or int(mine_reward_placement.get("treasure_reward_rng_state_after_0x4aa354_uint32", -1)) != 2283988067:
		_fail("0x4aa354 reward value RNG state drifted from recovered 0x4e7276 replay: %s" % JSON.stringify(mine_reward_placement))
		return
	var reward_attempts: Array = mine_reward_placement.get("treasure_reward_attempt_records", [])
	if reward_attempts.size() != 42:
		_fail("0x4aa354 reward attempt records did not cover all scheduler attempts: %s" % JSON.stringify(mine_reward_placement))
		return
	var first_attempt: Dictionary = reward_attempts[0]
	if int(first_attempt.get("selected_band_index", -1)) != 0 or int(first_attempt.get("value_rng_value", -1)) != 8723 or int(first_attempt.get("selected_reward_value", -1)) != 13723:
		_fail("0x4aa354 first reward value selection drifted from low + rng %% (high-low): %s" % JSON.stringify(first_attempt))
		return
	if String(first_attempt.get("pre_attempt_helper_address", "")) != "0x49ce64" or String(first_attempt.get("object_lookup_helper_address", "")) != "0x4aa1db" or String(first_attempt.get("guard_value_helper_address", "")) != "0x4a960a" or String(first_attempt.get("post_object_helper_address", "")) != "0x4a5c07":
		_fail("0x4aa354 first reward helper handoff addresses drifted: %s" % JSON.stringify(first_attempt))
		return
	var first_zone_band_order: Array = []
	for reward_attempt_index in range(7):
		first_zone_band_order.append(int(Dictionary(reward_attempts[reward_attempt_index]).get("selected_band_index", -1)))
	if first_zone_band_order != [0, 1, 2, 2, 1, 2, 1]:
		_fail("0x4aac70/0x4aa354 first-zone scheduler band order drifted: %s" % JSON.stringify(first_zone_band_order))
		return
	if bool(first_attempt.get("materializes_reward_object", true)):
		_fail("0x4aa354 value-selection boundary must not claim reward object materialization before 0x4aa1db is ported: %s" % JSON.stringify(first_attempt))
		return
	if String(mine_reward_placement.get("treasure_reward_object_lookup_status", "")) != "0x4aa1db_lookup_control_flow_with_materialized_candidate_scan_dynamic_value_sites_pending":
		_fail("0x4aa1db reward object lookup control flow was not exposed as the next pending boundary: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("treasure_reward_object_lookup_count", -1)) != 42 or int(mine_reward_placement.get("treasure_reward_object_lookup_primary_retry_budget_total", -1)) != 126 or bool(mine_reward_placement.get("treasure_reward_object_lookup_candidate_execution_materialized", true)):
		_fail("0x4aa1db reward object lookup counts/materialization flags drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if String(mine_reward_placement.get("treasure_reward_candidate_scan_status", "")) != "0x4a9f1c_materialized_candidate_scan_dynamic_value_sites_pending" or int(mine_reward_placement.get("treasure_reward_proxy_inventory_reward_reference_count", -1)) != 14:
		_fail("0x4a9f1c candidate scan status/proxy inventory drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	if int(mine_reward_placement.get("treasure_reward_candidate_scan_count", -1)) != 42 or int(mine_reward_placement.get("treasure_reward_candidate_vector_materialized_record_count", -1)) != 123:
		_fail("0x4a9f1c recovered materialized candidate-vector scan count drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	var vector_construction: Dictionary = mine_reward_placement.get("treasure_reward_candidate_vector_static_construction_summary", {})
	if int(vector_construction.get("static_insert_site_count", -1)) != 126 or int(vector_construction.get("static_insert_helper_42d8d8_count", -1)) != 27 or int(vector_construction.get("static_insert_helper_40bb26_count", -1)) != 99:
		_fail("0x49f95a reward vector construction-site summary drifted: %s" % JSON.stringify(vector_construction))
		return
	if int(vector_construction.get("current_direct_field_materialized_record_count", -1)) != 98 or int(vector_construction.get("current_literal_constructor_materialized_record_count", -1)) != 25 or int(vector_construction.get("current_materialized_record_count", -1)) != 123 or int(vector_construction.get("uncovered_static_insert_site_count", -1)) != 3:
		_fail("0x49f95a materialized vector coverage gap drifted: %s" % JSON.stringify(vector_construction))
		return
	if int(vector_construction.get("dynamic_constructor_site_pending_count", -1)) != 3:
		_fail("0x49f95a dynamic constructor site gap drifted: %s" % JSON.stringify(vector_construction))
		return
	if String(vector_construction.get("dynamic_value_function_recovery_status", "")) != "0x49c64b_0x49c849_0x49ca8b_formulas_ported_runtime_tables_pending":
		_fail("0x49f95a dynamic value-function formula recovery drifted: %s" % JSON.stringify(vector_construction))
		return
	var dynamic_values: Dictionary = mine_reward_placement.get("treasure_reward_dynamic_value_function_summary", {})
	if String(dynamic_values.get("status", "")) != "0x49c64b_0x49c849_0x49ca8b_dynamic_value_formulas_ported_runtime_tables_pending" or int(dynamic_values.get("ported_formula_count", -1)) != 3:
		_fail("0x49f95a dynamic value-function summary drifted: %s" % JSON.stringify(dynamic_values))
		return
	if int(dynamic_values.get("0x49fa2a_creature_loop_limit", -1)) != 0x76 or int(dynamic_values.get("0x4a043a_type17_loop_limit", -1)) != 0x3a or int(dynamic_values.get("0x4a0f54_inner_creature_loop_limit", -1)) != 0x76:
		_fail("0x49f95a one-level dynamic loop limits drifted: %s" % JSON.stringify(dynamic_values))
		return
	if String(dynamic_values.get("creature_table_loader_address", "")) != "0x40ce11" or int(dynamic_values.get("creature_table_loader_stride_bytes", -1)) != 0x74:
		_fail("0x49f95a dynamic creature table loader evidence drifted: %s" % JSON.stringify(dynamic_values))
		return
	if String(dynamic_values.get("creature_table_loader_static_storage_base_address", "")) != "0x57cea0" or String(dynamic_values.get("creature_table_loader_numeric_copy_dest_range", "")) != "creature_row+0x20..+0x70":
		_fail("0x49f95a dynamic creature table storage/copy evidence drifted: %s" % JSON.stringify(dynamic_values))
		return
	var dynamic_functions: Array = dynamic_values.get("functions", [])
	if dynamic_functions.size() != 3 or String(Dictionary(dynamic_functions[0]).get("address", "")) != "0x49c64b" or String(Dictionary(dynamic_functions[1]).get("address", "")) != "0x49c849" or String(Dictionary(dynamic_functions[2]).get("address", "")) != "0x49ca8b":
		_fail("0x49f95a dynamic value-function addresses drifted: %s" % JSON.stringify(dynamic_values))
		return
	var dynamic_skeletons: Array = dynamic_values.get("dynamic_record_skeletons", [])
	if dynamic_skeletons.size() != 3:
		_fail("0x49f95a dynamic record skeleton count drifted: %s" % JSON.stringify(dynamic_values))
		return
	if int(dynamic_values.get("known_unconditional_dynamic_record_count", -1)) != 0x3a or int(dynamic_values.get("scan_ready_dynamic_record_count", -1)) != 0:
		_fail("0x49f95a dynamic skeleton record-count gates drifted: %s" % JSON.stringify(dynamic_values))
		return
	if String(Dictionary(dynamic_skeletons[1]).get("constructor_call_address", "")) != "0x4a043a" or int(Dictionary(dynamic_skeletons[1]).get("known_unconditional_record_count", -1)) != 0x3a:
		_fail("0x49f95a type-17 dynamic skeleton loop drifted: %s" % JSON.stringify(dynamic_values))
		return
	if String(Dictionary(dynamic_skeletons[0]).get("record_count_status", "")) != "runtime_creature_table_pending" or String(Dictionary(dynamic_skeletons[2]).get("record_count_status", "")) != "generator_vector_and_runtime_creature_table_pending":
		_fail("0x49f95a dynamic creature-loop skeleton gates drifted: %s" % JSON.stringify(dynamic_values))
		return
	if int(mine_reward_placement.get("treasure_reward_candidate_scan_eligible_total", -1)) != 463 or int(mine_reward_placement.get("treasure_reward_candidate_scan_weight_total", -1)) != 95948:
		_fail("0x4a9f1c recovered materialized candidate scan totals drifted: %s" % JSON.stringify(mine_reward_placement))
		return
	var first_lookup: Dictionary = first_attempt.get("object_lookup_control_flow", {})
	if String(first_lookup.get("function_address", "")) != "0x4aa1db" or String(first_lookup.get("candidate_scan_helper_address", "")) != "0x4a9f1c":
		_fail("0x4aa1db first lookup helper addresses drifted: %s" % JSON.stringify(first_lookup))
		return
	if int(first_lookup.get("primary_probe_retry_budget", -1)) != 3 or int(first_lookup.get("primary_min_value", -1)) != 3430 or int(first_lookup.get("primary_max_value", -1)) != 13723:
		_fail("0x4aa1db first lookup primary value range/retry drifted: %s" % JSON.stringify(first_lookup))
		return
	if int(first_lookup.get("remaining_value_threshold", -1)) != 0x5dc or String(first_lookup.get("secondary_min_formula", "")) != "remaining_value / 4" or String(first_lookup.get("secondary_max_formula", "")) != "(remaining_value * 5) / 4":
		_fail("0x4aa1db remaining-value split constants drifted: %s" % JSON.stringify(first_lookup))
		return
	if String(first_lookup.get("secondary_validation_helper_address", "")) != "0x49d471" or String(first_lookup.get("placement_coordinate_helper_address", "")) != "0x49abd6" or String(first_lookup.get("cleanup_helper_address", "")) != "0x49d6e0":
		_fail("0x4aa1db validation/placement/cleanup helper addresses drifted: %s" % JSON.stringify(first_lookup))
		return
	if first_lookup.get("coordinate_sentinel", []) != [-1, -1, -1] or bool(first_lookup.get("materializes_reward_object", true)):
		_fail("0x4aa1db lookup must preserve sentinel coordinates and remain non-materializing: %s" % JSON.stringify(first_lookup))
		return
	var first_candidate_scan: Dictionary = first_lookup.get("candidate_scan_control_flow", {})
	if String(first_candidate_scan.get("function_address", "")) != "0x4a9f1c" or String(first_candidate_scan.get("generator_candidate_vector_begin_offset", "")) != "generator+0x10f4" or String(first_candidate_scan.get("generator_candidate_vector_end_offset", "")) != "generator+0x10f8":
		_fail("0x4a9f1c candidate vector offsets drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if String(first_candidate_scan.get("type_metadata_table_pointer_address", "")) != "0x57c648" or int(first_candidate_scan.get("type_metadata_stride_bytes", -1)) != 0x10:
		_fail("0x4a9f1c object metadata table evidence drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if String(first_candidate_scan.get("global_type_count_table_address", "")) != "0x5a26e4" or String(first_candidate_scan.get("zone_type_count_table_address", "")) != "0x5a2a8c":
		_fail("0x4a9f1c type-count cap table evidence drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if int(first_candidate_scan.get("value_range_min", -1)) != 3430 or int(first_candidate_scan.get("value_range_max", -1)) != 13723:
		_fail("0x4a9f1c first candidate value range drifted from 0x4aa1db primary range: %s" % JSON.stringify(first_candidate_scan))
		return
	if String(first_candidate_scan.get("candidate_vector_constructor_address", "")) != "0x49f95a" or int(first_candidate_scan.get("candidate_vector_record_count", -1)) != 123 or bool(first_candidate_scan.get("complete_generator_candidate_vector_materialized", true)):
		_fail("0x4a9f1c recovered materialized vector scope drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if int(first_candidate_scan.get("candidate_vector_static_insert_site_count", -1)) != 126 or int(first_candidate_scan.get("candidate_vector_uncovered_static_site_count", -1)) != 3:
		_fail("0x4a9f1c candidate scan lost the 0x49f95a full-vector construction gap: %s" % JSON.stringify(first_candidate_scan))
		return
	if int(first_candidate_scan.get("eligible_candidate_count", -1)) != 12 or int(first_candidate_scan.get("eligible_candidate_weight_total", -1)) != 418:
		_fail("0x4a9f1c first materialized candidate eligibility drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if String(first_candidate_scan.get("resource_helper_address", "")) != "0x4a9e40" or String(first_candidate_scan.get("footprint_probe_helper_address", "")) != "0x49a6f9" or String(first_candidate_scan.get("optional_coverage_ratio_helper_address", "")) != "0x4aa195" or String(first_candidate_scan.get("weighted_selection_rng_address", "")) != "0x4e7276":
		_fail("0x4a9f1c helper address evidence drifted: %s" % JSON.stringify(first_candidate_scan))
		return
	if int(first_candidate_scan.get("native_proxy_inventory_reward_reference_count", -1)) != 14 or !bool(first_candidate_scan.get("native_proxy_candidate_scan_materialized", false)) or bool(first_candidate_scan.get("native_proxy_weighted_selection_materialized", true)) or bool(first_candidate_scan.get("native_proxy_candidate_execution_materialized", true)):
		_fail("0x4a9f1c native proxy inventory must be visible but non-materializing: %s" % JSON.stringify(first_candidate_scan))
		return
	var first_eligible_preview: Array = first_candidate_scan.get("eligible_candidate_preview", [])
	if first_eligible_preview.size() < 12:
		_fail("0x4a9f1c first eligible candidate preview is too small: %s" % JSON.stringify(first_candidate_scan))
		return
	var first_preview_candidate: Dictionary = first_eligible_preview[0]
	if int(first_preview_candidate.get("type_id", -1)) != 6 or int(first_preview_candidate.get("value", -1)) != 6000 or int(first_preview_candidate.get("weight", -1)) != 20:
		_fail("0x4a9f1c first eligible candidate no longer matches the recovered Pandora Box record: %s" % JSON.stringify(first_candidate_scan))
		return
	var artifact_preview_candidate: Dictionary = first_eligible_preview[8]
	if int(artifact_preview_candidate.get("type_id", -1)) != 67:
		_fail("0x4a9f1c eligible preview lost the recovered Random Minor Artifact candidate: %s" % JSON.stringify(first_candidate_scan))
		return
	var spell_scroll_preview_candidate: Dictionary = first_eligible_preview[10]
	if int(spell_scroll_preview_candidate.get("type_id", -1)) != 93:
		_fail("0x4a9f1c eligible preview lost the recovered literal-constructor Spell Scroll candidate: %s" % JSON.stringify(first_candidate_scan))
		return
	if selected_payload.get("human_capable_source_owner_indices", []) != [0, 1, 2, 3]:
		_fail("The selected h3maped source template payload lost human-capable owner slots: %s" % JSON.stringify(report))
		return
	if selected_payload.get("player_capable_source_owner_indices", []) != [0, 1, 2, 3]:
		_fail("The selected h3maped source template payload lost player-capable owner slots: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("assignment_status", "")) != "0x4ac62a_player_slot_assignment_ported_inspection_only":
		_fail("The clean boundary did not port h3maped player-slot assignment: %s" % JSON.stringify(report))
		return
	var assignment: Dictionary = selected_payload.get("player_slot_assignment", {})
	if assignment.get("selected_color_bitmap", []) != [false, false, false, false, false, false, false, false]:
		_fail("Default selected-color bitmap must preserve constructor-zeroed generator+0xed8 state: %s" % JSON.stringify(report))
		return
	if assignment.get("selected_color_order", []) != [0, 1, 2, 3, 4, 5, 6, 7]:
		_fail("Default h3maped selected-color order drifted from 0x4ac62a..0x4ac6ec: %s" % JSON.stringify(report))
		return
	if assignment.get("actual_colors_by_source_owner", []) != [0, 1, 2, -1, -1, -1, -1, -1]:
		_fail("Default h3maped player assignment wrote the wrong mapped owner colors: %s" % JSON.stringify(report))
		return
	if int(assignment.get("assigned_player_count", -1)) != 3:
		_fail("The player-slot assignment did not assign all requested players: %s" % JSON.stringify(report))
		return

	if String(selected_payload.get("runtime_zone_build_status", "")) != "0x4a218c_runtime_zone_records_and_49b53d_terrain_ported_inspection_only":
		_fail("The clean boundary did not port the h3maped runtime-zone record build: %s" % JSON.stringify(report))
		return
	var runtime_build: Dictionary = selected_payload.get("runtime_zone_build", {})
	if int(runtime_build.get("runtime_zone_count", -1)) != 6 or int(runtime_build.get("link_seed_count", -1)) != 5:
		_fail("The h3maped runtime-zone build lost zone/link records: %s" % JSON.stringify(report))
		return
	if int(runtime_build.get("min_source_base_size", -1)) != 11 or int(runtime_build.get("scale_divisor", -1)) != 5 or int(runtime_build.get("initial_scale_reference", -1)) != 79:
		_fail("The h3maped runtime-zone build scale inputs drifted from 0x4a218c: %s" % JSON.stringify(report))
		return
	if String(runtime_build.get("coordinate_placement_status", "")) != "0x4a218c_interleaved_runtime_and_coordinate_replay_inspection_only":
		_fail("Runtime-zone coordinate candidate replay did not expose the clean h3maped status: %s" % JSON.stringify(report))
	var coordinate_seed: Dictionary = runtime_build.get("coordinate_seed", {})
	if String(coordinate_seed.get("rng_order_status", "")) != "0x4a218c_interleaved_replay_ported_inspection_only":
		_fail("Coordinate replay must expose the exact 0x4a218c runtime/coordinate RNG interleaving checkpoint: %s" % JSON.stringify(report))
	if int(coordinate_seed.get("placement_step_count", -1)) != 18 or int(coordinate_seed.get("coordinate_rng_calls_during_0x4a1f3b", -1)) != 18:
		_fail("Coordinate replay must expose one candidate-selection step for each 0x4a1f3b call: %s" % JSON.stringify(report))
	if int(coordinate_seed.get("town_rng_calls_during_0x49b452", -1)) != 4 or int(coordinate_seed.get("rng_event_count", -1)) != 22:
		_fail("Runtime-zone replay must expose interleaved town and coordinate RNG events from 0x4a218c: %s" % JSON.stringify(report))
	var bbox: Dictionary = coordinate_seed.get("bounding_box_rescale", {})
	if int(bbox.get("selected_span_before_rescale", -1)) != 84 or int(bbox.get("map_span", -1)) != 36:
		_fail("Coordinate replay bbox rescale drifted from the executable-derived 0x4a19ed path: %s" % JSON.stringify(report))
		return
	var runtime_zones: Array = runtime_build.get("runtime_zones", [])
	if runtime_zones.size() != 6:
		_fail("Runtime-zone report did not expose one record per active source zone: %s" % JSON.stringify(report))
		return
	var first_runtime_zone: Dictionary = runtime_zones[0]
	if int(first_runtime_zone.get("source_zone_id", -1)) != 1 or int(first_runtime_zone.get("actual_owner_color", -1)) != 0:
		_fail("Runtime-zone owner mapping did not preserve source zone +0x1c through generator +0xee4: %s" % JSON.stringify(report))
		return
	if int(first_runtime_zone.get("x_after_bbox_rescale", -1)) != 23 or int(first_runtime_zone.get("y_after_bbox_rescale", -1)) != 11:
		_fail("Interleaved 0x4a218c coordinate replay changed the first runtime-zone center: %s" % JSON.stringify(report))
		return
	if int(first_runtime_zone.get("source_base_size", -1)) != 11 or int(first_runtime_zone.get("runtime_initial_size_before_rescale", -1)) != 11 or int(first_runtime_zone.get("runtime_byte_3c", -1)) != 0:
		_fail("Runtime-zone initializer fields drifted from 0x49b452: %s" % JSON.stringify(report))
		return
	if int(runtime_zones[3].get("x_after_bbox_rescale", -1)) != 18 or int(runtime_zones[3].get("y_after_bbox_rescale", -1)) != 4:
		_fail("Interleaved 0x4a218c coordinate replay changed the fourth runtime-zone center: %s" % JSON.stringify(report))
		return
	if String(runtime_build.get("terrain_selection_status", "")) != "0x49b53d_runtime_terrain_selector_ported_inspection_only":
		_fail("Runtime-zone report did not expose the h3maped 0x49b53d terrain selector: %s" % JSON.stringify(report))
		return
	var terrain_selection: Dictionary = runtime_build.get("terrain_selection", {})
	if int(terrain_selection.get("selection_count", -1)) != 6 or int(terrain_selection.get("match_to_town_count", -1)) != 4 or int(terrain_selection.get("allowed_flag_choice_count", -1)) != 2:
		_fail("0x49b53d terrain selection did not cover match-to-town and allowed-flag zones: %s" % JSON.stringify(report))
		return
	if int(terrain_selection.get("rng_call_count", -1)) != 2:
		_fail("0x49b53d should consume terrain RNG only for the two treasure zones in this template: %s" % JSON.stringify(report))
		return
	if int(terrain_selection.get("rng_state_after_0x49b53d_uint32", -1)) != 2166683160:
		_fail("0x49b53d terrain selection did not preserve the recovered post-terrain RNG state: %s" % JSON.stringify(report))
		return
	if terrain_selection.get("town_choice_to_terrain_table", []) != [2, 2, 3, 7, 0, 0, 5, 4, 2]:
		_fail("0x49b53d town-choice terrain table drifted from executable data at 0x540908: %s" % JSON.stringify(report))
		return
	if String(runtime_zones[2].get("terrain_selection_status", "")) != "0x49b53d_ported":
		_fail("Runtime-zone report did not write the 0x49b53d terrain result into runtime+0x0c semantics: %s" % JSON.stringify(report))
		return
	if int(runtime_zones[2].get("h3maped_terrain_id", -1)) != 3 or String(runtime_zones[2].get("terrain_id", "")) != "snow":
		_fail("0x49b53d selected the wrong allowed-flag terrain for the first treasure zone: %s" % JSON.stringify(report))
		return
	if int(runtime_zones[5].get("h3maped_terrain_id", -1)) != 5 or String(runtime_zones[5].get("terrain_id", "")) != "rough":
		_fail("0x49b53d selected the wrong allowed-flag terrain for the second treasure zone: %s" % JSON.stringify(report))
		return
	if String(runtime_build.get("zone_footprint_placement_status", "")) != "0x4a3a03_0x4a3710_footprint_helpers_ported_terrain_visual_ready":
		_fail("The clean boundary did not expose the h3maped 0x4a3a03/0x4a3710 footprint helper checkpoint: %s" % JSON.stringify(report))
		return
	var footprint_phase: Dictionary = runtime_build.get("zone_footprint_placement", {})
	if int(footprint_phase.get("total_matching_runtime_zones", -1)) != 6 or int(footprint_phase.get("total_polygon_split_calls", -1)) != 6:
		_fail("0x4a3a03 must schedule one polygon split call per same-level runtime zone: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("appended_synthetic_runtime_zone_count", -1)) != 0:
		_fail("Small one-level land 0x4a3a03 must not append a synthetic fallback zone: %s" % JSON.stringify(report))
		return
	var footprint_levels: Array = footprint_phase.get("levels", [])
	if footprint_levels.size() != 1:
		_fail("Small one-level land 0x4a3a03 report must expose exactly one level: %s" % JSON.stringify(report))
		return
	var footprint_level_0: Dictionary = footprint_levels[0]
	if int(footprint_level_0.get("matching_runtime_zone_count", -1)) != 6 or bool(footprint_level_0.get("synthetic_fallback_zone_allowed_by_0x4a3a9d", true)):
		_fail("Small land 0x4a3a03 level collection or synthetic branch decision drifted: %s" % JSON.stringify(report))
		return
	if footprint_level_0.get("helper_call_sequence", []) != ["0x4a2777", "0x4a325d", "0x4a3710"]:
		_fail("0x4a3a03 helper sequence drifted from the executable phase order: %s" % JSON.stringify(report))
		return
	var polygon_seed: Dictionary = footprint_phase.get("polygon_seed_evidence", {})
	var polygon_bounds: Dictionary = polygon_seed.get("initial_bounds", {})
	if int(polygon_bounds.get("min_x", 0)) != -200 or int(polygon_bounds.get("max_x", 0)) != 400 or int(polygon_seed.get("initial_edge_count", 0)) != 4:
		_fail("0x4cc788 polygon seed bounds drifted from recovered h3maped constants: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("source_node_walk_status", "")) != "0x4cca55_to_0x4a2777_source_node_cycles_recovered":
		_fail("0x4cca55 source-node walks for 0x4a2777 were not recovered in the clean module: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("source_node_walk_count", -1)) != 6 or int(footprint_phase.get("source_node_walk_guard_exhausted_count", -1)) != 0:
		_fail("0x4cca55 source-node walks must cover each runtime zone without exhausting guards: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("finalizer_status", "")) != "0x4ccdfc_finalized_node_fanout_ported" or int(footprint_phase.get("finalized_node_count", 0)) <= 0:
		_fail("0x4ccdfc finalized polygon node fanout did not run before 0x4a2777: %s" % JSON.stringify(report))
		return
	var polygon_source_walks: Dictionary = footprint_phase.get("polygon_source_node_walks", {})
	if String(polygon_source_walks.get("status", "")) != "0x4ccb64_insertion_bridge_crossing_cleanup_and_source_walks_ported_for_0x4a2777":
		_fail("0x4ccb64 polygon source-walk model status drifted: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("boundary_traversal_status", "")) != "0x4a2777_real_source_node_cycle_traversal_ported_boundary_materialized":
		_fail("0x4a2777 real source-node boundary traversal was not materialized: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("boundary_runtime_zone_walk_count", -1)) <= 0 or int(footprint_phase.get("boundary_unique_cell_count", -1)) != 221:
		_fail("0x4a2777 boundary traversal did not produce zone walks and unique boundary cells: %s" % JSON.stringify(report))
		return
	if bool(footprint_phase.get("boundary_loop_guard_exhausted", true)):
		_fail("0x4a2777 boundary traversal exhausted its loop guard: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("span_fill_status", "")) != "0x4a325d_real_0x4a2777_boundary_span_fill_executed_terrain_schedule_ready":
		_fail("0x4a325d real boundary span fill was not executed: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("span_fill_filled_zone_count", -1)) <= 0 or int(footprint_phase.get("span_fill_unique_filled_cell_count", -1)) <= 0:
		_fail("0x4a325d span fill did not fill any runtime zones or cells: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("span_fill_unique_filled_cell_count", -1)) != 890 or int(footprint_phase.get("span_fill_remaining_unassigned_cell_count", -1)) != 185:
		_fail("0x4a325d span fill seed-1 cell counts drifted from the clean h3maped replay: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("span_fill_boundary_or_filled_cell_count", -1)) <= int(footprint_phase.get("boundary_unique_cell_count", -1)):
		_fail("0x4a325d span fill did not expand beyond the 0x4a2777 boundary cells: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("adjacency_finalizer_status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported":
		_fail("0x4a3710 small-land no-appended-zone finalizer was not ported: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("adjacency_finalizer_appended_runtime_zone_count", -1)) != 0 or int(footprint_phase.get("adjacency_finalizer_materialized_adjacency_count", -1)) != 0:
		_fail("0x4a3710 small-land branch should not append synthetic-zone adjacency: %s" % JSON.stringify(report))
		return
	if String(footprint_phase.get("terrain_fill_repaint_status", "")) != "0x4a3f27_terrain_fill_repaint_schedule_ported_inspection_only":
		_fail("0x4a3f27 terrain fill/repaint schedule was not ported over the real span-fill buffer: %s" % JSON.stringify(report))
		return
	if int(footprint_phase.get("terrain_repaint_call_count", -1)) != 1111:
		_fail("0x4a3f27 terrain repaint call count drifted from the seed-1 owned repaint cells: %s" % JSON.stringify(report))
		return
	var terrain_counts: Dictionary = footprint_phase.get("terrain_repaint_counts_after_repaint", {})
	if int(terrain_counts.get("dirt", -1)) != 492 or int(terrain_counts.get("grass", -1)) != 165 or int(terrain_counts.get("snow", -1)) != 222 or int(terrain_counts.get("rough", -1)) != 232 or int(terrain_counts.get("water", -1)) != 185:
		_fail("0x4a3f27 terrain counts after water fill and per-zone repaint drifted: %s" % JSON.stringify(report))
		return
	var terrain_fill: Dictionary = footprint_phase.get("terrain_fill_repaint", {})
	if int(terrain_fill.get("assigned_owner_cell_count", -1)) != 1111 or int(terrain_fill.get("zone_repaint_member_cell_count", -1)) != 1111 or int(terrain_fill.get("unresolved_cell_count", -1)) != 185:
		_fail("0x4a3f27 terrain fill/repaint did not consume the real 0x4a325d owner-byte buffer: %s" % JSON.stringify(report))
		return
	if int(terrain_fill.get("owner_basis_mismatch_count", -1)) != 0 or String(terrain_fill.get("terrain_art_index_flip_status", "")) != "TerrainPlacement_visual_selection_ported_inspection_only":
		_fail("0x4a3f27 terrain fill/repaint owner basis or TerrainPlacement visual normalization status drifted: %s" % JSON.stringify(terrain_fill))
		return
	var terrain_codes: PackedInt32Array = terrain_fill.get("terrain_code_u16", PackedInt32Array())
	var terrain_art_indices: PackedInt32Array = terrain_fill.get("terrain_art_index_u8", PackedInt32Array())
	var terrain_flip_h: PackedInt32Array = terrain_fill.get("terrain_flip_h", PackedInt32Array())
	var terrain_flip_v: PackedInt32Array = terrain_fill.get("terrain_flip_v", PackedInt32Array())
	var terrain_shape_classes: PackedInt32Array = terrain_fill.get("terrain_shape_class_u8", PackedInt32Array())
	var tile_byte_0: PackedInt32Array = terrain_fill.get("tile_byte_0_terrain_id_u8", PackedInt32Array())
	var tile_byte_1: PackedInt32Array = terrain_fill.get("tile_byte_1_terrain_art_u8", PackedInt32Array())
	var tile_byte_2: PackedInt32Array = terrain_fill.get("tile_byte_2_river_type_u8", PackedInt32Array())
	var tile_byte_3: PackedInt32Array = terrain_fill.get("tile_byte_3_river_art_u8", PackedInt32Array())
	var tile_byte_4: PackedInt32Array = terrain_fill.get("tile_byte_4_road_type_u8", PackedInt32Array())
	var tile_byte_5: PackedInt32Array = terrain_fill.get("tile_byte_5_road_art_u8", PackedInt32Array())
	var tile_byte_6: PackedInt32Array = terrain_fill.get("tile_byte_6_terrain_flags_u8", PackedInt32Array())
	var owner_byte_grid: PackedInt32Array = terrain_fill.get("owner_byte_grid_u8", PackedInt32Array())
	var owner_high_byte_grid: PackedInt32Array = terrain_fill.get("owner_high_byte_grid_i8", PackedInt32Array())
	var repaint_member_grid: PackedInt32Array = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array())
	if terrain_codes.size() != 1296 or terrain_art_indices.size() != 1296 or terrain_flip_h.size() != 1296 or terrain_flip_v.size() != 1296 or terrain_shape_classes.size() != 1296 or tile_byte_0.size() != 1296 or tile_byte_1.size() != 1296 or tile_byte_2.size() != 1296 or tile_byte_3.size() != 1296 or tile_byte_4.size() != 1296 or tile_byte_5.size() != 1296 or tile_byte_6.size() != 1296 or owner_byte_grid.size() != 1296 or owner_high_byte_grid.size() != 1296 or repaint_member_grid.size() != 1296:
		_fail("TerrainPlacement visual arrays must cover every small-map cell: %s" % JSON.stringify({
			"terrain_code_u16": terrain_codes.size(),
			"terrain_art_index_u8": terrain_art_indices.size(),
			"terrain_flip_h": terrain_flip_h.size(),
			"terrain_flip_v": terrain_flip_v.size(),
			"terrain_shape_class_u8": terrain_shape_classes.size(),
			"tile_byte_0_terrain_id_u8": tile_byte_0.size(),
			"tile_byte_1_terrain_art_u8": tile_byte_1.size(),
			"tile_byte_2_river_type_u8": tile_byte_2.size(),
			"tile_byte_3_river_art_u8": tile_byte_3.size(),
			"tile_byte_4_road_type_u8": tile_byte_4.size(),
			"tile_byte_5_road_art_u8": tile_byte_5.size(),
			"tile_byte_6_terrain_flags_u8": tile_byte_6.size(),
			"owner_byte_grid_u8": owner_byte_grid.size(),
			"owner_high_byte_grid_i8": owner_high_byte_grid.size(),
			"zone_repaint_member_grid_u8": repaint_member_grid.size(),
		}))
		return
		var owner_high_normalization: Dictionary = terrain_fill.get("owner_high_byte_normalization", {}) if terrain_fill.get("owner_high_byte_normalization", {}) is Dictionary else {}
		var owner_high_counts: Dictionary = terrain_fill.get("owner_high_byte_counts", {}) if terrain_fill.get("owner_high_byte_counts", {}) is Dictionary else {}
		if String(terrain_fill.get("occupancy_reset_high_owner_status", "")) != "0x4a5767_49a318_high_owner_channel_materialized_inspection_only" \
				or String(terrain_fill.get("owner_low_byte_source", "")) != "cell+0x20 bits 16..23" \
				or String(terrain_fill.get("owner_high_byte_source", "")) != "cell+0x20 bits 24..31" \
				or int(terrain_fill.get("owner_high_byte_materialized_count", -1)) != 1111 \
				or int(terrain_fill.get("owner_high_byte_sentinel_count", -1)) != 185 \
				or String(owner_high_normalization.get("function_address", "")) != "0x4a5767" \
				or String(owner_high_normalization.get("propagation_helper_address", "")) != "0x49a318" \
				or String(owner_high_normalization.get("cell_init_helper_address", "")) != "0x4a59e2" \
				or not bool(owner_high_normalization.get("grid_available", false)) \
				or bool(owner_high_normalization.get("complete_object_metadata_gate", true)) \
				or int(owner_high_normalization.get("seed_attempt_count", -1)) != 6 \
				or int(owner_high_normalization.get("seed_blocked_count", -1)) != 0 \
				or int(owner_high_normalization.get("popped_cell_count", -1)) != 3539 \
				or int(owner_high_normalization.get("same_owner_relax_count", -1)) != 1105 \
				or int(owner_high_normalization.get("cross_owner_high_byte_write_count", -1)) != 2428 \
				or int(owner_high_normalization.get("max_queue_size", -1)) != 71 \
				or int(owner_high_counts.get(0, -1)) != 171 \
				or int(owner_high_counts.get(1, -1)) != 201 \
				or int(owner_high_counts.get(2, -1)) != 174 \
				or int(owner_high_counts.get(3, -1)) != 262 \
				or int(owner_high_counts.get(4, -1)) != 124 \
				or int(owner_high_counts.get(5, -1)) != 179:
			_fail("0x4a5767/0x49a318 high owner-byte boundary drifted: %s" % JSON.stringify(terrain_fill))
			return
	if String(terrain_fill.get("tile_byte_writeout_status", "")) != "0x49b2b6_terrain_bytes_packed_overlay_bytes_pending":
		_fail("0x49b2b6 terrain-byte packing status was not exposed: %s" % JSON.stringify(terrain_fill))
		return
	if String(terrain_fill.get("tile_byte_overlay_status", "")) != "road_and_river_overlay_bytes_zero_until_0x4ab37f_0x4b4243_and_0x4ab6ac_0x4abd5f_ports":
		_fail("0x49b2b6 overlay byte pending status was not exposed: %s" % JSON.stringify(terrain_fill))
		return
	for index in range(terrain_codes.size()):
		var expected_byte_6 := (1 if int(terrain_flip_h[index]) != 0 else 0) | (2 if int(terrain_flip_v[index]) != 0 else 0)
		if int(tile_byte_0[index]) != (int(terrain_codes[index]) & 0x3f) or int(tile_byte_1[index]) != (int(terrain_art_indices[index]) & 0xff) or int(tile_byte_2[index]) != 0 or int(tile_byte_3[index]) != 0 or int(tile_byte_4[index]) != 0 or int(tile_byte_5[index]) != 0 or int(tile_byte_6[index]) != expected_byte_6:
			_fail("0x49b2b6 terrain-byte packing drifted from generated-cell fields: %s" % JSON.stringify({
				"index": index,
				"terrain_code": terrain_codes[index],
				"terrain_art": terrain_art_indices[index],
				"flip_h": terrain_flip_h[index],
				"flip_v": terrain_flip_v[index],
				"tile_byte_0": tile_byte_0[index],
				"tile_byte_1": tile_byte_1[index],
				"tile_byte_2": tile_byte_2[index],
				"tile_byte_3": tile_byte_3[index],
				"tile_byte_4": tile_byte_4[index],
				"tile_byte_5": tile_byte_5[index],
				"tile_byte_6": tile_byte_6[index],
			}))
			return
	var terrain_code_counts: Dictionary = terrain_fill.get("terrain_code_counts_after_repaint", {})
	if int(terrain_code_counts.get(0, -1)) != 492 or int(terrain_code_counts.get(2, -1)) != 165 or int(terrain_code_counts.get(3, -1)) != 222 or int(terrain_code_counts.get(5, -1)) != 232 or int(terrain_code_counts.get(8, -1)) != 185:
		_fail("0x4a3f27 terrain code grid counts drifted from terrain-id counts: %s" % JSON.stringify(terrain_code_counts))
		return
	var terrain_shape_counts: Dictionary = terrain_fill.get("terrain_visual_shape_class_counts", {})
	if int(terrain_fill.get("terrain_visual_transition_cell_count", -1)) != 413 or int(terrain_fill.get("terrain_visual_fallback_count", -1)) != 20 or int(terrain_shape_counts.get(0, -1)) != 883:
		_fail("TerrainPlacement visual class/fallback counts drifted: %s" % JSON.stringify({
			"transition": terrain_fill.get("terrain_visual_transition_cell_count", -1),
			"fallback": terrain_fill.get("terrain_visual_fallback_count", -1),
			"class_counts": terrain_shape_counts,
		}))
		return
	var link_seeds: Array = runtime_build.get("link_seeds", [])
	if link_seeds.size() != 5 or int(link_seeds[0].get("runtime_zone_a", -1)) != 0 or int(link_seeds[0].get("runtime_zone_b", -1)) != 3:
		_fail("Runtime-zone link seed endpoint resolution drifted from source link vectors: %s" % JSON.stringify(report))
		return
	if String(runtime_build.get("early_link_placement_status", "")) != "0x4a1f3b_endpoint_control_flow_ported_inspection_only":
		_fail("The clean boundary did not expose the h3maped early link-placement control flow: %s" % JSON.stringify(report))
		return
	var early_link_placement: Dictionary = runtime_build.get("early_link_placement", {})
	if int(early_link_placement.get("creation_pass_count", -1)) != 6 or int(early_link_placement.get("stabilization_pass_count", -1)) != 2:
		_fail("The h3maped early link-placement pass schedule drifted from 0x4a218c/0x4a1f3b: %s" % JSON.stringify(report))
		return
	if int(early_link_placement.get("call_count", -1)) != 18:
		_fail("The h3maped early link-placement call count should be creation pass plus two stabilization passes: %s" % JSON.stringify(report))
		return
	if int(early_link_placement.get("explicit_endpoint_attempt_count", -1)) != 25:
		_fail("The h3maped early link-placement endpoint attempt count drifted for the selected template: %s" % JSON.stringify(report))
		return
	if int(early_link_placement.get("fallback_attempt_count_if_no_valid_endpoint", -1)) != 3:
		_fail("The h3maped early link-placement fallback schedule drifted for the selected template: %s" % JSON.stringify(report))
		return
	if String(early_link_placement.get("coordinate_candidate_status", "")) != "0x4a218c_interleaved_runtime_and_coordinate_replay_inspection_only":
		_fail("Coordinate candidate replay status did not flow back into the early link placement report: %s" % JSON.stringify(report))
		return
	var early_calls: Array = early_link_placement.get("calls", [])
	if early_calls.size() != 18:
		_fail("The h3maped early link-placement report did not expose all scheduled calls: %s" % JSON.stringify(report))
		return
	if early_calls[0].get("available_endpoint_runtime_zones", []) != [] or int(early_calls[0].get("fallback_candidate_count_if_no_valid_endpoint", -1)) != 0:
		_fail("The first runtime zone should enter 0x4a1f3b with an empty runtime vector: %s" % JSON.stringify(report))
		return
	if early_calls[3].get("available_endpoint_runtime_zones", []) != [0]:
		_fail("Creation pass endpoint availability for source zone 4 drifted from the selected template graph: %s" % JSON.stringify(report))
		return
	if early_calls[6].get("available_endpoint_runtime_zones", []) != [3]:
		_fail("First stabilization pass endpoint availability for source zone 1 drifted from the selected template graph: %s" % JSON.stringify(report))
		return

	var color_config := config.duplicate(true)
	var color_constraints: Dictionary = color_config.get("player_constraints", {}).duplicate(true)
	color_constraints["selected_color_bitmap"] = [false, false, true, false, false, false, false, false]
	color_config["player_constraints"] = color_constraints
	var color_report: Dictionary = service.inspect_h3maped_small_rmg_port(color_config)
	var color_assignment: Dictionary = color_report.get("selected_template_payload", {}).get("player_slot_assignment", {})
	if color_assignment.get("selected_color_order", []) != [2, 0, 1, 3, 4, 5, 6, 7]:
		_fail("Explicit selected-color bitmap did not control h3maped color order: %s" % JSON.stringify(color_report))
		return
	if color_assignment.get("actual_colors_by_source_owner", []) != [2, 0, 1, -1, -1, -1, -1, -1]:
		_fail("Explicit selected-color bitmap did not flow into h3maped owner-color mapping: %s" % JSON.stringify(color_report))
		return

	var phase_ledger: Array = report.get("phase_ledger", [])
	if phase_ledger.size() < 8:
		_fail("The clean restart report must expose the executable phase ledger before implementation continues: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[0].get("phase_id", "")) != "template_selection" or String(phase_ledger[0].get("status", "")) != "ported_inspection_only":
		_fail("The phase ledger lost the h3maped template-selection anchor: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[1].get("phase_id", "")) != "player_slot_assignment" or String(phase_ledger[1].get("status", "")) != "ported_inspection_only":
		_fail("The phase ledger did not mark only the clean h3maped player-slot assignment as ported: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[2].get("phase_id", "")) != "runtime_zone_build" or String(phase_ledger[2].get("status", "")) != "ported_interleaved_runtime_coordinate_and_terrain_selection_inspection_only":
		_fail("The phase ledger did not mark only the clean h3maped runtime-zone record build as ported: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[3].get("phase_id", "")) != "zone_footprint_placement" or String(phase_ledger[3].get("status", "")) != "ported_0x4a3710_small_land_footprint_helpers_and_terrain_visual_inspection_only":
		_fail("The phase ledger did not expose only the clean h3maped 0x4a3710 footprint checkpoint as ported: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[4].get("status", "")) != "ported_schedule_and_visual_normalization_inspection_only":
		_fail("The phase ledger did not mark the clean h3maped 0x4a3f27 terrain schedule and visual normalization as ported: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[5].get("status", "")) != "0x4a8d2c_0x4a93a2_0x49aa93_town_49a09c_and_writeout_ledger_ported_project_adoption_pending":
		_fail("The phase ledger did not mark only h3maped direct town/castle candidate validity prechecking as ported for the object category phase: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[6].get("phase_id", "")) != "guard_reward_monster_placement" or String(phase_ledger[6].get("status", "")) != "0x4a9d6a_0x4a9911_0x4a9641_0x4aab7e_0x4aa354_value_selection_ported_rewards_pending":
		_fail("The phase ledger did not mark h3maped mine source ledgers and 0x4a9641 scan as ported with reward placement still pending: %s" % JSON.stringify(report))
		return
	var path_seed_update: Dictionary = selected_payload.get("path_state_seed_update_rule", {}) if selected_payload.get("path_state_seed_update_rule", {}) is Dictionary else {}
	if String(path_seed_update.get("status", "")) != "h3maped_0x4aae7b_path_state_seed_boundary_recovered_toolkit_pending" \
			or String(path_seed_update.get("normal_neighbor_update_block", "")) != "0x4ab2d8..0x4ab33a" \
			or String(path_seed_update.get("special_vector_update_block", "")) != "0x4ab25d..0x4ab2d0" \
			or String(path_seed_update.get("normal_neighbor_cost_source", "")) != "current_cost + 0x14, or current_cost + 0x3c when direction index bit0 is set" \
			or String(path_seed_update.get("special_vector_cost_source", "")) != "current_cost + 0x32" \
			or String(path_seed_update.get("update_compare", "")) != "computed_cost < target_cell_low_word" \
			or String(path_seed_update.get("path_cost_low_word_preserve_expression", "")) != "((old_cell_state ^ computed_cost) & 0xffff) ^ old_cell_state" \
			or String(path_seed_update.get("predecessor_write_block", "")) != "0x4ab310..0x4ab31b" \
			or String(path_seed_update.get("target_enqueue_block", "")) != "0x4ab31c..0x4ab32f" \
			or String(path_seed_update.get("queue_cleanup_block", "")) != "0x4ab353..0x4ab36e" \
			or String(path_seed_update.get("seed_initialization_status", "")) != "h3maped_0x4aae7b_seed_cell_initialization_materialized_propagation_pending" \
			or String(path_seed_update.get("neighbor_direction_table_status", "")) != "h3maped_0x5a2658_direction_table_materialized_propagation_pending" \
			or bool(path_seed_update.get("materializes_road_geometry", true)):
		_fail("The clean h3maped inspection report did not expose the recovered 0x4aae7b update rule: %s" % JSON.stringify(path_seed_update))
		return
	var direction_dx: PackedInt32Array = path_seed_update.get("neighbor_direction_dx_i32", PackedInt32Array())
	var direction_dy: PackedInt32Array = path_seed_update.get("neighbor_direction_dy_i32", PackedInt32Array())
	var direction_records: Array = path_seed_update.get("neighbor_direction_records", [])
	if String(path_seed_update.get("neighbor_direction_table_address", "")) != "0x5a2658" \
			or String(path_seed_update.get("neighbor_direction_table_end_address", "")) != "0x5a2698" \
			or String(path_seed_update.get("neighbor_direction_table_initializer", "")) != "0x499db3..0x499e20" \
			or direction_dx.size() != 8 \
			or direction_dy.size() != 8 \
			or direction_records.size() != 8:
		_fail("The recovered 0x5a2658 neighbor direction table was not materialized: %s" % JSON.stringify(path_seed_update))
		return
	var expected_dx := [1, 1, 0, -1, -1, -1, 0, 1]
	var expected_dy := [0, 1, 1, 1, 0, -1, -1, -1]
	for direction_index in range(8):
		var direction_record: Dictionary = direction_records[direction_index] if direction_records[direction_index] is Dictionary else {}
		if int(direction_dx[direction_index]) != int(expected_dx[direction_index]) \
				or int(direction_dy[direction_index]) != int(expected_dy[direction_index]) \
				or int(direction_record.get("dx", 999)) != int(expected_dx[direction_index]) \
				or int(direction_record.get("dy", 999)) != int(expected_dy[direction_index]):
			_fail("The recovered 0x5a2658 neighbor direction table values drifted at index %d: %s" % [direction_index, JSON.stringify(path_seed_update)])
			return
	var road_coordinate_vector_source: Dictionary = selected_payload.get("road_coordinate_vector_source", {}) if selected_payload.get("road_coordinate_vector_source", {}) is Dictionary else {}
	var road_adapter_boundary: Dictionary = selected_payload.get("road_adapter_boundary", {}) if selected_payload.get("road_adapter_boundary", {}) is Dictionary else {}
	var road_pair_iteration: Dictionary = road_adapter_boundary.get("road_pair_iteration", {}) if road_adapter_boundary.get("road_pair_iteration", {}) is Dictionary else {}
	var road_adapter_bridge: Dictionary = road_adapter_boundary.get("road_adapter_bridge", {}) if road_adapter_boundary.get("road_adapter_bridge", {}) is Dictionary else {}
	var road_candidate_marking: Dictionary = road_adapter_boundary.get("road_candidate_marking", {}) if road_adapter_boundary.get("road_candidate_marking", {}) is Dictionary else {}
	var road_final_art_materialization: Dictionary = road_adapter_boundary.get("road_final_art_materialization", {}) if road_adapter_boundary.get("road_final_art_materialization", {}) is Dictionary else {}
	var road_overlay_serialization: Dictionary = road_adapter_boundary.get("road_overlay_serialization", {}) if road_adapter_boundary.get("road_overlay_serialization", {}) is Dictionary else {}
	var road_toolkit_entry: Dictionary = road_adapter_boundary.get("road_toolkit_entry", {}) if road_adapter_boundary.get("road_toolkit_entry", {}) is Dictionary else {}
	var road_line_visit: Dictionary = road_toolkit_entry.get("line_visit_boundary", {}) if road_toolkit_entry.get("line_visit_boundary", {}) is Dictionary else {}
	var path_state_reset: Dictionary = road_adapter_boundary.get("path_state_reset", {}) if road_adapter_boundary.get("path_state_reset", {}) is Dictionary else {}
	var reset_pred_x: PackedInt32Array = path_state_reset.get("predecessor_x_i32", PackedInt32Array())
	var reset_pred_y: PackedInt32Array = path_state_reset.get("predecessor_y_i32", PackedInt32Array())
	var reset_pred_level: PackedInt32Array = path_state_reset.get("predecessor_level_i32", PackedInt32Array())
	var reset_costs: PackedInt32Array = path_state_reset.get("path_cost_low_word_u16", PackedInt32Array())
	var reset_materialized: PackedInt32Array = path_state_reset.get("materialized_bit25_grid_u8", PackedInt32Array())
	if String(path_state_reset.get("status", "")) != "h3maped_0x4aae2f_path_state_reset_grid_materialized_road_seed_pending" \
			or reset_pred_x.size() != 1296 \
			or reset_pred_y.size() != 1296 \
			or reset_pred_level.size() != 1296 \
			or reset_costs.size() != 1296 \
			or reset_materialized.size() != 1296:
		_fail("The clean h3maped report did not materialize the 0x4aae2f path-state reset arrays: %s" % JSON.stringify({
			"status": path_state_reset.get("status", ""),
			"predecessor_x_count": reset_pred_x.size(),
			"predecessor_y_count": reset_pred_y.size(),
			"predecessor_level_count": reset_pred_level.size(),
			"path_cost_count": reset_costs.size(),
			"materialized_count": reset_materialized.size(),
		}))
		return
	for reset_index in [0, 431, 1295]:
		if int(reset_pred_x[reset_index]) != -1 or int(reset_pred_y[reset_index]) != -1 or int(reset_pred_level[reset_index]) != -1 or int(reset_costs[reset_index]) != 0x7d00:
			_fail("0x4aae2f reset array values drifted from executable semantics at index %d: %s" % [reset_index, JSON.stringify({
				"predecessor_x": reset_pred_x[reset_index],
				"predecessor_y": reset_pred_y[reset_index],
				"predecessor_level": reset_pred_level[reset_index],
				"path_cost_low_word": reset_costs[reset_index],
			})])
			return
	var road_coordinate_record_count := int(road_coordinate_vector_source.get("materialized_partial_coordinate_record_count", -1))
	if String(road_pair_iteration.get("status", "")) != "h3maped_0x4ab52a_pair_iteration_ported_path_costs_materialized_road_adapter_pending" \
			or String(road_pair_iteration.get("function_address", "")) != "0x4ab52a" \
			or int(road_pair_iteration.get("coordinate_record_count", -1)) != road_coordinate_record_count \
			or int(road_pair_iteration.get("outer_seed_iteration_count", -1)) != max(0, road_coordinate_record_count - 1) \
			or int(road_pair_iteration.get("pair_candidate_iteration_count", -1)) != int((road_coordinate_record_count * (road_coordinate_record_count - 1)) / 2) \
			or not bool(road_pair_iteration.get("path_costs_materialized", false)) \
			or int(road_pair_iteration.get("candidate_low_word_count", -1)) != int((road_coordinate_record_count * (road_coordinate_record_count - 1)) / 2) \
			or int(road_pair_iteration.get("candidate_accept_count", -1)) != int(path_seed_update.get("candidate_accept_count", -2)) \
			or String(road_pair_iteration.get("candidate_low_word_read_block", "")) != "0x4ab5df..0x4ab60a" \
			or int(road_pair_iteration.get("candidate_low_word_threshold", -1)) != 0x7530 \
			or String(road_pair_iteration.get("candidate_accept_condition", "")) != "candidate cell +0x1c low word <= 0x7530" \
			or String(road_pair_iteration.get("road_adapter_call_site", "")) != "0x4ab611..0x4ab620 -> 0x4ab37f" \
			or int(road_pair_iteration.get("rng_state_before_road_phase_uint32", -1)) != int(mine_reward_placement.get("treasure_reward_rng_state_after_0x4aa354_uint32", -2)) \
			or bool(road_pair_iteration.get("road_geometry_materialized", true)):
		_fail("The clean h3maped inspection report did not expose the recovered 0x4ab52a road pair loop: %s" % JSON.stringify(road_pair_iteration))
		return
	if road_coordinate_record_count != 15 or int(road_pair_iteration.get("pair_candidate_iteration_count", -1)) != 105:
		_fail("Seed-1 partial road coordinate vector drifted from the currently ported h3maped town/mine record ledger: %s" % JSON.stringify({
			"coordinate_record_count": road_coordinate_record_count,
			"pair_candidate_iteration_count": road_pair_iteration.get("pair_candidate_iteration_count", -1),
			"road_coordinate_vector_source": road_coordinate_vector_source,
		}))
		return
	var seed_initializations: Array = path_seed_update.get("seed_initializations", [])
	if int(path_seed_update.get("seed_initialization_call_count", -1)) != road_coordinate_record_count - 1 \
			or int(path_seed_update.get("seed_initialization_expected_outer_seed_count", -1)) != road_coordinate_record_count - 1 \
			or seed_initializations.size() != road_coordinate_record_count - 1:
		_fail("0x4aae7b seed-cell initialization count did not match the 0x4ab52a outer seed loop: %s" % JSON.stringify(path_seed_update))
		return
	var propagation_summaries: Array = path_seed_update.get("normal_neighbor_propagation_summaries", [])
	var candidate_low_words: Array = path_seed_update.get("candidate_low_words", [])
	var predecessor_chains: Array = path_seed_update.get("predecessor_chain_records", [])
	var first_seed_costs: PackedInt32Array = path_seed_update.get("first_seed_path_cost_low_word_u16", PackedInt32Array())
	var first_seed_pred_x: PackedInt32Array = path_seed_update.get("first_seed_predecessor_x_i32", PackedInt32Array())
	var first_seed_pred_y: PackedInt32Array = path_seed_update.get("first_seed_predecessor_y_i32", PackedInt32Array())
	var first_seed_pred_level: PackedInt32Array = path_seed_update.get("first_seed_predecessor_level_i32", PackedInt32Array())
	if String(path_seed_update.get("normal_neighbor_propagation_status", "")) != "h3maped_0x4aae7b_normal_neighbor_path_costs_materialized_special_vectors_pending" \
			or String(path_seed_update.get("candidate_low_word_status", "")) != "h3maped_0x4ab52a_candidate_low_words_materialized_from_normal_0x4aae7b" \
			or int(path_seed_update.get("normal_neighbor_propagation_seed_count", -1)) != road_coordinate_record_count - 1 \
			or propagation_summaries.size() != road_coordinate_record_count - 1 \
			or int(path_seed_update.get("candidate_low_word_count", -1)) != int((road_coordinate_record_count * (road_coordinate_record_count - 1)) / 2) \
			or candidate_low_words.size() != int((road_coordinate_record_count * (road_coordinate_record_count - 1)) / 2) \
			or int(path_seed_update.get("candidate_accept_count", 0)) <= 0 \
			or String(path_seed_update.get("predecessor_chain_status", "")) != "h3maped_0x4ab37f_predecessor_chains_materialized_from_normal_0x4aae7b" \
			or int(path_seed_update.get("predecessor_chain_count", -1)) != int(path_seed_update.get("candidate_accept_count", -2)) \
			or predecessor_chains.size() != int(path_seed_update.get("candidate_accept_count", -2)) \
			or bool(path_seed_update.get("predecessor_chain_materializes_road_geometry", true)) \
			or first_seed_costs.size() != 1296 \
			or first_seed_pred_x.size() != 1296 \
			or first_seed_pred_y.size() != 1296 \
			or first_seed_pred_level.size() != 1296:
		_fail("0x4aae7b normal neighbor path-cost propagation was not materialized correctly: %s" % JSON.stringify(path_seed_update))
		return
	var first_propagation: Dictionary = propagation_summaries[0] if propagation_summaries[0] is Dictionary else {}
	if int(first_propagation.get("reached_cell_count", 0)) <= 1 \
			or int(first_propagation.get("relaxed_edge_count", 0)) <= 0 \
			or String(first_propagation.get("normal_neighbor_update_block", "")) != "0x4ab2d8..0x4ab33a" \
			or bool(first_propagation.get("special_vector_updates_materialized", true)):
		_fail("0x4aae7b first seed propagation summary drifted from the materialized normal-neighbor boundary: %s" % JSON.stringify(first_propagation))
		return
	var first_candidate_low_word: Dictionary = candidate_low_words[0] if candidate_low_words[0] is Dictionary else {}
	if int(first_candidate_low_word.get("candidate_low_word", 0x7d00)) > 0x7530 \
			or not bool(first_candidate_low_word.get("candidate_accepts_0x4ab52a", false)):
		_fail("0x4ab52a candidate low-word threshold semantics drifted after normal path propagation: %s" % JSON.stringify(first_candidate_low_word))
		return
	var first_predecessor_chain: Dictionary = predecessor_chains[0] if predecessor_chains[0] is Dictionary else {}
	if String(first_predecessor_chain.get("predecessor_chain_status", "")) != "h3maped_0x4ab37f_predecessor_chain_reaches_seed" \
			or not bool(first_predecessor_chain.get("predecessor_chain_reaches_seed", false)) \
			or int(first_predecessor_chain.get("predecessor_chain_step_count", 0)) <= 0 \
			or int(first_predecessor_chain.get("predecessor_chain_flat_cell_count", 0)) <= 0 \
			or bool(first_predecessor_chain.get("road_cell_mutation_materialized", true)) \
			or String(road_adapter_bridge.get("status", "")) != "h3maped_0x4ab37f_predecessor_chains_materialized_toolkit_pending" \
			or not bool(road_adapter_bridge.get("predecessor_chain_materialized", false)) \
			or int(road_adapter_bridge.get("predecessor_chain_count", -1)) != predecessor_chains.size() \
			or bool(road_adapter_bridge.get("materializes_road_geometry", true)):
		_fail("0x4ab37f predecessor-chain materialization did not stay aligned with the recovered path-state arrays: %s" % JSON.stringify({
			"first_predecessor_chain": first_predecessor_chain,
			"road_adapter_bridge": road_adapter_bridge,
			"predecessor_chain_count": predecessor_chains.size(),
		}))
		return
	var candidate_road_types: PackedInt32Array = road_candidate_marking.get("candidate_road_type_nibble_u8", PackedInt32Array())
	var candidate_road_art: PackedInt32Array = road_candidate_marking.get("final_road_art_u8", PackedInt32Array())
	var candidate_road_flip_a: PackedInt32Array = road_candidate_marking.get("final_road_flip_a_u8", PackedInt32Array())
	var candidate_road_flip_b: PackedInt32Array = road_candidate_marking.get("final_road_flip_b_u8", PackedInt32Array())
	var candidate_marked_cells: PackedInt32Array = road_candidate_marking.get("candidate_marked_flat_cells", PackedInt32Array())
	var candidate_marked_cell_count := int(road_candidate_marking.get("candidate_marked_cell_count", -1))
	if String(road_candidate_marking.get("status", "")) != "h3maped_0x49aec5_candidate_road_type_marks_materialized_art_pending" \
			or int(road_candidate_marking.get("selected_road_type", -1)) != int(road_pair_iteration.get("selected_road_type", -2)) \
			or int(road_candidate_marking.get("candidate_mark_road_type_shift", -1)) != 26 \
			or String(road_candidate_marking.get("candidate_mark_write_mask_cell_0x24_hex", "")) != "0xc3ffffff" \
			or candidate_road_types.size() != 1296 \
			or candidate_road_art.size() != 1296 \
			or candidate_road_flip_a.size() != 1296 \
			or candidate_road_flip_b.size() != 1296 \
			or candidate_marked_cells.size() != candidate_marked_cell_count \
			or candidate_marked_cell_count <= 0 \
			or int(road_candidate_marking.get("candidate_mark_write_attempt_count", 0)) < candidate_marked_cell_count \
			or not bool(road_candidate_marking.get("materializes_candidate_road_type_nibble", false)) \
			or bool(road_candidate_marking.get("materializes_final_road_art", true)) \
			or bool(road_candidate_marking.get("materializes_serialized_road_overlay", true)):
		_fail("0x49aec5 candidate road-type marking was not materialized correctly: %s" % JSON.stringify(road_candidate_marking))
		return
		for candidate_art_grid_index in range(candidate_road_art.size()):
			if int(candidate_road_art[candidate_art_grid_index]) != 0 or int(candidate_road_flip_a[candidate_art_grid_index]) != 0 or int(candidate_road_flip_b[candidate_art_grid_index]) != 0:
				_fail("0x49aec5 candidate marking must not synthesize final road art/flip: %s" % JSON.stringify({
					"index": candidate_art_grid_index,
					"art": candidate_road_art[candidate_art_grid_index],
					"flip_a": candidate_road_flip_a[candidate_art_grid_index],
					"flip_b": candidate_road_flip_b[candidate_art_grid_index],
				}))
				return
		if int(road_candidate_marking.get("candidate_road_type_grid_selected_count", -1)) != candidate_marked_cell_count:
			_fail("0x49aec5 candidate road-type mark count drifted from the grid: %s" % JSON.stringify({
				"candidate_marked_cell_count": candidate_marked_cell_count,
				"cpp_grid_selected_count": road_candidate_marking.get("candidate_road_type_grid_selected_count", -1),
				"selected_road_type": road_pair_iteration.get("selected_road_type", -1),
			}))
			return
		var final_road_types: PackedInt32Array = road_final_art_materialization.get("final_road_type_nibble_u8", PackedInt32Array())
		var final_road_art: PackedInt32Array = road_final_art_materialization.get("final_road_art_u8", PackedInt32Array())
		var final_road_flip_a: PackedInt32Array = road_final_art_materialization.get("final_road_flip_a_u8", PackedInt32Array())
		var final_road_flip_b: PackedInt32Array = road_final_art_materialization.get("final_road_flip_b_u8", PackedInt32Array())
		if String(road_final_art_materialization.get("status", "")) != "h3maped_0x458a2f_458893_final_art_flip_materialized_overlay_pending" \
				or final_road_types.size() != 1296 \
				or final_road_art.size() != 1296 \
				or final_road_flip_a.size() != 1296 \
				or final_road_flip_b.size() != 1296 \
				or int(road_final_art_materialization.get("selected_road_type", -1)) != int(road_pair_iteration.get("selected_road_type", -2)) \
				or int(road_final_art_materialization.get("final_road_cell_count", 0)) != candidate_marked_cell_count \
				or int(road_final_art_materialization.get("final_road_cell_count", 0)) != 411 \
				or int(road_final_art_materialization.get("candidate_mark_count", 0)) != candidate_marked_cell_count \
				or int(road_final_art_materialization.get("rng_call_count", 0)) != 1006 \
				or int(road_final_art_materialization.get("final_write_count", 0)) != 1006 \
				or int(road_final_art_materialization.get("neighbor_retouch_call_count", 0)) <= 0 \
				or not bool(road_final_art_materialization.get("materializes_final_road_art", false)) \
				or bool(road_final_art_materialization.get("materializes_serialized_road_overlay", true)) \
				or bool(road_final_art_materialization.get("complete_coordinate_vector_claim", true)):
			_fail("0x458a2f/0x458893 final road art/flip grid was not materialized as an inspection-only h3maped port: %s" % JSON.stringify(road_final_art_materialization))
			return
		var final_grid_selected_count := int(road_final_art_materialization.get("final_road_type_grid_selected_count", -1))
		var final_nonzero_art_count := int(road_final_art_materialization.get("final_nonzero_art_cell_count", -1))
		if final_grid_selected_count != candidate_marked_cell_count or final_nonzero_art_count <= 0:
			_fail("0x458a2f final road art grid count drifted from candidate marks: %s" % JSON.stringify({
				"final_grid_selected_count": final_grid_selected_count,
				"candidate_marked_cell_count": candidate_marked_cell_count,
				"final_nonzero_art_count": final_nonzero_art_count,
			}))
			return
		var road_overlay_byte_4: PackedInt32Array = road_overlay_serialization.get("tile_byte_4_road_type_u8", PackedInt32Array())
		var road_overlay_byte_5: PackedInt32Array = road_overlay_serialization.get("tile_byte_5_road_art_u8", PackedInt32Array())
		var road_overlay_byte_6: PackedInt32Array = road_overlay_serialization.get("tile_byte_6_flags_u8", PackedInt32Array())
		if String(road_overlay_serialization.get("status", "")) != "h3maped_0x49b2b6_road_overlay_bytes_materialized_partial_vector" \
				or road_overlay_byte_4.size() != 1296 \
				or road_overlay_byte_5.size() != 1296 \
				or road_overlay_byte_6.size() != 1296 \
				or int(road_overlay_serialization.get("road_overlay_cell_count", 0)) != candidate_marked_cell_count \
				or int(road_overlay_serialization.get("road_overlay_cell_count", 0)) != 411 \
				or int(road_overlay_serialization.get("road_type_selected_count", 0)) != candidate_marked_cell_count \
				or int(road_overlay_serialization.get("road_art_nonzero_count", 0)) != final_nonzero_art_count \
				or not bool(road_overlay_serialization.get("materializes_serialized_road_overlay", false)) \
				or bool(road_overlay_serialization.get("materializes_serialized_river_overlay", true)) \
				or bool(road_overlay_serialization.get("complete_coordinate_vector_claim", true)):
			_fail("0x49b2b6 road overlay bytes were not serialized from the recovered final road grid: %s" % JSON.stringify(road_overlay_serialization))
			return
		if int(road_adapter_boundary.get("road_overlay_cell_count", 0)) != candidate_marked_cell_count \
				or String(road_adapter_boundary.get("road_overlay_serialization_status", "")) != "h3maped_0x49b2b6_road_overlay_bytes_materialized_partial_vector":
			_fail("Road adapter boundary did not promote the recovered 0x49b2b6 road overlay serialization status: %s" % JSON.stringify(road_adapter_boundary))
			return
	var road_neighbor_dx: PackedInt32Array = road_line_visit.get("neighbor_direction_dx_i32", PackedInt32Array())
	var road_neighbor_dy: PackedInt32Array = road_line_visit.get("neighbor_direction_dy_i32", PackedInt32Array())
	var road_neighbor_records: Array = road_line_visit.get("neighbor_direction_records", [])
	var road_shape_records: Array = road_line_visit.get("road_art_shape_records", [])
	var road_art_variant_sequence: PackedInt32Array = road_line_visit.get("road_art_variant_class_sequence", PackedInt32Array())
	var road_art_variant_buckets: Array = road_line_visit.get("road_art_variant_bucket_records", [])
	var expected_road_dx := [0, 1, 1, 1, 0, -1, -1, -1]
	var expected_road_dy := [-1, -1, 0, 1, 1, 1, 0, -1]
	if String(road_toolkit_entry.get("neighbor_direction_table_initializer", "")) != "0x4bf38b..0x4bf3f3" \
			or String(road_line_visit.get("neighbor_direction_table_initializer", "")) != "0x4bf38b..0x4bf3f3" \
			or road_neighbor_dx.size() != 8 \
			or road_neighbor_dy.size() != 8 \
			or road_neighbor_records.size() != 8 \
			or road_shape_records.size() != 4 \
			or String(road_line_visit.get("road_art_variant_initializer_address", "")) != "0x4b41f4..0x4b4200" \
			or String(road_line_visit.get("road_art_variant_source_table_address", "")) != "0x54198c" \
			or String(road_line_visit.get("road_art_variant_runtime_table_address", "")) != "0x5a2f80" \
			or road_art_variant_sequence.size() != 17 \
			or road_art_variant_buckets.size() != 9 \
			or int(road_line_visit.get("road_art_shape_record_size_bytes", 0)) != 0x20 \
			or String(road_line_visit.get("final_write_cell_0x24_mask_hex", "")) != "0xc3ffffff" \
			or int(road_line_visit.get("final_write_cell_0x24_road_type_shift", -1)) != 26 \
			or String(road_line_visit.get("final_write_cell_0x28_mask_hex", "")) != "0xffe7ff00" \
			or int(road_line_visit.get("final_write_cell_0x28_flip_shift", -1)) != 19 \
			or bool(road_line_visit.get("materializes_road_geometry", true)):
		_fail("0x4b4243/0x458e61 road toolkit table/write evidence was not materialized from h3maped.exe: %s" % JSON.stringify(road_line_visit))
		return
	for road_direction_index in range(8):
		var road_direction_record: Dictionary = road_neighbor_records[road_direction_index] if road_neighbor_records[road_direction_index] is Dictionary else {}
		if int(road_neighbor_dx[road_direction_index]) != int(expected_road_dx[road_direction_index]) \
				or int(road_neighbor_dy[road_direction_index]) != int(expected_road_dy[road_direction_index]) \
				or int(road_direction_record.get("dx", 999)) != int(expected_road_dx[road_direction_index]) \
				or int(road_direction_record.get("dy", 999)) != int(expected_road_dy[road_direction_index]):
			_fail("0x5a5028 road-neighbor table values drifted at index %d: %s" % [road_direction_index, JSON.stringify(road_line_visit)])
			return
	var expected_shape_offsets := [
		[0, 1, 2, 3, 4, 5, 6, 7],
		[4, 3, 2, 1, 0, 7, 6, 5],
		[0, 7, 6, 5, 4, 3, 2, 1],
		[4, 5, 6, 7, 0, 1, 2, 3],
	]
	var expected_shape_flip_a := [0, 0, 1, 1]
	var expected_shape_flip_b := [0, 1, 0, 1]
	for shape_index in range(4):
		var shape_record: Dictionary = road_shape_records[shape_index] if road_shape_records[shape_index] is Dictionary else {}
		var shape_offsets: PackedInt32Array = shape_record.get("neighbor_flag_offsets", PackedInt32Array())
		if shape_offsets.size() != 8 \
				or int(shape_record.get("flip_selector_a", -1)) != int(expected_shape_flip_a[shape_index]) \
				or int(shape_record.get("flip_selector_b", -1)) != int(expected_shape_flip_b[shape_index]):
			_fail("0x538a04 road-shape record drifted at index %d: %s" % [shape_index, JSON.stringify(road_line_visit)])
			return
		for shape_offset_index in range(8):
			if int(shape_offsets[shape_offset_index]) != int(expected_shape_offsets[shape_index][shape_offset_index]):
				_fail("0x538a04 road-shape offset drifted at record %d offset %d: %s" % [shape_index, shape_offset_index, JSON.stringify(road_line_visit)])
				return
	var expected_variant_sequence := [4, 4, 5, 5, 5, 5, 6, 6, 7, 7, 2, 2, 3, 3, 0, 1, 8]
	for variant_index in range(expected_variant_sequence.size()):
		if int(road_art_variant_sequence[variant_index]) != int(expected_variant_sequence[variant_index]):
			_fail("0x54198c road-art variant class sequence drifted at index %d: %s" % [variant_index, JSON.stringify(road_line_visit)])
			return
	var expected_bucket_starts := [14, 15, 10, 12, 0, 2, 6, 8, 16]
	var expected_bucket_counts := [1, 1, 2, 2, 2, 4, 2, 2, 1]
	for art_class in range(9):
		var bucket: Dictionary = road_art_variant_buckets[art_class] if road_art_variant_buckets[art_class] is Dictionary else {}
		if int(bucket.get("art_class", -1)) != art_class \
				or int(bucket.get("first_variant_index", -1)) != int(expected_bucket_starts[art_class]) \
				or int(bucket.get("variant_count", -1)) != int(expected_bucket_counts[art_class]) \
				or int(bucket.get("runtime_record_offset_bytes", -1)) != 0x08 + art_class * 0x08:
			_fail("0x458755 road-art variant bucket drifted for art class %d: %s" % [art_class, JSON.stringify(road_line_visit)])
			return
	for seed_record_index in [0, seed_initializations.size() - 1]:
		var seed_init: Dictionary = seed_initializations[seed_record_index] if seed_initializations[seed_record_index] is Dictionary else {}
		if String(seed_init.get("seed_write_block", "")) != "0x4aaedc..0x4aaf0e" \
				or int(seed_init.get("path_cost_low_word_after_seed", -1)) != 0 \
				or seed_init.get("predecessor_after_seed", []) != [-1, -1, -1] \
				or not bool(seed_init.get("in_bounds", false)) \
				or bool(seed_init.get("materializes_neighbor_propagation", true)):
			_fail("0x4aae7b seed-cell initialization drifted from executable semantics: %s" % JSON.stringify(seed_init))
			return
	if int(road_pair_iteration.get("selected_road_type", 0)) != 1 or int(road_pair_iteration.get("road_type_rng_value", -1)) != 22929:
		_fail("Recovered 0x4ab52a seed-1 road type selection drifted from the current h3maped RNG replay: %s" % JSON.stringify(road_pair_iteration))
		return

	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "h3maped_small_clean_restart_gate"})
	if bool(generated.get("ok", true)) or String(generated.get("status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Small native catalog-auto generation must stay blocked until the clean h3maped phases can materialize complete maps: %s" % JSON.stringify({
			"ok": generated.get("ok", false),
			"status": generated.get("status", ""),
			"generation_status": generated.get("generation_status", ""),
			"full_generation_status": generated.get("full_generation_status", ""),
			"error_code": generated.get("error_code", ""),
		}))
		return
	if String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete" \
			or bool(Dictionary(generated.get("h3maped_small_port", {})).get("runtime_generation_allowed", true)):
		_fail("Blocked small generation must expose the inspection report and keep runtime generation disabled: %s" % JSON.stringify(generated))
		return
	var blocked_port: Dictionary = generated.get("h3maped_small_port", {}) if generated.get("h3maped_small_port", {}) is Dictionary else {}
	if String(blocked_port.get("status", "")) != "h3maped_small_clean_restart_template_selection_ready":
		_fail("Blocked small generation must carry the h3maped inspection boundary forward: %s" % JSON.stringify(blocked_port))
		return
	var explicit_small_config := config.duplicate(true)
	explicit_small_config["template_selection_mode"] = "catalog_explicit"
	explicit_small_config["template_id"] = "translated_rmg_template_049_v1"
	explicit_small_config["profile"] = {"id": "translated_rmg_profile_049_v1", "template_id": "translated_rmg_template_049_v1"}
	var explicit_small: Dictionary = service.generate_random_map(explicit_small_config, {"startup_path": "h3maped_small_explicit_template_gate"})
	if bool(explicit_small.get("ok", true)) \
			or String(explicit_small.get("status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(explicit_small.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Explicit small translated-template generation must route to the h3maped reset gate, not the archived native generator: %s" % JSON.stringify(explicit_small))
		return
	var medium_config := config.duplicate(true)
	medium_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var medium: Dictionary = service.generate_random_map(medium_config, {"startup_path": "h3maped_medium_archived_gate"})
	if bool(medium.get("ok", true)) or String(medium.get("status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope native catalog-auto generation must route to archived legacy disabled: %s" % JSON.stringify(medium))
		return
	var explicit_medium_config := medium_config.duplicate(true)
	explicit_medium_config["template_selection_mode"] = "catalog_explicit"
	explicit_medium_config["template_id"] = "translated_rmg_template_002_v1"
	explicit_medium_config["profile"] = {"id": "translated_rmg_profile_002_v1", "template_id": "translated_rmg_template_002_v1"}
	var explicit_medium: Dictionary = service.generate_random_map(explicit_medium_config, {"startup_path": "h3maped_medium_explicit_template_archived_gate"})
	if bool(explicit_medium.get("ok", true)) \
			or String(explicit_medium.get("status", "")) != "archived_legacy_native_rmg_disabled" \
			or String(explicit_medium.get("native_rmg_archive_status", "")) != "archived_legacy_native_rmg_debug_only":
		_fail("Out-of-scope explicit translated-template generation must not reach the archived native generator: %s" % JSON.stringify(explicit_medium))
		return
	var medium_debug: Dictionary = service.generate_random_map(medium_config, {"startup_path": "h3maped_medium_archived_gate", "allow_archived_legacy_native_rmg": true})
	if bool(medium_debug.get("ok", true)) or String(medium_debug.get("status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("The archived native catalog-auto path must remain disabled even when an old debug bypass option is passed: %s" % JSON.stringify(medium_debug))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"status": report.get("status", ""),
		"archive_status": report.get("archive_status", ""),
		"selected_template": selected_template.get("id", ""),
		"accepted_template_count": report.get("accepted_template_count", 0),
		"assignment_status": selected_payload.get("assignment_status", ""),
		"runtime_zone_build_status": selected_payload.get("runtime_zone_build_status", ""),
		"object_category_placement_status": selected_payload.get("object_category_placement_status", ""),
		"guard_reward_monster_placement_status": selected_payload.get("guard_reward_monster_placement_status", ""),
		"minimum_settlement_call_count": town_castle_placement.get("minimum_settlement_call_count", 0),
		"town_footprint_mask_status": town_castle_placement.get("town_footprint_mask_status", ""),
		"town_footprint_mask_eligible_total": town_castle_placement.get("town_footprint_mask_eligible_total", 0),
		"town_footprint_49a09c_status": town_castle_placement.get("town_footprint_49a09c_status", ""),
		"town_footprint_49a09c_pass_total": town_castle_placement.get("town_footprint_49a09c_pass_total", 0),
		"object_cell_materialization_status": town_castle_placement.get("object_cell_materialization_status", ""),
		"object_record_stamped_count": town_castle_placement.get("object_record_stamped_count", 0),
		"project_town_writeout_status": town_castle_placement.get("project_town_writeout_status", ""),
		"project_town_writeout_record_count": town_castle_placement.get("project_town_writeout_record_count", 0),
		"project_town_writeout_generator_f44_next": town_castle_placement.get("project_town_writeout_generator_f44_next", 0),
		"object_record_random_tie_selection_count": town_castle_placement.get("object_record_random_tie_selection_count", 0),
		"object_record_random_tie_rng_call_count": town_castle_placement.get("object_record_random_tie_rng_call_count", 0),
		"minimum_mine_count": mine_reward_placement.get("total_minimum_mine_count", 0),
		"mine_density_weight": mine_reward_placement.get("total_mine_density_weight", 0),
		"connection_guard_scaled_value_total": connection_payload.get("normal_guard_scaled_value_total", 0),
		"connection_guard_spawn_intent_count": connection_payload.get("normal_guard_spawn_intent_count", 0),
		"connection_geometry_dispatch_link_count": connection_payload.get("geometry_dispatch_link_count", 0),
		"connection_geometry_4a6cf2_overlap_cell_total": connection_payload.get("geometry_4a6cf2_overlap_cell_total", 0),
		"connection_geometry_4a696b_same_level_ready_count": connection_payload.get("geometry_4a696b_same_level_ready_count", 0),
		"mine_guard_scaled_value_total": mine_reward_placement.get("mine_guard_scaled_value_total", 0),
		"mine_template_row_count": mine_reward_placement.get("mine_template_row_count", 0),
		"mine_minimum_helper_call_count": mine_reward_placement.get("mine_minimum_helper_call_count", 0),
		"treasure_band_density_weight": mine_reward_placement.get("total_treasure_density_weight", 0),
		"treasure_scheduler_status": mine_reward_placement.get("treasure_scheduler_status", ""),
		"treasure_scheduler_active_zone_count": mine_reward_placement.get("treasure_scheduler_active_zone_count", 0),
		"treasure_scheduler_scaled_step_total": mine_reward_placement.get("treasure_scheduler_scaled_step_total", 0),
		"treasure_reward_attempt_status": mine_reward_placement.get("treasure_reward_attempt_status", ""),
		"treasure_reward_attempt_count": mine_reward_placement.get("treasure_reward_attempt_count", 0),
		"treasure_reward_value_rng_call_count": mine_reward_placement.get("treasure_reward_value_rng_call_count", 0),
		"treasure_reward_object_lookup_status": mine_reward_placement.get("treasure_reward_object_lookup_status", ""),
		"treasure_reward_object_lookup_count": mine_reward_placement.get("treasure_reward_object_lookup_count", 0),
		"treasure_reward_candidate_scan_status": mine_reward_placement.get("treasure_reward_candidate_scan_status", ""),
		"treasure_reward_candidate_scan_count": mine_reward_placement.get("treasure_reward_candidate_scan_count", 0),
		"treasure_reward_candidate_scan_eligible_total": mine_reward_placement.get("treasure_reward_candidate_scan_eligible_total", 0),
		"treasure_reward_candidate_scan_weight_total": mine_reward_placement.get("treasure_reward_candidate_scan_weight_total", 0),
		"treasure_reward_candidate_vector_proxy_backed_record_count": mine_reward_placement.get("treasure_reward_candidate_vector_proxy_backed_record_count", 0),
		"treasure_reward_candidate_vector_direct_field_record_count": mine_reward_placement.get("treasure_reward_candidate_vector_direct_field_record_count", 0),
		"treasure_reward_candidate_vector_literal_constructor_record_count": mine_reward_placement.get("treasure_reward_candidate_vector_literal_constructor_record_count", 0),
		"treasure_reward_candidate_vector_materialized_record_count": mine_reward_placement.get("treasure_reward_candidate_vector_materialized_record_count", 0),
		"treasure_reward_candidate_vector_static_insert_site_count": Dictionary(mine_reward_placement.get("treasure_reward_candidate_vector_static_construction_summary", {})).get("static_insert_site_count", 0),
		"treasure_reward_candidate_vector_uncovered_static_site_count": Dictionary(mine_reward_placement.get("treasure_reward_candidate_vector_static_construction_summary", {})).get("uncovered_static_insert_site_count", 0),
		"treasure_reward_proxy_inventory_reward_reference_count": mine_reward_placement.get("treasure_reward_proxy_inventory_reward_reference_count", 0),
		"terrain_selection_status": runtime_build.get("terrain_selection_status", ""),
		"early_link_placement_status": runtime_build.get("early_link_placement_status", ""),
		"coordinate_placement_status": runtime_build.get("coordinate_placement_status", ""),
		"coordinate_rng_order_status": coordinate_seed.get("rng_order_status", ""),
		"zone_footprint_placement_status": runtime_build.get("zone_footprint_placement_status", ""),
		"boundary_traversal_status": footprint_phase.get("boundary_traversal_status", ""),
		"boundary_unique_cell_count": footprint_phase.get("boundary_unique_cell_count", 0),
		"span_fill_status": footprint_phase.get("span_fill_status", ""),
		"span_fill_unique_filled_cell_count": footprint_phase.get("span_fill_unique_filled_cell_count", 0),
		"span_fill_remaining_unassigned_cell_count": footprint_phase.get("span_fill_remaining_unassigned_cell_count", 0),
		"adjacency_finalizer_status": footprint_phase.get("adjacency_finalizer_status", ""),
		"terrain_fill_repaint_status": footprint_phase.get("terrain_fill_repaint_status", ""),
		"terrain_repaint_call_count": footprint_phase.get("terrain_repaint_call_count", 0),
		"terrain_art_index_flip_status": terrain_fill.get("terrain_art_index_flip_status", ""),
		"tile_byte_writeout_status": terrain_fill.get("tile_byte_writeout_status", ""),
		"road_pair_iteration_status": road_pair_iteration.get("status", ""),
		"path_state_reset_status": path_state_reset.get("status", ""),
		"path_state_seed_initialization_count": path_seed_update.get("seed_initialization_call_count", 0),
		"path_state_normal_propagation_status": path_seed_update.get("normal_neighbor_propagation_status", ""),
		"path_state_candidate_low_word_count": path_seed_update.get("candidate_low_word_count", 0),
		"path_state_candidate_accept_count": path_seed_update.get("candidate_accept_count", 0),
		"path_state_predecessor_chain_count": path_seed_update.get("predecessor_chain_count", 0),
		"road_adapter_bridge_status": road_adapter_bridge.get("status", ""),
			"road_candidate_marking_status": road_candidate_marking.get("status", ""),
			"road_candidate_marked_cell_count": road_candidate_marking.get("candidate_marked_cell_count", 0),
			"road_final_art_status": road_final_art_materialization.get("status", ""),
			"road_final_cell_count": road_final_art_materialization.get("final_road_cell_count", 0),
			"road_final_write_count": road_final_art_materialization.get("final_write_count", 0),
			"road_final_art_rng_call_count": road_final_art_materialization.get("rng_call_count", 0),
			"road_overlay_serialization_status": road_overlay_serialization.get("status", ""),
			"road_overlay_cell_count": road_overlay_serialization.get("road_overlay_cell_count", 0),
			"road_toolkit_entry_status": road_toolkit_entry.get("status", ""),
		"road_line_visit_status": road_line_visit.get("status", ""),
		"road_coordinate_record_count": road_coordinate_record_count,
		"road_pair_candidate_iteration_count": road_pair_iteration.get("pair_candidate_iteration_count", 0),
		"selected_road_type": road_pair_iteration.get("selected_road_type", 0),
		"terrain_visual_transition_cell_count": terrain_fill.get("terrain_visual_transition_cell_count", 0),
		"terrain_visual_fallback_count": terrain_fill.get("terrain_visual_fallback_count", 0),
		"path_state_update_block": path_seed_update.get("normal_neighbor_update_block", ""),
		"path_state_cost_preserve": path_seed_update.get("path_cost_low_word_preserve_expression", ""),
		"generation_status": generated.get("status", ""),
		"generation_error_code": generated.get("error_code", ""),
		"runtime_generation_allowed": Dictionary(generated.get("h3maped_small_port", {})).get("runtime_generation_allowed", true),
		"partial_materialized_payload_status": report.get("partial_materialized_payload_status", ""),
		"out_of_scope_generation_status": medium.get("status", ""),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
