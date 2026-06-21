#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <queue>
#include <set>
#include <utility>
#include <vector>

namespace aurelion::h3maped_rmg_core {
namespace {

struct Coord {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct BoundaryPoint {
	int32_t x = 0;
	int32_t y = 0;
};

struct ScoreFrontierNode {
	int32_t score = 0;
	Coord coord;
};

struct ScoreFrontierCompare {
	bool operator()(const ScoreFrontierNode &left, const ScoreFrontierNode &right) const {
		return left.score > right.score;
	}
};

constexpr int32_t SUPPORTED_LAND_ENDPOINT_CURSOR_KEY_COUNT_0XD8_0XDC = 8;
constexpr uint32_t SUPPORTED_LAND_OBSERVED_STALE_CURSOR_0XF5C = 0x7a1befdfU;

struct SourcePolygonPoint4ccb64 {
	int32_t x = 0;
	int32_t y = 0;
};

struct SourcePolygonNode4ccb64 {
	int32_t x = 0;
	int32_t y = 0;
	int32_t payload = 0;
	bool has_payload = false;
	int32_t pair = -1;
	int32_t next = -1;
	int32_t previous = -1;
	bool active = true;
	bool finalized = false;
	int32_t finalized_x = -1;
	int32_t finalized_y = -1;
};

struct SourcePolygonModel4ccb64 {
	std::vector<SourcePolygonNode4ccb64> nodes;
	int32_t root = -1;

	int32_t add_pair(int32_t from_x, int32_t from_y, int32_t from_payload, int32_t to_x, int32_t to_y, int32_t to_payload, bool from_has_payload = false, bool to_has_payload = false) {
		const int32_t primary_index = int32_t(nodes.size());
		const int32_t paired_index = primary_index + 1;
		SourcePolygonNode4ccb64 primary;
		primary.x = from_x;
		primary.y = from_y;
		primary.payload = from_payload;
		primary.has_payload = from_has_payload;
		primary.pair = paired_index;
		primary.next = primary_index;
		primary.previous = primary_index;
		SourcePolygonNode4ccb64 paired;
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
		for (int32_t index = 0; index + 1 < int32_t(nodes.size()); index += 2) {
			if (nodes[size_t(index)].active || nodes[size_t(index + 1)].active) {
				count += 1;
			}
		}
		return count;
	}

	int32_t bridge_4ccb1f(int32_t old_node, int32_t target_node) {
		const SourcePolygonNode4ccb64 &old_pair = nodes[size_t(nodes[size_t(old_node)].pair)];
		const SourcePolygonNode4ccb64 &target = nodes[size_t(target_node)];
		const int32_t bridge_primary = add_pair(old_pair.x, old_pair.y, old_pair.payload, target.x, target.y, target.payload, old_pair.has_payload, target.has_payload);
		relink_4cc643(bridge_primary, nodes[size_t(nodes[size_t(old_node)].pair)].previous);
		relink_4cc643(nodes[size_t(bridge_primary)].pair, target_node);
		return bridge_primary;
	}

	int64_t side_4cca55(int32_t from_node, int32_t to_node, int32_t x, int32_t y) const {
		const SourcePolygonNode4ccb64 &from = nodes[size_t(from_node)];
		const SourcePolygonNode4ccb64 &to = nodes[size_t(to_node)];
		return int64_t(to.y - from.y) * int64_t(x - from.x) - int64_t(to.x - from.x) * int64_t(y - from.y);
	}

	int32_t locate_4cca55(int32_t x, int32_t y) const {
		int32_t current = root;
		for (int32_t guard = 0; guard < 512 && current >= 0 && current < int32_t(nodes.size()); ++guard) {
			const SourcePolygonNode4ccb64 &current_node = nodes[size_t(current)];
			if (current_node.x == x && current_node.y == y) {
				return current;
			}
			const int32_t paired = current_node.pair;
			const SourcePolygonNode4ccb64 &paired_node = nodes[size_t(paired)];
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
		const SourcePolygonNode4ccb64 &node = nodes[size_t(node_index)];
		const SourcePolygonNode4ccb64 &paired = nodes[size_t(node.pair)];
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
		const int64_t v1 = int64_t(y4 - y2) * int64_t(x3 - x2) - int64_t(x4 - x2) * int64_t(y3 - y2);
		const int64_t v2 = int64_t(x2 - x1) * int64_t(y3 - y1) - int64_t(y2 - y1) * int64_t(x3 - x1);
		const int64_t v3 = int64_t(y4 - y1) * int64_t(x3 - x1) - int64_t(x4 - x1) * int64_t(y3 - y1);
		const int64_t v4 = int64_t(y4 - y1) * int64_t(x2 - x1) - int64_t(x4 - x1) * int64_t(y2 - y1);
		const int64_t p1 = int64_t(x1) * int64_t(x1) + int64_t(y1) * int64_t(y1);
		const int64_t p2 = int64_t(x2) * int64_t(x2) + int64_t(y2) * int64_t(y2);
		const int64_t p3 = int64_t(x3) * int64_t(x3) + int64_t(y3) * int64_t(y3);
		const int64_t p4 = int64_t(x4) * int64_t(x4) + int64_t(y4) * int64_t(y4);
		return (p1 * v1 - p4 * v2 - p2 * v3 + p3 * v4) > 0;
	}

	bool crossing_orientation_gate_4ccb64(int32_t node_index) const {
		const SourcePolygonNode4ccb64 &node = nodes[size_t(node_index)];
		const SourcePolygonNode4ccb64 &paired = nodes[size_t(node.pair)];
		const SourcePolygonNode4ccb64 &previous_pair = nodes[size_t(nodes[size_t(node.previous)].pair)];
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

	static SourcePolygonPoint4ccb64 intersection_4ccd69(int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t x3, int32_t y3) {
		const int64_t term = int64_t(y3 - y2) * int64_t(y1 - y3) + int64_t(x1 - x3) * int64_t(x3 - x2);
		const int64_t denominator = int64_t(x1 - x3) * int64_t(y1 - y2) + int64_t(y1 - y3) * int64_t(x2 - x1);
		const int64_t x_adjust = idiv_truncate(int64_t(y1 - y2) * term, denominator);
		const int64_t y_adjust = idiv_truncate(int64_t(x2 - x1) * term, denominator);
		return SourcePolygonPoint4ccb64 {
			x1 + half_truncate_4ccd69(int64_t(x2 - x1) + x_adjust),
			y1 + half_truncate_4ccd69(int64_t(y2 - y1) + y_adjust)
		};
	}

	void write_finalized_4ccdfc(int32_t node_index, const SourcePolygonPoint4ccb64 &point) {
		nodes[size_t(node_index)].finalized_x = point.x;
		nodes[size_t(node_index)].finalized_y = point.y;
		nodes[size_t(node_index)].finalized = true;
	}

	int32_t finalize_4ccdfc() {
		int32_t finalized_triplets = 0;
		for (int32_t index = 0; index < int32_t(nodes.size()); ++index) {
			SourcePolygonNode4ccb64 &node = nodes[size_t(index)];
			if (!node.active || !node.has_payload || node.finalized) {
				continue;
			}
			const int32_t next_pair = nodes[size_t(node.next)].pair;
			const SourcePolygonNode4ccb64 &paired = nodes[size_t(node.pair)];
			const SourcePolygonNode4ccb64 &next_pair_node = nodes[size_t(next_pair)];
			const SourcePolygonPoint4ccb64 point = intersection_4ccd69(node.x, node.y, paired.x, paired.y, next_pair_node.x, next_pair_node.y);
			write_finalized_4ccdfc(index, point);
			write_finalized_4ccdfc(next_pair, point);
			const int32_t nested = nodes[size_t(next_pair)].next;
			const int32_t nested_pair = nodes[size_t(nested)].pair;
			write_finalized_4ccdfc(nested_pair, point);
			finalized_triplets += 1;
		}
		return finalized_triplets;
	}
};

struct CoordinateZone4a218c {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t source_index = -1;
	int32_t h3maped_zone_word_id = -1;
	int32_t source_bucket = -1;
	int32_t source_owner_index = -1;
	int32_t actual_player_color = -1;
	int32_t source_base_size = 0;
	uint16_t allowed_town_mask_0x41_0x49 = 0U;
	int32_t selected_town_choice_index_0x49b3c1 = -1;
	bool terrain_match_to_town_0x84 = false;
	uint16_t allowed_terrain_mask_0x85_0x8c = 0U;
	SourceZonePayload4a218c source_payload;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t scaled_size = 0;
};

struct TerrainVisualRow {
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
};

struct TerrainClassResult {
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
};

struct TerrainVisualGridTables {
	std::vector<TerrainVisualRow> dirt_rows;
	std::vector<TerrainVisualRow> sand_rows;
	std::vector<TerrainVisualRow> normal_rows;
	std::vector<TerrainVisualRow> water_rows;
	std::vector<TerrainVisualRow> rock_rows;
};

constexpr std::array<std::array<int32_t, 2>, 8> DIRECTION_TABLE_0X5A2658 = { {
	{ 1, 0 },
	{ 1, 1 },
	{ 0, 1 },
	{ -1, 1 },
	{ -1, 0 },
	{ -1, -1 },
	{ 0, -1 },
	{ 1, -1 },
} };

constexpr std::array<int32_t, 9> H3_TOWN_TO_TERRAIN_TABLE_540908 = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };

constexpr std::array<TerrainVisualRow, 79> H3_TERRAIN_VISUAL_NORMAL_ROWS = { {
	{ 2, 0, 0 }, { 2, 0, 0 }, { 2, 0, 0 }, { 2, 0, 0 }, { 3, 0, 0 }, { 3, 0, 0 }, { 3, 0, 0 }, { 3, 0, 0 },
	{ 4, 0, 0 }, { 4, 0, 0 }, { 4, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 }, { 5, 0, 0 }, { 5, 0, 0 }, { 5, 0, 0 },
	{ 6, 0, 0 }, { 6, 0, 0 }, { 7, 0, 0 }, { 7, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 },
	{ 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 },
	{ 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 12, 0, 0 }, { 12, 0, 0 }, { 13, 0, 0 }, { 13, 0, 0 },
	{ 14, 0, 0 }, { 15, 0, 0 }, { 16, 0, 0 }, { 17, 0, 0 }, { 18, 0, 0 }, { 19, 0, 0 }, { 20, 0, 0 }, { 21, 0, 0 },
	{ 22, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 23, 0, 0 }, { 24, 0, 0 }, { 25, 0, 0 }, { 26, 0, 0 }, { 28, 0, 0 }, { 27, 0, 0 },
} };

constexpr std::array<TerrainVisualRow, 46> H3_TERRAIN_VISUAL_DIRT_ROWS = { {
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 },
	{ 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 13, 0, 0 }, { 13, 0, 0 }, { 16, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 24, 0, 0 },
} };

constexpr std::array<TerrainVisualRow, 24> H3_TERRAIN_VISUAL_SAND_ROWS = { {
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
} };

constexpr std::array<TerrainVisualRow, 33> H3_TERRAIN_VISUAL_WATER_ROWS = { {
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 },
	{ 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 13, 0, 0 }, { 13, 0, 0 }, { 16, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 },
} };

constexpr std::array<TerrainVisualRow, 48> H3_TERRAIN_VISUAL_ROCK_ROWS = { {
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 1, 0 }, { 8, 1, 0 }, { 8, 0, 1 }, { 8, 0, 1 }, { 8, 1, 1 }, { 8, 1, 1 },
	{ 9, 0, 0 }, { 9, 0, 0 }, { 9, 1, 0 }, { 9, 1, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 1 }, { 10, 0, 1 },
	{ 11, 0, 0 }, { 11, 0, 0 }, { 11, 1, 0 }, { 11, 1, 0 }, { 11, 0, 1 }, { 11, 0, 1 }, { 11, 1, 1 }, { 11, 1, 1 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 12, 1, 0 }, { 12, 1, 0 }, { 12, 0, 1 }, { 12, 0, 1 }, { 12, 1, 1 }, { 12, 1, 1 },
	{ 13, 0, 0 }, { 13, 0, 0 }, { 13, 1, 0 }, { 13, 1, 0 }, { 13, 0, 1 }, { 13, 0, 1 }, { 13, 1, 1 }, { 13, 1, 1 },
} };

int32_t wrap_i32(int64_t value) {
	const uint32_t wrapped = uint32_t(uint64_t(value) & 0xffffffffULL);
	if (wrapped == 0x80000000U) {
		return std::numeric_limits<int32_t>::min();
	}
	if ((wrapped & 0x80000000U) != 0U) {
		return -int32_t((~wrapped + 1U) & 0x7fffffffU);
	}
	return int32_t(wrapped);
}

int32_t imul_low_i32(int32_t lhs, int32_t rhs) {
	return wrap_i32(int64_t(lhs) * int64_t(rhs));
}

int32_t idiv_i32(int32_t numerator, int32_t denominator) {
	if (denominator == 0) {
		return 0;
	}
	return int32_t(int64_t(numerator) / int64_t(denominator));
}

int32_t imul_low_idiv_i32(int32_t lhs, int32_t rhs, int32_t denominator) {
	return idiv_i32(imul_low_i32(lhs, rhs), denominator);
}

int32_t sign_for_line_4a261a(int32_t value) {
	return value > 0 ? 1 : -1;
}

int32_t signed_half_round_4a2413(int32_t value) {
	const int32_t sign = value < 0 ? -1 : 0;
	return (value - sign) >> 1;
}

int32_t distance_truncate(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

int32_t runtime_index_for_coordinate_zone(const CoordinateZone4a218c &zone, int32_t fallback) {
	return zone.runtime_zone_index >= 0 ? zone.runtime_zone_index : fallback;
}

int32_t zone_word_for_coordinate_zone(const CoordinateZone4a218c &zone, int32_t fallback) {
	if (zone.h3maped_zone_word_id >= 0) {
		return zone.h3maped_zone_word_id;
	}
	if (zone.source_zone_id > 0 && zone.source_index >= 0 && zone.source_zone_id == zone.source_index + 1) {
		return zone.source_index;
	}
	if (zone.source_zone_id >= 0) {
		return zone.source_zone_id;
	}
	if (zone.source_index >= 0) {
		return zone.source_index;
	}
	return fallback;
}

int32_t generated_cell_owner_byte2_signed_4a4142(uint32_t word_0x20) {
	const uint32_t value = (word_0x20 >> 16U) & 0xffU;
	return value >= 0x80U ? int32_t(value) - 0x100 : int32_t(value);
}

std::vector<int32_t> mask_slots(uint16_t mask, int32_t max_slots) {
	std::vector<int32_t> slots;
	for (int32_t index = 0; index < max_slots; ++index) {
		if ((mask & (uint16_t(1U) << uint32_t(index))) != 0U) {
			slots.push_back(index);
		}
	}
	return slots;
}

template <size_t N>
std::vector<TerrainVisualRow> terrain_visual_rows_from_embedded(const std::array<TerrainVisualRow, N> &rows) {
	return std::vector<TerrainVisualRow>(rows.begin(), rows.end());
}

TerrainVisualGridTables load_terrain_visual_grid_tables_4bcff5() {
	TerrainVisualGridTables tables;
	tables.dirt_rows = terrain_visual_rows_from_embedded(H3_TERRAIN_VISUAL_DIRT_ROWS);
	tables.sand_rows = terrain_visual_rows_from_embedded(H3_TERRAIN_VISUAL_SAND_ROWS);
	tables.normal_rows = terrain_visual_rows_from_embedded(H3_TERRAIN_VISUAL_NORMAL_ROWS);
	tables.water_rows = terrain_visual_rows_from_embedded(H3_TERRAIN_VISUAL_WATER_ROWS);
	tables.rock_rows = terrain_visual_rows_from_embedded(H3_TERRAIN_VISUAL_ROCK_ROWS);
	return tables;
}

const std::vector<TerrainVisualRow> &visual_rows_for_terrain_id_4bcff5(const TerrainVisualGridTables &tables, int32_t terrain_id) {
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

int32_t constructor_probability_for_terrain_id_4bcff5(int32_t terrain_id) {
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

std::vector<int32_t> row_indices_for_class_4bcfc3(const std::vector<TerrainVisualRow> &rows, int32_t shape_class) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_group_4bcfc3(const std::vector<TerrainVisualRow> &rows, int32_t shape_class, int32_t group_flag) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class && rows[size_t(index)].flag_a == group_flag) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_flags_4bcfc3(const std::vector<TerrainVisualRow> &rows, int32_t shape_class, int32_t flag_a, int32_t flag_b) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		const TerrainVisualRow &row = rows[size_t(index)];
		if (row.shape_class == shape_class && row.flag_a == flag_a && row.flag_b == flag_b) {
			indices.push_back(index);
		}
	}
	return indices;
}

uint32_t terrain_scratch_word_4bad0f(int32_t terrain_id, int32_t selected_row, int32_t flag_a, int32_t flag_b) {
	return 1U
			| ((uint32_t(terrain_id) & 0x0fU) << 1U)
			| ((uint32_t(selected_row) & 0x7fU) << 5U)
			| ((uint32_t(flag_a) & 0x01U) << 12U)
			| ((uint32_t(flag_b) & 0x01U) << 13U);
}

int32_t scratch_terrain_id_4bad0f(uint32_t scratch_word) {
	return int32_t((scratch_word >> 1U) & 0x0fU);
}

int32_t scratch_art_id_4bad0f(uint32_t scratch_word) {
	return int32_t((scratch_word >> 5U) & 0x7fU);
}

int32_t terrain_trait_flag4_4bb039(int32_t terrain_id) {
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

int32_t terrain_relation_4bb039(int32_t center_terrain_id, int32_t neighbor_terrain_id) {
	if (center_terrain_id == neighbor_terrain_id || center_terrain_id == 1) {
		return 0;
	}
	if (terrain_trait_flag4_4bb039(center_terrain_id) == 0 || terrain_trait_flag4_4bb039(neighbor_terrain_id) == 0) {
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

int32_t relation_at_oriented_4bb075(const std::array<int32_t, 8> &relations, int32_t flag_a, int32_t flag_b, int32_t slot, bool transposed_index = false) {
	return relations[size_t(orientation_slot_5436e0(flag_a, flag_b, slot, transposed_index))];
}

TerrainClassResult classify_terrain_relations_4bb075(const std::array<int32_t, 8> &relations) {
	static constexpr std::array<std::array<int32_t, 2>, 4> FLAGS = { { { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } } };
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(2) == 1 && r(4) == 1) {
			if (r(1) == 2 && r(5) == 2) {
				return { 0x1c, a, b };
			}
			if (r(3) == 2) {
				return { 0x1b, a, b };
			}
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(0) == 1 && r(6) == 1 && r(3) != 0) {
			return { r(3) == 1 ? 0x17 : 0x19, a, b };
		}
		if (r(0) == 2 && r(6) == 2 && r(3) != 0) {
			return { r(3) == 1 ? 0x1a : 0x18, a, b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(2) == 2 && r(4) == 1 && r(5) == 2) {
			return { 0x08, 1 - a, 1 - b };
		}
		if (r(2) == 1 && r(4) == 2 && r(1) == 2) {
			return { 0x08, 1 - a, 1 - b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot, true); };
		if (r(2) == 1 && r(4) == 1) {
			if (r(5) == 2) {
				return { 0x11, a, b };
			}
			if (r(1) == 2) {
				return { 0x12, a, b };
			}
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(0) == 1 && r(6) == 1) {
			return { 0x02, a, b };
		}
		if (r(0) == 2 && r(6) == 2) {
			return { 0x08, a, b };
		}
		if (r(2) == 1 && r(5) == 2) {
			return { 0x11, a, b };
		}
		if (r(4) == 1 && r(1) == 2) {
			return { 0x12, a, b };
		}
		if (r(2) == 2 && r(5) == 1) {
			return { 0x15, a, b };
		}
		if (r(4) == 2 && r(1) == 1) {
			return { 0x16, a, b };
		}
		if (r(6) == 1 && r(1) == 1) {
			return { 0x02, a, b };
		}
		if (r(0) == 1 && r(5) == 1) {
			return { 0x02, a, b };
		}
		if (r(6) == 2 && r(1) == 2) {
			return { 0x08, a, b };
		}
		if (r(0) == 2 && r(5) == 2) {
			return { 0x08, a, b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(2) == 1 && r(3) == 2) {
			return { 0x13, a, b };
		}
		if (r(4) == 1 && r(3) == 2) {
			return { 0x14, a, b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(0) == 1) {
			return { 0x04, a, b };
		}
		if (r(0) == 2) {
			return { 0x0a, a, b };
		}
		if (r(6) == 1) {
			return { 0x03, a, b };
		}
		if (r(6) == 2) {
			return { 0x09, a, b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(7) == 1 && r(3) == 1) {
			return { 0x0e, a, b };
		}
		if (r(7) == 1 && r(3) == 2) {
			return { 0x0f, a, b };
		}
		if (r(7) == 2 && r(3) == 2) {
			return { 0x10, a, b };
		}
	}
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_4bb075(relations, a, b, slot); };
		if (r(3) == 1) {
			return { 0x05, a, b };
		}
		if (r(3) == 2) {
			return { 0x0b, a, b };
		}
	}
	return { 0x00, 0, 0 };
}

int32_t terrain_at_grid_index_4bb74b(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size())) {
		return fallback_terrain_id;
	}
	return terrain_codes[size_t(index)];
}

bool set_terrain_at_grid_index_4bb74b(std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return false;
	}
	const int32_t index = level * level_tile_count + y * width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size()) || terrain_codes[size_t(index)] == terrain_id) {
		return false;
	}
	terrain_codes[size_t(index)] = terrain_id;
	return true;
}

int64_t terrain_grid_key_4bb74b(int32_t level, int32_t x, int32_t y) {
	return (int64_t(level) << 40) | (int64_t(y) << 20) | int64_t(x);
}

void terrain_decode_grid_key_4bb74b(int64_t key, int32_t &level, int32_t &x, int32_t &y) {
	level = int32_t(key >> 40);
	y = int32_t((key >> 20) & 0xfffff);
	x = int32_t(key & 0xfffff);
}

std::array<int32_t, 8> same_terrain_mask_4bc74c(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	std::array<int32_t, 8> mask = { 0, 0, 0, 0, 0, 0, 0, 0 };
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		return nx >= 0 && ny >= 0 && nx < width && ny < height && terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, nx, ny, -1) == terrain_id;
	};
	const bool north = same(x, y - 1);
	const bool south = same(x, y + 1);
	const bool west = same(x - 1, y);
	const bool east = same(x + 1, y);
	mask[0] = north ? 1 : 0;
	mask[4] = south ? 1 : 0;
	mask[6] = west ? 1 : 0;
	mask[2] = east ? 1 : 0;
	mask[7] = (north || west) && same(x - 1, y - 1) ? 1 : 0;
	mask[1] = (north || east) && same(x + 1, y - 1) ? 1 : 0;
	mask[5] = (south || west) && same(x - 1, y + 1) ? 1 : 0;
	mask[3] = (south || east) && same(x + 1, y + 1) ? 1 : 0;
	return mask;
}

std::vector<uint8_t> final_sweep_boundary_counts_4bbfcc(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_count) {
	const int32_t level_tile_count = width * height;
	const int32_t expected_tile_count = level_tile_count * std::max(0, level_count);
	std::vector<uint8_t> boundary_counts(size_t(std::max(0, expected_tile_count)), 0);
	if (width <= 0 || height <= 0 || level_count <= 0 || int32_t(terrain_codes.size()) != expected_tile_count) {
		return boundary_counts;
	}
	auto increment_if_different = [&](int32_t level_base, int32_t x, int32_t y, int32_t nx, int32_t ny) {
		if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
			return;
		}
		const int32_t index = level_base + y * width + x;
		const int32_t neighbor_index = level_base + ny * width + nx;
		if (terrain_codes[size_t(index)] == terrain_codes[size_t(neighbor_index)]) {
			return;
		}
		boundary_counts[size_t(index)] = uint8_t(std::min<int32_t>(255, int32_t(boundary_counts[size_t(index)]) + 1));
		boundary_counts[size_t(neighbor_index)] = uint8_t(std::min<int32_t>(255, int32_t(boundary_counts[size_t(neighbor_index)]) + 1));
	};
	for (int32_t level = 0; level < level_count; ++level) {
		const int32_t level_base = level * level_tile_count;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				increment_if_different(level_base, x, y, x + 1, y);
				increment_if_different(level_base, x, y, x, y + 1);
				increment_if_different(level_base, x, y, x + 1, y + 1);
				increment_if_different(level_base, x, y, x - 1, y + 1);
			}
		}
	}
	return boundary_counts;
}

bool same_class_region_gate_4bc928(const std::array<int32_t, 8> &mask) {
	int32_t cursor = 0;
	if (mask[0] != 0) {
		do {
			cursor = (cursor + 1) & 7;
			if (cursor == 0) {
				return false;
			}
		} while (mask[size_t(cursor)] != 0);
	}
	const int32_t start_zero = cursor;
	int32_t scan = (cursor + 1) & 7;
	while (scan != start_zero && mask[size_t(scan)] == 0) {
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
	} while (mask[size_t(scan)] != 0);
	do {
		scan = (scan + 1) & 7;
		if (scan == start_zero) {
			return false;
		}
	} while (mask[size_t(scan)] == 0);
	return true;
}

bool horizontal_pair_gate_4bc674(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= width - 1 || y < 0 || y >= height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool vertical_pair_gate_4bc6e0(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= height - 1 || x < 0 || x >= width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool toolkit_byte5_allows_same_class_gate_4bb74b(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool candidate_gate_4bc988(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = same_class_region_gate_4bc928(same_terrain_mask_4bc74c(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id));
	return horizontal_pair_gate || vertical_pair_gate || (toolkit_byte5_allows_same_class_gate_4bb74b(terrain_id) && same_class_region_gate);
}

int32_t frontier_retouch_4bbd01(std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, std::vector<int64_t> *changed_keys_out = nullptr) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](int32_t target_x, int32_t target_y) {
		const bool in_bounds = target_x >= 0 && target_y >= 0 && target_x < width && target_y < height;
		const bool changed = set_terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, target_x, target_y, terrain_id);
		if (changed) {
			changed_count += 1;
		}
		if (in_bounds && changed_keys_out != nullptr) {
			changed_keys_out->push_back(terrain_grid_key_4bb74b(level, target_x, target_y));
		}
	};
	if (vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = candidate_gate_4bc988(terrain_codes, width, height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = candidate_gate_4bc988(terrain_codes, width, height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(x, choose_upper ? y - 1 : y + 1);
	}
	if (horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = candidate_gate_4bc988(terrain_codes, width, height, level_tile_count, level, x - 1, y);
		const bool right_candidate = candidate_gate_4bc988(terrain_codes, width, height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? x - 1 : x + 1, y);
	}
	const std::array<int32_t, 8> same_terrain_mask = same_terrain_mask_4bc74c(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
	if (toolkit_byte5_allows_same_class_gate_4bb74b(terrain_id) && same_class_region_gate_4bc928(same_terrain_mask)) {
		int32_t start_same = 0;
		if (same_terrain_mask[0] == 0) {
			do {
				start_same = (start_same + 1) & 7;
				if (start_same == 0) {
					return changed_count;
				}
			} while (same_terrain_mask[size_t(start_same)] == 0);
		}
		struct ZeroRun {
			int32_t score = 0;
			int32_t start = 0;
			int32_t length = 0;
		};
		std::vector<ZeroRun> runs;
		int32_t scan = start_same;
		while (true) {
			scan = (scan + 1) & 7;
			if (scan == start_same) {
				break;
			}
			if (same_terrain_mask[size_t(scan)] != 0) {
				continue;
			}
			ZeroRun run;
			run.start = scan;
			do {
				run.score += (scan & 1) != 0 ? 1 : 2;
				run.length += 1;
				scan = (scan + 1) & 7;
				if (scan == start_same) {
					break;
				}
			} while (same_terrain_mask[size_t(scan)] == 0);
			runs.push_back(run);
			if (scan == start_same) {
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
				if (target_x >= 0 && target_y >= 0 && target_x < width && target_y < height) {
					retouch(target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
}

TerrainClassResult classify_grid_cell_4bb075(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	const std::array<int32_t, 8> relations = {
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y - 1, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x + 1, y - 1, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x + 1, y, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x + 1, y + 1, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x, y + 1, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x - 1, y + 1, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x - 1, y, center)),
		terrain_relation_4bb039(center, terrain_at_grid_index_4bb74b(terrain_codes, width, height, level_tile_count, level, x - 1, y - 1, center)),
	};
	return classify_terrain_relations_4bb075(relations);
}

bool select_visual_row_for_grid_cell_4bcfc3(const std::vector<TerrainVisualRow> &rows, int32_t terrain_id, const TerrainClassResult &classified, int32_t neighbor_mask, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b) {
	std::vector<int32_t> bucket;
	if (terrain_id == 9) {
		bucket = row_indices_for_class_flags_4bcfc3(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		const std::vector<int32_t> ordinary = row_indices_for_class_group_4bcfc3(rows, 0, 0);
		const std::vector<int32_t> special = row_indices_for_class_group_4bcfc3(rows, 0, 1);
		if (!special.empty()) {
			const int32_t probability_rng_value = rng.next();
			const int32_t probability_threshold = (constructor_probability_for_terrain_id_4bcff5(terrain_id) * std::max(0, neighbor_mask)) / 8;
			bucket = (probability_rng_value % 100) < probability_threshold ? special : ordinary;
		} else {
			bucket = ordinary;
		}
		out_flag_a = 0;
		out_flag_b = 0;
	} else {
		bucket = row_indices_for_class_4bcfc3(rows, classified.shape_class);
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

int32_t runtime_town_choice_49b3c1(uint16_t allowed_town_mask_0x41_0x49, H3MapedRng &rng, int32_t &rng_call_count) {
	const std::vector<int32_t> slots = mask_slots(allowed_town_mask_0x41_0x49, 9);
	if (slots.empty()) {
		return -1;
	}
	const int32_t rng_value = rng.next();
	rng_call_count += 1;
	return slots[size_t(rng_value % int32_t(slots.size()))];
}

RuntimeZoneSeedInput4a218c runtime_seed_from_coordinate_zone_after_49b3c1(const CoordinateZone4a218c &zone, int32_t fallback_runtime_index) {
	RuntimeZoneSeedInput4a218c seed;
	seed.runtime_zone_index = runtime_index_for_coordinate_zone(zone, fallback_runtime_index);
	seed.source_zone_id = zone.source_zone_id;
	seed.source_index = zone.source_index;
	seed.h3maped_zone_word_id = zone.h3maped_zone_word_id;
	seed.source_bucket = zone.source_bucket;
	seed.source_owner_index = zone.source_owner_index;
	seed.actual_player_color = zone.actual_player_color;
	seed.source_base_size = zone.source_base_size;
	seed.allowed_town_mask_0x41_0x49 = zone.allowed_town_mask_0x41_0x49;
	seed.selected_town_choice_index_0x49b3c1 = zone.selected_town_choice_index_0x49b3c1;
	seed.terrain_match_to_town_0x84 = zone.terrain_match_to_town_0x84;
	seed.allowed_terrain_mask_0x85_0x8c = zone.allowed_terrain_mask_0x85_0x8c;
	seed.source_payload = zone.source_payload;
	return seed;
}

int32_t coordinate_zone_position_for_runtime_index(const std::vector<CoordinateZone4a218c> &zones, int32_t runtime_zone_index) {
	for (int32_t index = 0; index < int32_t(zones.size()); ++index) {
		if (runtime_index_for_coordinate_zone(zones[size_t(index)], index) == runtime_zone_index) {
			return index;
		}
	}
	return -1;
}

bool coordinate_candidate_valid_4a1701(const CoordinateZone4a218c &current, const CoordinateCandidate4a17f5 &candidate, const std::vector<CoordinateZone4a218c> &zones, const std::vector<int32_t> &placed_positions) {
	if ((current.source_bucket == 0 || current.source_bucket == 1) && candidate.level == 1
			&& current.actual_player_color != 3 && current.actual_player_color != 4 && current.actual_player_color != 5) {
		return false;
	}
	for (const int32_t other_position : placed_positions) {
		if (other_position < 0 || other_position >= int32_t(zones.size())) {
			continue;
		}
		const CoordinateZone4a218c &other = zones[size_t(other_position)];
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

bool coordinate_zones_connectable_49b6e2(const CoordinateZone4a218c &first, const CoordinateZone4a218c &second) {
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

int32_t coordinate_link_acceptance_count_4a1967(const CoordinateZone4a218c &current, const std::vector<CoordinateZone4a218c> &zones, const std::vector<RuntimeLinkSeedInput4a218c> &links) {
	const int32_t current_runtime_index = runtime_index_for_coordinate_zone(current, current.source_index);
	int32_t accepted = 0;
	for (const RuntimeLinkSeedInput4a218c &link : links) {
		int32_t other_runtime_index = -1;
		if (link.from_index == current_runtime_index) {
			other_runtime_index = link.to_index;
		} else if (link.to_index == current_runtime_index) {
			other_runtime_index = link.from_index;
		}
		const int32_t other_position = coordinate_zone_position_for_runtime_index(zones, other_runtime_index);
		if (other_position < 0) {
			continue;
		}
		if (coordinate_zones_connectable_49b6e2(zones[size_t(other_position)], current)) {
			accepted += 1;
		}
	}
	return accepted;
}

int32_t coordinate_prune_divisor_from_generator_mode_4a218c(int32_t generator_mode_0x10b8) {
	if (generator_mode_0x10b8 == 0) {
		return 5;
	}
	if (generator_mode_0x10b8 == 1) {
		return 6;
	}
	return 7;
}

void append_angle_candidates_4a17f5(const CoordinateZone4a218c &base, const CoordinateZone4a218c &current, const std::vector<CoordinateZone4a218c> &zones, const std::vector<int32_t> &placed_positions, std::vector<CoordinateCandidate4a17f5> &candidates) {
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
		CoordinateCandidate4a17f5 candidate;
		candidate.x = int32_t(std::trunc(double(combined_size) * X_TABLE[direction] + double(base.x)));
		candidate.y = int32_t(std::trunc(double(combined_size) * Y_TABLE[direction] + double(base.y)));
		candidate.level = base.level;
		if (coordinate_candidate_valid_4a1701(current, candidate, zones, placed_positions)) {
			candidates.push_back(candidate);
		}
	}
}

void prune_candidates_4a1ad8_single_level(const CoordinateZone4a218c &current_template, int32_t current_position, const std::vector<CoordinateZone4a218c> &zones, const std::vector<int32_t> &placed_positions, const std::vector<RuntimeLinkSeedInput4a218c> &links, int32_t coordinate_prune_span_budget, std::vector<CoordinateCandidate4a17f5> &candidates) {
	if (candidates.empty()) {
		return;
	}
	int32_t best_link_count = 0;
	for (const CoordinateCandidate4a17f5 &candidate : candidates) {
		CoordinateZone4a218c candidate_zone = current_template;
		candidate_zone.x = candidate.x;
		candidate_zone.y = candidate.y;
		candidate_zone.level = candidate.level;
		best_link_count = std::max(best_link_count, coordinate_link_acceptance_count_4a1967(candidate_zone, zones, links));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordinateCandidate4a17f5 &candidate) {
		CoordinateZone4a218c candidate_zone = current_template;
		candidate_zone.x = candidate.x;
		candidate_zone.y = candidate.y;
		candidate_zone.level = candidate.level;
		return coordinate_link_acceptance_count_4a1967(candidate_zone, zones, links) < best_link_count;
	}), candidates.end());
	if (candidates.empty()) {
		return;
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const int32_t other_position : placed_positions) {
		if (other_position < 0 || other_position >= int32_t(zones.size()) || other_position == current_position) {
			continue;
		}
		const CoordinateZone4a218c &other = zones[size_t(other_position)];
		min_y = std::min(other.y - other.source_base_size, min_y);
		min_x = std::min(other.x - other.source_base_size, min_x);
		max_y = std::max(other.y + other.source_base_size + 1, max_y);
		max_x = std::max(other.x + other.source_base_size + 1, max_x);
	}

	auto candidate_span_metric = [&](const CoordinateCandidate4a17f5 &candidate) {
		const int32_t candidate_min_y = std::min(candidate.y - current_template.source_base_size, min_y);
		const int32_t candidate_min_x = std::min(candidate.x - current_template.source_base_size, min_x);
		const int32_t candidate_max_y = std::max(candidate.y + current_template.source_base_size + 1, max_y);
		const int32_t candidate_max_x = std::max(candidate.x + current_template.source_base_size + 1, max_x);
		const int32_t height = candidate_max_y - candidate_min_y;
		const int32_t width = candidate_max_x - candidate_min_x;
		return std::max(coordinate_prune_span_budget, std::max(height, width));
	};

	int32_t best_metric = 0x7d00;
	for (const CoordinateCandidate4a17f5 &candidate : candidates) {
		best_metric = std::min(best_metric, candidate_span_metric(candidate));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordinateCandidate4a17f5 &candidate) {
		const int32_t metric = candidate_span_metric(candidate);
		return best_metric < metric;
	}), candidates.end());
}

void write_line_cell_4a261a(BoundaryLineWriteResult &result, int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t x, int32_t y, int32_t zone_id, int32_t level, bool allow_reserved_flag = true) {
	if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
		result.out_of_bounds_write_count += 1;
		return;
	}
	BoundaryLineCellWrite write;
	write.x = x;
	write.y = y;
	write.level = level;
	write.zone_id = zone_id & 0xff;
	write.reserved = allow_reserved_flag && !(generator_mode_0x10b8 == 2 && level != 1);
	result.trace.push_back(write);
	const int64_t key = generated_cell_flat_key_4a325d(width, height, x, y, level);
	result.unique_cells[key] = true;
}

void push_span_4a325d(std::vector<SpanRecord> &pending, const SpanRecord &span, SpanFillResult &result) {
	pending.push_back(span);
	result.pushed_span_count += 1;
	result.max_pending_span_count = std::max<int32_t>(result.max_pending_span_count, int32_t(pending.size()));
}

void merge_boundary_line_4a2777(const BoundaryLineWriteResult &line, std::map<int64_t, bool> &unique_cells, BoundaryMaterialization4a2777 &result) {
	for (const auto &item : line.unique_cells) {
		unique_cells[item.first] = true;
	}
	result.trace_write_count += int32_t(line.trace.size());
	result.out_of_bounds_write_count += line.out_of_bounds_write_count;
}

} // namespace

int32_t H3MapedRng::next() {
	state = state * 0x343fdu + 0x269ec3u;
	return int32_t((state >> 16U) & 0x7fffu);
}

GeneratorSetupModeResult49ecf2 generator_setup_mode_49ecf2(uint32_t seed, int32_t setup_object_0x44) {
	GeneratorSetupModeResult49ecf2 result;
	result.setup_object_0x44 = setup_object_0x44;
	result.generator_mode_0x10b8 = setup_object_0x44;
	result.rng_state_before_setup = seed;
	result.rng_state_before_template_selection = seed;
	if (setup_object_0x44 == 3) {
		H3MapedRng rng;
		rng.state = seed;
		result.setup_rng_value = rng.next();
		result.setup_rng_call_count = 1;
		result.generator_mode_0x10b8 = result.setup_rng_value % 3;
		result.randomized_setup_sentinel_3 = true;
		result.rng_state_before_template_selection = rng.state;
	}
	return result;
}

int32_t map_width_for_size_class(const std::string &size_class) {
	if (size_class == "homm3_medium" || size_class == "medium") {
		return 72;
	}
	if (size_class == "homm3_small" || size_class == "small") {
		return 36;
	}
	return 0;
}

int32_t water_mode_code(const std::string &water_mode) {
	if (water_mode == "normal_water") {
		return 1;
	}
	if (water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(int32_t width, int32_t height, int32_t level_count, int32_t water_code) {
	int32_t score = int32_t((int64_t(std::max(1, width)) * int64_t(std::max(1, height)) * int64_t(std::max(1, level_count))) / 0x510);
	if (water_code == 2) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool supports_one_level_land_scope(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class) {
	if (level_count != 1 || water_mode != "land" || width != height) {
		return false;
	}
	const int32_t expected_width = map_width_for_size_class(size_class);
	return expected_width > 0 && width == expected_width;
}

std::string strict_scope_id(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class) {
	if (supports_one_level_land_scope(width, height, level_count, water_mode, size_class)) {
		const int32_t expected_width = map_width_for_size_class(size_class);
		if (expected_width == 36) {
			return "strict_small_36x36_one_level_land_only";
		}
		if (expected_width == 72) {
			return "strict_medium_72x72_one_level_land_only";
		}
	}
	return "unsupported_h3maped_scope";
}

std::string strict_scope_label(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class) {
	if (supports_one_level_land_scope(width, height, level_count, water_mode, size_class)) {
		const int32_t expected_width = map_width_for_size_class(size_class);
		if (expected_width == 36) {
			return "small_36x36_surface_land_only";
		}
		if (expected_width == 72) {
			return "medium_72x72_surface_land_only";
		}
	}
	return "unsupported_scope";
}

SourceObjectMaskLaneResult4af89f source_object_mask_lane_selector_0x4af89f(const SourceObjectRecord0x4c &record) {
	SourceObjectMaskLaneResult4af89f result;
	result.mask_word_0x18 = uint32_t(record.terrain_mask_b_0x18);
	for (int32_t lane = 0; lane < 9; ++lane) {
		result.scanned_lane_count += 1;
		const uint32_t bit = uint32_t(1U) << uint32_t(lane);
		if ((result.mask_word_0x18 & bit) != 0U) {
			result.selected_lane = lane;
			result.selected_by_mask = true;
			return result;
		}
	}
	result.selected_lane = 9;
	return result;
}

SourceObjectSelectorResult4a9e40 source_object_wrapper_selector_0x4a9e40(uint32_t rng_state, int32_t requested_lane, int32_t bucket_index_0x08, int32_t requested_source_field_0x20) {
	SourceObjectSelectorResult4a9e40 result;
	result.requested_lane = requested_lane;
	result.requested_bucket_index_0x08 = bucket_index_0x08;
	result.requested_source_field_0x20 = requested_source_field_0x20;
	result.rng_state_before = rng_state;
	result.rng_state_after = rng_state;

	SourceObjectWrapperBucket0xe8 bucket;
	if (!source_object_wrapper_bucket_by_index_0x49db76(bucket_index_0x08, bucket)) {
		return result;
	}
	result.bucket_found = true;

	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	for (const int32_t source_index : bucket.source_record_indices) {
		if (source_index < 0 || source_index >= int32_t(records.size())) {
			continue;
		}
		result.scanned_record_count += 1;
		const SourceObjectRecord0x4c &record = records[size_t(source_index)];
		if (record.subtype_0x20 != requested_source_field_0x20) {
			result.source_0x20_reject_count += 1;
			continue;
		}

		bool accepted = false;
		if (record.group_0x24 == 4 || record.group_0x24 == 5) {
			accepted = requested_lane != 8;
			if (!accepted) {
				result.group_lane8_reject_count += 1;
			}
		} else {
			const uint32_t mask_word = uint32_t(record.terrain_mask_b_0x18);
			const bool lane_in_word = requested_lane >= 0 && requested_lane < 32;
			const uint32_t bit = lane_in_word ? (uint32_t(1U) << uint32_t(requested_lane)) : 0U;
			accepted = lane_in_word && (mask_word & bit) != 0U;
			if (!accepted) {
				result.mask_reject_count += 1;
			}
		}
		if (accepted) {
			result.accepted_source_record_indices.push_back(source_index);
		}
	}

	result.accepted_count = int32_t(result.accepted_source_record_indices.size());
	if (result.accepted_count <= 0) {
		return result;
	}

	H3MapedRng rng;
	rng.state = rng_state;
	result.rng_value = rng.next();
	result.rng_state_after = rng.state;
	result.rng_consumed = true;
	result.selected_candidate_index = result.rng_value % result.accepted_count;
	result.selected_source_record_index = result.accepted_source_record_indices[size_t(result.selected_candidate_index)];
	const SourceObjectRecord0x4c &selected = records[size_t(result.selected_source_record_index)];
	result.selected = true;
	result.selected_type_id_0x1c = selected.type_id_0x1c;
	result.selected_subtype_0x20 = selected.subtype_0x20;
	result.selected_group_0x24 = selected.group_0x24;
	result.selected_def_name = selected.def_name;
	return result;
}

bool same_source_object_record_0x4c(const SourceObjectRecord0x4c &left, const SourceObjectRecord0x4c &right) {
	return left.source_row == right.source_row
			&& left.source == right.source
			&& left.def_name == right.def_name
			&& left.type_id_0x1c == right.type_id_0x1c
			&& left.type_name == right.type_name
			&& left.metadata_bucket_index_0x08 == right.metadata_bucket_index_0x08
			&& left.subtype_0x20 == right.subtype_0x20
			&& left.group_0x24 == right.group_0x24
			&& left.last_flag_0x28 == right.last_flag_0x28
			&& left.raw_field_0x20_known == right.raw_field_0x20_known
			&& left.raw_field_0x20 == right.raw_field_0x20
			&& left.raw_field_0x24_known == right.raw_field_0x24_known
			&& left.raw_field_0x24 == right.raw_field_0x24
			&& left.raw_field_0x28_known == right.raw_field_0x28_known
			&& left.raw_field_0x28 == right.raw_field_0x28
			&& left.raw_field_0x2c_known == right.raw_field_0x2c_known
			&& left.raw_field_0x2c == right.raw_field_0x2c
			&& left.raw_field_0x30_known == right.raw_field_0x30_known
			&& left.raw_field_0x30 == right.raw_field_0x30
			&& left.raw_field_0x34_known == right.raw_field_0x34_known
			&& left.raw_field_0x34 == right.raw_field_0x34
			&& left.raw_field_0x38_known == right.raw_field_0x38_known
			&& left.raw_field_0x38 == right.raw_field_0x38
			&& left.pass_count == right.pass_count
			&& left.action_count == right.action_count
			&& left.passability_mask == right.passability_mask
			&& left.action_mask == right.action_mask
			&& left.terrain_mask_a_0x14 == right.terrain_mask_a_0x14
			&& left.terrain_mask_b_0x18 == right.terrain_mask_b_0x18
			&& left.descriptor_mask_fields_0x34_0x48_known == right.descriptor_mask_fields_0x34_0x48_known
			&& left.descriptor_mask_fields_exact_def_msk == right.descriptor_mask_fields_exact_def_msk
			&& left.descriptor_width_0x34 == right.descriptor_width_0x34
			&& left.descriptor_height_0x38 == right.descriptor_height_0x38
			&& left.descriptor_mask_a_0x3c_0x40 == right.descriptor_mask_a_0x3c_0x40
			&& left.descriptor_mask_b_0x44_0x48 == right.descriptor_mask_b_0x44_0x48
			&& left.terrain_a_names == right.terrain_a_names
			&& left.terrain_b_names == right.terrain_b_names
			&& left.rand_trn_backed == right.rand_trn_backed;
}

int32_t source_object_catalog_index_0x49da08(const SourceObjectRecord0x4c &record) {
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	for (int32_t index = 0; index < int32_t(records.size()); ++index) {
		if (same_source_object_record_0x4c(records[size_t(index)], record)) {
			return index;
		}
	}
	return -1;
}

std::vector<SourceObjectMaskPoint490f3f> source_object_text_mask_points_0x490f3f(const std::string &mask_text, bool action_mask) {
	std::vector<SourceObjectMaskPoint490f3f> points;
	if (mask_text.size() < 48U) {
		return points;
	}
	for (int32_t row = 0; row < 6; ++row) {
		for (int32_t text_col = 0; text_col < 8; ++text_col) {
			const bool bit_set = mask_text[size_t(row * 8 + text_col)] == '1';
			const bool include = action_mask ? bit_set : !bit_set;
			if (!include) {
				continue;
			}
			points.push_back(SourceObjectMaskPoint490f3f { -text_col, -(5 - row) });
		}
	}
	return points;
}

SourceObjectResolverResult4af785 source_object_descriptor_resolver_0x4af785(SourceObjectResolverState4af785 &state, const SourceObjectRecord0x4c &record) {
	SourceObjectResolverResult4af785 result;
	result.input_source_catalog_index = source_object_catalog_index_0x49da08(record);
	result.input_source_row = record.source_row;
	result.input_def_name = record.def_name;
	result.input_type_id_0x1c = record.type_id_0x1c;
	result.input_subtype_0x20 = record.subtype_0x20;
	result.metadata_bucket_index_0x08 = record.metadata_bucket_index_0x08;
	const SourceObjectMaskLaneResult4af89f lane = source_object_mask_lane_selector_0x4af89f(record);
	result.resolver_lane_0x04 = lane.selected_lane;
	result.source_pair_count_before = int32_t(state.source_pairs_0xedc.size());

	for (const SourceObjectResolvedWrapper4af785 &wrapper : state.wrappers) {
		if (wrapper.metadata_bucket_index_0x08 == result.metadata_bucket_index_0x08) {
			result.bucket_size_before += 1;
		}
	}

	bool prior_wrapper_0x10_known = false;
	int32_t prior_wrapper_0x10 = 0;
	for (const SourceObjectResolvedWrapper4af785 &wrapper : state.wrappers) {
		if (wrapper.metadata_bucket_index_0x08 != result.metadata_bucket_index_0x08) {
			continue;
		}
		result.scanned_bucket_wrapper_count += 1;
		if (wrapper.wrapper_0x04 != result.resolver_lane_0x04) {
			result.lane_reject_count += 1;
			continue;
		}
		if (wrapper.source_record_copy.subtype_0x20 != record.subtype_0x20) {
			result.source_0x20_reject_count += 1;
			continue;
		}
		if (wrapper.wrapper_0x10_known) {
			prior_wrapper_0x10_known = true;
			prior_wrapper_0x10 = wrapper.wrapper_0x10;
		}
		if (same_source_object_record_0x4c(wrapper.source_record_copy, record)) {
			result.reused_existing_wrapper = true;
			result.selected_wrapper_index = wrapper.wrapper_index;
			result.wrapper_0x10_known = wrapper.wrapper_0x10_known;
			result.wrapper_0x10 = wrapper.wrapper_0x10;
			result.bucket_size_after = result.bucket_size_before;
			result.source_pair_count_after = int32_t(state.source_pairs_0xedc.size());
			return result;
		}
		result.source_copy_mismatch_count += 1;
	}

	SourceObjectResolvedWrapper4af785 wrapper;
	wrapper.wrapper_index = state.next_wrapper_index++;
	wrapper.source_catalog_index = result.input_source_catalog_index;
	wrapper.source_record_copy = record;
	wrapper.metadata_bucket_index_0x08 = result.metadata_bucket_index_0x08;
	wrapper.resolver_lane_0x04 = result.resolver_lane_0x04;
	wrapper.wrapper_0x04 = result.resolver_lane_0x04;
	wrapper.wrapper_0x10_known = prior_wrapper_0x10_known;
	wrapper.wrapper_0x10 = prior_wrapper_0x10;
	wrapper.initialized_by_0x49db76 = true;
	wrapper.copied_source_record = true;
	state.wrappers.push_back(wrapper);
	SourceObjectResolverSourcePair4af785 source_pair;
	source_pair.copied_source_catalog_index = wrapper.source_catalog_index;
	source_pair.wrapper_index = wrapper.wrapper_index;
	source_pair.source_record_pointer_0x00_carried = true;
	source_pair.source_record_copy = wrapper.source_record_copy;
	source_pair.source_lane_0x1c = wrapper.source_record_copy.type_id_0x1c;
	source_pair.context_pointer_0x04_carried = true;
	source_pair.context_wrapper_copy = wrapper;
	source_pair.context_wrapper_index_0x04 = wrapper.wrapper_index;
	source_pair.context_wrapper_lane_0x04 = wrapper.wrapper_0x04;
	source_pair.context_wrapper_0x10_known = wrapper.wrapper_0x10_known;
	source_pair.context_wrapper_0x10 = wrapper.wrapper_0x10;
	state.source_pairs_0xedc.push_back(source_pair);

	result.created_new_wrapper = true;
	result.selected_wrapper_index = wrapper.wrapper_index;
	result.bucket_size_after = result.bucket_size_before + 1;
	result.source_pair_count_after = int32_t(state.source_pairs_0xedc.size());
	result.appended_source_pair_0xedc = true;
	result.appended_wrapper_to_bucket = true;
	result.copied_source_record = true;
	result.wrapper_0x10_known = wrapper.wrapper_0x10_known;
	result.wrapper_0x10 = wrapper.wrapper_0x10;
	return result;
}

void preserve_source_pair_vector_edc(GeneratorObjectPrivateState &state, const SourceObjectResolverState4af785 &resolver_state) {
	state.source_pair_vector_edc.present = true;
	state.source_pair_vector_edc.contents_known = true;
	state.source_pair_vector_edc.count_known = true;
	state.source_pair_vector_edc.count = int32_t(resolver_state.source_pairs_0xedc.size());
	state.source_pair_vector_edc.element_size_bytes = 8;
	state.source_pair_records_edc = resolver_state.source_pairs_0xedc;
}

bool recovered_descriptor_join_context_0x4903e8(int32_t target_context) {
	return target_context == 45
			|| target_context == 53
			|| target_context == 54
			|| target_context == 79;
}

static bool descriptor_only_source_identity_is_ambiguous(const SourceObjectRecord0x4c &record) {
	const std::vector<SourceObjectRecord0x4c> matching_records =
			source_object_records_by_type_subtype_0x49da08(record.type_id_0x1c, record.subtype_0x20);
	return matching_records.size() > 1;
}

SourceObjectDescriptorJoinResult4903e8 source_object_descriptor_join_0x4903e8(SourceObjectResolverState4af785 &state, const SourceObjectDescriptor4903e8 &descriptor, const SourceObjectRecord0x4c &selected_source_record) {
	SourceObjectDescriptorJoinResult4903e8 result;
	result.descriptor = descriptor;
	result.source_record_copy = selected_source_record;
	result.source_catalog_index_0x49da08 = source_object_catalog_index_0x49da08(selected_source_record);
	const int32_t target_context = descriptor.target_context_0x4903e8 >= 0 ? descriptor.target_context_0x4903e8 : descriptor.descriptor_type_0x1c;
	result.recovered_target_context = recovered_descriptor_join_context_0x4903e8(target_context);
	result.descriptor_type_matches_source_type_0x1c = descriptor.descriptor_type_0x1c == selected_source_record.type_id_0x1c;
	result.descriptor_subtype_matches_source_0x20 = descriptor.subtype_0x20 == selected_source_record.subtype_0x20;
	result.descriptor_group_matches_source_0x24 = descriptor.group_0x24 == selected_source_record.group_0x24;
	result.descriptor_mask_fields_match_source_0x34_0x48 =
			!descriptor.descriptor_mask_fields_0x34_0x48_known
			|| !selected_source_record.descriptor_mask_fields_0x34_0x48_known
			|| (descriptor.descriptor_width_0x34 == selected_source_record.descriptor_width_0x34
					&& descriptor.descriptor_height_0x38 == selected_source_record.descriptor_height_0x38
					&& descriptor.descriptor_mask_a_0x3c_0x40 == selected_source_record.descriptor_mask_a_0x3c_0x40
					&& descriptor.descriptor_mask_b_0x44_0x48 == selected_source_record.descriptor_mask_b_0x44_0x48);
	result.descriptor_source_fields_match = result.descriptor_type_matches_source_type_0x1c
			&& result.descriptor_subtype_matches_source_0x20
			&& result.descriptor_group_matches_source_0x24
			&& result.descriptor_mask_fields_match_source_0x34_0x48;
	result.descriptor_source_key_is_not_source_row_id = descriptor.source_key_0x00 != selected_source_record.source_row;
	result.descriptor_only_identity_ambiguous = descriptor_only_source_identity_is_ambiguous(selected_source_record);

	if (!result.recovered_target_context) {
		result.blocked_reason = "0x4903e8_target_context_unrecovered_for_descriptor_source_join";
		return result;
	}
	if (result.source_catalog_index_0x49da08 < 0) {
		result.blocked_reason = "selected_copied_source_record_not_found_in_0x49da08_catalog";
		return result;
	}
	if (!result.descriptor_source_fields_match) {
		result.blocked_reason = "0x4903e8_descriptor_fields_do_not_match_selected_0x4c_source_record";
		return result;
	}

	result.resolver_0x4af785 = source_object_descriptor_resolver_0x4af785(state, selected_source_record);
	result.resolver_invoked_0x4af785 = true;
	result.copied_source_record_is_identity_authority = true;
	result.joined = result.resolver_0x4af785.reused_existing_wrapper
			|| result.resolver_0x4af785.created_new_wrapper;
	if (!result.joined) {
		result.blocked_reason = "0x4af785_resolver_did_not_resolve_or_create_source_wrapper";
	}
	return result;
}

ObjectMaterializationPrep4a8db2_4a901a object_materialization_prep_from_descriptor_join_0x4a8db2_0x4a901a(const SourceObjectDescriptorJoinResult4903e8 &join, uint32_t object_record_key, bool object_record_key_known, int32_t x, int32_t y, int32_t level) {
	ObjectMaterializationPrep4a8db2_4a901a prep;
	prep.descriptor_join_0x4903e8 = join;
	prep.descriptor_joined = join.joined;
	prep.copied_source_record_carried = join.copied_source_record_is_identity_authority;
	prep.source_catalog_index_0x49da08 = join.source_catalog_index_0x49da08;
	prep.source_record_copy = join.source_record_copy;
	prep.selected_wrapper_index_0x4af785 = join.resolver_0x4af785.selected_wrapper_index;
	prep.object_record_key_known = object_record_key_known;
	prep.object_record_key = object_record_key;
	prep.x = x;
	prep.y = y;
	prep.level = level;

	if (!join.joined) {
		prep.blocked_reason = join.blocked_reason.empty()
				? "0x4903e8_descriptor_source_join_not_resolved"
				: join.blocked_reason;
		return prep;
	}
	if (!object_record_key_known) {
		prep.blocked_reason = "0x4a8d2c_0x4a8db2_0x4a93a2_0x4a901a_object_record_key_caller_unported";
		return prep;
	}
	prep.ready_for_object_vector_commit_0x4a54a7 = true;
	return prep;
}

ObjectMaterializationPrep4a8db2_4a901a object_materialization_prep_from_weighted_record_0x4a93a2_0x4a901a(const SourceObjectDescriptorJoinResult4903e8 &join, const WeightedObjectRecord4a93a2 &record) {
	ObjectMaterializationPrep4a8db2_4a901a prep;
	prep.descriptor_join_0x4903e8 = join;
	prep.descriptor_joined = join.joined;
	prep.copied_source_record_carried = join.copied_source_record_is_identity_authority;
	prep.source_catalog_index_0x49da08 = join.source_catalog_index_0x49da08;
	prep.source_record_copy = join.source_record_copy;
	prep.selected_wrapper_index_0x4af785 = join.resolver_0x4af785.selected_wrapper_index;

	if (record.object_record_vtable_0x00 != WEIGHTED_OBJECT_RECORD_VTABLE_0X540A9C) {
		prep.blocked_reason = "0x4a93a2_weighted_record_vtable_not_0x540a9c";
		return prep;
	}
	if (!record.coordinate_payload_filled_before_0x4a901a) {
		prep.blocked_reason = "0x4a93a2_weighted_record_coordinate_payload_not_filled";
		return prep;
	}

	const bool source_backed_type98_bridge = !join.joined
			&& join.descriptor.descriptor_type_0x1c == 98
			&& join.descriptor_source_fields_match
			&& join.source_catalog_index_0x49da08 >= 0;
	if (!join.joined && !source_backed_type98_bridge) {
		prep.blocked_reason = join.blocked_reason.empty()
				? "0x4a93a2_weighted_descriptor_source_bridge_unresolved"
				: join.blocked_reason;
		return prep;
	}
	if (source_backed_type98_bridge) {
		prep.copied_source_record_carried = true;
		prep.weighted_type98_descriptor_bridge_0x4a93a2_known = true;
	}
	if (!record.object_record_key_known) {
		prep.blocked_reason = "0x4a8d2c_0x4a8db2_0x4a93a2_0x4a901a_object_record_key_caller_unported";
		return prep;
	}

	prep.object_record_key_known = true;
	prep.object_record_key = record.object_record_key;
	prep.x = record.x;
	prep.y = record.y;
	prep.level = record.level;
	prep.ready_for_object_vector_commit_0x4a54a7 = true;
	return prep;
}

WeightedSchedulerThreshold4a8db2 weighted_scheduler_threshold_0x4a8db2(const SourceZonePayload4a218c &source_payload) {
	WeightedSchedulerThreshold4a8db2 result;
	result.source_density_fields_known = true;
	result.player_castle_density_0x2c = source_payload.player_towns.castle_density;
	result.player_town_density_0x28 = source_payload.player_towns.town_density;
	result.neutral_castle_density_0x3c = source_payload.neutral_towns.castle_density;
	result.neutral_town_density_0x38 = source_payload.neutral_towns.town_density;

	const int32_t densities[] = {
		result.player_castle_density_0x2c,
		result.player_town_density_0x28,
		result.neutral_castle_density_0x3c,
		result.neutral_town_density_0x38,
	};
	for (const int32_t density : densities) {
		if (density > 0) {
			result.positive_density_sum += density;
		}
	}
	if (result.positive_density_sum <= 0) {
		result.blocked_reason = "0x4a8db2_weighted_scheduler_no_positive_town_castle_density";
		return result;
	}

	const int32_t quotient = 0x14400 / result.positive_density_sum;
	int32_t threshold = int32_t(std::sqrt(double(quotient)));
	while (int64_t(threshold + 1) * int64_t(threshold + 1) <= quotient) {
		++threshold;
	}
	while (int64_t(threshold) * int64_t(threshold) > quotient) {
		--threshold;
	}
	result.threshold_arg_0x18_known = true;
	result.threshold_arg_0x18 = threshold;
	return result;
}

GeneratedCellInitialWords generated_cell_initializer_0x499ea3(uint32_t old_word_0x24, uint32_t old_word_0x28, uint32_t old_word_0x2c) {
	GeneratedCellInitialWords cell;
	cell.word_0x10 = GENERATED_CELL_INITIAL_WORD_0X10;
	cell.word_0x1c = GENERATED_CELL_INITIAL_WORD_0X1C;
	cell.word_0x20 = GENERATED_CELL_INITIAL_WORD_0X20;
	cell.word_0x24 = (old_word_0x24 & GENERATED_CELL_INITIAL_WORD_0X24_MASK) | GENERATED_CELL_INITIAL_WORD_0X24_VALUE;
	cell.word_0x28 = (old_word_0x28 & GENERATED_CELL_INITIAL_WORD_0X28_PRESERVED_MASK) | GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
	cell.word_0x2c = old_word_0x2c & GENERATED_CELL_INITIAL_WORD_0X2C_CLEAR_MASK;
	return cell;
}

GeneratedCellRecordGrid0x30 generated_cell_record_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count) {
	GeneratedCellRecordGrid0x30 grid;
	grid.width = width;
	grid.height = height;
	grid.level_count = level_count;
	grid.stride_bytes = GENERATED_CELL_RECORD_STRIDE_BYTES;
	if (width <= 0 || height <= 0 || level_count <= 0) {
		return grid;
	}
	const int64_t cell_count = int64_t(width) * int64_t(height) * int64_t(level_count);
	if (cell_count <= 0) {
		return grid;
	}
	const GeneratedCellInitialWords initial = generated_cell_initializer_0x499ea3();
	grid.records.assign(size_t(cell_count), GeneratedCellRecord0x30());
	for (GeneratedCellRecord0x30 &record : grid.records) {
		record.stride_bytes = GENERATED_CELL_RECORD_STRIDE_BYTES;
		record.object_reference_vector_fields_0x04_0x08_present = true;
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x10_known = true;
		record.word_0x10 = initial.word_0x10;
		record.word_0x14_known = false;
		record.word_0x14 = 0U;
		record.word_0x18_known = false;
		record.word_0x18 = 0U;
		record.word_0x1c_known = true;
		record.word_0x1c = initial.word_0x1c;
		record.word_0x20_known = true;
		record.word_0x20 = initial.word_0x20;
		record.word_0x24_known = true;
		record.word_0x24 = initial.word_0x24;
		record.word_0x28_known = true;
		record.word_0x28 = initial.word_0x28;
		record.byte_0x2b_known = false;
		record.byte_0x2b_known_mask = 0U;
		record.byte_0x2b = 0U;
		record.word_0x2c_known = true;
		record.word_0x2c = initial.word_0x2c;
	}
	return grid;
}

GeneratedCellWordGrid generated_cell_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count) {
	GeneratedCellWordGrid grid;
	grid.width = width;
	grid.height = height;
	grid.level_count = level_count;
	if (width <= 0 || height <= 0 || level_count <= 0) {
		return grid;
	}
	const int64_t cell_count = int64_t(width) * int64_t(height) * int64_t(level_count);
	if (cell_count < 0) {
		return grid;
	}
	const GeneratedCellRecordGrid0x30 records = generated_cell_record_grid_reset_0x49a072(width, height, level_count);
	grid.word_0x10.reserve(size_t(cell_count));
	grid.word_0x1c.reserve(size_t(cell_count));
	grid.word_0x20.reserve(size_t(cell_count));
	grid.word_0x24.reserve(size_t(cell_count));
	grid.word_0x28.reserve(size_t(cell_count));
	grid.word_0x2c.reserve(size_t(cell_count));
	for (const GeneratedCellRecord0x30 &record : records.records) {
		grid.word_0x10.push_back(record.word_0x10);
		grid.word_0x1c.push_back(record.word_0x1c);
		grid.word_0x20.push_back(record.word_0x20);
		grid.word_0x24.push_back(record.word_0x24);
		grid.word_0x28.push_back(record.word_0x28);
		grid.word_0x2c.push_back(record.word_0x2c);
	}
	return grid;
}

void generated_cell_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count, std::vector<uint32_t> &word_0x20, std::vector<uint32_t> &word_0x24, std::vector<uint32_t> &word_0x28, std::vector<uint32_t> &word_0x2c) {
	const GeneratedCellWordGrid grid = generated_cell_grid_reset_0x49a072(width, height, level_count);
	word_0x20 = grid.word_0x20;
	word_0x24 = grid.word_0x24;
	word_0x28 = grid.word_0x28;
	word_0x2c = grid.word_0x2c;
}

int64_t cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0) {
		return -1;
	}
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

int64_t generated_cell_flat_key_4a325d(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

uint32_t generated_cell_zone_word_4a325d(uint32_t existing_word, int32_t zone_id) {
	return (existing_word & 0xff00ffffU) | (uint32_t(zone_id & 0xff) << 16U);
}

void generated_cell_apply_owner_word_4a2777(std::vector<uint32_t> &private_zone_words, std::vector<uint32_t> &generated_cell_word_0x20, int64_t key, int32_t zone_id) {
	if (key < 0 || key >= int64_t(private_zone_words.size())) {
		return;
	}
	private_zone_words[size_t(key)] = generated_cell_zone_word_4a325d(private_zone_words[size_t(key)], zone_id);
	if (key < int64_t(generated_cell_word_0x20.size())) {
		generated_cell_word_0x20[size_t(key)] = generated_cell_zone_word_4a325d(generated_cell_word_0x20[size_t(key)], zone_id);
	}
}

uint32_t generated_cell_word20_set_low_word(uint32_t word_0x20, uint32_t low_word) {
	return (word_0x20 & 0xffff0000U) | (low_word & 0x0000ffffU);
}

uint32_t generated_cell_4a54a7_endpoint_word28(uint32_t word_0x28) {
	return word_0x28 | CELL_ACTION_CONTROL_BIT_22 | CELL_OCCUPIED_BLOCKED_BIT_27;
}

uint32_t generated_cell_4aa3e9_reward_word28(uint32_t word_0x28) {
	return word_0x28 & ~CELL_DECOR_READY_BIT_25;
}

uint32_t generated_cell_49cf34_attach_word28(uint32_t word_0x28) {
	return (word_0x28 | CELL_OCCUPIED_BLOCKED_BIT_27) & ~CELL_DECOR_CANDIDATE_BIT_26;
}

uint32_t generated_cell_4a56b6_projection_word20(uint32_t word_0x20, uint32_t lowered_low_word) {
	return generated_cell_word20_set_low_word(word_0x20, lowered_low_word);
}

uint32_t generated_cell_49acf6_word24(uint32_t word_0x24, int32_t terrain_arg, int32_t art_arg) {
	return (word_0x24 & 0xffffc000U)
			| (uint32_t(terrain_arg) & 0x3fU)
			| ((uint32_t(art_arg) & 0xffU) << 6U);
}

uint32_t generated_cell_49acf6_word28(uint32_t word_0x28, int32_t flag_a, int32_t flag_b) {
	return (word_0x28 & ~CELL_TERRAIN_FLAG_MASK_0X49ACF6)
			| generated_cell_terrain_flags_0x49acf6(flag_a, flag_b);
}

uint32_t generated_cell_terrain_flags_0x49acf6(int32_t flag_a, int32_t flag_b) {
	return (((uint32_t(flag_a) & 0x01U) | ((uint32_t(flag_b) & 0x01U) << 1U)) << CELL_TERRAIN_FLAG_SHIFT_0X49ACF6);
}

uint32_t generated_cell_4a59e2_pack_word_0x1c(uint32_t word_0x1c, uint32_t arg_word_0x1c_high) {
	return (word_0x1c & 0x0000ffffU) | ((arg_word_0x1c_high & 0xffffU) << 16U);
}

uint32_t generated_cell_4a59e2_pack_word_0x20(uint32_t word_0x20, uint32_t arg_byte3) {
	return (word_0x20 & 0x00ffffffU) | ((arg_byte3 & 0xffU) << 24U);
}

uint32_t generated_cell_4a59e2_pack_word_0x28(uint32_t word_0x28, uint32_t arg_bits_12_14) {
	return (word_0x28 & ~RELATION_WORD_0X28_BITS_12_14_MASK)
			| ((arg_bits_12_14 & 0x7U) << 12U);
}

uint32_t generated_cell_4a5767_reset_force_word_0x1c(uint32_t word_0x1c_after_4a59e2) {
	return (word_0x1c_after_4a59e2 & 0xffff0000U)
			| (((word_0x1c_after_4a59e2 & 0x0000ffffU) & 0x7d00U) | 0x7d00U);
}

uint32_t generated_cell_49a318_clear_source_word_0x1c(uint32_t word_0x1c) {
	return word_0x1c & 0xffff0000U;
}

RelationResetCell generated_cell_4a5767_reset_cell(uint32_t source_word_0x20, uint32_t source_word_0x28) {
	RelationResetCell cell;
	cell.word_0x1c = generated_cell_4a59e2_pack_word_0x1c(0U, RELATION_RESET_ARG_0X4A59E2_WORD_0X1C_HIGH);
	cell.word_0x1c = generated_cell_4a5767_reset_force_word_0x1c(cell.word_0x1c);
	cell.word_0x20 = generated_cell_4a59e2_pack_word_0x20(source_word_0x20, RELATION_RESET_ARG_0X4A59E2_WORD_0X20_BYTE3);
	cell.word_0x28 = generated_cell_4a59e2_pack_word_0x28(source_word_0x28, RELATION_RESET_ARG_0X4A59E2_BITS_12_14);
	return cell;
}

bool generated_cell_4a5767_reset_projection(GeneratedCellRecord0x30 &record) {
	if (!record.word_0x20_known || !record.word_0x28_known) {
		return false;
	}
	const RelationResetCell reset = generated_cell_4a5767_reset_cell(record.word_0x20, record.word_0x28);
	const bool changed = !record.word_0x10_known || record.word_0x10 != reset.word_0x10
			|| !record.word_0x14_known || record.word_0x14 != reset.word_0x14
			|| !record.word_0x18_known || record.word_0x18 != reset.word_0x18
			|| !record.word_0x1c_known || record.word_0x1c != reset.word_0x1c
			|| !record.word_0x20_known || record.word_0x20 != reset.word_0x20
			|| !record.word_0x28_known || record.word_0x28 != reset.word_0x28;
	record.word_0x10_known = true;
	record.word_0x10 = reset.word_0x10;
	record.word_0x14_known = true;
	record.word_0x14 = reset.word_0x14;
	record.word_0x18_known = true;
	record.word_0x18 = reset.word_0x18;
	record.word_0x1c_known = true;
	record.word_0x1c = reset.word_0x1c;
	record.word_0x20_known = true;
	record.word_0x20 = reset.word_0x20;
	record.word_0x28_known = true;
	record.word_0x28 = reset.word_0x28;
	return changed;
}

bool generated_cell_49a318_clear_source_projection(GeneratedCellRecord0x30 &record) {
	if (!record.word_0x1c_known) {
		return false;
	}
	const uint32_t cleared_word_0x1c = generated_cell_49a318_clear_source_word_0x1c(record.word_0x1c);
	const bool changed = record.word_0x1c != cleared_word_0x1c
			|| !record.word_0x10_known || record.word_0x10 != RELATION_RESET_COORD_MINUS_ONE
			|| !record.word_0x14_known || record.word_0x14 != RELATION_RESET_COORD_MINUS_ONE
			|| !record.word_0x18_known || record.word_0x18 != RELATION_RESET_COORD_MINUS_ONE;
	record.word_0x1c = cleared_word_0x1c;
	record.word_0x10_known = true;
	record.word_0x10 = RELATION_RESET_COORD_MINUS_ONE;
	record.word_0x14_known = true;
	record.word_0x14 = RELATION_RESET_COORD_MINUS_ONE;
	record.word_0x18_known = true;
	record.word_0x18 = RELATION_RESET_COORD_MINUS_ONE;
	return changed;
}

static uint32_t generated_cell_word20_set_owner_byte3_49a318(uint32_t word_0x20, int32_t owner_byte) {
	return (word_0x20 & 0x00ffffffU) | ((uint32_t(owner_byte) & 0xffU) << 24U);
}

static uint32_t generated_cell_word1c_set_low_word_49a318(uint32_t word_0x1c, int32_t low_word) {
	return (word_0x1c & 0xffff0000U) | (uint32_t(low_word) & 0x0000ffffU);
}

static uint32_t generated_cell_word1c_set_high_word_49a318(uint32_t word_0x1c, int32_t high_word) {
	return (word_0x1c & 0x0000ffffU) | ((uint32_t(high_word) & 0x0000ffffU) << 16U);
}

static uint32_t generated_cell_word28_set_direction_49a318(uint32_t word_0x28, int32_t direction_ordinal) {
	return generated_cell_4a59e2_pack_word_0x28(word_0x28, uint32_t(direction_ordinal));
}

static int32_t generated_cell_terrain_code_0x24(const GeneratedCellRecord0x30 &record) {
	return record.word_0x24_known ? int32_t(record.word_0x24 & 0x3fU) : 9;
}

static bool generated_cell_relation_member_49a318(const GeneratedCellRecord0x30 &record) {
	return record.word_0x28_known && (record.word_0x28 & CELL_DECOR_READY_BIT_25) != 0U;
}

static bool int_table_contains_49a318(const int32_t *values, int32_t count, int32_t value) {
	for (int32_t index = 0; index < count; ++index) {
		if (values[index] == value) {
			return true;
		}
	}
	return false;
}

bool object_metadata_flag_0x598300(int32_t object_type_id, int32_t metadata_offset) {
	static constexpr int32_t METADATA_FIELD_PLUS_0_TYPES_0X52FD78[] = {
		3, 5, 6, 8, 9, 11, 12, 22, 26, 29, 34, 36, 52, 54,
		59, 62, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75,
		76, 79, 81, 82, 85, 86, 92, 93, 95, 101, 162, 163,
		164, 214, 215
	};
	static constexpr int32_t METADATA_FIELD_PLUS_1_TYPES_0X52FE20[] = {
		3, 5, 6, 8, 9, 11, 12, 22, 26, 29, 33, 34, 36, 54,
		59, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 162,
		163, 164, 76, 79, 81, 82, 85, 86, 93, 101, 111, 212,
		214, 215, 219
	};
	static constexpr int32_t METADATA_FIELD_PLUS_2_TYPES_0X52FCF0[] = {
		5, 6, 9, 12, 26, 29, 34, 54, 59, 62, 65, 66, 67, 68,
		69, 70, 71, 72, 73, 74, 75, 162, 163, 164, 76, 79, 81,
		82, 86, 93, 101, 212, 214, 215
	};
	if (object_type_id < 0 || object_type_id >= SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8) {
		return false;
	}
	if (metadata_offset == 0) {
		return int_table_contains_49a318(METADATA_FIELD_PLUS_0_TYPES_0X52FD78, int32_t(sizeof(METADATA_FIELD_PLUS_0_TYPES_0X52FD78) / sizeof(METADATA_FIELD_PLUS_0_TYPES_0X52FD78[0])), object_type_id);
	}
	if (metadata_offset == 1) {
		return int_table_contains_49a318(METADATA_FIELD_PLUS_1_TYPES_0X52FE20, int32_t(sizeof(METADATA_FIELD_PLUS_1_TYPES_0X52FE20) / sizeof(METADATA_FIELD_PLUS_1_TYPES_0X52FE20[0])), object_type_id);
	}
	if (metadata_offset == 2) {
		return int_table_contains_49a318(METADATA_FIELD_PLUS_2_TYPES_0X52FCF0, int32_t(sizeof(METADATA_FIELD_PLUS_2_TYPES_0X52FCF0) / sizeof(METADATA_FIELD_PLUS_2_TYPES_0X52FCF0[0])), object_type_id);
	}
	return false;
}

static bool generated_cell_descriptor_type_from_object_reference_49a318(const GeneratedCellRecord0x30 &record, const std::vector<ObjectRecordReference4a54a7> *object_records, int32_t &descriptor_type) {
	descriptor_type = -1;
	if (object_records == nullptr || !record.object_reference_vector_contents_known || record.object_references_0x04_0x08.empty()) {
		return false;
	}
	const uint32_t object_record_key = record.object_references_0x04_0x08.front();
	for (const ObjectRecordReference4a54a7 &object_record : *object_records) {
		if (object_record.object_record_key != object_record_key) {
			continue;
		}
		descriptor_type = object_record.descriptor_type_0x1c;
		if (descriptor_type < 0 && object_record.copied_source_record_carried) {
			descriptor_type = object_record.source_record_copy.type_id_0x1c;
		}
		return descriptor_type >= 0;
	}
	return false;
}

static int32_t relation_high_owner_direction_count_49a318(const GeneratedCellRecord0x30 &record, const std::vector<ObjectRecordReference4a54a7> *object_records, RelationHighOwnerPropagationResult49a318 &result, RelationHighOwnerPropagationSeedReport49a318 &report) {
	if (!record.word_0x28_known || (record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) == 0U) {
		return 8;
	}
	int32_t descriptor_type = -1;
	if (!generated_cell_descriptor_type_from_object_reference_49a318(record, object_records, descriptor_type)) {
		report.object_metadata_unresolved_count += 1;
		result.object_metadata_unresolved_count += 1;
		return 0;
	}
	if (!object_metadata_flag_0x598300(descriptor_type, 1)) {
		report.object_metadata_source_reduced_direction_count += 1;
		result.object_metadata_source_reduced_direction_count += 1;
		return 5;
	}
	return 8;
}

static bool relation_high_owner_candidate_allowed_49a318(const GeneratedCellRecord0x30 &record, const std::vector<ObjectRecordReference4a54a7> *object_records, int32_t direction, RelationHighOwnerPropagationResult49a318 &result, RelationHighOwnerPropagationSeedReport49a318 &report) {
	if (!record.word_0x28_known || (record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) == 0U) {
		return true;
	}
	report.object_metadata_candidate_scan_count += 1;
	result.object_metadata_candidate_scan_count += 1;
	int32_t descriptor_type = -1;
	if (!generated_cell_descriptor_type_from_object_reference_49a318(record, object_records, descriptor_type)) {
		report.object_metadata_unresolved_count += 1;
		result.object_metadata_unresolved_count += 1;
		report.object_metadata_candidate_reject_count += 1;
		result.object_metadata_candidate_reject_count += 1;
		return false;
	}
	if (object_metadata_flag_0x598300(descriptor_type, 0) && !object_metadata_flag_0x598300(descriptor_type, 2)) {
		report.object_metadata_candidate_reject_count += 1;
		result.object_metadata_candidate_reject_count += 1;
		return false;
	}
	if (!object_metadata_flag_0x598300(descriptor_type, 1) && direction > 0 && direction < 4) {
		report.object_metadata_candidate_reject_count += 1;
		result.object_metadata_candidate_reject_count += 1;
		return false;
	}
	return true;
}

RelationHighOwnerPropagationResult49a318 relation_high_owner_propagation_49a318(GeneratedCellRecordGrid0x30 &grid, const std::vector<GeneratorRelationOwnerState4a218c> &owners, const std::vector<ObjectRecordReference4a54a7> *object_records) {
	RelationHighOwnerPropagationResult49a318 result;
	result.applied = true;
	const int32_t tile_count = int32_t(grid.records.size());
	result.owner_high_byte_grid.assign(size_t(std::max<int32_t>(0, tile_count)), -1);
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || tile_count <= 0) {
		return result;
	}
	result.grid_available = true;

	struct HighOwnerQueueNode {
		int32_t x = 0;
		int32_t y = 0;
		int32_t level = 0;
		int32_t score = 0;
	};
	static constexpr int32_t DX[8] = { 1, 1, 0, -1, -1, -1, 0, 1 };
	static constexpr int32_t DY[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
	std::vector<int32_t> path_low_word(size_t(tile_count), RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452);
	std::vector<int32_t> path_high_word(size_t(tile_count), RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452);

	for (const GeneratorRelationOwnerState4a218c &owner : owners) {
		RelationHighOwnerPropagationSeedReport49a318 report;
		report.owner_vector_index = owner.owner_vector_index;
		report.runtime_zone_index = owner.runtime_zone_index;
		if (!owner.coordinate_triple_0x10_0x18_known) {
			report.status = "blocked_seed_coordinate_triple_unknown";
			result.seed_blocked_count += 1;
			result.seed_reports.push_back(report);
			continue;
		}
		result.seed_attempt_count += 1;
		report.seed_x = owner.coordinate_x_0x10;
		report.seed_y = owner.coordinate_y_0x14;
		report.seed_level = owner.coordinate_level_0x18;
		const int64_t seed_flat = cell_index(grid.width, grid.height, report.seed_x, report.seed_y, report.seed_level);
		if (seed_flat < 0 || seed_flat >= tile_count) {
			report.status = "blocked_seed_out_of_bounds";
			result.seed_blocked_count += 1;
			result.seed_reports.push_back(report);
			continue;
		}
		GeneratedCellRecord0x30 &seed_record = grid.records[size_t(seed_flat)];
		report.source_owner_byte = seed_record.word_0x20_known ? generated_cell_owner_byte2_signed_4a4142(seed_record.word_0x20) : -1;
		if (report.source_owner_byte < 0 || !generated_cell_relation_member_49a318(seed_record) || generated_cell_terrain_code_0x24(seed_record) == 9) {
			report.status = "blocked_seed_not_materialized_or_unowned";
			result.seed_blocked_count += 1;
			result.seed_reports.push_back(report);
			continue;
		}
		generated_cell_49a318_clear_source_projection(seed_record);

		std::vector<HighOwnerQueueNode> queue;
		path_low_word[size_t(seed_flat)] = 0;
		queue.push_back(HighOwnerQueueNode { report.seed_x, report.seed_y, report.seed_level, 0 });
		result.max_queue_size = std::max<int32_t>(result.max_queue_size, int32_t(queue.size()));

		for (int32_t guard = 0; guard < tile_count * 16 && !queue.empty(); ++guard) {
			int32_t best_index = 0;
			for (int32_t index = 1; index < int32_t(queue.size()); ++index) {
				if (queue[size_t(index)].score < queue[size_t(best_index)].score) {
					best_index = index;
				}
			}
			const HighOwnerQueueNode node = queue[size_t(best_index)];
			queue.erase(queue.begin() + best_index);
			report.popped_cell_count += 1;
			result.popped_cell_count += 1;
			const int64_t node_flat = cell_index(grid.width, grid.height, node.x, node.y, node.level);
			if (node_flat < 0 || node_flat >= tile_count) {
				continue;
			}
			const GeneratedCellRecord0x30 &node_record = grid.records[size_t(node_flat)];
			const int32_t node_owner = node_record.word_0x20_known ? generated_cell_owner_byte2_signed_4a4142(node_record.word_0x20) : -1;
			const int32_t base_score = node_owner == report.source_owner_byte
					? path_low_word[size_t(node_flat)]
					: path_high_word[size_t(node_flat)];
			const int32_t direction_count = relation_high_owner_direction_count_49a318(node_record, object_records, result, report);
			if (direction_count <= 0) {
				continue;
			}
			for (int32_t direction = direction_count - 1; direction >= 0; --direction) {
				const int32_t nx = node.x + DX[direction];
				const int32_t ny = node.y + DY[direction];
				const int32_t nl = node.level;
				const int64_t next_flat = cell_index(grid.width, grid.height, nx, ny, nl);
				if (next_flat < 0 || next_flat >= tile_count) {
					report.rejected_bounds_count += 1;
					continue;
				}
				GeneratedCellRecord0x30 &next_record = grid.records[size_t(next_flat)];
				const int32_t next_owner = next_record.word_0x20_known ? generated_cell_owner_byte2_signed_4a4142(next_record.word_0x20) : -1;
				if (next_owner < 0) {
					report.rejected_unowned_count += 1;
					continue;
				}
				if (!generated_cell_relation_member_49a318(next_record)) {
					report.rejected_materialized_count += 1;
					continue;
				}
				const int32_t terrain = generated_cell_terrain_code_0x24(next_record);
				if (terrain == 9) {
					report.rejected_terrain9_count += 1;
					continue;
				}
				if (!relation_high_owner_candidate_allowed_49a318(next_record, object_records, direction, result, report)) {
					continue;
				}
				if (next_owner == report.source_owner_byte) {
					const int32_t step = terrain == 8 ? 10 : 1;
					const int32_t next_score = base_score + step;
					if (next_score < path_low_word[size_t(next_flat)]) {
						path_low_word[size_t(next_flat)] = next_score;
						next_record.word_0x1c = generated_cell_word1c_set_low_word_49a318(next_record.word_0x1c_known ? next_record.word_0x1c : 0U, next_score);
						next_record.word_0x1c_known = true;
						next_record.word_0x10 = uint32_t(node.x);
						next_record.word_0x10_known = true;
						next_record.word_0x14 = uint32_t(node.y);
						next_record.word_0x14_known = true;
						next_record.word_0x18 = uint32_t(node.level);
						next_record.word_0x18_known = true;
						queue.push_back(HighOwnerQueueNode { nx, ny, nl, next_score });
						report.same_owner_relax_count += 1;
						result.same_owner_relax_count += 1;
					}
				} else {
					const int32_t next_score = base_score + 10;
					if (next_score < path_high_word[size_t(next_flat)]) {
						path_high_word[size_t(next_flat)] = next_score;
						result.owner_high_byte_grid[size_t(next_flat)] = report.source_owner_byte;
						next_record.word_0x1c = generated_cell_word1c_set_high_word_49a318(next_record.word_0x1c_known ? next_record.word_0x1c : 0U, next_score);
						next_record.word_0x1c_known = true;
						next_record.word_0x20 = generated_cell_word20_set_owner_byte3_49a318(next_record.word_0x20, report.source_owner_byte);
						next_record.word_0x20_known = true;
						next_record.word_0x28 = generated_cell_word28_set_direction_49a318(next_record.word_0x28_known ? next_record.word_0x28 : 0U, direction);
						next_record.word_0x28_known = true;
						queue.push_back(HighOwnerQueueNode { nx, ny, nl, next_score });
						report.cross_owner_high_byte_write_count += 1;
						result.cross_owner_high_byte_write_count += 1;
					}
				}
				result.max_queue_size = std::max<int32_t>(result.max_queue_size, int32_t(queue.size()));
			}
		}
		report.status = "0x49a318_seed_propagated";
		result.seed_reports.push_back(report);
	}

	for (const int32_t owner_high : result.owner_high_byte_grid) {
		if (owner_high < 0) {
			result.owner_high_byte_sentinel_count += 1;
		} else {
			result.owner_high_byte_materialized_count += 1;
		}
	}
	result.object_metadata_gate_complete = result.object_metadata_unresolved_count == 0;
	return result;
}

bool generated_cell_index_valid(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	return flat >= 0
			&& flat < int64_t(word_0x28.size())
			&& flat < int64_t(word_0x24.size());
}

bool generated_cell_49a1d8_valid_record(const GeneratedCellRecord0x30 &record) {
	if ((record.byte_0x2b_known_mask & 0x02U) == 0U || (record.byte_0x2b & 0x02U) == 0U) {
		return false;
	}
	return record.word_0x24_known && (record.word_0x24 & 0x3fU) != 9U;
}

bool generated_cell_49a1d8_valid_word24(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	if (!generated_cell_index_valid(word_0x28, word_0x24, flat)) {
		return false;
	}
	return (word_0x28[size_t(flat)] & CELL_DECOR_READY_BIT_25) != 0U
			&& (word_0x24[size_t(flat)] & 0x3fU) != 9U;
}

bool generated_cell_49a1d8_valid_terrain(const std::vector<uint32_t> &word_0x28, const std::vector<int32_t> &terrain_code, int64_t flat) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(terrain_code.size())) {
		return false;
	}
	return (word_0x28[size_t(flat)] & CELL_DECOR_READY_BIT_25) != 0U
			&& (terrain_code[size_t(flat)] & 0x3f) != 9;
}

bool generated_cell_49aa63(GeneratedCellRecord0x30 &record, bool set_candidate) {
	if (!record.word_0x28_known || !record.word_0x2c_known || (record.word_0x2c & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
	if (set_candidate) {
		record.word_0x28 |= CELL_DECOR_CANDIDATE_BIT_26;
		record.word_0x28 &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
		return !was_set;
	}
	record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
	return was_set;
}

bool generated_cell_49aa63(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_candidate) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
	if (set_candidate) {
		word_0x28[size_t(flat)] |= CELL_DECOR_CANDIDATE_BIT_26;
		word_0x28[size_t(flat)] &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~CELL_DECOR_CANDIDATE_BIT_26;
	return was_set;
}

bool generated_cell_49a932(GeneratedCellRecord0x30 &record, bool set_occupied) {
	if (!record.word_0x28_known || !record.word_0x2c_known || (record.word_0x2c & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
	if (set_occupied) {
		record.word_0x28 |= CELL_OCCUPIED_BLOCKED_BIT_27;
		record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
		return !was_set;
	}
	record.word_0x28 &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
	return was_set;
}

bool generated_cell_49a932(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_occupied) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
	if (set_occupied) {
		word_0x28[size_t(flat)] |= CELL_OCCUPIED_BLOCKED_BIT_27;
		word_0x28[size_t(flat)] &= ~CELL_DECOR_CANDIDATE_BIT_26;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
	return was_set;
}

bool generated_cell_49abd6_action_stamp(GeneratedCellRecord0x30 &record) {
	if (!record.word_0x28_known) {
		return false;
	}
	const uint32_t before = record.word_0x28;
	record.word_0x28 |= CELL_ACTION_CONTROL_BIT_22;
	generated_cell_49a932(record, true);
	return before != record.word_0x28;
}

bool generated_cell_49abd6_action_stamp(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	const uint32_t before = word_0x28[size_t(flat)];
	word_0x28[size_t(flat)] |= CELL_ACTION_CONTROL_BIT_22;
	generated_cell_49a932(word_0x28, word_0x2c, flat, true);
	return before != word_0x28[size_t(flat)];
}

bool generated_cell_49abd6_body_reject_stamp(GeneratedCellRecord0x30 &record) {
	if (!record.word_0x28_known) {
		return false;
	}
	const bool was_set = (record.word_0x28 & CELL_DECOR_READY_BIT_25) != 0U;
	record.byte_0x2b_known_mask |= 0x02U;
	record.byte_0x2b &= ~uint8_t(0x02U);
	record.byte_0x2b_known = record.byte_0x2b_known_mask == 0xffU;
	record.word_0x28 &= ~CELL_DECOR_READY_BIT_25;
	return was_set;
}

bool generated_cell_49abd6_body_reject_stamp(std::vector<uint32_t> &word_0x28, int64_t flat) {
	if (flat < 0 || flat >= int64_t(word_0x28.size())) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & CELL_DECOR_READY_BIT_25) != 0U;
	word_0x28[size_t(flat)] &= ~CELL_DECOR_READY_BIT_25;
	return was_set;
}

GeneratedCell49a85dStampResult generated_cell_49a85d_stamp(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level) {
	GeneratedCell49a85dStampResult result;
	if (width <= 0 || height <= 0 || level_count <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
		return result;
	}
	const int64_t center_flat = cell_index(width, height, x, y, level);
	if (center_flat < 0 || center_flat >= int64_t(word_0x28.size()) || center_flat >= int64_t(word_0x2c.size())) {
		return result;
	}
	result.center_in_bounds = true;
	result.center_set = generated_cell_49a932(word_0x28, word_0x2c, center_flat, true);

	const int32_t min_x = std::max<int32_t>(0, x - 1);
	const int32_t min_y = std::max<int32_t>(0, y - 1);
	const int32_t max_x = std::min<int32_t>(width, x + 2);
	const int32_t max_y = std::min<int32_t>(height, y + 2);
	for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
		for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
			const int64_t flat = cell_index(width, height, local_x, local_y, level);
			if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
				continue;
			}
			result.covered_cell_count += 1;
			if (generated_cell_49a932(word_0x28, word_0x2c, flat, true)) {
				result.covered_set_count += 1;
			}
		}
	}
	return result;
}

GeneratedCell49a962SweepResult generated_cell_49a962_word24(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, const std::vector<uint32_t> &word_0x24, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level) {
	GeneratedCell49a962SweepResult result;
	if (width <= 0 || height <= 0 || level_count <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
		return result;
	}
	const int64_t center_flat = cell_index(width, height, x, y, level);
	if (center_flat < 0 || center_flat >= int64_t(word_0x28.size()) || center_flat >= int64_t(word_0x2c.size())) {
		return result;
	}
	result.center_in_bounds = true;
	result.center_candidate_set = generated_cell_49aa63(word_0x28, word_0x2c, center_flat, true);

	const int32_t min_x = std::max<int32_t>(0, x - 1);
	const int32_t min_y = std::max<int32_t>(0, y - 1);
	const int32_t max_x = std::min<int32_t>(width, x + 2);
	const int32_t max_y = std::min<int32_t>(height, y + 2);
	for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
		for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
			const int64_t flat = cell_index(width, height, local_x, local_y, level);
			if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size()) || flat >= int64_t(word_0x24.size())) {
				continue;
			}
			result.neighbor_scan_count += 1;
			if ((word_0x28[size_t(flat)] & CELL_ACTION_CONTROL_BIT_22) != 0U) {
				result.neighbor_bit22_skip_count += 1;
				continue;
			}
			if (!generated_cell_49a1d8_valid_word24(word_0x28, word_0x24, flat)) {
				result.neighbor_invalid_skip_count += 1;
				continue;
			}
			if ((word_0x24[size_t(flat)] & 0x3fU) == 8U) {
				result.neighbor_terrain8_skip_count += 1;
				continue;
			}
			if (generated_cell_49a932(word_0x28, word_0x2c, flat, false)) {
				result.neighbor_clear_count += 1;
			}
		}
	}
	return result;
}

GeneratedCell49a962SweepResult generated_cell_49a962_terrain(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, const std::vector<int32_t> &terrain_code, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level) {
	GeneratedCell49a962SweepResult result;
	if (width <= 0 || height <= 0 || level_count <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
		return result;
	}
	const int64_t center_flat = cell_index(width, height, x, y, level);
	if (center_flat < 0 || center_flat >= int64_t(word_0x28.size()) || center_flat >= int64_t(word_0x2c.size())) {
		return result;
	}
	result.center_in_bounds = true;
	result.center_candidate_set = generated_cell_49aa63(word_0x28, word_0x2c, center_flat, true);

	const int32_t min_x = std::max<int32_t>(0, x - 1);
	const int32_t min_y = std::max<int32_t>(0, y - 1);
	const int32_t max_x = std::min<int32_t>(width, x + 2);
	const int32_t max_y = std::min<int32_t>(height, y + 2);
	for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
		for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
			const int64_t flat = cell_index(width, height, local_x, local_y, level);
			if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size()) || flat >= int64_t(terrain_code.size())) {
				continue;
			}
			result.neighbor_scan_count += 1;
			if ((word_0x28[size_t(flat)] & CELL_ACTION_CONTROL_BIT_22) != 0U) {
				result.neighbor_bit22_skip_count += 1;
				continue;
			}
			if (!generated_cell_49a1d8_valid_terrain(word_0x28, terrain_code, flat)) {
				result.neighbor_invalid_skip_count += 1;
				continue;
			}
			if ((terrain_code[size_t(flat)] & 0x3f) == 8) {
				result.neighbor_terrain8_skip_count += 1;
				continue;
			}
			if (generated_cell_49a932(word_0x28, word_0x2c, flat, false)) {
				result.neighbor_clear_count += 1;
			}
		}
	}
	return result;
}

GeneratedCellObjectReferenceRemoval499ee8Result generated_cell_object_reference_removal_0x499ee8(GeneratedCellRecord0x30 &record, uint32_t object_record_key) {
	GeneratedCellObjectReferenceRemoval499ee8Result result;
	result.object_reference_vector_known = record.object_reference_vector_contents_known;
	result.reference_count_before = record.object_reference_count;
	result.reference_count_after = record.object_reference_count;
	if (!record.object_reference_vector_contents_known) {
		return result;
	}

	result.reference_count_before = int32_t(record.object_references_0x04_0x08.size());
	record.object_reference_count = result.reference_count_before;
	auto it = std::find(record.object_references_0x04_0x08.begin(), record.object_references_0x04_0x08.end(), object_record_key);
	if (it == record.object_references_0x04_0x08.end()) {
		result.reference_count_after = record.object_reference_count;
		return result;
	}

	result.object_record_found = true;
	record.object_references_0x04_0x08.erase(it);
	record.object_reference_count = int32_t(record.object_references_0x04_0x08.size());
	result.object_record_removed = true;
	result.reference_count_after = record.object_reference_count;
	result.object_reference_vector_empty_after = record.object_reference_count == 0;
	if (!result.object_reference_vector_empty_after || !record.word_0x20_known || !record.word_0x28_known) {
		return result;
	}

	result.word_0x20_before = record.word_0x20;
	result.word_0x28_before = record.word_0x28;
	record.word_0x28 &= ~CELL_ACTION_CONTROL_BIT_22;
	record.word_0x28 |= CELL_DECOR_READY_BIT_25;
	record.word_0x20 = generated_cell_word20_set_low_word(record.word_0x20, 0x7fbcU);
	result.word_0x20_after = record.word_0x20;
	result.word_0x28_after = record.word_0x28;
	result.word_mutations_applied = true;
	return result;
}

static uint32_t generated_cell_pack_low_nibble_source_0x2c(uint32_t word_0x2c, int32_t low_nibble_source) {
	return (word_0x2c & 0xffffffe1U) | ((uint32_t(low_nibble_source) & 0x0fU) << 1U) | 0x01U;
}

static uint8_t generated_cell_word20_owner_byte2(uint32_t word_0x20) {
	return uint8_t((word_0x20 >> 16U) & 0xffU);
}

ConnectionRegionWriterResult4a606b connection_region_writer_4a606b(GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, int32_t level, int32_t low_nibble_source) {
	ConnectionRegionWriterResult4a606b result;
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || level < 0 || level >= grid.level_count) {
		return result;
	}

	const int32_t min_x = std::max<int32_t>(0, x - 1);
	const int32_t min_y = std::max<int32_t>(0, y - 1);
	const int32_t max_x = std::min<int32_t>(grid.width, x + 2);
	const int32_t max_y = std::min<int32_t>(grid.height, y + 2);
	for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
		for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
			const int64_t flat = cell_index(grid.width, grid.height, local_x, local_y, level);
			if (flat < 0 || flat >= int64_t(grid.records.size())) {
				continue;
			}
			result.rectangle_scan_count += 1;
			GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
			if (!record.object_reference_vector_contents_known) {
				result.object_reference_unknown_skip_count += 1;
				continue;
			}
			if (record.object_reference_count != 0) {
				result.object_reference_occupied_skip_count += 1;
				continue;
			}
			if (!record.word_0x28_known || !record.word_0x2c_known) {
				result.unknown_word_skip_count += 1;
				continue;
			}
			if (generated_cell_49aa63(record, true)) {
				result.candidate_bit_set_count += 1;
			}
			record.word_0x2c = generated_cell_pack_low_nibble_source_0x2c(record.word_0x2c, low_nibble_source);
			result.packed_stamp_count += 1;
		}
	}

	const int64_t source_flat = cell_index(grid.width, grid.height, x, y, level);
	if (source_flat < 0 || source_flat >= int64_t(grid.records.size())) {
		return result;
	}
	result.source_cell_in_bounds = true;
	const GeneratedCellRecord0x30 &source_record = grid.records[size_t(source_flat)];
	if (!source_record.word_0x10_known || !source_record.word_0x14_known || !source_record.word_0x18_known) {
		return result;
	}
	result.source_projection_triple_known = true;
	const int32_t projected_x = int32_t(source_record.word_0x10);
	const int32_t projected_y = int32_t(source_record.word_0x14);
	const int32_t projected_level = int32_t(source_record.word_0x18);
	const int64_t projected_flat = cell_index(grid.width, grid.height, projected_x, projected_y, projected_level);
	if (projected_flat < 0 || projected_flat >= int64_t(grid.records.size())) {
		return result;
	}
	result.source_projection_target_in_bounds = true;
	GeneratedCellRecord0x30 &projected_record = grid.records[size_t(projected_flat)];
	if (!projected_record.word_0x28_known || !projected_record.word_0x2c_known) {
		result.projected_target_unknown_word_skip_count += 1;
		return result;
	}
	projected_record.word_0x2c &= ~uint32_t(0x1fU);
	result.projected_target_low_bits_cleared_count += 1;
	if (generated_cell_49a932(projected_record, true)) {
		result.projected_target_occupied_set_count += 1;
	}
	return result;
}

ProjectedCellChainResult4a5a23 projected_cell_chain_no_object_4a5a23(GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, int32_t level, bool suppress_cleanup) {
	ProjectedCellChainResult4a5a23 result;
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0) {
		result.stopped_on_out_of_bounds = true;
		return result;
	}

	const int32_t max_steps = int32_t(grid.records.size()) + 1;
	for (int32_t step = 0; step < max_steps; ++step) {
		const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
		if (flat < 0 || flat >= int64_t(grid.records.size())) {
			result.stopped_on_out_of_bounds = true;
			return result;
		}
		if (step == 0) {
			result.start_cell_in_bounds = true;
		}
		GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
		if (!record.word_0x1c_known || !record.word_0x20_known || !record.word_0x28_known || !record.word_0x2c_known) {
			result.stopped_on_unknown_word = true;
			return result;
		}
		const uint32_t low_word = record.word_0x1c & 0x0000ffffU;
		if (low_word == 0U) {
			result.stopped_on_low_word_zero = true;
			return result;
		}
		if (low_word >= 0x7530U) {
			result.stopped_on_low_word_limit = true;
			return result;
		}
		result.visited_cell_count += 1;
		if ((record.word_0x2c & 0x01U) != 0U) {
			result.stopped_on_object_materialization_required = true;
			return result;
		}

		const uint32_t before_word_0x28 = record.word_0x28;
		record.word_0x28 |= CELL_OCCUPIED_BLOCKED_BIT_27;
		record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
		if (record.word_0x28 != before_word_0x28) {
			result.occupied_stamp_count += 1;
		}

		if (!suppress_cleanup) {
			const uint8_t owner_byte2 = generated_cell_word20_owner_byte2(record.word_0x20);
			const int32_t min_x = std::max<int32_t>(0, x - 1);
			const int32_t min_y = std::max<int32_t>(0, y - 1);
			const int32_t max_x = std::min<int32_t>(grid.width, x + 2);
			const int32_t max_y = std::min<int32_t>(grid.height, y + 2);
			for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
				for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
					const int64_t local_flat = cell_index(grid.width, grid.height, local_x, local_y, level);
					if (local_flat < 0 || local_flat >= int64_t(grid.records.size())) {
						continue;
					}
					result.cleanup_scan_count += 1;
					GeneratedCellRecord0x30 &nearby = grid.records[size_t(local_flat)];
					if (!nearby.word_0x20_known || !nearby.word_0x2c_known) {
						continue;
					}
					if (generated_cell_word20_owner_byte2(nearby.word_0x20) != owner_byte2 || (nearby.word_0x2c & 0x01U) != 0U) {
						continue;
					}
					result.cleanup_owner_match_count += 1;
					if ((nearby.byte_0x2b_known_mask & 0x04U) == 0U || (nearby.byte_0x2b & 0x04U) != 0U) {
						result.cleanup_bit_0x04_clear_count += 1;
					}
					nearby.byte_0x2b &= ~uint8_t(0x04U);
					nearby.byte_0x2b_known_mask |= 0x04U;
					nearby.byte_0x2b_known = nearby.byte_0x2b_known_mask == 0xffU;
				}
			}
		}

		if (!record.word_0x10_known || !record.word_0x14_known || !record.word_0x18_known) {
			result.stopped_on_unknown_projection = true;
			return result;
		}
		x = int32_t(record.word_0x10);
		y = int32_t(record.word_0x14);
		level = int32_t(record.word_0x18);
	}

	result.truncated_by_cycle_guard = true;
	return result;
}

ProjectedCellChainResult4a5a23 projected_cell_chain_with_object_branch_4a5a23(GeneratorObjectPrivateState &state, SourceObjectResolverState4af785 &resolver_state, H3MapedRng &rng, int32_t x, int32_t y, int32_t level, bool suppress_cleanup) {
	ProjectedCellChainResult4a5a23 result;
	GeneratedCellRecordGrid0x30 &grid = state.generated_cell_buffer;
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0) {
		result.stopped_on_out_of_bounds = true;
		return result;
	}

	const int32_t max_steps = int32_t(grid.records.size()) + 1;
	for (int32_t step = 0; step < max_steps; ++step) {
		const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
		if (flat < 0 || flat >= int64_t(grid.records.size())) {
			result.stopped_on_out_of_bounds = true;
			return result;
		}
		if (step == 0) {
			result.start_cell_in_bounds = true;
		}
		GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
		if (!record.word_0x1c_known || !record.word_0x20_known || !record.word_0x28_known || !record.word_0x2c_known) {
			result.stopped_on_unknown_word = true;
			return result;
		}
		const uint32_t low_word = record.word_0x1c & 0x0000ffffU;
		if (low_word == 0U) {
			result.stopped_on_low_word_zero = true;
			return result;
		}
		if (low_word >= 0x7530U) {
			result.stopped_on_low_word_limit = true;
			return result;
		}
		result.visited_cell_count += 1;

		if ((record.word_0x2c & 0x01U) != 0U) {
			result.object_branch_attempt_count += 1;
			const int32_t low_nibble_source = int32_t((record.word_0x2c >> 1U) & 0x0fU);
			const SourceObjectSelectorResult4a9e40 selector =
					source_object_wrapper_selector_0x4a9e40(rng.state, 9, 0, low_nibble_source);
			if (!selector.selected || selector.selected_source_record_index < 0) {
				result.object_branch_blocked_count += 1;
				result.object_branch_blocked_reason = "0x4a5a23_object_branch_0x4a9e40_selector_unresolved";
				result.stopped_on_object_materialization_required = true;
				return result;
			}
			rng.state = selector.rng_state_after;
			result.object_branch_selector_selected_count += 1;
			const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
			if (selector.selected_source_record_index >= int32_t(records.size())) {
				result.object_branch_blocked_count += 1;
				result.object_branch_blocked_reason = "0x4a5a23_object_branch_selected_source_record_out_of_range";
				result.stopped_on_object_materialization_required = true;
				return result;
			}
			if (!state.native_object_record_key_allocator_0x4a93a2_known) {
				result.object_branch_blocked_count += 1;
				result.object_branch_blocked_reason = "0x4a5a23_object_branch_native_object_record_key_allocator_unavailable";
				result.stopped_on_object_materialization_required = true;
				return result;
			}
			const SourceObjectRecord0x4c &selected_record = records[size_t(selector.selected_source_record_index)];
			const SourceObjectResolverResult4af785 resolver =
					source_object_descriptor_resolver_0x4af785(resolver_state, selected_record);
			if (!resolver.reused_existing_wrapper && !resolver.created_new_wrapper) {
				result.object_branch_blocked_count += 1;
				result.object_branch_blocked_reason = "0x4a5a23_object_branch_0x4af785_wrapper_unresolved";
				result.stopped_on_object_materialization_required = true;
				return result;
			}
			preserve_source_pair_vector_edc(state, resolver_state);

			const uint32_t object_record_key = state.next_native_object_record_key_0x4a93a2++;
			result.object_branch_allocated_record_count += 1;
			result.object_branch_record_keys.push_back(object_record_key);
			record.word_0x2c &= ~uint32_t(0x1fU);
			result.object_branch_low_bits_cleared_count += 1;
			const ObjectFootprintCommitResult4a54a7 commit = object_footprint_commit_4a54a7(
					state,
					object_record_key,
					selected_record.type_id_0x1c,
					x,
					y,
					level,
					false,
					0,
					0);
			if (!commit.object_vector_appended) {
				result.object_branch_blocked_count += 1;
				result.object_branch_blocked_reason = "0x4a5a23_object_branch_vtable_slot_0x04_commit_failed";
				result.stopped_on_object_materialization_required = true;
				return result;
			}
			result.object_branch_commit_count += 1;
			const uint32_t before_branch_word_0x28 = record.word_0x28;
			record.word_0x28 |= CELL_OCCUPIED_BLOCKED_BIT_27;
			record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
			if (record.word_0x28 != before_branch_word_0x28) {
				result.occupied_stamp_count += 1;
			}
			if (!state.object_records_0xec4_ecc.empty()) {
				ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
				object_record.object_record_vtable_0x00 = OBJECT_RECORD_VTABLE_0X540A74;
				object_record.descriptor_source_key_0x00 = selected_record.source_row;
				object_record.selected_wrapper_index_0x4af785 = resolver.selected_wrapper_index;
				object_record.source_catalog_index_0x49da08 = selector.selected_source_record_index;
				object_record.copied_source_record_carried = true;
				object_record.source_record_copy = selected_record;
			}
		} else {
			const uint32_t before_word_0x28 = record.word_0x28;
			record.word_0x28 |= CELL_OCCUPIED_BLOCKED_BIT_27;
			record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
			if (record.word_0x28 != before_word_0x28) {
				result.occupied_stamp_count += 1;
			}
		}

		if (!suppress_cleanup) {
			const uint8_t owner_byte2 = generated_cell_word20_owner_byte2(record.word_0x20);
			const int32_t min_x = std::max<int32_t>(0, x - 1);
			const int32_t min_y = std::max<int32_t>(0, y - 1);
			const int32_t max_x = std::min<int32_t>(grid.width, x + 2);
			const int32_t max_y = std::min<int32_t>(grid.height, y + 2);
			for (int32_t local_y = min_y; local_y < max_y; ++local_y) {
				for (int32_t local_x = min_x; local_x < max_x; ++local_x) {
					const int64_t local_flat = cell_index(grid.width, grid.height, local_x, local_y, level);
					if (local_flat < 0 || local_flat >= int64_t(grid.records.size())) {
						continue;
					}
					result.cleanup_scan_count += 1;
					GeneratedCellRecord0x30 &nearby = grid.records[size_t(local_flat)];
					if (!nearby.word_0x20_known || !nearby.word_0x2c_known) {
						continue;
					}
					if (generated_cell_word20_owner_byte2(nearby.word_0x20) != owner_byte2 || (nearby.word_0x2c & 0x01U) != 0U) {
						continue;
					}
					result.cleanup_owner_match_count += 1;
					if ((nearby.byte_0x2b_known_mask & 0x04U) == 0U || (nearby.byte_0x2b & 0x04U) != 0U) {
						result.cleanup_bit_0x04_clear_count += 1;
					}
					nearby.byte_0x2b &= ~uint8_t(0x04U);
					nearby.byte_0x2b_known_mask |= 0x04U;
					nearby.byte_0x2b_known = nearby.byte_0x2b_known_mask == 0xffU;
				}
			}
		}

		if (!record.word_0x10_known || !record.word_0x14_known || !record.word_0x18_known) {
			result.stopped_on_unknown_projection = true;
			return result;
		}
		x = int32_t(record.word_0x10);
		y = int32_t(record.word_0x14);
		level = int32_t(record.word_0x18);
	}

	result.truncated_by_cycle_guard = true;
	return result;
}

static std::vector<uint32_t> generated_cell_word20_vector_from_record_grid(const GeneratedCellRecordGrid0x30 &grid, bool &all_known) {
	std::vector<uint32_t> words;
	words.reserve(grid.records.size());
	all_known = true;
	for (const GeneratedCellRecord0x30 &record : grid.records) {
		if (!record.word_0x20_known) {
			all_known = false;
		}
		words.push_back(record.word_0x20);
	}
	return words;
}

static void apply_generated_cell_word20_vector_to_record_grid(GeneratedCellRecordGrid0x30 &grid, const std::vector<uint32_t> &words) {
	for (size_t index = 0; index < grid.records.size() && index < words.size(); ++index) {
		grid.records[index].word_0x20_known = true;
		grid.records[index].word_0x20 = words[index];
	}
}

static GeneratorRelationOwnerState4a218c *relation_owner_for_runtime_zone_0x4a54a7(GeneratorObjectPrivateState &state, int32_t runtime_zone_index) {
	for (GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (owner.runtime_zone_index == runtime_zone_index) {
			return &owner;
		}
	}
	return nullptr;
}

static bool increment_relation_descriptor_counter_0x4a54a7(GeneratorObjectPrivateState &state, ObjectFootprintCommitResult4a54a7 &result, int64_t projection_flat, int32_t descriptor_type_0x1c) {
	if (projection_flat < 0 || projection_flat >= int64_t(state.generated_cell_buffer.records.size()) || descriptor_type_0x1c < 0) {
		return false;
	}
	const GeneratedCellRecord0x30 &source_record = state.generated_cell_buffer.records[size_t(projection_flat)];
	if (!source_record.word_0x20_known) {
		return false;
	}
	const int32_t source_owner = generated_cell_owner_byte2_signed_4a4142(source_record.word_0x20);
	if (source_owner < 0) {
		return false;
	}
	GeneratorRelationOwnerState4a218c *owner = relation_owner_for_runtime_zone_0x4a54a7(state, source_owner);
	if (owner == nullptr || !owner->descriptor_type_counter_table_0x44_known) {
		return false;
	}
	if (owner->descriptor_type_counters_0x44.size() != size_t(RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT)) {
		return false;
	}
	if (descriptor_type_0x1c >= int32_t(owner->descriptor_type_counters_0x44.size())) {
		return false;
	}
	uint32_t &counter = owner->descriptor_type_counters_0x44[size_t(descriptor_type_0x1c)];
	if (counter == 0U && owner->descriptor_type_counter_table_0x44_zero_count > 0) {
		owner->descriptor_type_counter_table_0x44_zero_count -= 1;
	}
	counter += 1U;
	state.relation_descriptor_counter_increment_count_0x4a54a7 += 1;
	result.relation_descriptor_counter_incremented = true;
	result.relation_descriptor_counter_owner_runtime_zone_index = source_owner;
	result.relation_descriptor_counter_after = int32_t(counter);
	return true;
}

ObjectFootprintCommitResult4a54a7 object_footprint_commit_4a54a7(GeneratorObjectPrivateState &state, uint32_t object_record_key, int32_t descriptor_type_0x1c, int32_t x, int32_t y, int32_t level, bool descriptor_projection_enabled_0x29, int32_t descriptor_offset_x_0x2c, int32_t descriptor_offset_y_0x30) {
	ObjectFootprintCommitResult4a54a7 result;
	ObjectRecordReference4a54a7 object_record;
	object_record.object_record_key = object_record_key;
	object_record.descriptor_type_0x1c = descriptor_type_0x1c;
	object_record.x = x;
	object_record.y = y;
	object_record.level = level;
	state.object_records_0xec4_ecc.push_back(object_record);
	state.object_record_vector_append_count_0x4a54a7 += 1;
	state.object_record_vector_ec4_ecc.present = true;
	state.object_record_vector_ec4_ecc.contents_known = true;
	state.object_record_vector_ec4_ecc.count_known = true;
	state.object_record_vector_ec4_ecc.count = int32_t(state.object_records_0xec4_ecc.size());
	state.object_record_vector_ec4_ecc.element_size_bytes = 4;
	result.object_vector_appended = true;
	result.object_vector_count_after = state.object_record_vector_ec4_ecc.count;

	if (state.descriptor_counter_table_0x1110_present
			&& state.descriptor_counter_table_0x1110_contents_known
			&& descriptor_type_0x1c >= 0
			&& descriptor_type_0x1c < int32_t(state.descriptor_counter_table_0x1110.size())) {
		uint32_t &counter = state.descriptor_counter_table_0x1110[size_t(descriptor_type_0x1c)];
		counter += 1U;
		state.descriptor_counter_increment_count_0x4a54a7 += 1;
		result.descriptor_counter_incremented = true;
		result.descriptor_counter_after = int32_t(counter);
	}

	const int64_t target_flat = cell_index(state.width, state.height, x, y, level);
	if (target_flat < 0 || target_flat >= int64_t(state.generated_cell_buffer.records.size())) {
		return result;
	}
	result.target_cell_in_bounds = true;
	GeneratedCellRecord0x30 &target_record = state.generated_cell_buffer.records[size_t(target_flat)];
	if (target_record.object_reference_vector_contents_known) {
		target_record.object_references_0x04_0x08.push_back(object_record_key);
		target_record.object_reference_count = int32_t(target_record.object_references_0x04_0x08.size());
		state.generated_cell_object_reference_append_count_0x4a54a7 += 1;
		result.generated_cell_reference_appended = true;
		result.target_cell_reference_count_after = target_record.object_reference_count;
	}
	if (target_record.word_0x20_known && target_record.word_0x28_known) {
		result.target_cell_words_known = true;
		const uint32_t old_word_0x28 = target_record.word_0x28;
		target_record.word_0x28 = generated_cell_4a54a7_endpoint_word28(target_record.word_0x28);
		if (target_record.word_0x28 != old_word_0x28) {
			result.target_cell_word_mutation_count += 1;
		}
		state.target_cell_word_mutation_count_0x4a54a7 += result.target_cell_word_mutation_count;
	}

	result.projection_enabled = descriptor_projection_enabled_0x29;
	if (!descriptor_projection_enabled_0x29) {
		return result;
	}

	const int32_t projection_x = x - descriptor_offset_x_0x2c;
	const int32_t projection_y = y - descriptor_offset_y_0x30;
	const int64_t projection_flat = cell_index(state.width, state.height, projection_x, projection_y, level);
	if (projection_flat < 0 || projection_flat >= int64_t(state.generated_cell_buffer.records.size())) {
		return result;
	}
	result.projection_anchor_in_bounds = true;
	increment_relation_descriptor_counter_0x4a54a7(state, result, projection_flat, descriptor_type_0x1c);
	const uint32_t target_word_0x20_before_projection = target_record.word_0x20;
	bool all_word20_known = false;
	std::vector<uint32_t> word_0x20 = generated_cell_word20_vector_from_record_grid(state.generated_cell_buffer, all_word20_known);
	if (!all_word20_known) {
		return result;
	}
	result.projection_score_depletion_count = deplete_generated_cell_scores_4a54a7(
			word_0x20,
			state.width,
			state.height,
			state.level_count,
			projection_x,
			projection_y,
			level);
	if (result.projection_score_depletion_count > 0) {
		apply_generated_cell_word20_vector_to_record_grid(state.generated_cell_buffer, word_0x20);
		state.projection_score_depletion_count_0x4a54a7 += result.projection_score_depletion_count;
		const GeneratedCellRecord0x30 &updated_target_record = state.generated_cell_buffer.records[size_t(target_flat)];
		if (updated_target_record.word_0x20 != target_word_0x20_before_projection) {
			result.target_cell_word_mutation_count += 1;
			state.target_cell_word_mutation_count_0x4a54a7 += 1;
		}
	}
	return result;
}

ObjectFootprintCommitResult4a54a7 object_footprint_commit_4a54a7(GeneratorObjectPrivateState &state, const ObjectMaterializationPrep4a8db2_4a901a &prep) {
	if (!prep.ready_for_object_vector_commit_0x4a54a7) {
		return ObjectFootprintCommitResult4a54a7 {};
	}
	const SourceObjectDescriptor4903e8 &descriptor = prep.descriptor_join_0x4903e8.descriptor;
	const ObjectFootprintCommitResult4a54a7 result = object_footprint_commit_4a54a7(
			state,
			prep.object_record_key,
			descriptor.descriptor_type_0x1c,
			prep.x,
			prep.y,
			prep.level,
			descriptor.projection_enabled_0x29,
			descriptor.source_cell_x_0x2c,
			descriptor.source_cell_y_0x30);
	if (result.object_vector_appended && !state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &record = state.object_records_0xec4_ecc.back();
		record.source_descriptor_join_0x4903e8_known = prep.descriptor_joined;
		record.weighted_type98_descriptor_bridge_0x4a93a2_known = prep.weighted_type98_descriptor_bridge_0x4a93a2_known;
		record.descriptor_source_key_0x00 = descriptor.source_key_0x00;
		record.selected_wrapper_index_0x4af785 = prep.selected_wrapper_index_0x4af785;
		record.source_catalog_index_0x49da08 = prep.source_catalog_index_0x49da08;
		record.copied_source_record_carried = prep.copied_source_record_carried;
		record.source_record_copy = prep.source_record_copy;
	}
	return result;
}

std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> recovered_supported_land_connection_fallback_records_4a7605_4a5e03() {
	ConnectionFallbackMaterializationRecord4a7605_4a5e03 first;
	first.object_record_key = 0x036260c0U;
	first.object_record_pointer_4a5e03 = 0x036260c0U;
	first.descriptor_pointer = 0x018dca40U;
	first.arg0_4a5e03 = 0x2422U;
	first.descriptor_type_0x1c = 54;
	first.x = 59;
	first.y = 47;
	first.level = 0;
	first.descriptor_projection_enabled_0x29 = true;
	first.descriptor_offset_x_0x2c = 0;
	first.descriptor_offset_y_0x30 = 0;
	first.expected_owner_byte2_known = true;
	first.expected_owner_byte2 = 1;
	first.relation_counter_before_after_known = true;
	first.relation_counter_before = 0;
	first.relation_counter_after = 1;
	first.source = "medium_seed10_border_guard_fallback_0x4a7605_0x4a5e03_record_0";

	ConnectionFallbackMaterializationRecord4a7605_4a5e03 second;
	second.object_record_key = 0x03626060U;
	second.object_record_pointer_4a5e03 = 0x03626060U;
	second.descriptor_pointer = 0x018dc1a4U;
	second.arg0_4a5e03 = 0x2422U;
	second.descriptor_type_0x1c = 54;
	second.x = 39;
	second.y = 31;
	second.level = 0;
	second.descriptor_projection_enabled_0x29 = true;
	second.descriptor_offset_x_0x2c = 0;
	second.descriptor_offset_y_0x30 = 0;
	second.expected_owner_byte2_known = true;
	second.expected_owner_byte2 = 4;
	second.relation_counter_before_after_known = true;
	second.relation_counter_before = 1;
	second.relation_counter_after = 2;
	second.source = "medium_seed10_border_guard_fallback_0x4a7605_0x4a5e03_record_1";

	return { first, second };
}

ConnectionFallbackMaterializationResult4a7605_4a5e03 connection_fallback_materialization_4a7605_4a5e03(GeneratorObjectPrivateState &state, const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> &records) {
	ConnectionFallbackMaterializationResult4a7605_4a5e03 result;
	result.source_backed = true;
	result.input_record_count = int32_t(records.size());
	state.connection_fallback_materialization_0x4a7605_0x4a5e03_known = true;
	state.connection_fallback_materialization_record_count = result.input_record_count;
	state.connection_fallback_materialization_records_0x4a7605_0x4a5e03 = records;

	for (const ConnectionFallbackMaterializationRecord4a7605_4a5e03 &record : records) {
		ConnectionFallbackMaterializationRecordResult4a7605_4a5e03 record_result;
		record_result.record = record;
		const int64_t target_flat = cell_index(state.width, state.height, record.x, record.y, record.level);
		if (target_flat < 0 || target_flat >= int64_t(state.generated_cell_buffer.records.size())) {
			record_result.blocked_reason = "0x4a5e03_target_cell_out_of_bounds";
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		record_result.target_cell_in_bounds = true;
		GeneratedCellRecord0x30 &target_record = state.generated_cell_buffer.records[size_t(target_flat)];
		record_result.target_object_reference_vector_known = target_record.object_reference_vector_contents_known;
		record_result.target_object_reference_vector_empty =
				target_record.object_reference_vector_contents_known && target_record.object_reference_count == 0;
		if (!record_result.target_object_reference_vector_known) {
			record_result.blocked_reason = "0x4a5e03_target_object_reference_vector_unknown";
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		if (!record_result.target_object_reference_vector_empty) {
			record_result.blocked_reason = "0x4a5e03_target_object_reference_vector_not_empty";
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		if (record.expected_owner_byte2_known) {
			if (!target_record.word_0x20_known) {
				record_result.blocked_reason = "0x4a5e03_target_owner_word_unknown";
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
			const int32_t owner_byte2 = generated_cell_owner_byte2_signed_4a4142(target_record.word_0x20);
			record_result.expected_owner_byte2_matched = owner_byte2 == record.expected_owner_byte2;
			if (!record_result.expected_owner_byte2_matched) {
				record_result.blocked_reason = "0x4a5e03_target_owner_byte2_mismatch";
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
		}

		record_result.commit_0x4a54a7 = object_footprint_commit_4a54a7(
				state,
				record.object_record_key,
				record.descriptor_type_0x1c,
				record.x,
				record.y,
				record.level,
				record.descriptor_projection_enabled_0x29,
				record.descriptor_offset_x_0x2c,
				record.descriptor_offset_y_0x30);
		record_result.committed = record_result.commit_0x4a54a7.object_vector_appended;
		if (!record_result.committed) {
			record_result.blocked_reason = "0x4a54a7_fallback_record_commit_did_not_append_object_vector";
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		if (!state.object_records_0xec4_ecc.empty()) {
			ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
			object_record.connection_fallback_record_0x4a7605_0x4a5e03_known = true;
			object_record.connection_fallback_arg0_0x4a5e03 = record.arg0_4a5e03;
			object_record.connection_fallback_descriptor_pointer = record.descriptor_pointer;
			object_record.connection_fallback_expected_owner_byte2 =
					record.expected_owner_byte2_known ? record.expected_owner_byte2 : -1;
		}
		result.commit_count += 1;
		result.records.push_back(record_result);
	}
	state.connection_fallback_materialization_commit_count = result.commit_count;
	state.connection_fallback_materialization_blocked_count = result.blocked_count;
	return result;
}

static bool relation_scan_bounds_0x4a7312_non_sentinel(const GeneratorRelationOwnerState4a218c &source_relation) {
	return source_relation.scan_bounds_0x20_0x2c_known
			&& source_relation.scan_bound_low_x_0x20 != RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452
			&& source_relation.scan_bound_low_y_0x24 != RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452
			&& source_relation.scan_bound_high_x_0x28 != RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452
			&& source_relation.scan_bound_high_y_0x2c != RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452
			&& source_relation.scan_bound_low_x_0x20 < source_relation.scan_bound_high_x_0x28
			&& source_relation.scan_bound_low_y_0x24 < source_relation.scan_bound_high_y_0x2c;
}

static RelationScanConsumerResult4a5767 relation_scan_consumers_after_0x4a1f3b_bounds_4a5767_impl(GeneratedCellRecordGrid0x30 &grid, GeneratorObjectPrivateState *state, SourceObjectResolverState4af785 *resolver_state, H3MapedRng *rng, const std::vector<GeneratorRelationOwnerState4a218c> &owners) {
	RelationScanConsumerResult4a5767 result;
	result.applied = true;
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || grid.records.empty()) {
		return result;
	}
	result.grid_available = true;

	for (const GeneratorRelationOwnerState4a218c &owner : owners) {
		RelationScanConsumerOwnerReport4a5767 report;
		report.owner_vector_index = owner.owner_vector_index;
		report.runtime_zone_index = owner.runtime_zone_index;
		report.scan_bounds_known = owner.scan_bounds_0x20_0x2c_known;
		report.scan_bounds_non_sentinel = relation_scan_bounds_0x4a7312_non_sentinel(owner);
		result.owner_scan_count += 1;
		if (!report.scan_bounds_non_sentinel || !owner.coordinate_triple_0x10_0x18_known || owner.runtime_zone_index < 0) {
			result.owner_bounds_blocked_count += 1;
			result.owner_reports.push_back(report);
			continue;
		}

		const int32_t level = owner.coordinate_level_0x18;
		for (int32_t y = owner.scan_bound_low_y_0x24; y < owner.scan_bound_high_y_0x2c; ++y) {
			for (int32_t x = owner.scan_bound_low_x_0x20; x < owner.scan_bound_high_x_0x28; ++x) {
				report.scanned_cell_count += 1;
				result.scanned_cell_count += 1;
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat < 0 || flat >= int64_t(grid.records.size())) {
					report.out_of_bounds_cell_count += 1;
					continue;
				}
				GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
				if (!record.word_0x1c_known || !record.word_0x20_known || !record.word_0x24_known || !record.word_0x28_known || !record.word_0x2c_known) {
					report.unknown_word_skip_count += 1;
					continue;
				}
				if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(owner.runtime_zone_index & 0xff)) {
					report.owner_byte_reject_count += 1;
					result.owner_byte_reject_count += 1;
					continue;
				}
				if ((record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
					report.object_metadata_branch_blocked_count += 1;
					result.object_metadata_branch_blocked_count += 1;
					continue;
				}
				if (!generated_cell_49a1d8_valid_record(record)) {
					report.invalid_49a1d8_skip_count += 1;
					result.invalid_49a1d8_skip_count += 1;
					continue;
				}
				const uint32_t low_word = record.word_0x1c & 0x0000ffffU;
				if (low_word == 0U || low_word >= 0x7530U) {
					report.low_word_gate_skip_count += 1;
					continue;
				}

				const ProjectedCellChainResult4a5a23 chain =
						state != nullptr && resolver_state != nullptr && rng != nullptr && (record.word_0x2c & 0x01U) != 0U
						? projected_cell_chain_with_object_branch_4a5a23(*state, *resolver_state, *rng, x, y, level, false)
						: projected_cell_chain_no_object_4a5a23(grid, x, y, level, false);
				report.projected_chain_call_count += 1;
				report.projected_chain_occupied_stamp_count += chain.occupied_stamp_count;
				report.projected_chain_cleanup_clear_count += chain.cleanup_bit_0x04_clear_count;
				report.projected_chain_object_branch_attempt_count += chain.object_branch_attempt_count;
				report.projected_chain_object_branch_commit_count += chain.object_branch_commit_count;
				result.projected_chain_call_count += 1;
				result.projected_chain_occupied_stamp_count += chain.occupied_stamp_count;
				result.projected_chain_cleanup_clear_count += chain.cleanup_bit_0x04_clear_count;
				result.projected_chain_object_branch_attempt_count += chain.object_branch_attempt_count;
				result.projected_chain_object_branch_commit_count += chain.object_branch_commit_count;
				if (chain.stopped_on_object_materialization_required) {
					report.projected_chain_object_branch_blocked_count += 1;
					result.projected_chain_object_branch_blocked_count += 1;
				}
			}
		}
		result.owner_reports.push_back(report);
	}

	result.no_object_projection_chain_complete = result.projected_chain_object_branch_blocked_count == 0;
	return result;
}

RelationScanConsumerResult4a5767 relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(GeneratedCellRecordGrid0x30 &grid, const std::vector<GeneratorRelationOwnerState4a218c> &owners) {
	return relation_scan_consumers_after_0x4a1f3b_bounds_4a5767_impl(grid, nullptr, nullptr, nullptr, owners);
}

RelationScanConsumerResult4a5767 relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(GeneratorObjectPrivateState &state, SourceObjectResolverState4af785 &resolver_state, H3MapedRng &rng, const std::vector<GeneratorRelationOwnerState4a218c> &owners) {
	return relation_scan_consumers_after_0x4a1f3b_bounds_4a5767_impl(state.generated_cell_buffer, &state, &resolver_state, &rng, owners);
}

static bool source_relation_object_coordinate_eligibility_0x49aa93(
		const GeneratorObjectPrivateState &state,
		const SourceObjectDescriptorJoinResult4903e8 &join,
		int32_t x,
		int32_t y,
		int32_t level,
		int32_t relation_owner_byte2) {
	const std::vector<SourceObjectMaskPoint490f3f> body_points =
			source_object_text_mask_points_0x490f3f(join.source_record_copy.passability_mask, false);
	if (body_points.empty()) {
		return false;
	}
	for (const SourceObjectMaskPoint490f3f &point : body_points) {
		const int64_t flat = cell_index(state.width, state.height, x + point.dx, y + point.dy, level);
		if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
			return false;
		}
		const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
		if (!record.word_0x20_known || !record.word_0x24_known || !record.word_0x28_known || !record.word_0x2c_known) {
			return false;
		}
		if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(relation_owner_byte2 & 0xff)) {
			return false;
		}
		if ((record.word_0x24 & 0x3fU) == 9U) {
			return false;
		}
		if ((record.word_0x28 & CELL_DECOR_READY_BIT_25) == 0U || (record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U) {
			return false;
		}
		if ((record.word_0x2c & 0x01U) != 0U) {
			return false;
		}
	}
	return true;
}

SourceBoundedCandidatePickerResult4a7312 source_bounded_endpoint_candidate_picker_0x4a7312(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, uint32_t object_record_key, bool object_record_key_known, const GeneratorRelationOwnerState4a218c &source_relation, H3MapedRng &rng) {
	SourceBoundedCandidatePickerResult4a7312 result;
	result.descriptor_joined = join.joined;
	result.copied_source_record_carried = join.copied_source_record_is_identity_authority;
	result.object_record_key_known = object_record_key_known;
	result.scan_bounds_known = source_relation.scan_bounds_0x20_0x2c_known;
	result.scan_bounds_non_sentinel = relation_scan_bounds_0x4a7312_non_sentinel(source_relation);
	result.scan_bound_low_x_0x20 = source_relation.scan_bound_low_x_0x20;
	result.scan_bound_low_y_0x24 = source_relation.scan_bound_low_y_0x24;
	result.scan_bound_high_x_0x28 = source_relation.scan_bound_high_x_0x28;
	result.scan_bound_high_y_0x2c = source_relation.scan_bound_high_y_0x2c;
	result.relation_owner_byte_known = source_relation.runtime_zone_index >= 0;
	result.relation_owner_byte2 = source_relation.runtime_zone_index;
	result.descriptor_dimensions_known =
			(join.descriptor.descriptor_mask_fields_0x34_0x48_known
					&& join.descriptor.descriptor_width_0x34 > 0
					&& join.descriptor.descriptor_height_0x38 > 0)
			|| (join.source_record_copy.descriptor_mask_fields_0x34_0x48_known
					&& join.source_record_copy.descriptor_width_0x34 > 0
					&& join.source_record_copy.descriptor_height_0x38 > 0);
	result.source_mask_known = join.source_record_copy.passability_mask.size() >= 48U;

	if (!join.joined) {
		result.blocked_reason = join.blocked_reason.empty()
				? "0x4a7312_descriptor_source_join_not_resolved"
				: join.blocked_reason;
		return result;
	}
	if (!object_record_key_known) {
		result.blocked_reason = "0x4a7312_object_record_key_missing_from_caller";
		return result;
	}
	if (!result.scan_bounds_non_sentinel) {
		result.blocked_reason = "0x4a7312_source_relation_scan_bounds_missing_or_constructor_sentinel";
		return result;
	}
	if (!source_relation.coordinate_triple_0x10_0x18_known) {
		result.blocked_reason = "0x4a7312_source_relation_coordinate_triple_missing";
		return result;
	}
	if (!result.relation_owner_byte_known) {
		result.blocked_reason = "0x4a7312_source_relation_owner_byte_missing";
		return result;
	}
	if (!result.descriptor_dimensions_known) {
		result.blocked_reason = "0x4a7312_object_descriptor_dimensions_missing";
		return result;
	}
	if (!result.source_mask_known) {
		result.blocked_reason = "0x4a7312_source_object_passability_mask_missing";
		return result;
	}

	const int32_t level = source_relation.coordinate_level_0x18;
	for (int32_t y = source_relation.scan_bound_low_y_0x24; y < source_relation.scan_bound_high_y_0x2c; ++y) {
		for (int32_t x = source_relation.scan_bound_low_x_0x20; x < source_relation.scan_bound_high_x_0x28; ++x) {
			result.scanned_cell_count += 1;
			const int64_t flat = cell_index(state.width, state.height, x, y, level);
			if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
				result.out_of_bounds_cell_count += 1;
				continue;
			}
			const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
			if (!record.word_0x20_known) {
				result.unknown_cell_word_count += 1;
				continue;
			}
			if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(result.relation_owner_byte2 & 0xff)) {
				result.owner_byte_reject_count += 1;
				continue;
			}
			if (!source_relation_object_coordinate_eligibility_0x49aa93(state, join, x, y, level, result.relation_owner_byte2)) {
				result.eligibility_reject_count_0x49aa93 += 1;
				continue;
			}
			result.accepted_candidates_0x4ae1fd.push_back(SourceBoundedCandidate4a7312 { x, y, level });
		}
	}
	result.accepted_candidate_count = int32_t(result.accepted_candidates_0x4ae1fd.size());
	if (result.accepted_candidates_0x4ae1fd.empty()) {
		result.blocked_reason = "0x4a7312_candidate_vector_empty_after_source_relation_and_0x49aa93_filters";
		return result;
	}

	result.rng_value_0x4e7276 = rng.next();
	result.selected_candidate_index = result.rng_value_0x4e7276 % result.accepted_candidate_count;
	result.selected_candidate = result.accepted_candidates_0x4ae1fd[size_t(result.selected_candidate_index)];
	result.selected_candidate_known = true;
	result.commit_0x4a54a7 = object_footprint_commit_4a54a7(
			state,
			object_record_key,
			join.descriptor.descriptor_type_0x1c,
			result.selected_candidate.x,
			result.selected_candidate.y,
			result.selected_candidate.level,
			join.descriptor.projection_enabled_0x29,
			join.descriptor.source_cell_x_0x2c,
			join.descriptor.source_cell_y_0x30);
	result.committed_through_vtable_slot_0x04 = result.commit_0x4a54a7.object_vector_appended;
	if (!result.committed_through_vtable_slot_0x04) {
		result.blocked_reason = "0x4a7312_vtable_slot_0x04_object_commit_did_not_append";
		return result;
	}
	if (!state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
		object_record.source_descriptor_join_0x4903e8_known = true;
		object_record.descriptor_source_key_0x00 = join.descriptor.source_key_0x00;
		object_record.selected_wrapper_index_0x4af785 = join.resolver_0x4af785.selected_wrapper_index;
		object_record.source_catalog_index_0x49da08 = join.source_catalog_index_0x49da08;
		object_record.copied_source_record_carried = true;
		object_record.source_record_copy = join.source_record_copy;
	}
	return result;
}

WeightedObjectRecord4a93a2 allocate_object_record_0x4a93a2(GeneratorObjectPrivateState &state, int32_t x, int32_t y, int32_t level, int32_t selected_index_0x20, uint32_t enabled_word_0x24, bool enabled_low_byte_0x24) {
	WeightedObjectRecord4a93a2 record;
	record.object_record_vtable_0x00 = WEIGHTED_OBJECT_RECORD_VTABLE_0X540A9C;
	record.object_record_key_allocated_by_0x4a93a2 = true;
	record.object_record_key_known = state.native_object_record_key_allocator_0x4a93a2_known;
	if (state.native_object_record_key_allocator_0x4a93a2_known) {
		record.object_record_key = state.next_native_object_record_key_0x4a93a2;
		state.next_native_object_record_key_0x4a93a2 += 1U;
	}
	record.coordinate_payload_filled_before_0x4a901a = true;
	record.x = x;
	record.y = y;
	record.level = level;
	record.sequence_0x1c = state.object_record_sequence_allocator_0xf44_known
			? state.object_record_sequence_allocator_0xf44
			: -1;
	if (state.object_record_sequence_allocator_0xf44_known) {
		state.object_record_sequence_allocator_0xf44 += 1;
	}
	record.selected_index_0x20 = selected_index_0x20;
	record.enabled_word_0x24 = enabled_word_0x24;
	record.enabled_low_byte_0x24 = enabled_low_byte_0x24;
	state.object_record_allocation_count_0x4a93a2 += 1;
	return record;
}

WeightedObjectRecord4a93a2 allocate_weighted_object_record_0x4a93a2(GeneratorObjectPrivateState &state, int32_t x, int32_t y, int32_t level, int32_t selected_index_0x20, uint32_t enabled_word_0x24, bool enabled_low_byte_0x24) {
	return allocate_object_record_0x4a93a2(state, x, y, level, selected_index_0x20, enabled_word_0x24, enabled_low_byte_0x24);
}

WeightedObjectMaterializationCommitResult4a93a2 object_materialization_commit_from_weighted_record_0x4a93a2_0x4a901a_0x4a54a7(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, const WeightedObjectRecord4a93a2 &record) {
	WeightedObjectMaterializationCommitResult4a93a2 result;
	result.record_vtable_0x540a9c = record.object_record_vtable_0x00 == WEIGHTED_OBJECT_RECORD_VTABLE_0X540A9C;
	result.record_coordinate_payload_filled = record.coordinate_payload_filled_before_0x4a901a;
	result.prep_0x4a901a = object_materialization_prep_from_weighted_record_0x4a93a2_0x4a901a(join, record);
	if (!result.prep_0x4a901a.ready_for_object_vector_commit_0x4a54a7) {
		result.blocked_reason = result.prep_0x4a901a.blocked_reason.empty()
				? "0x4a93a2_0x4a901a_weighted_materialization_not_ready"
				: result.prep_0x4a901a.blocked_reason;
		return result;
	}

	result.commit_0x4a54a7 = object_footprint_commit_4a54a7(state, result.prep_0x4a901a);
	result.committed = result.commit_0x4a54a7.object_vector_appended;
	if (!result.committed) {
		result.blocked_reason = "0x4a54a7_weighted_record_commit_did_not_append_object_vector";
		return result;
	}
	if (!state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
		object_record.weighted_record_0x4a93a2_known = true;
		object_record.object_record_key_allocated_by_0x4a93a2 = record.object_record_key_allocated_by_0x4a93a2;
		object_record.object_record_vtable_0x00 = record.object_record_vtable_0x00;
		object_record.object_record_sequence_0x1c = record.sequence_0x1c;
		object_record.object_record_selected_index_0x20 = record.selected_index_0x20;
		object_record.object_record_enabled_word_0x24 = record.enabled_word_0x24;
		object_record.object_record_enabled_low_byte_0x24 = record.enabled_low_byte_0x24;
	}
	return result;
}

static bool source_order_descriptor_source_bridge_known_0x4a93a2(const SourceObjectDescriptorJoinResult4903e8 &join) {
	const bool source_backed_type98_bridge = !join.joined
			&& join.descriptor.descriptor_type_0x1c == 98
			&& join.descriptor_source_fields_match
			&& join.source_catalog_index_0x49da08 >= 0;
	return join.joined || source_backed_type98_bridge;
}

SourceOrderObjectPlacementResult4a93a2 source_order_object_placement_0x4a93a2(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, int32_t relation_owner_byte2, int32_t anchor_x_0x10, int32_t anchor_y_0x14, int32_t anchor_level_0x18, int32_t scan_low_x_0x20, int32_t scan_low_y_0x24, int32_t scan_high_x_0x28, int32_t scan_high_y_0x2c, int32_t source_pair_key_0x0c, int32_t selected_index_0x20, bool enabled_low_byte_0x24, H3MapedRng &rng) {
	SourceOrderObjectPlacementResult4a93a2 result;
	SourceOrderObjectPlacementState4a93a2 &placement = result.placement_state_0x4a93a2;
	placement.descriptor_source_bridge_known = source_order_descriptor_source_bridge_known_0x4a93a2(join);
	placement.copied_source_record_carried = join.copied_source_record_is_identity_authority || placement.descriptor_source_bridge_known;
	placement.scan_bounds_known = true;
	placement.scan_bounds_non_empty = scan_high_x_0x28 > scan_low_x_0x20 && scan_high_y_0x2c > scan_low_y_0x24;
	placement.relation_owner_byte_known = relation_owner_byte2 >= 0;
	placement.source_pair_key_known = true;
	placement.source_pair_key_not_minus_one = source_pair_key_0x0c != -1;
	placement.relation_owner_byte2 = relation_owner_byte2;
	placement.source_pair_key_0x0c = source_pair_key_0x0c;
	placement.selected_index_0x20 = selected_index_0x20;
	placement.enabled_low_byte_0x24 = enabled_low_byte_0x24;
	placement.anchor_x_0x10 = anchor_x_0x10;
	placement.anchor_y_0x14 = anchor_y_0x14;
	placement.anchor_level_0x18 = anchor_level_0x18;
	placement.scan_bound_low_x_0x20 = scan_low_x_0x20;
	placement.scan_bound_low_y_0x24 = scan_low_y_0x24;
	placement.scan_bound_high_x_0x28 = scan_high_x_0x28;
	placement.scan_bound_high_y_0x2c = scan_high_y_0x2c;
	state.source_order_direct_candidates_0x4a93a2_known = true;

	auto finish_blocked = [&](const std::string &reason) {
		placement.blocked_reason = reason;
		result.blocked_reason = reason;
		state.source_order_direct_candidate_vectors_0x4a93a2.push_back(placement);
		state.source_order_direct_candidate_vector_count_0x4a93a2 = int32_t(state.source_order_direct_candidate_vectors_0x4a93a2.size());
		state.source_order_direct_candidate_total_count_0x4a93a2 += placement.accepted_candidate_count;
		return result;
	};

	if (!placement.descriptor_source_bridge_known) {
		return finish_blocked(join.blocked_reason.empty()
				? "0x4a93a2_descriptor_source_bridge_unresolved"
				: join.blocked_reason);
	}
	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty()) {
		return finish_blocked("0x4a93a2_generated_cell_buffer_missing");
	}
	if (!placement.scan_bounds_non_empty) {
		return finish_blocked("0x4a93a2_scan_bounds_empty_or_unordered");
	}
	if (!placement.relation_owner_byte_known) {
		return finish_blocked("0x4a93a2_relation_owner_byte2_missing");
	}
	if (!placement.source_pair_key_not_minus_one) {
		return finish_blocked("0x4a93a2_source_pair_key_arg_0x0c_minus_one");
	}

	int32_t current_best_distance = placement.best_distance_squared_initial_0x7d00;
	for (int32_t y = scan_low_y_0x24; y < scan_high_y_0x2c; ++y) {
		for (int32_t x = scan_low_x_0x20; x < scan_high_x_0x28; ++x) {
			placement.scanned_cell_count += 1;
			const int64_t flat = cell_index(state.width, state.height, x, y, anchor_level_0x18);
			if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
				placement.out_of_bounds_cell_count += 1;
				continue;
			}
			const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
			if (!record.word_0x20_known) {
				placement.unknown_cell_word_count += 1;
				continue;
			}
			if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(relation_owner_byte2 & 0xff)) {
				placement.owner_byte_reject_count += 1;
				continue;
			}
			const int64_t dx = int64_t(x) - int64_t(anchor_x_0x10);
			const int64_t dy = int64_t(y) - int64_t(anchor_y_0x14);
			const int64_t distance64 = dx * dx + dy * dy;
			if (distance64 > int64_t(current_best_distance)) {
				placement.distance_reject_count += 1;
				continue;
			}
			if (!source_relation_object_coordinate_eligibility_0x49aa93(state, join, x, y, anchor_level_0x18, relation_owner_byte2)) {
				placement.eligibility_reject_count_0x49aa93 += 1;
				continue;
			}
			const int32_t distance = int32_t(distance64);
			if (distance < current_best_distance) {
				current_best_distance = distance;
				placement.best_distance_squared_after_scan = current_best_distance;
				placement.accepted_candidates_0x4ae1fd.clear();
				placement.local_vector_clear_count_0x4ae52a += 1;
			}
			placement.accepted_candidates_0x4ae1fd.push_back(SourceOrderObjectCandidate4a93a2 { x, y, anchor_level_0x18, distance });
			placement.local_vector_append_count_0x4ae1fd += 1;
		}
	}

	placement.accepted_candidate_count = int32_t(placement.accepted_candidates_0x4ae1fd.size());
	state.source_order_direct_candidate_total_count_0x4a93a2 += placement.accepted_candidate_count;
	if (placement.accepted_candidates_0x4ae1fd.empty()) {
		return finish_blocked("0x4a93a2_candidate_vector_empty_after_owner_distance_and_0x49aa93_filters");
	}

	placement.rng_value_0x4e7276 = rng.next();
	placement.selected_candidate_index = placement.rng_value_0x4e7276 % placement.accepted_candidate_count;
	placement.selected_candidate = placement.accepted_candidates_0x4ae1fd[size_t(placement.selected_candidate_index)];
	placement.selected_candidate_known = true;
	state.source_order_direct_selected_count_0x4a93a2 += 1;

	result.object_record_0x4a93a2 = allocate_object_record_0x4a93a2(
			state,
			placement.selected_candidate.x,
			placement.selected_candidate.y,
			placement.selected_candidate.level,
			selected_index_0x20,
			enabled_low_byte_0x24 ? 1U : 0U,
			enabled_low_byte_0x24);
	result.allocated_record_0x4a93a2 = true;
	placement.allocated_record_0x4a93a2 = true;
	placement.object_record_key_known = result.object_record_0x4a93a2.object_record_key_known;
	placement.object_record_key = result.object_record_0x4a93a2.object_record_key;

	result.commit_0x4a93a2_0x4a54a7 = object_materialization_commit_from_weighted_record_0x4a93a2_0x4a901a_0x4a54a7(state, join, result.object_record_0x4a93a2);
	result.committed = result.commit_0x4a93a2_0x4a54a7.committed;
	placement.committed_through_0x4a54a7 = result.committed;
	placement.object_vector_count_after = result.commit_0x4a93a2_0x4a54a7.commit_0x4a54a7.object_vector_count_after;
	if (result.committed) {
		placement.source_pair_success_byte_0x3c_set = true;
		state.source_order_direct_commit_count_0x4a93a2 += 1;
		if (!state.object_records_0xec4_ecc.empty()) {
			ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
			object_record.source_order_direct_record_0x4a8d2c_0x4a93a2_known = true;
			object_record.weighted_record_0x4a93a2_known = false;
		}
	} else {
		result.blocked_reason = result.commit_0x4a93a2_0x4a54a7.blocked_reason.empty()
				? "0x4a93a2_candidate_selected_but_commit_failed"
				: result.commit_0x4a93a2_0x4a54a7.blocked_reason;
		placement.blocked_reason = result.blocked_reason;
	}
	state.source_order_direct_candidate_vectors_0x4a93a2.push_back(placement);
	state.source_order_direct_candidate_vector_count_0x4a93a2 = int32_t(state.source_order_direct_candidate_vectors_0x4a93a2.size());
	return result;
}

SourceOrderObjectDispatcherResult4a8d2c source_order_object_dispatcher_0x4a8d2c(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, int32_t relation_owner_byte2, int32_t anchor_x_0x10, int32_t anchor_y_0x14, int32_t anchor_level_0x18, int32_t scan_low_x_0x20, int32_t scan_low_y_0x24, int32_t scan_high_x_0x28, int32_t scan_high_y_0x2c, int32_t source_pair_key_0x0c, int32_t lane_index_0x1c, H3MapedRng &rng, bool source_field_0x30_known, int32_t source_field_0x30, bool source_field_0x34_known, int32_t source_field_0x34) {
	SourceOrderObjectDispatcherResult4a8d2c result;
	result.source_field_0x20_known = join.source_record_copy.raw_field_0x20_known;
	result.source_field_0x20 = join.source_record_copy.raw_field_0x20;
	result.source_field_0x24_known = join.source_record_copy.raw_field_0x24_known;
	result.source_field_0x24 = join.source_record_copy.raw_field_0x24;
	result.source_field_0x30_known = join.source_record_copy.raw_field_0x30_known || source_field_0x30_known;
	result.source_field_0x30 = join.source_record_copy.raw_field_0x30_known ? join.source_record_copy.raw_field_0x30 : source_field_0x30;
	result.source_field_0x34_known = join.source_record_copy.raw_field_0x34_known || source_field_0x34_known;
	result.source_field_0x34 = join.source_record_copy.raw_field_0x34_known ? join.source_record_copy.raw_field_0x34 : source_field_0x34;
	result.lane_index_0x1c = lane_index_0x1c;
	result.source_pair_key_0x0c = source_pair_key_0x0c;

	auto append_branch = [&](int32_t offset, int32_t value, bool known, int32_t selected_index, bool flag) {
		SourceOrderObjectDispatcherBranch4a8d2c branch;
		branch.source_field_offset = offset;
		branch.source_field_value = value;
		branch.source_field_known = known;
		branch.branch_gate_positive = known && value > 0;
		branch.selected_index_0x20 = selected_index;
		branch.enabled_low_byte_0x24 = flag;
		result.branches.push_back(branch);
	};

	append_branch(0x24, result.source_field_0x24, result.source_field_0x24_known, lane_index_0x1c, true);
	append_branch(0x20, result.source_field_0x20, result.source_field_0x20_known, lane_index_0x1c, false);
	append_branch(0x34, result.source_field_0x34, result.source_field_0x34_known, -1, true);
	append_branch(0x30, result.source_field_0x30, result.source_field_0x30_known, -1, false);

	for (size_t index = 0; index < result.branches.size(); ++index) {
		SourceOrderObjectDispatcherBranch4a8d2c &branch = result.branches[index];
		if (!branch.source_field_known) {
			branch.blocked_reason = "0x4a8d2c_source_field_unrepresented_in_native_source_record";
			continue;
		}
		if (!branch.branch_gate_positive) {
			branch.blocked_reason = "0x4a8d2c_source_field_gate_not_positive";
			continue;
		}
		branch.attempted = true;
		result.attempted_branch_count += 1;
		branch.placement_0x4a93a2 = source_order_object_placement_0x4a93a2(
				state,
				join,
				relation_owner_byte2,
				anchor_x_0x10,
				anchor_y_0x14,
				anchor_level_0x18,
				scan_low_x_0x20,
				scan_low_y_0x24,
				scan_high_x_0x28,
				scan_high_y_0x2c,
				source_pair_key_0x0c,
				branch.selected_index_0x20,
				branch.enabled_low_byte_0x24,
				rng);
		if (branch.placement_0x4a93a2.committed) {
			result.selected_branch_index = int32_t(index);
			result.committed = true;
			return result;
		}
		branch.blocked_reason = branch.placement_0x4a93a2.blocked_reason;
	}

	result.blocked_reason = result.attempted_branch_count == 0
			? "0x4a8d2c_no_positive_source_field_branch"
			: "0x4a8d2c_all_attempted_0x4a93a2_branches_failed";
	return result;
}

WeightedObjectCandidateScanResult4a901a weighted_object_candidate_scan_0x4a901a(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, int32_t relation_owner_byte2, int32_t scan_low_x, int32_t scan_low_y, int32_t scan_high_x, int32_t scan_high_y, int32_t level, int32_t threshold_arg_0x18, H3MapedRng &rng, int32_t selected_index_0x20, uint32_t enabled_word_0x24, bool enabled_low_byte_0x24) {
	WeightedObjectCandidateScanResult4a901a result;
	WeightedObjectCandidateVectorState4a901a &vector_state = result.vector_state_0x4a901a;
	vector_state.scan_bounds_known = true;
	vector_state.scan_bounds_non_empty = scan_high_x > scan_low_x && scan_high_y > scan_low_y;
	vector_state.relation_owner_byte_known = relation_owner_byte2 >= 0;
	vector_state.threshold_arg_0x18_known = threshold_arg_0x18 >= 0;
	vector_state.relation_owner_byte2 = relation_owner_byte2;
	vector_state.scan_bound_low_x = scan_low_x;
	vector_state.scan_bound_low_y = scan_low_y;
	vector_state.scan_bound_high_x = scan_high_x;
	vector_state.scan_bound_high_y = scan_high_y;
	vector_state.level = level;
	vector_state.threshold_arg_0x18_initial = threshold_arg_0x18;
	vector_state.threshold_arg_0x18_after_scan = threshold_arg_0x18;

	const bool source_backed_type98_bridge = !join.joined
			&& join.descriptor.descriptor_type_0x1c == 98
			&& join.descriptor_source_fields_match
			&& join.source_catalog_index_0x49da08 >= 0;
	vector_state.descriptor_source_bridge_known = join.joined || source_backed_type98_bridge;
	vector_state.copied_source_record_carried = join.copied_source_record_is_identity_authority || source_backed_type98_bridge;
	state.weighted_candidate_vectors_0x4a901a_known = true;

	auto finish_blocked = [&](const std::string &reason) {
		vector_state.blocked_reason = reason;
		result.blocked_reason = reason;
		state.weighted_candidate_vectors_0x4a901a.push_back(vector_state);
		state.weighted_candidate_vector_count_0x4a901a = int32_t(state.weighted_candidate_vectors_0x4a901a.size());
		state.weighted_candidate_total_count_0x4a901a += vector_state.accepted_candidate_count;
		return result;
	};

	if (!vector_state.descriptor_source_bridge_known) {
		return finish_blocked(join.blocked_reason.empty()
				? "0x4a901a_weighted_descriptor_source_bridge_unresolved"
				: join.blocked_reason);
	}
	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty()) {
		return finish_blocked("0x4a901a_generated_cell_buffer_missing");
	}
	if (!vector_state.scan_bounds_non_empty) {
		return finish_blocked("0x4a901a_scan_bounds_empty_or_unordered");
	}
	if (!vector_state.relation_owner_byte_known) {
		return finish_blocked("0x4a901a_relation_owner_byte2_missing");
	}
	if (!vector_state.threshold_arg_0x18_known) {
		return finish_blocked("0x4a901a_threshold_arg_0x18_missing");
	}

	int32_t current_threshold = threshold_arg_0x18;
	for (int32_t y = scan_low_y; y < scan_high_y; ++y) {
		for (int32_t x = scan_low_x; x < scan_high_x; ++x) {
			vector_state.scanned_cell_count += 1;
			const int64_t flat = cell_index(state.width, state.height, x, y, level);
			if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
				vector_state.out_of_bounds_cell_count += 1;
				continue;
			}
			const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
			if (!record.word_0x20_known) {
				vector_state.unknown_cell_word_count += 1;
				continue;
			}
			if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(relation_owner_byte2 & 0xff)) {
				vector_state.owner_byte_reject_count += 1;
				continue;
			}
			const uint32_t low_word_score = record.word_0x20 & 0xffffU;
			if (low_word_score < uint32_t(current_threshold)) {
				vector_state.value_floor_reject_count += 1;
				continue;
			}
			if (!source_relation_object_coordinate_eligibility_0x49aa93(state, join, x, y, level, relation_owner_byte2)) {
				vector_state.eligibility_reject_count_0x49aa93 += 1;
				continue;
			}
			if (low_word_score > uint32_t(current_threshold)) {
				current_threshold = int32_t(low_word_score);
				vector_state.threshold_arg_0x18_after_scan = current_threshold;
				vector_state.accepted_candidates_0x4ae1fd.clear();
				vector_state.local_vector_clear_count_0x4ae52a += 1;
			}
			vector_state.accepted_candidates_0x4ae1fd.push_back(WeightedObjectCandidate4a901a { x, y, level, low_word_score });
			vector_state.local_vector_append_count_0x4ae1fd += 1;
		}
	}

	vector_state.accepted_candidate_count = int32_t(vector_state.accepted_candidates_0x4ae1fd.size());
	state.weighted_candidate_total_count_0x4a901a += vector_state.accepted_candidate_count;
	if (vector_state.accepted_candidates_0x4ae1fd.empty()) {
		return finish_blocked("0x4a901a_weighted_candidate_vector_empty_after_value_floor_and_0x49aa93_filters");
	}

	vector_state.rng_value_0x4e7276 = rng.next();
	vector_state.selected_candidate_index = vector_state.rng_value_0x4e7276 % vector_state.accepted_candidate_count;
	vector_state.selected_candidate = vector_state.accepted_candidates_0x4ae1fd[size_t(vector_state.selected_candidate_index)];
	vector_state.selected_candidate_known = true;
	state.weighted_candidate_selected_count_0x4a901a += 1;

	result.weighted_record_0x4a93a2 = allocate_weighted_object_record_0x4a93a2(
			state,
			vector_state.selected_candidate.x,
			vector_state.selected_candidate.y,
			vector_state.selected_candidate.level,
			selected_index_0x20,
			enabled_word_0x24,
			enabled_low_byte_0x24);
	result.allocated_record_0x4a93a2 = true;
	vector_state.allocated_record_0x4a93a2 = true;
	vector_state.object_record_key_known = result.weighted_record_0x4a93a2.object_record_key_known;
	vector_state.object_record_key = result.weighted_record_0x4a93a2.object_record_key;

	result.commit_0x4a93a2_0x4a901a_0x4a54a7 = object_materialization_commit_from_weighted_record_0x4a93a2_0x4a901a_0x4a54a7(state, join, result.weighted_record_0x4a93a2);
	result.committed = result.commit_0x4a93a2_0x4a901a_0x4a54a7.committed;
	vector_state.committed_through_0x4a54a7 = result.committed;
	vector_state.object_vector_count_after = result.commit_0x4a93a2_0x4a901a_0x4a54a7.commit_0x4a54a7.object_vector_count_after;
	if (result.committed) {
		state.weighted_candidate_commit_count_0x4a901a += 1;
	} else {
		result.blocked_reason = result.commit_0x4a93a2_0x4a901a_0x4a54a7.blocked_reason.empty()
				? "0x4a901a_weighted_candidate_selected_but_commit_failed"
				: result.commit_0x4a93a2_0x4a901a_0x4a54a7.blocked_reason;
		vector_state.blocked_reason = result.blocked_reason;
	}
	state.weighted_candidate_vectors_0x4a901a.push_back(vector_state);
	state.weighted_candidate_vector_count_0x4a901a = int32_t(state.weighted_candidate_vectors_0x4a901a.size());
	return result;
}

static bool endpoint_vector_contains_key_4a5e73(const std::vector<EndpointPointerRecord4a5e73> &records, int32_t key_0x20) {
	return std::any_of(records.begin(), records.end(), [&](const EndpointPointerRecord4a5e73 &record) {
		return record.key_0x20 == key_0x20;
	});
}

EndpointMaterializationResult4a5e73 endpoint_materialization_4a5e73(GeneratedCellRecordGrid0x30 &grid, EndpointMaterializationState4a5e73 &state, int32_t x, int32_t y, int32_t level, int32_t repeat_count, const SourceBoundedCandidatePickerResult4a7312 *projection_helper_0x4a7312) {
	EndpointMaterializationResult4a5e73 result;
	result.original_cursor_0xf5c = state.cursor_0xf5c;
	result.return_value = -1;

	result.d8_match_found = endpoint_vector_contains_key_4a5e73(state.endpoint_vector_d8_dc, state.cursor_0xf5c);
	if (!result.d8_match_found) {
		return result;
	}

	result.c8_match_found = endpoint_vector_contains_key_4a5e73(state.endpoint_vector_c8_cc, state.cursor_0xf5c);
	if (!result.c8_match_found) {
		result.return_value = 0;
		return result;
	}

	if (projection_helper_0x4a7312 == nullptr || !projection_helper_0x4a7312->committed_through_vtable_slot_0x04) {
		result.rejected_by_projection_helper_0x4a7312 = true;
		return result;
	}

	for (int32_t offset = 0; offset < repeat_count; ++offset) {
		const int64_t flat = cell_index(grid.width, grid.height, x + offset, y, level);
		if (flat < 0 || flat >= int64_t(grid.records.size())) {
			result.out_of_bounds_cell_count += 1;
			continue;
		}
		GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
		if (!record.word_0x28_known || !record.word_0x2c_known) {
			result.skipped_unknown_word_count += 1;
			continue;
		}
		record.word_0x2c &= ~uint32_t(0x1fU);
		record.word_0x28 |= CELL_OCCUPIED_BLOCKED_BIT_27;
		record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
		result.mutated_cell_count += 1;
	}

	if (state.cursor_0xf5c >= 0 && state.cursor_0xf5c < int32_t(state.byte_state_vector_1104_1108.size())) {
		state.byte_state_vector_1104_1108[size_t(state.cursor_0xf5c)] = 1U;
		result.byte_state_marked = true;
	}

	state.cursor_0xf5c = 0;
	while (state.cursor_0xf5c < int32_t(state.byte_state_vector_1104_1108.size())
			&& state.byte_state_vector_1104_1108[size_t(state.cursor_0xf5c)] != 0U) {
		state.cursor_0xf5c += 1;
		result.cursor_advanced_count += 1;
	}

	result.return_value = result.original_cursor_0xf5c;
	return result;
}

bool span_cell_in_bounds_4a325d(int32_t width, int32_t height, int32_t level_count, const SpanRecord &span) {
	return span.x >= 0 && span.x < width && span.y >= 0 && span.y < height && span.level >= 0 && span.level < level_count;
}

bool generated_cell_owner_unassigned_4a325d(const std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	const int64_t key = generated_cell_flat_key_4a325d(width, height, x, y, level);
	return key >= 0 && key < int64_t(generated_cell_word_0x20.size()) && (generated_cell_word_0x20[size_t(key)] & UNASSIGNED_ZONE_WORD) == UNASSIGNED_ZONE_WORD;
}

bool private_zone_word_unassigned_4a325d(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	const int64_t key = generated_cell_flat_key_4a325d(width, height, x, y, level);
	return key >= 0 && key < int64_t(zone_words.size()) && (zone_words[size_t(key)] & UNASSIGNED_ZONE_WORD) == UNASSIGNED_ZONE_WORD;
}

ClipResult clip_point_4a2b33(int32_t x1, int32_t y1, int32_t x2, int32_t y2, const ClipBounds &bounds) {
	ClipResult result;
	result.x = x1;
	result.y = y1;
	result.branch = "0x4a2b5d_input_or_fallback";
	if (x1 >= bounds.min_x && x1 < bounds.max_x && y1 >= bounds.min_y && y1 < bounds.max_y) {
		result.input_inside = true;
		result.branch = "0x4a2b5d_input_inside";
		return result;
	}

	int32_t clipped_x = x1;
	int32_t clipped_y = y1;
	const int32_t dx = x2 - x1;
	const int32_t dy = y2 - y1;
	auto accept_original_x = [&](const std::string &branch) {
		result.x = x1;
		result.y = clipped_y;
		result.branch = branch;
		return result;
	};
	auto accept_current = [&](const std::string &branch) {
		result.x = clipped_x;
		result.y = clipped_y;
		result.branch = branch;
		return result;
	};

	if (x1 < bounds.min_x && dx != 0) {
		const int32_t delta = bounds.min_x - x1;
		clipped_x = x1 + imul_low_idiv_i32(dx, delta, dx);
		clipped_y = y1 + imul_low_idiv_i32(dy, delta, dx);
		if (y1 >= bounds.min_y && clipped_y < bounds.min_y) {
			return accept_original_x("0x4a2bb5_left_edge_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_original_x("0x4a2bb5_left_edge_crosses_max_y");
		}
	}

	if (clipped_y < bounds.min_y && dy != 0) {
		const int32_t delta = bounds.min_y - clipped_y;
		const int32_t next_x = clipped_x + imul_low_idiv_i32(dx, delta, dy);
		const int32_t next_y = clipped_y + imul_low_idiv_i32(dy, delta, dy);
		clipped_x = next_x;
		clipped_y = next_y;
		if (x1 >= bounds.min_x && clipped_x < bounds.min_x) {
			return accept_original_x("0x4a2bb5_min_y_crosses_min_x");
		}
		if (x1 < bounds.max_x && clipped_x >= bounds.max_x) {
			return accept_original_x("0x4a2bb5_min_y_crosses_max_x");
		}
	}

	if (clipped_x >= bounds.max_x && dx != 0) {
		const int32_t delta = bounds.max_x - clipped_x - 1;
		clipped_x = clipped_x + imul_low_idiv_i32(dx, delta, dx);
		clipped_y = clipped_y + imul_low_idiv_i32(dy, delta, dx);
		if (y1 >= bounds.min_y && clipped_y < bounds.min_y) {
			return accept_original_x("0x4a2bb5_max_x_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_original_x("0x4a2bb5_max_x_crosses_max_y");
		}
	}

	if (clipped_y >= bounds.max_y && dy != 0) {
		const int32_t delta = bounds.max_y - clipped_y - 1;
		clipped_x = clipped_x + imul_low_idiv_i32(dx, delta, dy);
		clipped_y = clipped_y + imul_low_idiv_i32(dy, delta, dy);
		if (x1 >= bounds.min_x && clipped_x < bounds.min_x) {
			return accept_original_x("0x4a2ccf_max_y_crosses_min_x");
		}
		if (x1 < bounds.max_x && clipped_x >= bounds.max_x) {
			return accept_original_x("0x4a2ccf_max_y_crosses_max_x");
		}
	}

	return accept_current("0x4a2b5d_fallback_current");
}

bool point_inside_bounds_4a2777(const ClipResult &point, const ClipBounds &bounds) {
	return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
}

const char *boundary_vector_append_callsite_label_4a2777(uint32_t callsite) {
	switch (callsite) {
		case BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_0:
			return "0x4a28c8_rectangle_fallback_vertex_0";
		case BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_1:
			return "0x4a28dc_rectangle_fallback_vertex_1";
		case BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_2:
			return "0x4a28f3_rectangle_fallback_vertex_2";
		case BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_3:
			return "0x4a2907_rectangle_fallback_vertex_3";
		case BOUNDARY_VECTOR_APPEND_4A2777_SELECTED_CLIPPED_ENDPOINT:
			return "0x4a2990_selected_clipped_endpoint";
		case BOUNDARY_VECTOR_APPEND_4A2777_WRAP_CONTINUATION_ENDPOINT:
			return "0x4a2adc_wrap_continuation_endpoint";
		case BOUNDARY_VECTOR_APPEND_4A2777_FINAL_CLIPPED_ENDPOINT:
			return "0x4a2b1e_final_clipped_endpoint";
		default:
			return "";
	}
}

bool boundary_vector_append_callsite_recovered_4a2777(uint32_t callsite) {
	return boundary_vector_append_callsite_label_4a2777(callsite)[0] != '\0';
}

bool boundary_vector_append_4a2777(BoundaryVector4a2777 &vector, int32_t x, int32_t y, uint32_t callsite) {
	const char *label = boundary_vector_append_callsite_label_4a2777(callsite);
	if (label[0] == '\0') {
		vector.rejected_unknown_callsite_count += 1;
		return false;
	}
	BoundaryVectorRecord4a2777 record;
	record.x = x;
	record.y = y;
	record.append_callsite = callsite;
	record.append_label = label;
	vector.records.push_back(record);
	vector.append_counts_by_callsite[callsite] += 1;
	return true;
}

bool player_filter_allows_4a218c(int32_t min_human, int32_t max_human, int32_t min_total, int32_t max_total, int32_t human_count, int32_t player_count) {
	return human_count >= min_human
			&& human_count <= max_human
			&& player_count >= min_total
			&& player_count <= max_total;
}

PlayerSlotAssignmentResult4ac62a player_slot_assignment_4ac62a_4ac6ec(int32_t human_count, int32_t player_count, uint8_t human_capable_source_owner_mask, uint8_t player_capable_source_owner_mask, uint8_t selected_color_mask) {
	PlayerSlotAssignmentResult4ac62a result;
	result.requested_human_count = std::max<int32_t>(0, human_count);
	result.requested_player_count = std::max<int32_t>(result.requested_human_count, player_count);
	result.raw_ee0_slots.assign(8, -1);
	result.mapped_ee4_slots.assign(8, -1);
	result.selected_color_order_ed8.reserve(8);

	const uint8_t effective_selected_mask = selected_color_mask == 0U ? 0xffU : selected_color_mask;
	for (int32_t color = 0; color < 8; ++color) {
		if ((effective_selected_mask & (uint8_t(1U) << color)) != 0U) {
			result.selected_color_order_ed8.push_back(color);
		}
	}
	for (int32_t color = 0; color < 8; ++color) {
		if ((effective_selected_mask & (uint8_t(1U) << color)) == 0U) {
			result.selected_color_order_ed8.push_back(color);
		}
	}

	std::array<bool, 8> human_capable {};
	std::array<bool, 8> player_capable {};
	for (int32_t source_owner = 0; source_owner < 8; ++source_owner) {
		human_capable[size_t(source_owner)] = (human_capable_source_owner_mask & (uint8_t(1U) << source_owner)) != 0U;
		player_capable[size_t(source_owner)] = (player_capable_source_owner_mask & (uint8_t(1U) << source_owner)) != 0U;
	}

	int32_t assigned = 0;
	int32_t source_owner_scan = 0;
	bool complete = true;
	for (; assigned < result.requested_human_count; ++assigned) {
		while (source_owner_scan < 8 && !human_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8 || assigned >= int32_t(result.selected_color_order_ed8.size())) {
			complete = false;
			break;
		}
		player_capable[size_t(source_owner_scan)] = false;
		const int32_t actual_color = result.selected_color_order_ed8[size_t(assigned)];
		result.raw_ee0_slots[size_t(source_owner_scan)] = actual_color;
		result.mapped_ee4_slots[size_t(source_owner_scan)] = actual_color;
		result.assignments.push_back(PlayerSlotAssignmentRecord4ac62a { source_owner_scan, actual_color, true });
		++source_owner_scan;
	}

	source_owner_scan = 0;
	for (; assigned < result.requested_player_count; ++assigned) {
		while (source_owner_scan < 8 && !player_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8 || assigned >= int32_t(result.selected_color_order_ed8.size())) {
			complete = false;
			break;
		}
		const int32_t actual_color = result.selected_color_order_ed8[size_t(assigned)];
		result.raw_ee0_slots[size_t(source_owner_scan)] = actual_color;
		result.mapped_ee4_slots[size_t(source_owner_scan)] = actual_color;
		result.assignments.push_back(PlayerSlotAssignmentRecord4ac62a { source_owner_scan, actual_color, false });
		++source_owner_scan;
	}
	result.assigned_player_count = int32_t(result.assignments.size());
	result.complete = complete && result.assigned_player_count == result.requested_player_count;
	return result;
}

RuntimeSeedBuildResult4a218c runtime_seed_inputs_from_template_records_4a218c_4a1f3b(const std::vector<TemplateZoneRecord4a218c> &zones, const std::vector<TemplateLinkRecord4a1f3b> &links, const PlayerSlotAssignmentResult4ac62a &assignment, int32_t human_count, int32_t player_count) {
	RuntimeSeedBuildResult4a218c result;
	if (!assignment.complete) {
		result.blocked = true;
		return result;
	}

	struct SourceRuntimeIndex {
		int32_t source_zone_id = -1;
		int32_t runtime_zone_index = -1;
	};
	std::vector<SourceRuntimeIndex> runtime_index_by_source_zone;
	runtime_index_by_source_zone.reserve(zones.size());

	for (int32_t source_position = 0; source_position < int32_t(zones.size()); ++source_position) {
		const TemplateZoneRecord4a218c &zone = zones[size_t(source_position)];
		if (!player_filter_allows_4a218c(
					zone.player_filter_min_human,
					zone.player_filter_max_human,
					zone.player_filter_min_total,
					zone.player_filter_max_total,
					human_count,
					player_count)) {
			result.skipped_zone_filter_count += 1;
			continue;
		}
		RuntimeZoneSeedInput4a218c seed;
		seed.runtime_zone_index = int32_t(result.runtime_zone_seeds.size());
		seed.source_zone_id = zone.source_zone_id;
		seed.source_index = zone.source_index >= 0 ? zone.source_index : (zone.source_zone_id > 0 ? zone.source_zone_id - 1 : source_position);
		seed.h3maped_zone_word_id = zone.h3maped_zone_word_id >= 0 ? zone.h3maped_zone_word_id : seed.source_index;
		seed.source_bucket = zone.source_bucket;
		seed.source_owner_index = zone.source_owner_index;
		if (zone.source_owner_index >= 0 && zone.source_owner_index < int32_t(assignment.mapped_ee4_slots.size())) {
			seed.actual_player_color = assignment.mapped_ee4_slots[size_t(zone.source_owner_index)];
		} else {
			seed.actual_player_color = -1;
		}
		seed.source_base_size = zone.source_base_size;
		seed.allowed_town_mask_0x41_0x49 = zone.allowed_town_mask_0x41_0x49;
		seed.selected_town_choice_index_0x49b3c1 = -1;
		seed.terrain_match_to_town_0x84 = zone.terrain_match_to_town_0x84;
		seed.allowed_terrain_mask_0x85_0x8c = zone.allowed_terrain_mask_0x85_0x8c;
		seed.source_payload = zone.source_payload;
		runtime_index_by_source_zone.push_back(SourceRuntimeIndex { zone.source_zone_id, seed.runtime_zone_index });
		result.runtime_zone_seeds.push_back(seed);
	}

	auto runtime_index_for_source_zone = [&](int32_t source_zone_id) {
		for (const SourceRuntimeIndex &entry : runtime_index_by_source_zone) {
			if (entry.source_zone_id == source_zone_id) {
				return entry.runtime_zone_index;
			}
		}
		return -1;
	};

	for (const TemplateLinkRecord4a1f3b &link : links) {
		if (!player_filter_allows_4a218c(
					link.player_filter_min_human,
					link.player_filter_max_human,
					link.player_filter_min_total,
					link.player_filter_max_total,
					human_count,
					player_count)) {
			result.skipped_link_filter_count += 1;
			continue;
		}
		const int32_t runtime_a = runtime_index_for_source_zone(link.source_zone_a);
		const int32_t runtime_b = runtime_index_for_source_zone(link.source_zone_b);
		if (runtime_a < 0 || runtime_b < 0) {
			result.missing_link_endpoint_count += 1;
			continue;
		}
		result.runtime_links.push_back(RuntimeLinkSeedInput4a218c {
			runtime_a,
			runtime_b,
			link.guard_value,
			link.wide,
			link.border_guard,
			link.source_zone_a,
			link.source_zone_b,
			link.source_endpoint_a,
			link.source_endpoint_b,
		});
	}
	return result;
}

CoordinateSeedResult4a218c coordinate_seed_runtime_zone_boundary_inputs_4a218c_4a1f3b_4a19ed(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state_after_template_selection, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones, const std::vector<RuntimeLinkSeedInput4a218c> &links) {
	CoordinateSeedResult4a218c result;
	result.rng_state_before = rng_state_after_template_selection;
	result.rng_state_after = rng_state_after_template_selection;
	result.generator_mode_0x10b8 = generator_mode_0x10b8;
	result.level_count = level_count;
	result.map_width = width;
	result.map_height = height;
	if (level_count != 1 || width <= 0 || height <= 0) {
		result.blocked = true;
		return result;
	}

	std::vector<CoordinateZone4a218c> zones;
	zones.reserve(runtime_zones.size());
	for (int32_t index = 0; index < int32_t(runtime_zones.size()); ++index) {
		const RuntimeZoneSeedInput4a218c &input = runtime_zones[size_t(index)];
		CoordinateZone4a218c zone;
		zone.runtime_zone_index = input.runtime_zone_index >= 0 ? input.runtime_zone_index : index;
		zone.source_zone_id = input.source_zone_id;
		zone.source_index = input.source_index >= 0 ? input.source_index : zone.runtime_zone_index;
		zone.h3maped_zone_word_id = input.h3maped_zone_word_id;
		zone.source_bucket = input.source_bucket;
		zone.source_owner_index = input.source_owner_index;
		zone.actual_player_color = input.actual_player_color;
		zone.source_base_size = input.source_base_size;
		zone.allowed_town_mask_0x41_0x49 = input.allowed_town_mask_0x41_0x49;
		zone.selected_town_choice_index_0x49b3c1 = input.selected_town_choice_index_0x49b3c1;
		zone.terrain_match_to_town_0x84 = input.terrain_match_to_town_0x84;
		zone.allowed_terrain_mask_0x85_0x8c = input.allowed_terrain_mask_0x85_0x8c;
		zone.source_payload = input.source_payload;
		zone.scaled_size = input.source_base_size;
		zones.push_back(zone);
	}
	int32_t minimum_source_base_size = std::numeric_limits<int32_t>::max();
	for (const CoordinateZone4a218c &zone : zones) {
		if (zone.source_base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, zone.source_base_size);
		}
	}
	if (minimum_source_base_size == std::numeric_limits<int32_t>::max()) {
		minimum_source_base_size = 0;
	}
	result.minimum_source_base_size = minimum_source_base_size;
	result.coordinate_prune_divisor_4a218c = coordinate_prune_divisor_from_generator_mode_4a218c(generator_mode_0x10b8);
	result.coordinate_prune_span_budget_4a218c = result.coordinate_prune_divisor_4a218c > 0
			? idiv_i32(std::min(imul_low_i32(minimum_source_base_size, width), imul_low_i32(minimum_source_base_size, height)), result.coordinate_prune_divisor_4a218c)
			: 0;

	H3MapedRng rng;
	rng.state = rng_state_after_template_selection;
	std::vector<int32_t> placed_positions;
	auto place_zone = [&](int32_t zone_position, const std::string &pass_id, const std::vector<int32_t> &visible_positions) {
		CoordinatePlacementStep4a1f3b step;
		step.runtime_zone_index = runtime_index_for_coordinate_zone(zones[size_t(zone_position)], zone_position);
		step.pass_id = pass_id;
		std::vector<CoordinateCandidate4a17f5> candidates;
		if (visible_positions.empty()) {
			candidates.push_back(CoordinateCandidate4a17f5 { 0, 0, 0 });
			step.candidate_source = "0x4a1f7b_empty_runtime_vector_origin";
		} else {
			for (const RuntimeLinkSeedInput4a218c &link : links) {
				const int32_t current_runtime_index = runtime_index_for_coordinate_zone(zones[size_t(zone_position)], zone_position);
				int32_t other_runtime_index = -1;
				if (link.from_index == current_runtime_index) {
					other_runtime_index = link.to_index;
				} else if (link.to_index == current_runtime_index) {
					other_runtime_index = link.from_index;
				}
				const int32_t other_position = coordinate_zone_position_for_runtime_index(zones, other_runtime_index);
				if (other_position < 0 || std::find(visible_positions.begin(), visible_positions.end(), other_position) == visible_positions.end()) {
					continue;
				}
				step.explicit_link_base_count += 1;
				append_angle_candidates_4a17f5(zones[size_t(other_position)], zones[size_t(zone_position)], zones, visible_positions, candidates);
			}
			if (candidates.empty()) {
				for (const int32_t other_position : visible_positions) {
					append_angle_candidates_4a17f5(zones[size_t(other_position)], zones[size_t(zone_position)], zones, visible_positions, candidates);
				}
				step.candidate_source = "0x4a2069_existing_runtime_zone_fallback";
			} else {
				step.candidate_source = "0x4a200c_explicit_source_link_endpoint";
			}
		}
		step.candidate_count_before_prune = int32_t(candidates.size());
		step.candidates_before_prune_4a17f5 = candidates;
		prune_candidates_4a1ad8_single_level(zones[size_t(zone_position)], zone_position, zones, visible_positions, links, result.coordinate_prune_span_budget_4a218c, candidates);
		step.candidate_count_after_prune = int32_t(candidates.size());
		step.candidates_after_prune_4a1ad8 = candidates;
			if (candidates.empty()) {
				step.blocked = true;
				result.blocked = true;
				result.placement_steps.push_back(step);
				return;
			}
			const int32_t rng_value = rng.next();
			result.rng_call_count += 1;
			const int32_t selected_index = rng_value % int32_t(candidates.size());
			const CoordinateCandidate4a17f5 selected = candidates[size_t(selected_index)];
		zones[size_t(zone_position)].x = selected.x;
		zones[size_t(zone_position)].y = selected.y;
		zones[size_t(zone_position)].level = selected.level;
		step.rng_value = rng_value;
		step.selected_candidate_index = selected_index;
		step.selected_candidate_known = true;
		step.selected_candidate = selected;
		result.placement_steps.push_back(step);
	};

	for (int32_t zone_position = 0; zone_position < int32_t(zones.size()); ++zone_position) {
		const int32_t rng_calls_before_town_choice = result.rng_call_count;
		zones[size_t(zone_position)].selected_town_choice_index_0x49b3c1 = runtime_town_choice_49b3c1(
				zones[size_t(zone_position)].allowed_town_mask_0x41_0x49,
				rng,
				result.rng_call_count);
		result.town_choice_rng_call_count_0x49b3c1 += result.rng_call_count - rng_calls_before_town_choice;
		place_zone(zone_position, "0x4a2226_initial_runtime_zone_insertion", placed_positions);
		placed_positions.push_back(zone_position);
	}
	std::vector<int32_t> all_positions;
	for (int32_t zone_position = 0; zone_position < int32_t(zones.size()); ++zone_position) {
		all_positions.push_back(zone_position);
	}
	for (int32_t pass = 0; pass < 2; ++pass) {
		for (int32_t zone_position = 0; zone_position < int32_t(zones.size()); ++zone_position) {
			place_zone(zone_position, pass == 0 ? "0x4a22b3_refinement_pass_1" : "0x4a22b3_refinement_pass_2", all_positions);
		}
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const CoordinateZone4a218c &zone : zones) {
		min_y = std::min(zone.y - zone.source_base_size, min_y);
		min_x = std::min(zone.x - zone.source_base_size, min_x);
		max_y = std::max(zone.y + zone.source_base_size + 1, max_y);
		max_x = std::max(zone.x + zone.source_base_size + 1, max_x);
	}
	const int32_t bbox_height = max_y - min_y;
	const int32_t bbox_width = max_x - min_x;
	const int32_t bbox_span = std::max(bbox_height, bbox_width);
	const int32_t map_span = std::min(width, height);
	const int32_t offset_y = (min_y - bbox_span + max_y) / 2;
	const int32_t offset_x = (min_x - bbox_span + max_x) / 2;
	result.min_y_before_rescale = min_y;
	result.min_x_before_rescale = min_x;
	result.max_y_before_rescale = max_y;
	result.max_x_before_rescale = max_x;
	result.bbox_span = bbox_span;
	result.map_span = map_span;
	result.offset_y = offset_y;
	result.offset_x = offset_x;

		result.boundary_inputs.reserve(zones.size());
		for (int32_t zone_position = 0; zone_position < int32_t(zones.size()); ++zone_position) {
			CoordinateZone4a218c &zone = zones[size_t(zone_position)];
		if (bbox_span > 0) {
			zone.x = ((zone.x - offset_x) * map_span) / bbox_span;
			zone.y = ((zone.y - offset_y) * map_span) / bbox_span;
			zone.scaled_size = (zone.source_base_size * map_span) / bbox_span;
		} else {
			zone.scaled_size = zone.source_base_size;
		}
		RuntimeZoneBoundaryInput4a3a03 input;
		input.footprint.runtime_zone_index = runtime_index_for_coordinate_zone(zone, zone_position);
		input.footprint.source_zone_id = zone.source_zone_id;
		input.footprint.x_after_bbox_rescale = zone.x;
		input.footprint.y_after_bbox_rescale = zone.y;
			input.footprint.level = zone.level;
			input.zone_word = zone_word_for_coordinate_zone(zone, zone_position);
			input.random_span_limit = std::max<int32_t>(1, zone.scaled_size > 0 ? zone.scaled_size : zone.source_base_size);
			input.source_record_vector_index_4a3e9c = zone.source_index >= 0 ? zone.source_index : zone_position;
			input.has_source_record_seed_0x10 = true;
			input.source_record_seed_0x10 = SpanRecord { zone.x, zone.y, zone.level };
			input.allowed_town_mask_0x41_0x49 = zone.allowed_town_mask_0x41_0x49;
			input.selected_town_choice_index_0x49b3c1 = zone.selected_town_choice_index_0x49b3c1;
			input.terrain_match_to_town_0x84 = zone.terrain_match_to_town_0x84;
			input.allowed_terrain_mask_0x85_0x8c = zone.allowed_terrain_mask_0x85_0x8c;
			result.boundary_inputs.push_back(input);
			result.runtime_zone_records_after_0x49b3c1.push_back(runtime_seed_from_coordinate_zone_after_49b3c1(zone, zone_position));
		}
	result.rng_state_after = rng.state;
	return result;
}

RuntimeTerrainSelectionResult49b53d runtime_terrain_selection_49b53d(uint32_t rng_state_after_coordinate_replay, const std::vector<RuntimeZoneBoundaryInput4a3a03> &runtime_zones) {
	RuntimeTerrainSelectionResult49b53d result;
	result.rng_state_before = rng_state_after_coordinate_replay;
	result.rng_state_after = rng_state_after_coordinate_replay;

	H3MapedRng rng;
	rng.state = rng_state_after_coordinate_replay;
	result.records.reserve(runtime_zones.size());
	for (int32_t index = 0; index < int32_t(runtime_zones.size()); ++index) {
		const RuntimeZoneBoundaryInput4a3a03 &runtime = runtime_zones[size_t(index)];
		RuntimeTerrainSelectionRecord49b53d record;
		record.runtime_zone_index = runtime.footprint.runtime_zone_index >= 0 ? runtime.footprint.runtime_zone_index : index;
		record.level = runtime.footprint.level;
		record.selected_town_choice_index_0x49b3c1 = runtime.selected_town_choice_index_0x49b3c1;
		record.terrain_match_to_town_0x84 = runtime.terrain_match_to_town_0x84;
		record.allowed_terrain_mask_0x85_0x8c = runtime.allowed_terrain_mask_0x85_0x8c;
		record.selected_terrain_id_0x49b53d = 0;
		record.selection_source = "0x49b57d_0x49b584_no_eligible_flags_defaults_zero";

		if (record.terrain_match_to_town_0x84
				&& record.selected_town_choice_index_0x49b3c1 >= 0
				&& record.selected_town_choice_index_0x49b3c1 < int32_t(H3_TOWN_TO_TERRAIN_TABLE_540908.size())) {
			record.selected_terrain_id_0x49b53d = H3_TOWN_TO_TERRAIN_TABLE_540908[size_t(record.selected_town_choice_index_0x49b3c1)];
			record.selection_source = "0x49b54c_0x49b55b_match_to_town_table_0x540908";
			result.match_to_town_count += 1;
		} else {
			std::vector<int32_t> eligible_terrain_ids;
			for (int32_t terrain_id = 0; terrain_id < 8; ++terrain_id) {
				if ((record.allowed_terrain_mask_0x85_0x8c & (uint16_t(1U) << uint32_t(terrain_id))) == 0U) {
					continue;
				}
				if (terrain_id == 6 && record.level != 1) {
					continue;
				}
				eligible_terrain_ids.push_back(terrain_id);
			}
			if (eligible_terrain_ids.empty()) {
				result.no_eligible_default_zero_count += 1;
			} else {
				const int32_t rng_value = rng.next();
				result.rng_call_count += 1;
				record.rng_value = rng_value;
				record.rng_modulus = int32_t(eligible_terrain_ids.size());
				record.selected_allowed_ordinal = rng_value % record.rng_modulus;
				record.selected_terrain_id_0x49b53d = eligible_terrain_ids[size_t(record.selected_allowed_ordinal)];
				record.selection_source = "0x49b586_0x49b5b4_allowed_flag_rng_choice";
				result.allowed_flag_choice_count += 1;
			}
		}

		if (record.level == 1 && record.selected_terrain_id_0x49b53d != 7) {
			record.selected_terrain_id_0x49b53d = 6;
			record.forced_subterranean_0x49b5c3 = true;
			result.forced_subterranean_count += 1;
		}
		result.records.push_back(record);
	}
	result.rng_state_after = rng.state;
	return result;
}

TerrainRepaintResult4a3f27 terrain_repaint_4a3f27(int32_t width, int32_t height, int32_t level_count, const BoundaryMaterialization4a2777 &owner_materialization, const RuntimeTerrainSelectionResult49b53d &terrain_selection) {
	TerrainRepaintResult4a3f27 result;
	result.status = "blocked_invalid_dimensions";
	if (width <= 0 || height <= 0 || level_count <= 0) {
		return result;
	}
	const int64_t cell_count_64 = int64_t(width) * int64_t(height) * int64_t(level_count);
	if (cell_count_64 <= 0 || cell_count_64 > std::numeric_limits<int32_t>::max()) {
		return result;
	}
	const int32_t cell_count = int32_t(cell_count_64);
	const GeneratedCellWordGrid reset_grid = generated_cell_grid_reset_0x49a072(width, height, level_count);
	result.generated_cell_word_0x10 = reset_grid.word_0x10;
	result.generated_cell_word_0x1c = reset_grid.word_0x1c;
	result.generated_cell_word_0x20 = owner_materialization.generated_cell_word_0x20.size() == size_t(cell_count)
			? owner_materialization.generated_cell_word_0x20
			: reset_grid.word_0x20;
	result.generated_cell_word_0x24 = reset_grid.word_0x24;
	result.generated_cell_word_0x28 = reset_grid.word_0x28;
	result.generated_cell_word_0x2c = reset_grid.word_0x2c;
	result.terrain_code.assign(size_t(cell_count), 8);
	result.terrain_scratch_word_0x4bad0f.assign(size_t(cell_count), 0U);

	if (owner_materialization.cell_flags.size() == size_t(cell_count)) {
		for (int32_t flat = 0; flat < cell_count; ++flat) {
			if ((owner_materialization.cell_flags[size_t(flat)] & 0x10U) != 0U) {
				result.generated_cell_word_0x28[size_t(flat)] |= CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28;
			}
		}
	}

	const int32_t level_tile_count = width * height;
	const TerrainVisualGridTables visual_tables = load_terrain_visual_grid_tables_4bcff5();
	H3MapedRng live_visual_rng;
	live_visual_rng.state = terrain_selection.rng_state_after;
	result.terrain_visual_rng_state_before_0x4bb74b = live_visual_rng.state;

	auto live_accept_neighbor = [&](int32_t neighbor_index, int32_t terrain_id) -> bool {
		if (neighbor_index < 0 || neighbor_index >= cell_count) {
			return false;
		}
		const uint32_t neighbor_scratch = result.terrain_scratch_word_0x4bad0f[size_t(neighbor_index)];
		return (neighbor_scratch & 0x01U) != 0U && scratch_terrain_id_4bad0f(neighbor_scratch) == terrain_id && scratch_art_id_4bad0f(neighbor_scratch) != 0;
	};
	auto live_neighbor_mask_for_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id) -> int32_t {
		const int32_t index = level * level_tile_count + y * width + x;
		int32_t mask = 4;
		if (x > 0 && live_accept_neighbor(index - 1, terrain_id)) {
			mask >>= 1;
		}
		if (y > 0 && live_accept_neighbor(index - width, terrain_id)) {
			mask >>= 1;
		}
		if (x + 1 < width && live_accept_neighbor(index + 1, terrain_id)) {
			mask >>= 1;
		}
		if (y + 1 < height && live_accept_neighbor(index + width, terrain_id)) {
			mask >>= 1;
		}
		return mask;
	};
	auto apply_final_sweep_class_correction_4bbfcc = [&](TerrainClassResult classified, bool apply_correction) -> TerrainClassResult {
		if (!apply_correction) {
			return classified;
		}
		int32_t corrected_class = classified.shape_class;
		switch (classified.shape_class) {
			case 2:
				corrected_class = 6;
				break;
			case 8:
				corrected_class = 12;
				break;
			case 5:
				corrected_class = 7;
				break;
			case 11:
				corrected_class = 13;
				break;
			default:
				break;
		}
		if (corrected_class != classified.shape_class) {
			result.terrain_visual_final_sweep_class_correction_count_0x4bbfcc += 1;
			classified.shape_class = corrected_class;
		}
		return classified;
	};
	auto write_live_visual_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id, bool apply_final_sweep_class_correction = false) -> bool {
		if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * width + x;
		if (index < 0 || index >= cell_count) {
			return false;
		}
		result.terrain_visual_attempt_count_0x4bb74b += 1;
		const TerrainClassResult classified = apply_final_sweep_class_correction_4bbfcc(
				classify_grid_cell_4bb075(result.terrain_code, width, height, level_tile_count, level, x, y, terrain_id),
				apply_final_sweep_class_correction);
		const int32_t neighbor_mask = live_neighbor_mask_for_cell(level, x, y, terrain_id);
		int32_t selected_row = -1;
		int32_t out_flag_a = 0;
		int32_t out_flag_b = 0;
		const std::vector<TerrainVisualRow> &rows = visual_rows_for_terrain_id_4bcff5(visual_tables, terrain_id);
		bool selected = select_visual_row_for_grid_cell_4bcfc3(rows, terrain_id, classified, neighbor_mask, live_visual_rng, selected_row, out_flag_a, out_flag_b);
		if (!selected) {
			if (apply_final_sweep_class_correction) {
				const uint32_t current_record = result.terrain_scratch_word_0x4bad0f[size_t(index)];
				if ((current_record & 0x01U) != 0U && scratch_terrain_id_4bad0f(current_record) == terrain_id) {
					selected_row = scratch_art_id_4bad0f(current_record);
					out_flag_a = int32_t((current_record >> 12U) & 0x01U);
					out_flag_b = int32_t((current_record >> 13U) & 0x01U);
					result.terrain_visual_preserved_current_record_count_0x4bc5a3 += 1;
					selected = true;
				}
			}
			if (!selected) {
				result.terrain_visual_missing_bucket_count_0x4bcfc3 += 1;
				if (result.terrain_visual_missing_bucket_samples_0x4bcfc3.size() < 16U) {
					TerrainVisualMissingBucketSample4bcfc3 sample;
					sample.level = level;
					sample.x = x;
					sample.y = y;
					sample.terrain_id = terrain_id;
					sample.shape_class = classified.shape_class;
					sample.flag_a = classified.flag_a;
					sample.flag_b = classified.flag_b;
					sample.neighbor_mask = neighbor_mask;
					sample.row_table_count = int32_t(rows.size());
					sample.final_sweep = apply_final_sweep_class_correction;
					result.terrain_visual_missing_bucket_samples_0x4bcfc3.push_back(sample);
				}
				return false;
			}
		}
		result.terrain_scratch_word_0x4bad0f[size_t(index)] = terrain_scratch_word_4bad0f(terrain_id, selected_row, out_flag_a, out_flag_b);
		result.generated_cell_word_0x24[size_t(index)] = generated_cell_49acf6_word24(result.generated_cell_word_0x24[size_t(index)], terrain_id, selected_row);
		result.generated_cell_word_0x28[size_t(index)] = generated_cell_49acf6_word28(result.generated_cell_word_0x28[size_t(index)], out_flag_a, out_flag_b);
		result.terrain_visual_write_count_0x4bb74b += 1;
		if (selected_row != 0) {
			result.terrain_visual_art_nonzero_cell_count += 1;
		}
		if ((result.generated_cell_word_0x28[size_t(index)] & CELL_TERRAIN_FLAG_MASK_0X49ACF6) != 0U) {
			result.terrain_visual_flag_cell_count += 1;
		}
		return true;
	};

	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				result.full_map_water_repaint_count_0x4a4025 += 1;
				if (write_live_visual_cell(level, x, y, 8)) {
					result.terrain_visual_initial_water_write_count_0x4a4025 += 1;
				}
			}
		}
	}

	std::set<int64_t> set_a;
	std::set<int64_t> set_b;

	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain) {
		if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index_4bb74b(result.terrain_code, width, height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		if (set_b.insert(terrain_grid_key_4bb74b(level, x, y)).second) {
			result.terrain_visual_set_b_insert_count += 1;
		}
	};
	auto seed_4bba59 = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain) {
		append_set_b(level, x, y - 1, current_terrain);
		append_set_b(level, x, y + 1, current_terrain);
		append_set_b(level, x - 1, y, current_terrain);
		append_set_b(level, x + 1, y, current_terrain);
		static constexpr std::array<std::array<int32_t, 2>, 4> DIAGONALS = { { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } };
		for (const auto &delta : DIAGONALS) {
			const int32_t nx = x + delta[0];
			const int32_t ny = y + delta[1];
			const int32_t neighbor = terrain_at_grid_index_4bb74b(result.terrain_code, width, height, level_tile_count, level, nx, ny, current_terrain);
			if (toolkit_byte5_allows_same_class_gate_4bb74b(neighbor)) {
				append_set_b(level, nx, ny, current_terrain);
			}
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y) {
		if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
			return;
		}
		if (set_a.insert(terrain_grid_key_4bb74b(level, x, y)).second) {
			result.terrain_visual_set_a_insert_count += 1;
		}
	};
	auto process_set_a_neighbor = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper) {
		if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
			return;
		}
		const int64_t key = terrain_grid_key_4bb74b(level, x, y);
		const auto found = set_a.find(key);
		if (found == set_a.end()) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index_4bb74b(result.terrain_code, width, height, level_tile_count, level, x, y, current_terrain);
		const bool gate = horizontal_pair_wrapper
				? horizontal_pair_gate_4bc674(result.terrain_code, width, height, level_tile_count, level, x, y, neighbor)
				: vertical_pair_gate_4bc6e0(result.terrain_code, width, height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			set_a.erase(found);
			seed_4bba59(level, x, y, current_terrain);
		}
	};
	auto process_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0 || x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
			return;
		}
		set_terrain_at_grid_index_4bb74b(result.terrain_code, width, height, level_tile_count, level, x, y, active_terrain);
		if (write_live_visual_cell(level, x, y, active_terrain)) {
			result.terrain_visual_queue_write_count_0x4bb74b += 1;
		}
		set_b.erase(terrain_grid_key_4bb74b(level, x, y));
		if (!toolkit_byte5_allows_same_class_gate_4bb74b(active_terrain)) {
			process_set_a_neighbor(level, x, y - 1, active_terrain, true);
			process_set_a_neighbor(level, x, y + 1, active_terrain, true);
			process_set_a_neighbor(level, x - 1, y, active_terrain, false);
			process_set_a_neighbor(level, x + 1, y, active_terrain, false);
		} else if (candidate_gate_4bc988(result.terrain_code, width, height, level_tile_count, level, x, y)) {
			append_set_a(level, x, y);
		} else {
			seed_4bba59(level, x, y, active_terrain);
		}
	};

	int64_t drain_guard_count = 0;
	const int64_t drain_guard_limit = std::max<int64_t>(32768, int64_t(cell_count) * 128);
	auto drain_queue_for_active_terrain = [&](int32_t active_terrain) {
		while ((!set_a.empty() || !set_b.empty()) && drain_guard_count < drain_guard_limit) {
			drain_guard_count += 1;
			while (!set_a.empty() && drain_guard_count < drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_a.begin();
				set_a.erase(set_a.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				terrain_decode_grid_key_4bb74b(key, level, x, y);
				result.terrain_visual_set_a_drain_count += 1;
				std::vector<int64_t> changed_keys;
				result.terrain_visual_retouch_write_count_0x4bbd01 += frontier_retouch_4bbd01(result.terrain_code, width, height, level_tile_count, level, x, y, &changed_keys);
				for (const int64_t changed_key : changed_keys) {
					int32_t changed_level = 0;
					int32_t changed_x = 0;
					int32_t changed_y = 0;
					terrain_decode_grid_key_4bb74b(changed_key, changed_level, changed_x, changed_y);
					process_topology(changed_level, changed_x, changed_y, active_terrain);
				}
			}
			while (set_a.empty() && !set_b.empty() && drain_guard_count < drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_b.begin();
				set_b.erase(set_b.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				terrain_decode_grid_key_4bb74b(key, level, x, y);
				result.terrain_visual_set_b_drain_count += 1;
				if (candidate_gate_4bc988(result.terrain_code, width, height, level_tile_count, level, x, y)) {
					result.terrain_visual_set_b_candidate_true_count += 1;
					process_topology(level, x, y, active_terrain);
				}
			}
		}
		set_a.clear();
		set_b.clear();
	};

	for (const RuntimeTerrainSelectionRecord49b53d &record : terrain_selection.records) {
		if (record.selected_terrain_id_0x49b53d == 8) {
			result.water_zone_skip_count += 1;
			continue;
		}
		bool record_changed = false;
		for (int32_t flat = 0; flat < cell_count; ++flat) {
			const int32_t owner_byte = generated_cell_owner_byte2_signed_4a4142(result.generated_cell_word_0x20[size_t(flat)]);
			if (owner_byte != record.runtime_zone_index) {
				result.owner_gate_skip_count_0x4a4142 += 1;
				continue;
			}
			if (((result.generated_cell_word_0x28[size_t(flat)] >> 28U) & 0x01U) == 0U) {
				result.member_gate_skip_count_0x4a4150 += 1;
				continue;
			}
			result.zone_repaint_candidate_count_0x4a4082 += 1;
			result.zone_repaint_write_count_0x4a4163 += 1;
			const int32_t level = flat / level_tile_count;
			const int32_t level_offset = flat - level * level_tile_count;
			const int32_t y = level_offset / width;
			const int32_t x = level_offset - y * width;
			if (set_terrain_at_grid_index_4bb74b(result.terrain_code, width, height, level_tile_count, level, x, y, record.selected_terrain_id_0x49b53d)) {
				record_changed = true;
				if (write_live_visual_cell(level, x, y, record.selected_terrain_id_0x49b53d)) {
					result.terrain_visual_repaint_write_count_0x4a4082 += 1;
				}
				set_b.erase(terrain_grid_key_4bb74b(level, x, y));
				if (candidate_gate_4bc988(result.terrain_code, width, height, level_tile_count, level, x, y)) {
					append_set_a(level, x, y);
				} else {
					seed_4bba59(level, x, y, record.selected_terrain_id_0x49b53d);
				}
				if (!toolkit_byte5_allows_same_class_gate_4bb74b(record.selected_terrain_id_0x49b53d)) {
					process_set_a_neighbor(level, x, y - 1, record.selected_terrain_id_0x49b53d, true);
					process_set_a_neighbor(level, x, y + 1, record.selected_terrain_id_0x49b53d, true);
					process_set_a_neighbor(level, x - 1, y, record.selected_terrain_id_0x49b53d, false);
					process_set_a_neighbor(level, x + 1, y, record.selected_terrain_id_0x49b53d, false);
				}
			}
		}
		if (record_changed) {
			drain_queue_for_active_terrain(record.selected_terrain_id_0x49b53d);
		}
	}

	for (int32_t level = 0; level < level_count; ++level) {
		const int32_t level_base = level * level_tile_count;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int32_t index = level_base + y * width + x;
				if (index < 0 || index >= cell_count) {
					continue;
				}
				if (write_live_visual_cell(level, x, y, result.terrain_code[size_t(index)], true)) {
					result.terrain_visual_final_sweep_cell_count_0x4bbfcc += 1;
				}
			}
		}
	}

	for (int32_t index = 0; index < cell_count; ++index) {
		const uint32_t scratch_word = result.terrain_scratch_word_0x4bad0f[size_t(index)];
		if ((scratch_word & 0x01U) != 0U) {
			result.terrain_visual_dirty_cell_count_0x4bad0f += 1;
		}
		const uint32_t roundtrip_0x24 = (uint32_t(scratch_terrain_id_4bad0f(scratch_word)) & 0x3fU) | ((uint32_t(scratch_art_id_4bad0f(scratch_word)) & 0xffU) << 6U);
		const uint32_t roundtrip_0x28 = generated_cell_terrain_flags_0x49acf6(int32_t((scratch_word >> 12U) & 0x01U), int32_t((scratch_word >> 13U) & 0x01U));
		if (roundtrip_0x24 != (result.generated_cell_word_0x24[size_t(index)] & 0x00003fffU)
				|| roundtrip_0x28 != (result.generated_cell_word_0x28[size_t(index)] & CELL_TERRAIN_FLAG_MASK_0X49ACF6)) {
			result.terrain_visual_roundtrip_mismatch_count += 1;
		}
		if (int32_t(result.generated_cell_word_0x24[size_t(index)] & 0x3fU) != result.terrain_code[size_t(index)]) {
			result.terrain_visual_terrain_mismatch_count += 1;
		}
	}
	result.terrain_visual_rng_state_after_0x4bb74b = live_visual_rng.state;
	result.terrain_visual_queue_drain_complete_0x4bc5f0 = drain_guard_count < drain_guard_limit;
	result.executed = true;
	result.status = "terrainplacement_visual_row_and_flag_selection_executed_0x4bb74b_0x4bad0f_0x4bcfc3_0x4bce6d";
	return result;
}

SourceNodeFootprintResult4a3a03 build_source_node_footprints_4a3a03_4ccb64_4cca55(const std::vector<RuntimeZoneFootprintInput4a3a03> &runtime_zones) {
	SourceNodeFootprintResult4a3a03 result;
	SourcePolygonModel4ccb64 model;
	const int32_t p0 = model.add_pair(-200, -200, 0, 400, -200, 0);
	const int32_t p1 = model.add_pair(400, -200, 0, 400, 400, 0);
	const int32_t p2 = model.add_pair(400, 400, 0, -200, 400, 0);
	const int32_t p3 = model.add_pair(-200, 400, 0, -200, -200, 0);
	model.relink_4cc643(model.nodes[size_t(p0)].pair, p1);
	model.relink_4cc643(model.nodes[size_t(p1)].pair, p2);
	model.relink_4cc643(model.nodes[size_t(p2)].pair, p3);
	model.relink_4cc643(model.nodes[size_t(p3)].pair, p0);
	model.bridge_4ccb1f(p3, p2);
	model.root = p0;

	for (int32_t runtime_index = 0; runtime_index < int32_t(runtime_zones.size()); ++runtime_index) {
		const RuntimeZoneFootprintInput4a3a03 &runtime = runtime_zones[size_t(runtime_index)];
		if (runtime.level != 0) {
			continue;
		}
		const int32_t zone_index = runtime.runtime_zone_index >= 0 ? runtime.runtime_zone_index : runtime_index;
		const int32_t x = runtime.x_after_bbox_rescale;
		const int32_t y = runtime.y_after_bbox_rescale;
		SourceSplitStep4ccb64 step;
		step.runtime_zone_index = zone_index;
		step.source_zone_id = runtime.source_zone_id;
		step.x = x;
		step.y = y;
		int32_t located = model.locate_4cca55(x, y);
		if (located < 0) {
			step.status = "0x4cca55_locator_guard_failed";
			result.blocked = true;
			result.split_steps.push_back(step);
			break;
		}
		if ((model.nodes[size_t(located)].x == x && model.nodes[size_t(located)].y == y)
				|| (model.nodes[size_t(model.nodes[size_t(located)].pair)].x == x && model.nodes[size_t(model.nodes[size_t(located)].pair)].y == y)) {
			step.status = "0x4ccb64_duplicate_point_skipped";
			result.duplicate_skip_count += 1;
			result.split_steps.push_back(step);
			continue;
		}
		if (model.edge_side_test_4cc6f2(located, x, y)) {
			located = model.nodes[size_t(located)].previous;
			const int32_t erased = model.nodes[size_t(located)].next;
			model.erase_edge_4cc9cc(erased);
			result.edge_removal_count += 1;
		}
		const SourcePolygonNode4ccb64 &located_node = model.nodes[size_t(located)];
		const int32_t split_primary = model.add_pair(located_node.x, located_node.y, located_node.payload, x, y, zone_index, located_node.has_payload, true);
		model.relink_4cc643(split_primary, located);
		model.root = split_primary;
		result.inserted_node_pair_count += 1;
		result.executed_split_count += 1;

		int32_t bridge_pair_count = 0;
		int32_t current_bridge = split_primary;
		int32_t bridge_source = located;
		for (int32_t guard = 0; guard < 64; ++guard) {
			current_bridge = model.bridge_4ccb1f(bridge_source, model.nodes[size_t(current_bridge)].pair);
			bridge_pair_count += 1;
			result.inserted_bridge_pair_count += 1;
			bridge_source = model.nodes[size_t(current_bridge)].previous;
			const int32_t bridge_source_pair = model.nodes[size_t(bridge_source)].pair;
			if (model.nodes[size_t(bridge_source_pair)].previous == model.root) {
				break;
			}
			if (guard == 63) {
				result.blocked = true;
				step.status = "0x4ccb64_bridge_loop_guard_failed";
			}
		}

		int32_t cleanup_scan_count = 0;
		int32_t cleanup_test_count = 0;
		int32_t cleanup_collapse_count = 0;
		int32_t cleanup_cursor = bridge_source;
		for (int32_t guard = 0; guard < 256; ++guard) {
			cleanup_scan_count += 1;
			result.crossing_scan_count += 1;
			if (model.crossing_orientation_gate_4ccb64(cleanup_cursor)) {
				const SourcePolygonNode4ccb64 &cursor = model.nodes[size_t(cleanup_cursor)];
				const SourcePolygonNode4ccb64 &previous_pair = model.nodes[size_t(model.nodes[size_t(cursor.previous)].pair)];
				const SourcePolygonNode4ccb64 &paired = model.nodes[size_t(cursor.pair)];
				cleanup_test_count += 1;
				result.crossing_test_count += 1;
				if (model.crossing_test_4ccc7a(cursor.x, cursor.y, previous_pair.x, previous_pair.y, paired.x, paired.y, x, y)) {
					model.crossing_collapse_4cc68e(cleanup_cursor);
					cleanup_collapse_count += 1;
					result.crossing_collapse_count += 1;
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
				result.blocked = true;
				step.status = "0x4ccb64_crossing_cleanup_guard_failed";
			}
		}
		step.bridge_pair_count = bridge_pair_count;
		step.crossing_cleanup_scan_count = cleanup_scan_count;
		step.crossing_test_count = cleanup_test_count;
		step.crossing_collapse_count = cleanup_collapse_count;
		if (step.status.empty()) {
			step.status = result.blocked ? "0x4ccb64_guard_failed" : "0x4ccb64_pre_crossing_inserted";
		}
		result.split_steps.push_back(step);
		if (result.blocked) {
			break;
		}
	}

	result.allocated_node_pair_count = int32_t(model.nodes.size() / 2);
	result.active_node_pair_count = model.active_node_pair_count();
	result.finalized_triplet_count = result.blocked ? 0 : model.finalize_4ccdfc();
	for (const SourcePolygonNode4ccb64 &node : model.nodes) {
		if (!node.active) {
			continue;
		}
		if (node.has_payload) {
			result.active_payload_node_count += 1;
		}
		if (node.finalized) {
			result.finalized_node_count += 1;
		}
	}

	for (int32_t node_index = 0; node_index < int32_t(model.nodes.size()); ++node_index) {
		const SourcePolygonNode4ccb64 &node = model.nodes[size_t(node_index)];
		SourceDescriptorNode4cca55 descriptor;
		descriptor.model_node_index = node_index;
		descriptor.x = node.x;
		descriptor.y = node.y;
		descriptor.has_payload = node.has_payload;
		descriptor.payload = node.payload;
		descriptor.pair_index = node.pair;
		descriptor.next_index = node.next;
		descriptor.previous_index = node.previous;
		descriptor.active = node.active;
		descriptor.finalized = node.finalized;
		descriptor.finalized_x = node.finalized_x;
		descriptor.finalized_y = node.finalized_y;
		result.descriptor_nodes.push_back(descriptor);
		result.source_descriptor_node_count += 1;
		if (descriptor.active) {
			result.source_descriptor_active_node_count += 1;
		}
		if (descriptor.finalized) {
			result.source_descriptor_finalized_node_count += 1;
		}
	}

	for (int32_t runtime_index = 0; runtime_index < int32_t(runtime_zones.size()); ++runtime_index) {
		const RuntimeZoneFootprintInput4a3a03 &runtime = runtime_zones[size_t(runtime_index)];
		if (runtime.level != 0) {
			continue;
		}
		SourceWalk4cca55 walk;
		walk.runtime_zone_index = runtime.runtime_zone_index >= 0 ? runtime.runtime_zone_index : runtime_index;
		walk.source_zone_id = runtime.source_zone_id;
		walk.start_x = runtime.x_after_bbox_rescale;
		walk.start_y = runtime.y_after_bbox_rescale;
		const int32_t located = result.blocked ? -1 : model.locate_4cca55(walk.start_x, walk.start_y);
		walk.locator_node_index = located;
		walk.locator_status = located >= 0
				? "0x4cca55_runtime_zone_descriptor_handoff_materialized"
				: "0x4cca55_runtime_zone_descriptor_handoff_missing";
		if (located >= 0) {
			int32_t current = located;
			bool guard_exhausted = false;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const SourcePolygonNode4ccb64 &node = model.nodes[size_t(current)];
				const int32_t next = node.next;
				const int32_t next_pair = next >= 0 && next < int32_t(model.nodes.size()) ? model.nodes[size_t(next)].pair : -1;
				const SourcePolygonNode4ccb64 *next_pair_node = next_pair >= 0 && next_pair < int32_t(model.nodes.size()) ? &model.nodes[size_t(next_pair)] : nullptr;
				SourceNodeCyclePoint4a2777 source_node;
				source_node.model_node_index = current;
				source_node.pair_index = node.pair;
				source_node.next_index = node.next;
				source_node.previous_index = node.previous;
				source_node.next_pair_index = next_pair;
				source_node.raw_x_0x00 = node.x;
				source_node.raw_y_0x04 = node.y;
				source_node.finalized_x_0x1c = node.finalized_x;
				source_node.finalized_y_0x20 = node.finalized_y;
				source_node.finalized = node.finalized;
				source_node.has_payload = node.has_payload;
				source_node.payload = node.payload;
				source_node.next_pair_has_payload = next_pair_node != nullptr && next_pair_node->has_payload;
				source_node.next_pair_payload = next_pair_node != nullptr ? next_pair_node->payload : 0;
				walk.source_nodes.push_back(source_node);
				current = node.next;
				if (current == located) {
					break;
				}
				if (guard == 95) {
					guard_exhausted = true;
				}
			}
			if (guard_exhausted) {
				result.source_node_walk_guard_exhausted_count += 1;
			}
		}
		result.walks.push_back(walk);
		result.source_node_walk_count += 1;
	}

	return result;
}

FootprintFinalizerResult4a3710 footprint_finalizer_4a3710(int32_t level_count, int32_t water_mode_code, int32_t original_same_level_runtime_zone_count, int32_t final_runtime_zone_count) {
	FootprintFinalizerResult4a3710 result;
	result.executed = true;
	result.level_count = level_count;
	result.water_mode_code = water_mode_code;
	result.synthetic_branch_allowed_by_0x4a3a9d = level_count > 1 || water_mode_code != 0;
	result.original_same_level_runtime_zone_count = std::max(0, original_same_level_runtime_zone_count);
	result.final_runtime_zone_count = std::max(0, final_runtime_zone_count);
	result.appended_runtime_zone_count = std::max(0, result.final_runtime_zone_count - result.original_same_level_runtime_zone_count);
	result.adjacency_insert_count = 0;
	result.zone_order_reset_call_count = result.final_runtime_zone_count;
	result.per_zone_order_helper_call_count = result.original_same_level_runtime_zone_count;
	result.materializes_generated_cells = false;
	result.relation_order_vectors_required_for_downstream_consumers = true;
	result.relation_order_vectors_materialized = false;
	result.downstream_relation_order_blocker = "runtime_zone+0xc4 adjacency and runtime_zone+0x3e8 ordering vectors are not represented in the checkpoint-2 generated-cell payload";

	if (result.synthetic_branch_allowed_by_0x4a3a9d) {
		result.blocked = true;
		result.status = "0x4a3710_non_land_or_multilevel_synthetic_adjacency_branch_not_materialized";
		return result;
	}
	if (result.appended_runtime_zone_count > 0) {
		result.blocked = true;
		result.status = "0x4a3710_appended_zone_adjacency_schema_pending";
		return result;
	}
	result.status = "0x4a3710_one_level_land_no_appended_zone_finalizer_executed";
	return result;
}

BoundaryOwnerGridResult4a3a03 materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d_4a3710(int32_t width, int32_t height, int32_t level_count, int32_t water_mode_code, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<RuntimeZoneBoundaryInput4a3a03> &runtime_zones) {
	BoundaryOwnerGridResult4a3a03 result;
	std::vector<RuntimeZoneFootprintInput4a3a03> footprint_inputs;
	footprint_inputs.reserve(runtime_zones.size());
	for (const RuntimeZoneBoundaryInput4a3a03 &runtime : runtime_zones) {
		footprint_inputs.push_back(runtime.footprint);
	}
	result.source_footprints = build_source_node_footprints_4a3a03_4ccb64_4cca55(footprint_inputs);
	result.source_blocked = result.source_footprints.blocked;
	if (result.source_blocked) {
		return result;
	}

	for (const SourceWalk4cca55 &walk : result.source_footprints.walks) {
		const RuntimeZoneBoundaryInput4a3a03 *matched_input = nullptr;
		for (const RuntimeZoneBoundaryInput4a3a03 &runtime : runtime_zones) {
			const int32_t runtime_zone_index = runtime.footprint.runtime_zone_index;
			if (runtime.footprint.level != 0) {
				continue;
			}
			if ((runtime_zone_index >= 0 && runtime_zone_index == walk.runtime_zone_index)
					|| (runtime_zone_index < 0 && runtime.footprint.source_zone_id == walk.source_zone_id && runtime.footprint.x_after_bbox_rescale == walk.start_x && runtime.footprint.y_after_bbox_rescale == walk.start_y)) {
				matched_input = &runtime;
				break;
			}
		}
		if (matched_input == nullptr) {
			result.missing_boundary_input_count += 1;
			continue;
		}
		if (walk.source_nodes.empty()) {
			result.missing_source_walk_count += 1;
			continue;
		}

		BoundarySourceCycleHandoff4a2777 handoff;
		handoff.runtime_zone_index = walk.runtime_zone_index;
		handoff.zone_word = matched_input->zone_word;
		handoff.level = matched_input->footprint.level;
		handoff.random_span_limit = matched_input->random_span_limit;
		handoff.source_record_vector_index_4a3e9c = matched_input->source_record_vector_index_4a3e9c;
		handoff.has_source_record_seed_0x10 = matched_input->has_source_record_seed_0x10;
		handoff.source_record_seed_0x10 = matched_input->source_record_seed_0x10;
		handoff.source_nodes = walk.source_nodes;
		result.handoffs.push_back(std::move(handoff));
	}

	result.materialization = materialize_boundary_source_handoffs_4a2777_4a325d(width, height, level_count, generator_mode_0x10b8, rng_state, result.handoffs);
	result.materialization_executed = true;
	int32_t same_level_runtime_zone_count = 0;
	for (const RuntimeZoneBoundaryInput4a3a03 &runtime : runtime_zones) {
		if (runtime.footprint.level == 0) {
			same_level_runtime_zone_count += 1;
		}
	}
	result.footprint_finalizer = footprint_finalizer_4a3710(level_count, water_mode_code, same_level_runtime_zone_count, same_level_runtime_zone_count);
	result.footprint_finalizer_executed = result.footprint_finalizer.executed;
	return result;
}

CoordinateOwnerGridResult4a218c coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(int32_t width, int32_t height, int32_t level_count, int32_t water_mode_code, int32_t generator_mode_0x10b8, uint32_t rng_state_after_template_selection, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones, const std::vector<RuntimeLinkSeedInput4a218c> &links) {
	CoordinateOwnerGridResult4a218c result;
	result.coordinate_seed = coordinate_seed_runtime_zone_boundary_inputs_4a218c_4a1f3b_4a19ed(
			width,
			height,
			level_count,
			generator_mode_0x10b8,
			rng_state_after_template_selection,
			runtime_zones,
			links);
	result.coordinate_seed_blocked = result.coordinate_seed.blocked;
	if (result.coordinate_seed_blocked) {
		return result;
	}
	result.owner_grid = materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d_4a3710(
			width,
			height,
			level_count,
			water_mode_code,
			generator_mode_0x10b8,
			result.coordinate_seed.rng_state_after,
			result.coordinate_seed.boundary_inputs);
	result.owner_grid_executed = result.owner_grid.materialization_executed;
	if (result.owner_grid_executed) {
		result.terrain_selection = runtime_terrain_selection_49b53d(
				result.coordinate_seed.rng_state_after,
				result.coordinate_seed.boundary_inputs);
		result.terrain_selection_executed = true;
		result.terrain_repaint = terrain_repaint_4a3f27(
				width,
				height,
				level_count,
				result.owner_grid.materialization,
				result.terrain_selection);
		result.terrain_repaint_executed = result.terrain_repaint.executed;
	}
	return result;
}

static GeneratorObjectVectorState generator_object_vector_state(const std::string &label, uint32_t begin_offset, uint32_t end_offset, uint32_t capacity_offset, bool present, bool contents_known, bool count_known, int32_t count, int32_t element_size_bytes = 0) {
	GeneratorObjectVectorState state;
	state.label = label;
	state.begin_offset = begin_offset;
	state.end_offset = end_offset;
	state.capacity_offset = capacity_offset;
	state.present = present;
	state.contents_known = contents_known;
	state.count_known = count_known;
	state.count = count;
	state.element_size_bytes = element_size_bytes;
	return state;
}

static GeneratorObjectVectorState endpoint_byte_state_vector_from_d8_count_0x49f95a(const GeneratorObjectVectorState &endpoint_vector_d8_dc) {
	GeneratorObjectVectorState state = generator_object_vector_state(
			"endpoint_byte_state_vector_0x1104_0x1108",
			0x1104U,
			0x1108U,
			0U,
			true,
			endpoint_vector_d8_dc.count_known,
			endpoint_vector_d8_dc.count_known,
			endpoint_vector_d8_dc.count_known ? endpoint_vector_d8_dc.count : 0,
			1);
	state.count_sourced_from_vector = true;
	state.count_source_vector_label = endpoint_vector_d8_dc.label;
	state.zero_initialized_contents_known_when_count_known = true;
	return state;
}

static uint32_t relation_record_control_dword_0x49f7c4(bool wide, bool border_guard) {
	uint32_t control = 0U;
	if (wide) {
		control |= 0x00000001U;
	}
	if (border_guard) {
		control |= 0x00000100U;
	}
	return control;
}

static void append_relation_record_0x49f7c4(GeneratorRelationOwnerState4a218c &owner, int32_t source_link_index, int32_t target_runtime_zone_index, int32_t target_source_zone_id, const RuntimeLinkSeedInput4a218c &link, bool reciprocal) {
	GeneratorRelationRecordState4a218c record;
	record.source_link_index = source_link_index;
	record.owner_runtime_zone_index = owner.runtime_zone_index;
	record.owner_source_zone_id = owner.source_zone_id;
	record.target_runtime_zone_index = target_runtime_zone_index;
	record.target_source_zone_id = target_source_zone_id;
	record.guard_value = link.guard_value;
	record.wide = link.wide;
	record.border_guard = link.border_guard;
	record.reciprocal = reciprocal;
	record.control_dword_0x08 = relation_record_control_dword_0x49f7c4(link.wide, link.border_guard);
	owner.relation_records.push_back(record);
	owner.relation_record_count = int32_t(owner.relation_records.size());
}

static void append_source_endpoint_record_0x4a1f3b(GeneratorRelationOwnerState4a218c &owner, int32_t source_link_index, int32_t target_runtime_zone_index, int32_t target_source_zone_id, const RuntimeLinkSeedInput4a218c &link, bool reciprocal) {
	GeneratorSourceEndpointRecordState4a1f3b record;
	record.source_link_index = source_link_index;
	record.owner_runtime_zone_index = owner.runtime_zone_index;
	record.owner_source_zone_id = owner.source_zone_id;
	record.target_runtime_zone_index = target_runtime_zone_index;
	record.target_source_zone_id = target_source_zone_id;
	record.source_endpoint = reciprocal ? link.source_endpoint_b : link.source_endpoint_a;
	record.target_source_endpoint = reciprocal ? link.source_endpoint_a : link.source_endpoint_b;
	record.guard_value = link.guard_value;
	record.wide = link.wide;
	record.border_guard = link.border_guard;
	record.reciprocal = reciprocal;
	owner.source_endpoint_records_0xc8_0xcc.push_back(record);
}

static GeneratorCoordinateCandidateVectorState4a1f3b coordinate_candidate_vector_from_placement_step_0x4a1f3b(const CoordinatePlacementStep4a1f3b &step) {
	GeneratorCoordinateCandidateVectorState4a1f3b out;
	out.runtime_zone_index = step.runtime_zone_index;
	out.pass_id = step.pass_id;
	out.candidate_source = step.candidate_source;
	out.candidate_count_before_prune = step.candidate_count_before_prune;
	out.candidate_count_after_prune = step.candidate_count_after_prune;
	out.explicit_link_base_count = step.explicit_link_base_count;
	out.selected_candidate_index = step.selected_candidate_index;
	out.rng_value = step.rng_value;
	out.blocked = step.blocked;
	out.selected_candidate_known = step.selected_candidate_known;
	out.selected_candidate = step.selected_candidate;
	out.candidates_before_prune_4a17f5 = step.candidates_before_prune_4a17f5;
	out.candidates_after_prune_4a1ad8 = step.candidates_after_prune_4a1ad8;
	return out;
}

static void apply_relation_owner_coordinate_candidate_vectors_0x4a1f3b(GeneratorRelationOwnerState4a218c &owner, const std::vector<CoordinatePlacementStep4a1f3b> &placement_steps) {
	owner.coordinate_candidate_vectors_0x4a1f3b_known = true;
	owner.coordinate_candidate_vectors_0x4a1f3b.clear();
	owner.coordinate_candidate_vector_step_count = 0;
	owner.coordinate_candidate_after_prune_total_count = 0;
	for (const CoordinatePlacementStep4a1f3b &step : placement_steps) {
		if (step.runtime_zone_index != owner.runtime_zone_index) {
			continue;
		}
		GeneratorCoordinateCandidateVectorState4a1f3b vector = coordinate_candidate_vector_from_placement_step_0x4a1f3b(step);
		owner.coordinate_candidate_after_prune_total_count += int32_t(vector.candidates_after_prune_4a1ad8.size());
		owner.coordinate_candidate_vectors_0x4a1f3b.push_back(std::move(vector));
	}
	owner.coordinate_candidate_vector_step_count = int32_t(owner.coordinate_candidate_vectors_0x4a1f3b.size());
}

static const RuntimeZoneSeedInput4a218c *runtime_zone_after_town_choice_0x49b3c1(const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones_after_0x49b3c1, int32_t runtime_zone_index) {
	for (const RuntimeZoneSeedInput4a218c &zone : runtime_zones_after_0x49b3c1) {
		if (zone.runtime_zone_index == runtime_zone_index) {
			return &zone;
		}
	}
	return nullptr;
}

static void apply_relation_owner_constructor_0x49b452(GeneratorRelationOwnerState4a218c &owner, const RuntimeZoneSeedInput4a218c &seed, const RuntimeZoneSeedInput4a218c *post_town_choice_seed) {
	owner.constructor_0x49b452_known = true;
	owner.source_pointer_0x00_known = seed.source_index >= 0;
	owner.source_pointer_source_index_0x00 = seed.source_index;
	const int32_t town_choice = post_town_choice_seed != nullptr ? post_town_choice_seed->selected_town_choice_index_0x49b3c1 : seed.selected_town_choice_index_0x49b3c1;
	owner.town_choice_0x04_known = post_town_choice_seed != nullptr || town_choice >= 0;
	owner.town_choice_0x04 = town_choice;
	owner.source_owner_slot_0x1c_known = seed.source_owner_index >= 0;
	owner.source_owner_slot_0x1c = seed.source_owner_index;
	owner.scan_bounds_0x20_0x2c_known = false;
	owner.scan_bound_low_x_0x20 = RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452;
	owner.scan_bound_low_y_0x24 = RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452;
	owner.scan_bound_high_x_0x28 = RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452;
	owner.scan_bound_high_y_0x2c = RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452;
	owner.byte_0x3c_known = true;
	owner.byte_0x3c = 0U;
	owner.descriptor_type_counter_table_0x44_known = true;
	owner.descriptor_type_counter_table_0x44_byte_size = RELATION_OWNER_DESCRIPTOR_TABLE_0X44_BYTE_SIZE;
	owner.descriptor_type_counter_table_0x44_zero_count = RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
	owner.descriptor_type_counters_0x44.assign(size_t(RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
	owner.owner_local_vectors_0x3e4_0x3f4_0x404_known = true;
	owner.owner_local_vector_0x3e4_count = 0;
	owner.owner_local_vector_0x3f4_count = 0;
	owner.owner_local_vector_0x404_count = 0;
}

static const RuntimeZoneBoundaryInput4a3a03 *boundary_input_after_0x4a19ed_for_runtime_zone(const std::vector<RuntimeZoneBoundaryInput4a3a03> &boundary_inputs, int32_t runtime_zone_index) {
	for (const RuntimeZoneBoundaryInput4a3a03 &input : boundary_inputs) {
		if (input.footprint.runtime_zone_index == runtime_zone_index) {
			return &input;
		}
	}
	return nullptr;
}

static void apply_relation_owner_coordinate_state_0x4a1f3b_0x4a19ed(GeneratorRelationOwnerState4a218c &owner, const RuntimeZoneBoundaryInput4a3a03 *boundary_input_after_0x4a19ed) {
	owner.source_endpoint_vector_0xc8_0xcc_present = true;
	owner.source_endpoint_vector_0xc8_0xcc_contents_known = true;
	owner.source_endpoint_vector_0xc8_0xcc_count_known = true;
	owner.source_endpoint_vector_0xc8_0xcc_count = 0;
	owner.source_endpoint_vector_0xc8_0xcc_stride_bytes = 0x1c;

	if (boundary_input_after_0x4a19ed == nullptr) {
		owner.coordinate_triple_0x10_0x18_known = false;
		return;
	}
	owner.coordinate_triple_0x10_0x18_known = true;
	owner.coordinate_x_0x10 = boundary_input_after_0x4a19ed->footprint.x_after_bbox_rescale;
	owner.coordinate_y_0x14 = boundary_input_after_0x4a19ed->footprint.y_after_bbox_rescale;
	owner.coordinate_level_0x18 = boundary_input_after_0x4a19ed->footprint.level;
}

static std::vector<GeneratorRelationOwnerState4a218c> relation_owner_records_from_runtime_seed_0x4a218c_0x49f7c4(const RuntimeSeedBuildResult4a218c &runtime_seed, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones_after_0x49b3c1, const std::vector<RuntimeZoneBoundaryInput4a3a03> &boundary_inputs_after_0x4a19ed, const std::vector<CoordinatePlacementStep4a1f3b> &placement_steps_after_0x4a1f3b, int32_t &missing_endpoint_count) {
	std::vector<GeneratorRelationOwnerState4a218c> owners;
	owners.reserve(runtime_seed.runtime_zone_seeds.size());
	for (size_t index = 0; index < runtime_seed.runtime_zone_seeds.size(); ++index) {
		const RuntimeZoneSeedInput4a218c &seed = runtime_seed.runtime_zone_seeds[index];
		GeneratorRelationOwnerState4a218c owner;
		owner.owner_vector_index = int32_t(index);
		owner.runtime_zone_index = seed.runtime_zone_index;
		owner.source_zone_id = seed.source_zone_id;
		owner.source_index = seed.source_index;
		apply_relation_owner_constructor_0x49b452(owner, seed, runtime_zone_after_town_choice_0x49b3c1(runtime_zones_after_0x49b3c1, seed.runtime_zone_index));
		apply_relation_owner_coordinate_state_0x4a1f3b_0x4a19ed(owner, boundary_input_after_0x4a19ed_for_runtime_zone(boundary_inputs_after_0x4a19ed, seed.runtime_zone_index));
		apply_relation_owner_coordinate_candidate_vectors_0x4a1f3b(owner, placement_steps_after_0x4a1f3b);
		owners.push_back(owner);
	}

	auto owner_index_for_runtime_zone = [&](int32_t runtime_zone_index) {
		for (size_t index = 0; index < owners.size(); ++index) {
			if (owners[index].runtime_zone_index == runtime_zone_index) {
				return int32_t(index);
			}
		}
		return -1;
	};

	for (size_t link_index = 0; link_index < runtime_seed.runtime_links.size(); ++link_index) {
		const RuntimeLinkSeedInput4a218c &link = runtime_seed.runtime_links[link_index];
		const int32_t from_owner_index = owner_index_for_runtime_zone(link.from_index);
		const int32_t to_owner_index = owner_index_for_runtime_zone(link.to_index);
		if (from_owner_index < 0 || to_owner_index < 0) {
			missing_endpoint_count += 1;
			continue;
		}
		const int32_t from_source_zone_id = owners[size_t(from_owner_index)].source_zone_id;
		const int32_t to_source_zone_id = owners[size_t(to_owner_index)].source_zone_id;
		append_source_endpoint_record_0x4a1f3b(owners[size_t(from_owner_index)], int32_t(link_index), link.to_index, to_source_zone_id, link, false);
		append_source_endpoint_record_0x4a1f3b(owners[size_t(to_owner_index)], int32_t(link_index), link.from_index, from_source_zone_id, link, true);
		append_relation_record_0x49f7c4(owners[size_t(from_owner_index)], int32_t(link_index), link.to_index, to_source_zone_id, link, false);
		append_relation_record_0x49f7c4(owners[size_t(to_owner_index)], int32_t(link_index), link.from_index, from_source_zone_id, link, true);
	}
	for (GeneratorRelationOwnerState4a218c &owner : owners) {
		owner.source_endpoint_vector_0xc8_0xcc_count = int32_t(owner.source_endpoint_records_0xc8_0xcc.size());
	}

	return owners;
}

static bool apply_relation_owner_scan_bounds_from_generated_cells_0x4a1f3b(const GeneratedCellRecordGrid0x30 &grid, GeneratorRelationOwnerState4a218c &owner) {
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || grid.records.empty() || !owner.coordinate_triple_0x10_0x18_known) {
		return false;
	}
	const int64_t seed_flat = cell_index(grid.width, grid.height, owner.coordinate_x_0x10, owner.coordinate_y_0x14, owner.coordinate_level_0x18);
	if (seed_flat < 0 || seed_flat >= int64_t(grid.records.size())) {
		return false;
	}
	const GeneratedCellRecord0x30 &seed_record = grid.records[size_t(seed_flat)];
	if (!seed_record.word_0x20_known) {
		return false;
	}
	const int32_t owner_byte2 = generated_cell_owner_byte2_signed_4a4142(seed_record.word_0x20);
	if (owner_byte2 < 0) {
		return false;
	}

	int32_t low_x = grid.width;
	int32_t low_y = grid.height;
	int32_t high_x = -1;
	int32_t high_y = -1;
	for (int32_t y = 0; y < grid.height; ++y) {
		for (int32_t x = 0; x < grid.width; ++x) {
			const int64_t flat = cell_index(grid.width, grid.height, x, y, owner.coordinate_level_0x18);
			if (flat < 0 || flat >= int64_t(grid.records.size())) {
				continue;
			}
			const GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
			if (!record.word_0x20_known || generated_cell_owner_byte2_signed_4a4142(record.word_0x20) != owner_byte2) {
				continue;
			}
			low_x = std::min(low_x, x);
			low_y = std::min(low_y, y);
			high_x = std::max(high_x, x + 1);
			high_y = std::max(high_y, y + 1);
		}
	}
	if (high_x <= low_x || high_y <= low_y) {
		return false;
	}
	owner.scan_bounds_0x20_0x2c_known = true;
	owner.scan_bound_low_x_0x20 = low_x;
	owner.scan_bound_low_y_0x24 = low_y;
	owner.scan_bound_high_x_0x28 = high_x;
	owner.scan_bound_high_y_0x2c = high_y;
	return true;
}

static void apply_relation_owner_scan_bounds_from_generated_cells_0x4a1f3b(GeneratorObjectPrivateState &state) {
	state.relation_owner_scan_bounds_0x4a1f3b_applied = true;
	state.relation_owner_scan_bounds_known_count_0x4a1f3b = 0;
	state.relation_owner_scan_bounds_blocked_count_0x4a1f3b = 0;
	for (GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (apply_relation_owner_scan_bounds_from_generated_cells_0x4a1f3b(state.generated_cell_buffer, owner)) {
			state.relation_owner_scan_bounds_known_count_0x4a1f3b += 1;
		} else {
			state.relation_owner_scan_bounds_blocked_count_0x4a1f3b += 1;
		}
	}
}

static void apply_endpoint_materialization_state_d014(GeneratorObjectPrivateState &state) {
	state.endpoint_projection_records_c8_cc.clear();
	bool projection_vectors_known = state.relation_owner_records_10e4_10e8_partial_known
			&& state.relation_record_missing_endpoint_count_10e4_10e8 == 0;
	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		projection_vectors_known = projection_vectors_known
				&& owner.source_endpoint_vector_0xc8_0xcc_present
				&& owner.source_endpoint_vector_0xc8_0xcc_contents_known
				&& owner.source_endpoint_vector_0xc8_0xcc_count_known
				&& owner.source_endpoint_vector_0xc8_0xcc_count == int32_t(owner.source_endpoint_records_0xc8_0xcc.size());
		for (const GeneratorSourceEndpointRecordState4a1f3b &record : owner.source_endpoint_records_0xc8_0xcc) {
			state.endpoint_projection_records_c8_cc.push_back(record);
		}
	}

	state.endpoint_projection_vector_c8_cc_record_count = int32_t(state.endpoint_projection_records_c8_cc.size());
	state.endpoint_projection_vector_c8_cc_source_owned_0x4a1f3b = projection_vectors_known;
	state.endpoint_vector_c8_cc = generator_object_vector_state(
			"source_owned_endpoint_projection_vector_0xc8_0xcc_from_0x4a1f3b",
			0xc8U,
			0xccU,
			0U,
			true,
			projection_vectors_known,
			projection_vectors_known,
			projection_vectors_known ? state.endpoint_projection_vector_c8_cc_record_count : 0,
			0x1c);

	state.endpoint_cursor_vector_d8_dc_source_owned = false;
	state.endpoint_cursor_vector_d8_dc_supported_land_exclusion_known = true;
	state.endpoint_vector_d8_dc = generator_object_vector_state(
			"endpoint_cursor_pointer_vector_0xd8_0xdc_supported_land_key_range_0_7",
			0xd8U,
			0xdcU,
			0U,
			true,
			false,
			true,
			SUPPORTED_LAND_ENDPOINT_CURSOR_KEY_COUNT_0XD8_0XDC,
			4);
	state.endpoint_byte_state_vector_1104_1108 = endpoint_byte_state_vector_from_d8_count_0x49f95a(state.endpoint_vector_d8_dc);

	state.endpoint_cursor_producer_d014.recovered_supported_land_exclusion_known = true;
	state.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_range_known = true;
	state.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_count =
			SUPPORTED_LAND_ENDPOINT_CURSOR_KEY_COUNT_0XD8_0XDC;
	state.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c_known = true;
	state.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c =
			SUPPORTED_LAND_OBSERVED_STALE_CURSOR_0XF5C;
	state.endpoint_cursor_producer_d014.setup_zeroed_cursor_0xf58_0x49ecf2_known =
			state.endpoint_cursor_0xf58_present && state.endpoint_cursor_0xf58_known && state.endpoint_cursor_0xf58 == 0;
	state.endpoint_cursor_producer_d014.endpoint_byte_state_zero_init_from_d8_count_0x49f95a_known =
			state.endpoint_byte_state_vector_1104_1108.present
			&& state.endpoint_byte_state_vector_1104_1108.count_sourced_from_vector
			&& state.endpoint_byte_state_vector_1104_1108.count_known
			&& state.endpoint_byte_state_vector_1104_1108.contents_known
			&& state.endpoint_byte_state_vector_1104_1108.zero_initialized_contents_known_when_count_known;
	state.endpoint_cursor_producer_d014.direct_cursor_writer_surface_bounded = true;
	state.endpoint_cursor_producer_d014.setup_seeds_cursor_0xf5c = false;
	state.endpoint_cursor_producer_d014.successful_cursor_0xf5c_seed_source_known = false;
	state.endpoint_cursor_producer_d014.supported_land_success_path_reached = false;
	state.endpoint_cursor_producer_d014.supported_land_live_0x4a606b_reached = false;
	state.endpoint_cursor_producer_d014.supported_land_live_0x4a696b_relation_match_reached = false;
	state.endpoint_cursor_producer_d014.direct_cursor_writer_entries = {
		"0x4a5e73",
		"0x4adb72",
		"0x4add76",
	};
	state.endpoint_cursor_producer_d014.direct_cursor_writer_entry_count =
			int32_t(state.endpoint_cursor_producer_d014.direct_cursor_writer_entries.size());
	state.endpoint_cursor_producer_d014.missing_cursor_seed_source =
			"successful_generator_0xf5c_seed_source_before_0x4a5e73_endpoint_materialization";

	state.connection_materialization_caller_prep_d014.recovered_helper_contract_0x4a5e73_known = true;
	state.connection_materialization_caller_prep_d014.recovered_explicit_input_0x4a606b_known = true;
	state.connection_materialization_caller_prep_d014.recovered_no_object_projection_chain_0x4a5a23_known = true;
	state.connection_materialization_caller_prep_d014.live_0x4a5e73_to_0x4a606b_target_mode_excluded = true;
	state.connection_materialization_caller_prep_d014.live_0x4a696b_target_mode_excluded = true;
	state.connection_materialization_caller_prep_d014.fallback_0x4a7605_to_0x4a5e03_source_backed = true;
	state.connection_materialization_caller_prep_d014.live_endpoint_materialization_allowed = false;
	state.connection_materialization_caller_prep_d014.remaining_live_materialization_blocker =
			"source_order_fallback_0x4a7605_0x4a5e03_caller_order_pending_after_exact_payload_commit_helper_port";
	state.connection_fallback_materialization_0x4a7605_0x4a5e03_known = true;
	state.connection_fallback_materialization_record_count =
			int32_t(recovered_supported_land_connection_fallback_records_4a7605_4a5e03().size());
	state.connection_fallback_materialization_records_0x4a7605_0x4a5e03 =
			recovered_supported_land_connection_fallback_records_4a7605_4a5e03();
}

static void apply_relation_normalization_full_grid_reset_0x4a5767(GeneratorObjectPrivateState &state) {
	state.relation_normalization_4a5767_full_grid_reset_applied = true;
	for (GeneratedCellRecord0x30 &record : state.generated_cell_buffer.records) {
		state.relation_normalization_4a5767_full_grid_reset_visited_count += 1;
		if (!record.word_0x20_known || !record.word_0x28_known) {
			state.relation_normalization_4a5767_full_grid_reset_skipped_count += 1;
			continue;
		}
		if (generated_cell_4a5767_reset_projection(record)) {
			state.relation_normalization_4a5767_full_grid_reset_changed_count += 1;
		}
	}
}

static void overlay_generated_cell_words(GeneratedCellRecordGrid0x30 &grid, const std::vector<uint32_t> &word_0x10, const std::vector<uint32_t> &word_0x1c, const std::vector<uint32_t> &word_0x20, const std::vector<uint32_t> &word_0x24, const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c) {
	for (size_t index = 0; index < grid.records.size(); ++index) {
		GeneratedCellRecord0x30 &record = grid.records[index];
		if (index < word_0x10.size()) {
			record.word_0x10_known = true;
			record.word_0x10 = word_0x10[index];
		}
		if (index < word_0x1c.size()) {
			record.word_0x1c_known = true;
			record.word_0x1c = word_0x1c[index];
		}
		if (index < word_0x20.size()) {
			record.word_0x20_known = true;
			record.word_0x20 = word_0x20[index];
		}
		if (index < word_0x24.size()) {
			record.word_0x24_known = true;
			record.word_0x24 = word_0x24[index];
		}
		if (index < word_0x28.size()) {
			record.word_0x28_known = true;
			record.word_0x28 = word_0x28[index];
		}
		if (index < word_0x2c.size()) {
			record.word_0x2c_known = true;
			record.word_0x2c = word_0x2c[index];
		}
	}
}

GeneratorObjectPrivateState generator_object_private_state_from_recovered_partial_chain(int32_t width, int32_t height, int32_t level_count, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result) {
	GeneratorObjectPrivateState state;
	state.width = width;
	state.height = height;
	state.level_count = level_count;
	state.generated_cell_buffer = generated_cell_record_grid_reset_0x49a072(width, height, level_count);
	state.generated_cell_buffer_owned = !state.generated_cell_buffer.records.empty();
	if (coordinate_result.terrain_repaint_executed) {
		overlay_generated_cell_words(
				state.generated_cell_buffer,
				coordinate_result.terrain_repaint.generated_cell_word_0x10,
				coordinate_result.terrain_repaint.generated_cell_word_0x1c,
				coordinate_result.terrain_repaint.generated_cell_word_0x20,
				coordinate_result.terrain_repaint.generated_cell_word_0x24,
				coordinate_result.terrain_repaint.generated_cell_word_0x28,
				coordinate_result.terrain_repaint.generated_cell_word_0x2c);
	} else if (coordinate_result.owner_grid_executed) {
		overlay_generated_cell_words(
				state.generated_cell_buffer,
				{},
				{},
				coordinate_result.owner_grid.materialization.generated_cell_word_0x20,
				{},
				{},
				{});
	}
	apply_relation_normalization_full_grid_reset_0x4a5767(state);

	state.endpoint_vector_c8_cc = generator_object_vector_state("endpoint_projection_pointer_vector_0xc8_0xcc", 0xc8U, 0xccU, 0U, true, false, false, 0, 4);
	state.endpoint_vector_d8_dc = generator_object_vector_state("endpoint_cursor_pointer_vector_0xd8_0xdc", 0xd8U, 0xdcU, 0U, true, false, false, 0, 4);
	state.object_record_vector_ec4_ecc = generator_object_vector_state("object_record_vector_0xec4_0xecc", 0xec4U, 0xeccU, 0U, true, false, false, 0, 4);
	state.source_pair_vector_edc = generator_object_vector_state("source_pair_metadata_vector_0xedc", 0xedcU, 0U, 0U, true, false, false, 0, 8);
	state.pending_entry_vector_eec_ef0_ef4 = generator_object_vector_state("source_handler_pending_entry_vector_0xeec_0xef0_0xef4_source_excluded_for_direct_mode", 0xeecU, 0xef0U, 0xef4U, true, false, true, 0, 8);
	state.candidate_container_vector_10d4_10d8 = generator_object_vector_state("accepted_candidate_container_vector_0x10d4_0x10d8", 0x10d4U, 0x10d8U, 0U, template_selection.accepted_template_count > 0 || !template_selection.accepted_candidate_containers_10d4_10d8.empty(), true, true, int32_t(template_selection.accepted_candidate_containers_10d4_10d8.size()), 4);
	state.relation_vector_10e4_10e8 = generator_object_vector_state(
			"relation_vector_0x10e4_0x10e8",
			0x10e4U,
			0x10e8U,
			0U,
			!template_selection.blocked,
			false,
			!template_selection.blocked,
			int32_t(template_selection.runtime_seed.runtime_zone_seeds.size()),
			4);
	state.endpoint_byte_state_vector_1104_1108 = endpoint_byte_state_vector_from_d8_count_0x49f95a(state.endpoint_vector_d8_dc);
	state.endpoint_cursor_0xf58_present = true;
	state.endpoint_cursor_0xf58_known = true;
	state.endpoint_cursor_0xf58 = 0;
	state.endpoint_cursor_0xf5c_present = true;
	state.endpoint_cursor_0xf5c_known = false;
	state.descriptor_counter_table_0x1110_present = true;
	state.descriptor_counter_table_0x1110_contents_known = true;
	state.descriptor_counter_table_0x1110_known_count = DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	state.descriptor_counter_table_0x1110.assign(size_t(DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	state.object_record_sequence_allocator_0xf44_present = true;
	state.object_record_sequence_allocator_0xf44_known = true;
	state.object_record_sequence_allocator_0xf44 = 1;
	state.native_object_record_key_allocator_0x4a93a2_known = true;
	state.next_native_object_record_key_0x4a93a2 = 1U;
	state.weighted_scheduler_thresholds_0x4a8db2_known = !template_selection.blocked;
	state.weighted_scheduler_thresholds_0x4a8db2.reserve(template_selection.runtime_seed.runtime_zone_seeds.size());
	for (const RuntimeZoneSeedInput4a218c &runtime_zone : template_selection.runtime_seed.runtime_zone_seeds) {
		state.weighted_scheduler_thresholds_0x4a8db2.push_back(weighted_scheduler_threshold_0x4a8db2(runtime_zone.source_payload));
	}
	state.weighted_scheduler_threshold_count_0x4a8db2 = int32_t(state.weighted_scheduler_thresholds_0x4a8db2.size());
	state.source_owner_player_slots_ed8_ee0_ee4_present = template_selection.player_assignment.complete;
	state.selected_color_order_ed8_count = int32_t(template_selection.player_assignment.selected_color_order_ed8.size());
	state.raw_source_owner_slots_ee0_count = int32_t(template_selection.player_assignment.raw_ee0_slots.size());
	state.mapped_source_owner_slots_ee4_count = int32_t(template_selection.player_assignment.mapped_ee4_slots.size());
	state.relation_owner_records_10e4_10e8_partial_known = !template_selection.blocked;
	state.relation_owner_vectors_10e4_10e8 =
			relation_owner_records_from_runtime_seed_0x4a218c_0x49f7c4(
					template_selection.runtime_seed,
					coordinate_result.coordinate_seed.runtime_zone_records_after_0x49b3c1,
					coordinate_result.coordinate_seed.boundary_inputs,
					coordinate_result.coordinate_seed.placement_steps,
					state.relation_record_missing_endpoint_count_10e4_10e8);
	state.relation_owner_vector_count_10e4_10e8 = int32_t(state.relation_owner_vectors_10e4_10e8.size());
	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		state.relation_record_count_10e4_10e8 += owner.relation_record_count;
	}
	apply_relation_owner_scan_bounds_from_generated_cells_0x4a1f3b(state);
	SourceObjectResolverState4af785 relation_scan_resolver_state;
	H3MapedRng relation_scan_rng;
	if (coordinate_result.terrain_repaint_executed) {
		relation_scan_rng.state = coordinate_result.terrain_repaint.terrain_visual_rng_state_after_0x4bb74b;
	} else if (coordinate_result.terrain_selection_executed) {
		relation_scan_rng.state = coordinate_result.terrain_selection.rng_state_after;
	} else {
		relation_scan_rng.state = coordinate_result.coordinate_seed.rng_state_after;
	}
	const RelationScanConsumerResult4a5767 relation_scan_consumers =
			relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(state, relation_scan_resolver_state, relation_scan_rng, state.relation_owner_vectors_10e4_10e8);
	preserve_source_pair_vector_edc(state, relation_scan_resolver_state);
	state.relation_scan_consumers_4a5767_applied = relation_scan_consumers.applied;
	state.relation_scan_consumers_4a5767_no_object_projection_chain_complete = relation_scan_consumers.no_object_projection_chain_complete;
	state.relation_scan_consumer_owner_scan_count_4a5767 = relation_scan_consumers.owner_scan_count;
	state.relation_scan_consumer_owner_bounds_blocked_count_4a5767 = relation_scan_consumers.owner_bounds_blocked_count;
	state.relation_scan_consumer_scanned_cell_count_4a5767 = relation_scan_consumers.scanned_cell_count;
	state.relation_scan_consumer_object_branch_blocked_count_4a5767 = relation_scan_consumers.projected_chain_object_branch_blocked_count;
	state.relation_scan_consumer_projected_chain_call_count_4a5767 = relation_scan_consumers.projected_chain_call_count;
	state.relation_scan_consumer_projected_chain_occupied_stamp_count_4a5767 = relation_scan_consumers.projected_chain_occupied_stamp_count;
	state.relation_scan_consumer_projected_chain_cleanup_clear_count_4a5767 = relation_scan_consumers.projected_chain_cleanup_clear_count;
	state.relation_scan_consumer_object_branch_attempt_count_4a5767 = relation_scan_consumers.projected_chain_object_branch_attempt_count;
	state.relation_scan_consumer_object_branch_commit_count_4a5767 = relation_scan_consumers.projected_chain_object_branch_commit_count;
	const RelationHighOwnerPropagationResult49a318 high_owner_propagation =
			relation_high_owner_propagation_49a318(state.generated_cell_buffer, state.relation_owner_vectors_10e4_10e8, &state.object_records_0xec4_ecc);
	state.relation_high_owner_propagation_49a318_applied = high_owner_propagation.applied;
	state.relation_high_owner_propagation_49a318_grid_available = high_owner_propagation.grid_available;
	state.relation_high_owner_propagation_49a318_object_metadata_gate_complete = high_owner_propagation.object_metadata_gate_complete;
	state.relation_high_owner_seed_attempt_count_49a318 = high_owner_propagation.seed_attempt_count;
	state.relation_high_owner_seed_blocked_count_49a318 = high_owner_propagation.seed_blocked_count;
	state.relation_high_owner_popped_cell_count_49a318 = high_owner_propagation.popped_cell_count;
	state.relation_high_owner_same_owner_relax_count_49a318 = high_owner_propagation.same_owner_relax_count;
	state.relation_high_owner_cross_owner_high_byte_write_count_49a318 = high_owner_propagation.cross_owner_high_byte_write_count;
	state.relation_high_owner_max_queue_size_49a318 = high_owner_propagation.max_queue_size;
	state.relation_high_owner_materialized_count_49a318 = high_owner_propagation.owner_high_byte_materialized_count;
	state.relation_high_owner_sentinel_count_49a318 = high_owner_propagation.owner_high_byte_sentinel_count;
	state.relation_high_owner_seed_reports_49a318 = high_owner_propagation.seed_reports;
	apply_endpoint_materialization_state_d014(state);
	state.remaining_private_state_blockers = {
		"object_record_vector_0xec4_0xecc_live_contents_unported_until_0x4a8d2c_0x4a8db2_source_order_dispatcher_feeds_implemented_0x4a901a_scan",
		"source_pair_vector_0xedc_contents_preserved_0x4a8db2_scheduler_replay_pending",
		"relation_vector_0x10e4_0x10e8_0x49a318_callsite_order_private_state_compare_pending_after_bit22_policy_port",
		"source_order_fallback_0x4a7605_0x4a5e03_caller_order_pending_after_exact_payload_commit_helper_port",
		"live_0x4a5e73_to_0x4a606b_and_0x4a696b_endpoint_paths_target_mode_excluded_until_source_order_fallback_caller_is_ported",
		"descriptor_counter_table_0x1110_later_increment_decrement_replay_unported",
		"relation_high_owner_0x49a318_recovered_callsite_order_and_private_state_compare_pending",
	};
	return state;
}

std::vector<BoundaryCycleInput4a2777> boundary_cycles_from_source_handoffs_4a2777(const std::vector<BoundarySourceCycleHandoff4a2777> &handoffs) {
	std::vector<BoundaryCycleInput4a2777> cycles;
	cycles.reserve(handoffs.size());
	for (const BoundarySourceCycleHandoff4a2777 &handoff : handoffs) {
		BoundaryCycleInput4a2777 cycle;
		cycle.runtime_zone_index = handoff.runtime_zone_index;
			cycle.zone_word = handoff.zone_word;
			cycle.level = handoff.level;
			cycle.random_span_limit = handoff.random_span_limit;
			cycle.source_record_vector_index_4a3e9c = handoff.source_record_vector_index_4a3e9c;
			cycle.has_span_seed_4a325d = handoff.has_source_record_seed_0x10;
			cycle.span_seed_4a325d = handoff.source_record_seed_0x10;
			cycle.cycle_nodes.reserve(handoff.source_nodes.size());
		for (const SourceNodeCyclePoint4a2777 &source_node : handoff.source_nodes) {
			BoundaryCyclePoint4a2777 point;
			point.model_node_index = source_node.model_node_index;
			point.pair_index = source_node.pair_index;
			point.next_index = source_node.next_index;
			point.previous_index = source_node.previous_index;
			point.next_pair_index = source_node.next_pair_index;
			point.raw_x_0x00 = source_node.raw_x_0x00;
			point.raw_y_0x04 = source_node.raw_y_0x04;
			point.finalized_x_0x1c = source_node.finalized_x_0x1c;
			point.finalized_y_0x20 = source_node.finalized_y_0x20;
			point.x = source_node.finalized_x_0x1c;
			point.y = source_node.finalized_y_0x20;
			point.finalized = source_node.finalized;
			point.has_payload = source_node.has_payload;
			point.payload = source_node.payload;
			point.next_pair_has_payload = source_node.next_pair_has_payload;
			point.next_pair_payload = source_node.next_pair_payload;
			cycle.cycle_nodes.push_back(point);
		}
		cycles.push_back(std::move(cycle));
	}
	return cycles;
}

BoundaryLineWriteResult boundary_line_writer_4a261a(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level) {
	BoundaryLineWriteResult result;
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
	const int32_t diagonal_step_y = sign_for_line_4a261a(dy);
	if (dx > abs_dy) {
		major = dx;
		minor = abs_dy;
		simple_step_x = 1;
		simple_step_y = 0;
	} else {
		major = abs_dy;
		minor = dx;
		simple_step_x = 0;
		simple_step_y = sign_for_line_4a261a(dy);
	}

	int32_t error = major / 2;
	int32_t x = x1;
	int32_t y = y1;
	while (x != x2 || y != y2) {
		write_line_cell_4a261a(result, width, height, level_count, generator_mode_0x10b8, x, y, zone_id, level);
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
	write_line_cell_4a261a(result, width, height, level_count, generator_mode_0x10b8, x, y, zone_id, level, false);
	return result;
}

BoundaryLineWriteResult boundary_randomized_line_writer_4a2413(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level, int32_t random_span_limit, H3MapedRng &rng, int32_t &rng_call_count, int32_t &inserted_midpoint_count, int32_t &max_pending_point_count) {
	BoundaryLineWriteResult result;
	std::vector<BoundaryPoint> pending;
	pending.push_back(BoundaryPoint { x2, y2 });
	max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	int32_t current_x = x1;
	int32_t current_y = y1;
	for (int32_t guard = 0; guard < 4096 && !pending.empty(); ++guard) {
		const BoundaryPoint target = pending.back();
		pending.pop_back();
		const int32_t midpoint_x = signed_half_round_4a2413(target.x + current_x + 1);
		const int32_t midpoint_y = signed_half_round_4a2413(target.y + current_y + 1);
		if ((midpoint_x == current_x && midpoint_y == current_y) || (midpoint_x == target.x && midpoint_y == target.y)) {
			const int32_t clamped_x = std::min(std::max(current_x, 0), width - 1);
			const int32_t clamped_y = std::min(std::max(current_y, 0), height - 1);
			write_line_cell_4a261a(result, width, height, level_count, generator_mode_0x10b8, clamped_x, clamped_y, zone_id, level);
			current_x = target.x;
			current_y = target.y;
			continue;
		}
		const int32_t dx = target.x - current_x;
		const int32_t neg_dy = current_y - target.y;
		const int32_t segment_length = distance_truncate(0, 0, dx, neg_dy);
		int32_t jittered_x = midpoint_x;
		int32_t jittered_y = midpoint_y;
		if (segment_length > 1) {
			const int32_t jitter_limit = std::max<int32_t>(1, std::min(random_span_limit, segment_length));
			const int32_t rng_value = rng.next();
			rng_call_count += 1;
			const int32_t centered_offset = (rng_value % jitter_limit) - signed_half_round_4a2413(jitter_limit);
			const int32_t adjusted_x = (int64_t(centered_offset) * int64_t(neg_dy)) / int64_t(segment_length);
			const int32_t adjusted_y = (int64_t(dx) * int64_t(centered_offset)) / int64_t(segment_length);
			jittered_x += adjusted_x;
			jittered_y += adjusted_y;
		}
		pending.push_back(target);
		pending.push_back(BoundaryPoint { jittered_x, jittered_y });
		inserted_midpoint_count += 1;
		max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	}
	return result;
}

void apply_line_trace_to_zone_buffer_4a2777(const BoundaryLineWriteResult &line, std::vector<uint32_t> &zone_words, std::vector<uint32_t> &generated_cell_word_0x20, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count) {
	for (const BoundaryLineCellWrite &write : line.trace) {
		if (write.x < 0 || write.y < 0 || write.level < 0 || write.x >= width || write.y >= height || write.level >= level_count) {
			continue;
		}
		const int64_t key = generated_cell_flat_key_4a325d(width, height, write.x, write.y, write.level);
		if (key < 0 || key >= int64_t(zone_words.size()) || key >= int64_t(cell_flags.size())) {
			continue;
		}
		generated_cell_apply_owner_word_4a2777(zone_words, generated_cell_word_0x20, key, write.zone_id);
		if (write.reserved) {
			cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
		}
	}
}

BoundaryMaterialization4a2777 materialize_boundary_cycles_4a2777(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<BoundaryCycleInput4a2777> &cycles) {
	BoundaryMaterialization4a2777 result;
	result.width = width;
	result.height = height;
	result.level_count = level_count;
	result.generator_mode_0x10b8 = generator_mode_0x10b8;
	result.rng_state_before = rng_state;
	result.rng_state_after = rng_state;
	if (width <= 0 || height <= 0 || level_count <= 0) {
		return result;
	}
	const int64_t cell_count = int64_t(width) * int64_t(height) * int64_t(level_count);
	if (cell_count <= 0) {
		return result;
	}

	result.private_zone_words.assign(size_t(cell_count), UNASSIGNED_ZONE_WORD);
	const GeneratedCellWordGrid generated = generated_cell_grid_reset_0x49a072(width, height, level_count);
	result.generated_cell_word_0x20 = generated.word_0x20;
	result.cell_flags.assign(size_t(cell_count), 0U);

	H3MapedRng rng;
	rng.state = rng_state;
	const ClipBounds bounds { 0, 0, width, height };
	std::map<int64_t, bool> unique_cells;

	auto append_vertex = [&](BoundaryZoneMaterialization4a2777 &zone, int32_t x, int32_t y, uint32_t callsite) {
		if (!boundary_vector_append_4a2777(result.boundary_vector, x, y, callsite)) {
			return;
		}
		zone.appended_vertices.push_back(result.boundary_vector.records.back());
		result.appended_vertex_count += 1;
	};

	auto append_segment = [&](BoundaryZoneMaterialization4a2777 &zone, const std::string &id, const std::string &branch, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_word, int32_t level, bool randomized, int32_t random_span_limit) {
		BoundaryLineWriteResult line;
		if (randomized) {
			line = boundary_randomized_line_writer_4a2413(
					width,
					height,
					level_count,
					generator_mode_0x10b8,
					x1,
					y1,
					x2,
					y2,
					zone_word,
					level,
					std::max<int32_t>(1, random_span_limit),
					rng,
					result.randomized_rng_call_count,
					result.randomized_inserted_midpoint_count,
					result.randomized_max_pending_point_count);
			result.flagged_writer_segment_count += 1;
		} else {
			line = boundary_line_writer_4a261a(width, height, level_count, generator_mode_0x10b8, x1, y1, x2, y2, zone_word, level);
			result.deterministic_writer_segment_count += 1;
		}
		merge_boundary_line_4a2777(line, unique_cells, result);
		apply_line_trace_to_zone_buffer_4a2777(line, result.private_zone_words, result.generated_cell_word_0x20, result.cell_flags, width, height, level_count);

		BoundarySegment4a2777 segment;
		segment.id = id;
		segment.branch = branch;
		segment.writer = randomized ? "0x4a2413" : "0x4a261a";
		segment.from_x = x1;
		segment.from_y = y1;
		segment.to_x = x2;
		segment.to_y = y2;
		segment.randomized = randomized;
		segment.line = std::move(line);
		zone.segments.push_back(std::move(segment));
	};

	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};

	auto source_edge_writer_allowed = [](const BoundaryCyclePoint4a2777 &from_node, int32_t zone_word) {
		return !(from_node.next_pair_has_payload && from_node.next_pair_payload <= zone_word);
	};

	auto append_border_connection = [&](BoundaryZoneMaterialization4a2777 &zone, int32_t &current_x, int32_t &current_y, int32_t target_x, int32_t target_y, int32_t zone_word, int32_t level, int32_t random_span_limit) {
		if (current_x == target_x && current_y == target_y) {
			return;
		}
		const int32_t right_x = std::max<int32_t>(bounds.min_x, bounds.max_x - 1);
		const int32_t bottom_y = std::max<int32_t>(bounds.min_y, bounds.max_y - 1);
		int32_t wrap_guard = 0;
		while (current_x != target_x && current_y != target_y && point_on_clip_border(current_x, current_y) && point_on_clip_border(target_x, target_y) && wrap_guard < 8) {
			int32_t border_x = current_x;
			int32_t border_y = current_y;
			std::string branch = "0x4a2aa7_bottom_edge_to_min_x";
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
			append_segment(zone, "wrap", branch, current_x, current_y, border_x, border_y, zone_word, level, false, random_span_limit);
			append_vertex(zone, current_x, current_y, BOUNDARY_VECTOR_APPEND_4A2777_WRAP_CONTINUATION_ENDPOINT);
			current_x = border_x;
			current_y = border_y;
			result.wrap_segment_count += 1;
			wrap_guard += 1;
		}
		if (wrap_guard >= 8 && current_x != target_x && current_y != target_y) {
			result.loop_guard_exhausted = true;
			return;
		}
		if (current_x != target_x || current_y != target_y) {
			append_segment(
					zone,
					"final",
					"0x4a2af2_final_segment_to_real_cycle_endpoint",
					current_x,
					current_y,
					target_x,
					target_y,
					zone_word,
					level,
					false,
					random_span_limit);
			append_vertex(zone, current_x, current_y, BOUNDARY_VECTOR_APPEND_4A2777_FINAL_CLIPPED_ENDPOINT);
			result.final_segment_count += 1;
			current_x = target_x;
			current_y = target_y;
		}
	};

	for (size_t cycle_index = 0; cycle_index < cycles.size(); ++cycle_index) {
		const BoundaryCycleInput4a2777 &cycle = cycles[cycle_index];
		BoundaryZoneMaterialization4a2777 zone;
			zone.runtime_zone_index = cycle.runtime_zone_index;
			zone.zone_word = cycle.zone_word;
			zone.level = cycle.level;
			zone.source_record_vector_index_4a3e9c = cycle.source_record_vector_index_4a3e9c;
			zone.status = "blocked_before_cycle_consumption";
		zone.has_span_seed_4a325d = cycle.has_span_seed_4a325d;
		zone.span_seed_4a325d = cycle.span_seed_4a325d;
		zone.effective_span_seed_4a325d = cycle.span_seed_4a325d;

		if (cycle.runtime_zone_index < 0 || cycle.level < 0 || cycle.level >= level_count) {
			result.blocked_zone_count += 1;
			zone.status = "blocked_invalid_runtime_zone_or_level";
			result.zones.push_back(std::move(zone));
			continue;
		}

		for (const BoundaryCyclePoint4a2777 &node : cycle.cycle_nodes) {
			if (!node.finalized) {
				result.skipped_unfinalized_node_count += 1;
				continue;
			}
			zone.finalized_points.push_back(node);
		}

		if (zone.finalized_points.size() < 2) {
			result.blocked_zone_count += 1;
			zone.status = "blocked_no_finalized_cycle_segments";
			result.zones.push_back(std::move(zone));
			continue;
		}

		const bool flagged_branch = !(level_count == 2 && cycle.level != 1);
		const int32_t random_span_limit = std::max<int32_t>(1, cycle.random_span_limit);
		int32_t selected_segment_index = -1;
		ClipResult clipped_current;
		ClipResult clipped_target;
		for (int32_t index = 0; index < int32_t(zone.finalized_points.size()); ++index) {
			const BoundaryCyclePoint4a2777 &from = zone.finalized_points[size_t(index)];
			const BoundaryCyclePoint4a2777 &to = zone.finalized_points[size_t((index + 1) % int32_t(zone.finalized_points.size()))];
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			const ClipResult candidate_current = clip_point_4a2b33(from.x, from.y, to.x, to.y, bounds);
			const ClipResult candidate_target = clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777(candidate_current, bounds)) {
				result.skipped_out_of_bounds_clip_count += 1;
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
			result.fallback_zone_count += 1;
			zone.status = "0x4a2777_rectangle_fallback_materialized";
			const int32_t min_x = bounds.min_x;
			const int32_t min_y = bounds.min_y;
			const int32_t max_x = std::max<int32_t>(bounds.min_x, bounds.max_x - 1);
			const int32_t max_y = std::max<int32_t>(bounds.min_y, bounds.max_y - 1);
			struct RectangleEdge {
				const char *id;
				int32_t x1;
				int32_t y1;
				int32_t x2;
				int32_t y2;
			};
			const std::array<RectangleEdge, 4> edges = { {
					{ "rectangle_right", max_x, max_y, max_x, min_y },
					{ "rectangle_top", max_x, min_y, min_x, min_y },
					{ "rectangle_left", min_x, min_y, min_x, max_y },
					{ "rectangle_bottom", min_x, max_y, max_x, max_y },
			} };
			for (const RectangleEdge &edge : edges) {
				append_segment(zone, edge.id, "0x4a2847_rectangle_fallback", edge.x1, edge.y1, edge.x2, edge.y2, cycle.zone_word, cycle.level, false, random_span_limit);
				result.rectangle_edge_segment_count += 1;
			}
			append_vertex(zone, max_x, max_y, BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_0);
			append_vertex(zone, max_x, min_y, BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_1);
			append_vertex(zone, min_x, min_y, BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_2);
			append_vertex(zone, min_x, max_y, BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_3);
			result.zones.push_back(std::move(zone));
			continue;
		}

		zone.status = "0x4a2777_real_source_cycle_consumed";
		zone.selected_segment_index = selected_segment_index;
		append_vertex(zone, clipped_current.x, clipped_current.y, BOUNDARY_VECTOR_APPEND_4A2777_SELECTED_CLIPPED_ENDPOINT);
		if (source_edge_writer_allowed(zone.finalized_points[size_t(selected_segment_index)], cycle.zone_word)) {
			append_segment(
					zone,
					"connector",
					"0x4a2911_connector_segment_from_real_source_cycle",
					clipped_current.x,
					clipped_current.y,
					clipped_target.x,
					clipped_target.y,
					cycle.zone_word,
					cycle.level,
					flagged_branch,
					random_span_limit);
			result.connector_segment_count += 1;
		} else {
			result.owner_gate_skipped_segment_count += 1;
		}

		int32_t current_x = clipped_target.x;
		int32_t current_y = clipped_target.y;
		int32_t source_index = (selected_segment_index + 1) % int32_t(zone.finalized_points.size());
		for (int32_t guard = 0; guard < int32_t(zone.finalized_points.size()) + 4; ++guard) {
			const int32_t next_source_index = (source_index + 1) % int32_t(zone.finalized_points.size());
			if (source_index == selected_segment_index) {
				break;
			}
			const BoundaryCyclePoint4a2777 &from = zone.finalized_points[size_t(source_index)];
			const BoundaryCyclePoint4a2777 &to = zone.finalized_points[size_t(next_source_index)];
			source_index = next_source_index;
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			const ClipResult from_clip = clip_point_4a2b33(from.x, from.y, to.x, to.y, bounds);
			const ClipResult to_clip = clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777(from_clip, bounds) || !point_inside_bounds_4a2777(to_clip, bounds)) {
				result.skipped_out_of_bounds_clip_count += 1;
				continue;
			}

			append_border_connection(zone, current_x, current_y, from_clip.x, from_clip.y, cycle.zone_word, cycle.level, random_span_limit);
			if (result.loop_guard_exhausted) {
				break;
			}
			if (from_clip.x != to_clip.x || from_clip.y != to_clip.y) {
				if (!source_edge_writer_allowed(from, cycle.zone_word)) {
					result.owner_gate_skipped_segment_count += 1;
					continue;
				}
				append_segment(
						zone,
						"connector",
						"0x4a2911_connector_segment_from_real_source_cycle",
						from_clip.x,
						from_clip.y,
						to_clip.x,
						to_clip.y,
						cycle.zone_word,
						cycle.level,
						false,
						random_span_limit);
				result.connector_segment_count += 1;
				current_x = to_clip.x;
				current_y = to_clip.y;
			}
			if (source_index == selected_segment_index) {
				break;
			}
		}

		result.runtime_zone_walk_count += 1;
		result.zones.push_back(std::move(zone));
	}

	std::map<int64_t, bool> span_fill_unique_cells;
	for (BoundaryZoneMaterialization4a2777 &zone : result.zones) {
		if (!zone.has_span_seed_4a325d || zone.segments.empty()) {
			continue;
		}
		SpanRecord seed = zone.span_seed_4a325d;
		zone.span_seed_relocation_status_4a325d = "0x4a325d_seed_in_bounds_relocation_not_used";
		if (!span_cell_in_bounds_4a325d(width, height, level_count, seed)) {
			int32_t best_x = -1;
			int32_t best_y = -1;
			int32_t best_clearance = -1;
			for (const BoundaryCyclePoint4a2777 &point : zone.finalized_points) {
				const bool interior = point.x >= 1 && point.x < width - 1 && point.y >= 1 && point.y < height - 1;
				if (!interior) {
					continue;
				}
				const int32_t clearance = std::min<int32_t>(
						std::min<int32_t>(point.x, width - point.x - 1),
						std::min<int32_t>(point.y, height - point.y - 1));
				if (clearance > best_clearance) {
					best_clearance = clearance;
					best_x = point.x;
					best_y = point.y;
				}
			}
			if (best_x >= 0 && best_y >= 0) {
				const ClipResult clipped = clip_point_4a2b33(seed.x, seed.y, best_x, best_y, bounds);
				seed.x = clipped.x;
				seed.y = clipped.y;
				zone.span_seed_relocated_4a325d = true;
				zone.span_seed_relocation_status_4a325d = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
				result.span_fill_seed_relocated_count += 1;
			} else {
				zone.span_seed_relocation_status_4a325d = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
			}
		}
		zone.effective_span_seed_4a325d = seed;
		if (!span_cell_in_bounds_4a325d(width, height, level_count, seed)) {
			result.span_fill_seed_blocked_count += 1;
			continue;
		}
		if (!generated_cell_owner_unassigned_4a325d(result.generated_cell_word_0x20, width, height, seed.x, seed.y, seed.level)) {
			result.span_fill_seed_blocked_count += 1;
		}
		SpanFillResult fill = span_fill_4a325d(
				result.private_zone_words,
				result.generated_cell_word_0x20,
				result.cell_flags,
				width,
				height,
				level_count,
				generator_mode_0x10b8,
				zone.zone_word,
				seed);
		for (const auto &item : fill.unique_cells) {
			unique_cells[item.first] = true;
			span_fill_unique_cells[item.first] = true;
		}
		zone.span_fill_executed_4a325d = true;
		result.span_fill_trace_write_count += int32_t(fill.trace.size());
		result.span_fill_unique_cell_count = int32_t(span_fill_unique_cells.size());
		result.span_fill_out_of_bounds_span_count += fill.out_of_bounds_span_count;
		result.span_fill_pushed_span_count += fill.pushed_span_count;
		result.span_fill_popped_span_count += fill.popped_span_count;
		result.span_fill_max_pending_span_count = std::max<int32_t>(result.span_fill_max_pending_span_count, fill.max_pending_span_count);
		result.span_fill_blocked_initial_span_count += fill.blocked_initial_span_count;
		if (!fill.trace.empty()) {
			result.span_fill_zone_count += 1;
		}
		zone.span_fill_4a325d = std::move(fill);
	}

	result.unique_cell_count = int32_t(unique_cells.size());
	result.rng_state_after = rng.state;
	return result;
}

BoundaryMaterialization4a2777 materialize_boundary_source_handoffs_4a2777_4a325d(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<BoundarySourceCycleHandoff4a2777> &handoffs) {
	std::vector<BoundaryCycleInput4a2777> cycles = boundary_cycles_from_source_handoffs_4a2777(handoffs);
	BoundaryMaterialization4a2777 result = materialize_boundary_cycles_4a2777(width, height, level_count, generator_mode_0x10b8, rng_state, cycles);
		result.source_handoff_count = int32_t(handoffs.size());
		for (const BoundarySourceCycleHandoff4a2777 &handoff : handoffs) {
			result.source_handoff_point_count += int32_t(handoff.source_nodes.size());
			if (handoff.has_source_record_seed_0x10) {
				result.source_handoff_source_record_seed_count += 1;
			} else {
				result.source_handoff_missing_source_record_seed_count += 1;
			}
			for (const SourceNodeCyclePoint4a2777 &source_node : handoff.source_nodes) {
			if (source_node.finalized) {
				result.source_handoff_finalized_point_count += 1;
			}
			if (source_node.model_node_index >= 0 || source_node.pair_index >= 0 || source_node.next_index >= 0 || source_node.previous_index >= 0 || source_node.next_pair_index >= 0) {
				result.source_handoff_descriptor_indexed_point_count += 1;
			}
			if (source_node.raw_x_0x00 != source_node.finalized_x_0x1c || source_node.raw_y_0x04 != source_node.finalized_y_0x20) {
				result.source_handoff_raw_coordinate_point_count += 1;
			}
		}
	}
	return result;
}

SpanFillResult span_fill_4a325d(std::vector<uint32_t> &zone_words, std::vector<uint32_t> &generated_cell_word_0x20, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t zone_id, const SpanRecord &seed) {
	SpanFillResult result;
	std::vector<SpanRecord> pending;
	push_span_4a325d(pending, seed, result);
	for (int32_t guard = 0; guard < width * height * std::max(1, level_count) * 4 && !pending.empty(); ++guard) {
		SpanRecord coord = pending.back();
		pending.pop_back();
		result.popped_span_count += 1;
		if (!span_cell_in_bounds_4a325d(width, height, level_count, coord)) {
			result.out_of_bounds_span_count += 1;
			continue;
		}
		int32_t x = coord.x;
		while (x > 0 && generated_cell_owner_unassigned_4a325d(generated_cell_word_0x20, width, height, x - 1, coord.y, coord.level)) {
			x -= 1;
		}
		bool wrote_row = false;
		bool above_run_open = false;
		bool below_run_open = false;
		SpanRecord above_seed;
		SpanRecord below_seed;
		for (; x < width; ++x) {
			if (!generated_cell_owner_unassigned_4a325d(generated_cell_word_0x20, width, height, x, coord.y, coord.level)) {
				break;
			}
			const int64_t key = generated_cell_flat_key_4a325d(width, height, x, coord.y, coord.level);
			if (key < 0 || key >= int64_t(zone_words.size()) || key >= int64_t(cell_flags.size())) {
				continue;
			}
			generated_cell_apply_owner_word_4a2777(zone_words, generated_cell_word_0x20, key, zone_id);
			const bool reserved = !(generator_mode_0x10b8 == 2 && coord.level != 1);
			if (reserved) {
				cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
			}
			SpanFillCellWrite write;
			write.x = x;
			write.y = coord.y;
			write.level = coord.level;
			write.zone_id = zone_id;
			write.reserved = reserved;
			result.trace.push_back(write);
			result.unique_cells[key] = true;
			wrote_row = true;
			if (coord.y > 0 && generated_cell_owner_unassigned_4a325d(generated_cell_word_0x20, width, height, x, coord.y - 1, coord.level)) {
				if (!above_run_open) {
					above_seed = SpanRecord { x, coord.y - 1, coord.level };
					above_run_open = true;
				}
			} else if (above_run_open) {
				push_span_4a325d(pending, above_seed, result);
				above_run_open = false;
			}
			if (coord.y < height - 1 && generated_cell_owner_unassigned_4a325d(generated_cell_word_0x20, width, height, x, coord.y + 1, coord.level)) {
				if (!below_run_open) {
					below_seed = SpanRecord { x, coord.y + 1, coord.level };
					below_run_open = true;
				}
			} else if (below_run_open) {
				push_span_4a325d(pending, below_seed, result);
				below_run_open = false;
			}
		}
		if (!wrote_row) {
			result.blocked_initial_span_count += 1;
		}
		if (above_run_open) {
			push_span_4a325d(pending, above_seed, result);
		}
		if (below_run_open) {
			push_span_4a325d(pending, below_seed, result);
		}
	}
	return result;
}

int32_t deplete_generated_cell_scores_4a54a7(std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t level_count, int32_t anchor_x, int32_t anchor_y, int32_t anchor_level) {
	if (width <= 0 || height <= 0 || level_count <= 0 || anchor_level < 0 || anchor_level >= level_count || generated_cell_word_0x20.empty()) {
		return 0;
	}
	const int64_t anchor_flat = cell_index(width, height, anchor_x, anchor_y, anchor_level);
	if (anchor_flat < 0 || anchor_flat >= int64_t(generated_cell_word_0x20.size())) {
		return 0;
	}

	int32_t mutation_count = 0;
	if ((generated_cell_word_0x20[size_t(anchor_flat)] & 0xffffU) != 0U) {
		mutation_count += 1;
	}
	generated_cell_word_0x20[size_t(anchor_flat)] &= 0xffff0000U;

	std::priority_queue<ScoreFrontierNode, std::vector<ScoreFrontierNode>, ScoreFrontierCompare> frontier;
	frontier.push(ScoreFrontierNode { 0, Coord { anchor_x, anchor_y, anchor_level } });
	while (!frontier.empty()) {
		const ScoreFrontierNode node = frontier.top();
		frontier.pop();
		const Coord current = node.coord;
		const int64_t current_flat = cell_index(width, height, current.x, current.y, current.level);
		if (current_flat < 0 || current_flat >= int64_t(generated_cell_word_0x20.size())) {
			continue;
		}
		const int32_t base_score = int32_t(generated_cell_word_0x20[size_t(current_flat)] & 0xffffU);
		if (node.score != base_score) {
			continue;
		}
		for (int32_t direction_index = 0; direction_index < int32_t(DIRECTION_TABLE_0X5A2658.size()); ++direction_index) {
			const int32_t next_x = current.x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0];
			const int32_t next_y = current.y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1];
			const int64_t next_flat = cell_index(width, height, next_x, next_y, current.level);
			if (next_flat < 0 || next_flat >= int64_t(generated_cell_word_0x20.size())) {
				continue;
			}
			const int32_t candidate_score = base_score + ((direction_index & 1) != 0 ? 3 : 2);
			const uint32_t next_word = generated_cell_word_0x20[size_t(next_flat)];
			const int32_t current_score = int32_t(next_word & 0xffffU);
			if (candidate_score >= current_score || candidate_score > 0xffff) {
				continue;
			}
			generated_cell_word_0x20[size_t(next_flat)] = (next_word & 0xffff0000U) | uint32_t(candidate_score);
			frontier.push(ScoreFrontierNode { candidate_score, Coord { next_x, next_y, current.level } });
			mutation_count += 1;
		}
	}
	return mutation_count;
}

} // namespace aurelion::h3maped_rmg_core
