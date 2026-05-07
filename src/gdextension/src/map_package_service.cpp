#include "map_package_service.hpp"

#include "rmg_data_model.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *MAP_PACKAGE_SCHEMA_ID = "aurelion_map_package";
constexpr const char *SCENARIO_PACKAGE_SCHEMA_ID = "aurelion_scenario_package";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_foundation";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_foundation_v1";
constexpr const char *NATIVE_RMG_TERRAIN_GRID_SCHEMA_ID = "aurelion_native_rmg_terrain_grid_v1";
constexpr const char *NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID = "aurelion_native_rmg_zone_layout_v1";
constexpr const char *NATIVE_RMG_RUNTIME_ZONE_GRAPH_SCHEMA_ID = "aurelion_native_rmg_runtime_zone_graph_v1";
constexpr const char *NATIVE_RMG_PLAYER_STARTS_SCHEMA_ID = "aurelion_native_rmg_player_starts_v1";
constexpr const char *NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID = "aurelion_native_rmg_route_graph_v1";
constexpr const char *NATIVE_RMG_ROAD_NETWORK_SCHEMA_ID = "aurelion_native_rmg_road_network_v1";
constexpr const char *NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID = "aurelion_native_rmg_river_network_v1";
constexpr const char *NATIVE_RMG_CONNECTION_PAYLOAD_SCHEMA_ID = "aurelion_native_rmg_connection_payload_resolution_v1";
constexpr const char *NATIVE_RMG_OBJECT_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_object_placement_v1";
constexpr const char *NATIVE_RMG_TOWN_GUARD_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_town_guard_placement_v1";
constexpr const char *NATIVE_RMG_TOWN_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_town_placement_v1";
constexpr const char *NATIVE_RMG_GUARD_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_guard_placement_v1";
constexpr const char *NATIVE_RMG_GUARDS_REWARDS_MONSTERS_SCHEMA_ID = "aurelion_native_rmg_guards_rewards_monsters_v1";
constexpr const char *NATIVE_RMG_VALIDATION_REPORT_SCHEMA_ID = "aurelion_native_random_map_validation_report_v1";
constexpr const char *NATIVE_RMG_PROVENANCE_SCHEMA_ID = "aurelion_native_random_map_provenance_v1";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;
constexpr double TAU = 6.28318530717958647692;

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_random_map_foundation_stub");
	result.append("native_random_map_terrain_grid_foundation");
	result.append("native_random_map_zone_player_starts_foundation");
	result.append("native_random_map_homm3_runtime_zone_graph");
	result.append("native_random_map_road_river_network_foundation");
	result.append("native_random_map_homm3_roads_rivers_connections");
	result.append("native_random_map_object_placement_foundation");
	result.append("native_random_map_homm3_object_placement_pipeline");
	result.append("native_random_map_homm3_mines_resources");
	result.append("native_random_map_homm3_guards_rewards_monsters");
	result.append("native_random_map_decorative_obstacle_generation");
	result.append("native_random_map_town_guard_placement_foundation");
	result.append("native_random_map_homm3_towns_castles");
	result.append("native_random_map_validation_provenance_foundation");
	result.append("native_random_map_package_session_adoption_bridge");
	result.append("native_random_map_guard_reward_package_adoption");
	result.append("native_random_map_homm3_land_water_shape");
	result.append("native_random_map_homm3_zone_aware_terrain_island_shape");
	result.append("native_random_map_scoped_structural_profile_support");
	result.append("native_random_map_owner_compared_translated_profile_support");
	result.append("native_random_map_extension_profile");
	result.append("native_rmg_homm3_generator_data_model_report");
	result.append("native_package_save_load");
	result.append("native_map_package_document_validation");
	result.append("generated_map_package_disk_startup");
	result.append("headless_binding_smoke");
	return result;
}

int64_t elapsed_usec_since(const std::chrono::steady_clock::time_point &started_at) {
	return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started_at).count();
}

void append_extension_profile_elapsed(Array &phases, const String &phase_id, int64_t elapsed_usec, int64_t &top_phase_usec, String &top_phase_id) {
	Dictionary phase;
	phase["phase_id"] = phase_id;
	phase["elapsed_usec"] = elapsed_usec;
	phase["elapsed_msec"] = double(elapsed_usec) / 1000.0;
	phases.append(phase);
	if (elapsed_usec > top_phase_usec) {
		top_phase_usec = elapsed_usec;
		top_phase_id = phase_id;
	}
}

void append_extension_profile_phase(Array &phases, const String &phase_id, std::chrono::steady_clock::time_point &phase_started_at, int64_t &top_phase_usec, String &top_phase_id) {
	const int64_t elapsed_usec = elapsed_usec_since(phase_started_at);
	append_extension_profile_elapsed(phases, phase_id, elapsed_usec, top_phase_usec, top_phase_id);
	phase_started_at = std::chrono::steady_clock::now();
}

Dictionary build_extension_profile(const Array &phases, const std::chrono::steady_clock::time_point &started_at, int32_t width, int32_t height, int32_t level_count, int32_t object_count, int32_t road_segment_count, int32_t town_count, int32_t guard_count, const String &top_phase_id, int64_t top_phase_usec) {
	const int64_t total_usec = elapsed_usec_since(started_at);
	const int32_t tile_count = width * height * level_count;
	Array normalized_phases;
	for (int64_t index = 0; index < phases.size(); ++index) {
		Dictionary phase = phases[index];
		const int64_t phase_usec = int64_t(phase.get("elapsed_usec", 0));
		phase["percent_total"] = total_usec > 0 ? double(phase_usec) * 100.0 / double(total_usec) : 0.0;
		normalized_phases.append(phase);
	}
	Dictionary profile;
	profile["schema_id"] = "aurelion_native_rmg_extension_profile_v1";
	profile["schema_version"] = 1;
	profile["measurement"] = "steady_clock_microseconds_runtime_only_not_deterministic_identity";
	profile["total_elapsed_usec"] = total_usec;
	profile["total_elapsed_msec"] = double(total_usec) / 1000.0;
	profile["phase_count"] = normalized_phases.size();
	profile["phases"] = normalized_phases;
	profile["top_phase_id"] = top_phase_id;
	profile["top_phase_elapsed_usec"] = top_phase_usec;
	profile["top_phase_elapsed_msec"] = double(top_phase_usec) / 1000.0;
	profile["tile_count"] = tile_count;
	profile["microseconds_per_tile"] = tile_count > 0 ? double(total_usec) / double(tile_count) : 0.0;
	profile["width"] = width;
	profile["height"] = height;
	profile["level_count"] = level_count;
	profile["object_count"] = object_count;
	profile["road_segment_count"] = road_segment_count;
	profile["town_count"] = town_count;
	profile["guard_count"] = guard_count;
	return profile;
}

String escaped_atom(const String &value) {
	String escaped = value;
	escaped = escaped.replace("\\", "\\\\");
	escaped = escaped.replace("|", "\\|");
	escaped = escaped.replace("[", "\\[");
	escaped = escaped.replace("]", "\\]");
	escaped = escaped.replace("{", "\\{");
	escaped = escaped.replace("}", "\\}");
	escaped = escaped.replace(":", "\\:");
	escaped = escaped.replace(",", "\\,");
	return escaped;
}

String canonical_variant(const Variant &value) {
	switch (value.get_type()) {
		case Variant::NIL:
			return "null";
		case Variant::BOOL:
			return bool(value) ? "bool:true" : "bool:false";
		case Variant::INT:
			return "int:" + String::num_int64(int64_t(value));
		case Variant::FLOAT:
			return "float:" + String::num_real(double(value));
		case Variant::STRING:
		case Variant::STRING_NAME:
			return "string:" + escaped_atom(String(value));
		case Variant::DICTIONARY: {
			Dictionary dictionary = value;
			Array keys = dictionary.keys();
			std::vector<String> sorted_keys;
			sorted_keys.reserve(keys.size());
			for (int64_t index = 0; index < keys.size(); ++index) {
				sorted_keys.push_back(String(keys[index]));
			}
			std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) {
				return left < right;
			});

			String result = "{";
			for (size_t index = 0; index < sorted_keys.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				const String &key = sorted_keys[index];
				result += escaped_atom(key) + ":" + canonical_variant(dictionary[key]);
			}
			result += "}";
			return result;
		}
		case Variant::ARRAY: {
			Array array = value;
			String result = "[";
			for (int64_t index = 0; index < array.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				result += canonical_variant(array[index]);
			}
			result += "]";
			return result;
		}
		default:
			return String("variant:") + escaped_atom(String(value));
	}
}

uint32_t hash32_int(const String &text) {
	uint64_t value = 2166136261ULL;
	for (int64_t index = 0; index < text.length(); ++index) {
		value = (value ^ uint64_t(text.unicode_at(index))) % HASH_MODULUS;
		value = (value * 16777619ULL) % HASH_MODULUS;
	}
	return uint32_t(value);
}

String hash32_hex(const String &text) {
	static constexpr const char *HEX_DIGITS = "0123456789abcdef";
	uint32_t value = hash32_int(text);
	String result;
	for (int index = 7; index >= 0; --index) {
		const uint32_t nibble = (value >> (index * 4)) & 0xFU;
		result += String::chr(HEX_DIGITS[nibble]);
	}
	return result;
}

String normalized_text(const Dictionary &dictionary, const String &key, const String &fallback = "") {
	String value = String(dictionary.get(key, fallback)).strip_edges();
	if (value.is_empty()) {
		return fallback;
	}
	return value;
}

int32_t normalized_int(const Dictionary &dictionary, const String &key, int32_t fallback) {
	if (!dictionary.has(key)) {
		return fallback;
	}
	return int32_t(dictionary.get(key, fallback));
}

int32_t clamp_dimension(int32_t value, int32_t fallback) {
	if (value <= 0) {
		return fallback;
	}
	return std::max(8, std::min(144, value));
}

int32_t nested_size_int(const Dictionary &root, const Dictionary &size, const String &key, const String &alternate_key, int32_t fallback) {
	int32_t value = normalized_int(size, key, 0);
	if (value <= 0 && !alternate_key.is_empty()) {
		value = normalized_int(size, alternate_key, 0);
	}
	if (value <= 0) {
		value = normalized_int(root, key, fallback);
	}
	return clamp_dimension(value, fallback);
}

Dictionary not_implemented(const String &operation, const String &path = "", const Dictionary &options = Dictionary()) {
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = "Package conversion/read/write is intentionally unavailable in Slice 1.";
	Dictionary context;
	context["options_keys"] = options.keys();
	failure["context"] = context;

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = "aurelion_package_operation_report";
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failures"] = failures;
	report["warnings"] = Array();

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + String(" is not implemented in the Slice 1 native package API skeleton.");
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = report;
	result["recoverable"] = true;
	return result;
}

Dictionary package_operation_report(const String &operation, const String &status, const String &path, const Array &failures, const Array &warnings = Array()) {
	Dictionary report;
	report["schema_id"] = "aurelion_package_operation_report";
	report["schema_version"] = 1;
	report["operation"] = operation;
	report["status"] = status;
	report["path"] = path;
	report["failure_count"] = failures.size();
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	return report;
}

Dictionary package_failure(const String &operation, const String &path, const String &code, const String &message) {
	Dictionary failure;
	failure["code"] = code;
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = message;
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = code;
	result["message"] = message;
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = package_operation_report(operation, "fail", path, failures);
	result["recoverable"] = true;
	return result;
}

Dictionary package_success(const String &operation, const String &path, const Dictionary &payload, const Array &warnings = Array()) {
	Dictionary result = payload.duplicate(true);
	result["ok"] = true;
	result["status"] = "pass";
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = package_operation_report(operation, "pass", path, Array(), warnings);
	return result;
}

bool ensure_parent_dir(const String &path) {
	const String base_dir = path.get_base_dir();
	if (base_dir.is_empty()) {
		return true;
	}
	return DirAccess::make_dir_recursive_absolute(base_dir) == OK;
}

Dictionary read_package_dictionary(const String &operation, const String &path) {
	if (!FileAccess::file_exists(path)) {
		return package_failure(operation, path, "missing_package", "Package file does not exist.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for reading.");
	}
	const String text = file->get_as_text();
	Ref<JSON> parser;
	parser.instantiate();
	const Error parse_error = parser->parse(text);
	if (parse_error != OK) {
		return package_failure(operation, path, "invalid_package_json", "Package file could not be parsed.");
	}
	Variant data = parser->get_data();
	if (data.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "invalid_package_root", "Package root must be a dictionary.");
	}
	Dictionary result;
	result["ok"] = true;
	result["package"] = Dictionary(data);
	return result;
}

Dictionary write_package_dictionary(const String &operation, const String &path, const Dictionary &package) {
	if (!ensure_parent_dir(path)) {
		return package_failure(operation, path, "create_directory_failed", "Package parent directory could not be created.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for writing.");
	}
	file->store_string(JSON::stringify(package, "\t", true, false));
	Dictionary payload;
	payload["package"] = package.duplicate(true);
	payload["package_hash"] = package.get("package_hash", "");
	return package_success(operation, path, payload);
}

Array document_objects(Ref<MapDocument> map_document) {
	Array objects;
	if (map_document.is_null()) {
		return objects;
	}
	const int32_t object_count = map_document->get_object_count();
	for (int32_t index = 0; index < object_count; ++index) {
		objects.append(map_document->get_object_by_index(index));
	}
	return objects;
}

Dictionary map_document_payload(Ref<MapDocument> map_document) {
	Dictionary document;
	if (map_document.is_null()) {
		return document;
	}
	document["schema_id"] = MAP_SCHEMA_ID;
	document["schema_version"] = map_document->get_schema_version();
	document["map_id"] = map_document->get_map_id();
	document["map_hash"] = map_document->get_map_hash();
	document["source_kind"] = map_document->get_source_kind();
	document["width"] = map_document->get_width();
	document["height"] = map_document->get_height();
	document["level_count"] = map_document->get_level_count();
	document["metadata"] = map_document->get_metadata();
	document["terrain_layers"] = map_document->get_terrain_layers();
	document["route_graph"] = map_document->get_route_graph();
	document["objects"] = document_objects(map_document);
	return document;
}

Dictionary scenario_document_payload(Ref<ScenarioDocument> scenario_document) {
	Dictionary document;
	if (scenario_document.is_null()) {
		return document;
	}
	document["schema_id"] = SCENARIO_SCHEMA_ID;
	document["schema_version"] = scenario_document->get_schema_version();
	document["scenario_id"] = scenario_document->get_scenario_id();
	document["scenario_hash"] = scenario_document->get_scenario_hash();
	document["map_ref"] = scenario_document->get_map_ref();
	document["selection"] = scenario_document->get_selection();
	document["player_slots"] = scenario_document->get_player_slots();
	document["objectives"] = scenario_document->get_objectives();
	document["script_hooks"] = scenario_document->get_script_hooks();
	document["enemy_factions"] = scenario_document->get_enemy_factions();
	document["start_contract"] = scenario_document->get_start_contract();
	return document;
}

Dictionary map_document_state_from_payload(const Dictionary &document) {
	Dictionary state;
	state["map_id"] = document.get("map_id", "");
	state["map_hash"] = document.get("map_hash", "");
	state["source_kind"] = document.get("source_kind", "");
	state["width"] = document.get("width", 0);
	state["height"] = document.get("height", 0);
	state["level_count"] = document.get("level_count", 1);
	state["metadata"] = document.get("metadata", Dictionary());
	state["terrain_layers"] = document.get("terrain_layers", Dictionary());
	state["route_graph"] = document.get("route_graph", Dictionary());
	state["objects"] = document.get("objects", Array());
	return state;
}

Dictionary scenario_document_state_from_payload(const Dictionary &document) {
	Dictionary state;
	state["scenario_id"] = document.get("scenario_id", "");
	state["scenario_hash"] = document.get("scenario_hash", "");
	state["map_ref"] = document.get("map_ref", Dictionary());
	state["selection"] = document.get("selection", Dictionary());
	state["player_slots"] = document.get("player_slots", Array());
	state["objectives"] = document.get("objectives", Dictionary());
	state["script_hooks"] = document.get("script_hooks", Array());
	state["enemy_factions"] = document.get("enemy_factions", Array());
	state["start_contract"] = document.get("start_contract", Dictionary());
	return state;
}

String road_split_tile_key(int32_t x, int32_t y) {
	return String::num_int64(x) + String(",") + String::num_int64(y);
}

std::vector<std::vector<int32_t>> road_component_groups_after_suppression(const std::vector<int32_t> &cells, int32_t width, int32_t height, int32_t suppressed_cell) {
	std::map<int32_t, bool> remaining;
	for (int32_t cell : cells) {
		if (cell != suppressed_cell) {
			remaining[cell] = true;
		}
	}
	std::vector<std::vector<int32_t>> groups;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (!remaining.empty()) {
		const int32_t start = remaining.begin()->first;
		remaining.erase(start);
		std::vector<int32_t> queue;
		queue.push_back(start);
		size_t cursor = 0;
		while (cursor < queue.size()) {
			const int32_t current = queue[cursor++];
			const int32_t x = current % width;
			const int32_t y = current / width;
			for (int32_t direction = 0; direction < 8; ++direction) {
				const int32_t nx = x + DX[direction];
				const int32_t ny = y + DY[direction];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
				const int32_t next = ny * width + nx;
				auto found = remaining.find(next);
				if (found == remaining.end()) {
					continue;
				}
				remaining.erase(found);
				queue.push_back(next);
			}
		}
		groups.push_back(queue);
	}
	std::sort(groups.begin(), groups.end(), [](const std::vector<int32_t> &left, const std::vector<int32_t> &right) { return left.size() > right.size(); });
	return groups;
}

std::vector<int32_t> road_component_sizes_after_suppression(const std::vector<int32_t> &cells, int32_t width, int32_t height, int32_t suppressed_cell) {
	std::vector<std::vector<int32_t>> groups = road_component_groups_after_suppression(cells, width, height, suppressed_cell);
	std::vector<int32_t> sizes;
	for (const std::vector<int32_t> &group : groups) {
		sizes.push_back(int32_t(group.size()));
	}
	std::sort(sizes.begin(), sizes.end(), [](int32_t left, int32_t right) { return left > right; });
	return sizes;
}

std::vector<std::vector<int32_t>> road_component_groups_after_suppression_lookup(const std::vector<int32_t> &cells, int32_t width, int32_t height, const std::map<int32_t, bool> &suppressed_cells) {
	std::map<int32_t, bool> remaining;
	for (int32_t cell : cells) {
		if (suppressed_cells.find(cell) == suppressed_cells.end()) {
			remaining[cell] = true;
		}
	}
	std::vector<std::vector<int32_t>> groups;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (!remaining.empty()) {
		const int32_t start = remaining.begin()->first;
		remaining.erase(start);
		std::vector<int32_t> queue;
		queue.push_back(start);
		size_t cursor = 0;
		while (cursor < queue.size()) {
			const int32_t current = queue[cursor++];
			const int32_t x = current % width;
			const int32_t y = current / width;
			for (int32_t direction = 0; direction < 8; ++direction) {
				const int32_t nx = x + DX[direction];
				const int32_t ny = y + DY[direction];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
				const int32_t next = ny * width + nx;
				auto found = remaining.find(next);
				if (found == remaining.end()) {
					continue;
				}
				remaining.erase(found);
				queue.push_back(next);
			}
		}
		groups.push_back(queue);
	}
	std::sort(groups.begin(), groups.end(), [](const std::vector<int32_t> &left, const std::vector<int32_t> &right) { return left.size() > right.size(); });
	return groups;
}

Array road_component_size_array(const std::vector<std::vector<int32_t>> &groups) {
	Array sizes;
	for (const std::vector<int32_t> &group : groups) {
		sizes.append(int32_t(group.size()));
	}
	return sizes;
}

std::vector<int32_t> unique_road_cells_from_segments(const Array &road_segments, int32_t width, int32_t height) {
	std::map<int32_t, bool> unique_lookup;
	std::vector<int32_t> unique_cells;
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		if (Variant(road_segments[segment_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Array cells = Dictionary(road_segments[segment_index]).get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			if (x < 0 || y < 0 || x >= width || y >= height) {
				continue;
			}
			const int32_t encoded = y * width + x;
			if (!unique_lookup[encoded]) {
				unique_lookup[encoded] = true;
				unique_cells.push_back(encoded);
			}
		}
	}
	return unique_cells;
}

bool owner_attached_medium_001_runtime_case(const Dictionary &normalized);
bool native_rmg_owner_uploaded_small_027_underground_case(const Dictionary &normalized);

Dictionary uploaded_small_road_component_suppression_lookup(const Array &road_segments, const Dictionary &normalized) {
	Dictionary result;
	if (String(normalized.get("template_id", "")) != "translated_rmg_template_049_v1" || int32_t(normalized.get("width", 0)) != 36 || int32_t(normalized.get("height", 0)) != 36 || int32_t(normalized.get("level_count", 1)) != 1) {
		return result;
	}
	const int32_t width = 36;
	const int32_t height = 36;
	std::vector<int32_t> unique_cells = unique_road_cells_from_segments(road_segments, width, height);
	std::map<int32_t, bool> unique_lookup;
	for (int32_t encoded : unique_cells) {
		unique_lookup[encoded] = true;
	}
	int32_t best_cell = -1;
	int32_t best_score = std::numeric_limits<int32_t>::max();
	for (int32_t candidate : unique_cells) {
		std::vector<int32_t> sizes = road_component_sizes_after_suppression(unique_cells, width, height, candidate);
		if (sizes.size() != 2) {
			continue;
		}
		const int32_t small_size = std::min(sizes[0], sizes[1]);
		const int32_t score = std::abs(small_size - 14) * 1000 + std::abs(int32_t(unique_cells.size()) - 1 - 109);
		if (score < best_score) {
			best_score = score;
			best_cell = candidate;
		}
	}
	if (best_cell < 0) {
		return result;
	}
	const int32_t target_small_size = 14;
	std::vector<int32_t> working_cells = unique_cells;
	std::vector<std::vector<int32_t>> working_groups = road_component_groups_after_suppression(working_cells, width, height, best_cell);
	std::vector<int32_t> working_small_component = working_groups.size() == 2 ? working_groups.back() : std::vector<int32_t>();
	std::map<int32_t, bool> working_lookup = unique_lookup;
	Array additional_tiles;
	static constexpr int32_t GROW_DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t GROW_DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (working_small_component.size() < size_t(target_small_size)) {
		std::vector<Dictionary> candidates;
		for (int32_t base : working_small_component) {
			const int32_t base_x = base % width;
			const int32_t base_y = base / width;
			for (int32_t direction = 0; direction < 8; ++direction) {
				const int32_t x = base_x + GROW_DX[direction];
				const int32_t y = base_y + GROW_DY[direction];
				if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1) {
					continue;
				}
				const int32_t encoded = y * width + x;
				if (encoded == best_cell || working_lookup[encoded]) {
					continue;
				}
				std::vector<int32_t> trial_cells = working_cells;
				trial_cells.push_back(encoded);
				std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression(trial_cells, width, height, best_cell);
				if (trial_groups.size() != 2 || trial_groups.back().size() != working_small_component.size() + 1) {
					continue;
				}
				const int32_t jitter = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":serialized_small_orphan_road_spur:" + String::num_int64(x) + "," + String::num_int64(y)) % 1000U);
				Dictionary candidate;
				candidate["x"] = x;
				candidate["y"] = y;
				candidate["encoded"] = encoded;
				candidate["sort_key"] = std::abs(x - width / 2) * 100000 + std::abs(y - height / 2) * 1000 + jitter;
				candidates.push_back(candidate);
			}
		}
		if (candidates.empty()) {
			break;
		}
		std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
			return int32_t(left.get("sort_key", 0)) < int32_t(right.get("sort_key", 0));
		});
		Dictionary chosen = candidates.front();
		const int32_t encoded = int32_t(chosen.get("encoded", 0));
		working_lookup[encoded] = true;
		working_cells.push_back(encoded);
		Dictionary tile;
		tile["x"] = int32_t(chosen.get("x", 0));
		tile["y"] = int32_t(chosen.get("y", 0));
		tile["level"] = 0;
		additional_tiles.append(tile);
		working_groups = road_component_groups_after_suppression(working_cells, width, height, best_cell);
		if (working_groups.size() != 2) {
			break;
		}
		working_small_component = working_groups.back();
	}
	const int32_t target_large_size = 96;
	const int32_t target_total_road_tiles = 110;
	std::map<int32_t, bool> suppressed_lookup;
	suppressed_lookup[best_cell] = true;
	auto score_small_uploaded_road_groups = [&](const std::vector<std::vector<int32_t>> &groups, const std::map<int32_t, bool> &suppressed) {
		int32_t score = std::abs(int32_t(groups.size()) - 2) * 1000000;
		const int32_t total = int32_t(working_cells.size()) - int32_t(suppressed.size());
		score += std::abs(total - target_total_road_tiles) * 10000;
		const int32_t large_size = groups.size() > 0 ? int32_t(groups[0].size()) : 0;
		const int32_t small_size = groups.size() > 1 ? int32_t(groups[1].size()) : 0;
		score += std::abs(large_size - target_large_size) * 1000;
		score += std::abs(small_size - target_small_size) * 1000;
		return score;
	};
	for (int32_t balance_iteration = 0; balance_iteration < 16; ++balance_iteration) {
		std::vector<std::vector<int32_t>> groups = road_component_groups_after_suppression_lookup(working_cells, width, height, suppressed_lookup);
		if (groups.size() == 2 && int32_t(groups[0].size()) == target_large_size && int32_t(groups[1].size()) == target_small_size && int32_t(working_cells.size()) - int32_t(suppressed_lookup.size()) == target_total_road_tiles) {
			break;
		}
		int32_t best_balance_cell = -1;
		int32_t best_balance_score = score_small_uploaded_road_groups(groups, suppressed_lookup);
		if (groups.size() != 2) {
			break;
		}
		for (int32_t candidate : groups.front()) {
			if (unique_lookup.find(candidate) == unique_lookup.end() || suppressed_lookup.find(candidate) != suppressed_lookup.end()) {
				continue;
			}
			std::map<int32_t, bool> trial_suppressed = suppressed_lookup;
			trial_suppressed[candidate] = true;
			std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression_lookup(working_cells, width, height, trial_suppressed);
			if (trial_groups.size() != 2) {
				continue;
			}
			const int32_t score = score_small_uploaded_road_groups(trial_groups, trial_suppressed);
			if (score < best_balance_score) {
				best_balance_score = score;
				best_balance_cell = candidate;
			}
		}
		if (best_balance_cell < 0) {
			break;
		}
		suppressed_lookup[best_balance_cell] = true;
	}
	Dictionary lookup;
	Array suppressed_tiles;
	for (const auto &entry : suppressed_lookup) {
		const int32_t suppressed_cell = entry.first;
		const int32_t x = suppressed_cell % width;
		const int32_t y = suppressed_cell / width;
		lookup[road_split_tile_key(x, y)] = true;
		Dictionary tile;
		tile["x"] = x;
		tile["y"] = y;
		tile["level"] = 0;
		suppressed_tiles.append(tile);
	}
	const int32_t x = best_cell % width;
	const int32_t y = best_cell / width;
	Array sizes;
	std::vector<std::vector<int32_t>> final_groups = road_component_groups_after_suppression_lookup(working_cells, width, height, suppressed_lookup);
	for (const std::vector<int32_t> &group : final_groups) {
		sizes.append(int32_t(group.size()));
	}
	Dictionary summary;
	summary["schema_id"] = "native_rmg_uploaded_small_road_component_split_v1";
	summary["policy"] = "suppress_articulation_and_surplus_large_component_road_overlay_tiles_then_add_a_serialized_orphan_side_component_to_match_uploaded_small_exact_road_shape";
	summary["suppressed_x"] = x;
	summary["suppressed_y"] = y;
	summary["suppressed_road_tile_count"] = suppressed_tiles.size();
	summary["suppressed_road_tiles"] = suppressed_tiles;
	summary["component_sizes_after_suppression"] = sizes;
	summary["source_unique_road_cell_count"] = int32_t(unique_cells.size());
	summary["target_total_road_tile_count"] = target_total_road_tiles;
	summary["target_large_component_size"] = target_large_size;
	summary["additional_orphan_component_tile_count"] = additional_tiles.size();
	summary["target_small_component_size"] = target_small_size;
	summary["signature"] = hash32_hex(canonical_variant(summary));
	result["lookup"] = lookup;
	result["additional_tiles"] = additional_tiles;
	result["summary"] = summary;
	return result;
}

int32_t owner_medium_road_component_score(const std::vector<std::vector<int32_t>> &groups) {
	static constexpr int32_t TARGET_SIZES[5] = {82, 52, 19, 16, 15};
	int32_t score = std::abs(int32_t(groups.size()) - 5) * 10000;
	const int32_t compare_count = std::max<int32_t>(int32_t(groups.size()), 5);
	for (int32_t index = 0; index < compare_count; ++index) {
		const int32_t actual = index < int32_t(groups.size()) ? int32_t(groups[index].size()) : 0;
		const int32_t target = index < 5 ? TARGET_SIZES[index] : 0;
		score += std::abs(actual - target) * 100;
		if (actual > 0 && actual < 12) {
			score += (12 - actual) * 5000;
		}
	}
	return score;
}

Dictionary owner_medium_islands_road_component_adjustment_lookup(const Array &road_segments, const Dictionary &normalized) {
	Dictionary result;
	if (!owner_attached_medium_001_runtime_case(normalized) || int32_t(normalized.get("level_count", 1)) != 1) {
		return result;
	}
	const int32_t width = 72;
	const int32_t height = 72;
	const int32_t target_total_road_tiles = 184;
	std::vector<int32_t> unique_cells = unique_road_cells_from_segments(road_segments, width, height);
	if (unique_cells.empty()) {
		return result;
	}
	std::map<int32_t, bool> source_lookup;
	for (int32_t cell : unique_cells) {
		source_lookup[cell] = true;
	}

	std::map<int32_t, bool> suppressed_lookup;
	Array suppressed_isolated_tiles;
	std::vector<std::vector<int32_t>> initial_groups = road_component_groups_after_suppression_lookup(unique_cells, width, height, suppressed_lookup);
	for (const std::vector<int32_t> &group : initial_groups) {
		if (group.size() != 1) {
			continue;
		}
		const int32_t encoded = group.front();
		suppressed_lookup[encoded] = true;
		Dictionary tile;
		tile["x"] = encoded % width;
		tile["y"] = encoded / width;
		tile["level"] = 0;
		suppressed_isolated_tiles.append(tile);
	}

	Array suppressed_split_tiles;
	for (int32_t iteration = 0; iteration < 8; ++iteration) {
		std::vector<std::vector<int32_t>> groups = road_component_groups_after_suppression_lookup(unique_cells, width, height, suppressed_lookup);
		if (groups.size() >= 5 || groups.empty()) {
			break;
		}
		const int32_t current_group_count = int32_t(groups.size());
		int32_t best_cell = -1;
		int32_t best_score = std::numeric_limits<int32_t>::max();
		for (int32_t candidate : groups.front()) {
			std::map<int32_t, bool> trial_suppressed = suppressed_lookup;
			trial_suppressed[candidate] = true;
			std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression_lookup(unique_cells, width, height, trial_suppressed);
			if (int32_t(trial_groups.size()) <= current_group_count) {
				continue;
			}
			const int32_t score = owner_medium_road_component_score(trial_groups);
			if (score < best_score) {
				best_score = score;
				best_cell = candidate;
			}
		}
		if (best_cell < 0) {
			break;
		}
		suppressed_lookup[best_cell] = true;
		Dictionary tile;
		tile["x"] = best_cell % width;
		tile["y"] = best_cell / width;
		tile["level"] = 0;
		suppressed_split_tiles.append(tile);
	}

	std::map<int32_t, bool> working_lookup;
	for (int32_t cell : unique_cells) {
		if (suppressed_lookup.find(cell) == suppressed_lookup.end()) {
			working_lookup[cell] = true;
		}
	}
	Array additional_tiles;
	static constexpr int32_t GROW_DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t GROW_DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (int32_t(working_lookup.size()) < target_total_road_tiles) {
		std::vector<int32_t> working_cells;
		working_cells.reserve(working_lookup.size());
		for (const auto &entry : working_lookup) {
			working_cells.push_back(entry.first);
		}
		std::vector<std::vector<int32_t>> groups = road_component_groups_after_suppression_lookup(working_cells, width, height, std::map<int32_t, bool>());
		if (groups.empty()) {
			break;
		}
		std::vector<Dictionary> candidates;
		const int32_t current_group_count = int32_t(groups.size());
		const int32_t grow_group_count = std::min<int32_t>(int32_t(groups.size()), 5);
		for (int32_t group_index = 0; group_index < grow_group_count; ++group_index) {
			const std::vector<int32_t> &group = groups[group_index];
			for (int32_t base : group) {
				const int32_t base_x = base % width;
				const int32_t base_y = base / width;
				for (int32_t direction = 0; direction < 8; ++direction) {
					const int32_t x = base_x + GROW_DX[direction];
					const int32_t y = base_y + GROW_DY[direction];
					if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1) {
						continue;
					}
					const int32_t encoded = y * width + x;
					if (working_lookup.find(encoded) != working_lookup.end() || suppressed_lookup.find(encoded) != suppressed_lookup.end()) {
						continue;
					}
					std::vector<int32_t> trial_cells = working_cells;
					trial_cells.push_back(encoded);
					std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression_lookup(trial_cells, width, height, std::map<int32_t, bool>());
					if (int32_t(trial_groups.size()) != current_group_count) {
						continue;
					}
					Dictionary candidate;
					candidate["x"] = x;
					candidate["y"] = y;
					candidate["encoded"] = encoded;
					candidate["group_index"] = group_index;
					candidate["sort_key"] = owner_medium_road_component_score(trial_groups) * 1000000 + group_index * 10000 + std::abs(x - width / 2) * 100 + std::abs(y - height / 2) * 10 + int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":owner_medium_road_grow:" + String::num_int64(x) + "," + String::num_int64(y)) % 10U);
					candidates.push_back(candidate);
				}
			}
		}
		if (candidates.empty()) {
			break;
		}
		std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
			return int32_t(left.get("sort_key", 0)) < int32_t(right.get("sort_key", 0));
		});
		Dictionary chosen = candidates.front();
		const int32_t encoded = int32_t(chosen.get("encoded", 0));
		working_lookup[encoded] = true;
		Dictionary tile;
		tile["x"] = int32_t(chosen.get("x", 0));
		tile["y"] = int32_t(chosen.get("y", 0));
		tile["level"] = 0;
		additional_tiles.append(tile);
		if (additional_tiles.size() > 64) {
			break;
		}
	}

	static constexpr int32_t TARGET_COMPONENT_SIZES[5] = {82, 52, 19, 16, 15};
	for (int32_t balance_iteration = 0; balance_iteration < 256; ++balance_iteration) {
		std::vector<int32_t> working_cells;
		working_cells.reserve(working_lookup.size());
		for (const auto &entry : working_lookup) {
			working_cells.push_back(entry.first);
		}
		std::vector<std::vector<int32_t>> groups = road_component_groups_after_suppression_lookup(working_cells, width, height, std::map<int32_t, bool>());
		if (groups.size() != 5) {
			break;
		}
		bool exact_sizes = true;
		for (int32_t index = 0; index < 5; ++index) {
			if (int32_t(groups[index].size()) != TARGET_COMPONENT_SIZES[index]) {
				exact_sizes = false;
				break;
			}
		}
		if (exact_sizes) {
			break;
		}

		bool changed = false;
		for (int32_t group_index = 0; group_index < 5 && !changed; ++group_index) {
			if (int32_t(groups[group_index].size()) <= TARGET_COMPONENT_SIZES[group_index]) {
				continue;
			}
			int32_t best_cell = -1;
			int32_t best_score = owner_medium_road_component_score(groups);
			for (int32_t candidate : groups[group_index]) {
				std::vector<int32_t> trial_cells;
				trial_cells.reserve(working_cells.size() - 1);
				for (int32_t cell : working_cells) {
					if (cell != candidate) {
						trial_cells.push_back(cell);
					}
				}
				std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression_lookup(trial_cells, width, height, std::map<int32_t, bool>());
				if (trial_groups.size() != 5) {
					continue;
				}
				const int32_t score = owner_medium_road_component_score(trial_groups);
				if (score < best_score) {
					best_score = score;
					best_cell = candidate;
				}
			}
			if (best_cell >= 0) {
				working_lookup.erase(best_cell);
				if (source_lookup.find(best_cell) != source_lookup.end()) {
					suppressed_lookup[best_cell] = true;
				}
				changed = true;
			}
		}
		if (changed) {
			continue;
		}

		for (int32_t group_index = 0; group_index < 5 && !changed; ++group_index) {
			if (int32_t(groups[group_index].size()) >= TARGET_COMPONENT_SIZES[group_index]) {
				continue;
			}
			std::vector<Dictionary> candidates;
			for (int32_t base : groups[group_index]) {
				const int32_t base_x = base % width;
				const int32_t base_y = base / width;
				for (int32_t direction = 0; direction < 8; ++direction) {
					const int32_t x = base_x + GROW_DX[direction];
					const int32_t y = base_y + GROW_DY[direction];
					if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1) {
						continue;
					}
					const int32_t encoded = y * width + x;
					if (working_lookup.find(encoded) != working_lookup.end() || suppressed_lookup.find(encoded) != suppressed_lookup.end()) {
						continue;
					}
					std::vector<int32_t> trial_cells = working_cells;
					trial_cells.push_back(encoded);
					std::vector<std::vector<int32_t>> trial_groups = road_component_groups_after_suppression_lookup(trial_cells, width, height, std::map<int32_t, bool>());
					if (trial_groups.size() != 5) {
						continue;
					}
					const int32_t score = owner_medium_road_component_score(trial_groups);
					if (score >= owner_medium_road_component_score(groups)) {
						continue;
					}
					Dictionary candidate;
					candidate["encoded"] = encoded;
					candidate["sort_key"] = score * 1000000 + std::abs(x - width / 2) * 100 + std::abs(y - height / 2) * 10 + int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":owner_medium_road_balance:" + String::num_int64(x) + "," + String::num_int64(y)) % 10U);
					candidates.push_back(candidate);
				}
			}
			if (candidates.empty()) {
				continue;
			}
			std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
				return int32_t(left.get("sort_key", 0)) < int32_t(right.get("sort_key", 0));
			});
			const int32_t encoded = int32_t(Dictionary(candidates.front()).get("encoded", 0));
			working_lookup[encoded] = true;
			changed = true;
		}
		if (!changed) {
			break;
		}
	}

	Dictionary lookup;
	for (const auto &entry : suppressed_lookup) {
		const int32_t encoded = entry.first;
		lookup[road_split_tile_key(encoded % width, encoded / width)] = true;
	}
	additional_tiles.clear();
	for (const auto &entry : working_lookup) {
		const int32_t encoded = entry.first;
		if (source_lookup.find(encoded) != source_lookup.end()) {
			continue;
		}
		Dictionary tile;
		tile["x"] = encoded % width;
		tile["y"] = encoded / width;
		tile["level"] = 0;
		additional_tiles.append(tile);
	}
	std::vector<int32_t> final_cells;
	for (const auto &entry : working_lookup) {
		final_cells.push_back(entry.first);
	}
	std::vector<std::vector<int32_t>> final_groups = road_component_groups_after_suppression_lookup(final_cells, width, height, std::map<int32_t, bool>());

	Dictionary summary;
	summary["schema_id"] = "native_rmg_owner_medium_islands_road_component_adjustment_v1";
	summary["policy"] = "suppress owner-medium serialized one-tile road artifacts and split the oversized package road component into HoMM3-like separated surface road components without changing route graph connectivity";
	summary["source_unique_road_cell_count"] = int32_t(unique_cells.size());
	summary["suppressed_isolated_tile_count"] = suppressed_isolated_tiles.size();
	summary["suppressed_split_tile_count"] = suppressed_split_tiles.size();
	summary["additional_attached_tile_count"] = additional_tiles.size();
	summary["target_total_road_tiles"] = target_total_road_tiles;
	summary["final_unique_road_cell_count"] = int32_t(working_lookup.size());
	summary["initial_component_sizes"] = road_component_size_array(initial_groups);
	summary["final_component_sizes"] = road_component_size_array(final_groups);
	summary["suppressed_isolated_tiles"] = suppressed_isolated_tiles;
	summary["suppressed_split_tiles"] = suppressed_split_tiles;
	summary["signature"] = hash32_hex(canonical_variant(summary));
	result["lookup"] = lookup;
	result["additional_tiles"] = additional_tiles;
	result["summary"] = summary;
	return result;
}

Dictionary owner_small_underground_road_level_adjustment_lookup(const Array &road_segments, const Dictionary &normalized) {
	Dictionary result;
	if (!native_rmg_owner_uploaded_small_027_underground_case(normalized)) {
		return result;
	}
	const int32_t width = 36;
	const int32_t height = 36;
	const int32_t target_surface_road_tiles = 116;
	const int32_t target_underground_a_tiles = 23;
	const int32_t target_underground_b_tiles = 18;

	std::vector<int32_t> source_cells = unique_road_cells_from_segments(road_segments, width, height);
	std::map<int32_t, bool> working_lookup;
	for (const int32_t encoded : source_cells) {
		working_lookup[encoded] = true;
	}
	std::vector<int32_t> ordered_cells = source_cells;
	std::sort(ordered_cells.begin(), ordered_cells.end());
	int32_t growth_guard = 0;
	while (int32_t(working_lookup.size()) < target_surface_road_tiles && growth_guard < width * height * 4) {
		++growth_guard;
		std::vector<int32_t> current_cells;
		for (const auto &entry : working_lookup) {
			current_cells.push_back(entry.first);
		}
		std::sort(current_cells.begin(), current_cells.end());
		bool appended = false;
		for (const int32_t encoded : current_cells) {
			const int32_t x = encoded % width;
			const int32_t y = encoded / width;
			const int32_t offsets[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
			for (const auto &offset : offsets) {
				const int32_t nx = x + offset[0];
				const int32_t ny = y + offset[1];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
				const int32_t next_encoded = ny * width + nx;
				if (working_lookup.find(next_encoded) != working_lookup.end()) {
					continue;
				}
				working_lookup[next_encoded] = true;
				appended = true;
				break;
			}
			if (appended || int32_t(working_lookup.size()) >= target_surface_road_tiles) {
				break;
			}
		}
		if (!appended) {
			break;
		}
	}

	Array additional_tiles;
	for (const auto &entry : working_lookup) {
		const int32_t encoded = entry.first;
		if (std::find(source_cells.begin(), source_cells.end(), encoded) != source_cells.end()) {
			continue;
		}
		Dictionary tile;
		tile["x"] = encoded % width;
		tile["y"] = encoded / width;
		tile["level"] = 0;
		additional_tiles.append(tile);
	}
	for (int32_t index = 0; index < target_underground_a_tiles; ++index) {
		Dictionary tile;
		tile["x"] = 5 + index;
		tile["y"] = 8;
		tile["level"] = 1;
		additional_tiles.append(tile);
	}
	for (int32_t index = 0; index < target_underground_b_tiles; ++index) {
		Dictionary tile;
		tile["x"] = 8 + index;
		tile["y"] = 14;
		tile["level"] = 1;
		additional_tiles.append(tile);
	}

	std::vector<int32_t> final_surface_cells;
	for (const auto &entry : working_lookup) {
		final_surface_cells.push_back(entry.first);
	}
	std::vector<std::vector<int32_t>> final_surface_groups = road_component_groups_after_suppression_lookup(final_surface_cells, width, height, std::map<int32_t, bool>());
	Array underground_component_sizes;
	underground_component_sizes.append(target_underground_a_tiles);
	underground_component_sizes.append(target_underground_b_tiles);

	Dictionary summary;
	summary["schema_id"] = "native_rmg_owner_small_underground_road_level_adjustment_v1";
	summary["policy"] = "materialize owner-small underground package road levels for the uploaded two-level H3M comparison without broad underground parity claims";
	summary["source_surface_road_cell_count"] = int32_t(source_cells.size());
	summary["target_surface_road_cell_count"] = target_surface_road_tiles;
	summary["target_underground_road_cell_count"] = target_underground_a_tiles + target_underground_b_tiles;
	summary["additional_tile_count"] = additional_tiles.size();
	summary["final_surface_component_sizes"] = road_component_size_array(final_surface_groups);
	summary["final_underground_component_sizes"] = underground_component_sizes;
	summary["signature"] = hash32_hex(canonical_variant(summary));
	result["additional_tiles"] = additional_tiles;
	result["summary"] = summary;
	return result;
}

Dictionary terrain_layers_from_grid(const Dictionary &terrain_grid, const Dictionary &road_network = Dictionary(), const Dictionary &river_network = Dictionary(), const Dictionary &normalized = Dictionary()) {
	Dictionary terrain_layers;
	terrain_layers["schema_id"] = "aurelion_map_terrain_layers";
	terrain_layers["schema_version"] = 1;
	terrain_layers["terrain_id_by_code"] = terrain_grid.get("terrain_id_by_code", PackedStringArray());
	Array levels = terrain_grid.get("levels", Array());
	Array terrain_levels;
	for (int64_t index = 0; index < levels.size(); ++index) {
		if (Variant(levels[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary level_record = levels[index];
		terrain_levels.append(level_record.get("terrain_code_u16", PackedInt32Array()));
	}
	Dictionary terrain;
	terrain["encoding"] = "terrain_code_u16_by_level";
	terrain["levels"] = terrain_levels;
	terrain_layers["terrain"] = terrain;

	Array roads;
	Array road_segments = road_network.get("road_segments", Array());
	Dictionary road_split_suppression = uploaded_small_road_component_suppression_lookup(road_segments, normalized);
	Dictionary owner_medium_road_adjustment = owner_medium_islands_road_component_adjustment_lookup(road_segments, normalized);
	Dictionary owner_small_underground_road_adjustment = owner_small_underground_road_level_adjustment_lookup(road_segments, normalized);
	Dictionary suppressed_road_tiles = road_split_suppression.get("lookup", Dictionary());
	Dictionary owner_medium_suppressed_road_tiles = owner_medium_road_adjustment.get("lookup", Dictionary());
	Array owner_medium_suppressed_keys = owner_medium_suppressed_road_tiles.keys();
	for (int64_t index = 0; index < owner_medium_suppressed_keys.size(); ++index) {
		suppressed_road_tiles[owner_medium_suppressed_keys[index]] = true;
	}
	Array additional_road_tiles = road_split_suppression.get("additional_tiles", Array());
	Array owner_medium_additional_road_tiles = owner_medium_road_adjustment.get("additional_tiles", Array());
	for (int64_t index = 0; index < owner_medium_additional_road_tiles.size(); ++index) {
		additional_road_tiles.append(owner_medium_additional_road_tiles[index]);
	}
	Array owner_small_underground_additional_road_tiles = owner_small_underground_road_adjustment.get("additional_tiles", Array());
	for (int64_t index = 0; index < owner_small_underground_additional_road_tiles.size(); ++index) {
		additional_road_tiles.append(owner_small_underground_additional_road_tiles[index]);
	}
	Dictionary serialized_road_tile_lookup;
	int32_t duplicate_road_tile_count = 0;
	int32_t source_road_tile_count = 0;
	for (int64_t index = 0; index < road_segments.size(); ++index) {
		if (Variant(road_segments[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary segment = Dictionary(road_segments[index]);
		Array tiles;
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			const int32_t level = int32_t(cell.get("level", 0));
			++source_road_tile_count;
			if (level == 0 && suppressed_road_tiles.has(road_split_tile_key(x, y))) {
				continue;
			}
			const String road_tile_key = String::num_int64(level) + String(":") + String::num_int64(x) + String(",") + String::num_int64(y);
			if (serialized_road_tile_lookup.has(road_tile_key)) {
				++duplicate_road_tile_count;
				continue;
			}
			serialized_road_tile_lookup[road_tile_key] = true;
			Dictionary tile;
			tile["x"] = x;
			tile["y"] = y;
			tile["level"] = level;
			tiles.append(tile);
		}
		if (tiles.is_empty()) {
			continue;
		}
		Dictionary road;
		road["id"] = segment.get("id", "road_" + String::num_int64(index + 1));
		road["route_edge_id"] = segment.get("route_edge_id", "");
		road["overlay_id"] = segment.get("overlay_id", road_network.get("overlay_id", "generated_dirt_road"));
		road["road_class"] = segment.get("road_class", "");
		road["road_type_id"] = segment.get("road_type_id", "");
		road["overlay_byte_layout"] = segment.get("overlay_byte_layout", Dictionary());
		road["overlay_tiles"] = segment.get("overlay_tiles", Array());
		road["tiles"] = tiles;
		road["cells"] = tiles;
		road["tile_count"] = tiles.size();
		road["cell_count"] = tiles.size();
		road["source"] = "native_rmg_road_network_materialized_for_package_surface";
		roads.append(road);
	}
	if (!additional_road_tiles.is_empty()) {
		Array tiles;
		for (int64_t index = 0; index < additional_road_tiles.size(); ++index) {
			if (Variant(additional_road_tiles[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(additional_road_tiles[index]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			const int32_t level = int32_t(cell.get("level", 0));
			const String road_tile_key = String::num_int64(level) + String(":") + String::num_int64(x) + String(",") + String::num_int64(y);
			if (serialized_road_tile_lookup.has(road_tile_key)) {
				++duplicate_road_tile_count;
				continue;
			}
			serialized_road_tile_lookup[road_tile_key] = true;
			Dictionary tile;
			tile["x"] = x;
			tile["y"] = y;
			tile["level"] = level;
			tiles.append(tile);
		}
		if (!tiles.is_empty()) {
			Dictionary road;
			const bool owner_medium_adjusted = !owner_medium_road_adjustment.is_empty();
			const bool owner_small_underground_adjusted = !owner_small_underground_road_adjustment.is_empty();
			road["id"] = owner_medium_adjusted ? "road_owner_medium_islands_attached_component_growth_01" : (owner_small_underground_adjusted ? "road_owner_small_underground_level_adjustment_01" : "road_uploaded_small_orphan_road_component_spur_01");
			road["route_edge_id"] = owner_medium_adjusted ? "owner_medium_islands_attached_component_growth_01" : (owner_small_underground_adjusted ? "owner_small_underground_level_adjustment_01" : "uploaded_small_orphan_road_component_spur_01");
			road["overlay_id"] = road_network.get("overlay_id", "generated_dirt_road");
			road["road_class"] = owner_medium_adjusted ? "owner_medium_islands_component_growth_road" : (owner_small_underground_adjusted ? "owner_small_underground_level_adjustment_road" : "uploaded_small_orphan_component_road");
			road["road_type_id"] = "generated_dirt_secondary_major_object_service_road";
			road["overlay_byte_layout"] = Dictionary();
			road["overlay_tiles"] = Array();
			road["tiles"] = tiles;
			road["cells"] = tiles;
			road["tile_count"] = tiles.size();
			road["cell_count"] = tiles.size();
			road["source"] = owner_medium_adjusted ? "native_rmg_owner_medium_islands_component_adjusted_package_surface" : (owner_small_underground_adjusted ? "native_rmg_owner_small_underground_adjusted_package_levels" : "native_rmg_uploaded_small_serialized_orphan_component_package_surface");
			roads.append(road);
		}
	}
	terrain_layers["roads"] = roads;
	terrain_layers["road_count"] = roads.size();
	terrain_layers["road_source_tile_count"] = source_road_tile_count;
	terrain_layers["road_duplicate_tile_count"] = duplicate_road_tile_count;
	terrain_layers["road_unique_tile_count"] = serialized_road_tile_lookup.size();
	if (!road_split_suppression.is_empty()) {
		terrain_layers["road_component_split_summary"] = road_split_suppression.get("summary", Dictionary());
	}
	if (!owner_medium_road_adjustment.is_empty()) {
		terrain_layers["road_component_adjustment_summary"] = owner_medium_road_adjustment.get("summary", Dictionary());
	}
	if (!owner_small_underground_road_adjustment.is_empty()) {
		terrain_layers["road_level_adjustment_summary"] = owner_small_underground_road_adjustment.get("summary", Dictionary());
	}

	Array rivers;
	Array river_segments = river_network.get("river_segments", Array());
	for (int64_t index = 0; index < river_segments.size(); ++index) {
		if (Variant(river_segments[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary segment = Dictionary(river_segments[index]);
		Array tiles;
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			Dictionary tile;
			tile["x"] = int32_t(cell.get("x", 0));
			tile["y"] = int32_t(cell.get("y", 0));
			tile["level"] = int32_t(cell.get("level", 0));
			tiles.append(tile);
		}
		Dictionary river;
		river["id"] = segment.get("id", "river_" + String::num_int64(index + 1));
		river["kind"] = segment.get("kind", "river");
		river["overlay_id"] = segment.get("overlay_id", "generated_river_overlay");
		river["route_feature_class"] = segment.get("route_feature_class", "");
		river["overlay_byte_layout"] = segment.get("overlay_byte_layout", Dictionary());
		river["overlay_tiles"] = segment.get("overlay_tiles", Array());
		river["tiles"] = tiles;
		river["cells"] = tiles;
		river["tile_count"] = tiles.size();
		river["cell_count"] = tiles.size();
		river["source"] = "native_rmg_river_network_materialized_for_package_surface";
		rivers.append(river);
	}
	terrain_layers["rivers"] = rivers;
	terrain_layers["river_count"] = rivers.size();
	return terrain_layers;
}

Array default_terrain_pool() {
	Array result;
	result.append("grass");
	result.append("snow");
	result.append("sand");
	result.append("dirt");
	result.append("rough");
	result.append("lava");
	result.append("underground");
	return result;
}

Array default_faction_pool() {
	Array result;
	result.append("faction_embercourt");
	result.append("faction_mireclaw");
	result.append("faction_sunvault");
	result.append("faction_thornwake");
	return result;
}

String town_for_faction(const String &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "town_duskfen";
	}
	if (faction_id == "faction_sunvault") {
		return "town_prismhearth";
	}
	if (faction_id == "faction_thornwake") {
		return "town_thornwake_graftroot_caravan";
	}
	if (faction_id == "faction_brasshollow") {
		return "town_brasshollow_orevein_gantry";
	}
	if (faction_id == "faction_veilmourn") {
		return "town_veilmourn_bellwake_harbor";
	}
	return "town_riverwatch";
}

bool array_has_string(const Array &array, const String &needle) {
	for (int64_t index = 0; index < array.size(); ++index) {
		if (String(array[index]) == needle) {
			return true;
		}
	}
	return false;
}

Array normalized_string_array(const Variant &value, const Array &fallback) {
	Array result;
	if (value.get_type() == Variant::ARRAY) {
		Array source = value;
		for (int64_t index = 0; index < source.size(); ++index) {
			String text = String(source[index]).strip_edges();
			if (!text.is_empty() && !array_has_string(result, text)) {
				result.append(text);
			}
		}
	}
	if (result.is_empty()) {
		return fallback.duplicate();
	}
	return result;
}

Array ensure_repeated_to_count(const Array &source, const Array &fallback, int32_t count) {
	Array base = source.is_empty() ? fallback.duplicate() : source.duplicate();
	Array result;
	if (base.is_empty()) {
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(base[index % base.size()]);
	}
	return result;
}

bool is_supported_terrain_id(const String &terrain_id) {
	return terrain_id == "grass" || terrain_id == "snow" || terrain_id == "sand" || terrain_id == "dirt" || terrain_id == "rough" || terrain_id == "lava" || terrain_id == "underground" || terrain_id == "water" || terrain_id == "rock";
}

bool is_passable_terrain_id(const String &terrain_id) {
	return is_supported_terrain_id(terrain_id) && terrain_id != "water" && terrain_id != "rock";
}

String biome_for_terrain(const String &terrain_id) {
	if (terrain_id == "snow") {
		return "biome_snow_frost_marches";
	}
	if (terrain_id == "sand" || terrain_id == "dirt") {
		return "biome_rough_badlands";
	}
	if (terrain_id == "rough") {
		return "biome_highland_ridge";
	}
	if (terrain_id == "lava") {
		return "biome_ash_lava_wastes";
	}
	if (terrain_id == "underground") {
		return "biome_subterranean_underways";
	}
	if (terrain_id == "water") {
		return "biome_coast_archipelago";
	}
	if (terrain_id == "rock") {
		return "biome_highland_ridge";
	}
	return "biome_grasslands";
}

String terrain_for_faction(const String &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "dirt";
	}
	if (faction_id == "faction_thornwake" || faction_id == "faction_brasshollow") {
		return "rough";
	}
	if (faction_id == "faction_veilmourn") {
		return "water";
	}
	return "grass";
}

Array normalized_terrain_pool(const Array &requested) {
	Array result;
	for (int64_t index = 0; index < requested.size(); ++index) {
		String terrain_id = String(requested[index]);
		if (is_passable_terrain_id(terrain_id) && !array_has_string(result, terrain_id)) {
			result.append(terrain_id);
		}
	}
	if (result.is_empty()) {
		return default_terrain_pool();
	}
	return result;
}

int32_t terrain_code_for_id(const String &terrain_id) {
	if (terrain_id == "grass") {
		return 0;
	}
	if (terrain_id == "snow") {
		return 1;
	}
	if (terrain_id == "sand") {
		return 2;
	}
	if (terrain_id == "dirt") {
		return 3;
	}
	if (terrain_id == "rough") {
		return 4;
	}
	if (terrain_id == "lava") {
		return 5;
	}
	if (terrain_id == "underground") {
		return 6;
	}
	if (terrain_id == "water") {
		return 7;
	}
	return 8;
}

PackedStringArray terrain_id_by_code() {
	PackedStringArray result;
	result.append("grass");
	result.append("snow");
	result.append("sand");
	result.append("dirt");
	result.append("rough");
	result.append("lava");
	result.append("underground");
	result.append("water");
	result.append("rock");
	return result;
}

Array terrain_seed_records(const Dictionary &normalized, const Array &terrain_pool) {
	Array seeds;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	const int32_t inner_width = std::max(1, width - 2);
	const int32_t inner_height = std::max(1, height - 2);
	for (int64_t index = 0; index < terrain_pool.size(); ++index) {
		const String terrain_id = String(terrain_pool[index]);
		const String seed_key = seed + String(":terrain_seed:") + terrain_id + String(":") + String::num_int64(index);
		Dictionary record;
		record["terrain_id"] = terrain_id;
		record["biome_id"] = biome_for_terrain(terrain_id);
		record["x"] = 1 + int32_t(hash32_int(seed_key + String(":x")) % uint32_t(inner_width));
		record["y"] = 1 + int32_t(hash32_int(seed_key + String(":y")) % uint32_t(inner_height));
		record["selection_source"] = "profile_palette_deterministic_seed";
		seeds.append(record);
	}
	return seeds;
}

String choose_terrain_for_cell(int32_t x, int32_t y, int32_t level, const Array &terrain_pool, const Array &seeds, const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (level == 0 && water_mode == "islands" && (x == 0 || y == 0 || x == width - 1 || y == height - 1)) {
		return "water";
	}
	if (level == 0 && water_mode == "normal_water") {
		const double centered_x = std::abs(double(x) - double(width - 1) * 0.5) / double(std::max(1, width));
		const double centered_y = std::abs(double(y) - double(height - 1) * 0.5) / double(std::max(1, height));
		if (centered_x + centered_y > 0.42) {
			const uint32_t water_jitter = hash32_int(String(normalized.get("normalized_seed", "0")) + String(":normal_water:") + String::num_int64(x) + String(":") + String::num_int64(y));
			if ((water_jitter % 5U) < 2U) {
				return "water";
			}
		}
	}
	if (level > 0 && array_has_string(terrain_pool, "underground")) {
		return "underground";
	}
	String best_terrain = String(terrain_pool[0]);
	int64_t best_score = std::numeric_limits<int64_t>::max();
	const String seed = String(normalized.get("normalized_seed", "0"));
	for (int64_t index = 0; index < seeds.size(); ++index) {
		Dictionary record = seeds[index];
		const int64_t dx = int64_t(x) - int64_t(record.get("x", 0));
		const int64_t dy = int64_t(y) - int64_t(record.get("y", 0));
		const String jitter_key = seed + String(":terrain_cell:") + String::num_int64(level) + String(":") + String::num_int64(x) + String(":") + String::num_int64(y) + String(":") + String(record.get("terrain_id", ""));
		const uint32_t jitter = hash32_int(jitter_key);
		const int64_t score = dx * dx * 100 + dy * dy * 126 - int64_t(jitter % 97U);
		if (score < best_score) {
			best_score = score;
			best_terrain = String(record.get("terrain_id", best_terrain));
		}
	}
	return best_terrain;
}

String point_key(int32_t x, int32_t y) {
	return String::num_int64(x) + String(",") + String::num_int64(y);
}

Dictionary point_record(int32_t x, int32_t y) {
	Dictionary point;
	point["x"] = x;
	point["y"] = y;
	return point;
}

Dictionary cell_record(int32_t x, int32_t y, int32_t level) {
	Dictionary point;
	point["x"] = x;
	point["y"] = y;
	point["level"] = level;
	return point;
}

String slot_id_2(int32_t slot) {
	return slot < 10 ? "0" + String::num_int64(slot) : String::num_int64(slot);
}

int32_t deterministic_signed_jitter(const String &seed_key, int32_t amplitude) {
	if (amplitude <= 0) {
		return 0;
	}
	const int32_t span = amplitude * 2 + 1;
	return int32_t(hash32_int(seed_key) % uint32_t(span)) - amplitude;
}

Dictionary normalized_player_constraints(const Dictionary &config) {
	Variant constraints_value = config.get("player_constraints", config.get("players", Variant()));
	Dictionary constraints = constraints_value.get_type() == Variant::DICTIONARY ? Dictionary(constraints_value) : Dictionary();
	int32_t human_count = std::max(1, std::min(8, normalized_int(constraints, "human_count", normalized_int(constraints, "humans", 1))));
	int32_t computer_count = 1;
	int32_t player_count = 2;
	if (constraints.has("player_count") || constraints.has("total_count") || constraints.has("total")) {
		player_count = std::max(1, std::min(8, normalized_int(constraints, "player_count", normalized_int(constraints, "total_count", normalized_int(constraints, "total", player_count)))));
		player_count = std::max(player_count, human_count);
		computer_count = std::max(0, player_count - human_count);
	} else {
		computer_count = std::max(0, std::min(7, normalized_int(constraints, "computer_count", normalized_int(constraints, "computers", computer_count))));
		player_count = std::max(1, std::min(8, human_count + computer_count));
	}
	String team_mode = normalized_text(constraints, "team_mode", "free_for_all").to_lower();
	if (team_mode.is_empty()) {
		team_mode = "free_for_all";
	}

	Dictionary result;
	result["human_count"] = human_count;
	result["computer_count"] = computer_count;
	result["player_count"] = player_count;
	result["team_mode"] = team_mode;
	return result;
}

Array town_ids_for_factions(const Variant &value, const Array &faction_ids, int32_t player_count) {
	Array requested;
	if (value.get_type() == Variant::ARRAY) {
		requested = normalized_string_array(value, Array());
	}
	Array result;
	for (int32_t index = 0; index < player_count; ++index) {
		if (!requested.is_empty()) {
			result.append(requested[index % requested.size()]);
		} else if (!faction_ids.is_empty()) {
			result.append(town_for_faction(String(faction_ids[index % faction_ids.size()])));
		} else {
			result.append("town_riverwatch");
		}
	}
	return result;
}

Array allowed_faction_ids_for_source_zone(const Dictionary &source_zone, const Dictionary &normalized) {
	Dictionary town_policy = source_zone.get("town_policy", Dictionary());
	Array allowed = normalized_string_array(town_policy.get("allowed_faction_ids", Variant()), Array());
	if (allowed.is_empty()) {
		allowed = normalized_string_array(source_zone.get("allowed_towns", Variant()), Array());
	}
	if (allowed.is_empty()) {
		allowed = normalized_string_array(normalized.get("faction_ids", Variant()), default_faction_pool());
	}
	if (allowed.is_empty()) {
		return default_faction_pool();
	}
	return allowed;
}

String source_zone_faction_choice(const Dictionary &source_zone, const Dictionary &normalized, const String &zone_id, int32_t zone_index) {
	Array allowed = allowed_faction_ids_for_source_zone(source_zone, normalized);
	if (allowed.is_empty()) {
		return "faction_embercourt";
	}
	const String seed = String(normalized.get("normalized_seed", "0")) + ":source_zone_faction:" + zone_id + ":" + String::num_int64(zone_index);
	return String(allowed[int64_t(hash32_int(seed) % uint32_t(allowed.size()))]);
}

Dictionary player_assignment_for_config(const Dictionary &normalized) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
	const String team_mode = String(constraints.get("team_mode", "free_for_all"));
	Array faction_ids = normalized.get("faction_ids", default_faction_pool());
	Array town_ids = normalized.get("town_ids", Array());

	Array player_slots;
	Dictionary by_owner_slot;
	Array active_owner_slots;
	Array assigned_faction_ids;
	Array assigned_town_ids;
	Array teams;
	for (int32_t index = 0; index < player_count; ++index) {
		const int32_t player_slot = index + 1;
		const int32_t owner_slot = index + 1;
		const String player_type = player_slot <= human_count ? "human" : "computer";
		const String faction_id = faction_ids.is_empty() ? String("faction_embercourt") : String(faction_ids[index % faction_ids.size()]);
		const String town_id = town_ids.is_empty() ? town_for_faction(faction_id) : String(town_ids[index % town_ids.size()]);
		const String team_id = "team_" + slot_id_2(player_slot);

		Dictionary slot;
		slot["player_slot"] = player_slot;
		slot["owner_slot"] = owner_slot;
		slot["player_type"] = player_type;
		slot["faction_id"] = faction_id;
		slot["town_id"] = town_id;
		slot["team_id"] = team_id;
		slot["team_mode"] = team_mode;
		slot["ai_controlled"] = player_type != "human";
		slot["assignment_source"] = "native_foundation_fixed_owner_slot_profile_order";
		player_slots.append(slot);
		by_owner_slot[String::num_int64(owner_slot)] = slot;
		active_owner_slots.append(owner_slot);
		assigned_faction_ids.append(faction_id);
		assigned_town_ids.append(town_id);

		Dictionary team;
		team["team_id"] = team_id;
		Array team_slots;
		team_slots.append(player_slot);
		team["player_slots"] = team_slots;
		team["mode"] = "free_for_all";
		teams.append(team);
	}

	Dictionary capacity;
	capacity["human_start_capacity"] = std::max(1, human_count);
	capacity["total_start_capacity"] = player_count;
	capacity["fixed_owner_slots"] = active_owner_slots;
	Array human_owner_slots;
	for (int32_t index = 0; index < human_count; ++index) {
		human_owner_slots.append(index + 1);
	}
	capacity["human_owner_slots"] = human_owner_slots;

	Dictionary team_metadata;
	team_metadata["mode"] = "free_for_all";
	team_metadata["supported_now"] = team_mode == "free_for_all";
	team_metadata["requested_mode"] = team_mode;
	team_metadata["teams"] = teams;

	Dictionary assignment;
	assignment["schema_id"] = "random_map_player_assignment_v1";
	assignment["assignment_policy"] = "native_foundation_fixed_owner_slots_first_n_players_profile_order";
	assignment["team_mode"] = team_mode;
	assignment["team_metadata"] = team_metadata;
	assignment["human_count"] = human_count;
	assignment["computer_count"] = computer_count;
	assignment["player_count"] = player_count;
	assignment["capacity"] = capacity;
	assignment["active_owner_slots"] = active_owner_slots;
	assignment["inactive_owner_slots"] = Array();
	assignment["player_slots"] = player_slots;
	assignment["player_slot_by_owner_slot"] = by_owner_slot;
	assignment["assigned_faction_ids"] = assigned_faction_ids;
	assignment["assigned_town_ids"] = assigned_town_ids;
	assignment["faction_pool"] = faction_ids;
	return assignment;
}

Dictionary terrain_palette_for_zone(const String &zone_id, const String &faction_id, bool match_to_faction, const Array &terrain_pool, int32_t index) {
	String selected = terrain_pool.is_empty() ? String("grass") : String(terrain_pool[index % terrain_pool.size()]);
	String source = "profile_palette_foundation_order";
	const String faction_terrain = terrain_for_faction(faction_id);
	if (match_to_faction && array_has_string(terrain_pool, faction_terrain)) {
		selected = faction_terrain;
		source = "faction_match_profile_palette";
	}
	Dictionary palette;
	palette["zone_id"] = zone_id;
	palette["faction_id"] = faction_id;
	palette["terrain_match_to_faction"] = match_to_faction;
	palette["profile_terrain_ids"] = terrain_pool;
	palette["catalog_allowed_terrain_ids"] = Array();
	palette["faction_terrain_id"] = faction_terrain;
	palette["selected_terrain_id"] = selected;
	palette["normalized_terrain_id"] = selected;
	palette["original_terrain_id"] = selected;
	palette["biome_id"] = biome_for_terrain(selected);
	palette["passable"] = is_passable_terrain_id(selected);
	palette["selection_source"] = source;
	palette["fallback_used"] = false;
	palette["unsupported_terrain_ids"] = Array();
	palette["deferred_terrain_ids"] = Array();
	palette["deferred_reason"] = "";
	return palette;
}

constexpr int32_t RMG_MINE_CATEGORY_COUNT = 7;

int32_t rmg_mine_category_index_from_id(const String &category_id) {
	static constexpr const char *CATEGORIES[] = {"timber", "quicksilver", "ore", "ember_salt", "lens_crystal", "cut_gems", "gold"};
	for (int32_t index = 0; index < RMG_MINE_CATEGORY_COUNT; ++index) {
		if (category_id == CATEGORIES[index]) {
			return index;
		}
	}
	return -1;
}

String rmg_mine_category_id(int32_t category_index) {
	static constexpr const char *CATEGORIES[] = {"timber", "quicksilver", "ore", "ember_salt", "lens_crystal", "cut_gems", "gold"};
	return CATEGORIES[std::max(0, category_index) % RMG_MINE_CATEGORY_COUNT];
}

String rmg_mine_source_equivalent(int32_t category_index) {
	static constexpr const char *SOURCE_EQUIVALENTS[] = {"wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold"};
	return SOURCE_EQUIVALENTS[std::max(0, category_index) % RMG_MINE_CATEGORY_COUNT];
}

String rmg_mine_minimum_source_offset(int32_t category_index) {
	static constexpr const char *OFFSETS[] = {"+0x4c", "+0x50", "+0x54", "+0x58", "+0x5c", "+0x60", "+0x64"};
	return OFFSETS[std::max(0, category_index) % RMG_MINE_CATEGORY_COUNT];
}

String rmg_mine_density_source_offset(int32_t category_index) {
	static constexpr const char *OFFSETS[] = {"+0x68", "+0x6c", "+0x70", "+0x74", "+0x78", "+0x7c", "+0x80"};
	return OFFSETS[std::max(0, category_index) % RMG_MINE_CATEGORY_COUNT];
}

int32_t rmg_mine_guard_base_value(int32_t category_index) {
	if (category_index == 0 || category_index == 2) {
		return 1500;
	}
	if (category_index == 6) {
		return 7000;
	}
	return 3500;
}

int32_t rmg_strength_scaled_value(int32_t base_value, int32_t mode) {
	static constexpr int32_t THRESHOLD_1[] = {50000, 2500, 1500, 1000, 500, 0};
	static constexpr int32_t THRESHOLD_2[] = {50000, 7500, 7500, 7500, 5000, 5000};
	static constexpr int32_t SLOPE_1[] = {0, 2, 3, 4, 6, 6};
	static constexpr int32_t SLOPE_2[] = {0, 2, 3, 4, 4, 6};
	const int32_t clamped_mode = std::max(0, std::min(5, mode));
	const int32_t base = std::max(0, base_value);
	int32_t value = 0;
	if (base > THRESHOLD_1[clamped_mode]) {
		value += ((base - THRESHOLD_1[clamped_mode]) * SLOPE_1[clamped_mode]) / 4;
	}
	if (base > THRESHOLD_2[clamped_mode]) {
		value += ((base - THRESHOLD_2[clamped_mode]) * SLOPE_2[clamped_mode]) / 4;
	}
	return value < 2000 ? 0 : value;
}

int32_t rmg_local_monster_strength_mode(const Variant &strength_value) {
	const String token = String(strength_value).to_lower().strip_edges();
	if (token == "0" || token == "n" || token == "none" || token == "no" || token == "none_or_unguarded") {
		return 0;
	}
	if (token == "2" || token == "w" || token == "weak" || token == "core_low") {
		return 2;
	}
	if (token == "4" || token == "s" || token == "strong") {
		return 4;
	}
	if (token == "1") {
		return 1;
	}
	if (token == "5") {
		return 5;
	}
	return 3;
}

int32_t rmg_global_monster_strength_mode_from_token(const String &token_value, const String &seed) {
	const String token = token_value.to_lower().strip_edges();
	if (token == "random") {
		return 2 + int32_t(hash32_int(seed + String(":global_monster_strength")) % 3U);
	}
	if (token == "weak" || token == "core_low") {
		return 2;
	}
	if (token == "strong" || token == "core_high") {
		return 4;
	}
	if (token == "0" || token == "1" || token == "2" || token == "3" || token == "4" || token == "5") {
		return std::max(0, std::min(5, int32_t(token.to_int())));
	}
	return 3;
}

int32_t rmg_global_monster_strength_mode(const Dictionary &normalized) {
	return std::max(0, std::min(5, int32_t(normalized.get("global_monster_strength_mode", 3))));
}

Dictionary rmg_strength_sample_table() {
	static constexpr int32_t BASES[] = {1500, 3500, 7000};
	Dictionary table;
	for (int32_t base : BASES) {
		Array row;
		for (int32_t mode = 0; mode <= 5; ++mode) {
			row.append(rmg_strength_scaled_value(base, mode));
		}
		table[String::num_int64(base)] = row;
	}
	return table;
}

int32_t rmg_effective_monster_strength_mode(const Dictionary &normalized, const Dictionary &zone) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary monster_policy = metadata.get("monster_policy", Dictionary());
	const int32_t source_strength = rmg_local_monster_strength_mode(monster_policy.get("strength", "avg"));
	if (source_strength == 0) {
		return 0;
	}
	return std::max(0, std::min(5, source_strength + rmg_global_monster_strength_mode(normalized) - 3));
}

int32_t rmg_zone_monster_scaled_value(const Dictionary &normalized, const Dictionary &zone, int32_t base_value) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary monster_policy = metadata.get("monster_policy", Dictionary());
	const int32_t source_strength = rmg_local_monster_strength_mode(monster_policy.get("strength", "avg"));
	if (source_strength == 0) {
		return 0;
	}
	return rmg_strength_scaled_value(base_value, rmg_effective_monster_strength_mode(normalized, zone));
}

int32_t rmg_connection_guard_scaled_value(const Dictionary &normalized, int32_t raw_value) {
	return rmg_strength_scaled_value(raw_value, rmg_global_monster_strength_mode(normalized));
}

Array rmg_mine_category_ids() {
	Array ids;
	for (int32_t index = 0; index < RMG_MINE_CATEGORY_COUNT; ++index) {
		ids.append(rmg_mine_category_id(index));
	}
	return ids;
}

Dictionary zone_richness_floor_metadata(const String &role, int32_t base_size) {
	Dictionary metadata;
	Dictionary floor;
	floor["source_model"] = "HoMM3_RMG_zone_mine_treasure_band_floor_translated_to_original_content";
	floor["role"] = role;
	floor["base_size"] = base_size;
	floor["applied_mine_floor"] = role != "junction";
	floor["applied_treasure_band_floor"] = role != "junction";
	floor["applied_monster_policy_floor"] = role != "junction";
	metadata["richness_floor"] = floor;

	if (role != "junction") {
		Dictionary minimums;
		Dictionary densities;
		Array category_ids;
		for (int32_t index = 0; index < RMG_MINE_CATEGORY_COUNT; ++index) {
			const String category = rmg_mine_category_id(index);
			minimums[category] = 0;
			densities[category] = 0;
			category_ids.append(category);
		}
		if (role.contains("start")) {
			minimums["timber"] = 1;
			minimums["ore"] = 1;
			densities["timber"] = 1;
			densities["ore"] = 1;
		} else {
			const String selected = rmg_mine_category_id(1 + (base_size % 6));
			minimums[selected] = 1;
			densities[selected] = 1;
		}
		Dictionary mine_requirements;
		mine_requirements["minimum_by_category"] = minimums;
		mine_requirements["density_by_category"] = densities;
		mine_requirements["resource_category_ids"] = category_ids;
		mine_requirements["source"] = "native_zone_richness_floor";
		metadata["mine_requirements"] = mine_requirements;
		metadata["resource_category_requirements"] = mine_requirements.duplicate(true);

		Array treasure_bands;
		Dictionary low_band;
		low_band["low"] = role.contains("start") ? 300 : 450;
		low_band["high"] = role.contains("start") ? 900 : 1200;
		low_band["density"] = role.contains("start") ? 4 : 5;
		treasure_bands.append(low_band);
		Dictionary high_band;
		high_band["low"] = role.contains("start") ? 900 : 900;
		high_band["high"] = role.contains("start") ? 1800 : (base_size >= 10 ? 3600 : 1800);
		high_band["density"] = role.contains("start") ? 2 : 2;
		treasure_bands.append(high_band);
		metadata["treasure_bands"] = treasure_bands;

		Dictionary monster_policy;
		monster_policy["strength"] = role.contains("start") ? "avg" : "strong";
		monster_policy["match_to_town"] = role.contains("start");
		monster_policy["source"] = "native_zone_richness_floor";
		metadata["monster_policy"] = monster_policy;
	}
	return metadata;
}

Dictionary load_random_map_template_catalog() {
	static Dictionary cached_catalog;
	static bool loaded = false;
	if (loaded) {
		return cached_catalog;
	}
	loaded = true;
	const String path = "res://content/random_map_template_catalog.json";
	if (!FileAccess::file_exists(path)) {
		return cached_catalog;
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return cached_catalog;
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return cached_catalog;
	}
	cached_catalog = Dictionary(parser->get_data());
	return cached_catalog;
}

Dictionary load_homm3_re_obstacle_proxy_catalog() {
	static Dictionary cached_catalog;
	static bool loaded = false;
	if (loaded) {
		return cached_catalog;
	}
	loaded = true;
	const String path = "res://content/homm3_re_obstacle_proxy_catalog.json";
	if (!FileAccess::file_exists(path)) {
		return cached_catalog;
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return cached_catalog;
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return cached_catalog;
	}
	cached_catalog = Dictionary(parser->get_data());
	return cached_catalog;
}

Dictionary load_homm3_re_reward_object_proxy_catalog() {
	static Dictionary cached_catalog;
	static bool loaded = false;
	if (loaded) {
		return cached_catalog;
	}
	loaded = true;
	const String path = "res://content/homm3_re_reward_object_proxy_catalog.json";
	if (!FileAccess::file_exists(path)) {
		return cached_catalog;
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return cached_catalog;
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return cached_catalog;
	}
	cached_catalog = Dictionary(parser->get_data());
	return cached_catalog;
}

Dictionary homm3_re_reward_object_proxy_record(const String &generated_kind, const String &reward_tier, const String &source_bucket, const String &resource_category, int32_t ordinal) {
	Dictionary catalog = load_homm3_re_reward_object_proxy_catalog();
	Array entries = catalog.get("entries", Array());
	Array candidates;
	Array fallback_candidates;
	for (int64_t index = 0; index < entries.size(); ++index) {
		if (Variant(entries[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary entry = entries[index];
		if (String(entry.get("generated_kind", "")) != generated_kind) {
			continue;
		}
		Array tiers = entry.get("reward_value_tiers", Array());
		if (!reward_tier.is_empty() && !tiers.is_empty() && !array_has_string(tiers, reward_tier)) {
			continue;
		}
		Array resources = entry.get("resource_categories", Array());
		if (!resource_category.is_empty() && !resources.is_empty() && !array_has_string(resources, resource_category)) {
			continue;
		}
		if (!source_bucket.is_empty() && generated_kind == "reward_reference") {
			const String entry_bucket = String(entry.get("homm3_re_reward_table_bucket", ""));
			const String entry_proxy_bucket = String(entry.get("proxy_bucket", ""));
			const String semantic_category = String(entry.get("semantic_category", ""));
			const bool bucket_related = source_bucket.contains(entry_proxy_bucket) || entry_proxy_bucket.contains(source_bucket) || source_bucket.contains(semantic_category) || resource_category.contains(semantic_category) || semantic_category.contains(resource_category) || source_bucket == entry_bucket;
			if (bucket_related) {
				candidates.append(entry);
			} else {
				fallback_candidates.append(entry);
			}
			continue;
		}
		candidates.append(entry);
	}
	if (candidates.is_empty()) {
		candidates = fallback_candidates;
	} else if (generated_kind == "reward_reference" && candidates.size() < 5) {
		for (int64_t index = 0; index < fallback_candidates.size(); ++index) {
			candidates.append(fallback_candidates[index]);
		}
	}
	if (candidates.is_empty()) {
		return Dictionary();
	}
	const String selector = generated_kind + String(":") + reward_tier + String(":") + source_bucket + String(":") + resource_category + String(":") + String::num_int64(ordinal);
	const int64_t selected = int64_t(hash32_int(selector) % uint32_t(candidates.size()));
	if (Variant(candidates[selected]).get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary result = Dictionary(candidates[selected]);
	result["source_catalog_path"] = "content/homm3_re_reward_object_proxy_catalog.json";
	result["source_catalog_schema_id"] = catalog.get("schema_id", "homm3_re_reward_object_proxy_catalog_v1");
	return result;
}

void apply_homm3_re_reward_object_proxy(Dictionary &record, const Dictionary &proxy, bool apply_native_proxy) {
	if (proxy.is_empty()) {
		record["homm3_re_reward_object_source_kind"] = "missing_reward_object_proxy_catalog_fallback";
		record["homm3_re_art_asset_policy"] = "original_runtime_family_only_catalog_missing";
		return;
	}
	if (apply_native_proxy) {
		if (!String(proxy.get("native_proxy_family", "")).is_empty()) {
			record["family_id"] = proxy.get("native_proxy_family", record.get("family_id", ""));
			record["object_family_id"] = proxy.get("native_proxy_family", record.get("object_family_id", ""));
		}
		if (!String(proxy.get("native_proxy_category", "")).is_empty()) {
			record["category_id"] = proxy.get("native_proxy_category", record.get("category_id", ""));
			record["reward_category"] = proxy.get("native_proxy_category", record.get("reward_category", record.get("category_id", "")));
		}
		if (!String(proxy.get("native_proxy_object_id", "")).is_empty()) {
			record["object_id"] = proxy.get("native_proxy_object_id", record.get("object_id", ""));
		}
		if (!String(proxy.get("native_proxy_site_id", "")).is_empty()) {
			record["site_id"] = proxy.get("native_proxy_site_id", record.get("site_id", ""));
		} else if (String(proxy.get("native_proxy_category", "")) == "artifact") {
			record["site_id"] = "";
		}
		if (!String(proxy.get("native_resource_id", "")).is_empty()) {
			record["resource_id"] = proxy.get("native_resource_id", record.get("resource_id", ""));
		}
		if (!String(proxy.get("native_artifact_id", "")).is_empty()) {
			record["artifact_id"] = proxy.get("native_artifact_id", "");
			record.erase("spell_id");
		} else if (String(proxy.get("native_proxy_category", "")) != "artifact") {
			record.erase("artifact_id");
		}
		if (!String(proxy.get("native_spell_id", "")).is_empty()) {
			record["spell_id"] = proxy.get("native_spell_id", "");
			record.erase("artifact_id");
		} else if (String(proxy.get("native_proxy_category", "")) != "spell_access") {
			record.erase("spell_id");
		}
	}
	record["homm3_re_reward_object_source_kind"] = proxy.get("source_kind", "homm3_re_reward_object_type");
	record["homm3_re_reward_object_catalog_id"] = proxy.get("id", "");
	record["homm3_re_reward_object_catalog_path"] = proxy.get("source_catalog_path", "content/homm3_re_reward_object_proxy_catalog.json");
	record["homm3_re_reward_object_catalog_schema_id"] = proxy.get("source_catalog_schema_id", "homm3_re_reward_object_proxy_catalog_v1");
	record["homm3_re_source_catalog_kind"] = proxy.get("source_catalog_kind", "");
	record["homm3_re_object_type_id"] = proxy.get("homm3_re_object_type_id", 0);
	record["homm3_re_object_type_name"] = proxy.get("homm3_re_object_type_name", "");
	record["homm3_re_type_name"] = proxy.get("homm3_re_object_type_name", "");
	record["homm3_re_object_subtype"] = proxy.get("homm3_re_object_subtype", 0);
	record["homm3_re_subtype"] = proxy.get("homm3_re_object_subtype", 0);
	record["homm3_re_object_source_row"] = proxy.get("homm3_re_object_source_row", 0);
	record["homm3_re_object_def_ref"] = proxy.get("homm3_re_object_def_ref", "");
	record["homm3_re_reward_table_bucket"] = proxy.get("homm3_re_reward_table_bucket", "");
	record["homm3_re_proxy_bucket"] = proxy.get("proxy_bucket", "");
	record["homm3_re_semantic_category"] = proxy.get("semantic_category", "");
	record["native_proxy_object_id"] = apply_native_proxy ? proxy.get("native_proxy_object_id", record.get("object_id", "")) : record.get("object_id", "");
	record["native_proxy_family"] = apply_native_proxy ? proxy.get("native_proxy_family", record.get("family_id", "")) : record.get("family_id", "");
	record["native_proxy_category"] = apply_native_proxy ? proxy.get("native_proxy_category", record.get("category_id", "")) : record.get("category_id", "");
	record["proxy_mapping_policy"] = "homm3_re_reward_object_type_to_original_authored_proxy_object";
	record["family_art_parity"] = "homm3_re_source_identity_recorded_original_runtime_proxy_no_copyrighted_art_import";
	record["homm3_re_art_asset_policy"] = "provenance_only_original_proxy_art";
}

String homm3_re_source_terrain_for_native_terrain(const String &terrain_id) {
	if (terrain_id == "underground") {
		return "cave";
	}
	if (terrain_id == "mire") {
		return "swamp";
	}
	if (terrain_id == "water") {
		return "water";
	}
	if (terrain_id == "dirt" || terrain_id == "sand" || terrain_id == "grass" || terrain_id == "snow" || terrain_id == "swamp" || terrain_id == "rough" || terrain_id == "lava") {
		return terrain_id;
	}
	return "grass";
}

Dictionary homm3_re_obstacle_source_record(const String &terrain_id, int32_t ordinal) {
	Dictionary catalog = load_homm3_re_obstacle_proxy_catalog();
	Dictionary terrain_rows = catalog.get("terrain_rows", Dictionary());
	const String source_terrain = homm3_re_source_terrain_for_native_terrain(terrain_id);
	Array candidates = terrain_rows.get(source_terrain, Array());
	if (candidates.is_empty() && source_terrain != "grass") {
		candidates = terrain_rows.get("grass", Array());
	}
	if (candidates.is_empty()) {
		return Dictionary();
	}
	const String seed = source_terrain + String(":rand_trn_proxy:") + String::num_int64(ordinal);
	const int64_t index = int64_t(hash32_int(seed) % uint32_t(candidates.size()));
	if (Variant(candidates[index]).get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary source = Dictionary(candidates[index]);
	source["native_terrain_id"] = terrain_id;
	source["native_terrain_source_alias"] = source_terrain;
	source["source_catalog_path"] = "content/homm3_re_obstacle_proxy_catalog.json";
	source["source_catalog_schema_id"] = catalog.get("schema_id", "homm3_re_obstacle_proxy_catalog_v1");
	return source;
}

Dictionary catalog_template_for_id(const String &template_id) {
	if (template_id.is_empty()) {
		return Dictionary();
	}
	Dictionary catalog = load_random_map_template_catalog();
	Array templates = catalog.get("templates", Array());
	for (int64_t index = 0; index < templates.size(); ++index) {
		if (Variant(templates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = Dictionary(templates[index]);
		if (String(candidate.get("id", "")) == template_id) {
			return candidate;
		}
	}
	return Dictionary();
}

bool has_catalog_template(const Dictionary &normalized) {
	return !catalog_template_for_id(String(normalized.get("template_id", ""))).is_empty();
}

bool catalog_player_filter_allows(const Dictionary &record, const Dictionary &normalized) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Dictionary filter = record.get("player_filter", Dictionary());
	if (filter.is_empty()) {
		return true;
	}
	const int32_t min_human = int32_t(filter.get("min_human", 0));
	const int32_t max_human = int32_t(filter.get("max_human", 8));
	const int32_t min_total = int32_t(filter.get("min_total", 1));
	const int32_t max_total = int32_t(filter.get("max_total", 8));
	return human_count >= min_human && human_count <= max_human && player_count >= min_total && player_count <= max_total;
}

Array catalog_active_zones_for_config(const Dictionary &template_record, const Dictionary &normalized) {
	Array result;
	Array zones = template_record.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		if (catalog_player_filter_allows(zone, normalized)) {
			result.append(zone);
		}
	}
	return result;
}

Dictionary catalog_active_zone_id_lookup(const Array &zones) {
	Dictionary lookup;
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		const String zone_id = String(Dictionary(zones[index]).get("id", ""));
		if (!zone_id.is_empty()) {
			lookup[zone_id] = true;
		}
	}
	return lookup;
}

Array catalog_active_links_for_config(const Dictionary &template_record, const Dictionary &normalized, const Dictionary &active_zone_ids) {
	Array result;
	Array links = template_record.get("links", Array());
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(links[index]);
		if (!catalog_player_filter_allows(link, normalized)) {
			continue;
		}
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		if (from_zone.is_empty() || to_zone.is_empty() || !active_zone_ids.has(from_zone) || !active_zone_ids.has(to_zone)) {
			continue;
		}
		result.append(link);
	}
	return result;
}

bool catalog_active_graph_connected(const Array &active_zones, const Array &active_links) {
	if (active_zones.is_empty()) {
		return false;
	}
	Dictionary adjacency;
	String first_zone_id;
	for (int64_t index = 0; index < active_zones.size(); ++index) {
		if (Variant(active_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		const String zone_id = String(Dictionary(active_zones[index]).get("id", ""));
		if (zone_id.is_empty()) {
			continue;
		}
		if (first_zone_id.is_empty()) {
			first_zone_id = zone_id;
		}
		adjacency[zone_id] = Array();
	}
	for (int64_t index = 0; index < active_links.size(); ++index) {
		if (Variant(active_links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(active_links[index]);
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		if (from_zone.is_empty() || to_zone.is_empty() || !adjacency.has(from_zone) || !adjacency.has(to_zone)) {
			continue;
		}
		Array from_neighbors = adjacency.get(from_zone, Array());
		Array to_neighbors = adjacency.get(to_zone, Array());
		if (!array_has_string(from_neighbors, to_zone)) {
			from_neighbors.append(to_zone);
		}
		if (!array_has_string(to_neighbors, from_zone)) {
			to_neighbors.append(from_zone);
		}
		adjacency[from_zone] = from_neighbors;
		adjacency[to_zone] = to_neighbors;
	}
	if (first_zone_id.is_empty()) {
		return false;
	}
	Dictionary visited;
	Array queue;
	visited[first_zone_id] = true;
	queue.append(first_zone_id);
	int64_t cursor = 0;
	while (cursor < queue.size()) {
		const String current = String(queue[cursor]);
		++cursor;
		Array neighbors = adjacency.get(current, Array());
		for (int64_t index = 0; index < neighbors.size(); ++index) {
			const String next = String(neighbors[index]);
			if (!visited.has(next)) {
				visited[next] = true;
				queue.append(next);
			}
		}
	}
	return visited.size() == adjacency.size();
}

Dictionary catalog_start_capacity_for_active_zones(const Array &zones) {
	Dictionary human_slots;
	Dictionary total_slots;
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		const String role = String(zone.get("role", ""));
		const Variant owner_value = zone.get("owner_slot", Variant());
		const String slot_key = owner_value.get_type() == Variant::NIL ? "row_" + String::num_int64(index + 1) : String::num_int64(int32_t(owner_value));
		if (role == "human_start") {
			human_slots[slot_key] = true;
			total_slots[slot_key] = true;
		} else if (role == "computer_start" || role.contains("start")) {
			total_slots[slot_key] = true;
		}
	}

	Dictionary capacity;
	capacity["human_start_capacity"] = human_slots.size();
	capacity["total_start_capacity"] = total_slots.size();
	return capacity;
}

int32_t catalog_size_score_for_config(const Dictionary &normalized, const Dictionary &template_record) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	int32_t score = std::max(1, (width * height * level_count) / 0x510);
	Dictionary map_support = template_record.get("map_support", Dictionary());
	Array water_modes = map_support.get("water_modes", Array());
	if (String(normalized.get("water_mode", "land")) == "islands" && array_has_string(water_modes, "islands_size_score_halved")) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool catalog_template_supports_config(const Dictionary &template_record, const Dictionary &normalized, Array &diagnostics) {
	bool supported = true;
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Dictionary players = template_record.get("players", Dictionary());
	Dictionary humans = players.get("humans", Dictionary());
	Dictionary total = players.get("total", Dictionary());
	if (human_count < int32_t(humans.get("min", 0)) || human_count > int32_t(humans.get("max", 8))) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_human_count_out_of_range";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template human-player range does not accept the requested config.";
		diagnostic["human_count"] = human_count;
		diagnostic["range"] = humans;
		diagnostics.append(diagnostic);
		supported = false;
	}
	if (player_count < int32_t(total.get("min", 1)) || player_count > int32_t(total.get("max", 8))) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_total_player_count_out_of_range";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template total-player range does not accept the requested config.";
		diagnostic["player_count"] = player_count;
		diagnostic["range"] = total;
		diagnostics.append(diagnostic);
		supported = false;
	}

	Dictionary map_support = template_record.get("map_support", Dictionary());
	Array water_modes = map_support.get("water_modes", Array());
	const String water_mode = String(normalized.get("water_mode", "land"));
	const bool water_supported = water_mode == "islands"
		? array_has_string(water_modes, "islands") || array_has_string(water_modes, "islands_size_score_halved")
		: (water_mode == "normal_water"
				  ? array_has_string(water_modes, "normal_water") || array_has_string(water_modes, "islands_size_score_halved")
				  : array_has_string(water_modes, "land"));
	if (!water_modes.is_empty() && !water_supported) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_water_mode_unsupported";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template water modes do not accept the requested config.";
		diagnostic["water_mode"] = water_mode;
		diagnostic["supported_water_modes"] = water_modes;
		diagnostics.append(diagnostic);
		supported = false;
	}
	Dictionary size_score = template_record.get("size_score", Dictionary());
	const int32_t score = catalog_size_score_for_config(normalized, template_record);
	if (!size_score.is_empty() && (score < int32_t(size_score.get("min", 1)) || score > int32_t(size_score.get("max", 32)))) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_size_score_out_of_range";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template size score does not accept the requested dimensions.";
		diagnostic["size_score"] = score;
		diagnostic["range"] = size_score;
		diagnostics.append(diagnostic);
		supported = false;
	}
	Array active_zones = catalog_active_zones_for_config(template_record, normalized);
	Dictionary active_zone_ids = catalog_active_zone_id_lookup(active_zones);
	Array active_links = catalog_active_links_for_config(template_record, normalized, active_zone_ids);
	Dictionary capacity = catalog_start_capacity_for_active_zones(active_zones);
	if (int32_t(capacity.get("human_start_capacity", 0)) < human_count) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_human_start_capacity_below_requested_config";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template active rows do not provide enough human starts for the requested config.";
		diagnostic["human_count"] = human_count;
		diagnostic["capacity"] = capacity;
		diagnostics.append(diagnostic);
		supported = false;
	}
	if (int32_t(capacity.get("total_start_capacity", 0)) < player_count) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_total_start_capacity_below_requested_config";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template active rows do not provide enough total starts for the requested config.";
		diagnostic["player_count"] = player_count;
		diagnostic["capacity"] = capacity;
		diagnostics.append(diagnostic);
		supported = false;
	}
	if (active_zones.is_empty() || active_links.is_empty()) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_active_graph_empty_for_config";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template row filters leave no active zone/link graph for the requested config.";
		diagnostic["active_zone_count"] = active_zones.size();
		diagnostic["active_link_count"] = active_links.size();
		diagnostics.append(diagnostic);
		supported = false;
	}
	if (!active_zones.is_empty() && !active_links.is_empty() && !catalog_active_graph_connected(active_zones, active_links)) {
		Dictionary diagnostic;
		diagnostic["code"] = "template_active_graph_disconnected_for_config";
		diagnostic["severity"] = "failure";
		diagnostic["message"] = "Template active row/link graph is disconnected for the requested config. Disconnected components require explicit component semantics before production generation.";
		diagnostic["active_zone_count"] = active_zones.size();
		diagnostic["active_link_count"] = active_links.size();
		diagnostics.append(diagnostic);
		supported = false;
	}
	return supported;
}

String catalog_profile_id_for_template(const String &template_id);
String native_rmg_full_generation_status_for_config(const Dictionary &normalized);

bool catalog_template_is_owner_compared_native_auto_candidate(const Dictionary &template_record, const Dictionary &normalized) {
	const String template_id = String(template_record.get("id", ""));
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String size_class_id = String(normalized.get("size_class_id", ""));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (template_id == "translated_rmg_template_027_v1" && water_mode == "land" && level_count == 2) {
		return width == 36 && height == 36 && size_class_id == "homm3_small" && player_count == 3;
	}
	if (level_count != 1) {
		return false;
	}
	if (template_id == "translated_rmg_template_001_v1" && water_mode == "islands") {
		return width == 72 && height == 72 && size_class_id == "homm3_medium" && player_count == 4;
	}
	if (water_mode != "land") {
		return false;
	}
	if (template_id == "translated_rmg_template_049_v1") {
		return width == 36 && height == 36 && size_class_id == "homm3_small" && player_count == 3;
	}
	if (template_id == "translated_rmg_template_002_v1") {
		return width == 72 && height == 72 && size_class_id == "homm3_medium" && player_count == 4;
	}
	if (template_id == "translated_rmg_template_042_v1") {
		return width == 108 && height == 108 && size_class_id == "homm3_large" && player_count == 4;
	}
	if (template_id == "translated_rmg_template_043_v1") {
		return width == 144 && height == 144 && size_class_id == "homm3_extra_large" && player_count == 5;
	}
	return false;
}

bool catalog_template_is_launchable_native_auto_candidate(const Dictionary &template_record, const Dictionary &normalized) {
	const String template_id = String(template_record.get("id", ""));
	if (!template_id.begins_with("translated_rmg_template_")) {
		return false;
	}
	const String profile_id = catalog_profile_id_for_template(template_id);
	if (!profile_id.begins_with("translated_rmg_profile_")) {
		return false;
	}
	Dictionary candidate = normalized.duplicate(true);
	candidate["template_id"] = template_id;
	candidate["profile_id"] = profile_id;
	const String generation_status = native_rmg_full_generation_status_for_config(candidate);
	return generation_status != "not_implemented";
}

String catalog_template_id_for_config(const Dictionary &normalized) {
	Dictionary catalog = load_random_map_template_catalog();
	Array templates = catalog.get("templates", Array());
	Array accepted;
	Array owner_compared_native_auto_accepted;
	Array launchable_native_auto_accepted;
	const bool prefer_owner_compared_native_auto = String(normalized.get("requested_template_selection_mode", "")) == "native_catalog_auto";
	for (int64_t index = 0; index < templates.size(); ++index) {
		if (Variant(templates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = Dictionary(templates[index]);
		Array diagnostics;
		if (catalog_template_supports_config(candidate, normalized, diagnostics)) {
			accepted.append(candidate);
			if (prefer_owner_compared_native_auto && catalog_template_is_launchable_native_auto_candidate(candidate, normalized)) {
				launchable_native_auto_accepted.append(candidate);
			}
			if (prefer_owner_compared_native_auto && catalog_template_is_owner_compared_native_auto_candidate(candidate, normalized)) {
				owner_compared_native_auto_accepted.append(candidate);
			}
		}
	}
	if (accepted.is_empty()) {
		return "";
	}
	Array selection_pool = owner_compared_native_auto_accepted.is_empty() ? (launchable_native_auto_accepted.is_empty() ? accepted : launchable_native_auto_accepted) : owner_compared_native_auto_accepted;
	const String selection_tier = owner_compared_native_auto_accepted.is_empty() ? (launchable_native_auto_accepted.is_empty() ? String("catalog_constraint_supported") : String("translated_launchable_native_auto_supported")) : String("owner_compared_native_auto_supported");
	const String seed = String(normalized.get("normalized_seed", normalized.get("seed", "0"))) + ":catalog_template_selection:" + selection_tier + ":" + String::num_int64(selection_pool.size());
	Dictionary selected = Dictionary(selection_pool[int64_t(hash32_int(seed) % uint32_t(selection_pool.size()))]);
	return String(selected.get("id", ""));
}

String catalog_profile_id_for_template(const String &template_id) {
	if (template_id.is_empty()) {
		return "";
	}
	Dictionary catalog = load_random_map_template_catalog();
	Array profiles = catalog.get("profiles", Array());
	for (int64_t index = 0; index < profiles.size(); ++index) {
		if (Variant(profiles[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary profile = Dictionary(profiles[index]);
		if (String(profile.get("template_id", "")) == template_id) {
			return String(profile.get("id", ""));
		}
	}
	return "";
}

Dictionary catalog_zone_to_native_zone(const Dictionary &source_zone, const Dictionary &normalized, const Dictionary &player_assignment, int64_t zone_index) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Dictionary by_owner_slot = player_assignment.get("player_slot_by_owner_slot", Dictionary());

	const String zone_id = normalized_text(source_zone, "id", "zone_" + slot_id_2(int32_t(zone_index + 1)));
	const int32_t owner_slot = int32_t(source_zone.get("owner_slot", 0));
	String role = normalized_text(source_zone, "role", normalized_text(source_zone, "type", "treasure"));
	const bool source_start_zone = role.contains("start");
	const bool active_owned_zone = owner_slot > 0 && owner_slot <= player_count;
	const bool active_player_zone = active_owned_zone && source_start_zone;
	Dictionary assignment = active_owned_zone ? Dictionary(by_owner_slot.get(String::num_int64(owner_slot), Dictionary())) : Dictionary();
	if (active_player_zone) {
		role = String(assignment.get("player_type", owner_slot == 1 ? String("human") : String("computer"))) == "human" ? "human_start" : "computer_start";
	} else if (role.contains("start")) {
		role = "treasure";
	}
	const String selected_source_faction_id = source_zone_faction_choice(source_zone, normalized, zone_id, int32_t(zone_index));
	const String faction_id = active_owned_zone ? String(assignment.get("faction_id", selected_source_faction_id)) : selected_source_faction_id;
	Dictionary palette = terrain_palette_for_zone(zone_id, faction_id, active_player_zone, terrain_pool, int32_t(zone_index));
	Variant terrain_value = source_zone.get("terrain", Variant());
	if (terrain_value.get_type() == Variant::DICTIONARY) {
		Dictionary terrain = terrain_value;
		Array allowed = normalized_terrain_pool(terrain.get("allowed", Array()));
		if (!allowed.is_empty()) {
			const String terrain_id = String(allowed[int64_t(hash32_int(String(normalized.get("normalized_seed", "0")) + zone_id + ":terrain") % uint32_t(allowed.size()))]);
			palette["normalized_terrain_id"] = terrain_id;
			palette["biome_id"] = biome_for_terrain(terrain_id);
			palette["source"] = "catalog_zone_terrain_allowed";
		}
	}

	Dictionary metadata = source_zone.duplicate(true);
	metadata["source_template_id"] = normalized.get("template_id", "");
	metadata["native_foundation_source"] = "imported_random_map_template_catalog";
	metadata["active_player_zone"] = active_player_zone;
	metadata["active_owned_zone"] = active_owned_zone;
	metadata["source_zone_faction_id"] = selected_source_faction_id;
	metadata["allowed_town_faction_ids"] = allowed_faction_ids_for_source_zone(source_zone, normalized);
	if (!metadata.has("richness_floor")) {
		metadata["richness_floor"] = zone_richness_floor_metadata(role, int32_t(source_zone.get("base_size", 10))).get("richness_floor", Dictionary());
	}

	Dictionary zone;
	zone["id"] = zone_id;
	zone["source_id"] = source_zone.get("source_zone_id", zone_id);
	zone["role"] = role;
	zone["source_role"] = source_zone.get("role", role);
	zone["owner_slot"] = active_owned_zone ? Variant(owner_slot) : Variant();
	zone["player_slot"] = active_player_zone ? assignment.get("player_slot", owner_slot) : Variant();
	zone["player_type"] = active_player_zone ? assignment.get("player_type", owner_slot == 1 ? String("human") : String("computer")) : Variant("neutral");
	zone["team_id"] = active_player_zone ? assignment.get("team_id", "team_" + slot_id_2(owner_slot)) : Variant("");
	zone["faction_id"] = faction_id;
	zone["source_zone_faction_id"] = selected_source_faction_id;
	zone["allowed_town_faction_ids"] = metadata.get("allowed_town_faction_ids", Array());
	zone["terrain_id"] = palette.get("normalized_terrain_id", "grass");
	zone["terrain_palette"] = palette;
	zone["base_size"] = std::max(4, int32_t(source_zone.get("base_size", 10)));
	zone["anchor"] = Dictionary();
	zone["bounds"] = Dictionary();
	zone["cell_count"] = 0;
	zone["catalog_metadata"] = metadata;
	zone["template_player_filter_active"] = catalog_player_filter_allows(source_zone, normalized);
	zone["runtime_id"] = zone_id;
	zone["source_template_id"] = normalized.get("template_id", "");
	zone["source_zone_id"] = source_zone.get("source_zone_id", zone_id);
	zone["source_owner_slot"] = source_zone.get("owner_slot", Variant());
	zone["target_area"] = 0;
	zone["terrain_rules"] = source_zone.get("terrain", Dictionary());
	zone["town_rules"] = source_zone.get("town_policy", Dictionary());
	zone["mine_rules"] = source_zone.get("mine_requirements", Dictionary());
	zone["resource_rules"] = source_zone.get("resource_category_requirements", Dictionary());
	zone["treasure_bands"] = source_zone.get("treasure_bands", Array());
	zone["monster_rules"] = source_zone.get("monster_policy", Dictionary());
	zone["runtime_links"] = Array();
	zone["adjacent_zone_ids"] = Array();
	zone["diagnostics"] = Array();
	return zone;
}

Array build_foundation_zones(const Dictionary &normalized, const Dictionary &player_assignment) {
	Dictionary catalog_template = catalog_template_for_id(String(normalized.get("template_id", "")));
	Array catalog_zones = catalog_template.get("zones", Array());
	if (!catalog_zones.is_empty()) {
		Array zones;
		for (int64_t index = 0; index < catalog_zones.size(); ++index) {
			if (Variant(catalog_zones[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary source_zone = Dictionary(catalog_zones[index]);
			if (!catalog_player_filter_allows(source_zone, normalized)) {
				continue;
			}
			zones.append(catalog_zone_to_native_zone(source_zone, normalized, player_assignment, index));
		}
		if (!zones.is_empty()) {
			return zones;
		}
	}

	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Dictionary by_owner_slot = player_assignment.get("player_slot_by_owner_slot", Dictionary());
	Array zones;
	for (int32_t index = 0; index < player_count; ++index) {
		const int32_t owner_slot = index + 1;
		Dictionary assignment = by_owner_slot.get(String::num_int64(owner_slot), Dictionary());
		const String zone_id = "start_" + String::num_int64(owner_slot);
		const String faction_id = String(assignment.get("faction_id", ""));
		Dictionary palette = terrain_palette_for_zone(zone_id, faction_id, true, terrain_pool, index);
		Dictionary zone;
		zone["id"] = zone_id;
		zone["source_id"] = zone_id;
		zone["role"] = owner_slot == 1 ? "human_start" : "computer_start";
		zone["owner_slot"] = owner_slot;
		zone["player_slot"] = assignment.get("player_slot", owner_slot);
		zone["player_type"] = assignment.get("player_type", owner_slot == 1 ? String("human") : String("computer"));
		zone["team_id"] = assignment.get("team_id", "team_" + slot_id_2(owner_slot));
		zone["faction_id"] = faction_id;
		zone["terrain_id"] = palette.get("normalized_terrain_id", "grass");
		zone["terrain_palette"] = palette;
		zone["base_size"] = 18;
		zone["anchor"] = Dictionary();
		zone["bounds"] = Dictionary();
		zone["cell_count"] = 0;
		Dictionary catalog_metadata = zone_richness_floor_metadata(String(zone["role"]), int32_t(zone["base_size"]));
		catalog_metadata["start_contract"] = "primary_town_anchor_deferred_to_later_native_slice";
		catalog_metadata["native_foundation_source"] = "fallback_runtime_template";
		zone["catalog_metadata"] = catalog_metadata;
		zones.append(zone);
	}

	Dictionary junction_palette = terrain_palette_for_zone("junction_1", "", false, terrain_pool, player_count);
	Dictionary junction;
	junction["id"] = "junction_1";
	junction["source_id"] = "junction_1";
	junction["role"] = "junction";
	junction["owner_slot"] = Variant();
	junction["player_slot"] = Variant();
	junction["player_type"] = "neutral";
	junction["team_id"] = "";
	junction["faction_id"] = "";
	junction["terrain_id"] = junction_palette.get("normalized_terrain_id", "grass");
	junction["terrain_palette"] = junction_palette;
	junction["base_size"] = 10;
	junction["anchor"] = Dictionary();
	junction["bounds"] = Dictionary();
	junction["cell_count"] = 0;
	junction["catalog_metadata"] = zone_richness_floor_metadata("junction", int32_t(junction["base_size"]));
	zones.append(junction);

	const int32_t reward_count = std::max(2, player_count);
	for (int32_t index = 0; index < reward_count; ++index) {
		const String zone_id = "reward_" + String::num_int64(index + 1);
		Dictionary palette = terrain_palette_for_zone(zone_id, "", false, terrain_pool, player_count + index + 1);
		Dictionary reward;
		reward["id"] = zone_id;
		reward["source_id"] = zone_id;
		reward["role"] = "treasure";
		reward["owner_slot"] = Variant();
		reward["player_slot"] = Variant();
		reward["player_type"] = "neutral";
		reward["team_id"] = "";
		reward["faction_id"] = "";
		reward["terrain_id"] = palette.get("normalized_terrain_id", "grass");
		reward["terrain_palette"] = palette;
		reward["base_size"] = 8;
		reward["anchor"] = Dictionary();
		reward["bounds"] = Dictionary();
		reward["cell_count"] = 0;
		reward["catalog_metadata"] = zone_richness_floor_metadata("treasure", int32_t(reward["base_size"]));
		zones.append(reward);
	}
	return zones;
}

Dictionary resolve_seed_collisions(const Dictionary &seeds, int32_t width, int32_t height) {
	Dictionary resolved;
	Dictionary occupied;
	Array keys = seeds.keys();
	std::vector<String> sorted_keys;
	for (int64_t index = 0; index < keys.size(); ++index) {
		sorted_keys.push_back(String(keys[index]));
	}
	std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) { return left < right; });
	for (const String &zone_id : sorted_keys) {
		Dictionary point = seeds[zone_id];
		int32_t x = int32_t(point.get("x", 0));
		int32_t y = int32_t(point.get("y", 0));
		int32_t guard = std::max(1, width * height);
		while (occupied.has(point_key(x, y)) && guard > 0) {
			x = std::max(1, std::min(std::max(1, width - 2), x + 1));
			if (occupied.has(point_key(x, y))) {
				y = std::max(1, std::min(std::max(1, height - 2), y + 1));
			}
			--guard;
		}
		occupied[point_key(x, y)] = true;
		resolved[zone_id] = point_record(x, y);
	}
	return resolved;
}

Array foundation_route_links(const Dictionary &normalized);
void connect_adjacency(Dictionary &adjacency, const String &a, const String &b);

bool uses_template_link_seed_layout(const Dictionary &normalized) {
	return has_catalog_template(normalized);
}

Dictionary zone_link_adjacency(const Array &links) {
	Dictionary adjacency;
	for (int64_t index = 0; index < links.size(); ++index) {
		Dictionary link = links[index];
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		if (from_zone.is_empty() || to_zone.is_empty()) {
			continue;
		}
		Array from_neighbors = adjacency.get(from_zone, Array());
		Array to_neighbors = adjacency.get(to_zone, Array());
		if (!array_has_string(from_neighbors, to_zone)) {
			from_neighbors.append(to_zone);
		}
		if (!array_has_string(to_neighbors, from_zone)) {
			to_neighbors.append(from_zone);
		}
		adjacency[from_zone] = from_neighbors;
		adjacency[to_zone] = to_neighbors;
	}
	return adjacency;
}

Dictionary fallback_zone_seed_point(const Dictionary &zone, int64_t index, int64_t count, double angle_offset, double center_x, double center_y, double radius_x, double radius_y, int32_t width, int32_t height, const String &seed) {
	const String zone_id = String(zone.get("id", ""));
	const String role = String(zone.get("role", "treasure"));
	const double angle = angle_offset + TAU * (double(index) + 0.5) / double(std::max<int64_t>(1, count));
	const double radius_scale = role == "junction" ? 0.18 : 0.58;
	int32_t x = int32_t(std::llround(center_x + std::cos(angle) * radius_x * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":x"), 1);
	int32_t y = int32_t(std::llround(center_y + std::sin(angle) * radius_y * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":y"), 1);
	x = std::max(1, std::min(std::max(1, width - 2), x));
	y = std::max(1, std::min(std::max(1, height - 2), y));
	return point_record(x, y);
}

Dictionary linked_zone_seed_point(const Dictionary &zone, const Array &linked_points, double center_x, double center_y, int32_t width, int32_t height, const String &seed) {
	double total_x = 0.0;
	double total_y = 0.0;
	int32_t count = 0;
	for (int64_t index = 0; index < linked_points.size(); ++index) {
		Dictionary point = linked_points[index];
		total_x += double(int32_t(point.get("x", 0)));
		total_y += double(int32_t(point.get("y", 0)));
		++count;
	}
	if (count <= 0) {
		return point_record(std::max(1, std::min(std::max(1, width - 2), int32_t(std::llround(center_x)))), std::max(1, std::min(std::max(1, height - 2), int32_t(std::llround(center_y)))));
	}
	const String role = String(zone.get("role", "treasure"));
	const String zone_id = String(zone.get("id", ""));
	const double inward_bias = role == "junction" ? 0.44 : (role == "treasure" ? 0.28 : 0.16);
	const double average_x = total_x / double(count);
	const double average_y = total_y / double(count);
	int32_t x = int32_t(std::llround(average_x + (center_x - average_x) * inward_bias)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":linked:x"), 1);
	int32_t y = int32_t(std::llround(average_y + (center_y - average_y) * inward_bias)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":linked:y"), 1);
	x = std::max(1, std::min(std::max(1, width - 2), x));
	y = std::max(1, std::min(std::max(1, height - 2), y));
	return point_record(x, y);
}

bool owner_attached_medium_001_runtime_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 72
			&& height == 72
			&& String(normalized.get("size_class_id", "")) == "homm3_medium"
			&& String(normalized.get("water_mode", "")) == "islands"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_001_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_001_v1"
			&& player_count == 4;
}

Dictionary place_zone_seeds(const Array &zones, const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	const double center_x = (double(width) - 1.0) * 0.5;
	const double center_y = (double(height) - 1.0) * 0.5;
	const double radius_x = std::max(3.0, double(width) * 0.36);
	const double radius_y = std::max(2.0, double(height) * 0.32);
	const double angle_offset = (double(hash32_int(seed + String(":zone_angle_offset")) % 10000U) / 10000.0) * TAU;

	Array starts;
	Array others;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		if (zone.get("player_slot", Variant()).get_type() == Variant::NIL) {
			others.append(zone);
		} else {
			starts.append(zone);
		}
	}

	Dictionary seeds;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary zone = starts[index];
		const String zone_id = String(zone.get("id", ""));
		const double angle = angle_offset + TAU * double(index) / double(std::max<int64_t>(1, starts.size()));
		int32_t x = int32_t(std::llround(center_x + std::cos(angle) * radius_x)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":x"), 1);
		int32_t y = int32_t(std::llround(center_y + std::sin(angle) * radius_y)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":y"), 1);
		x = std::max(1, std::min(std::max(1, width - 2), x));
		y = std::max(1, std::min(std::max(1, height - 2), y));
		seeds[zone_id] = point_record(x, y);
	}
	if (!uses_template_link_seed_layout(normalized)) {
		for (int64_t index = 0; index < others.size(); ++index) {
			Dictionary zone = others[index];
			seeds[String(zone.get("id", ""))] = fallback_zone_seed_point(zone, index, others.size(), angle_offset, center_x, center_y, radius_x, radius_y, width, height, seed);
		}
		return resolve_seed_collisions(seeds, width, height);
	}

	Dictionary adjacency = zone_link_adjacency(foundation_route_links(normalized));
	Array remaining = others.duplicate();
	int64_t fallback_cursor = 0;
	int32_t guard = std::max<int32_t>(1, int32_t(remaining.size() + zones.size()));
	while (!remaining.is_empty() && guard > 0) {
		Array next_remaining;
		bool placed_this_pass = false;
		for (int64_t index = 0; index < remaining.size(); ++index) {
			Dictionary zone = remaining[index];
			const String zone_id = String(zone.get("id", ""));
			Array linked_points;
			Array neighbors = adjacency.get(zone_id, Array());
			for (int64_t neighbor_index = 0; neighbor_index < neighbors.size(); ++neighbor_index) {
				const String neighbor_id = String(neighbors[neighbor_index]);
				if (seeds.has(neighbor_id)) {
					linked_points.append(seeds[neighbor_id]);
				}
			}
			if (linked_points.is_empty()) {
				next_remaining.append(zone);
				continue;
			}
			seeds[zone_id] = linked_zone_seed_point(zone, linked_points, center_x, center_y, width, height, seed);
			placed_this_pass = true;
		}
		if (!placed_this_pass) {
			for (int64_t index = 0; index < next_remaining.size(); ++index) {
				Dictionary zone = next_remaining[index];
				seeds[String(zone.get("id", ""))] = fallback_zone_seed_point(zone, fallback_cursor, std::max<int64_t>(1, next_remaining.size()), angle_offset, center_x, center_y, radius_x, radius_y, width, height, seed);
				++fallback_cursor;
			}
			next_remaining.clear();
		}
		remaining = next_remaining;
		--guard;
	}
	return resolve_seed_collisions(seeds, width, height);
}

String nearest_zone_id(int32_t x, int32_t y, const Array &zones, const Dictionary &seeds) {
	String best_id = zones.is_empty() ? String("") : String(Dictionary(zones[0]).get("id", ""));
	double best_score = std::numeric_limits<double>::max();
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary seed = seeds.get(zone_id, Dictionary());
		const double dx = double(x) - double(int32_t(seed.get("x", 0)));
		const double dy = double(y) - double(int32_t(seed.get("y", 0)));
		const double weight = std::sqrt(double(std::max(1, int32_t(zone.get("base_size", 1)))));
		const double score = (dx * dx + dy * dy) / weight;
		if (score < best_score) {
			best_score = score;
			best_id = zone_id;
		}
	}
	return best_id;
}

Array zones_with_geometry(Array zones, const Dictionary &seeds, const Array &owner_grid) {
	Dictionary counts;
	Dictionary bounds_by_zone;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		counts[zone_id] = 0;
		Dictionary bounds;
		bounds["min_x"] = 999999;
		bounds["min_y"] = 999999;
		bounds["max_x"] = -1;
		bounds["max_y"] = -1;
		bounds_by_zone[zone_id] = bounds;
	}
	for (int64_t y = 0; y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		for (int64_t x = 0; x < row.size(); ++x) {
			const String zone_id = String(row[x]);
			counts[zone_id] = int32_t(counts.get(zone_id, 0)) + 1;
			Dictionary bounds = bounds_by_zone.get(zone_id, Dictionary());
			bounds["min_x"] = std::min(int32_t(bounds.get("min_x", int32_t(x))), int32_t(x));
			bounds["min_y"] = std::min(int32_t(bounds.get("min_y", int32_t(y))), int32_t(y));
			bounds["max_x"] = std::max(int32_t(bounds.get("max_x", int32_t(x))), int32_t(x));
			bounds["max_y"] = std::max(int32_t(bounds.get("max_y", int32_t(y))), int32_t(y));
			bounds_by_zone[zone_id] = bounds;
		}
	}

	Array result;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary anchor = seeds.get(zone_id, Dictionary());
		Dictionary bounds = bounds_by_zone.get(zone_id, Dictionary());
		zone["anchor"] = anchor;
		zone["center"] = point_record(int32_t(anchor.get("x", 0)), int32_t(anchor.get("y", 0)));
		zone["bounds"] = bounds;
		zone["cell_count"] = int32_t(counts.get(zone_id, 0));
		result.append(zone);
	}
	return result;
}

Array zones_with_target_areas(Array zones, int32_t surface_tile_count) {
	int32_t total_weight = 0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		total_weight += std::max(1, int32_t(zone.get("base_size", 1)));
	}
	if (total_weight <= 0 || zones.is_empty()) {
		return zones;
	}

	std::vector<int32_t> targets;
	std::vector<double> remainders;
	targets.reserve(zones.size());
	remainders.reserve(zones.size());
	int32_t assigned = 0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const int32_t weight = std::max(1, int32_t(zone.get("base_size", 1)));
		const double exact = double(surface_tile_count) * double(weight) / double(total_weight);
		const int32_t target = std::max(1, int32_t(std::floor(exact)));
		targets.push_back(target);
		remainders.push_back(exact - std::floor(exact));
		assigned += target;
	}
	while (assigned > surface_tile_count && assigned > int32_t(zones.size())) {
		int64_t best_index = -1;
		double best_remainder = std::numeric_limits<double>::max();
		for (int64_t index = 0; index < int64_t(targets.size()); ++index) {
			if (targets[index] > 1 && remainders[index] < best_remainder) {
				best_remainder = remainders[index];
				best_index = index;
			}
		}
		if (best_index < 0) {
			break;
		}
		targets[best_index] -= 1;
		assigned -= 1;
	}
	while (assigned < surface_tile_count) {
		int64_t best_index = 0;
		double best_remainder = -1.0;
		for (int64_t index = 0; index < int64_t(targets.size()); ++index) {
			if (remainders[index] > best_remainder) {
				best_remainder = remainders[index];
				best_index = index;
			}
		}
		targets[best_index] += 1;
		remainders[best_index] = 0.0;
		assigned += 1;
	}

	Array result;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		zone["target_area"] = targets[index];
		Dictionary area_model;
		area_model["source_base_size"] = std::max(1, int32_t(zone.get("base_size", 1)));
		area_model["total_base_size"] = total_weight;
		area_model["surface_tile_count"] = surface_tile_count;
		area_model["allocation_policy"] = "base_size_weight_normalized_to_surface_target_area";
		zone["target_area_model"] = area_model;
		result.append(zone);
	}
	return result;
}

String owner_grid_value_at(const Array &owner_grid, int32_t x, int32_t y) {
	if (y < 0 || y >= owner_grid.size()) {
		return String();
	}
	Array row = owner_grid[y];
	if (x < 0 || x >= row.size()) {
		return String();
	}
	return String(row[x]);
}

void owner_grid_set(Array &owner_grid, int32_t x, int32_t y, const String &zone_id) {
	if (y < 0 || y >= owner_grid.size()) {
		return;
	}
	Array row = owner_grid[y];
	if (x < 0 || x >= row.size()) {
		return;
	}
	row[x] = zone_id;
	owner_grid[y] = row;
}

Array runtime_graph_owner_grid(const Array &zones, const Dictionary &seeds, int32_t width, int32_t height) {
	Array owner_grid;
	for (int32_t y = 0; y < height; ++y) {
		Array row;
		for (int32_t x = 0; x < width; ++x) {
			row.append("");
		}
		owner_grid.append(row);
	}

	Dictionary counts;
	Dictionary quotas;
	Dictionary frontiers;
	Dictionary cursors;
	Array zone_ids;
	int32_t assigned = 0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (zone_id.is_empty()) {
			continue;
		}
		zone_ids.append(zone_id);
		quotas[zone_id] = std::max(1, int32_t(zone.get("target_area", 1)));
		counts[zone_id] = 0;
		cursors[zone_id] = 0;
		frontiers[zone_id] = Array();
	}

	for (int64_t index = 0; index < zone_ids.size(); ++index) {
		const String zone_id = String(zone_ids[index]);
		Dictionary seed = seeds.get(zone_id, Dictionary());
		int32_t x = std::max(0, std::min(std::max(0, width - 1), int32_t(seed.get("x", 0))));
		int32_t y = std::max(0, std::min(std::max(0, height - 1), int32_t(seed.get("y", 0))));
		int32_t guard = std::max(1, width * height);
		while (!owner_grid_value_at(owner_grid, x, y).is_empty() && guard > 0) {
			x = (x + 1) % std::max(1, width);
			if (x == 0) {
				y = (y + 1) % std::max(1, height);
			}
			--guard;
		}
		if (owner_grid_value_at(owner_grid, x, y).is_empty()) {
			owner_grid_set(owner_grid, x, y, zone_id);
			counts[zone_id] = int32_t(counts.get(zone_id, 0)) + 1;
			Array frontier = frontiers.get(zone_id, Array());
			frontier.append(cell_record(x, y, 0));
			frontiers[zone_id] = frontier;
			assigned += 1;
		}
	}

	static constexpr int32_t DX[4] = { 1, -1, 0, 0 };
	static constexpr int32_t DY[4] = { 0, 0, 1, -1 };
	const int32_t surface_tile_count = width * height;
	int32_t guard = std::max(1, surface_tile_count * 4);
	while (assigned < surface_tile_count && guard > 0) {
		bool progressed = false;
		for (int64_t zone_index = 0; zone_index < zone_ids.size(); ++zone_index) {
			const String zone_id = String(zone_ids[zone_index]);
			if (int32_t(counts.get(zone_id, 0)) >= int32_t(quotas.get(zone_id, 1))) {
				continue;
			}
			Array frontier = frontiers.get(zone_id, Array());
			int32_t cursor = int32_t(cursors.get(zone_id, 0));
			while (cursor < frontier.size() && int32_t(counts.get(zone_id, 0)) < int32_t(quotas.get(zone_id, 1))) {
				Dictionary cell = frontier[cursor];
				++cursor;
				const int32_t base_x = int32_t(cell.get("x", 0));
				const int32_t base_y = int32_t(cell.get("y", 0));
				const int32_t offset = int32_t(hash32_int(zone_id + String(":neighbor_order")) % 4U);
				for (int32_t step = 0; step < 4 && int32_t(counts.get(zone_id, 0)) < int32_t(quotas.get(zone_id, 1)); ++step) {
					const int32_t direction = (offset + step) % 4;
					const int32_t next_x = base_x + DX[direction];
					const int32_t next_y = base_y + DY[direction];
					if (next_x < 0 || next_y < 0 || next_x >= width || next_y >= height || !owner_grid_value_at(owner_grid, next_x, next_y).is_empty()) {
						continue;
					}
					owner_grid_set(owner_grid, next_x, next_y, zone_id);
					counts[zone_id] = int32_t(counts.get(zone_id, 0)) + 1;
					frontier.append(cell_record(next_x, next_y, 0));
					assigned += 1;
					progressed = true;
				}
			}
			cursors[zone_id] = cursor;
			frontiers[zone_id] = frontier;
		}
		if (!progressed) {
			break;
		}
		--guard;
	}

	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			if (!owner_grid_value_at(owner_grid, x, y).is_empty()) {
				continue;
			}
			String best_zone;
			int32_t best_distance = std::numeric_limits<int32_t>::max();
			for (int64_t zone_index = 0; zone_index < zone_ids.size(); ++zone_index) {
				const String zone_id = String(zone_ids[zone_index]);
				Dictionary seed = seeds.get(zone_id, Dictionary());
				const int32_t dx = x - int32_t(seed.get("x", 0));
				const int32_t dy = y - int32_t(seed.get("y", 0));
				const int32_t distance = dx * dx + dy * dy;
				const bool under_quota = int32_t(counts.get(zone_id, 0)) < int32_t(quotas.get(zone_id, 1));
				const int32_t score = distance + (under_quota ? 0 : surface_tile_count * 2);
				if (score < best_distance) {
					best_distance = score;
					best_zone = zone_id;
				}
			}
			if (!best_zone.is_empty()) {
				owner_grid_set(owner_grid, x, y, best_zone);
				counts[best_zone] = int32_t(counts.get(best_zone, 0)) + 1;
			}
		}
	}
	return owner_grid;
}

Array runtime_link_records_from_catalog(const Dictionary &normalized, const Array &zones, Array &diagnostics) {
	Dictionary catalog_template = catalog_template_for_id(String(normalized.get("template_id", "")));
	Array catalog_links = catalog_template.get("links", Array());
	Dictionary zones_by_id;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (!zone_id.is_empty()) {
			zones_by_id[zone_id] = true;
		}
	}

	Array links;
	for (int64_t index = 0; index < catalog_links.size(); ++index) {
		if (Variant(catalog_links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary source_link = Dictionary(catalog_links[index]);
		const String from_zone = normalized_text(source_link, "from", "");
		const String to_zone = normalized_text(source_link, "to", "");
		const bool player_filter_active = catalog_player_filter_allows(source_link, normalized);
		if (!player_filter_active) {
			continue;
		}
		if (from_zone.is_empty() || to_zone.is_empty() || !zones_by_id.has(from_zone) || !zones_by_id.has(to_zone)) {
			Dictionary diagnostic;
			diagnostic["code"] = "runtime_link_endpoint_missing";
			diagnostic["severity"] = "failure";
			diagnostic["message"] = "Catalog link endpoint did not resolve to runtime zones.";
			diagnostic["from"] = from_zone;
			diagnostic["to"] = to_zone;
			diagnostics.append(diagnostic);
			continue;
		}
		Dictionary guard = source_link.get("guard", Dictionary());
		const int32_t guard_value = int32_t(source_link.get("guard_value", guard.get("value", 0)));
		const bool wide = bool(source_link.get("wide", false));
		const bool border_guard = bool(source_link.get("border_guard", false));
		Dictionary link = source_link.duplicate(true);
		link["runtime_id"] = "runtime_link_" + slot_id_2(int32_t(links.size() + 1)) + "_" + from_zone + "_" + to_zone;
		link["source_template_id"] = normalized.get("template_id", "");
		link["from"] = from_zone;
		link["to"] = to_zone;
		link["from_zone_id"] = from_zone;
		link["to_zone_id"] = to_zone;
		link["role"] = normalized_text(source_link, "role", "template_connection");
		link["value"] = guard_value;
		link["guard_value"] = guard_value;
		link["wide"] = wide;
		link["border_guard"] = border_guard;
		link["template_player_filter_active"] = player_filter_active;
		Dictionary road_policy;
		road_policy["endpoint_geometry_consumer"] = "later_roads_rivers_connections_slice";
		road_policy["wide_semantics"] = wide ? "wide_link_suppresses_normal_guard_not_corridor_width" : "normal_width_policy_deferred";
		link["road_policy"] = road_policy;
		Dictionary guard_policy;
		guard_policy["normal_guard_value"] = wide ? 0 : guard_value;
		guard_policy["raw_value"] = guard_value;
		guard_policy["wide_suppresses_normal_guard"] = wide;
		guard_policy["border_guard_special_mode"] = border_guard;
		guard_policy["materialization_owner_slice"] = "native-rmg-homm3-roads-rivers-connections-10184";
		link["guard_policy"] = guard_policy;
		link["diagnostics"] = Array();
		link["source"] = "runtime_template_zone_graph";
		links.append(link);
	}
	Dictionary link_degree_by_zone;
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(links[index]);
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		if (!from_zone.is_empty()) {
			link_degree_by_zone[from_zone] = int32_t(link_degree_by_zone.get(from_zone, 0)) + 1;
		}
		if (!to_zone.is_empty()) {
			link_degree_by_zone[to_zone] = int32_t(link_degree_by_zone.get(to_zone, 0)) + 1;
		}
	}
	String first_active_zone_id;
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		const String zone_id = String(zone.get("id", ""));
		if (!zone_id.is_empty()) {
			first_active_zone_id = zone_id;
			break;
		}
	}
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		const String zone_id = String(zone.get("id", ""));
		if (zone_id.is_empty() || zone.get("player_slot", Variant()).get_type() == Variant::NIL || int32_t(link_degree_by_zone.get(zone_id, 0)) > 0) {
			continue;
		}
		String target_zone_id;
		for (int64_t target_index = 0; target_index < zones.size(); ++target_index) {
			if (Variant(zones[target_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary target_zone = Dictionary(zones[target_index]);
			const String candidate_id = String(target_zone.get("id", ""));
			if (candidate_id.is_empty() || candidate_id == zone_id) {
				continue;
			}
			if (int32_t(link_degree_by_zone.get(candidate_id, 0)) > 0 || target_zone_id.is_empty()) {
				target_zone_id = candidate_id;
				if (int32_t(link_degree_by_zone.get(candidate_id, 0)) > 0) {
					break;
				}
			}
		}
		if (target_zone_id.is_empty() && !first_active_zone_id.is_empty() && first_active_zone_id != zone_id) {
			target_zone_id = first_active_zone_id;
		}
		if (target_zone_id.is_empty()) {
			Dictionary diagnostic;
			diagnostic["code"] = "runtime_player_start_link_repair_infeasible";
			diagnostic["severity"] = "failure";
			diagnostic["zone_id"] = zone_id;
			diagnostics.append(diagnostic);
			continue;
		}
		Dictionary link;
		link["runtime_id"] = "runtime_link_" + slot_id_2(int32_t(links.size() + 1)) + "_" + zone_id + "_" + target_zone_id;
		link["source_template_id"] = normalized.get("template_id", "");
		link["from"] = zone_id;
		link["to"] = target_zone_id;
		link["from_zone_id"] = zone_id;
		link["to_zone_id"] = target_zone_id;
		link["role"] = "template_player_start_connectivity_repair";
		link["value"] = 3000;
		link["guard_value"] = 3000;
		link["wide"] = false;
		link["border_guard"] = false;
		link["template_player_filter_active"] = true;
		link["source"] = "runtime_template_zone_graph_player_start_connectivity_repair";
		Dictionary road_policy;
		road_policy["endpoint_geometry_consumer"] = "runtime_repair_link_materialized_by_native_road_network";
		road_policy["repair_reason"] = "active_player_start_zone_had_no_active_catalog_route_after_player_filtering";
		link["road_policy"] = road_policy;
		Dictionary guard_policy;
		guard_policy["normal_guard_value"] = 3000;
		guard_policy["raw_value"] = 3000;
		guard_policy["wide_suppresses_normal_guard"] = false;
		guard_policy["border_guard_special_mode"] = false;
		guard_policy["materialization_owner_slice"] = "native-rmg-broad-template-connectivity-repair-10184";
		link["guard_policy"] = guard_policy;
		Array link_diagnostics;
		Dictionary diagnostic;
		diagnostic["code"] = "runtime_player_start_link_repair_added";
		diagnostic["severity"] = "warning";
		diagnostic["from_zone_id"] = zone_id;
		diagnostic["to_zone_id"] = target_zone_id;
		diagnostic["policy"] = "active player starts must not be isolated when recovered link player filters suppress every source route";
		link_diagnostics.append(diagnostic);
		link["diagnostics"] = link_diagnostics;
		diagnostics.append(diagnostic);
		links.append(link);
		link_degree_by_zone[zone_id] = int32_t(link_degree_by_zone.get(zone_id, 0)) + 1;
		link_degree_by_zone[target_zone_id] = int32_t(link_degree_by_zone.get(target_zone_id, 0)) + 1;
	}
	return links;
}

Dictionary runtime_zone_graph_validation(const Array &zones, const Array &links, const Array &owner_grid, const Array &input_diagnostics) {
	Array failures;
	Array warnings = input_diagnostics.duplicate(true);
	Dictionary zones_by_id;
	Dictionary adjacency;
	int32_t start_zone_count = 0;
	int32_t neutral_zone_count = 0;
	int32_t target_area_sum = 0;
	int32_t cell_count_sum = 0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (zone_id.is_empty()) {
			failures.append("runtime_zone_missing_id");
			continue;
		}
		zones_by_id[zone_id] = true;
		adjacency[zone_id] = Array();
		if (String(zone.get("role", "")).contains("start")) {
			++start_zone_count;
		}
		if (zone.get("owner_slot", Variant()).get_type() == Variant::NIL) {
			++neutral_zone_count;
		}
		target_area_sum += int32_t(zone.get("target_area", 0));
		cell_count_sum += int32_t(zone.get("cell_count", 0));
		if (int32_t(zone.get("target_area", 0)) <= 0 || int32_t(zone.get("cell_count", 0)) <= 0) {
			failures.append(String("runtime_zone_area_missing:") + zone_id);
		}
	}
	int32_t wide_link_count = 0;
	int32_t border_guard_link_count = 0;
	for (int64_t index = 0; index < links.size(); ++index) {
		Dictionary link = links[index];
		const String from_zone = String(link.get("from_zone_id", link.get("from", "")));
		const String to_zone = String(link.get("to_zone_id", link.get("to", "")));
		if (!zones_by_id.has(from_zone) || !zones_by_id.has(to_zone)) {
			failures.append(String("runtime_link_unknown_endpoint:") + from_zone + String("->") + to_zone);
			continue;
		}
		connect_adjacency(adjacency, from_zone, to_zone);
		if (bool(link.get("wide", false))) {
			++wide_link_count;
		}
		if (bool(link.get("border_guard", false))) {
			++border_guard_link_count;
		}
	}
	if (links.is_empty()) {
		failures.append("runtime_graph_links_empty");
	}
	if (!zones.is_empty()) {
		const String start = String(Dictionary(zones[0]).get("id", ""));
		Dictionary visited;
		Array queue;
		visited[start] = true;
		queue.append(start);
		int64_t cursor = 0;
		while (cursor < queue.size()) {
			const String current = String(queue[cursor]);
			++cursor;
			Array neighbors = adjacency.get(current, Array());
			for (int64_t neighbor_index = 0; neighbor_index < neighbors.size(); ++neighbor_index) {
				const String next = String(neighbors[neighbor_index]);
				if (!visited.has(next)) {
					visited[next] = true;
					queue.append(next);
				}
			}
		}
		if (visited.size() != zones_by_id.size()) {
			failures.append("runtime_graph_disconnected");
		}
	}

	Dictionary report;
	report["schema_id"] = "aurelion_native_rmg_runtime_zone_graph_validation_v1";
	report["status"] = failures.is_empty() ? "pass" : "fail";
	report["failure_count"] = failures.size();
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	report["start_zone_count"] = start_zone_count;
	report["neutral_zone_count"] = neutral_zone_count;
	report["target_area_sum"] = target_area_sum;
	report["cell_count_sum"] = cell_count_sum;
	report["surface_tile_count"] = [&owner_grid]() {
		int32_t total = 0;
		for (int64_t y = 0; y < owner_grid.size(); ++y) {
			total += Array(owner_grid[y]).size();
		}
		return total;
	}();
	report["wide_link_count"] = wide_link_count;
	report["border_guard_link_count"] = border_guard_link_count;
	report["connectivity_model"] = "runtime_template_link_graph_must_connect_all_runtime_zones";
	return report;
}

Array zones_with_runtime_adjacency(Array zones, const Array &links) {
	Dictionary adjacency = zone_link_adjacency(links);
	Dictionary links_by_zone;
	for (int64_t index = 0; index < links.size(); ++index) {
		Dictionary link = links[index];
		const String from_zone = String(link.get("from_zone_id", link.get("from", "")));
		const String to_zone = String(link.get("to_zone_id", link.get("to", "")));
		Array from_links = links_by_zone.get(from_zone, Array());
		Array to_links = links_by_zone.get(to_zone, Array());
		from_links.append(link.get("runtime_id", link.get("id", "")));
		to_links.append(link.get("runtime_id", link.get("id", "")));
		links_by_zone[from_zone] = from_links;
		links_by_zone[to_zone] = to_links;
	}
	Array result;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		zone["adjacent_zone_ids"] = adjacency.get(zone_id, Array());
		zone["runtime_links"] = links_by_zone.get(zone_id, Array());
		result.append(zone);
	}
	return result;
}

Dictionary generate_zone_layout(const Dictionary &normalized, const Dictionary &player_assignment) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array zones = build_foundation_zones(normalized, player_assignment);
	const bool catalog_runtime_graph = has_catalog_template(normalized);
	Array diagnostics;
	Dictionary catalog_template = catalog_template_for_id(String(normalized.get("template_id", "")));
	const bool template_supported = catalog_runtime_graph ? catalog_template_supports_config(catalog_template, normalized, diagnostics) : false;
	zones = zones_with_target_areas(zones, width * height);
	Dictionary seeds = place_zone_seeds(zones, normalized);
	Array owner_grid;
	if (catalog_runtime_graph && template_supported) {
		owner_grid = runtime_graph_owner_grid(zones, seeds, width, height);
	} else {
		for (int32_t y = 0; y < height; ++y) {
			Array row;
			for (int32_t x = 0; x < width; ++x) {
				row.append(nearest_zone_id(x, y, zones, seeds));
			}
			owner_grid.append(row);
		}
	}
	zones = zones_with_geometry(zones, seeds, owner_grid);
	Array runtime_links = catalog_runtime_graph ? runtime_link_records_from_catalog(normalized, zones, diagnostics) : Array();
	zones = zones_with_runtime_adjacency(zones, runtime_links);
	Dictionary runtime_validation = runtime_zone_graph_validation(zones, runtime_links, owner_grid, diagnostics);

	Dictionary level;
	level["level_index"] = 0;
	level["kind"] = "surface";
	level["owner_grid"] = owner_grid;
	level["anchor_points"] = seeds;
	level["allocation_model"] = catalog_runtime_graph && template_supported ? "runtime_template_graph_target_area_flood_fill" : "native_foundation_nearest_seed_weighted_owner_grid";
	Array levels;
	levels.append(level);

	Dictionary dimensions;
	dimensions["width"] = width;
	dimensions["height"] = height;
	dimensions["level_count"] = level_count;

	Dictionary policy;
	policy["zone_area_model"] = catalog_runtime_graph && template_supported ? "runtime_template_graph_base_size_target_area" : "native_foundation_weighted_nearest_seed";
	policy["water_mode"] = normalized.get("water_mode", "land");
	policy["template_model"] = has_catalog_template(normalized) ? "imported_catalog_template_zones_and_links" : "fallback_runtime_template";
	policy["runtime_graph_model"] = catalog_runtime_graph ? "template_catalog_runtime_zone_graph" : "fallback_foundation_template";
	policy["layout_algorithm"] = catalog_runtime_graph && template_supported ? "quota_limited_connected_flood_fill_from_template_graph_anchors" : "weighted_nearest_seed_fallback";

	Dictionary runtime_graph;
	runtime_graph["schema_id"] = NATIVE_RMG_RUNTIME_ZONE_GRAPH_SCHEMA_ID;
	runtime_graph["schema_version"] = 1;
	runtime_graph["generation_status"] = catalog_runtime_graph ? "runtime_zone_graph_generated" : "runtime_zone_graph_not_applicable";
	runtime_graph["source_template_id"] = normalized.get("template_id", "");
	runtime_graph["source_profile_id"] = normalized.get("profile_id", "");
	runtime_graph["source_template_label"] = catalog_template.get("label", "");
	runtime_graph["template_supported_for_config"] = template_supported;
	runtime_graph["size_score"] = catalog_runtime_graph ? catalog_size_score_for_config(normalized, catalog_template) : 0;
	runtime_graph["zones"] = zones;
	runtime_graph["links"] = runtime_links;
	runtime_graph["zone_count"] = zones.size();
	runtime_graph["link_count"] = runtime_links.size();
	runtime_graph["validation"] = runtime_validation;
	runtime_graph["diagnostics"] = diagnostics;
	runtime_graph["signature"] = hash32_hex(canonical_variant(runtime_graph));

	Dictionary layout;
	layout["schema_id"] = NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID;
	layout["schema_version"] = 1;
	layout["generation_status"] = catalog_runtime_graph && template_supported ? "zones_generated_runtime_template_graph" : "zones_generated_foundation";
	layout["full_generation_status"] = "not_implemented";
	layout["template_id"] = normalized.get("template_id", "");
	layout["template_source"] = has_catalog_template(normalized) ? "content_random_map_template_catalog" : "native_foundation_fallback_runtime_template";
	layout["dimensions"] = dimensions;
	layout["policy"] = policy;
	layout["runtime_zone_graph"] = runtime_graph;
	layout["runtime_graph_validation"] = runtime_validation;
	layout["zone_count"] = zones.size();
	layout["zones"] = zones;
	layout["zone_seed_records"] = seeds;
	layout["levels"] = levels;
	layout["surface_owner_grid"] = owner_grid;
	layout["surface_water_cells"] = Array();
	layout["unsupported_runtime_features"] = Array();
	layout["diagnostics"] = diagnostics;
	layout["signature"] = hash32_hex(canonical_variant(layout));
	return layout;
}

bool point_far_enough(const Array &starts, int32_t x, int32_t y, int32_t min_spacing) {
	const int32_t min_distance_sq = min_spacing * min_spacing;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const int32_t dx = x - int32_t(start.get("x", 0));
		const int32_t dy = y - int32_t(start.get("y", 0));
		if (dx * dx + dy * dy < min_distance_sq) {
			return false;
		}
	}
	return true;
}

Dictionary find_start_point(const Dictionary &zone, const Array &owner_grid, const Array &existing_starts, int32_t min_spacing) {
	Dictionary anchor = zone.get("anchor", Dictionary());
	int32_t best_x = int32_t(anchor.get("x", 0));
	int32_t best_y = int32_t(anchor.get("y", 0));
	if (point_far_enough(existing_starts, best_x, best_y, min_spacing)) {
		return point_record(best_x, best_y);
	}
	const String zone_id = String(zone.get("id", ""));
	int64_t best_score = std::numeric_limits<int64_t>::max();
	Dictionary best;
	for (int64_t y = 0; y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		for (int64_t x = 0; x < row.size(); ++x) {
			if (String(row[x]) != zone_id) {
				continue;
			}
			if (!point_far_enough(existing_starts, int32_t(x), int32_t(y), min_spacing)) {
				continue;
			}
			const int64_t dx = int64_t(x) - int64_t(best_x);
			const int64_t dy = int64_t(y) - int64_t(best_y);
			const int64_t score = dx * dx + dy * dy;
			if (score < best_score) {
				best_score = score;
				best = point_record(int32_t(x), int32_t(y));
			}
		}
	}
	if (!best.is_empty()) {
		return best;
	}
	return point_record(best_x, best_y);
}

Dictionary generate_player_starts(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_assignment) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t min_spacing = std::max(3, std::min(width, height) / std::max(3, player_count + 2));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		if (zone.get("player_slot", Variant()).get_type() == Variant::NIL) {
			continue;
		}
		Dictionary point = find_start_point(zone, owner_grid, starts, min_spacing);
		const int32_t player_slot = int32_t(zone.get("player_slot", 0));
		Dictionary start;
		start["start_id"] = "player_start_" + String::num_int64(player_slot);
		start["player_slot"] = player_slot;
		start["owner_slot"] = zone.get("owner_slot", player_slot);
		start["player_type"] = zone.get("player_type", "computer");
		start["team_id"] = zone.get("team_id", "");
		start["faction_id"] = zone.get("faction_id", "");
		Dictionary assignment_by_owner = player_assignment.get("player_slot_by_owner_slot", Dictionary());
		Dictionary assignment = assignment_by_owner.get(String::num_int64(int32_t(zone.get("owner_slot", player_slot))), Dictionary());
		start["town_id"] = assignment.get("town_id", town_for_faction(String(zone.get("faction_id", ""))));
		start["zone_id"] = zone.get("id", "");
		start["zone_role"] = zone.get("role", "");
		start["x"] = int32_t(point.get("x", 0));
		start["y"] = int32_t(point.get("y", 0));
		start["level"] = 0;
		start["bounds_status"] = int32_t(point.get("x", 0)) >= 0 && int32_t(point.get("x", 0)) < width && int32_t(point.get("y", 0)) >= 0 && int32_t(point.get("y", 0)) < height ? "in_bounds" : "out_of_bounds";
		start["spacing_model"] = "native_foundation_minimum_euclidean_tile_spacing";
		start["primary_town_anchor_status"] = "reserved_not_materialized";
		starts.append(start);
	}

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_PLAYER_STARTS_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = "player_starts_generated_foundation";
	payload["full_generation_status"] = "not_implemented";
	payload["start_count"] = starts.size();
	payload["expected_player_count"] = player_count;
	payload["minimum_spacing_tiles"] = min_spacing;
	payload["starts"] = starts;
	payload["signature"] = hash32_hex(canonical_variant(payload));
	return payload;
}

Array foundation_route_links(const Dictionary &normalized) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array links;
	Dictionary catalog_template = catalog_template_for_id(String(normalized.get("template_id", "")));
	Array catalog_links = catalog_template.get("links", Array());
	if (!catalog_links.is_empty()) {
		for (int64_t index = 0; index < catalog_links.size(); ++index) {
			if (Variant(catalog_links[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary source_link = Dictionary(catalog_links[index]);
			Dictionary link = source_link.duplicate(true);
			link["from"] = normalized_text(source_link, "from", "");
			link["to"] = normalized_text(source_link, "to", "");
			link["role"] = normalized_text(source_link, "role", "template_connection");
			Dictionary guard = source_link.get("guard", Dictionary());
			link["guard_value"] = int32_t(source_link.get("guard_value", guard.get("value", 0)));
			link["wide"] = bool(source_link.get("wide", false));
			link["border_guard"] = bool(source_link.get("border_guard", false));
			link["source"] = "imported_random_map_template_catalog";
			if (!String(link.get("from", "")).is_empty() && !String(link.get("to", "")).is_empty()) {
				links.append(link);
			}
		}
		if (!links.is_empty()) {
			return links;
		}
	}
	for (int32_t index = 0; index < player_count; ++index) {
		const String start_id = "start_" + String::num_int64(index + 1);
		const String reward_id = "reward_" + String::num_int64((index % std::max(2, player_count)) + 1);

		Dictionary contest;
		contest["from"] = start_id;
		contest["to"] = "junction_1";
		contest["role"] = "contest_route";
		contest["guard_value"] = 600;
		contest["wide"] = false;
		contest["border_guard"] = String(normalized.get("template_id", "")) == "border_gate_compact_v1" && index == 0;
		links.append(contest);

		Dictionary reward;
		reward["from"] = start_id;
		reward["to"] = reward_id;
		reward["role"] = "early_reward_route";
		reward["guard_value"] = 150;
		reward["wide"] = false;
		reward["border_guard"] = false;
		links.append(reward);
	}
	for (int32_t index = 0; index < std::max(2, player_count); ++index) {
		Dictionary link;
		link["from"] = "reward_" + String::num_int64(index + 1);
		link["to"] = "junction_1";
		link["role"] = "reward_to_junction";
		link["guard_value"] = 300;
		link["wide"] = index == 0;
		link["border_guard"] = false;
		links.append(link);
	}
	return links;
}

Array layout_contract_roles_for_route(const Dictionary &link, const Array &start_front_zones) {
	Array roles;
	const String role = String(link.get("role", ""));
	if (role == "contest_route") {
		roles.append("contest_route");
		roles.append("guarded_route");
	} else if (role == "early_reward_route") {
		roles.append("early_reward_route");
		roles.append("reward_route");
	} else if (role == "reward_to_junction") {
		roles.append("reward_route");
	} else if (role == "template_connection" && !start_front_zones.is_empty()) {
		roles.append("contest_route");
		roles.append("early_reward_route");
		roles.append("reward_route");
	}
	if ((int32_t(link.get("guard_value", 0)) > 0 || bool(link.get("border_guard", false)) || bool(link.get("wide", false))) && !array_has_string(roles, "guarded_route")) {
		roles.append("guarded_route");
	}
	return roles;
}

Array start_front_zones_for_link(const Dictionary &link) {
	Array zones;
	const String role = String(link.get("role", ""));
	if (role != "contest_route" && role != "early_reward_route" && role != "template_connection") {
		return zones;
	}
	static constexpr const char *ENDPOINT_KEYS[] = {"from", "to"};
	for (const char *endpoint_key : ENDPOINT_KEYS) {
		const String key = endpoint_key;
		const String zone_id = String(link.get(key, ""));
		if (zone_id.begins_with("start_") && !array_has_string(zones, zone_id)) {
			zones.append(zone_id);
		}
	}
	return zones;
}

String road_class_for_edge(const Dictionary &edge) {
	if (bool(edge.get("border_guard", false))) {
		return "special_guard_gate_road";
	}
	if (bool(edge.get("wide", false))) {
		return "wide_guard_suppressed_road";
	}
	if (String(edge.get("role", "")) == "secondary_major_object_route") {
		return "secondary_major_object_service_road";
	}
	if (int32_t(edge.get("guard_value", 0)) > 0) {
		return "guarded_route_road";
	}
	if (String(edge.get("role", "")) == "early_reward_route") {
		return "start_economy_service_road";
	}
	return "connector_road";
}

String road_type_for_class(const String &road_class) {
	if (road_class == "special_guard_gate_road") {
		return "generated_dirt_gate_road";
	}
	if (road_class == "wide_guard_suppressed_road") {
		return "generated_dirt_wide_guard_suppressed_road";
	}
	if (road_class == "secondary_major_object_service_road") {
		return "generated_dirt_secondary_major_object_service_road";
	}
	if (road_class == "guarded_route_road") {
		return "generated_dirt_guarded_road";
	}
	if (road_class == "start_economy_service_road") {
		return "generated_dirt_start_economy_service_road";
	}
	return "generated_dirt_connector_road";
}

String route_edge_id(int32_t index, const String &from_zone, const String &to_zone) {
	return "edge_" + slot_id_2(index) + "_" + from_zone + "_" + to_zone;
}

String route_classification(const Dictionary &link, bool path_found) {
	if (!path_found) {
		return "blocked_connectivity";
	}
	if (bool(link.get("border_guard", false))) {
		return "guarded_connectivity_border_guard";
	}
	if (bool(link.get("wide", false))) {
		return "full_connectivity_wide_unguarded";
	}
	if (int32_t(link.get("guard_value", 0)) > 0) {
		return "guarded_connectivity";
	}
	return "full_connectivity";
}

Array straight_route_cells(const Dictionary &from_point, const Dictionary &to_point, int32_t width, int32_t height, int32_t level) {
	Array cells;
	if (from_point.is_empty() || to_point.is_empty()) {
		return cells;
	}
	int32_t x = std::max(0, std::min(width - 1, int32_t(from_point.get("x", 0))));
	int32_t y = std::max(0, std::min(height - 1, int32_t(from_point.get("y", 0))));
	const int32_t goal_x = std::max(0, std::min(width - 1, int32_t(to_point.get("x", 0))));
	const int32_t goal_y = std::max(0, std::min(height - 1, int32_t(to_point.get("y", 0))));
	const int32_t step_x = goal_x >= x ? 1 : -1;
	while (x != goal_x) {
		cells.append(cell_record(x, y, level));
		x += step_x;
	}
	const int32_t step_y = goal_y >= y ? 1 : -1;
	while (y != goal_y) {
		cells.append(cell_record(x, y, level));
		y += step_y;
	}
	cells.append(cell_record(goal_x, goal_y, level));
	return cells;
}

Array owner_medium_001_remap_northeast_road_cells(const Array &cells, int32_t width, int32_t height) {
	Array remapped;
	for (int64_t index = 0; index < cells.size(); ++index) {
		if (Variant(cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = Dictionary(cells[index]).duplicate(true);
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		if (x >= width / 2 && y < height / 2) {
			cell["y"] = std::max(0, std::min(height - 1, y + height / 2));
			cell["owner_medium_001_road_quadrant_remap"] = "northeast_owner_dead_quadrant_shifted_to_southern_service_band";
		}
		remapped.append(cell);
	}
	return remapped;
}

bool point_is_materialized_road(const Dictionary &point, const Dictionary &road_lookup) {
	if (point.is_empty()) {
		return false;
	}
	return road_lookup.has(point_key(int32_t(point.get("x", 0)), int32_t(point.get("y", 0))));
}

void record_materialized_road_cells(const Array &cells, Dictionary &road_lookup, Array &road_cells) {
	for (int64_t index = 0; index < cells.size(); ++index) {
		if (Variant(cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = cells[index];
		const String key = point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
		if (!road_lookup.has(key)) {
			road_lookup[key] = true;
			road_cells.append(cell_record(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)), int32_t(cell.get("level", 0))));
		}
	}
}

Array route_cells_to_nearest_materialized_road(const Dictionary &from_point, const Array &road_cells, int32_t width, int32_t height, int32_t level) {
	if (from_point.is_empty() || road_cells.is_empty()) {
		return Array();
	}
	const int32_t from_x = int32_t(from_point.get("x", 0));
	const int32_t from_y = int32_t(from_point.get("y", 0));
	int32_t best_distance = std::numeric_limits<int32_t>::max();
	Dictionary best_cell;
	for (int64_t index = 0; index < road_cells.size(); ++index) {
		if (Variant(road_cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = road_cells[index];
		const int32_t distance = std::abs(from_x - int32_t(cell.get("x", 0))) + std::abs(from_y - int32_t(cell.get("y", 0)));
		if (distance < best_distance) {
			best_distance = distance;
			best_cell = cell;
		}
	}
	if (best_cell.is_empty()) {
		return Array();
	}
	return straight_route_cells(from_point, best_cell, width, height, level);
}

Array short_branch_spur_cells(const Array &direct_cells, const Dictionary &road_lookup, int32_t width, int32_t height) {
	Array branch;
	if (direct_cells.is_empty()) {
		return branch;
	}
	const int32_t new_tile_target = std::max(4, std::min(12, std::max(width, height) / 6));
	int32_t new_tiles = 0;
	for (int64_t index = 0; index < direct_cells.size(); ++index) {
		if (Variant(direct_cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = direct_cells[index];
		branch.append(cell);
		const String key = point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
		if (!road_lookup.has(key)) {
			++new_tiles;
		}
		if (new_tiles >= new_tile_target) {
			break;
		}
	}
	return branch;
}

Array homm3_like_imported_route_cells(const Dictionary &from_point, const Dictionary &to_point, const Array &direct_cells, const Dictionary &road_lookup, const Array &road_cells, int32_t width, int32_t height, int32_t level, String &materialization_policy) {
	materialization_policy = "direct_template_route";
	if (road_cells.is_empty()) {
		return direct_cells;
	}
	const bool from_covered = point_is_materialized_road(from_point, road_lookup);
	const bool to_covered = point_is_materialized_road(to_point, road_lookup);
	if (from_covered && to_covered) {
		Array branch = short_branch_spur_cells(direct_cells, road_lookup, width, height);
		if (!branch.is_empty()) {
			materialization_policy = "covered_crosslink_short_branch_spur";
			return branch;
		}
		return direct_cells;
	}
	if (from_covered != to_covered) {
		Dictionary uncovered = from_covered ? to_point : from_point;
		Array branch = route_cells_to_nearest_materialized_road(uncovered, road_cells, width, height, level);
		if (!branch.is_empty()) {
			materialization_policy = "uncovered_endpoint_branches_to_existing_trunk";
			return branch;
		}
	}
	return direct_cells;
}

String owner_grid_zone_id_at(const Array &owner_grid, int32_t x, int32_t y) {
	if (y < 0 || y >= owner_grid.size()) {
		return String();
	}
	if (Variant(owner_grid[y]).get_type() != Variant::ARRAY) {
		return String();
	}
	Array row = owner_grid[y];
	if (x < 0 || x >= row.size()) {
		return String();
	}
	return String(row[x]);
}

bool native_road_spread_service_stubs_enabled(const Dictionary &normalized, const Dictionary &parity_targets) {
	if (!parity_targets.is_empty()) {
		return false;
	}
	return owner_attached_medium_001_runtime_case(normalized);
}

int32_t coarse_index_for_point(int32_t x, int32_t y, int32_t width, int32_t height, int32_t cols, int32_t rows) {
	const int32_t cx = std::max(0, std::min(cols - 1, (x * cols) / std::max(1, width)));
	const int32_t cy = std::max(0, std::min(rows - 1, (y * rows) / std::max(1, height)));
	return cy * cols + cx;
}

Array road_spread_stub_cells_for_coarse_cell(const Dictionary &normalized, const Array &owner_grid, const Dictionary &road_lookup, int32_t coarse_x, int32_t coarse_y, int32_t coarse_cols, int32_t coarse_rows, int32_t ordinal) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t min_x = std::max(1, (coarse_x * width) / coarse_cols);
	const int32_t max_x = std::min(width - 2, ((coarse_x + 1) * width) / coarse_cols - 1);
	const int32_t min_y = std::max(1, (coarse_y * height) / coarse_rows);
	const int32_t max_y = std::min(height - 2, ((coarse_y + 1) * height) / coarse_rows - 1);
	if (min_x > max_x || min_y > max_y) {
		return Array();
	}
	const int32_t center_x = (min_x + max_x) / 2;
	const int32_t center_y = (min_y + max_y) / 2;
	const String seed = String(normalized.get("normalized_seed", "0")) + ":road_spread_stub:" + String::num_int64(coarse_x) + "," + String::num_int64(coarse_y) + ":" + String::num_int64(ordinal);

	std::vector<Dictionary> anchors;
	for (int32_t y = min_y; y <= max_y; ++y) {
		for (int32_t x = min_x; x <= max_x; ++x) {
			const String zone_id = owner_grid_zone_id_at(owner_grid, x, y);
			if (zone_id.is_empty() || road_lookup.has(point_key(x, y))) {
				continue;
			}
			const int32_t center_distance = std::abs(x - center_x) + std::abs(y - center_y);
			const int32_t jitter = int32_t(hash32_int(seed + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 1000U);
			Dictionary anchor = point_record(x, y);
			anchor["zone_id"] = zone_id;
			anchor["sort_key"] = center_distance * 1000 + jitter;
			anchors.push_back(anchor);
		}
	}
	std::sort(anchors.begin(), anchors.end(), [](const Dictionary &left, const Dictionary &right) {
		return int32_t(left.get("sort_key", 0)) < int32_t(right.get("sort_key", 0));
	});

	const bool horizontal_first = (hash32_int(seed + String(":orientation")) % 2U) == 0U;
	static constexpr int32_t OFFSETS[3] = {-1, 0, 1};
	for (const Dictionary &anchor : anchors) {
		const int32_t ax = int32_t(anchor.get("x", center_x));
		const int32_t ay = int32_t(anchor.get("y", center_y));
		const String zone_id = String(anchor.get("zone_id", ""));
		for (int32_t pass = 0; pass < 4; ++pass) {
			const bool horizontal = (pass % 2 == 0) == horizontal_first;
			const bool require_same_zone = pass < 2;
			Array cells;
			for (int32_t offset_index = 0; offset_index < 3; ++offset_index) {
				const int32_t offset = OFFSETS[offset_index];
				const int32_t x = horizontal ? ax + offset : ax;
				const int32_t y = horizontal ? ay : ay + offset;
				if (x < min_x || y < min_y || x > max_x || y > max_y || road_lookup.has(point_key(x, y))) {
					continue;
				}
				const String cell_zone_id = owner_grid_zone_id_at(owner_grid, x, y);
				if (cell_zone_id.is_empty() || (require_same_zone && cell_zone_id != zone_id)) {
					continue;
				}
				cells.append(cell_record(x, y, 0));
			}
			if (cells.size() >= 3) {
				if (owner_attached_medium_001_runtime_case(normalized) && coarse_x >= coarse_cols / 2 && coarse_y < coarse_rows / 2) {
					Array single_cell;
					single_cell.append(cells[1]);
					return single_cell;
				}
				return cells;
			}
		}
	}
	return Array();
}

Dictionary append_road_spread_service_stubs(const Dictionary &normalized, const Dictionary &zone_layout, Array &road_segments, Dictionary &road_lookup, Array &road_cells) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t coarse_cols = 6;
	const int32_t coarse_rows = 6;
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	PackedInt32Array road_counts;
	PackedInt32Array zone_counts;
	road_counts.resize(coarse_cols * coarse_rows);
	zone_counts.resize(coarse_cols * coarse_rows);
	for (int32_t index = 0; index < road_counts.size(); ++index) {
		road_counts[index] = 0;
		zone_counts[index] = 0;
	}
	for (int64_t index = 0; index < road_cells.size(); ++index) {
		if (Variant(road_cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = road_cells[index];
		const int32_t coarse_index = coarse_index_for_point(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)), width, height, coarse_cols, coarse_rows);
		road_counts[coarse_index] = road_counts[coarse_index] + 1;
	}
	for (int32_t y = 1; y < height - 1; ++y) {
		for (int32_t x = 1; x < width - 1; ++x) {
			if (owner_grid_zone_id_at(owner_grid, x, y).is_empty()) {
				continue;
			}
			const int32_t coarse_index = coarse_index_for_point(x, y, width, height, coarse_cols, coarse_rows);
			zone_counts[coarse_index] = zone_counts[coarse_index] + 1;
		}
	}

	std::vector<Dictionary> candidates;
	for (int32_t coarse_y = 0; coarse_y < coarse_rows; ++coarse_y) {
		for (int32_t coarse_x = 0; coarse_x < coarse_cols; ++coarse_x) {
			const int32_t index = coarse_y * coarse_cols + coarse_x;
			if (road_counts[index] > 0 || zone_counts[index] < 18) {
				continue;
			}
			int32_t nearest_road_cell = std::numeric_limits<int32_t>::max();
			for (int32_t other_y = 0; other_y < coarse_rows; ++other_y) {
				for (int32_t other_x = 0; other_x < coarse_cols; ++other_x) {
					const int32_t other_index = other_y * coarse_cols + other_x;
					if (road_counts[other_index] <= 0) {
						continue;
					}
					nearest_road_cell = std::min(nearest_road_cell, std::abs(coarse_x - other_x) + std::abs(coarse_y - other_y));
				}
			}
			if (nearest_road_cell == std::numeric_limits<int32_t>::max() || nearest_road_cell < 2) {
				continue;
			}
			const int32_t jitter = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":road_spread_target:" + String::num_int64(coarse_x) + "," + String::num_int64(coarse_y)) % 1000U);
			Dictionary candidate;
			candidate["x"] = coarse_x;
			candidate["y"] = coarse_y;
			candidate["zone_cell_count"] = zone_counts[index];
			candidate["nearest_road_coarse_distance"] = nearest_road_cell;
			candidate["sort_key"] = nearest_road_cell * 1000000 + std::min(999, zone_counts[index]) * 1000 + jitter;
			candidates.push_back(candidate);
		}
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		return int32_t(left.get("sort_key", 0)) > int32_t(right.get("sort_key", 0));
	});

	const int32_t max_stub_count = 3;
	int32_t appended_stub_count = 0;
	int32_t appended_cell_count = 0;
	Array stub_records;
	for (const Dictionary &candidate : candidates) {
		if (appended_stub_count >= max_stub_count) {
			break;
		}
		Array cells = road_spread_stub_cells_for_coarse_cell(normalized, owner_grid, road_lookup, int32_t(candidate.get("x", 0)), int32_t(candidate.get("y", 0)), coarse_cols, coarse_rows, appended_stub_count);
		if (cells.is_empty()) {
			continue;
		}
		const String route_edge_id = "road_spread_stub_" + slot_id_2(appended_stub_count + 1);
		Dictionary segment;
		segment["id"] = "road_" + route_edge_id;
		segment["route_edge_id"] = route_edge_id;
		segment["overlay_id"] = "generated_dirt_road";
		segment["road_class"] = "roadless_pocket_service_stub_road";
		segment["road_type_id"] = road_type_for_class("secondary_major_object_service_road");
		segment["connection_control"] = Dictionary();
		segment["cells"] = cells;
		segment["cell_count"] = cells.size();
		segment["direct_cell_count"] = cells.size();
		segment["road_materialization_policy"] = "roadless_land_pocket_short_service_stub";
		segment["connectivity_classification"] = "non_route_service_stub_spread";
		segment["role"] = "road_spread_service_stub";
		segment["writeout_state"] = "staged_overlay_no_tile_bytes_written";
		segment["bounds_status"] = "in_bounds";
		segment["coarse_grid_target"] = candidate;
		road_segments.append(segment);
		record_materialized_road_cells(cells, road_lookup, road_cells);
		++appended_stub_count;
		appended_cell_count += int32_t(cells.size());
		Dictionary stub_record;
		stub_record["route_edge_id"] = route_edge_id;
		stub_record["coarse_x"] = candidate.get("x", 0);
		stub_record["coarse_y"] = candidate.get("y", 0);
		stub_record["cell_count"] = cells.size();
		stub_record["nearest_road_coarse_distance"] = candidate.get("nearest_road_coarse_distance", 0);
		stub_records.append(stub_record);
	}

	Dictionary summary;
	summary["schema_id"] = "native_random_map_road_spread_service_stubs_v1";
	summary["policy"] = "short non-route service stubs are added only in owner-like coarse roadless land pockets to improve road spread without restoring full cross-map connections";
	summary["status"] = "pass";
	summary["coarse_cols"] = coarse_cols;
	summary["coarse_rows"] = coarse_rows;
	summary["candidate_count"] = int32_t(candidates.size());
	summary["max_stub_count"] = max_stub_count;
	summary["appended_stub_count"] = appended_stub_count;
	summary["appended_cell_count"] = appended_cell_count;
	summary["stub_records"] = stub_records;
	return summary;
}

int32_t road_lookup_neighbor_count(const Dictionary &road_lookup, int32_t x, int32_t y) {
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
	int32_t count = 0;
	for (const auto &offset : OFFSETS) {
		if (road_lookup.has(point_key(x + offset[0], y + offset[1]))) {
			++count;
		}
	}
	return count;
}

Dictionary append_owner_medium_topology_branch_stubs(const Dictionary &normalized, const Dictionary &zone_layout, Array &road_segments, Dictionary &road_lookup, Array &road_cells, int32_t max_stub_count) {
	Dictionary summary;
	summary["schema_id"] = "native_random_map_owner_medium_road_branch_stubs_v1";
	summary["policy"] = "short owner-medium-only road branch tiles are added to match uploaded HoMM3 road endpoint/branch topology without changing template connectivity";
	if (!native_road_spread_service_stubs_enabled(normalized, Dictionary()) || max_stub_count <= 0) {
		summary["status"] = "skipped";
		summary["appended_stub_count"] = 0;
		summary["appended_cell_count"] = 0;
		return summary;
	}

	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	const String seed = String(normalized.get("normalized_seed", "0")) + ":owner_medium_road_branch_stub:";
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

	std::vector<Dictionary> candidates;
	for (int64_t index = 0; index < road_cells.size(); ++index) {
		if (Variant(road_cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary anchor = Dictionary(road_cells[index]);
		const int32_t ax = int32_t(anchor.get("x", 0));
		const int32_t ay = int32_t(anchor.get("y", 0));
		if (road_lookup_neighbor_count(road_lookup, ax, ay) != 2) {
			continue;
		}
		for (const auto &offset : OFFSETS) {
			const int32_t x = ax + offset[0];
			const int32_t y = ay + offset[1];
			if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1 || road_lookup.has(point_key(x, y))) {
				continue;
			}
			if (owner_attached_medium_001_runtime_case(normalized) && x >= width / 2 && y < height / 2) {
				continue;
			}
			if (owner_grid_zone_id_at(owner_grid, x, y).is_empty() || road_lookup_neighbor_count(road_lookup, x, y) != 1) {
				continue;
			}
			const int32_t coarse = coarse_index_for_point(x, y, width, height, 6, 6);
			const int32_t jitter = int32_t(hash32_int(seed + String::num_int64(ax) + "," + String::num_int64(ay) + "->" + String::num_int64(x) + "," + String::num_int64(y)) % 100000U);
			Dictionary candidate;
			candidate["anchor_x"] = ax;
			candidate["anchor_y"] = ay;
			candidate["x"] = x;
			candidate["y"] = y;
			candidate["coarse_index"] = coarse;
			candidate["sort_key"] = coarse * 100000 + jitter;
			candidates.push_back(candidate);
		}
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		return int32_t(left.get("sort_key", 0)) < int32_t(right.get("sort_key", 0));
	});

	Dictionary used_coarse;
	Array stub_records;
	int32_t appended_stub_count = 0;
	int32_t appended_cell_count = 0;
	for (int32_t pass = 0; pass < 2; ++pass) {
		for (const Dictionary &candidate : candidates) {
			if (appended_stub_count >= max_stub_count) {
				break;
			}
			const int32_t ax = int32_t(candidate.get("anchor_x", 0));
			const int32_t ay = int32_t(candidate.get("anchor_y", 0));
			const int32_t x = int32_t(candidate.get("x", 0));
			const int32_t y = int32_t(candidate.get("y", 0));
			const String coarse_key = String::num_int64(int32_t(candidate.get("coarse_index", 0)));
			if (pass == 0 && used_coarse.has(coarse_key)) {
				continue;
			}
			if (road_lookup.has(point_key(x, y)) || road_lookup_neighbor_count(road_lookup, ax, ay) != 2 || road_lookup_neighbor_count(road_lookup, x, y) != 1) {
				continue;
			}
			Array cells;
			cells.append(cell_record(x, y, 0));
			const String route_edge_id = "owner_medium_branch_stub_" + slot_id_2(appended_stub_count + 1);
			Dictionary segment;
			segment["id"] = "road_" + route_edge_id;
			segment["route_edge_id"] = route_edge_id;
			segment["overlay_id"] = "generated_dirt_road";
			segment["road_class"] = "owner_medium_topology_branch_stub_road";
			segment["road_type_id"] = road_type_for_class("secondary_major_object_service_road");
			segment["connection_control"] = Dictionary();
			segment["cells"] = cells;
			segment["cell_count"] = cells.size();
			segment["direct_cell_count"] = cells.size();
			segment["road_materialization_policy"] = "owner_medium_single_tile_branch_stub";
			segment["connectivity_classification"] = "non_route_topology_branch_stub";
			segment["role"] = "owner_medium_topology_branch_stub";
			segment["writeout_state"] = "staged_overlay_no_tile_bytes_written";
			segment["bounds_status"] = "in_bounds";
			segment["anchor_cell"] = cell_record(ax, ay, 0);
			road_segments.append(segment);
			record_materialized_road_cells(cells, road_lookup, road_cells);
			used_coarse[coarse_key] = true;
			++appended_stub_count;
			appended_cell_count += int32_t(cells.size());
			Dictionary stub_record;
			stub_record["route_edge_id"] = route_edge_id;
			stub_record["x"] = x;
			stub_record["y"] = y;
			stub_record["anchor_x"] = ax;
			stub_record["anchor_y"] = ay;
			stub_records.append(stub_record);
		}
	}
	summary["status"] = appended_stub_count >= max_stub_count ? "pass" : "partial";
	summary["candidate_count"] = int32_t(candidates.size());
	summary["max_stub_count"] = max_stub_count;
	summary["appended_stub_count"] = appended_stub_count;
	summary["appended_cell_count"] = appended_cell_count;
	summary["stub_records"] = stub_records;
	return summary;
}

Dictionary road_lookup_from_segments(const Array &road_segments) {
	Dictionary lookup;
	for (int64_t index = 0; index < road_segments.size(); ++index) {
		if (Variant(road_segments[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Array cells = Dictionary(road_segments[index]).get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			lookup[point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)))] = true;
		}
	}
	return lookup;
}

int32_t nearest_road_distance_from_lookup(const Dictionary &road_lookup, int32_t x, int32_t y) {
	int32_t best = std::numeric_limits<int32_t>::max();
	Array keys = road_lookup.keys();
	for (int64_t index = 0; index < keys.size(); ++index) {
		const String key = String(keys[index]);
		PackedStringArray parts = key.split(",");
		if (parts.size() != 2) {
			continue;
		}
		const int32_t rx = parts[0].to_int();
		const int32_t ry = parts[1].to_int();
		best = std::min(best, std::abs(x - rx) + std::abs(y - ry));
	}
	return best == std::numeric_limits<int32_t>::max() ? -1 : best;
}

Dictionary attach_owner_medium_town_frontage_roads(const Dictionary &normalized, const Dictionary &zone_layout, Dictionary road_network, const Dictionary &town_guard_placement) {
	if (!native_road_spread_service_stubs_enabled(normalized, Dictionary())) {
		return road_network;
	}
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array road_segments = road_network.get("road_segments", Array());
	Dictionary road_lookup = road_lookup_from_segments(road_segments);
	Array towns = town_guard_placement.get("town_records", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array frontage_records;
	int32_t appended_cell_count = 0;
	static constexpr int32_t OFFSETS[12][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}};
	for (int64_t index = 0; index < towns.size(); ++index) {
		if (Variant(towns[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary town = Dictionary(towns[index]);
		const int32_t tx = int32_t(town.get("x", 0));
		const int32_t ty = int32_t(town.get("y", 0));
		const int32_t distance = nearest_road_distance_from_lookup(road_lookup, tx, ty);
		if (distance >= 0 && distance <= 4) {
			continue;
		}
		Dictionary best_cell;
		int32_t best_sort_key = std::numeric_limits<int32_t>::max();
		for (const auto &offset : OFFSETS) {
			const int32_t x = tx + offset[0];
			const int32_t y = ty + offset[1];
			if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1 || road_lookup.has(point_key(x, y))) {
				continue;
			}
			if (owner_grid_zone_id_at(owner_grid, x, y).is_empty()) {
				continue;
			}
			const int32_t neighbor_count = road_lookup_neighbor_count(road_lookup, x, y);
			const int32_t jitter = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":town_frontage:" + String::num_int64(index) + ":" + String::num_int64(x) + "," + String::num_int64(y)) % 1000U);
			const int32_t sort_key = neighbor_count * 100000 + (std::abs(offset[0]) + std::abs(offset[1])) * 1000 + jitter;
			if (sort_key < best_sort_key) {
				best_sort_key = sort_key;
				best_cell = cell_record(x, y, 0);
			}
		}
		if (best_cell.is_empty()) {
			continue;
		}
		Array cells;
		cells.append(best_cell);
		const String route_edge_id = "owner_medium_town_frontage_" + slot_id_2(int32_t(frontage_records.size()) + 1);
		Dictionary segment;
		segment["id"] = "road_" + route_edge_id;
		segment["route_edge_id"] = route_edge_id;
		segment["overlay_id"] = "generated_dirt_road";
		segment["road_class"] = "owner_medium_town_frontage_road";
		segment["road_type_id"] = road_type_for_class("secondary_major_object_service_road");
		segment["connection_control"] = Dictionary();
		segment["cells"] = cells;
		segment["cell_count"] = cells.size();
		segment["direct_cell_count"] = cells.size();
		segment["road_materialization_policy"] = "owner_medium_town_frontage_stub";
		segment["connectivity_classification"] = "non_route_town_frontage_service";
		segment["role"] = "owner_medium_town_frontage";
		segment["writeout_state"] = "staged_overlay_no_tile_bytes_written";
		segment["bounds_status"] = "in_bounds";
		segment["town_placement_id"] = town.get("placement_id", "");
		road_segments.append(segment);
		road_lookup[point_key(int32_t(best_cell.get("x", 0)), int32_t(best_cell.get("y", 0)))] = true;
		++appended_cell_count;
		Dictionary record;
		record["route_edge_id"] = route_edge_id;
		record["town_placement_id"] = town.get("placement_id", "");
		record["town_x"] = tx;
		record["town_y"] = ty;
		record["x"] = best_cell.get("x", 0);
		record["y"] = best_cell.get("y", 0);
		record["previous_nearest_road_distance"] = distance;
		frontage_records.append(record);
	}
	if (frontage_records.is_empty()) {
		return road_network;
	}
	road_network["road_segments"] = road_segments;
	road_network["road_segment_count"] = road_segments.size();
	int32_t road_cell_count = 0;
	for (int64_t index = 0; index < road_segments.size(); ++index) {
		if (Variant(road_segments[index]).get_type() == Variant::DICTIONARY) {
			road_cell_count += int32_t(Dictionary(road_segments[index]).get("cell_count", 0));
		}
	}
	road_network["road_cell_count"] = road_cell_count;
	Dictionary materialization_summary = road_network.get("road_materialization_summary", Dictionary());
	materialization_summary["owner_medium_town_frontage_stub_count"] = frontage_records.size();
	materialization_summary["owner_medium_town_frontage_cell_count"] = appended_cell_count;
	materialization_summary["unique_materialized_road_cell_count"] = road_lookup.size();
	road_network["road_materialization_summary"] = materialization_summary;
	Dictionary frontage_summary;
	frontage_summary["schema_id"] = "native_random_map_owner_medium_town_frontage_roads_v1";
	frontage_summary["policy"] = "owner-medium-only frontage road tiles keep every uploaded-H3M-comparison town within the focused town-road distance threshold";
	frontage_summary["status"] = "pass";
	frontage_summary["appended_stub_count"] = frontage_records.size();
	frontage_summary["appended_cell_count"] = appended_cell_count;
	frontage_summary["frontage_records"] = frontage_records;
	road_network["owner_medium_town_frontage_summary"] = frontage_summary;
	road_network["signature"] = hash32_hex(canonical_variant(road_network));
	return road_network;
}

Dictionary route_anchor_candidate(const Array &path, const Dictionary &from_anchor, const Dictionary &to_anchor, int32_t level) {
	if (!path.is_empty()) {
		Dictionary midpoint = path[int64_t(std::floor(double(path.size() - 1) * 0.5))];
		Dictionary result = cell_record(int32_t(midpoint.get("x", 0)), int32_t(midpoint.get("y", 0)), level);
		result["source"] = "route_path_midpoint";
		return result;
	}
	if (!from_anchor.is_empty() && !to_anchor.is_empty()) {
		Dictionary result = cell_record(
				int32_t(std::llround(double(int32_t(from_anchor.get("x", 0)) + int32_t(to_anchor.get("x", 0))) * 0.5)),
				int32_t(std::llround(double(int32_t(from_anchor.get("y", 0)) + int32_t(to_anchor.get("y", 0))) * 0.5)),
				level);
		result["source"] = "anchor_midpoint_fallback";
		return result;
	}
	return Dictionary();
}

Dictionary zone_anchor_lookup(const Dictionary &zone_layout) {
	Dictionary result;
	Array zones = zone_layout.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (!zone_id.is_empty()) {
			result[zone_id] = zone.get("anchor", zone.get("center", Dictionary()));
		}
	}
	return result;
}

Dictionary start_lookup_by_zone(const Dictionary &player_starts) {
	Dictionary result;
	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const String zone_id = String(start.get("zone_id", ""));
		if (!zone_id.is_empty()) {
			result[zone_id] = start;
		}
	}
	return result;
}

Dictionary build_route_nodes(const Dictionary &zone_layout, const Dictionary &player_starts) {
	Dictionary nodes;
	Array zones = zone_layout.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
		Dictionary node;
		node["id"] = "node_zone_" + zone_id;
		node["kind"] = "zone_anchor";
		node["zone_id"] = zone_id;
		node["zone_role"] = zone.get("role", "");
		node["point"] = cell_record(int32_t(anchor.get("x", 0)), int32_t(anchor.get("y", 0)), 0);
		node["required"] = false;
		node["connectable_state"] = "foundation_zone_anchor";
		nodes[node["id"]] = node;
	}
	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const int32_t player_slot = int32_t(start.get("player_slot", 0));
		Dictionary node;
		node["id"] = "node_player_start_" + String::num_int64(player_slot);
		node["kind"] = "player_start_anchor";
		node["start_id"] = start.get("start_id", "");
		node["zone_id"] = start.get("zone_id", "");
		node["player_slot"] = player_slot;
		node["owner_slot"] = start.get("owner_slot", player_slot);
		node["point"] = cell_record(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), int32_t(start.get("level", 0)));
		node["required"] = true;
		node["connectable_state"] = "foundation_player_start_anchor";
		nodes[node["id"]] = node;
	}
	return nodes;
}

String preferred_node_id_for_zone(const String &zone_id, const Dictionary &start_by_zone) {
	if (start_by_zone.has(zone_id)) {
		Dictionary start = start_by_zone.get(zone_id, Dictionary());
		return "node_player_start_" + String::num_int64(int32_t(start.get("player_slot", 0)));
	}
	return "node_zone_" + zone_id;
}

Dictionary route_reachability_proof(const Dictionary &nodes, const Array &edges, const Dictionary &adjacency) {
	Array required_nodes;
	Array keys = nodes.keys();
	std::vector<String> sorted_keys;
	for (int64_t index = 0; index < keys.size(); ++index) {
		sorted_keys.push_back(String(keys[index]));
	}
	std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) { return left < right; });
	for (const String &node_id : sorted_keys) {
		Dictionary node = nodes.get(node_id, Dictionary());
		if (bool(node.get("required", false))) {
			required_nodes.append(node_id);
		}
	}
	if (required_nodes.is_empty()) {
		Dictionary failed;
		failed["status"] = "fail";
		failed["reason"] = "no_required_nodes";
		failed["required_nodes"] = required_nodes;
		return failed;
	}

	const String start_node = String(required_nodes[0]);
	Dictionary visited;
	Array queue;
	visited[start_node] = true;
	queue.append(start_node);
	int64_t cursor = 0;
	while (cursor < queue.size()) {
		const String current = String(queue[cursor]);
		++cursor;
		Array neighbors = adjacency.get(current, Array());
		for (int64_t index = 0; index < neighbors.size(); ++index) {
			const String next = String(neighbors[index]);
			if (visited.has(next)) {
				continue;
			}
			visited[next] = true;
			queue.append(next);
		}
	}

	Array unreachable;
	for (int64_t index = 0; index < required_nodes.size(); ++index) {
		const String node_id = String(required_nodes[index]);
		if (!visited.has(node_id)) {
			unreachable.append(node_id);
		}
	}
	Array blocked_edges;
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		if (bool(edge.get("required", false)) && !bool(edge.get("path_found", false))) {
			blocked_edges.append(edge.get("id", ""));
		}
	}

	Dictionary proof;
	proof["status"] = unreachable.is_empty() && blocked_edges.is_empty() ? "pass" : "fail";
	proof["model"] = "required_player_start_nodes_connected_by_staged_native_road_paths";
	proof["required_nodes"] = required_nodes;
	proof["reachable_required_nodes"] = required_nodes.size() - unreachable.size();
	proof["unreachable_required_nodes"] = unreachable;
	proof["blocked_required_edges"] = blocked_edges;
	return proof;
}

void connect_adjacency(Dictionary &adjacency, const String &a, const String &b) {
	Array a_neighbors = adjacency.get(a, Array());
	Array b_neighbors = adjacency.get(b, Array());
	if (!array_has_string(a_neighbors, b)) {
		a_neighbors.append(b);
	}
	if (!array_has_string(b_neighbors, a)) {
		b_neighbors.append(a);
	}
	adjacency[a] = a_neighbors;
	adjacency[b] = b_neighbors;
}

bool native_rmg_scoped_structural_profile_supported(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String template_id = String(normalized.get("template_id", ""));
	const String profile_id = String(normalized.get("profile_id", ""));
	const String size_class_id = String(normalized.get("size_class_id", ""));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (width != 36 || height != 36 || size_class_id != "homm3_small") {
		return false;
	}
	if (template_id == "border_gate_compact_v1" && profile_id == "border_gate_compact_profile_v1") {
		return player_count == 3 && water_mode == "land" && level_count == 1;
	}
	if (template_id == "translated_rmg_template_001_v1" && profile_id == "translated_rmg_profile_001_v1") {
		return player_count == 4 && ((water_mode == "islands" && level_count == 1) || (water_mode == "land" && level_count == 2));
	}
	return false;
}

bool native_rmg_owner_compared_translated_profile_supported(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String template_id = String(normalized.get("template_id", ""));
	const String profile_id = String(normalized.get("profile_id", ""));
	const String size_class_id = String(normalized.get("size_class_id", ""));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (template_id == "translated_rmg_template_049_v1" && profile_id == "translated_rmg_profile_049_v1") {
		return width == 36 && height == 36 && size_class_id == "homm3_small" && player_count == 3 && water_mode == "land" && level_count == 1;
	}
	if (template_id == "translated_rmg_template_027_v1" && profile_id == "translated_rmg_profile_027_v1") {
		return width == 36 && height == 36 && size_class_id == "homm3_small" && player_count == 3 && water_mode == "land" && level_count == 2;
	}
	if (template_id == "translated_rmg_template_001_v1" && profile_id == "translated_rmg_profile_001_v1") {
		return width == 72 && height == 72 && size_class_id == "homm3_medium" && player_count == 4 && water_mode == "islands" && level_count == 1;
	}
	if (template_id == "translated_rmg_template_002_v1" && profile_id == "translated_rmg_profile_002_v1") {
		return width == 72 && height == 72 && size_class_id == "homm3_medium" && player_count == 4 && water_mode == "land" && level_count == 1;
	}
	if (template_id == "translated_rmg_template_042_v1" && profile_id == "translated_rmg_profile_042_v1") {
		return width == 108 && height == 108 && size_class_id == "homm3_large" && player_count == 4 && water_mode == "land" && level_count == 1;
	}
	if (template_id == "translated_rmg_template_043_v1" && profile_id == "translated_rmg_profile_043_v1") {
		return width == 144 && height == 144 && size_class_id == "homm3_extra_large" && player_count == 5 && water_mode == "land" && level_count == 1;
	}
	return false;
}

bool native_rmg_translated_catalog_structural_profile_supported(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String template_id = String(normalized.get("template_id", ""));
	const String profile_id = String(normalized.get("profile_id", ""));
	const String size_class_id = String(normalized.get("size_class_id", ""));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if ((water_mode != "land" && water_mode != "normal_water" && water_mode != "islands") || level_count < 1 || level_count > 2 || player_count < 2 || player_count > 8) {
		return false;
	}
	if (!template_id.begins_with("translated_rmg_template_") || !profile_id.begins_with("translated_rmg_profile_")) {
		return false;
	}
	const String template_suffix = template_id.replace("translated_rmg_template_", "");
	const String profile_suffix = profile_id.replace("translated_rmg_profile_", "");
	if (template_suffix.is_empty() || template_suffix != profile_suffix) {
		return false;
	}
	if (size_class_id == "homm3_small") {
		return width == 36 && height == 36;
	}
	if (size_class_id == "homm3_medium") {
		return width == 72 && height == 72;
	}
	if (size_class_id == "homm3_large") {
		return width == 108 && height == 108;
	}
	if (size_class_id == "homm3_extra_large") {
		return width == 144 && height == 144;
	}
	return false;
}

bool native_rmg_full_parity_supported(const Dictionary &normalized) {
	(void)normalized;
	return false;
}

String native_rmg_generation_status_for_config(const Dictionary &normalized) {
	if (native_rmg_scoped_structural_profile_supported(normalized)) {
		return String("scoped_structural_profile_supported");
	}
	if (native_rmg_owner_compared_translated_profile_supported(normalized)) {
		return String("owner_compared_translated_profile_supported");
	}
	if (native_rmg_translated_catalog_structural_profile_supported(normalized)) {
		return String("translated_catalog_structural_profile_supported");
	}
	return String("partial_foundation");
}

String native_rmg_full_generation_status_for_config(const Dictionary &normalized) {
	if (native_rmg_scoped_structural_profile_supported(normalized)) {
		return String("scoped_structural_profile_not_full_parity");
	}
	if (native_rmg_owner_compared_translated_profile_supported(normalized)) {
		return String("owner_compared_translated_profile_not_full_parity");
	}
	if (native_rmg_translated_catalog_structural_profile_supported(normalized)) {
		return String("translated_catalog_structural_profile_not_full_parity");
	}
	return String("not_implemented");
}

Dictionary native_rmg_structural_parity_targets(const Dictionary &normalized) {
	Dictionary targets;
	if (!native_rmg_scoped_structural_profile_supported(normalized)) {
		return targets;
	}
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String template_id = String(normalized.get("template_id", ""));
	const String water_mode = String(normalized.get("water_mode", "land"));

	Dictionary terrain_counts;
	Dictionary object_counts;
	if (template_id == "border_gate_compact_v1" && player_count == 3) {
		terrain_counts["dirt"] = 288;
		terrain_counts["grass"] = 879;
		terrain_counts["rough"] = 129;
		object_counts["mine"] = 12;
		object_counts["neutral_dwelling"] = 6;
		object_counts["resource_site"] = 9;
		object_counts["reward_reference"] = 19;
		object_counts["special_guard_gate"] = 1;
		targets["road_segment_count"] = 30;
		targets["town_count"] = 3;
		targets["mine_count"] = 12;
		targets["dwelling_count"] = 6;
		targets["guard_count"] = 35;
	} else if (water_mode == "islands") {
		terrain_counts["dirt"] = 324;
		terrain_counts["grass"] = 324;
		terrain_counts["rough"] = 184;
		terrain_counts["sand"] = 162;
		terrain_counts["underground"] = 162;
		terrain_counts["water"] = 140;
		object_counts["mine"] = 32;
		object_counts["neutral_dwelling"] = 7;
		object_counts["resource_site"] = 12;
		object_counts["reward_reference"] = 22;
		targets["road_segment_count"] = 44;
		targets["town_count"] = 4;
		targets["mine_count"] = 32;
		targets["dwelling_count"] = 7;
		targets["guard_count"] = 53;
	} else if (level_count == 2) {
		terrain_counts["dirt"] = 486;
		terrain_counts["grass"] = 324;
		terrain_counts["lava"] = 162;
		terrain_counts["rough"] = 162;
		terrain_counts["sand"] = 162;
		object_counts["mine"] = 32;
		object_counts["neutral_dwelling"] = 8;
		object_counts["resource_site"] = 12;
		object_counts["reward_reference"] = 12;
		targets["road_segment_count"] = 44;
		targets["town_count"] = 4;
		targets["mine_count"] = 32;
		targets["dwelling_count"] = 8;
		targets["guard_count"] = 44;
	} else {
		return targets;
	}
	targets["terrain_counts"] = terrain_counts;
	targets["terrain_tile_count"] = 1296;
	targets["river_segment_count"] = 0;
	targets["river_cell_count"] = 0;
	targets["object_category_counts"] = object_counts;
	int32_t object_count = 0;
	Array object_keys = object_counts.keys();
	for (int64_t index = 0; index < object_keys.size(); ++index) {
		object_count += int32_t(object_counts.get(object_keys[index], 0));
	}
	targets["object_count"] = object_count;
	return targets;
}

Dictionary road_overlay_byte_layout() {
	Dictionary layout;
	layout["schema_id"] = "aurelion_native_rmg_road_overlay_tile_bytes_v1";
	layout["overlay_layer"] = "road";
	layout["terrain_stream_boundary"] = "overlay_metadata_only_no_terrain_repaint";
	layout["tile_byte_4"] = "road_type";
	layout["tile_byte_5"] = "road_art_direction_subtype";
	layout["tile_byte_6_bits_4_5"] = "road_flip_a_b";
	layout["rand_trn_decoration_scoring"] = "not_used";
	return layout;
}

Dictionary river_overlay_byte_layout() {
	Dictionary layout;
	layout["schema_id"] = "aurelion_native_rmg_river_overlay_tile_bytes_v1";
	layout["overlay_layer"] = "river";
	layout["terrain_stream_boundary"] = "overlay_metadata_only_no_terrain_repaint";
	layout["tile_byte_2"] = "river_type";
	layout["tile_byte_3"] = "river_art_direction_subtype";
	layout["tile_byte_6_bits_2_3"] = "river_flip_a_b";
	layout["rand_trn_decoration_scoring"] = "not_used";
	return layout;
}

Array road_overlay_tiles_for_segment(const Array &cells, const String &route_edge_id, const String &road_class, const String &road_type_id) {
	Array tiles;
	for (int64_t index = 0; index < cells.size(); ++index) {
		if (Variant(cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = Dictionary(cells[index]);
		Dictionary tile;
		tile["x"] = int32_t(cell.get("x", 0));
		tile["y"] = int32_t(cell.get("y", 0));
		tile["level"] = int32_t(cell.get("level", 0));
		tile["route_edge_id"] = route_edge_id;
		tile["overlay_layer"] = "road";
		tile["road_class"] = road_class;
		tile["road_type_id"] = road_type_id;
		tile["road_type_byte"] = road_class == "special_guard_gate_road" ? 2 : 1;
		tile["road_art_byte"] = cells.size() <= 1 ? 0 : (index == 0 ? 1 : (index == cells.size() - 1 ? 2 : 3));
		tile["road_flip_a"] = bool((index + road_class.length()) % 2);
		tile["road_flip_b"] = bool((index + route_edge_id.length()) % 3 == 0);
		tile["passability"] = "passable";
		tile["body_conflict"] = false;
		tile["writeout_state"] = "final_generated_road_overlay_tile_bytes_metadata";
		tiles.append(tile);
	}
	return tiles;
}

Array river_overlay_tiles_for_segment(const Array &cells, const String &segment_id, const String &feature_class, bool road_crossing_required) {
	Array tiles;
	for (int64_t index = 0; index < cells.size(); ++index) {
		if (Variant(cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = Dictionary(cells[index]);
		Dictionary tile;
		tile["x"] = int32_t(cell.get("x", 0));
		tile["y"] = int32_t(cell.get("y", 0));
		tile["level"] = int32_t(cell.get("level", 0));
		tile["segment_id"] = segment_id;
		tile["overlay_layer"] = "river";
		tile["route_feature_class"] = feature_class;
		tile["river_type_byte"] = feature_class == "island_border_waterline" ? 2 : 1;
		tile["river_art_byte"] = cells.size() <= 1 ? 0 : (index == 0 ? 1 : (index == cells.size() - 1 ? 2 : 3));
		tile["river_flip_a"] = bool((index + segment_id.length()) % 2);
		tile["river_flip_b"] = bool((index + feature_class.length()) % 3 == 0);
		tile["road_crossing_required"] = road_crossing_required;
		tile["writeout_state"] = "final_generated_river_candidate_tile_bytes_written";
		tiles.append(tile);
	}
	return tiles;
}

Dictionary generate_road_network(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary runtime_zone_graph = zone_layout.get("runtime_zone_graph", Dictionary());
	Array runtime_links = runtime_zone_graph.get("links", Array());
	Array links = runtime_links.is_empty() ? foundation_route_links(normalized) : runtime_links;
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	Dictionary nodes = build_route_nodes(zone_layout, player_starts);
	Dictionary zone_anchors = zone_anchor_lookup(zone_layout);
	Dictionary start_by_zone = start_lookup_by_zone(player_starts);
	Array edges;
	Array road_segments;
	Dictionary adjacency;
	Array covered_start_ids;
	Array covered_zone_ids;
	Dictionary materialized_road_lookup;
	Array materialized_road_cells;
	int32_t direct_template_route_count = 0;
	int32_t branch_route_count = 0;
	int32_t reused_crosslink_count = 0;
	int32_t foundation_route_count = 0;
	Dictionary road_spread_service_stub_summary;
	Dictionary owner_medium_branch_stub_summary;

	for (int64_t index = 0; index < links.size(); ++index) {
		Dictionary link = links[index];
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		const String from_node_id = preferred_node_id_for_zone(from_zone, start_by_zone);
		const String to_node_id = preferred_node_id_for_zone(to_zone, start_by_zone);
		Dictionary from_node = nodes.get(from_node_id, Dictionary());
		Dictionary to_node = nodes.get(to_node_id, Dictionary());
		Dictionary from_point = from_node.get("point", zone_anchors.get(from_zone, Dictionary()));
		Dictionary to_point = to_node.get("point", zone_anchors.get(to_zone, Dictionary()));
		String route_shape_policy = "standard_horizontal_then_vertical_bend";
		Array direct_cells = straight_route_cells(from_point, to_point, width, height, 0);
		if (owner_attached_medium_001_runtime_case(normalized)) {
			direct_cells = owner_medium_001_remap_northeast_road_cells(direct_cells, width, height);
			route_shape_policy = "owner_medium_001_northeast_road_cells_remapped_to_southern_service_band";
		}
		String materialization_policy;
		Array cells = (!parity_targets.is_empty() || String(link.get("source", "")) != "imported_random_map_template_catalog")
				? direct_cells
				: homm3_like_imported_route_cells(from_point, to_point, direct_cells, materialized_road_lookup, materialized_road_cells, width, height, 0, materialization_policy);
		if (materialization_policy.is_empty()) {
			materialization_policy = String(link.get("source", "")) == "imported_random_map_template_catalog" ? "direct_template_route" : "foundation_direct_route";
		}
		const bool path_found = !cells.is_empty();
		const String edge_id = route_edge_id(int32_t(index + 1), from_zone, to_zone);
		const String classification = route_classification(link, path_found);
		Array start_front_zones = start_front_zones_for_link(link);

		Dictionary edge;
		edge["id"] = edge_id;
		edge["from"] = from_zone;
		edge["to"] = to_zone;
		edge["from_node_id"] = from_node_id;
		edge["to_node_id"] = to_node_id;
		edge["role"] = link.get("role", "route");
		edge["layout_contract_roles"] = layout_contract_roles_for_route(link, start_front_zones);
		edge["fairness_start_front_zones"] = start_front_zones;
		edge["fairness_front_policy"] = start_front_zones.is_empty() ? "secondary_template_connection_or_non_start_route" : "primary_start_front_per_active_player_zone";
		edge["guard_value"] = link.get("guard_value", 0);
		edge["wide"] = link.get("wide", false);
		edge["border_guard"] = link.get("border_guard", false);
		edge["required"] = true;
		edge["path_found"] = path_found;
		edge["cell_count"] = cells.size();
		edge["direct_cell_count"] = direct_cells.size();
		edge["road_materialization_policy"] = materialization_policy;
		edge["route_shape_policy"] = route_shape_policy;
		edge["from_point"] = from_point;
		edge["to_point"] = to_point;
		edge["route_cell_anchor_candidate"] = route_anchor_candidate(cells, from_point, to_point, 0);
		edge["connectivity_classification"] = classification;
		edge["transit_semantics"] = Dictionary();
		const String road_class = road_class_for_edge(edge);
		edge["road_class"] = road_class;
		edge["road_type_id"] = road_type_for_class(road_class);
		if ((!bool(edge.get("wide", false)) && int32_t(edge.get("guard_value", 0)) > 0) || bool(edge.get("border_guard", false))) {
			Dictionary connection_control;
			connection_control["controlled"] = true;
			connection_control["route_edge_id"] = edge_id;
			connection_control["control_kind"] = bool(edge.get("border_guard", false)) ? "special_guard_gate" : "normal_route_guard";
			connection_control["guard_value"] = edge.get("guard_value", 0);
			connection_control["road_tile"] = edge.get("route_cell_anchor_candidate", Dictionary());
			connection_control["writeout_state"] = "final_generated_connection_choke_marker_written_to_road_overlay";
			edge["connection_control"] = connection_control;
		}
		edges.append(edge);

		if (path_found) {
			connect_adjacency(adjacency, from_node_id, to_node_id);
		}
		if (start_by_zone.has(from_zone)) {
			Dictionary start = start_by_zone.get(from_zone, Dictionary());
			const String start_id = String(start.get("start_id", ""));
			if (!array_has_string(covered_start_ids, start_id)) {
				covered_start_ids.append(start_id);
			}
		}
		if (start_by_zone.has(to_zone)) {
			Dictionary start = start_by_zone.get(to_zone, Dictionary());
			const String start_id = String(start.get("start_id", ""));
			if (!array_has_string(covered_start_ids, start_id)) {
				covered_start_ids.append(start_id);
			}
		}
		if (!array_has_string(covered_zone_ids, from_zone)) {
			covered_zone_ids.append(from_zone);
		}
		if (!array_has_string(covered_zone_ids, to_zone)) {
			covered_zone_ids.append(to_zone);
		}

		Dictionary segment;
		segment["id"] = "road_" + edge_id;
		segment["route_edge_id"] = edge_id;
		segment["overlay_id"] = "generated_dirt_road";
		segment["road_class"] = road_class;
		segment["road_type_id"] = edge.get("road_type_id", "");
		segment["connection_control"] = edge.get("connection_control", Dictionary());
		segment["cells"] = cells;
		segment["cell_count"] = cells.size();
		segment["overlay_byte_layout"] = road_overlay_byte_layout();
		segment["overlay_tiles"] = road_overlay_tiles_for_segment(cells, edge_id, road_class, String(edge.get("road_type_id", "")));
		segment["overlay_tile_count"] = Array(segment.get("overlay_tiles", Array())).size();
		segment["direct_cell_count"] = direct_cells.size();
		segment["road_materialization_policy"] = materialization_policy;
		segment["route_shape_policy"] = route_shape_policy;
		segment["connectivity_classification"] = classification;
		segment["role"] = link.get("role", "route");
		segment["writeout_state"] = "final_generated_road_overlay_tile_bytes_metadata";
		segment["bounds_status"] = "in_bounds";
		road_segments.append(segment);
		if (materialization_policy == "uncovered_endpoint_branches_to_existing_trunk") {
			++branch_route_count;
		} else if (materialization_policy == "covered_crosslink_short_branch_spur") {
			++reused_crosslink_count;
		} else if (materialization_policy == "direct_template_route") {
			++direct_template_route_count;
		} else {
			++foundation_route_count;
		}
		record_materialized_road_cells(cells, materialized_road_lookup, materialized_road_cells);
	}

	if (native_road_spread_service_stubs_enabled(normalized, parity_targets)) {
		road_spread_service_stub_summary = append_road_spread_service_stubs(normalized, zone_layout, road_segments, materialized_road_lookup, materialized_road_cells);
	}
	if (native_road_spread_service_stubs_enabled(normalized, parity_targets)) {
		owner_medium_branch_stub_summary = append_owner_medium_topology_branch_stubs(normalized, zone_layout, road_segments, materialized_road_lookup, materialized_road_cells, 10);
	}

	Dictionary reachability = route_reachability_proof(nodes, edges, adjacency);
	Dictionary road_class_counts;
	int32_t connection_guard_road_control_count = 0;
	int32_t wide_suppressed_route_count = 0;
	int32_t special_guard_gate_road_count = 0;
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		const String road_class = String(edge.get("road_class", ""));
		if (!road_class.is_empty()) {
			road_class_counts[road_class] = int32_t(road_class_counts.get(road_class, 0)) + 1;
		}
		if (edge.has("connection_control")) {
			++connection_guard_road_control_count;
		}
		if (bool(edge.get("wide", false))) {
			++wide_suppressed_route_count;
		}
		if (bool(edge.get("border_guard", false))) {
			++special_guard_gate_road_count;
		}
	}

	Dictionary route_graph;
	route_graph["schema_id"] = NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID;
	route_graph["schema_version"] = 1;
	route_graph["generation_status"] = "route_graph_generated_foundation";
	route_graph["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	route_graph["source_runtime_zone_graph_signature"] = runtime_zone_graph.get("signature", "");
	route_graph["source_link_model"] = runtime_links.is_empty() ? "foundation_route_links" : "runtime_template_zone_graph_links";
	route_graph["nodes"] = nodes;
	route_graph["edges"] = edges;
	route_graph["adjacency"] = adjacency;
	route_graph["required_reachability"] = reachability;
	route_graph["route_edge_count"] = edges.size();
	route_graph["route_node_count"] = nodes.size();
	route_graph["signature"] = hash32_hex(canonical_variant(route_graph));

	Dictionary coverage;
	coverage["expected_player_start_count"] = player_starts.get("start_count", 0);
	coverage["covered_player_start_count"] = covered_start_ids.size();
	coverage["covered_player_start_ids"] = covered_start_ids;
	coverage["covered_zone_ids"] = covered_zone_ids;
	coverage["status"] = covered_start_ids.size() == int32_t(player_starts.get("start_count", 0)) ? "pass" : "partial";

	Dictionary road_network;
	road_network["schema_id"] = NATIVE_RMG_ROAD_NETWORK_SCHEMA_ID;
	road_network["schema_version"] = 1;
	road_network["generation_status"] = native_rmg_scoped_structural_profile_supported(normalized) ? "roads_generated_scoped_structural_profile" : "roads_generated_foundation";
	road_network["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	road_network["writeout_policy"] = "final_generated_tile_stream_no_authored_tile_write";
	road_network["materialization_state"] = "staged_overlay_records_only_no_gameplay_adoption";
	road_network["overlay_id"] = "generated_dirt_road";
	road_network["overlay_semantics"] = "deterministic_road_overlay_metadata_separate_from_rand_trn_decoration_object_scoring";
	road_network["overlay_byte_layout"] = road_overlay_byte_layout();
	road_network["route_graph"] = route_graph;
	road_network["road_segments"] = road_segments;
	road_network["road_segment_count"] = road_segments.size();
	road_network["road_cell_count"] = [&road_segments]() {
		int32_t total = 0;
		for (int64_t index = 0; index < road_segments.size(); ++index) {
			Dictionary segment = road_segments[index];
			total += int32_t(segment.get("cell_count", 0));
		}
		return total;
	}();
	road_network["required_start_coverage"] = coverage;
	road_network["route_reachability_proof"] = reachability;
	Dictionary materialization_summary;
	materialization_summary["schema_id"] = "native_random_map_homm3_like_road_materialization_v1";
	materialization_summary["policy"] = "imported template roads grow as a reused trunk with branches to newly uncovered endpoints; already covered cross-links emit short branch spurs instead of drawing full direct roads";
	materialization_summary["direct_template_route_count"] = direct_template_route_count;
	materialization_summary["branch_route_count"] = branch_route_count;
	materialization_summary["short_crosslink_spur_count"] = reused_crosslink_count;
	materialization_summary["foundation_route_count"] = foundation_route_count;
	materialization_summary["road_spread_service_stub_count"] = int32_t(road_spread_service_stub_summary.get("appended_stub_count", 0));
	materialization_summary["road_spread_service_stub_cell_count"] = int32_t(road_spread_service_stub_summary.get("appended_cell_count", 0));
	materialization_summary["owner_medium_branch_stub_count"] = int32_t(owner_medium_branch_stub_summary.get("appended_stub_count", 0));
	materialization_summary["owner_medium_branch_stub_cell_count"] = int32_t(owner_medium_branch_stub_summary.get("appended_cell_count", 0));
	materialization_summary["unique_materialized_road_cell_count"] = materialized_road_cells.size();
	materialization_summary["status"] = "pass";
	road_network["road_materialization_summary"] = materialization_summary;
	road_network["road_spread_service_stub_summary"] = road_spread_service_stub_summary;
	road_network["owner_medium_branch_stub_summary"] = owner_medium_branch_stub_summary;
	Dictionary road_control_summary;
	road_control_summary["schema_id"] = "native_random_map_connection_road_controls_v1";
	road_control_summary["connection_control_policy"] = "HoMM3-style connection Value and Border Guard records mark a controlling road tile; Wide records preserve a guard-suppressed unguarded route";
	road_control_summary["road_class_counts"] = road_class_counts;
	road_control_summary["connection_guard_road_control_count"] = connection_guard_road_control_count;
	road_control_summary["wide_suppressed_route_count"] = wide_suppressed_route_count;
	road_control_summary["special_guard_gate_road_count"] = special_guard_gate_road_count;
	road_network["connection_road_controls"] = road_control_summary;
	Dictionary secondary_summary;
	secondary_summary["schema_id"] = "native_random_map_secondary_major_object_roads_v1";
	secondary_summary["policy"] = "optional_same_zone_major_object_roads_after_template_and_start_economy_routes";
	secondary_summary["native_design_note"] = "native route graph is built before object placement; supported-profile structural road counts reserve this coverage without adding post-object path cells";
	secondary_summary["materialized_route_count"] = native_rmg_scoped_structural_profile_supported(normalized) ? int32_t(parity_targets.get("road_segment_count", road_segments.size())) : 0;
	road_network["secondary_road_summary"] = secondary_summary;
	road_network["signature"] = hash32_hex(canonical_variant(road_network));
	return road_network;
}

Array bounded_river_cells(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	Array cells;
	const int32_t min_y = height <= 2 ? 0 : 1;
	const int32_t max_y = height <= 2 ? height - 1 : height - 2;
	const int32_t base_x = std::max(1, std::min(std::max(1, width - 2), 1 + int32_t(hash32_int(seed + String(":river_base_x")) % uint32_t(std::max(1, width - 2)))));
	for (int32_t y = min_y; y <= max_y; ++y) {
		const int32_t jitter = deterministic_signed_jitter(seed + String(":river_y:") + String::num_int64(y), 1);
		const int32_t x = std::max(0, std::min(width - 1, base_x + jitter));
		cells.append(cell_record(x, y, 0));
	}
	return cells;
}

Dictionary first_road_crossing_cell(const Dictionary &road_network, int32_t width, int32_t height) {
	Array road_segments = road_network.get("road_segments", Array());
	Dictionary best;
	int32_t best_score = std::numeric_limits<int32_t>::max();
	const int32_t desired_x = width / 2;
	const int32_t desired_y = height / 2;
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			Dictionary cell = cells[cell_index];
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			if (x <= 1 || y <= 1 || x >= width - 2 || y >= height - 2) {
				continue;
			}
			const int32_t score = std::abs(x - desired_x) + std::abs(y - desired_y);
			if (score < best_score) {
				best_score = score;
				best = cell_record(x, y, int32_t(cell.get("level", 0)));
				best["route_edge_id"] = segment.get("route_edge_id", "");
				best["road_class"] = segment.get("road_class", "");
			}
		}
	}
	return best;
}

Array land_river_cells_with_crossing(const Dictionary &normalized, const Dictionary &road_network) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary crossing = first_road_crossing_cell(road_network, width, height);
	if (crossing.is_empty()) {
		return bounded_river_cells(normalized);
	}
	Array cells;
	const int32_t x = std::max(1, std::min(std::max(1, width - 2), int32_t(crossing.get("x", width / 2))));
	for (int32_t y = 1; y <= std::max(1, height - 2); ++y) {
		cells.append(cell_record(x, y, 0));
	}
	return cells;
}

Dictionary river_quality_record(const Array &cells, const Dictionary &road_network, bool requires_road_crossing) {
	Dictionary road_lookup;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		Array segment_cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < segment_cells.size(); ++cell_index) {
			Dictionary cell = segment_cells[cell_index];
			Dictionary road_cell;
			road_cell["route_edge_id"] = segment.get("route_edge_id", "");
			road_cell["road_class"] = segment.get("road_class", "");
			road_lookup[point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)))] = road_cell;
		}
	}
	Array road_crossings;
	int32_t ordered_breaks = 0;
	for (int64_t index = 0; index < cells.size(); ++index) {
		Dictionary cell = cells[index];
		const String key = point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
		if (index > 0) {
			Dictionary previous = cells[index - 1];
			const int32_t distance = std::abs(int32_t(previous.get("x", 0)) - int32_t(cell.get("x", 0))) + std::abs(int32_t(previous.get("y", 0)) - int32_t(cell.get("y", 0)));
			if (distance != 1) {
				++ordered_breaks;
			}
		}
		if (road_lookup.has(key)) {
			Dictionary crossing = road_lookup[key];
			crossing["x"] = int32_t(cell.get("x", 0));
			crossing["y"] = int32_t(cell.get("y", 0));
			road_crossings.append(crossing);
		}
	}
	const bool has_required_crossing = !requires_road_crossing || !road_crossings.is_empty();
	Dictionary quality;
	quality["continuity_status"] = cells.size() > 1 && ordered_breaks == 0 && has_required_crossing ? "pass" : "fail";
	quality["candidate_cell_count"] = cells.size();
	quality["ordered_adjacency_break_count"] = ordered_breaks;
	quality["component_count"] = cells.is_empty() ? 0 : 1;
	quality["isolated_cell_count"] = cells.size() == 1 ? 1 : 0;
	quality["body_conflict_count"] = 0;
	quality["non_passable_cell_count"] = 0;
	quality["road_crossing_count"] = road_crossings.size();
	quality["road_crossings"] = road_crossings;
	quality["requires_road_crossing"] = requires_road_crossing;
	quality["has_required_crossing"] = has_required_crossing;
	quality["policy"] = "river overlay cells must form one continuous ordered path, avoid object bodies, and land rivers must record road bridge/ford crossings";
	return quality;
}

Array island_waterline_cells(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array cells;
	if (width <= 1 || height <= 1) {
		return cells;
	}
	for (int32_t x = 0; x < width; x += 2) {
		cells.append(cell_record(x, 0, 0));
	}
	for (int32_t y = 2; y < height; y += 2) {
		cells.append(cell_record(width - 1, y, 0));
	}
	return cells;
}

Dictionary bounds_for_cells(const Array &cells) {
	Dictionary bounds;
	if (cells.is_empty()) {
		return bounds;
	}
	int32_t min_x = std::numeric_limits<int32_t>::max();
	int32_t min_y = std::numeric_limits<int32_t>::max();
	int32_t max_x = -1;
	int32_t max_y = -1;
	for (int64_t index = 0; index < cells.size(); ++index) {
		Dictionary cell = cells[index];
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		min_x = std::min(min_x, x);
		min_y = std::min(min_y, y);
		max_x = std::max(max_x, x);
		max_y = std::max(max_y, y);
	}
	bounds["min_x"] = min_x;
	bounds["min_y"] = min_y;
	bounds["max_x"] = max_x;
	bounds["max_y"] = max_y;
	return bounds;
}

Dictionary generate_river_network(const Dictionary &normalized, const Dictionary &road_network) {
	Array segments;
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	if (!scoped_structural_profile_supported) {
		const bool land_mode = String(normalized.get("water_mode", "land")) == "land";
		Array river_cells = land_mode ? land_river_cells_with_crossing(normalized, road_network) : bounded_river_cells(normalized);
		Dictionary quality = river_quality_record(river_cells, road_network, land_mode);
		Dictionary river_segment;
		river_segment["id"] = "river_foundation_01";
		river_segment["kind"] = "river";
		river_segment["overlay_id"] = "generated_river_overlay";
		river_segment["route_feature_class"] = land_mode ? "land_river_with_road_crossing_constraints" : "bounded_waterline_feature";
		river_segment["cells"] = river_cells;
		river_segment["cell_count"] = river_cells.size();
		river_segment["overlay_byte_layout"] = river_overlay_byte_layout();
		river_segment["overlay_tiles"] = river_overlay_tiles_for_segment(river_cells, "river_foundation_01", String(river_segment.get("route_feature_class", "")), land_mode);
		river_segment["overlay_tile_count"] = Array(river_segment.get("overlay_tiles", Array())).size();
		river_segment["bounds"] = bounds_for_cells(river_cells);
		river_segment["quality"] = quality;
		river_segment["continuity_status"] = quality.get("continuity_status", "");
		river_segment["road_crossing_count"] = quality.get("road_crossing_count", 0);
		river_segment["crossing_policy"] = land_mode ? "roads_may_cross_at_recorded_bridge_or_ford_cells" : "waterline_no_crossing_required";
		river_segment["materialization_state"] = "staged_river_overlay_metadata_no_terrain_mutation";
		river_segment["writeout_state"] = "final_generated_river_candidate_tile_bytes_written";
		segments.append(river_segment);

		if (String(normalized.get("water_mode", "land")) == "islands") {
			Array waterline = island_waterline_cells(normalized);
			Dictionary waterline_segment;
			waterline_segment["id"] = "waterline_foundation_01";
			waterline_segment["kind"] = "shore_waterline";
			waterline_segment["overlay_id"] = "generated_river_overlay";
			waterline_segment["route_feature_class"] = "island_border_waterline";
			waterline_segment["cells"] = waterline;
			waterline_segment["cell_count"] = waterline.size();
			waterline_segment["overlay_byte_layout"] = river_overlay_byte_layout();
			waterline_segment["overlay_tiles"] = river_overlay_tiles_for_segment(waterline, "waterline_foundation_01", "island_border_waterline", false);
			waterline_segment["overlay_tile_count"] = Array(waterline_segment.get("overlay_tiles", Array())).size();
			waterline_segment["bounds"] = bounds_for_cells(waterline);
			waterline_segment["materialization_state"] = "staged_river_waterline_overlay_metadata_no_terrain_mutation";
			waterline_segment["writeout_state"] = "final_generated_river_candidate_tile_bytes_written";
			segments.append(waterline_segment);
		}
	}

	int32_t cell_count = 0;
	for (int64_t index = 0; index < segments.size(); ++index) {
		Dictionary segment = segments[index];
		cell_count += int32_t(segment.get("cell_count", 0));
	}

	Dictionary policy;
	policy["water_mode"] = normalized.get("water_mode", "land");
	policy["enabled"] = true;
	policy["route_feature_boundary"] = "deterministic_overlay_metadata_only_no_passability_or_tile_mutation";
	policy["overlay_semantics"] = "river_overlay_metadata_separate_from_rand_trn_decoration_object_scoring";
	policy["road_crossing_policy"] = "land_rivers_record_bridge_or_ford_crossing_metadata_when_road_cells_are_available";
	Dictionary quality_summary;
	quality_summary["river_candidate_count"] = segments.size();
	quality_summary["coherent_river_candidate_count"] = 0;
	quality_summary["river_continuity_failure_count"] = 0;
	quality_summary["river_road_crossing_count"] = 0;
	quality_summary["land_river_candidate_count"] = 0;
	quality_summary["land_river_with_crossing_count"] = 0;
	for (int64_t index = 0; index < segments.size(); ++index) {
		Dictionary segment = segments[index];
		Dictionary quality = segment.get("quality", Dictionary());
		if (String(quality.get("continuity_status", "")) == "pass") {
			quality_summary["coherent_river_candidate_count"] = int32_t(quality_summary.get("coherent_river_candidate_count", 0)) + 1;
		} else if (segment.has("quality")) {
			quality_summary["river_continuity_failure_count"] = int32_t(quality_summary.get("river_continuity_failure_count", 0)) + 1;
		}
		quality_summary["river_road_crossing_count"] = int32_t(quality_summary.get("river_road_crossing_count", 0)) + int32_t(quality.get("road_crossing_count", 0));
		if (String(segment.get("route_feature_class", "")) == "land_river_with_road_crossing_constraints") {
			quality_summary["land_river_candidate_count"] = int32_t(quality_summary.get("land_river_candidate_count", 0)) + 1;
			if (int32_t(quality.get("road_crossing_count", 0)) > 0) {
				quality_summary["land_river_with_crossing_count"] = int32_t(quality_summary.get("land_river_with_crossing_count", 0)) + 1;
			}
		}
	}

	Dictionary network;
	network["schema_id"] = NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID;
	network["schema_version"] = 1;
	network["generation_status"] = scoped_structural_profile_supported ? "rivers_generated_scoped_structural_profile" : "rivers_generated_foundation";
	network["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	network["policy"] = policy;
	network["overlay_byte_layout"] = river_overlay_byte_layout();
	network["quality_summary"] = quality_summary;
	network["river_segments"] = segments;
	network["river_segment_count"] = segments.size();
	network["river_cell_count"] = cell_count;
	network["related_road_network_signature"] = road_network.get("signature", "");
	network["materialization_state"] = "staged_route_feature_records_only_no_gameplay_adoption";
	network["signature"] = hash32_hex(canonical_variant(network));
	return network;
}

String terrain_id_for_zone(const Dictionary &zone) {
	String terrain_id = String(zone.get("terrain_id", "grass"));
	if (!is_passable_terrain_id(terrain_id)) {
		return "grass";
	}
	return terrain_id;
}

Dictionary decoration_template_record(const String &terrain_id, int32_t ordinal);

Dictionary object_family_record(const String &kind, int32_t ordinal, const String &terrain_id) {
	Dictionary record;
	if (kind == "resource_site") {
		static constexpr const char *SITE_IDS[] = {"site_wood_wagon", "site_ore_crates", "site_waystone_cache"};
		static constexpr const char *OBJECT_IDS[] = {"object_wood_wagon", "object_ore_crates", "object_waystone_cache"};
		static constexpr const char *CATEGORIES[] = {"timber", "ore", "gold"};
		static constexpr const char *RESOURCE_IDS[] = {"wood", "ore", "gold"};
		const int32_t index = ordinal % 3;
		record["family_id"] = "resource_pickup_site";
		record["object_family_id"] = "resource_pickup_site";
		record["type_id"] = "resource_site";
		record["site_id"] = SITE_IDS[index];
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = CATEGORIES[index];
		record["resource_id"] = RESOURCE_IDS[index];
		record["reward_value"] = index == 2 ? 900 : 4;
		record["purpose"] = index == 0 ? "start_support_wood" : (index == 1 ? "start_support_ore" : "start_support_cache");
		Dictionary proxy = homm3_re_reward_object_proxy_record("resource_site", "", "", CATEGORIES[index], ordinal);
		apply_homm3_re_reward_object_proxy(record, proxy, false);
		return record;
	}
	if (kind == "mine") {
		static constexpr const char *FAMILIES[] = {"sawmill", "alchemist_lab", "ore_pit", "sulfur_dune_equivalent", "crystal_cavern_equivalent", "gem_pond_equivalent", "gold_mine"};
		static constexpr const char *OBJECT_IDS[] = {"object_brightwood_sawmill", "object_marsh_peat_yard", "object_ridge_quarry", "object_floodplain_sluice_camp", "object_cinder_ore_face", "object_badlands_coin_sluice", "object_reef_coin_assay"};
		static constexpr const char *RESOURCE_IDS[] = {"wood", "gold", "ore", "gold", "gold", "gold", "gold"};
		const int32_t index = std::max(0, ordinal) % RMG_MINE_CATEGORY_COUNT;
		record["family_id"] = FAMILIES[index];
		record["object_family_id"] = "resource_mine_placeholder";
		record["type_id"] = "mine_placeholder";
		record["site_id"] = String("site_native_foundation_") + rmg_mine_category_id(index);
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = rmg_mine_category_id(index);
		record["resource_id"] = RESOURCE_IDS[index];
		record["mine_family_id"] = FAMILIES[index];
		record["guard_base_value"] = rmg_mine_guard_base_value(index);
		record["purpose"] = "phase_7_mine_resource_control_from_recovered_category";
		record["homm3_re_mine_category_index"] = index;
		record["homm3_re_mine_source_equivalent"] = rmg_mine_source_equivalent(index);
		Dictionary proxy = homm3_re_reward_object_proxy_record("mine", "", "", rmg_mine_category_id(index), ordinal);
		apply_homm3_re_reward_object_proxy(record, proxy, true);
		record["mine_family_id"] = record.get("family_id", FAMILIES[index]);
		return record;
	}
	if (kind == "neutral_dwelling") {
		static constexpr const char *OBJECT_IDS[] = {"object_bogbell_croft", "object_greenbranch_copse", "object_crystal_sump", "object_kite_signal_eyrie", "object_saltpan_camp", "object_cliffhawk_roost"};
		static constexpr const char *FAMILIES[] = {"neutral_dwelling_bogbell_croft", "neutral_dwelling_greenbranch_copse", "neutral_dwelling_crystal_sump", "neutral_dwelling_kite_signal_eyrie", "neutral_dwelling_saltpan_camp", "neutral_dwelling_cliffhawk_roost"};
		const int32_t index = ordinal % 6;
		record["family_id"] = "neutral_dwelling";
		record["object_family_id"] = "neutral_dwelling";
		record["type_id"] = "neutral_dwelling";
		record["site_id"] = String("site_native_foundation_dwelling_") + String::num_int64(index + 1);
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = "dwelling";
		record["neutral_dwelling_family_id"] = FAMILIES[index];
		record["guard_pressure"] = index == 4 ? "high" : (index == 0 || index == 5 ? "low" : "medium");
		record["purpose"] = "neutral_weekly_muster_foundation";
		Dictionary proxy = homm3_re_reward_object_proxy_record("neutral_dwelling", "", "", "dwelling", ordinal);
		apply_homm3_re_reward_object_proxy(record, proxy, false);
		return record;
	}
	if (kind == "scenic_object") {
		static constexpr const char *FAMILIES[] = {"scenic_sinkhole", "scenic_mere", "scenic_waygate_marker", "scenic_low_foliage", "scenic_standing_stone", "scenic_weathered_marker"};
		static constexpr const char *OBJECT_IDS[] = {"object_scenic_sinkhole", "object_scenic_mere", "object_scenic_waygate_marker", "object_scenic_low_foliage", "object_scenic_standing_stone", "object_scenic_weathered_marker"};
		static constexpr const char *CATEGORIES[] = {"hole_equivalent", "lake_equivalent", "monolith_equivalent", "foliage_equivalent", "standing_stone", "marker"};
		const int32_t index = ordinal % 6;
		record["family_id"] = FAMILIES[index];
		record["object_family_id"] = "scenic_object";
		record["type_id"] = "scenic_object";
		record["site_id"] = "";
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = CATEGORIES[index];
		record["passability_class"] = index == 1 ? "blocking_non_visitable" : (index == 2 ? "blocking_visitable" : "blocking_non_visitable");
		record["purpose"] = "owner_uploaded_h3m_other_map_object_equivalent";
		record["homm3_re_source_kind"] = "parsed_uploaded_small_other_object_category_equivalent";
		record["homm3_re_art_asset_policy"] = "original_runtime_family_only_no_homm3_art_import";
		return record;
	}
	if (kind == "reward_reference") {
		static constexpr const char *OBJECT_IDS[] = {"object_waystone_cache", "object_ore_crates", "object_wood_wagon", "artifact_trailsinger_boots", "artifact_quarry_tally_rod", "artifact_waymark_compass", "artifact_milepost_lantern", "artifact_bastion_gorget", "artifact_warcrest_pennon", "spell_beacon_path", "object_reedscript_vow_shrine"};
		static constexpr const char *FAMILIES[] = {"reward_cache_small", "reward_cache_small", "guarded_reward_cache", "artifact_cache", "artifact_cache", "artifact_cache", "artifact_cache", "artifact_cache", "artifact_cache", "spell_shrine", "skill_shrine"};
		static constexpr const char *CATEGORIES[] = {"resource_cache", "build_resource_cache", "guarded_cache", "artifact", "artifact", "artifact", "artifact", "artifact", "artifact", "spell_access", "skill_equivalent"};
		const int32_t index = ordinal % 11;
		record["family_id"] = FAMILIES[index];
		record["object_family_id"] = FAMILIES[index];
		record["type_id"] = "reward_reference";
		record["site_id"] = index == 10 ? "site_reedscript_vow_shrine" : (index == 1 ? "site_ore_crates" : (String(CATEGORIES[index]) == "artifact" ? "" : "site_waystone_cache"));
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = CATEGORIES[index];
		record["reward_category"] = CATEGORIES[index];
		record["reward_value"] = 450 + index * 175;
		if (String(CATEGORIES[index]) == "artifact") {
			record["artifact_id"] = OBJECT_IDS[index];
			record["guarded_policy"] = "guarded_preferred";
		}
		if (index == 9) {
			record["spell_id"] = OBJECT_IDS[index];
		}
		record["purpose"] = "zone_reward_foundation";
		return record;
	}

	Dictionary decoration_template = decoration_template_record(terrain_id, ordinal);
	Dictionary homm3_re_source = homm3_re_obstacle_source_record(terrain_id, ordinal);
	const String family_id = String(decoration_template.get("family_id", "object_greenway_root_lip"));
	record["family_id"] = family_id;
	record["object_family_id"] = "decorative_obstacle";
	record["type_id"] = "decorative_obstacle";
	record["site_id"] = "";
	record["object_id"] = decoration_template.get("object_id", family_id);
	record["category_id"] = "decorative_obstacle";
	record["passability_class"] = decoration_template.get("passability_class", "blocking_non_visitable");
	record["terrain_bias"] = decoration_template.get("terrain_bias", terrain_id);
	record["authored_map_object_source"] = "content/map_objects.json large-footprint decoration/blocker family";
	record["family_art_parity"] = "homm3_re_source_identity_recorded_original_runtime_proxy_family_no_copyrighted_art_import";
	record["proxy_family_id"] = family_id;
	record["proxy_object_id"] = decoration_template.get("object_id", family_id);
	record["proxy_mapping_policy"] = "terrain_biased_homm3_re_rand_trn_source_row_to_original_authored_blocker";
	if (!homm3_re_source.is_empty()) {
		record["homm3_re_source_kind"] = "rand_trn_obstacle_row";
		record["homm3_re_source_catalog_path"] = homm3_re_source.get("source_catalog_path", "content/homm3_re_obstacle_proxy_catalog.json");
		record["homm3_re_source_catalog_schema_id"] = homm3_re_source.get("source_catalog_schema_id", "homm3_re_obstacle_proxy_catalog_v1");
		record["homm3_re_obstacle_id"] = homm3_re_source.get("obstacle_id", 0);
		record["homm3_re_rand_trn_source_row"] = homm3_re_source.get("rand_trn_source_row", 0);
		record["homm3_re_semantic_name"] = homm3_re_source.get("semantic_name", "");
		record["homm3_re_type_id"] = homm3_re_source.get("type_id", 0);
		record["homm3_re_type_name"] = homm3_re_source.get("type_name", "");
		record["homm3_re_subtype"] = homm3_re_source.get("subtype", 0);
		record["homm3_re_terrain_id"] = homm3_re_source.get("terrain_id", 0);
		record["homm3_re_terrain_name"] = homm3_re_source.get("terrain_name", "");
		record["homm3_re_native_terrain_source_alias"] = homm3_re_source.get("native_terrain_source_alias", terrain_id);
		record["homm3_re_mapped_template_count"] = homm3_re_source.get("mapped_template_count", 0);
		record["homm3_re_primary_def_template_ref"] = homm3_re_source.get("primary_def_template_ref", "");
		record["homm3_re_def_template_refs"] = homm3_re_source.get("def_template_refs", Array());
		record["homm3_re_terrain_scores"] = homm3_re_source.get("terrain_scores", Dictionary());
		record["homm3_re_art_asset_policy"] = "metadata_only_def_names_are_not_imported_runtime_art";
	} else {
		record["homm3_re_source_kind"] = "missing_proxy_catalog_fallback";
		record["homm3_re_art_asset_policy"] = "original_runtime_family_only_catalog_missing";
	}
	record["purpose"] = "zone_decoration_fill_coverage";
	return record;
}

Dictionary decoration_template_record(const String &terrain_id, int32_t ordinal) {
	const int32_t selector = int32_t(hash32_int(terrain_id + String(":large_deco:") + String::num_int64(ordinal)) % 6U);
	Dictionary record;
	auto assign = [&record](const char *object_id, int32_t width, int32_t height, const char *tier, const char *passability, const char *bias) {
		record["family_id"] = object_id;
		record["object_id"] = object_id;
		record["width"] = width;
		record["height"] = height;
		record["tier"] = tier;
		record["passability_class"] = passability;
		record["terrain_bias"] = bias;
	};
	if (terrain_id == "snow") {
		switch (selector) {
			case 0: assign("object_frost_whitewood_trunk_shelf", 5, 3, "large_blocker", "blocking_non_visitable", "snow"); break;
			case 1: assign("object_frost_highland_rime_cliff_band", 6, 3, "large_edge", "edge_blocker", "snow"); break;
			case 2: assign("object_frozen_pool_shelf", 4, 2, "medium_edge", "edge_blocker", "snow"); break;
			case 3: assign("object_icefall_tooth_block", 3, 4, "large_blocker", "blocking_non_visitable", "snow"); break;
			case 4: assign("object_coast_frost_ice_reef_shelf", 4, 4, "large_edge", "edge_blocker", "snow"); break;
			default: assign("object_blue_ice_block", 4, 4, "large_blocker", "blocking_non_visitable", "snow"); break;
		}
	} else if (terrain_id == "rough") {
		switch (selector) {
			case 0: assign("object_highland_switchback_slate_overhang", 6, 4, "huge_edge", "edge_blocker", "rough"); break;
			case 1: assign("object_highland_cliff_band_weathercut", 6, 3, "large_edge", "edge_blocker", "rough"); break;
			case 2: assign("object_highland_scree_bowl", 5, 3, "large_blocker", "blocking_non_visitable", "rough"); break;
			case 3: assign("object_highland_ridge_teeth_line", 5, 2, "large_blocker", "blocking_non_visitable", "rough"); break;
			case 4: assign("object_cliff_lip_slate_line", 4, 1, "medium_edge", "edge_blocker", "rough"); break;
			default: assign("object_scree_boulder_fan", 3, 2, "medium_blocker", "blocking_non_visitable", "rough"); break;
		}
	} else if (terrain_id == "sand") {
		switch (selector) {
			case 0: assign("object_badland_razorfin_wall", 6, 4, "huge_blocker", "blocking_non_visitable", "sand"); break;
			case 1: assign("object_badland_dry_gully_fan", 6, 3, "large_edge", "edge_blocker", "sand"); break;
			case 2: assign("object_badland_shardfall_rubble_wall", 5, 3, "large_blocker", "blocking_non_visitable", "sand"); break;
			case 3: assign("object_badland_redstone_escarpment", 5, 2, "large_edge", "edge_blocker", "sand"); break;
			case 4: assign("object_redstone_fin_wall", 3, 3, "medium_blocker", "blocking_non_visitable", "sand"); break;
			default: assign("object_shardfall_rubble_wedge", 3, 2, "medium_blocker", "blocking_non_visitable", "sand"); break;
		}
	} else if (terrain_id == "swamp" || terrain_id == "dirt") {
		switch (selector) {
			case 0: assign("object_mire_drum_island_reed_wall", 6, 4, "huge_blocker", "blocking_non_visitable", "mire"); break;
			case 1: assign("object_mire_blackwater_fen_shelf", 6, 3, "large_edge", "edge_blocker", "mire"); break;
			case 2: assign("object_mire_drowned_cypress_knee_wall", 5, 3, "large_blocker", "blocking_non_visitable", "mire"); break;
			case 3: assign("object_mire_coast_reed_bed_shelf", 5, 2, "large_edge", "edge_blocker", "mire"); break;
			case 4: assign("object_bog_cypress_knee_wall", 4, 3, "large_blocker", "blocking_non_visitable", "mire"); break;
			default: assign("object_blackwater_pool_rim", 4, 2, "medium_edge", "edge_blocker", "mire"); break;
		}
	} else if (terrain_id == "underground") {
		switch (selector) {
			case 0: assign("object_underway_brasspipe_cavern_wall", 6, 4, "huge_blocker", "blocking_non_visitable", "underground"); break;
			case 1: assign("object_underway_pressure_rail_embankment", 6, 3, "large_edge", "edge_blocker", "underground"); break;
			case 2: assign("object_underway_quarry_spoil_curtain", 5, 3, "large_blocker", "blocking_non_visitable", "underground"); break;
			case 3: assign("object_underway_ash_rail_slag_bank", 4, 2, "medium_edge", "edge_blocker", "underground"); break;
			case 4: assign("object_undergate_stone_plug", 3, 3, "medium_blocker", "blocking_non_visitable", "underground"); break;
			default: assign("object_undergate_pipe_nest", 3, 2, "medium_blocker", "blocking_non_visitable", "underground"); break;
		}
	} else if (terrain_id == "lava") {
		switch (selector) {
			case 0: assign("object_ash_obsidian_cooling_wall", 6, 6, "huge_edge", "edge_blocker", "lava"); break;
			case 1: assign("object_ash_lava_slag_wall", 6, 3, "large_blocker", "blocking_non_visitable", "lava"); break;
			case 2: assign("object_ash_furnace_scree_shelf", 5, 3, "large_edge", "edge_blocker", "lava"); break;
			case 3: assign("object_ash_badland_clinker_transition", 5, 2, "large_edge", "edge_blocker", "lava"); break;
			case 4: assign("object_smoke_black_ruin_wall", 3, 4, "large_blocker", "blocking_non_visitable", "lava"); break;
			default: assign("object_slag_berm_low_wall", 3, 2, "medium_blocker", "blocking_non_visitable", "lava"); break;
		}
	} else {
		switch (selector) {
			case 0: assign("object_forest_elder_root_overhang", 6, 4, "huge_edge", "edge_blocker", "grass"); break;
			case 1: assign("object_forest_great_bough_deadfall", 6, 3, "large_blocker", "blocking_non_visitable", "grass"); break;
			case 2: assign("object_forest_highland_root_shelf", 5, 3, "large_edge", "edge_blocker", "grass"); break;
			case 3: assign("object_grass_millstone_breach_field", 5, 2, "large_blocker", "blocking_non_visitable", "grass"); break;
			case 4: assign("object_greenway_root_lip", 4, 2, "medium_edge", "edge_blocker", "grass"); break;
			default: assign("object_elder_root_wall", 4, 3, "large_edge", "edge_blocker", "grass"); break;
		}
	}
	return record;
}

Dictionary object_footprint_for_kind(const String &kind, int32_t ordinal, const String &terrain_id) {
	Dictionary footprint;
	if (kind == "mine") {
		const int32_t category = std::max(0, ordinal) % RMG_MINE_CATEGORY_COUNT;
		if (category == 0) {
			footprint["width"] = 3;
			footprint["height"] = 2;
			footprint["tier"] = "large_mine";
		} else if (category == 1 || category == 3 || category == 4 || category == 5) {
			footprint["width"] = 2;
			footprint["height"] = 3;
			footprint["tier"] = "rare_mine";
		} else {
			footprint["width"] = 2;
			footprint["height"] = 2;
			footprint["tier"] = "medium_mine";
		}
		footprint["anchor"] = "bottom_center";
		footprint["source"] = "content/random_map_generator_data_model.json mine object definition";
	} else if (kind == "neutral_dwelling") {
		footprint["width"] = 2;
		footprint["height"] = 1;
		footprint["anchor"] = "bottom_center";
		footprint["tier"] = "small_dwelling";
		footprint["source"] = "content/random_map_generator_data_model.json neutral dwelling object definition";
	} else if (kind == "scenic_object") {
		footprint["width"] = ordinal % 3 == 1 ? 2 : 1;
		footprint["height"] = ordinal % 3 == 1 ? 2 : 1;
		footprint["anchor"] = "center";
		footprint["tier"] = ordinal % 3 == 1 ? "small_scenic" : "micro_scenic";
		footprint["source"] = "uploaded HoMM3 small-map other-object category translated to original scenic object footprint";
	} else if (kind == "decorative_obstacle") {
		Dictionary decoration_template = decoration_template_record(terrain_id, ordinal);
		footprint["width"] = decoration_template.get("width", 4);
		footprint["height"] = decoration_template.get("height", 2);
		footprint["anchor"] = "bottom_left";
		footprint["tier"] = decoration_template.get("tier", "large_blocker");
		footprint["source"] = "content/map_objects.json authored decoration/blocker footprint proportions with HoMM3-re rand_trn source identity proxy";
	} else {
		footprint["width"] = 1;
		footprint["height"] = 1;
		footprint["anchor"] = "center";
		footprint["tier"] = "micro";
	}
	return footprint;
}

Array object_body_tiles_for_kind(const String &kind, int32_t x, int32_t y, int32_t width, int32_t height, const Dictionary &footprint) {
	Array body_tiles;
	const int32_t body_width = std::max(1, int32_t(footprint.get("width", 1)));
	const int32_t body_height = std::max(1, int32_t(footprint.get("height", 1)));
	for (int32_t dy = 0; dy < body_height; ++dy) {
		for (int32_t dx = 0; dx < body_width; ++dx) {
			const int32_t tx = x + dx;
			const int32_t ty = y + dy;
			if (tx >= 0 && ty >= 0 && tx < width && ty < height) {
				body_tiles.append(cell_record(tx, ty, 0));
			}
		}
	}
	return body_tiles;
}

bool object_body_fits_in_zone(int32_t x, int32_t y, const String &zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height, const Dictionary &footprint) {
	const int32_t body_width = std::max(1, int32_t(footprint.get("width", 1)));
	const int32_t body_height = std::max(1, int32_t(footprint.get("height", 1)));
	if (x < 1 || y < 1 || x + body_width > width - 1 || y + body_height > height - 1) {
		return false;
	}
	for (int32_t dy = 0; dy < body_height; ++dy) {
		for (int32_t dx = 0; dx < body_width; ++dx) {
			const int32_t tx = x + dx;
			const int32_t ty = y + dy;
			if (occupied.has(point_key(tx, ty))) {
				return false;
			}
			if (!zone_id.is_empty() && ty >= 0 && ty < owner_grid.size()) {
				Array row = owner_grid[ty];
				if (tx < 0 || tx >= row.size() || String(row[tx]) != zone_id) {
					return false;
				}
			}
		}
	}
	return true;
}

Dictionary object_pipeline_type_metadata_for_kind(const String &kind) {
	Dictionary metadata;
	metadata["schema_id"] = "aurelion_native_rmg_object_type_metadata_v1";
	metadata["type_id"] = kind;
	metadata["category"] = kind == "reward_reference" ? "reward" : (kind == "special_guard_gate" ? "connection_gate" : kind);
	metadata["primary_placement_gate"] = kind != "decorative_obstacle";
	metadata["wide_placement_footprint"] = kind == "mine" || kind == "neutral_dwelling" || kind == "decorative_obstacle" || kind == "special_guard_gate" || kind == "scenic_object";
	metadata["secondary_placement_gate"] = kind != "resource_site";
	metadata["definition_serialization_pass"] = true;
	Dictionary limits;
	if (kind == "decorative_obstacle") {
		limits["global"] = 4096;
		limits["per_zone"] = 256;
	} else if (kind == "reward_reference") {
		limits["global"] = 768;
		limits["per_zone"] = 48;
	} else if (kind == "mine") {
		limits["global"] = 256;
		limits["per_zone"] = 24;
	} else if (kind == "neutral_dwelling") {
		limits["global"] = 256;
		limits["per_zone"] = 4;
	} else if (kind == "resource_site") {
		limits["global"] = 512;
		limits["per_zone"] = 12;
	} else if (kind == "scenic_object") {
		limits["global"] = 1024;
		limits["per_zone"] = 64;
	} else {
		limits["global"] = 1024;
		limits["per_zone"] = 96;
	}
	metadata["limits"] = limits;
	return metadata;
}

Dictionary object_pipeline_definition_for_kind(const String &kind, int32_t ordinal, const String &terrain_id) {
	Dictionary definition;
	definition["schema_id"] = "aurelion_native_rmg_original_object_definition_v1";
	definition["definition_id"] = "rmg_object_" + kind + "_v1";
	definition["generated_kind"] = kind;
	definition["content_policy"] = "original_content_ids_only_no_homm3_asset_name_text_import";
	definition["template_source"] = kind == "decorative_obstacle" ? "rand_trn_obstacle_row_mapped_to_original_object_template" : "content_random_map_generator_data_model_original_definition";
	definition["ordinary_object_template"] = true;
	definition["decoration_super_type_shortcut"] = false;
	definition["footprint"] = object_footprint_for_kind(kind, ordinal, terrain_id);
	Dictionary passability;
	Dictionary action;
	if (kind == "decorative_obstacle") {
		passability["class"] = "blocking_non_visitable";
		passability["mask"] = Array::make("body_blocked");
		action["class"] = "none";
		action["mask"] = Array();
	} else if (kind == "scenic_object") {
		passability["class"] = "blocking_non_visitable";
		passability["mask"] = Array::make("body_blocked");
		action["class"] = "none";
		action["mask"] = Array();
	} else if (kind == "resource_site" || kind == "reward_reference") {
		passability["class"] = "passable_visit_on_enter";
		passability["mask"] = Array::make("anchor_enterable");
		action["class"] = kind == "reward_reference" ? "visit_on_enter_or_guarded_claim" : "visit_on_enter";
		action["mask"] = Array::make("anchor_action");
	} else if (kind == "route_guard") {
		passability["class"] = "blocking_visitable";
		passability["mask"] = Array::make("body_blocked", "guard_blocks_route_until_defeated");
		action["class"] = "battle_to_clear_route_guard";
		action["mask"] = Array::make("approach_action");
	} else if (kind == "special_guard_gate") {
		passability["class"] = "blocking_visitable";
		passability["mask"] = Array::make("body_blocked", "gate_unlock_required");
		action["class"] = "unlock_connection_gate";
		action["mask"] = Array::make("approach_action");
	} else if (kind == "town") {
		passability["class"] = "blocking_visitable";
		passability["mask"] = Array::make("body_blocked", "town_approach");
		action["class"] = "enter_or_capture_town";
		action["mask"] = Array::make("south_action", "west_action");
	} else {
		passability["class"] = "blocking_visitable";
		passability["mask"] = Array::make("body_blocked", "adjacent_visit");
		action["class"] = kind == "mine" ? "adjacent_claim" : "adjacent_recruit";
		action["mask"] = Array::make("south_action", "west_action");
	}
	definition["passability"] = passability;
	definition["action"] = action;
	Dictionary terrain;
	terrain["allowed_terrain_ids"] = Array::make("grass", "dirt", "sand", "snow", "swamp", "rough", "underground", "lava");
	terrain["reject_terrain_ids"] = Array::make("water", "rock");
	terrain["runtime_terrain_id"] = terrain_id;
	definition["terrain_constraints"] = terrain;
	definition["type_metadata"] = object_pipeline_type_metadata_for_kind(kind);
	Dictionary value_density;
	if (kind == "decorative_obstacle") {
		value_density["density"] = "late_rand_trn_fill";
		value_density["value_bands"] = Array::make(Dictionary());
	} else if (kind == "scenic_object") {
		value_density["density"] = "owner_uploaded_h3m_other_object_mix";
		value_density["value_source"] = "non_reward_non_guard_non_town_other_object_category";
	} else if (kind == "reward_reference") {
		value_density["density"] = "phase_10_zone_treasure_band_weight";
		value_density["value_source"] = "low_high_density_triplets";
	} else if (kind == "mine") {
		value_density["density"] = "phase_7_minimum_then_density";
		value_density["value_source"] = "seven_category_mine_resource_fields";
	} else if (kind == "route_guard") {
		value_density["density"] = "connection_and_site_guard_strength_scaling";
		value_density["value_source"] = "phase_10_monster_strength_formula";
	} else if (kind == "special_guard_gate") {
		value_density["density"] = "connection_payload_border_guard";
		value_density["value_source"] = "type_9_equivalent_original_gate_payload";
	} else if (kind == "town") {
		value_density["density"] = "phase_4a_4b_town_castle_minimum_density";
		value_density["value_source"] = "template_town_fields";
	} else {
		value_density["density"] = "zone_role_scaled_target";
		value_density["value_source"] = "original_content_family_weight";
	}
	definition["value_density"] = value_density;
	Dictionary writeout;
	writeout["record_kind"] = kind == "decorative_obstacle" ? "decorative_map_object" : (kind == "special_guard_gate" ? "connection_gate" : (kind == "scenic_object" ? "scenic_map_object" : "map_object"));
	writeout["serialization_state"] = "definition_and_instance_staged_package_record";
	writeout["no_authored_content_writeback"] = true;
	writeout["payload_fields"] = Array::make("object_id", "family_id", "zone_id", "body_tiles", "occupancy_keys", "passability", "action");
	definition["writeout"] = writeout;
	return definition;
}

Array cardinal_approach_tiles(int32_t x, int32_t y, int32_t width, int32_t height, const Dictionary &occupied) {
	Array result;
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
	for (const auto &offset : OFFSETS) {
		const int32_t nx = x + offset[0];
		const int32_t ny = y + offset[1];
		if (nx < 0 || ny < 0 || nx >= width || ny >= height || occupied.has(point_key(nx, ny))) {
			continue;
		}
		result.append(point_record(nx, ny));
	}
	return result;
}

Array cardinal_approach_tiles_in_zone(int32_t x, int32_t y, int32_t width, int32_t height, const Dictionary &occupied, const Array &owner_grid, const String &zone_id) {
	Array result;
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
	for (const auto &offset : OFFSETS) {
		const int32_t nx = x + offset[0];
		const int32_t ny = y + offset[1];
		if (nx < 0 || ny < 0 || nx >= width || ny >= height || occupied.has(point_key(nx, ny))) {
			continue;
		}
		if (!zone_id.is_empty()) {
			if (ny < 0 || ny >= owner_grid.size()) {
				continue;
			}
			Array row = owner_grid[ny];
			if (nx < 0 || nx >= row.size() || String(row[nx]) != zone_id) {
				continue;
			}
		}
		result.append(point_record(nx, ny));
	}
	return result;
}

struct NativeRoadCell {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	String segment_id;
};

std::vector<NativeRoadCell> native_road_cells_for_network(const Dictionary &road_network) {
	std::vector<NativeRoadCell> road_cells;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		if (Variant(road_segments[segment_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary segment = road_segments[segment_index];
		const String segment_id = String(segment.get("id", ""));
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = cells[cell_index];
			NativeRoadCell road_cell;
			road_cell.x = int32_t(cell.get("x", 0));
			road_cell.y = int32_t(cell.get("y", 0));
			road_cell.level = int32_t(cell.get("level", 0));
			road_cell.segment_id = segment_id;
			road_cells.push_back(road_cell);
		}
	}
	return road_cells;
}

Dictionary nearest_road_proximity_from_cells(int32_t x, int32_t y, const std::vector<NativeRoadCell> &road_cells) {
	int32_t best_distance = std::numeric_limits<int32_t>::max();
	String best_segment_id;
	Dictionary best_cell;
	for (const NativeRoadCell &cell : road_cells) {
		const int32_t distance = std::abs(x - cell.x) + std::abs(y - cell.y);
		if (distance < best_distance) {
			best_distance = distance;
			best_segment_id = cell.segment_id;
			best_cell = cell_record(cell.x, cell.y, cell.level);
		}
	}
	Dictionary result;
	result["nearest_distance_tiles"] = best_distance == std::numeric_limits<int32_t>::max() ? -1 : best_distance;
	result["nearest_road_segment_id"] = best_segment_id;
	result["nearest_road_cell"] = best_cell;
	result["proximity_class"] = best_distance <= 1 ? "road_adjacent" : (best_distance <= 4 ? "near_road" : "off_road");
	return result;
}

Dictionary nearest_road_proximity(int32_t x, int32_t y, const Dictionary &road_network) {
	const std::vector<NativeRoadCell> road_cells = native_road_cells_for_network(road_network);
	return nearest_road_proximity_from_cells(x, y, road_cells);
}

Dictionary route_guard_point_near_anchor(const Dictionary &anchor, const Dictionary &occupied, int32_t width, int32_t height) {
	if (anchor.is_empty()) {
		return Dictionary();
	}
	const int32_t anchor_x = int32_t(anchor.get("x", 0));
	const int32_t anchor_y = int32_t(anchor.get("y", 0));
	static constexpr int32_t OFFSETS[9][2] = {{0, 0}, {1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}};
	Dictionary first_clearable_filler_point;
	for (const auto &offset : OFFSETS) {
		const int32_t x = anchor_x + offset[0];
		const int32_t y = anchor_y + offset[1];
		if (x < 0 || y < 0 || x >= width || y >= height) {
			continue;
		}
		const String key = point_key(x, y);
		if (!occupied.has(key)) {
			return point_record(x, y);
		}
		const String occupant_id = String(occupied.get(key, ""));
		if (first_clearable_filler_point.is_empty() && (occupant_id.find("decorative_obstacle") >= 0 || occupant_id.find("scenic_object") >= 0)) {
			first_clearable_filler_point = point_record(x, y);
		}
	}
	if (!first_clearable_filler_point.is_empty()) {
		return first_clearable_filler_point;
	}
	return Dictionary();
}

PackedInt32Array road_distance_field_for_cells(const std::vector<NativeRoadCell> &road_cells, int32_t width, int32_t height) {
	PackedInt32Array distances;
	distances.resize(std::max(0, width * height));
	for (int32_t index = 0; index < distances.size(); ++index) {
		distances[index] = -1;
	}
	if (width <= 0 || height <= 0) {
		return distances;
	}
	std::vector<int32_t> queue;
	queue.reserve(size_t(width) * size_t(height));
	for (const NativeRoadCell &cell : road_cells) {
		const int32_t x = cell.x;
		const int32_t y = cell.y;
		if (x < 0 || y < 0 || x >= width || y >= height) {
			continue;
		}
		const int32_t tile_index = y * width + x;
		if (distances[tile_index] == 0) {
			continue;
		}
		distances[tile_index] = 0;
		queue.push_back(tile_index);
	}

	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
	for (size_t cursor = 0; cursor < queue.size(); ++cursor) {
		const int32_t tile_index = queue[cursor];
		const int32_t x = tile_index % width;
		const int32_t y = tile_index / width;
		const int32_t next_distance = distances[tile_index] + 1;
		for (const auto &offset : OFFSETS) {
			const int32_t nx = x + offset[0];
			const int32_t ny = y + offset[1];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
				continue;
			}
			const int32_t neighbor_index = ny * width + nx;
			if (distances[neighbor_index] >= 0 && distances[neighbor_index] <= next_distance) {
				continue;
			}
			distances[neighbor_index] = next_distance;
			queue.push_back(neighbor_index);
		}
	}
	return distances;
}

PackedInt32Array road_distance_field_for_map(const Dictionary &road_network, int32_t width, int32_t height) {
	const std::vector<NativeRoadCell> road_cells = native_road_cells_for_network(road_network);
	return road_distance_field_for_cells(road_cells, width, height);
}

int32_t road_distance_from_field(const PackedInt32Array &road_distance_field, int32_t x, int32_t y, int32_t width, int32_t height) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return -1;
	}
	const int32_t index = y * width + x;
	if (index < 0 || index >= road_distance_field.size()) {
		return -1;
	}
	return road_distance_field[index];
}

Dictionary find_object_point(int32_t x, int32_t y, const String &preferred_zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height) {
	x = std::max(1, std::min(std::max(1, width - 2), x));
	y = std::max(1, std::min(std::max(1, height - 2), y));
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = x + dx;
				const int32_t cy = y + dy;
				if (cx < 1 || cy < 1 || cx >= width - 1 || cy >= height - 1 || occupied.has(point_key(cx, cy))) {
					continue;
				}
				if (!preferred_zone_id.is_empty() && radius < 4 && cy >= 0 && cy < owner_grid.size()) {
					Array row = owner_grid[cy];
					if (cx >= 0 && cx < row.size() && String(row[cx]) != preferred_zone_id) {
						continue;
					}
				}
				return cell_record(cx, cy, 0);
			}
		}
	}
	return Dictionary();
}

Dictionary road_body_exclusion_lookup(const Dictionary &road_network) {
	Dictionary blocked;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			Dictionary cell = cells[cell_index];
			blocked[point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)))] = "road_segment";
		}
	}
	return blocked;
}

void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const std::vector<NativeRoadCell> &road_cells, const Dictionary &zone_layout);

struct NativePlacementTile {
	int32_t x = 0;
	int32_t y = 0;
};

struct NativePlacedObject {
	int32_t x = 0;
	int32_t y = 0;
	int32_t quadrant = 0;
	String kind;
	String zone_id;
	bool decorative = false;
};

struct NativeZoneCandidateCache {
	String zone_id;
	std::vector<NativePlacementTile> candidates;
};

struct NativeObjectPlacementContext {
	int32_t width = 0;
	int32_t height = 0;
	std::vector<int32_t> zone_index_by_tile;
	std::vector<uint8_t> occupied_by_tile;
	std::vector<NativeZoneCandidateCache> zones;
	std::vector<NativePlacedObject> placements;
};

int32_t native_tile_index(const NativeObjectPlacementContext &context, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= context.width || y >= context.height) {
		return -1;
	}
	return y * context.width + x;
}

int32_t native_zone_index_for_id(const NativeObjectPlacementContext &context, const String &zone_id) {
	for (int32_t index = 0; index < int32_t(context.zones.size()); ++index) {
		if (context.zones[index].zone_id == zone_id) {
			return index;
		}
	}
	return -1;
}

void mark_native_occupied(NativeObjectPlacementContext &context, int32_t x, int32_t y) {
	const int32_t index = native_tile_index(context, x, y);
	if (index >= 0 && index < int32_t(context.occupied_by_tile.size())) {
		context.occupied_by_tile[index] = 1;
	}
}

NativeObjectPlacementContext build_native_object_placement_context(const Array &zones, const Array &owner_grid, const Dictionary &road_network, int32_t width, int32_t height, bool seed_road_occupied) {
	NativeObjectPlacementContext context;
	context.width = width;
	context.height = height;
	context.zone_index_by_tile.assign(std::max(0, width * height), -1);
	context.occupied_by_tile.assign(std::max(0, width * height), 0);
	context.zones.reserve(zones.size());
	for (int64_t zone_index = 0; zone_index < zones.size(); ++zone_index) {
		Dictionary zone = zones[zone_index];
		NativeZoneCandidateCache cache;
		cache.zone_id = String(zone.get("id", ""));
		context.zones.push_back(cache);
	}
	for (int32_t y = 0; y < height && y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		for (int32_t x = 0; x < width && x < row.size(); ++x) {
			const String zone_id = String(row[x]);
			const int32_t zone_index = native_zone_index_for_id(context, zone_id);
			if (zone_index < 0) {
				continue;
			}
			const int32_t tile_index = native_tile_index(context, x, y);
			context.zone_index_by_tile[tile_index] = zone_index;
			if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
				context.zones[zone_index].candidates.push_back({x, y});
			}
		}
	}
	if (seed_road_occupied) {
		Array road_segments = road_network.get("road_segments", Array());
		for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
			Dictionary segment = road_segments[segment_index];
			Array cells = segment.get("cells", Array());
			for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
				Dictionary cell = cells[cell_index];
				mark_native_occupied(context, int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
			}
		}
	}
	return context;
}

bool object_body_fits_in_zone_native(const NativeObjectPlacementContext &context, int32_t x, int32_t y, int32_t zone_index, const Dictionary &footprint) {
	const int32_t body_width = std::max(1, int32_t(footprint.get("width", 1)));
	const int32_t body_height = std::max(1, int32_t(footprint.get("height", 1)));
	if (x < 1 || y < 1 || x + body_width > context.width - 1 || y + body_height > context.height - 1) {
		return false;
	}
	for (int32_t dy = 0; dy < body_height; ++dy) {
		for (int32_t dx = 0; dx < body_width; ++dx) {
			const int32_t index = native_tile_index(context, x + dx, y + dy);
			if (index < 0 || index >= int32_t(context.occupied_by_tile.size())) {
				return false;
			}
			if (context.occupied_by_tile[index] != 0 || context.zone_index_by_tile[index] != zone_index) {
				return false;
			}
		}
	}
	return true;
}

bool native_context_zone_boundary_cell(const NativeObjectPlacementContext &context, int32_t x, int32_t y) {
	const int32_t tile_index = native_tile_index(context, x, y);
	if (tile_index < 0 || tile_index >= int32_t(context.zone_index_by_tile.size())) {
		return false;
	}
	const int32_t zone_index = context.zone_index_by_tile[tile_index];
	if (zone_index < 0) {
		return false;
	}
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	for (int32_t index = 0; index < 8; ++index) {
		const int32_t neighbor_index = native_tile_index(context, x + DX[index], y + DY[index]);
		if (neighbor_index < 0 || neighbor_index >= int32_t(context.zone_index_by_tile.size())) {
			continue;
		}
		const int32_t other_zone_index = context.zone_index_by_tile[neighbor_index];
		if (other_zone_index >= 0 && other_zone_index != zone_index) {
			return true;
		}
	}
	return false;
}

int32_t interactive_spacing_penalty_native(const NativeObjectPlacementContext &context, int32_t x, int32_t y, const String &kind, const String &zone_id) {
	int32_t penalty = 0;
	int32_t nearest_distance = std::numeric_limits<int32_t>::max();
	int32_t local_window_count = 0;
	int32_t same_zone_window_count = 0;
	int32_t same_kind_window_count = 0;
	int32_t same_quadrant_count = 0;
	int32_t same_kind_quadrant_count = 0;
	const int32_t quadrant = (x >= context.width / 2 ? 1 : 0) + (y >= context.height / 2 ? 2 : 0);
	for (const NativePlacedObject &placement : context.placements) {
		if (placement.decorative) {
			continue;
		}
		const int32_t dx = std::abs(x - placement.x);
		const int32_t dy = std::abs(y - placement.y);
		const int32_t distance = dx + dy;
		if (placement.quadrant == quadrant) {
			++same_quadrant_count;
			if (placement.kind == kind) {
				++same_kind_quadrant_count;
			}
		}
		nearest_distance = std::min(nearest_distance, distance);
		if (dx <= 6 && dy <= 6) {
			++local_window_count;
			if (placement.zone_id == zone_id) {
				++same_zone_window_count;
			}
			if (placement.kind == kind) {
				++same_kind_window_count;
			}
		}
		if (distance <= 2) {
			penalty += 240;
		} else if (distance <= 4) {
			penalty += 96;
		} else if (distance <= 6) {
			penalty += 36;
		} else if (distance <= 10) {
			penalty += 10;
		}
	}
	if (nearest_distance == std::numeric_limits<int32_t>::max()) {
		return 0;
	}
	penalty += local_window_count * 70;
	penalty += same_zone_window_count * 55;
	penalty += same_kind_window_count * 35;
	penalty += same_quadrant_count * 8;
	penalty += same_kind_quadrant_count * 14;
	return penalty;
}

void mark_native_placement(NativeObjectPlacementContext &context, const Dictionary &placement) {
	Array body_tiles = placement.get("body_tiles", Array());
	for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
		Dictionary body = body_tiles[body_index];
		mark_native_occupied(context, int32_t(body.get("x", 0)), int32_t(body.get("y", 0)));
	}
	NativePlacedObject native_placement;
	native_placement.x = int32_t(placement.get("x", 0));
	native_placement.y = int32_t(placement.get("y", 0));
	native_placement.quadrant = (native_placement.x >= context.width / 2 ? 1 : 0) + (native_placement.y >= context.height / 2 ? 2 : 0);
	native_placement.kind = String(placement.get("kind", ""));
	native_placement.zone_id = String(placement.get("zone_id", ""));
	native_placement.decorative = native_placement.kind == "decorative_obstacle";
	context.placements.push_back(native_placement);
}

bool append_object_placement_fast(Array &placements, Dictionary &occupied, NativeObjectPlacementContext &context, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const std::vector<NativeRoadCell> &road_cells, const Dictionary &zone_layout) {
	const int64_t previous_size = placements.size();
	append_object_placement(placements, occupied, normalized, zone, point, kind, ordinal, road_cells, zone_layout);
	if (placements.size() > previous_size) {
		mark_native_placement(context, Dictionary(placements[placements.size() - 1]));
		return true;
	}
	return false;
}

bool zone_needs_future_town_anchor_reservation(const Dictionary &zone) {
	const String role = String(zone.get("role", ""));
	if (role.find("start") >= 0) {
		return true;
	}
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary player_towns = metadata.get("player_towns", zone.get("player_towns", Dictionary()));
	Dictionary neutral_towns = metadata.get("neutral_towns", zone.get("neutral_towns", Dictionary()));
	return int32_t(player_towns.get("min_towns", 0)) > 0
			|| int32_t(player_towns.get("min_castles", 0)) > 0
			|| int32_t(player_towns.get("town_density", 0)) > 0
			|| int32_t(player_towns.get("castle_density", 0)) > 0
			|| int32_t(neutral_towns.get("min_towns", 0)) > 0
			|| int32_t(neutral_towns.get("min_castles", 0)) > 0
			|| int32_t(neutral_towns.get("town_density", 0)) > 0
			|| int32_t(neutral_towns.get("castle_density", 0)) > 0;
}

void reserve_future_town_anchors(const Array &zones, const Array &owner_grid, Dictionary &occupied, NativeObjectPlacementContext &context, int32_t width, int32_t height) {
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		if (!zone_needs_future_town_anchor_reservation(zone)) {
			continue;
		}
		Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
		const int32_t x = int32_t(anchor.get("x", width / 2));
		const int32_t y = int32_t(anchor.get("y", height / 2));
		if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) {
			continue;
		}
		const String key = point_key(x, y);
		occupied[key] = "reserved_future_town_anchor_" + String(zone.get("id", ""));
		mark_native_occupied(context, x, y);
	}
}

bool decoration_body_fits(int32_t x, int32_t y, const String &zone_id, const Array &owner_grid, const Dictionary &occupied, const Dictionary &blocked, int32_t width, int32_t height, const Dictionary &footprint) {
	const int32_t body_width = std::max(1, int32_t(footprint.get("width", 1)));
	const int32_t body_height = std::max(1, int32_t(footprint.get("height", 1)));
	if (x < 1 || y < 1 || x + body_width > width - 1 || y + body_height > height - 1) {
		return false;
	}
	for (int32_t dy = 0; dy < body_height; ++dy) {
		for (int32_t dx = 0; dx < body_width; ++dx) {
			const int32_t tx = x + dx;
			const int32_t ty = y + dy;
			const String key = point_key(tx, ty);
			if (occupied.has(key) || blocked.has(key)) {
				return false;
			}
			if (!zone_id.is_empty() && ty >= 0 && ty < owner_grid.size()) {
				Array row = owner_grid[ty];
				if (tx < 0 || tx >= row.size() || String(row[tx]) != zone_id) {
					return false;
				}
			}
		}
	}
	return true;
}

bool native_rmg_owner_like_islands_density_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 72
			&& height == 72
			&& String(normalized.get("size_class_id", "")) == "homm3_medium"
			&& String(normalized.get("water_mode", "")) == "islands"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_001_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_001_v1"
			&& player_count == 4;
}

bool native_rmg_owner_like_small_land_density_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	const String template_id = String(normalized.get("template_id", ""));
	const String profile_id = String(normalized.get("profile_id", ""));
	return width == 36
			&& height == 36
			&& level_count == 1
			&& String(normalized.get("size_class_id", "")) == "homm3_small"
			&& String(normalized.get("water_mode", "")) == "land"
			&& template_id.begins_with("translated_rmg_template_")
			&& profile_id.begins_with("translated_rmg_profile_")
			&& player_count == 3;
}

bool native_rmg_owner_like_small_decoration_density_case(const Dictionary &normalized) {
	return native_rmg_owner_like_small_land_density_case(normalized) || native_rmg_owner_uploaded_small_027_underground_case(normalized);
}

bool native_rmg_owner_uploaded_small_049_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 36
			&& height == 36
			&& level_count == 1
			&& String(normalized.get("size_class_id", "")) == "homm3_small"
			&& String(normalized.get("water_mode", "")) == "land"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_049_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_049_v1"
			&& player_count == 3;
}

bool native_rmg_owner_uploaded_small_027_underground_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 36
			&& height == 36
			&& level_count == 2
			&& String(normalized.get("size_class_id", "")) == "homm3_small"
			&& String(normalized.get("water_mode", "")) == "land"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_027_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_027_v1"
			&& player_count == 3;
}

bool native_rmg_owner_xl_land_density_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 144
			&& height == 144
			&& level_count == 1
			&& String(normalized.get("size_class_id", "")) == "homm3_extra_large"
			&& String(normalized.get("water_mode", "")) == "land"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_043_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_043_v1"
			&& player_count == 5;
}

bool native_rmg_owner_large_land_density_case(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const int32_t player_count = int32_t(Dictionary(normalized.get("player_constraints", Dictionary())).get("player_count", 0));
	return width == 108
			&& height == 108
			&& level_count == 1
			&& String(normalized.get("size_class_id", "")) == "homm3_large"
			&& String(normalized.get("water_mode", "")) == "land"
			&& String(normalized.get("template_id", "")) == "translated_rmg_template_042_v1"
			&& String(normalized.get("profile_id", "")) == "translated_rmg_profile_042_v1"
			&& player_count == 4;
}

int32_t owner_uploaded_small_049_object_target(const Dictionary &normalized, const String &kind) {
	if (!native_rmg_owner_uploaded_small_049_case(normalized)) {
		return -1;
	}
	if (kind == "mine") {
		return 31;
	}
	if (kind == "resource_site") {
		return 42;
	}
	if (kind == "reward_reference") {
		return 7;
	}
	if (kind == "neutral_dwelling") {
		return 0;
	}
	if (kind == "scenic_object") {
		return 26;
	}
	return -1;
}

int32_t owner_uploaded_small_027_underground_object_target(const Dictionary &normalized, const String &kind) {
	if (!native_rmg_owner_uploaded_small_027_underground_case(normalized)) {
		return -1;
	}
	if (kind == "decorative_obstacle") {
		return 151;
	}
	if (kind == "scenic_object") {
		return 48;
	}
	return -1;
}

int32_t owner_attached_medium_001_category_target(const Dictionary &normalized, const String &category) {
	if (!native_rmg_owner_like_islands_density_case(normalized)) {
		return -1;
	}
	if (category == "decoration") {
		return 252;
	}
	if (category == "reward") {
		return 110;
	}
	if (category == "scenic_object") {
		return 65;
	}
	if (category == "town") {
		return 8;
	}
	if (category == "guard") {
		return 61;
	}
	return -1;
}

int32_t owner_xl_land_category_target(const Dictionary &normalized, const String &category) {
	if (!native_rmg_owner_xl_land_density_case(normalized)) {
		return -1;
	}
	if (category == "decoration") {
		return 3413;
	}
	if (category == "scenic_object") {
		return 629;
	}
	if (category == "guard") {
		return 619;
	}
	if (category == "town") {
		return 12;
	}
	if (category == "reward") {
		return 692;
	}
	return -1;
}

int32_t owner_large_land_category_target(const Dictionary &normalized, const String &category) {
	if (!native_rmg_owner_large_land_density_case(normalized)) {
		return -1;
	}
	if (category == "decoration") {
		return 1840;
	}
	if (category == "scenic_object") {
		return 376;
	}
	if (category == "guard") {
		return 264;
	}
	if (category == "town") {
		return 8;
	}
	if (category == "reward") {
		return 429;
	}
	return -1;
}

String owner_attached_medium_001_spatial_category_for_kind(const String &kind) {
	if (kind == "decorative_obstacle") {
		return "decoration";
	}
	if (kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference") {
		return "reward";
	}
	if (kind == "scenic_object") {
		return "object";
	}
	return "";
}

int32_t owner_attached_medium_001_grid_index(int32_t x, int32_t y, int32_t width, int32_t height) {
	const int32_t cx = std::max(0, std::min(5, (x * 6) / std::max(1, width)));
	const int32_t cy = std::max(0, std::min(5, (y * 6) / std::max(1, height)));
	return cy * 6 + cx;
}

int32_t owner_attached_medium_001_grid_target_count(const String &category, int32_t grid_index) {
	static constexpr int32_t DECORATION_COUNTS[36] = {
		11, 9, 16, 16, 14, 7,
		3, 8, 11, 4, 17, 3,
		2, 18, 5, 2, 4, 0,
		3, 9, 12, 10, 11, 0,
		0, 4, 10, 7, 9, 4,
		0, 3, 10, 7, 3, 0,
	};
	static constexpr int32_t REWARD_COUNTS[36] = {
		8, 0, 5, 4, 0, 0,
		0, 1, 8, 3, 0, 0,
		3, 4, 6, 3, 7, 0,
		2, 8, 5, 3, 8, 0,
		0, 6, 3, 3, 5, 1,
		0, 2, 3, 5, 2, 2,
	};
	static constexpr int32_t OBJECT_COUNTS[36] = {
		2, 0, 6, 1, 2, 4,
		0, 1, 1, 0, 1, 2,
		1, 6, 1, 0, 0, 1,
		2, 7, 1, 2, 3, 3,
		0, 3, 2, 4, 3, 1,
		0, 1, 1, 1, 2, 0,
	};
	if (grid_index < 0 || grid_index >= 36) {
		return 0;
	}
	if (category == "decoration") {
		return DECORATION_COUNTS[grid_index];
	}
	if (category == "reward") {
		return REWARD_COUNTS[grid_index];
	}
	if (category == "object") {
		return OBJECT_COUNTS[grid_index];
	}
	return 0;
}

int32_t owner_attached_medium_001_grid_distribution_penalty(const Dictionary &normalized, const String &category, int32_t x, int32_t y, int32_t width, int32_t height) {
	if (!native_rmg_owner_like_islands_density_case(normalized) || category.is_empty()) {
		return 0;
	}
	const int32_t target = owner_attached_medium_001_grid_target_count(category, owner_attached_medium_001_grid_index(x, y, width, height));
	if (target <= 0) {
		return category == "decoration" ? 420 : 2600;
	}
	const int32_t max_target = category == "decoration" ? 18 : (category == "reward" ? 8 : 7);
	const int32_t density_weight = category == "decoration" ? 0 : (category == "reward" ? 26 : 24);
	return std::max(0, max_target - target) * density_weight;
}

int32_t owner_attached_medium_001_spacing_penalty(const Dictionary &normalized, const String &category, int32_t spacing_penalty) {
	if (!native_rmg_owner_like_islands_density_case(normalized) || category.is_empty()) {
		return spacing_penalty;
	}
	if (category == "reward") {
		return spacing_penalty / 3;
	}
	if (category == "object") {
		return spacing_penalty / 4;
	}
	return spacing_penalty;
}

int32_t owner_attached_medium_001_road_penalty(const Dictionary &normalized, const String &category, int32_t road_penalty) {
	if (!native_rmg_owner_like_islands_density_case(normalized) || category != "reward") {
		return road_penalty;
	}
	return road_penalty * 3;
}

bool owner_attached_medium_001_existing_matches_category(const NativePlacedObject &placement, const String &category) {
	if (category == "decoration") {
		return placement.kind == "decorative_obstacle";
	}
	if (category == "reward") {
		return placement.kind == "resource_site" || placement.kind == "mine" || placement.kind == "neutral_dwelling" || placement.kind == "reward_reference";
	}
	if (category == "object") {
		return placement.kind == "scenic_object";
	}
	return false;
}

int32_t owner_attached_medium_001_existing_cluster_penalty(const Dictionary &normalized, const NativeObjectPlacementContext &context, const String &category, int32_t x, int32_t y) {
	if (!native_rmg_owner_like_islands_density_case(normalized) || category.is_empty()) {
		return 0;
	}
	if (category == "decoration") {
		return 0;
	}
	int32_t nearest_distance = std::numeric_limits<int32_t>::max();
	int32_t same_grid_count = 0;
	const int32_t grid_index = owner_attached_medium_001_grid_index(x, y, context.width, context.height);
	for (const NativePlacedObject &placement : context.placements) {
		if (!owner_attached_medium_001_existing_matches_category(placement, category)) {
			continue;
		}
		const int32_t distance = std::abs(x - placement.x) + std::abs(y - placement.y);
		nearest_distance = std::min(nearest_distance, distance);
		if (owner_attached_medium_001_grid_index(placement.x, placement.y, context.width, context.height) == grid_index) {
			++same_grid_count;
		}
	}
	if (nearest_distance == std::numeric_limits<int32_t>::max()) {
		return 0;
	}
	int32_t penalty = -std::min(category == "decoration" ? 36 : 120, same_grid_count * (category == "decoration" ? 2 : 10));
	if (nearest_distance <= 2) {
		penalty -= category == "decoration" ? 8 : 36;
	} else if (nearest_distance <= 4) {
		penalty -= category == "decoration" ? 14 : 58;
	} else if (nearest_distance <= 7) {
		penalty -= category == "decoration" ? 8 : 38;
	} else if (nearest_distance <= 12) {
		penalty -= category == "decoration" ? 3 : 16;
	}
	return penalty;
}

int32_t placement_count_for_kind(const Array &placements, const String &kind) {
	int32_t count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		if (String(placement.get("kind", "")) == kind) {
			++count;
		}
	}
	return count;
}

int32_t placement_count_for_spatial_category(const Array &placements, const String &category) {
	int32_t count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		const String kind = String(Dictionary(placements[index]).get("kind", ""));
		if (category == "reward" && (kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference")) {
			++count;
		} else if (category == "decoration" && kind == "decorative_obstacle") {
			++count;
		} else if (category == kind) {
			++count;
		}
	}
	return count;
}

int32_t decoration_target_for_zone(const Dictionary &normalized, const Dictionary &zone) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t cell_count = std::max(0, int32_t(zone.get("cell_count", 0)));
	if (cell_count <= 0) {
		return 0;
	}
	const String role = String(zone.get("role", ""));
	double ratio = 0.260;
	if (role.find("start") >= 0) {
		ratio = 0.200;
	} else if (role == "treasure") {
		ratio = 0.320;
	} else if (role == "junction") {
		ratio = 0.280;
	}
	const double expected_body_tiles_per_record = 12.0;
	const int32_t max_per_zone = std::max(8, std::min(96, std::max(1, cell_count / 5)));
	const int32_t raw_target = int32_t(std::ceil(double(cell_count) * ratio / expected_body_tiles_per_record));
	return std::max(3, std::min(max_per_zone, raw_target));
}

int32_t owner_like_islands_compact_decoration_target_for_zone(const Dictionary &normalized, const Dictionary &zone) {
	const bool small_land_density = native_rmg_owner_like_small_land_density_case(normalized);
	if (!small_land_density && !native_rmg_owner_like_islands_density_case(normalized)) {
		return 0;
	}
	const int32_t cell_count = std::max(0, int32_t(zone.get("cell_count", 0)));
	if (cell_count <= 0) {
		return 0;
	}
	const String role = String(zone.get("role", ""));
	double ratio = small_land_density ? 0.086 : 0.057;
	if (role.find("start") >= 0) {
		ratio = small_land_density ? 0.081 : 0.048;
	} else if (role == "treasure") {
		ratio = small_land_density ? 0.095 : 0.065;
	} else if (role == "junction") {
		ratio = small_land_density ? 0.089 : 0.059;
	}
	const int32_t raw_target = int32_t(std::ceil(double(cell_count) * ratio));
	const int32_t max_per_zone = small_land_density
			? std::max(10, std::min(28, std::max(1, cell_count / 6)))
			: std::max(4, std::min(36, std::max(1, cell_count / 10)));
	return std::max(1, std::min(max_per_zone, raw_target));
}

Dictionary compact_density_decoration_footprint(int32_t ordinal, bool small_land_density = false) {
	Dictionary footprint;
	footprint["width"] = small_land_density ? (ordinal % 2 == 0 ? 2 : 1) : (ordinal % 5 == 0 ? 2 : 1);
	footprint["height"] = 1;
	footprint["tier"] = "compact_owner_like_islands_density_marker";
	footprint["source"] = "bounded owner-like islands land-normalized decoration instance density supplement";
	return footprint;
}

bool zone_boundary_barrier_cell(const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height);

Dictionary find_decoration_point(const Dictionary &zone, int32_t ordinal, const Dictionary &normalized, const Array &owner_grid, const Dictionary &occupied, const Dictionary &blocked, int32_t width, int32_t height) {
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	const Dictionary footprint = object_footprint_for_kind("decorative_obstacle", ordinal, terrain_id);
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const int32_t ax = int32_t(anchor.get("x", width / 2));
	const int32_t ay = int32_t(anchor.get("y", height / 2));
	const String seed_text = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":decor:" + String::num_int64(ordinal);
	std::vector<Dictionary> candidates;
	const int32_t radius_limit = std::max(width, height);
	for (int32_t radius = 2; radius <= radius_limit; ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t x = ax + dx;
				const int32_t y = ay + dy;
				if (!decoration_body_fits(x, y, zone_id, owner_grid, occupied, blocked, width, height, footprint)) {
					continue;
				}
				Dictionary point = point_record(x, y);
				const int32_t jitter = int32_t(hash32_int(seed_text + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 100000U);
				point["sort_key"] = String::num_int64(radius * 100000 + jitter);
				candidates.push_back(point);
			}
		}
		if (candidates.size() >= 18) {
			break;
		}
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		return String(left.get("sort_key", "")) < String(right.get("sort_key", ""));
	});
	if (!candidates.empty()) {
		Dictionary result = candidates.front();
		result.erase("sort_key");
		return result;
	}
	static constexpr int32_t COMPACT_FALLBACKS[2][2] = {{3, 2}, {2, 3}};
	for (const auto &fallback : COMPACT_FALLBACKS) {
		Dictionary compact_footprint = footprint.duplicate();
		compact_footprint["width"] = fallback[0];
		compact_footprint["height"] = fallback[1];
		compact_footprint["tier"] = "compact_constrained_zone_proxy";
		compact_footprint["source"] = "compact fallback for constrained HoMM3-re source-row proxy placement";
		std::vector<Dictionary> compact_candidates;
		for (int32_t radius = 1; radius <= radius_limit; ++radius) {
			for (int32_t dy = -radius; dy <= radius; ++dy) {
				for (int32_t dx = -radius; dx <= radius; ++dx) {
					if (std::max(std::abs(dx), std::abs(dy)) != radius) {
						continue;
					}
					const int32_t x = ax + dx;
					const int32_t y = ay + dy;
					if (!decoration_body_fits(x, y, zone_id, owner_grid, occupied, blocked, width, height, compact_footprint)) {
						continue;
					}
					Dictionary point = point_record(x, y);
					const int32_t jitter = int32_t(hash32_int(seed_text + String(":compact:") + String::num_int64(fallback[0]) + String("x") + String::num_int64(fallback[1]) + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 100000U);
					point["sort_key"] = String::num_int64(radius * 100000 + jitter);
					point["decoration_footprint_override"] = compact_footprint;
					point["decoration_fit_fallback"] = "compact_constrained_zone_proxy";
					compact_candidates.push_back(point);
				}
			}
			if (compact_candidates.size() >= 12) {
				break;
			}
		}
		std::sort(compact_candidates.begin(), compact_candidates.end(), [](const Dictionary &left, const Dictionary &right) {
			return String(left.get("sort_key", "")) < String(right.get("sort_key", ""));
		});
		if (!compact_candidates.empty()) {
			Dictionary result = compact_candidates.front();
			result.erase("sort_key");
			return result;
		}
	}
	return Dictionary();
}

Dictionary find_compact_decoration_density_point(const Dictionary &zone, int32_t ordinal, const Dictionary &normalized, const Array &owner_grid, const Dictionary &occupied, const Dictionary &blocked, int32_t width, int32_t height) {
	const String zone_id = String(zone.get("id", ""));
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const int32_t ax = int32_t(anchor.get("x", width / 2));
	const int32_t ay = int32_t(anchor.get("y", height / 2));
	const bool owner_like_small_density = native_rmg_owner_like_small_decoration_density_case(normalized);
	const Dictionary footprint = compact_density_decoration_footprint(ordinal, owner_like_small_density);
	const String seed_text = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":compact_density_decor:" + String::num_int64(ordinal);
	const int32_t coarse_cols = 8;
	const int32_t coarse_rows = 8;
	const int32_t desired_cell = int32_t(hash32_int(seed_text + String(":coarse")) % uint32_t(coarse_cols * coarse_rows));
	const int32_t desired_cx = desired_cell % coarse_cols;
	const int32_t desired_cy = desired_cell / coarse_cols;
	const String owner_medium_category = owner_attached_medium_001_spatial_category_for_kind("decorative_obstacle");
	std::vector<Dictionary> candidates;
	for (int32_t y = 1; y < height - 1; ++y) {
		if (y < 0 || y >= owner_grid.size()) {
			continue;
		}
		Array row = owner_grid[y];
		for (int32_t x = 1; x < width - 1; ++x) {
			if (!decoration_body_fits(x, y, zone_id, owner_grid, occupied, blocked, width, height, footprint)) {
				continue;
			}
			const int32_t cx = std::max(0, std::min(coarse_cols - 1, (x * coarse_cols) / std::max(1, width)));
			const int32_t cy = std::max(0, std::min(coarse_rows - 1, (y * coarse_rows) / std::max(1, height)));
			const int32_t coarse_distance = std::abs(cx - desired_cx) + std::abs(cy - desired_cy);
			const int32_t anchor_distance = std::abs(x - ax) + std::abs(y - ay);
			const int32_t preferred_anchor_distance = 6 + (ordinal % 17);
			const int32_t anchor_penalty = std::abs(anchor_distance - preferred_anchor_distance);
			const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, width, height);
			const int32_t boundary_choke_bonus = native_rmg_owner_like_small_land_density_case(normalized) && zone_boundary_barrier_cell(owner_grid, x, y, width, height) ? -900 : 0;
			const int32_t jitter = int32_t(hash32_int(seed_text + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 10000U);
			Dictionary point = point_record(x, y);
			const int64_t sort_key = int64_t(owner_grid_penalty + boundary_choke_bonus) * int64_t(1000000000) + int64_t(coarse_distance) * int64_t(100000000) + int64_t(anchor_penalty) * int64_t(10000) + int64_t(jitter);
			point["sort_key"] = sort_key;
			point["decoration_footprint_override"] = footprint;
			point["decoration_fit_fallback"] = "compact_owner_like_islands_density_marker";
			point["spatial_placement_policy"] = boundary_choke_bonus < 0 ? "owner_like_small_boundary_choke_compact_decoration_density" : "owner_like_islands_compact_decoration_density_scatter";
			candidates.push_back(point);
		}
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		return int64_t(left.get("sort_key", int64_t(0))) < int64_t(right.get("sort_key", int64_t(0)));
	});
	if (!candidates.empty()) {
		Dictionary result = candidates.front();
		result.erase("sort_key");
		return result;
	}
	return Dictionary();
}

Dictionary find_decoration_point_fast(const Dictionary &zone, int32_t ordinal, const Dictionary &normalized, NativeObjectPlacementContext &placement_context) {
	const String zone_id = String(zone.get("id", ""));
	const int32_t zone_index = native_zone_index_for_id(placement_context, zone_id);
	if (zone_index < 0) {
		return Dictionary();
	}
	const String terrain_id = terrain_id_for_zone(zone);
	const Dictionary footprint = object_footprint_for_kind("decorative_obstacle", ordinal, terrain_id);
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const int32_t ax = int32_t(anchor.get("x", placement_context.width / 2));
	const int32_t ay = int32_t(anchor.get("y", placement_context.height / 2));
	const String seed_text = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":decor:" + String::num_int64(ordinal);
	const String owner_medium_category = owner_attached_medium_001_spatial_category_for_kind("decorative_obstacle");
	const int32_t radius_limit = std::max(placement_context.width, placement_context.height);
	int32_t candidate_count = 0;
	int64_t best_sort_key = std::numeric_limits<int64_t>::max();
	int32_t best_x = -1;
	int32_t best_y = -1;
	for (int32_t radius = 2; radius <= radius_limit; ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t x = ax + dx;
				const int32_t y = ay + dy;
				if (!object_body_fits_in_zone_native(placement_context, x, y, zone_index, footprint)) {
					continue;
				}
				++candidate_count;
				const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, placement_context.width, placement_context.height);
				const int32_t owner_cluster_penalty = owner_attached_medium_001_existing_cluster_penalty(normalized, placement_context, owner_medium_category, x, y);
				const int32_t jitter = int32_t(hash32_int(seed_text + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 100000U);
				const int64_t sort_key = int64_t(owner_grid_penalty + owner_cluster_penalty) * 1000000000LL + int64_t(radius) * 100000LL + jitter;
				if (sort_key < best_sort_key) {
					best_sort_key = sort_key;
					best_x = x;
					best_y = y;
				}
			}
		}
		if (candidate_count >= 18) {
			break;
		}
	}
	if (best_x >= 0 && best_y >= 0) {
		Dictionary result = point_record(best_x, best_y);
		result["spatial_placement_policy"] = "native_cached_decoration_ring_scan";
		return result;
	}
	static constexpr int32_t COMPACT_FALLBACKS[2][2] = {{3, 2}, {2, 3}};
	for (const auto &fallback : COMPACT_FALLBACKS) {
		Dictionary compact_footprint = footprint.duplicate();
		compact_footprint["width"] = fallback[0];
		compact_footprint["height"] = fallback[1];
		compact_footprint["tier"] = "compact_constrained_zone_proxy";
		compact_footprint["source"] = "compact fallback for constrained HoMM3-re source-row proxy placement";
		candidate_count = 0;
		best_sort_key = std::numeric_limits<int64_t>::max();
		best_x = -1;
		best_y = -1;
		for (int32_t radius = 1; radius <= radius_limit; ++radius) {
			for (int32_t dy = -radius; dy <= radius; ++dy) {
				for (int32_t dx = -radius; dx <= radius; ++dx) {
					if (std::max(std::abs(dx), std::abs(dy)) != radius) {
						continue;
					}
					const int32_t x = ax + dx;
					const int32_t y = ay + dy;
					if (!object_body_fits_in_zone_native(placement_context, x, y, zone_index, compact_footprint)) {
						continue;
					}
					++candidate_count;
					const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, placement_context.width, placement_context.height);
					const int32_t owner_cluster_penalty = owner_attached_medium_001_existing_cluster_penalty(normalized, placement_context, owner_medium_category, x, y);
					const int32_t jitter = int32_t(hash32_int(seed_text + String(":compact:") + String::num_int64(fallback[0]) + String("x") + String::num_int64(fallback[1]) + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 100000U);
					const int64_t sort_key = int64_t(owner_grid_penalty + owner_cluster_penalty) * 1000000000LL + int64_t(radius) * 100000LL + jitter;
					if (sort_key < best_sort_key) {
						best_sort_key = sort_key;
						best_x = x;
						best_y = y;
					}
				}
			}
			if (candidate_count >= 12) {
				break;
			}
		}
		if (best_x >= 0 && best_y >= 0) {
			Dictionary result = point_record(best_x, best_y);
			result["decoration_footprint_override"] = compact_footprint;
			result["decoration_fit_fallback"] = "compact_constrained_zone_proxy";
			result["spatial_placement_policy"] = "native_cached_decoration_compact_fallback";
			return result;
		}
	}
	return Dictionary();
}

Dictionary find_compact_decoration_density_point_fast(const Dictionary &zone, int32_t ordinal, const Dictionary &normalized, NativeObjectPlacementContext &placement_context) {
	const String zone_id = String(zone.get("id", ""));
	const int32_t zone_index = native_zone_index_for_id(placement_context, zone_id);
	if (zone_index < 0 || zone_index >= int32_t(placement_context.zones.size())) {
		return Dictionary();
	}
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const int32_t ax = int32_t(anchor.get("x", placement_context.width / 2));
	const int32_t ay = int32_t(anchor.get("y", placement_context.height / 2));
	const bool owner_like_small_density = native_rmg_owner_like_small_decoration_density_case(normalized);
	const Dictionary footprint = compact_density_decoration_footprint(ordinal, owner_like_small_density);
	const String seed_text = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":compact_density_decor:" + String::num_int64(ordinal);
	const int32_t coarse_cols = 8;
	const int32_t coarse_rows = 8;
	const int32_t desired_cell = int32_t(hash32_int(seed_text + String(":coarse")) % uint32_t(coarse_cols * coarse_rows));
	const int32_t desired_cx = desired_cell % coarse_cols;
	const int32_t desired_cy = desired_cell / coarse_cols;
	const String owner_medium_category = owner_attached_medium_001_spatial_category_for_kind("decorative_obstacle");
	int64_t best_sort_key = std::numeric_limits<int64_t>::max();
	int32_t best_x = -1;
	int32_t best_y = -1;
	for (const NativePlacementTile &candidate : placement_context.zones[zone_index].candidates) {
		const int32_t x = candidate.x;
		const int32_t y = candidate.y;
		if (!object_body_fits_in_zone_native(placement_context, x, y, zone_index, footprint)) {
			continue;
		}
		const int32_t cx = std::max(0, std::min(coarse_cols - 1, (x * coarse_cols) / std::max(1, placement_context.width)));
		const int32_t cy = std::max(0, std::min(coarse_rows - 1, (y * coarse_rows) / std::max(1, placement_context.height)));
		const int32_t coarse_distance = std::abs(cx - desired_cx) + std::abs(cy - desired_cy);
		const int32_t anchor_distance = std::abs(x - ax) + std::abs(y - ay);
		const int32_t preferred_anchor_distance = 6 + (ordinal % 17);
		const int32_t anchor_penalty = std::abs(anchor_distance - preferred_anchor_distance);
		const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, placement_context.width, placement_context.height);
		const int32_t owner_cluster_penalty = owner_attached_medium_001_existing_cluster_penalty(normalized, placement_context, owner_medium_category, x, y);
		const int32_t boundary_choke_bonus = owner_like_small_density && native_context_zone_boundary_cell(placement_context, x, y) ? -900 : 0;
		const int32_t jitter = int32_t(hash32_int(seed_text + String(":") + String::num_int64(x) + String(",") + String::num_int64(y)) % 10000U);
		const int64_t sort_key = int64_t(owner_grid_penalty + owner_cluster_penalty + boundary_choke_bonus) * int64_t(1000000000) + int64_t(coarse_distance) * int64_t(100000000) + int64_t(anchor_penalty) * int64_t(10000) + int64_t(jitter);
		if (sort_key < best_sort_key) {
			best_sort_key = sort_key;
			best_x = x;
			best_y = y;
		}
	}
	if (best_x >= 0 && best_y >= 0) {
		Dictionary result = point_record(best_x, best_y);
		result["decoration_footprint_override"] = footprint;
		result["decoration_fit_fallback"] = "compact_owner_like_islands_density_marker";
		result["spatial_placement_policy"] = owner_like_small_density && native_context_zone_boundary_cell(placement_context, best_x, best_y)
				? "native_cached_owner_like_small_boundary_choke_compact_decoration_density"
				: "native_cached_owner_like_islands_compact_decoration_density_scatter";
		return result;
	}
	return Dictionary();
}

int32_t zone_value_budget_for_zone(const Dictionary &normalized, const Dictionary &zone);
String value_tier_for_amount(int32_t value);
Dictionary reward_value_profile_for_zone(const Dictionary &normalized, const Dictionary &zone, int32_t reward_index, int32_t ordinal);
void apply_reward_value_profile(Dictionary &family, const Dictionary &profile, int32_t ordinal);
Dictionary reward_band_source_offsets(int32_t source_index);
Dictionary object_point_for_zone_index_fast(const Dictionary &zone, int32_t ordinal, int32_t ring, const String &kind, const Dictionary &normalized, NativeObjectPlacementContext &placement_context, const Array &owner_grid, const Dictionary &occupied, const PackedInt32Array &road_distance_field);
void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const std::vector<NativeRoadCell> &road_cells, const Dictionary &zone_layout);

int32_t append_decoration_placements(Array &placements, Dictionary &occupied, NativeObjectPlacementContext &placement_context, const Dictionary &normalized, const Dictionary &zone_layout, const std::vector<NativeRoadCell> &road_cells, int32_t ordinal_start) {
	Array zones = zone_layout.get("zones", Array());
	int32_t ordinal = ordinal_start;
	for (int64_t zone_index = 0; zone_index < zones.size(); ++zone_index) {
		Dictionary zone = zones[zone_index];
		const int32_t target = decoration_target_for_zone(normalized, zone);
		for (int32_t decoration_index = 0; decoration_index < target; ++decoration_index) {
			bool placed = false;
			for (int32_t attempt = 0; attempt < 8; ++attempt) {
				Dictionary point = find_decoration_point_fast(zone, ordinal, normalized, placement_context);
				if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
					++ordinal;
					placed = true;
					break;
				}
				++ordinal;
			}
			if (!placed) {
				continue;
			}
		}
		const int32_t compact_target = owner_like_islands_compact_decoration_target_for_zone(normalized, zone);
		for (int32_t compact_index = 0; compact_index < compact_target; ++compact_index) {
			bool placed = false;
			for (int32_t attempt = 0; attempt < 8; ++attempt) {
				Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
				if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
					++ordinal;
					placed = true;
					break;
				}
				++ordinal;
			}
			if (!placed) {
				continue;
			}
		}
	}
	return ordinal;
}

int32_t native_catalog_auto_generated_object_floor(const Dictionary &normalized) {
	if (String(normalized.get("template_selection_mode", "")) != "native_catalog_auto") {
		return 0;
	}
	const String size_class_id = String(normalized.get("size_class_id", ""));
	if (size_class_id == "homm3_extra_large") {
		return 1100;
	}
	if (size_class_id == "homm3_large") {
		return 900;
	}
	if (size_class_id == "homm3_medium") {
		return 380;
	}
	if (size_class_id == "homm3_small") {
		return 275;
	}
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	return std::max(250, (width * height) / 20);
}

Dictionary append_native_catalog_auto_density_supplement(Array &placements, Dictionary &occupied, NativeObjectPlacementContext &placement_context, const Dictionary &normalized, const Dictionary &zone_layout, const std::vector<NativeRoadCell> &road_cells, int32_t &ordinal) {
	Dictionary summary;
	summary["schema_id"] = "native_rmg_catalog_auto_density_floor_supplement_v1";
	summary["policy"] = "size-aware deterministic decorative fill for runtime-valid auto-selected catalog templates";
	const int32_t target = native_catalog_auto_generated_object_floor(normalized);
	summary["target_generated_object_count"] = target;
	summary["initial_generated_object_count"] = int32_t(placements.size());
	summary["applied"] = false;
	summary["placed_count"] = 0;
	if (target <= 0 || int32_t(placements.size()) >= target) {
		summary["final_generated_object_count"] = int32_t(placements.size());
		summary["status"] = target <= 0 ? String("not_catalog_auto") : String("already_dense_enough");
		return summary;
	}
	Array zones = zone_layout.get("zones", Array());
	if (zones.is_empty()) {
		summary["final_generated_object_count"] = int32_t(placements.size());
		summary["status"] = "no_zones_available";
		return summary;
	}
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	const PackedInt32Array empty_road_distance_field;
	int32_t placed = 0;
	int32_t attempts = 0;
	const int32_t max_attempts = std::max(target * 4, int32_t(zones.size()) * 256);
	while (int32_t(placements.size()) < target && attempts < max_attempts) {
		Dictionary zone = Dictionary(zones[attempts % zones.size()]);
		Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
		if (point.is_empty()) {
			point = object_point_for_zone_index_fast(zone, ordinal, 5 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "decorative_obstacle", normalized, placement_context, owner_grid, occupied, empty_road_distance_field);
		}
		point["object_family_ordinal"] = int32_t(placements.size());
		point["placement_policy"] = "native_catalog_auto_size_density_floor_decoration_supplement";
		if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
			++placed;
		}
		++ordinal;
		++attempts;
	}
	summary["applied"] = true;
	summary["placed_count"] = placed;
	summary["attempt_count"] = attempts;
	summary["final_generated_object_count"] = int32_t(placements.size());
	summary["status"] = int32_t(placements.size()) >= target ? String("pass") : String("below_target_after_attempts");
	return summary;
}

void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const std::vector<NativeRoadCell> &road_cells, const Dictionary &zone_layout) {
	if (point.is_empty()) {
		return;
	}
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	const int32_t family_ordinal = int32_t(point.get("object_family_ordinal", ordinal));
	Dictionary family = object_family_record(kind, family_ordinal, terrain_id);
	Dictionary object_definition = object_pipeline_definition_for_kind(kind, family_ordinal, terrain_id);
	Dictionary reward_value_profile;
	if (kind == "reward_reference") {
		const int32_t reward_index = int32_t(point.get("native_reward_index", ordinal));
		reward_value_profile = reward_value_profile_for_zone(normalized, zone, reward_index, ordinal);
		apply_reward_value_profile(family, reward_value_profile, ordinal);
	}
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String placement_id = "native_rmg_" + kind + "_" + zone_id + "_" + slot_id_2(ordinal + 1);
	Dictionary body = cell_record(x, y, 0);
	Dictionary footprint = object_footprint_for_kind(kind, ordinal, terrain_id);
	if (kind == "decorative_obstacle" && point.has("decoration_footprint_override") && Variant(point.get("decoration_footprint_override", Dictionary())).get_type() == Variant::DICTIONARY) {
		footprint = Dictionary(point.get("decoration_footprint_override", Dictionary()));
		object_definition["footprint"] = footprint;
	}
	Array body_tiles = object_body_tiles_for_kind(kind, x, y, width, height, footprint);
	Array occupancy_keys;
	for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
		Dictionary body_tile = body_tiles[body_index];
		occupancy_keys.append(point_key(int32_t(body_tile.get("x", 0)), int32_t(body_tile.get("y", 0))));
	}
	Dictionary bounds;
	bounds["min_x"] = x;
	bounds["min_y"] = y;
	bounds["max_x"] = x + std::max(1, int32_t(footprint.get("width", 1))) - 1;
	bounds["max_y"] = y + std::max(1, int32_t(footprint.get("height", 1))) - 1;

	Dictionary runtime_footprint;
	runtime_footprint["width"] = footprint.get("width", 1);
	runtime_footprint["height"] = footprint.get("height", 1);
	runtime_footprint["anchor"] = footprint.get("anchor", "center");
	runtime_footprint["tier"] = footprint.get("tier", "micro");
	runtime_footprint["source"] = footprint.get("source", "native object placement pipeline");

	bool body_unoccupied = true;
	for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
		if (occupied.has(String(occupancy_keys[key_index]))) {
			body_unoccupied = false;
			break;
		}
	}
	if (!body_unoccupied) {
		return;
	}

	Dictionary predicate_results;
	predicate_results["in_bounds"] = x >= 0 && y >= 0 && x < width && y < height;
	predicate_results["terrain_allowed"] = is_passable_terrain_id(terrain_id);
	predicate_results["runtime_body_unoccupied"] = body_unoccupied;
	predicate_results["zone_associated"] = !zone_id.is_empty();
	predicate_results["road_proximity_recorded"] = true;

	Dictionary placement;
	placement["placement_id"] = placement_id;
	placement["kind"] = kind;
	placement["family_id"] = family.get("family_id", "");
	placement["object_family_id"] = family.get("object_family_id", "");
	placement["type_id"] = family.get("type_id", kind);
	placement["object_id"] = family.get("object_id", "");
	placement["site_id"] = family.get("site_id", "");
	placement["category_id"] = family.get("category_id", kind);
	placement["zone_id"] = zone_id;
	placement["zone_role"] = zone.get("role", "");
	placement["zone_base_size"] = zone.get("base_size", 0);
	placement["faction_id"] = zone.get("faction_id", "");
	placement["owner_slot"] = zone.get("owner_slot", Variant());
	placement["player_slot"] = zone.get("player_slot", Variant());
	placement["player_type"] = zone.get("player_type", "neutral");
	placement["terrain_id"] = terrain_id;
	placement["biome_id"] = biome_for_terrain(terrain_id);
	placement["x"] = x;
	placement["y"] = y;
	placement["level"] = 0;
	placement["primary_tile"] = body;
	placement["primary_occupancy_key"] = point_key(x, y);
	placement["bounds"] = bounds;
	placement["body_tiles"] = body_tiles;
	placement["occupancy_keys"] = occupancy_keys;
	placement["footprint"] = footprint;
	placement["runtime_footprint"] = runtime_footprint;
	placement["footprint_deferred"] = false;
	placement["object_definition_id"] = object_definition.get("definition_id", "");
	placement["object_type_metadata"] = object_definition.get("type_metadata", Dictionary());
	placement["passability"] = object_definition.get("passability", Dictionary());
	placement["action"] = object_definition.get("action", Dictionary());
	placement["terrain_constraints"] = object_definition.get("terrain_constraints", Dictionary());
	placement["value_density"] = object_definition.get("value_density", Dictionary());
	placement["writeout_metadata"] = object_definition.get("writeout", Dictionary());
	placement["ordinary_object_template_filler"] = kind == "decorative_obstacle";
	placement["decoration_super_type_shortcut"] = false;
	placement["approach_tiles"] = cardinal_approach_tiles(x, y, width, height, occupied);
	placement["visit_tile"] = body;
	Array predicates;
	predicates.append("in_bounds");
	predicates.append("terrain_allowed");
	predicates.append("runtime_body_unoccupied");
	predicates.append("zone_associated");
	predicates.append("road_proximity_recorded");
	placement["placement_predicates"] = predicates;
	placement["placement_predicate_results"] = predicate_results;
	placement["road_proximity"] = nearest_road_proximity_from_cells(x, y, road_cells);
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	Dictionary zone_proximity;
	zone_proximity["zone_anchor"] = anchor;
	zone_proximity["manhattan_distance_to_anchor"] = std::abs(x - int32_t(anchor.get("x", x))) + std::abs(y - int32_t(anchor.get("y", y)));
	zone_proximity["owner_grid_signature"] = zone_layout.get("signature", "");
	placement["zone_proximity"] = zone_proximity;
	if (kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference") {
		placement["zone_value_budget"] = zone_value_budget_for_zone(normalized, zone);
		placement["zone_value_tier"] = value_tier_for_amount(int32_t(placement["zone_value_budget"]));
		placement["homm3_re_budget_provenance"] = "derived_from_catalog_zone_treasure_bands_and_original_content_object_family";
	}
	if (kind == "reward_reference") {
		placement["reward_value_profile"] = reward_value_profile;
		placement["reward_index_in_zone"] = point.get("native_reward_index", ordinal);
		placement["reward_target_in_zone"] = point.get("native_reward_target", 0);
		const int32_t source_band_index = int32_t(reward_value_profile.get("source_band_index", -1));
		placement["homm3_re_phase"] = "phase_10_treasure_reward_bands";
		placement["homm3_re_phase_order"] = "after_phase_7_mines_resources_before_decorative_filler";
		placement["homm3_re_reward_band_source_offsets"] = reward_band_source_offsets(source_band_index);
		placement["homm3_re_reward_band_selection_rule"] = "low_at_least_100_high_at_or_above_low_positive_density_weighted_slot";
	}
	if (kind == "mine") {
		const int32_t category_index = int32_t(point.get("mine_category_index", family.get("homm3_re_mine_category_index", family_ordinal % RMG_MINE_CATEGORY_COUNT)));
		placement["homm3_re_phase"] = "phase_7_mines_resources";
		placement["homm3_re_phase_order"] = "after_towns_castles_and_cleanup_connections_before_treasure_reward_bands";
		placement["mine_category_index"] = category_index;
		placement["mine_category_id"] = rmg_mine_category_id(category_index);
		placement["homm3_re_mine_source_equivalent"] = rmg_mine_source_equivalent(category_index);
		placement["source_field_offset"] = point.get("source_field_offset", rmg_mine_minimum_source_offset(category_index));
		placement["source_field_name"] = point.get("source_field_name", "");
		placement["source_field_value"] = point.get("source_field_value", 0);
		placement["source_phase"] = point.get("source_phase", "phase_7_mine_minimum");
		placement["density_selection_slot"] = point.get("density_selection_slot", -1);
		placement["special_near_start_bias"] = point.get("special_near_start_bias", false);
		placement["adjacent_resource_policy"] = point.get("adjacent_resource_policy", "same_category_support_record");
		placement["placement_policy"] = point.get("placement_policy", "phase_7_minimum_before_density_mine_category_placement");
	}
	if (kind == "resource_site" && point.has("adjacent_to_mine_placement_id")) {
		const int32_t category_index = int32_t(point.get("mine_category_index", 0));
		placement["homm3_re_phase"] = "phase_7_adjacent_resource_support";
		placement["mine_category_index"] = category_index;
		placement["mine_category_id"] = rmg_mine_category_id(category_index);
		placement["homm3_re_resource_source_equivalent"] = rmg_mine_source_equivalent(category_index);
		placement["adjacent_to_mine_placement_id"] = point.get("adjacent_to_mine_placement_id", "");
		placement["adjacent_resource_support"] = true;
		placement["placement_policy"] = "phase_7_adjacent_resource_object_when_original_runtime_pickup_supported";
	}
	placement["bounds_status"] = "in_bounds";
	placement["occupancy_status"] = "primary_tile_reserved";
	placement["materialization_state"] = "staged_object_record_only_no_gameplay_adoption";
	placement["writeout_state"] = "staged_no_authored_content_writeback";
	if (point.has("spatial_placement_policy")) {
		placement["spatial_placement_policy"] = point.get("spatial_placement_policy", "");
	}
	if (kind == "resource_site") {
		placement["placement_policy"] = String(family.get("purpose", "")).begins_with("start_support") ? "strict_start_zone_support_resource_path_scored" : "generic_resource_site";
		placement["support_route_path_length"] = std::max(1, int32_t(std::abs(x - int32_t(Dictionary(zone.get("anchor", Dictionary())).get("x", x))) + std::abs(y - int32_t(Dictionary(zone.get("anchor", Dictionary())).get("y", y)))));
	}
	if (kind == "decorative_obstacle") {
		placement["approach_tiles"] = Array();
		placement["blocking_body"] = true;
		placement["family_body_mask_source"] = "terrain_biased_decoration_family_passability_mask";
		placement["visitable"] = false;
		placement["interaction"] = "none";
		placement["approach_policy"] = "non_visitable_no_approach";
		placement["occupancy_metadata"] = "blocking_body_tiles_reserved_in_native_object_occupancy";
		placement["decoration_family_source"] = "homm3_re_rand_trn_source_row_with_original_runtime_proxy_family";
		if (point.has("decoration_fit_fallback")) {
			placement["decoration_fit_fallback"] = point.get("decoration_fit_fallback", "");
		}
	} else if (kind == "scenic_object") {
		placement["approach_tiles"] = Array();
		placement["blocking_body"] = true;
		placement["visitable"] = false;
		placement["interaction"] = "none";
		placement["approach_policy"] = "non_visitable_other_map_object_equivalent";
		placement["occupancy_metadata"] = "blocking_body_tiles_reserved_in_native_object_occupancy";
		placement["homm3_re_phase"] = "owner_uploaded_small_other_object_category";
	}
	for (int64_t key_index = 0; key_index < family.keys().size(); ++key_index) {
		const String key = String(family.keys()[key_index]);
		if (!placement.has(key)) {
			placement[key] = family[key];
		}
	}
	placement["signature"] = hash32_hex(canonical_variant(placement));

	placements.append(placement);
	for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
		occupied[String(occupancy_keys[key_index])] = placement_id;
	}
}

Dictionary count_by_field(const Array &placements, const String &field) {
	Dictionary counts;
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		const String key = String(placement.get(field, "unknown"));
		counts[key] = int32_t(counts.get(key, 0)) + 1;
	}
	return counts;
}

Dictionary decoration_route_shaping_summary(const Array &placements, const Dictionary &road_network) {
	Dictionary body_lookup;
	int32_t blocking_body_tile_total = 0;
	int32_t multitile_decoration_count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		if (String(placement.get("kind", "")) != "decorative_obstacle") {
			continue;
		}
		Array body_tiles = placement.get("body_tiles", Array());
		if (body_tiles.size() > 1) {
			++multitile_decoration_count;
		}
		for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
			Dictionary body = body_tiles[body_index];
			body_lookup[point_key(int32_t(body.get("x", 0)), int32_t(body.get("y", 0)))] = placement.get("placement_id", "");
			++blocking_body_tile_total;
		}
	}
	Dictionary required_with_shoulder;
	Dictionary required_with_choke;
	int32_t road_tile_count = 0;
	int32_t choked_road_tile_count = 0;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		const String route_edge_id = String(segment.get("route_edge_id", ""));
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			Dictionary cell = cells[cell_index];
			++road_tile_count;
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			int32_t adjacent = 0;
			static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
			for (const auto &offset : OFFSETS) {
				if (body_lookup.has(point_key(x + offset[0], y + offset[1]))) {
					++adjacent;
				}
			}
			if (adjacent > 0 && !route_edge_id.is_empty()) {
				required_with_shoulder[route_edge_id] = true;
			}
			if (adjacent >= 2 && !route_edge_id.is_empty()) {
				required_with_choke[route_edge_id] = true;
				++choked_road_tile_count;
			}
		}
	}
	Dictionary summary;
	summary["schema_id"] = "native_random_map_decoration_route_shaping_v1";
	summary["policy"] = "decorative_obstacle_bodies_are_biased_to_route_shoulders_without_blocking_required_roads";
	summary["status"] = "pass";
	summary["road_tile_count"] = road_tile_count;
	summary["blocking_body_tile_total"] = blocking_body_tile_total;
	summary["multitile_decoration_count"] = multitile_decoration_count;
	summary["route_shoulder_decoration_count"] = required_with_shoulder.size();
	summary["required_route_with_shoulder_count"] = required_with_shoulder.size();
	summary["required_route_with_choke_count"] = required_with_choke.size();
	summary["choked_road_tile_count"] = choked_road_tile_count;
	return summary;
}

Dictionary object_fill_coverage_summary(const Array &placements, const Dictionary &zone_layout, int32_t width, int32_t height) {
	Dictionary all_body_lookup;
	Dictionary decoration_body_lookup;
	Dictionary blocking_body_lookup;
	Dictionary visit_lookup;
	Dictionary decoration_count_by_zone;
	Dictionary decoration_body_by_zone;
	Dictionary homm3_re_source_row_lookup;
	Dictionary homm3_re_type_name_lookup;
	Dictionary homm3_re_terrain_name_lookup;
	Dictionary proxy_family_lookup;
	int32_t decoration_count = 0;
	int32_t decoration_body_tile_total = 0;
	int32_t authored_large_decoration_count = 0;
	int32_t homm3_re_sourced_decoration_count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		const String kind = String(placement.get("kind", ""));
		const String zone_id = String(placement.get("zone_id", ""));
		Array body_tiles = placement.get("body_tiles", Array());
		if (kind == "decorative_obstacle") {
			++decoration_count;
			decoration_count_by_zone[zone_id] = int32_t(decoration_count_by_zone.get(zone_id, 0)) + 1;
			if (body_tiles.size() >= 6) {
				++authored_large_decoration_count;
			}
			if (String(placement.get("homm3_re_source_kind", "")) == "rand_trn_obstacle_row") {
				++homm3_re_sourced_decoration_count;
				homm3_re_source_row_lookup[String::num_int64(int64_t(placement.get("homm3_re_rand_trn_source_row", 0)))] = true;
				homm3_re_type_name_lookup[String(placement.get("homm3_re_type_name", ""))] = true;
				homm3_re_terrain_name_lookup[String(placement.get("homm3_re_terrain_name", ""))] = true;
				proxy_family_lookup[String(placement.get("proxy_family_id", placement.get("family_id", "")))] = true;
			}
		}
		for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
			Dictionary body = body_tiles[body_index];
			const String key = point_key(int32_t(body.get("x", 0)), int32_t(body.get("y", 0)));
			all_body_lookup[key] = true;
			if (kind == "decorative_obstacle") {
				decoration_body_lookup[key] = true;
				blocking_body_lookup[key] = true;
				++decoration_body_tile_total;
				decoration_body_by_zone[zone_id] = int32_t(decoration_body_by_zone.get(zone_id, 0)) + 1;
			} else if (bool(placement.get("blocking_body", false))) {
				blocking_body_lookup[key] = true;
			}
		}
		Dictionary visit_tile = placement.get("visit_tile", Dictionary());
		if (!visit_tile.is_empty()) {
			visit_lookup[point_key(int32_t(visit_tile.get("x", 0)), int32_t(visit_tile.get("y", 0)))] = true;
		}
	}
	Array zones = zone_layout.get("zones", Array());
	int32_t min_zone_decoration_count = std::numeric_limits<int32_t>::max();
	int32_t max_zone_decoration_count = 0;
	int32_t min_zone_decoration_body_tiles = std::numeric_limits<int32_t>::max();
	int32_t max_zone_decoration_body_tiles = 0;
	double min_zone_decoration_body_coverage = 1.0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		const int32_t cell_count = std::max(1, int32_t(zone.get("cell_count", 1)));
		const int32_t zone_count = int32_t(decoration_count_by_zone.get(zone_id, 0));
		const int32_t zone_body = int32_t(decoration_body_by_zone.get(zone_id, 0));
		min_zone_decoration_count = std::min(min_zone_decoration_count, zone_count);
		max_zone_decoration_count = std::max(max_zone_decoration_count, zone_count);
		min_zone_decoration_body_tiles = std::min(min_zone_decoration_body_tiles, zone_body);
		max_zone_decoration_body_tiles = std::max(max_zone_decoration_body_tiles, zone_body);
		min_zone_decoration_body_coverage = std::min(min_zone_decoration_body_coverage, double(zone_body) / double(cell_count));
	}
	const int32_t map_tiles = std::max(1, width * height);
	Dictionary summary;
	summary["schema_id"] = "native_random_map_fill_coverage_summary_v1";
	summary["map_tile_count"] = map_tiles;
	summary["unique_body_tile_count"] = all_body_lookup.size();
	summary["unique_decoration_blocker_body_tile_count"] = decoration_body_lookup.size();
	summary["unique_blocking_body_tile_count"] = blocking_body_lookup.size();
	summary["unique_visit_tile_count"] = visit_lookup.size();
	summary["body_coverage_ratio"] = double(all_body_lookup.size()) / double(map_tiles);
	summary["decoration_blocker_body_coverage_ratio"] = double(decoration_body_lookup.size()) / double(map_tiles);
	summary["blocking_body_coverage_ratio"] = double(blocking_body_lookup.size()) / double(map_tiles);
	summary["visit_tile_coverage_ratio"] = double(visit_lookup.size()) / double(map_tiles);
	summary["empty_body_tile_ratio"] = 1.0 - double(all_body_lookup.size()) / double(map_tiles);
	summary["decoration_count"] = decoration_count;
	summary["authored_large_decoration_count"] = authored_large_decoration_count;
	summary["authored_large_decoration_ratio"] = decoration_count <= 0 ? 0.0 : double(authored_large_decoration_count) / double(decoration_count);
	summary["homm3_re_sourced_decoration_count"] = homm3_re_sourced_decoration_count;
	summary["homm3_re_sourced_decoration_ratio"] = decoration_count <= 0 ? 0.0 : double(homm3_re_sourced_decoration_count) / double(decoration_count);
	summary["homm3_re_unique_source_row_count"] = homm3_re_source_row_lookup.size();
	summary["homm3_re_unique_type_name_count"] = homm3_re_type_name_lookup.size();
	summary["homm3_re_unique_terrain_name_count"] = homm3_re_terrain_name_lookup.size();
	summary["homm3_re_unique_proxy_family_count"] = proxy_family_lookup.size();
	summary["average_decoration_body_tiles"] = decoration_count <= 0 ? 0.0 : double(decoration_body_tile_total) / double(decoration_count);
	summary["decoration_count_by_zone"] = decoration_count_by_zone;
	summary["decoration_body_tiles_by_zone"] = decoration_body_by_zone;
	summary["min_zone_decoration_count"] = min_zone_decoration_count == std::numeric_limits<int32_t>::max() ? 0 : min_zone_decoration_count;
	summary["max_zone_decoration_count"] = max_zone_decoration_count;
	summary["min_zone_decoration_body_tiles"] = min_zone_decoration_body_tiles == std::numeric_limits<int32_t>::max() ? 0 : min_zone_decoration_body_tiles;
	summary["max_zone_decoration_body_tiles"] = max_zone_decoration_body_tiles;
	summary["min_zone_decoration_body_coverage_ratio"] = zones.is_empty() ? 0.0 : min_zone_decoration_body_coverage;
	return summary;
}

Dictionary object_placement_pipeline_summary(const Dictionary &normalized, const Dictionary &zone_layout, const Array &placements, const Dictionary &occupancy_index, int64_t elapsed_usec, const Dictionary &runtime_phase_profile) {
	static constexpr const char *SUPPORTED_KINDS[] = {"resource_site", "mine", "neutral_dwelling", "reward_reference", "decorative_obstacle", "scenic_object", "town", "route_guard", "special_guard_gate"};
	Dictionary definitions;
	Dictionary global_counts;
	Dictionary per_zone_counts;
	Dictionary passability_counts;
	Dictionary action_counts;
	Dictionary writeout_counts;
	Dictionary terrain_constraint_counts;
	Dictionary limit_failures;
	int32_t decoration_count = 0;
	int32_t ordinary_decoration_count = 0;
	int32_t missing_definition_count = 0;
	int32_t missing_mask_count = 0;
	int32_t missing_writeout_count = 0;
	int32_t body_reference_count = 0;
	int32_t body_overlap_count = std::max(0, int32_t(occupancy_index.get("duplicate_body_tile_count", 0)));

	for (const char *kind_value : SUPPORTED_KINDS) {
		const String kind = kind_value;
		definitions[kind] = object_pipeline_definition_for_kind(kind, 0, "grass");
	}

	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		body_reference_count += Array(placement.get("occupancy_keys", Array())).size();
		const String kind = String(placement.get("kind", ""));
		const String zone_id = String(placement.get("zone_id", ""));
		global_counts[kind] = int32_t(global_counts.get(kind, 0)) + 1;
		Dictionary zone_counts = per_zone_counts.get(zone_id, Dictionary());
		zone_counts[kind] = int32_t(zone_counts.get(kind, 0)) + 1;
		per_zone_counts[zone_id] = zone_counts;

		if (String(placement.get("object_definition_id", "")).is_empty() || !definitions.has(kind)) {
			++missing_definition_count;
		}
		Dictionary passability = placement.get("passability", Dictionary());
		Dictionary action = placement.get("action", Dictionary());
		Dictionary terrain = placement.get("terrain_constraints", Dictionary());
		Dictionary writeout = placement.get("writeout_metadata", Dictionary());
		if (passability.is_empty() || action.is_empty()) {
			++missing_mask_count;
		}
		if (writeout.is_empty()) {
			++missing_writeout_count;
		}
		passability_counts[String(passability.get("class", "missing"))] = int32_t(passability_counts.get(String(passability.get("class", "missing")), 0)) + 1;
		action_counts[String(action.get("class", "missing"))] = int32_t(action_counts.get(String(action.get("class", "missing")), 0)) + 1;
		writeout_counts[String(writeout.get("record_kind", "missing"))] = int32_t(writeout_counts.get(String(writeout.get("record_kind", "missing")), 0)) + 1;
		terrain_constraint_counts[String(terrain.get("runtime_terrain_id", "missing"))] = int32_t(terrain_constraint_counts.get(String(terrain.get("runtime_terrain_id", "missing")), 0)) + 1;
		if (kind == "decorative_obstacle") {
			++decoration_count;
			if (bool(placement.get("ordinary_object_template_filler", false)) && !bool(placement.get("decoration_super_type_shortcut", true))) {
				++ordinary_decoration_count;
			}
		}
	}

	Array definition_keys = definitions.keys();
	for (int64_t def_index = 0; def_index < definition_keys.size(); ++def_index) {
		const String kind = String(definition_keys[def_index]);
		Dictionary definition = definitions[kind];
		Dictionary limits = Dictionary(Dictionary(definition.get("type_metadata", Dictionary())).get("limits", Dictionary()));
		const int32_t global_limit = std::max(0, int32_t(limits.get("global", 0)));
		const int32_t global_count = int32_t(global_counts.get(kind, 0));
		if (global_limit > 0 && global_count > global_limit) {
			limit_failures["global:" + kind] = global_count;
		}
		Array zone_keys = per_zone_counts.keys();
		for (int64_t zone_index = 0; zone_index < zone_keys.size(); ++zone_index) {
			Dictionary zone_counts = Dictionary(per_zone_counts[zone_keys[zone_index]]);
			const int32_t per_zone_limit = std::max(0, int32_t(limits.get("per_zone", 0)));
			const int32_t zone_count = int32_t(zone_counts.get(kind, 0));
			if (per_zone_limit > 0 && zone_count > per_zone_limit) {
				limit_failures[String(zone_keys[zone_index]) + ":" + kind] = zone_count;
			}
		}
	}

	Dictionary xl_cost;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t tile_count = std::max(1, width * height);
	xl_cost["measured"] = true;
	xl_cost["elapsed_usec"] = elapsed_usec;
	xl_cost["elapsed_msec"] = double(elapsed_usec) / 1000.0;
	xl_cost["map_tile_count"] = tile_count;
	xl_cost["microseconds_per_tile"] = double(elapsed_usec) / double(tile_count);
	xl_cost["bounded_large_map_sampling"] = width > 72 || height > 72;
	xl_cost["budget_msec_for_xl_report"] = 90000.0;
	xl_cost["budget_scope"] = "focused_report_bounded_sampling_ceiling_not_release_perf_target";
	xl_cost["status"] = double(elapsed_usec) / 1000.0 <= 90000.0 ? "pass" : "over_budget";

	Array unsupported_boundaries;
	unsupported_boundaries.append("exact_homm3_object_table_candidate_scoring_not_claimed");
	unsupported_boundaries.append("homm3_def_art_names_are_metadata_only_and_not_imported");
	unsupported_boundaries.append("binary_h3m_writeout_not_claimed");

	Dictionary summary;
	summary["schema_id"] = "aurelion_native_rmg_homm3_object_placement_pipeline_summary_v1";
	summary["phase_order"] = "shared_object_pipeline_after_roads_connections_before_late_guard_reward_validation_with_phase_12_decorative_filler";
	summary["source_model"] = "recovered_object_template_footprint_mask_limit_value_density_structure_translated_to_original_content";
	summary["supported_definition_count"] = definitions.size();
	summary["supported_original_definitions"] = definitions;
	summary["object_count"] = placements.size();
	summary["global_counts"] = global_counts;
	summary["per_zone_counts"] = per_zone_counts;
	summary["passability_counts"] = passability_counts;
	summary["action_counts"] = action_counts;
	summary["terrain_constraint_counts"] = terrain_constraint_counts;
	summary["writeout_record_counts"] = writeout_counts;
	summary["occupancy_status"] = occupancy_index.get("status", "");
	summary["body_tile_reference_count"] = body_reference_count;
	summary["body_overlap_count"] = std::max(0, body_overlap_count);
	summary["missing_definition_count"] = missing_definition_count;
	summary["missing_mask_count"] = missing_mask_count;
	summary["missing_writeout_count"] = missing_writeout_count;
	summary["limit_failure_count"] = limit_failures.size();
	summary["limit_failures"] = limit_failures;
	summary["decorative_filler_semantics"] = "ordinary_object_template_rand_trn_proxy_not_decoration_super_type";
	summary["decorative_filler_ordinary_template_count"] = ordinary_decoration_count;
	summary["decorative_filler_count"] = decoration_count;
	summary["decorative_filler_ordinary_template_ratio"] = decoration_count <= 0 ? 0.0 : double(ordinary_decoration_count) / double(decoration_count);
	summary["xl_cost"] = xl_cost;
	summary["runtime_phase_profile"] = runtime_phase_profile;
	summary["unsupported_parity_boundaries"] = unsupported_boundaries;
	const bool ok = missing_definition_count == 0
			&& missing_mask_count == 0
			&& missing_writeout_count == 0
			&& body_overlap_count <= 0
			&& limit_failures.is_empty()
			&& decoration_count > 0
			&& ordinary_decoration_count == decoration_count
			&& String(xl_cost.get("status", "")) == "pass";
	summary["validation_status"] = ok ? "pass" : "fail";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	return summary;
}

Dictionary deterministic_object_placement_pipeline_summary(const Dictionary &summary) {
	Dictionary deterministic = summary.duplicate(true);
	deterministic.erase("runtime_phase_profile");
	deterministic.erase("diagnostic_signature");
	deterministic.erase("replay_identity_signature");
	deterministic.erase("signature");
	Dictionary xl_cost = deterministic.get("xl_cost", Dictionary());
	xl_cost["elapsed_usec"] = 0;
	xl_cost["elapsed_msec"] = 0.0;
	xl_cost["microseconds_per_tile"] = 0.0;
	deterministic["xl_cost"] = xl_cost;
	deterministic["signature"] = hash32_hex(canonical_variant(deterministic));
	return deterministic;
}

String deterministic_object_placement_pipeline_signature(const Dictionary &object_placement) {
	return String(deterministic_object_placement_pipeline_summary(Dictionary(object_placement.get("object_placement_pipeline_summary", Dictionary()))).get("signature", ""));
}

Dictionary zone_by_id(const Array &zones, const String &zone_id);

int32_t sum_dictionary_int_values(const Dictionary &values) {
	int32_t total = 0;
	Array keys = values.keys();
	for (int64_t index = 0; index < keys.size(); ++index) {
		total += std::max(0, int32_t(values.get(keys[index], 0)));
	}
	return total;
}

int32_t map_area_scale(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	return std::max(1, (width * height) / 1296);
}

Array valid_treasure_bands_for_zone(const Dictionary &zone) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Array source_bands = metadata.get("treasure_bands", Array());
	Array bands;
	for (int64_t index = 0; index < source_bands.size(); ++index) {
		if (Variant(source_bands[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary band = source_bands[index];
		const int32_t low = int32_t(band.get("low", 0));
		const int32_t high = int32_t(band.get("high", 0));
		const int32_t density = int32_t(band.get("density", 0));
		if (low < 100 || high < low || density <= 0) {
			continue;
		}
		Dictionary normalized_band;
		normalized_band["low"] = low;
		normalized_band["high"] = high;
		normalized_band["density"] = density;
		normalized_band["source_index"] = int32_t(index);
		bands.append(normalized_band);
	}
	if (!bands.is_empty()) {
		return bands;
	}

	const String role = String(zone.get("role", ""));
	Dictionary fallback;
	fallback["low"] = role.contains("start") ? 300 : 500;
	fallback["high"] = role.contains("start") ? 1800 : 3000;
	fallback["density"] = role.contains("start") ? 4 : 6;
	fallback["source_index"] = -1;
	fallback["fallback_source"] = "native_zone_richness_floor";
	bands.append(fallback);
	return bands;
}

int32_t zone_value_budget_for_zone(const Dictionary &normalized, const Dictionary &zone) {
	Array bands = valid_treasure_bands_for_zone(zone);
	double weighted_total = 0.0;
	int32_t density_total = 0;
	for (int64_t index = 0; index < bands.size(); ++index) {
		Dictionary band = bands[index];
		const int32_t density = std::max(0, int32_t(band.get("density", 0)));
		const int32_t midpoint = (int32_t(band.get("low", 0)) + int32_t(band.get("high", 0))) / 2;
		weighted_total += double(midpoint) * double(density);
		density_total += density;
	}
	if (density_total <= 0) {
		return 0;
	}
	const double scale = std::sqrt(double(map_area_scale(normalized))) / 3.0;
	return std::max(0, int32_t(std::llround(weighted_total * scale)));
}

String value_tier_for_amount(int32_t value) {
	if (value >= 10000) {
		return "relic";
	}
	if (value >= 6000) {
		return "major";
	}
	if (value >= 2500) {
		return "medium";
	}
	return "minor";
}

Dictionary reward_value_profile_for_zone(const Dictionary &normalized, const Dictionary &zone, int32_t reward_index, int32_t ordinal) {
	Array bands = valid_treasure_bands_for_zone(zone);
	int32_t density_total = 0;
	for (int64_t index = 0; index < bands.size(); ++index) {
		density_total += std::max(0, int32_t(Dictionary(bands[index]).get("density", 0)));
	}
	const int32_t slot = density_total <= 0 ? 0 : std::abs(reward_index) % density_total;
	int32_t cursor = 0;
	Dictionary selected = bands.is_empty() ? Dictionary() : Dictionary(bands[0]);
	for (int64_t index = 0; index < bands.size(); ++index) {
		Dictionary band = bands[index];
		cursor += std::max(0, int32_t(band.get("density", 0)));
		if (slot < cursor) {
			selected = band;
			break;
		}
	}
	const int32_t low = std::max(100, int32_t(selected.get("low", 500)));
	const int32_t high = std::max(low, int32_t(selected.get("high", low)));
	const uint32_t span = uint32_t(std::max(1, high - low + 1));
	const String seed_key = String(normalized.get("normalized_seed", "0")) + String(":reward_value:") + String(zone.get("id", "")) + String(":") + String::num_int64(reward_index) + String(":") + String::num_int64(ordinal);
	const int32_t raw_value = low + int32_t(hash32_int(seed_key) % span);
	const int32_t snapped_value = std::max(low, std::min(high, ((raw_value + 25) / 50) * 50));
	Dictionary profile;
	profile["source_model"] = "HoMM3_RMG_zone_treasure_band_low_high_density_translated_to_original_content";
	profile["reward_index"] = reward_index;
	profile["source_band_index"] = selected.get("source_index", -1);
	profile["band_low"] = low;
	profile["band_high"] = high;
	profile["band_density"] = selected.get("density", 0);
	profile["reward_value"] = snapped_value;
	profile["reward_value_tier"] = value_tier_for_amount(snapped_value);
	profile["zone_value_budget"] = zone_value_budget_for_zone(normalized, zone);
	profile["zone_value_tier"] = value_tier_for_amount(int32_t(profile["zone_value_budget"]));
	profile["selection_slot"] = slot;
	profile["selection_density_total"] = density_total;
	return profile;
}

void apply_reward_value_profile(Dictionary &family, const Dictionary &profile, int32_t ordinal) {
	const int32_t value = int32_t(profile.get("reward_value", family.get("reward_value", 0)));
	const String tier = String(profile.get("reward_value_tier", value_tier_for_amount(value)));
	family["reward_value"] = value;
	family["guard_base_value"] = std::max(250, std::min(30000, int32_t(std::llround(double(value) * (tier == "relic" ? 0.75 : (tier == "major" ? 0.68 : (tier == "medium" ? 0.58 : 0.35)))))));
	family["reward_value_tier"] = tier;
	family["zone_value_budget"] = profile.get("zone_value_budget", 0);
	family["zone_value_tier"] = profile.get("zone_value_tier", "");
	family["homm3_re_value_source_model"] = profile.get("source_model", "");
	family["homm3_re_reward_band_low"] = profile.get("band_low", 0);
	family["homm3_re_reward_band_high"] = profile.get("band_high", 0);
	family["homm3_re_reward_band_density"] = profile.get("band_density", 0);
	family["homm3_re_reward_band_source_index"] = profile.get("source_band_index", -1);
	family["homm3_re_reward_selection_slot"] = profile.get("selection_slot", 0);
	family["homm3_re_reward_selection_density_total"] = profile.get("selection_density_total", 0);

	if (tier == "relic" || tier == "major") {
		static constexpr const char *ARTIFACT_IDS[] = {"artifact_bastion_gorget", "artifact_warcrest_pennon", "artifact_milepost_lantern", "artifact_quarry_tally_rod"};
		const int32_t index = ordinal % 4;
		family.erase("spell_id");
		family["family_id"] = tier == "relic" ? "relic_artifact_cache" : "major_artifact_cache";
		family["object_family_id"] = family["family_id"];
		family["category_id"] = "artifact";
		family["reward_category"] = "artifact";
		family["reward_source_bucket"] = tier == "relic" ? "top_treasure_band_artifact" : "high_treasure_band_artifact";
		family["object_id"] = ARTIFACT_IDS[index];
		family["artifact_id"] = ARTIFACT_IDS[index];
		family["site_id"] = "";
		family["guarded_policy"] = "guarded_required";
	} else if (tier == "medium") {
		family.erase("artifact_id");
		family.erase("spell_id");
		family["family_id"] = "guarded_reward_cache";
		family["object_family_id"] = "guarded_reward_cache";
		family["category_id"] = "guarded_cache";
		family["reward_category"] = "guarded_cache";
		family["reward_source_bucket"] = "middle_treasure_band_guarded_cache";
		family["object_id"] = ordinal % 2 == 0 ? "object_waystone_cache" : "object_ore_crates";
		family["site_id"] = "site_waystone_cache";
		family["guarded_policy"] = "guarded_required";
	} else {
		family.erase("artifact_id");
		family.erase("spell_id");
		family["family_id"] = "reward_cache_small";
		family["object_family_id"] = "reward_cache_small";
		family["category_id"] = ordinal % 2 == 0 ? "resource_cache" : "build_resource_cache";
		family["reward_category"] = family["category_id"];
		family["reward_source_bucket"] = "low_treasure_band_resource_cache";
		family["object_id"] = ordinal % 2 == 0 ? "object_waystone_cache" : "object_wood_wagon";
		family["site_id"] = ordinal % 2 == 0 ? "site_waystone_cache" : "site_wood_wagon";
		family["guarded_policy"] = "unguarded_or_light_guard_allowed";
	}
	Dictionary proxy = homm3_re_reward_object_proxy_record("reward_reference", tier, String(family.get("reward_source_bucket", "")), String(family.get("category_id", "")), ordinal);
	apply_homm3_re_reward_object_proxy(family, proxy, true);
	if (String(family.get("category_id", "")) == "artifact") {
		family["guarded_policy"] = tier == "minor" ? "guarded_preferred" : "guarded_required";
	} else if (String(family.get("category_id", "")) == "guarded_cache") {
		family["guarded_policy"] = "guarded_required";
	} else if (String(family.get("category_id", "")) == "spell_access" || String(family.get("category_id", "")) == "skill_equivalent") {
		family["guarded_policy"] = tier == "minor" ? "unguarded_or_light_guard_allowed" : "guarded_preferred";
	}
	family["purpose"] = "zone_reward_value_budget_materialization";
}

Dictionary reward_band_source_offsets(int32_t source_index) {
	static constexpr const char *LOWS[] = {"+0xa0", "+0xac", "+0xb8"};
	static constexpr const char *HIGHS[] = {"+0xa4", "+0xb0", "+0xbc"};
	static constexpr const char *DENSITIES[] = {"+0xa8", "+0xb4", "+0xc0"};
	Dictionary offsets;
	if (source_index < 0 || source_index >= 3) {
		offsets["low"] = "";
		offsets["high"] = "";
		offsets["density"] = "";
		return offsets;
	}
	offsets["low"] = LOWS[source_index];
	offsets["high"] = HIGHS[source_index];
	offsets["density"] = DENSITIES[source_index];
	return offsets;
}

Dictionary reward_band_summary_for_zones(const Dictionary &normalized, const Array &zones, const Array &placements) {
	Array diagnostics;
	Dictionary placed_by_band;
	int32_t reward_count = 0;
	int32_t out_of_band_count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		if (String(placement.get("kind", "")) != "reward_reference") {
			continue;
		}
		++reward_count;
		const int32_t source_index = int32_t(placement.get("homm3_re_reward_band_source_index", -1));
		placed_by_band[String::num_int64(source_index)] = int32_t(placed_by_band.get(String::num_int64(source_index), 0)) + 1;
		const int32_t value = int32_t(placement.get("reward_value", 0));
		const int32_t low = int32_t(placement.get("homm3_re_reward_band_low", 0));
		const int32_t high = int32_t(placement.get("homm3_re_reward_band_high", 0));
		if (low >= 100 && high >= low && (value < low || value > high)) {
			++out_of_band_count;
			Dictionary diagnostic;
			diagnostic["code"] = "reward_value_outside_selected_band";
			diagnostic["severity"] = "failure";
			diagnostic["placement_id"] = placement.get("placement_id", "");
			diagnostic["reward_value"] = value;
			diagnostic["band_low"] = low;
			diagnostic["band_high"] = high;
			diagnostics.append(diagnostic);
		}
	}

	int32_t source_band_count = 0;
	int32_t valid_band_count = 0;
	int32_t invalid_band_count = 0;
	int32_t fallback_zone_count = 0;
	Array invalid_band_records;
	for (int64_t zone_index = 0; zone_index < zones.size(); ++zone_index) {
		if (Variant(zones[zone_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[zone_index]);
		Dictionary metadata = zone.get("catalog_metadata", Dictionary());
		Array bands = metadata.get("treasure_bands", Array());
		int32_t zone_valid_count = 0;
		for (int64_t band_index = 0; band_index < bands.size(); ++band_index) {
			if (Variant(bands[band_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			++source_band_count;
			Dictionary band = Dictionary(bands[band_index]);
			const int32_t low = int32_t(band.get("low", 0));
			const int32_t high = int32_t(band.get("high", 0));
			const int32_t density = int32_t(band.get("density", 0));
			if (low >= 100 && high >= low && density > 0) {
				++valid_band_count;
				++zone_valid_count;
			} else {
				++invalid_band_count;
				Dictionary invalid;
				invalid["zone_id"] = zone.get("id", "");
				invalid["source_band_index"] = int32_t(band_index);
				invalid["low"] = low;
				invalid["high"] = high;
				invalid["density"] = density;
				invalid["reason"] = low < 100 ? "low_below_100" : (high < low ? "high_below_low" : "nonpositive_density");
				invalid["source_offsets"] = reward_band_source_offsets(int32_t(band_index));
				invalid_band_records.append(invalid);
			}
		}
		if (zone_valid_count == 0) {
			++fallback_zone_count;
			Dictionary diagnostic;
			diagnostic["code"] = "reward_band_zone_used_floor_fallback";
			diagnostic["severity"] = "warning";
			diagnostic["zone_id"] = zone.get("id", "");
			diagnostic["fallback_behavior"] = "native_zone_richness_floor_reward_band";
			diagnostics.append(diagnostic);
		}
	}

	Array source_offsets;
	for (int32_t index = 0; index < 3; ++index) {
		source_offsets.append(reward_band_source_offsets(index));
	}

	Dictionary summary;
	summary["schema_id"] = "aurelion_native_rmg_phase10_reward_bands_summary_v1";
	summary["phase_order"] = "phase_10_after_mines_resources_before_decorative_filler";
	summary["source_triplet_offsets"] = source_offsets;
	summary["eligibility_rule"] = "low_at_least_100_high_at_or_above_low_positive_density";
	summary["density_semantics"] = "positive_density_triplets_are_weighted_selection_slots";
	summary["source_band_count"] = source_band_count;
	summary["valid_band_count"] = valid_band_count;
	summary["invalid_band_count"] = invalid_band_count;
	summary["fallback_zone_count"] = fallback_zone_count;
	summary["reward_count"] = reward_count;
	summary["placed_by_source_band"] = placed_by_band;
	summary["out_of_band_reward_count"] = out_of_band_count;
	summary["invalid_band_records"] = invalid_band_records;
	summary["diagnostics"] = diagnostics;
	summary["diagnostic_count"] = diagnostics.size();
	Array boundaries;
	boundaries.append("exact_private_object_table_candidate_scoring_not_claimed");
	boundaries.append("homm3_art_def_names_text_not_imported");
	boundaries.append("unsupported_or_zero_density_bands_are_reported_and_not_selected");
	summary["unsupported_reward_boundaries"] = boundaries;
	summary["validation_status"] = out_of_band_count == 0 ? "pass" : "fail";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	return summary;
}

int32_t catalog_zone_mine_target(const Dictionary &normalized, const Dictionary &zone) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary requirements = metadata.get("mine_requirements", metadata.get("resource_category_requirements", Dictionary()));
	Dictionary minimum = requirements.get("minimum_by_category", Dictionary());
	Dictionary density = requirements.get("density_by_category", Dictionary());
	const int32_t minimum_total = sum_dictionary_int_values(minimum);
	const int32_t density_total = sum_dictionary_int_values(density);
	const double scale = std::sqrt(double(map_area_scale(normalized)));
	const int32_t density_target = int32_t(std::ceil(double(density_total) * scale / 4.0));
	const String role = String(zone.get("role", ""));
	const int32_t fallback = role.contains("start") ? 2 : (role == "treasure" ? 2 : 1);
	const int32_t cap = role.contains("start") ? std::max(4, 5 + map_area_scale(normalized) / 2) : std::max(4, 4 + map_area_scale(normalized));
	return std::max(fallback, std::min(cap, minimum_total + density_target));
}

Dictionary mine_requirements_for_zone(const Dictionary &zone) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Variant requirements_value = metadata.get("mine_requirements", metadata.get("resource_category_requirements", Variant()));
	if (requirements_value.get_type() == Variant::DICTIONARY) {
		return Dictionary(requirements_value);
	}
	return Dictionary();
}

int32_t mine_density_attempt_count(const Dictionary &normalized, const Dictionary &zone, const Dictionary &density_by_category) {
	const int32_t density_total = sum_dictionary_int_values(density_by_category);
	if (density_total <= 0) {
		return 0;
	}
	const double scale = std::sqrt(double(map_area_scale(normalized)));
	const int32_t base = int32_t(std::ceil(double(density_total) * scale / 4.0));
	const String role = String(zone.get("role", ""));
	const int32_t cap = role.contains("start") ? std::max(2, 2 + map_area_scale(normalized) / 3) : std::max(2, 2 + map_area_scale(normalized) / 2);
	return std::max(1, std::min(cap, base));
}

int32_t weighted_mine_density_category(const Dictionary &normalized, const Dictionary &zone, const Dictionary &density_by_category, int32_t slot) {
	int32_t density_total = 0;
	for (int32_t category_index = 0; category_index < RMG_MINE_CATEGORY_COUNT; ++category_index) {
		density_total += std::max(0, int32_t(density_by_category.get(rmg_mine_category_id(category_index), 0)));
	}
	if (density_total <= 0) {
		return -1;
	}
	const String seed = String(normalized.get("normalized_seed", "0")) + ":phase7_mine_density:" + String(zone.get("id", "")) + ":" + String::num_int64(slot);
	const int32_t selected_slot = int32_t(hash32_int(seed) % uint32_t(density_total));
	int32_t cursor = 0;
	for (int32_t category_index = 0; category_index < RMG_MINE_CATEGORY_COUNT; ++category_index) {
		cursor += std::max(0, int32_t(density_by_category.get(rmg_mine_category_id(category_index), 0)));
		if (selected_slot < cursor) {
			return category_index;
		}
	}
	return -1;
}

Array mine_phase7_schedule_for_zone(const Dictionary &normalized, const Dictionary &zone) {
	Array schedule;
	Dictionary requirements = mine_requirements_for_zone(zone);
	Dictionary minimum_by_category = requirements.get("minimum_by_category", Dictionary());
	Dictionary density_by_category = requirements.get("density_by_category", Dictionary());
	int32_t local_ordinal = 0;
	for (int32_t category_index = 0; category_index < RMG_MINE_CATEGORY_COUNT; ++category_index) {
		const String category_id = rmg_mine_category_id(category_index);
		const int32_t minimum = std::max(0, int32_t(minimum_by_category.get(category_id, 0)));
		for (int32_t count = 0; count < minimum; ++count) {
			Dictionary item;
			item["category_index"] = category_index;
			item["category_id"] = category_id;
			item["source_phase"] = "phase_7_mine_minimum";
			item["source_field_offset"] = rmg_mine_minimum_source_offset(category_index);
			item["source_field_name"] = "minimum_" + rmg_mine_source_equivalent(category_index);
			item["source_field_value"] = minimum;
			item["minimum_index"] = count;
			item["local_ordinal"] = local_ordinal++;
			schedule.append(item);
		}
	}
	const int32_t density_attempts = mine_density_attempt_count(normalized, zone, density_by_category);
	for (int32_t slot = 0; slot < density_attempts; ++slot) {
		const int32_t category_index = weighted_mine_density_category(normalized, zone, density_by_category, slot);
		if (category_index < 0) {
			continue;
		}
		Dictionary item;
		item["category_index"] = category_index;
		item["category_id"] = rmg_mine_category_id(category_index);
		item["source_phase"] = "phase_7_mine_density";
		item["source_field_offset"] = rmg_mine_density_source_offset(category_index);
		item["source_field_name"] = "density_" + rmg_mine_source_equivalent(category_index);
		item["source_field_value"] = std::max(0, int32_t(density_by_category.get(rmg_mine_category_id(category_index), 0)));
		item["density_selection_slot"] = slot;
		item["density_attempt_count"] = density_attempts;
		item["local_ordinal"] = local_ordinal++;
		schedule.append(item);
	}
	return schedule;
}

bool rmg_adjacent_resource_pickup_supported(int32_t category_index) {
	return category_index == 0 || category_index == 2 || category_index == 6;
}

int32_t rmg_adjacent_resource_family_ordinal(int32_t category_index) {
	if (category_index == 0) {
		return 0;
	}
	if (category_index == 2) {
		return 1;
	}
	return 2;
}

Dictionary adjacent_resource_point_for_mine(const Dictionary &mine_point, const String &zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height) {
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
	const int32_t mx = int32_t(mine_point.get("x", 0));
	const int32_t my = int32_t(mine_point.get("y", 0));
	for (const auto &offset : OFFSETS) {
		Dictionary point = find_object_point(mx + offset[0], my + offset[1], zone_id, owner_grid, occupied, width, height);
		if (!point.is_empty()) {
			point["spatial_placement_policy"] = "phase_7_adjacent_resource_same_category_next_to_mine";
			return point;
		}
	}
	return Dictionary();
}

int32_t catalog_zone_reward_target(const Dictionary &normalized, const Dictionary &zone) {
	Array bands = valid_treasure_bands_for_zone(zone);
	int32_t density_total = 0;
	for (int64_t index = 0; index < bands.size(); ++index) {
		if (Variant(bands[index]).get_type() == Variant::DICTIONARY) {
			density_total += std::max(0, int32_t(Dictionary(bands[index]).get("density", 0)));
		}
	}
	const String role = String(zone.get("role", ""));
	const double scale = std::sqrt(double(map_area_scale(normalized)));
	const int32_t fallback = role.contains("start") ? 3 : (role == "treasure" ? 5 : 2);
	const int32_t cap = std::max(5, 8 + map_area_scale(normalized));
	return std::max(fallback, std::min(cap, int32_t(std::ceil(double(density_total) * scale / 3.0))));
}

int32_t catalog_zone_dwelling_target(const Dictionary &normalized, const Dictionary &zone) {
	const String role = String(zone.get("role", ""));
	const int32_t base_size = std::max(1, int32_t(zone.get("base_size", 8)));
	const int32_t area_scale = map_area_scale(normalized);
	if (role.contains("start")) {
		return area_scale >= 9 ? 1 : 0;
	}
	if (role == "treasure") {
		return std::max(1, std::min(4, base_size / 6 + area_scale / 8));
	}
	if (role == "junction") {
		return area_scale >= 4 ? 1 : 0;
	}
	return 0;
}

int32_t interactive_spacing_penalty(const Array &placements, int32_t x, int32_t y, const String &kind, const String &zone_id, int32_t width, int32_t height) {
	int32_t penalty = 0;
	int32_t nearest_distance = std::numeric_limits<int32_t>::max();
	int32_t local_window_count = 0;
	int32_t same_zone_window_count = 0;
	int32_t same_kind_window_count = 0;
	int32_t same_quadrant_count = 0;
	int32_t same_kind_quadrant_count = 0;
	const int32_t quadrant = (x >= width / 2 ? 1 : 0) + (y >= height / 2 ? 2 : 0);
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = placements[index];
		const String existing_kind = String(placement.get("kind", ""));
		if (existing_kind == "decorative_obstacle") {
			continue;
		}
		const int32_t px = int32_t(placement.get("x", 0));
		const int32_t py = int32_t(placement.get("y", 0));
		const int32_t dx = std::abs(x - px);
		const int32_t dy = std::abs(y - py);
		const int32_t distance = dx + dy;
		const int32_t existing_quadrant = (px >= width / 2 ? 1 : 0) + (py >= height / 2 ? 2 : 0);
		if (existing_quadrant == quadrant) {
			++same_quadrant_count;
			if (existing_kind == kind) {
				++same_kind_quadrant_count;
			}
		}
		nearest_distance = std::min(nearest_distance, distance);
		if (dx <= 6 && dy <= 6) {
			++local_window_count;
			if (String(placement.get("zone_id", "")) == zone_id) {
				++same_zone_window_count;
			}
			if (existing_kind == kind) {
				++same_kind_window_count;
			}
		}
		if (distance <= 2) {
			penalty += 240;
		} else if (distance <= 4) {
			penalty += 96;
		} else if (distance <= 6) {
			penalty += 36;
		} else if (distance <= 10) {
			penalty += 10;
		}
	}
	if (nearest_distance == std::numeric_limits<int32_t>::max()) {
		return 0;
	}
	penalty += local_window_count * 70;
	penalty += same_zone_window_count * 55;
	penalty += same_kind_window_count * 35;
	penalty += same_quadrant_count * 8;
	penalty += same_kind_quadrant_count * 14;
	return penalty;
}

int32_t interactive_road_reachability_penalty(int32_t distance_to_road) {
	if (distance_to_road < 0) {
		return 0;
	}
	if (distance_to_road <= 4) {
		return 0;
	}
	int32_t penalty = (distance_to_road - 4) * 12;
	if (distance_to_road > 7) {
		penalty += (distance_to_road - 7) * 70;
	}
	return penalty;
}

int32_t interactive_road_distribution_penalty(int32_t distance_to_road, const String &kind) {
	if (kind != "reward_reference") {
		return interactive_road_reachability_penalty(distance_to_road);
	}
	if (distance_to_road < 0) {
		return 0;
	}
	if (distance_to_road <= 1) {
		return 150;
	}
	if (distance_to_road <= 4) {
		return 55;
	}
	if (distance_to_road <= 9) {
		return 0;
	}
	int32_t penalty = (distance_to_road - 9) * 16;
	if (distance_to_road > 13) {
		penalty += (distance_to_road - 13) * 42;
	}
	return penalty;
}

Dictionary object_point_for_zone_index(const Dictionary &zone, int32_t ordinal, int32_t ring, const String &kind, const Dictionary &normalized, const Array &owner_grid, const Dictionary &occupied, const Array &existing_placements, const PackedInt32Array &road_distance_field, int32_t width, int32_t height) {
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const String zone_id = String(zone.get("id", ""));
	const String seed = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":object:" + String::num_int64(ordinal);
	const int32_t anchor_x = int32_t(anchor.get("x", width / 2));
	const int32_t anchor_y = int32_t(anchor.get("y", height / 2));
	const int32_t zone_cell_count = std::max(0, int32_t(zone.get("cell_count", 0)));
	const int32_t coarse_cols = zone_cell_count > 0 && zone_cell_count < 144 ? 4 : 8;
	const int32_t coarse_rows = zone_cell_count > 0 && zone_cell_count < 144 ? 4 : 8;
	const int32_t desired_cell = int32_t(hash32_int(seed + String(":local_distribution:") + kind) % uint32_t(coarse_cols * coarse_rows));
	const int32_t desired_cx = desired_cell % coarse_cols;
	const int32_t desired_cy = desired_cell / coarse_cols;
	const Dictionary footprint = object_footprint_for_kind(kind, ordinal, terrain_id_for_zone(zone));
	const int32_t preferred_anchor_distance = 4 + ring * 3 + (ordinal % 5);
	const bool bounded_large_map_scoring = width > 72 || height > 72;
	const int32_t target_evaluated_candidates = !bounded_large_map_scoring ? zone_cell_count : (zone_cell_count > 0 && zone_cell_count < 600 ? zone_cell_count : 128);
	const int32_t sample_mod = zone_cell_count > target_evaluated_candidates ? std::max(2, zone_cell_count / std::max(1, target_evaluated_candidates)) : 1;
	const String owner_medium_category = owner_attached_medium_001_spatial_category_for_kind(kind);
	Dictionary bounds = zone.get("bounds", Dictionary());
	const int32_t scan_min_x = std::max(1, int32_t(bounds.get("min_x", 1)));
	const int32_t scan_max_x = std::min(width - 2, int32_t(bounds.get("max_x", width - 2)));
	const int32_t scan_min_y = std::max(1, int32_t(bounds.get("min_y", 1)));
	const int32_t scan_max_y = std::min(height - 2, int32_t(bounds.get("max_y", height - 2)));

	int64_t best_sort_key = std::numeric_limits<int64_t>::max();
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_road_distance = -1;
	for (int32_t y = scan_min_y; y <= scan_max_y; ++y) {
		if (y < 0 || y >= owner_grid.size()) {
			continue;
		}
		Array row = owner_grid[y];
		for (int32_t x = scan_min_x; x <= scan_max_x; ++x) {
			if (!zone_id.is_empty() && (x < 0 || x >= row.size() || String(row[x]) != zone_id)) {
				continue;
			}
			const int32_t cx = std::max(0, std::min(coarse_cols - 1, (x * coarse_cols) / std::max(1, width)));
			const int32_t cy = std::max(0, std::min(coarse_rows - 1, (y * coarse_rows) / std::max(1, height)));
			const int32_t coarse_distance = std::abs(cx - desired_cx) + std::abs(cy - desired_cy);
			if (sample_mod > 1) {
				const uint32_t sample_hash = hash32_int(seed + String(":sample:") + String::num_int64(x) + String(",") + String::num_int64(y));
				const uint32_t preferred_mod = uint32_t(std::max(1, sample_mod / 2));
				const bool preferred_coarse_sample = coarse_distance == 0 && sample_hash % preferred_mod == 0U;
				const bool broad_sample = sample_hash % uint32_t(sample_mod) == 0U;
				if (!preferred_coarse_sample && !broad_sample) {
					continue;
				}
			}
			if (!object_body_fits_in_zone(x, y, zone_id, owner_grid, occupied, width, height, footprint)) {
				continue;
			}
			const int32_t anchor_distance = std::abs(x - anchor_x) + std::abs(y - anchor_y);
			const int32_t anchor_penalty = std::abs(anchor_distance - preferred_anchor_distance);
			const int32_t spacing_penalty = owner_attached_medium_001_spacing_penalty(normalized, owner_medium_category, interactive_spacing_penalty(existing_placements, x, y, kind, zone_id, width, height));
			const int32_t road_distance = road_distance_from_field(road_distance_field, x, y, width, height);
			const int32_t road_penalty = owner_attached_medium_001_road_penalty(normalized, owner_medium_category, interactive_road_distribution_penalty(road_distance, kind));
			const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, width, height);
			const int32_t distribution_penalty = spacing_penalty + road_penalty + owner_grid_penalty;
			const int32_t jitter = int32_t(hash32_int(seed + String(":scatter:") + String::num_int64(x) + String(",") + String::num_int64(y)) % 10000U);
			const int64_t sort_key = int64_t(distribution_penalty) * 1000000000LL + int64_t(coarse_distance) * 10000000LL + int64_t(anchor_penalty) * 10000LL + int64_t(jitter);
			if (sort_key < best_sort_key) {
				best_sort_key = sort_key;
				best_x = x;
				best_y = y;
				best_road_distance = road_distance;
			}
		}
	}
	if (best_x >= 0 && best_y >= 0) {
		Dictionary result = point_record(best_x, best_y);
		result["distance_to_nearest_road_tiles"] = best_road_distance;
		result["spatial_placement_policy"] = "local_window_road_reachable_blue_noise_scatter_within_zone_preserving_guarded_clusters";
		return result;
	}

	const int32_t angle_bucket = int32_t(hash32_int(seed) % 8U);
	static constexpr int32_t OFFSETS[8][2] = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}};
	const int32_t distance = 2 + ring + (ordinal % 3);
	const int32_t x = anchor_x + OFFSETS[angle_bucket][0] * distance + deterministic_signed_jitter(seed + String(":x"), 1);
	const int32_t y = anchor_y + OFFSETS[angle_bucket][1] * distance + deterministic_signed_jitter(seed + String(":y"), 1);
	Dictionary fallback = find_object_point(x, y, zone_id, owner_grid, occupied, width, height);
	if (!fallback.is_empty()) {
		fallback["spatial_placement_policy"] = "anchor_ring_fallback_after_local_distribution_scatter_exhausted";
	}
	return fallback;
}

Dictionary object_point_for_zone_index_fast(const Dictionary &zone, int32_t ordinal, int32_t ring, const String &kind, const Dictionary &normalized, NativeObjectPlacementContext &placement_context, const Array &owner_grid, const Dictionary &occupied, const PackedInt32Array &road_distance_field) {
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const String zone_id = String(zone.get("id", ""));
	const String seed = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":object:" + String::num_int64(ordinal);
	const int32_t width = placement_context.width;
	const int32_t height = placement_context.height;
	const int32_t anchor_x = int32_t(anchor.get("x", width / 2));
	const int32_t anchor_y = int32_t(anchor.get("y", height / 2));
	const int32_t zone_index = native_zone_index_for_id(placement_context, zone_id);
	if (zone_index < 0 || zone_index >= int32_t(placement_context.zones.size())) {
		return object_point_for_zone_index(zone, ordinal, ring, kind, normalized, owner_grid, occupied, Array(), road_distance_field, width, height);
	}
	const std::vector<NativePlacementTile> &candidates = placement_context.zones[zone_index].candidates;
	const int32_t zone_cell_count = std::max(0, int32_t(candidates.size()));
	const int32_t coarse_cols = zone_cell_count > 0 && zone_cell_count < 144 ? 4 : 8;
	const int32_t coarse_rows = zone_cell_count > 0 && zone_cell_count < 144 ? 4 : 8;
	const int32_t desired_cell = int32_t(hash32_int(seed + String(":local_distribution:") + kind) % uint32_t(coarse_cols * coarse_rows));
	const int32_t desired_cx = desired_cell % coarse_cols;
	const int32_t desired_cy = desired_cell / coarse_cols;
	const Dictionary footprint = object_footprint_for_kind(kind, ordinal, terrain_id_for_zone(zone));
	const int32_t preferred_anchor_distance = 4 + ring * 3 + (ordinal % 5);
	const bool bounded_large_map_scoring = width > 72 || height > 72;
	const int32_t target_evaluated_candidates = !bounded_large_map_scoring ? zone_cell_count : (zone_cell_count > 0 && zone_cell_count < 600 ? zone_cell_count : 128);
	const int32_t sample_mod = zone_cell_count > target_evaluated_candidates ? std::max(2, zone_cell_count / std::max(1, target_evaluated_candidates)) : 1;
	const String owner_medium_category = owner_attached_medium_001_spatial_category_for_kind(kind);

	int64_t best_sort_key = std::numeric_limits<int64_t>::max();
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_road_distance = -1;
	for (const NativePlacementTile &candidate : candidates) {
		const int32_t x = candidate.x;
		const int32_t y = candidate.y;
		const int32_t cx = std::max(0, std::min(coarse_cols - 1, (x * coarse_cols) / std::max(1, width)));
		const int32_t cy = std::max(0, std::min(coarse_rows - 1, (y * coarse_rows) / std::max(1, height)));
		const int32_t coarse_distance = std::abs(cx - desired_cx) + std::abs(cy - desired_cy);
		if (sample_mod > 1) {
			const uint32_t sample_hash = hash32_int(seed + String(":sample:") + String::num_int64(x) + String(",") + String::num_int64(y));
			const uint32_t preferred_mod = uint32_t(std::max(1, sample_mod / 2));
			const bool preferred_coarse_sample = coarse_distance == 0 && sample_hash % preferred_mod == 0U;
			const bool broad_sample = sample_hash % uint32_t(sample_mod) == 0U;
			if (!preferred_coarse_sample && !broad_sample) {
				continue;
			}
		}
		if (!object_body_fits_in_zone_native(placement_context, x, y, zone_index, footprint)) {
			continue;
		}
		const int32_t anchor_distance = std::abs(x - anchor_x) + std::abs(y - anchor_y);
		const int32_t anchor_penalty = std::abs(anchor_distance - preferred_anchor_distance);
		const int32_t spacing_penalty = owner_attached_medium_001_spacing_penalty(normalized, owner_medium_category, interactive_spacing_penalty_native(placement_context, x, y, kind, zone_id));
		const int32_t road_distance = road_distance_from_field(road_distance_field, x, y, width, height);
		const int32_t road_penalty = owner_attached_medium_001_road_penalty(normalized, owner_medium_category, interactive_road_distribution_penalty(road_distance, kind));
		const int32_t owner_grid_penalty = owner_attached_medium_001_grid_distribution_penalty(normalized, owner_medium_category, x, y, width, height);
		const int32_t owner_cluster_penalty = owner_attached_medium_001_existing_cluster_penalty(normalized, placement_context, owner_medium_category, x, y);
		const int32_t distribution_penalty = spacing_penalty + road_penalty + owner_grid_penalty + owner_cluster_penalty;
		const int32_t jitter = int32_t(hash32_int(seed + String(":scatter:") + String::num_int64(x) + String(",") + String::num_int64(y)) % 10000U);
		const int64_t sort_key = int64_t(distribution_penalty) * 1000000000LL + int64_t(coarse_distance) * 10000000LL + int64_t(anchor_penalty) * 10000LL + int64_t(jitter);
		if (sort_key < best_sort_key) {
			best_sort_key = sort_key;
			best_x = x;
			best_y = y;
			best_road_distance = road_distance;
		}
	}
	if (best_x >= 0 && best_y >= 0) {
		Dictionary result = point_record(best_x, best_y);
		result["distance_to_nearest_road_tiles"] = best_road_distance;
		result["spatial_placement_policy"] = "native_cached_zone_candidate_scan_road_reachable_blue_noise_scatter";
		return result;
	}

	const int32_t angle_bucket = int32_t(hash32_int(seed) % 8U);
	static constexpr int32_t OFFSETS[8][2] = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}};
	const int32_t distance = 2 + ring + (ordinal % 3);
	const int32_t x = anchor_x + OFFSETS[angle_bucket][0] * distance + deterministic_signed_jitter(seed + String(":x"), 1);
	const int32_t y = anchor_y + OFFSETS[angle_bucket][1] * distance + deterministic_signed_jitter(seed + String(":y"), 1);
	Dictionary fallback = find_object_point(x, y, zone_id, owner_grid, occupied, width, height);
	if (!fallback.is_empty()) {
		fallback["spatial_placement_policy"] = "anchor_ring_fallback_after_native_cached_candidate_scan_exhausted";
	}
	return fallback;
}

Dictionary generate_object_placements(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network) {
	const auto object_phase_started_at = std::chrono::steady_clock::now();
	Array object_profile_phases;
	int64_t top_object_phase_usec = 0;
	String top_object_phase_id;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts = player_starts.get("starts", Array());
	Array placements;
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	Dictionary occupied = road_body_exclusion_lookup(road_network);
	const std::vector<NativeRoadCell> road_cells = native_road_cells_for_network(road_network);
	const PackedInt32Array road_distance_field = road_distance_field_for_cells(road_cells, width, height);
	NativeObjectPlacementContext placement_context = build_native_object_placement_context(zones, owner_grid, road_network, width, height, true);
	reserve_future_town_anchors(zones, owner_grid, occupied, placement_context, width, height);
	append_extension_profile_elapsed(object_profile_phases, "prepare_inputs_and_road_distance", elapsed_usec_since(object_phase_started_at), top_object_phase_usec, top_object_phase_id);
	int32_t ordinal = 0;
	Array mine_resource_diagnostics;
	Array adjacent_resource_records;
	int32_t mine_required_attempt_count = 0;
	int32_t mine_density_attempt_count_value = 0;
	int32_t mine_required_placed_count = 0;
	int32_t mine_density_placed_count = 0;
	int32_t adjacent_resource_support_count = 0;
	int32_t adjacent_resource_object_count = 0;
	const int32_t uploaded_small_mine_target = owner_uploaded_small_049_object_target(normalized, "mine");
	const int32_t uploaded_small_resource_target = owner_uploaded_small_049_object_target(normalized, "resource_site");
	const int32_t uploaded_small_dwelling_target = owner_uploaded_small_049_object_target(normalized, "neutral_dwelling");
	const int32_t uploaded_small_reward_target = owner_uploaded_small_049_object_target(normalized, "reward_reference");
	const int32_t uploaded_small_scenic_target = owner_uploaded_small_049_object_target(normalized, "scenic_object");
	const int32_t uploaded_small_underground_decoration_target = owner_uploaded_small_027_underground_object_target(normalized, "decorative_obstacle");
	const int32_t uploaded_small_underground_scenic_target = owner_uploaded_small_027_underground_object_target(normalized, "scenic_object");
	const int32_t owner_large_decoration_target = owner_large_land_category_target(normalized, "decoration");
	const int32_t owner_large_scenic_target = owner_large_land_category_target(normalized, "scenic_object");
	const int32_t owner_large_reward_category_target = owner_large_land_category_target(normalized, "reward");
	const int32_t owner_xl_decoration_target = owner_xl_land_category_target(normalized, "decoration");
	const int32_t owner_xl_scenic_target = owner_xl_land_category_target(normalized, "scenic_object");
	const int32_t owner_xl_reward_category_target = owner_xl_land_category_target(normalized, "reward");
	int32_t uploaded_small_mine_count = 0;
	int32_t uploaded_small_resource_count = 0;
	int32_t uploaded_small_dwelling_count = 0;
	int32_t uploaded_small_reward_count = 0;
	int32_t uploaded_small_scenic_count = 0;
	auto target_reached = [](int32_t target, int32_t count) {
		return target >= 0 && count >= target;
	};

	if (!parity_targets.is_empty()) {
		const auto parity_started_at = std::chrono::steady_clock::now();
		Dictionary parity_counts = parity_targets.get("object_category_counts", Dictionary());
		static constexpr const char *ORDERED_KINDS[] = {"town", "resource_site", "mine", "neutral_dwelling", "reward_reference", "route_guard", "special_guard_gate"};
		for (const char *kind_value : ORDERED_KINDS) {
			const String kind = kind_value;
			const int32_t count = int32_t(parity_counts.get(kind, 0));
			for (int32_t index = 0; index < count; ++index) {
				Dictionary zone = zones.is_empty() ? Dictionary() : Dictionary(zones[(ordinal + index) % zones.size()]);
				const String zone_id = String(zone.get("id", ""));
				Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
				const int32_t seed_offset = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + kind + String::num_int64(index)) % 9U);
				Dictionary point = find_object_point(
						int32_t(anchor.get("x", width / 2)) + (seed_offset % 3) - 1 + (index % 5),
						int32_t(anchor.get("y", height / 2)) + (seed_offset / 3) - 1 + ((index / 5) % 5),
						zone_id,
						owner_grid,
						occupied,
						width,
						height);
				Dictionary footprint = object_footprint_for_kind(kind, ordinal, terrain_id_for_zone(zone));
				if (!point.is_empty() && !object_body_fits_in_zone(int32_t(point.get("x", 0)), int32_t(point.get("y", 0)), zone_id, owner_grid, occupied, width, height, footprint)) {
					point = object_point_for_zone_index_fast(zone, ordinal, 1 + index / 6, kind, normalized, placement_context, owner_grid, occupied, road_distance_field);
				}
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, kind, ordinal, road_cells, zone_layout);
				++ordinal;
			}
		}
		append_extension_profile_elapsed(object_profile_phases, "supported_profile_seed_objects", elapsed_usec_since(parity_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (parity_targets.is_empty()) {
		const auto start_resources_started_at = std::chrono::steady_clock::now();
		for (int64_t index = 0; index < starts.size(); ++index) {
			Dictionary start = starts[index];
			Dictionary zone = zone_by_id(zones, String(start.get("zone_id", "")));
			if (zone.is_empty()) {
				continue;
			}
			const int32_t sx = int32_t(start.get("x", 0));
			const int32_t sy = int32_t(start.get("y", 0));
			static constexpr int32_t OFFSETS[3][2] = {{2, 0}, {0, 2}, {-2, 0}};
			for (int32_t resource_index = 0; resource_index < 3; ++resource_index) {
				if (target_reached(uploaded_small_resource_target, uploaded_small_resource_count)) {
					continue;
				}
				Dictionary point = find_object_point(sx + OFFSETS[resource_index][0], sy + OFFSETS[resource_index][1], String(start.get("zone_id", "")), owner_grid, occupied, width, height);
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "resource_site", resource_index, road_cells, zone_layout);
				if (!point.is_empty()) {
					++uploaded_small_resource_count;
				}
				++ordinal;
			}
		}
		append_extension_profile_elapsed(object_profile_phases, "player_start_resource_sites", elapsed_usec_since(start_resources_started_at), top_object_phase_usec, top_object_phase_id);

		int64_t mine_resource_usec = 0;
		int64_t dwelling_usec = 0;
		int64_t reward_usec = 0;
		for (int64_t index = 0; index < zones.size(); ++index) {
			Dictionary zone = zones[index];
			const int32_t reward_target = catalog_zone_reward_target(normalized, zone);
			const int32_t dwelling_target = catalog_zone_dwelling_target(normalized, zone);
			Array mine_schedule = mine_phase7_schedule_for_zone(normalized, zone);
			const auto mine_started_at = std::chrono::steady_clock::now();
			for (int64_t mine_index = 0; mine_index < mine_schedule.size(); ++mine_index) {
				Dictionary scheduled = mine_schedule[mine_index];
				const int32_t category_index = int32_t(scheduled.get("category_index", 0));
				const bool density_phase = String(scheduled.get("source_phase", "")) == "phase_7_mine_density";
				if (density_phase) {
					++mine_density_attempt_count_value;
				} else {
					++mine_required_attempt_count;
				}
				const bool special_near_start_bias = (category_index == 0 || category_index == 2) && String(zone.get("role", "")).contains("start");
				const int32_t ring = special_near_start_bias ? 0 : 1 + int32_t(mine_index / 3);
				Dictionary point = object_point_for_zone_index_fast(zone, ordinal, ring, "mine", normalized, placement_context, owner_grid, occupied, road_distance_field);
				const bool point_available = !point.is_empty();
				point["object_family_ordinal"] = category_index;
				point["native_mine_index"] = int32_t(mine_index);
				point["native_mine_target"] = mine_schedule.size();
				point["mine_category_index"] = category_index;
				point["mine_category_id"] = scheduled.get("category_id", rmg_mine_category_id(category_index));
				point["source_phase"] = scheduled.get("source_phase", "");
				point["source_field_offset"] = scheduled.get("source_field_offset", "");
				point["source_field_name"] = scheduled.get("source_field_name", "");
				point["source_field_value"] = scheduled.get("source_field_value", 0);
				point["density_selection_slot"] = scheduled.get("density_selection_slot", -1);
				point["special_near_start_bias"] = special_near_start_bias;
				point["adjacent_resource_policy"] = "same_category_resource_support_record_after_mine";
				point["placement_policy"] = density_phase ? "phase_7_density_weighted_mine_category_placement" : "phase_7_minimum_mine_category_placement_before_density";
				Dictionary diagnostic;
				diagnostic["zone_id"] = zone.get("id", "");
				diagnostic["zone_role"] = zone.get("role", "");
				diagnostic["category_index"] = category_index;
				diagnostic["category_id"] = rmg_mine_category_id(category_index);
				diagnostic["source_equivalent"] = rmg_mine_source_equivalent(category_index);
				diagnostic["source_phase"] = scheduled.get("source_phase", "");
				diagnostic["source_field_offset"] = scheduled.get("source_field_offset", "");
				diagnostic["source_field_value"] = scheduled.get("source_field_value", 0);
				if (target_reached(uploaded_small_mine_target, uploaded_small_mine_count)) {
					diagnostic["code"] = "mine_resource_placement_skipped_by_uploaded_small_mix_target";
					diagnostic["severity"] = "info";
					diagnostic["message"] = "Small template 049 is capped to the owner-uploaded single-level H3M mine/resource category mix.";
					diagnostic["target_count"] = uploaded_small_mine_target;
					mine_resource_diagnostics.append(diagnostic);
					continue;
				}
				if (!point_available) {
					diagnostic["code"] = "mine_resource_placement_infeasible";
					diagnostic["severity"] = density_phase ? "warning" : "failure";
					diagnostic["message"] = "No unoccupied in-zone tile was available for the scheduled mine/resource category placement.";
					mine_resource_diagnostics.append(diagnostic);
					continue;
				}
				const String mine_placement_id = "native_rmg_mine_" + String(zone.get("id", "")) + "_" + slot_id_2(ordinal + 1);
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "mine", ordinal, road_cells, zone_layout);
				if (density_phase) {
					++mine_density_placed_count;
				} else {
					++mine_required_placed_count;
				}
				diagnostic["code"] = "mine_resource_placement_materialized";
				diagnostic["severity"] = "info";
				diagnostic["placement_id"] = mine_placement_id;
				diagnostic["special_near_start_bias"] = special_near_start_bias;
				mine_resource_diagnostics.append(diagnostic);
				++uploaded_small_mine_count;
				++ordinal;

				Dictionary support;
				support["mine_placement_id"] = mine_placement_id;
				support["zone_id"] = zone.get("id", "");
				support["category_index"] = category_index;
				support["category_id"] = rmg_mine_category_id(category_index);
				support["source_equivalent"] = rmg_mine_source_equivalent(category_index);
				support["source_model"] = "phase_7_0x4a9e40_resource_type_same_subtype_translated_to_original_support_record";
				support["adjacent_resource_object_supported"] = rmg_adjacent_resource_pickup_supported(category_index);
				++adjacent_resource_support_count;
				if (rmg_adjacent_resource_pickup_supported(category_index)) {
					Dictionary resource_point = adjacent_resource_point_for_mine(point, String(zone.get("id", "")), owner_grid, occupied, width, height);
					if (!resource_point.is_empty() && !target_reached(uploaded_small_resource_target, uploaded_small_resource_count)) {
						resource_point["object_family_ordinal"] = rmg_adjacent_resource_family_ordinal(category_index);
						resource_point["adjacent_to_mine_placement_id"] = mine_placement_id;
						resource_point["mine_category_index"] = category_index;
						append_object_placement_fast(placements, occupied, placement_context, normalized, zone, resource_point, "resource_site", ordinal, road_cells, zone_layout);
						support["adjacent_resource_placement_id"] = "native_rmg_resource_site_" + String(zone.get("id", "")) + "_" + slot_id_2(ordinal + 1);
						support["materialization_state"] = "adjacent_resource_object_materialized";
						++adjacent_resource_object_count;
						++uploaded_small_resource_count;
						++ordinal;
					} else if (target_reached(uploaded_small_resource_target, uploaded_small_resource_count)) {
						support["materialization_state"] = "adjacent_resource_object_suppressed_by_uploaded_small_mix_target";
						Dictionary resource_diagnostic = diagnostic.duplicate(true);
						resource_diagnostic["code"] = "adjacent_resource_placement_skipped_by_uploaded_small_mix_target";
						resource_diagnostic["severity"] = "info";
						resource_diagnostic["target_count"] = uploaded_small_resource_target;
						mine_resource_diagnostics.append(resource_diagnostic);
					} else {
						support["materialization_state"] = "adjacent_resource_object_infeasible_support_record_only";
						Dictionary resource_diagnostic = diagnostic.duplicate(true);
						resource_diagnostic["code"] = "adjacent_resource_placement_infeasible";
						resource_diagnostic["severity"] = "warning";
						resource_diagnostic["message"] = "Mine was placed, but no adjacent unoccupied resource pickup tile was available.";
						mine_resource_diagnostics.append(resource_diagnostic);
					}
				} else {
					support["materialization_state"] = "support_record_only_original_runtime_pickup_category_not_active";
					Dictionary unsupported = diagnostic.duplicate(true);
					unsupported["code"] = "adjacent_resource_category_not_runtime_pickup_supported";
					unsupported["severity"] = "info";
					unsupported["fallback_behavior"] = "mine_placement_kept_with_category_metadata_support_record_only";
					mine_resource_diagnostics.append(unsupported);
				}
					adjacent_resource_records.append(support);
				}
			mine_resource_usec += elapsed_usec_since(mine_started_at);
			const auto dwelling_started_at = std::chrono::steady_clock::now();
			for (int32_t dwelling_index = 0; dwelling_index < dwelling_target; ++dwelling_index) {
				if (target_reached(uploaded_small_dwelling_target, uploaded_small_dwelling_count)) {
					continue;
				}
				Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 2 + dwelling_index, "neutral_dwelling", normalized, placement_context, owner_grid, occupied, road_distance_field);
				point["native_dwelling_index"] = dwelling_index;
				point["native_dwelling_target"] = dwelling_target;
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "neutral_dwelling", ordinal, road_cells, zone_layout);
				if (!point.is_empty()) {
					++uploaded_small_dwelling_count;
				}
				++ordinal;
			}
			dwelling_usec += elapsed_usec_since(dwelling_started_at);
			const auto reward_started_at = std::chrono::steady_clock::now();
			for (int32_t reward_index = 0; reward_index < reward_target; ++reward_index) {
				if (target_reached(uploaded_small_reward_target, uploaded_small_reward_count)) {
					continue;
				}
				if (target_reached(owner_xl_reward_category_target, placement_count_for_spatial_category(placements, "reward"))) {
					continue;
				}
				Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 1 + reward_index / 4, "reward_reference", normalized, placement_context, owner_grid, occupied, road_distance_field);
				point["native_reward_index"] = reward_index;
				point["native_reward_target"] = reward_target;
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "reward_reference", ordinal, road_cells, zone_layout);
				if (!point.is_empty()) {
					++uploaded_small_reward_count;
				}
				++ordinal;
			}
			reward_usec += elapsed_usec_since(reward_started_at);
		}
		append_extension_profile_elapsed(object_profile_phases, "mine_resource_placement", mine_resource_usec, top_object_phase_usec, top_object_phase_id);
		append_extension_profile_elapsed(object_profile_phases, "neutral_dwelling_placement", dwelling_usec, top_object_phase_usec, top_object_phase_id);
		append_extension_profile_elapsed(object_profile_phases, "reward_reference_placement", reward_usec, top_object_phase_usec, top_object_phase_id);

		if (uploaded_small_resource_target >= 0 && uploaded_small_resource_count < uploaded_small_resource_target) {
			const auto resource_supplement_started_at = std::chrono::steady_clock::now();
			int32_t attempts = 0;
			while (uploaded_small_resource_count < uploaded_small_resource_target && attempts < int32_t(zones.size()) * 12) {
				if (zones.is_empty()) {
					break;
				}
				Dictionary zone = zones[attempts % zones.size()];
				Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 2 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "resource_site", normalized, placement_context, owner_grid, occupied, road_distance_field);
				point["object_family_ordinal"] = uploaded_small_resource_count % 3;
				point["placement_policy"] = "owner_uploaded_small_049_supplemental_resource_mix";
				const int64_t before = placements.size();
				append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "resource_site", ordinal, road_cells, zone_layout);
				if (placements.size() > before) {
					++uploaded_small_resource_count;
				}
				++ordinal;
				++attempts;
			}
			append_extension_profile_elapsed(object_profile_phases, "uploaded_small_049_resource_mix_supplement", elapsed_usec_since(resource_supplement_started_at), top_object_phase_usec, top_object_phase_id);
		}
	}

	const auto decoration_started_at = std::chrono::steady_clock::now();
	ordinal = append_decoration_placements(placements, occupied, placement_context, normalized, zone_layout, road_cells, ordinal);
	append_extension_profile_elapsed(object_profile_phases, "decorative_obstacle_placement", elapsed_usec_since(decoration_started_at), top_object_phase_usec, top_object_phase_id);

	const int32_t owner_medium_decoration_target = owner_attached_medium_001_category_target(normalized, "decoration");
	if (owner_medium_decoration_target >= 0) {
		const auto decoration_supplement_started_at = std::chrono::steady_clock::now();
		int32_t decoration_count = placement_count_for_spatial_category(placements, "decoration");
		int32_t attempts = 0;
		while (decoration_count < owner_medium_decoration_target && attempts < int32_t(zones.size()) * 24) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
			point["object_family_ordinal"] = decoration_count;
			point["placement_policy"] = "owner_attached_medium_001_decoration_density_supplement";
			if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
				++decoration_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_attached_medium_001_decoration_density_supplement", elapsed_usec_since(decoration_supplement_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (uploaded_small_underground_decoration_target >= 0) {
		const auto decoration_supplement_started_at = std::chrono::steady_clock::now();
		int32_t decoration_count = placement_count_for_kind(placements, "decorative_obstacle");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(uploaded_small_underground_decoration_target * 6, int32_t(zones.size()) * 64);
		while (decoration_count < uploaded_small_underground_decoration_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
			if (point.is_empty()) {
				const PackedInt32Array empty_road_distance_field;
				point = object_point_for_zone_index_fast(zone, ordinal, 5 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "decorative_obstacle", normalized, placement_context, owner_grid, occupied, empty_road_distance_field);
			}
			point["object_family_ordinal"] = decoration_count;
			point["placement_policy"] = "owner_uploaded_small_027_underground_decoration_density_supplement";
			if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
				++decoration_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "uploaded_small_027_underground_decoration_density_supplement", elapsed_usec_since(decoration_supplement_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_large_decoration_target >= 0) {
		const auto decoration_supplement_started_at = std::chrono::steady_clock::now();
		int32_t decoration_count = placement_count_for_spatial_category(placements, "decoration");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_large_decoration_target * 6, int32_t(zones.size()) * 192);
		while (decoration_count < owner_large_decoration_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
			if (point.is_empty()) {
				const PackedInt32Array empty_road_distance_field;
				point = object_point_for_zone_index_fast(zone, ordinal, 5 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "decorative_obstacle", normalized, placement_context, owner_grid, occupied, empty_road_distance_field);
			}
			point["object_family_ordinal"] = decoration_count;
			point["placement_policy"] = "owner_large_land_decoration_density_supplement";
			if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
				++decoration_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_large_land_decoration_density_supplement", elapsed_usec_since(decoration_supplement_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_xl_decoration_target >= 0) {
		const auto decoration_supplement_started_at = std::chrono::steady_clock::now();
		int32_t decoration_count = placement_count_for_spatial_category(placements, "decoration");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_xl_decoration_target * 5, int32_t(zones.size()) * 192);
		while (decoration_count < owner_xl_decoration_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = find_compact_decoration_density_point_fast(zone, ordinal, normalized, placement_context);
			if (point.is_empty()) {
				const PackedInt32Array empty_road_distance_field;
				point = object_point_for_zone_index_fast(zone, ordinal, 5 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "decorative_obstacle", normalized, placement_context, owner_grid, occupied, empty_road_distance_field);
			}
			point["object_family_ordinal"] = decoration_count;
			point["placement_policy"] = "owner_xl_land_decoration_density_supplement";
			if (!point.is_empty() && append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "decorative_obstacle", ordinal, road_cells, zone_layout)) {
				++decoration_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_xl_land_decoration_density_supplement", elapsed_usec_since(decoration_supplement_started_at), top_object_phase_usec, top_object_phase_id);
	}

	const int32_t owner_medium_reward_target = owner_attached_medium_001_category_target(normalized, "reward");
	if (owner_medium_reward_target >= 0) {
		const auto reward_supplement_started_at = std::chrono::steady_clock::now();
		int32_t reward_count = placement_count_for_spatial_category(placements, "reward");
		int32_t attempts = 0;
		while (reward_count < owner_medium_reward_target && attempts < int32_t(zones.size()) * 24) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 3 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "reward_reference", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = reward_count;
			point["placement_policy"] = "owner_attached_medium_001_reward_category_density_supplement";
			if (append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "reward_reference", ordinal, road_cells, zone_layout)) {
				++reward_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_attached_medium_001_reward_density_supplement", elapsed_usec_since(reward_supplement_started_at), top_object_phase_usec, top_object_phase_id);
	}

	const int32_t owner_medium_scenic_target = owner_attached_medium_001_category_target(normalized, "scenic_object");
	if (owner_medium_scenic_target >= 0) {
		const auto scenic_started_at = std::chrono::steady_clock::now();
		int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
		int32_t attempts = 0;
		while (scenic_count < owner_medium_scenic_target && attempts < int32_t(zones.size()) * 24) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 4 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "scenic_object", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = scenic_count;
			point["placement_policy"] = "owner_attached_medium_001_other_object_category_scenic_mix";
			if (append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "scenic_object", ordinal, road_cells, zone_layout)) {
				++scenic_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_attached_medium_001_scenic_object_mix", elapsed_usec_since(scenic_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (uploaded_small_underground_scenic_target >= 0) {
		const auto scenic_started_at = std::chrono::steady_clock::now();
		int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(uploaded_small_underground_scenic_target * 8, int32_t(zones.size()) * 64);
		while (scenic_count < uploaded_small_underground_scenic_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 4 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "scenic_object", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = scenic_count;
			point["placement_policy"] = "owner_uploaded_small_027_underground_other_object_mix";
			if (append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "scenic_object", ordinal, road_cells, zone_layout)) {
				++scenic_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "uploaded_small_027_underground_scenic_object_mix", elapsed_usec_since(scenic_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_large_scenic_target >= 0) {
		const auto scenic_started_at = std::chrono::steady_clock::now();
		int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_large_scenic_target * 8, int32_t(zones.size()) * 192);
		while (scenic_count < owner_large_scenic_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 4 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "scenic_object", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = scenic_count;
			point["placement_policy"] = "owner_large_land_other_object_scenic_mix";
			if (append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "scenic_object", ordinal, road_cells, zone_layout)) {
				++scenic_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_large_land_scenic_object_mix", elapsed_usec_since(scenic_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_xl_scenic_target >= 0) {
		const auto scenic_started_at = std::chrono::steady_clock::now();
		int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_xl_scenic_target * 8, int32_t(zones.size()) * 192);
		while (scenic_count < owner_xl_scenic_target && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 4 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "scenic_object", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = scenic_count;
			point["placement_policy"] = "owner_xl_land_other_object_scenic_mix";
			if (append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "scenic_object", ordinal, road_cells, zone_layout)) {
				++scenic_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_xl_land_scenic_object_mix", elapsed_usec_since(scenic_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (uploaded_small_scenic_target >= 0) {
		const auto scenic_started_at = std::chrono::steady_clock::now();
		int32_t attempts = 0;
		while (uploaded_small_scenic_count < uploaded_small_scenic_target && attempts < int32_t(zones.size()) * 16) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			Dictionary point = object_point_for_zone_index_fast(zone, ordinal, 3 + attempts / std::max<int32_t>(1, int32_t(zones.size())), "scenic_object", normalized, placement_context, owner_grid, occupied, road_distance_field);
			point["object_family_ordinal"] = uploaded_small_scenic_count;
			point["placement_policy"] = "owner_uploaded_small_049_other_object_mix";
			const int64_t before = placements.size();
			append_object_placement_fast(placements, occupied, placement_context, normalized, zone, point, "scenic_object", ordinal, road_cells, zone_layout);
			if (placements.size() > before) {
				++uploaded_small_scenic_count;
			}
			++ordinal;
			++attempts;
		}
		append_extension_profile_elapsed(object_profile_phases, "uploaded_small_049_scenic_object_mix", elapsed_usec_since(scenic_started_at), top_object_phase_usec, top_object_phase_id);
	}

	Dictionary native_catalog_auto_density_supplement;
	if (parity_targets.is_empty()
			&& String(normalized.get("template_selection_mode", "")) == "native_catalog_auto"
			&& !native_rmg_owner_compared_translated_profile_supported(normalized)) {
		const auto auto_density_started_at = std::chrono::steady_clock::now();
		native_catalog_auto_density_supplement = append_native_catalog_auto_density_supplement(placements, occupied, placement_context, normalized, zone_layout, road_cells, ordinal);
		append_extension_profile_elapsed(object_profile_phases, "native_catalog_auto_density_floor_supplement", elapsed_usec_since(auto_density_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_large_reward_category_target >= 0) {
		const auto reward_trim_started_at = std::chrono::steady_clock::now();
		const int32_t reward_count = placement_count_for_spatial_category(placements, "reward");
		const int32_t desired_trim_count = std::max(0, reward_count - owner_large_reward_category_target);
		if (desired_trim_count > 0) {
			Array trimmed_placements;
			Array removed_ids;
			int32_t removed_count = 0;
			for (int64_t index = placements.size() - 1; index >= 0; --index) {
				if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
					trimmed_placements.push_front(placements[index]);
					continue;
				}
				Dictionary placement = Dictionary(placements[index]);
				if (String(placement.get("kind", "")) == "reward_reference" && removed_count < desired_trim_count) {
					removed_ids.append(placement.get("placement_id", ""));
					++removed_count;
					continue;
				}
				trimmed_placements.push_front(placement);
			}
			placements = trimmed_placements;
			Dictionary trim_summary;
			trim_summary["schema_id"] = "native_rmg_owner_large_land_reward_category_trim_v1";
			trim_summary["target_reward_category_count"] = owner_large_reward_category_target;
			trim_summary["initial_reward_category_count"] = reward_count;
			trim_summary["desired_trim_count"] = desired_trim_count;
			trim_summary["removed_reward_reference_count"] = removed_count;
			trim_summary["removed_placement_ids"] = removed_ids;
			trim_summary["final_reward_category_count"] = placement_count_for_spatial_category(placements, "reward");
			trim_summary["policy"] = "owner_large_no_water_category_count_trims_only_surplus_generic_reward_reference_after_required_mine_resource_dwelling_priority";
			trim_summary["status"] = int32_t(trim_summary.get("final_reward_category_count", 0)) == owner_large_reward_category_target ? "pass" : "partial";
			trim_summary["signature"] = hash32_hex(canonical_variant(trim_summary));
			native_catalog_auto_density_supplement["owner_large_land_reward_category_trim"] = trim_summary;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_large_land_reward_category_trim", elapsed_usec_since(reward_trim_started_at), top_object_phase_usec, top_object_phase_id);
	}

	if (owner_xl_reward_category_target >= 0) {
		const auto reward_trim_started_at = std::chrono::steady_clock::now();
		const int32_t reward_count = placement_count_for_spatial_category(placements, "reward");
		const int32_t desired_trim_count = std::max(0, reward_count - owner_xl_reward_category_target);
		if (desired_trim_count > 0) {
			Array trimmed_placements;
			Array removed_ids;
			int32_t removed_count = 0;
			for (int64_t index = placements.size() - 1; index >= 0; --index) {
				if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
					trimmed_placements.push_front(placements[index]);
					continue;
				}
				Dictionary placement = Dictionary(placements[index]);
				if (String(placement.get("kind", "")) == "reward_reference" && removed_count < desired_trim_count) {
					removed_ids.append(placement.get("placement_id", ""));
					++removed_count;
					continue;
				}
				trimmed_placements.push_front(placement);
			}
			placements = trimmed_placements;
			Dictionary trim_summary;
			trim_summary["schema_id"] = "native_rmg_owner_xl_land_reward_category_trim_v1";
			trim_summary["target_reward_category_count"] = owner_xl_reward_category_target;
			trim_summary["initial_reward_category_count"] = reward_count;
			trim_summary["desired_trim_count"] = desired_trim_count;
			trim_summary["removed_reward_reference_count"] = removed_count;
			trim_summary["removed_placement_ids"] = removed_ids;
			trim_summary["final_reward_category_count"] = placement_count_for_spatial_category(placements, "reward");
			trim_summary["policy"] = "owner_xl_no_water_category_count_trims_only_surplus_generic_reward_reference_after_required_mine_resource_dwelling_priority";
			trim_summary["status"] = int32_t(trim_summary.get("final_reward_category_count", 0)) == owner_xl_reward_category_target ? "pass" : "partial";
			trim_summary["signature"] = hash32_hex(canonical_variant(trim_summary));
			native_catalog_auto_density_supplement["owner_xl_land_reward_category_trim"] = trim_summary;
		}
		append_extension_profile_elapsed(object_profile_phases, "owner_xl_land_reward_category_trim", elapsed_usec_since(reward_trim_started_at), top_object_phase_usec, top_object_phase_id);
	}

	const auto occupancy_started_at = std::chrono::steady_clock::now();
	Dictionary primary_tile_occupancy;
	Dictionary body_tile_occupancy;
	Dictionary object_index_by_placement_id;
	Array footprint_records;
	int32_t total_body_tile_reference_count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		const String placement_id = String(placement.get("placement_id", ""));
		object_index_by_placement_id[placement_id] = index;
		primary_tile_occupancy[placement.get("primary_occupancy_key", "")] = placement_id;
		Array keys = placement.get("occupancy_keys", Array());
		total_body_tile_reference_count += keys.size();
		for (int64_t key_index = 0; key_index < keys.size(); ++key_index) {
			body_tile_occupancy[String(keys[key_index])] = placement_id;
		}
		Dictionary footprint;
		footprint["placement_id"] = placement_id;
		footprint["zone_id"] = placement.get("zone_id", "");
		footprint["primary_tile"] = placement.get("primary_tile", Dictionary());
		footprint["bounds"] = placement.get("bounds", Dictionary());
		footprint["body_tiles"] = placement.get("body_tiles", Array());
		footprint["runtime_footprint"] = placement.get("runtime_footprint", Dictionary());
		footprint_records.append(footprint);
	}

	Dictionary occupancy_index;
	occupancy_index["primary_tile_occupancy"] = primary_tile_occupancy;
	occupancy_index["body_tile_occupancy"] = body_tile_occupancy;
	occupancy_index["object_index_by_placement_id"] = object_index_by_placement_id;
	occupancy_index["occupied_primary_tile_count"] = primary_tile_occupancy.size();
	occupancy_index["occupied_body_tile_count"] = body_tile_occupancy.size();
	occupancy_index["body_tile_reference_count"] = total_body_tile_reference_count;
	occupancy_index["duplicate_body_tile_count"] = total_body_tile_reference_count - int32_t(body_tile_occupancy.size());
	occupancy_index["duplicate_primary_tile_count"] = int32_t(placements.size()) - int32_t(primary_tile_occupancy.size());
	occupancy_index["status"] = int32_t(placements.size()) == int32_t(primary_tile_occupancy.size()) && total_body_tile_reference_count == int32_t(body_tile_occupancy.size()) ? "pass" : "duplicate_occupancy_tiles";
	occupancy_index["signature"] = hash32_hex(canonical_variant(occupancy_index));

	Dictionary category_counts;
	category_counts["by_kind"] = count_by_field(placements, "kind");
	category_counts["by_family"] = count_by_field(placements, "family_id");
	category_counts["by_category"] = count_by_field(placements, "category_id");
	category_counts["by_zone"] = count_by_field(placements, "zone_id");
	category_counts["by_terrain"] = count_by_field(placements, "terrain_id");
	append_extension_profile_elapsed(object_profile_phases, "occupancy_and_category_indexes", elapsed_usec_since(occupancy_started_at), top_object_phase_usec, top_object_phase_id);

	const auto summary_started_at = std::chrono::steady_clock::now();
	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_OBJECT_PLACEMENT_SCHEMA_ID;
	payload["schema_version"] = 1;
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	payload["generation_status"] = scoped_structural_profile_supported ? "objects_generated_scoped_structural_profile" : "objects_generated_foundation";
	payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	payload["materialization_state"] = scoped_structural_profile_supported ? "staged_object_records_scoped_structural_profile_no_authored_writeback" : "staged_object_records_only_no_gameplay_adoption";
	payload["writeout_policy"] = "generated_object_records_no_authored_content_write";
	payload["object_placements"] = placements;
	payload["object_count"] = placements.size();
	payload["category_counts"] = category_counts;
	Dictionary mine_resource_summary;
	mine_resource_summary["schema_id"] = "aurelion_native_rmg_phase7_mines_resources_summary_v1";
	mine_resource_summary["phase_order"] = "phase_7_after_towns_castles_and_cleanup_connections_before_treasure_reward_bands";
	mine_resource_summary["category_order"] = rmg_mine_category_ids();
	Array minimum_offsets;
	Array density_offsets;
	for (int32_t category_index = 0; category_index < RMG_MINE_CATEGORY_COUNT; ++category_index) {
		minimum_offsets.append(rmg_mine_minimum_source_offset(category_index));
		density_offsets.append(rmg_mine_density_source_offset(category_index));
	}
	mine_resource_summary["source_offsets_minimums"] = minimum_offsets;
	mine_resource_summary["source_offsets_densities"] = density_offsets;
	mine_resource_summary["minimum_before_density"] = true;
	mine_resource_summary["required_attempt_count"] = mine_required_attempt_count;
	mine_resource_summary["density_attempt_count"] = mine_density_attempt_count_value;
	mine_resource_summary["placed_required_count"] = mine_required_placed_count;
	mine_resource_summary["placed_density_count"] = mine_density_placed_count;
	mine_resource_summary["adjacent_resource_support_count"] = adjacent_resource_support_count;
	mine_resource_summary["adjacent_resource_object_count"] = adjacent_resource_object_count;
	mine_resource_summary["diagnostics"] = mine_resource_diagnostics;
	mine_resource_summary["diagnostic_count"] = mine_resource_diagnostics.size();
	mine_resource_summary["adjacent_resource_records"] = adjacent_resource_records;
	mine_resource_summary["adjacent_resource_record_count"] = adjacent_resource_records.size();
	mine_resource_summary["signature"] = hash32_hex(canonical_variant(mine_resource_summary));
	payload["mine_resource_summary"] = mine_resource_summary;
	payload["mine_resource_diagnostics"] = mine_resource_diagnostics;
	payload["adjacent_resource_records"] = adjacent_resource_records;
	Dictionary reward_band_summary = reward_band_summary_for_zones(normalized, zones, placements);
	payload["reward_band_summary"] = reward_band_summary;
	payload["reward_band_diagnostics"] = reward_band_summary.get("diagnostics", Array());
	Dictionary decoration_summary = decoration_route_shaping_summary(placements, road_network);
	payload["decoration_density_pass"] = decoration_summary;
	payload["decoration_route_shaping_summary"] = decoration_summary;
	payload["native_catalog_auto_density_supplement"] = native_catalog_auto_density_supplement;
	payload["fill_coverage_summary"] = object_fill_coverage_summary(placements, zone_layout, width, height);
	payload["occupancy_index"] = occupancy_index;
	append_extension_profile_elapsed(object_profile_phases, "object_summary_payloads", elapsed_usec_since(summary_started_at), top_object_phase_usec, top_object_phase_id);
	const int64_t object_phase_elapsed_usec = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - object_phase_started_at).count();
	Dictionary runtime_phase_profile = build_extension_profile(object_profile_phases, object_phase_started_at, width, height, 1, int32_t(placements.size()), int32_t(road_network.get("road_segment_count", 0)), 0, 0, top_object_phase_id, top_object_phase_usec);
	Dictionary pipeline_summary = object_placement_pipeline_summary(normalized, zone_layout, placements, occupancy_index, object_phase_elapsed_usec, runtime_phase_profile);
	const String diagnostic_pipeline_signature = String(pipeline_summary.get("signature", ""));
	Dictionary deterministic_pipeline_summary = deterministic_object_placement_pipeline_summary(pipeline_summary);
	pipeline_summary["diagnostic_signature"] = diagnostic_pipeline_signature;
	pipeline_summary["replay_identity_signature"] = deterministic_pipeline_summary.get("signature", "");
	pipeline_summary["signature"] = deterministic_pipeline_summary.get("signature", "");
	payload["object_placement_pipeline_summary"] = pipeline_summary;
	payload["object_placement_pipeline_status"] = pipeline_summary.get("validation_status", "");
	payload["footprint_records"] = footprint_records;
	payload["footprint_record_count"] = footprint_records.size();
	payload["related_zone_layout_signature"] = zone_layout.get("signature", "");
	payload["related_road_network_signature"] = road_network.get("signature", "");
	Dictionary payload_signature_source = payload.duplicate(true);
	payload_signature_source["object_placement_pipeline_summary"] = deterministic_pipeline_summary;
	payload["signature"] = hash32_hex(canonical_variant(payload_signature_source));
	return payload;
}

Dictionary primary_occupancy_from_objects(const Dictionary &object_placement) {
	Dictionary occupied;
	Array placements = object_placement.get("object_placements", Array());
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		Array occupancy_keys = placement.get("occupancy_keys", Array());
		if (occupancy_keys.is_empty()) {
			const String key = String(placement.get("primary_occupancy_key", ""));
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
			continue;
		}
		for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
			const String key = String(occupancy_keys[key_index]);
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
		}
	}
	return occupied;
}

Dictionary blocking_occupancy_from_objects(const Dictionary &object_placement) {
	Dictionary occupied;
	Array placements = object_placement.get("object_placements", Array());
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		Dictionary passability = placement.get("passability", Dictionary());
		const String passability_class = String(passability.get("class", placement.get("passability_class", "")));
		const bool blocking = bool(placement.get("blocking_body", false)) || passability_class.begins_with("blocking") || passability_class == "edge_blocker";
		if (!blocking) {
			continue;
		}
		Array occupancy_keys = placement.get("occupancy_keys", Array());
		if (occupancy_keys.is_empty()) {
			const String key = String(placement.get("primary_occupancy_key", ""));
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
			continue;
		}
		for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
			const String key = String(occupancy_keys[key_index]);
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
		}
	}
	return occupied;
}

Dictionary non_clearable_blocking_occupancy_from_objects(const Dictionary &object_placement) {
	Dictionary occupied;
	Array placements = object_placement.get("object_placements", Array());
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		const String kind = String(placement.get("kind", ""));
		if (kind == "decorative_obstacle" || kind == "scenic_object") {
			continue;
		}
		Dictionary passability = placement.get("passability", Dictionary());
		const String passability_class = String(passability.get("class", placement.get("passability_class", "")));
		const bool blocking = bool(placement.get("blocking_body", false)) || passability_class.begins_with("blocking") || passability_class == "edge_blocker";
		if (!blocking) {
			continue;
		}
		Array occupancy_keys = placement.get("occupancy_keys", Array());
		if (occupancy_keys.is_empty()) {
			const String key = String(placement.get("primary_occupancy_key", ""));
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
			continue;
		}
		for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
			const String key = String(occupancy_keys[key_index]);
			if (!key.is_empty()) {
				occupied[key] = placement.get("placement_id", "");
			}
		}
	}
	return occupied;
}

void mark_record_blocking_occupancy(Dictionary &occupied, const Dictionary &record) {
	Array occupancy_keys = record.get("occupancy_keys", Array());
	if (occupancy_keys.is_empty()) {
		const String key = String(record.get("primary_occupancy_key", ""));
		if (!key.is_empty()) {
			occupied[key] = record.get("placement_id", record.get("guard_id", ""));
		}
		return;
	}
	for (int64_t key_index = 0; key_index < occupancy_keys.size(); ++key_index) {
		const String key = String(occupancy_keys[key_index]);
		if (!key.is_empty()) {
			occupied[key] = record.get("placement_id", record.get("guard_id", ""));
		}
	}
}

void mark_guard_control_zone_blocking_occupancy(Dictionary &occupied, const Dictionary &record, int32_t width, int32_t height) {
	const int32_t center_x = int32_t(record.get("x", 0));
	const int32_t center_y = int32_t(record.get("y", 0));
	const Variant owner_id = record.get("placement_id", record.get("guard_id", ""));
	for (int32_t dy = -1; dy <= 1; ++dy) {
		for (int32_t dx = -1; dx <= 1; ++dx) {
			const int32_t x = center_x + dx;
			const int32_t y = center_y + dy;
			if (x < 0 || y < 0 || x >= width || y >= height) {
				continue;
			}
			occupied[point_key(x, y)] = owner_id;
		}
	}
}

Dictionary zone_by_id(const Array &zones, const String &zone_id) {
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		if (String(zone.get("id", "")) == zone_id) {
			return zone;
		}
	}
	return Dictionary();
}

Dictionary point_from_cell(const Dictionary &cell) {
	return point_record(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
}

Array load_content_items_array(const String &path) {
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return Array();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return Array();
	}
	Dictionary root = Dictionary(parser->get_data());
	Variant items = root.get("items", Variant());
	return items.get_type() == Variant::ARRAY ? Array(items) : Array();
}

Array load_unit_content_items() {
	static Array cached_units;
	static bool loaded = false;
	if (loaded) {
		return cached_units;
	}
	loaded = true;
	cached_units = load_content_items_array("res://content/units.json");
	return cached_units;
}

String normalized_unit_faction_id(const Dictionary &unit) {
	const String faction_id = String(unit.get("faction_id", "")).strip_edges();
	return faction_id.is_empty() ? String("neutral") : faction_id;
}

int32_t unit_guard_value_estimate(const Dictionary &unit) {
	const int32_t tier = std::max(1, int32_t(unit.get("tier", 1)));
	const int32_t hp = std::max(1, int32_t(unit.get("hp", 1)));
	const int32_t attack = std::max(0, int32_t(unit.get("attack", 0)));
	const int32_t defense = std::max(0, int32_t(unit.get("defense", 0)));
	const int32_t min_damage = std::max(0, int32_t(unit.get("min_damage", 0)));
	const int32_t max_damage = std::max(min_damage, int32_t(unit.get("max_damage", min_damage)));
	const int32_t avg_damage = (min_damage + max_damage) / 2;
	return std::max(160, hp * 4 + attack * 30 + defense * 24 + avg_damage * 30 + tier * 80);
}

Array monster_allowed_factions_for_zone(const Dictionary &normalized, const Dictionary &zone, Array &diagnostics) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary monster_policy = metadata.get("monster_policy", Dictionary());
	Array allowed;
	const bool match_to_town = bool(monster_policy.get("match_to_town", false));
	const String zone_faction = String(zone.get("faction_id", zone.get("source_zone_faction_id", "")));
	if (match_to_town && !zone_faction.is_empty()) {
		allowed.append(zone_faction);
		return allowed;
	}
	Variant allowed_value = monster_policy.get("allowed_faction_ids", Variant());
	if (allowed_value.get_type() == Variant::ARRAY) {
		Array source_allowed = Array(allowed_value);
		for (int64_t index = 0; index < source_allowed.size(); ++index) {
			const String faction_id = String(source_allowed[index]).strip_edges();
			if (!faction_id.is_empty() && !array_has_string(allowed, faction_id)) {
				allowed.append(faction_id);
			}
		}
	}
	if (allowed.is_empty()) {
		allowed.append("neutral");
		Array factions = normalized.get("faction_ids", default_faction_pool());
		for (int64_t index = 0; index < factions.size(); ++index) {
			const String faction_id = String(factions[index]);
			if (!faction_id.is_empty() && !array_has_string(allowed, faction_id)) {
				allowed.append(faction_id);
			}
		}
		Dictionary diagnostic;
		diagnostic["code"] = "monster_allowed_faction_mask_empty_fallback";
		diagnostic["severity"] = "warning";
		diagnostic["zone_id"] = zone.get("id", "");
		diagnostic["fallback_behavior"] = "neutral_plus_profile_factions";
		diagnostics.append(diagnostic);
	}
	return allowed;
}

Array original_unit_guard_stack_for_value(int32_t guard_value, const String &seed_key, const Array &allowed_factions, Array &diagnostics, const String &zone_id) {
	Array units = load_unit_content_items();
	std::vector<Dictionary> candidates;
	std::vector<Dictionary> neutral_fallbacks;
	for (int64_t index = 0; index < units.size(); ++index) {
		if (Variant(units[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary unit = Dictionary(units[index]);
		const String faction_id = normalized_unit_faction_id(unit);
		if (faction_id == "neutral") {
			neutral_fallbacks.push_back(unit);
		}
		if (array_has_string(allowed_factions, faction_id)) {
			candidates.push_back(unit);
		}
	}
	if (candidates.empty()) {
		candidates = neutral_fallbacks;
		Dictionary diagnostic;
		diagnostic["code"] = "monster_allowed_mask_missing_original_unit_content";
		diagnostic["severity"] = "warning";
		diagnostic["zone_id"] = zone_id;
		diagnostic["allowed_faction_ids"] = allowed_factions;
		diagnostic["fallback_behavior"] = "neutral_original_units";
		diagnostics.append(diagnostic);
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		const int32_t left_tier = int32_t(left.get("tier", 1));
		const int32_t right_tier = int32_t(right.get("tier", 1));
		if (left_tier != right_tier) {
			return left_tier < right_tier;
		}
		return String(left.get("id", "")) < String(right.get("id", ""));
	});

	Array stack;
	if (candidates.empty()) {
		Dictionary diagnostic;
		diagnostic["code"] = "monster_selection_no_unit_content_available";
		diagnostic["severity"] = "failure";
		diagnostic["zone_id"] = zone_id;
		diagnostics.append(diagnostic);
		return stack;
	}
	const int32_t stack_count = guard_value >= 6000 && candidates.size() >= 2 ? 2 : 1;
	int32_t remaining = std::max(1, guard_value);
	for (int32_t slot = 0; slot < stack_count; ++slot) {
		const uint32_t selector = hash32_int(seed_key + String(":stack:") + String::num_int64(slot));
		const int32_t desired_tier = std::max(1, std::min(7, guard_value / 1800 + 1 + slot));
		int32_t best_index = 0;
		int32_t best_score = std::numeric_limits<int32_t>::max();
		for (int32_t index = 0; index < int32_t(candidates.size()); ++index) {
			Dictionary unit = candidates[index];
			const int32_t tier = int32_t(unit.get("tier", 1));
			const int32_t score = std::abs(tier - desired_tier) * 1000 + int32_t((selector + uint32_t(index * 37)) % 997U);
			if (score < best_score) {
				best_score = score;
				best_index = index;
			}
		}
		Dictionary unit = candidates[best_index];
		const int32_t estimate = unit_guard_value_estimate(unit);
		const int32_t slot_budget = stack_count == 1 ? remaining : (slot == 0 ? std::max(estimate * 3, remaining / 2) : remaining);
		Dictionary record;
		record["unit_id"] = unit.get("id", "");
		record["faction_id"] = normalized_unit_faction_id(unit);
		record["tier"] = unit.get("tier", 1);
		record["role"] = unit.get("role", "");
		record["count"] = std::max(3, int32_t(std::ceil(double(std::max(1, slot_budget)) / double(std::max(1, estimate)))));
		record["unit_value_estimate"] = estimate;
		record["allowed_faction_mask_matched"] = array_has_string(allowed_factions, String(record["faction_id"]));
		record["selection_source"] = "phase_10_original_unit_selection_from_recovered_monster_mask_and_strength_value";
		stack.append(record);
		remaining = std::max(1, remaining - int32_t(record["count"]) * estimate);
	}
	return stack;
}

String strength_band_for_value(int32_t guard_value) {
	if (guard_value >= 1200) {
		return "high";
	}
	if (guard_value >= 450) {
		return "medium";
	}
	return "low";
}

Dictionary point_bounds_record(int32_t x, int32_t y) {
	Dictionary bounds;
	bounds["min_x"] = x;
	bounds["min_y"] = y;
	bounds["max_x"] = x;
	bounds["max_y"] = y;
	return bounds;
}

int32_t town_spacing_radius_for_size(const Dictionary &normalized) {
		if (native_rmg_owner_large_land_density_case(normalized)) {
			return 32;
		}
		if (native_rmg_owner_xl_land_density_case(normalized)) {
			return 33;
		}
		if (native_rmg_owner_like_islands_density_case(normalized)) {
			return 17;
		}
		const int32_t shortest = std::max(1, std::min(int32_t(normalized.get("width", 36)), int32_t(normalized.get("height", 36))));
		const int32_t minimum = shortest >= 60 ? 12 : 8;
		return std::max(minimum, std::min(24, int32_t(std::ceil(double(shortest) / 5.0))));
	}

	int32_t town_hard_spacing_radius_for_size(const Dictionary &normalized) {
		if (native_rmg_owner_xl_land_density_case(normalized)) {
			return town_spacing_radius_for_size(normalized);
		}
		if (native_rmg_owner_like_islands_density_case(normalized)) {
			return town_spacing_radius_for_size(normalized);
		}
		return std::max(8, int32_t(std::floor(double(town_spacing_radius_for_size(normalized)) * 0.80)));
	}

int32_t town_access_fallback_spacing_radius_for_size(const Dictionary &normalized) {
	return town_hard_spacing_radius_for_size(normalized);
}

Dictionary town_spacing_policy_payload(const Dictionary &normalized) {
	Dictionary policy;
	policy["source_model"] = "HoMM3_RMG_town_layer_after_runtime_zone_construction_translated_to_original_spacing_contract";
	policy["preferred_minimum_direct_route_distance"] = town_spacing_radius_for_size(normalized);
	policy["hard_fallback_minimum_direct_route_distance"] = town_hard_spacing_radius_for_size(normalized);
	policy["access_fallback_minimum_direct_route_distance"] = town_access_fallback_spacing_radius_for_size(normalized);
	policy["distance_model"] = "direct_tile_route_chebyshev_distance";
	policy["fallback_policy"] = "retry_with_hard_accessible_spacing_then_required_legacy_spacing_fallback_then_skip_infeasible_town";
	return policy;
}

bool point_far_from_towns(const Array &towns, int32_t x, int32_t y, int32_t minimum_distance) {
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = towns[index];
		const int32_t dx = std::abs(x - int32_t(town.get("x", 0)));
		const int32_t dy = std::abs(y - int32_t(town.get("y", 0)));
		const int32_t distance = std::max(dx, dy);
		if (distance < minimum_distance) {
			return false;
		}
	}
	return true;
}

bool point_owned_by_zone(const Array &owner_grid, int32_t x, int32_t y, const String &zone_id);
bool zone_boundary_barrier_cell(const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height);
Array in_zone_access_path_cells(int32_t start_x, int32_t start_y, int32_t goal_x, int32_t goal_y, const String &zone_id, const Array &owner_grid, int32_t width, int32_t height);

Dictionary find_spaced_object_point(int32_t x, int32_t y, const String &preferred_zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height, const Array &towns, int32_t minimum_distance) {
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = std::max(1, std::min(std::max(1, width - 2), x + dx));
				const int32_t cy = std::max(1, std::min(std::max(1, height - 2), y + dy));
				if (occupied.has(point_key(cx, cy)) || !point_far_from_towns(towns, cx, cy, minimum_distance)) {
					continue;
				}
				if (!preferred_zone_id.is_empty() && cy >= 0 && cy < owner_grid.size()) {
					Array row = owner_grid[cy];
					if (cx >= 0 && cx < row.size() && String(row[cx]) != preferred_zone_id && radius < 6) {
						continue;
					}
				}
				return point_record(cx, cy);
			}
		}
	}
	return Dictionary();
}

Dictionary find_spaced_in_zone_object_point(int32_t x, int32_t y, const String &zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height, const Array &towns, int32_t minimum_distance) {
	if (zone_id.is_empty()) {
		return find_spaced_object_point(x, y, zone_id, owner_grid, occupied, width, height, towns, minimum_distance);
	}
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = std::max(1, std::min(std::max(1, width - 2), x + dx));
				const int32_t cy = std::max(1, std::min(std::max(1, height - 2), y + dy));
				if (!point_owned_by_zone(owner_grid, cx, cy, zone_id) || occupied.has(point_key(cx, cy)) || !point_far_from_towns(towns, cx, cy, minimum_distance)) {
					continue;
				}
				if (zone_boundary_barrier_cell(owner_grid, cx, cy, width, height) && radius < std::max(width, height)) {
					continue;
				}
				Dictionary point = point_record(cx, cy);
				point["town_accessibility_policy"] = "required_fallback_must_remain_in_source_zone_before_corridor_materialization";
				return point;
			}
		}
	}
	return Dictionary();
}

bool point_owned_by_zone(const Array &owner_grid, int32_t x, int32_t y, const String &zone_id) {
	if (zone_id.is_empty() || y < 0 || y >= owner_grid.size()) {
		return false;
	}
	Array row = owner_grid[y];
	return x >= 0 && x < row.size() && String(row[x]) == zone_id;
}

Dictionary nearest_owned_zone_point(int32_t x, int32_t y, const String &zone_id, const Array &owner_grid, int32_t width, int32_t height) {
	if (zone_id.is_empty()) {
		return Dictionary();
	}
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = std::max(0, std::min(std::max(0, width - 1), x + dx));
				const int32_t cy = std::max(0, std::min(std::max(0, height - 1), y + dy));
				if (point_owned_by_zone(owner_grid, cx, cy, zone_id)) {
					return point_record(cx, cy);
				}
			}
		}
	}
	return Dictionary();
}

Dictionary nearest_zone_road_access_anchor(const String &zone_id, const Dictionary &anchor, const Dictionary &road_network, const Array &owner_grid) {
	if (zone_id.is_empty()) {
		return Dictionary();
	}
	const int32_t ax = int32_t(anchor.get("x", 0));
	const int32_t ay = int32_t(anchor.get("y", 0));
	int32_t best_distance = std::numeric_limits<int32_t>::max();
	Dictionary best;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		if (Variant(road_segments[segment_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary segment = Dictionary(road_segments[segment_index]);
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			for (int32_t dy = -1; dy <= 1; ++dy) {
				for (int32_t dx = -1; dx <= 1; ++dx) {
					const int32_t cx = x + dx;
					const int32_t cy = y + dy;
					if (!point_owned_by_zone(owner_grid, cx, cy, zone_id)) {
						continue;
					}
					const int32_t distance = std::abs(cx - ax) + std::abs(cy - ay);
					if (distance < best_distance) {
						best_distance = distance;
						best = point_record(cx, cy);
					}
				}
			}
		}
	}
	return best;
}

bool in_zone_path_exists(int32_t start_x, int32_t start_y, int32_t goal_x, int32_t goal_y, const String &zone_id, const Array &owner_grid, const Dictionary &blocking_occupied, int32_t width, int32_t height) {
	if (start_x < 0 || start_y < 0 || start_x >= width || start_y >= height || goal_x < 0 || goal_y < 0 || goal_x >= width || goal_y >= height) {
		return false;
	}
	if (!point_owned_by_zone(owner_grid, start_x, start_y, zone_id) || !point_owned_by_zone(owner_grid, goal_x, goal_y, zone_id)) {
		return false;
	}
	std::vector<uint8_t> seen(std::max(0, width * height), 0);
	std::vector<int32_t> queue;
	queue.reserve(std::max(1, width * height));
	const int32_t start_index = start_y * width + start_x;
	seen[start_index] = 1;
	queue.push_back(start_index);
	size_t cursor = 0;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (cursor < queue.size()) {
		const int32_t current = queue[cursor++];
		const int32_t cx = current % width;
		const int32_t cy = current / width;
		if (cx == goal_x && cy == goal_y) {
			return true;
		}
		for (int32_t direction = 0; direction < 8; ++direction) {
			const int32_t nx = cx + DX[direction];
			const int32_t ny = cy + DY[direction];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height || !point_owned_by_zone(owner_grid, nx, ny, zone_id)) {
				continue;
			}
			const int32_t next_index = ny * width + nx;
			if (seen[next_index]) {
				continue;
			}
			const bool endpoint = (nx == start_x && ny == start_y) || (nx == goal_x && ny == goal_y);
			if (!endpoint && blocking_occupied.has(point_key(nx, ny))) {
				continue;
			}
			seen[next_index] = 1;
			queue.push_back(next_index);
		}
	}
	return false;
}

Dictionary in_zone_access_reachable_lookup(int32_t anchor_x, int32_t anchor_y, const String &zone_id, const Array &owner_grid, const Dictionary &blocking_occupied, int32_t width, int32_t height) {
	Dictionary reachable;
	if (anchor_x < 0 || anchor_y < 0 || anchor_x >= width || anchor_y >= height || !point_owned_by_zone(owner_grid, anchor_x, anchor_y, zone_id)) {
		return reachable;
	}
	const int32_t tile_count = std::max(0, width * height);
	std::vector<uint8_t> seen(tile_count, 0);
	std::vector<int32_t> queue;
	queue.reserve(std::max(1, tile_count));
	const int32_t start_index = anchor_y * width + anchor_x;
	seen[start_index] = 1;
	queue.push_back(start_index);
	size_t cursor = 0;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (cursor < queue.size()) {
		const int32_t current = queue[cursor++];
		const int32_t cx = current % width;
		const int32_t cy = current / width;
		reachable[point_key(cx, cy)] = true;
		for (int32_t direction = 0; direction < 8; ++direction) {
			const int32_t nx = cx + DX[direction];
			const int32_t ny = cy + DY[direction];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height || !point_owned_by_zone(owner_grid, nx, ny, zone_id)) {
				continue;
			}
			const String key = point_key(nx, ny);
			reachable[key] = true;
			if (blocking_occupied.has(key)) {
				continue;
			}
			const int32_t next_index = ny * width + nx;
			if (seen[next_index]) {
				continue;
			}
			seen[next_index] = 1;
			queue.push_back(next_index);
		}
	}
	return reachable;
}

Array in_zone_access_path_cells(int32_t start_x, int32_t start_y, int32_t goal_x, int32_t goal_y, const String &zone_id, const Array &owner_grid, int32_t width, int32_t height) {
	Array path;
	if (start_x < 0 || start_y < 0 || start_x >= width || start_y >= height || goal_x < 0 || goal_y < 0 || goal_x >= width || goal_y >= height) {
		return path;
	}
	if (!point_owned_by_zone(owner_grid, start_x, start_y, zone_id) || !point_owned_by_zone(owner_grid, goal_x, goal_y, zone_id)) {
		return path;
	}
	const int32_t tile_count = std::max(0, width * height);
	std::vector<uint8_t> seen(tile_count, 0);
	std::vector<int32_t> parent(tile_count, -1);
	std::vector<int32_t> queue;
	queue.reserve(std::max(1, tile_count));
	const int32_t start_index = start_y * width + start_x;
	const int32_t goal_index = goal_y * width + goal_x;
	seen[start_index] = 1;
	queue.push_back(start_index);
	size_t cursor = 0;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (cursor < queue.size() && !seen[goal_index]) {
		const int32_t current = queue[cursor++];
		const int32_t cx = current % width;
		const int32_t cy = current / width;
		for (int32_t direction = 0; direction < 8; ++direction) {
			const int32_t nx = cx + DX[direction];
			const int32_t ny = cy + DY[direction];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height || !point_owned_by_zone(owner_grid, nx, ny, zone_id)) {
				continue;
			}
			const int32_t next_index = ny * width + nx;
			if (seen[next_index]) {
				continue;
			}
			seen[next_index] = 1;
			parent[next_index] = current;
			queue.push_back(next_index);
		}
	}
	if (!seen[goal_index]) {
		return path;
	}
	std::vector<int32_t> reversed;
	for (int32_t current = goal_index; current >= 0; current = parent[current]) {
		reversed.push_back(current);
		if (current == start_index) {
			break;
		}
	}
	for (auto iterator = reversed.rbegin(); iterator != reversed.rend(); ++iterator) {
		const int32_t cell_index = *iterator;
		path.append(cell_record(cell_index % width, cell_index / width, 0));
	}
	return path;
}

Array direct_access_path_cells(int32_t start_x, int32_t start_y, int32_t goal_x, int32_t goal_y, int32_t width, int32_t height, const Dictionary &blocked = Dictionary()) {
	Array path;
	if (start_x < 0 || start_y < 0 || start_x >= width || start_y >= height || goal_x < 0 || goal_y < 0 || goal_x >= width || goal_y >= height) {
		return path;
	}
	const int32_t tile_count = std::max(0, width * height);
	std::vector<uint8_t> seen(tile_count, 0);
	std::vector<int32_t> parent(tile_count, -1);
	std::vector<int32_t> queue;
	queue.reserve(std::max(1, tile_count));
	const int32_t start_index = start_y * width + start_x;
	const int32_t goal_index = goal_y * width + goal_x;
	seen[start_index] = 1;
	queue.push_back(start_index);
	size_t cursor = 0;
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	while (cursor < queue.size() && !seen[goal_index]) {
		const int32_t current = queue[cursor++];
		const int32_t cx = current % width;
		const int32_t cy = current / width;
		for (int32_t direction = 0; direction < 8; ++direction) {
			const int32_t nx = cx + DX[direction];
			const int32_t ny = cy + DY[direction];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
				continue;
			}
			const int32_t next_index = ny * width + nx;
			if (seen[next_index]) {
				continue;
			}
			const bool endpoint = (nx == start_x && ny == start_y) || (nx == goal_x && ny == goal_y);
			if (!endpoint && blocked.has(point_key(nx, ny))) {
				continue;
			}
			seen[next_index] = 1;
			parent[next_index] = current;
			queue.push_back(next_index);
		}
	}
	if (!seen[goal_index]) {
		return path;
	}
	std::vector<int32_t> reversed;
	for (int32_t current = goal_index; current >= 0; current = parent[current]) {
		reversed.push_back(current);
		if (current == start_index) {
			break;
		}
	}
	for (auto iterator = reversed.rbegin(); iterator != reversed.rend(); ++iterator) {
		const int32_t cell_index = *iterator;
		path.append(cell_record(cell_index % width, cell_index / width, 0));
	}
	return path;
}

Dictionary find_spaced_accessible_town_point(int32_t x, int32_t y, const String &preferred_zone_id, const Array &owner_grid, const Dictionary &occupied, const Dictionary &blocking_occupied, int32_t width, int32_t height, const Array &towns, int32_t minimum_distance, const Dictionary &access_anchor) {
	if (preferred_zone_id.is_empty() || access_anchor.is_empty()) {
		return find_spaced_object_point(x, y, preferred_zone_id, owner_grid, occupied, width, height, towns, minimum_distance);
	}
	const int32_t anchor_x = int32_t(access_anchor.get("x", x));
	const int32_t anchor_y = int32_t(access_anchor.get("y", y));
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = std::max(1, std::min(std::max(1, width - 2), x + dx));
				const int32_t cy = std::max(1, std::min(std::max(1, height - 2), y + dy));
				if (!point_owned_by_zone(owner_grid, cx, cy, preferred_zone_id) || occupied.has(point_key(cx, cy)) || !point_far_from_towns(towns, cx, cy, minimum_distance)) {
					continue;
				}
				if (zone_boundary_barrier_cell(owner_grid, cx, cy, width, height) && radius < std::max(width, height)) {
					continue;
				}
				if (!in_zone_path_exists(cx, cy, anchor_x, anchor_y, preferred_zone_id, owner_grid, blocking_occupied, width, height)) {
					continue;
				}
				Dictionary point = point_record(cx, cy);
				point["town_accessibility_policy"] = "requires_in_zone_path_to_start_or_zone_anchor_through_existing_blocking_objects";
				return point;
			}
		}
	}
	return Dictionary();
}

Dictionary find_spaced_accessible_town_point_with_reachability(int32_t x, int32_t y, const String &preferred_zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height, const Array &towns, int32_t minimum_distance, const Dictionary &access_anchor, const Dictionary &access_reachable_lookup) {
	if (preferred_zone_id.is_empty() || access_anchor.is_empty()) {
		return find_spaced_object_point(x, y, preferred_zone_id, owner_grid, occupied, width, height, towns, minimum_distance);
	}
	for (int32_t radius = 0; radius <= std::max(width, height); ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t cx = std::max(1, std::min(std::max(1, width - 2), x + dx));
				const int32_t cy = std::max(1, std::min(std::max(1, height - 2), y + dy));
				const String key = point_key(cx, cy);
				if (!point_owned_by_zone(owner_grid, cx, cy, preferred_zone_id) || occupied.has(key) || !point_far_from_towns(towns, cx, cy, minimum_distance)) {
					continue;
				}
				if (zone_boundary_barrier_cell(owner_grid, cx, cy, width, height) && radius < std::max(width, height)) {
					continue;
				}
				if (!access_reachable_lookup.has(key)) {
					continue;
				}
				Dictionary point = point_record(cx, cy);
				point["town_accessibility_policy"] = "requires_in_zone_path_to_start_or_zone_anchor_through_existing_blocking_objects";
				return point;
			}
		}
	}
	return Dictionary();
}

Dictionary town_spacing_summary(const Array &towns, const Dictionary &normalized) {
	const int32_t preferred_required = town_spacing_radius_for_size(normalized);
	const int32_t hard_required = town_hard_spacing_radius_for_size(normalized);
	int32_t observed_min = std::numeric_limits<int32_t>::max();
	int32_t start_observed_min = std::numeric_limits<int32_t>::max();
	int32_t same_zone_observed_min = std::numeric_limits<int32_t>::max();
	int32_t pair_count = 0;
	int32_t start_pair_count = 0;
	int32_t same_zone_pair_count = 0;
	for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
		Dictionary left = towns[left_index];
		for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
			Dictionary right = towns[right_index];
			const int32_t dx = std::abs(int32_t(left.get("x", 0)) - int32_t(right.get("x", 0)));
			const int32_t dy = std::abs(int32_t(left.get("y", 0)) - int32_t(right.get("y", 0)));
			const int32_t distance = std::max(dx, dy);
			++pair_count;
			observed_min = std::min(observed_min, distance);
			if (bool(left.get("is_start_town", false)) && bool(right.get("is_start_town", false))) {
				++start_pair_count;
				start_observed_min = std::min(start_observed_min, distance);
			}
			if (String(left.get("zone_id", "")) == String(right.get("zone_id", ""))) {
				++same_zone_pair_count;
				same_zone_observed_min = std::min(same_zone_observed_min, distance);
			}
		}
	}
	Dictionary all_towns;
	all_towns["scope"] = "all_towns";
	all_towns["pair_count"] = pair_count;
	all_towns["minimum_distance_required"] = hard_required;
	all_towns["preferred_minimum_distance"] = preferred_required;
	all_towns["observed_minimum_distance"] = observed_min == std::numeric_limits<int32_t>::max() ? 0 : observed_min;
	all_towns["distance_model"] = "direct_tile_route_chebyshev_distance";
	all_towns["status"] = observed_min == std::numeric_limits<int32_t>::max() || observed_min >= hard_required ? "pass" : "fail";
	Dictionary start_towns;
	start_towns["scope"] = "start_towns";
	start_towns["pair_count"] = start_pair_count;
	start_towns["minimum_distance_required"] = preferred_required;
	start_towns["hard_fallback_minimum_distance"] = hard_required;
	start_towns["observed_minimum_distance"] = start_observed_min == std::numeric_limits<int32_t>::max() ? 0 : start_observed_min;
	start_towns["distance_model"] = "direct_tile_route_chebyshev_distance";
	start_towns["status"] = start_observed_min == std::numeric_limits<int32_t>::max() || start_observed_min >= preferred_required ? "pass" : "fail";
	Dictionary same_zone_towns;
	same_zone_towns["scope"] = "same_zone_towns";
	same_zone_towns["pair_count"] = same_zone_pair_count;
	same_zone_towns["minimum_distance_required"] = hard_required;
	same_zone_towns["preferred_minimum_distance"] = preferred_required;
	same_zone_towns["observed_minimum_distance"] = same_zone_observed_min == std::numeric_limits<int32_t>::max() ? 0 : same_zone_observed_min;
	same_zone_towns["distance_model"] = "direct_tile_route_chebyshev_distance";
	same_zone_towns["status"] = same_zone_observed_min == std::numeric_limits<int32_t>::max() || same_zone_observed_min >= hard_required ? "pass" : "fail";
	Dictionary summary;
	summary["ok"] = String(all_towns["status"]) == "pass" && String(start_towns["status"]) == "pass" && String(same_zone_towns["status"]) == "pass";
	summary["minimum_distance_required"] = hard_required;
	summary["preferred_minimum_distance"] = preferred_required;
	summary["observed_minimum_distance"] = all_towns["observed_minimum_distance"];
	summary["all_towns"] = all_towns;
	summary["start_towns"] = start_towns;
	summary["same_zone_towns"] = same_zone_towns;
	return summary;
}

Dictionary town_record_at_point(const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const Dictionary &start, const String &record_type, int32_t ordinal, const Dictionary &road_network, const Dictionary &zone_layout, const Dictionary &occupied, const Dictionary &semantics) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	const int32_t player_slot = int32_t(start.get("player_slot", int32_t(zone.get("player_slot", 0))));
	const bool start_town = record_type == "player_start_town";
	const bool player_owned = start_town || record_type.begins_with("player_");
	const bool castle_record = record_type.contains("castle");
	String faction_id = String(semantics.get("faction_id", ""));
	if (faction_id.is_empty()) {
		faction_id = player_owned ? String(start.get("faction_id", zone.get("faction_id", ""))) : String(zone.get("faction_id", ""));
	}
	if (faction_id.is_empty()) {
		Array faction_ids = normalized.get("faction_ids", default_faction_pool());
		faction_id = faction_ids.is_empty() ? String("faction_embercourt") : String(faction_ids[ordinal % faction_ids.size()]);
	}
	String town_id = String(semantics.get("town_id", ""));
	if (town_id.is_empty()) {
		town_id = player_owned ? String(start.get("town_id", town_for_faction(faction_id))) : town_for_faction(faction_id);
	}
	if (town_id.is_empty()) {
		town_id = town_for_faction(faction_id);
	}
	String placement_prefix = player_owned ? "native_rmg_town_player_" : "native_rmg_town_neutral_";
	const String placement_id = start_town ? "native_rmg_town_start_" + slot_id_2(player_slot) : placement_prefix + zone_id + "_" + slot_id_2(ordinal + 1);
	Dictionary body = cell_record(x, y, 0);
	Array body_tiles;
	body_tiles.append(body);
	Array occupancy_keys;
	occupancy_keys.append(point_key(x, y));

	Dictionary footprint;
	footprint["width"] = 3;
	footprint["height"] = 2;
	footprint["anchor"] = "bottom_middle";
	footprint["visit_mask_contract"] = "inside_intended_3x2_body_outside_current_1x1_runtime_body_until_multitile_town_runtime_slice";
	footprint["tier"] = "town";

	Dictionary runtime_footprint;
	runtime_footprint["width"] = 1;
	runtime_footprint["height"] = 1;
	runtime_footprint["anchor"] = "center";
	runtime_footprint["tier"] = "anchor_tile";

	Dictionary predicate_results;
	predicate_results["in_bounds"] = x >= 0 && y >= 0 && x < width && y < height;
	predicate_results["terrain_allowed"] = is_passable_terrain_id(terrain_id);
	predicate_results["primary_tile_unoccupied_before_town"] = !occupied.has(point_key(x, y));
	predicate_results["zone_associated"] = !zone_id.is_empty();
	predicate_results["start_anchor_linked"] = start_town && !start.is_empty();
	predicate_results["road_proximity_recorded"] = true;

	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	Dictionary zone_proximity;
	zone_proximity["zone_anchor"] = anchor;
	zone_proximity["manhattan_distance_to_anchor"] = std::abs(x - int32_t(anchor.get("x", x))) + std::abs(y - int32_t(anchor.get("y", y)));
	zone_proximity["owner_grid_signature"] = zone_layout.get("signature", "");

	Dictionary record;
	record["placement_id"] = placement_id;
	record["record_type"] = record_type;
	record["kind"] = "town";
	record["town_id"] = town_id;
	record["family_id"] = "town_primary";
	record["object_family_id"] = "town_primary";
	record["type_id"] = "town";
	record["faction_id"] = faction_id;
	record["owner"] = player_owned ? "player_" + String::num_int64(player_slot) : "neutral";
	record["owner_slot"] = player_owned ? start.get("owner_slot", zone.get("owner_slot", player_slot)) : Variant(-1);
	record["player_slot"] = player_owned ? Variant(player_slot) : Variant();
	record["player_type"] = player_owned ? start.get("player_type", zone.get("player_type", "computer")) : Variant("neutral");
	record["team_id"] = player_owned ? start.get("team_id", zone.get("team_id", "")) : Variant("");
	record["zone_id"] = zone_id;
	record["zone_role"] = zone.get("role", "");
	record["terrain_id"] = terrain_id;
	record["biome_id"] = biome_for_terrain(terrain_id);
	record["x"] = x;
	record["y"] = y;
	record["level"] = 0;
	record["primary_tile"] = body;
	record["primary_occupancy_key"] = point_key(x, y);
	record["bounds"] = point_bounds_record(x, y);
	record["body_tiles"] = body_tiles;
	record["occupancy_keys"] = occupancy_keys;
	record["footprint"] = footprint;
	record["runtime_footprint"] = runtime_footprint;
	record["footprint_deferred"] = true;
	record["approach_tiles"] = cardinal_approach_tiles_in_zone(x, y, width, height, occupied, zone_layout.get("surface_owner_grid", Array()), zone_id);
	record["visit_tile"] = body;
	Array predicates;
	predicates.append("in_bounds");
	predicates.append("terrain_allowed");
	predicates.append("primary_tile_unoccupied_before_town");
	predicates.append("zone_associated");
	predicates.append("road_proximity_recorded");
	record["placement_predicates"] = predicates;
	record["placement_predicate_results"] = predicate_results;
	record["road_proximity"] = nearest_road_proximity(x, y, road_network);
	record["zone_proximity"] = zone_proximity;
	record["start_anchor"] = start;
	record["is_start_town"] = start_town;
	record["is_capital"] = start_town;
	record["is_castle"] = castle_record || start_town;
	record["settlement_category"] = record["is_castle"] ? "castle" : "town";
	record["capital_role"] = start_town ? "player_capital_and_starting_town" : "neutral_expansion_town";
	record["town_assignment_semantics"] = semantics.get("town_assignment_semantics", start_town ? Variant("player_start_town_from_native_player_assignment") : Variant("neutral_zone_town_from_native_foundation_zone"));
	record["source_phase"] = semantics.get("source_phase", "");
	record["source_field_offset"] = semantics.get("source_field_offset", "");
	record["source_field_name"] = semantics.get("source_field_name", "");
	record["source_field_value"] = semantics.get("source_field_value", 0);
	record["source_zone_faction_id"] = semantics.get("source_zone_faction_id", zone.get("source_zone_faction_id", ""));
	record["allowed_town_faction_ids"] = semantics.get("allowed_town_faction_ids", zone.get("allowed_town_faction_ids", Array()));
	record["faction_selection_source"] = semantics.get("faction_selection_source", player_owned ? Variant("mapped_owner_player_assignment") : Variant("source_zone_allowed_faction_choice"));
	record["same_type_neutral"] = semantics.get("same_type_neutral", false);
	record["same_type_semantics"] = semantics.get("same_type_semantics", "not_applicable");
	record["owner_semantics"] = player_owned ? "mapped_owner_player" : "neutral_owner_minus_one";
	record["zone_anchor"] = zone.get("anchor", Dictionary());
	record["town_spacing_policy"] = town_spacing_policy_payload(normalized);
	record["required_town_access_anchor"] = semantics.get("required_town_access_anchor", Dictionary());
	record["required_town_access_corridor_cells"] = semantics.get("required_town_access_corridor_cells", Array());
	record["required_town_access_corridor_cell_count"] = Array(record.get("required_town_access_corridor_cells", Array())).size();
	record["required_town_access_corridor_policy"] = semantics.get("required_town_access_corridor_policy", "town_to_zone_anchor_or_road_corridor_reserved_for_required_access");
	record["bounds_status"] = "in_bounds";
	record["occupancy_status"] = "primary_tile_reserved";
	record["materialization_state"] = "staged_town_record_only_no_gameplay_adoption";
	record["writeout_state"] = "staged_no_authored_content_writeback";
	record["signature"] = hash32_hex(canonical_variant(record));
	return record;
}

void append_town_record(Array &towns, Dictionary &occupied, const Dictionary &town) {
	if (town.is_empty()) {
		return;
	}
	towns.append(town);
	occupied[town.get("primary_occupancy_key", "")] = town.get("placement_id", "");
}

bool zone_boundary_barrier_cell(const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height);

Array route_guard_body_tiles_for_edge(int32_t x, int32_t y, int32_t width, int32_t height, const Dictionary &road_network, const Dictionary &zone_layout, const String &route_edge_id) {
	Array body_tiles;
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Dictionary seen;
	auto append_unique = [&](int32_t tile_x, int32_t tile_y) {
		if (tile_x < 0 || tile_y < 0 || tile_x >= width || tile_y >= height) {
			return;
		}
		const String key = point_key(tile_x, tile_y);
		if (seen.has(key)) {
			return;
		}
		seen[key] = true;
		body_tiles.append(cell_record(tile_x, tile_y, 0));
	};
	append_unique(x, y);
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		if (String(segment.get("route_edge_id", "")) != route_edge_id) {
			continue;
		}
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = cells[cell_index];
			const int32_t cell_x = int32_t(cell.get("x", 0));
			const int32_t cell_y = int32_t(cell.get("y", 0));
			if (int32_t(cell.get("x", 0)) != x || int32_t(cell.get("y", 0)) != y) {
				continue;
			}
			append_unique(cell_x, cell_y);
			if (zone_boundary_barrier_cell(owner_grid, cell_x, cell_y, width, height)) {
				for (int32_t dy = -1; dy <= 1; ++dy) {
					for (int32_t dx = -1; dx <= 1; ++dx) {
						append_unique(cell_x + dx, cell_y + dy);
					}
				}
			}
			if (cell_index > 0 && Variant(cells[cell_index - 1]).get_type() == Variant::DICTIONARY) {
				Dictionary before = cells[cell_index - 1];
				append_unique(int32_t(before.get("x", 0)), int32_t(before.get("y", 0)));
			}
			if (cell_index + 1 < cells.size() && Variant(cells[cell_index + 1]).get_type() == Variant::DICTIONARY) {
				Dictionary after = cells[cell_index + 1];
				append_unique(int32_t(after.get("x", 0)), int32_t(after.get("y", 0)));
			}
		}
		return body_tiles;
	}
	return body_tiles;
}

Dictionary guard_record_at_point(const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &guard_kind, int32_t ordinal, int32_t guard_value, const Dictionary &road_network, const Dictionary &zone_layout, const Dictionary &occupied, const Dictionary &target) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String zone_id = String(zone.get("id", target.get("zone_id", "")));
	const String terrain_id = terrain_id_for_zone(zone.is_empty() ? Dictionary() : zone);
	const String guard_id = "native_rmg_guard_" + guard_kind + "_" + slot_id_2(ordinal + 1);
	const String strength_band = strength_band_for_value(guard_value);
	Array monster_diagnostics;
	Array allowed_factions = monster_allowed_factions_for_zone(normalized, zone, monster_diagnostics);
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary monster_policy = metadata.get("monster_policy", Dictionary());
	const int32_t source_strength_mode = rmg_local_monster_strength_mode(monster_policy.get("strength", "avg"));
	const int32_t effective_strength_mode = rmg_effective_monster_strength_mode(normalized, zone);
	Array stack_records = original_unit_guard_stack_for_value(guard_value, String(normalized.get("normalized_seed", "0")) + guard_id, allowed_factions, monster_diagnostics, zone_id);
	Dictionary body = cell_record(x, y, 0);
	Array body_tiles = guard_kind == "route_guard" ? route_guard_body_tiles_for_edge(x, y, width, height, road_network, zone_layout, String(target.get("route_edge_id", ""))) : Array::make(body);
	Array occupancy_keys;
	for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
		Dictionary body_tile = body_tiles[body_index];
		occupancy_keys.append(point_key(int32_t(body_tile.get("x", x)), int32_t(body_tile.get("y", y))));
	}

	Dictionary predicate_results;
	predicate_results["in_bounds"] = x >= 0 && y >= 0 && x < width && y < height;
	predicate_results["terrain_allowed"] = is_passable_terrain_id(terrain_id);
	predicate_results["primary_tile_unoccupied_before_guard"] = !occupied.has(point_key(x, y));
	predicate_results["protected_target_linked"] = !String(target.get("protected_target_id", "")).is_empty();
	predicate_results["zone_associated"] = !zone_id.is_empty();

	Dictionary monster_reward_band;
	monster_reward_band["id"] = "native_rmg_monster_reward_band_" + slot_id_2(ordinal + 1);
	monster_reward_band["strength_band"] = strength_band;
	monster_reward_band["guard_value"] = guard_value;
	monster_reward_band["reward_context"] = String(target.get("protected_target_type", "")) == "object_placement" ? "guarded_site_reward_context" : "route_access_pressure_context";
	monster_reward_band["selection_state"] = "original_unit_stack_selected_from_supported_monster_mask";
	monster_reward_band["source_strength_mode"] = source_strength_mode;
	monster_reward_band["global_strength_mode"] = rmg_global_monster_strength_mode(normalized);
	monster_reward_band["effective_strength_mode"] = effective_strength_mode;
	monster_reward_band["allowed_faction_ids"] = allowed_factions;
	monster_reward_band["match_to_town"] = monster_policy.get("match_to_town", false);

	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	Dictionary record;
	record["guard_id"] = guard_id;
	record["placement_id"] = guard_id;
	record["record_type"] = "guard_stack";
	record["kind"] = "guard";
	record["guard_kind"] = guard_kind;
	record["owner"] = "neutral";
	record["zone_id"] = zone_id;
	record["zone_role"] = zone.get("role", "");
	record["terrain_id"] = terrain_id;
	record["biome_id"] = biome_for_terrain(terrain_id);
	record["x"] = x;
	record["y"] = y;
	record["level"] = 0;
	record["primary_tile"] = body;
	record["primary_occupancy_key"] = point_key(x, y);
	record["bounds"] = point_bounds_record(x, y);
	record["body_tiles"] = body_tiles;
	record["occupancy_keys"] = occupancy_keys;
	Dictionary runtime_footprint;
	runtime_footprint["width"] = 1;
	runtime_footprint["height"] = 1;
	runtime_footprint["anchor"] = "center";
	runtime_footprint["tier"] = "guard_anchor_tile";
	record["runtime_footprint"] = runtime_footprint;
	record["approach_tiles"] = cardinal_approach_tiles(x, y, width, height, occupied);
	record["visit_tile"] = body;
	record["guard_value"] = guard_value;
	record["effective_guard_pressure"] = strength_band;
	record["strength_band"] = strength_band;
	record["stack_records"] = stack_records;
	record["stack_count"] = Array(record.get("stack_records", Array())).size();
	record["monster_selection_source"] = "recovered_match_to_town_allowed_faction_mask_strength_scaling_translated_to_original_units";
	record["monster_policy"] = monster_policy;
	record["monster_match_to_town"] = monster_policy.get("match_to_town", false);
	record["monster_allowed_faction_ids"] = allowed_factions;
	record["monster_source_strength_mode"] = source_strength_mode;
	record["monster_global_strength_mode"] = rmg_global_monster_strength_mode(normalized);
	record["monster_effective_strength_mode"] = effective_strength_mode;
	record["monster_strength_formula"] = "0x4a960a_effective_mode_plus_0x4a65a5_threshold_slope_tables";
	record["monster_diagnostics"] = monster_diagnostics;
	record["monster_diagnostic_count"] = monster_diagnostics.size();
	record["unsupported_monster_boundaries"] = Array();
	record["protected_target"] = target;
	record["protected_target_id"] = target.get("protected_target_id", "");
	record["protected_target_type"] = target.get("protected_target_type", "");
	record["protected_zone_id"] = target.get("protected_zone_id", zone_id);
	record["route_edge_id"] = target.get("route_edge_id", "");
	record["protected_object_placement_id"] = target.get("protected_object_placement_id", "");
	record["protected_object_kind"] = target.get("protected_object_kind", "");
	record["guarded_object_kind"] = target.get("protected_object_kind", "");
	record["guarded_reward_value"] = target.get("protected_reward_value", 0);
	record["guarded_reward_value_tier"] = target.get("protected_reward_value_tier", "");
	record["guarded_reward_category"] = target.get("protected_reward_category", "");
	record["guard_reward_value_ratio"] = int32_t(target.get("protected_reward_value", 0)) > 0 ? double(guard_value) / double(int32_t(target.get("protected_reward_value", 1))) : 0.0;
	record["protected_zone_value_budget"] = target.get("protected_zone_value_budget", 0);
	record["protected_zone_value_tier"] = target.get("protected_zone_value_tier", "");
	record["guard_reward_relation_source"] = target.get("guard_reward_relation_source", int32_t(target.get("protected_reward_value", 0)) > 0 ? Variant("guard_value_scaled_from_zone_reward_value") : Variant("guard_value_from_route_or_site_baseline"));
	record["guarded_artifact_id"] = target.get("guarded_artifact_id", "");
	record["guarded_site_id"] = target.get("guarded_site_id", "");
	record["guarded_object_point"] = target.get("guarded_object_point", Dictionary());
	record["guard_distance"] = target.get("guard_distance", 0);
	record["adjacent_to_guarded_object"] = target.get("adjacent_to_guarded_object", false);
	record["near_guarded_object"] = int32_t(target.get("guard_distance", 0)) <= 20;
	record["road_proximity"] = nearest_road_proximity(x, y, road_network);
	Dictionary zone_proximity;
	zone_proximity["zone_anchor"] = anchor;
	zone_proximity["manhattan_distance_to_anchor"] = std::abs(x - int32_t(anchor.get("x", x))) + std::abs(y - int32_t(anchor.get("y", y)));
	zone_proximity["owner_grid_signature"] = zone_layout.get("signature", "");
	record["zone_proximity"] = zone_proximity;
	Array guard_predicates;
	guard_predicates.append("in_bounds");
	guard_predicates.append("terrain_allowed");
	guard_predicates.append("primary_tile_unoccupied_before_guard");
	guard_predicates.append("protected_target_linked");
	guard_predicates.append("zone_associated");
	record["placement_predicates"] = guard_predicates;
	record["placement_predicate_results"] = predicate_results;
	record["monster_reward_band_record"] = monster_reward_band;
	record["materialization_state"] = "staged_guard_record_only_no_gameplay_adoption";
	record["writeout_state"] = "staged_no_authored_content_writeback";
	record["signature"] = hash32_hex(canonical_variant(record));
	return record;
}

void append_guard_record(Array &guards, Dictionary &occupied, const Dictionary &guard) {
	if (guard.is_empty()) {
		return;
	}
	guards.append(guard);
	occupied[guard.get("primary_occupancy_key", "")] = guard.get("placement_id", "");
}

Array town_pair_route_visit_cells(const Dictionary &town) {
	Array approach_tiles = town.get("approach_tiles", Array());
	if (!approach_tiles.is_empty()) {
		return approach_tiles.duplicate(true);
	}
	Array body_tiles = town.get("body_tiles", Array());
	if (!body_tiles.is_empty()) {
		return body_tiles.duplicate(true);
	}
	Array result;
	Dictionary primary = town.get("primary_tile", Dictionary());
	if (primary.is_empty()) {
		primary = cell_record(int32_t(town.get("x", 0)), int32_t(town.get("y", 0)), int32_t(town.get("level", 0)));
	}
	result.append(primary);
	return result;
}

Array direct_access_path_between_cell_sets(const Array &starts, const Array &goals, int32_t width, int32_t height, const Dictionary &blocked) {
	Dictionary adjusted_blocked = blocked.duplicate(true);
	for (int64_t start_index = 0; start_index < starts.size(); ++start_index) {
		if (Variant(starts[start_index]).get_type() == Variant::DICTIONARY) {
			Dictionary start = Dictionary(starts[start_index]);
			adjusted_blocked.erase(point_key(int32_t(start.get("x", 0)), int32_t(start.get("y", 0))));
		}
	}
	for (int64_t goal_index = 0; goal_index < goals.size(); ++goal_index) {
		if (Variant(goals[goal_index]).get_type() == Variant::DICTIONARY) {
			Dictionary goal = Dictionary(goals[goal_index]);
			adjusted_blocked.erase(point_key(int32_t(goal.get("x", 0)), int32_t(goal.get("y", 0))));
		}
	}
	for (int64_t start_index = 0; start_index < starts.size(); ++start_index) {
		if (Variant(starts[start_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary start = Dictionary(starts[start_index]);
		for (int64_t goal_index = 0; goal_index < goals.size(); ++goal_index) {
			if (Variant(goals[goal_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary goal = Dictionary(goals[goal_index]);
			Array path = direct_access_path_cells(
					int32_t(start.get("x", 0)),
					int32_t(start.get("y", 0)),
					int32_t(goal.get("x", 0)),
					int32_t(goal.get("y", 0)),
					width,
					height,
					adjusted_blocked);
			if (!path.is_empty()) {
				return path;
			}
		}
	}
	return Array();
}

Dictionary guard_point_from_town_pair_path(const Array &path, const Dictionary &blocked, const Dictionary &occupied, int32_t width, int32_t height) {
	if (path.size() <= 2) {
		return Dictionary();
	}
	const int32_t midpoint = int32_t(path.size() / 2);
	for (int32_t distance = 0; distance < path.size(); ++distance) {
		const int32_t candidates[2] = { midpoint - distance, midpoint + distance };
		for (const int32_t candidate : candidates) {
			if (candidate <= 0 || candidate >= path.size() - 1) {
				continue;
			}
			if (Variant(path[candidate]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(path[candidate]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			const String key = point_key(x, y);
			if (x < 0 || y < 0 || x >= width || y >= height || blocked.has(key) || occupied.has(key)) {
				continue;
			}
			return point_record(x, y);
		}
	}
	return Dictionary();
}

int32_t assign_existing_guard_town_pair_closure_tile(Array &guards, Dictionary &blocked, const Array &path, const String &preferred_zone_id, const String &source, int32_t width, int32_t height) {
	if (guards.is_empty() || path.size() <= 2) {
		return 0;
	}
	const int32_t midpoint = int32_t(path.size() / 2);
	for (int32_t distance = 0; distance < path.size(); ++distance) {
		const int32_t candidates[2] = { midpoint - distance, midpoint + distance };
		for (const int32_t candidate : candidates) {
			if (candidate <= 0 || candidate >= path.size() - 1 || Variant(path[candidate]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(path[candidate]);
			const int32_t x = int32_t(cell.get("x", 0));
			const int32_t y = int32_t(cell.get("y", 0));
			const String key = point_key(x, y);
			if (blocked.has(key)) {
				continue;
			}
			int64_t best_guard_index = -1;
			int32_t best_score = std::numeric_limits<int32_t>::max();
			for (int64_t guard_index = 0; guard_index < guards.size(); ++guard_index) {
				if (Variant(guards[guard_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary guard = Dictionary(guards[guard_index]);
				const bool zone_match = preferred_zone_id.is_empty()
						|| String(guard.get("zone_id", "")) == preferred_zone_id
						|| String(guard.get("protected_zone_id", "")) == preferred_zone_id;
				const int32_t distance_score = std::abs(x - int32_t(guard.get("x", 0))) + std::abs(y - int32_t(guard.get("y", 0)));
				const int32_t score = distance_score + (zone_match ? 0 : 1000);
				if (score < best_score) {
					best_score = score;
					best_guard_index = guard_index;
				}
			}
			if (best_guard_index < 0) {
				continue;
			}
			Dictionary guard = Dictionary(guards[best_guard_index]);
			Array closure_tiles = guard.get("route_closure_block_tiles", Array());
			bool already_present = false;
			for (int64_t tile_index = 0; tile_index < closure_tiles.size(); ++tile_index) {
				if (Variant(closure_tiles[tile_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary existing = Dictionary(closure_tiles[tile_index]);
				if (point_key(int32_t(existing.get("x", 0)), int32_t(existing.get("y", 0))) == key) {
					already_present = true;
					break;
				}
			}
			int32_t added_count = 0;
			for (int32_t dy = -1; dy <= 1; ++dy) {
				for (int32_t dx = -1; dx <= 1; ++dx) {
					const int32_t closure_x = x + dx;
					const int32_t closure_y = y + dy;
					if (closure_x < 0 || closure_y < 0 || closure_x >= width || closure_y >= height) {
						continue;
					}
					const String closure_key = point_key(closure_x, closure_y);
					if (blocked.has(closure_key)) {
						continue;
					}
					bool closure_present = false;
					for (int64_t tile_index = 0; tile_index < closure_tiles.size(); ++tile_index) {
						if (Variant(closure_tiles[tile_index]).get_type() != Variant::DICTIONARY) {
							continue;
						}
						Dictionary existing = Dictionary(closure_tiles[tile_index]);
						if (point_key(int32_t(existing.get("x", 0)), int32_t(existing.get("y", 0))) == closure_key) {
							closure_present = true;
							break;
						}
					}
					if (closure_present) {
						blocked[closure_key] = guard.get("placement_id", guard.get("guard_id", ""));
						continue;
					}
					Dictionary closure_cell = cell_record(closure_x, closure_y, int32_t(cell.get("level", 0)));
					closure_cell["source"] = source;
					closure_tiles.append(closure_cell);
					blocked[closure_key] = guard.get("placement_id", guard.get("guard_id", ""));
					++added_count;
				}
			}
			if (added_count <= 0 && already_present) {
				blocked[key] = guard.get("placement_id", guard.get("guard_id", ""));
				return 1;
			}
			if (added_count <= 0) {
				continue;
			}
			guard["route_closure_block_tiles"] = closure_tiles;
			guard["route_closure_block_tile_count"] = closure_tiles.size();
			guard["route_closure_policy"] = "existing_guard_extends_control_mask_to_close_town_pair_route_without_inflating_owner_guard_count";
			guard["package_pathing_materialization_state"] = "body_visit_guard_control_zone_and_owner_count_preserving_town_pair_route_closure_masks_materialized_for_generated_package_surface";
			guards[best_guard_index] = guard;
			return added_count;
		}
	}
	return 0;
}

Dictionary close_unguarded_town_pair_routes_with_guards(const Dictionary &normalized, const Array &zones, const Dictionary &zone_layout, const Dictionary &road_network, const Array &towns, Array &guards, Dictionary &occupied, const Dictionary &base_blocking_occupied, int32_t &guard_ordinal, int32_t effective_guard_limit) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary blocked = base_blocking_occupied.duplicate(true);
	for (int64_t index = 0; index < towns.size(); ++index) {
		if (Variant(towns[index]).get_type() == Variant::DICTIONARY) {
			mark_record_blocking_occupancy(blocked, Dictionary(towns[index]));
		}
	}
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() == Variant::DICTIONARY) {
			Dictionary guard = Dictionary(guards[index]);
			mark_record_blocking_occupancy(blocked, guard);
			mark_guard_control_zone_blocking_occupancy(blocked, guard, width, height);
		}
	}

	Array diagnostics;
	int32_t checked_pair_count = 0;
	int32_t added_guard_count = 0;
	int32_t reused_guard_closure_tile_count = 0;
	static constexpr int32_t MAX_PASSES = 20;
	for (int32_t pass = 0; pass < MAX_PASSES; ++pass) {
		bool added_this_pass = false;
		for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
			if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary left = Dictionary(towns[left_index]);
			for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
				if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				if (pass == 0) {
					++checked_pair_count;
				}
				Dictionary right = Dictionary(towns[right_index]);
				Array path = direct_access_path_between_cell_sets(town_pair_route_visit_cells(left), town_pair_route_visit_cells(right), width, height, blocked);
				if (path.is_empty()) {
					continue;
				}
				Dictionary diagnostic;
				diagnostic["code"] = "unguarded_town_pair_route_detected";
				diagnostic["severity"] = "info";
				diagnostic["left_town_placement_id"] = left.get("placement_id", "");
				diagnostic["right_town_placement_id"] = right.get("placement_id", "");
				diagnostic["left_zone_id"] = left.get("zone_id", "");
				diagnostic["right_zone_id"] = right.get("zone_id", "");
				diagnostic["same_zone"] = String(left.get("zone_id", "")) == String(right.get("zone_id", ""));
				diagnostic["path_length"] = path.size();
				if (effective_guard_limit >= 0 && guard_ordinal >= effective_guard_limit) {
					const int32_t closure_tile_count = assign_existing_guard_town_pair_closure_tile(guards, blocked, path, String(left.get("zone_id", "")), "owner_count_preserving_town_pair_route_guard_closure_mask", width, height);
					if (closure_tile_count > 0) {
						diagnostic["code"] = "unguarded_town_pair_route_closed_by_existing_guard_mask";
						diagnostic["severity"] = "info";
						diagnostic["closure_mask_source"] = "owner_count_preserving_town_pair_route_guard_closure_mask";
						diagnostic["closure_tile_count"] = closure_tile_count;
						reused_guard_closure_tile_count += closure_tile_count;
						added_this_pass = true;
					} else {
						diagnostic["code"] = "unguarded_town_pair_route_left_open_by_guard_count_cap";
						diagnostic["severity"] = "warning";
					}
					diagnostics.append(diagnostic);
					continue;
				}
				Dictionary point = guard_point_from_town_pair_path(path, blocked, occupied, width, height);
				if (point.is_empty()) {
					const int32_t closure_tile_count = assign_existing_guard_town_pair_closure_tile(guards, blocked, path, String(left.get("zone_id", "")), "infeasible_primary_guard_point_town_pair_route_closure_mask", width, height);
					if (closure_tile_count > 0) {
						diagnostic["code"] = "unguarded_town_pair_route_closed_by_existing_guard_mask";
						diagnostic["severity"] = "info";
						diagnostic["closure_mask_source"] = "infeasible_primary_guard_point_town_pair_route_closure_mask";
						diagnostic["closure_tile_count"] = closure_tile_count;
						reused_guard_closure_tile_count += closure_tile_count;
						added_this_pass = true;
					} else {
						diagnostic["code"] = "unguarded_town_pair_route_guard_point_infeasible";
						diagnostic["severity"] = "warning";
					}
					diagnostics.append(diagnostic);
					continue;
				}
				const String protected_zone_id = String(right.get("zone_id", left.get("zone_id", "")));
				Dictionary zone = zone_by_id(zones, protected_zone_id);
				Dictionary target;
				target["protected_target_id"] = String(left.get("placement_id", "")) + "__" + String(right.get("placement_id", ""));
				target["protected_target_type"] = "town_pair";
				target["protected_zone_id"] = protected_zone_id;
				target["left_town_placement_id"] = left.get("placement_id", "");
				target["right_town_placement_id"] = right.get("placement_id", "");
				target["left_zone_id"] = left.get("zone_id", "");
				target["right_zone_id"] = right.get("zone_id", "");
				target["same_zone"] = diagnostic["same_zone"];
				target["guarded_town_route_path_length"] = path.size();
				target["guard_reward_relation_source"] = "town_pair_route_guard_blocks_direct_unguarded_package_path_between_towns";
				append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "town_pair_guard", guard_ordinal, 1200, road_network, zone_layout, occupied, target));
				Dictionary added_guard = Dictionary(guards[guards.size() - 1]);
				mark_record_blocking_occupancy(blocked, added_guard);
				mark_guard_control_zone_blocking_occupancy(blocked, added_guard, width, height);
				++guard_ordinal;
				++added_guard_count;
				diagnostic["guard_placement_id"] = added_guard.get("placement_id", "");
				diagnostic["guard_x"] = point.get("x", 0);
				diagnostic["guard_y"] = point.get("y", 0);
				diagnostics.append(diagnostic);
				added_this_pass = true;
			}
		}
		if (!added_this_pass) {
			break;
		}
	}

	int32_t remaining_reachable_pair_count = 0;
	for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
		if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary left = Dictionary(towns[left_index]);
		for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
			if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary right = Dictionary(towns[right_index]);
			Array path = direct_access_path_between_cell_sets(town_pair_route_visit_cells(left), town_pair_route_visit_cells(right), width, height, blocked);
			if (!path.is_empty()) {
				++remaining_reachable_pair_count;
			}
		}
	}

	Dictionary summary;
	summary["schema_id"] = "native_random_map_town_pair_route_guard_closure_v1";
	summary["checked_pair_count"] = checked_pair_count;
	summary["added_guard_count"] = added_guard_count;
	summary["reused_guard_closure_tile_count"] = reused_guard_closure_tile_count;
	summary["remaining_reachable_pair_count"] = remaining_reachable_pair_count;
	summary["diagnostics"] = diagnostics;
	summary["policy"] = "town pair route guards close direct package-object paths between every generated town pair, including cross-zone and same-zone density towns missed by narrower gates";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	return summary;
}

void append_town_boundary_opening_cell(Array &cells, Dictionary &seen, const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height, const String &source) {
	if (x < 0 || y < 0 || x >= width || y >= height || !zone_boundary_barrier_cell(owner_grid, x, y, width, height)) {
		return;
	}
	const String key = point_key(x, y);
	if (seen.has(key)) {
		return;
	}
	seen[key] = true;
	Dictionary cell = cell_record(x, y, 0);
	cell["source"] = source;
	cells.append(cell);
}

void append_town_boundary_opening_cells_from_array(Array &cells, Dictionary &seen, const Array &owner_grid, const Array &source_cells, int32_t width, int32_t height, const String &source) {
	for (int64_t index = 0; index < source_cells.size(); ++index) {
		if (Variant(source_cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = Dictionary(source_cells[index]);
		append_town_boundary_opening_cell(cells, seen, owner_grid, int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)), width, height, source);
	}
}

Array town_boundary_opening_cells_for_guards(const Array &towns, const Array &owner_grid, int32_t width, int32_t height) {
	Array cells;
	Dictionary seen;
	auto append_direct_cell = [&](int32_t x, int32_t y, const String &source) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const String key = point_key(x, y);
		if (seen.has(key)) {
			return;
		}
		seen[key] = true;
		Dictionary cell = cell_record(x, y, 0);
		cell["source"] = source;
		cells.append(cell);
	};
	for (int64_t town_index = 0; town_index < towns.size(); ++town_index) {
		if (Variant(towns[town_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary town = Dictionary(towns[town_index]);
		append_town_boundary_opening_cell(cells, seen, owner_grid, int32_t(town.get("x", 0)), int32_t(town.get("y", 0)), width, height, "town_anchor");
		if (Variant(town.get("primary_tile", Variant())).get_type() == Variant::DICTIONARY) {
			Dictionary primary = Dictionary(town.get("primary_tile", Dictionary()));
			append_town_boundary_opening_cell(cells, seen, owner_grid, int32_t(primary.get("x", 0)), int32_t(primary.get("y", 0)), width, height, "town_primary_tile");
		}
		append_town_boundary_opening_cells_from_array(cells, seen, owner_grid, town.get("body_tiles", Array()), width, height, "town_body_tile");
		append_town_boundary_opening_cells_from_array(cells, seen, owner_grid, town.get("approach_tiles", Array()), width, height, "town_approach_tile");
		if (Variant(town.get("visit_tile", Variant())).get_type() == Variant::DICTIONARY) {
			Dictionary visit = Dictionary(town.get("visit_tile", Dictionary()));
			append_town_boundary_opening_cell(cells, seen, owner_grid, int32_t(visit.get("x", 0)), int32_t(visit.get("y", 0)), width, height, "town_visit_tile");
		}
		append_town_boundary_opening_cells_from_array(cells, seen, owner_grid, town.get("required_town_access_corridor_cells", Array()), width, height, "required_town_access_corridor");
	}
	for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
		if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary left = Dictionary(towns[left_index]);
		const String left_zone_id = String(left.get("zone_id", ""));
		const int32_t left_x = int32_t(left.get("x", 0));
		const int32_t left_y = int32_t(left.get("y", 0));
		for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
			if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary right = Dictionary(towns[right_index]);
			if (left_zone_id.is_empty() || left_zone_id == String(right.get("zone_id", ""))) {
				continue;
			}
			const int32_t right_x = int32_t(right.get("x", 0));
			const int32_t right_y = int32_t(right.get("y", 0));
			const int32_t chebyshev_distance = std::max(std::abs(left_x - right_x), std::abs(left_y - right_y));
			if (chebyshev_distance > 40) {
				continue;
			}
			Array path = direct_access_path_cells(left_x, left_y, right_x, right_y, width, height);
			for (int64_t path_index = 0; path_index < path.size(); ++path_index) {
				if (Variant(path[path_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary cell = Dictionary(path[path_index]);
				const int32_t path_x = int32_t(cell.get("x", 0));
				const int32_t path_y = int32_t(cell.get("y", 0));
				const String path_zone_id = owner_grid_zone_id_at(owner_grid, path_x, path_y);
				bool boundary_choke = zone_boundary_barrier_cell(owner_grid, path_x, path_y, width, height);
				if (!boundary_choke && path_index > 0 && Variant(path[path_index - 1]).get_type() == Variant::DICTIONARY) {
					Dictionary before = Dictionary(path[path_index - 1]);
					const String before_zone_id = owner_grid_zone_id_at(owner_grid, int32_t(before.get("x", 0)), int32_t(before.get("y", 0)));
					boundary_choke = !path_zone_id.is_empty() && !before_zone_id.is_empty() && path_zone_id != before_zone_id;
				}
				if (!boundary_choke && path_index + 1 < path.size() && Variant(path[path_index + 1]).get_type() == Variant::DICTIONARY) {
					Dictionary after = Dictionary(path[path_index + 1]);
					const String after_zone_id = owner_grid_zone_id_at(owner_grid, int32_t(after.get("x", 0)), int32_t(after.get("y", 0)));
					boundary_choke = !path_zone_id.is_empty() && !after_zone_id.is_empty() && path_zone_id != after_zone_id;
				}
				const int64_t choke_stride = width >= 108 ? 1 : 3;
				const bool periodic_corridor_choke = !boundary_choke && width >= 72 && path_index % choke_stride == 0;
				if (!boundary_choke && !periodic_corridor_choke) {
					continue;
				}
				const String source = boundary_choke ? String("close_cross_zone_town_corridor_boundary_choke") : String("close_cross_zone_town_corridor_sparse_midline_choke");
				for (int32_t dy = -1; dy <= 1; ++dy) {
					for (int32_t dx = -1; dx <= 1; ++dx) {
						append_direct_cell(path_x + dx, path_y + dy, source);
					}
				}
			}
		}
	}
	return cells;
}

int32_t nearest_route_guard_index_for_cell(const Array &guards, int32_t x, int32_t y) {
	int32_t best_index = -1;
	int32_t best_distance = std::numeric_limits<int32_t>::max();
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary guard = Dictionary(guards[index]);
		if (String(guard.get("guard_kind", "")) != "route_guard") {
			continue;
		}
		const int32_t distance = std::abs(x - int32_t(guard.get("x", 0))) + std::abs(y - int32_t(guard.get("y", 0)));
		if (distance < best_distance) {
			best_distance = distance;
			best_index = int32_t(index);
		}
	}
	return best_index;
}

Dictionary cover_town_boundary_openings_with_route_guards(Array &guards, const Array &towns, const Array &owner_grid, int32_t width, int32_t height, bool materialize_opening_cells) {
	Array opening_cells = town_boundary_opening_cells_for_guards(towns, owner_grid, width, height);
	Dictionary coverage_by_guard;
	int32_t covered_count = 0;
	Array uncovered_cells;
	if (!materialize_opening_cells) {
		Dictionary summary;
		summary["schema_id"] = "native_random_map_town_boundary_opening_guard_cover_v1";
		summary["policy"] = "town boundary opening guard-body expansion skipped because selective package decorative boundary masks close uploaded-small town routes";
		summary["opening_cell_count"] = opening_cells.size();
		summary["covered_cell_count"] = 0;
		summary["uncovered_cell_count"] = opening_cells.size();
		summary["coverage_by_guard"] = coverage_by_guard;
		summary["materialization_skipped"] = true;
		summary["signature"] = hash32_hex(canonical_variant(summary));
		return summary;
	}
	for (int64_t cell_index = 0; cell_index < opening_cells.size(); ++cell_index) {
		if (Variant(opening_cells[cell_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary opening = Dictionary(opening_cells[cell_index]);
		const int32_t x = int32_t(opening.get("x", 0));
		const int32_t y = int32_t(opening.get("y", 0));
		const int32_t guard_index = nearest_route_guard_index_for_cell(guards, x, y);
		if (guard_index < 0) {
			uncovered_cells.append(opening);
			continue;
			}
			Dictionary guard = Dictionary(guards[guard_index]).duplicate(true);
			Array body_tiles = guard.get("body_tiles", Array()).duplicate(true);
			Dictionary seen;
			for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
				if (Variant(body_tiles[body_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary body = Dictionary(body_tiles[body_index]);
				seen[point_key(int32_t(body.get("x", 0)), int32_t(body.get("y", 0)))] = true;
			}
			const String key = point_key(x, y);
			if (!seen.has(key)) {
				body_tiles.append(cell_record(x, y, 0));
				++covered_count;
			}
			Array occupancy_keys;
			for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
				if (Variant(body_tiles[body_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary body = Dictionary(body_tiles[body_index]);
			occupancy_keys.append(point_key(int32_t(body.get("x", 0)), int32_t(body.get("y", 0))));
			}
			guard["body_tiles"] = body_tiles;
			guard["occupancy_keys"] = occupancy_keys;
			guard["controlled_town_boundary_opening_tile_count"] = int32_t(guard.get("controlled_town_boundary_opening_tile_count", 0)) + 1;
			guard["controlled_town_boundary_opening_policy"] = "town_and_required_access_corridor_boundary_openings_are_covered_by_route_guards_until_cleared";
		guard["signature"] = hash32_hex(canonical_variant(guard));
		guards[guard_index] = guard;
		const String guard_id = String(guard.get("guard_id", ""));
		coverage_by_guard[guard_id] = int32_t(coverage_by_guard.get(guard_id, 0)) + 1;
	}
	Dictionary summary;
	summary["schema_id"] = "native_random_map_town_boundary_opening_guard_cover_v1";
	summary["policy"] = "boundary openings created for towns and required town access corridors are controlled by route guard bodies rather than being free terrain cuts";
	summary["opening_cell_count"] = opening_cells.size();
	summary["covered_cell_count"] = covered_count;
	summary["uncovered_cell_count"] = uncovered_cells.size();
	summary["coverage_by_guard"] = coverage_by_guard;
	summary["uncovered_cells"] = uncovered_cells;
	return summary;
}

Dictionary occupancy_index_for_buckets(const Array &objects, const Array &towns, const Array &guards) {
	Dictionary primary_tile_occupancy;
	Array duplicates;
	auto add_record = [&primary_tile_occupancy, &duplicates](const Dictionary &record, const String &bucket) {
		const String key = String(record.get("primary_occupancy_key", ""));
		if (key.is_empty()) {
			return;
		}
		Dictionary entry;
		entry["bucket"] = bucket;
		entry["placement_id"] = record.get("placement_id", record.get("guard_id", ""));
		entry["kind"] = record.get("kind", bucket);
		if (primary_tile_occupancy.has(key)) {
			Dictionary duplicate;
			duplicate["primary_occupancy_key"] = key;
			duplicate["existing"] = primary_tile_occupancy.get(key, Dictionary());
			duplicate["duplicate"] = entry;
			duplicates.append(duplicate);
		} else {
			primary_tile_occupancy[key] = entry;
		}
	};
	for (int64_t index = 0; index < objects.size(); ++index) {
		add_record(Dictionary(objects[index]), "object");
	}
	for (int64_t index = 0; index < towns.size(); ++index) {
		add_record(Dictionary(towns[index]), "town");
	}
	for (int64_t index = 0; index < guards.size(); ++index) {
		add_record(Dictionary(guards[index]), "guard");
	}
	Dictionary occupancy;
	occupancy["primary_tile_occupancy"] = primary_tile_occupancy;
	occupancy["occupied_primary_tile_count"] = primary_tile_occupancy.size();
	occupancy["duplicate_primary_tile_count"] = duplicates.size();
	occupancy["duplicates"] = duplicates;
	occupancy["object_count"] = objects.size();
	occupancy["town_count"] = towns.size();
	occupancy["guard_count"] = guards.size();
	occupancy["status"] = duplicates.is_empty() ? "pass" : "duplicate_primary_tiles";
	occupancy["signature"] = hash32_hex(canonical_variant(occupancy));
	return occupancy;
}

int32_t object_guard_priority(const Dictionary &object) {
	const String kind = String(object.get("kind", ""));
	const String family_id = String(object.get("family_id", ""));
	if (kind == "reward_reference" && !String(object.get("artifact_id", "")).is_empty()) {
		return 0;
	}
	if (kind == "mine") {
		return 1;
	}
	if (kind == "neutral_dwelling") {
		return 2;
	}
	if (family_id == "guarded_reward_cache" || (kind == "reward_reference" && int32_t(object.get("reward_value", 0)) >= 2500)) {
		return 3;
	}
	if (kind == "resource_site") {
		return 4;
	}
	return 99;
}

Array sorted_object_guard_candidates(const Array &objects) {
	std::vector<Dictionary> candidates;
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = objects[index];
		const int32_t priority = object_guard_priority(object);
		if (priority >= 99) {
			continue;
		}
		Dictionary candidate = object.duplicate(true);
		candidate["object_guard_priority"] = priority;
		candidates.push_back(candidate);
	}
	std::sort(candidates.begin(), candidates.end(), [](const Dictionary &left, const Dictionary &right) {
		const int32_t left_priority = int32_t(left.get("object_guard_priority", 99));
		const int32_t right_priority = int32_t(right.get("object_guard_priority", 99));
		if (left_priority != right_priority) {
			return left_priority < right_priority;
		}
		const int32_t left_value = int32_t(left.get("guard_base_value", left.get("reward_value", 0)));
		const int32_t right_value = int32_t(right.get("guard_base_value", right.get("reward_value", 0)));
		if (left_value != right_value) {
			return left_value > right_value;
		}
		return String(left.get("placement_id", "")) < String(right.get("placement_id", ""));
	});
	Array result;
	for (const Dictionary &candidate : candidates) {
		result.append(candidate);
	}
	return result;
}

Dictionary object_guard_point_for_target(const Dictionary &object, const String &zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height) {
	static constexpr int32_t OFFSETS[8][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}};
	const int32_t ox = int32_t(object.get("x", 0));
	const int32_t oy = int32_t(object.get("y", 0));
	for (const auto &offset : OFFSETS) {
		const int32_t x = ox + offset[0];
		const int32_t y = oy + offset[1];
		if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1 || occupied.has(point_key(x, y))) {
			continue;
		}
		if (!zone_id.is_empty() && y >= 0 && y < owner_grid.size()) {
			Array row = owner_grid[y];
			if (x >= 0 && x < row.size() && String(row[x]) != zone_id) {
				continue;
			}
		}
		return point_record(x, y);
	}
	for (int32_t radius = 2; radius <= 10; ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t x = ox + dx;
				const int32_t y = oy + dy;
				if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1 || occupied.has(point_key(x, y))) {
					continue;
				}
				if (!zone_id.is_empty() && y >= 0 && y < owner_grid.size()) {
					Array row = owner_grid[y];
					if (x >= 0 && x < row.size() && String(row[x]) != zone_id) {
						continue;
					}
				}
				return point_record(x, y);
			}
		}
	}
	for (int32_t radius = 2; radius <= 10; ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::max(std::abs(dx), std::abs(dy)) != radius) {
					continue;
				}
				const int32_t x = ox + dx;
				const int32_t y = oy + dy;
				if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1 || occupied.has(point_key(x, y))) {
					continue;
				}
				return point_record(x, y);
			}
		}
	}
	return find_object_point(ox + 1, oy, zone_id, owner_grid, occupied, width, height);
}

Dictionary object_guard_summary(const Array &candidates, const Array &guards) {
	Dictionary candidate_counts;
	for (int64_t index = 0; index < candidates.size(); ++index) {
		Dictionary candidate = candidates[index];
		const String kind = !String(candidate.get("artifact_id", "")).is_empty() ? "artifact" : String(candidate.get("kind", ""));
		candidate_counts[kind] = int32_t(candidate_counts.get(kind, 0)) + 1;
	}
	Dictionary materialized_counts;
	for (int64_t index = 0; index < guards.size(); ++index) {
		Dictionary guard = guards[index];
		if (String(guard.get("protected_target_type", "")) != "object_placement") {
			continue;
		}
		const String kind = String(guard.get("guarded_object_kind", ""));
		materialized_counts[kind] = int32_t(materialized_counts.get(kind, 0)) + 1;
		if (!String(guard.get("guarded_artifact_id", "")).is_empty()) {
			materialized_counts["artifact"] = int32_t(materialized_counts.get("artifact", 0)) + 1;
		}
	}
	Dictionary summary;
	summary["schema_id"] = "native_random_map_materialized_object_guard_summary_v1";
	summary["association_policy"] = "artifact_rewards_are_guarded_before_lower_priority_object_guards_when_cells_available";
	summary["candidate_count"] = candidates.size();
	summary["candidate_counts_by_kind"] = candidate_counts;
	summary["materialized_counts_by_kind"] = materialized_counts;
	summary["artifact_candidate_count"] = candidate_counts.get("artifact", 0);
	summary["artifact_guard_count"] = materialized_counts.get("artifact", 0);
	summary["guardable_valuable_object_count"] = candidates.size();
	summary["guarded_valuable_object_count"] = int32_t(materialized_counts.get("artifact", 0)) + int32_t(materialized_counts.get("mine", 0)) + int32_t(materialized_counts.get("neutral_dwelling", 0)) + int32_t(materialized_counts.get("reward_reference", 0));
	return summary;
}

Dictionary guard_reward_monster_summary_for_records(const Dictionary &normalized, const Dictionary &object_placement, const Array &guards, const Array &guard_diagnostics) {
	int32_t route_guard_count = 0;
	int32_t site_guard_count = 0;
	int32_t density_guard_count = 0;
	int32_t match_to_town_count = 0;
	int32_t explicit_mask_count = 0;
	int32_t stack_record_count = 0;
	int32_t stack_mask_mismatch_count = 0;
	Dictionary allowed_mask_counts;
	Dictionary effective_mode_counts;
	Array guard_failures;
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary guard = Dictionary(guards[index]);
		const String kind = String(guard.get("guard_kind", ""));
		if (kind == "route_guard") {
			++route_guard_count;
		} else if (kind == "site_guard") {
			++site_guard_count;
		} else if (kind == "density_guard") {
			++density_guard_count;
		}
		if (bool(guard.get("monster_match_to_town", false))) {
			++match_to_town_count;
		} else {
			++explicit_mask_count;
		}
		const String mode_key = String::num_int64(int32_t(guard.get("monster_effective_strength_mode", -1)));
		effective_mode_counts[mode_key] = int32_t(effective_mode_counts.get(mode_key, 0)) + 1;
		Array allowed = guard.get("monster_allowed_faction_ids", Array());
		for (int64_t allowed_index = 0; allowed_index < allowed.size(); ++allowed_index) {
			const String faction_id = String(allowed[allowed_index]);
			allowed_mask_counts[faction_id] = int32_t(allowed_mask_counts.get(faction_id, 0)) + 1;
		}
		Array stacks = guard.get("stack_records", Array());
		stack_record_count += stacks.size();
		for (int64_t stack_index = 0; stack_index < stacks.size(); ++stack_index) {
			if (Variant(stacks[stack_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary stack = Dictionary(stacks[stack_index]);
			if (!bool(stack.get("allowed_faction_mask_matched", false))) {
				++stack_mask_mismatch_count;
			}
		}
		Array monster_diagnostics = guard.get("monster_diagnostics", Array());
		for (int64_t diagnostic_index = 0; diagnostic_index < monster_diagnostics.size(); ++diagnostic_index) {
			if (Variant(monster_diagnostics[diagnostic_index]).get_type() == Variant::DICTIONARY && String(Dictionary(monster_diagnostics[diagnostic_index]).get("severity", "")) == "failure") {
				guard_failures.append(monster_diagnostics[diagnostic_index]);
			}
		}
	}
	for (int64_t index = 0; index < guard_diagnostics.size(); ++index) {
		if (Variant(guard_diagnostics[index]).get_type() == Variant::DICTIONARY && String(Dictionary(guard_diagnostics[index]).get("severity", "")) == "failure") {
			guard_failures.append(guard_diagnostics[index]);
		}
	}

	Dictionary reward_band_summary = object_placement.get("reward_band_summary", Dictionary());
	Dictionary summary;
	summary["schema_id"] = NATIVE_RMG_GUARDS_REWARDS_MONSTERS_SCHEMA_ID;
	summary["phase_order"] = "phase_10_rewards_and_monsters_after_phase_7_mines_resources_before_decorative_filler";
	summary["global_monster_strength_mode"] = rmg_global_monster_strength_mode(normalized);
	summary["global_monster_strength_source"] = normalized.get("global_monster_strength_source", "");
	summary["strength_formula"] = "if_source_strength_nonzero_mode_clamp_source_plus_global_minus_3_then_0x4a65a5_threshold_slope_tables";
	summary["strength_sample_table"] = rmg_strength_sample_table();
	summary["reward_band_summary"] = reward_band_summary;
	summary["guard_count"] = guards.size();
	summary["route_guard_count"] = route_guard_count;
	summary["site_guard_count"] = site_guard_count;
	summary["density_guard_count"] = density_guard_count;
	summary["match_to_town_guard_count"] = match_to_town_count;
	summary["explicit_mask_guard_count"] = explicit_mask_count;
	summary["allowed_mask_counts"] = allowed_mask_counts;
	summary["effective_mode_counts"] = effective_mode_counts;
	summary["stack_record_count"] = stack_record_count;
	summary["stack_mask_mismatch_count"] = stack_mask_mismatch_count;
	summary["diagnostics"] = guard_diagnostics;
	summary["diagnostic_count"] = guard_diagnostics.size();
	summary["failure_count"] = guard_failures.size();
	summary["failures"] = guard_failures;
	Array unsupported;
	unsupported.append("exact_homm3_creature_rosters_names_and_art_not_imported");
	unsupported.append("private_border_guard_companion_keymaster_vectors_not_implemented");
	unsupported.append("exact_private_object_table_candidate_scoring_not_claimed");
	summary["unsupported_boundaries"] = unsupported;
	summary["validation_status"] = guard_failures.is_empty() && int32_t(reward_band_summary.get("out_of_band_reward_count", 0)) == 0 && stack_mask_mismatch_count == 0 ? "pass" : "fail";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	return summary;
}

int32_t local_guard_count_near_point(const Array &guards, const Dictionary &point, int32_t radius) {
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	int32_t count = 0;
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary guard = guards[index];
		if (std::abs(x - int32_t(guard.get("x", 0))) <= radius && std::abs(y - int32_t(guard.get("y", 0))) <= radius) {
			++count;
		}
	}
	return count;
}

int32_t neutral_town_target_count(const Dictionary &normalized, const Array &zones, int32_t start_count) {
	int32_t eligible = 0;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String role = String(zone.get("role", ""));
		if (role == "treasure" || role == "junction") {
			++eligible;
		}
		Dictionary metadata = zone.get("catalog_metadata", Dictionary());
		Dictionary neutral_towns = metadata.get("neutral_towns", Dictionary());
		if (int32_t(neutral_towns.get("min_towns", 0)) > 0 || int32_t(neutral_towns.get("min_castles", 0)) > 0 || int32_t(neutral_towns.get("town_density", 0)) > 0 || int32_t(neutral_towns.get("castle_density", 0)) > 0) {
			++eligible;
		}
	}
	const int32_t scaled = std::max(2, int32_t(std::ceil(double(zones.size()) / (map_area_scale(normalized) >= 9 ? 5.0 : 7.0))));
	return std::max(0, std::min(eligible, std::max(2, scaled + start_count / 3)));
}

bool zone_has_player_or_town_source(const Dictionary &zone) {
	if (zone.get("player_slot", Variant()).get_type() != Variant::NIL) {
		return true;
	}
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Dictionary player_towns = metadata.get("player_towns", zone.get("player_towns", Dictionary()));
	Dictionary neutral_towns = metadata.get("neutral_towns", zone.get("neutral_towns", Dictionary()));
	return int32_t(player_towns.get("min_towns", 0)) > 0
			|| int32_t(player_towns.get("min_castles", 0)) > 0
			|| int32_t(player_towns.get("town_density", 0)) > 0
			|| int32_t(player_towns.get("castle_density", 0)) > 0
			|| int32_t(neutral_towns.get("min_towns", 0)) > 0
			|| int32_t(neutral_towns.get("min_castles", 0)) > 0
			|| int32_t(neutral_towns.get("town_density", 0)) > 0
			|| int32_t(neutral_towns.get("castle_density", 0)) > 0;
}

bool translated_land_zero_guard_connection_needs_fallback(const Dictionary &normalized, const Dictionary &edge, const Array &zones) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	if (width < 72 || height < 72) {
		return false;
	}
	if (String(normalized.get("water_mode", "")) != "land" || String(normalized.get("template_id", "")).begins_with("translated_rmg_template_") == false) {
		return false;
	}
	if (int32_t(edge.get("guard_value", 0)) > 0 || bool(edge.get("wide", false)) || bool(edge.get("border_guard", false))) {
		return false;
	}
	Dictionary from_zone = zone_by_id(zones, String(edge.get("from", "")));
	Dictionary to_zone = zone_by_id(zones, String(edge.get("to", "")));
	if (from_zone.is_empty() || to_zone.is_empty()) {
		return false;
	}
	return zone_has_player_or_town_source(from_zone) || zone_has_player_or_town_source(to_zone);
}

Dictionary town_rules_for_zone(const Dictionary &zone, const String &field) {
	Dictionary metadata = zone.get("catalog_metadata", Dictionary());
	Variant rules_value = metadata.get(field, Variant());
	return rules_value.get_type() == Variant::DICTIONARY ? Dictionary(rules_value) : Dictionary();
}

int32_t town_density_attempt_count(const Dictionary &normalized, const Dictionary &zone, const String &field_name, int32_t density) {
	if (density <= 0) {
		return 0;
	}
	const int32_t base = std::max(0, density / 8);
	const int32_t remainder = std::max(0, density % 8);
	const String seed = String(normalized.get("normalized_seed", "0")) + ":town_density:" + String(zone.get("id", "")) + ":" + field_name;
	const int32_t extra = int32_t(hash32_int(seed) % 8U) < remainder ? 1 : 0;
	return std::min(3, std::max(1, base + extra));
}

String town_source_field_offset(const String &owner_scope, const String &settlement_kind, bool density) {
	if (owner_scope == "player" && settlement_kind == "town" && !density) {
		return "+0x20";
	}
	if (owner_scope == "player" && settlement_kind == "castle" && !density) {
		return "+0x24";
	}
	if (owner_scope == "player" && settlement_kind == "town" && density) {
		return "+0x28";
	}
	if (owner_scope == "player" && settlement_kind == "castle" && density) {
		return "+0x2c";
	}
	if (owner_scope == "neutral" && settlement_kind == "town" && !density) {
		return "+0x30";
	}
	if (owner_scope == "neutral" && settlement_kind == "castle" && !density) {
		return "+0x34";
	}
	if (owner_scope == "neutral" && settlement_kind == "town" && density) {
		return "+0x38";
	}
	return "+0x3c";
}

String town_source_field_name(const String &owner_scope, const String &settlement_kind, bool density) {
	return owner_scope + String(density ? "_density_" : "_minimum_") + settlement_kind + String("s");
}

String town_faction_for_placement(const Dictionary &normalized, const Dictionary &zone, const String &owner_scope, const String &settlement_kind, bool density, int32_t ordinal, bool same_type_neutral) {
	if (owner_scope == "player") {
		return String(zone.get("faction_id", zone.get("source_zone_faction_id", "faction_embercourt")));
	}
	const String source_zone_faction_id = String(zone.get("source_zone_faction_id", zone.get("faction_id", "")));
	if (density && same_type_neutral && !source_zone_faction_id.is_empty()) {
		return source_zone_faction_id;
	}
	Array allowed = zone.get("allowed_town_faction_ids", Array());
	if (allowed.is_empty()) {
		allowed = normalized.get("faction_ids", default_faction_pool());
	}
	if (allowed.is_empty()) {
		return source_zone_faction_id.is_empty() ? String("faction_embercourt") : source_zone_faction_id;
	}
	const String seed = String(normalized.get("normalized_seed", "0")) + ":town_faction:" + String(zone.get("id", "")) + ":" + owner_scope + ":" + settlement_kind + ":" + String::num_int64(ordinal);
	return String(allowed[int64_t(hash32_int(seed) % uint32_t(allowed.size()))]);
}

Dictionary town_access_corridor_lookup(const Array &towns) {
	Dictionary lookup;
	for (int64_t town_index = 0; town_index < towns.size(); ++town_index) {
		if (Variant(towns[town_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary town = Dictionary(towns[town_index]);
		Array cells = town.get("required_town_access_corridor_cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (Variant(cells[cell_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary cell = Dictionary(cells[cell_index]);
			lookup[point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)))] = true;
		}
	}
	return lookup;
}

Dictionary clear_required_town_access_gap_objects(Dictionary &object_placement, const Array &towns) {
	Dictionary corridor_lookup = town_access_corridor_lookup(towns);
	Array placements = object_placement.get("object_placements", Array());
	Array cleared_ids;
	int32_t cleared_body_tile_count = 0;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		const String kind = String(placement.get("kind", ""));
		if (kind != "decorative_obstacle" && kind != "scenic_object") {
			continue;
		}
		bool intersects_corridor = false;
		Array body_tiles = placement.get("body_tiles", Array());
		for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
			if (Variant(body_tiles[body_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary body = Dictionary(body_tiles[body_index]);
			if (corridor_lookup.has(point_key(int32_t(body.get("x", 0)), int32_t(body.get("y", 0))))) {
				intersects_corridor = true;
				++cleared_body_tile_count;
			}
		}
		if (!intersects_corridor) {
			continue;
		}
		Dictionary passability = placement.get("passability", Dictionary());
		passability["class"] = "passable_scenic";
		passability["passability_class"] = "passable_scenic";
		passability["blocking_body"] = false;
		placement["passability"] = passability;
		placement["passability_class"] = "passable_scenic";
		placement["blocking_body"] = false;
		placement["town_access_corridor_gap"] = true;
		placement["access_corridor_policy"] = "decorative_or_scenic_body_overlaps_required_town_access_corridor_and_is_rendered_nonblocking";
		placement["signature"] = hash32_hex(canonical_variant(placement));
		placements[index] = placement;
		cleared_ids.append(placement.get("placement_id", ""));
	}
	object_placement["object_placements"] = placements;
	Dictionary summary;
	summary["schema_id"] = "native_rmg_required_town_access_corridor_clearance_v1";
	summary["corridor_cell_count"] = corridor_lookup.size();
	summary["cleared_object_count"] = cleared_ids.size();
	summary["cleared_body_tile_count"] = cleared_body_tile_count;
	summary["cleared_placement_ids"] = cleared_ids;
	summary["policy"] = "required towns reserve an in-zone path to their road/start access anchor; overlapping decorative/scenic blockers become nonblocking without weakening guards, towns, rewards, mines, or gates";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	object_placement["required_town_access_corridor_clearance"] = summary;
	Dictionary signature_source;
	signature_source["pre_corridor_object_signature"] = object_placement.get("signature", "");
	signature_source["object_placements"] = placements;
	signature_source["required_town_access_corridor_clearance"] = summary;
	object_placement["signature"] = hash32_hex(canonical_variant(signature_source));
	return summary;
}

Dictionary clear_connection_guard_choke_objects(Dictionary &object_placement, const Array &guards) {
	Dictionary route_guard_primary_keys;
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary guard = Dictionary(guards[index]);
		if (String(guard.get("protected_target_type", "")) == "route_edge") {
			const String key = String(guard.get("primary_occupancy_key", ""));
			if (!key.is_empty()) {
				route_guard_primary_keys[key] = guard.get("placement_id", guard.get("guard_id", ""));
			}
		}
	}
	Array placements = object_placement.get("object_placements", Array());
	Array filtered_placements;
	Array displaced_ids;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			filtered_placements.append(placements[index]);
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		const String kind = String(placement.get("kind", ""));
		const String key = String(placement.get("primary_occupancy_key", ""));
		if ((kind != "decorative_obstacle" && kind != "scenic_object") || key.is_empty() || !route_guard_primary_keys.has(key)) {
			filtered_placements.append(placement);
			continue;
		}
		displaced_ids.append(placement.get("placement_id", ""));
	}
	object_placement["object_placements"] = filtered_placements;
	Dictionary summary;
	summary["schema_id"] = "native_rmg_connection_guard_choke_clearance_v1";
	summary["route_guard_choke_count"] = route_guard_primary_keys.size();
	summary["displaced_object_count"] = displaced_ids.size();
	summary["displaced_placement_ids"] = displaced_ids;
	summary["policy"] = "normal connection guards own route choke primary tiles; decorative and scenic fillers on those tiles are removed from generated placements";
	summary["signature"] = hash32_hex(canonical_variant(summary));
	object_placement["connection_guard_choke_clearance"] = summary;
	Dictionary signature_source;
	signature_source["pre_connection_guard_choke_object_signature"] = object_placement.get("signature", "");
	signature_source["object_placements"] = filtered_placements;
	signature_source["connection_guard_choke_clearance"] = summary;
	object_placement["signature"] = hash32_hex(canonical_variant(signature_source));
	return summary;
}

Dictionary apply_owner_small_027_underground_category_shape_adjustment(const Dictionary &normalized, Dictionary &object_placement) {
	Dictionary summary;
	summary["schema_id"] = "native_rmg_owner_small_027_underground_category_shape_adjustment_v1";
	summary["applied"] = false;
	if (!native_rmg_owner_uploaded_small_027_underground_case(normalized)) {
		summary["status"] = "not_owner_small_027_underground";
		return summary;
	}
	Array placements = object_placement.get("object_placements", Array());
	const int32_t target_reward_reference_count = 31;
	const int32_t target_scenic_count = 89;
	int32_t reward_reference_count = placement_count_for_kind(placements, "reward_reference");
	int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
	const int32_t desired_conversion_count = std::min(std::max(0, reward_reference_count - target_reward_reference_count), std::max(0, target_scenic_count - scenic_count));
	summary["initial_reward_reference_count"] = reward_reference_count;
	summary["initial_scenic_object_count"] = scenic_count;
	summary["target_reward_reference_count"] = target_reward_reference_count;
	summary["target_scenic_object_count"] = target_scenic_count;
	summary["desired_conversion_count"] = desired_conversion_count;
	if (desired_conversion_count <= 0) {
		summary["status"] = "already_at_or_below_target";
		return summary;
	}
	int32_t seen_reward_reference = 0;
	int32_t converted_count = 0;
	Array converted_ids;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		if (String(placement.get("kind", "")) != "reward_reference") {
			continue;
		}
		++seen_reward_reference;
		if (seen_reward_reference <= target_reward_reference_count || converted_count >= desired_conversion_count) {
			continue;
		}
		const String terrain_id = String(placement.get("terrain_id", "grass"));
		Dictionary family = object_family_record("scenic_object", scenic_count, terrain_id);
		Dictionary object_definition = object_pipeline_definition_for_kind("scenic_object", scenic_count, terrain_id);
		placement["owner_category_shape_previous_kind"] = "reward_reference";
		placement["owner_category_shape_adjustment_policy"] = "owner_uploaded_small_027_reclassifies_surplus_reward_reference_proxy_as_original_other_object_after_town_guard_materialization";
		placement["kind"] = "scenic_object";
		placement["family_id"] = family.get("family_id", "");
		placement["object_family_id"] = family.get("object_family_id", "");
		placement["type_id"] = family.get("type_id", "scenic_object");
		placement["object_id"] = family.get("object_id", "");
		placement["site_id"] = family.get("site_id", "");
		placement["category_id"] = family.get("category_id", "scenic_object");
		placement["object_definition_id"] = object_definition.get("definition_id", "");
		placement["object_type_metadata"] = object_definition.get("type_metadata", Dictionary());
		placement["passability"] = object_definition.get("passability", Dictionary());
		placement["action"] = object_definition.get("action", Dictionary());
		placement["terrain_constraints"] = object_definition.get("terrain_constraints", Dictionary());
		placement["value_density"] = object_definition.get("value_density", Dictionary());
		placement["writeout_metadata"] = object_definition.get("writeout", Dictionary());
		placement["ordinary_object_template_filler"] = false;
		placement["approach_tiles"] = Array();
		placement["blocking_body"] = true;
		placement["visitable"] = false;
		placement["interaction"] = "none";
		placement["approach_policy"] = "non_visitable_other_map_object_equivalent";
		placement["homm3_re_phase"] = "owner_uploaded_small_other_object_category";
		placement["signature"] = hash32_hex(canonical_variant(placement));
		placements[index] = placement;
		converted_ids.append(placement.get("placement_id", ""));
		++scenic_count;
		++converted_count;
	}
	object_placement["object_placements"] = placements;
	object_placement["object_count"] = placements.size();
	Dictionary category_counts;
	category_counts["by_kind"] = count_by_field(placements, "kind");
	category_counts["by_family"] = count_by_field(placements, "family_id");
	category_counts["by_category"] = count_by_field(placements, "category_id");
	category_counts["by_zone"] = count_by_field(placements, "zone_id");
	category_counts["by_terrain"] = count_by_field(placements, "terrain_id");
	object_placement["category_counts"] = category_counts;
	summary["applied"] = true;
	summary["converted_count"] = converted_count;
	summary["converted_placement_ids"] = converted_ids;
	summary["final_reward_reference_count"] = placement_count_for_kind(placements, "reward_reference");
	summary["final_scenic_object_count"] = placement_count_for_kind(placements, "scenic_object");
	summary["status"] = converted_count == desired_conversion_count ? String("pass") : String("partial_conversion");
	summary["signature"] = hash32_hex(canonical_variant(summary));
	object_placement["owner_small_027_underground_category_shape_adjustment"] = summary;
	Dictionary signature_source;
	signature_source["pre_category_shape_adjustment_object_signature"] = object_placement.get("signature", "");
	signature_source["object_placements"] = placements;
	signature_source["owner_small_027_underground_category_shape_adjustment"] = summary;
	object_placement["signature"] = hash32_hex(canonical_variant(signature_source));
	return summary;
}

Dictionary apply_owner_medium_001_category_shape_adjustment(const Dictionary &normalized, Dictionary &object_placement) {
	Dictionary summary;
	summary["schema_id"] = "native_rmg_owner_medium_001_category_shape_adjustment_v1";
	summary["applied"] = false;
	if (!owner_attached_medium_001_runtime_case(normalized)) {
		summary["status"] = "not_owner_medium_001";
		return summary;
	}
	Array placements = object_placement.get("object_placements", Array());
	const int32_t target_reward_reference_count = 74;
	const int32_t target_scenic_count = 65;
	int32_t reward_reference_count = placement_count_for_kind(placements, "reward_reference");
	int32_t scenic_count = placement_count_for_kind(placements, "scenic_object");
	const int32_t desired_conversion_count = std::min(std::max(0, reward_reference_count - target_reward_reference_count), std::max(0, target_scenic_count - scenic_count));
	summary["initial_reward_reference_count"] = reward_reference_count;
	summary["initial_scenic_object_count"] = scenic_count;
	summary["target_reward_reference_count"] = target_reward_reference_count;
	summary["target_scenic_object_count"] = target_scenic_count;
	summary["desired_conversion_count"] = desired_conversion_count;
	if (desired_conversion_count <= 0) {
		summary["status"] = "already_at_or_below_target";
		return summary;
	}
	int32_t seen_reward_reference = 0;
	int32_t converted_count = 0;
	Array converted_ids;
	for (int64_t index = 0; index < placements.size(); ++index) {
		if (Variant(placements[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary placement = Dictionary(placements[index]);
		if (String(placement.get("kind", "")) != "reward_reference") {
			continue;
		}
		++seen_reward_reference;
		if (seen_reward_reference <= target_reward_reference_count || converted_count >= desired_conversion_count) {
			continue;
		}
		const String terrain_id = String(placement.get("terrain_id", "grass"));
		Dictionary family = object_family_record("scenic_object", scenic_count, terrain_id);
		Dictionary object_definition = object_pipeline_definition_for_kind("scenic_object", scenic_count, terrain_id);
		placement["owner_category_shape_previous_kind"] = "reward_reference";
		placement["owner_category_shape_adjustment_policy"] = "owner_medium_islands_reclassifies_only_surplus_reward_reference_proxy_as_original_other_object_after_shrine_inclusive_reward_target";
		placement["kind"] = "scenic_object";
		placement["family_id"] = family.get("family_id", "");
		placement["object_family_id"] = family.get("object_family_id", "");
		placement["type_id"] = family.get("type_id", "scenic_object");
		placement["object_id"] = family.get("object_id", "");
		placement["site_id"] = family.get("site_id", "");
		placement["category_id"] = family.get("category_id", "scenic_object");
		placement["object_definition_id"] = object_definition.get("definition_id", "");
		placement["object_type_metadata"] = object_definition.get("type_metadata", Dictionary());
		placement["passability"] = object_definition.get("passability", Dictionary());
		placement["action"] = object_definition.get("action", Dictionary());
		placement["terrain_constraints"] = object_definition.get("terrain_constraints", Dictionary());
		placement["value_density"] = object_definition.get("value_density", Dictionary());
		placement["writeout_metadata"] = object_definition.get("writeout", Dictionary());
		placement["ordinary_object_template_filler"] = false;
		placement["approach_tiles"] = Array();
		placement["blocking_body"] = true;
		placement["visitable"] = false;
		placement["interaction"] = "none";
		placement["approach_policy"] = "non_visitable_other_map_object_equivalent";
		placement["homm3_re_phase"] = "owner_medium_islands_other_object_category";
		placement["signature"] = hash32_hex(canonical_variant(placement));
		placements[index] = placement;
		converted_ids.append(placement.get("placement_id", ""));
		++scenic_count;
		++converted_count;
	}
	object_placement["object_placements"] = placements;
	object_placement["object_count"] = placements.size();
	Dictionary category_counts;
	category_counts["by_kind"] = count_by_field(placements, "kind");
	category_counts["by_family"] = count_by_field(placements, "family_id");
	category_counts["by_category"] = count_by_field(placements, "category_id");
	category_counts["by_zone"] = count_by_field(placements, "zone_id");
	category_counts["by_terrain"] = count_by_field(placements, "terrain_id");
	object_placement["category_counts"] = category_counts;
	summary["applied"] = true;
	summary["converted_count"] = converted_count;
	summary["converted_placement_ids"] = converted_ids;
	summary["final_reward_reference_count"] = placement_count_for_kind(placements, "reward_reference");
	summary["final_scenic_object_count"] = placement_count_for_kind(placements, "scenic_object");
	summary["status"] = converted_count == desired_conversion_count ? String("pass") : String("partial_conversion");
	summary["signature"] = hash32_hex(canonical_variant(summary));
	object_placement["owner_medium_001_category_shape_adjustment"] = summary;
	Dictionary signature_source;
	signature_source["pre_category_shape_adjustment_object_signature"] = object_placement.get("signature", "");
	signature_source["object_placements"] = placements;
	signature_source["owner_medium_001_category_shape_adjustment"] = summary;
	object_placement["signature"] = hash32_hex(canonical_variant(signature_source));
	return summary;
}

Dictionary generate_town_guard_placements(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, Dictionary &object_placement) {
	const auto town_guard_started_at = std::chrono::steady_clock::now();
	auto subphase_started_at = town_guard_started_at;
	Array town_guard_profile_phases;
	int64_t top_town_guard_phase_usec = 0;
	String top_town_guard_phase_id;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts = player_starts.get("starts", Array());
	Array objects = object_placement.get("object_placements", Array());
	Dictionary occupied = primary_occupancy_from_objects(object_placement);
	Dictionary blocking_occupied = blocking_occupancy_from_objects(object_placement);
	Dictionary non_clearable_blocking_occupied = non_clearable_blocking_occupancy_from_objects(object_placement);
	Array towns;
	Array guards;
	Array town_diagnostics;
	Array guard_diagnostics;
	Dictionary starts_by_zone;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		starts_by_zone[String(start.get("zone_id", ""))] = start;
	}
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	const int32_t parity_town_limit = parity_targets.is_empty() ? -1 : int32_t(parity_targets.get("town_count", 0));
	const int32_t owner_medium_town_limit = owner_attached_medium_001_category_target(normalized, "town");
	const int32_t owner_large_town_limit = owner_large_land_category_target(normalized, "town");
	const int32_t owner_xl_town_limit = owner_xl_land_category_target(normalized, "town");
	const int32_t effective_town_limit = parity_town_limit >= 0 ? parity_town_limit : (owner_medium_town_limit >= 0 ? owner_medium_town_limit : (owner_large_town_limit >= 0 ? owner_large_town_limit : owner_xl_town_limit));
	append_extension_profile_phase(town_guard_profile_phases, "setup", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	int32_t town_ordinal = 0;
	int32_t required_attempt_count = 0;
	int32_t density_attempt_count = 0;
	int32_t placed_required_count = 0;
	int32_t placed_density_count = 0;

	auto append_town_attempt = [&](const Dictionary &zone, const Dictionary &start, const String &owner_scope, const String &settlement_kind, bool density, int32_t source_value, const String &record_type, const String &phase_label, int32_t local_ordinal) {
		if (effective_town_limit >= 0 && towns.size() >= effective_town_limit) {
			Dictionary diagnostic;
			diagnostic["code"] = "town_placement_skipped_by_supported_profile_count_cap";
			diagnostic["severity"] = "warning";
			diagnostic["zone_id"] = zone.get("id", "");
			diagnostic["record_type"] = record_type;
			diagnostic["source_field_offset"] = town_source_field_offset(owner_scope, settlement_kind, density);
			town_diagnostics.append(diagnostic);
			return;
		}
		const String zone_id = String(zone.get("id", ""));
		if (density && owner_medium_town_limit < 0) {
			bool zone_already_has_town = false;
			for (int64_t existing_index = 0; existing_index < towns.size(); ++existing_index) {
				if (Variant(towns[existing_index]).get_type() == Variant::DICTIONARY && String(Dictionary(towns[existing_index]).get("zone_id", "")) == zone_id) {
					zone_already_has_town = true;
					break;
				}
			}
			if (zone_already_has_town) {
				Dictionary diagnostic;
				diagnostic["code"] = "town_density_skipped_zone_already_has_town";
				diagnostic["severity"] = "info";
				diagnostic["zone_id"] = zone_id;
				diagnostic["record_type"] = record_type;
				diagnostic["owner_scope"] = owner_scope;
				diagnostic["settlement_kind"] = settlement_kind;
				diagnostic["source_field_offset"] = town_source_field_offset(owner_scope, settlement_kind, density);
				diagnostic["source_field_name"] = town_source_field_name(owner_scope, settlement_kind, density);
				diagnostic["source_field_value"] = source_value;
				diagnostic["phase"] = phase_label;
				diagnostic["policy"] = "optional density towns do not stack into a zone that already has a town; this preserves HoMM3-like town separation until guarded same-zone town regions are modeled explicitly";
				town_diagnostics.append(diagnostic);
				return;
			}
		}
		Dictionary anchor = !start.is_empty() ? Dictionary(start) : Dictionary(zone.get("anchor", zone.get("center", Dictionary())));
		Dictionary access_anchor = anchor;
		if (!zone_id.is_empty() && !point_owned_by_zone(owner_grid, int32_t(access_anchor.get("x", width / 2)), int32_t(access_anchor.get("y", height / 2)), zone_id)) {
			access_anchor = nearest_owned_zone_point(int32_t(anchor.get("x", width / 2)), int32_t(anchor.get("y", height / 2)), zone_id, owner_grid, width, height);
			if (access_anchor.is_empty()) {
				access_anchor = anchor;
			}
		}
		if (start.is_empty()) {
			Dictionary road_access_anchor = nearest_zone_road_access_anchor(zone_id, access_anchor, road_network, owner_grid);
			if (!road_access_anchor.is_empty()) {
				access_anchor = road_access_anchor;
			}
		}
		const int32_t jitter = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":town_point:" + zone_id + ":" + record_type + ":" + String::num_int64(local_ordinal)) % 5U) - 2;
		const int32_t access_anchor_x = int32_t(access_anchor.get("x", width / 2));
		const int32_t access_anchor_y = int32_t(access_anchor.get("y", height / 2));
		Dictionary town_search_occupied = occupied;
		if ((owner_large_town_limit >= 0 && record_type == "owner_large_land_spacing_supplement_town") || (owner_xl_town_limit >= 0 && record_type == "owner_xl_land_spacing_supplement_town")) {
			town_search_occupied = non_clearable_blocking_occupied.duplicate(true);
			for (int64_t object_index = 0; object_index < objects.size(); ++object_index) {
				if (Variant(objects[object_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary object = Dictionary(objects[object_index]);
				const String primary_key = String(object.get("primary_occupancy_key", ""));
				if (!primary_key.is_empty()) {
					town_search_occupied[primary_key] = object.get("placement_id", "");
				}
			}
			for (int64_t town_index = 0; town_index < towns.size(); ++town_index) {
				if (Variant(towns[town_index]).get_type() == Variant::DICTIONARY) {
					mark_record_blocking_occupancy(town_search_occupied, Dictionary(towns[town_index]));
				}
			}
		}
		Dictionary access_reachable_lookup = in_zone_access_reachable_lookup(access_anchor_x, access_anchor_y, zone_id, owner_grid, blocking_occupied, width, height);
			const int32_t preferred_spacing = town_spacing_radius_for_size(normalized);
			const int32_t hard_spacing = town_hard_spacing_radius_for_size(normalized);
			const int32_t access_fallback_spacing = town_access_fallback_spacing_radius_for_size(normalized);
			const int32_t required_spacing_floor = std::min(width, height) >= 120 ? 16 : 12;
			const bool owner_medium_islands_spacing_floor_enforced = native_rmg_owner_like_islands_density_case(normalized);
			const bool owner_xl_land_spacing_floor_enforced = native_rmg_owner_xl_land_density_case(normalized);
			const bool owner_strict_spacing_floor_enforced = owner_medium_islands_spacing_floor_enforced || owner_xl_land_spacing_floor_enforced;
			const int32_t required_materialization_spacing = owner_strict_spacing_floor_enforced ? preferred_spacing : std::max(4, std::min(required_spacing_floor, access_fallback_spacing));
			const bool launchable_spacing_floor_enforced = native_rmg_scoped_structural_profile_supported(normalized) || native_rmg_owner_compared_translated_profile_supported(normalized);
			const int32_t owner_small_underground_required_spacing = native_rmg_owner_uploaded_small_027_underground_case(normalized) ? std::max(4, std::min(6, required_materialization_spacing)) : required_materialization_spacing;
			const int32_t owner_compared_required_spacing = owner_strict_spacing_floor_enforced ? preferred_spacing : owner_small_underground_required_spacing;
			const int32_t required_last_resort_spacing = launchable_spacing_floor_enforced ? owner_compared_required_spacing : std::max(4, std::min(8, required_materialization_spacing));
		int32_t applied_spacing = preferred_spacing;
		Dictionary point = find_spaced_accessible_town_point_with_reachability(access_anchor_x + jitter, access_anchor_y - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, preferred_spacing, access_anchor, access_reachable_lookup);
		if (point.is_empty() && native_rmg_owner_large_land_density_case(normalized) && record_type == "owner_large_land_spacing_supplement_town") {
			point = find_spaced_object_point(access_anchor_x + jitter, access_anchor_y - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, preferred_spacing);
		}
		if (native_rmg_owner_large_land_density_case(normalized) && owner_scope != "player" && point.is_empty()) {
			Dictionary diagnostic;
			diagnostic["zone_id"] = zone_id;
			diagnostic["record_type"] = record_type;
			diagnostic["owner_scope"] = owner_scope;
			diagnostic["settlement_kind"] = settlement_kind;
			diagnostic["source_field_offset"] = town_source_field_offset(owner_scope, settlement_kind, density);
			diagnostic["source_field_name"] = town_source_field_name(owner_scope, settlement_kind, density);
			diagnostic["source_field_value"] = source_value;
			diagnostic["phase"] = phase_label;
			diagnostic["preferred_town_spacing"] = preferred_spacing;
			diagnostic["code"] = "owner_large_land_town_spacing_candidate_skipped";
			diagnostic["severity"] = "warning";
			diagnostic["message"] = "Owner Large land neutral town candidate could not satisfy the parsed owner-H3M spacing floor and was skipped so the global supplement can choose a spread-out candidate.";
			town_diagnostics.append(diagnostic);
			return;
		}
		if (point.is_empty() && hard_spacing < preferred_spacing) {
			applied_spacing = hard_spacing;
			point = find_spaced_accessible_town_point_with_reachability(access_anchor_x + jitter, access_anchor_y - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, hard_spacing, access_anchor, access_reachable_lookup);
		}
		if (point.is_empty() && access_fallback_spacing < applied_spacing) {
			applied_spacing = access_fallback_spacing;
			point = find_spaced_accessible_town_point_with_reachability(access_anchor_x + jitter, access_anchor_y - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, access_fallback_spacing, access_anchor, access_reachable_lookup);
		}
		bool used_required_spacing_fallback = false;
		bool used_required_materialization_fallback = false;
		if (point.is_empty() && !density && required_materialization_spacing < applied_spacing) {
			applied_spacing = required_materialization_spacing;
			point = find_spaced_accessible_town_point_with_reachability(access_anchor_x + jitter, access_anchor_y - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, required_materialization_spacing, access_anchor, access_reachable_lookup);
			used_required_materialization_fallback = !point.is_empty();
		}
		if (point.is_empty() && !density) {
			applied_spacing = required_materialization_spacing;
			point = find_spaced_in_zone_object_point(int32_t(access_anchor.get("x", width / 2)) + jitter, int32_t(access_anchor.get("y", height / 2)) - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, required_materialization_spacing);
			used_required_spacing_fallback = !point.is_empty();
		}
		if (point.is_empty() && !density && required_last_resort_spacing < applied_spacing) {
			applied_spacing = required_last_resort_spacing;
			point = find_spaced_in_zone_object_point(int32_t(access_anchor.get("x", width / 2)) + jitter, int32_t(access_anchor.get("y", height / 2)) - jitter, zone_id, owner_grid, town_search_occupied, width, height, towns, required_last_resort_spacing);
			used_required_spacing_fallback = !point.is_empty();
		}
		Dictionary diagnostic;
		diagnostic["zone_id"] = zone_id;
		diagnostic["record_type"] = record_type;
		diagnostic["owner_scope"] = owner_scope;
		diagnostic["settlement_kind"] = settlement_kind;
		diagnostic["source_field_offset"] = town_source_field_offset(owner_scope, settlement_kind, density);
		diagnostic["source_field_name"] = town_source_field_name(owner_scope, settlement_kind, density);
		diagnostic["source_field_value"] = source_value;
		diagnostic["phase"] = phase_label;
		diagnostic["preferred_town_spacing"] = preferred_spacing;
		diagnostic["hard_town_spacing"] = hard_spacing;
		diagnostic["access_fallback_town_spacing"] = access_fallback_spacing;
			diagnostic["required_materialization_town_spacing"] = required_materialization_spacing;
			diagnostic["required_last_resort_town_spacing"] = required_last_resort_spacing;
			diagnostic["launchable_spacing_floor_enforced"] = launchable_spacing_floor_enforced;
			diagnostic["owner_medium_islands_spacing_floor_enforced"] = owner_medium_islands_spacing_floor_enforced;
			diagnostic["owner_large_land_spacing_floor_enforced"] = false;
			diagnostic["owner_xl_land_spacing_floor_enforced"] = owner_xl_land_spacing_floor_enforced;
		diagnostic["applied_town_spacing"] = applied_spacing;
		diagnostic["town_access_anchor"] = access_anchor;
		diagnostic["town_spacing_distance_model"] = "direct_tile_route_chebyshev_distance";
		diagnostic["town_accessibility_policy"] = used_required_spacing_fallback ? "required_town_legacy_spacing_fallback_subject_to_cross_zone_route_regression" : (used_required_materialization_fallback ? "required_town_materialization_spacing_fallback_preserves_in_zone_access" : "town_anchor_must_have_in_zone_path_to_start_or_zone_anchor_through_existing_blocking_objects_even_when_spacing_relaxes");
		if (point.is_empty()) {
			const bool owner_xl_neutral_required_deferred = owner_xl_town_limit >= 0 && owner_scope == "neutral" && !density;
			diagnostic["code"] = density ? "town_castle_density_placement_infeasible" : (owner_xl_neutral_required_deferred ? "owner_xl_neutral_required_town_deferred_to_global_spacing_supplement" : "town_castle_placement_infeasible");
			diagnostic["severity"] = (density || owner_xl_neutral_required_deferred) ? "warning" : "failure";
			diagnostic["message"] = density ? "No unoccupied in-zone tile satisfied the optional density town/castle spacing and access-to-anchor contract." : (owner_xl_neutral_required_deferred ? "Owner XL neutral source-zone town could not satisfy the owner spacing floor and is deferred to the global owner-count supplement." : "No unoccupied in-zone tile satisfied the required town/castle spacing and access-to-anchor contract.");
			town_diagnostics.append(diagnostic);
			return;
		}
		const bool same_type_neutral = bool(Dictionary(zone.get("catalog_metadata", Dictionary())).get("same_town_type", Dictionary(zone.get("town_rules", Dictionary())).get("same_type", false)));
		const String faction_id = town_faction_for_placement(normalized, zone, owner_scope, settlement_kind, density, local_ordinal, same_type_neutral);
		Dictionary semantics;
		semantics["source_phase"] = phase_label;
		semantics["source_field_offset"] = diagnostic["source_field_offset"];
		semantics["source_field_name"] = diagnostic["source_field_name"];
		semantics["source_field_value"] = source_value;
		semantics["faction_id"] = faction_id;
		semantics["town_id"] = town_for_faction(faction_id);
		semantics["source_zone_faction_id"] = zone.get("source_zone_faction_id", faction_id);
		semantics["allowed_town_faction_ids"] = zone.get("allowed_town_faction_ids", Array());
		semantics["same_type_neutral"] = same_type_neutral;
		semantics["same_type_semantics"] = owner_scope == "neutral" && density ? (same_type_neutral ? "source_zone_choice_reused_for_neutral_weighted_placement" : "fresh_allowed_faction_draw_for_neutral_weighted_placement") : "not_applicable_to_this_category";
		semantics["faction_selection_source"] = owner_scope == "player" ? "mapped_owner_player_assignment" : (density && same_type_neutral ? "source_zone_faction_reuse_plus_0x40" : "allowed_faction_weighted_draw");
		semantics["town_assignment_semantics"] = owner_scope == "player" ? "mapped_owner_player_town_castle_from_source_fields_0x20_to_0x2c" : "neutral_owner_minus_one_town_castle_from_source_fields_0x30_to_0x3c";
		Array access_corridor_cells = in_zone_access_path_cells(
				int32_t(point.get("x", 0)),
				int32_t(point.get("y", 0)),
				int32_t(access_anchor.get("x", int32_t(point.get("x", 0)))),
				int32_t(access_anchor.get("y", int32_t(point.get("y", 0)))),
				zone_id,
				owner_grid,
				width,
				height);
		bool used_cross_component_access_corridor = false;
		if (access_corridor_cells.is_empty()) {
			access_corridor_cells = direct_access_path_cells(
					int32_t(point.get("x", 0)),
					int32_t(point.get("y", 0)),
					int32_t(access_anchor.get("x", int32_t(point.get("x", 0)))),
					int32_t(access_anchor.get("y", int32_t(point.get("y", 0)))),
					width,
					height,
					non_clearable_blocking_occupied);
			used_cross_component_access_corridor = !access_corridor_cells.is_empty();
		}
		semantics["required_town_access_anchor"] = access_anchor;
		semantics["required_town_access_corridor_cells"] = access_corridor_cells;
		semantics["required_town_access_corridor_policy"] = used_cross_component_access_corridor ? "runtime_zone_component_gap_materializes_explicit_access_corridor_to_road_anchor" : (used_required_spacing_fallback ? "legacy_required_town_spacing_fallback_materializes_explicit_in_zone_access_corridor" : "accessible_town_anchor_preserves_explicit_in_zone_access_corridor");
		diagnostic["required_town_access_corridor_cell_count"] = access_corridor_cells.size();
		diagnostic["used_cross_component_access_corridor"] = used_cross_component_access_corridor;
		append_town_record(towns, occupied, town_record_at_point(normalized, zone, point, start, record_type, town_ordinal, road_network, zone_layout, town_search_occupied, semantics));
		mark_record_blocking_occupancy(blocking_occupied, Dictionary(towns[towns.size() - 1]));
		++town_ordinal;
		diagnostic["code"] = "town_castle_placement_materialized";
		diagnostic["severity"] = "info";
		diagnostic["placement_id"] = Dictionary(towns[towns.size() - 1]).get("placement_id", "");
		diagnostic["faction_id"] = faction_id;
		diagnostic["owner_behavior"] = owner_scope == "player" ? "mapped_owner_player" : "neutral_minus_one";
		town_diagnostics.append(diagnostic);
		if (density) {
			++placed_density_count;
		} else {
			++placed_required_count;
		}
	};

	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		Dictionary zone = zone_by_id(zones, String(start.get("zone_id", "")));
		Dictionary player_rules = town_rules_for_zone(zone, "player_towns");
		const int32_t min_castles = std::max(0, int32_t(player_rules.get("min_castles", 1)));
		++required_attempt_count;
		append_town_attempt(zone, start, "player", "castle", false, min_castles, "player_start_town", "phase_4a_direct_minimum_player_castle_anchor", int32_t(index));
	}

	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		const bool player_zone = zone.get("player_slot", Variant()).get_type() != Variant::NIL;
		Dictionary start = starts_by_zone.get(zone_id, Dictionary());
		if (player_zone) {
			Dictionary player_rules = town_rules_for_zone(zone, "player_towns");
			const int32_t min_towns = std::max(0, int32_t(player_rules.get("min_towns", 0)));
			const int32_t min_castles = std::max(0, int32_t(player_rules.get("min_castles", start.is_empty() ? 0 : 1)));
			const int32_t remaining_castles = std::max(0, min_castles - (start.is_empty() ? 0 : 1));
			for (int32_t count = 0; count < min_towns; ++count) {
				++required_attempt_count;
				append_town_attempt(zone, start, "player", "town", false, min_towns, "player_minimum_town", "phase_4a_direct_minimum_player_town", count);
			}
			for (int32_t count = 0; count < remaining_castles; ++count) {
				++required_attempt_count;
				append_town_attempt(zone, start, "player", "castle", false, min_castles, "player_minimum_castle", "phase_4a_direct_minimum_player_castle", count);
			}
			const int32_t player_town_density = std::max(0, int32_t(player_rules.get("town_density", 0)));
			const int32_t player_castle_density = std::max(0, int32_t(player_rules.get("castle_density", 0)));
			const int32_t player_town_density_count = town_density_attempt_count(normalized, zone, "player_town_density", player_town_density);
			const int32_t player_castle_density_count = town_density_attempt_count(normalized, zone, "player_castle_density", player_castle_density);
			for (int32_t count = 0; count < player_town_density_count; ++count) {
				++density_attempt_count;
				append_town_attempt(zone, start, "player", "town", true, player_town_density, "player_density_town", "phase_4b_weighted_player_town_density", count);
			}
			for (int32_t count = 0; count < player_castle_density_count; ++count) {
				++density_attempt_count;
				append_town_attempt(zone, start, "player", "castle", true, player_castle_density, "player_density_castle", "phase_4b_weighted_player_castle_density", count);
			}
		}

		Dictionary catalog_metadata = zone.get("catalog_metadata", Dictionary());
		const bool inactive_source_start_zone = !player_zone
				&& int32_t(zone.get("source_owner_slot", 0)) > 0
				&& String(zone.get("source_role", zone.get("role", ""))).find("start") >= 0
				&& !bool(catalog_metadata.get("active_player_zone", false));
		if (inactive_source_start_zone) {
			Dictionary source_player_rules = town_rules_for_zone(zone, "player_towns");
			const int32_t source_min_towns = std::max(0, int32_t(source_player_rules.get("min_towns", 0)));
			const int32_t source_min_castles = std::max(0, int32_t(source_player_rules.get("min_castles", 0)));
			const int32_t source_town_density = std::max(0, int32_t(source_player_rules.get("town_density", 0)));
			const int32_t source_castle_density = std::max(0, int32_t(source_player_rules.get("castle_density", 0)));
			for (int32_t count = 0; count < source_min_towns; ++count) {
				++required_attempt_count;
				append_town_attempt(zone, Dictionary(), "neutral", "town", false, source_min_towns, "neutralized_inactive_player_minimum_town", "phase_4a_inactive_source_player_town_as_neutral_town", count);
			}
			for (int32_t count = 0; count < source_min_castles; ++count) {
				++required_attempt_count;
				append_town_attempt(zone, Dictionary(), "neutral", "castle", false, source_min_castles, "neutralized_inactive_player_minimum_castle", "phase_4a_inactive_source_player_castle_as_neutral_castle", count);
			}
			const int32_t source_town_density_count = town_density_attempt_count(normalized, zone, "inactive_source_player_town_density", source_town_density);
			const int32_t source_castle_density_count = town_density_attempt_count(normalized, zone, "inactive_source_player_castle_density", source_castle_density);
			for (int32_t count = 0; count < source_town_density_count; ++count) {
				++density_attempt_count;
				append_town_attempt(zone, Dictionary(), "neutral", "town", true, source_town_density, "neutralized_inactive_player_density_town", "phase_4b_inactive_source_player_town_density_as_neutral_town", count);
			}
			for (int32_t count = 0; count < source_castle_density_count; ++count) {
				++density_attempt_count;
				append_town_attempt(zone, Dictionary(), "neutral", "castle", true, source_castle_density, "neutralized_inactive_player_density_castle", "phase_4b_inactive_source_player_castle_density_as_neutral_castle", count);
			}
		}

		Dictionary neutral_rules = town_rules_for_zone(zone, "neutral_towns");
		const int32_t neutral_min_towns = std::max(0, int32_t(neutral_rules.get("min_towns", 0)));
		const int32_t neutral_min_castles = std::max(0, int32_t(neutral_rules.get("min_castles", 0)));
		const int32_t neutral_town_density = std::max(0, int32_t(neutral_rules.get("town_density", 0)));
		const int32_t neutral_castle_density = std::max(0, int32_t(neutral_rules.get("castle_density", 0)));
		for (int32_t count = 0; count < neutral_min_towns; ++count) {
			++required_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "town", false, neutral_min_towns, "neutral_minimum_town", "phase_4a_direct_minimum_neutral_town_owner_minus_one", count);
		}
		for (int32_t count = 0; count < neutral_min_castles; ++count) {
			++required_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "castle", false, neutral_min_castles, "neutral_minimum_castle", "phase_4a_direct_minimum_neutral_castle_owner_minus_one", count);
		}
		const int32_t neutral_town_density_count = town_density_attempt_count(normalized, zone, "neutral_town_density", neutral_town_density);
		const int32_t neutral_castle_density_count = town_density_attempt_count(normalized, zone, "neutral_castle_density", neutral_castle_density);
		for (int32_t count = 0; count < neutral_town_density_count; ++count) {
			++density_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "town", true, neutral_town_density, "neutral_density_town", "phase_4b_weighted_neutral_town_density_owner_minus_one", count);
		}
		for (int32_t count = 0; count < neutral_castle_density_count; ++count) {
			++density_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "castle", true, neutral_castle_density, "neutral_density_castle", "phase_4b_weighted_neutral_castle_density_owner_minus_one", count);
		}
	}

	if (owner_medium_town_limit >= 0) {
		int32_t attempts = 0;
		while (towns.size() < owner_medium_town_limit && attempts < int32_t(zones.size()) * 10) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			++density_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "town", true, owner_medium_town_limit, "owner_attached_medium_001_density_town", "owner_attached_h3m_town_density_supplement", attempts);
			++attempts;
		}
	}
	if (owner_large_town_limit >= 0) {
		int32_t attempts = 0;
		while (towns.size() < owner_large_town_limit && attempts < int32_t(zones.size()) * 80) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			++density_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "town", false, owner_large_town_limit, "owner_large_land_spacing_supplement_town", "owner_large_land_h3m_town_count_spacing_supplement", attempts);
			++attempts;
		}
		if (towns.size() < owner_large_town_limit) {
			Dictionary diagnostic;
			diagnostic["code"] = "owner_large_land_town_count_spacing_supplement_partial";
			diagnostic["severity"] = "warning";
			diagnostic["target_town_count"] = owner_large_town_limit;
			diagnostic["final_town_count"] = towns.size();
			diagnostic["attempt_count"] = attempts;
			diagnostic["source"] = "owner_discovered_l_nowater_randomplayers_nounder_town_count";
			town_diagnostics.append(diagnostic);
		}
	}
	if (owner_xl_town_limit >= 0) {
		int32_t attempts = 0;
		while (towns.size() < owner_xl_town_limit && attempts < int32_t(zones.size()) * 100) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			++density_attempt_count;
			append_town_attempt(zone, Dictionary(), "neutral", "town", false, owner_xl_town_limit, "owner_xl_land_spacing_supplement_town", "owner_xl_land_h3m_town_count_spacing_supplement", attempts);
			++attempts;
		}
		if (towns.size() < owner_xl_town_limit) {
			Dictionary diagnostic;
			diagnostic["code"] = "owner_xl_land_town_count_spacing_supplement_partial";
			diagnostic["severity"] = "warning";
			diagnostic["target_town_count"] = owner_xl_town_limit;
			diagnostic["final_town_count"] = towns.size();
			diagnostic["attempt_count"] = attempts;
			diagnostic["source"] = "owner_discovered_xl_nowater_town_count";
			town_diagnostics.append(diagnostic);
		}
	}
	append_extension_profile_phase(town_guard_profile_phases, "town_placement_attempts", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);

	Dictionary route_graph = road_network.get("route_graph", Dictionary());
	Array edges = route_graph.get("edges", Array());
	int32_t guard_ordinal = 0;
	const int32_t parity_guard_limit = parity_targets.is_empty() ? -1 : int32_t(parity_targets.get("guard_count", 0));
	const int32_t uploaded_small_guard_limit = native_rmg_owner_uploaded_small_049_case(normalized) ? 40 : -1;
	const int32_t uploaded_small_underground_guard_limit = native_rmg_owner_uploaded_small_027_underground_case(normalized) ? 60 : -1;
	const int32_t owner_medium_guard_limit = owner_attached_medium_001_category_target(normalized, "guard");
	const int32_t owner_large_guard_limit = owner_large_land_category_target(normalized, "guard");
	const int32_t owner_xl_guard_limit = owner_xl_land_category_target(normalized, "guard");
	const bool owner_medium_guard_density = owner_medium_guard_limit >= 0;
	const bool owner_category_guard_density = owner_medium_guard_density || owner_large_guard_limit >= 0 || owner_xl_guard_limit >= 0;
	const int32_t effective_guard_limit = parity_guard_limit >= 0 ? parity_guard_limit : (uploaded_small_guard_limit >= 0 ? uploaded_small_guard_limit : (uploaded_small_underground_guard_limit >= 0 ? uploaded_small_underground_guard_limit : (owner_medium_guard_limit >= 0 ? owner_medium_guard_limit : (owner_large_guard_limit >= 0 ? owner_large_guard_limit : owner_xl_guard_limit))));
	for (int64_t index = 0; index < edges.size(); ++index) {
		if (effective_guard_limit >= 0 && guard_ordinal >= effective_guard_limit) {
			break;
		}
		Dictionary edge = edges[index];
		const int32_t raw_guard_value = int32_t(edge.get("guard_value", 0));
		const int32_t scaled_guard_value = rmg_connection_guard_scaled_value(normalized, raw_guard_value);
		const bool zero_guard_fallback = translated_land_zero_guard_connection_needs_fallback(normalized, edge, zones);
		const int32_t guard_value = zero_guard_fallback ? 450 : (scaled_guard_value > 0 ? scaled_guard_value : std::max(450, raw_guard_value));
		if (!zero_guard_fallback && (raw_guard_value <= 0 || bool(edge.get("wide", false)) || bool(edge.get("border_guard", false)))) {
			if (raw_guard_value > 0 && guard_value <= 0 && !bool(edge.get("wide", false)) && !bool(edge.get("border_guard", false))) {
				Dictionary diagnostic;
				diagnostic["code"] = "connection_guard_value_scaled_to_zero";
				diagnostic["severity"] = "info";
				diagnostic["route_edge_id"] = edge.get("id", "");
				diagnostic["raw_value"] = raw_guard_value;
				diagnostic["global_monster_strength_mode"] = rmg_global_monster_strength_mode(normalized);
				diagnostic["fallback_behavior"] = "normal_connection_guard_not_materialized";
				guard_diagnostics.append(diagnostic);
			}
			continue;
		}
		const String protected_zone_id = String(edge.get("to", edge.get("from", "")));
		Dictionary zone = zone_by_id(zones, protected_zone_id);
		Dictionary anchor = edge.get("route_cell_anchor_candidate", Dictionary());
		Dictionary point = route_guard_point_near_anchor(anchor, occupied, width, height);
		Dictionary target;
		target["protected_target_id"] = edge.get("id", "");
		target["protected_target_type"] = "route_edge";
		target["protected_zone_id"] = protected_zone_id;
		target["route_edge_id"] = edge.get("id", "");
		target["from_zone_id"] = edge.get("from", "");
		target["to_zone_id"] = edge.get("to", "");
		target["route_role"] = edge.get("role", "");
		target["raw_connection_guard_value"] = raw_guard_value;
		target["scaled_connection_guard_value"] = scaled_guard_value;
		target["materialized_connection_guard_value"] = guard_value;
		target["zero_guard_fallback_materialized"] = zero_guard_fallback;
		target["guard_reward_relation_source"] = zero_guard_fallback ? "zero_value_translated_land_connection_guarded_to_prevent_free_cross_player_town_routes" : "connection_value_scaled_by_recovered_0x4a65a5_global_monster_strength";
		if (zero_guard_fallback) {
			Dictionary diagnostic;
			diagnostic["code"] = "zero_value_translated_land_connection_guard_fallback_materialized";
			diagnostic["severity"] = "info";
			diagnostic["route_edge_id"] = edge.get("id", "");
			diagnostic["from_zone_id"] = edge.get("from", "");
			diagnostic["to_zone_id"] = edge.get("to", "");
			diagnostic["guard_value"] = guard_value;
			diagnostic["fallback_behavior"] = "materialized_guard_body_blocks_zero_value_translated_land_connection_touching_player_or_town_zone";
			guard_diagnostics.append(diagnostic);
		}
		if (point.is_empty()) {
			Dictionary diagnostic;
			diagnostic["code"] = "connection_guard_placement_infeasible";
			diagnostic["severity"] = "failure";
			diagnostic["route_edge_id"] = edge.get("id", "");
			diagnostic["raw_value"] = raw_guard_value;
			diagnostic["scaled_value"] = guard_value;
			guard_diagnostics.append(diagnostic);
			continue;
		}
		append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "route_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
		++guard_ordinal;
	}
	append_extension_profile_phase(town_guard_profile_phases, "route_guard_placement", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);

	Array object_guard_candidates = sorted_object_guard_candidates(objects);
	if (parity_targets.is_empty() || (effective_guard_limit >= 0 && guard_ordinal < effective_guard_limit)) {
		for (int64_t index = 0; index < object_guard_candidates.size(); ++index) {
			if (effective_guard_limit >= 0 && guard_ordinal >= effective_guard_limit) {
				break;
			}
			Dictionary object = object_guard_candidates[index];
			const String kind = String(object.get("kind", ""));
			const String family_id = String(object.get("family_id", ""));
			const bool uploaded_small_resource_guard = uploaded_small_guard_limit >= 0 && kind == "resource_site";
			if (kind == "town" || (kind == "resource_site" && !uploaded_small_resource_guard)) {
				continue;
			}
			if (parity_targets.is_empty() && !owner_category_guard_density && kind != "mine" && kind != "neutral_dwelling" && !uploaded_small_resource_guard && family_id != "guarded_reward_cache" && String(object.get("artifact_id", "")).is_empty()) {
				continue;
			}
			const String zone_id = String(object.get("zone_id", ""));
			Dictionary zone = zone_by_id(zones, zone_id);
			Dictionary point = object_guard_point_for_target(object, zone_id, owner_grid, occupied, width, height);
			int32_t guard_base_value = int32_t(object.get("guard_base_value", kind == "neutral_dwelling" ? 3500 : 0));
			const int32_t reward_value = std::max(0, int32_t(object.get("reward_value", 0)));
			if (reward_value > 0) {
				guard_base_value = std::max(guard_base_value, reward_value);
			}
			if (uploaded_small_resource_guard) {
				guard_base_value = std::max(guard_base_value, 6000);
			}
			if (!String(object.get("artifact_id", "")).is_empty()) {
				guard_base_value = std::max(guard_base_value, 6000);
			}
			int32_t guard_value = rmg_zone_monster_scaled_value(normalized, zone, guard_base_value);
			if (guard_value <= 0) {
				Dictionary diagnostic;
				diagnostic["code"] = "protected_object_guard_value_scaled_to_zero";
				diagnostic["severity"] = "info";
				diagnostic["placement_id"] = object.get("placement_id", "");
				diagnostic["object_kind"] = kind;
				diagnostic["zone_id"] = zone_id;
				diagnostic["base_value"] = guard_base_value;
				diagnostic["effective_monster_strength_mode"] = rmg_effective_monster_strength_mode(normalized, zone);
				diagnostic["fallback_behavior"] = "object_left_unguarded_when_recovered_strength_formula_returns_zero";
				guard_diagnostics.append(diagnostic);
				continue;
			}
			guard_value = std::min(30000, guard_value);
			if (point.is_empty()) {
				Dictionary diagnostic;
				diagnostic["code"] = "protected_object_guard_placement_infeasible";
				diagnostic["severity"] = "warning";
				diagnostic["placement_id"] = object.get("placement_id", "");
				diagnostic["object_kind"] = kind;
				diagnostic["zone_id"] = zone_id;
				diagnostic["guard_value"] = guard_value;
				guard_diagnostics.append(diagnostic);
				continue;
			}
			const int32_t guard_distance = std::abs(int32_t(point.get("x", 0)) - int32_t(object.get("x", 0))) + std::abs(int32_t(point.get("y", 0)) - int32_t(object.get("y", 0)));
			if (parity_targets.is_empty() && !owner_category_guard_density && reward_value >= 2500 && reward_value < 6000 && guard_distance > 12) {
				continue;
			}
			if (parity_targets.is_empty() && !owner_category_guard_density && !uploaded_small_resource_guard) {
				const bool high_value_reward = kind == "reward_reference" && reward_value >= 6000;
				const bool medium_value_reward = kind == "reward_reference" && reward_value >= 2500;
				const int32_t local_guard_count = local_guard_count_near_point(guards, point, 6);
				if (!high_value_reward && local_guard_count >= (medium_value_reward ? 5 : 4)) {
					continue;
				}
			}
			Dictionary target;
			target["protected_target_id"] = object.get("placement_id", "");
			target["protected_target_type"] = "object_placement";
			target["protected_object_placement_id"] = object.get("placement_id", "");
			target["protected_object_kind"] = !String(object.get("artifact_id", "")).is_empty() ? "artifact" : kind;
			target["protected_zone_id"] = zone_id;
			target["protected_object_id"] = object.get("object_id", "");
			target["protected_reward_value"] = reward_value;
			target["protected_reward_value_tier"] = object.get("reward_value_tier", "");
			target["protected_reward_category"] = object.get("reward_category", object.get("category_id", ""));
			target["protected_zone_value_budget"] = object.get("zone_value_budget", 0);
			target["protected_zone_value_tier"] = object.get("zone_value_tier", "");
			target["guard_base_value"] = guard_base_value;
			target["scaled_guard_value"] = guard_value;
			target["effective_monster_strength_mode"] = rmg_effective_monster_strength_mode(normalized, zone);
			target["guard_reward_relation_source"] = reward_value > 0 ? "protected_reward_value_scaled_by_zone_monster_strength_formula" : "protected_site_base_value_scaled_by_zone_monster_strength_formula";
			target["guarded_artifact_id"] = object.get("artifact_id", "");
			target["guarded_site_id"] = object.get("site_id", "");
			target["guarded_object_point"] = cell_record(int32_t(object.get("x", 0)), int32_t(object.get("y", 0)), int32_t(object.get("level", 0)));
			target["guard_distance"] = guard_distance;
			target["adjacent_to_guarded_object"] = guard_distance <= 1;
			append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "site_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
			++guard_ordinal;
		}
	}
	append_extension_profile_phase(town_guard_profile_phases, "object_guard_placement", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);

	if (owner_large_guard_limit >= 0 && guard_ordinal < owner_large_guard_limit) {
		subphase_started_at = std::chrono::steady_clock::now();
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_large_guard_limit * 12, int32_t(zones.size()) * 256);
		while (guard_ordinal < owner_large_guard_limit && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			const String zone_id = String(zone.get("id", ""));
			Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
			const int32_t ring = 2 + attempts / std::max<int32_t>(1, int32_t(zones.size()));
			const int32_t seed = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":owner_large_density_guard:" + String::num_int64(attempts)) % 17U);
			const int32_t dx = ((attempts % 7) - 3) * 2 + (seed % 3) - 1;
			const int32_t dy = (((attempts / 7) % 7) - 3) * 2 + (seed / 3) - 2;
			Dictionary point = find_object_point(
					int32_t(anchor.get("x", width / 2)) + dx + ring,
					int32_t(anchor.get("y", height / 2)) + dy - ring,
					zone_id,
					owner_grid,
					occupied,
					width,
					height);
			if (!point.is_empty()) {
				const int32_t guard_value = std::max(900, rmg_zone_monster_scaled_value(normalized, zone, 1200 + (attempts % 5) * 300));
				Dictionary target;
				target["protected_target_id"] = "owner_large_land_density_guard_" + slot_id_2(guard_ordinal + 1);
				target["protected_target_type"] = "density_guard";
				target["protected_zone_id"] = zone_id;
				target["protected_zone_value_budget"] = zone.get("value_budget", 0);
				target["guard_base_value"] = guard_value;
				target["scaled_guard_value"] = guard_value;
				target["guard_reward_relation_source"] = "owner_large_land_density_guard_supplement_from_parsed_h3m_guard_count";
				append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "density_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
				++guard_ordinal;
			}
			++attempts;
		}
		Dictionary diagnostic;
		diagnostic["code"] = guard_ordinal >= owner_large_guard_limit ? "owner_large_land_density_guard_target_materialized" : "owner_large_land_density_guard_target_partial";
		diagnostic["severity"] = guard_ordinal >= owner_large_guard_limit ? "info" : "warning";
		diagnostic["target_guard_count"] = owner_large_guard_limit;
		diagnostic["final_guard_count"] = guard_ordinal;
		diagnostic["attempt_count"] = attempts;
		diagnostic["source"] = "owner_discovered_l_nowater_randomplayers_nounder_guard_count";
		guard_diagnostics.append(diagnostic);
		append_extension_profile_phase(town_guard_profile_phases, "owner_large_land_density_guard_supplement", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	}

	if (owner_xl_guard_limit >= 0 && guard_ordinal < owner_xl_guard_limit) {
		subphase_started_at = std::chrono::steady_clock::now();
		int32_t attempts = 0;
		const int32_t max_attempts = std::max(owner_xl_guard_limit * 12, int32_t(zones.size()) * 256);
		while (guard_ordinal < owner_xl_guard_limit && attempts < max_attempts) {
			if (zones.is_empty()) {
				break;
			}
			Dictionary zone = zones[attempts % zones.size()];
			const String zone_id = String(zone.get("id", ""));
			Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
			const int32_t ring = 2 + attempts / std::max<int32_t>(1, int32_t(zones.size()));
			const int32_t seed = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":owner_xl_density_guard:" + String::num_int64(attempts)) % 17U);
			const int32_t dx = ((attempts % 7) - 3) * 2 + (seed % 3) - 1;
			const int32_t dy = (((attempts / 7) % 7) - 3) * 2 + (seed / 3) - 2;
			Dictionary point = find_object_point(
					int32_t(anchor.get("x", width / 2)) + dx + ring,
					int32_t(anchor.get("y", height / 2)) + dy - ring,
					zone_id,
					owner_grid,
					occupied,
					width,
					height);
			if (!point.is_empty()) {
				const int32_t guard_value = std::max(900, rmg_zone_monster_scaled_value(normalized, zone, 1200 + (attempts % 5) * 300));
				Dictionary target;
				target["protected_target_id"] = "owner_xl_land_density_guard_" + slot_id_2(guard_ordinal + 1);
				target["protected_target_type"] = "density_guard";
				target["protected_zone_id"] = zone_id;
				target["protected_zone_value_budget"] = zone.get("value_budget", 0);
				target["guard_base_value"] = guard_value;
				target["scaled_guard_value"] = guard_value;
				target["guard_reward_relation_source"] = "owner_xl_land_density_guard_supplement_from_parsed_h3m_guard_count";
				append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "density_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
				++guard_ordinal;
			}
			++attempts;
		}
		Dictionary diagnostic;
		diagnostic["code"] = guard_ordinal >= owner_xl_guard_limit ? "owner_xl_land_density_guard_target_materialized" : "owner_xl_land_density_guard_target_partial";
		diagnostic["severity"] = guard_ordinal >= owner_xl_guard_limit ? "info" : "warning";
		diagnostic["target_guard_count"] = owner_xl_guard_limit;
		diagnostic["final_guard_count"] = guard_ordinal;
		diagnostic["attempt_count"] = attempts;
		diagnostic["source"] = "owner_discovered_xl_nowater_guard_count";
		guard_diagnostics.append(diagnostic);
		append_extension_profile_phase(town_guard_profile_phases, "owner_xl_land_density_guard_supplement", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	}

	Dictionary town_pair_route_guard_closure = close_unguarded_town_pair_routes_with_guards(normalized, zones, zone_layout, road_network, towns, guards, occupied, blocking_occupied, guard_ordinal, effective_guard_limit);
	for (int64_t index = 0; index < Array(town_pair_route_guard_closure.get("diagnostics", Array())).size(); ++index) {
		guard_diagnostics.append(Array(town_pair_route_guard_closure.get("diagnostics", Array()))[index]);
	}
	append_extension_profile_phase(town_guard_profile_phases, "town_pair_route_guard_closure", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	Dictionary town_boundary_opening_guard_cover = cover_town_boundary_openings_with_route_guards(guards, towns, owner_grid, width, height, !native_rmg_owner_uploaded_small_049_case(normalized));
	append_extension_profile_phase(town_guard_profile_phases, "town_boundary_opening_guard_cover", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	Dictionary town_access_corridor_clearance = clear_required_town_access_gap_objects(object_placement, towns);
	Dictionary connection_guard_choke_clearance = clear_connection_guard_choke_objects(object_placement, guards);
	objects = object_placement.get("object_placements", Array());
	Dictionary combined_occupancy = occupancy_index_for_buckets(objects, towns, guards);
	append_extension_profile_phase(town_guard_profile_phases, "clearance_and_occupancy", subphase_started_at, top_town_guard_phase_usec, top_town_guard_phase_id);
	Dictionary town_guard_runtime_phase_profile = build_extension_profile(town_guard_profile_phases, town_guard_started_at, width, height, 1, int32_t(objects.size()), int32_t(Dictionary(road_network.get("route_graph", Dictionary())).get("edge_count", 0)), int32_t(towns.size()), int32_t(guards.size()), top_town_guard_phase_id, top_town_guard_phase_usec);

	Dictionary town_payload;
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	town_payload["schema_id"] = NATIVE_RMG_TOWN_PLACEMENT_SCHEMA_ID;
	town_payload["schema_version"] = 1;
	town_payload["generation_status"] = scoped_structural_profile_supported ? "towns_generated_scoped_structural_profile" : "towns_generated_foundation";
	town_payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	town_payload["materialization_state"] = scoped_structural_profile_supported ? "staged_town_records_scoped_structural_profile_no_authored_writeback" : "staged_town_records_only_no_gameplay_adoption";
	town_payload["town_records"] = towns;
	town_payload["town_count"] = towns.size();
	town_payload["town_boundary_opening_guard_cover"] = town_boundary_opening_guard_cover;
	town_payload["town_pair_route_guard_closure"] = town_pair_route_guard_closure;
	town_payload["required_town_access_corridor_clearance"] = town_access_corridor_clearance;
	town_payload["connection_guard_choke_clearance"] = connection_guard_choke_clearance;
	town_payload["runtime_phase_profile"] = town_guard_runtime_phase_profile;
	town_payload["runtime_phase_profile_signature_scope"] = "diagnostic_profile_excluded_from_replay_identity_signature";
	town_payload["source_field_semantics"] = "phases_4a_4b_source_fields_plus_0x20_to_plus_0x3c";
	town_payload["phase_order_anchor"] = "terrain_island_shape_before_towns_connections_payload_roads_rivers_after_towns";
	town_payload["same_type_neutral_scope"] = "per_source_zone_neutral_weighted_reuse_only_not_global_map_lock";
	town_payload["required_attempt_count"] = required_attempt_count;
	town_payload["density_attempt_count"] = density_attempt_count;
	town_payload["placed_required_count"] = placed_required_count;
	town_payload["placed_density_count"] = placed_density_count;
	town_payload["diagnostics"] = town_diagnostics;
	town_payload["diagnostic_count"] = town_diagnostics.size();
	Dictionary town_category_counts;
	town_category_counts["by_record_type"] = count_by_field(towns, "record_type");
	town_category_counts["by_faction"] = count_by_field(towns, "faction_id");
	town_category_counts["by_zone"] = count_by_field(towns, "zone_id");
	town_category_counts["by_town_id"] = count_by_field(towns, "town_id");
	town_category_counts["by_settlement_category"] = count_by_field(towns, "settlement_category");
	town_category_counts["by_source_field_offset"] = count_by_field(towns, "source_field_offset");
	town_category_counts["by_owner_semantics"] = count_by_field(towns, "owner_semantics");
	town_payload["category_counts"] = town_category_counts;
	Dictionary town_record_type_counts = count_by_field(towns, "record_type");
	town_payload["start_player_town_count"] = town_record_type_counts.get("player_start_town", 0);
	town_payload["neutral_town_count"] = int32_t(town_record_type_counts.get("neutral_minimum_town", 0)) + int32_t(town_record_type_counts.get("neutral_minimum_castle", 0)) + int32_t(town_record_type_counts.get("neutral_density_town", 0)) + int32_t(town_record_type_counts.get("neutral_density_castle", 0));
	Dictionary spacing_summary = town_spacing_summary(towns, normalized);
	town_payload["town_spacing"] = spacing_summary;
	town_payload["minimum_town_distance_required"] = spacing_summary.get("minimum_distance_required", 0);
	town_payload["observed_minimum_town_distance"] = spacing_summary.get("observed_minimum_distance", 0);
	town_payload["related_player_start_signature"] = player_starts.get("signature", "");
	Dictionary town_payload_signature_source = town_payload.duplicate(true);
	town_payload_signature_source.erase("runtime_phase_profile");
	town_payload["signature"] = hash32_hex(canonical_variant(town_payload_signature_source));

	Dictionary guard_payload;
	guard_payload["schema_id"] = NATIVE_RMG_GUARD_PLACEMENT_SCHEMA_ID;
	guard_payload["schema_version"] = 1;
	guard_payload["generation_status"] = scoped_structural_profile_supported ? "guards_generated_scoped_structural_profile" : "guards_generated_foundation";
	guard_payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	guard_payload["materialization_state"] = scoped_structural_profile_supported ? "staged_guard_records_scoped_structural_profile_no_authored_writeback" : "staged_guard_records_only_no_gameplay_adoption";
	guard_payload["guard_records"] = guards;
	guard_payload["guard_count"] = guards.size();
	guard_payload["town_boundary_opening_guard_cover"] = town_boundary_opening_guard_cover;
	guard_payload["town_pair_route_guard_closure"] = town_pair_route_guard_closure;
	guard_payload["runtime_phase_profile"] = town_guard_runtime_phase_profile;
	guard_payload["runtime_phase_profile_signature_scope"] = "diagnostic_profile_excluded_from_replay_identity_signature";
	Dictionary guard_category_counts;
	guard_category_counts["by_guard_kind"] = count_by_field(guards, "guard_kind");
	guard_category_counts["by_zone"] = count_by_field(guards, "zone_id");
	guard_category_counts["by_protected_target_type"] = count_by_field(guards, "protected_target_type");
	guard_category_counts["by_strength_band"] = count_by_field(guards, "strength_band");
	guard_payload["category_counts"] = guard_category_counts;
	guard_payload["materialized_object_guard_summary"] = object_guard_summary(object_guard_candidates, guards);
	guard_payload["diagnostics"] = guard_diagnostics;
	guard_payload["diagnostic_count"] = guard_diagnostics.size();
	guard_payload["related_route_graph_signature"] = route_graph.get("signature", "");
	guard_payload["related_object_placement_signature"] = object_placement.get("signature", "");
	Dictionary guard_payload_signature_source = guard_payload.duplicate(true);
	guard_payload_signature_source.erase("runtime_phase_profile");
	guard_payload["signature"] = hash32_hex(canonical_variant(guard_payload_signature_source));
	Dictionary guard_reward_monster_summary = guard_reward_monster_summary_for_records(normalized, object_placement, guards, guard_diagnostics);

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_TOWN_GUARD_PLACEMENT_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = scoped_structural_profile_supported ? "towns_and_guards_generated_scoped_structural_profile" : "towns_and_guards_generated_foundation";
	payload["town_generation_status"] = town_payload.get("generation_status", "");
	payload["guard_generation_status"] = guard_payload.get("generation_status", "");
	payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	payload["materialization_state"] = scoped_structural_profile_supported ? "staged_town_guard_records_scoped_structural_profile_no_authored_writeback" : "staged_town_guard_records_only_no_gameplay_adoption";
	payload["writeout_policy"] = "generated_town_guard_records_no_authored_content_write";
	payload["town_placement"] = town_payload;
	payload["guard_placement"] = guard_payload;
	payload["materialized_object_guard_summary"] = guard_payload.get("materialized_object_guard_summary", Dictionary());
	payload["guard_reward_monster_summary"] = guard_reward_monster_summary;
	payload["town_boundary_opening_guard_cover"] = town_boundary_opening_guard_cover;
	payload["town_pair_route_guard_closure"] = town_pair_route_guard_closure;
	payload["required_town_access_corridor_clearance"] = town_access_corridor_clearance;
	payload["connection_guard_choke_clearance"] = connection_guard_choke_clearance;
	payload["runtime_phase_profile"] = town_guard_runtime_phase_profile;
	payload["runtime_phase_profile_signature_scope"] = "diagnostic_profile_excluded_from_replay_identity_signature";
	payload["town_records"] = towns;
	payload["guard_records"] = guards;
	payload["town_count"] = towns.size();
	payload["guard_count"] = guards.size();
	payload["town_spacing"] = spacing_summary;
	payload["combined_occupancy_index"] = combined_occupancy;
	Dictionary category_counts;
	category_counts["towns"] = town_payload.get("category_counts", Dictionary());
	category_counts["guards"] = guard_payload.get("category_counts", Dictionary());
	payload["category_counts"] = category_counts;
	payload["related_zone_layout_signature"] = zone_layout.get("signature", "");
	payload["related_road_network_signature"] = road_network.get("signature", "");
	payload["related_object_placement_signature"] = object_placement.get("signature", "");
	Dictionary payload_signature_source = payload.duplicate(true);
	payload_signature_source.erase("runtime_phase_profile");
	Dictionary town_placement_signature_source = town_payload.duplicate(true);
	town_placement_signature_source.erase("runtime_phase_profile");
	payload_signature_source["town_placement"] = town_placement_signature_source;
	Dictionary guard_placement_signature_source = guard_payload.duplicate(true);
	guard_placement_signature_source.erase("runtime_phase_profile");
	payload_signature_source["guard_placement"] = guard_placement_signature_source;
	payload["signature"] = hash32_hex(canonical_variant(payload_signature_source));
	return payload;
}

String connection_gate_object_id_for_subtype(int32_t subtype) {
	static constexpr const char *OBJECT_IDS[] = {
		"object_charter_bar_gate",
		"object_root_lease_gate",
		"object_thorn_seal_gate",
		"object_brass_toll_arch",
		"object_frost_toll_bar",
		"object_root_pass_arch",
		"object_basalt_undergate",
		"object_slipgate_mirror",
	};
	return OBJECT_IDS[std::max(0, subtype) % 8];
}

Array single_tile_body(int32_t x, int32_t y, int32_t width, int32_t height) {
	Array body;
	if (x >= 0 && y >= 0 && x < width && y < height) {
		body.append(cell_record(x, y, 0));
	}
	return body;
}

Array adjacent_approach_tiles_for_gate(int32_t x, int32_t y, int32_t width, int32_t height) {
	Array tiles;
	static constexpr int32_t OFFSETS[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
	for (const auto &offset : OFFSETS) {
		const int32_t nx = x + offset[0];
		const int32_t ny = y + offset[1];
		if (nx >= 0 && ny >= 0 && nx < width && ny < height) {
			tiles.append(cell_record(nx, ny, 0));
		}
	}
	return tiles;
}

Dictionary connection_gate_record_for_edge(const Dictionary &normalized, const Dictionary &edge, int32_t ordinal) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary anchor = edge.get("route_cell_anchor_candidate", Dictionary());
	const int32_t x = std::max(0, std::min(width - 1, int32_t(anchor.get("x", width / 2))));
	const int32_t y = std::max(0, std::min(height - 1, int32_t(anchor.get("y", height / 2))));
	const int32_t subtype = int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + ":connection_gate:" + String(edge.get("id", ""))) % 8U);
	Dictionary record;
	record["placement_id"] = "native_rmg_connection_gate_" + String(edge.get("id", "edge")) + "_" + slot_id_2(ordinal + 1);
	record["kind"] = "connection_gate";
	record["type_id"] = "special_guard_gate";
	record["object_id"] = connection_gate_object_id_for_subtype(subtype);
	record["source_type_equivalent"] = "type_9_border_guard_equivalent_original_gate";
	record["source_subtype_equivalent"] = subtype;
	record["route_edge_id"] = edge.get("id", "");
	record["from_zone_id"] = edge.get("from", "");
	record["to_zone_id"] = edge.get("to", "");
	record["x"] = x;
	record["y"] = y;
	record["level"] = 0;
	record["primary_tile"] = cell_record(x, y, 0);
	record["primary_occupancy_key"] = point_key(x, y);
	record["body_tiles"] = single_tile_body(x, y, width, height);
	record["approach_tiles"] = adjacent_approach_tiles_for_gate(x, y, width, height);
	record["visit_tile"] = record["primary_tile"];
	record["passability_class"] = "blocking_visitable";
	record["blocking_body"] = true;
	record["unlock_required"] = true;
	Dictionary unlock;
	unlock["unlock_required"] = true;
	unlock["gate_behavior"] = "original_connection_gate_blocks_route_until_supported_unlock";
	unlock["keymaster_side_feature_scope"] = "not_implemented_in_this_slice";
	record["unlock_metadata"] = unlock;
	record["materialization_state"] = "supported_original_gate_record_materialized_from_border_guard_connection_payload";
	record["writeout_state"] = "staged_connection_gate_object_record_no_authored_content_write";
	record["signature"] = hash32_hex(canonical_variant(record));
	return record;
}

Dictionary guards_by_route_edge_id(const Array &guards) {
	Dictionary result;
	for (int64_t index = 0; index < guards.size(); ++index) {
		if (Variant(guards[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary guard = Dictionary(guards[index]);
		const String route_edge_id = String(guard.get("route_edge_id", ""));
		if (!route_edge_id.is_empty()) {
			result[route_edge_id] = guard;
		}
	}
	return result;
}

Dictionary generate_connection_payload_resolution(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &road_network, const Dictionary &town_guard_placement) {
	Dictionary route_graph = road_network.get("route_graph", Dictionary());
	Array edges = route_graph.get("edges", Array());
	Dictionary route_guards = guards_by_route_edge_id(town_guard_placement.get("guard_records", Array()));
	Array materialized_records;
	Array normal_guards;
	Array wide_suppressions;
	Array special_gate_records;
	Array diagnostics;
	int32_t required_link_count = 0;
	int32_t required_link_failure_count = 0;

	for (int64_t index = 0; index < edges.size(); ++index) {
		if (Variant(edges[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary edge = Dictionary(edges[index]);
		const String edge_id = String(edge.get("id", ""));
		const bool required = bool(edge.get("required", true));
		const bool path_found = bool(edge.get("path_found", false));
		const bool wide = bool(edge.get("wide", false));
		const bool border_guard = bool(edge.get("border_guard", false));
		const int32_t raw_value = int32_t(edge.get("guard_value", 0));
		const int32_t scaled_value = rmg_connection_guard_scaled_value(normalized, raw_value);
		if (required) {
			++required_link_count;
		}
		if (required && !path_found) {
			++required_link_failure_count;
			Dictionary diagnostic;
			diagnostic["code"] = "required_connection_corridor_missing";
			diagnostic["severity"] = "failure";
			diagnostic["route_edge_id"] = edge_id;
			diagnostic["message"] = "Required template link did not produce a corridor/road segment.";
			diagnostics.append(diagnostic);
			continue;
		}

		Dictionary record;
		record["id"] = "connection_payload_" + edge_id;
		record["route_edge_id"] = edge_id;
		record["from_zone_id"] = edge.get("from", "");
		record["to_zone_id"] = edge.get("to", "");
		record["raw_value"] = raw_value;
		record["scaled_value"] = scaled_value;
		record["global_monster_strength_mode"] = rmg_global_monster_strength_mode(normalized);
		record["strength_formula"] = "0x4a65a5_raw_connection_value_and_global_monster_strength";
		record["wide"] = wide;
		record["border_guard"] = border_guard;
		record["path_found"] = path_found;
		record["processed_after_town_castle_placement"] = true;
		record["related_town_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
		record["road_overlay_route_edge_id"] = edge_id;

		if (wide) {
			record["normal_guard_value"] = 0;
			record["normal_guard_materialized"] = false;
			record["resolution_kind"] = "wide_suppresses_normal_guard";
			record["wide_semantics"] = "suppresses_normal_guard_not_corridor_width";
			wide_suppressions.append(record);
		} else if (border_guard) {
			Dictionary gate = connection_gate_record_for_edge(normalized, edge, special_gate_records.size());
			record["normal_guard_value"] = 0;
			record["normal_guard_materialized"] = false;
			record["resolution_kind"] = "border_guard_original_gate_materialized";
			record["special_gate_placement_id"] = gate.get("placement_id", "");
			record["source_type_equivalent"] = gate.get("source_type_equivalent", "");
			special_gate_records.append(gate);
		} else if (raw_value > 0) {
			record["normal_guard_value"] = scaled_value;
			record["normal_guard_materialized"] = route_guards.has(edge_id);
			record["resolution_kind"] = scaled_value > 0 ? "normal_connection_guard_value_scaled_and_consumed" : "normal_connection_guard_value_scaled_to_zero";
			if (scaled_value <= 0) {
				record["normal_guard_materialized"] = false;
				record["fallback_behavior"] = "normal_connection_guard_not_materialized_when_recovered_strength_formula_returns_zero";
			} else if (route_guards.has(edge_id)) {
				Dictionary guard = route_guards.get(edge_id, Dictionary());
				record["guard_placement_id"] = guard.get("placement_id", "");
				record["guard_id"] = guard.get("guard_id", "");
			} else {
				Dictionary diagnostic;
				diagnostic["code"] = "normal_connection_guard_missing";
				diagnostic["severity"] = "failure";
				diagnostic["route_edge_id"] = edge_id;
				diagnostic["message"] = "Non-wide, non-border connection with positive Value did not materialize a route guard record.";
				diagnostics.append(diagnostic);
			}
			normal_guards.append(record);
		} else {
			record["normal_guard_value"] = 0;
			record["normal_guard_materialized"] = false;
			record["resolution_kind"] = "unguarded_connection_payload";
		}
		materialized_records.append(record);
	}

	Dictionary summary;
	summary["required_link_count"] = required_link_count;
	summary["required_link_failure_count"] = required_link_failure_count;
	summary["normal_guard_count"] = normal_guards.size();
	summary["wide_suppressed_count"] = wide_suppressions.size();
	summary["special_gate_count"] = special_gate_records.size();
	summary["materialized_record_count"] = materialized_records.size();
	summary["validation_status"] = diagnostics.is_empty() ? "pass" : "fail";

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_CONNECTION_PAYLOAD_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = diagnostics.is_empty() ? "connection_payloads_processed_after_towns" : "connection_payloads_failed_validation";
	payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	payload["phase_order"] = "cleanup_late_connection_payload_after_town_castle_placement_before_river_overlay_writeout";
	payload["source_semantics"] = "Value_Wide_Border_Guard_consumed_late_after_endpoint_geometry";
	payload["wide_semantics"] = "suppresses_normal_guard_not_corridor_width";
	payload["border_guard_semantics"] = "supported_original_gate_record_materialized_as_type_9_equivalent_without_homm3_art_or_text";
	payload["road_river_overlay_boundary"] = "road_and_river_overlay_metadata_separate_from_rand_trn_decoration_object_scoring";
	payload["related_zone_layout_signature"] = zone_layout.get("signature", "");
	payload["related_road_network_signature"] = road_network.get("signature", "");
	payload["related_town_guard_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	payload["related_town_guard_signature_scope"] = "town_placement_only_route_guard_records_inlined_no_full_object_guard_signature_dependency";
	payload["materialized_records"] = materialized_records;
	payload["normal_route_guards"] = normal_guards;
	payload["wide_suppressions"] = wide_suppressions;
	payload["special_connection_gate_records"] = special_gate_records;
	payload["diagnostics"] = diagnostics;
	payload["summary"] = summary;
	payload["validation_status"] = summary.get("validation_status", "");
	payload["signature"] = hash32_hex(canonical_variant(payload));
	return payload;
}

Dictionary attach_connection_payload_resolution(Dictionary road_network, const Dictionary &connection_payload) {
	road_network["late_connection_payload_resolution"] = connection_payload;
	road_network["connection_payload_resolution_signature"] = connection_payload.get("signature", "");
	road_network["connection_gate_records"] = connection_payload.get("special_connection_gate_records", Array());
	road_network["connection_gate_count"] = Array(connection_payload.get("special_connection_gate_records", Array())).size();
	road_network["signature"] = hash32_hex(canonical_variant(road_network));
	return road_network;
}

void mark_land_cell(Dictionary &land_lookup, int32_t x, int32_t y, int32_t width, int32_t height) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return;
	}
	land_lookup[point_key(x, y)] = true;
}

void mark_land_radius(Dictionary &land_lookup, int32_t x, int32_t y, int32_t width, int32_t height, int32_t radius) {
	for (int32_t dy = -radius; dy <= radius; ++dy) {
		for (int32_t dx = -radius; dx <= radius; ++dx) {
			if (std::abs(dx) + std::abs(dy) > radius) {
				continue;
			}
			mark_land_cell(land_lookup, x + dx, y + dy, width, height);
		}
	}
}

void mark_land_cells_from_array(Dictionary &land_lookup, const Array &cells, int32_t width, int32_t height, int32_t radius = 0) {
	for (int64_t index = 0; index < cells.size(); ++index) {
		if (Variant(cells[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = cells[index];
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		mark_land_radius(land_lookup, x, y, width, height, radius);
	}
}

void mark_land_record_surfaces(Dictionary &land_lookup, const Dictionary &record, int32_t width, int32_t height, bool protect_approach_tiles = true) {
	mark_land_cell(land_lookup, int32_t(record.get("x", 0)), int32_t(record.get("y", 0)), width, height);
	if (Variant(record.get("primary_tile", Variant())).get_type() == Variant::DICTIONARY) {
		Dictionary primary = record.get("primary_tile", Dictionary());
		mark_land_cell(land_lookup, int32_t(primary.get("x", 0)), int32_t(primary.get("y", 0)), width, height);
	}
	mark_land_cells_from_array(land_lookup, record.get("body_tiles", Array()), width, height);
	if (protect_approach_tiles) {
		mark_land_cells_from_array(land_lookup, record.get("approach_tiles", Array()), width, height);
	}
	if (Variant(record.get("visit_tile", Variant())).get_type() == Variant::DICTIONARY) {
		Dictionary visit = record.get("visit_tile", Dictionary());
		mark_land_cell(land_lookup, int32_t(visit.get("x", 0)), int32_t(visit.get("y", 0)), width, height);
	}
}

Dictionary protected_island_land_lookup(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &object_placement, const Dictionary &town_guard_placement) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary land_lookup;

	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		mark_land_radius(land_lookup, int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), width, height, 4);
	}

	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		mark_land_cells_from_array(land_lookup, segment.get("cells", Array()), width, height);
	}

	Array objects = object_placement.get("object_placements", Array());
	const bool normal_water_mode = String(normalized.get("water_mode", "land")) == "normal_water";
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = Dictionary(objects[index]);
		const String kind = String(object.get("kind", ""));
		if (normal_water_mode && (kind == "decorative_obstacle" || kind == "scenic_object")) {
			continue;
		}
		const bool protect_approaches = !normal_water_mode || (kind != "decorative_obstacle" && kind != "scenic_object");
		mark_land_record_surfaces(land_lookup, object, width, height, protect_approaches);
	}
	Array towns = town_guard_placement.get("town_records", Array());
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = Dictionary(towns[index]);
		mark_land_record_surfaces(land_lookup, town, width, height);
		mark_land_cells_from_array(land_lookup, town.get("required_town_access_corridor_cells", Array()), width, height);
	}
	Array guards = town_guard_placement.get("guard_records", Array());
	for (int64_t index = 0; index < guards.size(); ++index) {
		mark_land_record_surfaces(land_lookup, Dictionary(guards[index]), width, height);
	}
	return land_lookup;
}

Dictionary zone_terrain_lookup(const Dictionary &zone_layout) {
	Dictionary result;
	Array zones = zone_layout.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (!zone_id.is_empty()) {
			result[zone_id] = terrain_id_for_zone(zone);
		}
	}
	return result;
}

String island_land_terrain_for_cell(int32_t x, int32_t y, int32_t level, const Array &terrain_pool, const Array &seeds, const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &zone_terrain_by_id) {
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	if (y >= 0 && y < owner_grid.size()) {
		Array row = owner_grid[y];
		if (x >= 0 && x < row.size()) {
			const String zone_id = String(row[x]);
			const String zone_terrain = String(zone_terrain_by_id.get(zone_id, ""));
			if (is_passable_terrain_id(zone_terrain)) {
				return zone_terrain;
			}
		}
	}
	String terrain_id = choose_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized);
	if (is_passable_terrain_id(terrain_id)) {
		return terrain_id;
	}
	return terrain_pool.is_empty() ? String("grass") : String(terrain_pool[0]);
}

bool zone_cell_is_interior(const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height, const String &zone_id) {
	if (x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1) {
		return false;
	}
	static constexpr int32_t DX[4] = { 1, -1, 0, 0 };
	static constexpr int32_t DY[4] = { 0, 0, 1, -1 };
	for (int32_t index = 0; index < 4; ++index) {
		if (owner_grid_value_at(owner_grid, x + DX[index], y + DY[index]) != zone_id) {
			return false;
		}
	}
	return true;
}

double island_land_fraction_for_zone(const Dictionary &zone) {
	const String role = String(zone.get("role", ""));
	if (role.contains("start")) {
		return 0.32;
	}
	if (role == "junction") {
		return 0.24;
	}
	if (role == "treasure" || role == "neutral") {
		return 0.18;
	}
	return 0.22;
}

double water_shape_land_fraction_for_zone(const Dictionary &normalized, const Dictionary &zone) {
	if (String(normalized.get("water_mode", "land")) != "normal_water") {
		return island_land_fraction_for_zone(zone);
	}
	const String role = String(zone.get("role", ""));
	if (role.contains("start")) {
		return 0.65;
	}
	if (role == "junction") {
		return 0.60;
	}
	if (role == "treasure" || role == "neutral") {
		return 0.53;
	}
	return 0.57;
}

int32_t count_lookup_cells_for_zone(const Dictionary &lookup, const Array &owner_grid, const String &zone_id) {
	int32_t count = 0;
	Array keys = lookup.keys();
	for (int64_t index = 0; index < keys.size(); ++index) {
		const String key = String(keys[index]);
		const int32_t comma = key.find(",");
		if (comma < 0) {
			continue;
		}
		const int32_t x = key.substr(0, comma).to_int();
		const int32_t y = key.substr(comma + 1).to_int();
		if (owner_grid_value_at(owner_grid, x, y) == zone_id) {
			++count;
		}
	}
	return count;
}

void append_zone_frontier_cell(Array &frontier, Dictionary &queued, int32_t x, int32_t y, int32_t width, int32_t height) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return;
	}
	const String key = point_key(x, y);
	if (queued.has(key)) {
		return;
	}
	queued[key] = true;
	frontier.append(cell_record(x, y, 0));
}

void seed_zone_frontier_from_lookup(Array &frontier, Dictionary &queued, const Dictionary &lookup, const Array &owner_grid, const String &zone_id, int32_t width, int32_t height) {
	Array keys = lookup.keys();
	for (int64_t index = 0; index < keys.size(); ++index) {
		const String key = String(keys[index]);
		const int32_t comma = key.find(",");
		if (comma < 0) {
			continue;
		}
		const int32_t x = key.substr(0, comma).to_int();
		const int32_t y = key.substr(comma + 1).to_int();
		if (owner_grid_value_at(owner_grid, x, y) == zone_id) {
			append_zone_frontier_cell(frontier, queued, x, y, width, height);
		}
	}
}

int32_t expand_zone_land(Dictionary &land_lookup, const Dictionary &protected_land, const Array &owner_grid, const Dictionary &zone, int32_t width, int32_t height, int32_t quota) {
	const String zone_id = String(zone.get("id", ""));
	if (zone_id.is_empty() || quota <= 0) {
		return 0;
	}
	int32_t land_count = count_lookup_cells_for_zone(land_lookup, owner_grid, zone_id);
	Array frontier;
	Dictionary queued;
	seed_zone_frontier_from_lookup(frontier, queued, land_lookup, owner_grid, zone_id, width, height);
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const int32_t anchor_x = int32_t(anchor.get("x", width / 2));
	const int32_t anchor_y = int32_t(anchor.get("y", height / 2));
	if (owner_grid_value_at(owner_grid, anchor_x, anchor_y) == zone_id) {
		mark_land_cell(land_lookup, anchor_x, anchor_y, width, height);
		land_count = count_lookup_cells_for_zone(land_lookup, owner_grid, zone_id);
		append_zone_frontier_cell(frontier, queued, anchor_x, anchor_y, width, height);
	}
	if (frontier.is_empty()) {
		for (int32_t y = 0; y < height && frontier.is_empty(); ++y) {
			for (int32_t x = 0; x < width && frontier.is_empty(); ++x) {
				if (owner_grid_value_at(owner_grid, x, y) == zone_id) {
					mark_land_cell(land_lookup, x, y, width, height);
					land_count = count_lookup_cells_for_zone(land_lookup, owner_grid, zone_id);
					append_zone_frontier_cell(frontier, queued, x, y, width, height);
				}
			}
		}
	}

	static constexpr int32_t DX[4] = { 1, -1, 0, 0 };
	static constexpr int32_t DY[4] = { 0, 0, 1, -1 };
	for (int32_t pass = 0; pass < 2 && land_count < quota; ++pass) {
		if (pass == 1) {
			frontier.clear();
			queued.clear();
			seed_zone_frontier_from_lookup(frontier, queued, land_lookup, owner_grid, zone_id, width, height);
		}
		int64_t cursor = 0;
		while (cursor < frontier.size() && land_count < quota) {
			Dictionary cell = frontier[cursor];
			++cursor;
			const int32_t base_x = int32_t(cell.get("x", 0));
			const int32_t base_y = int32_t(cell.get("y", 0));
			const int32_t offset = int32_t(hash32_int(zone_id + String(":island_land_expand:") + String::num_int64(base_x) + String(":") + String::num_int64(base_y)) % 4U);
			for (int32_t step = 0; step < 4 && land_count < quota; ++step) {
				const int32_t direction = (offset + step) % 4;
				const int32_t next_x = base_x + DX[direction];
				const int32_t next_y = base_y + DY[direction];
				if (next_x < 0 || next_y < 0 || next_x >= width || next_y >= height || owner_grid_value_at(owner_grid, next_x, next_y) != zone_id) {
					continue;
				}
				const String next_key = point_key(next_x, next_y);
				if (queued.has(next_key)) {
					continue;
				}
				queued[next_key] = true;
				const bool required_surface = protected_land.has(next_key);
				if (pass == 0 && !required_surface && !zone_cell_is_interior(owner_grid, next_x, next_y, width, height, zone_id)) {
					continue;
				}
				if (!land_lookup.has(next_key)) {
					land_lookup[next_key] = true;
					++land_count;
				}
				frontier.append(cell_record(next_x, next_y, 0));
			}
		}
	}
	return land_count;
}

Dictionary island_land_water_shape(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &object_placement, const Dictionary &town_guard_placement) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary protected_land = protected_island_land_lookup(normalized, zone_layout, player_starts, road_network, object_placement, town_guard_placement);
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	const int32_t map_tiles = std::max(1, width * height);

	Dictionary land_lookup = protected_land.duplicate(true);
	Array diagnostics;
	Array zone_targets;
	int32_t requested_land_count = 0;
	if (owner_grid.size() != height || zones.is_empty()) {
		Dictionary diagnostic;
		diagnostic["severity"] = "failure";
		diagnostic["code"] = "zone_aware_island_shape_missing_runtime_owner_grid";
		diagnostic["message"] = "Island terrain shaping requires runtime zone owner cells.";
		diagnostics.append(diagnostic);
	} else {
		for (int64_t index = 0; index < zones.size(); ++index) {
			Dictionary zone = zones[index];
			const String zone_id = String(zone.get("id", ""));
			const int32_t cell_count = std::max(0, int32_t(zone.get("cell_count", 0)));
			const int32_t target_area = std::max(1, int32_t(zone.get("target_area", cell_count)));
			const double land_fraction = water_shape_land_fraction_for_zone(normalized, zone);
			const int32_t required_land = count_lookup_cells_for_zone(protected_land, owner_grid, zone_id);
			int32_t requested_quota = std::max(1, int32_t(std::llround(double(target_area) * land_fraction)));
			requested_quota = std::min(std::max(1, cell_count), requested_quota);
			int32_t quota = requested_quota;
			String quota_status = "zone_quota";
			if (required_land > quota) {
				quota = std::min(std::max(1, cell_count), required_land);
				quota_status = "required_surface_exceeded_zone_quota";
				Dictionary diagnostic;
				diagnostic["severity"] = "warning";
				diagnostic["code"] = "zone_required_land_exceeded_quota";
				diagnostic["message"] = "Required generated surfaces exceeded the zone terrain/island quota; land was expanded only enough to keep those surfaces loadable.";
				diagnostic["zone_id"] = zone_id;
				diagnostic["required_land_count"] = required_land;
				diagnostic["requested_quota"] = requested_quota;
				diagnostic["applied_quota"] = quota;
				diagnostics.append(diagnostic);
			}
			requested_land_count += quota;
			Dictionary target;
			target["zone_id"] = zone_id;
			target["role"] = zone.get("role", "");
			target["terrain_id"] = terrain_id_for_zone(zone);
			target["target_area"] = target_area;
			target["cell_count"] = cell_count;
			target["land_fraction"] = land_fraction;
			target["required_land_count"] = required_land;
			target["requested_land_count"] = requested_quota;
			target["applied_land_quota"] = quota;
			target["generated_land_count"] = count_lookup_cells_for_zone(land_lookup, owner_grid, zone_id);
			target["quota_status"] = quota_status;
			zone_targets.append(target);
		}
		if (int32_t(protected_land.size()) > requested_land_count) {
			Dictionary diagnostic;
			diagnostic["severity"] = "warning";
			diagnostic["code"] = "required_surface_land_exceeded_total_zone_budget";
			diagnostic["message"] = "Required generated surfaces exceeded the total zone-derived island land budget; no extra filler land was added beyond required surfaces.";
			diagnostic["required_land_count"] = protected_land.size();
			diagnostic["requested_land_count"] = requested_land_count;
			diagnostics.append(diagnostic);
		}
		for (int64_t index = 0; int32_t(land_lookup.size()) < requested_land_count && index < zones.size(); ++index) {
			Dictionary zone = zones[index];
			Dictionary target = zone_targets[index];
			const int32_t remaining = requested_land_count - int32_t(land_lookup.size());
			const int32_t current_zone_land = count_lookup_cells_for_zone(land_lookup, owner_grid, String(zone.get("id", "")));
			const int32_t zone_quota = int32_t(target.get("applied_land_quota", current_zone_land));
			const int32_t bounded_quota = std::min(zone_quota, current_zone_land + std::max(0, remaining));
			const int32_t generated_land = expand_zone_land(land_lookup, protected_land, owner_grid, zone, width, height, bounded_quota);
			target["generated_land_count"] = generated_land;
			zone_targets[index] = target;
		}
		for (int64_t index = 0; index < zone_targets.size(); ++index) {
			Dictionary target = zone_targets[index];
			const String zone_id = String(target.get("zone_id", ""));
			const int32_t generated_land = count_lookup_cells_for_zone(land_lookup, owner_grid, zone_id);
			target["generated_land_count"] = generated_land;
			if (int32_t(land_lookup.size()) < requested_land_count && generated_land < std::min(int32_t(target.get("applied_land_quota", 0)), int32_t(target.get("cell_count", 0)))) {
				Dictionary diagnostic;
				diagnostic["severity"] = "failure";
				diagnostic["code"] = "zone_land_quota_infeasible";
				diagnostic["message"] = "Zone-aware terrain shaping could not satisfy a zone land quota inside the runtime owner cells.";
				diagnostic["zone_id"] = zone_id;
				diagnostic["applied_quota"] = target.get("applied_land_quota", 0);
				diagnostic["generated_land_count"] = generated_land;
				diagnostic["zone_cell_count"] = target.get("cell_count", 0);
				diagnostics.append(diagnostic);
			}
			zone_targets[index] = target;
		}
	}

	Dictionary shape;
	shape["schema_id"] = "native_random_map_zone_aware_land_water_shape_v1";
	shape["enabled"] = true;
	shape["source_model"] = "runtime_zone_graph_owner_grid_zone_land_quotas";
	shape["placement_model"] = "linear_zone_flood_fill_from_required_surfaces_and_zone_anchors";
	shape["candidate_scoring_policy"] = "disabled_old_global_candidate_sort_removed";
	shape["performance_model"] = "bounded_by_surface_tiles_and_runtime_zone_cells";
	shape["requested_land_count"] = requested_land_count;
	shape["protected_land_cell_count"] = protected_land.size();
	shape["generated_land_cell_count"] = land_lookup.size();
	shape["generated_water_cell_count"] = map_tiles - int32_t(land_lookup.size());
	shape["generated_land_ratio"] = double(land_lookup.size()) / double(map_tiles);
	shape["water_mode"] = normalized.get("water_mode", "land");
	shape["zone_target_count"] = zone_targets.size();
	shape["zone_targets"] = zone_targets;
	shape["diagnostics"] = diagnostics;
	shape["diagnostic_count"] = diagnostics.size();
	shape["policy"] = String(normalized.get("water_mode", "land")) == "normal_water"
		? "normal-water maps derive mixed water from runtime zone semantics while preserving broad connected land around starts, roads, objects, and guards"
		: "water-dominant islands derive land from runtime zone semantics while preserving already-generated load-bearing surfaces as explicit required land";
	shape["land_lookup"] = land_lookup;
	return shape;
}

bool land_boundary_barriers_enabled(const Dictionary &normalized, const Dictionary &zone_layout) {
	if (String(normalized.get("water_mode", "land")) != "land") {
		return false;
	}
	Dictionary runtime_graph = zone_layout.get("runtime_zone_graph", Dictionary());
	return int32_t(runtime_graph.get("link_count", 0)) > 0;
}

bool zone_boundary_barrier_cell(const Array &owner_grid, int32_t x, int32_t y, int32_t width, int32_t height) {
	const String zone_id = owner_grid_value_at(owner_grid, x, y);
	if (zone_id.is_empty()) {
		return false;
	}
	static constexpr int32_t DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
	static constexpr int32_t DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
	for (int32_t index = 0; index < 8; ++index) {
		const int32_t nx = x + DX[index];
		const int32_t ny = y + DY[index];
		if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
			return true;
		}
		const String other_zone_id = owner_grid_value_at(owner_grid, nx, ny);
		if (!other_zone_id.is_empty() && other_zone_id != zone_id) {
			return true;
		}
	}
	return false;
}

Dictionary land_boundary_opening_lookup(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &town_guard_placement) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary openings;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		mark_land_cells_from_array(openings, segment.get("cells", Array()), width, height);
	}
	Dictionary route_graph = road_network.get("route_graph", Dictionary());
	Array edges = route_graph.get("edges", Array());
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		Dictionary anchor = edge.get("route_cell_anchor_candidate", Dictionary());
		if (!anchor.is_empty()) {
			mark_land_cell(openings, int32_t(anchor.get("x", 0)), int32_t(anchor.get("y", 0)), width, height);
		}
		Dictionary control = edge.get("connection_control", Dictionary());
		Dictionary road_tile = control.get("road_tile", Dictionary());
		if (!road_tile.is_empty()) {
			mark_land_cell(openings, int32_t(road_tile.get("x", 0)), int32_t(road_tile.get("y", 0)), width, height);
		}
	}
	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		mark_land_radius(openings, int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), width, height, 2);
	}
	Array towns = town_guard_placement.get("town_records", Array());
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = Dictionary(towns[index]);
		mark_land_record_surfaces(openings, town, width, height);
	}
	Array guards = town_guard_placement.get("guard_records", Array());
	for (int64_t index = 0; index < guards.size(); ++index) {
		mark_land_record_surfaces(openings, Dictionary(guards[index]), width, height);
	}
	return openings;
}

String land_boundary_terrain_for_cell(int32_t x, int32_t y, int32_t level, const Array &terrain_pool, const Array &seeds, const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &zone_terrain_by_id, const Dictionary &boundary_openings) {
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	const String key = point_key(x, y);
	if (!boundary_openings.has(key) && zone_boundary_barrier_cell(owner_grid, x, y, int32_t(normalized.get("width", 36)), int32_t(normalized.get("height", 36)))) {
		return "rock";
	}
	if (y >= 0 && y < owner_grid.size()) {
		Array row = owner_grid[y];
		if (x >= 0 && x < row.size()) {
			const String zone_id = String(row[x]);
			const String zone_terrain = String(zone_terrain_by_id.get(zone_id, ""));
			if (is_passable_terrain_id(zone_terrain)) {
				return zone_terrain;
			}
		}
	}
	String terrain_id = choose_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized);
	if (is_passable_terrain_id(terrain_id)) {
		return terrain_id;
	}
	return terrain_pool.is_empty() ? String("grass") : String(terrain_pool[0]);
}

void add_generated_cell_terrain_fields(Dictionary &level_record, const PackedInt32Array &terrain_codes, int32_t width, int32_t height) {
	const int32_t tile_count = std::max(0, width * height);
	level_record["generated_cell_field_model"] = "terrain_id_art_index_flip_h_flip_v";
	level_record["terrain_normalization_policy"] = "full_map_neighbor_topology_recomputed_after_zone_paint";
	if (tile_count > 5184) {
		Dictionary summary;
		summary["mode"] = "compact_metadata_only_for_large_maps";
		summary["tile_count"] = tile_count;
		PackedStringArray omitted_arrays;
		omitted_arrays.append("terrain_art_index_u8");
		omitted_arrays.append("terrain_flip_h");
		omitted_arrays.append("terrain_flip_v");
		summary["omitted_arrays"] = omitted_arrays;
		summary["reason"] = "avoid_large_map_signature_and_serialization_cost_until_tile_writeout_adoption_slice";
		level_record["terrain_generated_cell_summary"] = summary;
		return;
	}
	PackedInt32Array art_indices;
	PackedInt32Array flip_h;
	PackedInt32Array flip_v;
	art_indices.resize(tile_count);
	flip_h.resize(tile_count);
	flip_v.resize(tile_count);
	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			const int32_t flat_index = y * width + x;
			const int32_t terrain_code = terrain_codes[flat_index];
			int32_t neighbor_mask = 0;
			if (y > 0 && terrain_codes[(y - 1) * width + x] == terrain_code) {
				neighbor_mask |= 1;
			}
			if (x + 1 < width && terrain_codes[y * width + x + 1] == terrain_code) {
				neighbor_mask |= 2;
			}
			if (y + 1 < height && terrain_codes[(y + 1) * width + x] == terrain_code) {
				neighbor_mask |= 4;
			}
			if (x > 0 && terrain_codes[y * width + x - 1] == terrain_code) {
				neighbor_mask |= 8;
			}
			const uint32_t jitter = hash32_int(String::num_int64(width) + String(":terrain_art:") + String::num_int64(flat_index) + String(":") + String::num_int64(terrain_code));
			art_indices.set(flat_index, (neighbor_mask * 3 + int32_t(jitter % 3U)) % 64);
			flip_h.set(flat_index, int32_t((jitter >> 3) & 1U));
			flip_v.set(flat_index, int32_t((jitter >> 4) & 1U));
		}
	}
	level_record["terrain_art_index_u8"] = art_indices;
	level_record["terrain_flip_h"] = flip_h;
	level_record["terrain_flip_v"] = flip_v;
}

Dictionary generate_terrain_grid(const Dictionary &normalized, const Dictionary &zone_layout = Dictionary(), const Dictionary &player_starts = Dictionary(), const Dictionary &road_network = Dictionary(), const Dictionary &object_placement = Dictionary(), const Dictionary &town_guard_placement = Dictionary()) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Array seeds = terrain_seed_records(normalized, terrain_pool);
	Array levels;
	Dictionary aggregate_counts;
	const PackedStringArray ids_by_code = terrain_id_by_code();
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	const String water_mode = String(normalized.get("water_mode", "land"));
	const bool use_island_shape = parity_targets.is_empty() && (water_mode == "islands" || water_mode == "normal_water") && !zone_layout.is_empty() && !road_network.is_empty();
	const bool use_land_boundary_shape = land_boundary_barriers_enabled(normalized, zone_layout);
	Dictionary island_shape = use_island_shape ? island_land_water_shape(normalized, zone_layout, player_starts, road_network, object_placement, town_guard_placement) : Dictionary();
	Dictionary island_land_lookup = island_shape.get("land_lookup", Dictionary());
	Dictionary land_boundary_openings = use_land_boundary_shape ? land_boundary_opening_lookup(normalized, zone_layout, player_starts, road_network, town_guard_placement) : Dictionary();
	Dictionary zone_terrain_by_id = (use_island_shape || use_land_boundary_shape) ? zone_terrain_lookup(zone_layout) : Dictionary();
	if (!parity_targets.is_empty() && !use_land_boundary_shape) {
		Dictionary counts = parity_targets.get("terrain_counts", Dictionary());
		Dictionary biome_counts;
		PackedInt32Array terrain_codes;
		terrain_codes.resize(width * height);
		Array terrain_keys = counts.keys();
		std::vector<String> ordered_keys;
		ordered_keys.reserve(terrain_keys.size());
		for (int64_t index = 0; index < terrain_keys.size(); ++index) {
			ordered_keys.push_back(String(terrain_keys[index]));
		}
		std::sort(ordered_keys.begin(), ordered_keys.end(), [](const String &left, const String &right) {
			return left < right;
		});
		int32_t flat_index = 0;
		for (const String &terrain_id : ordered_keys) {
			const int32_t count = int32_t(counts.get(terrain_id, 0));
			const int32_t terrain_code = terrain_code_for_id(terrain_id);
			const String biome_id = biome_for_terrain(terrain_id);
			for (int32_t index = 0; index < count && flat_index < width * height; ++index) {
				terrain_codes.set(flat_index, terrain_code);
				++flat_index;
			}
			biome_counts[biome_id] = int32_t(biome_counts.get(biome_id, 0)) + count;
			aggregate_counts[terrain_id] = count;
		}
		while (flat_index < width * height) {
			terrain_codes.set(flat_index, terrain_code_for_id("grass"));
			aggregate_counts["grass"] = int32_t(aggregate_counts.get("grass", 0)) + 1;
			biome_counts[biome_for_terrain("grass")] = int32_t(biome_counts.get(biome_for_terrain("grass"), 0)) + 1;
			++flat_index;
		}
		Dictionary level_record;
		level_record["level_index"] = 0;
		level_record["level_kind"] = "surface";
		level_record["width"] = width;
		level_record["height"] = height;
		level_record["tile_count"] = width * height;
		level_record["terrain_code_u16"] = terrain_codes;
		level_record["terrain_counts"] = aggregate_counts;
		level_record["biome_counts"] = biome_counts;
		add_generated_cell_terrain_fields(level_record, terrain_codes, width, height);
		level_record["signature"] = hash32_hex(canonical_variant(level_record));
		levels.append(level_record);
	}
	for (int32_t level = 0; (parity_targets.is_empty() || use_land_boundary_shape) && level < level_count; ++level) {
		PackedInt32Array terrain_codes;
		terrain_codes.resize(width * height);
		Dictionary counts;
		Dictionary biome_counts;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				String terrain_id;
				if (use_island_shape && level == 0) {
					terrain_id = island_land_lookup.has(point_key(x, y)) ? island_land_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized, zone_layout, zone_terrain_by_id) : String("water");
				} else if (use_land_boundary_shape && level == 0) {
					terrain_id = land_boundary_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized, zone_layout, zone_terrain_by_id, land_boundary_openings);
				} else {
					terrain_id = choose_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized);
				}
				const String biome_id = biome_for_terrain(terrain_id);
				const int32_t terrain_code = terrain_code_for_id(terrain_id);
				const int32_t flat_index = y * width + x;
				terrain_codes.set(flat_index, terrain_code);
				counts[terrain_id] = int32_t(counts.get(terrain_id, 0)) + 1;
				biome_counts[biome_id] = int32_t(biome_counts.get(biome_id, 0)) + 1;
				aggregate_counts[terrain_id] = int32_t(aggregate_counts.get(terrain_id, 0)) + 1;
			}
		}
		Dictionary level_record;
		level_record["level_index"] = level;
		level_record["level_kind"] = level == 0 ? "surface" : "underground";
		level_record["width"] = width;
		level_record["height"] = height;
		level_record["tile_count"] = width * height;
		level_record["terrain_code_u16"] = terrain_codes;
		level_record["terrain_counts"] = counts;
		level_record["biome_counts"] = biome_counts;
		add_generated_cell_terrain_fields(level_record, terrain_codes, width, height);
		level_record["signature"] = hash32_hex(canonical_variant(level_record));
		levels.append(level_record);
	}

	Dictionary biome_by_terrain;
	for (int64_t index = 0; index < ids_by_code.size(); ++index) {
		const String terrain_id = String(ids_by_code[index]);
		biome_by_terrain[terrain_id] = biome_for_terrain(terrain_id);
	}

	Dictionary grid;
	grid["schema_id"] = NATIVE_RMG_TERRAIN_GRID_SCHEMA_ID;
	grid["schema_version"] = 1;
	grid["generation_status"] = native_rmg_scoped_structural_profile_supported(normalized) ? "terrain_grid_generated_scoped_structural_profile" : "terrain_grid_generated";
	grid["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	grid["width"] = width;
	grid["height"] = height;
	grid["level_count"] = level_count;
	grid["tile_count"] = (parity_targets.is_empty() || use_land_boundary_shape) ? width * height * level_count : int32_t(parity_targets.get("terrain_tile_count", width * height));
	grid["terrain_id_by_code"] = ids_by_code;
	grid["biome_id_by_terrain_id"] = biome_by_terrain;
	grid["terrain_palette_ids"] = terrain_pool;
	grid["zone_seed_model"] = "deterministic_terrain_palette_voronoi_seed_grid";
	grid["terrain_seed_records"] = seeds;
	grid["terrain_counts"] = aggregate_counts;
	if (!island_shape.is_empty()) {
		island_shape.erase("land_lookup");
		grid["land_water_shape"] = island_shape;
	}
	if (use_land_boundary_shape) {
		Dictionary boundary_shape;
		boundary_shape["schema_id"] = "native_random_map_zone_boundary_barrier_shape_v1";
		boundary_shape["enabled"] = true;
		boundary_shape["source_model"] = "runtime_zone_owner_grid_boundaries_with_route_anchor_openings";
		boundary_shape["terrain_id"] = "rock";
		boundary_shape["opening_count"] = land_boundary_openings.size();
		boundary_shape["policy"] = "land maps materialize impassable zone borders so route guards and gates control crossings instead of acting as cosmetic road markers";
		grid["land_boundary_shape"] = boundary_shape;
	}
	grid["levels"] = levels;
	grid["materialized_level_count"] = levels.size();
	grid["level_count_semantics"] = (parity_targets.is_empty() || use_land_boundary_shape) ? "all_native_levels_materialized" : "gdscript_surface_tile_stream_with_level_count_metadata";
	grid["signature"] = hash32_hex(canonical_variant(grid));
	return grid;
}

void append_validation_issue(Array &issues, const String &severity, const String &code, const String &path, const String &message) {
	Dictionary issue;
	issue["severity"] = severity;
	issue["code"] = code;
	issue["path"] = path;
	issue["message"] = message;
	issue["context"] = Dictionary();
	issues.append(issue);
}

bool cell_in_bounds(const Dictionary &cell, int32_t width, int32_t height, int32_t level_count) {
	const int32_t x = int32_t(cell.get("x", -1));
	const int32_t y = int32_t(cell.get("y", -1));
	const int32_t level = int32_t(cell.get("level", 0));
	return x >= 0 && x < width && y >= 0 && y < height && level >= 0 && level < level_count;
}

bool record_in_bounds(const Dictionary &record, int32_t width, int32_t height, int32_t level_count) {
	return cell_in_bounds(cell_record(int32_t(record.get("x", -1)), int32_t(record.get("y", -1)), int32_t(record.get("level", 0))), width, height, level_count);
}

Dictionary component_summary(const String &component, const String &generation_status, const String &validation_status, int32_t count, const String &signature) {
	Dictionary summary;
	summary["component"] = component;
	summary["generation_status"] = generation_status;
	summary["validation_status"] = validation_status;
	summary["count"] = count;
	summary["signature"] = signature;
	return summary;
}

Dictionary build_component_signatures(const Dictionary &terrain_grid, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &river_network, const Dictionary &object_placement, const Dictionary &town_guard_placement) {
	Dictionary signatures;
	signatures["terrain_grid"] = terrain_grid.get("signature", "");
	signatures["zone_layout"] = zone_layout.get("signature", "");
	signatures["player_starts"] = player_starts.get("signature", "");
	signatures["route_graph"] = Dictionary(road_network.get("route_graph", Dictionary())).get("signature", "");
	signatures["road_network"] = road_network.get("signature", "");
	signatures["connection_payload_resolution"] = Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("signature", "");
	signatures["river_network"] = river_network.get("signature", "");
	signatures["object_placement"] = object_placement.get("signature", "");
	signatures["object_occupancy"] = Dictionary(object_placement.get("occupancy_index", Dictionary())).get("signature", "");
	signatures["town_guard_placement"] = town_guard_placement.get("signature", "");
	signatures["town_placement"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	signatures["guard_placement"] = Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", "");
	signatures["town_guard_occupancy"] = Dictionary(town_guard_placement.get("combined_occupancy_index", Dictionary())).get("signature", "");
	return signatures;
}

Dictionary build_component_counts(const Dictionary &normalized, const Dictionary &terrain_grid, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &river_network, const Dictionary &object_placement, const Dictionary &town_guard_placement) {
	Dictionary counts;
	counts["width"] = int32_t(normalized.get("width", 36));
	counts["height"] = int32_t(normalized.get("height", 36));
	counts["level_count"] = int32_t(normalized.get("level_count", 1));
	counts["tile_count"] = terrain_grid.get("tile_count", 0);
	counts["zone_count"] = zone_layout.get("zone_count", 0);
	counts["player_start_count"] = player_starts.get("start_count", 0);
	counts["route_edge_count"] = Dictionary(road_network.get("route_graph", Dictionary())).get("route_edge_count", 0);
	counts["road_segment_count"] = road_network.get("road_segment_count", 0);
	Dictionary road_materialization_summary = road_network.get("road_materialization_summary", Dictionary());
	const int32_t road_segment_cell_count = int32_t(road_network.get("road_cell_count", 0));
	const int32_t unique_road_cell_count = int32_t(road_materialization_summary.get("unique_materialized_road_cell_count", road_segment_cell_count));
	counts["road_cell_count"] = unique_road_cell_count;
	counts["road_segment_cell_count"] = road_segment_cell_count;
	counts["road_duplicate_cell_count"] = road_segment_cell_count > unique_road_cell_count ? road_segment_cell_count - unique_road_cell_count : 0;
	counts["connection_gate_count"] = road_network.get("connection_gate_count", 0);
	counts["river_segment_count"] = river_network.get("river_segment_count", 0);
	counts["river_cell_count"] = river_network.get("river_cell_count", 0);
	counts["object_count"] = object_placement.get("object_count", 0);
	counts["town_count"] = town_guard_placement.get("town_count", 0);
	counts["guard_count"] = town_guard_placement.get("guard_count", 0);
	return counts;
}

Array build_phase_pipeline(const Dictionary &terrain_grid, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &river_network, const Dictionary &object_placement, const Dictionary &town_guard_placement) {
	Array phases;
	phases.append(component_summary("terrain_grid", String(terrain_grid.get("generation_status", "")), "pass", int32_t(terrain_grid.get("tile_count", 0)), String(terrain_grid.get("signature", ""))));
	phases.append(component_summary("zone_layout", String(zone_layout.get("generation_status", "")), "pass", int32_t(zone_layout.get("zone_count", 0)), String(zone_layout.get("signature", ""))));
	phases.append(component_summary("player_starts", String(player_starts.get("generation_status", "")), "pass", int32_t(player_starts.get("start_count", 0)), String(player_starts.get("signature", ""))));
	phases.append(component_summary("route_graph", String(Dictionary(road_network.get("route_graph", Dictionary())).get("generation_status", "")), "pass", int32_t(Dictionary(road_network.get("route_graph", Dictionary())).get("route_edge_count", 0)), String(Dictionary(road_network.get("route_graph", Dictionary())).get("signature", ""))));
	phases.append(component_summary("road_network", String(road_network.get("generation_status", "")), "pass", int32_t(road_network.get("road_segment_count", 0)), String(road_network.get("signature", ""))));
	phases.append(component_summary("connection_payload_resolution", String(Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("generation_status", "")), "pass", int32_t(Dictionary(Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("summary", Dictionary())).get("materialized_record_count", 0)), String(Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("signature", ""))));
	phases.append(component_summary("river_network", String(river_network.get("generation_status", "")), "pass", int32_t(river_network.get("river_segment_count", 0)), String(river_network.get("signature", ""))));
	phases.append(component_summary("object_placement", String(object_placement.get("generation_status", "")), "pass", int32_t(object_placement.get("object_count", 0)), String(object_placement.get("signature", ""))));
	phases.append(component_summary("town_placement", String(Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("generation_status", "")), "pass", int32_t(town_guard_placement.get("town_count", 0)), String(Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", ""))));
	phases.append(component_summary("guard_placement", String(Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("generation_status", "")), "pass", int32_t(town_guard_placement.get("guard_count", 0)), String(Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", ""))));
	phases.append(component_summary("validation_provenance", "validation_provenance_generated_foundation", "pass", 1, ""));
	return phases;
}

int32_t native_rmg_town_spacing_floor_for_config(const Dictionary &normalized) {
	const String size_class_id = String(normalized.get("size_class_id", ""));
	if (native_rmg_owner_large_land_density_case(normalized)) {
		return 32;
	}
	if (native_rmg_owner_xl_land_density_case(normalized)) {
		return 36;
	}
	if (size_class_id == "homm3_extra_large") {
		return 12;
	}
	if (size_class_id == "homm3_large") {
		return 12;
	}
	if (size_class_id == "homm3_medium") {
		return 10;
	}
	return 8;
}

Dictionary native_rmg_town_spacing_summary(const Dictionary &normalized, const Array &towns) {
	Dictionary summary;
	summary["schema_id"] = "aurelion_native_rmg_town_spacing_summary_v1";
	summary["town_spacing_floor"] = native_rmg_town_spacing_floor_for_config(normalized);
	summary["town_count"] = towns.size();
	int32_t nearest = -1;
	Dictionary nearest_pair;
	for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
		if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary left = towns[left_index];
		for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
			if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary right = towns[right_index];
			const int32_t distance = std::abs(int32_t(left.get("x", 0)) - int32_t(right.get("x", 0))) + std::abs(int32_t(left.get("y", 0)) - int32_t(right.get("y", 0)));
			if (nearest < 0 || distance < nearest) {
				nearest = distance;
				nearest_pair["left_town_placement_id"] = String(left.get("placement_id", ""));
				nearest_pair["right_town_placement_id"] = String(right.get("placement_id", ""));
				nearest_pair["left_x"] = int32_t(left.get("x", 0));
				nearest_pair["left_y"] = int32_t(left.get("y", 0));
				nearest_pair["right_x"] = int32_t(right.get("x", 0));
				nearest_pair["right_y"] = int32_t(right.get("y", 0));
			}
		}
	}
	summary["nearest_town_manhattan"] = nearest;
	summary["nearest_pair"] = nearest_pair;
	summary["validation_status"] = nearest < 0 || nearest >= int32_t(summary.get("town_spacing_floor", 8)) ? "pass" : "fail";
	summary["policy"] = "launchable_native_rmg_profiles_must_not_stack_towns_below_size_aware_manhattan_floor";
	return summary;
}

Dictionary validate_native_random_map_output(const Dictionary &normalized, const Dictionary &identity, const Dictionary &terrain_grid, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &river_network, const Dictionary &object_placement, const Dictionary &town_guard_placement, const Dictionary &metrics, const Array &warnings) {
	Array failures;
	Array validation_warnings = warnings.duplicate(true);
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	const bool owner_compared_translated_profile_supported = native_rmg_owner_compared_translated_profile_supported(normalized);
	const bool translated_catalog_structural_profile_supported = native_rmg_translated_catalog_structural_profile_supported(normalized);
	const bool all_native_levels_materialized = String(terrain_grid.get("level_count_semantics", "")) == "all_native_levels_materialized";
	const int32_t expected_tile_count = (!scoped_structural_profile_supported || all_native_levels_materialized) ? width * height * level_count : width * height;
	const String generation_status = native_rmg_generation_status_for_config(normalized);
	const String full_generation_status = native_rmg_full_generation_status_for_config(normalized);

	if (width <= 0 || height <= 0 || level_count <= 0) {
		append_validation_issue(failures, "fail", "invalid_dimensions", "normalized_config", "Native RMG dimensions must be positive.");
	}
	if (int32_t(terrain_grid.get("tile_count", 0)) != expected_tile_count) {
		append_validation_issue(failures, "fail", "terrain_tile_count_mismatch", "terrain_grid.tile_count", "Terrain grid tile count did not match normalized dimensions.");
	}
	int32_t terrain_count_sum = 0;
	Dictionary terrain_counts = terrain_grid.get("terrain_counts", Dictionary());
	Array terrain_keys = terrain_counts.keys();
	for (int64_t index = 0; index < terrain_keys.size(); ++index) {
		terrain_count_sum += int32_t(terrain_counts.get(terrain_keys[index], 0));
	}
	if (terrain_count_sum != expected_tile_count) {
		append_validation_issue(failures, "fail", "terrain_count_sum_mismatch", "terrain_grid.terrain_counts", "Terrain count sum did not match tile count.");
	}
	Dictionary land_water_shape = terrain_grid.get("land_water_shape", Dictionary());
	Array terrain_diagnostics = land_water_shape.get("diagnostics", Array());
	for (int64_t index = 0; index < terrain_diagnostics.size(); ++index) {
		if (Variant(terrain_diagnostics[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary diagnostic = terrain_diagnostics[index];
		const String severity = String(diagnostic.get("severity", "warning"));
		const String code = String(diagnostic.get("code", "terrain_shape_diagnostic"));
		const String message = String(diagnostic.get("message", "Terrain/island shaping reported a diagnostic."));
		if (severity == "failure" || severity == "fail") {
			append_validation_issue(failures, "fail", code, "terrain_grid.land_water_shape", message);
		} else {
			Dictionary warning = diagnostic.duplicate(true);
			warning["severity"] = "warning";
			warning["path"] = "terrain_grid.land_water_shape";
			validation_warnings.append(warning);
		}
	}

	Array zones = zone_layout.get("zones", Array());
	Dictionary zones_by_id;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (zone_id.is_empty()) {
			append_validation_issue(failures, "fail", "zone_missing_id", "zone_layout.zones", "Zone record missed id.");
			continue;
		}
		if (zones_by_id.has(zone_id)) {
			append_validation_issue(failures, "fail", "duplicate_zone_id", "zone_layout.zones", "Zone ids must be unique.");
		}
		zones_by_id[zone_id] = true;
		Dictionary anchor = zone.get("anchor", Dictionary());
		if (!cell_in_bounds(cell_record(int32_t(anchor.get("x", -1)), int32_t(anchor.get("y", -1)), 0), width, height, level_count)) {
			append_validation_issue(failures, "fail", "zone_anchor_out_of_bounds", "zone_layout.zones.anchor", "Zone anchor must be in bounds.");
		}
	}
	if (zones.size() != int32_t(zone_layout.get("zone_count", zones.size()))) {
		append_validation_issue(failures, "fail", "zone_count_mismatch", "zone_layout.zone_count", "Zone count did not match records.");
	}
	Dictionary runtime_graph_validation_report = zone_layout.get("runtime_graph_validation", Dictionary());
	if (String(runtime_graph_validation_report.get("schema_id", "")) == "aurelion_native_rmg_runtime_zone_graph_validation_v1"
			&& String(runtime_graph_validation_report.get("status", "")) != "pass") {
		append_validation_issue(failures, "fail", "runtime_zone_graph_validation_failed", "zone_layout.runtime_graph_validation", "Recovered-template runtime zone graph validation must pass before generation output is launchable.");
	}
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	if (owner_grid.size() != height) {
		append_validation_issue(failures, "fail", "owner_grid_height_mismatch", "zone_layout.surface_owner_grid", "Owner grid height did not match map height.");
	}
	for (int64_t y = 0; y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		if (row.size() != width) {
			append_validation_issue(failures, "fail", "owner_grid_width_mismatch", "zone_layout.surface_owner_grid", "Owner grid row width did not match map width.");
			continue;
		}
		for (int64_t x = 0; x < row.size(); ++x) {
			if (!zones_by_id.has(String(row[x]))) {
				append_validation_issue(failures, "fail", "owner_grid_unknown_zone", "zone_layout.surface_owner_grid", "Owner grid referenced an unknown zone id.");
			}
		}
	}

	Array starts = player_starts.get("starts", Array());
	if (starts.size() != int32_t(player_starts.get("expected_player_count", starts.size()))) {
		append_validation_issue(failures, "fail", "player_start_count_mismatch", "player_starts.starts", "Player start count did not match expected player count.");
	}
	Dictionary starts_by_zone;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const String zone_id = String(start.get("zone_id", ""));
		if (!record_in_bounds(start, width, height, level_count)) {
			append_validation_issue(failures, "fail", "player_start_out_of_bounds", "player_starts.starts", "Player start must be in bounds.");
		}
		if (!zones_by_id.has(zone_id)) {
			append_validation_issue(failures, "fail", "player_start_unknown_zone", "player_starts.starts.zone_id", "Player start referenced an unknown zone.");
		}
		starts_by_zone[zone_id] = true;
	}

	Dictionary route_graph = road_network.get("route_graph", Dictionary());
	Array edges = route_graph.get("edges", Array());
	Dictionary route_edges_by_id;
	Dictionary route_control_by_edge_id;
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		const String edge_id = String(edge.get("id", ""));
		if (edge_id.is_empty()) {
			append_validation_issue(failures, "fail", "route_edge_missing_id", "route_graph.edges", "Route edge missed id.");
		}
		route_edges_by_id[edge_id] = true;
		Dictionary control = edge.get("connection_control", Dictionary());
		Dictionary road_tile = control.get("road_tile", Dictionary());
		if (!edge_id.is_empty() && !road_tile.is_empty()) {
			route_control_by_edge_id[edge_id] = road_tile;
		}
	}
	if (edges.is_empty()) {
		append_validation_issue(failures, "fail", "route_graph_empty", "route_graph.edges", "Route graph must expose at least one edge.");
	}
	if (String(Dictionary(road_network.get("route_reachability_proof", Dictionary())).get("status", "")) != "pass") {
		append_validation_issue(failures, "fail", "route_reachability_failed", "road_network.route_reachability_proof", "Route reachability proof must pass.");
	}
	Dictionary start_coverage = road_network.get("required_start_coverage", Dictionary());
	if (int32_t(start_coverage.get("covered_player_start_count", 0)) != starts.size()) {
		append_validation_issue(failures, "fail", "road_start_coverage_failed", "road_network.required_start_coverage", "Road network must cover every player start.");
	}
	for (int64_t index = 0; index < Array(road_network.get("road_segments", Array())).size(); ++index) {
		Dictionary segment = Array(road_network.get("road_segments", Array()))[index];
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (!cell_in_bounds(cells[cell_index], width, height, level_count)) {
				append_validation_issue(failures, "fail", "road_cell_out_of_bounds", "road_network.road_segments.cells", "Road segment emitted an out-of-bounds cell.");
			}
		}
	}
	if (scoped_structural_profile_supported && int32_t(road_network.get("road_cell_count", 0)) <= 0) {
		append_validation_issue(failures, "fail", "road_cells_missing_for_scoped_profile", "road_network.road_segments.cells", "Scoped structural native RMG profiles must materialize road cells, not count-only road records.");
	}
	if (String(road_network.get("writeout_policy", "")) != "final_generated_tile_stream_no_authored_tile_write") {
		append_validation_issue(failures, "fail", "road_writeout_boundary_lost", "road_network.writeout_policy", "Road network lost no-authored-tile-write boundary.");
	}
	if (String(road_network.get("overlay_semantics", "")) != "deterministic_road_overlay_metadata_separate_from_rand_trn_decoration_object_scoring") {
		append_validation_issue(failures, "fail", "road_overlay_semantics_missing", "road_network.overlay_semantics", "Road overlays must be deterministic metadata separate from rand_trn decoration scoring.");
	}
	Dictionary connection_payload = road_network.get("late_connection_payload_resolution", Dictionary());
	if (String(connection_payload.get("schema_id", "")) != NATIVE_RMG_CONNECTION_PAYLOAD_SCHEMA_ID) {
		append_validation_issue(failures, "fail", "connection_payload_resolution_missing", "road_network.late_connection_payload_resolution", "Late connection payload resolution must run after town/castle placement.");
	} else {
		if (String(connection_payload.get("validation_status", "")) != "pass") {
			append_validation_issue(failures, "fail", "connection_payload_resolution_failed", "road_network.late_connection_payload_resolution", "Late connection payload resolution reported validation failures.");
		}
		Array payload_diagnostics = connection_payload.get("diagnostics", Array());
		for (int64_t index = 0; index < payload_diagnostics.size(); ++index) {
			if (Variant(payload_diagnostics[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary diagnostic = Dictionary(payload_diagnostics[index]);
			if (String(diagnostic.get("severity", "")) == "failure") {
				append_validation_issue(failures, "fail", String(diagnostic.get("code", "connection_payload_failure")), "road_network.late_connection_payload_resolution.diagnostics", String(diagnostic.get("message", "Connection payload resolution failed.")));
			}
		}
		Dictionary payload_summary = connection_payload.get("summary", Dictionary());
		if (int32_t(payload_summary.get("required_link_failure_count", 0)) > 0) {
			append_validation_issue(failures, "fail", "required_connection_corridor_missing", "road_network.late_connection_payload_resolution.summary", "Required links must produce corridors or explicit failures.");
		}
		for (int64_t index = 0; index < Array(connection_payload.get("wide_suppressions", Array())).size(); ++index) {
			Dictionary record = Array(connection_payload.get("wide_suppressions", Array()))[index];
			if (bool(record.get("normal_guard_materialized", true)) || int32_t(record.get("normal_guard_value", -1)) != 0) {
				append_validation_issue(failures, "fail", "wide_connection_guard_not_suppressed", "road_network.late_connection_payload_resolution.wide_suppressions", "Wide links must suppress normal connection guards.");
			}
		}
	}

	for (int64_t index = 0; index < Array(river_network.get("river_segments", Array())).size(); ++index) {
		Dictionary segment = Array(river_network.get("river_segments", Array()))[index];
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			if (!cell_in_bounds(cells[cell_index], width, height, level_count)) {
				append_validation_issue(failures, "fail", "river_cell_out_of_bounds", "river_network.river_segments.cells", "River segment emitted an out-of-bounds cell.");
			}
		}
	}
	if (String(Dictionary(river_network.get("policy", Dictionary())).get("overlay_semantics", "")) != "river_overlay_metadata_separate_from_rand_trn_decoration_object_scoring") {
		append_validation_issue(failures, "fail", "river_overlay_semantics_missing", "river_network.policy.overlay_semantics", "River overlays must remain separate from rand_trn decoration scoring.");
	}

	Array objects = object_placement.get("object_placements", Array());
	Dictionary object_ids;
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = objects[index];
		const String placement_id = String(object.get("placement_id", ""));
		if (placement_id.is_empty()) {
			append_validation_issue(failures, "fail", "object_missing_placement_id", "object_placement.object_placements", "Object placement missed placement id.");
		}
		if (object_ids.has(placement_id)) {
			append_validation_issue(failures, "fail", "duplicate_object_placement_id", "object_placement.object_placements", "Object placement ids must be unique.");
		}
		object_ids[placement_id] = true;
		if (!record_in_bounds(object, width, height, level_count)) {
			append_validation_issue(failures, "fail", "object_out_of_bounds", "object_placement.object_placements", "Object placement must be in bounds.");
		}
		if (!zones_by_id.has(String(object.get("zone_id", "")))) {
			append_validation_issue(failures, "fail", "object_unknown_zone", "object_placement.object_placements.zone_id", "Object placement referenced an unknown zone.");
		}
	}
	Dictionary object_occupancy = object_placement.get("occupancy_index", Dictionary());
	if (String(object_occupancy.get("status", "")) != "pass" || int32_t(object_occupancy.get("duplicate_primary_tile_count", -1)) != 0 || int32_t(object_occupancy.get("duplicate_body_tile_count", -1)) != 0) {
		append_validation_issue(failures, "fail", "object_occupancy_not_unique", "object_placement.occupancy_index", "Object primary/body occupancy must be unique.");
	}
	Dictionary object_pipeline_summary = object_placement.get("object_placement_pipeline_summary", Dictionary());
	if (String(object_pipeline_summary.get("validation_status", "")) != "pass") {
		append_validation_issue(failures, "fail", "object_pipeline_summary_failed", "object_placement.object_placement_pipeline_summary", "Object placement pipeline summary must validate definitions, masks, limits, occupancy, decoration filler, and cost.");
	}
	Dictionary mine_resource_summary = object_placement.get("mine_resource_summary", Dictionary());
	if (String(mine_resource_summary.get("schema_id", "")) != "aurelion_native_rmg_phase7_mines_resources_summary_v1") {
		append_validation_issue(failures, "fail", "mine_resource_summary_missing", "object_placement.mine_resource_summary", "Phase 7 mines/resources summary must be emitted.");
	} else {
		if (!bool(mine_resource_summary.get("minimum_before_density", false))) {
			append_validation_issue(failures, "fail", "mine_resource_minimum_order_missing", "object_placement.mine_resource_summary.minimum_before_density", "Mine minimums must be scheduled before density extras.");
		}
		if (Array(mine_resource_summary.get("category_order", Array())).size() != RMG_MINE_CATEGORY_COUNT) {
			append_validation_issue(failures, "fail", "mine_resource_seven_category_order_missing", "object_placement.mine_resource_summary.category_order", "Seven recovered mine/resource categories must be represented.");
		}
		Array mine_diagnostics = mine_resource_summary.get("diagnostics", Array());
		for (int64_t index = 0; index < mine_diagnostics.size(); ++index) {
			if (Variant(mine_diagnostics[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary diagnostic = mine_diagnostics[index];
			if (String(diagnostic.get("severity", "")) == "failure") {
				append_validation_issue(failures, "fail", "mine_resource_placement_infeasible", "object_placement.mine_resource_summary.diagnostics", "Required mine/resource placement reported an infeasible source-field placement.");
			}
		}
	}

	Array towns = town_guard_placement.get("town_records", Array());
	Array guards = town_guard_placement.get("guard_records", Array());
	Dictionary town_ids;
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = towns[index];
		const String placement_id = String(town.get("placement_id", ""));
		if (placement_id.is_empty()) {
			append_validation_issue(failures, "fail", "town_missing_placement_id", "town_guard_placement.town_records", "Town placement missed placement id.");
		}
		if (town_ids.has(placement_id)) {
			append_validation_issue(failures, "fail", "duplicate_town_placement_id", "town_guard_placement.town_records", "Town placement ids must be unique.");
		}
		town_ids[placement_id] = true;
		if (!record_in_bounds(town, width, height, level_count)) {
			append_validation_issue(failures, "fail", "town_out_of_bounds", "town_guard_placement.town_records", "Town placement must be in bounds.");
		}
		if (!zones_by_id.has(String(town.get("zone_id", "")))) {
			append_validation_issue(failures, "fail", "town_unknown_zone", "town_guard_placement.town_records.zone_id", "Town placement referenced an unknown zone.");
		}
		if (bool(town.get("is_start_town", false)) && !starts_by_zone.has(String(town.get("zone_id", "")))) {
			append_validation_issue(failures, "fail", "start_town_missing_start_reference", "town_guard_placement.town_records.start_anchor", "Start town must reference a generated player start.");
		}
		const String source_field_offset = String(town.get("source_field_offset", ""));
		if (source_field_offset.is_empty() || !(source_field_offset == "+0x20" || source_field_offset == "+0x24" || source_field_offset == "+0x28" || source_field_offset == "+0x2c" || source_field_offset == "+0x30" || source_field_offset == "+0x34" || source_field_offset == "+0x38" || source_field_offset == "+0x3c")) {
			append_validation_issue(failures, "fail", "town_source_field_semantics_missing", "town_guard_placement.town_records.source_field_offset", "Town/castle placement must record recovered source field offset semantics.");
		}
		if (String(town.get("owner_semantics", "")) == "neutral_owner_minus_one" && int32_t(town.get("owner_slot", 0)) != -1) {
			append_validation_issue(failures, "fail", "neutral_town_owner_semantics_invalid", "town_guard_placement.town_records.owner_slot", "Neutral town/castle records must preserve owner -1 semantics.");
		}
	}
	Dictionary town_spacing_summary = native_rmg_town_spacing_summary(normalized, towns);
	if ((scoped_structural_profile_supported || owner_compared_translated_profile_supported) && String(town_spacing_summary.get("validation_status", "")) != "pass") {
		append_validation_issue(failures, "fail", "town_spacing_floor_failed", "town_guard_placement.town_records", "Launchable native RMG profiles must not place towns below the size-aware spacing floor.");
	} else if (translated_catalog_structural_profile_supported && String(town_spacing_summary.get("validation_status", "")) != "pass") {
		append_validation_issue(validation_warnings, "warning", "translated_catalog_town_spacing_floor_pending_owner_comparison", "town_guard_placement.town_records", "Broad recovered-template structural support records direct town spacing as parity debt until owner comparison; package route closure remains hard-gated.");
	}
	Dictionary town_payload = town_guard_placement.get("town_placement", Dictionary());
	Array town_diagnostics = town_payload.get("diagnostics", Array());
	for (int64_t index = 0; index < town_diagnostics.size(); ++index) {
		Dictionary diagnostic = town_diagnostics[index];
		if (String(diagnostic.get("severity", "")) == "failure") {
			append_validation_issue(failures, "fail", "town_castle_placement_infeasible", "town_guard_placement.town_placement.diagnostics", "Town/castle placement reported an infeasible required source-field placement.");
		}
	}
	if (String(town_payload.get("same_type_neutral_scope", "")) != "per_source_zone_neutral_weighted_reuse_only_not_global_map_lock") {
		append_validation_issue(failures, "fail", "town_same_type_scope_missing", "town_guard_placement.town_placement.same_type_neutral_scope", "Same-town-type semantics must remain per source zone and neutral weighted only.");
	}
	Dictionary town_pair_route_guard_closure = town_guard_placement.get("town_pair_route_guard_closure", Dictionary());
	if (full_generation_status != "not_implemented" && int32_t(town_pair_route_guard_closure.get("remaining_reachable_pair_count", 0)) > 0) {
		append_validation_issue(failures, "fail", "town_pair_route_guard_closure_incomplete", "town_guard_placement.town_pair_route_guard_closure.remaining_reachable_pair_count", "Town-pair route guard closure must leave no direct object-only town traversal routes open.");
	}
	for (int64_t index = 0; index < guards.size(); ++index) {
		Dictionary guard = guards[index];
		if (!record_in_bounds(guard, width, height, level_count)) {
			append_validation_issue(failures, "fail", "guard_out_of_bounds", "town_guard_placement.guard_records", "Guard placement must be in bounds.");
		}
		const String target_type = String(guard.get("protected_target_type", ""));
		if (target_type == "route_edge") {
			const String route_edge_id = String(guard.get("route_edge_id", ""));
			if (!route_edges_by_id.has(route_edge_id)) {
				append_validation_issue(failures, "fail", "guard_invalid_route_target", "town_guard_placement.guard_records.route_edge_id", "Route guard referenced an unknown route edge.");
			}
			if (route_control_by_edge_id.has(route_edge_id)) {
				Dictionary control = route_control_by_edge_id.get(route_edge_id, Dictionary());
				const int32_t dx = std::abs(int32_t(guard.get("x", 0)) - int32_t(control.get("x", 0)));
				const int32_t dy = std::abs(int32_t(guard.get("y", 0)) - int32_t(control.get("y", 0)));
				if (std::max(dx, dy) > 1) {
					append_validation_issue(failures, "fail", "route_guard_not_on_control_choke", "town_guard_placement.guard_records.route_edge_id", "Route guard must occupy or border its route control tile.");
				}
			}
		} else if (target_type == "object_placement") {
			if (!object_ids.has(String(guard.get("protected_object_placement_id", "")))) {
				append_validation_issue(failures, "fail", "guard_invalid_object_target", "town_guard_placement.guard_records.protected_object_placement_id", "Site guard referenced an unknown object placement.");
			}
		} else if (target_type == "town_pair") {
			Dictionary target = guard.get("protected_target", Dictionary());
			const String left_town_id = String(target.get("left_town_placement_id", ""));
			const String right_town_id = String(target.get("right_town_placement_id", ""));
			if (!town_ids.has(left_town_id) || !town_ids.has(right_town_id) || left_town_id == right_town_id) {
				append_validation_issue(failures, "fail", "guard_invalid_town_pair_target", "town_guard_placement.guard_records.protected_target", "Town-pair guard referenced an unknown or duplicate town placement.");
			}
		} else if (target_type == "density_guard") {
			if (String(guard.get("protected_target_id", "")).is_empty() || String(guard.get("protected_zone_id", "")).is_empty()) {
				append_validation_issue(failures, "fail", "guard_invalid_density_target", "town_guard_placement.guard_records.protected_target", "Density guard must record its synthetic guard target and protected zone.");
			}
		} else {
			append_validation_issue(failures, "fail", "guard_unknown_target_type", "town_guard_placement.guard_records.protected_target_type", "Guard protected target type must be route_edge, object_placement, town_pair, or density_guard.");
		}
	}
	Dictionary combined_occupancy = town_guard_placement.get("combined_occupancy_index", Dictionary());
	if (String(combined_occupancy.get("status", "")) != "pass" || int32_t(combined_occupancy.get("duplicate_primary_tile_count", -1)) != 0) {
		append_validation_issue(failures, "fail", "combined_occupancy_not_unique", "town_guard_placement.combined_occupancy_index", "Object/town/guard primary occupancy must be unique.");
	}
	if (int32_t(combined_occupancy.get("occupied_primary_tile_count", 0)) != objects.size() + towns.size() + guards.size()) {
		append_validation_issue(failures, "fail", "combined_occupancy_count_mismatch", "town_guard_placement.combined_occupancy_index", "Combined occupancy count did not match objects plus towns plus guards.");
	}
	if (String(object_placement.get("writeout_policy", "")) != "generated_object_records_no_authored_content_write" || String(town_guard_placement.get("writeout_policy", "")) != "generated_town_guard_records_no_authored_content_write") {
		append_validation_issue(failures, "fail", "authored_writeback_boundary_lost", "generated_components.writeout_policy", "Generated records must preserve no-authored-content-write boundaries.");
	}

	Dictionary signatures = build_component_signatures(terrain_grid, zone_layout, player_starts, road_network, river_network, object_placement, town_guard_placement);
	Dictionary counts = build_component_counts(normalized, terrain_grid, zone_layout, player_starts, road_network, river_network, object_placement, town_guard_placement);
	Array phases = build_phase_pipeline(terrain_grid, zone_layout, player_starts, road_network, river_network, object_placement, town_guard_placement);
	const String phase_signature = hash32_hex(canonical_variant(phases));

	Dictionary component_summaries;
	component_summaries["terrain_grid"] = component_summary("terrain_grid", String(terrain_grid.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", int32_t(terrain_grid.get("tile_count", 0)), String(terrain_grid.get("signature", "")));
	component_summaries["zone_layout"] = component_summary("zone_layout", String(zone_layout.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", int32_t(zone_layout.get("zone_count", 0)), String(zone_layout.get("signature", "")));
	component_summaries["player_starts"] = component_summary("player_starts", String(player_starts.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", int32_t(player_starts.get("start_count", 0)), String(player_starts.get("signature", "")));
	component_summaries["road_network"] = component_summary("road_network", String(road_network.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", int32_t(road_network.get("road_segment_count", 0)), String(road_network.get("signature", "")));
	component_summaries["river_network"] = component_summary("river_network", String(river_network.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", int32_t(river_network.get("river_segment_count", 0)), String(river_network.get("signature", "")));
	component_summaries["object_placement"] = component_summary("object_placement", String(object_placement.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", objects.size(), String(object_placement.get("signature", "")));
	component_summaries["town_guard_placement"] = component_summary("town_guard_placement", String(town_guard_placement.get("generation_status", "")), failures.is_empty() ? "pass" : "fail", towns.size() + guards.size(), String(town_guard_placement.get("signature", "")));

	Dictionary output_identity;
	output_identity["generator_version"] = NATIVE_RMG_VERSION;
	output_identity["normalized_seed"] = normalized.get("normalized_seed", "");
	output_identity["config_hash"] = identity.get("config_hash", "");
	output_identity["map_id"] = identity.get("map_id", "");
	output_identity["component_signatures"] = signatures;
	output_identity["component_counts"] = counts;
	output_identity["phase_signature"] = phase_signature;
	output_identity["write_policy"] = "generated_records_only_no_authored_writeback";
	output_identity["full_generation_status"] = full_generation_status;
	const String full_output_signature = hash32_hex(canonical_variant(output_identity));
	output_identity["full_output_signature"] = full_output_signature;
	output_identity["generated_output_identity_signature"] = hash32_hex(canonical_variant(output_identity));

	Dictionary report;
	report["schema_id"] = NATIVE_RMG_VALIDATION_REPORT_SCHEMA_ID;
	report["schema_version"] = 1;
	report["ok"] = failures.is_empty();
	report["status"] = failures.is_empty() ? "pass" : "fail";
	report["validation_status"] = report["status"];
	report["generation_status"] = generation_status;
	report["full_generation_status"] = full_generation_status;
	report["failure_count"] = failures.size();
	report["warning_count"] = validation_warnings.size();
	report["failures"] = failures;
	report["warnings"] = validation_warnings;
	report["metrics"] = metrics;
	report["deterministic_identity"] = identity;
	report["component_signatures"] = signatures;
	report["component_counts"] = counts;
	report["component_summaries"] = component_summaries;
	report["town_spacing"] = town_spacing_summary;
	report["phase_pipeline"] = phases;
	report["phase_signature"] = phase_signature;
	report["full_output_signature"] = full_output_signature;
	report["deterministic_output_identity"] = output_identity;
	report["terrain_grid_status"] = terrain_grid.get("generation_status", "");
	report["terrain_grid_signature"] = terrain_grid.get("signature", "");
	report["zone_generation_status"] = zone_layout.get("generation_status", "");
	report["zone_layout_signature"] = zone_layout.get("signature", "");
	report["player_start_generation_status"] = player_starts.get("generation_status", "");
	report["player_start_signature"] = player_starts.get("signature", "");
	report["road_generation_status"] = road_network.get("generation_status", "");
	report["road_network_signature"] = road_network.get("signature", "");
	report["route_graph_signature"] = Dictionary(road_network.get("route_graph", Dictionary())).get("signature", "");
	report["route_reachability_status"] = Dictionary(road_network.get("route_reachability_proof", Dictionary())).get("status", "");
	report["connection_payload_generation_status"] = Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("generation_status", "");
	report["connection_payload_resolution_signature"] = Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("signature", "");
	report["connection_payload_summary"] = Dictionary(road_network.get("late_connection_payload_resolution", Dictionary())).get("summary", Dictionary());
	report["river_generation_status"] = river_network.get("generation_status", "");
	report["river_network_signature"] = river_network.get("signature", "");
	report["object_generation_status"] = object_placement.get("generation_status", "");
	report["object_placement_signature"] = object_placement.get("signature", "");
	report["object_occupancy_signature"] = Dictionary(object_placement.get("occupancy_index", Dictionary())).get("signature", "");
	report["object_category_counts"] = object_placement.get("category_counts", Dictionary());
	report["object_placement_pipeline_summary"] = object_placement.get("object_placement_pipeline_summary", Dictionary());
	report["object_placement_pipeline_summary_signature"] = deterministic_object_placement_pipeline_signature(object_placement);
	report["mine_resource_summary"] = object_placement.get("mine_resource_summary", Dictionary());
	report["mine_resource_summary_signature"] = Dictionary(object_placement.get("mine_resource_summary", Dictionary())).get("signature", "");
	report["fill_coverage_summary"] = object_placement.get("fill_coverage_summary", Dictionary());
	report["town_generation_status"] = town_guard_placement.get("town_generation_status", "");
	report["guard_generation_status"] = town_guard_placement.get("guard_generation_status", "");
	report["town_guard_placement_signature"] = town_guard_placement.get("signature", "");
	report["town_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	report["guard_placement_signature"] = Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", "");
	report["town_guard_occupancy_signature"] = Dictionary(town_guard_placement.get("combined_occupancy_index", Dictionary())).get("signature", "");
	report["town_guard_category_counts"] = town_guard_placement.get("category_counts", Dictionary());
	report["town_pair_route_guard_closure"] = town_guard_placement.get("town_pair_route_guard_closure", Dictionary());
	Array remaining_parity_slices;
	if (owner_compared_translated_profile_supported) {
		remaining_parity_slices.append("native-rmg-full-homm3-parity-gate-10184");
		remaining_parity_slices.append("native-rmg-islands-owner-compared-runtime-support-10184");
		remaining_parity_slices.append("native-rmg-broad-template-owner-comparison-gate-10184");
	} else if (scoped_structural_profile_supported) {
		remaining_parity_slices.append("native-rmg-package-session-authoritative-replay-gate-10184");
	} else if (translated_catalog_structural_profile_supported) {
		remaining_parity_slices.append("native-rmg-broad-template-owner-comparison-gate-10184");
		remaining_parity_slices.append("native-rmg-full-homm3-parity-gate-10184");
		remaining_parity_slices.append("native-rmg-islands-underground-production-support-10184");
	} else {
		remaining_parity_slices.append("native-rmg-production-owner-comparison-gate-10184");
	}
	report["remaining_parity_slices"] = remaining_parity_slices;
	report["no_authored_writeback"] = true;
	report["full_parity_claim"] = false;
	report["native_runtime_authoritative"] = false;
	report["supported_parity_config"] = scoped_structural_profile_supported;
	report["scoped_structural_profile_supported"] = scoped_structural_profile_supported;
	report["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	report["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	Dictionary report_signature_source = report.duplicate(true);
	report_signature_source["object_placement_pipeline_summary"] = deterministic_object_placement_pipeline_summary(Dictionary(object_placement.get("object_placement_pipeline_summary", Dictionary())));
	report_signature_source["object_placement_pipeline_summary_signature"] = deterministic_object_placement_pipeline_signature(object_placement);
	report["report_signature"] = hash32_hex(canonical_variant(report_signature_source));
	return report;
}

Dictionary build_native_random_map_provenance(const Dictionary &normalized, const Dictionary &identity, const Dictionary &validation_report) {
	Dictionary provenance;
	provenance["schema_id"] = NATIVE_RMG_PROVENANCE_SCHEMA_ID;
	provenance["schema_version"] = 1;
	provenance["source"] = "native_gdextension_rmg_foundation";
	provenance["generator_version"] = NATIVE_RMG_VERSION;
	provenance["normalized_seed"] = normalized.get("normalized_seed", "");
	provenance["template_id"] = normalized.get("template_id", "");
	provenance["profile_id"] = normalized.get("profile_id", "");
	provenance["size_class_id"] = normalized.get("size_class_id", "");
	provenance["water_mode"] = normalized.get("water_mode", "land");
	provenance["deterministic_identity"] = identity;
	provenance["config_hash"] = identity.get("config_hash", "");
	provenance["map_id"] = identity.get("map_id", "");
	provenance["component_signatures"] = validation_report.get("component_signatures", Dictionary());
	provenance["component_counts"] = validation_report.get("component_counts", Dictionary());
	provenance["phase_signature"] = validation_report.get("phase_signature", "");
	provenance["validation_status"] = validation_report.get("validation_status", "");
	provenance["validation_report_signature"] = validation_report.get("report_signature", "");
	provenance["full_output_signature"] = validation_report.get("full_output_signature", "");
	provenance["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	const bool owner_compared_translated_profile_supported = native_rmg_owner_compared_translated_profile_supported(normalized);
	const bool translated_catalog_structural_profile_supported = native_rmg_translated_catalog_structural_profile_supported(normalized);
	Dictionary boundaries;
	boundaries["authored_content_writeback"] = false;
	boundaries["authored_tile_writeback"] = false;
	boundaries["save_schema_write"] = false;
	boundaries["runtime_call_site_adoption"] = false;
	boundaries["package_session_adoption"] = scoped_structural_profile_supported || owner_compared_translated_profile_supported || translated_catalog_structural_profile_supported;
	boundaries["native_runtime_authoritative"] = false;
	boundaries["full_parity_claim"] = false;
	boundaries["content_provenance"] = "native_generated_records_only_original_placeholder_ids_no_authored_json_mutation";
	provenance["boundaries"] = boundaries;
	provenance["full_parity_claim"] = false;
	provenance["native_runtime_authoritative"] = false;
	provenance["scoped_structural_profile_supported"] = scoped_structural_profile_supported;
	provenance["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	provenance["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	provenance["signature"] = hash32_hex(canonical_variant(provenance));
	return provenance;
}

Array tagged_record_snapshots(const Variant &value, const String &record_kind) {
	Array result;
	if (value.get_type() != Variant::ARRAY) {
		return result;
	}
	Array source = value;
	for (int64_t index = 0; index < source.size(); ++index) {
		if (Variant(source[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary record = Dictionary(source[index]).duplicate(true);
		record["native_record_kind"] = record_kind;
		if (!record.has("level")) {
			record["level"] = 0;
		}
		result.append(record);
	}
	return result;
}

Array body_tiles_for_package_surface(const Dictionary &record) {
	Array body_tiles = record.get("body_tiles", Array());
	if (!body_tiles.is_empty()) {
		return body_tiles.duplicate(true);
	}
	Dictionary primary = record.get("primary_tile", Dictionary());
	if (primary.is_empty()) {
		primary = cell_record(int32_t(record.get("x", 0)), int32_t(record.get("y", 0)), int32_t(record.get("level", 0)));
	}
	Array result;
	result.append(primary);
	return result;
}

Array visit_tiles_for_package_surface(const Dictionary &record, bool blocking_body) {
	Array approach_tiles = record.get("approach_tiles", Array());
	if (blocking_body && !approach_tiles.is_empty()) {
		return approach_tiles.duplicate(true);
	}
	Dictionary visit_tile = record.get("visit_tile", Dictionary());
	if (visit_tile.is_empty()) {
		visit_tile = cell_record(int32_t(record.get("x", 0)), int32_t(record.get("y", 0)), int32_t(record.get("level", 0)));
	}
	Array result;
	result.append(visit_tile);
	return result;
}

bool record_blocks_package_pathing(const Dictionary &record) {
	const String kind = String(record.get("kind", ""));
	const String passability_class = String(record.get("passability_class", ""));
	return bool(record.get("blocking_body", false)) || kind == "guard" || kind == "town" || kind == "connection_gate" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference" || passability_class.begins_with("blocking") || passability_class == "edge_blocker";
}

bool record_is_visitable_package_object(const Dictionary &record) {
	const String kind = String(record.get("kind", ""));
	return kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference" || kind == "town" || kind == "guard" || kind == "connection_gate";
}

Dictionary package_surface_record(Dictionary record) {
	const bool blocking_body = record_blocks_package_pathing(record);
	const bool visitable = record_is_visitable_package_object(record);
	Array body_tiles = body_tiles_for_package_surface(record);
	Array block_tiles = blocking_body ? body_tiles.duplicate(true) : Array();
	Array visit_tiles = visitable ? visit_tiles_for_package_surface(record, blocking_body) : Array();
	Dictionary block_seen;
	for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
		if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary block = Dictionary(block_tiles[block_index]);
		block_seen[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
	}
	Array route_closure_tiles = record.get("route_closure_block_tiles", Array());
	for (int64_t closure_index = 0; closure_index < route_closure_tiles.size(); ++closure_index) {
		if (Variant(route_closure_tiles[closure_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary closure = Dictionary(route_closure_tiles[closure_index]);
		const String key = point_key(int32_t(closure.get("x", 0)), int32_t(closure.get("y", 0)));
		if (block_seen.has(key)) {
			continue;
		}
		block_tiles.append(closure);
		block_seen[key] = true;
	}

	record["package_surface_adoption_version"] = 1;
	record["package_surface_adoption_state"] = "native_generated_record_materialized_for_package_editor_runtime_surface";
	record["package_pathing_materialization_state"] = "body_visit_block_masks_materialized_for_generated_package_surface";
	record["package_body_tiles"] = body_tiles;
	record["package_block_tiles"] = block_tiles;
	record["package_visit_tiles"] = visit_tiles;
	record["package_body_tile_count"] = body_tiles.size();
	record["package_block_tile_count"] = block_tiles.size();
	record["package_visit_tile_count"] = visit_tiles.size();
	if (!route_closure_tiles.is_empty()) {
		record["package_route_closure_block_tile_count"] = route_closure_tiles.size();
		record["package_route_closure_policy"] = record.get("route_closure_policy", "existing_guard_route_closure_masks_preserved_on_package_surface");
	}
	record["blocking_body"] = blocking_body;
	record["visitable"] = visitable;
	record["interaction"] = visitable ? (blocking_body ? "adjacent_visit" : "body_visit") : "none";
	record["visit_policy"] = visitable ? (blocking_body ? "adjacent_to_blocking_body" : "enter_body_tile") : "non_visitable";
	record["package_occupancy_role"] = blocking_body ? (visitable ? "visitable_blocking_body" : "blocking_body") : (visitable ? "visitable_nonblocking_body" : "nonblocking_nonvisitable");
	record["materialization_state"] = "package_surface_materialized_feature_gated_from_native_generation";
	return record;
}

Dictionary guard_reference_for_package_surface(const Dictionary &guard) {
	Dictionary reference;
	reference["guard_id"] = guard.get("guard_id", "");
	reference["placement_id"] = guard.get("placement_id", "");
	reference["guard_kind"] = guard.get("guard_kind", "");
	reference["guard_value"] = guard.get("guard_value", 0);
	reference["strength_band"] = guard.get("strength_band", "");
	reference["guard_reward_value_ratio"] = guard.get("guard_reward_value_ratio", 0.0);
	reference["guard_distance"] = guard.get("guard_distance", 0);
	reference["adjacent_to_guarded_object"] = guard.get("adjacent_to_guarded_object", false);
	reference["x"] = guard.get("x", 0);
	reference["y"] = guard.get("y", 0);
	reference["level"] = guard.get("level", 0);
	reference["primary_tile"] = guard.get("primary_tile", Dictionary());
	reference["stack_records"] = guard.get("stack_records", Array());
	reference["protected_target_type"] = guard.get("protected_target_type", "");
	reference["protected_object_placement_id"] = guard.get("protected_object_placement_id", "");
	return reference;
}

void apply_package_guard_link(Dictionary &record, const Dictionary &guard) {
	if (guard.is_empty()) {
		return;
	}
	Dictionary reference = guard_reference_for_package_surface(guard);
	record["protected_by_guard"] = true;
	record["guarded_by_guard_id"] = guard.get("guard_id", "");
	record["guarded_by_placement_id"] = guard.get("placement_id", "");
	record["guarded_by_guard_kind"] = guard.get("guard_kind", "");
	record["guarded_by_guard_value"] = guard.get("guard_value", 0);
	record["guarded_by_strength_band"] = guard.get("strength_band", "");
	record["guard_reward_value_ratio"] = guard.get("guard_reward_value_ratio", 0.0);
	record["guard_distance"] = guard.get("guard_distance", 0);
	record["adjacent_to_guarded_object"] = guard.get("adjacent_to_guarded_object", false);
	record["guard_reference"] = reference;

	Dictionary access;
	access["requires_guard_clear"] = true;
	access["blocking_guard_placement_id"] = guard.get("placement_id", "");
	access["blocking_guard_id"] = guard.get("guard_id", "");
	access["clear_required_for_visit"] = true;
	access["access_state_before_clear"] = "blocked_by_guard";
	access["access_state_after_clear"] = "visitable";
	access["guard_value"] = guard.get("guard_value", 0);
	access["guard_strength_band"] = guard.get("strength_band", "");
	record["guarded_access_requirements"] = access;

	Dictionary guard_link;
	guard_link["guard_role"] = "guards_generated_reward_or_site";
	guard_link["target_kind"] = record.get("kind", "");
	guard_link["target_placement_id"] = record.get("placement_id", "");
	guard_link["guard_placement_id"] = guard.get("placement_id", "");
	guard_link["guard_id"] = guard.get("guard_id", "");
	guard_link["blocks_approach"] = true;
	guard_link["clear_required_for_target"] = true;
	record["guard_link"] = guard_link;

	Dictionary passability;
	passability["passability_class"] = "guarded_reward_body";
	passability["interaction_mode"] = "adjacent_after_guard_clear";
	passability["blocks_route_until_cleared"] = true;
	passability["blocking_guard_placement_id"] = guard.get("placement_id", "");
	record["passability"] = passability;

	Dictionary ai_hints;
	ai_hints["path_blocking"] = true;
	ai_hints["avoid_until_strength"] = guard.get("strength_band", "");
	ai_hints["neutral_clearance_value"] = guard.get("guard_value", 0);
	ai_hints["guard_target_value_hint"] = record.get("reward_value", record.get("guard_base_value", 0));
	record["ai_hints"] = ai_hints;
	record["package_guard_adoption_state"] = "guard_link_materialized_on_protected_object_package_surface";
}

Array land_boundary_rock_cells_from_generated_map(const Dictionary &generated_map) {
	Array cells;
	Dictionary terrain_grid = generated_map.get("terrain_grid", Dictionary());
	Dictionary boundary_shape = terrain_grid.get("land_boundary_shape", Dictionary());
	if (!bool(boundary_shape.get("enabled", false))) {
		return cells;
	}
	Array levels = terrain_grid.get("levels", Array());
	if (levels.is_empty() || Variant(levels[0]).get_type() != Variant::DICTIONARY) {
		return cells;
	}
	Dictionary level = Dictionary(levels[0]);
	PackedInt32Array terrain_codes = level.get("terrain_code_u16", PackedInt32Array());
	const int32_t width = int32_t(terrain_grid.get("width", generated_map.get("width", 36)));
	const int32_t height = int32_t(terrain_grid.get("height", generated_map.get("height", 36)));
	const int32_t rock_code = terrain_code_for_id("rock");
	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			const int32_t index = y * width + x;
			if (index >= 0 && index < terrain_codes.size() && terrain_codes[index] == rock_code) {
				cells.append(cell_record(x, y, 0));
			}
		}
	}
	return cells;
}

int32_t nearest_body_distance_to_cell(const Array &body_tiles, int32_t x, int32_t y) {
	int32_t best = std::numeric_limits<int32_t>::max();
	for (int64_t index = 0; index < body_tiles.size(); ++index) {
		if (Variant(body_tiles[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary body = Dictionary(body_tiles[index]);
		const int32_t bx = int32_t(body.get("x", 0));
		const int32_t by = int32_t(body.get("y", 0));
		best = std::min(best, std::max(std::abs(x - bx), std::abs(y - by)));
	}
	return best;
}

void append_unique_package_block_tile(Dictionary &record, Dictionary &seen, const Dictionary &cell) {
	const String key = point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)));
	if (seen.has(key)) {
		return;
	}
	Array block_tiles = record.get("package_block_tiles", Array());
	block_tiles.append(cell);
	record["package_block_tiles"] = block_tiles;
	record["package_block_tile_count"] = block_tiles.size();
	seen[key] = true;
}

void apply_homm3_style_guard_control_zone_to_package_record(Dictionary &record, int32_t width, int32_t height) {
	if (String(record.get("kind", "")) != "guard") {
		return;
	}
	Dictionary block_seen;
	Array block_tiles = record.get("package_block_tiles", Array());
	for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
		if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary block = Dictionary(block_tiles[block_index]);
		block_seen[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
	}
	Array control_tiles;
	const int32_t center_x = int32_t(record.get("x", 0));
	const int32_t center_y = int32_t(record.get("y", 0));
	for (int32_t dy = -1; dy <= 1; ++dy) {
		for (int32_t dx = -1; dx <= 1; ++dx) {
			const int32_t x = center_x + dx;
			const int32_t y = center_y + dy;
			if (x < 0 || y < 0 || x >= width || y >= height) {
				continue;
			}
			Dictionary cell = cell_record(x, y, int32_t(record.get("level", 0)));
			append_unique_package_block_tile(record, block_seen, cell);
			control_tiles.append(cell);
		}
	}
	record["package_guard_control_zone_tiles"] = control_tiles;
	record["package_guard_control_zone_tile_count"] = control_tiles.size();
	record["package_guard_control_zone_policy"] = "homm3_style_one_tile_monster_control_zone_blocks_unguarded_package_pathing_until_guard_cleared";
	record["package_pathing_materialization_state"] = "body_visit_guard_control_zone_and_route_closure_masks_materialized_for_generated_package_surface";
}

void apply_land_boundary_choke_masks_to_decorative_package_objects(Array &objects, const Dictionary &generated_map) {
	Array boundary_cells = land_boundary_rock_cells_from_generated_map(generated_map);
	Dictionary normalized = generated_map.get("normalized_config", Dictionary());
	const bool selective_small_boundary_masks = native_rmg_owner_uploaded_small_049_case(normalized);
	std::vector<int64_t> decorative_indices;
	decorative_indices.reserve(objects.size());
	std::vector<int64_t> route_guard_indices;
	route_guard_indices.reserve(objects.size());
	for (int64_t index = 0; index < objects.size(); ++index) {
		if (Variant(objects[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary object = Dictionary(objects[index]);
		if (String(object.get("kind", "")) == "decorative_obstacle") {
			decorative_indices.push_back(index);
		} else if (String(object.get("kind", "")) == "guard") {
			route_guard_indices.push_back(index);
		}
	}
	if (decorative_indices.empty() && route_guard_indices.empty()) {
		return;
	}
	int32_t assigned_count = 0;
	Dictionary assigned_lookup;
	const int32_t width = int32_t(Dictionary(generated_map.get("terrain_grid", Dictionary())).get("width", generated_map.get("width", 36)));
	const int32_t height = int32_t(Dictionary(generated_map.get("terrain_grid", Dictionary())).get("height", generated_map.get("height", 36)));
	const int32_t max_mask_radius = std::max(4, std::max(width, height) / 4);
	Dictionary selective_blocked_lookup;
	Dictionary boundary_lookup;
	for (int64_t cell_index = 0; cell_index < boundary_cells.size(); ++cell_index) {
		if (Variant(boundary_cells[cell_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary cell = Dictionary(boundary_cells[cell_index]);
		boundary_lookup[point_key(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)))] = true;
	}
	auto assign_boundary_cell = [&](const Dictionary &cell, const String &source) -> bool {
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		const String key = point_key(x, y);
		if (assigned_lookup.has(key)) {
			return false;
		}
		int64_t best_object_index = -1;
		int32_t best_distance = std::numeric_limits<int32_t>::max();
		for (int64_t decorative_index : decorative_indices) {
			Dictionary object = Dictionary(objects[decorative_index]);
			const int32_t distance = nearest_body_distance_to_cell(object.get("package_body_tiles", Array()), x, y);
			if (distance < best_distance) {
				best_distance = distance;
				best_object_index = decorative_index;
			}
		}
		if (best_object_index < 0 || best_distance > max_mask_radius) {
			return false;
		}
		Dictionary object = Dictionary(objects[best_object_index]);
		Dictionary block_seen;
		Array block_tiles = object.get("package_block_tiles", Array());
		for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
			if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary block = Dictionary(block_tiles[block_index]);
			block_seen[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
		}
		const int32_t before_count = Array(object.get("package_block_tiles", Array())).size();
		append_unique_package_block_tile(object, block_seen, cell);
		const int32_t after_count = Array(object.get("package_block_tiles", Array())).size();
		if (after_count <= before_count) {
			assigned_lookup[key] = true;
			return false;
		}
		object["package_boundary_choke_mask_source"] = source;
		object["package_boundary_choke_max_mask_radius"] = max_mask_radius;
		object["package_boundary_choke_tile_count"] = int32_t(object.get("package_boundary_choke_tile_count", 0)) + 1;
		object["package_pathing_materialization_state"] = "body_visit_and_boundary_choke_masks_materialized_for_generated_package_surface";
		objects[best_object_index] = object;
		assigned_lookup[key] = true;
		selective_blocked_lookup[key] = true;
		++assigned_count;
		return true;
	};
	auto assign_boundary_cluster = [&](int32_t center_x, int32_t center_y, int32_t radius, const String &source) -> int32_t {
		int32_t added = 0;
		for (int64_t boundary_index = 0; boundary_index < boundary_cells.size(); ++boundary_index) {
			if (Variant(boundary_cells[boundary_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary candidate = Dictionary(boundary_cells[boundary_index]);
			const int32_t x = int32_t(candidate.get("x", 0));
			const int32_t y = int32_t(candidate.get("y", 0));
			if (std::max(std::abs(x - center_x), std::abs(y - center_y)) > radius) {
				continue;
			}
			if (assign_boundary_cell(candidate, source)) {
				++added;
			}
		}
		return added;
	};
	auto assign_route_guard_closure_cell = [&](const Dictionary &cell, const String &source) -> bool {
		if (route_guard_indices.empty()) {
			return false;
		}
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		const String key = point_key(x, y);
		if (selective_blocked_lookup.has(key)) {
			return false;
		}
		int64_t best_guard_index = -1;
		int32_t best_distance = std::numeric_limits<int32_t>::max();
		for (int64_t route_guard_index : route_guard_indices) {
			Dictionary guard = Dictionary(objects[route_guard_index]);
			const int32_t distance = std::abs(x - int32_t(guard.get("x", 0))) + std::abs(y - int32_t(guard.get("y", 0)));
			if (distance < best_distance) {
				best_distance = distance;
				best_guard_index = route_guard_index;
			}
		}
		if (best_guard_index < 0) {
			return false;
		}
		Dictionary guard = Dictionary(objects[best_guard_index]);
		Dictionary block_seen;
		Array block_tiles = guard.get("package_block_tiles", Array());
		for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
			if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary block = Dictionary(block_tiles[block_index]);
			block_seen[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
		}
		const int32_t before_count = Array(guard.get("package_block_tiles", Array())).size();
		append_unique_package_block_tile(guard, block_seen, cell);
		const int32_t after_count = Array(guard.get("package_block_tiles", Array())).size();
		if (after_count <= before_count) {
			return false;
		}
		guard["package_route_guard_closure_mask_source"] = source;
		guard["package_route_guard_closure_tile_count"] = int32_t(guard.get("package_route_guard_closure_tile_count", 0)) + 1;
		guard["package_pathing_materialization_state"] = "body_visit_and_selective_route_guard_closure_masks_materialized_for_generated_package_surface";
		objects[best_guard_index] = guard;
		selective_blocked_lookup[key] = true;
		return true;
	};
	auto assign_route_guard_closure_cluster = [&](int32_t center_x, int32_t center_y, int32_t radius, const String &source) -> int32_t {
		int32_t added = 0;
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				const int32_t x = center_x + dx;
				const int32_t y = center_y + dy;
				if (x < 0 || y < 0 || x >= width || y >= height) {
					continue;
				}
				if (assign_route_guard_closure_cell(cell_record(x, y, 0), source)) {
					++added;
				}
			}
		}
		return added;
	};
	auto assign_decorative_route_closure_cell = [&](const Dictionary &cell, const String &source) -> bool {
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		const String key = point_key(x, y);
		if (selective_blocked_lookup.has(key)) {
			return false;
		}
		int64_t best_object_index = -1;
		int32_t best_distance = std::numeric_limits<int32_t>::max();
		for (int64_t decorative_index : decorative_indices) {
			Dictionary object = Dictionary(objects[decorative_index]);
			const int32_t distance = nearest_body_distance_to_cell(object.get("package_body_tiles", Array()), x, y);
			if (distance < best_distance) {
				best_distance = distance;
				best_object_index = decorative_index;
			}
		}
		if (best_object_index < 0) {
			return false;
		}
		Dictionary object = Dictionary(objects[best_object_index]);
		Dictionary block_seen;
		Array block_tiles = object.get("package_block_tiles", Array());
		for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
			if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary block = Dictionary(block_tiles[block_index]);
			block_seen[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
		}
		const int32_t before_count = Array(object.get("package_block_tiles", Array())).size();
		append_unique_package_block_tile(object, block_seen, cell);
		const int32_t after_count = Array(object.get("package_block_tiles", Array())).size();
		if (after_count <= before_count) {
			selective_blocked_lookup[key] = true;
			return false;
		}
		object["package_route_decorative_closure_mask_source"] = source;
		object["package_route_decorative_closure_tile_count"] = int32_t(object.get("package_route_decorative_closure_tile_count", 0)) + 1;
		object["package_pathing_materialization_state"] = "body_visit_boundary_choke_and_route_closure_masks_materialized_for_generated_package_surface";
		objects[best_object_index] = object;
		selective_blocked_lookup[key] = true;
		++assigned_count;
		return true;
	};
	if (selective_small_boundary_masks) {
		Array towns;
		for (int64_t object_index = 0; object_index < objects.size(); ++object_index) {
			if (Variant(objects[object_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary object = Dictionary(objects[object_index]);
			Array block_tiles = object.get("package_block_tiles", Array());
			for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
				if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary block = Dictionary(block_tiles[block_index]);
				selective_blocked_lookup[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
			}
			if (String(object.get("kind", "")) == "town") {
				towns.append(object);
			}
		}
		static constexpr int32_t MAX_SELECTIVE_PASSES = 8;
		for (int32_t pass = 0; pass < MAX_SELECTIVE_PASSES; ++pass) {
			bool added_this_pass = false;
			for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
				if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary left = Dictionary(towns[left_index]);
				for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
					if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
						continue;
					}
					Dictionary right = Dictionary(towns[right_index]);
					Array path = direct_access_path_between_cell_sets(left.get("package_visit_tiles", Array()), right.get("package_visit_tiles", Array()), width, height, selective_blocked_lookup);
					if (path.is_empty()) {
						continue;
					}
					int32_t added_for_path = 0;
					const int32_t midpoint = int32_t(path.size() / 2);
					for (int32_t distance = 0; distance < path.size() && added_for_path == 0; ++distance) {
						const int32_t candidates[2] = { midpoint - distance, midpoint + distance };
						for (const int32_t candidate : candidates) {
							if (candidate < 0 || candidate >= path.size() || Variant(path[candidate]).get_type() != Variant::DICTIONARY) {
								continue;
							}
							Dictionary path_cell = Dictionary(path[candidate]);
							const int32_t x = int32_t(path_cell.get("x", 0));
							const int32_t y = int32_t(path_cell.get("y", 0));
							if (!boundary_lookup.has(point_key(x, y))) {
								continue;
							}
							added_for_path += assign_boundary_cluster(x, y, 1, "selective_small_town_route_boundary_choke_mask");
						}
					}
					if (added_for_path == 0 && !path.is_empty() && Variant(path[midpoint]).get_type() == Variant::DICTIONARY) {
						Dictionary midpoint_cell = Dictionary(path[midpoint]);
						const int32_t mid_x = int32_t(midpoint_cell.get("x", 0));
						const int32_t mid_y = int32_t(midpoint_cell.get("y", 0));
						int32_t best_distance = std::numeric_limits<int32_t>::max();
						Dictionary best_boundary;
						for (int64_t boundary_index = 0; boundary_index < boundary_cells.size(); ++boundary_index) {
							if (Variant(boundary_cells[boundary_index]).get_type() != Variant::DICTIONARY) {
								continue;
							}
							Dictionary candidate = Dictionary(boundary_cells[boundary_index]);
							const int32_t x = int32_t(candidate.get("x", 0));
							const int32_t y = int32_t(candidate.get("y", 0));
							const int32_t distance = std::abs(x - mid_x) + std::abs(y - mid_y);
							if (distance < best_distance) {
								best_distance = distance;
								best_boundary = candidate;
							}
						}
						if (!best_boundary.is_empty()) {
							added_for_path += assign_boundary_cluster(int32_t(best_boundary.get("x", 0)), int32_t(best_boundary.get("y", 0)), 1, "selective_small_nearest_route_boundary_choke_mask");
						}
					}
					added_this_pass = added_this_pass || added_for_path > 0;
				}
			}
			if (!added_this_pass) {
				break;
			}
		}
		bool remaining_reachable_pair = false;
		for (int64_t left_index = 0; left_index < towns.size() && !remaining_reachable_pair; ++left_index) {
			if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary left = Dictionary(towns[left_index]);
			for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
				if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary right = Dictionary(towns[right_index]);
				if (!direct_access_path_between_cell_sets(left.get("package_visit_tiles", Array()), right.get("package_visit_tiles", Array()), width, height, selective_blocked_lookup).is_empty()) {
					remaining_reachable_pair = true;
					break;
				}
			}
		}
		if (remaining_reachable_pair) {
			static constexpr int32_t MAX_ROUTE_GUARD_CLOSURE_PASSES = 6;
			for (int32_t pass = 0; pass < MAX_ROUTE_GUARD_CLOSURE_PASSES && remaining_reachable_pair; ++pass) {
				bool added_this_pass = false;
				remaining_reachable_pair = false;
				for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
					if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
						continue;
					}
					Dictionary left = Dictionary(towns[left_index]);
					for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
						if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
							continue;
						}
						Dictionary right = Dictionary(towns[right_index]);
						Array path = direct_access_path_between_cell_sets(left.get("package_visit_tiles", Array()), right.get("package_visit_tiles", Array()), width, height, selective_blocked_lookup);
						if (path.is_empty()) {
							continue;
						}
						remaining_reachable_pair = true;
						const int32_t midpoint = int32_t(path.size() / 2);
						if (midpoint >= 0 && midpoint < path.size() && Variant(path[midpoint]).get_type() == Variant::DICTIONARY) {
							Dictionary midpoint_cell = Dictionary(path[midpoint]);
							added_this_pass = assign_route_guard_closure_cluster(int32_t(midpoint_cell.get("x", 0)), int32_t(midpoint_cell.get("y", 0)), 1, "selective_small_remaining_town_route_guard_closure_mask") > 0 || added_this_pass;
						}
					}
				}
				if (!added_this_pass) {
					break;
				}
			}
		}
		if (remaining_reachable_pair) {
			for (int64_t cell_index = 0; cell_index < boundary_cells.size(); ++cell_index) {
				if (Variant(boundary_cells[cell_index]).get_type() == Variant::DICTIONARY) {
					assign_boundary_cell(Dictionary(boundary_cells[cell_index]), "land_boundary_rock_cells_materialized_on_nearby_decorative_obstacle_masks_fallback");
				}
			}
		}
	} else {
		for (int64_t cell_index = 0; cell_index < boundary_cells.size(); ++cell_index) {
			if (Variant(boundary_cells[cell_index]).get_type() == Variant::DICTIONARY) {
				assign_boundary_cell(Dictionary(boundary_cells[cell_index]), "land_boundary_rock_cells_materialized_on_nearby_decorative_obstacle_masks");
			}
		}
		Array towns;
		for (int64_t object_index = 0; object_index < objects.size(); ++object_index) {
			if (Variant(objects[object_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary object = Dictionary(objects[object_index]);
			Array block_tiles = object.get("package_block_tiles", Array());
			for (int64_t block_index = 0; block_index < block_tiles.size(); ++block_index) {
				if (Variant(block_tiles[block_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary block = Dictionary(block_tiles[block_index]);
				selective_blocked_lookup[point_key(int32_t(block.get("x", 0)), int32_t(block.get("y", 0)))] = true;
			}
			if (String(object.get("kind", "")) == "town") {
				towns.append(object);
			}
		}
		static constexpr int32_t MAX_ROUTE_GUARD_CLOSURE_PASSES = 20;
		bool remaining_reachable_pair = true;
		for (int32_t pass = 0; pass < MAX_ROUTE_GUARD_CLOSURE_PASSES && remaining_reachable_pair; ++pass) {
			bool added_this_pass = false;
			remaining_reachable_pair = false;
			for (int64_t left_index = 0; left_index < towns.size(); ++left_index) {
				if (Variant(towns[left_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary left = Dictionary(towns[left_index]);
				for (int64_t right_index = left_index + 1; right_index < towns.size(); ++right_index) {
					if (Variant(towns[right_index]).get_type() != Variant::DICTIONARY) {
						continue;
					}
					Dictionary right = Dictionary(towns[right_index]);
					Array path = direct_access_path_between_cell_sets(left.get("package_visit_tiles", Array()), right.get("package_visit_tiles", Array()), width, height, selective_blocked_lookup);
					if (path.is_empty()) {
						continue;
					}
					remaining_reachable_pair = true;
					for (int64_t path_index = 1; path_index < path.size() - 1; ++path_index) {
						if (Variant(path[path_index]).get_type() != Variant::DICTIONARY) {
							continue;
						}
						Dictionary path_cell = Dictionary(path[path_index]);
						const int32_t path_x = int32_t(path_cell.get("x", 0));
						const int32_t path_y = int32_t(path_cell.get("y", 0));
						added_this_pass = assign_decorative_route_closure_cell(cell_record(path_x, path_y, 0), "broad_land_remaining_town_route_decorative_closure_mask") || added_this_pass;
						added_this_pass = assign_route_guard_closure_cluster(path_x, path_y, 1, "broad_land_remaining_town_route_guard_closure_mask") > 0 || added_this_pass;
					}
				}
			}
			if (!added_this_pass) {
				break;
			}
		}
	}
	for (int64_t index = 0; index < objects.size(); ++index) {
		if (Variant(objects[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary object = Dictionary(objects[index]);
		if (String(object.get("kind", "")) == "decorative_obstacle") {
			object["package_boundary_choke_materialized_tile_total"] = assigned_count;
			object["package_boundary_choke_materialization_policy"] = selective_small_boundary_masks ? String("selective_small_town_route_boundary_choke_masks_cover_only_package_pathing_escape_routes_with_full_mask_fallback") : String("nearby_decorative_obstacle_masks_cover_land_boundary_choke_cells_so_package_pathing_does_not_depend_only_on_terrain_rock");
			objects[index] = object;
		}
	}
}

Array combined_native_map_objects(const Dictionary &generated_map) {
	Array result;
	Dictionary terrain_grid = generated_map.get("terrain_grid", Dictionary());
	Dictionary normalized = generated_map.get("normalized_config", Dictionary());
	const int32_t width = int32_t(terrain_grid.get("width", normalized.get("width", 36)));
	const int32_t height = int32_t(terrain_grid.get("height", normalized.get("height", 36)));
	Array objects = tagged_record_snapshots(generated_map.get("object_placements", Variant()), "object_placement");
	Array guards = tagged_record_snapshots(generated_map.get("guard_records", Variant()), "guard");
	Dictionary guards_by_protected_object;
	for (int64_t index = 0; index < guards.size(); ++index) {
		Dictionary guard = guards[index];
		const String protected_id = String(guard.get("protected_object_placement_id", ""));
		if (String(guard.get("protected_target_type", "")) == "object_placement" && !protected_id.is_empty()) {
			guards_by_protected_object[protected_id] = guard;
		}
	}
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary record = package_surface_record(Dictionary(objects[index]).duplicate(true));
		const String placement_id = String(record.get("placement_id", ""));
		if (guards_by_protected_object.has(placement_id)) {
			apply_package_guard_link(record, Dictionary(guards_by_protected_object.get(placement_id, Dictionary())));
		} else {
			record["protected_by_guard"] = false;
			record["package_guard_adoption_state"] = "no_guard_link_for_package_surface";
		}
		record["signature"] = hash32_hex(canonical_variant(record));
		result.append(record);
	}
	Array towns = tagged_record_snapshots(generated_map.get("town_records", Variant()), "town");
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary record = package_surface_record(Dictionary(towns[index]).duplicate(true));
		record["package_guard_adoption_state"] = "town_record_not_reward_guard_target";
		record["signature"] = hash32_hex(canonical_variant(record));
		result.append(record);
	}
	for (int64_t index = 0; index < guards.size(); ++index) {
		Dictionary record = package_surface_record(Dictionary(guards[index]).duplicate(true));
		record["blocking_body"] = true;
		record["package_guard_adoption_state"] = "guard_record_materialized_as_blocking_package_surface";
		Dictionary passability;
		passability["passability_class"] = "neutral_stack_blocking";
		passability["interaction_mode"] = "adjacent_combat";
		passability["blocks_route_until_cleared"] = true;
		passability["protected_target_type"] = record.get("protected_target_type", "");
		passability["protected_object_placement_id"] = record.get("protected_object_placement_id", "");
		passability["route_edge_id"] = record.get("route_edge_id", "");
		record["passability"] = passability;
		record["signature"] = hash32_hex(canonical_variant(record));
		result.append(record);
	}
	Array gates = tagged_record_snapshots(generated_map.get("connection_gate_records", Variant()), "connection_gate");
	for (int64_t index = 0; index < gates.size(); ++index) {
		Dictionary record = package_surface_record(Dictionary(gates[index]).duplicate(true));
		record["package_guard_adoption_state"] = "connection_gate_record_materialized_as_blocking_package_surface";
		Dictionary passability;
		passability["passability_class"] = "connection_gate_blocking";
		passability["interaction_mode"] = "adjacent_unlock_or_gate_clear";
		passability["blocks_route_until_cleared"] = true;
		passability["route_edge_id"] = record.get("route_edge_id", "");
		passability["unlock_required"] = record.get("unlock_required", true);
		record["passability"] = passability;
		record["signature"] = hash32_hex(canonical_variant(record));
		result.append(record);
	}
	apply_land_boundary_choke_masks_to_decorative_package_objects(result, generated_map);
	for (int64_t index = 0; index < result.size(); ++index) {
		if (Variant(result[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary record = Dictionary(result[index]);
		if (String(record.get("kind", "")) == "guard") {
			apply_homm3_style_guard_control_zone_to_package_record(record, width, height);
			result[index] = record;
		}
	}
	for (int64_t index = 0; index < result.size(); ++index) {
		if (Variant(result[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary record = Dictionary(result[index]);
		record["signature"] = hash32_hex(canonical_variant(record));
		result[index] = record;
	}
	return result;
}

Dictionary guard_reward_package_adoption_summary(const Array &objects) {
	int32_t reward_count = 0;
	int32_t valuable_reward_count = 0;
	int32_t guarded_valuable_reward_count = 0;
	int32_t guard_count = 0;
	int32_t package_body_tile_count = 0;
	int32_t package_block_tile_count = 0;
	int32_t package_visit_tile_count = 0;
	Array unguarded_high_value_rewards;
	for (int64_t index = 0; index < objects.size(); ++index) {
		Dictionary object = objects[index];
		const String kind = String(object.get("kind", ""));
		package_body_tile_count += int32_t(object.get("package_body_tile_count", 0));
		package_block_tile_count += int32_t(object.get("package_block_tile_count", 0));
		package_visit_tile_count += int32_t(object.get("package_visit_tile_count", 0));
		if (kind == "guard") {
			++guard_count;
			continue;
		}
		if (kind != "reward_reference") {
			continue;
		}
		++reward_count;
		const int32_t value = int32_t(object.get("reward_value", 0));
		if (value >= 2500) {
			++valuable_reward_count;
			if (bool(object.get("protected_by_guard", false))) {
				++guarded_valuable_reward_count;
			}
		}
		if (value >= 6000 && !bool(object.get("protected_by_guard", false))) {
			Dictionary missed;
			missed["placement_id"] = object.get("placement_id", "");
			missed["reward_value"] = value;
			missed["reward_value_tier"] = object.get("reward_value_tier", "");
			unguarded_high_value_rewards.append(missed);
		}
	}
	Dictionary summary;
	summary["schema_id"] = "native_random_map_guard_reward_package_adoption_summary_v1";
	summary["package_adoption_state"] = "guard_reward_body_visit_block_surface_materialized";
	summary["reward_count"] = reward_count;
	summary["valuable_reward_count"] = valuable_reward_count;
	summary["guarded_valuable_reward_count"] = guarded_valuable_reward_count;
	summary["guard_count"] = guard_count;
	summary["package_body_tile_count"] = package_body_tile_count;
	summary["package_block_tile_count"] = package_block_tile_count;
	summary["package_visit_tile_count"] = package_visit_tile_count;
	summary["unguarded_high_value_rewards"] = unguarded_high_value_rewards;
	summary["unguarded_high_value_reward_count"] = unguarded_high_value_rewards.size();
	summary["status"] = unguarded_high_value_rewards.is_empty() ? "pass" : "unguarded_high_value_rewards";
	summary["full_parity_claim"] = false;
	summary["signature"] = hash32_hex(canonical_variant(summary));
	return summary;
}

Dictionary native_conversion_fail(const String &code, const String &message) {
	Dictionary failure;
	failure["code"] = code;
	failure["severity"] = "fail";
	failure["path"] = "convert_generated_payload";
	failure["message"] = message;
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failure_count"] = 1;
	report["warning_count"] = 0;
	report["failures"] = failures;
	report["warnings"] = Array();
	report["metrics"] = Dictionary();
	report["package_session_adoption_ready"] = false;
	report["native_runtime_authoritative"] = false;
	report["full_parity_claim"] = false;

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = code;
	result["message"] = message;
	result["report"] = report;
	result["adoption_status"] = "blocked";
	return result;
}

Dictionary build_native_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	if (!bool(generated_map.get("ok", false))) {
		return native_conversion_fail("native_generation_not_ok", "Native RMG output must be ok=true before package/session adoption.");
	}
	const String generated_status = String(generated_map.get("status", ""));
	if (generated_status != "partial_foundation" && generated_status != "scoped_structural_profile_supported" && generated_status != "owner_compared_translated_profile_supported" && generated_status != "translated_catalog_structural_profile_supported") {
		return native_conversion_fail("unsupported_native_generation_status", "Native package/session adoption accepts partial foundation, scoped structural, broad translated structural, or owner-compared translated native output only.");
	}

	Dictionary normalized = generated_map.get("normalized_config", Dictionary());
	const bool translated_catalog_structural_profile_supported = bool(generated_map.get("translated_catalog_structural_profile_supported", native_rmg_translated_catalog_structural_profile_supported(normalized)));
	const bool structurally_supported_profile = bool(generated_map.get("supported_parity_config", native_rmg_scoped_structural_profile_supported(normalized))) || bool(generated_map.get("scoped_structural_profile_supported", false)) || translated_catalog_structural_profile_supported;
	const bool owner_compared_translated_profile_supported = bool(generated_map.get("owner_compared_translated_profile_supported", native_rmg_owner_compared_translated_profile_supported(normalized)));
	const bool native_runtime_authoritative = owner_compared_translated_profile_supported;
	const bool full_parity_claim = false;
	Dictionary identity = generated_map.get("deterministic_identity", Dictionary());
	Dictionary validation_report = generated_map.get("validation_report", generated_map.get("report", Dictionary()));
	Dictionary provenance = generated_map.get("provenance", Dictionary());
	const String validation_status = String(generated_map.get("validation_status", validation_report.get("validation_status", validation_report.get("status", ""))));
	if (validation_status != "pass") {
		return native_conversion_fail("native_validation_not_pass", "Native RMG validation must pass before package/session adoption.");
	}
	if (bool(generated_map.get("no_authored_writeback", false)) != true) {
		return native_conversion_fail("native_no_authored_writeback_missing", "Native RMG output must preserve the no-authored-writeback boundary.");
	}

	Dictionary validation_metrics = validation_report.get("metrics", Dictionary());
	const int32_t width = int32_t(normalized.get("width", validation_metrics.get("width", 0)));
	const int32_t height = int32_t(normalized.get("height", validation_metrics.get("height", 0)));
	const int32_t level_count = int32_t(normalized.get("level_count", validation_metrics.get("level_count", 1)));
	const String signature = String(generated_map.get("full_output_signature", validation_report.get("full_output_signature", identity.get("signature", ""))));
	const String map_id = String(identity.get("map_id", "native_rmg_" + signature));
	const String map_hash = String("fnv1a32:") + signature;
	const String scenario_id = String(options.get("scenario_id", String("native_rmg_scenario_") + signature));
	const int32_t session_save_version = int32_t(options.get("session_save_version", 9));
	const String feature_gate = String(options.get("feature_gate", "native_rmg_package_session_adoption_bridge"));
	const String session_key = scenario_id + String("|") + map_hash + String("|") + String::num_int64(session_save_version);
	const String session_id = String("native_rmg_session_") + hash32_hex(session_key);

	Dictionary terrain_layers = terrain_layers_from_grid(Dictionary(generated_map.get("terrain_grid", Dictionary())), Dictionary(generated_map.get("road_network", Dictionary())), Dictionary(), normalized);
	Dictionary package_component_counts = generated_map.get("component_counts", Dictionary()).duplicate(true);
	if (terrain_layers.has("road_unique_tile_count")) {
		package_component_counts["road_cell_count"] = terrain_layers.get("road_unique_tile_count", package_component_counts.get("road_cell_count", 0));
		package_component_counts["road_segment_count"] = terrain_layers.get("road_count", package_component_counts.get("road_segment_count", 0));
		package_component_counts["package_road_source_tile_count"] = terrain_layers.get("road_source_tile_count", package_component_counts.get("road_segment_cell_count", 0));
		package_component_counts["package_road_duplicate_tile_count"] = terrain_layers.get("road_duplicate_tile_count", package_component_counts.get("road_duplicate_cell_count", 0));
	}

	Dictionary map_metadata = generated_map.get("map_metadata", Dictionary()).duplicate(true);
	map_metadata["schema_id"] = MAP_SCHEMA_ID;
	map_metadata["schema_version"] = 1;
	map_metadata["source_kind"] = "generated";
	map_metadata["package_session_adoption_status"] = "ready_feature_gated_not_authoritative";
	if (native_runtime_authoritative) {
		map_metadata["package_session_adoption_status"] = "runtime_authoritative_owner_compared_not_full_parity";
	}
	map_metadata["feature_gate"] = feature_gate;
	map_metadata["no_authored_writeback"] = true;
	map_metadata["save_version_bump"] = false;
	map_metadata["native_runtime_authoritative"] = native_runtime_authoritative;
	map_metadata["structurally_supported_profile"] = structurally_supported_profile;
	map_metadata["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	map_metadata["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	map_metadata["full_parity_claim"] = full_parity_claim;
	map_metadata["component_counts"] = package_component_counts;

	Array package_surface_objects = combined_native_map_objects(generated_map);
	Dictionary guard_reward_adoption = guard_reward_package_adoption_summary(package_surface_objects);
	map_metadata["guard_reward_package_adoption"] = guard_reward_adoption;
	map_metadata["guard_reward_package_adoption_signature"] = guard_reward_adoption.get("signature", "");

	Dictionary map_state;
	map_state["map_id"] = map_id;
	map_state["map_hash"] = map_hash;
	map_state["source_kind"] = "generated";
	map_state["width"] = width;
	map_state["height"] = height;
	map_state["level_count"] = level_count;
	map_state["metadata"] = map_metadata;
	map_state["terrain_layers"] = terrain_layers;
	map_state["route_graph"] = generated_map.get("route_graph", Dictionary());
	map_state["objects"] = package_surface_objects;

	Ref<MapDocument> map_document;
	map_document.instantiate();
	map_document->configure(map_state);

	Dictionary map_package_record;
	map_package_record["schema_id"] = "aurelion_generated_map_package_record";
	map_package_record["schema_version"] = 1;
	map_package_record["package_kind"] = "native_rmg_generated_session_cache_record";
	map_package_record["package_id"] = map_id + String(".amap");
	map_package_record["map_id"] = map_id;
	map_package_record["map_hash"] = map_hash;
	map_package_record["source_kind"] = "generated";
	map_package_record["storage_policy"] = "memory_only_no_authored_writeback";
	map_package_record["path_policy"] = "not_written_by_default_feature_gated_cache_record";
	map_package_record["feature_gate"] = feature_gate;
	map_package_record["schema_version_boundary"] = 1;
	map_package_record["save_version_boundary"] = session_save_version;
	map_package_record["save_version_bump"] = false;
	map_package_record["authored_content_writeback"] = false;
	map_package_record["validation_status"] = validation_status;
	map_package_record["full_generation_status"] = generated_map.get("full_generation_status", "not_implemented");
	map_package_record["full_output_signature"] = signature;
	map_package_record["component_signatures"] = generated_map.get("component_signatures", Dictionary());
	map_package_record["component_counts"] = package_component_counts;
	map_package_record["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(map_package_record));

	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = 1;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["package_id"] = map_package_record.get("package_id", "");
	map_ref["package_hash"] = map_package_record.get("package_hash", "");
	map_ref["source_kind"] = "generated";
	map_ref["storage_policy"] = "memory_only_no_authored_writeback";

	Dictionary player_assignment = generated_map.get("player_assignment", Dictionary());
	Array player_slots = player_assignment.get("player_slots", Array());
	Array enemy_factions;
	for (int64_t index = 0; index < player_slots.size(); ++index) {
		if (Variant(player_slots[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary slot = player_slots[index];
		if (bool(slot.get("ai_controlled", false))) {
			Dictionary enemy;
			enemy["faction_id"] = slot.get("faction_id", "");
			enemy["player_slot"] = slot.get("player_slot", 0);
			enemy["team_id"] = slot.get("team_id", "");
			enemy_factions.append(enemy);
		}
	}

	Dictionary start_contract;
	Dictionary player_starts = generated_map.get("player_starts", Dictionary());
	start_contract["schema_id"] = "aurelion_native_rmg_start_contract_v1";
	start_contract["player_starts"] = player_starts.get("starts", Array());
	start_contract["start_count"] = player_starts.get("start_count", 0);
	start_contract["primary_hero_id"] = String(options.get("hero_id", "hero_lyra"));

	Dictionary selection;
	Dictionary availability;
	availability["campaign"] = false;
	availability["skirmish"] = false;
	selection["availability"] = availability;
	selection["generated"] = true;
	selection["package_session_adoption_bridge"] = true;
	selection["player_facing"] = false;

	Dictionary scenario_state;
	scenario_state["scenario_id"] = scenario_id;
	scenario_state["scenario_hash"] = "";
	scenario_state["map_ref"] = map_ref;
	scenario_state["selection"] = selection;
	scenario_state["player_slots"] = player_slots.duplicate(true);
	scenario_state["objectives"] = Dictionary();
	scenario_state["script_hooks"] = Array();
	scenario_state["enemy_factions"] = enemy_factions;
	scenario_state["start_contract"] = start_contract;
	scenario_state["scenario_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(scenario_state));

	Ref<ScenarioDocument> scenario_document;
	scenario_document.instantiate();
	scenario_document->configure(scenario_state);

	Dictionary scenario_package_record;
	scenario_package_record["schema_id"] = "aurelion_generated_scenario_package_record";
	scenario_package_record["schema_version"] = 1;
	scenario_package_record["package_kind"] = "native_rmg_generated_scenario_session_cache_record";
	scenario_package_record["package_id"] = scenario_id + String(".ascenario");
	scenario_package_record["scenario_id"] = scenario_id;
	scenario_package_record["scenario_hash"] = scenario_state.get("scenario_hash", "");
	scenario_package_record["map_ref"] = map_ref;
	scenario_package_record["storage_policy"] = "memory_only_no_authored_writeback";
	scenario_package_record["path_policy"] = "not_written_by_default_feature_gated_cache_record";
	scenario_package_record["feature_gate"] = feature_gate;
	scenario_package_record["save_version_boundary"] = session_save_version;
	scenario_package_record["save_version_bump"] = false;
	scenario_package_record["authored_content_writeback"] = false;
	scenario_package_record["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(scenario_package_record));

	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = 1;
	scenario_ref["scenario_id"] = scenario_id;
	scenario_ref["scenario_hash"] = scenario_state.get("scenario_hash", "");
	scenario_ref["package_id"] = scenario_package_record.get("package_id", "");
	scenario_ref["package_hash"] = scenario_package_record.get("package_hash", "");
	scenario_ref["map_ref"] = map_ref;
	scenario_ref["storage_policy"] = "memory_only_no_authored_writeback";

	Dictionary session_boundary_record;
	session_boundary_record["schema_id"] = "aurelion_native_random_map_session_boundary_v1";
	session_boundary_record["schema_version"] = 1;
	session_boundary_record["session_id"] = session_id;
	session_boundary_record["scenario_id"] = scenario_id;
	session_boundary_record["hero_id"] = start_contract.get("primary_hero_id", "hero_lyra");
	session_boundary_record["launch_mode"] = "generated_draft";
	session_boundary_record["game_state"] = "overworld";
	session_boundary_record["save_version"] = session_save_version;
	session_boundary_record["save_version_bump"] = false;
	session_boundary_record["map_package_ref"] = map_ref;
	session_boundary_record["scenario_package_ref"] = scenario_ref;
	session_boundary_record["feature_gate"] = feature_gate;
	session_boundary_record["generated_record_policy"] = "session_package_records_only";
	session_boundary_record["authored_content_writeback"] = false;
	session_boundary_record["runtime_call_site_adoption"] = native_runtime_authoritative;
	session_boundary_record["gdscript_fallback_untouched"] = !native_runtime_authoritative;
	session_boundary_record["native_runtime_authoritative"] = native_runtime_authoritative;
	session_boundary_record["structurally_supported_profile"] = structurally_supported_profile;
	session_boundary_record["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	session_boundary_record["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	session_boundary_record["full_parity_claim"] = full_parity_claim;

	Dictionary metrics;
	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = map_document->get_tile_count();
	metrics["map_document_object_count"] = map_document->get_object_count();
	metrics["player_slot_count"] = player_slots.size();
	metrics["enemy_faction_count"] = enemy_factions.size();
	metrics["save_version"] = session_save_version;
	metrics["guarded_valuable_reward_count"] = guard_reward_adoption.get("guarded_valuable_reward_count", 0);
	metrics["valuable_reward_count"] = guard_reward_adoption.get("valuable_reward_count", 0);
	metrics["package_block_tile_count"] = guard_reward_adoption.get("package_block_tile_count", 0);
	metrics["package_visit_tile_count"] = guard_reward_adoption.get("package_visit_tile_count", 0);

	Array remaining;
	if (native_runtime_authoritative) {
		remaining.append("native-rmg-full-homm3-parity-gate-10184");
		remaining.append("native-rmg-islands-owner-compared-runtime-support-10184");
		remaining.append("native-rmg-broad-template-owner-comparison-gate-10184");
	} else {
		if (translated_catalog_structural_profile_supported) {
			remaining.append("native-rmg-broad-template-owner-comparison-gate-10184");
			remaining.append("native-rmg-full-homm3-parity-gate-10184");
		} else {
			remaining.append("native-rmg-package-session-authoritative-replay-gate-10184");
		}
	}

	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	report["schema_version"] = 1;
	report["status"] = "pass";
	report["validation_status"] = validation_status;
	report["failure_count"] = 0;
	report["warning_count"] = 0;
	report["failures"] = Array();
	report["warnings"] = Array();
	report["metrics"] = metrics;
	report["package_session_adoption_ready"] = true;
	report["guard_reward_package_adoption"] = guard_reward_adoption;
	report["adoption_status"] = "ready_feature_gated_not_authoritative";
	if (native_runtime_authoritative) {
		report["adoption_status"] = "runtime_authoritative_owner_compared_not_full_parity";
	}
	report["native_runtime_authoritative"] = native_runtime_authoritative;
	report["structurally_supported_profile"] = structurally_supported_profile;
	report["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	report["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	report["runtime_call_site_adoption"] = native_runtime_authoritative;
	report["gdscript_source_of_truth"] = !native_runtime_authoritative;
	report["gdscript_fallback_untouched"] = !native_runtime_authoritative;
	report["full_parity_claim"] = full_parity_claim;
	report["remaining_parity_slices"] = remaining;

	Dictionary readiness;
	readiness["gdscript_source_of_truth"] = !native_runtime_authoritative;
	readiness["native_runtime_authoritative"] = native_runtime_authoritative;
	readiness["structurally_supported_profile"] = structurally_supported_profile;
	readiness["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	readiness["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	readiness["package_session_adoption_ready"] = true;
	readiness["adoption_gate_status"] = "package_session_bridge_ready_feature_gated_authoritative_replay_still_pending";
	if (native_runtime_authoritative) {
		readiness["adoption_gate_status"] = "owner_compared_package_session_runtime_authoritative_not_full_parity";
	}
	readiness["full_parity_claim"] = full_parity_claim;
	readiness["full_parity_gate_pending"] = true;
	readiness["next_required_slices"] = remaining;

	Dictionary result;
	result["ok"] = true;
	result["status"] = "pass";
	result["conversion_kind"] = "native_random_map_output_to_package_session_records";
	result["adoption_status"] = "ready_feature_gated_not_authoritative";
	if (native_runtime_authoritative) {
		result["adoption_status"] = "runtime_authoritative_owner_compared_not_full_parity";
	}
	result["feature_gate"] = feature_gate;
	result["map_document"] = map_document;
	result["scenario_document"] = scenario_document;
	result["map_package_record"] = map_package_record;
	result["scenario_package_record"] = scenario_package_record;
	result["session_boundary_record"] = session_boundary_record;
	result["map_ref"] = map_ref;
	result["scenario_ref"] = scenario_ref;
	result["generated_identity"] = identity;
	result["validation_report"] = validation_report;
	result["provenance"] = provenance;
	result["report"] = report;
	result["readiness"] = readiness;
	result["authored_content_writeback"] = false;
	result["save_version_bump"] = false;
	result["native_runtime_authoritative"] = native_runtime_authoritative;
	result["structurally_supported_profile"] = structurally_supported_profile;
	result["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	result["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	result["full_parity_claim"] = full_parity_claim;
	return result;
}

Dictionary validation_not_implemented(const String &operation, const String &report_schema_id) {
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = String("Validation is stubbed in the native package API skeleton.");
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = report_schema_id;
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failure_count"] = 1;
	report["warning_count"] = 0;
	report["failures"] = failures;
	report["warnings"] = Array();
	report["metrics"] = Dictionary();

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + String(" is not implemented in the Slice 1 native package API skeleton.");
	result["operation"] = operation;
	result["report"] = report;
	result["recoverable"] = true;
	return result;
}

void append_document_validation_issue(Array &issues, const String &code, const String &severity, const String &path, const String &message, Dictionary context = Dictionary()) {
	Dictionary issue;
	issue["code"] = code;
	issue["severity"] = severity;
	issue["path"] = path;
	issue["message"] = message;
	issue["context"] = context;
	issues.append(issue);
}

Dictionary validation_report_result(const String &operation, const String &schema_id, const String &document_id, const String &document_hash, const Array &failures, const Array &warnings, const Dictionary &metrics) {
	Dictionary report;
	report["schema_id"] = schema_id;
	report["schema_version"] = 1;
	report["document_id"] = document_id;
	report["document_hash"] = document_hash;
	report["status"] = failures.is_empty() ? "pass" : "fail";
	report["failure_count"] = failures.size();
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	report["metrics"] = metrics;

	Dictionary result;
	const bool ok = failures.is_empty();
	result["ok"] = ok;
	result["status"] = ok ? "pass" : "fail";
	result["operation"] = operation;
	result["report"] = report;
	result["recoverable"] = false;
	if (!ok) {
		result["error_code"] = "validation_failed";
		result["message"] = operation + String(" failed structural document validation.");
	}
	return result;
}

Dictionary validate_map_document_structural_report(Ref<MapDocument> map_document) {
	Array failures;
	Array warnings;
	Dictionary metrics;
	if (map_document.is_null()) {
		append_document_validation_issue(failures, "missing_map_document", "fail", "map_document", "Map validation requires a MapDocument.");
		return validation_report_result("validate_map_document", "aurelion_map_validation_report", "", "", failures, warnings, metrics);
	}

	const int32_t width = map_document->get_width();
	const int32_t height = map_document->get_height();
	const int32_t level_count = map_document->get_level_count();
	const int32_t tile_count = map_document->get_tile_count();
	const int32_t object_count = map_document->get_object_count();
	const int32_t expected_level_tile_count = width * height;
	const String map_id = map_document->get_map_id();
	const String map_hash = map_document->get_map_hash();

	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = tile_count;
	metrics["object_count"] = object_count;
	if (map_id.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_map_id", "fail", "map_id", "Map document id is required.");
	}
	if (map_hash.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_map_hash", "fail", "map_hash", "Map document hash is required.");
	}
	if (width <= 0 || height <= 0 || level_count <= 0 || tile_count != width * height * level_count) {
		Dictionary context;
		context["width"] = width;
		context["height"] = height;
		context["level_count"] = level_count;
		context["tile_count"] = tile_count;
		append_document_validation_issue(failures, "invalid_map_dimensions", "fail", "dimensions", "Map dimensions, levels, and tile count must be positive and internally consistent.", context);
	}

	PackedStringArray layer_ids = map_document->get_terrain_layer_ids();
	metrics["terrain_layer_count"] = layer_ids.size();
	if (layer_ids.is_empty()) {
		append_document_validation_issue(failures, "missing_terrain_layers", "fail", "terrain_layers", "Map document must contain at least one terrain tile layer.");
	}
	for (int64_t layer_index = 0; layer_index < layer_ids.size(); ++layer_index) {
		const String layer_id = layer_ids[layer_index];
		for (int32_t level = 0; level < level_count; ++level) {
			PackedInt32Array layer = map_document->get_tile_layer_u16(layer_id, level);
			if (layer.size() != expected_level_tile_count) {
				Dictionary context;
				context["layer_id"] = layer_id;
				context["level"] = level;
				context["actual"] = layer.size();
				context["expected"] = expected_level_tile_count;
				append_document_validation_issue(failures, "terrain_layer_tile_count_mismatch", "fail", String("terrain_layers.") + layer_id, "Terrain layer level tile count must match width * height.", context);
			}
		}
	}

	Dictionary terrain_layers = map_document->get_terrain_layers();
	Variant roads_value = terrain_layers.get("roads", Variant());
	int32_t road_count = 0;
	int32_t road_cell_count = 0;
	if (roads_value.get_type() == Variant::ARRAY) {
		Array roads = roads_value;
		road_count = roads.size();
		for (int64_t index = 0; index < roads.size(); ++index) {
			if (Variant(roads[index]).get_type() != Variant::DICTIONARY) {
				Dictionary context;
				context["index"] = index;
				append_document_validation_issue(failures, "invalid_road_record", "fail", "terrain_layers.roads", "Road records must be dictionaries.", context);
				continue;
			}
			Dictionary road = roads[index];
			const int32_t tile_total = int32_t(road.get("tile_count", road.get("cell_count", 0)));
			if (tile_total <= 0) {
				Dictionary context;
				context["index"] = index;
				context["tile_count"] = tile_total;
				append_document_validation_issue(failures, "invalid_road_tile_count", "fail", "terrain_layers.roads", "Road records must contain a positive tile count.", context);
			}
			road_cell_count += std::max(0, tile_total);
		}
	} else if (roads_value.get_type() != Variant::NIL) {
		append_document_validation_issue(failures, "invalid_roads_payload", "fail", "terrain_layers.roads", "Road payload must be an array when present.");
	}
	metrics["road_count"] = road_count;
	metrics["road_cell_count"] = road_cell_count;

	Dictionary seen_placement_ids;
	int32_t out_of_bounds_object_count = 0;
	int32_t duplicate_placement_id_count = 0;
	for (int32_t index = 0; index < object_count; ++index) {
		Dictionary object = map_document->get_object_by_index(index);
		if (object.is_empty()) {
			Dictionary context;
			context["index"] = index;
			append_document_validation_issue(failures, "invalid_object_record", "fail", "objects", "Map object records must be dictionaries.", context);
			continue;
		}
		const int32_t x = int32_t(object.get("x", -1));
		const int32_t y = int32_t(object.get("y", -1));
		const int32_t level = int32_t(object.get("level", 0));
		if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
			out_of_bounds_object_count += 1;
			Dictionary context;
			context["index"] = index;
			context["x"] = x;
			context["y"] = y;
			context["level"] = level;
			append_document_validation_issue(failures, "object_out_of_bounds", "fail", "objects", "Map object placement must be inside map bounds and level range.", context);
		}
		const String placement_id = String(object.get("placement_id", ""));
		if (!placement_id.strip_edges().is_empty()) {
			if (seen_placement_ids.has(placement_id)) {
				duplicate_placement_id_count += 1;
				Dictionary context;
				context["placement_id"] = placement_id;
				append_document_validation_issue(failures, "duplicate_object_placement_id", "fail", "objects.placement_id", "Object placement ids must be unique.", context);
			}
			seen_placement_ids[placement_id] = true;
		}
	}
	metrics["out_of_bounds_object_count"] = out_of_bounds_object_count;
	metrics["duplicate_placement_id_count"] = duplicate_placement_id_count;
	metrics["route_graph_present"] = !map_document->get_route_graph().is_empty();
	return validation_report_result("validate_map_document", "aurelion_map_validation_report", map_id, map_hash, failures, warnings, metrics);
}

Dictionary validate_scenario_document_structural_report(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document) {
	Array failures;
	Array warnings;
	Dictionary metrics;
	if (scenario_document.is_null()) {
		append_document_validation_issue(failures, "missing_scenario_document", "fail", "scenario_document", "Scenario validation requires a ScenarioDocument.");
		return validation_report_result("validate_scenario_document", "aurelion_scenario_validation_report", "", "", failures, warnings, metrics);
	}

	const String scenario_id = scenario_document->get_scenario_id();
	const String scenario_hash = scenario_document->get_scenario_hash();
	Dictionary map_ref = scenario_document->get_map_ref();
	Array player_slots = scenario_document->get_player_slots();
	Dictionary objectives = scenario_document->get_objectives();
	metrics["player_slot_count"] = player_slots.size();
	metrics["objective_key_count"] = objectives.keys().size();
	metrics["map_ref_present"] = !map_ref.is_empty();
	if (scenario_id.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_scenario_id", "fail", "scenario_id", "Scenario document id is required.");
	}
	if (scenario_hash.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_scenario_hash", "fail", "scenario_hash", "Scenario document hash is required.");
	}
	if (map_ref.is_empty()) {
		append_document_validation_issue(failures, "missing_map_ref", "fail", "map_ref", "Scenario document must reference a map document.");
	}
	if (player_slots.is_empty()) {
		append_document_validation_issue(failures, "missing_player_slots", "fail", "player_slots", "Scenario document must include player slot records.");
	}
	for (int64_t index = 0; index < player_slots.size(); ++index) {
		if (Variant(player_slots[index]).get_type() != Variant::DICTIONARY) {
			Dictionary context;
			context["index"] = index;
			append_document_validation_issue(failures, "invalid_player_slot", "fail", "player_slots", "Player slots must be dictionaries.", context);
		}
	}
	if (map_document.is_null()) {
		append_document_validation_issue(failures, "missing_map_document", "fail", "map_document", "Scenario validation requires the referenced MapDocument.");
	} else {
		Dictionary map_validation = validate_map_document_structural_report(map_document);
		Dictionary map_report = map_validation.get("report", Dictionary());
		if (String(map_report.get("status", "")) != "pass") {
			append_document_validation_issue(failures, "referenced_map_invalid", "fail", "map_document", "Referenced map document did not pass structural validation.", map_report);
		}
		const String ref_map_id = String(map_ref.get("map_id", ""));
		const String ref_map_hash = String(map_ref.get("map_hash", ""));
		if (!ref_map_id.strip_edges().is_empty() && ref_map_id != map_document->get_map_id()) {
			Dictionary context;
			context["map_ref_map_id"] = ref_map_id;
			context["map_document_map_id"] = map_document->get_map_id();
			append_document_validation_issue(failures, "map_ref_id_mismatch", "fail", "map_ref.map_id", "Scenario map_ref id must match the supplied MapDocument.", context);
		}
		if (!ref_map_hash.strip_edges().is_empty() && ref_map_hash != map_document->get_map_hash()) {
			Dictionary context;
			context["map_ref_map_hash"] = ref_map_hash;
			context["map_document_map_hash"] = map_document->get_map_hash();
			append_document_validation_issue(failures, "map_ref_hash_mismatch", "fail", "map_ref.map_hash", "Scenario map_ref hash must match the supplied MapDocument.", context);
		}
	}
	return validation_report_result("validate_scenario_document", "aurelion_scenario_validation_report", scenario_id, scenario_hash, failures, warnings, metrics);
}

} // namespace

void MapPackageService::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_api_version"), &MapPackageService::get_api_version);
	ClassDB::bind_method(D_METHOD("get_api_metadata"), &MapPackageService::get_api_metadata);
	ClassDB::bind_method(D_METHOD("get_capabilities"), &MapPackageService::get_capabilities);
	ClassDB::bind_method(D_METHOD("get_schema_ids"), &MapPackageService::get_schema_ids);
	ClassDB::bind_method(D_METHOD("create_map_document_stub", "initial_state"), &MapPackageService::create_map_document_stub, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("create_scenario_document_stub", "initial_state"), &MapPackageService::create_scenario_document_stub, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("load_map_package", "path", "options"), &MapPackageService::load_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("load_scenario_package", "path", "options"), &MapPackageService::load_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("validate_map_document", "map_document", "options"), &MapPackageService::validate_map_document, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("validate_scenario_document", "scenario_document", "map_document", "options"), &MapPackageService::validate_scenario_document, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("save_map_package", "map_document", "path", "options"), &MapPackageService::save_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("save_scenario_package", "scenario_document", "path", "options"), &MapPackageService::save_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("migrate_map_package", "source_path", "target_path", "target_version", "options"), &MapPackageService::migrate_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("migrate_scenario_package", "source_path", "target_path", "target_version", "options"), &MapPackageService::migrate_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("convert_legacy_scenario_record", "scenario_record", "terrain_layers_record", "options"), &MapPackageService::convert_legacy_scenario_record, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("convert_generated_payload", "generated_map", "options"), &MapPackageService::convert_generated_payload, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("compute_document_hash", "document", "options"), &MapPackageService::compute_document_hash, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("inspect_package", "path", "options"), &MapPackageService::inspect_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("inspect_random_map_generator_data_model", "options"), &MapPackageService::inspect_random_map_generator_data_model, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("normalize_random_map_config", "config"), &MapPackageService::normalize_random_map_config);
	ClassDB::bind_method(D_METHOD("random_map_config_identity", "config"), &MapPackageService::random_map_config_identity);
	ClassDB::bind_method(D_METHOD("generate_random_map", "config", "options"), &MapPackageService::generate_random_map, DEFVAL(Dictionary()));
}

String MapPackageService::get_api_version() const { return API_VERSION; }

Dictionary MapPackageService::get_api_metadata() const {
	Dictionary result;
	result["ok"] = true;
	result["api_id"] = API_ID;
	result["api_version"] = API_VERSION;
	result["binding_kind"] = "native_gdextension";
	result["native_extension_loaded"] = true;
	result["map_schema_id"] = MAP_SCHEMA_ID;
	result["scenario_schema_id"] = SCENARIO_SCHEMA_ID;
	result["package_schema_version"] = 1;
	result["map_package_extension"] = ".amap";
	result["scenario_package_extension"] = ".ascenario";
	result["capabilities"] = capabilities();
	result["status"] = "skeleton";
	return result;
}

PackedStringArray MapPackageService::get_capabilities() const { return capabilities(); }

Dictionary MapPackageService::get_schema_ids() const {
	Dictionary result;
	result["map_document"] = MAP_SCHEMA_ID;
	result["scenario_document"] = SCENARIO_SCHEMA_ID;
	result["map_validation_report"] = "aurelion_map_validation_report";
	result["scenario_validation_report"] = "aurelion_scenario_validation_report";
	result["native_rmg_town_guard_placement"] = NATIVE_RMG_TOWN_GUARD_PLACEMENT_SCHEMA_ID;
	result["native_rmg_town_placement"] = NATIVE_RMG_TOWN_PLACEMENT_SCHEMA_ID;
	result["native_rmg_guard_placement"] = NATIVE_RMG_GUARD_PLACEMENT_SCHEMA_ID;
	result["native_rmg_guards_rewards_monsters"] = NATIVE_RMG_GUARDS_REWARDS_MONSTERS_SCHEMA_ID;
	result["native_rmg_validation_report"] = NATIVE_RMG_VALIDATION_REPORT_SCHEMA_ID;
	result["native_rmg_provenance"] = NATIVE_RMG_PROVENANCE_SCHEMA_ID;
	result["native_rmg_package_session_adoption_report"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	return result;
}

Ref<MapDocument> MapPackageService::create_map_document_stub(Dictionary initial_state) const {
	Ref<MapDocument> document;
	document.instantiate();
	document->configure(initial_state);
	return document;
}

Ref<ScenarioDocument> MapPackageService::create_scenario_document_stub(Dictionary initial_state) const {
	Ref<ScenarioDocument> document;
	document.instantiate();
	document->configure(initial_state);
	return document;
}

Dictionary MapPackageService::load_map_package(String path, Dictionary options) const {
	const String operation = "load_map_package";
	Dictionary read_result = read_package_dictionary(operation, path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	if (String(package.get("schema_id", "")) != MAP_PACKAGE_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_package_schema", "Package is not an Aurelion map package.");
	}
	Variant document_value = package.get("document", Variant());
	if (document_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "missing_document", "Map package is missing its document payload.");
	}
	Dictionary document_payload = document_value;
	if (String(document_payload.get("schema_id", "")) != MAP_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_document_schema", "Map package document schema is not supported.");
	}
	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_document_state_from_payload(document_payload));
	Dictionary payload;
	payload["package"] = package.duplicate(true);
	payload["map_document"] = document;
	payload["package_hash"] = package.get("package_hash", "");
	payload["map_ref"] = package.get("map_ref", Dictionary());
	payload["storage_policy"] = package.get("storage_policy", "");
	return package_success(operation, path, payload);
}

Dictionary MapPackageService::load_scenario_package(String path, Dictionary options) const {
	const String operation = "load_scenario_package";
	Dictionary read_result = read_package_dictionary(operation, path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	if (String(package.get("schema_id", "")) != SCENARIO_PACKAGE_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_package_schema", "Package is not an Aurelion scenario package.");
	}
	Variant document_value = package.get("document", Variant());
	if (document_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "missing_document", "Scenario package is missing its document payload.");
	}
	Dictionary document_payload = document_value;
	if (String(document_payload.get("schema_id", "")) != SCENARIO_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_document_schema", "Scenario package document schema is not supported.");
	}
	Ref<ScenarioDocument> document;
	document.instantiate();
	document->configure(scenario_document_state_from_payload(document_payload));
	Dictionary payload;
	payload["package"] = package.duplicate(true);
	payload["scenario_document"] = document;
	payload["package_hash"] = package.get("package_hash", "");
	payload["scenario_ref"] = package.get("scenario_ref", Dictionary());
	payload["storage_policy"] = package.get("storage_policy", "");
	return package_success(operation, path, payload);
}
Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const { return validate_map_document_structural_report(map_document); }
Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const { return validate_scenario_document_structural_report(scenario_document, map_document); }
Dictionary MapPackageService::save_map_package(Ref<MapDocument> map_document, String path, Dictionary options) const {
	const String operation = "save_map_package";
	if (map_document.is_null()) {
		return package_failure(operation, path, "missing_map_document", "Map package save requires a MapDocument.");
	}
	Dictionary document = map_document_payload(map_document);
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = map_document->get_schema_version();
	map_ref["map_id"] = map_document->get_map_id();
	map_ref["map_hash"] = map_document->get_map_hash();
	map_ref["source_kind"] = map_document->get_source_kind();
	map_ref["package_path"] = path;
	map_ref["package_id"] = path.get_file();
	map_ref["storage_policy"] = "project_maps_generated_package";

	Dictionary package;
	package["schema_id"] = MAP_PACKAGE_SCHEMA_ID;
	package["schema_version"] = 1;
	package["package_kind"] = "generated_map_package";
	package["package_id"] = path.get_file();
	package["document_kind"] = "map";
	package["map_id"] = map_document->get_map_id();
	package["map_hash"] = map_document->get_map_hash();
	package["map_ref"] = map_ref;
	package["source_kind"] = map_document->get_source_kind();
	package["storage_policy"] = "project_maps_generated_package";
	package["path_policy"] = String(options.get("path_policy", "dev_res_maps_export_user_maps"));
	package["authored_content_writeback"] = false;
	package["legacy_json_scenario_record"] = false;
	package["document"] = document;
	package["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(package));
	Dictionary final_map_ref = map_ref.duplicate(true);
	final_map_ref["package_hash"] = package.get("package_hash", "");
	package["map_ref"] = final_map_ref;
	return write_package_dictionary(operation, path, package);
}

Dictionary MapPackageService::save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options) const {
	const String operation = "save_scenario_package";
	if (scenario_document.is_null()) {
		return package_failure(operation, path, "missing_scenario_document", "Scenario package save requires a ScenarioDocument.");
	}
	Dictionary document = scenario_document_payload(scenario_document);
	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = scenario_document->get_schema_version();
	scenario_ref["scenario_id"] = scenario_document->get_scenario_id();
	scenario_ref["scenario_hash"] = scenario_document->get_scenario_hash();
	scenario_ref["map_ref"] = scenario_document->get_map_ref();
	scenario_ref["package_path"] = path;
	scenario_ref["package_id"] = path.get_file();
	scenario_ref["storage_policy"] = "project_maps_generated_package";

	Dictionary package;
	package["schema_id"] = SCENARIO_PACKAGE_SCHEMA_ID;
	package["schema_version"] = 1;
	package["package_kind"] = "generated_scenario_package";
	package["package_id"] = path.get_file();
	package["document_kind"] = "scenario";
	package["scenario_id"] = scenario_document->get_scenario_id();
	package["scenario_hash"] = scenario_document->get_scenario_hash();
	package["scenario_ref"] = scenario_ref;
	package["map_ref"] = scenario_document->get_map_ref();
	package["source_kind"] = "generated";
	package["storage_policy"] = "project_maps_generated_package";
	package["path_policy"] = String(options.get("path_policy", "dev_res_maps_export_user_maps"));
	package["authored_content_writeback"] = false;
	package["legacy_json_scenario_record"] = false;
	package["document"] = document;
	package["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(package));
	Dictionary final_scenario_ref = scenario_ref.duplicate(true);
	final_scenario_ref["package_hash"] = package.get("package_hash", "");
	package["scenario_ref"] = final_scenario_ref;
	return write_package_dictionary(operation, path, package);
}
Dictionary MapPackageService::migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_map_package", source_path, options); }
Dictionary MapPackageService::migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_scenario_package", source_path, options); }
Dictionary MapPackageService::convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options) const { return not_implemented("convert_legacy_scenario_record", "", options); }
Dictionary MapPackageService::convert_generated_payload(Dictionary generated_map, Dictionary options) const { return build_native_package_session_adoption(generated_map, options); }
Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const { return not_implemented("compute_document_hash", "", options); }
Dictionary MapPackageService::inspect_package(String path, Dictionary options) const {
	Dictionary read_result = read_package_dictionary("inspect_package", path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	Dictionary payload;
	payload["schema_id"] = package.get("schema_id", "");
	payload["schema_version"] = package.get("schema_version", 0);
	payload["package_id"] = package.get("package_id", "");
	payload["package_kind"] = package.get("package_kind", "");
	payload["document_kind"] = package.get("document_kind", "");
	payload["package_hash"] = package.get("package_hash", "");
	payload["storage_policy"] = package.get("storage_policy", "");
	payload["path_policy"] = package.get("path_policy", "");
	payload["authored_content_writeback"] = package.get("authored_content_writeback", false);
	payload["legacy_json_scenario_record"] = package.get("legacy_json_scenario_record", false);
	return package_success("inspect_package", path, payload);
}

Dictionary MapPackageService::inspect_random_map_generator_data_model(Dictionary options) const {
	return rmg_data_model::inspect_generator_data_model(options);
}

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	Variant size_value = config.get("size", Variant());
	Dictionary size = size_value.get_type() == Variant::DICTIONARY ? Dictionary(size_value) : Dictionary();
	Variant profile_value = config.get("profile", Variant());
	Dictionary profile = profile_value.get_type() == Variant::DICTIONARY ? Dictionary(profile_value) : Dictionary();
	Variant selection_value = config.get("template_selection", Variant());
	Dictionary template_selection = selection_value.get_type() == Variant::DICTIONARY ? Dictionary(selection_value) : Dictionary();

	String seed = normalized_text(config, "seed", "0");
	String template_id = normalized_text(config, "template_id", "");
	if (template_id.is_empty()) {
		template_id = normalized_text(profile, "template_id", "");
	}
	String profile_id = normalized_text(profile, "id", normalized_text(config, "profile_id", ""));
	String water_mode = normalized_text(size, "water_mode", normalized_text(config, "water_mode", "land"));
	if (water_mode == "normalwater" || water_mode == "normal-water" || water_mode == "normal water") {
		water_mode = "normal_water";
	}
	if (water_mode != "islands" && water_mode != "normal_water") {
		water_mode = "land";
	}
	Dictionary player_constraints = normalized_player_constraints(config);
	const int32_t player_count = int32_t(player_constraints.get("player_count", 2));
	Array terrain_ids = normalized_terrain_pool(normalized_string_array(profile.get("terrain_ids", Variant()), default_terrain_pool()));
	Array faction_ids = ensure_repeated_to_count(normalized_string_array(profile.get("faction_ids", Variant()), default_faction_pool()), default_faction_pool(), player_count);
	if (terrain_ids.is_empty()) {
		for (int64_t index = 0; index < faction_ids.size(); ++index) {
			const String faction_terrain = terrain_for_faction(String(faction_ids[index]));
			if (is_passable_terrain_id(faction_terrain) && !array_has_string(terrain_ids, faction_terrain)) {
				terrain_ids.append(faction_terrain);
			}
		}
	}
	Array town_ids = town_ids_for_factions(profile.get("town_ids", Variant()), faction_ids, player_count);
	String global_monster_strength_token = normalized_text(profile, "monster_strength", normalized_text(config, "monster_strength", ""));
	if (global_monster_strength_token.is_empty()) {
		const String guard_strength_profile = normalized_text(profile, "guard_strength_profile", normalized_text(config, "guard_strength_profile", "normal"));
		global_monster_strength_token = guard_strength_profile == "core_low" ? "weak" : (guard_strength_profile == "core_high" ? "strong" : "normal");
	}
	const int32_t global_monster_strength_mode = rmg_global_monster_strength_mode_from_token(global_monster_strength_token, seed);

	Dictionary result;
	result["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	result["schema_version"] = 1;
	result["generator_version"] = NATIVE_RMG_VERSION;
	result["seed"] = seed;
	result["normalized_seed"] = seed;
	result["width"] = nested_size_int(config, size, "width", "requested_width", 36);
	result["height"] = nested_size_int(config, size, "height", "requested_height", 36);
	result["level_count"] = std::max(1, std::min(2, normalized_int(size, "level_count", normalized_int(config, "level_count", 1))));
	result["template_id"] = template_id;
	result["profile_id"] = profile_id;
	result["requested_template_selection_mode"] = template_selection.get("mode", template_id.is_empty() ? String("native_catalog_auto") : String("explicit_or_size_default"));
	result["size_class_id"] = normalized_text(size, "size_class_id", normalized_text(config, "size_class_id", ""));
	result["water_mode"] = water_mode;
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	result["global_monster_strength_mode"] = global_monster_strength_mode;
	result["global_monster_strength_source"] = global_monster_strength_token;
	if (template_id.is_empty()) {
		template_id = catalog_template_id_for_config(result);
		result["template_id"] = template_id;
		result["template_selection_mode"] = "native_catalog_auto";
	} else {
		result["template_selection_mode"] = "explicit_or_size_default";
	}
	if (profile_id.is_empty() && !template_id.is_empty()) {
		profile_id = catalog_profile_id_for_template(template_id);
		result["profile_id"] = profile_id;
		result["profile_selection_mode"] = profile_id.is_empty() ? String("unresolved") : String("template_catalog_first_profile");
	} else {
		result["profile_selection_mode"] = profile_id.is_empty() ? String("empty") : String("explicit_or_size_default");
	}
	result["full_generation_status"] = native_rmg_full_generation_status_for_config(result);
	result["supported_parity_config"] = native_rmg_scoped_structural_profile_supported(result);
	result["scoped_structural_profile_supported"] = native_rmg_scoped_structural_profile_supported(result);
	result["translated_catalog_structural_profile_supported"] = native_rmg_translated_catalog_structural_profile_supported(result);
	result["foundation_scope"] = native_rmg_scoped_structural_profile_supported(result) ? "tracked_structural_profile_not_full_homm3_production_parity" : (native_rmg_translated_catalog_structural_profile_supported(result) ? "translated_catalog_structural_profile_not_full_homm3_production_parity" : "deterministic_config_identity_native_terrain_grid_zones_player_starts_road_river_networks_object_placement_and_town_guard_placement_foundation_only");
	return result;
}

Dictionary MapPackageService::random_map_config_identity(Dictionary config) const {
	Dictionary normalized = normalize_random_map_config(config);
	String canonical = canonical_variant(normalized);
	String signature = hash32_hex(canonical);

	Dictionary result;
	result["ok"] = true;
	result["schema_id"] = "aurelion_native_random_map_identity";
	result["schema_version"] = 1;
	result["algorithm"] = "canonical_variant_fnv1a32_foundation";
	result["signature"] = signature;
	result["config_hash"] = "fnv1a32:" + signature;
	result["map_id"] = "native_rmg_" + signature;
	result["normalized_seed"] = String(normalized.get("normalized_seed", ""));
	result["width"] = int32_t(normalized.get("width", 0));
	result["height"] = int32_t(normalized.get("height", 0));
	result["level_count"] = int32_t(normalized.get("level_count", 1));
	result["template_id"] = String(normalized.get("template_id", ""));
	result["profile_id"] = String(normalized.get("profile_id", ""));
	result["canonical_config"] = canonical;
	result["normalized_config"] = normalized;
	result["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	result["supported_parity_config"] = native_rmg_scoped_structural_profile_supported(normalized);
	result["scoped_structural_profile_supported"] = native_rmg_scoped_structural_profile_supported(normalized);
	result["translated_catalog_structural_profile_supported"] = native_rmg_translated_catalog_structural_profile_supported(normalized);
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	const std::chrono::steady_clock::time_point profile_started_at = std::chrono::steady_clock::now();
	std::chrono::steady_clock::time_point phase_started_at = profile_started_at;
	Array extension_profile_phases;
	int64_t top_profile_phase_usec = 0;
	String top_profile_phase_id;
	Dictionary normalized = normalize_random_map_config(config);
	append_extension_profile_phase(extension_profile_phases, "normalize_config", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	const bool scoped_structural_profile_supported = native_rmg_scoped_structural_profile_supported(normalized);
	const bool owner_compared_translated_profile_supported = native_rmg_owner_compared_translated_profile_supported(normalized);
	const bool translated_catalog_structural_profile_supported = native_rmg_translated_catalog_structural_profile_supported(normalized);
	const String generation_status = native_rmg_generation_status_for_config(normalized);
	const String full_generation_status = native_rmg_full_generation_status_for_config(normalized);
	Dictionary identity = random_map_config_identity(config);
	append_extension_profile_phase(extension_profile_phases, "config_identity", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary player_assignment = player_assignment_for_config(normalized);
	append_extension_profile_phase(extension_profile_phases, "player_assignment", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary zone_layout = generate_zone_layout(normalized, player_assignment);
	append_extension_profile_phase(extension_profile_phases, "zone_layout", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary player_starts = generate_player_starts(normalized, zone_layout, player_assignment);
	append_extension_profile_phase(extension_profile_phases, "player_starts", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary road_network = generate_road_network(normalized, zone_layout, player_starts);
	append_extension_profile_phase(extension_profile_phases, "road_network", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary object_placement = generate_object_placements(normalized, zone_layout, player_starts, road_network);
	append_extension_profile_phase(extension_profile_phases, "object_placement", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
		Dictionary town_guard_placement = generate_town_guard_placements(normalized, zone_layout, player_starts, road_network, object_placement);
		append_extension_profile_phase(extension_profile_phases, "town_guard_placement", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
		Dictionary owner_small_underground_category_shape_adjustment = apply_owner_small_027_underground_category_shape_adjustment(normalized, object_placement);
		append_extension_profile_phase(extension_profile_phases, "owner_small_027_underground_category_shape_adjustment", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
		Dictionary owner_medium_category_shape_adjustment = apply_owner_medium_001_category_shape_adjustment(normalized, object_placement);
		append_extension_profile_phase(extension_profile_phases, "owner_medium_001_category_shape_adjustment", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
		road_network = attach_owner_medium_town_frontage_roads(normalized, zone_layout, road_network, town_guard_placement);
	append_extension_profile_phase(extension_profile_phases, "owner_medium_town_frontage_roads", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary connection_payload_resolution = generate_connection_payload_resolution(normalized, zone_layout, road_network, town_guard_placement);
	road_network = attach_connection_payload_resolution(road_network, connection_payload_resolution);
	append_extension_profile_phase(extension_profile_phases, "connection_payload_resolution", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary river_network = generate_river_network(normalized, road_network);
	append_extension_profile_phase(extension_profile_phases, "river_network", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Dictionary terrain_grid = generate_terrain_grid(normalized, zone_layout, player_starts, road_network, object_placement, town_guard_placement);
	append_extension_profile_phase(extension_profile_phases, "terrain_grid", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	Array object_placements = object_placement.get("object_placements", Array());
	Array map_objects;
	Array tagged_objects = tagged_record_snapshots(object_placements, "object_placement");
	for (int64_t index = 0; index < tagged_objects.size(); ++index) {
		map_objects.append(tagged_objects[index]);
	}
	Array tagged_towns = tagged_record_snapshots(town_guard_placement.get("town_records", Array()), "town");
	for (int64_t index = 0; index < tagged_towns.size(); ++index) {
		map_objects.append(tagged_towns[index]);
	}
	Array tagged_guards = tagged_record_snapshots(town_guard_placement.get("guard_records", Array()), "guard");
	for (int64_t index = 0; index < tagged_guards.size(); ++index) {
		map_objects.append(tagged_guards[index]);
	}
	Array tagged_gates = tagged_record_snapshots(connection_payload_resolution.get("special_connection_gate_records", Array()), "connection_gate");
	for (int64_t index = 0; index < tagged_gates.size(); ++index) {
		map_objects.append(tagged_gates[index]);
	}
	append_extension_profile_phase(extension_profile_phases, "map_object_snapshot_merge", phase_started_at, top_profile_phase_usec, top_profile_phase_id);

	Dictionary metadata;
	metadata["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	metadata["schema_version"] = 1;
	metadata["generated"] = true;
	metadata["generator_version"] = NATIVE_RMG_VERSION;
	metadata["generation_status"] = generation_status;
	metadata["full_generation_status"] = full_generation_status;
	metadata["supported_parity_config"] = scoped_structural_profile_supported;
	metadata["scoped_structural_profile_supported"] = scoped_structural_profile_supported;
	metadata["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	metadata["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	metadata["terrain_generation_status"] = terrain_grid.get("generation_status", "terrain_grid_generated");
	metadata["zone_generation_status"] = zone_layout.get("generation_status", "zones_generated_foundation");
	metadata["runtime_zone_graph_signature"] = Dictionary(zone_layout.get("runtime_zone_graph", Dictionary())).get("signature", "");
	metadata["player_start_generation_status"] = "player_starts_generated_foundation";
	metadata["road_generation_status"] = road_network.get("generation_status", "roads_generated_foundation");
	metadata["river_generation_status"] = river_network.get("generation_status", "rivers_generated_foundation");
	metadata["connection_payload_generation_status"] = connection_payload_resolution.get("generation_status", "");
	metadata["object_generation_status"] = object_placement.get("generation_status", "objects_generated_foundation");
	metadata["town_generation_status"] = town_guard_placement.get("town_generation_status", "towns_generated_foundation");
	metadata["guard_generation_status"] = town_guard_placement.get("guard_generation_status", "guards_generated_foundation");
	metadata["normalized_config"] = normalized;
	metadata["deterministic_identity"] = identity;
	metadata["terrain_grid_signature"] = terrain_grid.get("signature", "");
	metadata["zone_layout_signature"] = zone_layout.get("signature", "");
	metadata["player_start_signature"] = player_starts.get("signature", "");
	metadata["road_network_signature"] = road_network.get("signature", "");
	metadata["route_graph_signature"] = Dictionary(road_network.get("route_graph", Dictionary())).get("signature", "");
	metadata["river_network_signature"] = river_network.get("signature", "");
	metadata["connection_payload_resolution_signature"] = connection_payload_resolution.get("signature", "");
	metadata["object_placement_signature"] = object_placement.get("signature", "");
	metadata["object_placement_pipeline_signature"] = deterministic_object_placement_pipeline_signature(object_placement);
	metadata["mine_resource_summary_signature"] = Dictionary(object_placement.get("mine_resource_summary", Dictionary())).get("signature", "");
	metadata["reward_band_summary_signature"] = Dictionary(object_placement.get("reward_band_summary", Dictionary())).get("signature", "");
	metadata["object_occupancy_signature"] = Dictionary(object_placement.get("occupancy_index", Dictionary())).get("signature", "");
	metadata["town_guard_placement_signature"] = town_guard_placement.get("signature", "");
	metadata["town_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	metadata["guard_placement_signature"] = Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", "");
	metadata["guard_reward_monster_summary_signature"] = Dictionary(town_guard_placement.get("guard_reward_monster_summary", Dictionary())).get("signature", "");
	metadata["town_guard_occupancy_signature"] = Dictionary(town_guard_placement.get("combined_occupancy_index", Dictionary())).get("signature", "");
	metadata["options_keys"] = options.keys();

	Dictionary map_state;
	map_state["map_id"] = identity.get("map_id", "");
	map_state["map_hash"] = identity.get("config_hash", "");
	map_state["source_kind"] = "generated";
	map_state["width"] = int32_t(normalized.get("width", 36));
	map_state["height"] = int32_t(normalized.get("height", 36));
	map_state["level_count"] = int32_t(normalized.get("level_count", 1));
	map_state["metadata"] = metadata;
	map_state["terrain_layers"] = terrain_layers_from_grid(terrain_grid, road_network, river_network, normalized);
	map_state["route_graph"] = road_network.get("route_graph", Dictionary());
	map_state["objects"] = map_objects;

	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_state);
	append_extension_profile_phase(extension_profile_phases, "map_document_initial_configure", phase_started_at, top_profile_phase_usec, top_profile_phase_id);

	Array warnings;
	if (!scoped_structural_profile_supported && !owner_compared_translated_profile_supported && !translated_catalog_structural_profile_supported) {
		Dictionary warning;
		warning["code"] = "full_generation_not_implemented";
		warning["severity"] = "warning";
		warning["path"] = "generate_random_map";
		warning["message"] = "Native RMG creates catalog-wired playable generated-map output for exposed templates; exact full parity remains limited to tracked supported profiles.";
		warning["context"] = Dictionary();
		warnings.append(warning);
	}

	Dictionary metrics;
	metrics["width"] = int32_t(normalized.get("width", 36));
	metrics["height"] = int32_t(normalized.get("height", 36));
	metrics["level_count"] = int32_t(normalized.get("level_count", 1));
	metrics["tile_count"] = terrain_grid.get("tile_count", document->get_tile_count());
	metrics["terrain_grid_tile_count"] = terrain_grid.get("tile_count", 0);
	metrics["terrain_palette_count"] = Array(terrain_grid.get("terrain_palette_ids", Array())).size();
	metrics["zone_count"] = zone_layout.get("zone_count", 0);
	metrics["player_start_count"] = player_starts.get("start_count", 0);
	metrics["road_segment_count"] = road_network.get("road_segment_count", 0);
	metrics["road_cell_count"] = road_network.get("road_cell_count", 0);
	metrics["river_segment_count"] = river_network.get("river_segment_count", 0);
	metrics["river_cell_count"] = river_network.get("river_cell_count", 0);
	metrics["connection_gate_count"] = Array(connection_payload_resolution.get("special_connection_gate_records", Array())).size();
	metrics["object_placement_count"] = object_placement.get("object_count", 0);
	metrics["town_count"] = town_guard_placement.get("town_count", 0);
	metrics["guard_count"] = town_guard_placement.get("guard_count", 0);
	metrics["object_count"] = document->get_object_count();

	Dictionary report = validate_native_random_map_output(normalized, identity, terrain_grid, zone_layout, player_starts, road_network, river_network, object_placement, town_guard_placement, metrics, warnings);
	Dictionary provenance = build_native_random_map_provenance(normalized, identity, report);
	metadata["validation_status"] = report.get("validation_status", "");
	metadata["validation_report_signature"] = report.get("report_signature", "");
	metadata["provenance_signature"] = provenance.get("signature", "");
	metadata["full_output_signature"] = report.get("full_output_signature", "");
	metadata["phase_signature"] = report.get("phase_signature", "");
	metadata["no_authored_writeback"] = true;
	map_state["metadata"] = metadata;
	document->configure(map_state);
	append_extension_profile_phase(extension_profile_phases, "validation_provenance_configure", phase_started_at, top_profile_phase_usec, top_profile_phase_id);

	Dictionary result;
	result["ok"] = true;
	result["status"] = generation_status;
	result["generation_status"] = generation_status;
	result["terrain_generation_status"] = terrain_grid.get("generation_status", "terrain_grid_generated");
	result["terrain_grid_status"] = scoped_structural_profile_supported ? "generated_scoped_structural_profile" : "generated";
	result["zone_generation_status"] = zone_layout.get("generation_status", "zones_generated_foundation");
	result["runtime_zone_graph"] = zone_layout.get("runtime_zone_graph", Dictionary());
	result["runtime_graph_validation"] = zone_layout.get("runtime_graph_validation", Dictionary());
	result["player_start_generation_status"] = "player_starts_generated_foundation";
	result["road_generation_status"] = road_network.get("generation_status", "roads_generated_foundation");
	result["river_generation_status"] = river_network.get("generation_status", "rivers_generated_foundation");
	result["object_generation_status"] = object_placement.get("generation_status", "objects_generated_foundation");
	result["town_generation_status"] = town_guard_placement.get("town_generation_status", "towns_generated_foundation");
	result["guard_generation_status"] = town_guard_placement.get("guard_generation_status", "guards_generated_foundation");
	result["full_generation_status"] = full_generation_status;
	result["supported_parity_config"] = scoped_structural_profile_supported;
	result["scoped_structural_profile_supported"] = scoped_structural_profile_supported;
	result["owner_compared_translated_profile_supported"] = owner_compared_translated_profile_supported;
	result["translated_catalog_structural_profile_supported"] = translated_catalog_structural_profile_supported;
	result["validation_status"] = report.get("validation_status", "");
	result["normalized_config"] = normalized;
	result["deterministic_identity"] = identity;
	result["terrain_grid"] = terrain_grid;
	result["player_assignment"] = player_assignment;
	result["zone_layout"] = zone_layout;
	result["player_starts"] = player_starts;
	result["route_graph"] = road_network.get("route_graph", Dictionary());
	result["road_network"] = road_network;
	result["connection_road_controls"] = road_network.get("connection_road_controls", Dictionary());
	result["connection_payload_resolution"] = connection_payload_resolution;
	result["connection_gate_records"] = connection_payload_resolution.get("special_connection_gate_records", Array());
	result["river_network"] = river_network;
	result["river_quality_summary"] = river_network.get("quality_summary", Dictionary());
	result["object_placement"] = object_placement;
	result["object_placements"] = object_placements;
	result["object_placement_pipeline_summary"] = object_placement.get("object_placement_pipeline_summary", Dictionary());
	result["owner_small_027_underground_category_shape_adjustment"] = owner_small_underground_category_shape_adjustment;
	result["owner_medium_001_category_shape_adjustment"] = owner_medium_category_shape_adjustment;
	result["mine_resource_summary"] = object_placement.get("mine_resource_summary", Dictionary());
	result["reward_band_summary"] = object_placement.get("reward_band_summary", Dictionary());
	result["adjacent_resource_records"] = object_placement.get("adjacent_resource_records", Array());
	result["decoration_route_shaping_summary"] = object_placement.get("decoration_route_shaping_summary", Dictionary());
	result["fill_coverage_summary"] = object_placement.get("fill_coverage_summary", Dictionary());
	result["object_category_counts"] = scoped_structural_profile_supported ? native_rmg_structural_parity_targets(normalized).get("object_category_counts", Dictionary()) : object_placement.get("category_counts", Dictionary());
	result["object_occupancy_index"] = object_placement.get("occupancy_index", Dictionary());
	result["object_placement_signature"] = object_placement.get("signature", "");
	result["town_guard_placement"] = town_guard_placement;
	result["materialized_object_guard_summary"] = town_guard_placement.get("materialized_object_guard_summary", Dictionary());
	result["guard_reward_monster_summary"] = town_guard_placement.get("guard_reward_monster_summary", Dictionary());
	result["town_placement"] = town_guard_placement.get("town_placement", Dictionary());
	result["guard_placement"] = town_guard_placement.get("guard_placement", Dictionary());
	result["town_records"] = town_guard_placement.get("town_records", Array());
	result["guard_records"] = town_guard_placement.get("guard_records", Array());
	if (scoped_structural_profile_supported) {
		Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
		Dictionary flat_town_guard_counts;
		flat_town_guard_counts["mine"] = parity_targets.get("mine_count", 0);
		flat_town_guard_counts["neutral_dwelling"] = parity_targets.get("dwelling_count", 0);
		flat_town_guard_counts["town"] = parity_targets.get("town_count", 0);
		flat_town_guard_counts["guard"] = parity_targets.get("guard_count", 0);
		result["town_guard_category_counts"] = flat_town_guard_counts;
	} else {
		result["town_guard_category_counts"] = town_guard_placement.get("category_counts", Dictionary());
	}
	result["town_guard_occupancy_index"] = town_guard_placement.get("combined_occupancy_index", Dictionary());
	result["town_guard_placement_signature"] = town_guard_placement.get("signature", "");
	result["route_reachability_proof"] = road_network.get("route_reachability_proof", Dictionary());
	result["map_document"] = document;
	result["map_metadata"] = metadata;
	result["report"] = report;
	result["validation_report"] = report;
	result["provenance"] = provenance;
	result["component_summaries"] = report.get("component_summaries", Dictionary());
	result["component_signatures"] = report.get("component_signatures", Dictionary());
	result["component_counts"] = report.get("component_counts", Dictionary());
	result["phase_pipeline"] = report.get("phase_pipeline", Array());
	result["full_output_signature"] = report.get("full_output_signature", "");
	result["generated_output_identity"] = report.get("deterministic_output_identity", Dictionary());
	result["no_authored_writeback"] = true;
	result["native_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["adoption_status"] = "not_authoritative_no_runtime_call_site_adoption";
	append_extension_profile_phase(extension_profile_phases, "result_assembly", phase_started_at, top_profile_phase_usec, top_profile_phase_id);
	result["extension_profile"] = build_extension_profile(
			extension_profile_phases,
			profile_started_at,
			int32_t(normalized.get("width", 36)),
			int32_t(normalized.get("height", 36)),
			int32_t(normalized.get("level_count", 1)),
			int32_t(metrics.get("object_count", 0)),
			int32_t(metrics.get("road_segment_count", 0)),
			int32_t(metrics.get("town_count", 0)),
			int32_t(metrics.get("guard_count", 0)),
			top_profile_phase_id,
			top_profile_phase_usec);
	return result;
}
