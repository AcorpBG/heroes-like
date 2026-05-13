#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <cmath>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *PROJECT_TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
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

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
};

struct CoordCandidate {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct RuntimeZoneSeed {
	int32_t runtime_index = -1;
	int32_t source_zone_id = -1;
	int32_t source_bucket = -1;
	int32_t source_owner_index = -1;
	int32_t actual_owner_color = -1;
	int32_t source_base_size = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t scaled_size = 0;
};

struct RuntimeLinkSeed {
	int32_t runtime_a = -1;
	int32_t runtime_b = -1;
};

const TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, "", 0xff, 0xff },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, "", 0x03, 0x03 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, "", 0x03, 0x03 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, "", 0x0f, 0x0f },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, "", 0x03, 0x03 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, "", 0x03, 0x03 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, "", 0x03, 0x03 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, "", 0x03, 0x03 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, "", 0x3f, 0x7f },
};

int32_t water_mode_code(const Dictionary &normalized_config) {
	const String water_mode = String(normalized_config.get("water_mode", "land"));
	if (water_mode == "normal_water") {
		return 1;
	}
	if (water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized_config) {
	const int32_t width = std::max(1, int32_t(normalized_config.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized_config.get("height", 36)));
	const int32_t levels = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	int32_t score = int32_t((int64_t(width) * int64_t(height) * int64_t(levels)) / 0x510);
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

Dictionary template_to_dictionary(const TemplateEvidence &template_evidence) {
	Dictionary record;
	record["id"] = template_evidence.id;
	record["source_catalog_index"] = template_evidence.catalog_index;
	record["min_size_score"] = template_evidence.min_size_score;
	record["max_size_score"] = template_evidence.max_size_score;
	record["min_humans"] = template_evidence.min_humans;
	record["max_humans"] = template_evidence.max_humans;
	record["min_total_players"] = template_evidence.min_total_players;
	record["max_total_players"] = template_evidence.max_total_players;
	record["zone_count"] = template_evidence.zone_count;
	record["connection_count"] = template_evidence.connection_count;
	record["adapted_template_id"] = template_evidence.adapted_template_id;
	record["human_capable_source_owner_mask"] = template_evidence.human_capable_source_owner_mask;
	record["player_capable_source_owner_mask"] = template_evidence.player_capable_source_owner_mask;
	record["source"] = "recovered h3maped template catalog anchored to /root/Downloads/h3maped.exe";
	return record;
}

const TemplateEvidence *template_for_catalog_index(int32_t catalog_index) {
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (candidate.catalog_index == catalog_index) {
			return &candidate;
		}
	}
	return nullptr;
}

Array source_owner_indices_from_mask(uint8_t mask) {
	Array indices;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & (1U << index)) != 0) {
			indices.append(index);
		}
	}
	return indices;
}

Dictionary load_json_dictionary(const String &path) {
	Dictionary result;
	result["ok"] = false;
	result["path"] = path;
	if (!FileAccess::file_exists(path)) {
		result["status"] = "missing_json_file";
		return result;
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		result["status"] = "unreadable_json_file";
		return result;
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		result["status"] = "invalid_json_dictionary";
		return result;
	}
	result["ok"] = true;
	result["status"] = "loaded";
	result["data"] = Dictionary(parser->get_data());
	return result;
}

Dictionary find_project_template_record(const String &adapted_template_id, Dictionary &load_status) {
	load_status = load_json_dictionary(PROJECT_TEMPLATE_CATALOG_PATH);
	if (!bool(load_status.get("ok", false))) {
		return Dictionary();
	}
	Dictionary catalog = load_status.get("data", Dictionary());
	if (Variant(catalog.get("templates", Variant())).get_type() != Variant::ARRAY) {
		load_status["ok"] = false;
		load_status["status"] = "missing_templates_array";
		return Dictionary();
	}
	Array templates = catalog.get("templates", Array());
	for (int64_t index = 0; index < templates.size(); ++index) {
		if (Variant(templates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = templates[index];
		if (String(candidate.get("id", "")) == adapted_template_id) {
			return candidate;
		}
	}
	load_status["ok"] = false;
	load_status["status"] = "adapted_template_not_found";
	load_status["adapted_template_id"] = adapted_template_id;
	return Dictionary();
}

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

int32_t ftol_truncate(double value) {
	return int32_t(std::trunc(value));
}

Array coordinate_candidate_report(const std::vector<CoordCandidate> &candidates, int32_t limit = 8) {
	Array result;
	const int32_t capped = std::min<int32_t>(int32_t(candidates.size()), limit);
	for (int32_t index = 0; index < capped; ++index) {
		Dictionary item;
		item["x"] = candidates[size_t(index)].x;
		item["y"] = candidates[size_t(index)].y;
		item["level"] = candidates[size_t(index)].level;
		result.append(item);
	}
	return result;
}

bool candidate_valid_4a1701(const RuntimeZoneSeed &current, const CoordCandidate &candidate, const std::vector<RuntimeZoneSeed> &zones, const std::vector<int32_t> &visible_runtime_indices) {
	if ((current.source_bucket == 0 || current.source_bucket == 1) && candidate.level == 1
			&& current.actual_owner_color != 3 && current.actual_owner_color != 4 && current.actual_owner_color != 5) {
		return false;
	}
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size())) {
			continue;
		}
		const RuntimeZoneSeed &other = zones[size_t(other_index)];
		if (other.runtime_index == current.runtime_index || other.level != candidate.level) {
			continue;
		}
		const int32_t distance = h3maped_distance_truncate_local(candidate.x, candidate.y, other.x, other.y);
		const int32_t minimum_tenths = (other.source_base_size + current.source_base_size) * 8;
		if (distance * 10 < minimum_tenths) {
			return false;
		}
	}
	return true;
}

bool zones_connectable_49b6e2(const RuntimeZoneSeed &first, const RuntimeZoneSeed &second) {
	const int32_t distance = h3maped_distance_truncate_local(first.x, first.y, second.x, second.y);
	const int32_t size_sum = first.source_base_size + second.source_base_size;
	if (first.level != second.level) {
		if (size_sum < distance) {
			return false;
		}
		return (size_sum - distance) > (std::min(first.source_base_size, second.source_base_size) / 2);
	}
	return size_sum * 11 >= distance * 10;
}

int32_t link_acceptance_count_4a1967(const RuntimeZoneSeed &current, const std::vector<RuntimeZoneSeed> &zones, const std::vector<RuntimeLinkSeed> &links) {
	int32_t accepted = 0;
	for (const RuntimeLinkSeed &link : links) {
		int32_t other_index = -1;
		if (link.runtime_a == current.runtime_index) {
			other_index = link.runtime_b;
		} else if (link.runtime_b == current.runtime_index) {
			other_index = link.runtime_a;
		}
		if (other_index < 0 || other_index >= int32_t(zones.size())) {
			continue;
		}
		if (zones_connectable_49b6e2(zones[size_t(other_index)], current)) {
			accepted += 1;
		}
	}
	return accepted;
}

void append_angle_candidates_4a17f5(const RuntimeZoneSeed &base, const RuntimeZoneSeed &current, const std::vector<RuntimeZoneSeed> &zones, const std::vector<int32_t> &visible_runtime_indices, std::vector<CoordCandidate> &candidates) {
	static constexpr double X_TABLE[32] = {
		1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
		0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
		0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
		-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
		-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
		-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
		0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
		0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
	};
	static constexpr double Y_TABLE[32] = {
		0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
		0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
		1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
		0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
		0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
		-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
		-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
		-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
	};
	const int32_t combined_size = base.source_base_size + current.source_base_size;
	for (int32_t direction = 0; direction < 32; ++direction) {
		CoordCandidate candidate;
		candidate.x = ftol_truncate(double(combined_size) * X_TABLE[direction] + double(base.x));
		candidate.y = ftol_truncate(double(combined_size) * Y_TABLE[direction] + double(base.y));
		candidate.level = base.level;
		if (candidate_valid_4a1701(current, candidate, zones, visible_runtime_indices)) {
			candidates.push_back(candidate);
		}
	}
}

void prune_candidates_4a1ad8_single_level(const RuntimeZoneSeed &current_template, const std::vector<RuntimeZoneSeed> &zones, const std::vector<int32_t> &visible_runtime_indices, const std::vector<RuntimeLinkSeed> &links, std::vector<CoordCandidate> &candidates) {
	if (candidates.empty()) {
		return;
	}
	int32_t best_link_count = 0;
	for (const CoordCandidate &candidate : candidates) {
		RuntimeZoneSeed candidate_zone = current_template;
		candidate_zone.x = candidate.x;
		candidate_zone.y = candidate.y;
		candidate_zone.level = candidate.level;
		best_link_count = std::max(best_link_count, link_acceptance_count_4a1967(candidate_zone, zones, links));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		RuntimeZoneSeed candidate_zone = current_template;
		candidate_zone.x = candidate.x;
		candidate_zone.y = candidate.y;
		candidate_zone.level = candidate.level;
		return link_acceptance_count_4a1967(candidate_zone, zones, links) < best_link_count;
	}), candidates.end());
	if (candidates.empty()) {
		return;
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index == current_template.runtime_index) {
			continue;
		}
		const RuntimeZoneSeed &other = zones[size_t(other_index)];
		min_y = std::min(other.y - other.source_base_size, min_y);
		min_x = std::min(other.x - other.source_base_size, min_x);
		max_y = std::max(other.y + other.source_base_size + 1, max_y);
		max_x = std::max(other.x + other.source_base_size + 1, max_x);
	}

	int32_t best_metric = 0x7d00;
	for (const CoordCandidate &candidate : candidates) {
		const int32_t candidate_min_y = std::min(candidate.y - current_template.source_base_size, min_y);
		const int32_t candidate_min_x = std::min(candidate.x - current_template.source_base_size, min_x);
		const int32_t candidate_max_y = std::max(candidate.y + current_template.source_base_size + 1, max_y);
		const int32_t candidate_max_x = std::max(candidate.x + current_template.source_base_size + 1, max_x);
		best_metric = std::min(best_metric, std::min(candidate_max_y - candidate_min_y, candidate_max_x - candidate_min_x));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		const int32_t candidate_min_y = std::min(candidate.y - current_template.source_base_size, min_y);
		const int32_t candidate_min_x = std::min(candidate.x - current_template.source_base_size, min_x);
		const int32_t candidate_max_y = std::max(candidate.y + current_template.source_base_size + 1, max_y);
		const int32_t candidate_max_x = std::max(candidate.x + current_template.source_base_size + 1, max_x);
		const int32_t metric = std::min(candidate_max_y - candidate_min_y, candidate_max_x - candidate_min_x);
		return best_metric < metric;
	}), candidates.end());
}

Array accepted_templates(const Dictionary &normalized_config) {
	Array records;
	if (!supports_scope(normalized_config)) {
		return records;
	}
	const int32_t score = size_score(normalized_config);
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (human_count < candidate.min_humans || human_count > candidate.max_humans) {
			continue;
		}
		if (player_count < candidate.min_total_players || player_count > candidate.max_total_players) {
			continue;
		}
		records.append(template_to_dictionary(candidate));
	}
	return records;
}

Dictionary player_slot_assignment_phase(const TemplateEvidence &selected_template, const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(0, int32_t(constraints.get("human_count", 1)));
	const int32_t player_count = std::max(human_count, int32_t(constraints.get("player_count", 2)));

	Dictionary phase;
	phase["phase_id"] = "player_slot_assignment";
	phase["status"] = "active_runtime_state_ready";
	phase["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	phase["selected_color_bitmap_offset"] = "generator+0xed8";
	phase["assignment_slots_offset"] = "generator+0xee0";
	phase["mapped_slots_offset"] = "generator+0xee4";
	phase["human_capable_source_owner_mask"] = selected_template.human_capable_source_owner_mask;
	phase["player_capable_source_owner_mask"] = selected_template.player_capable_source_owner_mask;
	phase["human_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.human_capable_source_owner_mask);
	phase["player_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.player_capable_source_owner_mask);

	Array selected_color_order;
	Array assignment_slots;
	Array mapped_slots;
	for (int32_t index = 0; index < 8; ++index) {
		selected_color_order.append(index);
		assignment_slots.append(-1);
		mapped_slots.append(-1);
	}

	Array assignments;
	Array human_indices = phase["human_capable_source_owner_indices"];
	Array player_indices = phase["player_capable_source_owner_indices"];
	int32_t assigned_players = 0;
	for (int32_t human = 0; human < human_count && human < human_indices.size(); ++human) {
		const int32_t source_owner = int32_t(human_indices[human]);
		assignment_slots[source_owner] = assigned_players;
		mapped_slots[source_owner] = assigned_players;
		Dictionary record;
		record["player_slot"] = assigned_players + 1;
		record["player_type"] = "human";
		record["source_owner_index"] = source_owner;
		record["actual_player_color"] = assigned_players;
		assignments.append(record);
		assigned_players += 1;
	}
	for (int32_t source_index = 0; assigned_players < player_count && source_index < player_indices.size(); ++source_index) {
		const int32_t source_owner = int32_t(player_indices[source_index]);
		if (int32_t(mapped_slots[source_owner]) != -1) {
			continue;
		}
		assignment_slots[source_owner] = assigned_players;
		mapped_slots[source_owner] = assigned_players;
		Dictionary record;
		record["player_slot"] = assigned_players + 1;
		record["player_type"] = "computer";
		record["source_owner_index"] = source_owner;
		record["actual_player_color"] = assigned_players;
		assignments.append(record);
		assigned_players += 1;
	}

	phase["selected_color_order_ed8"] = selected_color_order;
	phase["raw_ee0_slots"] = assignment_slots;
	phase["mapped_ee4_slots"] = mapped_slots;
	phase["assignment_records"] = assignments;
	phase["assigned_player_count"] = assigned_players;
	phase["requested_human_count"] = human_count;
	phase["requested_player_count"] = player_count;
	phase["materializes_runtime_players"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "runtime_zone_records_0x4a218c";
	return phase;
}

Dictionary runtime_zone_records_phase(const Dictionary &selection, const Dictionary &player_phase) {
	Dictionary phase;
	phase["phase_id"] = "runtime_zone_records";
	phase["status"] = "blocked_missing_project_template_catalog";
	phase["h3maped_anchor"] = "0x4a218c";
	phase["initializer_anchor"] = "0x49b452";
	phase["runtime_zone_vector_begin_offset"] = "generator+0x10e0";
	phase["runtime_zone_vector_end_offset"] = "generator+0x10e4";
	phase["runtime_zone_vector_capacity_offset"] = "generator+0x10e8";
	phase["runtime_zone_record_size_bytes"] = 0x414;
	phase["materializes_runtime_zone_coordinates"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";

	Dictionary catalog_load;
	const String adapted_template_id = String(selection.get("adapted_template_id", ""));
	Dictionary template_record = find_project_template_record(adapted_template_id, catalog_load);
	phase["project_catalog_load"] = catalog_load;
	phase["project_template_id"] = adapted_template_id;
	if (template_record.is_empty() || Variant(template_record.get("zones", Variant())).get_type() != Variant::ARRAY) {
		return phase;
	}

	Array mapped_slots = player_phase.get("mapped_ee4_slots", Array());
	Array zones = template_record.get("zones", Array());
	Array runtime_records;
	Array actual_owner_colors;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = 0x7fffffff;
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = zones[index];
		Dictionary ownership = zone.get("ownership", Dictionary());
		Dictionary grammar_source = zone.get("grammar_source", Dictionary());
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Dictionary mine_requirements = zone.get("mine_requirements", Dictionary());
		Dictionary minimum_by_category = mine_requirements.get("minimum_by_category", Dictionary());
		const int32_t source_owner = int32_t(ownership.get("source_owner_index", -2));
		int32_t actual_owner = -1;
		if (source_owner >= 0 && source_owner < mapped_slots.size()) {
			actual_owner = int32_t(mapped_slots[source_owner]);
		}
		const String role = String(zone.get("role", zone.get("type", "")));
		if (role == "human_start") {
			if (actual_owner >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else if (role == "treasure") {
			treasure_zone_count += 1;
		}
		const int32_t min_castles = int32_t(player_towns.get("min_castles", 0));
		minimum_player_castles += min_castles;
		const int32_t base_size = int32_t(zone.get("base_size", 0));
		if (base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, base_size);
		}

		Dictionary record;
		record["runtime_index"] = runtime_records.size();
		record["source_zone_id"] = zone.get("source_zone_id", zone.get("id", int32_t(index + 1)));
		record["role"] = role;
		record["source_bucket"] = grammar_source.get("source_bucket", -1);
		record["source_owner_index"] = source_owner;
		record["actual_owner_color"] = actual_owner;
		record["source_base_size"] = base_size;
		record["min_player_castles"] = min_castles;
		record["terrain_match_to_town"] = bool(Dictionary(zone.get("terrain", Dictionary())).get("match_to_faction", false));
		record["terrain_policy"] = Array(Dictionary(zone.get("terrain", Dictionary())).get("allowed", Array())).is_empty() ? String("match_to_player_town") : String("all_land_h3");
		record["allowed_faction_ids_for_49b3c1"] = town_policy.get("allowed_faction_ids", Array());
		record["monster_strength"] = Dictionary(zone.get("monster_policy", Dictionary())).get("strength", "");
		record["minimum_ore_mines"] = minimum_by_category.get("ore", 0);
		record["minimum_wood_mines"] = minimum_by_category.get("timber", 0);
		record["minimum_rare_mines"] = int32_t(minimum_by_category.get("gold", 0)) + int32_t(minimum_by_category.get("quicksilver", 0)) + int32_t(minimum_by_category.get("ember_salt", 0)) + int32_t(minimum_by_category.get("lens_crystal", 0)) + int32_t(minimum_by_category.get("cut_gems", 0));
		runtime_records.append(record);
		actual_owner_colors.append(actual_owner);
	}
	if (minimum_source_base_size == 0x7fffffff) {
		minimum_source_base_size = 0;
	}

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "res://content/random_map_template_catalog.json imported from recovered h3maped template catalog";
	phase["runtime_zone_count"] = runtime_records.size();
	phase["runtime_zone_records"] = runtime_records;
	phase["actual_owner_colors_by_runtime_zone"] = actual_owner_colors;
	phase["assigned_start_zone_count"] = assigned_start_zone_count;
	phase["unassigned_start_zone_count"] = unassigned_start_zone_count;
	phase["treasure_zone_count"] = treasure_zone_count;
	phase["minimum_player_castles"] = minimum_player_castles;
	phase["minimum_source_base_size"] = minimum_source_base_size;
	return phase;
}

bool player_filter_allows(const Dictionary &filter, int32_t human_count, int32_t player_count) {
	return human_count >= int32_t(filter.get("min_human", 0))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& player_count >= int32_t(filter.get("min_total", 0))
			&& player_count <= int32_t(filter.get("max_total", 8));
}

Dictionary link_seed_phase(const Dictionary &selection, const Dictionary &normalized_config, const Dictionary &runtime_zone_phase) {
	Dictionary phase;
	phase["phase_id"] = "link_seed_setup";
	phase["status"] = "blocked_until_runtime_zone_records";
	phase["h3maped_anchor"] = "0x4a1f3b";
	phase["candidate_generator_anchor"] = "0x4a17f5";
	phase["distance_validation_anchor"] = "0x4a1701";
	phase["late_payload_consumer_anchor"] = "0x4a79a3";
	phase["materializes_coordinates"] = false;
	phase["materializes_connection_guards"] = false;
	phase["materializes_roads"] = false;
	phase["materializes_blockers"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "coordinate_replay_0x4a17f5_0x4a1701";
	if (String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	Dictionary catalog_load;
	Dictionary template_record = find_project_template_record(String(selection.get("adapted_template_id", "")), catalog_load);
	phase["project_catalog_load"] = catalog_load;
	if (template_record.is_empty() || Variant(template_record.get("links", Variant())).get_type() != Variant::ARRAY) {
		phase["status"] = "blocked_missing_project_template_links";
		return phase;
	}

	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array links = template_record.get("links", Array());
	Array seeds;
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		Dictionary filter = link.get("player_filter", Dictionary());
		if (!player_filter_allows(filter, human_count, player_count)) {
			continue;
		}
		Dictionary endpoints = link.get("source_endpoints", Dictionary());
		const int32_t source_zone_a = int32_t(endpoints.get("zone1", 0));
		const int32_t source_zone_b = int32_t(endpoints.get("zone2", 0));
		if (source_zone_a <= 0 || source_zone_b <= 0) {
			continue;
		}
		Dictionary seed;
		seed["link_index"] = seeds.size();
		seed["source_row"] = Dictionary(link.get("grammar_source", Dictionary())).get("source_row", -1);
		seed["source_zone_a"] = source_zone_a;
		seed["source_zone_b"] = source_zone_b;
		seed["runtime_zone_a"] = source_zone_a - 1;
		seed["runtime_zone_b"] = source_zone_b - 1;
		seed["guard_value"] = link.get("guard_value", Dictionary(link.get("guard", Dictionary())).get("value", 0));
		seed["wide"] = bool(link.get("wide", false));
		seed["border_guard"] = bool(link.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		seeds.append(seed);
	}

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "res://content/random_map_template_catalog.json recovered link rows consumed through h3maped 0x4a1f3b";
	phase["link_seed_count"] = seeds.size();
	phase["link_seeds"] = seeds;
	return phase;
}

Dictionary coordinate_replay_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &link_phase, uint32_t rng_state_after_template_selection) {
	Dictionary phase;
	phase["phase_id"] = "coordinate_replay";
	phase["h3maped_anchor"] = "0x4a218c";
	phase["link_endpoint_consumer_anchor"] = "0x4a1f3b";
	phase["candidate_generator_anchor"] = "0x4a17f5";
	phase["distance_validation_anchor"] = "0x4a1701";
	phase["candidate_prune_anchor"] = "0x4a1ad8";
	phase["bbox_rescale_anchor"] = "0x4a19ed";
	phase["status"] = "blocked_until_link_seed_setup";
	phase["angle_table_x_address"] = "0x58dc28";
	phase["angle_table_y_address"] = "0x58dd28";
	phase["rng_state_before_0x4a218c_replay_uint32"] = int64_t(rng_state_after_template_selection);
	phase["materializes_zone_footprints"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "zone_footprint_source_nodes_0x4a3a03_0x4cc788";
	if (int32_t(normalized_config.get("level_count", 1)) != 1
			|| String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(link_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	Array runtime_records = runtime_zone_phase.get("runtime_zone_records", Array());
	std::vector<RuntimeZoneSeed> zones;
	zones.reserve(size_t(runtime_records.size()));
	for (int32_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[index];
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(runtime.get("runtime_index", index));
		zone.source_zone_id = int32_t(runtime.get("source_zone_id", -1));
		zone.source_bucket = int32_t(runtime.get("source_bucket", -1));
		zone.source_owner_index = int32_t(runtime.get("source_owner_index", -1));
		zone.actual_owner_color = int32_t(runtime.get("actual_owner_color", -1));
		zone.source_base_size = int32_t(runtime.get("source_base_size", 0));
		zone.scaled_size = zone.source_base_size;
		zones.push_back(zone);
	}

	std::vector<RuntimeLinkSeed> links;
	Array link_seeds = link_phase.get("link_seeds", Array());
	for (int32_t index = 0; index < link_seeds.size(); ++index) {
		if (Variant(link_seeds[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = link_seeds[index];
		RuntimeLinkSeed seed;
		seed.runtime_a = int32_t(link.get("runtime_zone_a", -1));
		seed.runtime_b = int32_t(link.get("runtime_zone_b", -1));
		if (seed.runtime_a >= 0 && seed.runtime_b >= 0) {
			links.push_back(seed);
		}
	}

	H3MapedRng rng { rng_state_after_template_selection };
	Array placement_steps;
	Array rng_events;
	int32_t coordinate_rng_calls = 0;
	int32_t town_choice_rng_calls = 0;
	bool complete = true;

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= runtime_records.size()) {
			return;
		}
		Dictionary runtime = runtime_records[zone_index];
		Array allowed_factions = runtime.get("allowed_faction_ids_for_49b3c1", Array());
		if (!allowed_factions.is_empty()) {
			const int32_t rng_value = rng.next();
			const int32_t town_choice_index = rng_value % int32_t(allowed_factions.size());
			runtime["selected_faction_id_49b3c1"] = String(allowed_factions[town_choice_index]);
			runtime["town_choice_index_49b3c1"] = town_choice_index;
			runtime["faction_source"] = "0x49b3c1_allowed_town_choice";
			town_choice_rng_calls += 1;
			Dictionary event;
			event["consumer"] = "0x49b3c1";
			event["runtime_zone_index"] = zone_index;
			event["value"] = rng_value;
			event["modulus"] = allowed_factions.size();
			event["selected_index"] = town_choice_index;
			event["selected_faction_id"] = runtime["selected_faction_id_49b3c1"];
			rng_events.append(event);
		}
		runtime_records[zone_index] = runtime;
	};

	auto place_zone = [&](int32_t zone_index, const String &pass_id, const std::vector<int32_t> &visible_runtime_indices) {
		std::vector<CoordCandidate> candidates;
		Dictionary step;
		step["pass"] = pass_id;
		step["runtime_zone_index"] = zone_index;
		step["runtime_vector_count_before_call"] = int32_t(visible_runtime_indices.size());
		Array visible_report;
		for (const int32_t visible_index : visible_runtime_indices) {
			visible_report.append(visible_index);
		}
		step["visible_runtime_zone_indices"] = visible_report;

		if (visible_runtime_indices.empty()) {
			candidates.push_back(CoordCandidate { 0, 0, 0 });
			step["candidate_source"] = "0x4a1f7b_empty_runtime_vector_origin";
			step["explicit_link_base_count"] = 0;
			step["fallback_base_count"] = 0;
		} else {
			int32_t explicit_base_count = 0;
			for (const RuntimeLinkSeed &link : links) {
				int32_t other_index = -1;
				if (link.runtime_a == zone_index) {
					other_index = link.runtime_b;
				} else if (link.runtime_b == zone_index) {
					other_index = link.runtime_a;
				}
				if (other_index < 0 || std::find(visible_runtime_indices.begin(), visible_runtime_indices.end(), other_index) == visible_runtime_indices.end()) {
					continue;
				}
				explicit_base_count += 1;
				append_angle_candidates_4a17f5(zones[size_t(other_index)], zones[size_t(zone_index)], zones, visible_runtime_indices, candidates);
			}
			step["explicit_link_base_count"] = explicit_base_count;
			if (candidates.empty()) {
				for (const int32_t other_index : visible_runtime_indices) {
					append_angle_candidates_4a17f5(zones[size_t(other_index)], zones[size_t(zone_index)], zones, visible_runtime_indices, candidates);
				}
				step["candidate_source"] = "0x4a2069_existing_runtime_zone_fallback";
				step["fallback_base_count"] = int32_t(visible_runtime_indices.size());
			} else {
				step["candidate_source"] = "0x4a200c_explicit_source_link_endpoint";
				step["fallback_base_count"] = 0;
			}
		}

		step["candidate_count_before_4a1ad8"] = int32_t(candidates.size());
		step["candidate_preview_before_4a1ad8"] = coordinate_candidate_report(candidates);
		prune_candidates_4a1ad8_single_level(zones[size_t(zone_index)], zones, visible_runtime_indices, links, candidates);
		step["candidate_count_after_4a1ad8"] = int32_t(candidates.size());
		step["candidate_preview_after_4a1ad8"] = coordinate_candidate_report(candidates);
		if (candidates.empty()) {
			step["blocked_reason"] = "0x4a1f3b produced no coordinate candidates";
			complete = false;
			placement_steps.append(step);
			return;
		}

		const int32_t rng_value = rng.next();
		coordinate_rng_calls += 1;
		const int32_t selected_index = rng_value % int32_t(candidates.size());
		const CoordCandidate selected = candidates[size_t(selected_index)];
		zones[size_t(zone_index)].x = selected.x;
		zones[size_t(zone_index)].y = selected.y;
		zones[size_t(zone_index)].level = selected.level;
		step["rng_value"] = rng_value;
		step["selected_candidate_index"] = selected_index;
		Dictionary selected_report;
		selected_report["x"] = selected.x;
		selected_report["y"] = selected.y;
		selected_report["level"] = selected.level;
		step["selected_candidate"] = selected_report;
		Dictionary event;
		event["consumer"] = "0x4a1f3b_candidate_selection";
		event["runtime_zone_index"] = zone_index;
		event["pass"] = pass_id;
		event["value"] = rng_value;
		event["modulus"] = candidates.size();
		event["selected_index"] = selected_index;
		rng_events.append(event);
		placement_steps.append(step);
	};

	for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
		std::vector<int32_t> visible;
		for (int32_t visible_index = 0; visible_index < zone_index; ++visible_index) {
			visible.push_back(visible_index);
		}
		apply_runtime_initializer_rng(zone_index);
		place_zone(zone_index, "0x4a2226_initial_runtime_zone_insertion", visible);
	}
	std::vector<int32_t> all_visible;
	for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
		all_visible.push_back(zone_index);
	}
	for (int32_t pass = 0; pass < 2; ++pass) {
		for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
			place_zone(zone_index, pass == 0 ? String("0x4a22b3_refinement_pass_1") : String("0x4a22b3_refinement_pass_2"), all_visible);
		}
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const RuntimeZoneSeed &zone : zones) {
		min_y = std::min(zone.y - zone.source_base_size, min_y);
		min_x = std::min(zone.x - zone.source_base_size, min_x);
		max_y = std::max(zone.y + zone.source_base_size + 1, max_y);
		max_x = std::max(zone.x + zone.source_base_size + 1, max_x);
	}
	const int32_t bbox_height = max_y - min_y;
	const int32_t bbox_width = max_x - min_x;
	const int32_t bbox_span = std::max(bbox_height, bbox_width);
	const int32_t map_span = std::min(int32_t(normalized_config.get("width", 36)), int32_t(normalized_config.get("height", 36)));
	const int32_t offset_y = (min_y - bbox_span + max_y) / 2;
	const int32_t offset_x = (min_x - bbox_span + max_x) / 2;

	Array scaled_zone_coordinates;
	for (RuntimeZoneSeed &zone : zones) {
		if (bbox_span > 0) {
			zone.x = ((zone.x - offset_x) * map_span) / bbox_span;
			zone.y = ((zone.y - offset_y) * map_span) / bbox_span;
			zone.scaled_size = (zone.source_base_size * map_span) / bbox_span;
		}
		Dictionary item;
		item["runtime_zone_index"] = zone.runtime_index;
		item["x_after_bbox_rescale"] = zone.x;
		item["y_after_bbox_rescale"] = zone.y;
		item["level"] = zone.level;
		item["runtime_size_after_bbox_rescale"] = zone.scaled_size;
		scaled_zone_coordinates.append(item);
	}

	Dictionary bbox;
	bbox["min_y_before_rescale"] = min_y;
	bbox["min_x_before_rescale"] = min_x;
	bbox["max_y_before_rescale"] = max_y;
	bbox["max_x_before_rescale"] = max_x;
	bbox["height_before_rescale"] = bbox_height;
	bbox["width_before_rescale"] = bbox_width;
	bbox["selected_span_before_rescale"] = bbox_span;
	bbox["map_span"] = map_span;
	bbox["offset_y"] = offset_y;
	bbox["offset_x"] = offset_x;

	phase["status"] = complete ? String("active_runtime_state_ready") : String("blocked_coordinate_candidate_replay");
	phase["source"] = "h3maped 0x4a218c interleaved runtime initializer, 0x4a1f3b endpoint walking, 0x4a17f5 candidates, 0x4a1701 spacing validation, 0x4a1ad8 pruning, and 0x4a19ed bbox rescale";
	phase["placement_step_count"] = placement_steps.size();
	phase["placement_steps"] = placement_steps;
	phase["coordinate_rng_calls_during_0x4a1f3b"] = coordinate_rng_calls;
	phase["town_choice_rng_calls_during_0x4a218c"] = town_choice_rng_calls;
	phase["total_interleaved_rng_calls_during_0x4a218c"] = coordinate_rng_calls + town_choice_rng_calls;
	phase["rng_event_count"] = rng_events.size();
	phase["rng_events"] = rng_events;
	phase["runtime_zone_records_after_0x49b3c1"] = runtime_records;
	phase["rng_state_after_0x4a218c_replay_uint32"] = int64_t(rng.state);
	phase["bounding_box_rescale"] = bbox;
	phase["scaled_zone_coordinates"] = scaled_zone_coordinates;
	return phase;
}

Dictionary small_pipeline_state(const Dictionary &normalized_config) {
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_generation_state_v1";
	state["runtime_generation_allowed"] = false;
	state["partial_materialized_payload_public_api"] = false;
	state["materializes_runtime_players"] = false;
	state["materializes_map_cells"] = false;
	state["materializes_public_output"] = false;

	Dictionary selection = selection_identity(normalized_config);
	state["selection_identity"] = selection;
	if (!bool(selection.get("ok", false))) {
		state["status"] = "blocked_before_template_selection";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	const TemplateEvidence *selected_template = template_for_catalog_index(int32_t(selection.get("source_catalog_index", -1)));
	if (selected_template == nullptr) {
		state["status"] = "blocked_missing_selected_template";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	Array completed_phases;
	completed_phases.append("template_selection");
	Dictionary player_phase = player_slot_assignment_phase(*selected_template, normalized_config);
	completed_phases.append("player_slot_assignment");
	Dictionary runtime_zone_phase = runtime_zone_records_phase(selection, player_phase);
	if (String(runtime_zone_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("runtime_zone_records");
	}
	Dictionary link_phase = link_seed_phase(selection, normalized_config, runtime_zone_phase);
	if (String(link_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("link_seed_setup");
	}
	Dictionary coordinate_phase = coordinate_replay_phase(
			normalized_config,
			runtime_zone_phase,
			link_phase,
			uint32_t(int64_t(selection.get("rng_state_after_selection_uint32", 0))));
	if (String(coordinate_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("coordinate_replay");
	}
	const bool coordinate_ready = completed_phases.has("coordinate_replay");
	state["status"] = coordinate_ready ? String("coordinate_replay_active_runtime_state_ready") : (completed_phases.size() >= 3 ? String("runtime_zone_records_active_runtime_state_ready") : String("player_slot_assignment_active_runtime_state_ready"));
	state["completed_phase_ids"] = completed_phases;
	state["completed_phase_count"] = completed_phases.size();
	state["player_slot_assignment"] = player_phase;
	state["runtime_zone_records"] = runtime_zone_phase;
	state["link_seed_setup"] = link_phase;
	state["coordinate_replay"] = coordinate_phase;
	state["blocked_next"] = coordinate_ready ? String("zone_footprint_source_nodes_0x4a3a03_0x4cc788") : (completed_phases.size() >= 3 ? String("coordinate_replay_and_zone_footprints_0x4a1f3b") : String("runtime_zone_records_0x4a218c"));
	return state;
}

Array restart_backlog() {
	Array phases;
	const char *ids[] = {
		"template_selection",
		"player_slot_assignment",
		"runtime_zone_records",
		"coordinate_replay_and_zone_footprints",
		"terrain_writeout_and_visuals",
		"town_object_placement",
		"roads_and_rivers",
		"connections_blockers_and_guards",
		"mines_rewards_and_objects",
		"final_h3m_writeout",
	};
	const char *anchors[] = {
		"0x49f0cd/0x4ac597/0x4e7276",
		"0x4ac62a..0x4ac6ec",
		"0x4a218c/0x49b3c1/0x49b53d",
		"0x4a1f3b/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed/0x4a3a03/0x4ccb64/0x4ccdfc/0x4a2777/0x4a325d/0x4a3710",
		"0x4a3f27/0x4bcff5/0x4bb74b/0x4bc5f0/0x49acf6/0x49b2b6",
		"0x4a8d2c/0x4a8db2/0x4a93a2/0x49aa93/0x49a09c/0x49ba89",
		"0x4ab52a/0x4aae7b/0x4ab37f/0x4b4243",
		"0x4a79a3/0x4a61bc/0x4a696b/0x4a6cf2/0x4a7605/0x4a65a5/0x4a5e03",
		"0x49aa93 object placement family",
		"0x49b2b6",
	};
	for (int32_t index = 0; index < 10; ++index) {
		Dictionary phase;
		phase["id"] = ids[index];
		phase["h3maped_anchors"] = anchors[index];
		phase["status"] = index == 0 ? String("active_boundary_only") : (index <= 3 ? String("active_runtime_state_ready") : String("pending_strict_port"));
		phase["materializes_public_output"] = false;
		phase["requires_exe_derived_implementation_before_runtime"] = index > 3;
		phases.append(phase);
	}
	return phases;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return int32_t(normalized_config.get("width", 36)) == 36
			&& int32_t(normalized_config.get("height", 36)) == 36
			&& int32_t(normalized_config.get("level_count", 1)) == 1
			&& String(normalized_config.get("water_mode", "land")) == "land";
}

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "unsupported_scope";
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["rng_function_address"] = "0x4e7276";
	result["seed_setter_address"] = "0x4e7269";
	result["algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
	result["supported_scope"] = supports_scope(normalized_config);
	if (!supports_scope(normalized_config)) {
		return result;
	}

	const Array accepted = accepted_templates(normalized_config);
	result["accepted_template_count"] = accepted.size();
	if (accepted.is_empty()) {
		result["status"] = "no_accepted_templates";
		return result;
	}

	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	uint32_t seed_value = 0;
	if (!parse_numeric_seed(seed_text, seed_value)) {
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["seed_text"] = seed_text;
		return result;
	}

	H3MapedRng rng;
	rng.state = seed_value;
	const int32_t first_value = rng.next();
	const int32_t selected_index = first_value % int32_t(accepted.size());
	Dictionary selected_template = accepted[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_uint32"] = int64_t(seed_value);
	result["rng_first_value"] = first_value;
	result["rng_state_after_selection_uint32"] = int64_t(rng.state);
	result["selected_vector_index"] = selected_index;
	result["source_template_id"] = selected_template.get("id", "");
	result["source_catalog_index"] = selected_template.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected_template.get("adapted_template_id", "");
	result["selected_template"] = selected_template;
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	const Array accepted = accepted_templates(normalized_config);

	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_restart_boundary_v2";
	report["schema_version"] = 2;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_restart_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "small_only_h3maped_exe_restart_no_catalog_auto_no_hash_selection_no_private_phase_ledger_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "overgrown_active_port_archived_out_of_build";
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
	report["archived_phase_ledger_path"] = ARCHIVED_PHASE_LEDGER_PATH;
	report["archived_active_boundary_path"] = ARCHIVED_ACTIVE_BOUNDARY_PATH;
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["spec_path"] = SPEC_PATH;
	report["catalog_path"] = CATALOG_SOURCE_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = size_score(normalized_config);
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["accepted_template_count"] = accepted.size();
	report["accepted_templates"] = accepted;
	report["selection_identity"] = selection_identity(normalized_config);
	report["small_generation_state"] = small_pipeline_state(normalized_config);
	report["restart_phase_backlog"] = restart_backlog();
	report["materialized_phase_status"] = "coordinate_replay_state_only";
	report["blocked_before_materialization"] = "waiting_for_strict_h3maped zone footprint and map-cell phase ports from 0x4ac552";
	report["explicitly_absent_reports"] = "zone footprints, terrain, towns, roads, blockers, guards, mines, rewards, and final writeout are absent until implemented as runtime generator phases";
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_restart_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "Small h3maped-derived RMG has been restarted from a compact executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["small_generation_state"] = small_pipeline_state(normalized_config);
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
