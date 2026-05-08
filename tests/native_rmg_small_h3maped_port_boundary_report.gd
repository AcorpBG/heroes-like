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
	if String(selected_payload.get("object_category_placement_status", "")) != "0x4a8d2c_0x4a93a2_0x49aa93_town_49a09c_and_writeout_ledger_ported_inspection_only":
		_fail("The clean boundary did not expose h3maped 0x4a8d2c/0x4a93a2/0x49aa93 direct town/castle candidate validity prechecking: %s" % JSON.stringify(report))
		return
	if String(selected_payload.get("guard_reward_monster_placement_status", "")) != "0x4a9d6a_0x4a9911_0x4a9641_0x4aab7e_mine_constraint_scan_ported_package_adoption_pending":
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
	var owner_byte_grid: PackedInt32Array = terrain_fill.get("owner_byte_grid_u8", PackedInt32Array())
	var repaint_member_grid: PackedInt32Array = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array())
	if terrain_codes.size() != 1296 or terrain_art_indices.size() != 1296 or terrain_flip_h.size() != 1296 or terrain_flip_v.size() != 1296 or terrain_shape_classes.size() != 1296 or owner_byte_grid.size() != 1296 or repaint_member_grid.size() != 1296:
		_fail("TerrainPlacement visual arrays must cover every small-map cell: %s" % JSON.stringify({
			"terrain_code_u16": terrain_codes.size(),
			"terrain_art_index_u8": terrain_art_indices.size(),
			"terrain_flip_h": terrain_flip_h.size(),
			"terrain_flip_v": terrain_flip_v.size(),
			"terrain_shape_class_u8": terrain_shape_classes.size(),
			"owner_byte_grid_u8": owner_byte_grid.size(),
			"zone_repaint_member_grid_u8": repaint_member_grid.size(),
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
	if String(phase_ledger[6].get("phase_id", "")) != "guard_reward_monster_placement" or String(phase_ledger[6].get("status", "")) != "0x4a9d6a_0x4a9911_0x4a9641_mine_constraint_scan_ported_rewards_pending":
		_fail("The phase ledger did not mark h3maped mine source ledgers and 0x4a9641 scan as ported with reward placement still pending: %s" % JSON.stringify(report))
		return

	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "h3maped_small_clean_restart_gate"})
	if bool(generated.get("ok", true)) or String(generated.get("status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Small native catalog-auto generation must be blocked until clean h3maped phase ports materialize the map: %s" % JSON.stringify(generated))
		return
	var medium_config := config.duplicate(true)
	medium_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var medium: Dictionary = service.generate_random_map(medium_config, {"startup_path": "h3maped_medium_archived_gate"})
	if bool(medium.get("ok", true)) or String(medium.get("status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope native catalog-auto generation must route to archived legacy disabled: %s" % JSON.stringify(medium))
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
		"mine_template_row_count": mine_reward_placement.get("mine_template_row_count", 0),
		"mine_minimum_helper_call_count": mine_reward_placement.get("mine_minimum_helper_call_count", 0),
		"treasure_band_density_weight": mine_reward_placement.get("total_treasure_density_weight", 0),
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
		"terrain_visual_transition_cell_count": terrain_fill.get("terrain_visual_transition_cell_count", 0),
		"terrain_visual_fallback_count": terrain_fill.get("terrain_visual_fallback_count", 0),
		"generation_status": generated.get("status", ""),
		"out_of_scope_generation_status": medium.get("status", ""),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
