#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iterator>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *ARCHIVED_PHASE_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp";
constexpr const char *ARCHIVED_ACTIVE_BOUNDARY_PATH = "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp";
constexpr const char *ARCHIVED_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp";
constexpr const char *OLDER_LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

struct TemplateEvidence {
	const char *id;
	int32_t catalog_index;
	int32_t min_size_score;
	int32_t max_size_score;
	int32_t min_humans;
	int32_t max_humans;
	int32_t min_total_players;
	int32_t max_total_players;
	int32_t zone_count;
	int32_t connection_count;
	const char *adapted_template_id;
	uint8_t human_capable_source_owner_mask;
	uint8_t player_capable_source_owner_mask;
};

struct SourceZoneEvidence {
	int32_t template_catalog_index;
	int32_t source_zone_id;
	const char *role;
	int32_t source_bucket;
	int32_t source_owner_index;
	int32_t base_size;
	int32_t min_player_castles;
	bool terrain_match_to_town;
	const char *terrain_policy;
	const char *monster_strength;
	int32_t allowed_town_count;
	int32_t allowed_terrain_count;
	int32_t minimum_ore_mines;
	int32_t minimum_wood_mines;
	int32_t minimum_rare_mines;
};

struct SourceLinkEvidence {
	int32_t template_catalog_index;
	int32_t source_zone_a;
	int32_t source_zone_b;
	int32_t guard_value;
	bool wide;
	bool border_guard;
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

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
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

const SourceZoneEvidence TEMPLATE_018_SOURCE_ZONES[] = {
	{ 18, 1, "human_start", 0, 0, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 2, "human_start", 0, 1, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 3, "treasure", 2, -2, 11, 0, false, "all_land_h3", "strong", 0, 8, 0, 0, 5 },
	{ 18, 4, "human_start", 0, 2, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 5, "human_start", 0, 3, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 6, "treasure", 2, -2, 11, 0, false, "all_land_h3", "strong", 0, 8, 0, 0, 5 },
};

const SourceLinkEvidence TEMPLATE_018_SOURCE_LINKS[] = {
	{ 18, 1, 4, 3000, false, false },
	{ 18, 2, 5, 3000, false, false },
	{ 18, 4, 5, 3000, false, false },
	{ 18, 3, 5, 6000, false, false },
	{ 18, 6, 4, 6000, false, false },
};

const char *H3MAPED_ALLOWED_MAIN_TOWNS[] = {
	"castle",
	"rampart",
	"tower",
	"inferno",
	"necropolis",
	"dungeon",
	"stronghold",
	"fortress",
	"elemental",
};

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
	record["source"] = "recovered h3maped template catalog parsed from /root/Downloads/h3maped.exe";
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

Dictionary player_slot_assignment_context(const TemplateEvidence &selected_template, const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(0, int32_t(constraints.get("human_count", 1)));
	const int32_t player_count = std::max(human_count, int32_t(constraints.get("player_count", 2)));
	Dictionary context;
	context["phase_id"] = "player_slot_assignment";
	context["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	context["status"] = "private_context_ready";
	context["selected_color_bitmap_offset"] = "generator+0xed8";
	context["assignment_slots_offset"] = "generator+0xee0";
	context["mapped_slots_offset"] = "generator+0xee4";
	context["human_capable_source_owner_mask"] = selected_template.human_capable_source_owner_mask;
	context["player_capable_source_owner_mask"] = selected_template.player_capable_source_owner_mask;
	context["human_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.human_capable_source_owner_mask);
	context["player_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.player_capable_source_owner_mask);

	Array selected_color_order;
	Array assignment_slots;
	Array mapped_slots;
	for (int32_t index = 0; index < 8; ++index) {
		selected_color_order.append(index);
		assignment_slots.append(-1);
		mapped_slots.append(-1);
	}

	Array assignments;
	Array human_indices = context["human_capable_source_owner_indices"];
	Array player_indices = context["player_capable_source_owner_indices"];
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

	context["selected_color_order"] = selected_color_order;
	context["raw_ee0_slots"] = assignment_slots;
	context["mapped_ee4_slots"] = mapped_slots;
	context["assignment_records"] = assignments;
	context["assigned_player_count"] = assigned_players;
	context["requested_human_count"] = human_count;
	context["requested_player_count"] = player_count;
	context["materializes_runtime_players"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "runtime_zone_records_0x4a218c";
	return context;
}

Dictionary runtime_zone_records_context(const TemplateEvidence &selected_template, const Dictionary &player_context) {
	Dictionary context;
	context["phase_id"] = "runtime_zone_records";
	context["h3maped_anchor"] = "0x4a218c";
	context["initializer_anchor"] = "0x49b452";
	context["status"] = "pending_source_zone_evidence_for_selected_template";
	context["runtime_zone_vector_begin_offset"] = "generator+0x10e0";
	context["runtime_zone_vector_end_offset"] = "generator+0x10e4";
	context["runtime_zone_vector_capacity_offset"] = "generator+0x10e8";
	context["runtime_zone_record_size_bytes"] = 0x414;
	context["source_zone_pointer_offset"] = "runtime_zone+0x00";
	context["chosen_town_offset"] = "runtime_zone+0x04";
	context["chosen_terrain_offset"] = "runtime_zone+0x0c";
	context["owner_mapping_source_offset"] = "generator+0xee4";
	context["materializes_runtime_zone_coordinates"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_runtime_players"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";

	if (selected_template.catalog_index != 18) {
		return context;
	}

	const Array mapped_slots = player_context.get("mapped_ee4_slots", Array());
	Array records;
	Array actual_owner_colors_by_runtime_zone;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = 0;
	for (int32_t index = 0; index < int32_t(std::size(TEMPLATE_018_SOURCE_ZONES)); ++index) {
		const SourceZoneEvidence &source_zone = TEMPLATE_018_SOURCE_ZONES[index];
		int32_t actual_owner_color = -1;
		if (source_zone.source_owner_index >= 0 && source_zone.source_owner_index < mapped_slots.size()) {
			actual_owner_color = int32_t(mapped_slots[source_zone.source_owner_index]);
		}

		Dictionary record;
		record["runtime_zone_index"] = index;
		record["source_template_catalog_index"] = source_zone.template_catalog_index;
		record["source_zone_id"] = source_zone.source_zone_id;
		record["role"] = source_zone.role;
		record["source_bucket"] = source_zone.source_bucket;
		record["source_owner_index"] = source_zone.source_owner_index;
		record["actual_owner_color"] = actual_owner_color;
		record["level"] = 0;
		record["source_base_size"] = source_zone.base_size;
		record["min_player_castles"] = source_zone.min_player_castles;
		record["terrain_match_to_town"] = source_zone.terrain_match_to_town;
		record["terrain_policy"] = source_zone.terrain_policy;
		record["monster_strength"] = source_zone.monster_strength;
		record["allowed_town_count"] = source_zone.allowed_town_count;
		record["allowed_terrain_count"] = source_zone.allowed_terrain_count;
		record["minimum_ore_mines"] = source_zone.minimum_ore_mines;
		record["minimum_wood_mines"] = source_zone.minimum_wood_mines;
		record["minimum_rare_mines"] = source_zone.minimum_rare_mines;
		if (source_zone.allowed_town_count > 0) {
			Array allowed_factions;
			for (int32_t town_index = 0; town_index < int32_t(std::size(H3MAPED_ALLOWED_MAIN_TOWNS)); ++town_index) {
				allowed_factions.append(H3MAPED_ALLOWED_MAIN_TOWNS[town_index]);
			}
			record["allowed_faction_ids_for_49b3c1"] = allowed_factions;
		}
		records.append(record);

		actual_owner_colors_by_runtime_zone.append(actual_owner_color);
		minimum_player_castles += source_zone.min_player_castles;
		if (minimum_source_base_size == 0 || source_zone.base_size < minimum_source_base_size) {
			minimum_source_base_size = source_zone.base_size;
		}
		if (source_zone.source_owner_index >= 0) {
			if (actual_owner_color >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else {
			treasure_zone_count += 1;
		}
	}

	context["status"] = "private_context_ready";
	context["source"] = "recovered h3maped template catalog plus 0x4a218c runtime-zone record setup";
	context["selected_template_source_catalog_index"] = selected_template.catalog_index;
	context["runtime_zone_records"] = records;
	context["runtime_zone_count"] = records.size();
	context["assigned_start_zone_count"] = assigned_start_zone_count;
	context["unassigned_start_zone_count"] = unassigned_start_zone_count;
	context["treasure_zone_count"] = treasure_zone_count;
	context["minimum_player_castles"] = minimum_player_castles;
	context["minimum_source_base_size"] = minimum_source_base_size;
	context["actual_owner_colors_by_runtime_zone"] = actual_owner_colors_by_runtime_zone;
	return context;
}

Dictionary link_seed_context(const TemplateEvidence &selected_template, const Dictionary &runtime_zone_context) {
	Dictionary context;
	context["phase_id"] = "link_seed_setup";
	context["h3maped_anchor"] = "0x4a1f3b";
	context["candidate_generator_anchor"] = "0x4a17f5";
	context["distance_validation_anchor"] = "0x4a1701";
	context["late_payload_consumer_anchor"] = "0x4a79a3";
	context["status"] = "pending_source_link_evidence_for_selected_template";
	context["materializes_coordinates"] = false;
	context["materializes_connection_guards"] = false;
	context["materializes_roads"] = false;
	context["materializes_blockers"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "coordinate_replay_0x4a17f5_0x4a1701";
	if (selected_template.catalog_index != 18) {
		return context;
	}

	Array seeds;
	for (int32_t index = 0; index < int32_t(std::size(TEMPLATE_018_SOURCE_LINKS)); ++index) {
		const SourceLinkEvidence &source_link = TEMPLATE_018_SOURCE_LINKS[index];
		Dictionary seed;
		seed["link_index"] = index;
		seed["source_template_catalog_index"] = source_link.template_catalog_index;
		seed["source_zone_a"] = source_link.source_zone_a;
		seed["source_zone_b"] = source_link.source_zone_b;
		seed["runtime_zone_a"] = source_link.source_zone_a - 1;
		seed["runtime_zone_b"] = source_link.source_zone_b - 1;
		seed["guard_value"] = source_link.guard_value;
		seed["wide"] = source_link.wide;
		seed["border_guard"] = source_link.border_guard;
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		seeds.append(seed);
	}

	context["status"] = String(runtime_zone_context.get("status", "")) == "private_context_ready" ? String("private_context_ready") : String("blocked_until_runtime_zone_records");
	context["source"] = "recovered h3maped template connection catalog plus 0x4a1f3b endpoint seed setup";
	context["link_seed_count"] = seeds.size();
	context["link_seeds"] = seeds;
	return context;
}

Dictionary coordinate_replay_context(const Dictionary &normalized_config, const Dictionary &runtime_zone_context, const Dictionary &link_context, uint32_t rng_state_after_template_selection) {
	Dictionary context;
	context["phase_id"] = "coordinate_replay_and_zone_footprints";
	context["h3maped_anchor"] = "0x4a218c";
	context["link_endpoint_consumer_anchor"] = "0x4a1f3b";
	context["candidate_generator_anchor"] = "0x4a17f5";
	context["distance_validation_anchor"] = "0x4a1701";
	context["candidate_prune_anchor"] = "0x4a1ad8";
	context["bbox_rescale_anchor"] = "0x4a19ed";
	context["status"] = "blocked_until_one_level_small_land_scope";
	context["angle_table_x_address"] = "0x58dc28";
	context["angle_table_y_address"] = "0x58dd28";
	context["rng_state_before_0x4a218c_replay_uint32"] = int64_t(rng_state_after_template_selection);
	context["materializes_map_cells"] = false;
	context["materializes_zone_footprints"] = false;
	context["materializes_terrain"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "zone_footprint_source_nodes_0x4a3a03_0x4cc788";
	if (int32_t(normalized_config.get("level_count", 1)) != 1 || String(runtime_zone_context.get("status", "")) != "private_context_ready" || String(link_context.get("status", "")) != "private_context_ready") {
		return context;
	}

	Array runtime_records = runtime_zone_context.get("runtime_zone_records", Array());
	std::vector<RuntimeZoneSeed> zones;
	zones.reserve(size_t(runtime_records.size()));
	for (int32_t index = 0; index < runtime_records.size(); ++index) {
		Dictionary runtime = runtime_records[index];
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(runtime.get("runtime_zone_index", index));
		zone.source_zone_id = int32_t(runtime.get("source_zone_id", -1));
		zone.source_bucket = int32_t(runtime.get("source_bucket", -1));
		zone.source_owner_index = int32_t(runtime.get("source_owner_index", -1));
		zone.actual_owner_color = int32_t(runtime.get("actual_owner_color", -1));
		zone.source_base_size = int32_t(runtime.get("source_base_size", 0));
		zone.scaled_size = zone.source_base_size;
		zones.push_back(zone);
	}

	std::vector<RuntimeLinkSeed> links;
	Array link_seeds = link_context.get("link_seeds", Array());
	for (int32_t index = 0; index < link_seeds.size(); ++index) {
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
		String faction_id = String(runtime.get("faction_id", ""));
		if (faction_id.is_empty()) {
			Array allowed_factions = runtime.get("allowed_faction_ids_for_49b3c1", Array());
			if (!allowed_factions.is_empty()) {
				const int32_t rng_value = rng.next();
				const int32_t town_choice_index = rng_value % int32_t(allowed_factions.size());
				faction_id = String(allowed_factions[town_choice_index]);
				runtime["faction_id"] = faction_id;
				runtime["town_choice_index"] = town_choice_index;
				runtime["faction_source"] = "0x49b3c1_allowed_town_choice";
				town_choice_rng_calls += 1;
				Dictionary event;
				event["consumer"] = "0x49b3c1";
				event["runtime_zone_index"] = zone_index;
				event["value"] = rng_value;
				event["modulus"] = allowed_factions.size();
				event["selected_index"] = town_choice_index;
				event["selected_faction_id"] = faction_id;
				rng_events.append(event);
			}
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

	context["status"] = complete ? String("private_context_ready") : String("blocked_coordinate_candidate_replay");
	context["source"] = "h3maped 0x4a218c interleaved runtime initializer, 0x4a1f3b endpoint walking, 0x4a17f5 candidates, 0x4a1701 spacing validation, 0x4a1ad8 pruning, and 0x4a19ed bbox rescale";
	context["placement_step_count"] = placement_steps.size();
	context["placement_steps"] = placement_steps;
	context["coordinate_rng_calls_during_0x4a1f3b"] = coordinate_rng_calls;
	context["town_choice_rng_calls_during_0x4a218c"] = town_choice_rng_calls;
	context["total_interleaved_rng_calls_during_0x4a218c"] = coordinate_rng_calls + town_choice_rng_calls;
	context["rng_event_count"] = rng_events.size();
	context["rng_events"] = rng_events;
	context["runtime_zone_records_after_0x49b3c1"] = runtime_records;
	context["rng_state_after_0x4a218c_replay_uint32"] = int64_t(rng.state);
	context["bounding_box_rescale"] = bbox;
	context["scaled_zone_coordinates"] = scaled_zone_coordinates;
	return context;
}

Dictionary zone_footprint_phase_context(const Dictionary &normalized_config, const Dictionary &runtime_zone_context, const Dictionary &coordinate_context) {
	Dictionary context;
	context["phase_id"] = "zone_footprint_phase_boundary";
	context["h3maped_anchor"] = "0x4a3a03";
	context["helper_sequence"] = "0x4a2777 -> 0x4a325d -> 0x4a3710";
	context["synthetic_source_zone_id"] = "0xd4";
	context["synthetic_triplets"] = "0xa0=100,0xa4=1000,0xa8=5,0xac=2000,0xb0=6000,0xb4=1";
	context["status"] = "blocked_until_coordinate_replay";
	context["materializes_boundaries"] = false;
	context["materializes_span_fill"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "source_node_rectangle_0x4cc788";
	if (String(coordinate_context.get("status", "")) != "private_context_ready") {
		return context;
	}

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	Array runtime_records = runtime_zone_context.get("runtime_zone_records", Array());
	Array levels;
	int32_t total_collected = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		Array zone_indices;
		Array helper_inputs;
		for (int32_t index = 0; index < runtime_records.size(); ++index) {
			Dictionary record = runtime_records[index];
			if (int32_t(record.get("level", 0)) != level) {
				continue;
			}
			const int32_t runtime_index = int32_t(record.get("runtime_zone_index", index));
			zone_indices.append(runtime_index);
			Dictionary helper_input;
			helper_input["call_order"] = helper_inputs.size();
			helper_input["helper_address"] = "0x4a2777";
			helper_input["runtime_zone_index"] = runtime_index;
			helper_input["source_zone_id"] = record.get("source_zone_id", -1);
			helper_input["level"] = level;
			helper_input["input_status"] = "queued_for_0x4a2777_no_boundary_materialization";
			helper_inputs.append(helper_input);
		}
		total_collected += zone_indices.size();
		Dictionary level_record;
		level_record["level"] = level;
		level_record["collected_runtime_zone_indices"] = zone_indices;
		level_record["collected_runtime_zone_count"] = zone_indices.size();
		level_record["helper_call_inputs"] = helper_inputs;
		level_record["helper_call_input_count"] = helper_inputs.size();
		level_record["synthetic_zone_appended"] = false;
		level_record["synthetic_zone_status"] = water_code == 0 && level_count == 1 ? String("not_applicable_small_one_level_land") : String("pending_water_or_multilevel_rule_port");
		level_record["helper_status"] = "0x4a2777_inputs_queued_0x4a325d_0x4a3710_materialization_pending";
		levels.append(level_record);
	}

	context["status"] = "private_context_ready";
	context["source"] = "h3maped 0x4a3a03 per-level runtime-zone collection and helper input scheduling";
	context["level_count"] = level_count;
	context["h3maped_water_mode_code"] = water_code;
	context["per_level"] = levels;
	context["total_collected_runtime_zone_count"] = total_collected;
	context["synthetic_zone_appended_count"] = 0;
	context["blocked_next"] = "source_node_rectangle_0x4cc788";
	return context;
}

Dictionary source_node_rectangle_context(const Dictionary &zone_footprint_context) {
	Dictionary context;
	context["phase_id"] = "source_node_rectangle";
	context["h3maped_anchor"] = "0x4cc788";
	context["node_constructor_anchor"] = "0x4cc955";
	context["splitter_anchor"] = "0x4ccb64";
	context["locator_anchor"] = "0x4cca55";
	context["finalizer_anchor"] = "0x4ccdfc";
	context["status"] = "blocked_until_zone_footprint_phase";
	context["materializes_source_node_graph"] = false;
	context["materializes_boundaries"] = false;
	context["materializes_span_fill"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_public_output"] = false;
	context["feeds_real_0x4a2777_boundary"] = false;
	context["blocked_next"] = "polygon_split_model_0x4ccb64_0x4ccdfc";
	if (String(zone_footprint_context.get("status", "")) != "private_context_ready") {
		return context;
	}

	Dictionary bounds;
	bounds["min_x"] = -200;
	bounds["min_y"] = -200;
	bounds["max_x"] = 400;
	bounds["max_y"] = 400;
	bounds["constant_min_hex"] = "0xffffff38";
	bounds["constant_max_hex"] = "0x190";

	Array edges;
	auto edge = [&](const char *id, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y, const char *next) {
		Dictionary item;
		item["id"] = id;
		item["from_x"] = from_x;
		item["from_y"] = from_y;
		item["to_x"] = to_x;
		item["to_y"] = to_y;
		item["next"] = next;
		item["constructor"] = "0x4cc955";
		return item;
	};
	edges.append(edge("top", -200, -200, 400, -200, "right"));
	edges.append(edge("right", 400, -200, 400, 400, "bottom"));
	edges.append(edge("bottom", 400, 400, -200, 400, "left"));
	edges.append(edge("left", -200, 400, -200, -200, "top"));

	context["status"] = "private_context_ready";
	context["source"] = "h3maped 0x4cc788 initial source-node rectangle constants before 0x4ccb64 split insertions";
	context["initial_bounds"] = bounds;
	context["initial_edge_count"] = edges.size();
	context["initial_edges"] = edges;
	return context;
}

Dictionary private_generation_context(const Dictionary &normalized_config) {
	Dictionary context;
	context["schema_id"] = "aurelion_h3maped_small_private_generation_context_v1";
	context["schema_version"] = 1;
	context["status"] = "template_selection_only";
	context["runtime_generation_allowed"] = false;
	context["partial_materialized_payload_public_api"] = false;
	Dictionary selection = selection_identity(normalized_config);
	context["selection_identity"] = selection;
	Array completed_phases;
	if (!bool(selection.get("ok", false))) {
		context["completed_phase_ids"] = completed_phases;
		context["blocked_next"] = "template_selection";
		return context;
	}
	completed_phases.append("template_selection");
	const TemplateEvidence *selected_template = template_for_catalog_index(int32_t(selection.get("source_catalog_index", -1)));
	if (selected_template != nullptr) {
		const Dictionary player_context = player_slot_assignment_context(*selected_template, normalized_config);
		const Dictionary runtime_zone_context = runtime_zone_records_context(*selected_template, player_context);
		const Dictionary link_context = link_seed_context(*selected_template, runtime_zone_context);
		const Dictionary coordinate_context = coordinate_replay_context(normalized_config, runtime_zone_context, link_context, uint32_t(int64_t(selection.get("rng_state_after_selection_uint32", 0))));
		const Dictionary zone_footprint_context = zone_footprint_phase_context(normalized_config, runtime_zone_context, coordinate_context);
		const Dictionary source_node_rectangle = source_node_rectangle_context(zone_footprint_context);
		context["player_context"] = player_context;
		completed_phases.append("player_slot_assignment");
		context["runtime_zone_context"] = runtime_zone_context;
		if (String(runtime_zone_context.get("status", "")) == "private_context_ready") {
			completed_phases.append("runtime_zone_records");
			context["link_context"] = link_context;
			if (String(link_context.get("status", "")) == "private_context_ready") {
				completed_phases.append("link_seed_setup");
				context["coordinate_replay_context"] = coordinate_context;
				if (String(coordinate_context.get("status", "")) == "private_context_ready") {
					completed_phases.append("coordinate_replay_and_zone_footprints");
					context["zone_footprint_context"] = zone_footprint_context;
					if (String(zone_footprint_context.get("status", "")) == "private_context_ready") {
						completed_phases.append("zone_footprint_phase_boundary");
						context["source_node_rectangle"] = source_node_rectangle;
						if (String(source_node_rectangle.get("status", "")) == "private_context_ready") {
							completed_phases.append("source_node_rectangle");
							context["status"] = "source_node_rectangle_private_context_ready";
							context["blocked_next"] = "polygon_split_model_0x4ccb64_0x4ccdfc";
						} else {
							context["status"] = "zone_footprint_phase_private_context_ready";
							context["blocked_next"] = "source_node_rectangle_0x4cc788";
						}
					} else {
						context["status"] = "coordinate_replay_private_context_ready";
						context["blocked_next"] = "zone_footprint_source_nodes_0x4a3a03_0x4cc788";
					}
				} else {
					context["status"] = "link_seed_private_context_ready";
					context["blocked_next"] = "coordinate_replay_0x4a17f5_0x4a1701";
				}
			} else {
				context["status"] = "runtime_zone_records_private_context_ready";
				context["blocked_next"] = "link_seed_setup_0x4a1f3b";
			}
		} else {
			context["status"] = "player_slot_assignment_private_context_ready";
			context["blocked_next"] = "runtime_zone_records_0x4a218c";
		}
	} else {
		context["status"] = "selected_template_record_missing";
		context["blocked_next"] = "player_slot_assignment";
	}
	context["completed_phase_ids"] = completed_phases;
	context["completed_phase_count"] = completed_phases.size();
	return context;
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
		"0x4a1f3b/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed/0x4a3a03/0x4a2777/0x4a325d",
		"0x4a3f27/0x4bcff5/0x4bb74b/0x4bc5f0/0x49acf6",
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
		phase["status"] = index == 0 ? String("active_boundary_only") : (index >= 1 && index <= 3 ? String("private_context_ready") : String("pending_strict_port"));
		phase["materializes_public_output"] = false;
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
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_fresh_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_fresh_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "previous_phase_ledger_archived_out_of_build";
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
	report["private_generation_context"] = private_generation_context(normalized_config);
	report["restart_phase_backlog"] = restart_backlog();
	report["materialized_phase_status"] = "none_after_fresh_restart";
	report["blocked_before_materialization"] = "waiting_for_strict_h3maped_small_phase_ports_from_0x4ac552";
	report["explicitly_absent_reports"] = "player slots, runtime zones, coordinates, terrain, towns, roads, blockers, guards, mines, rewards, and final writeout are not exposed until implemented as generator phases";
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_fresh_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "Small h3maped-derived RMG is a fresh executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["private_generation_context"] = private_generation_context(normalized_config);
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
