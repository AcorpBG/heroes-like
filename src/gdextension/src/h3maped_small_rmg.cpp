#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <set>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
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

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
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
	const char *trigger = "no classed relation";
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

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD = 0x00ff0000U;
constexpr uint32_t H3MAPED_ZONE_WORD_CLEAR_MASK = 0xff00ffffU;

struct H3MaskPoint {
	int32_t dx = 0;
	int32_t dy = 0;
};

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

Dictionary h3_cell_dictionary(int32_t x, int32_t y, int32_t level) {
	Dictionary cell;
	cell["x"] = x;
	cell["y"] = y;
	cell["level"] = level;
	return cell;
}

String h3_slot_id_2(int32_t slot) {
	if (slot >= 0 && slot < 10) {
		return String("0") + String::num_int64(slot);
	}
	return String::num_int64(slot);
}

Array project_default_faction_pool() {
	return Array::make("faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake");
}

String project_town_for_faction(const String &faction_id) {
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

String project_faction_for_player_slot(const Dictionary &normalized_config, int32_t player_slot) {
	Array faction_ids = normalized_config.get("faction_ids", Array());
	if (faction_ids.is_empty()) {
		faction_ids = project_default_faction_pool();
	}
	if (faction_ids.is_empty()) {
		return "faction_embercourt";
	}
	const int64_t index = std::max(0, player_slot - 1) % faction_ids.size();
	return String(faction_ids[index]);
}

String project_player_type_for_slot(const Dictionary &normalized_config, int32_t player_slot) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(1, int32_t(constraints.get("human_count", 1)));
	return player_slot <= human_count ? "human" : "computer";
}

int32_t h3maped_guard_scaled_value_4a65a5(int32_t raw_value, int32_t mode) {
	static constexpr int32_t THRESHOLD_1[] = { 50000, 2500, 1500, 1000, 500, 0 };
	static constexpr int32_t THRESHOLD_2[] = { 50000, 7500, 7500, 7500, 5000, 5000 };
	static constexpr int32_t SLOPE_1[] = { 0, 2, 3, 4, 6, 6 };
	static constexpr int32_t SLOPE_2[] = { 0, 2, 3, 4, 4, 6 };
	const int32_t clamped_mode = std::max(0, std::min(5, mode));
	const int32_t clamped_value = std::max(0, raw_value);
	int32_t scaled_value = 0;
	if (clamped_value > THRESHOLD_1[clamped_mode]) {
		scaled_value += ((clamped_value - THRESHOLD_1[clamped_mode]) * SLOPE_1[clamped_mode]) / 4;
	}
	if (clamped_value > THRESHOLD_2[clamped_mode]) {
		scaled_value += ((clamped_value - THRESHOLD_2[clamped_mode]) * SLOPE_2[clamped_mode]) / 4;
	}
	return scaled_value;
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
	std::map<int32_t, std::vector<int32_t>> rows_by_class;
	std::map<std::array<int32_t, 3>, std::vector<int32_t>> rows_by_class_flags;
	bool ok = true;
	int32_t decoded_count = 0;
	for (int32_t row_index = 0; row_index < row_count; ++row_index) {
		const int64_t row_va = table_va + int64_t(row_index) * 8;
		uint32_t shape_class = 0;
		uint8_t flag_a = 0;
		uint8_t flag_b = 0;
		if (!read_h3maped_u32_le(file, row_va, shape_class) || !read_h3maped_u8(file, row_va + 4, flag_a) || !read_h3maped_u8(file, row_va + 5, flag_b)) {
			ok = false;
			break;
		}
		rows_by_class[int32_t(shape_class)].push_back(row_index);
		if (include_flag_buckets) {
			rows_by_class_flags[{ int32_t(shape_class), int32_t(flag_a), int32_t(flag_b) }].push_back(row_index);
		}
		decoded_count += 1;
	}
	Dictionary report;
	report["id"] = id;
	report["terrain_ids"] = terrain_ids;
	report["table_address"] = address;
	report["table_file_offset"] = h3maped_va_to_file_offset(table_va);
	report["expected_row_count"] = row_count;
	report["decoded_row_count"] = decoded_count;
	report["status"] = ok && decoded_count == row_count ? String("decoded_from_h3maped_exe") : String("decode_failed");
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
	int32_t probability_threshold = -1;
	bool selected_special_bucket = false;
	if (rock_selector) {
		bucket = row_indices_for_class_flags(rows, shape_class, flag_a, flag_b);
	} else if (full_native) {
		const std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		const std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
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
	const int32_t art_rng_value = rng.next();
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
	report["blocked_next"] = "feed selected visual rows into 0x4bad0f and 0x49acf6 during the live 0x4bb74b/0x4bc5f0 sequence";
	return report;
}

uint32_t h3maped_scratch_word_4bad0f(int32_t terrain_id, int32_t selected_row, int32_t flag_a, int32_t flag_b) {
	return 1U
			| ((uint32_t(terrain_id) & 0x0fU) << 1U)
			| ((uint32_t(selected_row) & 0x7fU) << 5U)
			| ((uint32_t(flag_a) & 0x01U) << 12U)
			| ((uint32_t(flag_b) & 0x01U) << 13U);
}

Dictionary terrain_scratch_write_sample(const char *id, int32_t terrain_id, int32_t selected_row, int32_t flag_a, int32_t flag_b) {
	const uint32_t scratch_word = h3maped_scratch_word_4bad0f(terrain_id, selected_row, flag_a, flag_b);
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
	report["blocked_next"] = "apply selected rows through the live 0x4bb74b/0x4bc5f0 scratch-feedback sequence before adopting generated-cell art/flag words";
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
	report["status"] = "0x4bb039_0x5436e0_0x4bb075_relation_classifier_ported_inspection_only";
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
	report["blocked_next"] = "feed generated-grid relations through exact row selection and live 0x4bb74b/0x4bc5f0 scratch feedback";
	return report;
}

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

int32_t h3maped_scratch_terrain_id(uint32_t scratch_word) {
	return int32_t((scratch_word >> 1U) & 0x0fU);
}

int32_t h3maped_scratch_art_id(uint32_t scratch_word) {
	return int32_t((scratch_word >> 5U) & 0x7fU);
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

int64_t h3maped_grid_key(int32_t level, int32_t x, int32_t y) {
	return (int64_t(level) << 40) | (int64_t(y) << 20) | int64_t(x);
}

void h3maped_decode_grid_key(int64_t key, int32_t &level, int32_t &x, int32_t &y) {
	level = int32_t(key >> 40);
	y = int32_t((key >> 20) & 0xfffff);
	x = int32_t(key & 0xfffff);
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
	return horizontal_pair_gate || vertical_pair_gate || (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && same_class_region_gate);
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

int32_t h3maped_frontier_retouch_4bbd01(PackedInt32Array &terrain_code_u16, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, Array *sample_records, int32_t sample_limit, std::vector<int64_t> *changed_keys_out = nullptr) {
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
			if (changed_keys_out != nullptr) {
				changed_keys_out->push_back(h3maped_grid_key(level, target_x, target_y));
			}
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
		int32_t start_same = 0;
		if (same_terrain_mask[0] == 0) {
			do {
				start_same = (start_same + 1) & 7;
				if (start_same == 0) {
					return changed_count;
				}
			} while (same_terrain_mask[start_same] == 0);
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
			if (same_terrain_mask[scan] != 0) {
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
			} while (same_terrain_mask[scan] == 0);
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
					retouch("0x4bbd01_same_class_zero_run", target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
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

bool select_visual_row_for_grid_cell_with_neighbor_mask(const std::vector<TerrainVisualRow> &rows, int32_t terrain_id, const TerrainClassResult &classified, int32_t neighbor_mask, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b, String &selector_address, String &selector_kind, int32_t &probability_threshold, int32_t &probability_rng_value) {
	std::vector<int32_t> bucket;
	probability_threshold = -1;
	probability_rng_value = -1;
	const bool rock_selector = terrain_id == 9;
	if (rock_selector) {
		selector_address = "0x4baabf";
		selector_kind = "rock_class_flag_bucket";
		bucket = row_indices_for_class_flags(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		selector_address = "0x4ba938";
		selector_kind = "full_native_special_frequency_masked_by_0x4bce6d";
		std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
		if (!special.empty()) {
			probability_rng_value = rng.next();
			const int32_t clamped_mask = std::max(0, neighbor_mask);
			probability_threshold = (constructor_probability_for_terrain_id(terrain_id) * clamped_mask) / 8;
			const bool selected_special_bucket = (probability_rng_value % 100) < probability_threshold;
			bucket = selected_special_bucket ? special : ordinary;
		} else {
			bucket = ordinary;
		}
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

Dictionary h3maped_repaint_live_visual_feedback_boundary_report(const std::vector<uint32_t> &zone_words, const Array &selected_terrain_codes, const PackedInt32Array &final_terrain_code_u16, int32_t width, int32_t height, int32_t level_count, uint32_t rng_state_before_visual_selection) {
	Dictionary report;
	report["status"] = "0x4a4025_0x4bb74b_0x4bc5f0_repaint_queue_live_scratch_visual_feedback_boundary";
	report["source"] = "projects h3maped 0x4bcfc3 / 0x4bce6d / 0x4bad0f / 0x49acf6 visual writes during the 0x4a4025 full-water repaint, per-zone 0x4bb74b repaint sequence, and recovered 0x4bc5f0 set A/B queue drain; public package adoption remains blocked";
	report["ported_addresses"] = Array::make("0x4a4025", "0x4a4082", "0x4a415a", "0x4bb74b", "0x4bba13", "0x4bba36", "0x4bba59", "0x4bbd01", "0x4bc5f0", "0x4bc674", "0x4bc6e0", "0x4bc74c", "0x4bc928", "0x4bc988", "0x4bbfcc", "0x4bcfc3", "0x4bce6d", "0x4ba938", "0x4ba989", "0x4baabf", "0x4bad0f", "0x49acf6");
	report["exact_queue_drain_complete"] = true;
	report["adopts_into_runtime_grid"] = false;
	report["materializes_package_tiles"] = false;
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;

	const int32_t level_tile_count = width * height;
	PackedInt32Array live_terrain_code_u16;
	live_terrain_code_u16.resize(int32_t(zone_words.size()));
	for (int32_t index = 0; index < live_terrain_code_u16.size(); ++index) {
		live_terrain_code_u16.set(index, 8);
	}

	TerrainVisualGridTables tables;
	bool visual_tables_decoded = false;
	if (FileAccess::file_exists(BINARY_PATH)) {
		Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
		if (file.is_valid() && file->is_open()) {
			tables.dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
			tables.sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
			tables.normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
			tables.water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
			tables.rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);
			visual_tables_decoded = tables.dirt_rows.size() == 46 && tables.sand_rows.size() == 24 && tables.normal_rows.size() == 79 && tables.water_rows.size() == 33 && tables.rock_rows.size() == 48;
		}
	}
	report["visual_tables_decoded"] = visual_tables_decoded;

	PackedInt32Array live_scratch_word_u16;
	PackedInt32Array live_cell_word_0x24_u32;
	PackedInt32Array live_cell_word_0x28_u32;
	live_scratch_word_u16.resize(live_terrain_code_u16.size());
	live_cell_word_0x24_u32.resize(live_terrain_code_u16.size());
	live_cell_word_0x28_u32.resize(live_terrain_code_u16.size());

	H3MapedRng live_visual_rng{ rng_state_before_visual_selection };
	Dictionary neighbor_mask_histogram;
	Dictionary selector_kind_histogram;
	Array sample_records;
	int32_t live_visual_attempt_count = 0;
	int32_t live_visual_write_count = 0;
	int32_t live_visual_missing_bucket_count = 0;
	int32_t live_initial_water_attempt_count = 0;
	int32_t live_repaint_attempt_count = 0;
	int32_t live_queue_attempt_count = 0;
	int32_t live_full_native_cell_count = 0;
	int32_t live_terrain_art_nonzero_cell_count = 0;
	int32_t live_terrain_flag_cell_count = 0;

	auto live_accept_neighbor = [&](int32_t neighbor_index, int32_t terrain_id) -> bool {
		if (neighbor_index < 0 || neighbor_index >= live_scratch_word_u16.size()) {
			return false;
		}
		const uint32_t neighbor_scratch = uint32_t(int32_t(live_scratch_word_u16[neighbor_index]));
		if ((neighbor_scratch & 0x01U) == 0U) {
			return false;
		}
		if (h3maped_scratch_terrain_id(neighbor_scratch) != terrain_id) {
			return false;
		}
		return h3maped_scratch_art_id(neighbor_scratch) != 0;
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
	auto write_live_visual_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id, const char *source_branch) -> bool {
		if (!visual_tables_decoded || x < 0 || y < 0 || x >= width || y >= height) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * width + x;
		if (index < 0 || index >= live_terrain_code_u16.size()) {
			return false;
		}
		live_visual_attempt_count += 1;
		const TerrainClassResult classified = classify_grid_cell(live_terrain_code_u16, width, height, level_tile_count, level, x, y, terrain_id);
		const int32_t neighbor_mask = live_neighbor_mask_for_cell(level, x, y, terrain_id);
		const String mask_key = String::num_int64(neighbor_mask);
		neighbor_mask_histogram[mask_key] = int32_t(neighbor_mask_histogram.get(mask_key, 0)) + 1;
		if (classified.shape_class == 0) {
			live_full_native_cell_count += 1;
		}
		int32_t selected_row = -1;
		int32_t out_flag_a = 0;
		int32_t out_flag_b = 0;
		int32_t probability_threshold = -1;
		int32_t probability_rng_value = -1;
		String selector_address;
		String selector_kind;
		const std::vector<TerrainVisualRow> &rows = visual_rows_for_terrain_id(tables, terrain_id);
		const bool selected = select_visual_row_for_grid_cell_with_neighbor_mask(rows, terrain_id, classified, neighbor_mask, live_visual_rng, selected_row, out_flag_a, out_flag_b, selector_address, selector_kind, probability_threshold, probability_rng_value);
		selector_kind_histogram[selector_kind] = int32_t(selector_kind_histogram.get(selector_kind, 0)) + 1;
		if (!selected) {
			live_visual_missing_bucket_count += 1;
			return false;
		}
		const uint32_t scratch_word = h3maped_scratch_word_4bad0f(terrain_id, selected_row, out_flag_a, out_flag_b);
		const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU)
				| ((uint32_t(selected_row) & 0xffU) << 6U);
		const uint32_t generated_cell_word_0x28 = ((uint32_t(out_flag_a) & 0x01U) << 15U)
				| ((uint32_t(out_flag_b) & 0x01U) << 16U);
		live_scratch_word_u16.set(index, int32_t(scratch_word));
		live_cell_word_0x24_u32.set(index, int32_t(generated_cell_word_0x24));
		live_cell_word_0x28_u32.set(index, int32_t(generated_cell_word_0x28));
		live_visual_write_count += 1;
		if (selected_row != 0) {
			live_terrain_art_nonzero_cell_count += 1;
		}
		if (((generated_cell_word_0x28 >> 15U) & 0x03U) != 0U) {
			live_terrain_flag_cell_count += 1;
		}
		if (sample_records.size() < 16 && (classified.shape_class == 0 || neighbor_mask < 4)) {
			Dictionary sample;
			sample["index"] = index;
			sample["x"] = x;
			sample["y"] = y;
			sample["level"] = level;
			sample["terrain_id"] = terrain_id;
			sample["class"] = classified.shape_class;
			sample["neighbor_mask"] = neighbor_mask;
			sample["source_branch"] = source_branch;
			sample["selector_address"] = selector_address;
			sample["selector_kind"] = selector_kind;
			sample["probability_threshold"] = probability_threshold;
			sample["probability_rng_value"] = probability_rng_value;
			sample["selected_row"] = selected_row;
			sample["scratch_word_u16"] = int32_t(scratch_word);
			sample["generated_cell_word_0x24_u32"] = int64_t(generated_cell_word_0x24);
			sample["generated_cell_word_0x28_u32"] = int64_t(generated_cell_word_0x28);
			sample_records.append(sample);
		}
		return true;
	};

	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				live_initial_water_attempt_count += 1;
				write_live_visual_cell(level, x, y, 8, "0x4a4025_initial_water_repaint");
			}
		}
	}

	std::set<int64_t> set_a;
	std::set<int64_t> set_b;
	Array seed_samples;
	Array drain_samples;
	int32_t changed_cell_update_count = 0;
	int32_t set_a_insert_count = 0;
	int32_t set_b_insert_count = 0;
	int32_t max_set_a_count = 0;
	int32_t max_set_b_count = 0;

	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		const int64_t key = h3maped_grid_key(level, x, y);
		if (set_b.insert(key).second) {
			set_b_insert_count += 1;
		}
		if (seed_samples.size() < 12) {
			Dictionary sample;
			sample["x"] = x;
			sample["y"] = y;
			sample["level"] = level;
			sample["terrain_before_drain"] = neighbor;
			sample["current_repaint_terrain"] = current_terrain;
			sample["source_branch"] = source_branch;
			seed_samples.append(sample);
		}
	};
	auto seed_4bba59 = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain) {
		append_set_b(level, x, y - 1, current_terrain, "0x4bba59_north_south_cardinal");
		append_set_b(level, x, y + 1, current_terrain, "0x4bba59_north_south_cardinal");
		append_set_b(level, x - 1, y, current_terrain, "0x4bba59_west_east_cardinal");
		append_set_b(level, x + 1, y, current_terrain, "0x4bba59_west_east_cardinal");
		const std::array<std::array<int32_t, 2>, 4> diagonals = { { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } };
		for (const auto &delta : diagonals) {
			const int32_t nx = x + delta[0];
			const int32_t ny = y + delta[1];
			const int32_t neighbor = terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, nx, ny, current_terrain);
			if (!h3maped_toolkit_byte5_allows_same_class_gate(neighbor)) {
				continue;
			}
			append_set_b(level, nx, ny, current_terrain, "0x4bba59_diagonal_byte5_zero_neighbor");
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const int64_t key = h3maped_grid_key(level, x, y);
		if (set_a.insert(key).second) {
			set_a_insert_count += 1;
		}
		if (drain_samples.size() < 16) {
			Dictionary sample;
			sample["x"] = x;
			sample["y"] = y;
			sample["level"] = level;
			sample["source_branch"] = source_branch;
			sample["terrain_id"] = terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, x, y, -1);
			drain_samples.append(sample);
		}
	};
	auto seed_4bb74b_neighbor_branch = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		const bool gate = horizontal_pair_wrapper
				? h3maped_horizontal_pair_gate_4bc674(live_terrain_code_u16, width, height, level_tile_count, level, x, y, neighbor)
				: h3maped_vertical_pair_gate_4bc6e0(live_terrain_code_u16, width, height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			seed_4bba59(level, x, y, current_terrain);
			append_set_b(level, x, y, current_terrain, source_branch);
		}
	};
	auto process_4bb74b_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0) {
			return;
		}
		set_terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, x, y, active_terrain);
		live_queue_attempt_count += 1;
		write_live_visual_cell(level, x, y, active_terrain, "0x4bb74b_queue_live_visual_feedback");
		if (!h3maped_toolkit_byte5_allows_same_class_gate(active_terrain)) {
			seed_4bb74b_neighbor_branch(level, x, y - 1, active_terrain, true, "0x4bb7b7_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x, y + 1, active_terrain, true, "0x4bb80b_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x - 1, y, active_terrain, false, "0x4bb863_neighbor_0x4bba36_false");
			seed_4bb74b_neighbor_branch(level, x + 1, y, active_terrain, false, "0x4bb8b7_neighbor_0x4bba36_false");
		} else if (h3maped_candidate_gate_4bc988_grid(live_terrain_code_u16, width, height, level_tile_count, level, x, y)) {
			append_set_a(level, x, y, "0x4bb9ed_current_candidate_to_set_a");
		} else {
			seed_4bba59(level, x, y, active_terrain);
		}
	};
	auto update_max_queue_counts = [&]() {
		max_set_a_count = std::max(max_set_a_count, int32_t(set_a.size()));
		max_set_b_count = std::max(max_set_b_count, int32_t(set_b.size()));
	};
	int32_t set_a_drain_count = 0;
	int32_t set_b_drain_count = 0;
	int32_t set_b_candidate_true_count = 0;
	int32_t retouched_cell_write_count = 0;
	int32_t drain_guard_count = 0;
	const int32_t drain_guard_limit = 32768;
	auto drain_queue_for_active_terrain = [&](int32_t active_terrain) {
		update_max_queue_counts();
		while ((!set_a.empty() || !set_b.empty()) && drain_guard_count < drain_guard_limit) {
			drain_guard_count += 1;
			while (!set_a.empty() && drain_guard_count < drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_a.begin();
				set_a.erase(set_a.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				h3maped_decode_grid_key(key, level, x, y);
				set_a_drain_count += 1;
				std::vector<int64_t> changed_keys;
				retouched_cell_write_count += h3maped_frontier_retouch_4bbd01(live_terrain_code_u16, width, height, level_tile_count, level, x, y, &drain_samples, 24, &changed_keys);
				for (int64_t changed_key : changed_keys) {
					int32_t changed_level = 0;
					int32_t changed_x = 0;
					int32_t changed_y = 0;
					h3maped_decode_grid_key(changed_key, changed_level, changed_x, changed_y);
					process_4bb74b_topology(changed_level, changed_x, changed_y, active_terrain);
				}
				update_max_queue_counts();
			}
			while (set_a.empty() && !set_b.empty() && drain_guard_count < drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_b.begin();
				set_b.erase(set_b.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				h3maped_decode_grid_key(key, level, x, y);
				set_b_drain_count += 1;
				if (h3maped_candidate_gate_4bc988_grid(live_terrain_code_u16, width, height, level_tile_count, level, x, y)) {
					set_b_candidate_true_count += 1;
					process_4bb74b_topology(level, x, y, active_terrain);
				}
				update_max_queue_counts();
			}
		}
		set_a.clear();
		set_b.clear();
	};

	for (int64_t zone_index = 0; zone_index < selected_terrain_codes.size(); ++zone_index) {
		const int32_t terrain = int32_t(selected_terrain_codes[zone_index]);
		if (terrain == 8) {
			continue;
		}
		for (int32_t level = 0; level < level_count; ++level) {
			for (int32_t y = 0; y < height; ++y) {
				for (int32_t x = 0; x < width; ++x) {
					const int32_t index = level * level_tile_count + y * width + x;
					if (index < 0 || index >= int32_t(zone_words.size())) {
						continue;
					}
					const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != int32_t(zone_index)) {
						continue;
					}
					changed_cell_update_count += 1;
					if (set_terrain_at_grid_index(live_terrain_code_u16, width, height, level_tile_count, level, x, y, terrain)) {
						live_repaint_attempt_count += 1;
						write_live_visual_cell(level, x, y, terrain, "0x4bb74b_repaint_live_visual_feedback");
						if (h3maped_candidate_gate_4bc988_grid(live_terrain_code_u16, width, height, level_tile_count, level, x, y)) {
							append_set_a(level, x, y, "0x4bb9ed_repaint_candidate_to_set_a");
						} else {
							seed_4bba59(level, x, y, terrain);
						}
						if (!h3maped_toolkit_byte5_allows_same_class_gate(terrain)) {
							seed_4bb74b_neighbor_branch(level, x, y - 1, terrain, true, "0x4bb7b7_repaint_neighbor_0x4bba13_false");
							seed_4bb74b_neighbor_branch(level, x, y + 1, terrain, true, "0x4bb80b_repaint_neighbor_0x4bba13_false");
							seed_4bb74b_neighbor_branch(level, x - 1, y, terrain, false, "0x4bb863_repaint_neighbor_0x4bba36_false");
							seed_4bb74b_neighbor_branch(level, x + 1, y, terrain, false, "0x4bb8b7_repaint_neighbor_0x4bba36_false");
						}
					}
					drain_queue_for_active_terrain(terrain);
				}
			}
		}
	}

	int32_t live_dirty_cell_count = 0;
	int32_t live_roundtrip_mismatch_count = 0;
	int32_t live_terrain_mismatch_count = 0;
	for (int32_t index = 0; index < live_scratch_word_u16.size(); ++index) {
		const uint32_t scratch_word = uint32_t(int32_t(live_scratch_word_u16[index]));
		if ((scratch_word & 0x01U) != 0U) {
			live_dirty_cell_count += 1;
		}
		const uint32_t roundtrip_0x24 = (uint32_t(h3maped_scratch_terrain_id(scratch_word)) & 0x3fU)
				| ((uint32_t(h3maped_scratch_art_id(scratch_word)) & 0xffU) << 6U);
		const uint32_t roundtrip_0x28 = ((scratch_word >> 12U) & 0x01U) << 15U
				| (((scratch_word >> 13U) & 0x01U) << 16U);
		const uint32_t live_word_0x24 = uint32_t(int32_t(live_cell_word_0x24_u32[index]));
		const uint32_t live_word_0x28 = uint32_t(int32_t(live_cell_word_0x28_u32[index]));
		if (roundtrip_0x24 != live_word_0x24 || roundtrip_0x28 != live_word_0x28) {
			live_roundtrip_mismatch_count += 1;
		}
		if (index >= final_terrain_code_u16.size() || int32_t(live_word_0x24 & 0x3fU) != int32_t(final_terrain_code_u16[index])) {
			live_terrain_mismatch_count += 1;
		}
	}

	report["tile_count"] = live_scratch_word_u16.size();
	report["live_feedback_materialized"] = true;
	report["uses_live_scratch_neighbor_mask"] = true;
	report["live_visual_attempt_count"] = live_visual_attempt_count;
	report["live_visual_write_count"] = live_visual_write_count;
	report["live_visual_missing_bucket_count"] = live_visual_missing_bucket_count;
	report["live_initial_water_attempt_count"] = live_initial_water_attempt_count;
	report["live_repaint_attempt_count"] = live_repaint_attempt_count;
	report["live_queue_attempt_count"] = live_queue_attempt_count;
	report["live_dirty_cell_count"] = live_dirty_cell_count;
	report["live_roundtrip_mismatch_count"] = live_roundtrip_mismatch_count;
	report["live_terrain_mismatch_count"] = live_terrain_mismatch_count;
	report["live_full_native_cell_count"] = live_full_native_cell_count;
	report["live_terrain_art_nonzero_cell_count"] = live_terrain_art_nonzero_cell_count;
	report["live_terrain_flag_cell_count"] = live_terrain_flag_cell_count;
	report["neighbor_mask_histogram"] = neighbor_mask_histogram;
	report["selector_kind_histogram"] = selector_kind_histogram;
	report["post_queue_terrain_code_u16"] = live_terrain_code_u16;
	report["changed_cell_update_count"] = changed_cell_update_count;
	report["initial_set_a_candidate_count"] = max_set_a_count;
	report["initial_set_b_candidate_count"] = max_set_b_count;
	report["total_set_a_insert_count"] = set_a_insert_count;
	report["total_set_b_insert_count"] = set_b_insert_count;
	report["set_a_drain_count"] = set_a_drain_count;
	report["set_b_drain_count"] = set_b_drain_count;
	report["set_b_candidate_true_count"] = set_b_candidate_true_count;
	report["retouched_cell_write_count"] = retouched_cell_write_count;
	report["drain_guard_limit"] = drain_guard_limit;
	report["drain_guard_exhausted"] = drain_guard_count >= drain_guard_limit;
	report["seed_samples"] = seed_samples;
	report["drain_samples"] = drain_samples;
	report["scratch_word_u16"] = live_scratch_word_u16;
	report["generated_cell_word_0x24_u32"] = live_cell_word_0x24_u32;
	report["generated_cell_word_0x28_u32"] = live_cell_word_0x28_u32;
	report["sample_records"] = sample_records;
	report["rng_state_after_live_visual_selection_uint32"] = int64_t(live_visual_rng.state);
	report["blocked_next"] = "adopt live generated-cell words through 0x49b2b6 only after road/object phases are executable-derived";
	return report;
}

Dictionary terrainplacement_visual_tables_4bcff5_report() {
	Dictionary report;
	report["status"] = "0x4bcff5_terrainplacement_visual_tables_toolkit_ported_inspection_only";
	report["source"] = "h3maped TerrainPlacement visual table and toolkit boundary decoded from /root/Downloads/h3maped.exe; no hash art approximation or public package adoption";
	report["terrainplacement_factory_address"] = "0x4bcff5";
	report["terrainplacement_constructor_address"] = "0x4bb5ce";
	report["terrainplacement_wrapper_address"] = "0x4bd099";
	report["changed_cell_update_address"] = "0x4bb74b";
	report["queue_drain_address"] = "0x4bc5f0";
	report["visual_selector_address"] = "0x4bcfc3";
	report["neighbor_mask_address"] = "0x4bce6d";
	report["toolkit_table_address"] = "0x5436b8";
	report["complex_toolkit_vtable_address"] = "0x543780";
	report["simple_toolkit_vtable_address"] = "0x54379c";
	report["complex_visual_resolve_vfunc_plus_0x10"] = "0x4ba938";
	report["complex_visual_writeback_vfunc_plus_0x14"] = "0x4ba989";
	report["simple_visual_resolve_vfunc_plus_0x10"] = "0x4baa94";
	report["simple_visual_writeback_vfunc_plus_0x14"] = "0x4baabf";
	report["terrain_art_hash_fallback_allowed"] = false;
	report["materializes_visual_record"] = false;
	report["materializes_full_terrain_art_grid"] = false;
	report["materializes_package_tiles"] = false;
	report["project_grid_public_runtime_adoption"] = false;
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
	report["toolkit_object_addresses"] = terrain_toolkit_objects;
	Array constructor_records;
	const auto append_toolkit_record = [&constructor_records](const char *object_address, const char *constructor_address, int32_t terrain_id, int32_t arg_flag_a, int32_t arg_flag_b, int32_t range_probability, int32_t row_count, const char *table_address) {
		Dictionary record;
		record["object_address"] = object_address;
		record["constructor_address"] = constructor_address;
		record["terrain_id"] = terrain_id;
		record["arg_flag_a"] = arg_flag_a;
		record["arg_flag_b"] = arg_flag_b;
		record["range_probability"] = range_probability;
		record["row_count"] = row_count;
		record["table_address"] = table_address;
		constructor_records.append(record);
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
	report["toolkit_constructor_records"] = constructor_records;
	report["static_table_contracts"] = terrain_visual_static_table_contracts_report();
	report["visual_row_selection_contract"] = terrain_visual_row_selection_contract_report();
	report["scratch_write_contract"] = terrain_scratch_write_contract_report();
	report["final_normalization_contract"] = terrain_final_normalization_contract_report();
	report["terrain_classifier_contract"] = terrain_classifier_contract_report();
	report["blocked_next"] = "port live 0x4bb74b/0x4bc5f0 TerrainPlacement scratch feedback and copy selected rows into generated-cell art/flag words before any public package output";
	return report;
}

bool template_accepts(const TemplateEvidence &candidate, int32_t score, int32_t human_count, int32_t player_count) {
	return score >= candidate.min_size_score && score <= candidate.max_size_score
			&& human_count >= candidate.min_humans && human_count <= candidate.max_humans
			&& player_count >= candidate.min_total_players && player_count <= candidate.max_total_players
			&& player_count >= human_count;
}

Dictionary template_record(const TemplateEvidence &candidate) {
	Dictionary record;
	record["id"] = candidate.id;
	record["source_catalog_index"] = candidate.catalog_index;
	record["min_size_score"] = candidate.min_size_score;
	record["max_size_score"] = candidate.max_size_score;
	record["min_humans"] = candidate.min_humans;
	record["max_humans"] = candidate.max_humans;
	record["min_total_players"] = candidate.min_total_players;
	record["max_total_players"] = candidate.max_total_players;
	record["zone_count"] = candidate.zone_count;
	record["connection_count"] = candidate.connection_count;
	record["adapted_template_id"] = candidate.adapted_template_id;
	record["human_capable_source_owner_mask"] = candidate.human_capable_source_owner_mask;
	record["player_capable_source_owner_mask"] = candidate.player_capable_source_owner_mask;
	return record;
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

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by);

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

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

int32_t ftol_truncate(double value) {
	return int32_t(std::trunc(value));
}

String string_at(const Array &items, int32_t index) {
	if (index < 0 || index >= items.size()) {
		return String();
	}
	return String(items[index]);
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
	if (terrain_id == "underground" || terrain_id == "cave" || terrain_id == "subterranean") {
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

Array accepted_templates(const Dictionary &normalized_config) {
	Array accepted;
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t score = size_score(normalized_config);
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (template_accepts(candidate, score, human_count, player_count)) {
			accepted.append(template_record(candidate));
		}
	}
	return accepted;
}

Dictionary restart_backlog() {
	Array backlog;
	const char *phase_ids[] = {
		"template_selection",
		"player_slot_assignment",
		"runtime_zone_records",
		"coordinate_replay",
		"zone_footprints_and_terrain",
		"towns_and_player_starts",
		"roads_rivers_and_zone_links",
		"blockers_guards_mines_rewards",
		"final_h3maped_writeout",
	};
	for (int32_t index = 0; index < 9; ++index) {
		Dictionary phase;
		phase["phase_id"] = phase_ids[index];
		if (index == 0) {
			phase["status"] = "active_boundary_only";
		} else if (index == 1) {
			phase["status"] = "active_inspection_only";
		} else if (index == 2) {
			phase["status"] = "active_inspection_only";
		} else if (index == 3) {
			phase["status"] = "active_inspection_only";
		} else if (index == 4) {
			phase["status"] = "active_inspection_only";
		} else if (index == 5) {
			phase["status"] = "active_inspection_only";
		} else if (index == 6) {
			phase["status"] = "active_inspection_only";
		} else {
			phase["status"] = "pending_strict_h3maped_port";
		}
		backlog.append(phase);
	}
	Dictionary result;
	result["phase_count"] = backlog.size();
	result["phases"] = backlog;
	return result;
}

const TemplateEvidence *template_for_catalog_index(int32_t catalog_index) {
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (candidate.catalog_index == catalog_index) {
			return &candidate;
		}
	}
	return nullptr;
}

Dictionary source_template_record_for_catalog_index(int32_t source_catalog_index) {
	Dictionary catalog = load_json_dictionary(CATALOG_SOURCE_PATH);
	Array templates = catalog.get("templates", Array());
	if (source_catalog_index < 0 || source_catalog_index >= templates.size() || Variant(templates[source_catalog_index]).get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	return Dictionary(templates[source_catalog_index]);
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
		Array allowed_towns = zone.get("allowed_towns", Array());
		Array allowed_terrains = zone.get("allowed_terrains", Array());
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
		record["faction_id"] = String();
		record["town_choice_index"] = -1;
		record["faction_source"] = allowed_towns.is_empty() ? String("0x49b3c1_no_allowed_town_choice") : String("pending_0x49b3c1_interleaved_runtime_initializer");
		record["allowed_faction_ids_for_49b3c1"] = allowed_towns;
		record["terrain_id"] = String();
		record["terrain_match_to_faction"] = bool(zone.get("terrain_match_to_town", false));
		record["allowed_terrain_ids_for_49b53d"] = allowed_terrains;
		record["terrain_source_mask_count"] = allowed_terrains.size();
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

Dictionary link_seed_setup_report(const Dictionary &source_template_record, const Dictionary &runtime_zone_setup, int32_t human_count, int32_t total_players) {
	Dictionary report;
	report["status"] = "0x4a1f3b_endpoint_link_seeds_ported_inspection_only";
	report["source"] = "h3maped 0x4a1f3b consumes source-zone link endpoints for coordinate candidate generation; Value/Wide/Border Guard payloads are preserved for later 0x4a79a3";
	report["link_endpoint_consumer_address"] = "0x4a1f3b";
	report["candidate_generator_address"] = "0x4a17f5";
	report["distance_validation_address"] = "0x4a1701";
	report["late_payload_consumer_address"] = "0x4a79a3";
	report["materializes_coordinates"] = false;
	report["materializes_connection_guards"] = false;
	report["materializes_roads"] = false;
	report["materializes_blockers"] = false;

	Dictionary runtime_index_by_source_zone_id;
	Array runtime_records = runtime_zone_setup.get("runtime_zone_records", Array());
	for (int64_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[index];
		runtime_index_by_source_zone_id[String::num_int64(int64_t(runtime.get("source_zone_id", -1)))] = runtime.get("runtime_zone_index", index);
	}

	Array link_seeds;
	Array connections = source_template_record.get("connections", Array());
	for (int64_t index = 0; index < connections.size(); ++index) {
		if (Variant(connections[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary connection = connections[index];
		if (!player_filter_accepts(connection.get("player_filter", Dictionary()), human_count, total_players)) {
			continue;
		}
		const int32_t source_zone_a = int32_t(connection.get("zone1", -1));
		const int32_t source_zone_b = int32_t(connection.get("zone2", -1));
		Dictionary seed;
		seed["link_index"] = link_seeds.size();
		seed["source_zone_a"] = source_zone_a;
		seed["source_zone_b"] = source_zone_b;
		seed["runtime_zone_a"] = runtime_index_by_source_zone_id.get(String::num_int64(source_zone_a), -1);
		seed["runtime_zone_b"] = runtime_index_by_source_zone_id.get(String::num_int64(source_zone_b), -1);
		seed["guard_value"] = connection.get("value", 0);
		seed["wide"] = bool(connection.get("wide", false));
		seed["border_guard"] = bool(connection.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		link_seeds.append(seed);
	}

	report["link_seed_count"] = link_seeds.size();
	report["link_seeds"] = link_seeds;
	return report;
}

Dictionary late_link_payload_postprocess_report(const Dictionary &normalized_config, const Array &link_seeds) {
	Dictionary report;
	report["status"] = "0x4a79a3_late_connection_payload_postprocess_inspection_only";
	report["source"] = "h3maped cleanup 0x4a8c15 calls 0x4a79a3; raw reciprocal 0x1c link records are marked through +0x0a and late helpers consume Value(+0x04), Wide(+0x08), and Border Guard(+0x09)";
	report["cleanup_phase_address"] = "0x4a8c15";
	report["raw_link_postprocessor_address"] = "0x4a79a3";
	report["reciprocal_finder_address"] = "0x49b3fb";
	report["processed_marker_offset"] = "+0x0a";
	report["helper_addresses"] = Array::make("0x4a61bc", "0x4a696b", "0x4a6cf2", "0x4a7605", "0x4a65a5", "0x4a5e03", "0x4a5e73", "0x4a5a23");
	report["payload_offsets"] = Array::make("+0x04 Value", "+0x08 Wide", "+0x09 Border Guard");
	report["materializes_connection_geometry"] = false;
	report["materializes_connection_guards"] = false;
	report["guard_records_candidate_only"] = true;
	report["wide_semantics"] = "Wide suppresses normal guard value; recovered 0x4a6cf2 reads it after endpoint/corridor geometry, so it is not used as a corridor-width input in this chain";
	report["border_guard_semantics"] = "Border Guard enables special type 9 Border Guard subtype 0..7 marker/object handling through 0x4a5e73/0x4a5a23";

	const int32_t global_mode = std::max(0, std::min(5, int32_t(normalized_config.get("global_monster_strength_mode", 3))));
	Array records;
	Array raw_values;
	Array scaled_values;
	int32_t normal_guard_candidate_count = 0;
	int32_t normal_guard_scaled_positive_count = 0;
	int32_t normal_guard_suppressed_by_wide_count = 0;
	int32_t border_guard_special_count = 0;
	int32_t zero_scaled_guard_count = 0;
	for (int64_t index = 0; index < link_seeds.size(); ++index) {
		if (Variant(link_seeds[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = link_seeds[index];
		const int32_t raw_value = int32_t(link.get("guard_value", 0));
		const bool wide = bool(link.get("wide", false));
		const bool border_guard = bool(link.get("border_guard", false));
		const int32_t scaled_value = wide ? 0 : h3maped_guard_scaled_value_4a65a5(raw_value, global_mode);
		raw_values.append(raw_value);
		scaled_values.append(scaled_value);
		if (wide) {
			normal_guard_suppressed_by_wide_count += 1;
		} else if (!border_guard) {
			normal_guard_candidate_count += 1;
			if (scaled_value > 0) {
				normal_guard_scaled_positive_count += 1;
			} else {
				zero_scaled_guard_count += 1;
			}
		}
		if (border_guard) {
			border_guard_special_count += 1;
		}

		Dictionary record;
		record["link_index"] = link.get("link_index", index);
		record["source_zone_a"] = link.get("source_zone_a", -1);
		record["source_zone_b"] = link.get("source_zone_b", -1);
		record["runtime_zone_a"] = link.get("runtime_zone_a", -1);
		record["runtime_zone_b"] = link.get("runtime_zone_b", -1);
		record["link_value_offset_0x04_raw_guard_value"] = raw_value;
		record["link_wide_offset_0x08"] = wide;
		record["link_border_guard_offset_0x09"] = border_guard;
		record["global_monster_strength_mode_generator_0x10bc"] = global_mode;
		record["scaled_guard_value_0x4a65a5"] = scaled_value;
		record["normal_guard_value_source"] = wide ? String("wide_forces_zero") : String("0x4a65a5_link_value_and_global_strength");
		record["normal_guard_candidate_status"] = scaled_value > 0 && !border_guard ? String("candidate_0x4a5e03_normal_guard_no_materialization") : String("no_normal_guard_materialization");
		record["wide_suppresses_normal_guard"] = wide;
		record["border_guard_special_mode"] = border_guard;
		record["border_guard_object_type_id"] = border_guard ? 9 : -1;
		record["border_guard_subtype_range"] = border_guard ? String("0..7") : String();
		record["processed_marker_write_status"] = "unique_link_and_reciprocal_marked_inspection_only";
		records.append(record);
	}

	report["global_monster_strength_mode"] = global_mode;
	report["unique_link_count"] = records.size();
	report["reciprocal_link_record_count"] = records.size() * 2;
	report["processed_marker_write_count"] = records.size() * 2;
	report["raw_guard_values"] = raw_values;
	report["scaled_guard_values"] = scaled_values;
	report["normal_guard_candidate_count"] = normal_guard_candidate_count;
	report["normal_guard_scaled_positive_count"] = normal_guard_scaled_positive_count;
	report["normal_guard_suppressed_by_wide_count"] = normal_guard_suppressed_by_wide_count;
	report["border_guard_special_count"] = border_guard_special_count;
	report["zero_scaled_guard_count"] = zero_scaled_guard_count;
	report["records"] = records;
	report["blocked_next"] = "port 0x4a61bc/0x4a696b/0x4a6cf2/0x4a7605 geometry endpoints and 0x4a5e03/0x4a5e73 guard object placement before runtime guard adoption";
	return report;
}

Dictionary late_connection_overlap_geometry_report(const Array &runtime_zone_records, const Array &link_seeds, const Dictionary &terrain_cell_writeout) {
	Dictionary report;
	report["status"] = "0x4a6cf2_overlap_rectangle_connection_geometry_precondition_inspection_only";
	report["source"] = "h3maped 0x4a6cf2 copies the two runtime-zone bounding rectangles, computes their overlap before reading Wide, scans generated cells inside that overlap, then later consumes Value/Wide/Border Guard";
	report["ported_addresses"] = Array::make("0x4a6d52..0x4a6ddc", "0x4a6de2..0x4a6f4a", "0x4a707b..0x4a709a");
	report["materializes_connection_geometry"] = false;
	report["materializes_connection_guards"] = false;
	report["shape_list_source_pending"] = "generator+0x6a8";
	report["candidate_validation_pending"] = "0x49aa93";
	report["wide_read_order"] = "after overlap rectangle and candidate endpoint geometry";
	report["first_pass_helper_sequence"] = Array::make("0x4a61bc", "0x4a696b", "0x4a6cf2");
	report["second_pass_helper_sequence_if_unprocessed"] = Array::make("0x4a696b", "0x4a7605");
	report["processed_marker_policy"] = "0x4a79a3 marks link+0x0a and reciprocal link+0x0a only after a late helper resolves the pair";

	PackedInt32Array zone_word_u32 = terrain_cell_writeout.get("zone_word_u32", PackedInt32Array());
	const int32_t width = int32_t(terrain_cell_writeout.get("map_width", 0));
	const int32_t height = int32_t(terrain_cell_writeout.get("map_height", 0));
	const int32_t level_count = std::max(1, int32_t(terrain_cell_writeout.get("level_count", 1)));
	const int32_t expected_cell_count = width * height * level_count;
	const bool grid_available = width > 0 && height > 0 && zone_word_u32.size() == expected_cell_count;
	report["grid_available"] = grid_available;
	report["width"] = width;
	report["height"] = height;
	report["level_count"] = level_count;
	if (!grid_available) {
		report["records"] = Array();
		report["link_count"] = 0;
		report["overlap_available_count"] = 0;
		report["blocked_reason"] = "missing 0x4a325d zone-word grid";
		return report;
	}

	struct RuntimeBounds {
		bool seen = false;
		int32_t min_x = 0;
		int32_t min_y = 0;
		int32_t max_x = 0;
		int32_t max_y = 0;
		int32_t level = 0;
		int32_t cell_count = 0;
	};
	std::vector<RuntimeBounds> bounds(size_t(runtime_zone_records.size()));
	for (int32_t level = 0; level < level_count; ++level) {
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const int32_t cell_index = level * width * height + y * width + x;
				const uint32_t masked = uint32_t(int32_t(zone_word_u32[cell_index])) & H3MAPED_UNASSIGNED_ZONE_WORD;
				if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
					continue;
				}
				const int32_t runtime_index = int32_t((masked >> 16U) & 0xffU);
				if (runtime_index < 0 || runtime_index >= int32_t(bounds.size())) {
					continue;
				}
				RuntimeBounds &runtime_bounds = bounds[size_t(runtime_index)];
				if (!runtime_bounds.seen) {
					runtime_bounds.seen = true;
					runtime_bounds.min_x = x;
					runtime_bounds.max_x = x;
					runtime_bounds.min_y = y;
					runtime_bounds.max_y = y;
					runtime_bounds.level = level;
				} else {
					runtime_bounds.min_x = std::min(runtime_bounds.min_x, x);
					runtime_bounds.max_x = std::max(runtime_bounds.max_x, x);
					runtime_bounds.min_y = std::min(runtime_bounds.min_y, y);
					runtime_bounds.max_y = std::max(runtime_bounds.max_y, y);
				}
				runtime_bounds.cell_count += 1;
			}
		}
	}

	Array bounds_report;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		Dictionary runtime_record;
		if (Variant(runtime_zone_records[index]).get_type() == Variant::DICTIONARY) {
			runtime_record = runtime_zone_records[index];
		}
		const RuntimeBounds &runtime_bounds = bounds[size_t(index)];
		Dictionary item;
		item["runtime_zone_index"] = int32_t(index);
		item["source_zone_id"] = runtime_record.get("source_zone_id", -1);
		item["has_bounds"] = runtime_bounds.seen;
		item["min_x"] = runtime_bounds.seen ? runtime_bounds.min_x : -1;
		item["min_y"] = runtime_bounds.seen ? runtime_bounds.min_y : -1;
		item["max_x"] = runtime_bounds.seen ? runtime_bounds.max_x : -1;
		item["max_y"] = runtime_bounds.seen ? runtime_bounds.max_y : -1;
		item["level"] = runtime_bounds.seen ? runtime_bounds.level : -1;
		item["cell_count"] = runtime_bounds.cell_count;
		bounds_report.append(item);
	}

	Array records;
	Array overlap_available_link_indices;
	Array fallback_required_link_indices;
	int32_t overlap_available_count = 0;
	int32_t overlap_cell_total = 0;
	int32_t overlap_zone_a_cell_total = 0;
	int32_t overlap_zone_b_cell_total = 0;
	for (int64_t index = 0; index < link_seeds.size(); ++index) {
		if (Variant(link_seeds[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = link_seeds[index];
		const int32_t runtime_a = int32_t(link.get("runtime_zone_a", -1));
		const int32_t runtime_b = int32_t(link.get("runtime_zone_b", -1));
		Dictionary record;
		record["link_index"] = link.get("link_index", index);
		record["runtime_zone_a"] = runtime_a;
		record["runtime_zone_b"] = runtime_b;
		record["source_zone_a"] = link.get("source_zone_a", -1);
		record["source_zone_b"] = link.get("source_zone_b", -1);
		record["wide"] = link.get("wide", false);
		record["border_guard"] = link.get("border_guard", false);
		record["guard_value"] = link.get("guard_value", 0);
		record["first_pass_helper_sequence"] = report.get("first_pass_helper_sequence", Array());
		record["second_pass_helper_sequence_if_unprocessed"] = report.get("second_pass_helper_sequence_if_unprocessed", Array());
		if (runtime_a < 0 || runtime_b < 0 || runtime_a >= int32_t(bounds.size()) || runtime_b >= int32_t(bounds.size())
				|| !bounds[size_t(runtime_a)].seen || !bounds[size_t(runtime_b)].seen) {
			record["status"] = "0x4a6cf2_missing_runtime_zone_bounds";
			record["overlap_exists"] = false;
			record["helper_resolution_precondition"] = "missing_bounds_requires_later_fallback_or_failure";
			fallback_required_link_indices.append(link.get("link_index", index));
			records.append(record);
			continue;
		}
		const RuntimeBounds &a = bounds[size_t(runtime_a)];
		const RuntimeBounds &b = bounds[size_t(runtime_b)];
		const int32_t min_x = std::max(a.min_x, b.min_x);
		const int32_t max_x = std::min(a.max_x, b.max_x);
		const int32_t min_y = std::max(a.min_y, b.min_y);
		const int32_t max_y = std::min(a.max_y, b.max_y);
		const bool overlap_exists = min_x <= max_x && min_y <= max_y && a.level == b.level;
		record["runtime_zone_a_bounds"] = bounds_report[runtime_a];
		record["runtime_zone_b_bounds"] = bounds_report[runtime_b];
		record["overlap_exists"] = overlap_exists;
		record["overlap_min_x"] = overlap_exists ? min_x : -1;
		record["overlap_min_y"] = overlap_exists ? min_y : -1;
		record["overlap_max_x"] = overlap_exists ? max_x : -1;
		record["overlap_max_y"] = overlap_exists ? max_y : -1;
		record["overlap_level"] = overlap_exists ? a.level : -1;

		int32_t overlap_cell_count = 0;
		int32_t zone_a_cell_count = 0;
		int32_t zone_b_cell_count = 0;
		int32_t other_reserved_cell_count = 0;
		Array preview;
		if (overlap_exists) {
			for (int32_t y = min_y; y <= max_y; ++y) {
				for (int32_t x = min_x; x <= max_x; ++x) {
					const int32_t cell_index = a.level * width * height + y * width + x;
					const uint32_t masked = uint32_t(int32_t(zone_word_u32[cell_index])) & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
						continue;
					}
					const int32_t runtime_index = int32_t((masked >> 16U) & 0xffU);
					overlap_cell_count += 1;
					if (runtime_index == runtime_a) {
						zone_a_cell_count += 1;
					} else if (runtime_index == runtime_b) {
						zone_b_cell_count += 1;
					} else {
						other_reserved_cell_count += 1;
					}
					if (preview.size() < 8) {
						Dictionary cell;
						cell["x"] = x;
						cell["y"] = y;
						cell["level"] = a.level;
						cell["runtime_zone_index"] = runtime_index;
						preview.append(cell);
					}
				}
			}
			overlap_available_count += 1;
			overlap_available_link_indices.append(link.get("link_index", index));
		} else {
			fallback_required_link_indices.append(link.get("link_index", index));
		}

		record["overlap_cell_count"] = overlap_cell_count;
		record["overlap_zone_a_cell_count"] = zone_a_cell_count;
		record["overlap_zone_b_cell_count"] = zone_b_cell_count;
		record["overlap_other_reserved_cell_count"] = other_reserved_cell_count;
		record["overlap_reserved_cell_preview"] = preview;
		record["status"] = overlap_exists
				? String("0x4a6cf2_overlap_rect_available_pending_shape_list_0x6a8_and_0x49aa93_validation")
				: String("0x4a6cf2_no_overlap_rect_later_helpers_or_fallback_required");
		record["helper_resolution_precondition"] = overlap_exists
				? String("first_pass_0x4a6cf2_geometry_precondition_available")
				: String("first_pass_0x4a6cf2_overlap_missing_second_pass_0x4a7605_or_other_helper_required");
		overlap_cell_total += overlap_cell_count;
		overlap_zone_a_cell_total += zone_a_cell_count;
		overlap_zone_b_cell_total += zone_b_cell_count;
		records.append(record);
	}

	report["runtime_zone_bounds"] = bounds_report;
	report["link_count"] = records.size();
	report["overlap_available_count"] = overlap_available_count;
	report["overlap_available_link_indices"] = overlap_available_link_indices;
	report["fallback_required_link_indices"] = fallback_required_link_indices;
	report["fallback_required_count"] = fallback_required_link_indices.size();
	report["overlap_cell_total"] = overlap_cell_total;
	report["overlap_zone_a_cell_total"] = overlap_zone_a_cell_total;
	report["overlap_zone_b_cell_total"] = overlap_zone_b_cell_total;
	report["records"] = records;
	report["blocked_next"] = "port generator+0x6a8 candidate shape list, low-word score summing, 0x49aa93 two-sided validation, and endpoint object/guard stamping before runtime connection adoption";
	return report;
}

Dictionary coordinate_replay_report(const Dictionary &normalized_config, const Dictionary &runtime_zone_setup, const Dictionary &link_seed_setup, uint32_t rng_state_after_template_selection) {
	Dictionary report;
	report["status"] = "0x4a17f5_0x4a1701_coordinate_candidate_replay_ported_inspection_only";
	report["source"] = "h3maped 0x4a218c interleaves 0x49b3c1 town choice, 0x4a1f3b endpoint walking, 0x4a17f5 32-angle candidates, 0x4a1701 spacing validation, 0x4a1ad8 single-level pruning, and 0x4a19ed bbox rescale";
	report["angle_table_x_address"] = "0x58dc28";
	report["angle_table_y_address"] = "0x58dd28";
	report["distance_validation_address"] = "0x4a1701";
	report["candidate_prune_address"] = "0x4a1ad8";
	report["bbox_rescale_address"] = "0x4a19ed";
	report["rng_state_before_0x4a218c_replay_uint32"] = int64_t(rng_state_after_template_selection);
	report["town_choice_rng_status"] = "0x49b3c1_interleaved_allowed_town_choice_ported_inspection_only";
	report["materializes_map_cells"] = false;
	report["materializes_zone_footprints"] = false;
	if (int32_t(normalized_config.get("level_count", 1)) != 1) {
		report["status"] = "blocked_until_two_level_coordinate_port";
		report["blocked_reason"] = "clean reset is scoped to one-level small land maps before underground coordinate branches";
		return report;
	}

	Array runtime_records = runtime_zone_setup.get("runtime_zone_records", Array());
	std::vector<RuntimeZoneSeed> zones;
	zones.reserve(size_t(runtime_records.size()));
	for (int64_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
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
	Array link_seeds = link_seed_setup.get("link_seeds", Array());
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

	H3MapedRng rng{ rng_state_after_template_selection };
	Array placement_steps;
	Array rng_events;
	int32_t coordinate_rng_calls = 0;
	int32_t town_choice_rng_calls = 0;
	bool complete = true;

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= runtime_records.size() || Variant(runtime_records[zone_index]).get_type() != Variant::DICTIONARY) {
			return;
		}
		Dictionary runtime = Dictionary(runtime_records[zone_index]);
		String faction_id = String(runtime.get("faction_id", ""));
		if (faction_id.is_empty()) {
			Array allowed_factions = runtime.get("allowed_faction_ids_for_49b3c1", Array());
			if (!allowed_factions.is_empty()) {
				const int32_t rng_value = rng.next();
				const int32_t town_choice_index = rng_value % int32_t(allowed_factions.size());
				faction_id = string_at(allowed_factions, town_choice_index);
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
		for (int32_t visible_index : visible_runtime_indices) {
			visible_report.append(visible_index);
		}
		step["visible_runtime_zone_indices"] = visible_report;

		if (visible_runtime_indices.empty()) {
			candidates.push_back(CoordCandidate{ 0, 0, 0 });
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
	report["coordinate_rng_calls_during_0x4a1f3b"] = coordinate_rng_calls;
	report["town_choice_rng_calls_during_0x4a218c"] = town_choice_rng_calls;
	report["total_interleaved_rng_calls_during_0x4a218c"] = coordinate_rng_calls + town_choice_rng_calls;
	report["rng_event_count"] = rng_events.size();
	report["rng_events"] = rng_events;
	report["runtime_zone_records_after_0x49b3c1"] = runtime_records;
	report["rng_state_after_0x4a218c_replay_uint32"] = int64_t(rng.state);
	report["bounding_box_rescale"] = bbox;
	report["scaled_zone_coordinates"] = scaled_zone_coordinates;
	report["next_materialization_status"] = "pending_0x4ccb64_source_node_split_insertion";
	return report;
}

Dictionary runtime_terrain_selection_49b53d_report(const Dictionary &coordinate_replay) {
	Dictionary report;
	report["status"] = "0x49b53d_runtime_terrain_selection_ported_inspection_only";
	report["source"] = "h3maped 0x49b53d maps match-to-town runtime choices through table 0x540908, otherwise uses 0x4e7276 over source zone +0x85..+0x8c allowed terrain flags";
	report["function_address"] = "0x49b53d";
	report["town_to_terrain_table_address"] = "0x540908";
	report["allowed_terrain_flags_source"] = "source_zone+0x85..0x8c";
	report["rng_state_before_0x49b53d_uint32"] = coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0);
	report["materializes_terrain_cells"] = false;
	report["materializes_terrain_art"] = false;
	report["materializes_map_cells"] = false;
	report["public_package_output_allowed"] = false;

	const std::array<int32_t, 9> h3_town_to_terrain = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	Array town_table;
	for (int32_t item : h3_town_to_terrain) {
		town_table.append(item);
	}
	report["town_choice_to_terrain_table"] = town_table;

	H3MapedRng rng;
	rng.state = uint32_t(int64_t(coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)));
	Array runtime_records = coordinate_replay.get("runtime_zone_records_after_0x49b3c1", Array());
	Array selections;
	Array selected_ids;
	Array selected_names;
	int32_t rng_call_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t blank_allowed_mask_count = 0;
	int32_t forced_subterranean_count = 0;
	for (int64_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[index];
		Dictionary selection;
		const int32_t runtime_zone_index = int32_t(runtime.get("runtime_zone_index", index));
		const int32_t level = int32_t(runtime.get("level", 0));
		const bool match_to_faction = bool(runtime.get("terrain_match_to_faction", false));
		const int32_t town_choice_index = int32_t(runtime.get("town_choice_index", -1));
		selection["runtime_zone_index"] = runtime_zone_index;
		selection["level"] = level;
		selection["terrain_match_to_faction"] = match_to_faction;
		selection["town_choice_index"] = town_choice_index;
		selection["faction_id"] = runtime.get("faction_id", "");
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
	report["next_materialization_status"] = "pending_0x4a3f27_terrain_cell_writeout";
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
	report["initial_edge_count"] = edges.size();
	report["initial_edges"] = edges;
	report["blocked_next"] = "port 0x4ccb64 split insertion and 0x4ccdfc source-node finalization before feeding real cycles into 0x4a2777";
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
	report["feeds_real_0x4a2777_boundary"] = false;

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
	report["feeds_real_0x4a2777_boundary"] = false;

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
	report["blocked_next"] = "port 0x4a2413 randomized line writer and assemble 0x4a2777 source-node traversal from queued helper inputs";
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
	report["feeds_real_0x4a2777_boundary"] = false;

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

Dictionary real_source_node_cycle_traversal_4a2777_report(const Dictionary &normalized_config, const Dictionary &coordinate_replay, const Dictionary &split_model, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a2777_real_source_node_cycle_traversal_ported_boundary_buffer_private";
	report["source"] = "h3maped 0x4a2777 over real 0x4cca55 source-node cycles: clips finalized +0x1c/+0x20 coordinates through 0x4a2b33, appends runtime_zone+0x3f4 vertices, and paints private boundary cells through 0x4a261a/0x4a2413 before span fill";
	report["function_address"] = "0x4a2777";
	report["caller_address"] = "0x4a3e58..0x4a3e8c";
	report["source_node_cycle_source"] = "polygon_split_model_4ccb64.source_node_walks from 0x4cca55 after 0x4ccdfc finalization";
	report["clip_helper_address"] = "0x4a2b33";
	report["deterministic_line_writer_address"] = "0x4a261a";
	report["flagged_line_writer_address"] = "0x4a2413";
	report["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	report["materializes_boundaries"] = true;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["project_materialized_cell_count"] = 0;
	report["public_package_output_allowed"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;
	report["h3maped_water_mode_code"] = water_code;
	const Dictionary replay_bbox = coordinate_replay.get("bounding_box_rescale", Dictionary());
	report["rng_state_before_0x4a2777_uint32"] = coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0);

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_replay.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled.size(); ++index) {
		if (Variant(scaled[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
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
	H3MapedRng rng;
	rng.state = uint32_t(int64_t(coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)));

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
		if (Variant(walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary walk = Dictionary(walks[walk_index]);
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
	report["blocked_next"] = "feed private 0x4a2777 boundary cells into 0x4a325d span fill before terrain/object materialization";
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return report;
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

Dictionary seed_relocation_4a325d_report(const Dictionary &source_node_walk, const SpanRecord &seed, int32_t width, int32_t height, int32_t level_count) {
	Dictionary report;
	report["status"] = "0x4a325d_seed_in_bounds_relocation_not_used";
	report["source"] = "h3maped 0x4a32b2..0x4a338e relocation branch: out-of-bounds seeds scan the source-node cycle for the interior node with maximum border clearance, then clip the original seed toward that node through 0x4a2b33";
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

Dictionary real_boundary_span_fill_4a325d_report(const Dictionary &normalized_config, const Dictionary &coordinate_replay, const Dictionary &split_model, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	report["status"] = "0x4a325d_real_0x4a2777_boundary_span_fill_ported_private";
	report["source"] = "h3maped 0x4a325d span fill executed against the private 0x4a2777 boundary buffer produced from finalized 0x4cca55 source-node cycles";
	report["function_address"] = "0x4a325d";
	report["boundary_source_address"] = "0x4a2777";
	report["seed_source"] = "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale";
	report["uses_real_0x4a2777_boundary"] = true;
	report["materializes_span_fill"] = true;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["materializes_package_tiles"] = false;
	report["project_grid_public_runtime_adoption"] = false;
	report["public_package_output_allowed"] = false;

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
	Dictionary boundary = real_source_node_cycle_traversal_4a2777_report(normalized_config, coordinate_replay, split_model, &zone_words, &cell_flags);
	report["boundary_status"] = boundary.get("status", "");
	report["boundary_unique_cell_count"] = boundary.get("unique_cell_count", 0);
	report["boundary_trace_write_count"] = boundary.get("trace_write_count", 0);
	report["boundary_rng_state_after_0x4a2777_uint32"] = boundary.get("rng_state_after_0x4a2777_uint32", 0);

	Dictionary walk_by_runtime;
	Array source_node_walks = split_model.get("source_node_walks", Array());
	for (int64_t walk_index = 0; walk_index < source_node_walks.size(); ++walk_index) {
		if (Variant(source_node_walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary walk = source_node_walks[walk_index];
		walk_by_runtime[String::num_int64(int64_t(walk.get("runtime_zone_index", -1)))] = walk;
	}

	Array zone_fill_reports;
	Array scaled = coordinate_replay.get("scaled_zone_coordinates", Array());
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
		if (Variant(scaled[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
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
		Dictionary relocation = seed_relocation_4a325d_report(matching_walk, seed, width, height, level_count);
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

	report["runtime_zone_fill_attempt_count"] = zone_fill_reports.size();
	report["filled_zone_count"] = filled_zone_count;
	report["seed_blocked_count"] = seed_blocked_count;
	report["missing_seed_count"] = missing_seed_count;
	report["seed_relocation_count"] = seed_relocation_count;
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
	report["blocked_next"] = "port 0x4a3710 ordering/finalizer and 0x4a3f27 terrain/cell writeout before any project package output";
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return report;
}

Dictionary terrain_cell_writeout_4a3f27_report(const Dictionary &normalized_config, const Dictionary &coordinate_replay, const Dictionary &split_model, const Dictionary &terrain_selection) {
	Dictionary report;
	report["status"] = "0x4a3f27_terrain_cell_writeout_from_real_0x4a325d_zone_words_ported_inspection_only";
	report["source"] = "h3maped 0x4a3f27 repaints the generated cell grid from the 0x4a325d zone-word buffer: full-map water first, then per-runtime-zone single-cell terrain repaint; art/index/flip remain pending TerrainPlacement";
	report["function_address"] = "0x4a3f27";
	report["full_map_water_repaint_address"] = "0x4a4025";
	report["per_zone_repaint_loop_address"] = "0x4a4082";
	report["per_cell_repaint_call_address"] = "0x4a415a";
	report["owner_byte_gate_address"] = "0x4a4142";
	report["reserved_flag_gate_address"] = "0x4a4150";
	report["span_fill_source_address"] = "0x4a325d";
	report["tile_serializer_address"] = "0x49b2b6";
	report["materializes_private_generated_cell_words"] = true;
	report["materializes_terrain_art"] = false;
	report["materializes_roads"] = false;
	report["materializes_objects"] = false;
	report["materializes_package_tiles"] = false;
	report["project_grid_public_runtime_adoption"] = false;
	report["public_package_output_allowed"] = false;

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	report["map_width"] = width;
	report["map_height"] = height;
	report["level_count"] = level_count;

	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary span_fill = real_boundary_span_fill_4a325d_report(normalized_config, coordinate_replay, split_model, &zone_words, &cell_flags);
	report["span_fill_status"] = span_fill.get("status", "");
	report["span_fill_total_boundary_or_filled_cell_count"] = span_fill.get("total_boundary_or_filled_cell_count", 0);
	report["span_fill_remaining_unassigned_cell_count"] = span_fill.get("remaining_unassigned_cell_count", 0);
	report["span_fill_reserved_flag_cell_count"] = span_fill.get("reserved_flag_cell_count", 0);

	Array selected_terrain_names = terrain_selection.get("selected_project_terrain_ids", Array());
	Array selected_terrain_codes = terrain_selection.get("selected_h3maped_terrain_ids", Array());
	Dictionary terrain_name_counts;
	Dictionary h3_terrain_code_counts;
	Dictionary cells_by_zone_word;
	Dictionary repaint_cells_by_terrain_code;
	Array per_zone_repaint_records;
	PackedInt32Array terrain_code_u16;
	PackedInt32Array generated_cell_word_0x24_u32;
	PackedInt32Array generated_cell_word_0x28_u32;
	PackedInt32Array tile_byte_0_terrain_id_u8;
	PackedInt32Array tile_byte_1_terrain_art_u8;
	PackedInt32Array tile_byte_2_river_type_u8;
	PackedInt32Array tile_byte_3_river_art_u8;
	PackedInt32Array tile_byte_4_road_type_u8;
	PackedInt32Array tile_byte_5_road_art_u8;
	PackedInt32Array tile_byte_6_flags_u8;
	PackedInt32Array zone_word_u32;
	PackedInt32Array cell_flag_u8;
	const int32_t cell_count = int32_t(zone_words.size());
	terrain_code_u16.resize(cell_count);
	generated_cell_word_0x24_u32.resize(cell_count);
	generated_cell_word_0x28_u32.resize(cell_count);
	tile_byte_0_terrain_id_u8.resize(cell_count);
	tile_byte_1_terrain_art_u8.resize(cell_count);
	tile_byte_2_river_type_u8.resize(cell_count);
	tile_byte_3_river_art_u8.resize(cell_count);
	tile_byte_4_road_type_u8.resize(cell_count);
	tile_byte_5_road_art_u8.resize(cell_count);
	tile_byte_6_flags_u8.resize(cell_count);
	zone_word_u32.resize(cell_count);
	cell_flag_u8.resize(cell_count);

	int32_t reserved_cell_count = 0;
	int32_t unassigned_cell_count = 0;
	int32_t non_water_terrain_cell_count = 0;
	for (int32_t index = 0; index < cell_count; ++index) {
		zone_word_u32.set(index, int32_t(zone_words[size_t(index)]));
		cell_flag_u8.set(index, int32_t(cell_flags[size_t(index)]));
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		int32_t h3_terrain_code = 8;
		String terrain_name = "water";
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			unassigned_cell_count += 1;
		} else {
			const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
			const String zone_key = String::num_int64(zone_word_id);
			cells_by_zone_word[zone_key] = int32_t(cells_by_zone_word.get(zone_key, 0)) + 1;
			if (zone_word_id >= 0 && zone_word_id < selected_terrain_codes.size()) {
				h3_terrain_code = int32_t(selected_terrain_codes[zone_word_id]);
			}
			if (zone_word_id >= 0 && zone_word_id < selected_terrain_names.size()) {
				terrain_name = String(selected_terrain_names[zone_word_id]);
			} else {
				terrain_name = terrain_for_h3maped_id(h3_terrain_code);
			}
		}
		if (h3_terrain_code != 8) {
			non_water_terrain_cell_count += 1;
			const String terrain_code_key = String::num_int64(h3_terrain_code);
			repaint_cells_by_terrain_code[terrain_code_key] = int32_t(repaint_cells_by_terrain_code.get(terrain_code_key, 0)) + 1;
		}
		if ((cell_flags[size_t(index)] & 0x10U) != 0U) {
			reserved_cell_count += 1;
		}
		const uint32_t generated_cell_0x24 = uint32_t(h3_terrain_code) & 0x3fU;
		const uint32_t generated_cell_0x28 = 0U;
		generated_cell_word_0x24_u32.set(index, int32_t(generated_cell_0x24));
		generated_cell_word_0x28_u32.set(index, int32_t(generated_cell_0x28));
		terrain_code_u16.set(index, int32_t(generated_cell_0x24));
		tile_byte_0_terrain_id_u8.set(index, int32_t(generated_cell_0x24));
		tile_byte_1_terrain_art_u8.set(index, 0);
		tile_byte_2_river_type_u8.set(index, 0);
		tile_byte_3_river_art_u8.set(index, 0);
		tile_byte_4_road_type_u8.set(index, 0);
		tile_byte_5_road_art_u8.set(index, 0);
		tile_byte_6_flags_u8.set(index, 0);
		terrain_name_counts[terrain_name] = int32_t(terrain_name_counts.get(terrain_name, 0)) + 1;
		const String code_key = String::num_int64(h3_terrain_code);
		h3_terrain_code_counts[code_key] = int32_t(h3_terrain_code_counts.get(code_key, 0)) + 1;
	}

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
	terrain_repaint_schedule["initial_water_terrain_id"] = 8;
	terrain_repaint_schedule["initial_water_full_map_cell_count"] = cell_count;
	terrain_repaint_schedule["two_level_rock_prefill_address"] = "0x4a3f97";
	terrain_repaint_schedule["two_level_rock_prefill_executed"] = level_count > 1;
	terrain_repaint_schedule["single_cell_repaint_count"] = non_water_terrain_cell_count;
	terrain_repaint_schedule["repaint_cells_by_terrain_code"] = repaint_cells_by_terrain_code;
	terrain_repaint_schedule["per_zone_repaint_records"] = per_zone_repaint_records;
	terrain_repaint_schedule["materializes_visual_art"] = false;

	report["cell_count"] = cell_count;
	report["terrain_code_u16"] = terrain_code_u16;
	report["generated_cell_word_0x24_u32"] = generated_cell_word_0x24_u32;
	report["generated_cell_word_0x28_u32"] = generated_cell_word_0x28_u32;
	report["zone_word_u32"] = zone_word_u32;
	report["cell_flag_u8"] = cell_flag_u8;
	report["tile_byte_0_terrain_id_u8"] = tile_byte_0_terrain_id_u8;
	report["tile_byte_1_terrain_art_u8"] = tile_byte_1_terrain_art_u8;
	report["tile_byte_2_river_type_u8"] = tile_byte_2_river_type_u8;
	report["tile_byte_3_river_art_u8"] = tile_byte_3_river_art_u8;
	report["tile_byte_4_road_type_u8"] = tile_byte_4_road_type_u8;
	report["tile_byte_5_road_art_u8"] = tile_byte_5_road_art_u8;
	report["tile_byte_6_flags_u8"] = tile_byte_6_flags_u8;
	report["tile_byte_zero_terrain_cell_count"] = cell_count;
	report["tile_byte_zero_non_water_terrain_cell_count"] = non_water_terrain_cell_count;
	report["tile_byte_one_nonzero_art_cell_count"] = 0;
	report["tile_byte_six_terrain_flip_cell_count"] = 0;
	report["reserved_flag_cell_count"] = reserved_cell_count;
	report["unassigned_water_cell_count"] = unassigned_cell_count;
	report["terrain_name_counts"] = terrain_name_counts;
	report["h3_terrain_code_counts"] = h3_terrain_code_counts;
	report["cells_by_zone_word"] = cells_by_zone_word;
	report["terrain_repaint_schedule"] = terrain_repaint_schedule;
	report["final_sweep_boundary_counter_status"] = "0x4bbfcc_generated_grid_boundary_counter_applied_inspection_only";
	report["final_sweep_boundary_counter"] = generated_grid_final_sweep_boundary_counter_report(terrain_code_u16, width, height, level_count);
	Dictionary live_visual_feedback = h3maped_repaint_live_visual_feedback_boundary_report(zone_words, selected_terrain_codes, terrain_code_u16, width, height, level_count, uint32_t(int64_t(span_fill.get("boundary_rng_state_after_0x4a2777_uint32", 0))));
	report["repaint_live_visual_feedback_status"] = live_visual_feedback.get("status", "");
	report["repaint_live_visual_feedback"] = live_visual_feedback;
	report["tile_byte_writeout_status"] = "0x49b2b6_terrain_id_byte_packed_art_flip_pending";
	report["tile_byte_writeout_source"] = "0x49b2b6 serializes generated cell+0x24 bits 0..5 to terrain byte 0; terrain art byte 1 and terrain flip byte 6 bits 0..1 remain blocked until TerrainPlacement is ported";
	report["next_materialization_status"] = "pending_TerrainPlacement_0x4bcff5_0x4bd099_art_index_flip_writeout";
	report["blocked_next"] = "port TerrainPlacement art/index/flip, then towns, roads, blockers, guards, rewards, and final h3maped writeout before public package output";
	return report;
}

Dictionary town_castle_phase_schedule_report(const Dictionary &normalized_config, const Array &runtime_zone_records, const Dictionary &coordinate_replay, const Dictionary &terrain_selection, const Dictionary &terrain_cell_writeout) {
	Dictionary report;
	report["status"] = "0x4a8d2c_0x4a8db2_town_castle_phase_schedule_inspection_only";
	report["source"] = "h3maped 0x4a8d2c direct minimum town/castle pass, 0x4a8db2 weighted continuation, 0x4a93a2 direct object helper, 0x49aa93/0x49a09c footprint gates, 0x49b3c1 town type chooser, and 0x49ba89/0x540a9c town object record construction";
	report["ported_addresses"] = Array::make("0x4a8d2c", "0x4a8db2", "0x4a93a2", "0x49aa93", "0x49a09c", "0x49b3c1", "0x49ba89", "0x540a9c");
	report["materializes_town_objects"] = false;
	report["materializes_package_tiles"] = false;
	report["adopts_into_runtime_grid"] = false;

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

	Array selected_terrain_ids = terrain_selection.get("selected_h3maped_terrain_ids", Array());
	Array selected_project_terrain_ids = terrain_selection.get("selected_project_terrain_ids", Array());
	Array scheduled_records;
	Array skipped_records;
	Array scheduled_owner_colors;
	int32_t source_player_min_town_count = 0;
	int32_t source_player_min_castle_count = 0;
	int32_t source_neutral_min_town_count = 0;
	int32_t source_neutral_min_castle_count = 0;
	int32_t assigned_player_min_town_count = 0;
	int32_t assigned_player_min_castle_count = 0;
	int32_t neutral_minimum_town_castle_count = 0;
	int32_t density_schedule_count = 0;
	int32_t skipped_unassigned_player_start_min_town_count = 0;
	int32_t skipped_unassigned_player_start_min_castle_count = 0;

	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		if (Variant(runtime_zone_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[index];
		const int32_t runtime_index = int32_t(runtime.get("runtime_zone_index", index));
		const int32_t owner_color = int32_t(runtime.get("actual_owner_color", -1));
		const int32_t player_min_towns = int32_t(runtime.get("player_min_towns", 0));
		const int32_t player_min_castles = int32_t(runtime.get("player_min_castles", runtime.get("minimum_player_castles", 0)));
		const int32_t player_town_density = int32_t(runtime.get("player_town_density", 0));
		const int32_t player_castle_density = int32_t(runtime.get("player_castle_density", 0));
		const int32_t neutral_min_towns = int32_t(runtime.get("neutral_min_towns", 0));
		const int32_t neutral_min_castles = int32_t(runtime.get("neutral_min_castles", 0));
		const int32_t neutral_town_density = int32_t(runtime.get("neutral_town_density", 0));
		const int32_t neutral_castle_density = int32_t(runtime.get("neutral_castle_density", 0));

		source_player_min_town_count += player_min_towns;
		source_player_min_castle_count += player_min_castles;
		source_neutral_min_town_count += neutral_min_towns;
		source_neutral_min_castle_count += neutral_min_castles;
		neutral_minimum_town_castle_count += neutral_min_towns + neutral_min_castles;
		density_schedule_count += player_town_density + player_castle_density + neutral_town_density + neutral_castle_density;

		const int32_t direct_owned_count = player_min_towns + player_min_castles;
		if (direct_owned_count > 0 && owner_color < 0) {
			skipped_unassigned_player_start_min_town_count += player_min_towns;
			skipped_unassigned_player_start_min_castle_count += player_min_castles;
			Dictionary skipped;
			skipped["runtime_zone_index"] = runtime_index;
			skipped["source_zone_id"] = runtime.get("source_zone_id", -1);
			skipped["source_owner_index"] = runtime.get("source_owner_index", -1);
			skipped["actual_owner_color"] = owner_color;
			skipped["player_min_towns"] = player_min_towns;
			skipped["player_min_castles"] = player_min_castles;
			skipped["reason"] = "source player-owned minimum exists, but this source owner was not assigned to an active player color";
			skipped_records.append(skipped);
			continue;
		}

		if (owner_color < 0) {
			continue;
		}
		for (int32_t object_index = 0; object_index < direct_owned_count; ++object_index) {
			const bool has_castle = object_index >= player_min_towns;
			Dictionary scheduled;
			scheduled["phase"] = has_castle ? String("0x4a8d2c_direct_player_minimum_castle") : String("0x4a8d2c_direct_player_minimum_town");
			scheduled["helper"] = "0x4a93a2";
			scheduled["runtime_zone_index"] = runtime_index;
			scheduled["source_zone_id"] = runtime.get("source_zone_id", -1);
			scheduled["owner_color"] = owner_color;
			scheduled["has_castle"] = has_castle;
			scheduled["town_choice_index"] = runtime_index < town_choice_by_runtime.size() ? int32_t(town_choice_by_runtime[runtime_index]) : -1;
			scheduled["selected_h3maped_terrain_id"] = runtime_index < selected_terrain_ids.size() ? int32_t(selected_terrain_ids[runtime_index]) : -1;
			scheduled["selected_project_terrain_id"] = runtime_index < selected_project_terrain_ids.size() ? String(selected_project_terrain_ids[runtime_index]) : String();
			scheduled["object_materialization_blocked"] = true;
			scheduled_records.append(scheduled);
			scheduled_owner_colors.append(owner_color);
			if (has_castle) {
				assigned_player_min_castle_count += 1;
			} else {
				assigned_player_min_town_count += 1;
			}
		}
	}

	report["source_player_min_town_count"] = source_player_min_town_count;
	report["source_player_min_castle_count"] = source_player_min_castle_count;
	report["source_neutral_min_town_count"] = source_neutral_min_town_count;
	report["source_neutral_min_castle_count"] = source_neutral_min_castle_count;
	report["assigned_player_min_town_count"] = assigned_player_min_town_count;
	report["assigned_player_min_castle_count"] = assigned_player_min_castle_count;
	report["skipped_unassigned_player_start_min_town_count"] = skipped_unassigned_player_start_min_town_count;
	report["skipped_unassigned_player_start_min_castle_count"] = skipped_unassigned_player_start_min_castle_count;
	report["neutral_minimum_town_castle_count"] = neutral_minimum_town_castle_count;
	report["density_schedule_count"] = density_schedule_count;
	report["scheduled_direct_minimum_object_count"] = scheduled_records.size();
	report["scheduled_owned_player_town_count"] = scheduled_records.size();
	report["scheduled_owner_colors"] = scheduled_owner_colors;
	report["scheduled_records"] = scheduled_records;
	report["skipped_records"] = skipped_records;

	PackedInt32Array zone_word_u32 = terrain_cell_writeout.get("zone_word_u32", PackedInt32Array());
	PackedInt32Array terrain_code_u16 = terrain_cell_writeout.get("terrain_code_u16", PackedInt32Array());
	Dictionary live_visual_feedback = terrain_cell_writeout.get("repaint_live_visual_feedback", Dictionary());
	PackedInt32Array post_queue_terrain_code_u16 = live_visual_feedback.get("post_queue_terrain_code_u16", PackedInt32Array());
	const int32_t width = int32_t(terrain_cell_writeout.get("map_width", 0));
	const int32_t height = int32_t(terrain_cell_writeout.get("map_height", 0));
	const int32_t level_count = std::max(1, int32_t(terrain_cell_writeout.get("level_count", 1)));
	const int32_t expected_cell_count = width * height * level_count;
	const bool uses_post_queue_terrain = post_queue_terrain_code_u16.size() == expected_cell_count;
	if (uses_post_queue_terrain) {
		terrain_code_u16 = post_queue_terrain_code_u16;
	}
	report["direct_stamping_terrain_grid_source"] = uses_post_queue_terrain ? String("0x4a4025_0x4bb74b_0x4bc5f0_post_queue_generated_cell_0x24") : String("0x4a3f27_pre_queue_generated_cell_0x24");

	Dictionary scaled_by_runtime;
	Array scaled_coordinates = coordinate_replay.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled_coordinates.size(); ++index) {
		if (Variant(scaled_coordinates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scaled = scaled_coordinates[index];
		scaled_by_runtime[String::num_int64(int64_t(scaled.get("runtime_zone_index", -1)))] = scaled;
	}

	const String town_passability_mask = "000001110000011110001111111111111111111111111111";
	const String town_action_mask = "001000000000000000000000000000000000000000000000";
	const std::vector<H3MaskPoint> town_body_points = h3_text_mask_points(town_passability_mask, false);
	const std::vector<H3MaskPoint> town_action_points = h3_text_mask_points(town_action_mask, true);
	std::vector<uint8_t> object_occupied;
	if (expected_cell_count > 0) {
		object_occupied.resize(size_t(expected_cell_count), 0);
	}

	Array direct_stamping_records;
	int32_t direct_candidate_scan_count = 0;
	int32_t direct_candidate_total = 0;
	int32_t direct_candidate_missing_count = 0;
	int32_t direct_footprint_eligible_total = 0;
	int32_t direct_footprint_missing_count = 0;
	int32_t direct_footprint_rejected_bounds_count = 0;
	int32_t direct_footprint_rejected_zone_count = 0;
	int32_t direct_footprint_rejected_terrain_count = 0;
	int32_t direct_footprint_rejected_collision_count = 0;
	int32_t direct_footprint_marked_cell_count = 0;
	int32_t direct_unique_selection_count = 0;
	int32_t direct_random_tie_selection_count = 0;
	int32_t direct_random_tie_rng_call_count = 0;
	int32_t direct_record_projection_count = 0;
	int32_t direct_grid_unavailable_count = 0;
	H3MapedRng object_rng { uint32_t(int64_t(terrain_selection.get("rng_state_after_0x49b53d_uint32", coordinate_replay.get("rng_state_after_0x4a218c_replay_uint32", 0)))) };
	const uint32_t object_rng_state_before = object_rng.state;

	for (int64_t scheduled_index = 0; scheduled_index < scheduled_records.size(); ++scheduled_index) {
		if (Variant(scheduled_records[scheduled_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scheduled = scheduled_records[scheduled_index];
		const int32_t runtime_index = int32_t(scheduled.get("runtime_zone_index", -1));
		Dictionary scaled = scaled_by_runtime.get(String::num_int64(runtime_index), Dictionary());
		const int32_t anchor_x = int32_t(scaled.get("x_after_bbox_rescale", 0));
		const int32_t anchor_y = int32_t(scaled.get("y_after_bbox_rescale", 0));
		const int32_t anchor_level = int32_t(scaled.get("level", 0));

		Dictionary record;
		record["phase"] = "0x4a93a2_direct_primary_object_helper";
		record["runtime_zone_index"] = runtime_index;
		record["source_zone_id"] = scheduled.get("source_zone_id", -1);
		record["owner_color"] = scheduled.get("owner_color", -1);
		record["has_castle"] = scheduled.get("has_castle", false);
		record["runtime_anchor_x"] = anchor_x;
		record["runtime_anchor_y"] = anchor_y;
		record["runtime_anchor_level"] = anchor_level;
		record["direct_helper_address"] = "0x4a93a2";
		record["eligibility_helper_address"] = "0x49aa93";
		record["footprint_helper_address"] = "0x49a09c";
		record["base_constructor_address"] = "0x49ba89";
		record["town_vtable_address"] = "0x540a9c";
		record["record_size_bytes"] = 0x28;
		record["record_offset_0x20_owner_color"] = scheduled.get("owner_color", -1);
		record["record_offset_0x24_castle_flag"] = scheduled.get("has_castle", false);
		record["runtime_package_adoption"] = false;
		record["object_template_source"] = "objects.txt AVCcasx0.def type 98 subtype 0";
		record["object_template_passability_mask"] = town_passability_mask;
		record["object_template_action_mask"] = town_action_mask;
		record["town_footprint_body_cell_count"] = int32_t(town_body_points.size());
		record["town_footprint_action_cell_count"] = int32_t(town_action_points.size());
		direct_candidate_scan_count += 1;

		if (width <= 0 || height <= 0 || zone_word_u32.size() != expected_cell_count || terrain_code_u16.size() != expected_cell_count) {
			record["status"] = "blocked_missing_0x4a325d_zone_word_or_generated_cell_terrain_grid";
			record["candidate_count"] = 0;
			record["closest_candidate_count"] = 0;
			direct_grid_unavailable_count += 1;
			direct_candidate_missing_count += 1;
			direct_stamping_records.append(record);
			continue;
		}

		int32_t candidate_count = 0;
		int32_t closest_distance = 0x7fffffff;
		Array closest_candidates;
		Array candidate_preview;
		int32_t footprint_eligible_count = 0;
		int32_t footprint_rejected_bounds_count = 0;
		int32_t footprint_rejected_zone_count = 0;
		int32_t footprint_rejected_terrain_count = 0;
		int32_t footprint_rejected_collision_count = 0;
		int32_t closest_footprint_distance = 0x7fffffff;
		Array closest_footprint_candidates;
		Array footprint_candidate_preview;

		for (int32_t level = 0; level < level_count; ++level) {
			if (level != anchor_level) {
				continue;
			}
			for (int32_t y = 0; y < height; ++y) {
				for (int32_t x = 0; x < width; ++x) {
					const int32_t cell_index = level * width * height + y * width + x;
					const uint32_t masked = uint32_t(int32_t(zone_word_u32[cell_index])) & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != runtime_index) {
						continue;
					}
					const int32_t terrain_code = int32_t(terrain_code_u16[cell_index]) & 0x3f;
					if (terrain_code == 9) {
						continue;
					}
					const int32_t distance = h3maped_distance_truncate_local(anchor_x, anchor_y, x, y);
					candidate_count += 1;
					if (candidate_preview.size() < 8) {
						Dictionary candidate;
						candidate["x"] = x;
						candidate["y"] = y;
						candidate["level"] = level;
						candidate["distance_to_runtime_anchor"] = distance;
						candidate["terrain_code_u16"] = terrain_code;
						candidate_preview.append(candidate);
					}
					if (distance < closest_distance) {
						closest_distance = distance;
						closest_candidates.clear();
					}
					if (distance == closest_distance && closest_candidates.size() < 16) {
						Dictionary candidate;
						candidate["x"] = x;
						candidate["y"] = y;
						candidate["level"] = level;
						candidate["distance_to_runtime_anchor"] = distance;
						candidate["terrain_code_u16"] = terrain_code;
						closest_candidates.append(candidate);
					}

					bool footprint_passes = !town_body_points.empty();
					String footprint_reject_reason;
					for (const H3MaskPoint &point : town_body_points) {
						const int32_t body_x = x + point.dx;
						const int32_t body_y = y + point.dy;
						if (body_x < 0 || body_y < 0 || body_x >= width || body_y >= height) {
							footprint_passes = false;
							footprint_reject_reason = "out_of_bounds";
							break;
						}
						const int32_t body_index = level * width * height + body_y * width + body_x;
						if (body_index < 0 || body_index >= expected_cell_count) {
							footprint_passes = false;
							footprint_reject_reason = "out_of_bounds";
							break;
						}
						if (!object_occupied.empty() && object_occupied[size_t(body_index)] != 0) {
							footprint_passes = false;
							footprint_reject_reason = "object_collision";
							break;
						}
						const uint32_t body_masked = uint32_t(int32_t(zone_word_u32[body_index])) & H3MAPED_UNASSIGNED_ZONE_WORD;
						if (body_masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((body_masked >> 16U) & 0xffU) != runtime_index) {
							footprint_passes = false;
							footprint_reject_reason = "zone_mismatch";
							break;
						}
						const int32_t body_terrain_code = int32_t(terrain_code_u16[body_index]) & 0x3f;
						if (body_terrain_code == 8 || body_terrain_code == 9) {
							footprint_passes = false;
							footprint_reject_reason = "terrain_mismatch";
							break;
						}
					}
					if (!footprint_passes) {
						if (footprint_reject_reason == "out_of_bounds") {
							footprint_rejected_bounds_count += 1;
						} else if (footprint_reject_reason == "object_collision") {
							footprint_rejected_collision_count += 1;
						} else if (footprint_reject_reason == "terrain_mismatch") {
							footprint_rejected_terrain_count += 1;
						} else {
							footprint_rejected_zone_count += 1;
						}
						continue;
					}

					footprint_eligible_count += 1;
					if (footprint_candidate_preview.size() < 8) {
						Dictionary candidate;
						candidate["x"] = x;
						candidate["y"] = y;
						candidate["level"] = level;
						candidate["distance_to_runtime_anchor"] = distance;
						candidate["body_cell_count"] = int32_t(town_body_points.size());
						footprint_candidate_preview.append(candidate);
					}
					if (distance < closest_footprint_distance) {
						closest_footprint_distance = distance;
						closest_footprint_candidates.clear();
					}
					if (distance == closest_footprint_distance && closest_footprint_candidates.size() < 16) {
						Dictionary candidate;
						candidate["x"] = x;
						candidate["y"] = y;
						candidate["level"] = level;
						candidate["distance_to_runtime_anchor"] = distance;
						candidate["body_cell_count"] = int32_t(town_body_points.size());
						closest_footprint_candidates.append(candidate);
					}
				}
			}
		}

		direct_candidate_total += candidate_count;
		direct_footprint_eligible_total += footprint_eligible_count;
		direct_footprint_rejected_bounds_count += footprint_rejected_bounds_count;
		direct_footprint_rejected_zone_count += footprint_rejected_zone_count;
		direct_footprint_rejected_terrain_count += footprint_rejected_terrain_count;
		direct_footprint_rejected_collision_count += footprint_rejected_collision_count;
		record["candidate_count"] = candidate_count;
		record["candidate_preview"] = candidate_preview;
		record["closest_distance"] = candidate_count > 0 ? closest_distance : -1;
		record["closest_candidate_count"] = closest_candidates.size();
		record["closest_candidates"] = closest_candidates;
		record["footprint_eligible_count"] = footprint_eligible_count;
		record["footprint_candidate_preview"] = footprint_candidate_preview;
		record["footprint_rejected_bounds_count"] = footprint_rejected_bounds_count;
		record["footprint_rejected_zone_count"] = footprint_rejected_zone_count;
		record["footprint_rejected_terrain_count"] = footprint_rejected_terrain_count;
		record["footprint_rejected_collision_count"] = footprint_rejected_collision_count;
		record["closest_footprint_distance"] = footprint_eligible_count > 0 ? closest_footprint_distance : -1;
		record["closest_footprint_candidate_count"] = closest_footprint_candidates.size();
		record["closest_footprint_candidates"] = closest_footprint_candidates;
		record["full_0x49aa93_status"] = footprint_eligible_count > 0
				? String("0x49aa93_0x49a09c_town_footprint_gate_ported_for_zone_words_no_package_adoption")
				: String("0x49aa93_0x49a09c_town_footprint_gate_no_eligible_candidates");

		if (candidate_count == 0) {
			record["status"] = "0x4a93a2_zone_byte_candidate_scan_no_candidates";
			direct_candidate_missing_count += 1;
		} else if (footprint_eligible_count == 0) {
			record["status"] = "0x4a93a2_0x49aa93_town_footprint_gate_no_eligible_candidates";
			direct_footprint_missing_count += 1;
		} else {
			Dictionary selected;
			bool selected_from_random_tie = false;
			int32_t random_tie_rng_value = -1;
			int32_t random_tie_selected_index = -1;
			if (closest_footprint_candidates.size() == 1 && Variant(closest_footprint_candidates[0]).get_type() == Variant::DICTIONARY) {
				selected = closest_footprint_candidates[0];
				record["status"] = "0x4a93a2_unique_closest_0x49aa93_town_footprint_candidate_record_projection_inspection_only";
				direct_unique_selection_count += 1;
			} else {
				random_tie_rng_value = object_rng.next();
				direct_random_tie_rng_call_count += 1;
				random_tie_selected_index = random_tie_rng_value % int32_t(closest_footprint_candidates.size());
				selected = closest_footprint_candidates[random_tie_selected_index];
				selected_from_random_tie = true;
				record["status"] = "0x4a93a2_random_tie_0x49aa93_town_footprint_candidate_record_projection_inspection_only";
				direct_random_tie_selection_count += 1;
			}
			record["selected_x"] = selected.get("x", -1);
			record["selected_y"] = selected.get("y", -1);
			record["selected_level"] = selected.get("level", -1);
			record["selected_from_random_tie"] = selected_from_random_tie;
			record["random_tie_rng_value"] = random_tie_rng_value;
			record["random_tie_selected_index"] = random_tie_selected_index;
			record["object_record_projection_status"] = "0x49ba89_0x540a9c_record_fields_projected_no_package_adoption";

			int32_t marked_cells = 0;
			Array marked_preview;
			for (const H3MaskPoint &point : town_body_points) {
				const int32_t body_x = int32_t(selected.get("x", -1)) + point.dx;
				const int32_t body_y = int32_t(selected.get("y", -1)) + point.dy;
				const int32_t body_level = int32_t(selected.get("level", -1));
				const int32_t body_index = body_level * width * height + body_y * width + body_x;
				if (body_index < 0 || body_index >= expected_cell_count || object_occupied.empty()) {
					continue;
				}
				if (object_occupied[size_t(body_index)] == 0) {
					object_occupied[size_t(body_index)] = 1;
					marked_cells += 1;
					if (marked_preview.size() < 12) {
						marked_preview.append(h3_cell_dictionary(body_x, body_y, body_level));
					}
				}
			}
			record["object_occupied_cell_mark_count"] = marked_cells;
			record["object_occupied_body_cell_preview"] = marked_preview;
			direct_footprint_marked_cell_count += marked_cells;
			direct_record_projection_count += 1;
		}
		direct_stamping_records.append(record);
	}

	Array project_town_records;
	Array project_player_starts;
	Array project_owner_slots;
	int32_t synchronized_start_count = 0;
	for (int64_t index = 0; index < direct_stamping_records.size(); ++index) {
		if (Variant(direct_stamping_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary h3_record = direct_stamping_records[index];
		if (String(h3_record.get("object_record_projection_status", "")) != "0x49ba89_0x540a9c_record_fields_projected_no_package_adoption") {
			continue;
		}
		const int32_t owner_color = int32_t(h3_record.get("owner_color", -1));
		if (owner_color < 0) {
			continue;
		}
		const int32_t player_slot = owner_color + 1;
		const String slot_id = h3_slot_id_2(player_slot);
		const String faction_id = project_faction_for_player_slot(normalized_config, player_slot);
		const String town_id = project_town_for_faction(faction_id);
		const String player_type = project_player_type_for_slot(normalized_config, player_slot);
		const int32_t x = int32_t(h3_record.get("selected_x", -1));
		const int32_t y = int32_t(h3_record.get("selected_y", -1));
		const int32_t level = int32_t(h3_record.get("selected_level", 0));
		const int32_t runtime_index = int32_t(h3_record.get("runtime_zone_index", -1));

		Dictionary runtime;
		for (int64_t runtime_record_index = 0; runtime_record_index < runtime_zone_records.size(); ++runtime_record_index) {
			if (Variant(runtime_zone_records[runtime_record_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary candidate_runtime = runtime_zone_records[runtime_record_index];
			if (int32_t(candidate_runtime.get("runtime_zone_index", -1)) == runtime_index) {
				runtime = candidate_runtime;
				break;
			}
		}

		Array body_tiles;
		for (const H3MaskPoint &point : town_body_points) {
			body_tiles.append(h3_cell_dictionary(x + point.dx, y + point.dy, level));
		}
		Array approach_tiles;
		for (const H3MaskPoint &point : town_action_points) {
			approach_tiles.append(h3_cell_dictionary(x + point.dx, y + point.dy, level));
		}

		Dictionary town_record;
		town_record["placement_id"] = "native_rmg_town_start_" + slot_id;
		town_record["record_type"] = "player_start_town";
		town_record["kind"] = "town";
		town_record["town_id"] = town_id;
		town_record["faction_id"] = faction_id;
		town_record["owner"] = player_slot == 1 ? String("player") : String("enemy");
		town_record["owner_slot"] = player_slot;
		town_record["player_slot"] = player_slot;
		town_record["player_type"] = player_type;
		town_record["team_id"] = "team_" + slot_id;
		town_record["zone_id"] = runtime.get("source_zone_id", h3_record.get("source_zone_id", -1));
		town_record["zone_role"] = runtime.get("role", "");
		town_record["runtime_zone_index"] = runtime_index;
		town_record["x"] = x;
		town_record["y"] = y;
		town_record["level"] = level;
		town_record["primary_tile"] = h3_cell_dictionary(x, y, level);
		town_record["body_tiles"] = body_tiles;
		town_record["approach_tiles"] = approach_tiles;
		town_record["visit_tile"] = approach_tiles.is_empty() ? h3_cell_dictionary(x, y, level) : Dictionary(approach_tiles[0]);
		town_record["is_start_town"] = true;
		town_record["is_capital"] = true;
		town_record["is_castle"] = bool(h3_record.get("has_castle", true));
		town_record["settlement_category"] = "castle";
		town_record["capital_role"] = "player_start";
		town_record["start_anchor"] = true;
		town_record["materialization_state"] = "h3maped_private_town_record_candidate_no_public_package_adoption";
		town_record["source_algorithm"] = "h3maped_0x4a8d2c_0x4a93a2_0x49aa93_0x49ba89";
		town_record["h3maped_owner_color"] = owner_color;
		town_record["h3maped_record_status"] = h3_record.get("status", "");
		town_record["h3maped_record_projection_status"] = h3_record.get("object_record_projection_status", "");
		town_record["h3maped_selected_from_random_tie"] = h3_record.get("selected_from_random_tie", false);
		project_town_records.append(town_record);

		Dictionary start_record;
		start_record["start_id"] = "player_start_" + String::num_int64(player_slot);
		start_record["player_slot"] = player_slot;
		start_record["owner_slot"] = player_slot;
		start_record["player_type"] = player_type;
		start_record["team_id"] = "team_" + slot_id;
		start_record["faction_id"] = faction_id;
		start_record["town_id"] = town_id;
		start_record["town_placement_id"] = town_record.get("placement_id", "");
		start_record["zone_id"] = town_record.get("zone_id", "");
		start_record["zone_role"] = town_record.get("zone_role", "");
		start_record["x"] = x;
		start_record["y"] = y;
		start_record["level"] = level;
		start_record["bounds_status"] = "h3maped_footprint_checked";
		start_record["spacing_model"] = "h3maped_runtime_zone_anchor_and_0x49aa93_footprint_gate";
		start_record["primary_town_anchor_status"] = "materialized_as_h3maped_town_record_candidate";
		start_record["start_contract_source"] = "h3maped_0x4a93a2_town_record_candidate";
		project_player_starts.append(start_record);
		project_owner_slots.append(player_slot);
		if (int32_t(start_record.get("x", -999)) == int32_t(town_record.get("x", -1))
				&& int32_t(start_record.get("y", -999)) == int32_t(town_record.get("y", -1))
				&& int32_t(start_record.get("level", -999)) == int32_t(town_record.get("level", -1))) {
			synchronized_start_count += 1;
		}
	}

	Dictionary direct_stamping;
	direct_stamping["status"] = "0x4a93a2_0x49ba89_direct_town_object_stamping_projection_inspection_only";
	direct_stamping["source"] = "h3maped 0x4a93a2 scans matching generated-cell zone/source bytes, filters through 0x49aa93/0x49a09c, chooses closest candidates to the runtime-zone anchor with 0x4e7276 tie selection, then constructs 0x540a9c records through 0x49ba89";
	direct_stamping["terrain_grid_source"] = report.get("direct_stamping_terrain_grid_source", "");
	direct_stamping["direct_candidate_scan_count"] = direct_candidate_scan_count;
	direct_stamping["direct_candidate_total"] = direct_candidate_total;
	direct_stamping["direct_candidate_missing_count"] = direct_candidate_missing_count;
	direct_stamping["town_footprint_mask_status"] = "objects_txt_AVCcasx0_footprint_offsets_ported_for_0x49a09c";
	direct_stamping["town_footprint_body_cell_count"] = int32_t(town_body_points.size());
	direct_stamping["town_footprint_action_cell_count"] = int32_t(town_action_points.size());
	direct_stamping["town_footprint_body_offsets"] = h3_mask_points_to_array(town_body_points);
	direct_stamping["town_footprint_action_offsets"] = h3_mask_points_to_array(town_action_points);
	direct_stamping["direct_footprint_eligible_total"] = direct_footprint_eligible_total;
	direct_stamping["direct_footprint_missing_count"] = direct_footprint_missing_count;
	direct_stamping["direct_footprint_rejected_bounds_count"] = direct_footprint_rejected_bounds_count;
	direct_stamping["direct_footprint_rejected_zone_count"] = direct_footprint_rejected_zone_count;
	direct_stamping["direct_footprint_rejected_terrain_count"] = direct_footprint_rejected_terrain_count;
	direct_stamping["direct_footprint_rejected_collision_count"] = direct_footprint_rejected_collision_count;
	direct_stamping["direct_footprint_marked_cell_count"] = direct_footprint_marked_cell_count;
	direct_stamping["direct_grid_unavailable_count"] = direct_grid_unavailable_count;
	direct_stamping["direct_unique_selection_count"] = direct_unique_selection_count;
	direct_stamping["direct_random_tie_selection_count"] = direct_random_tie_selection_count;
	direct_stamping["direct_random_tie_rng_call_count"] = direct_random_tie_rng_call_count;
	direct_stamping["direct_record_projection_count"] = direct_record_projection_count;
	direct_stamping["object_rng_state_before_0x4a93a2_uint32"] = int64_t(object_rng_state_before);
	direct_stamping["object_rng_state_after_0x4a93a2_uint32"] = int64_t(object_rng.state);
	direct_stamping["runtime_package_adoption"] = false;
	direct_stamping["stamps_generated_cell_state"] = false;
	direct_stamping["records"] = direct_stamping_records;
	direct_stamping["blocked_next"] = "port roads, guards, blockers, mines, rewards, and final h3maped writeout before public package adoption";
	report["direct_stamping_projection_status"] = direct_stamping.get("status", "");
	report["direct_stamping_projection"] = direct_stamping;

	Dictionary normalized_constraints = normalized_config.get("player_constraints", Dictionary());
	Dictionary project_town_adoption_candidate;
	project_town_adoption_candidate["schema_id"] = "aurelion_native_rmg_town_placement_v1";
	project_town_adoption_candidate["schema_version"] = 1;
	project_town_adoption_candidate["status"] = "h3maped_project_town_adoption_candidate_inspection_only";
	project_town_adoption_candidate["source"] = "private bridge from h3maped 0x49ba89 town records into project town/player-start schemas; public package adoption remains blocked until later executable phases are ported";
	project_town_adoption_candidate["public_package_adoption"] = false;
	project_town_adoption_candidate["runtime_grid_adoption"] = false;
	project_town_adoption_candidate["town_record_count"] = project_town_records.size();
	project_town_adoption_candidate["player_start_count"] = project_player_starts.size();
	project_town_adoption_candidate["expected_player_count"] = int32_t(normalized_constraints.get("player_count", project_player_starts.size()));
	project_town_adoption_candidate["synchronized_player_start_count"] = synchronized_start_count;
	project_town_adoption_candidate["owner_slots"] = project_owner_slots;
	project_town_adoption_candidate["town_records"] = project_town_records;
	project_town_adoption_candidate["player_starts"] = project_player_starts;
	project_town_adoption_candidate["blocked_next"] = "adopt these records into the runtime package only after roads, guards, blockers, mines, rewards, and final h3maped writeout are ported";
	report["project_town_adoption_candidate_status"] = project_town_adoption_candidate.get("status", "");
	report["project_town_adoption_candidate"] = project_town_adoption_candidate;
	report["project_town_record_candidate_count"] = project_town_records.size();
	report["next_materialization_status"] = "pending_roads_guards_blockers_mines_rewards_and_final_h3maped_writeout_before_public_package_adoption";
	return report;
}

Dictionary footprint_finalizer_4a3710_report(const Dictionary &normalized_config, const Dictionary &runtime_zone_setup, const Dictionary &footprint_boundary) {
	Dictionary report;
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	const bool synthetic_branch_allowed = level_count > 1 || water_code != 0;
	Array runtime_zone_records = runtime_zone_setup.get("runtime_zone_records", Array());
	Array per_level = footprint_boundary.get("per_level", Array());
	int32_t original_same_level_runtime_zone_count = int32_t(footprint_boundary.get("total_collected_runtime_zone_count", runtime_zone_records.size()));
	if (per_level.size() > 0 && Variant(per_level[0]).get_type() == Variant::DICTIONARY) {
		Dictionary level_record = per_level[0];
		Array collected = level_record.get("collected_runtime_zone_indices", Array());
		original_same_level_runtime_zone_count = int32_t(collected.size());
	}
	const int32_t final_runtime_zone_count = int32_t(runtime_zone_records.size());
	const int32_t appended_runtime_zone_count = std::max(0, final_runtime_zone_count - original_same_level_runtime_zone_count);
	report["status"] = appended_runtime_zone_count == 0
			? String("0x4a3710_small_land_no_appended_zone_finalizer_ported_private")
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
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["public_package_output_allowed"] = false;
	report["blocked_next"] = appended_runtime_zone_count == 0
			? String("port 0x4a3f27 terrain/cell writeout over the private 0x4a325d buffer before project package output")
			: String("recover runtime_zone+0xc4 adjacency records before appended-zone finalizer output can be adopted");
	return report;
}

Dictionary polygon_split_model_4ccb64_report(const Dictionary &normalized_config, const Dictionary &coordinate_replay) {
	Dictionary report;
	report["status"] = "0x4ccb64_insertion_bridge_crossing_cleanup_and_finalizer_ported_inspection_only";
	report["source"] = "active reset port of the h3maped 0x4ccb64 source-node split loop and 0x4ccdfc finalizer over current 0x4a19ed scaled runtime-zone coordinates; output remains private inspection evidence before 0x4a2777 traversal";
	report["locator_address"] = "0x4cca55";
	report["splitter_address"] = "0x4ccb64";
	report["node_constructor_address"] = "0x4cc955";
	report["node_relink_address"] = "0x4cc643";
	report["edge_side_test_address"] = "0x4cc6f2";
	report["edge_erase_address"] = "0x4cc9cc";
	report["bridge_address"] = "0x4ccb1f";
	report["crossing_test_address"] = "0x4ccc7a";
	report["crossing_collapse_address"] = "0x4cc68e";
	report["intersection_writer_address"] = "0x4ccd69";
	report["finalizer_address"] = "0x4ccdfc";
	report["materializes_source_node_graph"] = true;
	report["materializes_boundaries"] = false;
	report["materializes_span_fill"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;
	report["feeds_real_0x4a2777_boundary"] = false;

	if (int32_t(normalized_config.get("level_count", 1)) != 1) {
		report["status"] = "unsupported_until_two_level_polygon_split_model_ported";
		return report;
	}

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_replay.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled.size(); ++index) {
		if (Variant(scaled[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
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

	report["split_steps"] = split_steps;
	report["runtime_split_point_count"] = int32_t(zones.size());
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
	report["post_crossing_cleanup_allocated_node_count"] = int32_t(model.nodes.size());
	report["post_crossing_cleanup_active_node_pair_count"] = model.active_node_pair_count();
	report["post_crossing_cleanup_active_node_count"] = model.active_node_pair_count() * 2;
	report["root_node_id_after_crossing_cleanup"] = model.root >= 0 ? model.nodes[size_t(model.root)].id : String();
	report["crossing_cleanup_status"] = blocked ? String("blocked_during_crossing_cleanup") : String("0x4ccc7a_0x4cc68e_crossing_cleanup_ported");

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
	report["finalizer_status"] = blocked ? String("blocked_before_0x4ccdfc") : String("0x4ccdfc_finalized_node_fanout_ported");
	report["finalized_triplet_count"] = finalized_triplet_count;
	report["finalized_node_count"] = finalized_node_count;
	report["active_payload_node_count"] = active_payload_node_count;
	report["finalized_steps"] = finalized_steps;

	Array source_node_walks;
	int32_t source_node_walk_count = 0;
	int32_t source_node_walk_guard_exhausted_count = 0;
	for (const RuntimeZoneSeed &zone : zones) {
		if (zone.level != 0) {
			continue;
		}
		Dictionary walk;
		walk["runtime_zone_index"] = zone.runtime_index;
		walk["locator_address"] = "0x4cca55";
		walk["consumer_address"] = "0x4a2777";
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
	report["source_node_walk_status"] = blocked ? String("blocked_before_0x4cca55_source_node_walk") : String("0x4cca55_to_0x4a2777_source_node_cycles_recovered_inspection_only");
	report["source_node_walk_count"] = source_node_walk_count;
	report["source_node_walk_guard_exhausted_count"] = source_node_walk_guard_exhausted_count;
	report["source_node_walks"] = source_node_walks;
	report["blocked_next"] = "feed finalized 0x4ccdfc source-node cycles into real 0x4a2777 traversal and then 0x4a325d span fill";
	return report;
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
	const Array accepted = supports_scope(normalized_config) ? accepted_templates(normalized_config) : Array();

	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_restart_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_restart_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "archived_current_native_rmg_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "previous_active_h3maped_boundary_archived_out_of_build";
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
	Dictionary identity = selection_identity(normalized_config);
	report["selection_identity"] = identity;
	if (bool(identity.get("ok", false))) {
		const TemplateEvidence *selected = template_for_catalog_index(int32_t(identity.get("source_catalog_index", -1)));
		if (selected != nullptr) {
			Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
			const int32_t human_count = int32_t(constraints.get("human_count", 1));
			const int32_t player_count = int32_t(constraints.get("player_count", 2));
			const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
			Dictionary assignment = player_slot_assignment_report(*selected, normalized_config, human_count, computer_count);
			report["player_slot_assignment"] = assignment;
			Dictionary source_template_record = source_template_record_for_catalog_index(selected->catalog_index);
			Dictionary runtime_zone_setup = runtime_zone_record_setup_report(*selected, source_template_record, assignment, human_count, player_count);
			report["runtime_zone_record_setup"] = runtime_zone_setup;
			Dictionary link_seed_setup = link_seed_setup_report(source_template_record, runtime_zone_setup, human_count, player_count);
			report["link_seed_setup"] = link_seed_setup;
			report["late_link_payload_postprocess"] = late_link_payload_postprocess_report(normalized_config, link_seed_setup.get("link_seeds", Array()));
			report["coordinate_replay"] = coordinate_replay_report(normalized_config, runtime_zone_setup, link_seed_setup, uint32_t(int64_t(identity.get("rng_state_after_selection_uint32", 0))));
			report["runtime_terrain_selection_49b53d"] = runtime_terrain_selection_49b53d_report(report["coordinate_replay"]);
			report["zone_footprint_phase_boundary"] = zone_footprint_phase_boundary_report(normalized_config, runtime_zone_setup);
			report["source_node_rectangle_4cc788"] = source_node_rectangle_4cc788_report();
			report["clip_helper_4a2b33"] = clip_helper_4a2b33_report(normalized_config);
			report["line_writer_4a261a"] = line_writer_4a261a_report(normalized_config);
			report["randomized_line_writer_4a2413"] = randomized_line_writer_4a2413_report(normalized_config);
			Dictionary polygon_split_model = polygon_split_model_4ccb64_report(normalized_config, report["coordinate_replay"]);
			report["polygon_split_model_4ccb64"] = polygon_split_model;
			report["real_source_node_cycle_traversal_4a2777"] = real_source_node_cycle_traversal_4a2777_report(normalized_config, report["coordinate_replay"], polygon_split_model);
			report["real_boundary_span_fill_4a325d"] = real_boundary_span_fill_4a325d_report(normalized_config, report["coordinate_replay"], polygon_split_model);
			report["terrain_cell_writeout_4a3f27"] = terrain_cell_writeout_4a3f27_report(normalized_config, report["coordinate_replay"], polygon_split_model, report["runtime_terrain_selection_49b53d"]);
			report["late_connection_overlap_geometry"] = late_connection_overlap_geometry_report(runtime_zone_setup.get("runtime_zone_records", Array()), link_seed_setup.get("link_seeds", Array()), report["terrain_cell_writeout_4a3f27"]);
			report["town_castle_phase_schedule"] = town_castle_phase_schedule_report(normalized_config, runtime_zone_setup.get("runtime_zone_records", Array()), report["coordinate_replay"], report["runtime_terrain_selection_49b53d"], report["terrain_cell_writeout_4a3f27"]);
			report["terrainplacement_visual_tables_4bcff5"] = terrainplacement_visual_tables_4bcff5_report();
			report["footprint_finalizer_4a3710"] = footprint_finalizer_4a3710_report(normalized_config, report["runtime_zone_record_setup"], report["zone_footprint_phase_boundary"]);
		}
	}
	report["restart_phase_backlog"] = restart_backlog().get("phases", Array());
	report["materialized_phase_status"] = "none_after_restart";
	report["blocked_before_materialization"] = "waiting_for_strict_h3maped_small_phase_ports_from_0x4ac552";
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
	result["message"] = "Small h3maped-derived RMG is reset to an executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
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
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
