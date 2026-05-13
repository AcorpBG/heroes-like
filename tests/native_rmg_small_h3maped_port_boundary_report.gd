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
			or String(backlog[2].get("status", "")) != "pending_strict_port" \
			or String(backlog[9].get("id", "")) != "final_h3m_writeout":
		_fail("Fresh restart backlog drifted: %s" % JSON.stringify(backlog))
		return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Fresh backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var private_context: Dictionary = report.get("private_generation_context", {})
	if String(private_context.get("schema_id", "")) != "aurelion_h3maped_small_private_generation_context_v1" \
			or String(private_context.get("status", "")) != "player_slot_assignment_private_context_ready" \
			or Array(private_context.get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment"] \
			or int(private_context.get("completed_phase_count", -1)) != 2 \
			or bool(private_context.get("runtime_generation_allowed", true)) \
			or bool(private_context.get("partial_materialized_payload_public_api", true)):
		_fail("Private generation context did not stop at the h3maped player-slot phase: %s" % JSON.stringify(private_context))
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

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or String(generated.get("error_code", "")) != "h3maped_phase_port_incomplete":
		_fail("Supported small generation must remain blocked by the fresh h3maped boundary: %s" % JSON.stringify(generated))
		return
	if Array(generated.get("private_generation_context", {}).get("completed_phase_ids", [])) != ["template_selection", "player_slot_assignment"]:
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
