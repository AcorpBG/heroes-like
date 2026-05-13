#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <set>
#include <utility>
#include <vector>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *OBJECT_CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json";
constexpr const char *CRTRAITS_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3ab_bmp/raw/crtraits.txt";
constexpr const char *REWARD_PROXY_CATALOG_PATH = "res://content/homm3_re_reward_object_proxy_catalog.json";
constexpr const char *PROJECT_TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *ARCHIVED_REPORT_TREADMILL_PATH = "src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp";
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

struct H3ObjectLimitOverride {
	int32_t type_id = -1;
	int32_t limit = 0;
};

struct H3MapedRewardCandidate {
	const char *constructor_address = "";
	const char *vtable_address = "";
	int32_t type_id = -1;
	int32_t subtype_id = 0;
	int32_t value = 0;
	int32_t weight = 0;
	int32_t extra_0x14 = 0;
	const char *source_note = "";
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
};

struct H3FootprintGateResult {
	bool pass = false;
	int32_t valid_count = 0;
	int32_t invalid_count = 0;
	int32_t invalid_transition_count = 0;
	int32_t out_of_bounds_count = 0;
	int32_t occupied_count = 0;
	int32_t owner_mismatch_count = 0;
	int32_t terrain_rejected_count = 0;
	int32_t repaint_rejected_count = 0;
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
};

struct SourceCycleNode {
	int32_t x = 0;
	int32_t y = 0;
	bool finalized = false;
	int32_t finalized_x = 0;
	int32_t finalized_y = 0;
};

struct SourceWalk {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t start_x = 0;
	int32_t start_y = 0;
	std::vector<SourceCycleNode> cycle_nodes;
};

struct PolygonSourceResult {
	std::vector<SourceWalk> walks;
	Array split_steps;
	int32_t executed_split_count = 0;
	int32_t duplicate_skip_count = 0;
	int32_t edge_removal_count = 0;
	int32_t inserted_node_pair_count = 0;
	int32_t inserted_bridge_pair_count = 0;
	int32_t crossing_scan_count = 0;
	int32_t crossing_test_count = 0;
	int32_t crossing_collapse_count = 0;
	int32_t allocated_node_pair_count = 0;
	int32_t active_node_pair_count = 0;
	int32_t finalized_triplet_count = 0;
	int32_t finalized_node_count = 0;
	int32_t active_payload_node_count = 0;
	int32_t source_node_walk_count = 0;
	int32_t source_node_walk_guard_exhausted_count = 0;
	bool blocked = false;
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

struct H3MaskPoint {
	int32_t dx = 0;
	int32_t dy = 0;
};

struct TerrainVisualGridTables {
	std::vector<TerrainVisualRow> dirt_rows;
	std::vector<TerrainVisualRow> sand_rows;
	std::vector<TerrainVisualRow> normal_rows;
	std::vector<TerrainVisualRow> water_rows;
	std::vector<TerrainVisualRow> rock_rows;
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
		for (int32_t index = 0; index + 1 < int32_t(nodes.size()); index += 2) {
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
		for (int32_t guard = 0; guard < 512 && current >= 0 && current < int32_t(nodes.size()); ++guard) {
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

	int32_t finalize_4ccdfc() {
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
		}
		return finalized_triplets;
	}
};

struct RuntimeLinkSeed {
	int32_t runtime_a = -1;
	int32_t runtime_b = -1;
};

constexpr TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, "", 0xff, 0xff },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, "", 0x0f, 0x0f },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, "", 0x3f, 0x7f },
};

constexpr const char *H3MAPED_ALLOWED_MAIN_TOWNS[] = {
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

int32_t nested_or_flat_i32(const Dictionary &dict, const char *nested_key, const char *flat_key, int32_t fallback) {
	Dictionary nested = dict.get(nested_key, Dictionary());
	if (nested.has(flat_key)) {
		return int32_t(nested.get(flat_key, fallback));
	}
	return int32_t(dict.get(flat_key, fallback));
}

String normalized_seed_text(const Dictionary &normalized_config) {
	return String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
}

int32_t player_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("player_count", normalized_config.get("player_count", 2)));
}

int32_t human_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("human_count", normalized_config.get("human_count", 1)));
}

String water_mode(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("water_mode", normalized_config.get("water_mode", "land")));
}

String size_class_id(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("size_class_id", normalized_config.get("size_class_id", "homm3_small")));
}

int32_t width(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "width", 36);
}

int32_t height(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "height", 36);
}

int32_t level_count(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "level_count", 1);
}

int32_t water_mode_code(const Dictionary &normalized_config) {
	const String mode = water_mode(normalized_config);
	if (mode == "normal_water") {
		return 1;
	}
	if (mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized_config) {
	int32_t score = int32_t((int64_t(std::max(1, width(normalized_config))) * int64_t(std::max(1, height(normalized_config))) * int64_t(std::max(1, level_count(normalized_config)))) / 0x510);
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

Dictionary template_record(const TemplateEvidence &candidate) {
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
	item["adapted_template_id"] = candidate.adapted_template_id;
	item["human_capable_source_owner_mask"] = int32_t(candidate.human_capable_source_owner_mask);
	item["player_capable_source_owner_mask"] = int32_t(candidate.player_capable_source_owner_mask);
	return item;
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

std::vector<H3ObjectRow> h3_object_rows_by_type_from_recovered_catalog(int32_t wanted_type_id, Dictionary &load_status) {
	std::vector<H3ObjectRow> rows;
	load_status = load_json_dictionary(OBJECT_CATALOG_SOURCE_PATH);
	if (!bool(load_status.get("ok", false))) {
		return rows;
	}
	Dictionary catalog = load_status.get("data", Dictionary());
	Array types = catalog.get("types", Array());
	for (int64_t type_index = 0; type_index < types.size(); ++type_index) {
		if (Variant(types[type_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary type_record = types[type_index];
		if (int32_t(type_record.get("type_id", -1)) != wanted_type_id) {
			continue;
		}
		Array templates = type_record.get("templates", Array());
		for (int64_t template_index = 0; template_index < templates.size(); ++template_index) {
			if (Variant(templates[template_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary item = templates[template_index];
			H3ObjectRow row;
			row.source_line = int32_t(item.get("source_row", 0));
			row.def_name = String(item.get("def_name", ""));
			row.passability_mask = String(item.get("pass_mask", ""));
			row.action_mask = String(item.get("action_mask", ""));
			row.terrain_mask_primary = String(item.get("terrain_mask_a", ""));
			row.terrain_mask_secondary = String(item.get("terrain_mask_b", ""));
			row.type_id = int32_t(item.get("type_id", wanted_type_id));
			row.subtype_id = int32_t(item.get("subtype", -1));
			rows.push_back(row);
		}
		break;
	}
	load_status["matched_type_id"] = wanted_type_id;
	load_status["matched_row_count"] = int32_t(rows.size());
	return rows;
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

int32_t h3maped_global_type_limit_5a26e4(int32_t type_id) {
	static constexpr H3ObjectLimitOverride OVERRIDES[] = {
		{ 26, 200 }, { 6, 200 }, { 57, 48 }, { 8, 64 }, { 100, 32 }, { 23, 32 },
		{ 32, 32 }, { 51, 32 }, { 61, 32 }, { 102, 32 }, { 41, 32 }, { 4, 32 },
		{ 47, 32 }, { 107, 32 }, { 104, 32 }, { 113, 32 }, { 88, 32 }, { 89, 32 },
		{ 90, 32 }, { 92, 32 }, { 55, 32 }, { 109, 32 }, { 112, 32 }, { 48, 32 },
		{ 22, 32 }, { 39, 32 }, { 108, 32 }, { 105, 32 }, { 83, 48 }, { 7, 32 },
	};
	for (const H3ObjectLimitOverride &entry : OVERRIDES) {
		if (entry.type_id == type_id) {
			return entry.limit;
		}
	}
	return 0x7d00;
}

int32_t h3maped_zone_type_limit_5a2a8c(int32_t type_id) {
	static constexpr H3ObjectLimitOverride OVERRIDES[] = {
		{ 2, 1 }, { 13, 1 }, { 14, 1 }, { 15, 1 }, { 27, 1 }, { 28, 1 },
		{ 30, 1 }, { 31, 1 }, { 35, 1 }, { 38, 1 }, { 42, 1 }, { 48, 1 },
		{ 49, 1 }, { 56, 1 }, { 58, 1 }, { 60, 1 }, { 64, 1 }, { 80, 1 },
		{ 94, 1 }, { 96, 1 }, { 99, 1 }, { 106, 1 }, { 110, 1 }, { 113, 3 },
	};
	for (const H3ObjectLimitOverride &entry : OVERRIDES) {
		if (entry.type_id == type_id) {
			return entry.limit;
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
		{ "0x4a1605", "0x540ba0", 107, 0, 1000, 50, 0, "School of War candidate" },
	};
}

Dictionary reward_proxy_for_type_subtype(int32_t type_id, int32_t subtype_id) {
	Dictionary load = load_json_dictionary(REWARD_PROXY_CATALOG_PATH);
	if (!bool(load.get("ok", false))) {
		return Dictionary();
	}
	Dictionary catalog = load.get("data", Dictionary());
	Array entries = catalog.get("entries", Array());
	for (int64_t index = 0; index < entries.size(); ++index) {
		if (Variant(entries[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary entry = entries[index];
		if (String(entry.get("generated_kind", "")) != "reward_reference") {
			continue;
		}
		if (int32_t(entry.get("homm3_re_object_type_id", -1)) == type_id && int32_t(entry.get("homm3_re_object_subtype", 0)) == subtype_id) {
			return entry;
		}
	}
	return Dictionary();
}

int32_t reward_proxy_reference_count_for_type_subtype(int32_t type_id, int32_t subtype_id) {
	return reward_proxy_for_type_subtype(type_id, subtype_id).is_empty() ? 0 : 1;
}

struct RewardObjectSelection {
	bool selected = false;
	H3MapedRewardCandidate candidate;
	Dictionary proxy;
	int32_t eligible_count = 0;
	int32_t eligible_weight_total = 0;
	int32_t rejected_value_count = 0;
	int32_t rejected_proxy_count = 0;
	int32_t rejected_limit_count = 0;
	int32_t rng_value = -1;
	int32_t selected_weight_roll = -1;
};

RewardObjectSelection h3maped_select_reward_candidate_4a9f1c(int32_t min_value, int32_t max_value, H3MapedRng &rng) {
	RewardObjectSelection result;
	struct Eligible {
		H3MapedRewardCandidate candidate;
		Dictionary proxy;
	};
	std::vector<Eligible> eligible;
	for (const H3MapedRewardCandidate &candidate : h3maped_reward_proxy_backed_candidates_49f95a()) {
		if (candidate.value < min_value || candidate.value > max_value) {
			result.rejected_value_count += 1;
			continue;
		}
		if (h3maped_global_type_limit_5a26e4(candidate.type_id) <= 0 || h3maped_zone_type_limit_5a2a8c(candidate.type_id) <= 0) {
			result.rejected_limit_count += 1;
			continue;
		}
		Dictionary proxy = reward_proxy_for_type_subtype(candidate.type_id, candidate.subtype_id);
		if (proxy.is_empty()) {
			result.rejected_proxy_count += 1;
			continue;
		}
		eligible.push_back(Eligible { candidate, proxy });
		result.eligible_weight_total += candidate.weight;
	}
	result.eligible_count = int32_t(eligible.size());
	if (eligible.empty() || result.eligible_weight_total <= 0) {
		return result;
	}
	result.rng_value = rng.next();
	result.selected_weight_roll = result.rng_value % result.eligible_weight_total;
	int32_t accumulator = 0;
	for (const Eligible &entry : eligible) {
		accumulator += entry.candidate.weight;
		if (result.selected_weight_roll < accumulator) {
			result.selected = true;
			result.candidate = entry.candidate;
			result.proxy = entry.proxy;
			return result;
		}
	}
	result.selected = true;
	result.candidate = eligible.back().candidate;
	result.proxy = eligible.back().proxy;
	return result;
}

Array accepted_templates(const Dictionary &normalized_config) {
	Array accepted;
	const int32_t score = size_score(normalized_config);
	const int32_t humans = human_count(normalized_config);
	const int32_t players = player_count(normalized_config);
	if (!supports_scope(normalized_config)) {
		return accepted;
	}
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (humans < candidate.min_humans || humans > candidate.max_humans || players < candidate.min_total_players || players > candidate.max_total_players || players < humans) {
			continue;
		}
		accepted.append(template_record(candidate));
	}
	return accepted;
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

bool read_h3maped_i32_le(Ref<FileAccess> &file, int64_t va, int32_t &out_value) {
	uint32_t raw_value = 0;
	if (!read_h3maped_u32_le(file, va, raw_value)) {
		return false;
	}
	out_value = int32_t(raw_value);
	return true;
}

std::vector<std::vector<String>> parse_h3maped_tsv(const String &text) {
	std::vector<std::vector<String>> rows;
	std::vector<String> row;
	String field;
	bool quoted = false;
	for (int64_t index = 0; index < text.length(); ++index) {
		const char32_t ch = text[index];
		if (ch == '"') {
			if (quoted && index + 1 < text.length() && text[index + 1] == '"') {
				field += String::chr('"');
				++index;
			} else {
				quoted = !quoted;
			}
			continue;
		}
		if (!quoted && ch == '\t') {
			row.push_back(field);
			field = String();
			continue;
		}
		if (!quoted && (ch == '\n' || ch == '\r')) {
			if (ch == '\r' && index + 1 < text.length() && text[index + 1] == '\n') {
				++index;
			}
			row.push_back(field);
			rows.push_back(row);
			row.clear();
			field = String();
			continue;
		}
		field += String::chr(ch);
	}
	if (field.length() > 0 || !row.empty()) {
		row.push_back(field);
		rows.push_back(row);
	}
	return rows;
}

bool parse_int_field(const String &value, int32_t &out_value) {
	const String stripped = value.strip_edges();
	if (stripped.is_empty()) {
		return false;
	}
	const CharString utf8 = stripped.utf8();
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(utf8.get_data(), &end, 10);
	if (errno != 0 || end == utf8.get_data() || *end != '\0') {
		return false;
	}
	out_value = int32_t(parsed);
	return true;
}

std::vector<std::pair<int32_t, int32_t>> h3maped_crtraits_monster_row_walk() {
	static constexpr int32_t GROUP_COUNTS[] = { 14, 14, 14, 14, 14, 14, 14, 14, 6, 14, 13 };
	std::vector<std::pair<int32_t, int32_t>> rows;
	int32_t monster_index = 0;
	int32_t source_row_index = 2;
	for (const int32_t group_count : GROUP_COUNTS) {
		for (int32_t index = 0; index < group_count; ++index) {
			rows.push_back(std::make_pair(monster_index, source_row_index));
			++monster_index;
			++source_row_index;
		}
		source_row_index += 3;
	}
	for (int32_t index = 0; index < 5; ++index) {
		rows.push_back(std::make_pair(monster_index, source_row_index));
		++monster_index;
		++source_row_index;
	}
	return rows;
}

Dictionary phase_record(const String &id, const String &source, const String &status) {
	Dictionary phase;
	phase["id"] = id;
	phase["h3maped_source"] = source;
	phase["status"] = status;
	phase["materializes_public_output"] = false;
	return phase;
}

Array fresh_phase_backlog() {
	Array backlog;
	backlog.append(phase_record("template_selection", "0x49f0cd, 0x4ac597, 0x4e7276", "active_strict_boundary"));
	backlog.append(phase_record("player_slot_assignment", "0x4ac62a..0x4ac6ec", "active_strict_executable_port"));
	backlog.append(phase_record("runtime_zone_records", "0x4a218c, 0x49b452", "active_strict_executable_port"));
	backlog.append(phase_record("link_seed_setup", "0x4a1f3b", "active_strict_executable_port"));
	backlog.append(phase_record("coordinate_replay", "0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed", "active_strict_executable_port"));
	backlog.append(phase_record("zone_footprint_source_nodes", "0x4a3a03, 0x4cc788, 0x4cc955, 0x4ccb64, 0x4ccdfc", "active_strict_executable_port"));
	backlog.append(phase_record("zone_boundary_and_span_fill", "0x4a2777, 0x4a2b33, 0x4a261a, 0x4a2413, 0x4a325d", "active_strict_executable_port"));
	backlog.append(phase_record("zone_footprint_finalizer", "0x4a3710, 0x49b61b, 0x4a3554", "active_strict_executable_port"));
	backlog.append(phase_record("runtime_terrain_selection", "0x49b53d, 0x540908", "active_strict_executable_port"));
	backlog.append(phase_record("terrain_cell_writeout", "0x4a3f27, 0x4a4025, 0x4a4082, 0x4a415a", "active_strict_executable_port"));
	backlog.append(phase_record("terrainplacement_visual_tables", "0x4bcff5, 0x543108, 0x543380, 0x5434f0, 0x5435b0, 0x542f88", "active_strict_executable_port"));
	backlog.append(phase_record("terrainplacement_live_feedback", "0x4bb74b, 0x4bc5f0", "active_strict_executable_port"));
	backlog.append(phase_record("terrain_tile_byte_writeback", "0x49b2b6", "active_strict_executable_port"));
	backlog.append(phase_record("town_object_placement", "0x4a8d2c, 0x4a8db2, 0x4a93a2", "active_strict_executable_port"));
	backlog.append(phase_record("mines_rewards_and_object_vector", "0x4a9d6a, 0x4a9911, 0x4aa354, 0x4a9f1c, 0x4aa9b7", "active_strict_executable_port"));
	backlog.append(phase_record("roads_and_rivers", "0x4ab52a, 0x4aae7b, 0x4ab37f, 0x4b4243, 0x458a2f, 0x458893", "pending_runtime_port"));
	backlog.append(phase_record("connections_blockers_and_guards", "0x4a79a3, 0x4a61bc, 0x4a696b, 0x4a6cf2, 0x4a7605", "pending_runtime_port"));
	backlog.append(phase_record("final_h3m_writeout", "0x49b2b6 plus final object/tile serialization", "pending_runtime_port"));
	return backlog;
}

Array current_gap_summary() {
	Array gaps;
	gaps.append("active public boundary is reset to h3maped binary verification, small land scope, recovered size/water score, h3maped RNG template selection, player slots, runtime zones, link seeds, coordinate replay, source-node geometry, boundary/span fill, the small-land footprint finalizer, runtime terrain selection, and private terrain cell writeout");
	gaps.append("old private terrain, town, mine, reward, road, blocker, and guard ledgers are archived evidence and are not exposed as active generation state");
	gaps.append("runtime map packages remain blocked until each required phase is reintroduced as strict executable-derived generation state with project asset adaptation only at the final content reference layer");
	gaps.append("next implementation step is a narrow executable port of 0x4aa603/0x4aa3e9 private reward coordinate filtering and generated-cell/object mutation over the private object-vector prerequisites, not public package output");
	return gaps;
}

Dictionary strict_restart_state(const Dictionary &normalized_config, const Array &accepted) {
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_strict_executable_restart_state_v1";
	state["status"] = supports_scope(normalized_config) ? String("strict_executable_restart_scaffold_active") : String("unsupported_scope");
	state["scope"] = "small_36x36_surface_land_only";
	state["binary_verified"] = bool(binary_verification().get("ok", false));
	state["active_public_generation_state"] = false;
	state["runtime_generation_allowed"] = false;
	state["partial_materialized_payload_public_api"] = false;
	state["legacy_private_phase_ledgers_exposed"] = false;
	state["legacy_private_phase_ledgers_archived_only"] = true;
	state["accepted_template_count"] = accepted.size();
	state["implemented_boundaries"] = Array::make(
			"binary_verification:/root/Downloads/h3maped.exe",
			"small_scope_gate:36x36_one_level_land",
			"size_water_score_boundary:0x49f0cd",
			"template_rng_selection_boundary:0x4e7269_0x4e7276",
			"player_slot_assignment:0x4ac62a..0x4ac6ec",
			"runtime_zone_records:0x4a218c_0x49b452",
			"link_seed_setup:0x4a1f3b",
			"coordinate_replay:0x4a17f5_0x4a1701_0x4a1ad8_0x4a19ed",
			"zone_footprint_source_nodes:0x4a3a03_0x4cc788_0x4cc955_0x4ccb64_0x4ccdfc",
			"zone_boundary_and_span_fill:0x4a2777_0x4a2b33_0x4a261a_0x4a2413_0x4a325d",
			"zone_footprint_finalizer:0x4a3710_0x49b61b_0x4a3554",
			"runtime_terrain_selection:0x49b53d_0x540908",
			"terrain_cell_writeout:0x4a3f27_0x4a4025_0x4a4082_0x4a415a",
			"terrainplacement_visual_tables:0x4bcff5_0x543108_0x543380_0x5434f0_0x5435b0_0x542f88",
			"terrainplacement_live_feedback:0x4bb74b_0x4bc5f0",
			"terrain_tile_byte_writeback:0x49b2b6",
			"town_object_placement:0x4a8d2c_0x4a8db2_0x4a93a2",
			"mines_rewards_and_object_vector:0x4a9d6a_0x4a9911_0x4aa354_0x4a9f1c_0x4aa9b7");
	state["pending_strict_ports"] = Array::make(
			"private_reward_filter_and_mutation:0x4aa603_0x4aa3e9",
			"roads_rivers_blockers_guards:0x4ab52a_0x4aae7b_0x4a79a3_0x4a61bc_0x4a696b_0x4a6cf2",
			"final_h3m_writeout:0x49b2b6");
	state["prohibited_runtime_sources"] = Array::make(
			"catalog_auto_hash_selection",
			"owner_sample_exact_count_fitting",
			"fake_road_cluster_materialization",
			"metadata_only_zone_link_validation",
			"archived_native_generator_fallback");
	state["next_required_port"] = "private_reward_filter_and_mutation_0x4aa603_0x4aa3e9";
	return state;
}

Dictionary player_slot_assignment_phase(const Dictionary &normalized_config, const Dictionary &selection) {
	Dictionary selected_template = selection.get("selected_template", Dictionary());
	const uint8_t human_mask = uint8_t(int32_t(selected_template.get("human_capable_source_owner_mask", 0)));
	const uint8_t player_mask = uint8_t(int32_t(selected_template.get("player_capable_source_owner_mask", 0)));
	const int32_t humans = std::max(0, human_count(normalized_config));
	const int32_t players = std::max(humans, player_count(normalized_config));

	Dictionary phase;
	phase["phase_id"] = "player_slot_assignment";
	phase["status"] = bool(selection.get("ok", false)) ? String("active_internal_state") : String("blocked_until_template_selection");
	phase["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	phase["selected_color_bitmap_offset"] = "generator+0xed8";
	phase["assignment_slots_offset"] = "generator+0xee0";
	phase["mapped_slots_offset"] = "generator+0xee4";
	phase["human_capable_source_owner_mask"] = int32_t(human_mask);
	phase["player_capable_source_owner_mask"] = int32_t(player_mask);
	phase["human_capable_source_owner_indices"] = source_owner_indices_from_mask(human_mask);
	phase["player_capable_source_owner_indices"] = source_owner_indices_from_mask(player_mask);

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
	for (int32_t human = 0; human < humans && human < human_indices.size(); ++human) {
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
	for (int32_t source_index = 0; assigned_players < players && source_index < player_indices.size(); ++source_index) {
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
	phase["requested_human_count"] = humans;
	phase["requested_player_count"] = players;
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
	Dictionary adapted_template = find_project_template_record(adapted_template_id, catalog_load);
	phase["project_catalog_load"] = catalog_load;
	phase["project_template_id"] = adapted_template_id;
	if (adapted_template.is_empty() || Variant(adapted_template.get("zones", Variant())).get_type() != Variant::ARRAY) {
		return phase;
	}

	Array mapped_slots = player_phase.get("mapped_ee4_slots", Array());
	Array zones = adapted_template.get("zones", Array());
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
		Dictionary neutral_towns = zone.get("neutral_towns", Dictionary());
		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Dictionary mine_requirements = zone.get("mine_requirements", Dictionary());
		Dictionary minimum_by_category = mine_requirements.get("minimum_by_category", Dictionary());
		Dictionary density_by_category = mine_requirements.get("density_by_category", Dictionary());
		Dictionary terrain = zone.get("terrain", Dictionary());

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
		record["player_min_towns"] = player_towns.get("min_towns", 0);
		record["min_player_castles"] = min_castles;
		record["player_min_castles"] = min_castles;
		record["player_town_density"] = player_towns.get("town_density", 0);
		record["player_castle_density"] = player_towns.get("castle_density", 0);
		record["neutral_min_towns"] = neutral_towns.get("min_towns", 0);
		record["neutral_min_castles"] = neutral_towns.get("min_castles", 0);
		record["neutral_town_density"] = neutral_towns.get("town_density", 0);
		record["neutral_castle_density"] = neutral_towns.get("castle_density", 0);
		record["terrain_match_to_town"] = bool(terrain.get("match_to_faction", false));
		record["terrain_policy"] = Array(terrain.get("allowed", Array())).is_empty() ? String("match_to_player_town") : String("all_land_h3");
		record["project_allowed_faction_ids"] = town_policy.get("allowed_faction_ids", Array());
		if (!Array(town_policy.get("allowed_faction_ids", Array())).is_empty()) {
			Array allowed_h3_towns;
			for (int32_t town_index = 0; town_index < int32_t(sizeof(H3MAPED_ALLOWED_MAIN_TOWNS) / sizeof(H3MAPED_ALLOWED_MAIN_TOWNS[0])); ++town_index) {
				allowed_h3_towns.append(H3MAPED_ALLOWED_MAIN_TOWNS[town_index]);
			}
			record["allowed_faction_ids_for_49b3c1"] = allowed_h3_towns;
		} else {
			record["allowed_faction_ids_for_49b3c1"] = Array();
		}
		if (String(record["terrain_policy"]) == "all_land_h3") {
			Array allowed_terrain_ids;
			allowed_terrain_ids.append(0);
			allowed_terrain_ids.append(1);
			allowed_terrain_ids.append(2);
			allowed_terrain_ids.append(3);
			allowed_terrain_ids.append(4);
			allowed_terrain_ids.append(5);
			allowed_terrain_ids.append(7);
			record["allowed_h3maped_terrain_ids_for_49b53d"] = allowed_terrain_ids;
		}
		record["monster_strength"] = Dictionary(zone.get("monster_policy", Dictionary())).get("strength", "");
		record["minimum_wood_mines"] = minimum_by_category.get("timber", 0);
		record["minimum_mercury_mines"] = minimum_by_category.get("quicksilver", 0);
		record["minimum_ore_mines"] = minimum_by_category.get("ore", 0);
		record["minimum_sulfur_mines"] = minimum_by_category.get("ember_salt", 0);
		record["minimum_crystal_mines"] = minimum_by_category.get("lens_crystal", 0);
		record["minimum_gems_mines"] = minimum_by_category.get("cut_gems", 0);
		record["minimum_gold_mines"] = minimum_by_category.get("gold", 0);
		record["minimum_rare_mines"] = int32_t(minimum_by_category.get("gold", 0)) + int32_t(minimum_by_category.get("quicksilver", 0)) + int32_t(minimum_by_category.get("ember_salt", 0)) + int32_t(minimum_by_category.get("lens_crystal", 0)) + int32_t(minimum_by_category.get("cut_gems", 0));
		record["mine_density_wood"] = density_by_category.get("timber", 0);
		record["mine_density_mercury"] = density_by_category.get("quicksilver", 0);
		record["mine_density_ore"] = density_by_category.get("ore", 0);
		record["mine_density_sulfur"] = density_by_category.get("ember_salt", 0);
		record["mine_density_crystal"] = density_by_category.get("lens_crystal", 0);
		record["mine_density_gems"] = density_by_category.get("cut_gems", 0);
		record["mine_density_gold"] = density_by_category.get("gold", 0);
		record["treasure_bands"] = zone.get("treasure_bands", Array());
		runtime_records.append(record);
		actual_owner_colors.append(actual_owner);
	}

	if (minimum_source_base_size == 0x7fffffff) {
		minimum_source_base_size = 0;
	}
	phase["status"] = "active_internal_state";
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

bool player_filter_allows(const Dictionary &filter, int32_t humans, int32_t players) {
	return humans >= int32_t(filter.get("min_human", 0))
			&& humans <= int32_t(filter.get("max_human", 8))
			&& players >= int32_t(filter.get("min_total", 0))
			&& players <= int32_t(filter.get("max_total", 8));
}

Dictionary link_seed_phase(const Dictionary &normalized_config, const Dictionary &selection, const Dictionary &runtime_zone_phase) {
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
	const String runtime_status = String(runtime_zone_phase.get("status", ""));
	if (runtime_status != "active_internal_state" && runtime_status != "active_strict_executable_port") {
		return phase;
	}

	Dictionary catalog_load;
	Dictionary adapted_template = find_project_template_record(String(selection.get("adapted_template_id", "")), catalog_load);
	phase["project_catalog_load"] = catalog_load;
	if (adapted_template.is_empty() || Variant(adapted_template.get("links", Variant())).get_type() != Variant::ARRAY) {
		phase["status"] = "blocked_missing_project_template_links";
		return phase;
	}

	const int32_t humans = human_count(normalized_config);
	const int32_t players = player_count(normalized_config);
	Array links = adapted_template.get("links", Array());
	Array seeds;
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		if (!player_filter_allows(link.get("player_filter", Dictionary()), humans, players)) {
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

	phase["status"] = "active_internal_state";
	phase["source"] = "res://content/random_map_template_catalog.json recovered link rows consumed through h3maped 0x4a1f3b";
	phase["link_seed_count"] = seeds.size();
	phase["link_seeds"] = seeds;
	return phase;
}

int32_t h3maped_distance_truncate_local(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
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

Dictionary h3_cell_dictionary(int32_t x, int32_t y, int32_t level) {
	Dictionary cell;
	cell["x"] = x;
	cell["y"] = y;
	cell["level"] = level;
	return cell;
}

int64_t h3maped_cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0) {
		return -1;
	}
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

String native_mine_proxy_object_id_for_subtype(int32_t subtype) {
	switch (subtype) {
		case 0:
			return "object_brightwood_sawmill";
		case 1:
			return "object_marsh_peat_yard";
		case 2:
			return "object_ridge_quarry";
		case 3:
			return "object_floodplain_sluice_camp";
		case 4:
			return "object_cinder_ore_face";
		case 5:
			return "object_badlands_coin_sluice";
		case 6:
			return "object_reef_coin_assay";
		default:
			return "";
	}
}

bool h3maped_49a1d8_cell_valid(const std::vector<uint8_t> &cell_flags, const std::vector<int32_t> &live_terrain_code, int64_t flat) {
	if (flat < 0 || flat >= int64_t(cell_flags.size()) || flat >= int64_t(live_terrain_code.size())) {
		return false;
	}
	if ((cell_flags[size_t(flat)] & 0x10U) == 0U) {
		return false;
	}
	return (live_terrain_code[size_t(flat)] & 0x3f) != 9;
}

H3FootprintGateResult h3maped_49a09c_circular_mask_gate(const std::vector<H3MaskPoint> &mask_points, const std::vector<uint32_t> &zone_words, const std::vector<uint8_t> &cell_flags, const std::vector<int32_t> &live_terrain_code, const std::vector<uint8_t> &object_occupied, int32_t width, int32_t height, int32_t level_count, int32_t anchor_x, int32_t anchor_y, int32_t anchor_level, int32_t runtime_zone_index, bool object_is_water_type) {
	H3FootprintGateResult result;
	if (mask_points.empty()) {
		return result;
	}
	bool previous_invalid = true;
	bool saw_invalid_after_valid = false;
	bool current_invalid = true;
	for (int32_t step = 0; step <= int32_t(mask_points.size()); ++step) {
		const H3MaskPoint &point = mask_points[size_t(step % int32_t(mask_points.size()))];
		const int32_t body_x = anchor_x + point.dx;
		const int32_t body_y = anchor_y + point.dy;
		current_invalid = false;
		if (body_x < 0 || body_y < 0 || body_x >= width || body_y >= height || anchor_level < 0 || anchor_level >= level_count) {
			result.out_of_bounds_count += 1;
			current_invalid = true;
		} else {
			const int64_t body_flat = h3maped_cell_index(width, height, body_x, body_y, anchor_level);
			if (body_flat < 0 || body_flat >= int64_t(zone_words.size())) {
				result.out_of_bounds_count += 1;
				current_invalid = true;
			} else if (!object_occupied.empty() && object_occupied[size_t(body_flat)] != 0) {
				result.occupied_count += 1;
				current_invalid = true;
			} else if (!h3maped_49a1d8_cell_valid(cell_flags, live_terrain_code, body_flat)) {
				if (body_flat >= 0 && body_flat < int64_t(cell_flags.size()) && (cell_flags[size_t(body_flat)] & 0x10U) == 0U) {
					result.repaint_rejected_count += 1;
				} else {
					result.terrain_rejected_count += 1;
				}
				current_invalid = true;
			} else {
				const int32_t terrain_code = live_terrain_code[size_t(body_flat)] & 0x3f;
				if ((terrain_code == 8) != object_is_water_type) {
					result.terrain_rejected_count += 1;
					current_invalid = true;
				} else {
					const uint32_t body_masked = zone_words[size_t(body_flat)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (body_masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((body_masked >> 16U) & 0xffU) != runtime_zone_index) {
						result.owner_mismatch_count += 1;
						current_invalid = true;
					}
				}
			}
		}
		if (current_invalid) {
			result.invalid_count += 1;
			if (!previous_invalid) {
				if (saw_invalid_after_valid) {
					result.invalid_transition_count += 1;
					result.pass = false;
					return result;
				}
				saw_invalid_after_valid = true;
				result.invalid_transition_count += 1;
			}
		} else {
			result.valid_count += 1;
		}
		previous_invalid = current_invalid;
	}
	result.pass = !current_invalid || saw_invalid_after_valid;
	return result;
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
	if (level_count(normalized_config) != 1
			|| (String(runtime_zone_phase.get("status", "")) != "active_internal_state" && String(runtime_zone_phase.get("status", "")) != "active_strict_executable_port")
			|| (String(link_phase.get("status", "")) != "active_internal_state" && String(link_phase.get("status", "")) != "active_strict_executable_port")) {
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
			runtime["faction_id"] = runtime["selected_faction_id_49b3c1"];
			runtime["town_choice_index"] = town_choice_index;
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
	const int32_t map_span = std::min(width(normalized_config), height(normalized_config));
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

	phase["status"] = complete ? String("active_internal_state") : String("blocked_coordinate_candidate_replay");
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

int64_t cell_key_4a325d(int32_t map_width, int32_t map_height, int32_t x, int32_t y, int32_t level) {
	return int64_t(level) * int64_t(map_width) * int64_t(map_height) + int64_t(y) * int64_t(map_width) + int64_t(x);
}

uint32_t zone_word_4a325d(uint32_t existing_word, int32_t zone_id) {
	return (existing_word & 0xff00ffffU) | (uint32_t(zone_id & 0xff) << 16U);
}

int32_t zone_word_id_for_runtime_zone(const Dictionary &runtime_zone) {
	const int32_t runtime_index = int32_t(runtime_zone.get("runtime_zone_index", runtime_zone.get("runtime_index", -1)));
	const int32_t source_zone_id = int32_t(runtime_zone.get("source_zone_id", -1));
	if (source_zone_id > 0 && runtime_index >= 0 && source_zone_id == runtime_index + 1) {
		return runtime_index;
	}
	if (source_zone_id >= 0) {
		return source_zone_id;
	}
	return runtime_index;
}

ClipResult clip_point_4a2b33(int32_t x1, int32_t y1, int32_t x2, int32_t y2, const ClipBounds &bounds) {
	ClipResult result;
	result.x = x1;
	result.y = y1;
	if (x1 >= bounds.min_x && x1 < bounds.max_x && y1 >= bounds.min_y && y1 < bounds.max_y) {
		result.input_inside = true;
		return result;
	}

	int32_t clipped_x = x1;
	int32_t clipped_y = y1;
	const int32_t dx = x2 - x1;
	const int32_t dy = y2 - y1;
	auto accept_with_original_x = [&]() {
		result.x = x1;
		result.y = clipped_y;
		return result;
	};
	auto accept_current = [&]() {
		result.x = clipped_x;
		result.y = clipped_y;
		return result;
	};

	if (x1 < bounds.min_x && dx != 0) {
		const int32_t delta = bounds.min_x - x1;
		clipped_x = x1 + int32_t((int64_t(dx) * int64_t(delta)) / int64_t(dx));
		clipped_y = y1 + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dx));
		if ((y1 >= bounds.min_y && clipped_y < bounds.min_y) || (y1 < bounds.max_y && clipped_y >= bounds.max_y)) {
			return accept_with_original_x();
		}
	}
	if (clipped_y < bounds.min_y && dy != 0) {
		const int32_t delta = bounds.min_y - clipped_y;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		if ((x1 >= bounds.min_x && clipped_x < bounds.min_x) || (x1 < bounds.max_x && clipped_x >= bounds.max_x)) {
			return accept_with_original_x();
		}
	}
	if (clipped_x >= bounds.max_x && dx != 0) {
		const int32_t delta = bounds.max_x - clipped_x - 1;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dx));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dx));
		if ((y1 >= bounds.min_y && clipped_y < bounds.min_y) || (y1 < bounds.max_y && clipped_y >= bounds.max_y)) {
			return accept_with_original_x();
		}
	}
	if (clipped_y >= bounds.max_y && dy != 0) {
		const int32_t delta = bounds.max_y - clipped_y - 1;
		clipped_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		clipped_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		if ((x1 >= bounds.min_x && clipped_x < bounds.min_x) || (x1 < bounds.max_x && clipped_x >= bounds.max_x)) {
			return accept_current();
		}
	}
	return accept_current();
}

int32_t sign_for_line_4a261a(int32_t value) {
	return value > 0 ? 1 : -1;
}

void write_line_cell_4a261a(LineWriteResult &result, int32_t map_width, int32_t map_height, int32_t map_level_count, int32_t water_code, int32_t x, int32_t y, int32_t zone_id, int32_t level) {
	if (x < 0 || y < 0 || level < 0 || x >= map_width || y >= map_height || level >= map_level_count) {
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
	const int64_t key = cell_key_4a325d(map_width, map_height, x, y, level);
	result.unique_cells[key] = true;
}

LineWriteResult line_writer_4a261a(int32_t map_width, int32_t map_height, int32_t map_level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level) {
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
	const int32_t diagonal_step_y = sign_for_line_4a261a(dy);
	if (dx > abs_dy) {
		major = dx;
		minor = abs_dy;
		simple_step_x = 1;
	} else {
		major = abs_dy;
		minor = dx;
		simple_step_y = sign_for_line_4a261a(dy);
	}
	int32_t error = major / 2;
	int32_t x = x1;
	int32_t y = y1;
	while (x != x2 || y != y2) {
		write_line_cell_4a261a(result, map_width, map_height, map_level_count, water_code, x, y, zone_id, level);
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
	write_line_cell_4a261a(result, map_width, map_height, map_level_count, water_code, x, y, zone_id, level);
	return result;
}

LineWriteResult randomized_line_writer_4a2413(int32_t map_width, int32_t map_height, int32_t map_level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level, int32_t random_span_limit, H3MapedRng &rng, int32_t &rng_call_count, int32_t &inserted_midpoint_count, int32_t &max_pending_point_count) {
	LineWriteResult result;
	std::vector<PolygonPoint> pending;
	pending.push_back(PolygonPoint { x2, y2 });
	max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	int32_t current_x = x1;
	int32_t current_y = y1;
	for (int32_t guard = 0; guard < 4096 && !pending.empty(); ++guard) {
		const PolygonPoint target = pending.back();
		pending.pop_back();
		const int32_t midpoint_x = (target.x + current_x + 1) / 2;
		const int32_t midpoint_y = (target.y + current_y + 1) / 2;
		if ((midpoint_x == current_x && midpoint_y == current_y) || (midpoint_x == target.x && midpoint_y == target.y)) {
			const int32_t clamped_x = std::min(std::max(current_x, 0), map_width - 1);
			const int32_t clamped_y = std::min(std::max(current_y, 0), map_height - 1);
			write_line_cell_4a261a(result, map_width, map_height, map_level_count, water_code, clamped_x, clamped_y, zone_id, level);
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
			jittered_x += int32_t((int64_t(centered_offset) * int64_t(neg_dy)) / int64_t(segment_length));
			jittered_y += int32_t((int64_t(dx) * int64_t(centered_offset)) / int64_t(segment_length));
		}
		pending.push_back(target);
		pending.push_back(PolygonPoint { jittered_x, jittered_y });
		inserted_midpoint_count += 1;
		max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	}
	return result;
}

bool point_inside_bounds_4a2777(const ClipResult &point, const ClipBounds &bounds) {
	return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
}

void apply_line_trace_to_zone_buffer_4a2777(const LineWriteResult &line, std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t map_width, int32_t map_height, int32_t map_level_count) {
	for (const LineCellWrite &write : line.trace) {
		if (write.x < 0 || write.y < 0 || write.level < 0 || write.x >= map_width || write.y >= map_height || write.level >= map_level_count) {
			continue;
		}
		const int64_t key = cell_key_4a325d(map_width, map_height, write.x, write.y, write.level);
		zone_words[size_t(key)] = zone_word_4a325d(zone_words[size_t(key)], write.zone_id);
		if (write.reserved) {
			cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
		}
	}
}

bool span_cell_in_bounds_4a325d(int32_t map_width, int32_t map_height, int32_t map_level_count, const SpanRecord &span) {
	return span.x >= 0 && span.x < map_width && span.y >= 0 && span.y < map_height && span.level >= 0 && span.level < map_level_count;
}

bool is_unassigned_zone_word_4a325d(const std::vector<uint32_t> &zone_words, int32_t map_width, int32_t map_height, int32_t x, int32_t y, int32_t level) {
	return (zone_words[size_t(cell_key_4a325d(map_width, map_height, x, y, level))] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD;
}

void push_span_4a325d(std::vector<SpanRecord> &pending, const SpanRecord &span, SpanFillResult &result) {
	pending.push_back(span);
	result.pushed_span_count += 1;
	result.max_pending_span_count = std::max<int32_t>(result.max_pending_span_count, int32_t(pending.size()));
}

SpanFillResult span_fill_4a325d(std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t map_width, int32_t map_height, int32_t map_level_count, int32_t water_code, int32_t zone_id, const SpanRecord &seed) {
	SpanFillResult result;
	std::vector<SpanRecord> pending;
	push_span_4a325d(pending, seed, result);
	for (int32_t guard = 0; guard < map_width * map_height * std::max(1, map_level_count) * 4 && !pending.empty(); ++guard) {
		SpanRecord span = pending.back();
		pending.pop_back();
		result.popped_span_count += 1;
		if (!span_cell_in_bounds_4a325d(map_width, map_height, map_level_count, span)) {
			result.out_of_bounds_span_count += 1;
			continue;
		}
		int32_t x = span.x;
		while (x > 0 && is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		if (x >= 0 && x < map_width && !is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, x, span.y, span.level)) {
			result.blocked_initial_span_count += 1;
		}
		bool above_open = false;
		bool below_open = false;
		SpanRecord above_span;
		SpanRecord below_span;
		for (; x < map_width; ++x) {
			if (!is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, x, span.y, span.level)) {
				break;
			}
			const int64_t key = cell_key_4a325d(map_width, map_height, x, span.y, span.level);
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
			if (span.y > 0 && is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, x, span.y - 1, span.level)) {
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
			if (span.y < map_height - 1 && is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, x, span.y + 1, span.level)) {
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

Array runtime_zones_for_footprint(const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase) {
	Array runtime_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array scaled_coords = coordinate_phase.get("scaled_zone_coordinates", Array());
	Array zones;
	for (int32_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = Dictionary(runtime_records[index]).duplicate();
		const int32_t runtime_index = int32_t(zone.get("runtime_index", index));
		zone["runtime_zone_index"] = runtime_index;
		for (int32_t coord_index = 0; coord_index < scaled_coords.size(); ++coord_index) {
			if (Variant(scaled_coords[coord_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary coord = scaled_coords[coord_index];
			if (int32_t(coord.get("runtime_zone_index", -1)) != runtime_index) {
				continue;
			}
			zone["x_after_bbox_rescale"] = coord.get("x_after_bbox_rescale", 0);
			zone["y_after_bbox_rescale"] = coord.get("y_after_bbox_rescale", 0);
			zone["level"] = coord.get("level", 0);
			zone["runtime_size_after_bbox_rescale"] = coord.get("runtime_size_after_bbox_rescale", zone.get("source_base_size", 1));
			break;
		}
		zones.append(zone);
	}
	return zones;
}

PolygonSourceResult build_polygon_source_walks_4ccb64(const Array &runtime_zones) {
	PolygonSourceResult result;
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
			result.blocked = true;
			result.split_steps.append(step);
			break;
		}
		if ((model.nodes[size_t(located)].x == x && model.nodes[size_t(located)].y == y)
				|| (model.nodes[size_t(model.nodes[size_t(located)].pair)].x == x && model.nodes[size_t(model.nodes[size_t(located)].pair)].y == y)) {
			step["status"] = "0x4ccb64_duplicate_point_skipped";
			result.duplicate_skip_count += 1;
			result.split_steps.append(step);
			continue;
		}
		if (model.edge_side_test_4cc6f2(located, x, y)) {
			located = model.nodes[size_t(located)].previous;
			const int32_t erased = model.nodes[size_t(located)].next;
			model.erase_edge_4cc9cc(erased);
			result.edge_removal_count += 1;
		}
		const PolygonModelNode &located_node = model.nodes[size_t(located)];
		const int32_t split_primary = model.add_pair(String("split_") + String::num_int64(zone_index), located_node.x, located_node.y, located_node.payload, x, y, zone_index, located_node.has_payload, true);
		model.relink_4cc643(split_primary, located);
		model.root = split_primary;
		result.inserted_node_pair_count += 1;
		result.executed_split_count += 1;
		int32_t bridge_pair_count = 0;
		int32_t current_bridge = split_primary;
		int32_t bridge_source = located;
		for (int32_t guard = 0; guard < 64; ++guard) {
			current_bridge = model.bridge_4ccb1f(bridge_source, model.nodes[size_t(current_bridge)].pair, String("split_") + String::num_int64(zone_index) + "_bridge_" + String::num_int64(bridge_pair_count));
			bridge_pair_count += 1;
			result.inserted_bridge_pair_count += 1;
			bridge_source = model.nodes[size_t(current_bridge)].previous;
			const int32_t bridge_source_pair = model.nodes[size_t(bridge_source)].pair;
			if (model.nodes[size_t(bridge_source_pair)].previous == model.root) {
				break;
			}
			if (guard == 63) {
				result.blocked = true;
				step["status"] = "0x4ccb64_bridge_loop_guard_failed";
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
				const PolygonModelNode &cursor = model.nodes[size_t(cleanup_cursor)];
				const PolygonModelNode &previous_pair = model.nodes[size_t(model.nodes[size_t(cursor.previous)].pair)];
				const PolygonModelNode &paired = model.nodes[size_t(cursor.pair)];
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
				step["status"] = "0x4ccb64_crossing_cleanup_guard_failed";
			}
		}
		step["bridge_pair_count"] = bridge_pair_count;
		step["crossing_cleanup_scan_count"] = cleanup_scan_count;
		step["crossing_test_count"] = cleanup_test_count;
		step["crossing_collapse_count"] = cleanup_collapse_count;
		step["status"] = result.blocked ? String("0x4ccb64_guard_failed") : String("0x4ccb64_pre_crossing_inserted");
		result.split_steps.append(step);
		if (result.blocked) {
			break;
		}
	}

	result.allocated_node_pair_count = int32_t(model.nodes.size() / 2);
	result.active_node_pair_count = model.active_node_pair_count();
	result.finalized_triplet_count = result.blocked ? 0 : model.finalize_4ccdfc();
	for (const PolygonModelNode &node : model.nodes) {
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

	for (int64_t runtime_index = 0; runtime_index < runtime_zones.size(); ++runtime_index) {
		if (Variant(runtime_zones[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = Dictionary(runtime_zones[runtime_index]);
		if (int32_t(runtime.get("level", 0)) != 0) {
			continue;
		}
		SourceWalk walk;
		walk.runtime_zone_index = int32_t(runtime.get("runtime_zone_index", runtime_index));
		walk.source_zone_id = int32_t(runtime.get("source_zone_id", -1));
		walk.start_x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		walk.start_y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		const int32_t located = result.blocked ? -1 : model.locate_4cca55(walk.start_x, walk.start_y);
		if (located >= 0) {
			int32_t current = located;
			bool guard_exhausted = false;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const PolygonModelNode &node = model.nodes[size_t(current)];
				walk.cycle_nodes.push_back(SourceCycleNode { node.x, node.y, node.finalized, node.finalized_x, node.finalized_y });
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

Dictionary zone_footprint_source_nodes_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase) {
	Dictionary phase;
	phase["phase_id"] = "zone_footprint_source_nodes";
	phase["status"] = "blocked_until_coordinate_replay";
	phase["h3maped_anchor"] = "0x4a3a03";
	phase["polygon_constructor_anchor"] = "0x4cc788";
	phase["polygon_node_constructor_anchor"] = "0x4cc955";
	phase["polygon_split_anchor"] = "0x4ccb64";
	phase["polygon_finalize_anchor"] = "0x4ccdfc";
	phase["strict_port_scope"] = "source-node rectangle, split insertion, crossing cleanup, and finalized source-node cycles only; no boundary/span fill, terrain, map cells, or public output";
	phase["source"] = "h3maped 0x4a3a03 small-land source-node setup through 0x4cc788, 0x4cc955, 0x4ccb64, and 0x4ccdfc over the coordinate replay output";
	phase["materializes_private_zone_cell_buffer"] = false;
	phase["materializes_boundary_trace"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "zone_boundary_and_span_fill_0x4a2777_0x4a325d_0x4a3710";
	if (String(coordinate_phase.get("status", "")) != "active_internal_state"
			&& String(coordinate_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}
	if (level_count(normalized_config) != 1 || water_mode_code(normalized_config) != 0) {
		phase["status"] = "unsupported_scope";
		return phase;
	}

	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);

	phase["status"] = source.blocked ? String("blocked_during_source_node_split") : String("active_strict_executable_port");
	phase["level_count"] = level_count(normalized_config);
	phase["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	phase["synthetic_fallback_zone_allowed_by_0x4a3a9d"] = false;
	phase["appended_synthetic_runtime_zone_count"] = 0;
	phase["initial_bounds_min_x"] = -200;
	phase["initial_bounds_min_y"] = -200;
	phase["initial_bounds_max_x"] = 400;
	phase["initial_bounds_max_y"] = 400;
	phase["initial_node_pair_count"] = 5;
	phase["total_matching_runtime_zones"] = runtime_zones.size();
	phase["total_polygon_split_calls"] = source.executed_split_count;
	phase["split_steps"] = source.split_steps;
	phase["duplicate_skip_count"] = source.duplicate_skip_count;
	phase["edge_removal_branch_count"] = source.edge_removal_count;
	phase["pre_crossing_inserted_node_pair_count"] = source.inserted_node_pair_count;
	phase["pre_crossing_inserted_bridge_pair_count"] = source.inserted_bridge_pair_count;
	phase["crossing_cleanup_scan_count"] = source.crossing_scan_count;
	phase["crossing_test_count"] = source.crossing_test_count;
	phase["crossing_collapse_count"] = source.crossing_collapse_count;
	phase["post_crossing_cleanup_allocated_node_pair_count"] = source.allocated_node_pair_count;
	phase["post_crossing_cleanup_active_node_pair_count"] = source.active_node_pair_count;
	phase["finalized_triplet_count"] = source.finalized_triplet_count;
	phase["finalized_node_count"] = source.finalized_node_count;
	phase["active_payload_node_count"] = source.active_payload_node_count;
	phase["source_node_walk_count"] = source.source_node_walk_count;
	phase["source_node_walk_guard_exhausted_count"] = source.source_node_walk_guard_exhausted_count;
	return phase;
}

Dictionary boundary_and_span_fill_4a2777_4a325d(const Dictionary &normalized_config, const Array &runtime_zones, const PolygonSourceResult &source, uint32_t rng_state_after_coordinate_seed, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary report;
	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = level_count(normalized_config);
	const int32_t water_code = water_mode_code(normalized_config);
	const int32_t cell_count = std::max(0, map_width * map_height * std::max(1, map_level_count));
	std::vector<uint32_t> zone_words(size_t(cell_count), H3MAPED_UNASSIGNED_ZONE_WORD);
	std::vector<uint8_t> cell_flags(size_t(cell_count), 0);
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = map_width;
	bounds.max_y = map_height;

	std::map<int64_t, bool> boundary_unique_cells;
	int32_t trace_write_count = 0;
	int32_t out_of_bounds_write_count = 0;
	int32_t runtime_zone_walk_count = 0;
	int32_t blocked_zone_count = 0;
	int32_t fallback_zone_count = 0;
	int32_t connector_segment_count = 0;
	int32_t wrap_segment_count = 0;
	int32_t final_segment_count = 0;
	int32_t flagged_writer_segment_count = 0;
	int32_t deterministic_writer_segment_count = 0;
	int32_t randomized_rng_call_count = 0;
	int32_t randomized_inserted_midpoint_count = 0;
	int32_t randomized_max_pending_point_count = 0;
	bool loop_guard_exhausted = false;
	H3MapedRng rng { rng_state_after_coordinate_seed };

	auto runtime_zone_by_index = [&](int32_t runtime_zone_index) -> Dictionary {
		for (int32_t index = 0; index < runtime_zones.size(); ++index) {
			if (Variant(runtime_zones[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary runtime = runtime_zones[index];
			if (int32_t(runtime.get("runtime_zone_index", index)) == runtime_zone_index) {
				return runtime;
			}
		}
		return Dictionary();
	};
	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};
	auto merge_line = [&](const LineWriteResult &line) {
		for (const auto &item : line.unique_cells) {
			boundary_unique_cells[item.first] = true;
		}
		trace_write_count += int32_t(line.trace.size());
		out_of_bounds_write_count += line.out_of_bounds_write_count;
		apply_line_trace_to_zone_buffer_4a2777(line, zone_words, cell_flags, map_width, map_height, map_level_count);
	};
	auto append_segment = [&](int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_word, int32_t level, bool randomized, int32_t random_span_limit) {
		LineWriteResult line;
		if (randomized) {
			line = randomized_line_writer_4a2413(map_width, map_height, map_level_count, water_code, x1, y1, x2, y2, zone_word, level, random_span_limit, rng, randomized_rng_call_count, randomized_inserted_midpoint_count, randomized_max_pending_point_count);
			flagged_writer_segment_count += 1;
		} else {
			line = line_writer_4a261a(map_width, map_height, map_level_count, water_code, x1, y1, x2, y2, zone_word, level);
			deterministic_writer_segment_count += 1;
		}
		merge_line(line);
	};

	for (const SourceWalk &walk : source.walks) {
		Dictionary runtime_zone = runtime_zone_by_index(walk.runtime_zone_index);
		if (runtime_zone.is_empty()) {
			blocked_zone_count += 1;
			continue;
		}
		const int32_t zone_word = zone_word_id_for_runtime_zone(runtime_zone);
		const int32_t level = int32_t(runtime_zone.get("level", 0));
		const bool flagged_branch = !(map_level_count == 2 && level != 1);
		const int32_t random_span_limit = std::max<int32_t>(1, int32_t(runtime_zone.get("runtime_size_after_bbox_rescale", runtime_zone.get("source_base_size", 1))));
		std::vector<PolygonPoint> finalized_points;
		for (const SourceCycleNode &node : walk.cycle_nodes) {
			if (node.finalized) {
				finalized_points.push_back(PolygonPoint { node.finalized_x, node.finalized_y });
			}
		}
		if (finalized_points.size() < 2) {
			blocked_zone_count += 1;
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
			continue;
		}
		append_segment(clipped_current.x, clipped_current.y, clipped_target.x, clipped_target.y, zone_word, level, flagged_branch, random_span_limit);
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
				continue;
			}
			int32_t wrap_guard = 0;
			while (current_x != next_clip.x && current_y != next_clip.y && point_on_clip_border(current_x, current_y) && point_on_clip_border(next_clip.x, next_clip.y) && wrap_guard < 8) {
				int32_t border_x = current_x;
				int32_t border_y = current_y;
				if (current_x == bounds.min_x) {
					if (current_y == bounds.min_y) {
						border_x = right_x;
						border_y = bounds.min_y;
					} else {
						border_x = bounds.min_x;
						border_y = bounds.min_y;
					}
				} else if (current_y == bounds.min_y) {
					border_x = right_x;
					border_y = bounds.min_y;
				} else if (current_x == right_x && current_y != bottom_y) {
					border_x = right_x;
					border_y = bottom_y;
				} else {
					border_x = bounds.min_x;
					border_y = bottom_y;
				}
				append_segment(current_x, current_y, border_x, border_y, zone_word, level, false, random_span_limit);
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
				append_segment(current_x, current_y, next_clip.x, next_clip.y, zone_word, level, false, random_span_limit);
				current_x = next_clip.x;
				current_y = next_clip.y;
				final_segment_count += 1;
			}
			if (source_index == selected_segment_index) {
				break;
			}
		}
		runtime_zone_walk_count += 1;
	}

	std::map<int64_t, bool> unique_filled_cells;
	int32_t filled_zone_count = 0;
	int32_t seed_blocked_count = 0;
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
		const int32_t zone_word = zone_word_id_for_runtime_zone(runtime);
		SpanRecord seed;
		seed.x = int32_t(runtime.get("x_after_bbox_rescale", 0));
		seed.y = int32_t(runtime.get("y_after_bbox_rescale", 0));
		seed.level = int32_t(runtime.get("level", 0));
		if (!span_cell_in_bounds_4a325d(map_width, map_height, map_level_count, seed)) {
			seed_blocked_count += 1;
			continue;
		}
		if (!is_unassigned_zone_word_4a325d(zone_words, map_width, map_height, seed.x, seed.y, seed.level)) {
			seed_blocked_count += 1;
		}
		SpanFillResult fill = span_fill_4a325d(zone_words, cell_flags, map_width, map_height, map_level_count, water_code, zone_word, seed);
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
	}

	int32_t remaining_unassigned_count = 0;
	int32_t boundary_or_filled_count = 0;
	int32_t reserved_cell_count = 0;
	std::map<int32_t, int32_t> cells_by_zone_word;
	for (int32_t level = 0; level < map_level_count; ++level) {
		for (int32_t y = 0; y < map_height; ++y) {
			for (int32_t x = 0; x < map_width; ++x) {
				const int64_t key = cell_key_4a325d(map_width, map_height, x, y, level);
				if ((cell_flags[size_t(key)] & 0x10U) != 0) {
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

	report["boundary_status"] = "0x4a2777_private_boundary_materialized";
	report["runtime_zone_walk_count"] = runtime_zone_walk_count;
	report["blocked_zone_count"] = blocked_zone_count;
	report["fallback_zone_count"] = fallback_zone_count;
	report["connector_segment_count"] = connector_segment_count;
	report["wrap_segment_count"] = wrap_segment_count;
	report["final_segment_count"] = final_segment_count;
	report["flagged_writer_segment_count"] = flagged_writer_segment_count;
	report["deterministic_writer_segment_count"] = deterministic_writer_segment_count;
	report["randomized_rng_call_count"] = randomized_rng_call_count;
	report["randomized_inserted_midpoint_count"] = randomized_inserted_midpoint_count;
	report["randomized_max_pending_point_count"] = randomized_max_pending_point_count;
	report["rng_state_after_0x4a2777_uint32"] = int64_t(rng.state);
	report["trace_write_count"] = trace_write_count;
	report["unique_boundary_cell_count"] = int32_t(boundary_unique_cells.size());
	report["out_of_bounds_write_count"] = out_of_bounds_write_count;
	report["loop_guard_exhausted"] = loop_guard_exhausted;
	report["span_fill_status"] = "0x4a325d_private_span_fill_materialized";
	report["filled_zone_count"] = filled_zone_count;
	report["seed_blocked_count"] = seed_blocked_count;
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
	if (zone_words_out != nullptr) {
		*zone_words_out = zone_words;
	}
	if (cell_flags_out != nullptr) {
		*cell_flags_out = cell_flags;
	}
	return report;
}

Dictionary zone_boundary_and_span_fill_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &source_node_phase) {
	Dictionary phase;
	phase["phase_id"] = "zone_boundary_and_span_fill";
	phase["status"] = "blocked_until_source_nodes";
	phase["boundary_traversal_anchor"] = "0x4a2777";
	phase["clip_helper_anchor"] = "0x4a2b33";
	phase["deterministic_line_writer_anchor"] = "0x4a261a";
	phase["randomized_line_writer_anchor"] = "0x4a2413";
	phase["span_fill_anchor"] = "0x4a325d";
	phase["strict_port_scope"] = "source-node boundary traversal and private span-fill zone buffer only; no finalizer, terrain, map cells, or public output";
	phase["source"] = "h3maped 0x4a2777 traversal over finalized source-node cycles plus 0x4a325d private span fill; 0x4a3710 ordering/finalizer remains pending";
	phase["materializes_private_zone_cell_buffer"] = false;
	phase["materializes_boundary_trace"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "zone_footprint_finalizer_0x4a3710";
	if (String(source_node_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}
	if (level_count(normalized_config) != 1 || water_mode_code(normalized_config) != 0) {
		phase["status"] = "unsupported_scope";
		return phase;
	}

	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	if (source.blocked) {
		phase["status"] = "blocked_during_source_node_split";
		return phase;
	}

	Dictionary fill = boundary_and_span_fill_4a2777_4a325d(
			normalized_config,
			runtime_zones,
			source,
			uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))));
	phase["status"] = "active_strict_executable_port";
	phase["boundary_status"] = fill.get("boundary_status", "");
	phase["boundary_runtime_zone_walk_count"] = fill.get("runtime_zone_walk_count", 0);
	phase["boundary_blocked_zone_count"] = fill.get("blocked_zone_count", 0);
	phase["boundary_fallback_zone_count"] = fill.get("fallback_zone_count", 0);
	phase["boundary_connector_segment_count"] = fill.get("connector_segment_count", 0);
	phase["boundary_wrap_segment_count"] = fill.get("wrap_segment_count", 0);
	phase["boundary_final_segment_count"] = fill.get("final_segment_count", 0);
	phase["boundary_flagged_writer_segment_count"] = fill.get("flagged_writer_segment_count", 0);
	phase["boundary_deterministic_writer_segment_count"] = fill.get("deterministic_writer_segment_count", 0);
	phase["boundary_randomized_rng_call_count"] = fill.get("randomized_rng_call_count", 0);
	phase["boundary_randomized_inserted_midpoint_count"] = fill.get("randomized_inserted_midpoint_count", 0);
	phase["boundary_randomized_max_pending_point_count"] = fill.get("randomized_max_pending_point_count", 0);
	phase["boundary_rng_state_after_0x4a2777_uint32"] = fill.get("rng_state_after_0x4a2777_uint32", 0);
	phase["boundary_trace_write_count"] = fill.get("trace_write_count", 0);
	phase["boundary_unique_cell_count"] = fill.get("unique_boundary_cell_count", 0);
	phase["boundary_out_of_bounds_write_count"] = fill.get("out_of_bounds_write_count", 0);
	phase["boundary_loop_guard_exhausted"] = fill.get("loop_guard_exhausted", false);
	phase["span_fill_status"] = fill.get("span_fill_status", "");
	phase["span_fill_filled_zone_count"] = fill.get("filled_zone_count", 0);
	phase["span_fill_seed_blocked_count"] = fill.get("seed_blocked_count", 0);
	phase["span_fill_unique_filled_cell_count"] = fill.get("total_unique_filled_cell_count", 0);
	phase["span_fill_boundary_or_filled_cell_count"] = fill.get("total_boundary_or_filled_cell_count", 0);
	phase["span_fill_remaining_unassigned_cell_count"] = fill.get("remaining_unassigned_cell_count", 0);
	phase["span_fill_reserved_cell_count"] = fill.get("reserved_cell_count", 0);
	phase["span_fill_pushed_span_count"] = fill.get("pushed_span_count", 0);
	phase["span_fill_popped_span_count"] = fill.get("popped_span_count", 0);
	phase["span_fill_max_pending_span_count"] = fill.get("max_pending_span_count", 0);
	phase["span_fill_out_of_bounds_span_count"] = fill.get("out_of_bounds_span_count", 0);
	phase["span_fill_blocked_initial_span_count"] = fill.get("blocked_initial_span_count", 0);
	phase["cells_by_zone_word"] = fill.get("cells_by_zone_word", Array());
	phase["materializes_private_zone_cell_buffer"] = true;
	phase["materializes_boundary_trace"] = true;
	phase["materializes_span_fill"] = true;
	return phase;
}

Dictionary zone_footprint_finalizer_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &source_node_phase, const Dictionary &span_fill_phase) {
	Dictionary phase;
	phase["phase_id"] = "zone_footprint_finalizer";
	phase["status"] = "blocked_until_span_fill";
	phase["h3maped_anchor"] = "0x4a3710";
	phase["call_site_anchor"] = "0x4a3efc..0x4a3f05";
	phase["polygon_locator_anchor"] = "0x4cca55";
	phase["clip_helper_anchor"] = "0x4a2b33";
	phase["zone_order_reset_anchor"] = "0x49b61b";
	phase["per_zone_order_helper_anchor"] = "0x4a3554";
	phase["adjacency_vector_offset"] = "runtime_zone+0xc4";
	phase["ordering_vector_offset"] = "runtime_zone+0x3e8";
	phase["strict_port_scope"] = "small-land no-appended-zone footprint finalizer: skip appended adjacency insertion, schedule zone ordering reset and per-zone rebuild only";
	phase["source"] = "h3maped 0x4a3710 footprint adjacency finalizer; small one-level land has no appended synthetic runtime zones, so adjacency insertion loops skip and only ordering reset/rebuild calls execute";
	phase["materializes_adjacency"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "runtime_terrain_selection_0x49b53d";
	if (String(span_fill_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}

	Array runtime_zone_records = runtime_zone_phase.get("runtime_zone_records", Array());
	const int32_t original_same_level_runtime_zone_count = int32_t(source_node_phase.get("total_matching_runtime_zones", runtime_zone_records.size()));
	const int32_t final_runtime_zone_count = runtime_zone_records.size();
	const int32_t appended_runtime_zone_count = std::max(0, final_runtime_zone_count - original_same_level_runtime_zone_count);
	const bool synthetic_branch_allowed = level_count(normalized_config) > 1 || water_mode_code(normalized_config) != 0;

	phase["status"] = appended_runtime_zone_count == 0
			? String("active_strict_executable_port")
			: String("blocked_appended_zone_adjacency_schema_pending");
	phase["h3maped_status"] = appended_runtime_zone_count == 0
			? String("0x4a3710_small_land_no_appended_zone_finalizer_ported")
			: String("0x4a3710_appended_zone_adjacency_finalizer_blocked");
	phase["level_count"] = level_count(normalized_config);
	phase["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	phase["synthetic_branch_allowed_by_0x4a3a9d"] = synthetic_branch_allowed;
	phase["original_same_level_runtime_zone_count"] = original_same_level_runtime_zone_count;
	phase["final_runtime_zone_count"] = final_runtime_zone_count;
	phase["appended_runtime_zone_count"] = appended_runtime_zone_count;

	Array recovered_operations;
	recovered_operations.append("iterates runtime zones from the level's original collected count to the current runtime-zone count");
	recovered_operations.append("finds the source polygon/list node containing each runtime zone rectangle origin through 0x4cca55");
	recovered_operations.append("clips candidate source edges through 0x4a2b33 and rejects endpoints outside map bounds");
	recovered_operations.append("adds bidirectional adjacency records into runtime_zone+0xc4 vectors only for appended synthetic zones");
	recovered_operations.append("resets each runtime zone ordering vector with 0x49b61b, then rebuilds per-zone ordering/depth state with 0x4a3554");
	phase["recovered_operations"] = recovered_operations;

	Array finalizer_phases;
	Dictionary initial_insert_phase;
	initial_insert_phase["address_range"] = "0x4a3735..0x4a3874";
	initial_insert_phase["start_index"] = original_same_level_runtime_zone_count;
	initial_insert_phase["end_index"] = final_runtime_zone_count;
	initial_insert_phase["status"] = appended_runtime_zone_count == 0 ? String("skipped_no_appended_runtime_zones") : String("blocked_appended_runtime_zone_adjacency_schema_pending");
	initial_insert_phase["materialized_adjacency_insert_count"] = 0;
	finalizer_phases.append(initial_insert_phase);

	Dictionary order_reset_phase;
	order_reset_phase["address_range"] = "0x4a3879..0x4a38be";
	order_reset_phase["zone_order_reset_call_count"] = final_runtime_zone_count;
	order_reset_phase["per_zone_order_helper_call_count"] = original_same_level_runtime_zone_count;
	order_reset_phase["status"] = "0x49b61b_reset_and_0x4a3554_rebuild_scheduled";
	finalizer_phases.append(order_reset_phase);

	Dictionary ordered_insert_phase;
	ordered_insert_phase["address_range"] = "0x4a38be..0x4a39fc";
	ordered_insert_phase["start_index"] = original_same_level_runtime_zone_count;
	ordered_insert_phase["end_index"] = final_runtime_zone_count;
	ordered_insert_phase["status"] = appended_runtime_zone_count == 0 ? String("skipped_no_appended_runtime_zones") : String("blocked_ordered_appended_adjacency_schema_pending");
	ordered_insert_phase["materialized_adjacency_insert_count"] = 0;
	finalizer_phases.append(ordered_insert_phase);

	phase["phases"] = finalizer_phases;
	phase["zone_order_reset_call_count"] = final_runtime_zone_count;
	phase["per_zone_order_helper_call_count"] = original_same_level_runtime_zone_count;
	phase["materialized_adjacency_count"] = 0;
	return phase;
}

String project_terrain_for_h3maped_id(int32_t terrain_id) {
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
			return "subterranean";
		case 7:
			return "lava";
		case 8:
			return "water";
		default:
			return "unknown";
	}
}

Dictionary runtime_terrain_selection_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &footprint_finalizer_phase) {
	static constexpr int32_t H3_TOWN_TO_TERRAIN_TABLE_540908[9] = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	Dictionary phase;
	phase["phase_id"] = "runtime_terrain_selection";
	phase["status"] = "blocked_until_footprint_finalizer";
	phase["h3maped_anchor"] = "0x49b53d";
	phase["town_to_terrain_table_address"] = "0x540908";
	phase["allowed_terrain_flags_source"] = "source_zone+0x85..0x8c";
	phase["rng_state_before_0x49b53d_uint32"] = coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0);
	phase["strict_port_scope"] = "runtime-zone terrain id selection only; no terrain cell writeout, TerrainPlacement art, map cells, package tiles, or public output";
	phase["materializes_runtime_zone_terrain_ids"] = false;
	phase["materializes_terrain_cells"] = false;
	phase["materializes_terrain_art"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_package_tiles"] = false;
	phase["materializes_public_output"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "terrain_cell_writeout_0x4a3f27";

	Array town_table;
	for (int32_t index = 0; index < int32_t(sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908) / sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908[0])); ++index) {
		town_table.append(H3_TOWN_TO_TERRAIN_TABLE_540908[index]);
	}
	phase["town_choice_to_terrain_table"] = town_table;

	if (String(runtime_zone_phase.get("status", "")) != "active_strict_executable_port"
			|| String(coordinate_phase.get("status", "")) != "active_strict_executable_port"
			|| String(footprint_finalizer_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}

	H3MapedRng rng { uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))) };
	Array runtime_records = coordinate_phase.get("runtime_zone_records_after_0x49b3c1", Array());
	Array selections;
	Array selected_ids;
	Array selected_names;
	int32_t rng_call_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t blank_allowed_mask_count = 0;
	int32_t forced_subterranean_count = 0;

	for (int32_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[index];
		Dictionary selection;
		const int32_t runtime_zone_index = int32_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", index)));
		const int32_t runtime_level = int32_t(runtime.get("level", 0));
		const bool match_to_town = bool(runtime.get("terrain_match_to_town", false));
		const int32_t town_choice_index = int32_t(runtime.get("town_choice_index", runtime.get("town_choice_index_49b3c1", -1)));
		selection["runtime_zone_index"] = runtime_zone_index;
		selection["level"] = runtime_level;
		selection["terrain_match_to_town"] = match_to_town;
		selection["town_choice_index"] = town_choice_index;
		selection["faction_id"] = runtime.get("faction_id", runtime.get("selected_faction_id_49b3c1", ""));

		int32_t selected_terrain = 0;
		String source = "0x49b57d_0x49b584_no_eligible_flags_defaults_zero";
		if (match_to_town && town_choice_index >= 0 && town_choice_index < int32_t(sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908) / sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908[0]))) {
			selected_terrain = H3_TOWN_TO_TERRAIN_TABLE_540908[town_choice_index];
			source = "0x49b54c_0x49b55b_match_to_town_table_0x540908";
			match_to_town_count += 1;
		} else {
			Array allowed = runtime.get("allowed_h3maped_terrain_ids_for_49b53d", Array());
			Array eligible_ids;
			Array eligible_names;
			for (int32_t allowed_index = 0; allowed_index < allowed.size(); ++allowed_index) {
				const int32_t h3_id = int32_t(allowed[allowed_index]);
				if (h3_id < 0 || h3_id > 7) {
					continue;
				}
				if (h3_id == 6 && runtime_level != 1) {
					continue;
				}
				eligible_ids.append(h3_id);
				eligible_names.append(project_terrain_for_h3maped_id(h3_id));
			}
			if (eligible_ids.is_empty()) {
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
		if (runtime_level == 1 && selected_terrain != 7) {
			selected_terrain = 6;
			forced_subterranean_count += 1;
			selection["forced_subterranean_branch"] = "0x49b5b7_0x49b5c3_level_1_non_lava_forces_terrain_6";
		}

		selection["selected_h3maped_terrain_id"] = selected_terrain;
		selection["selected_project_terrain_id"] = project_terrain_for_h3maped_id(selected_terrain);
		selection["source"] = source;
		selections.append(selection);
		selected_ids.append(selected_terrain);
		selected_names.append(project_terrain_for_h3maped_id(selected_terrain));
	}

	phase["status"] = "active_strict_executable_port";
	phase["source"] = "h3maped 0x49b53d runtime terrain selection over the 0x49b3c1 town choices and source-zone allowed terrain flags";
	phase["materializes_runtime_zone_terrain_ids"] = true;
	phase["selection_count"] = selections.size();
	phase["selections"] = selections;
	phase["selected_h3maped_terrain_ids"] = selected_ids;
	phase["selected_project_terrain_ids"] = selected_names;
	phase["match_to_town_count"] = match_to_town_count;
	phase["allowed_flag_choice_count"] = allowed_flag_choice_count;
	phase["blank_allowed_mask_count"] = blank_allowed_mask_count;
	phase["forced_subterranean_count"] = forced_subterranean_count;
	phase["terrain_rng_call_count"] = rng_call_count;
	phase["rng_state_after_0x49b53d_uint32"] = int64_t(rng.state);
	return phase;
}

Dictionary terrain_cell_writeout_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &source_node_phase, const Dictionary &runtime_terrain_phase) {
	Dictionary phase;
	phase["phase_id"] = "terrain_cell_writeout";
	phase["status"] = "blocked_until_runtime_terrain_selection";
	phase["h3maped_anchor"] = "0x4a3f27";
	phase["full_map_water_prefill_anchor"] = "0x4a4025";
	phase["runtime_zone_scan_anchor"] = "0x4a4082";
	phase["per_cell_repaint_anchor"] = "0x4a415a";
	phase["span_fill_anchor"] = "0x4a325d";
	phase["runtime_terrain_selection_anchor"] = "0x49b53d";
	phase["strict_port_scope"] = "private generated-cell terrain code writeout only; no TerrainPlacement art/index/flip, roads, objects, map cells, package tiles, or public output";
	phase["materializes_private_terrain_cell_buffer"] = false;
	phase["materializes_terrain_art"] = false;
	phase["materializes_roads"] = false;
	phase["materializes_objects"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_package_tiles"] = false;
	phase["materializes_public_output"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "terrainplacement_visual_tables_0x4bcff5";
	if (String(runtime_terrain_phase.get("status", "")) != "active_strict_executable_port"
			|| String(source_node_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}

	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	if (source.blocked) {
		phase["status"] = "blocked_during_source_node_split";
		return phase;
	}

	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary fill = boundary_and_span_fill_4a2777_4a325d(
			normalized_config,
			runtime_zones,
			source,
			uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))),
			&zone_words,
			&cell_flags);

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = level_count(normalized_config);
	const int32_t tile_count = std::max(0, map_width * map_height * std::max(1, map_level_count));
	Array selected_terrain_ids = runtime_terrain_phase.get("selected_h3maped_terrain_ids", Array());
	std::vector<int32_t> runtime_zone_terrain_ids(size_t(runtime_zones.size()), 8);
	for (int32_t index = 0; index < selected_terrain_ids.size() && index < int32_t(runtime_zone_terrain_ids.size()); ++index) {
		runtime_zone_terrain_ids[size_t(index)] = int32_t(selected_terrain_ids[index]);
	}

	std::map<int32_t, int32_t> owner_low_byte_counts;
	std::map<int32_t, int32_t> terrain_code_counts;
	std::map<String, int32_t> terrain_project_counts;
	terrain_code_counts[8] = tile_count;
	terrain_project_counts["water"] = tile_count;
	int32_t assigned_owner_cell_count = 0;
	int32_t unassigned_water_cell_count = 0;
	int32_t reserved_cell_count = 0;
	for (int32_t cell_index = 0; cell_index < tile_count && cell_index < int32_t(zone_words.size()); ++cell_index) {
		if ((cell_flags[size_t(cell_index)] & 0x10U) != 0) {
			reserved_cell_count += 1;
		}
		const uint32_t zone_word = zone_words[size_t(cell_index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD) {
			unassigned_water_cell_count += 1;
			continue;
		}
		const int32_t owner_byte = int32_t((zone_word >> 16U) & 0xffU);
		if (owner_byte < 0 || owner_byte >= int32_t(runtime_zone_terrain_ids.size())) {
			continue;
		}
		const int32_t terrain_id = runtime_zone_terrain_ids[size_t(owner_byte)];
		const String project_terrain = project_terrain_for_h3maped_id(terrain_id);
		assigned_owner_cell_count += 1;
		owner_low_byte_counts[owner_byte] += 1;
		terrain_code_counts[8] -= 1;
		terrain_project_counts["water"] -= 1;
		terrain_code_counts[terrain_id] += 1;
		terrain_project_counts[project_terrain] += 1;
	}

	Array owner_counts_report;
	for (const auto &item : owner_low_byte_counts) {
		Dictionary entry;
		entry["owner_low_byte"] = item.first;
		entry["cell_count"] = item.second;
		owner_counts_report.append(entry);
	}
	Array terrain_code_counts_report;
	for (const auto &item : terrain_code_counts) {
		Dictionary entry;
		entry["h3maped_terrain_id"] = item.first;
		entry["cell_count"] = item.second;
		terrain_code_counts_report.append(entry);
	}
	Dictionary terrain_project_counts_report;
	for (const auto &item : terrain_project_counts) {
		terrain_project_counts_report[item.first] = item.second;
	}

	phase["status"] = "active_strict_executable_port";
	phase["source"] = "h3maped 0x4a3f27 private terrain cell writeout over the real 0x4a325d zone-word buffer and 0x49b53d runtime terrain selections";
	phase["selected_h3maped_terrain_ids"] = runtime_terrain_phase.get("selected_h3maped_terrain_ids", Array());
	phase["selected_project_terrain_ids"] = runtime_terrain_phase.get("selected_project_terrain_ids", Array());
	phase["terrain_rng_call_count"] = runtime_terrain_phase.get("terrain_rng_call_count", 0);
	phase["rng_state_before_0x49b53d_uint32"] = runtime_terrain_phase.get("rng_state_before_0x49b53d_uint32", 0);
	phase["rng_state_after_0x49b53d_uint32"] = runtime_terrain_phase.get("rng_state_after_0x49b53d_uint32", 0);
	phase["tile_count"] = tile_count;
	phase["full_map_water_prefill_cell_count"] = tile_count;
	phase["private_zone_word_cell_count"] = int32_t(zone_words.size());
	phase["assigned_owner_cell_count"] = assigned_owner_cell_count;
	phase["zone_repaint_cell_count"] = assigned_owner_cell_count;
	phase["unassigned_water_cell_count"] = unassigned_water_cell_count;
	phase["reserved_cell_count"] = reserved_cell_count;
	phase["span_fill_boundary_or_filled_cell_count"] = fill.get("total_boundary_or_filled_cell_count", 0);
	phase["owner_low_byte_counts"] = owner_counts_report;
	phase["terrain_code_counts"] = terrain_code_counts_report;
	phase["terrain_project_counts"] = terrain_project_counts_report;
	phase["materializes_private_terrain_cell_buffer"] = true;
	return phase;
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
		rows.push_back(TerrainVisualRow { int32_t(shape_class), int32_t(flag_a), int32_t(flag_b) });
	}
	return rows;
}

Dictionary terrain_visual_table_summary(const char *id, const char *terrain_ids, const char *address, int64_t table_va, int32_t expected_row_count, const std::vector<TerrainVisualRow> &rows) {
	Dictionary summary;
	summary["id"] = id;
	summary["terrain_ids"] = terrain_ids;
	summary["table_address"] = address;
	summary["table_file_offset"] = h3maped_va_to_file_offset(table_va);
	summary["expected_row_count"] = expected_row_count;
	summary["decoded_row_count"] = int32_t(rows.size());
	summary["row_stride_bytes"] = 8;
	summary["row_contract"] = "u32 class, u8 flag_a, u8 flag_b";
	std::map<int32_t, int32_t> class_counts;
	for (const TerrainVisualRow &row : rows) {
		class_counts[row.shape_class] += 1;
	}
	Array class_records;
	for (const auto &entry : class_counts) {
		Dictionary record;
		record["class"] = entry.first;
		record["row_count"] = entry.second;
		class_records.append(record);
	}
	summary["unique_class_count"] = int32_t(class_counts.size());
	summary["class_counts"] = class_records;
	summary["status"] = int32_t(rows.size()) == expected_row_count ? String("decoded_from_h3maped_exe") : String("decode_failed");
	return summary;
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
	H3MapedRng rng { seed };
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
	Dictionary sample;
	sample["id"] = id;
	sample["selector_address"] = selector_address;
	sample["table_address"] = table_address;
	sample["selector_kind"] = selector_kind;
	sample["class"] = shape_class;
	sample["flag_a"] = flag_a;
	sample["flag_b"] = flag_b;
	sample["rng_seed_uint32"] = int64_t(seed);
	sample["probability_rng_value"] = probability_rng_value;
	sample["probability_threshold"] = probability_threshold;
	sample["selected_special_bucket"] = selected_special_bucket;
	sample["bucket_count"] = int32_t(bucket.size());
	if (bucket.empty()) {
		sample["status"] = "missing_visual_row_bucket";
		return sample;
	}
	const int32_t art_rng_value = rng.next();
	const int32_t selected_row = bucket[size_t(art_rng_value % int32_t(bucket.size()))];
	sample["status"] = "visual_row_selected_from_decoded_h3maped_table";
	sample["art_rng_value"] = art_rng_value;
	sample["selected_row"] = selected_row;
	sample["out_flag_a"] = rock_selector ? 0 : flag_a;
	sample["out_flag_b"] = rock_selector ? 0 : flag_b;
	sample["rng_state_after_uint32"] = int64_t(rng.state);
	return sample;
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
	const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU) | ((uint32_t(selected_row) & 0xffU) << 6U);
	const uint32_t generated_cell_word_0x28 = ((uint32_t(flag_a) & 0x01U) << 15U) | ((uint32_t(flag_b) & 0x01U) << 16U);
	Dictionary sample;
	sample["id"] = id;
	sample["terrain_id"] = terrain_id;
	sample["selected_row"] = selected_row;
	sample["flag_a"] = flag_a;
	sample["flag_b"] = flag_b;
	sample["scratch_word_u16"] = int32_t(scratch_word);
	sample["generated_cell_word_0x24_u32"] = int64_t(generated_cell_word_0x24);
	sample["generated_cell_word_0x28_u32"] = int64_t(generated_cell_word_0x28);
	sample["tile_byte_0_terrain_id"] = int32_t(generated_cell_word_0x24 & 0x3fU);
	sample["tile_byte_1_terrain_art"] = int32_t((generated_cell_word_0x24 >> 6U) & 0xffU);
	sample["tile_byte_6_terrain_flags"] = int32_t((generated_cell_word_0x28 >> 15U) & 0x03U);
	return sample;
}

Dictionary terrainplacement_visual_tables_phase(const Dictionary &terrain_cell_phase) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_visual_tables";
	phase["h3maped_anchor"] = "0x4bcff5";
	phase["terrainplacement_constructor_address"] = "0x4bb5ce";
	phase["terrainplacement_wrapper_address"] = "0x4bd099";
	phase["changed_cell_update_address"] = "0x4bb74b";
	phase["queue_drain_address"] = "0x4bc5f0";
	phase["visual_selector_address"] = "0x4bcfc3";
	phase["neighbor_mask_address"] = "0x4bce6d";
	phase["toolkit_table_address"] = "0x5436b8";
	phase["complex_toolkit_vtable_address"] = "0x543780";
	phase["simple_toolkit_vtable_address"] = "0x54379c";
	phase["complex_visual_resolve_vfunc_plus_0x10"] = "0x4ba938";
	phase["complex_visual_writeback_vfunc_plus_0x14"] = "0x4ba989";
	phase["simple_visual_resolve_vfunc_plus_0x10"] = "0x4baa94";
	phase["simple_visual_writeback_vfunc_plus_0x14"] = "0x4baabf";
	phase["status"] = "blocked_until_terrain_cell_writeout";
	phase["terrain_art_hash_fallback_allowed"] = false;
	phase["materializes_visual_record"] = false;
	phase["materializes_visual_records"] = false;
	phase["materializes_full_terrain_art_grid"] = false;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "terrainplacement_live_feedback_0x4bb74b_0x4bc5f0";
	if (String(terrain_cell_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}
	if (!FileAccess::file_exists(BINARY_PATH)) {
		phase["status"] = "h3maped_exe_missing";
		return phase;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		phase["status"] = "h3maped_exe_unreadable";
		return phase;
	}

	const std::vector<TerrainVisualRow> normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	const std::vector<TerrainVisualRow> dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
	const std::vector<TerrainVisualRow> sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
	const std::vector<TerrainVisualRow> water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	const std::vector<TerrainVisualRow> rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);

	Array table_summaries;
	table_summaries.append(terrain_visual_table_summary("normal_land_terrain_ids_2_7", "2,3,4,5,6,7", "0x543108", 0x543108, 79, normal_rows));
	table_summaries.append(terrain_visual_table_summary("dirt_terrain_id_0", "0", "0x543380", 0x543380, 46, dirt_rows));
	table_summaries.append(terrain_visual_table_summary("sand_terrain_id_1", "1", "0x5434f0", 0x5434f0, 24, sand_rows));
	table_summaries.append(terrain_visual_table_summary("water_terrain_id_8", "8", "0x5435b0", 0x5435b0, 33, water_rows));
	table_summaries.append(terrain_visual_table_summary("rock_terrain_id_9", "9", "0x542f88", 0x542f88, 48, rock_rows));
	const int32_t decoded_total = int32_t(normal_rows.size() + dirt_rows.size() + sand_rows.size() + water_rows.size() + rock_rows.size());

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

	Array row_selection_samples;
	row_selection_samples.append(terrain_row_selection_sample("normal_full_grass_seed_1", "0x4ba938", "0x543108", "normal_full_native_special_frequency", normal_rows, 0, 0, 0, 0x32, true, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("normal_transition_class_28_seed_1", "0x4ba989", "0x543108", "normal_transition_class_bucket", normal_rows, 28, 1, 0, 0x50, false, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("water_transition_class_16_seed_1", "0x4ba989", "0x5435b0", "water_normal_trait_transition_class_bucket", water_rows, 16, 0, 0, 0x00, false, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("rock_class_8_flag_1_0_seed_1", "0x4baabf", "0x542f88", "rock_class_flag_bucket", rock_rows, 8, 1, 0, 0x00, false, true, 1));

	Array scratch_samples;
	scratch_samples.append(terrain_scratch_write_sample("grass_full_row_60_flags_0_0", 2, 60, 0, 0));
	scratch_samples.append(terrain_scratch_write_sample("grass_class_28_row_77_flags_1_0", 2, 77, 1, 0));
	scratch_samples.append(terrain_scratch_write_sample("water_class_16_row_20_flags_0_0", 8, 20, 0, 0));
	scratch_samples.append(terrain_scratch_write_sample("rock_class_8_row_11_cleared_flags", 9, 11, 0, 0));

	phase["status"] = decoded_total == 230 ? String("active_strict_executable_port") : String("visual_table_decode_failed");
	phase["source"] = "h3maped 0x4bcff5 TerrainPlacement visual table/toolkit boundary decoded directly from /root/Downloads/h3maped.exe; no hashed terrain art approximation and no public package adoption";
	phase["strict_port_scope"] = "static TerrainPlacement visual row/toolkit metadata and bounded selector/scratch samples only; no live repaint feedback, map cells, package tiles, or public output";
	phase["table_count"] = table_summaries.size();
	phase["visual_table_count"] = table_summaries.size();
	phase["decoded_total_row_count"] = decoded_total;
	phase["total_visual_row_count"] = decoded_total;
	phase["expected_total_row_count"] = 230;
	phase["tables"] = table_summaries;
	phase["toolkit_constructor_records"] = constructor_records;
	phase["toolkit_constructor_record_count"] = constructor_records.size();
	phase["visual_row_selection_sample_count"] = row_selection_samples.size();
	phase["visual_row_selection_samples"] = row_selection_samples;
	phase["scratch_write_address"] = "0x4bad0f";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["scratch_word_contract"] = "bit0 dirty, bits1..4 terrain id, bits5..11 terrain art row, bit12 flag A, bit13 flag B";
	phase["generated_cell_contract"] = "cell+0x24 bits0..5 terrain id, bits6..13 terrain art; cell+0x28 bits15..16 terrain flags";
	phase["scratch_write_sample_count"] = scratch_samples.size();
	phase["scratch_write_samples"] = scratch_samples;
	phase["blocked_next"] = "terrainplacement_live_feedback_0x4bb74b_0x4bc5f0";
	return phase;
}

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
	if (center_terrain_id == neighbor_terrain_id || center_terrain_id == 1) {
		return 0;
	}
	if (terrain_trait_flag4(center_terrain_id) == 0 || terrain_trait_flag4(neighbor_terrain_id) == 0) {
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot, true); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(3) == 1) {
			return { 0x05, a, b };
		}
		if (r(3) == 2) {
			return { 0x0b, a, b };
		}
	}
	return { 0x00, 0, 0 };
}

int32_t terrain_at_grid_index(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * map_width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size())) {
		return fallback_terrain_id;
	}
	return terrain_codes[size_t(index)];
}

bool set_terrain_at_grid_index(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return false;
	}
	const int32_t index = level * level_tile_count + y * map_width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size()) || terrain_codes[size_t(index)] == terrain_id) {
		return false;
	}
	terrain_codes[size_t(index)] = terrain_id;
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

std::array<int32_t, 8> h3maped_same_terrain_mask_4bc74c(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	std::array<int32_t, 8> mask = { 0, 0, 0, 0, 0, 0, 0, 0 };
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		return nx >= 0 && ny >= 0 && nx < map_width && ny < map_height && terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, nx, ny, -1) == terrain_id;
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

bool h3maped_same_class_region_gate_4bc928(const std::array<int32_t, 8> &mask) {
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

bool h3maped_horizontal_pair_gate_4bc674(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= map_width - 1 || y < 0 || y >= map_height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool h3maped_vertical_pair_gate_4bc6e0(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= map_height - 1 || x < 0 || x >= map_width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool h3maped_toolkit_byte5_allows_same_class_gate(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool h3maped_candidate_gate_4bc988_grid(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928(h3maped_same_terrain_mask_4bc74c(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id));
	return horizontal_pair_gate || vertical_pair_gate || (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && same_class_region_gate);
}

int32_t h3maped_frontier_retouch_4bbd01(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, Array *sample_records, int32_t sample_limit, std::vector<int64_t> *changed_keys_out = nullptr) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](const char *branch, int32_t target_x, int32_t target_y) {
		const bool changed = set_terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, target_x, target_y, terrain_id);
		if (changed) {
			changed_count += 1;
			if (changed_keys_out != nullptr) {
				changed_keys_out->push_back(h3maped_grid_key(level, target_x, target_y));
			}
		}
		if (sample_records != nullptr && sample_records->size() < sample_limit) {
			Dictionary sample;
			sample["branch"] = branch;
			sample["from_x"] = x;
			sample["from_y"] = y;
			sample["target_x"] = target_x;
			sample["target_y"] = target_y;
			sample["terrain_id"] = terrain_id;
			sample["changed_terrain"] = changed;
			sample_records->append(sample);
		}
	};
	if (h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(choose_upper ? "0x4bbd01_vertical_upper" : "0x4bbd01_vertical_lower", x, choose_upper ? y - 1 : y + 1);
	}
	if (h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y);
		const bool right_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? "0x4bbd01_horizontal_left" : "0x4bbd01_horizontal_right", choose_left ? x - 1 : x + 1, y);
	}
	const std::array<int32_t, 8> same_terrain_mask = h3maped_same_terrain_mask_4bc74c(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	if (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && h3maped_same_class_region_gate_4bc928(same_terrain_mask)) {
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
				if (target_x >= 0 && target_y >= 0 && target_x < map_width && target_y < map_height) {
					retouch("0x4bbd01_same_class_zero_run", target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
}

TerrainClassResult classify_grid_cell(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	std::array<int32_t, 8> relations = {
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y - 1, center)),
	};
	return h3maped_classify_4bb075(relations);
}

bool select_visual_row_for_grid_cell_with_neighbor_mask(const std::vector<TerrainVisualRow> &rows, int32_t terrain_id, const TerrainClassResult &classified, int32_t neighbor_mask, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b, String &selector_address, String &selector_kind, int32_t &probability_threshold, int32_t &probability_rng_value) {
	std::vector<int32_t> bucket;
	probability_threshold = -1;
	probability_rng_value = -1;
	if (terrain_id == 9) {
		selector_address = "0x4baabf";
		selector_kind = "rock_class_flag_bucket";
		bucket = row_indices_for_class_flags(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		selector_address = "0x4ba938";
		selector_kind = "full_native_special_frequency_masked_by_0x4bce6d";
		const std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		const std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
		if (!special.empty()) {
			probability_rng_value = rng.next();
			probability_threshold = (constructor_probability_for_terrain_id(terrain_id) * std::max(0, neighbor_mask)) / 8;
			bucket = (probability_rng_value % 100) < probability_threshold ? special : ordinary;
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

Dictionary terrainplacement_live_feedback_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &terrain_cell_phase, const Dictionary &visual_tables_phase, std::vector<uint32_t> *out_zone_words = nullptr, std::vector<uint8_t> *out_cell_flags = nullptr, std::vector<uint32_t> *out_live_cell_word_0x24 = nullptr, std::vector<uint32_t> *out_live_cell_word_0x28 = nullptr, std::vector<int32_t> *out_live_terrain_code = nullptr) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_live_feedback";
	phase["h3maped_anchor"] = "0x4bb74b/0x4bc5f0";
	phase["full_water_repaint_address"] = "0x4a4025";
	phase["zone_repaint_loop_address"] = "0x4a4082";
	phase["single_cell_repaint_address"] = "0x4a415a";
	phase["changed_cell_update_address"] = "0x4bb74b";
	phase["neighbor_seed_address"] = "0x4bba59";
	phase["frontier_retouch_address"] = "0x4bbd01";
	phase["queue_drain_address"] = "0x4bc5f0";
	phase["candidate_gate_address"] = "0x4bc988";
	phase["visual_selector_address"] = "0x4bcfc3";
	phase["neighbor_mask_address"] = "0x4bce6d";
	phase["scratch_write_address"] = "0x4bad0f";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["status"] = "blocked_until_visual_tables";
	phase["uses_live_scratch_neighbor_mask"] = true;
	phase["materializes_private_generated_cell_words"] = false;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "terrain_tile_byte_writeback_0x49b2b6";
	if (String(visual_tables_phase.get("status", "")) != "active_strict_executable_port" || String(terrain_cell_phase.get("status", "")) != "active_strict_executable_port") {
		return phase;
	}

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = level_count(normalized_config);
	const int32_t level_tile_count = map_width * map_height;
	const int32_t tile_count = map_width * map_height * std::max(1, map_level_count);
	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	if (source.blocked) {
		phase["status"] = "blocked_during_source_node_split";
		return phase;
	}
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	const uint32_t coordinate_rng_state = uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0)));
	Dictionary fill = boundary_and_span_fill_4a2777_4a325d(normalized_config, runtime_zones, source, coordinate_rng_state, &zone_words, &cell_flags);
	const Array selected_terrain_codes = terrain_cell_phase.get("selected_h3maped_terrain_ids", Array());
	if (tile_count <= 0 || tile_count != int32_t(zone_words.size()) || selected_terrain_codes.is_empty()) {
		phase["status"] = "terrain_grid_inputs_missing";
		return phase;
	}

	TerrainVisualGridTables tables;
	if (!FileAccess::file_exists(BINARY_PATH)) {
		phase["status"] = "h3maped_exe_missing";
		return phase;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		phase["status"] = "h3maped_exe_unreadable";
		return phase;
	}
	tables.dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
	tables.sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
	tables.normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	tables.water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	tables.rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);
	const bool visual_tables_decoded = tables.dirt_rows.size() == 46 && tables.sand_rows.size() == 24 && tables.normal_rows.size() == 79 && tables.water_rows.size() == 33 && tables.rock_rows.size() == 48;
	phase["visual_tables_decoded"] = visual_tables_decoded;
	if (!visual_tables_decoded) {
		phase["status"] = "visual_table_decode_failed";
		return phase;
	}

	std::vector<int32_t> final_terrain_code(size_t(tile_count), 8);
	std::vector<int32_t> live_terrain_code(size_t(tile_count), 8);
	std::vector<uint32_t> live_scratch_word(size_t(tile_count), 0);
	std::vector<uint32_t> live_cell_word_0x24(size_t(tile_count), 0);
	std::vector<uint32_t> live_cell_word_0x28(size_t(tile_count), 0);
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			continue;
		}
		const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
		if (zone_word_id >= 0 && zone_word_id < selected_terrain_codes.size()) {
			final_terrain_code[size_t(index)] = int32_t(selected_terrain_codes[zone_word_id]);
		}
	}

	H3MapedRng live_visual_rng { uint32_t(int64_t(fill.get("rng_state_after_0x4a2777_uint32", 0))) };
	Dictionary neighbor_mask_histogram;
	Dictionary selector_kind_histogram;
	Array sample_records;
	Array seed_samples;
	Array drain_samples;
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
		if (neighbor_index < 0 || neighbor_index >= tile_count) {
			return false;
		}
		const uint32_t neighbor_scratch = live_scratch_word[size_t(neighbor_index)];
		return (neighbor_scratch & 0x01U) != 0U && h3maped_scratch_terrain_id(neighbor_scratch) == terrain_id && h3maped_scratch_art_id(neighbor_scratch) != 0;
	};
	auto live_neighbor_mask_for_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id) -> int32_t {
		const int32_t index = level * level_tile_count + y * map_width + x;
		int32_t mask = 4;
		if (x > 0 && live_accept_neighbor(index - 1, terrain_id)) {
			mask >>= 1;
		}
		if (y > 0 && live_accept_neighbor(index - map_width, terrain_id)) {
			mask >>= 1;
		}
		if (x + 1 < map_width && live_accept_neighbor(index + 1, terrain_id)) {
			mask >>= 1;
		}
		if (y + 1 < map_height && live_accept_neighbor(index + map_width, terrain_id)) {
			mask >>= 1;
		}
		return mask;
	};
	auto write_live_visual_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id, const char *source_branch) -> bool {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * map_width + x;
		if (index < 0 || index >= tile_count) {
			return false;
		}
		live_visual_attempt_count += 1;
		const TerrainClassResult classified = classify_grid_cell(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, terrain_id);
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
		const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU) | ((uint32_t(selected_row) & 0xffU) << 6U);
		const uint32_t generated_cell_word_0x28 = ((uint32_t(out_flag_a) & 0x01U) << 15U) | ((uint32_t(out_flag_b) & 0x01U) << 16U);
		live_scratch_word[size_t(index)] = scratch_word;
		live_cell_word_0x24[size_t(index)] = generated_cell_word_0x24;
		live_cell_word_0x28[size_t(index)] = generated_cell_word_0x28;
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

	for (int32_t level = 0; level < map_level_count; ++level) {
		for (int32_t y = 0; y < map_height; ++y) {
			for (int32_t x = 0; x < map_width; ++x) {
				live_initial_water_attempt_count += 1;
				write_live_visual_cell(level, x, y, 8, "0x4a4025_initial_water_repaint");
			}
		}
	}

	std::set<int64_t> set_a;
	std::set<int64_t> set_b;
	int32_t changed_cell_update_count = 0;
	int32_t set_a_insert_count = 0;
	int32_t set_b_insert_count = 0;
	int32_t max_set_a_count = 0;
	int32_t max_set_b_count = 0;
	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		if (set_b.insert(h3maped_grid_key(level, x, y)).second) {
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
			const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, nx, ny, current_terrain);
			if (h3maped_toolkit_byte5_allows_same_class_gate(neighbor)) {
				append_set_b(level, nx, ny, current_terrain, "0x4bba59_diagonal_byte5_zero_neighbor");
			}
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		if (set_a.insert(h3maped_grid_key(level, x, y)).second) {
			set_a_insert_count += 1;
		}
		if (drain_samples.size() < 16) {
			Dictionary sample;
			sample["x"] = x;
			sample["y"] = y;
			sample["level"] = level;
			sample["source_branch"] = source_branch;
			sample["terrain_id"] = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, -1);
			drain_samples.append(sample);
		}
	};
	auto seed_4bb74b_neighbor_branch = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		const bool gate = horizontal_pair_wrapper ? h3maped_horizontal_pair_gate_4bc674(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, neighbor) : h3maped_vertical_pair_gate_4bc6e0(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			seed_4bba59(level, x, y, current_terrain);
			append_set_b(level, x, y, current_terrain, source_branch);
		}
	};
	auto process_4bb74b_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0) {
			return;
		}
		set_terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, active_terrain);
		live_queue_attempt_count += 1;
		write_live_visual_cell(level, x, y, active_terrain, "0x4bb74b_queue_live_visual_feedback");
		if (!h3maped_toolkit_byte5_allows_same_class_gate(active_terrain)) {
			seed_4bb74b_neighbor_branch(level, x, y - 1, active_terrain, true, "0x4bb7b7_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x, y + 1, active_terrain, true, "0x4bb80b_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x - 1, y, active_terrain, false, "0x4bb863_neighbor_0x4bba36_false");
			seed_4bb74b_neighbor_branch(level, x + 1, y, active_terrain, false, "0x4bb8b7_neighbor_0x4bba36_false");
		} else if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
				retouched_cell_write_count += h3maped_frontier_retouch_4bbd01(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, &drain_samples, 24, &changed_keys);
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
				if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
		for (int32_t level = 0; level < map_level_count; ++level) {
			for (int32_t y = 0; y < map_height; ++y) {
				for (int32_t x = 0; x < map_width; ++x) {
					const int32_t index = level * level_tile_count + y * map_width + x;
					const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != int32_t(zone_index)) {
						continue;
					}
					changed_cell_update_count += 1;
					if (set_terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, terrain)) {
						live_repaint_attempt_count += 1;
						write_live_visual_cell(level, x, y, terrain, "0x4bb74b_repaint_live_visual_feedback");
						if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
	int32_t post_queue_terrain_difference_count = 0;
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t scratch_word = live_scratch_word[size_t(index)];
		if ((scratch_word & 0x01U) != 0U) {
			live_dirty_cell_count += 1;
		}
		const uint32_t roundtrip_0x24 = (uint32_t(h3maped_scratch_terrain_id(scratch_word)) & 0x3fU) | ((uint32_t(h3maped_scratch_art_id(scratch_word)) & 0xffU) << 6U);
		const uint32_t roundtrip_0x28 = (((scratch_word >> 12U) & 0x01U) << 15U) | (((scratch_word >> 13U) & 0x01U) << 16U);
		if (roundtrip_0x24 != live_cell_word_0x24[size_t(index)] || roundtrip_0x28 != live_cell_word_0x28[size_t(index)]) {
			live_roundtrip_mismatch_count += 1;
		}
		if (int32_t(live_cell_word_0x24[size_t(index)] & 0x3fU) != live_terrain_code[size_t(index)]) {
			live_terrain_mismatch_count += 1;
		}
		if (live_terrain_code[size_t(index)] != final_terrain_code[size_t(index)]) {
			post_queue_terrain_difference_count += 1;
		}
	}

	phase["status"] = "active_strict_executable_port";
	phase["source"] = "h3maped 0x4bb74b/0x4bc5f0 live repaint queue scratch feedback ported as private generated-cell evidence; no package tile/public grid adoption";
	phase["strict_port_scope"] = "private TerrainPlacement live scratch/generated-cell word feedback only; no 0x49b2b6 tile-byte projection, map cells, package tiles, roads, objects, or public output";
	phase["tile_count"] = tile_count;
	phase["exact_queue_drain_complete"] = drain_guard_count < drain_guard_limit;
	phase["live_feedback_materialized"] = true;
	phase["materializes_private_generated_cell_words"] = true;
	phase["live_visual_attempt_count"] = live_visual_attempt_count;
	phase["live_visual_write_count"] = live_visual_write_count;
	phase["live_visual_missing_bucket_count"] = live_visual_missing_bucket_count;
	phase["live_initial_water_attempt_count"] = live_initial_water_attempt_count;
	phase["live_repaint_attempt_count"] = live_repaint_attempt_count;
	phase["live_queue_attempt_count"] = live_queue_attempt_count;
	phase["live_dirty_cell_count"] = live_dirty_cell_count;
	phase["live_roundtrip_mismatch_count"] = live_roundtrip_mismatch_count;
	phase["live_terrain_mismatch_count"] = live_terrain_mismatch_count;
	phase["live_full_native_cell_count"] = live_full_native_cell_count;
	phase["live_terrain_art_nonzero_cell_count"] = live_terrain_art_nonzero_cell_count;
	phase["live_terrain_flag_cell_count"] = live_terrain_flag_cell_count;
	phase["post_queue_terrain_difference_count"] = post_queue_terrain_difference_count;
	phase["neighbor_mask_histogram"] = neighbor_mask_histogram;
	phase["selector_kind_histogram"] = selector_kind_histogram;
	phase["changed_cell_update_count"] = changed_cell_update_count;
	phase["initial_set_a_candidate_count"] = max_set_a_count;
	phase["initial_set_b_candidate_count"] = max_set_b_count;
	phase["total_set_a_insert_count"] = set_a_insert_count;
	phase["total_set_b_insert_count"] = set_b_insert_count;
	phase["set_a_drain_count"] = set_a_drain_count;
	phase["set_b_drain_count"] = set_b_drain_count;
	phase["set_b_candidate_true_count"] = set_b_candidate_true_count;
	phase["retouched_cell_write_count"] = retouched_cell_write_count;
	phase["drain_guard_limit"] = drain_guard_limit;
	phase["drain_guard_exhausted"] = drain_guard_count >= drain_guard_limit;
	phase["rng_state_after_live_visual_selection_uint32"] = int64_t(live_visual_rng.state);
	phase["seed_samples"] = seed_samples;
	phase["drain_samples"] = drain_samples;
	phase["sample_records"] = sample_records;
	phase["blocked_next"] = "terrain_tile_byte_writeback_0x49b2b6";
	if (out_zone_words != nullptr) {
		*out_zone_words = zone_words;
	}
	if (out_cell_flags != nullptr) {
		*out_cell_flags = cell_flags;
	}
	if (out_live_cell_word_0x24 != nullptr) {
		*out_live_cell_word_0x24 = live_cell_word_0x24;
	}
	if (out_live_cell_word_0x28 != nullptr) {
		*out_live_cell_word_0x28 = live_cell_word_0x28;
	}
	if (out_live_terrain_code != nullptr) {
		*out_live_terrain_code = live_terrain_code;
	}
	return phase;
}

Dictionary terrain_tile_byte_writeback_phase(const Dictionary &normalized_config, const Dictionary &live_feedback_phase, const std::vector<uint32_t> &live_cell_word_0x24, const std::vector<uint32_t> &live_cell_word_0x28, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "terrain_tile_byte_writeback";
	phase["h3maped_anchor"] = "0x49b2b6";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["serializer_contract"] = "byte0 = cell+0x24 bits0..5 terrain id; byte1 = cell+0x24 bits6..13 terrain art; byte6 bits0..1 = cell+0x28 bits15..16 terrain flags; river/road bytes remain pending";
	phase["status"] = "blocked_until_terrainplacement_live_feedback";
	phase["source"] = "h3maped 0x49b2b6 terrain tile-byte projection from live 0x49acf6 generated-cell words; roads/rivers/objects and package/public adoption remain pending";
	phase["strict_port_scope"] = "private terrain/art/flag tile-byte candidates only; no roads, rivers, objects, map cells, package tiles, or public output";
	phase["materializes_private_tile_byte_candidates"] = false;
	phase["materializes_package_tiles"] = false;
	phase["materializes_public_output"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["road_river_bytes_materialized"] = false;
	phase["object_bytes_materialized"] = false;
	phase["blocked_next"] = "town_object_placement_0x4a8d2c_0x4a8db2_0x4a93a2";
	if (String(live_feedback_phase.get("status", "")) != "active_strict_executable_port"
			|| live_cell_word_0x24.empty()
			|| live_cell_word_0x24.size() != live_cell_word_0x28.size()
			|| live_cell_word_0x24.size() != live_terrain_code.size()) {
		return phase;
	}

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t level_tile_count = map_width * map_height;
	const int32_t tile_count = int32_t(live_cell_word_0x24.size());
	Dictionary terrain_byte_histogram;
	Dictionary art_byte_histogram;
	Dictionary flag_byte_histogram;
	Array sample_tiles;
	int32_t terrain_mismatch_count = 0;
	int32_t art_nonzero_count = 0;
	int32_t flag_nonzero_count = 0;
	int32_t road_river_nonzero_count = 0;
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t word_0x24 = live_cell_word_0x24[size_t(index)];
		const uint32_t word_0x28 = live_cell_word_0x28[size_t(index)];
		const int32_t byte_0_terrain = int32_t(word_0x24 & 0x3fU);
		const int32_t byte_1_art = int32_t((word_0x24 >> 6U) & 0xffU);
		const int32_t byte_6_flags = int32_t((word_0x28 >> 15U) & 0x03U);
		const String terrain_key = String::num_int64(byte_0_terrain);
		const String art_key = String::num_int64(byte_1_art);
		const String flag_key = String::num_int64(byte_6_flags);
		terrain_byte_histogram[terrain_key] = int32_t(terrain_byte_histogram.get(terrain_key, 0)) + 1;
		art_byte_histogram[art_key] = int32_t(art_byte_histogram.get(art_key, 0)) + 1;
		flag_byte_histogram[flag_key] = int32_t(flag_byte_histogram.get(flag_key, 0)) + 1;
		if (byte_0_terrain != live_terrain_code[size_t(index)]) {
			terrain_mismatch_count += 1;
		}
		if (byte_1_art != 0) {
			art_nonzero_count += 1;
		}
		if (byte_6_flags != 0) {
			flag_nonzero_count += 1;
		}
		if (sample_tiles.size() < 16) {
			Dictionary sample;
			sample["index"] = index;
			sample["x"] = map_width > 0 ? index % map_width : 0;
			sample["y"] = map_width > 0 ? (index / map_width) % std::max(1, map_height) : 0;
			sample["level"] = level_tile_count > 0 ? index / level_tile_count : 0;
			sample["generated_cell_word_0x24_u32"] = int64_t(word_0x24);
			sample["generated_cell_word_0x28_u32"] = int64_t(word_0x28);
			sample["tile_byte_0_terrain_id"] = byte_0_terrain;
			sample["tile_byte_1_terrain_art"] = byte_1_art;
			sample["tile_byte_2_river_type"] = 0;
			sample["tile_byte_3_river_art"] = 0;
			sample["tile_byte_4_road_type"] = 0;
			sample["tile_byte_5_road_art"] = 0;
			sample["tile_byte_6_terrain_flags"] = byte_6_flags;
			sample_tiles.append(sample);
		}
	}

	phase["status"] = "active_strict_executable_port";
	phase["materializes_private_tile_byte_candidates"] = true;
	phase["tile_count"] = tile_count;
	phase["terrain_byte_candidate_count"] = tile_count;
	phase["terrain_byte_mismatch_count"] = terrain_mismatch_count;
	phase["terrain_art_nonzero_cell_count"] = art_nonzero_count;
	phase["terrain_flag_nonzero_cell_count"] = flag_nonzero_count;
	phase["road_river_nonzero_byte_count"] = road_river_nonzero_count;
	phase["tile_byte_0_histogram"] = terrain_byte_histogram;
	phase["tile_byte_1_art_histogram"] = art_byte_histogram;
	phase["tile_byte_6_flag_histogram"] = flag_byte_histogram;
	phase["sample_tile_byte_records"] = sample_tiles;
	phase["sample_tile_byte_record_count"] = sample_tiles.size();
	return phase;
}

#if 0
// Archived overgrown phase code. The same recovery evidence remains in the
// archived 20260513 files; live code reintroduces each phase only as a narrow
// strict executable port.
String project_terrain_for_h3maped_id(int32_t terrain_id) {
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
			return "subterranean";
		case 7:
			return "lava";
		case 8:
			return "water";
		default:
			return "unknown";
	}
}

Dictionary runtime_terrain_selection_49b53d(Array &runtime_zones, uint32_t rng_state_after_coordinate_replay, const Dictionary &normalized_config) {
	static constexpr int32_t H3_TOWN_TO_TERRAIN_TABLE_540908[9] = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	Dictionary phase;
	phase["phase_id"] = "runtime_terrain_selection";
	phase["h3maped_anchor"] = "0x49b53d";
	phase["town_to_terrain_table_address"] = "0x540908";
	phase["status"] = "active_internal_state";
	phase["rng_state_before_0x49b53d_uint32"] = int64_t(rng_state_after_coordinate_replay);
	phase["materializes_terrain_cells"] = false;
	phase["materializes_terrain_art"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;

	H3MapedRng rng { rng_state_after_coordinate_replay };
	Array selected_h3maped_terrain_ids;
	Array selected_project_terrains;
	Array selection_records;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t blank_allowed_mask_count = 0;
	int32_t forced_subterranean_count = 0;
	int32_t rng_call_count = 0;

	for (int32_t index = 0; index < runtime_zones.size(); ++index) {
		if (Variant(runtime_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zones[index];
		int32_t selected_terrain = 0;
		String source = "0x49b53d_default_dirt";
		if (bool(runtime.get("terrain_match_to_town", false))) {
			const int32_t town_choice = int32_t(runtime.get("town_choice_index_49b3c1", runtime.get("town_choice_index", -1)));
			if (town_choice >= 0 && town_choice < 9) {
				selected_terrain = H3_TOWN_TO_TERRAIN_TABLE_540908[town_choice];
				source = "0x49b53d_0x540908_town_table";
				match_to_town_count += 1;
			}
		} else {
			Array allowed = runtime.get("allowed_h3maped_terrain_ids_for_49b53d", Array());
			Array eligible;
			for (int32_t allowed_index = 0; allowed_index < allowed.size(); ++allowed_index) {
				const int32_t terrain_id = int32_t(allowed[allowed_index]);
				if (terrain_id >= 0 && terrain_id <= 7) {
					eligible.append(terrain_id);
				}
			}
			if (eligible.is_empty()) {
				blank_allowed_mask_count += 1;
			} else {
				const int32_t rng_value = rng.next();
				rng_call_count += 1;
				const int32_t selected_index = rng_value % int32_t(eligible.size());
				selected_terrain = int32_t(eligible[selected_index]);
				source = "0x49b53d_allowed_terrain_flag_rng";
				allowed_flag_choice_count += 1;
			}
		}
		if (level_count(normalized_config) == 2 && int32_t(runtime.get("level", 0)) == 1 && selected_terrain != 7) {
			selected_terrain = 6;
			source = "0x49b53d_forced_subterranean_level";
			forced_subterranean_count += 1;
		}

		const String project_terrain = project_terrain_for_h3maped_id(selected_terrain);
		runtime["h3maped_terrain_id"] = selected_terrain;
		runtime["terrain_id"] = project_terrain;
		runtime["terrain_source"] = source;
		runtime["terrain_selection_status"] = "0x49b53d_selected";
		runtime_zones[index] = runtime;
		selected_h3maped_terrain_ids.append(selected_terrain);
		selected_project_terrains.append(project_terrain);
		Dictionary record;
		record["runtime_zone_index"] = int32_t(runtime.get("runtime_zone_index", index));
		record["h3maped_terrain_id"] = selected_terrain;
		record["project_terrain_id"] = project_terrain;
		record["source"] = source;
		selection_records.append(record);
	}

	phase["runtime_zone_count"] = runtime_zones.size();
	phase["selected_h3maped_terrain_ids"] = selected_h3maped_terrain_ids;
	phase["selected_project_terrain_ids"] = selected_project_terrains;
	phase["selection_records"] = selection_records;
	phase["match_to_town_count"] = match_to_town_count;
	phase["allowed_flag_choice_count"] = allowed_flag_choice_count;
	phase["blank_allowed_mask_count"] = blank_allowed_mask_count;
	phase["forced_subterranean_count"] = forced_subterranean_count;
	phase["terrain_rng_call_count"] = rng_call_count;
	phase["rng_state_after_0x49b53d_uint32"] = int64_t(rng.state);
	return phase;
}

Dictionary terrain_cell_writeout_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &footprint_phase) {
	Dictionary phase;
	phase["phase_id"] = "terrain_cell_writeout";
	phase["status"] = "blocked_until_zone_footprints";
	phase["runtime_terrain_selection_anchor"] = "0x49b53d";
	phase["h3maped_anchor"] = "0x4a3f27";
	phase["span_fill_anchor"] = "0x4a325d";
	phase["materializes_private_terrain_cell_buffer"] = false;
	phase["materializes_terrain_art"] = false;
	phase["materializes_roads"] = false;
	phase["materializes_objects"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "terrainplacement_visual_tables_0x4bcff5";
	if (String(footprint_phase.get("status", "")) != "active_internal_state") {
		return phase;
	}

	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	if (source.blocked) {
		phase["status"] = "blocked_during_source_node_split";
		return phase;
	}
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	Dictionary fill = boundary_and_span_fill_4a2777_4a325d(normalized_config, runtime_zones, source, uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))), &zone_words, &cell_flags);
	Dictionary selection = runtime_terrain_selection_49b53d(runtime_zones, uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))), normalized_config);

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = level_count(normalized_config);
	const int32_t tile_count = std::max(0, map_width * map_height * std::max(1, map_level_count));
	std::vector<int32_t> runtime_zone_terrain_ids(size_t(runtime_zones.size()), 8);
	for (int32_t index = 0; index < runtime_zones.size(); ++index) {
		if (Variant(runtime_zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zones[index];
		const int32_t runtime_index = int32_t(runtime.get("runtime_zone_index", index));
		if (runtime_index >= 0 && runtime_index < int32_t(runtime_zone_terrain_ids.size())) {
			runtime_zone_terrain_ids[size_t(runtime_index)] = int32_t(runtime.get("h3maped_terrain_id", 8));
		}
	}

	std::map<int32_t, int32_t> owner_low_byte_counts;
	std::map<int32_t, int32_t> terrain_code_counts;
	std::map<String, int32_t> terrain_project_counts;
	terrain_code_counts[8] = tile_count;
	terrain_project_counts["water"] = tile_count;
	int32_t assigned_owner_cell_count = 0;
	int32_t unassigned_water_cell_count = 0;
	int32_t reserved_cell_count = 0;
	for (int32_t cell_index = 0; cell_index < tile_count && cell_index < int32_t(zone_words.size()); ++cell_index) {
		if ((cell_flags[size_t(cell_index)] & 0x10U) != 0) {
			reserved_cell_count += 1;
		}
		const uint32_t zone_word = zone_words[size_t(cell_index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD) {
			unassigned_water_cell_count += 1;
			continue;
		}
		const int32_t owner_byte = int32_t((zone_word >> 16U) & 0xffU);
		if (owner_byte < 0 || owner_byte >= int32_t(runtime_zone_terrain_ids.size())) {
			continue;
		}
		const int32_t terrain_id = runtime_zone_terrain_ids[size_t(owner_byte)];
		const String project_terrain = project_terrain_for_h3maped_id(terrain_id);
		assigned_owner_cell_count += 1;
		owner_low_byte_counts[owner_byte] += 1;
		terrain_code_counts[8] -= 1;
		terrain_project_counts["water"] -= 1;
		terrain_code_counts[terrain_id] += 1;
		terrain_project_counts[project_terrain] += 1;
	}

	Array owner_counts_report;
	for (const auto &item : owner_low_byte_counts) {
		Dictionary entry;
		entry["owner_low_byte"] = item.first;
		entry["cell_count"] = item.second;
		owner_counts_report.append(entry);
	}
	Array terrain_code_counts_report;
	for (const auto &item : terrain_code_counts) {
		Dictionary entry;
		entry["h3maped_terrain_id"] = item.first;
		entry["cell_count"] = item.second;
		terrain_code_counts_report.append(entry);
	}
	Dictionary terrain_project_counts_report;
	for (const auto &item : terrain_project_counts) {
		terrain_project_counts_report[item.first] = item.second;
	}

	phase["status"] = "active_internal_state";
	phase["source"] = "h3maped 0x49b53d terrain selection plus 0x4a3f27 private terrain cell writeout over the real 0x4a325d zone-word buffer";
	phase["terrain_selection"] = selection;
	phase["selected_h3maped_terrain_ids"] = selection.get("selected_h3maped_terrain_ids", Array());
	phase["selected_project_terrain_ids"] = selection.get("selected_project_terrain_ids", Array());
	phase["terrain_rng_call_count"] = selection.get("terrain_rng_call_count", 0);
	phase["rng_state_before_0x49b53d_uint32"] = selection.get("rng_state_before_0x49b53d_uint32", 0);
	phase["rng_state_after_0x49b53d_uint32"] = selection.get("rng_state_after_0x49b53d_uint32", 0);
	phase["tile_count"] = tile_count;
	phase["private_zone_word_cell_count"] = int32_t(zone_words.size());
	phase["assigned_owner_cell_count"] = assigned_owner_cell_count;
	phase["unassigned_water_cell_count"] = unassigned_water_cell_count;
	phase["reserved_cell_count"] = reserved_cell_count;
	phase["span_fill_boundary_or_filled_cell_count"] = fill.get("total_boundary_or_filled_cell_count", 0);
	phase["owner_low_byte_counts"] = owner_counts_report;
	phase["terrain_code_counts"] = terrain_code_counts_report;
	phase["terrain_project_counts"] = terrain_project_counts_report;
	phase["materializes_private_terrain_cell_buffer"] = true;
	return phase;
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
		rows.push_back(TerrainVisualRow { int32_t(shape_class), int32_t(flag_a), int32_t(flag_b) });
	}
	return rows;
}

Dictionary terrain_visual_table_summary(const char *id, const char *terrain_ids, const char *address, int64_t table_va, int32_t expected_row_count, const std::vector<TerrainVisualRow> &rows) {
	Dictionary summary;
	summary["id"] = id;
	summary["terrain_ids"] = terrain_ids;
	summary["table_address"] = address;
	summary["table_file_offset"] = h3maped_va_to_file_offset(table_va);
	summary["expected_row_count"] = expected_row_count;
	summary["decoded_row_count"] = int32_t(rows.size());
	summary["row_stride_bytes"] = 8;
	summary["row_contract"] = "u32 class, u8 flag_a, u8 flag_b";
	std::map<int32_t, int32_t> class_counts;
	for (const TerrainVisualRow &row : rows) {
		class_counts[row.shape_class] += 1;
	}
	Array class_records;
	for (const auto &entry : class_counts) {
		Dictionary record;
		record["class"] = entry.first;
		record["row_count"] = entry.second;
		class_records.append(record);
	}
	summary["unique_class_count"] = int32_t(class_counts.size());
	summary["class_counts"] = class_records;
	summary["status"] = int32_t(rows.size()) == expected_row_count ? String("decoded_from_h3maped_exe") : String("decode_failed");
	return summary;
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
	H3MapedRng rng { seed };
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
	Dictionary sample;
	sample["id"] = id;
	sample["selector_address"] = selector_address;
	sample["table_address"] = table_address;
	sample["selector_kind"] = selector_kind;
	sample["class"] = shape_class;
	sample["flag_a"] = flag_a;
	sample["flag_b"] = flag_b;
	sample["rng_seed_uint32"] = int64_t(seed);
	sample["probability_rng_value"] = probability_rng_value;
	sample["probability_threshold"] = probability_threshold;
	sample["selected_special_bucket"] = selected_special_bucket;
	sample["bucket_count"] = int32_t(bucket.size());
	if (bucket.empty()) {
		sample["status"] = "missing_visual_row_bucket";
		return sample;
	}
	const int32_t art_rng_value = rng.next();
	const int32_t selected_row = bucket[size_t(art_rng_value % int32_t(bucket.size()))];
	sample["status"] = "visual_row_selected_from_decoded_h3maped_table";
	sample["art_rng_value"] = art_rng_value;
	sample["selected_row"] = selected_row;
	sample["out_flag_a"] = rock_selector ? 0 : flag_a;
	sample["out_flag_b"] = rock_selector ? 0 : flag_b;
	sample["rng_state_after_uint32"] = int64_t(rng.state);
	return sample;
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
	const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU) | ((uint32_t(selected_row) & 0xffU) << 6U);
	const uint32_t generated_cell_word_0x28 = ((uint32_t(flag_a) & 0x01U) << 15U) | ((uint32_t(flag_b) & 0x01U) << 16U);
	Dictionary sample;
	sample["id"] = id;
	sample["terrain_id"] = terrain_id;
	sample["selected_row"] = selected_row;
	sample["flag_a"] = flag_a;
	sample["flag_b"] = flag_b;
	sample["scratch_word_u16"] = int32_t(scratch_word);
	sample["generated_cell_word_0x24_u32"] = int64_t(generated_cell_word_0x24);
	sample["generated_cell_word_0x28_u32"] = int64_t(generated_cell_word_0x28);
	sample["tile_byte_0_terrain_id"] = int32_t(generated_cell_word_0x24 & 0x3fU);
	sample["tile_byte_1_terrain_art"] = int32_t((generated_cell_word_0x24 >> 6U) & 0xffU);
	sample["tile_byte_6_terrain_flags"] = int32_t((generated_cell_word_0x28 >> 15U) & 0x03U);
	return sample;
}

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
	if (center_terrain_id == neighbor_terrain_id || center_terrain_id == 1) {
		return 0;
	}
	if (terrain_trait_flag4(center_terrain_id) == 0 || terrain_trait_flag4(neighbor_terrain_id) == 0) {
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot, true); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented(relations, a, b, slot); };
		if (r(3) == 1) {
			return { 0x05, a, b };
		}
		if (r(3) == 2) {
			return { 0x0b, a, b };
		}
	}
	return { 0x00, 0, 0 };
}

int32_t terrain_at_grid_index(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * map_width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size())) {
		return fallback_terrain_id;
	}
	return terrain_codes[size_t(index)];
}

bool set_terrain_at_grid_index(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return false;
	}
	const int32_t index = level * level_tile_count + y * map_width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size()) || terrain_codes[size_t(index)] == terrain_id) {
		return false;
	}
	terrain_codes[size_t(index)] = terrain_id;
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

std::array<int32_t, 8> h3maped_same_terrain_mask_4bc74c(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	std::array<int32_t, 8> mask = { 0, 0, 0, 0, 0, 0, 0, 0 };
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		return nx >= 0 && ny >= 0 && nx < map_width && ny < map_height && terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, nx, ny, -1) == terrain_id;
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

bool h3maped_same_class_region_gate_4bc928(const std::array<int32_t, 8> &mask) {
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

bool h3maped_horizontal_pair_gate_4bc674(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= map_width - 1 || y < 0 || y >= map_height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool h3maped_vertical_pair_gate_4bc6e0(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= map_height - 1 || x < 0 || x >= map_width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool h3maped_toolkit_byte5_allows_same_class_gate(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool h3maped_candidate_gate_4bc988_grid(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928(h3maped_same_terrain_mask_4bc74c(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id));
	return horizontal_pair_gate || vertical_pair_gate || (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && same_class_region_gate);
}

int32_t h3maped_frontier_retouch_4bbd01(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, Array *sample_records, int32_t sample_limit, std::vector<int64_t> *changed_keys_out = nullptr) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](const char *branch, int32_t target_x, int32_t target_y) {
		const bool changed = set_terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, target_x, target_y, terrain_id);
		if (changed) {
			changed_count += 1;
			if (changed_keys_out != nullptr) {
				changed_keys_out->push_back(h3maped_grid_key(level, target_x, target_y));
			}
		}
		if (sample_records != nullptr && sample_records->size() < sample_limit) {
			Dictionary sample;
			sample["branch"] = branch;
			sample["from_x"] = x;
			sample["from_y"] = y;
			sample["target_x"] = target_x;
			sample["target_y"] = target_y;
			sample["terrain_id"] = terrain_id;
			sample["changed_terrain"] = changed;
			sample_records->append(sample);
		}
	};
	if (h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(choose_upper ? "0x4bbd01_vertical_upper" : "0x4bbd01_vertical_lower", x, choose_upper ? y - 1 : y + 1);
	}
	if (h3maped_horizontal_pair_gate_4bc674(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y);
		const bool right_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? "0x4bbd01_horizontal_left" : "0x4bbd01_horizontal_right", choose_left ? x - 1 : x + 1, y);
	}
	const std::array<int32_t, 8> same_terrain_mask = h3maped_same_terrain_mask_4bc74c(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	if (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && h3maped_same_class_region_gate_4bc928(same_terrain_mask)) {
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
				if (target_x >= 0 && target_y >= 0 && target_x < map_width && target_y < map_height) {
					retouch("0x4bbd01_same_class_zero_run", target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
}

TerrainClassResult classify_grid_cell(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	std::array<int32_t, 8> relations = {
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y - 1, center)),
	};
	return h3maped_classify_4bb075(relations);
}

bool select_visual_row_for_grid_cell_with_neighbor_mask(const std::vector<TerrainVisualRow> &rows, int32_t terrain_id, const TerrainClassResult &classified, int32_t neighbor_mask, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b, String &selector_address, String &selector_kind, int32_t &probability_threshold, int32_t &probability_rng_value) {
	std::vector<int32_t> bucket;
	probability_threshold = -1;
	probability_rng_value = -1;
	if (terrain_id == 9) {
		selector_address = "0x4baabf";
		selector_kind = "rock_class_flag_bucket";
		bucket = row_indices_for_class_flags(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		selector_address = "0x4ba938";
		selector_kind = "full_native_special_frequency_masked_by_0x4bce6d";
		const std::vector<int32_t> ordinary = row_indices_for_class_group(rows, 0, 0);
		const std::vector<int32_t> special = row_indices_for_class_group(rows, 0, 1);
		if (!special.empty()) {
			probability_rng_value = rng.next();
			probability_threshold = (constructor_probability_for_terrain_id(terrain_id) * std::max(0, neighbor_mask)) / 8;
			bucket = (probability_rng_value % 100) < probability_threshold ? special : ordinary;
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

Dictionary terrainplacement_visual_tables_phase(const Dictionary &terrain_cell_phase) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_visual_tables";
	phase["h3maped_anchor"] = "0x4bcff5";
	phase["terrainplacement_constructor_address"] = "0x4bb5ce";
	phase["terrainplacement_wrapper_address"] = "0x4bd099";
	phase["changed_cell_update_address"] = "0x4bb74b";
	phase["queue_drain_address"] = "0x4bc5f0";
	phase["visual_selector_address"] = "0x4bcfc3";
	phase["neighbor_mask_address"] = "0x4bce6d";
	phase["toolkit_table_address"] = "0x5436b8";
	phase["complex_toolkit_vtable_address"] = "0x543780";
	phase["simple_toolkit_vtable_address"] = "0x54379c";
	phase["complex_visual_resolve_vfunc_plus_0x10"] = "0x4ba938";
	phase["complex_visual_writeback_vfunc_plus_0x14"] = "0x4ba989";
	phase["simple_visual_resolve_vfunc_plus_0x10"] = "0x4baa94";
	phase["simple_visual_writeback_vfunc_plus_0x14"] = "0x4baabf";
	phase["status"] = "blocked_until_terrain_cell_writeout";
	phase["terrain_art_hash_fallback_allowed"] = false;
	phase["materializes_visual_record"] = false;
	phase["materializes_full_terrain_art_grid"] = false;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback";
	if (String(terrain_cell_phase.get("status", "")) != "active_internal_state") {
		return phase;
	}
	if (!FileAccess::file_exists(BINARY_PATH)) {
		phase["status"] = "h3maped_exe_missing";
		return phase;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		phase["status"] = "h3maped_exe_unreadable";
		return phase;
	}

	const std::vector<TerrainVisualRow> normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	const std::vector<TerrainVisualRow> dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
	const std::vector<TerrainVisualRow> sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
	const std::vector<TerrainVisualRow> water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	const std::vector<TerrainVisualRow> rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);

	Array table_summaries;
	table_summaries.append(terrain_visual_table_summary("normal_land_terrain_ids_2_7", "2,3,4,5,6,7", "0x543108", 0x543108, 79, normal_rows));
	table_summaries.append(terrain_visual_table_summary("dirt_terrain_id_0", "0", "0x543380", 0x543380, 46, dirt_rows));
	table_summaries.append(terrain_visual_table_summary("sand_terrain_id_1", "1", "0x5434f0", 0x5434f0, 24, sand_rows));
	table_summaries.append(terrain_visual_table_summary("water_terrain_id_8", "8", "0x5435b0", 0x5435b0, 33, water_rows));
	table_summaries.append(terrain_visual_table_summary("rock_terrain_id_9", "9", "0x542f88", 0x542f88, 48, rock_rows));
	const int32_t decoded_total = int32_t(normal_rows.size() + dirt_rows.size() + sand_rows.size() + water_rows.size() + rock_rows.size());

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

	Array row_selection_samples;
	row_selection_samples.append(terrain_row_selection_sample("normal_full_grass_seed_1", "0x4ba938", "0x543108", "normal_full_native_special_frequency", normal_rows, 0, 0, 0, 0x32, true, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("normal_transition_class_28_seed_1", "0x4ba989", "0x543108", "normal_transition_class_bucket", normal_rows, 28, 1, 0, 0x50, false, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("water_transition_class_16_seed_1", "0x4ba989", "0x5435b0", "water_normal_trait_transition_class_bucket", water_rows, 16, 0, 0, 0x00, false, false, 1));
	row_selection_samples.append(terrain_row_selection_sample("rock_class_8_flag_1_0_seed_1", "0x4baabf", "0x542f88", "rock_class_flag_bucket", rock_rows, 8, 1, 0, 0x00, false, true, 1));

	Array scratch_samples;
	scratch_samples.append(terrain_scratch_write_sample("grass_full_row_60_flags_0_0", 2, 60, 0, 0));
	scratch_samples.append(terrain_scratch_write_sample("grass_class_28_row_77_flags_1_0", 2, 77, 1, 0));
	scratch_samples.append(terrain_scratch_write_sample("water_class_16_row_20_flags_0_0", 8, 20, 0, 0));
	scratch_samples.append(terrain_scratch_write_sample("rock_class_8_row_11_cleared_flags", 9, 11, 0, 0));

	phase["status"] = decoded_total == 230 ? String("active_internal_state") : String("visual_table_decode_failed");
	phase["source"] = "h3maped TerrainPlacement visual table/toolkit boundary decoded directly from /root/Downloads/h3maped.exe; no hashed terrain art approximation and no public package adoption";
	phase["table_count"] = table_summaries.size();
	phase["decoded_total_row_count"] = decoded_total;
	phase["expected_total_row_count"] = 230;
	phase["tables"] = table_summaries;
	phase["toolkit_constructor_records"] = constructor_records;
	phase["toolkit_constructor_record_count"] = constructor_records.size();
	phase["visual_row_selection_sample_count"] = row_selection_samples.size();
	phase["visual_row_selection_samples"] = row_selection_samples;
	phase["scratch_write_address"] = "0x4bad0f";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["scratch_word_contract"] = "bit0 dirty, bits1..4 terrain id, bits5..11 terrain art row, bit12 flag A, bit13 flag B";
	phase["generated_cell_contract"] = "cell+0x24 bits0..5 terrain id, bits6..13 terrain art; cell+0x28 bits15..16 terrain flags";
	phase["scratch_write_sample_count"] = scratch_samples.size();
	phase["scratch_write_samples"] = scratch_samples;
	phase["blocked_next"] = "live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback";
	return phase;
}

Dictionary terrainplacement_live_feedback_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &terrain_cell_phase, const Dictionary &visual_tables_phase, std::vector<uint32_t> *out_zone_words = nullptr, std::vector<uint8_t> *out_cell_flags = nullptr, std::vector<uint32_t> *out_live_cell_word_0x24 = nullptr, std::vector<uint32_t> *out_live_cell_word_0x28 = nullptr, std::vector<int32_t> *out_live_terrain_code = nullptr) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_live_feedback";
	phase["h3maped_anchor"] = "0x4bb74b/0x4bc5f0";
	phase["full_water_repaint_address"] = "0x4a4025";
	phase["zone_repaint_loop_address"] = "0x4a4082";
	phase["single_cell_repaint_address"] = "0x4a415a";
	phase["changed_cell_update_address"] = "0x4bb74b";
	phase["neighbor_seed_address"] = "0x4bba59";
	phase["frontier_retouch_address"] = "0x4bbd01";
	phase["queue_drain_address"] = "0x4bc5f0";
	phase["candidate_gate_address"] = "0x4bc988";
	phase["visual_selector_address"] = "0x4bcfc3";
	phase["neighbor_mask_address"] = "0x4bce6d";
	phase["scratch_write_address"] = "0x4bad0f";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["status"] = "blocked_until_visual_tables";
	phase["uses_live_scratch_neighbor_mask"] = true;
	phase["materializes_private_generated_cell_words"] = true;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "private_0x49b2b6_tile_byte_writeback_candidate";
	if (String(visual_tables_phase.get("status", "")) != "active_internal_state" || String(terrain_cell_phase.get("status", "")) != "active_internal_state") {
		return phase;
	}

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = level_count(normalized_config);
	const int32_t level_tile_count = map_width * map_height;
	const int32_t tile_count = map_width * map_height * std::max(1, map_level_count);
	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	if (source.blocked) {
		phase["status"] = "blocked_during_source_node_split";
		return phase;
	}
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	const uint32_t coordinate_rng_state = uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0)));
	Dictionary fill = boundary_and_span_fill_4a2777_4a325d(normalized_config, runtime_zones, source, coordinate_rng_state, &zone_words, &cell_flags);
	Dictionary selection = runtime_terrain_selection_49b53d(runtime_zones, coordinate_rng_state, normalized_config);
	const Array selected_terrain_codes = selection.get("selected_h3maped_terrain_ids", Array());
	if (tile_count <= 0 || tile_count != int32_t(zone_words.size()) || selected_terrain_codes.is_empty()) {
		phase["status"] = "terrain_grid_inputs_missing";
		return phase;
	}

	TerrainVisualGridTables tables;
	if (!FileAccess::file_exists(BINARY_PATH)) {
		phase["status"] = "h3maped_exe_missing";
		return phase;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		phase["status"] = "h3maped_exe_unreadable";
		return phase;
	}
	tables.dirt_rows = decode_terrain_visual_rows(file, 0x543380, 46);
	tables.sand_rows = decode_terrain_visual_rows(file, 0x5434f0, 24);
	tables.normal_rows = decode_terrain_visual_rows(file, 0x543108, 79);
	tables.water_rows = decode_terrain_visual_rows(file, 0x5435b0, 33);
	tables.rock_rows = decode_terrain_visual_rows(file, 0x542f88, 48);
	const bool visual_tables_decoded = tables.dirt_rows.size() == 46 && tables.sand_rows.size() == 24 && tables.normal_rows.size() == 79 && tables.water_rows.size() == 33 && tables.rock_rows.size() == 48;
	phase["visual_tables_decoded"] = visual_tables_decoded;
	if (!visual_tables_decoded) {
		phase["status"] = "visual_table_decode_failed";
		return phase;
	}

	std::vector<int32_t> final_terrain_code(size_t(tile_count), 8);
	std::vector<int32_t> live_terrain_code(size_t(tile_count), 8);
	std::vector<uint32_t> live_scratch_word(size_t(tile_count), 0);
	std::vector<uint32_t> live_cell_word_0x24(size_t(tile_count), 0);
	std::vector<uint32_t> live_cell_word_0x28(size_t(tile_count), 0);
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			continue;
		}
		const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
		if (zone_word_id >= 0 && zone_word_id < selected_terrain_codes.size()) {
			final_terrain_code[size_t(index)] = int32_t(selected_terrain_codes[zone_word_id]);
		}
	}

	H3MapedRng live_visual_rng { uint32_t(int64_t(fill.get("rng_state_after_0x4a2777_uint32", 0))) };
	Dictionary neighbor_mask_histogram;
	Dictionary selector_kind_histogram;
	Array sample_records;
	Array seed_samples;
	Array drain_samples;
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
		if (neighbor_index < 0 || neighbor_index >= tile_count) {
			return false;
		}
		const uint32_t neighbor_scratch = live_scratch_word[size_t(neighbor_index)];
		return (neighbor_scratch & 0x01U) != 0U && h3maped_scratch_terrain_id(neighbor_scratch) == terrain_id && h3maped_scratch_art_id(neighbor_scratch) != 0;
	};
	auto live_neighbor_mask_for_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id) -> int32_t {
		const int32_t index = level * level_tile_count + y * map_width + x;
		int32_t mask = 4;
		if (x > 0 && live_accept_neighbor(index - 1, terrain_id)) {
			mask >>= 1;
		}
		if (y > 0 && live_accept_neighbor(index - map_width, terrain_id)) {
			mask >>= 1;
		}
		if (x + 1 < map_width && live_accept_neighbor(index + 1, terrain_id)) {
			mask >>= 1;
		}
		if (y + 1 < map_height && live_accept_neighbor(index + map_width, terrain_id)) {
			mask >>= 1;
		}
		return mask;
	};
	auto write_live_visual_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id, const char *source_branch) -> bool {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * map_width + x;
		if (index < 0 || index >= tile_count) {
			return false;
		}
		live_visual_attempt_count += 1;
		const TerrainClassResult classified = classify_grid_cell(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, terrain_id);
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
		const uint32_t generated_cell_word_0x24 = (uint32_t(terrain_id) & 0x3fU) | ((uint32_t(selected_row) & 0xffU) << 6U);
		const uint32_t generated_cell_word_0x28 = ((uint32_t(out_flag_a) & 0x01U) << 15U) | ((uint32_t(out_flag_b) & 0x01U) << 16U);
		live_scratch_word[size_t(index)] = scratch_word;
		live_cell_word_0x24[size_t(index)] = generated_cell_word_0x24;
		live_cell_word_0x28[size_t(index)] = generated_cell_word_0x28;
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

	for (int32_t level = 0; level < map_level_count; ++level) {
		for (int32_t y = 0; y < map_height; ++y) {
			for (int32_t x = 0; x < map_width; ++x) {
				live_initial_water_attempt_count += 1;
				write_live_visual_cell(level, x, y, 8, "0x4a4025_initial_water_repaint");
			}
		}
	}

	std::set<int64_t> set_a;
	std::set<int64_t> set_b;
	int32_t changed_cell_update_count = 0;
	int32_t set_a_insert_count = 0;
	int32_t set_b_insert_count = 0;
	int32_t max_set_a_count = 0;
	int32_t max_set_b_count = 0;
	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		if (set_b.insert(h3maped_grid_key(level, x, y)).second) {
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
			const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, nx, ny, current_terrain);
			if (h3maped_toolkit_byte5_allows_same_class_gate(neighbor)) {
				append_set_b(level, nx, ny, current_terrain, "0x4bba59_diagonal_byte5_zero_neighbor");
			}
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		if (set_a.insert(h3maped_grid_key(level, x, y)).second) {
			set_a_insert_count += 1;
		}
		if (drain_samples.size() < 16) {
			Dictionary sample;
			sample["x"] = x;
			sample["y"] = y;
			sample["level"] = level;
			sample["source_branch"] = source_branch;
			sample["terrain_id"] = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, -1);
			drain_samples.append(sample);
		}
	};
	auto seed_4bb74b_neighbor_branch = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper, const char *source_branch) {
		if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		const bool gate = horizontal_pair_wrapper ? h3maped_horizontal_pair_gate_4bc674(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, neighbor) : h3maped_vertical_pair_gate_4bc6e0(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			seed_4bba59(level, x, y, current_terrain);
			append_set_b(level, x, y, current_terrain, source_branch);
		}
	};
	auto process_4bb74b_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0) {
			return;
		}
		set_terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, active_terrain);
		live_queue_attempt_count += 1;
		write_live_visual_cell(level, x, y, active_terrain, "0x4bb74b_queue_live_visual_feedback");
		if (!h3maped_toolkit_byte5_allows_same_class_gate(active_terrain)) {
			seed_4bb74b_neighbor_branch(level, x, y - 1, active_terrain, true, "0x4bb7b7_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x, y + 1, active_terrain, true, "0x4bb80b_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x - 1, y, active_terrain, false, "0x4bb863_neighbor_0x4bba36_false");
			seed_4bb74b_neighbor_branch(level, x + 1, y, active_terrain, false, "0x4bb8b7_neighbor_0x4bba36_false");
		} else if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
				retouched_cell_write_count += h3maped_frontier_retouch_4bbd01(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, &drain_samples, 24, &changed_keys);
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
				if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
		for (int32_t level = 0; level < map_level_count; ++level) {
			for (int32_t y = 0; y < map_height; ++y) {
				for (int32_t x = 0; x < map_width; ++x) {
					const int32_t index = level * level_tile_count + y * map_width + x;
					const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != int32_t(zone_index)) {
						continue;
					}
					changed_cell_update_count += 1;
					if (set_terrain_at_grid_index(live_terrain_code, map_width, map_height, level_tile_count, level, x, y, terrain)) {
						live_repaint_attempt_count += 1;
						write_live_visual_cell(level, x, y, terrain, "0x4bb74b_repaint_live_visual_feedback");
						if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, map_width, map_height, level_tile_count, level, x, y)) {
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
	int32_t post_queue_terrain_difference_count = 0;
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t scratch_word = live_scratch_word[size_t(index)];
		if ((scratch_word & 0x01U) != 0U) {
			live_dirty_cell_count += 1;
		}
		const uint32_t roundtrip_0x24 = (uint32_t(h3maped_scratch_terrain_id(scratch_word)) & 0x3fU) | ((uint32_t(h3maped_scratch_art_id(scratch_word)) & 0xffU) << 6U);
		const uint32_t roundtrip_0x28 = (((scratch_word >> 12U) & 0x01U) << 15U) | (((scratch_word >> 13U) & 0x01U) << 16U);
		if (roundtrip_0x24 != live_cell_word_0x24[size_t(index)] || roundtrip_0x28 != live_cell_word_0x28[size_t(index)]) {
			live_roundtrip_mismatch_count += 1;
		}
		if (int32_t(live_cell_word_0x24[size_t(index)] & 0x3fU) != live_terrain_code[size_t(index)]) {
			live_terrain_mismatch_count += 1;
		}
		if (live_terrain_code[size_t(index)] != final_terrain_code[size_t(index)]) {
			post_queue_terrain_difference_count += 1;
		}
	}

	phase["status"] = "active_internal_state";
	phase["source"] = "h3maped 0x4bb74b/0x4bc5f0 live repaint queue scratch feedback ported as private generated-cell evidence; no package tile/public grid adoption";
	phase["tile_count"] = tile_count;
	phase["exact_queue_drain_complete"] = drain_guard_count < drain_guard_limit;
	phase["live_feedback_materialized"] = true;
	phase["live_visual_attempt_count"] = live_visual_attempt_count;
	phase["live_visual_write_count"] = live_visual_write_count;
	phase["live_visual_missing_bucket_count"] = live_visual_missing_bucket_count;
	phase["live_initial_water_attempt_count"] = live_initial_water_attempt_count;
	phase["live_repaint_attempt_count"] = live_repaint_attempt_count;
	phase["live_queue_attempt_count"] = live_queue_attempt_count;
	phase["live_dirty_cell_count"] = live_dirty_cell_count;
	phase["live_roundtrip_mismatch_count"] = live_roundtrip_mismatch_count;
	phase["live_terrain_mismatch_count"] = live_terrain_mismatch_count;
	phase["live_full_native_cell_count"] = live_full_native_cell_count;
	phase["live_terrain_art_nonzero_cell_count"] = live_terrain_art_nonzero_cell_count;
	phase["live_terrain_flag_cell_count"] = live_terrain_flag_cell_count;
	phase["post_queue_terrain_difference_count"] = post_queue_terrain_difference_count;
	phase["neighbor_mask_histogram"] = neighbor_mask_histogram;
	phase["selector_kind_histogram"] = selector_kind_histogram;
	phase["changed_cell_update_count"] = changed_cell_update_count;
	phase["initial_set_a_candidate_count"] = max_set_a_count;
	phase["initial_set_b_candidate_count"] = max_set_b_count;
	phase["total_set_a_insert_count"] = set_a_insert_count;
	phase["total_set_b_insert_count"] = set_b_insert_count;
	phase["set_a_drain_count"] = set_a_drain_count;
	phase["set_b_drain_count"] = set_b_drain_count;
	phase["set_b_candidate_true_count"] = set_b_candidate_true_count;
	phase["retouched_cell_write_count"] = retouched_cell_write_count;
	phase["drain_guard_limit"] = drain_guard_limit;
	phase["drain_guard_exhausted"] = drain_guard_count >= drain_guard_limit;
	phase["rng_state_after_live_visual_selection_uint32"] = int64_t(live_visual_rng.state);
	phase["seed_samples"] = seed_samples;
	phase["drain_samples"] = drain_samples;
	phase["sample_records"] = sample_records;
	phase["blocked_next"] = "private_0x49b2b6_tile_byte_writeback_candidate";
	if (out_zone_words != nullptr) {
		*out_zone_words = zone_words;
	}
	if (out_cell_flags != nullptr) {
		*out_cell_flags = cell_flags;
	}
	if (out_live_cell_word_0x24 != nullptr) {
		*out_live_cell_word_0x24 = live_cell_word_0x24;
	}
	if (out_live_cell_word_0x28 != nullptr) {
		*out_live_cell_word_0x28 = live_cell_word_0x28;
	}
	if (out_live_terrain_code != nullptr) {
		*out_live_terrain_code = live_terrain_code;
	}
	return phase;
}

Dictionary terrain_tile_byte_writeback_phase(const Dictionary &normalized_config, const Dictionary &live_feedback_phase, const std::vector<uint32_t> &live_cell_word_0x24, const std::vector<uint32_t> &live_cell_word_0x28, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "terrain_tile_byte_writeback";
	phase["h3maped_anchor"] = "0x49b2b6";
	phase["generated_cell_write_address"] = "0x49acf6";
	phase["serializer_contract"] = "byte0 = cell+0x24 bits0..5 terrain id; byte1 = cell+0x24 bits6..13 terrain art; byte6 bits0..1 = cell+0x28 bits15..16 terrain flags; river/road bytes remain pending";
	phase["status"] = "blocked_until_live_feedback";
	phase["materializes_private_tile_byte_candidates"] = true;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["road_river_bytes_materialized"] = false;
	phase["object_bytes_materialized"] = false;
	phase["blocked_next"] = "town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2";
	if (String(live_feedback_phase.get("status", "")) != "active_internal_state"
			|| live_cell_word_0x24.empty()
			|| live_cell_word_0x24.size() != live_cell_word_0x28.size()
			|| live_cell_word_0x24.size() != live_terrain_code.size()) {
		return phase;
	}

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t level_tile_count = map_width * map_height;
	const int32_t tile_count = int32_t(live_cell_word_0x24.size());
	Dictionary terrain_byte_histogram;
	Dictionary art_byte_histogram;
	Dictionary flag_byte_histogram;
	Array sample_tiles;
	int32_t terrain_mismatch_count = 0;
	int32_t art_nonzero_count = 0;
	int32_t flag_nonzero_count = 0;
	int32_t road_river_nonzero_count = 0;
	for (int32_t index = 0; index < tile_count; ++index) {
		const uint32_t word_0x24 = live_cell_word_0x24[size_t(index)];
		const uint32_t word_0x28 = live_cell_word_0x28[size_t(index)];
		const int32_t byte_0_terrain = int32_t(word_0x24 & 0x3fU);
		const int32_t byte_1_art = int32_t((word_0x24 >> 6U) & 0xffU);
		const int32_t byte_6_flags = int32_t((word_0x28 >> 15U) & 0x03U);
		const String terrain_key = String::num_int64(byte_0_terrain);
		const String art_key = String::num_int64(byte_1_art);
		const String flag_key = String::num_int64(byte_6_flags);
		terrain_byte_histogram[terrain_key] = int32_t(terrain_byte_histogram.get(terrain_key, 0)) + 1;
		art_byte_histogram[art_key] = int32_t(art_byte_histogram.get(art_key, 0)) + 1;
		flag_byte_histogram[flag_key] = int32_t(flag_byte_histogram.get(flag_key, 0)) + 1;
		if (byte_0_terrain != live_terrain_code[size_t(index)]) {
			terrain_mismatch_count += 1;
		}
		if (byte_1_art != 0) {
			art_nonzero_count += 1;
		}
		if (byte_6_flags != 0) {
			flag_nonzero_count += 1;
		}
		if (sample_tiles.size() < 16) {
			Dictionary sample;
			sample["index"] = index;
			sample["x"] = map_width > 0 ? index % map_width : 0;
			sample["y"] = map_width > 0 ? (index / map_width) % std::max(1, map_height) : 0;
			sample["level"] = level_tile_count > 0 ? index / level_tile_count : 0;
			sample["generated_cell_word_0x24_u32"] = int64_t(word_0x24);
			sample["generated_cell_word_0x28_u32"] = int64_t(word_0x28);
			sample["tile_byte_0_terrain_id"] = byte_0_terrain;
			sample["tile_byte_1_terrain_art"] = byte_1_art;
			sample["tile_byte_2_river_type"] = 0;
			sample["tile_byte_3_river_art"] = 0;
			sample["tile_byte_4_road_type"] = 0;
			sample["tile_byte_5_road_art"] = 0;
			sample["tile_byte_6_terrain_flags"] = byte_6_flags;
			sample_tiles.append(sample);
		}
	}

	phase["status"] = "active_internal_state";
	phase["source"] = "h3maped 0x49b2b6 terrain tile-byte projection from live 0x49acf6 generated-cell words; roads/rivers/objects and package/public adoption remain pending";
	phase["tile_count"] = tile_count;
	phase["terrain_byte_candidate_count"] = tile_count;
	phase["terrain_byte_mismatch_count"] = terrain_mismatch_count;
	phase["terrain_art_nonzero_cell_count"] = art_nonzero_count;
	phase["terrain_flag_nonzero_cell_count"] = flag_nonzero_count;
	phase["road_river_nonzero_byte_count"] = road_river_nonzero_count;
	phase["tile_byte_0_histogram"] = terrain_byte_histogram;
	phase["tile_byte_1_art_histogram"] = art_byte_histogram;
	phase["tile_byte_6_flag_histogram"] = flag_byte_histogram;
	phase["sample_tile_byte_records"] = sample_tiles;
	phase["sample_tile_byte_record_count"] = sample_tiles.size();
	phase["blocked_next"] = "town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2";
	return phase;
}

#endif

Dictionary town_castle_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &terrain_phase, const Dictionary &terrain_tile_byte_phase, const std::vector<uint32_t> &zone_words, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "town_castle_phase";
	phase["h3maped_anchor"] = "0x4a8d2c/0x4a8db2/0x4a93a2";
	phase["direct_object_helper_anchor"] = "0x4a93a2";
	phase["candidate_gate_anchor"] = "0x49aa93";
	phase["footprint_gate_anchor"] = "0x49a09c";
	phase["town_type_chooser_anchor"] = "0x49b3c1";
	phase["object_record_constructor_anchor"] = "0x49ba89";
	phase["town_vtable_anchor"] = "0x540a9c";
	phase["status"] = "blocked_until_terrain_tile_writeback";
	phase["materializes_private_town_candidates"] = true;
	phase["materializes_town_objects"] = false;
	phase["materializes_package_tiles"] = false;
	phase["adopts_into_runtime_grid"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "object_vector_prerequisite_phase_4a9d6a_4aab7e";
	const String runtime_status = String(runtime_zone_phase.get("status", ""));
	const String coordinate_status = String(coordinate_phase.get("status", ""));
	const String terrain_status = String(terrain_phase.get("status", ""));
	const String tile_status = String(terrain_tile_byte_phase.get("status", ""));
	if ((runtime_status != "active_internal_state" && runtime_status != "active_strict_executable_port")
			|| (coordinate_status != "active_internal_state" && coordinate_status != "active_strict_executable_port")
			|| (terrain_status != "active_internal_state" && terrain_status != "active_strict_executable_port")
			|| (tile_status != "active_internal_state" && tile_status != "active_strict_executable_port")
			|| zone_words.empty()
			|| zone_words.size() != live_terrain_code.size()) {
		return phase;
	}

	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = std::max(1, level_count(normalized_config));
	const int32_t cell_count = int32_t(zone_words.size());
	const int32_t expected_cell_count = map_width * map_height * map_level_count;
	Array runtime_zone_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array runtime_after_town_choice = coordinate_phase.get("runtime_zone_records_after_0x49b3c1", Array());
	Array selected_terrain_ids = terrain_phase.get("selected_h3maped_terrain_ids", Array());
	Array selected_project_terrain_ids = terrain_phase.get("selected_project_terrain_ids", Array());
	Array rng_events = coordinate_phase.get("rng_events", Array());

	Array town_choice_by_runtime;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		town_choice_by_runtime.append(-1);
	}
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

	Dictionary runtime_record_by_index;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		if (Variant(runtime_zone_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[index];
		runtime_record_by_index[String::num_int64(int64_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", index))))] = runtime;
	}

	Dictionary runtime_after_choice_by_index;
	for (int64_t index = 0; index < runtime_after_town_choice.size(); ++index) {
		if (Variant(runtime_after_town_choice[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_after_town_choice[index];
		runtime_after_choice_by_index[String::num_int64(int64_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", index))))] = runtime;
	}

	Dictionary scaled_by_runtime;
	Array scaled_coordinates = coordinate_phase.get("scaled_zone_coordinates", Array());
	for (int64_t index = 0; index < scaled_coordinates.size(); ++index) {
		if (Variant(scaled_coordinates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scaled = scaled_coordinates[index];
		scaled_by_runtime[String::num_int64(int64_t(scaled.get("runtime_zone_index", -1)))] = scaled;
	}

	Array scheduled_records;
	Array skipped_records;
	Array scheduled_owner_colors;
	int32_t source_player_min_town_count = 0;
	int32_t source_player_min_castle_count = 0;
	int32_t source_neutral_min_town_count = 0;
	int32_t source_neutral_min_castle_count = 0;
	int32_t assigned_player_min_town_count = 0;
	int32_t assigned_player_min_castle_count = 0;
	int32_t skipped_unassigned_player_start_min_town_count = 0;
	int32_t skipped_unassigned_player_start_min_castle_count = 0;
	int32_t neutral_minimum_town_castle_count = 0;
	int32_t density_schedule_count = 0;

	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		if (Variant(runtime_zone_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[index];
		const int32_t runtime_index = int32_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", index)));
		const int32_t owner_color = int32_t(runtime.get("actual_owner_color", -1));
		const int32_t player_min_towns = int32_t(runtime.get("player_min_towns", 0));
		const int32_t player_min_castles = int32_t(runtime.get("player_min_castles", runtime.get("min_player_castles", 0)));
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

	const String town_passability_mask = "000001110000011110001111111111111111111111111111";
	const String town_action_mask = "001000000000000000000000000000000000000000000000";
	const std::vector<H3MaskPoint> town_body_points = h3_text_mask_points(town_passability_mask, false);
	const std::vector<H3MaskPoint> town_action_points = h3_text_mask_points(town_action_mask, true);
	std::vector<uint8_t> object_occupied(size_t(std::max(0, expected_cell_count)), 0);

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
	H3MapedRng object_rng { uint32_t(int64_t(terrain_phase.get("rng_state_after_0x49b53d_uint32", coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0)))) };
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
		record["town_footprint_body_cell_count"] = int32_t(town_body_points.size());
		record["town_footprint_action_cell_count"] = int32_t(town_action_points.size());
		direct_candidate_scan_count += 1;

		if (map_width <= 0 || map_height <= 0 || expected_cell_count <= 0 || cell_count != expected_cell_count) {
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
		int32_t footprint_eligible_count = 0;
		int32_t footprint_rejected_bounds_count = 0;
		int32_t footprint_rejected_zone_count = 0;
		int32_t footprint_rejected_terrain_count = 0;
		int32_t footprint_rejected_collision_count = 0;
		int32_t closest_footprint_distance = 0x7fffffff;
		Array closest_footprint_candidates;

		for (int32_t level = 0; level < map_level_count; ++level) {
			if (level != anchor_level) {
				continue;
			}
			for (int32_t y = 0; y < map_height; ++y) {
				for (int32_t x = 0; x < map_width; ++x) {
					const int32_t cell_index = level * map_width * map_height + y * map_width + x;
					const uint32_t masked = zone_words[size_t(cell_index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != runtime_index) {
						continue;
					}
					const int32_t current_terrain_code = live_terrain_code[size_t(cell_index)] & 0x3f;
					if (current_terrain_code == 9) {
						continue;
					}
					const int32_t distance = h3maped_distance_truncate_local(anchor_x, anchor_y, x, y);
					candidate_count += 1;
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
						candidate["terrain_code_u16"] = current_terrain_code;
						closest_candidates.append(candidate);
					}

					bool footprint_passes = !town_body_points.empty();
					String footprint_reject_reason;
					for (const H3MaskPoint &point : town_body_points) {
						const int32_t body_x = x + point.dx;
						const int32_t body_y = y + point.dy;
						if (body_x < 0 || body_y < 0 || body_x >= map_width || body_y >= map_height) {
							footprint_passes = false;
							footprint_reject_reason = "out_of_bounds";
							break;
						}
						const int32_t body_index = level * map_width * map_height + body_y * map_width + body_x;
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
						const uint32_t body_masked = zone_words[size_t(body_index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
						if (body_masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((body_masked >> 16U) & 0xffU) != runtime_index) {
							footprint_passes = false;
							footprint_reject_reason = "zone_mismatch";
							break;
						}
						const int32_t body_terrain_code = live_terrain_code[size_t(body_index)] & 0x3f;
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
		record["closest_distance"] = candidate_count > 0 ? closest_distance : -1;
		record["closest_candidate_count"] = closest_candidates.size();
		record["closest_candidates"] = closest_candidates;
		record["footprint_eligible_count"] = footprint_eligible_count;
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
				record["status"] = "0x4a93a2_unique_closest_0x49aa93_town_footprint_candidate_record_projection_private";
				direct_unique_selection_count += 1;
			} else {
				random_tie_rng_value = object_rng.next();
				direct_random_tie_rng_call_count += 1;
				random_tie_selected_index = random_tie_rng_value % int32_t(closest_footprint_candidates.size());
				selected = closest_footprint_candidates[random_tie_selected_index];
				selected_from_random_tie = true;
				record["status"] = "0x4a93a2_random_tie_0x49aa93_town_footprint_candidate_record_projection_private";
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
				const int32_t body_index = body_level * map_width * map_height + body_y * map_width + body_x;
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
		Dictionary runtime = runtime_record_by_index.get(String::num_int64(runtime_index), Dictionary());
		Dictionary runtime_after_choice = runtime_after_choice_by_index.get(String::num_int64(runtime_index), Dictionary());

		Array body_tiles;
		for (const H3MaskPoint &point : town_body_points) {
			body_tiles.append(h3_cell_dictionary(x + point.dx, y + point.dy, level));
		}
		Array approach_tiles;
		for (const H3MaskPoint &point : town_action_points) {
			approach_tiles.append(h3_cell_dictionary(x + point.dx, y + point.dy, level));
		}

		Dictionary town_record;
		town_record["placement_id"] = String("native_rmg_town_start_") + slot_id;
		town_record["record_type"] = "player_start_town";
		town_record["kind"] = "town";
		town_record["town_id"] = town_id;
		town_record["faction_id"] = faction_id;
		town_record["owner"] = player_slot == 1 ? String("player") : String("enemy");
		town_record["owner_slot"] = player_slot;
		town_record["player_slot"] = player_slot;
		town_record["player_type"] = player_type;
		town_record["team_id"] = String("team_") + slot_id;
		town_record["zone_id"] = runtime.get("source_zone_id", h3_record.get("source_zone_id", -1));
		town_record["zone_role"] = runtime.get("role", "");
		town_record["runtime_zone_index"] = runtime_index;
		town_record["h3maped_town_choice_index"] = runtime_after_choice.get("town_choice_index", -1);
		town_record["h3maped_faction_id"] = runtime_after_choice.get("faction_id", "");
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
		start_record["start_id"] = String("player_start_") + String::num_int64(player_slot);
		start_record["player_slot"] = player_slot;
		start_record["owner_slot"] = player_slot;
		start_record["player_type"] = player_type;
		start_record["team_id"] = String("team_") + slot_id;
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
	direct_stamping["status"] = "0x4a93a2_0x49ba89_direct_town_object_stamping_projection_private";
	direct_stamping["source"] = "h3maped 0x4a93a2 scans matching generated-cell zone/source bytes, filters through 0x49aa93/0x49a09c, chooses closest candidates to the runtime-zone anchor with 0x4e7276 tie selection, then constructs 0x540a9c records through 0x49ba89";
	direct_stamping["terrain_grid_source"] = "0x4bb74b_0x4bc5f0_live_generated_cell_0x24_terrain";
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
	direct_stamping["blocked_next"] = "object_vector_prerequisite_phase_4a9d6a_4aab7e";

	Dictionary normalized_constraints = normalized_config.get("player_constraints", Dictionary());
	Dictionary project_town_adoption_candidate;
	project_town_adoption_candidate["schema_id"] = "aurelion_native_rmg_town_placement_v1";
	project_town_adoption_candidate["schema_version"] = 1;
	project_town_adoption_candidate["status"] = "h3maped_project_town_adoption_candidate_private";
	project_town_adoption_candidate["source"] = "private bridge from h3maped 0x49ba89 town records into project town/player-start schemas; public package adoption remains blocked until road/guard/object phases are ported";
	project_town_adoption_candidate["public_package_adoption"] = false;
	project_town_adoption_candidate["runtime_grid_adoption"] = false;
	project_town_adoption_candidate["town_record_count"] = project_town_records.size();
	project_town_adoption_candidate["player_start_count"] = project_player_starts.size();
	project_town_adoption_candidate["expected_player_count"] = int32_t(normalized_constraints.get("player_count", project_player_starts.size()));
	project_town_adoption_candidate["synchronized_player_start_count"] = synchronized_start_count;
	project_town_adoption_candidate["owner_slots"] = project_owner_slots;
	project_town_adoption_candidate["town_records"] = project_town_records;
	project_town_adoption_candidate["player_starts"] = project_player_starts;
	project_town_adoption_candidate["blocked_next"] = "object_vector_prerequisite_phase_4a9d6a_4aab7e";

	phase["status"] = "active_strict_executable_port";
	phase["source"] = "h3maped 0x4a8d2c/0x4a8db2 town/castle phase and 0x4a93a2 direct town record projection ported as private candidates only";
	phase["map_width"] = map_width;
	phase["map_height"] = map_height;
	phase["level_count"] = map_level_count;
	phase["cell_count"] = cell_count;
	phase["source_player_min_town_count"] = source_player_min_town_count;
	phase["source_player_min_castle_count"] = source_player_min_castle_count;
	phase["source_neutral_min_town_count"] = source_neutral_min_town_count;
	phase["source_neutral_min_castle_count"] = source_neutral_min_castle_count;
	phase["assigned_player_min_town_count"] = assigned_player_min_town_count;
	phase["assigned_player_min_castle_count"] = assigned_player_min_castle_count;
	phase["skipped_unassigned_player_start_min_town_count"] = skipped_unassigned_player_start_min_town_count;
	phase["skipped_unassigned_player_start_min_castle_count"] = skipped_unassigned_player_start_min_castle_count;
	phase["neutral_minimum_town_castle_count"] = neutral_minimum_town_castle_count;
	phase["density_schedule_count"] = density_schedule_count;
	phase["scheduled_direct_minimum_object_count"] = scheduled_records.size();
	phase["scheduled_owned_player_town_count"] = scheduled_records.size();
	phase["scheduled_owner_colors"] = scheduled_owner_colors;
	phase["scheduled_records"] = scheduled_records;
	phase["skipped_records"] = skipped_records;
	phase["direct_stamping_projection_status"] = direct_stamping.get("status", "");
	phase["direct_stamping_projection"] = direct_stamping;
	phase["project_town_adoption_candidate_status"] = project_town_adoption_candidate.get("status", "");
	phase["project_town_adoption_candidate"] = project_town_adoption_candidate;
	phase["project_town_record_candidate_count"] = project_town_records.size();
	phase["project_player_start_candidate_count"] = project_player_starts.size();
	phase["next_materialization_status"] = "pending_roads_guards_blockers_mines_rewards_and_final_h3maped_writeout_before_public_package_adoption";
	phase["blocked_next"] = "object_vector_prerequisite_phase_4a9d6a_4aab7e";
	return phase;
}

Array h3_object_limit_override_records(const H3ObjectLimitOverride *overrides, int32_t count, const char *source_range) {
	Array records;
	for (int32_t index = 0; index < count; ++index) {
		Dictionary record;
		record["source_range"] = source_range;
		record["type_id"] = overrides[index].type_id;
		record["limit"] = overrides[index].limit;
		records.append(record);
	}
	return records;
}

Dictionary h3_candidate_vector_order_segment(const char *segment, const char *source_range, int32_t first_index, int32_t record_count, bool records_materialized) {
	Dictionary record;
	record["segment"] = segment;
	record["source_range"] = source_range;
	record["first_candidate_vector_index"] = first_index;
	record["record_count"] = record_count;
	record["last_candidate_vector_index"] = record_count <= 0 ? first_index - 1 : first_index + record_count - 1;
	record["candidate_records_materialized"] = records_materialized;
	return record;
}

Dictionary h3_single_level_candidate_vector_order_boundary() {
	Dictionary boundary;
	boundary["status"] = "single_level_candidate_vector_order_materialized_public_commit_pending";
	boundary["source_range"] = "0x49f95a..0x4a1701";
	boundary["candidate_vector_offset"] = "generator+0x10f4..+0x10f8";
	boundary["single_level_total_candidate_record_count"] = 704;
	boundary["candidate_vector_indices_materialized"] = true;
	boundary["candidate_records_fully_materialized"] = false;
	boundary["extended_total_candidate_record_count_materialized"] = false;
	boundary["create_vfuncs_materialized"] = true;
	boundary["public_coordinate_commit_materialized"] = false;
	boundary["segments"] = Array::make(
			h3_candidate_vector_order_segment("static_prefix", "0x49f95a..0x49f9e5", 0, 2, true),
			h3_candidate_vector_order_segment("single_level_monster_loop", "0x49f9ed..0x49fa54", 2, 118, true),
			h3_candidate_vector_order_segment("fixed_type6_value_bands", "0x49fa54..0x49ff54", 120, 18, true),
			h3_candidate_vector_order_segment("type10_object_bucket_loop", "0x49ff59..0x4a00c7", 138, 40, true),
			h3_candidate_vector_order_segment("static_tail_before_type17", "0x4a00cc..0x4a03cf", 178, 14, true),
			h3_candidate_vector_order_segment("single_level_type17_loop", "0x4a0402..0x4a045a", 192, 58, true),
			h3_candidate_vector_order_segment("static_tail_after_type17", "0x4a0466..0x4a0eeb", 250, 47, true),
			h3_candidate_vector_order_segment("type53_object_bucket_loop", "0x4a0eeb..0x4a1194", 297, 378, true),
			h3_candidate_vector_order_segment("static_constructor_tail", "0x4a1194..0x4a1701", 675, 29, true));
	boundary["materialized_static_candidate_record_count"] = 110;
	boundary["materialized_single_level_monster_candidate_count"] = 118;
	boundary["materialized_type10_candidate_count"] = 40;
	boundary["materialized_type17_candidate_count"] = 58;
	boundary["materialized_type53_candidate_count"] = 378;
	boundary["first_type10_candidate_vector_index"] = 138;
	boundary["first_type17_candidate_vector_index"] = 192;
	boundary["first_type53_candidate_vector_index"] = 297;
	boundary["last_type53_candidate_vector_index"] = 674;
	boundary["first_static_constructor_tail_candidate_vector_index"] = 675;
	return boundary;
}

Array h3_monster_power_table() {
	return Array::make(5000, 7000, 9000, 12000, 16000, 21000, 27000);
}

int32_t h3_monster_candidate_quantity_bucket(int32_t raw_value) {
	if (raw_value > 50) {
		return ((raw_value + 5) / 10) * 10;
	}
	if (raw_value > 12) {
		return ((raw_value + 2) / 5) * 5;
	}
	if (raw_value > 5) {
		return ((raw_value + 1) / 2) * 2;
	}
	return raw_value;
}

Dictionary h3_single_level_monster_candidate_summary() {
	Dictionary boundary;
	boundary["status"] = "single_level_monster_candidate_loop_materialized_from_crtraits_and_static_table";
	boundary["source_range"] = "0x49f9ed..0x49fa54";
	boundary["crtraits_loader_address"] = "0x40cc46";
	boundary["table_initializer_address"] = "0x40ce11";
	boundary["constructor_address"] = "0x49c5cd";
	boundary["table_address"] = "0x57cea0";
	boundary["table_pointer_address"] = "0x581298";
	boundary["record_stride_bytes"] = 0x74;
	boundary["source_crtraits_path"] = CRTRAITS_SOURCE_PATH;
	boundary["source_crtraits_lod"] = "H3ab_bmp.lod";
	boundary["loop_iteration_order"] = "descending_monster_index";
	boundary["single_level_iteration_count"] = 0x76;
	boundary["first_candidate_vector_index"] = 2;
	boundary["power_table_address"] = "0x58dc08";
	boundary["power_table"] = h3_monster_power_table();
	boundary["extended_monster_loop_materialized"] = false;

	Array sample_records;
	if (!FileAccess::file_exists(CRTRAITS_SOURCE_PATH)) {
		boundary["load_status"] = "missing_crtraits_source";
		boundary["candidate_record_count"] = 0;
		boundary["records_sample"] = sample_records;
		return boundary;
	}
	if (!FileAccess::file_exists(BINARY_PATH)) {
		boundary["load_status"] = "missing_h3maped_binary";
		boundary["candidate_record_count"] = 0;
		boundary["records_sample"] = sample_records;
		return boundary;
	}
	Ref<FileAccess> crtraits_file = FileAccess::open(CRTRAITS_SOURCE_PATH, FileAccess::READ);
	Ref<FileAccess> binary_file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (crtraits_file.is_null() || !crtraits_file->is_open() || binary_file.is_null() || !binary_file->is_open()) {
		boundary["load_status"] = "unreadable_source";
		boundary["candidate_record_count"] = 0;
		boundary["records_sample"] = sample_records;
		return boundary;
	}

	const std::vector<std::vector<String>> crtraits_rows = parse_h3maped_tsv(crtraits_file->get_as_text());
	const std::vector<std::pair<int32_t, int32_t>> row_walk = h3maped_crtraits_monster_row_walk();
	static constexpr int32_t POWER_TABLE[] = { 5000, 7000, 9000, 12000, 16000, 21000, 27000 };
	int32_t missing_source_row_count = 0;
	int32_t inactive_gate_count = 0;
	int32_t invalid_ai_value_count = 0;
	int32_t candidate_record_count = 0;
	for (int32_t loop_index = 0x76 - 1; loop_index >= 0; --loop_index) {
		if (loop_index >= int32_t(row_walk.size())) {
			++missing_source_row_count;
			continue;
		}
		const int32_t monster_index = row_walk[size_t(loop_index)].first;
		const int32_t source_row_index = row_walk[size_t(loop_index)].second;
		if (source_row_index < 0 || source_row_index >= int32_t(crtraits_rows.size())) {
			++missing_source_row_count;
			continue;
		}
		int32_t terrain_id = -1;
		int32_t tier_index = -1;
		const int64_t table_va = 0x57cea0 + int64_t(monster_index) * 0x74;
		if (!read_h3maped_i32_le(binary_file, table_va, terrain_id) || !read_h3maped_i32_le(binary_file, table_va + 0x04, tier_index)) {
			++missing_source_row_count;
			continue;
		}
		if (tier_index < 0) {
			++inactive_gate_count;
			continue;
		}
		int32_t ai_value = 0;
		if (crtraits_rows[size_t(source_row_index)].size() <= 10 || !parse_int_field(crtraits_rows[size_t(source_row_index)][10], ai_value) || ai_value <= 0 || tier_index >= int32_t(sizeof(POWER_TABLE) / sizeof(POWER_TABLE[0]))) {
			++invalid_ai_value_count;
			continue;
		}
		const int32_t raw_quantity = POWER_TABLE[tier_index] / ai_value;
		const int32_t quantity_bucket = h3_monster_candidate_quantity_bucket(raw_quantity);
		if (sample_records.size() < 6 || loop_index < 3) {
			Dictionary record;
			record["candidate_vector_index"] = 2 + candidate_record_count;
			record["source_address"] = "0x49f9ed";
			record["vtable_address"] = "0x540bc0";
			record["record_size_bytes"] = 0x1c;
			record["type_id"] = 6;
			record["monster_table_index"] = monster_index;
			record["crtraits_source_row_index"] = source_row_index;
			record["monster_terrain_id"] = terrain_id;
			record["monster_tier_index"] = tier_index;
			record["monster_ai_value"] = ai_value;
			record["raw_quantity_division"] = raw_quantity;
			record["candidate_record_field_0x18"] = quantity_bucket;
			record["crtraits_name_fields_omitted"] = true;
			sample_records.append(record);
		}
		++candidate_record_count;
	}
	boundary["load_status"] = "loaded";
	boundary["crtraits_csv_row_count"] = int32_t(crtraits_rows.size());
	boundary["crtraits_monster_row_walk_count"] = int32_t(row_walk.size());
	boundary["candidate_record_count"] = candidate_record_count;
	boundary["missing_source_row_count"] = missing_source_row_count;
	boundary["inactive_gate_count"] = inactive_gate_count;
	boundary["invalid_ai_value_count"] = invalid_ai_value_count;
	boundary["last_candidate_vector_index"] = candidate_record_count <= 0 ? -1 : 2 + candidate_record_count - 1;
	boundary["records_sample"] = sample_records;
	return boundary;
}

Dictionary h3_candidate_selector_boundary() {
	static constexpr H3ObjectLimitOverride GLOBAL_LIMIT_OVERRIDES[] = {
		{ 26, 200 }, { 6, 200 }, { 57, 48 }, { 8, 64 }, { 100, 32 }, { 23, 32 },
		{ 32, 32 }, { 51, 32 }, { 61, 32 }, { 102, 32 }, { 41, 32 }, { 4, 32 },
		{ 47, 32 }, { 107, 32 }, { 104, 32 }, { 113, 32 }, { 88, 32 }, { 89, 32 },
		{ 90, 32 }, { 92, 32 }, { 55, 32 }, { 109, 32 }, { 112, 32 }, { 48, 32 },
		{ 22, 32 }, { 39, 32 }, { 108, 32 }, { 105, 32 }, { 83, 48 }, { 7, 32 },
	};
	static constexpr H3ObjectLimitOverride PER_ZONE_LIMIT_OVERRIDES[] = {
		{ 2, 1 }, { 13, 1 }, { 14, 1 }, { 15, 1 }, { 27, 1 }, { 28, 1 },
		{ 30, 1 }, { 31, 1 }, { 35, 1 }, { 38, 1 }, { 42, 1 }, { 48, 1 },
		{ 49, 1 }, { 56, 1 }, { 58, 1 }, { 60, 1 }, { 64, 1 }, { 80, 1 },
		{ 94, 1 }, { 96, 1 }, { 99, 1 }, { 106, 1 }, { 110, 1 }, { 113, 3 },
	};

	Dictionary boundary;
	boundary["status"] = "selector_scan_weighted_choice_materialized_coordinate_commit_boundary_materialized_private_record_pending";
	boundary["source_range"] = "0x4a9f1c..0x4aa192";
	boundary["candidate_vector_source"] = "generator+0x10f4..+0x10f8";
	boundary["candidate_vector_builder_address"] = "0x49f95a";
	boundary["candidate_pointer_stride_bytes"] = 4;
	boundary["candidate_weight_offset"] = "+0x10";
	boundary["candidate_type_offset"] = "+0x04";
	boundary["candidate_subtype_offset"] = "+0x08";
	boundary["placed_count_array_offset"] = "generator+0x1110";
	boundary["global_limit_table_address"] = "0x5a26e4";
	boundary["per_zone_limit_table_address"] = "0x5a2a8c";
	boundary["global_limit_override_count"] = int32_t(sizeof(GLOBAL_LIMIT_OVERRIDES) / sizeof(GLOBAL_LIMIT_OVERRIDES[0]));
	boundary["per_zone_limit_override_count"] = int32_t(sizeof(PER_ZONE_LIMIT_OVERRIDES) / sizeof(PER_ZONE_LIMIT_OVERRIDES[0]));
	boundary["global_limit_overrides"] = h3_object_limit_override_records(GLOBAL_LIMIT_OVERRIDES, int32_t(sizeof(GLOBAL_LIMIT_OVERRIDES) / sizeof(GLOBAL_LIMIT_OVERRIDES[0])), "0x540758..0x540840");
	boundary["per_zone_limit_overrides"] = h3_object_limit_override_records(PER_ZONE_LIMIT_OVERRIDES, int32_t(sizeof(PER_ZONE_LIMIT_OVERRIDES) / sizeof(PER_ZONE_LIMIT_OVERRIDES[0])), "0x540848..0x540900");
	boundary["metadata_table_pointer_address"] = "0x57c648";
	boundary["metadata_table_address"] = "0x598300";
	boundary["metadata_record_size_bytes"] = 0x10;
	boundary["metadata_primary_gate_offset"] = "+0x00";
	boundary["metadata_secondary_gate_offset"] = "+0x02";
	boundary["candidate_disabled_vfunc_offset"] = "+0x08";
	boundary["candidate_value_vfunc_offset"] = "+0x04";
	boundary["candidate_create_vfunc_offset"] = "+0x00";
	boundary["template_selector_address"] = "0x4a9e40";
	boundary["collision_helper_address"] = "0x49a6f9";
	boundary["weighted_rng_address"] = "0x4e7276";
	boundary["selector_materialized"] = true;
	boundary["weighted_choice_materialized"] = true;
	boundary["create_call_materialized"] = true;
	boundary["runtime_reward_coordinate_commit_boundary_materialized"] = true;
	boundary["runtime_reward_coordinate_commit_materialized"] = false;
	boundary["public_object_materialization_allowed"] = false;
	boundary["remaining_blocker"] = "materialize_private_reward_coordinate_records_and_reward_object_adoption";
	return boundary;
}

Dictionary object_vector_prerequisite_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &terrain_phase, const Dictionary &town_castle_phase, const std::vector<uint32_t> &zone_words, const std::vector<uint8_t> &cell_flags, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "mines_rewards_and_object_vector";
	phase["status"] = "blocked_until_town_castle_phase";
	phase["h3maped_anchor"] = "0x4a9d6a/0x4a9911/0x4a9641/0x4a9c7c/0x4aab7e/0x4aa354/0x4a9f1c/0x4aa9b7";
	phase["mine_phase_anchor"] = "0x4a9d6a";
	phase["mine_coordinate_attempt_anchor"] = "0x4a9911/0x4a9641";
	phase["reward_scheduler_anchor"] = "0x4aab7e/0x4aa354";
	phase["candidate_vector_builder_anchor"] = "0x49f95a..0x4a1701";
	phase["candidate_selector_anchor"] = "0x4a9f1c";
	phase["reward_coordinate_anchor"] = "0x4aa9b7";
	phase["materializes_private_object_vector_prerequisites"] = true;
	phase["materializes_private_mine_records"] = false;
	phase["materializes_private_reward_coordinate_records"] = false;
	phase["materializes_public_objects"] = false;
	phase["adopts_into_runtime_grid"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9";
	const String runtime_status = String(runtime_zone_phase.get("status", ""));
	const String town_status = String(town_castle_phase.get("status", ""));
	if ((runtime_status != "active_internal_state" && runtime_status != "active_strict_executable_port")
			|| (town_status != "active_internal_state" && town_status != "active_strict_executable_port")) {
		return phase;
	}

	Array runtime_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array selected_terrain_ids = terrain_phase.get("selected_h3maped_terrain_ids", Array());
	Array scaled_coordinates = coordinate_phase.get("scaled_zone_coordinates", Array());
	Dictionary scaled_by_runtime;
	for (int64_t index = 0; index < scaled_coordinates.size(); ++index) {
		if (Variant(scaled_coordinates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary scaled = scaled_coordinates[index];
		scaled_by_runtime[String::num_int64(int64_t(scaled.get("runtime_zone_index", -1)))] = scaled;
	}
	const int32_t map_width = width(normalized_config);
	const int32_t map_height = height(normalized_config);
	const int32_t map_level_count = std::max(1, level_count(normalized_config));
	const int32_t expected_cell_count = map_width * map_height * map_level_count;
	const bool grid_available = map_width > 0
			&& map_height > 0
			&& expected_cell_count == int32_t(zone_words.size())
			&& zone_words.size() == cell_flags.size()
			&& zone_words.size() == live_terrain_code.size();
	std::vector<uint8_t> object_occupied(size_t(std::max(0, expected_cell_count)), 0);
	Dictionary town_adoption = town_castle_phase.get("project_town_adoption_candidate", Dictionary());
	Array town_records = town_adoption.get("town_records", Array());
	for (int64_t town_index = 0; town_index < town_records.size(); ++town_index) {
		if (Variant(town_records[town_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary town = town_records[town_index];
		Array body_tiles = town.get("body_tiles", Array());
		for (int64_t body_index = 0; body_index < body_tiles.size(); ++body_index) {
			if (Variant(body_tiles[body_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary body = body_tiles[body_index];
			const int32_t body_x = int32_t(body.get("x", -1));
			const int32_t body_y = int32_t(body.get("y", -1));
			const int32_t body_level = int32_t(body.get("level", 0));
			const int64_t flat = h3maped_cell_index(map_width, map_height, body_x, body_y, body_level);
			if (flat >= 0 && flat < expected_cell_count) {
				object_occupied[size_t(flat)] = 1;
			}
		}
	}
	static constexpr const char *MINE_KEYS[] = {
		"wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold",
	};
	Dictionary minimum_by_category;
	Dictionary density_by_category;
	for (const char *key : MINE_KEYS) {
		minimum_by_category[key] = 0;
		density_by_category[key] = 0;
	}
	Array zone_mine_records;
	Array reward_scheduler_preview;
	int32_t total_minimum_mine_count = 0;
	int32_t total_density_weight = 0;
	int32_t total_treasure_band_count = 0;
	int32_t eligible_reward_band_count = 0;
	int32_t reward_density_sum = 0;
	for (int64_t index = 0; index < runtime_records.size(); ++index) {
		if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[index];
		Dictionary mine_record;
		mine_record["runtime_zone_index"] = runtime.get("runtime_zone_index", runtime.get("runtime_index", index));
		mine_record["source_zone_id"] = runtime.get("source_zone_id", -1);
		mine_record["actual_owner_color"] = runtime.get("actual_owner_color", -1);
		mine_record["monster_strength"] = runtime.get("monster_strength", "");
		int32_t zone_minimum_total = 0;
		int32_t zone_density_total = 0;
		for (const char *key : MINE_KEYS) {
			const String min_key = String("minimum_") + key + "_mines";
			const String density_key = String("mine_density_") + key;
			const int32_t minimum = int32_t(runtime.get(min_key, 0));
			const int32_t density = int32_t(runtime.get(density_key, 0));
			minimum_by_category[key] = int32_t(minimum_by_category.get(key, 0)) + minimum;
			density_by_category[key] = int32_t(density_by_category.get(key, 0)) + density;
			mine_record[min_key] = minimum;
			mine_record[density_key] = density;
			zone_minimum_total += minimum;
			zone_density_total += density;
		}
		mine_record["minimum_total"] = zone_minimum_total;
		mine_record["density_total"] = zone_density_total;
		mine_record["private_coordinate_attempts_materialized"] = false;
		zone_mine_records.append(mine_record);
		total_minimum_mine_count += zone_minimum_total;
		total_density_weight += zone_density_total;

		Array bands = runtime.get("treasure_bands", Array());
		int32_t zone_eligible_count = 0;
		int32_t zone_density_sum = 0;
		for (int64_t band_index = 0; band_index < bands.size(); ++band_index) {
			if (Variant(bands[band_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary band = bands[band_index];
			const int32_t low = int32_t(band.get("low", 0));
			const int32_t high = int32_t(band.get("high", 0));
			const int32_t density = int32_t(band.get("density", 0));
			total_treasure_band_count += 1;
			if (low >= 100 && high >= low && density > 0) {
				zone_eligible_count += 1;
				zone_density_sum += density;
				eligible_reward_band_count += 1;
				reward_density_sum += density;
			}
		}
		Dictionary reward_zone;
		reward_zone["runtime_zone_index"] = runtime.get("runtime_zone_index", runtime.get("runtime_index", index));
		reward_zone["source_zone_id"] = runtime.get("source_zone_id", -1);
		reward_zone["treasure_band_count"] = bands.size();
		reward_zone["eligible_reward_band_count"] = zone_eligible_count;
		reward_zone["eligible_reward_density_sum"] = zone_density_sum;
		reward_zone["scheduler_status"] = zone_eligible_count > 0 ? String("0x4aab7e_reward_band_budget_preview_private") : String("0x4aab7e_no_eligible_reward_band");
		reward_zone["coordinate_commit_materialized"] = false;
		reward_scheduler_preview.append(reward_zone);
	}

	struct MineField {
		const char *name;
		const char *resource;
		int32_t subtype;
		const char *minimum_key;
		const char *density_key;
		const char *minimum_offset;
		const char *density_offset;
		int32_t guard_base_value;
	};
	static constexpr MineField MINE_FIELDS[] = {
		{ "wood", "timber", 0, "minimum_wood_mines", "mine_density_wood", "+0x4c", "+0x68", 1500 },
		{ "mercury", "quicksilver", 1, "minimum_mercury_mines", "mine_density_mercury", "+0x50", "+0x6c", 3500 },
		{ "ore", "ore", 2, "minimum_ore_mines", "mine_density_ore", "+0x54", "+0x70", 1500 },
		{ "sulfur", "ember_salt", 3, "minimum_sulfur_mines", "mine_density_sulfur", "+0x58", "+0x74", 3500 },
		{ "crystal", "lens_crystal", 4, "minimum_crystal_mines", "mine_density_crystal", "+0x5c", "+0x78", 3500 },
		{ "gems", "cut_gems", 5, "minimum_gems_mines", "mine_density_gems", "+0x60", "+0x7c", 3500 },
		{ "gold", "gold", 6, "minimum_gold_mines", "mine_density_gold", "+0x64", "+0x80", 7000 },
	};
	Dictionary mine_template_catalog_load;
	std::vector<H3ObjectRow> mine_template_rows = h3_object_rows_by_type_from_recovered_catalog(53, mine_template_catalog_load);
	Array mine_placement_records;
	Array mine_coordinate_records;
	int32_t mine_template_selection_rng_call_count = 0;
	int32_t mine_placement_rng_call_count = 0;
	int32_t mine_placement_scan_call_count = 0;
	int32_t mine_placement_candidate_total = 0;
	int32_t mine_placement_selected_count = 0;
	int32_t mine_placement_rejected_owner_count = 0;
	int32_t mine_placement_rejected_footprint_count = 0;
	int32_t mine_placement_rejected_special_distance_count = 0;
	int32_t mine_placement_marked_body_cell_count = 0;
	Dictionary direct_stamping = town_castle_phase.get("direct_stamping_projection", Dictionary());
	H3MapedRng object_rng { uint32_t(int64_t(direct_stamping.get("object_rng_state_after_0x4a93a2_uint32", 0))) };
	const uint32_t object_rng_state_before = object_rng.state;

	for (int64_t zone_index = 0; zone_index < runtime_records.size(); ++zone_index) {
		if (Variant(runtime_records[zone_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[zone_index];
		const int32_t runtime_index = int32_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", zone_index)));
		const int32_t runtime_terrain_id = runtime_index >= 0 && runtime_index < selected_terrain_ids.size() ? int32_t(selected_terrain_ids[runtime_index]) : -1;
		Dictionary scaled = scaled_by_runtime.get(String::num_int64(runtime_index), Dictionary());
		const int32_t anchor_x = int32_t(scaled.get("x_after_bbox_rescale", 0));
		const int32_t anchor_y = int32_t(scaled.get("y_after_bbox_rescale", 0));
		const int32_t anchor_level = int32_t(scaled.get("level", 0));
		bool has_town_record_in_zone = false;
		for (int64_t town_index = 0; town_index < town_records.size(); ++town_index) {
			if (Variant(town_records[town_index]).get_type() == Variant::DICTIONARY && int32_t(Dictionary(town_records[town_index]).get("runtime_zone_index", -1)) == runtime_index) {
				has_town_record_in_zone = true;
				break;
			}
		}

		for (const MineField &field : MINE_FIELDS) {
			const int32_t minimum_count = int32_t(runtime.get(field.minimum_key, 0));
			for (int32_t ordinal = 0; ordinal < minimum_count; ++ordinal) {
				Dictionary placement;
				placement["phase"] = "0x4a9911_0x4a9641_mine_minimum_private_placement";
				placement["runtime_zone_index"] = runtime_index;
				placement["source_zone_id"] = runtime.get("source_zone_id", -1);
				placement["source_field_offset"] = field.minimum_offset;
				placement["category_name"] = field.name;
				placement["resource_category_id"] = field.resource;
				placement["mine_subtype"] = field.subtype;
				placement["native_proxy_object_id"] = native_mine_proxy_object_id_for_subtype(field.subtype);
				placement["ordinal"] = ordinal;
				placement["template_bucket_offset"] = "generator+0x388..+0x38c";
				placement["template_selector_address"] = "0x4a9911";
				placement["constraint_scan_address"] = "0x4a9641";
				placement["footprint_gate_address"] = "0x49a09c";
				placement["cell_validity_address"] = "0x49a1d8";
				placement["object_record_constructor"] = "0x49ba89";
				placement["object_record_vtable"] = "0x540ab0";
				placement["runtime_package_adoption"] = false;
				placement["public_object_materialization"] = false;
				placement["runtime_h3maped_terrain_id"] = runtime_terrain_id;
				std::vector<H3ObjectRow> terrain_filtered_templates = filtered_h3_object_rows_for_subtype_and_terrain(mine_template_rows, field.subtype, runtime_terrain_id);
				placement["matched_template_count_after_terrain_filter"] = int32_t(terrain_filtered_templates.size());
				if (terrain_filtered_templates.empty() || !grid_available) {
					placement["status"] = terrain_filtered_templates.empty() ? String("blocked_no_0x42cc99_terrain_matching_mine_template_rows") : String("blocked_missing_generated_cell_grid");
					mine_placement_records.append(placement);
					continue;
				}

				const int32_t template_rng_value = object_rng.next();
				mine_template_selection_rng_call_count += 1;
				const int32_t selected_template_index = template_rng_value % int32_t(terrain_filtered_templates.size());
				const H3ObjectRow &selected_template = terrain_filtered_templates[size_t(selected_template_index)];
				const std::vector<H3MaskPoint> mine_body_points = h3_text_mask_points(selected_template.passability_mask, false);
				placement["selected_template_rng_value"] = template_rng_value;
				placement["selected_template_index"] = selected_template_index;
				placement["selected_template_source_line"] = selected_template.source_line;
				placement["selected_template_def_name"] = selected_template.def_name;
				placement["selected_template_body_cell_count"] = int32_t(mine_body_points.size());

				int32_t min_x = map_width;
				int32_t min_y = map_height;
				int32_t max_x_exclusive = 0;
				int32_t max_y_exclusive = 0;
				for (int32_t level = 0; level < map_level_count; ++level) {
					if (level != anchor_level) {
						continue;
					}
					for (int32_t y = 0; y < map_height; ++y) {
						for (int32_t x = 0; x < map_width; ++x) {
							const int64_t flat = h3maped_cell_index(map_width, map_height, x, y, level);
							if (flat < 0 || flat >= expected_cell_count) {
								continue;
							}
							const uint32_t masked = zone_words[size_t(flat)] & H3MAPED_UNASSIGNED_ZONE_WORD;
							if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != runtime_index) {
								continue;
							}
							min_x = std::min(min_x, x);
							min_y = std::min(min_y, y);
							max_x_exclusive = std::max(max_x_exclusive, x + 1);
							max_y_exclusive = std::max(max_y_exclusive, y + 1);
						}
					}
				}
				const bool bbox_found = min_x < max_x_exclusive && min_y < max_y_exclusive;
				if (!bbox_found) {
					min_x = 0;
					min_y = 0;
					max_x_exclusive = map_width;
					max_y_exclusive = map_height;
				}
				const bool special_distance_mode = (field.subtype == 0 || field.subtype == 2)
						&& int32_t(runtime.get("source_bucket", -1)) >= 0
						&& int32_t(runtime.get("source_bucket", -1)) <= 1
						&& has_town_record_in_zone;
				placement["placement_constraint_bbox_found"] = bbox_found;
				placement["placement_constraint_special_distance_mode"] = special_distance_mode;
				mine_placement_scan_call_count += 1;

				struct MinePlacementCandidate {
					int32_t x = -1;
					int32_t y = -1;
					int32_t level = -1;
					int32_t score = 0;
					int32_t neighbor_count = 0;
					int32_t distance_squared = 0;
					int32_t clamped_distance = 0;
				};
				std::vector<MinePlacementCandidate> tied_candidates;
				int32_t owner_match_count = 0;
				int32_t eligible_candidate_count = 0;
				int32_t rejected_owner_count = 0;
				int32_t rejected_footprint_count = 0;
				int32_t rejected_special_distance_count = 0;
				int32_t best_score = -1;
				int32_t best_neighbor_count = -1;
				int32_t best_clamped_distance = 0x9c40;
				for (int32_t y = min_y; y < max_y_exclusive; ++y) {
					for (int32_t x = min_x; x < max_x_exclusive; ++x) {
						const int64_t flat = h3maped_cell_index(map_width, map_height, x, y, anchor_level);
						if (flat < 0 || flat >= expected_cell_count) {
							continue;
						}
						const uint32_t masked = zone_words[size_t(flat)] & H3MAPED_UNASSIGNED_ZONE_WORD;
						if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != runtime_index) {
							rejected_owner_count += 1;
							continue;
						}
						owner_match_count += 1;
						const H3FootprintGateResult footprint = h3maped_49a09c_circular_mask_gate(mine_body_points, zone_words, cell_flags, live_terrain_code, object_occupied, map_width, map_height, map_level_count, x, y, anchor_level, runtime_index, false);
						if (!footprint.pass) {
							rejected_footprint_count += 1;
							continue;
						}
						const int32_t dx_from_anchor = x - anchor_x;
						const int32_t dy_from_anchor = y - anchor_y;
						const int32_t distance_squared = dx_from_anchor * dx_from_anchor + dy_from_anchor * dy_from_anchor;
						int32_t clamped_distance = distance_squared;
						if (special_distance_mode) {
							if (distance_squared < 0x10 || distance_squared > best_clamped_distance) {
								rejected_special_distance_count += 1;
								continue;
							}
							clamped_distance = std::max(distance_squared, 0x90);
						}
						int32_t neighbor_count = 0;
						for (const H3MaskPoint &point : mine_body_points) {
							const int64_t body_flat = h3maped_cell_index(map_width, map_height, x + point.dx, y + point.dy, anchor_level);
							if (body_flat >= 0 && body_flat < expected_cell_count && (live_terrain_code[size_t(body_flat)] & 0x3f) != 9) {
								neighbor_count += 1;
								if (neighbor_count >= 5) {
									neighbor_count = 5;
									break;
								}
							}
						}
						const int32_t score = int32_t(zone_words[size_t(flat)] & 0xffffU);
						bool keep_candidate = false;
						if (special_distance_mode && clamped_distance < best_clamped_distance) {
							best_clamped_distance = clamped_distance;
							best_score = score;
							best_neighbor_count = neighbor_count;
							tied_candidates.clear();
							keep_candidate = true;
						} else if ((!special_distance_mode || clamped_distance == best_clamped_distance)
								&& (score > best_score || (score == best_score && neighbor_count > best_neighbor_count))) {
							best_score = score;
							best_neighbor_count = neighbor_count;
							tied_candidates.clear();
							keep_candidate = true;
						} else if ((!special_distance_mode || clamped_distance == best_clamped_distance)
								&& score == best_score
								&& neighbor_count == best_neighbor_count) {
							keep_candidate = true;
						}
						if (keep_candidate) {
							tied_candidates.push_back(MinePlacementCandidate { x, y, anchor_level, score, neighbor_count, distance_squared, clamped_distance });
						}
						eligible_candidate_count += 1;
					}
				}
				mine_placement_candidate_total += eligible_candidate_count;
				mine_placement_rejected_owner_count += rejected_owner_count;
				mine_placement_rejected_footprint_count += rejected_footprint_count;
				mine_placement_rejected_special_distance_count += rejected_special_distance_count;
				placement["placement_constraint_owner_match_count"] = owner_match_count;
				placement["placement_constraint_candidate_count"] = eligible_candidate_count;
				placement["placement_constraint_rejected_owner_count"] = rejected_owner_count;
				placement["placement_constraint_rejected_49aa93_count"] = rejected_footprint_count;
				placement["placement_constraint_rejected_special_distance_count"] = rejected_special_distance_count;
				placement["placement_constraint_tied_candidate_count"] = int32_t(tied_candidates.size());
				if (tied_candidates.empty()) {
					placement["status"] = "0x4a9641_candidate_scan_executed_no_candidates";
					mine_placement_records.append(placement);
					continue;
				}
				const int32_t placement_rng_value = object_rng.next();
				mine_placement_rng_call_count += 1;
				const int32_t selected_index = placement_rng_value % int32_t(tied_candidates.size());
				const MinePlacementCandidate &selected = tied_candidates[size_t(selected_index)];
				int32_t marked_cells = 0;
				Array stamped_body_cells;
				for (const H3MaskPoint &point : mine_body_points) {
					const int32_t body_x = selected.x + point.dx;
					const int32_t body_y = selected.y + point.dy;
					const int64_t body_flat = h3maped_cell_index(map_width, map_height, body_x, body_y, selected.level);
					if (body_flat >= 0 && body_flat < expected_cell_count && object_occupied[size_t(body_flat)] == 0) {
						object_occupied[size_t(body_flat)] = 1;
						marked_cells += 1;
						if (stamped_body_cells.size() < 12) {
							stamped_body_cells.append(h3_cell_dictionary(body_x, body_y, selected.level));
						}
					}
				}
				mine_placement_selected_count += 1;
				mine_placement_marked_body_cell_count += marked_cells;
				placement["status"] = "0x4a9911_0x4a9641_mine_coordinate_record_projected_private";
				placement["placement_constraint_rng_value"] = placement_rng_value;
				placement["placement_constraint_selected_index"] = selected_index;
				placement["placement_constraint_selected_x"] = selected.x;
				placement["placement_constraint_selected_y"] = selected.y;
				placement["placement_constraint_selected_level"] = selected.level;
				placement["placement_constraint_selected_score_low_word"] = selected.score;
				placement["placement_constraint_selected_neighbor_count"] = selected.neighbor_count;
				placement["placement_constraint_selected_distance_squared"] = selected.distance_squared;
				placement["placement_constraint_marked_body_cell_count"] = marked_cells;
				placement["placement_constraint_marked_body_cell_preview"] = stamped_body_cells;
				Dictionary coordinate_record;
				coordinate_record["vector_index"] = town_records.size() + mine_coordinate_records.size();
				coordinate_record["byte_offset_from_begin"] = int32_t(coordinate_record.get("vector_index", 0)) * 12;
				coordinate_record["record_size_bytes"] = 12;
				coordinate_record["phase"] = "0x4a9911_0x4a9641_mine_minimum";
				coordinate_record["append_address"] = "0x4ae1fd";
				coordinate_record["source_kind"] = "mine";
				coordinate_record["source_runtime_zone_index"] = runtime_index;
				coordinate_record["source_zone_id"] = runtime.get("source_zone_id", -1);
				coordinate_record["mine_subtype"] = field.subtype;
				coordinate_record["resource_category_id"] = field.resource;
				coordinate_record["native_proxy_object_id"] = native_mine_proxy_object_id_for_subtype(field.subtype);
				coordinate_record["x"] = selected.x;
				coordinate_record["y"] = selected.y;
				coordinate_record["level"] = selected.level;
				coordinate_record["coordinate_triplet"] = Array::make(selected.x, selected.y, selected.level);
				coordinate_record["complete_executable_vector_claim"] = false;
				mine_coordinate_records.append(coordinate_record);
				mine_placement_records.append(placement);
			}
		}
	}

	Dictionary mine_requirements;
	mine_requirements["source_category_order"] = Array::make("wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold");
	mine_requirements["minimum_by_category"] = minimum_by_category;
	mine_requirements["density_by_category"] = density_by_category;
	mine_requirements["runtime_zone_record_count"] = zone_mine_records.size();
	mine_requirements["zone_records"] = zone_mine_records;
	mine_requirements["total_minimum_mine_count"] = total_minimum_mine_count;
	mine_requirements["total_density_weight"] = total_density_weight;
	mine_requirements["private_coordinate_attempts_materialized"] = true;
	mine_requirements["mine_template_catalog_load"] = mine_template_catalog_load;
	mine_requirements["mine_template_row_count"] = int32_t(mine_template_rows.size());
	mine_requirements["mine_template_selection_rng_call_count"] = mine_template_selection_rng_call_count;
	mine_requirements["mine_placement_rng_call_count"] = mine_placement_rng_call_count;
	mine_requirements["mine_placement_scan_call_count"] = mine_placement_scan_call_count;
	mine_requirements["mine_placement_candidate_total"] = mine_placement_candidate_total;
	mine_requirements["mine_placement_selected_count"] = mine_placement_selected_count;
	mine_requirements["mine_placement_rejected_owner_count"] = mine_placement_rejected_owner_count;
	mine_requirements["mine_placement_rejected_49aa93_count"] = mine_placement_rejected_footprint_count;
	mine_requirements["mine_placement_rejected_special_distance_count"] = mine_placement_rejected_special_distance_count;
	mine_requirements["mine_placement_marked_body_cell_count"] = mine_placement_marked_body_cell_count;
	mine_requirements["object_rng_state_before_0x4a9911_uint32"] = int64_t(object_rng_state_before);
	mine_requirements["object_rng_state_after_0x4a9911_0x4a9641_uint32"] = int64_t(object_rng.state);
	mine_requirements["placement_records"] = mine_placement_records;
	mine_requirements["coordinate_records"] = mine_coordinate_records;
	mine_requirements["materialized_private_mine_coordinate_record_count"] = mine_coordinate_records.size();

	Array reward_scheduler_records;
	Array reward_value_preview_records;
	H3MapedRng reward_preview_rng { object_rng.state };
	const uint32_t reward_preview_rng_state_before = reward_preview_rng.state;
	const int32_t reward_budget_base = water_mode_code(normalized_config) == 2 ? 0x640 : 0x320;
	int32_t reward_scheduler_zone_count = 0;
	int32_t reward_scheduler_total_density_sum = 0;
	int32_t reward_scheduler_budget_total = 0;
	int32_t reward_scheduler_preview_attempt_count = 0;
	int32_t reward_value_preview_rng_call_count = 0;
	int32_t reward_object_lookup_count = 0;
	int32_t reward_object_lookup_selected_count = 0;
	int32_t reward_object_lookup_rng_call_count = 0;
	int32_t reward_candidate_scan_count = 0;
	int32_t reward_candidate_scan_eligible_total = 0;
	int32_t reward_candidate_scan_weight_total = 0;
	Array reward_object_lookup_records;
	for (int64_t zone_index = 0; zone_index < runtime_records.size(); ++zone_index) {
		if (Variant(runtime_records[zone_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_records[zone_index];
		const int32_t runtime_index = int32_t(runtime.get("runtime_zone_index", runtime.get("runtime_index", zone_index)));
		struct RewardBandRuntime {
			int32_t band_index = -1;
			int32_t low = 0;
			int32_t high = 0;
			int32_t density = 0;
			int32_t counter = 0;
			int32_t counter_step = 0;
		};
		std::vector<RewardBandRuntime> eligible_bands;
		Array eligible_band_records;
		int32_t total_density = 0;
		int32_t density_product = 1;
		Array bands = runtime.get("treasure_bands", Array());
		for (int64_t band_index = 0; band_index < bands.size(); ++band_index) {
			if (Variant(bands[band_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary band = bands[band_index];
			const int32_t low = int32_t(band.get("low", 0));
			const int32_t high = int32_t(band.get("high", 0));
			const int32_t density = int32_t(band.get("density", 0));
			if (low < 100 || high < low || density <= 0) {
				continue;
			}
			total_density += density;
			density_product *= density;
			eligible_bands.push_back(RewardBandRuntime { int32_t(band_index), low, high, density, 0, 0 });
		}
		if (eligible_bands.empty() || total_density <= 0) {
			continue;
		}

		reward_scheduler_zone_count += 1;
		reward_scheduler_total_density_sum += total_density;
		const int32_t placement_budget = reward_budget_base / total_density;
		reward_scheduler_budget_total += placement_budget;
		for (RewardBandRuntime &band : eligible_bands) {
			band.counter_step = band.density > 0 ? density_product / band.density : 0;
			Dictionary eligible;
			eligible["band_index"] = band.band_index;
			eligible["low_value"] = band.low;
			eligible["high_value"] = band.high;
			eligible["density_weight"] = band.density;
			eligible["scheduler_counter_initial"] = band.counter;
			eligible["scheduler_counter_step"] = band.counter_step;
			eligible_band_records.append(eligible);
		}

		Array selected_attempts;
		for (int32_t attempt = 0; attempt < int32_t(eligible_bands.size()); ++attempt) {
			int32_t selected_index = -1;
			int32_t selected_counter = 0;
			for (int32_t band_index = 0; band_index < int32_t(eligible_bands.size()); ++band_index) {
				const RewardBandRuntime &band = eligible_bands[size_t(band_index)];
				if (selected_index < 0 || band.counter < selected_counter) {
					selected_index = band_index;
					selected_counter = band.counter;
				}
			}
			if (selected_index < 0) {
				break;
			}
			RewardBandRuntime &selected_band = eligible_bands[size_t(selected_index)];
			const int32_t counter_before = selected_band.counter;
			selected_band.counter += selected_band.counter_step;
			int32_t selected_value = selected_band.high;
			int32_t value_rng = -1;
			if (selected_band.high > selected_band.low) {
				value_rng = reward_preview_rng.next();
				reward_value_preview_rng_call_count += 1;
				selected_value = (value_rng % (selected_band.high - selected_band.low)) + selected_band.low;
			}

			Dictionary value_record;
			value_record["phase"] = "0x4aab7e_0x4aa354_reward_value_selection_preview";
			value_record["runtime_zone_index"] = runtime_index;
			value_record["source_zone_id"] = runtime.get("source_zone_id", -1);
			value_record["attempt_index_within_zone"] = attempt;
			value_record["band_index"] = selected_band.band_index;
			value_record["low_value"] = selected_band.low;
			value_record["high_value"] = selected_band.high;
			value_record["density_weight"] = selected_band.density;
			value_record["scheduler_counter_before"] = counter_before;
			value_record["scheduler_counter_step"] = selected_band.counter_step;
			value_record["scheduler_counter_after"] = selected_band.counter;
			value_record["value_rng_value"] = value_rng;
			value_record["selected_value"] = selected_value;
			value_record["commit_helper"] = "0x4aa9b7";
			value_record["commit_materialized"] = false;
			value_record["coordinate_vector_append_pending"] = true;

			const int32_t object_lookup_min_value = selected_value / 4;
			const int32_t object_lookup_max_value = selected_value;
			const RewardObjectSelection object_selection = h3maped_select_reward_candidate_4a9f1c(object_lookup_min_value, object_lookup_max_value, reward_preview_rng);
			reward_object_lookup_count += 1;
			reward_candidate_scan_count += 1;
			reward_candidate_scan_eligible_total += object_selection.eligible_count;
			reward_candidate_scan_weight_total += object_selection.eligible_weight_total;
			if (object_selection.rng_value >= 0) {
				reward_object_lookup_rng_call_count += 1;
			}
			Dictionary object_lookup;
			object_lookup["phase"] = "0x4aa1db_reward_object_lookup_private";
			object_lookup["candidate_scan_helper_address"] = "0x4a9f1c";
			object_lookup["candidate_vector_builder_address"] = "0x49f95a";
			object_lookup["primary_probe_retry_budget"] = 3;
			object_lookup["primary_min_value"] = object_lookup_min_value;
			object_lookup["primary_max_value"] = object_lookup_max_value;
			object_lookup["primary_value_divisor"] = 4;
			object_lookup["scan_source"] = "proxy_backed_recovered_static_candidates_from_0x49f95a";
			object_lookup["scan_complete_candidate_vector_claim"] = false;
			object_lookup["proxy_catalog_path"] = REWARD_PROXY_CATALOG_PATH;
			object_lookup["proxy_adaptation_policy"] = "h3maped_type_subtype_to_original_runtime_proxy";
			object_lookup["eligible_candidate_count"] = object_selection.eligible_count;
			object_lookup["eligible_candidate_weight_total"] = object_selection.eligible_weight_total;
			object_lookup["rejected_value_range_count"] = object_selection.rejected_value_count;
			object_lookup["rejected_native_proxy_mapping_count"] = object_selection.rejected_proxy_count;
			object_lookup["rejected_type_limit_count"] = object_selection.rejected_limit_count;
			object_lookup["weighted_rng_address"] = "0x4e7276";
			object_lookup["weighted_rng_value"] = object_selection.rng_value;
			object_lookup["weighted_selection_roll"] = object_selection.selected_weight_roll;
			object_lookup["selected"] = object_selection.selected;
			object_lookup["coordinate_commit_helper"] = "0x4aa9b7";
			object_lookup["coordinate_commit_materialized"] = false;
			if (object_selection.selected) {
				reward_object_lookup_selected_count += 1;
				object_lookup["selected_constructor_address"] = object_selection.candidate.constructor_address;
				object_lookup["selected_vtable_address"] = object_selection.candidate.vtable_address;
				object_lookup["selected_type_id"] = object_selection.candidate.type_id;
				object_lookup["selected_subtype_id"] = object_selection.candidate.subtype_id;
				object_lookup["selected_value"] = object_selection.candidate.value;
				object_lookup["selected_weight"] = object_selection.candidate.weight;
				object_lookup["selected_extra_0x14"] = object_selection.candidate.extra_0x14;
				object_lookup["selected_source_note"] = object_selection.candidate.source_note;
				object_lookup["native_proxy_catalog_id"] = object_selection.proxy.get("id", "");
				object_lookup["native_proxy_object_id"] = object_selection.proxy.get("native_proxy_object_id", "");
				object_lookup["native_proxy_family"] = object_selection.proxy.get("native_proxy_family", "");
				object_lookup["native_proxy_category"] = object_selection.proxy.get("native_proxy_category", "");
				object_lookup["homm3_re_object_def_ref"] = object_selection.proxy.get("homm3_re_object_def_ref", "");
			}
			value_record["object_lookup_control_flow"] = object_lookup;
			reward_object_lookup_records.append(object_lookup);
			reward_value_preview_records.append(value_record);
			selected_attempts.append(value_record);
			reward_scheduler_preview_attempt_count += 1;
		}

		Dictionary scheduler;
		scheduler["phase"] = "0x4aab7e_weighted_reward_scheduler";
		scheduler["runtime_zone_index"] = runtime_index;
		scheduler["source_zone_id"] = runtime.get("source_zone_id", -1);
		scheduler["eligible_band_count"] = int32_t(eligible_bands.size());
		scheduler["eligible_density_total"] = total_density;
		scheduler["eligible_density_product"] = density_product;
		scheduler["budget_base"] = reward_budget_base;
		scheduler["placement_budget_argument_to_0x4aa9b7"] = placement_budget;
		scheduler["eligible_bands"] = eligible_band_records;
		scheduler["preview_attempts"] = selected_attempts;
		scheduler["commit_helper"] = "0x4aa9b7";
		scheduler["commit_helper_pending"] = true;
		scheduler["complete_coordinate_vector_claim"] = false;
		reward_scheduler_records.append(scheduler);
	}

	Dictionary reward_scheduler;
	reward_scheduler["status"] = "0x4aab7e_per_zone_reward_band_scheduler_preview_private";
	reward_scheduler["total_treasure_band_count"] = total_treasure_band_count;
	reward_scheduler["eligible_reward_band_count"] = eligible_reward_band_count;
	reward_scheduler["eligible_reward_density_sum"] = reward_density_sum;
	reward_scheduler["coordinate_commit_anchor"] = "0x4aa9b7";
	reward_scheduler["coordinate_filter_anchor"] = "0x4aa603";
	reward_scheduler["final_object_commit_anchor"] = "0x4aa3e9";
	reward_scheduler["zone_previews"] = reward_scheduler_preview;
	reward_scheduler["scheduler_records"] = reward_scheduler_records;
	reward_scheduler["value_preview_records"] = reward_value_preview_records;
	reward_scheduler["object_lookup_records"] = reward_object_lookup_records;
	reward_scheduler["budget_base"] = reward_budget_base;
	reward_scheduler["scheduler_zone_count"] = reward_scheduler_zone_count;
	reward_scheduler["scheduler_total_density_sum"] = reward_scheduler_total_density_sum;
	reward_scheduler["scheduler_budget_argument_total"] = reward_scheduler_budget_total;
	reward_scheduler["value_preview_attempt_count"] = reward_scheduler_preview_attempt_count;
	reward_scheduler["value_preview_rng_call_count"] = reward_value_preview_rng_call_count;
	reward_scheduler["object_lookup_count"] = reward_object_lookup_count;
	reward_scheduler["object_lookup_selected_count"] = reward_object_lookup_selected_count;
	reward_scheduler["object_lookup_rng_call_count"] = reward_object_lookup_rng_call_count;
	reward_scheduler["candidate_scan_count"] = reward_candidate_scan_count;
	reward_scheduler["candidate_scan_eligible_total"] = reward_candidate_scan_eligible_total;
	reward_scheduler["candidate_scan_weight_total"] = reward_candidate_scan_weight_total;
	reward_scheduler["candidate_scan_source"] = "proxy_backed_recovered_static_candidates_from_0x49f95a";
	reward_scheduler["candidate_scan_complete_vector_claim"] = false;
	reward_scheduler["preview_rng_state_before_0x4aa354_uint32"] = int64_t(reward_preview_rng_state_before);
	reward_scheduler["preview_rng_state_after_0x4aa354_uint32"] = int64_t(reward_preview_rng.state);
	reward_scheduler["materializes_private_reward_coordinate_records"] = false;
	reward_scheduler["materializes_public_reward_objects"] = false;

	Dictionary monster_summary = h3_single_level_monster_candidate_summary();
	Dictionary vector_order = h3_single_level_candidate_vector_order_boundary();
	Dictionary selector = h3_candidate_selector_boundary();

	phase["status"] = "active_strict_executable_port";
	phase["source"] = "private object-vector prerequisite boundary from recovered h3maped candidate builder, mine/reward schedulers, and generic value-banded selector; no coordinate commit or runtime object adoption yet";
	phase["mine_requirements_boundary"] = mine_requirements;
	phase["reward_scheduler_boundary"] = reward_scheduler;
	phase["candidate_vector_order_boundary"] = vector_order;
	phase["candidate_selector_boundary"] = selector;
	phase["single_level_monster_candidate_boundary"] = monster_summary;
	phase["candidate_vector_single_level_total_count"] = vector_order.get("single_level_total_candidate_record_count", 0);
	phase["candidate_vector_materialized_static_subset_count"] = vector_order.get("materialized_static_candidate_record_count", 0);
	phase["candidate_vector_materialized_monster_count"] = monster_summary.get("candidate_record_count", 0);
	phase["candidate_vector_type10_count"] = vector_order.get("materialized_type10_candidate_count", 0);
	phase["candidate_vector_type17_count"] = vector_order.get("materialized_type17_candidate_count", 0);
	phase["candidate_vector_type53_count"] = vector_order.get("materialized_type53_candidate_count", 0);
	phase["selector_global_limit_override_count"] = selector.get("global_limit_override_count", 0);
	phase["selector_per_zone_limit_override_count"] = selector.get("per_zone_limit_override_count", 0);
	phase["materializes_private_mine_records"] = mine_coordinate_records.size() > 0;
	phase["materialized_private_mine_coordinate_record_count"] = mine_coordinate_records.size();
	phase["partial_coordinate_record_count"] = town_records.size() + mine_coordinate_records.size();
	phase["reward_scheduler_preview_attempt_count"] = reward_scheduler_preview_attempt_count;
	phase["reward_value_preview_rng_call_count"] = reward_value_preview_rng_call_count;
	phase["reward_scheduler_budget_argument_total"] = reward_scheduler_budget_total;
	phase["reward_object_lookup_count"] = reward_object_lookup_count;
	phase["reward_object_lookup_selected_count"] = reward_object_lookup_selected_count;
	phase["reward_object_lookup_rng_call_count"] = reward_object_lookup_rng_call_count;
	phase["reward_candidate_scan_count"] = reward_candidate_scan_count;
	phase["reward_candidate_scan_eligible_total"] = reward_candidate_scan_eligible_total;
	phase["reward_candidate_scan_weight_total"] = reward_candidate_scan_weight_total;
	phase["object_catalog_source_path"] = OBJECT_CATALOG_SOURCE_PATH;
	phase["grid_available"] = grid_available;
	phase["reward_coordinate_commit_materialized"] = false;
	phase["project_object_adoption_candidate_count"] = 0;
	phase["blocked_next"] = "private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9";
	return phase;
}

#if 0
Dictionary zone_footprint_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase) {
	Dictionary phase;
	phase["phase_id"] = "zone_footprints";
	phase["status"] = "blocked_until_coordinate_replay";
	phase["h3maped_anchor"] = "0x4a3a03";
	phase["polygon_constructor_anchor"] = "0x4cc788";
	phase["polygon_split_anchor"] = "0x4ccb64";
	phase["polygon_finalize_anchor"] = "0x4ccdfc";
	phase["boundary_traversal_anchor"] = "0x4a2777";
	phase["span_fill_anchor"] = "0x4a325d";
	phase["small_land_finalizer_anchor"] = "0x4a3710";
	phase["materializes_private_zone_cell_buffer"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "terrain_cell_writeout_0x4a3f27";
	if (String(coordinate_phase.get("status", "")) != "active_internal_state" || level_count(normalized_config) != 1) {
		return phase;
	}

	Array runtime_zones = runtime_zones_for_footprint(runtime_zone_phase, coordinate_phase);
	PolygonSourceResult source = build_polygon_source_walks_4ccb64(runtime_zones);
	Dictionary fill = source.blocked ? Dictionary() : boundary_and_span_fill_4a2777_4a325d(normalized_config, runtime_zones, source, uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0))));

	phase["status"] = source.blocked ? String("blocked_during_source_node_split") : String("active_internal_state");
	phase["source"] = "h3maped 0x4a3a03 small-land footprint phase: 0x4cc788 source rectangle, 0x4ccb64 split/crossing cleanup, 0x4ccdfc finalized source-node cycles, 0x4a2777 boundary traversal, 0x4a325d span fill, and 0x4a3710 no-synthetic-zone finalizer boundary";
	phase["level_count"] = level_count(normalized_config);
	phase["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	phase["synthetic_fallback_zone_allowed_by_0x4a3a9d"] = false;
	phase["appended_synthetic_runtime_zone_count"] = 0;
	phase["initial_bounds_min_x"] = -200;
	phase["initial_bounds_min_y"] = -200;
	phase["initial_bounds_max_x"] = 400;
	phase["initial_bounds_max_y"] = 400;
	phase["initial_node_pair_count"] = 5;
	phase["total_matching_runtime_zones"] = runtime_zones.size();
	phase["total_polygon_split_calls"] = source.executed_split_count;
	phase["split_steps"] = source.split_steps;
	phase["duplicate_skip_count"] = source.duplicate_skip_count;
	phase["edge_removal_branch_count"] = source.edge_removal_count;
	phase["pre_crossing_inserted_node_pair_count"] = source.inserted_node_pair_count;
	phase["pre_crossing_inserted_bridge_pair_count"] = source.inserted_bridge_pair_count;
	phase["crossing_cleanup_scan_count"] = source.crossing_scan_count;
	phase["crossing_test_count"] = source.crossing_test_count;
	phase["crossing_collapse_count"] = source.crossing_collapse_count;
	phase["post_crossing_cleanup_allocated_node_pair_count"] = source.allocated_node_pair_count;
	phase["post_crossing_cleanup_active_node_pair_count"] = source.active_node_pair_count;
	phase["finalized_triplet_count"] = source.finalized_triplet_count;
	phase["finalized_node_count"] = source.finalized_node_count;
	phase["active_payload_node_count"] = source.active_payload_node_count;
	phase["source_node_walk_count"] = source.source_node_walk_count;
	phase["source_node_walk_guard_exhausted_count"] = source.source_node_walk_guard_exhausted_count;
	if (!source.blocked) {
		phase["boundary_traversal_status"] = fill.get("boundary_status", "");
		phase["boundary_runtime_zone_walk_count"] = fill.get("runtime_zone_walk_count", 0);
		phase["boundary_unique_cell_count"] = fill.get("unique_boundary_cell_count", 0);
		phase["boundary_trace_write_count"] = fill.get("trace_write_count", 0);
		phase["boundary_loop_guard_exhausted"] = fill.get("loop_guard_exhausted", false);
		phase["span_fill_status"] = fill.get("span_fill_status", "");
		phase["span_fill_filled_zone_count"] = fill.get("filled_zone_count", 0);
		phase["span_fill_unique_filled_cell_count"] = fill.get("total_unique_filled_cell_count", 0);
		phase["span_fill_boundary_or_filled_cell_count"] = fill.get("total_boundary_or_filled_cell_count", 0);
		phase["span_fill_remaining_unassigned_cell_count"] = fill.get("remaining_unassigned_cell_count", 0);
		phase["reserved_cell_count"] = fill.get("reserved_cell_count", 0);
		phase["cells_by_zone_word"] = fill.get("cells_by_zone_word", Array());
		phase["materializes_private_zone_cell_buffer"] = true;
	}
	return phase;
}

Dictionary active_generation_state(const Dictionary &normalized_config) {
	Dictionary selection = selection_identity(normalized_config);
	Dictionary player_phase = player_slot_assignment_phase(normalized_config, selection);
	Dictionary runtime_zone_phase = runtime_zone_records_phase(selection, player_phase);
	Dictionary link_phase = link_seed_phase(normalized_config, selection, runtime_zone_phase);
	Dictionary coordinate_phase = coordinate_replay_phase(normalized_config, runtime_zone_phase, link_phase, uint32_t(int64_t(selection.get("rng_state_after_selection_uint32", 0))));
	Dictionary footprint_phase = zone_footprint_phase(normalized_config, runtime_zone_phase, coordinate_phase);
	Dictionary terrain_phase = terrain_cell_writeout_phase(normalized_config, runtime_zone_phase, coordinate_phase, footprint_phase);
	Dictionary terrainplacement_visual_phase = terrainplacement_visual_tables_phase(terrain_phase);
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	std::vector<uint32_t> live_cell_word_0x24;
	std::vector<uint32_t> live_cell_word_0x28;
	std::vector<int32_t> live_terrain_code;
	Dictionary terrainplacement_live_feedback = terrainplacement_live_feedback_phase(normalized_config, runtime_zone_phase, coordinate_phase, terrain_phase, terrainplacement_visual_phase, &zone_words, &cell_flags, &live_cell_word_0x24, &live_cell_word_0x28, &live_terrain_code);
	Dictionary terrain_tile_byte_writeback = terrain_tile_byte_writeback_phase(normalized_config, terrainplacement_live_feedback, live_cell_word_0x24, live_cell_word_0x28, live_terrain_code);
	Dictionary town_castle = town_castle_phase(normalized_config, runtime_zone_phase, coordinate_phase, terrain_phase, terrain_tile_byte_writeback, zone_words, live_terrain_code);
	Dictionary object_vector_prerequisite = object_vector_prerequisite_phase(normalized_config, runtime_zone_phase, coordinate_phase, terrain_phase, town_castle, zone_words, cell_flags, live_terrain_code);
	Array completed;
	completed.append("template_selection");
	if (String(player_phase.get("status", "")) == "active_internal_state") {
		completed.append("player_slot_assignment");
	}
	if (String(runtime_zone_phase.get("status", "")) == "active_internal_state") {
		completed.append("runtime_zone_records");
	}
	if (String(link_phase.get("status", "")) == "active_internal_state") {
		completed.append("link_seed_setup");
	}
	if (String(coordinate_phase.get("status", "")) == "active_internal_state") {
		completed.append("coordinate_replay");
	}
	if (String(footprint_phase.get("status", "")) == "active_internal_state") {
		completed.append("zone_footprints");
	}
	if (String(terrain_phase.get("status", "")) == "active_internal_state") {
		completed.append("terrain_cell_writeout");
	}
	if (String(terrainplacement_visual_phase.get("status", "")) == "active_internal_state") {
		completed.append("terrainplacement_visual_tables");
	}
	if (String(terrainplacement_live_feedback.get("status", "")) == "active_internal_state") {
		completed.append("terrainplacement_live_feedback");
	}
	if (String(terrain_tile_byte_writeback.get("status", "")) == "active_internal_state") {
		completed.append("terrain_tile_byte_writeback");
	}
	if (String(town_castle.get("status", "")) == "active_internal_state") {
		completed.append("town_castle_phase");
	}
	if (String(object_vector_prerequisite.get("status", "")) == "active_internal_state") {
		completed.append("mines_rewards_and_object_vector");
	}
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_active_generation_state_v1";
	state["status"] = completed.size() >= 12 ? String("object_vector_prerequisite_active_internal_state") : String(completed.size() >= 11 ? "town_castle_phase_active_internal_state" : String(completed.size() >= 10 ? "terrain_tile_byte_writeback_active_internal_state" : String(completed.size() >= 9 ? "terrainplacement_live_feedback_active_internal_state" : String(completed.size() >= 8 ? "terrainplacement_visual_tables_active_internal_state" : String(completed.size() >= 7 ? "terrain_cell_writeout_active_internal_state" : String(completed.size() >= 6 ? "zone_footprints_active_internal_state" : String(completed.size() >= 5 ? "coordinate_replay_active_internal_state" : "blocked_before_coordinate_replay")))))));
	state["completed_phase_ids"] = completed;
	state["completed_phase_count"] = completed.size();
	state["runtime_generation_allowed"] = false;
	state["materializes_public_output"] = false;
	state["materializes_runtime_players"] = false;
	state["materializes_map_cells"] = false;
	state["selection_identity"] = selection;
	state["player_slot_assignment"] = player_phase;
	state["runtime_zone_records"] = runtime_zone_phase;
	state["link_seed_setup"] = link_phase;
	state["coordinate_replay"] = coordinate_phase;
	state["zone_footprints"] = footprint_phase;
	state["terrain_cell_writeout"] = terrain_phase;
	state["terrainplacement_visual_tables"] = terrainplacement_visual_phase;
	state["terrainplacement_live_feedback"] = terrainplacement_live_feedback;
	state["terrain_tile_byte_writeback"] = terrain_tile_byte_writeback;
	state["town_castle_phase"] = town_castle;
	state["mines_rewards_and_object_vector"] = object_vector_prerequisite;
	state["blocked_next"] = completed.size() >= 12 ? String("private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9") : String(completed.size() >= 11 ? "object_vector_prerequisite_phase_4a9d6a_4aab7e" : String(completed.size() >= 10 ? "town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2" : String(completed.size() >= 9 ? "private_0x49b2b6_tile_byte_writeback_candidate" : String(completed.size() >= 8 ? "live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback" : String(completed.size() >= 7 ? "terrainplacement_visual_tables_0x4bcff5" : String(completed.size() >= 6 ? "terrain_cell_writeout_0x4a3f27" : "zone_footprint_source_nodes_0x4a3a03_0x4cc788"))))));
	return state;
}
#endif

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return width(normalized_config) == 36
			&& height(normalized_config) == 36
			&& level_count(normalized_config) == 1
			&& water_mode(normalized_config) == "land"
			&& size_class_id(normalized_config) == "homm3_small";
}

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary result;
	result["schema_id"] = "aurelion_native_rmg_small_h3maped_selection_identity_v2";
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["rng_seed_setter_address"] = "0x4e7269";
	result["rng_function_address"] = "0x4e7276";
	result["rng_algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
	result["runtime_generation_allowed"] = false;
	const Array accepted = accepted_templates(normalized_config);
	result["accepted_template_count"] = accepted.size();
	if (!supports_scope(normalized_config)) {
		result["ok"] = false;
		result["status"] = "unsupported_scope";
		return result;
	}
	if (accepted.is_empty()) {
		result["ok"] = false;
		result["status"] = "no_accepted_templates";
		return result;
	}
	const String seed_text = normalized_seed_text(normalized_config);
	uint32_t seed_value = 0;
	if (!parse_numeric_seed(seed_text, seed_value)) {
		result["ok"] = false;
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["seed_text"] = seed_text;
		return result;
	}
	const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
	const int32_t first_value = int32_t((next_state >> 16U) & 0x7fffu);
	const int32_t selected_index = first_value % int32_t(accepted.size());
	Dictionary selected = accepted[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_uint32"] = int64_t(seed_value);
	result["rng_first_value"] = first_value;
	result["rng_state_after_selection_uint32"] = int64_t(next_state);
	result["selected_vector_index"] = selected_index;
	result["source_template_id"] = selected.get("id", "");
	result["source_catalog_index"] = selected.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected.get("adapted_template_id", "");
	result["selected_template"] = selected;
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	const Array accepted = accepted_templates(normalized_config);
	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_fresh_start_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["active_module_role"] = "thin_boundary_and_generation_gate";
	report["archived_report_treadmill_path"] = ARCHIVED_REPORT_TREADMILL_PATH;
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
	report["archived_phase_ledger_path"] = ARCHIVED_PHASE_LEDGER_PATH;
	report["archived_active_boundary_path"] = ARCHIVED_ACTIVE_BOUNDARY_PATH;
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = size_score(normalized_config);
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["accepted_template_count"] = accepted.size();
	report["accepted_templates"] = accepted;
	Dictionary selection = selection_identity(normalized_config);
	report["selection_identity"] = selection;
	Dictionary player_slots = player_slot_assignment_phase(normalized_config, selection);
	player_slots["status"] = bool(selection.get("ok", false)) ? String("active_strict_executable_port") : String("blocked_until_template_selection");
	player_slots["source_range"] = "0x4ac62a..0x4ac6ec";
	player_slots["binary_byte_prefix_0x4ac62a"] = "6a 09 8d be e0 0e 00 00 59 83 c8 ff f3 ab 33 d2";
	player_slots["strict_port_scope"] = "generator+0xee0/+0xee4 assignment and mapping slots only";
	report["player_slot_assignment"] = player_slots;
	Dictionary runtime_zones = runtime_zone_records_phase(selection, player_slots);
	runtime_zones["status"] = String(runtime_zones.get("status", "")) == "active_internal_state" ? String("active_strict_executable_port") : String(runtime_zones.get("status", ""));
	runtime_zones["source_range"] = "0x4a218c/0x49b452";
	runtime_zones["binary_byte_prefix_0x4a218c"] = "55 8b ec 83 ec 28 53 8b d9 56 57 ff b3 e8 10 00";
	runtime_zones["binary_byte_prefix_0x49b452"] = "55 8b ec 53 56 8b f1 33 db 8a 4d 0b 57 8d 86 e4";
	runtime_zones["strict_port_scope"] = "generator+0x10e0/+0x10e4/+0x10e8 runtime-zone vector records only";
	report["runtime_zone_records"] = runtime_zones;
	Dictionary link_seeds = link_seed_phase(normalized_config, selection, runtime_zones);
	link_seeds["status"] = String(link_seeds.get("status", "")) == "active_internal_state" ? String("active_strict_executable_port") : String(link_seeds.get("status", ""));
	link_seeds["source_range"] = "0x4a1f3b";
	link_seeds["binary_byte_prefix_0x4a1f3b"] = "b8 54 a7 52 00 e8 8b 41 04 00 83 ec 2c 8a 45 0b";
	link_seeds["strict_port_scope"] = "link endpoint seed records only; no coordinates, guards, roads, blockers, or public output";
	report["link_seed_setup"] = link_seeds;
	const uint32_t replay_seed_state = uint32_t(int64_t(selection.get("rng_state_after_selection_uint32", 0)));
	Dictionary coordinate_replay = coordinate_replay_phase(normalized_config, runtime_zones, link_seeds, replay_seed_state);
	coordinate_replay["status"] = String(coordinate_replay.get("status", "")) == "active_internal_state" ? String("active_strict_executable_port") : String(coordinate_replay.get("status", ""));
	coordinate_replay["source_range"] = "0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed";
	coordinate_replay["binary_byte_prefix_0x4a17f5"] = "55 8b ec 83 ec 38 8b 45 08 53 56 57 8b 5d 0c 8d";
	coordinate_replay["binary_byte_prefix_0x4a1701"] = "55 8b ec 83 ec 34 8b 55 08 53 56 57 8d 72 10 8d";
	coordinate_replay["binary_byte_prefix_0x4a1ad8"] = "55 8b ec 83 ec 40 83 65 f0 00 83 79 20 01 53 8b";
	coordinate_replay["binary_byte_prefix_0x4a19ed"] = "55 8b ec 83 ec 14 8b 55 10 53 8b 5d 08 8b c1 8b";
	coordinate_replay["strict_port_scope"] = "coordinate candidate replay, pruning, RNG choice, and bbox rescale only; no zone footprints, terrain, map cells, or public output";
	report["coordinate_replay"] = coordinate_replay;
	Dictionary zone_source_nodes = zone_footprint_source_nodes_phase(normalized_config, runtime_zones, coordinate_replay);
	zone_source_nodes["source_range"] = "0x4a3a03/0x4cc788/0x4cc955/0x4ccb64/0x4ccdfc";
	zone_source_nodes["binary_byte_prefix_0x4a3a03"] = "b8 ea a7 52 00 e8 c3 26 04 00 81 ec 64 05 00 00";
	zone_source_nodes["binary_byte_prefix_0x4cc788"] = "b8 f3 ca 52 00 e8 3e 99 01 00 83 ec 1c 8a 45 f3";
	zone_source_nodes["binary_byte_prefix_0x4cc955"] = "b8 0a cb 52 00 e8 71 97 01 00 51 51 56 8b f1 6a";
	zone_source_nodes["binary_byte_prefix_0x4ccb64"] = "55 8b ec 83 ec 0c 53 56 57 8b 7d 08 ff 75 0c 8b";
	zone_source_nodes["binary_byte_prefix_0x4ccdfc"] = "55 8b ec 83 ec 0c 83 65 fc 00 53 56 57 8b d9 8b";
	report["zone_footprint_source_nodes"] = zone_source_nodes;
	Dictionary zone_boundary_span = zone_boundary_and_span_fill_phase(normalized_config, runtime_zones, coordinate_replay, zone_source_nodes);
	zone_boundary_span["source_range"] = "0x4a2777/0x4a2b33/0x4a261a/0x4a2413/0x4a325d";
	zone_boundary_span["binary_byte_prefix_0x4a2777"] = "55 8b ec 81 ec 88 00 00 00 53 8b 5d 08 56 57 8b";
	zone_boundary_span["binary_byte_prefix_0x4a2b33"] = "55 8b ec 83 ec 18 53 8b 5d 1c 56 8b 75 0c 8b 13";
	zone_boundary_span["binary_byte_prefix_0x4a261a"] = "55 8b ec 83 ec 20 8b 55 10 53 56 8b f1 8b 4d 08";
	zone_boundary_span["binary_byte_prefix_0x4a2413"] = "b8 68 a7 52 00 e8 b3 3c 04 00 83 ec 30 8a 45 1f";
	zone_boundary_span["binary_byte_prefix_0x4a325d"] = "b8 a4 a7 52 00 e8 69 2e 04 00 83 ec 60 8b 45 08";
	report["zone_boundary_and_span_fill"] = zone_boundary_span;
	Dictionary zone_finalizer = zone_footprint_finalizer_phase(normalized_config, runtime_zones, zone_source_nodes, zone_boundary_span);
	zone_finalizer["source_range"] = "0x4a3710/0x4a3efc/0x4a3f05/0x4cca55/0x49b61b/0x4a3554";
	zone_finalizer["binary_byte_prefix_0x4a3710"] = "55 8b ec 83 ec 70 53 8b d9 83 65 ac 00 83 65 b0";
	zone_finalizer["binary_byte_prefix_0x4a3efc"] = "8d 45 90 8b ce 50 ff 75 d4 e8 06 f8 ff ff 83 4d";
	zone_finalizer["binary_byte_prefix_0x4a3f05"] = "e8 06 f8 ff ff 83 4d fc ff 8d 4d 90 e8 08 8a 02";
	zone_finalizer["binary_byte_prefix_0x4cca55"] = "55 8b ec 51 51 8b 01 53 56 57 8b 08 8b 50 04 39";
	zone_finalizer["binary_byte_prefix_0x49b61b"] = "55 8b ec 51 83 65 fc 00 56 57 8b 7d 08 8b f1 8d";
	zone_finalizer["binary_byte_prefix_0x4a3554"] = "b8 c0 a7 52 00 e8 72 2b 04 00 83 ec 40 8a 45 0b";
	report["zone_footprint_finalizer"] = zone_finalizer;
	Dictionary runtime_terrain = runtime_terrain_selection_phase(normalized_config, runtime_zones, coordinate_replay, zone_finalizer);
	runtime_terrain["source_range"] = "0x49b53d/0x49b54c/0x49b586/0x49b5b7/0x540908";
	runtime_terrain["binary_byte_prefix_0x49b53d"] = "56 8b f1 57 8b 06 80 b8 84 00 00 00 00 74 11 8b";
	report["runtime_terrain_selection"] = runtime_terrain;
	Dictionary terrain_cell = terrain_cell_writeout_phase(normalized_config, runtime_zones, coordinate_replay, zone_source_nodes, runtime_terrain);
	terrain_cell["source_range"] = "0x4a3f27/0x4a4025/0x4a4082/0x4a415a";
	terrain_cell["binary_byte_prefix_0x4a3f27"] = "b8 1c a8 52 00 e8 9f 21 04 00 83 ec 5c 53 56 57";
	terrain_cell["binary_byte_prefix_0x4a4025"] = "8d 43 0c 6a 04 6a 08 50 8d 4d e8 e8 c0 8f 01 00";
	terrain_cell["binary_byte_prefix_0x4a4082"] = "8b 83 e4 10 00 00 85 c0 0f 84 15 01 00 00 8b 8b";
	terrain_cell["binary_byte_prefix_0x4a415a"] = "56 56 57 8d 4d e0 ff 75 d4 e8 31 8f 01 00 ff 45";
	report["terrain_cell_writeout"] = terrain_cell;
	Dictionary terrainplacement_visual = terrainplacement_visual_tables_phase(terrain_cell);
	terrainplacement_visual["source_range"] = "0x4bcff5/0x4bb5ce/0x4bd099/0x4bb74b/0x4bc5f0/0x4bcfc3/0x4bce6d/0x543108/0x543380/0x5434f0/0x5435b0/0x542f88";
	terrainplacement_visual["binary_byte_prefix_0x4bcff5"] = "b8 8a ba 52 00 e8 d1 90 02 00 83 ec 28 56 8b f1";
	terrainplacement_visual["binary_byte_prefix_0x4bb5ce"] = "b8 59 ba 52 00 e8 f8 aa 02 00 83 ec 0c 8b 45 08";
	terrainplacement_visual["binary_byte_prefix_0x4bd099"] = "ff 74 24 10 8b 49 04 ff 74 24 10 ff 74 24 10 ff";
	terrainplacement_visual["binary_byte_prefix_0x4bb74b"] = "55 8b ec 83 ec 28 53 56 8b f1 57 8b 7d 08 ff 76";
	terrainplacement_visual["binary_byte_prefix_0x4bc5f0"] = "55 8b ec 83 ec 10 53 56 57 8b f1 33 db 39 5e 20";
	terrainplacement_visual["binary_byte_prefix_0x4bcfc3"] = "56 8b 74 24 0c 56 ff 74 24 0c e8 9b fe ff ff 8b";
	terrainplacement_visual["binary_byte_prefix_0x4bce6d"] = "55 8b ec 83 ec 0c 53 56 57 8b 75 08 8b f9 8b 47";
	terrainplacement_visual["binary_byte_prefix_0x4ba938"] = "8b 44 24 08 56 83 f8 ff 8b f1 74 09 8b 4e 10 83";
	terrainplacement_visual["binary_byte_prefix_0x4ba989"] = "8b 54 24 10 8b 44 24 04 83 fa ff 56 74 0c 8b 71";
	terrainplacement_visual["binary_byte_prefix_0x4baa94"] = "8b 44 24 08 83 f8 ff 74 0a 83 3c c5 88 2f 54 00";
	terrainplacement_visual["binary_byte_prefix_0x4baabf"] = "55 8b ec 8b 45 14 66 8b 4d 0c 8b 55 08 83 f8 ff";
	terrainplacement_visual["binary_byte_prefix_0x4bad0f"] = "53 8b 5c 24 08 56 8b 74 24 10 57 8b f9 56 53 8b";
	terrainplacement_visual["binary_byte_prefix_0x49acf6"] = "8b 41 24 8b 54 24 04 66 25 00 c0 83 e2 3f 33 c2";
	report["terrainplacement_visual_tables"] = terrainplacement_visual;
	std::vector<uint32_t> zone_words;
	std::vector<uint8_t> cell_flags;
	std::vector<uint32_t> live_cell_word_0x24;
	std::vector<uint32_t> live_cell_word_0x28;
	std::vector<int32_t> live_terrain_code;
	Dictionary terrainplacement_live_feedback = terrainplacement_live_feedback_phase(normalized_config, runtime_zones, coordinate_replay, terrain_cell, terrainplacement_visual, &zone_words, &cell_flags, &live_cell_word_0x24, &live_cell_word_0x28, &live_terrain_code);
	terrainplacement_live_feedback["source_range"] = "0x4a4025/0x4a4082/0x4a415a/0x4bb74b/0x4bba59/0x4bbd01/0x4bc5f0/0x4bc988/0x4bcfc3/0x4bce6d/0x4bad0f/0x49acf6";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bb74b"] = "55 8b ec 83 ec 28 53 56 8b f1 57 8b 7d 08 ff 76";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bba59"] = "55 8b ec 83 ec 18 53 56 57 8b 7d 08 6a 0f 8b f1";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bbd01"] = "55 8b ec 83 ec 64 53 8b 5d 08 56 8b f1 53 89 75";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bc5f0"] = "55 8b ec 83 ec 10 53 56 57 8b f1 33 db 39 5e 20";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bc988"] = "56 57 8b 7c 24 0c 8b f1 57 e8 7d f0 ff ff 84 c0";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bcfc3"] = "56 8b 74 24 0c 56 ff 74 24 0c e8 9b fe ff ff 8b";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bce6d"] = "55 8b ec 83 ec 0c 53 56 57 8b 75 08 8b f9 8b 47";
	terrainplacement_live_feedback["binary_byte_prefix_0x4bad0f"] = "53 8b 5c 24 08 56 8b 74 24 10 57 8b f9 56 53 8b";
	terrainplacement_live_feedback["binary_byte_prefix_0x49acf6"] = "8b 41 24 8b 54 24 04 66 25 00 c0 83 e2 3f 33 c2";
	report["terrainplacement_live_feedback"] = terrainplacement_live_feedback;
	Dictionary terrain_tile_byte_writeback = terrain_tile_byte_writeback_phase(normalized_config, terrainplacement_live_feedback, live_cell_word_0x24, live_cell_word_0x28, live_terrain_code);
	terrain_tile_byte_writeback["source_range"] = "0x49b2b6/0x49acf6";
	terrain_tile_byte_writeback["binary_byte_prefix_0x49b2b6"] = "55 8b ec 51 53 56 57 8b 75 08 8b f9 6a 01 5b 8d";
	terrain_tile_byte_writeback["binary_byte_prefix_0x49acf6"] = "8b 41 24 8b 54 24 04 66 25 00 c0 83 e2 3f 33 c2";
	report["terrain_tile_byte_writeback"] = terrain_tile_byte_writeback;
	Dictionary town_castle = town_castle_phase(normalized_config, runtime_zones, coordinate_replay, terrain_cell, terrain_tile_byte_writeback, zone_words, live_terrain_code);
	town_castle["source_range"] = "0x4a8d2c/0x4a8db2/0x4a93a2/0x49aa93/0x49a09c/0x49b3c1/0x49ba89";
	town_castle["binary_byte_prefix_0x4a8d2c"] = "55 8b ec 51 53 56 57 8b 7d 08 8b d9 8b 37 8b 47";
	town_castle["binary_byte_prefix_0x4a8db2"] = "55 8b ec 83 ec 48 8b 45 08 53 56 33 db 8b 30 8b";
	town_castle["binary_byte_prefix_0x4a93a2"] = "b8 72 aa 52 00 e8 24 cd 03 00 83 ec 48 83 7d 0c";
	town_castle["binary_byte_prefix_0x49aa93"] = "55 8b ec 51 51 89 4d fc 53 8b 4d 18 56 57 6a 00";
	town_castle["binary_byte_prefix_0x49a09c"] = "55 8b ec 51 51 8b 45 1c 80 65 ff 00 53 56 83 78";
	town_castle["binary_byte_prefix_0x49b3c1"] = "56 57 33 ff 8b f1 33 c0 80 7c 06 41 00 74 01 47";
	town_castle["binary_byte_prefix_0x49ba89"] = "8b 44 24 04 56 8b f1 c7 06 74 0a 54 00 89 46 04";
	report["town_castle_phase"] = town_castle;
	Dictionary object_vector = object_vector_prerequisite_phase(normalized_config, runtime_zones, coordinate_replay, terrain_cell, town_castle, zone_words, cell_flags, live_terrain_code);
	object_vector["source_range"] = "0x4a9d6a/0x4a9911/0x4a9641/0x4a9c7c/0x4aab7e/0x4aa354/0x4a9f1c/0x4aa9b7/0x49f95a";
	object_vector["binary_byte_prefix_0x4a9d6a"] = "55 8b ec 83 ec 14 83 65 ec 00 53 56 57 8b f9 8b";
	object_vector["binary_byte_prefix_0x4a9911"] = "b8 ac aa 52 00 e8 b5 c7 03 00 83 ec 40 8a 45 0f";
	object_vector["binary_byte_prefix_0x4a9641"] = "b8 84 aa 52 00 e8 85 ca 03 00 83 ec 58 8b 45 08";
	object_vector["binary_byte_prefix_0x4a9c7c"] = "55 8b ec 83 ec 4c 8b 45 08 53 56 57 8b 00 89 4d";
	object_vector["binary_byte_prefix_0x4aab7e"] = "b8 07 ab 52 00 e8 48 b5 03 00 81 ec 90 00 00 00";
	object_vector["binary_byte_prefix_0x4aa354"] = "55 8b ec 53 8b 5d 0c 56 57 8b f9 8b cb e8 fe 2a";
	object_vector["binary_byte_prefix_0x4a9f1c"] = "b8 dc aa 52 00 e8 aa c1 03 00 83 ec 3c 53 56 57";
	object_vector["binary_byte_prefix_0x4aa9b7"] = "b8 f0 aa 52 00 e8 0f b7 03 00 83 ec 44 89 4d f0";
	object_vector["binary_byte_prefix_0x49f95a"] = "55 8b ec 83 ec 3c 53 56 57 6a 14 5f 89 4d f0 57";
	report["mines_rewards_and_object_vector"] = object_vector;
	report["strict_restart_state"] = strict_restart_state(normalized_config, accepted);
	report["fresh_phase_backlog"] = fresh_phase_backlog();
	report["current_gap_summary"] = current_gap_summary();
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_fresh_start_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The old native RMG and overgrown h3maped report path are archived. The active small-map path is reset to strict h3maped binary verification, scope gating, and template-selection evidence only; runtime package output is blocked until executable-derived phases are ported as generation state.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["strict_restart_state"] = strict_restart_state(normalized_config, accepted_templates(normalized_config));
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
