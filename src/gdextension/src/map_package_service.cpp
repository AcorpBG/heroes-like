#include "map_package_service.hpp"

#include "core_bridge.hpp"
#include "rmg_data_model.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cmath>
#include <cstdint>
#include <exception>
#include <memory>
#include <mutex>
#include <string>

using namespace godot;

// The package loads, the generation and its projection, the package writes and
// the document checks are the rules core's (Phase 8, the fold;
// aurelion_rules/map_packages.hpp and map_generation.hpp), through a CoreCall
// (core_bridge.hpp). What stays here is the service's own surface (its API
// metadata, stubs and not-implemented migrations), the package browser cache
// and the legacy scenario conversion, which use the core's checks and hashes.

namespace {

namespace map_generation = aurelion::rules::map_generation;
namespace mp = aurelion::rules::map_packages;
namespace st = aurelion::rules::state;
using aurelion::map_bridge::CoreCall;
using aurelion::map_bridge::utf8;

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *MAP_PACKAGE_SCHEMA_ID = "aurelion_map_package";
constexpr const char *SCENARIO_PACKAGE_SCHEMA_ID = "aurelion_scenario_package";
constexpr const char *BROWSER_MANIFEST_CACHE_SCHEMA_ID = "aurelion_package_browser_manifest_cache_v1";
constexpr const char *BROWSER_MANIFEST_CACHE_DIR = "user://package_browser_manifest_cache_v1";
// A cache entry may stand in for hashing its package only when the package was
// last modified at least this long before the entry checked it. A same-size
// rewrite within the second of the hashed write keeps both size and
// modification time, so an entry checked that soon is never trusted on them
// (git's racy-clean rule). Two seconds also covers FAT's 2-second timestamps.
constexpr int64_t BROWSER_MANIFEST_CACHE_SETTLED_SECONDS = 2;

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

// What the generator's last run gave (map_generation::GeneratorCache), for the
// next generation with the same generator inputs.
std::mutex &generator_mutex() {
	static std::mutex mutex;
	return mutex;
}

std::shared_ptr<const map_generation::GeneratorCache::Core> &last_generated_core() {
	static std::shared_ptr<const map_generation::GeneratorCache::Core> core;
	return core;
}

// A service call into the core. The core throws only on a path it leaves out
// or a broken invariant: that is a native failure, printed as an error and
// answered as a failed result.
template <typename Body>
Dictionary core_call(const char *operation, Body &&body) {
	try {
		CoreCall call;
		return call.out_dict(body(call));
	} catch (const std::exception &error) {
		const String message = String("MapPackageService.") + operation + String(": native failure: ") + String::utf8(error.what());
		UtilityFunctions::push_error(message);
		Dictionary result;
		result["ok"] = false;
		result["status"] = "fail";
		result["error_code"] = "native_failure";
		result["message"] = message;
		result["operation"] = operation;
		return result;
	}
}

String core_text(const std::string &text) {
	return String::utf8(text.data(), static_cast<int64_t>(text.size()));
}

// The core's package_failure and package_success results.
Dictionary package_failure(const String &operation, const String &path, const String &code, const String &message) {
	CoreCall call;
	return call.out_dict(mp::package_failure(call.state(), utf8(operation).c_str(), utf8(path), utf8(code).c_str(), utf8(message).c_str()));
}

Dictionary package_success(const String &operation, const String &path, const Dictionary &payload) {
	CoreCall call;
	return call.out_dict(mp::package_success(call.state(), utf8(operation).c_str(), utf8(path), call.in(payload.duplicate(false))));
}

// The core's document hash ("fnv1a32:..."), and its text hash.
String document_hash(const Variant &value) {
	CoreCall call;
	return core_text(map_generation::document_hash(call.state(), call.in(value)));
}

String text_hash(const String &text) {
	return core_text(map_generation::text_hash(utf8(text)));
}

// The core's read_package_dictionary: {ok, package} or the failure result.
Dictionary read_package_dictionary(const String &operation, const String &path) {
	CoreCall call;
	st::Value package;
	st::Value failure;
	if (!mp::read_package_dictionary(call.state(), call.files(), utf8(operation).c_str(), utf8(path), package, failure)) {
		return call.out_dict(failure);
	}
	Dictionary result;
	result["ok"] = true;
	result["package"] = call.out(package);
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

// ---------------------------------------------------------------- package browser cache

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
	return String(BROWSER_MANIFEST_CACHE_DIR) + "/" + text_hash(source_path) + ".json";
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

// Size and modification time of a package file, read before its content is
// hashed, and the clock time taken just before that read. Taking the time
// first means any edit that lands while the file is being hashed gets a later
// modification time than the one recorded here.
struct BrowserManifestSourceStamp {
	int64_t size = -1;
	int64_t modified_time = -1;
	int64_t checked_at = -1;
};

BrowserManifestSourceStamp browser_manifest_source_stamp(const String &source_path) {
	BrowserManifestSourceStamp stamp;
	stamp.checked_at = int64_t(std::floor(Time::get_singleton()->get_unix_time_from_system()));
	if (!FileAccess::file_exists(source_path)) {
		return stamp;
	}
	stamp.size = FileAccess::get_size(source_path);
	// Files inside an exported pack report 0, which never matches below.
	const int64_t modified_time = int64_t(FileAccess::get_modified_time(source_path));
	stamp.modified_time = modified_time > 0 ? modified_time : -1;
	return stamp;
}

bool browser_manifest_source_stamp_is_complete(const BrowserManifestSourceStamp &stamp) {
	return stamp.size >= 0 && stamp.modified_time > 0 && stamp.checked_at > 0;
}

bool browser_manifest_source_stamp_is_settled(const BrowserManifestSourceStamp &stamp) {
	return browser_manifest_source_stamp_is_complete(stamp) &&
			stamp.checked_at - stamp.modified_time >= BROWSER_MANIFEST_CACHE_SETTLED_SECONDS;
}

// A whole, non-negative number stored in the cache entry, or -1 when the field
// is missing or anything else. JSON reads numbers back as floats.
int64_t browser_manifest_cache_whole_number(const Dictionary &cache, const char *key) {
	const Variant value = cache.get(key, Variant());
	if (value.get_type() == Variant::INT) {
		const int64_t number = int64_t(value);
		return number >= 0 ? number : -1;
	}
	if (value.get_type() != Variant::FLOAT) {
		return -1;
	}
	const double number = double(value);
	if (!(number >= 0.0) || number > 9007199254740992.0 || number != std::floor(number)) {
		return -1;
	}
	return int64_t(number);
}

// The cache entry for source_path when it is well formed, records a source
// hash and its payload still matches its own integrity hash; empty otherwise.
// Whether that hash describes the file on disk is decided by the callers.
Dictionary read_browser_manifest_cache_entry(const String &source_path) {
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
			String(cache.get("source_sha256", "")).is_empty()) {
		return Dictionary();
	}
	Variant payload_value = cache.get("inspection_payload", Variant());
	if (payload_value.get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary payload = payload_value;
	if (!browser_manifest_cache_payload_is_valid(payload)) {
		return Dictionary();
	}
	if (String(cache.get("inspection_payload_hash", "")) != document_hash(payload)) {
		return Dictionary();
	}
	return cache;
}

// The entry's recorded hash when the package still has the size and
// modification time the entry recorded, and the entry checked it at least
// BROWSER_MANIFEST_CACHE_SETTLED_SECONDS after it was last modified. Empty
// otherwise, and then the caller hashes the package in full.
String browser_manifest_cache_stamped_sha256(const Dictionary &cache, const BrowserManifestSourceStamp &source_stamp) {
	if (cache.is_empty() || !browser_manifest_source_stamp_is_complete(source_stamp)) {
		return String();
	}
	BrowserManifestSourceStamp cached_stamp;
	cached_stamp.size = browser_manifest_cache_whole_number(cache, "source_size");
	cached_stamp.modified_time = browser_manifest_cache_whole_number(cache, "source_modified_time");
	cached_stamp.checked_at = browser_manifest_cache_whole_number(cache, "source_checked_at");
	if (cached_stamp.size != source_stamp.size ||
			cached_stamp.modified_time != source_stamp.modified_time ||
			!browser_manifest_source_stamp_is_settled(cached_stamp)) {
		return String();
	}
	return String(cache.get("source_sha256", ""));
}

// A detached copy of the entry's payload when the entry was recorded for
// source_sha256; empty otherwise.
Dictionary read_browser_manifest_cache_payload(const Dictionary &cache, const String &source_sha256) {
	if (cache.is_empty() || source_sha256.is_empty() ||
			String(cache.get("source_sha256", "")) != source_sha256) {
		return Dictionary();
	}
	Dictionary payload = Dictionary(cache.get("inspection_payload", Dictionary())).duplicate(true);
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

bool write_browser_manifest_cache(const String &source_path, const String &source_sha256, const BrowserManifestSourceStamp &source_stamp, const Dictionary &payload) {
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
	if (!aurelion::map_bridge::ensure_parent_dir(cache_path)) {
		return false;
	}
	Dictionary cache;
	cache["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
	cache["schema_version"] = 1;
	cache["source_path"] = source_path;
	cache["source_sha256"] = source_sha256;
	if (browser_manifest_source_stamp_is_complete(source_stamp)) {
		cache["source_size"] = source_stamp.size;
		cache["source_modified_time"] = source_stamp.modified_time;
		cache["source_checked_at"] = source_stamp.checked_at;
	}
	cache["inspection_payload"] = stable_payload.duplicate(true);
	cache["inspection_payload_hash"] = document_hash(stable_payload);
	return aurelion::map_bridge::replace_file(cache_path, JSON::stringify(cache, "\t", true, false).to_utf8_buffer()) == nullptr;
}

Dictionary browser_manifest_cache_profile(const char *status, const char *source_check, const String &source_sha256, const String &cache_path) {
	Dictionary profile;
	profile["schema_id"] = BROWSER_MANIFEST_CACHE_SCHEMA_ID;
	profile["status"] = status;
	profile["source_check"] = source_check;
	profile["source_sha256"] = source_sha256;
	profile["cache_path"] = cache_path;
	return profile;
}

} // namespace

namespace aurelion::map_bridge {

Dictionary write_package_browser_manifest_cache(const String &path, const Dictionary &package) {
	const BrowserManifestSourceStamp source_stamp = browser_manifest_source_stamp(path);
	const String source_sha256 = FileAccess::get_sha256(path);
	const bool cache_written = write_browser_manifest_cache(path, source_sha256, source_stamp, package_inspection_payload(package));
	return browser_manifest_cache_profile(cache_written ? "prepopulated" : "not_cacheable", "sha256", source_sha256, browser_manifest_cache_path(path));
}

} // namespace aurelion::map_bridge

void MapPackageService::release_runtime_caches() {
	std::lock_guard<std::mutex> lock(generator_mutex());
	last_generated_core().reset();
}

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
	return core_call("load_map_package", [&](CoreCall &call) {
		mp::MapDocument *document = nullptr;
		const st::Value document_value = call.new_map_document(document);
		return mp::load_map_package(call.state(), call.files(), utf8(path), *document, document_value);
	});
}

Dictionary MapPackageService::load_scenario_package(String path, Dictionary options) const {
	(void)options;
	return core_call("load_scenario_package", [&](CoreCall &call) {
		mp::ScenarioDocument *document = nullptr;
		const st::Value document_value = call.new_scenario_document(document);
		return mp::load_scenario_package(call.state(), call.files(), utf8(path), *document, document_value);
	});
}

Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return core_call("validate_map_document", [&](CoreCall &call) {
		return map_generation::validate_map_document(call.state(), call.map_document(call.in(map_document)));
	});
}

Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return core_call("validate_scenario_document", [&](CoreCall &call) {
		const mp::ScenarioDocument *scenario = call.scenario_document(call.in(scenario_document));
		const mp::MapDocument *map = call.map_document(call.in(map_document));
		return map_generation::validate_scenario_document(call.state(), scenario, map);
	});
}

Dictionary MapPackageService::save_map_package(Ref<MapDocument> map_document, String path, Dictionary options) const {
	return core_call("save_map_package", [&](CoreCall &call) {
		return map_generation::save_map_package(call.state(), call.files(), call, call.in(map_document), utf8(path), call.in(options));
	});
}

Dictionary MapPackageService::save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options) const {
	return core_call("save_scenario_package", [&](CoreCall &call) {
		return map_generation::save_scenario_package(call.state(), call.files(), call, call.in(scenario_document), utf8(path), call.in(options));
	});
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
	const String map_hash = document_hash(map_identity);

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
	const String scenario_hash = document_hash(scenario_identity);
	Dictionary scenario_state = scenario_identity.duplicate(true);
	scenario_state["scenario_id"] = scenario_id;
	scenario_state["scenario_hash"] = scenario_hash;
	scenario_state["map_ref"] = map_ref;
	Ref<ScenarioDocument> scenario_document;
	scenario_document.instantiate();
	scenario_document->configure(scenario_state);

	Dictionary map_validation = validate_map_document(map_document);
	Dictionary scenario_validation = validate_scenario_document(scenario_document, map_document);
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
	return core_call("convert_generated_payload", [&](CoreCall &call) {
		return map_generation::convert_generated_payload(call.state(), call.in(generated_map), call.in(options));
	});
}

Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const {
	(void)options;
	return core_call("compute_document_hash", [&](CoreCall &call) {
		return map_generation::compute_document_hash(call.state(), call.in(document));
	});
}

Dictionary MapPackageService::inspect_package(String path, Dictionary options) const {
	const bool bypass_cache = String(options.get("browser_manifest_cache_mode", "default")) == "bypass_read";
	const bool include_cache_profile = bool(options.get("include_browser_manifest_cache_profile", false));
	const String cache_path = browser_manifest_cache_path(path);
	const auto cache_hit = [&](const Dictionary &cached_payload, const String &cached_sha256, const char *source_check) {
		Dictionary cached_result = package_success("inspect_package", path, cached_payload);
		if (include_cache_profile) {
			cached_result["browser_manifest_cache_profile"] = browser_manifest_cache_profile("hit", source_check, cached_sha256, cache_path);
		}
		return cached_result;
	};
	// Read before hashing, so an edit made while hashing changes the stamp the
	// next listing compares against.
	const BrowserManifestSourceStamp source_stamp = browser_manifest_source_stamp(path);
	Dictionary cache;
	if (!bypass_cache) {
		cache = read_browser_manifest_cache_entry(path);
		// Unchanged size and modification time, recorded settled, stand in for
		// the content hash. Anything else hashes the package in full below.
		const String stamped_sha256 = browser_manifest_cache_stamped_sha256(cache, source_stamp);
		Dictionary stamped_payload = read_browser_manifest_cache_payload(cache, stamped_sha256);
		if (!stamped_payload.is_empty()) {
			return cache_hit(stamped_payload, stamped_sha256, "size_and_modified_time");
		}
	}
	const String source_sha256 = FileAccess::file_exists(path) ? FileAccess::get_sha256(path) : String();
	if (!bypass_cache) {
		Dictionary cached_payload = read_browser_manifest_cache_payload(cache, source_sha256);
		if (!cached_payload.is_empty()) {
			// The content still matches. Record the current stamp once it is
			// settled, so later listings can skip the hash.
			if (browser_manifest_source_stamp_is_settled(source_stamp)) {
				write_browser_manifest_cache(path, source_sha256, source_stamp, cached_payload);
			}
			return cache_hit(cached_payload, source_sha256, "sha256");
		}
	}
	Dictionary read_result = read_package_dictionary("inspect_package", path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	Dictionary payload = package_inspection_payload(package);
	const bool cache_written = write_browser_manifest_cache(path, source_sha256, source_stamp, payload);
	Dictionary result = package_success("inspect_package", path, payload);
	if (include_cache_profile) {
		result["browser_manifest_cache_profile"] = browser_manifest_cache_profile(
				cache_written ? (bypass_cache ? "bypass_written" : "miss_written") : "not_cacheable", "sha256", source_sha256, cache_path);
	}
	return result;
}

Dictionary MapPackageService::inspect_random_map_generator_data_model(Dictionary options) const {
	return rmg_data_model::inspect_generator_data_model(options);
}

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	return core_call("normalize_random_map_config", [&](CoreCall &call) {
		return map_generation::normalize_random_map_config(call.state(), call.in(config));
	});
}

Dictionary MapPackageService::random_map_config_identity(Dictionary config) const {
	return core_call("random_map_config_identity", [&](CoreCall &call) {
		return map_generation::random_map_config_identity(call.state(), call.in(config));
	});
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	return core_call("generate_random_map", [&](CoreCall &call) {
		map_generation::GeneratorCache cache;
		{
			std::lock_guard<std::mutex> lock(generator_mutex());
			cache.last = last_generated_core();
		}
		const std::shared_ptr<const map_generation::GeneratorCache::Core> before = cache.last;
		const st::Value result = map_generation::generate_random_map(call.state(), call.files(), call, cache, call.in(config), call.in(options));
		if (cache.last != before) {
			std::lock_guard<std::mutex> lock(generator_mutex());
			last_generated_core() = cache.last;
		}
		return result;
	});
}
