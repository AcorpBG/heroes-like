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
#include <cstdint>
#include <string>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *MAP_PACKAGE_SCHEMA_ID = "aurelion_map_package";
constexpr const char *SCENARIO_PACKAGE_SCHEMA_ID = "aurelion_scenario_package";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_config_normalization";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_exact_h3maped_state_chain_blocked_v1";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_rmg_homm3_generator_data_model_report");
	result.append("native_package_save_load");
	result.append("native_map_package_document_validation");
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

bool h3maped_core_supports_land_scope(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 0));
	const int32_t height = int32_t(normalized.get("height", 0));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const String water_mode = String(normalized.get("water_mode", "land"));
	const String size_class = String(normalized.get("size_class_id", ""));
	return aurelion::h3maped_rmg_core::supports_one_level_land_scope(width, height, level_count, std::string(water_mode.utf8().get_data()), std::string(size_class.utf8().get_data()));
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

Dictionary build_native_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	(void)generated_map;
	(void)options;
	return native_conversion_fail(
			"native_rmg_package_session_adoption_disabled",
			"Generated-map package/session adoption is disabled until the exact recovered H3MapEd private-state chain and executable phase order own the generated payload.");
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
	const bool supported = h3maped_core_supports_land_scope(normalized);
	result["schema_id"] = "aurelion_native_rmg_runtime_policy_classification_v1";
	result["schema_version"] = 1;
	result["supported_h3maped_scope"] = supported;
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(normalized);
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["blocked_reason"] = "exact_h3maped_private_state_chain_not_live_payload_source";
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

Dictionary write_package_dictionary(const String &operation, const String &path, const Dictionary &package, bool return_package = true) {
	if (!ensure_parent_dir(path)) {
		return package_failure(operation, path, "create_directory_failed", "Package parent directory could not be created.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for writing.");
	}
	file->store_string(JSON::stringify(package, "\t", true, false));
	Dictionary payload;
	if (return_package) {
		payload["package"] = package.duplicate(true);
	}
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
	result["native_rmg_generation_authority"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_runtime_generation_allowed"] = false;
	result["native_rmg_runtime_generation_policy"] = "small_36x36_land_and_medium_72x72_land_blocked_until_exact_recovered_h3maped_executable_order_owns_runtime_payload";
	result["native_rmg_production_ready"] = false;
	result["native_rmg_end_to_end_parity_complete"] = false;
	result["native_rmg_end_to_end_parity_status"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_medium_runtime_generation_unblock_scope"] = "disabled_until_exact_h3maped_state_chain_owns_payload";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	result["native_rmg_active_reset_slice_id"] = "native-rmg-exact-h3maped-state-chain-10184";
	result["native_rmg_active_port_capability"] = "native_rmg_small_and_medium_land_inspection_only_until_exact_state_chain";
	result["live_generation_surface_present"] = false;
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
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)));
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
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)));
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
	(void)scenario_record;
	(void)terrain_layers_record;
	return not_implemented("convert_legacy_scenario_record", "", options);
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
	(void)options;
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
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	result["template_selection_mode"] = "h3maped_exe_rng_deferred_exact_state_chain_blocked";
	result["template_selection_authority"] = "h3maped_exe_rng_original_catalog_inspection_only";
	result["template_selection_runtime_generation_allowed"] = false;
	result["translated_template_authority_used"] = false;
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["supported_parity_config"] = h3maped_core_supports_land_scope(result);
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(result);
	result["normalization_scope"] = "config_identity_only_runtime_generation_blocked_until_exact_h3maped_state_chain";
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
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["supported_parity_config"] = h3maped_core_supports_land_scope(normalized);
	result["runtime_policy_classification"] = native_rmg_runtime_policy_classification(normalized);
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	Dictionary normalized = normalize_random_map_config(config);
	Dictionary profile = extension_profile_stub(normalized);
	if (h3maped_core_supports_land_scope(normalized)) {
		return h3maped_exact_state_chain_runtime_blocked_result(normalized, profile, bool(options.get("include_h3maped_small_port", false)));
	}
	return native_rmg_exact_chain_unimplemented_blocked_result(normalized, profile, native_rmg_runtime_policy_classification(normalized));
}
