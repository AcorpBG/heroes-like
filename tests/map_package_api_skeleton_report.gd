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

	var map_doc: Variant = service.create_map_document_stub({
		"map_id": "slice1_fixture_map",
		"map_hash": "sha256:slice1-map-placeholder",
		"width": 4,
		"height": 3,
		"level_count": 1,
		"metadata": {"display_name": "Slice 1 Fixture Map"},
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
	if bool(validation_result.get("ok", true)) or String(validation_result.get("error_code", "")) != "not_implemented":
		_fail("validate_map_document did not return the stable stub failure shape: %s" % JSON.stringify(validation_result))
		return
	if String(validation_result.get("report", {}).get("schema_id", "")) != "aurelion_map_validation_report":
		_fail("validate_map_document did not return a map validation report skeleton.")
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
	})])
	get_tree().quit(0)

func _create_service() -> Variant:
	if ClassDB.class_exists("MapPackageService"):
		return ClassDB.instantiate("MapPackageService")
	return MapPackageServiceScript.new()

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
