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
	for index in range(2, backlog.size()):
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
