// MapPackageService.load_map_package and load_scenario_package
// (src/gdextension/src/map_package_service.cpp) and the methods of MapDocument
// and ScenarioDocument (map_document.cpp, scenario_document.cpp), ported under
// their names for a host without Godot.

#include "aurelion_rules/map_packages.hpp"

#include "aurelion_rules/compat/godot_json.hpp"
#include "aurelion_rules/port/gd.hpp"

#include <algorithm>

namespace aurelion::rules::map_packages {

namespace {

using state::Kind;
using state::State;
using state::Value;

constexpr const char *kMapPackageSchemaId = "aurelion_map_package";
constexpr const char *kMapSchemaId = "aurelion_map_document";
constexpr const char *kScenarioPackageSchemaId = "aurelion_scenario_package";
constexpr const char *kScenarioSchemaId = "aurelion_scenario_document";
// map_package_service.cpp's MAX_PACKAGE_FILE_BYTES and map_document.hpp's
// MAX_DIMENSION, MAX_LEVEL_COUNT and SCHEMA_VERSION.
constexpr size_t kMaxPackageFileBytes = size_t(256) * 1024 * 1024;
constexpr int32_t kMaxDimension = 256;
constexpr int32_t kMaxLevelCount = 2;
constexpr int32_t kSchemaVersion = 1;

Value new_dict(State &state) {
	return Value::of_ref(Kind::Dict, state.new_dict());
}

Value new_array(State &state) {
	return Value::of_ref(Kind::Array, state.new_array());
}

void put(State &state, const Value &dict, const char *key, const Value &value) {
	state.set(dict.ref, state.string(key), value);
}

Value get(const State &state, const Value &dict, const char *key, const Value &fallback) {
	uint32_t atom = 0;
	if (!state.find_atom(key, atom)) {
		return fallback;
	}
	return state.get(dict.ref, Value::str(atom), fallback);
}

// String(value) == expected.
bool text_is(const State &state, const Value &value, const char *expected) {
	return value.is_string_like() && state.text(value.ref) == expected;
}

// String(value), as a String.
Value text_value(State &state, const Value &value) {
	return Value::str(value.is_string_like() ? value.ref : gd::stringify(state, value));
}

// A String parameter of a bound method.
uint32_t string_arg(const Value *args, size_t count, size_t index, const char *method) {
	if (index >= count || !args[index].is_string_like()) {
		throw state::ScriptError(std::string("Invalid type in function '") + method + "': a String argument expected");
	}
	return args[index].ref;
}

// An int parameter of a bound method, with its default.
int64_t int_arg(const State &state, const Value *args, size_t count, size_t index, int64_t fallback) {
	return index < count ? gd::to_int(state, args[index]) : fallback;
}

// Dictionary(value) of a Variant: the Dictionary, or a new empty one.
Value dict_or_new(State &state, const Value &value) {
	return value.kind == Kind::Dict ? value : new_dict(state);
}

Value deep_copy(State &state, const Value &value) {
	return gd::duplicate_value(state, value, true);
}

// make_read_only_recursive.
void make_read_only_recursive(State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		const int64_t size = state.array_size(value.ref);
		for (int64_t index = 0; index < size; ++index) {
			make_read_only_recursive(state, state.at(value.ref, index));
		}
		state.array_node(value.ref).read_only = true;
	} else if (value.kind == Kind::Dict) {
		const state::ValueList values = state.dict(value.ref).values;
		for (const Value &item : values) {
			make_read_only_recursive(state, item);
		}
		state.dict_node(value.ref).read_only = true;
	}
}

// payload_dimension_in_range: an int or a float, whole, from 1 to maximum.
bool payload_dimension_in_range(const State &state, const Value &document, const char *key, const Value &fallback, int32_t maximum) {
	const Value value = get(state, document, key, fallback);
	double number = 0.0;
	if (value.kind == Kind::Int) {
		number = static_cast<double>(value.i);
	} else if (value.kind == Kind::Float) {
		number = value.f;
	} else {
		return false;
	}
	return number >= 1.0 && number <= double(maximum) && number == double(int64_t(number));
}

// MapDocument::assign_state, from a Dictionary holding the state's keys
// (configure's argument, or the package's document, which
// map_document_state_from_payload passes on key by key).
void assign_map_state(State &state, MapDocument &document, const Value &initial, const char *source_kind_fallback, bool copy_containers = true) {
	document.map_id = text_value(state, get(state, initial, "map_id", state.string("")));
	document.map_hash = text_value(state, get(state, initial, "map_hash", state.string("")));
	document.source_kind = text_value(state, get(state, initial, "source_kind", state.string(source_kind_fallback)));
	document.width = std::max<int32_t>(0, static_cast<int32_t>(gd::to_int(state, get(state, initial, "width", Value::of_int(0)))));
	document.height = std::max<int32_t>(0, static_cast<int32_t>(gd::to_int(state, get(state, initial, "height", Value::of_int(0)))));
	document.level_count = std::max<int32_t>(1, static_cast<int32_t>(gd::to_int(state, get(state, initial, "level_count", Value::of_int(1)))));
	document.metadata = dict_or_new(state, get(state, initial, "metadata", Value()));
	const auto copy = [&](const Value &value) { return copy_containers ? deep_copy(state, value) : value; };
	const Value terrain_layers = get(state, initial, "terrain_layers", Value());
	document.terrain_layers = terrain_layers.kind == Kind::Dict ? copy(terrain_layers) : new_dict(state);
	const Value route_graph = get(state, initial, "route_graph", Value());
	document.route_graph = route_graph.kind == Kind::Dict ? copy(route_graph) : new_dict(state);
	const Value objects = get(state, initial, "objects", Value());
	document.objects = objects.kind == Kind::Array ? copy(objects) : new_array(state);
	make_read_only_recursive(state, document.objects);
}

// ScenarioDocument::configure.
void assign_scenario_state(State &state, ScenarioDocument &document, const Value &initial) {
	document.scenario_id = text_value(state, get(state, initial, "scenario_id", state.string("")));
	document.scenario_hash = text_value(state, get(state, initial, "scenario_hash", state.string("")));
	document.map_ref = dict_or_new(state, get(state, initial, "map_ref", Value()));
	document.selection = dict_or_new(state, get(state, initial, "selection", Value()));
	const auto array_copy = [&](const char *key) {
		const Value value = get(state, initial, key, Value());
		return value.kind == Kind::Array ? deep_copy(state, value) : new_array(state);
	};
	const auto dict_copy = [&](const char *key) {
		const Value value = get(state, initial, key, Value());
		return value.kind == Kind::Dict ? deep_copy(state, value) : new_dict(state);
	};
	document.player_slots = array_copy("player_slots");
	document.objectives = dict_copy("objectives");
	document.script_hooks = array_copy("script_hooks");
	document.enemy_factions = array_copy("enemy_factions");
	document.start_contract = dict_copy("start_contract");
}

Value not_implemented(State &state, const char *operation, const char *skeleton) {
	const Value result = new_dict(state);
	put(state, result, "ok", Value::of_bool(false));
	put(state, result, "status", state.string("fail"));
	put(state, result, "error_code", state.string("not_implemented"));
	put(state, result, "message", state.string(std::string(operation) + " is not implemented in the Slice 1 native " + skeleton + " skeleton."));
	put(state, result, "operation", state.string(operation));
	put(state, result, "recoverable", Value::of_bool(true));
	return result;
}

Value validation_summary(State &state, const char *schema_id, const Value &id, const Value &hash, const Value &metrics) {
	const Value result = new_dict(state);
	put(state, result, "schema_id", state.string(schema_id));
	put(state, result, "schema_version", Value::of_int(1));
	put(state, result, "document_id", id);
	put(state, result, "document_hash", hash);
	put(state, result, "status", state.string("not_implemented"));
	put(state, result, "failure_count", Value::of_int(0));
	put(state, result, "warning_count", Value::of_int(0));
	put(state, result, "failures", new_array(state));
	put(state, result, "warnings", new_array(state));
	put(state, result, "metrics", metrics);
	return result;
}

int64_t tile_count(const MapDocument &document) {
	return int64_t(document.width) * int64_t(document.height) * int64_t(document.level_count);
}

const char *const kMapDocumentMethods[] = {
	"configure", "get_schema_version", "get_map_id", "get_map_hash", "get_source_kind", "get_width", "get_height",
	"get_level_count", "get_tile_count", "get_metadata", "get_terrain_layer_ids", "get_tile_layer_u16",
	"get_terrain_layers", "get_object_count", "get_objects", "get_object_by_index", "get_object_by_placement_id",
	"get_objects_in_rect", "get_route_graph", "get_validation_summary", "to_legacy_scenario_record_patch",
	"to_legacy_terrain_layers_record",
};

const char *const kScenarioDocumentMethods[] = {
	"configure", "get_schema_version", "get_scenario_id", "get_scenario_hash", "get_map_ref", "get_selection",
	"get_player_slots", "get_objectives", "get_script_hooks", "get_enemy_factions", "get_start_contract",
	"to_legacy_scenario_record", "get_validation_summary",
};

template <size_t N>
bool listed(const char *const (&names)[N], std::string_view method) {
	return std::find(std::begin(names), std::end(names), method) != std::end(names);
}

Value package_operation_report(State &state, const char *operation, const char *status, const std::string &path, const Value &failures) {
	const Value report = new_dict(state);
	put(state, report, "schema_id", state.string("aurelion_package_operation_report"));
	put(state, report, "schema_version", Value::of_int(1));
	put(state, report, "operation", state.string(operation));
	put(state, report, "status", state.string(status));
	put(state, report, "path", state.string(path));
	put(state, report, "failure_count", Value::of_int(state.array_size(failures.ref)));
	put(state, report, "warning_count", Value::of_int(0));
	put(state, report, "failures", failures);
	put(state, report, "warnings", new_array(state));
	return report;
}

} // namespace

bool read_package_dictionary(State &state, content::Files &files, const char *operation, const std::string &path, Value &package,
		Value &failure) {
	if (!files.exists(path)) {
		failure = package_failure(state, operation, path, "missing_package", "Package file does not exist.");
		return false;
	}
	std::string bytes;
	if (!files.read(path, bytes)) {
		failure = package_failure(state, operation, path, "open_failed", "Package file could not be opened for reading.");
		return false;
	}
	if (bytes.size() > kMaxPackageFileBytes) {
		failure = package_failure(state, operation, path, "package_too_large", "Package file is larger than any supported map package.");
		return false;
	}
	const compat::JsonParse parsed = compat::json_parse(state, bytes);
	if (parsed.error != 0) {
		failure = package_failure(state, operation, path, "invalid_package_json", "Package file could not be parsed.");
		return false;
	}
	if (parsed.data.kind != Kind::Dict) {
		failure = package_failure(state, operation, path, "invalid_package_root", "Package root must be a dictionary.");
		return false;
	}
	package = parsed.data;
	return true;
}

Value package_failure(State &state, const char *operation, const std::string &path, const char *code, const char *message) {
	const Value failure = new_dict(state);
	put(state, failure, "code", state.string(code));
	put(state, failure, "severity", state.string("fail"));
	put(state, failure, "path", state.string(operation));
	put(state, failure, "message", state.string(message));
	put(state, failure, "context", new_dict(state));
	const Value failures = new_array(state);
	state.append(failures.ref, failure);

	const Value result = new_dict(state);
	put(state, result, "ok", Value::of_bool(false));
	put(state, result, "status", state.string("fail"));
	put(state, result, "error_code", state.string(code));
	put(state, result, "message", state.string(message));
	put(state, result, "operation", state.string(operation));
	put(state, result, "path", state.string(path));
	put(state, result, "report", package_operation_report(state, operation, "fail", path, failures));
	put(state, result, "recoverable", Value::of_bool(true));
	return result;
}

// package_success: the payload (built for this result alone) with the result's
// fields after its own.
Value package_success(State &state, const char *operation, const std::string &path, const Value &payload) {
	put(state, payload, "ok", Value::of_bool(true));
	put(state, payload, "status", state.string("pass"));
	put(state, payload, "operation", state.string(operation));
	put(state, payload, "path", state.string(path));
	put(state, payload, "report", package_operation_report(state, operation, "pass", path, new_array(state)));
	return payload;
}

void configure_map_document(State &state, MapDocument &document, const Value &initial, bool copy_containers) {
	assign_map_state(state, document, initial, "test_fixture", copy_containers);
}

void configure_scenario_document(State &state, ScenarioDocument &document, const Value &initial) {
	assign_scenario_state(state, document, initial);
}

Value load_map_package(State &state, content::Files &files, const std::string &path, MapDocument &document, const Value &document_object) {
	const char *operation = "load_map_package";
	Value package;
	Value failure;
	if (!read_package_dictionary(state, files, operation, path, package, failure)) {
		return failure;
	}
	if (!text_is(state, get(state, package, "schema_id", state.string("")), kMapPackageSchemaId)) {
		return package_failure(state, operation, path, "wrong_package_schema", "Package is not an Aurelion map package.");
	}
	const Value payload_document = get(state, package, "document", Value());
	if (payload_document.kind != Kind::Dict) {
		return package_failure(state, operation, path, "missing_document", "Map package is missing its document payload.");
	}
	if (!text_is(state, get(state, payload_document, "schema_id", state.string("")), kMapSchemaId)) {
		return package_failure(state, operation, path, "wrong_document_schema", "Map package document schema is not supported.");
	}
	if (!payload_dimension_in_range(state, payload_document, "width", Value::of_int(0), kMaxDimension)
			|| !payload_dimension_in_range(state, payload_document, "height", Value::of_int(0), kMaxDimension)
			|| !payload_dimension_in_range(state, payload_document, "level_count", Value::of_int(1), kMaxLevelCount)) {
		return package_failure(state, operation, path, "invalid_map_dimensions",
				"Map package dimensions or level count are outside the supported range.");
	}
	assign_map_state(state, document, payload_document, "");
	const Value payload = new_dict(state);
	put(state, payload, "package", package);
	put(state, payload, "map_document", document_object);
	put(state, payload, "package_hash", get(state, package, "package_hash", state.string("")));
	put(state, payload, "map_ref", get(state, package, "map_ref", new_dict(state)));
	put(state, payload, "storage_policy", get(state, package, "storage_policy", state.string("")));
	return package_success(state, operation, path, payload);
}

Value load_scenario_package(State &state, content::Files &files, const std::string &path, ScenarioDocument &document,
		const Value &document_object) {
	const char *operation = "load_scenario_package";
	Value package;
	Value failure;
	if (!read_package_dictionary(state, files, operation, path, package, failure)) {
		return failure;
	}
	if (!text_is(state, get(state, package, "schema_id", state.string("")), kScenarioPackageSchemaId)) {
		return package_failure(state, operation, path, "wrong_package_schema", "Package is not an Aurelion scenario package.");
	}
	const Value payload_document = get(state, package, "document", Value());
	if (payload_document.kind != Kind::Dict) {
		return package_failure(state, operation, path, "missing_document", "Scenario package is missing its document payload.");
	}
	if (!text_is(state, get(state, payload_document, "schema_id", state.string("")), kScenarioSchemaId)) {
		return package_failure(state, operation, path, "wrong_document_schema", "Scenario package document schema is not supported.");
	}
	assign_scenario_state(state, document, payload_document);
	const Value payload = new_dict(state);
	put(state, payload, "package", package);
	put(state, payload, "scenario_document", document_object);
	put(state, payload, "package_hash", get(state, package, "package_hash", state.string("")));
	put(state, payload, "scenario_ref", get(state, package, "scenario_ref", new_dict(state)));
	put(state, payload, "storage_policy", get(state, package, "storage_policy", state.string("")));
	return package_success(state, operation, path, payload);
}

bool map_document_has_method(std::string_view method) {
	return listed(kMapDocumentMethods, method);
}

Value map_document_call(State &state, MapDocument &document, std::string_view method, const Value *args, size_t count) {
	if (method == "configure") {
		if (count < 1 || args[0].kind != Kind::Dict) {
			throw state::ScriptError("Invalid type in function 'configure': a Dictionary argument expected");
		}
		assign_map_state(state, document, args[0], "test_fixture");
		return Value();
	}
	if (method == "get_schema_version") {
		return Value::of_int(kSchemaVersion);
	}
	if (method == "get_map_id") {
		return document.map_id;
	}
	if (method == "get_map_hash") {
		return document.map_hash;
	}
	if (method == "get_source_kind") {
		return document.source_kind;
	}
	if (method == "get_width") {
		return Value::of_int(document.width);
	}
	if (method == "get_height") {
		return Value::of_int(document.height);
	}
	if (method == "get_level_count") {
		return Value::of_int(document.level_count);
	}
	if (method == "get_tile_count") {
		return Value::of_int(tile_count(document));
	}
	if (method == "get_metadata") {
		const Value result = deep_copy(state, document.metadata);
		put(state, result, "schema_id", state.string(kMapSchemaId));
		put(state, result, "schema_version", Value::of_int(kSchemaVersion));
		return result;
	}
	if (method == "get_terrain_layer_ids") {
		const uint32_t ids = gd::new_strings(state);
		const state::ValueList keys = state.dict(document.terrain_layers.ref).keys.list();
		for (const Value &key : keys) {
			const Value text = text_value(state, key);
			const std::string &name = state.text(text.ref);
			if (name == "schema_id" || name == "schema_version" || name == "terrain_id_by_code") {
				continue;
			}
			if (state.get(document.terrain_layers.ref, text, Value()).kind == Kind::Dict) {
				gd::packed_append_string(state, ids, text.ref);
			}
		}
		return gd::strings_value(ids);
	}
	if (method == "get_tile_layer_u16") {
		const uint32_t layer_id = string_arg(args, count, 0, "get_tile_layer_u16");
		const int64_t level = static_cast<int32_t>(int_arg(state, args, count, 1, 0));
		const uint32_t codes = gd::new_ints(state);
		const Value layer = state.get(document.terrain_layers.ref, Value::str(layer_id), Value());
		if (layer.kind != Kind::Dict) {
			return gd::ints_value(codes);
		}
		const Value levels = get(state, layer, "levels", Value());
		if (levels.kind != Kind::Array || level < 0 || level >= state.array_size(levels.ref)) {
			return gd::ints_value(codes);
		}
		const Value source = state.at(levels.ref, level);
		if (source.kind == Kind::PackedInt32) {
			return source;
		}
		if (source.kind == Kind::Array) {
			const int64_t size = state.array_size(source.ref);
			gd::packed_resize(state, codes, size);
			for (int64_t index = 0; index < size; ++index) {
				gd::packed_set(state, codes, index, static_cast<int32_t>(gd::to_int(state, state.at(source.ref, index))));
			}
		}
		return gd::ints_value(codes);
	}
	if (method == "get_terrain_layers") {
		return deep_copy(state, document.terrain_layers);
	}
	if (method == "get_object_count") {
		return Value::of_int(static_cast<int32_t>(state.array_size(document.objects.ref)));
	}
	if (method == "get_objects") {
		return document.objects;
	}
	if (method == "get_object_by_index") {
		const int64_t index = static_cast<int32_t>(int_arg(state, args, count, 0, 0));
		if (count < 1 || index < 0 || index >= state.array_size(document.objects.ref)) {
			return new_dict(state);
		}
		return deep_copy(state, dict_or_new(state, state.at(document.objects.ref, index)));
	}
	if (method == "get_object_by_placement_id") {
		const uint32_t placement_id = string_arg(args, count, 0, "get_object_by_placement_id");
		const int64_t size = state.array_size(document.objects.ref);
		for (int64_t index = 0; index < size; ++index) {
			const Value object = dict_or_new(state, state.at(document.objects.ref, index));
			const Value id = text_value(state, get(state, object, "placement_id", state.string("")));
			if (state.text(id.ref) == state.text(placement_id)) {
				return deep_copy(state, object);
			}
		}
		return new_dict(state);
	}
	if (method == "get_route_graph") {
		return deep_copy(state, document.route_graph);
	}
	if (method == "get_validation_summary") {
		const Value metrics = new_dict(state);
		put(state, metrics, "width", Value::of_int(document.width));
		put(state, metrics, "height", Value::of_int(document.height));
		put(state, metrics, "level_count", Value::of_int(document.level_count));
		put(state, metrics, "tile_count", Value::of_int(tile_count(document)));
		put(state, metrics, "object_count", Value::of_int(state.array_size(document.objects.ref)));
		return validation_summary(state, "aurelion_map_validation_report", document.map_id, document.map_hash, metrics);
	}
	if (method == "to_legacy_scenario_record_patch" || method == "to_legacy_terrain_layers_record") {
		return not_implemented(state, method == "to_legacy_scenario_record_patch" ? "to_legacy_scenario_record_patch" : "to_legacy_terrain_layers_record",
				"map document");
	}
	if (method == "get_objects_in_rect") {
		throw state::NotPorted("left out of the map document port: get_objects_in_rect (a Rect2i)");
	}
	throw state::ScriptError("Invalid call. Nonexistent function '" + std::string(method) + "' in base 'MapDocument'.");
}

bool scenario_document_has_method(std::string_view method) {
	return listed(kScenarioDocumentMethods, method);
}

Value scenario_document_call(State &state, ScenarioDocument &document, std::string_view method, const Value *args, size_t count) {
	if (method == "configure") {
		if (count < 1 || args[0].kind != Kind::Dict) {
			throw state::ScriptError("Invalid type in function 'configure': a Dictionary argument expected");
		}
		assign_scenario_state(state, document, args[0]);
		return Value();
	}
	if (method == "get_schema_version") {
		return Value::of_int(kSchemaVersion);
	}
	if (method == "get_scenario_id") {
		return document.scenario_id;
	}
	if (method == "get_scenario_hash") {
		return document.scenario_hash;
	}
	const std::pair<const char *, const Value *> copies[] = {
		{"get_map_ref", &document.map_ref},
		{"get_selection", &document.selection},
		{"get_player_slots", &document.player_slots},
		{"get_objectives", &document.objectives},
		{"get_script_hooks", &document.script_hooks},
		{"get_enemy_factions", &document.enemy_factions},
		{"get_start_contract", &document.start_contract},
	};
	for (const auto &copy : copies) {
		if (method == copy.first) {
			return deep_copy(state, *copy.second);
		}
	}
	if (method == "to_legacy_scenario_record") {
		return not_implemented(state, "to_legacy_scenario_record", "scenario document");
	}
	if (method == "get_validation_summary") {
		const Value metrics = new_dict(state);
		put(state, metrics, "player_slot_count", Value::of_int(state.array_size(document.player_slots.ref)));
		put(state, metrics, "enemy_faction_count", Value::of_int(state.array_size(document.enemy_factions.ref)));
		return validation_summary(state, "aurelion_scenario_validation_report", document.scenario_id, document.scenario_hash, metrics);
	}
	throw state::ScriptError("Invalid call. Nonexistent function '" + std::string(method) + "' in base 'ScenarioDocument'.");
}

} // namespace aurelion::rules::map_packages
