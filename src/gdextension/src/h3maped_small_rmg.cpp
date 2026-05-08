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
	String branch;
	bool input_inside = false;
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
	report["next_materialization_status"] = "pending_clean_port_0x4a3a03_boundary_after_coordinate_replay";
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
		uint32_t rng_state_after_coordinate_seed) {
	Dictionary report;
	report["status"] = "0x4a325d_real_0x4a2777_boundary_span_fill_executed_terrain_pending";
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
	report["blocked_next"] = "feed the 0x4a325d span fill through the small-land 0x4a3710 finalizer, then port h3maped 0x4a3f27 terrain fill/repaint before runtime map generation can adopt the materialized grid";
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
			? String("continue after the completed small-land 0x4a3710 no-appended-zone path into h3maped 0x4a3f27 terrain fill/repaint")
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
	report["status"] = "0x4a3a03_0x4a3710_footprint_helpers_ported_terrain_pending";
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
	report["cell_materialization_status"] = "0x4a3710_small_land_finalizer_ported_pending_0x4a3f27";
	report["blocked_next"] = "execute 0x4a3f27 terrain fill/repaint before any project terrain/object materialization";

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
	Dictionary span_fill = span_fill_4a325d_report(
			normalized_config,
			runtime_zones,
			source_walks,
			uint32_t(rng_state_after_coordinate_seed));
	Dictionary adjacency_finalizer = adjacency_finalizer_4a3710_report(normalized_config, runtime_zones);
	polygon_seed["runtime_split_pre_crossing_model"] = source_walks;
	polygon_seed["runtime_split_pre_crossing_status"] = source_walks.get("status", "");
	polygon_seed["boundary_traversal_model"] = boundary_traversal;
	polygon_seed["boundary_traversal_status"] = boundary_traversal.get("status", "");
	polygon_seed["span_fill_model"] = span_fill;
	polygon_seed["span_fill_status"] = span_fill.get("status", "");
	polygon_seed["adjacency_finalizer_model"] = adjacency_finalizer;
	polygon_seed["adjacency_finalizer_status"] = adjacency_finalizer.get("status", "");
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
		{ "zone_footprint_placement", "0x4a3a03, 0x4cc788, 0x4cca55, 0x4ccb64, 0x4ccdfc, 0x4a2777, 0x4a325d, 0x4a3710", "ported_0x4a3710_small_land_footprint_helpers_inspection_only_terrain_pending" },
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
