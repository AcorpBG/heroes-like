#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <iomanip>
#include <limits>
#include <queue>
#include <set>
#include <sstream>
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

static std::string hex_u32(uint32_t value) {
	std::ostringstream stream;
	stream << "0x" << std::hex << std::setw(8) << std::setfill('0') << value;
	return stream.str();
}

constexpr int32_t SUPPORTED_LAND_ENDPOINT_CURSOR_KEY_COUNT_0XD8_0XDC = 8;
constexpr uint32_t SUPPORTED_LAND_OBSERVED_STALE_CURSOR_0XF5C = 0x7a1befdfU;
constexpr int32_t H3MAPED_MINE_OBJECT_BUCKET_0X388_TYPE_KEY = 53;

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

GeneratorSetupModeResult49ecf2 generator_setup_mode_49ecf2(uint32_t seed, int32_t setup_object_0x44, bool setup_object_0x48_known, int32_t setup_object_0x48) {
	GeneratorSetupModeResult49ecf2 result;
	result.setup_object_0x44 = setup_object_0x44;
	result.generator_mode_0x10b8 = setup_object_0x44;
	result.setup_object_0x48_known = setup_object_0x48_known;
	result.setup_object_0x48 = setup_object_0x48;
	if (setup_object_0x48_known) {
		result.generator_value_band_0x10bc_known = true;
		result.generator_value_band_0x10bc = std::min<int32_t>(5, std::max<int32_t>(1, setup_object_0x48 + 3));
	}
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

static int32_t source_object_metadata_bucket_for_type_0x57c648_0x08(int32_t type_id_0x1c) {
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	for (const SourceObjectRecord0x4c &record : records) {
		if (record.type_id_0x1c == type_id_0x1c) {
			return record.metadata_bucket_index_0x08;
		}
	}
	return -1;
}

static bool descriptor_source_cell_offset_from_secondary_mask_0x4906fb(
		const SourceObjectRecord0x4c &record,
		int32_t &source_cell_x_0x2c,
		int32_t &source_cell_y_0x30) {
	if (record.action_mask.size() < 48U) {
		return false;
	}
	for (int32_t row = 0; row < 6; ++row) {
		for (int32_t col = 0; col < 8; ++col) {
			if (record.action_mask[size_t(row * 8 + col)] == '1') {
				source_cell_x_0x2c = col;
				source_cell_y_0x30 = row;
				return true;
			}
		}
	}
	source_cell_x_0x2c = 0;
	source_cell_y_0x30 = 0;
	return true;
}

static bool source_object_descriptor_mask_bit_0x41e951(const SourceObjectRecord0x4c &record, int32_t x, int32_t y) {
	if (x < 0 || x >= 8 || y < 0 || y >= 6) {
		return false;
	}
	// 0x41e951 reads the descriptor primary mask at +0x04/+0x08.
	// The .msk fields copied into +0x34..+0x48 are a separate surface.
	const size_t text_index = size_t(y * 8 + x);
	if (record.action_mask.size() > text_index) {
		return record.action_mask[text_index] == '1';
	}
	if (record.descriptor_mask_fields_0x34_0x48_known) {
		const int32_t bit_index = 47 - (8 * y) - x;
		return (record.descriptor_mask_a_0x3c_0x40 & (uint64_t(1U) << uint32_t(bit_index))) != 0U;
	}
	return false;
}

static bool source_object_descriptor_mask_bit_0x4268eb(const SourceObjectRecord0x4c &record, int32_t x, int32_t y) {
	if (x < 0 || x >= 8 || y < 0 || y >= 6) {
		return false;
	}
	// 0x4268eb reads the descriptor secondary mask at +0x0c/+0x10.
	// Do not substitute .msk +0x44/+0x48 body fields when text masks are present.
	const size_t text_index = size_t(y * 8 + x);
	if (record.passability_mask.size() > text_index) {
		return record.passability_mask[text_index] == '0';
	}
	if (record.descriptor_mask_fields_0x34_0x48_known) {
		const int32_t bit_index = 47 - (8 * y) - x;
		return (record.descriptor_mask_b_0x44_0x48 & (uint64_t(1U) << uint32_t(bit_index))) != 0U;
	}
	return false;
}

static std::vector<CoordinateCandidate4a17f5> descriptor_body_offsets_from_primary_mask_0x49a6f9(
		const SourceObjectRecord0x4c &record,
		int32_t source_cell_x_0x2c,
		int32_t source_cell_y_0x30) {
	(void)source_cell_x_0x2c;
	(void)source_cell_y_0x30;
	std::vector<CoordinateCandidate4a17f5> offsets;
	const int32_t descriptor_width = record.descriptor_width_0x34;
	const int32_t descriptor_height = record.descriptor_height_0x38;
	if (descriptor_width <= 0 || descriptor_height <= 0) {
		return offsets;
	}
	for (int32_t row = 0; row < descriptor_height; ++row) {
		for (int32_t col = 0; col < descriptor_width; ++col) {
			if (!source_object_descriptor_mask_bit_0x4268eb(record, col, row)) {
				continue;
			}
			offsets.push_back(CoordinateCandidate4a17f5 {
					-col,
					-row,
					0 });
		}
	}
	return offsets;
}

static GeneratorDescriptorVectorEntry0x398 generator_descriptor_vector_entry_from_source_record_0x49da08(
		const SourceObjectRecord0x4c &record,
		int32_t source_catalog_index_0x49da08) {
	GeneratorDescriptorVectorEntry0x398 entry;
	entry.source_catalog_index_0x49da08 = source_catalog_index_0x49da08;
	entry.descriptor_type_0x1c = record.type_id_0x1c;
	entry.descriptor_source_field_0x20 = record.subtype_0x20;
	entry.descriptor_group_0x24 = record.group_0x24;
	entry.descriptor_last_flag_0x28 = record.last_flag_0x28;
	entry.descriptor_source_cell_offsets_0x2c_0x30_known =
			descriptor_source_cell_offset_from_secondary_mask_0x4906fb(
					record,
					entry.descriptor_source_cell_x_0x2c,
					entry.descriptor_source_cell_y_0x30);
	entry.descriptor_projection_enabled_0x29 = entry.descriptor_source_cell_offsets_0x2c_0x30_known
			&& record.action_count > 0;
	entry.descriptor_dimensions_known = record.descriptor_mask_fields_0x34_0x48_known;
	entry.descriptor_width_0x34 = record.descriptor_width_0x34;
	entry.descriptor_height_0x38 = record.descriptor_height_0x38;
	entry.descriptor_mask_a_0x3c_0x40 = record.descriptor_mask_a_0x3c_0x40;
	entry.descriptor_mask_b_0x44_0x48 = record.descriptor_mask_b_0x44_0x48;
	entry.source_record_copy = record;
	return entry;
}

static std::vector<GeneratorDescriptorVectorEntry0x398> generator_descriptor_vector_entries_from_source_catalog_0x49da08_0x398_0x39c() {
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	std::vector<GeneratorDescriptorVectorEntry0x398> entries;
	entries.reserve(records.size());
	for (int32_t index = 0; index < int32_t(records.size()); ++index) {
		entries.push_back(generator_descriptor_vector_entry_from_source_record_0x49da08(records[size_t(index)], index));
	}
	std::stable_sort(entries.begin(), entries.end(), [](const GeneratorDescriptorVectorEntry0x398 &left, const GeneratorDescriptorVectorEntry0x398 &right) {
		if (left.descriptor_source_field_0x20 != right.descriptor_source_field_0x20) {
			return left.descriptor_source_field_0x20 < right.descriptor_source_field_0x20;
		}
		return left.source_catalog_index_0x49da08 < right.source_catalog_index_0x49da08;
	});
	for (int32_t index = 0; index < int32_t(entries.size()); ++index) {
		entries[size_t(index)].vector_index = index;
	}
	return entries;
}

static bool source_record_in_mine_template_bucket_0x388_0x38c(const SourceObjectRecord0x4c &record) {
	return record.source == "objects.txt"
			&& (record.type_id_0x1c == H3MAPED_MINE_OBJECT_BUCKET_0X388_TYPE_KEY
					|| record.metadata_bucket_index_0x08 == H3MAPED_MINE_OBJECT_BUCKET_0X388_TYPE_KEY);
}

static std::vector<GeneratorDescriptorVectorEntry0x398> generator_mine_resource_descriptor_vector_entries_from_source_catalog_0x49da08_0x388_0x38c() {
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	std::vector<GeneratorDescriptorVectorEntry0x398> entries;
	for (int32_t index = 0; index < int32_t(records.size()); ++index) {
		const SourceObjectRecord0x4c &record = records[size_t(index)];
		if (!source_record_in_mine_template_bucket_0x388_0x38c(record)) {
			continue;
		}
		entries.push_back(generator_descriptor_vector_entry_from_source_record_0x49da08(record, index));
	}
	for (int32_t index = 0; index < int32_t(entries.size()); ++index) {
		entries[size_t(index)].vector_index = index;
	}
	return entries;
}

static int32_t descriptor_vector_index_for_source_catalog_index_0x398(
		const GeneratorObjectPrivateState &state,
		int32_t source_catalog_index_0x49da08) {
	for (const GeneratorDescriptorVectorEntry0x398 &entry : state.descriptor_vector_entries_398_39c) {
		if (entry.source_catalog_index_0x49da08 == source_catalog_index_0x49da08) {
			return entry.vector_index;
		}
	}
	return -1;
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
			&& left.raw_field_0x3c_known == right.raw_field_0x3c_known
			&& left.raw_field_0x3c == right.raw_field_0x3c
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

static const SourceObjectRecord0x4c *source_object_record_for_descriptor_fields_0x4a7605(
		const ConnectionFallbackMaterializationRecord4a7605_4a5e03 &record,
		int32_t &source_catalog_index_0x49da08,
		bool &ambiguous) {
	source_catalog_index_0x49da08 = -1;
	ambiguous = false;
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	const SourceObjectRecord0x4c *match = nullptr;
	for (int32_t index = 0; index < int32_t(records.size()); ++index) {
		const SourceObjectRecord0x4c &candidate = records[size_t(index)];
		if (candidate.type_id_0x1c != record.descriptor_type_0x1c
				|| candidate.subtype_0x20 != record.descriptor_subtype_0x20
				|| candidate.group_0x24 != record.descriptor_class_0x24
				|| candidate.descriptor_width_0x34 != record.descriptor_mask_width_0x34
				|| candidate.descriptor_height_0x38 != record.descriptor_mask_height_0x38) {
			continue;
		}
		if (match != nullptr) {
			ambiguous = true;
			source_catalog_index_0x49da08 = -1;
			return nullptr;
		}
		match = &candidate;
		source_catalog_index_0x49da08 = index;
	}
	return match;
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

static SourceObjectDescriptorJoinContext4903e8 descriptor_join_context_from_descriptor_0x4903e8(const SourceObjectDescriptor4903e8 &descriptor) {
	SourceObjectDescriptorJoinContext4903e8 context;
	context.target_context_0x4903e8 = descriptor.target_context_0x4903e8;
	context.source_key_0x00 = descriptor.source_key_0x00;
	context.descriptor_type_0x1c = descriptor.descriptor_type_0x1c;
	context.subtype_0x20 = descriptor.subtype_0x20;
	context.group_0x24 = descriptor.group_0x24;
	context.projection_enabled_0x29 = descriptor.projection_enabled_0x29;
	context.source_cell_x_0x2c = descriptor.source_cell_x_0x2c;
	context.source_cell_y_0x30 = descriptor.source_cell_y_0x30;
	context.score_adjust_0x30_known = descriptor.score_adjust_0x30_known;
	context.score_adjust_0x30 = descriptor.score_adjust_0x30;
	context.score_adjust_0x40_known = descriptor.score_adjust_0x40_known;
	context.score_adjust_0x40 = descriptor.score_adjust_0x40;
	context.descriptor_mask_fields_0x34_0x48_known = descriptor.descriptor_mask_fields_0x34_0x48_known;
	context.descriptor_width_0x34 = descriptor.descriptor_width_0x34;
	context.descriptor_height_0x38 = descriptor.descriptor_height_0x38;
	context.descriptor_mask_a_0x3c_0x40 = descriptor.descriptor_mask_a_0x3c_0x40;
	context.descriptor_mask_b_0x44_0x48 = descriptor.descriptor_mask_b_0x44_0x48;
	return context;
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
	if (result.resolver_0x4af785.appended_source_pair_0xedc
			&& result.resolver_0x4af785.source_pair_count_after == result.resolver_0x4af785.source_pair_count_before + 1
			&& result.resolver_0x4af785.source_pair_count_after == int32_t(state.source_pairs_0xedc.size())) {
		SourceObjectResolverSourcePair4af785 &source_pair = state.source_pairs_0xedc.back();
		source_pair.descriptor_join_0x4903e8_known = true;
		source_pair.descriptor_join_descriptor_0x4903e8 = descriptor_join_context_from_descriptor_0x4903e8(descriptor);
		source_pair.descriptor_joined_0x4903e8 = result.joined;
		source_pair.descriptor_join_source_pair_index_0xedc = result.resolver_0x4af785.source_pair_count_before;
	}
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

SourceOrderSchedulerSourceRecord4a8db2 source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(const RuntimeZoneSeedInput4a218c &runtime_zone) {
	SourceOrderSchedulerSourceRecord4a8db2 record;
	const SourceZonePayload4a218c &payload = runtime_zone.source_payload;
	record.source_id_0x00 = runtime_zone.source_index >= 0 ? runtime_zone.source_index : payload.source_row;
	record.owner_or_type_0x04 = payload.source_ownership;
	record.relation_selector_0x1c = runtime_zone.source_owner_index;
	record.field_0x20_known = true;
	record.field_0x20 = payload.player_towns.min_towns;
	record.field_0x24_known = true;
	record.field_0x24 = payload.player_towns.min_castles;
	record.field_0x28_known = true;
	record.field_0x28 = payload.player_towns.town_density;
	record.field_0x2c_known = true;
	record.field_0x2c = payload.player_towns.castle_density;
	record.field_0x30_known = true;
	record.field_0x30 = payload.neutral_towns.min_towns;
	record.field_0x34_known = true;
	record.field_0x34 = payload.neutral_towns.min_castles;
	record.field_0x38_known = true;
	record.field_0x38 = payload.neutral_towns.town_density;
	record.field_0x3c_known = true;
	record.field_0x3c = payload.neutral_towns.castle_density;
	return record;
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

static uint8_t generated_cell_byte_0x2b_from_word28(uint32_t word_0x28) {
	return uint8_t((word_0x28 >> 24U) & 0xffU);
}

static void sync_generated_cell_byte_0x2b_from_word28(GeneratedCellRecord0x30 &record) {
	if (!record.word_0x28_known) {
		record.byte_0x2b_known = false;
		record.byte_0x2b_known_mask = 0U;
		record.byte_0x2b = 0U;
		return;
	}
	record.byte_0x2b_known = true;
	record.byte_0x2b_known_mask = 0xffU;
	record.byte_0x2b = generated_cell_byte_0x2b_from_word28(record.word_0x28);
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
		sync_generated_cell_byte_0x2b_from_word28(record);
		record.byte_0x2a_known = false;
		record.byte_0x2a_known_mask = 0U;
		record.byte_0x2a = 0U;
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
	sync_generated_cell_byte_0x2b_from_word28(record);
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
						sync_generated_cell_byte_0x2b_from_word28(next_record);
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

RewardGuardRelationPriorityResult4ad7f7 reward_guard_relation_priority_ordering_0x4ad7f7(std::vector<GeneratorRelationOwnerState4a218c> &owners, int32_t source_owner_vector_index, H3MapedRng &rng, bool descriptor_filter_fields_known) {
	RewardGuardRelationPriorityResult4ad7f7 result;
	result.relation_owner_count = int32_t(owners.size());
	result.source_owner_vector_index = source_owner_vector_index;
	result.rng_state_before = rng.state;
	result.rng_state_after = rng.state;
	if (owners.empty()) {
		result.blocked_reason = "0x4ad7f7_relation_vector_10e4_10e8_empty";
		return result;
	}
	auto owner_index_by_vector_index = [&](int32_t owner_vector_index) -> int32_t {
		for (int32_t index = 0; index < int32_t(owners.size()); ++index) {
			if (owners[size_t(index)].owner_vector_index == owner_vector_index) {
				return index;
			}
		}
		return -1;
	};
	auto owner_index_by_runtime_zone = [&](int32_t runtime_zone_index) -> int32_t {
		for (int32_t index = 0; index < int32_t(owners.size()); ++index) {
			if (owners[size_t(index)].runtime_zone_index == runtime_zone_index) {
				return index;
			}
		}
		return -1;
	};
	auto insert_by_priority_0x4ccecb = [&](std::vector<int32_t> &indices, int32_t owner_index) {
		const int32_t priority = owners[size_t(owner_index)].reward_guard_priority_0x40;
		auto it = indices.begin();
		for (; it != indices.end(); ++it) {
			const int32_t existing = owners[size_t(*it)].reward_guard_priority_0x40;
			if (priority < existing) {
				break;
			}
		}
		indices.insert(it, owner_index);
	};

	const int32_t source_index = owner_index_by_vector_index(source_owner_vector_index);
	if (source_index < 0) {
		result.blocked_reason = "0x4ad7f7_source_relation_owner_index_missing";
		return result;
	}
	result.source_relation_known = true;
	result.applied = true;

	for (GeneratorRelationOwnerState4a218c &owner : owners) {
		owner.reward_guard_priority_0x40_known = true;
		owner.reward_guard_priority_0x40 = 0x4e20;
		owner.reward_guard_priority_before_randomization_0x4ad7f7 = 0x4e20;
		owner.reward_guard_priority_rng_value_0x4e7276 = -1;
		owner.reward_guard_priority_source_relation_0x4ad6a8 = false;
		result.distance_prepass_reset_count += 1;
	}
	owners[size_t(source_index)].reward_guard_priority_0x40 = 0;
	owners[size_t(source_index)].reward_guard_priority_source_relation_0x4ad6a8 = true;

	std::vector<int32_t> work;
	work.push_back(source_index);
	while (!work.empty()) {
		const int32_t current_index = work.back();
		work.pop_back();
		const int32_t next_priority = owners[size_t(current_index)].reward_guard_priority_0x40 + 1;
		for (const GeneratorSourceEndpointRecordState4a1f3b &edge : owners[size_t(current_index)].source_endpoint_records_0xc8_0xcc) {
			const int32_t target_index = owner_index_by_runtime_zone(edge.target_runtime_zone_index);
			if (target_index < 0) {
				result.distance_prepass_missing_target_count += 1;
				continue;
			}
			GeneratorRelationOwnerState4a218c &target = owners[size_t(target_index)];
			if (!target.reward_guard_priority_0x40_known || target.reward_guard_priority_0x40 > next_priority) {
				target.reward_guard_priority_0x40_known = true;
				target.reward_guard_priority_0x40 = next_priority;
				result.distance_prepass_relax_count += 1;
				insert_by_priority_0x4ccecb(work, target_index);
			}
		}
	}
	result.distance_prepass_0x4ad6a8_applied = true;

	for (GeneratorRelationOwnerState4a218c &owner : owners) {
		const int32_t priority_before = owner.reward_guard_priority_0x40;
		const int32_t rng_value = rng.next();
		result.rng_call_count += 1;
		owner.reward_guard_priority_before_randomization_0x4ad7f7 = priority_before;
		owner.reward_guard_priority_rng_value_0x4e7276 = rng_value;
		if (priority_before == 1) {
			owner.reward_guard_priority_0x40 = 1000 + (rng_value % 10);
		} else {
			owner.reward_guard_priority_0x40 = priority_before * 10 + (rng_value % 10);
		}
		result.randomized_priority_count += 1;
	}
	result.randomized_priority_pass_0x4ad7f7_applied = true;
	result.rng_state_after = rng.state;

	std::vector<int32_t> ordered_indices;
	for (int32_t index = 0; index < int32_t(owners.size()); ++index) {
		const GeneratorRelationOwnerState4a218c &owner = owners[size_t(index)];
		RewardGuardRelationPriorityEntry4ad7f7 entry;
		entry.owner_vector_index = owner.owner_vector_index;
		entry.runtime_zone_index = owner.runtime_zone_index;
		entry.source_relation = index == source_index;
		entry.priority_after_0x4ad6a8 = owner.reward_guard_priority_before_randomization_0x4ad7f7;
		entry.rng_value_0x4e7276 = owner.reward_guard_priority_rng_value_0x4e7276;
		entry.priority_after_0x4ad7f7 = owner.reward_guard_priority_0x40;
		if (entry.source_relation) {
			entry.blocked_reason = "0x4ad7f7_skips_source_relation_argument";
			result.entries.push_back(entry);
			continue;
		}
		entry.priority_limit_0x7d0_passed = owner.reward_guard_priority_0x40 <= 0x7d0;
		if (!entry.priority_limit_0x7d0_passed) {
			entry.blocked_reason = "0x4ad7f7_priority_above_0x7d0";
			result.priority_limit_reject_count += 1;
			result.entries.push_back(entry);
			continue;
		}
		const bool source_type_known = descriptor_filter_fields_known || owner.source_pointer_type_0x04_known;
		const bool terrain_policy_known = descriptor_filter_fields_known || owner.terrain_policy_0x0c_known;
		entry.descriptor_filter_fields_known = source_type_known && terrain_policy_known;
		entry.descriptor_filter_passed = false;
		if (!entry.descriptor_filter_fields_known) {
			if (!source_type_known && !terrain_policy_known) {
				entry.blocked_reason = "0x4ad7f7_source_pointer_plus_04_and_relation_plus_0x0c_missing";
			} else if (!source_type_known) {
				entry.blocked_reason = "0x4ad7f7_source_pointer_plus_04_missing";
			} else {
				entry.blocked_reason = "0x4ad7f7_relation_plus_0x0c_missing";
			}
			result.descriptor_filter_unknown_count += 1;
			result.entries.push_back(entry);
			continue;
		}
		if (!descriptor_filter_fields_known && owner.source_pointer_type_0x04 == 3) {
			entry.blocked_reason = "0x4ad7f7_source_pointer_plus_04_equals_3";
			result.source_pointer_type_0x04_reject_count += 1;
			result.entries.push_back(entry);
			continue;
		}
		if (!descriptor_filter_fields_known && owner.terrain_policy_0x0c == 8) {
			entry.blocked_reason = "0x4ad7f7_relation_plus_0x0c_equals_8";
			result.terrain_policy_0x0c_reject_count += 1;
			result.entries.push_back(entry);
			continue;
		}
		entry.descriptor_filter_passed = true;
		insert_by_priority_0x4ccecb(ordered_indices, index);
		result.entries.push_back(entry);
	}
	for (const int32_t owner_index : ordered_indices) {
		result.ordered_owner_vector_indexes_0x4ccecb.push_back(owners[size_t(owner_index)].owner_vector_index);
	}
	result.ordered_vector_0x4ccecb_built = result.descriptor_filter_unknown_count == 0;
	result.ordered_vector_ready_for_0x4aa9b7 = result.ordered_vector_0x4ccecb_built && !result.ordered_owner_vector_indexes_0x4ccecb.empty();
	if (result.descriptor_filter_unknown_count != 0) {
		result.blocked_reason = "0x4ad7f7_ordered_vector_descriptor_filters_missing_for_0x4aa9b7";
	} else if (result.ordered_owner_vector_indexes_0x4ccecb.empty()) {
		result.blocked_reason = "0x4ad7f7_ordered_relation_vector_empty_before_0x4aa9b7";
	}
	return result;
}

bool generated_cell_index_valid(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	return flat >= 0
			&& flat < int64_t(word_0x28.size())
			&& flat < int64_t(word_0x24.size());
}

bool generated_cell_49a1d8_valid_record(const GeneratedCellRecord0x30 &record) {
	if (!record.word_0x28_known || (record.word_0x28 & CELL_DECOR_READY_BIT_25) == 0U) {
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
		sync_generated_cell_byte_0x2b_from_word28(record);
		return !was_set;
	}
	record.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
	sync_generated_cell_byte_0x2b_from_word28(record);
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
		sync_generated_cell_byte_0x2b_from_word28(record);
		return !was_set;
	}
	record.word_0x28 &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
	sync_generated_cell_byte_0x2b_from_word28(record);
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
	sync_generated_cell_byte_0x2b_from_word28(record);
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
	record.word_0x28 &= ~CELL_DECOR_READY_BIT_25;
	sync_generated_cell_byte_0x2b_from_word28(record);
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
	sync_generated_cell_byte_0x2b_from_word28(record);
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

static uint8_t generated_cell_word20_owner_byte3(uint32_t word_0x20) {
	return uint8_t((word_0x20 >> 24U) & 0xffU);
}

static int32_t generated_cell_word20_owner_byte2_signed(uint32_t word_0x20) {
	return int32_t(int8_t((word_0x20 >> 16U) & 0xffU));
}

static int32_t generated_cell_word20_owner_byte3_signed(uint32_t word_0x20) {
	return int32_t(int8_t((word_0x20 >> 24U) & 0xffU));
}

RewardGuardProjectionDriverSelectionResult4ad947 reward_guard_projection_driver_select_global_entry_0x4ad947(const std::vector<RewardGuardProjectionGlobalEntry4ad947> &global_entries_0x57c7cc_plus_0x0c, const std::vector<uint8_t> &used_flags_0x1024, H3MapedRng &rng) {
	RewardGuardProjectionDriverSelectionResult4ad947 result;
	if (int32_t(global_entries_0x57c7cc_plus_0x0c.size()) < REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947) {
		result.blocked_reason = "0x4ad947_projection_global_table_0x57c7cc_plus_0x0c_missing_or_short";
		return result;
	}
	result.global_table_known = true;
	if (int32_t(used_flags_0x1024.size()) < REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947) {
		result.blocked_reason = "0x4ad947_generator_used_flag_array_0x1024_missing_or_short";
		return result;
	}
	result.used_flags_0x1024_known = true;
	for (int32_t index = 0; index < REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947; ++index) {
		const RewardGuardProjectionGlobalEntry4ad947 &entry = global_entries_0x57c7cc_plus_0x0c[size_t(index)];
		result.scanned_entry_count += 1;
		if (!entry.disabled_byte_0x10_known || !entry.flag_byte_0x00_known) {
			result.field_unknown_count += 1;
			continue;
		}
		if (entry.disabled_byte_0x10 != 0U) {
			result.disabled_reject_count += 1;
			continue;
		}
		if (used_flags_0x1024[size_t(index)] != 0U) {
			result.used_flag_reject_count += 1;
			continue;
		}
		if ((entry.flag_byte_0x00 & 0x02U) == 0U) {
			result.flag_bit_reject_count += 1;
			continue;
		}
		result.eligible_entry_indexes.push_back(index);
	}
	if (result.field_unknown_count != 0) {
		result.blocked_reason = "0x4ad947_projection_global_table_entry_fields_missing";
		return result;
	}
	result.eligible_count = int32_t(result.eligible_entry_indexes.size());
	if (result.eligible_count < 0x14) {
		result.generator_0x10b4_written = true;
		result.generator_0x10b4_value = true;
	}
	if (result.eligible_count == 0) {
		result.blocked_reason = "0x4ad947_projection_global_table_no_eligible_entries";
		return result;
	}
	result.rng_value_0x4e7276 = rng.next();
	result.selected_eligible_ordinal = result.rng_value_0x4e7276 % result.eligible_count;
	if (result.selected_eligible_ordinal < 0) {
		result.selected_eligible_ordinal += result.eligible_count;
	}
	result.selected_global_entry_index = result.eligible_entry_indexes[size_t(result.selected_eligible_ordinal)];
	result.projection_record_selected_global_index_0x1c_written = true;
	result.applied = true;
	return result;
}

RewardGuardProjectionSourceRelationResult4ad947 reward_guard_projection_source_relation_from_coordinate_0x4ad947(const GeneratorObjectPrivateState &state, int32_t projection_x, int32_t projection_y, int32_t projection_level) {
	RewardGuardProjectionSourceRelationResult4ad947 result;
	result.projection_coordinate_known = true;
	result.projection_x = projection_x;
	result.projection_y = projection_y;
	result.projection_level = projection_level;
	if (!state.generated_cell_buffer_owned
			|| state.generated_cell_buffer.records.empty()
			|| state.width <= 0
			|| state.height <= 0
			|| state.level_count <= 0) {
		result.blocked_reason = "0x4ad947_generated_cell_buffer_or_dimensions_missing";
		return result;
	}
	result.generated_cell_grid_available = true;
	if (projection_x < 0 || projection_x >= state.width
			|| projection_y < 0 || projection_y >= state.height
			|| projection_level < 0 || projection_level >= state.level_count) {
		result.blocked_reason = "0x4ad947_projection_coordinate_out_of_bounds";
		return result;
	}
	const int64_t flat = cell_index(state.width, state.height, projection_x, projection_y, projection_level);
	result.projection_flat_index = flat;
	if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
		result.blocked_reason = "0x4ad947_projection_flat_index_out_of_generated_cell_buffer";
		return result;
	}
	const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
	if (!record.word_0x20_known) {
		result.blocked_reason = "0x4ad947_projection_cell_word_0x20_unknown";
		return result;
	}
	result.word_0x20_known = true;
	result.projection_word_0x20 = record.word_0x20;
	const int32_t source_owner_index = generated_cell_word20_owner_byte3_signed(record.word_0x20);
	result.source_owner_high_byte_signed = source_owner_index;
	result.source_owner_vector_index = source_owner_index;
	if (source_owner_index < 0) {
		result.blocked_reason = "0x4ad947_projection_cell_owner_high_byte_sentinel";
		return result;
	}
	if (source_owner_index >= int32_t(state.relation_owner_vectors_10e4_10e8.size())) {
		result.blocked_reason = "0x4ad947_projection_cell_owner_high_byte_out_of_relation_vector";
		return result;
	}
	const GeneratorRelationOwnerState4a218c &owner = state.relation_owner_vectors_10e4_10e8[size_t(source_owner_index)];
	result.source_relation_known = true;
	result.source_relation_runtime_zone_index = owner.runtime_zone_index;
	result.applied = true;
	return result;
}

static RewardGuardProjectionChainResult49c0a6 reward_guard_projection_chain_0x49c0a6_0x4ad947_0x4ad7f7(
		GeneratorObjectPrivateState &state,
		const RewardGuardProjectionObject540b14 *projection_object,
		const std::vector<RewardGuardProjectionGlobalEntry4ad947> *global_entries_0x57c7cc_plus_0x0c,
		H3MapedRng &rng) {
	RewardGuardProjectionChainResult49c0a6 result;
	result.invoked = true;

	if (projection_object == nullptr || !projection_object->live_input_known) {
		result.blocked_reason = "0x49c0a6_projection_object_0x540b14_live_input_pending_before_0x4ad947";
		return result;
	}
	result.projection_object_input_known = true;
	if (!projection_object->vtable_0x00_known) {
		result.blocked_reason = "0x49c0a6_projection_object_vtable_0x540b14_pending_before_0x4ad947";
		return result;
	}
	if (projection_object->vtable_0x00 != PROJECTION_OBJECT_VTABLE_0X540B14) {
		result.blocked_reason = "0x49c0a6_projection_object_vtable_not_0x540b14";
		return result;
	}
	result.projection_vtable_0x540b14_confirmed = true;
	if (!projection_object->generator_context_plus_0x1c_known) {
		result.blocked_reason = "0x49c0a6_projection_object_generator_context_plus_0x1c_pending_before_0x4ad947";
		return result;
	}
	result.projection_context_plus_0x1c_forwarded_to_0x4ad947 = true;

	if (global_entries_0x57c7cc_plus_0x0c == nullptr) {
		result.blocked_reason = "0x4ad947_projection_global_table_0x57c7cc_plus_0x0c_live_input_pending_before_selected_global_entry";
		return result;
	}
	result.projection_driver_invoked_0x4ad947 = true;
	result.projection_driver_0x4ad947 =
			reward_guard_projection_driver_select_global_entry_0x4ad947(
					*global_entries_0x57c7cc_plus_0x0c,
					state.reward_guard_projection_used_flags_0x1024,
					rng);
	state.reward_guard_projection_driver_selection_0x4ad947 = result.projection_driver_0x4ad947;
	state.reward_guard_projection_driver_selection_input_known =
			result.projection_driver_0x4ad947.global_table_known
			&& result.projection_driver_0x4ad947.used_flags_0x1024_known;
	if (result.projection_driver_0x4ad947.generator_0x10b4_written) {
		state.reward_guard_projection_generator_0x10b4_known = true;
		state.reward_guard_projection_generator_0x10b4 =
				result.projection_driver_0x4ad947.generator_0x10b4_value;
	}
	if (!result.projection_driver_0x4ad947.applied) {
		result.blocked_reason = result.projection_driver_0x4ad947.blocked_reason.empty()
				? "0x4ad947_projection_driver_selected_global_entry_failed"
				: result.projection_driver_0x4ad947.blocked_reason;
		return result;
	}

	if (!projection_object->projection_coordinate_known) {
		result.blocked_reason = "0x4ad947_projection_object_coordinate_triple_live_input_pending_before_0x4ad7f7";
		return result;
	}
	result.source_relation_lookup_invoked_0x4ad947 = true;
	result.source_relation_0x4ad947 =
			reward_guard_projection_source_relation_from_coordinate_0x4ad947(
					state,
					projection_object->projection_x,
					projection_object->projection_y,
					projection_object->projection_level);
	state.reward_guard_projection_source_relation_0x4ad947 = result.source_relation_0x4ad947;
	state.reward_guard_projection_source_relation_input_known = true;
	if (!result.source_relation_0x4ad947.applied) {
		result.blocked_reason = result.source_relation_0x4ad947.blocked_reason.empty()
				? "0x4ad947_projection_source_relation_lookup_failed"
				: result.source_relation_0x4ad947.blocked_reason;
		return result;
	}

	result.relation_priority_invoked_0x4ad7f7 = true;
	result.relation_priority_0x4ad7f7 =
			reward_guard_relation_priority_ordering_0x4ad7f7(
					state.relation_owner_vectors_10e4_10e8,
					result.source_relation_0x4ad947.source_owner_vector_index,
					rng,
					false);
	state.reward_guard_relation_priority_0x4ad7f7 = result.relation_priority_0x4ad7f7;
	if (!result.relation_priority_0x4ad7f7.ordered_vector_ready_for_0x4aa9b7) {
		result.blocked_reason = result.relation_priority_0x4ad7f7.blocked_reason.empty()
				? "0x4ad7f7_ordered_relation_vector_not_ready_for_0x4aa9b7"
				: result.relation_priority_0x4ad7f7.blocked_reason;
		return result;
	}

	if (projection_object->cleanup_pointer_plus_0x20_known) {
		result.projection_cleanup_plus_0x20_cleared = true;
	}
	result.blocked_reason = "0x4ad7f7_wrapper_and_selected_member_inputs_pending_before_0x4aa9b7";
	return result;
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
		sync_generated_cell_byte_0x2b_from_word28(record);
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
					if (!nearby.word_0x28_known || (nearby.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
						result.cleanup_bit_0x04_clear_count += 1;
					}
					if (nearby.word_0x28_known) {
						nearby.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
						sync_generated_cell_byte_0x2b_from_word28(nearby);
					}
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
			if (resolver.appended_source_pair_0xedc && !resolver_state.source_pairs_0xedc.empty()) {
				SourceObjectResolverSourcePair4af785 &source_pair = resolver_state.source_pairs_0xedc.back();
				source_pair.source_order_relation_context_known = true;
				source_pair.source_order_relation_owner_byte2 = generated_cell_word20_owner_byte2(record.word_0x20);
				source_pair.source_order_source_pair_key_0x0c_known = true;
				source_pair.source_order_source_pair_key_0x0c = low_nibble_source;
				source_pair.source_order_anchor_known = true;
				source_pair.source_order_anchor_x_0x10 = x;
				source_pair.source_order_anchor_y_0x14 = y;
				source_pair.source_order_anchor_level_0x18 = level;
				const int32_t source_selector = source_pair.source_record_copy.type_id_0x1c;
				if (source_selector >= 0 && source_selector < int32_t(state.mapped_source_owner_slots_ee4.size())) {
					source_pair.source_order_lane_state_0xee4_known = true;
					source_pair.source_order_lane_state_0xee4 = state.mapped_source_owner_slots_ee4[size_t(source_selector)];
				}
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
					0,
					&selected_record);
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
			sync_generated_cell_byte_0x2b_from_word28(record);
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
			sync_generated_cell_byte_0x2b_from_word28(record);
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
					if (!nearby.word_0x28_known || (nearby.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
						result.cleanup_bit_0x04_clear_count += 1;
					}
					if (nearby.word_0x28_known) {
						nearby.word_0x28 &= ~CELL_DECOR_CANDIDATE_BIT_26;
						sync_generated_cell_byte_0x2b_from_word28(nearby);
					}
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

static bool generated_cell_append_object_reference_0x40bb26(GeneratedCellRecord0x30 &cell, uint32_t object_record_key) {
	if (!cell.object_reference_vector_contents_known) {
		return false;
	}
	cell.object_references_0x04_0x08.push_back(object_record_key);
	cell.object_reference_count = int32_t(cell.object_references_0x04_0x08.size());
	return true;
}

static void generated_grid_stamp_object_footprint_0x49abd6(
		GeneratorObjectPrivateState &state,
		ObjectFootprintCommitResult4a54a7 &result,
		uint32_t object_record_key,
		int32_t anchor_x,
		int32_t anchor_y,
		int32_t anchor_level,
		const SourceObjectRecord0x4c &source) {
	if (state.generated_cell_buffer.width <= 0
			|| state.generated_cell_buffer.height <= 0
			|| state.generated_cell_buffer.level_count <= 0
			|| state.generated_cell_buffer.records.empty()) {
		return;
	}
	const int32_t descriptor_width = source.descriptor_width_0x34;
	const int32_t descriptor_height = source.descriptor_height_0x38;
	for (int32_t row = 0; row < descriptor_height; ++row) {
		for (int32_t col = 0; col < descriptor_width; ++col) {
			const int64_t flat = cell_index(
					state.generated_cell_buffer.width,
					state.generated_cell_buffer.height,
					anchor_x - col,
					anchor_y - row,
					anchor_level);
			if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
				continue;
			}
			GeneratedCellRecord0x30 &cell = state.generated_cell_buffer.records[size_t(flat)];
			bool stamped = false;
			if (source_object_descriptor_mask_bit_0x4268eb(source, col, row)) {
				const uint8_t before_byte_0x2a = cell.byte_0x2a;
				const uint32_t before_word_0x28 = cell.word_0x28;
				cell.byte_0x2a_known = true;
				cell.byte_0x2a_known_mask |= 0x40U;
				cell.byte_0x2a |= 0x40U;
				cell.word_0x28_known = true;
				cell.word_0x28 |= CELL_ACTION_CONTROL_BIT_22;
				stamped = generated_cell_49a932(cell, true)
						|| before_byte_0x2a != cell.byte_0x2a
						|| before_word_0x28 != cell.word_0x28;
				if (generated_cell_append_object_reference_0x40bb26(cell, object_record_key)) {
					state.generated_cell_object_reference_append_count_0x4a54a7 += 1;
					result.generator_body_reference_append_count_0x49abd6 += 1;
					stamped = true;
				}
			} else if (!source_object_descriptor_mask_bit_0x41e951(source, col, row)) {
				stamped = generated_cell_49abd6_body_reject_stamp(cell);
				if (generated_cell_append_object_reference_0x40bb26(cell, object_record_key)) {
					state.generated_cell_object_reference_append_count_0x4a54a7 += 1;
					result.generator_body_reference_append_count_0x49abd6 += 1;
					stamped = true;
				}
			}
			if (stamped) {
				result.generator_body_stamp_count_0x49abd6 += 1;
			}
		}
	}
	result.generator_body_stamp_applied_0x49abd6 = result.generator_body_stamp_count_0x49abd6 > 0;
}

ObjectFootprintCommitResult4a54a7 object_footprint_commit_4a54a7(GeneratorObjectPrivateState &state, uint32_t object_record_key, int32_t descriptor_type_0x1c, int32_t x, int32_t y, int32_t level, bool descriptor_projection_enabled_0x29, int32_t descriptor_offset_x_0x2c, int32_t descriptor_offset_y_0x30, const SourceObjectRecord0x4c *source_record_copy_0x04) {
	ObjectFootprintCommitResult4a54a7 result;
	ObjectRecordReference4a54a7 object_record;
	object_record.object_record_key = object_record_key;
	object_record.descriptor_type_0x1c = descriptor_type_0x1c;
	object_record.x = x;
	object_record.y = y;
	object_record.level = level;

	const int64_t target_flat = cell_index(state.width, state.height, x, y, level);
	GeneratedCellRecord0x30 *target_record = nullptr;
	if (target_flat >= 0 && target_flat < int64_t(state.generated_cell_buffer.records.size())) {
		result.target_cell_in_bounds = true;
		target_record = &state.generated_cell_buffer.records[size_t(target_flat)];
		result.target_cell_words_known = target_record->word_0x20_known && target_record->word_0x28_known;
	}

	result.source_record_copy_present_0x04 = source_record_copy_0x04 != nullptr;
	if (source_record_copy_0x04 == nullptr) {
		return result;
	}
	generated_grid_stamp_object_footprint_0x49abd6(
			state,
			result,
			object_record_key,
			x,
			y,
			level,
			*source_record_copy_0x04);
	if (target_record != nullptr) {
		result.target_cell_reference_count_after = target_record->object_reference_count;
		result.generated_cell_reference_appended = result.generator_body_reference_append_count_0x49abd6 > 0;
	}

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
	GeneratedCellRecord0x30 &projection_record = state.generated_cell_buffer.records[size_t(projection_flat)];
	if (projection_record.word_0x20_known) {
		const uint32_t old_word_0x20 = projection_record.word_0x20;
		projection_record.word_0x20 &= 0xffff0000U;
		if (projection_record.word_0x20 != old_word_0x20) {
			result.target_cell_word_mutation_count += 1;
			state.target_cell_word_mutation_count_0x4a54a7 += 1;
		}
	}
	const uint32_t target_word_0x20_before_projection =
			target_record != nullptr && target_record->word_0x20_known ? target_record->word_0x20 : 0U;
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
		const GeneratedCellRecord0x30 *updated_target_record =
				target_flat >= 0 && target_flat < int64_t(state.generated_cell_buffer.records.size())
				? &state.generated_cell_buffer.records[size_t(target_flat)]
				: nullptr;
		if (updated_target_record != nullptr
				&& updated_target_record->word_0x20_known
				&& updated_target_record->word_0x20 != target_word_0x20_before_projection) {
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
			descriptor.source_cell_y_0x30,
			prep.copied_source_record_carried ? &prep.source_record_copy : nullptr);
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

struct RecoveredRewardGuardCandidateSpec49f95a {
	uint32_t vtable_0x00 = 0U;
	int32_t descriptor_type_0x04 = -1;
	int32_t subtype_or_cursor_0x08 = 0;
	int32_t value_0x0c = 0;
	int32_t weight_0x10 = 0;
	bool direct_value_known = true;
	bool monster_score_fields_known = false;
	int32_t monster_table_index_0x14 = -1;
	int32_t monster_terrain_id_0x57cea0 = -1;
	int32_t monster_base_score_0x49c64b = 0;
};

static RewardGuardCandidateRecord4a9f1c reward_guard_candidate_record_49f95a(const RecoveredRewardGuardCandidateSpec49f95a &spec) {
	RewardGuardCandidateRecord4a9f1c record;
	record.candidate_vtable_0x00_known = true;
	record.candidate_vtable_0x00 = spec.vtable_0x00;
	record.descriptor_type_0x04_known = true;
	record.descriptor_type_0x04 = spec.descriptor_type_0x04;
	record.cursor_source_0x08_known = true;
	record.cursor_source_0x08 = spec.subtype_or_cursor_0x08;
	record.direct_value_0x0c_known = spec.direct_value_known;
	record.direct_value_0x0c = spec.value_0x0c;
	record.selection_weight_0x10_known = true;
	record.selection_weight_0x10 = spec.weight_0x10;
	record.monster_score_fields_known_0x49c64b = spec.monster_score_fields_known;
	record.monster_table_index_0x14 = spec.monster_table_index_0x14;
	record.monster_terrain_id_0x57cea0 = spec.monster_terrain_id_0x57cea0;
	record.monster_base_score_0x49c64b = spec.monster_base_score_0x49c64b;
	return record;
}

static void append_reward_guard_candidate_49f95a(std::vector<RewardGuardCandidateRecord4a9f1c> &records, const RecoveredRewardGuardCandidateSpec49f95a &spec) {
	records.push_back(reward_guard_candidate_record_49f95a(spec));
}

static void append_reward_guard_candidates_49f95a(std::vector<RewardGuardCandidateRecord4a9f1c> &records, const RecoveredRewardGuardCandidateSpec49f95a *begin, size_t count) {
	for (size_t index = 0; index < count; ++index) {
		append_reward_guard_candidate_49f95a(records, begin[index]);
	}
}

static void append_reward_guard_type10_candidates_49ff59(std::vector<RewardGuardCandidateRecord4a9f1c> &records) {
	static constexpr int32_t VALUES[] = { 5000, 7500, 10000, 15000, 20000 };
	for (int32_t subtype = 7; subtype >= 0; --subtype) {
		for (const int32_t value : VALUES) {
			append_reward_guard_candidate_49f95a(records, RecoveredRewardGuardCandidateSpec49f95a {
					0x540ca0U,
					10,
					subtype,
					value,
					10,
					true });
		}
	}
}

static void append_reward_guard_monster_candidates_49f9ed(std::vector<RewardGuardCandidateRecord4a9f1c> &records) {
	static constexpr int32_t MONSTER_TABLE_INDEXES_DESC_0X49F9ED[] = {
		117, 116, 115, 114, 113, 112, 111, 110, 109, 108,
		107, 106, 105, 104, 103, 102, 101, 100, 99, 98,
		97, 96, 95, 94, 93, 92, 91, 90, 89, 88,
		87, 86, 85, 84, 83, 82, 81, 80, 79, 78,
		77, 76, 75, 74, 73, 72, 71, 70, 69, 68,
		67, 66, 65, 64, 63, 62, 61, 60, 59, 58,
		57, 56, 55, 54, 53, 52, 51, 50, 49, 48,
		47, 46, 45, 44, 43, 42, 41, 40, 39, 38,
		37, 36, 35, 34, 33, 32, 31, 30, 29, 28,
		27, 26, 25, 24, 23, 22, 21, 20, 19, 18,
		17, 16, 15, 14, 13, 12, 11, 10, 9, 8,
		7, 6, 5, 4, 3, 2, 1, 0
	};
	static constexpr int32_t MONSTER_TERRAIN_IDS_DESC_0X49F9ED[] = {
		-1, -1, 8, 8, 8, 8, 7, 7, 7, 7,
		7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
		6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
		6, 6, 6, 6, 5, 5, 5, 5, 5, 5,
		5, 5, 5, 5, 5, 5, 5, 5, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		4, 4, 3, 3, 3, 3, 3, 3, 3, 3,
		3, 3, 3, 3, 3, 3, 2, 2, 2, 2,
		2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0
	};
	static constexpr int32_t MONSTER_VALUES_0X49F9ED[] = {
		19375, 15000, 9450, 12075, 16500, 7120, 23724, 24720, 22770, 20250,
		10710, 11040, 8960, 8960, 15420, 13350, 7020, 7560, 5400, 5040,
		24672, 25296, 21645, 18990, 16590, 15405, 10080, 12480, 8400, 8640,
		7105, 6500, 4680, 4800, 26163, 23510, 23835, 23205, 16020, 16700,
		11540, 12925, 9175, 8400, 7140, 6930, 5040, 4720, 23480, 27104,
		19056, 20870, 16185, 16960, 11745, 11100, 9450, 8820, 6400, 6860,
		5100, 4800, 21345, 25505, 22176, 20040, 18360, 15300, 12000, 11125,
		7840, 8925, 7200, 7155, 4800, 5000, 22500, 29744, 22720, 20160,
		14130, 17680, 10200, 11400, 8240, 8750, 7035, 6600, 5280, 4840,
		25839, 24360, 20300, 21672, 16060, 15510, 10640, 12950, 8275, 9360,
		7315, 6900, 4830, 5000, 26328, 25095, 21000, 19460, 15000, 14550,
		11760, 11125, 8960, 8775, 7360, 7560, 5175, 4800,
	};
	static_assert(sizeof(MONSTER_TABLE_INDEXES_DESC_0X49F9ED) == sizeof(MONSTER_VALUES_0X49F9ED), "monster table index list must match value list");
	static_assert(sizeof(MONSTER_TERRAIN_IDS_DESC_0X49F9ED) == sizeof(MONSTER_VALUES_0X49F9ED), "monster terrain list must match value list");
	for (size_t index = 0; index < sizeof(MONSTER_VALUES_0X49F9ED) / sizeof(MONSTER_VALUES_0X49F9ED[0]); ++index) {
		const int32_t value = MONSTER_VALUES_0X49F9ED[index];
		append_reward_guard_candidate_49f95a(records, RecoveredRewardGuardCandidateSpec49f95a {
				0x540bc0U,
				6,
				0,
				0,
				3,
				false,
				true,
				MONSTER_TABLE_INDEXES_DESC_0X49F9ED[index],
				MONSTER_TERRAIN_IDS_DESC_0X49F9ED[index],
				value });
	}
}

static void append_reward_guard_type17_candidates_4a0402(std::vector<RewardGuardCandidateRecord4a9f1c> &records) {
	static constexpr int32_t TYPE17_MONSTER_TABLE_INDEX_0X531CC4[] = {
		106, 96, 74, 66, 68, 10, 14, 112, 12, 94,
		54, 104, 16, 113, 52, 18, 114, 30, 36, 86,
		98, 84, 44, 102, 26, 4, 72, 46, 110, 42,
		100, 34, 80, 76, 78, 8, 38, 48, 90, 88,
		50, 82, 92, 28, 40, 22, 70, 115, 60, 108,
		20, 24, 64, 62, 56, 58, 0, 2
	};
	static constexpr int32_t TYPE17_MONSTER_TERRAIN_IDS_0X531CC4[] = {
		7, 6, 5, 4, 4, 0, 1, 8, 0, 6,
		3, 7, 1, 8, 3, 1, 8, 2, 2, 6,
		7, 6, 3, 7, 1, 0, 5, 3, 7, 3,
		7, 2, 5, 5, 5, 0, 2, 3, 6, 6,
		3, 5, 6, 2, 2, 1, 5, 8, 4, 7,
		1, 1, 4, 4, 4, 4, 0, 0
	};
	static constexpr std::pair<int32_t, int32_t> TYPE17_CANDIDATES_0X4A0402[] = {
		{ 57, 1134 }, { 56, 1120 }, { 55, 784 }, { 54, 720 }, { 53, 2220 }, { 52, 2544 },
		{ 51, 3612 }, { 50, 2590 }, { 49, 2700 }, { 48, 1764 }, { 47, 1890 }, { 46, 826 },
		{ 45, 1551 }, { 44, 3718 }, { 43, 704 }, { 42, 3081 }, { 41, 4702 }, { 40, 2295 },
		{ 39, 1344 }, { 38, 1664 }, { 37, 1780 }, { 36, 4032 }, { 35, 1455 }, { 34, 2505 },
		{ 33, 2068 }, { 32, 3094 }, { 31, 2280 }, { 30, 1008 }, { 29, 750 }, { 28, 4120 },
		{ 27, 1785 }, { 26, 1232 }, { 25, 2457 }, { 24, 4872 }, { 23, 2670 }, { 22, 1272 },
		{ 21, 900 }, { 20, 672 }, { 19, 1170 }, { 18, 2652 }, { 17, 1485 }, { 16, 1725 },
		{ 15, 1638 }, { 14, 3340 }, { 13, 1320 }, { 12, 1104 }, { 11, 2048 }, { 10, 5101 },
		{ 9, 2532 }, { 8, 5019 }, { 7, 2136 }, { 6, 1400 }, { 5, 3892 }, { 4, 3388 },
		{ 3, 4174 }, { 2, 2352 }, { 1, 3162 }, { 0, 2208 },
	};
	static_assert(sizeof(TYPE17_MONSTER_TABLE_INDEX_0X531CC4) / sizeof(TYPE17_MONSTER_TABLE_INDEX_0X531CC4[0]) == 58, "type17 subtype table must cover 58 records");
	static_assert(sizeof(TYPE17_MONSTER_TERRAIN_IDS_0X531CC4) / sizeof(TYPE17_MONSTER_TERRAIN_IDS_0X531CC4[0]) == 58, "type17 terrain table must cover 58 records");
	for (const auto &candidate : TYPE17_CANDIDATES_0X4A0402) {
		const int32_t subtype = candidate.first;
		append_reward_guard_candidate_49f95a(records, RecoveredRewardGuardCandidateSpec49f95a {
				0x540c00U,
				17,
				subtype,
				0,
				40,
				false,
				true,
				TYPE17_MONSTER_TABLE_INDEX_0X531CC4[subtype],
				TYPE17_MONSTER_TERRAIN_IDS_0X531CC4[subtype],
				candidate.second });
	}
}

static void append_reward_guard_type53_candidates_4a0eeb(std::vector<RewardGuardCandidateRecord4a9f1c> &records) {
	static constexpr int32_t MONSTER_TABLE_INDEXES_DESC_0X49F9ED[] = {
		117, 116, 115, 114, 113, 112, 111, 110, 109, 108,
		107, 106, 105, 104, 103, 102, 101, 100, 99, 98,
		97, 96, 95, 94, 93, 92, 91, 90, 89, 88,
		87, 86, 85, 84, 83, 82, 81, 80, 79, 78,
		77, 76, 75, 74, 73, 72, 71, 70, 69, 68,
		67, 66, 65, 64, 63, 62, 61, 60, 59, 58,
		57, 56, 55, 54, 53, 52, 51, 50, 49, 48,
		47, 46, 45, 44, 43, 42, 41, 40, 39, 38,
		37, 36, 35, 34, 33, 32, 31, 30, 29, 28,
		27, 26, 25, 24, 23, 22, 21, 20, 19, 18,
		17, 16, 15, 14, 13, 12, 11, 10, 9, 8,
		7, 6, 5, 4, 3, 2, 1, 0
	};
	static constexpr int32_t MONSTER_TERRAIN_IDS_DESC_0X49F9ED[] = {
		-1, -1, 8, 8, 8, 8, 7, 7, 7, 7,
		7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
		6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
		6, 6, 6, 6, 5, 5, 5, 5, 5, 5,
		5, 5, 5, 5, 5, 5, 5, 5, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		4, 4, 3, 3, 3, 3, 3, 3, 3, 3,
		3, 3, 3, 3, 3, 3, 2, 2, 2, 2,
		2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0
	};
	static constexpr int32_t MONSTER_VALUES_0X49F9ED[] = {
		19375, 15000, 9450, 12075, 16500, 7120, 23724, 24720, 22770, 20250,
		10710, 11040, 8960, 8960, 15420, 13350, 7020, 7560, 5400, 5040,
		24672, 25296, 21645, 18990, 16590, 15405, 10080, 12480, 8400, 8640,
		7105, 6500, 4680, 4800, 26163, 23510, 23835, 23205, 16020, 16700,
		11540, 12925, 9175, 8400, 7140, 6930, 5040, 4720, 23480, 27104,
		19056, 20870, 16185, 16960, 11745, 11100, 9450, 8820, 6400, 6860,
		5100, 4800, 21345, 25505, 22176, 20040, 18360, 15300, 12000, 11125,
		7840, 8925, 7200, 7155, 4800, 5000, 22500, 29744, 22720, 20160,
		14130, 17680, 10200, 11400, 8240, 8750, 7035, 6600, 5280, 4840,
		25839, 24360, 20300, 21672, 16060, 15510, 10640, 12950, 8275, 9360,
		7315, 6900, 4830, 5000, 26328, 25095, 21000, 19460, 15000, 14550,
		11760, 11125, 8960, 8775, 7360, 7560, 5175, 4800,
	};
	static_assert(sizeof(MONSTER_TABLE_INDEXES_DESC_0X49F9ED) == sizeof(MONSTER_VALUES_0X49F9ED), "monster table index list must match type53 value list");
	static_assert(sizeof(MONSTER_TERRAIN_IDS_DESC_0X49F9ED) == sizeof(MONSTER_VALUES_0X49F9ED), "monster terrain list must match type53 value list");
	static constexpr RecoveredRewardGuardCandidateSpec49f95a FIXED_TYPE53_0X4A0EEB[] = {
		{ 0x540c70U, 83, 0, 2000, 10, true },
		{ 0x540c70U, 83, 0, 5333, 10, true },
		{ 0x540c70U, 83, 0, 8666, 10, true },
		{ 0x540c70U, 83, 0, 12000, 10, true },
		{ 0x540c80U, 83, 0, 2000, 10, true },
		{ 0x540c80U, 83, 0, 5333, 10, true },
		{ 0x540c80U, 83, 0, 8666, 10, true },
		{ 0x540c80U, 83, 0, 12000, 10, true },
	};
	for (int32_t subtype = 0; subtype <= 2; ++subtype) {
		for (size_t index = 0; index < sizeof(MONSTER_VALUES_0X49F9ED) / sizeof(MONSTER_VALUES_0X49F9ED[0]); ++index) {
			const int32_t value = MONSTER_VALUES_0X49F9ED[index];
			append_reward_guard_candidate_49f95a(records, RecoveredRewardGuardCandidateSpec49f95a {
					0x540c60U,
					83,
					subtype,
					0,
					3,
					false,
					true,
					MONSTER_TABLE_INDEXES_DESC_0X49F9ED[index],
					MONSTER_TERRAIN_IDS_DESC_0X49F9ED[index],
					value });
		}
		for (RecoveredRewardGuardCandidateSpec49f95a fixed : FIXED_TYPE53_0X4A0EEB) {
			fixed.subtype_or_cursor_0x08 = subtype;
			append_reward_guard_candidate_49f95a(records, fixed);
		}
	}
}

static std::vector<RewardGuardCandidateRecord4a9f1c> reward_guard_candidate_records_single_level_land_49f95a() {
	static constexpr RecoveredRewardGuardCandidateSpec49f95a STATIC_PREFIX_0X49F95A[] = {
		{ 0x540ba0U, 2, 0, 100, 20, true },
		{ 0x540ba0U, 4, 0, 3000, 50, true },
	};
	static constexpr RecoveredRewardGuardCandidateSpec49f95a STATIC_TYPE6_BANDS_0X49F95A[] = {
		{ 0x540bd0U, 6, 0, 6000, 20, true },
		{ 0x540bd0U, 6, 0, 12000, 20, true },
		{ 0x540bd0U, 6, 0, 18000, 20, true },
		{ 0x540bd0U, 6, 0, 24000, 20, true },
		{ 0x540be0U, 6, 0, 5000, 5, true },
		{ 0x540be0U, 6, 0, 10000, 5, true },
		{ 0x540be0U, 6, 0, 15000, 5, true },
		{ 0x540be0U, 6, 0, 20000, 5, true },
		{ 0x540bf0U, 6, 0, 5000, 2, true },
		{ 0x540bf0U, 6, 0, 7500, 2, true },
		{ 0x540bf0U, 6, 0, 10000, 2, true },
		{ 0x540bf0U, 6, 0, 12500, 2, true },
		{ 0x540bf0U, 6, 0, 15000, 2, true },
		{ 0x540bf0U, 6, 0, 15000, 2, true },
		{ 0x540bf0U, 6, 0, 15000, 2, true },
		{ 0x540bf0U, 6, 0, 15000, 2, true },
		{ 0x540bf0U, 6, 0, 15000, 2, true },
		{ 0x540bf0U, 6, 0, 30000, 2, true },
	};
	static constexpr RecoveredRewardGuardCandidateSpec49f95a STATIC_AFTER_TYPE10_BEFORE_TYPE17_0X49F95A[] = {
		{ 0x540ba0U, 7, 0, 8000, 20, true },
		{ 0x540ba0U, 11, 0, 100, 100, true },
		{ 0x540ba0U, 12, 0, 2000, 500, true },
		{ 0x540ba0U, 13, 0, 5000, 20, true },
		{ 0x540ba0U, 13, 1, 10000, 20, true },
		{ 0x540ba0U, 13, 2, 7500, 20, true },
		{ 0x540ba0U, 14, 0, 100, 100, true },
		{ 0x540ba0U, 16, 0, 3000, 100, true },
		{ 0x540ba0U, 16, 1, 2000, 100, true },
		{ 0x540ba0U, 16, 2, 2000, 100, true },
		{ 0x540ba0U, 16, 3, 5000, 100, true },
		{ 0x540ba0U, 16, 4, 1500, 100, true },
		{ 0x540ba0U, 16, 5, 3000, 100, true },
		{ 0x540ba0U, 16, 6, 9000, 100, true },
	};
	static constexpr RecoveredRewardGuardCandidateSpec49f95a STATIC_AFTER_TYPE17_BEFORE_TYPE53_0X49F95A[] = {
		{ 0x540ba0U, 22, 0, 500, 100, true },
		{ 0x540ba0U, 23, 0, 1500, 100, true },
		{ 0x540ba0U, 24, 0, 4000, 20, true },
		{ 0x540ba0U, 25, 0, 10000, 100, true },
		{ 0x540ba0U, 28, 0, 100, 100, true },
		{ 0x540ba0U, 29, 0, 500, 1000, true },
		{ 0x540ba0U, 30, 0, 100, 100, true },
		{ 0x540ba0U, 31, 0, 100, 50, true },
		{ 0x540ba0U, 32, 0, 1500, 100, true },
		{ 0x540ba0U, 35, 0, 7000, 20, true },
		{ 0x540ba0U, 38, 0, 100, 100, true },
		{ 0x540ba0U, 39, 0, 500, 100, true },
		{ 0x540ba0U, 41, 0, 12000, 20, true },
		{ 0x540ba0U, 47, 0, 1000, 50, true },
		{ 0x540ba0U, 48, 0, 500, 50, true },
		{ 0x540ba0U, 49, 0, 250, 100, true },
		{ 0x540ba0U, 51, 0, 1500, 100, true },
		{ 0x540ba0U, 52, 0, 100, 100, true },
		{ 0x540ba0U, 55, 0, 500, 50, true },
		{ 0x540ba0U, 56, 0, 100, 50, true },
		{ 0x540ba0U, 57, 0, 3500, 200, true },
		{ 0x540ba0U, 58, 0, 750, 100, true },
		{ 0x540ba0U, 60, 0, 750, 100, true },
		{ 0x540ba0U, 61, 0, 1500, 100, true },
		{ 0x540c20U, 62, 0, 2500, 30, true },
		{ 0x540c20U, 62, 0, 5000, 30, true },
		{ 0x540c20U, 62, 0, 10000, 30, true },
		{ 0x540c20U, 62, 0, 20000, 30, true },
		{ 0x540c20U, 62, 0, 30000, 30, true },
		{ 0x540ba0U, 63, 0, 5000, 20, true },
		{ 0x540ba0U, 64, 0, 100, 100, true },
		{ 0x540bb0U, 66, 0, 2000, 150, true },
		{ 0x540bb0U, 67, 0, 5000, 150, true },
		{ 0x540bb0U, 68, 0, 10000, 150, true },
		{ 0x540bb0U, 69, 0, 20000, 150, true },
		{ 0x540c10U, 76, 0, 1500, 2000, true },
		{ 0x540ba0U, 78, 0, 5000, 20, true },
		{ 0x540c10U, 79, 0, 1400, 300, true },
		{ 0x540c10U, 79, 2, 1400, 300, true },
		{ 0x540c10U, 79, 1, 2000, 300, true },
		{ 0x540c10U, 79, 3, 2000, 300, true },
		{ 0x540c10U, 79, 4, 2000, 300, true },
		{ 0x540c10U, 79, 5, 2000, 300, true },
		{ 0x540c10U, 79, 6, 750, 300, true },
		{ 0x540ba0U, 80, 0, 100, 50, true },
		{ 0x540c30U, 81, 0, 1500, 100, true },
		{ 0x540ba0U, 82, 0, 1500, 500, true },
	};
	static constexpr RecoveredRewardGuardCandidateSpec49f95a STATIC_FINAL_TAIL_0X49F95A[] = {
		{ 0x540ba0U, 84, 0, 1000, 100, true },
		{ 0x540ba0U, 85, 0, 2000, 100, true },
		{ 0x540ba0U, 86, 0, 1500, 50, true },
		{ 0x540c40U, 88, 0, 500, 100, true },
		{ 0x540c40U, 89, 0, 2000, 100, true },
		{ 0x540c40U, 90, 0, 3000, 100, true },
		{ 0x540ba0U, 92, 0, 100, 20, true },
		{ 0x540c90U, 93, 0, 500, 30, true },
		{ 0x540c90U, 93, 0, 2000, 30, true },
		{ 0x540c90U, 93, 0, 3000, 30, true },
		{ 0x540c90U, 93, 0, 4000, 30, true },
		{ 0x540c90U, 93, 0, 5000, 30, true },
		{ 0x540ba0U, 94, 0, 200, 40, true },
		{ 0x540ba0U, 95, 0, 100, 20, true },
		{ 0x540ba0U, 96, 0, 100, 100, true },
		{ 0x540ba0U, 97, 0, 100, 100, true },
		{ 0x540ba0U, 99, 0, 100, 100, true },
		{ 0x540ba0U, 100, 0, 1500, 200, true },
		{ 0x540ba0U, 101, 0, 1500, 1000, true },
		{ 0x540ba0U, 102, 0, 2500, 50, true },
		{ 0x540ba0U, 104, 0, 2500, 20, true },
		{ 0x540ba0U, 105, 0, 500, 50, true },
		{ 0x540ba0U, 106, 0, 1500, 50, true },
		{ 0x540ba0U, 107, 0, 1000, 50, true },
		{ 0x540ba0U, 108, 0, 6000, 20, true },
		{ 0x540ba0U, 109, 0, 750, 50, true },
		{ 0x540ba0U, 110, 0, 500, 50, true },
		{ 0x540ba0U, 112, 0, 2500, 150, true },
		{ 0x540c50U, 113, 0, 1500, 80, true },
	};

	std::vector<RewardGuardCandidateRecord4a9f1c> records;
	records.reserve(704);
	append_reward_guard_candidates_49f95a(records, STATIC_PREFIX_0X49F95A, sizeof(STATIC_PREFIX_0X49F95A) / sizeof(STATIC_PREFIX_0X49F95A[0]));
	append_reward_guard_monster_candidates_49f9ed(records);
	append_reward_guard_candidates_49f95a(records, STATIC_TYPE6_BANDS_0X49F95A, sizeof(STATIC_TYPE6_BANDS_0X49F95A) / sizeof(STATIC_TYPE6_BANDS_0X49F95A[0]));
	append_reward_guard_type10_candidates_49ff59(records);
	append_reward_guard_candidates_49f95a(records, STATIC_AFTER_TYPE10_BEFORE_TYPE17_0X49F95A, sizeof(STATIC_AFTER_TYPE10_BEFORE_TYPE17_0X49F95A) / sizeof(STATIC_AFTER_TYPE10_BEFORE_TYPE17_0X49F95A[0]));
	append_reward_guard_type17_candidates_4a0402(records);
	append_reward_guard_candidates_49f95a(records, STATIC_AFTER_TYPE17_BEFORE_TYPE53_0X49F95A, sizeof(STATIC_AFTER_TYPE17_BEFORE_TYPE53_0X49F95A) / sizeof(STATIC_AFTER_TYPE17_BEFORE_TYPE53_0X49F95A[0]));
	append_reward_guard_type53_candidates_4a0eeb(records);
	append_reward_guard_candidates_49f95a(records, STATIC_FINAL_TAIL_0X49F95A, sizeof(STATIC_FINAL_TAIL_0X49F95A) / sizeof(STATIC_FINAL_TAIL_0X49F95A[0]));
	return records;
}

int32_t reward_guard_global_type_limit_0x5a26e4(int32_t descriptor_type) {
	static constexpr std::pair<int32_t, int32_t> OVERRIDES[] = {
		{ 26, 200 }, { 6, 200 }, { 57, 48 }, { 8, 64 }, { 100, 32 }, { 23, 32 },
		{ 32, 32 }, { 51, 32 }, { 61, 32 }, { 102, 32 }, { 41, 32 }, { 4, 32 },
		{ 47, 32 }, { 107, 32 }, { 104, 32 }, { 113, 32 }, { 88, 32 }, { 89, 32 },
		{ 90, 32 }, { 92, 32 }, { 55, 32 }, { 109, 32 }, { 112, 32 }, { 48, 32 },
		{ 22, 32 }, { 39, 32 }, { 108, 32 }, { 105, 32 }, { 83, 48 }, { 7, 32 },
	};
	for (const auto &entry : OVERRIDES) {
		if (entry.first == descriptor_type) {
			return entry.second;
		}
	}
	return REWARD_GUARD_DESCRIPTOR_TYPE_LIMIT_DEFAULT_0X7D00;
}

int32_t reward_guard_relation_type_limit_0x5a2a8c(int32_t descriptor_type) {
	static constexpr std::pair<int32_t, int32_t> OVERRIDES[] = {
		{ 2, 1 }, { 13, 1 }, { 14, 1 }, { 15, 1 }, { 27, 1 }, { 28, 1 },
		{ 30, 1 }, { 31, 1 }, { 35, 1 }, { 38, 1 }, { 42, 1 }, { 48, 1 },
		{ 49, 1 }, { 56, 1 }, { 58, 1 }, { 60, 1 }, { 64, 1 }, { 80, 1 },
		{ 94, 1 }, { 96, 1 }, { 99, 1 }, { 106, 1 }, { 110, 1 }, { 113, 3 },
	};
	for (const auto &entry : OVERRIDES) {
		if (entry.first == descriptor_type) {
			return entry.second;
		}
	}
	return REWARD_GUARD_DESCRIPTOR_TYPE_LIMIT_DEFAULT_0X7D00;
}

RewardGuardSelectorResult4a9f1c reward_guard_value_bounded_selector_counter_pass_0x4a9f1c(const GeneratorObjectPrivateState &state, const GeneratorRelationOwnerState4a218c *selector, int32_t lower_value_bound, int32_t upper_value_bound) {
	RewardGuardSelectorResult4a9f1c result;
	result.applied = true;
	result.candidate_vector_present = state.reward_guard_candidate_vector_10f4_10f8.present;
	result.candidate_vector_contents_known = state.reward_guard_candidate_records_10f4_10f8_contents_known;
	if (!state.reward_guard_candidate_vector_10f4_10f8.present || !state.reward_guard_candidate_records_10f4_10f8_contents_known) {
		result.blocked_reason = "reward_guard_candidate_vector_0x10f4_0x10f8_live_contents_pending_before_0x4a9f1c";
		return result;
	}
	if (!state.descriptor_counter_table_0x1110_present
			|| !state.descriptor_counter_table_0x1110_contents_known
			|| state.descriptor_counter_table_0x1110.size() != size_t(DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT)) {
		result.counter_input_missing_count += 1;
		result.blocked_reason = "descriptor_counter_table_0x1110_unavailable_for_0x4a9f1c_limit_check";
		return result;
	}
	if (selector == nullptr || !selector->descriptor_type_counter_table_0x44_known
			|| selector->descriptor_type_counters_0x44.size() != size_t(RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT)) {
		result.counter_input_missing_count += 1;
		result.blocked_reason = "selector_relation_counter_table_0x44_unavailable_for_0x4a9f1c_limit_check";
		return result;
	}

	result.candidate_scan_count = int32_t(state.reward_guard_candidate_records_10f4_10f8.size());
	result.candidate_decisions.reserve(state.reward_guard_candidate_records_10f4_10f8.size());
	for (const RewardGuardCandidateRecord4a9f1c &candidate : state.reward_guard_candidate_records_10f4_10f8) {
		RewardGuardCandidateDecision4a9f1c decision;
		decision.candidate_vtable_0x00_known = candidate.candidate_vtable_0x00_known;
		decision.candidate_vtable_0x00 = candidate.candidate_vtable_0x00;
		decision.descriptor_type_known = candidate.descriptor_type_0x04_known;
		decision.descriptor_type_0x04 = candidate.descriptor_type_0x04;
		decision.selection_weight_0x10_known = candidate.selection_weight_0x10_known;
		decision.selection_weight_0x10 = candidate.selection_weight_0x10;
		if (!candidate.descriptor_type_0x04_known
				|| candidate.descriptor_type_0x04 < 0
				|| candidate.descriptor_type_0x04 >= DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT
				|| candidate.descriptor_type_0x04 >= RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT) {
			result.descriptor_type_missing_count += 1;
			decision.blocked_reason = "candidate_descriptor_type_0x04_missing_or_out_of_range";
			result.candidate_decisions.push_back(decision);
			continue;
		}

		const size_t descriptor_type_index = size_t(candidate.descriptor_type_0x04);
		decision.global_counter_0x1110 = int32_t(state.descriptor_counter_table_0x1110[descriptor_type_index]);
		decision.global_limit_0x5a26e4 = reward_guard_global_type_limit_0x5a26e4(candidate.descriptor_type_0x04);
		decision.relation_counter_0x44 = int32_t(selector->descriptor_type_counters_0x44[descriptor_type_index]);
		decision.relation_limit_0x5a2a8c = reward_guard_relation_type_limit_0x5a2a8c(candidate.descriptor_type_0x04);

		if (decision.global_counter_0x1110 >= decision.global_limit_0x5a26e4) {
			decision.rejected_by_global_limit_0x5a26e4 = true;
			result.global_limit_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (decision.relation_counter_0x44 >= decision.relation_limit_0x5a2a8c) {
			decision.rejected_by_relation_limit_0x5a2a8c = true;
			result.relation_limit_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (candidate.direct_value_0x0c_known
				&& (candidate.direct_value_0x0c < lower_value_bound || candidate.direct_value_0x0c > upper_value_bound)) {
			decision.rejected_by_value_bounds = true;
			result.value_bound_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}

		decision.accepted_after_counter_and_value_checks = true;
		result.accepted_count += 1;
		result.candidate_decisions.push_back(decision);
	}
	if (result.accepted_count > 0) {
		result.blocked_reason = "0x4a9f1c_counter_pass_only_0x4a9e40_descriptor_selection_and_selected_object_vtable_allocation_not_invoked";
	}
	return result;
}

static bool reward_guard_candidate_vtable_returns_0x540b14(uint32_t candidate_vtable) {
	return candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_A_0X540C60
			|| candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_B_0X540C70
			|| candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_C_0X540C80;
}

static bool reward_guard_candidate_vtable_returned_object_vtable_0x4aa166(uint32_t candidate_vtable, uint32_t &object_vtable) {
	switch (candidate_vtable) {
		case 0x00540ba0U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540A74;
			return true;
		case 0x00540bb0U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540AC4;
			return true;
		case 0x00540bc0U:
		case 0x00540bd0U:
		case 0x00540be0U:
		case 0x00540bf0U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540AEC;
			return true;
		case 0x00540c00U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540AB0;
			return true;
		case 0x00540c10U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540AD8;
			return true;
		case 0x00540c20U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540B3C;
			return true;
		case 0x00540c30U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540B50;
			return true;
		case 0x00540c40U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540B64;
			return true;
		case 0x00540c50U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540B8C;
			return true;
		case REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_A_0X540C60:
		case REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_B_0X540C70:
		case REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_C_0X540C80:
			object_vtable = PROJECTION_OBJECT_VTABLE_0X540B14;
			return true;
		case 0x00540c90U:
			object_vtable = OBJECT_RECORD_VTABLE_0X540B78;
			return true;
		case REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_ADJACENT_0X540CA0:
			object_vtable = PROJECTION_OBJECT_VTABLE_0X540B00;
			return true;
		default:
			return false;
	}
}

static int32_t reward_guard_attach_value_from_band_0x4a65a5(int32_t selected_value, int32_t effective_band) {
	static constexpr std::array<int32_t, 6> first_thresholds_0x58db18 = { 50000, 2500, 1500, 1000, 500, 0 };
	static constexpr std::array<int32_t, 6> second_thresholds_0x58db30 = { 50000, 7500, 7500, 7500, 5000, 5000 };
	static constexpr std::array<int32_t, 6> first_multipliers_0x58db48 = { 0, 2, 3, 4, 6, 6 };
	static constexpr std::array<int32_t, 6> second_multipliers_0x58db60 = { 0, 2, 3, 4, 4, 6 };
	const int32_t band = std::min<int32_t>(5, std::max<int32_t>(0, effective_band));
	int32_t scaled_value = 0;
	if (selected_value > first_thresholds_0x58db18[size_t(band)]) {
		scaled_value += ((selected_value - first_thresholds_0x58db18[size_t(band)]) * first_multipliers_0x58db48[size_t(band)]) / 4;
	}
	if (selected_value > second_thresholds_0x58db30[size_t(band)]) {
		scaled_value += ((selected_value - second_thresholds_0x58db30[size_t(band)]) * second_multipliers_0x58db60[size_t(band)]) / 4;
	}
	return scaled_value < 0x7d0 ? 0 : scaled_value;
}

static RewardGuardAttachValueGateResult4a960a reward_guard_attach_value_gate_0x4a960a(const GeneratorObjectPrivateState &state, const GeneratorRelationOwnerState4a218c *selector, int32_t selected_value) {
	RewardGuardAttachValueGateResult4a960a result;
	result.invoked = true;
	result.selected_value_input = selected_value;
	result.generator_value_band_0x10bc_known = state.generator_value_band_0x10bc_known;
	result.generator_value_band_0x10bc = state.generator_value_band_0x10bc;
	if (!state.generator_value_band_0x10bc_known) {
		result.blocked_reason = "0x4a960a_generator_value_band_0x10bc_missing_from_0x49ecf2_setup_plus_0x48";
		return result;
	}
	if (selector == nullptr || !selector->source_pointer_value_0x90_known) {
		result.blocked_reason = "0x4a960a_selector_context_source_value_0x90_missing";
		return result;
	}
	result.selector_source_value_0x90_known = true;
	result.selector_source_value_0x90 = selector->source_pointer_value_0x90;
	result.effective_value_band_0x4a960a =
			std::min<int32_t>(5, std::max<int32_t>(0, selector->source_pointer_value_0x90 + state.generator_value_band_0x10bc - 3));
	result.scaled_attach_value_0x4a65a5 =
			reward_guard_attach_value_from_band_0x4a65a5(selected_value, result.effective_value_band_0x4a960a);
	result.applied = true;
	return result;
}

static bool reward_guard_candidate_vtable_has_direct_value_score(uint32_t candidate_vtable) {
	switch (candidate_vtable) {
		case 0x00540ba0U:
		case 0x00540bb0U:
		case 0x00540bd0U:
		case 0x00540be0U:
		case 0x00540bf0U:
		case 0x00540c10U:
		case 0x00540c20U:
		case 0x00540c30U:
		case 0x00540c40U:
		case 0x00540c50U:
		case 0x00540c90U:
			return true;
		default:
			return false;
	}
}

static bool reward_guard_candidate_monster_score_0x49c64b(
		const GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c *selector,
		const RewardGuardCandidateRecord4a9f1c &candidate,
		int32_t &score,
		std::string &blocked_reason) {
	if (selector == nullptr || !selector->terrain_policy_0x0c_known) {
		blocked_reason = "0x49c64b_selector_relation_terrain_0x08_missing";
		return false;
	}
	if (!candidate.monster_score_fields_known_0x49c64b) {
		blocked_reason = "0x49c64b_monster_candidate_fields_0x14_terrain_base_missing";
		return false;
	}
	if (candidate.monster_terrain_id_0x57cea0 != selector->terrain_policy_0x0c) {
		score = -1;
		return true;
	}
	if (!state.reward_guard_terrain_pressure_0xf60_0xf64_known) {
		blocked_reason = "0x49c64b_generator_0xf60_0xf64_terrain_pressure_state_missing";
		return false;
	}
	score = candidate.monster_base_score_0x49c64b;
	if (state.reward_guard_terrain_pressure_total_0xf60 > 0) {
		const int32_t terrain_id = selector->terrain_policy_0x0c;
		if (terrain_id < 0 || terrain_id >= int32_t(state.reward_guard_terrain_pressure_by_terrain_0xf64.size())) {
			blocked_reason = "0x49c64b_selector_relation_terrain_0x08_out_of_pressure_table_range";
			return false;
		}
		score += int32_t((int64_t(state.reward_guard_terrain_pressure_by_terrain_0xf64[size_t(terrain_id)]) * int64_t(score)) / int64_t(state.reward_guard_terrain_pressure_total_0xf60));
	}
	return true;
}

static bool reward_guard_candidate_score_0x4aa151(
		const GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c *selector,
		const RewardGuardCandidateRecord4a9f1c &candidate,
		int32_t &score,
		std::string &blocked_reason) {
	if (!candidate.candidate_vtable_0x00_known) {
		blocked_reason = "0x4a9f1c_candidate_vtable_0x00_missing_before_score_dispatch";
		return false;
	}

	const uint32_t candidate_vtable = candidate.candidate_vtable_0x00;
	if (reward_guard_candidate_vtable_has_direct_value_score(candidate_vtable)) {
		if (!candidate.direct_value_0x0c_known) {
			blocked_reason = "0x4a9f1c_candidate_direct_value_0x0c_missing_before_score_dispatch";
			return false;
		}
		score = candidate.direct_value_0x0c;
		return true;
	}

	if (candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_B_0X540C70
			|| candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_C_0X540C80) {
		if (!candidate.direct_value_0x0c_known) {
			blocked_reason = "0x49cb60_candidate_direct_value_0x0c_missing";
			return false;
		}
		if (!candidate.cursor_source_0x08_known) {
			blocked_reason = "0x49cb60_projection_candidate_cursor_0x08_missing";
			return false;
		}
		if (!state.endpoint_cursor_0xf58_known || !state.reward_guard_projection_generator_0x10b4_known) {
			blocked_reason = "0x49cb60_generator_0xf58_or_0x10b4_pending_before_projection_candidate_score";
			return false;
		}
		if (state.reward_guard_projection_generator_0x10b4 || state.endpoint_cursor_0xf58 != candidate.cursor_source_0x08) {
			score = -1;
			return true;
		}
		score = candidate.direct_value_0x0c;
		return true;
	}

	if (candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_A_0X540C60) {
		if (!candidate.cursor_source_0x08_known) {
			blocked_reason = "0x49ca8b_projection_candidate_cursor_0x08_missing";
			return false;
		}
		if (!state.endpoint_cursor_0xf58_known || !state.reward_guard_projection_generator_0x10b4_known) {
			blocked_reason = "0x49ca8b_generator_0xf58_or_0x10b4_pending_before_0x49c64b_score";
			return false;
		}
		if (state.reward_guard_projection_generator_0x10b4 || state.endpoint_cursor_0xf58 != candidate.cursor_source_0x08) {
			score = -1;
			return true;
		}
		int32_t monster_score = 0;
		if (!reward_guard_candidate_monster_score_0x49c64b(state, selector, candidate, monster_score, blocked_reason)) {
			return false;
		}
		score = ((2 * monster_score) - 4000) / 3;
		return true;
	}

	if (candidate_vtable == REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_ADJACENT_0X540CA0) {
		if (!candidate.direct_value_0x0c_known) {
			blocked_reason = "0x49cd97_candidate_direct_value_0x0c_missing";
			return false;
		}
		if (!candidate.cursor_source_0x08_known) {
			blocked_reason = "0x49cd97_projection_candidate_cursor_0x08_missing";
			return false;
		}
		if (!state.endpoint_cursor_0xf5c_known) {
			blocked_reason = "0x49cd97_generator_0xf5c_pending_before_adjacent_projection_candidate_score";
			return false;
		}
		if (state.endpoint_cursor_0xf5c != candidate.cursor_source_0x08) {
			score = -1;
			return true;
		}
		score = candidate.direct_value_0x0c;
		return true;
	}

	if (candidate_vtable == 0x00540bc0U) {
		return reward_guard_candidate_monster_score_0x49c64b(state, selector, candidate, score, blocked_reason);
	}
	if (candidate_vtable == 0x00540c00U) {
		return reward_guard_candidate_monster_score_0x49c64b(state, selector, candidate, score, blocked_reason);
	}

	blocked_reason = "0x4a9f1c_candidate_score_vtable_contract_unrecovered";
	return false;
}

static RewardGuardProjectionObject540b14 reward_guard_projection_object_from_selected_candidate_0x49cac2_0x49cb83_0x49cc22(
		const RewardGuardCandidateRecord4a9f1c &candidate) {
	RewardGuardProjectionObject540b14 object;
	object.live_input_known = true;
	object.vtable_0x00_known = true;
	object.vtable_0x00 = PROJECTION_OBJECT_VTABLE_0X540B14;
	object.generator_context_plus_0x1c_known = true;
	object.cleanup_pointer_plus_0x20_known = true;
	object.projection_coordinate_known = false;
	if (candidate.cursor_source_0x08_known) {
		object.projection_level = 0;
	}
	return object;
}

static int32_t reward_guard_descriptor_mask_extent_count_0x4aa195(const SourceObjectRecord0x4c &source) {
	const int32_t descriptor_width = source.descriptor_width_0x34 > 0 ? source.descriptor_width_0x34 : 0;
	const int32_t descriptor_height = source.descriptor_height_0x38 > 0 ? source.descriptor_height_0x38 : 0;
	int32_t count = 0;
	for (int32_t col = 0; col < descriptor_width; ++col) {
		for (int32_t row = 0; row < descriptor_height; ++row) {
			const bool secondary_mask = source_object_descriptor_mask_bit_0x41e951(source, col, row);
			if (!secondary_mask || source_object_descriptor_mask_bit_0x4268eb(source, col, row)) {
				count += 1;
			}
		}
	}
	return count;
}

RewardGuardSelectorResult4a9f1c reward_guard_selected_create_dispatch_0x4a9f1c(GeneratorObjectPrivateState &state, const GeneratorRelationOwnerState4a218c *selector, int32_t lower_value_bound, int32_t upper_value_bound, H3MapedRng &rng, const RewardGuardSelectorCallsiteArgs4a9f1c &callsite_args) {
	RewardGuardSelectorResult4a9f1c result;
	result.applied = true;
	result.callsite_args = callsite_args;
	result.candidate_vector_present = state.reward_guard_candidate_vector_10f4_10f8.present;
	result.candidate_vector_contents_known = state.reward_guard_candidate_records_10f4_10f8_contents_known;
	result.rng_state_after_0x4aa110 = rng.state;
	if (!state.reward_guard_candidate_vector_10f4_10f8.present || !state.reward_guard_candidate_records_10f4_10f8_contents_known) {
		result.blocked_reason = "reward_guard_candidate_vector_0x10f4_0x10f8_live_contents_pending_before_0x4a9f1c";
		return result;
	}
	if (!state.descriptor_counter_table_0x1110_present
			|| !state.descriptor_counter_table_0x1110_contents_known
			|| state.descriptor_counter_table_0x1110.size() != size_t(DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT)) {
		result.counter_input_missing_count += 1;
		result.blocked_reason = "descriptor_counter_table_0x1110_unavailable_for_0x4a9f1c_limit_check";
		return result;
	}
	if (selector == nullptr || !selector->descriptor_type_counter_table_0x44_known
			|| selector->descriptor_type_counters_0x44.size() != size_t(RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT)) {
		result.counter_input_missing_count += 1;
		result.blocked_reason = "selector_relation_counter_table_0x44_unavailable_for_0x4a9f1c_limit_check";
		return result;
	}

	std::vector<int32_t> accepted_candidate_indexes;
	if (callsite_args.coordinate_tuple_0x24_known && callsite_args.coordinate_tuple_0x24.x < 0) {
		result.coordinate_tuple_gate_0x24_skipped_negative = true;
	}
	result.candidate_scan_count = int32_t(state.reward_guard_candidate_records_10f4_10f8.size());
	result.candidate_decisions.reserve(state.reward_guard_candidate_records_10f4_10f8.size());
	for (int32_t candidate_index = 0; candidate_index < int32_t(state.reward_guard_candidate_records_10f4_10f8.size()); ++candidate_index) {
		const RewardGuardCandidateRecord4a9f1c &candidate = state.reward_guard_candidate_records_10f4_10f8[size_t(candidate_index)];
		RewardGuardCandidateDecision4a9f1c decision;
		decision.candidate_vtable_0x00_known = candidate.candidate_vtable_0x00_known;
		decision.candidate_vtable_0x00 = candidate.candidate_vtable_0x00;
		decision.descriptor_type_known = candidate.descriptor_type_0x04_known;
		decision.descriptor_type_0x04 = candidate.descriptor_type_0x04;
		decision.selection_weight_0x10_known = candidate.selection_weight_0x10_known;
		decision.selection_weight_0x10 = candidate.selection_weight_0x10;
		if (!candidate.descriptor_type_0x04_known
				|| candidate.descriptor_type_0x04 < 0
				|| candidate.descriptor_type_0x04 >= DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT
				|| candidate.descriptor_type_0x04 >= RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT) {
			result.descriptor_type_missing_count += 1;
			decision.blocked_reason = "candidate_descriptor_type_0x04_missing_or_out_of_range";
			result.candidate_decisions.push_back(decision);
			continue;
		}

		if (callsite_args.metadata_gate_byte_0x18 == 0U
				&& object_metadata_flag_0x598300(candidate.descriptor_type_0x04, 0)
				&& !object_metadata_flag_0x598300(candidate.descriptor_type_0x04, 2)) {
			decision.rejected_by_metadata_gate_0x18 = true;
			result.metadata_gate_reject_count_0x18 += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (callsite_args.precheck_byte_0x1c == 0U) {
			decision.rejected_by_score_dispatch = true;
			decision.blocked_reason = "0x4a9f1c_candidate_vtable_plus_0x08_precheck_unported_for_callsite_0x1c_zero";
			result.score_dispatch_missing_count += 1;
			result.blocked_reason = decision.blocked_reason;
			result.candidate_decisions.push_back(decision);
			return result;
		}

		const size_t descriptor_type_index = size_t(candidate.descriptor_type_0x04);
		decision.global_counter_0x1110 = int32_t(state.descriptor_counter_table_0x1110[descriptor_type_index]);
		decision.global_limit_0x5a26e4 = reward_guard_global_type_limit_0x5a26e4(candidate.descriptor_type_0x04);
		decision.relation_counter_0x44 = int32_t(selector->descriptor_type_counters_0x44[descriptor_type_index]);
		decision.relation_limit_0x5a2a8c = reward_guard_relation_type_limit_0x5a2a8c(candidate.descriptor_type_0x04);

		if (decision.global_counter_0x1110 >= decision.global_limit_0x5a26e4) {
			decision.rejected_by_global_limit_0x5a26e4 = true;
			result.global_limit_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (decision.relation_counter_0x44 >= decision.relation_limit_0x5a2a8c) {
			decision.rejected_by_relation_limit_0x5a2a8c = true;
			result.relation_limit_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		decision.accepted_after_counter_and_value_checks = true;

		int32_t score = 0;
		std::string score_blocker;
		if (!reward_guard_candidate_score_0x4aa151(state, selector, candidate, score, score_blocker)) {
			decision.rejected_by_score_dispatch = true;
			decision.blocked_reason = score_blocker;
			result.score_dispatch_missing_count += 1;
			result.blocked_reason = score_blocker;
			result.candidate_decisions.push_back(decision);
			return result;
		}
		decision.score_dispatch_0x04_known = true;
		decision.score_dispatch_value_0x04 = score;
		if (score < 0) {
			decision.rejected_by_score_dispatch = true;
			result.score_dispatch_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (score < lower_value_bound || score > upper_value_bound) {
			decision.rejected_by_value_bounds = true;
			result.value_bound_reject_count += 1;
			result.candidate_decisions.push_back(decision);
			continue;
		}
		if (!candidate.selection_weight_0x10_known || candidate.selection_weight_0x10 <= 0) {
			decision.rejected_by_score_dispatch = true;
			decision.blocked_reason = "0x4a9f1c_candidate_selection_weight_0x10_missing_or_nonpositive";
			result.score_dispatch_missing_count += 1;
			result.blocked_reason = decision.blocked_reason;
			result.candidate_decisions.push_back(decision);
			return result;
		}
		if (state.descriptor_vector_398_39c_source_owned) {
			if (selector == nullptr || !selector->terrain_policy_0x0c_known) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_selector_lane_0x0c_missing_before_0x4a9e40_descriptor_selection";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			if (!candidate.cursor_source_0x08_known) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_candidate_source_field_0x08_missing_before_0x4a9e40_descriptor_selection";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			const int32_t metadata_bucket_0x08 =
					source_object_metadata_bucket_for_type_0x57c648_0x08(candidate.descriptor_type_0x04);
			if (metadata_bucket_0x08 < 0) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_candidate_type_missing_metadata_bucket_0x57c648_0x08_before_0x4a9e40";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			decision.descriptor_selector_invoked_0x4a9e40 = true;
			decision.descriptor_selector_0x4a9e40 = source_object_wrapper_selector_0x4a9e40(
					rng.state,
					selector->terrain_policy_0x0c,
					metadata_bucket_0x08,
					candidate.cursor_source_0x08);
			if (decision.descriptor_selector_0x4a9e40.rng_consumed) {
				rng.state = decision.descriptor_selector_0x4a9e40.rng_state_after;
			}
			if (!decision.descriptor_selector_0x4a9e40.selected
					|| decision.descriptor_selector_0x4a9e40.selected_source_record_index < 0) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_0x4a9e40_descriptor_selection_empty";
				result.score_dispatch_reject_count += 1;
				result.candidate_decisions.push_back(decision);
				continue;
			}
			const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
			if (decision.descriptor_selector_0x4a9e40.selected_source_record_index >= int32_t(records.size())) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_0x4a9e40_selected_source_record_out_of_range";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			decision.selected_source_record_known_0x4a9e40 = true;
			decision.selected_source_catalog_index_0x49da08 =
					decision.descriptor_selector_0x4a9e40.selected_source_record_index;
			decision.selected_source_record_copy = records[size_t(decision.selected_source_catalog_index_0x49da08)];
			decision.selected_descriptor_vector_index_0x398 =
					descriptor_vector_index_for_source_catalog_index_0x398(
							state,
							decision.selected_source_catalog_index_0x49da08);
			if (decision.selected_descriptor_vector_index_0x398 < 0) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_selected_source_record_missing_from_generator_descriptor_vector_0x398";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
		}
		if (callsite_args.coordinate_tuple_0x24_known
				&& callsite_args.coordinate_tuple_0x24.x >= 0) {
			decision.rejected_by_score_dispatch = true;
			decision.blocked_reason = "0x4a9f1c_0x49a6f9_callsite_0x24_gate_unported_for_nonnegative_tuple";
			result.score_dispatch_missing_count += 1;
			result.blocked_reason = decision.blocked_reason;
			result.candidate_decisions.push_back(decision);
			return result;
		}
		if (callsite_args.policy_extent_byte_0x20 != 0U) {
			result.policy_extent_gate_invoked_0x20 = true;
			decision.policy_extent_gate_0x20_invoked = true;
			if (!decision.selected_source_record_known_0x4a9e40) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_0x4aa195_selected_descriptor_missing_for_policy_gate_0x20";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			const int32_t extent_count_0x4aa195 =
					reward_guard_descriptor_mask_extent_count_0x4aa195(decision.selected_source_record_copy);
			decision.policy_extent_mask_count_0x4aa195 = extent_count_0x4aa195;
			if (extent_count_0x4aa195 <= 0) {
				decision.rejected_by_score_dispatch = true;
				decision.blocked_reason = "0x4a9f1c_0x4aa195_descriptor_mask_extent_count_nonpositive";
				result.score_dispatch_missing_count += 1;
				result.blocked_reason = decision.blocked_reason;
				result.candidate_decisions.push_back(decision);
				return result;
			}
			const int32_t score_per_mask_cell = score / extent_count_0x4aa195;
			decision.policy_extent_score_per_mask_cell = score_per_mask_cell;
			const int32_t previous_best = result.policy_extent_best_score_per_mask_cell;
			if (score_per_mask_cell < (previous_best * 3) / 4) {
				decision.rejected_by_policy_extent_gate_0x20 = true;
				result.policy_extent_gate_reject_count_0x20 += 1;
				result.candidate_decisions.push_back(decision);
				continue;
			}
			if (previous_best < (score_per_mask_cell * 3) / 4) {
				accepted_candidate_indexes.clear();
				result.accepted_count = 0;
				result.accepted_weight_total_0x14 = 0;
				result.policy_extent_best_score_per_mask_cell = score_per_mask_cell;
				result.policy_extent_vector_clear_count_0x42bde9 += 1;
			}
		}
		decision.accepted_after_score_dispatch = true;
		result.accepted_count += 1;
		result.accepted_weight_total_0x14 += candidate.selection_weight_0x10;
		accepted_candidate_indexes.push_back(candidate_index);
		result.candidate_decisions.push_back(decision);
	}

	if (accepted_candidate_indexes.empty() || result.accepted_weight_total_0x14 <= 0) {
		result.blocked_reason = "0x4a9f1c_no_weighted_candidate_after_score_dispatch";
		return result;
	}

	result.rng_value_0x4e7276 = rng.next();
	result.rng_consumed_0x4aa110 = true;
	result.rng_state_after_0x4aa110 = rng.state;
	result.selected_weight_remainder = result.rng_value_0x4e7276 % result.accepted_weight_total_0x14;
	int32_t remaining = result.selected_weight_remainder;
	for (int32_t ordinal = 0; ordinal < int32_t(accepted_candidate_indexes.size()); ++ordinal) {
		const int32_t candidate_index = accepted_candidate_indexes[size_t(ordinal)];
		const RewardGuardCandidateRecord4a9f1c &candidate = state.reward_guard_candidate_records_10f4_10f8[size_t(candidate_index)];
		remaining -= candidate.selection_weight_0x10;
		if (remaining < 0) {
			result.selected_accepted_ordinal = ordinal;
			result.selected_candidate_index = candidate_index;
			result.selected_candidate_vtable_known = candidate.candidate_vtable_0x00_known;
			result.selected_candidate_vtable_0x00 = candidate.candidate_vtable_0x00;
			break;
		}
	}
	if (result.selected_candidate_index < 0) {
		result.blocked_reason = "0x4a9f1c_weighted_candidate_selection_failed";
		return result;
	}

	RewardGuardCandidateDecision4a9f1c &selected_decision = result.candidate_decisions[size_t(result.selected_candidate_index)];
	selected_decision.selected_by_weighted_rng_0x4aa110 = true;
	selected_decision.selected_score_replayed_0x4aa151 = true;
	result.selected_source_record_known_0x4a9e40 = selected_decision.selected_source_record_known_0x4a9e40;
	result.selected_source_catalog_index_0x49da08 = selected_decision.selected_source_catalog_index_0x49da08;
	result.selected_descriptor_vector_index_0x398 = selected_decision.selected_descriptor_vector_index_0x398;
	result.selected_source_record_copy = selected_decision.selected_source_record_copy;
	result.selected_score_dispatch_replayed_0x4aa151 = true;
	result.selected_score_value_known_0x04 = selected_decision.score_dispatch_0x04_known;
	result.selected_score_value_0x04 = selected_decision.score_dispatch_value_0x04;
	selected_decision.selected_create_dispatched_0x4aa166 = true;
	result.selected_create_dispatched_0x4aa166 = true;
	const RewardGuardCandidateRecord4a9f1c &selected_candidate = state.reward_guard_candidate_records_10f4_10f8[size_t(result.selected_candidate_index)];
	uint32_t selected_object_vtable_0x00 = 0U;
	if (!selected_candidate.candidate_vtable_0x00_known
			|| !reward_guard_candidate_vtable_returned_object_vtable_0x4aa166(
					selected_candidate.candidate_vtable_0x00,
					selected_object_vtable_0x00)) {
		result.blocked_reason = selected_candidate.candidate_vtable_0x00_known
				? "0x4a9f1c_selected_candidate_create_vtable_" + hex_u32(selected_candidate.candidate_vtable_0x00) + "_return_object_contract_unrecovered"
				: "0x4a9f1c_selected_candidate_create_vtable_missing_before_return_object_contract";
		return result;
	}
	result.selected_object_vtable_0x00_known = true;
	result.selected_object_vtable_0x00 = selected_object_vtable_0x00;
	if (selected_candidate.candidate_vtable_0x00_known
			&& reward_guard_candidate_vtable_returns_0x540b14(selected_candidate.candidate_vtable_0x00)) {
		result.selected_projection_object_0x540b14 =
				reward_guard_projection_object_from_selected_candidate_0x49cac2_0x49cb83_0x49cc22(selected_candidate);
		result.selected_projection_object_0x540b14_known = true;
	}
	return result;
}

static bool reward_guard_coordinate_vector_contains(const std::vector<CoordinateCandidate4a17f5> &candidates, int32_t x, int32_t y, int32_t level) {
	return std::any_of(candidates.begin(), candidates.end(), [&](const CoordinateCandidate4a17f5 &candidate) {
		return candidate.x == x && candidate.y == y && candidate.level == level;
	});
}

static const GeneratedCellRecord0x30 *reward_guard_wrapper_cell_0x49d2e0(const RewardGuardWrapperState4aa3e9 &wrapper, int32_t x, int32_t y, int32_t level) {
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return nullptr;
	}
	const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, x, y, level);
	if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
		return nullptr;
	}
	return &wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
}

static GeneratedCellRecord0x30 *reward_guard_wrapper_cell_mutable_0x49cf34(RewardGuardWrapperState4aa3e9 &wrapper, int32_t x, int32_t y, int32_t level) {
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return nullptr;
	}
	const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, x, y, level);
	if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
		return nullptr;
	}
	return &wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
}

static int32_t reward_guard_neighbor_descriptor_type_0x49d2e0(const RewardGuardWrapperState4aa3e9 &wrapper, const GeneratedCellRecord0x30 &record) {
	if (!record.object_reference_vector_contents_known || record.object_references_0x04_0x08.empty()) {
		return -1;
	}
	const uint32_t object_record_key = record.object_references_0x04_0x08.front();
	const auto member = std::find_if(wrapper.selected_members_0x2c_0x30.begin(),
			wrapper.selected_members_0x2c_0x30.end(),
			[&](const RewardGuardWrapperMember4aa3e9 &selected_member) {
				return selected_member.object_record_key_known
						&& selected_member.object_record_key == object_record_key
						&& selected_member.descriptor_type_0x1c >= 0;
			});
	if (member != wrapper.selected_members_0x2c_0x30.end()) {
		return member->descriptor_type_0x1c;
	}
	return -1;
}

struct SourceDescriptorFootprintResult49a6f9 {
	bool inputs_available = true;
	bool rejected = false;
	int32_t scanned_cell_count = 0;
	std::string blocked_reason;
};

static bool source_object_secondary_mask_terrain_rejects_0x49a6f9(const SourceObjectRecord0x4c &source, const GeneratedCellRecord0x30 &cell) {
	const bool generated_terrain8 = generated_cell_terrain_code_0x24(cell) == 8;
	const bool source_field_0x24_nonzero = source.group_0x24 != 0;
	const bool source_terrain8_flag_0x18 = (source.terrain_mask_b_0x18 & 0x0100U) != 0U;
	if (generated_terrain8) {
		return source_field_0x24_nonzero || !source_terrain8_flag_0x18;
	}
	return !source_field_0x24_nonzero && source_terrain8_flag_0x18;
}

static SourceDescriptorFootprintResult49a6f9 source_descriptor_footprint_rejects_0x49a6f9(
		const GeneratedCellRecordGrid0x30 &grid,
		const SourceObjectRecord0x4c &source,
		int32_t anchor_x,
		int32_t anchor_y,
		int32_t anchor_level,
		int32_t owner_byte2,
		bool reject_existing_bit26) {
	SourceDescriptorFootprintResult49a6f9 result;
	const int32_t descriptor_width = source.descriptor_width_0x34;
	const int32_t descriptor_height = source.descriptor_height_0x38;
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || grid.records.empty()) {
		result.inputs_available = false;
		result.rejected = true;
		result.blocked_reason = "0x49a6f9_generated_cell_grid_missing";
		return result;
	}
	if (anchor_x < descriptor_width - 1 || anchor_x >= grid.width || anchor_y < descriptor_height - 1 || anchor_y >= grid.height || anchor_level < 0 || anchor_level >= grid.level_count) {
		result.rejected = true;
		result.blocked_reason = "0x49a6f9_descriptor_anchor_outside_grid_bounds";
		return result;
	}

	for (int32_t row = 0; row < descriptor_height; ++row) {
		for (int32_t col = 0; col < descriptor_width; ++col) {
			const bool primary_mask = source_object_descriptor_mask_bit_0x4268eb(source, col, row);
			const bool secondary_mask = source_object_descriptor_mask_bit_0x41e951(source, col, row);
			if (!primary_mask && secondary_mask) {
				continue;
			}
			result.scanned_cell_count += 1;
			const int64_t flat = cell_index(grid.width, grid.height, anchor_x - col, anchor_y - row, anchor_level);
			if (flat < 0 || flat >= int64_t(grid.records.size())) {
				result.inputs_available = false;
				result.rejected = true;
				result.blocked_reason = "0x49a6f9_footprint_cell_missing";
				return result;
			}
			const GeneratedCellRecord0x30 &cell = grid.records[size_t(flat)];
			if (!cell.word_0x24_known || !cell.word_0x28_known || !generated_cell_49a1d8_valid_record(cell) || (cell.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
				result.rejected = true;
				result.blocked_reason = "0x49a6f9_footprint_cell_rejected";
				return result;
			}
			const bool checks_owner_byte = primary_mask || !secondary_mask;
			if (checks_owner_byte && !cell.word_0x20_known) {
				result.inputs_available = false;
				result.rejected = true;
				result.blocked_reason = "0x49a6f9_footprint_cell_owner_word_missing";
				return result;
			}
			if (checks_owner_byte) {
				if (generated_cell_word20_owner_byte2_signed(cell.word_0x20) != int32_t(int8_t(owner_byte2 & 0xff))) {
					result.rejected = true;
					result.blocked_reason = "0x49a6f9_footprint_owner_byte_rejected";
					return result;
				}
			}
			if (primary_mask) {
				if (reject_existing_bit26 && (cell.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
					result.rejected = true;
					result.blocked_reason = "0x49a6f9_footprint_existing_bit26_rejected";
					return result;
				}
			}
			if (!secondary_mask && source_object_secondary_mask_terrain_rejects_0x49a6f9(source, cell)) {
				result.rejected = true;
				result.blocked_reason = "0x49a6f9_secondary_mask_terrain_rejected";
				return result;
			}
		}
	}
	return result;
}

static bool reward_guard_footprint_rejects_0x49a6f9(const RewardGuardWrapperState4aa3e9 &wrapper, const RewardGuardWrapperMember4aa3e9 &member, const CoordinateCandidate4a17f5 &candidate, bool reject_existing_bit26, RewardGuardCandidateFilterResult49d2e0 &result) {
	if (!member.source_record_copy_known_0x04) {
		result.inputs_available = false;
		result.blocked_reason = "0x49d2e0_0x49a6f9_source_record_copy_missing";
		return true;
	}
	const SourceDescriptorFootprintResult49a6f9 footprint =
			source_descriptor_footprint_rejects_0x49a6f9(
					wrapper.generated_cell_grid_0x08_0x10,
					member.source_record_copy,
					candidate.x,
					candidate.y,
					candidate.level,
					-1,
					reject_existing_bit26);
	result.footprint_scan_count_0x49a6f9 += footprint.scanned_cell_count;
	if (!footprint.inputs_available) {
		result.inputs_available = false;
	}
	if (footprint.rejected) {
		result.footprint_reject_count_0x49a6f9 += 1;
		result.blocked_reason = footprint.blocked_reason.empty()
				? "0x49d2e0_0x49a6f9_footprint_rejected"
				: "0x49d2e0_" + footprint.blocked_reason;
		return true;
	}
	return false;
}

static RewardGuardCandidateFilterResult49d2e0 reward_guard_candidate_filter_0x49d2e0(const RewardGuardWrapperState4aa3e9 &wrapper, const RewardGuardWrapperMember4aa3e9 &member, const CoordinateCandidate4a17f5 &candidate) {
	RewardGuardCandidateFilterResult49d2e0 result;
	result.descriptor_type_0x1c = member.descriptor_type_0x1c;
	result.descriptor_relative_x = candidate.x - member.descriptor_offset_x_0x2c;
	result.descriptor_relative_y = candidate.y - member.descriptor_offset_y_0x30;
	result.descriptor_type_policy_known =
			member.descriptor_type_0x1c >= 0
			&& member.descriptor_type_0x1c < SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8;
	if (!wrapper.generated_cell_grid_0x08_0x10_known || wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		result.blocked_reason = "0x49d2e0_wrapper_generated_cell_grid_missing";
		return result;
	}
	if (!result.descriptor_type_policy_known) {
		result.blocked_reason = "0x49d2e0_descriptor_type_policy_missing";
		return result;
	}
	result.inputs_available = true;

	const bool policy_plus_1 = object_metadata_flag_0x598300(member.descriptor_type_0x1c, 1);
	if (!policy_plus_1) {
		for (int32_t direction_index = 5; direction_index < 8; ++direction_index) {
			result.policy_precheck_scan_count_0x5a2680 += 1;
			const GeneratedCellRecord0x30 *record = reward_guard_wrapper_cell_0x49d2e0(
					wrapper,
					result.descriptor_relative_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0],
					result.descriptor_relative_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1],
					candidate.level);
			if (record != nullptr
					&& record->word_0x28_known
					&& (record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
				result.policy_precheck_bit22_reject_count += 1;
				result.blocked_reason = "0x49d2e0_policy_plus_1_zero_precheck_bit22_reject";
				return result;
			}
		}
	}

	for (int32_t direction_index = 0; direction_index < 5; ++direction_index) {
		result.neighbor_policy_scan_count_0x5a2658 += 1;
		const GeneratedCellRecord0x30 *record = reward_guard_wrapper_cell_0x49d2e0(
				wrapper,
				result.descriptor_relative_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0],
				result.descriptor_relative_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1],
				candidate.level);
		if (record == nullptr || !record->word_0x28_known || (record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) == 0U) {
			continue;
		}
		result.neighbor_bit22_policy_check_count += 1;
		const int32_t neighbor_descriptor_type = reward_guard_neighbor_descriptor_type_0x49d2e0(wrapper, *record);
		if (neighbor_descriptor_type < 0) {
			result.inputs_available = false;
			result.blocked_reason = "0x49d2e0_bit22_neighbor_descriptor_type_missing";
			return result;
		}
		if (!object_metadata_flag_0x598300(neighbor_descriptor_type, 2)) {
			result.neighbor_policy_plus_2_reject_count += 1;
			result.blocked_reason = "0x49d2e0_neighbor_policy_plus_2_zero_reject";
			return result;
		}
		if (!object_metadata_flag_0x598300(neighbor_descriptor_type, 1)) {
			result.neighbor_policy_plus_1_reject_count += 1;
			result.blocked_reason = "0x49d2e0_neighbor_policy_plus_1_zero_reject";
			return result;
		}
	}

	const bool special_type_54_or_9 = member.descriptor_type_0x1c == 54 || member.descriptor_type_0x1c == 9;
	if (!special_type_54_or_9) {
		if (reward_guard_footprint_rejects_0x49a6f9(wrapper, member, candidate, true, result)) {
			return result;
		}
		result.accepted = true;
		return result;
	}

	if (reward_guard_footprint_rejects_0x49a6f9(wrapper, member, candidate, false, result)) {
		return result;
	}
	for (int32_t direction_index = 0; direction_index < int32_t(DIRECTION_TABLE_0X5A2658.size()); ++direction_index) {
		result.type54_9_neighbor_scan_count += 1;
		const GeneratedCellRecord0x30 *record = reward_guard_wrapper_cell_0x49d2e0(
				wrapper,
				result.descriptor_relative_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0],
				result.descriptor_relative_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1],
				candidate.level);
		if (record == nullptr || !record->word_0x28_known) {
			continue;
		}
		const bool bit22 = (record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
		const bool bit26 = (record->word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
		if (!bit22 && generated_cell_49a1d8_valid_record(*record) && !bit26) {
			result.type54_9_available_neighbor_count += 1;
		}
	}
	if (result.type54_9_available_neighbor_count <= 0) {
		result.blocked_reason = "0x49d2e0_type54_9_no_available_neighbor";
		return result;
	}
	result.accepted = true;
	return result;
}

static bool reward_guard_wrapper_contour_passable_0x49d7c3(const RewardGuardWrapperState4aa3e9 &wrapper, int32_t x, int32_t y, int32_t level) {
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return false;
	}
	const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, x, y, level);
	if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
		return false;
	}
	const GeneratedCellRecord0x30 &record = wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
	if (!record.word_0x28_known) {
		return false;
	}
	const bool bit22 = (record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
	const bool bit27 = (record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
	return !bit22 && generated_cell_49a1d8_valid_record(record) && bit27;
}

static RewardGuardWrapperConstructResult49ce04 reward_guard_wrapper_reset_existing_0x49ce64(RewardGuardWrapperState4aa3e9 &wrapper) {
	RewardGuardWrapperConstructResult49ce04 result;
	result.width_0x0c = wrapper.generated_cell_grid_0x08_0x10.width;
	result.height_0x10 = wrapper.generated_cell_grid_0x08_0x10.height;
	result.level_count_0x14 = wrapper.generated_cell_grid_0x08_0x10.level_count;
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| result.width_0x0c <= 0
			|| result.height_0x10 <= 0
			|| result.level_count_0x14 <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		result.blocked_reason = "0x49ce64_wrapper_grid_missing_before_reset";
		return result;
	}
	wrapper.generated_cell_grid_0x08_0x10 =
			generated_cell_record_grid_reset_0x49a072(result.width_0x0c, result.height_0x10, result.level_count_0x14);
	wrapper.generated_cell_grid_0x08_0x10_known = !wrapper.generated_cell_grid_0x08_0x10.records.empty();
	if (!wrapper.generated_cell_grid_0x08_0x10_known) {
		result.blocked_reason = "0x49ce64_wrapper_grid_0x49a072_reset_failed";
		return result;
	}
	wrapper.selected_member_vector_0x2c_0x30_known = true;
	wrapper.selected_members_0x2c_0x30.clear();
	wrapper.candidate_coordinate_vector_0x3c_0x40_known = true;
	wrapper.candidate_coordinates_0x3c_0x40.clear();
	wrapper.attached_flag_0x48_known = true;
	wrapper.attached_flag_0x48 = false;
	wrapper.attached_relative_coordinate_0x4c_0x50_known = false;
	wrapper.selected_coordinate_0x54_0x5c_known = false;
	wrapper.final_projection_mark_byte_0x60_known = true;
	wrapper.final_projection_mark_byte_0x60 = false;
	for (GeneratedCellRecord0x30 &record : wrapper.generated_cell_grid_0x08_0x10.records) {
		if (record.word_0x24_known) {
			record.word_0x24 = generated_cell_49acf6_word24(record.word_0x24, 0, 0);
		}
		if (record.word_0x28_known) {
			record.word_0x28 = generated_cell_49acf6_word28(record.word_0x28, 0, 0);
			sync_generated_cell_byte_0x2b_from_word28(record);
		}
		result.reset_cell_count_0x49ce64 += 1;
	}
	result.wrapper = wrapper;
	result.applied = true;
	return result;
}

static RewardGuardWrapperConstructResult49ce04 reward_guard_wrapper_cleanup_0x49cebd(RewardGuardWrapperState4aa3e9 &wrapper) {
	return reward_guard_wrapper_reset_existing_0x49ce64(wrapper);
}

RewardGuardWrapperConstructResult49ce04 reward_guard_wrapper_construct_0x49ce04() {
	RewardGuardWrapperConstructResult49ce04 result;
	result.width_0x0c = 0x10;
	result.height_0x10 = 0x10;
	result.level_count_0x14 = 1;
	RewardGuardWrapperState4aa3e9 wrapper;
	wrapper.generated_cell_grid_0x08_0x10_known = true;
	wrapper.generated_cell_grid_0x08_0x10 = generated_cell_record_grid_reset_0x49a072(result.width_0x0c, result.height_0x10, result.level_count_0x14);
	const RewardGuardWrapperConstructResult49ce04 reset = reward_guard_wrapper_reset_existing_0x49ce64(wrapper);
	result.reset_cell_count_0x49ce64 = reset.reset_cell_count_0x49ce64;
	result.wrapper = wrapper;
	result.applied = reset.applied && !wrapper.generated_cell_grid_0x08_0x10.records.empty();
	if (!result.applied) {
		result.blocked_reason = reset.blocked_reason.empty()
				? "0x49ce04_wrapper_grid_allocation_failed"
				: reset.blocked_reason;
	}
	return result;
}

RewardGuardWrapperRefreshResult49d6e0 reward_guard_wrapper_refresh_bounds_0x49d6e0(RewardGuardWrapperState4aa3e9 &wrapper) {
	RewardGuardWrapperRefreshResult49d6e0 result;
	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x49d6e0_wrapper_generated_cell_grid_missing");
	}

	int32_t min_x = 0x7d00;
	int32_t min_y = 0x7d00;
	int32_t max_x = -0x7d00;
	int32_t max_y = -0x7d00;
	for (int32_t y = 0; y < wrapper.generated_cell_grid_0x08_0x10.height; ++y) {
		for (int32_t x = 0; x < wrapper.generated_cell_grid_0x08_0x10.width; ++x) {
			const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, x, y, 0);
			if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
				continue;
			}
			result.scanned_cell_count += 1;
			const GeneratedCellRecord0x30 &record = wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
			const bool valid = generated_cell_49a1d8_valid_record(record);
			const bool bit22 = record.word_0x28_known && (record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
			const bool bit27 = record.word_0x28_known && (record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
			if (valid && !bit22 && bit27) {
				result.skipped_solid_cell_count += 1;
				continue;
			}
			min_x = std::min(min_x, x);
			min_y = std::min(min_y, y);
			max_x = std::max(max_x, x + 1);
			max_y = std::max(max_y, y + 1);
			result.included_cell_count += 1;
		}
	}
	wrapper.wrapper_bounds_0x18_0x24_known = true;
	wrapper.bound_left_0x18 = min_x;
	wrapper.bound_top_0x1c = min_y;
	wrapper.bound_right_0x20 = max_x;
	wrapper.bound_bottom_0x24 = max_y;
	result.bound_left_0x18 = min_x;
	result.bound_top_0x1c = min_y;
	result.bound_right_0x20 = max_x;
	result.bound_bottom_0x24 = max_y;
	result.applied = true;
	return result;
}

RewardGuardWrapperCandidateRebuildResult49d7c3 reward_guard_wrapper_rebuild_candidates_0x49d7c3(RewardGuardWrapperState4aa3e9 &wrapper) {
	RewardGuardWrapperCandidateRebuildResult49d7c3 result;
	result.candidate_count_before = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		result.candidate_count_after = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
		return result;
	};
	if (!wrapper.candidate_coordinate_vector_0x3c_0x40_known) {
		return finish_blocked("0x49d7c3_candidate_coordinate_vector_missing");
	}
	if (!wrapper.candidate_coordinates_0x3c_0x40.empty()) {
		result.returned_without_rebuild_existing_vector = true;
		result.candidate_count_after = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
		result.applied = true;
		return result;
	}
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x49d7c3_wrapper_generated_cell_grid_missing");
	}

	int32_t boundary_x = 0;
	int32_t boundary_y = 0;
	bool boundary_found = false;
	for (int32_t y = 0; y < wrapper.generated_cell_grid_0x08_0x10.height && !boundary_found; ++y) {
		for (int32_t x = 0; x < wrapper.generated_cell_grid_0x08_0x10.width; ++x) {
			if (!reward_guard_wrapper_contour_passable_0x49d7c3(wrapper, x, y, 0)) {
				boundary_x = x;
				boundary_y = y;
				boundary_found = true;
				break;
			}
		}
	}
	if (!boundary_found) {
		result.candidate_count_after = 0;
		result.applied = true;
		return result;
	}

	result.seed_boundary_found = true;
	result.seed_boundary_x = boundary_x;
	result.seed_boundary_y = boundary_y;
	const int32_t initial_x = boundary_x;
	const int32_t initial_y = boundary_y - 1;
	int32_t current_x = initial_x;
	int32_t current_y = initial_y;
	int32_t direction_index = 2;
	std::vector<CoordinateCandidate4a17f5> rebuilt_candidates;
	const int32_t max_steps = std::max<int32_t>(
			8,
			wrapper.generated_cell_grid_0x08_0x10.width
					* wrapper.generated_cell_grid_0x08_0x10.height
					* std::max<int32_t>(1, wrapper.generated_cell_grid_0x08_0x10.level_count)
					* 8);
	for (int32_t step = 0; step < max_steps; ++step) {
		rebuilt_candidates.push_back({ current_x, current_y, 0 });
		int32_t selected_direction = direction_index;
		bool passable_neighbor_found = false;
		for (int32_t probe = 0; probe < 4; ++probe) {
			selected_direction = (selected_direction - 2) & 7;
			result.contour_probe_count += 1;
			const int32_t target_x = current_x + DIRECTION_TABLE_0X5A2658[size_t(selected_direction)][0];
			const int32_t target_y = current_y + DIRECTION_TABLE_0X5A2658[size_t(selected_direction)][1];
			if (reward_guard_wrapper_contour_passable_0x49d7c3(wrapper, target_x, target_y, 0)) {
				passable_neighbor_found = true;
				break;
			}
		}
		if (!passable_neighbor_found) {
			result.contour_forced_step_count += 1;
		}
		current_x += DIRECTION_TABLE_0X5A2658[size_t(selected_direction)][0];
		current_y += DIRECTION_TABLE_0X5A2658[size_t(selected_direction)][1];
		direction_index = (selected_direction - 4) & 7;
		if (current_x == initial_x && current_y == initial_y) {
			wrapper.candidate_coordinates_0x3c_0x40 = rebuilt_candidates;
			result.appended_coordinates = rebuilt_candidates;
			result.contour_append_count = int32_t(rebuilt_candidates.size());
			result.candidate_count_after = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
			result.applied = true;
			return result;
		}
	}
	result.contour_append_count = int32_t(rebuilt_candidates.size());
	result.appended_coordinates = rebuilt_candidates;
	return finish_blocked("0x49d7c3_contour_walk_did_not_close");
}

RewardGuardWrapperFinalMarkResult49cefb reward_guard_wrapper_mark_candidate_cells_0x49cefb(RewardGuardWrapperState4aa3e9 &wrapper) {
	RewardGuardWrapperFinalMarkResult49cefb result;
	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x49cefb_wrapper_generated_cell_grid_missing");
	}
	if (!wrapper.candidate_coordinate_vector_0x3c_0x40_known) {
		return finish_blocked("0x49cefb_candidate_coordinate_vector_missing");
	}
	wrapper.final_projection_mark_byte_0x60_known = true;
	wrapper.final_projection_mark_byte_0x60 = true;
	result.candidate_count = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	for (const CoordinateCandidate4a17f5 &candidate : wrapper.candidate_coordinates_0x3c_0x40) {
		const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, candidate.x, candidate.y, candidate.level);
		if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
			result.out_of_bounds_candidate_count += 1;
			continue;
		}
		GeneratedCellRecord0x30 &record = wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
		record.byte_0x2a_known = true;
		record.byte_0x2a_known_mask |= CELL_REWARD_GUARD_FINAL_MARK_BYTE_0X2A_BIT_7;
		if ((record.byte_0x2a & CELL_REWARD_GUARD_FINAL_MARK_BYTE_0X2A_BIT_7) == 0U) {
			result.marked_candidate_cell_count += 1;
		}
		record.byte_0x2a |= CELL_REWARD_GUARD_FINAL_MARK_BYTE_0X2A_BIT_7;
	}
	result.applied = true;
	return result;
}

static int32_t reward_guard_stamp_member_body_0x49abd6(RewardGuardWrapperState4aa3e9 &wrapper, const RewardGuardWrapperMember4aa3e9 &member);

RewardGuardAttachResult49cf34 reward_guard_attach_member_0x49cf34(RewardGuardWrapperState4aa3e9 &wrapper, const RewardGuardWrapperMember4aa3e9 &member, H3MapedRng &rng) {
	RewardGuardAttachResult49cf34 result;
	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};
	if (!wrapper.generated_cell_grid_0x08_0x10_known || wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x49cf34_wrapper_generated_cell_grid_missing");
	}
	if (!wrapper.selected_member_vector_0x2c_0x30_known) {
		return finish_blocked("0x49cf34_selected_member_vector_missing");
	}
	if (!wrapper.candidate_coordinate_vector_0x3c_0x40_known) {
		return finish_blocked("0x49cf34_candidate_coordinate_vector_missing");
	}
	if (!member.object_record_key_known) {
		return finish_blocked("0x49cf34_member_object_record_key_missing");
	}

	result.candidate_rebuild_0x49d7c3 = reward_guard_wrapper_rebuild_candidates_0x49d7c3(wrapper);
	result.initial_candidate_refresh_0x49d7c3_applied = result.candidate_rebuild_0x49d7c3.applied;
	result.initial_candidate_refresh_returned_existing_vector_0x49d7c3 =
			result.candidate_rebuild_0x49d7c3.returned_without_rebuild_existing_vector;
	if (!result.candidate_rebuild_0x49d7c3.applied) {
		return finish_blocked(result.candidate_rebuild_0x49d7c3.blocked_reason.empty()
				? "0x49cf34_initial_0x49d7c3_candidate_refresh_failed"
				: result.candidate_rebuild_0x49d7c3.blocked_reason);
	}

	for (const RewardGuardWrapperMember4aa3e9 &selected_member : wrapper.selected_members_0x2c_0x30) {
		if (selected_member.descriptor_type_0x1c < 0) {
			continue;
		}
		const int32_t direction_count = object_metadata_flag_0x598300(selected_member.descriptor_type_0x1c, 1) ? 8 : 5;
		const int32_t base_x = selected_member.relative_x_0x08 - selected_member.descriptor_offset_x_0x2c;
		const int32_t base_y = selected_member.relative_y_0x0c - selected_member.descriptor_offset_y_0x30;
		for (int32_t direction_index = direction_count - 1; direction_index >= 0; --direction_index) {
			result.existing_member_probe_count_0x49cf34 += 1;
			const int32_t probe_x = base_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0];
			const int32_t probe_y = base_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1];
			const int32_t probe_level = selected_member.relative_level_0x10;
			GeneratedCellRecord0x30 *probe_record = reward_guard_wrapper_cell_mutable_0x49cf34(wrapper, probe_x, probe_y, probe_level);
			if (probe_record == nullptr || !probe_record->word_0x28_known) {
				result.existing_member_probe_out_of_bounds_count_0x49cf34 += 1;
				continue;
			}
			const bool probe_bit22 = (probe_record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
			if (probe_bit22) {
				result.existing_member_probe_bit22_reject_count_0x49cf34 += 1;
				continue;
			}
			if (!generated_cell_49a1d8_valid_record(*probe_record)) {
				result.existing_member_probe_invalid_reject_count_0x49a1d8 += 1;
				continue;
			}
			if (generated_cell_49aa63(*probe_record, true)) {
				result.existing_member_candidate_set_count_0x49aa63 += 1;
			} else {
				result.existing_member_probe_word2c_reject_count_0x49aa63 += 1;
			}
			for (int32_t y = std::max<int32_t>(0, probe_y - 1); y <= std::min<int32_t>(wrapper.generated_cell_grid_0x08_0x10.height - 1, probe_y + 1); ++y) {
				for (int32_t x = std::max<int32_t>(0, probe_x - 1); x <= std::min<int32_t>(wrapper.generated_cell_grid_0x08_0x10.width - 1, probe_x + 1); ++x) {
					GeneratedCellRecord0x30 *nearby = reward_guard_wrapper_cell_mutable_0x49cf34(wrapper, x, y, probe_level);
					if (nearby == nullptr || !nearby->word_0x28_known) {
						continue;
					}
					const bool nearby_bit22 = (nearby->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
					if (nearby_bit22 || !generated_cell_49a1d8_valid_record(*nearby)) {
						continue;
					}
					if (generated_cell_49a932(*nearby, false)) {
						result.existing_member_neighbor_bit27_clear_count_0x49a932 += 1;
					}
				}
			}
		}
	}

	result.candidate_count_before_filter = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	std::vector<CoordinateCandidate4a17f5> filtered_candidates;
	filtered_candidates.reserve(wrapper.candidate_coordinates_0x3c_0x40.size());
	for (const CoordinateCandidate4a17f5 &candidate : wrapper.candidate_coordinates_0x3c_0x40) {
		const int64_t flat = cell_index(wrapper.generated_cell_grid_0x08_0x10.width, wrapper.generated_cell_grid_0x08_0x10.height, candidate.x, candidate.y, candidate.level);
		const bool in_bounds = flat >= 0 && flat < int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size());
		const bool bit26_set = in_bounds
				&& wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)].word_0x28_known
				&& (wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)].word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
		if (!bit26_set) {
			result.bit26_clear_candidate_erase_count_0x4afaea += 1;
			continue;
		}
		const RewardGuardCandidateFilterResult49d2e0 filter_result =
				reward_guard_candidate_filter_0x49d2e0(wrapper, member, candidate);
		result.filter_results_0x49d2e0.push_back(filter_result);
		if (!filter_result.inputs_available) {
			result.filter_missing_input_count_0x49d2e0 += 1;
			continue;
		}
		if (!filter_result.accepted) {
			result.filter_reject_count_0x49d2e0 += 1;
			continue;
		}
		filtered_candidates.push_back(candidate);
	}
	wrapper.candidate_coordinates_0x3c_0x40 = filtered_candidates;
	result.candidate_count_after_filter = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	if (wrapper.candidate_coordinates_0x3c_0x40.empty()) {
		if (result.filter_missing_input_count_0x49d2e0 > 0 && result.filter_reject_count_0x49d2e0 == 0) {
			return finish_blocked("0x49cf34_0x49d2e0_candidate_filter_inputs_missing");
		}
		return finish_blocked("0x49cf34_candidate_vector_empty_after_bit26_and_0x49d2e0_filters");
	}

	result.rng_value_0x4e7276 = rng.next();
	result.selected_candidate_index = result.rng_value_0x4e7276 % int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	result.selected_candidate = wrapper.candidate_coordinates_0x3c_0x40[size_t(result.selected_candidate_index)];
	result.selected_candidate_known = true;

	RewardGuardWrapperMember4aa3e9 placed_member = member;
	placed_member.relative_x_0x08 = result.selected_candidate.x;
	placed_member.relative_y_0x0c = result.selected_candidate.y;
	placed_member.relative_level_0x10 = result.selected_candidate.level;
	wrapper.selected_members_0x2c_0x30.push_back(placed_member);
	result.appended_member_0x49d69d = true;
	result.selected_member_count_after = int32_t(wrapper.selected_members_0x2c_0x30.size());
	result.body_stamp_count_0x49abd6 = reward_guard_stamp_member_body_0x49abd6(wrapper, placed_member);
	result.stamped_member_0x49abd6 = result.body_stamp_count_0x49abd6 > 0;
	if (result.body_stamp_count_0x49abd6 <= 0) {
		return finish_blocked("0x49cf34_0x49d69d_0x49abd6_member_body_stamp_empty");
	}

	const int32_t descriptor_relative_x = placed_member.relative_x_0x08 - placed_member.descriptor_offset_x_0x2c;
	const int32_t descriptor_relative_y = placed_member.relative_y_0x0c - placed_member.descriptor_offset_y_0x30;
	result.primary_bit27_descriptor_relative_base_known_0x49d179_0x49d184 = true;
	result.primary_bit27_descriptor_relative_x_0x49d184 = descriptor_relative_x;
	result.primary_bit27_descriptor_relative_y_0x49d17f = descriptor_relative_y;
	for (int32_t direction_index = 0; direction_index < int32_t(DIRECTION_TABLE_0X5A2658.size()); ++direction_index) {
		const int32_t x = descriptor_relative_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0];
		const int32_t y = descriptor_relative_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1];
		GeneratedCellRecord0x30 *record = reward_guard_wrapper_cell_mutable_0x49cf34(wrapper, x, y, placed_member.relative_level_0x10);
		if (record == nullptr || !record->word_0x28_known || !generated_cell_49a1d8_valid_record(*record)) {
			continue;
		}
		if (placed_member.descriptor_type_0x1c == 9
				&& (record->word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
			continue;
		}
		if (generated_cell_49a932(*record, true)) {
			result.primary_bit27_write_count_0x49d1ed += 1;
		}
		const int32_t neighbor_start_direction =
				(direction_index & 1) != 0 ? ((direction_index - 1) & 7) : direction_index;
		const int32_t neighbor_direction_count = (direction_index & 1) != 0 ? 3 : 1;
		for (int32_t neighbor_step = 0; neighbor_step < neighbor_direction_count; ++neighbor_step) {
			const int32_t neighbor_direction_index = (neighbor_start_direction + neighbor_step) & 7;
			const int32_t neighbor_x = x + DIRECTION_TABLE_0X5A2658[size_t(neighbor_direction_index)][0];
			const int32_t neighbor_y = y + DIRECTION_TABLE_0X5A2658[size_t(neighbor_direction_index)][1];
			GeneratedCellRecord0x30 *neighbor_record =
					reward_guard_wrapper_cell_mutable_0x49cf34(wrapper, neighbor_x, neighbor_y, placed_member.relative_level_0x10);
			if (neighbor_record == nullptr || !neighbor_record->word_0x28_known) {
				continue;
			}
			if ((neighbor_record->word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U
					|| (neighbor_record->word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
					|| !generated_cell_49a1d8_valid_record(*neighbor_record)) {
				continue;
			}
			if (generated_cell_49a932(*neighbor_record, true)) {
				result.neighbor_bit27_write_count_0x49d270 += 1;
			}
		}
	}

	wrapper.attached_flag_0x48_known = true;
	wrapper.attached_flag_0x48 = true;
	result.attached_flag_set_0x48 = true;
	wrapper.attached_relative_coordinate_0x4c_0x50_known = true;
	wrapper.attached_relative_x_0x4c = descriptor_relative_x;
	wrapper.attached_relative_y_0x50 = descriptor_relative_y;
	result.attached_relative_coordinate_written_0x4c_0x50 = true;
	result.candidate_cleanup_count_0x4ae2d0 = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	wrapper.candidate_coordinates_0x3c_0x40.clear();
	result.bounds_refresh_0x49d6e0 = reward_guard_wrapper_refresh_bounds_0x49d6e0(wrapper);
	if (!result.bounds_refresh_0x49d6e0.applied) {
		return finish_blocked(result.bounds_refresh_0x49d6e0.blocked_reason.empty()
				? "0x49cf34_0x49d6e0_bounds_refresh_failed"
				: result.bounds_refresh_0x49d6e0.blocked_reason);
	}
	result.candidate_rebuild_0x49d7c3 = reward_guard_wrapper_rebuild_candidates_0x49d7c3(wrapper);
	if (!result.candidate_rebuild_0x49d7c3.applied) {
		return finish_blocked(result.candidate_rebuild_0x49d7c3.blocked_reason.empty()
				? "0x49cf34_post_cleanup_0x49d7c3_candidate_rebuild_failed"
				: result.candidate_rebuild_0x49d7c3.blocked_reason);
	}
	result.applied = true;
	return result;
}

struct RewardGuardMemberAllocationResult4a5c07 {
	bool applied = false;
	bool null_selection = false;
	RewardGuardWrapperMember4aa3e9 member;
	int32_t selected_source_catalog_index_0x49da08 = -1;
	int32_t selected_descriptor_vector_index_0x398 = -1;
	SourceObjectRecord0x4c selected_source_record_copy;
	uint32_t object_record_key = 0U;
	bool object_record_key_known = false;
	int32_t sequence_0x1c = -1;
	int32_t selected_quantity_0x20 = 0;
	bool body_anchor_fallback = false;
	std::string blocked_reason;
};

struct ConnectionMonsterAllocationResult4a5c07 {
	bool invoked = false;
	bool applied = false;
	bool null_selection = false;
	int32_t accepted_row_count = 0;
	int32_t selected_creature_id = -1;
	int32_t selected_quantity_0x20 = 0;
	int32_t selected_descriptor_vector_index_0x398 = -1;
	uint32_t object_record_key = 0U;
	bool object_record_key_known = false;
	int32_t sequence_0x1c = -1;
	SourceObjectRecord0x4c source_record_copy;
	std::string blocked_reason;
};

static ConnectionMonsterAllocationResult4a5c07 connection_monster_allocate_0x4a5c07(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t value_arg_0x08,
		H3MapedRng &rng);

static const GeneratorDescriptorVectorEntry0x398 *descriptor_vector_entry_by_index_0x4a5c07(
		const GeneratorObjectPrivateState &state,
		int32_t vector_index) {
	if (vector_index < 0) {
		return nullptr;
	}
	for (const GeneratorDescriptorVectorEntry0x398 &entry : state.descriptor_vector_entries_398_39c) {
		if (entry.vector_index == vector_index) {
			return &entry;
		}
	}
	return nullptr;
}

static const GeneratorDescriptorVectorEntry0x398 *selected_descriptor_vector_entry_0x4a5c07(
		const GeneratorObjectPrivateState &state,
		const RewardGuardSelectorResult4a9f1c &selector) {
	return descriptor_vector_entry_by_index_0x4a5c07(state, selector.selected_descriptor_vector_index_0x398);
}

static RewardGuardMemberAllocationResult4a5c07 reward_guard_allocate_member_from_selector_0x4a5c07(
		GeneratorObjectPrivateState &state,
		const RewardGuardSelectorResult4a9f1c &selector,
		uint32_t object_vtable_0x00,
		bool object_vtable_known) {
	RewardGuardMemberAllocationResult4a5c07 result;
	if (!selector.selected_source_record_known_0x4a9e40) {
		result.blocked_reason = "0x4a5c07_selected_source_record_missing_before_reward_guard_member_allocation";
		return result;
	}
	if (!object_vtable_known) {
		result.blocked_reason = "0x4a5c07_selected_object_vtable_missing_before_reward_guard_member_allocation";
		return result;
	}
	if (!state.native_object_record_key_allocator_0x4a93a2_known) {
		result.blocked_reason = "0x4a5c07_object_record_key_allocator_missing";
		return result;
	}
	if (!state.object_record_sequence_allocator_0xf44_known) {
		result.blocked_reason = "0x4a5c07_object_sequence_allocator_0xf44_missing";
		return result;
	}
	if (!state.descriptor_vector_398_39c_source_owned || state.descriptor_vector_entries_398_39c.empty()) {
		result.blocked_reason = "0x4a5c07_generator_descriptor_vector_0x398_0x39c_missing";
		return result;
	}

	const GeneratorDescriptorVectorEntry0x398 *selected_descriptor =
			selected_descriptor_vector_entry_0x4a5c07(state, selector);
	if (selected_descriptor == nullptr) {
		result.blocked_reason = "0x4a5c07_selected_descriptor_vector_entry_missing";
		return result;
	}
	if (!selected_descriptor->descriptor_source_cell_offsets_0x2c_0x30_known) {
		result.blocked_reason = "0x4a5c07_selected_descriptor_source_cell_offsets_0x2c_0x30_missing";
		return result;
	}
	const SourceObjectRecord0x4c &selected_source = selected_descriptor->source_record_copy;
	std::vector<CoordinateCandidate4a17f5> body_offsets =
			descriptor_body_offsets_from_primary_mask_0x49a6f9(
					selected_source,
					selected_descriptor->descriptor_source_cell_x_0x2c,
					selected_descriptor->descriptor_source_cell_y_0x30);
	if (body_offsets.empty()) {
		body_offsets.push_back(CoordinateCandidate4a17f5 { 0, 0, 0 });
		result.body_anchor_fallback = true;
	}

	result.selected_source_catalog_index_0x49da08 = selected_descriptor->source_catalog_index_0x49da08;
	result.selected_descriptor_vector_index_0x398 = selected_descriptor->vector_index;
	result.selected_source_record_copy = selected_source;
	result.object_record_key_known = true;
	result.object_record_key = state.next_native_object_record_key_0x4a93a2;
	state.next_native_object_record_key_0x4a93a2 += 1U;
	state.object_record_allocation_count_0x4a93a2 += 1;
	result.sequence_0x1c = state.object_record_sequence_allocator_0xf44;
	state.object_record_sequence_allocator_0xf44 += 1;

	result.member.object_record_key = result.object_record_key;
	result.member.object_record_key_known = true;
	result.member.object_record_vtable_0x00 = object_vtable_0x00;
	result.member.descriptor_type_0x1c = selected_descriptor->descriptor_type_0x1c;
	result.member.descriptor_projection_enabled_0x29 = selected_descriptor->descriptor_projection_enabled_0x29;
	result.member.descriptor_offset_x_0x2c = selected_descriptor->descriptor_source_cell_x_0x2c;
	result.member.descriptor_offset_y_0x30 = selected_descriptor->descriptor_source_cell_y_0x30;
	result.member.source_record_copy_known_0x04 = true;
	result.member.source_record_copy = selected_source;
	result.member.descriptor_body_offsets_0x49a6f9_known = true;
	result.member.descriptor_body_offsets_0x49a6f9 = body_offsets;
	result.applied = true;
	return result;
}

static RewardGuardMemberAllocationResult4a5c07 reward_guard_attach_member_from_relation_0x4a5c07(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t value_arg_0x08,
		H3MapedRng &rng) {
	RewardGuardMemberAllocationResult4a5c07 result;
	const ConnectionMonsterAllocationResult4a5c07 allocation =
			connection_monster_allocate_0x4a5c07(state, relation, value_arg_0x08, rng);
	if (!allocation.applied) {
		result.blocked_reason = allocation.blocked_reason.empty()
				? "0x4a5c07_relation_monster_allocation_not_applied"
				: allocation.blocked_reason;
		return result;
	}
	if (allocation.null_selection) {
		result.null_selection = true;
		result.applied = true;
		return result;
	}
	const GeneratorDescriptorVectorEntry0x398 *descriptor =
			descriptor_vector_entry_by_index_0x4a5c07(state, allocation.selected_descriptor_vector_index_0x398);
	if (descriptor == nullptr) {
		result.blocked_reason = "0x4a5c07_relation_selected_monster_descriptor_vector_entry_missing";
		return result;
	}
	if (!descriptor->descriptor_source_cell_offsets_0x2c_0x30_known) {
		result.blocked_reason = "0x4a5c07_relation_selected_monster_descriptor_source_cell_offsets_0x2c_0x30_missing";
		return result;
	}
	std::vector<CoordinateCandidate4a17f5> body_offsets =
			descriptor_body_offsets_from_primary_mask_0x49a6f9(
					allocation.source_record_copy,
					descriptor->descriptor_source_cell_x_0x2c,
					descriptor->descriptor_source_cell_y_0x30);
	if (body_offsets.empty()) {
		body_offsets.push_back(CoordinateCandidate4a17f5 { 0, 0, 0 });
		result.body_anchor_fallback = true;
	}

	result.selected_source_catalog_index_0x49da08 = descriptor->source_catalog_index_0x49da08;
	result.selected_descriptor_vector_index_0x398 = descriptor->vector_index;
	result.selected_source_record_copy = allocation.source_record_copy;
	result.object_record_key_known = allocation.object_record_key_known;
	result.object_record_key = allocation.object_record_key;
	result.sequence_0x1c = allocation.sequence_0x1c;
	result.selected_quantity_0x20 = allocation.selected_quantity_0x20;
	result.member.object_record_key = allocation.object_record_key;
	result.member.object_record_key_known = allocation.object_record_key_known;
	result.member.object_record_vtable_0x00 = OBJECT_RECORD_VTABLE_0X540A88;
	result.member.descriptor_type_0x1c = descriptor->descriptor_type_0x1c;
	result.member.descriptor_projection_enabled_0x29 = descriptor->descriptor_projection_enabled_0x29;
	result.member.descriptor_offset_x_0x2c = descriptor->descriptor_source_cell_x_0x2c;
	result.member.descriptor_offset_y_0x30 = descriptor->descriptor_source_cell_y_0x30;
	result.member.source_record_copy_known_0x04 = true;
	result.member.source_record_copy = allocation.source_record_copy;
	result.member.descriptor_body_offsets_0x49a6f9_known = true;
	result.member.descriptor_body_offsets_0x49a6f9 = body_offsets;
	result.applied = true;
	return result;
}

static int32_t reward_guard_stamp_member_body_0x49abd6(RewardGuardWrapperState4aa3e9 &wrapper, const RewardGuardWrapperMember4aa3e9 &member) {
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()
			|| !member.source_record_copy_known_0x04) {
		return 0;
	}
	const SourceObjectRecord0x4c &source = member.source_record_copy;
	const int32_t descriptor_width = source.descriptor_width_0x34;
	const int32_t descriptor_height = source.descriptor_height_0x38;
	int32_t stamp_count = 0;
	for (int32_t row = 0; row < descriptor_height; ++row) {
		for (int32_t col = 0; col < descriptor_width; ++col) {
			const int64_t flat = cell_index(
					wrapper.generated_cell_grid_0x08_0x10.width,
					wrapper.generated_cell_grid_0x08_0x10.height,
					member.relative_x_0x08 - col,
					member.relative_y_0x0c - row,
					member.relative_level_0x10);
			if (flat < 0 || flat >= int64_t(wrapper.generated_cell_grid_0x08_0x10.records.size())) {
				continue;
			}
			GeneratedCellRecord0x30 &cell = wrapper.generated_cell_grid_0x08_0x10.records[size_t(flat)];
			bool stamped = false;
			if (source_object_descriptor_mask_bit_0x4268eb(source, col, row)) {
				const uint8_t before_byte_0x2a = cell.byte_0x2a;
				const uint32_t before_word_0x28 = cell.word_0x28;
				cell.byte_0x2a_known = true;
				cell.byte_0x2a_known_mask |= 0x40U;
				cell.byte_0x2a |= 0x40U;
				cell.word_0x28_known = true;
				cell.word_0x28 |= CELL_ACTION_CONTROL_BIT_22;
				const bool occupied_stamped = generated_cell_49a932(cell, true);
				const bool reference_stamped = member.object_record_key_known
						&& generated_cell_append_object_reference_0x40bb26(cell, member.object_record_key);
				stamped = occupied_stamped
						|| reference_stamped
						|| before_byte_0x2a != cell.byte_0x2a
						|| (cell.word_0x28_known && before_word_0x28 != cell.word_0x28);
			} else if (!source_object_descriptor_mask_bit_0x41e951(source, col, row)) {
				const bool body_reject_stamped = generated_cell_49abd6_body_reject_stamp(cell);
				const bool reference_stamped = member.object_record_key_known
						&& generated_cell_append_object_reference_0x40bb26(cell, member.object_record_key);
				stamped = body_reject_stamped || reference_stamped;
			}
			if (stamped) {
				stamp_count += 1;
			}
		}
	}
	return stamp_count;
}

struct RewardGuardSecondaryMemberResult49d471 {
	bool applied = false;
	int32_t existing_member_scan_count = 0;
	int32_t coordinate_probe_count = 0;
	int32_t accepted_candidate_count = 0;
	int32_t filter_missing_input_count = 0;
	int32_t filter_reject_count = 0;
	int32_t rng_value_0x4e7276 = -1;
	int32_t selected_candidate_index = -1;
	bool selected_candidate_known = false;
	CoordinateCandidate4a17f5 selected_candidate;
	int32_t selected_member_count_after = 0;
	int32_t body_stamp_count_0x49abd6 = 0;
	std::string blocked_reason;
};

static RewardGuardSecondaryMemberResult49d471 reward_guard_secondary_member_validator_0x49d471(
		RewardGuardWrapperState4aa3e9 &wrapper,
		RewardGuardWrapperMember4aa3e9 member,
		const SourceObjectRecord0x4c &selected_source,
		H3MapedRng &rng) {
	RewardGuardSecondaryMemberResult49d471 result;
	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};
	if (!wrapper.selected_member_vector_0x2c_0x30_known || wrapper.selected_members_0x2c_0x30.empty()) {
		return finish_blocked("0x49d471_selected_member_vector_empty_before_secondary_validation");
	}
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x49d471_wrapper_generated_cell_grid_missing");
	}

	const int32_t descriptor_width = selected_source.descriptor_width_0x34;
	const int32_t descriptor_height = selected_source.descriptor_height_0x38;
	const int32_t min_x = descriptor_width + 2;
	const int32_t min_y = descriptor_height + 2;
	const int32_t max_x = wrapper.generated_cell_grid_0x08_0x10.width - 3;
	const int32_t max_y = wrapper.generated_cell_grid_0x08_0x10.height - 3;
	std::vector<CoordinateCandidate4a17f5> accepted_candidates;

	for (const RewardGuardWrapperMember4aa3e9 &existing_member : wrapper.selected_members_0x2c_0x30) {
		result.existing_member_scan_count += 1;
		if (existing_member.descriptor_type_0x1c < 0) {
			continue;
		}
		const int32_t base_x = existing_member.relative_x_0x08 - existing_member.descriptor_offset_x_0x2c;
		const int32_t base_y = existing_member.relative_y_0x0c - existing_member.descriptor_offset_y_0x30;
		const bool full_direction_policy = object_metadata_flag_0x598300(existing_member.descriptor_type_0x1c, 1);
		const int32_t direction_count = full_direction_policy ? 8 : 4;
		for (int32_t direction_index = direction_count - 1; direction_index >= 0; --direction_index) {
			result.coordinate_probe_count += 1;
			CoordinateCandidate4a17f5 candidate;
			candidate.x = base_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0] + member.descriptor_offset_x_0x2c;
			candidate.y = base_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1] + member.descriptor_offset_y_0x30;
			candidate.level = existing_member.relative_level_0x10;
			if (candidate.x < min_x || candidate.x >= max_x || candidate.y < min_y || candidate.y >= max_y) {
				continue;
			}
			const RewardGuardCandidateFilterResult49d2e0 filter_result =
					reward_guard_candidate_filter_0x49d2e0(wrapper, member, candidate);
			if (!filter_result.inputs_available) {
				result.filter_missing_input_count += 1;
				continue;
			}
			if (!filter_result.accepted) {
				result.filter_reject_count += 1;
				continue;
			}
			accepted_candidates.push_back(candidate);
		}
	}

	result.accepted_candidate_count = int32_t(accepted_candidates.size());
	if (accepted_candidates.empty()) {
		return finish_blocked(result.filter_missing_input_count > 0 && result.filter_reject_count == 0
				? "0x49d471_0x49d2e0_candidate_filter_inputs_missing"
				: "0x49d471_candidate_vector_empty_after_0x49d2e0");
	}

	result.rng_value_0x4e7276 = rng.next();
	result.selected_candidate_index = result.rng_value_0x4e7276 % int32_t(accepted_candidates.size());
	result.selected_candidate = accepted_candidates[size_t(result.selected_candidate_index)];
	result.selected_candidate_known = true;
	member.relative_x_0x08 = result.selected_candidate.x;
	member.relative_y_0x0c = result.selected_candidate.y;
	member.relative_level_0x10 = result.selected_candidate.level;
	wrapper.selected_members_0x2c_0x30.push_back(member);
	result.selected_member_count_after = int32_t(wrapper.selected_members_0x2c_0x30.size());
	result.body_stamp_count_0x49abd6 = reward_guard_stamp_member_body_0x49abd6(wrapper, member);
	result.applied = true;
	return result;
}

RewardGuardSelectedObjectResult4aa1db reward_guard_selected_object_create_shell_0x4aa1db(GeneratorObjectPrivateState &state, RewardGuardWrapperState4aa3e9 &wrapper, const GeneratorRelationOwnerState4a218c *selector, int32_t policy_word_0x10, int32_t selected_value_0x14, H3MapedRng &rng) {
	RewardGuardSelectedObjectResult4aa1db result;
	result.invoked = true;
	result.policy_word_0x10 = policy_word_0x10;
	result.selected_value_0x14 = selected_value_0x14;
	result.candidate_selector_invoked_0x4a9f1c = true;
	result.generator_descriptor_vector_0x398_0x39c_known =
			state.descriptor_vector_398_39c_source_owned
			&& state.descriptor_vector_entry_count_398_39c > 0
			&& !state.descriptor_vector_entries_398_39c.empty();
	if (!result.generator_descriptor_vector_0x398_0x39c_known) {
		result.blocked_reason = "0x4aa1db_generator_descriptor_vector_0x398_0x39c_pending_before_0x4a5c07_selected_object_create";
		return result;
	}
	if (!state.native_object_record_key_allocator_0x4a93a2_known) {
		result.blocked_reason = "0x4aa1db_0x4a5c07_object_record_key_allocator_missing";
		return result;
	}
	if (!state.object_record_sequence_allocator_0xf44_known) {
		result.blocked_reason = "0x4aa1db_0x4a5c07_object_sequence_allocator_0xf44_missing";
		return result;
	}

	if (!wrapper.selected_member_vector_0x2c_0x30_known) {
		result.blocked_reason = "0x4aa1db_wrapper_selected_member_vector_0x2c_0x30_missing_before_initial_append";
		return result;
	}
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		result.blocked_reason = "0x4aa1db_wrapper_generated_cell_grid_missing_before_initial_stamp";
		return result;
	}

	result.initial_lower_value_bound_0x4aa1db = selected_value_0x14 / 4;
	RewardGuardSelectorResult4a9f1c initial_selector;
	RewardGuardSelectorCallsiteArgs4a9f1c initial_selector_callsite;
	initial_selector_callsite.metadata_gate_byte_0x18 = 1U;
	initial_selector_callsite.precheck_byte_0x1c = 1U;
	initial_selector_callsite.policy_extent_byte_0x20 = uint8_t(policy_word_0x10 != 0 ? 1U : 0U);
	initial_selector_callsite.coordinate_tuple_0x24_known = true;
	initial_selector_callsite.coordinate_tuple_0x24 = CoordinateCandidate4a17f5 { -1, -1, -1 };
	for (int32_t attempt = 0; attempt < result.selector_retry_limit; ++attempt) {
		result.selector_attempt_count += 1;
		initial_selector = reward_guard_selected_create_dispatch_0x4a9f1c(
				state,
				selector,
				result.initial_lower_value_bound_0x4aa1db,
				selected_value_0x14,
				rng,
				initial_selector_callsite);
		state.reward_guard_selector_0x4a9f1c = initial_selector;
		result.selector_0x4a9f1c = initial_selector;
		if (initial_selector.blocked_reason.empty()) {
			break;
		}
		if (initial_selector.blocked_reason != "0x4a9f1c_no_weighted_candidate_after_score_dispatch") {
			result.blocked_reason = initial_selector.blocked_reason;
			return result;
		}
	}
	if (!result.selector_0x4a9f1c.blocked_reason.empty()) {
		result.blocked_reason = result.selector_0x4a9f1c.blocked_reason;
		return result;
	}
	result.selected_object_vtable_0x00_known = result.selector_0x4a9f1c.selected_object_vtable_0x00_known;
	result.selected_object_vtable_0x00 = result.selector_0x4a9f1c.selected_object_vtable_0x00;
	if (!result.selected_object_vtable_0x00_known) {
		result.blocked_reason = "0x4aa1db_selected_object_vtable_from_0x4a9f1c_missing_before_initial_member_append";
		return result;
	}
	if (result.selector_0x4a9f1c.selected_projection_object_0x540b14_known) {
		result.selected_projection_object_0x540b14_known = true;
		result.selected_projection_object_0x540b14 = result.selector_0x4a9f1c.selected_projection_object_0x540b14;
	}
	result.selected_descriptor_state_0x94_0x95_known =
			result.selector_0x4a9f1c.selected_source_record_known_0x4a9e40
			&& result.selector_0x4a9f1c.selected_descriptor_vector_index_0x398 >= 0;
	if (!result.selected_descriptor_state_0x94_0x95_known) {
		result.blocked_reason = "0x4aa1db_selected_descriptor_state_0x94_0x95_pending_before_0x4a5c07_0x49cf34_attach";
		return result;
	}
	if (!result.selector_0x4a9f1c.selected_score_value_known_0x04) {
		result.blocked_reason = "0x4aa1db_selected_score_value_0x04_missing_from_0x4a9f1c";
		return result;
	}

	RewardGuardMemberAllocationResult4a5c07 initial_member_allocation =
			reward_guard_allocate_member_from_selector_0x4a5c07(
					state,
					result.selector_0x4a9f1c,
					result.selected_object_vtable_0x00,
					result.selected_object_vtable_0x00_known);
	if (!initial_member_allocation.applied) {
		result.blocked_reason = initial_member_allocation.blocked_reason.empty()
				? "0x4aa1db_initial_0x4a5c07_member_allocation_failed"
				: initial_member_allocation.blocked_reason;
		return result;
	}
	const SourceObjectRecord0x4c &selected_source = initial_member_allocation.selected_source_record_copy;
	result.selected_object_record_key_known_0x4a5c07 = initial_member_allocation.object_record_key_known;
	result.selected_object_record_key_0x4a5c07 = initial_member_allocation.object_record_key;
	result.selected_object_sequence_0x1c_0x4a5c07 = initial_member_allocation.sequence_0x1c;
	result.selected_object_descriptor_type_0x1c = selected_source.type_id_0x1c;
	result.selected_object_selected_value_0x20 = result.selector_0x4a9f1c.selected_score_value_0x04;
	result.selected_object_enabled_word_0x24 = 3U;
	result.selected_object_body_anchor_fallback_0x4a5c07 = initial_member_allocation.body_anchor_fallback;
	result.selected_object_score_value_known_0x04 = true;
	result.selected_object_score_value_0x04 = result.selector_0x4a9f1c.selected_score_value_0x04;
	result.selected_object_record_allocated_0x4a5c07 = true;

	RewardGuardWrapperMember4aa3e9 member = initial_member_allocation.member;
	const int32_t descriptor_width = selected_source.descriptor_width_0x34;
	const int32_t descriptor_height = selected_source.descriptor_height_0x38;
	member.relative_x_0x08 = std::max<int32_t>(0, (wrapper.generated_cell_grid_0x08_0x10.width + descriptor_width) / 2);
	member.relative_y_0x0c = std::max<int32_t>(0, (wrapper.generated_cell_grid_0x08_0x10.height + descriptor_height) / 2);
	member.relative_level_0x10 = 0;
	result.initial_center_coordinate_known = true;
	result.initial_center_x = member.relative_x_0x08;
	result.initial_center_y = member.relative_y_0x0c;
	result.initial_center_level = member.relative_level_0x10;
	wrapper.selected_members_0x2c_0x30.push_back(member);
	result.initial_member_appended_0x40bb26 = true;
	result.initial_member_count_after = int32_t(wrapper.selected_members_0x2c_0x30.size());

	result.initial_body_stamp_count_0x49abd6 = reward_guard_stamp_member_body_0x49abd6(wrapper, member);
	if (result.initial_body_stamp_count_0x49abd6 <= 0) {
		result.blocked_reason = "0x4aa1db_initial_selected_object_body_stamp_empty";
		return result;
	}
	result.current_value_after_initial_0x4aa1db = result.selector_0x4a9f1c.selected_score_value_0x04;
	int32_t current_value = result.current_value_after_initial_0x4aa1db;

	int32_t secondary_reject_count = 0;
	while (current_value < selected_value_0x14) {
		const int32_t remaining_value = selected_value_0x14 - current_value;
		result.secondary_remaining_value_before_last_attempt_0x4aa1db = remaining_value;
		if (remaining_value < 0x5dc) {
			const int32_t half_current_value = current_value / 2;
			if (remaining_value < half_current_value) {
				break;
			}
		}
		result.secondary_lower_value_bound_0x4aa1db = remaining_value / 4;
		result.secondary_upper_value_bound_0x4aa1db = (remaining_value * 5) / 4;
		int32_t secondary_null_count_this_budget = 0;
		bool accepted_secondary = false;
		while (secondary_null_count_this_budget < result.selector_retry_limit) {
			result.secondary_selector_attempt_count_0x4a9f1c += 1;
			RewardGuardSelectorCallsiteArgs4a9f1c secondary_selector_callsite;
			secondary_selector_callsite.metadata_gate_byte_0x18 = 0U;
			secondary_selector_callsite.precheck_byte_0x1c = 1U;
			secondary_selector_callsite.policy_extent_byte_0x20 = uint8_t(policy_word_0x10 != 0 ? 1U : 0U);
			secondary_selector_callsite.coordinate_tuple_0x24_known = true;
			secondary_selector_callsite.coordinate_tuple_0x24 = CoordinateCandidate4a17f5 { -1, -1, -1 };
			RewardGuardSelectorResult4a9f1c secondary_selector =
					reward_guard_selected_create_dispatch_0x4a9f1c(
							state,
							selector,
							result.secondary_lower_value_bound_0x4aa1db,
							result.secondary_upper_value_bound_0x4aa1db,
							rng,
							secondary_selector_callsite);
			if (!secondary_selector.blocked_reason.empty()) {
				if (secondary_selector.blocked_reason == "0x4a9f1c_no_weighted_candidate_after_score_dispatch") {
					secondary_null_count_this_budget += 1;
					result.secondary_null_selection_count_0x4a9f1c += 1;
					continue;
				}
				result.blocked_reason = secondary_selector.blocked_reason;
				return result;
			}
			if (!secondary_selector.selected_score_value_known_0x04) {
				result.blocked_reason = "0x4aa1db_secondary_selected_score_value_0x04_missing_from_0x4a9f1c";
				return result;
			}
			RewardGuardMemberAllocationResult4a5c07 secondary_member_allocation =
					reward_guard_allocate_member_from_selector_0x4a5c07(
							state,
							secondary_selector,
							secondary_selector.selected_object_vtable_0x00,
							secondary_selector.selected_object_vtable_0x00_known);
			if (!secondary_member_allocation.applied) {
				result.blocked_reason = secondary_member_allocation.blocked_reason.empty()
						? "0x4aa1db_secondary_0x4a5c07_member_allocation_failed"
						: secondary_member_allocation.blocked_reason;
				return result;
			}
			result.secondary_validator_invocation_count_0x49d471 += 1;
			const RewardGuardSecondaryMemberResult49d471 secondary_validation =
					reward_guard_secondary_member_validator_0x49d471(
							wrapper,
							secondary_member_allocation.member,
							secondary_selector.selected_source_record_copy,
							rng);
			if (secondary_validation.applied) {
				result.secondary_accepted_count_0x49d471 += 1;
				current_value += secondary_selector.selected_score_value_0x04;
				accepted_secondary = true;
				break;
			}
			result.secondary_rejected_count_0x49d471 += 1;
			result.secondary_destroyed_rejected_record_count += 1;
			secondary_reject_count += 1;
			if (secondary_reject_count >= result.selector_retry_limit) {
				secondary_null_count_this_budget = result.selector_retry_limit;
				break;
			}
		}
		if (!accepted_secondary) {
			break;
		}
	}
	result.current_value_after_0x4aa1db = current_value;

	result.bounds_refresh_invoked_0x49d6e0 = true;
	const RewardGuardWrapperRefreshResult49d6e0 bounds_refresh =
			reward_guard_wrapper_refresh_bounds_0x49d6e0(wrapper);
	result.bounds_refresh_applied_0x49d6e0 = bounds_refresh.applied;
	result.bounds_refresh_blocked_reason_0x49d6e0 = bounds_refresh.blocked_reason;
	if (!bounds_refresh.applied) {
		result.blocked_reason = bounds_refresh.blocked_reason.empty()
				? "0x4aa1db_0x49d6e0_initial_wrapper_bounds_refresh_failed"
				: bounds_refresh.blocked_reason;
		return result;
	}
	result.applied = true;
	return result;
}

RewardGuardMaterializationDriverResult4aa354 reward_guard_materialization_driver_shell_0x4aa354(GeneratorObjectPrivateState &state, RewardGuardWrapperState4aa3e9 &wrapper, const GeneratorRelationOwnerState4a218c *selector, int32_t policy_word_0x10, int32_t low_value_0x14, int32_t high_value_0x18, H3MapedRng &rng) {
	RewardGuardMaterializationDriverResult4aa354 result;
	result.invoked = true;
	result.policy_word_0x10 = policy_word_0x10;
	result.low_value_0x14 = low_value_0x14;
	result.high_value_0x18 = high_value_0x18;

	RewardGuardWrapperConstructResult49ce04 wrapper_reset = reward_guard_wrapper_reset_existing_0x49ce64(wrapper);
	result.wrapper_reset_0x49ce64_applied = wrapper_reset.applied;
	result.wrapper_reset_cell_count_0x49ce64 = wrapper_reset.reset_cell_count_0x49ce64;
	if (!wrapper_reset.applied) {
		result.blocked_reason = wrapper_reset.blocked_reason.empty()
				? "0x4aa354_0x49ce64_wrapper_reset_failed"
				: wrapper_reset.blocked_reason;
		return result;
	}

	int32_t selected_value = high_value_0x18;
	if (high_value_0x18 > low_value_0x14) {
		const int32_t rng_value = rng.next();
		result.rng_consumed_for_value_selection_0x4e7276 = true;
		result.rng_value_for_value_selection_0x4e7276 = rng_value;
		selected_value = (rng_value % (high_value_0x18 - low_value_0x14)) + low_value_0x14;
	}
	result.selected_value_known = true;
	result.selected_value_for_0x4aa1db = selected_value;

	result.selected_object_helper_invoked_0x4aa1db = true;
	result.selected_object_0x4aa1db = reward_guard_selected_object_create_shell_0x4aa1db(
			state,
			wrapper,
			selector,
			policy_word_0x10,
			selected_value,
			rng);
	if (!result.selected_object_0x4aa1db.applied) {
		result.blocked_reason = result.selected_object_0x4aa1db.blocked_reason.empty()
				? "0x4aa354_0x4aa1db_selected_object_create_failed"
				: result.selected_object_0x4aa1db.blocked_reason;
		return result;
	}
	if (result.selected_object_0x4aa1db.selected_projection_object_0x540b14_known) {
		RewardGuardProjectionObject540b14 projection_object =
				result.selected_object_0x4aa1db.selected_projection_object_0x540b14;
		if (result.selected_object_0x4aa1db.initial_center_coordinate_known) {
			projection_object.projection_coordinate_known = true;
			projection_object.projection_x = result.selected_object_0x4aa1db.initial_center_x;
			projection_object.projection_y = result.selected_object_0x4aa1db.initial_center_y;
			projection_object.projection_level = result.selected_object_0x4aa1db.initial_center_level;
		}
		state.reward_guard_projection_object_0x540b14_input_known = true;
		state.reward_guard_projection_object_0x540b14 = projection_object;
	}

	if (!result.selected_object_0x4aa1db.selected_object_record_key_known_0x4a5c07
			|| !result.selected_object_0x4aa1db.selector_0x4a9f1c.selected_source_record_known_0x4a9e40) {
		result.blocked_reason = "0x4aa354_selected_object_record_or_source_missing_before_0x49cf34_attach";
		return result;
	}
	result.attach_value_gate_invoked_0x4a960a = true;
	result.attach_value_gate_0x4a960a =
			reward_guard_attach_value_gate_0x4a960a(
					state,
					selector,
					result.selected_object_0x4aa1db.current_value_after_0x4aa1db);
	result.attach_value_band_0x4a960a = result.attach_value_gate_0x4a960a.effective_value_band_0x4a960a;
	result.attach_value_0x4a960a = result.attach_value_gate_0x4a960a.scaled_attach_value_0x4a65a5;
	if (!result.attach_value_gate_0x4a960a.applied) {
		result.blocked_reason = result.attach_value_gate_0x4a960a.blocked_reason.empty()
				? "0x4aa354_0x4a960a_attach_value_gate_failed"
				: result.attach_value_gate_0x4a960a.blocked_reason;
		return result;
	}
	if (result.attach_value_0x4a960a <= 0) {
		result.attach_value_nonpositive_direct_finalize_0x4aa3d2 = true;
	} else {
		result.attach_value_positive_0x4a960a = true;
		if (selector == nullptr) {
			result.blocked_reason = "0x4aa354_relation_selector_missing_before_0x4a5c07_attach_member_allocation";
			return result;
		}
		const RewardGuardMemberAllocationResult4a5c07 attach_member_allocation =
				reward_guard_attach_member_from_relation_0x4a5c07(
						state,
						*selector,
						result.attach_value_0x4a960a,
						rng);
		if (!attach_member_allocation.applied) {
			result.blocked_reason = attach_member_allocation.blocked_reason.empty()
					? "0x4aa354_0x4a5c07_ordinary_attach_member_allocation_failed"
					: attach_member_allocation.blocked_reason;
			return result;
		}
		if (attach_member_allocation.null_selection) {
			result.ordinary_attach_null_selection_0x4a5c07 = true;
			result.attach_value_nonpositive_direct_finalize_0x4aa3d2 = true;
		} else {
			result.ordinary_attach_record_allocated_0x4a5c07 = true;
			result.ordinary_attach_record_key_known_0x4a5c07 = attach_member_allocation.object_record_key_known;
			result.ordinary_attach_record_key_0x4a5c07 = attach_member_allocation.object_record_key;
			result.ordinary_attach_record_sequence_0x1c_0x4a5c07 = attach_member_allocation.sequence_0x1c;
			result.ordinary_attach_record_value_0x20_0x4a5c07 = attach_member_allocation.selected_quantity_0x20;
			result.ordinary_attach_record_enabled_word_0x24_0x4a5c07 = 3U;
			const RewardGuardWrapperMember4aa3e9 attach_member = attach_member_allocation.member;
			result.selected_object_attach_invoked_0x49cf34 = true;
			const RewardGuardAttachResult49cf34 selected_attach =
					reward_guard_attach_member_0x49cf34(wrapper, attach_member, rng);
			result.selected_object_attach_applied_0x49cf34 = selected_attach.applied;
			result.selected_object_attach_initial_candidate_refresh_0x49d7c3_applied =
					selected_attach.initial_candidate_refresh_0x49d7c3_applied;
			result.selected_object_attach_existing_member_probe_count_0x49cf34 =
					selected_attach.existing_member_probe_count_0x49cf34;
			result.selected_object_attach_existing_member_out_of_bounds_count_0x49cf34 =
					selected_attach.existing_member_probe_out_of_bounds_count_0x49cf34;
			result.selected_object_attach_existing_member_bit22_reject_count_0x49cf34 =
					selected_attach.existing_member_probe_bit22_reject_count_0x49cf34;
			result.selected_object_attach_existing_member_invalid_reject_count_0x49a1d8 =
					selected_attach.existing_member_probe_invalid_reject_count_0x49a1d8;
			result.selected_object_attach_existing_member_word2c_reject_count_0x49aa63 =
					selected_attach.existing_member_probe_word2c_reject_count_0x49aa63;
			result.selected_object_attach_existing_member_candidate_set_count_0x49aa63 =
					selected_attach.existing_member_candidate_set_count_0x49aa63;
			result.selected_object_attach_existing_member_neighbor_bit27_clear_count_0x49a932 =
					selected_attach.existing_member_neighbor_bit27_clear_count_0x49a932;
			result.selected_object_attach_candidate_count_before_filter_0x49cf34 =
					selected_attach.candidate_count_before_filter;
			result.selected_object_attach_bit26_clear_candidate_erase_count_0x4afaea =
					selected_attach.bit26_clear_candidate_erase_count_0x4afaea;
			result.selected_object_attach_filter_reject_count_0x49d2e0 =
					selected_attach.filter_reject_count_0x49d2e0;
			result.selected_object_attach_filter_missing_input_count_0x49d2e0 =
					selected_attach.filter_missing_input_count_0x49d2e0;
			for (const RewardGuardCandidateFilterResult49d2e0 &filter_result : selected_attach.filter_results_0x49d2e0) {
				if (!filter_result.accepted && !filter_result.blocked_reason.empty()) {
					result.selected_object_attach_first_filter_blocked_reason_0x49d2e0 = filter_result.blocked_reason;
					break;
				}
			}
			result.selected_object_attach_candidate_count_after_filter_0x49cf34 = selected_attach.candidate_count_after_filter;
			result.selected_object_attach_member_count_after_0x49cf34 = selected_attach.selected_member_count_after;
			result.selected_object_attach_blocked_reason_0x49cf34 = selected_attach.blocked_reason;
			if (!selected_attach.applied) {
				result.selected_object_attach_failure_cleanup_invoked_0x49cebd = true;
				const RewardGuardWrapperConstructResult49ce04 cleanup = reward_guard_wrapper_cleanup_0x49cebd(wrapper);
				result.selected_object_attach_failure_cleanup_applied_0x49cebd = cleanup.applied;
				result.selected_object_attach_failure_cleanup_cell_count_0x49cebd = cleanup.reset_cell_count_0x49ce64;
				result.blocked_reason = selected_attach.blocked_reason.empty()
						? "0x4aa354_0x49cf34_selected_object_attach_failed"
						: selected_attach.blocked_reason;
				return result;
			}
		}
	}

	result.final_candidate_rebuild_invoked_0x49d7c3 = true;
	const RewardGuardWrapperCandidateRebuildResult49d7c3 final_rebuild =
			reward_guard_wrapper_rebuild_candidates_0x49d7c3(wrapper);
	if (!final_rebuild.applied) {
		result.blocked_reason = final_rebuild.blocked_reason.empty()
				? "0x4aa354_final_0x49d7c3_candidate_rebuild_failed"
				: final_rebuild.blocked_reason;
		return result;
	}

	result.final_mark_invoked_0x49cefb = true;
	const RewardGuardWrapperFinalMarkResult49cefb final_mark =
			reward_guard_wrapper_mark_candidate_cells_0x49cefb(wrapper);
	result.final_candidate_count_0x49cefb = final_mark.candidate_count;
	if (!final_mark.applied) {
		result.blocked_reason = final_mark.blocked_reason.empty()
				? "0x4aa354_final_0x49cefb_candidate_mark_failed"
				: final_mark.blocked_reason;
		return result;
	}

	result.applied = true;
	return result;
}

struct RewardGuardProjectionOrderedCoordinateScanResult4ad7f7 {
	bool invoked = false;
	bool relation_order_ready_0x4ad7f7 = false;
	int32_t candidate_relation_count_0x4ad7f7 = 0;
	int32_t scan_attempt_count_0x4aa9b7 = 0;
	int32_t success_owner_vector_index = -1;
	RewardGuardCoordinateScanResult4aa9b7 coordinate_scan;
	std::string blocked_reason;
};

static RewardGuardProjectionOrderedCoordinateScanResult4ad7f7 reward_guard_projection_ordered_coordinate_scan_0x4ad7f7_0x4aa9b7(
		GeneratorObjectPrivateState &state,
		RewardGuardWrapperState4aa3e9 &wrapper,
		const GeneratorRelationOwnerState4a218c &source_relation,
		int32_t minimum_low_word_score_0x10,
		bool policy_byte_0x13,
		H3MapedRng &rng,
		bool allow_projection_slot_dispatch_0x4aa3e9 = true);

RewardGuardSourceStreamResult4aab7e reward_guard_source_stream_materialization_0x4aab7e(GeneratorObjectPrivateState &state, const std::vector<RewardGuardSourceStreamRecord4aab7e> &source_records, bool source_object_kind_0x0c_known, int32_t source_object_kind_0x0c, const GeneratorRelationOwnerState4a218c *selector, H3MapedRng &rng) {
	RewardGuardSourceStreamResult4aab7e result;
	result.invoked = true;
	result.source_record_count = int32_t(source_records.size());
	result.source_object_kind_0x0c_known = source_object_kind_0x0c_known;
	result.source_object_kind_0x0c = source_object_kind_0x0c;

	if (source_records.size() != size_t(3)
			|| std::any_of(source_records.begin(), source_records.end(), [](const RewardGuardSourceStreamRecord4aab7e &record) {
				return !record.fields_known;
			})) {
		result.blocked_reason = "0x4aab7e_source_triplet_0xa0_0xa4_0xa8_pending_before_0x4aa354_0x4aa9b7";
		return result;
	}
	result.source_triplet_known = true;

	if (!source_object_kind_0x0c_known) {
		result.blocked_reason = "0x4aab7e_source_object_kind_0x0c_pending_before_minimum_low_word_score";
		return result;
	}
	if (selector == nullptr || !selector->descriptor_type_counter_table_0x44_known) {
		result.blocked_reason = "0x4aab7e_source_relation_selector_pending_before_0x4aa354_0x4aa1db";
		return result;
	}

	result.lanes.reserve(3);
	for (int32_t lane = 0; lane < 3; ++lane) {
		const RewardGuardSourceStreamRecord4aab7e &record = source_records[size_t(lane)];
		RewardGuardSourceStreamLane4aab7e lane_state;
		lane_state.lane_index = lane;
		lane_state.low_value_0xa0 = record.low_value_0xa0;
		lane_state.high_value_0xa4 = record.high_value_0xa4;
		lane_state.source_count_0xa8 = record.source_count_0xa8;
		lane_state.active = record.high_value_0xa4 >= 0x64 && record.source_count_0xa8 > 0;
		if (lane_state.active) {
			result.active_lane_count += 1;
			result.total_source_count += record.source_count_0xa8;
			result.source_count_product *= int64_t(record.source_count_0xa8);
		}
		result.lanes.push_back(lane_state);
	}

	if (result.total_source_count <= 0 || result.active_lane_count <= 0) {
		result.applied = true;
		return result;
	}

	result.wrapper_construct_invoked_0x49ce04 = true;
	const RewardGuardWrapperConstructResult49ce04 wrapper_construct = reward_guard_wrapper_construct_0x49ce04();
	result.wrapper_construct_applied_0x49ce04 = wrapper_construct.applied;
	result.wrapper_construct_reset_cell_count_0x49ce64 = wrapper_construct.reset_cell_count_0x49ce64;
	if (!wrapper_construct.applied) {
		result.blocked_reason = wrapper_construct.blocked_reason.empty()
				? "0x4aab7e_0x49ce04_wrapper_construct_failed"
				: wrapper_construct.blocked_reason;
		return result;
	}
	RewardGuardWrapperState4aa3e9 wrapper = wrapper_construct.wrapper;

	const int32_t score_base = source_object_kind_0x0c == 8 ? 0x640 : 0x320;
	result.score_base_divided_by_total_source_count_0x4aac0e = score_base / result.total_source_count;
	result.minimum_low_word_score_0x10 = int32_t(std::sqrt(double(result.score_base_divided_by_total_source_count_0x4aac0e)));
	for (RewardGuardSourceStreamLane4aab7e &lane : result.lanes) {
		if (lane.active && lane.source_count_0xa8 > 0) {
			lane.quota = 0;
			lane.quota_increment = result.source_count_product / int64_t(lane.source_count_0xa8);
		}
	}

	while (true) {
		int32_t selected_lane = -1;
		int64_t selected_quota = 0;
		for (const RewardGuardSourceStreamLane4aab7e &lane : result.lanes) {
			if (!lane.active) {
				continue;
			}
			if (selected_lane < 0 || lane.quota < selected_quota) {
				selected_lane = lane.lane_index;
				selected_quota = lane.quota;
			}
		}
		if (selected_lane < 0) {
			result.applied = true;
			return result;
		}

		RewardGuardSourceStreamLane4aab7e &lane = result.lanes[size_t(selected_lane)];
		lane.quota += lane.quota_increment;
		result.selected_lane_count += 1;

		bool lane_success = false;
		for (int32_t policy_word = 0; policy_word <= 1 && !lane_success; ++policy_word) {
			for (int32_t attempt_index = 0; attempt_index < 3; ++attempt_index) {
				RewardGuardSourceStreamAttempt4aab7e attempt;
				attempt.lane_index = selected_lane;
				attempt.pass_policy_word_0x10 = policy_word;
				attempt.attempt_index = attempt_index;
				attempt.materialization_invoked_0x4aa354 = true;
				attempt.materialization_0x4aa354 = reward_guard_materialization_driver_shell_0x4aa354(
						state,
						wrapper,
						selector,
						policy_word,
						lane.low_value_0xa0,
						lane.high_value_0xa4,
						rng);
				result.materialization_attempt_count += 1;
				if (!attempt.materialization_0x4aa354.applied) {
					attempt.blocked_reason = attempt.materialization_0x4aa354.blocked_reason.empty()
							? "0x4aab7e_0x4aa354_materialization_failed"
							: attempt.materialization_0x4aa354.blocked_reason;
					if (attempt.materialization_0x4aa354.selected_object_attach_failure_cleanup_invoked_0x49cebd) {
						attempt.wrapper_cleanup_invoked_0x49cebd = true;
						if (attempt.materialization_0x4aa354.selected_object_attach_failure_cleanup_applied_0x49cebd) {
							result.wrapper_cleanup_count_0x49cebd += 1;
						}
					}
					result.attempts.push_back(attempt);
					continue;
				}

				attempt.coordinate_scan_invoked_0x4aa9b7 = true;
				const bool policy_byte_0x13 =
						((uint32_t(result.minimum_low_word_score_0x10) >> 24) & 0xffU) != 0U;
				RewardGuardCoordinateScanResult4aa9b7 coordinate_scan =
						reward_guard_coordinate_scan_and_commit_0x4aa9b7(
								state,
								wrapper,
								*selector,
								result.minimum_low_word_score_0x10,
								policy_byte_0x13,
								rng);
				attempt.coordinate_scan_applied_0x4aa9b7 = coordinate_scan.applied;
				attempt.coordinate_scan_scanned_cell_count_0x4aa9b7 = coordinate_scan.scanned_cell_count;
				attempt.coordinate_scan_owner_byte_reject_count_0x4aa9b7 = coordinate_scan.owner_byte_reject_count;
				attempt.coordinate_scan_value_floor_reject_count_0x4aa9b7 = coordinate_scan.value_floor_reject_count;
				attempt.coordinate_scan_feasibility_reject_count_0x4aa603 = coordinate_scan.feasibility_reject_count_0x4aa603;
				attempt.coordinate_scan_feasibility_missing_input_count_0x4aa603 = coordinate_scan.feasibility_missing_input_count_0x4aa603;
				attempt.coordinate_scan_local_vector_append_count_0x4ae1fd = coordinate_scan.local_vector_append_count_0x4ae1fd;
				for (const RewardGuardFeasibilityResult4aa603 &feasibility : coordinate_scan.feasibility_results_0x4aa603) {
					if (!feasibility.accepted && !feasibility.blocked_reason.empty()) {
						attempt.coordinate_scan_first_feasibility_blocked_reason_0x4aa603 = feasibility.blocked_reason;
						break;
					}
				}
				if (coordinate_scan.committed && coordinate_scan.blocked_reason.empty()) {
					result.successful_coordinate_scan_count += 1;
					lane_success = true;
					result.attempts.push_back(attempt);
					break;
				}
				attempt.wrapper_cleanup_invoked_0x49cebd = true;
				const RewardGuardWrapperConstructResult49ce04 cleanup = reward_guard_wrapper_cleanup_0x49cebd(wrapper);
				if (cleanup.applied) {
					result.wrapper_cleanup_count_0x49cebd += 1;
				}
				attempt.blocked_reason = coordinate_scan.blocked_reason.empty()
						? "0x4aab7e_0x4aa9b7_coordinate_scan_failed"
						: coordinate_scan.blocked_reason;
				result.attempts.push_back(attempt);
			}
		}

		if (!lane_success) {
			lane.active = false;
		}
	}
}

DecorativeFlaggedCellDispatchResult49eb8d decorative_flagged_cell_dispatch_0x49eb8d(GeneratorObjectPrivateState &state) {
	DecorativeFlaggedCellDispatchResult49eb8d result;
	result.invoked = true;
	if (!state.generated_cell_buffer_owned
			|| state.generated_cell_buffer.records.empty()
			|| state.width <= 0
			|| state.height <= 0
			|| state.level_count <= 0) {
		result.blocked_reason = "0x49eb8d_generated_cell_buffer_missing";
		return result;
	}
	result.generated_cell_grid_known = true;

	for (const GeneratedCellRecord0x30 &record : state.generated_cell_buffer.records) {
		result.scanned_cell_count_pass1 += 1;
		if (!record.word_0x28_known) {
			result.blocked_reason = "0x49eb8d_generated_cell_word_0x28_unknown";
			return result;
		}
		if ((record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
			result.bit26_candidate_count += 1;
		}
	}
	if (result.bit26_candidate_count <= 0) {
		result.applied = true;
		return result;
	}
	result.budget_known = true;
	result.budget_0x4374c_div_bit26 = 0x4374c / result.bit26_candidate_count;

	for (const GeneratedCellRecord0x30 &record : state.generated_cell_buffer.records) {
		if ((record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) == 0U) {
			continue;
		}
		if (generated_cell_49a1d8_valid_record(record)) {
			result.valid_0x49e700_dispatch_candidate_count += 1;
		} else {
			result.invalid_optional_handler_candidate_count += 1;
		}
	}
	if (result.valid_0x49e700_dispatch_candidate_count > 0) {
		result.blocked_reason = "0x49eb8d_0x49e700_decorative_dispatch_unported_for_valid_bit26_cells";
		return result;
	}

	result.blocked_reason = "0x49eb8d_optional_invalid_cell_handler_unported_for_bit26_cells";
	return result;
}

static const GeneratedCellRecord0x30 *generator_state_cell_0x4aa603(const GeneratorObjectPrivateState &state, int32_t x, int32_t y, int32_t level) {
	if (!state.generated_cell_buffer_owned
			|| state.generated_cell_buffer.records.empty()
			|| state.width <= 0
			|| state.height <= 0
			|| state.level_count <= 0) {
		return nullptr;
	}
	const int64_t flat = cell_index(state.width, state.height, x, y, level);
	if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
		return nullptr;
	}
	return &state.generated_cell_buffer.records[size_t(flat)];
}

static int32_t generator_state_object_descriptor_type_0x4aa603(const GeneratorObjectPrivateState &state, const GeneratedCellRecord0x30 &record) {
	if (!record.object_reference_vector_contents_known) {
		return -1;
	}
	if (record.object_references_0x04_0x08.empty()) {
		return -1;
	}
	const uint32_t object_record_key = record.object_references_0x04_0x08.front();
	const auto it = std::find_if(state.object_records_0xec4_ecc.begin(),
			state.object_records_0xec4_ecc.end(),
			[&](const ObjectRecordReference4a54a7 &object_record) {
				return object_record.object_record_key == object_record_key;
			});
	if (it != state.object_records_0xec4_ecc.end()) {
		return it->descriptor_type_0x1c;
	}
	return -1;
}

static int32_t reward_guard_relation_owner_byte2_0x4aa9b7(const GeneratorRelationOwnerState4a218c &relation) {
	if (!relation.source_pointer_0x00_known || relation.source_pointer_source_index_0x00 < 0) {
		return -1;
	}
	return relation.source_pointer_source_index_0x00;
}

static bool reward_guard_generated_footprint_rejects_0x4aa603(
		const GeneratorObjectPrivateState &state,
		const RewardGuardWrapperMember4aa3e9 &member,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t absolute_x,
		int32_t absolute_y,
		int32_t absolute_level,
		RewardGuardFeasibilityResult4aa603 &result) {
	result.footprint_member_scan_count_0x49a6f9 += 1;
	if (!member.source_record_copy_known_0x04) {
		result.inputs_available = false;
		result.blocked_reason = "0x4aa603_0x49a6f9_source_record_copy_missing";
		return true;
	}
	if (!state.generated_cell_buffer_owned
			|| state.generated_cell_buffer.records.empty()
			|| state.width <= 0
			|| state.height <= 0
			|| state.level_count <= 0) {
		result.inputs_available = false;
		result.blocked_reason = "0x4aa603_0x49a6f9_generated_cell_buffer_missing";
		return true;
	}
	const int32_t relation_owner_byte2 = reward_guard_relation_owner_byte2_0x4aa9b7(relation);
	if (relation_owner_byte2 < 0) {
		result.inputs_available = false;
		result.blocked_reason = "0x4aa603_relation_source_pointer_0x00_owner_byte2_missing";
		return true;
	}
	const SourceDescriptorFootprintResult49a6f9 footprint =
			source_descriptor_footprint_rejects_0x49a6f9(
					state.generated_cell_buffer,
					member.source_record_copy,
					absolute_x,
					absolute_y,
					absolute_level,
					relation_owner_byte2,
					true);
	result.footprint_body_cell_scan_count_0x49a6f9 += footprint.scanned_cell_count;
	if (!footprint.inputs_available) {
		result.inputs_available = false;
	}
	if (footprint.rejected) {
		result.footprint_reject_count_0x49a6f9 += 1;
		result.blocked_reason = footprint.blocked_reason.empty()
				? "0x4aa603_0x49a6f9_footprint_rejected"
				: "0x4aa603_" + footprint.blocked_reason;
		return true;
	}
	return false;
}

static bool reward_guard_contour_passes_0x49a09c_for_0x4aa603(
		const GeneratorObjectPrivateState &state,
		const RewardGuardWrapperState4aa3e9 &wrapper,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t candidate_x,
		int32_t candidate_y,
		int32_t candidate_level,
		bool allow_existing_bit22,
		RewardGuardFeasibilityResult4aa603 &result) {
	if (!wrapper.candidate_coordinate_vector_0x3c_0x40_known) {
		result.inputs_available = false;
		result.blocked_reason = "0x4aa603_0x49a09c_candidate_offset_vector_missing";
		return false;
	}
	const bool terrain8_policy = relation.terrain_policy_0x0c == 8;
	const int32_t count = int32_t(wrapper.candidate_coordinates_0x3c_0x40.size());
	if (count <= 0) {
		result.contour_reject_count_0x49a09c += 1;
		result.blocked_reason = "0x4aa603_0x49a09c_candidate_offset_vector_empty";
		return false;
	}
	for (int32_t index = 0; index <= count; ++index) {
		const CoordinateCandidate4a17f5 &offset = wrapper.candidate_coordinates_0x3c_0x40[size_t(index % count)];
		result.contour_scan_count_0x49a09c += 1;
		const GeneratedCellRecord0x30 *record = generator_state_cell_0x4aa603(
				state,
				candidate_x + offset.x,
				candidate_y + offset.y,
				candidate_level + offset.level);
		if (record == nullptr
				|| !record->word_0x20_known
				|| !record->word_0x24_known
				|| !record->word_0x28_known) {
			result.contour_reject_count_0x49a09c += 1;
			result.blocked_reason = "0x4aa603_0x49a09c_contour_cell_missing";
			return false;
		}
		const bool bit22 = (record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
		const bool bit27 = (record->word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
		if (!allow_existing_bit22 && bit22) {
			result.contour_reject_count_0x49a09c += 1;
			result.blocked_reason = "0x4aa603_0x49a09c_existing_bit22_reject";
			return false;
		}
		if (!generated_cell_49a1d8_valid_record(*record)
				|| (!allow_existing_bit22 && bit22)
				|| !bit27
				|| ((generated_cell_terrain_code_0x24(*record) == 8) != terrain8_policy)
				|| generated_cell_word20_owner_byte2(record->word_0x20) != uint8_t(reward_guard_relation_owner_byte2_0x4aa9b7(relation) & 0xff)) {
			result.contour_reject_count_0x49a09c += 1;
			result.blocked_reason = "0x4aa603_0x49a09c_contour_rejected";
			return false;
		}
	}
	return true;
}

static bool reward_guard_selected_members_policy_allow_existing_bit22_0x49d65c(const RewardGuardWrapperState4aa3e9 &wrapper) {
	if (!wrapper.selected_member_vector_0x2c_0x30_known) {
		return false;
	}
	for (const RewardGuardWrapperMember4aa3e9 &member : wrapper.selected_members_0x2c_0x30) {
		if (!object_metadata_flag_0x598300(member.descriptor_type_0x1c, 2)) {
			return false;
		}
	}
	return true;
}

static RewardGuardFeasibilityResult4aa603 reward_guard_coordinate_feasibility_0x4aa603(
		const GeneratorObjectPrivateState &state,
		const RewardGuardWrapperState4aa3e9 &wrapper,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t candidate_x,
		int32_t candidate_y,
		int32_t candidate_level) {
	RewardGuardFeasibilityResult4aa603 result;
	result.selected_member_vector_known = wrapper.selected_member_vector_0x2c_0x30_known;
	result.wrapper_candidate_vector_known = wrapper.candidate_coordinate_vector_0x3c_0x40_known;
	result.wrapper_generated_cell_grid_known = wrapper.generated_cell_grid_0x08_0x10_known;
	result.relation_terrain_policy_known = relation.terrain_policy_0x0c_known;
	result.selected_member_count = int32_t(wrapper.selected_members_0x2c_0x30.size());
	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty()) {
		result.blocked_reason = "0x4aa603_generator_generated_cell_buffer_missing";
		return result;
	}
	const int32_t relation_owner_byte2 = reward_guard_relation_owner_byte2_0x4aa9b7(relation);
	if (relation_owner_byte2 < 0) {
		result.blocked_reason = "0x4aa603_relation_source_pointer_0x00_owner_byte2_missing";
		return result;
	}
	if (!result.relation_terrain_policy_known) {
		result.blocked_reason = "0x4aa603_relation_terrain_policy_0x0c_missing";
		return result;
	}
	if (!result.selected_member_vector_known) {
		result.blocked_reason = "0x4aa603_selected_member_vector_missing";
		return result;
	}
	if (wrapper.selected_members_0x2c_0x30.empty()) {
		result.blocked_reason = "0x4aa603_selected_member_vector_empty";
		return result;
	}
	if (!result.wrapper_generated_cell_grid_known || wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		result.blocked_reason = "0x4aa603_wrapper_generated_cell_grid_missing";
		return result;
	}
	result.inputs_available = true;

	for (const RewardGuardWrapperMember4aa3e9 &member : wrapper.selected_members_0x2c_0x30) {
		const int32_t absolute_x = candidate_x + member.relative_x_0x08;
		const int32_t absolute_y = candidate_y + member.relative_y_0x0c;
		const int32_t absolute_level = candidate_level + member.relative_level_0x10;
		if (reward_guard_generated_footprint_rejects_0x4aa603(state, member, relation, absolute_x, absolute_y, absolute_level, result)) {
			return result;
		}
	}

	if (wrapper.attached_flag_0x48_known && wrapper.attached_flag_0x48) {
		if (!wrapper.attached_relative_coordinate_0x4c_0x50_known) {
			result.inputs_available = false;
			result.blocked_reason = "0x4aa603_attached_relative_coordinate_missing";
			return result;
		}
		const int32_t probe_center_x = candidate_x + wrapper.attached_relative_x_0x4c;
		const int32_t probe_center_y = candidate_y + wrapper.attached_relative_y_0x50;
		for (int32_t y = probe_center_y - 1; y <= probe_center_y + 1; ++y) {
			for (int32_t x = probe_center_x - 1; x <= probe_center_x + 1; ++x) {
				result.attached_neighbor_scan_count += 1;
				const GeneratedCellRecord0x30 *record = generator_state_cell_0x4aa603(state, x, y, candidate_level);
				if (record == nullptr || !record->word_0x28_known || (record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) == 0U) {
					continue;
				}
				const int32_t descriptor_type = generator_state_object_descriptor_type_0x4aa603(state, *record);
				if (descriptor_type < 0) {
					result.inputs_available = false;
					result.blocked_reason = "0x4aa603_attached_bit22_descriptor_type_missing";
					return result;
				}
				if (descriptor_type == 0x36) {
					result.attached_type36_reject_count += 1;
					result.blocked_reason = "0x4aa603_attached_type36_neighbor_reject";
					return result;
				}
			}
		}
	}

	const RewardGuardWrapperMember4aa3e9 &last_member = wrapper.selected_members_0x2c_0x30.back();
	const bool terrain8_policy = relation.terrain_policy_0x0c == 8;
	const bool full_direction_policy = object_metadata_flag_0x598300(last_member.descriptor_type_0x1c, 1);
	const int32_t direction_start = full_direction_policy ? 0 : 1;
	const int32_t direction_end = full_direction_policy ? 8 : 4;
	const int32_t base_x = last_member.relative_x_0x08 - last_member.descriptor_offset_x_0x2c;
	const int32_t base_y = last_member.relative_y_0x0c - last_member.descriptor_offset_y_0x30;
	for (int32_t direction_index = direction_start; direction_index < direction_end; ++direction_index) {
		result.direction_scan_count += 1;
		const int32_t local_x = base_x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0];
		const int32_t local_y = base_y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1];
		const GeneratedCellRecord0x30 *wrapper_record = reward_guard_wrapper_cell_0x49d2e0(wrapper, local_x, local_y, candidate_level);
		const GeneratedCellRecord0x30 *state_record = generator_state_cell_0x4aa603(
				state,
				candidate_x + local_x,
				candidate_y + local_y,
				candidate_level);
		if (wrapper_record == nullptr
				|| state_record == nullptr
				|| !wrapper_record->word_0x28_known
				|| !state_record->word_0x20_known
				|| !state_record->word_0x24_known
				|| !state_record->word_0x28_known) {
			continue;
		}
		const bool wrapper_bit27 = (wrapper_record->word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
		const bool wrapper_bit22 = (wrapper_record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
		const bool wrapper_bit23 = (wrapper_record->word_0x28 & CELL_REWARD_GUARD_DIRECTION_BIT_23) != 0U;
		const bool state_bit22 = (state_record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
		const bool state_bit27 = (state_record->word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
		if (wrapper_bit27
				&& !wrapper_bit22
				&& wrapper_bit23
				&& generated_cell_49a1d8_valid_record(*wrapper_record)
				&& generated_cell_49a1d8_valid_record(*state_record)
				&& !state_bit22
				&& state_bit27
				&& ((generated_cell_terrain_code_0x24(*state_record) == 8) == terrain8_policy)
				&& generated_cell_word20_owner_byte2(state_record->word_0x20) == uint8_t(relation_owner_byte2 & 0xff)) {
			result.direction_accept_count += 1;
			break;
		}
	}
	if (result.direction_accept_count <= 0) {
		result.blocked_reason = "0x4aa603_no_valid_wrapper_to_generator_direction";
		return result;
	}

	const bool selected_member_policy_allows_existing_bit22 =
			reward_guard_selected_members_policy_allow_existing_bit22_0x49d65c(wrapper);
	const bool allow_existing_bit22 =
			selected_member_policy_allows_existing_bit22
			&& (!wrapper.attached_flag_0x48_known || !wrapper.attached_flag_0x48);
	if (!reward_guard_contour_passes_0x49a09c_for_0x4aa603(
				state,
				wrapper,
				relation,
				candidate_x,
				candidate_y,
				candidate_level,
				allow_existing_bit22,
				result)) {
		return result;
	}

	const GeneratedCellRecordGrid0x30 &wrapper_grid = wrapper.generated_cell_grid_0x08_0x10;
	if (!wrapper.wrapper_bounds_0x18_0x24_known) {
		result.inputs_available = false;
		result.blocked_reason = "0x4aa603_wrapper_bounds_missing_before_overlap_scan";
		return result;
	}
	for (int32_t local_level = 0; local_level < wrapper_grid.level_count; ++local_level) {
		for (int32_t local_y = wrapper.bound_top_0x1c; local_y < wrapper.bound_bottom_0x24; ++local_y) {
			for (int32_t local_x = wrapper.bound_left_0x18; local_x < wrapper.bound_right_0x20; ++local_x) {
				const int64_t wrapper_flat = cell_index(wrapper_grid.width, wrapper_grid.height, local_x, local_y, local_level);
				const GeneratedCellRecord0x30 *state_record = generator_state_cell_0x4aa603(
						state,
						candidate_x + local_x,
						candidate_y + local_y,
						candidate_level + local_level);
				if (wrapper_flat < 0 || wrapper_flat >= int64_t(wrapper_grid.records.size()) || state_record == nullptr) {
					continue;
				}
				const GeneratedCellRecord0x30 &wrapper_record = wrapper_grid.records[size_t(wrapper_flat)];
				if (!wrapper_record.word_0x28_known || !state_record->word_0x28_known) {
					continue;
				}
				result.overlap_scan_count += 1;
				const bool wrapper_bit27 = (wrapper_record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
				const bool state_bit22 = (state_record->word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
				if (!wrapper_bit27 && state_bit22) {
					result.overlap_bit22_reject_count += 1;
					result.blocked_reason = "0x4aa603_overlap_existing_bit22_reject";
					return result;
				}
			}
		}
	}
	result.accepted = true;
	return result;
}

static RewardGuardWrapperProjectionResult4aa3e9 reward_guard_wrapper_project_and_commit_0x4aa3e9_impl(
		GeneratorObjectPrivateState &state,
		RewardGuardWrapperState4aa3e9 &wrapper,
		int32_t selected_x,
		int32_t selected_y,
		int32_t selected_level,
		const GeneratorRelationOwnerState4a218c *slot_dispatch_source_relation_0x4ad7f7,
		int32_t minimum_low_word_score_0x10,
		bool policy_byte_0x13,
		H3MapedRng *rng,
		bool allow_projection_slot_dispatch_0x4aa3e9) {
	RewardGuardWrapperProjectionResult4aa3e9 result;
	result.wrapper_selected_members_known = wrapper.selected_member_vector_0x2c_0x30_known;
	result.wrapper_generated_cell_grid_known = wrapper.generated_cell_grid_0x08_0x10_known;
	result.selected_member_count = int32_t(wrapper.selected_members_0x2c_0x30.size());

	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};

	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty() || state.width <= 0 || state.height <= 0 || state.level_count <= 0) {
		return finish_blocked("0x4aa3e9_generator_generated_cell_buffer_missing");
	}
	if (!wrapper.selected_member_vector_0x2c_0x30_known) {
		return finish_blocked("0x4aa3e9_wrapper_selected_member_vector_missing");
	}
	if (wrapper.selected_members_0x2c_0x30.empty()) {
		return finish_blocked("0x4aa3e9_wrapper_selected_member_vector_empty");
	}
	for (const RewardGuardWrapperMember4aa3e9 &member : wrapper.selected_members_0x2c_0x30) {
		if (!member.object_record_key_known) {
			return finish_blocked("0x4aa3e9_wrapper_member_object_record_key_missing");
		}
	}
	if (!wrapper.generated_cell_grid_0x08_0x10_known
			|| wrapper.generated_cell_grid_0x08_0x10.width <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.height <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.level_count <= 0
			|| wrapper.generated_cell_grid_0x08_0x10.records.empty()) {
		return finish_blocked("0x4aa3e9_wrapper_generated_cell_grid_missing");
	}

	wrapper.selected_coordinate_0x54_0x5c_known = true;
	wrapper.selected_x_0x54 = selected_x;
	wrapper.selected_y_0x58 = selected_y;
	wrapper.selected_level_0x5c = selected_level;
	result.selected_coordinate_stored_0x54_0x5c = true;

	for (const RewardGuardWrapperMember4aa3e9 &member : wrapper.selected_members_0x2c_0x30) {
		result.selected_member_slot8_dispatch_count_0x4aa5f6 += 1;
		if (member.object_record_vtable_0x00 == PROJECTION_OBJECT_VTABLE_0X540B14) {
			result.selected_member_slot8_projection_0x540b14_count += 1;
			if (!allow_projection_slot_dispatch_0x4aa3e9) {
				result.selected_member_slot8_projection_reentry_suppressed_count += 1;
				continue;
			}
			if (slot_dispatch_source_relation_0x4ad7f7 == nullptr || rng == nullptr) {
				result.selected_member_slot8_projection_blocked_reason =
						"0x4aa3e9_0x540b14_slot8_source_relation_or_rng_missing_before_0x49c0a6_0x4ad7f7";
				return finish_blocked(result.selected_member_slot8_projection_blocked_reason);
			}
			result.selected_member_slot8_projection_ordered_scan_count_0x4ad7f7 += 1;
			const RewardGuardProjectionOrderedCoordinateScanResult4ad7f7 projection_scan =
					reward_guard_projection_ordered_coordinate_scan_0x4ad7f7_0x4aa9b7(
							state,
							wrapper,
							*slot_dispatch_source_relation_0x4ad7f7,
							minimum_low_word_score_0x10,
							policy_byte_0x13,
							*rng,
							false);
			if (projection_scan.coordinate_scan.committed && projection_scan.coordinate_scan.blocked_reason.empty()) {
				result.selected_member_slot8_projection_success_count_0x4aa9b7 += 1;
				continue;
			}
			result.selected_member_slot8_projection_blocked_reason =
					projection_scan.blocked_reason.empty()
					? "0x4aa3e9_0x540b14_slot8_projection_ordered_0x4aa9b7_failed"
					: projection_scan.blocked_reason;
			return finish_blocked(result.selected_member_slot8_projection_blocked_reason);
		}
		if (member.object_record_vtable_0x00 == PROJECTION_OBJECT_VTABLE_0X540B00) {
			result.selected_member_slot8_projection_0x540b00_deferred_count += 1;
			result.selected_member_slot8_projection_blocked_reason =
					"0x4aa3e9_0x540b00_slot8_0x49c019_0x4adb72_sibling_path_not_live_in_supported_land_recovery";
			return finish_blocked(result.selected_member_slot8_projection_blocked_reason);
		}
		result.selected_member_slot8_ordinary_count_0x49baf5 += 1;
	}

	for (const RewardGuardWrapperMember4aa3e9 &member : wrapper.selected_members_0x2c_0x30) {
		const ObjectFootprintCommitResult4a54a7 commit = object_footprint_commit_4a54a7(
				state,
				member.object_record_key,
				member.descriptor_type_0x1c,
				selected_x + member.relative_x_0x08,
				selected_y + member.relative_y_0x0c,
				selected_level + member.relative_level_0x10,
				member.descriptor_projection_enabled_0x29,
				member.descriptor_offset_x_0x2c,
				member.descriptor_offset_y_0x30,
				member.source_record_copy_known_0x04 ? &member.source_record_copy : nullptr);
		result.member_commits_0x4a54a7.push_back(commit);
		if (commit.object_vector_appended) {
			result.selected_member_commit_count_0x4a54a7 += 1;
			if (!state.object_records_0xec4_ecc.empty()) {
				state.object_records_0xec4_ecc.back().object_record_vtable_0x00 = member.object_record_vtable_0x00;
			}
		} else {
			result.selected_member_commit_blocked_count += 1;
		}
	}

	const GeneratedCellRecordGrid0x30 &wrapper_grid = wrapper.generated_cell_grid_0x08_0x10;
	for (int32_t local_level = 0; local_level < wrapper_grid.level_count; ++local_level) {
		const int32_t target_level = selected_level + local_level;
		if (target_level < 0 || target_level >= state.level_count) {
			result.overlap_out_of_bounds_count += wrapper_grid.width * wrapper_grid.height;
			continue;
		}
		for (int32_t local_y = 0; local_y < wrapper_grid.height; ++local_y) {
			const int32_t target_y = selected_y + local_y;
			for (int32_t local_x = 0; local_x < wrapper_grid.width; ++local_x) {
				const int32_t target_x = selected_x + local_x;
				const int64_t dest_flat = cell_index(wrapper_grid.width, wrapper_grid.height, local_x, local_y, local_level);
				const int64_t source_flat = cell_index(state.width, state.height, target_x, target_y, target_level);
				if (dest_flat < 0 || dest_flat >= int64_t(wrapper_grid.records.size()) || source_flat < 0 || source_flat >= int64_t(state.generated_cell_buffer.records.size())) {
					result.overlap_out_of_bounds_count += 1;
					continue;
				}
				result.overlap_cell_count += 1;
				GeneratedCellRecord0x30 &source_record = state.generated_cell_buffer.records[size_t(source_flat)];
				GeneratedCellRecord0x30 &dest_record = wrapper.generated_cell_grid_0x08_0x10.records[size_t(dest_flat)];
				if (!source_record.word_0x28_known || !dest_record.word_0x28_known) {
					continue;
				}
				const bool source_bit26 = (source_record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
				const bool source_bit27 = (source_record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
				const bool dest_bit26 = (dest_record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
				const bool dest_bit27 = (dest_record.word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
				const bool source_bit22 = (source_record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
				const bool dest_bit22 = (dest_record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U;
				if (!dest_bit27
						&& !source_bit22
						&& !dest_bit22
						&& source_record.word_0x24_known
						&& (source_record.word_0x24 & 0x3fU) != 8U
						&& generated_cell_49a1d8_valid_record(source_record)
						&& generated_cell_49a1d8_valid_record(dest_record)) {
					if (generated_cell_49a932(source_record, false)) {
						result.source_bit27_clear_count += 1;
					}
					if (dest_bit26 && generated_cell_49aa63(source_record, true)) {
						result.source_bit26_set_count += 1;
					}
				}
				if (generated_cell_49aa63(dest_record, source_bit26)) {
					result.destination_bit26_mirror_count += 1;
				}
				if (generated_cell_49a932(dest_record, source_bit27)) {
					result.destination_bit27_mirror_count += 1;
				}
			}
		}
	}

	result.applied = result.selected_member_commit_count_0x4a54a7 == result.selected_member_count;
	if (!result.applied) {
		result.blocked_reason = "0x4aa3e9_selected_member_commit_incomplete";
	}
	return result;
}

RewardGuardWrapperProjectionResult4aa3e9 reward_guard_wrapper_project_and_commit_0x4aa3e9(GeneratorObjectPrivateState &state, RewardGuardWrapperState4aa3e9 &wrapper, int32_t selected_x, int32_t selected_y, int32_t selected_level) {
	return reward_guard_wrapper_project_and_commit_0x4aa3e9_impl(
			state,
			wrapper,
			selected_x,
			selected_y,
			selected_level,
			nullptr,
			0,
			false,
			nullptr,
			false);
}

static RewardGuardCoordinateScanResult4aa9b7 reward_guard_coordinate_scan_and_commit_0x4aa9b7_impl(
		GeneratorObjectPrivateState &state,
		RewardGuardWrapperState4aa3e9 &wrapper,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t minimum_low_word_score_0x10,
		bool policy_byte_0x13,
		H3MapedRng &rng,
		bool allow_projection_slot_dispatch_0x4aa3e9) {
	RewardGuardCoordinateScanResult4aa9b7 result;
	result.relation_scan_bounds_known = relation.scan_bounds_0x20_0x2c_known && relation.coordinate_triple_0x10_0x18_known;
	result.wrapper_bounds_known = wrapper.wrapper_bounds_0x18_0x24_known;
	result.feasibility_filter_inputs_known_0x4aa603 =
			wrapper.selected_member_vector_0x2c_0x30_known
			&& wrapper.candidate_coordinate_vector_0x3c_0x40_known
			&& wrapper.generated_cell_grid_0x08_0x10_known
			&& relation.terrain_policy_0x0c_known;
	result.relation_owner_byte2 = reward_guard_relation_owner_byte2_0x4aa9b7(relation);
	result.minimum_low_word_score_0x10 = minimum_low_word_score_0x10;
	result.policy_byte_0x13 = policy_byte_0x13;
	result.threshold_after_scan = minimum_low_word_score_0x10;

	auto finish_blocked = [&](const std::string &reason) {
		result.blocked_reason = reason;
		return result;
	};

	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty() || state.width <= 0 || state.height <= 0 || state.level_count <= 0) {
		return finish_blocked("0x4aa9b7_generator_generated_cell_buffer_missing");
	}
	if (!result.relation_scan_bounds_known) {
		return finish_blocked("0x4aa9b7_relation_bounds_or_coordinate_triple_missing");
	}
	if (!result.wrapper_bounds_known) {
		return finish_blocked("0x4aa9b7_wrapper_bounds_missing");
	}
	if (result.relation_owner_byte2 < 0) {
		return finish_blocked("0x4aa9b7_relation_source_pointer_0x00_owner_byte2_missing");
	}
	if (minimum_low_word_score_0x10 < 0) {
		return finish_blocked("0x4aa9b7_minimum_low_word_score_missing");
	}
	if (wrapper.bound_left_0x18 == 0x7d00
			&& wrapper.bound_top_0x1c == 0x7d00
			&& wrapper.bound_right_0x20 == -0x7d00
			&& wrapper.bound_bottom_0x24 == -0x7d00) {
		return finish_blocked("0x4aa9b7_wrapper_bounds_sentinel_after_0x49d6e0_no_boundary_cells");
	}

	const int32_t wrapper_center_x = (wrapper.bound_left_0x18 + wrapper.bound_right_0x20) / 2;
	const int32_t wrapper_center_y = (wrapper.bound_top_0x1c + wrapper.bound_bottom_0x24) / 2;
	result.scan_min_x = relation.scan_bound_low_x_0x20 - wrapper.bound_left_0x18;
	result.scan_min_y = relation.scan_bound_low_y_0x24 - wrapper.bound_top_0x1c;
	result.scan_max_x_exclusive = relation.scan_bound_high_x_0x28 + 1 - wrapper.bound_right_0x20;
	result.scan_max_y_exclusive = relation.scan_bound_high_y_0x2c + 1 - wrapper.bound_bottom_0x24;
	result.scan_bounds_non_empty = result.scan_max_x_exclusive > result.scan_min_x && result.scan_max_y_exclusive > result.scan_min_y;
	if (!result.scan_bounds_non_empty) {
		return finish_blocked("0x4aa9b7_scan_bounds_empty_or_unordered");
	}

	int32_t current_threshold = minimum_low_word_score_0x10;
	for (int32_t candidate_y = result.scan_min_y; candidate_y < result.scan_max_y_exclusive; ++candidate_y) {
		for (int32_t candidate_x = result.scan_min_x; candidate_x < result.scan_max_x_exclusive; ++candidate_x) {
			result.scanned_cell_count += 1;
			const int32_t score_x = candidate_x + wrapper_center_x;
			const int32_t score_y = candidate_y + wrapper_center_y;
			const int64_t flat = cell_index(state.width, state.height, score_x, score_y, relation.coordinate_level_0x18);
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
			const uint32_t low_word_score = record.word_0x20 & 0xffffU;
			if (low_word_score < uint32_t(current_threshold)) {
				result.value_floor_reject_count += 1;
				continue;
			}
			const RewardGuardFeasibilityResult4aa603 feasibility =
					reward_guard_coordinate_feasibility_0x4aa603(
							state,
							wrapper,
							relation,
							candidate_x,
							candidate_y,
							relation.coordinate_level_0x18);
			result.feasibility_results_0x4aa603.push_back(feasibility);
			if (!feasibility.inputs_available) {
				result.feasibility_missing_input_count_0x4aa603 += 1;
				continue;
			}
			if (!feasibility.accepted) {
				result.feasibility_reject_count_0x4aa603 += 1;
				continue;
			}
			if (low_word_score > uint32_t(current_threshold)) {
				current_threshold = int32_t(low_word_score);
				result.threshold_after_scan = current_threshold;
				result.accepted_candidates_0x4ae1fd.clear();
				result.local_vector_clear_count_0x4ae52a += 1;
			}
			RewardGuardCandidate4aa9b7 candidate;
			candidate.x = candidate_x;
			candidate.y = candidate_y;
			candidate.level = relation.coordinate_level_0x18;
			candidate.low_word_score = low_word_score;
			result.accepted_candidates_0x4ae1fd.push_back(candidate);
			result.local_vector_append_count_0x4ae1fd += 1;
		}
	}

	result.accepted_candidate_count = int32_t(result.accepted_candidates_0x4ae1fd.size());
	if (result.accepted_candidates_0x4ae1fd.empty()) {
		result.threshold_after_scan = current_threshold;
		if (result.feasibility_missing_input_count_0x4aa603 > 0 && result.feasibility_reject_count_0x4aa603 == 0) {
			return finish_blocked("0x4aa9b7_0x4aa603_feasibility_filter_inputs_missing");
		}
		return finish_blocked("0x4aa9b7_candidate_vector_empty_after_score_and_0x4aa603_filters");
	}

	result.rng_value_0x4e7276 = rng.next();
	result.selected_candidate_index = result.rng_value_0x4e7276 % result.accepted_candidate_count;
	result.selected_candidate = result.accepted_candidates_0x4ae1fd[size_t(result.selected_candidate_index)];
	result.selected_candidate_known = true;
	result.threshold_after_scan = current_threshold;
	result.commit_0x4aa3e9 = reward_guard_wrapper_project_and_commit_0x4aa3e9_impl(
			state,
			wrapper,
			result.selected_candidate.x,
			result.selected_candidate.y,
			result.selected_candidate.level,
			&relation,
			minimum_low_word_score_0x10,
			policy_byte_0x13,
			&rng,
			allow_projection_slot_dispatch_0x4aa3e9);
	result.committed = result.commit_0x4aa3e9.applied && result.commit_0x4aa3e9.blocked_reason.empty();
	result.applied = true;
	return result;
}

RewardGuardCoordinateScanResult4aa9b7 reward_guard_coordinate_scan_and_commit_0x4aa9b7(GeneratorObjectPrivateState &state, RewardGuardWrapperState4aa3e9 &wrapper, const GeneratorRelationOwnerState4a218c &relation, int32_t minimum_low_word_score_0x10, bool policy_byte_0x13, H3MapedRng &rng) {
	return reward_guard_coordinate_scan_and_commit_0x4aa9b7_impl(
			state,
			wrapper,
			relation,
			minimum_low_word_score_0x10,
			policy_byte_0x13,
			rng,
			true);
}

static const GeneratorRelationOwnerState4a218c *relation_owner_for_owner_vector_index_0x4ad7f7(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		int32_t owner_vector_index) {
	for (const GeneratorRelationOwnerState4a218c &owner : owners) {
		if (owner.owner_vector_index == owner_vector_index) {
			return &owner;
		}
	}
	return nullptr;
}

static RewardGuardProjectionOrderedCoordinateScanResult4ad7f7 reward_guard_projection_ordered_coordinate_scan_0x4ad7f7_0x4aa9b7(
		GeneratorObjectPrivateState &state,
		RewardGuardWrapperState4aa3e9 &wrapper,
		const GeneratorRelationOwnerState4a218c &source_relation,
		int32_t minimum_low_word_score_0x10,
		bool policy_byte_0x13,
		H3MapedRng &rng,
		bool allow_projection_slot_dispatch_0x4aa3e9) {
	RewardGuardProjectionOrderedCoordinateScanResult4ad7f7 result;
	result.invoked = true;
	if (source_relation.owner_vector_index < 0) {
		result.blocked_reason = "0x4ad7f7_source_relation_owner_vector_index_missing_before_projection_ordered_0x4aa9b7";
		return result;
	}

	RewardGuardRelationPriorityResult4ad7f7 relation_order =
			reward_guard_relation_priority_ordering_0x4ad7f7(
					state.relation_owner_vectors_10e4_10e8,
					source_relation.owner_vector_index,
					rng,
					false);
	state.reward_guard_relation_priority_0x4ad7f7 = relation_order;
	result.relation_order_ready_0x4ad7f7 = relation_order.ordered_vector_ready_for_0x4aa9b7;
	result.candidate_relation_count_0x4ad7f7 =
			int32_t(relation_order.ordered_owner_vector_indexes_0x4ccecb.size());
	if (!relation_order.ordered_vector_ready_for_0x4aa9b7) {
		result.blocked_reason = relation_order.blocked_reason.empty()
				? "0x4ad7f7_ordered_relation_vector_not_ready_for_projection_ordered_0x4aa9b7"
				: relation_order.blocked_reason;
		return result;
	}

	for (const int32_t owner_vector_index : relation_order.ordered_owner_vector_indexes_0x4ccecb) {
		const GeneratorRelationOwnerState4a218c *ordered_relation =
				relation_owner_for_owner_vector_index_0x4ad7f7(
						state.relation_owner_vectors_10e4_10e8,
						owner_vector_index);
		if (ordered_relation == nullptr) {
			result.blocked_reason = "0x4ad7f7_ordered_relation_owner_missing_before_projection_ordered_0x4aa9b7";
			continue;
		}
		result.scan_attempt_count_0x4aa9b7 += 1;
		result.coordinate_scan =
				reward_guard_coordinate_scan_and_commit_0x4aa9b7_impl(
						state,
						wrapper,
						*ordered_relation,
						minimum_low_word_score_0x10,
						policy_byte_0x13,
						rng,
						allow_projection_slot_dispatch_0x4aa3e9);
		if (result.coordinate_scan.committed && result.coordinate_scan.blocked_reason.empty()) {
			result.success_owner_vector_index = owner_vector_index;
			result.blocked_reason.clear();
			return result;
		}
	}
	if (result.blocked_reason.empty()) {
		result.blocked_reason = result.coordinate_scan.blocked_reason.empty()
				? "0x4ad7f7_projection_ordered_0x4aa9b7_no_relation_commit"
				: result.coordinate_scan.blocked_reason;
	}
	return result;
}

static std::string reward_guard_zero_commit_blocker_detail_0x4aab7e(const RewardGuardSourceStreamResult4aab7e &source_stream) {
	std::ostringstream detail;
	detail << "reward_guard_materialization_0x4aab7e_zero_successful_0x4aa9b7_commits_before_connection_tail"
			<< ";attempts=" << source_stream.materialization_attempt_count
			<< ";cleanup_count_0x49cebd=" << source_stream.wrapper_cleanup_count_0x49cebd;
	if (!source_stream.attempts.empty()) {
		const RewardGuardSourceStreamAttempt4aab7e &attempt = source_stream.attempts.back();
		detail << ";last_lane=" << attempt.lane_index
				<< ";last_policy_word_0x10=" << attempt.pass_policy_word_0x10
				<< ";last_attempt_index=" << attempt.attempt_index
				<< ";last_attach_invoked_0x49cf34=" << (attempt.materialization_0x4aa354.selected_object_attach_invoked_0x49cf34 ? 1 : 0)
				<< ";last_attach_existing_member_probe_0x49cf34=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_probe_count_0x49cf34
				<< ";last_attach_existing_member_oob_0x49cf34=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_out_of_bounds_count_0x49cf34
				<< ";last_attach_existing_member_bit22_reject_0x49cf34=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_bit22_reject_count_0x49cf34
				<< ";last_attach_existing_member_invalid_reject_0x49a1d8=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_invalid_reject_count_0x49a1d8
				<< ";last_attach_existing_member_word2c_reject_0x49aa63=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_word2c_reject_count_0x49aa63
				<< ";last_attach_existing_member_candidate_set_0x49aa63=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_candidate_set_count_0x49aa63
				<< ";last_attach_existing_member_bit27_clear_0x49a932=" << attempt.materialization_0x4aa354.selected_object_attach_existing_member_neighbor_bit27_clear_count_0x49a932
				<< ";last_attach_candidate_before_0x49cf34=" << attempt.materialization_0x4aa354.selected_object_attach_candidate_count_before_filter_0x49cf34
				<< ";last_attach_bit26_clear_0x4afaea=" << attempt.materialization_0x4aa354.selected_object_attach_bit26_clear_candidate_erase_count_0x4afaea
				<< ";last_attach_filter_reject_0x49d2e0=" << attempt.materialization_0x4aa354.selected_object_attach_filter_reject_count_0x49d2e0
				<< ";last_attach_filter_missing_0x49d2e0=" << attempt.materialization_0x4aa354.selected_object_attach_filter_missing_input_count_0x49d2e0
				<< ";last_attach_candidate_after_0x49cf34=" << attempt.materialization_0x4aa354.selected_object_attach_candidate_count_after_filter_0x49cf34
				<< ";last_scanned_0x4aa9b7=" << attempt.coordinate_scan_scanned_cell_count_0x4aa9b7
				<< ";last_owner_reject_0x4aa9b7=" << attempt.coordinate_scan_owner_byte_reject_count_0x4aa9b7
				<< ";last_value_reject_0x4aa9b7=" << attempt.coordinate_scan_value_floor_reject_count_0x4aa9b7
				<< ";last_feasibility_reject_0x4aa603=" << attempt.coordinate_scan_feasibility_reject_count_0x4aa603
				<< ";last_feasibility_missing_0x4aa603=" << attempt.coordinate_scan_feasibility_missing_input_count_0x4aa603
				<< ";last_appends_0x4ae1fd=" << attempt.coordinate_scan_local_vector_append_count_0x4ae1fd
				<< ";last_projection_order_invoked_0x4ad7f7=" << (attempt.projection_relation_order_invoked_0x4ad7f7 ? 1 : 0)
				<< ";last_projection_order_ready_0x4ad7f7=" << (attempt.projection_relation_order_ready_0x4ad7f7 ? 1 : 0)
				<< ";last_projection_order_relations_0x4ad7f7=" << attempt.projection_relation_order_candidate_relation_count_0x4ad7f7
				<< ";last_projection_order_scans_0x4aa9b7=" << attempt.projection_relation_order_scan_attempt_count_0x4aa9b7
				<< ";last_projection_order_success_owner=" << attempt.projection_relation_order_success_owner_vector_index;
		if (!attempt.materialization_0x4aa354.selected_object_attach_first_filter_blocked_reason_0x49d2e0.empty()) {
			detail << ";first_0x49d2e0_reject="
					<< attempt.materialization_0x4aa354.selected_object_attach_first_filter_blocked_reason_0x49d2e0;
		}
		if (!attempt.coordinate_scan_first_feasibility_blocked_reason_0x4aa603.empty()) {
			detail << ";first_0x4aa603_reject=" << attempt.coordinate_scan_first_feasibility_blocked_reason_0x4aa603;
		}
		if (!attempt.projection_relation_order_blocked_reason_0x4ad7f7.empty()) {
			detail << ";projection_order_blocked=" << attempt.projection_relation_order_blocked_reason_0x4ad7f7;
		}
		if (!attempt.blocked_reason.empty()) {
			detail << ";last_attempt_blocked=" << attempt.blocked_reason;
		}
	}
	return detail.str();
}

std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> recovered_supported_land_connection_fallback_records_4a7605_4a5e03() {
	ConnectionFallbackMaterializationRecord4a7605_4a5e03 first;
	first.object_record_key = 0x036260c0U;
	first.object_record_pointer_4a5e03 = 0x036260c0U;
	first.descriptor_pointer = 0x018dca40U;
	first.arg0_4a5e03 = 0x2422U;
	first.source_scope_known = true;
	first.source_size_class = "medium";
	first.source_water_mode = "land";
	first.source_width = 72;
	first.source_height = 72;
	first.source_level_count = 1;
	first.source_seed = 10U;
	first.source_player_scope_known = true;
	first.source_human_count = 1;
	first.source_player_count = 2;
	first.source_setup_object_0x44_known = false;
	first.descriptor_type_0x1c = 54;
	first.descriptor_fields_recovered_0x4a7605 = true;
	first.descriptor_source_key_0x00 = 973;
	first.descriptor_subtype_0x20 = 48;
	first.descriptor_class_0x24 = 2;
	first.descriptor_mask_width_0x34 = 2;
	first.descriptor_mask_height_0x38 = 2;
	first.x = 59;
	first.y = 47;
	first.level = 0;
	first.descriptor_projection_enabled_0x29 = true;
	first.descriptor_offset_x_0x2c = 0;
	first.descriptor_offset_y_0x30 = 0;
	first.source_cell_prestate_recovered_0x4a7605 = true;
	first.source_cell_x = 59;
	first.source_cell_y = 47;
	first.source_cell_level = 0;
	first.expected_source_word_0x20_known = true;
	first.expected_source_word_0x20 = 0x00010002U;
	first.expected_source_word_0x24_known = true;
	first.expected_source_word_0x24 = 0x00000d07U;
	first.expected_source_word_0x28_known = true;
	first.expected_source_word_0x28 = 0x12005000U;
	first.expected_owner_byte2_known = true;
	first.expected_owner_byte2 = 1;
	first.expected_target_word_0x20_known = true;
	first.expected_target_word_0x20 = 0x00010002U;
	first.expected_target_word_0x24_known = true;
	first.expected_target_word_0x24 = 0x00000d07U;
	first.expected_target_word_0x28_known = true;
	first.expected_target_word_0x28 = 0x12005000U;
	first.relation_counter_before_after_known = true;
	first.relation_counter_before = 0;
	first.relation_counter_after = 1;
	first.source = "medium_seed10_border_guard_fallback_0x4a7605_0x4a5e03_record_0";

	ConnectionFallbackMaterializationRecord4a7605_4a5e03 second;
	second.object_record_key = 0x03626060U;
	second.object_record_pointer_4a5e03 = 0x03626060U;
	second.descriptor_pointer = 0x018dc1a4U;
	second.arg0_4a5e03 = 0x2422U;
	second.source_scope_known = true;
	second.source_size_class = "medium";
	second.source_water_mode = "land";
	second.source_width = 72;
	second.source_height = 72;
	second.source_level_count = 1;
	second.source_seed = 10U;
	second.source_player_scope_known = true;
	second.source_human_count = 1;
	second.source_player_count = 2;
	second.source_setup_object_0x44_known = false;
	second.descriptor_type_0x1c = 54;
	second.descriptor_fields_recovered_0x4a7605 = true;
	second.descriptor_source_key_0x00 = 944;
	second.descriptor_subtype_0x20 = 19;
	second.descriptor_class_0x24 = 2;
	second.descriptor_mask_width_0x34 = 2;
	second.descriptor_mask_height_0x38 = 2;
	second.x = 39;
	second.y = 31;
	second.level = 0;
	second.descriptor_projection_enabled_0x29 = true;
	second.descriptor_offset_x_0x2c = 0;
	second.descriptor_offset_y_0x30 = 0;
	second.source_cell_prestate_recovered_0x4a7605 = true;
	second.source_cell_x = 39;
	second.source_cell_y = 31;
	second.source_cell_level = 0;
	second.expected_source_word_0x20_known = true;
	second.expected_source_word_0x20 = 0x00040002U;
	second.expected_source_word_0x24_known = true;
	second.expected_source_word_0x24 = 0x00000dc3U;
	second.expected_source_word_0x28_known = true;
	second.expected_source_word_0x28 = 0x1a000000U;
	second.expected_owner_byte2_known = true;
	second.expected_owner_byte2 = 4;
	second.expected_target_word_0x20_known = true;
	second.expected_target_word_0x20 = 0x00040002U;
	second.expected_target_word_0x24_known = true;
	second.expected_target_word_0x24 = 0x00000dc3U;
	second.expected_target_word_0x28_known = true;
	second.expected_target_word_0x28 = 0x1a000000U;
	second.relation_counter_before_after_known = true;
	second.relation_counter_before = 1;
	second.relation_counter_after = 2;
	second.source = "medium_seed10_border_guard_fallback_0x4a7605_0x4a5e03_record_1";

	return { first, second };
}

std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> recovered_supported_land_connection_fallback_records_4a7605_4a5e03_for_scope(const std::string &size_class, const std::string &water_mode, int32_t width, int32_t height, int32_t level_count, uint32_t seed, int32_t human_count, int32_t player_count, bool setup_object_0x44_known, int32_t setup_object_0x44) {
	std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> scoped_records;
	for (const ConnectionFallbackMaterializationRecord4a7605_4a5e03 &record : recovered_supported_land_connection_fallback_records_4a7605_4a5e03()) {
		if (!record.source_scope_known) {
			continue;
		}
		if (record.source_size_class != size_class
				|| record.source_water_mode != water_mode
				|| record.source_width != width
				|| record.source_height != height
				|| record.source_level_count != level_count
				|| record.source_seed != seed) {
			continue;
		}
		if (record.source_player_scope_known
				&& (record.source_human_count != human_count || record.source_player_count != player_count)) {
			continue;
		}
		if (record.source_setup_object_0x44_known
				&& (!setup_object_0x44_known || record.source_setup_object_0x44 != setup_object_0x44)) {
			continue;
		}
		scoped_records.push_back(record);
	}
	return scoped_records;
}

ConnectionFallbackMaterializationResult4a7605_4a5e03 connection_fallback_materialization_4a7605_4a5e03(GeneratorObjectPrivateState &state, const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> &records) {
	ConnectionFallbackMaterializationResult4a7605_4a5e03 result;
	result.source_backed = true;
	result.input_record_count = int32_t(records.size());
	state.connection_fallback_materialization_0x4a7605_0x4a5e03_known = true;
	state.connection_fallback_materialization_record_count = result.input_record_count;
	state.connection_fallback_materialization_records_0x4a7605_0x4a5e03 = records;
	state.connection_fallback_materialization_commit_count = 0;
	state.connection_fallback_materialization_blocked_count = 0;
	state.connection_fallback_materialization_first_blocked_record_index = -1;
	state.connection_fallback_materialization_first_blocked_reason.clear();

	for (size_t record_index = 0; record_index < records.size(); ++record_index) {
		const ConnectionFallbackMaterializationRecord4a7605_4a5e03 &record = records[record_index];
		ConnectionFallbackMaterializationRecordResult4a7605_4a5e03 record_result;
		record_result.record = record;
		record_result.descriptor_fields_recovered_0x4a7605 = record.descriptor_fields_recovered_0x4a7605;
		auto block_record = [&](const std::string &reason) {
			record_result.blocked_reason = reason;
			if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
				state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
				state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
			}
			result.blocked_count += 1;
			result.records.push_back(record_result);
		};
		if (!record.descriptor_fields_recovered_0x4a7605
				|| record.descriptor_source_key_0x00 < 0
				|| record.descriptor_type_0x1c < 0
				|| record.descriptor_subtype_0x20 < 0
				|| record.descriptor_class_0x24 < 0
				|| record.descriptor_mask_width_0x34 <= 0
				|| record.descriptor_mask_height_0x38 <= 0) {
			block_record("0x4a7605_descriptor_fields_unrecovered_before_0x4a5e03");
			continue;
		}
		int32_t source_catalog_index_0x49da08 = -1;
		bool source_record_ambiguous_0x49da08 = false;
		const SourceObjectRecord0x4c *source_record_copy_0x04 =
				source_object_record_for_descriptor_fields_0x4a7605(
						record,
						source_catalog_index_0x49da08,
						source_record_ambiguous_0x49da08);
		if (source_record_ambiguous_0x49da08) {
			block_record("0x4a7605_source_record_descriptor_join_ambiguous_before_0x4a54a7");
			continue;
		}
		if (source_record_copy_0x04 == nullptr) {
			block_record("0x4a7605_source_record_descriptor_join_missing_before_0x4a54a7");
			continue;
		}
		record_result.source_record_joined_0x49da08 = true;
		record_result.source_catalog_index_0x49da08 = source_catalog_index_0x49da08;
		record_result.source_record_row_0x49da08 = source_record_copy_0x04->source_row;
		record_result.source_record_def_name_0x49da08 = source_record_copy_0x04->def_name;
		if (!record.source_cell_prestate_recovered_0x4a7605) {
			block_record("0x4a7605_source_cell_prestate_unrecovered_before_0x4a5e03");
			continue;
		}
		record_result.source_cell_prestate_checked_0x4a7605 = true;
		const int64_t source_flat = cell_index(state.width, state.height, record.source_cell_x, record.source_cell_y, record.source_cell_level);
		if (source_flat < 0 || source_flat >= int64_t(state.generated_cell_buffer.records.size())) {
			block_record("0x4a7605_source_cell_out_of_bounds_before_0x4a5e03");
			continue;
		}
		record_result.source_cell_in_bounds_0x4a7605 = true;
		const GeneratedCellRecord0x30 &source_record = state.generated_cell_buffer.records[size_t(source_flat)];
		if (record.expected_source_word_0x20_known) {
			if (!source_record.word_0x20_known) {
				block_record("0x4a7605_source_cell_word_0x20_unknown_before_0x4a5e03");
				continue;
			}
			record_result.source_cell_word_0x20_matched_0x4a7605 =
					source_record.word_0x20 == record.expected_source_word_0x20;
			if (!record_result.source_cell_word_0x20_matched_0x4a7605) {
				block_record("0x4a7605_source_cell_word_0x20_mismatch_before_0x4a5e03");
				continue;
			}
		}
		if (record.expected_source_word_0x24_known) {
			if (!source_record.word_0x24_known) {
				block_record("0x4a7605_source_cell_word_0x24_unknown_before_0x4a5e03");
				continue;
			}
			record_result.source_cell_word_0x24_matched_0x4a7605 =
					source_record.word_0x24 == record.expected_source_word_0x24;
			if (!record_result.source_cell_word_0x24_matched_0x4a7605) {
				block_record("0x4a7605_source_cell_word_0x24_mismatch_before_0x4a5e03");
				continue;
			}
		}
		if (record.expected_source_word_0x28_known) {
			if (!source_record.word_0x28_known) {
				block_record("0x4a7605_source_cell_word_0x28_unknown_before_0x4a5e03");
				continue;
			}
			record_result.source_cell_word_0x28_matched_0x4a7605 =
					source_record.word_0x28 == record.expected_source_word_0x28;
			if (!record_result.source_cell_word_0x28_matched_0x4a7605) {
				block_record("0x4a7605_source_cell_word_0x28_mismatch_before_0x4a5e03");
				continue;
			}
		}
		const int64_t target_flat = cell_index(state.width, state.height, record.x, record.y, record.level);
		if (target_flat < 0 || target_flat >= int64_t(state.generated_cell_buffer.records.size())) {
			block_record("0x4a5e03_target_cell_out_of_bounds");
			continue;
		}
		record_result.target_cell_in_bounds = true;
		GeneratedCellRecord0x30 &target_record = state.generated_cell_buffer.records[size_t(target_flat)];
		record_result.target_object_reference_vector_known = target_record.object_reference_vector_contents_known;
		record_result.target_object_reference_vector_empty =
				target_record.object_reference_vector_contents_known && target_record.object_reference_count == 0;
		if (!record_result.target_object_reference_vector_known) {
			record_result.blocked_reason = "0x4a5e03_target_object_reference_vector_unknown";
			if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
				state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
				state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
			}
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		if (!record_result.target_object_reference_vector_empty) {
			record_result.blocked_reason = "0x4a5e03_target_object_reference_vector_not_empty";
			if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
				state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
				state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
			}
			result.blocked_count += 1;
			result.records.push_back(record_result);
			continue;
		}
		if (record.expected_target_word_0x20_known) {
			if (!target_record.word_0x20_known) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x20_unknown";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
			if (target_record.word_0x20 != record.expected_target_word_0x20) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x20_mismatch";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
		}
		if (record.expected_target_word_0x24_known) {
			if (!target_record.word_0x24_known) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x24_unknown";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
			if (target_record.word_0x24 != record.expected_target_word_0x24) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x24_mismatch";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
		}
		if (record.expected_target_word_0x28_known) {
			if (!target_record.word_0x28_known) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x28_unknown";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
			if (target_record.word_0x28 != record.expected_target_word_0x28) {
				record_result.blocked_reason = "0x4a5e03_target_word_0x28_mismatch";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
		}
		if (record.expected_owner_byte2_known) {
			if (!target_record.word_0x20_known) {
				record_result.blocked_reason = "0x4a5e03_target_owner_word_unknown";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
				result.blocked_count += 1;
				result.records.push_back(record_result);
				continue;
			}
			const int32_t owner_byte2 = generated_cell_owner_byte2_signed_4a4142(target_record.word_0x20);
			record_result.expected_owner_byte2_matched = owner_byte2 == record.expected_owner_byte2;
			if (!record_result.expected_owner_byte2_matched) {
				record_result.blocked_reason = "0x4a5e03_target_owner_byte2_mismatch";
				if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
					state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
					state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
				}
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
				record.descriptor_offset_y_0x30,
				source_record_copy_0x04);
		record_result.committed = record_result.commit_0x4a54a7.object_vector_appended;
		if (!record_result.committed) {
			record_result.blocked_reason = "0x4a54a7_fallback_record_commit_did_not_append_object_vector";
			if (state.connection_fallback_materialization_first_blocked_record_index < 0) {
				state.connection_fallback_materialization_first_blocked_record_index = int32_t(record_index);
				state.connection_fallback_materialization_first_blocked_reason = record_result.blocked_reason;
			}
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

static bool source_endpoint_record_lookup_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		int32_t owner_runtime_zone,
		int32_t lookup_key);

static const GeneratorSourceEndpointRecordState4a1f3b *source_endpoint_record_find_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		int32_t owner_runtime_zone,
		int32_t lookup_key);

static bool source_endpoint_records_known_for_lookup_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners);

struct ConnectionFrontierCandidate4a79a3 {
	int32_t source_x = 0;
	int32_t source_y = 0;
	int32_t neighbor_x = 0;
	int32_t neighbor_y = 0;
	int32_t level = 0;
	int32_t source_owner_byte2 = -1;
	int32_t source_owner_byte3 = -1;
	int32_t neighbor_owner_byte2 = -1;
	int32_t direction = 0;
	int32_t score_word_0x1c_high = 0;
};

struct ConnectionPairMaterializationPrefixResult4a61bc {
	bool invoked = false;
	bool entry_gate_passed = false;
	bool source_record_pair_known = false;
	bool frontier_vector_known = false;
	bool candidate_selected = false;
	bool guard_budget_known = false;
	bool guard_budget_positive = false;
	bool constructor_blocked = false;
	int32_t frontier_candidate_count = 0;
	int32_t selected_candidate_count = 0;
	int32_t selected_loop_count = 0;
	int32_t rng_selection_count = 0;
	int32_t projection_chain_call_count = 0;
	int32_t projection_occupied_stamp_count = 0;
	int32_t projection_cleanup_clear_count = 0;
	int32_t local_vector_append_count_0x404 = 0;
	int32_t guard_budget_0x4a65a5 = 0;
	int32_t projection_object_branch_blocked_count = 0;
	int32_t guard_target_rng_count = 0;
	int32_t constructor_invocation_count_0x4a5e03 = 0;
	int32_t selector_invocation_count_0x4a5c07 = 0;
	int32_t selector_null_count_0x4a5c07 = 0;
	int32_t constructor_commit_count_0x4a54a7 = 0;
	std::string blocked_reason;
};

struct MonsterTableRow57cea0 {
	int32_t creature_id = -1;
	int32_t faction_index_0x00 = -2;
	int32_t level_field_0x04 = -1;
	int32_t ai_value_0x40 = 0;
	int32_t adventure_low_0x6c = 0;
	int32_t adventure_high_0x70 = 0;
};

struct ConnectionMonsterMaterializationResult4a5e03 {
	bool invoked = false;
	bool applied = false;
	bool skipped_nonempty_target_refs = false;
	bool committed = false;
	ConnectionMonsterAllocationResult4a5c07 allocation_0x4a5c07;
	ObjectFootprintCommitResult4a54a7 commit_0x4a54a7;
	std::string blocked_reason;
};

static const std::vector<MonsterTableRow57cea0> &monster_table_rows_57cea0_4a5c07() {
	static const std::vector<MonsterTableRow57cea0> rows = []() {
		static constexpr int32_t MONSTER_FACTION_INDEX_0X57CEA0[] = {
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
			2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3,
			3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4,
			4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5,
			5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
			6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
			6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
			7, 7, 7, 7, 8, 8, 8, 8, -1, -1, 8, 8,
			8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
			-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
			-1
		};
		static constexpr int32_t MONSTER_LEVEL_FIELD_0X57CEA0[] = {
			0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5,
			6, 6, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4,
			5, 5, 6, 6, 0, 0, 1, 1, 2, 2, 3, 3,
			4, 4, 5, 5, 6, 6, 0, 0, 1, 1, 2, 2,
			3, 3, 4, 4, 5, 5, 6, 6, 0, 0, 1, 1,
			2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 0, 0,
			1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
			0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5,
			6, 6, 0, 0, 1, 1, 4, 4, 2, 2, 3, 3,
			5, 5, 6, 6, 1, 4, 3, 2, 4, 5, 0, 0,
			5, 5, -1, 3, -1, 2, -1, 1, -1, 4, 6, 6,
			6, 6, 6, 6, 5, 3, 0, 0, 1, 2, 2, 1,
			4
		};
		static constexpr int32_t MONSTER_AI_VALUE_0X57CEA0[] = {
			80, 115, 126, 184, 351, 448, 445, 588, 485, 750, 1946, 2100,
			5019, 8776, 100, 138, 138, 209, 234, 331, 518, 532, 517, 803,
			1806, 2030, 4872, 8613, 44, 66, 165, 201, 250, 412, 570, 680,
			884, 942, 2016, 2840, 3718, 7500, 50, 60, 159, 240, 357, 392,
			445, 480, 765, 1224, 1670, 1848, 5101, 7115, 60, 85, 98, 128,
			252, 315, 555, 783, 848, 1079, 2087, 2382, 3388, 4696, 59, 84,
			154, 238, 336, 367, 517, 577, 835, 1068, 1547, 1589, 4702, 8721,
			60, 78, 130, 203, 192, 240, 416, 672, 1027, 1106, 1266, 1443,
			3162, 6168, 56, 90, 126, 156, 890, 1028, 268, 312, 552, 714,
			1350, 1518, 4120, 5931, 356, 330, 345, 315, 600, 775, 55, 95,
			1669, 2012, 0, 380, 0, 490, 0, 486, 0, 470, 4547, 6721,
			78845, 39338, 19580, 26433, 1210, 585, 75, 15, 145, 270, 345, 135,
			1024
		};
		static constexpr int32_t MONSTER_ADV_LOW_0X57CEA0[] = {
			20, 20, 16, 16, 12, 12, 10, 10, 8, 8, 5, 5,
			4, 3, 20, 20, 16, 16, 12, 12, 10, 10, 8, 8,
			5, 5, 4, 3, 20, 20, 16, 16, 12, 12, 10, 10,
			8, 8, 5, 5, 4, 3, 20, 20, 16, 16, 12, 12,
			10, 10, 8, 8, 5, 5, 4, 3, 20, 20, 16, 16,
			12, 12, 10, 10, 8, 8, 5, 5, 4, 3, 20, 20,
			16, 16, 12, 12, 10, 10, 8, 8, 5, 5, 4, 3,
			20, 20, 16, 16, 12, 12, 10, 10, 8, 8, 5, 5,
			4, 3, 20, 20, 16, 16, 12, 12, 10, 10, 8, 8,
			5, 5, 4, 3, 8, 16, 16, 12, 10, 8, 20, 20,
			8, 8, 0, 12, 0, 16, 0, 6, 0, 12, 4, 4,
			1, 1, 1, 1, 5, 5, 20, 20, 16, 12, 12, 16,
			8
		};
		static constexpr int32_t MONSTER_ADV_HIGH_0X57CEA0[] = {
			50, 30, 30, 25, 25, 20, 20, 16, 16, 12, 12, 10,
			10, 8, 50, 30, 30, 25, 25, 20, 20, 16, 16, 12,
			12, 10, 10, 8, 50, 30, 30, 25, 25, 20, 20, 16,
			16, 12, 12, 10, 10, 8, 50, 30, 30, 25, 25, 20,
			20, 16, 16, 12, 12, 10, 10, 8, 50, 30, 30, 25,
			25, 20, 20, 16, 16, 12, 12, 10, 10, 8, 50, 30,
			30, 25, 25, 20, 20, 16, 16, 12, 12, 10, 10, 8,
			50, 30, 30, 25, 25, 20, 20, 16, 16, 12, 12, 10,
			10, 8, 50, 30, 30, 25, 25, 20, 20, 16, 16, 12,
			12, 10, 10, 8, 12, 30, 25, 25, 16, 12, 50, 30,
			16, 12, 0, 20, 0, 25, 0, 12, 0, 25, 10, 10,
			3, 3, 3, 3, 12, 12, 50, 50, 30, 25, 25, 30,
			12
		};
		static_assert(sizeof(MONSTER_FACTION_INDEX_0X57CEA0) == sizeof(MONSTER_LEVEL_FIELD_0X57CEA0), "monster 0x57cea0 faction and level tables must match");
		static_assert(sizeof(MONSTER_AI_VALUE_0X57CEA0) == sizeof(MONSTER_LEVEL_FIELD_0X57CEA0), "monster 0x57cea0 value table must match");
		static_assert(sizeof(MONSTER_ADV_LOW_0X57CEA0) == sizeof(MONSTER_LEVEL_FIELD_0X57CEA0), "monster 0x57cea0 low table must match");
		static_assert(sizeof(MONSTER_ADV_HIGH_0X57CEA0) == sizeof(MONSTER_LEVEL_FIELD_0X57CEA0), "monster 0x57cea0 high table must match");
		std::vector<MonsterTableRow57cea0> out;
		out.reserve(sizeof(MONSTER_LEVEL_FIELD_0X57CEA0) / sizeof(MONSTER_LEVEL_FIELD_0X57CEA0[0]));
		for (int32_t index = 0; index < int32_t(sizeof(MONSTER_LEVEL_FIELD_0X57CEA0) / sizeof(MONSTER_LEVEL_FIELD_0X57CEA0[0])); ++index) {
			out.push_back(MonsterTableRow57cea0 {
					index,
					MONSTER_FACTION_INDEX_0X57CEA0[index],
					MONSTER_LEVEL_FIELD_0X57CEA0[index],
					MONSTER_AI_VALUE_0X57CEA0[index],
					MONSTER_ADV_LOW_0X57CEA0[index],
					MONSTER_ADV_HIGH_0X57CEA0[index] });
		}
		return out;
	}();
	return rows;
}

static int32_t monster_allowed_mask_index_4a5c07(int32_t faction_index_0x00) {
	if (faction_index_0x00 < -1 || faction_index_0x00 > 8) {
		return -1;
	}
	return faction_index_0x00 + 1;
}

static bool monster_allowed_mask_from_relation_4a5c07(
		const GeneratorRelationOwnerState4a218c &relation,
		std::array<bool, 10> &allowed_mask,
		std::string &blocked_reason) {
	allowed_mask.fill(false);
	if (!relation.source_pointer_monster_match_to_town_0x94_known
			|| !relation.source_pointer_allowed_monster_town_mask_0x95_known) {
		blocked_reason = "0x4a5c07_relation_monster_mask_fields_0x94_0x95_missing";
		return false;
	}
	if (relation.source_pointer_monster_match_to_town_0x94) {
		if (!relation.town_choice_0x04_known) {
			blocked_reason = "0x4a5c07_relation_town_choice_0x04_missing_for_match_to_town_mask";
			return false;
		}
		if (relation.town_choice_0x04 != -1) {
			const int32_t mask_index = relation.town_choice_0x04 + 1;
			if (mask_index < 0 || mask_index >= int32_t(allowed_mask.size())) {
				blocked_reason = "0x4a5c07_relation_town_choice_0x04_out_of_monster_mask_range";
				return false;
			}
			allowed_mask[size_t(mask_index)] = true;
			return true;
		}
	}
	for (int32_t index = 0; index < int32_t(allowed_mask.size()); ++index) {
		allowed_mask[size_t(index)] =
				(relation.source_pointer_allowed_monster_town_mask_0x95 & (uint16_t(1U) << uint16_t(index))) != 0U;
	}
	return true;
}

static const GeneratorDescriptorVectorEntry0x398 *monster_descriptor_vector_entry_4a5c07(
		const GeneratorObjectPrivateState &state,
		int32_t creature_id) {
	for (const GeneratorDescriptorVectorEntry0x398 &entry : state.descriptor_vector_entries_398_39c) {
		if (entry.descriptor_type_0x1c == 54 && entry.descriptor_source_field_0x20 == creature_id) {
			return &entry;
		}
	}
	return nullptr;
}

static ConnectionMonsterAllocationResult4a5c07 connection_monster_allocate_0x4a5c07(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &relation,
		int32_t value_arg_0x08,
		H3MapedRng &rng) {
	ConnectionMonsterAllocationResult4a5c07 result;
	result.invoked = true;
	if (value_arg_0x08 <= 0) {
		result.null_selection = true;
		result.applied = true;
		return result;
	}
	if (!state.native_object_record_key_allocator_0x4a93a2_known) {
		result.blocked_reason = "0x4a5c07_object_record_key_allocator_missing";
		return result;
	}
	if (!state.object_record_sequence_allocator_0xf44_known) {
		result.blocked_reason = "0x4a5c07_object_sequence_allocator_0xf44_missing";
		return result;
	}
	if (!state.descriptor_vector_398_39c_source_owned || state.descriptor_vector_entries_398_39c.empty()) {
		result.blocked_reason = "0x4a5c07_generator_descriptor_vector_0x398_0x39c_missing";
		return result;
	}
	std::array<bool, 10> allowed_mask {};
	if (!monster_allowed_mask_from_relation_4a5c07(relation, allowed_mask, result.blocked_reason)) {
		return result;
	}

	std::vector<const MonsterTableRow57cea0 *> accepted_rows;
	const std::vector<MonsterTableRow57cea0> &rows = monster_table_rows_57cea0_4a5c07();
	for (auto it = rows.rbegin(); it != rows.rend(); ++it) {
		const MonsterTableRow57cea0 &row = *it;
		if (row.level_field_0x04 < 0) {
			continue;
		}
		const int32_t mask_index = monster_allowed_mask_index_4a5c07(row.faction_index_0x00);
		if (mask_index < 0 || mask_index >= int32_t(allowed_mask.size()) || !allowed_mask[size_t(mask_index)]) {
			continue;
		}
		if (row.ai_value_0x40 <= 0 || row.adventure_low_0x6c <= 0 || row.adventure_high_0x70 <= 0) {
			result.blocked_reason = "0x4a5c07_creature_runtime_value_or_quantity_bounds_missing";
			return result;
		}
		const int64_t average_stack = (int64_t(row.adventure_high_0x70) + int64_t(row.adventure_low_0x6c)) / 2;
		const int64_t minimum_value = int64_t(row.ai_value_0x40) * average_stack;
		const int64_t maximum_value = int64_t(row.ai_value_0x40) * 100;
		if (minimum_value > int64_t(value_arg_0x08)) {
			continue;
		}
		if (int64_t(value_arg_0x08) > maximum_value) {
			continue;
		}
		accepted_rows.push_back(&row);
	}
	result.accepted_row_count = int32_t(accepted_rows.size());
	if (accepted_rows.empty()) {
		result.null_selection = true;
		result.applied = true;
		return result;
	}

	const int32_t selected_ordinal = rng.next() % int32_t(accepted_rows.size());
	const MonsterTableRow57cea0 &selected = *accepted_rows[size_t(selected_ordinal)];
	const GeneratorDescriptorVectorEntry0x398 *descriptor =
			monster_descriptor_vector_entry_4a5c07(state, selected.creature_id);
	if (descriptor == nullptr) {
		result.blocked_reason = "0x4a5c07_selected_monster_descriptor_vector_entry_missing:creature_id="
				+ std::to_string(selected.creature_id);
		return result;
	}
	if (!descriptor->descriptor_source_cell_offsets_0x2c_0x30_known) {
		result.blocked_reason = "0x4a5c07_selected_monster_descriptor_source_cell_offsets_0x2c_0x30_missing";
		return result;
	}

	int32_t selected_quantity = (value_arg_0x08 + (selected.ai_value_0x40 / 2)) / selected.ai_value_0x40;
	const int32_t spread = selected_quantity / 4 + 1;
	if (spread > 1) {
		selected_quantity += (rng.next() % spread) - (rng.next() % spread);
	}
	if (selected_quantity < 1) {
		selected_quantity = 1;
	}

	result.selected_creature_id = selected.creature_id;
	result.selected_quantity_0x20 = selected_quantity;
	result.selected_descriptor_vector_index_0x398 = descriptor->vector_index;
	result.source_record_copy = descriptor->source_record_copy;
	result.object_record_key_known = true;
	result.object_record_key = state.next_native_object_record_key_0x4a93a2;
	state.next_native_object_record_key_0x4a93a2 += 1U;
	state.object_record_allocation_count_0x4a93a2 += 1;
	result.sequence_0x1c = state.object_record_sequence_allocator_0xf44;
	state.object_record_sequence_allocator_0xf44 += 1;
	result.applied = true;
	return result;
}

static ConnectionMonsterMaterializationResult4a5e03 connection_monster_materialization_0x4a5e03(
		GeneratorObjectPrivateState &state,
		int32_t x,
		int32_t y,
		int32_t level,
		int32_t value_arg_0x08,
		H3MapedRng &rng) {
	ConnectionMonsterMaterializationResult4a5e03 result;
	result.invoked = true;
	const int64_t target_flat = cell_index(state.width, state.height, x, y, level);
	if (target_flat < 0 || target_flat >= int64_t(state.generated_cell_buffer.records.size())) {
		result.blocked_reason = "0x4a5e03_target_cell_out_of_bounds";
		return result;
	}
	GeneratedCellRecord0x30 &target = state.generated_cell_buffer.records[size_t(target_flat)];
	if (!target.object_reference_vector_contents_known) {
		result.blocked_reason = "0x4a5e03_target_object_reference_vector_unknown";
		return result;
	}
	if (!target.object_references_0x04_0x08.empty()) {
		result.skipped_nonempty_target_refs = true;
		result.applied = true;
		return result;
	}
	if (!target.word_0x20_known) {
		result.blocked_reason = "0x4a5e03_target_owner_word_unknown";
		return result;
	}
	const int32_t owner_byte2 = generated_cell_word20_owner_byte2_signed(target.word_0x20);
	GeneratorRelationOwnerState4a218c *relation = relation_owner_for_runtime_zone_0x4a54a7(state, owner_byte2);
	if (relation == nullptr) {
		result.blocked_reason = "0x4a5e03_target_owner_relation_missing";
		return result;
	}
	result.allocation_0x4a5c07 =
			connection_monster_allocate_0x4a5c07(state, *relation, value_arg_0x08, rng);
	if (!result.allocation_0x4a5c07.applied) {
		result.blocked_reason = result.allocation_0x4a5c07.blocked_reason.empty()
				? "0x4a5c07_monster_allocation_not_applied"
				: result.allocation_0x4a5c07.blocked_reason;
		return result;
	}
	if (result.allocation_0x4a5c07.null_selection) {
		result.applied = true;
		return result;
	}
	const SourceObjectRecord0x4c &source = result.allocation_0x4a5c07.source_record_copy;
	const GeneratorDescriptorVectorEntry0x398 *descriptor =
			monster_descriptor_vector_entry_4a5c07(state, result.allocation_0x4a5c07.selected_creature_id);
	if (descriptor == nullptr) {
		result.blocked_reason = "0x4a5e03_selected_monster_descriptor_lost_before_0x4a54a7";
		return result;
	}
	result.commit_0x4a54a7 = object_footprint_commit_4a54a7(
			state,
			result.allocation_0x4a5c07.object_record_key,
			descriptor->descriptor_type_0x1c,
			x,
			y,
			level,
			descriptor->descriptor_projection_enabled_0x29,
			descriptor->descriptor_source_cell_x_0x2c,
			descriptor->descriptor_source_cell_y_0x30,
			&source);
	result.committed = result.commit_0x4a54a7.object_vector_appended;
	if (!result.committed) {
		result.blocked_reason = "0x4a54a7_connection_monster_commit_did_not_append_object_vector";
		return result;
	}
	if (!state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
		object_record.object_record_key_allocated_by_0x4a93a2 = true;
		object_record.object_record_vtable_0x00 = OBJECT_RECORD_VTABLE_0X540A88;
		object_record.object_record_sequence_0x1c = result.allocation_0x4a5c07.sequence_0x1c;
		object_record.object_record_selected_index_0x20 = result.allocation_0x4a5c07.selected_quantity_0x20;
		object_record.object_record_enabled_word_0x24 = 3U;
		object_record.object_record_enabled_low_byte_0x24 = true;
		object_record.source_catalog_index_0x49da08 = descriptor->source_catalog_index_0x49da08;
		object_record.copied_source_record_carried = true;
		object_record.source_record_copy = source;
	}
	result.applied = true;
	return result;
}

static ConnectionPairMaterializationPrefixResult4a61bc connection_pair_materialization_prefix_0x4a61bc(
		GeneratorObjectPrivateState &state,
		GeneratorRelationOwnerState4a218c &source_owner,
		GeneratorRelationOwnerState4a218c &target_owner,
		const GeneratorSourceEndpointRecordState4a1f3b &source_endpoint,
		const GeneratorSourceEndpointRecordState4a1f3b &reciprocal_endpoint,
		const std::vector<ConnectionFrontierCandidate4a79a3> &frontier_candidates,
		H3MapedRng &rng) {
	ConnectionPairMaterializationPrefixResult4a61bc result;
	result.invoked = true;
	result.source_record_pair_known =
			source_endpoint.target_runtime_zone_index == target_owner.runtime_zone_index
			&& reciprocal_endpoint.target_runtime_zone_index == source_owner.runtime_zone_index;
	if (!result.source_record_pair_known) {
		result.blocked_reason = "0x4a61bc_source_endpoint_pair_not_reciprocal";
		return result;
	}
	if (!source_owner.coordinate_triple_0x10_0x18_known
			|| !target_owner.coordinate_triple_0x10_0x18_known
			|| !source_owner.terrain_policy_0x0c_known
			|| !target_owner.terrain_policy_0x0c_known) {
		result.blocked_reason = "0x4a61bc_relation_owner_entry_fields_unknown";
		return result;
	}
	if (source_owner.coordinate_level_0x18 != target_owner.coordinate_level_0x18) {
		result.blocked_reason = "0x4a61bc_relation_owner_level_mismatch";
		return result;
	}
	if (source_owner.terrain_policy_0x0c == 8 || target_owner.terrain_policy_0x0c == 8) {
		result.blocked_reason = "0x4a61bc_relation_owner_terrain_policy_8_gate_returned_false";
		return result;
	}
	result.entry_gate_passed = true;
	result.frontier_vector_known = true;

	int32_t best_score = std::numeric_limits<int32_t>::max();
	std::vector<ConnectionFrontierCandidate4a79a3> best_candidates;
	for (const ConnectionFrontierCandidate4a79a3 &candidate : frontier_candidates) {
		if (candidate.level != source_owner.coordinate_level_0x18) {
			continue;
		}
		if (candidate.source_owner_byte2 != source_owner.runtime_zone_index
				|| candidate.source_owner_byte3 != target_owner.runtime_zone_index) {
			continue;
		}
		result.frontier_candidate_count += 1;
		if (candidate.score_word_0x1c_high > best_score) {
			continue;
		}
		if (candidate.score_word_0x1c_high < best_score) {
			best_score = candidate.score_word_0x1c_high;
			best_candidates.clear();
		}
		best_candidates.push_back(candidate);
	}
	result.selected_candidate_count = int32_t(best_candidates.size());
	if (result.selected_candidate_count <= 0) {
		result.blocked_reason = "0x4a61bc_live_prefix_no_source_frontier_candidate_after_0x49b3fb";
		return result;
	}
	result.candidate_selected = true;

	if (source_endpoint.wide) {
		result.guard_budget_known = true;
		result.guard_budget_0x4a65a5 = 0;
	} else {
		result.guard_budget_known = state.generator_value_band_0x10bc_known;
		if (!result.guard_budget_known) {
			result.blocked_reason = "0x4a61bc_0x4a65a5_generator_value_band_missing_before_0x4a5e03";
			return result;
		}
		result.guard_budget_0x4a65a5 =
				reward_guard_attach_value_from_band_0x4a65a5(source_endpoint.guard_value, state.generator_value_band_0x10bc);
	}
	result.guard_budget_positive = result.guard_budget_0x4a65a5 > 0;

	if (best_score == 1 && result.guard_budget_0x4a65a5 <= 0 && !source_endpoint.border_guard) {
		return result;
	}

	const int32_t selected_loop_limit =
			std::min<int32_t>(int32_t(best_candidates.size()), (result.frontier_candidate_count + 39) / 40);
	for (int32_t loop_index = 0; loop_index < selected_loop_limit; ++loop_index) {
		if (best_candidates.empty()) {
			break;
		}
		const int32_t rng_value = rng.next();
		result.rng_selection_count += 1;
		const int32_t selected_index = rng_value % int32_t(best_candidates.size());
		const ConnectionFrontierCandidate4a79a3 selected = best_candidates[size_t(selected_index)];
		best_candidates.erase(best_candidates.begin() + selected_index);
		result.selected_loop_count += 1;

		const ProjectedCellChainResult4a5a23 source_chain =
				projected_cell_chain_no_object_4a5a23(
						state.generated_cell_buffer,
						selected.source_x,
						selected.source_y,
						selected.level,
						source_endpoint.border_guard);
		result.projection_chain_call_count += 1;
		result.projection_occupied_stamp_count += source_chain.occupied_stamp_count;
		result.projection_cleanup_clear_count += source_chain.cleanup_bit_0x04_clear_count;
		if (source_chain.stopped_on_object_materialization_required) {
			result.projection_object_branch_blocked_count += 1;
			result.blocked_reason = "0x4a61bc_0x4a5a23_source_projection_object_branch_unowned_before_0x4a5e03";
			return result;
		}

		source_owner.owner_local_vectors_0x3e4_0x3f4_0x404_known = true;
		source_owner.owner_local_vector_0x404_count += 1;
		result.local_vector_append_count_0x404 += 1;

		const ProjectedCellChainResult4a5a23 target_chain =
				projected_cell_chain_no_object_4a5a23(
						state.generated_cell_buffer,
						selected.neighbor_x,
						selected.neighbor_y,
						selected.level,
						source_endpoint.border_guard);
		result.projection_chain_call_count += 1;
		result.projection_occupied_stamp_count += target_chain.occupied_stamp_count;
		result.projection_cleanup_clear_count += target_chain.cleanup_bit_0x04_clear_count;
		if (target_chain.stopped_on_object_materialization_required) {
			result.projection_object_branch_blocked_count += 1;
			result.blocked_reason = "0x4a61bc_0x4a5a23_target_projection_object_branch_unowned_before_0x4a5e03";
			return result;
		}

		target_owner.owner_local_vectors_0x3e4_0x3f4_0x404_known = true;
		target_owner.owner_local_vector_0x404_count += 1;
		result.local_vector_append_count_0x404 += 1;

		if (result.guard_budget_0x4a65a5 > 0) {
			const int32_t target_choice_rng = rng.next();
			result.guard_target_rng_count += 1;
			const bool use_source_cell = (target_choice_rng % 2) == 0;
			const int32_t constructor_x = use_source_cell ? selected.source_x : selected.neighbor_x;
			const int32_t constructor_y = use_source_cell ? selected.source_y : selected.neighbor_y;
			result.constructor_invocation_count_0x4a5e03 += 1;
			const ConnectionMonsterMaterializationResult4a5e03 constructor =
					connection_monster_materialization_0x4a5e03(
							state,
							constructor_x,
							constructor_y,
							selected.level,
							result.guard_budget_0x4a65a5,
							rng);
			if (constructor.allocation_0x4a5c07.invoked) {
				result.selector_invocation_count_0x4a5c07 += 1;
			}
			if (constructor.allocation_0x4a5c07.null_selection) {
				result.selector_null_count_0x4a5c07 += 1;
			}
			if (constructor.committed) {
				result.constructor_commit_count_0x4a54a7 += 1;
			}
			if (!constructor.applied) {
				result.constructor_blocked = true;
				result.blocked_reason = constructor.blocked_reason.empty()
						? "0x4a5e03_connection_monster_materialization_not_applied"
						: constructor.blocked_reason;
				return result;
			}
		}
	}

	if (source_endpoint.border_guard) {
		result.constructor_blocked = true;
		result.blocked_reason = "0x4a61bc_border_guard_endpoint_helpers_0x4a5e73_0x4a606b_unowned_before_0x4a5e03";
		return result;
	}
	return result;
}

static ConnectionTailReplayResult4a79a3 connection_tail_replay_0x4a79a3(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	ConnectionTailReplayResult4a79a3 result;
	result.invoked = true;
	result.internal_growth_initial_object_count = int32_t(state.object_records_0xec4_ecc.size());
	result.generated_cell_grid_owned = state.generated_cell_buffer_owned;
	result.endpoint_caller_prep_known =
			state.connection_materialization_caller_prep_d014.recovered_helper_contract_0x4a5e73_known
			&& state.connection_materialization_caller_prep_d014.recovered_explicit_input_0x4a606b_known
			&& state.connection_materialization_caller_prep_d014.recovered_no_object_projection_chain_0x4a5a23_known
			&& state.connection_materialization_caller_prep_d014.live_0x4a5e73_to_0x4a606b_target_mode_excluded
			&& state.connection_materialization_caller_prep_d014.live_0x4a696b_target_mode_excluded
			&& state.connection_materialization_caller_prep_d014.fallback_0x4a7605_to_0x4a5e03_source_backed;
	result.fallback_materialization_known =
			state.connection_fallback_materialization_0x4a7605_0x4a5e03_known
			&& state.connection_fallback_materialization_records_0x4a7605_0x4a5e03.size()
					== size_t(state.connection_fallback_materialization_record_count);
	result.fallback_materialization_applied =
			result.fallback_materialization_known
			&& state.connection_fallback_materialization_record_count > 0
			&& state.connection_fallback_materialization_blocked_count == 0
			&& state.connection_fallback_materialization_commit_count
					== state.connection_fallback_materialization_record_count;

	if (!result.generated_cell_grid_owned) {
		result.blocked_reason = "0x4a79a3_generated_cell_grid_not_owned";
		return result;
	}
	if (!result.endpoint_caller_prep_known) {
		result.blocked_reason = "0x4a79a3_endpoint_caller_prep_not_owned";
		return result;
	}

	const int64_t expected_cell_count = int64_t(state.generated_cell_buffer.width)
			* int64_t(state.generated_cell_buffer.height)
			* int64_t(state.generated_cell_buffer.level_count);
	if (state.generated_cell_buffer.width <= 0
			|| state.generated_cell_buffer.height <= 0
			|| state.generated_cell_buffer.level_count <= 0
			|| expected_cell_count <= 0
			|| expected_cell_count != int64_t(state.generated_cell_buffer.records.size())) {
		result.blocked_reason = "0x4a79a3_generated_cell_grid_shape_invalid";
		return result;
	}
	for (const GeneratedCellRecord0x30 &record : state.generated_cell_buffer.records) {
		if (!record.word_0x20_known
				|| !record.word_0x24_known
				|| !record.word_0x28_known
				|| !record.byte_0x2b_known) {
			result.blocked_reason = "0x4a79a3_generated_cell_record_input_unknown";
			return result;
		}
	}
	if (!source_endpoint_records_known_for_lookup_0x49b3fb(state.relation_owner_vectors_10e4_10e8)) {
		result.blocked_reason = "0x4a79a3_source_endpoint_vector_0xc8_0xcc_input_unknown";
		return result;
	}

	result.source_backed_frontier_known = true;
	std::vector<ConnectionFrontierCandidate4a79a3> frontier_candidates;
	for (int32_t level = 0; level < state.generated_cell_buffer.level_count; ++level) {
		for (int32_t y = 0; y < state.generated_cell_buffer.height; ++y) {
			for (int32_t x = 0; x < state.generated_cell_buffer.width; ++x) {
				const int64_t flat = cell_index(state.generated_cell_buffer.width, state.generated_cell_buffer.height, x, y, level);
				if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
					continue;
				}
				const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
				result.source_frontier_scan_cell_count += 1;
				if (generated_cell_word20_owner_byte3_signed(record.word_0x20) < 0) {
					continue;
				}
				const uint32_t terrain = record.word_0x24 & 0x3fU;
				if (terrain == 8U || terrain == 9U) {
					continue;
				}
				if ((record.word_0x28 & CELL_DECOR_READY_BIT_25) == 0U) {
					continue;
				}
				const int32_t direction = int32_t((record.word_0x28 >> 12U) & 0x7U);
				const int32_t neighbor_x = x + DIRECTION_TABLE_0X5A2658[size_t(direction)][0];
				const int32_t neighbor_y = y + DIRECTION_TABLE_0X5A2658[size_t(direction)][1];
				const int64_t neighbor_flat = cell_index(state.generated_cell_buffer.width, state.generated_cell_buffer.height, neighbor_x, neighbor_y, level);
				if (neighbor_flat < 0 || neighbor_flat >= int64_t(state.generated_cell_buffer.records.size())) {
					result.source_frontier_out_of_bounds_skip_count += 1;
					continue;
				}
				const GeneratedCellRecord0x30 &neighbor = state.generated_cell_buffer.records[size_t(neighbor_flat)];
				if ((neighbor.word_0x24 & 0x3fU) == 8U) {
					result.source_frontier_neighbor_terrain8_skip_count += 1;
					continue;
				}
				if (generated_cell_word20_owner_byte2_signed(neighbor.word_0x20)
						== generated_cell_word20_owner_byte2_signed(record.word_0x20)) {
					result.source_frontier_same_owner_skip_count += 1;
					continue;
				}
				ConnectionFrontierCandidate4a79a3 candidate;
				candidate.source_x = x;
				candidate.source_y = y;
				candidate.neighbor_x = neighbor_x;
				candidate.neighbor_y = neighbor_y;
				candidate.level = level;
				candidate.source_owner_byte2 = generated_cell_word20_owner_byte2_signed(record.word_0x20);
				candidate.source_owner_byte3 = generated_cell_word20_owner_byte3_signed(record.word_0x20);
				candidate.neighbor_owner_byte2 = generated_cell_word20_owner_byte2_signed(neighbor.word_0x20);
				candidate.direction = direction;
				candidate.score_word_0x1c_high = int32_t((record.word_0x1c >> 16U) & 0xffffU);
				frontier_candidates.push_back(candidate);
				result.source_frontier_candidate_pair_count += 1;
			}
		}
	}

	for (GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (!owner.terrain_policy_0x0c_known || !owner.coordinate_triple_0x10_0x18_known) {
			result.blocked_reason = "0x4a79a3_relation_owner_tail_input_unknown";
			return result;
		}
		if (owner.terrain_policy_0x0c == 8) {
			continue;
		}
		const int32_t level = owner.coordinate_level_0x18;
		if (level < 0 || level >= state.generated_cell_buffer.level_count) {
			result.blocked_reason = "0x4a79a3_relation_owner_level_out_of_bounds";
			return result;
		}
		result.relation_owner_level_byte2b_clear_pass_count += 1;
		for (int32_t y = 0; y < state.generated_cell_buffer.height; ++y) {
			for (int32_t x = 0; x < state.generated_cell_buffer.width; ++x) {
				const int64_t flat = cell_index(state.generated_cell_buffer.width, state.generated_cell_buffer.height, x, y, level);
				if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
					continue;
				}
				GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
				const uint32_t previous = record.word_0x28;
				record.word_0x28 &= ~CELL_BYTE_0X2B_LOW_BIT_24;
				record.word_0x28_known = true;
				sync_generated_cell_byte_0x2b_from_word28(record);
				if (record.word_0x28 != previous) {
					result.relation_owner_level_byte2b_clear_cell_count += 1;
				}
			}
		}
		for (const GeneratorSourceEndpointRecordState4a1f3b &record : owner.source_endpoint_records_0xc8_0xcc) {
			const int32_t target_runtime_zone = record.target_runtime_zone_index;
			GeneratorRelationOwnerState4a218c *target_owner =
					relation_owner_for_runtime_zone_0x4a54a7(state, target_runtime_zone);
			if (target_owner == nullptr) {
				continue;
			}
			const GeneratorSourceEndpointRecordState4a1f3b *reciprocal_endpoint =
					source_endpoint_record_find_0x49b3fb(
							state.relation_owner_vectors_10e4_10e8,
							target_owner->runtime_zone_index,
							owner.runtime_zone_index);
			if (reciprocal_endpoint != nullptr) {
				result.internal_growth_candidate_pair_count += 1;
				const ConnectionPairMaterializationPrefixResult4a61bc prefix =
						connection_pair_materialization_prefix_0x4a61bc(
								state,
								owner,
								*target_owner,
								record,
								*reciprocal_endpoint,
								frontier_candidates,
								rng);
				if (prefix.invoked) {
					result.internal_growth_0x4a61bc_invocation_count += 1;
				}
				if (prefix.entry_gate_passed) {
					result.internal_growth_0x4a61bc_entry_gate_pass_count += 1;
				}
				result.internal_growth_0x4a61bc_frontier_candidate_count +=
						prefix.frontier_candidate_count;
				result.internal_growth_0x4a61bc_selected_candidate_count +=
						prefix.selected_candidate_count;
				result.internal_growth_0x4a61bc_selected_loop_count +=
						prefix.selected_loop_count;
				result.internal_growth_0x4a61bc_rng_selection_count +=
						prefix.rng_selection_count;
				result.internal_growth_0x4a61bc_projection_chain_call_count +=
						prefix.projection_chain_call_count;
				result.internal_growth_0x4a61bc_projection_occupied_stamp_count +=
						prefix.projection_occupied_stamp_count;
				result.internal_growth_0x4a61bc_projection_cleanup_clear_count +=
						prefix.projection_cleanup_clear_count;
				result.internal_growth_0x4a61bc_local_vector_append_count_0x404 +=
						prefix.local_vector_append_count_0x404;
				if (prefix.guard_budget_positive) {
					result.internal_growth_0x4a61bc_guard_budget_positive_count += 1;
				}
				result.internal_growth_0x4a61bc_projection_object_branch_blocked_count +=
						prefix.projection_object_branch_blocked_count;
				if (prefix.constructor_blocked) {
					result.internal_growth_0x4a61bc_constructor_blocked_count += 1;
				}
				if (!prefix.blocked_reason.empty()
						&& prefix.blocked_reason != "0x4a61bc_live_prefix_no_source_frontier_candidate_after_0x49b3fb"
						&& result.blocked_reason.empty()) {
					result.blocked_reason = prefix.blocked_reason;
				}
			}
		}
	}

	result.internal_growth_0x49b3fb_0x4a61bc_known = result.internal_growth_candidate_pair_count > 0;
	result.internal_growth_0x4a61bc_prefix_owned =
			result.internal_growth_0x49b3fb_0x4a61bc_known
			&& result.internal_growth_0x4a61bc_invocation_count == result.internal_growth_candidate_pair_count;
	result.internal_growth_final_object_count = int32_t(state.object_records_0xec4_ecc.size());
	result.internal_growth_positive_append_count =
			result.internal_growth_final_object_count - result.internal_growth_initial_object_count;
	if (result.internal_growth_candidate_pair_count > 0) {
		if (!result.blocked_reason.empty()) {
			// Keep the exact first source-backed blocker discovered inside 0x4a61bc.
		} else if (result.internal_growth_0x4a61bc_constructor_blocked_count > 0) {
			result.blocked_reason =
					"0x4a61bc_live_direct_0x4a5c07_0x4a5e03_commit_blocked";
		} else if (result.internal_growth_0x4a61bc_selected_candidate_count == 0
				&& result.internal_growth_0x4a61bc_entry_gate_pass_count > 0) {
			result.blocked_reason =
					"0x4a61bc_live_prefix_no_source_frontier_candidate_after_0x49b3fb";
		} else {
			result.applied = true;
			return result;
		}
		return result;
	}

	if (!result.fallback_materialization_applied) {
		if (!state.connection_fallback_materialization_records_available_for_scope
				|| state.connection_fallback_materialization_record_count == 0) {
			result.blocked_reason = "0x4a79a3_fallback_materialization_0x4a7605_0x4a5e03_source_records_missing_after_live_pair_loop";
			return result;
		}
		const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> fallback_records =
				state.connection_fallback_materialization_records_0x4a7605_0x4a5e03;
		const ConnectionFallbackMaterializationResult4a7605_4a5e03 fallback_result =
				connection_fallback_materialization_4a7605_4a5e03(state, fallback_records);
		result.fallback_materialization_known =
				state.connection_fallback_materialization_0x4a7605_0x4a5e03_known
				&& state.connection_fallback_materialization_records_0x4a7605_0x4a5e03.size()
						== size_t(state.connection_fallback_materialization_record_count);
		result.fallback_materialization_applied =
				result.fallback_materialization_known
				&& state.connection_fallback_materialization_record_count > 0
				&& fallback_result.blocked_count == 0
				&& fallback_result.commit_count == state.connection_fallback_materialization_record_count;
		if (!result.fallback_materialization_applied) {
			if (!state.connection_fallback_materialization_first_blocked_reason.empty()) {
				result.blocked_reason = "0x4a79a3_fallback_materialization_0x4a7605_0x4a5e03_blocked_at_record_"
						+ std::to_string(state.connection_fallback_materialization_first_blocked_record_index)
						+ "_" + state.connection_fallback_materialization_first_blocked_reason;
			} else {
				result.blocked_reason = "0x4a79a3_fallback_materialization_0x4a7605_0x4a5e03_not_applied";
			}
			return result;
		}
	}

	result.applied = true;
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
		if (!generated_cell_49a1d8_valid_record(record)) {
			return false;
		}
		if ((record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
			return false;
		}
		if ((record.word_0x2c & 0x01U) != 0U) {
			return false;
		}
	}
	return true;
}

static bool source_relation_endpoint_coordinate_eligibility_0x49aa93(
		const GeneratorObjectPrivateState &state,
		const SourceObjectDescriptorJoinResult4903e8 &join,
		int32_t x,
		int32_t y,
		int32_t level,
		int32_t relation_match_byte3) {
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
		if (generated_cell_word20_owner_byte3(record.word_0x20) != uint8_t(relation_match_byte3 & 0xff)) {
			return false;
		}
		if ((record.word_0x24 & 0x3fU) == 9U) {
			return false;
		}
		if (!generated_cell_49a1d8_valid_record(record)) {
			return false;
		}
		if ((record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
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
			if (generated_cell_word20_owner_byte3(record.word_0x20) != uint8_t(result.relation_owner_byte2 & 0xff)) {
				result.owner_byte_reject_count += 1;
				continue;
			}
			if (!source_relation_endpoint_coordinate_eligibility_0x49aa93(state, join, x, y, level, result.relation_owner_byte2)) {
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
			join.descriptor.source_cell_y_0x30,
			join.copied_source_record_is_identity_authority ? &join.source_record_copy : nullptr);
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

SourceOrderSchedulerResult4a8db2 source_order_weighted_scheduler_from_source_record_0x4a8db2(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, const SourceOrderSchedulerSourceRecord4a8db2 &source_record, bool source_pair_pointer_0x00_carried, bool context_pointer_0x04_carried, int32_t source_pair_copied_source_catalog_index, int32_t context_wrapper_index_0x04, int32_t relation_owner_byte2, int32_t scan_low_x, int32_t scan_low_y, int32_t scan_high_x, int32_t scan_high_y, int32_t level, int32_t lane_state_0xee4, H3MapedRng &rng) {
	SourceOrderSchedulerResult4a8db2 result;
	result.source_pair_pointer_carried = source_pair_pointer_0x00_carried;
	result.source_pair_copied_source_catalog_index = source_pair_copied_source_catalog_index;
	result.source_record_id_0x00 = source_record.source_id_0x00;
	result.source_record_owner_or_type_0x04 = source_record.owner_or_type_0x04;
	result.source_record_relation_selector_0x1c = source_record.relation_selector_0x1c;
	result.context_pointer_carried = context_pointer_0x04_carried;
	result.context_wrapper_index_0x04 = context_wrapper_index_0x04;
	result.lane_state_0xee4 = lane_state_0xee4;
	result.scan_bounds_known = true;
	result.scan_bounds_non_empty = scan_high_x > scan_low_x && scan_high_y > scan_low_y;
	result.relation_owner_byte_known = relation_owner_byte2 >= 0;
	result.relation_owner_byte2 = relation_owner_byte2;
	result.scan_bound_low_x = scan_low_x;
	result.scan_bound_low_y = scan_low_y;
	result.scan_bound_high_x = scan_high_x;
	result.scan_bound_high_y = scan_high_y;
	result.level = level;
	result.descriptor_source_bridge_known = join.joined
			|| (!join.joined
					&& join.descriptor.descriptor_type_0x1c == 98
					&& join.descriptor_source_fields_match
					&& join.source_catalog_index_0x49da08 >= 0);

	auto make_lane = [&](int32_t lane_index,
			uint32_t direct_callsite,
			uint32_t weighted_callsite,
			int32_t count_offset,
			bool count_known,
			int32_t count_value,
			int32_t density_offset,
			bool density_known,
			int32_t density_value,
			bool use_lane_state,
			bool enabled_low_byte) {
		SourceOrderSchedulerLane4a8db2 lane;
		lane.lane_index = lane_index;
		lane.direct_callsite = direct_callsite;
		lane.weighted_callsite = weighted_callsite;
		lane.count_field_offset = count_offset;
		lane.count_field_known = count_known;
		lane.count_field_value = count_value;
		lane.density_field_offset = density_offset;
		lane.density_field_known = density_known;
		lane.density_field_value = density_value;
		lane.use_lane_state_0xee4 = use_lane_state;
		lane.selected_index_0x20 = use_lane_state ? lane_state_0xee4 : -1;
		lane.enabled_low_byte_0x24 = enabled_low_byte;
		lane.initially_disabled = !density_known || density_value <= 0;
		lane.disabled_after_replay = lane.initially_disabled;
		return lane;
	};

	result.lanes.push_back(make_lane(0, 0x4a8df7U, 0x4a8ffdU, 0x24, source_record.field_0x24_known, source_record.field_0x24, 0x2c, source_record.field_0x2c_known, source_record.field_0x2c, true, true));
	result.lanes.push_back(make_lane(1, 0x4a8e26U, 0x4a8fd6U, 0x20, source_record.field_0x20_known, source_record.field_0x20, 0x28, source_record.field_0x28_known, source_record.field_0x28, true, false));
	result.lanes.push_back(make_lane(2, 0x4a8e55U, 0x4a8fb4U, 0x34, source_record.field_0x34_known, source_record.field_0x34, 0x3c, source_record.field_0x3c_known, source_record.field_0x3c, false, true));
	result.lanes.push_back(make_lane(3, 0x4a8e83U, 0x4a8f96U, 0x30, source_record.field_0x30_known, source_record.field_0x30, 0x38, source_record.field_0x38_known, source_record.field_0x38, false, false));

	auto finish = [&](const std::string &reason, bool finished) {
		result.blocked_reason = reason;
		result.replay_finished = finished;
		result.disabled_lane_count = 0;
		for (const SourceOrderSchedulerLane4a8db2 &lane : result.lanes) {
			if (lane.disabled_after_replay) {
				result.disabled_lane_count += 1;
			}
		}
		state.source_order_scheduler_replay_0x4a8db2_known = true;
		state.source_order_scheduler_replays_0x4a8db2.push_back(result);
		state.source_order_scheduler_replay_count_0x4a8db2 = int32_t(state.source_order_scheduler_replays_0x4a8db2.size());
		state.source_order_scheduler_direct_call_count_0x4a8db2 += result.direct_prepass_call_count;
		state.source_order_scheduler_weighted_call_count_0x4a8db2 += result.weighted_call_count;
		state.source_order_scheduler_commit_count_0x4a8db2 += result.committed_call_count;
		if (!reason.empty() && !finished) {
			state.source_order_scheduler_blocked_count_0x4a8db2 += 1;
		}
		return result;
	};
	auto field_offset_label = [](int32_t offset) -> const char * {
		switch (offset) {
			case 0x20:
				return "0x20";
			case 0x24:
				return "0x24";
			case 0x28:
				return "0x28";
			case 0x2c:
				return "0x2c";
			case 0x30:
				return "0x30";
			case 0x34:
				return "0x34";
			case 0x38:
				return "0x38";
			case 0x3c:
				return "0x3c";
			default:
				return "unknown";
		}
	};

	if (!result.source_pair_pointer_carried) {
		return finish("0x4a8db2_source_pair_plus_0x00_source_record_missing", false);
	}
	if (!result.context_pointer_carried) {
		return finish("0x4a8db2_source_pair_plus_0x04_context_missing", false);
	}
	if (!result.descriptor_source_bridge_known) {
		return finish(join.blocked_reason.empty() ? "0x4a8db2_descriptor_source_bridge_unresolved" : join.blocked_reason, false);
	}
	if (!result.scan_bounds_non_empty) {
		return finish("0x4a8db2_scan_bounds_empty_or_unordered", false);
	}
	if (!result.relation_owner_byte_known) {
		return finish("0x4a8db2_relation_owner_byte2_missing", false);
	}

	for (const SourceOrderSchedulerLane4a8db2 &lane : result.lanes) {
		if (!lane.count_field_known) {
			return finish(std::string("0x4a8db2_source_count_field_") + field_offset_label(lane.count_field_offset) + "_unknown", false);
		}
	}

	auto run_scan_call = [&](SourceOrderSchedulerLane4a8db2 &lane,
			const std::string &phase,
			uint32_t callsite,
			int32_t loop_index,
			int32_t threshold_arg,
			int64_t score_before,
			int64_t increment,
			int64_t score_after) {
		SourceOrderSchedulerCall4a8db2 call;
		call.phase = phase;
		call.callsite = callsite;
		call.lane_index = lane.lane_index;
		call.loop_index = loop_index;
		call.selected_index_0x20 = lane.selected_index_0x20;
		call.enabled_low_byte_0x24 = lane.enabled_low_byte_0x24;
		call.threshold_arg_0x18 = threshold_arg;
		call.scheduler_score_before = score_before;
		call.scheduler_increment = increment;
		call.scheduler_score_after = score_after;
		call.weighted_candidate_vector_index_0x4a901a = int32_t(state.weighted_candidate_vectors_0x4a901a.size());
		call.attempted_0x4a901a = true;
		const WeightedObjectCandidateScanResult4a901a scan = weighted_object_candidate_scan_0x4a901a(
				state,
				join,
				relation_owner_byte2,
				scan_low_x,
				scan_low_y,
				scan_high_x,
				scan_high_y,
				level,
				threshold_arg,
				rng,
				lane.selected_index_0x20,
				0U,
				lane.enabled_low_byte_0x24);
		call.returned_nonzero = scan.committed;
		call.committed = scan.committed;
		call.weighted_candidate_accepted_count_0x4a901a = scan.vector_state_0x4a901a.accepted_candidate_count;
		call.blocked_reason = scan.blocked_reason;
		lane.committed_call_count += scan.committed ? 1 : 0;
		result.committed_call_count += scan.committed ? 1 : 0;
		result.calls.push_back(call);
		return scan.committed;
	};

	bool first_count_branch = true;
	for (size_t lane_index = 0; lane_index < result.lanes.size(); ++lane_index) {
		SourceOrderSchedulerLane4a8db2 &lane = result.lanes[lane_index];
		if (lane.count_field_value <= 0) {
			continue;
		}
		const int32_t start_index = lane_index == 0 ? 1 : (first_count_branch ? 1 : 0);
		for (int32_t loop_index = start_index; loop_index < lane.count_field_value; ++loop_index) {
			lane.direct_prepass_call_count += 1;
			result.direct_prepass_call_count += 1;
			run_scan_call(lane, "direct_prepass", lane.direct_callsite, loop_index, 0, 0, 0, 0);
		}
		first_count_branch = false;
	}

	for (const SourceOrderSchedulerLane4a8db2 &lane : result.lanes) {
		if (!lane.density_field_known) {
			return finish(std::string("0x4a8db2_source_density_field_") + field_offset_label(lane.density_field_offset) + "_unknown", false);
		}
		if (lane.density_field_value > 0) {
			result.positive_density_sum += lane.density_field_value;
			result.positive_density_product *= int64_t(lane.density_field_value);
		}
	}
	if (result.positive_density_sum <= 0) {
		return finish("0x4a8db2_weighted_scheduler_no_positive_density", true);
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

	for (SourceOrderSchedulerLane4a8db2 &lane : result.lanes) {
		if (lane.density_field_value <= 0) {
			lane.initially_disabled = true;
			lane.disabled_after_replay = true;
			lane.blocked_reason = "0x4a8db2_density_lane_nonpositive";
			continue;
		}
		lane.initially_disabled = false;
		lane.disabled_after_replay = false;
		lane.scheduler_increment = result.positive_density_product / int64_t(lane.density_field_value);
		lane.scheduler_score = int64_t(lane.count_field_value) * lane.scheduler_increment;
	}

	while (true) {
		int32_t selected_lane_index = -1;
		int64_t selected_score = 0;
		for (int32_t index = 0; index < int32_t(result.lanes.size()); ++index) {
			const SourceOrderSchedulerLane4a8db2 &lane = result.lanes[size_t(index)];
			if (lane.disabled_after_replay) {
				continue;
			}
			if (selected_lane_index < 0 || lane.scheduler_score < selected_score) {
				selected_lane_index = index;
				selected_score = lane.scheduler_score;
			}
		}
		if (selected_lane_index < 0) {
			return finish("", true);
		}
		SourceOrderSchedulerLane4a8db2 &lane = result.lanes[size_t(selected_lane_index)];
		const int64_t score_before = lane.scheduler_score;
		lane.scheduler_score += lane.scheduler_increment;
		lane.weighted_call_count += 1;
		result.weighted_call_count += 1;
		const bool committed = run_scan_call(lane, "weighted", lane.weighted_callsite, lane.weighted_call_count - 1, result.threshold_arg_0x18, score_before, lane.scheduler_increment, lane.scheduler_score);
		if (!committed) {
			lane.disabled_after_replay = true;
			lane.blocked_reason = result.calls.empty() ? "0x4a8db2_weighted_scan_returned_zero" : result.calls.back().blocked_reason;
			result.calls.back().disabled_after_false = true;
		}
	}
}

SourceOrderSchedulerResult4a8db2 source_order_weighted_scheduler_0x4a8db2(GeneratorObjectPrivateState &state, const SourceObjectDescriptorJoinResult4903e8 &join, const SourceObjectResolverSourcePair4af785 &source_pair, int32_t relation_owner_byte2, int32_t scan_low_x, int32_t scan_low_y, int32_t scan_high_x, int32_t scan_high_y, int32_t level, int32_t lane_state_0xee4, H3MapedRng &rng, bool source_field_0x30_known, int32_t source_field_0x30, bool source_field_0x34_known, int32_t source_field_0x34, bool source_field_0x3c_known, int32_t source_field_0x3c) {
	const SourceObjectRecord0x4c &record = source_pair.source_record_copy;
	SourceOrderSchedulerSourceRecord4a8db2 source_record;
	source_record.source_id_0x00 = source_pair.copied_source_catalog_index;
	source_record.owner_or_type_0x04 = source_pair.context_wrapper_lane_0x04;
	source_record.relation_selector_0x1c = source_pair.source_lane_0x1c;
	source_record.field_0x20_known = record.raw_field_0x20_known;
	source_record.field_0x20 = record.raw_field_0x20;
	source_record.field_0x24_known = record.raw_field_0x24_known;
	source_record.field_0x24 = record.raw_field_0x24;
	source_record.field_0x28_known = record.raw_field_0x28_known;
	source_record.field_0x28 = record.raw_field_0x28;
	source_record.field_0x2c_known = record.raw_field_0x2c_known;
	source_record.field_0x2c = record.raw_field_0x2c;
	source_record.field_0x30_known = record.raw_field_0x30_known || source_field_0x30_known;
	source_record.field_0x30 = record.raw_field_0x30_known ? record.raw_field_0x30 : source_field_0x30;
	source_record.field_0x34_known = record.raw_field_0x34_known || source_field_0x34_known;
	source_record.field_0x34 = record.raw_field_0x34_known ? record.raw_field_0x34 : source_field_0x34;
	source_record.field_0x38_known = record.raw_field_0x38_known;
	source_record.field_0x38 = record.raw_field_0x38;
	source_record.field_0x3c_known = source_field_0x3c_known;
	source_record.field_0x3c = source_field_0x3c;
	return source_order_weighted_scheduler_from_source_record_0x4a8db2(
			state,
			join,
			source_record,
			source_pair.source_record_pointer_0x00_carried,
			source_pair.context_pointer_0x04_carried,
			source_pair.copied_source_catalog_index,
			source_pair.context_wrapper_index_0x04,
			relation_owner_byte2,
			scan_low_x,
			scan_low_y,
			scan_high_x,
			scan_high_y,
			level,
			lane_state_0xee4,
			rng);
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
		sync_generated_cell_byte_0x2b_from_word28(record);
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

static const RuntimeTerrainSelectionRecord49b53d *runtime_terrain_selection_for_runtime_zone_0x49b53d(const RuntimeTerrainSelectionResult49b53d *terrain_selection, int32_t runtime_zone_index) {
	if (terrain_selection == nullptr) {
		return nullptr;
	}
	for (const RuntimeTerrainSelectionRecord49b53d &record : terrain_selection->records) {
		if (record.runtime_zone_index == runtime_zone_index) {
			return &record;
		}
	}
	return nullptr;
}

static void apply_relation_owner_constructor_0x49b452(GeneratorRelationOwnerState4a218c &owner, const RuntimeZoneSeedInput4a218c &seed, const RuntimeZoneSeedInput4a218c *post_town_choice_seed) {
	owner.constructor_0x49b452_known = true;
	const RuntimeZoneSeedInput4a218c &source_record_seed = post_town_choice_seed != nullptr ? *post_town_choice_seed : seed;
	const SourceOrderSchedulerSourceRecord4a8db2 source_record =
			source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(source_record_seed);
	owner.source_pointer_0x00_known = source_record.source_id_0x00 >= 0;
	owner.source_pointer_source_index_0x00 = source_record.source_id_0x00;
	owner.source_pointer_type_0x04_known = source_record.owner_or_type_0x04 >= 0;
	owner.source_pointer_type_0x04 = source_record.owner_or_type_0x04;
	owner.source_pointer_value_0x90_known = source_record.source_id_0x00 >= 0;
	owner.source_pointer_value_0x90 = seed.source_payload.monster_strength_mode;
	owner.source_pointer_monster_match_to_town_0x94_known = source_record.source_id_0x00 >= 0;
	owner.source_pointer_monster_match_to_town_0x94 = seed.source_payload.monster_match_to_town;
	owner.source_pointer_allowed_monster_town_mask_0x95_known = source_record.source_id_0x00 >= 0;
	owner.source_pointer_allowed_monster_town_mask_0x95 = seed.source_payload.allowed_monster_town_mask;
	const int32_t town_choice = post_town_choice_seed != nullptr ? post_town_choice_seed->selected_town_choice_index_0x49b3c1 : seed.selected_town_choice_index_0x49b3c1;
	owner.town_choice_0x04_known = post_town_choice_seed != nullptr || town_choice >= 0;
	owner.town_choice_0x04 = town_choice;
	owner.source_owner_slot_0x1c_known = seed.source_owner_index >= 0;
	owner.source_owner_slot_0x1c = seed.source_owner_index;
	owner.source_order_source_record_0x00_known = source_record.source_id_0x00 >= 0;
	owner.source_order_source_record_0x00 = source_record;
	owner.source_order_source_record_field_0x04_known =
			owner.source_order_source_record_0x00_known
			&& owner.source_order_source_record_0x00.owner_or_type_0x04 >= 0;
	owner.reward_guard_source_bands_0xa0_0xc0_known = seed.source_index >= 0;
	owner.reward_guard_source_bands_0xa0_0xc0 = {
		seed.source_payload.treasure_band_0,
		seed.source_payload.treasure_band_1,
		seed.source_payload.treasure_band_2,
	};
	owner.mine_resource_rules_0x4c_0x84_known = seed.source_index >= 0;
	owner.mine_resource_rules_0x4c_0x84 = seed.source_payload.mines;
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

static void apply_relation_owner_terrain_policy_0x49b53d(GeneratorRelationOwnerState4a218c &owner, const RuntimeTerrainSelectionRecord49b53d *terrain_record) {
	if (terrain_record == nullptr) {
		owner.terrain_policy_0x0c_known = false;
		owner.terrain_policy_0x0c = 0;
		return;
	}
	owner.terrain_policy_0x0c_known = true;
	owner.terrain_policy_0x0c = terrain_record->selected_terrain_id_0x49b53d;
}

static std::vector<RewardGuardSourceStreamRecord4aab7e> reward_guard_source_stream_records_from_relation_owner_0x4aab7e(const GeneratorRelationOwnerState4a218c &owner) {
	if (!owner.reward_guard_source_bands_0xa0_0xc0_known) {
		return {};
	}
	std::vector<RewardGuardSourceStreamRecord4aab7e> records;
	records.reserve(3);
	for (const SourceTreasureBand4a218c &band : owner.reward_guard_source_bands_0xa0_0xc0) {
		RewardGuardSourceStreamRecord4aab7e record;
		record.fields_known = true;
		record.low_value_0xa0 = band.low;
		record.high_value_0xa4 = band.high;
		record.source_count_0xa8 = band.density;
		records.push_back(record);
	}
	return records;
}

static bool reward_guard_source_pointer_vector_0x10e4_0x10e8_known_for_0x4aab7e(const GeneratorObjectPrivateState &state) {
	return state.relation_owner_records_10e4_10e8_partial_known
			&& state.relation_vector_10e4_10e8.present
			&& state.relation_vector_10e4_10e8.contents_known
			&& state.relation_vector_10e4_10e8.count_known
			&& state.relation_vector_10e4_10e8.count == int32_t(state.relation_owner_vectors_10e4_10e8.size());
}

static RewardGuardSourceStreamResult4aab7e reward_guard_source_order_loop_0x4ac552_0x4aab7e(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	RewardGuardSourceStreamResult4aab7e aggregate;
	if (!reward_guard_source_pointer_vector_0x10e4_0x10e8_known_for_0x4aab7e(state)) {
		aggregate.blocked_reason = "0x4ac552_relation_pointer_vector_0x10e4_0x10e8_not_owned_before_0x4aab7e";
		return aggregate;
	}
	if (state.relation_owner_vectors_10e4_10e8.empty()) {
		aggregate.applied = true;
		return aggregate;
	}

	auto merge_reward_guard_source_stream = [](RewardGuardSourceStreamResult4aab7e &target, const RewardGuardSourceStreamResult4aab7e &stream) {
		if (!target.invoked) {
			target = stream;
			return;
		}
		target.invoked = target.invoked || stream.invoked;
		target.applied = target.applied && stream.applied;
		target.wrapper_construct_invoked_0x49ce04 = target.wrapper_construct_invoked_0x49ce04 || stream.wrapper_construct_invoked_0x49ce04;
		target.wrapper_construct_applied_0x49ce04 = target.wrapper_construct_applied_0x49ce04 || stream.wrapper_construct_applied_0x49ce04;
		target.wrapper_construct_reset_cell_count_0x49ce64 += stream.wrapper_construct_reset_cell_count_0x49ce64;
		target.source_triplet_known = target.source_triplet_known && stream.source_triplet_known;
		target.source_object_kind_0x0c_known = target.source_object_kind_0x0c_known && stream.source_object_kind_0x0c_known;
		target.source_record_count += stream.source_record_count;
		target.active_lane_count += stream.active_lane_count;
		target.total_source_count += stream.total_source_count;
		target.source_count_product = stream.source_count_product;
		target.score_base_divided_by_total_source_count_0x4aac0e = stream.score_base_divided_by_total_source_count_0x4aac0e;
		target.minimum_low_word_score_0x10 = stream.minimum_low_word_score_0x10;
		target.selected_lane_count += stream.selected_lane_count;
		target.materialization_attempt_count += stream.materialization_attempt_count;
		target.successful_coordinate_scan_count += stream.successful_coordinate_scan_count;
		target.wrapper_cleanup_count_0x49cebd += stream.wrapper_cleanup_count_0x49cebd;
		target.lanes.insert(target.lanes.end(), stream.lanes.begin(), stream.lanes.end());
		target.attempts.insert(target.attempts.end(), stream.attempts.begin(), stream.attempts.end());
		if (target.blocked_reason.empty() && !stream.blocked_reason.empty()) {
			target.blocked_reason = stream.blocked_reason;
		}
	};

	for (int32_t source_index_0x4ac552 = 0;
			source_index_0x4ac552 < int32_t(state.relation_owner_vectors_10e4_10e8.size());
			++source_index_0x4ac552) {
		const GeneratorRelationOwnerState4a218c &owner =
				state.relation_owner_vectors_10e4_10e8[size_t(source_index_0x4ac552)];
		state.reward_guard_source_stream_records_0x4aab7e =
				reward_guard_source_stream_records_from_relation_owner_0x4aab7e(owner);
		state.reward_guard_source_stream_0x4aab7e_input_known =
				owner.reward_guard_source_bands_0xa0_0xc0_known;
		state.reward_guard_source_stream_owner_kind_0x0c_known =
				owner.terrain_policy_0x0c_known;
		state.reward_guard_source_stream_owner_kind_0x0c = owner.terrain_policy_0x0c;

		const RewardGuardSourceStreamResult4aab7e stream =
				reward_guard_source_stream_materialization_0x4aab7e(
						state,
						state.reward_guard_source_stream_records_0x4aab7e,
						owner.terrain_policy_0x0c_known,
						owner.terrain_policy_0x0c,
						&owner,
						rng);
		merge_reward_guard_source_stream(aggregate, stream);
		if (!stream.blocked_reason.empty()) {
			return aggregate;
		}
	}
	return aggregate;
}

static int32_t mine_resource_minimum_count_0x4c_0x4a9d6a(const SourceMineRules4a218c &rules, int32_t category_index) {
	switch (category_index) {
		case 0:
			return rules.minimum_wood;
		case 1:
			return rules.minimum_mercury;
		case 2:
			return rules.minimum_ore;
		case 3:
			return rules.minimum_sulfur;
		case 4:
			return rules.minimum_crystal;
		case 5:
			return rules.minimum_gems;
		case 6:
			return rules.minimum_gold;
		default:
			return 0;
	}
}

static int32_t mine_resource_density_count_0x68_0x4a9c7c(const SourceMineRules4a218c &rules, int32_t category_index) {
	switch (category_index) {
		case 0:
			return rules.density_wood;
		case 1:
			return rules.density_mercury;
		case 2:
			return rules.density_ore;
		case 3:
			return rules.density_sulfur;
		case 4:
			return rules.density_crystal;
		case 5:
			return rules.density_gems;
		case 6:
			return rules.density_gold;
		default:
			return 0;
	}
}

static bool descriptor_terrain_bitset_index_test_0x42cc99(uint16_t mask_word_0x18, int32_t terrain_policy_index) {
	if (terrain_policy_index < 0 || terrain_policy_index >= 10) {
		return false;
	}
	return (uint32_t(mask_word_0x18) & (uint32_t(1U) << uint32_t(terrain_policy_index))) != 0U;
}

static bool mine_resource_coordinate_eligibility_0x49aa93(
		const GeneratorObjectPrivateState &state,
		const SourceObjectRecord0x4c &source_record,
		int32_t x,
		int32_t y,
		int32_t level,
		int32_t relation_owner_byte2) {
	const std::vector<SourceObjectMaskPoint490f3f> body_points =
			source_object_text_mask_points_0x490f3f(source_record.passability_mask, false);
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
		if (!generated_cell_49a1d8_valid_record(record)) {
			return false;
		}
		if ((record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
			return false;
		}
		if ((record.word_0x2c & 0x01U) != 0U) {
			return false;
		}
	}
	return true;
}

static int32_t mine_resource_body_pressure_count_0x4a9641(
		const GeneratorObjectPrivateState &state,
		const GeneratorDescriptorVectorEntry0x398 &descriptor,
		int32_t x,
		int32_t y,
		int32_t level,
		int32_t &body_reject_count) {
	const std::vector<CoordinateCandidate4a17f5> body_offsets =
			descriptor_body_offsets_from_primary_mask_0x49a6f9(
					descriptor.source_record_copy,
					descriptor.descriptor_source_cell_x_0x2c,
					descriptor.descriptor_source_cell_y_0x30);
	int32_t body_pressure_count = 0;
	for (const CoordinateCandidate4a17f5 &offset : body_offsets) {
		const int32_t body_x = x + offset.x;
		const int32_t body_y = y + offset.y;
		if (body_y > y) {
			body_reject_count += 1;
			continue;
		}
		const int64_t flat = cell_index(state.width, state.height, body_x, body_y, level);
		if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
			body_reject_count += 1;
			continue;
		}
		const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
		if (!record.word_0x24_known || !record.word_0x28_known) {
			body_reject_count += 1;
			continue;
		}
		if ((record.word_0x28 & CELL_DECOR_READY_BIT_25) == 0U) {
			body_reject_count += 1;
			continue;
		}
		if ((record.word_0x24 & 0x3fU) == 9U) {
			body_reject_count += 1;
			continue;
		}
		if (((record.word_0x28 >> 26U) & 0x1U) == 0U) {
			body_reject_count += 1;
			continue;
		}
		body_pressure_count += 1;
	}
	return body_pressure_count > 5 ? 5 : body_pressure_count;
}

static void mirror_mine_resource_coordinate_builder_fields_0x4a9641(
		MineResourceSelectedObjectCallbackResult4a9911 &result,
		const MineResourceSelectedObjectCallbackResult4a9911 &builder) {
	result.coordinate_builder_0x4a9641_invoked = builder.coordinate_builder_0x4a9641_invoked;
	result.coordinate_builder_0x4a9641_applied = builder.coordinate_builder_0x4a9641_applied;
	result.coordinate_builder_scan_bounds_known_0x20_0x2c = builder.coordinate_builder_scan_bounds_known_0x20_0x2c;
	result.coordinate_builder_scan_low_x_0x20 = builder.coordinate_builder_scan_low_x_0x20;
	result.coordinate_builder_scan_low_y_0x24 = builder.coordinate_builder_scan_low_y_0x24;
	result.coordinate_builder_scan_high_x_0x28 = builder.coordinate_builder_scan_high_x_0x28;
	result.coordinate_builder_scan_high_y_0x2c = builder.coordinate_builder_scan_high_y_0x2c;
	result.coordinate_builder_scanned_cell_count = builder.coordinate_builder_scanned_cell_count;
	result.coordinate_builder_owner_byte_reject_count = builder.coordinate_builder_owner_byte_reject_count;
	result.coordinate_builder_eligibility_reject_count_0x49aa93 = builder.coordinate_builder_eligibility_reject_count_0x49aa93;
	result.coordinate_builder_value_floor_reject_count = builder.coordinate_builder_value_floor_reject_count;
	result.coordinate_builder_distance_reject_count = builder.coordinate_builder_distance_reject_count;
	result.coordinate_builder_body_offset_count_0x18_0x1c = builder.coordinate_builder_body_offset_count_0x18_0x1c;
	result.coordinate_builder_body_reject_count = builder.coordinate_builder_body_reject_count;
	result.coordinate_builder_body_best_count = builder.coordinate_builder_body_best_count;
	result.coordinate_builder_threshold_initial_0x14 = builder.coordinate_builder_threshold_initial_0x14;
	result.coordinate_builder_threshold_after_scan_0x14 = builder.coordinate_builder_threshold_after_scan_0x14;
	result.coordinate_builder_local_vector_clear_count_0x4ae52a_0x4ae27c = builder.coordinate_builder_local_vector_clear_count_0x4ae52a_0x4ae27c;
	result.coordinate_builder_local_vector_append_count_0x4ae1fd = builder.coordinate_builder_local_vector_append_count_0x4ae1fd;
	result.coordinate_builder_candidate_count = builder.coordinate_builder_candidate_count;
	result.coordinate_builder_selected_candidate_index = builder.coordinate_builder_selected_candidate_index;
	result.coordinate_builder_selected_x = builder.coordinate_builder_selected_x;
	result.coordinate_builder_selected_y = builder.coordinate_builder_selected_y;
	result.coordinate_builder_selected_level = builder.coordinate_builder_selected_level;
	result.coordinate_builder_rng_value_0x4e7276 = builder.coordinate_builder_rng_value_0x4e7276;
	result.coordinate_builder_object_record_key = builder.coordinate_builder_object_record_key;
	result.coordinate_builder_object_record_key_known = builder.coordinate_builder_object_record_key_known;
	result.coordinate_builder_commit_appended_0x4a54a7 = builder.coordinate_builder_commit_appended_0x4a54a7;
	result.coordinate_builder_object_vector_count_after = builder.coordinate_builder_object_vector_count_after;
}

static int32_t mine_resource_guard_budget_value_0x4a9911(int32_t category_index) {
	if (category_index == 0 || category_index == 2) {
		return 0x5dc;
	}
	if (category_index == 6) {
		return 0x1b58;
	}
	return 0xdac;
}

static void mirror_mine_resource_guard_followup_fields_0x4a9911(
		MineResourceSelectedObjectCallbackResult4a9911 &result,
		const MineResourceSelectedObjectCallbackResult4a9911 &guard_followup) {
	result.guard_attach_value_gate_invoked_0x4a960a = guard_followup.guard_attach_value_gate_invoked_0x4a960a;
	result.guard_attach_value_gate_0x4a960a = guard_followup.guard_attach_value_gate_0x4a960a;
	result.guard_budget_value_0x4a9911 = guard_followup.guard_budget_value_0x4a9911;
	result.guard_attach_value_positive_0x4a960a = guard_followup.guard_attach_value_positive_0x4a960a;
	result.guard_attach_value_nonpositive_direct_continue = guard_followup.guard_attach_value_nonpositive_direct_continue;
	result.guard_attach_value_0x4a65a5 = guard_followup.guard_attach_value_0x4a65a5;
	result.guard_attach_value_band_0x4a960a = guard_followup.guard_attach_value_band_0x4a960a;
	result.guard_coordinate_adjusted_0x4a9911 = guard_followup.guard_coordinate_adjusted_0x4a9911;
	result.guard_x_0x4a9911 = guard_followup.guard_x_0x4a9911;
	result.guard_y_0x4a9911 = guard_followup.guard_y_0x4a9911;
	result.guard_level_0x4a9911 = guard_followup.guard_level_0x4a9911;
	result.guard_materialization_invoked_0x4a5e03 = guard_followup.guard_materialization_invoked_0x4a5e03;
	result.guard_materialization_committed_0x4a54a7 = guard_followup.guard_materialization_committed_0x4a54a7;
	result.guard_object_record_key_0x4a5e03 = guard_followup.guard_object_record_key_0x4a5e03;
	result.guard_object_record_key_known_0x4a5e03 = guard_followup.guard_object_record_key_known_0x4a5e03;
	result.guard_object_record_sequence_0x1c = guard_followup.guard_object_record_sequence_0x1c;
	result.guard_object_vector_count_after_0x4a54a7 = guard_followup.guard_object_vector_count_after_0x4a54a7;
}

static MineResourceSelectedObjectCallbackResult4a9911 mine_resource_guard_followup_0x4a9911_0x4a960a_0x4a5e03(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &owner,
		const GeneratorDescriptorVectorEntry0x398 &selected,
		const MineResourceSelectedObjectCallbackResult4a9911 &coordinate_builder) {
	MineResourceSelectedObjectCallbackResult4a9911 result;
	result.guard_attach_value_gate_invoked_0x4a960a = true;
	result.guard_budget_value_0x4a9911 =
			mine_resource_guard_budget_value_0x4a9911(selected.descriptor_source_field_0x20);
	result.guard_attach_value_gate_0x4a960a =
			reward_guard_attach_value_gate_0x4a960a(
					state,
					&owner,
					result.guard_budget_value_0x4a9911);
	result.guard_attach_value_band_0x4a960a = result.guard_attach_value_gate_0x4a960a.effective_value_band_0x4a960a;
	result.guard_attach_value_0x4a65a5 = result.guard_attach_value_gate_0x4a960a.scaled_attach_value_0x4a65a5;
	if (!result.guard_attach_value_gate_0x4a960a.applied) {
		result.blocked_reason = result.guard_attach_value_gate_0x4a960a.blocked_reason.empty()
				? "0x4a9911_0x4a960a_guard_attach_value_gate_failed"
				: result.guard_attach_value_gate_0x4a960a.blocked_reason;
		return result;
	}
	if (result.guard_attach_value_0x4a65a5 <= 0) {
		result.guard_attach_value_nonpositive_direct_continue = true;
		result.applied = true;
		return result;
	}

	if (coordinate_builder.coordinate_builder_selected_x < 0
			|| coordinate_builder.coordinate_builder_selected_y < 0
			|| coordinate_builder.coordinate_builder_selected_level < 0) {
		result.blocked_reason = "0x4a9911_guard_coordinate_missing_after_0x4a9641_commit";
		return result;
	}
	if (!selected.descriptor_source_cell_offsets_0x2c_0x30_known) {
		result.blocked_reason = "0x4a9911_guard_descriptor_source_cell_offsets_0x2c_0x30_missing";
		return result;
	}
	if (!state.native_object_record_key_allocator_0x4a93a2_known) {
		result.blocked_reason = "0x4a9911_guard_0x4a5e03_object_key_allocator_missing";
		return result;
	}

	result.guard_attach_value_positive_0x4a960a = true;
	result.guard_coordinate_adjusted_0x4a9911 = true;
	result.guard_x_0x4a9911 =
			coordinate_builder.coordinate_builder_selected_x - selected.descriptor_source_cell_x_0x2c;
	result.guard_y_0x4a9911 =
			coordinate_builder.coordinate_builder_selected_y + (1 - selected.descriptor_source_cell_y_0x30);
	result.guard_level_0x4a9911 = coordinate_builder.coordinate_builder_selected_level;
	result.guard_object_record_key_0x4a5e03 = state.next_native_object_record_key_0x4a93a2;
	result.guard_object_record_key_known_0x4a5e03 = true;
	state.next_native_object_record_key_0x4a93a2 += 1U;
	if (state.object_record_sequence_allocator_0xf44_known) {
		result.guard_object_record_sequence_0x1c = state.object_record_sequence_allocator_0xf44;
		state.object_record_sequence_allocator_0xf44 += 1;
	}
	state.object_record_allocation_count_0x4a93a2 += 1;

	result.guard_materialization_invoked_0x4a5e03 = true;
	const ObjectFootprintCommitResult4a54a7 commit = object_footprint_commit_4a54a7(
			state,
			result.guard_object_record_key_0x4a5e03,
			54,
			result.guard_x_0x4a9911,
			result.guard_y_0x4a9911,
			result.guard_level_0x4a9911,
			true,
			0,
			0,
			&selected.source_record_copy);
	result.guard_materialization_committed_0x4a54a7 = commit.object_vector_appended;
	result.guard_object_vector_count_after_0x4a54a7 = commit.object_vector_count_after;
	if (!commit.object_vector_appended) {
		result.blocked_reason = "0x4a9911_guard_0x4a5e03_0x4a54a7_commit_did_not_append";
		return result;
	}
	if (!state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
		object_record.object_record_vtable_0x00 = OBJECT_RECORD_VTABLE_0X540A88;
		object_record.object_record_sequence_0x1c = result.guard_object_record_sequence_0x1c;
		object_record.object_record_selected_index_0x20 = selected.descriptor_source_field_0x20;
		object_record.object_record_enabled_word_0x24 = 3U;
		object_record.object_record_enabled_low_byte_0x24 = true;
		object_record.mine_resource_guard_record_0x4a9911_0x4a5e03_known = true;
		object_record.mine_resource_guard_arg0_0x4a5e03 = uint32_t(result.guard_attach_value_0x4a65a5);
		object_record.mine_resource_guard_protected_object_key = coordinate_builder.coordinate_builder_object_record_key;
		object_record.mine_resource_guard_source_category_0x20 = selected.descriptor_source_field_0x20;
		object_record.mine_resource_guard_selected_source_catalog_index_0x49da08 =
				selected.source_catalog_index_0x49da08;
	}
	result.applied = true;
	return result;
}

static MineResourceSelectedObjectCallbackResult4a9911 mine_resource_coordinate_builder_0x4a9641(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &owner,
		const GeneratorDescriptorVectorEntry0x398 &selected,
		bool force_flag_0x0f,
		int32_t threshold_arg_0x14,
		H3MapedRng &rng) {
	MineResourceSelectedObjectCallbackResult4a9911 result;
	result.coordinate_builder_0x4a9641_invoked = true;
	result.owner_vector_index = owner.owner_vector_index;
	result.runtime_zone_index = owner.runtime_zone_index;
	result.category_index = selected.descriptor_source_field_0x20;
	result.selected = true;
	result.selected_descriptor_vector_index_0x388 = selected.vector_index;
	result.selected_source_catalog_index_0x49da08 = selected.source_catalog_index_0x49da08;
	result.selected_descriptor_type_0x1c = selected.descriptor_type_0x1c;
	result.selected_source_field_0x20 = selected.descriptor_source_field_0x20;
	result.selected_def_name = selected.source_record_copy.def_name;
	result.force_flag_0x0f = force_flag_0x0f;
	result.policy_arg_0x10 = threshold_arg_0x14;
	result.coordinate_builder_scan_bounds_known_0x20_0x2c = relation_scan_bounds_0x4a7312_non_sentinel(owner);
	result.coordinate_builder_scan_low_x_0x20 = owner.scan_bound_low_x_0x20;
	result.coordinate_builder_scan_low_y_0x24 = owner.scan_bound_low_y_0x24;
	result.coordinate_builder_scan_high_x_0x28 = owner.scan_bound_high_x_0x28;
	result.coordinate_builder_scan_high_y_0x2c = owner.scan_bound_high_y_0x2c;
	result.coordinate_builder_threshold_initial_0x14 = threshold_arg_0x14;
	result.coordinate_builder_threshold_after_scan_0x14 = threshold_arg_0x14;
	result.coordinate_builder_body_offset_count_0x18_0x1c =
			int32_t(descriptor_body_offsets_from_primary_mask_0x49a6f9(
					selected.source_record_copy,
					selected.descriptor_source_cell_x_0x2c,
					selected.descriptor_source_cell_y_0x30).size());

	if (!state.generated_cell_buffer_owned || state.generated_cell_buffer.records.empty()) {
		result.blocked_reason = "0x4a9641_generated_cell_buffer_missing";
		return result;
	}
	if (!result.coordinate_builder_scan_bounds_known_0x20_0x2c) {
		result.blocked_reason = "0x4a9641_relation_scan_bounds_0x20_0x2c_missing_or_sentinel";
		return result;
	}
	if (owner.runtime_zone_index < 0) {
		result.blocked_reason = "0x4a9641_relation_owner_byte2_missing";
		return result;
	}
	if (force_flag_0x0f && !owner.coordinate_triple_0x10_0x18_known) {
		result.blocked_reason = "0x4a9641_force_distance_anchor_0x30_missing";
		return result;
	}
	if (!state.native_object_record_key_allocator_0x4a93a2_known) {
		result.blocked_reason = "0x4a9641_selected_object_key_allocator_missing_before_0x5044b1";
		return result;
	}

	std::vector<CoordinateCandidate4a17f5> accepted_candidates;
	int32_t current_threshold = threshold_arg_0x14;
	int32_t best_distance_squared = 0x9c40;
	int32_t best_body_count = 0;
	const int32_t level = owner.coordinate_triple_0x10_0x18_known ? owner.coordinate_level_0x18 : 0;
	for (int32_t y = owner.scan_bound_low_y_0x24; y < owner.scan_bound_high_y_0x2c; ++y) {
		for (int32_t x = owner.scan_bound_low_x_0x20; x < owner.scan_bound_high_x_0x28; ++x) {
			result.coordinate_builder_scanned_cell_count += 1;
			const int64_t flat = cell_index(state.width, state.height, x, y, level);
			if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
				result.coordinate_builder_eligibility_reject_count_0x49aa93 += 1;
				continue;
			}
			const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
			if (!record.word_0x20_known) {
				result.coordinate_builder_eligibility_reject_count_0x49aa93 += 1;
				continue;
			}
			if (generated_cell_word20_owner_byte2(record.word_0x20) != uint8_t(owner.runtime_zone_index & 0xff)) {
				result.coordinate_builder_owner_byte_reject_count += 1;
				continue;
			}
			if (!mine_resource_coordinate_eligibility_0x49aa93(
						state,
						selected.source_record_copy,
						x,
						y,
						level,
						owner.runtime_zone_index)) {
				result.coordinate_builder_eligibility_reject_count_0x49aa93 += 1;
				continue;
			}

			if (force_flag_0x0f) {
				const int64_t dx = int64_t(x) - int64_t(owner.coordinate_x_0x10);
				const int64_t dy = int64_t(y) - int64_t(owner.coordinate_y_0x14);
				const int64_t distance64 = dx * dx + dy * dy;
				if (distance64 > int64_t(best_distance_squared) || distance64 < 0x10) {
					result.coordinate_builder_distance_reject_count += 1;
					continue;
				}
				const int32_t candidate_distance = int32_t(distance64 < 0x90 ? 0x90 : distance64);
				if (candidate_distance < best_distance_squared) {
					best_distance_squared = candidate_distance;
					accepted_candidates.clear();
					result.coordinate_builder_local_vector_clear_count_0x4ae52a_0x4ae27c += 1;
				}
			}

			const int32_t low_word_score = int32_t(record.word_0x20 & 0xffffU);
			if (low_word_score < current_threshold) {
				result.coordinate_builder_value_floor_reject_count += 1;
				continue;
			}

			const int32_t body_count = mine_resource_body_pressure_count_0x4a9641(
					state,
					selected,
					x,
					y,
					level,
					result.coordinate_builder_body_reject_count);
			if (body_count < best_body_count) {
				result.coordinate_builder_body_reject_count += 1;
				continue;
			}
			if (body_count > best_body_count) {
				best_body_count = body_count;
				result.coordinate_builder_body_best_count = best_body_count;
				accepted_candidates.clear();
				result.coordinate_builder_local_vector_clear_count_0x4ae52a_0x4ae27c += 1;
			}
			if (low_word_score > current_threshold) {
				current_threshold = low_word_score;
				result.coordinate_builder_threshold_after_scan_0x14 = current_threshold;
				accepted_candidates.clear();
				result.coordinate_builder_local_vector_clear_count_0x4ae52a_0x4ae27c += 1;
			}
			accepted_candidates.push_back(CoordinateCandidate4a17f5 { x, y, level });
			result.coordinate_builder_local_vector_append_count_0x4ae1fd += 1;
		}
	}

	result.coordinate_builder_candidate_count = int32_t(accepted_candidates.size());
	if (accepted_candidates.empty()) {
		result.blocked_reason = "0x4a9641_candidate_vector_empty_after_owner_0x49aa93_value_body_filters";
		return result;
	}

	result.coordinate_builder_rng_value_0x4e7276 = rng.next();
	result.coordinate_builder_selected_candidate_index =
			result.coordinate_builder_rng_value_0x4e7276 % result.coordinate_builder_candidate_count;
	const CoordinateCandidate4a17f5 selected_coordinate =
			accepted_candidates[size_t(result.coordinate_builder_selected_candidate_index)];
	result.coordinate_builder_selected_x = selected_coordinate.x;
	result.coordinate_builder_selected_y = selected_coordinate.y;
	result.coordinate_builder_selected_level = selected_coordinate.level;
	result.coordinate_builder_object_record_key = state.next_native_object_record_key_0x4a93a2;
	result.coordinate_builder_object_record_key_known = true;
	state.next_native_object_record_key_0x4a93a2 += 1U;
	int32_t allocated_sequence = -1;
	if (state.object_record_sequence_allocator_0xf44_known) {
		allocated_sequence = state.object_record_sequence_allocator_0xf44;
		state.object_record_sequence_allocator_0xf44 += 1;
	}
	state.object_record_allocation_count_0x4a93a2 += 1;

	const ObjectFootprintCommitResult4a54a7 commit = object_footprint_commit_4a54a7(
			state,
			result.coordinate_builder_object_record_key,
			selected.descriptor_type_0x1c,
			selected_coordinate.x,
			selected_coordinate.y,
			selected_coordinate.level,
			selected.descriptor_projection_enabled_0x29,
			selected.descriptor_source_cell_x_0x2c,
			selected.descriptor_source_cell_y_0x30,
			&selected.source_record_copy);
	result.coordinate_builder_commit_appended_0x4a54a7 = commit.object_vector_appended;
	result.coordinate_builder_object_vector_count_after = commit.object_vector_count_after;
	if (!commit.object_vector_appended) {
		result.blocked_reason = "0x4a9641_vtable_slot_0x04_object_commit_did_not_append";
		return result;
	}
	if (!state.object_records_0xec4_ecc.empty()) {
		ObjectRecordReference4a54a7 &object_record = state.object_records_0xec4_ecc.back();
		object_record.object_record_vtable_0x00 = OBJECT_RECORD_VTABLE_0X540AB0;
		object_record.object_record_sequence_0x1c = allocated_sequence;
		object_record.object_record_selected_index_0x20 = selected.descriptor_source_field_0x20;
		object_record.source_catalog_index_0x49da08 = selected.source_catalog_index_0x49da08;
		object_record.copied_source_record_carried = true;
		object_record.source_record_copy = selected.source_record_copy;
	}
	result.selected_object_allocated_0x5044b1 = true;
	result.selected_object_initialized_0x49ba89 = true;
	result.selected_object_vtable_0x540ab0 = OBJECT_RECORD_VTABLE_0X540AB0;
	result.coordinate_builder_0x4a9641_applied = true;
	result.applied = true;
	return result;
}

static MineResourceSelectedObjectCallbackResult4a9911 mine_resource_selected_object_callback_0x4a9911(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &owner,
		int32_t category_index,
		bool force_flag_0x0f,
		int32_t policy_arg_0x10,
		H3MapedRng &rng) {
	MineResourceSelectedObjectCallbackResult4a9911 result;
	result.invoked = true;
	result.owner_vector_index = owner.owner_vector_index;
	result.runtime_zone_index = owner.runtime_zone_index;
	result.category_index = category_index;
	result.force_flag_0x0f = force_flag_0x0f;
	result.policy_arg_0x10 = policy_arg_0x10;
	result.relation_terrain_policy_0x0c_known = owner.terrain_policy_0x0c_known;
	result.relation_terrain_policy_0x0c = owner.terrain_policy_0x0c;
	result.descriptor_bucket_0x388_0x38c_known =
			state.mine_resource_descriptor_vector_388_38c_source_owned
			&& state.mine_resource_descriptor_vector_entry_count_388_38c > 0
			&& !state.mine_resource_descriptor_vector_entries_388_38c.empty();
	result.descriptor_bucket_count_0x388_0x38c = state.mine_resource_descriptor_vector_entry_count_388_38c;
	result.rng_state_before_0x4e7276 = rng.state;
	result.rng_state_after_0x4e7276 = rng.state;
	if (!result.descriptor_bucket_0x388_0x38c_known) {
		result.blocked_reason = "0x4a9911_generator_plus_0x388_0x38c_mine_resource_descriptor_bucket_missing";
		return result;
	}
	if (!owner.terrain_policy_0x0c_known) {
		result.blocked_reason = "0x4a9911_relation_terrain_policy_0x0c_missing_before_0x42cc99";
		return result;
	}

	std::vector<const GeneratorDescriptorVectorEntry0x398 *> accepted_candidates;
	for (const GeneratorDescriptorVectorEntry0x398 &entry : state.mine_resource_descriptor_vector_entries_388_38c) {
		result.descriptor_scan_count += 1;
		if (entry.descriptor_source_field_0x20 != category_index) {
			continue;
		}
		result.category_match_count += 1;
		result.first_pass_terrain_test_count_0x42cc99 += 1;
		if (descriptor_terrain_bitset_index_test_0x42cc99(entry.source_record_copy.terrain_mask_b_0x18, owner.terrain_policy_0x0c)) {
			result.first_pass_terrain_match_count_0x42cc99 += 1;
			accepted_candidates.push_back(&entry);
		}
	}

	if (accepted_candidates.empty()) {
		result.fallback_pass_used = true;
		for (const GeneratorDescriptorVectorEntry0x398 &entry : state.mine_resource_descriptor_vector_entries_388_38c) {
			result.fallback_scan_count += 1;
			if (entry.descriptor_source_field_0x20 != category_index) {
				continue;
			}
			result.fallback_match_count_0x40bb26 += 1;
			accepted_candidates.push_back(&entry);
		}
	}

	result.accepted_count = int32_t(accepted_candidates.size());
	if (accepted_candidates.empty()) {
		result.blocked_reason = "0x4a9911_no_mine_resource_descriptor_candidate_for_category";
		return result;
	}

	result.rng_value_0x4e7276 = rng.next();
	result.rng_state_after_0x4e7276 = rng.state;
	result.selected_candidate_index = result.rng_value_0x4e7276 % result.accepted_count;
	const GeneratorDescriptorVectorEntry0x398 &selected = *accepted_candidates[size_t(result.selected_candidate_index)];
	result.selected = true;
	result.selected_descriptor_vector_index_0x388 = selected.vector_index;
	result.selected_source_catalog_index_0x49da08 = selected.source_catalog_index_0x49da08;
	result.selected_descriptor_type_0x1c = selected.descriptor_type_0x1c;
	result.selected_source_field_0x20 = selected.descriptor_source_field_0x20;
	result.selected_def_name = selected.source_record_copy.def_name;
	result.selected_object_allocated_0x5044b1 = true;
	result.selected_object_initialized_0x49ba89 = true;
	result.selected_object_vtable_0x540ab0 = OBJECT_RECORD_VTABLE_0X540AB0;
	const MineResourceSelectedObjectCallbackResult4a9911 coordinate_builder =
			mine_resource_coordinate_builder_0x4a9641(
					state,
					owner,
					selected,
					force_flag_0x0f,
					policy_arg_0x10,
					rng);
	mirror_mine_resource_coordinate_builder_fields_0x4a9641(result, coordinate_builder);
	if (!coordinate_builder.applied) {
		result.blocked_reason = coordinate_builder.blocked_reason.empty()
				? "0x4a9641_coordinate_builder_not_applied"
				: coordinate_builder.blocked_reason;
		return result;
	}
	const MineResourceSelectedObjectCallbackResult4a9911 guard_followup =
			mine_resource_guard_followup_0x4a9911_0x4a960a_0x4a5e03(
					state,
					owner,
					selected,
					coordinate_builder);
	mirror_mine_resource_guard_followup_fields_0x4a9911(result, guard_followup);
	if (!guard_followup.applied) {
		result.blocked_reason = guard_followup.blocked_reason.empty()
				? "0x4a9911_guard_followup_0x4a960a_0x4a5e03_not_applied"
				: guard_followup.blocked_reason;
		return result;
	}
	result.applied = true;
	return result;
}

static bool mine_resource_density_failure_disables_0x4a9c7c(const std::string &reason) {
	return reason.empty()
			|| reason == "0x4a9911_no_mine_resource_descriptor_candidate_for_category"
			|| reason == "0x4a9641_candidate_vector_empty_after_owner_0x49aa93_value_body_filters";
}

static int32_t mine_resource_density_threshold_0x4a9c7c(int32_t density_total) {
	if (density_total <= 0) {
		return 0;
	}
	const int32_t quotient = 0x14400 / density_total;
	return int32_t(std::sqrt(double(quotient)));
}

static bool mine_resource_density_followup_0x4a9c7c(
		GeneratorObjectPrivateState &state,
		const GeneratorRelationOwnerState4a218c &owner,
		std::array<MineResourceMaterializationCategory4a9d6a, 7> &categories,
		MineResourceMaterializationResult4a9d6a &result,
		H3MapedRng &rng) {
	result.density_followup_0x4a9c7c_reached = true;
	int32_t density_total = 0;
	int32_t density_product = 1;
	for (MineResourceMaterializationCategory4a9d6a &category : categories) {
		if (category.density_count <= 0) {
			category.density_disabled_0x4a9c7c = true;
			continue;
		}
		category.density_active_0x4a9c7c = true;
		result.density_active_category_count_0x4a9c7c += 1;
		density_total += category.density_count;
		density_product *= category.density_count;
	}
	if (density_total <= 0) {
		result.density_followup_0x4a9c7c_applied = true;
		return true;
	}

	result.density_product_0x4a9c7c = density_product;
	result.density_threshold_0x4e7dec = mine_resource_density_threshold_0x4a9c7c(density_total);
	for (MineResourceMaterializationCategory4a9d6a &category : categories) {
		if (!category.density_active_0x4a9c7c || category.density_disabled_0x4a9c7c) {
			continue;
		}
		category.density_step_0x4a9c7c =
				category.density_count > 0 ? density_product / category.density_count : 0;
		category.density_counter_initial_0x4a9c7c =
				category.required_count_0x4c * category.density_step_0x4a9c7c;
		category.density_counter_current_0x4a9c7c = category.density_counter_initial_0x4a9c7c;
	}

	while (true) {
		int32_t selected_category = -1;
		int32_t selected_counter = 0;
		for (int32_t category_index = 0; category_index <= 6; ++category_index) {
			const MineResourceMaterializationCategory4a9d6a &category = categories[size_t(category_index)];
			if (!category.density_active_0x4a9c7c || category.density_disabled_0x4a9c7c) {
				continue;
			}
			if (selected_category < 0 || category.density_counter_current_0x4a9c7c < selected_counter) {
				selected_category = category_index;
				selected_counter = category.density_counter_current_0x4a9c7c;
			}
		}
		if (selected_category < 0) {
			break;
		}

		MineResourceMaterializationCategory4a9d6a &category = categories[size_t(selected_category)];
		category.density_counter_current_0x4a9c7c += category.density_step_0x4a9c7c;
		category.density_attempted_callback_count_0x4a9911 += 1;
		result.density_scheduler_selection_count_0x4a9c7c += 1;
		result.density_callback_attempt_count_0x4a9911 += 1;
		result.callback_attempt_count_0x4a9911 += 1;
		category.density_selected_object_callback_0x4a9911 =
				mine_resource_selected_object_callback_0x4a9911(
						state,
						owner,
						selected_category,
						false,
						result.density_threshold_0x4e7dec,
						rng);
		if (category.density_selected_object_callback_0x4a9911.applied
				&& category.density_selected_object_callback_0x4a9911.blocked_reason.empty()) {
			category.density_successful_callback_count_0x4a9911 += 1;
			result.density_successful_count_0x4a9911 += 1;
			result.successful_count_0x4a9911 += 1;
			continue;
		}

		const std::string failure_reason = category.density_selected_object_callback_0x4a9911.blocked_reason;
		category.density_disabled_0x4a9c7c = true;
		category.density_disabled_after_failure_0x4a9c7c = true;
		result.density_disabled_count_0x4a9c7c += 1;
		if (!mine_resource_density_failure_disables_0x4a9c7c(failure_reason)) {
			category.blocked_reason = failure_reason.empty()
					? "0x4a9c7c_density_0x4a9911_selected_object_callback_not_applied"
					: failure_reason;
			result.blocked_reason = category.blocked_reason;
			return false;
		}
	}

	result.density_followup_0x4a9c7c_applied = true;
	return true;
}

static MineResourceMaterializationResult4a9d6a mine_resource_materialization_0x4a9d6a(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	MineResourceMaterializationResult4a9d6a result;
	result.invoked = true;
	result.relation_vector_known =
			state.relation_vector_10e4_10e8.present
			&& state.relation_vector_10e4_10e8.count_known
			&& state.relation_owner_records_10e4_10e8_partial_known;
	result.relation_owner_count = int32_t(state.relation_owner_vectors_10e4_10e8.size());
	if (!result.relation_vector_known) {
		result.blocked_reason = "0x4a9d6a_relation_vector_10e4_10e8_missing_before_mine_resource_materialization";
		return result;
	}

	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (!owner.mine_resource_rules_0x4c_0x84_known) {
			result.blocked_reason = "0x4a9d6a_relation_leading_descriptor_mine_counts_0x4c_missing";
			return result;
		}
		std::array<MineResourceMaterializationCategory4a9d6a, 7> owner_categories;
		for (int32_t category = 0; category <= 6; ++category) {
			MineResourceMaterializationCategory4a9d6a &category_result = owner_categories[size_t(category)];
			category_result.owner_vector_index = owner.owner_vector_index;
			category_result.runtime_zone_index = owner.runtime_zone_index;
			category_result.relation_source_index_0x00 = owner.source_pointer_source_index_0x00;
			category_result.category_index = category;
			category_result.required_count_0x4c = mine_resource_minimum_count_0x4c_0x4a9d6a(owner.mine_resource_rules_0x4c_0x84, category);
			category_result.density_count = mine_resource_density_count_0x68_0x4a9c7c(owner.mine_resource_rules_0x4c_0x84, category);
			if ((category == 0 || category == 2)
					&& owner.source_pointer_type_0x04_known
					&& (owner.source_pointer_type_0x04 == 0 || owner.source_pointer_type_0x04 == 1)
					&& owner.byte_0x3c_known
					&& owner.byte_0x3c != 0U) {
				category_result.force_flag_from_relation_byte_0x3c = true;
			}
			result.category_scan_count += 1;
			result.required_total_count_0x4c += category_result.required_count_0x4c;
			result.density_total_count += category_result.density_count;
		}
		for (int32_t category = 0; category <= 6; ++category) {
			MineResourceMaterializationCategory4a9d6a &category_result = owner_categories[size_t(category)];
			if (category_result.required_count_0x4c > 0) {
				bool force_flag = category_result.force_flag_from_relation_byte_0x3c;
				for (int32_t attempt = 0; attempt < category_result.required_count_0x4c; ++attempt) {
					category_result.attempted_callback_count_0x4a9911 += 1;
					category_result.selected_object_callback_0x4a9911 =
							mine_resource_selected_object_callback_0x4a9911(
									state,
									owner,
									category,
									force_flag,
									0,
									rng);
					result.callback_attempt_count_0x4a9911 += 1;
					if (!category_result.selected_object_callback_0x4a9911.applied
							|| !category_result.selected_object_callback_0x4a9911.blocked_reason.empty()) {
						category_result.blocked_reason =
								category_result.selected_object_callback_0x4a9911.blocked_reason.empty()
								? "0x4a9911_selected_object_callback_not_applied_before_mine_resource_commit"
								: category_result.selected_object_callback_0x4a9911.blocked_reason;
						result.blocked_reason = category_result.blocked_reason;
						result.categories.insert(result.categories.end(), owner_categories.begin(), owner_categories.end());
						return result;
					}
					force_flag = false;
					category_result.successful_callback_count_0x4a9911 += 1;
					result.successful_count_0x4a9911 += 1;
				}
			}
		}
		if (!mine_resource_density_followup_0x4a9c7c(state, owner, owner_categories, result, rng)) {
			result.categories.insert(result.categories.end(), owner_categories.begin(), owner_categories.end());
			if (result.blocked_reason.empty()) {
				result.blocked_reason = "0x4a9c7c_density_followup_not_applied";
			}
			return result;
		}
		result.categories.insert(result.categories.end(), owner_categories.begin(), owner_categories.end());
	}

	result.applied = true;
	return result;
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

static std::vector<GeneratorRelationOwnerState4a218c> relation_owner_records_from_runtime_seed_0x4a218c_0x49f7c4(const RuntimeSeedBuildResult4a218c &runtime_seed, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones_after_0x49b3c1, const std::vector<RuntimeZoneBoundaryInput4a3a03> &boundary_inputs_after_0x4a19ed, const std::vector<CoordinatePlacementStep4a1f3b> &placement_steps_after_0x4a1f3b, const RuntimeTerrainSelectionResult49b53d *terrain_selection, int32_t &missing_endpoint_count) {
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
		apply_relation_owner_terrain_policy_0x49b53d(owner, runtime_terrain_selection_for_runtime_zone_0x49b53d(terrain_selection, seed.runtime_zone_index));
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

static bool produce_relation_owner_vector_from_selected_candidate_0x4ac552_0x4a218c(GeneratorObjectPrivateState &state, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result) {
	state.relation_owner_vector_produced_by_0x4ac552_0x4a218c = false;
	state.relation_owner_vector_selected_candidate_input_known = false;
	state.relation_owner_vector_producer_blocked_reason.clear();
	state.relation_owner_vector_selected_candidate_source_catalog_index = -1;
	state.relation_owner_vector_selected_candidate_template_name.clear();
	state.relation_owner_vector_selected_candidate_source_zone_count = 0;
	state.relation_owner_vector_selected_candidate_source_link_count = 0;
	state.relation_owner_vectors_10e4_10e8.clear();
	state.relation_owner_vector_count_10e4_10e8 = 0;
	state.relation_record_count_10e4_10e8 = 0;
	state.relation_record_missing_endpoint_count_10e4_10e8 = 0;
	state.relation_owner_records_10e4_10e8_partial_known = false;
	state.weighted_scheduler_thresholds_0x4a8db2_known = false;
	state.weighted_scheduler_threshold_count_0x4a8db2 = 0;
	state.weighted_scheduler_thresholds_0x4a8db2.clear();
	state.relation_vector_10e4_10e8.contents_known = false;
	state.relation_vector_10e4_10e8.count_known = false;
	state.relation_vector_10e4_10e8.count = 0;
	state.reward_guard_relation_priority_0x4ad7f7.relation_owner_count = 0;

	if (!state.candidate_container_vector_10d4_10d8.present
			|| !state.candidate_container_vector_10d4_10d8.contents_known
			|| !state.candidate_container_vector_10d4_10d8.count_known
			|| state.candidate_container_vector_10d4_10d8.count != int32_t(state.candidate_container_records_10d4_10d8.size())) {
		state.relation_owner_vector_producer_blocked_reason =
				"0x4ac552_candidate_container_vector_0x10d4_0x10d8_not_owned_before_0x4a218c";
		return false;
	}
	if (!state.selected_candidate_container_0x4ac552_known
			|| template_selection.selected_vector_index < 0
			|| template_selection.selected_vector_index >= int32_t(state.candidate_container_records_10d4_10d8.size())) {
		state.relation_owner_vector_producer_blocked_reason =
				"0x4ac552_selected_candidate_container_not_owned_before_0x4a218c";
		return false;
	}
	const TemplateCandidateContainerRecord4ac552 &selected_candidate =
			state.candidate_container_records_10d4_10d8[size_t(template_selection.selected_vector_index)];
	if (selected_candidate.source_catalog_index != template_selection.selected_source_catalog_index
			|| selected_candidate.template_name != template_selection.selected_template_name) {
		state.relation_owner_vector_producer_blocked_reason =
				"0x4ac552_selected_candidate_container_mismatch_before_0x4a218c";
		return false;
	}
	if (template_selection.blocked || template_selection.runtime_seed.blocked) {
		state.relation_owner_vector_producer_blocked_reason =
				"0x4ac552_selected_candidate_runtime_seed_blocked_before_0x4a218c";
		return false;
	}
	if (template_selection.runtime_seed.runtime_zone_seeds.empty()) {
		state.relation_owner_vector_producer_blocked_reason =
				"0x4ac552_selected_candidate_runtime_zone_vector_empty_before_0x4a218c";
		return false;
	}

	state.relation_owner_vector_selected_candidate_input_known = true;
	state.relation_owner_vector_selected_candidate_source_catalog_index = selected_candidate.source_catalog_index;
	state.relation_owner_vector_selected_candidate_template_name = selected_candidate.template_name;
	state.relation_owner_vector_selected_candidate_source_zone_count = selected_candidate.zone_count;
	state.relation_owner_vector_selected_candidate_source_link_count = selected_candidate.link_count;

	state.relation_owner_records_10e4_10e8_partial_known = true;
	state.relation_owner_vectors_10e4_10e8 =
			relation_owner_records_from_runtime_seed_0x4a218c_0x49f7c4(
					template_selection.runtime_seed,
					coordinate_result.coordinate_seed.runtime_zone_records_after_0x49b3c1,
					coordinate_result.coordinate_seed.boundary_inputs,
					coordinate_result.coordinate_seed.placement_steps,
					coordinate_result.terrain_selection_executed ? &coordinate_result.terrain_selection : nullptr,
					state.relation_record_missing_endpoint_count_10e4_10e8);
	state.relation_owner_vector_count_10e4_10e8 = int32_t(state.relation_owner_vectors_10e4_10e8.size());
	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		state.relation_record_count_10e4_10e8 += owner.relation_record_count;
	}
	state.relation_vector_10e4_10e8.present = true;
	state.relation_vector_10e4_10e8.contents_known = true;
	state.relation_vector_10e4_10e8.count_known = true;
	state.relation_vector_10e4_10e8.count = state.relation_owner_vector_count_10e4_10e8;
	state.weighted_scheduler_thresholds_0x4a8db2_known = true;
	state.weighted_scheduler_thresholds_0x4a8db2.reserve(template_selection.runtime_seed.runtime_zone_seeds.size());
	for (const RuntimeZoneSeedInput4a218c &runtime_zone : template_selection.runtime_seed.runtime_zone_seeds) {
		state.weighted_scheduler_thresholds_0x4a8db2.push_back(weighted_scheduler_threshold_0x4a8db2(runtime_zone.source_payload));
	}
	state.weighted_scheduler_threshold_count_0x4a8db2 = int32_t(state.weighted_scheduler_thresholds_0x4a8db2.size());
	apply_relation_owner_scan_bounds_from_generated_cells_0x4a1f3b(state);
	state.reward_guard_relation_priority_0x4ad7f7.relation_owner_count = state.relation_owner_vector_count_10e4_10e8;
	state.relation_owner_vector_produced_by_0x4ac552_0x4a218c = true;
	return true;
}

static void apply_endpoint_materialization_state_d014(GeneratorObjectPrivateState &state, const std::string &size_class, const std::string &water_mode, uint32_t seed, int32_t human_count, int32_t player_count, bool setup_object_0x44_known, int32_t setup_object_0x44) {
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
	state.connection_fallback_materialization_scope_known = true;
	state.connection_fallback_materialization_scope_size_class = size_class;
	state.connection_fallback_materialization_scope_water_mode = water_mode;
	state.connection_fallback_materialization_scope_width = state.width;
	state.connection_fallback_materialization_scope_height = state.height;
	state.connection_fallback_materialization_scope_level_count = state.level_count;
	state.connection_fallback_materialization_scope_seed = seed;
	state.connection_fallback_materialization_scope_human_count = human_count;
	state.connection_fallback_materialization_scope_player_count = player_count;
	state.connection_fallback_materialization_scope_setup_object_0x44_known = setup_object_0x44_known;
	state.connection_fallback_materialization_scope_setup_object_0x44 = setup_object_0x44;
	state.connection_fallback_materialization_records_0x4a7605_0x4a5e03 =
			recovered_supported_land_connection_fallback_records_4a7605_4a5e03_for_scope(
					size_class,
					water_mode,
					state.width,
					state.height,
					state.level_count,
					seed,
					human_count,
					player_count,
					setup_object_0x44_known,
					setup_object_0x44);
	state.connection_fallback_materialization_records_available_for_scope =
			!state.connection_fallback_materialization_records_0x4a7605_0x4a5e03.empty();
	state.connection_fallback_materialization_0x4a7605_0x4a5e03_known = true;
	state.connection_fallback_materialization_record_count =
			int32_t(state.connection_fallback_materialization_records_0x4a7605_0x4a5e03.size());
	state.connection_fallback_materialization_commit_count = 0;
	state.connection_fallback_materialization_blocked_count = 0;
	state.connection_fallback_materialization_first_blocked_record_index = -1;
	state.connection_fallback_materialization_first_blocked_reason.clear();
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

static void apply_relation_high_owner_propagation_49a318(GeneratorObjectPrivateState &state) {
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
}

static void apply_materialization_bridge_relation_normalization_0x4a5767(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	apply_relation_normalization_full_grid_reset_0x4a5767(state);
	SourceObjectResolverState4af785 relation_scan_resolver_state;
	H3MapedRng relation_scan_rng;
	relation_scan_rng.state = rng.state;
	const RelationScanConsumerResult4a5767 relation_scan_consumers =
			relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(
					state,
					relation_scan_resolver_state,
					relation_scan_rng,
					state.relation_owner_vectors_10e4_10e8);
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
	apply_relation_high_owner_propagation_49a318(state);
	rng.state = relation_scan_rng.state;
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
			sync_generated_cell_byte_0x2b_from_word28(record);
		}
		if (index < word_0x2c.size()) {
			record.word_0x2c_known = true;
			record.word_0x2c = word_0x2c[index];
		}
	}
}

static const RuntimeZoneSeedInput4a218c *runtime_zone_after_town_choice_0x49b3c1(const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones_after_0x49b3c1, int32_t runtime_zone_index);

static const SourceObjectRecord0x4c *source_type98_town_record_for_choice_0x49b3c1(int32_t town_choice) {
	if (town_choice < 0) {
		return nullptr;
	}
	const std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
	for (const SourceObjectRecord0x4c &record : records) {
		if (record.type_id_0x1c == 98 && record.subtype_0x20 == town_choice && record.group_0x24 == 1) {
			return &record;
		}
	}
	return nullptr;
}

static SourceObjectDescriptor4903e8 source_type98_town_descriptor_from_record_0x4a8db2(const SourceObjectRecord0x4c &record) {
	SourceObjectDescriptor4903e8 descriptor;
	descriptor.target_context_0x4903e8 = 98;
	descriptor.source_key_0x00 = record.source_row;
	descriptor.descriptor_type_0x1c = record.type_id_0x1c;
	descriptor.subtype_0x20 = record.subtype_0x20;
	descriptor.group_0x24 = record.group_0x24;
	descriptor.projection_enabled_0x29 = true;
	descriptor.source_cell_x_0x2c = 2;
	descriptor.source_cell_y_0x30 = 0;
	descriptor.descriptor_mask_fields_0x34_0x48_known = record.descriptor_mask_fields_0x34_0x48_known;
	descriptor.descriptor_width_0x34 = record.descriptor_width_0x34;
	descriptor.descriptor_height_0x38 = record.descriptor_height_0x38;
	descriptor.descriptor_mask_a_0x3c_0x40 = record.descriptor_mask_a_0x3c_0x40;
	descriptor.descriptor_mask_b_0x44_0x48 = record.descriptor_mask_b_0x44_0x48;
	return descriptor;
}

static void append_blocked_source_order_scheduler_replay_0x4a8db2(GeneratorObjectPrivateState &state, const SourceOrderSchedulerSourceRecord4a8db2 &source_record, int32_t relation_owner_byte2, const std::string &reason) {
	SourceOrderSchedulerResult4a8db2 result;
	result.source_pair_pointer_carried = source_record.source_id_0x00 >= 0;
	result.source_record_id_0x00 = source_record.source_id_0x00;
	result.source_record_owner_or_type_0x04 = source_record.owner_or_type_0x04;
	result.source_record_relation_selector_0x1c = source_record.relation_selector_0x1c;
	result.context_pointer_carried = false;
	result.lane_state_0xee4 = -1;
	result.relation_owner_byte_known = relation_owner_byte2 >= 0;
	result.relation_owner_byte2 = relation_owner_byte2;
	result.blocked_reason = reason;
	result.replay_finished = false;
	state.source_order_scheduler_replay_0x4a8db2_known = true;
	state.source_order_scheduler_replays_0x4a8db2.push_back(result);
	state.source_order_scheduler_replay_count_0x4a8db2 = int32_t(state.source_order_scheduler_replays_0x4a8db2.size());
	state.source_order_scheduler_blocked_count_0x4a8db2 += 1;
}

static std::string source_order_relation_pointer_loop_blocker_detail_0x4ac552(const GeneratorObjectPrivateState &state) {
	std::ostringstream detail;
	detail << "0x4ac552_relation_pointer_0x10e4_0x10e8_source_record_not_owned_before_0x4a8c15"
			<< ":relations=" << state.source_order_relation_pointer_loop_relation_count_0x10e4
			<< ",source_pointer_known=" << state.source_order_relation_pointer_loop_source_pointer_known_count
			<< ",source_record_field_0x04_known=" << state.source_order_relation_pointer_loop_source_record_field_0x04_known_count
			<< ",scan_bounds_known=" << state.source_order_relation_pointer_loop_scan_bounds_known_count
			<< ",missing_source_pointer=" << state.source_order_relation_pointer_loop_missing_source_pointer_count
			<< ",missing_source_record_field_0x04=" << state.source_order_relation_pointer_loop_missing_source_record_field_0x04_count
			<< ",missing_scan_bounds=" << state.source_order_relation_pointer_loop_missing_scan_bounds_count
			<< ",no_source_record_skips=" << state.source_order_relation_pointer_loop_no_source_record_skip_count
			<< ",direct_replays_0x4a8d2c=" << state.source_order_relation_pointer_loop_direct_replay_count_0x4a8d2c
			<< ",scheduler_replays_0x4a8db2=" << state.source_order_relation_pointer_loop_scheduler_replay_count_0x4a8db2
			<< ",missing_town_records=" << state.source_order_relation_pointer_loop_missing_town_record_count;
	return detail.str();
}

static bool replay_relation_pointer_source_order_loop_0x4ac552_0x4a8d2c_0x4a8db2(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	state.source_order_relation_pointer_loop_0x4ac552_ported = true;
	state.source_order_relation_pointer_loop_relation_count_0x10e4 =
			int32_t(state.relation_owner_vectors_10e4_10e8.size());
	if (!state.relation_owner_records_10e4_10e8_partial_known
			|| !state.relation_vector_10e4_10e8.present
			|| !state.relation_vector_10e4_10e8.contents_known
			|| !state.relation_vector_10e4_10e8.count_known
			|| state.relation_vector_10e4_10e8.count != state.source_order_relation_pointer_loop_relation_count_0x10e4) {
		state.source_order_relation_pointer_loop_0x4ac552_blocked_reason =
				"0x4ac552_relation_pointer_vector_0x10e4_0x10e8_not_owned_before_0x4a8d2c";
		return false;
	}
	if (state.relation_owner_vectors_10e4_10e8.empty()) {
		state.source_order_relation_pointer_loop_0x4ac552_input_known = true;
		state.source_order_relation_pointer_loop_0x4ac552_applied = true;
		return true;
	}

	SourceObjectResolverState4af785 type98_descriptor_state;
	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		const bool source_pointer_known =
				owner.source_pointer_0x00_known
				&& owner.source_pointer_source_index_0x00 >= 0
				&& owner.source_order_source_record_0x00_known
				&& owner.source_pointer_type_0x04_known
				&& owner.source_owner_slot_0x1c_known;
		if (source_pointer_known) {
			state.source_order_relation_pointer_loop_source_pointer_known_count += 1;
		} else {
			state.source_order_relation_pointer_loop_missing_source_pointer_count += 1;
			state.source_order_relation_pointer_loop_no_source_record_skip_count += 1;
			continue;
		}
		const bool source_record_field_0x04_known = owner.source_order_source_record_field_0x04_known;
		if (source_record_field_0x04_known) {
			state.source_order_relation_pointer_loop_source_record_field_0x04_known_count += 1;
		} else {
			state.source_order_relation_pointer_loop_missing_source_record_field_0x04_count += 1;
			state.source_order_relation_pointer_loop_no_source_record_skip_count += 1;
			continue;
		}
		if (owner.scan_bounds_0x20_0x2c_known) {
			state.source_order_relation_pointer_loop_scan_bounds_known_count += 1;
		} else {
			state.source_order_relation_pointer_loop_missing_scan_bounds_count += 1;
		}
		if (!source_pointer_known || !source_record_field_0x04_known || !owner.scan_bounds_0x20_0x2c_known) {
			continue;
		}

		const SourceObjectRecord0x4c *town_record = source_type98_town_record_for_choice_0x49b3c1(owner.town_choice_0x04);
		if (town_record == nullptr) {
			state.source_order_relation_pointer_loop_missing_town_record_count += 1;
			continue;
		}
		const SourceObjectDescriptor4903e8 descriptor =
				source_type98_town_descriptor_from_record_0x4a8db2(*town_record);
		const SourceObjectDescriptorJoinResult4903e8 join =
				source_object_descriptor_join_0x4903e8(type98_descriptor_state, descriptor, *town_record);
		const int32_t lane_state_0xee4 =
				owner.source_order_source_record_0x00.relation_selector_0x1c >= 0
						&& owner.source_order_source_record_0x00.relation_selector_0x1c < int32_t(state.mapped_source_owner_slots_ee4.size())
				? state.mapped_source_owner_slots_ee4[size_t(owner.source_order_source_record_0x00.relation_selector_0x1c)]
				: -1;
		const int32_t source_pair_key_0x0c = owner.source_order_source_record_0x00.source_id_0x00 >= 0
				? owner.source_order_source_record_0x00.source_id_0x00
				: owner.runtime_zone_index;
		const SourceOrderObjectDispatcherResult4a8d2c direct =
				source_order_object_dispatcher_0x4a8d2c(
						state,
						join,
						owner.runtime_zone_index,
						owner.coordinate_x_0x10,
						owner.coordinate_y_0x14,
						owner.coordinate_level_0x18,
						owner.scan_bound_low_x_0x20,
						owner.scan_bound_low_y_0x24,
						owner.scan_bound_high_x_0x28,
						owner.scan_bound_high_y_0x2c,
						source_pair_key_0x0c,
						lane_state_0xee4,
						rng,
						owner.source_order_source_record_0x00.field_0x30_known,
						owner.source_order_source_record_0x00.field_0x30,
						owner.source_order_source_record_0x00.field_0x34_known,
						owner.source_order_source_record_0x00.field_0x34);
		state.source_order_relation_pointer_loop_direct_replay_count_0x4a8d2c += 1;
		if (direct.committed) {
			state.source_order_relation_pointer_loop_direct_commit_count_0x4a8d2c += 1;
		}

		const int32_t before_scheduler_commit_count = state.source_order_scheduler_commit_count_0x4a8db2;
		source_order_weighted_scheduler_from_source_record_0x4a8db2(
				state,
				join,
				owner.source_order_source_record_0x00,
				true,
				true,
				join.source_catalog_index_0x49da08,
				owner.owner_vector_index,
				owner.runtime_zone_index,
				owner.scan_bound_low_x_0x20,
				owner.scan_bound_low_y_0x24,
				owner.scan_bound_high_x_0x28,
				owner.scan_bound_high_y_0x2c,
				owner.coordinate_level_0x18,
				lane_state_0xee4,
				rng);
		state.source_order_relation_pointer_loop_scheduler_replay_count_0x4a8db2 += 1;
		state.source_order_relation_pointer_loop_scheduler_commit_count_0x4a8db2 +=
				state.source_order_scheduler_commit_count_0x4a8db2 - before_scheduler_commit_count;
	}

	state.source_order_relation_pointer_loop_0x4ac552_input_known =
			state.source_order_relation_pointer_loop_missing_scan_bounds_count == 0
			&& state.source_order_relation_pointer_loop_missing_town_record_count == 0;
	if (!state.source_order_relation_pointer_loop_0x4ac552_input_known) {
		state.source_order_relation_pointer_loop_0x4ac552_blocked_reason =
				source_order_relation_pointer_loop_blocker_detail_0x4ac552(state);
		return false;
	}

	state.source_order_relation_pointer_loop_0x4ac552_applied = true;
	state.source_order_relation_pointer_loop_0x4ac552_blocked_reason.clear();
	return true;
}

static void replay_live_type98_source_order_scheduler_0x4a8db2(GeneratorObjectPrivateState &state, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result, H3MapedRng &rng) {
	SourceObjectResolverState4af785 type98_descriptor_state;
	const std::vector<RuntimeZoneSeedInput4a218c> &post_town_choice_zones =
			coordinate_result.coordinate_seed.runtime_zone_records_after_0x49b3c1;
	for (const RuntimeZoneSeedInput4a218c &base_runtime_zone : template_selection.runtime_seed.runtime_zone_seeds) {
		const RuntimeZoneSeedInput4a218c *post_town_choice_zone =
				runtime_zone_after_town_choice_0x49b3c1(post_town_choice_zones, base_runtime_zone.runtime_zone_index);
		const RuntimeZoneSeedInput4a218c &runtime_zone = post_town_choice_zone != nullptr ? *post_town_choice_zone : base_runtime_zone;
		const SourceOrderSchedulerSourceRecord4a8db2 source_record =
				source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(runtime_zone);
		GeneratorRelationOwnerState4a218c *owner = relation_owner_for_runtime_zone_0x4a54a7(state, runtime_zone.runtime_zone_index);
		if (owner == nullptr) {
			append_blocked_source_order_scheduler_replay_0x4a8db2(
					state,
					source_record,
					runtime_zone.runtime_zone_index,
					"0x4a8db2_relation_owner_record_missing_for_runtime_zone");
			continue;
		}
		const int32_t town_choice = runtime_zone.selected_town_choice_index_0x49b3c1;
		const SourceObjectRecord0x4c *town_record = source_type98_town_record_for_choice_0x49b3c1(town_choice);
		if (town_record == nullptr) {
			append_blocked_source_order_scheduler_replay_0x4a8db2(
					state,
					source_record,
					owner->runtime_zone_index,
					"0x4a8db2_type98_selected_town_source_record_missing");
			continue;
		}
		const SourceObjectDescriptor4903e8 descriptor =
				source_type98_town_descriptor_from_record_0x4a8db2(*town_record);
		const SourceObjectDescriptorJoinResult4903e8 join =
				source_object_descriptor_join_0x4903e8(type98_descriptor_state, descriptor, *town_record);
		const int32_t source_selector = source_record.relation_selector_0x1c;
		const int32_t lane_state_0xee4 =
				source_selector >= 0 && source_selector < int32_t(state.mapped_source_owner_slots_ee4.size())
				? state.mapped_source_owner_slots_ee4[size_t(source_selector)]
				: -1;
		source_order_weighted_scheduler_from_source_record_0x4a8db2(
				state,
				join,
				source_record,
				source_record.source_id_0x00 >= 0,
				true,
				join.source_catalog_index_0x49da08,
				owner->owner_vector_index,
				owner->runtime_zone_index,
				owner->scan_bound_low_x_0x20,
				owner->scan_bound_low_y_0x24,
				owner->scan_bound_high_x_0x28,
				owner->scan_bound_high_y_0x2c,
				owner->coordinate_level_0x18,
				lane_state_0xee4,
				rng);
	}
}

static void replay_live_type98_source_order_direct_0x4a8d2c(GeneratorObjectPrivateState &state, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result, H3MapedRng &rng) {
	SourceObjectResolverState4af785 type98_descriptor_state;
	const std::vector<RuntimeZoneSeedInput4a218c> &post_town_choice_zones =
			coordinate_result.coordinate_seed.runtime_zone_records_after_0x49b3c1;
	for (const RuntimeZoneSeedInput4a218c &base_runtime_zone : template_selection.runtime_seed.runtime_zone_seeds) {
		const RuntimeZoneSeedInput4a218c *post_town_choice_zone =
				runtime_zone_after_town_choice_0x49b3c1(post_town_choice_zones, base_runtime_zone.runtime_zone_index);
		const RuntimeZoneSeedInput4a218c &runtime_zone = post_town_choice_zone != nullptr ? *post_town_choice_zone : base_runtime_zone;
		const SourceOrderSchedulerSourceRecord4a8db2 source_record =
				source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(runtime_zone);
		GeneratorRelationOwnerState4a218c *owner = relation_owner_for_runtime_zone_0x4a54a7(state, runtime_zone.runtime_zone_index);
		if (owner == nullptr || !owner->scan_bounds_0x20_0x2c_known) {
			continue;
		}
		const int32_t town_choice = runtime_zone.selected_town_choice_index_0x49b3c1;
		const SourceObjectRecord0x4c *town_record = source_type98_town_record_for_choice_0x49b3c1(town_choice);
		if (town_record == nullptr) {
			continue;
		}
		const SourceObjectDescriptor4903e8 descriptor =
				source_type98_town_descriptor_from_record_0x4a8db2(*town_record);
		const SourceObjectDescriptorJoinResult4903e8 join =
				source_object_descriptor_join_0x4903e8(type98_descriptor_state, descriptor, *town_record);
		const int32_t source_selector = source_record.relation_selector_0x1c;
		const int32_t lane_state_0xee4 =
				source_selector >= 0 && source_selector < int32_t(state.mapped_source_owner_slots_ee4.size())
				? state.mapped_source_owner_slots_ee4[size_t(source_selector)]
				: -1;
		const int32_t source_pair_key_0x0c = source_record.source_id_0x00 >= 0
				? source_record.source_id_0x00
				: runtime_zone.runtime_zone_index;
		source_order_object_dispatcher_0x4a8d2c(
				state,
				join,
				owner->runtime_zone_index,
				owner->coordinate_x_0x10,
				owner->coordinate_y_0x14,
				owner->coordinate_level_0x18,
				owner->scan_bound_low_x_0x20,
				owner->scan_bound_low_y_0x24,
				owner->scan_bound_high_x_0x28,
				owner->scan_bound_high_y_0x2c,
				source_pair_key_0x0c,
				lane_state_0xee4,
				rng);
	}
}

static SourceObjectDescriptor4903e8 source_descriptor_from_preserved_pair_context_0x4903e8(const SourceObjectDescriptorJoinContext4903e8 &context) {
	SourceObjectDescriptor4903e8 descriptor;
	descriptor.target_context_0x4903e8 = context.target_context_0x4903e8;
	descriptor.source_key_0x00 = context.source_key_0x00;
	descriptor.descriptor_type_0x1c = context.descriptor_type_0x1c;
	descriptor.subtype_0x20 = context.subtype_0x20;
	descriptor.group_0x24 = context.group_0x24;
	descriptor.projection_enabled_0x29 = context.projection_enabled_0x29;
	descriptor.source_cell_x_0x2c = context.source_cell_x_0x2c;
	descriptor.source_cell_y_0x30 = context.source_cell_y_0x30;
	descriptor.score_adjust_0x30_known = context.score_adjust_0x30_known;
	descriptor.score_adjust_0x30 = context.score_adjust_0x30;
	descriptor.score_adjust_0x40_known = context.score_adjust_0x40_known;
	descriptor.score_adjust_0x40 = context.score_adjust_0x40;
	descriptor.descriptor_mask_fields_0x34_0x48_known = context.descriptor_mask_fields_0x34_0x48_known;
	descriptor.descriptor_width_0x34 = context.descriptor_width_0x34;
	descriptor.descriptor_height_0x38 = context.descriptor_height_0x38;
	descriptor.descriptor_mask_a_0x3c_0x40 = context.descriptor_mask_a_0x3c_0x40;
	descriptor.descriptor_mask_b_0x44_0x48 = context.descriptor_mask_b_0x44_0x48;
	return descriptor;
}

static SourceObjectDescriptorJoinResult4903e8 source_descriptor_join_from_preserved_pair_0x4903e8(const SourceObjectResolverSourcePair4af785 &pair) {
	SourceObjectDescriptorJoinResult4903e8 result;
	result.descriptor = source_descriptor_from_preserved_pair_context_0x4903e8(pair.descriptor_join_descriptor_0x4903e8);
	result.source_record_copy = pair.source_record_copy;
	result.source_catalog_index_0x49da08 = pair.copied_source_catalog_index >= 0
			? pair.copied_source_catalog_index
			: source_object_catalog_index_0x49da08(pair.source_record_copy);
	const int32_t target_context = result.descriptor.target_context_0x4903e8 >= 0
			? result.descriptor.target_context_0x4903e8
			: result.descriptor.descriptor_type_0x1c;
	result.recovered_target_context = recovered_descriptor_join_context_0x4903e8(target_context);
	result.descriptor_type_matches_source_type_0x1c = result.descriptor.descriptor_type_0x1c == pair.source_record_copy.type_id_0x1c;
	result.descriptor_subtype_matches_source_0x20 = result.descriptor.subtype_0x20 == pair.source_record_copy.subtype_0x20;
	result.descriptor_group_matches_source_0x24 = result.descriptor.group_0x24 == pair.source_record_copy.group_0x24;
	result.descriptor_mask_fields_match_source_0x34_0x48 =
			!result.descriptor.descriptor_mask_fields_0x34_0x48_known
			|| !pair.source_record_copy.descriptor_mask_fields_0x34_0x48_known
			|| (result.descriptor.descriptor_width_0x34 == pair.source_record_copy.descriptor_width_0x34
					&& result.descriptor.descriptor_height_0x38 == pair.source_record_copy.descriptor_height_0x38
					&& result.descriptor.descriptor_mask_a_0x3c_0x40 == pair.source_record_copy.descriptor_mask_a_0x3c_0x40
					&& result.descriptor.descriptor_mask_b_0x44_0x48 == pair.source_record_copy.descriptor_mask_b_0x44_0x48);
	result.descriptor_source_fields_match = result.descriptor_type_matches_source_type_0x1c
			&& result.descriptor_subtype_matches_source_0x20
			&& result.descriptor_group_matches_source_0x24
			&& result.descriptor_mask_fields_match_source_0x34_0x48;
	result.descriptor_source_key_is_not_source_row_id = result.descriptor.source_key_0x00 != pair.source_record_copy.source_row;
	result.descriptor_only_identity_ambiguous = descriptor_only_source_identity_is_ambiguous(pair.source_record_copy);
	result.copied_source_record_is_identity_authority = true;
	result.resolver_invoked_0x4af785 = false;
	result.resolver_0x4af785.selected_wrapper_index = pair.context_wrapper_index_0x04 >= 0
			? pair.context_wrapper_index_0x04
			: pair.wrapper_index;
	result.resolver_0x4af785.input_source_catalog_index = result.source_catalog_index_0x49da08;
	result.resolver_0x4af785.input_source_row = pair.source_record_copy.source_row;
	result.resolver_0x4af785.input_def_name = pair.source_record_copy.def_name;
	result.resolver_0x4af785.input_type_id_0x1c = pair.source_record_copy.type_id_0x1c;
	result.resolver_0x4af785.input_subtype_0x20 = pair.source_record_copy.subtype_0x20;
	result.resolver_0x4af785.metadata_bucket_index_0x08 = pair.source_record_copy.metadata_bucket_index_0x08;
	result.resolver_0x4af785.resolver_lane_0x04 = pair.context_wrapper_lane_0x04;
	result.joined = pair.descriptor_joined_0x4903e8;

	if (!result.recovered_target_context) {
		result.blocked_reason = "preserved_0x4903e8_target_context_unrecovered";
	} else if (!pair.source_record_pointer_0x00_carried || !pair.context_pointer_0x04_carried) {
		result.blocked_reason = "preserved_0xedc_source_pair_pointer_context_missing";
	} else if (result.source_catalog_index_0x49da08 < 0) {
		result.blocked_reason = "preserved_0xedc_copied_source_record_not_found_in_0x49da08_catalog";
	} else if (!result.descriptor_source_fields_match) {
		result.blocked_reason = "preserved_0x4903e8_descriptor_fields_do_not_match_copied_0x4c_source_record";
	} else if (!result.joined) {
		result.blocked_reason = "preserved_0x4903e8_descriptor_pair_not_marked_joined";
	}
	return result;
}

void replay_generic_non_type98_source_order_pairs_0x4a8d2c_0x4a8db2(GeneratorObjectPrivateState &state, H3MapedRng &rng) {
	state.generic_source_order_pair_replay_applied_0x4a8d2c_0x4a8db2 = true;
	for (size_t index = 0; index < state.source_pair_records_edc.size(); ++index) {
		const SourceObjectResolverSourcePair4af785 &pair = state.source_pair_records_edc[index];
		state.generic_source_order_pair_scan_count_0xedc += 1;
		if (pair.source_record_copy.type_id_0x1c == 98) {
			state.generic_source_order_pair_type98_skip_count += 1;
			continue;
		}
		if (!pair.descriptor_join_0x4903e8_known) {
			state.generic_source_order_pair_descriptor_context_missing_count += 1;
			state.generic_source_order_pair_replay_blockers_0xedc.push_back("0xedc_pair_" + std::to_string(index) + "_0x4903e8_descriptor_context_missing");
			continue;
		}
		const SourceObjectDescriptorJoinResult4903e8 join = source_descriptor_join_from_preserved_pair_0x4903e8(pair);
		if (!join.joined || !join.blocked_reason.empty()) {
			state.generic_source_order_pair_descriptor_context_missing_count += 1;
			state.generic_source_order_pair_replay_blockers_0xedc.push_back("0xedc_pair_" + std::to_string(index) + "_" + (join.blocked_reason.empty() ? "0x4903e8_join_unresolved" : join.blocked_reason));
			continue;
		}
		if (!pair.source_order_relation_context_known || !pair.source_order_source_pair_key_0x0c_known) {
			state.generic_source_order_pair_relation_context_missing_count += 1;
			state.generic_source_order_pair_replay_blockers_0xedc.push_back("0xedc_pair_" + std::to_string(index) + "_source_order_relation_or_key_context_missing");
			continue;
		}
		GeneratorRelationOwnerState4a218c *owner = relation_owner_for_runtime_zone_0x4a54a7(state, pair.source_order_relation_owner_byte2);
		if (owner == nullptr || !owner->scan_bounds_0x20_0x2c_known) {
			state.generic_source_order_pair_relation_context_missing_count += 1;
			state.generic_source_order_pair_replay_blockers_0xedc.push_back("0xedc_pair_" + std::to_string(index) + "_relation_owner_scan_bounds_missing");
			continue;
		}
		const int32_t anchor_x = pair.source_order_anchor_known ? pair.source_order_anchor_x_0x10 : owner->coordinate_x_0x10;
		const int32_t anchor_y = pair.source_order_anchor_known ? pair.source_order_anchor_y_0x14 : owner->coordinate_y_0x14;
		const int32_t anchor_level = pair.source_order_anchor_known ? pair.source_order_anchor_level_0x18 : owner->coordinate_level_0x18;
		const int32_t lane_state = pair.source_order_lane_state_0xee4_known ? pair.source_order_lane_state_0xee4 : pair.source_lane_0x1c;
		if (!pair.source_record_copy.raw_field_0x20_known
				|| !pair.source_record_copy.raw_field_0x24_known
				|| !pair.source_record_copy.raw_field_0x28_known
				|| !pair.source_record_copy.raw_field_0x2c_known
				|| !pair.source_record_copy.raw_field_0x38_known) {
			state.generic_source_order_pair_source_fields_missing_count += 1;
			state.generic_source_order_pair_replay_blockers_0xedc.push_back("0xedc_pair_" + std::to_string(index) + "_copied_0x4c_source_count_or_density_fields_missing");
			continue;
		}
		const SourceOrderObjectDispatcherResult4a8d2c direct = source_order_object_dispatcher_0x4a8d2c(
				state,
				join,
				pair.source_order_relation_owner_byte2,
				anchor_x,
				anchor_y,
				anchor_level,
				owner->scan_bound_low_x_0x20,
				owner->scan_bound_low_y_0x24,
				owner->scan_bound_high_x_0x28,
				owner->scan_bound_high_y_0x2c,
				pair.source_order_source_pair_key_0x0c,
				lane_state,
				rng);
		state.generic_source_order_pair_direct_dispatch_count_0x4a8d2c += 1;
		if (direct.committed) {
			state.generic_source_order_pair_direct_commit_count_0x4a8d2c += 1;
		}
		const int32_t before_weighted_commit_count = state.source_order_scheduler_commit_count_0x4a8db2;
		source_order_weighted_scheduler_0x4a8db2(
				state,
				join,
				pair,
				pair.source_order_relation_owner_byte2,
				owner->scan_bound_low_x_0x20,
				owner->scan_bound_low_y_0x24,
				owner->scan_bound_high_x_0x28,
				owner->scan_bound_high_y_0x2c,
				anchor_level,
				lane_state,
				rng,
				pair.source_record_copy.raw_field_0x30_known,
				pair.source_record_copy.raw_field_0x30,
				pair.source_record_copy.raw_field_0x34_known,
				pair.source_record_copy.raw_field_0x34,
				pair.source_record_copy.raw_field_0x3c_known,
				pair.source_record_copy.raw_field_0x3c);
		state.generic_source_order_pair_weighted_replay_count_0x4a8db2 += 1;
		state.generic_source_order_pair_weighted_commit_count_0x4a8db2 +=
				state.source_order_scheduler_commit_count_0x4a8db2 - before_weighted_commit_count;
	}
}

struct RoutePoint4a8260 {
	int32_t x = 0;
	int32_t y = 0;
};

struct RouteFreeCellPhaseResult4a8260 {
	bool route_0x4a8260_ported = true;
	bool input_known = false;
	bool route_0x4a8260_applied = false;
	bool candidate_boundary_0x4a4c8e_applied = false;
	std::string blocked_reason;
	uint32_t rng_state_before = 0U;
	uint32_t rng_state_after = 0U;
	int32_t route_scan_cell_count = 0;
	int32_t route_scan_empty_object_vector_count = 0;
	int32_t route_scan_nonempty_object_vector_count = 0;
	int32_t route_stamp_call_count_0x49a85d = 0;
	int32_t route_cut_call_count_0x4a80dc = 0;
	int32_t final_sweep_call_count_0x49a962 = 0;
	int32_t final_sweep_neighbor_clear_count_0x49a962 = 0;
	int32_t candidate_boundary_scan_count_0x4a4c8e = 0;
	int32_t candidate_boundary_trigger_count_0x4a4c8e = 0;
};

static bool generated_cell_record_input_known_for_route_0x4a8260(const GeneratedCellRecord0x30 &record) {
	return record.object_reference_vector_fields_0x04_0x08_present
			&& record.object_reference_vector_contents_known
			&& record.word_0x20_known
			&& record.word_0x24_known
			&& record.word_0x28_known
			&& record.word_0x2c_known;
}

static bool generated_cell_record_object_vector_empty_0x4a8260(const GeneratedCellRecord0x30 &record) {
	return record.object_reference_vector_contents_known && record.object_references_0x04_0x08.empty();
}

static bool route_point_in_bounds_0x4a8260(const GeneratedCellRecordGrid0x30 &grid, const RoutePoint4a8260 &point) {
	return point.x >= 0 && point.y >= 0 && point.x < grid.width && point.y < grid.height;
}

static bool route_inner_point_in_bounds_0x4a80dc(const GeneratedCellRecordGrid0x30 &grid, const RoutePoint4a8260 &point) {
	return point.x >= 1 && point.y >= 1 && point.x < grid.width - 1 && point.y < grid.height - 1;
}

static int32_t route_half_sum_0x4a8260(int32_t a, int32_t b) {
	return (a + b + 1) / 2;
}

static int32_t route_distance_0x4cc5ad(int32_t dx, int32_t dy) {
	const int64_t squared = int64_t(dx) * int64_t(dx) + int64_t(dy) * int64_t(dy);
	return int32_t(std::sqrt(double(squared)));
}

static int32_t route_step_sign_0x4a80dc(int32_t delta) {
	return delta <= 0 ? -1 : 1;
}

static GeneratedCell49a85dStampResult generated_cell_49a85d_stamp_record_grid(GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, int32_t level) {
	GeneratedCell49a85dStampResult result;
	const int64_t center_flat = cell_index(grid.width, grid.height, x, y, level);
	if (center_flat < 0 || center_flat >= int64_t(grid.records.size())) {
		return result;
	}
	result.center_in_bounds = true;
	result.center_set = generated_cell_49a932(grid.records[size_t(center_flat)], true);

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
			result.covered_cell_count += 1;
			if (generated_cell_49a932(grid.records[size_t(flat)], true)) {
				result.covered_set_count += 1;
			}
		}
	}
	return result;
}

static GeneratedCell49a962SweepResult generated_cell_49a962_record_grid(GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, int32_t level) {
	GeneratedCell49a962SweepResult result;
	const int64_t center_flat = cell_index(grid.width, grid.height, x, y, level);
	if (center_flat < 0 || center_flat >= int64_t(grid.records.size())) {
		return result;
	}
	result.center_in_bounds = true;
	result.center_candidate_set = generated_cell_49aa63(grid.records[size_t(center_flat)], true);

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
			GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
			result.neighbor_scan_count += 1;
			if (!record.word_0x28_known || (record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
				result.neighbor_bit22_skip_count += 1;
				continue;
			}
			if (!generated_cell_49a1d8_valid_record(record)) {
				result.neighbor_invalid_skip_count += 1;
				continue;
			}
			if ((record.word_0x24 & 0x3fU) == 8U) {
				result.neighbor_terrain8_skip_count += 1;
				continue;
			}
			if (generated_cell_49a932(record, false)) {
				result.neighbor_clear_count += 1;
			}
		}
	}
	return result;
}

static RoutePoint4a8260 route_cut_0x4a80dc(const GeneratedCellRecordGrid0x30 &grid, const RoutePoint4a8260 &start, const RoutePoint4a8260 &target, int32_t level, bool &occupied_hit, bool &boundary_return) {
	occupied_hit = false;
	boundary_return = false;
	const int32_t dx = target.x - start.x;
	const int32_t dy = target.y - start.y;
	const int32_t abs_dx = std::abs(dx);
	const int32_t abs_dy = std::abs(dy);
	RoutePoint4a8260 current = start;
	RoutePoint4a8260 previous = start;
	const int32_t guard_limit = std::max<int32_t>(8, (grid.width + grid.height) * 4);
	int32_t step_count = 0;
	auto occupied_neighborhood = [&](const RoutePoint4a8260 &point) {
		for (int32_t y = point.y - 1; y <= point.y + 1; ++y) {
			for (int32_t x = point.x - 1; x <= point.x + 1; ++x) {
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat >= 0
						&& flat < int64_t(grid.records.size())
						&& grid.records[size_t(flat)].word_0x28_known
						&& (grid.records[size_t(flat)].word_0x28 & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U) {
					return true;
				}
			}
		}
		return false;
	};
	if (abs_dx > abs_dy) {
		const int32_t step_x = route_step_sign_0x4a80dc(dx);
		const int32_t step_y = route_step_sign_0x4a80dc(dy);
		int32_t error = abs_dx / 2;
		while (step_count < guard_limit) {
			previous = current;
			error += abs_dy;
			if (error >= abs_dx) {
				error -= abs_dx;
				current.y += step_y;
			}
			current.x += step_x;
			step_count += 1;
			if (!route_inner_point_in_bounds_0x4a80dc(grid, current)) {
				boundary_return = true;
				return previous;
			}
			if (step_count <= 2) {
				continue;
			}
			if (occupied_neighborhood(current)) {
				occupied_hit = true;
				return previous;
			}
		}
		boundary_return = true;
		return previous;
	}
	const int32_t step_x = route_step_sign_0x4a80dc(dx);
	const int32_t step_y = route_step_sign_0x4a80dc(dy);
	int32_t error = abs_dy / 2;
	while (step_count < guard_limit) {
		previous = current;
		error += abs_dx;
		if (error >= abs_dy) {
			error -= abs_dy;
			current.x += step_x;
		}
		current.y += step_y;
		step_count += 1;
		if (!route_inner_point_in_bounds_0x4a80dc(grid, current)) {
			boundary_return = true;
			return previous;
		}
		if (step_count <= 2) {
			continue;
		}
		if (occupied_neighborhood(current)) {
			occupied_hit = true;
			return previous;
		}
	}
	boundary_return = true;
	return previous;
}

static bool relation_lookup_wide_0x4a4c8e(const std::vector<GeneratorRelationOwnerState4a218c> &owners, int32_t owner_runtime_zone, int32_t neighbor_runtime_zone, bool &wide) {
	wide = false;
	for (const GeneratorRelationOwnerState4a218c &owner : owners) {
		if (owner.runtime_zone_index != owner_runtime_zone) {
			continue;
		}
		for (const GeneratorRelationRecordState4a218c &record : owner.relation_records) {
			if (record.target_runtime_zone_index == neighbor_runtime_zone) {
				wide = record.wide;
				return true;
			}
		}
		return false;
	}
	return false;
}

static RouteFreeCellPhaseResult4a8260 route_free_cell_phase_0x4a8260_0x4a4c8e(GeneratedCellRecordGrid0x30 &grid, const std::vector<GeneratorRelationOwnerState4a218c> &owners, H3MapedRng &rng) {
	RouteFreeCellPhaseResult4a8260 result;
	result.rng_state_before = rng.state;
	result.rng_state_after = rng.state;
	const int64_t expected_cell_count = int64_t(grid.width) * int64_t(grid.height) * int64_t(grid.level_count);
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || expected_cell_count <= 0 || expected_cell_count != int64_t(grid.records.size())) {
		result.blocked_reason = "route_container_free_cell_sweep_0x4a8260_invalid_generated_cell_grid";
		return result;
	}
	for (const GeneratedCellRecord0x30 &record : grid.records) {
		if (!generated_cell_record_input_known_for_route_0x4a8260(record)) {
			result.blocked_reason = "route_container_free_cell_sweep_0x4a8260_generated_cell_record_input_unknown";
			return result;
		}
	}
	result.input_known = true;

	for (GeneratedCellRecord0x30 &record : grid.records) {
		result.route_scan_cell_count += 1;
		if ((record.word_0x2c & 0x1U) != 0U) {
			continue;
		}
		if (generated_cell_record_object_vector_empty_0x4a8260(record)) {
			result.route_scan_empty_object_vector_count += 1;
			generated_cell_49aa63(record, true);
		} else {
			result.route_scan_nonempty_object_vector_count += 1;
			generated_cell_49a932(record, true);
		}
	}

	for (int32_t level = 0; level < grid.level_count; ++level) {
		const int32_t orientation = rng.next() % 4;
		RoutePoint4a8260 start;
		RoutePoint4a8260 end;
		switch (orientation) {
			case 0:
				start = { 0, 0 };
				end = { grid.width - 1, grid.height - 1 };
				break;
			case 1:
				start = { grid.width / 2, 0 };
				end = { grid.width / 2, grid.height - 1 };
				break;
			case 2:
				start = { grid.width - 1, 0 };
				end = { 0, grid.height - 1 };
				break;
			default:
				start = { 0, grid.height / 2 };
				end = { grid.width - 1, grid.height / 2 };
				break;
		}
		std::vector<RoutePoint4a8260> pending;
		std::deque<std::pair<RoutePoint4a8260, RoutePoint4a8260>> secondary;
		pending.push_back(start);
		pending.push_back(end);
		const int32_t guard_limit = std::max<int32_t>(1024, int32_t(expected_cell_count) * 16);
		int32_t guard_count = 0;
		while (guard_count < guard_limit) {
			while (pending.size() >= 2 && guard_count < guard_limit) {
				guard_count += 1;
				const RoutePoint4a8260 p1 = pending.back();
				pending.pop_back();
				const RoutePoint4a8260 p2 = pending.back();
				pending.pop_back();
				const RoutePoint4a8260 mid { route_half_sum_0x4a8260(p1.x, p2.x), route_half_sum_0x4a8260(p1.y, p2.y) };
				if ((mid.x == p1.x && mid.y == p1.y) || (mid.x == p2.x && mid.y == p2.y)) {
					if (route_point_in_bounds_0x4a8260(grid, p2)) {
						result.route_stamp_call_count_0x49a85d += 1;
						generated_cell_49a85d_stamp_record_grid(grid, p2.x, p2.y, level);
					}
					continue;
				}
				const int32_t dx_p2_to_p1 = p1.x - p2.x;
				const int32_t dyneg_p2_to_p1 = p2.y - p1.y;
				const int32_t distance = route_distance_0x4cc5ad(dx_p2_to_p1, dyneg_p2_to_p1);
				RoutePoint4a8260 randomized_mid = mid;
				if (distance > 1) {
					const int32_t split_rng_value = rng.next();
					const int32_t offset = (split_rng_value % distance) - (distance / 2);
					randomized_mid.x += (offset * dyneg_p2_to_p1) / distance;
					randomized_mid.y += (offset * dx_p2_to_p1) / distance;
				}
				pending.push_back(p1);
				pending.push_back(randomized_mid);
				pending.push_back(randomized_mid);
				pending.push_back(p2);
				if (distance >= 8 && route_point_in_bounds_0x4a8260(grid, randomized_mid)) {
					const RoutePoint4a8260 target_a { randomized_mid.x + dyneg_p2_to_p1, randomized_mid.y + dx_p2_to_p1 };
					const RoutePoint4a8260 target_b { randomized_mid.x - dyneg_p2_to_p1, randomized_mid.y - dx_p2_to_p1 };
					secondary.push_back(std::make_pair(randomized_mid, target_a));
					secondary.push_back(std::make_pair(randomized_mid, target_b));
				}
			}
			if (!pending.empty()) {
				result.blocked_reason = "route_container_free_cell_sweep_0x4a8260_route_pending_guard_exhausted";
				result.rng_state_after = rng.state;
				return result;
			}
			if (secondary.empty()) {
				break;
			}
			const auto pair = secondary.front();
			secondary.pop_front();
			bool occupied_hit = false;
			bool boundary_return = false;
			result.route_cut_call_count_0x4a80dc += 1;
			const RoutePoint4a8260 returned = route_cut_0x4a80dc(grid, pair.first, pair.second, level, occupied_hit, boundary_return);
			(void)occupied_hit;
			(void)boundary_return;
			const int32_t delta_x = returned.x - pair.first.x;
			const int32_t delta_y = returned.y - pair.first.y;
			if (delta_x * delta_x + delta_y * delta_y >= 25) {
				pending.push_back(returned);
				pending.push_back(pair.first);
			}
		}
		if (guard_count >= guard_limit) {
			result.blocked_reason = "route_container_free_cell_sweep_0x4a8260_route_guard_exhausted";
			result.rng_state_after = rng.state;
			return result;
		}
	}

	for (int32_t level = 0; level < grid.level_count; ++level) {
		for (int32_t y = 0; y < grid.height; ++y) {
			for (int32_t x = 0; x < grid.width; ++x) {
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat < 0 || flat >= int64_t(grid.records.size())) {
					continue;
				}
				GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
				const uint32_t terrain_class = record.word_0x24 & 0x3fU;
				if ((terrain_class == 8U || terrain_class == 9U) && (record.word_0x2c & 0x1U) == 0U) {
					generated_cell_49a932(record, true);
				}
				if ((record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
					const GeneratedCell49a962SweepResult sweep = generated_cell_49a962_record_grid(grid, x, y, level);
					result.final_sweep_call_count_0x49a962 += 1;
					result.final_sweep_neighbor_clear_count_0x49a962 += sweep.neighbor_clear_count;
				}
			}
		}
	}

	for (int32_t level = 0; level < grid.level_count; ++level) {
		for (int32_t y = 0; y < grid.height; ++y) {
			for (int32_t x = 0; x < grid.width; ++x) {
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat < 0 || flat >= int64_t(grid.records.size())) {
					continue;
				}
				GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
				result.candidate_boundary_scan_count_0x4a4c8e += 1;
				const int32_t owner_signed = int32_t(int8_t((record.word_0x20 >> 16U) & 0xffU));
				if (owner_signed < 0 || (record.word_0x24 & 0x3fU) == 8U) {
					continue;
				}
				bool triggered = false;
				for (int32_t local_y = std::max<int32_t>(0, y - 1); local_y < std::min<int32_t>(grid.height, y + 2); ++local_y) {
					for (int32_t local_x = std::max<int32_t>(0, x - 1); local_x < std::min<int32_t>(grid.width, x + 2); ++local_x) {
						const int64_t neighbor_flat = cell_index(grid.width, grid.height, local_x, local_y, level);
						if (neighbor_flat < 0 || neighbor_flat >= int64_t(grid.records.size()) || neighbor_flat == flat) {
							continue;
						}
						const GeneratedCellRecord0x30 &neighbor = grid.records[size_t(neighbor_flat)];
						const int32_t neighbor_owner_signed = int32_t(int8_t((neighbor.word_0x20 >> 16U) & 0xffU));
						if (neighbor_owner_signed < 0) {
							if ((neighbor.word_0x24 & 0x3fU) == 8U) {
								triggered = true;
							}
							continue;
						}
						if (neighbor_owner_signed == owner_signed) {
							continue;
						}
						bool relation_wide = false;
						const bool relation_found = relation_lookup_wide_0x4a4c8e(owners, owner_signed, neighbor_owner_signed, relation_wide);
						if (!relation_found || level == 1 || !relation_wide) {
							triggered = true;
						}
					}
				}
				if (!triggered) {
					continue;
				}
				result.candidate_boundary_trigger_count_0x4a4c8e += 1;
				generated_cell_49aa63(record, true);
				if ((record.word_0x24 & 0x3fU) != 8U && generated_cell_record_object_vector_empty_0x4a8260(record)) {
					generated_cell_49aa63(record, true);
				}
				for (int32_t local_y = std::max<int32_t>(0, y - 1); local_y < std::min<int32_t>(grid.height, y + 2); ++local_y) {
					for (int32_t local_x = std::max<int32_t>(0, x - 1); local_x < std::min<int32_t>(grid.width, x + 2); ++local_x) {
						const int64_t candidate_flat = cell_index(grid.width, grid.height, local_x, local_y, level);
						if (candidate_flat < 0 || candidate_flat >= int64_t(grid.records.size())) {
							continue;
						}
						GeneratedCellRecord0x30 &candidate = grid.records[size_t(candidate_flat)];
						if (!generated_cell_record_object_vector_empty_0x4a8260(candidate)) {
							continue;
						}
						generated_cell_49a932(candidate, false);
					}
				}
			}
		}
	}
	result.candidate_boundary_0x4a4c8e_applied = true;
	result.route_0x4a8260_applied = true;
	result.rng_state_after = rng.state;
	return result;
}

struct Post4a4c8eCleanupResult4a8c15 {
	bool input_known = false;
	bool applied = false;
	std::string blocked_reason;
	int32_t scan_count = 0;
	int32_t bit26_skip_count = 0;
	int32_t invalid_49a1d8_skip_count = 0;
	int32_t bit22_skip_count = 0;
	int32_t object_reference_skip_count = 0;
	int32_t non_negative_owner_skip_count = 0;
	int32_t terrain8_or_9_skip_count = 0;
	int32_t call_count_0x49a962 = 0;
	int32_t neighbor_clear_count_0x49a962 = 0;
};

struct MaterializationBridgeRelationLoopResult4a4913 {
	bool input_known = false;
	bool applied = false;
	std::string blocked_reason;
	int32_t relation_count = 0;
	int32_t call_count_0x4a4913 = 0;
	int32_t non_type8_skip_count = 0;
	int32_t reset_cell_count = 0;
	int32_t foreign_seed_call_count_0x4a4694 = 0;
	int32_t candidate_scan_count = 0;
	int32_t candidate_append_count_0x4ae1fd = 0;
	int32_t rng_call_count_0x4e7276 = 0;
	int32_t brush_call_count_0x4a4522 = 0;
	int32_t selected_seed_call_count_0x4a4694 = 0;
	int32_t queue_relax_count_0x4a4694 = 0;
	int32_t brush_bit26_set_count_0x4a4522 = 0;
};

struct MaterializationBridgeWaterEdgeWriterResult4a4fc5 {
	bool input_known = false;
	bool applied = false;
	bool source_backed_land_scope = false;
	std::string blocked_reason;
	int32_t scan_count = 0;
	int32_t owner_low_sentinel_skip_count = 0;
	int32_t owner_high_sentinel_skip_count = 0;
	int32_t source_water_cell_count = 0;
	int32_t relation_lookup_skip_count = 0;
	int32_t mutation_source_count = 0;
	int32_t bit26_set_count = 0;
	int32_t byte2b_clear_count = 0;
	int32_t visual_repaint_pending_count = 0;
	int32_t neighbor_bit25_probe_count = 0;
	int32_t bit26_candidate_count = 0;
};

struct Coord12Candidate4a4913 {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

static bool source_endpoint_record_lookup_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		int32_t owner_runtime_zone,
		int32_t lookup_key) {
	return source_endpoint_record_find_0x49b3fb(owners, owner_runtime_zone, lookup_key) != nullptr;
}

static const GeneratorSourceEndpointRecordState4a1f3b *source_endpoint_record_find_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		int32_t owner_runtime_zone,
		int32_t lookup_key) {
	for (const GeneratorRelationOwnerState4a218c &owner : owners) {
		if (owner.runtime_zone_index != owner_runtime_zone) {
			continue;
		}
		if (!owner.source_endpoint_vector_0xc8_0xcc_present
				|| !owner.source_endpoint_vector_0xc8_0xcc_contents_known
				|| !owner.source_endpoint_vector_0xc8_0xcc_count_known
				|| owner.source_endpoint_vector_0xc8_0xcc_count != int32_t(owner.source_endpoint_records_0xc8_0xcc.size())) {
			return nullptr;
		}
		for (const GeneratorSourceEndpointRecordState4a1f3b &record : owner.source_endpoint_records_0xc8_0xcc) {
			if (record.target_runtime_zone_index == lookup_key) {
				return &record;
			}
		}
		return nullptr;
	}
	return nullptr;
}

static bool source_endpoint_records_known_for_lookup_0x49b3fb(
		const std::vector<GeneratorRelationOwnerState4a218c> &owners) {
	if (owners.empty()) {
		return false;
	}
	return std::all_of(
			owners.begin(),
			owners.end(),
			[](const GeneratorRelationOwnerState4a218c &owner) {
				return owner.source_endpoint_vector_0xc8_0xcc_present
						&& owner.source_endpoint_vector_0xc8_0xcc_contents_known
						&& owner.source_endpoint_vector_0xc8_0xcc_count_known
						&& owner.source_endpoint_vector_0xc8_0xcc_count == int32_t(owner.source_endpoint_records_0xc8_0xcc.size());
			});
}

static Post4a4c8eCleanupResult4a8c15 post_4a4c8e_cleanup_scan_0x4a8c15(GeneratedCellRecordGrid0x30 &grid) {
	Post4a4c8eCleanupResult4a8c15 result;
	const int64_t expected_cell_count = int64_t(grid.width) * int64_t(grid.height) * int64_t(grid.level_count);
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || expected_cell_count <= 0 || expected_cell_count != int64_t(grid.records.size())) {
		result.blocked_reason = "0x4a8c15_post_0x4a4c8e_cleanup_invalid_generated_cell_grid";
		return result;
	}
	for (const GeneratedCellRecord0x30 &record : grid.records) {
		if (!record.object_reference_vector_fields_0x04_0x08_present
				|| !record.object_reference_vector_contents_known
				|| !record.word_0x20_known
				|| !record.word_0x24_known
				|| !record.word_0x28_known
				|| !record.word_0x2c_known) {
			result.blocked_reason = "0x4a8c15_post_0x4a4c8e_cleanup_generated_cell_record_input_unknown";
			return result;
		}
	}
	result.input_known = true;

	for (int32_t level = 0; level < grid.level_count; ++level) {
		for (int32_t y = 0; y < grid.height; ++y) {
			for (int32_t x = 0; x < grid.width; ++x) {
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat < 0 || flat >= int64_t(grid.records.size())) {
					continue;
				}
				GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
				result.scan_count += 1;
				if ((record.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
					result.bit26_skip_count += 1;
					continue;
				}
				if (!generated_cell_49a1d8_valid_record(record)) {
					result.invalid_49a1d8_skip_count += 1;
					continue;
				}
				if ((record.word_0x28 & CELL_ACTION_CONTROL_BIT_22) != 0U) {
					result.bit22_skip_count += 1;
					continue;
				}
				if (!generated_cell_record_object_vector_empty_0x4a8260(record)) {
					result.object_reference_skip_count += 1;
					continue;
				}
				const int32_t owner_signed = int32_t(int8_t((record.word_0x20 >> 16U) & 0xffU));
				if (owner_signed >= 0) {
					result.non_negative_owner_skip_count += 1;
					continue;
				}
				const uint32_t terrain_class = record.word_0x24 & 0x3fU;
				if (terrain_class == 8U || terrain_class == 9U) {
					result.terrain8_or_9_skip_count += 1;
					continue;
				}
				const GeneratedCell49a962SweepResult sweep = generated_cell_49a962_record_grid(grid, x, y, level);
				result.call_count_0x49a962 += 1;
				result.neighbor_clear_count_0x49a962 += sweep.neighbor_clear_count;
			}
		}
	}
	result.applied = true;
	return result;
}

static bool generated_cell_grid_inputs_known_0x4a4913(const GeneratedCellRecordGrid0x30 &grid) {
	const int64_t expected_cell_count = int64_t(grid.width) * int64_t(grid.height) * int64_t(grid.level_count);
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || expected_cell_count <= 0 || expected_cell_count != int64_t(grid.records.size())) {
		return false;
	}
	for (const GeneratedCellRecord0x30 &record : grid.records) {
		if (!record.word_0x1c_known
				|| !record.word_0x20_known
				|| !record.word_0x24_known
				|| !record.word_0x28_known
				|| !record.word_0x2c_known) {
			return false;
		}
	}
	return true;
}

static void reset_relation_region_cell_0x4a4913(GeneratedCellRecord0x30 &record) {
	record.word_0x1c = (record.word_0x1c & 0x0000ffffU) | 0x7d000000U;
	record.word_0x1c_known = true;
	record.word_0x20 &= 0x00ffffffU;
	record.word_0x20_known = true;
	record.word_0x28 &= 0xffff8fffU;
	record.word_0x28_known = true;
	sync_generated_cell_byte_0x2b_from_word28(record);
}

static int32_t generated_cell_word1c_high_word_0x4a4913(const GeneratedCellRecord0x30 &record) {
	return int32_t((record.word_0x1c >> 16U) & 0xffffU);
}

static uint32_t generated_cell_word1c_set_high_word_0x4a4913(uint32_t word_0x1c, int32_t high_word) {
	return (word_0x1c & 0x0000ffffU) | ((uint32_t(high_word) & 0xffffU) << 16U);
}

static uint32_t generated_cell_word28_set_direction_0x4a4694(uint32_t word_0x28, int32_t direction_ordinal) {
	return (word_0x28 & 0xffff8fffU) | ((uint32_t(direction_ordinal) & 0x7U) << 12U);
}

static int32_t relation_bridge_seed_propagation_0x4a4694(
		GeneratedCellRecordGrid0x30 &grid,
		int32_t seed_x,
		int32_t seed_y,
		int32_t seed_level,
		int32_t relation_owner_byte2) {
	if (relation_owner_byte2 < 0) {
		return 0;
	}
	const int64_t seed_flat = cell_index(grid.width, grid.height, seed_x, seed_y, seed_level);
	if (seed_flat < 0 || seed_flat >= int64_t(grid.records.size())) {
		return 0;
	}
	GeneratedCellRecord0x30 &seed_record = grid.records[size_t(seed_flat)];
	seed_record.word_0x1c = generated_cell_word1c_set_high_word_0x4a4913(seed_record.word_0x1c, 0);
	seed_record.word_0x1c_known = true;
	seed_record.word_0x20 &= 0x00ffffffU;
	seed_record.word_0x20_known = true;
	seed_record.word_0x28 &= 0xffff8fffU;
	seed_record.word_0x28_known = true;
	sync_generated_cell_byte_0x2b_from_word28(seed_record);

	struct QueueNode4a4694 {
		int32_t x = 0;
		int32_t y = 0;
		int32_t level = 0;
		int32_t score = 0;
	};
	std::vector<QueueNode4a4694> queue;
	queue.push_back(QueueNode4a4694 { seed_x, seed_y, seed_level, 0 });
	int32_t relax_count = 0;
	while (!queue.empty()) {
		int32_t best_index = 0;
		for (int32_t index = 1; index < int32_t(queue.size()); ++index) {
			if (queue[size_t(index)].score < queue[size_t(best_index)].score) {
				best_index = index;
			}
		}
		const QueueNode4a4694 node = queue[size_t(best_index)];
		queue.erase(queue.begin() + best_index);
		const int64_t node_flat = cell_index(grid.width, grid.height, node.x, node.y, node.level);
		if (node_flat < 0 || node_flat >= int64_t(grid.records.size())) {
			continue;
		}
		const GeneratedCellRecord0x30 &node_record = grid.records[size_t(node_flat)];
		const int32_t node_score = generated_cell_word1c_high_word_0x4a4913(node_record);
		for (int32_t direction = 0; direction < int32_t(DIRECTION_TABLE_0X5A2658.size()); ++direction) {
			const int32_t next_x = node.x + DIRECTION_TABLE_0X5A2658[size_t(direction)][0];
			const int32_t next_y = node.y + DIRECTION_TABLE_0X5A2658[size_t(direction)][1];
			const int64_t next_flat = cell_index(grid.width, grid.height, next_x, next_y, node.level);
			if (next_flat < 0 || next_flat >= int64_t(grid.records.size())) {
				continue;
			}
			GeneratedCellRecord0x30 &next_record = grid.records[size_t(next_flat)];
			if (generated_cell_word20_owner_byte2_signed(next_record.word_0x20) != int32_t(int8_t(relation_owner_byte2 & 0xff))) {
				continue;
			}
			const int32_t next_score = node_score + ((direction & 1) != 0 ? 3 : 2);
			if (next_score >= generated_cell_word1c_high_word_0x4a4913(next_record)) {
				continue;
			}
			next_record.word_0x1c = generated_cell_word1c_set_high_word_0x4a4913(next_record.word_0x1c, next_score);
			next_record.word_0x1c_known = true;
			next_record.word_0x20 &= 0x00ffffffU;
			next_record.word_0x20_known = true;
			next_record.word_0x28 = generated_cell_word28_set_direction_0x4a4694(next_record.word_0x28, direction);
			next_record.word_0x28_known = true;
			sync_generated_cell_byte_0x2b_from_word28(next_record);
			queue.push_back(QueueNode4a4694 { next_x, next_y, node.level, next_score });
			relax_count += 1;
		}
	}
	return relax_count;
}

static int32_t relation_bridge_brush_0x4a4522(
		GeneratedCellRecordGrid0x30 &grid,
		int32_t low_x,
		int32_t low_y,
		int32_t high_x,
		int32_t high_y,
		int32_t level,
		H3MapedRng &rng,
		MaterializationBridgeRelationLoopResult4a4913 &result) {
	(void)(rng.next() % 6);
	result.rng_call_count_0x4e7276 += 1;
	int32_t set_count = 0;
	for (int32_t y = low_y; y < high_y; ++y) {
		for (int32_t x = low_x; x < high_x; ++x) {
			const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
			if (flat < 0 || flat >= int64_t(grid.records.size())) {
				continue;
			}
			GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
			if ((record.word_0x24 & 0x3fU) == 8U || (record.word_0x2c & 0x1U) != 0U) {
				continue;
			}
			const uint32_t previous = record.word_0x28;
			record.word_0x28 = (record.word_0x28 & ~CELL_OCCUPIED_BLOCKED_BIT_27) | CELL_DECOR_CANDIDATE_BIT_26;
			record.word_0x28_known = true;
			sync_generated_cell_byte_0x2b_from_word28(record);
			if (record.word_0x28 != previous) {
				set_count += 1;
			}
		}
	}
	return set_count;
}

static MaterializationBridgeRelationLoopResult4a4913 materialization_bridge_relation_loop_0x4a4913(
		GeneratorObjectPrivateState &state,
		H3MapedRng &rng) {
	MaterializationBridgeRelationLoopResult4a4913 result;
	result.relation_count = int32_t(state.relation_owner_vectors_10e4_10e8.size());
	if (!state.relation_owner_records_10e4_10e8_partial_known
			|| !state.relation_vector_10e4_10e8.present
			|| !state.relation_vector_10e4_10e8.contents_known
			|| !state.relation_vector_10e4_10e8.count_known
			|| state.relation_vector_10e4_10e8.count != result.relation_count) {
		result.blocked_reason = "0x4a4913_relation_vector_10e4_10e8_not_owned";
		return result;
	}
	if (!generated_cell_grid_inputs_known_0x4a4913(state.generated_cell_buffer)) {
		result.blocked_reason = "0x4a4913_generated_cell_grid_input_unknown";
		return result;
	}
	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (!owner.terrain_policy_0x0c_known
				|| !owner.scan_bounds_0x20_0x2c_known
				|| !owner.coordinate_triple_0x10_0x18_known
				|| !owner.source_pointer_0x00_known
				|| owner.source_pointer_source_index_0x00 < 0) {
			result.blocked_reason = "0x4a4913_relation_record_input_unknown";
			return result;
		}
	}
	result.input_known = true;

	for (const GeneratorRelationOwnerState4a218c &owner : state.relation_owner_vectors_10e4_10e8) {
		if (owner.terrain_policy_0x0c != 8) {
			result.non_type8_skip_count += 1;
			continue;
		}
		result.call_count_0x4a4913 += 1;
		const int32_t level = owner.coordinate_level_0x18;
		const int32_t relation_owner_byte2 = owner.source_pointer_source_index_0x00;
		for (int32_t y = owner.scan_bound_low_y_0x24; y < owner.scan_bound_high_y_0x2c; ++y) {
			for (int32_t x = owner.scan_bound_low_x_0x20; x < owner.scan_bound_high_x_0x28; ++x) {
				const int64_t flat = cell_index(state.width, state.height, x, y, level);
				if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
					continue;
				}
				reset_relation_region_cell_0x4a4913(state.generated_cell_buffer.records[size_t(flat)]);
				result.reset_cell_count += 1;
			}
		}

		const int32_t expanded_low_x = std::max<int32_t>(0, owner.scan_bound_low_x_0x20 - 1);
		const int32_t expanded_low_y = std::max<int32_t>(0, owner.scan_bound_low_y_0x24 - 1);
		const int32_t expanded_high_x = std::min<int32_t>(state.width, owner.scan_bound_high_x_0x28 + 1);
		const int32_t expanded_high_y = std::min<int32_t>(state.height, owner.scan_bound_high_y_0x2c + 1);
		for (int32_t y = expanded_low_y; y < expanded_high_y; ++y) {
			for (int32_t x = expanded_low_x; x < expanded_high_x; ++x) {
				const int64_t flat = cell_index(state.width, state.height, x, y, level);
				if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
					continue;
				}
				const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
				if (generated_cell_word20_owner_byte2_signed(record.word_0x20) == int32_t(int8_t(relation_owner_byte2 & 0xff))) {
					continue;
				}
				result.queue_relax_count_0x4a4694 += relation_bridge_seed_propagation_0x4a4694(
						state.generated_cell_buffer,
						x,
						y,
						level,
						relation_owner_byte2);
				result.foreign_seed_call_count_0x4a4694 += 1;
			}
		}

		const int32_t candidate_low_x = std::max<int32_t>(owner.scan_bound_low_x_0x20, 3);
		const int32_t candidate_low_y = std::max<int32_t>(owner.scan_bound_low_y_0x24, 3);
		const int32_t candidate_high_x = std::min<int32_t>(state.width - 4, owner.scan_bound_high_x_0x28);
		const int32_t candidate_high_y = std::min<int32_t>(state.height - 4, owner.scan_bound_high_y_0x2c);
		while (true) {
			std::vector<Coord12Candidate4a4913> candidates;
			for (int32_t y = candidate_low_y; y < candidate_high_y; ++y) {
				for (int32_t x = candidate_low_x; x < candidate_high_x; ++x) {
					const int64_t flat = cell_index(state.width, state.height, x, y, level);
					if (flat < 0 || flat >= int64_t(state.generated_cell_buffer.records.size())) {
						continue;
					}
					const GeneratedCellRecord0x30 &record = state.generated_cell_buffer.records[size_t(flat)];
					result.candidate_scan_count += 1;
					if ((record.word_0x1c & 0xffff0000U) < 0x00140000U) {
						continue;
					}
					candidates.push_back(Coord12Candidate4a4913 { x, y, level });
					result.candidate_append_count_0x4ae1fd += 1;
				}
			}
			if (candidates.empty()) {
				break;
			}
			const uint32_t selected_rng = rng.next();
			result.rng_call_count_0x4e7276 += 1;
			const Coord12Candidate4a4913 selected = candidates[size_t(selected_rng % uint32_t(candidates.size()))];
			const int64_t selected_flat = cell_index(state.width, state.height, selected.x, selected.y, selected.level);
			if (selected_flat < 0 || selected_flat >= int64_t(state.generated_cell_buffer.records.size())) {
				continue;
			}
			const int32_t selected_high_word = generated_cell_word1c_high_word_0x4a4913(
					state.generated_cell_buffer.records[size_t(selected_flat)]);
			const int32_t radius_divisor = (selected_high_word / 3) - 5;
			if (radius_divisor <= 0) {
				break;
			}
			const uint32_t radius_rng = rng.next();
			result.rng_call_count_0x4e7276 += 1;
			const int32_t radius = std::min<int32_t>(6, int32_t(radius_rng % uint32_t(radius_divisor)) + 3);
			const int32_t brush_low_x = std::max<int32_t>(0, selected.x - radius);
			const int32_t brush_low_y = std::max<int32_t>(0, selected.y - radius);
			const int32_t brush_high_x = std::min<int32_t>(state.width, selected.x + radius);
			const int32_t brush_high_y = std::min<int32_t>(state.height, selected.y + radius);
			result.brush_bit26_set_count_0x4a4522 += relation_bridge_brush_0x4a4522(
					state.generated_cell_buffer,
					brush_low_x,
					brush_low_y,
					brush_high_x,
					brush_high_y,
					level,
					rng,
					result);
			result.brush_call_count_0x4a4522 += 1;
			result.queue_relax_count_0x4a4694 += relation_bridge_seed_propagation_0x4a4694(
					state.generated_cell_buffer,
					selected.x,
					selected.y,
					selected.level,
					relation_owner_byte2);
			result.selected_seed_call_count_0x4a4694 += 1;
		}
	}
	result.applied = true;
	return result;
}

static MaterializationBridgeWaterEdgeWriterResult4a4fc5 materialization_bridge_water_edge_writer_0x4a4fc5(
		GeneratedCellRecordGrid0x30 &grid,
		const std::vector<GeneratorRelationOwnerState4a218c> &owners,
		const std::string &water_mode) {
	MaterializationBridgeWaterEdgeWriterResult4a4fc5 result;
	const int64_t expected_cell_count = int64_t(grid.width) * int64_t(grid.height) * int64_t(grid.level_count);
	if (grid.width <= 0 || grid.height <= 0 || grid.level_count <= 0 || expected_cell_count <= 0 || expected_cell_count != int64_t(grid.records.size())) {
		result.blocked_reason = "0x4a4fc5_invalid_generated_cell_grid";
		return result;
	}
	for (const GeneratedCellRecord0x30 &record : grid.records) {
		if (!record.object_reference_vector_fields_0x04_0x08_present
				|| !record.object_reference_vector_contents_known
				|| !record.word_0x20_known
				|| !record.word_0x24_known
				|| !record.word_0x28_known
				|| !record.word_0x2c_known) {
			result.blocked_reason = "0x4a4fc5_generated_cell_record_input_unknown";
			return result;
		}
	}
	if (!source_endpoint_records_known_for_lookup_0x49b3fb(owners)) {
		result.blocked_reason = "0x4a4fc5_source_endpoint_vector_0xc8_0xcc_input_unknown";
		return result;
	}
	result.input_known = true;
	if (water_mode != "land" || grid.level_count != 1) {
		result.blocked_reason = "0x4a4fc5_only_one_level_land_scope_is_source_backed";
		return result;
	}
	result.source_backed_land_scope = true;

	for (int32_t level = 0; level < grid.level_count; ++level) {
		for (int32_t y = 0; y < grid.height; ++y) {
			for (int32_t x = 0; x < grid.width; ++x) {
				const int64_t flat = cell_index(grid.width, grid.height, x, y, level);
				if (flat < 0 || flat >= int64_t(grid.records.size())) {
					continue;
				}
				GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
				result.scan_count += 1;
				if (generated_cell_word20_owner_byte2_signed(record.word_0x20) < 0) {
					result.owner_low_sentinel_skip_count += 1;
					continue;
				}
				if ((record.word_0x24 & 0x3fU) != 8U) {
					continue;
				}
				const int32_t source_owner_byte3 = generated_cell_word20_owner_byte3_signed(record.word_0x20);
				if (source_owner_byte3 < 0) {
					result.owner_high_sentinel_skip_count += 1;
					continue;
				}
				result.source_water_cell_count += 1;
				bool neighbor_source_found = false;
				int32_t replacement_terrain_id = 0;
				for (int32_t neighbor_y = std::max<int32_t>(0, y - 1); neighbor_y < std::min<int32_t>(grid.height, y + 2) && !neighbor_source_found; ++neighbor_y) {
					for (int32_t neighbor_x = std::max<int32_t>(0, x - 1); neighbor_x < std::min<int32_t>(grid.width, x + 2); ++neighbor_x) {
						const int64_t neighbor_flat = cell_index(grid.width, grid.height, neighbor_x, neighbor_y, level);
						if (neighbor_flat < 0 || neighbor_flat >= int64_t(grid.records.size())) {
							continue;
						}
						const GeneratedCellRecord0x30 &neighbor = grid.records[size_t(neighbor_flat)];
						result.neighbor_bit25_probe_count += 1;
						const uint32_t neighbor_terrain = neighbor.word_0x24 & 0x3fU;
						if (neighbor_terrain == 8U || neighbor_terrain == 9U) {
							continue;
						}
						if ((neighbor.word_0x28 & CELL_DECOR_CANDIDATE_BIT_26) != 0U) {
							continue;
						}
						if ((neighbor.word_0x28 & CELL_DECOR_READY_BIT_25) == 0U) {
							continue;
						}
						neighbor_source_found = true;
						replacement_terrain_id = int32_t(int8_t(neighbor.word_0x24 & 0x3fU));
						break;
					}
				}
				if (!neighbor_source_found) {
					continue;
				}
				const int32_t source_owner_byte2 = generated_cell_word20_owner_byte2_signed(record.word_0x20);
				if (source_endpoint_record_lookup_0x49b3fb(owners, source_owner_byte2, source_owner_byte3)) {
					result.relation_lookup_skip_count += 1;
					continue;
				}
				result.mutation_source_count += 1;
				for (int32_t mutation_y = std::max<int32_t>(0, y - 1); mutation_y < std::min<int32_t>(grid.height, y + 2); ++mutation_y) {
					for (int32_t mutation_x = std::max<int32_t>(0, x - 1); mutation_x < std::min<int32_t>(grid.width, x + 2); ++mutation_x) {
						const int64_t mutation_flat = cell_index(grid.width, grid.height, mutation_x, mutation_y, level);
						if (mutation_flat < 0 || mutation_flat >= int64_t(grid.records.size())) {
							continue;
						}
						GeneratedCellRecord0x30 &mutation_record = grid.records[size_t(mutation_flat)];
						if ((mutation_record.word_0x2c & 0x01U) == 0U) {
							const uint32_t previous = mutation_record.word_0x28;
							mutation_record.word_0x28 = (mutation_record.word_0x28 & ~CELL_OCCUPIED_BLOCKED_BIT_27) | CELL_DECOR_CANDIDATE_BIT_26;
							mutation_record.word_0x28_known = true;
							sync_generated_cell_byte_0x2b_from_word28(mutation_record);
							if (mutation_record.word_0x28 != previous) {
								result.bit26_set_count += 1;
							}
						}
						if ((mutation_record.word_0x24 & 0x3fU) == 8U) {
							(void)replacement_terrain_id;
							result.visual_repaint_pending_count += 1;
						}
					}
				}
				for (int32_t clear_y = std::max<int32_t>(0, y - 2); clear_y < std::min<int32_t>(grid.height, y + 3); ++clear_y) {
					for (int32_t clear_x = std::max<int32_t>(0, x - 2); clear_x < std::min<int32_t>(grid.width, x + 3); ++clear_x) {
						const int64_t clear_flat = cell_index(grid.width, grid.height, clear_x, clear_y, level);
						if (clear_flat < 0 || clear_flat >= int64_t(grid.records.size())) {
							continue;
						}
						GeneratedCellRecord0x30 &clear_record = grid.records[size_t(clear_flat)];
						if (!clear_record.object_references_0x04_0x08.empty() || (clear_record.word_0x2c & 0x01U) != 0U) {
							continue;
						}
						const uint32_t previous = clear_record.word_0x28;
						clear_record.word_0x28 &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
						clear_record.word_0x28_known = true;
						sync_generated_cell_byte_0x2b_from_word28(clear_record);
						if (clear_record.word_0x28 != previous) {
							result.byte2b_clear_count += 1;
						}
					}
				}
			}
		}
	}
	result.applied = true;
	return result;
}

static void initialize_generator_object_private_state_from_workflow_entry_0x49ecf2_0x49f95a(GeneratorObjectPrivateState &state, int32_t width, int32_t height, int32_t level_count, const GeneratorSetupModeResult49ecf2 &setup_mode, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result) {
	state = GeneratorObjectPrivateState();
	state.width = width;
	state.height = height;
	state.level_count = level_count;
	state.generator_value_band_0x10bc_known = setup_mode.generator_value_band_0x10bc_known;
	state.generator_value_band_0x10bc = setup_mode.generator_value_band_0x10bc;
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
	state.endpoint_vector_c8_cc = generator_object_vector_state("endpoint_projection_pointer_vector_0xc8_0xcc", 0xc8U, 0xccU, 0U, true, false, false, 0, 4);
	state.endpoint_vector_d8_dc = generator_object_vector_state("endpoint_cursor_pointer_vector_0xd8_0xdc", 0xd8U, 0xdcU, 0U, true, false, false, 0, 4);
	state.mine_resource_descriptor_vector_entries_388_38c = generator_mine_resource_descriptor_vector_entries_from_source_catalog_0x49da08_0x388_0x38c();
	state.mine_resource_descriptor_vector_entry_count_388_38c = int32_t(state.mine_resource_descriptor_vector_entries_388_38c.size());
	state.mine_resource_descriptor_vector_388_38c = generator_object_vector_state(
			"mine_resource_descriptor_pointer_vector_0x388_0x38c",
			0x388U,
			0x38cU,
			0U,
			!state.mine_resource_descriptor_vector_entries_388_38c.empty(),
			true,
			true,
			state.mine_resource_descriptor_vector_entry_count_388_38c,
			4);
	state.mine_resource_descriptor_vector_388_38c_source_owned =
			state.mine_resource_descriptor_vector_388_38c.present
			&& state.mine_resource_descriptor_vector_388_38c.contents_known
			&& state.mine_resource_descriptor_vector_388_38c.count_known;
	state.descriptor_vector_entries_398_39c = generator_descriptor_vector_entries_from_source_catalog_0x49da08_0x398_0x39c();
	state.descriptor_vector_entry_count_398_39c = int32_t(state.descriptor_vector_entries_398_39c.size());
	state.descriptor_vector_398_39c = generator_object_vector_state(
			"descriptor_pointer_vector_0x398_0x39c",
			0x398U,
			0x39cU,
			0U,
			!state.descriptor_vector_entries_398_39c.empty(),
			true,
			true,
			state.descriptor_vector_entry_count_398_39c,
			4);
	state.descriptor_vector_398_39c_source_owned =
			state.descriptor_vector_398_39c.present
			&& state.descriptor_vector_398_39c.contents_known
			&& state.descriptor_vector_398_39c.count_known;
	state.object_record_vector_ec4_ecc = generator_object_vector_state("object_record_vector_0xec4_0xecc", 0xec4U, 0xeccU, 0U, true, false, false, 0, 4);
	state.source_pair_vector_edc = generator_object_vector_state("source_pair_metadata_vector_0xedc", 0xedcU, 0U, 0U, true, false, false, 0, 8);
	state.pending_entry_vector_eec_ef0_ef4 = generator_object_vector_state("source_handler_pending_entry_vector_0xeec_0xef0_0xef4_source_excluded_for_direct_mode", 0xeecU, 0xef0U, 0xef4U, true, false, true, 0, 8);
	state.candidate_container_vector_10d4_10d8 = generator_object_vector_state("accepted_candidate_container_vector_0x10d4_0x10d8", 0x10d4U, 0x10d8U, 0U, template_selection.accepted_template_count > 0 || !template_selection.accepted_candidate_containers_10d4_10d8.empty(), true, true, int32_t(template_selection.accepted_candidate_containers_10d4_10d8.size()), 4);
	state.candidate_container_records_10d4_10d8 = template_selection.accepted_candidate_containers_10d4_10d8;
	if (template_selection.selected_vector_index >= 0
			&& template_selection.selected_vector_index < int32_t(state.candidate_container_records_10d4_10d8.size())) {
		state.selected_candidate_container_0x4ac552_known = true;
		state.selected_candidate_container_0x4ac552 =
				state.candidate_container_records_10d4_10d8[size_t(template_selection.selected_vector_index)];
	}
	state.relation_vector_10e4_10e8 = generator_object_vector_state(
			"relation_vector_0x10e4_0x10e8",
			0x10e4U,
			0x10e8U,
			0U,
			!template_selection.blocked,
			false,
			false,
			0,
			4);
	state.reward_guard_candidate_vector_10f4_10f8 = generator_object_vector_state(
			"reward_guard_candidate_bucket_vector_0x10f4_0x10f8",
			REWARD_GUARD_CANDIDATE_VECTOR_BEGIN_0X10F4,
			REWARD_GUARD_CANDIDATE_VECTOR_END_0X10F8,
			REWARD_GUARD_CANDIDATE_VECTOR_CAPACITY_0X10FC,
			!template_selection.blocked,
			false,
			false,
			0,
			4);
	state.reward_guard_candidate_records_10f4_10f8 = reward_guard_candidate_records_single_level_land_49f95a();
	state.reward_guard_candidate_records_10f4_10f8_contents_known =
			!template_selection.blocked
			&& state.reward_guard_candidate_records_10f4_10f8.size() == size_t(704);
	state.reward_guard_candidate_record_count_10f4_10f8 =
			int32_t(state.reward_guard_candidate_records_10f4_10f8.size());
	state.reward_guard_candidate_vector_10f4_10f8.contents_known =
			state.reward_guard_candidate_records_10f4_10f8_contents_known;
	state.reward_guard_candidate_vector_10f4_10f8.count_known =
			state.reward_guard_candidate_records_10f4_10f8_contents_known;
	state.reward_guard_candidate_vector_10f4_10f8.count =
			state.reward_guard_candidate_record_count_10f4_10f8;
	state.endpoint_byte_state_vector_1104_1108 = endpoint_byte_state_vector_from_d8_count_0x49f95a(state.endpoint_vector_d8_dc);
	state.endpoint_cursor_0xf58_present = true;
	state.endpoint_cursor_0xf58_known = true;
	state.endpoint_cursor_0xf58 = 0;
	state.endpoint_cursor_0xf5c_present = true;
	state.endpoint_cursor_0xf5c_known = true;
	state.endpoint_cursor_0xf5c = int32_t(0x7a1befdfU);
	state.descriptor_counter_table_0x1110_present = true;
	state.descriptor_counter_table_0x1110_contents_known = true;
	state.descriptor_counter_table_0x1110_known_count = DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	state.descriptor_counter_table_0x1110.assign(size_t(DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	state.reward_guard_projection_generator_0x10b4_known = true;
	state.reward_guard_projection_generator_0x10b4 = false;
	state.reward_guard_terrain_pressure_zeroed_0x4aadd2 = false;
	state.reward_guard_terrain_pressure_0xf60_0xf64_known = false;
	state.reward_guard_terrain_pressure_total_0xf60 = 0;
	state.reward_guard_terrain_pressure_by_terrain_0xf64.fill(0);
	state.reward_guard_projection_used_flags_0x1024_known = true;
	state.reward_guard_projection_used_flags_0x1024_count = REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947;
	state.reward_guard_projection_used_flags_0x1024_zero_count = REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947;
	state.reward_guard_projection_used_flags_0x1024.assign(size_t(REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947), 0U);
	state.object_record_sequence_allocator_0xf44_present = true;
	state.object_record_sequence_allocator_0xf44_known = true;
	state.object_record_sequence_allocator_0xf44 = 1;
	state.native_object_record_key_allocator_0x4a93a2_known = true;
	state.next_native_object_record_key_0x4a93a2 = 1U;
	state.weighted_scheduler_thresholds_0x4a8db2_known = false;
	state.weighted_scheduler_threshold_count_0x4a8db2 = 0;
	state.source_owner_player_slots_ed8_ee0_ee4_present = template_selection.player_assignment.complete;
	state.selected_color_order_ed8_count = int32_t(template_selection.player_assignment.selected_color_order_ed8.size());
	state.raw_source_owner_slots_ee0_count = int32_t(template_selection.player_assignment.raw_ee0_slots.size());
	state.mapped_source_owner_slots_ee4_count = int32_t(template_selection.player_assignment.mapped_ee4_slots.size());
	state.selected_color_order_ed8 = template_selection.player_assignment.selected_color_order_ed8;
	state.raw_source_owner_slots_ee0 = template_selection.player_assignment.raw_ee0_slots;
	state.mapped_source_owner_slots_ee4 = template_selection.player_assignment.mapped_ee4_slots;
	state.relation_owner_records_10e4_10e8_partial_known = false;
	state.relation_owner_vector_count_10e4_10e8 = 0;
	state.relation_record_count_10e4_10e8 = 0;
	state.relation_record_missing_endpoint_count_10e4_10e8 = 0;
	state.reward_guard_relation_priority_helper_0x4ad6a8_0x4ad7f7_ported = true;
	state.reward_guard_relation_priority_live_replay_blocked = false;
	state.reward_guard_projection_driver_selection_0x4ad947_ported = true;
	state.reward_guard_projection_driver_selection_input_known = false;
	state.reward_guard_projection_source_relation_0x4ad947_ported = true;
	state.reward_guard_projection_source_relation_input_known = false;
	state.reward_guard_projection_object_0x540b14_input_known = false;
	state.reward_guard_projection_object_0x540b14.live_input_known = false;
	state.reward_guard_source_stream_0x4aab7e_ported = true;
	state.reward_guard_source_stream_0x4aab7e_input_known = false;
	state.reward_guard_source_stream_owner_kind_0x0c_known = false;
	state.reward_guard_relation_priority_0x4ad7f7.relation_owner_count = 0;
	state.reward_guard_selector_0x4a9f1c_counter_limit_contract_ported = true;
}

static void advance_generator_object_private_state_source_order_to_current_blocker(GeneratorObjectPrivateState &state, const std::string &size_class, const std::string &water_mode, uint32_t seed, int32_t human_count, int32_t player_count, bool setup_object_0x44_known, int32_t setup_object_0x44, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result) {
	H3MapedRng route_free_cell_rng;
	if (coordinate_result.terrain_repaint_executed) {
		route_free_cell_rng.state = coordinate_result.terrain_repaint.terrain_visual_rng_state_after_0x4bb74b;
	} else if (coordinate_result.terrain_selection_executed) {
		route_free_cell_rng.state = coordinate_result.terrain_selection.rng_state_after;
	} else {
		route_free_cell_rng.state = coordinate_result.coordinate_seed.rng_state_after;
	}
	if (!produce_relation_owner_vector_from_selected_candidate_0x4ac552_0x4a218c(state, template_selection, coordinate_result)) {
		if (state.relation_owner_vector_producer_blocked_reason.empty()) {
			state.relation_owner_vector_producer_blocked_reason =
					"0x4ac552_0x4a218c_selected_candidate_relation_owner_vector_not_owned";
		}
		state.remaining_private_state_blockers = {
			state.relation_owner_vector_producer_blocked_reason,
			"source_order_relation_pointer_loop_0x4a8d2c_0x4a8db2_not_executed_until_0x10e4_relation_vector_is_owned",
			"route_free_cell_sweep_0x4a8c15_0x4a8260_0x4a4c8e_not_executed_until_0x10e4_relation_vector_is_owned",
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x10e4_relation_vector_is_owned",
			"reward_guard_materialization_not_executed_until_0x10e4_relation_vector_is_owned",
			"connection_road_river_0x4a79a3_not_executed_until_source_order_payload_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	const bool source_order_relation_pointer_loop_owned =
			replay_relation_pointer_source_order_loop_0x4ac552_0x4a8d2c_0x4a8db2(state, route_free_cell_rng);
	if (!source_order_relation_pointer_loop_owned) {
		if (state.source_order_relation_pointer_loop_0x4ac552_blocked_reason.empty()) {
			state.source_order_relation_pointer_loop_0x4ac552_blocked_reason =
					"0x4ac552_relation_pointer_source_order_loop_not_owned_before_0x4a8c15";
		}
		state.remaining_private_state_blockers = {
			state.source_order_relation_pointer_loop_0x4ac552_blocked_reason,
			"route_free_cell_sweep_0x4a8c15_0x4a8260_0x4a4c8e_not_executed_until_0x4ac552_relation_pointer_source_order_loop_is_owned",
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x4ac552_relation_pointer_source_order_loop_is_owned",
			"relation_scan_consumers_0x4a5767_not_executed_until_0x4ac552_relation_pointer_source_order_loop_is_owned",
			"reward_guard_materialization_not_executed_until_0x4ac552_relation_pointer_source_order_loop_is_owned",
			"connection_road_river_0x4a79a3_not_executed_until_source_order_payload_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	const RouteFreeCellPhaseResult4a8260 route_free_cell_phase =
			route_free_cell_phase_0x4a8260_0x4a4c8e(
					state.generated_cell_buffer,
					state.relation_owner_vectors_10e4_10e8,
					route_free_cell_rng);
	state.route_container_free_cell_sweep_0x4a8260_ported = route_free_cell_phase.route_0x4a8260_ported;
	state.route_container_free_cell_sweep_0x4a8260_input_known = route_free_cell_phase.input_known;
	state.route_container_free_cell_sweep_0x4a8260_applied =
			route_free_cell_phase.route_0x4a8260_applied
			&& route_free_cell_phase.candidate_boundary_0x4a4c8e_applied;
	state.route_container_free_cell_sweep_0x4a8260_blocked_reason = route_free_cell_phase.blocked_reason;
	if (!state.route_container_free_cell_sweep_0x4a8260_applied
			|| !state.route_container_free_cell_sweep_0x4a8260_blocked_reason.empty()) {
		if (state.route_container_free_cell_sweep_0x4a8260_blocked_reason.empty()) {
			state.route_container_free_cell_sweep_0x4a8260_blocked_reason =
					"route_container_free_cell_sweep_0x4a8260_or_candidate_relation_0x4a4c8e_not_applied";
		}
		state.remaining_private_state_blockers = {
			state.route_container_free_cell_sweep_0x4a8260_blocked_reason,
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x4a8260_0x4a4c8e_are_owned",
			"relation_scan_consumers_0x4a5767_not_executed_until_0x4a8260_0x4a4c8e_are_owned",
			"source_order_object_materialization_not_executed_until_0x4a8260_0x4a4c8e_are_owned",
			"reward_guard_materialization_not_executed_until_0x4a8260_0x4a4c8e_are_owned",
			"connection_road_river_0x4a79a3_not_executed_until_upstream_generated_cell_phase_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_ported = true;
	const Post4a4c8eCleanupResult4a8c15 post_4a4c8e_cleanup =
			post_4a4c8e_cleanup_scan_0x4a8c15(state.generated_cell_buffer);
	state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_input_known =
			post_4a4c8e_cleanup.input_known;
	state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_applied =
			post_4a4c8e_cleanup.applied;
	state.materialization_bridge_post_4a4c8e_cleanup_scan_count_0x4a8c15 =
			post_4a4c8e_cleanup.scan_count;
	state.materialization_bridge_post_4a4c8e_cleanup_call_count_0x49a962 =
			post_4a4c8e_cleanup.call_count_0x49a962;
	if (!post_4a4c8e_cleanup.applied || !post_4a4c8e_cleanup.blocked_reason.empty()) {
		if (state.materialization_bridge_0x4a8c15_blocked_reason.empty()) {
			state.materialization_bridge_0x4a8c15_blocked_reason =
					post_4a4c8e_cleanup.blocked_reason.empty()
					? "0x4a8c15_post_0x4a4c8e_cleanup_not_applied"
					: post_4a4c8e_cleanup.blocked_reason;
		}
		state.remaining_private_state_blockers = {
			state.materialization_bridge_0x4a8c15_blocked_reason,
			"relation_loop_0x4a4913_not_executed_until_0x4a8c15_post_0x4a4c8e_cleanup_is_owned",
			"bridge_relation_normalization_0x4a5767_not_executed_until_0x4a4913_is_owned",
			"bridge_water_edge_writer_0x4a4fc5_not_executed_until_0x4a4913_is_owned",
			"connection_tail_0x4a79a3_not_executed_until_0x4a4913_is_owned",
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x4a8c15_materialization_bridge_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	state.materialization_bridge_relation_loop_0x4a4913_ported = true;
	const MaterializationBridgeRelationLoopResult4a4913 relation_loop =
			materialization_bridge_relation_loop_0x4a4913(state, route_free_cell_rng);
	state.materialization_bridge_relation_loop_0x4a4913_input_known = relation_loop.input_known;
	state.materialization_bridge_relation_loop_0x4a4913_applied = relation_loop.applied;
	state.materialization_bridge_relation_loop_relation_count_0x4a4913 = relation_loop.relation_count;
	state.materialization_bridge_relation_loop_call_count_0x4a4913 = relation_loop.call_count_0x4a4913;
	state.materialization_bridge_relation_loop_non_type8_skip_count_0x4a4913 = relation_loop.non_type8_skip_count;
	state.materialization_bridge_relation_loop_reset_cell_count_0x4a4913 = relation_loop.reset_cell_count;
	state.materialization_bridge_relation_loop_foreign_seed_call_count_0x4a4694 = relation_loop.foreign_seed_call_count_0x4a4694;
	state.materialization_bridge_relation_loop_candidate_scan_count_0x4a4913 = relation_loop.candidate_scan_count;
	state.materialization_bridge_relation_loop_candidate_append_count_0x4ae1fd = relation_loop.candidate_append_count_0x4ae1fd;
	state.materialization_bridge_relation_loop_rng_call_count_0x4e7276 = relation_loop.rng_call_count_0x4e7276;
	state.materialization_bridge_relation_loop_brush_call_count_0x4a4522 = relation_loop.brush_call_count_0x4a4522;
	state.materialization_bridge_relation_loop_selected_seed_call_count_0x4a4694 = relation_loop.selected_seed_call_count_0x4a4694;
	state.materialization_bridge_relation_loop_queue_relax_count_0x4a4694 = relation_loop.queue_relax_count_0x4a4694;
	state.materialization_bridge_relation_loop_brush_bit26_set_count_0x4a4522 = relation_loop.brush_bit26_set_count_0x4a4522;
	if (!relation_loop.applied || !relation_loop.blocked_reason.empty()) {
		state.materialization_bridge_0x4a8c15_blocked_reason =
				relation_loop.blocked_reason.empty()
				? "0x4a4913_relation_loop_not_applied"
				: relation_loop.blocked_reason;
		const std::string materialization_bridge_blocker = state.materialization_bridge_0x4a8c15_blocked_reason;
		state.remaining_private_state_blockers = {
			materialization_bridge_blocker,
			"bridge_relation_normalization_0x4a5767_not_executed_until_0x4a4913_is_owned",
			"bridge_water_edge_writer_0x4a4fc5_not_executed_until_0x4a4913_is_owned",
			"connection_tail_0x4a79a3_not_executed_until_0x4a4913_is_owned",
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x4a8c15_materialization_bridge_is_owned",
			"relation_scan_consumers_0x4a5767_not_executed_until_0x4a8c15_materialization_bridge_is_owned",
			"source_order_object_materialization_not_executed_until_0x4a8c15_materialization_bridge_is_owned",
			"reward_guard_materialization_not_executed_until_0x4a8c15_materialization_bridge_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	apply_materialization_bridge_relation_normalization_0x4a5767(state, route_free_cell_rng);
	state.materialization_bridge_water_edge_writer_0x4a4fc5_ported = true;
	const MaterializationBridgeWaterEdgeWriterResult4a4fc5 water_edge_writer =
			materialization_bridge_water_edge_writer_0x4a4fc5(
					state.generated_cell_buffer,
					state.relation_owner_vectors_10e4_10e8,
					water_mode);
	state.materialization_bridge_water_edge_writer_0x4a4fc5_input_known = water_edge_writer.input_known;
	state.materialization_bridge_water_edge_writer_0x4a4fc5_applied = water_edge_writer.applied;
	state.materialization_bridge_water_edge_writer_0x4a4fc5_source_backed_land_scope =
			water_edge_writer.source_backed_land_scope;
	state.materialization_bridge_water_edge_writer_scan_count_0x4a4fc5 =
			water_edge_writer.scan_count;
	state.materialization_bridge_water_edge_writer_owner_low_sentinel_skip_count_0x4a4fc5 =
			water_edge_writer.owner_low_sentinel_skip_count;
	state.materialization_bridge_water_edge_writer_owner_high_sentinel_skip_count_0x4a4fc5 =
			water_edge_writer.owner_high_sentinel_skip_count;
	state.materialization_bridge_water_edge_writer_source_water_cell_count_0x4a4fc5 =
			water_edge_writer.source_water_cell_count;
	state.materialization_bridge_water_edge_writer_relation_lookup_skip_count_0x4a4fc5 =
			water_edge_writer.relation_lookup_skip_count;
	state.materialization_bridge_water_edge_writer_mutation_source_count_0x4a4fc5 =
			water_edge_writer.mutation_source_count;
	state.materialization_bridge_water_edge_writer_bit26_set_count_0x4a4fc5 =
			water_edge_writer.bit26_set_count;
	state.materialization_bridge_water_edge_writer_byte2b_clear_count_0x4a4fc5 =
			water_edge_writer.byte2b_clear_count;
	state.materialization_bridge_water_edge_writer_visual_repaint_pending_count_0x4a4fc5 =
			water_edge_writer.visual_repaint_pending_count;
	state.materialization_bridge_water_edge_writer_neighbor_bit25_probe_count_0x4a4fc5 =
			water_edge_writer.neighbor_bit25_probe_count;
	state.materialization_bridge_water_edge_writer_bit26_candidate_count_0x4a4fc5 =
			water_edge_writer.bit26_candidate_count;
	state.materialization_bridge_water_edge_writer_blocked_reason_0x4a4fc5 =
			water_edge_writer.blocked_reason;
	if (!water_edge_writer.applied || !water_edge_writer.blocked_reason.empty()) {
		state.materialization_bridge_0x4a8c15_blocked_reason =
				water_edge_writer.blocked_reason.empty()
				? "0x4a4fc5_bridge_water_edge_writer_not_applied"
				: water_edge_writer.blocked_reason;
		const std::string materialization_bridge_blocker = state.materialization_bridge_0x4a8c15_blocked_reason;
		state.remaining_private_state_blockers = {
			materialization_bridge_blocker,
			"connection_tail_0x4a79a3_not_executed_until_0x4a4fc5_is_owned",
			"mine_resource_materialization_0x4a9d6a_not_executed_until_0x4a8c15_0x4a4fc5_0x4a79a3_materialization_bridge_is_owned",
			"source_order_object_materialization_not_executed_until_0x4a8c15_0x4a4fc5_0x4a79a3_materialization_bridge_is_owned",
			"reward_guard_materialization_not_executed_until_0x4a8c15_0x4a4fc5_0x4a79a3_materialization_bridge_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	state.materialization_bridge_0x4a8c15_blocked_reason =
			"";
	state.mine_resource_materialization_0x4a9d6a_ported = true;
	state.mine_resource_materialization_0x4a9d6a = mine_resource_materialization_0x4a9d6a(state, route_free_cell_rng);
	state.mine_resource_materialization_0x4a9d6a_input_known =
			state.mine_resource_materialization_0x4a9d6a.relation_vector_known;
	if (!state.mine_resource_materialization_0x4a9d6a.applied
			|| !state.mine_resource_materialization_0x4a9d6a.blocked_reason.empty()) {
		const std::string blocker = state.mine_resource_materialization_0x4a9d6a.blocked_reason.empty()
				? "0x4a9d6a_mine_resource_materialization_not_applied"
				: state.mine_resource_materialization_0x4a9d6a.blocked_reason;
		state.remaining_private_state_blockers = {
			blocker,
			"reward_guard_terrain_pressure_0x4aadd2_not_source_ordered_until_0x4a9d6a_is_owned",
			"relation_scan_consumers_0x4a5767_not_executed_until_0x4a9d6a_mine_resource_materialization_is_owned",
			"source_order_object_materialization_not_executed_until_0x4a9d6a_mine_resource_materialization_is_owned",
			"reward_guard_materialization_not_executed_until_0x4a9d6a_mine_resource_materialization_is_owned",
			"connection_road_river_0x4a79a3_not_executed_until_upstream_mine_resource_phase_is_owned",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	state.reward_guard_terrain_pressure_zeroed_0x4aadd2 = true;
	state.reward_guard_terrain_pressure_0xf60_0xf64_known = true;
	state.reward_guard_terrain_pressure_total_0xf60 = 0;
	state.reward_guard_terrain_pressure_by_terrain_0xf64.fill(0);
	apply_relation_normalization_full_grid_reset_0x4a5767(state);
	SourceObjectResolverState4af785 relation_scan_resolver_state;
	H3MapedRng relation_scan_rng;
	relation_scan_rng.state = route_free_cell_rng.state;
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
	apply_relation_high_owner_propagation_49a318(state);
	state.reward_guard_materialization_driver_0x4aa354_ported = true;
	state.reward_guard_source_stream_0x4aab7e_ported = true;
	state.reward_guard_source_stream_0x4aab7e =
			reward_guard_source_order_loop_0x4ac552_0x4aab7e(state, relation_scan_rng);
	state.reward_guard_source_stream_0x4aab7e_input_known =
			reward_guard_source_pointer_vector_0x10e4_0x10e8_known_for_0x4aab7e(state)
			&& std::all_of(
					state.relation_owner_vectors_10e4_10e8.begin(),
					state.relation_owner_vectors_10e4_10e8.end(),
					[](const GeneratorRelationOwnerState4a218c &owner) {
						return owner.reward_guard_source_bands_0xa0_0xc0_known;
					});
	state.reward_guard_source_stream_owner_kind_0x0c_known =
			!state.relation_owner_vectors_10e4_10e8.empty()
			&& std::all_of(
					state.relation_owner_vectors_10e4_10e8.begin(),
					state.relation_owner_vectors_10e4_10e8.end(),
					[](const GeneratorRelationOwnerState4a218c &owner) {
						return owner.terrain_policy_0x0c_known;
					});
	state.reward_guard_materialization_driver_input_known =
			state.reward_guard_source_stream_0x4aab7e_input_known
			&& state.reward_guard_source_stream_owner_kind_0x0c_known
			&& state.reward_guard_source_stream_0x4aab7e.invoked
			&& state.reward_guard_source_stream_0x4aab7e.source_triplet_known
			&& state.reward_guard_source_stream_0x4aab7e.source_object_kind_0x0c_known;
	if (!state.reward_guard_source_stream_0x4aab7e.attempts.empty()) {
		state.reward_guard_materialization_driver_0x4aa354 =
				state.reward_guard_source_stream_0x4aab7e.attempts.back().materialization_0x4aa354;
	} else {
		state.reward_guard_materialization_driver_0x4aa354.blocked_reason =
				state.reward_guard_source_stream_0x4aab7e.blocked_reason;
	}
	if (!state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()) {
		state.remaining_private_state_blockers = {
			state.reward_guard_source_stream_0x4aab7e.blocked_reason,
			"connection_road_river_0x4a79a3_not_executed_until_reward_guard_source_stream_commits_are_owned",
			"decorative_dispatch_0x49eb8d_not_executed_until_reward_guard_source_stream_commits_are_owned",
			"road_river_object_adjacency_0x4ab52a_replay_unported_after_source_order_connection_tail",
			"descriptor_counter_table_0x1110_later_increment_decrement_replay_unported",
		};
		return;
	}
	if (state.reward_guard_source_stream_0x4aab7e.invoked
			&& state.reward_guard_source_stream_0x4aab7e.applied
			&& state.reward_guard_source_stream_0x4aab7e.materialization_attempt_count > 0
			&& state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count == 0) {
		const std::string reward_guard_zero_commit_blocker =
				reward_guard_zero_commit_blocker_detail_0x4aab7e(state.reward_guard_source_stream_0x4aab7e);
		state.remaining_private_state_blockers = {
			reward_guard_zero_commit_blocker,
			"connection_road_river_0x4a79a3_not_executed_until_reward_guard_source_stream_commits_are_owned",
			"decorative_dispatch_0x49eb8d_not_executed_until_reward_guard_source_stream_commits_are_owned",
			"road_river_object_adjacency_0x4ab52a_replay_unported_after_source_order_connection_tail",
			"descriptor_counter_table_0x1110_later_increment_decrement_replay_unported",
		};
		return;
	}
	state.decorative_flagged_cell_dispatch_0x49eb8d_ported = true;
	state.decorative_flagged_cell_dispatch_0x49eb8d =
			decorative_flagged_cell_dispatch_0x49eb8d(state);
	if (!state.decorative_flagged_cell_dispatch_0x49eb8d.applied
			|| !state.decorative_flagged_cell_dispatch_0x49eb8d.blocked_reason.empty()) {
		const std::string decorative_blocker =
				state.decorative_flagged_cell_dispatch_0x49eb8d.blocked_reason.empty()
				? "0x49eb8d_decorative_flagged_cell_dispatch_not_applied_after_reward_guard"
				: state.decorative_flagged_cell_dispatch_0x49eb8d.blocked_reason;
		state.remaining_private_state_blockers = {
			decorative_blocker,
			"road_river_object_adjacency_0x4ab52a_replay_unported_after_0x49eb8d",
			"descriptor_counter_table_0x1110_later_increment_decrement_replay_unported",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
	apply_endpoint_materialization_state_d014(state, size_class, water_mode, seed, human_count, player_count, setup_object_0x44_known, setup_object_0x44);
	state.connection_tail_replay_0x4a79a3_ported = true;
	state.connection_tail_replay_0x4a79a3 = connection_tail_replay_0x4a79a3(state, relation_scan_rng);
	if (!state.connection_tail_replay_0x4a79a3.applied
			|| !state.connection_tail_replay_0x4a79a3.blocked_reason.empty()) {
		const std::string connection_blocker =
				state.connection_tail_replay_0x4a79a3.blocked_reason.empty()
				? "0x4a79a3_connection_tail_replay_not_applied_after_reward_guard"
				: state.connection_tail_replay_0x4a79a3.blocked_reason;
		state.remaining_private_state_blockers = {
			connection_blocker,
			"road_river_object_adjacency_0x4ab52a_replay_unported_after_source_order_connection_tail",
			"descriptor_counter_table_0x1110_later_increment_decrement_replay_unported",
			"final_writeout_not_executed_until_source_order_payload_is_owned",
		};
		return;
	}
}

H3MapedRmgWorkflowResult run_h3maped_rmg_entry_to_writeout_workflow(const H3MapedRmgWorkflowConfig &config) {
	H3MapedRmgWorkflowResult result;
	result.config = config;
	result.status = "blocked";
	result.blocked_reason = "h3maped_rmg_workflow_not_started";
	result.current_phase_id = "entry_scope";
	result.supported_scope = supports_one_level_land_scope(
			config.width,
			config.height,
			config.level_count,
			config.water_mode,
			config.size_class);

	auto add_phase = [&result](const std::string &id, const std::string &anchor, const std::string &status, const std::string &blocker) {
		H3MapedRmgWorkflowPhase phase;
		phase.id = id;
		phase.h3maped_anchor = anchor;
		phase.status = status;
		phase.blocker = blocker;
		result.phases.push_back(phase);
	};

	if (!result.supported_scope) {
		result.status = "unsupported_scope";
		result.blocked_reason = "standalone_h3maped_workflow_currently_scopes_only_small_medium_one_level_land";
		add_phase("entry_scope", "0x4adfe1_h3maped_random_map_entry_scope", "unsupported_scope", result.blocked_reason);
		return result;
	}
	add_phase("entry_scope", "0x4adfe1_h3maped_random_map_entry_scope", "complete", "");

	if (!config.setup_object_0x44_known) {
		result.current_phase_id = "setup_template_selection";
		result.status = "blocked";
		result.blocked_reason = "rmg_setup_object_0x44_before_0x49ecf2_template_selection";
		result.missing_inputs.push_back(result.blocked_reason);
		add_phase("setup_template_selection", "0x49ecf2_0x49f0cd_0x4ac552", "blocked", result.blocked_reason);
		add_phase("coordinate_boundary_terrain", "0x4a218c_0x4a1f3b_0x4a19ed_0x4a3a03_0x4cca55_0x4a2777_0x4a325d_0x4a3710_0x49b53d_0x4a3f27", "pending", "blocked_before_setup_template_selection");
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "pending", "blocked_before_coordinate_boundary_terrain");
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_mine_resource_materialization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}

	result.setup_mode_0x49ecf2 = generator_setup_mode_49ecf2(
			config.seed,
			config.setup_object_0x44,
			config.setup_object_0x48_known,
			config.setup_object_0x48);
	const int32_t score = size_score(
			config.width,
			config.height,
			config.level_count,
			water_mode_code(config.water_mode));
	result.template_selection_0x4ac552 =
			template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
					result.setup_mode_0x49ecf2.rng_state_before_template_selection,
					score,
					config.human_count,
					config.player_count);
	result.executed = true;
	if (result.template_selection_0x4ac552.blocked
			|| result.template_selection_0x4ac552.runtime_seed.blocked
			|| result.template_selection_0x4ac552.runtime_seed.runtime_zone_seeds.empty()) {
		result.current_phase_id = "setup_template_selection";
		result.status = "blocked";
		result.blocked_reason = "h3maped_workflow_template_selection_or_runtime_seed_build_blocked";
		if (result.template_selection_0x4ac552.runtime_seed.runtime_zone_seeds.empty()) {
			result.missing_inputs.push_back("runtime_zone_seed_inputs");
		}
		add_phase("setup_template_selection", "0x49ecf2_0x49f0cd_0x4ac552", "blocked", result.blocked_reason);
		add_phase("coordinate_boundary_terrain", "0x4a218c_0x4a1f3b_0x4a19ed_0x4a3a03_0x4cca55_0x4a2777_0x4a325d_0x4a3710_0x49b53d_0x4a3f27", "pending", "blocked_before_runtime_zone_seed_inputs");
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "pending", "blocked_before_coordinate_boundary_terrain");
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_mine_resource_materialization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("setup_template_selection", "0x49ecf2_0x49f0cd_0x4ac552", "complete", "");

	result.coordinate_owner_grid_0x4a218c =
			coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
					config.width,
					config.height,
					config.level_count,
					water_mode_code(config.water_mode),
					result.setup_mode_0x49ecf2.generator_mode_0x10b8,
					result.template_selection_0x4ac552.rng_state_after_template_selection,
					result.template_selection_0x4ac552.runtime_seed.runtime_zone_seeds,
					result.template_selection_0x4ac552.runtime_seed.runtime_links);
	const bool coordinate_terrain_done = result.coordinate_owner_grid_0x4a218c.owner_grid_executed
			&& !result.coordinate_owner_grid_0x4a218c.coordinate_seed_blocked
			&& result.coordinate_owner_grid_0x4a218c.terrain_repaint.status != "pending_execution";
	if (!coordinate_terrain_done) {
		result.current_phase_id = "coordinate_boundary_terrain";
		result.status = "blocked";
		result.blocked_reason = result.coordinate_owner_grid_0x4a218c.coordinate_seed_blocked
				? "h3maped_workflow_coordinate_seed_blocked"
				: "h3maped_workflow_coordinate_boundary_terrain_not_executed";
		add_phase("coordinate_boundary_terrain", "0x4a218c_0x4a1f3b_0x4a19ed_0x4a3a03_0x4cca55_0x4a2777_0x4a325d_0x4a3710_0x49b53d_0x4a3f27", "blocked", result.blocked_reason);
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "pending", "blocked_before_coordinate_boundary_terrain");
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_mine_resource_materialization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("coordinate_boundary_terrain", "0x4a218c_0x4a1f3b_0x4a19ed_0x4a3a03_0x4cca55_0x4a2777_0x4a325d_0x4a3710_0x49b53d_0x4a3f27", "complete_source_order_prefix", "continues_with_workflow_owned_generator_private_state");

	initialize_generator_object_private_state_from_workflow_entry_0x49ecf2_0x49f95a(
			result.generator_object_private_state,
			config.width,
			config.height,
			config.level_count,
			result.setup_mode_0x49ecf2,
			result.template_selection_0x4ac552,
			result.coordinate_owner_grid_0x4a218c);
	if (!result.generator_object_private_state.generated_cell_buffer_owned) {
		result.current_phase_id = "generator_object_private_state";
		result.status = "blocked";
		result.blocked_reason = "h3maped_workflow_generator_object_private_state_not_built";
		add_phase("generator_object_private_state", "generator_plus_0x14_0x18_0x1c_0x20_0xec4_0xedc_0x10d4_0x10e4_0x1110", "blocked", result.blocked_reason);
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "pending", "blocked_before_generator_object_private_state");
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_mine_resource_materialization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("generator_object_private_state", "generator_plus_0x14_0x18_0x1c_0x20_0xec4_0xedc_0x10d4_0x10e4_0x1110", "complete_source_order_prefix", "workflow_owned_state_continues_into_route_free_cell_sweep");

	advance_generator_object_private_state_source_order_to_current_blocker(
			result.generator_object_private_state,
			config.size_class,
			config.water_mode,
			config.seed,
			config.human_count,
			config.player_count,
			config.setup_object_0x44_known,
			config.setup_object_0x44,
			result.template_selection_0x4ac552,
			result.coordinate_owner_grid_0x4a218c);

	const GeneratorObjectPrivateState &object_state = result.generator_object_private_state;
	const bool source_order_relation_pointer_loop_owned =
			object_state.source_order_relation_pointer_loop_0x4ac552_ported
			&& object_state.source_order_relation_pointer_loop_0x4ac552_input_known
			&& object_state.source_order_relation_pointer_loop_0x4ac552_applied
			&& object_state.source_order_relation_pointer_loop_0x4ac552_blocked_reason.empty();
	if (!source_order_relation_pointer_loop_owned) {
		result.current_phase_id = "source_order_object_materialization";
		result.status = "blocked";
		result.blocked_reason = object_state.source_order_relation_pointer_loop_0x4ac552_blocked_reason.empty()
				? "0x4ac552_relation_pointer_source_order_loop_not_owned_before_0x4a8c15"
				: object_state.source_order_relation_pointer_loop_0x4ac552_blocked_reason;
		add_phase("source_order_object_materialization", "0x4ac552_0x4a8d2c_0x4a8db2_0x4a93a2", "blocked", result.blocked_reason);
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "pending", "blocked_before_route_free_cell_sweep_by_source_order_object_materialization");
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("source_order_object_materialization", "0x4ac552_0x4a8d2c_0x4a8db2_0x4a93a2", "complete_source_order_prefix", "continues_into_route_free_cell_sweep");

	const bool route_free_cell_sweep_owned = object_state.route_container_free_cell_sweep_0x4a8260_ported
			&& object_state.route_container_free_cell_sweep_0x4a8260_input_known
			&& object_state.route_container_free_cell_sweep_0x4a8260_applied
			&& object_state.route_container_free_cell_sweep_0x4a8260_blocked_reason.empty();
	if (!route_free_cell_sweep_owned) {
		result.current_phase_id = "route_free_cell_sweep";
		result.status = "blocked";
		result.blocked_reason = object_state.route_container_free_cell_sweep_0x4a8260_blocked_reason.empty()
				? "route_container_free_cell_sweep_0x4a8260_not_owned_before_0x4a4c8e"
				: object_state.route_container_free_cell_sweep_0x4a8260_blocked_reason;
		add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "blocked", result.blocked_reason);
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", "blocked_before_route_free_cell_sweep");
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_mine_resource_materialization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("route_free_cell_sweep", "0x4a8c15_0x4a8260_0x4a4c8e", "complete_source_order_prefix", "continues_into_mine_resource_materialization");

	const bool materialization_bridge_blocked =
			(!object_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_applied
					&& object_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_ported)
			|| (!object_state.materialization_bridge_relation_loop_0x4a4913_applied
					&& object_state.materialization_bridge_relation_loop_0x4a4913_ported)
			|| (!object_state.materialization_bridge_water_edge_writer_0x4a4fc5_applied
					&& object_state.materialization_bridge_water_edge_writer_0x4a4fc5_ported)
			|| (!object_state.remaining_private_state_blockers.empty()
					&& object_state.remaining_private_state_blockers.front().rfind("0x4a8c15_", 0) == 0);
	if (materialization_bridge_blocked) {
		result.current_phase_id = "materialization_bridge";
		result.status = "blocked";
		result.blocked_reason = !object_state.remaining_private_state_blockers.empty()
				? object_state.remaining_private_state_blockers.front()
				: "0x4a8c15_materialization_bridge_incomplete";
		add_phase("materialization_bridge", "0x4a8c15_0x4a4913_0x4a5767_0x4a4fc5", "blocked", result.blocked_reason);
		if (object_state.relation_normalization_4a5767_full_grid_reset_applied) {
			std::ostringstream relation_reset_note;
			relation_reset_note << "visited=" << object_state.relation_normalization_4a5767_full_grid_reset_visited_count
					<< ",changed=" << object_state.relation_normalization_4a5767_full_grid_reset_changed_count
					<< ",skipped=" << object_state.relation_normalization_4a5767_full_grid_reset_skipped_count
					<< ",scan_applied=" << (object_state.relation_scan_consumers_4a5767_applied ? "true" : "false")
					<< ",high_owner_applied=" << (object_state.relation_high_owner_propagation_49a318_applied ? "true" : "false");
			add_phase("bridge_relation_normalization", "0x4a5767_0x4a5a23_0x49a318", "complete_source_order_prefix", relation_reset_note.str());
		} else {
			add_phase("bridge_relation_normalization", "0x4a5767_0x4a5a23_0x49a318", "pending", "blocked_before_0x4a5767");
		}
		if (object_state.materialization_bridge_water_edge_writer_0x4a4fc5_applied) {
			std::ostringstream water_edge_note;
			water_edge_note << "scan=" << object_state.materialization_bridge_water_edge_writer_scan_count_0x4a4fc5
					<< ",owner_byte2_sentinel_skips=" << object_state.materialization_bridge_water_edge_writer_owner_low_sentinel_skip_count_0x4a4fc5
					<< ",owner_byte3_sentinel_skips=" << object_state.materialization_bridge_water_edge_writer_owner_high_sentinel_skip_count_0x4a4fc5
					<< ",source_water=" << object_state.materialization_bridge_water_edge_writer_source_water_cell_count_0x4a4fc5
					<< ",relation_lookup_skips=" << object_state.materialization_bridge_water_edge_writer_relation_lookup_skip_count_0x4a4fc5
					<< ",mutation_sources=" << object_state.materialization_bridge_water_edge_writer_mutation_source_count_0x4a4fc5
					<< ",bit26_writes=" << object_state.materialization_bridge_water_edge_writer_bit26_set_count_0x4a4fc5
					<< ",byte2b_clears=" << object_state.materialization_bridge_water_edge_writer_byte2b_clear_count_0x4a4fc5
					<< ",visual_repaint_pending=" << object_state.materialization_bridge_water_edge_writer_visual_repaint_pending_count_0x4a4fc5
					<< ",bit25_probes=" << object_state.materialization_bridge_water_edge_writer_neighbor_bit25_probe_count_0x4a4fc5
					<< ",bit26_candidates=" << object_state.materialization_bridge_water_edge_writer_bit26_candidate_count_0x4a4fc5;
			add_phase("bridge_water_edge_writer", "0x4a4fc5", "complete_source_order_prefix", water_edge_note.str());
			add_phase("connection_tail", "0x4a79a3", "pending", "blocked_before_reward_guard_materialization");
		} else {
			add_phase("bridge_water_edge_writer", "0x4a4fc5", "blocked", result.blocked_reason);
			add_phase("connection_tail", "0x4a79a3", "pending", "blocked_before_0x4a4fc5");
		}
		const std::string downstream_bridge_blocker = object_state.materialization_bridge_water_edge_writer_0x4a4fc5_applied
				? "blocked_before_reward_guard_materialization"
				: "blocked_before_0x4a4fc5_0x4a79a3_materialization_bridge";
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "pending", downstream_bridge_blocker);
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", downstream_bridge_blocker);
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_0x4a79a3_connection_tail");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}

	const bool mine_resource_owned = object_state.mine_resource_materialization_0x4a9d6a_ported
			&& object_state.mine_resource_materialization_0x4a9d6a_input_known
			&& object_state.mine_resource_materialization_0x4a9d6a.invoked
			&& object_state.mine_resource_materialization_0x4a9d6a.applied
			&& object_state.mine_resource_materialization_0x4a9d6a.blocked_reason.empty();
	if (!mine_resource_owned) {
		result.current_phase_id = "mine_resource_materialization";
		result.status = "blocked";
		result.blocked_reason = object_state.mine_resource_materialization_0x4a9d6a.blocked_reason.empty()
				? "h3maped_workflow_mine_resource_materialization_0x4a9d6a_not_owned"
				: object_state.mine_resource_materialization_0x4a9d6a.blocked_reason;
		add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "blocked", result.blocked_reason);
		add_phase("relation_normalization", "0x4aadd2_0x4a5767_0x4a59e2", "pending", "blocked_before_mine_resource_materialization");
		add_phase("relation_scan_consumers", "0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_relation_normalization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("mine_resource_materialization", "0x4a9d6a_0x4a9911_0x4a9c7c_0x4a9641", "complete_source_order_prefix", "continues_into_0x4aadd2_0x4a5767_relation_normalization");

	if (!object_state.relation_normalization_4a5767_full_grid_reset_applied) {
		result.current_phase_id = "relation_normalization";
		result.status = "blocked";
		result.blocked_reason = "h3maped_workflow_relation_normalization_0x4a5767_full_grid_reset_not_applied_after_0x4a9d6a_0x4aadd2";
		add_phase("relation_normalization", "0x4aadd2_0x4a5767_0x4a59e2", "blocked", result.blocked_reason);
		add_phase("relation_scan_consumers", "0x4a5767_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "pending", "blocked_before_relation_normalization");
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	{
		std::ostringstream relation_reset_note;
		relation_reset_note << "visited=" << object_state.relation_normalization_4a5767_full_grid_reset_visited_count
				<< ",changed=" << object_state.relation_normalization_4a5767_full_grid_reset_changed_count
				<< ",skipped=" << object_state.relation_normalization_4a5767_full_grid_reset_skipped_count;
		add_phase("relation_normalization", "0x4aadd2_0x4a5767_0x4a59e2", "complete_source_order_prefix", relation_reset_note.str());
	}

	const bool relation_scan_owned = object_state.relation_owner_scan_bounds_0x4a1f3b_applied
			&& object_state.relation_scan_consumers_4a5767_applied
			&& object_state.relation_high_owner_propagation_49a318_applied;
	if (!relation_scan_owned) {
		result.current_phase_id = "relation_scan_consumers";
		result.status = "blocked";
		result.blocked_reason = !object_state.remaining_private_state_blockers.empty()
				? object_state.remaining_private_state_blockers.front()
				: "h3maped_workflow_relation_scan_0x4aadd2_0x4a5767_0x49a318_not_owned";
		add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x49a318_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "blocked", result.blocked_reason);
		add_phase("source_order_object_materialization", "0x4a8d2c_0x4a8db2_0x4a901a_0x4a93a2_0x4a54a7", "pending", "blocked_before_relation_scan_consumers");
		add_phase("reward_guard_materialization", "0x540b14_0x49c0a6_0x4ad947_0x4ad7f7_0x4a9f1c_0x4aa1db_0x4aa9b7_0x4aa3e9", "pending", "blocked_before_source_order_object_materialization");
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	add_phase("relation_scan_consumers", "0x4aadd2_0x4a5767_0x49a318_0x4a5a23_0x4a9e40_0x4af785_0x49ba89_0x4a54a7", "complete_source_order_prefix", "source_pair_preservation_continues_into_reward_guard_materialization");

	const bool reward_guard_source_stream_owned = object_state.reward_guard_source_stream_0x4aab7e_ported
			&& object_state.reward_guard_source_stream_0x4aab7e_input_known
			&& object_state.reward_guard_source_stream_owner_kind_0x0c_known
			&& object_state.reward_guard_source_stream_0x4aab7e.invoked
			&& object_state.reward_guard_source_stream_0x4aab7e.applied
			&& object_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty();
	const bool reward_guard_committed =
			object_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count > 0;
	const bool reward_guard_owned = reward_guard_source_stream_owned && reward_guard_committed;
	if (!reward_guard_owned) {
		result.current_phase_id = "reward_guard_materialization";
		result.status = "blocked";
		if (object_state.reward_guard_relation_priority_live_replay_blocked
				&& !object_state.reward_guard_relation_priority_live_replay_blocker.empty()) {
			result.blocked_reason = object_state.reward_guard_relation_priority_live_replay_blocker;
		} else if (reward_guard_source_stream_owned
				&& object_state.reward_guard_source_stream_0x4aab7e.materialization_attempt_count > 0
				&& object_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count == 0) {
			result.blocked_reason =
					reward_guard_zero_commit_blocker_detail_0x4aab7e(object_state.reward_guard_source_stream_0x4aab7e);
		} else if (!object_state.reward_guard_candidate_records_10f4_10f8_contents_known) {
			result.blocked_reason = "reward_guard_candidate_vector_0x10f4_0x10f8_live_contents_pending_before_0x4a9f1c";
		} else if (!object_state.reward_guard_selector_0x4a9f1c.blocked_reason.empty()) {
			result.blocked_reason = object_state.reward_guard_selector_0x4a9f1c.blocked_reason;
		} else if (!object_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()) {
			result.blocked_reason = object_state.reward_guard_source_stream_0x4aab7e.blocked_reason;
		} else {
			result.blocked_reason = "reward_guard_materialization_0x4aab7e_source_stream_not_owned";
		}
		add_phase("reward_guard_materialization", "0x4ac552_0x4aab7e_0x4aa354_0x4aa9b7_0x4aa3e9", "blocked", result.blocked_reason);
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x49eb8d_0x4ab52a", "pending", "blocked_before_reward_guard_materialization");
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	}
	std::ostringstream reward_guard_note;
	reward_guard_note << "source_stream_attempts=" << object_state.reward_guard_source_stream_0x4aab7e.materialization_attempt_count
			<< ",successful_0x4aa9b7_commits=" << object_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count;
	add_phase("reward_guard_materialization", "0x4ac552_0x4aab7e_0x4aa354_0x4aa9b7_0x4aa3e9", "complete_source_order_prefix", reward_guard_note.str());

	result.current_phase_id = "connection_road_river";
	result.status = "blocked";
	if (!object_state.decorative_flagged_cell_dispatch_0x49eb8d_ported
			|| !object_state.decorative_flagged_cell_dispatch_0x49eb8d.invoked) {
		result.blocked_reason = "0x49eb8d_decorative_flagged_cell_dispatch_not_invoked_after_reward_guard";
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x49eb8d_0x4ab52a", "blocked", result.blocked_reason);
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	} else if (!object_state.decorative_flagged_cell_dispatch_0x49eb8d.applied) {
		result.blocked_reason = object_state.decorative_flagged_cell_dispatch_0x49eb8d.blocked_reason.empty()
				? "0x49eb8d_decorative_flagged_cell_dispatch_blocked"
				: object_state.decorative_flagged_cell_dispatch_0x49eb8d.blocked_reason;
		add_phase("connection_road_river", "0x4a79a3_0x4a61bc_0x4a7605_0x4a5e03_0x49eb8d_0x4ab52a", "blocked", result.blocked_reason);
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	} else if (!object_state.connection_tail_replay_0x4a79a3_ported
			|| !object_state.connection_tail_replay_0x4a79a3.invoked) {
		result.blocked_reason = "0x4a79a3_connection_tail_replay_not_invoked_after_0x49eb8d";
		add_phase("connection_road_river", "0x4a79a3_0x49b3fb_0x4a61bc_0x4a696b_0x4a7605_0x4a7312_0x4a5e03", "blocked", result.blocked_reason);
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	} else if (!object_state.connection_tail_replay_0x4a79a3.applied) {
		result.blocked_reason = object_state.connection_tail_replay_0x4a79a3.blocked_reason.empty()
				? "0x4a79a3_connection_tail_replay_blocked"
				: object_state.connection_tail_replay_0x4a79a3.blocked_reason;
		add_phase("connection_road_river", "0x4a79a3_0x49b3fb_0x4a61bc_0x4a696b_0x4a7605_0x4a7312_0x4a5e03", "blocked", result.blocked_reason);
		add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
		return result;
	} else {
		const ConnectionTailReplayResult4a79a3 &connection_tail =
				object_state.connection_tail_replay_0x4a79a3;
		std::ostringstream connection_note;
		connection_note << "append_pairs=" << connection_tail.internal_growth_candidate_pair_count
				<< ",positive_appends=" << connection_tail.internal_growth_positive_append_count
				<< ",payload_records=" << connection_tail.payload_loop_non_null_record_count
				<< ",4a696b_samples=" << connection_tail.controlled_0x4a696b_sampled_call_count
				<< ",4a696b_direct_mutations=" << connection_tail.controlled_0x4a696b_direct_mutation_hits
				<< ",direct_4a7312_commits=" << connection_tail.after_selected_direct_0x4a7312_commit_count;
		add_phase("connection_road_river", "0x4a79a3_0x49b3fb_0x4a61bc_0x4a696b_0x4a7605_0x4a7312_0x4a5e03", "complete_source_order_prefix", connection_note.str());
	}
	result.current_phase_id = "road_river_object_adjacency";
	result.blocked_reason = "road_river_object_adjacency_0x4ab52a_replay_unported_after_source_backed_0x4a79a3_connection_tail";
	add_phase("road_river_object_adjacency", "0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243", "blocked", result.blocked_reason);
	add_phase("final_writeout", "0x4ad1e3_0x49b2b6_0x4ad309_0x4ad3eb_0x4ad3de_0x4ae09a", "pending", "blocked_before_final_payload");
	return result;
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
