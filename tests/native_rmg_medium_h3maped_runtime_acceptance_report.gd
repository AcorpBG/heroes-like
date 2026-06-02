extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const REPORT_ID := "NATIVE_RMG_MEDIUM_H3MAPED_RUNTIME_ACCEPTANCE_REPORT"
const STRICT_SCOPE := "strict_medium_72x72_one_level_land_only"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated := _validate_public_generation(service)
	if not bool(generated.get("ok", false)):
		_fail("public generation failed: %s" % JSON.stringify(generated))
		return
	var adoption := _validate_package_adoption(service, generated)
	if not bool(adoption.get("ok", false)):
		_fail("package adoption failed: %s" % JSON.stringify(adoption))
		return
	var round_trip := _validate_save_load_round_trip(service, adoption)
	if not bool(round_trip.get("ok", false)):
		_fail("save/load round trip failed: %s" % JSON.stringify(round_trip))
		return
	var startup := _validate_generated_map_startup(service)
	if not bool(startup.get("ok", false)):
		_fail("generated-map startup failed: %s" % JSON.stringify(startup))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"schema_id": "native_rmg_medium_h3maped_runtime_acceptance_report_v1",
		"strict_scope": STRICT_SCOPE,
		"generation": generated.get("summary", {}),
		"adoption": adoption.get("summary", {}),
		"round_trip": round_trip,
		"startup": startup,
	})])
	get_tree().quit(0)

func _validate_public_generation(service: Variant) -> Dictionary:
	var generated: Dictionary = service.generate_random_map(_medium_land_config("10", 4), {"startup_path": "medium_runtime_acceptance"})
	var payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	var validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	var metrics: Dictionary = generated.get("validator_metrics", {}) if generated.get("validator_metrics", {}) is Dictionary else {}
	var tile_bytes: Dictionary = generated.get("final_tile_bytes", {}) if generated.get("final_tile_bytes", {}) is Dictionary else {}
	var byte_arrays_ok := true
	for key in ["byte_0_terrain_u8", "byte_1_terrain_art_u8", "byte_2_river_type_u8", "byte_3_river_art_u8", "byte_4_road_type_u8", "byte_5_road_art_u8", "byte_6_flags_u8"]:
		var bytes: Variant = tile_bytes.get(key, PackedInt32Array())
		if not (bytes is PackedInt32Array) or int(bytes.size()) != 5184:
			byte_arrays_ok = false
	var ok := bool(generated.get("ok", false)) \
			and String(generated.get("generation_status", "")) == "h3maped_medium_validated_package_ready" \
			and String(generated.get("full_generation_status", "")) == "h3maped_medium_public_package_production_ready_strict_medium_land" \
			and String(generated.get("production_ready_scope", "")) == STRICT_SCOPE \
			and bool(generated.get("runtime_generation_allowed", false)) \
			and bool(generated.get("public_runtime_authoritative", false)) \
			and String(payload.get("source_kind", "")) == "generated_h3maped_medium_validated" \
			and int(payload.get("width", 0)) == 72 \
			and int(payload.get("height", 0)) == 72 \
			and int(payload.get("level_count", 0)) == 1 \
			and String(validator.get("status", "")) == "strict_fast_structural_validator_pass_public_generation_ready" \
			and int(validator.get("failure_count", -1)) == 0 \
			and int(metrics.get("expected_tile_count", 0)) == 5184 \
			and int(metrics.get("player_start_count", 0)) == 4 \
			and int(metrics.get("owned_player_town_count", 0)) == 4 \
			and int(metrics.get("neutral_town_count", 0)) > 0 \
			and int(metrics.get("connection_blocker_count", 0)) > 0 \
			and int(metrics.get("connection_guard_count", 0)) > 0 \
			and int(metrics.get("route_link_without_blocker_count", -1)) == 0 \
			and int(metrics.get("route_link_without_guard_count", -1)) == 0 \
			and int(metrics.get("exact_h3m_body_block_mismatch_count", -1)) == 0 \
			and byte_arrays_ok
	var summary := {
		"status": generated.get("generation_status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"source_template_id": generated.get("source_template_id", ""),
		"source_catalog_index": generated.get("source_catalog_index", -1),
		"production_ready_scope": generated.get("production_ready_scope", ""),
		"metrics": metrics,
	}
	return {
		"ok": ok,
		"generated": generated,
		"summary": summary,
	}

func _validate_package_adoption(service: Variant, generated_report: Dictionary) -> Dictionary:
	var generated: Dictionary = generated_report.get("generated", {}) if generated_report.get("generated", {}) is Dictionary else {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_medium_h3maped_runtime_acceptance",
		"session_save_version": 9,
		"scenario_id": "h3maped_medium_runtime_acceptance",
	})
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var map_validation: Dictionary = service.validate_map_document(map_document) if map_document != null else {"ok": false}
	var scenario_validation: Dictionary = service.validate_scenario_document(scenario_document, map_document) if map_document != null and scenario_document != null else {"ok": false}
	var ok := bool(adoption.get("ok", false)) \
			and String(adoption.get("conversion_kind", "")) == "h3maped_medium_validated_package_to_package_session_records" \
			and String(adoption.get("adoption_status", "")) == "h3maped_medium_package_session_production_ready_strict_medium_land" \
			and String(adoption.get("production_ready_scope", "")) == STRICT_SCOPE \
			and map_document != null \
			and scenario_document != null \
			and int(map_document.get_width()) == 72 \
			and int(map_document.get_height()) == 72 \
			and int(map_document.get_level_count()) == 1 \
			and int(metrics.get("player_start_count", 0)) == 4 \
			and int(metrics.get("player_start_town_count", 0)) == 4 \
			and bool(map_validation.get("ok", false)) \
			and bool(scenario_validation.get("ok", false))
	return {
		"ok": ok,
		"adoption": adoption,
		"summary": {
			"conversion_kind": adoption.get("conversion_kind", ""),
			"adoption_status": adoption.get("adoption_status", ""),
			"production_ready_scope": adoption.get("production_ready_scope", ""),
			"metrics": metrics,
		},
	}

func _validate_save_load_round_trip(service: Variant, adoption_report: Dictionary) -> Dictionary:
	var adoption: Dictionary = adoption_report.get("adoption", {}) if adoption_report.get("adoption", {}) is Dictionary else {}
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	var map_path := "user://h3maped_medium_runtime_acceptance.amap"
	var scenario_path := "user://h3maped_medium_runtime_acceptance.ascenario"
	var save_map: Dictionary = service.save_map_package(map_document, map_path, {"path_policy": "h3maped_medium_runtime_acceptance", "return_package": false})
	var save_scenario: Dictionary = service.save_scenario_package(scenario_document, scenario_path, {"path_policy": "h3maped_medium_runtime_acceptance", "return_package": false})
	var load_map: Dictionary = service.load_map_package(map_path)
	var load_scenario: Dictionary = service.load_scenario_package(scenario_path)
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(scenario_path)
	var loaded_map: Variant = load_map.get("map_document", null)
	var loaded_scenario: Variant = load_scenario.get("scenario_document", null)
	var loaded_metadata: Dictionary = loaded_map.get_metadata() if loaded_map != null else {}
	var loaded_terrain: Dictionary = loaded_map.get_terrain_layers() if loaded_map != null else {}
	var roads: Array = loaded_terrain.get("roads", []) if loaded_terrain.get("roads", []) is Array else []
	var ok := bool(save_map.get("ok", false)) \
			and bool(save_scenario.get("ok", false)) \
			and bool(load_map.get("ok", false)) \
			and bool(load_scenario.get("ok", false)) \
			and loaded_map != null \
			and loaded_scenario != null \
			and int(loaded_map.get_width()) == 72 \
			and int(loaded_map.get_height()) == 72 \
			and int(loaded_map.get_level_count()) == 1 \
			and int(loaded_map.get_object_count()) > 0 \
			and roads.size() > 0 \
			and String(loaded_metadata.get("source_template_authority", "")) == "h3maped_exe_rng" \
			and String(loaded_metadata.get("production_ready_scope", "")) == STRICT_SCOPE \
			and int(loaded_scenario.get_start_contract().get("start_count", -1)) == 4 \
			and int(loaded_scenario.get_start_contract().get("start_town_count", -1)) == 4
	return {
		"ok": ok,
		"map_saved": save_map.get("ok", false),
		"scenario_saved": save_scenario.get("ok", false),
		"map_loaded": load_map.get("ok", false),
		"scenario_loaded": load_scenario.get("ok", false),
		"object_count": loaded_map.get_object_count() if loaded_map != null else 0,
		"road_count": roads.size(),
		"start_count": loaded_scenario.get_start_contract().get("start_count", -1) if loaded_scenario != null else -1,
	}

func _validate_generated_map_startup(service: Variant) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"10",
		"",
		"",
		4,
		"land",
		false,
		"homm3_medium",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", {"max_attempts": 1, "mode": "none"})
	if not bool(setup.get("ok", false)):
		return {"ok": false, "setup": setup}
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	var loaded_map: Dictionary = service.load_map_package(map_path)
	var loaded_document: Variant = loaded_map.get("map_document", null)
	var runtime_surface := _runtime_block_surface_summary(session, loaded_document) if session != null and loaded_document != null else {"ok": false}
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(scenario_path)
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session != null and session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	var ok := session != null \
			and bool(loaded_map.get("ok", false)) \
			and loaded_document != null \
			and String(setup.get("native_generation", {}).get("status", "")) == "h3maped_medium_validated_package_ready" \
			and String(package_startup.get("package_identity", {}).get("size_class_id", "")) == "homm3_medium" \
			and String(package_startup.get("package_stem", "")).begins_with("medium-") \
			and String(boundary.get("adoption_path", "")) == "native_rmg_generated_package_saved_loaded_from_disk" \
			and not bool(boundary.get("content_service_generated_draft", true)) \
			and int(runtime_surface.get("runtime_unblocked_required_tile_count", -1)) == 0 \
			and int(runtime_surface.get("session_guard_count", 0)) >= int(runtime_surface.get("package_guard_count", -1)) \
			and int(runtime_surface.get("session_connection_blocker_count", 0)) >= int(runtime_surface.get("package_connection_blocker_count", -1))
	return {
		"ok": ok,
		"setup_status": setup.get("native_generation", {}),
		"package_stem": package_startup.get("package_stem", ""),
		"scenario_id": setup.get("scenario_id", ""),
		"session_id": session.session_id if session != null else "",
		"runtime_block_surface": runtime_surface,
	}

func _runtime_block_surface_summary(session: Variant, map_document: Variant) -> Dictionary:
	var session_encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var session_map_objects: Array = session.overworld.get("map_objects", []) if session.overworld.get("map_objects", []) is Array else []
	var session_guard_count := 0
	for encounter in session_encounters:
		if encounter is Dictionary and String(encounter.get("kind", "")) == "guard":
			session_guard_count += 1
	var session_connection_blocker_count := 0
	for object in session_map_objects:
		if object is Dictionary and String(object.get("kind", "")) == "connection_blocker":
			session_connection_blocker_count += 1
	var package_guard_count := 0
	var package_connection_blocker_count := 0
	var guard_block_tile_count := 0
	var connection_blocker_block_tile_count := 0
	var runtime_unblocked_required_tiles := []
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", ""))
		if not (kind in ["guard", "connection_blocker"]):
			continue
		if kind == "guard":
			package_guard_count += 1
		else:
			package_connection_blocker_count += 1
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		for tile in block_tiles:
			if not (tile is Dictionary):
				continue
			var x := int(tile.get("x", -1))
			var y := int(tile.get("y", -1))
			if kind == "guard":
				guard_block_tile_count += 1
			else:
				connection_blocker_block_tile_count += 1
			if not OverworldRulesScript.tile_is_blocked(session, x, y):
				runtime_unblocked_required_tiles.append({
					"placement_id": String(object.get("placement_id", "")),
					"kind": kind,
					"x": x,
					"y": y,
					"level": int(tile.get("level", 0)),
				})
	return {
		"session_guard_count": session_guard_count,
		"session_connection_blocker_count": session_connection_blocker_count,
		"package_guard_count": package_guard_count,
		"package_connection_blocker_count": package_connection_blocker_count,
		"guard_block_tile_count": guard_block_tile_count,
		"connection_blocker_block_tile_count": connection_blocker_block_tile_count,
		"runtime_unblocked_required_tile_count": runtime_unblocked_required_tiles.size(),
		"runtime_unblocked_required_tiles": runtime_unblocked_required_tiles,
	}

func _medium_land_config(seed: String, player_count: int) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 72,
			"height": 72,
			"level_count": 1,
			"water_mode": "land",
			"size_class_id": "homm3_medium",
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
