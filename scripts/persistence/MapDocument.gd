extends RefCounted

const SCHEMA_ID := "aurelion_map_document"
const SCHEMA_VERSION := 1

var _map_id := ""
var _map_hash := ""
var _source_kind := "test_fixture"
var _width := 0
var _height := 0
var _level_count := 1
var _metadata: Dictionary = {}
var _objects: Array = []

func _init(initial_state: Dictionary = {}) -> void:
	_map_id = String(initial_state.get("map_id", ""))
	_map_hash = String(initial_state.get("map_hash", ""))
	_source_kind = String(initial_state.get("source_kind", "test_fixture"))
	_width = max(0, int(initial_state.get("width", 0)))
	_height = max(0, int(initial_state.get("height", 0)))
	_level_count = max(1, int(initial_state.get("level_count", 1)))
	_metadata = initial_state.get("metadata", {}).duplicate(true) if initial_state.get("metadata", {}) is Dictionary else {}
	_objects = initial_state.get("objects", []).duplicate(true) if initial_state.get("objects", []) is Array else []

func get_schema_version() -> int:
	return SCHEMA_VERSION

func get_map_id() -> String:
	return _map_id

func get_map_hash() -> String:
	return _map_hash

func get_source_kind() -> String:
	return _source_kind

func get_width() -> int:
	return _width

func get_height() -> int:
	return _height

func get_level_count() -> int:
	return _level_count

func get_tile_count() -> int:
	return _width * _height * _level_count

func get_metadata() -> Dictionary:
	var metadata := _metadata.duplicate(true)
	metadata["schema_id"] = SCHEMA_ID
	metadata["schema_version"] = SCHEMA_VERSION
	return metadata

func get_terrain_layer_ids() -> PackedStringArray:
	return PackedStringArray()

func get_tile_layer_u16(layer_id: String, level: int = 0) -> PackedInt32Array:
	return PackedInt32Array()

func get_object_count() -> int:
	return _objects.size()

func get_object_by_index(index: int) -> Dictionary:
	if index < 0 or index >= _objects.size() or not (_objects[index] is Dictionary):
		return {}
	return _objects[index].duplicate(true)

func get_object_by_placement_id(placement_id: String) -> Dictionary:
	for object in _objects:
		if object is Dictionary and String(object.get("placement_id", "")) == placement_id:
			return object.duplicate(true)
	return {}

func get_objects_in_rect(rect: Rect2i, level: int = 0) -> Array:
	var result := []
	for object in _objects:
		if not (object is Dictionary):
			continue
		if int(object.get("level", 0)) != level:
			continue
		var point := Vector2i(int(object.get("x", 0)), int(object.get("y", 0)))
		if rect.has_point(point):
			result.append(object.duplicate(true))
	return result

func get_route_graph() -> Dictionary:
	return _not_implemented("get_route_graph")

func get_validation_summary() -> Dictionary:
	return {
		"schema_id": "aurelion_map_validation_report",
		"schema_version": 1,
		"document_id": _map_id,
		"document_hash": _map_hash,
		"status": "not_implemented",
		"failure_count": 0,
		"warning_count": 0,
		"failures": [],
		"warnings": [],
		"metrics": {
			"width": _width,
			"height": _height,
			"level_count": _level_count,
			"tile_count": get_tile_count(),
			"object_count": get_object_count(),
		},
	}

func to_legacy_scenario_record_patch() -> Dictionary:
	return _not_implemented("to_legacy_scenario_record_patch")

func to_legacy_terrain_layers_record() -> Dictionary:
	return _not_implemented("to_legacy_terrain_layers_record")

func _not_implemented(operation: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": "not_implemented",
		"message": "%s is not implemented in the Slice 1 map document skeleton." % operation,
		"operation": operation,
		"recoverable": true,
	}
