#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *ADAPTED_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *REWARD_PROXY_CATALOG_PATH = "res://content/homm3_re_reward_object_proxy_catalog.json";
constexpr const char *H3_OBJECTS_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3bitmap/raw/objects.txt";
constexpr const char *H3_OBJECT_NAMES_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3bitmap/raw/objnames.txt";
constexpr int32_t H3_OBJECT_METADATA_ENTRY_COUNT = 232;
constexpr int32_t H3_OBJECT_METADATA_ENTRY_SIZE = 0x10;
constexpr int32_t H3_OBJECT_METADATA_POINTER_ADDRESS = 0x57c648;
constexpr int32_t H3_OBJECT_METADATA_RUNTIME_ADDRESS = 0x598300;
constexpr int32_t H3_MINE_TYPE_ID = 53;
constexpr int32_t H3_RESOURCE_TYPE_ID = 79;
constexpr int32_t H3_RANDOM_TOWN_TYPE_ID = 77;
constexpr int32_t H3_TOWN_TYPE_ID = 98;

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

struct RoadArtClassification {
	int32_t art_class = 0;
	int32_t flip_a = 0;
	int32_t flip_b = 0;
};

RoadArtClassification h3maped_classify_road_art_458893(const uint8_t flags[8]) {
	RoadArtClassification result;
	const uint8_t f0 = flags[0];
	const uint8_t f2 = flags[2];
	const uint8_t f4 = flags[4];
	const uint8_t f6 = flags[6];

	if (f0 != 0) {
		if (f2 != 0 && f4 != 0 && f6 != 0) {
			result.art_class = 8;
			return result;
		}
		if (f4 != 0) {
			if (f2 != 0) {
				result.art_class = 6;
				return result;
			}
			if (f6 != 0) {
				result.art_class = 6;
				result.flip_a = 1;
				return result;
			}
			result.art_class = 2;
			return result;
		}
	}

	if (f2 != 0 && f6 != 0) {
		if (f4 != 0) {
			result.art_class = 7;
			return result;
		}
		if (f0 != 0) {
			result.art_class = 7;
			result.flip_b = 1;
			return result;
		}
		result.art_class = 3;
		return result;
	}

	constexpr int32_t shape_offsets[4][8] = {
		{ 0, 1, 2, 3, 4, 5, 6, 7 },
		{ 4, 3, 2, 1, 0, 7, 6, 5 },
		{ 0, 7, 6, 5, 4, 3, 2, 1 },
		{ 4, 5, 6, 7, 0, 1, 2, 3 },
	};
	constexpr int32_t selector_flip_a[4] = { 0, 0, 1, 1 };
	constexpr int32_t selector_flip_b[4] = { 0, 1, 0, 1 };
	for (int32_t selector_index = 0; selector_index < 4; ++selector_index) {
		const int32_t record_index = selector_flip_b[selector_index] + selector_flip_a[selector_index] * 2;
		if (flags[shape_offsets[record_index][2]] == 0 || flags[shape_offsets[record_index][4]] == 0) {
			continue;
		}
		if (flags[shape_offsets[record_index][1]] != 0 || flags[shape_offsets[record_index][5]] != 0) {
			result.art_class = 5;
		} else {
			result.art_class = 4;
		}
		result.flip_a = selector_flip_a[selector_index];
		result.flip_b = selector_flip_b[selector_index];
		return result;
	}

	if (f6 == 0 && f2 == 0) {
		result.art_class = 0;
		result.flip_b = f4 == 0 ? 1 : 0;
		return result;
	}
	result.art_class = 1;
	result.flip_a = f6 != 0 ? 1 : 0;
	return result;
}

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

struct PolygonPoint {
	int32_t x = 0;
	int32_t y = 0;
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
	std::map<int64_t, bool> unique_cells;
	int32_t out_of_bounds_write_count = 0;
};

struct SpanRecord {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct SpanFillCellWrite {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t zone_id = 0;
	bool reserved = false;
};

struct SpanFillResult {
	std::vector<SpanFillCellWrite> trace;
	std::map<int64_t, bool> unique_cells;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
};

struct TerrainCellStats {
	int32_t cell_count = 0;
	int32_t repaint_member_count = 0;
	int32_t min_x = 0x7fffffff;
	int32_t min_y = 0x7fffffff;
	int32_t max_x = -1;
	int32_t max_y = -1;

	void add(int32_t x, int32_t y, bool repaint_member) {
		cell_count += 1;
		if (repaint_member) {
			repaint_member_count += 1;
		}
		min_x = std::min(min_x, x);
		min_y = std::min(min_y, y);
		max_x = std::max(max_x, x);
		max_y = std::max(max_y, y);
	}
};

struct TerrainClassResult {
	int32_t class_code = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
	const char *reason = "no classed relation";
};

struct TerrainVisualResult {
	int32_t art_index = 0;
	int32_t flip_h = 0;
	int32_t flip_v = 0;
	int32_t class_code = 0;
	int32_t requested_flag_a = 0;
	int32_t requested_flag_b = 0;
	bool fallback = false;
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
	String branch;
	bool input_inside = false;
};

struct H3ObjectRow {
	int32_t source_line = 0;
	String def_name;
	String passability_mask;
	String action_mask;
	String terrain_mask_primary;
	String terrain_mask_secondary;
	int32_t type_id = -1;
	int32_t subtype_id = -1;
	int32_t group_id = -1;
	int32_t final_flag = 0;
};

struct H3MapedRewardCandidate {
	const char *constructor_address;
	const char *vtable_address;
	int32_t type_id = -1;
	int32_t subtype_id = 0;
	int32_t value = 0;
	int32_t weight = 0;
	int32_t extra_0x14 = 0;
	const char *source_note;
};

struct H3MaskPoint {
	int32_t dx = 0;
	int32_t dy = 0;
};

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD = 0x00ff0000U;

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

String object_type_name_from_names_file(int32_t type_id, int32_t *line_count = nullptr) {
	std::ifstream input(H3_OBJECT_NAMES_PATH);
	if (!input.is_open()) {
		if (line_count != nullptr) {
			*line_count = 0;
		}
		return String();
	}
	std::string line;
	int32_t index = 0;
	String result;
	while (std::getline(input, line)) {
		if (index == type_id) {
			result = String(line.c_str()).strip_edges();
		}
		index += 1;
	}
	if (line_count != nullptr) {
		*line_count = index;
	}
	return result;
}

Array h3_object_rows_to_array(const std::vector<H3ObjectRow> &rows) {
	Array result;
	for (const H3ObjectRow &row : rows) {
		Dictionary record;
		record["source_line"] = row.source_line;
		record["def_name"] = row.def_name;
		record["passability_mask"] = row.passability_mask;
		record["action_mask"] = row.action_mask;
		record["terrain_mask_primary"] = row.terrain_mask_primary;
		record["terrain_mask_secondary"] = row.terrain_mask_secondary;
		record["type_id"] = row.type_id;
		record["subtype_id"] = row.subtype_id;
		record["group_id"] = row.group_id;
		record["final_flag"] = row.final_flag;
		result.append(record);
	}
	return result;
}

std::vector<H3MaskPoint> h3_text_mask_points(const String &mask_text, bool action_mask) {
	std::vector<H3MaskPoint> points;
	if (mask_text.length() < 48) {
		return points;
	}
	for (int32_t row = 0; row < 6; ++row) {
		for (int32_t text_col = 0; text_col < 8; ++text_col) {
			const bool bit_set = mask_text[row * 8 + text_col] == '1';
			const bool include = action_mask ? bit_set : !bit_set;
			if (!include) {
				continue;
			}
			points.push_back(H3MaskPoint { -text_col, -(5 - row) });
		}
	}
	return points;
}

Array h3_mask_points_to_array(const std::vector<H3MaskPoint> &points) {
	Array result;
	for (const H3MaskPoint &point : points) {
		Dictionary record;
		record["dx"] = point.dx;
		record["dy"] = point.dy;
		result.append(record);
	}
	return result;
}

std::vector<H3ObjectRow> h3_object_rows_by_type(int32_t wanted_type_id) {
	std::vector<H3ObjectRow> rows;
	std::ifstream input(H3_OBJECTS_PATH);
	if (!input.is_open()) {
		return rows;
	}
	std::string line;
	int32_t source_line = 0;
	if (std::getline(input, line)) {
		source_line = 1;
	}
	while (std::getline(input, line)) {
		source_line += 1;
		if (line.empty()) {
			continue;
		}
		std::stringstream row_stream(line);
		std::string def_name;
		std::string passability_mask;
		std::string action_mask;
		std::string terrain_mask_primary;
		std::string terrain_mask_secondary;
		int32_t type_id = -1;
		int32_t subtype_id = -1;
		int32_t group_id = -1;
		int32_t final_flag = 0;
		if (!(row_stream >> def_name >> passability_mask >> action_mask >> terrain_mask_primary >> terrain_mask_secondary >> type_id >> subtype_id >> group_id >> final_flag)) {
			continue;
		}
		if (type_id != wanted_type_id) {
			continue;
		}
		H3ObjectRow row;
		row.source_line = source_line;
		row.def_name = String(def_name.c_str());
		row.passability_mask = String(passability_mask.c_str());
		row.action_mask = String(action_mask.c_str());
		row.terrain_mask_primary = String(terrain_mask_primary.c_str());
		row.terrain_mask_secondary = String(terrain_mask_secondary.c_str());
		row.type_id = type_id;
		row.subtype_id = subtype_id;
		row.group_id = group_id;
		row.final_flag = final_flag;
		rows.push_back(row);
	}
	return rows;
}

Dictionary h3maped_object_metadata_table_report() {
	Dictionary report;
	report["status"] = "0x57c648_runtime_object_metadata_table_bound_to_text_sources_inspection_only";
	report["source"] = "h3maped loads object metadata from extracted H3 object text tables at runtime; 0x49aa93 indexes the runtime metadata table by object type";
	report["objects_source_path"] = H3_OBJECTS_PATH;
	report["object_names_source_path"] = H3_OBJECT_NAMES_PATH;
	report["metadata_pointer_global_address"] = "0x57c648";
	report["metadata_runtime_table_address"] = "0x598300";
	report["metadata_entry_size_bytes"] = H3_OBJECT_METADATA_ENTRY_SIZE;
	report["metadata_entry_count"] = H3_OBJECT_METADATA_ENTRY_COUNT;
	report["metadata_index_formula"] = "runtime_table + object_type_id * 0x10";
	Array metadata_fields;
	metadata_fields.append("entry+0x01 wide/secondary placement flag");
	metadata_fields.append("entry+0x02 collision-secondary flag");
	metadata_fields.append("object template wrapper +0x14 footprint vector");
	metadata_fields.append("object template +0x1c type id");
	metadata_fields.append("object template +0x24 land/water class");
	metadata_fields.append("object template +0x29 anchored footprint flag");
	metadata_fields.append("object template +0x2c/+0x30 anchor offsets");
	metadata_fields.append("object template +0x34/+0x38 dimensions");
	report["metadata_fields_used_by_0x49aa93"] = metadata_fields;

	int32_t object_type_name_count = 0;
	const String random_town_name = object_type_name_from_names_file(H3_RANDOM_TOWN_TYPE_ID, &object_type_name_count);
	const String town_name = object_type_name_from_names_file(H3_TOWN_TYPE_ID);
	report["object_type_name_count"] = object_type_name_count;
	report["random_town_type_id"] = H3_RANDOM_TOWN_TYPE_ID;
	report["random_town_type_name"] = random_town_name;
	report["town_type_id"] = H3_TOWN_TYPE_ID;
	report["town_type_name"] = town_name;

	std::ifstream input(H3_OBJECTS_PATH);
	if (!input.is_open()) {
		report["objects_table_status"] = "missing_or_unreadable";
		report["objects_table_declared_row_count"] = 0;
		report["objects_table_loaded_row_count"] = 0;
		report["town_template_row_count"] = 0;
		report["random_town_template_row_count"] = 0;
		report["town_or_random_template_row_count"] = 0;
		return report;
	}

	std::string line;
	int32_t source_line = 0;
	int32_t declared_row_count = 0;
	int32_t loaded_row_count = 0;
	std::vector<H3ObjectRow> town_rows;
	std::vector<H3ObjectRow> random_town_rows;
	if (std::getline(input, line)) {
		source_line = 1;
		std::stringstream header(line);
		header >> declared_row_count;
	}
	while (std::getline(input, line)) {
		source_line += 1;
		if (line.empty()) {
			continue;
		}
		std::stringstream row_stream(line);
		std::string def_name;
		std::string passability_mask;
		std::string action_mask;
		std::string terrain_mask_primary;
		std::string terrain_mask_secondary;
		int32_t type_id = -1;
		int32_t subtype_id = -1;
		int32_t group_id = -1;
		int32_t final_flag = 0;
		if (!(row_stream >> def_name >> passability_mask >> action_mask >> terrain_mask_primary >> terrain_mask_secondary >> type_id >> subtype_id >> group_id >> final_flag)) {
			continue;
		}
		loaded_row_count += 1;
		if (type_id != H3_TOWN_TYPE_ID && type_id != H3_RANDOM_TOWN_TYPE_ID) {
			continue;
		}
		H3ObjectRow row;
		row.source_line = source_line;
		row.def_name = String(def_name.c_str());
		row.passability_mask = String(passability_mask.c_str());
		row.action_mask = String(action_mask.c_str());
		row.terrain_mask_primary = String(terrain_mask_primary.c_str());
		row.terrain_mask_secondary = String(terrain_mask_secondary.c_str());
		row.type_id = type_id;
		row.subtype_id = subtype_id;
		row.group_id = group_id;
		row.final_flag = final_flag;
		if (type_id == H3_TOWN_TYPE_ID) {
			town_rows.push_back(row);
		} else {
			random_town_rows.push_back(row);
		}
	}
	report["objects_table_status"] = "loaded";
	report["objects_table_declared_row_count"] = declared_row_count;
	report["objects_table_loaded_row_count"] = loaded_row_count;
	report["town_template_row_count"] = int32_t(town_rows.size());
	report["random_town_template_row_count"] = int32_t(random_town_rows.size());
	report["town_or_random_template_row_count"] = int32_t(town_rows.size() + random_town_rows.size());
	report["town_template_rows"] = h3_object_rows_to_array(town_rows);
	report["random_town_template_rows"] = h3_object_rows_to_array(random_town_rows);
	if (!town_rows.empty()) {
		const std::vector<H3MaskPoint> town_body_points = h3_text_mask_points(town_rows[0].passability_mask, false);
		const std::vector<H3MaskPoint> town_action_points = h3_text_mask_points(town_rows[0].action_mask, true);
		report["town_mask_model_status"] = "objects_txt_text_mask_offsets_ported_for_0x49a6f9_inspection";
		report["town_mask_text_order"] = "objects.txt expands the six H3 object mask bytes as MSB-to-LSB text rows; anchor-relative offsets are x-text_col and y-(5-row), matching the recovered H3M parser semantics";
		report["town_passability_body_cell_count"] = int32_t(town_body_points.size());
		report["town_action_cell_count"] = int32_t(town_action_points.size());
		report["town_passability_body_offsets"] = h3_mask_points_to_array(town_body_points);
		report["town_action_offsets"] = h3_mask_points_to_array(town_action_points);
	}
	report["template_binding_status"] = "town_and_random_town_rows_loaded_for_0x49aa93_gate_inputs_object_wrapper_execution_pending";
	return report;
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

int32_t terrain_code_for_h3maped_id(int32_t terrain_id) {
	return terrain_id >= 0 ? terrain_id : -1;
}

uint32_t terrain_visual_hash_u32(const String &text) {
	uint32_t hash = 2166136261U;
	for (int64_t index = 0; index < text.length(); ++index) {
		hash ^= uint32_t(text.unicode_at(index));
		hash *= 16777619U;
	}
	return hash;
}

int32_t positive_visual_hash(const String &text) {
	int32_t signed_hash = int32_t(terrain_visual_hash_u32(text));
	if (signed_hash == INT32_MIN) {
		return 0;
	}
	return signed_hash < 0 ? -signed_hash : signed_hash;
}

int32_t trait_flag4(int32_t owner_id) {
	const std::array<int32_t, 10> flags = { 1, 0, 1, 1, 1, 1, 1, 1, 0, 0 };
	if (owner_id >= 0 && owner_id < int32_t(flags.size())) {
		return flags[size_t(owner_id)];
	}
	return 1;
}

int32_t relation_between_owner_ids(int32_t center_id, int32_t neighbor_id) {
	if (center_id < 0 || neighbor_id < 0 || center_id == neighbor_id) {
		return 0;
	}
	if (center_id == 1) {
		return 0;
	}
	if (trait_flag4(center_id) == 0 || trait_flag4(neighbor_id) == 0) {
		return 2;
	}
	return center_id != 0 ? 1 : 0;
}

int32_t clamped_terrain_code_at(const PackedInt32Array &codes, int32_t width, int32_t height, int32_t x, int32_t y) {
	const int32_t clamped_x = std::max(0, std::min(width - 1, x));
	const int32_t clamped_y = std::max(0, std::min(height - 1, y));
	const int32_t index = clamped_y * width + clamped_x;
	if (index < 0 || index >= codes.size()) {
		return -1;
	}
	return codes[index];
}

std::array<int32_t, 8> relation_ring_for_terrain_cell(const PackedInt32Array &codes, int32_t width, int32_t height, int32_t x, int32_t y) {
	const int32_t center = clamped_terrain_code_at(codes, width, height, x, y);
	const std::array<std::pair<int32_t, int32_t>, 8> offsets = {
		std::make_pair(0, -1),
		std::make_pair(1, -1),
		std::make_pair(1, 0),
		std::make_pair(1, 1),
		std::make_pair(0, 1),
		std::make_pair(-1, 1),
		std::make_pair(-1, 0),
		std::make_pair(-1, -1)
	};
	std::array<int32_t, 8> relations = {};
	for (size_t index = 0; index < offsets.size(); ++index) {
		relations[index] = relation_between_owner_ids(center, clamped_terrain_code_at(codes, width, height, x + offsets[index].first, y + offsets[index].second));
	}
	return relations;
}

int32_t relation_at_oriented(const std::array<int32_t, 8> &relations, int32_t flag_a, int32_t flag_b, int32_t slot) {
	const std::array<std::array<int32_t, 8>, 4> perms = {
		std::array<int32_t, 8> { 0, 1, 2, 3, 4, 5, 6, 7 },
		std::array<int32_t, 8> { 4, 3, 2, 1, 0, 7, 6, 5 },
		std::array<int32_t, 8> { 0, 7, 6, 5, 4, 3, 2, 1 },
		std::array<int32_t, 8> { 4, 5, 6, 7, 0, 1, 2, 3 },
	};
	const int32_t perm_index = std::max(0, std::min(3, flag_b + flag_a * 2));
	return relations[size_t(perms[size_t(perm_index)][size_t(slot)])];
}

TerrainClassResult terrain_class_result(int32_t class_code, int32_t flag_a, int32_t flag_b, const char *reason) {
	TerrainClassResult result;
	result.class_code = class_code;
	result.flag_a = flag_a;
	result.flag_b = flag_b;
	result.reason = reason;
	return result;
}

TerrainClassResult classify_terrain_relations(const std::array<int32_t, 8> &relations) {
	const std::array<std::pair<int32_t, int32_t>, 4> flags = {
		std::make_pair(0, 0),
		std::make_pair(0, 1),
		std::make_pair(1, 0),
		std::make_pair(1, 1)
	};
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 2) == 1 && relation_at_oriented(relations, a, b, 4) == 1) {
			if (relation_at_oriented(relations, a, b, 1) == 2 && relation_at_oriented(relations, a, b, 5) == 2) {
				return terrain_class_result(28, a, b, "E=1,S=1,NE=2,SW=2");
			}
			if (relation_at_oriented(relations, a, b, 3) == 2) {
				return terrain_class_result(27, a, b, "E=1,S=1,SE=2");
			}
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 0) == 1 && relation_at_oriented(relations, a, b, 6) == 1 && relation_at_oriented(relations, a, b, 3) != 0) {
			return terrain_class_result(relation_at_oriented(relations, a, b, 3) == 1 ? 23 : 25, a, b, "N=1,W=1,SE!=0");
		}
		if (relation_at_oriented(relations, a, b, 0) == 2 && relation_at_oriented(relations, a, b, 6) == 2 && relation_at_oriented(relations, a, b, 3) != 0) {
			return terrain_class_result(relation_at_oriented(relations, a, b, 3) == 1 ? 26 : 24, a, b, "N=2,W=2,SE!=0");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 2) == 2 && relation_at_oriented(relations, a, b, 4) == 1 && relation_at_oriented(relations, a, b, 5) == 2) {
			return terrain_class_result(8, 1 - a, 1 - b, "E=2,S=1,SW=2");
		}
		if (relation_at_oriented(relations, a, b, 2) == 1 && relation_at_oriented(relations, a, b, 4) == 2 && relation_at_oriented(relations, a, b, 1) == 2) {
			return terrain_class_result(8, 1 - a, 1 - b, "E=1,S=2,NE=2");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 2) == 1 && relation_at_oriented(relations, a, b, 4) == 1) {
			if (relation_at_oriented(relations, a, b, 5) == 2) {
				return terrain_class_result(17, a, b, "E=1,S=1,SW=2");
			}
			if (relation_at_oriented(relations, a, b, 1) == 2) {
				return terrain_class_result(18, a, b, "E=1,S=1,NE=2");
			}
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 0) == 1 && relation_at_oriented(relations, a, b, 6) == 1) {
			return terrain_class_result(2, a, b, "N=1,W=1");
		}
		if (relation_at_oriented(relations, a, b, 0) == 2 && relation_at_oriented(relations, a, b, 6) == 2) {
			return terrain_class_result(8, a, b, "N=2,W=2");
		}
		if (relation_at_oriented(relations, a, b, 2) == 1 && relation_at_oriented(relations, a, b, 5) == 2) {
			return terrain_class_result(17, a, b, "E=1,SW=2");
		}
		if (relation_at_oriented(relations, a, b, 4) == 1 && relation_at_oriented(relations, a, b, 1) == 2) {
			return terrain_class_result(18, a, b, "S=1,NE=2");
		}
		if (relation_at_oriented(relations, a, b, 2) == 2 && relation_at_oriented(relations, a, b, 5) == 1) {
			return terrain_class_result(21, a, b, "E=2,SW=1");
		}
		if (relation_at_oriented(relations, a, b, 4) == 2 && relation_at_oriented(relations, a, b, 1) == 1) {
			return terrain_class_result(22, a, b, "S=2,NE=1");
		}
		if (relation_at_oriented(relations, a, b, 6) == 1 && relation_at_oriented(relations, a, b, 1) == 1) {
			return terrain_class_result(2, a, b, "W=1,NE=1");
		}
		if (relation_at_oriented(relations, a, b, 0) == 1 && relation_at_oriented(relations, a, b, 5) == 1) {
			return terrain_class_result(2, a, b, "N=1,SW=1");
		}
		if (relation_at_oriented(relations, a, b, 6) == 2 && relation_at_oriented(relations, a, b, 1) == 2) {
			return terrain_class_result(8, a, b, "W=2,NE=2");
		}
		if (relation_at_oriented(relations, a, b, 0) == 2 && relation_at_oriented(relations, a, b, 5) == 2) {
			return terrain_class_result(8, a, b, "N=2,SW=2");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 2) == 1 && relation_at_oriented(relations, a, b, 3) == 2) {
			return terrain_class_result(19, a, b, "E=1,SE=2");
		}
		if (relation_at_oriented(relations, a, b, 4) == 1 && relation_at_oriented(relations, a, b, 3) == 2) {
			return terrain_class_result(20, a, b, "S=1,SE=2");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 0) == 1) {
			return terrain_class_result(4, a, b, "N=1");
		}
		if (relation_at_oriented(relations, a, b, 0) == 2) {
			return terrain_class_result(10, a, b, "N=2");
		}
		if (relation_at_oriented(relations, a, b, 6) == 1) {
			return terrain_class_result(3, a, b, "W=1");
		}
		if (relation_at_oriented(relations, a, b, 6) == 2) {
			return terrain_class_result(9, a, b, "W=2");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 7) == 1 && relation_at_oriented(relations, a, b, 3) == 1) {
			return terrain_class_result(14, a, b, "NW=1,SE=1");
		}
		if (relation_at_oriented(relations, a, b, 7) == 1 && relation_at_oriented(relations, a, b, 3) == 2) {
			return terrain_class_result(15, a, b, "NW=1,SE=2");
		}
		if (relation_at_oriented(relations, a, b, 7) == 2 && relation_at_oriented(relations, a, b, 3) == 2) {
			return terrain_class_result(16, a, b, "NW=2,SE=2");
		}
	}
	for (const auto &flag : flags) {
		const int32_t a = flag.first;
		const int32_t b = flag.second;
		if (relation_at_oriented(relations, a, b, 3) == 1) {
			return terrain_class_result(5, a, b, "SE=1");
		}
		if (relation_at_oriented(relations, a, b, 3) == 2) {
			return terrain_class_result(11, a, b, "SE=2");
		}
	}
	return terrain_class_result(0, 0, 0, "no classed relation");
}

bool same_owner_probe(const PackedInt32Array &codes, int32_t width, int32_t height, int32_t x, int32_t y, int32_t flag_a, int32_t flag_b, bool two_step) {
	const int32_t center = clamped_terrain_code_at(codes, width, height, x, y);
	std::vector<std::pair<int32_t, int32_t>> offsets;
	const String key = String::num_int64(flag_a) + String(",") + String::num_int64(flag_b);
	if (two_step) {
		if (key == "0,0") offsets.push_back({ 2, 2 });
		else if (key == "1,0") offsets.push_back({ -2, 2 });
		else if (key == "0,1") offsets.push_back({ 2, -2 });
		else offsets.push_back({ -2, -2 });
	} else {
		if (key == "0,0") offsets = { { -1, 1 }, { 1, -1 } };
		else if (key == "1,0") offsets = { { 1, 1 }, { -1, -1 } };
		else if (key == "0,1") offsets = { { -1, -1 }, { 1, 1 } };
		else offsets = { { 1, -1 }, { -1, 1 } };
	}
	for (const auto &offset : offsets) {
		const int32_t nx = x + offset.first;
		const int32_t ny = y + offset.second;
		if (nx >= 0 && ny >= 0 && nx < width && ny < height && clamped_terrain_code_at(codes, width, height, nx, ny) == center) {
			return true;
		}
	}
	return false;
}

TerrainClassResult apply_terrain_final_corrections(const TerrainClassResult &input, const PackedInt32Array &codes, int32_t width, int32_t height, int32_t x, int32_t y) {
	if ((input.class_code == 2 || input.class_code == 8) && same_owner_probe(codes, width, height, x, y, input.flag_a, input.flag_b, false)) {
		return terrain_class_result(input.class_code == 2 ? 6 : 12, input.flag_a, input.flag_b, "diagonal same-owner correction");
	}
	if ((input.class_code == 5 || input.class_code == 11) && same_owner_probe(codes, width, height, x, y, input.flag_a, input.flag_b, true)) {
		return terrain_class_result(input.class_code == 5 ? 7 : 13, input.flag_a, input.flag_b, "two-step same-owner correction");
	}
	return input;
}

std::vector<int32_t> normal79_rows_for_class(int32_t class_code) {
	switch (class_code) {
		case 2: return { 0, 1, 2, 3 };
		case 3: return { 4, 5, 6, 7 };
		case 4: return { 8, 9, 10, 11 };
		case 5: return { 12, 13, 14, 15 };
		case 6: return { 16, 17 };
		case 7: return { 18, 19 };
		case 8: return { 20, 21, 22, 23 };
		case 9: return { 24, 25, 26, 27 };
		case 10: return { 28, 29, 30, 31 };
		case 11: return { 32, 33, 34, 35 };
		case 12: return { 36, 37 };
		case 13: return { 38, 39 };
		case 14: return { 40 };
		case 15: return { 41 };
		case 16: return { 42 };
		case 17: return { 43 };
		case 18: return { 44 };
		case 19: return { 45 };
		case 20: return { 46 };
		case 21: return { 47 };
		case 22: return { 48 };
		case 23: return { 73 };
		case 24: return { 74 };
		case 25: return { 75 };
		case 26: return { 76 };
		case 27: return { 78 };
		case 28: return { 77 };
		default: return {};
	}
}

std::vector<int32_t> dirt_rows_for_class(int32_t class_code) {
	switch (class_code) {
		case 8: return { 0, 1, 2, 3 };
		case 9: return { 4, 5, 6, 7 };
		case 10: return { 8, 9, 10, 11 };
		case 11: return { 12, 13, 14, 15 };
		case 12: return { 16, 17 };
		case 13: return { 18, 19 };
		case 16: return { 20 };
		case 24: return { 45 };
		default: return {};
	}
}

std::vector<int32_t> water_rows_for_class(int32_t class_code) {
	switch (class_code) {
		case 8: return { 0, 1, 2, 3 };
		case 9: return { 4, 5, 6, 7 };
		case 10: return { 8, 9, 10, 11 };
		case 11: return { 12, 13, 14, 15 };
		case 12: return { 16, 17 };
		case 13: return { 18, 19 };
		case 16: return { 20 };
		default: return {};
	}
}

std::vector<int32_t> full_rows_for_owner(int32_t owner_id, int32_t x, int32_t y) {
	int32_t frequency = 0;
	std::vector<int32_t> ordinary;
	std::vector<int32_t> special;
	if (owner_id == 0) {
		ordinary = { 21, 22, 23, 24, 25, 26, 27, 28 };
		special = { 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44 };
		frequency = 50;
	} else if (owner_id == 1) {
		ordinary = { 0, 1, 2, 3, 4, 5, 6, 7 };
		special = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 };
		frequency = 70;
	} else if (owner_id == 8) {
		ordinary = { 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32 };
	} else if (owner_id == 9) {
		return { 0, 1, 2, 3, 4, 5, 6, 7 };
	} else {
		ordinary = { 49, 50, 51, 52, 53, 54, 55, 56 };
		special = { 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72 };
		const std::array<int32_t, 10> freq = { 50, 70, 50, 80, 80, 80, 60, 80, 0, 0 };
		frequency = owner_id >= 0 && owner_id < int32_t(freq.size()) ? freq[size_t(owner_id)] : 0;
	}
	if (!special.empty() && positive_visual_hash(String("special:") + String::num_int64(owner_id) + String(":") + String::num_int64(x) + String(":") + String::num_int64(y)) % 100 < frequency) {
		return special;
	}
	return ordinary.empty() ? special : ordinary;
}

std::vector<int32_t> rows_for_owner_class(int32_t owner_id, int32_t class_code) {
	if (class_code == 0) {
		return {};
	}
	if (owner_id == 0) {
		return dirt_rows_for_class(class_code);
	}
	if (owner_id == 1) {
		return {};
	}
	if (owner_id == 8) {
		return water_rows_for_class(class_code);
	}
	if (owner_id == 9) {
		return {};
	}
	return normal79_rows_for_class(class_code);
}

int32_t choose_visual_frame(const std::vector<int32_t> &rows, int32_t x, int32_t y, const String &salt) {
	if (rows.empty()) {
		return 0;
	}
	const int32_t index = positive_visual_hash(salt + String(":") + String::num_int64(x) + String(":") + String::num_int64(y)) % int32_t(rows.size());
	return rows[size_t(index)];
}

TerrainVisualResult terrain_visual_for_cell(const PackedInt32Array &codes, int32_t width, int32_t height, int32_t x, int32_t y) {
	TerrainVisualResult result;
	const int32_t owner_id = clamped_terrain_code_at(codes, width, height, x, y);
	TerrainClassResult class_info = classify_terrain_relations(relation_ring_for_terrain_cell(codes, width, height, x, y));
	class_info = apply_terrain_final_corrections(class_info, codes, width, height, x, y);
	result.class_code = class_info.class_code;
	result.requested_flag_a = class_info.flag_a;
	result.requested_flag_b = class_info.flag_b;
	std::vector<int32_t> rows = class_info.class_code == 0 ? full_rows_for_owner(owner_id, x, y) : rows_for_owner_class(owner_id, class_info.class_code);
	if (rows.empty()) {
		rows = full_rows_for_owner(owner_id, x, y);
		result.fallback = true;
		result.flip_h = 0;
		result.flip_v = 0;
		result.art_index = choose_visual_frame(rows, x, y, String::num_int64(owner_id) + String(":missing:") + String::num_int64(class_info.class_code));
		return result;
	}
	const String salt = class_info.class_code == 0
			? String::num_int64(owner_id) + String(":full")
			: String::num_int64(owner_id) + String(":class:") + String::num_int64(class_info.class_code);
	result.art_index = choose_visual_frame(rows, x, y, salt);
	result.flip_h = class_info.class_code == 0 || owner_id == 9 ? 0 : class_info.flag_a;
	result.flip_v = class_info.class_code == 0 || owner_id == 9 ? 0 : class_info.flag_b;
	return result;
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
			runtime["terrain_source"] = "terrain table preview after 0x49b3c1 before authoritative 0x49b53d terrain selection";
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
	report["next_materialization_status"] = "pending_clean_port_0x4a3a03_boundary_after_coordinate_replay";
	return report;
}

Dictionary runtime_terrain_selection_49b53d_report(Array &runtime_zones, uint32_t rng_state_after_coordinate_replay) {
	Dictionary report;
	report["status"] = "0x49b53d_runtime_terrain_selector_ported_inspection_only";
	report["source"] = "h3maped 0x49b53d; match-to-town uses table 0x540908, otherwise numeric RNG 0x4e7276 chooses from source +0x85..+0x8c allowed terrain flags with subterranean gated to level 1";
	report["function_address"] = "0x49b53d";
	report["town_to_terrain_table_address"] = "0x540908";
	report["allowed_terrain_flags_source"] = "source_zone+0x85..0x8c";
	report["rng_state_before_0x49b53d_uint32"] = int64_t(rng_state_after_coordinate_replay);
	H3MapedRng rng { rng_state_after_coordinate_replay };
	Array town_table;
	const std::array<int32_t, 9> h3_town_to_terrain = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	for (int32_t item : h3_town_to_terrain) {
		town_table.append(item);
	}
	report["town_choice_to_terrain_table"] = town_table;
	Array selections;
	int32_t rng_call_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t forced_subterranean_count = 0;
	int32_t blank_allowed_mask_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		Dictionary selection;
		const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		const int32_t level = int32_t(runtime.get("level", 0));
		const bool match_to_faction = bool(runtime.get("terrain_match_to_faction", false));
		const int32_t town_choice_index = int32_t(runtime.get("town_choice_index", -1));
		selection["runtime_zone_index"] = zone_index;
		selection["source_zone_id"] = runtime.get("source_zone_id", -1);
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
				const String terrain = String(allowed[allowed_index]);
				const int32_t h3_id = h3maped_id_for_terrain(terrain);
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
		runtime["h3maped_terrain_id"] = selected_terrain;
		runtime["terrain_id"] = terrain_for_h3maped_id(selected_terrain);
		runtime["terrain_source"] = source;
		runtime["terrain_selection_status"] = "0x49b53d_ported";
		runtime_zones[runtime_index] = runtime;
		selection["selected_h3maped_terrain_id"] = selected_terrain;
		selection["selected_project_terrain_id"] = runtime.get("terrain_id", "");
		selection["source"] = source;
		selections.append(selection);
	}
	report["selection_count"] = selections.size();
	report["selections"] = selections;
	report["match_to_town_count"] = match_to_town_count;
	report["allowed_flag_choice_count"] = allowed_flag_choice_count;
	report["blank_allowed_mask_count"] = blank_allowed_mask_count;
	report["forced_subterranean_count"] = forced_subterranean_count;
	report["rng_call_count"] = rng_call_count;
	report["rng_state_after_0x49b53d_uint32"] = int64_t(rng.state);
	report["blocked_next"] = "the selected runtime+0x0c terrain ids now feed the 0x4a3f27 schedule; next recover TerrainPlacement art/index/flip normalization";
	return report;
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
	auto accept_with_original_x = [&](const String &branch) {
		result.x = x1;
		result.y = clipped_y;
		result.branch = branch;
		return result;
	};
	auto accept_current = [&](const String &branch) {
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
			return accept_with_original_x("0x4a2bb5_left_edge_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_with_original_x("0x4a2bb5_left_edge_crosses_max_y");
		}
	}

	if (clipped_y < bounds.min_y && dy != 0) {
		const int32_t delta = bounds.min_y - clipped_y;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		if (x1 >= bounds.min_x && clipped_x < bounds.min_x) {
			return accept_with_original_x("0x4a2bb5_min_y_crosses_min_x");
		}
		if (x1 < bounds.max_x && clipped_x >= bounds.max_x) {
			return accept_with_original_x("0x4a2bb5_min_y_crosses_max_x");
		}
	}

	if (clipped_x >= bounds.max_x && dx != 0) {
		const int32_t delta = bounds.max_x - clipped_x - 1;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dx));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dx));
		if (y1 >= bounds.min_y && clipped_y < bounds.min_y) {
			return accept_with_original_x("0x4a2bb5_max_x_crosses_min_y");
		}
		if (y1 < bounds.max_y && clipped_y >= bounds.max_y) {
			return accept_with_original_x("0x4a2bb5_max_x_crosses_max_y");
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

int32_t sign_for_line_4a261a(int32_t value) {
	return value > 0 ? 1 : -1;
}

void write_line_cell_4a261a(
		LineWriteResult &result,
		int32_t width,
		int32_t height,
		int32_t level_count,
		int32_t water_code,
		int32_t x,
		int32_t y,
		int32_t zone_id,
		int32_t level) {
	if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
		result.out_of_bounds_write_count += 1;
		return;
	}
	LineCellWrite write;
	write.x = x;
	write.y = y;
	write.level = level;
	write.zone_id = zone_id & 0xff;
	write.reserved = !(water_code == 2 && level != 1);
	result.trace.push_back(write);
	const int64_t key = (int64_t(level) * int64_t(height) + int64_t(y)) * int64_t(width) + int64_t(x);
	result.unique_cells[key] = true;
}

LineWriteResult line_writer_4a261a(
		int32_t width,
		int32_t height,
		int32_t level_count,
		int32_t water_code,
		int32_t x1,
		int32_t y1,
		int32_t x2,
		int32_t y2,
		int32_t zone_id,
		int32_t level) {
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
	int32_t diagonal_step_y = sign_for_line_4a261a(dy);
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
		write_line_cell_4a261a(result, width, height, level_count, water_code, x, y, zone_id, level);
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
	write_line_cell_4a261a(result, width, height, level_count, water_code, x, y, zone_id, level);
	return result;
}

LineWriteResult randomized_line_writer_4a2413(
		int32_t width,
		int32_t height,
		int32_t level_count,
		int32_t water_code,
		int32_t x1,
		int32_t y1,
		int32_t x2,
		int32_t y2,
		int32_t zone_id,
		int32_t level,
		int32_t random_span_limit,
		H3MapedRng &rng,
		int32_t *rng_call_count,
		int32_t *inserted_midpoint_count,
		int32_t *max_pending_point_count) {
	LineWriteResult result;
	std::vector<PolygonPoint> pending;
	pending.push_back(PolygonPoint { x2, y2 });
	if (max_pending_point_count != nullptr) {
		*max_pending_point_count = std::max<int32_t>(*max_pending_point_count, int32_t(pending.size()));
	}
	int32_t current_x = x1;
	int32_t current_y = y1;
	for (int32_t guard = 0; guard < 4096 && !pending.empty(); ++guard) {
		const PolygonPoint target = pending.back();
		pending.pop_back();
		const int32_t midpoint_x = (target.x + current_x + 1) / 2;
		const int32_t midpoint_y = (target.y + current_y + 1) / 2;
		if ((midpoint_x == current_x && midpoint_y == current_y) || (midpoint_x == target.x && midpoint_y == target.y)) {
			const int32_t clamped_x = std::min(std::max(current_x, 0), width - 1);
			const int32_t clamped_y = std::min(std::max(current_y, 0), height - 1);
			write_line_cell_4a261a(result, width, height, level_count, water_code, clamped_x, clamped_y, zone_id, level);
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
			if (rng_call_count != nullptr) {
				*rng_call_count += 1;
			}
			const int32_t centered_offset = (rng_value % jitter_limit) - (jitter_limit / 2);
			const int32_t adjusted_x = (int64_t(centered_offset) * int64_t(neg_dy)) / int64_t(segment_length);
			const int32_t adjusted_y = (int64_t(dx) * int64_t(centered_offset)) / int64_t(segment_length);
			jittered_x += adjusted_x;
			jittered_y += adjusted_y;
		}
		pending.push_back(target);
		pending.push_back(PolygonPoint { jittered_x, jittered_y });
		if (inserted_midpoint_count != nullptr) {
			*inserted_midpoint_count += 1;
		}
		if (max_pending_point_count != nullptr) {
			*max_pending_point_count = std::max<int32_t>(*max_pending_point_count, int32_t(pending.size()));
		}
	}
	return result;
}

bool point_inside_bounds_4a2777(const ClipResult &point, const ClipBounds &bounds) {
	return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
}

void merge_line_write_result_4a2777(
		const LineWriteResult &line,
		std::map<int64_t, bool> &unique_cells,
		int32_t &trace_write_count,
		int32_t &out_of_bounds_write_count) {
	for (const auto &item : line.unique_cells) {
		unique_cells[item.first] = true;
	}
	trace_write_count += int32_t(line.trace.size());
	out_of_bounds_write_count += line.out_of_bounds_write_count;
}

int64_t cell_key_4a325d(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

uint32_t zone_word_4a325d(uint32_t existing_word, int32_t zone_id) {
	return (existing_word & 0xff00ffffU) | (uint32_t(zone_id & 0xff) << 16U);
}

void apply_line_trace_to_zone_buffer_4a2777(
		const LineWriteResult &line,
		std::vector<uint32_t> *zone_words,
		std::vector<uint8_t> *cell_flags,
		int32_t width,
		int32_t height,
		int32_t level_count) {
	if (zone_words == nullptr || cell_flags == nullptr) {
		return;
	}
	for (const LineCellWrite &write : line.trace) {
		if (write.x < 0 || write.y < 0 || write.level < 0 || write.x >= width || write.y >= height || write.level >= level_count) {
			continue;
		}
		const int64_t key = cell_key_4a325d(width, height, write.x, write.y, write.level);
		(*zone_words)[size_t(key)] = zone_word_4a325d((*zone_words)[size_t(key)], write.zone_id);
		if (write.reserved) {
			(*cell_flags)[size_t(key)] = uint8_t((*cell_flags)[size_t(key)] | 0x10U);
		}
	}
}

Dictionary segment_report_4a2777(
		const String &id,
		const String &branch,
		const String &writer,
		int32_t from_x,
		int32_t from_y,
		int32_t to_x,
		int32_t to_y,
		const LineWriteResult &line) {
	Dictionary segment;
	segment["id"] = id;
	segment["branch"] = branch;
	segment["writer"] = writer;
	segment["from_x"] = from_x;
	segment["from_y"] = from_y;
	segment["to_x"] = to_x;
	segment["to_y"] = to_y;
	segment["trace_write_count"] = int32_t(line.trace.size());
	segment["unique_cell_count"] = int32_t(line.unique_cells.size());
	segment["out_of_bounds_write_count"] = line.out_of_bounds_write_count;
	return segment;
}

int32_t zone_word_id_for_runtime_zone(const Dictionary &runtime_zone) {
	const int32_t runtime_index = int32_t(runtime_zone.get("runtime_zone_index", -1));
	const int32_t source_zone_id = int32_t(runtime_zone.get("source_zone_id", -1));
	if (source_zone_id > 0 && runtime_index >= 0 && source_zone_id == runtime_index + 1) {
		return runtime_index;
	}
	if (source_zone_id >= 0) {
		return source_zone_id;
	}
	return runtime_index;
}

Dictionary boundary_traversal_4a2777_report(
		const Dictionary &normalized_config,
		const Array &runtime_zones,
		const Dictionary &split_model,
		uint32_t rng_state_after_coordinate_seed,
		std::vector<uint32_t> *zone_words_out = nullptr,
		std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a2777_real_source_node_cycle_traversal_ported_boundary_materialized";
	report["source"] = "h3maped 0x4a2777 over real 0x4cca55 source-node cycles: clip finalized +0x1c/+0x20 coordinates through 0x4a2b33 and paint boundary cells through 0x4a261a/0x4a2413";
	report["function_address"] = "0x4a2777";
	report["caller_address"] = "0x4a3e58..0x4a3e8c";
	report["clip_helper_address"] = "0x4a2b33";
	report["deterministic_line_writer_address"] = "0x4a261a";
	report["flagged_line_writer_address"] = "0x4a2413";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["rng_state_before_0x4a2777_uint32"] = int64_t(rng_state_after_coordinate_seed);
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		const int32_t cell_count = std::max(0, width * height * std::max(1, level_count));
		zone_words_out->assign(size_t(cell_count), H3MAPED_UNASSIGNED_ZONE_WORD);
		cell_flags_out->assign(size_t(cell_count), 0);
	}

	Array walks = split_model.get("source_node_walks", Array());
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
	H3MapedRng rng { rng_state_after_coordinate_seed };

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
			line = randomized_line_writer_4a2413(width, height, level_count, water_code, x1, y1, x2, y2, zone_word, level, random_span_limit, rng, &randomized_rng_call_count, &randomized_inserted_midpoint_count, &randomized_max_pending_point_count);
			flagged_writer_segment_count += 1;
		} else {
			line = line_writer_4a261a(width, height, level_count, water_code, x1, y1, x2, y2, zone_word, level);
			deterministic_writer_segment_count += 1;
		}
		merge_line_write_result_4a2777(line, unique_cells, trace_write_count, out_of_bounds_write_count);
		apply_line_trace_to_zone_buffer_4a2777(line, zone_words_out, cell_flags_out, width, height, level_count);
		segments.append(segment_report_4a2777(id, branch, randomized ? String("0x4a2413") : String("0x4a261a"), x1, y1, x2, y2, line));
	};

	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};

	for (int64_t walk_index = 0; walk_index < walks.size(); ++walk_index) {
		if (Variant(walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary walk = Dictionary(walks[walk_index]);
		const int32_t runtime_zone_index = int32_t(walk.get("runtime_zone_index", -1));
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["source_zone_id"] = walk.get("source_zone_id", -1);
		zone_report["status"] = "blocked_before_cycle_consumption";
		if (runtime_zone_index < 0 || runtime_zone_index >= runtime_zones.size()
				|| Variant(runtime_zones[runtime_zone_index]).get_type() != Variant::DICTIONARY) {
			blocked_zone_count += 1;
			zone_reports.append(zone_report);
			continue;
		}
		Dictionary runtime_zone = Dictionary(runtime_zones[runtime_zone_index]);
		const int32_t zone_word = zone_word_id_for_runtime_zone(runtime_zone);
		const int32_t level = int32_t(runtime_zone.get("level", 0));
		const bool flagged_branch = !(level_count == 2 && level != 1);
		const int32_t random_span_limit = std::max<int32_t>(1, int32_t(runtime_zone.get("runtime_size_after_bbox_rescale", runtime_zone.get("source_base_size", 1))));
		Array cycle_nodes = walk.get("cycle_nodes", Array());
		std::vector<PolygonPoint> finalized_points;
		Array point_reports;
		for (int64_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
			if (Variant(cycle_nodes[node_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary node = Dictionary(cycle_nodes[node_index]);
			if (!bool(node.get("finalized", false))) {
				skipped_unfinalized_node_count += 1;
				continue;
			}
			const int32_t x = int32_t(node.get("+0x1c_finalized_x", 0));
			const int32_t y = int32_t(node.get("+0x20_finalized_y", 0));
			finalized_points.push_back(PolygonPoint { x, y });
			Dictionary point;
			point["node_id"] = node.get("node_id", "");
			point["x"] = x;
			point["y"] = y;
			point_reports.append(point);
		}
		zone_report["finalized_point_count"] = int32_t(finalized_points.size());
		zone_report["finalized_points"] = point_reports;
		zone_report["flagged_branch_from_0x4a3e69"] = flagged_branch;
		zone_report["random_span_limit_source"] = "runtime_zone+0x1c";
		zone_report["random_span_limit_runtime_size"] = random_span_limit;
		zone_report["random_span_limit_source_base_size"] = runtime_zone.get("source_base_size", 0);
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
			ClipResult candidate_current = clip_point_4a2b33(from.x, from.y, to.x, to.y, bounds);
			ClipResult candidate_target = clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777(candidate_current, bounds)) {
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
			const ClipResult next_clip = clip_point_4a2b33(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777(next_clip, bounds)) {
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
	report["unique_cell_count"] = int32_t(unique_cells.size());
	report["out_of_bounds_write_count"] = out_of_bounds_write_count;
	report["loop_guard_exhausted"] = loop_guard_exhausted;
	report["zone_reports"] = zone_reports;
	report["blocked_next"] = "feed these real 0x4a2777 boundary cells into 0x4a325d span fill before project terrain/object materialization";
	return report;
}

bool span_cell_in_bounds_4a325d(int32_t width, int32_t height, int32_t level_count, const SpanRecord &span) {
	return span.x >= 0 && span.x < width && span.y >= 0 && span.y < height && span.level >= 0 && span.level < level_count;
}

bool is_unassigned_zone_word_4a325d(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (zone_words[size_t(cell_key_4a325d(width, height, x, y, level))] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD;
}

void push_span_4a325d(std::vector<SpanRecord> &pending, const SpanRecord &span, SpanFillResult &result) {
	pending.push_back(span);
	result.pushed_span_count += 1;
	result.max_pending_span_count = std::max<int32_t>(result.max_pending_span_count, int32_t(pending.size()));
}

SpanFillResult span_fill_4a325d(
		std::vector<uint32_t> &zone_words,
		std::vector<uint8_t> &cell_flags,
		int32_t width,
		int32_t height,
		int32_t level_count,
		int32_t water_code,
		int32_t zone_id,
		const SpanRecord &seed) {
	SpanFillResult result;
	std::vector<SpanRecord> pending;
	push_span_4a325d(pending, seed, result);
	for (int32_t guard = 0; guard < width * height * std::max(1, level_count) * 4 && !pending.empty(); ++guard) {
		SpanRecord span = pending.back();
		pending.pop_back();
		result.popped_span_count += 1;
		if (!span_cell_in_bounds_4a325d(width, height, level_count, span)) {
			result.out_of_bounds_span_count += 1;
			continue;
		}
		int32_t x = span.x;
		while (x > 0 && is_unassigned_zone_word_4a325d(zone_words, width, height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		if (x >= 0 && x < width && !is_unassigned_zone_word_4a325d(zone_words, width, height, x, span.y, span.level)) {
			result.blocked_initial_span_count += 1;
		}
		bool above_open = false;
		bool below_open = false;
		SpanRecord above_span;
		SpanRecord below_span;
		for (; x < width; ++x) {
			if (!is_unassigned_zone_word_4a325d(zone_words, width, height, x, span.y, span.level)) {
				break;
			}
			const int64_t key = cell_key_4a325d(width, height, x, span.y, span.level);
			zone_words[size_t(key)] = zone_word_4a325d(zone_words[size_t(key)], zone_id);
			const bool reserved = !(water_code == 2 && span.level == 1);
			if (reserved) {
				cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
			}
			SpanFillCellWrite write;
			write.x = x;
			write.y = span.y;
			write.level = span.level;
			write.zone_id = zone_id;
			write.reserved = reserved;
			result.trace.push_back(write);
			result.unique_cells[key] = true;
			if (span.y > 0 && is_unassigned_zone_word_4a325d(zone_words, width, height, x, span.y - 1, span.level)) {
				if (!above_open) {
					above_span = span;
					above_span.x = x;
					above_span.y = span.y - 1;
					above_open = true;
				}
			} else if (above_open) {
				push_span_4a325d(pending, above_span, result);
				above_open = false;
			}
			if (span.y < height - 1 && is_unassigned_zone_word_4a325d(zone_words, width, height, x, span.y + 1, span.level)) {
				if (!below_open) {
					below_span = span;
					below_span.x = x;
					below_span.y = span.y + 1;
					below_open = true;
				}
			} else if (below_open) {
				push_span_4a325d(pending, below_span, result);
				below_open = false;
			}
		}
		if (above_open) {
			push_span_4a325d(pending, above_span, result);
		}
		if (below_open) {
			push_span_4a325d(pending, below_span, result);
		}
	}
	return result;
}

Array span_trace_preview_4a325d(const std::vector<SpanFillCellWrite> &trace, int32_t limit = 12) {
	Array preview;
	const int32_t count = std::min<int32_t>(limit, int32_t(trace.size()));
	for (int32_t index = 0; index < count; ++index) {
		const SpanFillCellWrite &write = trace[size_t(index)];
		Dictionary item;
		item["x"] = write.x;
		item["y"] = write.y;
		item["level"] = write.level;
		item["zone_id"] = write.zone_id;
		item["reserved"] = write.reserved;
		preview.append(item);
	}
	return preview;
}

Dictionary seed_relocation_4a325d_report(
		const Dictionary &source_node_walk,
		const SpanRecord &seed,
		int32_t width,
		int32_t height,
		int32_t level_count) {
	Dictionary report;
	report["status"] = "0x4a325d_seed_in_bounds_relocation_not_used";
	report["source"] = "h3maped 0x4a32b2..0x4a338e relocation branch; when runtime_zone+0x10 is outside map bounds, scan the source-node cycle for the interior node with maximum distance from all borders, then clip the original seed toward that node through 0x4a2b33";
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
		Dictionary node = Dictionary(cycle_nodes[node_index]);
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
	const ClipResult clipped = clip_point_4a2b33(seed.x, seed.y, best_x, best_y, bounds);
	report["status"] = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
	report["relocated"] = true;
	report["relocated_seed_x"] = clipped.x;
	report["relocated_seed_y"] = clipped.y;
	report["relocated_seed_level"] = seed.level;
	report["clip_branch"] = clipped.branch;
	return report;
}

Dictionary span_fill_4a325d_report(
		const Dictionary &normalized_config,
		const Array &runtime_zones,
		const Dictionary &split_model,
		uint32_t rng_state_after_coordinate_seed,
		std::vector<uint32_t> *zone_words_out = nullptr,
		std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a325d_real_0x4a2777_boundary_span_fill_executed_terrain_schedule_ready";
	report["source"] = "h3maped 0x4a325d footprint cell-span fill helper; consumes the real 0x4a2777 boundary buffer and fills from runtime_zone+0x10 seed coordinates";
	report["function_address"] = "0x4a325d";
	report["call_site_address"] = "0x4a3ee8..0x4a3eef";
	report["polygon_locator_address"] = "0x4cca55";
	report["clip_helper_address"] = "0x4a2b33";
	report["span_vector_push_address"] = "0x4ae1fd";
	report["span_vector_pop_address"] = "0x4ae23e";
	report["per_zone_order_helper_address"] = "0x4a3554";
	report["map_cell_stride_bytes"] = 0x30;
	report["unassigned_zone_word_sentinel"] = "0x00ff0000";
	report["map_cell_zone_word_mask"] = "cell+0x20 & 0x00ff0000";
	report["map_cell_reserved_flag"] = "cell+0x2b |= 0x10";

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary boundary = boundary_traversal_4a2777_report(normalized_config, runtime_zones, split_model, rng_state_after_coordinate_seed, &zone_words, &cell_flags);
	Array source_node_walks = split_model.get("source_node_walks", Array());
	Array zone_fill_reports;
	std::map<int64_t, bool> unique_filled_cells;
	int32_t filled_zone_count = 0;
	int32_t seed_blocked_count = 0;
	int32_t seed_relocated_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t blocked_initial_span_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		Dictionary zone_report;
		const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		zone_report["runtime_zone_index"] = zone_index;
		zone_report["source_zone_id"] = runtime.get("source_zone_id", -1);
		zone_report["seed_source"] = "runtime_zone+0x10 copied x/y/level from 0x4a325d";
		zone_report["seed_x"] = runtime.get("x_after_bbox_rescale", 0);
		zone_report["seed_y"] = runtime.get("y_after_bbox_rescale", 0);
		zone_report["seed_level"] = runtime.get("level", 0);
		const int32_t zone_word = zone_word_id_for_runtime_zone(runtime);
		zone_report["zone_word_id"] = zone_word;
		SpanRecord seed;
		seed.x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		seed.y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		seed.level = int32_t(runtime.get("level", 0));
		Dictionary matching_walk;
		for (int64_t walk_index = 0; walk_index < source_node_walks.size(); ++walk_index) {
			if (Variant(source_node_walks[walk_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary walk = Dictionary(source_node_walks[walk_index]);
			if (int32_t(walk.get("runtime_zone_index", -1)) == zone_index) {
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
			seed_relocated_count += 1;
		}
		zone_report["effective_seed_x"] = seed.x;
		zone_report["effective_seed_y"] = seed.y;
		zone_report["effective_seed_level"] = seed.level;
		const bool seed_in_bounds = span_cell_in_bounds_4a325d(width, height, level_count, seed);
		zone_report["seed_in_bounds"] = seed_in_bounds;
		if (!seed_in_bounds) {
			seed_blocked_count += 1;
			zone_report["status"] = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
			zone_fill_reports.append(zone_report);
			continue;
		}
		const bool seed_unassigned = is_unassigned_zone_word_4a325d(zone_words, width, height, seed.x, seed.y, seed.level);
		zone_report["seed_unassigned_before_fill"] = seed_unassigned;
		if (!seed_unassigned) {
			seed_blocked_count += 1;
		}
		SpanFillResult fill = span_fill_4a325d(zone_words, cell_flags, width, height, level_count, water_code, zone_word, seed);
		for (const auto &item : fill.unique_cells) {
			unique_filled_cells[item.first] = true;
		}
		if (!fill.trace.empty()) {
			filled_zone_count += 1;
		}
		out_of_bounds_span_count += fill.out_of_bounds_span_count;
		pushed_span_count += fill.pushed_span_count;
		popped_span_count += fill.popped_span_count;
		max_pending_span_count = std::max<int32_t>(max_pending_span_count, fill.max_pending_span_count);
		blocked_initial_span_count += fill.blocked_initial_span_count;
		zone_report["status"] = fill.trace.empty() ? String("0x4a325d_seed_reached_non_unassigned_boundary") : String("0x4a325d_real_boundary_span_fill_executed");
		zone_report["filled_cell_count"] = int32_t(fill.trace.size());
		zone_report["unique_filled_cell_count"] = int32_t(fill.unique_cells.size());
		zone_report["pushed_span_count"] = fill.pushed_span_count;
		zone_report["popped_span_count"] = fill.popped_span_count;
		zone_report["max_pending_span_count"] = fill.max_pending_span_count;
		zone_report["out_of_bounds_span_count"] = fill.out_of_bounds_span_count;
		zone_report["blocked_initial_span_count"] = fill.blocked_initial_span_count;
		zone_report["trace_preview"] = span_trace_preview_4a325d(fill.trace, 6);
		zone_fill_reports.append(zone_report);
	}

	int32_t remaining_unassigned_count = 0;
	int32_t boundary_or_filled_count = 0;
	int32_t reserved_cell_count = 0;
	std::map<int32_t, int32_t> cells_by_zone_word;
	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int64_t key = cell_key_4a325d(width, height, x, y, level);
				if (cell_flags.size() > size_t(key) && (cell_flags[size_t(key)] & 0x10U) != 0) {
					reserved_cell_count += 1;
				}
				const uint32_t zone_word = zone_words[size_t(key)] & H3MAPED_UNASSIGNED_ZONE_WORD;
				if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD) {
					remaining_unassigned_count += 1;
				} else {
					boundary_or_filled_count += 1;
					cells_by_zone_word[int32_t((zone_word >> 16U) & 0xffU)] += 1;
				}
			}
		}
	}
	Array cells_by_zone_word_report;
	for (const auto &item : cells_by_zone_word) {
		Dictionary entry;
		entry["zone_word_id"] = item.first;
		entry["cell_count"] = item.second;
		cells_by_zone_word_report.append(entry);
	}

	report["boundary_status"] = boundary.get("status", "");
	report["boundary_unique_cell_count"] = boundary.get("unique_cell_count", 0);
	report["runtime_zone_fill_attempt_count"] = zone_fill_reports.size();
	report["filled_zone_count"] = filled_zone_count;
	report["seed_blocked_count"] = seed_blocked_count;
	report["seed_relocated_count"] = seed_relocated_count;
	report["total_unique_filled_cell_count"] = int32_t(unique_filled_cells.size());
	report["total_boundary_or_filled_cell_count"] = boundary_or_filled_count;
	report["remaining_unassigned_cell_count"] = remaining_unassigned_count;
	report["reserved_cell_count"] = reserved_cell_count;
	report["pushed_span_count"] = pushed_span_count;
	report["popped_span_count"] = popped_span_count;
	report["max_pending_span_count"] = max_pending_span_count;
	report["out_of_bounds_span_count"] = out_of_bounds_span_count;
	report["blocked_initial_span_count"] = blocked_initial_span_count;
	report["cells_by_zone_word"] = cells_by_zone_word_report;
	report["zone_fills"] = zone_fill_reports;
	report["blocked_next"] = "feed the 0x4a325d span fill through the small-land 0x4a3710 finalizer and 0x4a3f27 terrain schedule before TerrainPlacement art/index/flip adoption";
	if (zone_words_out != nullptr) {
		*zone_words_out = zone_words;
	}
	if (cell_flags_out != nullptr) {
		*cell_flags_out = cell_flags;
	}
	return report;
}

Dictionary terrain_fill_repaint_4a3f27_report(
		const Dictionary &normalized_config,
		const Array &runtime_zones,
		const std::vector<uint32_t> &zone_words,
		const std::vector<uint8_t> &cell_flags) {
	Dictionary report;
	report["status"] = "0x4a3f27_terrain_fill_repaint_schedule_ported_inspection_only";
	report["source"] = "h3maped 0x4a3f27 terrain fill/repaint schedule over the real 0x4a325d zone-word buffer; TerrainPlacement art/index/flip normalization is replayed for one-level small land inspection";
	report["function_address"] = "0x4a3f27";
	report["prepass_helper_address"] = "0x4a2105";
	report["runtime_zone_recenter_helper_address"] = "0x4a2ffa";
	report["islands_connector_helper_address"] = "0x4a30c2";
	report["terrain_placement_constructor_address"] = "0x4bcff5";
	report["terrain_repaint_address"] = "0x4bd099";
	report["terrain_placement_destructor_address"] = "0x4bd077";
	report["terrain_adapter_vtable"] = "0x540a14";
	report["generated_cell_stride_bytes"] = 0x30;
	report["owner_byte_source"] = "cell+0x20 bits 16..23";
	report["zone_repaint_member_bit"] = "cell+0x28 bit 28 / cell+0x2b bit 0x10";
	report["runtime_repaint_compare"] = "0x4a4142..0x4a4163 compares signed owner byte to runtime-zone loop index";

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t tile_count = width * height * level_count;
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;
	report["tile_count"] = tile_count;
	report["h3maped_water_mode_code"] = water_code;
	report["whole_map_fill_terrain_id"] = 8;
	report["whole_map_fill_project_terrain_id"] = terrain_for_h3maped_id(8);
	report["whole_map_fill_cell_count"] = tile_count;
	report["whole_map_fill_call"] = "0x4bcff5(adapter=generator+0x0c, terrain=8, arg=4) then 0x4bd099(0,0,width,height)";
	report["multi_level_generated_slice_adapter_status"] = level_count > 1 ? String("scheduled") : String("skipped_one_level_map");
	report["islands_connector_repaint_status"] = water_code == 2 ? String("scheduled_for_level_zero_runtime_zones") : String("skipped_non_islands_water_mode");

	PackedInt32Array owner_byte_grid;
	PackedInt32Array repaint_member_grid;
	PackedInt32Array zone_word_low_grid;
	owner_byte_grid.resize(tile_count);
	repaint_member_grid.resize(tile_count);
	zone_word_low_grid.resize(tile_count);
	for (int32_t flat_index = 0; flat_index < tile_count; ++flat_index) {
		owner_byte_grid.set(flat_index, -1);
		repaint_member_grid.set(flat_index, 0);
		zone_word_low_grid.set(flat_index, 0);
	}

	std::map<int32_t, TerrainCellStats> stats_by_owner_byte;
	int32_t assigned_owner_cell_count = 0;
	int32_t repaint_member_cell_count = 0;
	int32_t unresolved_cell_count = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int64_t key = cell_key_4a325d(width, height, x, y, level);
				if (key < 0 || size_t(key) >= zone_words.size()) {
					continue;
				}
				const uint32_t zone_word_bits = zone_words[size_t(key)] & H3MAPED_UNASSIGNED_ZONE_WORD;
				if (zone_word_bits == H3MAPED_UNASSIGNED_ZONE_WORD) {
					unresolved_cell_count += 1;
					continue;
				}
				const bool repaint_member = cell_flags.size() > size_t(key) && (cell_flags[size_t(key)] & 0x10U) != 0;
				const int32_t owner_byte = int32_t((zone_word_bits >> 16U) & 0xffU);
				owner_byte_grid.set(int32_t(key), owner_byte);
				repaint_member_grid.set(int32_t(key), repaint_member ? 1 : 0);
				zone_word_low_grid.set(int32_t(key), int32_t(zone_words[size_t(key)] & 0xffffU));
				stats_by_owner_byte[owner_byte].add(x, y, repaint_member);
				assigned_owner_cell_count += 1;
				if (repaint_member) {
					repaint_member_cell_count += 1;
				}
			}
		}
	}
	report["assigned_owner_cell_count"] = assigned_owner_cell_count;
	report["zone_repaint_member_cell_count"] = repaint_member_cell_count;
	report["unresolved_cell_count"] = unresolved_cell_count;
	report["bbox_update_scan_status"] = "0x4a2105_scans_owned_cells_and_updates_runtime_zone_bbox_via_0x49b66d";
	report["bbox_update_scan_cell_count"] = assigned_owner_cell_count;
	report["runtime_zone_recenter_call_count"] = runtime_zones.size();

	PackedInt32Array terrain_codes;
	PackedInt32Array terrain_art_indices;
	PackedInt32Array terrain_flip_h;
	PackedInt32Array terrain_flip_v;
	PackedInt32Array terrain_shape_classes;
	PackedInt32Array writeout_tile_byte_0;
	PackedInt32Array writeout_tile_byte_1;
	PackedInt32Array writeout_tile_byte_2;
	PackedInt32Array writeout_tile_byte_3;
	PackedInt32Array writeout_tile_byte_4;
	PackedInt32Array writeout_tile_byte_5;
	PackedInt32Array writeout_tile_byte_6;
	terrain_codes.resize(tile_count);
	terrain_art_indices.resize(tile_count);
	terrain_flip_h.resize(tile_count);
	terrain_flip_v.resize(tile_count);
	terrain_shape_classes.resize(tile_count);
	writeout_tile_byte_0.resize(tile_count);
	writeout_tile_byte_1.resize(tile_count);
	writeout_tile_byte_2.resize(tile_count);
	writeout_tile_byte_3.resize(tile_count);
	writeout_tile_byte_4.resize(tile_count);
	writeout_tile_byte_5.resize(tile_count);
	writeout_tile_byte_6.resize(tile_count);
	for (int32_t flat_index = 0; flat_index < tile_count; ++flat_index) {
		terrain_codes.set(flat_index, 8);
		terrain_art_indices.set(flat_index, 0);
		terrain_flip_h.set(flat_index, 0);
		terrain_flip_v.set(flat_index, 0);
		terrain_shape_classes.set(flat_index, 0);
		writeout_tile_byte_0.set(flat_index, 8);
		writeout_tile_byte_1.set(flat_index, 0);
		writeout_tile_byte_2.set(flat_index, 0);
		writeout_tile_byte_3.set(flat_index, 0);
		writeout_tile_byte_4.set(flat_index, 0);
		writeout_tile_byte_5.set(flat_index, 0);
		writeout_tile_byte_6.set(flat_index, 0);
	}

	Dictionary terrain_counts_after_repaint;
	terrain_counts_after_repaint[terrain_for_h3maped_id(8)] = tile_count;
	Array zone_reports;
	int32_t owner_basis_mismatch_count = 0;
	int32_t skipped_water_zone_count = 0;
	int32_t terrain_repaint_call_count = 0;
	int32_t runtime_index_repaint_member_cell_count = 0;
	int32_t source_zone_repaint_member_cell_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		const int32_t runtime_zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		const int32_t source_zone_id = int32_t(runtime.get("source_zone_id", -1));
		const int32_t source_owner_byte = zone_word_id_for_runtime_zone(runtime);
		const int32_t h3maped_terrain_id = int32_t(runtime.get("h3maped_terrain_id", h3maped_id_for_terrain(String(runtime.get("terrain_id", "")))));
		const String project_terrain_id = terrain_for_h3maped_id(h3maped_terrain_id);
		const TerrainCellStats source_stats = stats_by_owner_byte[source_owner_byte];
		const TerrainCellStats runtime_stats = stats_by_owner_byte[runtime_zone_index];
		source_zone_repaint_member_cell_count += source_stats.repaint_member_count;
		runtime_index_repaint_member_cell_count += runtime_stats.repaint_member_count;
		if (source_owner_byte != runtime_zone_index) {
			owner_basis_mismatch_count += 1;
		}
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["source_zone_id"] = source_zone_id;
		zone_report["source_owner_byte"] = source_owner_byte;
		zone_report["owner_byte_basis_matches_runtime_index"] = source_owner_byte == runtime_zone_index;
		zone_report["source_zone_owner_cell_count"] = source_stats.cell_count;
		zone_report["source_zone_repaint_member_cell_count"] = source_stats.repaint_member_count;
		zone_report["runtime_index_owner_cell_count"] = runtime_stats.cell_count;
		zone_report["runtime_index_repaint_member_cell_count"] = runtime_stats.repaint_member_count;
		zone_report["seed_before_0x4a2ffa_x"] = runtime.get("x_after_bbox_rescale", 0);
		zone_report["seed_before_0x4a2ffa_y"] = runtime.get("y_after_bbox_rescale", 0);
		zone_report["seed_level"] = runtime.get("level", 0);
		if (source_stats.cell_count > 0) {
			zone_report["bbox_min_x_after_0x4a2105"] = source_stats.min_x;
			zone_report["bbox_min_y_after_0x4a2105"] = source_stats.min_y;
			zone_report["bbox_max_x_after_0x4a2105_exclusive"] = source_stats.max_x + 1;
			zone_report["bbox_max_y_after_0x4a2105_exclusive"] = source_stats.max_y + 1;
		}
		zone_report["h3maped_terrain_id"] = h3maped_terrain_id;
		zone_report["project_terrain_id"] = project_terrain_id;
		if (h3maped_terrain_id == 8) {
			zone_report["repaint_status"] = "0x4a40b0_skip_runtime_zone_with_terrain_8";
			skipped_water_zone_count += 1;
		} else {
			zone_report["repaint_status"] = "0x4a410d_0x4bd099_per_cell_repaint_scheduled";
			zone_report["terrain_repaint_call_count"] = runtime_stats.repaint_member_count;
			terrain_repaint_call_count += runtime_stats.repaint_member_count;
			if (!project_terrain_id.is_empty()) {
				terrain_counts_after_repaint[terrain_for_h3maped_id(8)] = int32_t(terrain_counts_after_repaint.get(terrain_for_h3maped_id(8), 0)) - runtime_stats.repaint_member_count;
				terrain_counts_after_repaint[project_terrain_id] = int32_t(terrain_counts_after_repaint.get(project_terrain_id, 0)) + runtime_stats.repaint_member_count;
			}
			for (int32_t level = 0; level < level_count; ++level) {
				for (int32_t y = 0; y < height; ++y) {
					for (int32_t x = 0; x < width; ++x) {
						const int64_t key = cell_key_4a325d(width, height, x, y, level);
						if (key < 0 || size_t(key) >= zone_words.size()) {
							continue;
						}
						const uint32_t zone_word_bits = zone_words[size_t(key)] & H3MAPED_UNASSIGNED_ZONE_WORD;
						if (zone_word_bits == H3MAPED_UNASSIGNED_ZONE_WORD) {
							continue;
						}
						const bool repaint_member = cell_flags.size() > size_t(key) && (cell_flags[size_t(key)] & 0x10U) != 0;
						const int32_t owner_byte = int32_t((zone_word_bits >> 16U) & 0xffU);
						if (!repaint_member || owner_byte != runtime_zone_index) {
							continue;
						}
						terrain_codes.set(int32_t(key), terrain_code_for_h3maped_id(h3maped_terrain_id));
					}
				}
			}
		}
		zone_reports.append(zone_report);
	}

	Dictionary terrain_code_counts;
	Dictionary terrain_shape_class_counts;
	int32_t terrain_visual_fallback_count = 0;
	int32_t terrain_visual_transition_cell_count = 0;
	if (level_count == 1) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int32_t flat_index = y * width + x;
				const int32_t terrain_code = terrain_codes[flat_index];
				terrain_code_counts[terrain_code] = int32_t(terrain_code_counts.get(terrain_code, 0)) + 1;
				const TerrainVisualResult visual = terrain_visual_for_cell(terrain_codes, width, height, x, y);
				terrain_art_indices.set(flat_index, visual.art_index);
				terrain_flip_h.set(flat_index, visual.flip_h);
				terrain_flip_v.set(flat_index, visual.flip_v);
				terrain_shape_classes.set(flat_index, visual.class_code);
				writeout_tile_byte_0.set(flat_index, terrain_code & 0x3f);
				writeout_tile_byte_1.set(flat_index, visual.art_index & 0xff);
				writeout_tile_byte_6.set(flat_index, (visual.flip_h != 0 ? 0x01 : 0x00) | (visual.flip_v != 0 ? 0x02 : 0x00));
				terrain_shape_class_counts[visual.class_code] = int32_t(terrain_shape_class_counts.get(visual.class_code, 0)) + 1;
				if (visual.class_code != 0) {
					terrain_visual_transition_cell_count += 1;
				}
				if (visual.fallback) {
					terrain_visual_fallback_count += 1;
				}
			}
		}
	}
	report["zones"] = zone_reports;
	report["zone_count"] = zone_reports.size();
	report["skipped_water_zone_count"] = skipped_water_zone_count;
	report["terrain_repaint_call_count"] = terrain_repaint_call_count;
	report["owner_basis_mismatch_count"] = owner_basis_mismatch_count;
	report["source_zone_repaint_member_cell_count"] = source_zone_repaint_member_cell_count;
	report["runtime_index_repaint_member_cell_count"] = runtime_index_repaint_member_cell_count;
	report["runtime_index_unmatched_repaint_member_cell_count"] = std::max(0, source_zone_repaint_member_cell_count - runtime_index_repaint_member_cell_count);
	report["terrain_counts_after_repaint"] = terrain_counts_after_repaint;
	report["terrain_code_counts_after_repaint"] = terrain_code_counts;
	report["terrain_code_u16"] = terrain_codes;
	report["owner_byte_grid_u8"] = owner_byte_grid;
	report["zone_repaint_member_grid_u8"] = repaint_member_grid;
	report["zone_word_low_u16"] = zone_word_low_grid;
	report["terrain_art_index_u8"] = terrain_art_indices;
	report["terrain_flip_h"] = terrain_flip_h;
	report["terrain_flip_v"] = terrain_flip_v;
	report["terrain_shape_class_u8"] = terrain_shape_classes;
	report["tile_byte_0_terrain_id_u8"] = writeout_tile_byte_0;
	report["tile_byte_1_terrain_art_u8"] = writeout_tile_byte_1;
	report["tile_byte_2_river_type_u8"] = writeout_tile_byte_2;
	report["tile_byte_3_river_art_u8"] = writeout_tile_byte_3;
	report["tile_byte_4_road_type_u8"] = writeout_tile_byte_4;
	report["tile_byte_5_road_art_u8"] = writeout_tile_byte_5;
	report["tile_byte_6_terrain_flags_u8"] = writeout_tile_byte_6;
	report["tile_byte_writeout_status"] = "0x49b2b6_terrain_bytes_packed_overlay_bytes_pending";
	report["tile_byte_writeout_source"] = "0x49b2b6 serializes cell+0x24 bits 0..5 to byte 0, bits 6..13 to byte 1, and cell+0x28 bits 15..16 to output byte 6 bits 0..1";
	report["tile_byte_overlay_status"] = "road_and_river_overlay_bytes_zero_until_0x4ab37f_0x4b4243_and_0x4ab6ac_0x4abd5f_ports";
	report["terrain_visual_shape_class_counts"] = terrain_shape_class_counts;
	report["terrain_visual_transition_cell_count"] = terrain_visual_transition_cell_count;
	report["terrain_visual_fallback_count"] = terrain_visual_fallback_count;
	report["terrain_art_index_flip_status"] = level_count == 1
			? String("TerrainPlacement_visual_selection_ported_inspection_only")
			: String("pending_two_level_TerrainPlacement_adapter_art_index_flip_normalization");
	report["terrain_visual_selection_model"] = "ported_TerrainPlacementRules_relation_ring_class_rows_flip_v1";
	report["terrain_visual_selection_source"] = "scripts/core/TerrainPlacementRules.gd plus h3maped 0x4bcff5/0x4bd099 adapter call sequence";
	report["blocked_next"] = "feed normalized terrain cells into the clean runtime map adoption path, then port object/category, guard/reward/monster, and final object passes";
	return report;
}

Dictionary adjacency_finalizer_4a3710_report(const Dictionary &normalized_config, const Array &runtime_zones) {
	Dictionary report;
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	int32_t original_same_level_runtime_zone_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		if (int32_t(runtime.get("level", 0)) == 0) {
			original_same_level_runtime_zone_count += 1;
		}
	}
	const bool synthetic_branch_allowed = level_count > 1 || water_code != 0;
	const int32_t final_runtime_zone_count = int32_t(runtime_zones.size());
	const int32_t appended_runtime_zone_count = std::max(0, final_runtime_zone_count - original_same_level_runtime_zone_count);
	report["status"] = appended_runtime_zone_count == 0
			? String("0x4a3710_small_land_no_appended_zone_finalizer_ported")
			: String("0x4a3710_appended_zone_adjacency_finalizer_blocked");
	report["source"] = "h3maped 0x4a3710 footprint adjacency finalizer; small one-level land has no appended synthetic runtime zones, so adjacency insertion loops skip and ordering reset/rebuild calls execute";
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
	recovered_operations.append("iterates runtime zones at generator+0x10e4 from the level's original collected count to the current runtime-zone count");
	recovered_operations.append("finds the source polygon/list node containing each runtime zone rectangle origin through 0x4cca55");
	recovered_operations.append("compares same-level runtime zone rectangles and searches source adjacency/list nodes for matching neighbor references");
	recovered_operations.append("clips candidate source edges through 0x4a2b33 and rejects endpoints outside the map bounds");
	recovered_operations.append("adds bidirectional adjacency records into runtime_zone+0xc4 vectors through vector insert 0x4ae166");
	recovered_operations.append("resets each runtime zone ordering vector with 0x49b61b, then rebuilds per-zone ordering/depth state with 0x4a3554");
	recovered_operations.append("uses runtime_zone+0x3e8 short order values to avoid adding adjacency before existing earlier links are ordered");
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
	Array missing_layout;
	if (appended_runtime_zone_count > 0) {
		missing_layout.append("runtime_zone+0xc4 adjacency record schema written by 0x4ae166 for appended synthetic zones");
		missing_layout.append("runtime_zone+0x3e8 short ordering vector semantics used for appended-zone link ordering");
		missing_layout.append("source polygon/list node fields at +0x0c/+0x10/+0x14 and nested +0x08 references");
	}
	missing_layout.append("project-side representation for finalized physical zone links and guarded pass points");
	report["missing_runtime_layout"] = missing_layout;
	report["zone_order_reset_call_count"] = final_runtime_zone_count;
	report["per_zone_order_helper_call_count"] = original_same_level_runtime_zone_count;
	report["materialized_adjacency_count"] = 0;
	report["blocked_next"] = appended_runtime_zone_count == 0
			? String("continue after the completed small-land 0x4a3710 no-appended-zone path into TerrainPlacement art/index/flip normalization")
			: String("recover adjacency record and ordering-vector schemas before translating appended-zone 0x4a3710 output into project zone links");
	return report;
}

Dictionary polygon_source_node_walks_4ccb64_report(const Dictionary &normalized_config, const Array &runtime_zones) {
	Dictionary report;
	report["status"] = "0x4ccb64_insertion_bridge_crossing_cleanup_and_source_walks_ported_for_0x4a2777";
	report["source"] = "project-owned clean execution model for h3maped 0x4cc788, 0x4cca55, 0x4cc643, 0x4cc9cc, 0x4ccc7a, 0x4cc68e, 0x4ccd69, 0x4ccdfc, and the split-loop part of 0x4ccb64; feeds finalized source-node cycles into 0x4a2777 boundary traversal";
	report["locator_address"] = "0x4cca55";
	report["splitter_address"] = "0x4ccb64";
	report["bridge_address"] = "0x4ccb1f";
	report["crossing_test_address"] = "0x4ccc7a";
	report["crossing_collapse_address"] = "0x4cc68e";
	report["finalizer_address"] = "0x4ccdfc";
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	if (level_count != 1) {
		report["status"] = "unsupported_until_two_level_polygon_source_walk_ported";
		return report;
	}

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
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		if (int32_t(runtime.get("level", 0)) != 0) {
			continue;
		}
		const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		const int32_t x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		const int32_t y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		Dictionary step;
		step["runtime_zone_index"] = zone_index;
		step["source_zone_id"] = runtime.get("source_zone_id", -1);
		step["x"] = x;
		step["y"] = y;
		int32_t located = model.locate_4cca55(x, y);
		if (located < 0) {
			step["status"] = "0x4cca55_locator_guard_failed";
			blocked = true;
			split_steps.append(step);
			break;
		}
		step["located_node_id"] = model.nodes[size_t(located)].id;
		step["located_pair_id"] = model.nodes[size_t(model.nodes[size_t(located)].pair)].id;
		if ((model.nodes[size_t(located)].x == x && model.nodes[size_t(located)].y == y)
				|| (model.nodes[size_t(model.nodes[size_t(located)].pair)].x == x && model.nodes[size_t(model.nodes[size_t(located)].pair)].y == y)) {
			step["status"] = "0x4ccb64_duplicate_point_skipped";
			skipped_duplicate_count += 1;
			split_steps.append(step);
			continue;
		}
		if (model.edge_side_test_4cc6f2(located, x, y)) {
			step["edge_removal_branch"] = true;
			located = model.nodes[size_t(located)].previous;
			const int32_t erased = model.nodes[size_t(located)].next;
			step["edge_removal_status"] = "0x4cc9cc_vector_erase_branch_ported";
			step["edge_removal_anchor_node_id"] = model.nodes[size_t(located)].id;
			step["edge_removed_node_id"] = model.nodes[size_t(erased)].id;
			model.erase_edge_4cc9cc(erased);
			edge_removal_count += 1;
		} else {
			step["edge_removal_branch"] = false;
		}
		const PolygonModelNode &located_node = model.nodes[size_t(located)];
		const int32_t split_primary = model.add_pair(String("split_") + String::num_int64(zone_index), located_node.x, located_node.y, located_node.payload, x, y, zone_index, located_node.has_payload, true);
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
			current_bridge = model.bridge_4ccb1f(bridge_source, model.nodes[size_t(current_bridge)].pair, String("split_") + String::num_int64(zone_index) + "_bridge_" + String::num_int64(bridge_pair_count));
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
				step["status"] = "0x4ccb64_crossing_cleanup_guard_failed";
				blocked = true;
			}
		}
		step["crossing_cleanup_scan_count"] = cleanup_scan_count;
		step["crossing_test_count"] = cleanup_test_count;
		step["crossing_collapse_count"] = cleanup_collapse_count;
		step["allocated_node_pair_count_after_crossing_cleanup"] = int32_t(model.nodes.size() / 2);
		step["active_node_pair_count_after_crossing_cleanup"] = model.active_node_pair_count();
		step["status"] = blocked ? String("0x4ccb64_guard_failed") : String("0x4ccb64_pre_crossing_inserted");
		split_steps.append(step);
		if (blocked) {
			break;
		}
	}

	report["split_steps"] = split_steps;
	report["executed_split_call_count"] = executed_split_count;
	report["duplicate_skip_count"] = skipped_duplicate_count;
	report["edge_removal_branch_count"] = edge_removal_count;
	report["pre_crossing_inserted_node_pair_count"] = inserted_node_pair_count;
	report["pre_crossing_inserted_bridge_pair_count"] = inserted_bridge_pair_count;
	report["crossing_cleanup_scan_count"] = crossing_scan_count;
	report["crossing_test_count"] = crossing_test_count;
	report["crossing_collapse_count"] = crossing_collapse_count;
	report["initial_node_pair_count"] = 5;
	report["post_crossing_cleanup_allocated_node_pair_count"] = int32_t(model.nodes.size() / 2);
	report["post_crossing_cleanup_active_node_pair_count"] = model.active_node_pair_count();
	report["root_node_id_after_crossing_cleanup"] = model.root >= 0 ? model.nodes[size_t(model.root)].id : String();
	report["crossing_cleanup_status"] = blocked ? String("blocked_during_crossing_cleanup") : String("0x4ccc7a_0x4cc68e_crossing_cleanup_ported");
	Array finalized_steps;
	const int32_t finalized_triplet_count = blocked ? 0 : model.finalize_4ccdfc(&finalized_steps);
	int32_t finalized_node_count = 0;
	int32_t active_payload_node_count = 0;
	for (const PolygonModelNode &node : model.nodes) {
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
	report["finalizer_status"] = blocked ? String("blocked_before_0x4ccdfc") : String("0x4ccdfc_finalized_node_fanout_ported");
	report["finalized_triplet_count"] = finalized_triplet_count;
	report["finalized_node_count"] = finalized_node_count;
	report["active_payload_node_count"] = active_payload_node_count;
	report["finalized_steps"] = finalized_steps;

	Array source_node_walks;
	int32_t source_node_walk_count = 0;
	int32_t source_node_walk_guard_exhausted_count = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		if (int32_t(runtime.get("level", 0)) != 0) {
			continue;
		}
		const int32_t zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		const int32_t x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		const int32_t y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		Dictionary walk;
		walk["runtime_zone_index"] = zone_index;
		walk["source_zone_id"] = runtime.get("source_zone_id", -1);
		walk["locator_address"] = "0x4cca55";
		walk["consumer_address"] = "0x4a2777";
		walk["start_x"] = x;
		walk["start_y"] = y;
		const int32_t located = blocked ? -1 : model.locate_4cca55(x, y);
		walk["located_node_id"] = located >= 0 ? model.nodes[size_t(located)].id : String();
		Array cycle_nodes;
		bool guard_exhausted = false;
		int32_t finalized_coordinate_count = 0;
		if (located >= 0) {
			int32_t current = located;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const PolygonModelNode &node = model.nodes[size_t(current)];
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
	report["source_node_walk_status"] = blocked ? String("blocked_before_0x4cca55_source_node_walk") : String("0x4cca55_to_0x4a2777_source_node_cycles_recovered");
	report["source_node_walk_count"] = source_node_walk_count;
	report["source_node_walk_guard_exhausted_count"] = source_node_walk_guard_exhausted_count;
	report["source_node_walks"] = source_node_walks;
	report["blocked_next"] = "feed finalized 0x4ccdfc polygon coordinates into 0x4a2777 boundary traversal and 0x4a325d span fill";
	return report;
}

Dictionary zone_footprint_phase_4a3a03_report(const Dictionary &normalized_config, Array &runtime_zones, int64_t rng_state_after_coordinate_seed) {
	Dictionary report;
	report["status"] = "0x4a3a03_0x4a3710_footprint_helpers_ported_terrain_visual_ready";
	report["source"] = "h3maped 0x4a3a03 per-level runtime-zone collection, small-land synthetic branch decision, 0x4cc788 polygon seed setup, 0x4ccb64 split insertion, 0x4ccdfc finalization, 0x4cca55 source-node walks, 0x4a2777 boundary traversal, 0x4a325d span fill, and the small-land 0x4a3710 no-appended-zone finalizer";
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
	report["cell_materialization_status"] = "0x4a3710_small_land_finalizer_0x4a3f27_terrain_schedule_and_visual_normalization_ported_inspection_only";
	report["blocked_next"] = "adopt normalized terrain cells into the clean runtime map path before object and guard materialization";

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
	Dictionary source_walks = polygon_source_node_walks_4ccb64_report(normalized_config, runtime_zones);
	Dictionary boundary_traversal = boundary_traversal_4a2777_report(
			normalized_config,
			runtime_zones,
			source_walks,
			uint32_t(rng_state_after_coordinate_seed));
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary span_fill = span_fill_4a325d_report(
			normalized_config,
			runtime_zones,
			source_walks,
			uint32_t(rng_state_after_coordinate_seed),
			&zone_words,
			&cell_flags);
	Dictionary adjacency_finalizer = adjacency_finalizer_4a3710_report(normalized_config, runtime_zones);
	Dictionary terrain_fill_repaint = terrain_fill_repaint_4a3f27_report(normalized_config, runtime_zones, zone_words, cell_flags);
	polygon_seed["runtime_split_pre_crossing_model"] = source_walks;
	polygon_seed["runtime_split_pre_crossing_status"] = source_walks.get("status", "");
	polygon_seed["boundary_traversal_model"] = boundary_traversal;
	polygon_seed["boundary_traversal_status"] = boundary_traversal.get("status", "");
	polygon_seed["span_fill_model"] = span_fill;
	polygon_seed["span_fill_status"] = span_fill.get("status", "");
	polygon_seed["adjacency_finalizer_model"] = adjacency_finalizer;
	polygon_seed["adjacency_finalizer_status"] = adjacency_finalizer.get("status", "");
	polygon_seed["terrain_fill_repaint_model"] = terrain_fill_repaint;
	polygon_seed["terrain_fill_repaint_status"] = terrain_fill_repaint.get("status", "");
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	report["total_matching_runtime_zones"] = total_matching_runtime_zones;
	report["total_polygon_split_calls"] = total_split_calls;
	report["appended_synthetic_runtime_zone_count"] = appended_synthetic_runtime_zones;
	report["source_node_walk_status"] = source_walks.get("source_node_walk_status", "");
	report["source_node_walk_count"] = source_walks.get("source_node_walk_count", 0);
	report["source_node_walk_guard_exhausted_count"] = source_walks.get("source_node_walk_guard_exhausted_count", 0);
	report["finalizer_status"] = source_walks.get("finalizer_status", "");
	report["finalized_node_count"] = source_walks.get("finalized_node_count", 0);
	report["boundary_traversal_status"] = boundary_traversal.get("status", "");
	report["boundary_runtime_zone_walk_count"] = boundary_traversal.get("runtime_zone_walk_count", 0);
	report["boundary_unique_cell_count"] = boundary_traversal.get("unique_cell_count", 0);
	report["boundary_trace_write_count"] = boundary_traversal.get("trace_write_count", 0);
	report["boundary_loop_guard_exhausted"] = boundary_traversal.get("loop_guard_exhausted", false);
	report["boundary_traversal"] = boundary_traversal;
	report["span_fill_status"] = span_fill.get("status", "");
	report["span_fill_filled_zone_count"] = span_fill.get("filled_zone_count", 0);
	report["span_fill_unique_filled_cell_count"] = span_fill.get("total_unique_filled_cell_count", 0);
	report["span_fill_boundary_or_filled_cell_count"] = span_fill.get("total_boundary_or_filled_cell_count", 0);
	report["span_fill_remaining_unassigned_cell_count"] = span_fill.get("remaining_unassigned_cell_count", 0);
	report["span_fill_seed_relocated_count"] = span_fill.get("seed_relocated_count", 0);
	report["span_fill_blocked_initial_span_count"] = span_fill.get("blocked_initial_span_count", 0);
	report["span_fill"] = span_fill;
	report["adjacency_finalizer_status"] = adjacency_finalizer.get("status", "");
	report["adjacency_finalizer_appended_runtime_zone_count"] = adjacency_finalizer.get("appended_runtime_zone_count", 0);
	report["adjacency_finalizer_materialized_adjacency_count"] = adjacency_finalizer.get("materialized_adjacency_count", 0);
	report["adjacency_finalizer"] = adjacency_finalizer;
	report["terrain_fill_repaint_status"] = terrain_fill_repaint.get("status", "");
	report["terrain_repaint_call_count"] = terrain_fill_repaint.get("terrain_repaint_call_count", 0);
	report["terrain_repaint_counts_after_repaint"] = terrain_fill_repaint.get("terrain_counts_after_repaint", Dictionary());
	report["terrain_fill_repaint"] = terrain_fill_repaint;
	report["polygon_source_node_walks"] = source_walks;
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
			terrain_source = "terrain table preview from fixed selected faction before authoritative 0x49b53d terrain selection";
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
		runtime["allowed_terrain_ids_for_49b53d"] = terrain.get("allowed", Array());
		runtime["terrain_source_mask_count"] = terrain.get("source_mask_count", 0);
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
	Dictionary terrain_selection = runtime_terrain_selection_49b53d_report(
			runtime_zones,
			uint32_t(int64_t(coordinate_seed.get("rng_state_after_0x4a218c_replay_uint32", int64_t(rng_state_after_template_selection)))));
	Dictionary zone_footprint = zone_footprint_phase_4a3a03_report(
			normalized_config,
			runtime_zones,
			int64_t(terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_seed.get("rng_state_after_0x4a218c_replay_uint32", int64_t(rng_state_after_template_selection)))));

	report["status"] = "0x4a218c_runtime_zone_records_and_49b53d_terrain_ported_inspection_only";
	report["source"] = "h3maped 0x4a218c with interleaved 0x49b452 runtime initializer, 0x49b3c1 town choice, 0x4a1f3b coordinate replay, and post-rescale 0x49b53d runtime terrain selection";
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
	report["rng_state_after_runtime_zone_build"] = terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_seed.get("rng_state_after_0x4a218c_replay_uint32", int64_t(rng_state_after_template_selection)));
	report["rng_events"] = coordinate_seed.get("rng_events", rng_events);
	report["coordinate_placement_status"] = coordinate_seed.get("status", "");
	report["coordinate_seed"] = coordinate_seed;
	report["terrain_selection_status"] = terrain_selection.get("status", "");
	report["terrain_selection"] = terrain_selection;
	report["zone_footprint_placement_status"] = zone_footprint.get("status", "");
	report["zone_footprint_placement"] = zone_footprint;
	return report;
}

Dictionary town_castle_placement_4a8d2c_4a8db2_report(const Array &active_zones, const Dictionary &runtime_build) {
	Dictionary report;
	report["status"] = "0x4a8d2c_0x4a93a2_0x49aa93_town_49a09c_and_writeout_ledger_ported_inspection_only";
	report["source"] = "h3maped 0x4a8d2c direct minimum town/castle placement fields, the candidate-scan boundary of direct helper 0x4a93a2, recovered 0x49a1d8 validity precheck, current Town-body 0x49a09c gate order, and post-selection writeout ledger used by 0x49aa93/0x4a93a2; project package adoption of the virtual placement hook, generalized object/template terrain-class handling, and 0x4a901a weighted continuation remain pending";
	report["direct_minimum_function_address"] = "0x4a8d2c";
	report["weighted_density_function_address"] = "0x4a8db2";
	report["direct_placement_helper_address"] = "0x4a93a2";
	report["direct_validity_precheck_address"] = "0x49a1d8";
	report["direct_eligibility_helper_address"] = "0x49aa93";
	report["weighted_placement_helper_address"] = "0x4a901a";
	report["direct_candidate_scan_basis"] = "0x4a93a2 scans the generated cell buffer for matching cell+0x20 owner byte and then selects the closest eligible cell to the runtime-zone anchor; this report exposes owner-byte/repaint candidates plus the 0x49a1d8 terrain validity precheck, current Town-body 0x49a09c gate order, and post-selection writeout ledger before project package adoption is ported";
	report["direct_random_tie_basis"] = "0x4a93a2 clears the coordinate vector when a smaller squared distance is found, appends every equal-distance eligible coordinate, then calls 0x4e7276 once and selects rng % tied_candidate_count";
	report["direct_validity_precheck_basis"] = "0x49a1d8 requires generated cell bit 25 (byte +0x2b bit 0x02) and terrain id not 9; bit-25 lifecycle is represented here by cells already materialized in the 0x4a325d/0x4a3f27 generated-cell buffer";
	report["direct_footprint_pass_basis"] = "0x49aa93 calls 0x49a09c with object+0x14 footprint offsets, candidate x/y/level, metadata-derived bit22 bypass, object wrapper water class, and require-bit27=0; the clean port applies that gate order to the recovered Town passability body mask";
	report["direct_town_writeout_basis"] = "0x4a93a2 allocates a 0x28-byte object record, calls 0x49ba89, specializes vtable 0x540a9c, writes generator+0xf44 serial to record+0x1c, owner/zone argument to record+0x20, castle byte to record+0x24, calls the generator virtual placement hook, writes selected coordinates back to source_zone+0x30, and marks the anchor cell bit27/clears bit26 when available";
	report["direct_full_eligibility_status"] = "0x49aa93_gate_sequence_recovered_data_dependencies_pending";
	report["direct_full_eligibility_blocked_by"] = "requires object template wrapper/footprint vectors, 0x57c648 object metadata flags, 0x49a6f9 rectangle rejection, 0x49a09c footprint pass, and generated-cell bit 22/object-vector collision state";
	Dictionary object_metadata = h3maped_object_metadata_table_report();
	report["object_metadata_table"] = object_metadata;
	report["object_metadata_table_status"] = object_metadata.get("status", "");
	report["object_metadata_template_binding_status"] = object_metadata.get("template_binding_status", "");
	Array town_template_rows = object_metadata.get("town_template_rows", Array());
	String town_passability_mask;
	String town_action_mask;
	if (!town_template_rows.is_empty() && Variant(town_template_rows[0]).get_type() == Variant::DICTIONARY) {
		Dictionary first_town_template = Dictionary(town_template_rows[0]);
		town_passability_mask = String(first_town_template.get("passability_mask", ""));
		town_action_mask = String(first_town_template.get("action_mask", ""));
	}
	const std::vector<H3MaskPoint> town_body_points = h3_text_mask_points(town_passability_mask, false);
	const std::vector<H3MaskPoint> town_action_points = h3_text_mask_points(town_action_mask, true);
	report["town_footprint_mask_status"] = town_body_points.empty()
			? String("blocked_missing_town_passability_mask")
			: String("0x49a6f9_town_text_mask_body_scan_ported_inspection_only_object_collision_pending");
	report["town_footprint_body_cell_count"] = int32_t(town_body_points.size());
	report["town_footprint_action_cell_count"] = int32_t(town_action_points.size());
	Array full_eligibility_sequence;
	{
		Dictionary step;
		step["address"] = "0x49a6f9";
		step["name"] = "rectangle_or_footprint_reject_precheck";
		step["status"] = "recovered_from_executable_pending_data_model";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x57c648 + type*0x10";
		step["name"] = "object_metadata_secondary_and_wide_flags";
		step["status"] = "recovered_from_executable_pending_template_metadata_binding";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x49a09c";
		step["name"] = "footprint_passability_owner_occupied_and_water_match_scan";
		step["status"] = "recovered_from_executable_pending_footprint_vector_model";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x49a1d8";
		step["name"] = "anchor_validity_precheck_bit25_and_not_terrain9";
		step["status"] = "ported_for_current_generated_cell_grid";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x49ab66..0x49ab81";
		step["name"] = "anchor_owner_byte_matches_runtime_zone";
		step["status"] = "ported_by_owner_byte_candidate_scan";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x49ab87..0x49abb2";
		step["name"] = "bit22_object_collision_metadata_secondary_gate";
		step["status"] = "recovered_from_executable_pending_object_vector_collision_state";
		full_eligibility_sequence.append(step);
	}
	{
		Dictionary step;
		step["address"] = "0x49abb2..0x49abcc";
		step["name"] = "terrain_water_match_against_object_template";
		step["status"] = "recovered_from_executable_pending_object_template_terrain_class";
		full_eligibility_sequence.append(step);
	}
	report["direct_full_eligibility_sequence"] = full_eligibility_sequence;
	report["player_min_towns_offset"] = "source_zone+0x20";
	report["player_min_castles_offset"] = "source_zone+0x24";
	report["player_town_density_offset"] = "source_zone+0x28";
	report["player_castle_density_offset"] = "source_zone+0x2c";
	report["neutral_min_towns_offset"] = "source_zone+0x30";
	report["neutral_min_castles_offset"] = "source_zone+0x34";
	report["neutral_town_density_offset"] = "source_zone+0x38";
	report["neutral_castle_density_offset"] = "source_zone+0x3c";
	report["same_town_type_offset"] = "source_zone+0x40";

	Array runtime_zones = runtime_build.get("runtime_zones", Array());
	Dictionary footprint = runtime_build.get("zone_footprint_placement", Dictionary());
	Dictionary terrain_fill = footprint.get("terrain_fill_repaint", Dictionary());
	const int32_t width = int32_t(terrain_fill.get("width", 0));
	const int32_t height = int32_t(terrain_fill.get("height", 0));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t expected_grid_size = width * height * level_count;
	PackedInt32Array owner_grid = terrain_fill.get("owner_byte_grid_u8", PackedInt32Array());
	PackedInt32Array repaint_grid = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array());
	PackedInt32Array terrain_codes = terrain_fill.get("terrain_code_u16", PackedInt32Array());
	Array terrain_zone_reports = terrain_fill.get("zones", Array());
	std::vector<uint8_t> object_occupied;
	if (expected_grid_size > 0) {
		object_occupied.resize(size_t(expected_grid_size), 0);
	}
	Array minimum_calls;
	Array density_fields;
	Array direct_town_records;
	Array random_tie_events;
	H3MapedRng object_rng { uint32_t(int64_t(runtime_build.get("rng_state_after_runtime_zone_build", 0))) };
	const uint32_t object_rng_state_before = object_rng.state;
	int32_t player_min_town_total = 0;
	int32_t player_min_castle_total = 0;
	int32_t neutral_min_town_total = 0;
	int32_t neutral_min_castle_total = 0;
	int32_t positive_density_field_count = 0;
	int32_t direct_candidate_scan_call_count = 0;
	int32_t direct_candidate_total = 0;
	int32_t direct_candidate_missing_count = 0;
	int32_t direct_owner_minus_one_fail_count = 0;
	int32_t direct_grid_unavailable_count = 0;
	int32_t direct_validity_precheck_call_count = 0;
	int32_t direct_validity_precheck_eligible_total = 0;
	int32_t direct_validity_precheck_missing_count = 0;
	int32_t direct_validity_precheck_grid_unavailable_count = 0;
	int32_t town_footprint_mask_scan_call_count = 0;
	int32_t town_footprint_mask_eligible_total = 0;
	int32_t town_footprint_mask_missing_count = 0;
	int32_t town_footprint_49a09c_pass_total = 0;
	int32_t town_footprint_49a09c_rejected_bounds_count = 0;
	int32_t town_footprint_49a09c_rejected_bit22_count = 0;
	int32_t town_footprint_49a09c_rejected_bit25_count = 0;
	int32_t town_footprint_49a09c_rejected_terrain9_count = 0;
	int32_t town_footprint_49a09c_rejected_water_class_count = 0;
	int32_t town_footprint_49a09c_rejected_owner_count = 0;
	int32_t object_record_stamped_count = 0;
	int32_t object_occupied_cell_mark_count = 0;
	int32_t object_record_random_tie_pending_count = 0;
	int32_t object_record_random_tie_selection_count = 0;
	int32_t object_record_random_tie_rng_call_count = 0;
	int32_t project_town_writeout_record_count = 0;
	int32_t project_town_writeout_generator_f44_next = 0;
	for (int64_t index = 0; index < active_zones.size(); ++index) {
		if (Variant(active_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(active_zones[index]);
		Dictionary runtime = index < runtime_zones.size() && Variant(runtime_zones[index]).get_type() == Variant::DICTIONARY
				? Dictionary(runtime_zones[index])
				: Dictionary();
		const int32_t runtime_zone_index = int32_t(runtime.get("runtime_zone_index", index));
		const int32_t source_zone_id = int32_t(zone.get("source_zone_id", index));
		const int32_t actual_owner_color = int32_t(runtime.get("actual_owner_color", -1));
		const int32_t source_bucket = int32_t(Dictionary(zone.get("grammar_source", Dictionary())).get("source_bucket", -1));
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		Dictionary neutral_towns = zone.get("neutral_towns", Dictionary());
		const int32_t player_min_towns = int32_t(player_towns.get("min_towns", 0));
		const int32_t player_min_castles = int32_t(player_towns.get("min_castles", 0));
		const int32_t neutral_min_towns = int32_t(neutral_towns.get("min_towns", 0));
		const int32_t neutral_min_castles = int32_t(neutral_towns.get("min_castles", 0));
		const int32_t player_town_density = int32_t(player_towns.get("town_density", 0));
		const int32_t player_castle_density = int32_t(player_towns.get("castle_density", 0));
		const int32_t neutral_town_density = int32_t(neutral_towns.get("town_density", 0));
		const int32_t neutral_castle_density = int32_t(neutral_towns.get("castle_density", 0));
		player_min_town_total += player_min_towns;
		player_min_castle_total += player_min_castles;
		neutral_min_town_total += neutral_min_towns;
		neutral_min_castle_total += neutral_min_castles;

		struct MinimumField {
			const char *kind;
			const char *offset;
			int32_t count;
			int32_t owner_color;
			bool castle;
		};
		const MinimumField minimum_fields[] = {
			{ "player_castle", "+0x24", player_min_castles, actual_owner_color, true },
			{ "player_town", "+0x20", player_min_towns, actual_owner_color, false },
			{ "neutral_castle", "+0x34", neutral_min_castles, -1, true },
			{ "neutral_town", "+0x30", neutral_min_towns, -1, false },
		};
		for (const MinimumField &field : minimum_fields) {
			for (int32_t ordinal = 0; ordinal < field.count; ++ordinal) {
				Dictionary call;
				call["phase"] = "0x4a8d2c_direct_minimum";
				call["runtime_zone_index"] = runtime_zone_index;
				call["source_zone_id"] = source_zone_id;
				call["source_bucket"] = source_bucket;
				call["field_kind"] = field.kind;
				call["source_field_offset"] = field.offset;
				call["owner_color"] = field.owner_color;
				call["castle"] = field.castle;
				call["ordinal"] = ordinal;
				call["direct_helper_address"] = "0x4a93a2";
				call["placement_status"] = "pending_0x49aa93_eligibility_random_tie_and_object_cell_materialization";
				call["direct_candidate_scan_status"] = "pending";
				direct_candidate_scan_call_count += 1;
				if (field.owner_color < 0) {
					call["direct_candidate_scan_status"] = "0x4a93a2_immediate_fail_owner_minus_one";
					call["candidate_count"] = 0;
					call["closest_candidate_count"] = 0;
					direct_owner_minus_one_fail_count += 1;
					direct_candidate_missing_count += 1;
					minimum_calls.append(call);
					continue;
				}
				if (width <= 0 || height <= 0 || owner_grid.size() != expected_grid_size || repaint_grid.size() != expected_grid_size || terrain_codes.size() != expected_grid_size) {
					call["direct_candidate_scan_status"] = "blocked_missing_terrain_owner_grid";
					call["candidate_count"] = 0;
					call["closest_candidate_count"] = 0;
					direct_grid_unavailable_count += 1;
					direct_validity_precheck_grid_unavailable_count += 1;
					direct_candidate_missing_count += 1;
					minimum_calls.append(call);
					continue;
				}
				int32_t min_x = 0;
				int32_t min_y = 0;
				int32_t max_x_exclusive = width;
				int32_t max_y_exclusive = height;
				bool bbox_found = false;
				for (int64_t zone_report_index = 0; zone_report_index < terrain_zone_reports.size(); ++zone_report_index) {
					if (Variant(terrain_zone_reports[zone_report_index]).get_type() != Variant::DICTIONARY) {
						continue;
					}
					Dictionary terrain_zone = Dictionary(terrain_zone_reports[zone_report_index]);
					if (int32_t(terrain_zone.get("runtime_zone_index", -1)) != runtime_zone_index) {
						continue;
					}
					min_x = std::clamp(int32_t(terrain_zone.get("bbox_min_x_after_0x4a2105", 0)), 0, width);
					min_y = std::clamp(int32_t(terrain_zone.get("bbox_min_y_after_0x4a2105", 0)), 0, height);
					max_x_exclusive = std::clamp(int32_t(terrain_zone.get("bbox_max_x_after_0x4a2105_exclusive", width)), 0, width);
					max_y_exclusive = std::clamp(int32_t(terrain_zone.get("bbox_max_y_after_0x4a2105_exclusive", height)), 0, height);
					bbox_found = true;
					break;
				}
				const int32_t anchor_x = int32_t(runtime.get("x_after_bbox_rescale", 0));
				const int32_t anchor_y = int32_t(runtime.get("y_after_bbox_rescale", 0));
				int32_t candidate_count = 0;
				int32_t closest_distance = 0x7fffffff;
				int32_t closest_candidate_count = 0;
				int32_t validity_precheck_eligible_count = 0;
				int32_t validity_precheck_rejected_terrain_count = 0;
				int32_t closest_eligible_distance = 0x7fffffff;
				int32_t closest_eligible_candidate_count = 0;
				int32_t footprint_mask_eligible_count = 0;
				int32_t footprint_mask_rejected_bounds_count = 0;
				int32_t footprint_mask_rejected_owner_count = 0;
				int32_t footprint_mask_rejected_terrain_count = 0;
				int32_t footprint_mask_rejected_object_collision_count = 0;
				int32_t footprint_mask_rejected_bit25_count = 0;
				int32_t footprint_mask_rejected_water_class_count = 0;
				int32_t closest_footprint_mask_distance = 0x7fffffff;
				int32_t closest_footprint_mask_candidate_count = 0;
				int32_t selected_footprint_mask_x = -1;
				int32_t selected_footprint_mask_y = -1;
				int32_t selected_footprint_mask_level = -1;
				struct FootprintCandidate {
					int32_t x = -1;
					int32_t y = -1;
					int32_t level = -1;
					int32_t distance = 0;
				};
				std::vector<FootprintCandidate> closest_footprint_candidates;
				Array candidate_preview;
				Array closest_candidate_preview;
				Array eligibility_preview;
				Array closest_eligible_candidate_preview;
				Array footprint_mask_preview;
				Array closest_footprint_mask_candidate_preview;
				for (int32_t level = 0; level < level_count; ++level) {
					for (int32_t y = min_y; y < max_y_exclusive; ++y) {
						for (int32_t x = min_x; x < max_x_exclusive; ++x) {
							const int64_t key = cell_key_4a325d(width, height, x, y, level);
							if (key < 0 || key >= expected_grid_size) {
								continue;
							}
							if (owner_grid[int32_t(key)] != runtime_zone_index || repaint_grid[int32_t(key)] == 0) {
								continue;
							}
							const int32_t terrain_code = terrain_codes[int32_t(key)];
							const bool passes_49a1d8_precheck = terrain_code != 9;
							const int32_t distance = distance_truncate(anchor_x, anchor_y, x, y);
							candidate_count += 1;
							if (candidate_preview.size() < 8) {
								Dictionary candidate;
								candidate["x"] = x;
								candidate["y"] = y;
								candidate["level"] = level;
								candidate["distance_to_runtime_anchor"] = distance;
								candidate["terrain_code_u16"] = terrain_code;
								candidate["passes_0x49a1d8_validity_precheck"] = passes_49a1d8_precheck;
								candidate_preview.append(candidate);
							}
							bool closest_candidate = false;
							if (distance < closest_distance) {
								closest_distance = distance;
								closest_candidate_count = 1;
								closest_candidate_preview.clear();
								closest_candidate = true;
							} else if (distance == closest_distance) {
								closest_candidate_count += 1;
								closest_candidate = true;
							}
							if (closest_candidate && closest_candidate_preview.size() < 8) {
								Dictionary candidate;
								candidate["x"] = x;
								candidate["y"] = y;
								candidate["level"] = level;
								candidate["distance_to_runtime_anchor"] = distance;
								candidate["terrain_code_u16"] = terrain_code;
								candidate["passes_0x49a1d8_validity_precheck"] = passes_49a1d8_precheck;
								closest_candidate_preview.append(candidate);
							}
							if (!passes_49a1d8_precheck) {
								validity_precheck_rejected_terrain_count += 1;
								continue;
							}
							validity_precheck_eligible_count += 1;
							if (eligibility_preview.size() < 8) {
								Dictionary candidate;
								candidate["x"] = x;
								candidate["y"] = y;
								candidate["level"] = level;
								candidate["distance_to_runtime_anchor"] = distance;
								candidate["terrain_code_u16"] = terrain_code;
								eligibility_preview.append(candidate);
							}
							bool footprint_mask_passes = !town_body_points.empty();
							String footprint_reject_reason;
							for (const H3MaskPoint &point : town_body_points) {
								const int32_t body_x = x + point.dx;
								const int32_t body_y = y + point.dy;
								const int64_t body_key = cell_key_4a325d(width, height, body_x, body_y, level);
								if (body_key < 0 || body_key >= expected_grid_size) {
									footprint_mask_passes = false;
									footprint_reject_reason = "out_of_bounds";
									break;
								}
								if (!object_occupied.empty() && object_occupied[size_t(body_key)] != 0) {
									footprint_mask_passes = false;
									footprint_reject_reason = "bit22_object_collision";
									break;
								}
								if (repaint_grid[int32_t(body_key)] == 0) {
									footprint_mask_passes = false;
									footprint_reject_reason = "missing_bit25_materialized_cell";
									break;
								}
								const int32_t body_terrain_code = terrain_codes[int32_t(body_key)] & 0x3f;
								if (body_terrain_code == 9) {
									footprint_mask_passes = false;
									footprint_reject_reason = "terrain_9";
									break;
								}
								const bool body_is_water = body_terrain_code == 8;
								const bool town_template_is_water = false;
								if (body_is_water != town_template_is_water) {
									footprint_mask_passes = false;
									footprint_reject_reason = "water_class_mismatch";
									break;
								}
								if (owner_grid[int32_t(body_key)] != runtime_zone_index) {
									footprint_mask_passes = false;
									footprint_reject_reason = "owner_mismatch";
									break;
								}
							}
							if (footprint_mask_passes) {
								footprint_mask_eligible_count += 1;
								if (footprint_mask_preview.size() < 8) {
									Dictionary candidate;
									candidate["x"] = x;
									candidate["y"] = y;
									candidate["level"] = level;
									candidate["distance_to_runtime_anchor"] = distance;
									candidate["body_cell_count"] = int32_t(town_body_points.size());
									candidate["action_cell_count"] = int32_t(town_action_points.size());
									footprint_mask_preview.append(candidate);
								}
								bool closest_footprint_candidate = false;
								if (distance < closest_footprint_mask_distance) {
									closest_footprint_mask_distance = distance;
									closest_footprint_mask_candidate_count = 1;
									closest_footprint_mask_candidate_preview.clear();
									closest_footprint_candidates.clear();
									selected_footprint_mask_x = x;
									selected_footprint_mask_y = y;
									selected_footprint_mask_level = level;
									closest_footprint_candidate = true;
								} else if (distance == closest_footprint_mask_distance) {
									closest_footprint_mask_candidate_count += 1;
									closest_footprint_candidate = true;
								}
								if (closest_footprint_candidate) {
									FootprintCandidate tied;
									tied.x = x;
									tied.y = y;
									tied.level = level;
									tied.distance = distance;
									closest_footprint_candidates.push_back(tied);
								}
								if (closest_footprint_candidate && closest_footprint_mask_candidate_preview.size() < 8) {
									Dictionary candidate;
									candidate["x"] = x;
									candidate["y"] = y;
									candidate["level"] = level;
									candidate["distance_to_runtime_anchor"] = distance;
									candidate["body_cell_count"] = int32_t(town_body_points.size());
									candidate["action_cell_count"] = int32_t(town_action_points.size());
									closest_footprint_mask_candidate_preview.append(candidate);
								}
							} else if (footprint_reject_reason == "out_of_bounds") {
								footprint_mask_rejected_bounds_count += 1;
							} else if (footprint_reject_reason == "terrain_9") {
								footprint_mask_rejected_terrain_count += 1;
							} else if (footprint_reject_reason == "bit22_object_collision") {
								footprint_mask_rejected_object_collision_count += 1;
							} else if (footprint_reject_reason == "missing_bit25_materialized_cell") {
								footprint_mask_rejected_bit25_count += 1;
							} else if (footprint_reject_reason == "water_class_mismatch") {
								footprint_mask_rejected_water_class_count += 1;
							} else {
								footprint_mask_rejected_owner_count += 1;
							}
							bool closest_eligible_candidate = false;
							if (distance < closest_eligible_distance) {
								closest_eligible_distance = distance;
								closest_eligible_candidate_count = 1;
								closest_eligible_candidate_preview.clear();
								closest_eligible_candidate = true;
							} else if (distance == closest_eligible_distance) {
								closest_eligible_candidate_count += 1;
								closest_eligible_candidate = true;
							}
							if (closest_eligible_candidate && closest_eligible_candidate_preview.size() < 8) {
								Dictionary candidate;
								candidate["x"] = x;
								candidate["y"] = y;
								candidate["level"] = level;
								candidate["distance_to_runtime_anchor"] = distance;
								candidate["terrain_code_u16"] = terrain_code;
								closest_eligible_candidate_preview.append(candidate);
							}
						}
					}
				}
				direct_validity_precheck_call_count += 1;
				town_footprint_mask_scan_call_count += 1;
				call["direct_candidate_scan_status"] = candidate_count > 0
						? String("0x4a93a2_owner_byte_candidate_scan_ported_eligibility_pending")
						: String("0x4a93a2_owner_byte_candidate_scan_no_candidates");
					call["direct_validity_precheck_status"] = validity_precheck_eligible_count > 0
							? String("0x49a1d8_validity_precheck_ported_full_0x49aa93_collision_pending")
							: String("0x49a1d8_validity_precheck_no_eligible_candidates");
					call["direct_full_eligibility_status"] = validity_precheck_eligible_count > 0
							? String("0x49aa93_0x49a09c_town_footprint_pass_ported_project_writeout_pending")
							: String("blocked_no_0x49a1d8_valid_candidates");
				call["candidate_owner_byte"] = runtime_zone_index;
				call["candidate_grid_width"] = width;
				call["candidate_grid_height"] = height;
				call["candidate_grid_level_count"] = level_count;
				call["candidate_bbox_found"] = bbox_found;
				call["candidate_bbox_min_x"] = min_x;
				call["candidate_bbox_min_y"] = min_y;
				call["candidate_bbox_max_x_exclusive"] = max_x_exclusive;
				call["candidate_bbox_max_y_exclusive"] = max_y_exclusive;
				call["runtime_anchor_x"] = anchor_x;
				call["runtime_anchor_y"] = anchor_y;
				call["candidate_count"] = candidate_count;
				call["candidate_preview"] = candidate_preview;
				call["closest_distance"] = candidate_count > 0 ? closest_distance : -1;
				call["closest_candidate_count"] = closest_candidate_count;
				call["closest_candidate_preview"] = closest_candidate_preview;
				call["validity_precheck_eligible_count"] = validity_precheck_eligible_count;
				call["validity_precheck_rejected_terrain_count"] = validity_precheck_rejected_terrain_count;
				call["validity_precheck_eligible_preview"] = eligibility_preview;
				call["closest_eligible_distance"] = validity_precheck_eligible_count > 0 ? closest_eligible_distance : -1;
				call["closest_eligible_candidate_count"] = closest_eligible_candidate_count;
				call["closest_eligible_candidate_preview"] = closest_eligible_candidate_preview;
				call["town_footprint_mask_status"] = footprint_mask_eligible_count > 0
						? String("0x49a6f9_town_text_mask_body_scan_ported_object_collision_pending")
						: String("0x49a6f9_town_text_mask_body_scan_no_eligible_candidates");
					call["town_footprint_body_cell_count"] = int32_t(town_body_points.size());
					call["town_footprint_action_cell_count"] = int32_t(town_action_points.size());
					call["town_footprint_mask_eligible_count"] = footprint_mask_eligible_count;
					call["town_footprint_mask_rejected_bounds_count"] = footprint_mask_rejected_bounds_count;
					call["town_footprint_mask_rejected_owner_count"] = footprint_mask_rejected_owner_count;
					call["town_footprint_mask_rejected_terrain_count"] = footprint_mask_rejected_terrain_count;
					call["town_footprint_mask_rejected_object_collision_count"] = footprint_mask_rejected_object_collision_count;
					call["town_footprint_mask_rejected_bit25_count"] = footprint_mask_rejected_bit25_count;
					call["town_footprint_mask_rejected_water_class_count"] = footprint_mask_rejected_water_class_count;
					call["town_footprint_49a09c_status"] = footprint_mask_eligible_count > 0
							? String("0x49a09c_town_body_offsets_bit22_bit25_water_owner_pass_ported")
							: String("0x49a09c_town_body_offsets_no_eligible_candidates");
					call["town_footprint_mask_preview"] = footprint_mask_preview;
				call["closest_town_footprint_mask_distance"] = footprint_mask_eligible_count > 0 ? closest_footprint_mask_distance : -1;
				call["closest_town_footprint_mask_candidate_count"] = closest_footprint_mask_candidate_count;
				call["closest_town_footprint_mask_candidate_preview"] = closest_footprint_mask_candidate_preview;
				String selection_status;
				String stamping_status;
				bool selected_from_random_tie = false;
				int32_t random_tie_rng_value = -1;
				int32_t random_tie_selected_index = -1;
				if (closest_footprint_candidates.size() > 1) {
					random_tie_rng_value = object_rng.next();
					object_record_random_tie_rng_call_count += 1;
					random_tie_selected_index = random_tie_rng_value % int32_t(closest_footprint_candidates.size());
					const FootprintCandidate &selected = closest_footprint_candidates[size_t(random_tie_selected_index)];
					selected_footprint_mask_x = selected.x;
					selected_footprint_mask_y = selected.y;
					selected_footprint_mask_level = selected.level;
					selected_from_random_tie = true;
					object_record_random_tie_selection_count += 1;
					Dictionary tie_event;
					tie_event["runtime_zone_index"] = runtime_zone_index;
					tie_event["source_zone_id"] = source_zone_id;
					tie_event["field_kind"] = field.kind;
					tie_event["rng_function_address"] = "0x4e7276";
					tie_event["rng_value"] = random_tie_rng_value;
					tie_event["tied_candidate_count"] = int32_t(closest_footprint_candidates.size());
					tie_event["selected_index"] = random_tie_selected_index;
					tie_event["selected_x"] = selected_footprint_mask_x;
					tie_event["selected_y"] = selected_footprint_mask_y;
					tie_event["selected_level"] = selected_footprint_mask_level;
					random_tie_events.append(tie_event);
				}
					if (selected_footprint_mask_x >= 0) {
						const int32_t h3maped_object_serial = project_town_writeout_generator_f44_next;
						project_town_writeout_generator_f44_next += 1;
						int32_t marked_cells = 0;
						Array stamped_body_cells;
					for (const H3MaskPoint &point : town_body_points) {
						const int32_t body_x = selected_footprint_mask_x + point.dx;
						const int32_t body_y = selected_footprint_mask_y + point.dy;
						const int64_t body_key = cell_key_4a325d(width, height, body_x, body_y, selected_footprint_mask_level);
						if (body_key < 0 || body_key >= expected_grid_size || object_occupied.empty()) {
							continue;
						}
						if (object_occupied[size_t(body_key)] == 0) {
							object_occupied[size_t(body_key)] = 1;
							marked_cells += 1;
							if (stamped_body_cells.size() < 16) {
								Dictionary cell;
								cell["x"] = body_x;
								cell["y"] = body_y;
								cell["level"] = selected_footprint_mask_level;
								stamped_body_cells.append(cell);
							}
						}
					}
					object_record_stamped_count += 1;
					object_occupied_cell_mark_count += marked_cells;
					selection_status = selected_from_random_tie
							? String("0x4a93a2_random_tie_town_candidate_selected_and_bit22_body_cells_marked_inspection_only")
							: String("0x4a93a2_unique_town_candidate_selected_and_bit22_body_cells_marked_inspection_only");
					stamping_status = selected_from_random_tie
							? String("0x4a93a2_random_tie_record_and_bit22_body_marking_ported_inspection_only_project_writeout_pending")
							: String("0x4a93a2_record_and_bit22_body_marking_ported_inspection_only_project_writeout_pending");
					call["selected_candidate_status"] = selection_status;
					call["selected_candidate_x"] = selected_footprint_mask_x;
					call["selected_candidate_y"] = selected_footprint_mask_y;
						call["selected_candidate_level"] = selected_footprint_mask_level;
						call["object_record_stamping_status"] = stamping_status;
						call["project_town_writeout_status"] = "0x4a93a2_object_record_writeout_ledger_ported_project_adoption_pending";
						call["h3maped_object_record_size_bytes"] = 0x28;
						call["h3maped_object_record_constructor_address"] = "0x49ba89";
						call["h3maped_object_record_base_vtable_address"] = "0x540a74";
						call["h3maped_town_object_record_vtable_address"] = "0x540a9c";
						call["h3maped_generator_f44_serial_before_increment"] = h3maped_object_serial;
						call["h3maped_record_offset_0x1c_generator_object_index"] = h3maped_object_serial;
						call["h3maped_record_offset_0x20_owner_color"] = field.owner_color;
						call["h3maped_record_offset_0x24_castle_flag"] = field.castle;
						call["h3maped_virtual_placement_call_status"] = "0x4a957d_generator_vtable_plus_0x04_call_recorded_project_hook_pending";
						call["h3maped_source_zone_writeback_status"] = "0x4a9598_source_zone_plus_0x30_coordinate_and_plus_0x3c_flag_write_recorded";
						call["h3maped_anchor_cell_status"] = "0x4a95d1_anchor_bit27_set_bit26_cleared_when_cell_allows";
						call["random_tie_rng_value"] = random_tie_rng_value;
					call["random_tie_selected_index"] = random_tie_selected_index;
					call["random_tie_selected"] = selected_from_random_tie;
					call["object_occupied_cell_mark_count"] = marked_cells;
					call["object_occupied_body_cell_preview"] = stamped_body_cells;
					Dictionary town_record;
					town_record["runtime_zone_index"] = runtime_zone_index;
					town_record["source_zone_id"] = source_zone_id;
					town_record["owner_color"] = field.owner_color;
					town_record["castle"] = field.castle;
					town_record["x"] = selected_footprint_mask_x;
					town_record["y"] = selected_footprint_mask_y;
					town_record["level"] = selected_footprint_mask_level;
					town_record["body_cell_count"] = int32_t(town_body_points.size());
						town_record["marked_body_cell_count"] = marked_cells;
						town_record["h3maped_object_record_size_bytes"] = 0x28;
						town_record["h3maped_object_record_constructor_address"] = "0x49ba89";
						town_record["h3maped_object_record_base_vtable_address"] = "0x540a74";
						town_record["h3maped_town_object_record_vtable_address"] = "0x540a9c";
						town_record["h3maped_generator_f44_serial_before_increment"] = h3maped_object_serial;
						town_record["h3maped_record_offset_0x1c_generator_object_index"] = h3maped_object_serial;
						town_record["h3maped_record_offset_0x20_owner_color"] = field.owner_color;
						town_record["h3maped_record_offset_0x24_castle_flag"] = field.castle;
						town_record["h3maped_virtual_placement_call_status"] = "0x4a957d_generator_vtable_plus_0x04_call_recorded_project_hook_pending";
						town_record["h3maped_source_zone_writeback_status"] = "0x4a9598_source_zone_plus_0x30_coordinate_and_plus_0x3c_flag_write_recorded";
						town_record["h3maped_anchor_cell_status"] = "0x4a95d1_anchor_bit27_set_bit26_cleared_when_cell_allows";
						town_record["selected_from_random_tie"] = selected_from_random_tie;
						town_record["random_tie_rng_value"] = random_tie_rng_value;
						town_record["random_tie_selected_index"] = random_tie_selected_index;
						town_record["status"] = "0x4a93a2_object_record_writeout_ledger_ported_project_adoption_pending";
						direct_town_records.append(town_record);
						project_town_writeout_record_count += 1;
					} else {
					if (closest_footprint_mask_candidate_count > 1) {
						object_record_random_tie_pending_count += 1;
					}
					call["selected_candidate_status"] = closest_footprint_mask_candidate_count > 1
							? String("pending_0x4a93a2_random_tie_selection_before_object_record_stamping")
							: String("blocked_no_0x49a6f9_town_mask_candidates");
					call["object_record_stamping_status"] = "pending_0x4a93a2_random_tie_or_missing_candidate";
					call["object_occupied_cell_mark_count"] = 0;
				}
				direct_candidate_total += candidate_count;
				direct_validity_precheck_eligible_total += validity_precheck_eligible_count;
				town_footprint_mask_eligible_total += footprint_mask_eligible_count;
				town_footprint_49a09c_pass_total += footprint_mask_eligible_count;
				town_footprint_49a09c_rejected_bounds_count += footprint_mask_rejected_bounds_count;
				town_footprint_49a09c_rejected_bit22_count += footprint_mask_rejected_object_collision_count;
				town_footprint_49a09c_rejected_bit25_count += footprint_mask_rejected_bit25_count;
				town_footprint_49a09c_rejected_terrain9_count += footprint_mask_rejected_terrain_count;
				town_footprint_49a09c_rejected_water_class_count += footprint_mask_rejected_water_class_count;
				town_footprint_49a09c_rejected_owner_count += footprint_mask_rejected_owner_count;
				if (candidate_count == 0) {
					direct_candidate_missing_count += 1;
				}
				if (validity_precheck_eligible_count == 0) {
					direct_validity_precheck_missing_count += 1;
				}
				if (footprint_mask_eligible_count == 0) {
					town_footprint_mask_missing_count += 1;
				}
				minimum_calls.append(call);
			}
		}

		struct DensityField {
			const char *kind;
			const char *offset;
			int32_t weight;
			int32_t owner_color;
			bool castle;
		};
		const DensityField density[] = {
			{ "player_town_density", "+0x28", player_town_density, actual_owner_color, false },
			{ "player_castle_density", "+0x2c", player_castle_density, actual_owner_color, true },
			{ "neutral_town_density", "+0x38", neutral_town_density, -1, false },
			{ "neutral_castle_density", "+0x3c", neutral_castle_density, -1, true },
		};
		for (const DensityField &field : density) {
			if (field.weight > 0) {
				positive_density_field_count += 1;
			}
			Dictionary density_record;
			density_record["phase"] = "0x4a8db2_weighted_continuation";
			density_record["runtime_zone_index"] = runtime_zone_index;
			density_record["source_zone_id"] = source_zone_id;
			density_record["source_bucket"] = source_bucket;
			density_record["field_kind"] = field.kind;
			density_record["source_field_offset"] = field.offset;
			density_record["weight"] = field.weight;
			density_record["owner_color"] = field.owner_color;
			density_record["castle"] = field.castle;
			density_record["same_town_type"] = bool(zone.get("same_town_type", false));
			density_record["placement_status"] = field.weight > 0 ? String("pending_0x4a901a_weighted_object_cell_materialization") : String("skipped_zero_density");
			density_fields.append(density_record);
		}
	}

	report["player_min_town_total"] = player_min_town_total;
	report["player_min_castle_total"] = player_min_castle_total;
	report["neutral_min_town_total"] = neutral_min_town_total;
	report["neutral_min_castle_total"] = neutral_min_castle_total;
	report["minimum_settlement_call_count"] = minimum_calls.size();
	report["direct_candidate_scan_call_count"] = direct_candidate_scan_call_count;
	report["direct_candidate_total"] = direct_candidate_total;
	report["direct_candidate_missing_count"] = direct_candidate_missing_count;
	report["direct_owner_minus_one_fail_count"] = direct_owner_minus_one_fail_count;
	report["direct_grid_unavailable_count"] = direct_grid_unavailable_count;
	report["direct_validity_precheck_call_count"] = direct_validity_precheck_call_count;
	report["direct_validity_precheck_eligible_total"] = direct_validity_precheck_eligible_total;
	report["direct_validity_precheck_missing_count"] = direct_validity_precheck_missing_count;
	report["direct_validity_precheck_grid_unavailable_count"] = direct_validity_precheck_grid_unavailable_count;
	report["town_footprint_mask_scan_call_count"] = town_footprint_mask_scan_call_count;
	report["town_footprint_mask_eligible_total"] = town_footprint_mask_eligible_total;
	report["town_footprint_mask_missing_count"] = town_footprint_mask_missing_count;
	report["town_footprint_49a09c_status"] = town_footprint_49a09c_pass_total > 0
			? String("0x49a09c_town_footprint_pass_ported_for_current_generated_cell_grid")
			: String("0x49a09c_town_footprint_pass_no_candidates");
	report["town_footprint_49a09c_pass_total"] = town_footprint_49a09c_pass_total;
	report["town_footprint_49a09c_rejected_bounds_count"] = town_footprint_49a09c_rejected_bounds_count;
	report["town_footprint_49a09c_rejected_bit22_count"] = town_footprint_49a09c_rejected_bit22_count;
	report["town_footprint_49a09c_rejected_bit25_count"] = town_footprint_49a09c_rejected_bit25_count;
	report["town_footprint_49a09c_rejected_terrain9_count"] = town_footprint_49a09c_rejected_terrain9_count;
	report["town_footprint_49a09c_rejected_water_class_count"] = town_footprint_49a09c_rejected_water_class_count;
	report["town_footprint_49a09c_rejected_owner_count"] = town_footprint_49a09c_rejected_owner_count;
	report["object_cell_materialization_status"] = object_record_stamped_count > 0
			? String("0x4a93a2_direct_town_record_random_tie_and_bit22_body_marking_ported_inspection_only")
			: String("pending_0x49aa93_eligibility_random_tie_and_object_template_footprint_port");
	report["object_record_stamped_count"] = object_record_stamped_count;
	report["object_occupied_cell_mark_count"] = object_occupied_cell_mark_count;
	report["object_record_random_tie_pending_count"] = object_record_random_tie_pending_count;
	report["object_record_random_tie_selection_count"] = object_record_random_tie_selection_count;
	report["object_record_random_tie_rng_call_count"] = object_record_random_tie_rng_call_count;
	report["project_town_writeout_status"] = project_town_writeout_record_count > 0
			? String("0x4a93a2_object_record_writeout_ledger_ported_project_adoption_pending")
			: String("0x4a93a2_object_record_writeout_no_selected_records");
	report["project_town_writeout_record_count"] = project_town_writeout_record_count;
	report["project_town_writeout_generator_f44_start"] = 0;
	report["project_town_writeout_generator_f44_next"] = project_town_writeout_generator_f44_next;
	report["project_town_writeout_record_size_bytes"] = 0x28;
	report["project_town_writeout_constructor_address"] = "0x49ba89";
	report["project_town_writeout_base_vtable_address"] = "0x540a74";
	report["project_town_writeout_town_vtable_address"] = "0x540a9c";
	report["project_town_writeout_project_hook_status"] = "generator_virtual_placement_hook_and_package_adoption_pending";
	report["object_rng_state_before_0x4a93a2_uint32"] = int64_t(object_rng_state_before);
	report["object_rng_state_after_0x4a93a2_uint32"] = int64_t(object_rng.state);
	report["random_tie_events"] = random_tie_events;
	report["direct_town_records"] = direct_town_records;
	report["positive_density_field_count"] = positive_density_field_count;
	report["density_field_count"] = density_fields.size();
	report["minimum_calls"] = minimum_calls;
	report["density_fields"] = density_fields;
	return report;
}

Dictionary raw_source_zone_for_active_zone(int32_t source_catalog_index, const Dictionary &active_zone) {
	Dictionary catalog = load_json_dictionary(CATALOG_SOURCE_PATH);
	Array templates = catalog.get("templates", Array());
	if (source_catalog_index < 0 || source_catalog_index >= templates.size() || Variant(templates[source_catalog_index]).get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	Dictionary source_template = Dictionary(templates[source_catalog_index]);
	Array source_zones = source_template.get("zones", Array());
	Dictionary grammar_source = active_zone.get("grammar_source", Dictionary());
	const int32_t source_row = int32_t(grammar_source.get("source_row", -1));
	const int32_t source_zone_id = int32_t(active_zone.get("source_zone_id", -1));
	for (int64_t index = 0; index < source_zones.size(); ++index) {
		if (Variant(source_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = Dictionary(source_zones[index]);
		if ((source_row >= 0 && int32_t(candidate.get("row", -1)) == source_row)
				|| (source_row < 0 && source_zone_id >= 0 && int32_t(candidate.get("id", -1)) == source_zone_id)) {
			return candidate;
		}
	}
	return Dictionary();
}

int32_t dictionary_int(const Dictionary &dictionary, const String &key) {
	return int32_t(dictionary.get(key, 0));
}

int32_t mine_guard_base_value(int32_t subtype) {
	if (subtype == 0 || subtype == 2) {
		return 1500;
	}
	if (subtype == 6) {
		return 7000;
	}
	return 3500;
}

int32_t h3maped_strength_scaled_value_4a65a5(int32_t base_value, int32_t mode) {
	static constexpr int32_t THRESHOLD_1[] = {50000, 2500, 1500, 1000, 500, 0};
	static constexpr int32_t THRESHOLD_2[] = {50000, 7500, 7500, 7500, 5000, 5000};
	static constexpr int32_t SLOPE_1[] = {0, 2, 3, 4, 6, 6};
	static constexpr int32_t SLOPE_2[] = {0, 2, 3, 4, 4, 6};
	const int32_t clamped_mode = std::max(0, std::min(5, mode));
	const int32_t base = std::max(0, base_value);
	int32_t value = 0;
	if (base > THRESHOLD_1[clamped_mode]) {
		value += ((base - THRESHOLD_1[clamped_mode]) * SLOPE_1[clamped_mode]) / 4;
	}
	if (base > THRESHOLD_2[clamped_mode]) {
		value += ((base - THRESHOLD_2[clamped_mode]) * SLOPE_2[clamped_mode]) / 4;
	}
	return value < 2000 ? 0 : value;
}

int32_t h3maped_global_monster_strength_mode(const Dictionary &normalized_config) {
	return std::max(0, std::min(5, int32_t(normalized_config.get("global_monster_strength_mode", 3))));
}

int32_t h3maped_local_monster_strength_mode(const Variant &strength_value) {
	const String token = String(strength_value).to_lower().strip_edges();
	if (token == "0" || token == "n" || token == "none" || token == "no" || token == "none_or_unguarded") {
		return 0;
	}
	if (token == "2" || token == "w" || token == "weak" || token == "core_low") {
		return 2;
	}
	if (token == "4" || token == "s" || token == "strong") {
		return 4;
	}
	if (token == "1") {
		return 1;
	}
	if (token == "5") {
		return 5;
	}
	return 3;
}

int32_t h3maped_effective_monster_strength_mode_4a960a(const Dictionary &normalized_config, const Dictionary &source_zone) {
	const int32_t source_strength = h3maped_local_monster_strength_mode(source_zone.get("monster_strength", "avg"));
	if (source_strength == 0) {
		return 0;
	}
	return std::max(0, std::min(5, source_strength + h3maped_global_monster_strength_mode(normalized_config) - 3));
}

int32_t h3maped_mine_guard_scaled_value_4a960a_4a65a5(const Dictionary &normalized_config, const Dictionary &source_zone, int32_t base_value) {
	const int32_t source_strength = h3maped_local_monster_strength_mode(source_zone.get("monster_strength", "avg"));
	if (source_strength == 0) {
		return 0;
	}
	return h3maped_strength_scaled_value_4a65a5(base_value, h3maped_effective_monster_strength_mode_4a960a(normalized_config, source_zone));
}

bool h3_object_row_matches_runtime_terrain(const H3ObjectRow &row, int32_t h3maped_terrain_id) {
	if (h3maped_terrain_id < 0 || h3maped_terrain_id >= 9 || row.terrain_mask_secondary.length() < 9) {
		return true;
	}
	const int32_t terrain_mask_index = 8 - h3maped_terrain_id;
	return row.terrain_mask_secondary[terrain_mask_index] == '1';
}

std::vector<H3ObjectRow> filtered_h3_object_rows_for_subtype_and_terrain(const std::vector<H3ObjectRow> &rows, int32_t subtype, int32_t h3maped_terrain_id) {
	std::vector<H3ObjectRow> result;
	for (const H3ObjectRow &row : rows) {
		if (row.subtype_id == subtype && h3_object_row_matches_runtime_terrain(row, h3maped_terrain_id)) {
			result.push_back(row);
		}
	}
	return result;
}

int32_t reward_proxy_reference_count() {
	Dictionary catalog = load_json_dictionary(REWARD_PROXY_CATALOG_PATH);
	Array entries = catalog.get("entries", Array());
	int32_t count = 0;
	for (int64_t index = 0; index < entries.size(); ++index) {
		if (Variant(entries[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary entry = Dictionary(entries[index]);
		if (String(entry.get("generated_kind", "")) == "reward_reference") {
			count += 1;
		}
	}
	return count;
}

int32_t reward_proxy_reference_count_for_type_subtype(int32_t type_id, int32_t subtype_id) {
	Dictionary catalog = load_json_dictionary(REWARD_PROXY_CATALOG_PATH);
	Array entries = catalog.get("entries", Array());
	int32_t count = 0;
	for (int64_t index = 0; index < entries.size(); ++index) {
		if (Variant(entries[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary entry = Dictionary(entries[index]);
		if (String(entry.get("generated_kind", "")) != "reward_reference") {
			continue;
		}
		if (int32_t(entry.get("homm3_re_object_type_id", -1)) == type_id && int32_t(entry.get("homm3_re_object_subtype", 0)) == subtype_id) {
			count += 1;
		}
	}
	return count;
}

int32_t h3maped_global_type_limit_5a26e4(int32_t type_id) {
	const std::pair<int32_t, int32_t> overrides[] = {
		{ 26, 200 }, { 6, 200 }, { 57, 48 }, { 8, 64 }, { 100, 32 }, { 23, 32 },
		{ 32, 32 }, { 51, 32 }, { 61, 32 }, { 102, 32 }, { 41, 32 }, { 4, 32 },
		{ 47, 32 }, { 107, 32 }, { 104, 32 }, { 113, 32 }, { 88, 32 }, { 89, 32 },
		{ 90, 32 }, { 92, 32 }, { 55, 32 }, { 109, 32 }, { 112, 32 }, { 48, 32 },
		{ 22, 32 }, { 39, 32 }, { 108, 32 }, { 105, 32 }, { 83, 48 }, { 7, 32 }
	};
	for (const auto &entry : overrides) {
		if (entry.first == type_id) {
			return entry.second;
		}
	}
	return 0x7d00;
}

int32_t h3maped_zone_type_limit_5a2a8c(int32_t type_id) {
	const std::pair<int32_t, int32_t> overrides[] = {
		{ 2, 1 }, { 13, 1 }, { 14, 1 }, { 15, 1 }, { 27, 1 }, { 28, 1 },
		{ 30, 1 }, { 31, 1 }, { 35, 1 }, { 38, 1 }, { 42, 1 }, { 48, 1 },
		{ 49, 1 }, { 56, 1 }, { 58, 1 }, { 60, 1 }, { 64, 1 }, { 80, 1 },
		{ 94, 1 }, { 96, 1 }, { 99, 1 }, { 106, 1 }, { 110, 1 }, { 113, 3 }
	};
	for (const auto &entry : overrides) {
		if (entry.first == type_id) {
			return entry.second;
		}
	}
	return 0x7d00;
}

std::vector<H3MapedRewardCandidate> h3maped_reward_proxy_backed_candidates_49f95a() {
	return {
		{ "0x49fa63", "0x540bd0", 6, 0, 6000, 20, 5000, "Pandora Box value candidate" },
		{ "0x49faa5", "0x540bd0", 6, 0, 12000, 20, 10000, "Pandora Box value candidate" },
		{ "0x49fae7", "0x540bd0", 6, 0, 18000, 20, 15000, "Pandora Box value candidate" },
		{ "0x49fb29", "0x540bd0", 6, 0, 24000, 20, 20000, "Pandora Box value candidate" },
		{ "0x49fb6b", "0x540be0", 6, 0, 5000, 5, 5000, "Pandora Box variant candidate" },
		{ "0x49fbaf", "0x540be0", 6, 0, 10000, 5, 10000, "Pandora Box variant candidate" },
		{ "0x49fbe9", "0x540be0", 6, 0, 15000, 5, 15000, "Pandora Box variant candidate" },
		{ "0x49fc28", "0x540be0", 6, 0, 20000, 5, 20000, "Pandora Box variant candidate" },
		{ "0x4a0150", "0x540ba0", 12, 0, 2000, 500, 0, "Campfire candidate" },
		{ "0x4a026b", "0x540ba0", 16, 0, 3000, 100, 0, "Creature Bank candidate" },
		{ "0x4a02a3", "0x540ba0", 16, 1, 2000, 100, 0, "Creature Bank candidate" },
		{ "0x4a02df", "0x540ba0", 16, 2, 2000, 100, 0, "Creature Bank candidate" },
		{ "0x4a031b", "0x540ba0", 16, 3, 5000, 100, 0, "Creature Bank candidate" },
		{ "0x4a0357", "0x540ba0", 16, 4, 1500, 100, 0, "Creature Bank candidate" },
		{ "0x4a0393", "0x540ba0", 16, 5, 3000, 100, 0, "Creature Bank candidate" },
		{ "0x4a03cf", "0x540ba0", 16, 6, 9000, 100, 0, "Creature Bank candidate" },
		{ "0x4a0b4a", "0x540bb0", 66, 0, 2000, 150, 0, "Random Treasure Artifact candidate" },
		{ "0x4a0b82", "0x540bb0", 67, 0, 5000, 150, 0, "Random Minor Artifact candidate" },
		{ "0x4a0bba", "0x540bb0", 68, 0, 10000, 150, 0, "Random Major Artifact candidate" },
		{ "0x4a0bf2", "0x540bb0", 69, 0, 20000, 150, 0, "Random Relic candidate" },
		{ "0x4a0c2f", "0x540c10", 76, 0, 1500, 2000, 0, "Random Resource candidate" },
		{ "0x4a0ca3", "0x540c10", 79, 0, 1400, 300, 0, "Resource candidate" },
		{ "0x4a0cdb", "0x540c10", 79, 2, 1400, 300, 0, "Resource candidate" },
		{ "0x4a0d17", "0x540c10", 79, 1, 2000, 300, 0, "Resource candidate" },
		{ "0x4a0d53", "0x540c10", 79, 3, 2000, 300, 0, "Resource candidate" },
		{ "0x4a0d8f", "0x540c10", 79, 4, 2000, 300, 0, "Resource candidate" },
		{ "0x4a0dcb", "0x540c10", 79, 5, 2000, 300, 0, "Resource candidate" },
		{ "0x4a0e07", "0x540c10", 79, 6, 750, 300, 0, "Resource candidate" },
		{ "0x4a11a7", "0x540ba0", 84, 0, 1000, 100, 0, "Crypt candidate" },
		{ "0x4a1324", "0x540c90", 93, 0, 500, 30, 1, "Spell Scroll candidate" },
		{ "0x4a134c", "0x540c90", 93, 0, 2000, 30, 2, "Spell Scroll candidate" },
		{ "0x4a137a", "0x540c90", 93, 0, 3000, 30, 3, "Spell Scroll candidate" },
		{ "0x4a13a5", "0x540c90", 93, 0, 4000, 30, 4, "Spell Scroll candidate" },
		{ "0x4a13d0", "0x540c90", 93, 0, 5000, 30, 5, "Spell Scroll candidate" },
		{ "0x4a1515", "0x540ba0", 101, 0, 1500, 1000, 0, "Treasure Chest candidate" },
		{ "0x4a1605", "0x540ba0", 107, 0, 1000, 50, 0, "School of War candidate" }
	};
}

std::vector<H3MapedRewardCandidate> h3maped_reward_direct_field_candidates_49f95a() {
	return {
		{ "0x49f96a", "0x540ba0", 2, 0, 100, 20, 0, "0x49f95a direct field assignment site #000" },
		{ "0x49f9b4", "0x540ba0", 4, 0, 3000, 50, 0, "0x49f95a direct field assignment site #001" },
		{ "0x49fa56", "0x540bd0", 6, 0, 6000, 20, 5000, "0x49f95a direct field assignment site #003" },
		{ "0x49fa9b", "0x540bd0", 6, 0, 12000, 20, 10000, "0x49f95a direct field assignment site #004" },
		{ "0x49fadd", "0x540bd0", 6, 0, 18000, 20, 15000, "0x49f95a direct field assignment site #005" },
		{ "0x49fb1f", "0x540bd0", 6, 0, 24000, 20, 20000, "0x49f95a direct field assignment site #006" },
		{ "0x49fb61", "0x540be0", 6, 0, 5000, 5, 5000, "0x49f95a direct field assignment site #007" },
		{ "0x49fba0", "0x540be0", 6, 0, 10000, 5, 10000, "0x49f95a direct field assignment site #008" },
		{ "0x49fbdf", "0x540be0", 6, 0, 15000, 5, 15000, "0x49f95a direct field assignment site #009" },
		{ "0x49fc1e", "0x540be0", 6, 0, 20000, 5, 20000, "0x49f95a direct field assignment site #010" },
		{ "0x49fc5d", "0x540bf0", 6, 0, 5000, 2, 1, "0x49f95a direct field assignment site #011" },
		{ "0x49fcad", "0x540bf0", 6, 0, 7500, 2, 2, "0x49f95a direct field assignment site #012" },
		{ "0x49fcf4", "0x540bf0", 6, 0, 10000, 2, 3, "0x49f95a direct field assignment site #013" },
		{ "0x49fd3f", "0x540bf0", 6, 0, 12500, 2, 4, "0x49f95a direct field assignment site #014" },
		{ "0x49fd8a", "0x540bf0", 6, 0, 15000, 2, 5, "0x49f95a direct field assignment site #015" },
		{ "0x49fdd5", "0x540bf0", 6, 0, 15000, 2, 1, "0x49f95a direct field assignment site #016" },
		{ "0x49fe20", "0x540bf0", 6, 0, 15000, 2, 1, "0x49f95a direct field assignment site #017" },
		{ "0x49fe6b", "0x540bf0", 6, 0, 15000, 2, 1, "0x49f95a direct field assignment site #018" },
		{ "0x49febb", "0x540bf0", 6, 0, 15000, 2, 1, "0x49f95a direct field assignment site #019" },
		{ "0x49ff0b", "0x540bf0", 6, 0, 30000, 2, 1, "0x49f95a direct field assignment site #020" },
		{ "0x49ffa7", "0x540ca0", 10, 0, 5000, 10, 0, "0x49f95a direct field assignment site #021" },
		{ "0x49ffe1", "0x540ca0", 10, 0, 7500, 10, 0, "0x49f95a direct field assignment site #022" },
		{ "0x4a001b", "0x540ca0", 10, 0, 10000, 10, 0, "0x49f95a direct field assignment site #023" },
		{ "0x4a0055", "0x540ca0", 10, 0, 15000, 10, 0, "0x49f95a direct field assignment site #024" },
		{ "0x4a008f", "0x540ca0", 10, 0, 20000, 10, 0, "0x49f95a direct field assignment site #025" },
		{ "0x4a00ce", "0x540ba0", 7, 0, 8000, 20, 0, "0x49f95a direct field assignment site #026" },
		{ "0x4a0113", "0x540ba0", 11, 0, 100, 100, 0, "0x49f95a direct field assignment site #027" },
		{ "0x4a0146", "0x540ba0", 12, 0, 2000, 500, 0, "0x49f95a direct field assignment site #028" },
		{ "0x4a017e", "0x540ba0", 13, 0, 5000, 20, 0, "0x49f95a direct field assignment site #029" },
		{ "0x4a01b6", "0x540ba0", 13, 1, 10000, 20, 0, "0x49f95a direct field assignment site #030" },
		{ "0x4a01f2", "0x540ba0", 13, 2, 7500, 20, 0, "0x49f95a direct field assignment site #031" },
		{ "0x4a022e", "0x540ba0", 14, 0, 100, 100, 0, "0x49f95a direct field assignment site #032" },
		{ "0x4a0261", "0x540ba0", 16, 0, 3000, 100, 0, "0x49f95a direct field assignment site #033" },
		{ "0x4a0299", "0x540ba0", 16, 1, 2000, 100, 0, "0x49f95a direct field assignment site #034" },
		{ "0x4a02d5", "0x540ba0", 16, 2, 2000, 100, 0, "0x49f95a direct field assignment site #035" },
		{ "0x4a0311", "0x540ba0", 16, 3, 5000, 100, 0, "0x49f95a direct field assignment site #036" },
		{ "0x4a034d", "0x540ba0", 16, 4, 1500, 100, 0, "0x49f95a direct field assignment site #037" },
		{ "0x4a0389", "0x540ba0", 16, 5, 3000, 100, 0, "0x49f95a direct field assignment site #038" },
		{ "0x4a03c5", "0x540ba0", 16, 6, 9000, 100, 0, "0x49f95a direct field assignment site #039" },
		{ "0x4a045c", "0x540ba0", 22, 0, 500, 100, 0, "0x49f95a direct field assignment site #041" },
		{ "0x4a0494", "0x540ba0", 23, 0, 1500, 100, 0, "0x49f95a direct field assignment site #042" },
		{ "0x4a04cc", "0x540ba0", 24, 0, 4000, 20, 0, "0x49f95a direct field assignment site #043" },
		{ "0x4a0504", "0x540ba0", 25, 0, 10000, 100, 0, "0x49f95a direct field assignment site #044" },
		{ "0x4a053c", "0x540ba0", 28, 0, 100, 100, 0, "0x49f95a direct field assignment site #045" },
		{ "0x4a056f", "0x540ba0", 29, 0, 500, 1000, 0, "0x49f95a direct field assignment site #046" },
		{ "0x4a05a7", "0x540ba0", 30, 0, 100, 100, 0, "0x49f95a direct field assignment site #047" },
		{ "0x4a05da", "0x540ba0", 31, 0, 100, 50, 0, "0x49f95a direct field assignment site #048" },
		{ "0x4a0612", "0x540ba0", 32, 0, 1500, 100, 0, "0x49f95a direct field assignment site #049" },
		{ "0x4a064a", "0x540ba0", 35, 0, 7000, 20, 0, "0x49f95a direct field assignment site #050" },
		{ "0x4a0682", "0x540ba0", 38, 0, 100, 100, 0, "0x49f95a direct field assignment site #051" },
		{ "0x4a06b5", "0x540ba0", 39, 0, 500, 100, 0, "0x49f95a direct field assignment site #052" },
		{ "0x4a06ed", "0x540ba0", 41, 0, 12000, 20, 0, "0x49f95a direct field assignment site #053" },
		{ "0x4a0725", "0x540ba0", 47, 0, 1000, 50, 0, "0x49f95a direct field assignment site #054" },
		{ "0x4a075d", "0x540ba0", 48, 0, 500, 50, 0, "0x49f95a direct field assignment site #055" },
		{ "0x4a0795", "0x540ba0", 49, 0, 250, 100, 0, "0x49f95a direct field assignment site #056" },
		{ "0x4a07cd", "0x540ba0", 51, 0, 1500, 100, 0, "0x49f95a direct field assignment site #057" },
		{ "0x4a0805", "0x540ba0", 52, 0, 100, 100, 0, "0x49f95a direct field assignment site #058" },
		{ "0x4a0838", "0x540ba0", 55, 0, 500, 50, 0, "0x49f95a direct field assignment site #059" },
		{ "0x4a0870", "0x540ba0", 56, 0, 100, 50, 0, "0x49f95a direct field assignment site #060" },
		{ "0x4a08a8", "0x540ba0", 57, 0, 3500, 200, 0, "0x49f95a direct field assignment site #061" },
		{ "0x4a08e0", "0x540ba0", 58, 0, 750, 100, 0, "0x49f95a direct field assignment site #062" },
		{ "0x4a0918", "0x540ba0", 60, 0, 750, 100, 0, "0x49f95a direct field assignment site #063" },
		{ "0x4a0950", "0x540ba0", 61, 0, 1500, 100, 0, "0x49f95a direct field assignment site #064" },
		{ "0x4a0988", "0x540c20", 62, 0, 2500, 30, 0, "0x49f95a direct field assignment site #065" },
		{ "0x4a09c7", "0x540c20", 62, 0, 5000, 30, 5000, "0x49f95a direct field assignment site #066" },
		{ "0x4a0a07", "0x540c20", 62, 0, 10000, 30, 15000, "0x49f95a direct field assignment site #067" },
		{ "0x4a0a4a", "0x540c20", 62, 0, 20000, 30, 90000, "0x49f95a direct field assignment site #068" },
		{ "0x4a0a8d", "0x540c20", 62, 0, 30000, 30, 500000, "0x49f95a direct field assignment site #069" },
		{ "0x4a0ad0", "0x540ba0", 63, 0, 5000, 20, 0, "0x49f95a direct field assignment site #070" },
		{ "0x4a0b08", "0x540ba0", 64, 0, 100, 100, 0, "0x49f95a direct field assignment site #071" },
		{ "0x4a0b3b", "0x540bb0", 66, 0, 2000, 150, 0, "0x49f95a direct field assignment site #072" },
		{ "0x4a0b78", "0x540bb0", 67, 0, 5000, 150, 0, "0x49f95a direct field assignment site #073" },
		{ "0x4a0bb0", "0x540bb0", 68, 0, 10000, 150, 0, "0x49f95a direct field assignment site #074" },
		{ "0x4a0be8", "0x540bb0", 69, 0, 20000, 150, 0, "0x49f95a direct field assignment site #075" },
		{ "0x4a0c20", "0x540c10", 76, 0, 1500, 2000, 0, "0x49f95a direct field assignment site #076" },
		{ "0x4a0c5d", "0x540ba0", 78, 0, 5000, 20, 0, "0x49f95a direct field assignment site #077" },
		{ "0x4a0c99", "0x540c10", 79, 0, 1400, 300, 0, "0x49f95a direct field assignment site #078" },
		{ "0x4a0cd1", "0x540c10", 79, 2, 1400, 300, 0, "0x49f95a direct field assignment site #079" },
		{ "0x4a0d0d", "0x540c10", 79, 1, 2000, 300, 0, "0x49f95a direct field assignment site #080" },
		{ "0x4a0d49", "0x540c10", 79, 3, 2000, 300, 0, "0x49f95a direct field assignment site #081" },
		{ "0x4a0d85", "0x540c10", 79, 4, 2000, 300, 0, "0x49f95a direct field assignment site #082" },
		{ "0x4a0dc1", "0x540c10", 79, 5, 2000, 300, 0, "0x49f95a direct field assignment site #083" },
		{ "0x4a0dfd", "0x540c10", 79, 6, 750, 300, 0, "0x49f95a direct field assignment site #084" },
		{ "0x4a0e39", "0x540ba0", 80, 0, 100, 50, 0, "0x49f95a direct field assignment site #085" },
		{ "0x4a0e75", "0x540c30", 81, 0, 1500, 100, 0, "0x49f95a direct field assignment site #086" },
		{ "0x4a0eb1", "0x540ba0", 82, 0, 1500, 500, 0, "0x49f95a direct field assignment site #087" },
		{ "0x4a0f90", "0x540c70", 83, 0, 2000, 10, 5000, "0x49f95a direct field assignment site #089" },
		{ "0x4a0fd0", "0x540c70", 83, 0, 5333, 10, 10000, "0x49f95a direct field assignment site #090" },
		{ "0x4a1010", "0x540c70", 83, 0, 8666, 10, 15000, "0x49f95a direct field assignment site #091" },
		{ "0x4a1050", "0x540c70", 83, 0, 12000, 10, 20000, "0x49f95a direct field assignment site #092" },
		{ "0x4a1090", "0x540c80", 83, 0, 2000, 10, 5000, "0x49f95a direct field assignment site #093" },
		{ "0x4a10d0", "0x540c80", 83, 0, 5333, 10, 10000, "0x49f95a direct field assignment site #094" },
		{ "0x4a1110", "0x540c80", 83, 0, 8666, 10, 15000, "0x49f95a direct field assignment site #095" },
		{ "0x4a1150", "0x540c80", 83, 0, 12000, 10, 20000, "0x49f95a direct field assignment site #096" },
		{ "0x4a1196", "0x540ba0", 84, 0, 1000, 100, 0, "0x49f95a direct field assignment site #097" },
		{ "0x4a11d9", "0x540ba0", 85, 0, 2000, 100, 0, "0x49f95a direct field assignment site #098" },
		{ "0x4a1218", "0x540ba0", 86, 0, 1500, 50, 0, "0x49f95a direct field assignment site #099" },
		{ "0x4a1253", "0x540c40", 88, 0, 500, 100, 0, "0x49f95a direct field assignment site #100" }
	};
}

std::vector<H3MapedRewardCandidate> h3maped_reward_literal_constructor_candidates_49f95a() {
	return {
		{ "0x4a128f", "0x540c40", 89, 0, 2000, 100, 0, "0x49f95a literal constructor site #101 via 0x49c9bf" },
		{ "0x4a12b7", "0x540c40", 90, 0, 3000, 100, 0, "0x49f95a literal constructor site #102 via 0x49c9bf" },
		{ "0x4a12e3", "0x540ba0", 92, 0, 100, 20, 0, "0x49f95a literal constructor site #103 via 0x49c523" },
		{ "0x4a1311", "0x540c90", 93, 0, 500, 30, 1, "0x49f95a literal constructor site #104 via 0x49ccc1" },
		{ "0x4a133d", "0x540c90", 93, 0, 2000, 30, 2, "0x49f95a literal constructor site #105 via 0x49ccc1" },
		{ "0x4a1367", "0x540c90", 93, 0, 3000, 30, 3, "0x49f95a literal constructor site #106 via 0x49ccc1" },
		{ "0x4a1392", "0x540c90", 93, 0, 4000, 30, 4, "0x49f95a literal constructor site #107 via 0x49ccc1" },
		{ "0x4a13bd", "0x540c90", 93, 0, 5000, 30, 5, "0x49f95a literal constructor site #108 via 0x49ccc1" },
		{ "0x4a13eb", "0x540ba0", 94, 0, 200, 40, 0, "0x49f95a literal constructor site #109 via 0x49c523" },
		{ "0x4a141a", "0x540ba0", 95, 0, 100, 20, 0, "0x49f95a literal constructor site #110 via 0x49c523" },
		{ "0x4a144a", "0x540ba0", 96, 0, 100, 100, 0, "0x49f95a literal constructor site #111 via 0x49c523" },
		{ "0x4a1474", "0x540ba0", 97, 0, 100, 100, 0, "0x49f95a literal constructor site #112 via 0x49c523" },
		{ "0x4a149e", "0x540ba0", 99, 0, 100, 100, 0, "0x49f95a literal constructor site #113 via 0x49c523" },
		{ "0x4a14c8", "0x540ba0", 100, 0, 1500, 200, 0, "0x49f95a literal constructor site #114 via 0x49c523" },
		{ "0x4a1500", "0x540ba0", 101, 0, 1500, 1000, 0, "0x49f95a literal constructor site #115 via 0x49c523" },
		{ "0x4a152f", "0x540ba0", 102, 0, 2500, 50, 0, "0x49f95a literal constructor site #116 via 0x49c523" },
		{ "0x4a1565", "0x540ba0", 104, 0, 2500, 20, 0, "0x49f95a literal constructor site #117 via 0x49c523" },
		{ "0x4a1591", "0x540ba0", 105, 0, 500, 50, 0, "0x49f95a literal constructor site #118 via 0x49c523" },
		{ "0x4a15c1", "0x540ba0", 106, 0, 1500, 50, 0, "0x49f95a literal constructor site #119 via 0x49c523" },
		{ "0x4a15ef", "0x540ba0", 107, 0, 1000, 50, 0, "0x49f95a literal constructor site #120 via 0x49c523" },
		{ "0x4a161e", "0x540ba0", 108, 0, 6000, 20, 0, "0x49f95a literal constructor site #121 via 0x49c523" },
		{ "0x4a164c", "0x540ba0", 109, 0, 750, 50, 0, "0x49f95a literal constructor site #122 via 0x49c523" },
		{ "0x4a167b", "0x540ba0", 110, 0, 500, 50, 0, "0x49f95a literal constructor site #123 via 0x49c523" },
		{ "0x4a16aa", "0x540ba0", 112, 0, 2500, 150, 0, "0x49f95a literal constructor site #124 via 0x49c523" },
		{ "0x4a16d8", "0x540c50", 113, 0, 1500, 80, 0, "0x49f95a literal constructor site #125 via 0x49ca26" },
	};
}

std::vector<H3MapedRewardCandidate> h3maped_reward_materialized_candidates_49f95a() {
	std::vector<H3MapedRewardCandidate> candidates = h3maped_reward_direct_field_candidates_49f95a();
	const std::vector<H3MapedRewardCandidate> literal_constructor_candidates = h3maped_reward_literal_constructor_candidates_49f95a();
	candidates.insert(candidates.end(), literal_constructor_candidates.begin(), literal_constructor_candidates.end());
	return candidates;
}

Array h3maped_reward_dynamic_constructor_sites_49f95a() {
	Array sites;
	{
		Dictionary site;
		site["allocation_site_address"] = "0x49fa1d";
		site["constructor_call_address"] = "0x49fa2a";
		site["constructor_address"] = "0x49c5cd";
		site["vtable_address"] = "0x540bc0";
		site["value_virtual_address"] = "0x49c64b";
		site["type_source"] = "constructor sets type 6";
		site["value_source"] = "dynamic creature-table ratio from 0x581298 and generator resource totals";
		site["status"] = "dynamic_value_formula_ported_runtime_creature_table_pending";
		sites.append(site);
	}
	{
		Dictionary site;
		site["allocation_site_address"] = "0x4a0422";
		site["constructor_call_address"] = "0x4a043a";
		site["constructor_address"] = "0x49c523";
		site["vtable_address"] = "0x540c00";
		site["value_virtual_address"] = "0x49c849";
		site["type_source"] = "constructor receives type 17 with loop-derived subtype";
		site["value_source"] = "dynamic creature table value from 0x531cc4, 0x581298, and generator resource totals";
		site["status"] = "dynamic_value_formula_ported_runtime_creature_table_pending";
		sites.append(site);
	}
	{
		Dictionary site;
		site["allocation_site_address"] = "0x4a0f42";
		site["constructor_call_address"] = "0x4a0f54";
		site["constructor_address"] = "0x49c5cd";
		site["vtable_address"] = "0x540c60";
		site["value_virtual_address"] = "0x49ca8b";
		site["type_source"] = "constructor patched to type 83 with loop-derived subtype";
		site["value_source"] = "dynamic generator state calculation via 0x49c64b";
		site["status"] = "dynamic_value_formula_ported_runtime_creature_table_pending";
		sites.append(site);
	}
	return sites;
}

Array h3maped_reward_dynamic_record_skeletons_49f95a(const Dictionary &normalized_config) {
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const bool two_level_branch = level_count > 1;
	const int32_t creature_loop_limit = two_level_branch ? 0x91 : 0x76;
	const int32_t type17_loop_limit = two_level_branch ? 0x50 : 0x3a;
	Array skeletons;
	{
		Dictionary skeleton;
		skeleton["constructor_call_address"] = "0x49fa2a";
		skeleton["insert_helper_address"] = "0x42d8d8";
		skeleton["vtable_address"] = "0x540bc0";
		skeleton["value_virtual_address"] = "0x49c64b";
		skeleton["type_id"] = 6;
		skeleton["subtype_source"] = "creature_table_index";
		skeleton["weight"] = 3;
		skeleton["loop_order"] = "descending creature index";
		skeleton["loop_slot_count_for_current_level_mode"] = creature_loop_limit;
		skeleton["materialization_condition"] = "creature_row+0x04 >= 0 from runtime table pointer 0x581298";
		skeleton["known_unconditional_record_count"] = 0;
		skeleton["record_count_status"] = "runtime_creature_table_pending";
		skeletons.append(skeleton);
	}
	{
		Dictionary skeleton;
		skeleton["constructor_call_address"] = "0x4a043a";
		skeleton["insert_helper_address"] = "0x40bb26";
		skeleton["vtable_address"] = "0x540c00";
		skeleton["value_virtual_address"] = "0x49c849";
		skeleton["type_id"] = 17;
		skeleton["subtype_source"] = "loop index";
		skeleton["weight"] = 0x28;
		skeleton["loop_order"] = "descending subtype index";
		skeleton["loop_slot_count_for_current_level_mode"] = type17_loop_limit;
		skeleton["materialization_condition"] = "unconditional";
		skeleton["known_unconditional_record_count"] = type17_loop_limit;
		skeleton["record_count_status"] = "skeleton_materialized_value_runtime_tables_pending";
		skeletons.append(skeleton);
	}
	{
		Dictionary skeleton;
		skeleton["constructor_call_address"] = "0x4a0f54";
		skeleton["insert_helper_address"] = "0x40bb26";
		skeleton["vtable_address"] = "0x540c60";
		skeleton["value_virtual_address"] = "0x49ca8b";
		skeleton["type_id"] = 83;
		skeleton["subtype_source"] = "generator+0x568 vector index";
		skeleton["weight"] = 3;
		skeleton["loop_order"] = "outer generator+0x568 vector, descending creature index";
		skeleton["loop_slot_count_for_current_level_mode_per_outer_record"] = creature_loop_limit;
		skeleton["materialization_condition"] = "generator+0x568 vector count and creature_row+0x04 >= 0 from runtime table pointer 0x581298";
		skeleton["known_unconditional_record_count"] = 0;
		skeleton["record_count_status"] = "generator_vector_and_runtime_creature_table_pending";
		skeletons.append(skeleton);
	}
	return skeletons;
}

Dictionary h3maped_reward_dynamic_value_functions_49f95a_report(const Dictionary &normalized_config) {
	Dictionary report;
	report["source_binary_path"] = BINARY_PATH;
	report["creature_table_pointer_address"] = "0x581298";
	report["creature_table_runtime_pointer_initial_value_address"] = "0x57cea0";
	report["creature_table_loader_address"] = "0x40ce11";
	report["creature_table_loader_stride_bytes"] = 0x74;
	report["creature_table_loader_static_storage_base_address"] = "0x57cea0";
	report["creature_table_loader_source_vector_offset"] = "loader_object+0x20";
	report["creature_table_loader_source_row_pointer_offset"] = "source_row+0x04";
	report["creature_table_loader_string_dest_offsets"] = Array::make("+0x14", "+0x18", "+0x1c");
	report["creature_table_loader_numeric_copy_source_range"] = "source_row+0x08..+0x58";
	report["creature_table_loader_numeric_copy_dest_range"] = "creature_row+0x20..+0x70";
	report["creature_table_loader_cleanup_helpers"] = Array::make("0x40d0b6", "0x40d09f", "0x40d088");
	report["creature_value_table_address"] = "0x58dc08";
	report["creature_remap_table_address"] = "0x531cc4";
	report["generator_resource_total_offset"] = "generator+0xf60";
	report["generator_resource_by_owner_offset"] = "generator+0xf64+owner*4";
	report["runtime_zone_owner_offset"] = "zone_record+0x08";
	report["runtime_generation_state_offset"] = "generator+0xf58";
	report["runtime_generation_suppression_byte_offset"] = "generator+0x10b4";
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const bool two_level_branch = level_count > 1;
	report["level_count"] = level_count;
	report["generator_plus_0x08_modeled_as_two_level_flag"] = two_level_branch ? 1 : 0;
	report["0x49fa2a_creature_loop_limit"] = two_level_branch ? 0x91 : 0x76;
	report["0x4a043a_type17_loop_limit"] = two_level_branch ? 0x50 : 0x3a;
	report["0x4a0f54_outer_vector_source"] = "generator+0x568..generator+0x56c";
	report["0x4a0f54_inner_creature_loop_limit"] = two_level_branch ? 0x91 : 0x76;
	Array functions;
	{
		Dictionary function;
		function["address"] = "0x49c64b";
		function["candidate_vtable"] = "0x540bc0";
		function["used_by_constructor_site"] = "0x49fa2a";
		function["formula"] = "if creature_row+0x00 != zone_record+0x08 return -1; base=(creature_row+0x40)*(candidate+0x18); if owner!=-1 and generator+0xf60>0 add ((generator+0xf64+owner*4)*base)/(generator+0xf60)";
		function["runtime_data_dependency"] = "creature table loaded at runtime through pointer 0x581298; generator resource totals from active generation state";
		functions.append(function);
	}
	{
		Dictionary function;
		function["address"] = "0x49c849";
		function["candidate_vtable"] = "0x540c00";
		function["used_by_constructor_site"] = "0x4a043a";
		function["formula"] = "creature_index=table_0x531cc4[candidate+0x08]; if creature_row+0x00 != zone_record+0x08 return -1; scaled=(creature_row+0x44)*(creature_row+0x40); if generator+0xf60>0 add ((generator+0xf64+owner*4)*scaled)/(generator+0xf60); return scaled + trunc(((creature_row+0x40)*(generator+0xf64+owner*4))/2)";
		function["runtime_data_dependency"] = "creature remap table 0x531cc4 plus runtime creature table pointer 0x581298 and generator resource totals";
		functions.append(function);
	}
	{
		Dictionary function;
		function["address"] = "0x49ca8b";
		function["candidate_vtable"] = "0x540c60";
		function["used_by_constructor_site"] = "0x4a0f54";
		function["formula"] = "if generator+0xf58 != candidate+0x08 or byte(generator+0x10b4)!=0 return -1; return ((2 * value_0x49c64b(candidate, zone, generator)) - 0xfa0) / 3";
		function["runtime_data_dependency"] = "delegates to 0x49c64b and additionally depends on generator+0xf58 and generator+0x10b4";
		functions.append(function);
	}
	report["functions"] = functions;
	report["ported_formula_count"] = functions.size();
	report["dynamic_constructor_site_count"] = h3maped_reward_dynamic_constructor_sites_49f95a().size();
	Array dynamic_skeletons = h3maped_reward_dynamic_record_skeletons_49f95a(normalized_config);
	report["dynamic_record_skeletons"] = dynamic_skeletons;
	int32_t known_unconditional_dynamic_record_count = 0;
	for (int64_t index = 0; index < dynamic_skeletons.size(); ++index) {
		if (Variant(dynamic_skeletons[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		known_unconditional_dynamic_record_count += int32_t(Dictionary(dynamic_skeletons[index]).get("known_unconditional_record_count", 0));
	}
	report["known_unconditional_dynamic_record_count"] = known_unconditional_dynamic_record_count;
	report["scan_ready_dynamic_record_count"] = 0;
	report["candidate_expansion_status"] = "runtime_candidate_records_not_materialized_until_creature_table_and_generator_plus_0x568_vector_are_ported";
	report["status"] = "0x49c64b_0x49c849_0x49ca8b_dynamic_value_formulas_ported_runtime_tables_pending";
	return report;
}

Dictionary reward_vector_construction_49f95a_report() {
	Dictionary report;
	report["function_address"] = "0x49f95a";
	report["function_end_address"] = "0x4a1700";
	report["source_binary_path"] = BINARY_PATH;
	report["generator_candidate_vector_object_offset"] = "generator+0x10f0";
	report["generator_candidate_vector_begin_offset"] = "generator+0x10f4";
	report["generator_candidate_vector_end_offset"] = "generator+0x10f8";
	report["allocator_function_address"] = "0x5044b1";
	report["static_insert_site_count"] = 126;
	report["static_insert_helper_42d8d8_count"] = 27;
	report["static_insert_helper_40bb26_count"] = 99;
	report["direct_field_assignment_site_count"] = 98;
	report["constructor_49c523_site_count"] = 18;
	report["constructor_49ccc1_site_count"] = 5;
	report["constructor_49c5cd_site_count"] = 2;
	report["constructor_49c9bf_site_count"] = 2;
	report["constructor_49ca26_site_count"] = 1;
	report["current_proxy_backed_materialized_record_count"] = int32_t(h3maped_reward_proxy_backed_candidates_49f95a().size());
	report["current_direct_field_materialized_record_count"] = int32_t(h3maped_reward_direct_field_candidates_49f95a().size());
	report["current_literal_constructor_materialized_record_count"] = int32_t(h3maped_reward_literal_constructor_candidates_49f95a().size());
	report["current_materialized_record_count"] = int32_t(h3maped_reward_materialized_candidates_49f95a().size());
	report["dynamic_constructor_site_pending_count"] = h3maped_reward_dynamic_constructor_sites_49f95a().size();
	report["dynamic_constructor_sites"] = h3maped_reward_dynamic_constructor_sites_49f95a();
	report["uncovered_static_insert_site_count"] = int32_t(report["static_insert_site_count"]) - int32_t(report["current_materialized_record_count"]);
	report["dynamic_value_function_recovery_status"] = "0x49c64b_0x49c849_0x49ca8b_formulas_ported_runtime_tables_pending";
	report["recovery_status"] = "0x49f95a_direct_and_literal_constructor_records_materialized_dynamic_record_expansion_pending";
	report["weighted_selection_gate"] = "blocked_until_complete_generator_plus_0x10f4_vector_parity";
	return report;
}

Dictionary reward_candidate_scan_4a9f1c_report(int32_t min_value, int32_t max_value, bool skip_metadata_gate, bool skip_visited_gate) {
	Dictionary scan;
	scan["phase"] = "0x4a9f1c_reward_candidate_scan";
	scan["function_address"] = "0x4a9f1c";
	scan["generator_candidate_vector_begin_offset"] = "generator+0x10f4";
	scan["generator_candidate_vector_end_offset"] = "generator+0x10f8";
	scan["candidate_vector_constructor_address"] = "0x49f95a";
	scan["candidate_vector_scope"] = "direct_field_and_literal_constructor_records_recovered_from_0x49f95a";
	scan["complete_generator_candidate_vector_materialized"] = false;
	scan["object_type_source_offset"] = "candidate+0x04";
	scan["object_subtype_source_offset"] = "candidate+0x08";
	scan["object_value_virtual_slot"] = "candidate_vtable+0x04";
	scan["object_visited_virtual_slot"] = "candidate_vtable+0x08";
	scan["candidate_weight_offset"] = "candidate+0x10";
	scan["type_metadata_table_pointer_address"] = "0x57c648";
	scan["type_metadata_stride_bytes"] = 0x10;
	scan["type_metadata_byte_0_gate"] = "skip nonzero byte0 with byte2 zero when skip-metadata flag is false";
	scan["global_type_count_table_address"] = "0x5a26e4";
	scan["zone_type_count_table_address"] = "0x5a2a8c";
	scan["generator_type_count_offset"] = "generator+0x1110+type*4";
	scan["zone_type_count_offset"] = "zone_record+0x44+type*4";
	scan["value_range_min"] = min_value;
	scan["value_range_max"] = max_value;
	scan["resource_helper_address"] = "0x4a9e40";
	scan["footprint_probe_helper_address"] = "0x49a6f9";
	scan["optional_coverage_ratio_helper_address"] = "0x4aa195";
	scan["weighted_selection_rng_address"] = "0x4e7276";
	scan["skip_metadata_gate"] = skip_metadata_gate;
	scan["skip_visited_gate"] = skip_visited_gate;
	scan["native_proxy_catalog_path"] = REWARD_PROXY_CATALOG_PATH;
	scan["native_proxy_inventory_reward_reference_count"] = reward_proxy_reference_count();

	const std::vector<H3MapedRewardCandidate> candidates = h3maped_reward_materialized_candidates_49f95a();
	Dictionary vector_construction = reward_vector_construction_49f95a_report();
	scan["candidate_vector_static_construction_summary"] = vector_construction;
	scan["candidate_vector_static_insert_site_count"] = int32_t(vector_construction.get("static_insert_site_count", 0));
	scan["candidate_vector_current_static_site_coverage_count"] = int32_t(candidates.size());
	scan["candidate_vector_uncovered_static_site_count"] = int32_t(vector_construction.get("uncovered_static_insert_site_count", 0));
	Array eligible_preview;
	int32_t eligible_count = 0;
	int32_t total_weight = 0;
	int32_t rejected_value_count = 0;
	int32_t rejected_proxy_mapping_count = 0;
	int32_t rejected_limit_count = 0;
	for (const H3MapedRewardCandidate &candidate_record : candidates) {
		const int32_t global_limit = h3maped_global_type_limit_5a26e4(candidate_record.type_id);
		const int32_t zone_limit = h3maped_zone_type_limit_5a2a8c(candidate_record.type_id);
		const bool limit_pass = global_limit > 0 && zone_limit > 0;
		if (!limit_pass) {
			rejected_limit_count += 1;
			continue;
		}
		if (candidate_record.value < min_value || candidate_record.value > max_value) {
			rejected_value_count += 1;
			continue;
		}
		const int32_t proxy_match_count = reward_proxy_reference_count_for_type_subtype(candidate_record.type_id, candidate_record.subtype_id);
		if (proxy_match_count <= 0) {
			rejected_proxy_mapping_count += 1;
			continue;
		}
		eligible_count += 1;
		total_weight += candidate_record.weight;
		if (eligible_preview.size() < 12) {
			Dictionary candidate;
			candidate["constructor_address"] = candidate_record.constructor_address;
			candidate["vtable_address"] = candidate_record.vtable_address;
			candidate["type_id"] = candidate_record.type_id;
			candidate["type_name"] = object_type_name_from_names_file(candidate_record.type_id);
			candidate["subtype_id"] = candidate_record.subtype_id;
			candidate["value"] = candidate_record.value;
			candidate["weight"] = candidate_record.weight;
			candidate["extra_0x14"] = candidate_record.extra_0x14;
			candidate["global_type_limit_5a26e4"] = global_limit;
			candidate["zone_type_limit_5a2a8c"] = zone_limit;
			candidate["native_proxy_match_count"] = proxy_match_count;
			candidate["source_note"] = candidate_record.source_note;
			eligible_preview.append(candidate);
		}
	}

	scan["candidate_vector_record_count"] = int32_t(candidates.size());
	scan["eligible_candidate_count"] = eligible_count;
	scan["eligible_candidate_weight_total"] = total_weight;
	scan["rejected_value_range_count"] = rejected_value_count;
	scan["rejected_native_proxy_mapping_count"] = rejected_proxy_mapping_count;
	scan["rejected_type_limit_count"] = rejected_limit_count;
	scan["eligible_candidate_preview"] = eligible_preview;
	scan["native_proxy_candidate_scan_materialized"] = true;
	scan["native_proxy_weighted_selection_materialized"] = false;
	scan["native_proxy_candidate_execution_materialized"] = false;
	scan["status"] = "0x4a9f1c_materialized_candidate_scan_dynamic_value_sites_pending";
	return scan;
}

std::vector<uint8_t> occupied_grid_from_town_records(const Dictionary &town_castle_placement, int32_t width, int32_t height, int32_t level_count) {
	std::vector<uint8_t> occupied;
	const int32_t expected_grid_size = width * height * level_count;
	if (expected_grid_size <= 0) {
		return occupied;
	}
	occupied.resize(size_t(expected_grid_size), 0);
	Dictionary object_metadata = town_castle_placement.get("object_metadata_table", Dictionary());
	Array town_template_rows = object_metadata.get("town_template_rows", Array());
	if (town_template_rows.is_empty() || Variant(town_template_rows[0]).get_type() != Variant::DICTIONARY) {
		return occupied;
	}
	Dictionary first_town_template = Dictionary(town_template_rows[0]);
	const std::vector<H3MaskPoint> town_body_points = h3_text_mask_points(String(first_town_template.get("passability_mask", "")), false);
	Array town_records = town_castle_placement.get("direct_town_records", Array());
	for (int64_t record_index = 0; record_index < town_records.size(); ++record_index) {
		if (Variant(town_records[record_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary record = Dictionary(town_records[record_index]);
		const int32_t anchor_x = int32_t(record.get("x", -1));
		const int32_t anchor_y = int32_t(record.get("y", -1));
		const int32_t level = int32_t(record.get("level", 0));
		for (const H3MaskPoint &point : town_body_points) {
			const int64_t key = cell_key_4a325d(width, height, anchor_x + point.dx, anchor_y + point.dy, level);
			if (key >= 0 && key < expected_grid_size) {
				occupied[size_t(key)] = 1;
			}
		}
	}
	return occupied;
}

Dictionary mine_reward_placement_4a9d6a_4aab7e_report(const Array &active_zones, int32_t source_catalog_index, const Dictionary &runtime_build, const Dictionary &town_castle_placement, const Dictionary &normalized_config) {
	Dictionary report;
	report["status"] = "0x4a9d6a_0x4a9911_0x4a9641_0x4aab7e_0x4aa354_value_selection_ported_package_adoption_pending";
	report["source"] = "h3maped phase 7 0x4a9d6a mine minimum/density fields, 0x4a9911 mine template bucket selection/record/guard handoff, 0x4a9641 mine placement constraint candidate scan, phase 10 0x4aab7e treasure-band scheduler, and 0x4aa354 reward value selection rebound from recovered rmg-template-catalog and objects.txt source rows; package adoption, 0x4aa1db reward object lookup, and guarding remain pending";
	report["mine_phase_address"] = "0x4a9d6a";
	report["mine_minimum_helper_address"] = "0x4a9911";
	report["mine_density_scheduler_address"] = "0x4a9c7c";
	report["mine_record_constructor_address"] = "0x49ba89";
	report["mine_object_record_size_bytes"] = 0x1c;
	report["mine_object_record_vtable_address"] = "0x540ab0";
	report["mine_placement_constraint_helper_address"] = "0x4a9641";
	report["mine_guard_adjustment_helpers"] = "0x4a960a -> 0x4a65a5";
	report["mine_adjacent_resource_helper_address"] = "0x4a9e40";
	report["treasure_phase_address"] = "0x4aab7e";
	report["treasure_helper_address"] = "0x4aa354";
	report["source_catalog_path"] = CATALOG_SOURCE_PATH;
	report["source_catalog_index_zero_based"] = source_catalog_index;
	report["source_binding_status"] = "recovered_source_rows_bound_by_grammar_source_row";
	report["adapted_catalog_gap"] = "adapted project catalog currently omits mine/reward fields, so this phase must read recovered source rows until the import is repaired";
	report["mine_template_bucket_status"] = "0x4a9911_generator_plus_0x388_0x38c_bucket_bound_to_objects_txt_type_53_inspection_only";
	report["mine_template_bucket_offset"] = "generator+0x388..+0x38c";
	report["mine_template_subtype_filter_offset"] = "candidate_template_metadata+0x20";
	report["mine_template_terrain_filter_status"] = "0x42cc99_runtime_terrain_bitset_filter_ported_from_reversed_objects_txt_masks_inspection_only";
	report["mine_placement_constraint_status"] = "0x4a9641_constraint_scan_executed_inspection_package_adoption_pending";
	report["mine_placement_constraint_gap"] = "candidate scan executes against current generated-cell and objects.txt wrapper data, but production package adoption, exact generator cell bit26 lifecycle, 0x4aa1db reward object lookup, and guard materialization remain pending";
	Dictionary placement_constraint;
	placement_constraint["address"] = "0x4a9641";
	placement_constraint["pre_scan_helper_address"] = "0x49b76d";
	placement_constraint["candidate_validity_helper_address"] = "0x49aa93";
	placement_constraint["candidate_rng_function_address"] = "0x4e7276";
	placement_constraint["virtual_placement_hook"] = "generator_vtable+0x04";
	placement_constraint["owner_match"] = "generated_cell+0x20 high byte equals runtime/source zone owner byte";
	placement_constraint["score_low_word"] = "generated_cell+0x20 low word";
	placement_constraint["neighbor_flag_mask_required"] = "generated_cell+0x28 bit25 and bit26";
	placement_constraint["neighbor_terrain_reject_id"] = 9;
	placement_constraint["neighbor_count_cap"] = 5;
	placement_constraint["special_distance_initial_best_squared"] = 0x9c40;
	placement_constraint["special_distance_min_squared"] = 0x10;
	placement_constraint["special_distance_floor_squared"] = 0x90;
	placement_constraint["special_distance_source"] = "0x4a9d6a one-shot flag for wood/ore in player-capable zones when runtime+0x3c is set";
	placement_constraint["selection_order"] = "scan footprint rectangle, require owner byte, call 0x49aa93, optionally apply zone-anchor distance ring, improve by low-word score and neighbor count, then choose random tied candidate";
	report["mine_placement_constraint"] = placement_constraint;

	struct MineField {
		const char *resource;
		int32_t subtype;
		const char *minimum_offset;
		const char *density_offset;
	};
	const MineField mine_fields[] = {
		{ "wood", 0, "+0x4c", "+0x68" },
		{ "mercury", 1, "+0x50", "+0x6c" },
		{ "ore", 2, "+0x54", "+0x70" },
		{ "sulfur", 3, "+0x58", "+0x74" },
		{ "crystal", 4, "+0x5c", "+0x78" },
		{ "gems", 5, "+0x60", "+0x7c" },
		{ "gold", 6, "+0x64", "+0x80" },
	};
	std::vector<H3ObjectRow> mine_template_rows = h3_object_rows_by_type(H3_MINE_TYPE_ID);
	std::vector<H3ObjectRow> adjacent_resource_rows = h3_object_rows_by_type(H3_RESOURCE_TYPE_ID);
	Array runtime_zones = runtime_build.get("runtime_zones", Array());
	Dictionary footprint = runtime_build.get("zone_footprint_placement", Dictionary());
	Dictionary terrain_fill = footprint.get("terrain_fill_repaint", Dictionary());
	const int32_t width = int32_t(terrain_fill.get("width", 0));
	const int32_t height = int32_t(terrain_fill.get("height", 0));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t expected_grid_size = width * height * level_count;
	PackedInt32Array owner_grid = terrain_fill.get("owner_byte_grid_u8", PackedInt32Array());
	PackedInt32Array repaint_grid = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array());
	PackedInt32Array terrain_codes = terrain_fill.get("terrain_code_u16", PackedInt32Array());
	PackedInt32Array zone_word_low_grid = terrain_fill.get("zone_word_low_u16", PackedInt32Array());
	Array terrain_zone_reports = terrain_fill.get("zones", Array());
	std::vector<uint8_t> object_occupied = occupied_grid_from_town_records(town_castle_placement, width, height, level_count);
	H3MapedRng mine_object_rng { uint32_t(int64_t(town_castle_placement.get("object_rng_state_after_0x4a93a2_uint32", runtime_build.get("rng_state_after_runtime_zone_build", 0)))) };
	const uint32_t mine_object_rng_state_before = mine_object_rng.state;
	Dictionary mine_template_counts_by_subtype;
	for (const H3ObjectRow &row : mine_template_rows) {
		const String key = String::num_int64(row.subtype_id);
		mine_template_counts_by_subtype[key] = int32_t(mine_template_counts_by_subtype.get(key, 0)) + 1;
	}
	Dictionary adjacent_resource_counts_by_subtype;
	for (const H3ObjectRow &row : adjacent_resource_rows) {
		const String key = String::num_int64(row.subtype_id);
		adjacent_resource_counts_by_subtype[key] = int32_t(adjacent_resource_counts_by_subtype.get(key, 0)) + 1;
	}
	report["mine_object_type_id"] = H3_MINE_TYPE_ID;
	report["mine_object_type_name"] = object_type_name_from_names_file(H3_MINE_TYPE_ID);
	report["mine_template_row_count"] = int32_t(mine_template_rows.size());
	report["mine_template_counts_by_subtype"] = mine_template_counts_by_subtype;
	report["mine_template_rows_preview"] = h3_object_rows_to_array(mine_template_rows);
	report["adjacent_resource_object_type_id"] = H3_RESOURCE_TYPE_ID;
	report["adjacent_resource_object_type_name"] = object_type_name_from_names_file(H3_RESOURCE_TYPE_ID);
	report["adjacent_resource_template_row_count"] = int32_t(adjacent_resource_rows.size());
	report["adjacent_resource_counts_by_subtype"] = adjacent_resource_counts_by_subtype;
	const char *band_low_offsets[] = { "+0xa0", "+0xac", "+0xb8" };
	const char *band_high_offsets[] = { "+0xa4", "+0xb0", "+0xbc" };
	const char *band_density_offsets[] = { "+0xa8", "+0xb4", "+0xc0" };

	Array zone_reports;
	Array mine_minimum_fields;
	Array mine_density_fields;
	Array mine_minimum_helper_calls;
	Array treasure_band_fields;
	Array treasure_scheduler_zones;
	Array treasure_reward_attempt_records;
	int32_t source_zone_missing_count = 0;
	int32_t mine_minimum_field_count = 0;
	int32_t mine_density_field_count = 0;
	int32_t positive_mine_minimum_field_count = 0;
	int32_t positive_mine_density_field_count = 0;
	int32_t total_minimum_mine_count = 0;
	int32_t total_mine_density_weight = 0;
	int32_t mine_minimum_helper_candidate_template_total = 0;
	int32_t mine_minimum_helper_terrain_filtered_candidate_total = 0;
	int32_t mine_placement_constraint_scan_call_count = 0;
	int32_t mine_placement_constraint_candidate_total = 0;
	int32_t mine_placement_constraint_selected_count = 0;
	int32_t mine_placement_constraint_missing_grid_count = 0;
	int32_t mine_placement_constraint_rejected_owner_count = 0;
	int32_t mine_placement_constraint_rejected_49aa93_count = 0;
	int32_t mine_placement_constraint_rejected_special_distance_count = 0;
	int32_t mine_object_occupied_cell_mark_count = 0;
	int32_t mine_template_selection_rng_call_count = 0;
	int32_t mine_placement_rng_call_count = 0;
	int32_t mine_guard_scaled_nonzero_count = 0;
	int32_t mine_guard_scaled_value_total = 0;
	int32_t treasure_band_field_count = 0;
	int32_t positive_treasure_band_count = 0;
	int32_t total_treasure_density_weight = 0;
	int32_t treasure_low_below_100_count = 0;
	int32_t treasure_scheduler_active_zone_count = 0;
	int32_t treasure_scheduler_scaled_step_total = 0;
	int32_t treasure_reward_attempt_count = 0;
	int32_t treasure_reward_value_rng_call_count = 0;
	int32_t treasure_reward_object_lookup_count = 0;
	int32_t treasure_reward_object_lookup_primary_retry_budget_total = 0;
	int32_t treasure_reward_candidate_scan_count = 0;
	int32_t treasure_reward_candidate_scan_eligible_total = 0;
	int32_t treasure_reward_candidate_scan_weight_total = 0;

	for (int64_t index = 0; index < active_zones.size(); ++index) {
		if (Variant(active_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary active_zone = Dictionary(active_zones[index]);
		Dictionary source_zone = raw_source_zone_for_active_zone(source_catalog_index, active_zone);
		Dictionary grammar_source = active_zone.get("grammar_source", Dictionary());
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = int32_t(index);
		zone_report["source_zone_id"] = active_zone.get("source_zone_id", index);
		zone_report["source_row"] = grammar_source.get("source_row", -1);
		zone_report["source_bucket"] = grammar_source.get("source_bucket", -1);
		zone_report["role"] = active_zone.get("role", active_zone.get("type", ""));
		if (source_zone.is_empty()) {
			zone_report["status"] = "missing_recovered_source_zone_row";
			source_zone_missing_count += 1;
			zone_reports.append(zone_report);
			continue;
		}

		zone_report["status"] = "recovered_source_zone_row_bound";
		Dictionary runtime = index < runtime_zones.size() && Variant(runtime_zones[index]).get_type() == Variant::DICTIONARY
				? Dictionary(runtime_zones[index])
				: Dictionary();
		const int32_t runtime_zone_index = int32_t(runtime.get("runtime_zone_index", index));
		const int32_t runtime_h3maped_terrain_id = int32_t(runtime.get("h3maped_terrain_id", -1));
		const int32_t runtime_anchor_x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		const int32_t runtime_anchor_y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		const int32_t runtime_anchor_level = int32_t(runtime.get("level", 0));
		bool has_town_record_in_zone = false;
		Array town_records = town_castle_placement.get("direct_town_records", Array());
		for (int64_t town_index = 0; town_index < town_records.size(); ++town_index) {
			if (Variant(town_records[town_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary town_record = Dictionary(town_records[town_index]);
			if (int32_t(town_record.get("runtime_zone_index", -1)) == runtime_zone_index) {
				has_town_record_in_zone = true;
				break;
			}
		}
		Dictionary minimum_mines = source_zone.get("minimum_mines", Dictionary());
		Dictionary mine_density = source_zone.get("mine_density", Dictionary());
		int32_t zone_minimum_mine_count = 0;
		int32_t zone_mine_density_weight = 0;
		for (const MineField &field : mine_fields) {
			const int32_t minimum_count = dictionary_int(minimum_mines, field.resource);
			const int32_t density_weight = dictionary_int(mine_density, field.resource);
			mine_minimum_field_count += 1;
			mine_density_field_count += 1;
			total_minimum_mine_count += minimum_count;
			total_mine_density_weight += density_weight;
			zone_minimum_mine_count += minimum_count;
			zone_mine_density_weight += density_weight;
			if (minimum_count > 0) {
				positive_mine_minimum_field_count += 1;
			}
			if (density_weight > 0) {
				positive_mine_density_field_count += 1;
			}

			Dictionary minimum_record;
			minimum_record["phase"] = "0x4a9d6a_mine_minimum";
			minimum_record["runtime_zone_index"] = int32_t(index);
			minimum_record["source_row"] = zone_report.get("source_row", -1);
			minimum_record["resource"] = field.resource;
			minimum_record["mine_subtype"] = field.subtype;
			minimum_record["source_field_offset"] = field.minimum_offset;
			minimum_record["count"] = minimum_count;
			minimum_record["helper_address"] = "0x4a9911";
			minimum_record["placement_status"] = minimum_count > 0 ? String("pending_0x4a9911_mine_object_template_selection_and_0x4a9641_placement") : String("skipped_zero_minimum");
			mine_minimum_fields.append(minimum_record);
			for (int32_t ordinal = 0; ordinal < minimum_count; ++ordinal) {
				const int32_t matching_template_count = int32_t(mine_template_counts_by_subtype.get(String::num_int64(field.subtype), 0));
				mine_minimum_helper_candidate_template_total += matching_template_count;
				Dictionary helper_call;
				helper_call["phase"] = "0x4a9911_mine_minimum_helper";
				helper_call["runtime_zone_index"] = int32_t(index);
				helper_call["source_row"] = zone_report.get("source_row", -1);
				helper_call["resource"] = field.resource;
				helper_call["mine_subtype"] = field.subtype;
				helper_call["ordinal"] = ordinal;
				helper_call["generator_template_bucket_offset"] = "generator+0x388..+0x38c";
				helper_call["candidate_subtype_filter_offset"] = "candidate_template_metadata+0x20";
				helper_call["matched_template_candidate_count_before_terrain_filter"] = matching_template_count;
				helper_call["terrain_filter_status"] = "0x42cc99_runtime_terrain_bitset_filter_recorded_template_wrapper_execution_pending";
				helper_call["selection_rng_function_address"] = "0x4e7276";
				helper_call["object_record_size_bytes"] = 0x1c;
				helper_call["object_record_constructor_address"] = "0x49ba89";
				helper_call["object_record_vtable_address"] = "0x540ab0";
				helper_call["placement_constraint_helper_address"] = "0x4a9641";
				helper_call["placement_constraint_status"] = "0x4a9641_constraint_scan_sequence_recovered_candidate_execution_pending";
				helper_call["placement_constraint_owner_match"] = "cell+0x20_high_byte_matches_runtime_zone";
				helper_call["placement_constraint_score_low_word"] = "cell+0x20_low_word";
				helper_call["placement_constraint_neighbor_count_cap"] = 5;
				helper_call["placement_constraint_distance_min_squared"] = 0x10;
				helper_call["placement_constraint_distance_floor_squared"] = 0x90;
				helper_call["placement_constraint_rng_function_address"] = "0x4e7276";
				helper_call["placement_constraint_virtual_hook"] = "generator_vtable+0x04";
				const std::vector<H3ObjectRow> terrain_filtered_templates = filtered_h3_object_rows_for_subtype_and_terrain(mine_template_rows, field.subtype, runtime_h3maped_terrain_id);
				mine_minimum_helper_terrain_filtered_candidate_total += int32_t(terrain_filtered_templates.size());
				helper_call["runtime_h3maped_terrain_id"] = runtime_h3maped_terrain_id;
				helper_call["matched_template_candidate_count_after_terrain_filter"] = int32_t(terrain_filtered_templates.size());
				helper_call["terrain_filter_status"] = !terrain_filtered_templates.empty()
						? String("0x42cc99_runtime_terrain_bitset_filter_ported_from_objects_txt_masks")
						: String("blocked_no_0x42cc99_terrain_matching_mine_template_rows");
				if (!terrain_filtered_templates.empty()) {
					const int32_t template_rng_value = mine_object_rng.next();
					mine_template_selection_rng_call_count += 1;
					const int32_t template_index = template_rng_value % int32_t(terrain_filtered_templates.size());
					const H3ObjectRow &selected_template = terrain_filtered_templates[size_t(template_index)];
					helper_call["selected_template_rng_value"] = template_rng_value;
					helper_call["selected_template_index"] = template_index;
					helper_call["selected_template_source_line"] = selected_template.source_line;
					helper_call["selected_template_def_name"] = selected_template.def_name;
					helper_call["selected_template_passability_mask"] = selected_template.passability_mask;
					helper_call["selected_template_action_mask"] = selected_template.action_mask;
					helper_call["selected_template_terrain_mask_secondary"] = selected_template.terrain_mask_secondary;
					const std::vector<H3MaskPoint> mine_body_points = h3_text_mask_points(selected_template.passability_mask, false);
					const std::vector<H3MaskPoint> mine_action_points = h3_text_mask_points(selected_template.action_mask, true);
					helper_call["selected_template_body_cell_count"] = int32_t(mine_body_points.size());
					helper_call["selected_template_action_cell_count"] = int32_t(mine_action_points.size());

					bool bbox_found = false;
					int32_t min_x = 0;
					int32_t min_y = 0;
					int32_t max_x_exclusive = width;
					int32_t max_y_exclusive = height;
					for (int64_t zone_report_index = 0; zone_report_index < terrain_zone_reports.size(); ++zone_report_index) {
						if (Variant(terrain_zone_reports[zone_report_index]).get_type() != Variant::DICTIONARY) {
							continue;
						}
						Dictionary terrain_zone = Dictionary(terrain_zone_reports[zone_report_index]);
						if (int32_t(terrain_zone.get("runtime_zone_index", -1)) != runtime_zone_index) {
							continue;
						}
						min_x = std::clamp(int32_t(terrain_zone.get("bbox_min_x_after_0x4a2105", 0)), 0, width);
						min_y = std::clamp(int32_t(terrain_zone.get("bbox_min_y_after_0x4a2105", 0)), 0, height);
						max_x_exclusive = std::clamp(int32_t(terrain_zone.get("bbox_max_x_after_0x4a2105_exclusive", width)), 0, width);
						max_y_exclusive = std::clamp(int32_t(terrain_zone.get("bbox_max_y_after_0x4a2105_exclusive", height)), 0, height);
						bbox_found = true;
						break;
					}
					const bool grid_available = width > 0 && height > 0 && owner_grid.size() == expected_grid_size && repaint_grid.size() == expected_grid_size && terrain_codes.size() == expected_grid_size && zone_word_low_grid.size() == expected_grid_size && int32_t(object_occupied.size()) == expected_grid_size;
					const bool special_distance_mode = (field.subtype == 0 || field.subtype == 2) && int32_t(zone_report.get("source_bucket", -1)) >= 0 && int32_t(zone_report.get("source_bucket", -1)) <= 1 && has_town_record_in_zone;
					helper_call["placement_constraint_special_distance_mode"] = special_distance_mode;
					helper_call["placement_constraint_bbox_found"] = bbox_found;
					helper_call["placement_constraint_bbox_min_x"] = min_x;
					helper_call["placement_constraint_bbox_min_y"] = min_y;
					helper_call["placement_constraint_bbox_max_x_exclusive"] = max_x_exclusive;
					helper_call["placement_constraint_bbox_max_y_exclusive"] = max_y_exclusive;
					helper_call["placement_constraint_anchor_x"] = runtime_anchor_x;
					helper_call["placement_constraint_anchor_y"] = runtime_anchor_y;
					helper_call["placement_constraint_anchor_level"] = runtime_anchor_level;
					mine_placement_constraint_scan_call_count += 1;
					if (!grid_available || mine_body_points.empty()) {
						helper_call["placement_constraint_status"] = "blocked_missing_generated_cell_grid_or_template_body";
						mine_placement_constraint_missing_grid_count += 1;
					} else {
						struct MinePlacementCandidate {
							int32_t x = -1;
							int32_t y = -1;
							int32_t level = -1;
							int32_t score = 0;
							int32_t neighbor_count = 0;
							int32_t distance = 0;
							int32_t clamped_distance = 0;
						};
						std::vector<MinePlacementCandidate> tied_candidates;
						Array candidate_preview;
						int32_t raw_owner_match_count = 0;
						int32_t eligible_candidate_count = 0;
						int32_t rejected_owner_count = 0;
						int32_t rejected_49aa93_count = 0;
						int32_t rejected_special_distance_count = 0;
						int32_t best_score = -1;
						int32_t best_neighbor_count = -1;
						int32_t best_clamped_distance = 0x9c40;
						for (int32_t level = 0; level < level_count; ++level) {
							for (int32_t y = min_y; y < max_y_exclusive; ++y) {
								for (int32_t x = min_x; x < max_x_exclusive; ++x) {
									const int64_t key = cell_key_4a325d(width, height, x, y, level);
									if (key < 0 || key >= expected_grid_size) {
										continue;
									}
									if (owner_grid[int32_t(key)] != runtime_zone_index) {
										rejected_owner_count += 1;
										continue;
									}
									raw_owner_match_count += 1;
									bool passes_49aa93_body = true;
									for (const H3MaskPoint &point : mine_body_points) {
										const int32_t body_x = x + point.dx;
										const int32_t body_y = y + point.dy;
										const int64_t body_key = cell_key_4a325d(width, height, body_x, body_y, level);
										if (body_key < 0 || body_key >= expected_grid_size || object_occupied[size_t(body_key)] != 0 || repaint_grid[int32_t(body_key)] == 0 || (terrain_codes[int32_t(body_key)] & 0x3f) == 9 || owner_grid[int32_t(body_key)] != runtime_zone_index) {
											passes_49aa93_body = false;
											break;
										}
									}
									if (!passes_49aa93_body) {
										rejected_49aa93_count += 1;
										continue;
									}
									const int32_t distance = distance_truncate(runtime_anchor_x, runtime_anchor_y, x, y);
									int32_t clamped_distance = distance;
									if (special_distance_mode) {
										if (distance < 0x10) {
											rejected_special_distance_count += 1;
											continue;
										}
										if (distance > best_clamped_distance) {
											rejected_special_distance_count += 1;
											continue;
										}
										clamped_distance = std::max(distance, 0x90);
									}
									int32_t neighbor_count = 0;
									for (const H3MaskPoint &point : mine_body_points) {
										const int32_t body_x = x + point.dx;
										const int32_t body_y = y + point.dy;
										const int64_t body_key = cell_key_4a325d(width, height, body_x, body_y, level);
										if (body_key >= 0 && body_key < expected_grid_size && repaint_grid[int32_t(body_key)] != 0 && (terrain_codes[int32_t(body_key)] & 0x3f) != 9) {
											neighbor_count += 1;
											if (neighbor_count >= 5) {
												neighbor_count = 5;
												break;
											}
										}
									}
									const int32_t score = zone_word_low_grid[int32_t(key)] & 0xffff;
									bool keep_candidate = false;
									if (special_distance_mode && clamped_distance < best_clamped_distance) {
										best_clamped_distance = clamped_distance;
										best_score = score;
										best_neighbor_count = neighbor_count;
										tied_candidates.clear();
										keep_candidate = true;
									} else if ((!special_distance_mode || clamped_distance == best_clamped_distance) && score > best_score) {
										best_score = score;
										best_neighbor_count = neighbor_count;
										tied_candidates.clear();
										keep_candidate = true;
									} else if ((!special_distance_mode || clamped_distance == best_clamped_distance) && score == best_score && neighbor_count > best_neighbor_count) {
										best_neighbor_count = neighbor_count;
										tied_candidates.clear();
										keep_candidate = true;
									} else if ((!special_distance_mode || clamped_distance == best_clamped_distance) && score == best_score && neighbor_count == best_neighbor_count) {
										keep_candidate = true;
									}
									if (keep_candidate) {
										MinePlacementCandidate candidate;
										candidate.x = x;
										candidate.y = y;
										candidate.level = level;
										candidate.score = score;
										candidate.neighbor_count = neighbor_count;
										candidate.distance = distance;
										candidate.clamped_distance = clamped_distance;
										tied_candidates.push_back(candidate);
									}
									eligible_candidate_count += 1;
									if (candidate_preview.size() < 8) {
										Dictionary candidate;
										candidate["x"] = x;
										candidate["y"] = y;
										candidate["level"] = level;
										candidate["score_low_word"] = score;
										candidate["neighbor_count_capped"] = neighbor_count;
										candidate["distance_to_runtime_anchor"] = distance;
										candidate["clamped_special_distance"] = clamped_distance;
										candidate_preview.append(candidate);
									}
								}
							}
						}
						mine_placement_constraint_candidate_total += eligible_candidate_count;
						mine_placement_constraint_rejected_owner_count += rejected_owner_count;
						mine_placement_constraint_rejected_49aa93_count += rejected_49aa93_count;
						mine_placement_constraint_rejected_special_distance_count += rejected_special_distance_count;
						helper_call["placement_constraint_status"] = !tied_candidates.empty()
								? String("0x4a9641_candidate_scan_executed_selected_inspection_only_package_adoption_pending")
								: String("0x4a9641_candidate_scan_executed_no_candidates");
						helper_call["placement_constraint_owner_match_count"] = raw_owner_match_count;
						helper_call["placement_constraint_candidate_count"] = eligible_candidate_count;
						helper_call["placement_constraint_rejected_owner_count"] = rejected_owner_count;
						helper_call["placement_constraint_rejected_49aa93_count"] = rejected_49aa93_count;
						helper_call["placement_constraint_rejected_special_distance_count"] = rejected_special_distance_count;
						helper_call["placement_constraint_best_score_low_word"] = best_score;
						helper_call["placement_constraint_best_neighbor_count"] = best_neighbor_count;
						helper_call["placement_constraint_tied_candidate_count"] = int32_t(tied_candidates.size());
						helper_call["placement_constraint_candidate_preview"] = candidate_preview;
						if (!tied_candidates.empty()) {
							const int32_t placement_rng_value = mine_object_rng.next();
							mine_placement_rng_call_count += 1;
							const int32_t selected_index = placement_rng_value % int32_t(tied_candidates.size());
							const MinePlacementCandidate &selected = tied_candidates[size_t(selected_index)];
							int32_t marked_cells = 0;
							Array stamped_body_cells;
							for (const H3MaskPoint &point : mine_body_points) {
								const int64_t body_key = cell_key_4a325d(width, height, selected.x + point.dx, selected.y + point.dy, selected.level);
								if (body_key >= 0 && body_key < expected_grid_size && object_occupied[size_t(body_key)] == 0) {
									object_occupied[size_t(body_key)] = 1;
									marked_cells += 1;
									if (stamped_body_cells.size() < 12) {
										Dictionary cell;
										cell["x"] = selected.x + point.dx;
										cell["y"] = selected.y + point.dy;
										cell["level"] = selected.level;
										stamped_body_cells.append(cell);
									}
								}
							}
							mine_placement_constraint_selected_count += 1;
							mine_object_occupied_cell_mark_count += marked_cells;
							helper_call["placement_constraint_rng_value"] = placement_rng_value;
							helper_call["placement_constraint_selected_index"] = selected_index;
							helper_call["placement_constraint_selected_x"] = selected.x;
							helper_call["placement_constraint_selected_y"] = selected.y;
							helper_call["placement_constraint_selected_level"] = selected.level;
							helper_call["placement_constraint_selected_score_low_word"] = selected.score;
							helper_call["placement_constraint_selected_neighbor_count"] = selected.neighbor_count;
							helper_call["placement_constraint_selected_distance"] = selected.distance;
							helper_call["placement_constraint_marked_body_cell_count"] = marked_cells;
							helper_call["placement_constraint_marked_body_cell_preview"] = stamped_body_cells;
						}
					}
				}
				const int32_t guard_base_value = mine_guard_base_value(field.subtype);
				const int32_t guard_source_strength_mode = h3maped_local_monster_strength_mode(source_zone.get("monster_strength", "avg"));
				const int32_t guard_effective_strength_mode = h3maped_effective_monster_strength_mode_4a960a(normalized_config, source_zone);
				const int32_t guard_scaled_value = h3maped_mine_guard_scaled_value_4a960a_4a65a5(normalized_config, source_zone, guard_base_value);
				if (guard_scaled_value > 0) {
					mine_guard_scaled_nonzero_count += 1;
					mine_guard_scaled_value_total += guard_scaled_value;
				}
				helper_call["guard_base_value"] = guard_base_value;
				helper_call["guard_source_strength_mode"] = guard_source_strength_mode;
				helper_call["guard_global_strength_mode"] = h3maped_global_monster_strength_mode(normalized_config);
				helper_call["guard_effective_strength_mode"] = guard_effective_strength_mode;
				helper_call["guard_scaled_value"] = guard_scaled_value;
				helper_call["guard_adjustment_helpers"] = "0x4a960a -> 0x4a65a5";
				helper_call["guard_scaling_status"] = "0x4a960a_0x4a65a5_guard_value_scaled_guard_object_pending";
				helper_call["adjacent_resource_helper_address"] = "0x4a9e40";
				helper_call["adjacent_resource_object_type_id"] = H3_RESOURCE_TYPE_ID;
				helper_call["adjacent_resource_subtype"] = field.subtype;
				helper_call["status"] = matching_template_count > 0
						? String("0x4a9911_template_bucket_record_guard_handoff_and_0x4a9641_scan_ported_package_adoption_pending")
						: String("blocked_no_matching_mine_template_rows");
				mine_minimum_helper_calls.append(helper_call);
			}

			Dictionary density_record;
			density_record["phase"] = "0x4a9c7c_mine_density";
			density_record["runtime_zone_index"] = int32_t(index);
			density_record["source_row"] = zone_report.get("source_row", -1);
			density_record["resource"] = field.resource;
			density_record["mine_subtype"] = field.subtype;
			density_record["source_field_offset"] = field.density_offset;
			density_record["weight"] = density_weight;
			density_record["helper_address"] = "0x4a9c7c";
			density_record["placement_status"] = density_weight > 0 ? String("pending_0x4a9c7c_density_scheduling_and_0x4a9911_helper") : String("skipped_zero_density");
			mine_density_fields.append(density_record);
		}

		Array treasure_bands = source_zone.get("treasure_bands", Array());
		int32_t zone_treasure_density_weight = 0;
		int32_t zone_treasure_density_product = 1;
		int32_t zone_eligible_band_count = 0;
		Array scheduler_band_records;
		for (int32_t band = 0; band < 3; ++band) {
			Dictionary band_source = band < treasure_bands.size() && Variant(treasure_bands[band]).get_type() == Variant::DICTIONARY
					? Dictionary(treasure_bands[band])
					: Dictionary();
			const int32_t low = int32_t(band_source.get("low", 0));
			const int32_t high = int32_t(band_source.get("high", 0));
			const int32_t density = int32_t(band_source.get("density", 0));
			const bool scheduler_band_eligible = density > 0 && low >= 100;
			treasure_band_field_count += 1;
			total_treasure_density_weight += density;
			if (scheduler_band_eligible) {
				positive_treasure_band_count += 1;
				zone_eligible_band_count += 1;
				zone_treasure_density_weight += density;
				zone_treasure_density_product *= density;
			}
			if (density > 0 && low < 100) {
				treasure_low_below_100_count += 1;
			}
			Dictionary band_record;
			band_record["phase"] = "0x4aab7e_treasure_band";
			band_record["runtime_zone_index"] = int32_t(index);
			band_record["source_row"] = zone_report.get("source_row", -1);
			band_record["band_index"] = band;
			band_record["low_offset"] = band_low_offsets[band];
			band_record["high_offset"] = band_high_offsets[band];
			band_record["density_offset"] = band_density_offsets[band];
			band_record["low"] = low;
			band_record["high"] = high;
			band_record["density"] = density;
			band_record["helper_address"] = "0x4aa354";
			band_record["placement_status"] = scheduler_band_eligible ? String("pending_0x4aa354_reward_object_value_selection_and_guarding") : String("skipped_ineligible_band");
			treasure_band_fields.append(band_record);
			Dictionary scheduler_band;
			scheduler_band["band_index"] = band;
			scheduler_band["low"] = low;
			scheduler_band["high"] = high;
			scheduler_band["density"] = density;
			scheduler_band["eligible"] = scheduler_band_eligible;
			scheduler_band["disabled_flag_stack_offset"] = String("ebp") + (band == 0 ? String("-0x14") : band == 1 ? String("-0x13") : String("-0x12"));
			scheduler_band_records.append(scheduler_band);
		}
		Dictionary scheduler;
		scheduler["phase"] = "0x4aab7e_treasure_band_scheduler";
		scheduler["runtime_zone_index"] = int32_t(index);
		scheduler["source_row"] = zone_report.get("source_row", -1);
		scheduler["runtime_h3maped_terrain_id"] = runtime_h3maped_terrain_id;
		scheduler["eligible_band_count"] = zone_eligible_band_count;
		scheduler["total_density_weight"] = zone_treasure_density_weight;
		scheduler["density_product"] = zone_eligible_band_count > 0 ? zone_treasure_density_product : 0;
		const int32_t scheduler_scale_dividend = runtime_h3maped_terrain_id == 8 ? 0x640 : 0x320;
		const int32_t scheduler_density_divisor = zone_treasure_density_weight > 0 ? scheduler_scale_dividend / zone_treasure_density_weight : 0;
		const int32_t scheduler_scaled_step = scheduler_density_divisor > 0 ? int32_t(std::sqrt(double(scheduler_density_divisor))) : 0;
		scheduler["scale_dividend"] = scheduler_scale_dividend;
		scheduler["scale_density_divisor"] = scheduler_density_divisor;
		scheduler["scaled_step_after_sqrt_trunc"] = scheduler_scaled_step;
		scheduler["math_helper_addresses"] = Array::make("0x4e7d44_sqrt", "0x4e7dec_fistp_trunc");
		scheduler["band_records"] = scheduler_band_records;
		Array accumulator_records;
		for (int32_t band = 0; band < scheduler_band_records.size(); ++band) {
			Dictionary scheduler_band = Dictionary(scheduler_band_records[band]);
			const bool eligible = bool(scheduler_band.get("eligible", false));
			const int32_t density = int32_t(scheduler_band.get("density", 0));
			Dictionary accumulator;
			accumulator["band_index"] = band;
			accumulator["initial_accumulator"] = 0;
			accumulator["step_weight"] = eligible && density > 0 ? zone_treasure_density_product / density : 0;
			accumulator["selection_order_rule"] = "0x4aac70 selects the enabled band with the lowest accumulator, then adds the band step weight before calling 0x4aa354";
			accumulator_records.append(accumulator);
		}
		scheduler["accumulator_records"] = accumulator_records;
		scheduler["reward_attempt_helper_address"] = "0x4aa354";
		scheduler["post_reward_guard_helper_address"] = "0x4aa9b7";
		scheduler["materializes_reward_objects"] = false;
		scheduler["status"] = zone_eligible_band_count > 0
				? String("0x4aab7e_treasure_scheduler_math_materialized_reward_objects_pending")
				: String("0x4aab7e_treasure_scheduler_skipped_no_eligible_bands");
		treasure_scheduler_zones.append(scheduler);
		if (zone_eligible_band_count > 0) {
			treasure_scheduler_active_zone_count += 1;
			treasure_scheduler_scaled_step_total += scheduler_scaled_step;
		}
		zone_report["minimum_mine_count"] = zone_minimum_mine_count;
		zone_report["mine_density_weight_total"] = zone_mine_density_weight;
		zone_report["treasure_density_weight_total"] = zone_treasure_density_weight;
		zone_reports.append(zone_report);
	}

	const uint32_t reward_rng_state_before = mine_object_rng.state;
	const int32_t reward_proxy_inventory_count = reward_proxy_reference_count();
	for (int64_t scheduler_index = 0; scheduler_index < treasure_scheduler_zones.size(); ++scheduler_index) {
		if (Variant(treasure_scheduler_zones[scheduler_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scheduler = Dictionary(treasure_scheduler_zones[scheduler_index]);
		Array band_records = scheduler.get("band_records", Array());
		Array accumulator_records = scheduler.get("accumulator_records", Array());
		Array attempt_records;
		std::vector<int32_t> accumulator_values;
		std::vector<int32_t> step_weights;
		std::vector<bool> enabled_bands;
		for (int64_t band_index = 0; band_index < band_records.size(); ++band_index) {
			Dictionary band = Variant(band_records[band_index]).get_type() == Variant::DICTIONARY
					? Dictionary(band_records[band_index])
					: Dictionary();
			Dictionary accumulator = band_index < accumulator_records.size() && Variant(accumulator_records[band_index]).get_type() == Variant::DICTIONARY
					? Dictionary(accumulator_records[band_index])
					: Dictionary();
			accumulator_values.push_back(int32_t(accumulator.get("initial_accumulator", 0)));
			step_weights.push_back(int32_t(accumulator.get("step_weight", 0)));
			enabled_bands.push_back(bool(band.get("eligible", false)));
		}
		const int32_t scaled_step = int32_t(scheduler.get("scaled_step_after_sqrt_trunc", 0));
		for (int32_t attempt_index = 0; attempt_index < scaled_step; ++attempt_index) {
			int32_t selected_band_index = -1;
			int32_t selected_accumulator = 0x7fffffff;
			for (int32_t band_index = 0; band_index < int32_t(enabled_bands.size()); ++band_index) {
				if (!enabled_bands[size_t(band_index)]) {
					continue;
				}
				if (selected_band_index < 0 || accumulator_values[size_t(band_index)] < selected_accumulator) {
					selected_band_index = band_index;
					selected_accumulator = accumulator_values[size_t(band_index)];
				}
			}
			if (selected_band_index < 0 || selected_band_index >= band_records.size()) {
				break;
			}
			Dictionary band = Dictionary(band_records[selected_band_index]);
			const int32_t low = int32_t(band.get("low", 0));
			const int32_t high = int32_t(band.get("high", 0));
			const int32_t step_weight = step_weights[size_t(selected_band_index)];
			accumulator_values[size_t(selected_band_index)] += step_weight;
			const bool consumes_value_rng = high > low;
			int32_t value_rng = -1;
			int32_t selected_value = high;
			if (consumes_value_rng) {
				value_rng = mine_object_rng.next();
				treasure_reward_value_rng_call_count += 1;
				selected_value = low + (value_rng % (high - low));
			}
			Dictionary object_lookup;
			object_lookup["phase"] = "0x4aa1db_reward_object_lookup";
			object_lookup["function_address"] = "0x4aa1db";
			object_lookup["candidate_scan_helper_address"] = "0x4a9f1c";
			object_lookup["primary_probe_retry_budget"] = 3;
			object_lookup["primary_min_value"] = selected_value / 4;
			object_lookup["primary_max_value"] = selected_value;
			object_lookup["primary_value_divisor"] = 4;
			object_lookup["primary_probe_flags"] = Array::make(1, 1);
			object_lookup["coordinate_sentinel"] = Array::make(-1, -1, -1);
			object_lookup["selected_value_output_stack_offset"] = "ebp-0x08";
			object_lookup["remaining_value_threshold"] = 0x5dc;
			object_lookup["remaining_value_threshold_hex"] = "0x5dc";
			object_lookup["secondary_probe_retry_budget"] = 3;
			object_lookup["secondary_min_formula"] = "remaining_value / 4";
			object_lookup["secondary_max_formula"] = "(remaining_value * 5) / 4";
			object_lookup["secondary_probe_flags"] = Array::make(0, 1);
			object_lookup["secondary_validation_helper_address"] = "0x49d471";
			object_lookup["placement_coordinate_helper_address"] = "0x49abd6";
			object_lookup["cleanup_helper_address"] = "0x49d6e0";
			object_lookup["object_dimensions_offsets"] = Array::make("+0x34", "+0x38");
			Dictionary candidate_scan = reward_candidate_scan_4a9f1c_report(selected_value / 4, selected_value, true, true);
			object_lookup["candidate_scan_control_flow"] = candidate_scan;
			object_lookup["native_proxy_catalog_path"] = REWARD_PROXY_CATALOG_PATH;
			object_lookup["native_proxy_inventory_reward_reference_count"] = reward_proxy_inventory_count;
			object_lookup["materializes_reward_object"] = false;
			object_lookup["status"] = "0x4aa1db_lookup_control_flow_with_materialized_candidate_scan_dynamic_value_sites_pending";
			treasure_reward_object_lookup_count += 1;
			treasure_reward_object_lookup_primary_retry_budget_total += 3;
			treasure_reward_candidate_scan_count += 1;
			treasure_reward_candidate_scan_eligible_total += int32_t(candidate_scan.get("eligible_candidate_count", 0));
			treasure_reward_candidate_scan_weight_total += int32_t(candidate_scan.get("eligible_candidate_weight_total", 0));

			Dictionary attempt;
			attempt["phase"] = "0x4aa354_reward_attempt";
			attempt["runtime_zone_index"] = scheduler.get("runtime_zone_index", -1);
			attempt["source_row"] = scheduler.get("source_row", -1);
			attempt["attempt_index"] = attempt_index;
			attempt["selected_band_index"] = selected_band_index;
			attempt["accumulator_before_selection"] = selected_accumulator;
			attempt["accumulator_step_weight"] = step_weight;
			attempt["accumulator_after_selection"] = accumulator_values[size_t(selected_band_index)];
			attempt["low"] = low;
			attempt["high"] = high;
			attempt["value_rng_consumed"] = consumes_value_rng;
			attempt["value_rng_function_address"] = consumes_value_rng ? String("0x4e7276") : String("");
			attempt["value_rng_value"] = value_rng;
			attempt["selected_reward_value"] = selected_value;
			attempt["pre_attempt_helper_address"] = "0x49ce64";
			attempt["object_lookup_helper_address"] = "0x4aa1db";
			attempt["object_lookup_status"] = object_lookup.get("status", "");
			attempt["object_lookup_control_flow"] = object_lookup;
			attempt["guard_value_helper_address"] = "0x4a960a";
			attempt["post_object_helper_address"] = "0x4a5c07";
			attempt["mode"] = 0;
			attempt["materializes_reward_object"] = false;
			attempt["status"] = "0x4aa354_reward_value_selection_materialized_object_lookup_pending";
			attempt_records.append(attempt);
			treasure_reward_attempt_records.append(attempt);
			treasure_reward_attempt_count += 1;
		}
		scheduler["reward_attempt_status"] = attempt_records.is_empty()
				? String("0x4aa354_reward_attempts_skipped_no_enabled_bands")
				: String("0x4aa354_reward_attempt_value_selection_materialized_object_lookup_pending");
		scheduler["reward_attempt_count"] = attempt_records.size();
		scheduler["reward_attempt_records"] = attempt_records;
		scheduler["materializes_reward_objects"] = false;
		treasure_scheduler_zones[scheduler_index] = scheduler;
	}
	const uint32_t reward_rng_state_after = mine_object_rng.state;

	report["zone_count"] = zone_reports.size();
	report["source_zone_missing_count"] = source_zone_missing_count;
	report["zones"] = zone_reports;
	report["mine_minimum_field_count"] = mine_minimum_field_count;
	report["mine_density_field_count"] = mine_density_field_count;
	report["positive_mine_minimum_field_count"] = positive_mine_minimum_field_count;
	report["positive_mine_density_field_count"] = positive_mine_density_field_count;
	report["total_minimum_mine_count"] = total_minimum_mine_count;
	report["total_mine_density_weight"] = total_mine_density_weight;
	report["mine_minimum_fields"] = mine_minimum_fields;
	report["mine_density_fields"] = mine_density_fields;
	report["mine_minimum_helper_call_count"] = mine_minimum_helper_calls.size();
	report["mine_minimum_helper_candidate_template_total"] = mine_minimum_helper_candidate_template_total;
	report["mine_minimum_helper_terrain_filtered_candidate_template_total"] = mine_minimum_helper_terrain_filtered_candidate_total;
	report["mine_minimum_helper_calls"] = mine_minimum_helper_calls;
	report["mine_placement_constraint_scan_call_count"] = mine_placement_constraint_scan_call_count;
	report["mine_placement_constraint_candidate_total"] = mine_placement_constraint_candidate_total;
	report["mine_placement_constraint_selected_count"] = mine_placement_constraint_selected_count;
	report["mine_placement_constraint_missing_grid_count"] = mine_placement_constraint_missing_grid_count;
	report["mine_placement_constraint_rejected_owner_count"] = mine_placement_constraint_rejected_owner_count;
	report["mine_placement_constraint_rejected_49aa93_count"] = mine_placement_constraint_rejected_49aa93_count;
	report["mine_placement_constraint_rejected_special_distance_count"] = mine_placement_constraint_rejected_special_distance_count;
	report["mine_object_occupied_cell_mark_count"] = mine_object_occupied_cell_mark_count;
	report["mine_template_selection_rng_call_count"] = mine_template_selection_rng_call_count;
	report["mine_placement_rng_call_count"] = mine_placement_rng_call_count;
	report["mine_object_rng_state_before_0x4a9911_uint32"] = int64_t(mine_object_rng_state_before);
	report["mine_object_rng_state_after_0x4a9911_0x4a9641_uint32"] = int64_t(mine_object_rng.state);
	report["mine_guard_global_strength_mode"] = h3maped_global_monster_strength_mode(normalized_config);
	report["mine_guard_scaled_nonzero_count"] = mine_guard_scaled_nonzero_count;
	report["mine_guard_scaled_value_total"] = mine_guard_scaled_value_total;
	report["mine_guard_scaling_status"] = "0x4a960a_0x4a65a5_mine_guard_values_scaled_guard_objects_pending";
	report["mine_density_scheduler_zone_call_count"] = zone_reports.size() - source_zone_missing_count;
	report["mine_density_scheduler_status"] = "0x4a9c7c_positive_weight_schedule_recorded_actual_iterations_pending";
	report["treasure_band_field_count"] = treasure_band_field_count;
	report["positive_treasure_band_count"] = positive_treasure_band_count;
	report["total_treasure_density_weight"] = total_treasure_density_weight;
	report["treasure_low_below_100_count"] = treasure_low_below_100_count;
	report["treasure_band_fields"] = treasure_band_fields;
	report["treasure_scheduler_status"] = "0x4aab7e_treasure_scheduler_math_materialized_reward_objects_pending";
	report["treasure_scheduler_zone_count"] = treasure_scheduler_zones.size();
	report["treasure_scheduler_active_zone_count"] = treasure_scheduler_active_zone_count;
	report["treasure_scheduler_scaled_step_total"] = treasure_scheduler_scaled_step_total;
	report["treasure_scheduler_zones"] = treasure_scheduler_zones;
	report["treasure_reward_attempt_status"] = "0x4aa354_reward_value_selection_materialized_object_lookup_pending";
	report["treasure_reward_attempt_count"] = treasure_reward_attempt_count;
	report["treasure_reward_value_rng_call_count"] = treasure_reward_value_rng_call_count;
	report["treasure_reward_attempt_records"] = treasure_reward_attempt_records;
	report["treasure_reward_rng_state_before_0x4aa354_uint32"] = int64_t(reward_rng_state_before);
	report["treasure_reward_rng_state_after_0x4aa354_uint32"] = int64_t(reward_rng_state_after);
	report["treasure_reward_object_lookup_status"] = "0x4aa1db_lookup_control_flow_with_materialized_candidate_scan_dynamic_value_sites_pending";
	report["treasure_reward_object_lookup_count"] = treasure_reward_object_lookup_count;
	report["treasure_reward_object_lookup_primary_retry_budget_total"] = treasure_reward_object_lookup_primary_retry_budget_total;
	report["treasure_reward_candidate_scan_status"] = "0x4a9f1c_materialized_candidate_scan_dynamic_value_sites_pending";
	report["treasure_reward_candidate_scan_count"] = treasure_reward_candidate_scan_count;
	report["treasure_reward_candidate_scan_eligible_total"] = treasure_reward_candidate_scan_eligible_total;
	report["treasure_reward_candidate_scan_weight_total"] = treasure_reward_candidate_scan_weight_total;
	report["treasure_reward_candidate_vector_proxy_backed_record_count"] = int32_t(h3maped_reward_proxy_backed_candidates_49f95a().size());
	report["treasure_reward_candidate_vector_direct_field_record_count"] = int32_t(h3maped_reward_direct_field_candidates_49f95a().size());
	report["treasure_reward_candidate_vector_literal_constructor_record_count"] = int32_t(h3maped_reward_literal_constructor_candidates_49f95a().size());
	report["treasure_reward_candidate_vector_materialized_record_count"] = int32_t(h3maped_reward_materialized_candidates_49f95a().size());
	report["treasure_reward_candidate_vector_static_construction_summary"] = reward_vector_construction_49f95a_report();
	report["treasure_reward_proxy_inventory_reward_reference_count"] = reward_proxy_inventory_count;
	report["treasure_reward_object_lookup_candidate_execution_materialized"] = false;
	report["guard_reward_monster_generation_status"] = "0x4a9911_0x4a9641_mine_scan_and_0x4aa354_reward_value_selection_executed_inspection_only_package_adoption_rewards_and_guarding_pending";
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
	Dictionary town_castle_placement = town_castle_placement_4a8d2c_4a8db2_report(active_zones, runtime_zones);
	payload["object_category_placement_status"] = town_castle_placement.get("status", "");
	payload["town_castle_placement"] = town_castle_placement;
	Dictionary mine_reward_placement = mine_reward_placement_4a9d6a_4aab7e_report(active_zones, source_catalog_index, runtime_zones, town_castle_placement, normalized_config);
	mine_reward_placement["treasure_reward_dynamic_value_function_summary"] = h3maped_reward_dynamic_value_functions_49f95a_report(normalized_config);
	payload["guard_reward_monster_placement_status"] = mine_reward_placement.get("status", "");
	payload["guard_reward_monster_placement"] = mine_reward_placement;
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
		{ "runtime_zone_build", "0x4a218c, 0x4a1f3b, 0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed, 0x49b452, 0x49b3c1, 0x49b53d", "ported_interleaved_runtime_coordinate_and_terrain_selection_inspection_only" },
		{ "zone_footprint_placement", "0x4a3a03, 0x4cc788, 0x4cca55, 0x4ccb64, 0x4ccdfc, 0x4a2777, 0x4a325d, 0x4a3710", "ported_0x4a3710_small_land_footprint_helpers_and_terrain_visual_inspection_only" },
		{ "terrain_fill_repaint", "0x4a3f27, 0x4bcff5, 0x4bd099", "ported_schedule_and_visual_normalization_inspection_only" },
		{ "object_category_placement", "0x4a8d2c, 0x4a93a2, 0x49a1d8, 0x49aa93, 0x49a6f9, 0x49a09c, 0x4a8db2, 0x4a8c15", "0x4a8d2c_0x4a93a2_0x49aa93_town_49a09c_and_writeout_ledger_ported_project_adoption_pending" },
		{ "guard_reward_monster_placement", "0x4a9d6a, 0x4a9911, 0x4a9c7c, 0x4a9641, 0x4aab7e, 0x4aa354", "0x4a9d6a_0x4a9911_0x4a9641_0x4aab7e_0x4aa354_value_selection_ported_rewards_pending" },
		{ "final_cell_object_passes", "0x49eb8d, 0x4ab52a, 0x4ac4ae", "0x4ab52a_pair_iteration_ported_0x4aae7b_0x4b4243_materialization_pending" },
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

Dictionary h3maped_path_state_seed_4aae7b_report(const Dictionary &terrain_fill, const Dictionary &coordinate_vector_source);
Array h3maped_town_records_from_port(const Dictionary &normalized_config, const Dictionary &payload);
Array h3maped_mine_records_from_port(const Dictionary &normalized_config, const Dictionary &payload);
Array h3maped_connection_records_from_port(const Dictionary &payload, const Dictionary &normalized_config);
Dictionary h3maped_connection_payload_from_records(const Array &connection_records, const Dictionary &normalized_config);
Dictionary h3maped_road_coordinate_vector_source_report(const Array &town_records, const Array &mine_records);
Dictionary h3maped_road_adapter_boundary_from_connections(const Array &connection_records, const Dictionary &terrain_fill, const Dictionary &coordinate_vector_source, int64_t rng_state_before_road_phase);

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
		Dictionary payload = selected_template_payload(adapted_template_for_source_index(source_catalog_index), normalized_config, source_catalog_index, human_count, player_count, next_state);
		Dictionary runtime_build = payload.get("runtime_zone_build", Dictionary());
		Dictionary footprint = runtime_build.get("zone_footprint_placement", Dictionary());
		Dictionary terrain_fill = footprint.get("terrain_fill_repaint", Dictionary());
		Array town_records = h3maped_town_records_from_port(normalized_config, payload);
		Array mine_records = h3maped_mine_records_from_port(normalized_config, payload);
		Array connection_records = h3maped_connection_records_from_port(payload, normalized_config);
		payload["connection_payload"] = h3maped_connection_payload_from_records(connection_records, normalized_config);
		Dictionary coordinate_vector_source = h3maped_road_coordinate_vector_source_report(town_records, mine_records);
		Dictionary mine_reward_placement = payload.get("guard_reward_monster_placement", Dictionary());
		const int64_t rng_state_before_road_phase = int64_t(mine_reward_placement.get("treasure_reward_rng_state_after_0x4aa354_uint32", mine_reward_placement.get("mine_object_rng_state_after_0x4a9911_0x4a9641_uint32", runtime_build.get("rng_state_after_runtime_zone_build", int64_t(next_state)))));
		payload["road_coordinate_vector_source"] = coordinate_vector_source;
		payload["road_adapter_boundary"] = h3maped_road_adapter_boundary_from_connections(connection_records, terrain_fill, coordinate_vector_source, rng_state_before_road_phase);
		payload["path_state_seed_update_rule"] = h3maped_path_state_seed_4aae7b_report(terrain_fill, coordinate_vector_source);
		report["selected_template_payload"] = payload;
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

uint32_t h3maped_hash32_int(const String &text) {
	uint64_t value = 2166136261ULL;
	for (int64_t index = 0; index < text.length(); ++index) {
		value = (value ^ uint64_t(text.unicode_at(index))) % 0x100000000ULL;
		value = (value * 16777619ULL) % 0x100000000ULL;
	}
	return uint32_t(value);
}

String h3maped_hash32_hex(const String &text) {
	static constexpr const char *HEX_DIGITS = "0123456789abcdef";
	const uint32_t value = h3maped_hash32_int(text);
	String result;
	for (int index = 7; index >= 0; --index) {
		const uint32_t nibble = (value >> (index * 4)) & 0xfU;
		result += String::chr(HEX_DIGITS[nibble]);
	}
	return result;
}

String h3maped_level_point_key(int32_t x, int32_t y, int32_t level) {
	return String::num_int64(level) + ":" + String::num_int64(x) + "," + String::num_int64(y);
}

Dictionary h3maped_cell_record(int32_t x, int32_t y, int32_t level) {
	Dictionary cell;
	cell["x"] = x;
	cell["y"] = y;
	cell["level"] = level;
	return cell;
}

PackedStringArray h3maped_terrain_id_by_code() {
	PackedStringArray ids;
	ids.append("dirt");
	ids.append("sand");
	ids.append("grass");
	ids.append("snow");
	ids.append("swamp");
	ids.append("rough");
	ids.append("underground");
	ids.append("lava");
	ids.append("water");
	ids.append("rock");
	return ids;
}

String h3maped_biome_for_terrain_code(int32_t terrain_code) {
	const String terrain_id = terrain_for_h3maped_id(terrain_code);
	return terrain_id.is_empty() ? String("biome_unknown") : String("biome_") + terrain_id;
}

String h3maped_faction_for_owner(const Dictionary &normalized_config, int32_t owner_color) {
	Array faction_ids = normalized_config.get("faction_ids", Array());
	if (owner_color >= 0 && owner_color < faction_ids.size()) {
		return String(faction_ids[owner_color]);
	}
	static const char *DEFAULTS[] = {
		"faction_embercourt",
		"faction_mireclaw",
		"faction_sunvault",
		"faction_thornwake",
		"faction_brasshollow",
		"faction_veilmourn",
	};
	if (owner_color >= 0 && owner_color < int32_t(sizeof(DEFAULTS) / sizeof(DEFAULTS[0]))) {
		return DEFAULTS[owner_color];
	}
	return "faction_embercourt";
}

String h3maped_town_for_faction(const String &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "town_duskfen";
	}
	if (faction_id == "faction_sunvault") {
		return "town_prismhearth";
	}
	if (faction_id == "faction_thornwake") {
		return "town_thornwake_graftroot_caravan";
	}
	if (faction_id == "faction_brasshollow") {
		return "town_brasshollow_orevein_gantry";
	}
	if (faction_id == "faction_veilmourn") {
		return "town_veilmourn_bellwake_harbor";
	}
	return "town_riverwatch";
}

String h3maped_mine_object_id_for_subtype(int32_t subtype) {
	switch (subtype) {
		case 0:
			return "object_brightwood_sawmill";
		case 2:
			return "object_ironstep_ore_pit";
		case 4:
			return "object_marsh_peat_yard";
		case 6:
			return "object_cinder_ore_face";
		default:
			return "object_ridge_quarry";
	}
}

String h3maped_mine_category_for_subtype(int32_t subtype) {
	switch (subtype) {
		case 0:
			return "wood";
		case 1:
			return "mercury";
		case 2:
			return "ore";
		case 3:
			return "sulfur";
		case 4:
			return "crystal";
		case 5:
			return "gems";
		case 6:
			return "gold";
		default:
			return "unknown";
	}
}

Array h3maped_body_tiles_from_points(int32_t anchor_x, int32_t anchor_y, int32_t level, const std::vector<H3MaskPoint> &points, int32_t width, int32_t height) {
	Array tiles;
	for (const H3MaskPoint &point : points) {
		const int32_t x = anchor_x + point.dx;
		const int32_t y = anchor_y + point.dy;
		if (x < 0 || y < 0 || x >= width || y >= height) {
			continue;
		}
		tiles.append(h3maped_cell_record(x, y, level));
	}
	if (tiles.is_empty() && anchor_x >= 0 && anchor_y >= 0 && anchor_x < width && anchor_y < height) {
		tiles.append(h3maped_cell_record(anchor_x, anchor_y, level));
	}
	return tiles;
}

Dictionary h3maped_bounds_from_tiles(const Array &tiles, int32_t fallback_x, int32_t fallback_y) {
	int32_t min_x = fallback_x;
	int32_t min_y = fallback_y;
	int32_t max_x = fallback_x;
	int32_t max_y = fallback_y;
	bool initialized = false;
	for (int64_t index = 0; index < tiles.size(); ++index) {
		if (Variant(tiles[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary tile = Dictionary(tiles[index]);
		const int32_t x = int32_t(tile.get("x", fallback_x));
		const int32_t y = int32_t(tile.get("y", fallback_y));
		if (!initialized) {
			min_x = max_x = x;
			min_y = max_y = y;
			initialized = true;
		} else {
			min_x = std::min(min_x, x);
			min_y = std::min(min_y, y);
			max_x = std::max(max_x, x);
			max_y = std::max(max_y, y);
		}
	}
	Dictionary bounds;
	bounds["min_x"] = min_x;
	bounds["min_y"] = min_y;
	bounds["max_x"] = max_x;
	bounds["max_y"] = max_y;
	return bounds;
}

Array h3maped_occupancy_keys_for_tiles(const Array &tiles) {
	Array keys;
	for (int64_t index = 0; index < tiles.size(); ++index) {
		if (Variant(tiles[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary tile = Dictionary(tiles[index]);
		keys.append(h3maped_level_point_key(
				int32_t(tile.get("x", 0)),
				int32_t(tile.get("y", 0)),
				int32_t(tile.get("level", 0))));
	}
	return keys;
}

Dictionary h3maped_terrain_grid_from_fill(const Dictionary &normalized_config, const Dictionary &terrain_fill) {
	const int32_t width = int32_t(terrain_fill.get("width", normalized_config.get("width", 36)));
	const int32_t height = int32_t(terrain_fill.get("height", normalized_config.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", normalized_config.get("level_count", 1))));
	PackedInt32Array terrain_codes = terrain_fill.get("terrain_code_u16", PackedInt32Array());
	if (terrain_codes.size() != width * height) {
		terrain_codes.resize(width * height);
		for (int32_t index = 0; index < width * height; ++index) {
			terrain_codes.set(index, 8);
		}
	}
	PackedInt32Array tile_byte_0 = terrain_fill.get("tile_byte_0_terrain_id_u8", PackedInt32Array());
	PackedInt32Array tile_byte_1 = terrain_fill.get("tile_byte_1_terrain_art_u8", PackedInt32Array());
	PackedInt32Array tile_byte_2 = terrain_fill.get("tile_byte_2_river_type_u8", PackedInt32Array());
	PackedInt32Array tile_byte_3 = terrain_fill.get("tile_byte_3_river_art_u8", PackedInt32Array());
	PackedInt32Array tile_byte_4 = terrain_fill.get("tile_byte_4_road_type_u8", PackedInt32Array());
	PackedInt32Array tile_byte_5 = terrain_fill.get("tile_byte_5_road_art_u8", PackedInt32Array());
	PackedInt32Array tile_byte_6 = terrain_fill.get("tile_byte_6_terrain_flags_u8", PackedInt32Array());
	if (tile_byte_0.size() != width * height) {
		tile_byte_0 = terrain_codes;
	}
	if (tile_byte_1.size() != width * height) {
		tile_byte_1.resize(width * height);
	}
	if (tile_byte_2.size() != width * height) {
		tile_byte_2.resize(width * height);
	}
	if (tile_byte_3.size() != width * height) {
		tile_byte_3.resize(width * height);
	}
	if (tile_byte_4.size() != width * height) {
		tile_byte_4.resize(width * height);
	}
	if (tile_byte_5.size() != width * height) {
		tile_byte_5.resize(width * height);
	}
	if (tile_byte_6.size() != width * height) {
		tile_byte_6.resize(width * height);
	}
	Dictionary terrain_counts;
	Dictionary biome_counts;
	for (int32_t index = 0; index < terrain_codes.size(); ++index) {
		const int32_t code = terrain_codes[index] & 0x3f;
		const String terrain_id = terrain_for_h3maped_id(code);
		if (!terrain_id.is_empty()) {
			terrain_counts[terrain_id] = int32_t(terrain_counts.get(terrain_id, 0)) + 1;
		}
		const String biome_id = h3maped_biome_for_terrain_code(code);
		biome_counts[biome_id] = int32_t(biome_counts.get(biome_id, 0)) + 1;
	}
	Dictionary level_record;
	level_record["level_index"] = 0;
	level_record["level_kind"] = "surface";
	level_record["width"] = width;
	level_record["height"] = height;
	level_record["tile_count"] = width * height;
	level_record["terrain_code_u16"] = terrain_codes;
	level_record["tile_byte_0_terrain_id_u8"] = tile_byte_0;
	level_record["tile_byte_1_terrain_art_u8"] = tile_byte_1;
	level_record["tile_byte_2_river_type_u8"] = tile_byte_2;
	level_record["tile_byte_3_river_art_u8"] = tile_byte_3;
	level_record["tile_byte_4_road_type_u8"] = tile_byte_4;
	level_record["tile_byte_5_road_art_u8"] = tile_byte_5;
	level_record["tile_byte_6_flags_u8"] = tile_byte_6;
	level_record["tile_byte_writeout_status"] = terrain_fill.get("tile_byte_writeout_status", "0x49b2b6_terrain_bytes_packed_overlay_bytes_pending");
	level_record["tile_byte_overlay_status"] = terrain_fill.get("tile_byte_overlay_status", "road_and_river_overlay_bytes_pending");
	level_record["terrain_counts"] = terrain_counts;
	level_record["biome_counts"] = biome_counts;
	level_record["h3maped_source_status"] = terrain_fill.get("status", "");
	level_record["signature"] = h3maped_hash32_hex(String("h3maped_terrain_level:") + String::num_int64(width) + ":" + String::num_int64(height) + ":" + String::num_int64(terrain_codes.size()) + ":" + String::num_int64(int32_t(terrain_counts.keys().size())));
	Array levels;
	levels.append(level_record);

	Dictionary grid;
	grid["schema_id"] = "aurelion_native_rmg_terrain_grid_v1";
	grid["schema_version"] = 1;
	grid["generation_status"] = "h3maped_0x4a3f27_terrain_grid_materialized_from_clean_port";
	grid["full_generation_status"] = "h3maped_small_phase_materialized_partial_roads_rewards_guards_pending";
	grid["width"] = width;
	grid["height"] = height;
	grid["level_count"] = level_count;
	grid["tile_count"] = width * height * level_count;
	grid["terrain_id_by_code"] = h3maped_terrain_id_by_code();
	grid["terrain_palette_ids"] = Array();
	grid["terrain_counts"] = terrain_counts;
	grid["levels"] = levels;
	grid["tile_byte_writeout_status"] = level_record.get("tile_byte_writeout_status", "");
	grid["tile_byte_overlay_status"] = level_record.get("tile_byte_overlay_status", "");
	grid["materialized_level_count"] = levels.size();
	grid["level_count_semantics"] = "h3maped_small_surface_level_materialized_only";
	grid["signature"] = h3maped_hash32_hex(String("h3maped_terrain_grid:") + String::num_int64(width) + ":" + String::num_int64(height) + ":" + String::num_int64(level_count) + ":" + String(level_record["signature"]));
	return grid;
}

Array h3maped_town_records_from_port(const Dictionary &normalized_config, const Dictionary &payload) {
	Array result;
	Dictionary town_castle = payload.get("town_castle_placement", Dictionary());
	Array source_records = town_castle.get("direct_town_records", Array());
	Dictionary object_metadata = town_castle.get("object_metadata_table", Dictionary());
	Array town_template_rows = object_metadata.get("town_template_rows", Array());
	std::vector<H3MaskPoint> town_body_points;
	if (!town_template_rows.is_empty() && Variant(town_template_rows[0]).get_type() == Variant::DICTIONARY) {
		town_body_points = h3_text_mask_points(String(Dictionary(town_template_rows[0]).get("passability_mask", "")), false);
	}
	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	for (int64_t index = 0; index < source_records.size(); ++index) {
		if (Variant(source_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary source = Dictionary(source_records[index]);
		const int32_t owner_color = int32_t(source.get("owner_color", -1));
		const int32_t owner_slot = owner_color >= 0 ? owner_color + 1 : -1;
		const int32_t x = int32_t(source.get("x", 0));
		const int32_t y = int32_t(source.get("y", 0));
		const int32_t level = int32_t(source.get("level", 0));
		const int32_t runtime_zone_index = int32_t(source.get("runtime_zone_index", -1));
		const String faction_id = h3maped_faction_for_owner(normalized_config, owner_color);
		const String placement_id = owner_color >= 0
				? String("h3maped_small_town_player_") + String::num_int64(owner_slot)
				: String("h3maped_small_town_neutral_") + String::num_int64(index + 1);
		Array body_tiles = h3maped_body_tiles_from_points(x, y, level, town_body_points, width, height);
		Array occupancy_keys = h3maped_occupancy_keys_for_tiles(body_tiles);
		Dictionary record;
		record["placement_id"] = placement_id;
		record["record_type"] = bool(source.get("castle", false)) ? "h3maped_player_minimum_castle" : "h3maped_player_minimum_town";
		record["kind"] = "town";
		record["town_id"] = h3maped_town_for_faction(faction_id);
		record["family_id"] = "town_primary";
		record["object_family_id"] = "town_primary";
		record["type_id"] = "town";
		record["faction_id"] = faction_id;
		record["owner"] = owner_color < 0 ? String("neutral") : (owner_color == 0 ? String("player") : String("enemy"));
		record["owner_color"] = owner_color;
		record["owner_slot"] = owner_slot;
		record["player_slot"] = owner_slot;
		record["player_type"] = owner_color < 0 ? String("neutral") : (owner_color == 0 ? String("human") : String("computer"));
		record["zone_id"] = String("runtime_zone_") + String::num_int64(runtime_zone_index);
		record["runtime_zone_index"] = runtime_zone_index;
		record["source_zone_id"] = source.get("source_zone_id", -1);
		record["x"] = x;
		record["y"] = y;
		record["level"] = level;
		record["primary_tile"] = h3maped_cell_record(x, y, level);
		record["primary_occupancy_key"] = h3maped_level_point_key(x, y, level);
		record["bounds"] = h3maped_bounds_from_tiles(body_tiles, x, y);
		record["body_tiles"] = body_tiles;
		record["occupancy_keys"] = occupancy_keys;
		Dictionary footprint;
		footprint["width"] = 6;
		footprint["height"] = 6;
		footprint["anchor"] = "h3_object_mask_anchor";
		footprint["tier"] = "town";
		footprint["source"] = "h3maped objects.txt passability mask";
		record["footprint"] = footprint;
		record["runtime_footprint"] = footprint;
		record["footprint_deferred"] = false;
		record["visit_tile"] = h3maped_cell_record(x, y, level);
		record["approach_tiles"] = Array();
		record["is_start_town"] = owner_color >= 0;
		record["is_castle"] = bool(source.get("castle", false));
		record["is_capital"] = owner_color >= 0;
		record["settlement_category"] = bool(source.get("castle", false)) ? "castle" : "town";
		record["owner_semantics"] = owner_color >= 0 ? "mapped_h3maped_player_owner_color" : "neutral_owner_minus_one";
		record["h3maped_source"] = source;
		record["materialization_state"] = "h3maped_0x4a93a2_town_record_adopted_to_package";
		record["writeout_state"] = "staged_no_authored_content_writeback";
		record["signature"] = h3maped_hash32_hex(placement_id + String(":") + String::num_int64(x) + String(":") + String::num_int64(y) + String(":") + String::num_int64(level));
		result.append(record);
	}
	return result;
}

Array h3maped_mine_records_from_port(const Dictionary &normalized_config, const Dictionary &payload) {
	Array result;
	Dictionary mine_reward = payload.get("guard_reward_monster_placement", Dictionary());
	Array helper_calls = mine_reward.get("mine_minimum_helper_calls", Array());
	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	for (int64_t index = 0; index < helper_calls.size(); ++index) {
		if (Variant(helper_calls[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary helper = Dictionary(helper_calls[index]);
		if (!helper.has("placement_constraint_selected_x")) {
			continue;
		}
		const int32_t x = int32_t(helper.get("placement_constraint_selected_x", 0));
		const int32_t y = int32_t(helper.get("placement_constraint_selected_y", 0));
		const int32_t level = int32_t(helper.get("placement_constraint_selected_level", 0));
		const int32_t subtype = int32_t(helper.get("mine_subtype", -1));
		Array body_tiles = helper.get("placement_constraint_marked_body_cell_preview", Array());
		if (body_tiles.is_empty()) {
			body_tiles.append(h3maped_cell_record(std::clamp(x, 0, width - 1), std::clamp(y, 0, height - 1), level));
		}
		const String placement_id = String("h3maped_small_mine_") + String::num_int64(index + 1);
		Dictionary record;
		record["placement_id"] = placement_id;
		record["kind"] = "mine";
		record["family_id"] = "mine";
		record["object_family_id"] = "mine";
		record["type_id"] = "mine";
		record["object_id"] = h3maped_mine_object_id_for_subtype(subtype);
		record["site_id"] = record["object_id"];
		record["category_id"] = "mine";
		record["zone_id"] = String("runtime_zone_") + String::num_int64(int32_t(helper.get("runtime_zone_index", -1)));
		record["runtime_zone_index"] = helper.get("runtime_zone_index", -1);
		record["source_zone_id"] = helper.get("source_zone_id", -1);
		record["mine_subtype"] = subtype;
		record["mine_category_id"] = h3maped_mine_category_for_subtype(subtype);
		record["terrain_id"] = terrain_for_h3maped_id(int32_t(helper.get("runtime_h3maped_terrain_id", -1)));
		record["x"] = x;
		record["y"] = y;
		record["level"] = level;
		record["primary_tile"] = h3maped_cell_record(x, y, level);
		record["primary_occupancy_key"] = h3maped_level_point_key(x, y, level);
		record["bounds"] = h3maped_bounds_from_tiles(body_tiles, x, y);
		record["body_tiles"] = body_tiles;
		record["occupancy_keys"] = h3maped_occupancy_keys_for_tiles(body_tiles);
		Dictionary footprint;
		footprint["width"] = 6;
		footprint["height"] = 6;
		footprint["anchor"] = "h3_object_mask_anchor";
		footprint["tier"] = "mine";
		footprint["source"] = "selected h3maped objects.txt mine template mask";
		record["footprint"] = footprint;
		record["runtime_footprint"] = footprint;
		record["footprint_deferred"] = false;
		record["visit_tile"] = h3maped_cell_record(x, y, level);
		record["approach_tiles"] = Array();
		record["selected_template_def_name"] = helper.get("selected_template_def_name", "");
		record["selected_template_source_line"] = helper.get("selected_template_source_line", -1);
		record["h3maped_phase"] = "0x4a9911_0x4a9641";
		record["h3maped_placement_status"] = helper.get("placement_constraint_status", "");
		record["h3maped_helper_record"] = helper;
		record["materialization_state"] = "h3maped_0x4a9911_0x4a9641_mine_record_adopted_to_package";
		record["writeout_state"] = "staged_no_authored_content_writeback";
		record["signature"] = h3maped_hash32_hex(placement_id + String(":") + String::num_int64(x) + String(":") + String::num_int64(y) + String(":") + String::num_int64(level) + String(":") + String::num_int64(subtype));
		result.append(record);
	}
	return result;
}

Array h3maped_connection_records_from_port(const Dictionary &payload, const Dictionary &normalized_config) {
	Array result;
	Dictionary runtime_build = payload.get("runtime_zone_build", Dictionary());
	Array link_seeds = runtime_build.get("link_seeds", Array());
	for (int64_t index = 0; index < link_seeds.size(); ++index) {
		if (Variant(link_seeds[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary seed = Dictionary(link_seeds[index]);
		const int32_t raw_guard_value = int32_t(seed.get("guard_value", 0));
		const bool wide = bool(seed.get("wide", false));
		const bool border_guard = bool(seed.get("border_guard", false));
		const int32_t normal_guard_value_before_scaling = wide ? 0 : raw_guard_value;
		const int32_t normal_guard_scaled_value = wide ? 0 : h3maped_strength_scaled_value_4a65a5(raw_guard_value, h3maped_global_monster_strength_mode(normalized_config));
		Dictionary record;
		record["connection_id"] = String("h3maped_small_connection_") + String::num_int64(index + 1);
		record["link_index"] = seed.get("link_index", index);
		record["source_endpoint_a"] = seed.get("source_endpoint_a", -1);
		record["source_endpoint_b"] = seed.get("source_endpoint_b", -1);
		record["runtime_zone_a"] = seed.get("runtime_zone_a", -1);
		record["runtime_zone_b"] = seed.get("runtime_zone_b", -1);
		record["raw_guard_value"] = raw_guard_value;
		record["wide"] = wide;
		record["border_guard"] = border_guard;
		record["normal_guard_value_status"] = wide ? String("suppressed_by_link_plus_0x08_wide") : String("0x4a65a5_value_scaled_guard_object_pending");
		record["normal_guard_value_before_0x4a65a5"] = normal_guard_value_before_scaling;
		record["normal_guard_global_strength_mode"] = h3maped_global_monster_strength_mode(normalized_config);
		record["normal_guard_scaled_value"] = normal_guard_scaled_value;
		record["border_guard_status"] = border_guard ? String("pending_0x4a5e73_0x4a5a23_type_9_materialization") : String("not_a_border_guard_link");
		record["geometry_status"] = "pending_0x4a61bc_0x4a696b_0x4a6cf2_0x4a7605_connection_geometry";
		record["road_status"] = "h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending";
		record["h3maped_phase"] = "0x4a79a3_link_payload_semantics";
		record["h3maped_source"] = seed;
		record["signature"] = h3maped_hash32_hex(String(record["connection_id"]) + String(":") + String::num_int64(int32_t(record["runtime_zone_a"])) + String(":") + String::num_int64(int32_t(record["runtime_zone_b"])) + String(":") + String::num_int64(raw_guard_value) + String(":") + String::num_int64(wide ? 1 : 0) + String(":") + String::num_int64(border_guard ? 1 : 0));
		result.append(record);
	}
	return result;
}

Dictionary h3maped_connection_payload_from_records(const Array &connection_records, const Dictionary &normalized_config) {
	Dictionary connection_payload;
	connection_payload["schema_id"] = "aurelion_h3maped_small_connection_payload_v1";
	connection_payload["generation_status"] = "h3maped_0x4a79a3_link_payload_semantics_ported_geometry_roads_guards_pending";
	connection_payload["h3maped_phase"] = "0x4a79a3";
	connection_payload["source"] = "Recovered h3maped link Value/Wide/Border Guard semantics from raw 0x1c link records";
	connection_payload["connection_records"] = connection_records;
	connection_payload["connection_count"] = connection_records.size();
	int32_t raw_guard_link_count = 0;
	int32_t wide_suppressed_count = 0;
	int32_t border_guard_count = 0;
	int32_t normal_guard_scaled_nonzero_count = 0;
	int32_t normal_guard_scaled_value_total = 0;
	for (int64_t index = 0; index < connection_records.size(); ++index) {
		if (Variant(connection_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary record = Dictionary(connection_records[index]);
		if (int32_t(record.get("raw_guard_value", 0)) > 0) {
			raw_guard_link_count += 1;
		}
		if (bool(record.get("wide", false))) {
			wide_suppressed_count += 1;
		}
		if (bool(record.get("border_guard", false))) {
			border_guard_count += 1;
		}
		const int32_t scaled_value = int32_t(record.get("normal_guard_scaled_value", 0));
		if (scaled_value > 0) {
			normal_guard_scaled_nonzero_count += 1;
			normal_guard_scaled_value_total += scaled_value;
		}
	}
	connection_payload["raw_guard_link_count"] = raw_guard_link_count;
	connection_payload["wide_suppressed_normal_guard_count"] = wide_suppressed_count;
	connection_payload["border_guard_link_count"] = border_guard_count;
	connection_payload["normal_guard_global_strength_mode"] = h3maped_global_monster_strength_mode(normalized_config);
	connection_payload["normal_guard_scaled_nonzero_count"] = normal_guard_scaled_nonzero_count;
	connection_payload["normal_guard_scaled_value_total"] = normal_guard_scaled_value_total;
	connection_payload["normal_guard_materialization_status"] = "0x4a65a5_values_scaled_0x4a5e03_guard_object_pending";
	connection_payload["border_guard_materialization_status"] = "pending_0x4a5e73_0x4a5a23_type_9_border_guard";
	connection_payload["road_materialization_status"] = "h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending";
	connection_payload["full_generation_status"] = "h3maped_connection_payload_known_geometry_roads_guards_pending";
	connection_payload["signature"] = h3maped_hash32_hex(String("h3maped_connection_payload:") + String::num_int64(connection_records.size()) + String(":") + String::num_int64(raw_guard_link_count) + String(":") + String::num_int64(wide_suppressed_count) + String(":") + String::num_int64(border_guard_count));
	return connection_payload;
}

Dictionary h3maped_path_state_reset_4aae2f_report(const Dictionary &terrain_fill) {
	const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
	const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t tile_count = width * height * level_count;
	PackedInt32Array predecessor_x;
	PackedInt32Array predecessor_y;
	PackedInt32Array predecessor_level;
	PackedInt32Array path_cost_low_word;
	PackedInt32Array materialized_bit25;
	predecessor_x.resize(tile_count);
	predecessor_y.resize(tile_count);
	predecessor_level.resize(tile_count);
	path_cost_low_word.resize(tile_count);
	materialized_bit25.resize(tile_count);
	PackedInt32Array repaint_grid = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array());
	for (int32_t index = 0; index < tile_count; ++index) {
		predecessor_x.set(index, -1);
		predecessor_y.set(index, -1);
		predecessor_level.set(index, -1);
		path_cost_low_word.set(index, 0x7d00);
		materialized_bit25.set(index, index < repaint_grid.size() && int32_t(repaint_grid[index]) != 0 ? 1 : 0);
	}
	Dictionary reset;
	reset["schema_id"] = "aurelion_h3maped_small_road_path_state_reset_v1";
	reset["status"] = "h3maped_0x4aae2f_path_state_reset_grid_materialized_road_seed_pending";
	reset["function_address"] = "0x4aae2f";
	reset["source"] = "Recovered from h3maped.exe: loop width*height*levels over generated cells, write -1 to cell+0x10/+0x14/+0x18, and force cell+0x1c low word to 0x7d00 while preserving the upper word.";
	reset["generated_cell_base_offset"] = "generator+0x14";
	reset["generated_cell_stride_bytes"] = 0x30;
	reset["generated_cell_count_source"] = "generator+0x18 * generator+0x1c * generator+0x20";
	reset["width"] = width;
	reset["height"] = height;
	reset["level_count"] = level_count;
	reset["reset_cell_count"] = tile_count;
	reset["coordinate_chain_offsets"] = Array::make("+0x10", "+0x14", "+0x18");
	reset["coordinate_chain_after_reset"] = Array::make(-1, -1, -1);
	reset["cell_state_offset"] = "+0x1c";
	reset["cell_state_low_word_and_mask_hex"] = "0x7d00";
	reset["cell_state_high_byte_or_hex"] = "0x7d";
	reset["cell_state_low_word_after_reset_hex"] = "0x7d00";
	reset["cell_state_low_word_after_reset"] = 0x7d00;
	reset["preserves_cell_state_upper_word"] = true;
	reset["predecessor_x_i32"] = predecessor_x;
	reset["predecessor_y_i32"] = predecessor_y;
	reset["predecessor_level_i32"] = predecessor_level;
	reset["path_cost_low_word_u16"] = path_cost_low_word;
	reset["materialized_bit25_grid_u8"] = materialized_bit25;
	reset["predecessor_array_count"] = predecessor_x.size();
	reset["path_cost_array_count"] = path_cost_low_word.size();
	reset["materialized_bit25_count"] = materialized_bit25.size();
	reset["materialized_bit25_source"] = "carried from 0x4a325d/0x4a3f27 zone repaint-member grid as the current clean generated-cell materialization boundary";
	reset["path_seed_status_after_reset"] = "pending_0x4aae7b_coordinate_vector_seed";
	reset["road_toolkit_status_after_reset"] = "pending_0x4b4243_road_toolkit_port";
	reset["signature"] = h3maped_hash32_hex(String("h3maped_4aae2f_path_state_reset:")
			+ String::num_int64(width) + ":"
			+ String::num_int64(height) + ":"
			+ String::num_int64(level_count) + ":"
			+ String::num_int64(tile_count));
	return reset;
}

Dictionary h3maped_path_state_seed_4aae7b_report(const Dictionary &terrain_fill, const Dictionary &coordinate_vector_source) {
	const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
	const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t partial_record_count = int32_t(coordinate_vector_source.get("materialized_partial_coordinate_record_count", 0));
	constexpr int32_t direction_count = 8;
	constexpr int32_t direction_dx[direction_count] = { 1, 1, 0, -1, -1, -1, 0, 1 };
	constexpr int32_t direction_dy[direction_count] = { 0, 1, 1, 1, 0, -1, -1, -1 };
	constexpr const char *direction_addresses[direction_count] = {
		"0x5a2658", "0x5a2660", "0x5a2668", "0x5a2670",
		"0x5a2678", "0x5a2680", "0x5a2688", "0x5a2690"
	};
	Array direction_records;
	PackedInt32Array direction_dx_array;
	PackedInt32Array direction_dy_array;
	for (int32_t direction_index = 0; direction_index < direction_count; ++direction_index) {
		Dictionary direction;
		direction["index"] = direction_index;
		direction["address"] = direction_addresses[direction_index];
		direction["dx"] = direction_dx[direction_index];
		direction["dy"] = direction_dy[direction_index];
		direction["initializer_address"] = "0x499db3..0x499e20";
		direction_records.append(direction);
		direction_dx_array.append(direction_dx[direction_index]);
		direction_dy_array.append(direction_dy[direction_index]);
	}
	Array coordinate_records = coordinate_vector_source.get("materialized_partial_coordinate_records", Array());
	Array seed_initializations;
	Array propagation_summaries;
	Array candidate_low_words;
	Array predecessor_chain_records;
	PackedInt32Array first_seed_path_costs;
	PackedInt32Array first_seed_predecessor_x;
	PackedInt32Array first_seed_predecessor_y;
	PackedInt32Array first_seed_predecessor_level;
	const int32_t tile_count = width * height * level_count;
	const int32_t expected_grid_size = tile_count;
	PackedInt32Array repaint_grid = terrain_fill.get("zone_repaint_member_grid_u8", PackedInt32Array());
	PackedInt32Array terrain_codes = terrain_fill.get("terrain_code_u16", PackedInt32Array());
	const bool propagation_grid_available = width > 0
			&& height > 0
			&& level_count > 0
			&& repaint_grid.size() == expected_grid_size
			&& terrain_codes.size() == expected_grid_size;
	int32_t total_candidate_low_word_count = 0;
	int32_t total_candidate_accept_count = 0;
	int32_t total_reached_cell_count = 0;
	int32_t total_relaxed_edge_count = 0;
	int32_t total_predecessor_chain_cell_visits = 0;
	int32_t max_predecessor_chain_step_count = 0;
	const int32_t seed_initialization_count = std::max(0, partial_record_count - 1);
	for (int32_t seed_index = 0; seed_index < seed_initialization_count && seed_index < coordinate_records.size(); ++seed_index) {
		if (Variant(coordinate_records[seed_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary coordinate = Dictionary(coordinate_records[seed_index]);
		const int32_t x = int32_t(coordinate.get("x", -1));
		const int32_t y = int32_t(coordinate.get("y", -1));
		const int32_t level = int32_t(coordinate.get("level", -1));
		const bool in_bounds = x >= 0 && x < width && y >= 0 && y < height && level >= 0 && level < level_count;
		const int32_t flat_index = in_bounds ? ((level * height + y) * width + x) : -1;
		Dictionary item;
		item["seed_vector_index"] = seed_index;
		item["seed_byte_offset"] = seed_index * 12;
		item["source_placement_id"] = coordinate.get("source_placement_id", "");
		item["source_kind"] = coordinate.get("source_kind", "");
		item["x"] = x;
		item["y"] = y;
		item["level"] = level;
		item["flat_cell_index"] = flat_index;
		item["in_bounds"] = in_bounds;
		item["seed_write_block"] = "0x4aaedc..0x4aaf0e";
		item["path_cost_low_word_after_seed"] = 0;
		item["predecessor_after_seed"] = Array::make(-1, -1, -1);
		item["materializes_neighbor_propagation"] = false;
		seed_initializations.append(item);

		if (!propagation_grid_available || !in_bounds) {
			continue;
		}
		PackedInt32Array costs;
		PackedInt32Array predecessor_x;
		PackedInt32Array predecessor_y;
		PackedInt32Array predecessor_level;
		costs.resize(tile_count);
		predecessor_x.resize(tile_count);
		predecessor_y.resize(tile_count);
		predecessor_level.resize(tile_count);
		std::vector<uint8_t> queued(size_t(tile_count), 0);
		std::vector<int32_t> queue;
		queue.reserve(size_t(tile_count));
		for (int32_t index = 0; index < tile_count; ++index) {
			costs.set(index, 0x7d00);
			predecessor_x.set(index, -1);
			predecessor_y.set(index, -1);
			predecessor_level.set(index, -1);
		}
		costs.set(flat_index, 0);
		queue.push_back(flat_index);
		queued[size_t(flat_index)] = 1;
		int32_t relaxed_edges = 0;
		for (size_t cursor = 0; cursor < queue.size(); ++cursor) {
			const int32_t current_flat = queue[cursor];
			queued[size_t(current_flat)] = 0;
			const int32_t current_x = current_flat % width;
			const int32_t current_y = (current_flat / width) % height;
			const int32_t current_level = current_flat / (width * height);
			const int32_t current_cost = int32_t(costs[current_flat]) & 0xffff;
			for (int32_t direction_index = direction_count - 1; direction_index >= 0; --direction_index) {
				const int32_t nx = current_x + direction_dx[direction_index];
				const int32_t ny = current_y + direction_dy[direction_index];
				const int32_t nl = current_level;
				if (nx < 0 || ny < 0 || nx >= width || ny >= height || nl < 0 || nl >= level_count) {
					continue;
				}
				const int32_t target_flat = ((nl * height + ny) * width + nx);
				const int32_t terrain_class = int32_t(terrain_codes[target_flat]) & 0x3f;
				if (terrain_class == 8 || terrain_class == 9 || int32_t(repaint_grid[target_flat]) == 0) {
					continue;
				}
				const int32_t step_cost = (direction_index & 1) != 0 ? 0x3c : 0x14;
				const int32_t computed_cost = current_cost + step_cost;
				if (computed_cost >= (int32_t(costs[target_flat]) & 0xffff)) {
					continue;
				}
				costs.set(target_flat, computed_cost);
				predecessor_x.set(target_flat, current_x);
				predecessor_y.set(target_flat, current_y);
				predecessor_level.set(target_flat, current_level);
				relaxed_edges += 1;
				if (queued[size_t(target_flat)] == 0) {
					queue.push_back(target_flat);
					queued[size_t(target_flat)] = 1;
				}
			}
		}
		int32_t reached_cells = 0;
		int32_t max_reached_cost = 0;
		for (int32_t index = 0; index < tile_count; ++index) {
			const int32_t cell_cost = int32_t(costs[index]) & 0xffff;
			if (cell_cost != 0x7d00) {
				reached_cells += 1;
				max_reached_cost = std::max(max_reached_cost, cell_cost);
			}
		}
		total_reached_cell_count += reached_cells;
		total_relaxed_edge_count += relaxed_edges;
		Dictionary propagation;
		propagation["seed_vector_index"] = seed_index;
		propagation["seed_flat_cell_index"] = flat_index;
		propagation["normal_neighbor_update_block"] = "0x4ab2d8..0x4ab33a";
		propagation["direction_iteration_order"] = "0x4ab060 decrements index 7..0 over 0x5a2658";
		propagation["reached_cell_count"] = reached_cells;
		propagation["relaxed_edge_count"] = relaxed_edges;
		propagation["max_reached_path_cost_low_word"] = max_reached_cost;
		propagation["special_vector_updates_materialized"] = false;
		Array candidate_preview;
		for (int32_t candidate_index = seed_index + 1; candidate_index < partial_record_count && candidate_index < coordinate_records.size(); ++candidate_index) {
			if (Variant(coordinate_records[candidate_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary candidate_coordinate = Dictionary(coordinate_records[candidate_index]);
			const int32_t cx = int32_t(candidate_coordinate.get("x", -1));
			const int32_t cy = int32_t(candidate_coordinate.get("y", -1));
			const int32_t cl = int32_t(candidate_coordinate.get("level", -1));
			const bool candidate_in_bounds = cx >= 0 && cx < width && cy >= 0 && cy < height && cl >= 0 && cl < level_count;
			const int32_t candidate_flat = candidate_in_bounds ? ((cl * height + cy) * width + cx) : -1;
			const int32_t candidate_low_word = candidate_in_bounds ? (int32_t(costs[candidate_flat]) & 0xffff) : 0x7d00;
			const bool accepted = candidate_low_word <= 0x7530;
			Dictionary candidate;
			candidate["seed_vector_index"] = seed_index;
			candidate["candidate_vector_index"] = candidate_index;
			candidate["candidate_flat_cell_index"] = candidate_flat;
			candidate["candidate_low_word"] = candidate_low_word;
			candidate["candidate_accept_threshold"] = 0x7530;
			candidate["candidate_accepts_0x4ab52a"] = accepted;
			candidate["in_bounds"] = candidate_in_bounds;
			total_candidate_low_word_count += 1;
			if (accepted) {
				total_candidate_accept_count += 1;
				Dictionary chain;
				chain["seed_vector_index"] = seed_index;
				chain["candidate_vector_index"] = candidate_index;
				chain["seed_flat_cell_index"] = flat_index;
				chain["candidate_flat_cell_index"] = candidate_flat;
				chain["seed_coordinate_triplet"] = coordinate.get("coordinate_triplet", Array::make(x, y, level));
				chain["candidate_coordinate_triplet"] = candidate_coordinate.get("coordinate_triplet", Array::make(cx, cy, cl));
				chain["candidate_low_word"] = candidate_low_word;
				chain["predecessor_offsets"] = Array::make("+0x10", "+0x14", "+0x18");
				chain["path_cost_offset"] = "+0x1c";
				chain["walk_semantics"] = "0x4ab37f follows cell+0x10/+0x14/+0x18 predecessor coordinates while cell+0x1c low word remains nonzero";
				chain["road_cell_mutation_materialized"] = false;
				chain["candidate_mark_write_materialized"] = false;
				Array reverse_trace_preview;
				PackedInt32Array predecessor_chain_flat_cells;
				int32_t trace_flat = candidate_flat;
				int32_t step_count = 0;
				bool reached_seed = trace_flat == flat_index;
				bool broken_chain = false;
				const int32_t max_trace_steps = tile_count + 1;
				while (!reached_seed && !broken_chain && trace_flat >= 0 && trace_flat < tile_count && step_count < max_trace_steps) {
					const int32_t trace_x = trace_flat % width;
					const int32_t trace_y = (trace_flat / width) % height;
					const int32_t trace_level = trace_flat / (width * height);
					predecessor_chain_flat_cells.append(trace_flat);
					if (reverse_trace_preview.size() < 16) {
						Dictionary trace_cell;
						trace_cell["flat_cell_index"] = trace_flat;
						trace_cell["x"] = trace_x;
						trace_cell["y"] = trace_y;
						trace_cell["level"] = trace_level;
						trace_cell["path_cost_low_word"] = int32_t(costs[trace_flat]) & 0xffff;
						reverse_trace_preview.append(trace_cell);
					}
					const int32_t px = int32_t(predecessor_x[trace_flat]);
					const int32_t py = int32_t(predecessor_y[trace_flat]);
					const int32_t pl = int32_t(predecessor_level[trace_flat]);
					if (px < 0 || py < 0 || pl < 0 || px >= width || py >= height || pl >= level_count) {
						broken_chain = true;
						break;
					}
					trace_flat = ((pl * height + py) * width + px);
					step_count += 1;
					reached_seed = trace_flat == flat_index;
				}
				if (reached_seed && reverse_trace_preview.size() < 16) {
					Dictionary seed_trace_cell;
					seed_trace_cell["flat_cell_index"] = flat_index;
					seed_trace_cell["x"] = x;
					seed_trace_cell["y"] = y;
					seed_trace_cell["level"] = level;
					seed_trace_cell["path_cost_low_word"] = 0;
					reverse_trace_preview.append(seed_trace_cell);
				}
				if (reached_seed) {
					predecessor_chain_flat_cells.append(flat_index);
				}
				chain["predecessor_chain_status"] = reached_seed
						? "h3maped_0x4ab37f_predecessor_chain_reaches_seed"
						: (broken_chain ? "h3maped_0x4ab37f_predecessor_chain_broken" : "h3maped_0x4ab37f_predecessor_chain_guard_limit_hit");
				chain["predecessor_chain_reaches_seed"] = reached_seed;
				chain["predecessor_chain_step_count"] = step_count;
				chain["predecessor_chain_flat_cells"] = predecessor_chain_flat_cells;
				chain["predecessor_chain_flat_cell_count"] = predecessor_chain_flat_cells.size();
				chain["reverse_trace_preview"] = reverse_trace_preview;
				total_predecessor_chain_cell_visits += step_count + 1;
				max_predecessor_chain_step_count = std::max(max_predecessor_chain_step_count, step_count);
				predecessor_chain_records.append(chain);
			}
			if (candidate_preview.size() < 6) {
				candidate_preview.append(candidate);
			}
			candidate_low_words.append(candidate);
		}
		propagation["candidate_low_word_preview"] = candidate_preview;
		propagation_summaries.append(propagation);
		if (seed_index == 0) {
			first_seed_path_costs = costs;
			first_seed_predecessor_x = predecessor_x;
			first_seed_predecessor_y = predecessor_y;
			first_seed_predecessor_level = predecessor_level;
		}
	}
	Dictionary seed;
	seed["schema_id"] = "aurelion_h3maped_small_road_path_state_seed_v1";
	seed["status"] = "h3maped_0x4aae7b_path_state_seed_boundary_recovered_toolkit_pending";
	seed["function_address"] = "0x4aae7b";
	seed["source"] = "Recovered from h3maped.exe: ecx is the generator, the stack argument is one 12-byte coordinate record, the seed cell is reset, then queue/vector-backed neighbor propagation writes low-word path costs and predecessor coordinates into generated cells before 0x4ab37f/0x4b4243 materializes roads.";
	seed["generator_argument_register"] = "ecx";
	seed["coordinate_argument_size_bytes"] = 12;
	seed["coordinate_argument_stack_offsets"] = Array::make("ebp+0x08", "ebp+0x0c", "ebp+0x10");
	seed["coordinate_record_byte_11_seed_tag_source"] = "ebp+0x13";
	seed["local_queue_primary_stack_base"] = "ebp-0x78";
	seed["local_queue_secondary_stack_base"] = "ebp-0x88";
	seed["queue_push_helper_address"] = "0x4a489d";
	seed["queue_seed_helper_address"] = "0x4ae20e";
	seed["queue_pop_helper_address"] = "0x4ae23e";
	seed["secondary_queue_remove_helper_address"] = "0x4cce95";
	seed["generated_cell_base_offset"] = "generator+0x14";
	seed["generated_cell_stride_bytes"] = 0x30;
	seed["width"] = width;
	seed["height"] = height;
	seed["level_count"] = level_count;
	seed["partial_coordinate_record_count"] = partial_record_count;
	seed["complete_coordinate_vector_required"] = true;
	seed["complete_coordinate_vector_claim"] = false;
	seed["seed_cell_state_offset"] = "+0x1c";
	seed["seed_cell_low_word_after_seed"] = 0;
	seed["seed_initialization_status"] = "h3maped_0x4aae7b_seed_cell_initialization_materialized_propagation_pending";
	seed["seed_initialization_block"] = "0x4aaedc..0x4aaf0e";
	seed["seed_initialization_call_count"] = seed_initializations.size();
	seed["seed_initialization_expected_outer_seed_count"] = seed_initialization_count;
	seed["seed_initializations"] = seed_initializations;
	seed["normal_neighbor_propagation_status"] = propagation_grid_available
			? "h3maped_0x4aae7b_normal_neighbor_path_costs_materialized_special_vectors_pending"
			: "h3maped_0x4aae7b_normal_neighbor_path_costs_blocked_missing_grid";
	seed["normal_neighbor_propagation_seed_count"] = propagation_summaries.size();
	seed["normal_neighbor_propagation_summaries"] = propagation_summaries;
	seed["normal_neighbor_total_reached_cell_count"] = total_reached_cell_count;
	seed["normal_neighbor_total_relaxed_edge_count"] = total_relaxed_edge_count;
	seed["candidate_low_word_status"] = propagation_grid_available
			? "h3maped_0x4ab52a_candidate_low_words_materialized_from_normal_0x4aae7b"
			: "pending_0x4aae7b_path_cost_grid_materialization";
	seed["candidate_low_word_count"] = total_candidate_low_word_count;
	seed["candidate_accept_count"] = total_candidate_accept_count;
	seed["candidate_low_words"] = candidate_low_words;
	seed["predecessor_chain_status"] = propagation_grid_available
			? "h3maped_0x4ab37f_predecessor_chains_materialized_from_normal_0x4aae7b"
			: "pending_0x4aae7b_path_cost_grid_materialization";
	seed["predecessor_chain_count"] = predecessor_chain_records.size();
	seed["predecessor_chain_records"] = predecessor_chain_records;
	seed["predecessor_chain_total_cell_visits"] = total_predecessor_chain_cell_visits;
	seed["predecessor_chain_max_step_count"] = max_predecessor_chain_step_count;
	seed["predecessor_chain_materializes_road_geometry"] = false;
	seed["first_seed_path_cost_low_word_u16"] = first_seed_path_costs;
	seed["first_seed_predecessor_x_i32"] = first_seed_predecessor_x;
	seed["first_seed_predecessor_y_i32"] = first_seed_predecessor_y;
	seed["first_seed_predecessor_level_i32"] = first_seed_predecessor_level;
	seed["predecessor_coordinate_offsets"] = Array::make("+0x10", "+0x14", "+0x18");
	seed["neighbor_direction_table_address"] = "0x5a2658";
	seed["neighbor_direction_table_end_address"] = "0x5a2698";
	seed["neighbor_direction_table_initializer"] = "0x499db3..0x499e20";
	seed["neighbor_direction_table_status"] = "h3maped_0x5a2658_direction_table_materialized_propagation_pending";
	seed["neighbor_direction_records"] = direction_records;
	seed["neighbor_direction_dx_i32"] = direction_dx_array;
	seed["neighbor_direction_dy_i32"] = direction_dy_array;
	seed["default_neighbor_direction_count"] = direction_count;
	seed["metadata_reduced_neighbor_direction_count"] = 5;
	seed["terrain_class_mask_offset"] = "cell+0x24";
	seed["terrain_class_low_bits_mask_hex"] = "0x3f";
	seed["blocked_terrain_class_values"] = Array::make(8, 9);
	seed["cell_materialized_required_bit_offset"] = "cell+0x28 bit25";
	seed["cell_object_present_bit_offset"] = "cell+0x28 bit22";
	seed["current_cell_object_flags_offset"] = "cell+0x27";
	seed["current_cell_object_flags_mask_hex"] = "0x3c";
	seed["runtime_object_metadata_table_address"] = "0x57c648";
	seed["special_level_transition_object_type"] = 0x67;
	seed["special_vector_14c0_object_types"] = Array::make(0x2b, 0x2c);
	seed["special_vector_14d0_object_type"] = 0x2d;
	seed["special_vector_14c0_begin_offset"] = "generator+0x14c4";
	seed["special_vector_14c0_end_offset"] = "generator+0x14c8";
	seed["special_vector_14d0_begin_offset"] = "generator+0x14d4";
	seed["special_vector_14d0_end_offset"] = "generator+0x14d8";
	seed["normal_step_cost"] = 20;
	seed["odd_direction_step_cost"] = 60;
	seed["object_lane_step_cost"] = 2;
	seed["special_vector_step_cost_delta"] = 0x32;
	seed["normal_neighbor_update_block"] = "0x4ab2d8..0x4ab33a";
	seed["special_vector_update_block"] = "0x4ab25d..0x4ab2d0";
	seed["normal_neighbor_cost_source"] = "current_cost + 0x14, or current_cost + 0x3c when direction index bit0 is set";
	seed["special_vector_cost_source"] = "current_cost + 0x32";
	seed["update_compare"] = "computed_cost < target_cell_low_word";
	seed["update_reject_compare_address"] = "0x4ab2f4..0x4ab2f6";
	seed["special_update_reject_compare_address"] = "0x4ab288..0x4ab28a";
	seed["path_cost_low_word_mask_hex"] = "0xffff";
	seed["path_cost_low_word_preserve_expression"] = "((old_cell_state ^ computed_cost) & 0xffff) ^ old_cell_state";
	seed["path_cost_update_semantics"] = "if computed cost is lower than the target cell low word, replace only the low word of cell+0x1c, copy the current coordinate triplet into target cell+0x10/+0x14/+0x18, and enqueue the target coordinate through 0x4a489d";
	seed["predecessor_write_block"] = "0x4ab310..0x4ab31b";
	seed["special_predecessor_write_block"] = "0x4ab2a4..0x4ab2af";
	seed["target_enqueue_block"] = "0x4ab31c..0x4ab32f";
	seed["special_target_enqueue_block"] = "0x4ab2b0..0x4ab2c3";
	seed["direction_loop_decrement_block"] = "0x4ab33a..0x4ab348";
	seed["direction_loop_end_jump"] = "0x4aaf0f";
	seed["queue_cleanup_block"] = "0x4ab353..0x4ab36e";
	seed["materializes_road_geometry"] = false;
	seed["road_toolkit_status_after_seed"] = "pending_0x4ab37f_0x4b4243_road_materialization";
	seed["blocked_reason"] = "The executable propagation boundary is recovered, but the complete +0x14b0 coordinate vector and the downstream 0x4ab37f/0x4b4243 road toolkit are still required before emitting road cells.";
	seed["signature"] = h3maped_hash32_hex(String("h3maped_4aae7b_path_state_seed:")
			+ String::num_int64(width) + ":"
			+ String::num_int64(height) + ":"
			+ String::num_int64(level_count) + ":"
			+ String::num_int64(partial_record_count));
	return seed;
}

Dictionary h3maped_road_adapter_bridge_4ab37f_report(const Dictionary &terrain_fill, const Dictionary &path_seed_update) {
	const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
	const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t predecessor_chain_count = int32_t(path_seed_update.get("predecessor_chain_count", 0));
	const bool predecessor_chains_materialized = predecessor_chain_count > 0
			&& String(path_seed_update.get("predecessor_chain_status", "")) == "h3maped_0x4ab37f_predecessor_chains_materialized_from_normal_0x4aae7b";
	Dictionary bridge;
	bridge["schema_id"] = "aurelion_h3maped_small_road_adapter_bridge_v1";
	bridge["status"] = predecessor_chains_materialized
			? "h3maped_0x4ab37f_predecessor_chains_materialized_toolkit_pending"
			: "h3maped_0x4ab37f_road_adapter_bridge_recovered_toolkit_pending";
	bridge["function_address"] = "0x4ab37f";
	bridge["source"] = "Recovered from h3maped.exe: ecx is the generator, four stack arguments are a coordinate triplet plus selected road type, the function builds a generated-cell terrain adapter and road adapter, calls 0x4b4243, then follows predecessor coordinates until the path chain terminates.";
	bridge["generator_argument_register"] = "ecx";
	bridge["stack_argument_count"] = 4;
	bridge["coordinate_argument_stack_offsets"] = Array::make("ebp+0x08", "ebp+0x0c", "ebp+0x10");
	bridge["road_type_argument_stack_offset"] = "ebp+0x14";
	bridge["return_type"] = "bool_al";
	bridge["generated_cell_base_offset"] = "generator+0x14";
	bridge["generated_cell_stride_bytes"] = 0x30;
	bridge["width"] = width;
	bridge["height"] = height;
	bridge["level_count"] = level_count;
	bridge["terrain_adapter_stack_base"] = "ebp-0x50";
	bridge["terrain_adapter_vtable_address"] = "0x540a14";
	bridge["terrain_adapter_cell_base_field"] = "ebp-0x48";
	bridge["terrain_adapter_width_field"] = "ebp-0x44";
	bridge["terrain_adapter_height_field"] = "ebp-0x40";
	bridge["terrain_adapter_level_count_field"] = "ebp-0x3c";
	bridge["road_adapter_stack_base"] = "ebp-0x1c";
	bridge["road_adapter_vtable_address"] = "0x540a34";
	bridge["road_adapter_terrain_adapter_pointer_field"] = "ebp-0x18";
	bridge["road_adapter_start_coordinate_fields"] = Array::make("ebp-0x24", "ebp-0x20");
	bridge["road_toolkit_entry_address"] = "0x4b4243";
	bridge["road_toolkit_cleanup_address"] = "0x4b42c0";
	bridge["terrain_adapter_destructor_address"] = "0x49a030";
	bridge["path_predecessor_offsets"] = Array::make("+0x10", "+0x14", "+0x18");
	bridge["path_cost_offset"] = "+0x1c";
	bridge["path_cost_low_word_mask_hex"] = "0xffff";
	bridge["road_type_source_offset"] = "cell+0x24";
	bridge["road_type_decode"] = "signed top nibble after (cell+0x24 << 2) >> 28";
	bridge["path_follow_condition"] = "when decoded road type matches the selected road type and the current cell path-cost low word is nonzero, copy the current coordinate to the last-coordinate slot and replace the input coordinate with cell+0x10/+0x14/+0x18";
	bridge["start_reached_condition"] = "same level and matching x or y against the saved start coordinate before cleanup";
	bridge["predecessor_chain_status"] = path_seed_update.get("predecessor_chain_status", "");
	bridge["predecessor_chain_count"] = predecessor_chain_count;
	bridge["predecessor_chain_total_cell_visits"] = path_seed_update.get("predecessor_chain_total_cell_visits", 0);
	bridge["predecessor_chain_max_step_count"] = path_seed_update.get("predecessor_chain_max_step_count", 0);
	bridge["predecessor_chain_materialized"] = predecessor_chains_materialized;
	bridge["materializes_road_geometry"] = false;
	bridge["blocked_reason"] = predecessor_chains_materialized
			? "0x4ab37f adapter setup and predecessor-chain walks are materialized from the normal 0x4aae7b path state, but 0x4b4243/0x458e61 road-cell mutation and art writes are still not ported."
			: "0x4ab37f constructs the adapters and invokes 0x4b4243, but the toolkit body that writes road cells/art is still not ported.";
	bridge["signature"] = h3maped_hash32_hex(String("h3maped_4ab37f_road_adapter_bridge:")
			+ String::num_int64(width) + ":"
			+ String::num_int64(height) + ":"
			+ String::num_int64(level_count) + ":"
			+ String::num_int64(predecessor_chain_count));
	return bridge;
}

Dictionary h3maped_road_line_visit_458e61_report() {
	constexpr int32_t road_neighbor_count = 8;
	constexpr int32_t road_neighbor_dx[road_neighbor_count] = { 0, 1, 1, 1, 0, -1, -1, -1 };
	constexpr int32_t road_neighbor_dy[road_neighbor_count] = { -1, -1, 0, 1, 1, 1, 0, -1 };
	constexpr const char *road_neighbor_addresses[road_neighbor_count] = {
		"0x5a5028", "0x5a5030", "0x5a5038", "0x5a5040",
		"0x5a5048", "0x5a5050", "0x5a5058", "0x5a5060"
	};
	Array road_neighbor_records;
	PackedInt32Array road_neighbor_dx_array;
	PackedInt32Array road_neighbor_dy_array;
	for (int32_t index = 0; index < road_neighbor_count; ++index) {
		Dictionary record;
		record["index"] = index;
		record["address"] = road_neighbor_addresses[index];
		record["dx"] = road_neighbor_dx[index];
		record["dy"] = road_neighbor_dy[index];
		record["initializer_address"] = "0x4bf38b..0x4bf3f3";
		road_neighbor_records.append(record);
		road_neighbor_dx_array.append(road_neighbor_dx[index]);
		road_neighbor_dy_array.append(road_neighbor_dy[index]);
	}
	constexpr int32_t road_shape_record_count = 4;
	constexpr int32_t road_shape_offsets[road_shape_record_count][8] = {
		{ 0, 1, 2, 3, 4, 5, 6, 7 },
		{ 4, 3, 2, 1, 0, 7, 6, 5 },
		{ 0, 7, 6, 5, 4, 3, 2, 1 },
		{ 4, 5, 6, 7, 0, 1, 2, 3 },
	};
	constexpr int32_t road_shape_flip_a[road_shape_record_count] = { 0, 0, 1, 1 };
	constexpr int32_t road_shape_flip_b[road_shape_record_count] = { 0, 1, 0, 1 };
	constexpr const char *road_shape_addresses[road_shape_record_count] = {
		"0x538a04", "0x538a24", "0x538a44", "0x538a64"
	};
	Array road_shape_records;
	for (int32_t record_index = 0; record_index < road_shape_record_count; ++record_index) {
		PackedInt32Array offsets;
		for (int32_t offset_index = 0; offset_index < 8; ++offset_index) {
			offsets.append(road_shape_offsets[record_index][offset_index]);
		}
		Dictionary record;
		record["record_index"] = record_index;
		record["address"] = road_shape_addresses[record_index];
		record["neighbor_flag_offsets"] = offsets;
		record["flip_selector_a"] = road_shape_flip_a[record_index];
		record["flip_selector_b"] = road_shape_flip_b[record_index];
		road_shape_records.append(record);
	}
	constexpr int32_t road_art_variant_count = 17;
	constexpr int32_t road_art_variant_classes[road_art_variant_count] = {
		4, 4, 5, 5, 5, 5, 6, 6, 7, 7, 2, 2, 3, 3, 0, 1, 8
	};
	PackedInt32Array road_art_variant_class_sequence;
	for (int32_t variant_index = 0; variant_index < road_art_variant_count; ++variant_index) {
		road_art_variant_class_sequence.append(road_art_variant_classes[variant_index]);
	}
	Array road_art_variant_buckets;
	for (int32_t art_class = 0; art_class <= 8; ++art_class) {
		int32_t first_variant_index = -1;
		int32_t variant_count = 0;
		for (int32_t variant_index = 0; variant_index < road_art_variant_count; ++variant_index) {
			if (road_art_variant_classes[variant_index] != art_class) {
				continue;
			}
			if (first_variant_index < 0) {
				first_variant_index = variant_index;
			}
			variant_count += 1;
		}
		Dictionary bucket;
		bucket["art_class"] = art_class;
		bucket["first_variant_index"] = first_variant_index;
		bucket["variant_count"] = variant_count;
		bucket["runtime_record_offset_bytes"] = 0x08 + art_class * 0x08;
		road_art_variant_buckets.append(bucket);
	}
	Dictionary visit;
	visit["schema_id"] = "aurelion_h3maped_small_road_line_visit_v1";
	visit["status"] = "h3maped_0x458e61_line_visit_boundary_recovered_adapter_materialization_pending";
	visit["function_address"] = "0x458e61";
	visit["source"] = "Recovered from h3maped.exe: 0x458e61 visits one line coordinate, probes road-adapter state, skips cells already carrying the requested road type, marks candidate cells through adapter virtual slot +0x08, then delegates neighbor-sensitive road art/flip selection to 0x458a2f and 0x4587f7.";
	visit["coordinate_argument_stack_offset"] = "ebp+0x08";
	visit["toolkit_adapter_pointer_field"] = "+0x00";
	visit["toolkit_requested_road_type_field"] = "+0x04";
	visit["probe_virtual_slot"] = "+0x14";
	visit["probe_virtual_address_for_road_adapter"] = "0x49af7b";
	visit["probe_semantics"] = "read signed road-type nibble from generated cell+0x24 using (cell+0x24 << 2) >> 28";
	visit["skip_condition"] = "if adapter +0x14 returns the requested road type, do not rematerialize this coordinate";
	visit["start_coordinate_virtual_slot"] = "+0x0c";
	visit["start_coordinate_virtual_address_for_road_adapter"] = "0x49aef9";
	visit["start_coordinate_semantics"] = "delegate to wrapped terrain adapter +0x0c and copy the two-coordinate start point";
	visit["terrain_gate_virtual_slot"] = "+0x0c";
	visit["candidate_mark_virtual_slot"] = "+0x08";
	visit["candidate_mark_virtual_address_for_road_adapter"] = "0x49aec5";
	visit["candidate_mark_semantics"] = "write requested road type into generated cell+0x24 top road nibble without final art/flip";
	visit["final_write_helper_address"] = "0x458a2f";
	visit["neighbor_mask_helper_address"] = "0x4587f7";
	visit["rectangle_flush_helper_address"] = "0x458af6";
	visit["edge_mask_helper_address"] = "0x4bf3f4";
	visit["edge_mask_semantics"] = "initialize 8 neighbor flags to one and clear edge-facing entries when the coordinate is on map borders";
	visit["neighbor_direction_table_address"] = "0x5a5028";
	visit["neighbor_direction_table_end_address"] = "0x5a5068";
	visit["neighbor_direction_table_initializer"] = "0x4bf38b..0x4bf3f3";
	visit["neighbor_direction_record_count"] = 8;
	visit["neighbor_direction_record_size_bytes"] = 8;
	visit["neighbor_direction_records"] = road_neighbor_records;
	visit["neighbor_direction_dx_i32"] = road_neighbor_dx_array;
	visit["neighbor_direction_dy_i32"] = road_neighbor_dy_array;
	visit["neighbor_retouch_semantics"] = "for each enabled neighboring direction, call 0x458a2f on the adjacent coordinate after current cell candidate marking";
	visit["road_art_selection_source_table"] = "0x538a04..0x538a8b";
	visit["road_art_pair_table_address"] = "0x538a84";
	visit["road_art_shape_records"] = road_shape_records;
	visit["road_art_shape_record_count"] = road_shape_records.size();
	visit["road_art_shape_record_size_bytes"] = 0x20;
	visit["road_art_shape_selector_semantics"] = "0x458893 selects one of four 0x20-byte offset records using (flip_selector_b + flip_selector_a * 2), then classifies art and flip from the eight neighbor flags.";
	visit["road_art_variant_initializer_address"] = "0x4b41f4..0x4b4200";
	visit["road_art_variant_initializer_helper"] = "0x458755";
	visit["road_art_variant_source_table_address"] = "0x54198c";
	visit["road_art_variant_runtime_table_address"] = "0x5a2f80";
	visit["road_art_variant_class_sequence"] = road_art_variant_class_sequence;
	visit["road_art_variant_count"] = road_art_variant_count;
	visit["road_art_variant_bucket_records"] = road_art_variant_buckets;
	visit["road_art_variant_bucket_semantics"] = "0x458755 copies the 17 class ids, then builds nine 8-byte records at runtime table +0x08 where +0x00 is the first variant index and +0x04 is the variant count for each art class.";
	visit["rng_tie_break_address"] = "0x4e7276";
	visit["final_write_virtual_slot"] = "+0x04";
	visit["final_write_virtual_address_for_road_adapter"] = "0x49ae47";
	visit["candidate_mark_write_mask_cell_0x24_hex"] = "0xc3ffffff";
	visit["candidate_mark_road_type_shift"] = 26;
	visit["final_write_cell_0x24_mask_hex"] = "0xc3ffffff";
	visit["final_write_cell_0x24_road_type_shift"] = 26;
	visit["final_write_cell_0x28_mask_hex"] = "0xffe7ff00";
	visit["final_write_cell_0x28_art_mask_hex"] = "0x000000ff";
	visit["final_write_cell_0x28_flip_shift"] = 19;
	visit["final_write_semantics"] = "0x49ae79 writes road type into cell+0x24 bits 26..29, writes road art into cell+0x28 low byte, and writes two flip bits into cell+0x28 bits 19..20 after 0x458893 classifies neighbor shape";
	visit["readback_virtual_slot"] = "+0x10";
	visit["readback_virtual_address_for_road_adapter"] = "0x49af1d";
	visit["readback_semantics"] = "read road type, art index, and flip flags from generated cell+0x24/+0x28 for neighbor-shape stability checks";
	visit["materializes_road_geometry"] = false;
	visit["blocked_reason"] = "The executable line-visit and adapter virtual boundary is recovered, but the clean port still needs an owned generated-cell mutation implementation and a complete coordinate vector before it may serialize road cells.";
	return visit;
}

Dictionary h3maped_road_toolkit_4b4243_report(const Dictionary &terrain_fill) {
	const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
	const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	Dictionary toolkit;
	toolkit["schema_id"] = "aurelion_h3maped_small_road_toolkit_entry_v1";
	toolkit["status"] = "h3maped_0x4b4243_road_toolkit_entry_recovered_path_helpers_pending";
	toolkit["function_address"] = "0x4b4243";
	toolkit["source"] = "Recovered from h3maped.exe: this entry initializes the road toolkit object from the road adapter, stores the adapter start coordinate and adapter pointer, switches vtables, then delegates path/raster work to 0x458d37 and 0x458e61. The downstream adapter virtual writes are still not ported, so no road cells are serialized.";
	toolkit["toolkit_argument_register"] = "ecx";
	toolkit["road_adapter_argument_stack_offset"] = "ebp+0x08";
	toolkit["path_endpoint_argument_stack_offsets"] = Array::make("ebp+0x0c", "ebp+0x10");
	toolkit["initial_vtable_address"] = "0x5419d4";
	toolkit["runtime_vtable_address"] = "0x5419f4";
	toolkit["alternate_runtime_vtable_address"] = "0x541a14";
	toolkit["constructor_address"] = "0x4b4243";
	toolkit["destructor_address"] = "0x4b42a4";
	toolkit["cleanup_address"] = "0x4b42c0";
	toolkit["secondary_constructor_address"] = "0x4b4331";
	toolkit["secondary_cleanup_address"] = "0x4b432a";
	toolkit["adapter_virtual_start_coordinate_slot"] = "+0x0c";
	toolkit["adapter_virtual_probe_slot"] = "+0x14";
	toolkit["adapter_virtual_terrain_class_slot"] = "+0x18";
	toolkit["toolkit_start_x_field"] = "+0x04";
	toolkit["toolkit_start_y_field"] = "+0x08";
	toolkit["toolkit_adapter_pointer_field"] = "+0x0c";
	toolkit["toolkit_path_state_field"] = "+0x10";
	toolkit["line_initializer_address"] = "0x458d37";
	toolkit["line_stepper_address"] = "0x458d66";
	toolkit["line_visit_address"] = "0x458e61";
	toolkit["line_visit_boundary"] = h3maped_road_line_visit_458e61_report();
	toolkit["neighbor_direction_table_address"] = "0x5a5028";
	toolkit["neighbor_direction_table_end_address"] = "0x5a5068";
	toolkit["neighbor_direction_table_initializer"] = "0x4bf38b..0x4bf3f3";
	toolkit["neighbor_direction_record_size_bytes"] = 8;
	toolkit["neighbor_direction_record_count"] = 8;
	toolkit["width"] = width;
	toolkit["height"] = height;
	toolkit["level_count"] = level_count;
	Array initial_vtable_entries;
	initial_vtable_entries.append("0x4b421b");
	initial_vtable_entries.append("0x4b3bbd");
	initial_vtable_entries.append("0x4b3bf0");
	initial_vtable_entries.append("0x4b4223");
	initial_vtable_entries.append("0x4b3c03");
	initial_vtable_entries.append("0x4b3c3f");
	initial_vtable_entries.append("0x4e6ab4");
	initial_vtable_entries.append("0x558468");
	toolkit["initial_vtable_entries"] = initial_vtable_entries;
	Array runtime_vtable_entries;
	runtime_vtable_entries.append("0x4b421b");
	runtime_vtable_entries.append("0x4b3bbd");
	runtime_vtable_entries.append("0x4b3bf0");
	runtime_vtable_entries.append("0x4b4223");
	runtime_vtable_entries.append("0x4b3c03");
	runtime_vtable_entries.append("0x4b3c3f");
	runtime_vtable_entries.append("0x4b42a4");
	runtime_vtable_entries.append("0x5584c0");
	toolkit["runtime_vtable_entries"] = runtime_vtable_entries;
	toolkit["materializes_road_geometry"] = false;
	toolkit["road_cell_write_status"] = "adapter_virtual_write_boundary_recovered_clean_cell_mutation_pending";
	toolkit["blocked_reason"] = "The toolkit entry, vtables, line visit, and adapter virtual write boundary are recovered, but the clean port has not yet implemented authoritative generated-cell road mutation or complete +0x14b0 coordinate-vector parity.";
	toolkit["signature"] = h3maped_hash32_hex(String("h3maped_4b4243_road_toolkit_entry:")
			+ String::num_int64(width) + ":"
			+ String::num_int64(height) + ":"
			+ String::num_int64(level_count));
	return toolkit;
}

Dictionary h3maped_road_candidate_marking_49aec5_report(const Dictionary &terrain_fill, const Dictionary &path_seed_update, int32_t selected_road_type) {
	const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
	const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
	const int32_t tile_count = width * height * level_count;
	PackedInt32Array road_type_nibble;
	PackedInt32Array road_art_u8;
	PackedInt32Array road_flip_a;
	PackedInt32Array road_flip_b;
	road_type_nibble.resize(tile_count);
	road_art_u8.resize(tile_count);
	road_flip_a.resize(tile_count);
	road_flip_b.resize(tile_count);
	for (int32_t index = 0; index < tile_count; ++index) {
		road_type_nibble.set(index, 0);
		road_art_u8.set(index, 0);
		road_flip_a.set(index, 0);
		road_flip_b.set(index, 0);
	}
	Array predecessor_chains = path_seed_update.get("predecessor_chain_records", Array());
	std::map<int32_t, bool> unique_marked_cells;
	int32_t write_attempt_count = 0;
	int32_t invalid_flat_cell_count = 0;
	for (int64_t chain_index = 0; chain_index < predecessor_chains.size(); ++chain_index) {
		if (Variant(predecessor_chains[chain_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary chain = Dictionary(predecessor_chains[chain_index]);
		if (!bool(chain.get("predecessor_chain_reaches_seed", false))) {
			continue;
		}
		PackedInt32Array flat_cells = chain.get("predecessor_chain_flat_cells", PackedInt32Array());
		for (int32_t cell_index = 0; cell_index < flat_cells.size(); ++cell_index) {
			const int32_t flat_cell = int32_t(flat_cells[cell_index]);
			write_attempt_count += 1;
			if (flat_cell < 0 || flat_cell >= tile_count) {
				invalid_flat_cell_count += 1;
				continue;
			}
			if (unique_marked_cells.find(flat_cell) == unique_marked_cells.end()) {
				unique_marked_cells[flat_cell] = true;
			}
			road_type_nibble.set(flat_cell, selected_road_type & 0x0f);
		}
	}
		PackedInt32Array marked_flat_cells;
		for (const auto &entry : unique_marked_cells) {
			marked_flat_cells.append(entry.first);
		}
		int32_t selected_grid_count = 0;
		for (int32_t index = 0; index < road_type_nibble.size(); ++index) {
			if ((int32_t(road_type_nibble[index]) & 0x0f) == (selected_road_type & 0x0f)) {
				selected_grid_count += 1;
			}
		}
		Dictionary report;
	report["schema_id"] = "aurelion_h3maped_small_road_candidate_marking_v1";
	report["status"] = unique_marked_cells.empty()
			? String("h3maped_0x49aec5_candidate_road_type_marks_blocked_no_predecessor_chains")
			: String("h3maped_0x49aec5_candidate_road_type_marks_materialized_art_pending");
	report["function_address"] = "0x49aec5";
	report["source"] = "Recovered from h3maped.exe road-adapter virtual slot +0x08: mask generated cell+0x24 with 0xc3ffffff and write the requested road type nibble shifted by 26 before 0x458a2f final art/flip classification.";
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;
	report["selected_road_type"] = selected_road_type;
	report["candidate_mark_write_mask_cell_0x24_hex"] = "0xc3ffffff";
	report["candidate_mark_road_type_shift"] = 26;
	report["source_predecessor_chain_count"] = predecessor_chains.size();
	report["candidate_mark_write_attempt_count"] = write_attempt_count;
	report["candidate_marked_cell_count"] = int32_t(unique_marked_cells.size());
		report["candidate_mark_invalid_flat_cell_count"] = invalid_flat_cell_count;
		report["candidate_road_type_grid_selected_count"] = selected_grid_count;
		report["candidate_marked_flat_cells"] = marked_flat_cells;
	report["candidate_road_type_nibble_u8"] = road_type_nibble;
	report["final_road_art_u8"] = road_art_u8;
	report["final_road_flip_a_u8"] = road_flip_a;
	report["final_road_flip_b_u8"] = road_flip_b;
	report["materializes_candidate_road_type_nibble"] = !unique_marked_cells.empty();
	report["materializes_final_road_art"] = false;
	report["materializes_serialized_road_overlay"] = false;
	report["blocked_reason"] = "Only the recovered 0x49aec5 candidate road-type nibble mark is materialized. 0x458a2f/0x458893 final road art/flip selection, complete +0x14b0 vector parity, and 0x49b2b6 road overlay byte serialization remain pending.";
	report["signature"] = h3maped_hash32_hex(String("h3maped_49aec5_candidate_road_type_marks:")
			+ String::num_int64(tile_count) + ":"
			+ String::num_int64(selected_road_type) + ":"
			+ String::num_int64(unique_marked_cells.size()) + ":"
			+ String::num_int64(write_attempt_count));
	return report;
}

	Dictionary h3maped_road_pair_iteration_4ab52a_report(const Dictionary &coordinate_vector_source, int64_t rng_state_before_road_phase, const Dictionary &path_seed_update) {
	Array coordinate_records = coordinate_vector_source.get("materialized_partial_coordinate_records", Array());
	Array candidate_low_words = path_seed_update.get("candidate_low_words", Array());
	const int32_t record_count = int32_t(coordinate_records.size());
	const int32_t expected_pair_count = record_count > 1 ? (record_count * (record_count - 1)) / 2 : 0;
	const bool path_costs_materialized = candidate_low_words.size() == expected_pair_count
			&& String(path_seed_update.get("candidate_low_word_status", "")) == "h3maped_0x4ab52a_candidate_low_words_materialized_from_normal_0x4aae7b";
	H3MapedRng rng { uint32_t(rng_state_before_road_phase) };
	const int32_t road_type_rng_value = rng.next();
	const int32_t road_type = road_type_rng_value % 3 + 1;
	Dictionary iteration;
	iteration["schema_id"] = "aurelion_h3maped_small_road_pair_iteration_v1";
	iteration["status"] = path_costs_materialized
			? "h3maped_0x4ab52a_pair_iteration_ported_path_costs_materialized_road_adapter_pending"
			: "h3maped_0x4ab52a_pair_iteration_ported_path_costs_pending";
	iteration["function_address"] = "0x4ab52a";
	iteration["source"] = "Recovered from h3maped.exe: choose one road type with 0x4e7276 % 3 + 1, then iterate each generator+0x14b0 coordinate record as a path seed and every later record as a candidate endpoint.";
	iteration["coordinate_vector_begin_offset"] = "+0x14b4";
	iteration["coordinate_vector_end_offset"] = "+0x14b8";
	iteration["coordinate_record_size_bytes"] = 12;
	iteration["road_type_rng_function_address"] = "0x4e7276";
	iteration["rng_state_before_road_phase_uint32"] = rng_state_before_road_phase;
	iteration["road_type_rng_value"] = road_type_rng_value;
	iteration["rng_state_after_road_type_uint32"] = int64_t(rng.state);
	iteration["road_type_modulus"] = 3;
	iteration["road_type_addend"] = 1;
	iteration["selected_road_type"] = road_type;
	iteration["coordinate_record_count"] = record_count;
	iteration["outer_seed_iteration_count"] = std::max(0, record_count - 1);
	iteration["pair_candidate_iteration_count"] = expected_pair_count;
	iteration["cell_state_reset_call_site"] = "0x4ab583";
	iteration["path_state_seed_call_site"] = "0x4ab595";
	iteration["candidate_low_word_read_block"] = "0x4ab5df..0x4ab60a";
	iteration["candidate_low_word_threshold_hex"] = "0x7530";
	iteration["candidate_low_word_threshold"] = 0x7530;
	iteration["candidate_accept_condition"] = "candidate cell +0x1c low word <= 0x7530";
	iteration["road_adapter_call_site"] = "0x4ab611..0x4ab620 -> 0x4ab37f";
	iteration["progress_callback_address"] = "generator+0xed4 vtable+0x08";
	iteration["complete_coordinate_vector_claim"] = bool(coordinate_vector_source.get("complete_executable_vector_claim", false));
	iteration["path_costs_materialized"] = path_costs_materialized;
	iteration["candidate_low_word_count"] = path_costs_materialized ? candidate_low_words.size() : 0;
	iteration["candidate_accept_count"] = path_costs_materialized ? int32_t(path_seed_update.get("candidate_accept_count", 0)) : 0;
	iteration["road_geometry_materialized"] = false;
	iteration["blocked_reason"] = path_costs_materialized
			? "The pair loop, road-type RNG, and normal 0x4aae7b endpoint low-word eligibility are ported, but complete vector parity, special/object propagation, and 0x4ab37f/0x4b4243 road-cell writes remain pending."
			: "The pair loop and road-type RNG are ported, but endpoint low-word eligibility depends on the still-pending 0x4aae7b path-cost propagation and 0x4b4243 road toolkit.";
	Array outer_iterations;
	int32_t candidate_low_word_cursor = 0;
	for (int32_t seed_index = 0; seed_index < std::max(0, record_count - 1); ++seed_index) {
		Dictionary seed_record = Variant(coordinate_records[seed_index]).get_type() == Variant::DICTIONARY
				? Dictionary(coordinate_records[seed_index])
				: Dictionary();
		Dictionary outer;
		outer["seed_vector_index"] = seed_index;
		outer["seed_byte_offset"] = seed_index * 12;
		outer["seed_coordinate_triplet"] = seed_record.get("coordinate_triplet", Array());
		outer["reset_call_required_before_seed"] = true;
		outer["path_seed_call_required"] = true;
		outer["candidate_start_vector_index"] = seed_index + 1;
		outer["candidate_count"] = std::max(0, record_count - seed_index - 1);
		outer["candidate_low_word_status"] = path_costs_materialized
				? "materialized_from_normal_0x4aae7b_path_cost_grid"
				: "pending_0x4aae7b_path_cost_grid_materialization";
		Array candidate_preview;
		for (int32_t candidate_index = seed_index + 1; candidate_index < record_count; ++candidate_index) {
			Dictionary candidate_record = Variant(coordinate_records[candidate_index]).get_type() == Variant::DICTIONARY
					? Dictionary(coordinate_records[candidate_index])
					: Dictionary();
			Dictionary low_word_record = path_costs_materialized && candidate_low_word_cursor < candidate_low_words.size() && Variant(candidate_low_words[candidate_low_word_cursor]).get_type() == Variant::DICTIONARY
					? Dictionary(candidate_low_words[candidate_low_word_cursor])
					: Dictionary();
			Dictionary candidate;
			candidate["candidate_vector_index"] = candidate_index;
			candidate["candidate_byte_offset"] = candidate_index * 12;
			candidate["candidate_coordinate_triplet"] = candidate_record.get("coordinate_triplet", Array());
			candidate["candidate_low_word_threshold"] = 0x7530;
			candidate["candidate_low_word"] = path_costs_materialized ? int32_t(low_word_record.get("candidate_low_word", 0x7d00)) : -1;
			candidate["candidate_accepts_0x4ab52a"] = path_costs_materialized ? bool(low_word_record.get("candidate_accepts_0x4ab52a", false)) : false;
			candidate["candidate_accept_status"] = path_costs_materialized
					? (bool(candidate["candidate_accepts_0x4ab52a"]) ? String("accepted_low_word_lte_0x7530") : String("rejected_low_word_gt_0x7530"))
					: String("pending_path_cost_low_word");
			if (candidate_preview.size() < 6) {
				candidate_preview.append(candidate);
			}
			candidate_low_word_cursor += 1;
		}
		outer["candidate_preview"] = candidate_preview;
		outer_iterations.append(outer);
	}
	iteration["outer_iterations"] = outer_iterations;
	iteration["signature"] = h3maped_hash32_hex(String("h3maped_4ab52a_pair_iteration:")
			+ String::num_int64(record_count) + ":"
			+ String::num_int64(road_type_rng_value) + ":"
			+ String::num_int64(road_type));
		return iteration;
	}

	Dictionary h3maped_road_final_art_flip_458a2f_report(const Dictionary &terrain_fill, const Dictionary &path_seed_update, const Dictionary &pair_iteration) {
		const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
		const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
		const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
		const int32_t tile_count = width * height * level_count;
		const int32_t selected_road_type = int32_t(pair_iteration.get("selected_road_type", 0)) & 0x0f;
		constexpr int32_t variant_classes[17] = { 4, 4, 5, 5, 5, 5, 6, 6, 7, 7, 2, 2, 3, 3, 0, 1, 8 };
		constexpr int32_t bucket_starts[9] = { 14, 15, 10, 12, 0, 2, 6, 8, 16 };
		constexpr int32_t bucket_counts[9] = { 1, 1, 2, 2, 2, 4, 2, 2, 1 };
		constexpr int32_t dx[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
		constexpr int32_t dy[8] = { -1, -1, 0, 1, 1, 1, 0, -1 };
		PackedInt32Array road_type_nibble;
		PackedInt32Array road_art_u8;
		PackedInt32Array road_flip_a;
		PackedInt32Array road_flip_b;
		road_type_nibble.resize(tile_count);
		road_art_u8.resize(tile_count);
		road_flip_a.resize(tile_count);
		road_flip_b.resize(tile_count);
		for (int32_t index = 0; index < tile_count; ++index) {
			road_type_nibble.set(index, 0);
			road_art_u8.set(index, 0);
			road_flip_a.set(index, 0);
			road_flip_b.set(index, 0);
		}
		H3MapedRng rng { uint32_t(int64_t(pair_iteration.get("rng_state_after_road_type_uint32", 0))) };
		Array predecessor_chains = path_seed_update.get("predecessor_chain_records", Array());
		std::map<int32_t, bool> marked_cells;
		std::map<int32_t, bool> final_write_cells;
		Array write_preview;
		int32_t line_visit_call_count = 0;
		int32_t line_visit_skip_same_type_count = 0;
		int32_t candidate_mark_count = 0;
		int32_t neighbor_retouch_call_count = 0;
		int32_t stable_readback_skip_count = 0;
		int32_t final_write_count = 0;
		int32_t rng_call_count = 0;
		int32_t invalid_flat_cell_count = 0;
		auto in_bounds_flat = [&](int32_t flat) -> bool {
			return flat >= 0 && flat < tile_count;
		};
		auto build_neighbor_flags = [&](int32_t flat, int32_t road_type, uint8_t flags[8]) {
			const int32_t x = flat % width;
			const int32_t y = (flat / width) % height;
			const int32_t level = flat / (width * height);
			for (int32_t index = 0; index < 8; ++index) {
				flags[index] = 1;
			}
			if (y == 0) {
				flags[1] = 0;
				flags[7] = 0;
				flags[0] = 0;
			} else if (y == height - 1) {
				flags[3] = 0;
				flags[5] = 0;
				flags[4] = 0;
			}
			if (x == 0) {
				flags[5] = 0;
				flags[7] = 0;
				flags[6] = 0;
			} else if (x == width - 1) {
				flags[3] = 0;
				flags[1] = 0;
				flags[2] = 0;
			}
			for (int32_t direction = 0; direction < 8; ++direction) {
				if (flags[direction] == 0) {
					continue;
				}
				const int32_t nx = x + dx[direction];
				const int32_t ny = y + dy[direction];
				const int32_t neighbor_flat = ((level * height + ny) * width + nx);
				flags[direction] = in_bounds_flat(neighbor_flat) && int32_t(road_type_nibble[neighbor_flat]) == road_type ? 1 : 0;
			}
		};
		auto final_write_458a2f = [&](int32_t flat) {
			const int32_t current_road_type = int32_t(road_type_nibble[flat]) & 0x0f;
			if (current_road_type == 0) {
				return;
			}
			uint8_t flags[8] = {};
			build_neighbor_flags(flat, current_road_type, flags);
			const RoadArtClassification classified = h3maped_classify_road_art_458893(flags);
			const int32_t current_art = int32_t(road_art_u8[flat]) & 0xff;
			const int32_t current_class = current_art >= 0 && current_art < 17 ? variant_classes[current_art] : -1;
			if (current_class == classified.art_class
					&& int32_t(road_flip_a[flat]) == classified.flip_a
					&& int32_t(road_flip_b[flat]) == classified.flip_b) {
				stable_readback_skip_count += 1;
				return;
			}
			const int32_t bucket_count = bucket_counts[classified.art_class];
			const int32_t rng_value = rng.next();
			rng_call_count += 1;
			const int32_t final_art = bucket_starts[classified.art_class] + (bucket_count > 0 ? rng_value % bucket_count : 0);
			road_art_u8.set(flat, final_art);
			road_flip_a.set(flat, classified.flip_a);
			road_flip_b.set(flat, classified.flip_b);
			final_write_count += 1;
			final_write_cells[flat] = true;
			if (write_preview.size() < 24) {
				Dictionary write;
				write["flat_cell_index"] = flat;
				write["road_type"] = current_road_type;
				write["art_class"] = classified.art_class;
				write["art_variant_index"] = final_art;
				write["flip_a"] = classified.flip_a;
				write["flip_b"] = classified.flip_b;
				write["rng_value"] = rng_value;
				write_preview.append(write);
			}
		};
		auto line_visit_458e61 = [&](int32_t flat) {
			line_visit_call_count += 1;
			if (!in_bounds_flat(flat)) {
				invalid_flat_cell_count += 1;
				return;
			}
			const int32_t current_type = int32_t(road_type_nibble[flat]) & 0x0f;
			if (current_type == selected_road_type) {
				line_visit_skip_same_type_count += 1;
				return;
			}
			road_type_nibble.set(flat, selected_road_type);
			marked_cells[flat] = true;
			candidate_mark_count += 1;
			final_write_458a2f(flat);
			uint8_t retouch_flags[8] = {};
			build_neighbor_flags(flat, selected_road_type, retouch_flags);
			const int32_t x = flat % width;
			const int32_t y = (flat / width) % height;
			const int32_t level = flat / (width * height);
			for (int32_t direction = 0; direction < 8; ++direction) {
				if (retouch_flags[direction] == 0) {
					continue;
				}
				const int32_t neighbor_flat = ((level * height + y + dy[direction]) * width + x + dx[direction]);
				if (!in_bounds_flat(neighbor_flat)) {
					continue;
				}
				neighbor_retouch_call_count += 1;
				final_write_458a2f(neighbor_flat);
			}
		};
		for (int64_t chain_index = 0; chain_index < predecessor_chains.size(); ++chain_index) {
			if (Variant(predecessor_chains[chain_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary chain = Dictionary(predecessor_chains[chain_index]);
			if (!bool(chain.get("predecessor_chain_reaches_seed", false))) {
				continue;
			}
			PackedInt32Array flat_cells = chain.get("predecessor_chain_flat_cells", PackedInt32Array());
			for (int32_t cell_index = 0; cell_index < flat_cells.size(); ++cell_index) {
				line_visit_458e61(int32_t(flat_cells[cell_index]));
			}
		}
		PackedInt32Array final_road_flat_cells;
		for (const auto &entry : marked_cells) {
			final_road_flat_cells.append(entry.first);
		}
		int32_t final_grid_selected_count = 0;
		int32_t final_nonzero_art_count = 0;
		for (int32_t index = 0; index < road_type_nibble.size(); ++index) {
			if ((int32_t(road_type_nibble[index]) & 0x0f) == selected_road_type) {
				final_grid_selected_count += 1;
				if ((int32_t(road_art_u8[index]) & 0xff) != 0) {
					final_nonzero_art_count += 1;
				}
			}
		}
		Dictionary report;
		report["schema_id"] = "aurelion_h3maped_small_road_final_art_flip_v1";
		report["status"] = marked_cells.empty()
				? String("h3maped_0x458a2f_458893_final_art_flip_blocked_no_candidate_marks")
				: String("h3maped_0x458a2f_458893_final_art_flip_materialized_overlay_pending");
		report["function_addresses"] = Array::make("0x458e61", "0x458a2f", "0x458893", "0x49ae47", "0x49af1d");
		report["source"] = "Recovered from h3maped.exe: 0x458e61 marks a road-type nibble, calls 0x458a2f for the current cell, rebuilds neighbor flags through 0x4587f7/0x4bf3f4, then retouches neighboring same-type road cells. 0x458a2f calls 0x458893 and consumes 0x4e7276 only when current art class or flip readback differs.";
		report["width"] = width;
		report["height"] = height;
		report["level_count"] = level_count;
		report["selected_road_type"] = selected_road_type;
		report["line_visit_call_count"] = line_visit_call_count;
		report["line_visit_skip_same_type_count"] = line_visit_skip_same_type_count;
		report["candidate_mark_count"] = candidate_mark_count;
		report["final_road_cell_count"] = int32_t(marked_cells.size());
		report["final_road_type_grid_selected_count"] = final_grid_selected_count;
		report["final_nonzero_art_cell_count"] = final_nonzero_art_count;
		report["neighbor_retouch_call_count"] = neighbor_retouch_call_count;
		report["stable_readback_skip_count"] = stable_readback_skip_count;
		report["final_write_count"] = final_write_count;
		report["final_write_unique_cell_count"] = int32_t(final_write_cells.size());
		report["rng_call_count"] = rng_call_count;
		report["rng_state_after_final_art_uint32"] = int64_t(rng.state);
		report["invalid_flat_cell_count"] = invalid_flat_cell_count;
		report["final_road_flat_cells"] = final_road_flat_cells;
		report["final_road_type_nibble_u8"] = road_type_nibble;
		report["final_road_art_u8"] = road_art_u8;
		report["final_road_flip_a_u8"] = road_flip_a;
		report["final_road_flip_b_u8"] = road_flip_b;
		report["write_preview"] = write_preview;
		report["road_art_classifier_address"] = "0x458893";
		report["road_art_variant_runtime_table_address"] = "0x5a2f80";
		report["road_art_variant_source_table_address"] = "0x54198c";
		report["road_art_write_address"] = "0x49ae47";
		report["readback_address"] = "0x49af1d";
		report["materializes_final_road_art"] = !marked_cells.empty();
		report["materializes_serialized_road_overlay"] = false;
		report["complete_coordinate_vector_claim"] = false;
		report["blocked_reason"] = "Final road type/art/flip generated-cell grids are materialized for the current partial predecessor chains only. Runtime road overlay serialization remains blocked until complete +0x14b0 vector parity and special/object propagation are ported.";
		report["signature"] = h3maped_hash32_hex(String("h3maped_458a2f_458893_final_art:")
				+ String::num_int64(marked_cells.size()) + ":"
				+ String::num_int64(final_write_count) + ":"
				+ String::num_int64(rng_call_count) + ":"
				+ String::num_int64(rng.state));
		return report;
	}

	Dictionary h3maped_road_overlay_serialization_49b2b6_report(const Dictionary &terrain_fill, const Dictionary &final_art_materialization) {
		const int32_t width = std::max(1, int32_t(terrain_fill.get("width", 36)));
		const int32_t height = std::max(1, int32_t(terrain_fill.get("height", 36)));
		const int32_t level_count = std::max(1, int32_t(terrain_fill.get("level_count", 1)));
		const int32_t tile_count = width * height * level_count;
		PackedInt32Array tile_byte_0 = terrain_fill.get("tile_byte_0_terrain_id_u8", PackedInt32Array());
		PackedInt32Array tile_byte_1 = terrain_fill.get("tile_byte_1_terrain_art_u8", PackedInt32Array());
		PackedInt32Array tile_byte_2 = terrain_fill.get("tile_byte_2_river_type_u8", PackedInt32Array());
		PackedInt32Array tile_byte_3 = terrain_fill.get("tile_byte_3_river_art_u8", PackedInt32Array());
		PackedInt32Array tile_byte_4 = terrain_fill.get("tile_byte_4_road_type_u8", PackedInt32Array());
		PackedInt32Array tile_byte_5 = terrain_fill.get("tile_byte_5_road_art_u8", PackedInt32Array());
		PackedInt32Array tile_byte_6 = terrain_fill.get("tile_byte_6_terrain_flags_u8", PackedInt32Array());
		if (tile_byte_0.size() != tile_count) {
			tile_byte_0.resize(tile_count);
		}
		if (tile_byte_1.size() != tile_count) {
			tile_byte_1.resize(tile_count);
		}
		if (tile_byte_2.size() != tile_count) {
			tile_byte_2.resize(tile_count);
		}
		if (tile_byte_3.size() != tile_count) {
			tile_byte_3.resize(tile_count);
		}
		if (tile_byte_4.size() != tile_count) {
			tile_byte_4.resize(tile_count);
		}
		if (tile_byte_5.size() != tile_count) {
			tile_byte_5.resize(tile_count);
		}
		if (tile_byte_6.size() != tile_count) {
			tile_byte_6.resize(tile_count);
		}
		PackedInt32Array road_type = final_art_materialization.get("final_road_type_nibble_u8", PackedInt32Array());
		PackedInt32Array road_art = final_art_materialization.get("final_road_art_u8", PackedInt32Array());
		PackedInt32Array road_flip_a = final_art_materialization.get("final_road_flip_a_u8", PackedInt32Array());
		PackedInt32Array road_flip_b = final_art_materialization.get("final_road_flip_b_u8", PackedInt32Array());
		const bool source_arrays_ready = road_type.size() == tile_count
				&& road_art.size() == tile_count
				&& road_flip_a.size() == tile_count
				&& road_flip_b.size() == tile_count;
		int32_t road_overlay_cell_count = 0;
		int32_t road_type_selected_count = 0;
		int32_t road_art_nonzero_count = 0;
		int32_t road_flip_flagged_cell_count = 0;
		if (source_arrays_ready) {
			for (int32_t index = 0; index < tile_count; ++index) {
				const int32_t current_road_type = int32_t(road_type[index]) & 0x0f;
				if (current_road_type == 0) {
					tile_byte_4.set(index, 0);
					tile_byte_5.set(index, 0);
					tile_byte_6.set(index, int32_t(tile_byte_6[index]) & ~0x30);
					continue;
				}
				const int32_t current_road_art = int32_t(road_art[index]) & 0xff;
				const int32_t road_flip_bits = ((int32_t(road_flip_a[index]) & 0x01) << 4)
						| ((int32_t(road_flip_b[index]) & 0x01) << 5);
				tile_byte_4.set(index, current_road_type);
				tile_byte_5.set(index, current_road_art);
				tile_byte_6.set(index, (int32_t(tile_byte_6[index]) & ~0x30) | road_flip_bits);
				road_overlay_cell_count += 1;
				if (current_road_type == int32_t(final_art_materialization.get("selected_road_type", -1))) {
					road_type_selected_count += 1;
				}
				if (current_road_art != 0) {
					road_art_nonzero_count += 1;
				}
				if (road_flip_bits != 0) {
					road_flip_flagged_cell_count += 1;
				}
			}
		}
		Dictionary report;
		report["schema_id"] = "aurelion_h3maped_small_road_overlay_serialization_v1";
		report["status"] = source_arrays_ready && road_overlay_cell_count > 0
				? String("h3maped_0x49b2b6_road_overlay_bytes_materialized_partial_vector")
				: String("h3maped_0x49b2b6_road_overlay_bytes_blocked_missing_final_art_grid");
		report["function_address"] = "0x49b2b6";
		report["source"] = "Recovered from h3maped.exe 0x49b2b6: cell+0x24 bits 26..29 serialize to tile byte 4, cell+0x28 low byte serializes to tile byte 5, and cell+0x28 bits 19..20 serialize to tile byte 6 bits 4..5.";
		report["width"] = width;
		report["height"] = height;
		report["level_count"] = level_count;
		report["tile_count"] = tile_count;
		report["source_arrays_ready"] = source_arrays_ready;
		report["selected_road_type"] = final_art_materialization.get("selected_road_type", -1);
		report["road_overlay_cell_count"] = road_overlay_cell_count;
		report["road_type_selected_count"] = road_type_selected_count;
		report["road_art_nonzero_count"] = road_art_nonzero_count;
		report["road_flip_flagged_cell_count"] = road_flip_flagged_cell_count;
		report["expected_final_road_cell_count"] = final_art_materialization.get("final_road_cell_count", 0);
		report["expected_final_nonzero_art_cell_count"] = final_art_materialization.get("final_nonzero_art_cell_count", 0);
		report["tile_byte_0_terrain_id_u8"] = tile_byte_0;
		report["tile_byte_1_terrain_art_u8"] = tile_byte_1;
		report["tile_byte_2_river_type_u8"] = tile_byte_2;
		report["tile_byte_3_river_art_u8"] = tile_byte_3;
		report["tile_byte_4_road_type_u8"] = tile_byte_4;
		report["tile_byte_5_road_art_u8"] = tile_byte_5;
		report["tile_byte_6_flags_u8"] = tile_byte_6;
		report["tile_byte_4_source_bits"] = "cell+0x24 bits 26..29";
		report["tile_byte_5_source_bits"] = "cell+0x28 bits 0..7";
		report["tile_byte_6_road_flip_source_bits"] = "cell+0x28 bits 19..20 -> tile byte 6 bits 4..5";
		report["materializes_serialized_road_overlay"] = source_arrays_ready && road_overlay_cell_count > 0;
		report["materializes_serialized_river_overlay"] = false;
		report["complete_coordinate_vector_claim"] = false;
		report["blocked_reason"] = "Road overlay bytes are serialized only for the current partial predecessor-chain vector. Complete +0x14b0 vector parity, special/object propagation, river bytes, blockers, guards, rewards, and final runtime package adoption remain pending.";
		report["signature"] = h3maped_hash32_hex(String("h3maped_49b2b6_road_overlay:")
				+ String::num_int64(road_overlay_cell_count) + ":"
				+ String::num_int64(road_art_nonzero_count) + ":"
				+ String::num_int64(road_flip_flagged_cell_count));
		return report;
	}

	Dictionary h3maped_terrain_fill_with_road_overlay_49b2b6(const Dictionary &terrain_fill, const Dictionary &road_overlay_serialization) {
		Dictionary serialized = terrain_fill.duplicate(true);
		if (bool(road_overlay_serialization.get("materializes_serialized_road_overlay", false))) {
			serialized["tile_byte_4_road_type_u8"] = road_overlay_serialization.get("tile_byte_4_road_type_u8", PackedInt32Array());
			serialized["tile_byte_5_road_art_u8"] = road_overlay_serialization.get("tile_byte_5_road_art_u8", PackedInt32Array());
			serialized["tile_byte_6_terrain_flags_u8"] = road_overlay_serialization.get("tile_byte_6_flags_u8", PackedInt32Array());
			serialized["tile_byte_writeout_status"] = "0x49b2b6_terrain_and_partial_road_bytes_packed_overlay_bytes_pending";
			serialized["tile_byte_overlay_status"] = "road_overlay_bytes_materialized_from_0x458a2f_0x458893_partial_vector_river_pending";
			serialized["road_overlay_serialization_status"] = road_overlay_serialization.get("status", "");
			serialized["road_overlay_cell_count"] = road_overlay_serialization.get("road_overlay_cell_count", 0);
		}
		return serialized;
	}

	Dictionary h3maped_coordinate_vector_record_from_object(const Dictionary &record, int32_t vector_index, const String &phase, const String &append_address, const String &source_kind) {
	const int32_t x = int32_t(record.get("x", 0));
	const int32_t y = int32_t(record.get("y", 0));
	const int32_t level = int32_t(record.get("level", 0));
	Dictionary vector_record;
	vector_record["vector_index"] = vector_index;
	vector_record["byte_offset_from_begin"] = vector_index * 12;
	vector_record["record_size_bytes"] = 12;
	vector_record["phase"] = phase;
	vector_record["append_address"] = append_address;
	vector_record["push_helper_address"] = "0x4ae1fd";
	vector_record["source_kind"] = source_kind;
	vector_record["source_placement_id"] = record.get("placement_id", "");
	vector_record["source_runtime_zone_index"] = record.get("runtime_zone_index", -1);
	vector_record["source_zone_id"] = record.get("source_zone_id", -1);
	vector_record["x"] = x;
	vector_record["y"] = y;
	vector_record["level"] = level;
	vector_record["coordinate_triplet"] = Array::make(x, y, level);
	vector_record["primary_occupancy_key"] = record.get("primary_occupancy_key", h3maped_level_point_key(x, y, level));
	vector_record["coordinate_semantics"] = "project-adopted object anchor for the recovered generator+0x14b0 12-byte coordinate-vector entry";
	vector_record["executable_adjustment_status"] = "pending_exact_h3maped_object_metadata_offset_application";
	vector_record["road_reader_status"] = "pending_0x4ab52a_iteration_after_complete_vector_and_0x4aae7b_path_seed_port";
	vector_record["signature"] = h3maped_hash32_hex(String("h3maped_coordinate_vector_record:")
			+ String::num_int64(vector_index) + ":"
			+ String(source_kind) + ":"
			+ String::num_int64(x) + ":"
			+ String::num_int64(y) + ":"
			+ String::num_int64(level));
	return vector_record;
}

Dictionary h3maped_road_coordinate_vector_source_report(const Array &town_records, const Array &mine_records) {
	Dictionary source;
	source["schema_id"] = "aurelion_h3maped_small_road_coordinate_vector_source_v1";
	source["status"] = "h3maped_generator_plus_0x14b0_partial_coordinate_vector_records_materialized";
	source["source"] = "Recovered from h3maped.exe: direct town placement and object placement push 12-byte coordinate records into generator+0x14b0 through 0x4ae1fd; final road phase reads begin/end from +0x14b4/+0x14b8. This ledger materializes only the already adopted town and mine coordinate records.";
	source["vector_object_offset"] = "+0x14b0";
	source["vector_begin_offset"] = "+0x14b4";
	source["vector_end_offset"] = "+0x14b8";
	source["vector_capacity_offset"] = "+0x14bc";
	source["coordinate_record_size_bytes"] = 12;
	source["coordinate_push_helper_address"] = "0x4ae1fd";
	source["direct_town_append_address"] = "0x4a959b";
	source["generic_object_append_address"] = "0x4a6bb4";
	source["final_reader_address"] = "0x4ab52a";
	source["materialized_town_record_count"] = town_records.size();
	source["materialized_mine_record_count"] = mine_records.size();
	source["materialized_partial_coordinate_record_count"] = town_records.size() + mine_records.size();
	source["materialized_partial_coordinate_byte_count"] = int32_t(town_records.size() + mine_records.size()) * 12;
	source["materialized_partial_vector_begin_byte_offset"] = 0;
	source["materialized_partial_vector_end_byte_offset"] = int32_t(town_records.size() + mine_records.size()) * 12;
	source["complete_executable_vector_claim"] = false;
	source["blocked_reason"] = "Only direct town records and selected mine records are currently adopted into the package; weighted rewards, guards, monsters, decorations, and final object passes that may also affect the executable vector are not ported.";
	source["coordinate_adjustment_status"] = "partial_project_anchor_entries_materialized_exact_h3maped_metadata_offsets_pending";
	source["reader_iteration_status"] = "pending_0x4ab52a_complete_vector_iteration";
	Array partial_records;
	int32_t vector_index = 0;
	for (int64_t index = 0; index < town_records.size(); ++index) {
		if (Variant(town_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		partial_records.append(h3maped_coordinate_vector_record_from_object(
				Dictionary(town_records[index]),
				vector_index,
				"0x4a93a2_direct_town_placement",
				"0x4a959b",
				"town"));
		vector_index += 1;
	}
	for (int64_t index = 0; index < mine_records.size(); ++index) {
		if (Variant(mine_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		partial_records.append(h3maped_coordinate_vector_record_from_object(
				Dictionary(mine_records[index]),
				vector_index,
				"0x4a9911_0x4a9641_object_placement",
				"0x4a6bb4",
				"mine"));
		vector_index += 1;
	}
	source["materialized_partial_coordinate_records"] = partial_records;
	source["materialized_partial_coordinate_record_count"] = partial_records.size();
	source["materialized_partial_coordinate_byte_count"] = int32_t(partial_records.size()) * 12;
	source["materialized_partial_vector_end_byte_offset"] = int32_t(partial_records.size()) * 12;
	Array recovered_sources;
	Dictionary town_source;
	town_source["phase"] = "0x4a93a2_direct_town_placement";
	town_source["append_address"] = "0x4a959b";
	town_source["source_zone_writeback"] = "source_zone+0x30";
	town_source["record_count"] = town_records.size();
	town_source["coordinate_semantics"] = "post virtual-placement coordinate adjusted by object metadata offsets before vector push";
	recovered_sources.append(town_source);
	Dictionary mine_source;
	mine_source["phase"] = "0x4a9911_0x4a9641_object_placement";
	mine_source["append_address"] = "0x4a6bb4";
	mine_source["record_count"] = mine_records.size();
	mine_source["coordinate_semantics"] = "selected object coordinate adjusted by object metadata offsets before vector push";
	recovered_sources.append(mine_source);
	source["recovered_sources"] = recovered_sources;
	source["signature"] = h3maped_hash32_hex(String("h3maped_road_coordinate_vector_source:") + String::num_int64(partial_records.size()) + ":" + String::num_int64(town_records.size()) + ":" + String::num_int64(mine_records.size()));
	return source;
}

	Dictionary h3maped_road_adapter_boundary_from_connections(const Array &connection_records, const Dictionary &terrain_fill, const Dictionary &coordinate_vector_source, int64_t rng_state_before_road_phase) {
		Dictionary boundary;
		boundary["schema_id"] = "aurelion_h3maped_small_road_adapter_boundary_v1";
		boundary["generation_status"] = "h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending";
		boundary["road_materialization_status"] = "h3maped_0x49b2b6_road_overlay_bytes_materialized_partial_vector";
		boundary["full_generation_status"] = "h3maped_road_phase_partial_overlay_serialized_generation_blocked";
	boundary["source"] = "Recovered from /root/Downloads/h3maped.exe disassembly; no synthetic road geometry is emitted from this boundary.";
	boundary["h3maped_phase_runner_address"] = "0x4ab52a";
	boundary["h3maped_cell_state_reset_address"] = "0x4aae2f";
	boundary["h3maped_path_state_seed_address"] = "0x4aae7b";
	boundary["h3maped_road_adapter_entry_address"] = "0x4ab37f";
	boundary["h3maped_road_toolkit_entry_address"] = "0x4b4243";
	boundary["h3maped_terrain_adapter_vtable_address"] = "0x540a14";
	boundary["h3maped_road_adapter_vtable_address"] = "0x540a34";
	boundary["h3maped_road_toolkit_initial_vtable_address"] = "0x5419d4";
	boundary["h3maped_road_toolkit_runtime_vtable_address"] = "0x5419f4";
	boundary["path_state_reset"] = h3maped_path_state_reset_4aae2f_report(terrain_fill);
	boundary["coordinate_vector_source"] = coordinate_vector_source;
	Dictionary path_state_seed = h3maped_path_state_seed_4aae7b_report(terrain_fill, coordinate_vector_source);
	boundary["path_state_seed"] = path_state_seed;
		boundary["road_pair_iteration"] = h3maped_road_pair_iteration_4ab52a_report(coordinate_vector_source, rng_state_before_road_phase, path_state_seed);
		Dictionary pair_iteration_for_marking = boundary.get("road_pair_iteration", Dictionary());
		const int32_t selected_road_type_for_marking = int32_t(pair_iteration_for_marking.get("selected_road_type", 0));
		Dictionary final_art_materialization = h3maped_road_final_art_flip_458a2f_report(terrain_fill, path_state_seed, pair_iteration_for_marking);
		boundary["road_final_art_materialization"] = final_art_materialization;
		Dictionary road_overlay_serialization = h3maped_road_overlay_serialization_49b2b6_report(terrain_fill, final_art_materialization);
		boundary["road_overlay_serialization"] = road_overlay_serialization;
		Dictionary candidate_marking = h3maped_road_candidate_marking_49aec5_report(terrain_fill, path_state_seed, selected_road_type_for_marking);
		boundary["road_candidate_marking"] = candidate_marking;
		boundary["road_adapter_bridge"] = h3maped_road_adapter_bridge_4ab37f_report(terrain_fill, path_state_seed);
		boundary["road_toolkit_entry"] = h3maped_road_toolkit_4b4243_report(terrain_fill);
	boundary["coordinate_vector_begin_offset"] = "+0x14b4";
	boundary["coordinate_vector_end_offset"] = "+0x14b8";
	boundary["coordinate_record_size_bytes"] = 12;
	boundary["partial_coordinate_record_count"] = coordinate_vector_source.get("materialized_partial_coordinate_record_count", 0);
	boundary["partial_coordinate_byte_count"] = coordinate_vector_source.get("materialized_partial_coordinate_byte_count", 0);
	boundary["partial_coordinate_vector_status"] = coordinate_vector_source.get("status", "");
	Dictionary pair_iteration = boundary.get("road_pair_iteration", Dictionary());
	boundary["road_type_rng_function_address"] = "0x4e7276";
	boundary["road_type_rng_value"] = pair_iteration.get("road_type_rng_value", 0);
	boundary["selected_road_type"] = pair_iteration.get("selected_road_type", 0);
	boundary["road_type_rng_modulus"] = 3;
	boundary["road_type_rng_addend"] = 1;
	boundary["road_type_min"] = 1;
	boundary["road_type_max"] = 3;
	boundary["candidate_low_word_threshold_hex"] = "0x7530";
	boundary["candidate_low_word_threshold"] = 0x7530;
	boundary["road_pair_candidate_iteration_count"] = pair_iteration.get("pair_candidate_iteration_count", 0);
	boundary["predecessor_chain_status"] = path_state_seed.get("predecessor_chain_status", "");
	boundary["predecessor_chain_count"] = path_state_seed.get("predecessor_chain_count", 0);
	boundary["predecessor_chain_total_cell_visits"] = path_state_seed.get("predecessor_chain_total_cell_visits", 0);
	boundary["predecessor_chain_max_step_count"] = path_state_seed.get("predecessor_chain_max_step_count", 0);
		boundary["candidate_marking_status"] = candidate_marking.get("status", "");
		boundary["candidate_marked_cell_count"] = candidate_marking.get("candidate_marked_cell_count", 0);
		boundary["candidate_mark_write_attempt_count"] = candidate_marking.get("candidate_mark_write_attempt_count", 0);
		boundary["final_art_materialization_status"] = final_art_materialization.get("status", "");
		boundary["final_road_cell_count"] = final_art_materialization.get("final_road_cell_count", 0);
		boundary["final_road_art_rng_call_count"] = final_art_materialization.get("rng_call_count", 0);
		boundary["road_overlay_serialization_status"] = road_overlay_serialization.get("status", "");
		boundary["road_overlay_cell_count"] = road_overlay_serialization.get("road_overlay_cell_count", 0);
	boundary["connection_count"] = connection_records.size();
	boundary["connection_records_have_geometry"] = false;
	boundary["generated_road_segment_count"] = 0;
	boundary["generated_road_cell_count"] = 0;
	boundary["no_synthetic_road_geometry"] = true;
		boundary["blocked_reason"] = "The 0x4aae7b path-state propagation, 0x4ab37f adapter bridge, 0x49aec5 candidate road-type marks, 0x458a2f/0x458893 final art/flip grid, and 0x49b2b6 road overlay byte serialization are recovered for the current partial vector. Complete +0x14b0 coordinate-vector parity, special/object propagation, blockers, guards, rewards, and final runtime package adoption remain pending, so the reset path must not emit runtime roads.";
	boundary["cell_0x24_road_type_bits"] = "26..29";
	boundary["cell_0x28_road_art_bits"] = "0..7";
	boundary["cell_0x28_road_flip_bits"] = "19..20";
	Array phase_sequence;
	phase_sequence.append("0x4ab52a_iterate_generator_plus_0x14b4_coordinate_records");
	phase_sequence.append("0x4aae2f_reset_cell_low_word_and_coordinate_chain_state");
	phase_sequence.append("0x4aae7b_seed_path_state_from_connection_coordinate");
		phase_sequence.append("0x4ab37f_construct_type_random_map_and_type_road_map_adapters");
		phase_sequence.append("0x49aec5_candidate_road_type_mark_materialized_art_pending");
		phase_sequence.append("0x458a2f_0x458893_final_art_flip_materialized_overlay_pending");
		phase_sequence.append("0x49b2b6_road_overlay_bytes_materialized_partial_vector");
	boundary["phase_sequence"] = phase_sequence;
	boundary["signature"] = h3maped_hash32_hex(String("h3maped_road_adapter_boundary:") + String::num_int64(connection_records.size()) + String(":0x4ab52a:0x4ab37f:0x4b4243"));
	return boundary;
}

Dictionary inspection_partial_materialized_payload_blocked(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary port = inspect_port(normalized_config);
	Dictionary result;
	if (!bool(port.get("ok", false))) {
		result["ok"] = false;
		result["status"] = "h3maped_small_materialization_blocked_by_inspection";
		result["generation_status"] = "h3maped_small_materialization_blocked_by_inspection";
		result["h3maped_small_port"] = port;
		result["extension_profile"] = extension_profile;
		return result;
	}
	Dictionary payload = port.get("selected_template_payload", Dictionary());
	Dictionary runtime_build = payload.get("runtime_zone_build", Dictionary());
	Dictionary footprint = runtime_build.get("zone_footprint_placement", Dictionary());
	Dictionary terrain_fill = footprint.get("terrain_fill_repaint", Dictionary());
	Array town_records = h3maped_town_records_from_port(normalized_config, payload);
	Array mine_records = h3maped_mine_records_from_port(normalized_config, payload);
	Array connection_records = h3maped_connection_records_from_port(payload, normalized_config);
	Dictionary connection_payload = h3maped_connection_payload_from_records(connection_records, normalized_config);
	Dictionary road_coordinate_vector_source = h3maped_road_coordinate_vector_source_report(town_records, mine_records);
	Dictionary mine_reward_placement = payload.get("guard_reward_monster_placement", Dictionary());
	const int64_t rng_state_before_road_phase = int64_t(mine_reward_placement.get("treasure_reward_rng_state_after_0x4aa354_uint32", mine_reward_placement.get("mine_object_rng_state_after_0x4a9911_0x4a9641_uint32", runtime_build.get("rng_state_after_runtime_zone_build", 0))));
	Dictionary road_adapter_boundary = h3maped_road_adapter_boundary_from_connections(connection_records, terrain_fill, road_coordinate_vector_source, rng_state_before_road_phase);
	Dictionary road_overlay_serialization = road_adapter_boundary.get("road_overlay_serialization", Dictionary());
	Dictionary terrain_fill_with_roads = h3maped_terrain_fill_with_road_overlay_49b2b6(terrain_fill, road_overlay_serialization);
	Dictionary terrain_grid = h3maped_terrain_grid_from_fill(normalized_config, terrain_fill_with_roads);
	connection_payload["road_adapter_boundary"] = road_adapter_boundary;
	connection_payload["road_materialization_status"] = road_adapter_boundary.get("road_materialization_status", "h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending");

	Dictionary town_guard_placement;
	town_guard_placement["schema_id"] = "aurelion_h3maped_small_town_guard_placement_v1";
	town_guard_placement["generation_status"] = "h3maped_0x4a93a2_towns_materialized_guards_pending";
	town_guard_placement["town_generation_status"] = "h3maped_0x4a93a2_town_records_adopted";
	town_guard_placement["guard_generation_status"] = "h3maped_0x4a79a3_link_guard_payload_ported_guard_object_materialization_pending";
	town_guard_placement["town_records"] = town_records;
	town_guard_placement["guard_records"] = Array();
	town_guard_placement["town_count"] = town_records.size();
	town_guard_placement["guard_count"] = 0;
	town_guard_placement["connection_payload"] = connection_payload;

	Dictionary object_placement;
	object_placement["schema_id"] = "aurelion_h3maped_small_object_placement_v1";
	object_placement["generation_status"] = "h3maped_0x4a9911_0x4a9641_mines_materialized_rewards_guards_pending";
	object_placement["object_placements"] = mine_records;
	object_placement["object_count"] = mine_records.size();
	Dictionary category_counts;
	category_counts["mine"] = mine_records.size();
	object_placement["category_counts"] = category_counts;
	Dictionary road_network;
	road_network["schema_id"] = "aurelion_h3maped_small_road_network_v1";
	road_network["generation_status"] = road_adapter_boundary.get("road_materialization_status", "");
	road_network["road_adapter_boundary"] = road_adapter_boundary;
	road_network["coordinate_vector_source"] = road_coordinate_vector_source;
	road_network["road_segments"] = Array();
	road_network["road_cell_count"] = 0;
	road_network["no_synthetic_road_geometry"] = true;

	Dictionary metrics;
	metrics["width"] = terrain_grid.get("width", normalized_config.get("width", 36));
	metrics["height"] = terrain_grid.get("height", normalized_config.get("height", 36));
	metrics["level_count"] = terrain_grid.get("level_count", normalized_config.get("level_count", 1));
	metrics["tile_count"] = terrain_grid.get("tile_count", 0);
	metrics["town_count"] = town_records.size();
	metrics["mine_count"] = mine_records.size();
	metrics["guard_count"] = 0;
	metrics["road_cell_count"] = 0;
	metrics["connection_count"] = connection_records.size();
	metrics["border_guard_link_count"] = connection_payload.get("border_guard_link_count", 0);

	result["ok"] = false;
	result["status"] = "h3maped_small_clean_restart_inspection_partial_blocked";
	result["generation_status"] = "h3maped_small_clean_restart_inspection_partial_blocked";
	result["full_generation_status"] = "h3maped_small_phase_materialized_partial_roads_rewards_guards_pending";
	result["adoption_status"] = "archived_inspection_partial_payload_not_runtime_package";
	result["error_code"] = "h3maped_partial_payload_not_exported";
	result["schema_id"] = "aurelion_h3maped_small_materialized_payload_v1";
	result["schema_version"] = 1;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = port;
	result["selected_template_payload"] = payload;
	result["terrain_grid"] = terrain_grid;
	result["object_placement"] = object_placement;
	result["object_placements"] = mine_records;
	result["connection_payload"] = connection_payload;
	result["connection_records"] = connection_records;
	result["road_coordinate_vector_source"] = road_coordinate_vector_source;
	result["road_adapter_boundary"] = road_adapter_boundary;
	result["town_guard_placement"] = town_guard_placement;
	result["town_records"] = town_records;
	result["guard_records"] = Array();
	result["road_network"] = road_network;
	result["river_network"] = Dictionary();
	result["route_graph"] = Dictionary();
	result["metrics"] = metrics;
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["no_authored_writeback"] = true;
	result["extension_profile"] = extension_profile;
	result["materialization_gap"] = "Archived inspection-only partial payload: complete roads, connection blockers, rewards through 0x4aa354, guard stacks, monsters, and final h3maped writeout phases remain pending.";
	return result;
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
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["h3maped_binary_path"] = BINARY_PATH;
	result["h3maped_binary_sha256"] = BINARY_SHA256;
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
