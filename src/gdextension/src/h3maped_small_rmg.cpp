#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *ARCHIVED_REPORT_TREADMILL_PATH = "src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp";
constexpr const char *ARCHIVED_OVERGROWN_ACTIVE_PATH = "src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp";
constexpr const char *ARCHIVED_PHASE_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp";
constexpr const char *ARCHIVED_ACTIVE_BOUNDARY_PATH = "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp";
constexpr const char *ARCHIVED_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp";
constexpr const char *OLDER_LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

struct TemplateEvidence {
	const char *id = "";
	int32_t catalog_index = -1;
	int32_t min_size_score = 0;
	int32_t max_size_score = 0;
	int32_t min_humans = 0;
	int32_t max_humans = 0;
	int32_t min_total_players = 0;
	int32_t max_total_players = 0;
	int32_t zone_count = 0;
	int32_t connection_count = 0;
	const char *adapted_template_id = "";
	uint8_t human_capable_source_owner_mask = 0;
	uint8_t player_capable_source_owner_mask = 0;
};

constexpr TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, "", 0xff, 0xff },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, "", 0x0f, 0x0f },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, "", 0x3f, 0x7f },
};

int32_t nested_or_flat_i32(const Dictionary &dict, const char *nested_key, const char *flat_key, int32_t fallback) {
	Dictionary nested = dict.get(nested_key, Dictionary());
	if (nested.has(flat_key)) {
		return int32_t(nested.get(flat_key, fallback));
	}
	return int32_t(dict.get(flat_key, fallback));
}

String normalized_seed_text(const Dictionary &normalized_config) {
	return String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
}

int32_t player_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("player_count", normalized_config.get("player_count", 2)));
}

int32_t human_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("human_count", normalized_config.get("human_count", 1)));
}

String water_mode(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("water_mode", normalized_config.get("water_mode", "land")));
}

String size_class_id(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("size_class_id", normalized_config.get("size_class_id", "homm3_small")));
}

int32_t width(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "width", 36);
}

int32_t height(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "height", 36);
}

int32_t level_count(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "level_count", 1);
}

int32_t water_mode_code(const Dictionary &normalized_config) {
	const String mode = water_mode(normalized_config);
	if (mode == "normal_water") {
		return 1;
	}
	if (mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized_config) {
	int32_t score = int32_t((int64_t(std::max(1, width(normalized_config))) * int64_t(std::max(1, height(normalized_config))) * int64_t(std::max(1, level_count(normalized_config)))) / 0x510);
	if (water_mode_code(normalized_config) == 2) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool parse_numeric_seed(const String &seed_text, uint32_t &seed_value) {
	const String stripped = seed_text.strip_edges();
	if (stripped.is_empty()) {
		return false;
	}
	const CharString utf8 = stripped.utf8();
	char *end = nullptr;
	errno = 0;
	const long long parsed = std::strtoll(utf8.get_data(), &end, 10);
	if (errno != 0 || end == utf8.get_data() || *end != '\0') {
		return false;
	}
	seed_value = uint32_t(parsed);
	return true;
}

Dictionary template_record(const TemplateEvidence &candidate) {
	Dictionary item;
	item["id"] = candidate.id;
	item["source_catalog_index"] = candidate.catalog_index;
	item["min_size_score"] = candidate.min_size_score;
	item["max_size_score"] = candidate.max_size_score;
	item["min_humans"] = candidate.min_humans;
	item["max_humans"] = candidate.max_humans;
	item["min_total_players"] = candidate.min_total_players;
	item["max_total_players"] = candidate.max_total_players;
	item["zone_count"] = candidate.zone_count;
	item["connection_count"] = candidate.connection_count;
	item["adapted_template_id"] = candidate.adapted_template_id;
	item["human_capable_source_owner_mask"] = int32_t(candidate.human_capable_source_owner_mask);
	item["player_capable_source_owner_mask"] = int32_t(candidate.player_capable_source_owner_mask);
	return item;
}

Array accepted_templates(const Dictionary &normalized_config) {
	Array accepted;
	const int32_t score = size_score(normalized_config);
	const int32_t humans = human_count(normalized_config);
	const int32_t players = player_count(normalized_config);
	if (!supports_scope(normalized_config)) {
		return accepted;
	}
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (humans < candidate.min_humans || humans > candidate.max_humans || players < candidate.min_total_players || players > candidate.max_total_players || players < humans) {
			continue;
		}
		accepted.append(template_record(candidate));
	}
	return accepted;
}

Dictionary binary_verification() {
	Dictionary report;
	report["path"] = BINARY_PATH;
	report["expected_sha256"] = BINARY_SHA256;
	report["expected_size_bytes"] = BINARY_SIZE_BYTES;
	report["format"] = "PE32 GUI Intel 80386 Windows executable";
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["ok"] = false;
		report["status"] = "missing";
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["ok"] = false;
		report["status"] = "unreadable";
		return report;
	}
	const int64_t actual_size = file->get_length();
	const int32_t byte_0 = file->get_8();
	const int32_t byte_1 = file->get_8();
	const String actual_sha256 = FileAccess::get_sha256(BINARY_PATH);
	const bool mz = byte_0 == 'M' && byte_1 == 'Z';
	const bool sha_ok = actual_sha256 == String(BINARY_SHA256);
	report["actual_size_bytes"] = actual_size;
	report["actual_sha256"] = actual_sha256;
	report["mz_header_present"] = mz;
	report["sha256_matches"] = sha_ok;
	report["ok"] = actual_size == BINARY_SIZE_BYTES && mz && sha_ok;
	report["status"] = bool(report["ok"]) ? String("verified_reset_anchor") : String("mismatch");
	return report;
}

Dictionary phase_record(const String &id, const String &source, const String &status) {
	Dictionary phase;
	phase["id"] = id;
	phase["h3maped_source"] = source;
	phase["status"] = status;
	phase["materializes_public_output"] = false;
	return phase;
}

Array fresh_phase_backlog() {
	Array backlog;
	backlog.append(phase_record("template_selection", "0x49f0cd, 0x4ac597, 0x4e7276", "active_boundary"));
	backlog.append(phase_record("player_slot_assignment", "0x4ac62a..0x4ac6ec", "pending_runtime_port"));
	backlog.append(phase_record("runtime_zone_records", "0x4a218c, 0x49b452", "pending_runtime_port"));
	backlog.append(phase_record("coordinate_replay_and_zone_footprints", "0x4a1f3b, 0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed, 0x4a3a03", "pending_runtime_port"));
	backlog.append(phase_record("terrain_and_terrainplacement", "0x4a3f27, 0x4bb74b, 0x4bc5f0, 0x49b2b6", "pending_runtime_port"));
	backlog.append(phase_record("town_object_placement", "0x4a8d2c, 0x4a8db2, 0x4a93a2", "pending_runtime_port"));
	backlog.append(phase_record("mines_rewards_and_object_vector", "0x4a9d6a, 0x4a9911, 0x4aa354, 0x4a9f1c, 0x4aa9b7", "pending_runtime_port"));
	backlog.append(phase_record("roads_and_rivers", "0x4ab52a, 0x4aae7b, 0x4ab37f, 0x4b4243, 0x458a2f, 0x458893", "pending_runtime_port"));
	backlog.append(phase_record("connections_blockers_and_guards", "0x4a79a3, 0x4a61bc, 0x4a696b, 0x4a6cf2, 0x4a7605", "pending_runtime_port"));
	backlog.append(phase_record("final_h3m_writeout", "0x49b2b6 plus final object/tile serialization", "pending_runtime_port"));
	return backlog;
}

Array current_gap_summary() {
	Array gaps;
	gaps.append("active code now contains only h3maped binary verification, small scope gate, and template RNG selection");
	gaps.append("player slots, runtime zones, physical zone fills, terrain, towns, roads, blockers, guards, mines, rewards, and writeout are not implemented in the fresh active module");
	gaps.append("all earlier private phase ledgers were archived because they were report growth, not usable map generation");
	gaps.append("small maps remain blocked from runtime package output until executable-derived phases are ported as actual generation state");
	return gaps;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return width(normalized_config) == 36
			&& height(normalized_config) == 36
			&& level_count(normalized_config) == 1
			&& water_mode(normalized_config) == "land"
			&& size_class_id(normalized_config) == "homm3_small";
}

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary result;
	result["schema_id"] = "aurelion_native_rmg_small_h3maped_selection_identity_v2";
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["rng_seed_setter_address"] = "0x4e7269";
	result["rng_function_address"] = "0x4e7276";
	result["rng_algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
	result["runtime_generation_allowed"] = false;
	const Array accepted = accepted_templates(normalized_config);
	result["accepted_template_count"] = accepted.size();
	if (!supports_scope(normalized_config)) {
		result["ok"] = false;
		result["status"] = "unsupported_scope";
		return result;
	}
	if (accepted.is_empty()) {
		result["ok"] = false;
		result["status"] = "no_accepted_templates";
		return result;
	}
	const String seed_text = normalized_seed_text(normalized_config);
	uint32_t seed_value = 0;
	if (!parse_numeric_seed(seed_text, seed_value)) {
		result["ok"] = false;
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["seed_text"] = seed_text;
		return result;
	}
	const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
	const int32_t first_value = int32_t((next_state >> 16U) & 0x7fffu);
	const int32_t selected_index = first_value % int32_t(accepted.size());
	Dictionary selected = accepted[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_uint32"] = int64_t(seed_value);
	result["rng_first_value"] = first_value;
	result["rng_state_after_selection_uint32"] = int64_t(next_state);
	result["selected_vector_index"] = selected_index;
	result["source_template_id"] = selected.get("id", "");
	result["source_catalog_index"] = selected.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected.get("adapted_template_id", "");
	result["selected_template"] = selected;
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	const Array accepted = accepted_templates(normalized_config);
	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_fresh_start_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["active_module_role"] = "thin_boundary_and_generation_gate";
	report["archived_report_treadmill_path"] = ARCHIVED_REPORT_TREADMILL_PATH;
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
	report["archived_phase_ledger_path"] = ARCHIVED_PHASE_LEDGER_PATH;
	report["archived_active_boundary_path"] = ARCHIVED_ACTIVE_BOUNDARY_PATH;
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = size_score(normalized_config);
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["accepted_template_count"] = accepted.size();
	report["accepted_templates"] = accepted;
	report["selection_identity"] = selection_identity(normalized_config);
	report["fresh_phase_backlog"] = fresh_phase_backlog();
	report["current_gap_summary"] = current_gap_summary();
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_fresh_start_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The old native RMG and overgrown h3maped report path are archived. The active small-map path only verifies h3maped.exe and performs h3maped RNG template selection; runtime package output is blocked until real generator phases are ported.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

Dictionary archived_legacy_disabled_result(const Dictionary &normalized_config, const Dictionary &extension_profile, const Dictionary &runtime_policy_classification) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "archived_legacy_native_rmg_disabled";
	result["generation_status"] = "archived_legacy_native_rmg_disabled";
	result["full_generation_status"] = "disabled_by_h3maped_small_reset";
	result["error_code"] = "archived_legacy_native_rmg_disabled";
	result["message"] = "The previous native RMG path is archived and cannot be used as a fallback during the small h3maped restart.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
