#include "map_document.hpp"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>

using namespace godot;

namespace {

Dictionary not_implemented(const String &operation) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + String(" is not implemented in the Slice 1 native map document skeleton.");
	result["operation"] = operation;
	result["recoverable"] = true;
	return result;
}

} // namespace

void MapDocument::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "initial_state"), &MapDocument::configure);
	ClassDB::bind_method(D_METHOD("get_schema_version"), &MapDocument::get_schema_version);
	ClassDB::bind_method(D_METHOD("get_map_id"), &MapDocument::get_map_id);
	ClassDB::bind_method(D_METHOD("get_map_hash"), &MapDocument::get_map_hash);
	ClassDB::bind_method(D_METHOD("get_source_kind"), &MapDocument::get_source_kind);
	ClassDB::bind_method(D_METHOD("get_width"), &MapDocument::get_width);
	ClassDB::bind_method(D_METHOD("get_height"), &MapDocument::get_height);
	ClassDB::bind_method(D_METHOD("get_level_count"), &MapDocument::get_level_count);
	ClassDB::bind_method(D_METHOD("get_tile_count"), &MapDocument::get_tile_count);
	ClassDB::bind_method(D_METHOD("get_metadata"), &MapDocument::get_metadata);
	ClassDB::bind_method(D_METHOD("get_terrain_layer_ids"), &MapDocument::get_terrain_layer_ids);
	ClassDB::bind_method(D_METHOD("get_tile_layer_u16", "layer_id", "level"), &MapDocument::get_tile_layer_u16, DEFVAL(0));
	ClassDB::bind_method(D_METHOD("get_object_count"), &MapDocument::get_object_count);
	ClassDB::bind_method(D_METHOD("get_object_by_index", "index"), &MapDocument::get_object_by_index);
	ClassDB::bind_method(D_METHOD("get_object_by_placement_id", "placement_id"), &MapDocument::get_object_by_placement_id);
	ClassDB::bind_method(D_METHOD("get_objects_in_rect", "rect", "level"), &MapDocument::get_objects_in_rect, DEFVAL(0));
	ClassDB::bind_method(D_METHOD("get_route_graph"), &MapDocument::get_route_graph);
	ClassDB::bind_method(D_METHOD("get_validation_summary"), &MapDocument::get_validation_summary);
	ClassDB::bind_method(D_METHOD("to_legacy_scenario_record_patch"), &MapDocument::to_legacy_scenario_record_patch);
	ClassDB::bind_method(D_METHOD("to_legacy_terrain_layers_record"), &MapDocument::to_legacy_terrain_layers_record);
}

void MapDocument::configure(Dictionary initial_state) {
	map_id = String(initial_state.get("map_id", ""));
	map_hash = String(initial_state.get("map_hash", ""));
	source_kind = String(initial_state.get("source_kind", "test_fixture"));
	width = std::max(0, int32_t(initial_state.get("width", 0)));
	height = std::max(0, int32_t(initial_state.get("height", 0)));
	level_count = std::max(1, int32_t(initial_state.get("level_count", 1)));
	metadata = initial_state.get("metadata", Dictionary());
	Variant objects_value = initial_state.get("objects", Variant());
	objects = objects_value.get_type() == Variant::ARRAY ? Array(objects_value).duplicate(true) : Array();
}

int32_t MapDocument::get_schema_version() const { return SCHEMA_VERSION; }
String MapDocument::get_map_id() const { return map_id; }
String MapDocument::get_map_hash() const { return map_hash; }
String MapDocument::get_source_kind() const { return source_kind; }
int32_t MapDocument::get_width() const { return width; }
int32_t MapDocument::get_height() const { return height; }
int32_t MapDocument::get_level_count() const { return level_count; }
int32_t MapDocument::get_tile_count() const { return width * height * level_count; }

Dictionary MapDocument::get_metadata() const {
	Dictionary result = metadata.duplicate(true);
	result["schema_id"] = "aurelion_map_document";
	result["schema_version"] = SCHEMA_VERSION;
	return result;
}

PackedStringArray MapDocument::get_terrain_layer_ids() const { return PackedStringArray(); }
PackedInt32Array MapDocument::get_tile_layer_u16(String layer_id, int32_t level) const { return PackedInt32Array(); }
int32_t MapDocument::get_object_count() const { return objects.size(); }
Dictionary MapDocument::get_object_by_index(int32_t index) const {
	if (index < 0 || index >= objects.size()) {
		return Dictionary();
	}
	return Dictionary(objects[index]).duplicate(true);
}
Dictionary MapDocument::get_object_by_placement_id(String placement_id) const {
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = objects[index];
		if (String(object.get("placement_id", "")) == placement_id) {
			return object.duplicate(true);
		}
	}
	return Dictionary();
}
Array MapDocument::get_objects_in_rect(Rect2i rect, int32_t level) const {
	Array result;
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = objects[index];
		if (int32_t(object.get("level", 0)) != level) {
			continue;
		}
		const int32_t x = int32_t(object.get("x", 0));
		const int32_t y = int32_t(object.get("y", 0));
		if (x >= rect.position.x && y >= rect.position.y && x < rect.position.x + rect.size.x && y < rect.position.y + rect.size.y) {
			result.append(object.duplicate(true));
		}
	}
	return result;
}
Dictionary MapDocument::get_route_graph() const { return not_implemented("get_route_graph"); }

Dictionary MapDocument::get_validation_summary() const {
	Dictionary metrics;
	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = get_tile_count();
	metrics["object_count"] = get_object_count();

	Dictionary result;
	result["schema_id"] = "aurelion_map_validation_report";
	result["schema_version"] = 1;
	result["document_id"] = map_id;
	result["document_hash"] = map_hash;
	result["status"] = "not_implemented";
	result["failure_count"] = 0;
	result["warning_count"] = 0;
	result["failures"] = Array();
	result["warnings"] = Array();
	result["metrics"] = metrics;
	return result;
}

Dictionary MapDocument::to_legacy_scenario_record_patch() const { return not_implemented("to_legacy_scenario_record_patch"); }
Dictionary MapDocument::to_legacy_terrain_layers_record() const { return not_implemented("to_legacy_terrain_layers_record"); }
