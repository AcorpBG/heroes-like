class_name MapPackageService
extends RefCounted

const MapDocumentScript = preload("res://scripts/persistence/MapDocument.gd")
const ScenarioDocumentScript = preload("res://scripts/persistence/ScenarioDocument.gd")

const API_ID := "aurelion_map_package_api"
const API_VERSION := "0.1.0"
const PACKAGE_SCHEMA_VERSION := 1
const MAP_SCHEMA_ID := "aurelion_map_document"
const SCENARIO_SCHEMA_ID := "aurelion_scenario_document"
const MAP_PACKAGE_EXTENSION := ".amap"
const SCENARIO_PACKAGE_EXTENSION := ".ascenario"
const BINDING_KIND := "gdscript_compatibility_shim"

const CAPABILITIES := [
	"api_metadata",
	"typed_map_document_stub",
	"typed_scenario_document_stub",
	"stable_not_implemented_errors",
	"headless_binding_smoke",
]

func get_api_version() -> String:
	return API_VERSION

func get_api_metadata() -> Dictionary:
	return {
		"ok": true,
		"api_id": API_ID,
		"api_version": API_VERSION,
		"binding_kind": BINDING_KIND,
		"native_extension_loaded": false,
		"map_schema_id": MAP_SCHEMA_ID,
		"scenario_schema_id": SCENARIO_SCHEMA_ID,
		"package_schema_version": PACKAGE_SCHEMA_VERSION,
		"map_package_extension": MAP_PACKAGE_EXTENSION,
		"scenario_package_extension": SCENARIO_PACKAGE_EXTENSION,
		"capabilities": get_capabilities(),
		"status": "skeleton",
	}

func get_capabilities() -> PackedStringArray:
	return PackedStringArray(CAPABILITIES)

func get_schema_ids() -> Dictionary:
	return {
		"map_document": MAP_SCHEMA_ID,
		"scenario_document": SCENARIO_SCHEMA_ID,
		"map_validation_report": "aurelion_map_validation_report",
		"scenario_validation_report": "aurelion_scenario_validation_report",
	}

func create_map_document_stub(initial_state: Dictionary = {}) -> Variant:
	return MapDocumentScript.new(initial_state)

func create_scenario_document_stub(initial_state: Dictionary = {}) -> Variant:
	return ScenarioDocumentScript.new(initial_state)

func load_map_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_map_package", "not_implemented", path, options)

func load_scenario_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_scenario_package", "not_implemented", path, options)

func validate_map_document(map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_map_document", "aurelion_map_validation_report")

func validate_scenario_document(scenario_document: Variant, map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report")

func save_map_package(map_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_map_package", "not_implemented", path, options)

func save_scenario_package(scenario_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_scenario_package", "not_implemented", path, options)

func migrate_map_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_map_package", "not_implemented", source_path, options)

func migrate_scenario_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_scenario_package", "not_implemented", source_path, options)

func convert_legacy_scenario_record(scenario_record: Dictionary, terrain_layers_record: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("convert_legacy_scenario_record", "not_implemented", "", options)

func convert_generated_payload(generated_map: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("convert_generated_payload", "not_implemented", "", options)

func compute_document_hash(document: Variant, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("compute_document_hash", "not_implemented", "", options)

func inspect_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("inspect_package", "not_implemented", path, options)

func _validation_not_implemented(operation: String, report_schema_id: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": "not_implemented",
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"report": {
			"schema_id": report_schema_id,
			"schema_version": 1,
			"status": "fail",
			"failure_count": 1,
			"warning_count": 0,
			"failures": [{
				"code": "not_implemented",
				"severity": "fail",
				"path": operation,
				"message": "Validation is stubbed in Slice 1.",
				"context": {},
			}],
			"warnings": [],
			"metrics": {},
		},
		"recoverable": true,
	}

func _not_implemented(operation: String, error_code: String, path: String, options: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": error_code,
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"operation": operation,
		"path": path,
		"report": {
			"schema_id": "aurelion_package_operation_report",
			"schema_version": 1,
			"status": "fail",
			"failures": [{
				"code": error_code,
				"severity": "fail",
				"path": operation,
				"message": "Package conversion/read/write is intentionally unavailable in Slice 1.",
				"context": {"options_keys": options.keys()},
			}],
			"warnings": [],
		},
		"recoverable": true,
	}
