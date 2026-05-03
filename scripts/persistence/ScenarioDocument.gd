extends RefCounted

const SCHEMA_ID := "aurelion_scenario_document"
const SCHEMA_VERSION := 1

var _scenario_id := ""
var _scenario_hash := ""
var _map_ref: Dictionary = {}
var _selection: Dictionary = {}
var _player_slots: Array = []
var _objectives: Dictionary = {}
var _script_hooks: Array = []
var _enemy_factions: Array = []
var _start_contract: Dictionary = {}

func _init(initial_state: Dictionary = {}) -> void:
	_scenario_id = String(initial_state.get("scenario_id", ""))
	_scenario_hash = String(initial_state.get("scenario_hash", ""))
	_map_ref = initial_state.get("map_ref", {}).duplicate(true) if initial_state.get("map_ref", {}) is Dictionary else {}
	_selection = initial_state.get("selection", {}).duplicate(true) if initial_state.get("selection", {}) is Dictionary else {}
	_player_slots = initial_state.get("player_slots", []).duplicate(true) if initial_state.get("player_slots", []) is Array else []
	_objectives = initial_state.get("objectives", {}).duplicate(true) if initial_state.get("objectives", {}) is Dictionary else {}
	_script_hooks = initial_state.get("script_hooks", []).duplicate(true) if initial_state.get("script_hooks", []) is Array else []
	_enemy_factions = initial_state.get("enemy_factions", []).duplicate(true) if initial_state.get("enemy_factions", []) is Array else []
	_start_contract = initial_state.get("start_contract", {}).duplicate(true) if initial_state.get("start_contract", {}) is Dictionary else {}

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
	return _player_slots.duplicate(true)

func get_objectives() -> Dictionary:
	return _objectives.duplicate(true)

func get_script_hooks() -> Array:
	return _script_hooks.duplicate(true)

func get_enemy_factions() -> Array:
	return _enemy_factions.duplicate(true)

func get_start_contract() -> Dictionary:
	return _start_contract.duplicate(true)

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
		"metrics": {
			"player_slot_count": _player_slots.size(),
			"enemy_faction_count": _enemy_factions.size(),
		},
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
