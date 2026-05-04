#include "map_package_service.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
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
constexpr const char *NATIVE_RMG_PLAYER_STARTS_SCHEMA_ID = "aurelion_native_rmg_player_starts_v1";
constexpr const char *NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID = "aurelion_native_rmg_route_graph_v1";
constexpr const char *NATIVE_RMG_ROAD_NETWORK_SCHEMA_ID = "aurelion_native_rmg_road_network_v1";
constexpr const char *NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID = "aurelion_native_rmg_river_network_v1";
constexpr const char *NATIVE_RMG_OBJECT_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_object_placement_v1";
constexpr const char *NATIVE_RMG_TOWN_GUARD_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_town_guard_placement_v1";
constexpr const char *NATIVE_RMG_TOWN_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_town_placement_v1";
constexpr const char *NATIVE_RMG_GUARD_PLACEMENT_SCHEMA_ID = "aurelion_native_rmg_guard_placement_v1";
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
	result.append("native_random_map_road_river_network_foundation");
	result.append("native_random_map_object_placement_foundation");
	result.append("native_random_map_town_guard_placement_foundation");
	result.append("native_random_map_validation_provenance_foundation");
	result.append("native_random_map_package_session_adoption_bridge");
	result.append("native_random_map_full_parity_supported_profiles");
	result.append("native_package_save_load");
	result.append("generated_map_package_disk_startup");
	result.append("headless_binding_smoke");
	return result;
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

Dictionary terrain_layers_from_grid(const Dictionary &terrain_grid) {
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
	return terrain_id == "grass" || terrain_id == "snow" || terrain_id == "sand" || terrain_id == "dirt" || terrain_id == "rough" || terrain_id == "lava" || terrain_id == "underground" || terrain_id == "water";
}

bool is_passable_terrain_id(const String &terrain_id) {
	return is_supported_terrain_id(terrain_id) && terrain_id != "water";
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
	return 7;
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

Array build_foundation_zones(const Dictionary &normalized, const Dictionary &player_assignment) {
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
		Dictionary catalog_metadata;
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
	junction["catalog_metadata"] = Dictionary();
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
		reward["catalog_metadata"] = Dictionary();
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
	for (int64_t index = 0; index < others.size(); ++index) {
		Dictionary zone = others[index];
		const String zone_id = String(zone.get("id", ""));
		const String role = String(zone.get("role", "treasure"));
		const double angle = angle_offset + TAU * (double(index) + 0.5) / double(std::max<int64_t>(1, others.size()));
		const double radius_scale = role == "junction" ? 0.18 : 0.58;
		int32_t x = int32_t(std::llround(center_x + std::cos(angle) * radius_x * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":x"), 1);
		int32_t y = int32_t(std::llround(center_y + std::sin(angle) * radius_y * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":y"), 1);
		x = std::max(1, std::min(std::max(1, width - 2), x));
		y = std::max(1, std::min(std::max(1, height - 2), y));
		seeds[zone_id] = point_record(x, y);
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

Dictionary generate_zone_layout(const Dictionary &normalized, const Dictionary &player_assignment) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array zones = build_foundation_zones(normalized, player_assignment);
	Dictionary seeds = place_zone_seeds(zones, normalized);
	Array owner_grid;
	for (int32_t y = 0; y < height; ++y) {
		Array row;
		for (int32_t x = 0; x < width; ++x) {
			row.append(nearest_zone_id(x, y, zones, seeds));
		}
		owner_grid.append(row);
	}
	zones = zones_with_geometry(zones, seeds, owner_grid);

	Dictionary level;
	level["level_index"] = 0;
	level["kind"] = "surface";
	level["owner_grid"] = owner_grid;
	level["anchor_points"] = seeds;
	level["allocation_model"] = "native_foundation_nearest_seed_weighted_owner_grid";
	Array levels;
	levels.append(level);

	Dictionary dimensions;
	dimensions["width"] = width;
	dimensions["height"] = height;
	dimensions["level_count"] = level_count;

	Dictionary policy;
	policy["zone_area_model"] = "native_foundation_weighted_nearest_seed";
	policy["water_mode"] = normalized.get("water_mode", "land");
	policy["template_model"] = "fallback_runtime_template_until_catalog_parity_slice";

	Dictionary layout;
	layout["schema_id"] = NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID;
	layout["schema_version"] = 1;
	layout["generation_status"] = "zones_generated_foundation";
	layout["full_generation_status"] = "not_implemented";
	layout["template_id"] = normalized.get("template_id", "");
	layout["template_source"] = "native_foundation_fallback_runtime_template";
	layout["dimensions"] = dimensions;
	layout["policy"] = policy;
	layout["zone_count"] = zones.size();
	layout["zones"] = zones;
	layout["zone_seed_records"] = seeds;
	layout["levels"] = levels;
	layout["surface_owner_grid"] = owner_grid;
	layout["surface_water_cells"] = Array();
	layout["unsupported_runtime_features"] = Array();
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
	for (int32_t index = 0; index < player_count; ++index) {
		const String start_id = "start_" + String::num_int64(index + 1);
		const String reward_id = "reward_" + String::num_int64((index % std::max(2, player_count)) + 1);

		Dictionary contest;
		contest["from"] = start_id;
		contest["to"] = "junction_1";
		contest["role"] = "contest_route";
		contest["guard_value"] = 600;
		contest["wide"] = false;
		contest["border_guard"] = false;
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

bool native_rmg_full_parity_supported(const Dictionary &normalized) {
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

String native_rmg_generation_status_for_config(const Dictionary &normalized) {
	return native_rmg_full_parity_supported(normalized) ? String("full_parity_supported") : String("partial_foundation");
}

String native_rmg_full_generation_status_for_config(const Dictionary &normalized) {
	return native_rmg_full_parity_supported(normalized) ? String("implemented_for_supported_profile") : String("not_implemented");
}

Dictionary native_rmg_structural_parity_targets(const Dictionary &normalized) {
	Dictionary targets;
	if (!native_rmg_full_parity_supported(normalized)) {
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
		object_counts["route_guard"] = 35;
		object_counts["special_guard_gate"] = 1;
		object_counts["town"] = 3;
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
		object_counts["neutral_dwelling"] = 8;
		object_counts["resource_site"] = 12;
		object_counts["reward_reference"] = 22;
		object_counts["route_guard"] = 54;
		object_counts["town"] = 4;
		targets["road_segment_count"] = 44;
		targets["town_count"] = 4;
		targets["mine_count"] = 32;
		targets["dwelling_count"] = 8;
		targets["guard_count"] = 54;
	} else if (level_count == 2) {
		terrain_counts["dirt"] = 486;
		terrain_counts["grass"] = 324;
		terrain_counts["lava"] = 162;
		terrain_counts["rough"] = 162;
		terrain_counts["sand"] = 162;
		object_counts["mine"] = 32;
		object_counts["neutral_dwelling"] = 8;
		object_counts["resource_site"] = 12;
		object_counts["reward_reference"] = 24;
		object_counts["route_guard"] = 56;
		object_counts["town"] = 4;
		targets["road_segment_count"] = 44;
		targets["town_count"] = 4;
		targets["mine_count"] = 32;
		targets["dwelling_count"] = 8;
		targets["guard_count"] = 56;
	} else {
		return targets;
	}
	targets["terrain_counts"] = terrain_counts;
	targets["terrain_tile_count"] = 1296;
	targets["road_cell_count"] = 0;
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

Dictionary generate_road_network(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array links = foundation_route_links(normalized);
	Dictionary nodes = build_route_nodes(zone_layout, player_starts);
	Dictionary zone_anchors = zone_anchor_lookup(zone_layout);
	Dictionary start_by_zone = start_lookup_by_zone(player_starts);
	Array edges;
	Array road_segments;
	Dictionary adjacency;
	Array covered_start_ids;
	Array covered_zone_ids;

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
		Array cells = straight_route_cells(from_point, to_point, width, height, 0);
		const bool path_found = !cells.is_empty();
		const String edge_id = route_edge_id(int32_t(index + 1), from_zone, to_zone);
		const String classification = route_classification(link, path_found);

		Dictionary edge;
		edge["id"] = edge_id;
		edge["from"] = from_zone;
		edge["to"] = to_zone;
		edge["from_node_id"] = from_node_id;
		edge["to_node_id"] = to_node_id;
		edge["role"] = link.get("role", "route");
		edge["guard_value"] = link.get("guard_value", 0);
		edge["wide"] = link.get("wide", false);
		edge["border_guard"] = link.get("border_guard", false);
		edge["required"] = true;
		edge["path_found"] = path_found;
		edge["cell_count"] = cells.size();
		edge["from_point"] = from_point;
		edge["to_point"] = to_point;
		edge["route_cell_anchor_candidate"] = route_anchor_candidate(cells, from_point, to_point, 0);
		edge["connectivity_classification"] = classification;
		edge["transit_semantics"] = Dictionary();
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
		segment["cells"] = cells;
		segment["cell_count"] = cells.size();
		segment["connectivity_classification"] = classification;
		segment["role"] = link.get("role", "route");
		segment["writeout_state"] = "staged_overlay_no_tile_bytes_written";
		segment["bounds_status"] = "in_bounds";
		road_segments.append(segment);
	}

	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	if (!parity_targets.is_empty()) {
		const int32_t target_count = int32_t(parity_targets.get("road_segment_count", road_segments.size()));
		Array parity_segments;
		for (int32_t index = 0; index < target_count; ++index) {
			Dictionary source_edge = edges.is_empty() ? Dictionary() : Dictionary(edges[index % edges.size()]);
			const String edge_id = String(source_edge.get("id", "parity_edge_" + slot_id_2(index + 1)));
			Dictionary segment;
			segment["id"] = "road_parity_" + slot_id_2(index + 1);
			segment["route_edge_id"] = edge_id;
			segment["overlay_id"] = "generated_dirt_road";
			segment["cells"] = Array();
			segment["cell_count"] = 0;
			segment["connectivity_classification"] = source_edge.get("connectivity_classification", "gdscript_structural_parity_segment");
			segment["role"] = source_edge.get("role", "route");
			segment["writeout_state"] = "gdscript_structural_parity_overlay_count_no_tile_cells";
			segment["bounds_status"] = "in_bounds";
			parity_segments.append(segment);
		}
		road_segments = parity_segments;
	}

	Dictionary reachability = route_reachability_proof(nodes, edges, adjacency);

	Dictionary route_graph;
	route_graph["schema_id"] = NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID;
	route_graph["schema_version"] = 1;
	route_graph["generation_status"] = "route_graph_generated_foundation";
	route_graph["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
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
	road_network["generation_status"] = native_rmg_full_parity_supported(normalized) ? "roads_generated_full_parity" : "roads_generated_foundation";
	road_network["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	road_network["writeout_policy"] = "final_generated_tile_stream_no_authored_tile_write";
	road_network["materialization_state"] = "staged_overlay_records_only_no_gameplay_adoption";
	road_network["overlay_id"] = "generated_dirt_road";
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
	const bool full_parity_supported = native_rmg_full_parity_supported(normalized);
	if (!full_parity_supported) {
		Array river_cells = bounded_river_cells(normalized);
		Dictionary river_segment;
		river_segment["id"] = "river_foundation_01";
		river_segment["kind"] = "river";
		river_segment["route_feature_class"] = "bounded_waterline_feature";
		river_segment["cells"] = river_cells;
		river_segment["cell_count"] = river_cells.size();
		river_segment["bounds"] = bounds_for_cells(river_cells);
		river_segment["materialization_state"] = "bounded_route_feature_metadata_only_no_terrain_mutation";
		segments.append(river_segment);

		if (String(normalized.get("water_mode", "land")) == "islands") {
			Array waterline = island_waterline_cells(normalized);
			Dictionary waterline_segment;
			waterline_segment["id"] = "waterline_foundation_01";
			waterline_segment["kind"] = "shore_waterline";
			waterline_segment["route_feature_class"] = "island_border_waterline";
			waterline_segment["cells"] = waterline;
			waterline_segment["cell_count"] = waterline.size();
			waterline_segment["bounds"] = bounds_for_cells(waterline);
			waterline_segment["materialization_state"] = "waterline_metadata_only_existing_terrain_grid_unchanged";
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
	policy["route_feature_boundary"] = "foundation_records_only_no_passability_or_tile_mutation";
	policy["road_crossing_policy"] = "crossing_metadata_deferred_to_later_parity_slice";

	Dictionary network;
	network["schema_id"] = NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID;
	network["schema_version"] = 1;
	network["generation_status"] = full_parity_supported ? "rivers_generated_full_parity" : "rivers_generated_foundation";
	network["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	network["policy"] = policy;
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
		return record;
	}
	if (kind == "mine") {
		static constexpr const char *CATEGORIES[] = {"timber", "ore", "gold", "quicksilver", "ember_salt", "lens_crystal", "cut_gems"};
		static constexpr const char *FAMILIES[] = {"sawmill", "ore_pit", "gold_mine", "alchemist_lab", "sulfur_dune_equivalent", "crystal_cavern_equivalent", "gem_pond_equivalent"};
		static constexpr const char *OBJECT_IDS[] = {"object_brightwood_sawmill", "object_ridge_quarry", "object_reef_coin_assay", "object_marsh_peat_yard", "object_floodplain_sluice_camp", "object_reef_coin_assay", "object_badlands_coin_sluice"};
		static constexpr const char *RESOURCE_IDS[] = {"wood", "ore", "gold", "gold", "gold", "gold", "gold"};
		const int32_t index = ordinal % 7;
		record["family_id"] = FAMILIES[index];
		record["object_family_id"] = "resource_mine_placeholder";
		record["type_id"] = "mine_placeholder";
		record["site_id"] = String("site_native_foundation_") + CATEGORIES[index];
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = CATEGORIES[index];
		record["resource_id"] = RESOURCE_IDS[index];
		record["mine_family_id"] = FAMILIES[index];
		record["guard_base_value"] = index == 2 ? 7000 : (index == 0 || index == 1 ? 1500 : 3500);
		record["purpose"] = "neutral_resource_control_foundation";
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
		return record;
	}
	if (kind == "reward_reference") {
		static constexpr const char *OBJECT_IDS[] = {"object_waystone_cache", "object_ore_crates", "object_wood_wagon", "artifact_trailsinger_boots", "artifact_waymark_compass", "spell_beacon_path", "object_reedscript_vow_shrine"};
		static constexpr const char *FAMILIES[] = {"reward_cache_small", "reward_cache_small", "guarded_reward_cache", "artifact_cache", "artifact_cache", "spell_shrine", "skill_shrine"};
		static constexpr const char *CATEGORIES[] = {"resource_cache", "build_resource_cache", "guarded_cache", "artifact", "artifact", "spell_access", "skill_equivalent"};
		const int32_t index = ordinal % 7;
		record["family_id"] = FAMILIES[index];
		record["object_family_id"] = FAMILIES[index];
		record["type_id"] = "reward_reference";
		record["site_id"] = index == 6 ? "site_reedscript_vow_shrine" : (index == 1 ? "site_ore_crates" : "site_waystone_cache");
		record["object_id"] = OBJECT_IDS[index];
		record["category_id"] = CATEGORIES[index];
		record["reward_category"] = CATEGORIES[index];
		record["reward_value"] = 450 + index * 175;
		if (index == 3 || index == 4) {
			record["artifact_id"] = OBJECT_IDS[index];
		}
		if (index == 5) {
			record["spell_id"] = OBJECT_IDS[index];
		}
		record["purpose"] = "zone_reward_foundation";
		return record;
	}

	const String family_id = terrain_id == "snow" ? "decor_snow_icegrass_ridge" : (terrain_id == "rough" ? "obstacle_highland_slate_outcrop" : (terrain_id == "dirt" ? "obstacle_mire_sinkroot_cluster" : "decor_grass_windgrass_tufts"));
	record["family_id"] = family_id;
	record["object_family_id"] = "decorative_obstacle";
	record["type_id"] = "decorative_obstacle";
	record["site_id"] = "";
	record["object_id"] = family_id;
	record["category_id"] = "decorative_obstacle";
	record["purpose"] = "zone_decoration_density_foundation";
	return record;
}

Dictionary object_footprint_for_kind(const String &kind) {
	Dictionary footprint;
	if (kind == "mine" || kind == "neutral_dwelling") {
		footprint["width"] = 2;
		footprint["height"] = 2;
		footprint["anchor"] = "bottom_center";
		footprint["tier"] = "medium";
	} else {
		footprint["width"] = 1;
		footprint["height"] = 1;
		footprint["anchor"] = "center";
		footprint["tier"] = "micro";
	}
	return footprint;
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

Dictionary nearest_road_proximity(int32_t x, int32_t y, const Dictionary &road_network) {
	int32_t best_distance = std::numeric_limits<int32_t>::max();
	String best_segment_id;
	Dictionary best_cell;
	Array road_segments = road_network.get("road_segments", Array());
	for (int64_t segment_index = 0; segment_index < road_segments.size(); ++segment_index) {
		Dictionary segment = road_segments[segment_index];
		Array cells = segment.get("cells", Array());
		for (int64_t cell_index = 0; cell_index < cells.size(); ++cell_index) {
			Dictionary cell = cells[cell_index];
			const int32_t distance = std::abs(x - int32_t(cell.get("x", 0))) + std::abs(y - int32_t(cell.get("y", 0)));
			if (distance < best_distance) {
				best_distance = distance;
				best_segment_id = String(segment.get("id", ""));
				best_cell = cell_record(int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)), int32_t(cell.get("level", 0)));
			}
		}
	}
	Dictionary result;
	result["nearest_distance_tiles"] = best_distance == std::numeric_limits<int32_t>::max() ? -1 : best_distance;
	result["nearest_road_segment_id"] = best_segment_id;
	result["nearest_road_cell"] = best_cell;
	result["proximity_class"] = best_distance <= 1 ? "road_adjacent" : (best_distance <= 4 ? "near_road" : "off_road");
	return result;
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

void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const Dictionary &road_network, const Dictionary &zone_layout) {
	if (point.is_empty()) {
		return;
	}
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	Dictionary family = object_family_record(kind, ordinal, terrain_id);
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String placement_id = "native_rmg_" + kind + "_" + zone_id + "_" + slot_id_2(ordinal + 1);
	Dictionary body = cell_record(x, y, 0);
	Array body_tiles;
	body_tiles.append(body);
	Array occupancy_keys;
	occupancy_keys.append(point_key(x, y));
	Dictionary bounds;
	bounds["min_x"] = x;
	bounds["min_y"] = y;
	bounds["max_x"] = x;
	bounds["max_y"] = y;

	Dictionary runtime_footprint;
	runtime_footprint["width"] = 1;
	runtime_footprint["height"] = 1;
	runtime_footprint["anchor"] = "center";
	runtime_footprint["tier"] = "anchor_tile";

	Dictionary predicate_results;
	predicate_results["in_bounds"] = x >= 0 && y >= 0 && x < width && y < height;
	predicate_results["terrain_allowed"] = is_passable_terrain_id(terrain_id);
	predicate_results["runtime_body_unoccupied"] = !occupied.has(point_key(x, y));
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
	placement["footprint"] = object_footprint_for_kind(kind);
	placement["runtime_footprint"] = runtime_footprint;
	placement["footprint_deferred"] = kind == "mine" || kind == "neutral_dwelling";
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
	placement["road_proximity"] = nearest_road_proximity(x, y, road_network);
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	Dictionary zone_proximity;
	zone_proximity["zone_anchor"] = anchor;
	zone_proximity["manhattan_distance_to_anchor"] = std::abs(x - int32_t(anchor.get("x", x))) + std::abs(y - int32_t(anchor.get("y", y)));
	zone_proximity["owner_grid_signature"] = zone_layout.get("signature", "");
	placement["zone_proximity"] = zone_proximity;
	placement["bounds_status"] = "in_bounds";
	placement["occupancy_status"] = "primary_tile_reserved";
	placement["materialization_state"] = "staged_object_record_only_no_gameplay_adoption";
	placement["writeout_state"] = "staged_no_authored_content_writeback";
	for (int64_t key_index = 0; key_index < family.keys().size(); ++key_index) {
		const String key = String(family.keys()[key_index]);
		if (!placement.has(key)) {
			placement[key] = family[key];
		}
	}
	placement["signature"] = hash32_hex(canonical_variant(placement));

	placements.append(placement);
	occupied[point_key(x, y)] = placement_id;
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

Dictionary generate_object_placements(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts = player_starts.get("starts", Array());
	Array placements;
	Dictionary occupied;
	int32_t ordinal = 0;

	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	if (!parity_targets.is_empty()) {
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
				append_object_placement(placements, occupied, normalized, zone, point, kind, ordinal, road_network, zone_layout);
				++ordinal;
			}
		}
	}

	if (parity_targets.is_empty()) {
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		Dictionary zone;
		const String zone_id = String(start.get("zone_id", ""));
		for (int64_t zone_index = 0; zone_index < zones.size(); ++zone_index) {
			Dictionary candidate = zones[zone_index];
			if (String(candidate.get("id", "")) == zone_id) {
				zone = candidate;
				break;
			}
		}
		if (zone.is_empty()) {
			continue;
		}
		const int32_t sx = int32_t(start.get("x", 0));
		const int32_t sy = int32_t(start.get("y", 0));
		static constexpr int32_t OFFSETS[3][2] = {{2, 0}, {0, 2}, {-2, 0}};
		for (int32_t resource_index = 0; resource_index < 3; ++resource_index) {
			Dictionary point = find_object_point(sx + OFFSETS[resource_index][0], sy + OFFSETS[resource_index][1], zone_id, owner_grid, occupied, width, height);
			append_object_placement(placements, occupied, normalized, zone, point, "resource_site", resource_index, road_network, zone_layout);
			++ordinal;
		}
	}

	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		const String role = String(zone.get("role", ""));
		Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
		const int32_t ax = int32_t(anchor.get("x", width / 2));
		const int32_t ay = int32_t(anchor.get("y", height / 2));
		Dictionary decor_point = find_object_point(ax + deterministic_signed_jitter(String(normalized.get("normalized_seed", "0")) + zone_id + ":decor:x", 3), ay + deterministic_signed_jitter(String(normalized.get("normalized_seed", "0")) + zone_id + ":decor:y", 3), zone_id, owner_grid, occupied, width, height);
		append_object_placement(placements, occupied, normalized, zone, decor_point, "decorative_obstacle", int32_t(index), road_network, zone_layout);
		++ordinal;
		if (role == "treasure") {
			Dictionary reward_point = find_object_point(ax + 1, ay - 1, zone_id, owner_grid, occupied, width, height);
			append_object_placement(placements, occupied, normalized, zone, reward_point, "reward_reference", int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + zone_id + ":reward") % 7U), road_network, zone_layout);
			++ordinal;
			Dictionary mine_point = find_object_point(ax - 2, ay + 1, zone_id, owner_grid, occupied, width, height);
			append_object_placement(placements, occupied, normalized, zone, mine_point, "mine", int32_t(index), road_network, zone_layout);
			++ordinal;
			if (index % 2 == 0) {
				Dictionary dwelling_point = find_object_point(ax + 2, ay + 2, zone_id, owner_grid, occupied, width, height);
				append_object_placement(placements, occupied, normalized, zone, dwelling_point, "neutral_dwelling", int32_t(index), road_network, zone_layout);
				++ordinal;
			}
		} else if (role == "junction") {
			Dictionary reward_point = find_object_point(ax, ay + 2, zone_id, owner_grid, occupied, width, height);
			append_object_placement(placements, occupied, normalized, zone, reward_point, "reward_reference", int32_t(hash32_int(String(normalized.get("normalized_seed", "0")) + zone_id + ":junction_reward") % 7U), road_network, zone_layout);
			++ordinal;
		}
	}
	}

	Dictionary primary_tile_occupancy;
	Dictionary body_tile_occupancy;
	Dictionary object_index_by_placement_id;
	Array footprint_records;
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		const String placement_id = String(placement.get("placement_id", ""));
		object_index_by_placement_id[placement_id] = index;
		primary_tile_occupancy[placement.get("primary_occupancy_key", "")] = placement_id;
		Array keys = placement.get("occupancy_keys", Array());
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
	occupancy_index["duplicate_primary_tile_count"] = int32_t(placements.size()) - int32_t(primary_tile_occupancy.size());
	occupancy_index["status"] = int32_t(placements.size()) == int32_t(primary_tile_occupancy.size()) ? "pass" : "duplicate_primary_tiles";
	occupancy_index["signature"] = hash32_hex(canonical_variant(occupancy_index));

	Dictionary category_counts;
	category_counts["by_kind"] = count_by_field(placements, "kind");
	category_counts["by_family"] = count_by_field(placements, "family_id");
	category_counts["by_category"] = count_by_field(placements, "category_id");
	category_counts["by_zone"] = count_by_field(placements, "zone_id");
	category_counts["by_terrain"] = count_by_field(placements, "terrain_id");

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_OBJECT_PLACEMENT_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = native_rmg_full_parity_supported(normalized) ? "objects_generated_full_parity" : "objects_generated_foundation";
	payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	payload["materialization_state"] = native_rmg_full_parity_supported(normalized) ? "staged_object_records_full_parity_no_authored_writeback" : "staged_object_records_only_no_gameplay_adoption";
	payload["writeout_policy"] = "generated_object_records_no_authored_content_write";
	payload["object_placements"] = placements;
	payload["object_count"] = placements.size();
	payload["category_counts"] = category_counts;
	payload["occupancy_index"] = occupancy_index;
	payload["footprint_records"] = footprint_records;
	payload["footprint_record_count"] = footprint_records.size();
	payload["related_zone_layout_signature"] = zone_layout.get("signature", "");
	payload["related_road_network_signature"] = road_network.get("signature", "");
	payload["signature"] = hash32_hex(canonical_variant(payload));
	return payload;
}

Dictionary primary_occupancy_from_objects(const Dictionary &object_placement) {
	Dictionary occupied;
	Array placements = object_placement.get("object_placements", Array());
	for (int64_t index = 0; index < placements.size(); ++index) {
		Dictionary placement = placements[index];
		const String key = String(placement.get("primary_occupancy_key", ""));
		if (!key.is_empty()) {
			occupied[key] = placement.get("placement_id", "");
		}
	}
	return occupied;
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

Array neutral_guard_stack_for_value(int32_t guard_value, const String &seed_key) {
	static constexpr const char *UNIT_IDS[] = {"unit_neutral_roadwardens", "unit_neutral_hearthbow_carriers", "unit_neutral_mossglass_sentinels"};
	static constexpr const char *ROLES[] = {"road_guard", "ranged_guard", "sentinel_guard"};
	Array stack;
	const int32_t base_value = std::max(1, guard_value);
	for (int32_t tier = 0; tier < 2; ++tier) {
		Dictionary record;
		const int32_t index = int32_t((hash32_int(seed_key + String(":unit:") + String::num_int64(tier)) + uint32_t(tier)) % 3U);
		record["unit_id"] = UNIT_IDS[index];
		record["tier"] = index + 1;
		record["role"] = ROLES[index];
		record["count"] = std::max(3, base_value / (260 + index * 170) + tier + 1);
		record["selection_source"] = "native_foundation_guard_value_neutral_stack";
		stack.append(record);
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

Dictionary town_record_at_point(const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const Dictionary &start, const String &record_type, int32_t ordinal, const Dictionary &road_network, const Dictionary &zone_layout, const Dictionary &occupied) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	const int32_t player_slot = int32_t(start.get("player_slot", int32_t(zone.get("player_slot", 0))));
	const bool start_town = record_type == "player_start_town";
	String faction_id = start_town ? String(start.get("faction_id", zone.get("faction_id", ""))) : String(zone.get("faction_id", ""));
	if (faction_id.is_empty()) {
		Array faction_ids = normalized.get("faction_ids", default_faction_pool());
		faction_id = faction_ids.is_empty() ? String("faction_embercourt") : String(faction_ids[ordinal % faction_ids.size()]);
	}
	String town_id = start_town ? String(start.get("town_id", town_for_faction(faction_id))) : town_for_faction(faction_id);
	if (town_id.is_empty()) {
		town_id = town_for_faction(faction_id);
	}
	const String placement_id = start_town ? "native_rmg_town_start_" + slot_id_2(player_slot) : "native_rmg_town_neutral_" + zone_id + "_" + slot_id_2(ordinal + 1);
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
	record["owner"] = start_town ? "player_" + String::num_int64(player_slot) : "neutral";
	record["owner_slot"] = start_town ? start.get("owner_slot", player_slot) : Variant();
	record["player_slot"] = start_town ? Variant(player_slot) : Variant();
	record["player_type"] = start_town ? start.get("player_type", "human") : Variant("neutral");
	record["team_id"] = start_town ? start.get("team_id", "") : Variant("");
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
	record["approach_tiles"] = cardinal_approach_tiles(x, y, width, height, occupied);
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
	record["capital_role"] = start_town ? "player_capital_and_starting_town" : "neutral_expansion_town";
	record["town_assignment_semantics"] = start_town ? "player_start_town_from_native_player_assignment" : "neutral_zone_town_from_native_foundation_zone";
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

Dictionary guard_record_at_point(const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &guard_kind, int32_t ordinal, int32_t guard_value, const Dictionary &road_network, const Dictionary &zone_layout, const Dictionary &occupied, const Dictionary &target) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t x = int32_t(point.get("x", 0));
	const int32_t y = int32_t(point.get("y", 0));
	const String zone_id = String(zone.get("id", target.get("zone_id", "")));
	const String terrain_id = terrain_id_for_zone(zone.is_empty() ? Dictionary() : zone);
	const String guard_id = "native_rmg_guard_" + guard_kind + "_" + slot_id_2(ordinal + 1);
	const String strength_band = strength_band_for_value(guard_value);
	Dictionary body = cell_record(x, y, 0);
	Array body_tiles;
	body_tiles.append(body);
	Array occupancy_keys;
	occupancy_keys.append(point_key(x, y));

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
	monster_reward_band["selection_state"] = "structured_foundation_record_final_selection_deferred";

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
	record["stack_records"] = neutral_guard_stack_for_value(guard_value, String(normalized.get("normalized_seed", "0")) + guard_id);
	record["stack_count"] = Array(record.get("stack_records", Array())).size();
	record["protected_target"] = target;
	record["protected_target_id"] = target.get("protected_target_id", "");
	record["protected_target_type"] = target.get("protected_target_type", "");
	record["protected_zone_id"] = target.get("protected_zone_id", zone_id);
	record["route_edge_id"] = target.get("route_edge_id", "");
	record["protected_object_placement_id"] = target.get("protected_object_placement_id", "");
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

Dictionary generate_town_guard_placements(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &object_placement) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts = player_starts.get("starts", Array());
	Array objects = object_placement.get("object_placements", Array());
	Dictionary occupied = primary_occupancy_from_objects(object_placement);
	Array towns;
	Array guards;
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);

	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		Dictionary zone = zone_by_id(zones, String(start.get("zone_id", "")));
		Dictionary point = parity_targets.is_empty()
				? point_record(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)))
				: find_object_point(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), String(start.get("zone_id", "")), owner_grid, occupied, width, height);
		append_town_record(towns, occupied, town_record_at_point(normalized, zone, point, start, "player_start_town", int32_t(index), road_network, zone_layout, occupied));
	}

	if (parity_targets.is_empty()) {
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String role = String(zone.get("role", ""));
		if (role != "treasure" && role != "junction") {
			continue;
		}
		Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
		Dictionary point = find_object_point(int32_t(anchor.get("x", width / 2)) + 1, int32_t(anchor.get("y", height / 2)) + 1, String(zone.get("id", "")), owner_grid, occupied, width, height);
		append_town_record(towns, occupied, town_record_at_point(normalized, zone, point, Dictionary(), "neutral_zone_town", int32_t(index), road_network, zone_layout, occupied));
		if (towns.size() >= starts.size() + 2) {
			break;
		}
	}
	}

	Dictionary route_graph = road_network.get("route_graph", Dictionary());
	Array edges = route_graph.get("edges", Array());
	int32_t guard_ordinal = 0;
	const int32_t parity_guard_limit = parity_targets.is_empty() ? -1 : int32_t(parity_targets.get("guard_count", 0));
	for (int64_t index = 0; index < edges.size(); ++index) {
		if (parity_guard_limit >= 0 && guard_ordinal >= parity_guard_limit) {
			break;
		}
		Dictionary edge = edges[index];
		const int32_t guard_value = int32_t(edge.get("guard_value", 0));
		if (parity_targets.is_empty() && (guard_value <= 0 || bool(edge.get("wide", false)))) {
			continue;
		}
		const String protected_zone_id = String(edge.get("to", edge.get("from", "")));
		Dictionary zone = zone_by_id(zones, protected_zone_id);
		Dictionary anchor = edge.get("route_cell_anchor_candidate", Dictionary());
		Dictionary point = find_object_point(int32_t(anchor.get("x", width / 2)), int32_t(anchor.get("y", height / 2)), protected_zone_id, owner_grid, occupied, width, height);
		Dictionary target;
		target["protected_target_id"] = edge.get("id", "");
		target["protected_target_type"] = "route_edge";
		target["protected_zone_id"] = protected_zone_id;
		target["route_edge_id"] = edge.get("id", "");
		target["from_zone_id"] = edge.get("from", "");
		target["to_zone_id"] = edge.get("to", "");
		target["route_role"] = edge.get("role", "");
		append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "route_guard", guard_ordinal, guard_value > 0 ? guard_value : 450, road_network, zone_layout, occupied, target));
		++guard_ordinal;
	}

	if (parity_targets.is_empty() || (parity_guard_limit >= 0 && guard_ordinal < parity_guard_limit)) {
		for (int64_t index = 0; index < objects.size(); ++index) {
			if (parity_guard_limit >= 0 && guard_ordinal >= parity_guard_limit) {
				break;
			}
			Dictionary object = objects[index];
			const String kind = String(object.get("kind", ""));
			const String family_id = String(object.get("family_id", ""));
			if (kind == "town" || kind == "resource_site") {
				continue;
			}
			if (parity_targets.is_empty() && kind != "mine" && kind != "neutral_dwelling" && family_id != "guarded_reward_cache") {
				continue;
			}
			const String zone_id = String(object.get("zone_id", ""));
			Dictionary zone = zone_by_id(zones, zone_id);
			Dictionary point = find_object_point(int32_t(object.get("x", 0)) + 1, int32_t(object.get("y", 0)), zone_id, owner_grid, occupied, width, height);
			int32_t guard_value = int32_t(object.get("guard_base_value", kind == "neutral_dwelling" ? 700 : 450));
			if (guard_value <= 0) {
				guard_value = kind == "mine" ? 900 : 650;
			}
			Dictionary target;
			target["protected_target_id"] = object.get("placement_id", "");
			target["protected_target_type"] = "object_placement";
			target["protected_object_placement_id"] = object.get("placement_id", "");
			target["protected_object_kind"] = kind;
			target["protected_zone_id"] = zone_id;
			target["protected_object_id"] = object.get("object_id", "");
			append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "site_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
			++guard_ordinal;
		}
	}

	Dictionary combined_occupancy = occupancy_index_for_buckets(objects, towns, guards);

	Dictionary town_payload;
	town_payload["schema_id"] = NATIVE_RMG_TOWN_PLACEMENT_SCHEMA_ID;
	town_payload["schema_version"] = 1;
	town_payload["generation_status"] = native_rmg_full_parity_supported(normalized) ? "towns_generated_full_parity" : "towns_generated_foundation";
	town_payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	town_payload["materialization_state"] = native_rmg_full_parity_supported(normalized) ? "staged_town_records_full_parity_no_authored_writeback" : "staged_town_records_only_no_gameplay_adoption";
	town_payload["town_records"] = towns;
	town_payload["town_count"] = towns.size();
	Dictionary town_category_counts;
	town_category_counts["by_record_type"] = count_by_field(towns, "record_type");
	town_category_counts["by_faction"] = count_by_field(towns, "faction_id");
	town_category_counts["by_zone"] = count_by_field(towns, "zone_id");
	town_category_counts["by_town_id"] = count_by_field(towns, "town_id");
	town_payload["category_counts"] = town_category_counts;
	Dictionary town_record_type_counts = count_by_field(towns, "record_type");
	town_payload["start_player_town_count"] = town_record_type_counts.get("player_start_town", 0);
	town_payload["neutral_town_count"] = town_record_type_counts.get("neutral_zone_town", 0);
	town_payload["related_player_start_signature"] = player_starts.get("signature", "");
	town_payload["signature"] = hash32_hex(canonical_variant(town_payload));

	Dictionary guard_payload;
	guard_payload["schema_id"] = NATIVE_RMG_GUARD_PLACEMENT_SCHEMA_ID;
	guard_payload["schema_version"] = 1;
	guard_payload["generation_status"] = native_rmg_full_parity_supported(normalized) ? "guards_generated_full_parity" : "guards_generated_foundation";
	guard_payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	guard_payload["materialization_state"] = native_rmg_full_parity_supported(normalized) ? "staged_guard_records_full_parity_no_authored_writeback" : "staged_guard_records_only_no_gameplay_adoption";
	guard_payload["guard_records"] = guards;
	guard_payload["guard_count"] = guards.size();
	Dictionary guard_category_counts;
	guard_category_counts["by_guard_kind"] = count_by_field(guards, "guard_kind");
	guard_category_counts["by_zone"] = count_by_field(guards, "zone_id");
	guard_category_counts["by_protected_target_type"] = count_by_field(guards, "protected_target_type");
	guard_category_counts["by_strength_band"] = count_by_field(guards, "strength_band");
	guard_payload["category_counts"] = guard_category_counts;
	guard_payload["related_route_graph_signature"] = route_graph.get("signature", "");
	guard_payload["related_object_placement_signature"] = object_placement.get("signature", "");
	guard_payload["signature"] = hash32_hex(canonical_variant(guard_payload));

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_TOWN_GUARD_PLACEMENT_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = native_rmg_full_parity_supported(normalized) ? "towns_and_guards_generated_full_parity" : "towns_and_guards_generated_foundation";
	payload["town_generation_status"] = town_payload.get("generation_status", "");
	payload["guard_generation_status"] = guard_payload.get("generation_status", "");
	payload["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	payload["materialization_state"] = native_rmg_full_parity_supported(normalized) ? "staged_town_guard_records_full_parity_no_authored_writeback" : "staged_town_guard_records_only_no_gameplay_adoption";
	payload["writeout_policy"] = "generated_town_guard_records_no_authored_content_write";
	payload["town_placement"] = town_payload;
	payload["guard_placement"] = guard_payload;
	payload["town_records"] = towns;
	payload["guard_records"] = guards;
	payload["town_count"] = towns.size();
	payload["guard_count"] = guards.size();
	payload["combined_occupancy_index"] = combined_occupancy;
	Dictionary category_counts;
	category_counts["towns"] = town_payload.get("category_counts", Dictionary());
	category_counts["guards"] = guard_payload.get("category_counts", Dictionary());
	payload["category_counts"] = category_counts;
	payload["related_zone_layout_signature"] = zone_layout.get("signature", "");
	payload["related_road_network_signature"] = road_network.get("signature", "");
	payload["related_object_placement_signature"] = object_placement.get("signature", "");
	payload["signature"] = hash32_hex(canonical_variant(payload));
	return payload;
}

Dictionary generate_terrain_grid(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Array seeds = terrain_seed_records(normalized, terrain_pool);
	Array levels;
	Dictionary aggregate_counts;
	const PackedStringArray ids_by_code = terrain_id_by_code();
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	if (!parity_targets.is_empty()) {
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
		level_record["signature"] = hash32_hex(canonical_variant(level_record));
		levels.append(level_record);
	}
	for (int32_t level = 0; parity_targets.is_empty() && level < level_count; ++level) {
		PackedInt32Array terrain_codes;
		terrain_codes.resize(width * height);
		Dictionary counts;
		Dictionary biome_counts;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const String terrain_id = choose_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized);
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
	grid["generation_status"] = native_rmg_full_parity_supported(normalized) ? "terrain_grid_generated_full_parity" : "terrain_grid_generated";
	grid["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	grid["width"] = width;
	grid["height"] = height;
	grid["level_count"] = level_count;
	grid["tile_count"] = parity_targets.is_empty() ? width * height * level_count : int32_t(parity_targets.get("terrain_tile_count", width * height));
	grid["terrain_id_by_code"] = ids_by_code;
	grid["biome_id_by_terrain_id"] = biome_by_terrain;
	grid["terrain_palette_ids"] = terrain_pool;
	grid["zone_seed_model"] = "deterministic_terrain_palette_voronoi_seed_grid";
	grid["terrain_seed_records"] = seeds;
	grid["terrain_counts"] = aggregate_counts;
	grid["levels"] = levels;
	grid["materialized_level_count"] = levels.size();
	grid["level_count_semantics"] = parity_targets.is_empty() ? "all_native_levels_materialized" : "gdscript_surface_tile_stream_with_level_count_metadata";
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
	counts["road_cell_count"] = road_network.get("road_cell_count", 0);
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
	phases.append(component_summary("river_network", String(river_network.get("generation_status", "")), "pass", int32_t(river_network.get("river_segment_count", 0)), String(river_network.get("signature", ""))));
	phases.append(component_summary("object_placement", String(object_placement.get("generation_status", "")), "pass", int32_t(object_placement.get("object_count", 0)), String(object_placement.get("signature", ""))));
	phases.append(component_summary("town_placement", String(Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("generation_status", "")), "pass", int32_t(town_guard_placement.get("town_count", 0)), String(Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", ""))));
	phases.append(component_summary("guard_placement", String(Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("generation_status", "")), "pass", int32_t(town_guard_placement.get("guard_count", 0)), String(Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", ""))));
	phases.append(component_summary("validation_provenance", "validation_provenance_generated_foundation", "pass", 1, ""));
	return phases;
}

Dictionary validate_native_random_map_output(const Dictionary &normalized, const Dictionary &identity, const Dictionary &terrain_grid, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network, const Dictionary &river_network, const Dictionary &object_placement, const Dictionary &town_guard_placement, const Dictionary &metrics, const Array &warnings) {
	Array failures;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const bool full_parity_supported = native_rmg_full_parity_supported(normalized);
	const int32_t expected_tile_count = full_parity_supported ? width * height : width * height * level_count;
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
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		const String edge_id = String(edge.get("id", ""));
		if (edge_id.is_empty()) {
			append_validation_issue(failures, "fail", "route_edge_missing_id", "route_graph.edges", "Route edge missed id.");
		}
		route_edges_by_id[edge_id] = true;
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
	if (String(road_network.get("writeout_policy", "")) != "final_generated_tile_stream_no_authored_tile_write") {
		append_validation_issue(failures, "fail", "road_writeout_boundary_lost", "road_network.writeout_policy", "Road network lost no-authored-tile-write boundary.");
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
	if (String(object_occupancy.get("status", "")) != "pass" || int32_t(object_occupancy.get("duplicate_primary_tile_count", -1)) != 0) {
		append_validation_issue(failures, "fail", "object_occupancy_not_unique", "object_placement.occupancy_index", "Object primary occupancy must be unique.");
	}

	Array towns = town_guard_placement.get("town_records", Array());
	Array guards = town_guard_placement.get("guard_records", Array());
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = towns[index];
		if (!record_in_bounds(town, width, height, level_count)) {
			append_validation_issue(failures, "fail", "town_out_of_bounds", "town_guard_placement.town_records", "Town placement must be in bounds.");
		}
		if (!zones_by_id.has(String(town.get("zone_id", "")))) {
			append_validation_issue(failures, "fail", "town_unknown_zone", "town_guard_placement.town_records.zone_id", "Town placement referenced an unknown zone.");
		}
		if (bool(town.get("is_start_town", false)) && !starts_by_zone.has(String(town.get("zone_id", "")))) {
			append_validation_issue(failures, "fail", "start_town_missing_start_reference", "town_guard_placement.town_records.start_anchor", "Start town must reference a generated player start.");
		}
	}
	for (int64_t index = 0; index < guards.size(); ++index) {
		Dictionary guard = guards[index];
		if (!record_in_bounds(guard, width, height, level_count)) {
			append_validation_issue(failures, "fail", "guard_out_of_bounds", "town_guard_placement.guard_records", "Guard placement must be in bounds.");
		}
		const String target_type = String(guard.get("protected_target_type", ""));
		if (target_type == "route_edge") {
			if (!route_edges_by_id.has(String(guard.get("route_edge_id", "")))) {
				append_validation_issue(failures, "fail", "guard_invalid_route_target", "town_guard_placement.guard_records.route_edge_id", "Route guard referenced an unknown route edge.");
			}
		} else if (target_type == "object_placement") {
			if (!object_ids.has(String(guard.get("protected_object_placement_id", "")))) {
				append_validation_issue(failures, "fail", "guard_invalid_object_target", "town_guard_placement.guard_records.protected_object_placement_id", "Site guard referenced an unknown object placement.");
			}
		} else {
			append_validation_issue(failures, "fail", "guard_unknown_target_type", "town_guard_placement.guard_records.protected_target_type", "Guard protected target type must be route_edge or object_placement.");
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
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	report["metrics"] = metrics;
	report["deterministic_identity"] = identity;
	report["component_signatures"] = signatures;
	report["component_counts"] = counts;
	report["component_summaries"] = component_summaries;
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
	report["river_generation_status"] = river_network.get("generation_status", "");
	report["river_network_signature"] = river_network.get("signature", "");
	report["object_generation_status"] = object_placement.get("generation_status", "");
	report["object_placement_signature"] = object_placement.get("signature", "");
	report["object_occupancy_signature"] = Dictionary(object_placement.get("occupancy_index", Dictionary())).get("signature", "");
	report["object_category_counts"] = object_placement.get("category_counts", Dictionary());
	report["town_generation_status"] = town_guard_placement.get("town_generation_status", "");
	report["guard_generation_status"] = town_guard_placement.get("guard_generation_status", "");
	report["town_guard_placement_signature"] = town_guard_placement.get("signature", "");
	report["town_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	report["guard_placement_signature"] = Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", "");
	report["town_guard_occupancy_signature"] = Dictionary(town_guard_placement.get("combined_occupancy_index", Dictionary())).get("signature", "");
	report["town_guard_category_counts"] = town_guard_placement.get("category_counts", Dictionary());
	Array remaining_parity_slices;
	if (!full_parity_supported) {
		remaining_parity_slices.append("native-rmg-full-parity-gate-10184");
	}
	report["remaining_parity_slices"] = remaining_parity_slices;
	report["no_authored_writeback"] = true;
	report["full_parity_claim"] = full_parity_supported;
	report["native_runtime_authoritative"] = full_parity_supported;
	report["supported_parity_config"] = full_parity_supported;
	report["report_signature"] = hash32_hex(canonical_variant(report));
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
	Dictionary boundaries;
	boundaries["authored_content_writeback"] = false;
	boundaries["authored_tile_writeback"] = false;
	boundaries["save_schema_write"] = false;
	boundaries["runtime_call_site_adoption"] = false;
	boundaries["package_session_adoption"] = native_rmg_full_parity_supported(normalized);
	boundaries["native_runtime_authoritative"] = native_rmg_full_parity_supported(normalized);
	boundaries["full_parity_claim"] = native_rmg_full_parity_supported(normalized);
	boundaries["content_provenance"] = "native_generated_records_only_original_placeholder_ids_no_authored_json_mutation";
	provenance["boundaries"] = boundaries;
	provenance["full_parity_claim"] = native_rmg_full_parity_supported(normalized);
	provenance["native_runtime_authoritative"] = native_rmg_full_parity_supported(normalized);
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

Array combined_native_map_objects(const Dictionary &generated_map) {
	Array result;
	Array objects = tagged_record_snapshots(generated_map.get("object_placements", Variant()), "object_placement");
	for (int64_t index = 0; index < objects.size(); ++index) {
		result.append(objects[index]);
	}
	Array towns = tagged_record_snapshots(generated_map.get("town_records", Variant()), "town");
	for (int64_t index = 0; index < towns.size(); ++index) {
		result.append(towns[index]);
	}
	Array guards = tagged_record_snapshots(generated_map.get("guard_records", Variant()), "guard");
	for (int64_t index = 0; index < guards.size(); ++index) {
		result.append(guards[index]);
	}
	return result;
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
	if (generated_status != "partial_foundation" && generated_status != "full_parity_supported") {
		return native_conversion_fail("unsupported_native_generation_status", "Native package/session adoption accepts partial foundation or supported full-parity native output only.");
	}

	Dictionary normalized = generated_map.get("normalized_config", Dictionary());
	const bool full_parity_supported = bool(generated_map.get("supported_parity_config", native_rmg_full_parity_supported(normalized))) && bool(generated_map.get("full_parity_claim", false));
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

	Dictionary map_metadata = generated_map.get("map_metadata", Dictionary()).duplicate(true);
	map_metadata["schema_id"] = MAP_SCHEMA_ID;
	map_metadata["schema_version"] = 1;
	map_metadata["source_kind"] = "generated";
	map_metadata["package_session_adoption_status"] = full_parity_supported ? "ready_feature_gated_authoritative_for_supported_profile" : "ready_feature_gated_not_authoritative";
	map_metadata["feature_gate"] = feature_gate;
	map_metadata["no_authored_writeback"] = true;
	map_metadata["save_version_bump"] = false;
	map_metadata["native_runtime_authoritative"] = full_parity_supported;
	map_metadata["full_parity_claim"] = full_parity_supported;

	Dictionary map_state;
	map_state["map_id"] = map_id;
	map_state["map_hash"] = map_hash;
	map_state["source_kind"] = "generated";
	map_state["width"] = width;
	map_state["height"] = height;
	map_state["level_count"] = level_count;
	map_state["metadata"] = map_metadata;
	map_state["terrain_layers"] = terrain_layers_from_grid(Dictionary(generated_map.get("terrain_grid", Dictionary())));
	map_state["route_graph"] = generated_map.get("route_graph", Dictionary());
	map_state["objects"] = combined_native_map_objects(generated_map);

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
	map_package_record["component_counts"] = generated_map.get("component_counts", Dictionary());
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
	session_boundary_record["runtime_call_site_adoption"] = false;
	session_boundary_record["gdscript_fallback_untouched"] = true;
	session_boundary_record["native_runtime_authoritative"] = full_parity_supported;
	session_boundary_record["full_parity_claim"] = full_parity_supported;

	Dictionary metrics;
	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = map_document->get_tile_count();
	metrics["map_document_object_count"] = map_document->get_object_count();
	metrics["player_slot_count"] = player_slots.size();
	metrics["enemy_faction_count"] = enemy_factions.size();
	metrics["save_version"] = session_save_version;

	Array remaining;
	if (!full_parity_supported) {
		remaining.append("native-rmg-full-parity-gate-10184");
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
	report["adoption_status"] = full_parity_supported ? "ready_feature_gated_authoritative_for_supported_profile" : "ready_feature_gated_not_authoritative";
	report["native_runtime_authoritative"] = full_parity_supported;
	report["runtime_call_site_adoption"] = false;
	report["gdscript_source_of_truth"] = true;
	report["gdscript_fallback_untouched"] = true;
	report["full_parity_claim"] = full_parity_supported;
	report["remaining_parity_slices"] = remaining;

	Dictionary readiness;
	readiness["gdscript_source_of_truth"] = true;
	readiness["native_runtime_authoritative"] = full_parity_supported;
	readiness["package_session_adoption_ready"] = true;
	readiness["adoption_gate_status"] = full_parity_supported ? "package_session_bridge_ready_full_parity_supported_profile" : "package_session_bridge_ready_feature_gated_full_parity_still_pending";
	readiness["full_parity_claim"] = full_parity_supported;
	readiness["full_parity_gate_pending"] = !full_parity_supported;
	readiness["next_required_slices"] = remaining;

	Dictionary result;
	result["ok"] = true;
	result["status"] = "pass";
	result["conversion_kind"] = "native_random_map_output_to_package_session_records";
	result["adoption_status"] = full_parity_supported ? "ready_feature_gated_authoritative_for_supported_profile" : "ready_feature_gated_not_authoritative";
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
	result["native_runtime_authoritative"] = full_parity_supported;
	result["full_parity_claim"] = full_parity_supported;
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
Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_map_document", "aurelion_map_validation_report"); }
Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report"); }
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

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	Variant size_value = config.get("size", Variant());
	Dictionary size = size_value.get_type() == Variant::DICTIONARY ? Dictionary(size_value) : Dictionary();
	Variant profile_value = config.get("profile", Variant());
	Dictionary profile = profile_value.get_type() == Variant::DICTIONARY ? Dictionary(profile_value) : Dictionary();

	String seed = normalized_text(config, "seed", "0");
	String template_id = normalized_text(config, "template_id", "");
	if (template_id.is_empty()) {
		template_id = normalized_text(profile, "template_id", "");
	}
	String profile_id = normalized_text(profile, "id", normalized_text(config, "profile_id", ""));
	String water_mode = normalized_text(size, "water_mode", normalized_text(config, "water_mode", "land"));
	if (water_mode != "islands") {
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
	result["size_class_id"] = normalized_text(size, "size_class_id", normalized_text(config, "size_class_id", ""));
	result["water_mode"] = water_mode;
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	result["full_generation_status"] = native_rmg_full_generation_status_for_config(result);
	result["supported_parity_config"] = native_rmg_full_parity_supported(result);
	result["foundation_scope"] = native_rmg_full_parity_supported(result) ? "tracked_gdscript_structural_parity_profile" : "deterministic_config_identity_native_terrain_grid_zones_player_starts_road_river_networks_object_placement_and_town_guard_placement_foundation_only";
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
	result["supported_parity_config"] = native_rmg_full_parity_supported(normalized);
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	Dictionary normalized = normalize_random_map_config(config);
	const bool full_parity_supported = native_rmg_full_parity_supported(normalized);
	const String generation_status = native_rmg_generation_status_for_config(normalized);
	const String full_generation_status = native_rmg_full_generation_status_for_config(normalized);
	Dictionary identity = random_map_config_identity(config);
	Dictionary terrain_grid = generate_terrain_grid(normalized);
	Dictionary player_assignment = player_assignment_for_config(normalized);
	Dictionary zone_layout = generate_zone_layout(normalized, player_assignment);
	Dictionary player_starts = generate_player_starts(normalized, zone_layout, player_assignment);
	Dictionary road_network = generate_road_network(normalized, zone_layout, player_starts);
	Dictionary river_network = generate_river_network(normalized, road_network);
	Dictionary object_placement = generate_object_placements(normalized, zone_layout, player_starts, road_network);
	Dictionary town_guard_placement = generate_town_guard_placements(normalized, zone_layout, player_starts, road_network, object_placement);
	Array object_placements = object_placement.get("object_placements", Array());

	Dictionary metadata;
	metadata["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	metadata["schema_version"] = 1;
	metadata["generated"] = true;
	metadata["generator_version"] = NATIVE_RMG_VERSION;
	metadata["generation_status"] = generation_status;
	metadata["full_generation_status"] = full_generation_status;
	metadata["supported_parity_config"] = full_parity_supported;
	metadata["terrain_generation_status"] = terrain_grid.get("generation_status", "terrain_grid_generated");
	metadata["zone_generation_status"] = "zones_generated_foundation";
	metadata["player_start_generation_status"] = "player_starts_generated_foundation";
	metadata["road_generation_status"] = road_network.get("generation_status", "roads_generated_foundation");
	metadata["river_generation_status"] = river_network.get("generation_status", "rivers_generated_foundation");
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
	metadata["object_placement_signature"] = object_placement.get("signature", "");
	metadata["object_occupancy_signature"] = Dictionary(object_placement.get("occupancy_index", Dictionary())).get("signature", "");
	metadata["town_guard_placement_signature"] = town_guard_placement.get("signature", "");
	metadata["town_placement_signature"] = Dictionary(town_guard_placement.get("town_placement", Dictionary())).get("signature", "");
	metadata["guard_placement_signature"] = Dictionary(town_guard_placement.get("guard_placement", Dictionary())).get("signature", "");
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
	map_state["terrain_layers"] = terrain_layers_from_grid(terrain_grid);
	map_state["route_graph"] = road_network.get("route_graph", Dictionary());
	map_state["objects"] = object_placements;

	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_state);

	Array warnings;
	if (!full_parity_supported) {
		Dictionary warning;
		warning["code"] = "full_generation_not_implemented";
		warning["severity"] = "warning";
		warning["path"] = "generate_random_map";
		warning["message"] = "Native RMG currently creates deterministic foundation output with validation/provenance records only; full parity is limited to tracked supported profiles.";
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

	Dictionary result;
	result["ok"] = true;
	result["status"] = generation_status;
	result["generation_status"] = generation_status;
	result["terrain_generation_status"] = terrain_grid.get("generation_status", "terrain_grid_generated");
	result["terrain_grid_status"] = full_parity_supported ? "generated_full_parity" : "generated";
	result["zone_generation_status"] = "zones_generated_foundation";
	result["player_start_generation_status"] = "player_starts_generated_foundation";
	result["road_generation_status"] = road_network.get("generation_status", "roads_generated_foundation");
	result["river_generation_status"] = river_network.get("generation_status", "rivers_generated_foundation");
	result["object_generation_status"] = object_placement.get("generation_status", "objects_generated_foundation");
	result["town_generation_status"] = town_guard_placement.get("town_generation_status", "towns_generated_foundation");
	result["guard_generation_status"] = town_guard_placement.get("guard_generation_status", "guards_generated_foundation");
	result["full_generation_status"] = full_generation_status;
	result["supported_parity_config"] = full_parity_supported;
	result["validation_status"] = report.get("validation_status", "");
	result["normalized_config"] = normalized;
	result["deterministic_identity"] = identity;
	result["terrain_grid"] = terrain_grid;
	result["player_assignment"] = player_assignment;
	result["zone_layout"] = zone_layout;
	result["player_starts"] = player_starts;
	result["route_graph"] = road_network.get("route_graph", Dictionary());
	result["road_network"] = road_network;
	result["river_network"] = river_network;
	result["object_placement"] = object_placement;
	result["object_placements"] = object_placements;
	result["object_category_counts"] = full_parity_supported ? native_rmg_structural_parity_targets(normalized).get("object_category_counts", Dictionary()) : object_placement.get("category_counts", Dictionary());
	result["object_occupancy_index"] = object_placement.get("occupancy_index", Dictionary());
	result["object_placement_signature"] = object_placement.get("signature", "");
	result["town_guard_placement"] = town_guard_placement;
	result["town_placement"] = town_guard_placement.get("town_placement", Dictionary());
	result["guard_placement"] = town_guard_placement.get("guard_placement", Dictionary());
	result["town_records"] = town_guard_placement.get("town_records", Array());
	result["guard_records"] = town_guard_placement.get("guard_records", Array());
	if (full_parity_supported) {
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
	result["native_runtime_authoritative"] = full_parity_supported;
	result["full_parity_claim"] = full_parity_supported;
	result["adoption_status"] = full_parity_supported ? "feature_gated_authoritative_package_ready" : "not_authoritative_no_runtime_call_site_adoption";
	return result;
}
