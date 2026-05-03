#include "map_package_service.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <algorithm>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_foundation";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_foundation_v1";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_random_map_foundation_stub");
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
	return std::min(1024, value);
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

Dictionary MapPackageService::load_map_package(String path, Dictionary options) const { return not_implemented("load_map_package", path, options); }
Dictionary MapPackageService::load_scenario_package(String path, Dictionary options) const { return not_implemented("load_scenario_package", path, options); }
Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_map_document", "aurelion_map_validation_report"); }
Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report"); }
Dictionary MapPackageService::save_map_package(Ref<MapDocument> map_document, String path, Dictionary options) const { return not_implemented("save_map_package", path, options); }
Dictionary MapPackageService::save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options) const { return not_implemented("save_scenario_package", path, options); }
Dictionary MapPackageService::migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_map_package", source_path, options); }
Dictionary MapPackageService::migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_scenario_package", source_path, options); }
Dictionary MapPackageService::convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options) const { return not_implemented("convert_legacy_scenario_record", "", options); }
Dictionary MapPackageService::convert_generated_payload(Dictionary generated_map, Dictionary options) const { return not_implemented("convert_generated_payload", "", options); }
Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const { return not_implemented("compute_document_hash", "", options); }
Dictionary MapPackageService::inspect_package(String path, Dictionary options) const { return not_implemented("inspect_package", path, options); }

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
	result["full_generation_status"] = "not_implemented";
	result["foundation_scope"] = "deterministic_config_identity_and_empty_map_document_stub_only";
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
	result["full_generation_status"] = "not_implemented";
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	Dictionary normalized = normalize_random_map_config(config);
	Dictionary identity = random_map_config_identity(config);

	Dictionary metadata;
	metadata["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	metadata["schema_version"] = 1;
	metadata["generated"] = true;
	metadata["generator_version"] = NATIVE_RMG_VERSION;
	metadata["generation_status"] = "partial_foundation";
	metadata["full_generation_status"] = "not_implemented";
	metadata["normalized_config"] = normalized;
	metadata["deterministic_identity"] = identity;
	metadata["options_keys"] = options.keys();

	Dictionary map_state;
	map_state["map_id"] = identity.get("map_id", "");
	map_state["map_hash"] = identity.get("config_hash", "");
	map_state["source_kind"] = "generated";
	map_state["width"] = int32_t(normalized.get("width", 36));
	map_state["height"] = int32_t(normalized.get("height", 36));
	map_state["level_count"] = int32_t(normalized.get("level_count", 1));
	map_state["metadata"] = metadata;

	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_state);

	Dictionary warning;
	warning["code"] = "full_generation_not_implemented";
	warning["severity"] = "warning";
	warning["path"] = "generate_random_map";
	warning["message"] = "Native RMG currently creates only deterministic identity metadata and an empty MapDocument stub.";
	warning["context"] = Dictionary();

	Array warnings;
	warnings.append(warning);

	Dictionary metrics;
	metrics["width"] = int32_t(normalized.get("width", 36));
	metrics["height"] = int32_t(normalized.get("height", 36));
	metrics["level_count"] = int32_t(normalized.get("level_count", 1));
	metrics["tile_count"] = document->get_tile_count();
	metrics["object_count"] = document->get_object_count();

	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_foundation_report";
	report["schema_version"] = 1;
	report["status"] = "partial_foundation";
	report["failure_count"] = 0;
	report["warning_count"] = warnings.size();
	report["failures"] = Array();
	report["warnings"] = warnings;
	report["metrics"] = metrics;
	report["deterministic_identity"] = identity;

	Dictionary result;
	result["ok"] = true;
	result["status"] = "partial_foundation";
	result["generation_status"] = "partial_foundation";
	result["full_generation_status"] = "not_implemented";
	result["normalized_config"] = normalized;
	result["deterministic_identity"] = identity;
	result["map_document"] = document;
	result["map_metadata"] = metadata;
	result["report"] = report;
	result["adoption_status"] = "not_authoritative_no_runtime_call_site_adoption";
	return result;
}
