#include "map_package_service.hpp"

#include "h3maped_rmg_core.hpp"
#include "rmg_data_model.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *MAP_PACKAGE_SCHEMA_ID = "aurelion_map_package";
constexpr const char *SCENARIO_PACKAGE_SCHEMA_ID = "aurelion_scenario_package";
constexpr const char *BROWSER_MANIFEST_CACHE_SCHEMA_ID = "aurelion_package_browser_manifest_cache_v1";
constexpr const char *BROWSER_MANIFEST_CACHE_DIR = "user://package_browser_manifest_cache_v1";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_config_normalization";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_exact_h3maped_state_chain_v1";
constexpr const char *HOMM3_RE_PROXY_CATALOG_PATH = "res://content/homm3_re_reward_object_proxy_catalog.json";
constexpr const char *HOMM3_RE_PROXY_CATALOG_SCHEMA = "homm3_re_reward_object_proxy_catalog_v1";
constexpr const char *RANDOM_MAP_OBJECT_ELIGIBILITY_PATH = "res://content/random_map_object_eligibility.json";
constexpr const char *RANDOM_MAP_OBJECT_ELIGIBILITY_SCHEMA = "aurelion_random_map_object_eligibility_v1";
constexpr const char *MAP_OBJECT_CATALOG_PATH = "res://content/map_objects.json";
constexpr const char *RESOURCE_SITE_CATALOG_PATH = "res://content/resource_sites.json";
constexpr const char *ARTIFACT_CATALOG_PATH = "res://content/artifacts.json";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;

using SteadyClock = std::chrono::steady_clock;

double elapsed_milliseconds(const SteadyClock::time_point &started_at) {
	return std::chrono::duration<double, std::milli>(SteadyClock::now() - started_at).count();
}

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_random_map_generation");
	result.append("native_random_map_package_session_adoption");
	result.append("native_rmg_homm3_generator_data_model_report");
	result.append("native_package_save_load");
	result.append("native_map_package_document_validation");
	result.append("legacy_scenario_record_conversion");
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
		case Variant::PACKED_INT32_ARRAY: {
			PackedInt32Array array = value;
			String result = "[";
			for (int64_t index = 0; index < array.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				result += "int:" + String::num_int64(array[index]);
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
	const uint32_t value = hash32_int(text);
	String result;
	for (int index = 7; index >= 0; --index) {
		const uint32_t nibble = (value >> (index * 4)) & 0xFU;
		result += String::chr(HEX_DIGITS[nibble]);
	}
	return result;
}

String hash32_hex_bytes(const std::vector<uint8_t> &bytes) {
	static constexpr const char *HEX_DIGITS = "0123456789abcdef";
	uint32_t value = 2166136261U;
	for (uint8_t byte : bytes) {
		value = (value ^ uint32_t(byte)) * 16777619U;
	}
	String result;
	for (int index = 7; index >= 0; --index) {
		result += String::chr(HEX_DIGITS[(value >> (index * 4)) & 0xFU]);
	}
	return result;
}

String normalized_text(const Dictionary &dictionary, const String &key, const String &fallback = "") {
	String value = String(dictionary.get(key, fallback)).strip_edges();
	return value.is_empty() ? fallback : value;
}

int32_t normalized_int(const Dictionary &dictionary, const String &key, int32_t fallback) {
	if (!dictionary.has(key)) {
		return fallback;
	}
	return int32_t(dictionary.get(key, fallback));
}

int32_t dimension_for_size_class(const String &size_class_id, int32_t fallback) {
	const String normalized = size_class_id.strip_edges().to_lower();
	if (normalized == "small" || normalized == "homm3_small" || normalized == "s") {
		return 36;
	}
	if (normalized == "medium" || normalized == "homm3_medium" || normalized == "m") {
		return 72;
	}
	if (normalized == "large" || normalized == "homm3_large" || normalized == "l") {
		return 108;
	}
	if (normalized == "extra_large" || normalized == "homm3_extra_large" || normalized == "xl") {
		return 144;
	}
	return fallback;
}

String normalized_size_class_id(const Dictionary &config, const Dictionary &size) {
	String value = normalized_text(size, "size_class_id", normalized_text(config, "size_class_id", ""));
	if (value.is_empty()) {
		value = normalized_text(size, "size", normalized_text(config, "size", ""));
	}
	value = value.strip_edges().to_lower();
	if (value == "s") {
		return "small";
	}
	if (value == "m") {
		return "medium";
	}
	if (value == "l") {
		return "large";
	}
	if (value == "xl") {
		return "extra_large";
	}
	if (value.begins_with("homm3_")) {
		return value.substr(6);
	}
	return value;
}

int32_t nested_size_int(const Dictionary &root, const Dictionary &size, const String &key, const String &alternate_key, int32_t fallback) {
	int32_t value = int32_t(size.get(key, 0));
	if (value <= 0) {
		value = int32_t(size.get(alternate_key, 0));
	}
	if (value <= 0) {
		value = int32_t(root.get(key, fallback));
	}
	return std::max<int32_t>(8, std::min<int32_t>(144, value));
}

Array normalized_string_array(Variant value, const Array &fallback) {
	Array result;
	if (value.get_type() == Variant::ARRAY) {
		Array source = value;
		for (int64_t index = 0; index < source.size(); ++index) {
			const String text = String(source[index]).strip_edges();
			if (!text.is_empty() && !result.has(text)) {
				result.append(text);
			}
		}
	}
	return result.is_empty() ? fallback.duplicate(true) : result;
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

Array ensure_repeated_to_count(const Array &source, const Array &fallback, int32_t count) {
	Array base = source.is_empty() ? fallback : source;
	Array result;
	if (base.is_empty()) {
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(base[index % base.size()]);
	}
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

Array town_ids_for_factions(Variant requested_value, const Array &faction_ids, int32_t count) {
	Array requested = normalized_string_array(requested_value, Array());
	Array result;
	if (!requested.is_empty()) {
		for (int32_t index = 0; index < count; ++index) {
			result.append(requested[index % requested.size()]);
		}
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(town_for_faction(String(faction_ids[index % faction_ids.size()])));
	}
	return result;
}

Dictionary normalized_player_constraints(const Dictionary &config) {
	Variant value = config.get("player_constraints", config.get("players", Variant()));
	Dictionary source = value.get_type() == Variant::DICTIONARY ? Dictionary(value) : Dictionary();
	int32_t human_count = std::max<int32_t>(1, std::min<int32_t>(8, int32_t(source.get("human_count", source.get("humans", 1)))));
	int32_t player_count = 2;
	int32_t computer_count = 1;
	if (source.has("player_count") || source.has("total_count") || source.has("total")) {
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, int32_t(source.get("player_count", source.get("total_count", source.get("total", 2))))));
		player_count = std::max(player_count, human_count);
		computer_count = std::max<int32_t>(0, player_count - human_count);
	} else {
		computer_count = std::max<int32_t>(0, std::min<int32_t>(7, int32_t(source.get("computer_count", source.get("computers", 1)))));
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, human_count + computer_count));
	}
	Dictionary result;
	result["human_count"] = human_count;
	result["computer_count"] = computer_count;
	result["player_count"] = player_count;
	result["team_mode"] = normalized_text(source, "team_mode", "free_for_all");
	const int32_t default_human_teams = human_count;
	const int32_t human_team_count = std::max<int32_t>(1, std::min<int32_t>(human_count,
			int32_t(source.get("human_team_count", source.get("human_teams", default_human_teams)))));
	const int32_t default_computer_teams = 0;
	const int32_t computer_team_count = computer_count == 0
			? 0
			: std::max<int32_t>(0, std::min<int32_t>(computer_count,
					int32_t(source.get("computer_team_count", source.get("computer_teams", default_computer_teams)))));
	result["human_team_count"] = human_team_count;
	result["computer_team_count"] = computer_team_count;
	return result;
}

String normalized_water_mode(const Dictionary &config, const Dictionary &size) {
	String water_mode = normalized_text(size, "water_mode", normalized_text(config, "water_mode", "land")).strip_edges().to_lower();
	if (water_mode == "none" || water_mode == "no_water" || water_mode == "land_only" || water_mode == "nowater") {
		return "land";
	}
	if (water_mode == "normalwater" || water_mode == "normal-water" || water_mode == "normal water" || water_mode == "mixed") {
		return "normal_water";
	}
	if (water_mode == "water") {
		return "islands";
	}
	if (water_mode != "islands" && water_mode != "normal_water") {
		return "land";
	}
	return water_mode;
}

bool known_h3maped_monster_strength(const String &strength) {
	return strength == "random"
			|| strength == "weak"
			|| strength == "normal"
			|| strength == "strong";
}

int32_t h3maped_monster_strength_raw_0x48(const String &strength) {
	if (strength == "normal") {
		return 0;
	}
	if (strength == "strong") {
		return 1;
	}
	return -1;
}

bool h3maped_core_supports_land_scope(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 0));
	const int32_t height = int32_t(normalized.get("height", 0));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const String water_mode = String(normalized.get("water_mode", "land"));
	const String size_class = String(normalized.get("size_class_id", ""));
	return aurelion::h3maped_rmg_core::supports_recovered_workflow_execution_scope(width, height, level_count, std::string(water_mode.utf8().get_data()), std::string(size_class.utf8().get_data()));
}

String h3maped_core_strict_scope_id(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 0));
	const int32_t height = int32_t(normalized.get("height", 0));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const String water_mode = String(normalized.get("water_mode", "land"));
	const String size_class = String(normalized.get("size_class_id", ""));
	return String(aurelion::h3maped_rmg_core::strict_scope_id(width, height, level_count, std::string(water_mode.utf8().get_data()), std::string(size_class.utf8().get_data())).c_str());
}

Dictionary extension_profile_stub(const Dictionary &normalized) {
	Dictionary result;
	result["schema_id"] = "aurelion_native_rmg_extension_profile_v1";
	result["schema_version"] = 1;
	result["measurement"] = "not_measured_generation_blocked_before_payload";
	result["phase_count"] = 1;
	Array phases;
	Dictionary phase;
	phase["phase_id"] = "normalize_config";
	phase["elapsed_usec"] = 0;
	phase["elapsed_msec"] = 0.0;
	phases.append(phase);
	result["phases"] = phases;
	result["width"] = normalized.get("width", 0);
	result["height"] = normalized.get("height", 0);
	result["level_count"] = normalized.get("level_count", 1);
	result["object_count"] = 0;
	result["road_segment_count"] = 0;
	result["town_count"] = 0;
	result["guard_count"] = 0;
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

Dictionary build_h3maped_small_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	(void)generated_map;
	(void)options;
	return native_conversion_fail(
			"h3maped_validator_gated_package_session_adoption_removed",
			"H3MapEd Small/Medium package/session adoption is disabled until the exact recovered H3MapEd private-state chain and executable phase order own the generated payload.");
}

const char *runtime_object_kind(int32_t type_id) {
	switch (type_id) {
		case 5: return "artifact";
		case 53: return "mine";
		case 54:
		case 71: case 72: case 73: case 74: case 75:
		case 162: case 163: case 164:
			return "guard";
		case 77: case 98: return "town";
		case 66: case 67: case 68: case 69: case 76: case 79:
		case 83: case 88: case 89: case 90: case 93: case 101:
			return "reward_reference";
		case 118: case 119: case 120: case 124: case 134: case 135:
		case 136: case 137: case 147: case 150: case 155: case 199:
		case 207: case 210:
			return "decorative_obstacle";
		default: return "h3m_object";
	}
}

Dictionary runtime_json_dictionary(const String &path) {
	if (!FileAccess::file_exists(path)) {
		return Dictionary();
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return Dictionary();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK) {
		return Dictionary();
	}
	Variant data = parser->get_data();
	return data.get_type() == Variant::DICTIONARY ? Dictionary(data) : Dictionary();
}

bool runtime_string_array_contains(const Variant &value, const String &needle) {
	if (value.get_type() != Variant::ARRAY) {
		return false;
	}
	Array values = value;
	for (int64_t index = 0; index < values.size(); ++index) {
		if (String(values[index]) == needle) {
			return true;
		}
	}
	return false;
}

Dictionary runtime_random_map_object_eligibility() {
	Dictionary registry = runtime_json_dictionary(RANDOM_MAP_OBJECT_ELIGIBILITY_PATH);
	if (String(registry.get("schema_id", "")) != RANDOM_MAP_OBJECT_ELIGIBILITY_SCHEMA
			|| String(registry.get("native_generation_boundary", ""))
					!= "classification_and_runtime_proxy_selection_only_no_phase_placement_topology_footprint_mask_rng_or_final_payload_changes") {
		return Dictionary();
	}
	return registry;
}

Dictionary runtime_authored_pool_definition(const Dictionary &registry, const String &pool_id) {
	Variant pools_value = registry.get("authored_pools", Variant());
	if (pools_value.get_type() != Variant::ARRAY) {
		return Dictionary();
	}
	Array pools = pools_value;
	for (int64_t index = 0; index < pools.size(); ++index) {
		if (pools[index].get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary pool = pools[index];
		if (String(pool.get("id", "")) == pool_id) {
			return pool;
		}
	}
	return Dictionary();
}

bool runtime_map_object_matches_pool(
		const Dictionary &item,
		const Dictionary &pool,
		const std::unordered_set<std::string> &resource_site_ids) {
	const String item_id = String(item.get("id", ""));
	const String primary_class = String(item.get("primary_class", ""));
	const bool explicit_match = runtime_string_array_contains(pool.get("explicit_object_ids", Variant()), item_id);
	Variant primary_classes = pool.get("primary_classes", Variant());
	if (primary_classes.get_type() == Variant::ARRAY
			&& !runtime_string_array_contains(primary_classes, primary_class)
			&& !explicit_match) {
		return false;
	}
	Variant families = pool.get("families", Variant());
	if (families.get_type() == Variant::ARRAY
			&& !runtime_string_array_contains(families, String(item.get("family", "")))) {
		return false;
	}
	Dictionary runtime_boundary = item.get("runtime_boundary", Dictionary());
	if (runtime_string_array_contains(
			pool.get("exclude_runtime_statuses", Variant()),
			String(runtime_boundary.get("status", "")))) {
		return false;
	}
	if (bool(pool.get("require_resource_site", false))) {
		const String site_id = String(item.get("resource_site_id", ""));
		if (site_id.is_empty() || resource_site_ids.count(std::string(site_id.utf8().get_data())) == 0) {
			return false;
		}
	}
	return !item_id.is_empty();
}

Dictionary runtime_authored_pool_candidates(const Dictionary &registry) {
	Dictionary result;
	Dictionary map_catalog = runtime_json_dictionary(MAP_OBJECT_CATALOG_PATH);
	Dictionary site_catalog = runtime_json_dictionary(RESOURCE_SITE_CATALOG_PATH);
	Dictionary artifact_catalog = runtime_json_dictionary(ARTIFACT_CATALOG_PATH);
	Array map_items = map_catalog.get("items", Array());
	Array site_items = site_catalog.get("items", Array());
	Array artifact_items = artifact_catalog.get("items", Array());
	std::unordered_set<std::string> resource_site_ids;
	for (int64_t index = 0; index < site_items.size(); ++index) {
		if (site_items[index].get_type() != Variant::DICTIONARY) {
			continue;
		}
		const String site_id = String(Dictionary(site_items[index]).get("id", ""));
		if (!site_id.is_empty()) {
			resource_site_ids.insert(std::string(site_id.utf8().get_data()));
		}
	}
	Array pools = registry.get("authored_pools", Array());
	for (int64_t pool_index = 0; pool_index < pools.size(); ++pool_index) {
		if (pools[pool_index].get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary pool = pools[pool_index];
		const String pool_id = String(pool.get("id", ""));
		const String domain = String(pool.get("content_domain", ""));
		Array candidates;
		if (domain == "map_object") {
			for (int64_t item_index = 0; item_index < map_items.size(); ++item_index) {
				if (map_items[item_index].get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary item = map_items[item_index];
				if (runtime_map_object_matches_pool(item, pool, resource_site_ids)) {
					candidates.append(item.duplicate(true));
				}
			}
		} else if (domain == "artifact") {
			for (int64_t item_index = 0; item_index < artifact_items.size(); ++item_index) {
				if (artifact_items[item_index].get_type() == Variant::DICTIONARY
						&& !String(Dictionary(artifact_items[item_index]).get("id", "")).is_empty()) {
					candidates.append(Dictionary(artifact_items[item_index]).duplicate(true));
				}
			}
		}
		for (int64_t item_index = 1; item_index < candidates.size(); ++item_index) {
			Variant current = candidates[item_index];
			const String current_id = String(Dictionary(current).get("id", ""));
			int64_t insert_index = item_index;
			while (insert_index > 0
					&& String(Dictionary(candidates[insert_index - 1]).get("id", "")) > current_id) {
				candidates[insert_index] = candidates[insert_index - 1];
				--insert_index;
			}
			candidates[insert_index] = current;
		}
		result[pool_id] = candidates;
	}
	return result;
}

Array runtime_live_proxy_catalog_entries() {
	if (!FileAccess::file_exists(HOMM3_RE_PROXY_CATALOG_PATH)) {
		return Array();
	}
	Ref<FileAccess> file = FileAccess::open(HOMM3_RE_PROXY_CATALOG_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return Array();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK) {
		return Array();
	}
	Variant data = parser->get_data();
	if (data.get_type() != Variant::DICTIONARY) {
		return Array();
	}
	Dictionary catalog = data;
	if (String(catalog.get("schema_id", "")) != HOMM3_RE_PROXY_CATALOG_SCHEMA
			|| String(catalog.get("asset_policy", "")) != "provenance_only_original_proxy_art") {
		return Array();
	}
	Variant entries_value = catalog.get("entries", Variant());
	if (entries_value.get_type() != Variant::ARRAY) {
		return Array();
	}
	Array entries = entries_value;
	Array detached;
	for (int64_t index = 0; index < entries.size(); ++index) {
		if (entries[index].get_type() != Variant::DICTIONARY) {
			return Array();
		}
		Dictionary entry = entries[index];
		const String generated_kind = String(entry.get("generated_kind", ""));
		const String proxy_object_id = String(entry.get("native_proxy_object_id", ""));
		if (String(entry.get("id", "")).is_empty()
				|| int32_t(entry.get("homm3_re_object_type_id", 0)) <= 0
				|| int32_t(entry.get("homm3_re_object_subtype", -1)) < 0
				|| generated_kind.is_empty()
				|| proxy_object_id.is_empty()) {
			return Array();
		}
		detached.append(entry.duplicate(true));
	}
	return detached;
}

bool runtime_proxy_entry_has_live_site_surface(const Dictionary &entry) {
	if (String(entry.get("runtime_projection_status", "live")) != "live") {
		return false;
	}
	const String kind = String(entry.get("generated_kind", ""));
	if (kind == "mine" || kind == "neutral_dwelling") {
		return !String(entry.get("native_proxy_object_id", "")).is_empty();
	}
	if (kind == "reward_reference" || kind == "resource_site") {
		return !String(entry.get("native_proxy_object_id", "")).is_empty()
				&& !String(entry.get("native_proxy_site_id", "")).is_empty();
	}
	return false;
}

bool runtime_proxy_entry_has_live_artifact_surface(const Dictionary &entry) {
	const String artifact_id = String(entry.get("native_artifact_id", ""));
	return String(entry.get("generated_kind", "")) == "reward_reference"
			&& String(entry.get("semantic_category", "")) == "artifact"
			&& !artifact_id.is_empty()
			&& String(entry.get("native_proxy_object_id", "")) == artifact_id
			&& String(entry.get("native_proxy_site_id", "")).is_empty();
}

Dictionary runtime_live_proxy_entry(
		const Array &entries,
		int32_t type_id,
		int32_t subtype,
		const String &base_kind) {
	Array exact_entries;
	Array kind_entries;
	for (int64_t index = 0; index < entries.size(); ++index) {
		Dictionary entry = entries[index];
		if (int32_t(entry.get("homm3_re_object_type_id", 0)) != type_id
				|| int32_t(entry.get("homm3_re_object_subtype", -1)) != subtype
				|| (!runtime_proxy_entry_has_live_site_surface(entry)
						&& !runtime_proxy_entry_has_live_artifact_surface(entry))) {
			continue;
		}
		exact_entries.append(entry);
		if (String(entry.get("generated_kind", "")) == base_kind) {
			kind_entries.append(entry);
		}
	}
	if (kind_entries.size() == 1) {
		return Dictionary(kind_entries[0]).duplicate(true);
	}
	if (kind_entries.is_empty() && exact_entries.size() == 1) {
		return Dictionary(exact_entries[0]).duplicate(true);
	}
	return Dictionary();
}

Dictionary runtime_authored_pool_proxy_entry(
		const Dictionary &registry,
		const Dictionary &candidates_by_pool,
		const Dictionary &catalog_entry,
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &source,
		const String &map_id) {
	Dictionary source_type_pools = registry.get("source_type_pools", Dictionary());
	const String source_type_key = String::num_int64(source.type_id);
	const String pool_id = String(source_type_pools.get(source_type_key, ""));
	if (pool_id.is_empty()) {
		return catalog_entry.duplicate(true);
	}
	Dictionary pool = runtime_authored_pool_definition(registry, pool_id);
	Variant candidates_value = candidates_by_pool.get(pool_id, Variant());
	if (pool.is_empty() || candidates_value.get_type() != Variant::ARRAY) {
		return Dictionary();
	}
	Array candidates = candidates_value;
	if (candidates.is_empty()) {
		return Dictionary();
	}
	if (!catalog_entry.is_empty()) {
		Dictionary entry = catalog_entry.duplicate(true);
		entry["native_authored_pool_id"] = pool_id;
		entry["native_authored_pool_candidate_count"] = candidates.size();
		entry["native_authored_pool_candidate_id"] = entry.get("native_proxy_object_id", "");
		entry["native_authored_pool_selection_token"] = String("exact_catalog:") + String(entry.get("id", ""));
		entry["native_authored_pool_selection_mode"] = "existing_exact_catalog_identity";
		entry["native_authored_pool_registry_path"] = RANDOM_MAP_OBJECT_ELIGIBILITY_PATH;
		entry["native_authored_pool_registry_schema"] = RANDOM_MAP_OBJECT_ELIGIBILITY_SCHEMA;
		entry["native_authored_pool_source_placement_unchanged"] = true;
		entry["native_authored_pool_final_payload_unchanged"] = true;
		return entry;
	}
	const String selection_token = hash32_hex(
			map_id + String(":") + String::num_int64(source.serialized_index)
			+ String(":") + source_type_key + String(":")
			+ String::num_int64(source.subtype) + String(":") + pool_id);
	const int64_t candidate_index = int64_t(hash32_int(selection_token)) % candidates.size();
	Dictionary candidate = candidates[candidate_index];
	Dictionary entry = catalog_entry.duplicate(true);
	const String domain = String(pool.get("content_domain", ""));
	const String candidate_id = String(candidate.get("id", ""));
	entry.erase("native_proxy_site_id");
	entry.erase("native_resource_id");
	entry.erase("native_artifact_id");
	entry["id"] = String("authored_pool_proxy_") + source_type_key + String("_")
			+ String::num_int64(source.subtype) + String("_") + pool_id;
	entry["generated_kind"] = pool.get("generated_kind", "");
	entry["source_kind"] = "homm3_re_final_payload_post_projection_original_content_pool";
	entry["semantic_category"] = pool.get("semantic_category", pool_id);
	entry["native_proxy_object_id"] = candidate_id;
	if (domain == "artifact") {
		entry["native_artifact_id"] = candidate_id;
		entry["native_proxy_family"] = candidate.get("family", "artifact");
		entry["native_proxy_category"] = candidate.get("artifact_class", "artifact");
	} else {
		const String site_id = String(candidate.get("resource_site_id", ""));
		if (!site_id.is_empty()) {
			entry["native_proxy_site_id"] = site_id;
		}
		entry["native_proxy_family"] = candidate.get("family", "");
		entry["native_proxy_category"] = candidate.get("primary_class", "");
	}
	entry["homm3_re_object_type_id"] = source.type_id;
	entry["homm3_re_object_type_name"] = String(source.def_name.c_str());
	entry["homm3_re_object_subtype"] = source.subtype;
	entry["homm3_re_object_def_ref"] = String(source.def_name.c_str());
	entry["native_authored_pool_id"] = pool_id;
	entry["native_authored_pool_candidate_count"] = candidates.size();
	entry["native_authored_pool_candidate_id"] = candidate_id;
	entry["native_authored_pool_selection_token"] = selection_token;
	entry["native_authored_pool_selection_mode"] = "stable_source_ordinal_pool_index";
	entry["native_authored_pool_registry_path"] = RANDOM_MAP_OBJECT_ELIGIBILITY_PATH;
	entry["native_authored_pool_registry_schema"] = RANDOM_MAP_OBJECT_ELIGIBILITY_SCHEMA;
	entry["native_authored_pool_source_placement_unchanged"] = true;
	entry["native_authored_pool_final_payload_unchanged"] = true;
	return entry;
}

void apply_runtime_live_proxy_entry(Dictionary &object, const Dictionary &entry) {
	if (entry.is_empty()) {
		return;
	}
	object["kind"] = entry.get("generated_kind", "");
	object["native_record_kind"] = entry.get("generated_kind", "");
	object["object_id"] = entry.get("native_proxy_object_id", "");
	object["native_proxy_object_id"] = entry.get("native_proxy_object_id", "");
	const String site_id = String(entry.get("native_proxy_site_id", ""));
	if (!site_id.is_empty()) {
		object["site_id"] = site_id;
	}
	const String resource_id = String(entry.get("native_resource_id", ""));
	if (!resource_id.is_empty()) {
		object["resource_id"] = resource_id;
	}
	const String artifact_id = String(entry.get("native_artifact_id", ""));
	if (!artifact_id.is_empty()) {
		object["artifact_id"] = artifact_id;
	}
	for (const char *field : {
				"native_proxy_family",
				"native_proxy_category",
				"semantic_category",
				"homm3_re_reward_table_bucket" }) {
		const String value = String(entry.get(field, ""));
		if (!value.is_empty()) {
			object[field] = value;
		}
	}
	object["homm3_re_reward_object_catalog_id"] = entry.get("id", "");
	if (!String(entry.get("native_authored_pool_id", "")).is_empty()) {
		object["native_authored_pool_resolution_status"] = "mapped";
		for (const char *field : {
					"native_authored_pool_id",
					"native_authored_pool_candidate_id",
					"native_authored_pool_selection_token",
					"native_authored_pool_selection_mode",
					"native_authored_pool_registry_path",
					"native_authored_pool_registry_schema" }) {
			object[field] = entry.get(field, "");
		}
		object["native_authored_pool_candidate_count"] = entry.get("native_authored_pool_candidate_count", 0);
		object["native_authored_pool_source_placement_unchanged"] = true;
		object["native_authored_pool_final_payload_unchanged"] = true;
		if (String(entry.get("native_authored_pool_selection_mode", "")) == "existing_exact_catalog_identity") {
			object["homm3_re_reward_object_catalog_path"] = HOMM3_RE_PROXY_CATALOG_PATH;
			object["homm3_re_reward_object_catalog_schema"] = HOMM3_RE_PROXY_CATALOG_SCHEMA;
		}
	} else {
		object["homm3_re_reward_object_catalog_path"] = HOMM3_RE_PROXY_CATALOG_PATH;
		object["homm3_re_reward_object_catalog_schema"] = HOMM3_RE_PROXY_CATALOG_SCHEMA;
	}
	object["homm3_re_reward_object_source_kind"] = entry.get("source_kind", "");
	object["homm3_re_object_type_id"] = entry.get("homm3_re_object_type_id", 0);
	object["homm3_re_object_type_name"] = entry.get("homm3_re_object_type_name", "");
	object["homm3_re_object_subtype"] = entry.get("homm3_re_object_subtype", 0);
	object["homm3_re_object_source_row"] = entry.get("homm3_re_object_source_row", 0);
	object["homm3_re_object_def_ref"] = entry.get("homm3_re_object_def_ref", "");
	object["homm3_re_art_asset_policy"] = "provenance_only_original_proxy_art";
}

String runtime_faction_id(const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "faction_embercourt";
	}
	return (slot->color % 2 == 0) ? "faction_sunvault" : "faction_mireclaw";
}

String runtime_town_id(const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "town_riverwatch";
	}
	return (slot->color % 2 == 0) ? "town_prismhearth" : "town_duskfen";
}

String configured_runtime_faction_id(
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot,
		const Dictionary &normalized_config) {
	if (slot != nullptr) {
		const Dictionary player_setup = normalized_config.get("player_setup", Dictionary());
		if (slot->human) {
			const String selected_faction_id = String(player_setup.get("faction_id", "")).strip_edges();
			if (!selected_faction_id.is_empty()) {
				return selected_faction_id;
			}
		}
		const Array faction_ids = normalized_config.get("faction_ids", Array());
		if (slot->color >= 0 && slot->color < faction_ids.size()) {
			const String faction_id = String(faction_ids[slot->color]).strip_edges();
			if (!faction_id.is_empty()) {
				return faction_id;
			}
		}
	}
	return runtime_faction_id(slot);
}

String configured_runtime_town_id(
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot,
		const Dictionary &normalized_config) {
	if (slot != nullptr) {
		const Dictionary player_setup = normalized_config.get("player_setup", Dictionary());
		if (slot->human) {
			const String selected_faction_id = String(player_setup.get("faction_id", "")).strip_edges();
			if (!selected_faction_id.is_empty()) {
				return town_for_faction(selected_faction_id);
			}
		}
		const Array town_ids = normalized_config.get("town_ids", Array());
		if (slot->color >= 0 && slot->color < town_ids.size()) {
			const String town_id = String(town_ids[slot->color]).strip_edges();
			if (!town_id.is_empty()) {
				return town_id;
			}
		}
	}
	return runtime_town_id(slot);
}

Dictionary runtime_tile_point(const aurelion::h3maped_rmg_core::RuntimeMapTilePoint &point) {
	Dictionary result;
	result["x"] = point.x;
	result["y"] = point.y;
	result["level"] = point.level;
	return result;
}

Array runtime_tile_points(const std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> &points) {
	Array result;
	for (const auto &point : points) {
		result.append(runtime_tile_point(point));
	}
	return result;
}

int64_t runtime_tile_flat(
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection,
		int32_t x,
		int32_t y,
		int32_t level) {
	if (x < 0 || y < 0 || level < 0
			|| x >= projection.width || y >= projection.height || level >= projection.level_count) {
		return -1;
	}
	return int64_t(level) * projection.width * projection.height
			+ int64_t(y) * projection.width + x;
}

Array runtime_guard_control_tiles(
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &source,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	Array result;
	std::unordered_set<int64_t> seen;
	std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> fallback_origins;
	const std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> *origins = &source.action_tiles;
	if (origins->empty()) {
		fallback_origins.push_back({
				std::clamp(source.x, 0, projection.width - 1),
				std::clamp(source.y, 0, projection.height - 1),
				std::clamp(source.level, 0, projection.level_count - 1),
		});
		origins = &fallback_origins;
	}
	for (const auto &origin : *origins) {
		for (int32_t dy = -1; dy <= 1; ++dy) {
			for (int32_t dx = -1; dx <= 1; ++dx) {
				const int32_t x = origin.x + dx;
				const int32_t y = origin.y + dy;
				const int32_t level = origin.level;
				const int64_t flat = runtime_tile_flat(projection, x, y, level);
				if (flat < 0 || !seen.insert(flat).second) {
					continue;
				}
				result.append(runtime_tile_point({x, y, level}));
			}
		}
	}
	return result;
}

Dictionary runtime_start_tile_for_slot(
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 &slot,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	std::unordered_set<int64_t> blocked_tiles;
	std::unordered_set<int64_t> interaction_tiles;
	std::unordered_set<int64_t> road_tiles;
	for (const auto &object : projection.objects) {
		for (const auto &point : object.body_tiles) {
			const int64_t flat = runtime_tile_flat(projection, point.x, point.y, point.level);
			if (flat >= 0) {
				blocked_tiles.insert(flat);
			}
		}
		for (const auto &point : object.action_tiles) {
			const int64_t flat = runtime_tile_flat(projection, point.x, point.y, point.level);
			if (flat >= 0) {
				interaction_tiles.insert(flat);
			}
		}
	}
	for (const auto &point : projection.road_tiles) {
		const int64_t flat = runtime_tile_flat(projection, point.x, point.y, point.level);
		if (flat >= 0) {
			road_tiles.insert(flat);
		}
	}

	auto terrain_passable = [&](int32_t x, int32_t y, int32_t level) {
		const int64_t flat = runtime_tile_flat(projection, x, y, level);
		if (flat < 0 || flat >= int64_t(projection.terrain_type_codes.size())) {
			return false;
		}
		const uint8_t terrain = projection.terrain_type_codes[size_t(flat)] & 0x3f;
		return terrain != 8 && terrain != 9;
	};
	auto has_unblocked_adjacent_road = [&](int32_t x, int32_t y, int32_t level) {
		for (int32_t dy = -1; dy <= 1; ++dy) {
			for (int32_t dx = -1; dx <= 1; ++dx) {
				if (dx == 0 && dy == 0) {
					continue;
				}
				const int64_t flat = runtime_tile_flat(projection, x + dx, y + dy, level);
				if (flat >= 0 && road_tiles.count(flat) > 0 && blocked_tiles.count(flat) == 0) {
					return true;
				}
			}
		}
		return false;
	};
	auto cuts_blocked_corner = [&](int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y, int32_t level) {
		const int32_t dx = to_x - from_x;
		const int32_t dy = to_y - from_y;
		if (std::abs(dx) != 1 || std::abs(dy) != 1) {
			return false;
		}
		const int64_t horizontal = runtime_tile_flat(projection, from_x + dx, from_y, level);
		const int64_t vertical = runtime_tile_flat(projection, from_x, from_y + dy, level);
		return blocked_tiles.count(horizontal) > 0 && blocked_tiles.count(vertical) > 0;
	};
	auto road_reachable_step_count = [&](int32_t start_x, int32_t start_y, int32_t level) {
		const int64_t start_flat = runtime_tile_flat(projection, start_x, start_y, level);
		if (start_flat < 0 || blocked_tiles.count(start_flat) > 0
				|| road_tiles.count(start_flat) > 0 || !terrain_passable(start_x, start_y, level)) {
			return -1;
		}
		std::vector<std::pair<int32_t, int32_t>> queue;
		std::vector<int32_t> distances;
		std::unordered_set<int64_t> visited;
		queue.emplace_back(start_x, start_y);
		distances.push_back(0);
		visited.insert(start_flat);
		for (size_t cursor = 0; cursor < queue.size(); ++cursor) {
			const auto current = queue[cursor];
			const int32_t current_distance = distances[cursor];
			for (int32_t dy = -1; dy <= 1; ++dy) {
				for (int32_t dx = -1; dx <= 1; ++dx) {
					if (dx == 0 && dy == 0) {
						continue;
					}
					const int32_t next_x = current.first + dx;
					const int32_t next_y = current.second + dy;
					if (!terrain_passable(next_x, next_y, level)
							|| cuts_blocked_corner(current.first, current.second, next_x, next_y, level)) {
						continue;
					}
					const int64_t next_flat = runtime_tile_flat(projection, next_x, next_y, level);
					if (visited.count(next_flat) > 0 || blocked_tiles.count(next_flat) > 0) {
						continue;
					}
					if (road_tiles.count(next_flat) > 0) {
						return current_distance + 1;
					}
					if (interaction_tiles.count(next_flat) > 0) {
						continue;
					}
					visited.insert(next_flat);
					queue.emplace_back(next_x, next_y);
					distances.push_back(current_distance + 1);
				}
			}
		}
		return -1;
	};
	auto selected_tile = [&](int32_t x, int32_t y, int32_t level, int32_t radius,
			int32_t road_steps, bool adjacent_road, const char *source) {
		Dictionary selected;
		selected["x"] = x;
		selected["y"] = y;
		selected["level"] = level;
		selected["selection_radius_from_town_coordinate"] = radius;
		selected["selection_package_road_reachable_steps"] = road_steps;
		selected["selection_adjacent_unblocked_package_road"] = adjacent_road;
		selected["selection_removed_removable_start_block_mask"] = false;
		selected["selection_source"] = source;
		return selected;
	};
	auto candidate_available = [&](int32_t x, int32_t y, int32_t level) {
		const int64_t flat = runtime_tile_flat(projection, x, y, level);
		return flat >= 0 && terrain_passable(x, y, level)
				&& blocked_tiles.count(flat) == 0
				&& road_tiles.count(flat) == 0
				&& interaction_tiles.count(flat) == 0;
	};

	const int32_t road_radius = std::min<int32_t>(std::max(projection.width, projection.height), 18);
	for (int32_t adjacent_pass = 0; adjacent_pass < 2; ++adjacent_pass) {
		const bool require_adjacent_road = adjacent_pass == 0;
		for (int32_t radius = 1; radius <= road_radius; ++radius) {
			for (int32_t dy = -radius; dy <= radius; ++dy) {
				for (int32_t dx = -radius; dx <= radius; ++dx) {
					if (std::abs(dx) + std::abs(dy) != radius) {
						continue;
					}
					const int32_t x = slot.town_x + dx;
					const int32_t y = slot.town_y + dy;
					if (!candidate_available(x, y, slot.town_level)) {
						continue;
					}
					const bool adjacent_road = has_unblocked_adjacent_road(x, y, slot.town_level);
					if (require_adjacent_road && !adjacent_road) {
						continue;
					}
					const int32_t road_steps = road_reachable_step_count(x, y, slot.town_level);
					if (road_steps <= 0) {
						continue;
					}
					return selected_tile(
							x, y, slot.town_level, radius, road_steps, adjacent_road,
							require_adjacent_road
									? "h3maped_town_coordinate_exact_package_mask_adjacent_road_runtime_start"
									: "h3maped_town_coordinate_exact_package_mask_reachable_road_runtime_start");
				}
			}
		}
	}

	const int32_t safe_radius = std::max(projection.width, projection.height);
	for (int32_t radius = 1; radius <= safe_radius; ++radius) {
		for (int32_t dy = -radius; dy <= radius; ++dy) {
			for (int32_t dx = -radius; dx <= radius; ++dx) {
				if (std::abs(dx) + std::abs(dy) != radius) {
					continue;
				}
				const int32_t x = slot.town_x + dx;
				const int32_t y = slot.town_y + dy;
				if (candidate_available(x, y, slot.town_level)) {
					return selected_tile(
							x, y, slot.town_level, radius, -1,
							has_unblocked_adjacent_road(x, y, slot.town_level),
							"h3maped_town_coordinate_exact_package_mask_nearest_unblocked_runtime_start");
				}
			}
		}
	}
	return Dictionary();
}

Dictionary runtime_layer(const std::vector<uint8_t> &codes, int32_t width, int32_t height, int32_t level_count) {
	Dictionary result;
	Array levels;
	const int32_t level_size = width * height;
	for (int32_t level = 0; level < level_count; ++level) {
		PackedInt32Array values;
		values.resize(level_size);
		for (int32_t index = 0; index < level_size; ++index) {
			values.set(index, int32_t(codes[size_t(level * level_size + index)]));
		}
		levels.append(values);
	}
	result["levels"] = levels;
	return result;
}

const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *runtime_slot_for_town(
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (slot.town_x == point.x && slot.town_y == point.y
					&& slot.town_level == point.level) {
				return &slot;
			}
		}
	}
	return nullptr;
}

String runtime_placement_id(const String &map_id, int32_t index) {
	return map_id + String("_object_") + String::num_int64(index).pad_zeros(4);
}

String runtime_town_placement_id(
		const String &map_id,
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 &slot,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &object : projection.objects) {
		if (object.type_id != 98) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (point.x == slot.town_x && point.y == slot.town_y
					&& point.level == slot.town_level) {
				return runtime_placement_id(map_id, object.serialized_index);
			}
		}
	}
	return "";
}

Dictionary runtime_terrain_layers(const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	Dictionary layers;
	layers["schema_id"] = "aurelion_terrain_layers";
	layers["schema_version"] = 1;
	Array terrain_ids;
	for (const char *id : { "dirt", "sand", "grass", "snow", "swamp", "rough", "underground", "lava", "water", "rock" }) {
		terrain_ids.append(id);
	}
	layers["terrain_id_by_code"] = terrain_ids;
	layers["terrain"] = runtime_layer(projection.terrain_type_codes, projection.width, projection.height, projection.level_count);
	layers["terrain_art"] = runtime_layer(projection.terrain_art_codes, projection.width, projection.height, projection.level_count);
	layers["river_type"] = runtime_layer(projection.river_type_codes, projection.width, projection.height, projection.level_count);
	layers["river_art"] = runtime_layer(projection.river_art_codes, projection.width, projection.height, projection.level_count);
	layers["road_type"] = runtime_layer(projection.road_type_codes, projection.width, projection.height, projection.level_count);
	layers["road_art"] = runtime_layer(projection.road_art_codes, projection.width, projection.height, projection.level_count);
	layers["flags"] = runtime_layer(projection.tile_flags, projection.width, projection.height, projection.level_count);
	layers["road_unique_tile_count"] = int32_t(projection.road_tiles.size());
	Array roads;
	if (!projection.road_tiles.empty()) {
		Dictionary road;
		road["id"] = "h3maped_native_roads";
		road["tiles"] = runtime_tile_points(projection.road_tiles);
		roads.append(road);
	}
	layers["roads"] = roads;
	return layers;
}

Dictionary runtime_objects(
		const String &map_id,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection,
		const Dictionary &normalized_config) {
	Array result;
	Array failures;
	const Array live_proxy_catalog = runtime_live_proxy_catalog_entries();
	const Dictionary eligibility = runtime_random_map_object_eligibility();
	const Dictionary candidates_by_pool = runtime_authored_pool_candidates(eligibility);
	const Dictionary source_type_pools = eligibility.get("source_type_pools", Dictionary());
	const Dictionary source_kind_passthrough = eligibility.get("source_kind_passthrough", Dictionary());
	const Dictionary source_type_exclusions = eligibility.get("source_type_exclusions", Dictionary());
	Dictionary resolution_counts;
	for (const auto &source : projection.objects) {
		Dictionary object;
		const String base_kind = runtime_object_kind(source.type_id);
		const Dictionary catalog_proxy = runtime_live_proxy_entry(
				live_proxy_catalog,
				source.type_id,
				source.subtype,
				base_kind);
		const Dictionary live_proxy = runtime_authored_pool_proxy_entry(
				eligibility,
				candidates_by_pool,
				catalog_proxy,
				source,
				map_id);
		const String kind = live_proxy.is_empty()
				? base_kind
				: String(live_proxy.get("generated_kind", base_kind));
		const int32_t x = std::clamp(source.x, 0, projection.width - 1);
		const int32_t y = std::clamp(source.y, 0, projection.height - 1);
		const int32_t level = std::clamp(source.level, 0, projection.level_count - 1);
		object["placement_id"] = runtime_placement_id(map_id, source.serialized_index);
		object["kind"] = kind;
		object["native_record_kind"] = kind;
		object["source_kind"] = "h3maped_final_payload";
		object["h3m_type_id"] = source.type_id;
		object["h3m_subtype"] = source.subtype;
		object["h3m_group"] = source.group;
		object["h3m_definition_index"] = source.definition_index;
		object["h3m_def_name"] = String(source.def_name.c_str());
		object["h3m_serialization_pass"] = source.serialization_pass;
		object["h3m_payload_offset"] = source.payload_offset;
		object["h3m_payload_byte_count"] = source.payload_byte_count;
		object["h3m_anchor_x"] = source.x;
		object["h3m_anchor_y"] = source.y;
		object["h3m_anchor_level"] = source.level;
		object["x"] = x;
		object["y"] = y;
		object["level"] = level;
		Dictionary primary;
		primary["x"] = x; primary["y"] = y; primary["level"] = level;
		object["primary_tile"] = primary;
		Array body_tiles = runtime_tile_points(source.body_tiles);
		if (body_tiles.is_empty()) {
			body_tiles.append(primary.duplicate(true));
		}
		Array visit_tiles = runtime_tile_points(source.action_tiles);
		if (visit_tiles.is_empty()
				&& (kind == "town" || kind == "mine" || kind == "artifact"
						|| kind == "reward_reference")) {
			visit_tiles.append(primary.duplicate(true));
		}
		object["body_tiles"] = body_tiles;
		object["package_body_tiles"] = body_tiles;
		object["package_block_tiles"] = runtime_tile_points(source.body_tiles);
		object["package_visit_tiles"] = visit_tiles;
		if (!visit_tiles.is_empty()) {
			object["visit_tile"] = visit_tiles[0];
		}
		object["blocking_body"] = !source.body_tiles.empty();
		apply_runtime_live_proxy_entry(object, live_proxy);
		const String source_type_key = String::num_int64(source.type_id);
		String resolution_status = String(object.get("native_authored_pool_resolution_status", ""));
		if (resolution_status.is_empty()) {
			if (source_kind_passthrough.has(source_type_key)) {
				resolution_status = "native_runtime_passthrough";
			} else if (source_type_exclusions.has(source_type_key)) {
				resolution_status = "unsupported_source_type";
				object["native_authored_pool_exclusion_reason"] = source_type_exclusions.get(source_type_key, "");
			} else if (kind == "decorative_obstacle" || visit_tiles.is_empty()) {
				resolution_status = "renderer_managed_nonvisitable_body";
			} else if (source_type_pools.has(source_type_key)) {
				resolution_status = "mapped_pool_resolution_failed";
			} else {
				resolution_status = "unclassified_visitable_source_type";
			}
			object["native_authored_pool_resolution_status"] = resolution_status;
		}
		resolution_counts[resolution_status] = int64_t(resolution_counts.get(resolution_status, 0)) + 1;
		if (!visit_tiles.is_empty()
				&& (resolution_status == "unsupported_source_type"
						|| resolution_status == "mapped_pool_resolution_failed"
						|| resolution_status == "unclassified_visitable_source_type")) {
			Dictionary failure;
			failure["code"] = resolution_status;
			failure["type_id"] = source.type_id;
			failure["subtype"] = source.subtype;
			failure["definition_name"] = String(source.def_name.c_str());
			failure["serialized_index"] = source.serialized_index;
			failure["visit_tile_count"] = visit_tiles.size();
			failure["reason"] = object.get("native_authored_pool_exclusion_reason", "");
			failures.append(failure);
		}
		if (kind == "town") {
			const auto *slot = runtime_slot_for_town(source, projection);
			object["owner"] = slot == nullptr ? "neutral" : (slot->human ? "player" : "enemy");
			object["owner_slot"] = slot == nullptr ? 0 : slot->color + 1;
			object["player_slot"] = slot == nullptr ? 0 : slot->color + 1;
			object["player_type"] = slot == nullptr ? "neutral" : (slot->human ? "human" : "computer");
			object["is_start_town"] = slot != nullptr;
			object["start_anchor"] = slot != nullptr;
			object["town_id"] = configured_runtime_town_id(slot, normalized_config);
			object["faction_id"] = configured_runtime_faction_id(slot, normalized_config);
		} else if (kind == "guard") {
			object["encounter_id"] = "encounter_mire_raid";
			object["object_id"] = "encounter_mire_raid";
			Array control_tiles = runtime_guard_control_tiles(source, projection);
			object["package_guard_control_zone_tiles"] = control_tiles;
			object["package_guard_control_zone_tile_count"] = control_tiles.size();
			object["package_guard_engagement_tiles"] = control_tiles;
			object["package_guard_engagement_tile_count"] = control_tiles.size();
			object["package_guard_control_zone_pathing_policy"] = "h3m_guard_control_forces_engagement_guard_body_remains_blocking_surface";
			object["package_guard_engagement_policy"] = "h3m_guard_control_forces_engagement";
		} else if (kind == "mine") {
			if (live_proxy.is_empty()) {
				object["site_id"] = source.subtype == 2 ? "site_ridge_quarry" : "site_brightwood_sawmill";
			}
			object["owner"] = "neutral";
		} else if (kind == "reward_reference") {
			if (live_proxy.is_empty()) {
				object["site_id"] = "site_generated_town_required_source_cache";
			}
		}
		result.append(object);
	}
	Dictionary report;
	report["ok"] = failures.is_empty() && !eligibility.is_empty();
	report["objects"] = result;
	report["failures"] = failures;
	report["failure_count"] = failures.size();
	report["resolution_counts"] = resolution_counts;
	report["registry_path"] = RANDOM_MAP_OBJECT_ELIGIBILITY_PATH;
	report["registry_schema"] = RANDOM_MAP_OBJECT_ELIGIBILITY_SCHEMA;
	report["registry_loaded"] = !eligibility.is_empty();
	return report;
}

Dictionary build_native_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	if (!bool(generated_map.get("ok", false))
			|| !bool(generated_map.get("native_runtime_authoritative", false))
			|| !bool(generated_map.get("runtime_payload_projection_complete", false))) {
		return native_conversion_fail(
				"native_rmg_generated_payload_not_authoritative",
				"Package/session adoption requires a structurally validated native-owned final payload.");
	}
	Variant map_value = generated_map.get("map_document", Variant());
	Variant scenario_value = generated_map.get("scenario_document", Variant());
	if (map_value.get_type() != Variant::OBJECT || scenario_value.get_type() != Variant::OBJECT) {
		return native_conversion_fail(
				"native_rmg_generated_documents_missing",
				"Package/session adoption requires generated MapDocument and ScenarioDocument objects.");
	}
	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	report["schema_version"] = 1;
	report["status"] = "pass";
	report["failure_count"] = 0;
	report["warning_count"] = 0;
	report["failures"] = Array();
	report["warnings"] = Array();
	report["package_session_adoption_ready"] = true;
	report["native_runtime_authoritative"] = true;
	report["runtime_call_site_adoption"] = true;
	report["full_parity_claim"] = bool(generated_map.get("full_parity_claim", false));
	report["adoption_status"] = "runtime_authoritative_source_parity_complete";

	const String map_id = generated_map.get("map_id", "");
	const String map_hash = generated_map.get("map_hash", "");
	const String scenario_id = generated_map.get("scenario_id", "");
	const String scenario_hash = generated_map.get("scenario_hash", "");
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = MapDocument::SCHEMA_VERSION;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["source_kind"] = "generated_h3maped_native_parity";
	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = ScenarioDocument::SCHEMA_VERSION;
	scenario_ref["scenario_id"] = scenario_id;
	scenario_ref["scenario_hash"] = scenario_hash;
	scenario_ref["map_ref"] = map_ref;

	const String feature_gate = options.get("feature_gate", "native_rmg_runtime");
	const int32_t save_version = int32_t(options.get("session_save_version", 0));
	const Dictionary normalized_config = generated_map.get("normalized_config", Dictionary());
	const Dictionary player_setup = normalized_config.get("player_setup", Dictionary());
	const String player_hero_id = String(player_setup.get("hero_id", "hero_lyra")).strip_edges();
	Dictionary boundary;
	boundary["schema_id"] = "aurelion_native_rmg_package_session_boundary_v1";
	boundary["session_id"] = "native_rmg_session_" + map_id;
	boundary["scenario_id"] = scenario_id;
	boundary["map_id"] = map_id;
	boundary["hero_id"] = player_hero_id.is_empty() ? String("hero_lyra") : player_hero_id;
	boundary["player_faction_id"] = String(player_setup.get("faction_id", ""));
	boundary["player_setup"] = player_setup.duplicate(true);
	boundary["feature_gate"] = feature_gate;
	boundary["save_version"] = save_version;
	boundary["save_version_bump"] = false;
	boundary["authored_content_writeback"] = false;
	boundary["campaign_adoption"] = false;
	boundary["runtime_call_site_adoption"] = true;
	boundary["native_runtime_authoritative"] = true;
	boundary["full_parity_claim"] = bool(generated_map.get("full_parity_claim", false));
	boundary["map_package_ref"] = map_ref;
	boundary["scenario_package_ref"] = scenario_ref;

	Dictionary generated_identity;
	generated_identity["map_id"] = map_id;
	generated_identity["map_hash"] = map_hash;
	generated_identity["scenario_id"] = scenario_id;
	generated_identity["scenario_hash"] = scenario_hash;
	generated_identity["normalized_config"] = generated_map.get("normalized_config", Dictionary());
	Dictionary result;
	result["ok"] = true;
	result["status"] = "complete";
	result["adoption_status"] = "ready";
	result["package_session_adoption_ready"] = true;
	result["native_runtime_authoritative"] = true;
	result["map_document"] = map_value;
	result["scenario_document"] = scenario_value;
	result["map_ref"] = map_ref;
	result["scenario_ref"] = scenario_ref;
	result["session_boundary_record"] = boundary;
	result["generated_identity"] = generated_identity;
	result["validation_report"] = report;
	result["report"] = report;
	return result;
}

Dictionary h3maped_exact_state_chain_runtime_blocked_result(const Dictionary &normalized, const Dictionary &extension_profile, bool include_legacy_request_flag) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["generation_status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["error_code"] = "native_rmg_exact_state_chain_not_ported";
	result["message"] = "Runtime RMG is blocked until the exact recovered H3MapEd private-state chain and executable order own the generated payload.";
	result["normalized_config"] = normalized.duplicate(true);
	result["extension_profile"] = extension_profile.duplicate(true);
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(normalized);
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["public_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["live_generation_surface_present"] = false;
	result["native_rmg_generation_authority"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_runtime_generation_policy"] = "small_36x36_land_and_medium_72x72_land_blocked_until_exact_recovered_h3maped_executable_order_owns_runtime_payload";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	result["include_h3maped_small_port_requested"] = include_legacy_request_flag;
	return result;
}

Dictionary native_rmg_exact_chain_unimplemented_blocked_result(const Dictionary &normalized, const Dictionary &extension_profile, const Dictionary &classification) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["generation_status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["error_code"] = "native_rmg_exact_state_chain_not_ported";
	result["message"] = "Runtime RMG is blocked for this scope. Add source-backed H3MapEd private-state support before enabling map output.";
	result["normalized_config"] = normalized.duplicate(true);
	result["extension_profile"] = extension_profile.duplicate(true);
	result["runtime_policy_classification"] = classification.duplicate(true);
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["public_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["live_generation_surface_present"] = false;
	result["native_rmg_generation_authority"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	return result;
}

Dictionary native_rmg_runtime_policy_classification(const Dictionary &normalized) {
	Dictionary result;
	const String monster_strength = normalized.get("monster_strength", "random");
	const bool supported_scope = h3maped_core_supports_land_scope(normalized);
	const bool supported_strength = known_h3maped_monster_strength(monster_strength);
	const bool supported = supported_scope && supported_strength;
	result["schema_id"] = "aurelion_native_rmg_runtime_policy_classification_v1";
	result["schema_version"] = 1;
	result["supported_h3maped_scope"] = supported;
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(normalized);
	result["runtime_generation_allowed"] = supported;
	result["native_runtime_authoritative"] = supported;
	result["full_parity_claim"] = supported;
	result["blocked_reason"] = supported
			? ""
			: (supported_scope
					? "unsupported_h3maped_monster_strength"
					: "outside_supported_h3maped_parity_matrix");
	return result;
}

Dictionary not_implemented(const String &operation, const String &path, const Dictionary &options) {
	(void)options;
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = operation + String(" is not implemented in the native package API skeleton.");
	failure["context"] = Dictionary();

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
	result["message"] = operation + String(" is not implemented in the native package API skeleton.");
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

Dictionary browser_manifest_from_package(const Dictionary &package) {
	Variant document_value = package.get("document", Variant());
	if (document_value.get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary document = document_value;
	Dictionary browser_manifest;
	const String package_schema = package.get("schema_id", "");
	const String document_schema = document.get("schema_id", "");
	if (package_schema == MAP_PACKAGE_SCHEMA_ID && document_schema == MAP_SCHEMA_ID) {
		Variant metadata_value = document.get("metadata", Variant());
		Dictionary metadata = metadata_value.get_type() == Variant::DICTIONARY ? Dictionary(metadata_value) : Dictionary();
		metadata = metadata.duplicate(true);
		metadata["schema_id"] = MAP_SCHEMA_ID;
		metadata["schema_version"] = 1;
		Variant map_ref_value = package.get("map_ref", Variant());
		Dictionary map_ref = map_ref_value.get_type() == Variant::DICTIONARY ? Dictionary(map_ref_value) : Dictionary();
		browser_manifest["document_kind"] = "map";
		browser_manifest["width"] = document.get("width", 0);
		browser_manifest["height"] = document.get("height", 0);
		browser_manifest["level_count"] = document.get("level_count", 1);
		browser_manifest["metadata"] = metadata;
		browser_manifest["map_ref"] = map_ref.duplicate(true);
	} else if (package_schema == SCENARIO_PACKAGE_SCHEMA_ID && document_schema == SCENARIO_SCHEMA_ID) {
		Variant selection_value = document.get("selection", Variant());
		Dictionary selection = selection_value.get_type() == Variant::DICTIONARY ? Dictionary(selection_value) : Dictionary();
		Variant slots_value = document.get("player_slots", Variant());
		Array player_slots = slots_value.get_type() == Variant::ARRAY ? Array(slots_value) : Array();
		Variant scenario_ref_value = package.get("scenario_ref", Variant());
		Dictionary scenario_ref = scenario_ref_value.get_type() == Variant::DICTIONARY ? Dictionary(scenario_ref_value) : Dictionary();
		browser_manifest["document_kind"] = "scenario";
		browser_manifest["selection"] = selection.duplicate(true);
		browser_manifest["player_count"] = player_slots.size();
		browser_manifest["scenario_ref"] = scenario_ref.duplicate(true);
	}
	return browser_manifest;
}

Dictionary package_inspection_payload(const Dictionary &package) {
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
	Dictionary browser_manifest = browser_manifest_from_package(package);
	if (!browser_manifest.is_empty()) {
		payload["browser_manifest"] = browser_manifest;
	}
	return payload;
}

String browser_manifest_cache_path(const String &source_path) {
	return String(BROWSER_MANIFEST_CACHE_DIR) + "/" + hash32_hex(source_path) + ".json";
}

bool browser_manifest_cache_payload_is_valid(const Dictionary &payload) {
	Variant manifest_value = payload.get("browser_manifest", Variant());
	if (manifest_value.get_type() != Variant::DICTIONARY) {
		return false;
	}
	Dictionary manifest = manifest_value;
	const String package_schema = payload.get("schema_id", "");
	const String document_kind = manifest.get("document_kind", "");
	return (package_schema == MAP_PACKAGE_SCHEMA_ID && document_kind == "map") ||
			(package_schema == SCENARIO_PACKAGE_SCHEMA_ID && document_kind == "scenario");
}

Dictionary read_browser_manifest_cache(const String &source_path, const String &source_sha256) {
	if (source_sha256.is_empty()) {
		return Dictionary();
	}
	const String cache_path = browser_manifest_cache_path(source_path);
	if (!FileAccess::file_exists(cache_path)) {
		return Dictionary();
	}
	Dictionary read_result = read_package_dictionary("read_browser_manifest_cache", cache_path);
	if (!bool(read_result.get("ok", false))) {
		return Dictionary();
	}
	Dictionary cache = read_result.get("package", Dictionary());
	if (String(cache.get("schema_id", "")) != BROWSER_MANIFEST_CACHE_SCHEMA_ID ||
			int32_t(cache.get("schema_version", 0)) != 1 ||
			String(cache.get("source_path", "")) != source_path ||
			String(cache.get("source_sha256", "")) != source_sha256) {
		return Dictionary();
	}
	Variant payload_value = cache.get("inspection_payload", Variant());
	if (payload_value.get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary payload = Dictionary(payload_value).duplicate(true);
	if (!browser_manifest_cache_payload_is_valid(payload)) {
		return Dictionary();
	}
	const String expected_hash = "fnv1a32:" + hash32_hex(canonical_variant(payload));
	if (String(cache.get("inspection_payload_hash", "")) != expected_hash) {
		return Dictionary();
	}
	Dictionary cached_manifest = payload.get("browser_manifest", Dictionary());
	if (String(cached_manifest.get("document_kind", "")) == "map") {
		Dictionary cached_metadata = cached_manifest.get("metadata", Dictionary());
		cached_metadata.erase("schema_version");
		cached_metadata["schema_version"] = int64_t(1);
		cached_manifest["metadata"] = cached_metadata;
		payload["browser_manifest"] = cached_manifest;
	} else if (String(cached_manifest.get("document_kind", "")) == "scenario") {
		const int64_t cached_player_count = int64_t(cached_manifest.get("player_count", 0));
		cached_manifest.erase("player_count");
		cached_manifest["player_count"] = cached_player_count;
		payload["browser_manifest"] = cached_manifest;
	}
	return payload;
}

bool write_browser_manifest_cache(const String &source_path, const String &source_sha256, const Dictionary &payload) {
	if (source_sha256.is_empty() || !browser_manifest_cache_payload_is_valid(payload)) {
		return false;
	}
	Ref<JSON> payload_parser;
	payload_parser.instantiate();
	if (payload_parser->parse(JSON::stringify(payload, "", true, false)) != OK || payload_parser->get_data().get_type() != Variant::DICTIONARY) {
		return false;
	}
	Dictionary normalized_payload = Dictionary(payload_parser->get_data());
	if (!browser_manifest_cache_payload_is_valid(normalized_payload)) {
		return false;
	}
	Dictionary normalized_manifest = normalized_payload.get("browser_manifest", Dictionary());
	if (String(normalized_manifest.get("document_kind", "")) == "map") {
		Dictionary normalized_metadata = normalized_manifest.get("metadata", Dictionary());
		normalized_metadata["schema_id"] = MAP_SCHEMA_ID;
		normalized_metadata.erase("schema_version");
		normalized_metadata["schema_version"] = int64_t(1);
		normalized_manifest["metadata"] = normalized_metadata;
		normalized_payload["browser_manifest"] = normalized_manifest;
	}
	Ref<JSON> stable_payload_parser;
	stable_payload_parser.instantiate();
	if (stable_payload_parser->parse(JSON::stringify(normalized_payload, "", true, false)) != OK || stable_payload_parser->get_data().get_type() != Variant::DICTIONARY) {
		return false;
	}
	Dictionary stable_payload = Dictionary(stable_payload_parser->get_data());
	if (!browser_manifest_cache_payload_is_valid(stable_payload)) {
		return false;
	}
	const String cache_path = browser_manifest_cache_path(source_path);
	if (!ensure_parent_dir(cache_path)) {
		return false;
	}
	Dictionary cache;
	cache["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
	cache["schema_version"] = 1;
	cache["source_path"] = source_path;
	cache["source_sha256"] = source_sha256;
	cache["inspection_payload"] = stable_payload.duplicate(true);
	cache["inspection_payload_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(stable_payload));
	Ref<FileAccess> file = FileAccess::open(cache_path, FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return false;
	}
	file->store_string(JSON::stringify(cache, "\t", true, false));
	file->flush();
	file->close();
	return true;
}

Dictionary write_package_dictionary(const String &operation, const String &path, const Dictionary &package, bool return_package = true, bool include_cache_profile = false) {
	if (!ensure_parent_dir(path)) {
		return package_failure(operation, path, "create_directory_failed", "Package parent directory could not be created.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for writing.");
	}
	file->store_string(JSON::stringify(package, "\t", true, false));
	file->flush();
	file->close();
	const String source_sha256 = FileAccess::get_sha256(path);
	const bool cache_written = write_browser_manifest_cache(path, source_sha256, package_inspection_payload(package));
	Dictionary payload;
	if (return_package) {
		payload["package"] = package.duplicate(true);
	}
	payload["package_hash"] = package.get("package_hash", "");
	if (include_cache_profile) {
		Dictionary profile;
		profile["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
		profile["status"] = cache_written ? "prepopulated" : "not_cacheable";
		profile["source_sha256"] = source_sha256;
		profile["cache_path"] = browser_manifest_cache_path(path);
		payload["browser_manifest_cache_profile"] = profile;
	}
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
	const int32_t expected_level_tile_count = width * height;
	const String map_id = map_document->get_map_id();
	const String map_hash = map_document->get_map_hash();

	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = tile_count;
	metrics["object_count"] = map_document->get_object_count();
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
	if (roads_value.get_type() == Variant::ARRAY) {
		Array roads = roads_value;
		for (int64_t road_index = 0; road_index < roads.size(); ++road_index) {
			if (roads[road_index].get_type() != Variant::DICTIONARY) {
				Dictionary context;
				context["index"] = road_index;
				append_document_validation_issue(failures, "invalid_road_record", "fail", "terrain_layers.roads", "Road overlay records must be dictionaries.", context);
				continue;
			}
			Dictionary road = roads[road_index];
			Variant tiles_value = road.get("tiles", Variant());
			const int32_t tile_count = tiles_value.get_type() == Variant::ARRAY
					? int32_t(Array(tiles_value).size())
					: int32_t(road.get("tile_count", 0));
			if (tile_count <= 0) {
				Dictionary context;
				context["index"] = road_index;
				context["tile_count"] = tile_count;
				append_document_validation_issue(failures, "invalid_road_tile_count", "fail", "terrain_layers.roads", "Road overlays must contain at least one tile.", context);
			}
			if (tiles_value.get_type() != Variant::ARRAY) {
				continue;
			}
			Array tiles = tiles_value;
			for (int64_t tile_index = 0; tile_index < tiles.size(); ++tile_index) {
				if (tiles[tile_index].get_type() != Variant::DICTIONARY) {
					Dictionary context;
					context["road_index"] = road_index;
					context["tile_index"] = tile_index;
					append_document_validation_issue(failures, "invalid_road_tile", "fail", "terrain_layers.roads", "Road overlay tiles must be dictionaries.", context);
					continue;
				}
				Dictionary tile = tiles[tile_index];
				const int32_t x = int32_t(tile.get("x", -1));
				const int32_t y = int32_t(tile.get("y", -1));
				const int32_t level = int32_t(tile.get("level", 0));
				if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
					Dictionary context;
					context["road_index"] = road_index;
					context["tile_index"] = tile_index;
					context["x"] = x;
					context["y"] = y;
					context["level"] = level;
					append_document_validation_issue(failures, "road_tile_out_of_bounds", "fail", "terrain_layers.roads", "Road overlay tiles must be inside map bounds and level range.", context);
				}
			}
		}
	}

	Dictionary placement_ids;
	for (int32_t index = 0; index < map_document->get_object_count(); ++index) {
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
		const String placement_id = String(object.get("placement_id", "")).strip_edges();
		if (placement_id.is_empty()) {
			Dictionary context;
			context["index"] = index;
			append_document_validation_issue(failures, "missing_object_placement_id", "fail", "objects", "Map object placement ids are required.", context);
		} else if (placement_ids.has(placement_id)) {
			Dictionary context;
			context["index"] = index;
			context["placement_id"] = placement_id;
			append_document_validation_issue(failures, "duplicate_object_placement_id", "fail", "objects", "Map object placement ids must be unique.", context);
		} else {
			placement_ids[placement_id] = true;
		}
		if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
			Dictionary context;
			context["index"] = index;
			context["x"] = x;
			context["y"] = y;
			context["level"] = level;
			append_document_validation_issue(failures, "object_out_of_bounds", "fail", "objects", "Map object placement must be inside map bounds and level range.", context);
		}
	}
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
	if (map_document.is_null()) {
		append_document_validation_issue(failures, "missing_map_document", "fail", "map_document", "Scenario validation requires the referenced MapDocument.");
	} else {
		Dictionary map_validation = validate_map_document_structural_report(map_document);
		Dictionary map_report = map_validation.get("report", Dictionary());
		if (String(map_report.get("status", "")) != "pass") {
			append_document_validation_issue(failures, "referenced_map_invalid", "fail", "map_document", "Referenced map document did not pass structural validation.", map_report);
		}
		if (String(map_ref.get("map_id", "")) != map_document->get_map_id()) {
			append_document_validation_issue(failures, "map_ref_id_mismatch", "fail", "map_ref.map_id", "Scenario map reference id must match the referenced MapDocument.");
		}
		if (String(map_ref.get("map_hash", "")) != map_document->get_map_hash()) {
			append_document_validation_issue(failures, "map_ref_hash_mismatch", "fail", "map_ref.map_hash", "Scenario map reference hash must match the referenced MapDocument.");
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
	result["native_rmg_generation_authority"] = "recovered_h3maped_exe_source_order_native_owned_final_payload";
	result["native_rmg_runtime_generation_allowed"] = true;
	result["native_rmg_runtime_generation_policy"] = "all_sizes_one_level_and_two_level_land_normal_water_islands; random_weak_normal_strong_monster_strength";
	result["native_rmg_production_ready"] = true;
	result["native_rmg_production_ready_scope"] = "strict_supported_h3maped_parity_matrix";
	result["native_rmg_end_to_end_parity_complete"] = true;
	result["native_rmg_end_to_end_parity_status"] = "complete_for_supported_h3maped_parity_matrix";
	result["native_rmg_runtime_generation_unblock_scope"] = "small_medium_large_xlarge_one_level_and_two_level_land_normal_water_islands";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	result["native_rmg_active_reset_slice_id"] = "native-rmg-exact-h3maped-state-chain-10184";
	result["native_rmg_active_port_capability"] = "native_rmg_final_payload_runtime_projection_and_package_session_adoption";
	result["live_generation_surface_present"] = true;
	result["status"] = "ready";
	return result;
}

PackedStringArray MapPackageService::get_capabilities() const { return capabilities(); }

Dictionary MapPackageService::get_schema_ids() const {
	Dictionary result;
	result["map_document"] = MAP_SCHEMA_ID;
	result["scenario_document"] = SCENARIO_SCHEMA_ID;
	result["map_validation_report"] = "aurelion_map_validation_report";
	result["scenario_validation_report"] = "aurelion_scenario_validation_report";
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
	(void)options;
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
	(void)options;
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

Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return validate_map_document_structural_report(map_document);
}

Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return validate_scenario_document_structural_report(scenario_document, map_document);
}

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
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)), bool(options.get("include_browser_manifest_cache_profile", false)));
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
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)), bool(options.get("include_browser_manifest_cache_profile", false)));
}

Dictionary MapPackageService::migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options) const {
	(void)target_path;
	(void)target_version;
	return not_implemented("migrate_map_package", source_path, options);
}

Dictionary MapPackageService::migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options) const {
	(void)target_path;
	(void)target_version;
	return not_implemented("migrate_scenario_package", source_path, options);
}

Dictionary MapPackageService::convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options) const {
	const String operation = "convert_legacy_scenario_record";
	const String source_scenario_id = String(scenario_record.get("id", "")).strip_edges();
	if (source_scenario_id.is_empty()) {
		return package_failure(operation, "", "missing_scenario_id", "Legacy scenario conversion requires a non-empty scenario id.");
	}
	const String terrain_record_id = String(terrain_layers_record.get("id", source_scenario_id)).strip_edges();
	if (!terrain_record_id.is_empty() && terrain_record_id != source_scenario_id) {
		return package_failure(operation, "", "terrain_scenario_id_mismatch", "Terrain-layer record id must match the legacy scenario id.");
	}

	Variant map_value = scenario_record.get("map", Variant());
	if (map_value.get_type() != Variant::ARRAY) {
		return package_failure(operation, "", "invalid_map_rows", "Legacy scenario map must be an array of terrain rows.");
	}
	Array map_rows = map_value;
	Variant map_size_value = scenario_record.get("map_size", Variant());
	if (map_size_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, "", "invalid_map_size", "Legacy scenario map_size must be a dictionary.");
	}
	Dictionary map_size = map_size_value;
	const int32_t height = int32_t(map_size.get("height", map_rows.size()));
	int32_t width = int32_t(map_size.get("width", 0));
	if (width <= 0 && !map_rows.is_empty() && map_rows[0].get_type() == Variant::ARRAY) {
		width = Array(map_rows[0]).size();
	}
	if (width <= 0 || height <= 0 || map_rows.size() != height) {
		return package_failure(operation, "", "invalid_map_dimensions", "Legacy scenario map dimensions must be positive and match the authored row count.");
	}

	Dictionary terrain_code_by_id;
	Array terrain_id_by_code;
	for (const char *terrain_id : { "dirt", "sand", "grass", "snow", "swamp", "rough", "underground", "lava", "water", "rock", "forest", "mire", "badlands", "ash", "cavern" }) {
		const String id = terrain_id;
		terrain_code_by_id[id] = terrain_id_by_code.size();
		terrain_id_by_code.append(id);
	}
	PackedInt32Array terrain_codes;
	terrain_codes.resize(width * height);
	for (int32_t y = 0; y < height; ++y) {
		Variant row_value = map_rows[y];
		if (row_value.get_type() != Variant::ARRAY) {
			return package_failure(operation, "", "invalid_map_row", "Legacy scenario map rows must be arrays.");
		}
		Array row = row_value;
		if (row.size() != width) {
			return package_failure(operation, "", "ragged_map_rows", "Legacy scenario map rows must all match map_size.width.");
		}
		for (int32_t x = 0; x < width; ++x) {
			if (row[x].get_type() != Variant::STRING && row[x].get_type() != Variant::STRING_NAME) {
				return package_failure(operation, "", "invalid_terrain_cell", "Legacy scenario terrain cells must contain non-empty terrain ids.");
			}
			const String terrain_id = String(row[x]).strip_edges();
			if (terrain_id.is_empty()) {
				return package_failure(operation, "", "invalid_terrain_cell", "Legacy scenario terrain cells must contain non-empty terrain ids.");
			}
			if (!terrain_code_by_id.has(terrain_id)) {
				terrain_code_by_id[terrain_id] = terrain_id_by_code.size();
				terrain_id_by_code.append(terrain_id);
			}
			terrain_codes.set(y * width + x, int32_t(terrain_code_by_id[terrain_id]));
		}
	}

	Array objects;
	Dictionary placement_ids;
	String object_failure_code;
	String object_failure_message;
	auto append_objects = [&](const char *source_key, const char *kind) -> bool {
		Variant source_value = scenario_record.get(source_key, Variant());
		if (source_value.get_type() == Variant::NIL) {
			return true;
		}
		if (source_value.get_type() != Variant::ARRAY) {
			object_failure_code = "invalid_object_family";
			object_failure_message = String("Legacy scenario ") + source_key + String(" must be an array.");
			return false;
		}
		Array source = source_value;
		for (int64_t index = 0; index < source.size(); ++index) {
			if (source[index].get_type() != Variant::DICTIONARY) {
				object_failure_code = "invalid_object_record";
				object_failure_message = String("Legacy scenario ") + source_key + String(" contains a non-dictionary placement.");
				return false;
			}
			Dictionary object = Dictionary(source[index]).duplicate(true);
			const String placement_id = String(object.get("placement_id", "")).strip_edges();
			if (placement_id.is_empty()) {
				object_failure_code = "missing_placement_id";
				object_failure_message = String("Legacy scenario ") + source_key + String(" contains a placement without placement_id.");
				return false;
			}
			if (placement_ids.has(placement_id)) {
				object_failure_code = "duplicate_placement_id";
				object_failure_message = String("Legacy scenario contains duplicate placement_id: ") + placement_id;
				return false;
			}
			const int32_t x = int32_t(object.get("x", -1));
			const int32_t y = int32_t(object.get("y", -1));
			const int32_t level = int32_t(object.get("level", 0));
			if (x < 0 || y < 0 || x >= width || y >= height || level != 0) {
				object_failure_code = "object_out_of_bounds";
				object_failure_message = String("Legacy scenario ") + source_key + String(" contains an out-of-bounds placement.");
				return false;
			}
			object["kind"] = kind;
			object["source_kind"] = "authored_legacy_scenario";
			object["level"] = level;
			placement_ids[placement_id] = true;
			objects.append(object);
		}
		return true;
	};
	if (!append_objects("towns", "town")
			|| !append_objects("resource_nodes", "resource_site")
			|| !append_objects("artifact_nodes", "artifact")
			|| !append_objects("encounters", "encounter")) {
		return package_failure(operation, "", object_failure_code, object_failure_message);
	}
	Variant map_objects_value = scenario_record.get("map_objects", Variant());
	if (map_objects_value.get_type() != Variant::NIL) {
		if (map_objects_value.get_type() != Variant::ARRAY) {
			return package_failure(operation, "", "invalid_map_objects", "Legacy scenario map_objects must be an array.");
		}
		Array map_objects = map_objects_value;
		for (int64_t index = 0; index < map_objects.size(); ++index) {
			if (map_objects[index].get_type() != Variant::DICTIONARY) {
				return package_failure(operation, "", "invalid_map_object_record", "Legacy scenario map_objects contains a non-dictionary placement.");
			}
			Dictionary object = Dictionary(map_objects[index]).duplicate(true);
			const String placement_id = String(object.get("placement_id", "")).strip_edges();
			if (placement_id.is_empty()) {
				return package_failure(operation, "", "missing_placement_id", "Legacy scenario map_objects contains a placement without placement_id.");
			}
			// Runtime family projections can contain the same source object. The editable
			// family record wins while standalone source objects remain byte-faithful.
			if (placement_ids.has(placement_id)) {
				continue;
			}
			const int32_t x = int32_t(object.get("x", -1));
			const int32_t y = int32_t(object.get("y", -1));
			const int32_t level = int32_t(object.get("level", 0));
			if (x < 0 || y < 0 || x >= width || y >= height || level != 0) {
				return package_failure(operation, "", "object_out_of_bounds", "Legacy scenario map_objects contains an out-of-bounds placement.");
			}
			String object_kind = String(object.get("kind", "")).strip_edges();
			if (object_kind.is_empty()) {
				object_kind = String(object.get("native_record_kind", "")).strip_edges();
			}
			if (object_kind.is_empty()) {
				return package_failure(operation, "", "missing_object_kind", "Legacy scenario map_objects contains a placement without kind.");
			}
			object["level"] = level;
			placement_ids[placement_id] = true;
			objects.append(object);
		}
	}

	Array roads;
	Variant roads_value = terrain_layers_record.get("roads", Array());
	if (roads_value.get_type() != Variant::ARRAY) {
		return package_failure(operation, "", "invalid_road_layers", "Legacy terrain-layer roads must be an array.");
	}
	roads = Array(roads_value).duplicate(true);
	for (int64_t road_index = 0; road_index < roads.size(); ++road_index) {
		if (roads[road_index].get_type() != Variant::DICTIONARY) {
			return package_failure(operation, "", "invalid_road_record", "Legacy terrain-layer roads contain a non-dictionary record.");
		}
		Dictionary road = roads[road_index];
		Variant tiles_value = road.get("tiles", Variant());
		if (tiles_value.get_type() != Variant::ARRAY) {
			return package_failure(operation, "", "invalid_road_tiles", "Legacy terrain-layer road tiles must be an array.");
		}
		Array tiles = tiles_value;
		for (int64_t tile_index = 0; tile_index < tiles.size(); ++tile_index) {
			if (tiles[tile_index].get_type() != Variant::DICTIONARY) {
				return package_failure(operation, "", "invalid_road_tile", "Legacy terrain-layer roads contain a non-dictionary tile.");
			}
			Dictionary tile = tiles[tile_index];
			const int32_t x = int32_t(tile.get("x", -1));
			const int32_t y = int32_t(tile.get("y", -1));
			if (x < 0 || y < 0 || x >= width || y >= height) {
				return package_failure(operation, "", "road_tile_out_of_bounds", "Legacy terrain-layer roads contain an out-of-bounds tile.");
			}
		}
	}

	Dictionary terrain_layer;
	Array terrain_levels;
	terrain_levels.append(terrain_codes);
	terrain_layer["levels"] = terrain_levels;
	Dictionary converted_terrain_layers;
	converted_terrain_layers["schema_id"] = "aurelion_terrain_layers";
	converted_terrain_layers["schema_version"] = 1;
	converted_terrain_layers["terrain_id_by_code"] = terrain_id_by_code;
	converted_terrain_layers["terrain"] = terrain_layer;
	converted_terrain_layers["terrain_layer_status"] = terrain_layers_record.get("terrain_layer_status", "foundation_authored");
	converted_terrain_layers["roads"] = roads;

	const String scenario_id = String(options.get("scenario_id", source_scenario_id)).strip_edges();
	const String map_id = String(options.get("map_id", scenario_id + String("_map"))).strip_edges();
	if (scenario_id.is_empty() || map_id.is_empty()) {
		return package_failure(operation, "", "invalid_target_identity", "Converted map and scenario ids must be non-empty.");
	}
	Dictionary map_identity;
	map_identity["map_id"] = map_id;
	map_identity["map"] = map_rows;
	map_identity["terrain_layers"] = converted_terrain_layers;
	map_identity["objects"] = objects;
	const String map_hash = "fnv1a32:" + hash32_hex(canonical_variant(map_identity));

	Dictionary metadata;
	metadata["generated"] = false;
	metadata["source_kind"] = "authored_legacy_scenario_conversion";
	metadata["source_scenario_id"] = source_scenario_id;
	metadata["display_name"] = scenario_record.get("name", source_scenario_id);
	metadata["legacy_json_writeback"] = false;
	Dictionary route_graph;
	route_graph["schema_id"] = "aurelion_route_graph";
	route_graph["nodes"] = Array();
	route_graph["edges"] = Array();
	Dictionary map_state;
	map_state["map_id"] = map_id;
	map_state["map_hash"] = map_hash;
	map_state["source_kind"] = "authored_legacy_scenario_conversion";
	map_state["width"] = width;
	map_state["height"] = height;
	map_state["level_count"] = 1;
	map_state["metadata"] = metadata;
	map_state["terrain_layers"] = converted_terrain_layers;
	map_state["route_graph"] = route_graph;
	map_state["objects"] = objects;
	Ref<MapDocument> map_document;
	map_document.instantiate();
	map_document->configure(map_state);

	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = MapDocument::SCHEMA_VERSION;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["source_kind"] = "authored_legacy_scenario_conversion";
	Array player_slots;
	Variant player_slots_value = scenario_record.get("player_slots", Variant());
	if (player_slots_value.get_type() != Variant::NIL) {
		if (player_slots_value.get_type() != Variant::ARRAY) {
			return package_failure(operation, "", "invalid_player_slots", "Legacy scenario player_slots must be an array.");
		}
		player_slots = Array(player_slots_value).duplicate(true);
	}
	const bool preserve_explicit_player_slots = !player_slots.is_empty();
	if (player_slots.is_empty()) {
		Dictionary player_slot;
		player_slot["slot"] = 1;
		player_slot["owner"] = "player";
		player_slot["human"] = true;
		player_slot["computer"] = false;
		player_slot["faction_id"] = scenario_record.get("player_faction_id", "");
		player_slots.append(player_slot);
	}
	Variant enemy_factions_value = scenario_record.get("enemy_factions", Array());
	if (enemy_factions_value.get_type() != Variant::ARRAY) {
		return package_failure(operation, "", "invalid_enemy_factions", "Legacy scenario enemy_factions must be an array.");
	}
	Array enemy_factions = Array(enemy_factions_value).duplicate(true);
	for (int64_t index = 0; !preserve_explicit_player_slots && index < enemy_factions.size(); ++index) {
		String faction_id;
		if (enemy_factions[index].get_type() == Variant::DICTIONARY) {
			Dictionary enemy = enemy_factions[index];
			faction_id = String(enemy.get("faction_id", enemy.get("id", ""))).strip_edges();
		} else {
			faction_id = String(enemy_factions[index]).strip_edges();
		}
		if (faction_id.is_empty()) {
			continue;
		}
		Dictionary enemy_slot;
		enemy_slot["slot"] = player_slots.size() + 1;
		enemy_slot["owner"] = "enemy";
		enemy_slot["human"] = false;
		enemy_slot["computer"] = true;
		enemy_slot["faction_id"] = faction_id;
		player_slots.append(enemy_slot);
	}
	Variant start_value = scenario_record.get("start", Dictionary());
	if (start_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, "", "invalid_start_contract", "Legacy scenario start must be a dictionary.");
	}
	Dictionary start_contract = Dictionary(start_value).duplicate(true);
	start_contract["hero_id"] = scenario_record.get("hero_id", "");
	start_contract["player_army_id"] = scenario_record.get("player_army_id", "");
	start_contract["player_faction_id"] = scenario_record.get("player_faction_id", "");
	start_contract["starting_resources"] = scenario_record.get("starting_resources", Dictionary());
	if (scenario_record.has("hero_starts")) {
		start_contract["hero_starts"] = scenario_record.get("hero_starts", Array());
	}
	Dictionary scenario_identity;
	scenario_identity["scenario_id"] = scenario_id;
	scenario_identity["map_hash"] = map_hash;
	scenario_identity["selection"] = scenario_record.get("selection", Dictionary());
	scenario_identity["player_slots"] = player_slots;
	scenario_identity["objectives"] = scenario_record.get("objectives", Dictionary());
	scenario_identity["script_hooks"] = scenario_record.get("script_hooks", Array());
	scenario_identity["enemy_factions"] = enemy_factions;
	scenario_identity["start_contract"] = start_contract;
	const String scenario_hash = "fnv1a32:" + hash32_hex(canonical_variant(scenario_identity));
	Dictionary scenario_state = scenario_identity.duplicate(true);
	scenario_state["scenario_id"] = scenario_id;
	scenario_state["scenario_hash"] = scenario_hash;
	scenario_state["map_ref"] = map_ref;
	Ref<ScenarioDocument> scenario_document;
	scenario_document.instantiate();
	scenario_document->configure(scenario_state);

	Dictionary map_validation = validate_map_document_structural_report(map_document);
	Dictionary scenario_validation = validate_scenario_document_structural_report(scenario_document, map_document);
	if (!bool(map_validation.get("ok", false)) || !bool(scenario_validation.get("ok", false))) {
		Dictionary failure = package_failure(operation, "", "converted_document_validation_failed", "Converted legacy scenario documents failed structural validation.");
		failure["map_validation"] = map_validation;
		failure["scenario_validation"] = scenario_validation;
		return failure;
	}

	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = ScenarioDocument::SCHEMA_VERSION;
	scenario_ref["scenario_id"] = scenario_id;
	scenario_ref["scenario_hash"] = scenario_hash;
	scenario_ref["map_ref"] = map_ref;
	Dictionary payload;
	payload["map_document"] = map_document;
	payload["scenario_document"] = scenario_document;
	payload["map_ref"] = map_ref;
	payload["scenario_ref"] = scenario_ref;
	payload["map_validation"] = map_validation;
	payload["scenario_validation"] = scenario_validation;
	payload["source_scenario_id"] = source_scenario_id;
	payload["source_kind"] = "authored_legacy_scenario_conversion";
	payload["conversion_policy"] = "typed_documents_no_authored_json_writeback";
	payload["object_count"] = objects.size();
	payload["terrain_cell_count"] = terrain_codes.size();
	return package_success(operation, "", payload);
}

Dictionary MapPackageService::convert_generated_payload(Dictionary generated_map, Dictionary options) const {
	return build_native_package_session_adoption(generated_map, options);
}

Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const {
	(void)options;
	Dictionary result;
	result["ok"] = true;
	result["status"] = "pass";
	result["algorithm"] = "canonical_variant_fnv1a32";
	result["hash"] = "fnv1a32:" + hash32_hex(canonical_variant(document));
	return result;
}

Dictionary MapPackageService::inspect_package(String path, Dictionary options) const {
	const bool bypass_cache = String(options.get("browser_manifest_cache_mode", "default")) == "bypass_read";
	const bool include_cache_profile = bool(options.get("include_browser_manifest_cache_profile", false));
	const String source_sha256 = FileAccess::file_exists(path) ? FileAccess::get_sha256(path) : String();
	const String cache_path = browser_manifest_cache_path(path);
	if (!bypass_cache) {
		Dictionary cached_payload = read_browser_manifest_cache(path, source_sha256);
		if (!cached_payload.is_empty()) {
			Dictionary cached_result = package_success("inspect_package", path, cached_payload);
			if (include_cache_profile) {
				Dictionary profile;
				profile["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
				profile["status"] = "hit";
				profile["source_sha256"] = source_sha256;
				profile["cache_path"] = cache_path;
				cached_result["browser_manifest_cache_profile"] = profile;
			}
			return cached_result;
		}
	}
	Dictionary read_result = read_package_dictionary("inspect_package", path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	Dictionary payload = package_inspection_payload(package);
	const bool cache_written = write_browser_manifest_cache(path, source_sha256, payload);
	Dictionary result = package_success("inspect_package", path, payload);
	if (include_cache_profile) {
		Dictionary profile;
		profile["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
		profile["status"] = cache_written ? (bypass_cache ? "bypass_written" : "miss_written") : "not_cacheable";
		profile["source_sha256"] = source_sha256;
		profile["cache_path"] = cache_path;
		result["browser_manifest_cache_profile"] = profile;
	}
	return result;
}

Dictionary MapPackageService::inspect_random_map_generator_data_model(Dictionary options) const {
	return rmg_data_model::inspect_generator_data_model(options);
}

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	Variant size_value = config.get("size", Variant());
	Dictionary size = size_value.get_type() == Variant::DICTIONARY ? Dictionary(size_value) : Dictionary();
	Variant profile_value = config.get("profile", Variant());
	Dictionary profile = profile_value.get_type() == Variant::DICTIONARY ? Dictionary(profile_value) : Dictionary();
	Variant player_setup_value = config.get("player_setup", Variant());
	Dictionary player_setup = player_setup_value.get_type() == Variant::DICTIONARY ? Dictionary(player_setup_value) : Dictionary();

	const String size_class_id = normalized_size_class_id(config, size);
	const int32_t default_dimension = dimension_for_size_class(size_class_id, 36);
	const int32_t width = nested_size_int(config, size, "width", "requested_width", default_dimension);
	const int32_t height = nested_size_int(config, size, "height", "requested_height", default_dimension);
	Dictionary player_constraints = normalized_player_constraints(config);
	const int32_t player_count = int32_t(player_constraints.get("player_count", 2));
	Array terrain_ids = normalized_string_array(profile.get("terrain_ids", Variant()), default_terrain_pool());
	Array faction_ids = ensure_repeated_to_count(normalized_string_array(profile.get("faction_ids", Variant()), default_faction_pool()), default_faction_pool(), player_count);
	Array town_ids = town_ids_for_factions(profile.get("town_ids", Variant()), faction_ids, player_count);

	Dictionary result;
	result["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	result["schema_version"] = 1;
	result["normalizer_version"] = NATIVE_RMG_VERSION;
	result["seed"] = normalized_text(config, "seed", "0");
	result["normalized_seed"] = result["seed"];
	result["width"] = width;
	result["height"] = height;
	result["level_count"] = std::max<int32_t>(1, std::min<int32_t>(2, normalized_int(size, "level_count", normalized_int(config, "level_count", 1))));
	result["template_id"] = normalized_text(config, "template_id", normalized_text(profile, "template_id", ""));
	result["profile_id"] = normalized_text(profile, "id", normalized_text(config, "profile_id", ""));
	result["size_class_id"] = size_class_id;
	result["water_mode"] = normalized_water_mode(config, size);
	result["monster_strength"] = normalized_text(config, "monster_strength", "random").strip_edges().to_lower();
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	if (!player_setup.is_empty()) {
		Dictionary normalized_player_setup;
		normalized_player_setup["faction_id"] = String(player_setup.get("faction_id", "")).strip_edges();
		normalized_player_setup["hero_id"] = String(player_setup.get("hero_id", "")).strip_edges();
		normalized_player_setup["selection_mode"] = String(player_setup.get("selection_mode", "player_selected")).strip_edges();
		result["player_setup"] = normalized_player_setup;
	}
	result["template_selection_mode"] = "recovered_h3maped_exe_rng_exact_state_chain";
	result["template_selection_authority"] = "recovered_h3maped_exe_source_order";
	result["template_selection_runtime_generation_allowed"] = true;
	result["translated_template_authority_used"] = false;
	const Dictionary runtime_policy = native_rmg_runtime_policy_classification(result);
	const bool supported_parity_config = bool(runtime_policy.get("runtime_generation_allowed", false));
	result["full_generation_status"] = supported_parity_config
			? "native_runtime_ready_for_supported_scope"
			: "native_runtime_blocked_outside_supported_scope";
	result["supported_parity_config"] = supported_parity_config;
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(result);
	result["normalization_scope"] = supported_parity_config
			? "native_runtime_generation_supported_scope"
			: "native_runtime_generation_unsupported_scope";
	return result;
}

Dictionary MapPackageService::random_map_config_identity(Dictionary config) const {
	Dictionary normalized = normalize_random_map_config(config);
	const String canonical = canonical_variant(normalized);
	const String signature = hash32_hex(canonical);

	Dictionary result;
	result["ok"] = true;
	result["schema_id"] = "aurelion_native_random_map_identity";
	result["schema_version"] = 1;
	result["algorithm"] = "canonical_variant_fnv1a32_config_normalization";
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
	const Dictionary runtime_policy = native_rmg_runtime_policy_classification(normalized);
	const bool supported = bool(runtime_policy.get("runtime_generation_allowed", false));
	result["full_generation_status"] = supported
			? "native_runtime_ready_for_supported_scope"
			: "native_runtime_blocked_outside_supported_scope";
	result["supported_parity_config"] = supported;
	result["runtime_policy_classification"] = runtime_policy;
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	const bool include_performance_profile = bool(options.get("include_performance_profile", false));
	const auto total_started_at = SteadyClock::now();
	Dictionary performance_profile;
	performance_profile["schema_id"] = "aurelion_native_rmg_generation_performance_profile_v1";
	performance_profile["size_class_id"] = String(config.get("size_class_id", ""));
	performance_profile["buckets_ms"] = Dictionary();
	auto record_bucket = [&](const char *bucket, const SteadyClock::time_point &started_at) {
		if (!include_performance_profile) {
			return;
		}
		Dictionary buckets = performance_profile.get("buckets_ms", Dictionary());
		buckets[bucket] = elapsed_milliseconds(started_at);
		performance_profile["buckets_ms"] = buckets;
	};
	const auto normalize_started_at = SteadyClock::now();
	Dictionary normalized = normalize_random_map_config(config);
	record_bucket("normalize_config", normalize_started_at);
	if (!h3maped_core_supports_land_scope(normalized)) {
		return native_rmg_exact_chain_unimplemented_blocked_result(
				normalized,
				extension_profile_stub(normalized),
				native_rmg_runtime_policy_classification(normalized));
	}
	const String monster_strength = normalized.get("monster_strength", "random");
	if (!known_h3maped_monster_strength(monster_strength)) {
		Dictionary blocked = native_rmg_exact_chain_unimplemented_blocked_result(
				normalized,
				extension_profile_stub(normalized),
				native_rmg_runtime_policy_classification(normalized));
		blocked["error_code"] = "native_rmg_monster_strength_unsupported";
		blocked["message"] = "Monster strength must be random, weak, normal, or strong.";
		return blocked;
	}

	const Dictionary players = normalized.get("player_constraints", Dictionary());
	aurelion::h3maped_rmg_core::H3MapedRmgWorkflowConfig workflow_config;
	const String size_class = normalized.get("size_class_id", "");
	const String water_mode = normalized.get("water_mode", "land");
	workflow_config.size_class = std::string(size_class.utf8().get_data());
	workflow_config.water_mode = std::string(water_mode.utf8().get_data());
	workflow_config.width = int32_t(normalized.get("width", 0));
	workflow_config.height = int32_t(normalized.get("height", 0));
	workflow_config.level_count = int32_t(normalized.get("level_count", 1));
	workflow_config.human_count = int32_t(players.get("human_count", 1));
	workflow_config.player_count = int32_t(players.get("player_count", 2));
	const String seed_text = normalized.get("normalized_seed", "0");
	workflow_config.seed = uint32_t(uint64_t(seed_text.to_int()) & 0xffffffffULL);
	workflow_config.setup_object_0x34_known = true;
	workflow_config.setup_object_0x34 = workflow_config.human_count;
	workflow_config.setup_object_0x38_known = true;
	workflow_config.setup_object_0x38 = int32_t(players.get("human_team_count", workflow_config.human_count));
	workflow_config.setup_object_0x3c_known = true;
	workflow_config.setup_object_0x3c = int32_t(players.get("computer_count", workflow_config.player_count - workflow_config.human_count));
	workflow_config.setup_object_0x40_known = true;
	workflow_config.setup_object_0x40 = int32_t(players.get("computer_team_count", 0));
	workflow_config.setup_object_0x44_known = true;
	workflow_config.setup_object_0x44 = aurelion::h3maped_rmg_core::water_mode_code(
			std::string(water_mode.utf8().get_data()));
	workflow_config.setup_object_raw_0x48_known = true;
	workflow_config.setup_object_raw_0x48 = h3maped_monster_strength_raw_0x48(monster_strength);
	workflow_config.setup_object_0x48_known = false;
	workflow_config.setup_object_0x4c_known = true;
	workflow_config.setup_object_0x4c = 2;
	workflow_config.setup_caller_arg_0x0c_known = true;
	workflow_config.setup_caller_arg_0x0c =
			aurelion::h3maped_rmg_core::DIRECT_ENTRY_OPTIONAL_HANDLER_SENTINEL_0X4602C1;

	const auto workflow_started_at = SteadyClock::now();
	const auto workflow =
			aurelion::h3maped_rmg_core::run_h3maped_rmg_entry_to_writeout_workflow(workflow_config);
	record_bucket("recovered_workflow", workflow_started_at);
	const auto projection_started_at = SteadyClock::now();
	const auto projection =
			aurelion::h3maped_rmg_core::project_runtime_map_from_native_owned_final_payload(workflow);
	record_bucket("final_payload_projection", projection_started_at);
	if (!projection.applied) {
		Dictionary blocked;
		blocked["ok"] = false;
		blocked["status"] = "blocked";
		blocked["generation_status"] = "native_rmg_workflow_blocked";
		blocked["error_code"] = "native_rmg_final_payload_projection_blocked";
		blocked["message"] = String(projection.blocked_reason.c_str());
		blocked["workflow_status"] = String(workflow.status.c_str());
		blocked["workflow_phase"] = String(workflow.current_phase_id.c_str());
		blocked["workflow_blocked_reason"] = String(workflow.blocked_reason.c_str());
		blocked["normalized_config"] = normalized.duplicate(true);
		blocked["runtime_generation_allowed"] = false;
		blocked["native_runtime_authoritative"] = false;
		return blocked;
	}

	const String payload_token = hash32_hex_bytes(workflow.final_payload_writeout_0x4ad1e3.payload_bytes);
	const Dictionary player_setup = normalized.get("player_setup", Dictionary());
	const String player_faction_id = String(player_setup.get("faction_id", "")).strip_edges();
	const String player_hero_id = String(player_setup.get("hero_id", "")).strip_edges();
	const String runtime_identity_token = player_setup.is_empty()
			? payload_token
			: hash32_hex(payload_token + String(":") + player_faction_id + String(":") + player_hero_id);
	const String map_id = "native_h3maped_" + runtime_identity_token;
	const String map_hash = "fnv1a32:" + runtime_identity_token;
	const String scenario_id = map_id + String("_skirmish");
	const String scenario_hash = String("fnv1a32:") + hash32_hex(map_hash + String(":scenario"));

	Dictionary map_state;
	map_state["map_id"] = map_id;
	map_state["map_hash"] = map_hash;
	map_state["source_kind"] = "generated_h3maped_native_parity";
	map_state["width"] = projection.width;
	map_state["height"] = projection.height;
	map_state["level_count"] = projection.level_count;
	Dictionary metadata;
	metadata["generated"] = true;
	metadata["source_kind"] = "generated_h3maped_native_parity";
	metadata["source_template_authority"] = "h3maped_exe_rng";
	metadata["source_order_authority"] = "recovered_h3maped_exe_source_order";
	const String source_template_id = String("h3maped_template_")
			+ String::num_int64(workflow.template_selection_0x4ac552.selected_source_catalog_index).pad_zeros(3);
	metadata["source_template_id"] = source_template_id;
	metadata["template_id"] = source_template_id;
	metadata["full_generation_status"] = "native_runtime_ready";
	metadata["validation_status"] = "pass";
	metadata["native_runtime_authoritative"] = true;
	metadata["full_parity_claim"] = true;
	metadata["native_h3m_final_payload_parity"] = true;
	metadata["runtime_payload_projection_complete"] = true;
	metadata["production_ready"] = true;
	Dictionary package_normalized_config = normalized.duplicate(true);
	package_normalized_config["template_id"] = source_template_id;
	package_normalized_config["source_template_id"] = source_template_id;
	package_normalized_config["full_generation_status"] = "native_runtime_ready";
	metadata["normalized_config"] = package_normalized_config;
	metadata["final_payload_byte_count"] = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
	metadata["final_payload_fnv1a32"] = payload_token;
	metadata["runtime_player_setup"] = player_setup.duplicate(true);
	Dictionary component_counts;
	component_counts["tile_count"] = projection.tile_count;
	component_counts["object_count"] = projection.object_count;
	component_counts["object_definition_count"] = projection.object_definition_count;
	component_counts["road_cell_count"] = int32_t(projection.road_tiles.size());
	component_counts["zone_count"] = int32_t(workflow.template_selection_0x4ac552.runtime_seed.runtime_zone_seeds.size());
	int32_t town_count = 0;
	for (const auto &object : projection.objects) {
		if (object.type_id == 98) {
			++town_count;
		}
	}
	component_counts["town_count"] = town_count;
	metadata["component_counts"] = component_counts;
	map_state["metadata"] = metadata;
	const auto terrain_started_at = SteadyClock::now();
	map_state["terrain_layers"] = runtime_terrain_layers(projection);
	record_bucket("terrain_variant_projection", terrain_started_at);
	Dictionary route_graph;
	route_graph["schema_id"] = "aurelion_route_graph";
	route_graph["nodes"] = Array();
	route_graph["edges"] = Array();
	map_state["route_graph"] = route_graph;
	const auto objects_started_at = SteadyClock::now();
	Dictionary runtime_object_projection = runtime_objects(map_id, projection, normalized);
	record_bucket("object_variant_projection", objects_started_at);
	if (!bool(runtime_object_projection.get("ok", false))) {
		Dictionary blocked;
		blocked["ok"] = false;
		blocked["status"] = "blocked";
		blocked["error_code"] = "native_rmg_authored_object_pool_resolution_failed";
		blocked["message"] = "Native final-payload objects did not all resolve through an original-content pool or an explicit nonvisitable/passthrough owner.";
		blocked["object_pool_resolution"] = runtime_object_projection;
		blocked["final_payload_fnv1a32"] = payload_token;
		blocked["final_payload_byte_count"] = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
		return blocked;
	}
	Dictionary metadata_pool_resolution;
	for (const char *field : {
				"failure_count",
				"resolution_counts",
				"registry_path",
				"registry_schema",
				"registry_loaded" }) {
		metadata_pool_resolution[field] = runtime_object_projection.get(field, Variant());
	}
	metadata_pool_resolution["ok"] = true;
	metadata["native_authored_object_pool_resolution"] = metadata_pool_resolution;
	map_state["metadata"] = metadata;
	map_state["objects"] = runtime_object_projection.get("objects", Array());
	Ref<MapDocument> map_document;
	map_document.instantiate();
	map_document->configure(map_state);

	Array player_slots;
	Array enemy_factions;
	Array player_starts;
	Array player_start_towns;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active) {
			continue;
		}
		Dictionary player_slot;
		player_slot["slot"] = slot.color + 1;
		player_slot["color"] = slot.color;
		player_slot["human"] = slot.human;
		player_slot["computer"] = slot.computer;
		player_slot["owner"] = slot.human ? "player" : "enemy";
		player_slot["faction_id"] = configured_runtime_faction_id(&slot, normalized);
		player_slots.append(player_slot);
		if (slot.computer) {
			enemy_factions.append(configured_runtime_faction_id(&slot, normalized));
		}
		if (slot.has_main_town) {
			Dictionary start;
			start["start_id"] = "player_start_" + String::num_int64(slot.color + 1);
			start["owner"] = slot.human ? "player" : "enemy";
			start["owner_slot"] = slot.color + 1;
			start["player_slot"] = slot.color + 1;
			start["player_type"] = slot.human ? "human" : "computer";
			start["faction_id"] = configured_runtime_faction_id(&slot, normalized);
			start["town_id"] = configured_runtime_town_id(&slot, normalized);
			start["town_placement_id"] = runtime_town_placement_id(map_id, slot, projection);
			start["x"] = slot.town_x;
			start["y"] = slot.town_y;
			start["level"] = slot.town_level;
			const Dictionary runtime_start_tile = runtime_start_tile_for_slot(slot, projection);
			if (runtime_start_tile.is_empty()) {
				Dictionary blocked;
				blocked["ok"] = false;
				blocked["status"] = "blocked";
				blocked["error_code"] = "native_rmg_runtime_start_blocked_by_exact_h3m_masks";
				blocked["message"] = "Native payload projection did not expose an exact-mask-safe runtime start tile.";
				blocked["player_slot"] = slot.color + 1;
				blocked["town_x"] = slot.town_x;
				blocked["town_y"] = slot.town_y;
				blocked["town_level"] = slot.town_level;
				return blocked;
			}
			start["hero_start_tile"] = runtime_start_tile;
			start["runtime_start_tile"] = runtime_start_tile.duplicate(true);
			player_starts.append(start);
			player_start_towns.append(start.duplicate(true));
		}
	}

	Dictionary scenario_state;
	scenario_state["scenario_id"] = scenario_id;
	scenario_state["scenario_hash"] = scenario_hash;
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = MapDocument::SCHEMA_VERSION;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["source_kind"] = "generated_h3maped_native_parity";
	scenario_state["map_ref"] = map_ref;
	Dictionary selection;
	selection["template_id"] = normalized.get("template_id", "");
	selection["seed"] = seed_text;
	selection["water_mode"] = water_mode;
	selection["player_faction_id"] = player_faction_id;
	selection["player_hero_id"] = player_hero_id;
	scenario_state["selection"] = selection;
	scenario_state["player_slots"] = player_slots;
	Dictionary objectives;
	objectives["kind"] = "defeat_generated_rivals";
	objectives["description"] = "Defeat every rival commander.";
	scenario_state["objectives"] = objectives;
	scenario_state["script_hooks"] = Array();
	scenario_state["enemy_factions"] = enemy_factions;
	Dictionary start_contract;
	start_contract["schema_id"] = "aurelion_native_rmg_start_contract_v1";
	start_contract["primary_hero_id"] = player_hero_id.is_empty() ? String("hero_lyra") : player_hero_id;
	start_contract["player_faction_id"] = player_faction_id;
	start_contract["player_starts"] = player_starts;
	start_contract["player_start_towns"] = player_start_towns;
	start_contract["start_count"] = player_starts.size();
	start_contract["start_town_count"] = player_start_towns.size();
	scenario_state["start_contract"] = start_contract;
	Ref<ScenarioDocument> scenario_document;
	scenario_document.instantiate();
	scenario_document->configure(scenario_state);

	const auto validation_started_at = SteadyClock::now();
	Dictionary map_validation = validate_map_document_structural_report(map_document);
	Dictionary scenario_validation = validate_scenario_document_structural_report(scenario_document, map_document);
	record_bucket("document_validation", validation_started_at);
	if (!bool(map_validation.get("ok", false)) || !bool(scenario_validation.get("ok", false))) {
		Dictionary blocked;
		blocked["ok"] = false;
		blocked["status"] = "blocked";
		blocked["error_code"] = "native_rmg_runtime_document_validation_failed";
		blocked["message"] = "Native payload projection did not produce structurally valid runtime documents.";
		blocked["map_validation"] = map_validation;
		blocked["scenario_validation"] = scenario_validation;
		return blocked;
	}

	Dictionary result;
	result["ok"] = true;
	result["status"] = "complete";
	result["generation_status"] = "native_rmg_complete";
	result["full_generation_status"] = "native_runtime_ready";
	result["normalized_config"] = normalized.duplicate(true);
	result["map_id"] = map_id;
	result["map_hash"] = map_hash;
	result["scenario_id"] = scenario_id;
	result["scenario_hash"] = scenario_hash;
	result["map_document"] = map_document;
	result["scenario_document"] = scenario_document;
	result["map_validation"] = map_validation;
	result["scenario_validation"] = scenario_validation;
	if (include_performance_profile) {
		performance_profile["total_ms"] = elapsed_milliseconds(total_started_at);
		result["performance_profile"] = performance_profile;
	}
	result["final_payload_byte_count"] = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
	result["final_payload_fnv1a32"] = payload_token;
	result["runtime_tile_count"] = projection.tile_count;
	result["runtime_object_count"] = projection.object_count;
	result["runtime_road_cell_count"] = int32_t(projection.road_tiles.size());
	result["runtime_payload_projection_complete"] = true;
	result["supported_parity_config"] = true;
	result["runtime_generation_allowed"] = true;
	result["native_runtime_authoritative"] = true;
	result["public_runtime_authoritative"] = true;
	result["package_session_adoption_ready"] = true;
	result["full_parity_claim"] = true;
	return result;
}
