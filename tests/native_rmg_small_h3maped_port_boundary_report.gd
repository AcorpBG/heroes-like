extends Node

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_PORT_BOUNDARY_REPORT"

const SMALL_USABILITY_FLOOR := {
	"width": 36,
	"height": 36,
	"level_count": 1,
	"player_start_count": 3,
	"min_zone_count": 3,
	"min_town_count": 3,
	"min_object_count": 40,
	"min_guard_count": 6,
	"min_route_link_count": 1,
	"min_road_record_count": 1,
	"min_road_tile_count": 35,
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("native_rmg_generation_authority", "")) != "h3maped_small_reset_only" \
			or not bool(metadata.get("native_rmg_runtime_generation_allowed", false)) \
			or String(metadata.get("native_rmg_runtime_generation_policy", "")) != "small_36x36_land_validator_gated_only" \
			or not bool(metadata.get("native_rmg_production_ready", false)) \
			or String(metadata.get("native_rmg_production_ready_scope", "")) != "strict_small_36x36_one_level_land_only":
		_fail("Native RMG usability gate is not active: %s" % JSON.stringify(metadata))
		return

	var supported_config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}

	var report: Dictionary = service.inspect_h3maped_small_rmg_port(supported_config)
	if not _assert_inspection_usability(report):
		return

	var generated: Dictionary = service.generate_random_map(supported_config)
	if not _assert_generated_usability(generated):
		return

	var generated_repeat: Dictionary = service.generate_random_map(supported_config.duplicate(true))
	var repeat_payload: Dictionary = generated_repeat.get("map_document_payload", {}) if generated_repeat.get("map_document_payload", {}) is Dictionary else {}
	var generated_payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	if not bool(generated_repeat.get("ok", false)) \
			or String(repeat_payload.get("map_id", "")) != String(generated_payload.get("map_id", "")) \
			or String(repeat_payload.get("map_hash", "")) != String(generated_payload.get("map_hash", "")) \
			or Dictionary(generated_repeat.get("final_tile_bytes", {})) != Dictionary(generated.get("final_tile_bytes", {})):
		_fail("Small usability generation is not deterministic across repeat calls: %s / %s" % [JSON.stringify(generated), JSON.stringify(generated_repeat)])
		return

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"scenario_id": "h3maped_small_usability_gate_test",
		"feature_gate": "native_rmg_small_h3maped_usability_package_test",
	})
	if not _assert_adoption_usability(service, adoption, generated):
		return

	var explicit_config := supported_config.duplicate(true)
	explicit_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_result: Dictionary = service.generate_random_map(explicit_config)
	var explicit_payload: Dictionary = explicit_result.get("map_document_payload", {}) if explicit_result.get("map_document_payload", {}) is Dictionary else {}
	if not bool(explicit_result.get("ok", false)) \
			or String(explicit_result.get("generation_status", "")) != "h3maped_small_validated_package_ready" \
			or not String(explicit_payload.get("source_template_id", "")).begins_with("h3maped_template_") \
			or String(explicit_payload.get("source_kind", "")) != "generated_h3maped_small_validated":
		_fail("Explicit translated-template request did not stay on h3maped source-template authority: %s" % JSON.stringify(explicit_result))
		return

	var out_of_scope_config := supported_config.duplicate(true)
	out_of_scope_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var out_of_scope: Dictionary = service.generate_random_map(out_of_scope_config)
	if bool(out_of_scope.get("ok", true)) \
			or String(out_of_scope.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
		_fail("Out-of-scope map did not stay on the archived-native disabled gate: %s" % JSON.stringify(out_of_scope))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"schema_id": "native_rmg_small_h3maped_usability_boundary_report_v1",
		"small_usability_floor": SMALL_USABILITY_FLOOR,
		"template": String(generated_payload.get("source_template_id", "")),
		"metrics": generated.get("validator_metrics", {}),
	})])
	get_tree().quit(0)

func _assert_inspection_usability(report: Dictionary) -> bool:
	if not bool(report.get("ok", false)) \
			or String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1" \
			or String(report.get("scope", "")) != "small_36x36_surface_land_only":
		_fail("Small h3maped inspection boundary rejected the supported scope: %s" % JSON.stringify(report))
		return false
	var binary: Dictionary = report.get("h3maped_binary", {}) if report.get("h3maped_binary", {}) is Dictionary else {}
	if not bool(binary.get("ok", false)) \
			or String(binary.get("source", "")) != "compiled:h3maped_small_rmg_embedded_data" \
			or String(binary.get("reference_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("Compiled h3maped data anchor is not verified: %s" % JSON.stringify(binary))
		return false
	var selection: Dictionary = report.get("selection_identity", {}) if report.get("selection_identity", {}) is Dictionary else {}
	if not bool(selection.get("ok", false)) \
			or String(selection.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or not String(selection.get("source_template_id", "")).begins_with("h3maped_template_"):
		_fail("h3maped template selection authority drifted: %s" % JSON.stringify(selection))
		return false
	var fast_validator: Dictionary = report.get("fast_structural_validator", {}) if report.get("fast_structural_validator", {}) is Dictionary else {}
	if String(fast_validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" \
			or int(fast_validator.get("failure_count", -1)) != 0:
		_fail("Inspection fast validator is not green: %s" % JSON.stringify(fast_validator))
		return false
	return _assert_metrics_usability(fast_validator.get("metrics", {}) if fast_validator.get("metrics", {}) is Dictionary else {}, "inspection")

func _assert_generated_usability(generated: Dictionary) -> bool:
	var payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)) \
			or String(generated.get("schema_id", "")) != "aurelion_h3maped_small_validator_gated_generation_result_v1" \
			or String(generated.get("generation_status", "")) != "h3maped_small_validated_package_ready" \
			or String(generated.get("full_generation_status", "")) != "h3maped_small_public_package_production_ready_strict_small_land" \
			or not bool(generated.get("runtime_generation_allowed", false)) \
			or not bool(generated.get("public_runtime_authoritative", false)) \
			or bool(generated.get("full_parity_claim", true)):
		_fail("Small map generation did not return a validator-gated public package: %s" % JSON.stringify(generated))
		return false
	if not _assert_payload_usability(payload, "generated"):
		return false
	return _assert_metrics_usability(generated.get("validator_metrics", {}) if generated.get("validator_metrics", {}) is Dictionary else {}, "generated")

func _assert_adoption_usability(service: Variant, adoption: Dictionary, generated: Dictionary) -> bool:
	var adopted_map_document: Variant = adoption.get("map_document", null)
	var adopted_scenario_document: Variant = adoption.get("scenario_document", null)
	var adoption_report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var adoption_metrics: Dictionary = adoption_report.get("metrics", {}) if adoption_report.get("metrics", {}) is Dictionary else {}
	if not bool(adoption.get("ok", false)) \
			or String(adoption.get("status", "")) != "pass" \
			or String(adoption.get("conversion_kind", "")) != "h3maped_small_validated_package_to_package_session_records" \
			or String(adoption.get("adoption_status", "")) != "h3maped_small_package_session_production_ready_strict_small_land" \
			or adopted_map_document == null \
			or adopted_scenario_document == null \
			or not bool(adoption_report.get("package_session_adoption_ready", false)) \
			or not bool(adoption_report.get("production_ready", false)):
		_fail("Small usability package did not adopt into package/session documents: %s" % JSON.stringify(adoption))
		return false
	if int(adopted_map_document.get_width()) != int(SMALL_USABILITY_FLOOR.get("width", 0)) \
			or int(adopted_map_document.get_height()) != int(SMALL_USABILITY_FLOOR.get("height", 0)) \
			or int(adopted_map_document.get_level_count()) != int(SMALL_USABILITY_FLOOR.get("level_count", 0)) \
			or int(adopted_map_document.get_object_count()) < int(SMALL_USABILITY_FLOOR.get("min_object_count", 0)) \
			or int(adopted_scenario_document.get_start_contract().get("start_count", -1)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(adopted_scenario_document.get_start_contract().get("start_town_count", -1)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)):
		_fail("Adopted documents missed Small usability shape: %s" % JSON.stringify(adoption))
		return false
	if int(adoption_metrics.get("width", -1)) != int(SMALL_USABILITY_FLOOR.get("width", 0)) \
			or int(adoption_metrics.get("height", -1)) != int(SMALL_USABILITY_FLOOR.get("height", 0)) \
			or int(adoption_metrics.get("level_count", -1)) != int(SMALL_USABILITY_FLOOR.get("level_count", 0)) \
			or int(adoption_metrics.get("map_document_object_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_object_count", 0)) \
			or int(adoption_metrics.get("player_start_count", 0)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(adoption_metrics.get("player_start_town_count", 0)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(adoption_metrics.get("route_link_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_route_link_count", 0)):
		_fail("adoption metrics missed Small usability floor: %s" % JSON.stringify(adoption_metrics))
		return false
	var map_validation: Dictionary = service.validate_map_document(adopted_map_document)
	if not bool(map_validation.get("ok", false)):
		_fail("Adopted Small map document did not validate: %s" % JSON.stringify(map_validation))
		return false
	var scenario_validation: Dictionary = service.validate_scenario_document(adopted_scenario_document, adopted_map_document)
	if not bool(scenario_validation.get("ok", false)) \
			or int(scenario_validation.get("report", {}).get("metrics", {}).get("player_slot_count", -1)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)):
		_fail("Adopted Small scenario document did not validate: %s" % JSON.stringify(scenario_validation))
		return false
	var map_package_path := "user://h3maped_small_usability_gate_test.amap"
	var scenario_package_path := "user://h3maped_small_usability_gate_test.ascenario"
	var save_map: Dictionary = service.save_map_package(adopted_map_document, map_package_path, {"path_policy": "h3maped_small_usability_gate_test", "return_package": false})
	if not bool(save_map.get("ok", false)):
		_fail("Small usability map package save failed: %s" % JSON.stringify(save_map))
		return false
	var save_scenario: Dictionary = service.save_scenario_package(adopted_scenario_document, scenario_package_path, {"path_policy": "h3maped_small_usability_gate_test", "return_package": false})
	if not bool(save_scenario.get("ok", false)):
		DirAccess.remove_absolute(map_package_path)
		_fail("Small usability scenario package save failed: %s" % JSON.stringify(save_scenario))
		return false
	var load_map: Dictionary = service.load_map_package(map_package_path)
	var load_scenario: Dictionary = service.load_scenario_package(scenario_package_path)
	DirAccess.remove_absolute(map_package_path)
	DirAccess.remove_absolute(scenario_package_path)
	var loaded_map_document: Variant = load_map.get("map_document", null)
	var loaded_scenario_document: Variant = load_scenario.get("scenario_document", null)
	if not bool(load_map.get("ok", false)) \
			or not bool(load_scenario.get("ok", false)) \
			or loaded_map_document == null \
			or loaded_scenario_document == null \
			or String(loaded_map_document.get_map_hash()) != String(adopted_map_document.get_map_hash()) \
			or int(loaded_scenario_document.get_start_contract().get("start_count", -1)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)):
		_fail("Small usability packages did not round-trip through save/load: %s / %s" % [JSON.stringify(load_map), JSON.stringify(load_scenario)])
		return false
	return true

func _assert_payload_usability(payload: Dictionary, label: String) -> bool:
	if String(payload.get("schema_id", "")) != "aurelion_map_document" \
			or String(payload.get("source_kind", "")) != "generated_h3maped_small_validated" \
			or int(payload.get("width", -1)) != int(SMALL_USABILITY_FLOOR.get("width", 0)) \
			or int(payload.get("height", -1)) != int(SMALL_USABILITY_FLOOR.get("height", 0)) \
			or int(payload.get("level_count", -1)) != int(SMALL_USABILITY_FLOOR.get("level_count", 0)) \
			or not String(payload.get("source_template_id", "")).begins_with("h3maped_template_") \
			or not bool(payload.get("public_runtime_authoritative", false)):
		_fail("%s payload missed Small h3maped usability identity: %s" % [label, JSON.stringify(payload)])
		return false
	var terrain_layers: Dictionary = payload.get("terrain_layers", {}) if payload.get("terrain_layers", {}) is Dictionary else {}
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var route_graph: Dictionary = payload.get("route_graph", {}) if payload.get("route_graph", {}) is Dictionary else {}
	var objects: Array = payload.get("objects", []) if payload.get("objects", []) is Array else []
	var player_starts: Array = payload.get("player_starts", []) if payload.get("player_starts", []) is Array else []
	if objects.size() < int(SMALL_USABILITY_FLOOR.get("min_object_count", 0)) \
			or player_starts.size() != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or roads.size() < int(SMALL_USABILITY_FLOOR.get("min_road_record_count", 0)) \
			or int(route_graph.get("road_segment_disconnected_count", -1)) != 0 \
			or int(route_graph.get("link_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_route_link_count", 0)) \
			or int(route_graph.get("guarded_link_count", -1)) != int(route_graph.get("link_count", 0)):
		_fail("%s payload missed usable objects, starts, roads, or guarded routes: %s" % [label, JSON.stringify(payload)])
		return false
	for road in roads:
		if not (road is Dictionary) \
				or String(road.get("route_edge_id", "")) == "" \
				or not String(road.get("road_class", "")).begins_with("h3maped_") \
				or not String(road.get("road_class", "")).contains("route_road") \
				or not bool(road.get("connected_cell_chain", false)) \
				or int(road.get("cell_count", 0)) <= 1:
			_fail("%s road segment missed route metadata: %s" % [label, JSON.stringify(road)])
			return false
	return true

func _assert_metrics_usability(metrics: Dictionary, label: String) -> bool:
	if int(metrics.get("expected_tile_count", 1296)) != 1296 \
			or int(metrics.get("terrain_tile_count", 1296)) != 1296 \
			or int(metrics.get("package_object_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_object_count", 0)) \
			or int(metrics.get("player_start_count", 0)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(metrics.get("owned_player_town_count", 0)) != int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(metrics.get("mine_count", 0)) <= 0 \
			or int(metrics.get("connection_guard_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_guard_count", 0)) \
			or int(metrics.get("route_link_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_route_link_count", 0)) \
			or int(metrics.get("unguarded_route_link_count", -1)) != 0 \
			or int(metrics.get("route_link_without_blocker_count", -1)) != 0 \
			or int(metrics.get("route_link_without_guard_count", -1)) != 0 \
			or int(metrics.get("road_record_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_road_record_count", 0)) \
			or int(metrics.get("road_route_edge_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_road_record_count", 0)) \
			or int(metrics.get("road_route_node_count", 0)) < int(SMALL_USABILITY_FLOOR.get("player_start_count", 0)) \
			or int(metrics.get("road_segment_disconnected_count", -1)) != 0 \
			or int(metrics.get("road_segment_without_route_edge_count", -1)) != 0 \
			or int(metrics.get("road_segment_missing_metadata_count", -1)) != 0 \
			or int(metrics.get("road_overlay_type_nonzero_count", 0)) < int(SMALL_USABILITY_FLOOR.get("min_road_tile_count", 0)) \
			or int(metrics.get("duplicate_placement_id_count", -1)) != 0 \
			or int(metrics.get("out_of_bounds_object_count", -1)) != 0:
		_fail("%s metrics missed Small usability floor: %s" % [label, JSON.stringify(metrics)])
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
