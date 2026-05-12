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
	if String(selected_payload.get("materialization_status", "")) != "blocked_until_next_executable_phase_port":
		_fail("The clean restart must stop after template selection until the next executable phase is ported: %s" % JSON.stringify(report))
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
	if String(selected_payload.get("runtime_zone_build_status", "")) != "0x4a218c_runtime_zone_record_setup_ported" \
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
			or String(runtime_records[0].get("coordinate_status", "")) != "pending_0x4a1f3b_0x4a17f5_0x4a1701":
		_fail("Runtime-zone records lost selected-template/source-owner identity: %s" % JSON.stringify(runtime_zones))
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
