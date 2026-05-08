#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cmath>
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
constexpr const char *ADAPTED_CATALOG_PATH = "res://content/random_map_template_catalog.json";

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
	int32_t border_guard_edge_count;
};

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
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

struct CoordCandidate {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

const TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, 0 },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, 0 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, 0 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, 0 },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, 0 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, 0 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, 0 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, 0 },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, 0 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, 0 },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, 0 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, 0 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, 0 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, 0 },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, 0 },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, 0 },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, 0 },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, 0 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, 0 },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, 0 },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, 0 },
};

int32_t water_mode_code(const Dictionary &normalized) {
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (water_mode == "normal_water") {
		return 1;
	}
	if (water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized) {
	const int32_t width = std::max(1, int32_t(normalized.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(normalized.get("level_count", 1)));
	int32_t score = int32_t((int64_t(width) * int64_t(height) * int64_t(level_count)) / 0x510);
	if (water_mode_code(normalized) == 2) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool parse_explicit_seed(const String &seed_text, uint32_t &seed_value) {
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
	report["verification_policy"] = "local_file_size_and_mz_header_checked; expected SHA-256 is the recorded reset anchor";
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["status"] = "missing";
		report["ok"] = false;
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["status"] = "unreadable";
		report["ok"] = false;
		return report;
	}
	const int64_t size = file->get_length();
	const int32_t byte_0 = file->get_8();
	const int32_t byte_1 = file->get_8();
	const bool mz = byte_0 == 'M' && byte_1 == 'Z';
	report["actual_size_bytes"] = size;
	report["mz_header_present"] = mz;
	report["ok"] = size == BINARY_SIZE_BYTES && mz;
	report["status"] = bool(report["ok"]) ? String("verified_reset_anchor") : String("mismatch");
	return report;
}

Dictionary load_json_dictionary(const String &path) {
	if (!FileAccess::file_exists(path)) {
		return Dictionary();
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return Dictionary();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	return Dictionary(parser->get_data());
}

bool player_filter_accepts(const Dictionary &filter, int32_t human_count, int32_t total_count) {
	return human_count >= int32_t(filter.get("min_human", 1))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& total_count >= int32_t(filter.get("min_total", 2))
			&& total_count <= int32_t(filter.get("max_total", 8));
}

int32_t scale_divisor_for_water_mode(int32_t water_mode) {
	if (water_mode == 1) {
		return 6;
	}
	if (water_mode == 2) {
		return 7;
	}
	return 5;
}

String string_at(const Array &values, int32_t index, const String &fallback = String()) {
	if (index < 0 || index >= values.size()) {
		return fallback;
	}
	return String(values[index]);
}

String terrain_for_faction(const String &faction_id) {
	if (faction_id == "faction_embercourt") {
		return "lava";
	}
	if (faction_id == "faction_thornwake") {
		return "grass";
	}
	if (faction_id == "faction_sunvault") {
		return "sand";
	}
	if (faction_id == "faction_brasshollow") {
		return "rough";
	}
	if (faction_id == "faction_veilmourn") {
		return "snow";
	}
	if (faction_id == "faction_mireclaw") {
		return "swamp";
	}
	return String();
}

Array bool_bitmap_report(const std::array<bool, 8> &bitmap) {
	Array result;
	for (bool enabled : bitmap) {
		result.append(enabled);
	}
	return result;
}

std::array<bool, 8> selected_color_bitmap_from_normalized(const Dictionary &normalized_config) {
	std::array<bool, 8> bitmap = {};
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	Array selected = constraints.get("selected_color_bitmap", Array());
	for (int32_t index = 0; index < 8 && index < selected.size(); ++index) {
		bitmap[size_t(index)] = bool(selected[index]);
	}
	return bitmap;
}

int32_t ftol_truncate(double value) {
	return int32_t(std::trunc(value));
}

int32_t distance_truncate(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return ftol_truncate(std::sqrt(double(dx * dx + dy * dy)));
}

Array coordinate_candidate_report(const std::vector<CoordCandidate> &candidates, int32_t limit = 8) {
	Array result;
	const int32_t capped = std::min<int32_t>(int32_t(candidates.size()), limit);
	for (int32_t index = 0; index < capped; ++index) {
		const CoordCandidate &candidate = candidates[size_t(index)];
		Dictionary item;
		item["x"] = candidate.x;
		item["y"] = candidate.y;
		item["level"] = candidate.level;
		result.append(item);
	}
	return result;
}

bool candidate_valid_4a1701(
		const RuntimeZoneSeed &current,
		const CoordCandidate &candidate,
		const std::vector<RuntimeZoneSeed> &zones,
		const std::vector<int32_t> &visible_runtime_indices) {
	if ((current.source_bucket == 0 || current.source_bucket == 1) && candidate.level == 1
			&& current.actual_owner_color != 3 && current.actual_owner_color != 4 && current.actual_owner_color != 5) {
		return false;
	}
	for (int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size())) {
			continue;
		}
		const RuntimeZoneSeed &other = zones[size_t(other_index)];
		if (other.source_zone_id == current.source_zone_id || other.level != candidate.level) {
			continue;
		}
		const int32_t distance = distance_truncate(candidate.x, candidate.y, other.x, other.y);
		const int32_t minimum_tenths = (other.source_base_size + current.source_base_size) * 8;
		if (distance * 10 < minimum_tenths) {
			return false;
		}
	}
	return true;
}

bool zones_connectable_49b6e2(const RuntimeZoneSeed &first, const RuntimeZoneSeed &second) {
	const int32_t distance = distance_truncate(first.x, first.y, second.x, second.y);
	const int32_t size_sum = first.source_base_size + second.source_base_size;
	if (first.level != second.level) {
		if (size_sum < distance) {
			return false;
		}
		return (size_sum - distance) > (std::min(first.source_base_size, second.source_base_size) / 2);
	}
	return size_sum * 11 >= distance * 10;
}

int32_t link_acceptance_count_4a1967(
		const RuntimeZoneSeed &current,
		const std::vector<RuntimeZoneSeed> &zones,
		const std::vector<RuntimeLinkSeed> &links) {
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

void append_angle_candidates_4a17f5(
		const RuntimeZoneSeed &base,
		const RuntimeZoneSeed &current,
		const std::vector<RuntimeZoneSeed> &zones,
		const std::vector<int32_t> &visible_runtime_indices,
		std::vector<CoordCandidate> &candidates) {
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

void prune_candidates_4a1ad8_single_level(
		const RuntimeZoneSeed &current_template,
		const std::vector<RuntimeZoneSeed> &zones,
		const std::vector<int32_t> &visible_runtime_indices,
		const std::vector<RuntimeLinkSeed> &links,
		std::vector<CoordCandidate> &candidates) {
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
	for (int32_t other_index : visible_runtime_indices) {
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

Dictionary player_slot_assignment_report(
		const std::array<bool, 8> &human_capable,
		const std::array<bool, 8> &player_capable_source,
		const std::array<bool, 8> &selected_color_bitmap,
		int32_t human_count,
		int32_t computer_count) {
	Dictionary report;
	std::array<int32_t, 9> raw_mapping = {};
	raw_mapping.fill(-1);
	std::array<bool, 8> player_capable = player_capable_source;
	std::array<int32_t, 8> color_order = {};
	int32_t order_index = 0;
	for (int32_t color = 0; color < 8; ++color) {
		if (selected_color_bitmap[size_t(color)]) {
			color_order[size_t(order_index++)] = color;
		}
	}
	for (int32_t color = 0; color < 8; ++color) {
		if (!selected_color_bitmap[size_t(color)]) {
			color_order[size_t(order_index++)] = color;
		}
	}

	Array color_order_report;
	for (int32_t color : color_order) {
		color_order_report.append(color);
	}

	Array assignments;
	int32_t assigned_count = 0;
	int32_t source_owner_scan = 0;
	bool complete = true;
	for (; assigned_count < human_count; ++assigned_count) {
		while (source_owner_scan < 8 && !human_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8) {
			complete = false;
			break;
		}
		player_capable[size_t(source_owner_scan)] = false;
		const int32_t actual_color = color_order[size_t(assigned_count)];
		raw_mapping[size_t(source_owner_scan + 1)] = actual_color;
		Dictionary assignment;
		assignment["source_owner_index"] = source_owner_scan;
		assignment["actual_player_color"] = actual_color;
		assignment["player_type"] = "human";
		assignments.append(assignment);
		++source_owner_scan;
	}

	const int32_t desired_total = human_count + computer_count;
	source_owner_scan = 0;
	for (; assigned_count < desired_total; ++assigned_count) {
		while (source_owner_scan < 8 && !player_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8) {
			complete = false;
			break;
		}
		const int32_t actual_color = color_order[size_t(assigned_count)];
		raw_mapping[size_t(source_owner_scan + 1)] = actual_color;
		Dictionary assignment;
		assignment["source_owner_index"] = source_owner_scan;
		assignment["actual_player_color"] = actual_color;
		assignment["player_type"] = "computer";
		assignments.append(assignment);
		++source_owner_scan;
	}

	Array raw_slots;
	for (int32_t value : raw_mapping) {
		raw_slots.append(value);
	}
	Array colors_by_source_owner;
	for (int32_t source_owner = 0; source_owner < 8; ++source_owner) {
		colors_by_source_owner.append(raw_mapping[size_t(source_owner + 1)]);
	}

	report["status"] = complete ? String("0x4ac62a_player_slot_assignment_ported_inspection_only") : String("0x4ac62a_player_slot_assignment_incomplete");
	report["source"] = "h3maped 0x4ac62a..0x4ac6ec using generator+0xed8 selected-color bitmap and source zone +0x04/+0x1c capability bitmaps";
	report["selected_color_bitmap_offset"] = "generator+0xed8";
	report["assignment_slots_offset"] = "generator+0xee0";
	report["mapped_slots_offset"] = "generator+0xee4";
	report["selected_color_bitmap"] = bool_bitmap_report(selected_color_bitmap);
	report["selected_color_order"] = color_order_report;
	report["raw_ee0_slots"] = raw_slots;
	report["actual_colors_by_source_owner"] = colors_by_source_owner;
	report["assignments"] = assignments;
	report["desired_human_count"] = human_count;
	report["desired_computer_count"] = computer_count;
	report["desired_total_players"] = desired_total;
	report["assigned_player_count"] = assignments.size();
	if (!complete) {
		report["blocker"] = "selected template does not expose enough human/player-capable source owner slots for requested counts";
	}
	return report;
}

Dictionary coordinate_seed_report_4a1f3b(
		const Dictionary &normalized_config,
		Array &runtime_zones,
		const Array &link_seeds,
		uint32_t rng_state_after_template_selection) {
	Dictionary report;
	report["status"] = "0x4a218c_interleaved_runtime_and_coordinate_replay_inspection_only";
	report["source"] = "h3maped 0x4a218c interleaved 0x49b452 runtime init, 0x49b3c1 town choice, 0x4a1f3b coordinate seeding, 0x4a17f5 angle candidates, 0x4a1701 spacing validation, 0x4a1ad8 single-level pruning, and 0x4a19ed bounding-box rescale";
	report["angle_table_x_address"] = "0x58dc28";
	report["angle_table_y_address"] = "0x58dd28";
	report["distance_validation_address"] = "0x4a1701";
	report["candidate_prune_address"] = "0x4a1ad8";
	report["bbox_rescale_address"] = "0x4a19ed";
	report["rng_state_before_0x4a218c_replay_uint32"] = int64_t(rng_state_after_template_selection);
	report["rng_order_status"] = "0x4a218c_interleaved_replay_ported_inspection_only";
	report["rng_order_note"] = "town-choice RNG and coordinate-choice RNG are replayed in 0x4a218c creation/refinement order; map emission remains blocked until 0x4a3a03 footprint cells and later materialization phases are ported";
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	if (level_count != 1) {
		report["status"] = "blocked_until_two_level_coordinate_port";
		report["blocked_reason"] = "this clean reset is scoped to one-level small land maps before underground branches are ported";
		return report;
	}

	std::vector<RuntimeZoneSeed> zones;
	zones.reserve(size_t(runtime_zones.size()));
	for (int64_t index = 0; index < runtime_zones.size(); ++index) {
		if (Variant(runtime_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[index]);
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(runtime.get("runtime_zone_index", index));
		zone.source_zone_id = int32_t(runtime.get("source_zone_id", index));
		zone.source_bucket = int32_t(runtime.get("source_bucket", -1));
		zone.source_owner_index = int32_t(runtime.get("source_owner_index", -1));
		zone.actual_owner_color = int32_t(runtime.get("actual_owner_color", -1));
		zone.source_base_size = int32_t(runtime.get("source_base_size", 0));
		zone.scaled_size = zone.source_base_size;
		zones.push_back(zone);
	}

	std::vector<RuntimeLinkSeed> links;
	links.reserve(size_t(link_seeds.size()));
	for (int64_t index = 0; index < link_seeds.size(); ++index) {
		if (Variant(link_seeds[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(link_seeds[index]);
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
	int32_t rng_calls = 0;
	int32_t town_rng_calls = 0;
	bool complete = true;

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= runtime_zones.size()
				|| Variant(runtime_zones[zone_index]).get_type() != Variant::DICTIONARY) {
			return;
		}
		Dictionary runtime = Dictionary(runtime_zones[zone_index]);
		String faction_id = String(runtime.get("faction_id", ""));
		if (faction_id.is_empty()) {
			Array allowed_factions = runtime.get("allowed_faction_ids_for_49b3c1", Array());
			if (!allowed_factions.is_empty()) {
				const int32_t rng_value = rng.next();
				const int32_t town_choice_index = rng_value % int32_t(allowed_factions.size());
				faction_id = string_at(allowed_factions, town_choice_index);
				runtime["faction_id"] = faction_id;
				runtime["town_choice_index"] = town_choice_index;
				runtime["faction_source"] = "0x49b3c1 adapted allowed_faction_ids choice";
				town_rng_calls += 1;
				Dictionary event;
				event["consumer"] = "0x49b3c1";
				event["runtime_zone_index"] = zone_index;
				event["value"] = rng_value;
				event["modulus"] = allowed_factions.size();
				event["selected_index"] = town_choice_index;
				rng_events.append(event);
			}
		}
		if (bool(runtime.get("terrain_match_to_faction", false)) && !faction_id.is_empty()) {
			runtime["terrain_id"] = terrain_for_faction(faction_id);
			runtime["terrain_source"] = "terrain table preview after 0x49b3c1; authoritative 0x49b53d terrain phase still pending";
		}
		runtime_zones[zone_index] = runtime;
	};

	auto place_zone = [&](int32_t zone_index, const String &pass_id, const std::vector<int32_t> &visible_runtime_indices) {
		std::vector<CoordCandidate> candidates;
		Dictionary step;
		step["pass"] = pass_id;
		step["runtime_zone_index"] = zone_index;
		step["runtime_vector_count_before_call"] = int32_t(visible_runtime_indices.size());
		Array visible_report;
		for (int32_t visible_index : visible_runtime_indices) {
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
				for (int32_t other_index : visible_runtime_indices) {
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
		rng_calls += 1;
		const int32_t selected_index = rng_value % int32_t(candidates.size());
		const CoordCandidate selected = candidates[size_t(selected_index)];
		zones[size_t(zone_index)].x = selected.x;
		zones[size_t(zone_index)].y = selected.y;
		zones[size_t(zone_index)].level = selected.level;
		step["rng_value"] = rng_value;
		Dictionary event;
		event["consumer"] = "0x4a1f3b_candidate_selection";
		event["runtime_zone_index"] = zone_index;
		event["pass"] = pass_id;
		event["value"] = rng_value;
		event["modulus"] = candidates.size();
		event["selected_index"] = selected_index;
		rng_events.append(event);
		step["selected_candidate_index"] = selected_index;
		Dictionary selected_report;
		selected_report["x"] = selected.x;
		selected_report["y"] = selected.y;
		selected_report["level"] = selected.level;
		step["selected_candidate"] = selected_report;
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
	const int32_t map_span = std::min(int32_t(normalized_config.get("width", 0)), int32_t(normalized_config.get("height", 0)));
	const int32_t offset_y = (min_y - bbox_span + max_y) / 2;
	const int32_t offset_x = (min_x - bbox_span + max_x) / 2;
	Array scaled_zone_coordinates;
	for (RuntimeZoneSeed &zone : zones) {
		if (bbox_span > 0) {
			zone.x = ((zone.x - offset_x) * map_span) / bbox_span;
			zone.y = ((zone.y - offset_y) * map_span) / bbox_span;
			zone.scaled_size = (zone.source_base_size * map_span) / bbox_span;
		} else {
			zone.scaled_size = zone.source_base_size;
		}
		Dictionary item;
		item["runtime_zone_index"] = zone.runtime_index;
		item["x_after_bbox_rescale"] = zone.x;
		item["y_after_bbox_rescale"] = zone.y;
		item["level"] = zone.level;
		item["runtime_size_after_bbox_rescale"] = zone.scaled_size;
		scaled_zone_coordinates.append(item);
		if (zone.runtime_index >= 0 && zone.runtime_index < runtime_zones.size()
				&& Variant(runtime_zones[zone.runtime_index]).get_type() == Variant::DICTIONARY) {
			Dictionary runtime = Dictionary(runtime_zones[zone.runtime_index]);
			runtime["x_after_bbox_rescale"] = zone.x;
			runtime["y_after_bbox_rescale"] = zone.y;
			runtime["level"] = zone.level;
			runtime["runtime_size_after_bbox_rescale"] = zone.scaled_size;
			runtime["rectangle_status"] = "pending_0x4a3a03_footprint_placement_after_coordinate_seed";
			runtime_zones[zone.runtime_index] = runtime;
		}
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
	report["ok"] = complete;
	report["placement_step_count"] = placement_steps.size();
	report["placement_steps"] = placement_steps;
	report["town_rng_calls_during_0x49b452"] = town_rng_calls;
	report["coordinate_rng_calls_during_0x4a1f3b"] = rng_calls;
	report["rng_event_count"] = rng_events.size();
	report["rng_events"] = rng_events;
	report["rng_state_after_0x4a218c_replay_uint32"] = int64_t(rng.state);
	report["bounding_box_rescale"] = bbox;
	report["scaled_zone_coordinates"] = scaled_zone_coordinates;
	report["next_materialization_status"] = "pending_clean_port_0x4a3a03_0x4a2777_0x4a325d_0x4a3710";
	return report;
}

Dictionary zone_footprint_phase_4a3a03_report(const Dictionary &normalized_config, Array &runtime_zones, int64_t rng_state_after_coordinate_seed) {
	Dictionary report;
	report["status"] = "0x4a3a03_level_collection_and_polygon_seed_ported_helpers_pending";
	report["source"] = "h3maped 0x4a3a03 per-level runtime-zone collection, small-land synthetic branch decision, 0x4cc788 polygon seed setup, and 0x4ccb64 split-call scheduling";
	report["function_address"] = "0x4a3a03";
	report["zone_collection_address"] = "0x4a3a2b..0x4a3a86";
	report["synthetic_source_zone_branch_address"] = "0x4a3a9d..0x4a3e12";
	report["polygon_constructor_address"] = "0x4cc788";
	report["polygon_split_address"] = "0x4ccb64";
	report["polygon_finalize_address"] = "0x4ccdfc";
	report["first_helper_address"] = "0x4a2777";
	report["second_helper_address"] = "0x4a325d";
	report["finalizer_address"] = "0x4a3710";
	report["rng_state_before_footprint_phase_uint32"] = rng_state_after_coordinate_seed;
	report["cell_materialization_status"] = "pending_clean_port_0x4a2777_0x4a325d_0x4a3710";
	report["blocked_next"] = "execute 0x4a2777 boundary traversal and 0x4a325d span fill before any project terrain/object materialization";

	Dictionary synthetic_defaults;
	synthetic_defaults["+0x04"] = 3;
	synthetic_defaults["+0x1c"] = -1;
	synthetic_defaults["+0xa0"] = 100;
	synthetic_defaults["+0xa4"] = 1000;
	synthetic_defaults["+0xa8"] = 5;
	synthetic_defaults["+0xac"] = 2000;
	synthetic_defaults["+0xb0"] = 6000;
	synthetic_defaults["+0xb4"] = 1;
	report["synthetic_source_zone_size"] = "0xd4";
	report["synthetic_source_zone_defaults"] = synthetic_defaults;

	Dictionary polygon_seed;
	polygon_seed["status"] = "0x4cc788_initial_bounds_and_0x4ccb64_split_calls_scheduled";
	Dictionary bounds;
	bounds["min_x"] = -200;
	bounds["min_y"] = -200;
	bounds["max_x"] = 400;
	bounds["max_y"] = 400;
	bounds["source"] = "0x4cc788 constants 0xffffff38 and 0x190";
	polygon_seed["initial_bounds"] = bounds;
	Array initial_edges;
	auto append_edge = [&](int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y) {
		Dictionary edge;
		edge["from_x"] = from_x;
		edge["from_y"] = from_y;
		edge["to_x"] = to_x;
		edge["to_y"] = to_y;
		edge["payload"] = 0;
		initial_edges.append(edge);
	};
	append_edge(-200, -200, 400, -200);
	append_edge(400, -200, 400, 400);
	append_edge(400, 400, -200, 400);
	append_edge(-200, 400, -200, -200);
	polygon_seed["initial_edges"] = initial_edges;
	polygon_seed["initial_edge_count"] = initial_edges.size();

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	Array levels;
	int32_t total_matching_runtime_zones = 0;
	int32_t total_split_calls = 0;
	int32_t appended_synthetic_runtime_zones = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		Array matching_indices;
		Array split_calls;
		for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
			if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
			if (int32_t(runtime.get("level", 0)) != level) {
				continue;
			}
			matching_indices.append(runtime.get("runtime_zone_index", runtime_index));
			Dictionary split_call;
			split_call["call_site_address"] = "0x4a3a79";
			split_call["runtime_zone_index"] = runtime.get("runtime_zone_index", runtime_index);
			split_call["source_zone_id"] = runtime.get("source_zone_id", -1);
			split_call["x"] = runtime.get("x_after_bbox_rescale", 0);
			split_call["y"] = runtime.get("y_after_bbox_rescale", 0);
			split_call["level"] = level;
			split_call["payload"] = "runtime_zone_pointer";
			split_call["source_fields"] = "runtime_zone+0x10 x/y copied after 0x4a19ed rescale, then pushed to 0x4ccb64";
			split_calls.append(split_call);

			runtime["footprint_collection_status"] = "0x4a3a03_collected_for_level";
			runtime["polygon_split_seed_index"] = split_calls.size() - 1;
			runtime["rectangle_status"] = "pending_0x4a2777_0x4a325d_0x4a3710_cell_materialization";
			runtime_zones[runtime_index] = runtime;
		}
		total_matching_runtime_zones += matching_indices.size();
		total_split_calls += split_calls.size();
		const bool synthetic_branch_allowed = level == 1 || water_code != 0;
		Dictionary level_report;
		level_report["level_index"] = level;
		level_report["matching_runtime_zone_count"] = matching_indices.size();
		level_report["matching_runtime_zone_indices"] = matching_indices;
		level_report["synthetic_fallback_zone_allowed_by_0x4a3a9d"] = synthetic_branch_allowed;
		level_report["synthetic_fallback_zone_created"] = false;
		level_report["synthetic_fallback_zone_reason"] = synthetic_branch_allowed
				? String("requires 0x4a3b48 direction scan before source-zone allocation")
				: String("skipped because level != 1 and water mode is land, matching 0x4a3a9d..0x4a3aa9");
		Array helper_sequence;
		helper_sequence.append("0x4a2777");
		helper_sequence.append("0x4a325d");
		helper_sequence.append("0x4a3710");
		level_report["helper_call_sequence"] = helper_sequence;
		level_report["helper_call_status"] = "scheduled_not_executed";
		level_report["polygon_split_call_count"] = split_calls.size();
		level_report["polygon_split_calls"] = split_calls;
		levels.append(level_report);
	}

	polygon_seed["levels"] = levels;
	polygon_seed["materialized_primary_split_seed_count"] = total_split_calls;
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["total_matching_runtime_zones"] = total_matching_runtime_zones;
	report["total_polygon_split_calls"] = total_split_calls;
	report["appended_synthetic_runtime_zone_count"] = appended_synthetic_runtime_zones;
	report["levels"] = levels;
	report["polygon_seed_evidence"] = polygon_seed;
	return report;
}

Dictionary runtime_zone_build_report(
		const Dictionary &normalized_config,
		const Array &active_zones,
		const Array &active_links,
		const Dictionary &assignment,
		uint32_t rng_state_after_template_selection) {
	Dictionary report;
	const int32_t width = std::max(1, int32_t(normalized_config.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized_config.get("height", 36)));
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t divisor = scale_divisor_for_water_mode(water_code);
	int32_t min_base_size = 0x7d00;
	Dictionary runtime_index_by_source_zone_id;
	for (int64_t index = 0; index < active_zones.size(); ++index) {
		if (Variant(active_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(active_zones[index]);
		min_base_size = std::min(min_base_size, int32_t(zone.get("base_size", 0x7d00)));
		runtime_index_by_source_zone_id[String::num_int64(int64_t(zone.get("source_zone_id", index)))] = index;
	}
	if (min_base_size == 0x7d00) {
		min_base_size = 0;
	}

	const int32_t scale_reference = divisor > 0 ? std::min(min_base_size * width, min_base_size * height) / divisor : 0;
	H3MapedRng rng { rng_state_after_template_selection };
	Array rng_events;
	Array runtime_zones;
	Array colors_by_source_owner = assignment.get("actual_colors_by_source_owner", Array());
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	Array selected_factions = constraints.get("selected_faction_ids", Array());

	for (int64_t index = 0; index < active_zones.size(); ++index) {
		if (Variant(active_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(active_zones[index]);
		Dictionary ownership = zone.get("ownership", Dictionary());
		const int32_t source_owner_index = int32_t(ownership.get("source_owner_index", -1));
		int32_t actual_owner_color = -1;
		if (source_owner_index >= 0 && source_owner_index < colors_by_source_owner.size()) {
			actual_owner_color = int32_t(colors_by_source_owner[source_owner_index]);
		}

		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Array allowed_factions = town_policy.get("allowed_faction_ids", Array());
		int32_t town_choice_index = -1;
		String faction_id;
		String faction_source = "0x49b3c1_no_allowed_town_choice";
		if (actual_owner_color >= 0 && actual_owner_color < selected_factions.size() && !String(selected_factions[actual_owner_color]).is_empty()) {
			faction_id = String(selected_factions[actual_owner_color]);
			faction_source = "generator+0xf24 adapted from player_constraints.selected_faction_ids";
		} else if (!allowed_factions.is_empty()) {
			faction_source = "pending_0x49b3c1_interleaved_runtime_initializer";
		}

		Dictionary terrain = zone.get("terrain", Dictionary());
		String terrain_id;
		String terrain_source = "pending_0x4a3f27_terrain_phase";
		if (bool(terrain.get("match_to_faction", false)) && !faction_id.is_empty()) {
			terrain_id = terrain_for_faction(faction_id);
			terrain_source = "terrain table preview from fixed selected faction; authoritative 0x49b53d terrain phase still pending";
		}

		Dictionary runtime;
		runtime["runtime_zone_index"] = index;
		runtime["source_zone_id"] = zone.get("source_zone_id", index);
		runtime["source_zone_key"] = zone.get("id", "");
		runtime["source_pointer_offset"] = "runtime+0x00";
		runtime["runtime_town_choice_offset"] = "runtime+0x04";
		runtime["runtime_terrain_offset"] = "runtime+0x0c";
		runtime["runtime_size_offset"] = "runtime+0x1c";
		runtime["runtime_byte_3c_offset"] = "runtime+0x3c";
		runtime["role"] = zone.get("role", zone.get("type", ""));
		runtime["source_bucket"] = Dictionary(zone.get("grammar_source", Dictionary())).get("source_bucket", -1);
		runtime["source_owner_index"] = source_owner_index;
		runtime["actual_owner_color"] = actual_owner_color;
		runtime["source_base_size"] = zone.get("base_size", 0);
		runtime["runtime_initial_size_before_rescale"] = zone.get("base_size", 0);
		runtime["runtime_byte_3c"] = 0;
		runtime["faction_id"] = faction_id;
		runtime["town_choice_index"] = town_choice_index;
		runtime["faction_source"] = faction_source;
		runtime["allowed_faction_ids_for_49b3c1"] = allowed_factions;
		runtime["terrain_id"] = terrain_id;
		runtime["terrain_source"] = terrain_source;
		runtime["terrain_match_to_faction"] = bool(terrain.get("match_to_faction", false));
		runtime["rectangle_status"] = "pending_0x4a1f3b_0x4a17f5_link_seed_and_0x4a3a03_footprint_placement";
		runtime_zones.append(runtime);
	}

	Array link_seeds;
	Array adjacency;
	for (int64_t index = 0; index < runtime_zones.size(); ++index) {
		adjacency.append(Array());
	}
	for (int64_t index = 0; index < active_links.size(); ++index) {
		if (Variant(active_links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(active_links[index]);
		Dictionary endpoints = link.get("source_endpoints", Dictionary());
		const String from_id = String::num_int64(int64_t(endpoints.get("zone1", -1)));
		const String to_id = String::num_int64(int64_t(endpoints.get("zone2", -1)));
		Dictionary seed;
		seed["link_index"] = index;
		seed["source_endpoint_a"] = endpoints.get("zone1", -1);
		seed["source_endpoint_b"] = endpoints.get("zone2", -1);
		seed["runtime_zone_a"] = runtime_index_by_source_zone_id.get(from_id, -1);
		seed["runtime_zone_b"] = runtime_index_by_source_zone_id.get(to_id, -1);
		seed["guard_value"] = link.get("guard_value", Dictionary(link.get("guard", Dictionary())).get("value", 0));
		seed["wide"] = bool(link.get("wide", false));
		seed["border_guard"] = bool(link.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b uses endpoint pointers only; payload is preserved for later guard/link consumers";
		link_seeds.append(seed);

		const int32_t runtime_a = int32_t(seed.get("runtime_zone_a", -1));
		const int32_t runtime_b = int32_t(seed.get("runtime_zone_b", -1));
		if (runtime_a >= 0 && runtime_a < adjacency.size() && runtime_b >= 0 && runtime_b < adjacency.size()) {
			Array links_a = adjacency[runtime_a];
			links_a.append(runtime_b);
			adjacency[runtime_a] = links_a;
			Array links_b = adjacency[runtime_b];
			links_b.append(runtime_a);
			adjacency[runtime_b] = links_b;
		}
	}

	Array placement_calls;
	int32_t explicit_endpoint_attempts = 0;
	int32_t fallback_attempts_if_no_valid_endpoint = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		Array available_links;
		Array linked = runtime_index < adjacency.size() ? Array(adjacency[runtime_index]) : Array();
		for (int64_t link_index = 0; link_index < linked.size(); ++link_index) {
			const int32_t linked_runtime = int32_t(linked[link_index]);
			if (linked_runtime >= 0 && linked_runtime < runtime_index) {
				available_links.append(linked_runtime);
			}
		}
		explicit_endpoint_attempts += available_links.size();
		if (available_links.is_empty()) {
			fallback_attempts_if_no_valid_endpoint += int32_t(runtime_index);
		}
		Dictionary call;
		call["pass"] = "creation";
		call["runtime_zone_index"] = runtime_index;
		call["runtime_vector_count_before_call"] = runtime_index;
		call["available_endpoint_runtime_zones"] = available_links;
		call["fallback_candidate_count_if_no_valid_endpoint"] = available_links.is_empty() ? runtime_index : 0;
		call["coordinate_status"] = "pending_0x4a17f5_candidate_math_and_0x4a1701_validation";
		placement_calls.append(call);
	}
	for (int32_t repeat = 0; repeat < 2; ++repeat) {
		for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
			Array available_links;
			Array linked = runtime_index < adjacency.size() ? Array(adjacency[runtime_index]) : Array();
			for (int64_t link_index = 0; link_index < linked.size(); ++link_index) {
				const int32_t linked_runtime = int32_t(linked[link_index]);
				if (linked_runtime >= 0 && linked_runtime < runtime_zones.size()) {
					available_links.append(linked_runtime);
				}
			}
			explicit_endpoint_attempts += available_links.size();
			if (available_links.is_empty()) {
				fallback_attempts_if_no_valid_endpoint += int32_t(runtime_zones.size());
			}
			Dictionary call;
			call["pass"] = repeat == 0 ? String("stabilization_1") : String("stabilization_2");
			call["runtime_zone_index"] = runtime_index;
			call["runtime_vector_count_before_call"] = runtime_zones.size();
			call["available_endpoint_runtime_zones"] = available_links;
			call["fallback_candidate_count_if_no_valid_endpoint"] = available_links.is_empty() ? runtime_zones.size() : 0;
			call["coordinate_status"] = "pending_0x4a17f5_candidate_math_and_0x4a1701_validation";
			placement_calls.append(call);
		}
	}

	Dictionary early_link_placement;
	early_link_placement["status"] = "0x4a1f3b_endpoint_control_flow_ported_inspection_only";
	early_link_placement["source"] = "h3maped 0x4a1f3b walks source zone +0xc8..+0xcc endpoint records, then falls back to all existing runtime zones if no coordinate candidates survive";
	early_link_placement["payload_policy"] = "link value/wide/border_guard are not consumed by 0x4a1f3b/0x4a17f5; they are preserved for later 0x4a79a3 connection guard consumers";
	early_link_placement["creation_pass_count"] = runtime_zones.size();
	early_link_placement["stabilization_pass_count"] = 2;
	early_link_placement["call_count"] = placement_calls.size();
	early_link_placement["explicit_endpoint_attempt_count"] = explicit_endpoint_attempts;
	early_link_placement["fallback_attempt_count_if_no_valid_endpoint"] = fallback_attempts_if_no_valid_endpoint;
	early_link_placement["calls"] = placement_calls;
	Dictionary coordinate_seed = coordinate_seed_report_4a1f3b(normalized_config, runtime_zones, link_seeds, rng_state_after_template_selection);
	early_link_placement["coordinate_candidate_status"] = coordinate_seed.get("status", "");
	Dictionary zone_footprint = zone_footprint_phase_4a3a03_report(
			normalized_config,
			runtime_zones,
			int64_t(coordinate_seed.get("rng_state_after_0x4a218c_replay_uint32", int64_t(rng_state_after_template_selection))));

	report["status"] = "0x4a218c_runtime_zone_records_ported_inspection_only";
	report["source"] = "h3maped 0x4a218c with interleaved 0x49b452 runtime initializer, 0x49b3c1 town choice, and 0x4a1f3b coordinate replay";
	report["runtime_zone_vector_offset"] = "generator+0x10e0/+0x10e4/+0x10e8";
	report["vector_clear_status"] = "0x42bde9_semantics_represented_by_rebuilt_report_array";
	report["water_mode_code"] = water_code;
	report["scale_divisor"] = divisor;
	report["min_source_base_size"] = min_base_size;
	report["initial_scale_reference"] = scale_reference;
	report["scale_formula"] = "min(min_source_base_size * width, min_source_base_size * height) / divisor(land=5, normal_water=6, islands=7)";
	report["runtime_zone_count"] = runtime_zones.size();
	report["runtime_zones"] = runtime_zones;
	report["link_seed_count"] = link_seeds.size();
	report["link_seeds"] = link_seeds;
	report["early_link_placement_status"] = early_link_placement.get("status", "");
	report["early_link_placement"] = early_link_placement;
	report["rng_state_after_runtime_zone_build"] = coordinate_seed.get("rng_state_after_0x4a218c_replay_uint32", int64_t(rng_state_after_template_selection));
	report["rng_events"] = coordinate_seed.get("rng_events", rng_events);
	report["coordinate_placement_status"] = coordinate_seed.get("status", "");
	report["coordinate_seed"] = coordinate_seed;
	report["zone_footprint_placement_status"] = zone_footprint.get("status", "");
	report["zone_footprint_placement"] = zone_footprint;
	return report;
}

Dictionary adapted_template_for_source_index(int32_t source_catalog_index) {
	Dictionary catalog = load_json_dictionary(ADAPTED_CATALOG_PATH);
	Array templates = catalog.get("templates", Array());
	const int32_t imported_source_index = source_catalog_index + 1;
	for (int64_t index = 0; index < templates.size(); ++index) {
		if (Variant(templates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = Dictionary(templates[index]);
		Dictionary provenance = candidate.get("import_provenance", Dictionary());
		if (int32_t(provenance.get("source_template_index", -1)) == imported_source_index) {
			return candidate;
		}
	}
	return Dictionary();
}

Dictionary selected_template_payload(const Dictionary &template_record, const Dictionary &normalized_config, int32_t source_catalog_index, int32_t human_count, int32_t player_count, uint32_t rng_state_after_template_selection) {
	Dictionary payload;
	payload["source"] = "adapted project catalog resolved by import_provenance.source_template_index";
	payload["source_catalog_index_zero_based"] = source_catalog_index;
	payload["imported_source_template_index_one_based"] = source_catalog_index + 1;
	if (template_record.is_empty()) {
		payload["status"] = "adapted_template_not_found";
		return payload;
	}
	Array active_zones;
	Array active_links;
	Array human_capable_owner_indices;
	Array player_capable_owner_indices;
	std::array<bool, 8> human_capable = {};
	std::array<bool, 8> player_capable = {};
	int32_t player_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	Array zones = template_record.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(zones[index]);
		if (!player_filter_accepts(zone.get("player_filter", Dictionary()), human_count, player_count)) {
			continue;
		}
		const String role = String(zone.get("role", zone.get("type", "")));
		if (role == "human_start" || role == "computer_start") {
			player_start_zone_count += 1;
		}
		if (role == "treasure") {
			treasure_zone_count += 1;
		}
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		minimum_player_castles += int32_t(player_towns.get("min_castles", 0));
		Dictionary ownership = zone.get("ownership", Dictionary());
		const int32_t source_owner_index = int32_t(ownership.get("source_owner_index", -1));
		Dictionary grammar_source = zone.get("grammar_source", Dictionary());
		const int32_t source_bucket = int32_t(grammar_source.get("source_bucket", -1));
		if (source_owner_index >= 0 && source_bucket == 0) {
			human_capable_owner_indices.append(source_owner_index);
			player_capable_owner_indices.append(source_owner_index);
			if (source_owner_index < 8) {
				human_capable[size_t(source_owner_index)] = true;
				player_capable[size_t(source_owner_index)] = true;
			}
		} else if (source_owner_index >= 0 && source_bucket == 1) {
			player_capable_owner_indices.append(source_owner_index);
			if (source_owner_index < 8) {
				player_capable[size_t(source_owner_index)] = true;
			}
		}
		active_zones.append(zone);
	}
	Array links = template_record.get("links", Array());
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = Dictionary(links[index]);
		if (player_filter_accepts(link.get("player_filter", Dictionary()), human_count, player_count)) {
			active_links.append(link);
		}
	}
	payload["status"] = "adapted_template_found";
	payload["adapted_template_id"] = String(template_record.get("id", ""));
	payload["zone_count"] = active_zones.size();
	payload["link_count"] = active_links.size();
	payload["player_start_zone_count"] = player_start_zone_count;
	payload["treasure_zone_count"] = treasure_zone_count;
	payload["minimum_player_castles_before_assignment"] = minimum_player_castles;
	payload["human_capable_source_owner_indices"] = human_capable_owner_indices;
	payload["player_capable_source_owner_indices"] = player_capable_owner_indices;
	const int32_t computer_count = std::max(0, player_count - human_count);
	Dictionary assignment = player_slot_assignment_report(human_capable, player_capable, selected_color_bitmap_from_normalized(normalized_config), human_count, computer_count);
	payload["assignment_status"] = assignment.get("status", "");
	payload["player_slot_assignment"] = assignment;
	Dictionary runtime_zones = runtime_zone_build_report(normalized_config, active_zones, active_links, assignment, rng_state_after_template_selection);
	payload["runtime_zone_build_status"] = runtime_zones.get("status", "");
	payload["runtime_zone_build"] = runtime_zones;
	payload["zones"] = active_zones;
	payload["links"] = active_links;
	return payload;
}

Array clean_phase_ledger() {
	Array phases;
	struct Phase {
		const char *id;
		const char *address;
		const char *status;
	};
	const Phase PHASES[] = {
		{ "template_selection", "0x49f0cd, 0x4ac597..0x4ac5a4, 0x4e7276", "ported_inspection_only" },
		{ "player_slot_assignment", "0x4ac62a..0x4ac6ec", "ported_inspection_only" },
		{ "runtime_zone_build", "0x4a218c, 0x4a1f3b, 0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed, 0x49b452, 0x49b3c1", "ported_interleaved_runtime_and_coordinate_replay_inspection_only" },
		{ "zone_footprint_placement", "0x4a3a03, 0x4cc788, 0x4ccb64, 0x4a2777, 0x4a325d, 0x4a3710", "ported_level_collection_and_polygon_seed_inspection_only_helpers_pending" },
		{ "terrain_fill_repaint", "0x4a3f27, 0x4bcff5, 0x4bd099", "pending_clean_port" },
		{ "object_category_placement", "0x4a8d2c, 0x4a8db2, 0x4a8c15", "pending_clean_port" },
		{ "guard_reward_monster_placement", "0x4a9d6a, 0x4aab7e", "pending_clean_port" },
		{ "final_cell_object_passes", "0x49eb8d, 0x4ab52a, 0x4ac4ae", "pending_clean_port" },
	};
	for (const Phase &phase : PHASES) {
		Dictionary record;
		record["phase_id"] = phase.id;
		record["h3maped_address"] = phase.address;
		record["status"] = phase.status;
		phases.append(record);
	}
	return phases;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return int32_t(normalized_config.get("width", 0)) == 36
			&& int32_t(normalized_config.get("height", 0)) == 36
			&& int32_t(normalized_config.get("level_count", 1)) == 1
			&& String(normalized_config.get("water_mode", "land")) == "land";
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
	const int32_t score = size_score(normalized_config);
	const bool supported = supports_scope(normalized_config);
	Array accepted_templates;
	if (supported) {
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (score < candidate.min_size_score || score > candidate.max_size_score) {
				continue;
			}
			if (human_count < candidate.min_humans || human_count > candidate.max_humans
					|| player_count < candidate.min_total_players || player_count > candidate.max_total_players
					|| player_count < human_count) {
				continue;
			}
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
			item["border_guard_edge_count"] = candidate.border_guard_edge_count;
			accepted_templates.append(item);
		}
	}

	Dictionary report;
	report["ok"] = supported && accepted_templates.size() > 0;
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_clean_restart_v1";
	report["schema_version"] = 1;
	report["status"] = supported ? (accepted_templates.is_empty() ? String("h3maped_small_no_accepted_templates") : String("h3maped_small_clean_restart_template_selection_ready")) : String("unsupported_scope");
	report["scope"] = "small_36x36_surface_land_only";
	report["archive_status"] = "previous_native_catalog_auto_generator_archived_debug_only";
	report["implementation_policy"] = "no_hash_selection_no_sample_count_fitting_no_project_fallback_maps";
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["catalog_path"] = CATALOG_SOURCE_PATH;
	report["adapted_catalog_path"] = ADAPTED_CATALOG_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = score;
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["human_count"] = human_count;
	report["computer_count"] = computer_count;
	report["player_count"] = player_count;
	report["accepted_template_count"] = accepted_templates.size();
	report["accepted_templates"] = accepted_templates;
	report["phase_ledger"] = clean_phase_ledger();
	report["generation_phase_status"] = "blocked_until_clean_h3maped_phase_ports_materialize_map_cells";
	report["runtime_generation_allowed"] = false;
	report["normalized_config"] = normalized_config;

	uint32_t seed_value = 0;
	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	if (supported && !accepted_templates.is_empty() && parse_explicit_seed(seed_text, seed_value)) {
		const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
		const int32_t rng_value = int32_t((next_state >> 16U) & 0x7fffu);
		const int32_t selected_index = rng_value % int32_t(accepted_templates.size());
		Dictionary selected_template = accepted_templates[selected_index];
		const int32_t source_catalog_index = int32_t(selected_template.get("source_catalog_index", -1));
		Dictionary rng;
		rng["function_address"] = "0x4e7276";
		rng["seed_setter_address"] = "0x4e7269";
		rng["algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
		rng["seed_text"] = seed_text;
		rng["seed_value_uint32"] = int64_t(seed_value);
		rng["first_state_uint32"] = int64_t(next_state);
		rng["first_value"] = rng_value;
		rng["selected_vector_index"] = selected_index;
		report["selected_template_status"] = "h3maped_rng_selected";
		report["selected_template_vector_index"] = selected_index;
		report["selected_template"] = selected_template;
		report["h3maped_rng"] = rng;
		report["selected_template_payload"] = selected_template_payload(adapted_template_for_source_index(source_catalog_index), normalized_config, source_catalog_index, human_count, player_count, next_state);
	} else if (supported && !accepted_templates.is_empty()) {
		Dictionary rng;
		rng["function_address"] = "0x4e7276";
		rng["seed_setter_address"] = "0x4e7269";
		rng["blocked_reason"] = "h3maped seed must be numeric; no replacement hash is allowed";
		report["selected_template_status"] = "blocked_until_numeric_h3maped_seed";
		report["h3maped_rng"] = rng;
	} else {
		report["selected_template_status"] = "none";
	}
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The archived native catalog-auto generator is disabled. The replacement is a clean small-map h3maped-derived path; it will not emit fallback maps until the executable phase ports can materialize terrain, towns, roads, blockers, guards, mines, and rewards.";
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
	result["full_generation_status"] = "archived_current_native_rmg_replaced_by_small_h3maped_port";
	result["error_code"] = "archived_legacy_native_rmg_disabled";
	result["message"] = "The previous native catalog-auto RMG path is archived as debug-only evidence. Production RMG work must use the small h3maped-derived port.";
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["native_rmg_archive_status"] = "archived_legacy_catalog_auto_debug_only";
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["h3maped_binary_path"] = BINARY_PATH;
	result["h3maped_binary_sha256"] = BINARY_SHA256;
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
