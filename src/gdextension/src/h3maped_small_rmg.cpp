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
constexpr const char *PROJECT_TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *ARCHIVED_OVERGROWN_ACTIVE_PATH = "src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp";
constexpr const char *ARCHIVED_PHASE_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp";
constexpr const char *ARCHIVED_ACTIVE_BOUNDARY_PATH = "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp";
constexpr const char *ARCHIVED_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp";
constexpr const char *OLDER_LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

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
			return "unknown";
	}
}

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

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD = 0x00ff0000U;
constexpr uint32_t H3MAPED_ZONE_WORD_CLEAR_MASK = 0xff00ffffU;

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

struct H3MaskPoint {
	int32_t dx = 0;
	int32_t dy = 0;
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
		return PolygonPoint {
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
	record["source"] = "recovered h3maped template catalog anchored to /root/Downloads/h3maped.exe";
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
	pending.push_back(CoordCandidate { x2, y2, level });
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
		pending.push_back(CoordCandidate { jittered_x, jittered_y, level });
		inserted_midpoint_count += 1;
		max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	}
	return result;
}

bool h3maped_cell_unassigned_4a325d(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return (zone_words[size_t(h3maped_cell_index(width, height, x, y, level))] & H3MAPED_UNASSIGNED_ZONE_WORD) == H3MAPED_UNASSIGNED_ZONE_WORD;
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
		if (!h3maped_cell_unassigned_4a325d(zone_words, width, height, span.x, span.y, span.level)) {
			result.blocked_initial_span_count += 1;
		}
		int32_t x = span.x;
		while (x > 0 && h3maped_cell_unassigned_4a325d(zone_words, width, height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		bool upper_run_open = false;
		bool lower_run_open = false;
		SpanRecord upper_span;
		SpanRecord lower_span;
		for (; x < width && h3maped_cell_unassigned_4a325d(zone_words, width, height, x, span.y, span.level); ++x) {
			const int64_t index = h3maped_cell_index(width, height, x, span.y, span.level);
			zone_words[size_t(index)] = (zone_words[size_t(index)] & H3MAPED_ZONE_WORD_CLEAR_MASK) | (uint32_t(zone_word_id & 0xff) << 16U);
			if (!(water_code == 2 && span.level != 1)) {
				cell_flags[size_t(index)] = uint8_t(cell_flags[size_t(index)] | 0x10U);
			}
			result.filled_cell_count += 1;
			append_span_fill_preview_4a325d(result.trace_preview, x, span.y, span.level);

			const bool upper_open = span.y > 0 && h3maped_cell_unassigned_4a325d(zone_words, width, height, x, span.y - 1, span.level);
			if (upper_open && !upper_run_open) {
				upper_span = SpanRecord { x, span.y - 1, span.level };
				upper_run_open = true;
			} else if (!upper_open && upper_run_open) {
				push_span(upper_span);
				upper_run_open = false;
			}

			const bool lower_open = span.y + 1 < height && h3maped_cell_unassigned_4a325d(zone_words, width, height, x, span.y + 1, span.level);
			if (lower_open && !lower_run_open) {
				lower_span = SpanRecord { x, span.y + 1, span.level };
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

Dictionary player_slot_assignment_phase(const TemplateEvidence &selected_template, const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(0, int32_t(constraints.get("human_count", 1)));
	const int32_t player_count = std::max(human_count, int32_t(constraints.get("player_count", 2)));

	Dictionary phase;
	phase["phase_id"] = "player_slot_assignment";
	phase["status"] = "active_runtime_state_ready";
	phase["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	phase["selected_color_bitmap_offset"] = "generator+0xed8";
	phase["assignment_slots_offset"] = "generator+0xee0";
	phase["mapped_slots_offset"] = "generator+0xee4";
	phase["human_capable_source_owner_mask"] = selected_template.human_capable_source_owner_mask;
	phase["player_capable_source_owner_mask"] = selected_template.player_capable_source_owner_mask;
	phase["human_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.human_capable_source_owner_mask);
	phase["player_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.player_capable_source_owner_mask);

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

	phase["selected_color_order_ed8"] = selected_color_order;
	phase["raw_ee0_slots"] = assignment_slots;
	phase["mapped_ee4_slots"] = mapped_slots;
	phase["assignment_records"] = assignments;
	phase["assigned_player_count"] = assigned_players;
	phase["requested_human_count"] = human_count;
	phase["requested_player_count"] = player_count;
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
	Dictionary template_record = find_project_template_record(adapted_template_id, catalog_load);
	phase["project_catalog_load"] = catalog_load;
	phase["project_template_id"] = adapted_template_id;
	if (template_record.is_empty() || Variant(template_record.get("zones", Variant())).get_type() != Variant::ARRAY) {
		return phase;
	}

	Array mapped_slots = player_phase.get("mapped_ee4_slots", Array());
	Array zones = template_record.get("zones", Array());
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
		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Dictionary mine_requirements = zone.get("mine_requirements", Dictionary());
		Dictionary minimum_by_category = mine_requirements.get("minimum_by_category", Dictionary());
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
		record["min_player_castles"] = min_castles;
		record["terrain_match_to_town"] = bool(Dictionary(zone.get("terrain", Dictionary())).get("match_to_faction", false));
		record["terrain_policy"] = Array(Dictionary(zone.get("terrain", Dictionary())).get("allowed", Array())).is_empty() ? String("match_to_player_town") : String("all_land_h3");
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
			for (int32_t terrain_id = 0; terrain_id <= 7; ++terrain_id) {
				allowed_terrain_ids.append(terrain_id);
			}
			record["allowed_h3maped_terrain_ids_for_49b53d"] = allowed_terrain_ids;
		}
		record["monster_strength"] = Dictionary(zone.get("monster_policy", Dictionary())).get("strength", "");
		record["minimum_ore_mines"] = minimum_by_category.get("ore", 0);
		record["minimum_wood_mines"] = minimum_by_category.get("timber", 0);
		record["minimum_rare_mines"] = int32_t(minimum_by_category.get("gold", 0)) + int32_t(minimum_by_category.get("quicksilver", 0)) + int32_t(minimum_by_category.get("ember_salt", 0)) + int32_t(minimum_by_category.get("lens_crystal", 0)) + int32_t(minimum_by_category.get("cut_gems", 0));
		runtime_records.append(record);
		actual_owner_colors.append(actual_owner);
	}
	if (minimum_source_base_size == 0x7fffffff) {
		minimum_source_base_size = 0;
	}

	phase["status"] = "active_runtime_state_ready";
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

bool player_filter_allows(const Dictionary &filter, int32_t human_count, int32_t player_count) {
	return human_count >= int32_t(filter.get("min_human", 0))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& player_count >= int32_t(filter.get("min_total", 0))
			&& player_count <= int32_t(filter.get("max_total", 8));
}

Dictionary link_seed_phase(const Dictionary &selection, const Dictionary &normalized_config, const Dictionary &runtime_zone_phase) {
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
	if (String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	Dictionary catalog_load;
	Dictionary template_record = find_project_template_record(String(selection.get("adapted_template_id", "")), catalog_load);
	phase["project_catalog_load"] = catalog_load;
	if (template_record.is_empty() || Variant(template_record.get("links", Variant())).get_type() != Variant::ARRAY) {
		phase["status"] = "blocked_missing_project_template_links";
		return phase;
	}

	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array links = template_record.get("links", Array());
	Array seeds;
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		Dictionary filter = link.get("player_filter", Dictionary());
		if (!player_filter_allows(filter, human_count, player_count)) {
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

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "res://content/random_map_template_catalog.json recovered link rows consumed through h3maped 0x4a1f3b";
	phase["link_seed_count"] = seeds.size();
	phase["link_seeds"] = seeds;
	return phase;
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
	if (int32_t(normalized_config.get("level_count", 1)) != 1
			|| String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(link_phase.get("status", "")) != "active_runtime_state_ready") {
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

	phase["status"] = complete ? String("active_runtime_state_ready") : String("blocked_coordinate_candidate_replay");
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

Dictionary zone_footprint_phase_boundary(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase) {
	Dictionary phase;
	phase["phase_id"] = "zone_footprint_phase_boundary";
	phase["h3maped_anchor"] = "0x4a3a03";
	phase["helper_sequence"] = "0x4a2777 -> 0x4a325d -> 0x4a3710";
	phase["synthetic_source_zone_id"] = "0xd4";
	phase["synthetic_triplets"] = "0xa0=100,0xa4=1000,0xa8=5,0xac=2000,0xb0=6000,0xb4=1";
	phase["status"] = "blocked_until_coordinate_replay";
	phase["materializes_boundaries"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "source_node_rectangle_0x4cc788";
	if (String(coordinate_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	Array runtime_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array levels;
	int32_t total_collected = 0;
	for (int32_t level = 0; level < level_count; ++level) {
		Array zone_indices;
		Array helper_inputs;
		for (int32_t index = 0; index < runtime_records.size(); ++index) {
			if (Variant(runtime_records[index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary record = runtime_records[index];
			if (int32_t(record.get("level", 0)) != level) {
				continue;
			}
			const int32_t runtime_index = int32_t(record.get("runtime_index", index));
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

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x4a3a03 per-level runtime-zone collection and helper input scheduling";
	phase["level_count"] = level_count;
	phase["h3maped_water_mode_code"] = water_code;
	phase["per_level"] = levels;
	phase["total_collected_runtime_zone_count"] = total_collected;
	phase["synthetic_zone_appended_count"] = 0;
	return phase;
}

Dictionary source_node_rectangle_phase(const Dictionary &zone_footprint_phase) {
	Dictionary phase;
	phase["phase_id"] = "source_node_rectangle";
	phase["h3maped_anchor"] = "0x4cc788";
	phase["node_constructor_anchor"] = "0x4cc955";
	phase["splitter_anchor"] = "0x4ccb64";
	phase["locator_anchor"] = "0x4cca55";
	phase["finalizer_anchor"] = "0x4ccdfc";
	phase["status"] = "blocked_until_zone_footprint_phase";
	phase["materializes_source_node_graph"] = false;
	phase["materializes_boundaries"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["feeds_real_0x4a2777_boundary"] = false;
	phase["blocked_next"] = "polygon_split_model_0x4ccb64_0x4ccdfc";
	if (String(zone_footprint_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
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

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x4cc788 initial source-node rectangle constants before 0x4ccb64 split insertions";
	phase["initial_bounds"] = bounds;
	phase["initial_edge_count"] = edges.size();
	phase["initial_edges"] = edges;
	return phase;
}

Dictionary polygon_split_model_phase(const Dictionary &normalized_config, const Dictionary &coordinate_phase, const Dictionary &source_node_phase) {
	Dictionary phase;
	phase["phase_id"] = "polygon_split_model";
	phase["h3maped_anchor"] = "0x4ccb64";
	phase["locator_anchor"] = "0x4cca55";
	phase["splitter_anchor"] = "0x4ccb64";
	phase["node_constructor_anchor"] = "0x4cc955";
	phase["node_relink_anchor"] = "0x4cc643";
	phase["edge_side_test_anchor"] = "0x4cc6f2";
	phase["edge_erase_anchor"] = "0x4cc9cc";
	phase["bridge_anchor"] = "0x4ccb1f";
	phase["crossing_test_anchor"] = "0x4ccc7a";
	phase["crossing_collapse_anchor"] = "0x4cc68e";
	phase["intersection_writer_anchor"] = "0x4ccd69";
	phase["finalizer_anchor"] = "0x4ccdfc";
	phase["status"] = "blocked_until_source_node_rectangle";
	phase["materializes_source_node_graph"] = false;
	phase["materializes_boundaries"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["feeds_real_0x4a2777_boundary"] = false;
	phase["blocked_next"] = "source_node_boundary_traversal_0x4a2777";
	if (String(source_node_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}
	if (int32_t(normalized_config.get("level_count", 1)) != 1) {
		phase["status"] = "unsupported_until_two_level_polygon_split_model_ported";
		return phase;
	}

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_phase.get("scaled_zone_coordinates", Array());
	zones.reserve(size_t(scaled.size()));
	for (int32_t index = 0; index < scaled.size(); ++index) {
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
		step["status"] = blocked ? String("0x4ccb64_guard_failed") : String("0x4ccb64_pre_crossing_inserted");
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
		walk["located_node_id"] = located >= 0 ? Variant(model.nodes[size_t(located)].id) : Variant(String());
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
				node_report["+0x10_next"] = node.next >= 0 ? Variant(model.nodes[size_t(node.next)].id) : Variant(String());
				node_report["+0x14_previous"] = node.previous >= 0 ? Variant(model.nodes[size_t(node.previous)].id) : Variant(String());
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

	phase["status"] = blocked ? String("blocked_during_polygon_split_model") : String("active_runtime_state_ready");
	phase["source"] = "h3maped 0x4ccb64 insertion/bridge/crossing-cleanup loop and 0x4ccdfc source-node finalizer over 0x4a19ed scaled runtime-zone coordinates";
	phase["materializes_source_node_graph"] = !blocked;
	phase["split_steps"] = split_steps;
	phase["runtime_split_point_count"] = int32_t(zones.size());
	phase["executed_split_call_count"] = executed_split_count;
	phase["duplicate_skip_count"] = skipped_duplicate_count;
	phase["edge_removal_branch_count"] = edge_removal_count;
	phase["pre_crossing_inserted_node_pair_count"] = inserted_node_pair_count;
	phase["pre_crossing_inserted_bridge_pair_count"] = inserted_bridge_pair_count;
	phase["crossing_cleanup_scan_count"] = crossing_scan_count;
	phase["crossing_test_count"] = crossing_test_count;
	phase["crossing_collapse_count"] = crossing_collapse_count;
	phase["initial_node_pair_count"] = 5;
	phase["post_crossing_cleanup_allocated_node_pair_count"] = int32_t(model.nodes.size() / 2);
	phase["post_crossing_cleanup_allocated_node_count"] = int32_t(model.nodes.size());
	phase["post_crossing_cleanup_active_node_pair_count"] = model.active_node_pair_count();
	phase["post_crossing_cleanup_active_node_count"] = model.active_node_pair_count() * 2;
	phase["root_node_id_after_crossing_cleanup"] = model.root >= 0 ? Variant(model.nodes[size_t(model.root)].id) : Variant(String());
	phase["crossing_cleanup_status"] = blocked ? String("blocked_during_crossing_cleanup") : String("0x4ccc7a_0x4cc68e_crossing_cleanup_ported");
	phase["finalizer_status"] = blocked ? String("blocked_before_0x4ccdfc") : String("0x4ccdfc_finalized_node_fanout_ported");
	phase["finalized_triplet_count"] = finalized_triplet_count;
	phase["finalized_node_count"] = finalized_node_count;
	phase["active_payload_node_count"] = active_payload_node_count;
	phase["finalized_steps"] = finalized_steps;
	phase["source_node_walk_status"] = blocked ? String("blocked_before_0x4cca55_source_node_walk") : String("0x4cca55_to_0x4a2777_source_node_cycles_recovered_private_only");
	phase["source_node_walk_count"] = source_node_walk_count;
	phase["source_node_walk_guard_exhausted_count"] = source_node_walk_guard_exhausted_count;
	phase["source_node_walks"] = source_node_walks;
	return phase;
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

Dictionary source_node_boundary_traversal_phase(const Dictionary &normalized_config, const Dictionary &coordinate_phase, const Dictionary &polygon_split_phase, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary phase;
	phase["phase_id"] = "source_node_boundary_traversal";
	phase["h3maped_anchor"] = "0x4a2777";
	phase["caller_anchor"] = "0x4a3e58..0x4a3e8c";
	phase["source_node_cycle_source"] = "polygon_split_model.source_node_walks_from_0x4cca55_after_0x4ccdfc_finalization";
	phase["clip_helper_anchor"] = "0x4a2b33";
	phase["deterministic_line_writer_anchor"] = "0x4a261a";
	phase["flagged_line_writer_anchor"] = "0x4a2413";
	phase["runtime_vertex_vector_offset"] = "runtime_zone+0x3f4";
	phase["status"] = "blocked_until_polygon_split_model";
	phase["materializes_boundaries"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_public_output"] = false;
	phase["project_materialized_cell_count"] = 0;
	phase["blocked_next"] = "span_fill_4a325d";
	if (String(polygon_split_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	phase["map_width"] = width;
	phase["map_height"] = height;
	phase["level_count"] = level_count;
	phase["h3maped_water_mode_code"] = water_code;
	phase["rng_state_before_0x4a2777_uint32"] = coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0);

	std::vector<RuntimeZoneSeed> zones;
	Array scaled = coordinate_phase.get("scaled_zone_coordinates", Array());
	for (int32_t index = 0; index < scaled.size(); ++index) {
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
	Array walks = polygon_split_phase.get("source_node_walks", Array());
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
	rng.state = uint32_t(int64_t(coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0)));

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

	for (int32_t walk_index = 0; walk_index < walks.size(); ++walk_index) {
		if (Variant(walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
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
		for (int32_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
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

	phase["status"] = "active_runtime_state_ready";
	phase["materializes_boundaries"] = true;
	phase["runtime_zone_walk_count"] = runtime_zone_walk_count;
	phase["blocked_zone_count"] = blocked_zone_count;
	phase["fallback_zone_count"] = fallback_zone_count;
	phase["connector_segment_count"] = connector_segment_count;
	phase["wrap_segment_count"] = wrap_segment_count;
	phase["final_segment_count"] = final_segment_count;
	phase["appended_vertex_count"] = appended_vertex_count;
	phase["skipped_unfinalized_node_count"] = skipped_unfinalized_node_count;
	phase["skipped_out_of_bounds_clip_count"] = skipped_out_of_bounds_clip_count;
	phase["flagged_writer_segment_count"] = flagged_writer_segment_count;
	phase["deterministic_writer_segment_count"] = deterministic_writer_segment_count;
	phase["randomized_rng_call_count"] = randomized_rng_call_count;
	phase["randomized_inserted_midpoint_count"] = randomized_inserted_midpoint_count;
	phase["randomized_max_pending_point_count"] = randomized_max_pending_point_count;
	phase["rng_state_after_0x4a2777_uint32"] = int64_t(rng.state);
	phase["trace_write_count"] = trace_write_count;
	phase["unique_cell_count"] = int32_t(unique_cells.size());
	phase["out_of_bounds_write_count"] = out_of_bounds_write_count;
	phase["loop_guard_exhausted"] = loop_guard_exhausted;
	phase["zone_reports"] = zone_reports;
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return phase;
}

Dictionary seed_relocation_4a325d_phase(const Dictionary &source_node_walk, const SpanRecord &seed, int32_t width, int32_t height, int32_t level_count) {
	Dictionary phase;
	phase["status"] = "0x4a325d_seed_in_bounds_relocation_not_used";
	phase["h3maped_anchor"] = "0x4a325d";
	phase["branch_anchor"] = "0x4a32b2..0x4a338e";
	phase["clip_helper_anchor"] = "0x4a2b33";
	phase["seed_x"] = seed.x;
	phase["seed_y"] = seed.y;
	phase["seed_level"] = seed.level;
	const bool seed_in_bounds = seed.x >= 0 && seed.x < width && seed.y >= 0 && seed.y < height && seed.level >= 0 && seed.level < level_count;
	phase["seed_in_bounds"] = seed_in_bounds;

	Array candidates;
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_clearance = -1;
	Array cycle_nodes = source_node_walk.get("cycle_nodes", Array());
	for (int32_t node_index = 0; node_index < cycle_nodes.size(); ++node_index) {
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
	phase["candidate_count"] = candidates.size();
	phase["candidates"] = candidates;
	phase["best_candidate_x"] = best_x;
	phase["best_candidate_y"] = best_y;
	phase["best_candidate_border_clearance"] = best_clearance;
	if (seed_in_bounds) {
		phase["relocated"] = false;
		phase["relocated_seed_x"] = seed.x;
		phase["relocated_seed_y"] = seed.y;
		phase["relocated_seed_level"] = seed.level;
		return phase;
	}
	if (best_x < 0 || best_y < 0) {
		phase["status"] = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
		phase["relocated"] = false;
		phase["relocated_seed_x"] = seed.x;
		phase["relocated_seed_y"] = seed.y;
		phase["relocated_seed_level"] = seed.level;
		return phase;
	}
	ClipBounds bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	ClipResult clipped = h3maped_clip_point_4a2b33(seed.x, seed.y, best_x, best_y, bounds);
	phase["status"] = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
	phase["relocated"] = true;
	phase["relocated_seed_x"] = clipped.x;
	phase["relocated_seed_y"] = clipped.y;
	phase["relocated_seed_level"] = seed.level;
	phase["clip_branch"] = clipped.branch;
	return phase;
}

Dictionary span_fill_4a325d_phase(const Dictionary &normalized_config, const Dictionary &coordinate_phase, const Dictionary &polygon_split_phase, const Dictionary &boundary_traversal_phase, std::vector<uint32_t> zone_words, std::vector<uint8_t> cell_flags, std::vector<uint32_t> *zone_words_out = nullptr, std::vector<uint8_t> *cell_flags_out = nullptr) {
	Dictionary phase;
	phase["phase_id"] = "span_fill_4a325d";
	phase["h3maped_anchor"] = "0x4a325d";
	phase["boundary_source_anchor"] = "0x4a2777";
	phase["seed_source"] = "runtime_zone+0x10 x/y/level after 0x4a19ed bbox rescale";
	phase["source"] = "h3maped 0x4a325d span fill over the private 0x4a2777 boundary buffer produced from finalized 0x4cca55 source-node cycles";
	phase["status"] = "blocked_until_source_node_boundary_traversal";
	phase["uses_real_0x4a2777_boundary"] = true;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "footprint_finalizer_4a3710";
	if (String(boundary_traversal_phase.get("status", "")) != "active_runtime_state_ready" || zone_words.empty() || cell_flags.empty()) {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = int32_t(normalized_config.get("level_count", 1));
	const int32_t water_code = water_mode_code(normalized_config);
	phase["map_width"] = width;
	phase["map_height"] = height;
	phase["level_count"] = level_count;
	phase["h3maped_water_mode_code"] = water_code;
	phase["boundary_status"] = boundary_traversal_phase.get("status", "");
	phase["boundary_unique_cell_count"] = boundary_traversal_phase.get("unique_cell_count", 0);
	phase["boundary_trace_write_count"] = boundary_traversal_phase.get("trace_write_count", 0);
	phase["boundary_rng_state_after_0x4a2777_uint32"] = boundary_traversal_phase.get("rng_state_after_0x4a2777_uint32", 0);

	Dictionary walk_by_runtime;
	Array source_node_walks = polygon_split_phase.get("source_node_walks", Array());
	for (int32_t walk_index = 0; walk_index < source_node_walks.size(); ++walk_index) {
		if (Variant(source_node_walks[walk_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary walk = source_node_walks[walk_index];
		walk_by_runtime[String::num_int64(int64_t(walk.get("runtime_zone_index", -1)))] = walk;
	}

	Array zone_fill_reports;
	Array scaled = coordinate_phase.get("scaled_zone_coordinates", Array());
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
	for (int32_t index = 0; index < scaled.size(); ++index) {
		if (Variant(scaled[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary item = scaled[index];
		const int32_t runtime_zone_index = int32_t(item.get("runtime_zone_index", index));
		SpanRecord seed { int32_t(item.get("x_after_bbox_rescale", 0)), int32_t(item.get("y_after_bbox_rescale", 0)), int32_t(item.get("level", 0)) };
		Dictionary zone_report;
		zone_report["runtime_zone_index"] = runtime_zone_index;
		zone_report["zone_word_id"] = runtime_zone_index;
		zone_report["seed_x"] = seed.x;
		zone_report["seed_y"] = seed.y;
		zone_report["seed_level"] = seed.level;

		Dictionary matching_walk = walk_by_runtime.get(String::num_int64(runtime_zone_index), Dictionary());
		Dictionary relocation = seed_relocation_4a325d_phase(matching_walk, seed, width, height, level_count);
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

		const bool seed_unassigned = h3maped_cell_unassigned_4a325d(zone_words, width, height, seed.x, seed.y, seed.level);
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

	phase["status"] = "active_runtime_state_ready";
	phase["materializes_span_fill"] = true;
	phase["runtime_zone_fill_attempt_count"] = zone_fill_reports.size();
	phase["filled_zone_count"] = filled_zone_count;
	phase["seed_blocked_count"] = seed_blocked_count;
	phase["missing_seed_count"] = missing_seed_count;
	phase["seed_relocation_count"] = seed_relocation_count;
	phase["unique_filled_cell_count"] = total_filled_cell_count;
	phase["total_boundary_or_filled_cell_count"] = total_boundary_or_filled_cell_count;
	phase["remaining_unassigned_cell_count"] = remaining_unassigned_cell_count;
	phase["reserved_flag_cell_count"] = reserved_flag_cell_count;
	phase["pushed_span_count"] = pushed_span_count;
	phase["popped_span_count"] = popped_span_count;
	phase["max_pending_span_count"] = max_pending_span_count;
	phase["out_of_bounds_span_count"] = out_of_bounds_span_count;
	phase["blocked_initial_span_count"] = blocked_initial_span_count;
	phase["cells_by_zone_word"] = cells_by_zone_word;
	phase["zone_fill_reports"] = zone_fill_reports;
	if (zone_words_out != nullptr && cell_flags_out != nullptr) {
		*zone_words_out = zone_words;
		*cell_flags_out = cell_flags;
	}
	return phase;
}

Dictionary footprint_finalizer_4a3710_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &zone_footprint_phase, const Dictionary &span_fill_phase) {
	Dictionary phase;
	phase["phase_id"] = "footprint_finalizer_4a3710";
	phase["h3maped_anchor"] = "0x4a3710";
	phase["call_site_anchor"] = "0x4a3efc..0x4a3f05";
	phase["call_site_start_index_source"] = "0x4a3a86..0x4a3a9a captures runtime-zone vector count before the synthetic branch and passes it at 0x4a3f02";
	phase["polygon_locator_anchor"] = "0x4cca55";
	phase["clip_helper_anchor"] = "0x4a2b33";
	phase["zone_order_reset_anchor"] = "0x49b61b";
	phase["per_zone_order_helper_anchor"] = "0x4a3554";
	phase["adjacency_vector_offset"] = "runtime_zone+0xc4";
	phase["ordering_vector_offset"] = "runtime_zone+0x3e8";
	phase["status"] = "blocked_until_span_fill_4a325d";
	phase["materializes_zone_cells"] = false;
	phase["materializes_boundary_cells"] = false;
	phase["materializes_span_fill"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_package_tiles"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "runtime_terrain_selection_49b53d";
	if (String(span_fill_phase.get("status", "")) != "active_runtime_state_ready") {
		return phase;
	}

	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t water_code = water_mode_code(normalized_config);
	const bool synthetic_branch_allowed = level_count > 1 || water_code != 0;
	Array runtime_zone_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array per_level = zone_footprint_phase.get("per_level", Array());
	int32_t original_same_level_runtime_zone_count = int32_t(zone_footprint_phase.get("total_collected_runtime_zone_count", runtime_zone_records.size()));
	if (per_level.size() > 0 && Variant(per_level[0]).get_type() == Variant::DICTIONARY) {
		Dictionary level_record = per_level[0];
		Array collected = level_record.get("collected_runtime_zone_indices", Array());
		original_same_level_runtime_zone_count = int32_t(collected.size());
	}
	const int32_t final_runtime_zone_count = int32_t(runtime_zone_records.size());
	const int32_t appended_runtime_zone_count = std::max(0, final_runtime_zone_count - original_same_level_runtime_zone_count);
	phase["status"] = appended_runtime_zone_count == 0
			? String("0x4a3710_small_land_no_appended_zone_finalizer_ported_private")
			: String("0x4a3710_appended_zone_adjacency_finalizer_blocked");
	phase["source"] = "h3maped 0x4a3710 footprint adjacency finalizer; small one-level land has no appended synthetic runtime zones, so adjacency insertion loops skip and only ordering reset/rebuild calls execute";
	phase["level_count"] = level_count;
	phase["h3maped_water_mode_code"] = water_code;
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
	phase["blocked_next"] = appended_runtime_zone_count == 0
			? String("runtime_terrain_selection_49b53d")
			: String("runtime_zone_0xc4_appended_adjacency_records");
	return phase;
}

Dictionary runtime_terrain_selection_49b53d_phase(const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &footprint_finalizer_phase) {
	Dictionary phase;
	phase["phase_id"] = "runtime_terrain_selection_49b53d";
	phase["h3maped_anchor"] = "0x49b53d";
	phase["town_to_terrain_table_address"] = "0x540908";
	phase["allowed_terrain_flags_source"] = "source_zone+0x85..0x8c";
	phase["rng_state_before_0x49b53d_uint32"] = coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0);
	phase["status"] = "blocked_until_footprint_finalizer_4a3710";
	phase["materializes_terrain_cells"] = false;
	phase["materializes_terrain_art"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_package_tiles"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "terrain_cell_writeout_4a3f27";
	if (String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(coordinate_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(footprint_finalizer_phase.get("status", "")) != "0x4a3710_small_land_no_appended_zone_finalizer_ported_private") {
		return phase;
	}

	const int32_t town_to_terrain[] = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	Array town_table;
	for (int32_t index = 0; index < int32_t(sizeof(town_to_terrain) / sizeof(town_to_terrain[0])); ++index) {
		town_table.append(town_to_terrain[index]);
	}
	phase["town_choice_to_terrain_table"] = town_table;

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
		const int32_t level = int32_t(runtime.get("level", 0));
		const bool match_to_town = bool(runtime.get("terrain_match_to_town", false));
		const int32_t town_choice_index = int32_t(runtime.get("town_choice_index", runtime.get("town_choice_index_49b3c1", -1)));
		selection["runtime_zone_index"] = runtime_zone_index;
		selection["level"] = level;
		selection["terrain_match_to_town"] = match_to_town;
		selection["town_choice_index"] = town_choice_index;
		selection["faction_id"] = runtime.get("faction_id", runtime.get("selected_faction_id_49b3c1", ""));

		int32_t selected_terrain = -1;
		String source;
		if (match_to_town && town_choice_index >= 0 && town_choice_index < int32_t(sizeof(town_to_terrain) / sizeof(town_to_terrain[0]))) {
			selected_terrain = town_to_terrain[town_choice_index];
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

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x49b53d runtime terrain selection over the 0x49b3c1 town choices and source-zone allowed terrain flags";
	phase["selection_count"] = selections.size();
	phase["selections"] = selections;
	phase["selected_h3maped_terrain_ids"] = selected_ids;
	phase["selected_project_terrain_ids"] = selected_names;
	phase["match_to_town_count"] = match_to_town_count;
	phase["allowed_flag_choice_count"] = allowed_flag_choice_count;
	phase["blank_allowed_mask_count"] = blank_allowed_mask_count;
	phase["forced_subterranean_count"] = forced_subterranean_count;
	phase["rng_call_count"] = rng_call_count;
	phase["rng_state_after_0x49b53d_uint32"] = int64_t(rng.state);
	phase["blocked_next"] = "terrain_cell_writeout_4a3f27";
	return phase;
}

Dictionary terrain_cell_writeout_4a3f27_phase(const Dictionary &normalized_config, const Dictionary &span_fill_phase, const Dictionary &terrain_selection_phase, const std::vector<uint32_t> &zone_words, const std::vector<uint8_t> &cell_flags) {
	Dictionary phase;
	phase["phase_id"] = "terrain_cell_writeout_4a3f27";
	phase["h3maped_anchor"] = "0x4a3f27";
	phase["full_map_water_repaint_address"] = "0x4a4025";
	phase["per_zone_repaint_loop_address"] = "0x4a4082";
	phase["per_cell_repaint_call_address"] = "0x4a415a";
	phase["owner_byte_gate_address"] = "0x4a4142";
	phase["reserved_flag_gate_address"] = "0x4a4150";
	phase["span_fill_source_address"] = "0x4a325d";
	phase["tile_serializer_address"] = "0x49b2b6";
	phase["status"] = "blocked_until_terrain_selection_and_span_fill";
	phase["materializes_private_generated_cell_words"] = true;
	phase["materializes_terrain_art"] = false;
	phase["materializes_roads"] = false;
	phase["materializes_objects"] = false;
	phase["materializes_package_tiles"] = false;
	phase["project_grid_public_runtime_adoption"] = false;
	phase["public_package_output_allowed"] = false;
	phase["blocked_next"] = "terrainplacement_visual_tables_4bcff5";
	if (String(span_fill_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(terrain_selection_phase.get("status", "")) != "active_runtime_state_ready"
			|| zone_words.empty()) {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	Array selected_terrain_names = terrain_selection_phase.get("selected_project_terrain_ids", Array());
	Array selected_terrain_codes = terrain_selection_phase.get("selected_h3maped_terrain_ids", Array());
	Dictionary terrain_name_counts;
	Dictionary h3_terrain_code_counts;
	Dictionary cells_by_zone_word;
	Dictionary repaint_cells_by_terrain_code;
	Array per_zone_repaint_records;
	Array sample_cells;
	const int32_t cell_count = int32_t(zone_words.size());

	int32_t reserved_cell_count = 0;
	int32_t unassigned_cell_count = 0;
	int32_t non_water_terrain_cell_count = 0;
	int32_t owner_low_materialized_count = 0;
	Dictionary owner_low_byte_counts;
	for (int32_t index = 0; index < cell_count; ++index) {
		const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
		int32_t h3_terrain_code = 8;
		String terrain_name = "water";
		int32_t owner_low_byte = -1;
		if (masked == H3MAPED_UNASSIGNED_ZONE_WORD) {
			unassigned_cell_count += 1;
		} else {
			const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
			owner_low_byte = zone_word_id;
			owner_low_materialized_count += 1;
			const String owner_key = String::num_int64(owner_low_byte);
			owner_low_byte_counts[owner_key] = int32_t(owner_low_byte_counts.get(owner_key, 0)) + 1;
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
		const bool repaint_member = (cell_flags.size() == zone_words.size() && (cell_flags[size_t(index)] & 0x10U) != 0U);
		if (repaint_member) {
			reserved_cell_count += 1;
		}
		terrain_name_counts[terrain_name] = int32_t(terrain_name_counts.get(terrain_name, 0)) + 1;
		const String code_key = String::num_int64(h3_terrain_code);
		h3_terrain_code_counts[code_key] = int32_t(h3_terrain_code_counts.get(code_key, 0)) + 1;
		if (sample_cells.size() < 8) {
			Dictionary sample;
			sample["index"] = index;
			sample["x"] = index % width;
			sample["y"] = (index / width) % height;
			sample["level"] = index / (width * height);
			sample["owner_low_byte"] = owner_low_byte;
			sample["terrain_code"] = h3_terrain_code;
			sample["terrain_name"] = terrain_name;
			sample["repaint_member"] = repaint_member;
			sample_cells.append(sample);
		}
	}

	for (int32_t zone_index = 0; zone_index < selected_terrain_codes.size(); ++zone_index) {
		const int32_t zone_terrain_code = int32_t(selected_terrain_codes[zone_index]);
		const String zone_key = String::num_int64(zone_index);
		Dictionary zone_record;
		zone_record["runtime_zone_index"] = zone_index;
		zone_record["terrain_code"] = zone_terrain_code;
		zone_record["terrain_name"] = zone_index < selected_terrain_names.size() ? String(selected_terrain_names[zone_index]) : terrain_for_h3maped_id(zone_terrain_code);
		zone_record["single_cell_repaint_count"] = zone_terrain_code == 8 ? 0 : int32_t(cells_by_zone_word.get(zone_key, 0));
		zone_record["skipped_water_zone"] = zone_terrain_code == 8;
		per_zone_repaint_records.append(zone_record);
	}

	Dictionary terrain_repaint_schedule;
	terrain_repaint_schedule["status"] = "0x4a3f27_water_then_zone_single_cell_repaint_schedule_ported_private";
	terrain_repaint_schedule["initial_water_terrain_id"] = 8;
	terrain_repaint_schedule["initial_water_full_map_cell_count"] = cell_count;
	terrain_repaint_schedule["two_level_rock_prefill_address"] = "0x4a3f97";
	terrain_repaint_schedule["two_level_rock_prefill_executed"] = level_count > 1;
	terrain_repaint_schedule["single_cell_repaint_count"] = non_water_terrain_cell_count;
	terrain_repaint_schedule["repaint_cells_by_terrain_code"] = repaint_cells_by_terrain_code;
	terrain_repaint_schedule["per_zone_repaint_records"] = per_zone_repaint_records;
	terrain_repaint_schedule["materializes_visual_art"] = false;

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x4a3f27 terrain/cell writeout consumes the private real 0x4a325d zone-word buffer: full-map water repaint first, then per-runtime-zone terrain repaint; art/index/flip remain blocked before package adoption";
	phase["map_width"] = width;
	phase["map_height"] = height;
	phase["level_count"] = level_count;
	phase["cell_count"] = cell_count;
	phase["span_fill_status"] = span_fill_phase.get("status", "");
	phase["span_fill_total_boundary_or_filled_cell_count"] = span_fill_phase.get("total_boundary_or_filled_cell_count", 0);
	phase["span_fill_remaining_unassigned_cell_count"] = span_fill_phase.get("remaining_unassigned_cell_count", 0);
	phase["span_fill_reserved_flag_cell_count"] = span_fill_phase.get("reserved_flag_cell_count", 0);
	phase["owner_low_byte_source"] = "cell+0x20 bits 16..23 from real 0x4a325d zone word id";
	phase["owner_low_byte_materialized_count"] = owner_low_materialized_count;
	phase["owner_low_byte_counts"] = owner_low_byte_counts;
	phase["tile_byte_zero_terrain_cell_count"] = cell_count;
	phase["tile_byte_zero_non_water_terrain_cell_count"] = non_water_terrain_cell_count;
	phase["tile_byte_one_nonzero_art_cell_count"] = 0;
	phase["tile_byte_six_terrain_flip_cell_count"] = 0;
	phase["reserved_flag_cell_count"] = reserved_cell_count;
	phase["unassigned_water_cell_count"] = unassigned_cell_count;
	phase["terrain_name_counts"] = terrain_name_counts;
	phase["h3_terrain_code_counts"] = h3_terrain_code_counts;
	phase["cells_by_zone_word"] = cells_by_zone_word;
	phase["terrain_repaint_schedule"] = terrain_repaint_schedule;
	phase["sample_cells"] = sample_cells;
	phase["tile_byte_writeout_status"] = "0x49b2b6_terrain_id_byte_packed_art_flip_pending";
	phase["tile_byte_writeout_source"] = "0x49b2b6 serializes generated cell+0x24 bits 0..5 to terrain byte 0; terrain art byte 1 and terrain flip byte 6 bits 0..1 remain blocked until TerrainPlacement is ported";
	phase["blocked_next"] = "terrainplacement_visual_tables_4bcff5";
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

int32_t terrain_at_grid_index(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size())) {
		return fallback_terrain_id;
	}
	return terrain_codes[size_t(index)];
}

bool set_terrain_at_grid_index(std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
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

int64_t h3maped_grid_key(int32_t level, int32_t x, int32_t y) {
	return (int64_t(level) << 40) | (int64_t(y) << 20) | int64_t(x);
}

void h3maped_decode_grid_key(int64_t key, int32_t &level, int32_t &x, int32_t &y) {
	level = int32_t(key >> 40);
	y = int32_t((key >> 20) & 0xfffff);
	x = int32_t(key & 0xfffff);
}

std::array<int32_t, 8> h3maped_same_terrain_mask_4bc74c(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	std::array<int32_t, 8> mask = { 0, 0, 0, 0, 0, 0, 0, 0 };
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		return nx >= 0 && ny >= 0 && nx < width && ny < height && terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, nx, ny, -1) == terrain_id;
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

bool h3maped_horizontal_pair_gate_4bc674(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= width - 1 || y < 0 || y >= height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool h3maped_vertical_pair_gate_4bc6e0(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= height - 1 || x < 0 || x >= width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool h3maped_toolkit_byte5_allows_same_class_gate(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool h3maped_candidate_gate_4bc988_grid(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928(h3maped_same_terrain_mask_4bc74c(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id));
	return horizontal_pair_gate || vertical_pair_gate || (h3maped_toolkit_byte5_allows_same_class_gate(terrain_id) && same_class_region_gate);
}

int32_t h3maped_frontier_retouch_4bbd01(std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, Array *sample_records, int32_t sample_limit, std::vector<int64_t> *changed_keys_out = nullptr) {
	if (x < 0 || y < 0 || x >= width || y >= height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](const char *branch, int32_t target_x, int32_t target_y) {
		const bool changed = set_terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, target_x, target_y, terrain_id);
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
	if (h3maped_vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, width, height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, width, height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = h3maped_horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(choose_upper ? "0x4bbd01_vertical_upper" : "0x4bbd01_vertical_lower", x, choose_upper ? y - 1 : y + 1);
	}
	if (h3maped_horizontal_pair_gate_4bc674(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, width, height, level_tile_count, level, x - 1, y);
		const bool right_candidate = h3maped_candidate_gate_4bc988_grid(terrain_codes, width, height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = h3maped_vertical_pair_gate_4bc6e0(terrain_codes, width, height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? "0x4bbd01_horizontal_left" : "0x4bbd01_horizontal_right", choose_left ? x - 1 : x + 1, y);
	}
	const std::array<int32_t, 8> same_terrain_mask = h3maped_same_terrain_mask_4bc74c(terrain_codes, width, height, level_tile_count, level, x, y, terrain_id);
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
				if (target_x >= 0 && target_y >= 0 && target_x < width && target_y < height) {
					retouch("0x4bbd01_same_class_zero_run", target_x, target_y);
				}
				slot = (slot + 1) & 7;
			}
		}
	}
	return changed_count;
}

TerrainClassResult classify_grid_cell(const std::vector<int32_t> &terrain_codes, int32_t width, int32_t height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	std::array<int32_t, 8> relations = {
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x + 1, y - 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x + 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x + 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x - 1, y + 1, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x - 1, y, center)),
		h3maped_terrain_relation_4bb039(center, terrain_at_grid_index(terrain_codes, width, height, level_tile_count, level, x - 1, y - 1, center)),
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

Dictionary terrainplacement_visual_tables_4bcff5_phase(const Dictionary &terrain_cell_phase) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_visual_tables_4bcff5";
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
	if (String(terrain_cell_phase.get("status", "")) != "active_runtime_state_ready") {
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

	phase["status"] = decoded_total == 230 ? String("active_runtime_state_ready") : String("visual_table_decode_failed");
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

Dictionary terrainplacement_live_feedback_4bb74b_4bc5f0_phase(const Dictionary &normalized_config, const std::vector<uint32_t> &zone_words, const Dictionary &span_fill_phase, const Dictionary &runtime_terrain_phase, const Dictionary &terrain_cell_phase, const Dictionary &visual_tables_phase, std::vector<uint32_t> *out_live_cell_word_0x24 = nullptr, std::vector<uint32_t> *out_live_cell_word_0x28 = nullptr, std::vector<int32_t> *out_live_terrain_code = nullptr) {
	Dictionary phase;
	phase["phase_id"] = "terrainplacement_live_feedback_4bb74b_4bc5f0";
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
	if (String(visual_tables_phase.get("status", "")) != "active_runtime_state_ready" || String(terrain_cell_phase.get("status", "")) != "active_runtime_state_ready" || String(runtime_terrain_phase.get("status", "")) != "active_runtime_state_ready" || zone_words.empty()) {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t level_tile_count = width * height;
	const int32_t tile_count = int32_t(zone_words.size());
	const Array selected_terrain_codes = runtime_terrain_phase.get("selected_h3maped_terrain_ids", Array());
	if (tile_count != width * height * level_count || selected_terrain_codes.is_empty()) {
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

	H3MapedRng live_visual_rng { uint32_t(int64_t(span_fill_phase.get("boundary_rng_state_after_0x4a2777_uint32", 0))) };
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
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * width + x;
		if (index < 0 || index >= tile_count) {
			return false;
		}
		live_visual_attempt_count += 1;
		const TerrainClassResult classified = classify_grid_cell(live_terrain_code, width, height, level_tile_count, level, x, y, terrain_id);
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
	int32_t changed_cell_update_count = 0;
	int32_t set_a_insert_count = 0;
	int32_t set_b_insert_count = 0;
	int32_t max_set_a_count = 0;
	int32_t max_set_b_count = 0;

	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, x, y, current_terrain);
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
			const int32_t neighbor = terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, nx, ny, current_terrain);
			if (h3maped_toolkit_byte5_allows_same_class_gate(neighbor)) {
				append_set_b(level, nx, ny, current_terrain, "0x4bba59_diagonal_byte5_zero_neighbor");
			}
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
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
			sample["terrain_id"] = terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, x, y, -1);
			drain_samples.append(sample);
		}
	};
	auto seed_4bb74b_neighbor_branch = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper, const char *source_branch) {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		const bool gate = horizontal_pair_wrapper ? h3maped_horizontal_pair_gate_4bc674(live_terrain_code, width, height, level_tile_count, level, x, y, neighbor) : h3maped_vertical_pair_gate_4bc6e0(live_terrain_code, width, height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			seed_4bba59(level, x, y, current_terrain);
			append_set_b(level, x, y, current_terrain, source_branch);
		}
	};
	auto process_4bb74b_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0) {
			return;
		}
		set_terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, x, y, active_terrain);
		live_queue_attempt_count += 1;
		write_live_visual_cell(level, x, y, active_terrain, "0x4bb74b_queue_live_visual_feedback");
		if (!h3maped_toolkit_byte5_allows_same_class_gate(active_terrain)) {
			seed_4bb74b_neighbor_branch(level, x, y - 1, active_terrain, true, "0x4bb7b7_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x, y + 1, active_terrain, true, "0x4bb80b_neighbor_0x4bba13_false");
			seed_4bb74b_neighbor_branch(level, x - 1, y, active_terrain, false, "0x4bb863_neighbor_0x4bba36_false");
			seed_4bb74b_neighbor_branch(level, x + 1, y, active_terrain, false, "0x4bb8b7_neighbor_0x4bba36_false");
		} else if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, width, height, level_tile_count, level, x, y)) {
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
				retouched_cell_write_count += h3maped_frontier_retouch_4bbd01(live_terrain_code, width, height, level_tile_count, level, x, y, &drain_samples, 24, &changed_keys);
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
				if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, width, height, level_tile_count, level, x, y)) {
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
					const uint32_t masked = zone_words[size_t(index)] & H3MAPED_UNASSIGNED_ZONE_WORD;
					if (masked == H3MAPED_UNASSIGNED_ZONE_WORD || int32_t((masked >> 16U) & 0xffU) != int32_t(zone_index)) {
						continue;
					}
					changed_cell_update_count += 1;
					if (set_terrain_at_grid_index(live_terrain_code, width, height, level_tile_count, level, x, y, terrain)) {
						live_repaint_attempt_count += 1;
						write_live_visual_cell(level, x, y, terrain, "0x4bb74b_repaint_live_visual_feedback");
						if (h3maped_candidate_gate_4bc988_grid(live_terrain_code, width, height, level_tile_count, level, x, y)) {
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
		const uint32_t roundtrip_0x28 = ((scratch_word >> 12U) & 0x01U) << 15U | (((scratch_word >> 13U) & 0x01U) << 16U);
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

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x4bb74b/0x4bc5f0 live repaint queue scratch feedback ported as private generated-cell evidence; no package tile/public grid adoption";
	phase["tile_count"] = tile_count;
	phase["exact_queue_drain_complete"] = true;
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

Dictionary terrain_tile_byte_writeback_49b2b6_phase(const Dictionary &normalized_config, const Dictionary &live_feedback_phase, const std::vector<uint32_t> &live_cell_word_0x24, const std::vector<uint32_t> &live_cell_word_0x28, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "terrain_tile_byte_writeback_49b2b6";
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
	if (String(live_feedback_phase.get("status", "")) != "active_runtime_state_ready"
			|| live_cell_word_0x24.empty()
			|| live_cell_word_0x24.size() != live_cell_word_0x28.size()
			|| live_cell_word_0x24.size() != live_terrain_code.size()) {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_tile_count = width * height;
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
			sample["x"] = index % width;
			sample["y"] = (index / width) % height;
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

	phase["status"] = "active_runtime_state_ready";
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

Dictionary town_castle_phase_4a8d2c_phase(const Dictionary &normalized_config, const Dictionary &runtime_zone_phase, const Dictionary &coordinate_phase, const Dictionary &runtime_terrain_phase, const Dictionary &terrain_tile_writeback_phase, const std::vector<uint32_t> &zone_words, const std::vector<int32_t> &live_terrain_code) {
	Dictionary phase;
	phase["phase_id"] = "town_castle_phase_4a8d2c";
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
	phase["blocked_next"] = "roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243";
	if (String(runtime_zone_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(coordinate_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(runtime_terrain_phase.get("status", "")) != "active_runtime_state_ready"
			|| String(terrain_tile_writeback_phase.get("status", "")) != "active_runtime_state_ready"
			|| zone_words.empty()
			|| zone_words.size() != live_terrain_code.size()) {
		return phase;
	}

	const int32_t width = int32_t(normalized_config.get("width", 36));
	const int32_t height = int32_t(normalized_config.get("height", 36));
	const int32_t level_count = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	const int32_t cell_count = int32_t(zone_words.size());
	const int32_t expected_cell_count = width * height * level_count;
	Array runtime_zone_records = runtime_zone_phase.get("runtime_zone_records", Array());
	Array runtime_after_town_choice = coordinate_phase.get("runtime_zone_records_after_0x49b3c1", Array());
	Array selected_terrain_ids = runtime_terrain_phase.get("selected_h3maped_terrain_ids", Array());
	Array selected_project_terrain_ids = runtime_terrain_phase.get("selected_project_terrain_ids", Array());
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
	H3MapedRng object_rng { uint32_t(int64_t(runtime_terrain_phase.get("rng_state_after_0x49b53d_uint32", coordinate_phase.get("rng_state_after_0x4a218c_replay_uint32", 0)))) };
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

		if (width <= 0 || height <= 0 || expected_cell_count <= 0 || cell_count != expected_cell_count) {
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

		for (int32_t level = 0; level < level_count; ++level) {
			if (level != anchor_level) {
				continue;
			}
			for (int32_t y = 0; y < height; ++y) {
				for (int32_t x = 0; x < width; ++x) {
					const int32_t cell_index = level * width * height + y * width + x;
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
	direct_stamping["blocked_next"] = "roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243";

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
	project_town_adoption_candidate["blocked_next"] = "roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243";

	phase["status"] = "active_runtime_state_ready";
	phase["source"] = "h3maped 0x4a8d2c/0x4a8db2 town/castle phase and 0x4a93a2 direct town record projection ported as private candidates only";
	phase["map_width"] = width;
	phase["map_height"] = height;
	phase["level_count"] = level_count;
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
	phase["blocked_next"] = "roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243";
	return phase;
}

Dictionary small_pipeline_state(const Dictionary &normalized_config) {
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_generation_state_v1";
	state["runtime_generation_allowed"] = false;
	state["partial_materialized_payload_public_api"] = false;
	state["materializes_runtime_players"] = false;
	state["materializes_map_cells"] = false;
	state["materializes_public_output"] = false;

	Dictionary selection = selection_identity(normalized_config);
	state["selection_identity"] = selection;
	if (!bool(selection.get("ok", false))) {
		state["status"] = "blocked_before_template_selection";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	const TemplateEvidence *selected_template = template_for_catalog_index(int32_t(selection.get("source_catalog_index", -1)));
	if (selected_template == nullptr) {
		state["status"] = "blocked_missing_selected_template";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	Array completed_phases;
	completed_phases.append("template_selection");
	Dictionary player_phase = player_slot_assignment_phase(*selected_template, normalized_config);
	completed_phases.append("player_slot_assignment");
	Dictionary runtime_zone_phase = runtime_zone_records_phase(selection, player_phase);
	if (String(runtime_zone_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("runtime_zone_records");
	}
	Dictionary link_phase = link_seed_phase(selection, normalized_config, runtime_zone_phase);
	if (String(link_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("link_seed_setup");
	}
	Dictionary coordinate_phase = coordinate_replay_phase(
			normalized_config,
			runtime_zone_phase,
			link_phase,
			uint32_t(int64_t(selection.get("rng_state_after_selection_uint32", 0))));
	if (String(coordinate_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("coordinate_replay");
	}
	Dictionary zone_footprint_phase = zone_footprint_phase_boundary(normalized_config, runtime_zone_phase, coordinate_phase);
	if (String(zone_footprint_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("zone_footprint_phase_boundary");
	}
	Dictionary source_node_phase = source_node_rectangle_phase(zone_footprint_phase);
	if (String(source_node_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("source_node_rectangle");
	}
	Dictionary polygon_split_phase = polygon_split_model_phase(normalized_config, coordinate_phase, source_node_phase);
	if (String(polygon_split_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("polygon_split_model");
	}
	std::vector<uint32_t> boundary_zone_words;
	std::vector<uint8_t> boundary_cell_flags;
	Dictionary boundary_traversal_phase = source_node_boundary_traversal_phase(normalized_config, coordinate_phase, polygon_split_phase, &boundary_zone_words, &boundary_cell_flags);
	if (String(boundary_traversal_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("source_node_boundary_traversal");
	}
	std::vector<uint32_t> span_fill_zone_words;
	std::vector<uint8_t> span_fill_cell_flags;
	Dictionary span_fill_phase = span_fill_4a325d_phase(normalized_config, coordinate_phase, polygon_split_phase, boundary_traversal_phase, boundary_zone_words, boundary_cell_flags, &span_fill_zone_words, &span_fill_cell_flags);
	if (String(span_fill_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("span_fill_4a325d");
	}
	Dictionary footprint_finalizer_phase = footprint_finalizer_4a3710_phase(normalized_config, runtime_zone_phase, zone_footprint_phase, span_fill_phase);
	if (String(footprint_finalizer_phase.get("status", "")) == "0x4a3710_small_land_no_appended_zone_finalizer_ported_private") {
		completed_phases.append("footprint_finalizer_4a3710");
	}
	Dictionary runtime_terrain_phase = runtime_terrain_selection_49b53d_phase(runtime_zone_phase, coordinate_phase, footprint_finalizer_phase);
	if (String(runtime_terrain_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("runtime_terrain_selection_49b53d");
	}
		Dictionary terrain_cell_phase = terrain_cell_writeout_4a3f27_phase(normalized_config, span_fill_phase, runtime_terrain_phase, span_fill_zone_words, span_fill_cell_flags);
		if (String(terrain_cell_phase.get("status", "")) == "active_runtime_state_ready") {
			completed_phases.append("terrain_cell_writeout_4a3f27");
		}
		Dictionary terrainplacement_visual_tables_phase = terrainplacement_visual_tables_4bcff5_phase(terrain_cell_phase);
		if (String(terrainplacement_visual_tables_phase.get("status", "")) == "active_runtime_state_ready") {
			completed_phases.append("terrainplacement_visual_tables_4bcff5");
		}
		std::vector<uint32_t> live_cell_word_0x24;
		std::vector<uint32_t> live_cell_word_0x28;
		std::vector<int32_t> live_terrain_code;
		Dictionary terrainplacement_live_feedback_phase = terrainplacement_live_feedback_4bb74b_4bc5f0_phase(normalized_config, span_fill_zone_words, span_fill_phase, runtime_terrain_phase, terrain_cell_phase, terrainplacement_visual_tables_phase, &live_cell_word_0x24, &live_cell_word_0x28, &live_terrain_code);
		if (String(terrainplacement_live_feedback_phase.get("status", "")) == "active_runtime_state_ready") {
			completed_phases.append("terrainplacement_live_feedback_4bb74b_4bc5f0");
		}
		Dictionary terrain_tile_byte_writeback_phase = terrain_tile_byte_writeback_49b2b6_phase(normalized_config, terrainplacement_live_feedback_phase, live_cell_word_0x24, live_cell_word_0x28, live_terrain_code);
		if (String(terrain_tile_byte_writeback_phase.get("status", "")) == "active_runtime_state_ready") {
			completed_phases.append("terrain_tile_byte_writeback_49b2b6");
		}
		Dictionary town_castle_phase = town_castle_phase_4a8d2c_phase(normalized_config, runtime_zone_phase, coordinate_phase, runtime_terrain_phase, terrain_tile_byte_writeback_phase, span_fill_zone_words, live_terrain_code);
		if (String(town_castle_phase.get("status", "")) == "active_runtime_state_ready") {
			completed_phases.append("town_castle_phase_4a8d2c");
		}
		const bool town_castle_ready = completed_phases.has("town_castle_phase_4a8d2c");
		const bool terrain_tile_byte_writeback_ready = completed_phases.has("terrain_tile_byte_writeback_49b2b6");
		const bool terrainplacement_live_feedback_ready = completed_phases.has("terrainplacement_live_feedback_4bb74b_4bc5f0");
		const bool terrainplacement_visual_tables_ready = completed_phases.has("terrainplacement_visual_tables_4bcff5");
		const bool terrain_cell_ready = completed_phases.has("terrain_cell_writeout_4a3f27");
		const bool runtime_terrain_ready = completed_phases.has("runtime_terrain_selection_49b53d");
		const bool footprint_finalizer_ready = completed_phases.has("footprint_finalizer_4a3710");
	const bool span_fill_ready = completed_phases.has("span_fill_4a325d");
	const bool boundary_traversal_ready = completed_phases.has("source_node_boundary_traversal");
	const bool polygon_split_ready = completed_phases.has("polygon_split_model");
	const bool source_node_ready = completed_phases.has("source_node_rectangle");
	const bool coordinate_ready = completed_phases.has("coordinate_replay");
		state["status"] = town_castle_ready ? String("town_castle_phase_4a8d2c_active_runtime_state_ready") : (terrain_tile_byte_writeback_ready ? String("terrain_tile_byte_writeback_49b2b6_active_runtime_state_ready") : (terrainplacement_live_feedback_ready ? String("terrainplacement_live_feedback_4bb74b_4bc5f0_active_runtime_state_ready") : (terrainplacement_visual_tables_ready ? String("terrainplacement_visual_tables_4bcff5_active_runtime_state_ready") : (terrain_cell_ready ? String("terrain_cell_writeout_4a3f27_active_runtime_state_ready") : (runtime_terrain_ready ? String("runtime_terrain_selection_49b53d_active_runtime_state_ready") : (footprint_finalizer_ready ? String("footprint_finalizer_4a3710_active_runtime_state_ready") : (span_fill_ready ? String("span_fill_4a325d_active_runtime_state_ready") : (boundary_traversal_ready ? String("source_node_boundary_traversal_active_runtime_state_ready") : (polygon_split_ready ? String("polygon_split_model_active_runtime_state_ready") : (source_node_ready ? String("source_node_rectangle_active_runtime_state_ready") : (coordinate_ready ? String("coordinate_replay_active_runtime_state_ready") : (completed_phases.size() >= 3 ? String("runtime_zone_records_active_runtime_state_ready") : String("player_slot_assignment_active_runtime_state_ready")))))))))))));
	state["completed_phase_ids"] = completed_phases;
	state["completed_phase_count"] = completed_phases.size();
	state["player_slot_assignment"] = player_phase;
	state["runtime_zone_records"] = runtime_zone_phase;
	state["link_seed_setup"] = link_phase;
	state["coordinate_replay"] = coordinate_phase;
	state["zone_footprint_phase_boundary"] = zone_footprint_phase;
	state["source_node_rectangle"] = source_node_phase;
	state["polygon_split_model"] = polygon_split_phase;
	state["source_node_boundary_traversal"] = boundary_traversal_phase;
	state["span_fill_4a325d"] = span_fill_phase;
	state["footprint_finalizer_4a3710"] = footprint_finalizer_phase;
		state["runtime_terrain_selection_49b53d"] = runtime_terrain_phase;
		state["terrain_cell_writeout_4a3f27"] = terrain_cell_phase;
		state["terrainplacement_visual_tables_4bcff5"] = terrainplacement_visual_tables_phase;
		state["terrainplacement_live_feedback_4bb74b_4bc5f0"] = terrainplacement_live_feedback_phase;
		state["terrain_tile_byte_writeback_49b2b6"] = terrain_tile_byte_writeback_phase;
		state["town_castle_phase_4a8d2c"] = town_castle_phase;
		state["blocked_next"] = town_castle_ready ? String("roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243") : (terrain_tile_byte_writeback_ready ? String("town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2") : (terrainplacement_live_feedback_ready ? String("private_0x49b2b6_tile_byte_writeback_candidate") : (terrainplacement_visual_tables_ready ? String("live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback") : (terrain_cell_ready ? String("terrainplacement_visual_tables_4bcff5") : (runtime_terrain_ready ? String("terrain_cell_writeout_4a3f27") : (footprint_finalizer_ready ? String("runtime_terrain_selection_49b53d") : (span_fill_ready ? String("footprint_finalizer_4a3710") : (boundary_traversal_ready ? String("span_fill_4a325d") : (polygon_split_ready ? String("source_node_boundary_traversal_0x4a2777") : (source_node_ready ? String("polygon_split_model_0x4ccb64_0x4ccdfc") : (coordinate_ready ? String("zone_footprint_source_nodes_0x4a3a03_0x4cc788") : (completed_phases.size() >= 3 ? String("coordinate_replay_and_zone_footprints_0x4a1f3b") : String("runtime_zone_records_0x4a218c")))))))))))));
		return state;
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
		"0x4a1f3b/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed/0x4a3a03/0x4ccb64/0x4ccdfc/0x4a2777/0x4a325d/0x4a3710",
		"0x4a3f27/0x4bcff5/0x4bb74b/0x4bc5f0/0x49acf6/0x49b2b6",
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
			phase["status"] = index == 0 ? String("active_boundary_only") : (index <= 5 ? String("active_runtime_state_ready") : String("pending_strict_port"));
		phase["materializes_public_output"] = false;
		phase["requires_exe_derived_implementation_before_runtime"] = index > 5;
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
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_restart_boundary_v2";
	report["schema_version"] = 2;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_restart_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "small_only_h3maped_exe_restart_no_catalog_auto_no_hash_selection_no_private_phase_ledger_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "overgrown_active_port_archived_out_of_build";
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
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
	report["small_generation_state"] = small_pipeline_state(normalized_config);
	report["restart_phase_backlog"] = restart_backlog();
		report["materialized_phase_status"] = "terrainplacement_visual_tables_private_state_only";
		report["blocked_before_materialization"] = "waiting_for_strict h3maped TerrainPlacement live feedback and package-adoption phase ports from 0x4ac552";
	report["explicitly_absent_reports"] = "terrain, towns, roads, blockers, guards, mines, rewards, and final writeout are absent until implemented as runtime generator phases";
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
	result["message"] = "Small h3maped-derived RMG has been restarted from a compact executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["small_generation_state"] = small_pipeline_state(normalized_config);
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
