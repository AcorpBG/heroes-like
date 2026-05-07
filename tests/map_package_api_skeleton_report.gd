extends Node

const REPORT_ID := "MAP_PACKAGE_API_SKELETON_REPORT"
const MapPackageServiceScript = preload("res://scripts/persistence/MapPackageService.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var service: Variant = _create_service()
	var metadata: Dictionary = service.get_api_metadata()
	if not bool(metadata.get("ok", false)):
		_fail("API metadata did not return ok=true: %s" % JSON.stringify(metadata))
		return
	if String(metadata.get("api_id", "")) != "aurelion_map_package_api":
		_fail("Unexpected API id: %s" % JSON.stringify(metadata))
		return
	if String(metadata.get("api_version", "")) != "0.1.0":
		_fail("Unexpected API version: %s" % JSON.stringify(metadata))
		return
	if String(metadata.get("binding_kind", "")) != "native_gdextension":
		_fail("Unexpected binding kind: %s" % JSON.stringify(metadata))
		return
	if not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension did not load: %s" % JSON.stringify(metadata))
		return

	var capabilities: PackedStringArray = service.get_capabilities()
	for required in ["api_metadata", "typed_map_document_stub", "typed_scenario_document_stub", "stable_not_implemented_errors"]:
		if not capabilities.has(required):
			_fail("Missing capability %s in %s." % [required, JSON.stringify(Array(capabilities))])
			return

	if not _assert_gdscript_fallback_surface_underground_terrain_policy():
		return

	var terrain_codes := []
	for _index in range(12):
		terrain_codes.append(1)
	var map_doc: Variant = service.create_map_document_stub({
		"map_id": "slice1_fixture_map",
		"map_hash": "sha256:slice1-map-placeholder",
		"width": 4,
		"height": 3,
		"level_count": 1,
		"metadata": {"display_name": "Slice 1 Fixture Map"},
		"terrain_layers": {
			"base": {"levels": [terrain_codes]},
			"roads": [{"id": "fixture_road", "tile_count": 2}],
		},
		"objects": [
			{"placement_id": "fixture_object_1", "object_id": "object_fixture_marker", "x": 1, "y": 1, "level": 0},
		],
		"route_graph": {"nodes": [], "edges": []},
	})
	if map_doc.get_schema_version() != 1 or map_doc.get_map_id() != "slice1_fixture_map":
		_fail("MapDocument identity getters failed.")
		return
	if map_doc.get_tile_count() != 12:
		_fail("MapDocument tile count was not stable.")
		return

	var scenario_doc: Variant = service.create_scenario_document_stub({
		"scenario_id": "slice1_fixture_scenario",
		"scenario_hash": "sha256:slice1-scenario-placeholder",
		"map_ref": {"map_id": map_doc.get_map_id(), "map_hash": map_doc.get_map_hash(), "map_schema_version": map_doc.get_schema_version()},
		"selection": {"title": "Slice 1 Fixture Scenario"},
		"player_slots": [{"slot_index": 0, "controller": "human", "faction_id": "faction_embercourt"}],
		"objectives": {"primary": "survive_fixture_validation"},
	})
	if scenario_doc.get_schema_version() != 1 or scenario_doc.get_scenario_id() != "slice1_fixture_scenario":
		_fail("ScenarioDocument identity getters failed.")
		return

	var fixture_path := "res://maps/api_skeleton_fixture.amap"
	var save_result: Dictionary = service.save_map_package(map_doc, fixture_path)
	if not bool(save_result.get("ok", false)):
		_fail("save_map_package did not write a package: %s" % JSON.stringify(save_result))
		return
	var load_result: Dictionary = service.load_map_package(fixture_path)
	if not bool(load_result.get("ok", false)):
		_fail("load_map_package did not load the saved package: %s" % JSON.stringify(load_result))
		return
	var loaded_map: Variant = load_result.get("map_document", null)
	if loaded_map == null or loaded_map.get_map_id() != map_doc.get_map_id() or loaded_map.get_tile_count() != map_doc.get_tile_count():
		_fail("Loaded MapDocument did not preserve identity/dimensions.")
		return
	DirAccess.remove_absolute(fixture_path)

	var validation_result: Dictionary = service.validate_map_document(map_doc)
	if not bool(validation_result.get("ok", false)) or String(validation_result.get("status", "")) != "pass":
		_fail("validate_map_document did not pass a structurally valid map: %s" % JSON.stringify(validation_result))
		return
	if String(validation_result.get("report", {}).get("schema_id", "")) != "aurelion_map_validation_report":
		_fail("validate_map_document did not return a map validation report.")
		return
	if int(validation_result.get("report", {}).get("metrics", {}).get("terrain_layer_count", 0)) <= 0:
		_fail("validate_map_document did not report terrain layer metrics: %s" % JSON.stringify(validation_result))
		return

	var bad_map: Variant = service.create_map_document_stub({
		"map_id": "bad_fixture_map",
		"map_hash": "sha256:bad-map-placeholder",
		"width": 4,
		"height": 3,
		"level_count": 1,
		"terrain_layers": {
			"base": {"levels": [[1, 2]]},
			"roads": [{"id": "bad_road", "tile_count": 0}],
		},
		"objects": [
			{"placement_id": "bad_object", "x": 99, "y": 99, "level": 0},
			{"placement_id": "bad_object", "x": 1, "y": 1, "level": 0},
		],
	})
	var bad_validation: Dictionary = service.validate_map_document(bad_map)
	if bool(bad_validation.get("ok", true)) or String(bad_validation.get("status", "")) != "fail":
		_fail("validate_map_document did not reject an invalid map: %s" % JSON.stringify(bad_validation))
		return
	if int(bad_validation.get("report", {}).get("failure_count", 0)) < 4:
		_fail("invalid map validation did not report concrete failures: %s" % JSON.stringify(bad_validation))
		return
	var bad_map_codes := _failure_codes(bad_validation)
	for required_code in ["terrain_layer_tile_count_mismatch", "invalid_road_tile_count", "object_out_of_bounds", "duplicate_object_placement_id"]:
		if not bad_map_codes.has(required_code):
			_fail("invalid map validation missed %s: %s" % [required_code, JSON.stringify(bad_validation)])
			return

	var null_map_validation: Dictionary = service.validate_map_document(null)
	if bool(null_map_validation.get("ok", true)) or not _failure_codes(null_map_validation).has("missing_map_document"):
		_fail("validate_map_document did not reject a null map document: %s" % JSON.stringify(null_map_validation))
		return

	var scenario_validation: Dictionary = service.validate_scenario_document(scenario_doc, map_doc)
	if not bool(scenario_validation.get("ok", false)) or String(scenario_validation.get("status", "")) != "pass":
		_fail("validate_scenario_document did not pass a structurally valid scenario/map pair: %s" % JSON.stringify(scenario_validation))
		return
	if int(scenario_validation.get("report", {}).get("metrics", {}).get("objective_key_count", -1)) <= 0:
		_fail("validate_scenario_document did not report objective metrics: %s" % JSON.stringify(scenario_validation))
		return

	var bad_scenario: Variant = service.create_scenario_document_stub({
		"scenario_id": "bad_fixture_scenario",
		"scenario_hash": "sha256:bad-scenario-placeholder",
		"map_ref": {"map_id": "different_map", "map_hash": map_doc.get_map_hash()},
		"player_slots": [{"slot_index": 0}],
	})
	var bad_scenario_validation: Dictionary = service.validate_scenario_document(bad_scenario, map_doc)
	if bool(bad_scenario_validation.get("ok", true)) or String(bad_scenario_validation.get("status", "")) != "fail":
		_fail("validate_scenario_document did not reject a mismatched map_ref: %s" % JSON.stringify(bad_scenario_validation))
		return
	if not _failure_codes(bad_scenario_validation).has("map_ref_id_mismatch"):
		_fail("bad scenario validation did not report map_ref_id_mismatch: %s" % JSON.stringify(bad_scenario_validation))
		return

	var null_scenario_validation: Dictionary = service.validate_scenario_document(null, map_doc)
	if bool(null_scenario_validation.get("ok", true)) or not _failure_codes(null_scenario_validation).has("missing_scenario_document"):
		_fail("validate_scenario_document did not reject a null scenario document: %s" % JSON.stringify(null_scenario_validation))
		return

	var missing_map_validation: Dictionary = service.validate_scenario_document(scenario_doc, null)
	if bool(missing_map_validation.get("ok", true)) or not _failure_codes(missing_map_validation).has("missing_map_document"):
		_fail("validate_scenario_document did not reject a missing referenced map document: %s" % JSON.stringify(missing_map_validation))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"api_version": metadata.get("api_version", ""),
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", true),
		"capabilities": Array(capabilities),
		"map_schema_version": map_doc.get_schema_version(),
		"scenario_schema_version": scenario_doc.get_schema_version(),
		"saved_package_path": fixture_path,
		"loaded_package_hash": load_result.get("package_hash", ""),
		"map_validation_status": validation_result.get("status", ""),
		"scenario_validation_status": scenario_validation.get("status", ""),
		"invalid_map_failure_count": bad_validation.get("report", {}).get("failure_count", 0),
		"invalid_scenario_failure_count": bad_scenario_validation.get("report", {}).get("failure_count", 0),
		"null_map_validation_status": null_map_validation.get("status", ""),
		"null_scenario_validation_status": null_scenario_validation.get("status", ""),
		"missing_map_validation_status": missing_map_validation.get("status", ""),
	})])
	get_tree().quit(0)

func _assert_gdscript_fallback_surface_underground_terrain_policy() -> bool:
	var fallback_service := MapPackageServiceScript.new()
	var surface_config := {
		"seed": "gdscript-fallback-surface-underground-policy-10184",
		"size": {"width": 12, "height": 10, "level_count": 1, "water_mode": "land"},
		"profile": {
			"id": "gdscript_fallback_surface_policy",
			"terrain_ids": ["grass", "dirt", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw"],
		},
	}
	var surface: Dictionary = fallback_service.generate_random_map(surface_config)
	if not bool(surface.get("ok", false)):
		_fail("GDScript fallback surface terrain policy generation failed: %s" % JSON.stringify(surface))
		return false
	var surface_grid: Dictionary = surface.get("terrain_grid", {}) if surface.get("terrain_grid", {}) is Dictionary else {}
	var surface_counts: Dictionary = surface_grid.get("terrain_counts", {}) if surface_grid.get("terrain_counts", {}) is Dictionary else {}
	if int(surface_counts.get("underground", 0)) != 0:
		_fail("GDScript fallback surface-only map materialized underground terrain: %s" % JSON.stringify(surface_counts))
		return false
	if String(surface_grid.get("underground_terrain_policy", "")) != "not_materialized_for_surface_only_maps":
		_fail("GDScript fallback surface-only map missed terrain policy metadata: %s" % JSON.stringify(surface_grid))
		return false

	var two_level_config := surface_config.duplicate(true)
	two_level_config["seed"] = "gdscript-fallback-two-level-underground-policy-10184"
	two_level_config["size"] = surface_config.get("size", {}).duplicate(true)
	two_level_config["size"]["level_count"] = 2
	var two_level: Dictionary = fallback_service.generate_random_map(two_level_config)
	if not bool(two_level.get("ok", false)):
		_fail("GDScript fallback two-level terrain policy generation failed: %s" % JSON.stringify(two_level))
		return false
	var two_level_grid: Dictionary = two_level.get("terrain_grid", {}) if two_level.get("terrain_grid", {}) is Dictionary else {}
	var levels: Array = two_level_grid.get("levels", []) if two_level_grid.get("levels", []) is Array else []
	if levels.size() != 2:
		_fail("GDScript fallback two-level map did not materialize two levels: %s" % JSON.stringify(two_level_grid))
		return false
	var level0: Dictionary = levels[0] if levels[0] is Dictionary else {}
	var level1: Dictionary = levels[1] if levels[1] is Dictionary else {}
	var level0_counts: Dictionary = level0.get("terrain_counts", {}) if level0.get("terrain_counts", {}) is Dictionary else {}
	var level1_counts: Dictionary = level1.get("terrain_counts", {}) if level1.get("terrain_counts", {}) is Dictionary else {}
	if int(level0_counts.get("underground", 0)) != 0:
		_fail("GDScript fallback two-level map used underground terrain on level 0: %s" % JSON.stringify(level0_counts))
		return false
	if int(level1_counts.get("underground", 0)) != 12 * 10:
		_fail("GDScript fallback two-level map did not reserve underground terrain for level 1: %s" % JSON.stringify(level1_counts))
		return false
	return true

func _create_service() -> Variant:
	if ClassDB.class_exists("MapPackageService"):
		return ClassDB.instantiate("MapPackageService")
	return MapPackageServiceScript.new()

func _failure_codes(validation_result: Dictionary) -> Dictionary:
	var result := {}
	var report: Dictionary = validation_result.get("report", {}) if validation_result.get("report", {}) is Dictionary else {}
	var failures: Array = report.get("failures", []) if report.get("failures", []) is Array else []
	for failure in failures:
		if failure is Dictionary:
			result[String(failure.get("code", ""))] = true
	return result

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
