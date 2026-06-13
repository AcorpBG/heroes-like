#include "rmg_native_core.hpp"
#include "h3maped_small_rmg_embedded_data.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <limits>
#include <map>
#include <sstream>

namespace aurelion::rmg_native_core {
namespace {

struct JsonSpan {
	size_t begin = 0;
	size_t end = 0;
	bool ok = false;
};

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
};

struct GeneratorModeResolutionPlain {
	bool setup_object_0x44_known = false;
	int32_t setup_object_0x44 = 0;
	bool generator_mode_known = false;
	int32_t generator_mode_0x10b8 = 0;
	bool randomized_from_setup_value_3 = false;
	int32_t randomization_rng_value = -1;
	uint32_t rng_state_after_0x49ecf2 = 0;
	int32_t pre_template_rng_call_count = 0;
};

struct TemplateRecord {
	int32_t catalog_index = -1;
	std::string id;
	std::string name;
	int32_t min_size_score = 0;
	int32_t max_size_score = 0;
	int32_t min_humans = 0;
	int32_t max_humans = 0;
	int32_t min_total_players = 0;
	int32_t max_total_players = 0;
	int32_t filtered_zone_count = 0;
	int32_t unfiltered_zone_count = 0;
	int32_t filtered_connection_count = 0;
	int32_t unfiltered_connection_count = 0;
	uint8_t human_capable_source_owner_mask = 0;
	uint8_t player_capable_source_owner_mask = 0;
	JsonSpan object_span;
	JsonSpan zones_span;
	JsonSpan connections_span;
};

struct RuntimeZoneSummary {
	bool ok = false;
	std::string blocked_reason;
	GeneratorModeResolutionPlain generator_mode;
	int32_t accepted_template_count = 0;
	int32_t template_selection_rng_value = 0;
	uint32_t rng_state_after_selection = 0;
	int32_t selected_vector_index = -1;
	TemplateRecord selected;
	std::vector<int32_t> mapped_slots;
	std::vector<int32_t> assignment_source_owners;
	std::vector<JsonSpan> selected_zone_spans;
};

struct RuntimeZoneRecordPlain {
	int32_t runtime_index = -1;
	int32_t source_zone_id = -1;
	std::string role;
	int32_t source_bucket = -1;
	int32_t source_owner_index = -1;
	int32_t actual_owner_color = -1;
	bool is_player_capable_zone = false;
	bool has_assigned_start = false;
	int32_t source_base_size = 0;
	std::vector<int32_t> allowed_town_slots;
	int32_t town_choice_rng_value = -1;
	int32_t town_choice_index = -1;
	int32_t town_choice_selected_allowed_ordinal = -1;
	int32_t x_after_bbox_rescale = 0;
	int32_t y_after_bbox_rescale = 0;
	int32_t level_after_bbox_rescale = 0;
	int32_t runtime_size_after_bbox_rescale = 0;
};

struct RuntimeLinkSeedPlain {
	int32_t link_index = -1;
	int32_t source_row = -1;
	int32_t source_zone_a = -1;
	int32_t source_zone_b = -1;
	int32_t runtime_a = -1;
	int32_t runtime_b = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
};

struct CoordCandidate {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct PlacementStepPlain {
	std::string pass_id;
	int32_t runtime_zone_index = -1;
	std::vector<int32_t> visible_runtime_zone_indices;
	std::string candidate_source;
	int32_t explicit_link_base_count = 0;
	int32_t fallback_base_count = 0;
	int32_t candidate_count_before_4a1ad8 = 0;
	int32_t candidate_count_after_4a1ad8 = 0;
	std::vector<CoordCandidate> candidate_preview_before_4a1ad8;
	std::vector<CoordCandidate> candidate_preview_after_4a1ad8;
	bool blocked = false;
	std::string blocked_reason;
	int32_t rng_value = -1;
	int32_t selected_candidate_index = -1;
	CoordCandidate selected_candidate;
};

struct RngEventPlain {
	std::string consumer;
	int32_t runtime_zone_index = -1;
	std::string pass_id;
	int32_t value = 0;
	int32_t modulus = 0;
	int32_t selected_index = -1;
	std::vector<int32_t> allowed_original_town_indices;
};

struct CoordinateReplaySummary {
	bool ok = false;
	std::string blocked_reason;
	int32_t minimum_source_base_size = 0;
	int32_t coordinate_prune_divisor_4a218c = 5;
	int32_t coordinate_prune_span_budget_4a218c = 0;
	int32_t coordinate_rng_calls = 0;
	int32_t town_choice_rng_calls = 0;
	uint32_t rng_state_after_0x4a218c = 0;
	int32_t bbox_min_y = 0;
	int32_t bbox_min_x = 0;
	int32_t bbox_max_y = 0;
	int32_t bbox_max_x = 0;
	int32_t bbox_height = 0;
	int32_t bbox_width = 0;
	int32_t bbox_span = 0;
	int32_t map_span = 0;
	int32_t offset_y = 0;
	int32_t offset_x = 0;
	std::vector<RuntimeZoneRecordPlain> runtime_records_after_0x49b3c1;
	std::vector<RuntimeLinkSeedPlain> link_seeds;
	std::vector<PlacementStepPlain> placement_steps;
	std::vector<RngEventPlain> rng_events;
	std::vector<RuntimeZoneRecordPlain> scaled_zone_coordinates;
};

struct PolygonPointPlain {
	int32_t x = 0;
	int32_t y = 0;
};

struct PolygonModelNodePlain {
	std::string id;
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

struct SourceSplitStepPlain {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t x = 0;
	int32_t y = 0;
	std::string status;
	int32_t bridge_pair_count = 0;
	int32_t crossing_cleanup_scan_count = 0;
	int32_t crossing_test_count = 0;
	int32_t crossing_collapse_count = 0;
};

struct SourceCycleNodePlain {
	int32_t x = 0;
	int32_t y = 0;
	bool has_payload = false;
	int32_t payload = 0;
	bool next_pair_has_payload = false;
	int32_t next_pair_payload = 0;
	bool finalized = false;
	int32_t finalized_x = -1;
	int32_t finalized_y = -1;
};

struct SourceWalkPlain {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t start_x = 0;
	int32_t start_y = 0;
	std::vector<SourceCycleNodePlain> cycle_nodes;
};

struct PolygonSourceResultPlain {
	bool blocked = false;
	int32_t duplicate_skip_count = 0;
	int32_t edge_removal_count = 0;
	int32_t inserted_node_pair_count = 0;
	int32_t executed_split_count = 0;
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
	std::vector<SourceSplitStepPlain> split_steps;
	std::vector<SourceWalkPlain> walks;
};

struct SyntheticRuntimeZoneAttemptPlain {
	int32_t base_runtime_zone_index = -1;
	int32_t base_source_zone_id = -1;
	int32_t direction_byte_offset = 0;
	int32_t direction_table_index = 0;
	int32_t base_x = 0;
	int32_t base_y = 0;
	int32_t base_level = 0;
	int32_t base_radius = 0;
	int32_t candidate_x = 0;
	int32_t candidate_y = 0;
	int32_t candidate_level = 0;
	bool accepted = false;
	int32_t synthetic_runtime_zone_index = -1;
	std::string status;
};

struct SyntheticRuntimeZoneReplaySummaryPlain {
	bool ported_plain_cpp = false;
	bool generator_mode_known = false;
	bool branch_allowed = false;
	std::string status = "blocked_until_generator_mode";
	std::string blocked_reason = "generator_mode_unknown";
	int32_t initial_runtime_zone_count = 0;
	int32_t runtime_zone_count_after_append = 0;
	int32_t scan_attempt_count = 0;
	int32_t accepted_count = 0;
	int32_t rejected_count = 0;
	std::vector<SyntheticRuntimeZoneAttemptPlain> attempts;
	std::vector<RuntimeZoneRecordPlain> runtime_zones_after_append;
};

struct SourceNodeFootprintSummary {
	bool coordinate_replay_available = false;
	bool supported_scope = false;
	bool source_nodes_built = false;
	bool source_blocked = false;
	std::string status = "blocked_until_coordinate_replay";
	std::string blocked_reason = "coordinate_replay_missing";
	GeneratorModeResolutionPlain generator_mode;
	bool generator_mode_0x10b8_known = false;
	int32_t generator_mode_0x10b8 = 0;
	bool synthetic_branch_allowed = false;
	int32_t total_matching_runtime_zones = 0;
	SyntheticRuntimeZoneReplaySummaryPlain synthetic_append;
	std::vector<RuntimeZoneRecordPlain> runtime_zones_after_synthetic_append;
	PolygonSourceResultPlain source;
};

struct LineCellWritePlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t zone_id = 0;
	bool reserved = false;
};

struct LineWriteResultPlain {
	std::vector<LineCellWritePlain> trace;
	std::map<int64_t, bool> unique_cells;
	int32_t out_of_bounds_write_count = 0;
};

struct SpanRecordPlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct SpanFillCellWritePlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t zone_id = 0;
	bool reserved = false;
};

struct SpanFillResultPlain {
	std::vector<SpanFillCellWritePlain> trace;
	std::map<int64_t, bool> unique_cells;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
};

struct ClipBoundsPlain {
	int32_t min_x = 0;
	int32_t min_y = 0;
	int32_t max_x = 0;
	int32_t max_y = 0;
};

struct ClipResultPlain {
	int32_t x = 0;
	int32_t y = 0;
	std::string branch;
	bool input_inside = false;
};

struct ZoneSpanFillSummaryPlain {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t zone_word_id = -1;
	std::string status;
	std::string seed_relocation_status;
	int32_t seed_x = 0;
	int32_t seed_y = 0;
	int32_t seed_level = 0;
	int32_t effective_seed_x = 0;
	int32_t effective_seed_y = 0;
	int32_t effective_seed_level = 0;
	bool seed_relocated = false;
	bool seed_in_bounds = false;
	bool seed_unassigned_before_fill = false;
	int32_t filled_cell_count = 0;
	int32_t unique_filled_cell_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
};

struct BoundarySpanFillSummary {
	bool coordinate_replay_available = false;
	bool source_node_walks_available = false;
	bool supported_scope = false;
	bool boundary_span_fill_materialized_plain_cpp = false;
	bool private_zone_cell_buffer_materialized = false;
	bool same_level_synthetic_runtime_zone_append_ported = false;
	bool same_level_synthetic_runtime_zone_branch_allowed = false;
	int32_t same_level_synthetic_runtime_zone_count = 0;
	int32_t runtime_zone_count_after_synthetic_append = 0;
	std::string status = "blocked_until_source_node_footprint_summary";
	std::string blocked_reason = "source_node_footprint_summary_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t water_code = 0;
	uint32_t rng_state_before_0x4a2777 = 0;
	uint32_t rng_state_after_0x4a2777 = 0;
	int32_t boundary_runtime_zone_walk_count = 0;
	int32_t boundary_blocked_zone_count = 0;
	int32_t boundary_fallback_zone_count = 0;
	int32_t boundary_connector_segment_count = 0;
	int32_t boundary_wrap_segment_count = 0;
	int32_t boundary_final_segment_count = 0;
	int32_t boundary_appended_vertex_count = 0;
	int32_t boundary_skipped_unfinalized_node_count = 0;
	int32_t boundary_skipped_out_of_bounds_clip_count = 0;
	int32_t boundary_owner_gate_skipped_segment_count = 0;
	int32_t boundary_flagged_writer_segment_count = 0;
	int32_t boundary_deterministic_writer_segment_count = 0;
	int32_t boundary_randomized_rng_call_count = 0;
	int32_t boundary_randomized_inserted_midpoint_count = 0;
	int32_t boundary_randomized_max_pending_point_count = 0;
	int32_t boundary_trace_write_count = 0;
	int32_t boundary_unique_cell_count = 0;
	int32_t boundary_out_of_bounds_write_count = 0;
	bool boundary_loop_guard_exhausted = false;
	int32_t span_fill_attempt_count = 0;
	int32_t span_fill_filled_zone_count = 0;
	int32_t span_fill_seed_blocked_count = 0;
	int32_t span_fill_seed_relocated_count = 0;
	int32_t span_fill_unique_filled_cell_count = 0;
	int32_t span_fill_boundary_or_filled_cell_count = 0;
	int32_t span_fill_remaining_unassigned_cell_count = 0;
	int32_t span_fill_pushed_span_count = 0;
	int32_t span_fill_popped_span_count = 0;
	int32_t span_fill_max_pending_span_count = 0;
	int32_t span_fill_out_of_bounds_span_count = 0;
	int32_t span_fill_blocked_initial_span_count = 0;
	std::map<int32_t, int32_t> cells_by_zone_word;
	std::vector<ZoneSpanFillSummaryPlain> zone_fills;
	bool generated_cell_owner_words_materialized = false;
	int32_t generated_cell_word_0x20_owner_byte_materialized_count = 0;
	int32_t generated_cell_word_0x20_unassigned_sentinel_count = 0;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<int32_t> generated_cell_terrain_code;
};

struct PolygonModelPlain {
	std::vector<PolygonModelNodePlain> nodes;
	int32_t root = -1;

	int32_t add_pair(const std::string &prefix, int32_t from_x, int32_t from_y, int32_t from_payload, int32_t to_x, int32_t to_y, int32_t to_payload, bool from_has_payload = false, bool to_has_payload = false) {
		const int32_t primary_index = int32_t(nodes.size());
		const int32_t paired_index = primary_index + 1;
		PolygonModelNodePlain primary;
		primary.id = prefix + "_primary";
		primary.x = from_x;
		primary.y = from_y;
		primary.payload = from_payload;
		primary.has_payload = from_has_payload;
		primary.pair = paired_index;
		primary.next = primary_index;
		primary.previous = primary_index;
		PolygonModelNodePlain paired;
		paired.id = prefix + "_paired";
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

	int32_t bridge_4ccb1f(int32_t old_node, int32_t target_node, const std::string &prefix) {
		const PolygonModelNodePlain &old_pair = nodes[size_t(nodes[size_t(old_node)].pair)];
		const PolygonModelNodePlain &target = nodes[size_t(target_node)];
		const int32_t bridge_primary = add_pair(prefix, old_pair.x, old_pair.y, old_pair.payload, target.x, target.y, target.payload, old_pair.has_payload, target.has_payload);
		relink_4cc643(bridge_primary, nodes[size_t(nodes[size_t(old_node)].pair)].previous);
		relink_4cc643(nodes[size_t(bridge_primary)].pair, target_node);
		return bridge_primary;
	}

	int64_t side_4cca55(int32_t from_node, int32_t to_node, int32_t x, int32_t y) const {
		const PolygonModelNodePlain &from = nodes[size_t(from_node)];
		const PolygonModelNodePlain &to = nodes[size_t(to_node)];
		return int64_t(to.y - from.y) * int64_t(x - from.x) - int64_t(to.x - from.x) * int64_t(y - from.y);
	}

	int32_t locate_4cca55(int32_t x, int32_t y) const {
		int32_t current = root;
		for (int32_t guard = 0; guard < 512 && current >= 0 && current < int32_t(nodes.size()); ++guard) {
			const PolygonModelNodePlain &current_node = nodes[size_t(current)];
			if (current_node.x == x && current_node.y == y) {
				return current;
			}
			const int32_t paired = current_node.pair;
			const PolygonModelNodePlain &paired_node = nodes[size_t(paired)];
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
		const PolygonModelNodePlain &node = nodes[size_t(node_index)];
		const PolygonModelNodePlain &paired = nodes[size_t(node.pair)];
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
		const PolygonModelNodePlain &node = nodes[size_t(node_index)];
		const PolygonModelNodePlain &paired = nodes[size_t(node.pair)];
		const PolygonModelNodePlain &previous_pair = nodes[size_t(nodes[size_t(node.previous)].pair)];
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

	static PolygonPointPlain intersection_4ccd69(int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t x3, int32_t y3) {
		const int64_t term = int64_t(y3 - y2) * int64_t(y1 - y3) + int64_t(x1 - x3) * int64_t(x3 - x2);
		const int64_t denominator = int64_t(x1 - x3) * int64_t(y1 - y2) + int64_t(y1 - y3) * int64_t(x2 - x1);
		const int64_t x_adjust = idiv_truncate(int64_t(y1 - y2) * term, denominator);
		const int64_t y_adjust = idiv_truncate(int64_t(x2 - x1) * term, denominator);
		return PolygonPointPlain {
			x1 + half_truncate_4ccd69(int64_t(x2 - x1) + x_adjust),
			y1 + half_truncate_4ccd69(int64_t(y2 - y1) + y_adjust)
		};
	}

	void write_finalized_4ccdfc(int32_t node_index, const PolygonPointPlain &point) {
		nodes[size_t(node_index)].finalized_x = point.x;
		nodes[size_t(node_index)].finalized_y = point.y;
		nodes[size_t(node_index)].finalized = true;
	}

	int32_t finalize_4ccdfc() {
		int32_t finalized_triplets = 0;
		for (int32_t index = 0; index < int32_t(nodes.size()); ++index) {
			PolygonModelNodePlain &node = nodes[size_t(index)];
			if (!node.active || !node.has_payload || node.finalized) {
				continue;
			}
			const int32_t next_pair = nodes[size_t(node.next)].pair;
			const PolygonModelNodePlain &paired = nodes[size_t(node.pair)];
			const PolygonModelNodePlain &next_pair_node = nodes[size_t(next_pair)];
			const PolygonPointPlain point = intersection_4ccd69(node.x, node.y, paired.x, paired.y, next_pair_node.x, next_pair_node.y);
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

std::string trim(const std::string &value) {
	size_t begin = 0;
	while (begin < value.size() && std::isspace(static_cast<unsigned char>(value[begin])) != 0) {
		++begin;
	}
	size_t end = value.size();
	while (end > begin && std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
		--end;
	}
	return value.substr(begin, end - begin);
}

std::string lower_ascii(std::string value) {
	for (char &ch : value) {
		ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
	}
	return value;
}

std::vector<std::string> split(const std::string &value, char delimiter) {
	std::vector<std::string> parts;
	std::string current;
	std::istringstream stream(value);
	while (std::getline(stream, current, delimiter)) {
		parts.push_back(trim(current));
	}
	if (!value.empty() && value.back() == delimiter) {
		parts.emplace_back();
	}
	return parts;
}

bool parse_i32(const std::string &raw, int32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	out_value = static_cast<int32_t>(parsed);
	return true;
}

bool parse_u32(const std::string &raw, uint32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const unsigned long parsed = std::strtoul(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed > std::numeric_limits<uint32_t>::max()) {
		return false;
	}
	out_value = static_cast<uint32_t>(parsed);
	return true;
}

std::string normalize_size_class(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "s" || value == "small" || value == "homm3_small") {
		return "small";
	}
	if (value == "m" || value == "medium" || value == "homm3_medium") {
		return "medium";
	}
	return value;
}

std::string normalize_water_mode(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "none" || value == "no_water" || value == "nowater" || value == "land") {
		return "land";
	}
	if (value == "normal" || value == "normal_water" || value == "mixed") {
		return "normal_water";
	}
	if (value == "water" || value == "islands") {
		return "islands";
	}
	return value;
}

std::string json_escape(const std::string &value) {
	std::string out;
	out.reserve(value.size() + 8);
	for (const unsigned char ch : value) {
		switch (ch) {
			case '\\':
				out += "\\\\";
				break;
			case '"':
				out += "\\\"";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			default:
				if (ch < 0x20) {
					static constexpr char HEX[] = "0123456789abcdef";
					out += "\\u00";
					out.push_back(HEX[(ch >> 4) & 0x0f]);
					out.push_back(HEX[ch & 0x0f]);
				} else {
					out.push_back(static_cast<char>(ch));
				}
				break;
		}
	}
	return out;
}

int32_t i8_from_u32_byte(uint32_t value, uint32_t shift) {
	return int32_t(int8_t((value >> shift) & 0xffU));
}

int32_t map_width_for_size(const std::string &size_class) {
	if (size_class == "medium") {
		return 72;
	}
	if (size_class == "small") {
		return 36;
	}
	return 0;
}

bool supported_one_level_land_scope(const ControlledCase &controlled_case) {
	return controlled_case.parse_ok
			&& (controlled_case.size_class == "small" || controlled_case.size_class == "medium")
			&& controlled_case.water_mode == "land"
			&& controlled_case.level_count == 1;
}

size_t skip_ws(const char *text, size_t pos, size_t end) {
	while (pos < end && std::isspace(static_cast<unsigned char>(text[pos])) != 0) {
		++pos;
	}
	return pos;
}

JsonSpan match_json_span(const char *text, size_t begin, size_t end) {
	if (begin >= end || (text[begin] != '{' && text[begin] != '[')) {
		return {};
	}
	const char open = text[begin];
	const char close = open == '{' ? '}' : ']';
	int32_t depth = 0;
	bool in_string = false;
	bool escape = false;
	for (size_t pos = begin; pos < end; ++pos) {
		const char ch = text[pos];
		if (in_string) {
			if (escape) {
				escape = false;
			} else if (ch == '\\') {
				escape = true;
			} else if (ch == '"') {
				in_string = false;
			}
			continue;
		}
		if (ch == '"') {
			in_string = true;
			continue;
		}
		if (ch == open) {
			++depth;
		} else if (ch == close) {
			--depth;
			if (depth == 0) {
				return JsonSpan { begin, pos + 1, true };
			}
		}
	}
	return {};
}

bool parse_json_string_at(const char *text, size_t begin, size_t end, std::string &out_value, size_t *out_after = nullptr) {
	if (begin >= end || text[begin] != '"') {
		return false;
	}
	std::string value;
	bool escape = false;
	for (size_t pos = begin + 1; pos < end; ++pos) {
		const char ch = text[pos];
		if (escape) {
			switch (ch) {
				case '"':
				case '\\':
				case '/':
					value.push_back(ch);
					break;
				case 'b':
					value.push_back('\b');
					break;
				case 'f':
					value.push_back('\f');
					break;
				case 'n':
					value.push_back('\n');
					break;
				case 'r':
					value.push_back('\r');
					break;
				case 't':
					value.push_back('\t');
					break;
				default:
					value.push_back(ch);
					break;
			}
			escape = false;
			continue;
		}
		if (ch == '\\') {
			escape = true;
			continue;
		}
		if (ch == '"') {
			out_value = value;
			if (out_after != nullptr) {
				*out_after = pos + 1;
			}
			return true;
		}
		value.push_back(ch);
	}
	return false;
}

JsonSpan object_key_value_span(const char *text, JsonSpan object, const char *key) {
	if (!object.ok || object.begin >= object.end || text[object.begin] != '{') {
		return {};
	}
	const size_t key_len = std::strlen(key);
	bool in_string = false;
	bool escape = false;
	int32_t depth = 0;
	for (size_t pos = object.begin; pos < object.end; ++pos) {
		const char ch = text[pos];
		if (in_string) {
			if (escape) {
				escape = false;
			} else if (ch == '\\') {
				escape = true;
			} else if (ch == '"') {
				in_string = false;
			}
			continue;
		}
		if (ch == '"') {
			if (depth == 1) {
				std::string parsed_key;
				size_t after_key = pos;
				if (parse_json_string_at(text, pos, object.end, parsed_key, &after_key) && parsed_key.size() == key_len && parsed_key == key) {
					size_t colon = skip_ws(text, after_key, object.end);
					if (colon >= object.end || text[colon] != ':') {
						return {};
					}
					size_t value_begin = skip_ws(text, colon + 1, object.end);
					if (value_begin >= object.end) {
						return {};
					}
					if (text[value_begin] == '{' || text[value_begin] == '[') {
						return match_json_span(text, value_begin, object.end);
					}
					if (text[value_begin] == '"') {
						std::string ignored;
						size_t after_value = value_begin;
						if (!parse_json_string_at(text, value_begin, object.end, ignored, &after_value)) {
							return {};
						}
						return JsonSpan { value_begin, after_value, true };
					}
					size_t value_end = value_begin;
					while (value_end < object.end && text[value_end] != ',' && text[value_end] != '}') {
						++value_end;
					}
					return JsonSpan { value_begin, value_end, true };
				}
			}
			in_string = true;
			continue;
		}
		if (ch == '{' || ch == '[') {
			++depth;
		} else if (ch == '}' || ch == ']') {
			--depth;
		}
	}
	return {};
}

bool parse_json_int(const char *text, JsonSpan span, int32_t &out_value) {
	if (!span.ok) {
		return false;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	size_t end = span.end;
	while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
		--end;
	}
	if (begin >= end) {
		return false;
	}
	std::string raw(text + begin, text + end);
	return parse_i32(raw, out_value);
}

int32_t json_int_or(const char *text, JsonSpan object, const char *key, int32_t fallback) {
	int32_t value = fallback;
	JsonSpan span = object_key_value_span(text, object, key);
	if (parse_json_int(text, span, value)) {
		return value;
	}
	return fallback;
}

std::string json_string_or(const char *text, JsonSpan object, const char *key, const std::string &fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok) {
		return fallback;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	std::string value;
	if (parse_json_string_at(text, begin, span.end, value)) {
		return value;
	}
	return fallback;
}

bool json_bool_or(const char *text, JsonSpan object, const char *key, bool fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok) {
		return fallback;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	size_t end = span.end;
	while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
		--end;
	}
	if (end > begin) {
		const std::string raw(text + begin, text + end);
		if (raw == "true") {
			return true;
		}
		if (raw == "false") {
			return false;
		}
	}
	int32_t value = 0;
	if (parse_json_int(text, span, value)) {
		return value != 0;
	}
	return fallback;
}

std::pair<int32_t, int32_t> json_i32_pair_or(const char *text, JsonSpan object, const char *key, std::pair<int32_t, int32_t> fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok || span.begin >= span.end || text[skip_ws(text, span.begin, span.end)] != '[') {
		return fallback;
	}
	std::vector<int32_t> values;
	size_t pos = skip_ws(text, span.begin, span.end) + 1;
	while (pos < span.end) {
		pos = skip_ws(text, pos, span.end);
		if (pos >= span.end || text[pos] == ']') {
			break;
		}
		size_t value_end = pos;
		while (value_end < span.end && text[value_end] != ',' && text[value_end] != ']') {
			++value_end;
		}
		int32_t parsed = 0;
		if (parse_json_int(text, JsonSpan { pos, value_end, true }, parsed)) {
			values.push_back(parsed);
		}
		pos = value_end < span.end && text[value_end] == ',' ? value_end + 1 : value_end;
	}
	if (values.size() >= 2) {
		return std::make_pair(values[0], values[1]);
	}
	return fallback;
}

std::vector<JsonSpan> json_array_object_spans(const char *text, JsonSpan array_span) {
	std::vector<JsonSpan> spans;
	if (!array_span.ok) {
		return spans;
	}
	size_t pos = skip_ws(text, array_span.begin, array_span.end);
	if (pos >= array_span.end || text[pos] != '[') {
		return spans;
	}
	++pos;
	while (pos < array_span.end) {
		pos = skip_ws(text, pos, array_span.end);
		if (pos >= array_span.end || text[pos] == ']') {
			break;
		}
		if (text[pos] == '{') {
			JsonSpan object = match_json_span(text, pos, array_span.end);
			if (!object.ok) {
				break;
			}
			spans.push_back(object);
			pos = object.end;
			continue;
		}
		++pos;
	}
	return spans;
}

std::vector<std::string> json_array_string_values(const char *text, JsonSpan array_span) {
	std::vector<std::string> values;
	if (!array_span.ok) {
		return values;
	}
	size_t pos = skip_ws(text, array_span.begin, array_span.end);
	if (pos >= array_span.end || text[pos] != '[') {
		return values;
	}
	++pos;
	while (pos < array_span.end) {
		pos = skip_ws(text, pos, array_span.end);
		if (pos >= array_span.end || text[pos] == ']') {
			break;
		}
		if (text[pos] == '"') {
			std::string value;
			size_t after_value = pos;
			if (!parse_json_string_at(text, pos, array_span.end, value, &after_value)) {
				break;
			}
			values.push_back(value);
			pos = after_value;
			continue;
		}
		++pos;
	}
	return values;
}

int32_t bit_count_u8(uint8_t mask) {
	int32_t count = 0;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & uint8_t(1U << uint32_t(index))) != 0) {
			++count;
		}
	}
	return count;
}

bool player_filter_allows_plain(const char *text, JsonSpan maybe_filter, int32_t humans, int32_t players) {
	if (!maybe_filter.ok) {
		return true;
	}
	return humans >= json_int_or(text, maybe_filter, "min_human", 0)
			&& humans <= json_int_or(text, maybe_filter, "max_human", 8)
			&& players >= json_int_or(text, maybe_filter, "min_total", 0)
			&& players <= json_int_or(text, maybe_filter, "max_total", 8);
}

int32_t size_score_for_case(const ControlledCase &controlled_case) {
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t levels = std::max<int32_t>(1, controlled_case.level_count);
	if (map_width <= 0) {
		return 0;
	}
	return int32_t((int64_t(map_width) * int64_t(map_width) * int64_t(levels)) / 0x510);
}

GeneratorModeResolutionPlain resolve_generator_mode_0x49ecf2_plain(const ControlledCase &controlled_case) {
	GeneratorModeResolutionPlain resolution;
	resolution.setup_object_0x44_known = controlled_case.setup_object_0x44_known;
	resolution.setup_object_0x44 = controlled_case.setup_object_0x44;
	resolution.rng_state_after_0x49ecf2 = controlled_case.seed;
	if (!controlled_case.setup_object_0x44_known) {
		return resolution;
	}
	resolution.generator_mode_known = true;
	if (controlled_case.setup_object_0x44 == 3) {
		H3MapedRng rng { controlled_case.seed };
		resolution.randomized_from_setup_value_3 = true;
		resolution.randomization_rng_value = rng.next();
		resolution.generator_mode_0x10b8 = resolution.randomization_rng_value % 3;
		resolution.rng_state_after_0x49ecf2 = rng.state;
		resolution.pre_template_rng_call_count = 1;
		return resolution;
	}
	resolution.generator_mode_0x10b8 = controlled_case.setup_object_0x44;
	return resolution;
}

std::string generator_mode_status_label(const GeneratorModeResolutionPlain &resolution) {
	if (!resolution.setup_object_0x44_known) {
		return "unknown_missing_same_run_rmg_setup_object_0x44_capture";
	}
	if (resolution.randomized_from_setup_value_3) {
		return "resolved_by_0x49ecf2_rng_percent_3_from_setup_value_3";
	}
	return "resolved_directly_from_rmg_setup_object_0x44";
}

std::vector<int32_t> owner_indices_from_mask(uint8_t mask) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & uint8_t(1U << uint32_t(index))) != 0) {
			indices.push_back(index);
		}
	}
	return indices;
}

int32_t h3maped_town_original_index_from_id_plain(const std::string &town_id) {
	static constexpr const char *ALLOWED_TOWNS[] = {
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
	for (int32_t index = 0; index < 9; ++index) {
		if (town_id == ALLOWED_TOWNS[size_t(index)]) {
			return index;
		}
	}
	return -1;
}

std::vector<int32_t> h3maped_allowed_town_slots_plain(const std::vector<std::string> &allowed_towns) {
	std::array<bool, 9> flags = {};
	for (const std::string &town_id : allowed_towns) {
		const int32_t town_index = h3maped_town_original_index_from_id_plain(town_id);
		if (town_index >= 0 && town_index < int32_t(flags.size())) {
			flags[size_t(town_index)] = true;
		}
	}
	std::vector<int32_t> slots;
	for (int32_t index = 0; index < int32_t(flags.size()); ++index) {
		if (flags[size_t(index)]) {
			slots.push_back(index);
		}
	}
	return slots;
}

JsonSpan template_catalog_root_span(const char *text, size_t size) {
	size_t pos = skip_ws(text, 0, size);
	if (pos >= size || text[pos] != '{') {
		return {};
	}
	return match_json_span(text, pos, size);
}

TemplateRecord template_record_from_span(const char *text, JsonSpan object, int32_t catalog_index, int32_t humans, int32_t players) {
	TemplateRecord record;
	record.catalog_index = catalog_index;
	record.id = std::string("h3maped_template_") + (catalog_index < 10 ? "00" : catalog_index < 100 ? "0" : "") + std::to_string(catalog_index);
	record.name = json_string_or(text, object, "name", "");
	record.min_size_score = json_int_or(text, object, "min_size", 0);
	record.max_size_score = json_int_or(text, object, "max_size", 0);
	const auto human_range = json_i32_pair_or(text, object, "supported_human_range", std::make_pair(0, 0));
	const auto total_range = json_i32_pair_or(text, object, "supported_total_player_range", std::make_pair(0, 0));
	record.min_humans = human_range.first;
	record.max_humans = human_range.second;
	record.min_total_players = total_range.first;
	record.max_total_players = total_range.second;
	record.object_span = object;
	record.zones_span = object_key_value_span(text, object, "zones");
	record.connections_span = object_key_value_span(text, object, "connections");
	const std::vector<JsonSpan> zone_spans = json_array_object_spans(text, record.zones_span);
	const std::vector<JsonSpan> connection_spans = json_array_object_spans(text, record.connections_span);
	record.unfiltered_zone_count = int32_t(zone_spans.size());
	record.unfiltered_connection_count = int32_t(connection_spans.size());
	for (JsonSpan zone : zone_spans) {
		if (!player_filter_allows_plain(text, object_key_value_span(text, zone, "player_filter"), humans, players)) {
			continue;
		}
		++record.filtered_zone_count;
		const int32_t owner = json_int_or(text, zone, "ownership", -1);
		if (owner < 0 || owner >= 8) {
			continue;
		}
		const std::string type = json_string_or(text, zone, "type", "");
		if (type == "human_start") {
			record.human_capable_source_owner_mask = uint8_t(record.human_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
			record.player_capable_source_owner_mask = uint8_t(record.player_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
		} else if (type == "computer_start") {
			record.player_capable_source_owner_mask = uint8_t(record.player_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
		}
	}
	for (JsonSpan connection : connection_spans) {
		if (player_filter_allows_plain(text, object_key_value_span(text, connection, "player_filter"), humans, players)) {
			++record.filtered_connection_count;
		}
	}
	return record;
}

std::vector<TemplateRecord> accepted_templates_for_case(const ControlledCase &controlled_case) {
	std::vector<TemplateRecord> accepted;
	if (!supported_one_level_land_scope(controlled_case)) {
		return accepted;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	const size_t size = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json_size();
	JsonSpan root = template_catalog_root_span(text, size);
	JsonSpan templates = object_key_value_span(text, root, "templates");
	const std::vector<JsonSpan> template_spans = json_array_object_spans(text, templates);
	const int32_t score = size_score_for_case(controlled_case);
	const int32_t humans = controlled_case.human_count;
	const int32_t players = controlled_case.players;
	for (int32_t index = 0; index < int32_t(template_spans.size()); ++index) {
		TemplateRecord record = template_record_from_span(text, template_spans[size_t(index)], index, humans, players);
		if (score < record.min_size_score || score > record.max_size_score) {
			continue;
		}
		if (humans < record.min_humans || humans > record.max_humans || players < record.min_total_players || players > record.max_total_players || players < humans) {
			continue;
		}
		if (controlled_case.size_class != "medium"
				&& (bit_count_u8(record.human_capable_source_owner_mask) < humans || bit_count_u8(record.player_capable_source_owner_mask) < players)) {
			continue;
		}
		accepted.push_back(record);
	}
	return accepted;
}

RuntimeZoneSummary build_runtime_zone_summary(const ControlledCase &controlled_case) {
	RuntimeZoneSummary summary;
	if (!controlled_case.parse_ok) {
		summary.blocked_reason = controlled_case.parse_error;
		return summary;
	}
	summary.generator_mode = resolve_generator_mode_0x49ecf2_plain(controlled_case);
	std::vector<TemplateRecord> accepted = accepted_templates_for_case(controlled_case);
	summary.accepted_template_count = int32_t(accepted.size());
	if (accepted.empty()) {
		summary.blocked_reason = "no_accepted_h3maped_templates_for_case";
		return summary;
	}
	H3MapedRng rng { summary.generator_mode.rng_state_after_0x49ecf2 };
	summary.template_selection_rng_value = rng.next();
	summary.rng_state_after_selection = rng.state;
	summary.selected_vector_index = summary.template_selection_rng_value % int32_t(accepted.size());
	summary.selected = accepted[size_t(summary.selected_vector_index)];
	summary.selected_zone_spans = json_array_object_spans(godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json(), summary.selected.zones_span);
	summary.mapped_slots.assign(8, -1);
	const std::vector<int32_t> human_indices = owner_indices_from_mask(summary.selected.human_capable_source_owner_mask);
	const std::vector<int32_t> player_indices = owner_indices_from_mask(summary.selected.player_capable_source_owner_mask);
	int32_t assigned_players = 0;
	for (int32_t index = 0; index < controlled_case.human_count && index < int32_t(human_indices.size()); ++index) {
		const int32_t source_owner = human_indices[size_t(index)];
		summary.mapped_slots[size_t(source_owner)] = assigned_players;
		summary.assignment_source_owners.push_back(source_owner);
		++assigned_players;
	}
	for (int32_t index = 0; assigned_players < controlled_case.players && index < int32_t(player_indices.size()); ++index) {
		const int32_t source_owner = player_indices[size_t(index)];
		if (summary.mapped_slots[size_t(source_owner)] != -1) {
			continue;
		}
		summary.mapped_slots[size_t(source_owner)] = assigned_players;
		summary.assignment_source_owners.push_back(source_owner);
		++assigned_players;
	}
	summary.ok = true;
	return summary;
}

int32_t json_nested_int_or(const char *text, JsonSpan object, const char *nested_key, const char *key, int32_t fallback) {
	JsonSpan nested = object_key_value_span(text, object, nested_key);
	if (!nested.ok) {
		return fallback;
	}
	return json_int_or(text, nested, key, fallback);
}

int32_t h3maped_distance_truncate_plain(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

int32_t ftol_truncate_plain(double value) {
	return int32_t(std::trunc(value));
}

constexpr double H3MAPED_DIRECTION_X_TABLE[32] = {
	1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
	0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
	0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
	-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
	-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
	-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
	0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
	0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
};

constexpr double H3MAPED_DIRECTION_Y_TABLE[32] = {
	0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
	0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
	1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
	0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
	0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
	-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
	-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
	-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
};

std::vector<RuntimeZoneRecordPlain> runtime_zone_records_plain(const RuntimeZoneSummary &summary) {
	std::vector<RuntimeZoneRecordPlain> records;
	if (!summary.ok) {
		return records;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		JsonSpan zone = summary.selected_zone_spans[index];
		RuntimeZoneRecordPlain record;
		record.runtime_index = int32_t(index);
		record.source_zone_id = json_int_or(text, zone, "id", int32_t(index + 1));
		record.role = json_string_or(text, zone, "type", "");
		record.source_bucket = json_int_or(text, zone, "bucket", -1);
		record.source_owner_index = json_int_or(text, zone, "ownership", -2);
		record.actual_owner_color = record.source_owner_index >= 0 && record.source_owner_index < int32_t(summary.mapped_slots.size())
				? summary.mapped_slots[size_t(record.source_owner_index)]
				: -1;
		record.is_player_capable_zone = record.source_bucket == 0 || record.source_bucket == 1;
		record.has_assigned_start = record.is_player_capable_zone && record.actual_owner_color >= 0;
		record.source_base_size = json_int_or(text, zone, "base_size", 0);
		std::vector<std::string> allowed_towns = json_array_string_values(text, object_key_value_span(text, zone, "allowed_towns"));
		if (allowed_towns.empty()) {
			JsonSpan town_policy = object_key_value_span(text, zone, "town_policy");
			allowed_towns = json_array_string_values(text, object_key_value_span(text, town_policy, "allowed_faction_ids"));
		}
		record.allowed_town_slots = h3maped_allowed_town_slots_plain(allowed_towns);
		records.push_back(record);
	}
	return records;
}

std::vector<RuntimeLinkSeedPlain> link_seeds_plain(const ControlledCase &controlled_case, const RuntimeZoneSummary &summary) {
	std::vector<RuntimeLinkSeedPlain> seeds;
	if (!summary.ok) {
		return seeds;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	const std::vector<JsonSpan> links = json_array_object_spans(text, summary.selected.connections_span);
	std::map<int32_t, int32_t> runtime_index_by_source_zone_id;
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		JsonSpan zone = summary.selected_zone_spans[index];
		const int32_t source_zone_id = json_int_or(text, zone, "id", int32_t(index + 1));
		if (source_zone_id > 0) {
			runtime_index_by_source_zone_id[source_zone_id] = int32_t(index);
		}
	}
	for (JsonSpan link : links) {
		if (!player_filter_allows_plain(text, object_key_value_span(text, link, "player_filter"), controlled_case.human_count, controlled_case.players)) {
			continue;
		}
		JsonSpan endpoints = object_key_value_span(text, link, "source_endpoints");
		const int32_t source_zone_a = json_int_or(text, link, "zone1", json_int_or(text, endpoints, "zone1", 0));
		const int32_t source_zone_b = json_int_or(text, link, "zone2", json_int_or(text, endpoints, "zone2", 0));
		if (source_zone_a <= 0 || source_zone_b <= 0) {
			continue;
		}
		JsonSpan guard = object_key_value_span(text, link, "guard");
		JsonSpan grammar_source = object_key_value_span(text, link, "grammar_source");
		RuntimeLinkSeedPlain seed;
		seed.link_index = int32_t(seeds.size());
		seed.source_row = json_int_or(text, link, "row", json_int_or(text, grammar_source, "source_row", -1));
		seed.source_zone_a = source_zone_a;
		seed.source_zone_b = source_zone_b;
		const auto found_a = runtime_index_by_source_zone_id.find(source_zone_a);
		const auto found_b = runtime_index_by_source_zone_id.find(source_zone_b);
		seed.runtime_a = found_a != runtime_index_by_source_zone_id.end() ? found_a->second : source_zone_a - 1;
		seed.runtime_b = found_b != runtime_index_by_source_zone_id.end() ? found_b->second : source_zone_b - 1;
		seed.guard_value = json_int_or(text, link, "value", json_int_or(text, link, "guard_value", json_int_or(text, guard, "value", 0)));
		seed.wide = json_bool_or(text, link, "wide", false);
		seed.border_guard = json_bool_or(text, link, "border_guard", false);
		seeds.push_back(seed);
	}
	return seeds;
}

bool candidate_valid_4a1701_plain(const RuntimeZoneRecordPlain &current, const CoordCandidate &candidate, const std::vector<CoordCandidate> &zone_positions, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<int32_t> &visible_runtime_indices) {
	if ((current.source_bucket == 0 || current.source_bucket == 1)
			&& candidate.level == 1
			&& current.actual_owner_color != 3
			&& current.actual_owner_color != 4
			&& current.actual_owner_color != 5) {
		return false;
	}
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size())) {
			continue;
		}
		const RuntimeZoneRecordPlain &other = zones[size_t(other_index)];
		const CoordCandidate other_position = zone_positions[size_t(other_index)];
		if (other.runtime_index == current.runtime_index || other_position.level != candidate.level) {
			continue;
		}
		const int32_t distance = h3maped_distance_truncate_plain(candidate.x, candidate.y, other_position.x, other_position.y);
		const int32_t minimum_tenths = (other.source_base_size + current.source_base_size) * 8;
		if (distance * 10 < minimum_tenths) {
			return false;
		}
	}
	return true;
}

bool zones_connectable_49b6e2_plain(const RuntimeZoneRecordPlain &first, const CoordCandidate &first_position, const RuntimeZoneRecordPlain &second, const CoordCandidate &second_position) {
	const int32_t distance = h3maped_distance_truncate_plain(first_position.x, first_position.y, second_position.x, second_position.y);
	const int32_t size_sum = first.source_base_size + second.source_base_size;
	if (first_position.level != second_position.level) {
		if (size_sum < distance) {
			return false;
		}
		return (size_sum - distance) > (std::min(first.source_base_size, second.source_base_size) / 2);
	}
	return size_sum * 11 >= distance * 10;
}

int32_t link_acceptance_count_4a1967_plain(const RuntimeZoneRecordPlain &current, const CoordCandidate &current_position, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, const std::vector<RuntimeLinkSeedPlain> &links) {
	int32_t accepted = 0;
	for (const RuntimeLinkSeedPlain &link : links) {
		int32_t other_index = -1;
		if (link.runtime_a == current.runtime_index) {
			other_index = link.runtime_b;
		} else if (link.runtime_b == current.runtime_index) {
			other_index = link.runtime_a;
		}
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size())) {
			continue;
		}
		if (std::find(visible_runtime_indices.begin(), visible_runtime_indices.end(), other_index) == visible_runtime_indices.end()) {
			continue;
		}
		if (zones_connectable_49b6e2_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], current, current_position)) {
			accepted += 1;
		}
	}
	return accepted;
}

void append_angle_candidates_4a17f5_plain(const RuntimeZoneRecordPlain &base, const CoordCandidate &base_position, const RuntimeZoneRecordPlain &current, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, std::vector<CoordCandidate> &candidates) {
	const int32_t combined_size = base.source_base_size + current.source_base_size;
	for (int32_t direction = 0; direction < 32; ++direction) {
		CoordCandidate candidate;
		candidate.x = ftol_truncate_plain(double(combined_size) * H3MAPED_DIRECTION_X_TABLE[direction] + double(base_position.x));
		candidate.y = ftol_truncate_plain(double(combined_size) * H3MAPED_DIRECTION_Y_TABLE[direction] + double(base_position.y));
		candidate.level = base_position.level;
		if (candidate_valid_4a1701_plain(current, candidate, zone_positions, zones, visible_runtime_indices)) {
			candidates.push_back(candidate);
		}
	}
}

void prune_candidates_4a1ad8_plain(const RuntimeZoneRecordPlain &current, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, const std::vector<RuntimeLinkSeedPlain> &links, int32_t coordinate_prune_span_budget, std::vector<CoordCandidate> &candidates) {
	if (candidates.empty()) {
		return;
	}
	int32_t best_link_count = 0;
	for (const CoordCandidate &candidate : candidates) {
		best_link_count = std::max(best_link_count, link_acceptance_count_4a1967_plain(current, candidate, zones, zone_positions, visible_runtime_indices, links));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		return link_acceptance_count_4a1967_plain(current, candidate, zones, zone_positions, visible_runtime_indices, links) < best_link_count;
	}), candidates.end());
	if (candidates.empty()) {
		return;
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size()) || other_index == current.runtime_index) {
			continue;
		}
		const RuntimeZoneRecordPlain &other = zones[size_t(other_index)];
		const CoordCandidate other_position = zone_positions[size_t(other_index)];
		min_y = std::min(other_position.y - other.source_base_size, min_y);
		min_x = std::min(other_position.x - other.source_base_size, min_x);
		max_y = std::max(other_position.y + other.source_base_size + 1, max_y);
		max_x = std::max(other_position.x + other.source_base_size + 1, max_x);
	}

	auto candidate_span_metric = [&](const CoordCandidate &candidate) {
		const int32_t candidate_min_y = std::min(candidate.y - current.source_base_size, min_y);
		const int32_t candidate_min_x = std::min(candidate.x - current.source_base_size, min_x);
		const int32_t candidate_max_y = std::max(candidate.y + current.source_base_size + 1, max_y);
		const int32_t candidate_max_x = std::max(candidate.x + current.source_base_size + 1, max_x);
		const int32_t height = candidate_max_y - candidate_min_y;
		const int32_t width = candidate_max_x - candidate_min_x;
		return std::max(coordinate_prune_span_budget, std::max(height, width));
	};

	int32_t best_metric = 0x7d00;
	for (const CoordCandidate &candidate : candidates) {
		best_metric = std::min(best_metric, candidate_span_metric(candidate));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		return best_metric < candidate_span_metric(candidate);
	}), candidates.end());
}

std::vector<CoordCandidate> coord_preview(const std::vector<CoordCandidate> &candidates, int32_t limit = 8) {
	const size_t count = std::min<size_t>(candidates.size(), size_t(std::max(0, limit)));
	return std::vector<CoordCandidate>(candidates.begin(), candidates.begin() + count);
}

CoordinateReplaySummary build_coordinate_replay_summary(const ControlledCase &controlled_case, const RuntimeZoneSummary &runtime_zone_summary) {
	CoordinateReplaySummary summary;
	if (!runtime_zone_summary.ok) {
		summary.blocked_reason = "blocked_until_runtime_zone_summary";
		return summary;
	}
	if (!supported_one_level_land_scope(controlled_case)) {
		summary.blocked_reason = "blocked_unsupported_non_small_medium_one_level_land_scope";
		return summary;
	}
	std::vector<RuntimeZoneRecordPlain> zones = runtime_zone_records_plain(runtime_zone_summary);
	std::vector<CoordCandidate> zone_positions(zones.size(), CoordCandidate {});
	summary.link_seeds = link_seeds_plain(controlled_case, runtime_zone_summary);
	summary.runtime_records_after_0x49b3c1 = zones;
	int32_t minimum_source_base_size = std::numeric_limits<int32_t>::max();
	for (const RuntimeZoneRecordPlain &zone : zones) {
		if (zone.source_base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, zone.source_base_size);
		}
	}
	if (minimum_source_base_size == std::numeric_limits<int32_t>::max()) {
		minimum_source_base_size = 0;
	}
	summary.minimum_source_base_size = minimum_source_base_size;
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t map_height = map_width;
	summary.coordinate_prune_divisor_4a218c = 5;
	summary.coordinate_prune_span_budget_4a218c = std::min(minimum_source_base_size * map_width, minimum_source_base_size * map_height) / summary.coordinate_prune_divisor_4a218c;
	H3MapedRng rng { runtime_zone_summary.rng_state_after_selection };

	auto append_rng_event = [&](const RngEventPlain &event) {
		summary.rng_events.push_back(event);
	};

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= int32_t(zones.size())) {
			return;
		}
		RuntimeZoneRecordPlain &runtime = zones[size_t(zone_index)];
		if (runtime.allowed_town_slots.empty()) {
			return;
		}
		const int32_t rng_value = rng.next();
		const int32_t selected_allowed_ordinal = rng_value % int32_t(runtime.allowed_town_slots.size());
		const int32_t town_choice_index = runtime.allowed_town_slots[size_t(selected_allowed_ordinal)];
		runtime.town_choice_rng_value = rng_value;
		runtime.town_choice_selected_allowed_ordinal = selected_allowed_ordinal;
		runtime.town_choice_index = town_choice_index;
		summary.runtime_records_after_0x49b3c1[size_t(zone_index)] = runtime;
		++summary.town_choice_rng_calls;
		RngEventPlain event;
		event.consumer = "0x49b3c1";
		event.runtime_zone_index = zone_index;
		event.value = rng_value;
		event.modulus = int32_t(runtime.allowed_town_slots.size());
		event.selected_index = town_choice_index;
		event.allowed_original_town_indices = runtime.allowed_town_slots;
		append_rng_event(event);
	};

	bool complete = true;
	auto place_zone = [&](int32_t zone_index, const std::string &pass_id, const std::vector<int32_t> &visible_runtime_indices) {
		std::vector<CoordCandidate> candidates;
		PlacementStepPlain step;
		step.pass_id = pass_id;
		step.runtime_zone_index = zone_index;
		step.visible_runtime_zone_indices = visible_runtime_indices;
		if (zone_index < 0 || zone_index >= int32_t(zones.size())) {
			step.blocked = true;
			step.blocked_reason = "runtime_zone_index_out_of_range";
			complete = false;
			summary.placement_steps.push_back(step);
			return;
		}

		if (visible_runtime_indices.empty()) {
			candidates.push_back(CoordCandidate { 0, 0, 0 });
			step.candidate_source = "0x4a1f7b_empty_runtime_vector_origin";
		} else {
			int32_t explicit_base_count = 0;
			for (const RuntimeLinkSeedPlain &link : summary.link_seeds) {
				int32_t other_index = -1;
				if (link.runtime_a == zone_index) {
					other_index = link.runtime_b;
				} else if (link.runtime_b == zone_index) {
					other_index = link.runtime_a;
				}
				if (other_index < 0 || other_index >= int32_t(zones.size()) || std::find(visible_runtime_indices.begin(), visible_runtime_indices.end(), other_index) == visible_runtime_indices.end()) {
					continue;
				}
				++explicit_base_count;
				append_angle_candidates_4a17f5_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, candidates);
			}
			step.explicit_link_base_count = explicit_base_count;
			if (candidates.empty()) {
				for (const int32_t other_index : visible_runtime_indices) {
					if (other_index >= 0 && other_index < int32_t(zones.size())) {
						append_angle_candidates_4a17f5_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, candidates);
					}
				}
				step.candidate_source = "0x4a2069_existing_runtime_zone_fallback";
				step.fallback_base_count = int32_t(visible_runtime_indices.size());
			} else {
				step.candidate_source = "0x4a200c_explicit_source_link_endpoint";
			}
		}

		step.candidate_count_before_4a1ad8 = int32_t(candidates.size());
		step.candidate_preview_before_4a1ad8 = coord_preview(candidates);
		prune_candidates_4a1ad8_plain(zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, summary.link_seeds, summary.coordinate_prune_span_budget_4a218c, candidates);
		step.candidate_count_after_4a1ad8 = int32_t(candidates.size());
		step.candidate_preview_after_4a1ad8 = coord_preview(candidates);
		if (candidates.empty()) {
			step.blocked = true;
			step.blocked_reason = "0x4a1f3b produced no coordinate candidates";
			complete = false;
			summary.placement_steps.push_back(step);
			return;
		}
		const int32_t rng_value = rng.next();
		++summary.coordinate_rng_calls;
		const int32_t selected_index = rng_value % int32_t(candidates.size());
		const CoordCandidate selected = candidates[size_t(selected_index)];
		zone_positions[size_t(zone_index)] = selected;
		step.rng_value = rng_value;
		step.selected_candidate_index = selected_index;
		step.selected_candidate = selected;
		RngEventPlain event;
		event.consumer = "0x4a1f3b_candidate_selection";
		event.runtime_zone_index = zone_index;
		event.pass_id = pass_id;
		event.value = rng_value;
		event.modulus = int32_t(candidates.size());
		event.selected_index = selected_index;
		append_rng_event(event);
		summary.placement_steps.push_back(step);
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
			place_zone(zone_index, pass == 0 ? "0x4a22b3_refinement_pass_1" : "0x4a22b3_refinement_pass_2", all_visible);
		}
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (size_t index = 0; index < zones.size(); ++index) {
		const RuntimeZoneRecordPlain &zone = zones[index];
		const CoordCandidate position = zone_positions[index];
		min_y = std::min(position.y - zone.source_base_size, min_y);
		min_x = std::min(position.x - zone.source_base_size, min_x);
		max_y = std::max(position.y + zone.source_base_size + 1, max_y);
		max_x = std::max(position.x + zone.source_base_size + 1, max_x);
	}
	summary.bbox_min_y = min_y;
	summary.bbox_min_x = min_x;
	summary.bbox_max_y = max_y;
	summary.bbox_max_x = max_x;
	summary.bbox_height = max_y - min_y;
	summary.bbox_width = max_x - min_x;
	summary.bbox_span = std::max(summary.bbox_height, summary.bbox_width);
	summary.map_span = std::min(map_width, map_height);
	summary.offset_y = (min_y - summary.bbox_span + max_y) / 2;
	summary.offset_x = (min_x - summary.bbox_span + max_x) / 2;
	for (size_t index = 0; index < zones.size(); ++index) {
		RuntimeZoneRecordPlain scaled = zones[index];
		CoordCandidate position = zone_positions[index];
		int32_t scaled_size = scaled.source_base_size;
		if (summary.bbox_span > 0) {
			position.x = ((position.x - summary.offset_x) * summary.map_span) / summary.bbox_span;
			position.y = ((position.y - summary.offset_y) * summary.map_span) / summary.bbox_span;
			scaled_size = (scaled.source_base_size * summary.map_span) / summary.bbox_span;
		}
		scaled.x_after_bbox_rescale = position.x;
		scaled.y_after_bbox_rescale = position.y;
		scaled.level_after_bbox_rescale = position.level;
		scaled.runtime_size_after_bbox_rescale = scaled_size;
		summary.scaled_zone_coordinates.push_back(scaled);
	}
	summary.rng_state_after_0x4a218c = rng.state;
	summary.ok = complete;
	if (!summary.ok) {
		summary.blocked_reason = "coordinate_candidate_replay_incomplete";
	}
	return summary;
}

PolygonSourceResultPlain build_polygon_source_walks_4ccb64_plain(const std::vector<RuntimeZoneRecordPlain> &runtime_zones) {
	PolygonSourceResultPlain result;
	PolygonModelPlain model;
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

	for (int32_t runtime_index = 0; runtime_index < int32_t(runtime_zones.size()); ++runtime_index) {
		const RuntimeZoneRecordPlain &runtime = runtime_zones[size_t(runtime_index)];
		if (runtime.level_after_bbox_rescale != 0) {
			continue;
		}
		const int32_t zone_index = runtime.runtime_index >= 0 ? runtime.runtime_index : runtime_index;
		const int32_t x = runtime.x_after_bbox_rescale;
		const int32_t y = runtime.y_after_bbox_rescale;
		SourceSplitStepPlain step;
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
		const PolygonModelNodePlain &located_node = model.nodes[size_t(located)];
		const int32_t split_primary = model.add_pair("split_" + std::to_string(zone_index), located_node.x, located_node.y, located_node.payload, x, y, zone_index, located_node.has_payload, true);
		model.relink_4cc643(split_primary, located);
		model.root = split_primary;
		result.inserted_node_pair_count += 1;
		result.executed_split_count += 1;
		int32_t bridge_pair_count = 0;
		int32_t current_bridge = split_primary;
		int32_t bridge_source = located;
		for (int32_t guard = 0; guard < 64; ++guard) {
			current_bridge = model.bridge_4ccb1f(bridge_source, model.nodes[size_t(current_bridge)].pair, "split_" + std::to_string(zone_index) + "_bridge_" + std::to_string(bridge_pair_count));
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
				const PolygonModelNodePlain &cursor = model.nodes[size_t(cleanup_cursor)];
				const PolygonModelNodePlain &previous_pair = model.nodes[size_t(model.nodes[size_t(cursor.previous)].pair)];
				const PolygonModelNodePlain &paired = model.nodes[size_t(cursor.pair)];
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
	for (const PolygonModelNodePlain &node : model.nodes) {
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

	for (int32_t runtime_index = 0; runtime_index < int32_t(runtime_zones.size()); ++runtime_index) {
		const RuntimeZoneRecordPlain &runtime = runtime_zones[size_t(runtime_index)];
		if (runtime.level_after_bbox_rescale != 0) {
			continue;
		}
		SourceWalkPlain walk;
		walk.runtime_zone_index = runtime.runtime_index >= 0 ? runtime.runtime_index : runtime_index;
		walk.source_zone_id = runtime.source_zone_id;
		walk.start_x = runtime.x_after_bbox_rescale;
		walk.start_y = runtime.y_after_bbox_rescale;
		const int32_t located = result.blocked ? -1 : model.locate_4cca55(walk.start_x, walk.start_y);
		if (located >= 0) {
			int32_t current = located;
			bool guard_exhausted = false;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const PolygonModelNodePlain &node = model.nodes[size_t(current)];
				const int32_t next = node.next;
				const int32_t next_pair = next >= 0 && next < int32_t(model.nodes.size()) ? model.nodes[size_t(next)].pair : -1;
				const PolygonModelNodePlain *next_pair_node = next_pair >= 0 && next_pair < int32_t(model.nodes.size()) ? &model.nodes[size_t(next_pair)] : nullptr;
				SourceCycleNodePlain source_node;
				source_node.x = node.x;
				source_node.y = node.y;
				source_node.has_payload = node.has_payload;
				source_node.payload = node.payload;
				source_node.next_pair_has_payload = next_pair_node != nullptr && next_pair_node->has_payload;
				source_node.next_pair_payload = next_pair_node != nullptr ? next_pair_node->payload : 0;
				source_node.finalized = node.finalized;
				source_node.finalized_x = node.finalized_x;
				source_node.finalized_y = node.finalized_y;
				walk.cycle_nodes.push_back(source_node);
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

CoordCandidate coord_from_runtime_zone_plain(const RuntimeZoneRecordPlain &zone) {
	return CoordCandidate { zone.x_after_bbox_rescale, zone.y_after_bbox_rescale, zone.level_after_bbox_rescale };
}

std::vector<CoordCandidate> coords_from_runtime_zones_plain(const std::vector<RuntimeZoneRecordPlain> &runtime_zones) {
	std::vector<CoordCandidate> coords;
	coords.reserve(runtime_zones.size());
	for (const RuntimeZoneRecordPlain &zone : runtime_zones) {
		coords.push_back(coord_from_runtime_zone_plain(zone));
	}
	return coords;
}

std::vector<int32_t> visible_indices_for_runtime_zones_plain(const std::vector<RuntimeZoneRecordPlain> &runtime_zones) {
	std::vector<int32_t> indices;
	indices.reserve(runtime_zones.size());
	for (int32_t index = 0; index < int32_t(runtime_zones.size()); ++index) {
		indices.push_back(index);
	}
	return indices;
}

std::vector<RuntimeZoneRecordPlain> runtime_zones_with_effective_size_0x1c_plain(const std::vector<RuntimeZoneRecordPlain> &runtime_zones) {
	std::vector<RuntimeZoneRecordPlain> effective = runtime_zones;
	for (RuntimeZoneRecordPlain &zone : effective) {
		if (zone.runtime_size_after_bbox_rescale > 0) {
			zone.source_base_size = zone.runtime_size_after_bbox_rescale;
		}
	}
	return effective;
}

RuntimeZoneRecordPlain synthetic_runtime_zone_record_49b452_plain(const RuntimeZoneRecordPlain &base, int32_t runtime_index, const CoordCandidate &candidate, int32_t radius) {
	RuntimeZoneRecordPlain synthetic;
	synthetic.runtime_index = runtime_index;
	synthetic.source_zone_id = runtime_index + 1;
	synthetic.role = "same_level_synthetic_runtime_zone_0x4a3b48";
	synthetic.source_bucket = 3;
	synthetic.source_owner_index = -1;
	synthetic.actual_owner_color = -1;
	synthetic.is_player_capable_zone = false;
	synthetic.has_assigned_start = false;
	synthetic.source_base_size = radius;
	synthetic.town_choice_rng_value = -1;
	synthetic.town_choice_index = -1;
	synthetic.town_choice_selected_allowed_ordinal = -1;
	synthetic.x_after_bbox_rescale = candidate.x;
	synthetic.y_after_bbox_rescale = candidate.y;
	synthetic.level_after_bbox_rescale = base.level_after_bbox_rescale;
	synthetic.runtime_size_after_bbox_rescale = radius;
	return synthetic;
}

SyntheticRuntimeZoneReplaySummaryPlain replay_same_level_synthetic_runtime_zone_append_4a3b48_plain(const ControlledCase &controlled_case, const CoordinateReplaySummary &coordinate_summary, const GeneratorModeResolutionPlain &generator_mode) {
	SyntheticRuntimeZoneReplaySummaryPlain replay;
	replay.generator_mode_known = generator_mode.generator_mode_known;
	replay.runtime_zones_after_append = coordinate_summary.scaled_zone_coordinates;
	replay.initial_runtime_zone_count = int32_t(coordinate_summary.scaled_zone_coordinates.size());
	replay.runtime_zone_count_after_append = replay.initial_runtime_zone_count;
	if (!coordinate_summary.ok) {
		replay.blocked_reason = "coordinate_replay_missing";
		return replay;
	}
	if (!supported_one_level_land_scope(controlled_case)) {
		replay.status = "unsupported_scope";
		replay.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return replay;
	}
	if (!generator_mode.generator_mode_known) {
		replay.status = "blocked_missing_same_run_rmg_setup_object_0x44";
		replay.blocked_reason = "generator_mode_0x10b8_unknown";
		return replay;
	}
	replay.ported_plain_cpp = true;
	replay.branch_allowed = generator_mode.generator_mode_0x10b8 != 0;
	if (!replay.branch_allowed) {
		replay.status = "inactive_generator_mode_0_skips_same_level_synthetic_runtime_zone_append";
		replay.blocked_reason.clear();
		return replay;
	}

	const int32_t width = map_width_for_size(controlled_case.size_class);
	const int32_t height = width;
	for (int32_t base_index = 0; base_index < replay.initial_runtime_zone_count; ++base_index) {
		if (base_index < 0 || base_index >= int32_t(replay.runtime_zones_after_append.size())) {
			continue;
		}
		const RuntimeZoneRecordPlain base = replay.runtime_zones_after_append[size_t(base_index)];
		if (base.level_after_bbox_rescale != 0) {
			continue;
		}
		const int32_t radius = std::max<int32_t>(1, base.runtime_size_after_bbox_rescale > 0 ? base.runtime_size_after_bbox_rescale : base.source_base_size);
		for (int32_t direction_byte_offset = 0; direction_byte_offset < 0x100; direction_byte_offset += 0x20) {
			const int32_t direction_table_index = direction_byte_offset / int32_t(sizeof(double));
			SyntheticRuntimeZoneAttemptPlain attempt;
			attempt.base_runtime_zone_index = base.runtime_index;
			attempt.base_source_zone_id = base.source_zone_id;
			attempt.direction_byte_offset = direction_byte_offset;
			attempt.direction_table_index = direction_table_index;
			attempt.base_x = base.x_after_bbox_rescale;
			attempt.base_y = base.y_after_bbox_rescale;
			attempt.base_level = base.level_after_bbox_rescale;
			attempt.base_radius = radius;
			attempt.candidate_x = ftol_truncate_plain(double(base.x_after_bbox_rescale) + double(radius * 2) * H3MAPED_DIRECTION_X_TABLE[direction_table_index]);
			attempt.candidate_y = ftol_truncate_plain(double(base.y_after_bbox_rescale) + double(radius * 2) * H3MAPED_DIRECTION_Y_TABLE[direction_table_index]);
			attempt.candidate_level = base.level_after_bbox_rescale;
			++replay.scan_attempt_count;

			if (attempt.candidate_x < 0 || attempt.candidate_y < 0 || attempt.candidate_x >= width || attempt.candidate_y >= height) {
				attempt.status = "rejected_candidate_center_out_of_map_bounds_before_0x4a1701";
				++replay.rejected_count;
				replay.attempts.push_back(attempt);
				continue;
			}
			RuntimeZoneRecordPlain synthetic_probe = synthetic_runtime_zone_record_49b452_plain(base, int32_t(replay.runtime_zones_after_append.size()), CoordCandidate { attempt.candidate_x, attempt.candidate_y, attempt.candidate_level }, radius);
			const std::vector<RuntimeZoneRecordPlain> effective_runtime_zones = runtime_zones_with_effective_size_0x1c_plain(replay.runtime_zones_after_append);
			const std::vector<CoordCandidate> zone_positions = coords_from_runtime_zones_plain(effective_runtime_zones);
			const std::vector<int32_t> visible_indices = visible_indices_for_runtime_zones_plain(effective_runtime_zones);
			if (!candidate_valid_4a1701_plain(synthetic_probe, CoordCandidate { attempt.candidate_x, attempt.candidate_y, attempt.candidate_level }, zone_positions, effective_runtime_zones, visible_indices)) {
				attempt.status = "rejected_by_0x4a1701_spacing_or_level_gate";
				++replay.rejected_count;
				replay.attempts.push_back(attempt);
				continue;
			}

			attempt.accepted = true;
			attempt.synthetic_runtime_zone_index = int32_t(replay.runtime_zones_after_append.size());
			attempt.status = "accepted_plain_cpp_0x4a3b48_direction_scan_0x49b452_runtime_zone";
			replay.runtime_zones_after_append.push_back(synthetic_probe);
			++replay.accepted_count;
			replay.attempts.push_back(attempt);
		}
	}
	replay.runtime_zone_count_after_append = int32_t(replay.runtime_zones_after_append.size());
	replay.status = "active_plain_cpp_same_level_synthetic_runtime_zone_append_summary";
	replay.blocked_reason.clear();
	return replay;
}

SourceNodeFootprintSummary build_source_node_footprint_summary(const ControlledCase &controlled_case, const CoordinateReplaySummary &coordinate_summary) {
	SourceNodeFootprintSummary summary;
	summary.coordinate_replay_available = coordinate_summary.ok;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	if (!summary.coordinate_replay_available) {
		summary.blocked_reason = "blocked_until_coordinate_replay";
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}
	summary.generator_mode = resolve_generator_mode_0x49ecf2_plain(controlled_case);
	summary.generator_mode_0x10b8_known = summary.generator_mode.generator_mode_known;
	if (summary.generator_mode_0x10b8_known) {
		summary.generator_mode_0x10b8 = summary.generator_mode.generator_mode_0x10b8;
		summary.synthetic_branch_allowed = summary.generator_mode.generator_mode_0x10b8 != 0;
	}
	summary.synthetic_append = replay_same_level_synthetic_runtime_zone_append_4a3b48_plain(controlled_case, coordinate_summary, summary.generator_mode);
	summary.runtime_zones_after_synthetic_append = summary.synthetic_append.runtime_zones_after_append;
	summary.total_matching_runtime_zones = int32_t(summary.runtime_zones_after_synthetic_append.size());
	if (!summary.generator_mode_0x10b8_known) {
		summary.status = "blocked_same_level_synthetic_runtime_zone_replay_pending";
		summary.blocked_reason = "capture_or_supply_rmg_setup_object_0x44_then_replay_0x4a3b48_0x49b452";
		return summary;
	}
	summary.source = build_polygon_source_walks_4ccb64_plain(summary.runtime_zones_after_synthetic_append);
	summary.source_blocked = summary.source.blocked;
	summary.source_nodes_built = !summary.source.blocked;
	if (summary.source_blocked) {
		summary.status = "blocked_during_source_node_split";
		summary.blocked_reason = "0x4ccb64_source_node_split_guard_failed";
	} else {
		summary.status = summary.synthetic_branch_allowed
				? "active_plain_cpp_source_node_footprint_summary_with_synthetic_runtime_zone_append"
				: "active_plain_cpp_source_node_footprint_summary";
		summary.blocked_reason.clear();
	}
	return summary;
}

int32_t water_mode_code_plain(const ControlledCase &controlled_case) {
	if (controlled_case.water_mode == "normal_water") {
		return 1;
	}
	if (controlled_case.water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t zone_word_id_for_runtime_zone_plain(const RuntimeZoneRecordPlain &zone) {
	if (zone.source_zone_id > 0 && zone.runtime_index >= 0 && zone.source_zone_id == zone.runtime_index + 1) {
		return zone.runtime_index;
	}
	if (zone.source_zone_id >= 0) {
		return zone.source_zone_id;
	}
	return zone.runtime_index;
}

int64_t cell_key_4a325d_plain(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

uint32_t zone_word_4a325d_plain(uint32_t existing_word, int32_t zone_id) {
	return (existing_word & 0xff00ffffU) | (uint32_t(zone_id & 0xff) << 16U);
}

constexpr uint32_t H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN = 0x00ff0000U;

bool span_cell_in_bounds_4a325d_plain(int32_t width, int32_t height, int32_t level_count, const SpanRecordPlain &span) {
	return span.x >= 0 && span.x < width && span.y >= 0 && span.y < height && span.level >= 0 && span.level < level_count;
}

bool is_unassigned_zone_word_4a325d_plain(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	const int64_t key = cell_key_4a325d_plain(width, height, x, y, level);
	return key >= 0 && key < int64_t(zone_words.size()) && (zone_words[size_t(key)] & H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN) == H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN;
}

ClipResultPlain clip_point_4a2b33_plain(int32_t x1, int32_t y1, int32_t x2, int32_t y2, const ClipBoundsPlain &bounds) {
	ClipResultPlain result;
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
	auto accept_with_original_x = [&](const std::string &branch) {
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
		const int32_t next_x = clipped_x + int32_t((int64_t(delta) * int64_t(dx)) / int64_t(dy));
		const int32_t next_y = clipped_y + int32_t((int64_t(dy) * int64_t(delta)) / int64_t(dy));
		clipped_x = next_x;
		clipped_y = next_y;
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

bool point_inside_bounds_4a2777_plain(const ClipResultPlain &point, const ClipBoundsPlain &bounds) {
	return point.x >= bounds.min_x && point.x < bounds.max_x && point.y >= bounds.min_y && point.y < bounds.max_y;
}

int32_t sign_for_line_4a261a_plain(int32_t value) {
	return value > 0 ? 1 : -1;
}

void write_line_cell_4a261a_plain(LineWriteResultPlain &result, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x, int32_t y, int32_t zone_id, int32_t level) {
	if (x < 0 || y < 0 || level < 0 || x >= width || y >= height || level >= level_count) {
		result.out_of_bounds_write_count += 1;
		return;
	}
	LineCellWritePlain write;
	write.x = x;
	write.y = y;
	write.level = level;
	write.zone_id = zone_id & 0xff;
	write.reserved = !(water_code == 2 && level != 1);
	result.trace.push_back(write);
	const int64_t key = cell_key_4a325d_plain(width, height, x, y, level);
	result.unique_cells[key] = true;
}

LineWriteResultPlain line_writer_4a261a_plain(int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level) {
	LineWriteResultPlain result;
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
	const int32_t diagonal_step_y = sign_for_line_4a261a_plain(dy);
	if (dx > abs_dy) {
		major = dx;
		minor = abs_dy;
		simple_step_x = 1;
		simple_step_y = 0;
	} else {
		major = abs_dy;
		minor = dx;
		simple_step_x = 0;
		simple_step_y = sign_for_line_4a261a_plain(dy);
	}

	int32_t error = major / 2;
	int32_t x = x1;
	int32_t y = y1;
	while (x != x2 || y != y2) {
		write_line_cell_4a261a_plain(result, width, height, level_count, water_code, x, y, zone_id, level);
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
	write_line_cell_4a261a_plain(result, width, height, level_count, water_code, x, y, zone_id, level);
	return result;
}

LineWriteResultPlain randomized_line_writer_4a2413_plain(int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level, int32_t random_span_limit, H3MapedRng &rng, int32_t &rng_call_count, int32_t &inserted_midpoint_count, int32_t &max_pending_point_count) {
	LineWriteResultPlain result;
	std::vector<PolygonPointPlain> pending;
	pending.push_back(PolygonPointPlain { x2, y2 });
	max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	int32_t current_x = x1;
	int32_t current_y = y1;
	for (int32_t guard = 0; guard < 4096 && !pending.empty(); ++guard) {
		const PolygonPointPlain target = pending.back();
		pending.pop_back();
		const int32_t midpoint_x = (target.x + current_x + 1) / 2;
		const int32_t midpoint_y = (target.y + current_y + 1) / 2;
		if ((midpoint_x == current_x && midpoint_y == current_y) || (midpoint_x == target.x && midpoint_y == target.y)) {
			const int32_t clamped_x = std::min(std::max(current_x, 0), width - 1);
			const int32_t clamped_y = std::min(std::max(current_y, 0), height - 1);
			write_line_cell_4a261a_plain(result, width, height, level_count, water_code, clamped_x, clamped_y, zone_id, level);
			current_x = target.x;
			current_y = target.y;
			continue;
		}
		const int32_t dx = target.x - current_x;
		const int32_t neg_dy = current_y - target.y;
		const int32_t segment_length = h3maped_distance_truncate_plain(0, 0, dx, neg_dy);
		int32_t jittered_x = midpoint_x;
		int32_t jittered_y = midpoint_y;
		if (segment_length > 1) {
			const int32_t jitter_limit = std::max<int32_t>(1, std::min(random_span_limit, segment_length));
			const int32_t rng_value = rng.next();
			rng_call_count += 1;
			const int32_t centered_offset = (rng_value % jitter_limit) - (jitter_limit / 2);
			const int32_t adjusted_x = (int64_t(centered_offset) * int64_t(neg_dy)) / int64_t(segment_length);
			const int32_t adjusted_y = (int64_t(dx) * int64_t(centered_offset)) / int64_t(segment_length);
			jittered_x += adjusted_x;
			jittered_y += adjusted_y;
		}
		pending.push_back(target);
		pending.push_back(PolygonPointPlain { jittered_x, jittered_y });
		inserted_midpoint_count += 1;
		max_pending_point_count = std::max<int32_t>(max_pending_point_count, int32_t(pending.size()));
	}
	return result;
}

void merge_line_write_result_4a2777_plain(const LineWriteResultPlain &line, std::map<int64_t, bool> &unique_cells, int32_t &trace_write_count, int32_t &out_of_bounds_write_count) {
	for (const auto &item : line.unique_cells) {
		unique_cells[item.first] = true;
	}
	trace_write_count += int32_t(line.trace.size());
	out_of_bounds_write_count += line.out_of_bounds_write_count;
}

void apply_line_trace_to_zone_buffer_4a2777_plain(const LineWriteResultPlain &line, std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count) {
	for (const LineCellWritePlain &write : line.trace) {
		if (write.x < 0 || write.y < 0 || write.level < 0 || write.x >= width || write.y >= height || write.level >= level_count) {
			continue;
		}
		const int64_t key = cell_key_4a325d_plain(width, height, write.x, write.y, write.level);
		if (key < 0 || key >= int64_t(zone_words.size()) || key >= int64_t(cell_flags.size())) {
			continue;
		}
		zone_words[size_t(key)] = zone_word_4a325d_plain(zone_words[size_t(key)], write.zone_id);
		if (write.reserved) {
			cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
		}
	}
}

void push_span_4a325d_plain(std::vector<SpanRecordPlain> &pending, const SpanRecordPlain &span, SpanFillResultPlain &result) {
	pending.push_back(span);
	result.pushed_span_count += 1;
	result.max_pending_span_count = std::max<int32_t>(result.max_pending_span_count, int32_t(pending.size()));
}

SpanFillResultPlain span_fill_4a325d_plain(std::vector<uint32_t> &zone_words, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t water_code, int32_t zone_id, const SpanRecordPlain &seed) {
	SpanFillResultPlain result;
	std::vector<SpanRecordPlain> pending;
	push_span_4a325d_plain(pending, seed, result);
	for (int32_t guard = 0; guard < width * height * std::max(1, level_count) * 4 && !pending.empty(); ++guard) {
		SpanRecordPlain span = pending.back();
		pending.pop_back();
		result.popped_span_count += 1;
		if (!span_cell_in_bounds_4a325d_plain(width, height, level_count, span)) {
			result.out_of_bounds_span_count += 1;
			continue;
		}
		int32_t x = span.x;
		while (x > 0 && is_unassigned_zone_word_4a325d_plain(zone_words, width, height, x - 1, span.y, span.level)) {
			x -= 1;
		}
		if (x >= 0 && x < width && !is_unassigned_zone_word_4a325d_plain(zone_words, width, height, x, span.y, span.level)) {
			result.blocked_initial_span_count += 1;
		}
		bool above_open = false;
		bool below_open = false;
		SpanRecordPlain above_span;
		SpanRecordPlain below_span;
		for (; x < width; ++x) {
			if (!is_unassigned_zone_word_4a325d_plain(zone_words, width, height, x, span.y, span.level)) {
				break;
			}
			const int64_t key = cell_key_4a325d_plain(width, height, x, span.y, span.level);
			if (key < 0 || key >= int64_t(zone_words.size()) || key >= int64_t(cell_flags.size())) {
				continue;
			}
			zone_words[size_t(key)] = zone_word_4a325d_plain(zone_words[size_t(key)], zone_id);
			const bool reserved = !(water_code == 2 && span.level == 1);
			if (reserved) {
				cell_flags[size_t(key)] = uint8_t(cell_flags[size_t(key)] | 0x10U);
			}
			SpanFillCellWritePlain write;
			write.x = x;
			write.y = span.y;
			write.level = span.level;
			write.zone_id = zone_id;
			write.reserved = reserved;
			result.trace.push_back(write);
			result.unique_cells[key] = true;
			if (span.y > 0 && is_unassigned_zone_word_4a325d_plain(zone_words, width, height, x, span.y - 1, span.level)) {
				if (!above_open) {
					above_span = span;
					above_span.x = x;
					above_span.y = span.y - 1;
					above_open = true;
				}
			} else if (above_open) {
				push_span_4a325d_plain(pending, above_span, result);
				above_open = false;
			}
			if (span.y < height - 1 && is_unassigned_zone_word_4a325d_plain(zone_words, width, height, x, span.y + 1, span.level)) {
				if (!below_open) {
					below_span = span;
					below_span.x = x;
					below_span.y = span.y + 1;
					below_open = true;
				}
			} else if (below_open) {
				push_span_4a325d_plain(pending, below_span, result);
				below_open = false;
			}
		}
		if (above_open) {
			push_span_4a325d_plain(pending, above_span, result);
		}
		if (below_open) {
			push_span_4a325d_plain(pending, below_span, result);
		}
	}
	return result;
}

struct SeedRelocationPlain {
	std::string status = "0x4a325d_seed_in_bounds_relocation_not_used";
	bool relocated = false;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

SeedRelocationPlain seed_relocation_4a325d_plain(const SourceWalkPlain *walk, const SpanRecordPlain &seed, int32_t width, int32_t height, int32_t level_count) {
	SeedRelocationPlain relocation;
	relocation.x = seed.x;
	relocation.y = seed.y;
	relocation.level = seed.level;
	const bool seed_in_bounds = seed.x >= 0 && seed.x < width && seed.y >= 0 && seed.y < height && seed.level >= 0 && seed.level < level_count;
	if (seed_in_bounds) {
		return relocation;
	}
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_clearance = -1;
	if (walk != nullptr) {
		for (const SourceCycleNodePlain &node : walk->cycle_nodes) {
			const int32_t x = node.x;
			const int32_t y = node.y;
			if (x >= 1 && x < width - 1 && y >= 1 && y < height - 1) {
				const int32_t clearance = std::min<int32_t>(std::min<int32_t>(x, width - x - 1), std::min<int32_t>(y, height - y - 1));
				if (clearance > best_clearance) {
					best_clearance = clearance;
					best_x = x;
					best_y = y;
				}
			}
		}
	}
	if (best_x < 0 || best_y < 0) {
		relocation.status = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
		return relocation;
	}
	ClipBoundsPlain bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	const ClipResultPlain clipped = clip_point_4a2b33_plain(seed.x, seed.y, best_x, best_y, bounds);
	relocation.status = "0x4a325d_seed_out_of_bounds_relocated_with_0x4a2b33";
	relocation.relocated = true;
	relocation.x = clipped.x;
	relocation.y = clipped.y;
	return relocation;
}

BoundarySpanFillSummary build_boundary_span_fill_summary(const ControlledCase &controlled_case, const CoordinateReplaySummary &coordinate_summary, const SourceNodeFootprintSummary &source_node_summary) {
	BoundarySpanFillSummary summary;
	summary.coordinate_replay_available = coordinate_summary.ok;
	summary.source_node_walks_available = source_node_summary.source_nodes_built;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.width = map_width_for_size(controlled_case.size_class);
	summary.height = summary.width;
	summary.level_count = controlled_case.level_count;
	summary.water_code = water_mode_code_plain(controlled_case);
	summary.rng_state_before_0x4a2777 = coordinate_summary.rng_state_after_0x4a218c;
	summary.rng_state_after_0x4a2777 = coordinate_summary.rng_state_after_0x4a218c;
	const std::vector<RuntimeZoneRecordPlain> &runtime_zones = source_node_summary.runtime_zones_after_synthetic_append.empty()
			? coordinate_summary.scaled_zone_coordinates
			: source_node_summary.runtime_zones_after_synthetic_append;
	summary.same_level_synthetic_runtime_zone_append_ported = source_node_summary.synthetic_append.ported_plain_cpp;
	summary.same_level_synthetic_runtime_zone_branch_allowed = source_node_summary.synthetic_append.branch_allowed;
	summary.same_level_synthetic_runtime_zone_count = source_node_summary.synthetic_append.accepted_count;
	summary.runtime_zone_count_after_synthetic_append = int32_t(runtime_zones.size());
	if (!summary.coordinate_replay_available) {
		summary.blocked_reason = "blocked_until_coordinate_replay";
		return summary;
	}
	if (!summary.source_node_walks_available) {
		summary.blocked_reason = "blocked_until_source_node_walks";
		return summary;
	}
	if (!summary.supported_scope || summary.width <= 0 || summary.height <= 0 || summary.level_count <= 0) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	const int32_t cell_count = std::max(0, summary.width * summary.height * std::max(1, summary.level_count));
	std::vector<uint32_t> zone_words(size_t(cell_count), H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN);
	std::vector<uint8_t> cell_flags(size_t(cell_count), 0);
	std::map<int64_t, bool> boundary_unique_cells;
	H3MapedRng rng;
	rng.state = summary.rng_state_before_0x4a2777;
	ClipBoundsPlain bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = summary.width;
	bounds.max_y = summary.height;

	auto append_line = [&](int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_word, int32_t level, bool randomized, int32_t random_span_limit) {
		LineWriteResultPlain line;
		if (randomized) {
			line = randomized_line_writer_4a2413_plain(summary.width, summary.height, summary.level_count, summary.water_code, x1, y1, x2, y2, zone_word, level, random_span_limit, rng, summary.boundary_randomized_rng_call_count, summary.boundary_randomized_inserted_midpoint_count, summary.boundary_randomized_max_pending_point_count);
			summary.boundary_flagged_writer_segment_count += 1;
		} else {
			line = line_writer_4a261a_plain(summary.width, summary.height, summary.level_count, summary.water_code, x1, y1, x2, y2, zone_word, level);
			summary.boundary_deterministic_writer_segment_count += 1;
		}
		merge_line_write_result_4a2777_plain(line, boundary_unique_cells, summary.boundary_trace_write_count, summary.boundary_out_of_bounds_write_count);
		apply_line_trace_to_zone_buffer_4a2777_plain(line, zone_words, cell_flags, summary.width, summary.height, summary.level_count);
	};

	auto point_on_clip_border = [&](int32_t x, int32_t y) {
		return x == bounds.min_x || x == bounds.max_x - 1 || y == bounds.min_y || y == bounds.max_y - 1;
	};

	auto append_border_connection = [&](int32_t &current_x, int32_t &current_y, int32_t target_x, int32_t target_y, int32_t zone_word, int32_t level, int32_t random_span_limit) {
		if (current_x == target_x && current_y == target_y) {
			return;
		}
		const int32_t right_x = std::max<int32_t>(bounds.min_x, bounds.max_x - 1);
		const int32_t bottom_y = std::max<int32_t>(bounds.min_y, bounds.max_y - 1);
		int32_t wrap_guard = 0;
		while (current_x != target_x && current_y != target_y && point_on_clip_border(current_x, current_y) && point_on_clip_border(target_x, target_y) && wrap_guard < 8) {
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
			append_line(current_x, current_y, border_x, border_y, zone_word, level, false, random_span_limit);
			summary.boundary_appended_vertex_count += 1;
			current_x = border_x;
			current_y = border_y;
			summary.boundary_wrap_segment_count += 1;
			wrap_guard += 1;
		}
		if (wrap_guard >= 8 && current_x != target_x && current_y != target_y) {
			summary.boundary_loop_guard_exhausted = true;
			return;
		}
		if (current_x != target_x || current_y != target_y) {
			append_line(current_x, current_y, target_x, target_y, zone_word, level, false, random_span_limit);
			summary.boundary_appended_vertex_count += 1;
			summary.boundary_final_segment_count += 1;
			current_x = target_x;
			current_y = target_y;
		}
	};

	for (const SourceWalkPlain &walk : source_node_summary.source.walks) {
		const int32_t runtime_zone_index = walk.runtime_zone_index;
		if (runtime_zone_index < 0 || runtime_zone_index >= int32_t(runtime_zones.size())) {
			summary.boundary_blocked_zone_count += 1;
			continue;
		}
		const RuntimeZoneRecordPlain &zone = runtime_zones[size_t(runtime_zone_index)];
		const int32_t zone_word = zone_word_id_for_runtime_zone_plain(zone);
		const int32_t level = zone.level_after_bbox_rescale;
		const bool flagged_branch = !(summary.level_count == 2 && level != 1);
		const int32_t random_span_limit = std::max<int32_t>(1, zone.runtime_size_after_bbox_rescale > 0 ? zone.runtime_size_after_bbox_rescale : zone.source_base_size);
		std::vector<SourceCycleNodePlain> source_nodes;
		for (const SourceCycleNodePlain &node : walk.cycle_nodes) {
			if (!node.finalized) {
				summary.boundary_skipped_unfinalized_node_count += 1;
				continue;
			}
			source_nodes.push_back(node);
		}
		if (source_nodes.size() < 2) {
			summary.boundary_blocked_zone_count += 1;
			continue;
		}
		auto node_point = [](const SourceCycleNodePlain &node) {
			return PolygonPointPlain { node.finalized_x, node.finalized_y };
		};
		auto source_edge_writer_allowed = [&](const SourceCycleNodePlain &from_node) {
			return !(from_node.next_pair_has_payload && from_node.next_pair_payload <= zone_word);
		};
		int32_t selected_segment_index = -1;
		ClipResultPlain clipped_current;
		ClipResultPlain clipped_target;
		for (int32_t index = 0; index < int32_t(source_nodes.size()); ++index) {
			const PolygonPointPlain from = node_point(source_nodes[size_t(index)]);
			const PolygonPointPlain to = node_point(source_nodes[size_t((index + 1) % int32_t(source_nodes.size()))]);
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			ClipResultPlain candidate_current = clip_point_4a2b33_plain(from.x, from.y, to.x, to.y, bounds);
			ClipResultPlain candidate_target = clip_point_4a2b33_plain(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777_plain(candidate_current, bounds)) {
				summary.boundary_skipped_out_of_bounds_clip_count += 1;
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
			summary.boundary_fallback_zone_count += 1;
			continue;
		}
		if (source_edge_writer_allowed(source_nodes[size_t(selected_segment_index)])) {
			append_line(clipped_current.x, clipped_current.y, clipped_target.x, clipped_target.y, zone_word, level, flagged_branch, random_span_limit);
			summary.boundary_appended_vertex_count += 1;
			summary.boundary_connector_segment_count += 1;
		} else {
			summary.boundary_owner_gate_skipped_segment_count += 1;
		}
		int32_t current_x = clipped_target.x;
		int32_t current_y = clipped_target.y;
		int32_t source_index = (selected_segment_index + 1) % int32_t(source_nodes.size());
		for (int32_t guard = 0; guard < int32_t(source_nodes.size()) + 4; ++guard) {
			const int32_t next_source_index = (source_index + 1) % int32_t(source_nodes.size());
			if (source_index == selected_segment_index) {
				break;
			}
			const SourceCycleNodePlain &from_node = source_nodes[size_t(source_index)];
			const PolygonPointPlain from = node_point(from_node);
			const PolygonPointPlain to = node_point(source_nodes[size_t(next_source_index)]);
			source_index = next_source_index;
			if (from.x == to.x && from.y == to.y) {
				continue;
			}
			const ClipResultPlain from_clip = clip_point_4a2b33_plain(from.x, from.y, to.x, to.y, bounds);
			const ClipResultPlain to_clip = clip_point_4a2b33_plain(to.x, to.y, from.x, from.y, bounds);
			if (!point_inside_bounds_4a2777_plain(from_clip, bounds) || !point_inside_bounds_4a2777_plain(to_clip, bounds)) {
				summary.boundary_skipped_out_of_bounds_clip_count += 1;
				continue;
			}
			append_border_connection(current_x, current_y, from_clip.x, from_clip.y, zone_word, level, random_span_limit);
			if (summary.boundary_loop_guard_exhausted) {
				break;
			}
			if (from_clip.x != to_clip.x || from_clip.y != to_clip.y) {
				if (source_edge_writer_allowed(from_node)) {
					append_line(from_clip.x, from_clip.y, to_clip.x, to_clip.y, zone_word, level, false, random_span_limit);
					summary.boundary_appended_vertex_count += 1;
					summary.boundary_connector_segment_count += 1;
				} else {
					summary.boundary_owner_gate_skipped_segment_count += 1;
				}
				current_x = to_clip.x;
				current_y = to_clip.y;
			}
			if (source_index == selected_segment_index) {
				break;
			}
		}
		summary.boundary_runtime_zone_walk_count += 1;
	}

	summary.boundary_unique_cell_count = int32_t(boundary_unique_cells.size());
	summary.rng_state_after_0x4a2777 = rng.state;
	std::map<int64_t, bool> real_unique_filled_cells;
	for (const RuntimeZoneRecordPlain &zone : runtime_zones) {
		const SourceWalkPlain *matching_walk = nullptr;
		for (const SourceWalkPlain &walk : source_node_summary.source.walks) {
			if (walk.runtime_zone_index == zone.runtime_index) {
				matching_walk = &walk;
				break;
			}
		}
		ZoneSpanFillSummaryPlain zone_fill;
		zone_fill.runtime_zone_index = zone.runtime_index;
		zone_fill.source_zone_id = zone.source_zone_id;
		zone_fill.zone_word_id = zone_word_id_for_runtime_zone_plain(zone);
		zone_fill.seed_x = zone.x_after_bbox_rescale;
		zone_fill.seed_y = zone.y_after_bbox_rescale;
		zone_fill.seed_level = zone.level_after_bbox_rescale;
		SpanRecordPlain seed { zone_fill.seed_x, zone_fill.seed_y, zone_fill.seed_level };
		SeedRelocationPlain relocation = seed_relocation_4a325d_plain(matching_walk, seed, summary.width, summary.height, summary.level_count);
		zone_fill.seed_relocation_status = relocation.status;
		if (relocation.relocated) {
			seed.x = relocation.x;
			seed.y = relocation.y;
			seed.level = relocation.level;
			zone_fill.seed_relocated = true;
			summary.span_fill_seed_relocated_count += 1;
		}
		zone_fill.effective_seed_x = seed.x;
		zone_fill.effective_seed_y = seed.y;
		zone_fill.effective_seed_level = seed.level;
		zone_fill.seed_in_bounds = span_cell_in_bounds_4a325d_plain(summary.width, summary.height, summary.level_count, seed);
		if (!zone_fill.seed_in_bounds) {
			zone_fill.status = "0x4a325d_seed_out_of_bounds_no_relocation_candidate";
			summary.span_fill_seed_blocked_count += 1;
			summary.zone_fills.push_back(zone_fill);
			continue;
		}
		zone_fill.seed_unassigned_before_fill = is_unassigned_zone_word_4a325d_plain(zone_words, summary.width, summary.height, seed.x, seed.y, seed.level);
		if (!zone_fill.seed_unassigned_before_fill) {
			summary.span_fill_seed_blocked_count += 1;
		}
		SpanFillResultPlain fill = span_fill_4a325d_plain(zone_words, cell_flags, summary.width, summary.height, summary.level_count, summary.water_code, zone_fill.zone_word_id, seed);
		for (const auto &item : fill.unique_cells) {
			real_unique_filled_cells[item.first] = true;
		}
		if (!fill.trace.empty()) {
			summary.span_fill_filled_zone_count += 1;
		}
		summary.span_fill_pushed_span_count += fill.pushed_span_count;
		summary.span_fill_popped_span_count += fill.popped_span_count;
		summary.span_fill_max_pending_span_count = std::max<int32_t>(summary.span_fill_max_pending_span_count, fill.max_pending_span_count);
		summary.span_fill_out_of_bounds_span_count += fill.out_of_bounds_span_count;
		summary.span_fill_blocked_initial_span_count += fill.blocked_initial_span_count;
		zone_fill.status = fill.trace.empty() ? "0x4a325d_seed_reached_non_unassigned_boundary" : "0x4a325d_real_boundary_span_fill_executed";
		zone_fill.filled_cell_count = int32_t(fill.trace.size());
		zone_fill.unique_filled_cell_count = int32_t(fill.unique_cells.size());
		zone_fill.pushed_span_count = fill.pushed_span_count;
		zone_fill.popped_span_count = fill.popped_span_count;
		zone_fill.max_pending_span_count = fill.max_pending_span_count;
		zone_fill.out_of_bounds_span_count = fill.out_of_bounds_span_count;
		zone_fill.blocked_initial_span_count = fill.blocked_initial_span_count;
		summary.zone_fills.push_back(zone_fill);
	}
	summary.span_fill_attempt_count = int32_t(runtime_zones.size());
	summary.span_fill_unique_filled_cell_count = int32_t(real_unique_filled_cells.size());
	for (int32_t level = 0; level < summary.level_count; ++level) {
		for (int32_t y = 0; y < summary.height; ++y) {
			for (int32_t x = 0; x < summary.width; ++x) {
				const int64_t key = cell_key_4a325d_plain(summary.width, summary.height, x, y, level);
				const uint32_t zone_word = zone_words[size_t(key)] & H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN;
				if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN) {
					summary.span_fill_remaining_unassigned_cell_count += 1;
				} else {
					summary.span_fill_boundary_or_filled_cell_count += 1;
					summary.cells_by_zone_word[int32_t((zone_word >> 16U) & 0xffU)] += 1;
				}
			}
		}
	}
	constexpr uint32_t GENERATED_CELL_WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t GENERATED_CELL_WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t GENERATED_CELL_WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr uint32_t GENERATED_CELL_WORD_0X2C_DEFAULT = 0U;
	constexpr int32_t GENERATED_CELL_TERRAIN_CODE_DEFAULT = 8;
	summary.generated_cell_word_0x20.assign(size_t(cell_count), GENERATED_CELL_WORD_0X20_DEFAULT);
	summary.generated_cell_word_0x24.assign(size_t(cell_count), GENERATED_CELL_WORD_0X24_DEFAULT);
	summary.generated_cell_word_0x28.assign(size_t(cell_count), GENERATED_CELL_WORD_0X28_DEFAULT);
	summary.generated_cell_word_0x2c.assign(size_t(cell_count), GENERATED_CELL_WORD_0X2C_DEFAULT);
	summary.generated_cell_terrain_code.assign(size_t(cell_count), GENERATED_CELL_TERRAIN_CODE_DEFAULT);
	for (int32_t flat = 0; flat < cell_count; ++flat) {
		const uint32_t zone_word = zone_words[size_t(flat)] & H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN;
		if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN) {
			summary.generated_cell_word_0x20_unassigned_sentinel_count += 1;
			continue;
		}
		summary.generated_cell_word_0x20[size_t(flat)] = (GENERATED_CELL_WORD_0X20_DEFAULT & 0xff00ffffU) | zone_word;
		summary.generated_cell_word_0x20_owner_byte_materialized_count += 1;
	}
	summary.generated_cell_owner_words_materialized = true;
	summary.private_zone_cell_buffer_materialized = true;
	summary.boundary_span_fill_materialized_plain_cpp = true;
	if (source_node_summary.status == "blocked_same_level_synthetic_runtime_zone_replay_pending") {
		summary.status = source_node_summary.status;
		summary.blocked_reason = "boundary_and_span_fill_blocked_until_same_level_synthetic_runtime_zone_append_inputs_are_known";
	} else if (summary.boundary_loop_guard_exhausted) {
		summary.status = "blocked_boundary_loop_guard_exhausted";
		summary.blocked_reason = "0x4a2777_boundary_wrap_loop_guard_exhausted";
	} else {
		summary.status = "active_plain_cpp_boundary_span_fill_summary";
		summary.blocked_reason.clear();
	}
	return summary;
}

void append_int_array_json(std::ostream &out, const std::vector<int32_t> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		out << values[index];
	}
	out << "]";
}

void append_coord_json(std::ostream &out, const CoordCandidate &coord) {
	out << "{";
	out << "\"x\":" << coord.x << ",";
	out << "\"y\":" << coord.y << ",";
	out << "\"level\":" << coord.level;
	out << "}";
}

void append_coord_array_json(std::ostream &out, const std::vector<CoordCandidate> &coords) {
	out << "[";
	for (size_t index = 0; index < coords.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		append_coord_json(out, coords[index]);
	}
	out << "]";
}

void append_plain_runtime_records_json(std::ostream &out, const std::vector<RuntimeZoneRecordPlain> &records, bool include_scaled_coordinates) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RuntimeZoneRecordPlain &record = records[index];
		out << "{";
		out << "\"runtime_index\":" << record.runtime_index << ",";
		out << "\"source_zone_id\":" << record.source_zone_id << ",";
		out << "\"role\":\"" << json_escape(record.role) << "\",";
		out << "\"source_bucket\":" << record.source_bucket << ",";
		out << "\"source_owner_index\":" << record.source_owner_index << ",";
		out << "\"actual_owner_color\":" << record.actual_owner_color << ",";
		out << "\"is_player_capable_zone\":" << (record.is_player_capable_zone ? "true" : "false") << ",";
		out << "\"has_assigned_start\":" << (record.has_assigned_start ? "true" : "false") << ",";
		out << "\"source_base_size\":" << record.source_base_size << ",";
		out << "\"allowed_original_town_indices_49b3c1\":";
		append_int_array_json(out, record.allowed_town_slots);
		out << ",";
		out << "\"town_choice_rng_value_49b3c1\":" << record.town_choice_rng_value << ",";
		out << "\"town_choice_index_49b3c1\":" << record.town_choice_index << ",";
		out << "\"town_choice_selected_allowed_ordinal_49b3c1\":" << record.town_choice_selected_allowed_ordinal;
		if (include_scaled_coordinates) {
			out << ",";
			out << "\"x_after_bbox_rescale\":" << record.x_after_bbox_rescale << ",";
			out << "\"y_after_bbox_rescale\":" << record.y_after_bbox_rescale << ",";
			out << "\"level\":" << record.level_after_bbox_rescale << ",";
			out << "\"runtime_size_after_bbox_rescale\":" << record.runtime_size_after_bbox_rescale;
		}
		out << "}";
	}
	out << "]";
}

void append_link_seed_records_json(std::ostream &out, const std::vector<RuntimeLinkSeedPlain> &links) {
	out << "[";
	for (size_t index = 0; index < links.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RuntimeLinkSeedPlain &link = links[index];
		out << "{";
		out << "\"link_index\":" << link.link_index << ",";
		out << "\"source_row\":" << link.source_row << ",";
		out << "\"source_zone_a\":" << link.source_zone_a << ",";
		out << "\"source_zone_b\":" << link.source_zone_b << ",";
		out << "\"runtime_zone_a\":" << link.runtime_a << ",";
		out << "\"runtime_zone_b\":" << link.runtime_b << ",";
		out << "\"guard_value\":" << link.guard_value << ",";
		out << "\"wide\":" << (link.wide ? "true" : "false") << ",";
		out << "\"border_guard\":" << (link.border_guard ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_link_seed_summary_json(std::ostream &out, const CoordinateReplaySummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_link_seed_summary_v1\",\n";
	out << "    \"phase_id\": \"link_seed_setup\",\n";
	out << "    \"h3maped_anchor\": \"0x4a1f3b\",\n";
	out << "    \"status\": \"" << (summary.link_seeds.empty() && !summary.ok ? "blocked" : "active_plain_cpp_link_seed_summary") << "\",\n";
	out << "    \"source\": \"original recovered h3maped template connections consumed by 0x4a1f3b\",\n";
	out << "    \"link_seed_count\": " << summary.link_seeds.size() << ",\n";
	out << "    \"materializes_coordinates\": false,\n";
	out << "    \"materializes_connection_guards\": false,\n";
	out << "    \"link_seeds\": ";
	append_link_seed_records_json(out, summary.link_seeds);
	out << "\n";
	out << "  }";
}

void append_rng_events_json(std::ostream &out, const std::vector<RngEventPlain> &events) {
	out << "[";
	for (size_t index = 0; index < events.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RngEventPlain &event = events[index];
		out << "{";
		out << "\"consumer\":\"" << json_escape(event.consumer) << "\",";
		out << "\"runtime_zone_index\":" << event.runtime_zone_index << ",";
		if (!event.pass_id.empty()) {
			out << "\"pass\":\"" << json_escape(event.pass_id) << "\",";
		}
		out << "\"value\":" << event.value << ",";
		out << "\"modulus\":" << event.modulus << ",";
		out << "\"selected_index\":" << event.selected_index;
		if (!event.allowed_original_town_indices.empty()) {
			out << ",\"allowed_original_town_indices\":";
			append_int_array_json(out, event.allowed_original_town_indices);
		}
		out << "}";
	}
	out << "]";
}

void append_placement_steps_json(std::ostream &out, const std::vector<PlacementStepPlain> &steps) {
	out << "[";
	for (size_t index = 0; index < steps.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const PlacementStepPlain &step = steps[index];
		out << "{";
		out << "\"pass\":\"" << json_escape(step.pass_id) << "\",";
		out << "\"runtime_zone_index\":" << step.runtime_zone_index << ",";
		out << "\"runtime_vector_count_before_call\":" << step.visible_runtime_zone_indices.size() << ",";
		out << "\"visible_runtime_zone_indices\":";
		append_int_array_json(out, step.visible_runtime_zone_indices);
		out << ",";
		out << "\"candidate_source\":\"" << json_escape(step.candidate_source) << "\",";
		out << "\"explicit_link_base_count\":" << step.explicit_link_base_count << ",";
		out << "\"fallback_base_count\":" << step.fallback_base_count << ",";
		out << "\"candidate_count_before_4a1ad8\":" << step.candidate_count_before_4a1ad8 << ",";
		out << "\"candidate_preview_before_4a1ad8\":";
		append_coord_array_json(out, step.candidate_preview_before_4a1ad8);
		out << ",";
		out << "\"candidate_count_after_4a1ad8\":" << step.candidate_count_after_4a1ad8 << ",";
		out << "\"candidate_preview_after_4a1ad8\":";
		append_coord_array_json(out, step.candidate_preview_after_4a1ad8);
		out << ",";
		out << "\"blocked\":" << (step.blocked ? "true" : "false") << ",";
		out << "\"blocked_reason\":\"" << json_escape(step.blocked_reason) << "\",";
		out << "\"rng_value\":" << step.rng_value << ",";
		out << "\"selected_candidate_index\":" << step.selected_candidate_index << ",";
		out << "\"selected_candidate\":";
		append_coord_json(out, step.selected_candidate);
		out << "}";
	}
	out << "]";
}

void append_coordinate_replay_summary_json(std::ostream &out, const CoordinateReplaySummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_coordinate_replay_summary_v1\",\n";
	out << "    \"phase_id\": \"coordinate_replay\",\n";
	out << "    \"h3maped_anchor\": \"0x4a218c\",\n";
	out << "    \"link_endpoint_consumer_anchor\": \"0x4a1f3b\",\n";
	out << "    \"candidate_generator_anchor\": \"0x4a17f5\",\n";
	out << "    \"distance_validation_anchor\": \"0x4a1701\",\n";
	out << "    \"candidate_prune_anchor\": \"0x4a1ad8\",\n";
	out << "    \"bbox_rescale_anchor\": \"0x4a19ed\",\n";
	out << "    \"status\": \"" << (summary.ok ? "active_plain_cpp_coordinate_replay_summary" : "blocked_coordinate_candidate_replay") << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"h3maped 0x4a218c interleaved runtime initializer, 0x4a1f3b endpoint walking, 0x4a17f5 candidates, 0x4a1701 spacing validation, 0x4a1ad8 pruning, and 0x4a19ed bbox rescale\",\n";
	out << "    \"materializes_zone_footprints\": false,\n";
	out << "    \"materializes_private_generated_cell_owner_words\": false,\n";
	out << "    \"placement_step_count\": " << summary.placement_steps.size() << ",\n";
	out << "    \"blanket_refinement_pass_count\": 2,\n";
	out << "    \"minimum_source_base_size\": " << summary.minimum_source_base_size << ",\n";
	out << "    \"coordinate_prune_span_budget_4a218c\": " << summary.coordinate_prune_span_budget_4a218c << ",\n";
	out << "    \"coordinate_prune_divisor_4a218c\": " << summary.coordinate_prune_divisor_4a218c << ",\n";
	out << "    \"coordinate_rng_calls_during_0x4a1f3b\": " << summary.coordinate_rng_calls << ",\n";
	out << "    \"town_choice_rng_calls_during_0x4a218c\": " << summary.town_choice_rng_calls << ",\n";
	out << "    \"total_interleaved_rng_calls_during_0x4a218c\": " << (summary.coordinate_rng_calls + summary.town_choice_rng_calls) << ",\n";
	out << "    \"rng_event_count\": " << summary.rng_events.size() << ",\n";
	out << "    \"rng_state_after_0x4a218c_replay_uint32\": " << summary.rng_state_after_0x4a218c << ",\n";
	out << "    \"runtime_zone_records_after_0x49b3c1\": ";
	append_plain_runtime_records_json(out, summary.runtime_records_after_0x49b3c1, false);
	out << ",\n";
	out << "    \"placement_steps\": ";
	append_placement_steps_json(out, summary.placement_steps);
	out << ",\n";
	out << "    \"rng_events\": ";
	append_rng_events_json(out, summary.rng_events);
	out << ",\n";
	out << "    \"bounding_box_rescale\": {";
	out << "\"min_y_before_rescale\":" << summary.bbox_min_y << ",";
	out << "\"min_x_before_rescale\":" << summary.bbox_min_x << ",";
	out << "\"max_y_before_rescale\":" << summary.bbox_max_y << ",";
	out << "\"max_x_before_rescale\":" << summary.bbox_max_x << ",";
	out << "\"height_before_rescale\":" << summary.bbox_height << ",";
	out << "\"width_before_rescale\":" << summary.bbox_width << ",";
	out << "\"selected_span_before_rescale\":" << summary.bbox_span << ",";
	out << "\"map_span\":" << summary.map_span << ",";
	out << "\"offset_y\":" << summary.offset_y << ",";
	out << "\"offset_x\":" << summary.offset_x;
	out << "},\n";
	out << "    \"scaled_zone_coordinates\": ";
	append_plain_runtime_records_json(out, summary.scaled_zone_coordinates, true);
	out << ",\n";
	out << "    \"blocked_next\": \"zone_footprint_source_nodes_0x4a3a03_0x4cc788_then_0x4a325d_owner_materialization\"\n";
	out << "  }";
}

void append_source_split_steps_json(std::ostream &out, const std::vector<SourceSplitStepPlain> &steps) {
	out << "[";
	for (size_t index = 0; index < steps.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SourceSplitStepPlain &step = steps[index];
		out << "{";
		out << "\"runtime_zone_index\":" << step.runtime_zone_index << ",";
		out << "\"source_zone_id\":" << step.source_zone_id << ",";
		out << "\"x\":" << step.x << ",";
		out << "\"y\":" << step.y << ",";
		out << "\"status\":\"" << json_escape(step.status) << "\",";
		out << "\"bridge_pair_count\":" << step.bridge_pair_count << ",";
		out << "\"crossing_cleanup_scan_count\":" << step.crossing_cleanup_scan_count << ",";
		out << "\"crossing_test_count\":" << step.crossing_test_count << ",";
		out << "\"crossing_collapse_count\":" << step.crossing_collapse_count;
		out << "}";
	}
	out << "]";
}

void append_source_walks_json(std::ostream &out, const std::vector<SourceWalkPlain> &walks) {
	out << "[";
	for (size_t walk_index = 0; walk_index < walks.size(); ++walk_index) {
		if (walk_index != 0) {
			out << ",";
		}
		const SourceWalkPlain &walk = walks[walk_index];
		out << "{";
		out << "\"runtime_zone_index\":" << walk.runtime_zone_index << ",";
		out << "\"source_zone_id\":" << walk.source_zone_id << ",";
		out << "\"start_x\":" << walk.start_x << ",";
		out << "\"start_y\":" << walk.start_y << ",";
		out << "\"nodes\":[";
		for (size_t node_index = 0; node_index < walk.cycle_nodes.size(); ++node_index) {
			if (node_index != 0) {
				out << ",";
			}
			const SourceCycleNodePlain &node = walk.cycle_nodes[node_index];
			out << "{";
			out << "\"x\":" << node.x << ",";
			out << "\"y\":" << node.y << ",";
			out << "\"has_payload\":" << (node.has_payload ? "true" : "false") << ",";
			out << "\"payload\":" << node.payload << ",";
			out << "\"next_pair_has_payload\":" << (node.next_pair_has_payload ? "true" : "false") << ",";
			out << "\"next_pair_payload\":" << node.next_pair_payload << ",";
			out << "\"finalized\":" << (node.finalized ? "true" : "false") << ",";
			out << "\"finalized_x\":" << node.finalized_x << ",";
			out << "\"finalized_y\":" << node.finalized_y;
			out << "}";
		}
		out << "]";
		out << "}";
	}
	out << "]";
}

void append_synthetic_runtime_zone_attempts_json(std::ostream &out, const std::vector<SyntheticRuntimeZoneAttemptPlain> &attempts) {
	out << "[";
	for (size_t index = 0; index < attempts.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SyntheticRuntimeZoneAttemptPlain &attempt = attempts[index];
		out << "{";
		out << "\"base_runtime_zone_index\":" << attempt.base_runtime_zone_index << ",";
		out << "\"base_source_zone_id\":" << attempt.base_source_zone_id << ",";
		out << "\"direction_byte_offset\":" << attempt.direction_byte_offset << ",";
		out << "\"direction_table_index\":" << attempt.direction_table_index << ",";
		out << "\"base_x\":" << attempt.base_x << ",";
		out << "\"base_y\":" << attempt.base_y << ",";
		out << "\"base_level\":" << attempt.base_level << ",";
		out << "\"base_radius\":" << attempt.base_radius << ",";
		out << "\"candidate_x\":" << attempt.candidate_x << ",";
		out << "\"candidate_y\":" << attempt.candidate_y << ",";
		out << "\"candidate_level\":" << attempt.candidate_level << ",";
		out << "\"accepted\":" << (attempt.accepted ? "true" : "false") << ",";
		out << "\"synthetic_runtime_zone_index\":" << attempt.synthetic_runtime_zone_index << ",";
		out << "\"status\":\"" << json_escape(attempt.status) << "\"";
		out << "}";
	}
	out << "]";
}

void append_source_node_footprint_summary_json(std::ostream &out, const SourceNodeFootprintSummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_source_node_footprint_summary_v1\",\n";
	out << "    \"phase_id\": \"zone_footprint_source_nodes\",\n";
	out << "    \"h3maped_anchor\": \"0x4a3a03\",\n";
	out << "    \"polygon_constructor_anchor\": \"0x4cc788\",\n";
	out << "    \"polygon_node_constructor_anchor\": \"0x4cc955\",\n";
	out << "    \"polygon_split_anchor\": \"0x4ccb64\",\n";
	out << "    \"polygon_finalize_anchor\": \"0x4ccdfc\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"strict_port_scope\": \"source-node rectangle, split insertion, crossing cleanup, and finalized source-node cycles only; no boundary/span fill, terrain, map cells, or public output\",\n";
	out << "    \"source\": \"h3maped 0x4a3a03 small-land source-node setup through 0x4cc788, 0x4cc955, 0x4ccb64, and 0x4ccdfc over the coordinate replay output after any 0x4a3b48/0x49b452 same-level synthetic runtime-zone append\",\n";
	out << "    \"coordinate_replay_available\": " << (summary.coordinate_replay_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"source_node_construction_ported_plain_cpp\": " << (summary.source_nodes_built ? "true" : "false") << ",\n";
	out << "    \"materializes_private_zone_cell_buffer\": false,\n";
	out << "    \"materializes_boundary_trace\": false,\n";
	out << "    \"materializes_span_fill\": false,\n";
	out << "    \"materializes_terrain\": false,\n";
	out << "    \"materializes_map_cells\": false,\n";
	out << "    \"materializes_public_output\": false,\n";
	out << "    \"generator_mode_0x10b8_source\": \"0x49ecf2 writes generator+0x10b8 from constructor arg8 ([EBP+0x24]); 0x4adfe1 supplies that arg from RMG setup object+0x44; 0x4adf88 initializes setup+0x44 to 3, then 0x4602c1 overwrites stack setup [EBP-0x80]+0x44 from [EDI+0xac]+0x10 before calling 0x4adfe1; 0x4a3a9d tests level_index == 1 || generator+0x10b8 != 0\",\n";
	out << "    \"rmg_setup_object_0x44_known\": " << (summary.generator_mode.setup_object_0x44_known ? "true" : "false") << ",\n";
	if (summary.generator_mode.setup_object_0x44_known) {
		out << "    \"rmg_setup_object_0x44\": " << summary.generator_mode.setup_object_0x44 << ",\n";
	} else {
		out << "    \"rmg_setup_object_0x44\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "    \"generator_mode_0x10b8_known\": " << (summary.generator_mode_0x10b8_known ? "true" : "false") << ",\n";
	if (summary.generator_mode_0x10b8_known) {
		out << "    \"generator_mode_0x10b8\": " << summary.generator_mode_0x10b8 << ",\n";
	} else {
		out << "    \"generator_mode_0x10b8\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "    \"generator_mode_0x10b8_status\": \"" << json_escape(generator_mode_status_label(summary.generator_mode)) << "\",\n";
	out << "    \"generator_mode_randomized_from_setup_value_3\": " << (summary.generator_mode.randomized_from_setup_value_3 ? "true" : "false") << ",\n";
	if (summary.generator_mode.randomized_from_setup_value_3) {
		out << "    \"generator_mode_randomization_rng_value_0x4e7276\": " << summary.generator_mode.randomization_rng_value << ",\n";
	} else {
		out << "    \"generator_mode_randomization_rng_value_0x4e7276\": null,\n";
	}
	out << "    \"generator_mode_rng_state_after_0x49ecf2_uint32\": " << summary.generator_mode.rng_state_after_0x49ecf2 << ",\n";
	out << "    \"template_preselection_rng_call_count\": " << summary.generator_mode.pre_template_rng_call_count << ",\n";
	if (summary.generator_mode_0x10b8_known) {
		out << "    \"synthetic_fallback_zone_allowed_by_0x4a3a9d\": " << (summary.synthetic_branch_allowed ? "true" : "false") << ",\n";
	} else {
		out << "    \"synthetic_fallback_zone_allowed_by_0x4a3a9d\": \"unknown_until_generator_0x10b8_rmg_setup_object_0x44_is_captured\",\n";
	}
	out << "    \"same_level_synthetic_runtime_zone_append_ported_plain_cpp\": " << (summary.synthetic_append.ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"same_level_synthetic_runtime_zone_append_status\": \"" << json_escape(summary.synthetic_append.status) << "\",\n";
	out << "    \"same_level_synthetic_runtime_zone_append_blocked_reason\": \"" << json_escape(summary.synthetic_append.blocked_reason) << "\",\n";
	out << "    \"same_level_synthetic_runtime_zone_initial_count\": " << summary.synthetic_append.initial_runtime_zone_count << ",\n";
	out << "    \"appended_synthetic_runtime_zone_count\": " << summary.synthetic_append.accepted_count << ",\n";
	out << "    \"runtime_zone_count_after_synthetic_append\": " << summary.synthetic_append.runtime_zone_count_after_append << ",\n";
	out << "    \"synthetic_runtime_zone_scan_attempt_count\": " << summary.synthetic_append.scan_attempt_count << ",\n";
	out << "    \"synthetic_runtime_zone_rejected_count\": " << summary.synthetic_append.rejected_count << ",\n";
	out << "    \"appended_synthetic_runtime_zone_count_authority\": \"native_materialized_plain_cpp_0x4a3b48_0x49b452_replay_count; H3MapEd same-run compare still required before checkpoint-2 parity is complete\",\n";
	out << "    \"synthetic_runtime_zone_scan_attempts\": ";
	append_synthetic_runtime_zone_attempts_json(out, summary.synthetic_append.attempts);
	out << ",\n";
	out << "    \"runtime_zone_records_after_synthetic_append\": ";
	append_plain_runtime_records_json(out, summary.runtime_zones_after_synthetic_append, true);
	out << ",\n";
	out << "    \"initial_bounds_min_x\": -200,\n";
	out << "    \"initial_bounds_min_y\": -200,\n";
	out << "    \"initial_bounds_max_x\": 400,\n";
	out << "    \"initial_bounds_max_y\": 400,\n";
	out << "    \"initial_node_pair_count\": 5,\n";
	out << "    \"total_matching_runtime_zones\": " << summary.total_matching_runtime_zones << ",\n";
	out << "    \"total_polygon_split_calls\": " << summary.source.executed_split_count << ",\n";
	out << "    \"duplicate_skip_count\": " << summary.source.duplicate_skip_count << ",\n";
	out << "    \"edge_removal_branch_count\": " << summary.source.edge_removal_count << ",\n";
	out << "    \"pre_crossing_inserted_node_pair_count\": " << summary.source.inserted_node_pair_count << ",\n";
	out << "    \"pre_crossing_inserted_bridge_pair_count\": " << summary.source.inserted_bridge_pair_count << ",\n";
	out << "    \"crossing_cleanup_scan_count\": " << summary.source.crossing_scan_count << ",\n";
	out << "    \"crossing_test_count\": " << summary.source.crossing_test_count << ",\n";
	out << "    \"crossing_collapse_count\": " << summary.source.crossing_collapse_count << ",\n";
	out << "    \"post_crossing_cleanup_allocated_node_pair_count\": " << summary.source.allocated_node_pair_count << ",\n";
	out << "    \"post_crossing_cleanup_active_node_pair_count\": " << summary.source.active_node_pair_count << ",\n";
	out << "    \"finalized_triplet_count\": " << summary.source.finalized_triplet_count << ",\n";
	out << "    \"finalized_node_count\": " << summary.source.finalized_node_count << ",\n";
	out << "    \"active_payload_node_count\": " << summary.source.active_payload_node_count << ",\n";
	out << "    \"source_node_walk_count\": " << summary.source.source_node_walk_count << ",\n";
	out << "    \"source_node_walk_guard_exhausted_count\": " << summary.source.source_node_walk_guard_exhausted_count << ",\n";
	out << "    \"split_steps\": ";
	append_source_split_steps_json(out, summary.source.split_steps);
	out << ",\n";
	out << "    \"source_node_walk_previews\": ";
	append_source_walks_json(out, summary.source.walks);
	out << ",\n";
	out << "    \"blocked_next\": \"rerun_same_run_pre_0x4a4c8e_generated_cell_compare_after_synthetic_runtime_zone_append\"\n";
	out << "  }";
}

void append_zone_span_fill_summaries_json(std::ostream &out, const std::vector<ZoneSpanFillSummaryPlain> &zone_fills) {
	out << "[";
	for (size_t index = 0; index < zone_fills.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const ZoneSpanFillSummaryPlain &zone = zone_fills[index];
		out << "{";
		out << "\"runtime_zone_index\":" << zone.runtime_zone_index << ",";
		out << "\"source_zone_id\":" << zone.source_zone_id << ",";
		out << "\"zone_word_id\":" << zone.zone_word_id << ",";
		out << "\"status\":\"" << json_escape(zone.status) << "\",";
		out << "\"seed_relocation_status\":\"" << json_escape(zone.seed_relocation_status) << "\",";
		out << "\"seed_x\":" << zone.seed_x << ",";
		out << "\"seed_y\":" << zone.seed_y << ",";
		out << "\"seed_level\":" << zone.seed_level << ",";
		out << "\"effective_seed_x\":" << zone.effective_seed_x << ",";
		out << "\"effective_seed_y\":" << zone.effective_seed_y << ",";
		out << "\"effective_seed_level\":" << zone.effective_seed_level << ",";
		out << "\"seed_relocated\":" << (zone.seed_relocated ? "true" : "false") << ",";
		out << "\"seed_in_bounds\":" << (zone.seed_in_bounds ? "true" : "false") << ",";
		out << "\"seed_unassigned_before_fill\":" << (zone.seed_unassigned_before_fill ? "true" : "false") << ",";
		out << "\"filled_cell_count\":" << zone.filled_cell_count << ",";
		out << "\"unique_filled_cell_count\":" << zone.unique_filled_cell_count << ",";
		out << "\"pushed_span_count\":" << zone.pushed_span_count << ",";
		out << "\"popped_span_count\":" << zone.popped_span_count << ",";
		out << "\"max_pending_span_count\":" << zone.max_pending_span_count << ",";
		out << "\"out_of_bounds_span_count\":" << zone.out_of_bounds_span_count << ",";
		out << "\"blocked_initial_span_count\":" << zone.blocked_initial_span_count;
		out << "}";
	}
	out << "]";
}

void append_cells_by_zone_word_json(std::ostream &out, const std::map<int32_t, int32_t> &cells_by_zone_word) {
	out << "[";
	size_t index = 0;
	for (const auto &item : cells_by_zone_word) {
		if (index != 0) {
			out << ",";
		}
		out << "{";
		out << "\"zone_word_id\":" << item.first << ",";
		out << "\"cell_count\":" << item.second;
		out << "}";
		++index;
	}
	out << "]";
}

void append_int_histogram_json(std::ostream &out, const std::map<int32_t, int32_t> &histogram) {
	out << "{";
	size_t index = 0;
	for (const auto &item : histogram) {
		if (index != 0) {
			out << ",";
		}
		out << "\"" << item.first << "\": " << item.second;
		++index;
	}
	out << "}";
}

void append_boundary_span_fill_summary_json(std::ostream &out, const BoundarySpanFillSummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_boundary_span_fill_summary_v1\",\n";
	out << "    \"phase_id\": \"zone_boundary_and_span_fill\",\n";
	out << "    \"h3maped_anchor\": \"0x4a2777\",\n";
	out << "    \"clip_helper_anchor\": \"0x4a2b33\",\n";
	out << "    \"deterministic_line_writer_anchor\": \"0x4a261a\",\n";
	out << "    \"randomized_line_writer_anchor\": \"0x4a2413\",\n";
	out << "    \"span_fill_anchor\": \"0x4a325d\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered h3maped 0x4a2777 source-node boundary traversal and 0x4a325d span fill over the currently materialized source-node walks\",\n";
	out << "    \"strict_port_scope\": \"private zone-word and reserved-flag cell buffer only; no terrain repaint, generated-cell live feedback, object vectors, package adoption, or public map output\",\n";
	out << "    \"coordinate_replay_available\": " << (summary.coordinate_replay_available ? "true" : "false") << ",\n";
	out << "    \"source_node_walks_available\": " << (summary.source_node_walks_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"boundary_span_fill_materialized_plain_cpp\": " << (summary.boundary_span_fill_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"materializes_private_zone_cell_buffer\": " << (summary.private_zone_cell_buffer_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_private_generated_cell_owner_words\": " << (summary.generated_cell_owner_words_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_boundary_trace\": " << (summary.boundary_span_fill_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"materializes_span_fill\": " << (summary.boundary_span_fill_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"materializes_terrain\": false,\n";
	out << "    \"materializes_map_cells\": false,\n";
	out << "    \"materializes_public_output\": false,\n";
	out << "    \"same_level_synthetic_runtime_zone_append_ported\": " << (summary.same_level_synthetic_runtime_zone_append_ported ? "true" : "false") << ",\n";
	out << "    \"same_level_synthetic_runtime_zone_branch_allowed\": " << (summary.same_level_synthetic_runtime_zone_branch_allowed ? "true" : "false") << ",\n";
	out << "    \"same_level_synthetic_runtime_zone_count\": " << summary.same_level_synthetic_runtime_zone_count << ",\n";
	out << "    \"runtime_zone_count_after_synthetic_append\": " << summary.runtime_zone_count_after_synthetic_append << ",\n";
	out << "    \"same_level_synthetic_runtime_zone_blocker\": \"" << (summary.same_level_synthetic_runtime_zone_append_ported
			? "append_replay_materialized_in_plain_cpp; rerun_same_run_pre_0x4a4c8e_generated_cell_compare_before_claiming_checkpoint_parity"
			: "generator+0x10b8 must be resolved from same-run RMG setup object +0x44 before 0x4a3b48 direction scan and 0x49b452 append replay can be compared") << "\",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"h3maped_water_mode_code\": " << summary.water_code << ",\n";
	out << "    \"rng_state_before_0x4a2777_uint32\": " << summary.rng_state_before_0x4a2777 << ",\n";
	out << "    \"rng_state_after_0x4a2777_uint32\": " << summary.rng_state_after_0x4a2777 << ",\n";
	out << "    \"boundary_runtime_zone_walk_count\": " << summary.boundary_runtime_zone_walk_count << ",\n";
	out << "    \"boundary_blocked_zone_count\": " << summary.boundary_blocked_zone_count << ",\n";
	out << "    \"boundary_fallback_zone_count\": " << summary.boundary_fallback_zone_count << ",\n";
	out << "    \"boundary_connector_segment_count\": " << summary.boundary_connector_segment_count << ",\n";
	out << "    \"boundary_wrap_segment_count\": " << summary.boundary_wrap_segment_count << ",\n";
	out << "    \"boundary_final_segment_count\": " << summary.boundary_final_segment_count << ",\n";
	out << "    \"boundary_appended_vertex_count\": " << summary.boundary_appended_vertex_count << ",\n";
	out << "    \"boundary_skipped_unfinalized_node_count\": " << summary.boundary_skipped_unfinalized_node_count << ",\n";
	out << "    \"boundary_skipped_out_of_bounds_clip_count\": " << summary.boundary_skipped_out_of_bounds_clip_count << ",\n";
	out << "    \"boundary_owner_gate_skipped_segment_count\": " << summary.boundary_owner_gate_skipped_segment_count << ",\n";
	out << "    \"boundary_flagged_writer_segment_count\": " << summary.boundary_flagged_writer_segment_count << ",\n";
	out << "    \"boundary_deterministic_writer_segment_count\": " << summary.boundary_deterministic_writer_segment_count << ",\n";
	out << "    \"boundary_randomized_rng_call_count\": " << summary.boundary_randomized_rng_call_count << ",\n";
	out << "    \"boundary_randomized_inserted_midpoint_count\": " << summary.boundary_randomized_inserted_midpoint_count << ",\n";
	out << "    \"boundary_randomized_max_pending_point_count\": " << summary.boundary_randomized_max_pending_point_count << ",\n";
	out << "    \"boundary_trace_write_count\": " << summary.boundary_trace_write_count << ",\n";
	out << "    \"boundary_unique_cell_count\": " << summary.boundary_unique_cell_count << ",\n";
	out << "    \"boundary_out_of_bounds_write_count\": " << summary.boundary_out_of_bounds_write_count << ",\n";
	out << "    \"boundary_loop_guard_exhausted\": " << (summary.boundary_loop_guard_exhausted ? "true" : "false") << ",\n";
	out << "    \"span_fill_attempt_count\": " << summary.span_fill_attempt_count << ",\n";
	out << "    \"span_fill_filled_zone_count\": " << summary.span_fill_filled_zone_count << ",\n";
	out << "    \"span_fill_seed_blocked_count\": " << summary.span_fill_seed_blocked_count << ",\n";
	out << "    \"span_fill_seed_relocated_count\": " << summary.span_fill_seed_relocated_count << ",\n";
	out << "    \"span_fill_unique_filled_cell_count\": " << summary.span_fill_unique_filled_cell_count << ",\n";
	out << "    \"span_fill_boundary_or_filled_cell_count\": " << summary.span_fill_boundary_or_filled_cell_count << ",\n";
	out << "    \"span_fill_remaining_unassigned_cell_count\": " << summary.span_fill_remaining_unassigned_cell_count << ",\n";
	out << "    \"generated_cell_word_0x20_owner_byte_materialized_count\": " << summary.generated_cell_word_0x20_owner_byte_materialized_count << ",\n";
	out << "    \"generated_cell_word_0x20_unassigned_sentinel_count\": " << summary.generated_cell_word_0x20_unassigned_sentinel_count << ",\n";
	out << "    \"span_fill_pushed_span_count\": " << summary.span_fill_pushed_span_count << ",\n";
	out << "    \"span_fill_popped_span_count\": " << summary.span_fill_popped_span_count << ",\n";
	out << "    \"span_fill_max_pending_span_count\": " << summary.span_fill_max_pending_span_count << ",\n";
	out << "    \"span_fill_out_of_bounds_span_count\": " << summary.span_fill_out_of_bounds_span_count << ",\n";
	out << "    \"span_fill_blocked_initial_span_count\": " << summary.span_fill_blocked_initial_span_count << ",\n";
	out << "    \"cells_by_zone_word\": ";
	append_cells_by_zone_word_json(out, summary.cells_by_zone_word);
	out << ",\n";
	out << "    \"zone_fills\": ";
	append_zone_span_fill_summaries_json(out, summary.zone_fills);
	out << ",\n";
	out << "    \"blocked_next\": \"rerun_same_run_pre_0x4a4c8e_generated_cell_compare_after_synthetic_runtime_zone_append\"\n";
	out << "  }";
}

void append_runtime_zone_summary_json(std::ostream &out, const RuntimeZoneSummary &summary) {
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_runtime_zone_template_summary_v1\",\n";
	out << "    \"phase_id\": \"runtime_zone_records\",\n";
	out << "    \"h3maped_anchor\": \"0x4a218c\",\n";
	out << "    \"initializer_anchor\": \"0x49b452\",\n";
	out << "    \"status\": \"" << (summary.ok ? "active_plain_cpp_template_runtime_zone_summary" : "blocked") << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"template_selection_mode\": \"h3maped_exe_rng_original_catalog\",\n";
	out << "    \"generator_mode_0x10b8_source\": \"0x49ecf2 writes generator+0x10b8 from constructor arg8 ([EBP+0x24]); setup value 3 is randomized through 0x4e7276() % 3 before template selection consumes RNG\",\n";
	out << "    \"rmg_setup_object_0x44_known\": " << (summary.generator_mode.setup_object_0x44_known ? "true" : "false") << ",\n";
	if (summary.generator_mode.setup_object_0x44_known) {
		out << "    \"rmg_setup_object_0x44\": " << summary.generator_mode.setup_object_0x44 << ",\n";
	} else {
		out << "    \"rmg_setup_object_0x44\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "    \"generator_mode_0x10b8_known\": " << (summary.generator_mode.generator_mode_known ? "true" : "false") << ",\n";
	if (summary.generator_mode.generator_mode_known) {
		out << "    \"generator_mode_0x10b8\": " << summary.generator_mode.generator_mode_0x10b8 << ",\n";
	} else {
		out << "    \"generator_mode_0x10b8\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "    \"generator_mode_0x10b8_status\": \"" << json_escape(generator_mode_status_label(summary.generator_mode)) << "\",\n";
	out << "    \"generator_mode_randomized_from_setup_value_3\": " << (summary.generator_mode.randomized_from_setup_value_3 ? "true" : "false") << ",\n";
	if (summary.generator_mode.randomized_from_setup_value_3) {
		out << "    \"generator_mode_randomization_rng_value_0x4e7276\": " << summary.generator_mode.randomization_rng_value << ",\n";
	} else {
		out << "    \"generator_mode_randomization_rng_value_0x4e7276\": null,\n";
	}
	out << "    \"generator_mode_rng_state_after_0x49ecf2_uint32\": " << summary.generator_mode.rng_state_after_0x49ecf2 << ",\n";
	out << "    \"template_preselection_rng_call_count\": " << summary.generator_mode.pre_template_rng_call_count << ",\n";
	out << "    \"accepted_template_count\": " << summary.accepted_template_count << ",\n";
	out << "    \"template_selection_rng_value\": " << summary.template_selection_rng_value << ",\n";
	out << "    \"rng_state_after_selection_uint32\": " << summary.rng_state_after_selection << ",\n";
	out << "    \"selected_vector_index\": " << summary.selected_vector_index << ",\n";
	out << "    \"selected_template\": {\n";
	out << "      \"id\": \"" << json_escape(summary.selected.id) << "\",\n";
	out << "      \"source_catalog_index\": " << summary.selected.catalog_index << ",\n";
	out << "      \"source_name\": \"" << json_escape(summary.selected.name) << "\",\n";
	out << "      \"zone_count\": " << summary.selected.filtered_zone_count << ",\n";
	out << "      \"connection_count\": " << summary.selected.filtered_connection_count << ",\n";
	out << "      \"unfiltered_zone_count\": " << summary.selected.unfiltered_zone_count << ",\n";
	out << "      \"unfiltered_connection_count\": " << summary.selected.unfiltered_connection_count << ",\n";
	out << "      \"human_capable_source_owner_mask\": " << int32_t(summary.selected.human_capable_source_owner_mask) << ",\n";
	out << "      \"player_capable_source_owner_mask\": " << int32_t(summary.selected.player_capable_source_owner_mask) << "\n";
	out << "    },\n";
	out << "    \"mapped_ee4_slots\": ";
	append_int_array_json(out, summary.mapped_slots);
	out << ",\n";
	out << "    \"assignment_source_owner_order\": ";
	append_int_array_json(out, summary.assignment_source_owners);
	out << ",\n";
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = std::numeric_limits<int32_t>::max();
	out << "    \"runtime_zone_records\": [";
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		JsonSpan zone = summary.selected_zone_spans[index];
		const int32_t source_owner = json_int_or(text, zone, "ownership", -2);
		const int32_t actual_owner = source_owner >= 0 && source_owner < int32_t(summary.mapped_slots.size()) ? summary.mapped_slots[size_t(source_owner)] : -1;
		const std::string role = json_string_or(text, zone, "type", "");
		const int32_t source_bucket = json_int_or(text, zone, "bucket", -1);
		const int32_t base_size = json_int_or(text, zone, "base_size", 0);
		const bool is_player_capable_zone = source_bucket == 0 || source_bucket == 1;
		const bool has_assigned_start = is_player_capable_zone && actual_owner >= 0;
		const int32_t min_castles = json_nested_int_or(text, zone, "player_towns", "min_castles", 0);
		if (role == "human_start") {
			if (actual_owner >= 0) {
				++assigned_start_zone_count;
			} else {
				++unassigned_start_zone_count;
			}
		} else if (role == "treasure") {
			++treasure_zone_count;
		}
		minimum_player_castles += min_castles;
		if (base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, base_size);
		}
		out << "{";
		out << "\"runtime_index\":" << index << ",";
		out << "\"source_zone_id\":" << json_int_or(text, zone, "id", int32_t(index + 1)) << ",";
		out << "\"role\":\"" << json_escape(role) << "\",";
		out << "\"source_bucket\":" << source_bucket << ",";
		out << "\"source_owner_index\":" << source_owner << ",";
		out << "\"actual_owner_color\":" << actual_owner << ",";
		out << "\"is_player_capable_zone\":" << (is_player_capable_zone ? "true" : "false") << ",";
		out << "\"has_assigned_start\":" << (has_assigned_start ? "true" : "false") << ",";
		out << "\"runtime_byte_0x3c_inferred\":" << (has_assigned_start ? "true" : "false") << ",";
		out << "\"source_base_size\":" << base_size << ",";
		out << "\"player_min_castles\":" << min_castles << ",";
		out << "\"minimum_wood_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "wood", 0) << ",";
		out << "\"minimum_ore_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "ore", 0) << ",";
		out << "\"minimum_gold_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "gold", 0) << ",";
		out << "\"mine_density_wood\":" << json_nested_int_or(text, zone, "mine_density", "wood", 0) << ",";
		out << "\"mine_density_ore\":" << json_nested_int_or(text, zone, "mine_density", "ore", 0) << ",";
		out << "\"mine_density_gold\":" << json_nested_int_or(text, zone, "mine_density", "gold", 0);
		out << "}";
	}
	out << "],\n";
	if (minimum_source_base_size == std::numeric_limits<int32_t>::max()) {
		minimum_source_base_size = 0;
	}
	out << "    \"runtime_zone_count\": " << summary.selected_zone_spans.size() << ",\n";
	out << "    \"assigned_start_zone_count\": " << assigned_start_zone_count << ",\n";
	out << "    \"unassigned_start_zone_count\": " << unassigned_start_zone_count << ",\n";
	out << "    \"treasure_zone_count\": " << treasure_zone_count << ",\n";
	out << "    \"minimum_player_castles\": " << minimum_player_castles << ",\n";
	out << "    \"minimum_source_base_size\": " << minimum_source_base_size << ",\n";
	out << "    \"materializes_runtime_zone_coordinates\": false,\n";
	out << "    \"materializes_private_generated_cell_owner_words\": false,\n";
	out << "    \"blocked_next\": \"coordinate_replay_and_zone_footprints_0x4a1f3b_then_0x4a325d_owner_materialization\"\n";
	out << "  }";
}

void append_initialized_generated_cell_checkpoint_json(std::ostream &out, const ControlledCase &controlled_case) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t map_height = map_width;
	const int32_t map_level_count = controlled_case.level_count;
	const int64_t cell_count = int64_t(map_width) * int64_t(map_height) * int64_t(map_level_count);
	const bool supported = supported_one_level_land_scope(controlled_case) && map_width > 0 && cell_count >= 0;
	out << "{\n";
	out << "    \"schema_id\": \"h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1\",\n";
	out << "    \"checkpoint_id\": \"plain_cpp_initial_generated_cell_defaults\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x49ecf2_constructor_defaults_before_0x4a325d_owner_write\",\n";
	out << "    \"plain_cpp_stage\": \"constructor_default_words_only_before_runtime_zone_owner_materialization\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? map_width : 0) << ",\n";
	out << "    \"height\": " << (supported ? map_height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? map_level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"cell_dword_index_8\",\n";
	out << "    \"word_0x24_source\": \"cell_dword_index_9\",\n";
	out << "    \"word_0x28_source\": \"cell_dword_index_10\",\n";
	out << "    \"word_0x2c_source\": \"cell_dword_index_11\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2\",\n";
	out << "    \"status\": \"" << (supported ? "available_constructor_defaults_only" : "blocked_unsupported_or_invalid_scope") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"word_0x28_bit22_count\": 0,\n";
	out << "    \"word_0x28_bit25_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit26_count\": 0,\n";
	out << "    \"word_0x28_bit27_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit28_count\": 0,\n";
	out << "    \"word_0x2c_bit0_count\": 0,\n";
	out << "    \"owner_byte2_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"owner_byte3_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_terrain_histogram\": {\"8\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_art_histogram\": {\"21\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x28_top_byte_histogram\": {\"10\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"records\": [";
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			if (flat != 0) {
				out << ",";
			}
			const int32_t level_tile_count = map_width * map_height;
			const int32_t level = int32_t(flat / level_tile_count);
			const int32_t remainder = int32_t(flat % level_tile_count);
			out << "{";
			out << "\"flat\":" << flat << ",";
			out << "\"x\":" << (remainder % map_width) << ",";
			out << "\"y\":" << (remainder / map_width) << ",";
			out << "\"level\":" << level << ",";
			out << "\"word_0x20\":" << WORD_0X20_DEFAULT << ",";
			out << "\"word_0x24\":" << WORD_0X24_DEFAULT << ",";
			out << "\"word_0x28\":" << WORD_0X28_DEFAULT << ",";
			out << "\"owner_byte2_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 16U) << ",";
			out << "\"owner_byte3_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 24U) << ",";
			out << "\"terrain_code\":" << TERRAIN_CODE_DEFAULT;
			out << "}";
		}
	}
	out << "]\n";
	out << "  }";
}

void append_boundary_owner_generated_cell_checkpoint_json(std::ostream &out, const BoundarySpanFillSummary &summary) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int64_t cell_count = int64_t(summary.width) * int64_t(summary.height) * int64_t(summary.level_count);
	const bool supported = summary.generated_cell_owner_words_materialized
			&& summary.width > 0
			&& summary.height > 0
			&& summary.level_count > 0
			&& cell_count >= 0
			&& summary.generated_cell_word_0x20.size() == size_t(cell_count)
			&& summary.generated_cell_word_0x24.size() == size_t(cell_count)
			&& summary.generated_cell_word_0x28.size() == size_t(cell_count)
			&& summary.generated_cell_terrain_code.size() == size_t(cell_count);

	std::map<int32_t, int32_t> owner_byte2_histogram;
	std::map<int32_t, int32_t> owner_byte3_histogram;
	std::map<int32_t, int32_t> word_0x24_terrain_histogram;
	std::map<int32_t, int32_t> word_0x24_art_histogram;
	std::map<int32_t, int32_t> word_0x28_top_byte_histogram;
	std::map<int32_t, int32_t> terrain_code_histogram;
	int32_t word_0x28_bit22_count = 0;
	int32_t word_0x28_bit25_count = 0;
	int32_t word_0x28_bit26_count = 0;
	int32_t word_0x28_bit27_count = 0;
	int32_t word_0x28_bit28_count = 0;
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			const uint32_t word_0x20 = summary.generated_cell_word_0x20[size_t(flat)];
			const uint32_t word_0x24 = summary.generated_cell_word_0x24[size_t(flat)];
			const uint32_t word_0x28 = summary.generated_cell_word_0x28[size_t(flat)];
			owner_byte2_histogram[i8_from_u32_byte(word_0x20, 16U)] += 1;
			owner_byte3_histogram[i8_from_u32_byte(word_0x20, 24U)] += 1;
			word_0x24_terrain_histogram[int32_t(word_0x24 & 0x3fU)] += 1;
			word_0x24_art_histogram[int32_t((word_0x24 >> 6U) & 0xffU)] += 1;
			word_0x28_top_byte_histogram[int32_t((word_0x28 >> 24U) & 0xffU)] += 1;
			terrain_code_histogram[summary.generated_cell_terrain_code[size_t(flat)]] += 1;
			word_0x28_bit22_count += (word_0x28 & (1U << 22U)) != 0U ? 1 : 0;
			word_0x28_bit25_count += (word_0x28 & (1U << 25U)) != 0U ? 1 : 0;
			word_0x28_bit26_count += (word_0x28 & (1U << 26U)) != 0U ? 1 : 0;
			word_0x28_bit27_count += (word_0x28 & (1U << 27U)) != 0U ? 1 : 0;
			word_0x28_bit28_count += (word_0x28 & (1U << 28U)) != 0U ? 1 : 0;
		}
	}

	out << "{\n";
	out << "    \"schema_id\": \"h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1\",\n";
	out << "    \"checkpoint_id\": \"after_boundary_span_fill_owner_words\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x4a2777_0x4a325d_owner_words_before_terrain_live_feedback_and_0x4a4c8e\",\n";
	out << "    \"plain_cpp_stage\": \"after_boundary_span_fill_owner_byte2_materialization_before_terrain_live_feedback\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? summary.width : 0) << ",\n";
	out << "    \"height\": " << (supported ? summary.height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? summary.level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"constructor_default_0xffff7fbc_with_byte2_replaced_by_0x4a2777_0x4a325d_zone_word\",\n";
	out << "    \"word_0x24_source\": \"constructor_default_0x00000548; terrain live feedback not yet ported in this checkpoint\",\n";
	out << "    \"word_0x28_source\": \"constructor_default_bit25_bit27; later terrain/generated-cell mutations not yet ported in this checkpoint\",\n";
	out << "    \"word_0x2c_source\": \"not_recorded_for_this_owner_materialization_checkpoint\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2 after 0x4a325d owner materialization\",\n";
	out << "    \"status\": \"" << (supported ? "available_plain_cpp_boundary_span_fill_owner_words" : "blocked_boundary_span_fill_owner_words_unavailable") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"word_0x20_owner_byte_materialized_count\": " << (supported ? summary.generated_cell_word_0x20_owner_byte_materialized_count : 0) << ",\n";
	out << "    \"word_0x20_unassigned_sentinel_count\": " << (supported ? summary.generated_cell_word_0x20_unassigned_sentinel_count : 0) << ",\n";
	out << "    \"word_0x28_bit22_count\": " << word_0x28_bit22_count << ",\n";
	out << "    \"word_0x28_bit25_count\": " << word_0x28_bit25_count << ",\n";
	out << "    \"word_0x28_bit26_count\": " << word_0x28_bit26_count << ",\n";
	out << "    \"word_0x28_bit27_count\": " << word_0x28_bit27_count << ",\n";
	out << "    \"word_0x28_bit28_count\": " << word_0x28_bit28_count << ",\n";
	out << "    \"word_0x2c_bit0_count\": 0,\n";
	out << "    \"owner_byte2_signed_histogram\": ";
	append_int_histogram_json(out, owner_byte2_histogram);
	out << ",\n";
	out << "    \"owner_byte3_signed_histogram\": ";
	append_int_histogram_json(out, owner_byte3_histogram);
	out << ",\n";
	out << "    \"word_0x24_terrain_histogram\": ";
	append_int_histogram_json(out, word_0x24_terrain_histogram);
	out << ",\n";
	out << "    \"word_0x24_art_histogram\": ";
	append_int_histogram_json(out, word_0x24_art_histogram);
	out << ",\n";
	out << "    \"word_0x28_top_byte_histogram\": ";
	append_int_histogram_json(out, word_0x28_top_byte_histogram);
	out << ",\n";
	out << "    \"terrain_code_histogram\": ";
	append_int_histogram_json(out, terrain_code_histogram);
	out << ",\n";
	out << "    \"records\": [";
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			if (flat != 0) {
				out << ",";
			}
			const int32_t level_tile_count = summary.width * summary.height;
			const int32_t level = int32_t(flat / level_tile_count);
			const int32_t remainder = int32_t(flat % level_tile_count);
			const uint32_t word_0x20 = summary.generated_cell_word_0x20[size_t(flat)];
			const uint32_t word_0x24 = summary.generated_cell_word_0x24[size_t(flat)];
			const uint32_t word_0x28 = summary.generated_cell_word_0x28[size_t(flat)];
			out << "{";
			out << "\"flat\":" << flat << ",";
			out << "\"x\":" << (remainder % summary.width) << ",";
			out << "\"y\":" << (remainder / summary.width) << ",";
			out << "\"level\":" << level << ",";
			out << "\"word_0x20\":" << word_0x20 << ",";
			out << "\"word_0x24\":" << word_0x24 << ",";
			out << "\"word_0x28\":" << word_0x28 << ",";
			out << "\"owner_byte2_signed\":" << i8_from_u32_byte(word_0x20, 16U) << ",";
			out << "\"owner_byte3_signed\":" << i8_from_u32_byte(word_0x20, 24U) << ",";
			out << "\"terrain_code\":" << summary.generated_cell_terrain_code[size_t(flat)];
			out << "}";
		}
	}
	out << "]\n";
	out << "  }";
}

} // namespace

ControlledCase parse_controlled_case(const std::string &raw) {
	ControlledCase controlled_case;
	controlled_case.raw = raw;
	const std::vector<std::string> parts = split(raw, ':');
	if (parts.size() < 6) {
		controlled_case.parse_error = "expected id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]";
		return controlled_case;
	}
	controlled_case.id = parts[0];
	controlled_case.size_class = normalize_size_class(parts[1]);
	controlled_case.water_mode = normalize_water_mode(parts[4]);
	if (controlled_case.id.empty()) {
		controlled_case.parse_error = "missing case id";
		return controlled_case;
	}
	if (!parse_i32(parts[2], controlled_case.players) || controlled_case.players < 1) {
		controlled_case.parse_error = "invalid players";
		return controlled_case;
	}
	if (!parse_u32(parts[3], controlled_case.seed)) {
		controlled_case.parse_error = "invalid seed";
		return controlled_case;
	}
	if (!parse_i32(parts[5], controlled_case.level_count) || controlled_case.level_count < 1) {
		controlled_case.parse_error = "invalid level_count";
		return controlled_case;
	}
	controlled_case.human_count = 1;
	controlled_case.computer_count = std::max(0, controlled_case.players - 1);
	if (parts.size() >= 7 && !parts[6].empty() && !parse_i32(parts[6], controlled_case.human_count)) {
		controlled_case.parse_error = "invalid human_count";
		return controlled_case;
	}
	if (parts.size() >= 8 && !parts[7].empty() && !parse_i32(parts[7], controlled_case.computer_count)) {
		controlled_case.parse_error = "invalid computer_count";
		return controlled_case;
	}
	if (controlled_case.human_count < 0 || controlled_case.computer_count < 0) {
		controlled_case.parse_error = "invalid negative player split";
		return controlled_case;
	}
	if (parts.size() >= 9 && !parts[8].empty()) {
		controlled_case.setup_object_0x44_known = parse_i32(parts[8], controlled_case.setup_object_0x44);
		if (!controlled_case.setup_object_0x44_known) {
			controlled_case.parse_error = "invalid setup_object_0x44";
			return controlled_case;
		}
	}
	controlled_case.parse_ok = true;
	return controlled_case;
}

std::vector<std::string> split_case_filter(const std::string &case_filter) {
	std::vector<std::string> filters;
	for (const std::string &part : split(case_filter, ',')) {
		if (!part.empty()) {
			filters.push_back(lower_ascii(part));
		}
	}
	return filters;
}

bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters) {
	if (filters.empty()) {
		return true;
	}
	const std::string id = lower_ascii(controlled_case.id);
	const std::string raw = lower_ascii(controlled_case.raw);
	for (const std::string &filter : filters) {
		if (id == filter || raw.find(filter) != std::string::npos) {
			return true;
		}
	}
	return false;
}

std::string safe_case_filename(const std::string &case_id) {
	std::string out;
	out.reserve(case_id.size());
	for (const unsigned char ch : case_id) {
		if (std::isalnum(ch) != 0 || ch == '-' || ch == '_') {
			out.push_back(static_cast<char>(ch));
		} else {
			out.push_back('_');
		}
	}
	return out.empty() ? "case" : out;
}

std::string case_phase_snapshot_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason) {
	const bool supported = supported_one_level_land_scope(controlled_case);
	const int32_t width = map_width_for_size(controlled_case.size_class);
	const GeneratorModeResolutionPlain generator_mode = resolve_generator_mode_0x49ecf2_plain(controlled_case);
	const bool synthetic_branch_allowed = generator_mode.generator_mode_known && generator_mode.generator_mode_0x10b8 != 0;
	const RuntimeZoneSummary runtime_zone_summary = build_runtime_zone_summary(controlled_case);
	const CoordinateReplaySummary coordinate_replay_summary = build_coordinate_replay_summary(controlled_case, runtime_zone_summary);
	const SourceNodeFootprintSummary source_node_summary = build_source_node_footprint_summary(controlled_case, coordinate_replay_summary);
	const BoundarySpanFillSummary boundary_span_fill_summary = build_boundary_span_fill_summary(controlled_case, coordinate_replay_summary, source_node_summary);
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_phase_snapshot_v2\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"status\": \"" << json_escape(status) << "\",\n";
	out << "  \"blocked_reason\": \"" << json_escape(blocked_reason) << "\",\n";
	out << "  \"case_id\": \"" << json_escape(controlled_case.id) << "\",\n";
	out << "  \"raw_controlled_case\": \"" << json_escape(controlled_case.raw) << "\",\n";
	out << "  \"parse_ok\": " << (controlled_case.parse_ok ? "true" : "false") << ",\n";
	out << "  \"parse_error\": \"" << json_escape(controlled_case.parse_error) << "\",\n";
	out << "  \"normalized_config\": {\n";
	out << "    \"size_class\": \"" << json_escape(controlled_case.size_class) << "\",\n";
	out << "    \"width\": " << width << ",\n";
	out << "    \"height\": " << width << ",\n";
	out << "    \"players\": " << controlled_case.players << ",\n";
	out << "    \"seed\": " << controlled_case.seed << ",\n";
	out << "    \"water_mode\": \"" << json_escape(controlled_case.water_mode) << "\",\n";
	out << "    \"level_count\": " << controlled_case.level_count << ",\n";
	out << "    \"human_count\": " << controlled_case.human_count << ",\n";
	out << "    \"computer_count\": " << controlled_case.computer_count << "\n";
	out << "  },\n";
	out << "  \"supported_one_level_land_scope\": " << (supported ? "true" : "false") << ",\n";
	out << "  \"generation_output_written\": false,\n";
	out << "  \"amap_written\": false,\n";
	out << "  \"phase_checkpoint\": \"native-rmg-private-generated-cell-grid-alignment-10184\",\n";
	out << "  \"plain_cpp_generated_cell_grid_stage\": \"post_0x49ecf2_generator_mode_before_runtime_zone_owner_materialization\",\n";
	out << "  \"generator_mode_0x10b8_source\": \"0x49ecf2 writes generator+0x10b8 from constructor arg8 ([EBP+0x24]); 0x4adfe1 supplies that arg from RMG setup object+0x44; 0x4adf88 initializes setup+0x44 to 3, then 0x4602c1 overwrites stack setup [EBP-0x80]+0x44 from [EDI+0xac]+0x10 before calling 0x4adfe1; 0x4a3a9d tests level_index == 1 || generator+0x10b8 != 0\",\n";
	out << "  \"rmg_setup_object_0x44_known\": " << (generator_mode.setup_object_0x44_known ? "true" : "false") << ",\n";
	if (generator_mode.setup_object_0x44_known) {
		out << "  \"rmg_setup_object_0x44\": " << generator_mode.setup_object_0x44 << ",\n";
	} else {
		out << "  \"rmg_setup_object_0x44\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"generator_mode_0x10b8_known\": " << (generator_mode.generator_mode_known ? "true" : "false") << ",\n";
	if (generator_mode.generator_mode_known) {
		out << "  \"generator_mode_0x10b8\": " << generator_mode.generator_mode_0x10b8 << ",\n";
	} else {
		out << "  \"generator_mode_0x10b8\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"generator_mode_0x10b8_status\": \"" << json_escape(generator_mode_status_label(generator_mode)) << "\",\n";
	out << "  \"generator_mode_randomized_from_setup_value_3\": " << (generator_mode.randomized_from_setup_value_3 ? "true" : "false") << ",\n";
	if (generator_mode.randomized_from_setup_value_3) {
		out << "  \"generator_mode_randomization_rng_value_0x4e7276\": " << generator_mode.randomization_rng_value << ",\n";
	} else {
		out << "  \"generator_mode_randomization_rng_value_0x4e7276\": null,\n";
	}
	out << "  \"generator_mode_rng_state_after_0x49ecf2_uint32\": " << generator_mode.rng_state_after_0x49ecf2 << ",\n";
	out << "  \"template_preselection_rng_call_count\": " << generator_mode.pre_template_rng_call_count << ",\n";
	out << "  \"synthetic_branch_condition_0x4a3a9d\": \"level_index == 1 || generator+0x10b8 != 0\",\n";
	if (generator_mode.generator_mode_known) {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": " << (synthetic_branch_allowed ? "true" : "false") << ",\n";
	} else {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": \"unknown_until_generator_0x10b8_rmg_setup_object_0x44_is_captured\",\n";
	}
	out << "  \"private_state_checkpoint_initial_generated_cells\": ";
	append_initialized_generated_cell_checkpoint_json(out, controlled_case);
	out << ",\n";
	out << "  \"private_state_checkpoint_after_boundary_span_fill_owner_words\": ";
	append_boundary_owner_generated_cell_checkpoint_json(out, boundary_span_fill_summary);
	out << ",\n";
	out << "  \"plain_cpp_runtime_zone_template_summary\": ";
	append_runtime_zone_summary_json(out, runtime_zone_summary);
	out << ",\n";
	out << "  \"plain_cpp_link_seed_summary\": ";
	append_link_seed_summary_json(out, coordinate_replay_summary);
	out << ",\n";
	out << "  \"plain_cpp_coordinate_replay_summary\": ";
	append_coordinate_replay_summary_json(out, coordinate_replay_summary);
	out << ",\n";
	out << "  \"plain_cpp_source_node_footprint_summary\": ";
	append_source_node_footprint_summary_json(out, source_node_summary);
	out << ",\n";
	out << "  \"plain_cpp_boundary_span_fill_summary\": ";
	append_boundary_span_fill_summary_json(out, boundary_span_fill_summary);
	out << ",\n";
	out << "  \"next_required_native_core_slice\": \"port_terrain_live_feedback_generated_cell_mutations_after_boundary_owner_words\",\n";
	out << "  \"next_required_alignment_slice\": \"capture_or_default_same_run_setup_0x44_then_compare_pre_0x4a4c8e_after_terrain_live_feedback\"\n";
	out << "}\n";
	return out.str();
}

} // namespace aurelion::rmg_native_core
