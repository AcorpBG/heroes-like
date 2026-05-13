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

	var supported_config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var report: Dictionary = service.inspect_h3maped_small_rmg_port(supported_config)
	if not bool(report.get("ok", false)):
		_fail("Strict small h3maped boundary rejected the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1" \
			or String(report.get("implementation_policy", "")) != "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback" \
			or String(report.get("scope", "")) != "small_36x36_surface_land_only":
		_fail("Strict restart boundary metadata drifted: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) \
			or bool(report.get("partial_materialized_payload_public_api", true)) \
			or report.has("active_generation_state") \
			or report.has("small_generation_state") \
			or report.has("private_generation_context"):
		_fail("Strict restart boundary exposed active generation payload: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("path", "")) != "/root/Downloads/h3maped.exe" \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37" \
			or int(binary.get("actual_size_bytes", -1)) != 2134016 \
			or not bool(binary.get("mz_header_present", false)):
		_fail("h3maped.exe binary anchor is not verified: %s" % JSON.stringify(binary))
		return

	var selection: Dictionary = report.get("selection_identity", {})
	if not bool(selection.get("ok", false)) \
			or String(selection.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(selection.get("rng_function_address", "")) != "0x4e7276" \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or String(selection.get("adapted_template_id", "")) != "translated_rmg_template_019_v1":
		_fail("Strict h3maped template selection drifted: %s" % JSON.stringify(selection))
		return

	var player_slots: Dictionary = report.get("player_slot_assignment", {})
	if String(player_slots.get("status", "")) != "active_strict_executable_port" \
			or String(player_slots.get("source_range", "")) != "0x4ac62a..0x4ac6ec" \
			or String(player_slots.get("assignment_slots_offset", "")) != "generator+0xee0" \
			or String(player_slots.get("mapped_slots_offset", "")) != "generator+0xee4" \
			or String(player_slots.get("binary_byte_prefix_0x4ac62a", "")) != "6a 09 8d be e0 0e 00 00 59 83 c8 ff f3 ab 33 d2" \
			or Array(player_slots.get("raw_ee0_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or Array(player_slots.get("mapped_ee4_slots", [])) != [0, 1, 2, -1, -1, -1, -1, -1] \
			or int(player_slots.get("assigned_player_count", -1)) != 3:
		_fail("Strict h3maped player-slot assignment drifted: %s" % JSON.stringify(player_slots))
		return
	var assignments: Array = player_slots.get("assignment_records", [])
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
		_fail("Strict h3maped player-slot records drifted: %s" % JSON.stringify(assignments))
		return

	var runtime_zone_phase: Dictionary = report.get("runtime_zone_records", {})
	if String(runtime_zone_phase.get("status", "")) != "active_strict_executable_port" \
			or String(runtime_zone_phase.get("source_range", "")) != "0x4a218c/0x49b452" \
			or String(runtime_zone_phase.get("runtime_zone_vector_begin_offset", "")) != "generator+0x10e0" \
			or String(runtime_zone_phase.get("runtime_zone_vector_end_offset", "")) != "generator+0x10e4" \
			or String(runtime_zone_phase.get("runtime_zone_vector_capacity_offset", "")) != "generator+0x10e8" \
			or int(runtime_zone_phase.get("runtime_zone_record_size_bytes", -1)) != 0x414 \
			or String(runtime_zone_phase.get("binary_byte_prefix_0x4a218c", "")) != "55 8b ec 83 ec 28 53 8b d9 56 57 ff b3 e8 10 00" \
			or String(runtime_zone_phase.get("binary_byte_prefix_0x49b452", "")) != "55 8b ec 53 56 8b f1 33 db 8a 4d 0b 57 8d 86 e4" \
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
			or bool(runtime_zone_phase.get("materializes_runtime_players", true)) \
			or bool(runtime_zone_phase.get("materializes_public_output", true)):
		_fail("Strict h3maped runtime-zone record port drifted: %s" % JSON.stringify(runtime_zone_phase))
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
		_fail("Strict h3maped runtime-zone records changed: %s" % JSON.stringify(runtime_records))
		return

	var strict_state: Dictionary = report.get("strict_restart_state", {})
	if String(strict_state.get("schema_id", "")) != "aurelion_h3maped_small_strict_executable_restart_state_v1" \
			or String(strict_state.get("status", "")) != "strict_executable_restart_scaffold_active" \
			or not bool(strict_state.get("binary_verified", false)) \
			or bool(strict_state.get("active_public_generation_state", true)) \
			or bool(strict_state.get("legacy_private_phase_ledgers_exposed", true)) \
			or not bool(strict_state.get("legacy_private_phase_ledgers_archived_only", false)) \
			or String(strict_state.get("next_required_port", "")) != "link_seed_setup_0x4a1f3b":
		_fail("Strict executable restart state drifted: %s" % JSON.stringify(strict_state))
		return

	var pending_ports: Array = strict_state.get("pending_strict_ports", [])
	if pending_ports.size() != 8 \
			or not pending_ports.has("link_seed_setup:0x4a1f3b") \
			or not pending_ports.has("roads_rivers_blockers_guards:0x4ab52a_0x4aae7b_0x4a79a3_0x4a61bc_0x4a696b_0x4a6cf2"):
		_fail("Strict restart pending executable ports changed: %s" % JSON.stringify(pending_ports))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 12 \
			or String(backlog[0].get("status", "")) != "active_strict_boundary" \
			or String(backlog[1].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[2].get("status", "")) != "active_strict_executable_port" \
			or String(backlog[8].get("status", "")) != "pending_strict_executable_port" \
			or String(backlog[9].get("status", "")) != "pending_runtime_port":
		_fail("Strict phase backlog drifted: %s" % JSON.stringify(backlog))
		return

	var generated: Dictionary = service.generate_random_map(supported_config)
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or bool(generated.get("runtime_generation_allowed", true)) \
			or generated.has("active_generation_state"):
		_fail("Supported small map generation bypassed the reset gate: %s" % JSON.stringify(generated))
		return

	var explicit_config := supported_config.duplicate(true)
	explicit_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_result: Dictionary = service.generate_random_map(explicit_config)
	if bool(explicit_result.get("ok", true)) \
			or String(explicit_result.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready":
		_fail("Explicit translated-template request bypassed the reset gate: %s" % JSON.stringify(explicit_result))
		return

	var out_of_scope_config := supported_config.duplicate(true)
	out_of_scope_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var out_of_scope: Dictionary = service.generate_random_map(out_of_scope_config)
	if bool(out_of_scope.get("ok", true)) \
			or String(out_of_scope.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope map did not stay on the archived-native disabled gate: %s" % JSON.stringify(out_of_scope))
		return

	print("%s: ok" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
