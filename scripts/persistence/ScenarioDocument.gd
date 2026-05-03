class_name ScenarioDocument
extends RefCounted

const SCHEMA_ID := "aurelion_scenario_document"
const SCHEMA_VERSION := 1

var _scenario_id := ""
var _scenario_hash := ""
var _map_ref: Dictionary = {}
var _selection: Dictionary = {}

func _init(initial_state: Dictionary = {}) -> void:
	_scenario_id = String(initial_state.get("scenario_id", ""))
	_scenario_hash = String(initial_state.get("scenario_hash", ""))
	_map_ref = initial_state.get("map_ref", {}).duplicate(true) if initial_state.get("map_ref", {}) is Dictionary else {}
	_selection = initial_state.get("selection", {}).duplicate(true) if initial_state.get("selection", {}) is Dictionary else {}

func get_schema_version() -> int:
	return SCHEMA_VERSION

func get_scenario_id() -> String:
	return _scenario_id

func get_scenario_hash() -> String:
	return _scenario_hash

func get_map_ref() -> Dictionary:
	return _map_ref.duplicate(true)

func get_selection() -> Dictionary:
	return _selection.duplicate(true)

func get_player_slots() -> Array:
	return []

func get_objectives() -> Dictionary:
	return _not_implemented("get_objectives")

func get_script_hooks() -> Array:
	return []

func get_enemy_factions() -> Array:
	return []

func get_start_contract() -> Dictionary:
	return _not_implemented("get_start_contract")

func to_legacy_scenario_record(map_document: Variant) -> Dictionary:
	return _not_implemented("to_legacy_scenario_record")

func get_validation_summary() -> Dictionary:
	return {
		"schema_id": "aurelion_scenario_validation_report",
		"schema_version": 1,
		"document_id": _scenario_id,
		"document_hash": _scenario_hash,
		"status": "not_implemented",
		"failure_count": 0,
		"warning_count": 0,
		"failures": [],
		"warnings": [],
		"metrics": {},
	}

func _not_implemented(operation: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": "not_implemented",
		"message": "%s is not implemented in the Slice 1 scenario document skeleton." % operation,
		"operation": operation,
		"recoverable": true,
	}
