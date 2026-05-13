#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
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
	int32_t border_guard_edge_count;
	const char *adapted_template_id;
	uint8_t human_capable_source_owner_mask;
	uint8_t player_capable_source_owner_mask;
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

struct ClipBounds {
	int32_t min_x = 0;
	int32_t min_y = 0;
	int32_t max_x = 0;
	int32_t max_y = 0;
};

struct ClipResult {
	int32_t x = 0;
	int32_t y = 0;
	bool input_inside = false;
	const char *branch = "";
};

struct LineWriteResult {
	int32_t write_count = 0;
	int32_t unique_cell_count = 0;
	int32_t out_of_bounds_write_count = 0;
	int32_t reserved_flag_write_count = 0;
	Array trace_preview;
};

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD = 0x00ff0000U;
constexpr uint32_t H3MAPED_ZONE_WORD_CLEAR_MASK = 0xff00ffffU;

const TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, 0, "", 0xff, 0xff },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, 0, "", 0x03, 0x03 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, 0, "", 0x03, 0x03 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, 0, "", 0x0f, 0x0f },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, 0, "", 0x03, 0x03 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, 0, "", 0x03, 0x03 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, 0, "", 0x03, 0x03 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, 0, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, 0, "", 0x03, 0x03 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, 0, "", 0x0f, 0x0f },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, 0, "", 0x03, 0x03 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, 0, "", 0x03, 0x03 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, 0, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, 0, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, 0, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, 0, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, 0, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, 0, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, 0, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, 0, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, 0, "", 0x3f, 0x7f },
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

bool parse_numeric_h3maped_seed(const String &seed_text, uint32_t &seed_value) {
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

Dictionary template_to_dictionary(const TemplateEvidence &candidate) {
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
	item["adapted_template_id"] = candidate.adapted_template_id;
	item["human_capable_source_owner_mask"] = candidate.human_capable_source_owner_mask;
	item["player_capable_source_owner_mask"] = candidate.player_capable_source_owner_mask;
	return item;
}

Array mask_indices(uint8_t mask) {
	Array indices;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & (1U << index)) != 0) {
			indices.append(index);
		}
	}
	return indices;
}

Array bool_bitmap_report(const std::array<bool, 8> &bitmap) {
	Array report;
	for (bool value : bitmap) {
		report.append(value);
	}
	return report;
}

std::array<bool, 8> bool_bitmap_from_mask(uint8_t mask) {
	std::array<bool, 8> bitmap = {};
	for (int32_t index = 0; index < 8; ++index) {
		bitmap[size_t(index)] = (mask & (1U << index)) != 0;
	}
	return bitmap;
}

std::array<bool, 8> selected_color_bitmap_from_config(const Dictionary &normalized_config) {
	std::array<bool, 8> bitmap = {};
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	Array selected = constraints.get("selected_color_bitmap", Array());
	for (int32_t index = 0; index < 8 && index < selected.size(); ++index) {
		bitmap[size_t(index)] = bool(selected[index]);
	}
	return bitmap;
}

int64_t h3maped_cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (int64_t(level) * int64_t(height) + int64_t(y)) * int64_t(width) + int64_t(x);
}

ClipResult h3maped_clip_point_4a2b33(int32_t x1, int32_t y1, int32_t x2, int32_t y2, const ClipBounds &bounds) {
	ClipResult result;
	result.x = x1;
	result.y = y1;
	result.branch = "0x4a2b5d_fallback_current";
	if (x1 >= bounds.min_x && x1 < bounds.max_x && y1 >= bounds.min_y && y1 < bounds.max_y) {
		result.input_inside = true;
		result.branch = "0x4a2b5d_input_inside";
		return result;
	}

	int32_t clipped_x = x1;
	int32_t clipped_y = y1;
	const int32_t dx = x2 - x1;
	const int32_t dy = y2 - y1;
	auto accept_original_x = [&](const char *branch) {
		result.x = x1;
		result.y = clipped_y;
		result.branch = branch;
		return result;
	};
	auto accept_current = [&](const char *branch) {
		result.x = clipped_x;
		result.y = clipped_y;
		result.branch = branch;
		return result;
	};

	if (x1 < bounds.min_x && dx != 0) {
		const int32_t delta = bounds.min_x - x1;
		clipped_x = x1 + int32_t((int64_t(dx) * int64_t(delta)) / int64_t(dx));
		clipped_y = y1 + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dx));
		if (y1 >= bounds.min_y && clipped_y < bounds.min_y) {
			return accept_original_x("0x4a2bb5_left_edge_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_original_x("0x4a2bb5_left_edge_crosses_max_y");
		}
	}
	if (clipped_y < bounds.min_y && dy != 0) {
		const int32_t delta = bounds.min_y - clipped_y;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		if (x1 >= bounds.min_x && clipped_x < bounds.min_x) {
			return accept_original_x("0x4a2bb5_min_y_crosses_min_x");
		}
		if (x1 < bounds.max_x && clipped_x >= bounds.max_x) {
			return accept_original_x("0x4a2bb5_min_y_crosses_max_x");
		}
	}
	if (clipped_x >= bounds.max_x && dx != 0) {
		const int32_t delta = bounds.max_x - clipped_x - 1;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dx));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dx));
		if (y1 >= bounds.min_y && clipped_y < bounds.min_y) {
			return accept_original_x("0x4a2bb5_max_x_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_original_x("0x4a2bb5_max_x_crosses_max_y");
		}
	}
	if (clipped_y >= bounds.max_y && dy != 0) {
		const int32_t delta = bounds.max_y - clipped_y - 1;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		if (x1 >= bounds.min_x && clipped_x < bounds.min_x) {
			return accept_current("0x4a2ccf_max_y_crosses_min_x");
		}
		if (x1 < bounds.max_x && clipped_x >= bounds.max_x) {
			return accept_current("0x4a2ccf_max_y_crosses_max_x");
		}
	}
	return accept_current("0x4a2b5d_fallback_current");
}

void append_line_trace_preview(Array &trace_preview, int32_t x, int32_t y, int32_t level) {
	if (trace_preview.size() >= 8) {
		return;
	}
	Dictionary item;
	item["x"] = x;
	item["y"] = y;
	item["level"] = level;
	trace_preview.append(item);
}

int32_t h3maped_line_sign_4a261a(int32_t value) {
	return value > 0 ? 1 : -1;
}

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

void h3maped_write_line_cell_4a261a(LineWriteResult &result, std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x, int32_t y, int32_t level, int32_t zone_word_id) {
	if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
		result.out_of_bounds_write_count += 1;
		return;
	}
	const int64_t index = h3maped_cell_index(width, height, x, y, level);
	if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) != (uint32_t(zone_word_id & 0xff) << 16U)) {
		result.unique_cell_count += 1;
	}
	zone_words[size_t(index)] = (zone_words[size_t(index)] & H3MAPED_ZONE_WORD_CLEAR_MASK) | (uint32_t(zone_word_id & 0xff) << 16U);
	if (!(water_code == 2 && level != 1)) {
		cell_flags[size_t(index)] = uint8_t(cell_flags[size_t(index)] | 0x10U);
		result.reserved_flag_write_count += 1;
	}
	result.write_count += 1;
	append_line_trace_preview(result.trace_preview, x, y, level);
}

LineWriteResult h3maped_line_writer_4a261a(std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t level, int32_t zone_word_id) {
	LineWriteResult result;
	if (x1 > x2) {
		std::swap(x1, x2);
		std::swap(y1, y2);
	}
	const int32_t dx = x2 - x1;
	const int32_t dy = y2 - y1;
	const int32_t abs_dy = std::abs(dy);
	int32_t major = 0;
	int32_t minor = 0;
	int32_t simple_step_x = 0;
	int32_t simple_step_y = 0;
	const int32_t diagonal_step_y = h3maped_line_sign_4a261a(dy);
	if (dx > abs_dy) {
		major = dx;
		minor = abs_dy;
		simple_step_x = 1;
	} else {
		major = abs_dy;
		minor = dx;
		simple_step_y = h3maped_line_sign_4a261a(dy);
	}
	int32_t error = major / 2;
	int32_t x = x1;
	int32_t y = y1;
	while (x != x2 || y != y2) {
		h3maped_write_line_cell_4a261a(result, zone_words, cell_flags, width, height, level_count, water_code, x, y, level, zone_word_id);
		error += minor;
		if (error < major) {
			x += simple_step_x;
			y += simple_step_y;
		} else {
			error -= major;
			x += 1;
			y += diagonal_step_y;
		}
	}
	h3maped_write_line_cell_4a261a(result, zone_words, cell_flags, width, height, level_count, water_code, x, y, level, zone_word_id);
	return result;
}

LineWriteResult h3maped_randomized_line_writer_4a2413(std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t level, int32_t zone_word_id, int32_t random_span_limit, H3MapedRng &rng, int32_t &rng_call_count, int32_t &inserted_midpoint_count, int32_t &max_pending_point_count) {
	LineWriteResult result;
	std::vector<CoordCandidate> pending;
	pending.push_back(CoordCandidate{ x2, y2, level });
	max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	int32_t current_x = x1;
	int32_t current_y = y1;
	for (int32_t guard = 0; guard < 4096 && !pending.empty(); ++guard) {
		const CoordCandidate target = pending.back();
		pending.pop_back();
		const int32_t midpoint_x = (target.x + current_x + 1) / 2;
		const int32_t midpoint_y = (target.y + current_y + 1) / 2;
		if ((midpoint_x == current_x && midpoint_y == current_y) || (midpoint_x == target.x && midpoint_y == target.y)) {
			const int32_t clamped_x = std::min(std::max(current_x, 0), std::max(0, width - 1));
			const int32_t clamped_y = std::min(std::max(current_y, 0), std::max(0, height - 1));
			h3maped_write_line_cell_4a261a(result, zone_words, cell_flags, width, height, level_count, water_code, clamped_x, clamped_y, level, zone_word_id);
			current_x = target.x;
			current_y = target.y;
			continue;
		}
		const int32_t dx = target.x - current_x;
		const int32_t neg_dy = current_y - target.y;
		const int32_t segment_length = h3maped_distance_truncate_local(0, 0, dx, neg_dy);
		int32_t jittered_x = midpoint_x;
		int32_t jittered_y = midpoint_y;
		if (segment_length > 1) {
			const int32_t jitter_limit = std::max<int32_t>(1, std::min(random_span_limit, segment_length));
			const int32_t rng_value = rng.next();
			rng_call_count += 1;
			const int32_t centered_offset = (rng_value % jitter_limit) - (jitter_limit / 2);
			const int32_t adjusted_x = int32_t((int64_t(centered_offset) * int64_t(neg_dy)) / int64_t(segment_length));
			const int32_t adjusted_y = int32_t((int64_t(dx) * int64_t(centered_offset)) / int64_t(segment_length));
			jittered_x += adjusted_x;
			jittered_y += adjusted_y;
		}
		pending.push_back(target);
		pending.push_back(CoordCandidate{ jittered_x, jittered_y, level });
		inserted_midpoint_count += 1;
		max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	}
	return result;
}

Dictionary player_slot_assignment_report(const TemplateEvidence &candidate, const Dictionary &normalized_config, int32_t human_count, int32_t computer_count) {
	Dictionary report;
	std::array<int32_t, 9> raw_mapping = {};
	raw_mapping.fill(-1);
	std::array<bool, 8> human_capable = bool_bitmap_from_mask(candidate.human_capable_source_owner_mask);
	std::array<bool, 8> player_capable = bool_bitmap_from_mask(candidate.player_capable_source_owner_mask);
	const std::array<bool, 8> selected_color_bitmap = selected_color_bitmap_from_config(normalized_config);
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

	source_owner_scan = 0;
	const int32_t desired_total = human_count + computer_count;
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
	report["source"] = "h3maped 0x4ac552 before phase calls; source +0x04 role bucket and +0x1c ownership build generator+0xee0/+0xee4";
	report["selected_color_bitmap_offset"] = "generator+0xed8";
	report["assignment_slots_offset"] = "generator+0xee0";
	report["mapped_slots_offset"] = "generator+0xee4";
	report["source_template_id"] = candidate.id;
	report["source_catalog_index"] = candidate.catalog_index;
	report["human_capable_source_owner_mask"] = candidate.human_capable_source_owner_mask;
	report["player_capable_source_owner_mask"] = candidate.player_capable_source_owner_mask;
	report["human_capable_source_owner_indices"] = mask_indices(candidate.human_capable_source_owner_mask);
	report["player_capable_source_owner_indices"] = mask_indices(candidate.player_capable_source_owner_mask);
	report["selected_color_bitmap"] = bool_bitmap_report(selected_color_bitmap);
	report["selected_color_order"] = color_order_report;
	report["raw_ee0_slots"] = raw_slots;
	report["actual_colors_by_source_owner"] = colors_by_source_owner;
	report["assignments"] = assignments;
	report["assigned_count"] = assignments.size();
	report["desired_human_count"] = human_count;
	report["desired_computer_count"] = computer_count;
	report["materializes_runtime_players"] = false;
	return report;
}

bool player_filter_accepts(const Dictionary &filter, int32_t human_count, int32_t total_players) {
	if (filter.is_empty()) {
		return true;
	}
	return human_count >= int32_t(filter.get("min_human", 0))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& total_players >= int32_t(filter.get("min_total", 0))
			&& total_players <= int32_t(filter.get("max_total", 8));
}

int32_t owner_color_for_source_owner(const Array &colors_by_source_owner, int32_t source_owner_index) {
	if (source_owner_index < 0 || source_owner_index >= colors_by_source_owner.size()) {
		return -1;
	}
	return int32_t(colors_by_source_owner[source_owner_index]);
}

Dictionary source_template_record_for_catalog_index(int32_t source_catalog_index) {
	Dictionary catalog = load_json_dictionary(CATALOG_SOURCE_PATH);
	Array templates = catalog.get("templates", Array());
	if (source_catalog_index < 0 || source_catalog_index >= templates.size() || Variant(templates[source_catalog_index]).get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	return Dictionary(templates[source_catalog_index]);
}

Dictionary runtime_zone_record_setup_report(const TemplateEvidence &candidate, const Dictionary &source_template_record, const Dictionary &assignment, int32_t human_count, int32_t total_players) {
	Dictionary report;
	report["status"] = "0x4a218c_runtime_zone_record_setup_ported_inspection_only";
	report["source"] = "h3maped 0x4a218c consumes generator+0xee4 owner-color mapping, clears generator+0x10e0/+0x10e4/+0x10e8, allocates 0x414-byte runtime-zone records, and initializes through 0x49b452";
	report["runtime_zone_vector_offsets"] = "generator+0x10e0/+0x10e4/+0x10e8";
	report["runtime_zone_record_size_bytes"] = 0x414;
	report["source_zone_pointer_offset"] = "runtime_zone+0x00";
	report["chosen_town_offset"] = "runtime_zone+0x04";
	report["chosen_terrain_offset"] = "runtime_zone+0x0c";
	report["owner_color_mapping_source"] = "generator+0xee4";
	report["materializes_runtime_zone_coordinates"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["materializes_runtime_players"] = false;
	report["source_template_id"] = candidate.id;
	report["source_catalog_index"] = candidate.catalog_index;

	if (source_template_record.is_empty()) {
		report["status"] = "0x4a218c_runtime_zone_record_setup_source_template_missing";
		report["runtime_zone_count"] = 0;
		report["runtime_zone_records"] = Array();
		return report;
	}

	Array colors_by_source_owner = assignment.get("actual_colors_by_source_owner", Array());
	Array zones = source_template_record.get("zones", Array());
	Array records;
	Array owner_colors;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = 0;
	bool has_base_size = false;

	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = zones[index];
		if (!player_filter_accepts(zone.get("player_filter", Dictionary()), human_count, total_players)) {
			continue;
		}
		const String role = String(zone.get("type", ""));
		const int32_t source_owner_index = int32_t(zone.get("ownership", -1));
		const int32_t actual_owner_color = owner_color_for_source_owner(colors_by_source_owner, source_owner_index);
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		Dictionary neutral_towns = zone.get("neutral_towns", Dictionary());
		const int32_t source_base_size = int32_t(zone.get("base_size", 0));
		if (!has_base_size || source_base_size < minimum_source_base_size) {
			minimum_source_base_size = source_base_size;
			has_base_size = true;
		}

		const int32_t min_castles = int32_t(player_towns.get("min_castles", 0));
		minimum_player_castles += min_castles;
		if (role == "human_start" || role == "computer_start") {
			if (actual_owner_color >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else if (role == "treasure") {
			treasure_zone_count += 1;
		}

		Dictionary record;
		record["runtime_zone_index"] = records.size();
		record["source_zone_id"] = zone.get("id", -1);
		record["role"] = role;
		record["source_bucket"] = zone.get("bucket", -1);
		record["source_owner_index"] = source_owner_index;
		record["actual_owner_color"] = actual_owner_color;
		record["level"] = 0;
		record["source_base_size"] = source_base_size;
		record["player_min_towns"] = player_towns.get("min_towns", 0);
		record["player_min_castles"] = min_castles;
		record["player_town_density"] = player_towns.get("town_density", 0);
		record["player_castle_density"] = player_towns.get("castle_density", 0);
		record["neutral_min_towns"] = neutral_towns.get("min_towns", 0);
		record["neutral_min_castles"] = neutral_towns.get("min_castles", 0);
		record["neutral_town_density"] = neutral_towns.get("town_density", 0);
		record["neutral_castle_density"] = neutral_towns.get("castle_density", 0);
		record["coordinate_status"] = "pending_0x4a17f5_0x4a1701";
		record["terrain_status"] = "pending_0x49b53d";
		record["footprint_status"] = "pending_0x4a3a03";
		records.append(record);
		owner_colors.append(actual_owner_color);
	}

	report["source_template_name"] = source_template_record.get("name", "");
	report["runtime_zone_count"] = records.size();
	report["assigned_start_zone_count"] = assigned_start_zone_count;
	report["unassigned_start_zone_count"] = unassigned_start_zone_count;
	report["treasure_zone_count"] = treasure_zone_count;
	report["minimum_player_castles"] = minimum_player_castles;
	report["minimum_source_base_size"] = has_base_size ? minimum_source_base_size : 0;
	report["actual_owner_colors_by_runtime_zone"] = owner_colors;
	report["runtime_zone_records"] = records;
	return report;
}

Dictionary zone_footprint_phase_boundary_report(const Dictionary &normalized_config, const Dictionary &runtime_zone_setup) {
	Dictionary report;
	report["status"] = "0x4a3a03_zone_footprint_phase_boundary_ported_inspection_only";
	report["source"] = "h3maped 0x4a3a03 runs once per level, collects matching runtime zones, may append synthetic source 0xd4 for water/level cases, then calls 0x4a2777 -> 0x4a325d -> 0x4a3710";
	report["phase_address"] = "0x4a3a03";
	report["helper_sequence"] = "0x4a2777 -> 0x4a325d -> 0x4a3710";
	report["synthetic_source_zone_id"] = "0xd4";
	report["synthetic_triplets"] = "0xa0=100,0xa4=1000,0xa8=5,0xac=2000,0xb0=6000,0xb4=1";
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	Array runtime_records = runtime_zone_setup.get("runtime_zone_records", Array());
	Array levels;
	int32_t total_collected = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		Array zone_indices;
		Array helper_call_inputs;
		for (int64_t index = 0; index < runtime_records.size(); ++index) {
			if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary record = runtime_records[index];
			if (int32_t(record.get("level", 0)) != level) {
				continue;
			}
			const Variant runtime_index = record.get("runtime_zone_index", index);
			zone_indices.append(runtime_index);
			Dictionary helper_input;
			helper_input["call_order"] = helper_call_inputs.size();
			helper_input["helper_address"] = "0x4a2777";
			helper_input["runtime_zone_index"] = runtime_index;
			helper_input["source_zone_id"] = record.get("source_zone_id", -1);
			helper_input["level"] = level;
			helper_input["input_status"] = "queued_for_0x4a2777_no_boundary_materialization";
			helper_call_inputs.append(helper_input);
		}
		total_collected += zone_indices.size();
		Dictionary level_record;
		level_record["level"] = level;
		level_record["collected_runtime_zone_indices"] = zone_indices;
		level_record["collected_runtime_zone_count"] = zone_indices.size();
		level_record["helper_call_inputs"] = helper_call_inputs;
		level_record["helper_call_input_count"] = helper_call_inputs.size();
		level_record["synthetic_zone_appended"] = false;
		level_record["synthetic_zone_status"] = water_code == 0 && level_count == 1 ? String("not_applicable_small_one_level_land") : String("pending_water_or_multilevel_rule_port");
		level_record["helper_status"] = "0x4a2777_inputs_queued_0x4a325d_0x4a3710_materialization_pending";
		levels.append(level_record);
	}

	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["per_level"] = levels;
	report["total_collected_runtime_zone_count"] = total_collected;
	report["synthetic_zone_appended_count"] = 0;
	return report;
}

Dictionary clip_helper_4a2b33_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2b33_clip_helper_ported_inspection_only";
	report["source"] = "h3maped 0x4a2777 dependency: 0x4a2b33 clips source-node segment endpoints to the active map rectangle before boundary line painting";
	report["function_address"] = "0x4a2b33";
	report["caller_address"] = "0x4a2777";
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = std::max(1, int32_t(normalized_config.get("width", 36)));
	bounds.max_y = std::max(1, int32_t(normalized_config.get("height", 36)));
	Dictionary bounds_report;
	bounds_report["min_x"] = bounds.min_x;
	bounds_report["min_y"] = bounds.min_y;
	bounds_report["max_x"] = bounds.max_x;
	bounds_report["max_y"] = bounds.max_y;
	report["clip_bounds"] = bounds_report;

	auto clip_sample = [&](const char *id, int32_t x1, int32_t y1, int32_t x2, int32_t y2) {
		ClipResult clipped = h3maped_clip_point_4a2b33(x1, y1, x2, y2, bounds);
		Dictionary item;
		item["id"] = id;
		item["from_x"] = x1;
		item["from_y"] = y1;
		item["to_x"] = x2;
		item["to_y"] = y2;
		item["out_x"] = clipped.x;
		item["out_y"] = clipped.y;
		item["input_inside"] = clipped.input_inside;
		item["branch"] = clipped.branch;
		item["output_in_bounds"] = clipped.x >= bounds.min_x && clipped.x < bounds.max_x && clipped.y >= bounds.min_y && clipped.y < bounds.max_y;
		return item;
	};

	Array samples;
	samples.append(clip_sample("inside", 10, 10, 30, 30));
	samples.append(clip_sample("left_to_inside", -5, 10, 20, 10));
	samples.append(clip_sample("top_to_inside", 10, -5, 10, 20));
	samples.append(clip_sample("right_to_inside", bounds.max_x + 5, 12, 20, 12));
	samples.append(clip_sample("bottom_to_inside", 12, bounds.max_y + 5, 12, 20));
	report["sample_count"] = samples.size();
	report["samples"] = samples;
	report["blocked_next"] = "port 0x4a261a deterministic line writer before 0x4a2777 can consume queued runtime-zone cycles";
	return report;
}

Dictionary line_writer_4a261a_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a261a_deterministic_line_writer_ported_inspection_only";
	report["source"] = "h3maped 0x4a2777 dependency: 0x4a261a paints a deterministic line of zone-word cells and reserved flags after endpoint clipping";
	report["function_address"] = "0x4a261a";
	report["caller_address"] = "0x4a2777";
	report["zone_word_mask"] = "0x00ff0000";
	report["zone_word_clear_mask"] = "0xff00ffff";
	report["reserved_flag_mask"] = "0x10";
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	const int32_t sample_width = 12;
	const int32_t sample_height = 8;
	const int32_t level_count = 1;
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t zone_word_id = 7;
	std::vector<uint32_t> zone_words(size_t(sample_width * sample_height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(sample_width * sample_height * level_count), 0);
	LineWriteResult line = h3maped_line_writer_4a261a(zone_words, cell_flags, sample_width, sample_height, level_count, water_code, 2, 3, 8, 3, 0, zone_word_id);

	int32_t zone_word_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	for (int32_t y = 0; y < sample_height; ++y) {
		for (int32_t x = 0; x < sample_width; ++x) {
			const int64_t index = h3maped_cell_index(sample_width, sample_height, x, y, 0);
			if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == (uint32_t(zone_word_id) << 16U)) {
				zone_word_cell_count += 1;
			}
			if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
				reserved_flag_cell_count += 1;
			}
		}
	}

	Dictionary sample;
	sample["map_width"] = sample_width;
	sample["map_height"] = sample_height;
	sample["level_count"] = level_count;
	sample["h3maped_water_mode_code"] = water_code;
	sample["from_x"] = 2;
	sample["from_y"] = 3;
	sample["to_x"] = 8;
	sample["to_y"] = 3;
	sample["level"] = 0;
	sample["zone_word_id"] = zone_word_id;
	sample["write_count"] = line.write_count;
	sample["unique_cell_count"] = line.unique_cell_count;
	sample["zone_word_cell_count"] = zone_word_cell_count;
	sample["reserved_flag_write_count"] = line.reserved_flag_write_count;
	sample["reserved_flag_cell_count"] = reserved_flag_cell_count;
	sample["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	sample["trace_preview"] = line.trace_preview;
	report["sample_contract"] = sample;
	report["blocked_next"] = "assemble 0x4a2777 source-node traversal from queued helper inputs, 0x4a2b33 clipping, and this 0x4a261a line writer";
	return report;
}

Dictionary randomized_line_writer_4a2413_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2413_randomized_line_writer_ported_inspection_only";
	report["source"] = "h3maped 0x4a2777 flagged branch writer; recursively subdivides a segment, jitters midpoint candidates with 0x4e7276, clamps terminal writes to map bounds, and writes zone words like 0x4a261a";
	report["function_address"] = "0x4a2413";
	report["caller_address"] = "0x4a2777";
	report["rng_address"] = "0x4e7276";
	report["distance_helper_address"] = "0x4cc5ad";
	report["reserved_flag_mask"] = "0x10";
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	const int32_t width = std::max(1, int32_t(normalized_config.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized_config.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t zone_word_id = 9;
	const int32_t random_span_limit = 6;
	std::vector<uint32_t> zone_words(size_t(width * height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(width * height * level_count), 0);
	H3MapedRng rng;
	rng.state = 1;
	int32_t rng_call_count = 0;
	int32_t inserted_midpoint_count = 0;
	int32_t max_pending_point_count = 0;
	LineWriteResult line = h3maped_randomized_line_writer_4a2413(
			zone_words,
			cell_flags,
			width,
			height,
			level_count,
			water_code,
			2,
			2,
			width - 3,
			height - 5,
			0,
			zone_word_id,
			random_span_limit,
			rng,
			rng_call_count,
			inserted_midpoint_count,
			max_pending_point_count);

	int32_t zone_word_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			const int64_t index = h3maped_cell_index(width, height, x, y, 0);
			if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == (uint32_t(zone_word_id) << 16U)) {
				zone_word_cell_count += 1;
			}
			if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
				reserved_flag_cell_count += 1;
			}
		}
	}

	Dictionary sample;
	sample["map_width"] = width;
	sample["map_height"] = height;
	sample["level_count"] = level_count;
	sample["h3maped_water_mode_code"] = water_code;
	sample["from_x"] = 2;
	sample["from_y"] = 2;
	sample["to_x"] = width - 3;
	sample["to_y"] = height - 5;
	sample["level"] = 0;
	sample["zone_word_id"] = zone_word_id;
	sample["random_span_limit"] = random_span_limit;
	sample["write_count"] = line.write_count;
	sample["unique_cell_count"] = line.unique_cell_count;
	sample["zone_word_cell_count"] = zone_word_cell_count;
	sample["reserved_flag_write_count"] = line.reserved_flag_write_count;
	sample["reserved_flag_cell_count"] = reserved_flag_cell_count;
	sample["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	sample["rng_call_count"] = rng_call_count;
	sample["inserted_midpoint_count"] = inserted_midpoint_count;
	sample["max_pending_point_count"] = max_pending_point_count;
	sample["rng_state_after_uint32"] = int64_t(rng.state);
	sample["trace_preview"] = line.trace_preview;
	report["sample_contract"] = sample;
	report["blocked_next"] = "wire 0x4a2413 into the real 0x4a2777 flagged source-node traversal branch";
	return report;
}

Dictionary source_node_rectangle_4cc788_report() {
	Dictionary report;
	report["status"] = "0x4cc788_initial_source_node_bounds_ported_inspection_only";
	report["source"] = "h3maped 0x4cc788 constructs the initial polygon source-node rectangle from constants 0xffffff38 (-200) and 0x190 (400), then links four 0x4cc955 nodes before 0x4ccb64 runtime-zone split insertions";
	report["function_address"] = "0x4cc788";
	report["node_constructor_address"] = "0x4cc955";
	report["splitter_address"] = "0x4ccb64";
	report["locator_address"] = "0x4cca55";
	report["finalizer_address"] = "0x4ccdfc";
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["feeds_real_0x4a2777_boundary"] = false;

	Dictionary bounds;
	bounds["min_x"] = -200;
	bounds["min_y"] = -200;
	bounds["max_x"] = 400;
	bounds["max_y"] = 400;
	bounds["constant_min_hex"] = "0xffffff38";
	bounds["constant_max_hex"] = "0x190";
	report["initial_bounds"] = bounds;

	Array edges;
	auto append_edge = [&](const char *id, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y) {
		Dictionary edge;
		edge["id"] = id;
		edge["from_x"] = from_x;
		edge["from_y"] = from_y;
		edge["to_x"] = to_x;
		edge["to_y"] = to_y;
		edge["payload"] = 0;
		edges.append(edge);
	};
	append_edge("top", -200, -200, 400, -200);
	append_edge("right", 400, -200, 400, 400);
	append_edge("bottom", 400, 400, -200, 400);
	append_edge("left", -200, 400, -200, -200);
	report["initial_edge_count"] = edges.size();
	report["initial_edges"] = edges;
	report["blocked_next"] = "port 0x4ccb64 split insertion and 0x4ccdfc source-node finalization before feeding real cycles into 0x4a2777";
	return report;
}

Array accepted_templates_for_config(const Dictionary &normalized_config, int32_t score, int32_t human_count, int32_t player_count) {
	Array accepted_templates;
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (human_count < candidate.min_humans || human_count > candidate.max_humans
				|| player_count < candidate.min_total_players || player_count > candidate.max_total_players
				|| player_count < human_count) {
			continue;
		}
		accepted_templates.append(template_to_dictionary(candidate));
	}
	return accepted_templates;
}

Array restart_phase_backlog() {
	Array phases;
	struct Phase {
		const char *id;
		const char *source;
	};
	const Phase REQUIRED_PHASES[] = {
		{ "template_selection", "0x49f0cd / 0x4ac597 / 0x4e7276" },
		{ "player_slot_assignment", "0x4ac62a..0x4ac6ec" },
		{ "runtime_zone_records", "0x4a218c" },
		{ "zone_footprints_and_terrain", "0x4a3a03 / 0x4a2777 / 0x4a325d / 0x4a3f27" },
		{ "town_object_placement", "0x4a8d2c / 0x4a93a2 / 0x49ba89" },
		{ "roads_and_rivers", "0x4ab52a / 0x4aae7b / 0x4ab37f / 0x4b4243" },
		{ "connections_blockers_guards", "0x4a79a3 / 0x4a61bc / 0x4a696b / 0x4a6cf2 / 0x4a7605" },
		{ "mines_rewards_objects", "0x49aa93 object placement family" },
		{ "final_h3m_writeout", "0x49b2b6" },
	};
	for (const Phase &phase : REQUIRED_PHASES) {
		Dictionary record;
		record["phase_id"] = phase.id;
		record["h3maped_source"] = phase.source;
		if (phase.id == String("template_selection")) {
			record["status"] = "active_boundary_only";
		} else if (phase.id == String("player_slot_assignment")) {
			record["status"] = "active_inspection_only";
		} else if (phase.id == String("runtime_zone_records")) {
			record["status"] = "active_inspection_only";
		} else if (phase.id == String("zone_footprints_and_terrain")) {
			record["status"] = "active_phase_boundary_only";
		} else {
			record["status"] = "pending_strict_port";
		}
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

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t score = size_score(normalized_config);
	Array accepted_templates;
	if (supports_scope(normalized_config)) {
		accepted_templates = accepted_templates_for_config(normalized_config, score, human_count, player_count);
	}

	Dictionary result;
	result["ok"] = false;
	result["schema_id"] = "aurelion_native_rmg_small_h3maped_selection_identity_v1";
	result["schema_version"] = 2;
	result["scope"] = "small_36x36_surface_land_only";
	result["supported_scope"] = supports_scope(normalized_config);
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["template_loader_address"] = "0x49f0cd";
	result["rng_seed_setter_address"] = "0x4e7269";
	result["rng_function_address"] = "0x4e7276";
	result["accepted_template_count"] = accepted_templates.size();
	result["requested_template_id_ignored"] = String(normalized_config.get("template_id", ""));
	result["explicit_template_requests_bypass_reset"] = false;
	result["size_score"] = score;
	if (!supports_scope(normalized_config)) {
		result["status"] = "unsupported_scope";
		return result;
	}
	if (accepted_templates.is_empty()) {
		result["status"] = "h3maped_small_no_accepted_templates";
		return result;
	}

	uint32_t seed_value = 0;
	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	if (!parse_numeric_h3maped_seed(seed_text, seed_value)) {
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["blocked_reason"] = "h3maped seed must be numeric; no project hash replacement is allowed";
		return result;
	}

	const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
	const int32_t rng_value = int32_t((next_state >> 16U) & 0x7fffu);
	const int32_t selected_index = rng_value % int32_t(accepted_templates.size());
	Dictionary selected_template = accepted_templates[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_value_uint32"] = int64_t(seed_value);
	result["rng_state_after_selection_uint32"] = int64_t(next_state);
	result["rng_first_value"] = rng_value;
	result["selected_vector_index"] = selected_index;
	result["selected_template"] = selected_template;
	result["source_template_id"] = selected_template.get("id", "");
	result["source_catalog_index"] = selected_template.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected_template.get("adapted_template_id", "");
	result["template_id"] = selected_template.get("adapted_template_id", "");
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
	const int32_t score = size_score(normalized_config);
	Array accepted_templates;
	if (supports_scope(normalized_config)) {
		accepted_templates = accepted_templates_for_config(normalized_config, score, human_count, player_count);
	}

	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted_templates.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_clean_restart_v8";
	report["schema_version"] = 8;
	report["status"] = supports_scope(normalized_config) ? (accepted_templates.is_empty() ? String("h3maped_small_no_accepted_templates") : String("h3maped_small_clean_boundary_ready")) : String("unsupported_scope");
	report["scope"] = "small_36x36_surface_land_only";
	report["implementation_policy"] = "clean_restart_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_fallback_maps";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "previous_active_h3maped_inspection_ledger_archived_out_of_build";
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["catalog_path"] = CATALOG_SOURCE_PATH;
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
	report["restart_phase_backlog"] = restart_phase_backlog();
	Dictionary identity = selection_identity(normalized_config);
	report["selection_identity"] = identity;
	if (bool(identity.get("ok", false))) {
		const int32_t selected_catalog_index = int32_t(identity.get("source_catalog_index", -1));
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (candidate.catalog_index == selected_catalog_index) {
				Dictionary assignment = player_slot_assignment_report(candidate, normalized_config, human_count, computer_count);
				report["player_slot_assignment"] = assignment;
				Dictionary runtime_zone_setup = runtime_zone_record_setup_report(candidate, source_template_record_for_catalog_index(selected_catalog_index), assignment, human_count, player_count);
				report["runtime_zone_record_setup"] = runtime_zone_setup;
				report["zone_footprint_phase_boundary"] = zone_footprint_phase_boundary_report(normalized_config, runtime_zone_setup);
				report["clip_helper_4a2b33"] = clip_helper_4a2b33_report(normalized_config);
				report["line_writer_4a261a"] = line_writer_4a261a_report(normalized_config);
				report["randomized_line_writer_4a2413"] = randomized_line_writer_4a2413_report(normalized_config);
				report["source_node_rectangle_4cc788"] = source_node_rectangle_4cc788_report();
				break;
			}
		}
	}
	report["generation_phase_status"] = "blocked_until_required_h3maped_phases_are_ported_from_executable";
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The prior native RMG path is archived. The replacement is small-map-only and will not emit fallback maps until each required h3maped.exe phase is ported and adapted to project assets.";
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
	result["message"] = "Out-of-scope map sizes and modes do not emit fallback maps during the h3maped small-map restart.";
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["native_rmg_archive_status"] = "archived_legacy_native_rmg_debug_only";
	result["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["h3maped_binary_path"] = BINARY_PATH;
	result["h3maped_binary_sha256"] = BINARY_SHA256;
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
