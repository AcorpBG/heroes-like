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
