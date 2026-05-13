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
#include <map>
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

struct LineCellWrite {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t zone_id = 0;
	bool reserved = false;
};

struct LineWriteResult {
	std::vector<LineCellWrite> trace;
	int32_t write_count = 0;
	int32_t unique_cell_count = 0;
	int32_t out_of_bounds_write_count = 0;
	int32_t reserved_flag_write_count = 0;
	Array trace_preview;
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

struct PolygonPoint {
	int32_t x = 0;
	int32_t y = 0;
};

struct H3MapedPolygonModelNode {
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

struct H3MapedPolygonModel {
	std::vector<H3MapedPolygonModelNode> nodes;
	int32_t root = -1;

	int32_t add_pair(const String &prefix, int32_t from_x, int32_t from_y, int32_t from_payload, int32_t to_x, int32_t to_y, int32_t to_payload, bool from_has_payload = false, bool to_has_payload = false) {
		const int32_t primary_index = int32_t(nodes.size());
		const int32_t paired_index = primary_index + 1;
		H3MapedPolygonModelNode primary;
		primary.id = prefix + String("_primary");
		primary.x = from_x;
		primary.y = from_y;
		primary.payload = from_payload;
		primary.has_payload = from_has_payload;
		primary.pair = paired_index;
		primary.next = primary_index;
		primary.previous = primary_index;
		H3MapedPolygonModelNode paired;
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

	void erase_edge_4cc9cc(int32_t node_index) {
		edge_swap_4cc670(node_index);
		const int32_t paired = nodes[size_t(node_index)].pair;
		nodes[size_t(node_index)].active = false;
		nodes[size_t(paired)].active = false;
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
		const H3MapedPolygonModelNode &old_pair = nodes[size_t(nodes[size_t(old_node)].pair)];
		const H3MapedPolygonModelNode &target = nodes[size_t(target_node)];
		const int32_t bridge_primary = add_pair(prefix, old_pair.x, old_pair.y, old_pair.payload, target.x, target.y, target.payload, old_pair.has_payload, target.has_payload);
		relink_4cc643(bridge_primary, nodes[size_t(nodes[size_t(old_node)].pair)].previous);
		relink_4cc643(nodes[size_t(bridge_primary)].pair, target_node);
		return bridge_primary;
	}

	int64_t side_4cca55(int32_t from_node, int32_t to_node, int32_t x, int32_t y) const {
		const H3MapedPolygonModelNode &from = nodes[size_t(from_node)];
		const H3MapedPolygonModelNode &to = nodes[size_t(to_node)];
		return int64_t(to.y - from.y) * int64_t(x - from.x) - int64_t(to.x - from.x) * int64_t(y - from.y);
	}

	int32_t locate_4cca55(int32_t x, int32_t y) const {
		int32_t current = root;
		for (int32_t guard = 0; guard < 512; ++guard) {
			const H3MapedPolygonModelNode &current_node = nodes[size_t(current)];
			if (current_node.x == x && current_node.y == y) {
				return current;
			}
			const int32_t paired = current_node.pair;
			const H3MapedPolygonModelNode &paired_node = nodes[size_t(paired)];
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
		const H3MapedPolygonModelNode &node = nodes[size_t(node_index)];
		const H3MapedPolygonModelNode &paired = nodes[size_t(node.pair)];
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
		const H3MapedPolygonModelNode &node = nodes[size_t(node_index)];
		const H3MapedPolygonModelNode &paired = nodes[size_t(node.pair)];
		const H3MapedPolygonModelNode &previous_pair = nodes[size_t(nodes[size_t(node.previous)].pair)];
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
		return PolygonPoint{
			x1 + half_truncate_4ccd69(int64_t(x2 - x1) + x_adjust),
			y1 + half_truncate_4ccd69(int64_t(y2 - y1) + y_adjust),
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
			H3MapedPolygonModelNode &node = nodes[size_t(index)];
			if (!node.active || !node.has_payload || node.finalized) {
				continue;
			}
			const int32_t next_pair = nodes[size_t(node.next)].pair;
			const H3MapedPolygonModelNode &paired = nodes[size_t(node.pair)];
			const H3MapedPolygonModelNode &next_pair_node = nodes[size_t(next_pair)];
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

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
};

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD = 0x00ff0000U;
constexpr uint32_t H3MAPED_ZONE_WORD_CLEAR_MASK = 0xff00ffffU;

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
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

int64_t h3maped_cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (int64_t(level) * int64_t(height) + int64_t(y)) * int64_t(width) + int64_t(x);
}

bool h3maped_cell_unassigned(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (zone_words[size_t(h3maped_cell_index(width, height, x, y, level))] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD;
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
	LineCellWrite write;
	write.x = x;
	write.y = y;
	write.level = level;
	write.zone_id = zone_word_id & 0xff;
	write.reserved = !(water_code == 2 && level != 1);
	result.trace.push_back(write);
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

void append_span_fill_preview_4a325d(Array &trace_preview, int32_t x, int32_t y, int32_t level) {
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
		if (!h3maped_cell_unassigned(zone_words, width, height, span.x, span.y, span.level)) {
			result.blocked_initial_span_count += 1;
		}
		int32_t x = span.x;
		while (x > 0 && h3maped_cell_unassigned(zone_words, width, height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		bool upper_run_open = false;
		bool lower_run_open = false;
		SpanRecord upper_span;
		SpanRecord lower_span;
		for (; x < width && h3maped_cell_unassigned(zone_words, width, height, x, span.y, span.level); ++x) {
			const int64_t index = h3maped_cell_index(width, height, x, span.y, span.level);
			zone_words[size_t(index)] = (zone_words[size_t(index)] & H3MAPED_ZONE_WORD_CLEAR_MASK) | (uint32_t(zone_word_id & 0xff) << 16U);
			if (!(water_code == 2 && span.level != 1)) {
				cell_flags[size_t(index)] = uint8_t(cell_flags[size_t(index)] | 0x10U);
			}
			result.filled_cell_count += 1;
			append_span_fill_preview_4a325d(result.trace_preview, x, span.y, span.level);

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
	}
	return result;
}

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

Dictionary polygon_split_model_context(const Dictionary &normalized_config, const Dictionary &coordinate_context, const Dictionary &source_node_rectangle) {
	Dictionary context;
	context["phase_id"] = "polygon_split_model";
	context["h3maped_anchor"] = "0x4ccb64";
	context["locator_anchor"] = "0x4cca55";
	context["splitter_anchor"] = "0x4ccb64";
	context["node_constructor_anchor"] = "0x4cc955";
	context["node_relink_anchor"] = "0x4cc643";
	context["edge_side_test_anchor"] = "0x4cc6f2";
	context["edge_erase_anchor"] = "0x4cc9cc";
	context["bridge_anchor"] = "0x4ccb1f";
	context["crossing_test_anchor"] = "0x4ccc7a";
	context["crossing_collapse_anchor"] = "0x4cc68e";
	context["intersection_writer_anchor"] = "0x4ccd69";
	context["finalizer_anchor"] = "0x4ccdfc";
	context["status"] = "blocked_until_source_node_rectangle";
	context["materializes_source_node_graph"] = true;
	context["materializes_boundaries"] = false;
	context["materializes_span_fill"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_public_output"] = false;
	context["feeds_real_0x4a2777_boundary"] = false;
	context["blocked_next"] = "source_node_cycles_to_0x4a2777_boundary_traversal";
	if (String(source_node_rectangle.get("status", "")) != "private_context_ready") {
		return context;
	}
	if (int32_t(normalized_config.get("level_count", 1)) != 1) {
		context["status"] = "unsupported_until_two_level_polygon_split_model_ported";
		return context;
	}

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_context.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled.size(); ++index) {
		Dictionary item = scaled[index];
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(item.get("runtime_zone_index", index));
		zone.x = int32_t(item.get("x_after_bbox_rescale", 0));
		zone.y = int32_t(item.get("y_after_bbox_rescale", 0));
		zone.level = int32_t(item.get("level", 0));
		zones.push_back(zone);
	}

	H3MapedPolygonModel model;
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

	Array split_steps;
	int32_t executed_split_count = 0;
	int32_t skipped_duplicate_count = 0;
	int32_t edge_removal_count = 0;
	int32_t inserted_node_pair_count = 0;
	int32_t inserted_bridge_pair_count = 0;
	int32_t crossing_scan_count = 0;
	int32_t crossing_test_count = 0;
	int32_t crossing_collapse_count = 0;
	bool blocked = false;
	for (const RuntimeZoneSeed &zone : zones) {
		if (zone.level != 0) {
			continue;
		}
		Dictionary step;
		step["runtime_zone_index"] = zone.runtime_index;
		step["x"] = zone.x;
		step["y"] = zone.y;
		int32_t located = model.locate_4cca55(zone.x, zone.y);
		if (located < 0) {
			step["status"] = "0x4cca55_locator_guard_failed";
			blocked = true;
			split_steps.append(step);
			break;
		}
		step["located_node_id"] = model.nodes[size_t(located)].id;
		step["located_pair_id"] = model.nodes[size_t(model.nodes[size_t(located)].pair)].id;
		if ((model.nodes[size_t(located)].x == zone.x && model.nodes[size_t(located)].y == zone.y)
				|| (model.nodes[size_t(model.nodes[size_t(located)].pair)].x == zone.x && model.nodes[size_t(model.nodes[size_t(located)].pair)].y == zone.y)) {
			step["status"] = "0x4ccb64_duplicate_point_skipped";
			skipped_duplicate_count += 1;
			split_steps.append(step);
			continue;
		}
		if (model.edge_side_test_4cc6f2(located, zone.x, zone.y)) {
			step["edge_removal_branch"] = true;
			located = model.nodes[size_t(located)].previous;
			const int32_t erased = model.nodes[size_t(located)].next;
			step["edge_removal_status"] = "0x4cc9cc_vector_erase_branch_ported";
			step["edge_removed_node_id"] = model.nodes[size_t(erased)].id;
			model.erase_edge_4cc9cc(erased);
			edge_removal_count += 1;
		} else {
			step["edge_removal_branch"] = false;
		}
		const H3MapedPolygonModelNode &located_node = model.nodes[size_t(located)];
		const int32_t split_primary = model.add_pair(String("split_") + String::num_int64(zone.runtime_index), located_node.x, located_node.y, located_node.payload, zone.x, zone.y, zone.runtime_index, located_node.has_payload, true);
		model.relink_4cc643(split_primary, located);
		model.root = split_primary;
		inserted_node_pair_count += 1;
		executed_split_count += 1;
		step["inserted_primary_node_id"] = model.nodes[size_t(split_primary)].id;
		step["inserted_paired_node_id"] = model.nodes[size_t(model.nodes[size_t(split_primary)].pair)].id;
		int32_t bridge_pair_count = 0;
		int32_t current_bridge = split_primary;
		int32_t bridge_source = located;
		for (int32_t guard = 0; guard < 64; ++guard) {
			current_bridge = model.bridge_4ccb1f(bridge_source, model.nodes[size_t(current_bridge)].pair, String("split_") + String::num_int64(zone.runtime_index) + "_bridge_" + String::num_int64(bridge_pair_count));
			bridge_pair_count += 1;
			inserted_bridge_pair_count += 1;
			bridge_source = model.nodes[size_t(current_bridge)].previous;
			const int32_t bridge_source_pair = model.nodes[size_t(bridge_source)].pair;
			if (model.nodes[size_t(bridge_source_pair)].previous == model.root) {
				break;
			}
			if (guard == 63) {
				step["status"] = "0x4ccb64_bridge_loop_guard_failed";
				blocked = true;
			}
		}
		step["bridge_pair_count"] = bridge_pair_count;
		step["allocated_node_pair_count_after_pre_crossing"] = int32_t(model.nodes.size() / 2);
		step["active_node_pair_count_after_pre_crossing"] = model.active_node_pair_count();
		int32_t cleanup_scan_count = 0;
		int32_t cleanup_test_count = 0;
		int32_t cleanup_collapse_count = 0;
		int32_t cleanup_cursor = bridge_source;
		for (int32_t guard = 0; guard < 256; ++guard) {
			cleanup_scan_count += 1;
			crossing_scan_count += 1;
			if (model.crossing_orientation_gate_4ccb64(cleanup_cursor)) {
				const H3MapedPolygonModelNode &cursor = model.nodes[size_t(cleanup_cursor)];
				const H3MapedPolygonModelNode &previous_pair = model.nodes[size_t(model.nodes[size_t(cursor.previous)].pair)];
				const H3MapedPolygonModelNode &paired = model.nodes[size_t(cursor.pair)];
				cleanup_test_count += 1;
				crossing_test_count += 1;
				if (model.crossing_test_4ccc7a(cursor.x, cursor.y, previous_pair.x, previous_pair.y, paired.x, paired.y, zone.x, zone.y)) {
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
				step["status"] = "0x4ccb64_crossing_cleanup_guard_failed";
				blocked = true;
			}
		}
		step["crossing_cleanup_scan_count"] = cleanup_scan_count;
		step["crossing_test_count"] = cleanup_test_count;
		step["crossing_collapse_count"] = cleanup_collapse_count;
		step["allocated_node_pair_count_after_crossing_cleanup"] = int32_t(model.nodes.size() / 2);
		step["active_node_pair_count_after_crossing_cleanup"] = model.active_node_pair_count();
		step["status"] = blocked ? String("0x4ccb64_bridge_loop_guard_failed") : String("0x4ccb64_pre_crossing_inserted");
		split_steps.append(step);
		if (blocked) {
			break;
		}
	}

	Array finalized_steps;
	const int32_t finalized_triplet_count = blocked ? 0 : model.finalize_4ccdfc(&finalized_steps);
	int32_t finalized_node_count = 0;
	int32_t active_payload_node_count = 0;
	for (const H3MapedPolygonModelNode &node : model.nodes) {
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

	Array source_node_walks;
	int32_t source_node_walk_count = 0;
	int32_t source_node_walk_guard_exhausted_count = 0;
	for (const RuntimeZoneSeed &zone : zones) {
		if (zone.level != 0) {
			continue;
		}
		Dictionary walk;
		walk["runtime_zone_index"] = zone.runtime_index;
		walk["locator_anchor"] = "0x4cca55";
		walk["consumer_anchor"] = "0x4a2777";
		walk["start_x"] = zone.x;
		walk["start_y"] = zone.y;
		const int32_t located = blocked ? -1 : model.locate_4cca55(zone.x, zone.y);
		walk["located_node_id"] = located >= 0 ? model.nodes[size_t(located)].id : String();
		Array cycle_nodes;
		bool guard_exhausted = false;
		int32_t finalized_coordinate_count = 0;
		if (located >= 0) {
			int32_t current = located;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const H3MapedPolygonModelNode &node = model.nodes[size_t(current)];
				Dictionary node_report;
				node_report["node_id"] = node.id;
				node_report["+0x00_x"] = node.x;
				node_report["+0x04_y"] = node.y;
				node_report["+0x08_payload"] = node.payload;
				node_report["has_payload"] = node.has_payload;
				node_report["+0x10_next"] = node.next >= 0 ? model.nodes[size_t(node.next)].id : String();
				node_report["+0x14_previous"] = node.previous >= 0 ? model.nodes[size_t(node.previous)].id : String();
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
		walk["cycle_node_count"] = cycle_nodes.size();
		walk["finalized_coordinate_count"] = finalized_coordinate_count;
		walk["guard_exhausted"] = guard_exhausted;
		walk["cycle_nodes"] = cycle_nodes;
		source_node_walks.append(walk);
		source_node_walk_count += 1;
	}

	context["status"] = blocked ? String("blocked_during_polygon_split_model") : String("private_context_ready");
	context["source"] = "h3maped 0x4ccb64 insertion/bridge/crossing-cleanup loop and 0x4ccdfc source-node finalizer over 0x4a19ed scaled runtime-zone coordinates";
	context["split_steps"] = split_steps;
	context["runtime_split_point_count"] = int32_t(zones.size());
	context["executed_split_call_count"] = executed_split_count;
	context["duplicate_skip_count"] = skipped_duplicate_count;
	context["edge_removal_branch_count"] = edge_removal_count;
	context["pre_crossing_inserted_node_pair_count"] = inserted_node_pair_count;
	context["pre_crossing_inserted_bridge_pair_count"] = inserted_bridge_pair_count;
	context["crossing_cleanup_scan_count"] = crossing_scan_count;
	context["crossing_test_count"] = crossing_test_count;
	context["crossing_collapse_count"] = crossing_collapse_count;
	context["initial_node_pair_count"] = 5;
	context["post_crossing_cleanup_allocated_node_pair_count"] = int32_t(model.nodes.size() / 2);
	context["post_crossing_cleanup_allocated_node_count"] = int32_t(model.nodes.size());
	context["post_crossing_cleanup_active_node_pair_count"] = model.active_node_pair_count();
	context["post_crossing_cleanup_active_node_count"] = model.active_node_pair_count() * 2;
	context["root_node_id_after_crossing_cleanup"] = model.root >= 0 ? model.nodes[size_t(model.root)].id : String();
	context["crossing_cleanup_status"] = blocked ? String("blocked_during_crossing_cleanup") : String("0x4ccc7a_0x4cc68e_crossing_cleanup_ported");
	context["finalizer_status"] = blocked ? String("blocked_before_0x4ccdfc") : String("0x4ccdfc_finalized_node_fanout_ported");
	context["finalized_triplet_count"] = finalized_triplet_count;
	context["finalized_node_count"] = finalized_node_count;
	context["active_payload_node_count"] = active_payload_node_count;
	context["finalized_steps"] = finalized_steps;
	context["source_node_walk_status"] = blocked ? String("blocked_before_0x4cca55_source_node_walk") : String("0x4cca55_to_0x4a2777_source_node_cycles_recovered_private_only");
	context["source_node_walk_count"] = source_node_walk_count;
	context["source_node_walk_guard_exhausted_count"] = source_node_walk_guard_exhausted_count;
	context["source_node_walks"] = source_node_walks;
	context["blocked_next"] = "feed_finalized_0x4ccdfc_source_node_cycles_into_real_0x4a2777_traversal";
	return context;
}

bool h3maped_point_inside_bounds_4a2777(const ClipResult &point, const ClipBounds &bounds) {
	return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
}

void merge_line_write_result_4a2777(const LineWriteResult &line, std::map<int64_t, bool> &unique_cells, int32_t &trace_write_count, int32_t &out_of_bounds_write_count, int32_t width, int32_t height) {
	for (const LineCellWrite &write : line.trace) {
		const int64_t key = (int64_t(write.level) * int64_t(height) + int64_t(write.y)) * int64_t(width) + int64_t(write.x);
		unique_cells[key] = true;
	}
	trace_write_count += int32_t(line.trace.size());
	out_of_bounds_write_count += line.out_of_bounds_write_count;
}

Dictionary segment_report_4a2777(const String &id, const String &branch, const String &writer, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y, const LineWriteResult &line) {
	Dictionary segment;
	segment["id"] = id;
	segment["branch"] = branch;
	segment["writer"] = writer;
	segment["from_x"] = from_x;
	segment["from_y"] = from_y;
	segment["to_x"] = to_x;
	segment["to_y"] = to_y;
	segment["trace_write_count"] = int32_t(line.trace.size());
	segment["unique_cell_count"] = line.unique_cell_count;
	segment["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	return segment;
}

Dictionary source_node_boundary_traversal_context(const Dictionary &normalized_config, const Dictionary &coordinate_context, const Dictionary &polygon_split_context, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary context;
	context["phase_id"] = "source_node_boundary_traversal";
	context["h3maped_anchor"] = "0x4a2777";
	context["caller_anchor"] = "0x4a3e58..0x4a3e8c";
	context["source_node_cycle_source"] = "polygon_split_model.source_node_walks_from_0x4cca55_after_0x4ccdfc_finalization";
	context["clip_helper_anchor"] = "0x4a2b33";
	context["deterministic_line_writer_anchor"] = "0x4a261a";
	context["flagged_line_writer_anchor"] = "0x4a2413";
	context["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	context["status"] = "blocked_until_polygon_split_model";
	context["materializes_boundaries"] = true;
	context["materializes_span_fill"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_public_output"] = false;
	context["project_materialized_cell_count"] = 0;
	context["blocked_next"] = "0x4a325d_span_fill";
	if (String(polygon_split_context.get("status", "")) != "private_context_ready") {
		return context;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	context["map_width"] = width;
	context["map_height"] = height;
	context["level_count"] = level_count;
	context["h3maped_water_mode_code"] = water_code;
	context["rng_state_before_0x4a2777_uint32"] = coordinate_context.get("rng_state_after_0x4a218c_replay_uint32", 0);

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_context.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled.size(); ++index) {
		Dictionary item = scaled[index];
		RuntimeZoneSeed zone;
		zone.runtime_index = int32_t(item.get("runtime_zone_index", index));
		zone.x = int32_t(item.get("x_after_bbox_rescale", 0));
		zone.y = int32_t(item.get("y_after_bbox_rescale", 0));
		zone.level = int32_t(item.get("level", 0));
		zone.scaled_size = int32_t(item.get("runtime_size_after_bbox_rescale", 1));
		zones.push_back(zone);
	}

	std::vector<uint32_t> zone_words(size_t(std::max(0, width * height * std::max(1, level_count))), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(std::max(0, width * height * std::max(1, level_count))), 0);
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	Array walks = polygon_split_context.get("source_node_walks", Array());
	Array zone_reports;
	std::map<int64_t, bool> unique_cells;
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
	H3MapedRng rng;
	rng.state = uint32_t(int64_t(coordinate_context.get("rng_state_after_0x4a218c_replay_uint32", 0)));

	auto append_vertex = [&](Array &vertices, int32_t x, int32_t y) {
		Dictionary vertex;
		vertex["x"] = x;
		vertex["y"] = y;
		vertices.append(vertex);
		appended_vertex_count += 1;
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
		merge_line_write_result_4a2777(line, unique_cells, trace_write_count, out_of_bounds_write_count, width, height);
		segments.append(segment_report_4a2777(id, branch, randomized ? String("0x4a2413") : String("0x4a261a"), x1, y1, x2, y2, line));
	};

	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};

	for (int64_t walk_index = 0; walk_index < walks.size(); ++walk_index) {
		Dictionary walk = walks[walk_index];
		const int32_t runtime_zone_index = int32_t(walk.get("runtime_zone_index", -1));
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["status"] = "blocked_before_cycle_consumption";
		if (runtime_zone_index < 0 || runtime_zone_index >= int32_t(zones.size())) {
			blocked_zone_count += 1;
			zone_reports.append(zone_report);
			continue;
		}
		const RuntimeZoneSeed &zone = zones[size_t(runtime_zone_index)];
		const int32_t zone_word = std::max(0, zone.runtime_index);
		const int32_t level = zone.level;
		const bool flagged_branch = !(level_count == 2 && level != 1);
		const int32_t random_span_limit = std::max<int32_t>(1, zone.scaled_size > 0 ? zone.scaled_size : 1);
		Array cycle_nodes = walk.get("cycle_nodes", Array());
		std::vector<PolygonPoint> finalized_points;
		Array point_reports;
		for (int64_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
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
			if (!h3maped_point_inside_bounds_4a2777(candidate_current, bounds)) {
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
			if (!h3maped_point_inside_bounds_4a2777(next_clip, bounds)) {
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

	context["status"] = "private_context_ready";
	context["runtime_zone_walk_count"] = runtime_zone_walk_count;
	context["blocked_zone_count"] = blocked_zone_count;
	context["fallback_zone_count"] = fallback_zone_count;
	context["connector_segment_count"] = connector_segment_count;
	context["wrap_segment_count"] = wrap_segment_count;
	context["final_segment_count"] = final_segment_count;
	context["appended_vertex_count"] = appended_vertex_count;
	context["skipped_unfinalized_node_count"] = skipped_unfinalized_node_count;
	context["skipped_out_of_bounds_clip_count"] = skipped_out_of_bounds_clip_count;
	context["flagged_writer_segment_count"] = flagged_writer_segment_count;
	context["deterministic_writer_segment_count"] = deterministic_writer_segment_count;
	context["randomized_rng_call_count"] = randomized_rng_call_count;
	context["randomized_inserted_midpoint_count"] = randomized_inserted_midpoint_count;
	context["randomized_max_pending_point_count"] = randomized_max_pending_point_count;
	context["rng_state_after_0x4a2777_uint32"] = int64_t(rng.state);
	context["trace_write_count"] = trace_write_count;
	context["unique_cell_count"] = int32_t(unique_cells.size());
	context["out_of_bounds_write_count"] = out_of_bounds_write_count;
	context["loop_guard_exhausted"] = loop_guard_exhausted;
	context["zone_reports"] = zone_reports;
	context["blocked_next"] = "0x4a325d_span_fill";
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return context;
}

Dictionary seed_relocation_4a325d_context(const Dictionary &source_node_walk, const SpanRecord &seed, int32_t width, int32_t height, int32_t level_count) {
	Dictionary context;
	context["status"] = "0x4a325d_seed_in_bounds_relocation_not_used";
	context["h3maped_anchor"] = "0x4a325d";
	context["branch_anchor"] = "0x4a32b2..0x4a338e";
	context["clip_helper_anchor"] = "0x4a2b33";
	context["seed_x"] = seed.x;
	context["seed_y"] = seed.y;
	context["seed_level"] = seed.level;
	const bool seed_in_bounds = seed.x >= 0 && seed.x < width && seed.y >= 0 && seed.y < height && seed.level >= 0 && seed.level < level_count;
	context["seed_in_bounds"] = seed_in_bounds;

	Array candidates;
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_clearance = -1;
	Array cycle_nodes = source_node_walk.get("cycle_nodes", Array());
	for (int64_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
		Dictionary node = cycle_nodes[node_index];
		const int32_t x = int32_t(node.get("+0x1c_finalized_x", 0));
		const int32_t y = int32_t(node.get("+0x20_finalized_y", 0));
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
	context["candidate_count"] = candidates.size();
	context["candidates"] = candidates;
	context["best_candidate_x"] = best_x;
	context["best_candidate_y"] = best_y;
	context["best_candidate_border_clearance"] = best_clearance;
	if (seed_in_bounds) {
		context["relocated"] = false;
		context["relocated_seed_x"] = seed.x;
		context["relocated_seed_y"] = seed.y;
		context["relocated_seed_level"] = seed.level;
		return context;
	}
	if (best_x < 0 || best_y < 0) {
		context["status"] = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
		context["relocated"] = false;
		context["relocated_seed_x"] = seed.x;
		context["relocated_seed_y"] = seed.y;
		context["relocated_seed_level"] = seed.level;
		return context;
	}
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	ClipResult clipped = h3maped_clip_point_4a2b33(seed.x, seed.y, best_x, best_y, bounds);
	context["status"] = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
	context["relocated"] = true;
	context["relocated_seed_x"] = clipped.x;
	context["relocated_seed_y"] = clipped.y;
	context["relocated_seed_level"] = seed.level;
	context["clip_branch"] = clipped.branch;
	return context;
}

Dictionary span_fill_4a325d_context(const Dictionary &normalized_config, const Dictionary &coordinate_context, const Dictionary &polygon_split_context, const Dictionary &boundary_traversal_context, std::vector<uint32_t> zone_words, std::vector<uint8_t> cell_flags) {
	Dictionary context;
	context["phase_id"] = "span_fill_4a325d";
	context["h3maped_anchor"] = "0x4a325d";
	context["boundary_source_anchor"] = "0x4a2777";
	context["seed_source"] = "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale";
	context["source"] = "h3maped 0x4a325d span fill executed against the private 0x4a2777 boundary buffer produced from finalized 0x4cca55 source-node cycles";
	context["status"] = "blocked_until_boundary_traversal";
	context["uses_real_0x4a2777_boundary"] = true;
	context["materializes_span_fill"] = true;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_runtime_players"] = false;
	context["materializes_package_tiles"] = false;
	context["project_grid_public_runtime_adoption"] = false;
	context["public_package_output_allowed"] = false;
	context["blocked_next"] = "0x4a3710_ordering_finalizer";
	if (String(boundary_traversal_context.get("status", "")) != "private_context_ready" || zone_words.empty() || cell_flags.empty()) {
		return context;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	context["map_width"] = width;
	context["map_height"] = height;
	context["level_count"] = level_count;
	context["h3maped_water_mode_code"] = water_code;
	context["boundary_status"] = boundary_traversal_context.get("status", "");
	context["boundary_unique_cell_count"] = boundary_traversal_context.get("unique_cell_count", 0);
	context["boundary_trace_write_count"] = boundary_traversal_context.get("trace_write_count", 0);
	context["boundary_rng_state_after_0x4a2777_uint32"] = boundary_traversal_context.get("rng_state_after_0x4a2777_uint32", 0);

	Dictionary walk_by_runtime;
	Array source_node_walks = polygon_split_context.get("source_node_walks", Array());
	for (int64_t walk_index = 0; walk_index < source_node_walks.size(); ++walk_index) {
		Dictionary walk = source_node_walks[walk_index];
		walk_by_runtime[String::num_int64(int64_t(walk.get("runtime_zone_index", -1)))] = walk;
	}

	Array zone_fill_reports;
	Array scaled = coordinate_context.get("scaled_zone_coordinates", Array());
	int32_t filled_zone_count = 0;
	int32_t seed_blocked_count = 0;
	int32_t seed_relocation_count = 0;
	int32_t missing_seed_count = 0;
	int32_t total_filled_cell_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
	for (int64_t index = 0; index < scaled.size(); ++index) {
		Dictionary item = scaled[index];
		const int32_t runtime_zone_index = int32_t(item.get("runtime_zone_index", index));
		SpanRecord seed{ int32_t(item.get("x_after_bbox_rescale", 0)), int32_t(item.get("y_after_bbox_rescale", 0)), int32_t(item.get("level", 0)) };
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["zone_word_id"] = runtime_zone_index;
		zone_report["seed_x"] = seed.x;
		zone_report["seed_y"] = seed.y;
		zone_report["seed_level"] = seed.level;

		Dictionary matching_walk = walk_by_runtime.get(String::num_int64(runtime_zone_index), Dictionary());
		Dictionary relocation = seed_relocation_4a325d_context(matching_walk, seed, width, height, level_count);
		zone_report["seed_relocation_status"] = relocation.get("status", "");
		zone_report["seed_relocation"] = relocation;
		if (bool(relocation.get("relocated", false))) {
			seed.x = int32_t(relocation.get("relocated_seed_x", seed.x));
			seed.y = int32_t(relocation.get("relocated_seed_y", seed.y));
			seed.level = int32_t(relocation.get("relocated_seed_level", seed.level));
			seed_relocation_count += 1;
		}
		zone_report["effective_seed_x"] = seed.x;
		zone_report["effective_seed_y"] = seed.y;
		zone_report["effective_seed_level"] = seed.level;
		if (seed.x < 0 || seed.x >= width || seed.y < 0 || seed.y >= height || seed.level < 0 || seed.level >= level_count) {
			missing_seed_count += 1;
			zone_report["status"] = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
			zone_fill_reports.append(zone_report);
			continue;
		}

		const bool seed_unassigned = h3maped_cell_unassigned(zone_words, width, height, seed.x, seed.y, seed.level);
		zone_report["seed_unassigned_before_fill"] = seed_unassigned;
		if (!seed_unassigned) {
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

	int32_t total_boundary_or_filled_cell_count = 0;
	int32_t remaining_unassigned_cell_count = 0;
	int32_t reserved_flag_cell_count = 0;
	Dictionary cells_by_zone_word;
	for (int32_t index = 0; index < int32_t(zone_words.size()); ++index) {
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

	context["status"] = "private_context_ready";
	context["runtime_zone_fill_attempt_count"] = zone_fill_reports.size();
	context["filled_zone_count"] = filled_zone_count;
	context["seed_blocked_count"] = seed_blocked_count;
	context["missing_seed_count"] = missing_seed_count;
	context["seed_relocation_count"] = seed_relocation_count;
	context["unique_filled_cell_count"] = total_filled_cell_count;
	context["total_boundary_or_filled_cell_count"] = total_boundary_or_filled_cell_count;
	context["remaining_unassigned_cell_count"] = remaining_unassigned_cell_count;
	context["reserved_flag_cell_count"] = reserved_flag_cell_count;
	context["pushed_span_count"] = pushed_span_count;
	context["popped_span_count"] = popped_span_count;
	context["max_pending_span_count"] = max_pending_span_count;
	context["out_of_bounds_span_count"] = out_of_bounds_span_count;
	context["blocked_initial_span_count"] = blocked_initial_span_count;
	context["cells_by_zone_word"] = cells_by_zone_word;
	context["zone_fill_reports"] = zone_fill_reports;
	context["blocked_next"] = "0x4a3710_ordering_finalizer";
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
		const Dictionary polygon_split_context = polygon_split_model_context(normalized_config, coordinate_context, source_node_rectangle);
		std::vector<uint32_t> boundary_zone_words;
		std::vector<uint8_t> boundary_cell_flags;
		const Dictionary boundary_traversal_context = source_node_boundary_traversal_context(normalized_config, coordinate_context, polygon_split_context, &boundary_zone_words, &boundary_cell_flags);
		const Dictionary span_fill_context = span_fill_4a325d_context(normalized_config, coordinate_context, polygon_split_context, boundary_traversal_context, boundary_zone_words, boundary_cell_flags);
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
							context["polygon_split_context"] = polygon_split_context;
							if (String(polygon_split_context.get("status", "")) == "private_context_ready") {
								completed_phases.append("polygon_split_model");
								context["boundary_traversal_context"] = boundary_traversal_context;
								if (String(boundary_traversal_context.get("status", "")) == "private_context_ready") {
									completed_phases.append("source_node_boundary_traversal");
									context["span_fill_context"] = span_fill_context;
									if (String(span_fill_context.get("status", "")) == "private_context_ready") {
										completed_phases.append("span_fill_4a325d");
										context["status"] = "span_fill_private_context_ready";
										context["blocked_next"] = "0x4a3710_ordering_finalizer";
									} else {
										context["status"] = "source_node_boundary_private_context_ready";
										context["blocked_next"] = "0x4a325d_span_fill";
									}
								} else {
									context["status"] = "polygon_split_model_private_context_ready";
									context["blocked_next"] = "source_node_cycles_to_0x4a2777_boundary_traversal";
								}
							} else {
								context["status"] = "source_node_rectangle_private_context_ready";
								context["blocked_next"] = "polygon_split_model_0x4ccb64_0x4ccdfc";
							}
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
