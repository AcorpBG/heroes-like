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

	if String(selected_payload.get("runtime_zone_build_status", "")) != "0x4a218c_runtime_zone_records_ported_inspection_only":
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
	if String(runtime_zones[2].get("terrain_source", "")) != "pending_0x4a3f27_terrain_phase":
		_fail("Runtime-zone report must not consume terrain RNG before the h3maped terrain phase: %s" % JSON.stringify(report))
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
	if String(phase_ledger[2].get("phase_id", "")) != "runtime_zone_build" or String(phase_ledger[2].get("status", "")) != "ported_interleaved_runtime_and_coordinate_replay_inspection_only":
		_fail("The phase ledger did not mark only the clean h3maped runtime-zone record build as ported: %s" % JSON.stringify(report))
		return
	if String(phase_ledger[3].get("status", "")) != "pending_clean_port":
		_fail("Zone footprint placement must remain pending after the runtime-zone record port: %s" % JSON.stringify(report))
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
		"early_link_placement_status": runtime_build.get("early_link_placement_status", ""),
		"coordinate_placement_status": runtime_build.get("coordinate_placement_status", ""),
		"coordinate_rng_order_status": coordinate_seed.get("rng_order_status", ""),
		"generation_status": generated.get("status", ""),
		"out_of_scope_generation_status": medium.get("status", ""),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
