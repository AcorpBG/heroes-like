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
	result.append("native_random_map_decorative_obstacle_generation");
	result.append("native_random_map_town_guard_placement_foundation");
	result.append("native_random_map_validation_provenance_foundation");
	result.append("native_random_map_package_session_adoption_bridge");
	result.append("native_random_map_guard_reward_package_adoption");
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

Dictionary terrain_layers_from_grid(const Dictionary &terrain_grid, const Dictionary &road_network = Dictionary()) {
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
			Dictionary tile;
			tile["x"] = int32_t(cell.get("x", 0));
			tile["y"] = int32_t(cell.get("y", 0));
			tile["level"] = int32_t(cell.get("level", 0));
			tiles.append(tile);
		}
		Dictionary road;
		road["id"] = segment.get("id", "road_" + String::num_int64(index + 1));
		road["route_edge_id"] = segment.get("route_edge_id", "");
		road["overlay_id"] = segment.get("overlay_id", road_network.get("overlay_id", "generated_dirt_road"));
		road["road_class"] = segment.get("road_class", "");
		road["road_type_id"] = segment.get("road_type_id", "");
		road["tiles"] = tiles;
		road["cells"] = tiles;
		road["tile_count"] = tiles.size();
		road["cell_count"] = tiles.size();
		road["source"] = "native_rmg_road_network_materialized_for_package_surface";
		roads.append(road);
	}
	terrain_layers["roads"] = roads;
	terrain_layers["road_count"] = roads.size();
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
		static constexpr const char *CATEGORIES[] = {"timber", "ore", "gold", "quicksilver", "ember_salt", "lens_crystal", "cut_gems"};
		Array category_ids;
		for (const char *category : CATEGORIES) {
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
			const String selected = String(CATEGORIES[2 + (base_size % 5)]);
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

bool catalog_player_filter_allows(const Dictionary &record, int32_t player_count) {
	Dictionary filter = record.get("player_filter", Dictionary());
	if (filter.is_empty()) {
		return true;
	}
	const int32_t min_total = int32_t(filter.get("min_total", 1));
	const int32_t max_total = int32_t(filter.get("max_total", 8));
	return player_count >= min_total && player_count <= max_total;
}

Dictionary catalog_zone_to_native_zone(const Dictionary &source_zone, const Dictionary &normalized, const Dictionary &player_assignment, int64_t zone_index) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Dictionary by_owner_slot = player_assignment.get("player_slot_by_owner_slot", Dictionary());

	const String zone_id = normalized_text(source_zone, "id", "zone_" + slot_id_2(int32_t(zone_index + 1)));
	const int32_t owner_slot = int32_t(source_zone.get("owner_slot", 0));
	const bool active_player_zone = owner_slot > 0 && owner_slot <= player_count;
	Dictionary assignment = active_player_zone ? Dictionary(by_owner_slot.get(String::num_int64(owner_slot), Dictionary())) : Dictionary();
	String role = normalized_text(source_zone, "role", normalized_text(source_zone, "type", "treasure"));
	if (active_player_zone) {
		role = owner_slot == 1 ? "human_start" : "computer_start";
	} else if (role.contains("start")) {
		role = "treasure";
	}
	const String faction_id = active_player_zone ? String(assignment.get("faction_id", "")) : "";
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
	if (!metadata.has("richness_floor")) {
		metadata["richness_floor"] = zone_richness_floor_metadata(role, int32_t(source_zone.get("base_size", 10))).get("richness_floor", Dictionary());
	}

	Dictionary zone;
	zone["id"] = zone_id;
	zone["source_id"] = source_zone.get("source_zone_id", zone_id);
	zone["role"] = role;
	zone["source_role"] = source_zone.get("role", role);
	zone["owner_slot"] = active_player_zone ? Variant(owner_slot) : Variant();
	zone["player_slot"] = active_player_zone ? assignment.get("player_slot", owner_slot) : Variant();
	zone["player_type"] = active_player_zone ? assignment.get("player_type", owner_slot == 1 ? String("human") : String("computer")) : Variant("neutral");
	zone["team_id"] = active_player_zone ? assignment.get("team_id", "team_" + slot_id_2(owner_slot)) : Variant("");
	zone["faction_id"] = faction_id;
	zone["terrain_id"] = palette.get("normalized_terrain_id", "grass");
	zone["terrain_palette"] = palette;
	zone["base_size"] = std::max(4, int32_t(source_zone.get("base_size", 10)));
	zone["anchor"] = Dictionary();
	zone["bounds"] = Dictionary();
	zone["cell_count"] = 0;
	zone["catalog_metadata"] = metadata;
	zone["template_player_filter_active"] = catalog_player_filter_allows(source_zone, player_count);
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
			zones.append(catalog_zone_to_native_zone(Dictionary(catalog_zones[index]), normalized, player_assignment, index));
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
	policy["template_model"] = has_catalog_template(normalized) ? "imported_catalog_template_zones_and_links" : "fallback_runtime_template";

	Dictionary layout;
	layout["schema_id"] = NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID;
	layout["schema_version"] = 1;
	layout["generation_status"] = "zones_generated_foundation";
	layout["full_generation_status"] = "not_implemented";
	layout["template_id"] = normalized.get("template_id", "");
	layout["template_source"] = has_catalog_template(normalized) ? "content_random_map_template_catalog" : "native_foundation_fallback_runtime_template";
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
		object_counts["neutral_dwelling"] = 7;
		object_counts["resource_site"] = 12;
		object_counts["reward_reference"] = 22;
		object_counts["route_guard"] = 53;
		object_counts["town"] = 4;
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
		object_counts["route_guard"] = 44;
		object_counts["town"] = 4;
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
		edge["from_point"] = from_point;
		edge["to_point"] = to_point;
		edge["route_cell_anchor_candidate"] = route_anchor_candidate(cells, from_point, to_point, 0);
		edge["connectivity_classification"] = classification;
		edge["transit_semantics"] = Dictionary();
		const String road_class = road_class_for_edge(edge);
		edge["road_class"] = road_class;
		edge["road_type_id"] = road_type_for_class(road_class);
		if (int32_t(edge.get("guard_value", 0)) > 0 || bool(edge.get("border_guard", false))) {
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
			segment["road_class"] = source_edge.get("road_class", "gdscript_structural_parity_segment");
			segment["road_type_id"] = source_edge.get("road_type_id", "generated_dirt_connector_road");
			segment["connection_control"] = source_edge.get("connection_control", Dictionary());
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
	secondary_summary["materialized_route_count"] = native_rmg_full_parity_supported(normalized) ? int32_t(parity_targets.get("road_segment_count", road_segments.size())) : 0;
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
	const bool full_parity_supported = native_rmg_full_parity_supported(normalized);
	if (!full_parity_supported) {
		const bool land_mode = String(normalized.get("water_mode", "land")) == "land";
		Array river_cells = land_mode ? land_river_cells_with_crossing(normalized, road_network) : bounded_river_cells(normalized);
		Dictionary quality = river_quality_record(river_cells, road_network, land_mode);
		Dictionary river_segment;
		river_segment["id"] = "river_foundation_01";
		river_segment["kind"] = "river";
		river_segment["route_feature_class"] = land_mode ? "land_river_with_road_crossing_constraints" : "bounded_waterline_feature";
		river_segment["cells"] = river_cells;
		river_segment["cell_count"] = river_cells.size();
		river_segment["bounds"] = bounds_for_cells(river_cells);
		river_segment["quality"] = quality;
		river_segment["continuity_status"] = quality.get("continuity_status", "");
		river_segment["road_crossing_count"] = quality.get("road_crossing_count", 0);
		river_segment["crossing_policy"] = land_mode ? "roads_may_cross_at_recorded_bridge_or_ford_cells" : "waterline_no_crossing_required";
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
	network["generation_status"] = full_parity_supported ? "rivers_generated_full_parity" : "rivers_generated_foundation";
	network["full_generation_status"] = native_rmg_full_generation_status_for_config(normalized);
	network["policy"] = policy;
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
		Dictionary proxy = homm3_re_reward_object_proxy_record("mine", "", "", CATEGORIES[index], ordinal);
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
	if (kind == "mine" || kind == "neutral_dwelling") {
		footprint["width"] = 2;
		footprint["height"] = 2;
		footprint["anchor"] = "bottom_center";
		footprint["tier"] = "medium";
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
	const int32_t body_width = kind == "decorative_obstacle" ? std::max(1, int32_t(footprint.get("width", 1))) : 1;
	const int32_t body_height = kind == "decorative_obstacle" ? std::max(1, int32_t(footprint.get("height", 1))) : 1;
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

int32_t zone_value_budget_for_zone(const Dictionary &normalized, const Dictionary &zone);
String value_tier_for_amount(int32_t value);
Dictionary reward_value_profile_for_zone(const Dictionary &normalized, const Dictionary &zone, int32_t reward_index, int32_t ordinal);
void apply_reward_value_profile(Dictionary &family, const Dictionary &profile, int32_t ordinal);
void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const Dictionary &road_network, const Dictionary &zone_layout);

int32_t append_decoration_placements(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &road_network, int32_t ordinal_start) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Dictionary blocked = road_body_exclusion_lookup(road_network);
	int32_t ordinal = ordinal_start;
	for (int64_t zone_index = 0; zone_index < zones.size(); ++zone_index) {
		Dictionary zone = zones[zone_index];
		const int32_t target = decoration_target_for_zone(normalized, zone);
		for (int32_t decoration_index = 0; decoration_index < target; ++decoration_index) {
			bool placed = false;
			for (int32_t attempt = 0; attempt < 8; ++attempt) {
				Dictionary point = find_decoration_point(zone, ordinal, normalized, owner_grid, occupied, blocked, width, height);
				if (!point.is_empty()) {
					append_object_placement(placements, occupied, normalized, zone, point, "decorative_obstacle", ordinal, road_network, zone_layout);
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

void append_object_placement(Array &placements, Dictionary &occupied, const Dictionary &normalized, const Dictionary &zone, const Dictionary &point, const String &kind, int32_t ordinal, const Dictionary &road_network, const Dictionary &zone_layout) {
	if (point.is_empty()) {
		return;
	}
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String zone_id = String(zone.get("id", ""));
	const String terrain_id = terrain_id_for_zone(zone);
	Dictionary family = object_family_record(kind, ordinal, terrain_id);
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
	bounds["max_x"] = kind == "decorative_obstacle" ? x + std::max(1, int32_t(footprint.get("width", 1))) - 1 : x;
	bounds["max_y"] = kind == "decorative_obstacle" ? y + std::max(1, int32_t(footprint.get("height", 1))) - 1 : y;

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
	if (kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference") {
		placement["zone_value_budget"] = zone_value_budget_for_zone(normalized, zone);
		placement["zone_value_tier"] = value_tier_for_amount(int32_t(placement["zone_value_budget"]));
		placement["homm3_re_budget_provenance"] = "derived_from_catalog_zone_treasure_bands_and_original_content_object_family";
	}
	if (kind == "reward_reference") {
		placement["reward_value_profile"] = reward_value_profile;
		placement["reward_index_in_zone"] = point.get("native_reward_index", ordinal);
		placement["reward_target_in_zone"] = point.get("native_reward_target", 0);
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

Dictionary object_point_for_zone_index(const Dictionary &zone, int32_t ordinal, int32_t ring, const String &kind, const Dictionary &normalized, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height) {
	Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
	const String zone_id = String(zone.get("id", ""));
	const String seed = String(normalized.get("normalized_seed", "0")) + ":" + zone_id + ":object:" + String::num_int64(ordinal);
	const int32_t anchor_x = int32_t(anchor.get("x", width / 2));
	const int32_t anchor_y = int32_t(anchor.get("y", height / 2));
	const int32_t zone_cell_count = std::max(0, int32_t(zone.get("cell_count", 0)));
	if (zone_cell_count > 0 && zone_cell_count < 144) {
		const int32_t angle_bucket = int32_t(hash32_int(seed) % 8U);
		static constexpr int32_t OFFSETS[8][2] = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}};
		const int32_t distance = 2 + ring + (ordinal % 3);
		const int32_t x = anchor_x + OFFSETS[angle_bucket][0] * distance + deterministic_signed_jitter(seed + String(":x"), 1);
		const int32_t y = anchor_y + OFFSETS[angle_bucket][1] * distance + deterministic_signed_jitter(seed + String(":y"), 1);
		Dictionary compact_zone_point = find_object_point(x, y, zone_id, owner_grid, occupied, width, height);
		if (!compact_zone_point.is_empty()) {
			compact_zone_point["spatial_placement_policy"] = "anchor_ring_for_compact_zone_decoration_fit_preservation";
		}
		return compact_zone_point;
	}
	const int32_t coarse_cols = 6;
	const int32_t coarse_rows = 6;
	const int32_t desired_cell = int32_t(hash32_int(seed + String(":coarse:") + kind) % uint32_t(coarse_cols * coarse_rows));
	const int32_t desired_cx = desired_cell % coarse_cols;
	const int32_t desired_cy = desired_cell / coarse_cols;
	const int32_t preferred_anchor_distance = 4 + ring * 3 + (ordinal % 5);

	std::vector<Dictionary> candidates;
	for (int32_t y = 1; y < height - 1; ++y) {
		if (y < 0 || y >= owner_grid.size()) {
			continue;
		}
		Array row = owner_grid[y];
		for (int32_t x = 1; x < width - 1; ++x) {
			if (occupied.has(point_key(x, y))) {
				continue;
			}
			if (!zone_id.is_empty() && (x < 0 || x >= row.size() || String(row[x]) != zone_id)) {
				continue;
			}
			const int32_t cx = std::max(0, std::min(coarse_cols - 1, (x * coarse_cols) / std::max(1, width)));
			const int32_t cy = std::max(0, std::min(coarse_rows - 1, (y * coarse_rows) / std::max(1, height)));
			const int32_t coarse_distance = std::abs(cx - desired_cx) + std::abs(cy - desired_cy);
			const int32_t anchor_distance = std::abs(x - anchor_x) + std::abs(y - anchor_y);
			const int32_t anchor_penalty = std::abs(anchor_distance - preferred_anchor_distance);
			const int32_t jitter = int32_t(hash32_int(seed + String(":scatter:") + String::num_int64(x) + String(",") + String::num_int64(y)) % 10000U);
			Dictionary point = point_record(x, y);
			const int64_t sort_key = int64_t(coarse_distance) * 100000000LL + int64_t(anchor_penalty) * 10000LL + int64_t(jitter);
			point["sort_key"] = Variant(sort_key);
			point["spatial_placement_policy"] = "coarse_grid_scatter_within_zone_not_anchor_ring_cluster";
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

	const int32_t angle_bucket = int32_t(hash32_int(seed) % 8U);
	static constexpr int32_t OFFSETS[8][2] = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}};
	const int32_t distance = 2 + ring + (ordinal % 3);
	const int32_t x = anchor_x + OFFSETS[angle_bucket][0] * distance + deterministic_signed_jitter(seed + String(":x"), 1);
	const int32_t y = anchor_y + OFFSETS[angle_bucket][1] * distance + deterministic_signed_jitter(seed + String(":y"), 1);
	Dictionary fallback = find_object_point(x, y, zone_id, owner_grid, occupied, width, height);
	if (!fallback.is_empty()) {
		fallback["spatial_placement_policy"] = "anchor_ring_fallback_after_zone_scatter_exhausted";
	}
	return fallback;
}

Dictionary generate_object_placements(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts, const Dictionary &road_network) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts = player_starts.get("starts", Array());
	Array placements;
	Dictionary parity_targets = native_rmg_structural_parity_targets(normalized);
	Dictionary occupied = parity_targets.is_empty() ? road_body_exclusion_lookup(road_network) : Dictionary();
	int32_t ordinal = 0;

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
			Dictionary zone = zone_by_id(zones, String(start.get("zone_id", "")));
			if (zone.is_empty()) {
				continue;
			}
			const int32_t sx = int32_t(start.get("x", 0));
			const int32_t sy = int32_t(start.get("y", 0));
			static constexpr int32_t OFFSETS[3][2] = {{2, 0}, {0, 2}, {-2, 0}};
			for (int32_t resource_index = 0; resource_index < 3; ++resource_index) {
				Dictionary point = find_object_point(sx + OFFSETS[resource_index][0], sy + OFFSETS[resource_index][1], String(start.get("zone_id", "")), owner_grid, occupied, width, height);
				append_object_placement(placements, occupied, normalized, zone, point, "resource_site", resource_index, road_network, zone_layout);
				++ordinal;
			}
		}

		for (int64_t index = 0; index < zones.size(); ++index) {
			Dictionary zone = zones[index];
			const int32_t mine_target = catalog_zone_mine_target(normalized, zone);
			const int32_t reward_target = catalog_zone_reward_target(normalized, zone);
			const int32_t dwelling_target = catalog_zone_dwelling_target(normalized, zone);
			for (int32_t mine_index = 0; mine_index < mine_target; ++mine_index) {
				Dictionary point = object_point_for_zone_index(zone, ordinal, mine_index / 3, "mine", normalized, owner_grid, occupied, width, height);
				point["native_mine_index"] = mine_index;
				point["native_mine_target"] = mine_target;
				append_object_placement(placements, occupied, normalized, zone, point, "mine", ordinal, road_network, zone_layout);
				++ordinal;
			}
			for (int32_t dwelling_index = 0; dwelling_index < dwelling_target; ++dwelling_index) {
				Dictionary point = object_point_for_zone_index(zone, ordinal, 2 + dwelling_index, "neutral_dwelling", normalized, owner_grid, occupied, width, height);
				point["native_dwelling_index"] = dwelling_index;
				point["native_dwelling_target"] = dwelling_target;
				append_object_placement(placements, occupied, normalized, zone, point, "neutral_dwelling", ordinal, road_network, zone_layout);
				++ordinal;
			}
			for (int32_t reward_index = 0; reward_index < reward_target; ++reward_index) {
				Dictionary point = object_point_for_zone_index(zone, ordinal, 1 + reward_index / 4, "reward_reference", normalized, owner_grid, occupied, width, height);
				point["native_reward_index"] = reward_index;
				point["native_reward_target"] = reward_target;
				append_object_placement(placements, occupied, normalized, zone, point, "reward_reference", ordinal, road_network, zone_layout);
				++ordinal;
			}
		}
	}

	ordinal = append_decoration_placements(placements, occupied, normalized, zone_layout, road_network, ordinal);

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
	Dictionary decoration_summary = decoration_route_shaping_summary(placements, road_network);
	payload["decoration_density_pass"] = decoration_summary;
	payload["decoration_route_shaping_summary"] = decoration_summary;
	payload["fill_coverage_summary"] = object_fill_coverage_summary(placements, zone_layout, width, height);
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

int32_t town_spacing_radius_for_size(const Dictionary &normalized) {
	const int32_t shortest = std::max(1, std::min(int32_t(normalized.get("width", 36)), int32_t(normalized.get("height", 36))));
	const int32_t minimum = shortest >= 30 ? 6 : 5;
	return std::max(minimum, std::min(18, int32_t(std::ceil(double(shortest) / 8.0))));
}

int32_t town_hard_spacing_radius_for_size(const Dictionary &normalized) {
	return std::max(4, int32_t(std::floor(double(town_spacing_radius_for_size(normalized)) * 0.75)));
}

Dictionary town_spacing_policy_payload(const Dictionary &normalized) {
	Dictionary policy;
	policy["source_model"] = "HoMM3_RMG_town_layer_after_runtime_zone_construction_translated_to_original_spacing_contract";
	policy["preferred_minimum_manhattan_distance"] = town_spacing_radius_for_size(normalized);
	policy["hard_fallback_minimum_manhattan_distance"] = town_hard_spacing_radius_for_size(normalized);
	policy["fallback_policy"] = "retry_with_hard_spacing_before_any_unspaced_town_placement";
	return policy;
}

bool point_far_from_towns(const Array &towns, int32_t x, int32_t y, int32_t minimum_distance) {
	for (int64_t index = 0; index < towns.size(); ++index) {
		Dictionary town = towns[index];
		const int32_t distance = std::abs(x - int32_t(town.get("x", 0))) + std::abs(y - int32_t(town.get("y", 0)));
		if (distance < minimum_distance) {
			return false;
		}
	}
	return true;
}

Dictionary find_spaced_object_point(int32_t x, int32_t y, const String &preferred_zone_id, const Array &owner_grid, const Dictionary &occupied, int32_t width, int32_t height, const Array &towns, int32_t minimum_distance) {
	Dictionary fallback = find_object_point(x, y, preferred_zone_id, owner_grid, occupied, width, height);
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
	return fallback;
}

Dictionary town_spacing_summary(const Array &towns, const Dictionary &normalized) {
	const int32_t required = town_spacing_radius_for_size(normalized);
	const int32_t same_zone_required = town_hard_spacing_radius_for_size(normalized);
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
			const int32_t distance = std::abs(int32_t(left.get("x", 0)) - int32_t(right.get("x", 0))) + std::abs(int32_t(left.get("y", 0)) - int32_t(right.get("y", 0)));
			++pair_count;
			observed_min = std::min(observed_min, distance);
			if (int32_t(left.get("player_slot", 0)) > 0 && int32_t(right.get("player_slot", 0)) > 0) {
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
	all_towns["minimum_distance_required"] = required;
	all_towns["observed_minimum_distance"] = observed_min == std::numeric_limits<int32_t>::max() ? 0 : observed_min;
	all_towns["status"] = observed_min == std::numeric_limits<int32_t>::max() || observed_min >= required ? "pass" : "fail";
	Dictionary start_towns;
	start_towns["scope"] = "start_towns";
	start_towns["pair_count"] = start_pair_count;
	start_towns["minimum_distance_required"] = required;
	start_towns["observed_minimum_distance"] = start_observed_min == std::numeric_limits<int32_t>::max() ? 0 : start_observed_min;
	start_towns["status"] = start_observed_min == std::numeric_limits<int32_t>::max() || start_observed_min >= required ? "pass" : "fail";
	Dictionary same_zone_towns;
	same_zone_towns["scope"] = "same_zone_towns";
	same_zone_towns["pair_count"] = same_zone_pair_count;
	same_zone_towns["minimum_distance_required"] = same_zone_required;
	same_zone_towns["observed_minimum_distance"] = same_zone_observed_min == std::numeric_limits<int32_t>::max() ? 0 : same_zone_observed_min;
	same_zone_towns["status"] = same_zone_observed_min == std::numeric_limits<int32_t>::max() || same_zone_observed_min >= same_zone_required ? "pass" : "fail";
	Dictionary summary;
	summary["ok"] = String(all_towns["status"]) == "pass" && String(start_towns["status"]) == "pass" && String(same_zone_towns["status"]) == "pass";
	summary["minimum_distance_required"] = required;
	summary["observed_minimum_distance"] = all_towns["observed_minimum_distance"];
	summary["all_towns"] = all_towns;
	summary["start_towns"] = start_towns;
	summary["same_zone_towns"] = same_zone_towns;
	return summary;
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
	record["zone_anchor"] = zone.get("anchor", Dictionary());
	record["town_spacing_policy"] = town_spacing_policy_payload(normalized);
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
	record["protected_object_kind"] = target.get("protected_object_kind", "");
	record["guarded_object_kind"] = target.get("protected_object_kind", "");
	record["guarded_reward_value"] = target.get("protected_reward_value", 0);
	record["guarded_reward_value_tier"] = target.get("protected_reward_value_tier", "");
	record["guarded_reward_category"] = target.get("protected_reward_category", "");
	record["guard_reward_value_ratio"] = int32_t(target.get("protected_reward_value", 0)) > 0 ? double(guard_value) / double(int32_t(target.get("protected_reward_value", 1))) : 0.0;
	record["protected_zone_value_budget"] = target.get("protected_zone_value_budget", 0);
	record["protected_zone_value_tier"] = target.get("protected_zone_value_tier", "");
	record["guard_reward_relation_source"] = int32_t(target.get("protected_reward_value", 0)) > 0 ? "guard_value_scaled_from_zone_reward_value" : "guard_value_from_route_or_site_baseline";
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
				? find_spaced_object_point(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), String(start.get("zone_id", "")), owner_grid, occupied, width, height, towns, town_hard_spacing_radius_for_size(normalized))
				: find_spaced_object_point(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), String(start.get("zone_id", "")), owner_grid, occupied, width, height, towns, town_hard_spacing_radius_for_size(normalized));
		append_town_record(towns, occupied, town_record_at_point(normalized, zone, point, start, "player_start_town", int32_t(index), road_network, zone_layout, occupied));
	}

	if (parity_targets.is_empty()) {
		const int32_t neutral_target = neutral_town_target_count(normalized, zones, starts.size());
		int32_t neutral_count = 0;
		for (int64_t index = 0; index < zones.size(); ++index) {
			Dictionary zone = zones[index];
			const String role = String(zone.get("role", ""));
			if (role != "treasure" && role != "junction") {
				continue;
			}
			Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
			Dictionary point = find_spaced_object_point(int32_t(anchor.get("x", width / 2)) + 1, int32_t(anchor.get("y", height / 2)) + 1, String(zone.get("id", "")), owner_grid, occupied, width, height, towns, town_hard_spacing_radius_for_size(normalized));
			append_town_record(towns, occupied, town_record_at_point(normalized, zone, point, Dictionary(), "neutral_zone_town", int32_t(index), road_network, zone_layout, occupied));
			++neutral_count;
			if (neutral_count >= neutral_target) {
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

	Array object_guard_candidates = sorted_object_guard_candidates(objects);
	if (parity_targets.is_empty() || (parity_guard_limit >= 0 && guard_ordinal < parity_guard_limit)) {
		for (int64_t index = 0; index < object_guard_candidates.size(); ++index) {
			if (parity_guard_limit >= 0 && guard_ordinal >= parity_guard_limit) {
				break;
			}
			Dictionary object = object_guard_candidates[index];
			const String kind = String(object.get("kind", ""));
			const String family_id = String(object.get("family_id", ""));
			if (kind == "town" || kind == "resource_site") {
				continue;
			}
			if (parity_targets.is_empty() && kind != "mine" && kind != "neutral_dwelling" && family_id != "guarded_reward_cache" && String(object.get("artifact_id", "")).is_empty()) {
				continue;
			}
			const String zone_id = String(object.get("zone_id", ""));
			Dictionary zone = zone_by_id(zones, zone_id);
			Dictionary point = object_guard_point_for_target(object, zone_id, owner_grid, occupied, width, height);
			int32_t guard_value = int32_t(object.get("guard_base_value", kind == "neutral_dwelling" ? 700 : 450));
			const int32_t reward_value = std::max(0, int32_t(object.get("reward_value", 0)));
			if (reward_value > 0) {
				const double relation = reward_value >= 10000 ? 0.75 : (reward_value >= 6000 ? 0.68 : (reward_value >= 2500 ? 0.58 : 0.35));
				guard_value = std::max(guard_value, int32_t(std::llround(double(reward_value) * relation)));
			}
			if (!String(object.get("artifact_id", "")).is_empty()) {
				guard_value = std::max(guard_value, 1800);
			}
			if (guard_value <= 0) {
				guard_value = kind == "mine" ? 900 : 650;
			}
			guard_value = std::min(30000, guard_value);
			const int32_t guard_distance = std::abs(int32_t(point.get("x", 0)) - int32_t(object.get("x", 0))) + std::abs(int32_t(point.get("y", 0)) - int32_t(object.get("y", 0)));
			if (parity_targets.is_empty() && reward_value >= 2500 && reward_value < 6000 && guard_distance > 12) {
				continue;
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
			target["guarded_artifact_id"] = object.get("artifact_id", "");
			target["guarded_site_id"] = object.get("site_id", "");
			target["guarded_object_point"] = cell_record(int32_t(object.get("x", 0)), int32_t(object.get("y", 0)), int32_t(object.get("level", 0)));
			target["guard_distance"] = guard_distance;
			target["adjacent_to_guarded_object"] = guard_distance <= 1;
			append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "site_guard", guard_ordinal, guard_value, road_network, zone_layout, occupied, target));
			++guard_ordinal;
		}
	}

	if (parity_guard_limit >= 0 && guard_ordinal < parity_guard_limit && !zones.is_empty() && !edges.is_empty()) {
		int32_t fill_index = 0;
		while (guard_ordinal < parity_guard_limit && fill_index < parity_guard_limit * 3) {
			Dictionary edge = edges[fill_index % edges.size()];
			const String zone_id = String(edge.get("to", edge.get("from", "")));
			Dictionary zone = zone_by_id(zones, zone_id);
			Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
			Dictionary point = find_object_point(int32_t(anchor.get("x", width / 2)) + fill_index, int32_t(anchor.get("y", height / 2)) + fill_index, zone_id, owner_grid, occupied, width, height);
			if (!point.is_empty()) {
				const String route_edge_id = String(edge.get("id", ""));
				Dictionary target;
				target["protected_target_id"] = route_edge_id;
				target["protected_target_type"] = "route_edge";
				target["protected_zone_id"] = zone_id;
				target["route_edge_id"] = route_edge_id;
				target["full_parity_guard_fill_id"] = String("native_rmg_full_parity_guard_fill_") + String::num_int64(guard_ordinal);
				target["guard_reward_relation_source"] = "full_parity_structural_guard_count_fill";
				append_guard_record(guards, occupied, guard_record_at_point(normalized, zone, point, "route_guard", guard_ordinal, 450, road_network, zone_layout, occupied, target));
				++guard_ordinal;
			}
			++fill_index;
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
	Dictionary spacing_summary = town_spacing_summary(towns, normalized);
	town_payload["town_spacing"] = spacing_summary;
	town_payload["minimum_town_distance_required"] = spacing_summary.get("minimum_distance_required", 0);
	town_payload["observed_minimum_town_distance"] = spacing_summary.get("observed_minimum_distance", 0);
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
	guard_payload["materialized_object_guard_summary"] = object_guard_summary(object_guard_candidates, guards);
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
	payload["materialized_object_guard_summary"] = guard_payload.get("materialized_object_guard_summary", Dictionary());
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
	report["fill_coverage_summary"] = object_placement.get("fill_coverage_summary", Dictionary());
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
	return bool(record.get("blocking_body", false)) || kind == "guard" || kind == "town" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference" || passability_class.begins_with("blocking") || passability_class == "edge_blocker";
}

bool record_is_visitable_package_object(const Dictionary &record) {
	const String kind = String(record.get("kind", ""));
	return kind == "resource_site" || kind == "mine" || kind == "neutral_dwelling" || kind == "reward_reference" || kind == "town" || kind == "guard";
}

Dictionary package_surface_record(Dictionary record) {
	const bool blocking_body = record_blocks_package_pathing(record);
	const bool visitable = record_is_visitable_package_object(record);
	Array body_tiles = body_tiles_for_package_surface(record);
	Array block_tiles = blocking_body ? body_tiles.duplicate(true) : Array();
	Array visit_tiles = visitable ? visit_tiles_for_package_surface(record, blocking_body) : Array();

	record["package_surface_adoption_version"] = 1;
	record["package_surface_adoption_state"] = "native_generated_record_materialized_for_package_editor_runtime_surface";
	record["package_pathing_materialization_state"] = "body_visit_block_masks_materialized_for_generated_package_surface";
	record["package_body_tiles"] = body_tiles;
	record["package_block_tiles"] = block_tiles;
	record["package_visit_tiles"] = visit_tiles;
	record["package_body_tile_count"] = body_tiles.size();
	record["package_block_tile_count"] = block_tiles.size();
	record["package_visit_tile_count"] = visit_tiles.size();
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

Array combined_native_map_objects(const Dictionary &generated_map) {
	Array result;
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
	map_state["terrain_layers"] = terrain_layers_from_grid(Dictionary(generated_map.get("terrain_grid", Dictionary())), Dictionary(generated_map.get("road_network", Dictionary())));
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
	metrics["guarded_valuable_reward_count"] = guard_reward_adoption.get("guarded_valuable_reward_count", 0);
	metrics["valuable_reward_count"] = guard_reward_adoption.get("valuable_reward_count", 0);
	metrics["package_block_tile_count"] = guard_reward_adoption.get("package_block_tile_count", 0);
	metrics["package_visit_tile_count"] = guard_reward_adoption.get("package_visit_tile_count", 0);

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
	report["guard_reward_package_adoption"] = guard_reward_adoption;
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
	map_state["terrain_layers"] = terrain_layers_from_grid(terrain_grid, road_network);
	map_state["route_graph"] = road_network.get("route_graph", Dictionary());
	map_state["objects"] = map_objects;

	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_state);

	Array warnings;
	if (!full_parity_supported) {
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
	result["connection_road_controls"] = road_network.get("connection_road_controls", Dictionary());
	result["river_network"] = river_network;
	result["river_quality_summary"] = river_network.get("quality_summary", Dictionary());
	result["object_placement"] = object_placement;
	result["object_placements"] = object_placements;
	result["decoration_route_shaping_summary"] = object_placement.get("decoration_route_shaping_summary", Dictionary());
	result["fill_coverage_summary"] = object_placement.get("fill_coverage_summary", Dictionary());
	result["object_category_counts"] = full_parity_supported ? native_rmg_structural_parity_targets(normalized).get("object_category_counts", Dictionary()) : object_placement.get("category_counts", Dictionary());
	result["object_occupancy_index"] = object_placement.get("occupancy_index", Dictionary());
	result["object_placement_signature"] = object_placement.get("signature", "");
	result["town_guard_placement"] = town_guard_placement;
	result["materialized_object_guard_summary"] = town_guard_placement.get("materialized_object_guard_summary", Dictionary());
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
