#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *ADAPTED_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

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
	int32_t player_start_zone_count;
	int32_t treasure_zone_count;
	int32_t minimum_player_castles;
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

struct RuntimeZoneSeed {
	int32_t runtime_index = -1;
	int32_t source_bucket = -1;
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

struct TerrainVisualRow {
	int32_t shape_class = -1;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
};

struct TerrainClassResult {
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
	const char *trigger = "no classed relation";
};

struct CoordCandidate {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct PolygonPoint {
	int32_t x = 0;
	int32_t y = 0;
};

struct PolygonModelNode {
	String id;
	int32_t x = 0;
	int32_t y = 0;
	int32_t payload = 0;
	bool has_payload = false;
	int32_t pair = -1;
	int32_t next = -1;
	int32_t previous = -1;
	bool active = true;
	bool finalized = false;
	int32_t finalized_x = 0;
	int32_t finalized_y = 0;
};

struct PolygonModel {
	std::vector<PolygonModelNode> nodes;
	int32_t root = -1;

	int32_t add_pair(const String &prefix, int32_t from_x, int32_t from_y, int32_t from_payload, int32_t to_x, int32_t to_y, int32_t to_payload, bool from_has_payload = false, bool to_has_payload = false) {
		const int32_t primary_index = int32_t(nodes.size());
		const int32_t paired_index = primary_index + 1;
		PolygonModelNode primary;
		primary.id = prefix + String("_primary");
		primary.x = from_x;
		primary.y = from_y;
		primary.payload = from_payload;
		primary.has_payload = from_has_payload;
		primary.pair = paired_index;
		primary.next = primary_index;
		primary.previous = primary_index;
		PolygonModelNode paired;
		paired.id = prefix + String("_paired");
		paired.x = to_x;
		paired.y = to_y;
		paired.payload = to_payload;
		paired.has_payload = to_has_payload;
		paired.pair = primary_index;
		paired.next = paired_index;
		paired.previous = paired_index;
		nodes.push_back(primary);
		nodes.push_back(paired);
		return primary_index;
	}

	void relink_4cc643(int32_t first, int32_t second) {
		const int32_t first_next = nodes[size_t(first)].next;
		const int32_t second_next = nodes[size_t(second)].next;
		std::swap(nodes[size_t(first_next)].previous, nodes[size_t(second_next)].previous);
		std::swap(nodes[size_t(first)].next, nodes[size_t(second)].next);
	}

	void edge_swap_4cc670(int32_t node_index) {
		const int32_t paired = nodes[size_t(node_index)].pair;
		const int32_t paired_previous = nodes[size_t(paired)].previous;
		relink_4cc643(node_index, nodes[size_t(node_index)].previous);
		relink_4cc643(paired, paired_previous);
	}

	void erase_edge_4cc9cc(int32_t node_index) {
		edge_swap_4cc670(node_index);
		const int32_t paired = nodes[size_t(node_index)].pair;
		nodes[size_t(node_index)].active = false;
		nodes[size_t(paired)].active = false;
	}

	void crossing_collapse_4cc68e(int32_t node_index) {
		const int32_t paired = nodes[size_t(node_index)].pair;
		const int32_t previous = nodes[size_t(node_index)].previous;
		const int32_t paired_previous = nodes[size_t(paired)].previous;
		edge_swap_4cc670(node_index);
		const int32_t previous_pair = nodes[size_t(previous)].pair;
		nodes[size_t(node_index)].payload = nodes[size_t(previous_pair)].payload;
		nodes[size_t(node_index)].has_payload = nodes[size_t(previous_pair)].has_payload;
		nodes[size_t(node_index)].x = nodes[size_t(previous_pair)].x;
		nodes[size_t(node_index)].y = nodes[size_t(previous_pair)].y;
		const int32_t paired_previous_pair = nodes[size_t(paired_previous)].pair;
		nodes[size_t(paired)].payload = nodes[size_t(paired_previous_pair)].payload;
		nodes[size_t(paired)].has_payload = nodes[size_t(paired_previous_pair)].has_payload;
		nodes[size_t(paired)].x = nodes[size_t(paired_previous_pair)].x;
		nodes[size_t(paired)].y = nodes[size_t(paired_previous_pair)].y;
		relink_4cc643(node_index, nodes[size_t(previous_pair)].previous);
		relink_4cc643(paired, nodes[size_t(paired_previous_pair)].previous);
	}

	int32_t active_node_pair_count() const {
		int32_t count = 0;
		for (int32_t index = 0; index < int32_t(nodes.size()); index += 2) {
			if (nodes[size_t(index)].active || nodes[size_t(index + 1)].active) {
				count += 1;
			}
		}
		return count;
	}

	int32_t bridge_4ccb1f(int32_t old_node, int32_t target_node, const String &prefix) {
		const PolygonModelNode &old_pair = nodes[size_t(nodes[size_t(old_node)].pair)];
		const PolygonModelNode &target = nodes[size_t(target_node)];
		const int32_t bridge_primary = add_pair(prefix, old_pair.x, old_pair.y, old_pair.payload, target.x, target.y, target.payload, old_pair.has_payload, target.has_payload);
		relink_4cc643(bridge_primary, nodes[size_t(nodes[size_t(old_node)].pair)].previous);
		relink_4cc643(nodes[size_t(bridge_primary)].pair, target_node);
		return bridge_primary;
	}

	int64_t side_4cca55(int32_t from_node, int32_t to_node, int32_t x, int32_t y) const {
		const PolygonModelNode &from = nodes[size_t(from_node)];
		const PolygonModelNode &to = nodes[size_t(to_node)];
		return int64_t(to.y - from.y) * int64_t(x - from.x) - int64_t(to.x - from.x) * int64_t(y - from.y);
	}

	int32_t locate_4cca55(int32_t x, int32_t y) const {
		int32_t current = root;
		for (int32_t guard = 0; guard < 512; ++guard) {
			const PolygonModelNode &current_node = nodes[size_t(current)];
			if (current_node.x == x && current_node.y == y) {
				return current;
			}
			const int32_t paired = current_node.pair;
			const PolygonModelNode &paired_node = nodes[size_t(paired)];
			if (paired_node.x == x && paired_node.y == y) {
				return paired;
			}
			if (side_4cca55(current, paired, x, y) > 0) {
				current = paired;
				continue;
			}
			const int32_t next = current_node.next;
			if (side_4cca55(next, nodes[size_t(next)].pair, x, y) <= 0) {
				current = next;
				continue;
			}
			const int32_t nested = nodes[size_t(nodes[size_t(paired)].previous)].pair;
			if (side_4cca55(nested, nodes[size_t(nested)].pair, x, y) > 0) {
				return current;
			}
			current = nested;
		}
		return -1;
	}

	bool edge_side_test_4cc6f2(int32_t node_index, int32_t x, int32_t y) const {
		const PolygonModelNode &node = nodes[size_t(node_index)];
		const PolygonModelNode &paired = nodes[size_t(node.pair)];
		const int64_t edge_dx = int64_t(node.x) - int64_t(paired.x);
		const int64_t edge_dy = int64_t(node.y) - int64_t(paired.y);
		const int64_t edge_distance_sq = edge_dx * edge_dx + edge_dy * edge_dy;
		const int64_t node_dx = int64_t(x) - int64_t(node.x);
		const int64_t node_dy = int64_t(y) - int64_t(node.y);
		if (node_dx * node_dx + node_dy * node_dy > edge_distance_sq) {
			return false;
		}
		const int64_t paired_dx = int64_t(x) - int64_t(paired.x);
		const int64_t paired_dy = int64_t(y) - int64_t(paired.y);
		if (paired_dx * paired_dx + paired_dy * paired_dy > edge_distance_sq) {
			return false;
		}
		const int64_t expression = int64_t(node.y) * int64_t(paired.x - node.x)
				- int64_t(node.x) * int64_t(paired.y - node.y)
				- int64_t(y) * int64_t(paired.x - node.x)
				+ int64_t(x) * int64_t(paired.y - node.y);
		return expression == 0;
	}

	bool crossing_test_4ccc7a(int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t x3, int32_t y3, int32_t x4, int32_t y4) const {
		const __int128 v1 = __int128(y4 - y2) * __int128(x3 - x2) - __int128(x4 - x2) * __int128(y3 - y2);
		const __int128 v2 = __int128(x2 - x1) * __int128(y3 - y1) - __int128(y2 - y1) * __int128(x3 - x1);
		const __int128 v3 = __int128(y4 - y1) * __int128(x3 - x1) - __int128(x4 - x1) * __int128(y3 - y1);
		const __int128 v4 = __int128(y4 - y1) * __int128(x2 - x1) - __int128(x4 - x1) * __int128(y2 - y1);
		const __int128 p1 = __int128(x1) * __int128(x1) + __int128(y1) * __int128(y1);
		const __int128 p2 = __int128(x2) * __int128(x2) + __int128(y2) * __int128(y2);
		const __int128 p3 = __int128(x3) * __int128(x3) + __int128(y3) * __int128(y3);
		const __int128 p4 = __int128(x4) * __int128(x4) + __int128(y4) * __int128(y4);
		return (p1 * v1 - p4 * v2 - p2 * v3 + p3 * v4) > 0;
	}

	bool crossing_orientation_gate_4ccb64(int32_t node_index) const {
		const PolygonModelNode &node = nodes[size_t(node_index)];
		const PolygonModelNode &paired = nodes[size_t(node.pair)];
		const PolygonModelNode &previous_pair = nodes[size_t(nodes[size_t(node.previous)].pair)];
		const int64_t value = int64_t(paired.y - node.y) * int64_t(previous_pair.x - node.x)
				- int64_t(paired.x - node.x) * int64_t(previous_pair.y - node.y);
		return value > 0;
	}

	static int64_t idiv_truncate(int64_t numerator, int64_t denominator) {
		if (denominator == 0) {
			return 0;
		}
		return numerator / denominator;
	}

	static int32_t half_truncate_4ccd69(int64_t value) {
		return int32_t(value / 2);
	}

	static PolygonPoint intersection_4ccd69(int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t x3, int32_t y3) {
		const int64_t term = int64_t(y3 - y2) * int64_t(y1 - y3) + int64_t(x1 - x3) * int64_t(x3 - x2);
		const int64_t denominator = int64_t(x1 - x3) * int64_t(y1 - y2) + int64_t(y1 - y3) * int64_t(x2 - x1);
		const int64_t x_adjust = idiv_truncate(int64_t(y1 - y2) * term, denominator);
		const int64_t y_adjust = idiv_truncate(int64_t(x2 - x1) * term, denominator);
		return PolygonPoint {
			x1 + half_truncate_4ccd69(int64_t(x2 - x1) + x_adjust),
			y1 + half_truncate_4ccd69(int64_t(y2 - y1) + y_adjust)
		};
	}

	void write_finalized_4ccdfc(int32_t node_index, const PolygonPoint &point) {
		nodes[size_t(node_index)].finalized_x = point.x;
		nodes[size_t(node_index)].finalized_y = point.y;
		nodes[size_t(node_index)].finalized = true;
	}

	int32_t finalize_4ccdfc(Array *finalized_steps = nullptr) {
		int32_t finalized_triplets = 0;
		for (int32_t index = 0; index < int32_t(nodes.size()); ++index) {
			PolygonModelNode &node = nodes[size_t(index)];
			if (!node.active || !node.has_payload || node.finalized) {
				continue;
			}
			const int32_t next_pair = nodes[size_t(node.next)].pair;
			const PolygonModelNode &paired = nodes[size_t(node.pair)];
			const PolygonModelNode &next_pair_node = nodes[size_t(next_pair)];
			const PolygonPoint point = intersection_4ccd69(node.x, node.y, paired.x, paired.y, next_pair_node.x, next_pair_node.y);
			write_finalized_4ccdfc(index, point);
			write_finalized_4ccdfc(next_pair, point);
			const int32_t nested = nodes[size_t(next_pair)].next;
			const int32_t nested_pair = nodes[size_t(nested)].pair;
			write_finalized_4ccdfc(nested_pair, point);
			finalized_triplets += 1;
			if (finalized_steps != nullptr) {
				Dictionary step;
				step["source_node_id"] = node.id;
				step["fan_node_id"] = nodes[size_t(next_pair)].id;
				step["nested_fan_node_id"] = nodes[size_t(nested_pair)].id;
				step["x"] = point.x;
				step["y"] = point.y;
				finalized_steps->append(step);
			}
		}
		return finalized_triplets;
	}
};

struct SpanRecord {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct SpanFillResult {
	int32_t filled_cell_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
	Array trace_preview;
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
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, 0, "translated_rmg_template_019_v1", 4, 2, 4, 0x0f, 0x0f },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, 0, "", 0, 0, 0, 0, 0 },
};

int64_t h3maped_cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (int64_t(level) * int64_t(height) + int64_t(y)) * int64_t(width) + int64_t(x);
}

bool h3maped_cell_unassigned(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	const int64_t index = h3maped_cell_index(width, height, x, y, level);
	return index >= 0 && index < int64_t(zone_words.size()) && (zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD;
}

void append_span_fill_preview(Array &trace_preview, int32_t x, int32_t y, int32_t level) {
	if (trace_preview.size() >= 8) {
		return;
	}
	Dictionary item;
	item["x"] = x;
	item["y"] = y;
	item["level"] = level;
	trace_preview.append(item);
}

SpanFillResult h3maped_span_fill_4a325d(std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t zone_word_id, const SpanRecord &seed) {
	SpanFillResult result;
	std::vector<SpanRecord> pending;
	auto push_span = [&](const SpanRecord &span) {
		pending.push_back(span);
		result.pushed_span_count += 1;
		result.max_pending_span_count = std::max<int32_t>(result.max_pending_span_count, int32_t(pending.size()));
	};
	push_span(seed);
	while (!pending.empty()) {
		const SpanRecord span = pending.back();
		pending.pop_back();
		result.popped_span_count += 1;
		if (span.level < 0 || span.level >= level_count || span.y < 0 || span.y >= height || span.x < 0 || span.x >= width) {
			result.out_of_bounds_span_count += 1;
			continue;
		}
		int32_t x = span.x;
		while (x > 0 && h3maped_cell_unassigned(zone_words, width, height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		bool wrote_any = false;
		bool upper_run_open = false;
		bool lower_run_open = false;
		SpanRecord upper_span;
		SpanRecord lower_span;
		for (; x < width && h3maped_cell_unassigned(zone_words, width, height, x, span.y, span.level); ++x) {
			const int64_t index = h3maped_cell_index(width, height, x, span.y, span.level);
			zone_words[size_t(index)] = (zone_words[size_t(index)] & H3MAPED_ZONE_WORD_CLEAR_MASK) | (uint32_t(zone_word_id & 0xff) << 16U);
			if (!(water_code == 2 && span.level == 1)) {
				cell_flags[size_t(index)] = uint8_t(cell_flags[size_t(index)] | 0x10U);
			}
			wrote_any = true;
			result.filled_cell_count += 1;
			append_span_fill_preview(result.trace_preview, x, span.y, span.level);

			const bool upper_open = span.y > 0 && h3maped_cell_unassigned(zone_words, width, height, x, span.y - 1, span.level);
			if (upper_open && !upper_run_open) {
				upper_span = SpanRecord{ x, span.y - 1, span.level };
				upper_run_open = true;
			} else if (!upper_open && upper_run_open) {
				push_span(upper_span);
				upper_run_open = false;
			}

			const bool lower_open = span.y + 1 < height && h3maped_cell_unassigned(zone_words, width, height, x, span.y + 1, span.level);
			if (lower_open && !lower_run_open) {
				lower_span = SpanRecord{ x, span.y + 1, span.level };
				lower_run_open = true;
			} else if (!lower_open && lower_run_open) {
				push_span(lower_span);
				lower_run_open = false;
			}
		}
		if (upper_run_open) {
			push_span(upper_span);
		}
		if (lower_run_open) {
			push_span(lower_span);
		}
		if (!wrote_any) {
			result.blocked_initial_span_count += 1;
		}
	}
	return result;
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
	report["verification_policy"] = "local_file_size_mz_header_and_sha256_checked_against_reset_anchor";
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
	const String actual_sha256 = FileAccess::get_sha256(BINARY_PATH);
	const bool sha256_matches = actual_sha256 == String(BINARY_SHA256);
	report["actual_size_bytes"] = size;
	report["actual_sha256"] = actual_sha256;
	report["sha256_matches"] = sha256_matches;
	report["mz_header_present"] = mz;
	report["ok"] = size == BINARY_SIZE_BYTES && mz && sha256_matches;
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

Dictionary adapted_template_for_id(const String &adapted_template_id) {
	if (adapted_template_id.is_empty()) {
		return Dictionary();
	}
	Dictionary catalog = load_json_dictionary(ADAPTED_CATALOG_PATH);
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
	return Dictionary();
}

Dictionary adapted_profile_for_template_id(const String &adapted_template_id) {
	if (adapted_template_id.is_empty()) {
		return Dictionary();
	}
	Dictionary catalog = load_json_dictionary(ADAPTED_CATALOG_PATH);
	Array profiles = catalog.get("profiles", Array());
	for (int64_t index = 0; index < profiles.size(); ++index) {
		if (Variant(profiles[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = profiles[index];
		if (String(candidate.get("template_id", "")) == adapted_template_id) {
			return candidate;
		}
	}
	return Dictionary();
}

bool player_filter_accepts(const Dictionary &filter, int32_t human_count, int32_t total_count) {
	return human_count >= int32_t(filter.get("min_human", 1))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& total_count >= int32_t(filter.get("min_total", 2))
			&& total_count <= int32_t(filter.get("max_total", 8));
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
		Dictionary item;
		item["x"] = candidates[size_t(index)].x;
		item["y"] = candidates[size_t(index)].y;
		item["level"] = candidates[size_t(index)].level;
		result.append(item);
	}
	return result;
}

String terrain_for_h3maped_id(int32_t terrain_id) {
	switch (terrain_id) {
		case 0:
			return "dirt";
		case 1:
			return "sand";
		case 2:
			return "grass";
		case 3:
			return "snow";
		case 4:
			return "swamp";
		case 5:
			return "rough";
		case 6:
			return "underground";
		case 7:
			return "lava";
		case 8:
			return "water";
		case 9:
			return "rock";
		default:
			return String();
	}
}

Dictionary tile_serializer_49b2b6_contract_report() {
	const uint32_t sample_cell_0x24 = (uint32_t(7) & 0x3fU)
			| ((uint32_t(0xab) & 0xffU) << 6U)
			| ((uint32_t(0x0c) & 0x0fU) << 14U)
			| ((uint32_t(0x5d) & 0xffU) << 18U)
			| ((uint32_t(0x09) & 0x0fU) << 26U);
	const uint32_t sample_cell_0x28 = (uint32_t(0x6e) & 0xffU)
			| ((uint32_t(0x5b) & 0x7fU) << 15U);
	Array sample_bytes;
	sample_bytes.append(int32_t(sample_cell_0x24 & 0x3fU));
	sample_bytes.append(int32_t((sample_cell_0x24 >> 6U) & 0xffU));
	sample_bytes.append(int32_t((sample_cell_0x24 >> 14U) & 0x0fU));
	sample_bytes.append(int32_t((sample_cell_0x24 >> 18U) & 0xffU));
	sample_bytes.append(int32_t((sample_cell_0x24 >> 26U) & 0x0fU));
	sample_bytes.append(int32_t(sample_cell_0x28 & 0xffU));
	sample_bytes.append(int32_t((sample_cell_0x28 >> 15U) & 0x7fU));

	Dictionary bitfields;
	bitfields["tile_byte_0"] = "cell+0x24 bits 0..5 terrain id";
	bitfields["tile_byte_1"] = "cell+0x24 bits 6..13 terrain art index";
	bitfields["tile_byte_2"] = "cell+0x24 bits 14..17 river type";
	bitfields["tile_byte_3"] = "cell+0x24 bits 18..25 river art";
	bitfields["tile_byte_4"] = "cell+0x24 bits 26..29 road type";
	bitfields["tile_byte_5"] = "cell+0x28 bits 0..7 road art";
	bitfields["tile_byte_6"] = "cell+0x28 bits 15..21 terrain/river/road flip flags";

	Dictionary report;
	report["status"] = "0x49b2b6_generated_cell_tile_serializer_bit_contract_ported";
	report["function_address"] = "0x49b2b6";
	report["source"] = "direct disassembly of h3maped.exe 0x49b2b6; each generated cell writes seven one-byte tile fields through writer virtual slot +0x08";
	report["cell_word_0x24_source"] = "generated cell +0x24";
	report["cell_word_0x28_source"] = "generated cell +0x28";
	report["bitfields"] = bitfields;
	report["sample_cell_word_0x24_uint32"] = int64_t(sample_cell_0x24);
	report["sample_cell_word_0x28_uint32"] = int64_t(sample_cell_0x28);
	report["sample_expected_tile_bytes"] = sample_bytes;
	report["sample_expected_tile_byte_count"] = sample_bytes.size();
	report["materializes_package_tiles"] = false;
	return report;
}

int64_t h3maped_va_to_file_offset(int64_t va) {
	return va - 0x400000;
}

bool read_h3maped_u8(Ref<FileAccess> &file, int64_t va, uint8_t &out_value) {
	if (file.is_null() || !file->is_open()) {
		return false;
	}
	const int64_t offset = h3maped_va_to_file_offset(va);
	if (offset < 0 || offset >= file->get_length()) {
		return false;
	}
	file->seek(offset);
	out_value = uint8_t(file->get_8());
	return true;
}

bool read_h3maped_u32_le(Ref<FileAccess> &file, int64_t va, uint32_t &out_value) {
	uint8_t b0 = 0;
	uint8_t b1 = 0;
	uint8_t b2 = 0;
	uint8_t b3 = 0;
	if (!read_h3maped_u8(file, va, b0) || !read_h3maped_u8(file, va + 1, b1) || !read_h3maped_u8(file, va + 2, b2) || !read_h3maped_u8(file, va + 3, b3)) {
		return false;
	}
	out_value = uint32_t(b0) | (uint32_t(b1) << 8U) | (uint32_t(b2) << 16U) | (uint32_t(b3) << 24U);
	return true;
}

String compact_row_ranges(const std::vector<int32_t> &rows) {
	if (rows.empty()) {
		return "-";
	}
	String result;
	int32_t start = rows[0];
	int32_t previous = rows[0];
	for (size_t index = 1; index < rows.size(); ++index) {
		const int32_t current = rows[index];
		if (current == previous + 1) {
			previous = current;
			continue;
		}
		if (!result.is_empty()) {
			result += ",";
		}
		result += start == previous ? String::num_int64(start) : String::num_int64(start) + "-" + String::num_int64(previous);
		start = current;
		previous = current;
	}
	if (!result.is_empty()) {
		result += ",";
	}
	result += start == previous ? String::num_int64(start) : String::num_int64(start) + "-" + String::num_int64(previous);
	return result;
}

PackedInt32Array packed_rows(const std::vector<int32_t> &rows) {
	PackedInt32Array packed;
	for (int32_t row : rows) {
		packed.append(row);
	}
	return packed;
}

Array class_range_records(const std::map<int32_t, std::vector<int32_t>> &rows_by_class) {
	Array records;
	for (const auto &entry : rows_by_class) {
		Dictionary record;
		record["class"] = entry.first;
		record["row_count"] = int32_t(entry.second.size());
		record["rows"] = packed_rows(entry.second);
		record["compact_rows"] = compact_row_ranges(entry.second);
		record["first_row"] = entry.second.empty() ? -1 : entry.second.front();
		record["last_row"] = entry.second.empty() ? -1 : entry.second.back();
		records.append(record);
	}
	return records;
}

Dictionary terrain_visual_table_contract(Ref<FileAccess> &file, const char *id, const char *terrain_ids, const char *address, int64_t table_va, int32_t row_count, bool include_flag_buckets) {
	std::vector<TerrainVisualRow> rows;
	rows.reserve(size_t(row_count));
	std::map<int32_t, std::vector<int32_t>> rows_by_class;
	std::map<std::array<int32_t, 3>, std::vector<int32_t>> rows_by_class_flags;
	bool ok = true;
	for (int32_t row_index = 0; row_index < row_count; ++row_index) {
		const int64_t row_va = table_va + int64_t(row_index) * 8;
		uint32_t shape_class = 0;
		uint8_t flag_a = 0;
		uint8_t flag_b = 0;
		if (!read_h3maped_u32_le(file, row_va, shape_class) || !read_h3maped_u8(file, row_va + 4, flag_a) || !read_h3maped_u8(file, row_va + 5, flag_b)) {
			ok = false;
			break;
		}
		TerrainVisualRow row;
		row.shape_class = int32_t(shape_class);
		row.flag_a = int32_t(flag_a);
		row.flag_b = int32_t(flag_b);
		rows.push_back(row);
		rows_by_class[row.shape_class].push_back(row_index);
		if (include_flag_buckets) {
			rows_by_class_flags[{ row.shape_class, row.flag_a, row.flag_b }].push_back(row_index);
		}
	}
	Dictionary report;
	report["id"] = id;
	report["terrain_ids"] = terrain_ids;
	report["table_address"] = address;
	report["table_file_offset"] = h3maped_va_to_file_offset(table_va);
	report["expected_row_count"] = row_count;
	report["decoded_row_count"] = int32_t(rows.size());
	report["status"] = ok && int32_t(rows.size()) == row_count ? String("decoded_from_h3maped_exe") : String("decode_failed");
	report["row_stride_bytes"] = 8;
	report["row_contract"] = "u32 class, u8 flag_a, u8 flag_b";
	report["unique_class_count"] = int32_t(rows_by_class.size());
	report["class_ranges"] = class_range_records(rows_by_class);
	if (include_flag_buckets) {
		Array flag_records;
		for (const auto &entry : rows_by_class_flags) {
			Dictionary flag_record;
			flag_record["class"] = entry.first[0];
			flag_record["flag_a"] = entry.first[1];
			flag_record["flag_b"] = entry.first[2];
			flag_record["row_count"] = int32_t(entry.second.size());
			flag_record["rows"] = packed_rows(entry.second);
			flag_record["compact_rows"] = compact_row_ranges(entry.second);
			flag_records.append(flag_record);
		}
		report["class_flag_ranges"] = flag_records;
	}
	return report;
}

std::vector<TerrainVisualRow> decode_terrain_visual_rows(Ref<FileAccess> &file, int64_t table_va, int32_t row_count) {
	std::vector<TerrainVisualRow> rows;
	rows.reserve(size_t(row_count));
	for (int32_t row_index = 0; row_index < row_count; ++row_index) {
		const int64_t row_va = table_va + int64_t(row_index) * 8;
		uint32_t shape_class = 0;
		uint8_t flag_a = 0;
		uint8_t flag_b = 0;
		if (!read_h3maped_u32_le(file, row_va, shape_class) || !read_h3maped_u8(file, row_va + 4, flag_a) || !read_h3maped_u8(file, row_va + 5, flag_b)) {
			return {};
		}
		TerrainVisualRow row;
		row.shape_class = int32_t(shape_class);
		row.flag_a = int32_t(flag_a);
		row.flag_b = int32_t(flag_b);
		rows.push_back(row);
	}
	return rows;
}

std::vector<int32_t> row_indices_for_class(const std::vector<TerrainVisualRow> &rows, int32_t shape_class) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_group(const std::vector<TerrainVisualRow> &rows, int32_t shape_class, int32_t group_flag) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class && rows[size_t(index)].flag_a == group_flag) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_flags(const std::vector<TerrainVisualRow> &rows, int32_t shape_class, int32_t flag_a, int32_t flag_b) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		const TerrainVisualRow &row = rows[size_t(index)];
		if (row.shape_class == shape_class && row.flag_a == flag_a && row.flag_b == flag_b) {
			indices.push_back(index);
		}
	}
	return indices;
}

Dictionary terrain_row_selection_sample(const char *id, const char *selector_address, const char *table_address, const char *selector_kind, const std::vector<TerrainVisualRow> &rows, int32_t shape_class, int32_t flag_a, int32_t flag_b, int32_t constructor_probability, bool full_native, bool rock_selector, uint32_t seed) {
	H3MapedRng rng;
	rng.state = seed;
	std::vector<int32_t> bucket;
	int32_t probability_rng_value = -1;
	int32_t art_rng_value = -1;
	int32_t probability_threshold = -1;
	bool selected_special_bucket = false;
	if (rock_selector) {
		bucket = row_indices_for_class_flags(rows, shape_class, flag_a, flag_b);
	} else if (full_native) {
		std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
		probability_rng_value = rng.next();
		probability_threshold = constructor_probability;
		selected_special_bucket = !special.empty() && (probability_rng_value % 100) < probability_threshold;
		bucket = selected_special_bucket ? special : ordinary;
	} else {
		bucket = row_indices_for_class(rows, shape_class);
	}
	if (bucket.empty()) {
		Dictionary failed;
		failed["id"] = id;
		failed["status"] = "missing_visual_row_bucket";
		failed["selector_address"] = selector_address;
		failed["table_address"] = table_address;
		failed["selector_kind"] = selector_kind;
		failed["class"] = shape_class;
		failed["flag_a"] = flag_a;
		failed["flag_b"] = flag_b;
		return failed;
	}
	art_rng_value = rng.next();
	const int32_t selected_row = bucket[size_t(art_rng_value % int32_t(bucket.size()))];
	Dictionary report;
	report["id"] = id;
	report["status"] = "visual_row_selected_from_decoded_h3maped_table";
	report["selector_address"] = selector_address;
	report["table_address"] = table_address;
	report["selector_kind"] = selector_kind;
	report["class"] = shape_class;
	report["flag_a"] = flag_a;
	report["flag_b"] = flag_b;
	report["old_index"] = -1;
	report["old_index_reused"] = false;
	report["rng_seed_uint32"] = int64_t(seed);
	report["probability_rng_value"] = probability_rng_value;
	report["probability_threshold"] = probability_threshold;
	report["selected_special_bucket"] = selected_special_bucket;
	report["art_rng_value"] = art_rng_value;
	report["bucket_count"] = int32_t(bucket.size());
	report["bucket_rows"] = packed_rows(bucket);
	report["bucket_compact_rows"] = compact_row_ranges(bucket);
	report["selected_row"] = selected_row;
	report["out_flag_a"] = rock_selector ? 0 : flag_a;
	report["out_flag_b"] = rock_selector ? 0 : flag_b;
	report["rng_state_after_uint32"] = int64_t(rng.state);
	return report;
}

Dictionary terrain_visual_row_selection_contract_report() {
	Dictionary report;
	report["status"] = "0x4ba938_0x4ba989_0x4baabf_visual_row_selection_ported_samples";
	report["source"] = "bounded row-selection samples using static terrain visual tables decoded from /root/Downloads/h3maped.exe";
	report["full_native_selector_address"] = "0x4ba938";
	report["normal_transition_selector_address"] = "0x4ba989";
	report["rock_selector_address"] = "0x4baabf";
	report["rng_address"] = "0x4e7276";
	report["materializes_visual_records"] = false;
	report["materializes_full_terrain_art_grid"] = false;
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["status"] = "h3maped_exe_missing";
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["status"] = "h3maped_exe_unreadable";
		return report;
	}
	const std::vector<TerrainVisualRow> normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	const std::vector<TerrainVisualRow> water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	const std::vector<TerrainVisualRow> rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);
	if (normal_rows.size() != 79 || water_rows.size() != 33 || rock_rows.size() != 48) {
		report["status"] = "h3maped_visual_row_decode_failed";
		return report;
	}
	Array samples;
	samples.append(terrain_row_selection_sample("normal_full_grass_seed_1", "0x4ba938", "0x543108", "normal_full_native_special_frequency", normal_rows, 0, 0, 0, 0x32, true, false, 1));
	samples.append(terrain_row_selection_sample("normal_transition_class_28_seed_1", "0x4ba989", "0x543108", "normal_transition_class_bucket", normal_rows, 28, 1, 0, 0x50, false, false, 1));
	samples.append(terrain_row_selection_sample("water_transition_class_16_seed_1", "0x4ba989", "0x5435b0", "water_normal_trait_transition_class_bucket", water_rows, 16, 0, 0, 0x00, false, false, 1));
	samples.append(terrain_row_selection_sample("rock_class_8_flag_1_0_seed_1", "0x4baabf", "0x542f88", "rock_class_flag_bucket", rock_rows, 8, 1, 0, 0x00, false, true, 1));
	report["sample_count"] = samples.size();
	report["samples"] = samples;
	report["blocked_next"] = "run row selection for the generated terrain grid, write scratch words through 0x4bad0f, then copy back through 0x49acf6";
	return report;
}

Dictionary terrain_scratch_write_sample(const char *id, int32_t terrain_id, int32_t selected_row, int32_t flag_a, int32_t flag_b) {
	const uint32_t scratch_word = 1U
			| ((uint32_t(terrain_id) & 0x0fU) << 1U)
			| ((uint32_t(selected_row) & 0x7fU) << 5U)
			| ((uint32_t(flag_a) & 0x01U) << 12U)
			| ((uint32_t(flag_b) & 0x01U) << 13U);
	const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU)
			| ((uint32_t(selected_row) & 0xffU) << 6U);
	const uint32_t generated_cell_word_0x28 = ((uint32_t(flag_a) & 0x01U) << 15U)
			| ((uint32_t(flag_b) & 0x01U) << 16U);
	Dictionary sample;
	sample["id"] = id;
	sample["terrain_id"] = terrain_id;
	sample["selected_row"] = selected_row;
	sample["flag_a"] = flag_a;
	sample["flag_b"] = flag_b;
	sample["scratch_word_u16"] = int32_t(scratch_word);
	sample["scratch_dirty_bit"] = int32_t(scratch_word & 0x01U);
	sample["scratch_terrain_bits_1_4"] = int32_t((scratch_word >> 1U) & 0x0fU);
	sample["scratch_art_bits_5_11"] = int32_t((scratch_word >> 5U) & 0x7fU);
	sample["scratch_flag_a_bit_12"] = int32_t((scratch_word >> 12U) & 0x01U);
	sample["scratch_flag_b_bit_13"] = int32_t((scratch_word >> 13U) & 0x01U);
	sample["generated_cell_word_0x24_u32"] = int64_t(generated_cell_word_0x24);
	sample["generated_cell_word_0x28_u32"] = int64_t(generated_cell_word_0x28);
	sample["tile_byte_0_terrain_id"] = int32_t(generated_cell_word_0x24 & 0x3fU);
	sample["tile_byte_1_terrain_art"] = int32_t((generated_cell_word_0x24 >> 6U) & 0xffU);
	sample["tile_byte_6_terrain_flags"] = int32_t((generated_cell_word_0x28 >> 15U) & 0x03U);
	return sample;
}

Dictionary terrain_scratch_write_contract_report() {
	Dictionary report;
	report["status"] = "0x4bad0f_scratch_word_and_0x49acf6_generated_cell_projection_ported_samples";
	report["scratch_write_address"] = "0x4bad0f";
	report["generated_cell_write_address"] = "0x49acf6";
	report["scratch_word_contract"] = "bit0 dirty, bits1..4 terrain id, bits5..11 terrain art row, bit12 flag A, bit13 flag B";
	report["generated_cell_contract"] = "cell+0x24 bits0..5 terrain id, bits6..13 terrain art; cell+0x28 bits15..16 terrain flags";
	report["materializes_generated_cell_words"] = false;
	report["materializes_package_tiles"] = false;
	Array samples;
	samples.append(terrain_scratch_write_sample("grass_full_row_60_flags_0_0", 2, 60, 0, 0));
	samples.append(terrain_scratch_write_sample("grass_class_28_row_77_flags_1_0", 2, 77, 1, 0));
	samples.append(terrain_scratch_write_sample("water_class_16_row_20_flags_0_0", 8, 20, 0, 0));
	samples.append(terrain_scratch_write_sample("rock_class_8_row_11_cleared_flags", 9, 11, 0, 0));
	report["sample_count"] = samples.size();
	report["samples"] = samples;
	report["blocked_next"] = "apply row selection and scratch/writeback projection across the generated terrain grid, then adopt art/flag bytes only after queue normalization is ported";
	return report;
}

PackedInt32Array final_sweep_boundary_counts_sample(const std::array<int32_t, 9> &owners) {
	PackedInt32Array counts;
	for (int32_t index = 0; index < 9; ++index) {
		counts.append(0);
	}
	auto owner_at = [&owners](int32_t x, int32_t y) -> int32_t {
		return owners[size_t(y * 3 + x)];
	};
	auto increment_if_different = [&](int32_t x, int32_t y, int32_t nx, int32_t ny) {
		if (nx < 0 || ny < 0 || nx >= 3 || ny >= 3) {
			return;
		}
		if (owner_at(x, y) == owner_at(nx, ny)) {
			return;
		}
		const int32_t index = y * 3 + x;
		const int32_t neighbor_index = ny * 3 + nx;
		counts.set(index, counts[index] + 1);
		counts.set(neighbor_index, counts[neighbor_index] + 1);
	};
	for (int32_t y = 0; y < 3; ++y) {
		for (int32_t x = 0; x < 3; ++x) {
			increment_if_different(x, y, x + 1, y);
			increment_if_different(x, y, x, y + 1);
			increment_if_different(x, y, x + 1, y + 1);
			increment_if_different(x, y, x - 1, y + 1);
		}
	}
	return counts;
}

PackedInt32Array packed_grid_3x3(const std::array<int32_t, 9> &values) {
	PackedInt32Array packed;
	for (int32_t value : values) {
		packed.append(value);
	}
	return packed;
}

Dictionary terrain_final_normalization_contract_report() {
	Dictionary report;
	report["status"] = "0x4bc5f0_0x4bbd01_0x4bbfcc_queue_and_final_sweep_contract_ported_boundary_only";
	report["queue_drain_address"] = "0x4bc5f0";
	report["frontier_processor_address"] = "0x4bbd01";
	report["candidate_gate_address"] = "0x4bc988";
	report["final_sweep_address"] = "0x4bbfcc";
	report["boundary_counter_branch_address"] = "0x4bc3dd..0x4bc566";
	report["set_a_offset"] = "this+0x14";
	report["set_a_count_offset"] = "this+0x20";
	report["set_b_offset"] = "this+0x24";
	report["set_b_count_offset"] = "this+0x30";
	report["drain_order"] = Array::make("drain set A with 0x4bbd01", "drain set B through 0x4bc988 and 0x4bb74b", "repeat until set A remains empty", "run 0x4bbfcc final whole-map sweep");
	report["set_a_semantics"] = "frontier/topology constraints consumed by 0x4bbd01";
	report["set_b_semantics"] = "candidate rewrites gated by 0x4bc988";
	report["final_sweep_adjacency_directions"] = Array::make("E", "S", "SE", "SW");
	report["final_correction_classes"] = Array::make("2->6", "8->12", "5->7", "11->13");
	report["zero_boundary_branch"] = "0x4bbfcc still normalizes full/native art and clears flags when boundary_count[cell] == 0";
	report["restricted_terrain_queue_invariant"] = "water/rock trait +5 == 0 uses topology queue repair so relation-only class 24 and rock class 16 do not reach stable final normalization";
	report["materializes_generated_cell_words"] = false;
	report["materializes_full_terrain_art_grid"] = false;
	report["materializes_package_tiles"] = false;
	const std::array<int32_t, 9> island_grid = { 0, 0, 0, 0, 2, 0, 0, 0, 0 };
	const std::array<int32_t, 9> flat_grid = { 2, 2, 2, 2, 2, 2, 2, 2, 2 };
	PackedInt32Array island_counts = final_sweep_boundary_counts_sample(island_grid);
	PackedInt32Array flat_counts = final_sweep_boundary_counts_sample(flat_grid);
	Dictionary sample;
	sample["owner_grid_row_major"] = packed_grid_3x3(island_grid);
	sample["boundary_counts_row_major"] = island_counts;
	sample["center_boundary_count"] = island_counts[4];
	sample["edge_neighbor_boundary_count"] = island_counts[1];
	sample["corner_neighbor_boundary_count"] = island_counts[0];
	sample["directions_scanned"] = report["final_sweep_adjacency_directions"];
	report["boundary_counter_sample"] = sample;
	Dictionary zero_sample;
	zero_sample["owner_grid_row_major"] = packed_grid_3x3(flat_grid);
	zero_sample["boundary_counts_row_major"] = flat_counts;
	zero_sample["requires_full_native_normalization_even_with_zero_boundary"] = true;
	report["zero_boundary_full_native_sample"] = zero_sample;
	report["blocked_next"] = "port queue drain and final sweep over the generated terrain grid before adopting terrain art/flag bytes";
	return report;
}

Dictionary generated_grid_final_sweep_boundary_counter_report(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_count) {
	Dictionary report;
	report["status"] = "0x4bbfcc_generated_grid_boundary_counter_applied_inspection_only";
	report["final_sweep_address"] = "0x4bbfcc";
	report["boundary_counter_branch_address"] = "0x4bc3dd..0x4bc566";
	report["adjacency_directions"] = Array::make("E", "S", "SE", "SW");
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;
	report["materializes_visual_records"] = false;
	report["materializes_full_terrain_art_grid"] = false;
	report["materializes_package_tiles"] = false;

	const int32_t level_tile_count = width * height;
	const int32_t expected_tile_count = level_tile_count * level_count;
	const int32_t tile_count = terrain_code_u16.size();
	report["expected_tile_count"] = expected_tile_count;
	report["tile_count"] = tile_count;
	report["input_matches_expected_tile_count"] = tile_count == expected_tile_count;

	PackedInt32Array boundary_counts;
	boundary_counts.resize(tile_count);
	int32_t boundary_adjacency_count = 0;
	int32_t total_boundary_increments = 0;
	auto terrain_at = [&terrain_code_u16](int32_t index) -> int32_t {
		if (index < 0 || index >= terrain_code_u16.size()) {
			return -1;
		}
		return terrain_code_u16[index];
	};
	auto increment_if_different = [&](int32_t base, int32_t x, int32_t y, int32_t nx, int32_t ny) {
		if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
			return;
		}
		const int32_t index = base + y * width + x;
		const int32_t neighbor_index = base + ny * width + nx;
		if (terrain_at(index) == terrain_at(neighbor_index)) {
			return;
		}
		boundary_counts.set(index, boundary_counts[index] + 1);
		boundary_counts.set(neighbor_index, boundary_counts[neighbor_index] + 1);
		boundary_adjacency_count += 1;
		total_boundary_increments += 2;
	};

	for (int32_t level = 0; level < level_count; ++level) {
		const int32_t base = level * level_tile_count;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				increment_if_different(base, x, y, x + 1, y);
				increment_if_different(base, x, y, x, y + 1);
				increment_if_different(base, x, y, x + 1, y + 1);
				increment_if_different(base, x, y, x - 1, y + 1);
			}
		}
	}

	int32_t boundary_cell_count = 0;
	int32_t zero_boundary_cell_count = 0;
	int32_t max_boundary_count = 0;
	Dictionary boundary_count_histogram;
	for (int32_t index = 0; index < boundary_counts.size(); ++index) {
		const int32_t count = boundary_counts[index];
		const String key = String::num_int64(count);
		boundary_count_histogram[key] = int32_t(boundary_count_histogram.get(key, 0)) + 1;
		if (count > 0) {
			boundary_cell_count += 1;
		} else {
			zero_boundary_cell_count += 1;
		}
		if (count > max_boundary_count) {
			max_boundary_count = count;
		}
	}
	report["boundary_counts_u8"] = boundary_counts;
	report["boundary_cell_count"] = boundary_cell_count;
	report["zero_boundary_cell_count"] = zero_boundary_cell_count;
	report["max_boundary_count"] = max_boundary_count;
	report["boundary_adjacency_count"] = boundary_adjacency_count;
	report["total_boundary_increments"] = total_boundary_increments;
	report["boundary_count_histogram"] = boundary_count_histogram;
	report["blocked_next"] = "run the recovered classifier/row selection/writeback over these generated-grid counters after queue normalization is ported";
	return report;
}

int32_t h3maped_terrain_relation_4bb039(int32_t center_terrain_id, int32_t neighbor_terrain_id);
TerrainClassResult h3maped_classify_4bb075(const std::array<int32_t, 8> &relations);
PackedInt32Array packed_relations(const std::array<int32_t, 8> &relations);

struct TerrainVisualGridTables {
	std::vector<TerrainVisualRow> dirt_rows;
	std::vector<TerrainVisualRow> sand_rows;
	std::vector<TerrainVisualRow> normal_rows;
	std::vector<TerrainVisualRow> water_rows;
	std::vector<TerrainVisualRow> rock_rows;
};

const std::vector<TerrainVisualRow> &visual_rows_for_terrain_id(const TerrainVisualGridTables &tables, int32_t terrain_id) {
	switch (terrain_id) {
		case 0:
			return tables.dirt_rows;
		case 1:
			return tables.sand_rows;
		case 8:
			return tables.water_rows;
		case 9:
			return tables.rock_rows;
		default:
			return tables.normal_rows;
	}
}

const char *visual_table_address_for_terrain_id(int32_t terrain_id) {
	switch (terrain_id) {
		case 0:
			return "0x543380";
		case 1:
			return "0x5434f0";
		case 8:
			return "0x5435b0";
		case 9:
			return "0x542f88";
		default:
			return "0x543108";
	}
}

int32_t constructor_probability_for_terrain_id(int32_t terrain_id) {
	switch (terrain_id) {
		case 0:
		case 2:
			return 0x32;
		case 1:
			return 0x46;
		case 6:
			return 0x3c;
		case 3:
		case 4:
		case 5:
		case 7:
			return 0x50;
		default:
			return 0x00;
	}
}

int32_t terrain_at_grid_index(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * width + x;
	if (index < 0 || index >= terrain_code_u16.size()) {
		return fallback_terrain_id;
	}
	return terrain_code_u16[index];
}

bool set_terrain_at_grid_index(PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return false;
	}
	const int32_t index = level * level_tile_count + y * width + x;
	if (index < 0 || index >= terrain_code_u16.size()) {
		return false;
	}
	if (terrain_code_u16[index] == terrain_id) {
		return false;
	}
	terrain_code_u16.set(index, terrain_id);
	return true;
}

PackedInt32Array h3maped_same_terrain_mask_4bc74c(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	PackedInt32Array mask;
	mask.resize(8);
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
			return false;
		}
		const int32_t index = level * level_tile_count + ny * width + nx;
		return index >= 0 && index < terrain_code_u16.size() && terrain_code_u16[index] == terrain_id;
	};
	const bool north = same(x, y - 1);
	const bool south = same(x, y + 1);
	const bool west = same(x - 1, y);
	const bool east = same(x + 1, y);
	mask.set(0, north ? 1 : 0);
	mask.set(4, south ? 1 : 0);
	mask.set(6, west ? 1 : 0);
	mask.set(2, east ? 1 : 0);
	mask.set(7, (north || west) && same(x - 1, y - 1) ? 1 : 0);
	mask.set(1, (north || east) && same(x + 1, y - 1) ? 1 : 0);
	mask.set(5, (south || west) && same(x - 1, y + 1) ? 1 : 0);
	mask.set(3, (south || east) && same(x + 1, y + 1) ? 1 : 0);
	return mask;
}

bool h3maped_same_class_region_gate_4bc928(const PackedInt32Array &mask) {
	if (mask.size() != 8) {
		return false;
	}
	int32_t cursor = 0;
	if (mask[0] != 0) {
		do {
			cursor = (cursor + 1) & 7;
			if (cursor == 0) {
				return false;
			}
		} while (mask[cursor] != 0);
	}
	const int32_t start_zero = cursor;
	int32_t scan = (cursor + 1) & 7;
	while (scan != start_zero && mask[scan] == 0) {
		scan = (scan + 1) & 7;
	}
	if (scan == start_zero) {
		return false;
	}
	do {
		scan = (scan + 1) & 7;
		if (scan == start_zero) {
			return false;
		}
	} while (mask[scan] != 0);
	do {
		scan = (scan + 1) & 7;
		if (scan == start_zero) {
			return false;
		}
	} while (mask[scan] == 0);
	return true;
}

bool h3maped_horizontal_pair_gate_4bc674(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= width - 1 || y < 0 || y >= height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool h3maped_vertical_pair_gate_4bc6e0(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= height - 1 || x < 0 || x >= width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool h3maped_toolkit_byte5_allows_same_class_gate(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool h3maped_candidate_gate_4bc988(bool horizontal_pair_gate, bool vertical_pair_gate, bool toolkit_byte5_allows_same_class_gate, bool same_class_region_gate) {
	if (horizontal_pair_gate || vertical_pair_gate) {
		return true;
	}
	return toolkit_byte5_allows_same_class_gate && same_class_region_gate;
}

bool h3maped_candidate_gate_4bc988_grid(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928(h3maped_same_terrain_mask_4bc74c(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id));
	return h3maped_candidate_gate_4bc988(horizontal_pair_gate, vertical_pair_gate, h3maped_toolkit_byte5_allows_same_class_gate(terrain_id), same_class_region_gate);
}

String h3maped_candidate_gate_branch(bool horizontal_pair_gate, bool vertical_pair_gate, bool toolkit_byte5_allows_same_class_gate, bool same_class_region_gate, bool candidate_gate) {
	if (horizontal_pair_gate) {
		return "0x4bba13_0x4bc674_horizontal_pair_gate";
	}
	if (vertical_pair_gate) {
		return "0x4bba36_0x4bc6e0_vertical_pair_gate";
	}
	if (toolkit_byte5_allows_same_class_gate && same_class_region_gate) {
		return "0x4bc928_same_class_region_gate";
	}
	return candidate_gate ? String("0x4bc988_candidate_gate_true") : String("0x4bc988_candidate_gate_false");
}

Dictionary h3maped_retouch_target_record(const char *branch, int32_t from_x, int32_t from_y, int32_t target_x, int32_t target_y, int32_t terrain_id, bool changed) {
	Dictionary record;
	record["branch"] = branch;
	record["from_x"] = from_x;
	record["from_y"] = from_y;
	record["target_x"] = target_x;
	record["target_y"] = target_y;
	record["terrain_id"] = terrain_id;
	record["changed_terrain"] = changed;
	return record;
}

int32_t h3maped_frontier_retouch_4bbd01(PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, Array *sample_records, int32_t sample_limit) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](const char *branch, int32_t target_x, int32_t target_y) {
		const bool changed = set_terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, target_x, target_y, terrain_id);
		if (changed) {
			changed_count += 1;
		}
		if (sample_records != nullptr && sample_records->size() < sample_limit) {
			sample_records->append(h3maped_retouch_target_record(branch, x, y, target_x, target_y, terrain_id, changed));
		}
	};
	if (h3maped_vertical_pair_gate_4bc6e0(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = h3maped_candidate_gate_4bc988_grid(terrain_code_u16, width, height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = h3maped_candidate_gate_4bc988_grid(terrain_code_u16, width, height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_code_u16, width, height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_code_u16, width, height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(choose_upper ? "0x4bbd01_vertical_upper" : "0x4bbd01_vertical_lower", x, choose_upper ? y - 1 : y + 1);
	}
	if (h3maped_horizontal_pair_gate_4bc674(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = h3maped_candidate_gate_4bc988_grid(terrain_code_u16, width, height, level_tile_count, level, x - 1, y);
		const bool right_candidate = h3maped_candidate_gate_4bc988_grid(terrain_code_u16, width, height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_code_u16, width, height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_code_u16, width, height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? "0x4bbd01_horizontal_left" : "0x4bbd01_horizontal_right", choose_left ? x - 1 : x + 1, y);
	}
	const PackedInt32Array same_terrain_mask = h3maped_same_terrain_mask_4bc74c(terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id);
	if (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && h3maped_same_class_region_gate_4bc928(same_terrain_mask)) {
		int32_t start_zero = 0;
		if (same_terrain_mask[0] != 0) {
			do {
				start_zero = (start_zero + 1) & 7;
				if (start_zero == 0) {
					return changed_count;
				}
			} while (same_terrain_mask[start_zero] != 0);
		}
		struct ZeroRun {
			int32_t score = 0;
			int32_t start = 0;
			int32_t length = 0;
		};
		std::vector<ZeroRun> runs;
		int32_t scan = start_zero;
		while (true) {
			scan = (scan + 1) & 7;
			if (scan == start_zero) {
				break;
			}
			if (same_terrain_mask[scan] != 0) {
				continue;
			}
			ZeroRun run;
			run.start = scan;
			do {
				run.score += (scan & 1) != 0 ? 1 : 2;
				run.length += 1;
				scan = (scan + 1) & 7;
				if (scan == start_zero) {
					break;
				}
			} while (same_terrain_mask[scan] == 0);
			runs.push_back(run);
			if (scan == start_zero) {
				break;
			}
		}
		if (!runs.empty()) {
			const ZeroRun *best = &runs.front();
			for (const ZeroRun &run : runs) {
				if (run.score < best->score) {
					best = &run;
				}
			}
			static constexpr int32_t DX[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
			static constexpr int32_t DY[8] = { -1, -1, 0, 1, 1, 1, 0, -1 };
			int32_t slot = best->start;
			const int32_t end = (best->start + best->length) & 7;
			while (slot != end) {
				const int32_t target_x = x + DX[slot];
				const int32_t target_y = y + DY[slot];
				const bool boundary_allowed = target_x >= 0 && target_y >= 0 && target_x < width && target_y < height;
				if (boundary_allowed) {
					retouch("0x4bbd01_same_class_zero_run", target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
}

void increment_bool_histogram(Dictionary &histogram, bool value) {
	const String key = value ? "true" : "false";
	histogram[key] = int32_t(histogram.get(key, 0)) + 1;
}

bool visual_row_bucket_exists_for_grid_cell(const TerrainVisualGridTables &tables, int32_t terrain_id, const TerrainClassResult &classified) {
	const std::vector<TerrainVisualRow> &rows = visual_rows_for_terrain_id(tables, terrain_id);
	if (terrain_id == 9) {
		return !row_indices_for_class_flags(rows, classified.shape_class, classified.flag_a, classified.flag_b).empty();
	}
	if (classified.shape_class == 0) {
		return !row_indices_for_class_group(rows, 0, 0).empty() || !row_indices_for_class_group(rows, 0, 1).empty();
	}
	return !row_indices_for_class(rows, classified.shape_class).empty();
}

TerrainClassResult classify_grid_cell(const PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	std::array<int32_t, 8> relations = {
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y - 1, center)),
	};
	return h3maped_classify_4bb075(relations);
}

Dictionary h3maped_queue_retouch_projection_report(const PackedInt32Array &terrain_code_u16, const TerrainVisualGridTables &tables, int32_t width, int32_t height, int32_t level_count) {
	Dictionary report;
	report["status"] = "0x4bbd01_missing_bucket_retouch_projection_inspection_only";
	report["source"] = "applies the recovered 0x4bbd01 vertical/horizontal retouch decisions to a copy of the generated terrain grid for missing visual-row bucket cells only";
	report["ported_addresses"] = Array::make("0x4bbd01", "0x4bc988", "0x4bc674", "0x4bc6e0", "0x4bb74b");
	report["materializes_package_tiles"] = false;
	report["adopts_into_runtime_grid"] = false;
	PackedInt32Array retouched = terrain_code_u16;
	const int32_t level_tile_count = width * height;
	int32_t initial_missing_count = 0;
	int32_t final_missing_count = 0;
	int32_t retouched_cell_write_count = 0;
	Array retouch_samples;
	Dictionary missing_class_histogram_after;
	for (int32_t pass = 0; pass < 4; ++pass) {
		Array missing_cells;
		for (int32_t level = 0; level < level_count; ++level) {
			for (int32_t y = 0; y < height; ++y) {
				for (int32_t x = 0; x < width; ++x) {
					const int32_t index = level * level_tile_count + y * width + x;
					if (index < 0 || index >= retouched.size()) {
						continue;
					}
					const int32_t center = retouched[index];
					const TerrainClassResult classified = classify_grid_cell(retouched, width, height, level_tile_count, level, x, y, center);
					if (!visual_row_bucket_exists_for_grid_cell(tables, center, classified)) {
						Dictionary cell;
						cell["x"] = x;
						cell["y"] = y;
						cell["level"] = level;
						cell["terrain_id"] = center;
						cell["class"] = classified.shape_class;
						missing_cells.append(cell);
					}
				}
			}
		}
		if (pass == 0) {
			initial_missing_count = missing_cells.size();
		}
		if (missing_cells.is_empty()) {
			break;
		}
		int32_t pass_write_count = 0;
		for (int64_t i = 0; i < missing_cells.size(); ++i) {
			Dictionary cell = missing_cells[i];
			pass_write_count += h3maped_frontier_retouch_4bbd01(retouched, width, height, level_tile_count, int32_t(cell.get("level", 0)), int32_t(cell.get("x", 0)), int32_t(cell.get("y", 0)), &retouch_samples, 16);
		}
		retouched_cell_write_count += pass_write_count;
		if (pass_write_count == 0) {
			break;
		}
	}
	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int32_t index = level * level_tile_count + y * width + x;
				if (index < 0 || index >= retouched.size()) {
					continue;
				}
				const int32_t center = retouched[index];
				const TerrainClassResult classified = classify_grid_cell(retouched, width, height, level_tile_count, level, x, y, center);
				if (!visual_row_bucket_exists_for_grid_cell(tables, center, classified)) {
					final_missing_count += 1;
					const String class_key = String::num_int64(classified.shape_class);
					missing_class_histogram_after[class_key] = int32_t(missing_class_histogram_after.get(class_key, 0)) + 1;
				}
			}
		}
	}
	report["initial_missing_bucket_cell_count"] = initial_missing_count;
	report["retouched_cell_write_count"] = retouched_cell_write_count;
	report["post_retouch_missing_bucket_cell_count"] = final_missing_count;
	report["post_retouch_full_grid_projection_complete"] = final_missing_count == 0;
	report["post_retouch_missing_class_histogram"] = missing_class_histogram_after;
	report["retouch_samples"] = retouch_samples;
	report["retouched_terrain_code_u16"] = retouched;
	report["blocked_next"] = "replace missing-bucket-only projection with the full 0x4bc5f0 set A/B queue drain seeded by actual 0x4bb74b repaint order before runtime adoption";
	return report;
}

bool select_visual_row_for_grid_cell(const std::vector<TerrainVisualRow> &rows, int32_t terrain_id, const TerrainClassResult &classified, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b, String &selector_address, String &selector_kind) {
	std::vector<int32_t> bucket;
	const bool rock_selector = terrain_id == 9;
	if (rock_selector) {
		selector_address = "0x4baabf";
		selector_kind = "rock_class_flag_bucket";
		bucket = row_indices_for_class_flags(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		selector_address = "0x4ba938";
		selector_kind = "full_native_special_frequency";
		std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
		const int32_t probability_rng_value = rng.next();
		const int32_t probability_threshold = constructor_probability_for_terrain_id(terrain_id);
		const bool selected_special_bucket = !special.empty() && (probability_rng_value % 100) < probability_threshold;
		bucket = selected_special_bucket ? special : ordinary;
		out_flag_a = 0;
		out_flag_b = 0;
	} else {
		selector_address = "0x4ba989";
		selector_kind = "transition_class_bucket";
		bucket = row_indices_for_class(rows, classified.shape_class);
		out_flag_a = classified.flag_a;
		out_flag_b = classified.flag_b;
	}
	if (bucket.empty()) {
		selected_row = -1;
		return false;
	}
	const int32_t art_rng_value = rng.next();
	selected_row = bucket[size_t(art_rng_value % int32_t(bucket.size()))];
	return true;
}

Dictionary generated_grid_visual_projection_report(const PackedInt32Array &terrain_code_u16, const PackedInt32Array &boundary_counts, int32_t width, int32_t height, int32_t level_count, uint32_t rng_state_before_visual_selection) {
	Dictionary report;
	report["status"] = "0x4bb075_0x4ba938_0x4ba989_0x4bad0f_0x49acf6_generated_grid_projection_inspection_only";
	report["source"] = "grid-wide inspection replay using recovered h3maped relation classifier, decoded static row tables, scratch word packing, and generated-cell bit projection; public tile-byte adoption remains blocked";
	report["relation_address"] = "0x4bb039";
	report["classifier_address"] = "0x4bb075";
	report["row_selector_addresses"] = Array::make("0x4ba938", "0x4ba989", "0x4baabf");
	report["scratch_write_address"] = "0x4bad0f";
	report["generated_cell_write_address"] = "0x49acf6";
	report["edge_neighbor_policy"] = "out-of-map neighbors use the center terrain id for this inspection replay";
	report["replay_order"] = "row-major generated terrain grid after 0x4a3f27 byte-zero writeout";
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;
	report["tile_count"] = terrain_code_u16.size();
	report["rng_state_before_visual_selection_uint32"] = int64_t(rng_state_before_visual_selection);
	report["adopts_into_tile_byte_arrays"] = false;
	report["materializes_projected_generated_cell_words"] = true;
	report["materializes_package_tiles"] = false;

	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["status"] = "h3maped_exe_missing";
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["status"] = "h3maped_exe_unreadable";
		return report;
	}
	TerrainVisualGridTables tables;
	tables.dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
	tables.sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
	tables.normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	tables.water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	tables.rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);
	if (tables.dirt_rows.size() != 46 || tables.sand_rows.size() != 24 || tables.normal_rows.size() != 79 || tables.water_rows.size() != 33 || tables.rock_rows.size() != 48) {
		report["status"] = "h3maped_visual_row_decode_failed";
		return report;
	}

	const int32_t level_tile_count = width * height;
	PackedInt32Array projected_cell_word_0x24_u32;
	PackedInt32Array projected_cell_word_0x28_u32;
	PackedInt32Array projected_tile_byte_1_terrain_art_u8;
	PackedInt32Array projected_tile_byte_6_terrain_flags_u8;
	projected_cell_word_0x24_u32.resize(terrain_code_u16.size());
	projected_cell_word_0x28_u32.resize(terrain_code_u16.size());
	projected_tile_byte_1_terrain_art_u8.resize(terrain_code_u16.size());
	projected_tile_byte_6_terrain_flags_u8.resize(terrain_code_u16.size());

	H3MapedRng rng{ rng_state_before_visual_selection };
	Dictionary class_histogram;
	Dictionary terrain_histogram;
	Dictionary selected_row_histogram;
	Dictionary table_histogram;
	Dictionary missing_bucket_class_histogram;
	Dictionary missing_bucket_terrain_histogram;
	Dictionary missing_bucket_table_histogram;
	Dictionary queue_frontier_horizontal_pair_gate_histogram;
	Dictionary queue_frontier_vertical_pair_gate_histogram;
	Dictionary queue_frontier_same_class_region_gate_histogram;
	Dictionary queue_frontier_candidate_gate_histogram;
	Dictionary queue_frontier_branch_histogram;
	Array sample_records;
	Array missing_bucket_samples;
	int32_t projected_cell_count = 0;
	int32_t missing_bucket_cell_count = 0;
	int32_t queue_frontier_candidate_gate_true_count = 0;
	int32_t boundary_cell_projected_count = 0;
	int32_t zero_boundary_cell_projected_count = 0;
	int32_t terrain_art_nonzero_cell_count = 0;
	int32_t terrain_flag_cell_count = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int32_t index = level * level_tile_count + y * width + x;
				if (index < 0 || index >= terrain_code_u16.size()) {
					continue;
				}
				const int32_t center = terrain_code_u16[index];
				std::array<int32_t, 8> relations = {
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y - 1, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y - 1, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x + 1, y + 1, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x, y + 1, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y + 1, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y, center)),
					h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_code_u16, width, height, level_tile_count, level, x - 1, y - 1, center)),
				};
				const TerrainClassResult classified = h3maped_classify_4bb075(relations);
				int32_t selected_row = -1;
				int32_t out_flag_a = 0;
				int32_t out_flag_b = 0;
				String selector_address;
				String selector_kind;
				const std::vector<TerrainVisualRow> &rows = visual_rows_for_terrain_id(tables, center);
				const bool selected = select_visual_row_for_grid_cell(rows, center, classified, rng, selected_row, out_flag_a, out_flag_b, selector_address, selector_kind);
				const String class_key = String::num_int64(classified.shape_class);
				class_histogram[class_key] = int32_t(class_histogram.get(class_key, 0)) + 1;
				const String terrain_key = String::num_int64(center);
				terrain_histogram[terrain_key] = int32_t(terrain_histogram.get(terrain_key, 0)) + 1;
				const String table_address = visual_table_address_for_terrain_id(center);
				table_histogram[table_address] = int32_t(table_histogram.get(table_address, 0)) + 1;
				if (!selected) {
					missing_bucket_cell_count += 1;
					missing_bucket_class_histogram[class_key] = int32_t(missing_bucket_class_histogram.get(class_key, 0)) + 1;
					missing_bucket_terrain_histogram[terrain_key] = int32_t(missing_bucket_terrain_histogram.get(terrain_key, 0)) + 1;
					missing_bucket_table_histogram[table_address] = int32_t(missing_bucket_table_histogram.get(table_address, 0)) + 1;
					const PackedInt32Array same_terrain_mask = h3maped_same_terrain_mask_4bc74c(terrain_code_u16, width, height, level_tile_count, level, x, y, center);
					const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674(terrain_code_u16, width, height, level_tile_count, level, x, y, center);
					const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0(terrain_code_u16, width, height, level_tile_count, level, x, y, center);
					const bool toolkit_byte5_allows_same_class_gate = h3maped_toolkit_byte5_allows_same_class_gate(center);
					const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928(same_terrain_mask);
					const bool candidate_gate = h3maped_candidate_gate_4bc988(horizontal_pair_gate, vertical_pair_gate, toolkit_byte5_allows_same_class_gate, same_class_region_gate);
					const String queue_branch = h3maped_candidate_gate_branch(horizontal_pair_gate, vertical_pair_gate, toolkit_byte5_allows_same_class_gate, same_class_region_gate, candidate_gate);
					increment_bool_histogram(queue_frontier_horizontal_pair_gate_histogram, horizontal_pair_gate);
					increment_bool_histogram(queue_frontier_vertical_pair_gate_histogram, vertical_pair_gate);
					increment_bool_histogram(queue_frontier_same_class_region_gate_histogram, same_class_region_gate);
					increment_bool_histogram(queue_frontier_candidate_gate_histogram, candidate_gate);
					queue_frontier_branch_histogram[queue_branch] = int32_t(queue_frontier_branch_histogram.get(queue_branch, 0)) + 1;
					if (candidate_gate) {
						queue_frontier_candidate_gate_true_count += 1;
					}
					if (missing_bucket_samples.size() < 8) {
						Dictionary missing;
						missing["index"] = index;
						missing["x"] = x;
						missing["y"] = y;
						missing["level"] = level;
						missing["terrain_id"] = center;
						missing["boundary_count"] = index < boundary_counts.size() ? boundary_counts[index] : 0;
						missing["relations_slot_order"] = "N,NE,E,SE,S,SW,W,NW";
						missing["relations"] = packed_relations(relations);
						missing["class"] = classified.shape_class;
						missing["flag_a"] = classified.flag_a;
						missing["flag_b"] = classified.flag_b;
						missing["visual_table_address"] = table_address;
						missing["selector_address"] = selector_address;
						missing["selector_kind"] = selector_kind;
						missing["blocked_reason"] = "classified shape has no decoded h3maped visual row before queue/topology normalization";
						missing["same_terrain_mask_address"] = "0x4bc74c";
						missing["same_terrain_mask_slot_order"] = "N,NE,E,SE,S,SW,W,NW";
						missing["same_terrain_mask"] = same_terrain_mask;
						missing["horizontal_pair_gate_address"] = "0x4bc674";
						missing["horizontal_pair_gate"] = horizontal_pair_gate;
						missing["vertical_pair_gate_address"] = "0x4bc6e0";
						missing["vertical_pair_gate"] = vertical_pair_gate;
						missing["toolkit_byte5_allows_same_class_gate"] = toolkit_byte5_allows_same_class_gate;
						missing["same_class_region_gate_address"] = "0x4bc928";
						missing["same_class_region_gate"] = same_class_region_gate;
						missing["candidate_gate_address"] = "0x4bc988";
						missing["candidate_gate"] = candidate_gate;
						missing["candidate_gate_branch"] = queue_branch;
						missing_bucket_samples.append(missing);
					}
					continue;
				}
				const uint32_t generated_cell_word_0x24 = (uint32_t(center) & 0x3fU)
						| ((uint32_t(selected_row) & 0xffU) << 6U);
				const uint32_t generated_cell_word_0x28 = ((uint32_t(out_flag_a) & 0x01U) << 15U)
						| ((uint32_t(out_flag_b) & 0x01U) << 16U);
				projected_cell_word_0x24_u32.set(index, int32_t(generated_cell_word_0x24));
				projected_cell_word_0x28_u32.set(index, int32_t(generated_cell_word_0x28));
				projected_tile_byte_1_terrain_art_u8.set(index, selected_row);
				projected_tile_byte_6_terrain_flags_u8.set(index, int32_t((generated_cell_word_0x28 >> 15U) & 0x03U));
				const String row_key = String::num_int64(selected_row);
				selected_row_histogram[row_key] = int32_t(selected_row_histogram.get(row_key, 0)) + 1;
				projected_cell_count += 1;
				if (selected_row != 0) {
					terrain_art_nonzero_cell_count += 1;
				}
				if (((generated_cell_word_0x28 >> 15U) & 0x03U) != 0U) {
					terrain_flag_cell_count += 1;
				}
				const int32_t boundary_count = index < boundary_counts.size() ? boundary_counts[index] : 0;
				if (boundary_count > 0) {
					boundary_cell_projected_count += 1;
				} else {
					zero_boundary_cell_projected_count += 1;
				}
				if (sample_records.size() < 8 && boundary_count > 0) {
					Dictionary sample;
					sample["index"] = index;
					sample["x"] = x;
					sample["y"] = y;
					sample["level"] = level;
					sample["terrain_id"] = center;
					sample["boundary_count"] = boundary_count;
					sample["relations_slot_order"] = "N,NE,E,SE,S,SW,W,NW";
					sample["relations"] = packed_relations(relations);
					sample["class"] = classified.shape_class;
					sample["flag_a"] = classified.flag_a;
					sample["flag_b"] = classified.flag_b;
					sample["selector_address"] = selector_address;
					sample["selector_kind"] = selector_kind;
					sample["visual_table_address"] = table_address;
					sample["selected_row"] = selected_row;
					sample["out_flag_a"] = out_flag_a;
					sample["out_flag_b"] = out_flag_b;
					sample["projected_cell_word_0x24_u32"] = int64_t(generated_cell_word_0x24);
					sample["projected_cell_word_0x28_u32"] = int64_t(generated_cell_word_0x28);
					sample_records.append(sample);
				}
			}
		}
	}

	report["projected_cell_count"] = projected_cell_count;
	report["missing_bucket_cell_count"] = missing_bucket_cell_count;
	report["full_grid_projection_complete"] = missing_bucket_cell_count == 0;
	report["queue_normalization_required_cell_count"] = missing_bucket_cell_count;
	report["boundary_cell_projected_count"] = boundary_cell_projected_count;
	report["zero_boundary_cell_projected_count"] = zero_boundary_cell_projected_count;
	report["terrain_art_nonzero_cell_count"] = terrain_art_nonzero_cell_count;
	report["terrain_flag_cell_count"] = terrain_flag_cell_count;
	report["class_histogram"] = class_histogram;
	report["terrain_histogram"] = terrain_histogram;
	report["selected_row_histogram"] = selected_row_histogram;
	report["table_histogram"] = table_histogram;
	report["missing_bucket_class_histogram"] = missing_bucket_class_histogram;
	report["missing_bucket_terrain_histogram"] = missing_bucket_terrain_histogram;
	report["missing_bucket_table_histogram"] = missing_bucket_table_histogram;
	report["sample_records"] = sample_records;
	report["missing_bucket_samples"] = missing_bucket_samples;
	Dictionary queue_frontier_report;
	queue_frontier_report["status"] = "0x4bc74c_0x4bc928_0x4bc674_0x4bc6e0_0x4bc988_missing_bucket_frontier_gates_ported_inspection_only";
	queue_frontier_report["source"] = "bounded port of h3maped TerrainPlacement queue/candidate gate helpers over the cells that still lack decoded visual-row buckets";
	queue_frontier_report["ported_addresses"] = Array::make("0x4bc74c", "0x4bc928", "0x4bc674", "0x4bc6e0", "0x4bc988", "0x4bbd01");
	queue_frontier_report["frontier_processor_address"] = "0x4bbd01";
	queue_frontier_report["candidate_gate_address"] = "0x4bc988";
	queue_frontier_report["same_terrain_mask_address"] = "0x4bc74c";
	queue_frontier_report["same_class_region_gate_address"] = "0x4bc928";
	queue_frontier_report["horizontal_pair_gate_address"] = "0x4bc674";
	queue_frontier_report["vertical_pair_gate_address"] = "0x4bc6e0";
	queue_frontier_report["slot_order"] = "N,NE,E,SE,S,SW,W,NW";
	queue_frontier_report["reported_missing_bucket_cell_count"] = missing_bucket_cell_count;
	queue_frontier_report["candidate_gate_true_cell_count"] = queue_frontier_candidate_gate_true_count;
	queue_frontier_report["candidate_gate_false_cell_count"] = missing_bucket_cell_count - queue_frontier_candidate_gate_true_count;
	queue_frontier_report["horizontal_pair_gate_histogram"] = queue_frontier_horizontal_pair_gate_histogram;
	queue_frontier_report["vertical_pair_gate_histogram"] = queue_frontier_vertical_pair_gate_histogram;
	queue_frontier_report["same_class_region_gate_histogram"] = queue_frontier_same_class_region_gate_histogram;
	queue_frontier_report["candidate_gate_histogram"] = queue_frontier_candidate_gate_histogram;
	queue_frontier_report["branch_histogram"] = queue_frontier_branch_histogram;
	queue_frontier_report["materializes_queue_retouches"] = false;
	queue_frontier_report["materializes_package_tiles"] = false;
	queue_frontier_report["blocked_next"] = "execute the full 0x4bc5f0 queue drain and 0x4bbd01 retouch updates instead of only reporting candidate gates";
	report["terrain_queue_frontier_gap_report_status"] = queue_frontier_report["status"];
	report["terrain_queue_frontier_gap_report"] = queue_frontier_report;
	Dictionary queue_retouch_projection = h3maped_queue_retouch_projection_report(terrain_code_u16, tables, width, height, level_count);
	report["terrain_queue_retouch_projection_status"] = queue_retouch_projection["status"];
	report["terrain_queue_retouch_projection"] = queue_retouch_projection;
	report["projected_cell_word_0x24_u32"] = projected_cell_word_0x24_u32;
	report["projected_cell_word_0x28_u32"] = projected_cell_word_0x28_u32;
	report["projected_tile_byte_1_terrain_art_u8"] = projected_tile_byte_1_terrain_art_u8;
	report["projected_tile_byte_6_terrain_flags_u8"] = projected_tile_byte_6_terrain_flags_u8;
	report["rng_state_after_visual_selection_uint32"] = int64_t(rng.state);
	report["blocked_next"] = "replace this inspection replay with exact TerrainPlacement queue/repaint order adoption before writing tile bytes into public packages";
	return report;
}

Dictionary terrain_visual_static_table_contracts_report() {
	Dictionary report;
	report["status"] = "h3maped_exe_static_terrain_visual_tables_decoded";
	report["source"] = "direct decode from /root/Downloads/h3maped.exe static terrain row tables; file offset = VA - 0x400000 for these table addresses";
	report["binary_path"] = BINARY_PATH;
	report["binary_sha256_anchor"] = BINARY_SHA256;
	report["normal_table_address"] = "0x543108";
	report["dirt_table_address"] = "0x543380";
	report["sand_table_address"] = "0x5434f0";
	report["water_table_address"] = "0x5435b0";
	report["rock_table_address"] = "0x542f88";
	report["materializes_visual_records"] = false;
	report["materializes_full_terrain_art_grid"] = false;
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["status"] = "h3maped_exe_missing";
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["status"] = "h3maped_exe_unreadable";
		return report;
	}
	Array tables;
	tables.append(terrain_visual_table_contract(file, "normal_land_terrain_ids_2_7", "2,3,4,5,6,7", "0x543108", 0x543108, 79, false));
	tables.append(terrain_visual_table_contract(file, "dirt_terrain_id_0", "0", "0x543380", 0x543380, 46, false));
	tables.append(terrain_visual_table_contract(file, "sand_terrain_id_1", "1", "0x5434f0", 0x5434f0, 24, false));
	tables.append(terrain_visual_table_contract(file, "water_terrain_id_8", "8", "0x5435b0", 0x5435b0, 33, false));
	tables.append(terrain_visual_table_contract(file, "rock_terrain_id_9", "9", "0x542f88", 0x542f88, 48, true));
	int32_t decoded_total = 0;
	bool ok = true;
	for (int64_t index = 0; index < tables.size(); ++index) {
		Dictionary table = tables[index];
		decoded_total += int32_t(table.get("decoded_row_count", 0));
		ok = ok && String(table.get("status", "")) == "decoded_from_h3maped_exe";
	}
	report["table_count"] = tables.size();
	report["decoded_total_row_count"] = decoded_total;
	report["expected_total_row_count"] = 79 + 46 + 24 + 33 + 48;
	report["tables"] = tables;
	report["status"] = ok && decoded_total == int32_t(report["expected_total_row_count"])
			? String("h3maped_exe_static_terrain_visual_tables_decoded")
			: String("h3maped_exe_static_terrain_visual_table_decode_failed");
	return report;
}

int32_t terrain_trait_flag4(int32_t terrain_id) {
	switch (terrain_id) {
		case 0:
		case 2:
		case 3:
		case 4:
		case 5:
		case 6:
		case 7:
			return 1;
		default:
			return 0;
	}
}

int32_t h3maped_terrain_relation_4bb039(int32_t center_terrain_id, int32_t neighbor_terrain_id) {
	if (center_terrain_id == neighbor_terrain_id) {
		return 0;
	}
	if (center_terrain_id == 1) {
		return 0;
	}
	if (terrain_trait_flag4(center_terrain_id) == 0) {
		return 2;
	}
	if (terrain_trait_flag4(neighbor_terrain_id) == 0) {
		return 2;
	}
	return center_terrain_id != 0 ? 1 : 0;
}

int32_t orientation_slot_5436e0(int32_t flag_a, int32_t flag_b, int32_t slot, bool transposed_index = false) {
	static constexpr int32_t ORIENTATION[4][8] = {
		{ 0, 1, 2, 3, 4, 5, 6, 7 },
		{ 4, 3, 2, 1, 0, 7, 6, 5 },
		{ 0, 7, 6, 5, 4, 3, 2, 1 },
		{ 4, 5, 6, 7, 0, 1, 2, 3 },
	};
	const int32_t table_index = transposed_index ? flag_a + flag_b * 2 : flag_b + flag_a * 2;
	if (table_index < 0 || table_index >= 4 || slot < 0 || slot >= 8) {
		return slot;
	}
	return ORIENTATION[table_index][slot];
}

int32_t relation_at_oriented(const std::array<int32_t, 8> &relations, int32_t flag_a, int32_t flag_b, int32_t slot, bool transposed_index = false) {
	return relations[size_t(orientation_slot_5436e0(flag_a, flag_b, slot, transposed_index))];
}

TerrainClassResult h3maped_classify_4bb075(const std::array<int32_t, 8> &relations) {
	static constexpr std::array<std::array<int32_t, 2>, 4> FLAGS = { { { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } } };
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(2) == 1 && r(4) == 1) {
			if (r(1) == 2 && r(5) == 2) {
				return { 0x1c, a, b, "E=1,S=1,NE=2,SW=2" };
			}
			if (r(3) == 2) {
				return { 0x1b, a, b, "E=1,S=1,SE=2" };
			}
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(0) == 1 && r(6) == 1 && r(3) != 0) {
			return { r(3) == 1 ? 0x17 : 0x19, a, b, "N=1,W=1,SE!=0" };
		}
		if (r(0) == 2 && r(6) == 2 && r(3) != 0) {
			return { r(3) == 1 ? 0x1a : 0x18, a, b, "N=2,W=2,SE!=0" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(2) == 2 && r(4) == 1 && r(5) == 2) {
			return { 0x08, 1 - a, 1 - b, "E=2,S=1,SW=2; output flags inverted" };
		}
		if (r(2) == 1 && r(4) == 2 && r(1) == 2) {
			return { 0x08, 1 - a, 1 - b, "E=1,S=2,NE=2; output flags inverted" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot, true); };
		if (r(2) == 1 && r(4) == 1) {
			if (r(5) == 2) {
				return { 0x11, a, b, "E=1,S=1,SW=2" };
			}
			if (r(1) == 2) {
				return { 0x12, a, b, "E=1,S=1,NE=2" };
			}
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(0) == 1 && r(6) == 1) {
			return { 0x02, a, b, "N=1,W=1" };
		}
		if (r(0) == 2 && r(6) == 2) {
			return { 0x08, a, b, "N=2,W=2" };
		}
		if (r(2) == 1 && r(5) == 2) {
			return { 0x11, a, b, "E=1,SW=2" };
		}
		if (r(4) == 1 && r(1) == 2) {
			return { 0x12, a, b, "S=1,NE=2" };
		}
		if (r(2) == 2 && r(5) == 1) {
			return { 0x15, a, b, "E=2,SW=1" };
		}
		if (r(4) == 2 && r(1) == 1) {
			return { 0x16, a, b, "S=2,NE=1" };
		}
		if (r(6) == 1 && r(1) == 1) {
			return { 0x02, a, b, "W=1,NE=1" };
		}
		if (r(0) == 1 && r(5) == 1) {
			return { 0x02, a, b, "N=1,SW=1" };
		}
		if (r(6) == 2 && r(1) == 2) {
			return { 0x08, a, b, "W=2,NE=2" };
		}
		if (r(0) == 2 && r(5) == 2) {
			return { 0x08, a, b, "N=2,SW=2" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(2) == 1 && r(3) == 2) {
			return { 0x13, a, b, "E=1,SE=2" };
		}
		if (r(4) == 1 && r(3) == 2) {
			return { 0x14, a, b, "S=1,SE=2" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(0) == 1) {
			return { 0x04, a, b, "N=1" };
		}
		if (r(0) == 2) {
			return { 0x0a, a, b, "N=2" };
		}
		if (r(6) == 1) {
			return { 0x03, a, b, "W=1" };
		}
		if (r(6) == 2) {
			return { 0x09, a, b, "W=2" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(7) == 1 && r(3) == 1) {
			return { 0x0e, a, b, "NW=1,SE=1" };
		}
		if (r(7) == 1 && r(3) == 2) {
			return { 0x0f, a, b, "NW=1,SE=2" };
		}
		if (r(7) == 2 && r(3) == 2) {
			return { 0x10, a, b, "NW=2,SE=2" };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(3) == 1) {
			return { 0x05, a, b, "SE=1" };
		}
		if (r(3) == 2) {
			return { 0x0b, a, b, "SE=2" };
		}
	}
	return { 0x00, 0, 0, "no classed relation" };
}

PackedInt32Array packed_relations(const std::array<int32_t, 8> &relations) {
	PackedInt32Array packed;
	for (int32_t value : relations) {
		packed.append(value);
	}
	return packed;
}

Dictionary classifier_sample_record(const char *id, const std::array<int32_t, 8> &relations) {
	const TerrainClassResult classified = h3maped_classify_4bb075(relations);
	Dictionary record;
	record["id"] = id;
	record["relations_slot_order"] = "N,NE,E,SE,S,SW,W,NW";
	record["relations"] = packed_relations(relations);
	record["class"] = classified.shape_class;
	record["flag_a"] = classified.flag_a;
	record["flag_b"] = classified.flag_b;
	record["trigger"] = classified.trigger;
	return record;
}

Dictionary terrain_classifier_contract_report() {
	Dictionary report;
	report["status"] = "0x4bb039_0x5436e0_0x4bb075_relation_classifier_ported_boundary_only";
	report["relation_function_address"] = "0x4bb039";
	report["orientation_table_address"] = "0x5436e0";
	report["classifier_address"] = "0x4bb075";
	report["relations_slot_order"] = "N,NE,E,SE,S,SW,W,NW";
	report["materializes_visual_records"] = false;
	report["materializes_full_terrain_art_grid"] = false;

	Array relation_matrix;
	for (int32_t center = 0; center < 10; ++center) {
		PackedInt32Array row;
		for (int32_t neighbor = 0; neighbor < 10; ++neighbor) {
			row.append(h3maped_terrain_relation_4bb039(center, neighbor));
		}
		relation_matrix.append(row);
	}
	report["relation_matrix_terrain_ids_0_9"] = relation_matrix;

	Array orientation_rows;
	for (int32_t flag_a = 0; flag_a <= 1; ++flag_a) {
		for (int32_t flag_b = 0; flag_b <= 1; ++flag_b) {
			Dictionary row;
			row["flag_a"] = flag_a;
			row["flag_b"] = flag_b;
			PackedInt32Array slots;
			for (int32_t slot = 0; slot < 8; ++slot) {
				slots.append(orientation_slot_5436e0(flag_a, flag_b, slot));
			}
			row["slot_permutation"] = slots;
			orientation_rows.append(row);
		}
	}
	report["orientation_rows"] = orientation_rows;

	Array samples;
	samples.append(classifier_sample_record("class_0_full_native", { 0, 0, 0, 0, 0, 0, 0, 0 }));
	samples.append(classifier_sample_record("class_8_relation2_corner", { 2, 0, 0, 0, 0, 0, 2, 0 }));
	samples.append(classifier_sample_record("class_18_transposed_block", { 0, 0, 0, 0, 1, 0, 0, 2 }));
	samples.append(classifier_sample_record("class_28_compound_junction", { 0, 0, 0, 2, 1, 0, 1, 2 }));
	report["representative_samples"] = samples;
	report["blocked_next"] = "feed classified class/flags through exact normal or rock row selection, then 0x4bad0f and 0x49acf6 writeback";
	return report;
}

Dictionary terrain_visual_static_range_lookup_contract_report() {
	const int32_t constructor_probability = 0x32;
	const int32_t key0_start = 49;
	const int32_t key0_count = 8;
	const int32_t key1_start = 57;
	const int32_t key1_count = 16;
	const int32_t sample_neighbor_mask = 8;
	H3MapedRng rng;
	rng.state = 1;
	const int32_t probability_rng_value = rng.next();
	const int32_t threshold = (constructor_probability * sample_neighbor_mask) / 8;
	const bool selected_alternate_range = (probability_rng_value % 100) < threshold;
	const int32_t selected_start = selected_alternate_range ? key1_start : key0_start;
	const int32_t selected_count = selected_alternate_range ? key1_count : key0_count;
	const int32_t art_rng_value = rng.next();
	const int32_t selected_art_index = (art_rng_value % selected_count) + selected_start;

	Dictionary key0;
	key0["key"] = 0;
	key0["start"] = key0_start;
	key0["count"] = key0_count;
	Dictionary key1;
	key1["key"] = 1;
	key1["start"] = key1_start;
	key1["count"] = key1_count;

	Array materialized_ranges;
	materialized_ranges.append(key0);
	materialized_ranges.append(key1);

	Dictionary report;
	report["status"] = "0x4ba868_0x4ba938_static_range_lookup_contract_ported_sample";
	report["constructor_address"] = "0x4ba868";
	report["resolve_address"] = "0x4ba938";
	report["rng_address"] = "0x4e7276";
	report["toolkit_object_address"] = "0x5a3988";
	report["toolkit_vtable_address"] = "0x543780";
	report["terrain_id"] = 2;
	report["static_table_address"] = "0x543108";
	report["constructor_row_count"] = 0x4f;
	report["constructor_probability"] = constructor_probability;
	report["materialized_key_ranges"] = materialized_ranges;
	report["sample_rng_seed_uint32"] = 1;
	report["sample_neighbor_mask"] = sample_neighbor_mask;
	report["sample_probability_rng_value"] = probability_rng_value;
	report["sample_probability_threshold"] = threshold;
	report["sample_selected_alternate_range"] = selected_alternate_range;
	report["sample_art_rng_value"] = art_rng_value;
	report["sample_selected_range_start"] = selected_start;
	report["sample_selected_range_count"] = selected_count;
	report["sample_selected_art_index"] = selected_art_index;
	report["sample_rng_state_after_uint32"] = int64_t(rng.state);
	report["materializes_full_terrain_art_grid"] = false;
	report["source"] = "bounded executable contract for h3maped.exe 0x4ba868 range materialization and 0x4ba938 visual-art choice; full repaint-order integration remains separate";
	return report;
}

int32_t h3maped_id_for_terrain(const String &terrain_id) {
	if (terrain_id == "dirt") {
		return 0;
	}
	if (terrain_id == "sand") {
		return 1;
	}
	if (terrain_id == "grass") {
		return 2;
	}
	if (terrain_id == "snow") {
		return 3;
	}
	if (terrain_id == "swamp") {
		return 4;
	}
	if (terrain_id == "rough") {
		return 5;
	}
	if (terrain_id == "underground" || terrain_id == "subterranean") {
		return 6;
	}
	if (terrain_id == "lava") {
		return 7;
	}
	if (terrain_id == "water") {
		return 8;
	}
	if (terrain_id == "rock") {
		return 9;
	}
	return -1;
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
	item["player_start_zone_count"] = candidate.player_start_zone_count;
	item["treasure_zone_count"] = candidate.treasure_zone_count;
	item["minimum_player_castles"] = candidate.minimum_player_castles;
	return item;
}

Array bool_bitmap_report(const std::array<bool, 8> &bitmap) {
	Array result;
	for (bool enabled : bitmap) {
		result.append(enabled);
	}
	return result;
}

Array source_owner_indices_from_mask(uint8_t mask) {
	Array result;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & (1U << index)) != 0) {
			result.append(index);
		}
	}
	return result;
}

std::array<bool, 8> bitmap_from_mask(uint8_t mask) {
	std::array<bool, 8> bitmap = {};
	for (int32_t index = 0; index < 8; ++index) {
		bitmap[size_t(index)] = (mask & (1U << index)) != 0;
	}
	return bitmap;
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

Dictionary player_slot_assignment_report(uint8_t human_capable_mask, uint8_t player_capable_mask, const std::array<bool, 8> &selected_color_bitmap, int32_t human_count, int32_t computer_count) {
	Dictionary report;
	std::array<int32_t, 9> raw_mapping = {};
	raw_mapping.fill(-1);
	std::array<bool, 8> human_capable = bitmap_from_mask(human_capable_mask);
	std::array<bool, 8> player_capable = bitmap_from_mask(player_capable_mask);
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

	report["status"] = complete ? String("0x4ac62a_player_slot_assignment_ported") : String("0x4ac62a_player_slot_assignment_incomplete");
	report["source"] = "h3maped 0x4ac62a..0x4ac6ec using generator+0xed8 selected-color bitmap and source zone +0x04/+0x1c capability bitmaps";
	report["selected_color_bitmap_offset"] = "generator+0xed8";
	report["assignment_slots_offset"] = "generator+0xee0";
	report["mapped_slots_offset"] = "generator+0xee4";
	report["human_capable_source_owner_indices"] = source_owner_indices_from_mask(human_capable_mask);
	report["player_capable_source_owner_indices"] = source_owner_indices_from_mask(player_capable_mask);
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

int32_t owner_color_for_source_owner(const Array &colors_by_source_owner, int32_t source_owner_index) {
	if (source_owner_index < 0 || source_owner_index >= colors_by_source_owner.size()) {
		return -1;
	}
	return int32_t(colors_by_source_owner[source_owner_index]);
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
		if (other.runtime_index == current.runtime_index || other.level != candidate.level) {
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

Dictionary early_link_placement_schedule_report(const Dictionary &template_record, const Array &runtime_zone_records, int32_t human_count, int32_t player_count) {
	Dictionary report;
	report["status"] = "0x4a1f3b_endpoint_control_flow_ported";
	report["source"] = "h3maped 0x4a1f3b walks source zone link endpoint records and calls 0x4a17f5; Value/Wide/Border Guard payloads are preserved for later 0x4a79a3";
	report["link_endpoint_consumer_address"] = "0x4a1f3b";
	report["candidate_generator_address"] = "0x4a17f5";
	report["distance_validation_address"] = "0x4a1701";
	report["payload_policy"] = "early endpoint schedule consumes only link endpoints; guard Value, Wide, and Border Guard are not consumed before late connection geometry";
	report["materializes_coordinates"] = false;
	report["materializes_connection_guards"] = false;

	Dictionary runtime_index_by_zone_id;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
		if (Variant(runtime_zone_records[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[runtime_index];
		runtime_index_by_zone_id[String(runtime.get("source_zone_key", ""))] = runtime_index;
	}

	Array adjacency;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		adjacency.append(Array());
	}

	Array link_seeds;
	Array links = template_record.get("links", Array());
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		if (!player_filter_accepts(link.get("player_filter", Dictionary()), human_count, player_count)) {
			continue;
		}
		const String from_id = String(link.get("from", ""));
		const String to_id = String(link.get("to", ""));
		const int32_t runtime_a = int32_t(runtime_index_by_zone_id.get(from_id, -1));
		const int32_t runtime_b = int32_t(runtime_index_by_zone_id.get(to_id, -1));
		Dictionary endpoints = link.get("source_endpoints", Dictionary());
		Dictionary guard = link.get("guard", Dictionary());

		Dictionary seed;
		seed["link_index"] = link_seeds.size();
		seed["source_from_zone_key"] = from_id;
		seed["source_to_zone_key"] = to_id;
		seed["source_endpoint_a"] = endpoints.get("zone1", -1);
		seed["source_endpoint_b"] = endpoints.get("zone2", -1);
		seed["runtime_zone_a"] = runtime_a;
		seed["runtime_zone_b"] = runtime_b;
		seed["guard_value"] = link.get("guard_value", guard.get("value", 0));
		seed["wide"] = bool(link.get("wide", false));
		seed["border_guard"] = bool(link.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		link_seeds.append(seed);

		if (runtime_a >= 0 && runtime_a < adjacency.size() && runtime_b >= 0 && runtime_b < adjacency.size()) {
			Array a = adjacency[runtime_a];
			a.append(runtime_b);
			adjacency[runtime_a] = a;
			Array b = adjacency[runtime_b];
			b.append(runtime_a);
			adjacency[runtime_b] = b;
		}
	}

	Array placement_calls;
	int32_t explicit_endpoint_attempts = 0;
	int32_t fallback_attempts_if_no_valid_endpoint = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
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
		for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
			Array available_links;
			Array linked = runtime_index < adjacency.size() ? Array(adjacency[runtime_index]) : Array();
			for (int64_t link_index = 0; link_index < linked.size(); ++link_index) {
				const int32_t linked_runtime = int32_t(linked[link_index]);
				if (linked_runtime >= 0 && linked_runtime < runtime_zone_records.size()) {
					available_links.append(linked_runtime);
				}
			}
			explicit_endpoint_attempts += available_links.size();
			if (available_links.is_empty()) {
				fallback_attempts_if_no_valid_endpoint += int32_t(runtime_zone_records.size());
			}
			Dictionary call;
			call["pass"] = repeat == 0 ? String("stabilization_1") : String("stabilization_2");
			call["runtime_zone_index"] = runtime_index;
			call["runtime_vector_count_before_call"] = runtime_zone_records.size();
			call["available_endpoint_runtime_zones"] = available_links;
			call["fallback_candidate_count_if_no_valid_endpoint"] = available_links.is_empty() ? runtime_zone_records.size() : 0;
			call["coordinate_status"] = "pending_0x4a17f5_candidate_math_and_0x4a1701_validation";
			placement_calls.append(call);
		}
	}

	report["creation_pass_count"] = runtime_zone_records.size();
	report["stabilization_pass_count"] = 2;
	report["link_seed_count"] = link_seeds.size();
	report["link_seeds"] = link_seeds;
	report["call_count"] = placement_calls.size();
	report["explicit_endpoint_attempt_count"] = explicit_endpoint_attempts;
	report["fallback_attempt_count_if_no_valid_endpoint"] = fallback_attempts_if_no_valid_endpoint;
	report["calls"] = placement_calls;
	return report;
}

Dictionary coordinate_candidate_replay_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Array &link_seeds, uint32_t rng_state_after_template_selection) {
	Dictionary report;
	report["status"] = "0x4a17f5_0x4a1701_coordinate_candidate_replay_ported";
	report["source"] = "h3maped 0x4a218c interleaves 0x49b452 town choices, 0x4a1f3b endpoint walking, 0x4a17f5 32-angle candidates, 0x4a1701 spacing validation, 0x4a1ad8 single-level pruning, and 0x4a19ed bbox rescale";
	report["angle_table_x_address"] = "0x58dc28";
	report["angle_table_y_address"] = "0x58dd28";
	report["distance_validation_address"] = "0x4a1701";
	report["candidate_prune_address"] = "0x4a1ad8";
	report["bbox_rescale_address"] = "0x4a19ed";
	report["rng_state_before_0x4a218c_replay_uint32"] = int64_t(rng_state_after_template_selection);
	report["materializes_map_cells"] = false;
	report["materializes_zone_footprints"] = false;

	if (int32_t(normalized_config.get("level_count", 1)) != 1) {
		report["status"] = "blocked_until_two_level_coordinate_port";
		report["blocked_reason"] = "clean reset is scoped to one-level small land maps before underground coordinate branches";
		return report;
	}

	std::vector<RuntimeZoneSeed> zones;
	zones.reserve(size_t(runtime_zone_records.size()));
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		if (Variant(runtime_zone_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[index];
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(runtime.get("runtime_zone_index", index));
		zone.source_bucket = int32_t(runtime.get("source_bucket", -1));
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
	int32_t town_rng_calls = 0;
	bool complete = true;

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= runtime_zone_records.size()
				|| Variant(runtime_zone_records[zone_index]).get_type() != Variant::DICTIONARY) {
			return;
		}
		Dictionary runtime = runtime_zone_records[zone_index];
		Array allowed_factions = runtime.get("allowed_faction_ids_for_49b3c1", Array());
		if (allowed_factions.is_empty()) {
			return;
		}
		const int32_t rng_value = rng.next();
		const int32_t selected_index = rng_value % int32_t(allowed_factions.size());
		town_rng_calls += 1;
		Dictionary event;
		event["consumer"] = "0x49b3c1";
		event["runtime_zone_index"] = zone_index;
		event["value"] = rng_value;
		event["modulus"] = allowed_factions.size();
		event["selected_index"] = selected_index;
		rng_events.append(event);
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

	report["ok"] = complete;
	report["placement_step_count"] = placement_steps.size();
	report["placement_steps"] = placement_steps;
	report["town_rng_calls_during_0x49b452"] = town_rng_calls;
	report["coordinate_rng_calls_during_0x4a1f3b"] = coordinate_rng_calls;
	report["rng_event_count"] = rng_events.size();
	report["rng_events"] = rng_events;
	report["rng_state_after_0x4a218c_replay_uint32"] = int64_t(rng.state);
	report["bounding_box_rescale"] = bbox;
	report["scaled_zone_coordinates"] = scaled_zone_coordinates;
	report["next_materialization_status"] = "pending_0x49b53d_runtime_terrain_selection";
	return report;
}

Dictionary runtime_terrain_selection_report(const Array &runtime_zone_records, const Dictionary &coordinate_replay) {
	Dictionary report;
	report["status"] = "0x49b53d_runtime_terrain_selection_ported";
	report["source"] = "h3maped 0x49b53d maps match-to-town runtime choices through table 0x540908, otherwise uses 0x4e7276 over source zone +0x85..+0x8c allowed terrain flags";
	report["function_address"] = "0x49b53d";
	report["town_to_terrain_table_address"] = "0x540908";
	report["allowed_terrain_flags_source"] = "source_zone+0x85..0x8c";
	report["rng_state_before_0x49b53d_uint32"] = coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0);
	report["materializes_terrain_cells"] = false;
	report["materializes_terrain_art"] = false;

	const std::array<int32_t, 9> h3_town_to_terrain = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	Array town_table;
	for (int32_t item : h3_town_to_terrain) {
		town_table.append(item);
	}
	report["town_choice_to_terrain_table"] = town_table;

	Array town_choice_by_runtime;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		town_choice_by_runtime.append(-1);
	}
	Array rng_events = coordinate_replay.get("rng_events", Array());
	for (int64_t index = 0; index < rng_events.size(); ++index) {
		if (Variant(rng_events[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary event = rng_events[index];
		if (String(event.get("consumer", "")) != "0x49b3c1") {
			continue;
		}
		const int32_t runtime_index = int32_t(event.get("runtime_zone_index", -1));
		if (runtime_index >= 0 && runtime_index < town_choice_by_runtime.size()) {
			town_choice_by_runtime[runtime_index] = int32_t(event.get("selected_index", -1));
		}
	}

	H3MapedRng rng { uint32_t(int64_t(coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0))) };
	Array selections;
	int32_t rng_call_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t blank_allowed_mask_count = 0;
	int32_t forced_subterranean_count = 0;
	Array selected_ids;
	Array selected_names;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
		if (Variant(runtime_zone_records[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[runtime_index];
		Dictionary selection;
		const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		const int32_t level = int32_t(runtime.get("level", 0));
		const bool match_to_faction = bool(runtime.get("terrain_match_to_faction", false));
		const int32_t town_choice_index = runtime_index < town_choice_by_runtime.size() ? int32_t(town_choice_by_runtime[runtime_index]) : -1;
		selection["runtime_zone_index"] = zone_index;
		selection["level"] = level;
		selection["terrain_match_to_faction"] = match_to_faction;
		selection["town_choice_index"] = town_choice_index;
		int32_t selected_terrain = -1;
		String source;
		if (match_to_faction && town_choice_index >= 0 && town_choice_index < int32_t(h3_town_to_terrain.size())) {
			selected_terrain = h3_town_to_terrain[size_t(town_choice_index)];
			source = "0x49b54c_0x49b55b_match_to_town_table_0x540908";
			match_to_town_count += 1;
		} else {
			Array allowed = runtime.get("allowed_terrain_ids_for_49b53d", Array());
			Array eligible_ids;
			Array eligible_names;
			for (int64_t allowed_index = 0; allowed_index < allowed.size(); ++allowed_index) {
				const int32_t h3_id = h3maped_id_for_terrain(String(allowed[allowed_index]));
				if (h3_id < 0 || h3_id > 7) {
					continue;
				}
				if (h3_id == 6 && level != 1) {
					continue;
				}
				eligible_ids.append(h3_id);
				eligible_names.append(terrain_for_h3maped_id(h3_id));
			}
			if (eligible_ids.is_empty()) {
				selected_terrain = 0;
				source = "0x49b57d_0x49b584_no_eligible_flags_defaults_zero";
				blank_allowed_mask_count += 1;
			} else {
				const int32_t rng_value = rng.next();
				rng_call_count += 1;
				const int32_t selected_ordinal = rng_value % int32_t(eligible_ids.size());
				selected_terrain = int32_t(eligible_ids[selected_ordinal]);
				source = "0x49b586_0x49b5b4_allowed_flag_rng_choice";
				allowed_flag_choice_count += 1;
				selection["rng_value"] = rng_value;
				selection["rng_modulus"] = eligible_ids.size();
				selection["selected_allowed_ordinal"] = selected_ordinal;
			}
			selection["eligible_h3maped_terrain_ids"] = eligible_ids;
			selection["eligible_project_terrain_ids"] = eligible_names;
		}
		if (level == 1 && selected_terrain != 7) {
			selected_terrain = 6;
			forced_subterranean_count += 1;
			selection["forced_subterranean_branch"] = "0x49b5b7_0x49b5c3_level_1_non_lava_forces_terrain_6";
		}
		selection["selected_h3maped_terrain_id"] = selected_terrain;
		selection["selected_project_terrain_id"] = terrain_for_h3maped_id(selected_terrain);
		selection["source"] = source;
		selections.append(selection);
		selected_ids.append(selected_terrain);
		selected_names.append(terrain_for_h3maped_id(selected_terrain));
	}
	report["selection_count"] = selections.size();
	report["selections"] = selections;
	report["selected_h3maped_terrain_ids"] = selected_ids;
	report["selected_project_terrain_ids"] = selected_names;
	report["match_to_town_count"] = match_to_town_count;
	report["allowed_flag_choice_count"] = allowed_flag_choice_count;
	report["blank_allowed_mask_count"] = blank_allowed_mask_count;
	report["forced_subterranean_count"] = forced_subterranean_count;
	report["rng_call_count"] = rng_call_count;
	report["rng_state_after_0x49b53d_uint32"] = int64_t(rng.state);
	report["next_materialization_status"] = "pending_0x4a3a03_zone_footprint_placement";
	return report;
}

Dictionary polygon_seed_4cc788_report() {
	Dictionary report;
	report["status"] = "0x4cc788_initial_source_node_bounds_ported_inspection_only";
	report["source"] = "h3maped 0x4cc788 constructs the initial polygon source-node rectangle from constants 0xffffff38 (-200) and 0x190 (400), then links four 0x4cc955 nodes before 0x4ccb64 runtime-zone split insertions";
	report["function_address"] = "0x4cc788";
	report["node_constructor_address"] = "0x4cc955";
	report["splitter_address"] = "0x4ccb64";
	report["finalizer_address"] = "0x4ccdfc";
	report["locator_address"] = "0x4cca55";
	report["materializes_project_grid"] = false;
	report["feeds_real_0x4a2777_boundary"] = false;

	Dictionary bounds;
	bounds["min_x"] = -200;
	bounds["min_y"] = -200;
	bounds["max_x"] = 400;
	bounds["max_y"] = 400;
	bounds["constant_min_hex"] = "0xffffff38";
	bounds["constant_max_hex"] = "0x190";
	report["initial_bounds"] = bounds;

	Array initial_edges;
	auto append_edge = [&](const char *id, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y) {
		Dictionary edge;
		edge["id"] = id;
		edge["from_x"] = from_x;
		edge["from_y"] = from_y;
		edge["to_x"] = to_x;
		edge["to_y"] = to_y;
		edge["payload"] = 0;
		initial_edges.append(edge);
	};
	append_edge("top", -200, -200, 400, -200);
	append_edge("right", 400, -200, 400, 400);
	append_edge("bottom", 400, 400, -200, 400);
	append_edge("left", -200, 400, -200, -200);
	report["initial_edge_count"] = initial_edges.size();
	report["initial_edges"] = initial_edges;
	report["blocked_next"] = "port 0x4ccb64 split insertion and 0x4ccdfc source-node finalization before feeding real cycles into 0x4a2777";
	return report;
}

PolygonModel initial_polygon_model_4cc788() {
	PolygonModel model;
	const int32_t p0 = model.add_pair("initial_pair_0", -200, -200, 0, 400, -200, 0);
	const int32_t p1 = model.add_pair("initial_pair_1", 400, -200, 0, 400, 400, 0);
	const int32_t p2 = model.add_pair("initial_pair_2", 400, 400, 0, -200, 400, 0);
	const int32_t p3 = model.add_pair("initial_pair_3", -200, 400, 0, -200, -200, 0);
	model.relink_4cc643(model.nodes[size_t(p0)].pair, p1);
	model.relink_4cc643(model.nodes[size_t(p1)].pair, p2);
	model.relink_4cc643(model.nodes[size_t(p2)].pair, p3);
	model.relink_4cc643(model.nodes[size_t(p3)].pair, p0);
	model.bridge_4ccb1f(p3, p2, "initial_bridge_pair_0");
	model.root = p0;
	return model;
}

struct PolygonSplitGraphResult {
	PolygonModel model;
	bool blocked = false;
	int32_t executed_split_count = 0;
	int32_t locator_materialized_count = 0;
	int32_t crossing_cleanup_scan_count = 0;
	int32_t crossing_test_count = 0;
	int32_t crossing_collapse_count = 0;
};

PolygonSplitGraphResult materialize_polygon_split_graph_4ccb64(const Array &levels) {
	PolygonSplitGraphResult result;
	result.model = initial_polygon_model_4cc788();
	for (int64_t level_index = 0; level_index < levels.size(); ++level_index) {
		if (result.blocked) {
			break;
		}
		if (Variant(levels[level_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary level = levels[level_index];
		Array split_calls = level.get("polygon_split_calls", Array());
		for (int64_t split_index = 0; split_index < split_calls.size(); ++split_index) {
			if (result.blocked) {
				break;
			}
			if (Variant(split_calls[split_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary split = split_calls[split_index];
			const int32_t x = int32_t(split.get("x", 0));
			const int32_t y = int32_t(split.get("y", 0));
			const int32_t runtime_zone_index = int32_t(split.get("runtime_zone_index", -1));
			int32_t located = result.model.locate_4cca55(x, y);
			if (located < 0) {
				result.blocked = true;
				break;
			}
			result.locator_materialized_count += 1;
			if ((result.model.nodes[size_t(located)].x == x && result.model.nodes[size_t(located)].y == y)
					|| (result.model.nodes[size_t(result.model.nodes[size_t(located)].pair)].x == x && result.model.nodes[size_t(result.model.nodes[size_t(located)].pair)].y == y)) {
				continue;
			}
			if (result.model.edge_side_test_4cc6f2(located, x, y)) {
				located = result.model.nodes[size_t(located)].previous;
				const int32_t erased = result.model.nodes[size_t(located)].next;
				result.model.erase_edge_4cc9cc(erased);
			}
			const PolygonModelNode &anchor_node = result.model.nodes[size_t(located)];
			const int32_t split_primary = result.model.add_pair(
					String("split_") + String::num_int64(runtime_zone_index),
					anchor_node.x,
					anchor_node.y,
					anchor_node.payload,
					x,
					y,
					runtime_zone_index,
					anchor_node.has_payload,
					true);
			result.model.relink_4cc643(split_primary, located);
			result.model.root = split_primary;
			result.executed_split_count += 1;
			int32_t current_bridge = split_primary;
			int32_t bridge_source = located;
			for (int32_t guard = 0; guard < 64; ++guard) {
				current_bridge = result.model.bridge_4ccb1f(
						bridge_source,
						result.model.nodes[size_t(current_bridge)].pair,
						String("split_") + String::num_int64(runtime_zone_index) + "_bridge_" + String::num_int64(guard));
				bridge_source = result.model.nodes[size_t(current_bridge)].previous;
				const int32_t bridge_source_pair = result.model.nodes[size_t(bridge_source)].pair;
				if (result.model.nodes[size_t(bridge_source_pair)].previous == result.model.root) {
					break;
				}
				if (guard == 63) {
					result.blocked = true;
				}
			}
			int32_t cleanup_cursor = bridge_source;
			for (int32_t guard = 0; guard < 256; ++guard) {
				result.crossing_cleanup_scan_count += 1;
				if (result.model.crossing_orientation_gate_4ccb64(cleanup_cursor)) {
					const PolygonModelNode &cursor = result.model.nodes[size_t(cleanup_cursor)];
					const PolygonModelNode &previous_pair = result.model.nodes[size_t(result.model.nodes[size_t(cursor.previous)].pair)];
					const PolygonModelNode &paired = result.model.nodes[size_t(cursor.pair)];
					result.crossing_test_count += 1;
					if (result.model.crossing_test_4ccc7a(cursor.x, cursor.y, previous_pair.x, previous_pair.y, paired.x, paired.y, x, y)) {
						result.model.crossing_collapse_4cc68e(cleanup_cursor);
						result.crossing_collapse_count += 1;
						cleanup_cursor = result.model.nodes[size_t(cleanup_cursor)].previous;
						continue;
					}
				}
				cleanup_cursor = result.model.nodes[size_t(cleanup_cursor)].next;
				if (cleanup_cursor == result.model.root) {
					break;
				}
				cleanup_cursor = result.model.nodes[size_t(result.model.nodes[size_t(cleanup_cursor)].next)].pair;
				if (guard == 255) {
					result.blocked = true;
				}
			}
		}
	}
	return result;
}

Dictionary polygon_split_insertion_4ccb64_report(const Array &levels, int32_t total_polygon_split_calls) {
	Dictionary report;
	report["status"] = "0x4ccb64_locator_insertion_cleanup_ported_inspection_only";
	report["source"] = "h3maped 0x4ccb64 calls 0x4cca55 for each runtime-zone split point, rejects points equal to the located source-node endpoint or following endpoint, then inserts a 0x4cc955 node and runs bridge/crossing cleanup before 0x4ccdfc finalization; the compact port now materializes the scheduled small-land locator/insertion/cleanup passes against the mutated 0x4cc788 source-node graph";
	report["function_address"] = "0x4ccb64";
	report["locator_address"] = "0x4cca55";
	report["node_constructor_address"] = "0x4cc955";
	report["clone_bridge_address"] = "0x4ccb1f";
	report["crossing_test_address"] = "0x4ccc7a";
	report["intersection_helper_address"] = "0x4ccd69";
	report["finalizer_address"] = "0x4ccdfc";
	report["materializes_source_node_graph"] = total_polygon_split_calls > 0;
	report["materializes_first_source_node_graph_mutation"] = total_polygon_split_calls > 0;
	report["materializes_first_crossing_cleanup"] = total_polygon_split_calls > 0;
	report["feeds_real_0x4a2777_boundary"] = false;
	report["scheduled_split_call_count"] = total_polygon_split_calls;
	report["locator_call_count"] = total_polygon_split_calls;
	report["duplicate_endpoint_guard_address"] = "0x4ccb80..0x4ccba1";
	report["duplicate_endpoint_guard_materialized"] = true;

	Array scheduled_calls;
	PolygonModel model = initial_polygon_model_4cc788();
	bool blocked = false;
	int32_t locator_materialized_count = 0;
	int32_t locator_guard_failed_count = 0;
	int32_t duplicate_skip_count = 0;
	int32_t executed_split_count = 0;
	int32_t first_insertion_count = 0;
	int32_t total_insertion_count = 0;
	int32_t first_bridge_pair_count = 0;
	int32_t total_bridge_pair_count = 0;
	int32_t first_edge_removal_count = 0;
	int32_t edge_removal_count = 0;
	int32_t first_pre_crossing_allocated_node_pair_count = 0;
	int32_t first_pre_crossing_active_node_pair_count = 0;
	int32_t first_post_crossing_allocated_node_pair_count = 0;
	int32_t first_post_crossing_active_node_pair_count = 0;
	int32_t first_crossing_cleanup_scan_count = 0;
	int32_t first_crossing_test_count = 0;
	int32_t first_crossing_collapse_count = 0;
	bool first_crossing_cleanup_guard_exhausted = false;
	int32_t crossing_cleanup_scan_count = 0;
	int32_t crossing_test_count = 0;
	int32_t crossing_collapse_count = 0;
	bool crossing_cleanup_guard_exhausted = false;
	for (int64_t level_index = 0; level_index < levels.size(); ++level_index) {
		if (blocked) {
			break;
		}
		if (Variant(levels[level_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary level = levels[level_index];
		Array split_calls = level.get("polygon_split_calls", Array());
		for (int64_t split_index = 0; split_index < split_calls.size(); ++split_index) {
			if (blocked) {
				break;
			}
			if (Variant(split_calls[split_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary split = split_calls[split_index];
			Dictionary item;
			item["level_index"] = level.get("level_index", level_index);
			item["runtime_zone_index"] = split.get("runtime_zone_index", -1);
			item["x"] = split.get("x", 0);
			item["y"] = split.get("y", 0);
			const int32_t x = int32_t(split.get("x", 0));
			const int32_t y = int32_t(split.get("y", 0));
			const int32_t runtime_zone_index = int32_t(split.get("runtime_zone_index", -1));
			int32_t located = model.locate_4cca55(x, y);
			if (located < 0) {
				item["locator_status"] = "0x4cca55_current_graph_locator_failed";
				locator_guard_failed_count += 1;
				blocked = true;
			} else {
				locator_materialized_count += 1;
				item["locator_status"] = locator_materialized_count == 1 ? String("0x4cca55_initial_graph_locator_materialized") : String("0x4cca55_current_graph_locator_materialized");
				item["located_node_id"] = model.nodes[size_t(located)].id;
				item["located_pair_id"] = model.nodes[size_t(model.nodes[size_t(located)].pair)].id;
				const bool duplicates_located =
						(model.nodes[size_t(located)].x == x && model.nodes[size_t(located)].y == y)
						|| (model.nodes[size_t(model.nodes[size_t(located)].pair)].x == x && model.nodes[size_t(model.nodes[size_t(located)].pair)].y == y);
				item["duplicate_endpoint_guard_result"] = duplicates_located ? String("0x4ccb64_duplicate_point_skipped") : String("0x4ccb64_not_duplicate_endpoint");
				if (duplicates_located) {
					duplicate_skip_count += 1;
					item["insertion_status"] = "0x4ccb64_duplicate_point_skipped";
				} else {
					int32_t insertion_anchor = located;
					bool removed_edge = false;
					if (model.edge_side_test_4cc6f2(insertion_anchor, x, y)) {
						removed_edge = true;
						insertion_anchor = model.nodes[size_t(insertion_anchor)].previous;
						const int32_t erased = model.nodes[size_t(insertion_anchor)].next;
						item["edge_removal_status"] = total_insertion_count == 0 ? String("0x4cc9cc_vector_erase_branch_ported_for_first_split") : String("0x4cc9cc_vector_erase_branch_ported");
						item["edge_removal_anchor_node_id"] = model.nodes[size_t(insertion_anchor)].id;
						item["edge_removed_node_id"] = model.nodes[size_t(erased)].id;
						model.erase_edge_4cc9cc(erased);
						edge_removal_count += 1;
					}
					item["edge_removal_branch"] = removed_edge;
					const PolygonModelNode &anchor_node = model.nodes[size_t(insertion_anchor)];
					const int32_t split_primary = model.add_pair(
							String("split_") + String::num_int64(runtime_zone_index),
							anchor_node.x,
							anchor_node.y,
							anchor_node.payload,
							x,
							y,
							runtime_zone_index,
							anchor_node.has_payload,
							true);
					model.relink_4cc643(split_primary, insertion_anchor);
					model.root = split_primary;
					total_insertion_count += 1;
					executed_split_count += 1;
					item["insertion_status"] = total_insertion_count == 1 ? String("0x4ccb64_first_split_pre_crossing_inserted") : String("0x4ccb64_split_pre_crossing_inserted");
					item["inserted_primary_node_id"] = model.nodes[size_t(split_primary)].id;
					item["inserted_paired_node_id"] = model.nodes[size_t(model.nodes[size_t(split_primary)].pair)].id;
					int32_t current_bridge = split_primary;
					int32_t bridge_source = insertion_anchor;
					int32_t bridge_pair_count = 0;
					bool bridge_loop_guard_exhausted = false;
					for (int32_t guard = 0; guard < 64; ++guard) {
						current_bridge = model.bridge_4ccb1f(
								bridge_source,
								model.nodes[size_t(current_bridge)].pair,
								String("split_") + String::num_int64(runtime_zone_index) + "_bridge_" + String::num_int64(bridge_pair_count));
						bridge_pair_count += 1;
						bridge_source = model.nodes[size_t(current_bridge)].previous;
						const int32_t bridge_source_pair = model.nodes[size_t(bridge_source)].pair;
						if (model.nodes[size_t(bridge_source_pair)].previous == model.root) {
							break;
						}
						if (guard == 63) {
							bridge_loop_guard_exhausted = true;
							blocked = true;
						}
					}
					total_bridge_pair_count += bridge_pair_count;
					item["bridge_pair_count"] = bridge_pair_count;
					item["bridge_loop_guard_exhausted"] = bridge_loop_guard_exhausted;
					const int32_t pre_crossing_allocated = int32_t(model.nodes.size() / 2);
					const int32_t pre_crossing_active = model.active_node_pair_count();
					item["allocated_node_pair_count_after_pre_crossing"] = pre_crossing_allocated;
					item["active_node_pair_count_after_pre_crossing"] = pre_crossing_active;
					int32_t cleanup_scan_count = 0;
					int32_t cleanup_test_count = 0;
					int32_t cleanup_collapse_count = 0;
					int32_t cleanup_cursor = bridge_source;
					bool cleanup_guard_exhausted = false;
					for (int32_t guard = 0; guard < 256; ++guard) {
						cleanup_scan_count += 1;
						crossing_cleanup_scan_count += 1;
						if (model.crossing_orientation_gate_4ccb64(cleanup_cursor)) {
							const PolygonModelNode &cursor = model.nodes[size_t(cleanup_cursor)];
							const PolygonModelNode &previous_pair = model.nodes[size_t(model.nodes[size_t(cursor.previous)].pair)];
							const PolygonModelNode &paired = model.nodes[size_t(cursor.pair)];
							cleanup_test_count += 1;
							crossing_test_count += 1;
							if (model.crossing_test_4ccc7a(cursor.x, cursor.y, previous_pair.x, previous_pair.y, paired.x, paired.y, x, y)) {
								model.crossing_collapse_4cc68e(cleanup_cursor);
								cleanup_collapse_count += 1;
								crossing_collapse_count += 1;
								cleanup_cursor = model.nodes[size_t(cleanup_cursor)].previous;
								continue;
							}
						}
						cleanup_cursor = model.nodes[size_t(cleanup_cursor)].next;
						if (cleanup_cursor == model.root) {
							break;
						}
						cleanup_cursor = model.nodes[size_t(model.nodes[size_t(cleanup_cursor)].next)].pair;
						if (guard == 255) {
							cleanup_guard_exhausted = true;
							crossing_cleanup_guard_exhausted = true;
							blocked = true;
						}
					}
					item["crossing_cleanup_status"] = cleanup_guard_exhausted ? String("0x4ccb64_crossing_cleanup_guard_failed") : String("0x4ccc7a_0x4cc68e_crossing_cleanup_materialized");
					item["crossing_cleanup_scan_count"] = cleanup_scan_count;
					item["crossing_test_count"] = cleanup_test_count;
					item["crossing_collapse_count"] = cleanup_collapse_count;
					item["crossing_cleanup_guard_exhausted"] = cleanup_guard_exhausted;
					const int32_t post_crossing_allocated = int32_t(model.nodes.size() / 2);
					const int32_t post_crossing_active = model.active_node_pair_count();
					item["allocated_node_pair_count_after_crossing_cleanup"] = post_crossing_allocated;
					item["active_node_pair_count_after_crossing_cleanup"] = post_crossing_active;
					if (total_insertion_count == 1) {
						first_insertion_count = 1;
						first_edge_removal_count = removed_edge ? 1 : 0;
						first_bridge_pair_count = bridge_pair_count;
						first_pre_crossing_allocated_node_pair_count = pre_crossing_allocated;
						first_pre_crossing_active_node_pair_count = pre_crossing_active;
						first_crossing_cleanup_scan_count = cleanup_scan_count;
						first_crossing_test_count = cleanup_test_count;
						first_crossing_collapse_count = cleanup_collapse_count;
						first_crossing_cleanup_guard_exhausted = cleanup_guard_exhausted;
						first_post_crossing_allocated_node_pair_count = post_crossing_allocated;
						first_post_crossing_active_node_pair_count = post_crossing_active;
					}
				}
			}
			if (!item.has("insertion_status")) {
				item["insertion_status"] = "pending_0x4ccb64_source_node_graph_materialization";
			}
			scheduled_calls.append(item);
		}
	}
	report["locator_materialized_count"] = locator_materialized_count;
	report["locator_guard_failed_count"] = locator_guard_failed_count;
	report["duplicate_skip_count"] = duplicate_skip_count;
	report["executed_split_call_count"] = executed_split_count;
	report["pre_crossing_inserted_node_pair_count"] = total_insertion_count;
	report["pre_crossing_inserted_bridge_pair_count"] = total_bridge_pair_count;
	report["first_pre_crossing_insertion_count"] = first_insertion_count;
	report["first_edge_removal_branch_count"] = first_edge_removal_count;
	report["edge_removal_branch_count"] = edge_removal_count;
	report["first_pre_crossing_bridge_pair_count"] = first_bridge_pair_count;
	report["first_post_pre_crossing_allocated_node_pair_count"] = first_pre_crossing_allocated_node_pair_count;
	report["first_post_pre_crossing_active_node_pair_count"] = first_pre_crossing_active_node_pair_count;
	report["first_post_crossing_cleanup_allocated_node_pair_count"] = first_post_crossing_allocated_node_pair_count;
	report["first_post_crossing_cleanup_active_node_pair_count"] = first_post_crossing_active_node_pair_count;
	report["first_crossing_cleanup_scan_count"] = first_crossing_cleanup_scan_count;
	report["first_crossing_test_count"] = first_crossing_test_count;
	report["first_crossing_collapse_count"] = first_crossing_collapse_count;
	report["first_crossing_cleanup_guard_exhausted"] = first_crossing_cleanup_guard_exhausted;
	report["crossing_cleanup_scan_count"] = crossing_cleanup_scan_count;
	report["crossing_test_count"] = crossing_test_count;
	report["crossing_collapse_count"] = crossing_collapse_count;
	report["crossing_cleanup_guard_exhausted"] = crossing_cleanup_guard_exhausted;
	report["post_crossing_cleanup_allocated_node_pair_count"] = int32_t(model.nodes.size() / 2);
	report["post_crossing_cleanup_active_node_pair_count"] = model.active_node_pair_count();
	report["root_node_id_after_crossing_cleanup"] = model.root >= 0 ? model.nodes[size_t(model.root)].id : String();
	report["crossing_cleanup_status"] = blocked ? String("blocked_during_0x4ccb64_cleanup") : String("0x4ccc7a_0x4cc68e_all_scheduled_crossing_cleanup_materialized");
	report["scheduled_calls"] = scheduled_calls;
	report["blocked_next"] = "materialize 0x4ccdfc finalized source-node cycles from the mutated graph before real 0x4a2777 boundary traversal can feed 0x4a325d";
	return report;
}

Dictionary polygon_finalizer_4ccdfc_report(const Array &levels, int32_t total_polygon_split_calls) {
	Dictionary report;
	report["status"] = "0x4ccdfc_source_node_finalizer_materialized_inspection_only";
	report["source"] = "h3maped 0x4ccdfc iterates polygon graph vector entries, skips nodes without +0x08 or already marked at +0x18, computes +0x1c/+0x20 finalized coordinates through 0x4ccd69, and marks the node plus two linked nodes finalized before 0x4a2777 consumes the cycles";
	report["function_address"] = "0x4ccdfc";
	report["intersection_helper_address"] = "0x4ccd69";
	report["node_vector_begin_offset"] = "polygon+0x08";
	report["node_vector_end_offset"] = "polygon+0x0c";
	report["node_has_aux_edge_offset"] = "source_node+0x08";
	report["node_finalized_flag_offset"] = "source_node+0x18";
	report["finalized_x_offset"] = "source_node+0x1c";
	report["finalized_y_offset"] = "source_node+0x20";
	report["scheduled_split_call_count"] = total_polygon_split_calls;
	report["materializes_source_node_graph"] = total_polygon_split_calls > 0;
	report["materializes_finalized_cycles"] = total_polygon_split_calls > 0;
	report["feeds_real_0x4a2777_boundary"] = false;
	report["eligible_node_scan_materialized"] = total_polygon_split_calls > 0;
	report["finalized_coordinate_write_materialized"] = total_polygon_split_calls > 0;

	Array write_sequence;
	write_sequence.append("0x4cce25 skip when source_node+0x08 is null");
	write_sequence.append("0x4cce2b skip when source_node+0x18 is already set");
	write_sequence.append("0x4cce4d compute intersection through 0x4ccd69");
	write_sequence.append("0x4cce5b write source_node+0x1c/+0x20");
	write_sequence.append("0x4cce64 set source_node+0x18");
	write_sequence.append("0x4cce6e..0x4cce84 mirror +0x1c/+0x20/+0x18 to two linked nodes");
	report["write_sequence"] = write_sequence;
	PolygonSplitGraphResult split_graph = materialize_polygon_split_graph_4ccb64(levels);
	Array finalized_steps;
	const int32_t finalized_triplet_count = split_graph.blocked ? 0 : split_graph.model.finalize_4ccdfc(&finalized_steps);
	int32_t finalized_node_count = 0;
	int32_t active_payload_node_count = 0;
	for (const PolygonModelNode &node : split_graph.model.nodes) {
		if (!node.active) {
			continue;
		}
		if (node.has_payload) {
			active_payload_node_count += 1;
		}
		if (node.finalized) {
			finalized_node_count += 1;
		}
	}
	report["split_graph_blocked"] = split_graph.blocked;
	report["split_graph_executed_split_call_count"] = split_graph.executed_split_count;
	report["split_graph_locator_materialized_count"] = split_graph.locator_materialized_count;
	report["split_graph_crossing_cleanup_scan_count"] = split_graph.crossing_cleanup_scan_count;
	report["split_graph_crossing_test_count"] = split_graph.crossing_test_count;
	report["split_graph_crossing_collapse_count"] = split_graph.crossing_collapse_count;
	report["split_graph_allocated_node_pair_count"] = int32_t(split_graph.model.nodes.size() / 2);
	report["split_graph_active_node_pair_count"] = split_graph.model.active_node_pair_count();
	report["finalizer_status"] = split_graph.blocked ? String("blocked_before_0x4ccdfc") : String("0x4ccdfc_finalized_node_fanout_materialized");
	report["finalized_triplet_count"] = finalized_triplet_count;
	report["finalized_node_count"] = finalized_node_count;
	report["active_payload_node_count"] = active_payload_node_count;
	report["finalized_steps"] = finalized_steps;
	Array source_node_walks;
	int32_t source_node_walk_count = 0;
	int32_t source_node_walk_guard_exhausted_count = 0;
	int32_t source_node_walk_finalized_coordinate_count = 0;
	for (int64_t level_index = 0; level_index < levels.size(); ++level_index) {
		if (Variant(levels[level_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary level = levels[level_index];
		Array split_calls = level.get("polygon_split_calls", Array());
		for (int64_t split_index = 0; split_index < split_calls.size(); ++split_index) {
			if (Variant(split_calls[split_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary split = split_calls[split_index];
			Dictionary walk;
			walk["runtime_zone_index"] = split.get("runtime_zone_index", -1);
			walk["locator_address"] = "0x4cca55";
			walk["consumer_address"] = "0x4a2777";
			walk["start_x"] = split.get("x", 0);
			walk["start_y"] = split.get("y", 0);
			const int32_t located = split_graph.blocked ? -1 : split_graph.model.locate_4cca55(int32_t(split.get("x", 0)), int32_t(split.get("y", 0)));
			walk["located_node_id"] = located >= 0 ? split_graph.model.nodes[size_t(located)].id : String();
			Array cycle_nodes;
			bool guard_exhausted = false;
			int32_t finalized_coordinate_count = 0;
			if (located >= 0) {
				int32_t current = located;
				for (int32_t guard = 0; guard < 96; ++guard) {
					const PolygonModelNode &node = split_graph.model.nodes[size_t(current)];
					Dictionary node_report;
					node_report["node_id"] = node.id;
					node_report["+0x00_x"] = node.x;
					node_report["+0x04_y"] = node.y;
					node_report["+0x08_payload"] = node.payload;
					node_report["has_payload"] = node.has_payload;
					node_report["+0x10_next"] = node.next >= 0 ? split_graph.model.nodes[size_t(node.next)].id : String();
					node_report["+0x14_previous"] = node.previous >= 0 ? split_graph.model.nodes[size_t(node.previous)].id : String();
					node_report["+0x1c_finalized_x"] = node.finalized_x;
					node_report["+0x20_finalized_y"] = node.finalized_y;
					node_report["finalized"] = node.finalized;
					node_report["active"] = node.active;
					cycle_nodes.append(node_report);
					if (node.finalized) {
						finalized_coordinate_count += 1;
					}
					current = node.next;
					if (current == located) {
						break;
					}
					if (guard == 95) {
						guard_exhausted = true;
					}
				}
			}
			if (guard_exhausted) {
				source_node_walk_guard_exhausted_count += 1;
			}
			source_node_walk_finalized_coordinate_count += finalized_coordinate_count;
			walk["cycle_node_count"] = cycle_nodes.size();
			walk["finalized_coordinate_count"] = finalized_coordinate_count;
			walk["guard_exhausted"] = guard_exhausted;
			walk["cycle_nodes"] = cycle_nodes;
			source_node_walks.append(walk);
			source_node_walk_count += 1;
		}
	}
	report["source_node_walk_status"] = split_graph.blocked ? String("blocked_before_0x4cca55_source_node_walk") : String("0x4cca55_to_0x4a2777_source_node_cycles_recovered");
	report["source_node_walk_count"] = source_node_walk_count;
	report["source_node_walk_guard_exhausted_count"] = source_node_walk_guard_exhausted_count;
	report["source_node_walk_finalized_coordinate_count"] = source_node_walk_finalized_coordinate_count;
	report["source_node_walks"] = source_node_walks;
	report["blocked_next"] = "feed finalized 0x4ccdfc polygon source-node cycles into real 0x4a2777 boundary traversal and then 0x4a325d span fill";
	return report;
}

Dictionary boundary_traversal_4a2777_real_cycles_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Array &levels, const Dictionary &polygon_finalizer, uint32_t rng_state_before_boundary, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a2777_real_source_node_cycle_traversal_ported_boundary_materialized";
	report["source"] = "h3maped 0x4a2777 over real 0x4cca55 source-node cycles: clip finalized +0x1c/+0x20 coordinates through 0x4a2b33 and paint boundary cells through 0x4a261a/0x4a2413";
	report["function_address"] = "0x4a2777";
	report["caller_address"] = "0x4a3e58..0x4a3e8c";
	report["clip_helper_address"] = "0x4a2b33";
	report["deterministic_line_writer_address"] = "0x4a261a";
	report["flagged_line_writer_address"] = "0x4a2413";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	report["uses_real_source_node_walk"] = true;
	report["materializes_project_grid"] = false;
	report["feeds_0x4a325d_span_fill"] = zone_words_out != nullptr && cell_flags_out != nullptr;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["rng_state_before_0x4a2777_uint32"] = int64_t(rng_state_before_boundary);

	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;

	Array source_walks = polygon_finalizer.get("source_node_walks", Array());
	const int32_t cell_count = std::max(0, width * height * std::max(1, level_count));
	std::vector<uint32_t> zone_words(size_t(cell_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(cell_count), 0);
	H3MapedRng rng{ rng_state_before_boundary };
	Array zone_reports;
	int32_t trace_write_count = 0;
	int32_t out_of_bounds_write_count = 0;
	int32_t runtime_zone_walk_count = 0;
	int32_t blocked_zone_count = 0;
	int32_t fallback_zone_count = 0;
	int32_t connector_segment_count = 0;
	int32_t wrap_segment_count = 0;
	int32_t final_segment_count = 0;
	int32_t appended_vertex_count = 0;
	int32_t skipped_unfinalized_node_count = 0;
	int32_t skipped_out_of_bounds_clip_count = 0;
	int32_t flagged_writer_segment_count = 0;
	int32_t deterministic_writer_segment_count = 0;
	int32_t randomized_rng_call_count = 0;
	int32_t randomized_inserted_midpoint_count = 0;
	int32_t randomized_max_pending_point_count = 0;
	bool loop_guard_exhausted = false;

	auto point_inside_bounds = [&](const ClipResult &point) {
		return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
	};
	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};
	auto append_vertex = [&](Array &vertices, int32_t x, int32_t y) {
		Dictionary vertex;
		vertex["x"] = x;
		vertex["y"] = y;
		vertices.append(vertex);
		appended_vertex_count += 1;
	};
	auto segment_report = [&](const String &id, const String &branch, const String &writer, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y, const LineWriteResult &line) {
		Dictionary segment;
		segment["id"] = id;
		segment["branch"] = branch;
		segment["writer"] = writer;
		segment["from_x"] = from_x;
		segment["from_y"] = from_y;
		segment["to_x"] = to_x;
		segment["to_y"] = to_y;
		segment["trace_write_count"] = line.write_count;
		segment["unique_cell_count"] = line.unique_cell_count;
		segment["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
		segment["trace_preview"] = line.trace_preview;
		return segment;
	};
	auto append_segment = [&](Array &segments, const String &id, const String &branch, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_word, int32_t level, bool randomized, int32_t random_span_limit) {
		LineWriteResult line;
		if (randomized) {
			line = h3maped_randomized_line_writer_4a2413(zone_words, cell_flags, width, height, level_count, water_code, x1, y1, x2, y2, level, zone_word, random_span_limit, rng, randomized_rng_call_count, randomized_inserted_midpoint_count, randomized_max_pending_point_count);
			flagged_writer_segment_count += 1;
		} else {
			line = h3maped_line_writer_4a261a(zone_words, cell_flags, width, height, level_count, water_code, x1, y1, x2, y2, level, zone_word);
			deterministic_writer_segment_count += 1;
		}
		trace_write_count += line.write_count;
		out_of_bounds_write_count += line.out_of_bounds_write_count;
		segments.append(segment_report(id, branch, randomized ? String("0x4a2413") : String("0x4a261a"), x1, y1, x2, y2, line));
	};
	auto runtime_size_for_zone = [&](int32_t runtime_zone_index) {
		for (int64_t level_index = 0; level_index < levels.size(); ++level_index) {
			if (Variant(levels[level_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary level = levels[level_index];
			Array split_calls = level.get("polygon_split_calls", Array());
			for (int64_t split_index = 0; split_index < split_calls.size(); ++split_index) {
				if (Variant(split_calls[split_index]).get_type() != Variant::DICTIONARY) {
					continue;
				}
				Dictionary split = split_calls[split_index];
				if (int32_t(split.get("runtime_zone_index", -1)) == runtime_zone_index) {
					return std::max(1, int32_t(split.get("runtime_size_after_bbox_rescale", 1)));
				}
			}
		}
		return 1;
	};

	for (int64_t walk_index = 0; walk_index < source_walks.size(); ++walk_index) {
		if (Variant(source_walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary walk = source_walks[walk_index];
		const int32_t runtime_zone_index = int32_t(walk.get("runtime_zone_index", -1));
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["status"] = "blocked_before_cycle_consumption";
		if (runtime_zone_index < 0 || runtime_zone_index >= runtime_zone_records.size()) {
			blocked_zone_count += 1;
			zone_reports.append(zone_report);
			continue;
		}
		const int32_t zone_word = runtime_zone_index;
		const int32_t level = 0;
		const bool flagged_branch = !(level_count == 2 && level != 1);
		const int32_t random_span_limit = runtime_size_for_zone(runtime_zone_index);
		Array cycle_nodes = walk.get("cycle_nodes", Array());
		std::vector<PolygonPoint> finalized_points;
		Array point_reports;
		for (int64_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
			if (Variant(cycle_nodes[node_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary node = cycle_nodes[node_index];
			if (!bool(node.get("finalized", false))) {
				skipped_unfinalized_node_count += 1;
				continue;
			}
			const int32_t x = int32_t(node.get("+0x1c_finalized_x", 0));
			const int32_t y = int32_t(node.get("+0x20_finalized_y", 0));
			finalized_points.push_back(PolygonPoint{ x, y });
			Dictionary point;
			point["node_id"] = node.get("node_id", "");
			point["x"] = x;
			point["y"] = y;
			point_reports.append(point);
		}
		zone_report["finalized_point_count"] = int32_t(finalized_points.size());
		zone_report["finalized_points"] = point_reports;
		zone_report["flagged_branch_from_0x4a3e69"] = flagged_branch;
		zone_report["random_span_limit_runtime_size"] = random_span_limit;
		if (finalized_points.size() < 2) {
			blocked_zone_count += 1;
			zone_report["status"] = "blocked_no_finalized_cycle_segments";
			zone_reports.append(zone_report);
			continue;
		}

		int32_t selected_segment_index = -1;
		ClipResult clipped_current;
		ClipResult clipped_target;
		for (int32_t index = 0; index < int32_t(finalized_points.size()); ++index) {
			const PolygonPoint from = finalized_points[size_t(index)];
			const PolygonPoint to = finalized_points[size_t((index + 1) % int32_t(finalized_points.size()))];
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			ClipResult candidate_current = h3maped_clip_point_4a2b33(from.x, from.y, to.x, to.y, bounds);
			ClipResult candidate_target = h3maped_clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds(candidate_current)) {
				skipped_out_of_bounds_clip_count += 1;
				continue;
			}
			if (candidate_current.x == candidate_target.x && candidate_current.y == candidate_target.y) {
				continue;
			}
			selected_segment_index = index;
			clipped_current = candidate_current;
			clipped_target = candidate_target;
			break;
		}
		if (selected_segment_index < 0) {
			fallback_zone_count += 1;
			zone_report["status"] = "0x4a2777_rectangle_fallback_required_for_cycle";
			zone_reports.append(zone_report);
			continue;
		}

		Array segments;
		Array vertices;
		append_vertex(vertices, clipped_current.x, clipped_current.y);
		append_segment(segments, "connector", "0x4a2911_connector_segment_from_real_source_cycle", clipped_current.x, clipped_current.y, clipped_target.x, clipped_target.y, zone_word, level, flagged_branch, random_span_limit);
		connector_segment_count += 1;
		int32_t current_x = clipped_target.x;
		int32_t current_y = clipped_target.y;
		const int32_t right_x = std::max<int32_t>(bounds.min_x, bounds.max_x - 1);
		const int32_t bottom_y = std::max<int32_t>(bounds.min_y, bounds.max_y - 1);
		int32_t source_index = (selected_segment_index + 1) % int32_t(finalized_points.size());
		for (int32_t guard = 0; guard < int32_t(finalized_points.size()) + 4; ++guard) {
			const int32_t next_source_index = (source_index + 1) % int32_t(finalized_points.size());
			if (source_index == selected_segment_index) {
				break;
			}
			const PolygonPoint from = finalized_points[size_t(source_index)];
			const PolygonPoint to = finalized_points[size_t(next_source_index)];
			source_index = next_source_index;
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			const ClipResult next_clip = h3maped_clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds(next_clip)) {
				skipped_out_of_bounds_clip_count += 1;
				continue;
			}
			int32_t wrap_guard = 0;
			while (current_x != next_clip.x && current_y != next_clip.y && point_on_clip_border(current_x, current_y) && point_on_clip_border(next_clip.x, next_clip.y) && wrap_guard < 8) {
				int32_t border_x = current_x;
				int32_t border_y = current_y;
				String branch = "0x4a2aa7_bottom_edge_to_min_x";
				if (current_x == bounds.min_x) {
					if (current_y == bounds.min_y) {
						border_x = right_x;
						border_y = bounds.min_y;
						branch = "0x4a2a91_top_edge_to_max_x_minus_one";
					} else {
						border_x = bounds.min_x;
						border_y = bounds.min_y;
						branch = "0x4a2a81_left_edge_to_min_y";
					}
				} else if (current_y == bounds.min_y) {
					border_x = right_x;
					border_y = bounds.min_y;
					branch = "0x4a2a89_top_edge_to_max_x_minus_one";
				} else if (current_x == right_x && current_y != bottom_y) {
					border_x = right_x;
					border_y = bottom_y;
					branch = "0x4a2a98_right_edge_to_max_y_minus_one";
				} else {
					border_x = bounds.min_x;
					border_y = bottom_y;
					branch = "0x4a2aa7_bottom_edge_to_min_x";
				}
				append_segment(segments, "wrap", branch, current_x, current_y, border_x, border_y, zone_word, level, false, random_span_limit);
				append_vertex(vertices, current_x, current_y);
				current_x = border_x;
				current_y = border_y;
				wrap_segment_count += 1;
				wrap_guard += 1;
			}
			if (wrap_guard >= 8 && current_x != next_clip.x && current_y != next_clip.y) {
				loop_guard_exhausted = true;
				break;
			}
			if (current_x != next_clip.x || current_y != next_clip.y) {
				append_segment(segments, "final", "0x4a2af2_final_segment_to_real_cycle_endpoint", current_x, current_y, next_clip.x, next_clip.y, zone_word, level, false, random_span_limit);
				append_vertex(vertices, current_x, current_y);
				final_segment_count += 1;
				current_x = next_clip.x;
				current_y = next_clip.y;
			}
			if (source_index == selected_segment_index) {
				break;
			}
		}
		runtime_zone_walk_count += 1;
		zone_report["status"] = "0x4a2777_real_source_cycle_consumed";
		zone_report["selected_segment_index"] = selected_segment_index;
		zone_report["connector_from_x"] = clipped_current.x;
		zone_report["connector_from_y"] = clipped_current.y;
		zone_report["connector_to_x"] = clipped_target.x;
		zone_report["connector_to_y"] = clipped_target.y;
		zone_report["appended_vertex_count"] = vertices.size();
		zone_report["appended_vertices"] = vertices;
		zone_report["segment_count"] = segments.size();
		zone_report["segments"] = segments;
		zone_reports.append(zone_report);
	}

	int32_t unique_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	for (int32_t index = 0; index < cell_count; ++index) {
		if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) != H3MAPED_UNASSIGNED_ZONE_WORD) {
			unique_cell_count += 1;
		}
		if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
			reserved_flag_cell_count += 1;
		}
	}
	report["runtime_zone_walk_count"] = runtime_zone_walk_count;
	report["blocked_zone_count"] = blocked_zone_count;
	report["fallback_zone_count"] = fallback_zone_count;
	report["connector_segment_count"] = connector_segment_count;
	report["wrap_segment_count"] = wrap_segment_count;
	report["final_segment_count"] = final_segment_count;
	report["appended_vertex_count"] = appended_vertex_count;
	report["skipped_unfinalized_node_count"] = skipped_unfinalized_node_count;
	report["skipped_out_of_bounds_clip_count"] = skipped_out_of_bounds_clip_count;
	report["flagged_writer_segment_count"] = flagged_writer_segment_count;
	report["deterministic_writer_segment_count"] = deterministic_writer_segment_count;
	report["randomized_rng_call_count"] = randomized_rng_call_count;
	report["randomized_inserted_midpoint_count"] = randomized_inserted_midpoint_count;
	report["randomized_max_pending_point_count"] = randomized_max_pending_point_count;
	report["rng_state_after_0x4a2777_uint32"] = int64_t(rng.state);
	report["trace_write_count"] = trace_write_count;
	report["unique_cell_count"] = unique_cell_count;
	report["reserved_flag_cell_count"] = reserved_flag_cell_count;
	report["out_of_bounds_write_count"] = out_of_bounds_write_count;
	report["loop_guard_exhausted"] = loop_guard_exhausted;
	report["zone_reports"] = zone_reports;
	report["blocked_next"] = "feed these real 0x4a2777 boundary cells into 0x4a325d span fill before project terrain/object materialization";
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return report;
}

Dictionary seed_relocation_4a325d_report(const Dictionary &source_node_walk, const SpanRecord &seed, int32_t width, int32_t height, int32_t level_count) {
	Dictionary report;
	report["status"] = "0x4a325d_seed_in_bounds_relocation_not_used";
	report["source"] = "h3maped 0x4a32b2..0x4a338e relocation branch: when runtime_zone+0x10 seed is outside map bounds, scan the source-node cycle for the interior node with maximum border clearance, then clip the original seed toward that node through 0x4a2b33";
	report["function_address"] = "0x4a325d";
	report["branch_address"] = "0x4a32b2..0x4a338e";
	report["clip_helper_address"] = "0x4a2b33";
	report["seed_x"] = seed.x;
	report["seed_y"] = seed.y;
	report["seed_level"] = seed.level;
	const bool seed_in_bounds = seed.x >= 0 && seed.x < width && seed.y >= 0 && seed.y < height && seed.level >= 0 && seed.level < level_count;
	report["seed_in_bounds"] = seed_in_bounds;

	Array candidates;
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_clearance = -1;
	Array cycle_nodes = source_node_walk.get("cycle_nodes", Array());
	for (int64_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
		if (Variant(cycle_nodes[node_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary node = cycle_nodes[node_index];
		const int32_t x = int32_t(node.get("+0x00_x", node.get("+0x1c_finalized_x", 0)));
		const int32_t y = int32_t(node.get("+0x04_y", node.get("+0x20_finalized_y", 0)));
		Dictionary candidate;
		candidate["node_id"] = node.get("node_id", "");
		candidate["x"] = x;
		candidate["y"] = y;
		const bool interior = x >= 1 && x < width - 1 && y >= 1 && y < height - 1;
		candidate["interior_by_0x4a32ca"] = interior;
		int32_t clearance = -1;
		if (interior) {
			clearance = std::min<int32_t>(std::min<int32_t>(x, width - x - 1), std::min<int32_t>(y, height - y - 1));
			if (clearance > best_clearance) {
				best_clearance = clearance;
				best_x = x;
				best_y = y;
			}
		}
		candidate["border_clearance"] = clearance;
		candidates.append(candidate);
	}
	report["candidate_count"] = candidates.size();
	report["candidates"] = candidates;
	report["best_candidate_x"] = best_x;
	report["best_candidate_y"] = best_y;
	report["best_candidate_border_clearance"] = best_clearance;
	if (seed_in_bounds) {
		report["relocated"] = false;
		report["relocated_seed_x"] = seed.x;
		report["relocated_seed_y"] = seed.y;
		report["relocated_seed_level"] = seed.level;
		return report;
	}
	if (best_x < 0 || best_y < 0) {
		report["status"] = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
		report["relocated"] = false;
		report["relocated_seed_x"] = seed.x;
		report["relocated_seed_y"] = seed.y;
		report["relocated_seed_level"] = seed.level;
		return report;
	}
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	ClipResult clipped = h3maped_clip_point_4a2b33(seed.x, seed.y, best_x, best_y, bounds);
	report["status"] = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
	report["relocated"] = true;
	report["relocated_seed_x"] = clipped.x;
	report["relocated_seed_y"] = clipped.y;
	report["relocated_seed_level"] = seed.level;
	report["clip_branch"] = clipped.branch;
	return report;
}

Dictionary real_span_fill_4a325d_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Array &levels, const Dictionary &polygon_finalizer, uint32_t rng_state_before_boundary, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a325d_real_0x4a2777_boundary_span_fill_executed";
	report["source"] = "h3maped 0x4a325d executed against the real 0x4a2777 boundary buffer produced from finalized 0x4cca55 source-node cycles";
	report["function_address"] = "0x4a325d";
	report["boundary_source_address"] = "0x4a2777";
	report["uses_real_0x4a2777_boundary"] = true;
	report["materializes_project_grid"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;

	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary boundary = boundary_traversal_4a2777_real_cycles_report(normalized_config, runtime_zone_records, levels, polygon_finalizer, rng_state_before_boundary, &zone_words, &cell_flags);
	report["boundary_status"] = boundary.get("status", "");
	report["boundary_unique_cell_count"] = boundary.get("unique_cell_count", 0);
	report["boundary_trace_write_count"] = boundary.get("trace_write_count", 0);
	report["boundary_rng_state_after_0x4a2777_uint32"] = boundary.get("rng_state_after_0x4a2777_uint32", 0);
	Array source_node_walks = polygon_finalizer.get("source_node_walks", Array());

	Dictionary split_by_runtime;
	for (int64_t level_index = 0; level_index < levels.size(); ++level_index) {
		if (Variant(levels[level_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary level = levels[level_index];
		Array split_calls = level.get("polygon_split_calls", Array());
		for (int64_t split_index = 0; split_index < split_calls.size(); ++split_index) {
			if (Variant(split_calls[split_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary split = split_calls[split_index];
			split_by_runtime[String::num_int64(int64_t(split.get("runtime_zone_index", -1)))] = split;
		}
	}

	Array zone_fill_reports;
	int32_t filled_zone_count = 0;
	int32_t seed_blocked_count = 0;
	int32_t missing_seed_count = 0;
	int32_t total_filled_cell_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
		if (Variant(runtime_zone_records[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime_zone = runtime_zone_records[runtime_index];
		const int32_t runtime_zone_index = int32_t(runtime_zone.get("runtime_zone_index", runtime_index));
		Dictionary split = split_by_runtime.get(String::num_int64(runtime_zone_index), Dictionary());
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["zone_word_id"] = runtime_zone_index;
		if (split.is_empty()) {
			missing_seed_count += 1;
			zone_report["status"] = "blocked_missing_0x4a3a03_split_seed";
			zone_fill_reports.append(zone_report);
			continue;
		}
		const int32_t seed_x = int32_t(split.get("x", 0));
		const int32_t seed_y = int32_t(split.get("y", 0));
		const int32_t seed_level = int32_t(split.get("level", 0));
		SpanRecord seed{ seed_x, seed_y, seed_level };
		zone_report["seed_x"] = seed_x;
		zone_report["seed_y"] = seed_y;
		zone_report["seed_level"] = seed_level;
		zone_report["seed_source"] = "0x4a3a03 runtime-zone split call x/y/level after 0x4a19ed bbox rescale";

		Dictionary matching_walk;
		for (int64_t walk_index = 0; walk_index < source_node_walks.size(); ++walk_index) {
			if (Variant(source_node_walks[walk_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary walk = source_node_walks[walk_index];
			if (int32_t(walk.get("runtime_zone_index", -1)) == runtime_zone_index) {
				matching_walk = walk;
				break;
			}
		}
		Dictionary relocation = seed_relocation_4a325d_report(matching_walk, seed, width, height, level_count);
		zone_report["seed_relocation_status"] = relocation.get("status", "");
		zone_report["seed_relocation"] = relocation;
		if (bool(relocation.get("relocated", false))) {
			seed.x = int32_t(relocation.get("relocated_seed_x", seed.x));
			seed.y = int32_t(relocation.get("relocated_seed_y", seed.y));
			seed.level = int32_t(relocation.get("relocated_seed_level", seed.level));
		}
		zone_report["effective_seed_x"] = seed.x;
		zone_report["effective_seed_y"] = seed.y;
		zone_report["effective_seed_level"] = seed.level;

		const bool seed_available = h3maped_cell_unassigned(zone_words, width, height, seed.x, seed.y, seed.level);
		zone_report["seed_unassigned_before_fill"] = seed_available;
		if (!seed_available) {
			seed_blocked_count += 1;
		}
		SpanFillResult fill = h3maped_span_fill_4a325d(zone_words, cell_flags, width, height, level_count, water_code, runtime_zone_index, seed);
		if (fill.filled_cell_count > 0) {
			filled_zone_count += 1;
		}
		total_filled_cell_count += fill.filled_cell_count;
		pushed_span_count += fill.pushed_span_count;
		popped_span_count += fill.popped_span_count;
		max_pending_span_count = std::max(max_pending_span_count, fill.max_pending_span_count);
		out_of_bounds_span_count += fill.out_of_bounds_span_count;
		blocked_initial_span_count += fill.blocked_initial_span_count;
		zone_report["status"] = fill.filled_cell_count > 0 ? String("0x4a325d_span_fill_executed") : String("0x4a325d_span_fill_no_cells_written");
		zone_report["filled_cell_count"] = fill.filled_cell_count;
		zone_report["pushed_span_count"] = fill.pushed_span_count;
		zone_report["popped_span_count"] = fill.popped_span_count;
		zone_report["max_pending_span_count"] = fill.max_pending_span_count;
		zone_report["out_of_bounds_span_count"] = fill.out_of_bounds_span_count;
		zone_report["blocked_initial_span_count"] = fill.blocked_initial_span_count;
		zone_report["trace_preview"] = fill.trace_preview;
		zone_fill_reports.append(zone_report);
	}

	const int32_t cell_count = int32_t(zone_words.size());
	int32_t total_boundary_or_filled_cell_count = 0;
	int32_t remaining_unassigned_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	Dictionary cells_by_zone_word;
	for (int32_t index = 0; index < cell_count; ++index) {
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			remaining_unassigned_cell_count += 1;
		} else {
			total_boundary_or_filled_cell_count += 1;
			const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
			const String key = String::num_int64(zone_word_id);
			cells_by_zone_word[key] = int32_t(cells_by_zone_word.get(key, 0)) + 1;
		}
		if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
			reserved_flag_cell_count += 1;
		}
	}

	report["runtime_zone_fill_attempt_count"] = zone_fill_reports.size();
	report["filled_zone_count"] = filled_zone_count;
	report["seed_blocked_count"] = seed_blocked_count;
	report["missing_seed_count"] = missing_seed_count;
	report["seed_relocation_count"] = 0;
	report["seed_relocation_status"] = seed_blocked_count == 0 ? String("not_needed_all_current_seeds_unassigned") : String("0x4a32b2_relocation_ported_not_needed_for_current_in_bounds_seed_span_scan");
	report["unique_filled_cell_count"] = total_filled_cell_count;
	report["total_boundary_or_filled_cell_count"] = total_boundary_or_filled_cell_count;
	report["remaining_unassigned_cell_count"] = remaining_unassigned_cell_count;
	report["reserved_flag_cell_count"] = reserved_flag_cell_count;
	report["pushed_span_count"] = pushed_span_count;
	report["popped_span_count"] = popped_span_count;
	report["max_pending_span_count"] = max_pending_span_count;
	report["out_of_bounds_span_count"] = out_of_bounds_span_count;
	report["blocked_initial_span_count"] = blocked_initial_span_count;
	report["cells_by_zone_word"] = cells_by_zone_word;
	report["zone_fill_reports"] = zone_fill_reports;
	report["blocked_next"] = "adopt this h3maped zone-word buffer into 0x4a3f27 terrain/cell writeout, then towns, roads, blockers, guards, mines, rewards, and final package output";
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return report;
}

Dictionary terrain_cell_writeout_4a3f27_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Array &levels, const Dictionary &polygon_finalizer, const Dictionary &terrain_selection, uint32_t rng_state_before_boundary) {
	Dictionary report;
	report["status"] = "0x4a3f27_terrain_cell_writeout_from_real_0x4a325d_zone_words_ported_inspection_only";
	report["source"] = "h3maped 0x4a3f27 terrain fill/repaint schedule consumes the 0x4a325d zone-word buffer and assigns each generated cell its runtime-zone terrain, with remaining unassigned cells carried as water/void for later TerrainPlacement art/index/flip normalization";
	report["function_address"] = "0x4a3f27";
	report["span_fill_source_address"] = "0x4a325d";
	report["tile_serializer_address"] = "0x49b2b6";
	report["materializes_project_grid"] = true;
	report["project_grid_public_runtime_adoption"] = false;
	report["materializes_package_tiles"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;

	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary span_fill = real_span_fill_4a325d_report(normalized_config, runtime_zone_records, levels, polygon_finalizer, rng_state_before_boundary, &zone_words, &cell_flags);
	report["span_fill_status"] = span_fill.get("status", "");
	report["span_fill_total_boundary_or_filled_cell_count"] = span_fill.get("total_boundary_or_filled_cell_count", 0);
	report["span_fill_remaining_unassigned_cell_count"] = span_fill.get("remaining_unassigned_cell_count", 0);

	Array selected_terrain_names = terrain_selection.get("selected_project_terrain_ids", Array());
	Array selected_terrain_codes = terrain_selection.get("selected_h3maped_terrain_ids", Array());
	Dictionary terrain_name_counts;
	Dictionary h3_terrain_code_counts;
	Dictionary cells_by_zone_word;
	Dictionary repaint_cells_by_terrain_code;
	Array per_zone_repaint_records;
	PackedInt32Array terrain_code_u16;
	PackedInt32Array tile_byte_0_terrain_id_u8;
	PackedInt32Array tile_byte_1_terrain_art_u8;
	PackedInt32Array tile_byte_2_river_type_u8;
	PackedInt32Array tile_byte_3_river_art_u8;
	PackedInt32Array tile_byte_4_road_type_u8;
	PackedInt32Array tile_byte_5_road_art_u8;
	PackedInt32Array tile_byte_6_flags_u8;
	PackedInt32Array generated_cell_word_0x24_u32;
	PackedInt32Array generated_cell_word_0x28_u32;
	int32_t reserved_cell_count = 0;
	int32_t unassigned_cell_count = 0;
	int32_t non_water_terrain_cell_count = 0;
	const int32_t cell_count = int32_t(zone_words.size());
	terrain_code_u16.resize(cell_count);
	tile_byte_0_terrain_id_u8.resize(cell_count);
	tile_byte_1_terrain_art_u8.resize(cell_count);
	tile_byte_2_river_type_u8.resize(cell_count);
	tile_byte_3_river_art_u8.resize(cell_count);
	tile_byte_4_road_type_u8.resize(cell_count);
	tile_byte_5_road_art_u8.resize(cell_count);
	tile_byte_6_flags_u8.resize(cell_count);
	generated_cell_word_0x24_u32.resize(cell_count);
	generated_cell_word_0x28_u32.resize(cell_count);
	for (int32_t index = 0; index < cell_count; ++index) {
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		int32_t h3_terrain_code = 8;
		String terrain_name = "water";
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			unassigned_cell_count += 1;
		} else {
			const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
			const String zone_key = String::num_int64(zone_word_id);
			cells_by_zone_word[zone_key] = int32_t(cells_by_zone_word.get(zone_key, 0)) + 1;
			if (zone_word_id >= 0 && zone_word_id < selected_terrain_names.size()) {
				terrain_name = String(selected_terrain_names[zone_word_id]);
			}
			if (zone_word_id >= 0 && zone_word_id < selected_terrain_codes.size()) {
				h3_terrain_code = int32_t(selected_terrain_codes[zone_word_id]);
			}
		}
		if (h3_terrain_code != 8) {
			non_water_terrain_cell_count += 1;
			const String terrain_code_key = String::num_int64(h3_terrain_code);
			repaint_cells_by_terrain_code[terrain_code_key] = int32_t(repaint_cells_by_terrain_code.get(terrain_code_key, 0)) + 1;
		}
		const uint32_t generated_cell_0x24 = uint32_t(h3_terrain_code) & 0x3fU;
		const uint32_t generated_cell_0x28 = 0U;
		generated_cell_word_0x24_u32.set(index, int32_t(generated_cell_0x24));
		generated_cell_word_0x28_u32.set(index, int32_t(generated_cell_0x28));
		terrain_code_u16.set(index, int32_t(generated_cell_0x24 & 0x3fU));
		tile_byte_0_terrain_id_u8.set(index, int32_t(generated_cell_0x24 & 0x3fU));
		tile_byte_1_terrain_art_u8.set(index, 0);
		tile_byte_2_river_type_u8.set(index, 0);
		tile_byte_3_river_art_u8.set(index, 0);
		tile_byte_4_road_type_u8.set(index, 0);
		tile_byte_5_road_art_u8.set(index, 0);
		tile_byte_6_flags_u8.set(index, 0);
		terrain_name_counts[terrain_name] = int32_t(terrain_name_counts.get(terrain_name, 0)) + 1;
		const String code_key = String::num_int64(h3_terrain_code);
		h3_terrain_code_counts[code_key] = int32_t(h3_terrain_code_counts.get(code_key, 0)) + 1;
		if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
			reserved_cell_count += 1;
		}
	}

	report["cell_count"] = cell_count;
	report["tile_byte_zero_terrain_cell_count"] = cell_count;
	report["tile_byte_zero_non_water_terrain_cell_count"] = non_water_terrain_cell_count;
	report["tile_byte_one_nonzero_art_cell_count"] = 0;
	report["tile_byte_six_terrain_flip_cell_count"] = 0;
	report["reserved_flag_cell_count"] = reserved_cell_count;
	report["unassigned_water_cell_count"] = unassigned_cell_count;
	report["terrain_name_counts"] = terrain_name_counts;
	report["h3_terrain_code_counts"] = h3_terrain_code_counts;
	report["cells_by_zone_word"] = cells_by_zone_word;
	for (int64_t zone_index = 0; zone_index < selected_terrain_codes.size(); ++zone_index) {
		const int32_t zone_terrain_code = int32_t(selected_terrain_codes[zone_index]);
		const String zone_key = String::num_int64(zone_index);
		const int32_t repaint_cell_count = zone_terrain_code == 8 ? 0 : int32_t(cells_by_zone_word.get(zone_key, 0));
		Dictionary zone_record;
		zone_record["runtime_zone_index"] = int32_t(zone_index);
		zone_record["terrain_code"] = zone_terrain_code;
		zone_record["terrain_name"] = zone_index < selected_terrain_names.size() ? String(selected_terrain_names[zone_index]) : terrain_for_h3maped_id(zone_terrain_code);
		zone_record["single_cell_repaint_count"] = repaint_cell_count;
		zone_record["skipped_water_zone"] = zone_terrain_code == 8;
		per_zone_repaint_records.append(zone_record);
	}
	Dictionary terrain_repaint_schedule;
	terrain_repaint_schedule["status"] = "0x4a3f27_water_then_zone_single_cell_repaint_schedule_ported_inspection_only";
	terrain_repaint_schedule["full_map_water_repaint_address"] = "0x4a4025";
	terrain_repaint_schedule["per_zone_repaint_loop_address"] = "0x4a4082";
	terrain_repaint_schedule["per_cell_repaint_call_address"] = "0x4a415a";
	terrain_repaint_schedule["initial_water_terrain_id"] = 8;
	terrain_repaint_schedule["initial_water_full_map_cell_count"] = cell_count;
	terrain_repaint_schedule["two_level_rock_prefill_address"] = "0x4a3f97";
	terrain_repaint_schedule["two_level_rock_prefill_executed"] = level_count > 1;
	terrain_repaint_schedule["reserved_flag_gate"] = "cell+0x28 top-nibble bit tested at 0x4a4150 before 1x1 zone repaint";
	terrain_repaint_schedule["owner_byte_gate"] = "cell+0x20 signed owner byte compared with runtime zone index at 0x4a4142";
	terrain_repaint_schedule["single_cell_repaint_count"] = non_water_terrain_cell_count;
	terrain_repaint_schedule["repaint_cells_by_terrain_code"] = repaint_cells_by_terrain_code;
	terrain_repaint_schedule["per_zone_repaint_records"] = per_zone_repaint_records;
	terrain_repaint_schedule["materializes_visual_art"] = false;
	report["terrain_repaint_schedule"] = terrain_repaint_schedule;
	report["terrain_code_u16"] = terrain_code_u16;
	report["generated_cell_word_0x24_u32"] = generated_cell_word_0x24_u32;
	report["generated_cell_word_0x28_u32"] = generated_cell_word_0x28_u32;
	report["tile_byte_0_terrain_id_u8"] = tile_byte_0_terrain_id_u8;
	report["tile_byte_1_terrain_art_u8"] = tile_byte_1_terrain_art_u8;
	report["tile_byte_2_river_type_u8"] = tile_byte_2_river_type_u8;
	report["tile_byte_3_river_art_u8"] = tile_byte_3_river_art_u8;
	report["tile_byte_4_road_type_u8"] = tile_byte_4_road_type_u8;
	report["tile_byte_5_road_art_u8"] = tile_byte_5_road_art_u8;
	report["tile_byte_6_flags_u8"] = tile_byte_6_flags_u8;
	report["tile_byte_writeout_status"] = "0x49b2b6_terrain_id_byte_packed_art_flip_pending";
	report["tile_byte_writeout_source"] = "0x49b2b6 serializes generated cell+0x24 bits 0..5 to byte 0; terrain art byte 1 and terrain flip byte 6 bits 0..1 remain blocked until TerrainPlacement 0x4bcff5/0x4bd099 normalization is ported";
	Dictionary final_sweep_boundary_counter = generated_grid_final_sweep_boundary_counter_report(terrain_code_u16, width, height, level_count);
	report["final_sweep_boundary_counter_status"] = final_sweep_boundary_counter.get("status", "");
	report["final_sweep_boundary_counter"] = final_sweep_boundary_counter;
	Dictionary terrain_visual_projection = generated_grid_visual_projection_report(terrain_code_u16, final_sweep_boundary_counter.get("boundary_counts_u8", PackedInt32Array()), width, height, level_count, uint32_t(int64_t(span_fill.get("boundary_rng_state_after_0x4a2777_uint32", rng_state_before_boundary))));
	report["terrain_visual_projection_status"] = terrain_visual_projection.get("status", "");
	report["terrain_visual_projection"] = terrain_visual_projection;
	report["tile_serializer_contract_status"] = "0x49b2b6_generated_cell_tile_serializer_bit_contract_ported";
	report["tile_serializer_contract"] = tile_serializer_49b2b6_contract_report();
	report["terrain_art_index_flip_status"] = "pending_TerrainPlacement_0x4bcff5_0x4bd099_art_index_flip_writeout";
	Array blocked_legacy_reasons;
	blocked_legacy_reasons.append("legacy_h3maped_small_rmg_inspection_ledger uses positive_visual_hash frame selection");
	blocked_legacy_reasons.append("scripts/core/TerrainPlacementRules.gd is project-side visual behavior, not an exact h3maped.exe TerrainPlacement classifier");
	blocked_legacy_reasons.append("no custom art-index or flip heuristics are allowed in the clean h3maped reset path");
	Array required_terrainplacement_addresses;
	required_terrainplacement_addresses.append("0x4bcff5");
	required_terrainplacement_addresses.append("0x4bd099");
	required_terrainplacement_addresses.append("0x4bb681");
	required_terrainplacement_addresses.append("0x49b2b6");
	required_terrainplacement_addresses.append("0x543764");
	required_terrainplacement_addresses.append("0x543780");
	required_terrainplacement_addresses.append("0x54379c");
	required_terrainplacement_addresses.append("0x5437dc");
	Dictionary art_flip_blocker;
	art_flip_blocker["status"] = "blocked_until_exact_h3maped_TerrainPlacement_classifier_recovered";
	art_flip_blocker["legacy_visual_classifier_reuse_allowed"] = false;
	art_flip_blocker["blocked_legacy_reasons"] = blocked_legacy_reasons;
	art_flip_blocker["required_addresses"] = required_terrainplacement_addresses;
	art_flip_blocker["serializer_bit_evidence"] = "0x49b2b6 packs cell+0x24 bits 6..13 into tile byte 1 and cell+0x28 bits 15..16 into tile byte 6 bits 0..1";
	art_flip_blocker["final_normalization_contract"] = terrain_final_normalization_contract_report();
	Dictionary repaint_boundary;
	repaint_boundary["status"] = "0x4bd099_0x4bb681_TerrainPlacement_repaint_rectangle_loop_recovered_boundary_only";
	repaint_boundary["constructor_address"] = "0x4bb5ce";
	repaint_boundary["wrapper_address"] = "0x4bd099";
	repaint_boundary["rectangle_loop_address"] = "0x4bb681";
	repaint_boundary["cell_ensure_address"] = "0x4bb71b";
	repaint_boundary["changed_cell_update_address"] = "0x4bb74b";
	repaint_boundary["same_terrain_neighbor_touch_address"] = "0x4bad0f";
	repaint_boundary["terrain_id_compare"] = "0x4bb6ba shifts ensured scratch byte right by 1, masks 0x0f, and compares it with the TerrainPlacement current terrain id at adapter+0x04";
	repaint_boundary["loop_arguments"] = "x, y, width, height passed through 0x4bd099 into 0x4bb681";
	repaint_boundary["materializes_art_flip"] = false;
	repaint_boundary["blocked_next"] = "recover 0x4bb74b/0x4bad0f/0x4bcfc3 and toolkit class tables before writing tile byte 1 or tile byte 6 terrain flip bits";
	Dictionary changed_cell_update;
	changed_cell_update["status"] = "0x4bb74b_changed_cell_update_boundary_recovered_no_art_flip_materialization";
	changed_cell_update["entry_address"] = "0x4bb74b";
	changed_cell_update["visual_record_resolve_address"] = "0x4bcfc3";
	changed_cell_update["visual_record_table_address"] = "0x5436b8";
	changed_cell_update["scratch_write_address"] = "0x4bad0f";
	changed_cell_update["neighbor_validation_vertical_address"] = "0x4bba13";
	changed_cell_update["neighbor_validation_horizontal_address"] = "0x4bba36";
	changed_cell_update["neighbor_touch_address"] = "0x4bba59";
	changed_cell_update["neighbor_mask_address"] = "0x4bf3f4";
	changed_cell_update["fallback_neighbor_table_range"] = "0x5a5028..0x5a5068";
	changed_cell_update["scratch_word_bit_0"] = "dirty/materialized flag set by 0x4bad0f";
	changed_cell_update["scratch_word_bits_1_4"] = "terrain id from visual record byte 0 low nibble";
	changed_cell_update["scratch_word_bits_5_11"] = "terrain art index from visual record byte 4 low seven bits";
	changed_cell_update["scratch_word_bit_12"] = "terrain flag A from visual record byte 8 bit 0";
	changed_cell_update["scratch_word_bit_13"] = "terrain flag B from visual record byte 9 bit 0";
	changed_cell_update["scratch_write_contract"] = terrain_scratch_write_contract_report();
	changed_cell_update["materializes_tile_byte_1"] = false;
	changed_cell_update["materializes_tile_byte_6_terrain_flags"] = false;
	Dictionary visual_classifier;
	Array terrain_toolkit_objects;
	terrain_toolkit_objects.append("0x5a4130");
	terrain_toolkit_objects.append("0x5a3d58");
	terrain_toolkit_objects.append("0x5a3988");
	terrain_toolkit_objects.append("0x5a3b70");
	terrain_toolkit_objects.append("0x5a3f40");
	terrain_toolkit_objects.append("0x5a46b8");
	terrain_toolkit_objects.append("0x5a4c70");
	terrain_toolkit_objects.append("0x5a4a88");
	terrain_toolkit_objects.append("0x5a48a0");
	terrain_toolkit_objects.append("0x5a4128");
	Array terrain_toolkit_vtables;
	terrain_toolkit_vtables.append("0x543764");
	terrain_toolkit_vtables.append("0x543780");
	terrain_toolkit_vtables.append("0x54379c");
	Array terrain_static_tables;
	terrain_static_tables.append("0x542f88");
	terrain_static_tables.append("0x543108");
	terrain_static_tables.append("0x543380");
	terrain_static_tables.append("0x5434f0");
	terrain_static_tables.append("0x5435b0");
	Array terrain_toolkit_constructor_records;
	const auto append_toolkit_record = [&terrain_toolkit_constructor_records](const char *object_address, const char *constructor_address, int terrain_id, int arg_flag_a, int arg_flag_b, int range_probability, int row_count, const char *table_address) {
		Dictionary record;
		record["object_address"] = object_address;
		record["constructor_address"] = constructor_address;
		record["terrain_id"] = terrain_id;
		record["arg_flag_a"] = arg_flag_a;
		record["arg_flag_b"] = arg_flag_b;
		record["range_probability"] = range_probability;
		record["row_count"] = row_count;
		record["table_address"] = table_address;
		terrain_toolkit_constructor_records.append(record);
	};
	append_toolkit_record("0x5a4130", "0x4ba868", 0, 1, 1, 0x32, 0x2e, "0x543380");
	append_toolkit_record("0x5a3d58", "0x4ba868", 1, 0, 1, 0x46, 0x18, "0x5434f0");
	append_toolkit_record("0x5a3988", "0x4ba868", 2, 1, 1, 0x32, 0x4f, "0x543108");
	append_toolkit_record("0x5a3b70", "0x4ba868", 3, 1, 1, 0x50, 0x4f, "0x543108");
	append_toolkit_record("0x5a3f40", "0x4ba868", 4, 1, 1, 0x50, 0x4f, "0x543108");
	append_toolkit_record("0x5a46b8", "0x4ba868", 5, 1, 1, 0x50, 0x4f, "0x543108");
	append_toolkit_record("0x5a4c70", "0x4ba868", 6, 1, 1, 0x3c, 0x4f, "0x543108");
	append_toolkit_record("0x5a4a88", "0x4ba868", 7, 1, 1, 0x50, 0x4f, "0x543108");
	append_toolkit_record("0x5a48a0", "0x4ba868", 8, 0, 0, 0x00, 0x21, "0x5435b0");
	append_toolkit_record("0x5a4128", "0x4baa66", 9, 0, 0, 0x00, 0x00, "none");
	visual_classifier["status"] = "0x4bcfc3_0x4bce6d_toolkit_visual_selector_recovered_boundary_only";
	visual_classifier["selector_address"] = "0x4bcfc3";
	visual_classifier["neighbor_mask_address"] = "0x4bce6d";
	visual_classifier["toolkit_table_address"] = "0x5436b8";
	visual_classifier["toolkit_object_addresses"] = terrain_toolkit_objects;
	visual_classifier["toolkit_vtable_addresses"] = terrain_toolkit_vtables;
	visual_classifier["toolkit_constructor_records"] = terrain_toolkit_constructor_records;
	visual_classifier["toolkit_constructor_address"] = "0x4ba868";
	visual_classifier["simple_toolkit_constructor_address"] = "0x4ba9c8";
	visual_classifier["simple_toolkit_zero_constructor_address"] = "0x4baa66";
	visual_classifier["static_visual_table_addresses"] = terrain_static_tables;
	visual_classifier["neighbor_probe_vfunc_offset"] = "+0x08";
	visual_classifier["visual_record_resolve_vfunc_offset"] = "+0x10";
	visual_classifier["complex_toolkit_vtable_address"] = "0x543780";
	visual_classifier["complex_neighbor_probe_vfunc_plus_0x08"] = "0x4ba91d";
	visual_classifier["complex_direct_record_reader_vfunc_plus_0x0c"] = "0x4ba92b";
	visual_classifier["complex_visual_resolve_vfunc_plus_0x10"] = "0x4ba938";
	visual_classifier["complex_visual_writeback_vfunc_plus_0x14"] = "0x4ba989";
	visual_classifier["simple_toolkit_vtable_address"] = "0x54379c";
	visual_classifier["simple_neighbor_probe_vfunc_plus_0x08"] = "0x4baa81";
	visual_classifier["simple_direct_record_reader_vfunc_plus_0x0c"] = "0x4baa86";
	visual_classifier["simple_visual_resolve_vfunc_plus_0x10"] = "0x4baa94";
	visual_classifier["simple_visual_writeback_vfunc_plus_0x14"] = "0x4baabf";
	visual_classifier["neighbor_mask_inputs"] = "up, down, left, and right same-terrain scratch cells; matching neighbor art is accepted through toolkit vfunc +0x08 before shifting the mask";
	visual_classifier["selector_flow"] = "0x4bcfc3 calls 0x4bce6d, indexes terrain toolkit table 0x5436b8 by terrain id, then calls toolkit vfunc +0x10 with the reduced neighbor mask and previous art id -1";
	visual_classifier["complex_resolve_flow"] = "0x4ba938 reuses a previous nonzero visual id when valid, otherwise chooses common or alternate contiguous ranges at object+0x14/object+0x1c through 0x4e7276";
	visual_classifier["simple_resolve_flow"] = "0x4baa94 reuses a previous nonzero visual id when valid, otherwise chooses from global range 0x5a4318/0x5a431c through 0x4e7276";
	visual_classifier["terrain_classifier_contract"] = terrain_classifier_contract_report();
	visual_classifier["static_range_lookup_contract"] = terrain_visual_static_range_lookup_contract_report();
	visual_classifier["static_table_contracts"] = terrain_visual_static_table_contracts_report();
	visual_classifier["visual_row_selection_contract"] = terrain_visual_row_selection_contract_report();
	visual_classifier["materializes_visual_record"] = false;
	visual_classifier["blocked_next"] = "port the toolkit static-table lookup bodies and feed their selected visual record into 0x4bad0f/0x49acf6";
	changed_cell_update["visual_classifier"] = visual_classifier;
	Dictionary copyback_gate;
	copyback_gate["status"] = "0x4bc988_TerrainPlacement_retouch_gate_recovered_copyback_pending";
	copyback_gate["gate_address"] = "0x4bc988";
	copyback_gate["vertical_neighbor_gate_address"] = "0x4bba13";
	copyback_gate["horizontal_neighbor_gate_address"] = "0x4bba36";
	copyback_gate["cell_ensure_address"] = "0x4bb71b";
	copyback_gate["terrain_class_table_address"] = "0x5436b8";
	copyback_gate["same_class_region_gate_address"] = "0x4bc928";
	copyback_gate["ordered_insert_helper_address"] = "0x4bd1c1";
	copyback_gate["container_insert_address"] = "0x4bd374";
	copyback_gate["container_lookup_address"] = "0x4bd3c5";
	copyback_gate["copyback_to_generated_cell_0x24_0x28"] = false;
	copyback_gate["blocked_next"] = "recover the generated-cell adapter virtual write path after ordered scratch/container updates";
	Dictionary adapter_writeback;
	adapter_writeback["status"] = "0x49acc5_0x49acf6_type_random_map_terrain_writeback_recovered_not_materialized";
	adapter_writeback["adapter_vtable_address"] = "0x540a14";
	adapter_writeback["adapter_constructor_address"] = "0x499f60";
	adapter_writeback["virtual_write_entry_address"] = "0x49acc5";
	adapter_writeback["cell_write_helper_address"] = "0x49acf6";
	adapter_writeback["read_full_record_address"] = "0x49ad83";
	adapter_writeback["read_terrain_id_address"] = "0x49adde";
	adapter_writeback["read_terrain_art_address"] = "0x49ae01";
	adapter_writeback["cell_word_0x24_terrain_bits"] = "bits 0..5";
	adapter_writeback["cell_word_0x24_art_bits"] = "bits 6..13";
	adapter_writeback["cell_word_0x28_terrain_flag_bits"] = "bits 15..16";
	adapter_writeback["materializes_generated_cell_words"] = false;
	adapter_writeback["blocked_next"] = "feed exact TerrainPlacement visual record fields through this writeback path after classifier recovery";
	copyback_gate["adapter_writeback"] = adapter_writeback;
	changed_cell_update["copyback_gate"] = copyback_gate;
	changed_cell_update["blocked_next"] = "recover visual record selection through 0x4bce6d and class-table vfunc +0x10 before copying scratch art/flag bits into generated cell+0x24/+0x28";
	repaint_boundary["changed_cell_update"] = changed_cell_update;
	art_flip_blocker["terrainplacement_repaint_boundary"] = repaint_boundary;
	report["terrain_art_index_flip_blocker"] = art_flip_blocker;

	Dictionary level_record;
	level_record["level_index"] = 0;
	level_record["level_kind"] = "surface";
	level_record["width"] = width;
	level_record["height"] = height;
	level_record["tile_count"] = width * height;
	level_record["terrain_code_u16"] = terrain_code_u16;
	level_record["generated_cell_word_0x24_u32"] = generated_cell_word_0x24_u32;
	level_record["generated_cell_word_0x28_u32"] = generated_cell_word_0x28_u32;
	level_record["tile_byte_0_terrain_id_u8"] = tile_byte_0_terrain_id_u8;
	level_record["tile_byte_1_terrain_art_u8"] = tile_byte_1_terrain_art_u8;
	level_record["tile_byte_2_river_type_u8"] = tile_byte_2_river_type_u8;
	level_record["tile_byte_3_river_art_u8"] = tile_byte_3_river_art_u8;
	level_record["tile_byte_4_road_type_u8"] = tile_byte_4_road_type_u8;
	level_record["tile_byte_5_road_art_u8"] = tile_byte_5_road_art_u8;
	level_record["tile_byte_6_flags_u8"] = tile_byte_6_flags_u8;
	level_record["tile_byte_writeout_status"] = report.get("tile_byte_writeout_status", "");
	level_record["terrain_counts"] = terrain_name_counts;
	level_record["h3_terrain_code_counts"] = h3_terrain_code_counts;
	Array grid_levels;
	grid_levels.append(level_record);
	Dictionary terrain_grid;
	terrain_grid["schema_id"] = "aurelion_native_rmg_terrain_grid_v1";
	terrain_grid["schema_version"] = 1;
	terrain_grid["generation_status"] = "h3maped_0x4a3f27_terrain_grid_adopted_inspection_only";
	terrain_grid["public_runtime_adoption_status"] = "blocked_until_TerrainPlacement_art_index_flip_and_later_rmg_phases";
	terrain_grid["width"] = width;
	terrain_grid["height"] = height;
	terrain_grid["level_count"] = level_count;
	terrain_grid["tile_count"] = cell_count;
	terrain_grid["terrain_counts"] = terrain_name_counts;
	terrain_grid["h3_terrain_code_counts"] = h3_terrain_code_counts;
	terrain_grid["levels"] = grid_levels;
	terrain_grid["tile_byte_writeout_status"] = report.get("tile_byte_writeout_status", "");
	terrain_grid["final_sweep_boundary_counter_status"] = final_sweep_boundary_counter.get("status", "");
	terrain_grid["terrain_visual_projection_status"] = terrain_visual_projection.get("status", "");
	terrain_grid["materialized_level_count"] = grid_levels.size();
	report["terrain_grid_status"] = terrain_grid.get("generation_status", "");
	report["terrain_grid"] = terrain_grid;
	report["blocked_next"] = "port TerrainPlacement art/index/flip normalization, then place owned towns, roads, blockers, guards, mines, rewards, and final packages";
	return report;
}

Dictionary zone_footprint_schedule_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Dictionary &coordinate_replay, const Dictionary &terrain_selection) {
	Dictionary report;
	report["status"] = "0x4a3a03_zone_footprint_schedule_ported";
	report["source"] = "h3maped 0x4a3a03 per-level runtime-zone collection, small-land synthetic fallback decision, and helper schedule before 0x4a2777/0x4a325d/0x4a3710 cell materialization";
	report["function_address"] = "0x4a3a03";
	report["zone_collection_address"] = "0x4a3a2b..0x4a3a86";
	report["synthetic_source_zone_branch_address"] = "0x4a3a9d..0x4a3e12";
	report["polygon_constructor_address"] = "0x4cc788";
	report["polygon_split_address"] = "0x4ccb64";
	report["polygon_finalize_address"] = "0x4ccdfc";
	report["polygon_locator_address"] = "0x4cca55";
	report["first_helper_address"] = "0x4a2777";
	report["second_helper_address"] = "0x4a325d";
	report["finalizer_address"] = "0x4a3710";
	report["materializes_zone_cells"] = false;
	report["materializes_boundary_cells"] = false;
	report["materializes_span_fill"] = false;

	Dictionary polygon_seed = polygon_seed_4cc788_report();
	report["polygon_seed_status"] = polygon_seed.get("status", "");
	report["polygon_seed"] = polygon_seed;

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

	Dictionary scaled_by_runtime;
	Array scaled_coordinates = coordinate_replay.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled_coordinates.size(); ++index) {
		if (Variant(scaled_coordinates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scaled = scaled_coordinates[index];
		scaled_by_runtime[String::num_int64(int64_t(scaled.get("runtime_zone_index", -1)))] = scaled;
	}

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	Array levels;
	int32_t total_matching_runtime_zones = 0;
	int32_t total_polygon_split_calls = 0;
	int32_t appended_synthetic_runtime_zone_count = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		Array matching_indices;
		Array split_calls;
		for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
			if (Variant(runtime_zone_records[runtime_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary runtime = runtime_zone_records[runtime_index];
			const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
			Dictionary scaled = scaled_by_runtime.get(String::num_int64(zone_index), Dictionary());
			if (int32_t(scaled.get("level", 0)) != level) {
				continue;
			}
			matching_indices.append(zone_index);
			Dictionary split_call;
			split_call["call_site_address"] = "0x4a3a79";
			split_call["runtime_zone_index"] = zone_index;
			split_call["x"] = scaled.get("x_after_bbox_rescale", 0);
			split_call["y"] = scaled.get("y_after_bbox_rescale", 0);
			split_call["level"] = level;
			split_call["runtime_size_after_bbox_rescale"] = scaled.get("runtime_size_after_bbox_rescale", 0);
			split_call["payload"] = "runtime_zone_pointer";
			split_call["source_fields"] = "runtime_zone+0x10 x/y copied after 0x4a19ed rescale, then pushed to 0x4ccb64";
			split_calls.append(split_call);
		}
		total_matching_runtime_zones += matching_indices.size();
		total_polygon_split_calls += split_calls.size();
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
		level_report["polygon_split_call_count"] = split_calls.size();
		level_report["polygon_split_calls"] = split_calls;
		level_report["helper_call_sequence"] = Array::make("0x4a2777", "0x4a325d", "0x4a3710");
		level_report["helper_call_status"] = "scheduled_not_executed";
		levels.append(level_report);
	}

	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["total_matching_runtime_zones"] = total_matching_runtime_zones;
	report["total_polygon_split_calls"] = total_polygon_split_calls;
	report["appended_synthetic_runtime_zone_count"] = appended_synthetic_runtime_zone_count;
	report["levels"] = levels;
	Dictionary polygon_split = polygon_split_insertion_4ccb64_report(levels, total_polygon_split_calls);
	report["polygon_split_status"] = polygon_split.get("status", "");
	report["polygon_split"] = polygon_split;
	Dictionary polygon_finalizer = polygon_finalizer_4ccdfc_report(levels, total_polygon_split_calls);
	report["polygon_finalizer_status"] = polygon_finalizer.get("status", "");
	report["polygon_finalizer"] = polygon_finalizer;
	Dictionary boundary_traversal = boundary_traversal_4a2777_real_cycles_report(normalized_config, runtime_zone_records, levels, polygon_finalizer, uint32_t(int64_t(terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)))));
	report["boundary_traversal_status"] = boundary_traversal.get("status", "");
	report["boundary_traversal"] = boundary_traversal;
	report["boundary_runtime_zone_walk_count"] = boundary_traversal.get("runtime_zone_walk_count", 0);
	report["boundary_unique_cell_count"] = boundary_traversal.get("unique_cell_count", 0);
	report["boundary_trace_write_count"] = boundary_traversal.get("trace_write_count", 0);
	report["boundary_loop_guard_exhausted"] = boundary_traversal.get("loop_guard_exhausted", false);
	Dictionary real_span_fill = real_span_fill_4a325d_report(normalized_config, runtime_zone_records, levels, polygon_finalizer, uint32_t(int64_t(terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)))));
	report["real_span_fill_status"] = real_span_fill.get("status", "");
	report["real_span_fill"] = real_span_fill;
	report["span_fill_unique_filled_cell_count"] = real_span_fill.get("unique_filled_cell_count", 0);
	report["span_fill_total_boundary_or_filled_cell_count"] = real_span_fill.get("total_boundary_or_filled_cell_count", 0);
	report["span_fill_remaining_unassigned_cell_count"] = real_span_fill.get("remaining_unassigned_cell_count", 0);
	Dictionary terrain_cell_writeout = terrain_cell_writeout_4a3f27_report(normalized_config, runtime_zone_records, levels, polygon_finalizer, terrain_selection, uint32_t(int64_t(terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)))));
	report["terrain_cell_writeout_status"] = terrain_cell_writeout.get("status", "");
	report["terrain_cell_writeout"] = terrain_cell_writeout;
	report["terrain_cell_count"] = terrain_cell_writeout.get("cell_count", 0);
	report["terrain_unassigned_water_cell_count"] = terrain_cell_writeout.get("unassigned_water_cell_count", 0);
	report["next_materialization_status"] = "pending_TerrainPlacement_art_index_flip_and_project_grid_adoption";
	return report;
}

Dictionary footprint_finalizer_4a3710_report(const Dictionary &normalized_config, const Array &runtime_zone_records, int32_t original_same_level_runtime_zone_count) {
	Dictionary report;
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	const bool synthetic_branch_allowed = level_count > 1 || water_code != 0;
	const int32_t final_runtime_zone_count = int32_t(runtime_zone_records.size());
	const int32_t appended_runtime_zone_count = std::max(0, final_runtime_zone_count - original_same_level_runtime_zone_count);
	report["status"] = appended_runtime_zone_count == 0
			? String("0x4a3710_small_land_no_appended_zone_finalizer_ported")
			: String("0x4a3710_appended_zone_adjacency_finalizer_blocked");
	report["source"] = "h3maped 0x4a3710 footprint adjacency finalizer; small one-level land has no appended synthetic runtime zones, so adjacency insertion loops skip and only ordering reset/rebuild calls execute";
	report["function_address"] = "0x4a3710";
	report["call_site_address"] = "0x4a3efc..0x4a3f05";
	report["call_site_start_index_source"] = "0x4a3a86..0x4a3a9a captures runtime-zone vector count before the synthetic branch and passes it at 0x4a3f02";
	report["polygon_locator_address"] = "0x4cca55";
	report["clip_helper_address"] = "0x4a2b33";
	report["zone_order_reset_address"] = "0x49b61b";
	report["per_zone_order_helper_address"] = "0x4a3554";
	report["adjacency_vector_offset"] = "runtime_zone+0xc4";
	report["ordering_vector_offset"] = "runtime_zone+0x3e8";
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["synthetic_branch_allowed_by_0x4a3a9d"] = synthetic_branch_allowed;
	report["original_same_level_runtime_zone_count"] = original_same_level_runtime_zone_count;
	report["final_runtime_zone_count"] = final_runtime_zone_count;
	report["appended_runtime_zone_count"] = appended_runtime_zone_count;

	Array recovered_operations;
	recovered_operations.append("iterates runtime zones from the level's original collected count to the current runtime-zone count");
	recovered_operations.append("finds the source polygon/list node containing each runtime zone rectangle origin through 0x4cca55");
	recovered_operations.append("clips candidate source edges through 0x4a2b33 and rejects endpoints outside map bounds");
	recovered_operations.append("adds bidirectional adjacency records into runtime_zone+0xc4 vectors only for appended synthetic zones");
	recovered_operations.append("resets each runtime zone ordering vector with 0x49b61b, then rebuilds per-zone ordering/depth state with 0x4a3554");
	report["recovered_operations"] = recovered_operations;

	Array phases;
	Dictionary initial_insert_phase;
	initial_insert_phase["address_range"] = "0x4a3735..0x4a3874";
	initial_insert_phase["start_index"] = original_same_level_runtime_zone_count;
	initial_insert_phase["end_index"] = final_runtime_zone_count;
	initial_insert_phase["status"] = appended_runtime_zone_count == 0 ? String("skipped_no_appended_runtime_zones") : String("blocked_appended_runtime_zone_adjacency_schema_pending");
	initial_insert_phase["materialized_adjacency_insert_count"] = 0;
	phases.append(initial_insert_phase);
	Dictionary order_reset_phase;
	order_reset_phase["address_range"] = "0x4a3879..0x4a38be";
	order_reset_phase["zone_order_reset_call_count"] = final_runtime_zone_count;
	order_reset_phase["per_zone_order_helper_call_count"] = original_same_level_runtime_zone_count;
	order_reset_phase["status"] = "0x49b61b_reset_and_0x4a3554_rebuild_scheduled";
	phases.append(order_reset_phase);
	Dictionary ordered_insert_phase;
	ordered_insert_phase["address_range"] = "0x4a38be..0x4a39fc";
	ordered_insert_phase["start_index"] = original_same_level_runtime_zone_count;
	ordered_insert_phase["end_index"] = final_runtime_zone_count;
	ordered_insert_phase["status"] = appended_runtime_zone_count == 0 ? String("skipped_no_appended_runtime_zones") : String("blocked_ordered_appended_adjacency_schema_pending");
	ordered_insert_phase["materialized_adjacency_insert_count"] = 0;
	phases.append(ordered_insert_phase);
	report["phases"] = phases;
	report["zone_order_reset_call_count"] = final_runtime_zone_count;
	report["per_zone_order_helper_call_count"] = original_same_level_runtime_zone_count;
	report["materialized_adjacency_count"] = 0;
	report["materializes_zone_cells"] = false;
	report["materializes_boundary_cells"] = false;
	report["materializes_span_fill"] = false;
	report["blocked_next"] = appended_runtime_zone_count == 0
			? String("0x4a2777 boundary traversal and 0x4a325d span fill remain pending before terrain adoption")
			: String("recover runtime_zone+0xc4 adjacency records before appended-zone finalizer output can be adopted");
	return report;
}

Dictionary span_fill_primitive_4a325d_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a325d_standalone_span_fill_primitive_ported_real_boundary_pending";
	report["source"] = "h3maped 0x4a325d disassembly: stack-backed 12-byte span records, unassigned zone-word scan under 0x00ff0000, zone-byte write to cell+0x20, and reserved flag write to cell+0x2b";
	report["function_address"] = "0x4a325d";
	report["span_vector_push_address"] = "0x4ae1fd";
	report["span_vector_pop_address"] = "0x4ae23e";
	report["seed_relocation_range"] = "0x4a32b2..0x4a338b";
	report["span_loop_range"] = "0x4a3391..0x4a3537";
	report["map_cell_stride_bytes"] = 0x30;
	report["unassigned_zone_word_sentinel"] = "0x00ff0000";
	report["zone_word_write_mask"] = "cell+0x20 = (cell+0x20 & 0xff00ffff) | ((source_zone_word & 0xff) << 16)";
	report["reserved_flag_write"] = "cell+0x2b |= 0x10 unless water_mode == islands and level == 1";
	report["uses_real_0x4a2777_boundary"] = false;
	report["materializes_project_grid"] = false;

	const int32_t width = 12;
	const int32_t height = 10;
	const int32_t level_count = 1;
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t cell_count = width * height * level_count;
	std::vector<uint32_t> zone_words(size_t(cell_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(cell_count), 0);
	const int32_t boundary_zone_word_id = 12;
	const int32_t fill_zone_word_id = 9;
	const int32_t min_x = 2;
	const int32_t min_y = 2;
	const int32_t max_x = 9;
	const int32_t max_y = 7;
	int32_t boundary_cell_count = 0;
	auto mark_boundary = [&](int32_t x, int32_t y) {
		const int64_t index = h3maped_cell_index(width, height, x, y, 0);
		if (index < 0 || index >= int64_t(zone_words.size())) {
			return;
		}
		if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD) {
			boundary_cell_count += 1;
		}
		zone_words[size_t(index)] = (uint32_t(boundary_zone_word_id & 0xff) << 16U);
		cell_flags[size_t(index)] = uint8_t(cell_flags[size_t(index)] | 0x10U);
	};
	for (int32_t x = min_x; x <= max_x; ++x) {
		mark_boundary(x, min_y);
		mark_boundary(x, max_y);
	}
	for (int32_t y = min_y; y <= max_y; ++y) {
		mark_boundary(min_x, y);
		mark_boundary(max_x, y);
	}
	SpanFillResult fill = h3maped_span_fill_4a325d(zone_words, cell_flags, width, height, level_count, water_code, fill_zone_word_id, SpanRecord{ min_x + 1, min_y + 1, 0 });
	int32_t remaining_unassigned_count = 0;
	int32_t filled_zone_word_count = 0;
	int32_t reserved_flag_count = 0;
	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			const int64_t index = h3maped_cell_index(width, height, x, y, 0);
			const uint32_t masked_zone_word = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
			if (masked_zone_word == H3MAPED_UNASSIGNED_ZONE_WORD) {
				remaining_unassigned_count += 1;
			}
			if (masked_zone_word == (uint32_t(fill_zone_word_id & 0xff) << 16U)) {
				filled_zone_word_count += 1;
			}
			if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
				reserved_flag_count += 1;
			}
		}
	}
	Dictionary sample;
	sample["map_width"] = width;
	sample["map_height"] = height;
	sample["level_count"] = level_count;
	sample["h3maped_water_mode_code"] = water_code;
	sample["boundary_min_x"] = min_x;
	sample["boundary_min_y"] = min_y;
	sample["boundary_max_x"] = max_x;
	sample["boundary_max_y"] = max_y;
	sample["boundary_cell_count"] = boundary_cell_count;
	sample["seed_x"] = min_x + 1;
	sample["seed_y"] = min_y + 1;
	sample["seed_level"] = 0;
	sample["filled_cell_count"] = fill.filled_cell_count;
	sample["filled_zone_word_count"] = filled_zone_word_count;
	sample["remaining_unassigned_cell_count"] = remaining_unassigned_count;
	sample["reserved_flag_cell_count"] = reserved_flag_count;
	sample["pushed_span_count"] = fill.pushed_span_count;
	sample["popped_span_count"] = fill.popped_span_count;
	sample["max_pending_span_count"] = fill.max_pending_span_count;
	sample["out_of_bounds_span_count"] = fill.out_of_bounds_span_count;
	sample["blocked_initial_span_count"] = fill.blocked_initial_span_count;
	sample["trace_preview"] = fill.trace_preview;
	report["sample_contract"] = sample;
	report["blocked_next"] = "wire 0x4a2777 real boundary traversal into this 0x4a325d span primitive before project terrain/cell adoption";
	return report;
}

Dictionary boundary_helper_primitives_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2b33_clip_and_0x4a261a_line_writer_primitives_ported";
	report["source"] = "h3maped 0x4a2777 dependencies: 0x4a2b33 integer point/segment clip helper and 0x4a261a deterministic map-cell zone-word line writer";
	report["clip_helper_address"] = "0x4a2b33";
	report["line_writer_address"] = "0x4a261a";
	report["uses_real_0x4a2777_source_node_walk"] = false;
	report["materializes_project_grid"] = false;

	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = int32_t(normalized_config.get("width", 36));
	bounds.max_y = int32_t(normalized_config.get("height", 36));
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
	Array clip_samples;
	clip_samples.append(clip_sample("inside", 10, 10, 30, 30));
	clip_samples.append(clip_sample("left_to_inside", -5, 10, 20, 10));
	clip_samples.append(clip_sample("top_to_inside", 10, -5, 10, 20));
	clip_samples.append(clip_sample("right_to_inside", bounds.max_x + 5, 12, 20, 12));
	clip_samples.append(clip_sample("bottom_to_inside", 12, bounds.max_y + 5, 12, 20));
	report["clip_sample_count"] = clip_samples.size();
	report["clip_samples"] = clip_samples;

	const int32_t sample_width = 12;
	const int32_t sample_height = 8;
	const int32_t level_count = 1;
	const int32_t water_code = water_mode_code(normalized_config);
	std::vector<uint32_t> zone_words(size_t(sample_width * sample_height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(sample_width * sample_height * level_count), 0);
	LineWriteResult line = h3maped_line_writer_4a261a(zone_words, cell_flags, sample_width, sample_height, level_count, water_code, 2, 3, 8, 3, 0, 7);
	int32_t zone_word_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	for (int32_t y = 0; y < sample_height; ++y) {
		for (int32_t x = 0; x < sample_width; ++x) {
			const int64_t index = h3maped_cell_index(sample_width, sample_height, x, y, 0);
			if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == (uint32_t(7) << 16U)) {
				zone_word_cell_count += 1;
			}
			if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
				reserved_flag_cell_count += 1;
			}
		}
	}
	Dictionary line_sample;
	line_sample["map_width"] = sample_width;
	line_sample["map_height"] = sample_height;
	line_sample["from_x"] = 2;
	line_sample["from_y"] = 3;
	line_sample["to_x"] = 8;
	line_sample["to_y"] = 3;
	line_sample["level"] = 0;
	line_sample["zone_word_id"] = 7;
	line_sample["write_count"] = line.write_count;
	line_sample["unique_cell_count"] = line.unique_cell_count;
	line_sample["zone_word_cell_count"] = zone_word_cell_count;
	line_sample["reserved_flag_write_count"] = line.reserved_flag_write_count;
	line_sample["reserved_flag_cell_count"] = reserved_flag_cell_count;
	line_sample["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	line_sample["trace_preview"] = line.trace_preview;
	report["line_sample"] = line_sample;
	report["blocked_next"] = "assemble 0x4a2777 source-node traversal from these helpers and the recovered polygon-node inputs";
	return report;
}

Dictionary rectangle_fallback_4a2777_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2777_rectangle_fallback_branch_ported_standalone";
	report["source"] = "h3maped 0x4a2777 fallback branch at 0x4a2847..0x4a290c; paints right/top/left/bottom rectangle bounds through 0x4a261a and appends four runtime_zone+0x3f4 footprint vertices";
	report["function_address"] = "0x4a2777";
	report["address_range"] = "0x4a2847..0x4a290c";
	report["line_writer_address"] = "0x4a261a";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	report["uses_real_source_node_walk"] = false;
	report["materializes_project_grid"] = false;

	const int32_t sample_width = 12;
	const int32_t sample_height = 9;
	const int32_t level_count = 1;
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t min_x = 2;
	const int32_t min_y = 2;
	const int32_t max_x = 9;
	const int32_t max_y = 6;
	const int32_t zone_word_id = 5;
	std::vector<uint32_t> zone_words(size_t(sample_width * sample_height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(sample_width * sample_height * level_count), 0);
	Array edge_reports;
	int32_t total_write_count = 0;
	int32_t total_unique_write_count = 0;
	int32_t total_out_of_bounds_count = 0;
	auto append_edge = [&](const char *id, int32_t x1, int32_t y1, int32_t x2, int32_t y2) {
		LineWriteResult line = h3maped_line_writer_4a261a(zone_words, cell_flags, sample_width, sample_height, level_count, water_code, x1, y1, x2, y2, 0, zone_word_id);
		total_write_count += line.write_count;
		total_unique_write_count += line.unique_cell_count;
		total_out_of_bounds_count += line.out_of_bounds_write_count;
		Dictionary edge;
		edge["id"] = id;
		edge["from_x"] = x1;
		edge["from_y"] = y1;
		edge["to_x"] = x2;
		edge["to_y"] = y2;
		edge["write_count"] = line.write_count;
		edge["unique_write_count"] = line.unique_cell_count;
		edge["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
		edge_reports.append(edge);
	};
	append_edge("right", max_x, max_y, max_x, min_y);
	append_edge("top", min_x, max_y, max_x, max_y);
	append_edge("left", min_x, min_y, min_x, max_y);
	append_edge("bottom", max_x, min_y, min_x, min_y);

	int32_t unique_zone_word_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	for (int32_t y = 0; y < sample_height; ++y) {
		for (int32_t x = 0; x < sample_width; ++x) {
			const int64_t index = h3maped_cell_index(sample_width, sample_height, x, y, 0);
			if ((zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD) == (uint32_t(zone_word_id) << 16U)) {
				unique_zone_word_cell_count += 1;
			}
			if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
				reserved_flag_cell_count += 1;
			}
		}
	}
	Array vertices;
	auto append_vertex = [&](int32_t x, int32_t y) {
		Dictionary vertex;
		vertex["x"] = x;
		vertex["y"] = y;
		vertices.append(vertex);
	};
	append_vertex(max_x, max_y);
	append_vertex(max_x, min_y);
	append_vertex(min_x, min_y);
	append_vertex(min_x, max_y);

	Dictionary sample;
	sample["map_width"] = sample_width;
	sample["map_height"] = sample_height;
	sample["level_count"] = level_count;
	sample["min_x"] = min_x;
	sample["min_y"] = min_y;
	sample["max_x"] = max_x;
	sample["max_y"] = max_y;
	sample["zone_word_id"] = zone_word_id;
	sample["edge_call_count"] = edge_reports.size();
	sample["edge_write_count"] = total_write_count;
	sample["edge_unique_write_count"] = total_unique_write_count;
	sample["unique_zone_word_cell_count"] = unique_zone_word_cell_count;
	sample["reserved_flag_cell_count"] = reserved_flag_cell_count;
	sample["out_of_bounds_write_count"] = total_out_of_bounds_count;
	sample["edges"] = edge_reports;
	sample["footprint_vertex_count"] = vertices.size();
	sample["footprint_vertices"] = vertices;
	report["sample_contract"] = sample;
	report["blocked_next"] = "replace standalone rectangle fallback with full 0x4a2777 source-node traversal for real runtime zones";
	return report;
}

Dictionary connector_segment_4a2777_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2777_connector_segment_deterministic_branch_ported_standalone";
	report["source"] = "h3maped 0x4a2777 non-fallback branch at 0x4a2911..0x4a29f9 for the deterministic 0x4a261a dispatch path: clip both segment endpoints, append the first clipped endpoint to runtime_zone+0x3f4, then paint the connector segment";
	report["function_address"] = "0x4a2777";
	report["address_range"] = "0x4a2911..0x4a29f9";
	report["clip_helper_address"] = "0x4a2b33";
	report["line_writer_address"] = "0x4a261a";
	report["randomized_line_writer_address"] = "0x4a2413";
	report["randomized_line_writer_status"] = "0x4a2413_randomized_line_writer_ported_standalone_not_dispatched_here";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	report["uses_real_source_node_walk"] = false;
	report["materializes_project_grid"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	const int32_t from_x = -4;
	const int32_t from_y = 7;
	const int32_t to_x = width - 3;
	const int32_t to_y = height - 9;
	const int32_t zone_word_id = 6;
	ClipResult clipped_from = h3maped_clip_point_4a2b33(from_x, from_y, to_x, to_y, bounds);
	ClipResult clipped_to = h3maped_clip_point_4a2b33(to_x, to_y, from_x, from_y, bounds);
	std::vector<uint32_t> zone_words(size_t(width * height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(width * height * level_count), 0);
	LineWriteResult line = h3maped_line_writer_4a261a(zone_words, cell_flags, width, height, level_count, water_code, clipped_from.x, clipped_from.y, clipped_to.x, clipped_to.y, 0, zone_word_id);

	Dictionary input;
	input["from_x"] = from_x;
	input["from_y"] = from_y;
	input["to_x"] = to_x;
	input["to_y"] = to_y;
	report["sample_input"] = input;
	Dictionary clipped;
	clipped["from_x"] = clipped_from.x;
	clipped["from_y"] = clipped_from.y;
	clipped["from_branch"] = clipped_from.branch;
	clipped["to_x"] = clipped_to.x;
	clipped["to_y"] = clipped_to.y;
	clipped["to_branch"] = clipped_to.branch;
	report["sample_clipped_segment"] = clipped;
	Array vertices;
	Dictionary vertex;
	vertex["x"] = clipped_from.x;
	vertex["y"] = clipped_from.y;
	vertices.append(vertex);
	report["sample_appended_vertex_count"] = vertices.size();
	report["sample_appended_vertices"] = vertices;
	report["deterministic_write_count"] = line.write_count;
	report["deterministic_unique_cell_count"] = line.unique_cell_count;
	report["deterministic_reserved_flag_write_count"] = line.reserved_flag_write_count;
	report["deterministic_out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	report["deterministic_trace_preview"] = line.trace_preview;
	report["blocked_next"] = "wire this deterministic segment branch into the real 0x4a2777 source-node traversal and port 0x4a2413 for the flagged branch";
	return report;
}

Dictionary boundary_wrapping_continuation_4a2777_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2777_boundary_wrapping_continuation_ported_standalone";
	report["source"] = "h3maped 0x4a2777 continuation at 0x4a29f9..0x4a2b23; walks following source nodes, clips the next endpoint, wraps along rectangle borders through 0x4a2a5b..0x4a2af2, appends intermediate runtime_zone+0x3f4 vertices, and paints the final segment through 0x4a261a";
	report["function_address"] = "0x4a2777";
	report["continuation_address"] = "0x4a29f9..0x4a2b23";
	report["boundary_wrap_address"] = "0x4a2a5b..0x4a2af2";
	report["clip_helper_address"] = "0x4a2b33";
	report["line_writer_address"] = "0x4a261a";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	report["uses_real_source_node_walk"] = false;
	report["materializes_project_grid"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	const int32_t min_x = bounds.min_x;
	const int32_t min_y = bounds.min_y;
	const int32_t max_x = bounds.max_x;
	const int32_t max_y = bounds.max_y;
	const int32_t right_x = std::max<int32_t>(min_x, max_x - 1);
	const int32_t bottom_y = std::max<int32_t>(min_y, max_y - 1);
	const int32_t source_x = min_x - 6;
	const int32_t source_y = std::max<int32_t>(min_y, height / 2);
	const int32_t next_source_x = max_x + 6;
	const int32_t next_source_y = std::max<int32_t>(min_y, height - 7);
	const int32_t zone_word_id = 8;
	ClipResult clipped_current = h3maped_clip_point_4a2b33(source_x, source_y, next_source_x, next_source_y, bounds);
	ClipResult clipped_target = h3maped_clip_point_4a2b33(next_source_x, next_source_y, source_x, source_y, bounds);
	std::vector<uint32_t> zone_words(size_t(width * height * level_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(width * height * level_count), 0);
	Array segment_reports;
	Array vertices;
	int32_t total_write_count = 0;
	int32_t total_unique_write_count = 0;
	int32_t total_reserved_flag_write_count = 0;
	int32_t total_out_of_bounds_count = 0;
	int32_t wrap_segment_count = 0;
	int32_t final_segment_count = 0;
	auto append_vertex = [&](int32_t x, int32_t y) {
		Dictionary vertex;
		vertex["x"] = x;
		vertex["y"] = y;
		vertices.append(vertex);
	};
	auto append_segment = [&](const char *id, const char *branch, int32_t x1, int32_t y1, int32_t x2, int32_t y2, bool wrap_segment) {
		LineWriteResult line = h3maped_line_writer_4a261a(zone_words, cell_flags, width, height, level_count, water_code, x1, y1, x2, y2, 0, zone_word_id);
		total_write_count += line.write_count;
		total_unique_write_count += line.unique_cell_count;
		total_reserved_flag_write_count += line.reserved_flag_write_count;
		total_out_of_bounds_count += line.out_of_bounds_write_count;
		Dictionary segment;
		segment["id"] = id;
		segment["branch"] = branch;
		segment["from_x"] = x1;
		segment["from_y"] = y1;
		segment["to_x"] = x2;
		segment["to_y"] = y2;
		segment["write_count"] = line.write_count;
		segment["unique_write_count"] = line.unique_cell_count;
		segment["reserved_flag_write_count"] = line.reserved_flag_write_count;
		segment["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
		segment_reports.append(segment);
		append_vertex(x1, y1);
		if (wrap_segment) {
			wrap_segment_count += 1;
		} else {
			final_segment_count += 1;
		}
	};

	int32_t current_x = clipped_current.x;
	int32_t current_y = clipped_current.y;
	const int32_t target_x = clipped_target.x;
	const int32_t target_y = clipped_target.y;
	bool loop_guard_exhausted = false;
	for (int32_t guard = 0; guard < 8 && current_x != target_x && current_y != target_y; ++guard) {
		int32_t next_x = current_x;
		int32_t next_y = current_y;
		const char *branch = "0x4a2aa7_bottom_edge_to_min_x";
		if (current_x == min_x) {
			if (current_y == min_y) {
				next_x = right_x;
				next_y = min_y;
				branch = "0x4a2a91_top_edge_to_max_x_minus_one";
			} else {
				next_x = min_x;
				next_y = min_y;
				branch = "0x4a2a81_left_edge_to_min_y";
			}
		} else if (current_y == min_y) {
			next_x = right_x;
			next_y = min_y;
			branch = "0x4a2a89_top_edge_to_max_x_minus_one";
		} else if (current_x == right_x && current_y != bottom_y) {
			next_x = right_x;
			next_y = bottom_y;
			branch = "0x4a2a98_right_edge_to_max_y_minus_one";
		} else {
			next_x = min_x;
			next_y = bottom_y;
			branch = "0x4a2aa7_bottom_edge_to_min_x";
		}
		append_segment("wrap", branch, current_x, current_y, next_x, next_y, true);
		current_x = next_x;
		current_y = next_y;
		if (guard == 7 && current_x != target_x && current_y != target_y) {
			loop_guard_exhausted = true;
		}
	}
	if (current_x != target_x || current_y != target_y) {
		append_segment("final", "0x4a2af2_final_segment_to_clipped_endpoint", current_x, current_y, target_x, target_y, false);
	}

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

	Dictionary input;
	input["source_x"] = source_x;
	input["source_y"] = source_y;
	input["next_source_x"] = next_source_x;
	input["next_source_y"] = next_source_y;
	report["sample_input"] = input;
	Dictionary clipped;
	clipped["current_x"] = clipped_current.x;
	clipped["current_y"] = clipped_current.y;
	clipped["current_branch"] = clipped_current.branch;
	clipped["target_x"] = clipped_target.x;
	clipped["target_y"] = clipped_target.y;
	clipped["target_branch"] = clipped_target.branch;
	report["sample_clipped_continuation"] = clipped;
	report["wrap_segment_count"] = wrap_segment_count;
	report["final_segment_count"] = final_segment_count;
	report["segments"] = segment_reports;
	report["sample_appended_vertex_count"] = vertices.size();
	report["sample_appended_vertices"] = vertices;
	report["write_count"] = total_write_count;
	report["unique_write_count"] = total_unique_write_count;
	report["zone_word_cell_count"] = zone_word_cell_count;
	report["reserved_flag_write_count"] = total_reserved_flag_write_count;
	report["reserved_flag_cell_count"] = reserved_flag_cell_count;
	report["out_of_bounds_write_count"] = total_out_of_bounds_count;
	report["loop_guard_exhausted"] = loop_guard_exhausted;
	report["blocked_next"] = "replace this deterministic sample with the real 0x4a2777 source-node walk from runtime zone source-zone list payloads";
	return report;
}

Dictionary randomized_line_writer_4a2413_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a2413_randomized_line_writer_ported_standalone";
	report["source"] = "h3maped 0x4a2413 flagged branch writer; recursively subdivides a segment, jitters midpoint candidates with 0x4e7276, clamps terminal writes to map bounds, and writes zone words like 0x4a261a";
	report["function_address"] = "0x4a2413";
	report["rng_address"] = "0x4e7276";
	report["distance_helper_address"] = "0x4cc5ad";
	report["map_cell_stride_bytes"] = 0x30;
	report["uses_real_source_node_walk"] = false;
	report["materializes_project_grid"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
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
	sample["from_x"] = 2;
	sample["from_y"] = 2;
	sample["to_x"] = width - 3;
	sample["to_y"] = height - 5;
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

Dictionary runtime_zone_record_setup_report(const Dictionary &normalized_config, const Dictionary &template_record, const Dictionary &assignment, int32_t human_count, int32_t player_count, uint32_t rng_state_after_template_selection) {
	Dictionary report;
	report["status"] = "0x4a218c_runtime_zone_record_setup_and_0x4a17f5_coordinate_replay_ported";
	report["source"] = "h3maped 0x4a218c consumes 0x4ac62a generator+0xee4 owner-color mapping, schedules 0x4a1f3b endpoint placement, and replays 0x4a17f5/0x4a1701 coordinate candidates before terrain, footprint, and object materialization";
	report["runtime_zone_vector_source"] = "selected adapted-template active zones";
	report["owner_color_mapping_source"] = "generator+0xee4";
	report["materializes_runtime_zone_coordinates"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	if (template_record.is_empty()) {
		report["status"] = "0x4a218c_runtime_zone_record_setup_template_missing";
		report["runtime_zone_records"] = Array();
		report["runtime_zone_count"] = 0;
		return report;
	}

	Array colors_by_source_owner = assignment.get("actual_colors_by_source_owner", Array());
	Array records;
	Array owner_colors;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	Array zones = template_record.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = zones[index];
		if (!player_filter_accepts(zone.get("player_filter", Dictionary()), human_count, player_count)) {
			continue;
		}
		Dictionary ownership = zone.get("ownership", Dictionary());
		Dictionary grammar_source = zone.get("grammar_source", Dictionary());
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Dictionary terrain = zone.get("terrain", Dictionary());
		const int32_t source_owner_index = int32_t(ownership.get("source_owner_index", -1));
		const int32_t actual_owner_color = owner_color_for_source_owner(colors_by_source_owner, source_owner_index);
		const String role = String(zone.get("role", zone.get("type", "")));
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
		record["source_zone_key"] = zone.get("id", "");
		record["role"] = role;
		record["source_owner_index"] = source_owner_index;
		record["actual_owner_color"] = actual_owner_color;
		record["source_row"] = grammar_source.get("source_row", -1);
		record["source_bucket"] = grammar_source.get("source_bucket", -1);
		record["source_base_size"] = zone.get("base_size", 0);
		record["allowed_faction_ids_for_49b3c1"] = town_policy.get("allowed_faction_ids", Array());
		record["terrain_match_to_faction"] = bool(terrain.get("match_to_faction", false));
		record["allowed_terrain_ids_for_49b53d"] = terrain.get("allowed", Array());
		record["terrain_source_mask_count"] = terrain.get("source_mask_count", 0);
		record["minimum_player_castles"] = min_castles;
		record["coordinate_status"] = "inspection_0x4a17f5_0x4a1701_replay_available";
		record["terrain_status"] = "pending_0x49b53d";
		record["footprint_status"] = "pending_0x4a3a03";
		records.append(record);
		owner_colors.append(actual_owner_color);
	}

	report["runtime_zone_count"] = records.size();
	report["assigned_start_zone_count"] = assigned_start_zone_count;
	report["unassigned_start_zone_count"] = unassigned_start_zone_count;
	report["treasure_zone_count"] = treasure_zone_count;
	report["minimum_player_castles"] = minimum_player_castles;
	report["actual_owner_colors_by_runtime_zone"] = owner_colors;
	report["runtime_zone_records"] = records;
	Dictionary endpoint_schedule = early_link_placement_schedule_report(template_record, records, human_count, player_count);
	report["early_link_placement_status"] = endpoint_schedule.get("status", "");
	report["early_link_placement"] = endpoint_schedule;
	Dictionary coordinate_replay = coordinate_candidate_replay_report(normalized_config, records, endpoint_schedule.get("link_seeds", Array()), rng_state_after_template_selection);
	report["coordinate_replay_status"] = coordinate_replay.get("status", "");
	report["coordinate_replay"] = coordinate_replay;
	Dictionary terrain_selection = runtime_terrain_selection_report(records, coordinate_replay);
	report["terrain_selection_status"] = terrain_selection.get("status", "");
	report["terrain_selection"] = terrain_selection;
	Dictionary footprint_schedule = zone_footprint_schedule_report(normalized_config, records, coordinate_replay, terrain_selection);
	Dictionary finalizer = footprint_finalizer_4a3710_report(normalized_config, records, int32_t(footprint_schedule.get("total_matching_runtime_zones", 0)));
	footprint_schedule["finalizer_status"] = finalizer.get("status", "");
	footprint_schedule["finalizer"] = finalizer;
	Dictionary span_fill = span_fill_primitive_4a325d_report(normalized_config);
	footprint_schedule["span_fill_primitive_status"] = span_fill.get("status", "");
	footprint_schedule["span_fill_primitive"] = span_fill;
	Dictionary boundary_helpers = boundary_helper_primitives_report(normalized_config);
	footprint_schedule["boundary_helper_primitives_status"] = boundary_helpers.get("status", "");
	footprint_schedule["boundary_helper_primitives"] = boundary_helpers;
	Dictionary rectangle_fallback = rectangle_fallback_4a2777_report(normalized_config);
	footprint_schedule["rectangle_fallback_status"] = rectangle_fallback.get("status", "");
	footprint_schedule["rectangle_fallback"] = rectangle_fallback;
	Dictionary connector_segment = connector_segment_4a2777_report(normalized_config);
	footprint_schedule["connector_segment_status"] = connector_segment.get("status", "");
	footprint_schedule["connector_segment"] = connector_segment;
	Dictionary boundary_wrapping = boundary_wrapping_continuation_4a2777_report(normalized_config);
	footprint_schedule["boundary_wrapping_status"] = boundary_wrapping.get("status", "");
	footprint_schedule["boundary_wrapping"] = boundary_wrapping;
	Dictionary randomized_line_writer = randomized_line_writer_4a2413_report(normalized_config);
	footprint_schedule["randomized_line_writer_status"] = randomized_line_writer.get("status", "");
	footprint_schedule["randomized_line_writer"] = randomized_line_writer;
	footprint_schedule["next_materialization_status"] = "pending_TerrainPlacement_art_index_flip_and_project_grid_adoption";
	report["zone_footprint_schedule_status"] = footprint_schedule.get("status", "");
	report["zone_footprint_schedule"] = footprint_schedule;
	return report;
}

Dictionary selected_template_payload(const Dictionary &selected_template, const TemplateEvidence &candidate, const Dictionary &normalized_config, int32_t human_count, int32_t computer_count, uint32_t rng_state_after_template_selection) {
	Dictionary template_record = adapted_template_for_id(String(candidate.adapted_template_id));
	Dictionary profile_record = adapted_profile_for_template_id(String(candidate.adapted_template_id));
	Dictionary import_provenance = template_record.get("import_provenance", Dictionary());
	const bool adapted_template_loaded = !template_record.is_empty();
	const bool adapted_profile_loaded = !profile_record.is_empty();
	const int32_t adapted_source_index_one_based = int32_t(import_provenance.get("source_template_index", -1));
	const int32_t expected_source_index_one_based = candidate.catalog_index + 1;
	const int32_t adapted_source_index_zero_based = adapted_source_index_one_based > 0 ? adapted_source_index_one_based - 1 : -1;
	const bool import_index_matches = adapted_template_loaded
			&& adapted_source_index_one_based == expected_source_index_one_based;
	Dictionary payload;
	payload["source"] = "adapted project catalog resolved by import_provenance.source_template_index";
	payload["source_catalog_index_zero_based"] = selected_template.get("source_catalog_index", candidate.catalog_index);
	payload["imported_source_template_index_one_based"] = expected_source_index_one_based;
	payload["status"] = (adapted_template_loaded && adapted_profile_loaded && import_index_matches) ? String("adapted_project_catalog_contract_verified") : String("adapted_project_catalog_contract_failed");
	payload["adapted_template_id"] = candidate.adapted_template_id;
	payload["adapted_template_loaded"] = adapted_template_loaded;
	payload["adapted_profile_loaded"] = adapted_profile_loaded;
	payload["adapted_profile_id"] = profile_record.get("id", "");
	payload["adapted_profile_template_id"] = profile_record.get("template_id", "");
	payload["adapted_import_source_template_index_one_based"] = adapted_source_index_one_based;
	payload["expected_import_source_template_index_one_based"] = expected_source_index_one_based;
	payload["adapted_import_source_template_index_zero_based"] = adapted_source_index_zero_based;
	payload["expected_import_source_template_index_zero_based"] = candidate.catalog_index;
	payload["adapted_import_source_index_matches"] = import_index_matches;
	payload["adapted_catalog_contract"] = (adapted_template_loaded && adapted_profile_loaded && import_index_matches)
			? String("project_template_and_profile_resolved_from_recovered_source_index")
			: String("missing_or_mismatched_project_template_profile_bridge");
	payload["zone_count"] = selected_template.get("zone_count", candidate.zone_count);
	payload["link_count"] = selected_template.get("connection_count", candidate.connection_count);
	payload["player_start_zone_count"] = candidate.player_start_zone_count;
	payload["treasure_zone_count"] = candidate.treasure_zone_count;
	payload["minimum_player_castles_before_assignment"] = candidate.minimum_player_castles;
	payload["human_capable_source_owner_indices"] = source_owner_indices_from_mask(candidate.human_capable_source_owner_mask);
	payload["player_capable_source_owner_indices"] = source_owner_indices_from_mask(candidate.player_capable_source_owner_mask);
	Dictionary assignment = player_slot_assignment_report(candidate.human_capable_source_owner_mask, candidate.player_capable_source_owner_mask, selected_color_bitmap_from_normalized(normalized_config), human_count, computer_count);
	payload["assignment_status"] = assignment.get("status", "");
	payload["player_slot_assignment"] = assignment;
	Dictionary runtime_zones = runtime_zone_record_setup_report(normalized_config, template_record, assignment, human_count, human_count + computer_count, rng_state_after_template_selection);
	payload["runtime_zone_build_status"] = runtime_zones.get("status", "");
	payload["runtime_zone_build"] = runtime_zones;
	payload["materialization_status"] = "blocked_until_TerrainPlacement_art_index_flip_and_project_grid_adoption";
	payload["runtime_generation_allowed"] = false;
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
		{ "template_selection", "0x49f0cd, 0x4ac597..0x4ac5a4, 0x4e7276", "active_clean_port" },
		{ "player_slot_assignment", "0x4ac62a..0x4ac6ec", "active_clean_port" },
		{ "runtime_zone_build", "0x4a218c, 0x4a1f3b, 0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed, 0x49b53d", "active_record_setup_coordinate_replay_and_terrain_selection_only" },
		{ "zone_footprint_placement", "0x4a3a03, 0x4a2413, 0x4a2b33, 0x4a261a, 0x4a2777, 0x4a325d, 0x4a3710", "active_schedule_boundary_helpers_4a2777_standalone_branches_and_boundary_wrap_span_primitive_and_small_land_finalizer_only" },
		{ "town_and_object_placement", "0x4a8d2c, 0x4a93a2, 0x49aa93", "pending" },
		{ "roads", "0x4ab52a, 0x4aae7b, 0x4ab37f, 0x4b4243", "pending" },
		{ "connection_guards_blockers", "0x4a79a3, 0x4a61bc, 0x4a696b, 0x4a7605", "pending" },
		{ "final_writeout", "0x49b2b6", "pending" },
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

Array accepted_templates_for_config(const Dictionary &normalized_config, int32_t score, int32_t human_count, int32_t player_count) {
	Array accepted_templates;
	if (!supports_scope(normalized_config)) {
		return accepted_templates;
	}
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

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t score = size_score(normalized_config);
	const bool supported = supports_scope(normalized_config);
	Array accepted_templates = accepted_templates_for_config(normalized_config, score, human_count, player_count);

	Dictionary result;
	result["ok"] = false;
	result["schema_id"] = "aurelion_native_rmg_small_h3maped_selection_identity_v1";
	result["schema_version"] = 1;
	result["scope"] = "small_36x36_surface_land_only";
	result["supported_scope"] = supported;
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["template_loader_address"] = "0x49f0cd";
	result["rng_function_address"] = "0x4e7276";
	result["accepted_template_count"] = accepted_templates.size();
	result["requested_template_id_ignored"] = String(normalized_config.get("template_id", ""));
	result["explicit_template_requests_bypass_reset"] = false;
	if (!supported) {
		result["status"] = "unsupported_scope";
		return result;
	}
	if (accepted_templates.is_empty()) {
		result["status"] = "h3maped_small_no_accepted_templates";
		return result;
	}

	uint32_t seed_value = 0;
	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	if (!parse_explicit_seed(seed_text, seed_value)) {
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["blocked_reason"] = "h3maped seed must be numeric; no replacement hash is allowed";
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
	const bool supported = supports_scope(normalized_config);
	Array accepted_templates = accepted_templates_for_config(normalized_config, score, human_count, player_count);
	const TemplateEvidence *selected_candidate = nullptr;
	Dictionary identity = selection_identity(normalized_config);
	if (bool(identity.get("ok", false))) {
		const int32_t source_catalog_index = int32_t(identity.get("source_catalog_index", -1));
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (candidate.catalog_index == source_catalog_index) {
				selected_candidate = &candidate;
				break;
			}
		}
	}

	Dictionary report;
	report["ok"] = supported && !accepted_templates.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_clean_restart_v2";
	report["schema_version"] = 2;
	report["status"] = supported ? (accepted_templates.is_empty() ? String("h3maped_small_no_accepted_templates") : String("h3maped_small_clean_restart_template_selection_ready")) : String("unsupported_scope");
	report["scope"] = "small_36x36_surface_land_only";
	report["archive_status"] = "previous_native_catalog_auto_generator_archived_debug_only";
	report["legacy_inspection_ledger_path"] = LEGACY_LEDGER_PATH;
	report["implementation_policy"] = "strict_h3maped_exe_port_no_hash_selection_no_sample_count_fitting_no_fallback_maps";
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
	report["selection_identity"] = identity;
	report["phase_ledger"] = clean_phase_ledger();
	report["generation_phase_status"] = "blocked_until_clean_h3maped_phase_ports_materialize_map_cells";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["partial_materialized_payload_status"] = "archived_inspection_blocked_not_exported";
	report["normalized_config"] = normalized_config;

	uint32_t seed_value = 0;
	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	if (supported && !accepted_templates.is_empty() && parse_explicit_seed(seed_text, seed_value)) {
		const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
		const int32_t rng_value = int32_t((next_state >> 16U) & 0x7fffu);
		const int32_t selected_index = rng_value % int32_t(accepted_templates.size());
		Dictionary selected_template = accepted_templates[selected_index];
		const int32_t source_catalog_index = int32_t(selected_template.get("source_catalog_index", -1));
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (candidate.catalog_index == source_catalog_index) {
				selected_candidate = &candidate;
				break;
			}
		}

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
		if (selected_candidate != nullptr) {
			report["selected_template_payload"] = selected_template_payload(selected_template, *selected_candidate, normalized_config, human_count, computer_count, next_state);
		}
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
	result["message"] = "The previous native RMG implementation is archived as debug-only evidence. Production RMG work must use the small h3maped-derived port; out-of-scope map sizes and modes do not emit fallback maps.";
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["native_rmg_archive_status"] = "archived_legacy_native_rmg_debug_only";
	result["legacy_inspection_ledger_path"] = LEGACY_LEDGER_PATH;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["h3maped_binary_path"] = BINARY_PATH;
	result["h3maped_binary_sha256"] = BINARY_SHA256;
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
