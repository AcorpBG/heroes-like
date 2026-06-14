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
#include <set>
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
	bool setup_object_0x44_supplied = false;
	bool setup_object_0x44_defaulted_from_initializer = false;
	int32_t setup_object_0x44 = 0;
	bool generator_mode_known = false;
	int32_t generator_mode_0x10b8 = 0;
	bool randomized_from_setup_value_3 = false;
	int32_t randomization_rng_value = -1;
	uint32_t rng_state_after_0x49ecf2 = 0;
	int32_t pre_template_rng_call_count = 0;
};

constexpr int32_t H3MAPED_DEFAULT_RMG_SETUP_OBJECT_0X44_PLAIN = 3;

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
	bool terrain_match_to_town = false;
	std::vector<int32_t> allowed_h3maped_terrain_ids;
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

struct SourceDescriptorNodePlain {
	int32_t model_node_index = -1;
	int32_t x = 0;
	int32_t y = 0;
	bool has_payload = false;
	int32_t payload = 0;
	int32_t pair_index = -1;
	int32_t next_index = -1;
	int32_t previous_index = -1;
	bool active = false;
	bool finalized = false;
	int32_t finalized_x = -1;
	int32_t finalized_y = -1;
};

struct SourceCycleNodePlain {
	int32_t model_node_index = -1;
	int32_t pair_index = -1;
	int32_t next_index = -1;
	int32_t previous_index = -1;
	int32_t next_pair_index = -1;
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
	int32_t locator_node_index = -1;
	std::string locator_status;
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
	int32_t source_descriptor_node_count = 0;
	int32_t source_descriptor_active_node_count = 0;
	int32_t source_descriptor_finalized_node_count = 0;
	std::vector<SourceSplitStepPlain> split_steps;
	std::vector<SourceDescriptorNodePlain> descriptor_nodes;
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
	std::string seed_descriptor_handoff_status;
	std::string seed_descriptor_source;
	int32_t seed_x = 0;
	int32_t seed_y = 0;
	int32_t seed_level = 0;
	int32_t effective_seed_x = 0;
	int32_t effective_seed_y = 0;
	int32_t effective_seed_level = 0;
	bool seed_relocated = false;
	bool seed_in_bounds = false;
	bool exact_seed_descriptor_handoff_ported = false;
	bool seed_descriptor_proxy_available = false;
	int32_t seed_descriptor_candidate_scan_count = 0;
	int32_t seed_descriptor_candidate_interior_count = 0;
	int32_t seed_descriptor_best_x = -1;
	int32_t seed_descriptor_best_y = -1;
	int32_t seed_descriptor_best_clearance = -1;
	std::string seed_descriptor_clip_branch;
	bool seed_unassigned_before_fill = false;
	int32_t filled_cell_count = 0;
	int32_t unique_filled_cell_count = 0;
	int32_t pushed_span_count = 0;
	int32_t popped_span_count = 0;
	int32_t max_pending_span_count = 0;
	int32_t out_of_bounds_span_count = 0;
	int32_t blocked_initial_span_count = 0;
};

struct BoundaryVectorEventPlain {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t zone_word_id = -1;
	int32_t vector_index = -1;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	std::string event_kind;
	std::string h3maped_anchor;
	std::string native_source;
};

struct BoundarySpanFillSummary {
	bool coordinate_replay_available = false;
	bool source_node_walks_available = false;
	bool supported_scope = false;
	bool boundary_span_fill_materialized_plain_cpp = false;
	bool private_zone_cell_buffer_materialized = false;
	bool boundary_native_vector_trace_materialized = false;
	bool boundary_exact_h3maped_vector_materialized = false;
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
	bool boundary_source_descriptor_handoff_materialized = false;
	int32_t boundary_descriptor_handoff_walk_count = 0;
	int32_t boundary_descriptor_handoff_node_count = 0;
	int32_t boundary_descriptor_handoff_missing_count = 0;
	int32_t boundary_descriptor_handoff_inactive_or_invalid_count = 0;
	int32_t boundary_descriptor_handoff_guard_exhausted_count = 0;
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
	int32_t boundary_vector_event_count = 0;
	int32_t boundary_vector_event_sample_limit = 512;
	bool boundary_vector_event_sample_truncated = false;
	std::map<std::string, int32_t> boundary_vector_events_by_anchor;
	std::map<std::string, int32_t> boundary_vector_events_by_kind;
	std::vector<BoundaryVectorEventPlain> boundary_vector_events;
	int32_t boundary_trace_write_count = 0;
	int32_t boundary_unique_cell_count = 0;
	int32_t boundary_out_of_bounds_write_count = 0;
	bool boundary_loop_guard_exhausted = false;
	int32_t span_fill_attempt_count = 0;
	int32_t span_fill_filled_zone_count = 0;
	int32_t span_fill_seed_blocked_count = 0;
	int32_t span_fill_seed_relocated_count = 0;
	bool span_fill_exact_seed_descriptor_handoff_materialized = false;
	int32_t span_fill_seed_out_of_bounds_count = 0;
	int32_t span_fill_seed_descriptor_handoff_unported_count = 0;
	int32_t span_fill_seed_descriptor_proxy_available_count = 0;
	int32_t span_fill_seed_descriptor_proxy_candidate_scan_count = 0;
	int32_t span_fill_seed_descriptor_proxy_interior_candidate_count = 0;
	int32_t span_fill_seed_descriptor_proxy_relocated_count = 0;
	int32_t span_fill_seed_descriptor_proxy_no_candidate_count = 0;
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
	std::vector<uint32_t> private_zone_words;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<int32_t> generated_cell_terrain_code;
};

struct FilledZoneGeometryPlain {
	int32_t runtime_zone_index = -1;
	int32_t zone_word_id = -1;
	int32_t filled_cell_count = 0;
	bool has_filled_cells = false;
	int32_t filled_rect_min_x_0x20 = 0;
	int32_t filled_rect_min_y_0x24 = 0;
	int32_t filled_rect_max_x_exclusive_0x28 = 0;
	int32_t filled_rect_max_y_exclusive_0x2c = 0;
	int32_t centroid_x_0x10 = 0;
	int32_t centroid_y_0x14 = 0;
	int32_t centroid_level_0x18 = 0;
	int32_t relation_type_0x0c = 0;
};

struct RuntimeTerrainSelectionPlain {
	int32_t runtime_zone_index = -1;
	int32_t level = 0;
	bool terrain_match_to_town = false;
	int32_t town_choice_index = -1;
	std::vector<int32_t> eligible_h3maped_terrain_ids;
	int32_t rng_value = -1;
	int32_t rng_modulus = 0;
	int32_t selected_allowed_ordinal = -1;
	int32_t monster_town_rng_value = -1;
	int32_t selected_monster_table_ordinal_0x49b4e1 = -1;
	bool selected_monster_table_value_materialized = false;
	int32_t selected_h3maped_terrain_id = 0;
	std::string selected_project_terrain_id;
	std::string source;
};

struct RuntimeTerrainSelectionSummaryPlain {
	bool coordinate_replay_available = false;
	bool supported_scope = false;
	bool materializes_runtime_zone_terrain_ids = false;
	std::string status = "blocked_until_coordinate_replay";
	std::string blocked_reason = "coordinate_replay_missing";
	uint32_t rng_state_before_0x49b53d = 0;
	uint32_t rng_state_after_0x49b53d = 0;
	int32_t selection_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t blank_allowed_mask_count = 0;
	int32_t forced_subterranean_count = 0;
	int32_t terrain_rng_call_count = 0;
	int32_t monster_town_rng_call_count_0x49b4e1 = 0;
	std::vector<RuntimeTerrainSelectionPlain> selections;
	std::vector<int32_t> selected_h3maped_terrain_ids;
};

struct TerrainCellWriteoutSummaryPlain {
	bool boundary_owner_words_available = false;
	bool runtime_terrain_selection_available = false;
	bool materializes_private_terrain_cell_buffer = false;
	std::string status = "blocked_until_runtime_terrain_selection";
	std::string blocked_reason = "runtime_terrain_selection_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t cell_count = 0;
	int32_t assigned_owner_cell_count = 0;
	int32_t unassigned_water_cell_count = 0;
	int32_t selected_runtime_zone_count = 0;
	std::map<int32_t, int32_t> owner_low_byte_counts;
	std::map<int32_t, int32_t> terrain_code_counts;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<int32_t> generated_cell_terrain_code;
};

struct TerrainRelationEligibilitySamplePlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t flat_cell_index = 0;
	int32_t relation_index = 0;
	int32_t relation_owner_byte2 = 0;
};

struct TerrainRelationEligibilitySummaryPlain {
	bool boundary_owner_words_available = false;
	bool supported_scope = false;
	bool relation_geometry_materialized_plain_cpp = false;
	bool generated_cell_relation_eligibility_materialized = false;
	std::string status = "blocked_until_boundary_owner_words";
	std::string blocked_reason = "boundary_owner_generated_cell_words_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t cell_count = 0;
	int32_t runtime_zone_count = 0;
	int32_t relation_geometry_record_count_0x4a2105_0x4a2ffa = 0;
	int32_t relation_geometry_filled_record_count_0x4a2105_0x4a2ffa = 0;
	int32_t terrain_relation_eligibility_record_count_0x4a2ec3 = 0;
	int32_t terrain_relation_eligibility_scan_cell_count_0x4a2ec3 = 0;
	int32_t terrain_relation_eligibility_owner_match_count_0x4a2ec3 = 0;
	int32_t terrain_relation_eligibility_bit28_set_count_0x4a2ec3 = 0;
	int32_t terrain_relation_eligibility_relation_type_8_skip_count_0x4a2ec3 = 0;
	std::vector<FilledZoneGeometryPlain> geometry_records;
	std::vector<TerrainRelationEligibilitySamplePlain> samples;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<int32_t> generated_cell_terrain_code;
};

struct TerrainVisualRowPlain {
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
};

struct TerrainClassResultPlain {
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
};

struct TerrainVisualGridTablesPlain {
	std::vector<TerrainVisualRowPlain> dirt_rows;
	std::vector<TerrainVisualRowPlain> sand_rows;
	std::vector<TerrainVisualRowPlain> normal_rows;
	std::vector<TerrainVisualRowPlain> water_rows;
	std::vector<TerrainVisualRowPlain> rock_rows;
};

struct TerrainLiveFeedbackSamplePlain {
	int32_t index = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t terrain_id = 0;
	int32_t shape_class = 0;
	int32_t neighbor_mask = 0;
	std::string source_branch;
	std::string selector_address;
	std::string selector_kind;
	int32_t probability_threshold = -1;
	int32_t probability_rng_value = -1;
	int32_t selected_row = -1;
	uint32_t scratch_word = 0;
	uint32_t generated_cell_word_0x24 = 0;
	uint32_t generated_cell_word_0x28 = 0;
};

struct TerrainLiveFeedbackSeedSamplePlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t terrain_before_drain = 0;
	int32_t current_repaint_terrain = 0;
	std::string source_branch;
};

struct TerrainLiveFeedbackDrainSamplePlain {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t terrain_id = 0;
	std::string source_branch;
	std::string branch;
	int32_t from_x = 0;
	int32_t from_y = 0;
	int32_t target_x = 0;
	int32_t target_y = 0;
	bool changed_terrain = false;
	bool is_retouch = false;
};

struct TerrainLiveFeedbackSummaryPlain {
	bool terrain_relation_eligibility_available = false;
	bool visual_tables_decoded = false;
	bool live_feedback_materialized = false;
	bool materializes_private_generated_cell_words = false;
	std::string status = "blocked_until_terrain_relation_eligibility";
	std::string blocked_reason = "terrain_relation_eligibility_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t cell_count = 0;
	int32_t live_cell_word_0x20_owner_byte_materialized_count = 0;
	int32_t live_cell_word_0x20_unassigned_sentinel_count = 0;
	int32_t terrain_relation_repaint_record_count_0x4a4082 = 0;
	int32_t terrain_relation_repaint_scan_cell_count_0x4a4082 = 0;
	int32_t terrain_relation_repaint_owner_mismatch_count_0x4a4082 = 0;
	int32_t terrain_relation_repaint_bit28_reject_count_0x4a4082 = 0;
	int32_t terrain_relation_repaint_type8_skip_count_0x4a4082 = 0;
	int32_t changed_cell_update_count = 0;
	int32_t live_visual_attempt_count = 0;
	int32_t live_visual_write_count = 0;
	int32_t live_visual_missing_bucket_count = 0;
	int32_t live_initial_water_attempt_count = 0;
	int32_t live_repaint_attempt_count = 0;
	int32_t live_queue_attempt_count = 0;
	int32_t live_dirty_cell_count = 0;
	int32_t live_roundtrip_mismatch_count = 0;
	int32_t live_terrain_mismatch_count = 0;
	int32_t live_full_native_cell_count = 0;
	int32_t live_terrain_art_nonzero_cell_count = 0;
	int32_t live_terrain_flag_cell_count = 0;
	int32_t live_cell_word_0x28_bit25_default_write_count = 0;
	int32_t post_queue_terrain_difference_count = 0;
	int32_t max_set_a_count = 0;
	int32_t max_set_b_count = 0;
	int32_t total_set_a_insert_count = 0;
	int32_t total_set_a_neighbor_remove_count = 0;
	int32_t total_set_b_insert_count = 0;
	int32_t total_set_b_current_remove_count = 0;
	int32_t set_a_drain_count = 0;
	int32_t set_b_drain_count = 0;
	int32_t set_b_candidate_true_count = 0;
	int32_t retouched_cell_write_count = 0;
	int64_t drain_guard_limit = 0;
	bool drain_guard_exhausted = false;
	bool exact_queue_drain_complete = false;
	int32_t final_sweep_cell_count_0x4bbfcc = 0;
	int32_t final_sweep_boundary_cell_count_0x4bbfcc = 0;
	int32_t final_sweep_zero_boundary_cell_count_0x4bbfcc = 0;
	int32_t final_sweep_max_boundary_count_0x4bbfcc = 0;
	int32_t final_sweep_class_correction_count_0x4bbfcc = 0;
	uint32_t rng_state_before_live_visual_selection = 0;
	uint32_t rng_state_after_live_visual_selection = 0;
	std::map<int32_t, int32_t> neighbor_mask_histogram;
	std::map<std::string, int32_t> selector_kind_histogram;
	std::map<int32_t, int32_t> final_sweep_boundary_count_histogram_0x4bbfcc;
	std::map<std::string, int32_t> final_sweep_class_correction_histogram_0x4bbfcc;
	std::vector<TerrainLiveFeedbackSamplePlain> samples;
	std::vector<TerrainLiveFeedbackSeedSamplePlain> seed_samples;
	std::vector<TerrainLiveFeedbackDrainSamplePlain> drain_samples;
	std::vector<FilledZoneGeometryPlain> geometry_records;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<int32_t> generated_cell_terrain_code;
};

struct GeneratedCellBitHelperSummaryPlain {
	bool terrain_live_feedback_available = false;
	bool supported_scope = false;
	bool helper_contracts_ported_plain_cpp = false;
	bool diagnostic_only = true;
	bool live_grid_mutation_adopted = false;
	std::string status = "blocked_until_terrain_live_feedback";
	std::string blocked_reason = "terrain_live_feedback_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t cell_count = 0;
	int32_t valid_0x49a1d8_count = 0;
	int32_t invalid_0x49a1d8_count = 0;
	int32_t invalid_0x49a1d8_bit25_clear_count = 0;
	int32_t invalid_0x49a1d8_terrain9_count = 0;
	int32_t word_0x2c_bit0_lock_count = 0;
	int32_t source_bit26_count = 0;
	int32_t source_bit27_count = 0;
	int32_t terrain_8_9_occupied_scan_count = 0;
	int32_t terrain_8_9_occupied_set_count_0x49a932 = 0;
	int32_t terrain_8_9_0x2c_skip_count = 0;
	int32_t candidate_0x49a962_call_count = 0;
	int32_t candidate_0x49a962_center_set_count = 0;
	int32_t candidate_0x49a962_neighbor_scan_count = 0;
	int32_t candidate_0x49a962_neighbor_bit22_skip_count = 0;
	int32_t candidate_0x49a962_neighbor_invalid_skip_count = 0;
	int32_t candidate_0x49a962_neighbor_terrain8_skip_count = 0;
	int32_t candidate_0x49a962_neighbor_clear_count_0x49a932 = 0;
	int32_t diagnostic_final_bit26_count = 0;
	int32_t diagnostic_final_bit27_count = 0;
};

struct RelationNormalizationResetSamplePlain {
	int32_t flat = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	uint32_t word_0x10 = 0;
	uint32_t word_0x14 = 0;
	uint32_t word_0x18 = 0;
	uint32_t word_0x1c = 0;
	uint32_t word_0x20 = 0;
	uint32_t word_0x28 = 0;
};

struct RelationNormalizationSourceClearSamplePlain {
	int32_t flat = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	uint32_t before_word_0x1c = 0;
	uint32_t after_word_0x1c = 0;
	uint32_t after_word_0x10 = 0;
	uint32_t after_word_0x14 = 0;
	uint32_t after_word_0x18 = 0;
	bool low_word_cleared = false;
	bool high_word_preserved = false;
	bool projection_triple_minus_one = false;
};

struct RelationNormalizationContractSummaryPlain {
	bool terrain_live_feedback_available = false;
	bool supported_scope = false;
	bool relation_normalization_contract_ported_plain_cpp = false;
	bool helper_0x4a59e2_pack_materialized_plain_cpp = false;
	bool full_grid_reset_0x4a5767_materialized_plain_cpp = false;
	bool propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp = false;
	bool propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp = false;
	bool propagation_source_cell_clear_live_application_pending = true;
	bool generated_cell_word_0x1c_reset_gate_materialized = false;
	bool generated_cell_projection_triple_reset_materialized = false;
	bool static_surface_markers_recovered = false;
	bool r6_semantic_surface_recovered = false;
	bool diagnostic_only = true;
	bool native_behavior_changed = false;
	bool used_objdump = false;
	bool runtime_ordered_replay_materialized = false;
	bool generated_cell_word_0x20_low_word_propagation_materialized = false;
	bool generated_cell_word_0x1c_projection_gate_materialized = false;
	bool generated_cell_projection_triple_materialized = false;
	bool object_reference_vector_filter_materialized = false;
	bool descriptor_policy_table_materialized = false;
	bool relation_vector_runtime_order_materialized = false;
	bool generated_cell_mutation_replay_complete = false;
	bool selected_template_vector_profile_available = false;
	bool same_run_h3maped_hc4_seed10_template_vector_validated = false;
	bool selected_candidate_relation_record_profile_available = false;
	bool same_run_h3maped_hc4_seed10_selected_candidate_relation_topology_recorded = false;
	bool flat_template_link_seeds_are_runtime_relation_vector = false;
	bool flat_template_link_seed_surface_matches_selected_candidate_relation_records = false;
	bool selected_candidate_relation_records_are_generator_0x10e4_runtime_vector = false;
	bool generator_0x10e4_relation_pointer_records_materialized = false;
	bool generator_0x10e8_relation_pointer_end_materialized = false;
	std::string status = "blocked_until_terrain_live_feedback";
	std::string blocked_reason = "terrain_live_feedback_missing";
	std::string relation_vector_blocked_reason = "blocked_until_runtime_zone_summary";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t seed = 0;
	int32_t cell_count = 0;
	int32_t selected_template_vector_candidate_count = 0;
	int32_t selected_template_vector_selected_index = -1;
	int32_t selected_template_vector_rng_value = -1;
	uint32_t selected_template_vector_rng_state_after_selection = 0;
	int32_t selected_template_source_catalog_index = -1;
	std::string selected_template_id;
	std::string selected_template_source_name;
	int32_t selected_template_zone_count = 0;
	int32_t selected_template_connection_count = 0;
	int32_t flat_template_link_seed_count = 0;
	int32_t flat_template_link_seed_border_guard_count = 0;
	int32_t selected_candidate_relation_owner_count = 0;
	int32_t selected_candidate_relation_total_record_count = 0;
	int32_t selected_candidate_relation_border_guard_record_count = 0;
	int32_t selected_candidate_relation_record_stride_bytes = 0;
	int32_t template_vs_selected_candidate_relation_record_count_delta = 0;
	int32_t template_vs_selected_candidate_border_guard_record_count_delta = 0;
	std::vector<int32_t> selected_candidate_relation_owner_record_counts;
	std::vector<int32_t> selected_candidate_relation_owner_border_guard_counts;
	int32_t static_marker_count = 50;
	int32_t static_present_marker_count = 50;
	int32_t static_missing_marker_count = 0;
	int32_t normalizer_0x4a5767_marker_count = 21;
	int32_t normalizer_0x4a5767_present_marker_count = 21;
	int32_t normalizer_0x4a5767_reference_marker_count = 3;
	int32_t normalizer_0x4a5767_reference_present_marker_count = 3;
	int32_t propagation_0x49a318_marker_count = 23;
	int32_t propagation_0x49a318_present_marker_count = 23;
	int32_t propagation_0x49a318_reference_marker_count = 3;
	int32_t propagation_0x49a318_reference_present_marker_count = 3;
	int32_t source_bit26_count = 0;
	int32_t source_bit27_count = 0;
	int32_t diagnostic_final_bit26_count = 0;
	int32_t diagnostic_final_bit27_count = 0;
	int32_t reset_cell_count = 0;
	int32_t reset_word_0x1c_0x7d007d00_count = 0;
	int32_t reset_projection_triple_minus_one_count = 0;
	int32_t reset_word_0x20_byte3_minus_one_count = 0;
	int32_t reset_word_0x28_bits_12_14_zero_count = 0;
	int32_t propagation_source_cell_clear_sample_count = 0;
	int32_t propagation_source_cell_clear_low_word_zero_count = 0;
	int32_t propagation_source_cell_clear_high_word_preserved_count = 0;
	int32_t propagation_source_cell_projection_triple_minus_one_sample_count = 0;
	std::vector<uint32_t> reset_word_0x10;
	std::vector<uint32_t> reset_word_0x14;
	std::vector<uint32_t> reset_word_0x18;
	std::vector<uint32_t> reset_word_0x1c;
	std::vector<uint32_t> reset_word_0x20;
	std::vector<uint32_t> reset_word_0x28;
	std::vector<RelationNormalizationResetSamplePlain> reset_samples;
	std::vector<RelationNormalizationSourceClearSamplePlain> source_clear_samples;
	std::string working_name = "relation_local_generated_cell_normalizer_and_owner_projection_propagation";
};

struct RouteBoundaryContractSummaryPlain {
	bool generated_cell_bit_helpers_available = false;
	bool supported_scope = false;
	bool object_vector_prerequisite_available = false;
	bool route_contract_ported_plain_cpp = false;
	bool diagnostic_only = true;
	bool live_grid_mutation_adopted = false;
	bool native_object_vector_order_materialized = false;
	bool same_run_descriptor_state_complete = false;
	bool generated_cell_mutation_replay_complete = false;
	bool projection_write_coordinates_materialized = false;
	bool native_route_rng_boundary_materialized = false;
	bool recovered_reference_case_matches = false;
	std::string status = "blocked_until_generated_cell_bit_helpers";
	std::string blocked_reason = "generated_cell_bit_helpers_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t seed = 0;
	int32_t expected_reference_seed = 58;
	int32_t expected_reference_width = 36;
	int32_t expected_reference_height = 36;
	uint32_t h3maped_route_entry_state_uint32 = 2776862028U;
	int32_t h3maped_route_entry_offset_from_seed = 5002;
	int32_t recovered_route_event_count = 2026;
	int32_t recovered_split_count = 416;
	int32_t recovered_stamp_count = 340;
	int32_t recovered_a80dc_call_count = 52;
	int32_t recovered_far_cut_count = 11;
	int32_t recovered_silent_oob_terminal_count = 88;
	int32_t rng_call_count = 319;
	int32_t rng_unique_remainder_count = 297;
	int32_t rng_ambiguous_remainder_count = 21;
	int32_t rng_no_rng_split_count = 98;
	int32_t source_bit26_count = 0;
	int32_t source_bit27_count = 0;
	int32_t diagnostic_final_bit26_count = 0;
	int32_t diagnostic_final_bit27_count = 0;
};

struct ObjectVectorPrerequisiteContractSummaryPlain {
	bool generated_cell_bit_helpers_available = false;
	bool supported_scope = false;
	bool object_vector_contract_ported_plain_cpp = false;
	bool descriptor_source_identity_closure_ported_plain_cpp = false;
	bool descriptor_source_identity_r4_crosswalk_recovered = false;
	bool descriptor_source_identity_native_behavior_changed = false;
	bool descriptor_plus_0x00_registry_key_not_row_recovered = false;
	bool descriptor_copied_source_record_identity_authority_recovered = false;
	bool object_vector_commit_mutation_helpers_ported_plain_cpp = false;
	bool object_vector_projection_write_helpers_ported_plain_cpp = false;
	bool object_vector_49cf34_attach_mutation_helpers_ported_plain_cpp = false;
	bool object_vector_4a79a3_payload_order_ported_plain_cpp = false;
	bool object_vector_4a79a3_payload_order_records_match_recovered = false;
	bool object_vector_endpoint_dispatch_exclusion_ported_plain_cpp = false;
	bool endpoint_dispatch_4a696b_direct_mutation_excluded_supported_land = false;
	bool endpoint_dispatch_4a7605_delegated_materialization_afterstate_pending = false;
	bool relation_normalization_contract_ported_plain_cpp = false;
	bool relation_normalization_4a59e2_pack_materialized_plain_cpp = false;
	bool relation_normalization_full_grid_reset_materialized_plain_cpp = false;
	bool relation_normalization_source_cell_clear_0x49a318_primitive_materialized = false;
	bool relation_normalization_source_cell_projection_triple_minus_one_primitive_materialized = false;
	bool relation_normalization_source_cell_clear_live_application_pending = true;
	bool relation_normalization_projection_gate_reset_materialized = false;
	bool relation_normalization_projection_triple_reset_materialized = false;
	bool relation_normalization_runtime_replay_pending = false;
	bool relation_normalization_word20_low_word_propagation_pending = false;
	bool relation_normalization_projection_gate_pending = false;
	bool relation_normalization_projection_triple_pending = false;
	bool relation_normalization_object_reference_filter_pending = false;
	bool diagnostic_only = true;
	bool native_object_vector_order_materialized = false;
	bool same_run_descriptor_state_complete = false;
	bool generated_cell_mutation_replay_complete = false;
	bool projection_write_coordinates_materialized = false;
	bool sampled_4a54a7_commit_mutation_samples_match = false;
	bool sampled_4a56b6_projection_write_samples_match = false;
	bool sampled_49cf34_attach_mutation_samples_match = false;
	bool sampled_4a56b6_projection_write_full_stream_materialized = false;
	bool sampled_4a56b6_projection_write_unique_cell_count_matches = false;
	bool sampled_4a56b6_projection_write_ordinals_cover_stream = false;
	bool recovered_reference_case_matches = false;
	std::string status = "blocked_until_generated_cell_bit_helpers";
	std::string blocked_reason = "generated_cell_bit_helpers_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t seed = 0;
	int32_t expected_reference_seed = 58;
	int32_t expected_reference_width = 36;
	int32_t expected_reference_height = 36;
	int32_t seed58_4aa354_call_count = 195;
	int32_t seed58_4aa354_49cf34_call_count = 150;
	int32_t seed58_4aa354_4aa9b7_call_count = 195;
	int32_t seed58_4aa354_4aa3e9_call_count = 14;
	bool seed58_source_stream_has_4aa354_to_49cf34_attach_order = false;
	bool seed58_source_stream_has_4aa9b7_to_4aa3e9_handoff = true;
	bool seed58_source_stream_dumps_generator_descriptor_vector_0x398_0x39c = false;
	bool seed58_source_stream_dumps_selected_descriptor_state_0x94_0x95 = false;
	bool object_vector_static_contract_recovered = true;
	bool object_vector_producer_surface_recovered = true;
	bool object_vector_cleanup_surfaces_recovered = true;
	bool object_vector_phase_consumer_surface_recovered = true;
	int32_t sampled_4a54a7_commit_mutation_sample_count = 0;
	int32_t sampled_4a54a7_endpoint_clear_sample_count = 0;
	int32_t sampled_4aa3e9_reward_lower_sample_count = 0;
	int32_t sampled_4aa3e9_projection_write_count = 90;
	int32_t sampled_4aa3e9_projection_write_unique_cell_count = 90;
	int32_t sampled_4a56b6_projection_write_sample_count = 0;
	int32_t sampled_4a56b6_projection_write_matched_sample_count = 0;
	int32_t sampled_4a56b6_projection_write_unique_cell_count = 0;
	int32_t sampled_4a56b6_projection_write_ordinal_min = 0;
	int32_t sampled_4a56b6_projection_write_ordinal_max = 0;
	int32_t sampled_49cf34_attach_write_pair_count = 17;
	int32_t sampled_49cf34_attach_matched_write_pair_count = 0;
	int32_t sampled_49cf34_attach_primary_write_pair_count = 0;
	int32_t sampled_49cf34_attach_neighbor_write_pair_count = 0;
	int32_t sampled_49cf34_attach_unique_cell_count = 0;
	int32_t sampled_49cf34_attach_changed_write_pair_count = 0;
	int32_t sampled_49cf34_attach_clears_bit26_count = 0;
	int32_t sampled_49cf34_attach_sets_bit27_from_clear_count = 0;
	int32_t sampled_4a79a3_initial_object_vector_count = 7;
	int32_t sampled_4a79a3_positive_append_count = 6;
	int32_t sampled_4a79a3_final_object_vector_count = 13;
	int32_t sampled_4a79a3_payload_loop_count = 19;
	int32_t sampled_4a79a3_later_49eb8d_handoff_count = 107;
	int32_t sampled_4a79a3_payload_record_count = 0;
	int32_t sampled_4a79a3_payload_vtable_0x00540a9c_count = 0;
	int32_t sampled_4a79a3_payload_vtable_0x00540a88_count = 0;
	bool sampled_4a79a3_filter_hits_4a696b = true;
	bool sampled_4a79a3_filter_hits_4a7605 = true;
	int32_t sampled_endpoint_dispatch_4a696b_entry_count = 0;
	int32_t sampled_endpoint_dispatch_4a7605_entry_count = 0;
	int32_t sampled_endpoint_dispatch_4a696b_source_relation_match_hits = 0;
	int32_t sampled_endpoint_dispatch_4a696b_direct_mutation_hits = 0;
	int32_t sampled_endpoint_dispatch_4a7605_endpoint_policy_count = 0;
};

struct DescriptorSourceIdentityContextPlain {
	std::string return_address;
	int32_t descriptor_type = 0;
	std::string label;
	int32_t selected_sample_count = 0;
	int32_t joined_sample_count = 0;
	bool all_selected_samples_joined = false;
	int32_t unique_descriptor_identity_tuple_count = 0;
	int32_t unique_catalog_type_subtype_resolution_count = 0;
	int32_t ambiguous_catalog_type_subtype_resolution_count = 0;
	int32_t missing_catalog_type_subtype_resolution_count = 0;
	int32_t row_mode_sample_count = 0;
	int32_t row_mode_match_count = 0;
	int32_t row_mode_mismatch_count = 0;
	int32_t row_mode_missing_count = 0;
	std::string identity_authority;
};

struct DescriptorSourceIdentityClosureSummaryPlain {
	bool supported_scope = false;
	bool diagnostic_only = true;
	bool native_behavior_changed = false;
	bool used_objdump = false;
	bool descriptor_source_identity_closure_ported_plain_cpp = false;
	bool r4_descriptor_source_identity_crosswalk_recovered = false;
	bool same_run_selected_descriptor_pointer_join_recovered = false;
	bool all_target_mixed_selected_descriptors_joined = false;
	bool descriptor_input_type_subtype_class_fields_recovered = false;
	bool descriptor_only_identity_not_claimed_for_ambiguous_mines = false;
	bool descriptor_plus_0x00_registry_key_not_row_recovered = false;
	bool object_table_loader_source_row_shape_recovered = false;
	bool provider_mapping_covers_target_source_lanes_53_54_79 = false;
	bool source_catalog_template_producer_recovered = false;
	bool source_record_cache_key_preserves_def_name_fields = false;
	bool type45_base_loader_special_case_recovered = false;
	bool copied_source_record_identity_authority_required = false;
	bool same_run_descriptor_state_complete = false;
	std::string status = "blocked_until_supported_scope";
	std::string blocked_reason = "unsupported_non_small_medium_one_level_land";
	int32_t selected_descriptor_count = 433;
	int32_t target_mixed_selected_descriptor_count = 87;
	int32_t target_mixed_joined_descriptor_count = 87;
	int32_t target_mixed_missing_join_count = 0;
	int32_t build_event_count = 2671;
	int32_t unique_built_descriptor_count = 2671;
	int32_t provider_slot_pair_count = 27;
	int32_t source_record_copy_size_bytes = 76;
	int32_t fixed_score_before = 89;
	int32_t fixed_score_after = 92;
	int32_t remaining_fixed_budget_after = 8;
	std::string active_blocker_after = "R5";
	std::vector<DescriptorSourceIdentityContextPlain> contexts;
};

struct ObjectVectorPayloadOrderRecordPlain {
	int32_t event_index = 0;
	std::string record_pointer;
	std::string record_vtable;
	std::string descriptor_pointer;
	std::string descriptor_source_pointer;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t field_0x1c = 0;
	int32_t field_0x20 = 0;
	uint32_t field_0x24 = 0;
	uint32_t field_0x28 = 0;
	uint32_t field_0x2c = 0;
	std::array<uint32_t, 12> record_words = {};
};

struct ObjectVectorPayloadOrderSummaryPlain {
	bool supported_scope = false;
	bool diagnostic_only = true;
	bool native_behavior_changed = false;
	bool object_vector_4a79a3_payload_order_ported_plain_cpp = false;
	bool vector_entries_match_record_pointers = false;
	bool record_payloads_dumped = false;
	bool descriptor_wrappers_dumped = false;
	bool payload_order_records_match_recovered = false;
	bool native_object_vector_order_materialized = false;
	bool generated_cell_mutation_replay_complete = false;
	bool projection_write_coordinates_materialized = false;
	std::string status = "blocked_until_supported_scope";
	std::string blocked_reason = "unsupported_non_small_medium_one_level_land";
	int32_t record_count = 0;
	int32_t shifted_count_at_0x4a7d99 = 0;
	int32_t vector_entry_count = 0;
	int32_t record_vtable_0x00540a9c_count = 0;
	int32_t record_vtable_0x00540a88_count = 0;
	std::vector<std::string> vector_entries;
	std::vector<ObjectVectorPayloadOrderRecordPlain> records;
};

struct ObjectVectorEndpointDispatchSummaryPlain {
	bool supported_scope = false;
	bool diagnostic_only = true;
	bool native_behavior_changed = false;
	bool endpoint_dispatch_contract_ported_plain_cpp = false;
	bool filter_dispatch_summary_recovered = false;
	bool static_4a696b_direct_mutation_surface_recovered = false;
	bool static_4a7605_fallback_coordinator_surface_recovered = false;
	bool target_mode_4a696b_direct_mutation_excluded_supported_land = false;
	bool multi_seed_4a696b_pair_gate_recovered = false;
	bool live_4a696b_direct_mutation_sites_not_hit = false;
	bool hit_4a696b_from_4a79a3 = false;
	bool hit_4a7605_from_4a79a3 = false;
	bool hit_pair_mark_sites = false;
	bool direct_4a696b_mutation_adopted = false;
	bool delegated_4a7605_afterstate_materialized = false;
	bool generated_cell_mutation_replay_complete = false;
	std::string status = "blocked_until_supported_scope";
	std::string blocked_reason = "unsupported_non_small_medium_one_level_land";
	int32_t dispatch_4a696b_from_4a79a3_count = 0;
	int32_t dispatch_4a7605_from_4a79a3_count = 0;
	int32_t source_4a696b_combined_entries = 0;
	int32_t source_4a696b_source_relation_match_hits = 0;
	int32_t source_4a696b_candidate_append_hits = 0;
	int32_t source_4a696b_direct_mutation_hits = 0;
	int32_t source_4a696b_complete_grid_scan_count = 0;
	int32_t source_4a696b_zero_owner_relation_pair_match_scan_count = 0;
	int32_t source_4a696b_scanned_cell_total = 0;
	int32_t source_4a696b_seed_count = 0;
	int32_t source_4a696b_byte2_only_or_any_match_total = 0;
	int32_t source_4a696b_byte3_only_or_any_match_total = 0;
	int32_t trace_4a696b_entry_count = 0;
	int32_t trace_4a7605_entry_count = 0;
	int32_t trace_4a7312_call_count = 0;
	int32_t trace_4a7312_vtable_commit_count = 0;
	int32_t trace_4a696b_direct_mutation_site_hit_count = 0;
	int32_t static_4a7605_endpoint_policy_4a7312_count = 0;
	int32_t static_4a7605_endpoint_writer_4a746b_count = 0;
	int32_t static_4a7605_materializer_4a5e03_count = 0;
	int32_t static_4a7605_record_initializer_49ba89_count = 0;
	int32_t static_4a7605_coordinate_append_40bb15_count = 0;
	int32_t static_4a7605_coordinate_merge_40bb26_count = 0;
	int32_t static_4a7605_direct_generated_cell_28_write_count = 0;
};

struct ObjectVectorCommitMutationSamplePlain {
	std::string sample_id;
	std::string source_anchor;
	std::string mutation_mode;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	uint32_t before_word_0x20 = 0;
	uint32_t before_word_0x24 = 0;
	uint32_t before_word_0x28 = 0;
	uint32_t before_word_0x2c = 0;
	uint32_t expected_word_0x20 = 0;
	uint32_t expected_word_0x24 = 0;
	uint32_t expected_word_0x28 = 0;
	uint32_t expected_word_0x2c = 0;
	uint32_t replay_word_0x20 = 0;
	uint32_t replay_word_0x24 = 0;
	uint32_t replay_word_0x28 = 0;
	uint32_t replay_word_0x2c = 0;
	bool match = false;
};

struct ObjectVectorProjectionWriteSamplePlain {
	int32_t ordinal = 0;
	uint32_t recovered_cell_pointer = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	uint32_t before_word_0x1c = 0;
	uint32_t before_word_0x20 = 0;
	uint32_t before_word_0x24 = 0;
	uint32_t before_word_0x28 = 0;
	uint32_t before_word_0x2c = 0;
	uint32_t expected_word_0x20 = 0;
	uint32_t replay_word_0x20 = 0;
	bool high_word_preserved = false;
	bool low_word_lowered = false;
	bool match = false;
};

struct ObjectVectorAttachMutationSamplePlain {
	std::string kind;
	uint32_t recovered_cell_pointer = 0;
	int32_t probe_x = 0;
	int32_t probe_y = 0;
	int32_t relative_x = 0;
	int32_t relative_y = 0;
	int32_t direction_index = 0;
	int32_t descriptor_class_or_type = 0;
	uint32_t before_word_0x28 = 0;
	uint32_t expected_word_0x28 = 0;
	uint32_t replay_word_0x28 = 0;
	uint32_t changed_mask = 0;
	bool clears_bit26 = false;
	bool sets_bit27_from_clear = false;
	bool leaves_bit27_set = false;
	bool match = false;
};

struct ObjectVectorCommitMutationSummaryPlain {
	bool terrain_live_feedback_available = false;
	bool supported_scope = false;
	bool commit_mutation_helpers_ported_plain_cpp = false;
	bool projection_write_helpers_ported_plain_cpp = false;
	bool attach_mutation_helpers_ported_plain_cpp = false;
	bool diagnostic_only = true;
	bool live_grid_mutation_adopted = false;
	bool recovered_samples_match = false;
	bool projection_write_recovered_samples_match = false;
	bool attach_mutation_recovered_samples_match = false;
	bool projection_write_full_stream_materialized_plain_cpp = false;
	bool projection_write_unique_cell_count_matches_recovered = false;
	bool projection_write_ordinals_cover_recovered_stream = false;
	std::string status = "blocked_until_terrain_live_feedback";
	std::string blocked_reason = "terrain_live_feedback_missing";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t seed = 0;
	int32_t sample_count = 0;
	int32_t matched_sample_count = 0;
	int32_t endpoint_clear_sample_count = 0;
	int32_t reward_lower_sample_count = 0;
	int32_t sampled_4aa3e9_projection_write_count = 90;
	int32_t sampled_4aa3e9_projection_write_unique_cell_count = 90;
	int32_t projection_write_sample_count = 0;
	int32_t projection_write_matched_sample_count = 0;
	int32_t projection_write_unique_cell_count = 0;
	int32_t projection_write_ordinal_min = 0;
	int32_t projection_write_ordinal_max = 0;
	int32_t sampled_4a61bc_min_projection_write_count = 74;
	int32_t sampled_4a61bc_max_projection_write_count = 105;
	int32_t sampled_49cf34_attach_write_pair_count = 17;
	int32_t attach_write_pair_count = 0;
	int32_t attach_matched_write_pair_count = 0;
	int32_t attach_primary_write_pair_count = 0;
	int32_t attach_neighbor_write_pair_count = 0;
	int32_t attach_unique_cell_count = 0;
	int32_t attach_changed_write_pair_count = 0;
	int32_t attach_clears_bit26_count = 0;
	int32_t attach_sets_bit27_from_clear_count = 0;
	std::vector<ObjectVectorCommitMutationSamplePlain> samples;
	std::vector<ObjectVectorProjectionWriteSamplePlain> projection_write_samples;
	std::vector<ObjectVectorAttachMutationSamplePlain> attach_mutation_samples;
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
	resolution.setup_object_0x44_supplied = controlled_case.setup_object_0x44_supplied || controlled_case.setup_object_0x44_known;
	resolution.setup_object_0x44_known = true;
	resolution.setup_object_0x44 = resolution.setup_object_0x44_supplied ? controlled_case.setup_object_0x44 : H3MAPED_DEFAULT_RMG_SETUP_OBJECT_0X44_PLAIN;
	resolution.setup_object_0x44_defaulted_from_initializer = !resolution.setup_object_0x44_supplied;
	resolution.rng_state_after_0x49ecf2 = controlled_case.seed;
	resolution.generator_mode_known = true;
	if (resolution.setup_object_0x44 == 3) {
		H3MapedRng rng { controlled_case.seed };
		resolution.randomized_from_setup_value_3 = true;
		resolution.randomization_rng_value = rng.next();
		resolution.generator_mode_0x10b8 = resolution.randomization_rng_value % 3;
		resolution.rng_state_after_0x49ecf2 = rng.state;
		resolution.pre_template_rng_call_count = 1;
		return resolution;
	}
	resolution.generator_mode_0x10b8 = resolution.setup_object_0x44;
	return resolution;
}

std::string generator_mode_status_label(const GeneratorModeResolutionPlain &resolution) {
	if (!resolution.setup_object_0x44_known) {
		return "unknown_missing_same_run_rmg_setup_object_0x44_capture";
	}
	if (resolution.setup_object_0x44_defaulted_from_initializer) {
		return "defaulted_from_0x4adf88_setup_initializer_value_3_no_same_run_capture_supplied";
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

int32_t h3maped_terrain_id_from_name_plain(const std::string &terrain_name) {
	if (terrain_name == "dirt") {
		return 0;
	}
	if (terrain_name == "sand") {
		return 1;
	}
	if (terrain_name == "grass") {
		return 2;
	}
	if (terrain_name == "snow") {
		return 3;
	}
	if (terrain_name == "swamp") {
		return 4;
	}
	if (terrain_name == "rough") {
		return 5;
	}
	if (terrain_name == "cave") {
		return 6;
	}
	if (terrain_name == "lava") {
		return 7;
	}
	if (terrain_name == "water") {
		return 8;
	}
	return -1;
}

std::string project_terrain_for_h3maped_id_plain(int32_t terrain_id) {
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

std::vector<int32_t> h3maped_terrain_ids_from_original_names_plain(const std::vector<std::string> &terrain_names) {
	std::array<bool, 8> flags = {};
	for (const std::string &terrain_name : terrain_names) {
		const int32_t terrain_id = h3maped_terrain_id_from_name_plain(terrain_name);
		if (terrain_id >= 0 && terrain_id < int32_t(flags.size())) {
			flags[size_t(terrain_id)] = true;
		}
	}
	std::vector<int32_t> ids;
	for (int32_t terrain_id = 0; terrain_id < int32_t(flags.size()); ++terrain_id) {
		if (flags[size_t(terrain_id)]) {
			ids.push_back(terrain_id);
		}
	}
	return ids;
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
		JsonSpan terrain_policy = object_key_value_span(text, zone, "terrain_policy");
		record.terrain_match_to_town = json_bool_or(text, zone, "terrain_match_to_town", json_bool_or(text, terrain_policy, "match_to_faction", false));
		std::vector<std::string> allowed_terrains = json_array_string_values(text, object_key_value_span(text, zone, "allowed_terrains"));
		if (allowed_terrains.empty()) {
			allowed_terrains = json_array_string_values(text, object_key_value_span(text, terrain_policy, "allowed"));
		}
		record.allowed_h3maped_terrain_ids = h3maped_terrain_ids_from_original_names_plain(allowed_terrains);
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
	for (int32_t node_index = 0; node_index < int32_t(model.nodes.size()); ++node_index) {
		const PolygonModelNodePlain &node = model.nodes[size_t(node_index)];
		SourceDescriptorNodePlain descriptor;
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
		walk.locator_node_index = located;
		walk.locator_status = located >= 0
				? "0x4cca55_runtime_zone_descriptor_handoff_materialized"
				: "0x4cca55_runtime_zone_descriptor_handoff_missing";
		if (located >= 0) {
			int32_t current = located;
			bool guard_exhausted = false;
			for (int32_t guard = 0; guard < 96; ++guard) {
				const PolygonModelNodePlain &node = model.nodes[size_t(current)];
				const int32_t next = node.next;
				const int32_t next_pair = next >= 0 && next < int32_t(model.nodes.size()) ? model.nodes[size_t(next)].pair : -1;
				const PolygonModelNodePlain *next_pair_node = next_pair >= 0 && next_pair < int32_t(model.nodes.size()) ? &model.nodes[size_t(next_pair)] : nullptr;
				SourceCycleNodePlain source_node;
				source_node.model_node_index = current;
				source_node.pair_index = node.pair;
				source_node.next_index = node.next;
				source_node.previous_index = node.previous;
				source_node.next_pair_index = next_pair;
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
constexpr uint32_t H3MAPED_CELL_ACTION_CONTROL_BIT_22_PLAIN = 1U << 22U;
constexpr uint32_t H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN = 1U << 26U;
constexpr uint32_t H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN = 1U << 27U;
constexpr uint32_t H3MAPED_CELL_DECOR_READY_BIT_25_PLAIN = 1U << 25U;
constexpr uint32_t H3MAPED_CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28_PLAIN = 1U << 28U;
constexpr uint32_t H3MAPED_CELL_TERRAIN_FLAG_SHIFT_0X49ACF6_PLAIN = 15U;
constexpr uint32_t H3MAPED_CELL_TERRAIN_FLAG_MASK_0X49ACF6_PLAIN = 0x03U << H3MAPED_CELL_TERRAIN_FLAG_SHIFT_0X49ACF6_PLAIN;

uint32_t h3maped_generated_cell_word20_set_low_word_plain(uint32_t word_0x20, uint32_t low_word) {
	return (word_0x20 & 0xffff0000U) | (low_word & 0x0000ffffU);
}

uint32_t h3maped_generated_cell_4a54a7_endpoint_word28_plain(uint32_t word_0x28) {
	return word_0x28 | H3MAPED_CELL_ACTION_CONTROL_BIT_22_PLAIN | H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN;
}

uint32_t h3maped_generated_cell_4aa3e9_reward_word28_plain(uint32_t word_0x28) {
	return word_0x28 & ~H3MAPED_CELL_DECOR_READY_BIT_25_PLAIN;
}

uint32_t h3maped_generated_cell_49cf34_attach_word28_plain(uint32_t word_0x28) {
	return (word_0x28 | H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) & ~H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN;
}

uint32_t h3maped_generated_cell_4a56b6_projection_word20_plain(uint32_t word_0x20, uint32_t lowered_low_word) {
	return h3maped_generated_cell_word20_set_low_word_plain(word_0x20, lowered_low_word);
}

constexpr uint32_t H3MAPED_RELATION_RESET_WORD_0X1C_PLAIN = 0x7d007d00U;
constexpr uint32_t H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN = 0xffffffffU;
constexpr uint32_t H3MAPED_RELATION_RESET_ARG_0X4A59E2_WORD_0X1C_HIGH_PLAIN = 0x7d00U;
constexpr uint32_t H3MAPED_RELATION_RESET_ARG_0X4A59E2_BITS_12_14_PLAIN = 0U;
constexpr uint32_t H3MAPED_RELATION_RESET_ARG_0X4A59E2_WORD_0X20_BYTE3_PLAIN = 0xffffffffU;
constexpr uint32_t H3MAPED_RELATION_WORD_0X28_BITS_12_14_MASK_PLAIN = 0x7U << 12U;

uint32_t h3maped_generated_cell_4a59e2_pack_word_0x1c_plain(uint32_t word_0x1c, uint32_t arg_word_0x1c_high) {
	return (word_0x1c & 0x0000ffffU) | ((arg_word_0x1c_high & 0xffffU) << 16U);
}

uint32_t h3maped_generated_cell_4a59e2_pack_word_0x20_plain(uint32_t word_0x20, uint32_t arg_byte3) {
	return (word_0x20 & 0x00ffffffU) | ((arg_byte3 & 0xffU) << 24U);
}

uint32_t h3maped_generated_cell_4a59e2_pack_word_0x28_plain(uint32_t word_0x28, uint32_t arg_bits_12_14) {
	return (word_0x28 & ~H3MAPED_RELATION_WORD_0X28_BITS_12_14_MASK_PLAIN)
			| ((arg_bits_12_14 & 0x7U) << 12U);
}

uint32_t h3maped_generated_cell_4a5767_reset_force_word_0x1c_plain(uint32_t word_0x1c_after_4a59e2) {
	return (word_0x1c_after_4a59e2 & 0xffff0000U)
			| (((word_0x1c_after_4a59e2 & 0x0000ffffU) & 0x7d00U) | 0x7d00U);
}

uint32_t h3maped_generated_cell_49a318_clear_source_word_0x1c_plain(uint32_t word_0x1c) {
	// 0x49a3a2: AND word ptr [ESI + 0x1c], DI after EDI was zeroed at 0x49a32b.
	return word_0x1c & 0xffff0000U;
}

bool h3maped_generated_cell_index_valid_plain(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	return flat >= 0
			&& flat < int64_t(word_0x28.size())
			&& flat < int64_t(word_0x24.size());
}

bool h3maped_generated_cell_49a1d8_valid_plain(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	if (!h3maped_generated_cell_index_valid_plain(word_0x28, word_0x24, flat)) {
		return false;
	}
	return (word_0x28[size_t(flat)] & H3MAPED_CELL_DECOR_READY_BIT_25_PLAIN) != 0U
			&& (word_0x24[size_t(flat)] & 0x3fU) != 9U;
}

bool h3maped_generated_cell_49aa63_plain(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_candidate) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) != 0U;
	if (set_candidate) {
		word_0x28[size_t(flat)] |= H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN;
		word_0x28[size_t(flat)] &= ~H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN;
	return was_set;
}

bool h3maped_generated_cell_49a932_plain(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_occupied) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) != 0U;
	if (set_occupied) {
		word_0x28[size_t(flat)] |= H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN;
		word_0x28[size_t(flat)] &= ~H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN;
	return was_set;
}

int64_t h3maped_generated_cell_flat_plain(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0) {
		return -1;
	}
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

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
	std::string handoff_status = "0x4a325d_seed_descriptor_handoff_not_used_for_in_bounds_seed";
	std::string descriptor_source = "not_used_seed_already_in_bounds";
	bool relocated = false;
	bool seed_in_bounds = false;
	bool exact_descriptor_handoff_ported = false;
	bool descriptor_proxy_available = false;
	int32_t candidate_scan_count = 0;
	int32_t interior_candidate_count = 0;
	int32_t best_candidate_x = -1;
	int32_t best_candidate_y = -1;
	int32_t best_candidate_clearance = -1;
	std::string clip_branch;
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

SeedRelocationPlain seed_relocation_4a325d_plain(const SourceWalkPlain *walk, const SpanRecordPlain &seed, int32_t width, int32_t height, int32_t level_count) {
	SeedRelocationPlain relocation;
	relocation.x = seed.x;
	relocation.y = seed.y;
	relocation.level = seed.level;
	relocation.seed_in_bounds = seed.x >= 0 && seed.x < width && seed.y >= 0 && seed.y < height && seed.level >= 0 && seed.level < level_count;
	if (relocation.seed_in_bounds) {
		return relocation;
	}
	relocation.status = "0x4a325d_seed_out_of_bounds_exact_descriptor_handoff_unported";
	relocation.handoff_status = "0x4a325d_out_of_bounds_descriptor_scan_required_but_exact_0x4a3a03_0x4cca55_descriptor_handoff_unported";
	relocation.descriptor_source = "unported_h3maped_descriptor_argument_ebp_plus_0x0c";
	int32_t best_x = -1;
	int32_t best_y = -1;
	int32_t best_clearance = -1;
	if (walk != nullptr) {
		relocation.descriptor_proxy_available = true;
		relocation.descriptor_source = walk->locator_node_index >= 0
				? "native_source_descriptor_cycle_from_0x4cca55_handoff_not_exact_0x4a325d_relocation_replay"
				: "native_current_source_cycle_walk_proxy_missing_0x4cca55_locator_index";
		for (const SourceCycleNodePlain &node : walk->cycle_nodes) {
			relocation.candidate_scan_count += 1;
			const int32_t x = node.x;
			const int32_t y = node.y;
			if (x >= 1 && x < width - 1 && y >= 1 && y < height - 1) {
				relocation.interior_candidate_count += 1;
				const int32_t clearance = std::min<int32_t>(std::min<int32_t>(x, width - x - 1), std::min<int32_t>(y, height - y - 1));
				if (clearance > best_clearance) {
					best_clearance = clearance;
					best_x = x;
					best_y = y;
				}
			}
		}
	}
	relocation.best_candidate_x = best_x;
	relocation.best_candidate_y = best_y;
	relocation.best_candidate_clearance = best_clearance;
	if (best_x < 0 || best_y < 0) {
		relocation.status = "0x4a325d_seed_out_of_bounds_exact_descriptor_handoff_unported_no_proxy_candidate";
		relocation.handoff_status = relocation.descriptor_proxy_available
				? "0x4a325d_current_cycle_proxy_scanned_but_no_interior_candidate"
				: "0x4a325d_exact_descriptor_handoff_unported_and_no_native_proxy_walk";
		return relocation;
	}
	ClipBoundsPlain bounds;
	bounds.min_x = 0;
	bounds.min_y = 0;
	bounds.max_x = width;
	bounds.max_y = height;
	const ClipResultPlain clipped = clip_point_4a2b33_plain(seed.x, seed.y, best_x, best_y, bounds);
	relocation.status = "0x4a325d_seed_out_of_bounds_current_cycle_proxy_relocated_with_0x4a2b33_exact_descriptor_handoff_unported";
	relocation.handoff_status = "0x4a325d_proxy_matches_recovered_best-clearance_formula_but_not_exact_descriptor_argument";
	relocation.relocated = true;
	relocation.clip_branch = clipped.branch;
	relocation.x = clipped.x;
	relocation.y = clipped.y;
	return relocation;
}

void append_boundary_vector_event_4a2777_plain(BoundarySpanFillSummary &summary, int32_t runtime_zone_index, int32_t source_zone_id, int32_t zone_word_id, int32_t x, int32_t y, int32_t level, const std::string &event_kind, const std::string &h3maped_anchor, const std::string &native_source) {
	summary.boundary_vector_event_count += 1;
	summary.boundary_vector_events_by_anchor[h3maped_anchor] += 1;
	summary.boundary_vector_events_by_kind[event_kind] += 1;
	if (int32_t(summary.boundary_vector_events.size()) >= summary.boundary_vector_event_sample_limit) {
		summary.boundary_vector_event_sample_truncated = true;
		return;
	}
	BoundaryVectorEventPlain event;
	event.runtime_zone_index = runtime_zone_index;
	event.source_zone_id = source_zone_id;
	event.zone_word_id = zone_word_id;
	event.vector_index = summary.boundary_vector_event_count - 1;
	event.x = x;
	event.y = y;
	event.level = level;
	event.event_kind = event_kind;
	event.h3maped_anchor = h3maped_anchor;
	event.native_source = native_source;
	summary.boundary_vector_events.push_back(event);
}

bool source_descriptor_node_valid_plain(const std::vector<SourceDescriptorNodePlain> &nodes, int32_t node_index) {
	return node_index >= 0 && node_index < int32_t(nodes.size()) && nodes[size_t(node_index)].active;
}

SourceCycleNodePlain source_cycle_node_from_descriptor_plain(const std::vector<SourceDescriptorNodePlain> &nodes, const SourceDescriptorNodePlain &node) {
	SourceCycleNodePlain source_node;
	source_node.model_node_index = node.model_node_index;
	source_node.pair_index = node.pair_index;
	source_node.next_index = node.next_index;
	source_node.previous_index = node.previous_index;
	source_node.next_pair_index = source_descriptor_node_valid_plain(nodes, node.next_index) ? nodes[size_t(node.next_index)].pair_index : -1;
	source_node.x = node.x;
	source_node.y = node.y;
	source_node.has_payload = node.has_payload;
	source_node.payload = node.payload;
	if (source_descriptor_node_valid_plain(nodes, source_node.next_pair_index)) {
		const SourceDescriptorNodePlain &next_pair = nodes[size_t(source_node.next_pair_index)];
		source_node.next_pair_has_payload = next_pair.has_payload;
		source_node.next_pair_payload = next_pair.payload;
	}
	source_node.finalized = node.finalized;
	source_node.finalized_x = node.finalized_x;
	source_node.finalized_y = node.finalized_y;
	return source_node;
}

std::vector<SourceCycleNodePlain> descriptor_cycle_from_locator_plain(const std::vector<SourceDescriptorNodePlain> &nodes, int32_t locator_node_index, bool &guard_exhausted, int32_t &inactive_or_invalid_count) {
	std::vector<SourceCycleNodePlain> cycle;
	guard_exhausted = false;
	inactive_or_invalid_count = 0;
	if (!source_descriptor_node_valid_plain(nodes, locator_node_index)) {
		inactive_or_invalid_count += 1;
		return cycle;
	}
	int32_t current = locator_node_index;
	const int32_t guard_limit = std::max<int32_t>(16, int32_t(nodes.size()) + 4);
	for (int32_t guard = 0; guard < guard_limit; ++guard) {
		if (!source_descriptor_node_valid_plain(nodes, current)) {
			inactive_or_invalid_count += 1;
			break;
		}
		const SourceDescriptorNodePlain &node = nodes[size_t(current)];
		cycle.push_back(source_cycle_node_from_descriptor_plain(nodes, node));
		current = node.next_index;
		if (current == locator_node_index) {
			break;
		}
		if (guard == guard_limit - 1) {
			guard_exhausted = true;
		}
	}
	return cycle;
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

	auto append_border_connection = [&](int32_t &current_x, int32_t &current_y, int32_t target_x, int32_t target_y, int32_t zone_word, int32_t level, int32_t random_span_limit, int32_t runtime_zone_index, int32_t source_zone_id) {
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
			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, source_zone_id, zone_word, current_x, current_y, level, "h3maped_wrap_current_vertex", "0x4a2adc", "0x4a2777_current_point_before_wrap_update");
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
			const int32_t old_current_x = current_x;
			const int32_t old_current_y = current_y;
			append_line(current_x, current_y, target_x, target_y, zone_word, level, false, random_span_limit);
			summary.boundary_appended_vertex_count += 1;
			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, source_zone_id, zone_word, old_current_x, old_current_y, level, "h3maped_final_current_vertex", "0x4a2b1e", "0x4a2777_current_point_before_final_update");
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
		bool descriptor_guard_exhausted = false;
		int32_t descriptor_inactive_or_invalid_count = 0;
		std::vector<SourceCycleNodePlain> walk_descriptor_nodes = descriptor_cycle_from_locator_plain(source_node_summary.source.descriptor_nodes, walk.locator_node_index, descriptor_guard_exhausted, descriptor_inactive_or_invalid_count);
		std::vector<SourceCycleNodePlain> replay_nodes = walk_descriptor_nodes.empty() ? walk.cycle_nodes : walk_descriptor_nodes;
		if (!walk_descriptor_nodes.empty()) {
			summary.boundary_source_descriptor_handoff_materialized = true;
			summary.boundary_descriptor_handoff_walk_count += 1;
			summary.boundary_descriptor_handoff_node_count += int32_t(walk_descriptor_nodes.size());
		} else {
			summary.boundary_descriptor_handoff_missing_count += 1;
		}
		if (descriptor_guard_exhausted) {
			summary.boundary_descriptor_handoff_guard_exhausted_count += 1;
		}
		summary.boundary_descriptor_handoff_inactive_or_invalid_count += descriptor_inactive_or_invalid_count;
		std::vector<SourceCycleNodePlain> source_nodes;
		for (const SourceCycleNodePlain &node : replay_nodes) {
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
		auto append_fallback_rectangle = [&]() {
			const int32_t left_x = bounds.min_x;
			const int32_t top_y = bounds.min_y;
			const int32_t right_x = std::max<int32_t>(bounds.min_x, bounds.max_x - 1);
			const int32_t bottom_y = std::max<int32_t>(bounds.min_y, bounds.max_y - 1);
			append_line(right_x, bottom_y, right_x, top_y, zone_word, level, false, random_span_limit);
			append_line(right_x, top_y, left_x, top_y, zone_word, level, false, random_span_limit);
			append_line(left_x, top_y, left_x, bottom_y, zone_word, level, false, random_span_limit);
			append_line(left_x, bottom_y, right_x, bottom_y, zone_word, level, false, random_span_limit);

			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, zone.source_zone_id, zone_word, right_x, bottom_y, level, "h3maped_fallback_rectangle_vertex", "0x4a28c8", "0x4a2777_fallback_rectangle_bottom_right");
			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, zone.source_zone_id, zone_word, right_x, top_y, level, "h3maped_fallback_rectangle_vertex", "0x4a28dc", "0x4a2777_fallback_rectangle_top_right");
			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, zone.source_zone_id, zone_word, left_x, top_y, level, "h3maped_fallback_rectangle_vertex", "0x4a28f3", "0x4a2777_fallback_rectangle_top_left");
			append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, zone.source_zone_id, zone_word, left_x, bottom_y, level, "h3maped_fallback_rectangle_vertex", "0x4a2907", "0x4a2777_fallback_rectangle_bottom_left");
			summary.boundary_appended_vertex_count += 4;
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
			append_fallback_rectangle();
			summary.boundary_fallback_zone_count += 1;
			summary.boundary_runtime_zone_walk_count += 1;
			continue;
		}
		append_boundary_vector_event_4a2777_plain(summary, runtime_zone_index, zone.source_zone_id, zone_word, clipped_current.x, clipped_current.y, level, "h3maped_selected_start_vertex", "0x4a2990", "0x4a2777_selected_start_before_owner_gate");
		summary.boundary_appended_vertex_count += 1;
		if (source_edge_writer_allowed(source_nodes[size_t(selected_segment_index)])) {
			append_line(clipped_current.x, clipped_current.y, clipped_target.x, clipped_target.y, zone_word, level, flagged_branch, random_span_limit);
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
			append_border_connection(current_x, current_y, from_clip.x, from_clip.y, zone_word, level, random_span_limit, runtime_zone_index, zone.source_zone_id);
			if (summary.boundary_loop_guard_exhausted) {
				break;
			}
			if (from_clip.x != to_clip.x || from_clip.y != to_clip.y) {
				if (source_edge_writer_allowed(from_node)) {
					append_line(from_clip.x, from_clip.y, to_clip.x, to_clip.y, zone_word, level, false, random_span_limit);
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
	summary.boundary_native_vector_trace_materialized = true;
	summary.boundary_exact_h3maped_vector_materialized = false;
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
		zone_fill.seed_descriptor_handoff_status = relocation.handoff_status;
		zone_fill.seed_descriptor_source = relocation.descriptor_source;
		zone_fill.exact_seed_descriptor_handoff_ported = relocation.exact_descriptor_handoff_ported;
		zone_fill.seed_descriptor_proxy_available = relocation.descriptor_proxy_available;
		zone_fill.seed_descriptor_candidate_scan_count = relocation.candidate_scan_count;
		zone_fill.seed_descriptor_candidate_interior_count = relocation.interior_candidate_count;
		zone_fill.seed_descriptor_best_x = relocation.best_candidate_x;
		zone_fill.seed_descriptor_best_y = relocation.best_candidate_y;
		zone_fill.seed_descriptor_best_clearance = relocation.best_candidate_clearance;
		zone_fill.seed_descriptor_clip_branch = relocation.clip_branch;
		if (!relocation.seed_in_bounds) {
			summary.span_fill_seed_out_of_bounds_count += 1;
			if (!relocation.exact_descriptor_handoff_ported) {
				summary.span_fill_seed_descriptor_handoff_unported_count += 1;
			}
		}
		if (relocation.descriptor_proxy_available) {
			summary.span_fill_seed_descriptor_proxy_available_count += 1;
			summary.span_fill_seed_descriptor_proxy_candidate_scan_count += relocation.candidate_scan_count;
			summary.span_fill_seed_descriptor_proxy_interior_candidate_count += relocation.interior_candidate_count;
			if (relocation.best_candidate_x < 0 || relocation.best_candidate_y < 0) {
				summary.span_fill_seed_descriptor_proxy_no_candidate_count += 1;
			}
		}
		if (relocation.relocated) {
			seed.x = relocation.x;
			seed.y = relocation.y;
			seed.level = relocation.level;
			zone_fill.seed_relocated = true;
			summary.span_fill_seed_relocated_count += 1;
			if (relocation.descriptor_proxy_available && !relocation.exact_descriptor_handoff_ported) {
				summary.span_fill_seed_descriptor_proxy_relocated_count += 1;
			}
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
	summary.private_zone_words = zone_words;
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

RuntimeTerrainSelectionSummaryPlain build_runtime_terrain_selection_summary(const ControlledCase &controlled_case, const CoordinateReplaySummary &coordinate_summary, const SourceNodeFootprintSummary &source_node_summary) {
	static constexpr int32_t H3_TOWN_TO_TERRAIN_TABLE_540908[9] = { 2, 2, 3, 7, 0, 0, 5, 4, 2 };
	RuntimeTerrainSelectionSummaryPlain summary;
	summary.coordinate_replay_available = coordinate_summary.ok;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.rng_state_before_0x49b53d = coordinate_summary.rng_state_after_0x4a218c;
	summary.rng_state_after_0x49b53d = coordinate_summary.rng_state_after_0x4a218c;
	if (!summary.coordinate_replay_available) {
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	H3MapedRng rng { summary.rng_state_before_0x49b53d };
	const std::vector<RuntimeZoneRecordPlain> &terrain_runtime_zones = source_node_summary.runtime_zones_after_synthetic_append.empty()
			? coordinate_summary.scaled_zone_coordinates
			: source_node_summary.runtime_zones_after_synthetic_append;
	for (int32_t index = 0; index < int32_t(terrain_runtime_zones.size()); ++index) {
		const RuntimeZoneRecordPlain &runtime = terrain_runtime_zones[size_t(index)];
		RuntimeTerrainSelectionPlain selection;
		selection.runtime_zone_index = runtime.runtime_index >= 0 ? runtime.runtime_index : index;
		selection.level = runtime.level_after_bbox_rescale;
		selection.terrain_match_to_town = runtime.terrain_match_to_town;
		selection.town_choice_index = runtime.town_choice_index;
		int32_t selected_terrain = 0;
		std::string source = "0x49b57d_0x49b584_no_eligible_flags_defaults_zero";
		if (runtime.terrain_match_to_town
				&& runtime.town_choice_index >= 0
				&& runtime.town_choice_index < int32_t(sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908) / sizeof(H3_TOWN_TO_TERRAIN_TABLE_540908[0]))) {
			selected_terrain = H3_TOWN_TO_TERRAIN_TABLE_540908[size_t(runtime.town_choice_index)];
			source = "0x49b54c_0x49b55b_match_to_town_table_0x540908";
			summary.match_to_town_count += 1;
		} else {
			for (const int32_t h3_id : runtime.allowed_h3maped_terrain_ids) {
				if (h3_id < 0 || h3_id > 7) {
					continue;
				}
				if (h3_id == 6 && runtime.level_after_bbox_rescale != 1) {
					continue;
				}
				selection.eligible_h3maped_terrain_ids.push_back(h3_id);
			}
			if (selection.eligible_h3maped_terrain_ids.empty()) {
				summary.blank_allowed_mask_count += 1;
			} else {
				const int32_t rng_value = rng.next();
				summary.terrain_rng_call_count += 1;
				const int32_t selected_ordinal = rng_value % int32_t(selection.eligible_h3maped_terrain_ids.size());
				selected_terrain = selection.eligible_h3maped_terrain_ids[size_t(selected_ordinal)];
				source = "0x49b586_0x49b5b4_allowed_flag_rng_choice";
				summary.allowed_flag_choice_count += 1;
				selection.rng_value = rng_value;
				selection.rng_modulus = int32_t(selection.eligible_h3maped_terrain_ids.size());
				selection.selected_allowed_ordinal = selected_ordinal;
			}
		}
		if (runtime.level_after_bbox_rescale == 1 && selected_terrain != 7) {
			selected_terrain = 6;
			summary.forced_subterranean_count += 1;
		}

		if (runtime.town_choice_index == -1) {
			const int32_t rng_value = rng.next();
			selection.monster_town_rng_value = rng_value;
			selection.selected_monster_table_ordinal_0x49b4e1 = rng_value % 4;
			selection.selected_monster_table_value_materialized = false;
			summary.monster_town_rng_call_count_0x49b4e1 += 1;
		} else {
			selection.selected_monster_table_ordinal_0x49b4e1 = runtime.town_choice_index;
			selection.selected_monster_table_value_materialized = true;
		}

		selection.selected_h3maped_terrain_id = selected_terrain;
		selection.selected_project_terrain_id = project_terrain_for_h3maped_id_plain(selected_terrain);
		selection.source = source;
		summary.selections.push_back(selection);
		summary.selected_h3maped_terrain_ids.push_back(selected_terrain);
	}
	summary.selection_count = int32_t(summary.selections.size());
	summary.rng_state_after_0x49b53d = rng.state;
	summary.materializes_runtime_zone_terrain_ids = true;
	summary.status = "active_plain_cpp_runtime_terrain_selection";
	summary.blocked_reason.clear();
	return summary;
}

TerrainCellWriteoutSummaryPlain build_terrain_cell_writeout_summary(const BoundarySpanFillSummary &boundary_summary, const RuntimeTerrainSelectionSummaryPlain &terrain_summary, const SourceNodeFootprintSummary &source_node_summary) {
	TerrainCellWriteoutSummaryPlain summary;
	summary.boundary_owner_words_available = boundary_summary.generated_cell_owner_words_materialized;
	summary.runtime_terrain_selection_available = terrain_summary.materializes_runtime_zone_terrain_ids;
	summary.width = boundary_summary.width;
	summary.height = boundary_summary.height;
	summary.level_count = boundary_summary.level_count;
	const int32_t level_tile_count = summary.width * summary.height;
	summary.cell_count = level_tile_count * std::max(1, summary.level_count);
	const std::vector<RuntimeZoneRecordPlain> &runtime_zones = source_node_summary.runtime_zones_after_synthetic_append;
	const bool supported = summary.boundary_owner_words_available
			&& summary.runtime_terrain_selection_available
			&& boundary_summary.private_zone_words.size() == size_t(summary.cell_count)
			&& boundary_summary.generated_cell_word_0x20.size() == size_t(summary.cell_count)
			&& boundary_summary.generated_cell_word_0x24.size() == size_t(summary.cell_count)
			&& boundary_summary.generated_cell_word_0x28.size() == size_t(summary.cell_count)
			&& boundary_summary.generated_cell_word_0x2c.size() == size_t(summary.cell_count)
			&& boundary_summary.generated_cell_terrain_code.size() == size_t(summary.cell_count)
			&& summary.width > 0
			&& summary.height > 0
			&& summary.level_count > 0
			&& summary.cell_count >= 0;
	if (!supported) {
		summary.blocked_reason = "boundary_owner_words_or_runtime_terrain_selection_missing";
		return summary;
	}

	std::map<int32_t, int32_t> runtime_index_by_zone_word_id;
	for (const RuntimeZoneRecordPlain &runtime : runtime_zones) {
		runtime_index_by_zone_word_id[zone_word_id_for_runtime_zone_plain(runtime)] = runtime.runtime_index;
	}
	summary.generated_cell_word_0x20.assign(boundary_summary.generated_cell_word_0x20.size(), 0xffff7fbcU);
	summary.generated_cell_word_0x24 = boundary_summary.generated_cell_word_0x24;
	summary.generated_cell_word_0x28 = boundary_summary.generated_cell_word_0x28;
	summary.generated_cell_word_0x2c = boundary_summary.generated_cell_word_0x2c;
	summary.generated_cell_terrain_code.assign(boundary_summary.generated_cell_terrain_code.size(), 8);
	summary.terrain_code_counts[8] = summary.cell_count;
	for (int32_t flat = 0; flat < summary.cell_count; ++flat) {
		const uint32_t zone_word = boundary_summary.private_zone_words[size_t(flat)] & H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN;
		if (zone_word == H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN) {
			summary.unassigned_water_cell_count += 1;
			continue;
		}
		const int32_t zone_word_id = int32_t((zone_word >> 16U) & 0xffU);
		const auto runtime_found = runtime_index_by_zone_word_id.find(zone_word_id);
		const int32_t runtime_index = runtime_found == runtime_index_by_zone_word_id.end() ? -1 : runtime_found->second;
		if (runtime_index < 0 || runtime_index >= int32_t(terrain_summary.selected_h3maped_terrain_ids.size())) {
			continue;
		}
		const int32_t terrain_id = terrain_summary.selected_h3maped_terrain_ids[size_t(runtime_index)];
		summary.generated_cell_word_0x20[size_t(flat)] = (summary.generated_cell_word_0x20[size_t(flat)] & 0xff00ffffU) | zone_word;
		summary.generated_cell_terrain_code[size_t(flat)] = terrain_id;
		summary.assigned_owner_cell_count += 1;
		summary.owner_low_byte_counts[zone_word_id] += 1;
		if (terrain_id != 8) {
			summary.terrain_code_counts[8] -= 1;
			summary.terrain_code_counts[terrain_id] += 1;
		}
	}
	summary.selected_runtime_zone_count = int32_t(terrain_summary.selected_h3maped_terrain_ids.size());
	for (auto iterator = summary.terrain_code_counts.begin(); iterator != summary.terrain_code_counts.end();) {
		if (iterator->second == 0) {
			iterator = summary.terrain_code_counts.erase(iterator);
		} else {
			++iterator;
		}
	}
	summary.materializes_private_terrain_cell_buffer = true;
	summary.status = "active_plain_cpp_terrain_cell_writeout";
	summary.blocked_reason.clear();
	return summary;
}

std::vector<FilledZoneGeometryPlain> filled_zone_geometry_4a2105_4a2ffa_plain(const BoundarySpanFillSummary &boundary_summary, const std::vector<RuntimeZoneRecordPlain> &runtime_zones) {
	struct Accumulator {
		FilledZoneGeometryPlain geometry;
		int64_t sum_x = 0;
		int64_t sum_y = 0;
	};

	std::map<int32_t, int32_t> runtime_index_by_zone_word_id;
	std::map<int32_t, Accumulator> geometry_by_runtime_index;
	for (const RuntimeZoneRecordPlain &runtime : runtime_zones) {
		const int32_t runtime_index = runtime.runtime_index;
		const int32_t zone_word_id = zone_word_id_for_runtime_zone_plain(runtime);
		runtime_index_by_zone_word_id[zone_word_id] = runtime_index;
		Accumulator accumulator;
		accumulator.geometry.runtime_zone_index = runtime_index;
		accumulator.geometry.zone_word_id = zone_word_id;
		accumulator.geometry.filled_rect_min_x_0x20 = std::numeric_limits<int32_t>::max();
		accumulator.geometry.filled_rect_min_y_0x24 = std::numeric_limits<int32_t>::max();
		geometry_by_runtime_index[runtime_index] = accumulator;
	}

	const int32_t level_tile_count = boundary_summary.width * boundary_summary.height;
	const int32_t expected_cell_count = level_tile_count * std::max(1, boundary_summary.level_count);
	if (boundary_summary.width > 0
			&& boundary_summary.height > 0
			&& expected_cell_count == int32_t(boundary_summary.private_zone_words.size())) {
		for (int32_t flat = 0; flat < expected_cell_count; ++flat) {
			const uint32_t masked = boundary_summary.private_zone_words[size_t(flat)] & H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN;
			if (masked == H3MAPED_UNASSIGNED_ZONE_WORD_PLAIN) {
				continue;
			}
			const int32_t zone_word_id = int32_t((masked >> 16U) & 0xffU);
			const auto runtime_found = runtime_index_by_zone_word_id.find(zone_word_id);
			if (runtime_found == runtime_index_by_zone_word_id.end()) {
				continue;
			}
			const int32_t runtime_index = runtime_found->second;
			Accumulator &accumulator = geometry_by_runtime_index[runtime_index];
			const int32_t remainder = flat % level_tile_count;
			const int32_t x = remainder % boundary_summary.width;
			const int32_t y = remainder / boundary_summary.width;
			FilledZoneGeometryPlain &geometry = accumulator.geometry;
			geometry.filled_rect_min_x_0x20 = std::min<int32_t>(geometry.filled_rect_min_x_0x20, x);
			geometry.filled_rect_min_y_0x24 = std::min<int32_t>(geometry.filled_rect_min_y_0x24, y);
			geometry.filled_rect_max_x_exclusive_0x28 = std::max<int32_t>(geometry.filled_rect_max_x_exclusive_0x28, x + 1);
			geometry.filled_rect_max_y_exclusive_0x2c = std::max<int32_t>(geometry.filled_rect_max_y_exclusive_0x2c, y + 1);
			accumulator.sum_x += x;
			accumulator.sum_y += y;
			geometry.filled_cell_count += 1;
			geometry.has_filled_cells = true;
		}
	}

	std::vector<FilledZoneGeometryPlain> records;
	records.reserve(geometry_by_runtime_index.size());
	for (auto &item : geometry_by_runtime_index) {
		Accumulator &accumulator = item.second;
		FilledZoneGeometryPlain &geometry = accumulator.geometry;
		if (geometry.filled_cell_count > 0) {
			geometry.centroid_x_0x10 = int32_t(accumulator.sum_x / geometry.filled_cell_count);
			geometry.centroid_y_0x14 = int32_t(accumulator.sum_y / geometry.filled_cell_count);
			geometry.centroid_level_0x18 = 0;
		} else {
			geometry.filled_rect_min_x_0x20 = 0;
			geometry.filled_rect_min_y_0x24 = 0;
			geometry.filled_rect_max_x_exclusive_0x28 = 0;
			geometry.filled_rect_max_y_exclusive_0x2c = 0;
		}
		records.push_back(geometry);
	}
	return records;
}

TerrainRelationEligibilitySummaryPlain build_terrain_relation_eligibility_summary(const BoundarySpanFillSummary &boundary_summary, const TerrainCellWriteoutSummaryPlain &terrain_cell_summary, const SourceNodeFootprintSummary &source_node_summary) {
	TerrainRelationEligibilitySummaryPlain summary;
	summary.boundary_owner_words_available = terrain_cell_summary.materializes_private_terrain_cell_buffer;
	summary.supported_scope = boundary_summary.supported_scope;
	summary.width = boundary_summary.width;
	summary.height = boundary_summary.height;
	summary.level_count = boundary_summary.level_count;
	const int32_t level_tile_count = summary.width * summary.height;
	summary.cell_count = level_tile_count * std::max(1, summary.level_count);
	const std::vector<RuntimeZoneRecordPlain> &runtime_zones = source_node_summary.runtime_zones_after_synthetic_append;
	summary.runtime_zone_count = int32_t(runtime_zones.size());
	const bool supported = summary.boundary_owner_words_available
			&& summary.supported_scope
			&& summary.width > 0
			&& summary.height > 0
			&& summary.level_count > 0
			&& summary.cell_count >= 0
			&& boundary_summary.private_zone_words.size() == size_t(summary.cell_count)
			&& terrain_cell_summary.generated_cell_word_0x20.size() == size_t(summary.cell_count)
			&& terrain_cell_summary.generated_cell_word_0x24.size() == size_t(summary.cell_count)
			&& terrain_cell_summary.generated_cell_word_0x28.size() == size_t(summary.cell_count)
			&& terrain_cell_summary.generated_cell_word_0x2c.size() == size_t(summary.cell_count)
			&& terrain_cell_summary.generated_cell_terrain_code.size() == size_t(summary.cell_count)
			&& !runtime_zones.empty();
	if (!supported) {
		summary.blocked_reason = "boundary_owner_words_or_runtime_zones_missing";
		return summary;
	}

	summary.geometry_records = filled_zone_geometry_4a2105_4a2ffa_plain(boundary_summary, runtime_zones);
	summary.relation_geometry_record_count_0x4a2105_0x4a2ffa = int32_t(summary.geometry_records.size());
	for (const FilledZoneGeometryPlain &geometry : summary.geometry_records) {
		if (geometry.has_filled_cells) {
			summary.relation_geometry_filled_record_count_0x4a2105_0x4a2ffa += 1;
		}
	}
	summary.relation_geometry_materialized_plain_cpp = true;
	summary.generated_cell_word_0x20 = terrain_cell_summary.generated_cell_word_0x20;
	summary.generated_cell_word_0x24 = terrain_cell_summary.generated_cell_word_0x24;
	summary.generated_cell_word_0x28 = terrain_cell_summary.generated_cell_word_0x28;
	summary.generated_cell_word_0x2c = terrain_cell_summary.generated_cell_word_0x2c;
	summary.generated_cell_terrain_code = terrain_cell_summary.generated_cell_terrain_code;

	for (int32_t relation_index = 0; relation_index < int32_t(summary.geometry_records.size()); ++relation_index) {
		const FilledZoneGeometryPlain &relation = summary.geometry_records[size_t(relation_index)];
		if (!relation.has_filled_cells) {
			continue;
		}
		if (relation.relation_type_0x0c == 8) {
			summary.terrain_relation_eligibility_relation_type_8_skip_count_0x4a2ec3 += 1;
			continue;
		}
		const int32_t relation_owner_byte2 = relation.zone_word_id;
		const int32_t min_x = std::max<int32_t>(0, relation.filled_rect_min_x_0x20);
		const int32_t min_y = std::max<int32_t>(0, relation.filled_rect_min_y_0x24);
		const int32_t max_x = std::min<int32_t>(summary.width, relation.filled_rect_max_x_exclusive_0x28);
		const int32_t max_y = std::min<int32_t>(summary.height, relation.filled_rect_max_y_exclusive_0x2c);
		if (min_x >= max_x || min_y >= max_y) {
			continue;
		}
		summary.terrain_relation_eligibility_record_count_0x4a2ec3 += 1;
		for (int32_t level = 0; level < summary.level_count; ++level) {
			for (int32_t y = min_y; y < max_y; ++y) {
				for (int32_t x = min_x; x < max_x; ++x) {
					const int32_t flat = level * level_tile_count + y * summary.width + x;
					if (flat < 0 || flat >= summary.cell_count) {
						continue;
					}
					summary.terrain_relation_eligibility_scan_cell_count_0x4a2ec3 += 1;
					const int32_t owner_byte2 = i8_from_u32_byte(summary.generated_cell_word_0x20[size_t(flat)], 16U);
					if (owner_byte2 != relation_owner_byte2) {
						continue;
					}
					summary.terrain_relation_eligibility_owner_match_count_0x4a2ec3 += 1;
					if ((summary.generated_cell_word_0x28[size_t(flat)] & H3MAPED_CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28_PLAIN) == 0U) {
						summary.generated_cell_word_0x28[size_t(flat)] |= H3MAPED_CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28_PLAIN;
						summary.terrain_relation_eligibility_bit28_set_count_0x4a2ec3 += 1;
						if (summary.samples.size() < 16) {
							TerrainRelationEligibilitySamplePlain sample;
							sample.x = x;
							sample.y = y;
							sample.level = level;
							sample.flat_cell_index = flat;
							sample.relation_index = relation_index;
							sample.relation_owner_byte2 = relation_owner_byte2;
							summary.samples.push_back(sample);
						}
					}
				}
			}
		}
	}

	summary.generated_cell_relation_eligibility_materialized = true;
	summary.status = "active_plain_cpp_terrain_relation_eligibility_summary";
	summary.blocked_reason.clear();
	return summary;
}

static constexpr TerrainVisualRowPlain H3_TERRAIN_VISUAL_NORMAL_ROWS_PLAIN[] = {
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
};

static constexpr TerrainVisualRowPlain H3_TERRAIN_VISUAL_DIRT_ROWS_PLAIN[] = {
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 },
	{ 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 13, 0, 0 }, { 13, 0, 0 }, { 16, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 24, 0, 0 },
};

static constexpr TerrainVisualRowPlain H3_TERRAIN_VISUAL_SAND_ROWS_PLAIN[] = {
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
	{ 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 },
};

static constexpr TerrainVisualRowPlain H3_TERRAIN_VISUAL_WATER_ROWS_PLAIN[] = {
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 }, { 9, 0, 0 },
	{ 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 }, { 11, 0, 0 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 13, 0, 0 }, { 13, 0, 0 }, { 16, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 0, 0, 0 },
};

static constexpr TerrainVisualRowPlain H3_TERRAIN_VISUAL_ROCK_ROWS_PLAIN[] = {
	{ 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 },
	{ 8, 0, 0 }, { 8, 0, 0 }, { 8, 1, 0 }, { 8, 1, 0 }, { 8, 0, 1 }, { 8, 0, 1 }, { 8, 1, 1 }, { 8, 1, 1 },
	{ 9, 0, 0 }, { 9, 0, 0 }, { 9, 1, 0 }, { 9, 1, 0 }, { 10, 0, 0 }, { 10, 0, 0 }, { 10, 0, 1 }, { 10, 0, 1 },
	{ 11, 0, 0 }, { 11, 0, 0 }, { 11, 1, 0 }, { 11, 1, 0 }, { 11, 0, 1 }, { 11, 0, 1 }, { 11, 1, 1 }, { 11, 1, 1 },
	{ 12, 0, 0 }, { 12, 0, 0 }, { 12, 1, 0 }, { 12, 1, 0 }, { 12, 0, 1 }, { 12, 0, 1 }, { 12, 1, 1 }, { 12, 1, 1 },
	{ 13, 0, 0 }, { 13, 0, 0 }, { 13, 1, 0 }, { 13, 1, 0 }, { 13, 0, 1 }, { 13, 0, 1 }, { 13, 1, 1 }, { 13, 1, 1 },
};

std::vector<TerrainVisualRowPlain> terrain_visual_rows_from_embedded_plain(const TerrainVisualRowPlain *rows, size_t row_count) {
	return std::vector<TerrainVisualRowPlain>(rows, rows + row_count);
}

TerrainVisualGridTablesPlain load_terrain_visual_grid_tables_plain() {
	TerrainVisualGridTablesPlain tables;
	tables.dirt_rows = terrain_visual_rows_from_embedded_plain(H3_TERRAIN_VISUAL_DIRT_ROWS_PLAIN, sizeof(H3_TERRAIN_VISUAL_DIRT_ROWS_PLAIN) / sizeof(H3_TERRAIN_VISUAL_DIRT_ROWS_PLAIN[0]));
	tables.sand_rows = terrain_visual_rows_from_embedded_plain(H3_TERRAIN_VISUAL_SAND_ROWS_PLAIN, sizeof(H3_TERRAIN_VISUAL_SAND_ROWS_PLAIN) / sizeof(H3_TERRAIN_VISUAL_SAND_ROWS_PLAIN[0]));
	tables.normal_rows = terrain_visual_rows_from_embedded_plain(H3_TERRAIN_VISUAL_NORMAL_ROWS_PLAIN, sizeof(H3_TERRAIN_VISUAL_NORMAL_ROWS_PLAIN) / sizeof(H3_TERRAIN_VISUAL_NORMAL_ROWS_PLAIN[0]));
	tables.water_rows = terrain_visual_rows_from_embedded_plain(H3_TERRAIN_VISUAL_WATER_ROWS_PLAIN, sizeof(H3_TERRAIN_VISUAL_WATER_ROWS_PLAIN) / sizeof(H3_TERRAIN_VISUAL_WATER_ROWS_PLAIN[0]));
	tables.rock_rows = terrain_visual_rows_from_embedded_plain(H3_TERRAIN_VISUAL_ROCK_ROWS_PLAIN, sizeof(H3_TERRAIN_VISUAL_ROCK_ROWS_PLAIN) / sizeof(H3_TERRAIN_VISUAL_ROCK_ROWS_PLAIN[0]));
	return tables;
}

std::vector<int32_t> row_indices_for_class_plain(const std::vector<TerrainVisualRowPlain> &rows, int32_t shape_class) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_group_plain(const std::vector<TerrainVisualRowPlain> &rows, int32_t shape_class, int32_t group_flag) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		if (rows[size_t(index)].shape_class == shape_class && rows[size_t(index)].flag_a == group_flag) {
			indices.push_back(index);
		}
	}
	return indices;
}

std::vector<int32_t> row_indices_for_class_flags_plain(const std::vector<TerrainVisualRowPlain> &rows, int32_t shape_class, int32_t flag_a, int32_t flag_b) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < int32_t(rows.size()); ++index) {
		const TerrainVisualRowPlain &row = rows[size_t(index)];
		if (row.shape_class == shape_class && row.flag_a == flag_a && row.flag_b == flag_b) {
			indices.push_back(index);
		}
	}
	return indices;
}

const std::vector<TerrainVisualRowPlain> &visual_rows_for_terrain_id_plain(const TerrainVisualGridTablesPlain &tables, int32_t terrain_id) {
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

int32_t constructor_probability_for_terrain_id_plain(int32_t terrain_id) {
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

uint32_t h3maped_scratch_word_4bad0f_plain(int32_t terrain_id, int32_t selected_row, int32_t flag_a, int32_t flag_b) {
	return 1U
			| ((uint32_t(terrain_id) & 0x0fU) << 1U)
			| ((uint32_t(selected_row) & 0x7fU) << 5U)
			| ((uint32_t(flag_a) & 0x01U) << 12U)
			| ((uint32_t(flag_b) & 0x01U) << 13U);
}

uint32_t h3maped_generated_cell_terrain_flags_0x49acf6_plain(int32_t flag_a, int32_t flag_b) {
	return (((uint32_t(flag_a) & 0x01U) | ((uint32_t(flag_b) & 0x01U) << 1U)) << H3MAPED_CELL_TERRAIN_FLAG_SHIFT_0X49ACF6_PLAIN);
}

int32_t h3maped_scratch_terrain_id_plain(uint32_t scratch_word) {
	return int32_t((scratch_word >> 1U) & 0x0fU);
}

int32_t h3maped_scratch_art_id_plain(uint32_t scratch_word) {
	return int32_t((scratch_word >> 5U) & 0x7fU);
}

int32_t terrain_trait_flag4_plain(int32_t terrain_id) {
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

int32_t h3maped_terrain_relation_4bb039_plain(int32_t center_terrain_id, int32_t neighbor_terrain_id) {
	if (center_terrain_id == neighbor_terrain_id || center_terrain_id == 1) {
		return 0;
	}
	if (terrain_trait_flag4_plain(center_terrain_id) == 0 || terrain_trait_flag4_plain(neighbor_terrain_id) == 0) {
		return 2;
	}
	return center_terrain_id != 0 ? 1 : 0;
}

int32_t orientation_slot_5436e0_plain(int32_t flag_a, int32_t flag_b, int32_t slot, bool transposed_index = false) {
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

int32_t relation_at_oriented_plain(const std::array<int32_t, 8> &relations, int32_t flag_a, int32_t flag_b, int32_t slot, bool transposed_index = false) {
	return relations[size_t(orientation_slot_5436e0_plain(flag_a, flag_b, slot, transposed_index))];
}

TerrainClassResultPlain h3maped_classify_4bb075_plain(const std::array<int32_t, 8> &relations) {
	static constexpr std::array<std::array<int32_t, 2>, 4> FLAGS = { { { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } } };
	for (const auto &flags : FLAGS) {
		const int32_t a = flags[0];
		const int32_t b = flags[1];
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot, true); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
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
		auto r = [&](int32_t slot) { return relation_at_oriented_plain(relations, a, b, slot); };
		if (r(3) == 1) {
			return { 0x05, a, b };
		}
		if (r(3) == 2) {
			return { 0x0b, a, b };
		}
	}
	return { 0x00, 0, 0 };
}

int32_t terrain_at_grid_index_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t fallback_terrain_id) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return fallback_terrain_id;
	}
	const int32_t index = level * level_tile_count + y * map_width + x;
	if (index < 0 || index >= int32_t(terrain_codes.size())) {
		return fallback_terrain_id;
	}
	return terrain_codes[size_t(index)];
}

bool set_terrain_at_grid_index_plain(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
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

int64_t h3maped_grid_key_plain(int32_t level, int32_t x, int32_t y) {
	return (int64_t(level) << 40) | (int64_t(y) << 20) | int64_t(x);
}

void h3maped_decode_grid_key_plain(int64_t key, int32_t &level, int32_t &x, int32_t &y) {
	level = int32_t(key >> 40);
	y = int32_t((key >> 20) & 0xfffff);
	x = int32_t(key & 0xfffff);
}

std::array<int32_t, 8> h3maped_same_terrain_mask_4bc74c_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	std::array<int32_t, 8> mask = { 0, 0, 0, 0, 0, 0, 0, 0 };
	const auto same = [&](int32_t nx, int32_t ny) -> bool {
		return nx >= 0 && ny >= 0 && nx < map_width && ny < map_height && terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, nx, ny, -1) == terrain_id;
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

std::vector<uint8_t> h3maped_final_sweep_boundary_counts_0x4bbfcc_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_count) {
	const int32_t level_tile_count = map_width * map_height;
	const int32_t expected_tile_count = level_tile_count * std::max(0, level_count);
	std::vector<uint8_t> boundary_counts(size_t(std::max(0, expected_tile_count)), 0);
	if (map_width <= 0 || map_height <= 0 || level_count <= 0 || int32_t(terrain_codes.size()) != expected_tile_count) {
		return boundary_counts;
	}
	auto increment_if_different = [&](int32_t level_base, int32_t x, int32_t y, int32_t nx, int32_t ny) {
		if (nx < 0 || ny < 0 || nx >= map_width || ny >= map_height) {
			return;
		}
		const int32_t index = level_base + y * map_width + x;
		const int32_t neighbor_index = level_base + ny * map_width + nx;
		if (terrain_codes[size_t(index)] == terrain_codes[size_t(neighbor_index)]) {
			return;
		}
		boundary_counts[size_t(index)] = uint8_t(std::min<int32_t>(255, int32_t(boundary_counts[size_t(index)]) + 1));
		boundary_counts[size_t(neighbor_index)] = uint8_t(std::min<int32_t>(255, int32_t(boundary_counts[size_t(neighbor_index)]) + 1));
	};
	for (int32_t level = 0; level < level_count; ++level) {
		const int32_t level_base = level * level_tile_count;
		for (int32_t y = 0; y < map_height; ++y) {
			for (int32_t x = 0; x < map_width; ++x) {
				increment_if_different(level_base, x, y, x + 1, y);
				increment_if_different(level_base, x, y, x, y + 1);
				increment_if_different(level_base, x, y, x + 1, y + 1);
				increment_if_different(level_base, x, y, x - 1, y + 1);
			}
		}
	}
	return boundary_counts;
}

bool h3maped_same_class_region_gate_4bc928_plain(const std::array<int32_t, 8> &mask) {
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

bool h3maped_horizontal_pair_gate_4bc674_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (x <= 0 || x >= map_width - 1 || y < 0 || y >= map_height) {
		return false;
	}
	const int32_t west = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
	const int32_t east = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
	return west != terrain_id && east != terrain_id;
}

bool h3maped_vertical_pair_gate_4bc6e0_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t terrain_id) {
	if (y <= 0 || y >= map_height - 1 || x < 0 || x >= map_width) {
		return false;
	}
	const int32_t north = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
	const int32_t south = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
	return north != terrain_id && south != terrain_id;
}

bool h3maped_toolkit_byte5_allows_same_class_gate_plain(int32_t terrain_id) {
	return terrain_id == 8 || terrain_id == 9;
}

bool h3maped_candidate_gate_4bc988_grid_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return false;
	}
	const int32_t terrain_id = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return false;
	}
	const bool horizontal_pair_gate = h3maped_horizontal_pair_gate_4bc674_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool vertical_pair_gate = h3maped_vertical_pair_gate_4bc6e0_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	const bool same_class_region_gate = h3maped_same_class_region_gate_4bc928_plain(h3maped_same_terrain_mask_4bc74c_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id));
	return horizontal_pair_gate || vertical_pair_gate || (h3maped_toolkit_byte5_allows_same_class_gate_plain(terrain_id) && same_class_region_gate);
}

int32_t h3maped_frontier_retouch_4bbd01_plain(std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, std::vector<TerrainLiveFeedbackDrainSamplePlain> *sample_records, int32_t sample_limit, std::vector<int64_t> *changed_keys_out = nullptr) {
	if (x < 0 || y < 0 || x >= map_width || y >= map_height) {
		return 0;
	}
	const int32_t terrain_id = terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, -1);
	if (terrain_id < 0) {
		return 0;
	}
	int32_t changed_count = 0;
	auto retouch = [&](const char *branch, int32_t target_x, int32_t target_y) {
		const bool in_bounds = target_x >= 0 && target_y >= 0 && target_x < map_width && target_y < map_height;
		const bool changed = set_terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, target_x, target_y, terrain_id);
		if (changed) {
			changed_count += 1;
		}
		if (in_bounds && changed_keys_out != nullptr) {
			changed_keys_out->push_back(h3maped_grid_key_plain(level, target_x, target_y));
		}
		if (sample_records != nullptr && int32_t(sample_records->size()) < sample_limit) {
			TerrainLiveFeedbackDrainSamplePlain sample;
			sample.branch = branch;
			sample.from_x = x;
			sample.from_y = y;
			sample.target_x = target_x;
			sample.target_y = target_y;
			sample.level = level;
			sample.terrain_id = terrain_id;
			sample.changed_terrain = changed;
			sample.is_retouch = true;
			sample_records->push_back(sample);
		}
	};
	if (h3maped_vertical_pair_gate_4bc6e0_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool upper_candidate = h3maped_candidate_gate_4bc988_grid_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1);
		const bool lower_candidate = h3maped_candidate_gate_4bc988_grid_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1);
		bool choose_upper = upper_candidate;
		if (!upper_candidate && !lower_candidate) {
			const bool upper_horizontal_pair = h3maped_horizontal_pair_gate_4bc674_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, terrain_id);
			const bool lower_horizontal_pair = h3maped_horizontal_pair_gate_4bc674_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, terrain_id);
			choose_upper = !upper_horizontal_pair || lower_horizontal_pair;
		}
		retouch(choose_upper ? "0x4bbd01_vertical_upper" : "0x4bbd01_vertical_lower", x, choose_upper ? y - 1 : y + 1);
	}
	if (h3maped_horizontal_pair_gate_4bc674_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id)) {
		const bool left_candidate = h3maped_candidate_gate_4bc988_grid_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y);
		const bool right_candidate = h3maped_candidate_gate_4bc988_grid_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y);
		bool choose_left = left_candidate;
		if (!left_candidate && !right_candidate) {
			const bool left_vertical_pair = h3maped_vertical_pair_gate_4bc6e0_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, terrain_id);
			const bool right_vertical_pair = h3maped_vertical_pair_gate_4bc6e0_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, terrain_id);
			choose_left = !left_vertical_pair || right_vertical_pair;
		}
		retouch(choose_left ? "0x4bbd01_horizontal_left" : "0x4bbd01_horizontal_right", choose_left ? x - 1 : x + 1, y);
	}
	const std::array<int32_t, 8> same_terrain_mask = h3maped_same_terrain_mask_4bc74c_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y, terrain_id);
	if (h3maped_toolkit_byte5_allows_same_class_gate_plain(terrain_id) && h3maped_same_class_region_gate_4bc928_plain(same_terrain_mask)) {
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

TerrainClassResultPlain classify_grid_cell_plain(const std::vector<int32_t> &terrain_codes, int32_t map_width, int32_t map_height, int32_t level_tile_count, int32_t level, int32_t x, int32_t y, int32_t center) {
	std::array<int32_t, 8> relations = {
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y - 1, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y - 1, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x + 1, y + 1, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x, y + 1, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y + 1, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y, center)),
		h3maped_terrain_relation_4bb039_plain(center, terrain_at_grid_index_plain(terrain_codes, map_width, map_height, level_tile_count, level, x - 1, y - 1, center)),
	};
	return h3maped_classify_4bb075_plain(relations);
}

bool select_visual_row_for_grid_cell_with_neighbor_mask_plain(const std::vector<TerrainVisualRowPlain> &rows, int32_t terrain_id, const TerrainClassResultPlain &classified, int32_t neighbor_mask, H3MapedRng &rng, int32_t &selected_row, int32_t &out_flag_a, int32_t &out_flag_b, std::string &selector_address, std::string &selector_kind, int32_t &probability_threshold, int32_t &probability_rng_value) {
	std::vector<int32_t> bucket;
	probability_threshold = -1;
	probability_rng_value = -1;
	if (terrain_id == 9) {
		selector_address = "0x4baabf";
		selector_kind = "rock_class_flag_bucket";
		bucket = row_indices_for_class_flags_plain(rows, classified.shape_class, classified.flag_a, classified.flag_b);
		out_flag_a = 0;
		out_flag_b = 0;
	} else if (classified.shape_class == 0) {
		selector_address = "0x4ba938";
		selector_kind = "full_native_special_frequency_masked_by_0x4bce6d";
		const std::vector<int32_t> ordinary = row_indices_for_class_group_plain(rows, 0, 0);
		const std::vector<int32_t> special = row_indices_for_class_group_plain(rows, 0, 1);
		if (!special.empty()) {
			probability_rng_value = rng.next();
			probability_threshold = (constructor_probability_for_terrain_id_plain(terrain_id) * std::max(0, neighbor_mask)) / 8;
			bucket = (probability_rng_value % 100) < probability_threshold ? special : ordinary;
		} else {
			bucket = ordinary;
		}
		out_flag_a = 0;
		out_flag_b = 0;
	} else {
		selector_address = "0x4ba989";
		selector_kind = "transition_class_bucket";
		bucket = row_indices_for_class_plain(rows, classified.shape_class);
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

TerrainLiveFeedbackSummaryPlain build_terrain_live_feedback_summary(const TerrainRelationEligibilitySummaryPlain &relation_summary, const RuntimeTerrainSelectionSummaryPlain &terrain_summary) {
	TerrainLiveFeedbackSummaryPlain summary;
	summary.terrain_relation_eligibility_available = relation_summary.generated_cell_relation_eligibility_materialized;
	summary.width = relation_summary.width;
	summary.height = relation_summary.height;
	summary.level_count = relation_summary.level_count;
	summary.cell_count = relation_summary.cell_count;
	summary.geometry_records = relation_summary.geometry_records;
	summary.rng_state_before_live_visual_selection = terrain_summary.rng_state_after_0x49b53d;
	summary.rng_state_after_live_visual_selection = terrain_summary.rng_state_after_0x49b53d;
	const int32_t level_tile_count = summary.width * summary.height;
	const bool supported = summary.terrain_relation_eligibility_available
			&& terrain_summary.materializes_runtime_zone_terrain_ids
			&& summary.width > 0
			&& summary.height > 0
			&& summary.level_count > 0
			&& summary.cell_count > 0
			&& relation_summary.generated_cell_word_0x20.size() == size_t(summary.cell_count)
			&& relation_summary.generated_cell_word_0x24.size() == size_t(summary.cell_count)
			&& relation_summary.generated_cell_word_0x28.size() == size_t(summary.cell_count)
			&& relation_summary.generated_cell_word_0x2c.size() == size_t(summary.cell_count)
			&& relation_summary.generated_cell_terrain_code.size() == size_t(summary.cell_count);
	if (!supported) {
		summary.blocked_reason = "terrain_relation_eligibility_or_runtime_terrain_missing";
		return summary;
	}

	TerrainVisualGridTablesPlain tables = load_terrain_visual_grid_tables_plain();
	summary.visual_tables_decoded = tables.dirt_rows.size() == 46 && tables.sand_rows.size() == 24 && tables.normal_rows.size() == 79 && tables.water_rows.size() == 33 && tables.rock_rows.size() == 48;
	if (!summary.visual_tables_decoded) {
		summary.status = "visual_table_decode_failed";
		summary.blocked_reason = "embedded_visual_table_row_count_mismatch";
		return summary;
	}

	const std::vector<int32_t> final_terrain_code = relation_summary.generated_cell_terrain_code;
	std::vector<int32_t> live_terrain_code(size_t(summary.cell_count), 8);
	std::vector<uint32_t> live_scratch_word(size_t(summary.cell_count), 0);
	std::vector<uint32_t> live_cell_word_0x20 = relation_summary.generated_cell_word_0x20;
	std::vector<uint32_t> live_cell_word_0x24 = relation_summary.generated_cell_word_0x24;
	std::vector<uint32_t> live_cell_word_0x28 = relation_summary.generated_cell_word_0x28;
	std::vector<uint32_t> live_cell_word_0x2c = relation_summary.generated_cell_word_0x2c;
	for (int32_t index = 0; index < summary.cell_count; ++index) {
		if (live_cell_word_0x20[size_t(index)] == 0xffff7fbcU) {
			summary.live_cell_word_0x20_unassigned_sentinel_count += 1;
		} else {
			summary.live_cell_word_0x20_owner_byte_materialized_count += 1;
		}
	}

	H3MapedRng live_visual_rng { summary.rng_state_before_live_visual_selection };
	auto live_accept_neighbor = [&](int32_t neighbor_index, int32_t terrain_id) -> bool {
		if (neighbor_index < 0 || neighbor_index >= summary.cell_count) {
			return false;
		}
		const uint32_t neighbor_scratch = live_scratch_word[size_t(neighbor_index)];
		return (neighbor_scratch & 0x01U) != 0U && h3maped_scratch_terrain_id_plain(neighbor_scratch) == terrain_id && h3maped_scratch_art_id_plain(neighbor_scratch) != 0;
	};
	auto live_neighbor_mask_for_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id) -> int32_t {
		const int32_t index = level * level_tile_count + y * summary.width + x;
		int32_t mask = 4;
		if (x > 0 && live_accept_neighbor(index - 1, terrain_id)) {
			mask >>= 1;
		}
		if (y > 0 && live_accept_neighbor(index - summary.width, terrain_id)) {
			mask >>= 1;
		}
		if (x + 1 < summary.width && live_accept_neighbor(index + 1, terrain_id)) {
			mask >>= 1;
		}
		if (y + 1 < summary.height && live_accept_neighbor(index + summary.width, terrain_id)) {
			mask >>= 1;
		}
		return mask;
	};
	auto apply_final_sweep_class_correction_0x4bbfcc = [&](TerrainClassResultPlain classified, bool apply_correction) -> TerrainClassResultPlain {
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
			summary.final_sweep_class_correction_count_0x4bbfcc += 1;
			summary.final_sweep_class_correction_histogram_0x4bbfcc[std::to_string(classified.shape_class) + "->" + std::to_string(corrected_class)] += 1;
			classified.shape_class = corrected_class;
		}
		return classified;
	};
	auto write_live_visual_cell = [&](int32_t level, int32_t x, int32_t y, int32_t terrain_id, const char *source_branch, bool apply_final_sweep_class_correction = false) -> bool {
		if (x < 0 || y < 0 || x >= summary.width || y >= summary.height) {
			return false;
		}
		const int32_t index = level * level_tile_count + y * summary.width + x;
		if (index < 0 || index >= summary.cell_count) {
			return false;
		}
		summary.live_visual_attempt_count += 1;
		const TerrainClassResultPlain classified = apply_final_sweep_class_correction_0x4bbfcc(classify_grid_cell_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, terrain_id), apply_final_sweep_class_correction);
		const int32_t neighbor_mask = live_neighbor_mask_for_cell(level, x, y, terrain_id);
		summary.neighbor_mask_histogram[neighbor_mask] += 1;
		if (classified.shape_class == 0) {
			summary.live_full_native_cell_count += 1;
		}
		int32_t selected_row = -1;
		int32_t out_flag_a = 0;
		int32_t out_flag_b = 0;
		int32_t probability_threshold = -1;
		int32_t probability_rng_value = -1;
		std::string selector_address;
		std::string selector_kind;
		const std::vector<TerrainVisualRowPlain> &rows = visual_rows_for_terrain_id_plain(tables, terrain_id);
		const bool selected = select_visual_row_for_grid_cell_with_neighbor_mask_plain(rows, terrain_id, classified, neighbor_mask, live_visual_rng, selected_row, out_flag_a, out_flag_b, selector_address, selector_kind, probability_threshold, probability_rng_value);
		summary.selector_kind_histogram[selector_kind] += 1;
		if (!selected) {
			summary.live_visual_missing_bucket_count += 1;
			return false;
		}
		const uint32_t scratch_word = h3maped_scratch_word_4bad0f_plain(terrain_id, selected_row, out_flag_a, out_flag_b);
		const uint32_t generated_cell_word_0x24 = (live_cell_word_0x24[size_t(index)] & 0xffffc000U)
				| (uint32_t(terrain_id) & 0x3fU)
				| ((uint32_t(selected_row) & 0xffU) << 6U);
		const uint32_t generated_cell_word_0x28 = (live_cell_word_0x28[size_t(index)] & ~H3MAPED_CELL_TERRAIN_FLAG_MASK_0X49ACF6_PLAIN)
				| h3maped_generated_cell_terrain_flags_0x49acf6_plain(out_flag_a, out_flag_b);
		live_scratch_word[size_t(index)] = scratch_word;
		live_cell_word_0x24[size_t(index)] = generated_cell_word_0x24;
		live_cell_word_0x28[size_t(index)] = generated_cell_word_0x28;
		summary.live_cell_word_0x28_bit25_default_write_count += 1;
		summary.live_visual_write_count += 1;
		if (selected_row != 0) {
			summary.live_terrain_art_nonzero_cell_count += 1;
		}
		if ((generated_cell_word_0x28 & H3MAPED_CELL_TERRAIN_FLAG_MASK_0X49ACF6_PLAIN) != 0U) {
			summary.live_terrain_flag_cell_count += 1;
		}
		if (summary.samples.size() < 16 && (classified.shape_class == 0 || neighbor_mask < 4)) {
			TerrainLiveFeedbackSamplePlain sample;
			sample.index = index;
			sample.x = x;
			sample.y = y;
			sample.level = level;
			sample.terrain_id = terrain_id;
			sample.shape_class = classified.shape_class;
			sample.neighbor_mask = neighbor_mask;
			sample.source_branch = source_branch;
			sample.selector_address = selector_address;
			sample.selector_kind = selector_kind;
			sample.probability_threshold = probability_threshold;
			sample.probability_rng_value = probability_rng_value;
			sample.selected_row = selected_row;
			sample.scratch_word = scratch_word;
			sample.generated_cell_word_0x24 = generated_cell_word_0x24;
			sample.generated_cell_word_0x28 = generated_cell_word_0x28;
			summary.samples.push_back(sample);
		}
		return true;
	};

	for (int32_t level = 0; level < summary.level_count; ++level) {
		for (int32_t y = 0; y < summary.height; ++y) {
			for (int32_t x = 0; x < summary.width; ++x) {
				summary.live_initial_water_attempt_count += 1;
				write_live_visual_cell(level, x, y, 8, "0x4a4025_initial_water_repaint");
			}
		}
	}

	std::set<int64_t> set_a;
	std::set<int64_t> set_b;
	auto append_set_b = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, const char *source_branch) {
		if (x < 0 || y < 0 || x >= summary.width || y >= summary.height) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, current_terrain);
		if (neighbor == current_terrain) {
			return;
		}
		if (set_b.insert(h3maped_grid_key_plain(level, x, y)).second) {
			summary.total_set_b_insert_count += 1;
		}
		if (summary.seed_samples.size() < 12) {
			TerrainLiveFeedbackSeedSamplePlain sample;
			sample.x = x;
			sample.y = y;
			sample.level = level;
			sample.terrain_before_drain = neighbor;
			sample.current_repaint_terrain = current_terrain;
			sample.source_branch = source_branch;
			summary.seed_samples.push_back(sample);
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
			const int32_t neighbor = terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, nx, ny, current_terrain);
			if (h3maped_toolkit_byte5_allows_same_class_gate_plain(neighbor)) {
				append_set_b(level, nx, ny, current_terrain, "0x4bba59_diagonal_byte5_zero_neighbor");
			}
		}
	};
	auto append_set_a = [&](int32_t level, int32_t x, int32_t y, const char *source_branch) {
		if (x < 0 || y < 0 || x >= summary.width || y >= summary.height) {
			return;
		}
		if (set_a.insert(h3maped_grid_key_plain(level, x, y)).second) {
			summary.total_set_a_insert_count += 1;
		}
		if (summary.drain_samples.size() < 16) {
			TerrainLiveFeedbackDrainSamplePlain sample;
			sample.x = x;
			sample.y = y;
			sample.level = level;
			sample.source_branch = source_branch;
			sample.terrain_id = terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, -1);
			summary.drain_samples.push_back(sample);
		}
	};
	auto process_4bb74b_set_a_neighbor = [&](int32_t level, int32_t x, int32_t y, int32_t current_terrain, bool horizontal_pair_wrapper) {
		if (x < 0 || y < 0 || x >= summary.width || y >= summary.height) {
			return;
		}
		const int64_t key = h3maped_grid_key_plain(level, x, y);
		auto found = set_a.find(key);
		if (found == set_a.end()) {
			return;
		}
		const int32_t neighbor = terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, current_terrain);
		const bool gate = horizontal_pair_wrapper ? h3maped_horizontal_pair_gate_4bc674_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, neighbor) : h3maped_vertical_pair_gate_4bc6e0_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, neighbor);
		if (!gate) {
			set_a.erase(found);
			summary.total_set_a_neighbor_remove_count += 1;
			seed_4bba59(level, x, y, current_terrain);
		}
	};
	auto process_4bb74b_topology = [&](int32_t level, int32_t x, int32_t y, int32_t active_terrain) {
		if (active_terrain < 0) {
			return;
		}
		set_terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, active_terrain);
		summary.live_queue_attempt_count += 1;
		write_live_visual_cell(level, x, y, active_terrain, "0x4bb74b_queue_live_visual_feedback");
		const int64_t current_key = h3maped_grid_key_plain(level, x, y);
		if (set_b.erase(current_key) > 0) {
			summary.total_set_b_current_remove_count += 1;
		}
		if (!h3maped_toolkit_byte5_allows_same_class_gate_plain(active_terrain)) {
			process_4bb74b_set_a_neighbor(level, x, y - 1, active_terrain, true);
			process_4bb74b_set_a_neighbor(level, x, y + 1, active_terrain, true);
			process_4bb74b_set_a_neighbor(level, x - 1, y, active_terrain, false);
			process_4bb74b_set_a_neighbor(level, x + 1, y, active_terrain, false);
		} else if (h3maped_candidate_gate_4bc988_grid_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y)) {
			append_set_a(level, x, y, "0x4bb9ed_current_candidate_to_set_a");
		} else {
			seed_4bba59(level, x, y, active_terrain);
		}
	};
	auto update_max_queue_counts = [&]() {
		summary.max_set_a_count = std::max(summary.max_set_a_count, int32_t(set_a.size()));
		summary.max_set_b_count = std::max(summary.max_set_b_count, int32_t(set_b.size()));
	};

	int64_t drain_guard_count = 0;
	summary.drain_guard_limit = std::max<int64_t>(32768, int64_t(summary.cell_count) * 128);
	auto drain_queue_for_active_terrain = [&](int32_t active_terrain) {
		update_max_queue_counts();
		while ((!set_a.empty() || !set_b.empty()) && drain_guard_count < summary.drain_guard_limit) {
			drain_guard_count += 1;
			while (!set_a.empty() && drain_guard_count < summary.drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_a.begin();
				set_a.erase(set_a.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				h3maped_decode_grid_key_plain(key, level, x, y);
				summary.set_a_drain_count += 1;
				std::vector<int64_t> changed_keys;
				summary.retouched_cell_write_count += h3maped_frontier_retouch_4bbd01_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, &summary.drain_samples, 24, &changed_keys);
				for (int64_t changed_key : changed_keys) {
					int32_t changed_level = 0;
					int32_t changed_x = 0;
					int32_t changed_y = 0;
					h3maped_decode_grid_key_plain(changed_key, changed_level, changed_x, changed_y);
					process_4bb74b_topology(changed_level, changed_x, changed_y, active_terrain);
				}
				update_max_queue_counts();
			}
			while (set_a.empty() && !set_b.empty() && drain_guard_count < summary.drain_guard_limit) {
				drain_guard_count += 1;
				const int64_t key = *set_b.begin();
				set_b.erase(set_b.begin());
				int32_t level = 0;
				int32_t x = 0;
				int32_t y = 0;
				h3maped_decode_grid_key_plain(key, level, x, y);
				summary.set_b_drain_count += 1;
				if (h3maped_candidate_gate_4bc988_grid_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y)) {
					summary.set_b_candidate_true_count += 1;
					process_4bb74b_topology(level, x, y, active_terrain);
				}
				update_max_queue_counts();
			}
		}
		set_a.clear();
		set_b.clear();
	};

	for (int32_t relation_index = 0; relation_index < int32_t(relation_summary.geometry_records.size()); ++relation_index) {
		const FilledZoneGeometryPlain &relation = relation_summary.geometry_records[size_t(relation_index)];
		if (!relation.has_filled_cells) {
			continue;
		}
		if (relation.relation_type_0x0c == 8) {
			summary.terrain_relation_repaint_type8_skip_count_0x4a4082 += 1;
			continue;
		}
		const int32_t runtime_index = relation.runtime_zone_index;
		if (runtime_index < 0 || runtime_index >= int32_t(terrain_summary.selected_h3maped_terrain_ids.size())) {
			continue;
		}
		const int32_t terrain = terrain_summary.selected_h3maped_terrain_ids[size_t(runtime_index)];
		if (terrain == 8) {
			continue;
		}
		const int32_t relation_owner_byte2 = relation.zone_word_id;
		const int32_t min_x = std::max<int32_t>(0, relation.filled_rect_min_x_0x20);
		const int32_t min_y = std::max<int32_t>(0, relation.filled_rect_min_y_0x24);
		const int32_t max_x = std::min<int32_t>(summary.width, relation.filled_rect_max_x_exclusive_0x28);
		const int32_t max_y = std::min<int32_t>(summary.height, relation.filled_rect_max_y_exclusive_0x2c);
		if (min_x >= max_x || min_y >= max_y) {
			continue;
		}
		summary.terrain_relation_repaint_record_count_0x4a4082 += 1;
		for (int32_t level = 0; level < summary.level_count; ++level) {
			for (int32_t y = min_y; y < max_y; ++y) {
				for (int32_t x = min_x; x < max_x; ++x) {
					const int32_t index = level * level_tile_count + y * summary.width + x;
					if (index < 0 || index >= summary.cell_count) {
						continue;
					}
					summary.terrain_relation_repaint_scan_cell_count_0x4a4082 += 1;
					const int32_t owner_byte2 = i8_from_u32_byte(live_cell_word_0x20[size_t(index)], 16U);
					if (owner_byte2 != relation_owner_byte2) {
						summary.terrain_relation_repaint_owner_mismatch_count_0x4a4082 += 1;
						continue;
					}
					if ((live_cell_word_0x28[size_t(index)] & H3MAPED_CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28_PLAIN) == 0U) {
						summary.terrain_relation_repaint_bit28_reject_count_0x4a4082 += 1;
						continue;
					}
					summary.changed_cell_update_count += 1;
					if (set_terrain_at_grid_index_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y, terrain)) {
						summary.live_repaint_attempt_count += 1;
						write_live_visual_cell(level, x, y, terrain, "0x4a4082_relation_rect_bit28_repaint_live_visual_feedback");
						const int64_t current_key = h3maped_grid_key_plain(level, x, y);
						if (set_b.erase(current_key) > 0) {
							summary.total_set_b_current_remove_count += 1;
						}
						if (h3maped_candidate_gate_4bc988_grid_plain(live_terrain_code, summary.width, summary.height, level_tile_count, level, x, y)) {
							append_set_a(level, x, y, "0x4bb9ed_repaint_candidate_to_set_a");
						} else {
							seed_4bba59(level, x, y, terrain);
						}
						if (!h3maped_toolkit_byte5_allows_same_class_gate_plain(terrain)) {
							process_4bb74b_set_a_neighbor(level, x, y - 1, terrain, true);
							process_4bb74b_set_a_neighbor(level, x, y + 1, terrain, true);
							process_4bb74b_set_a_neighbor(level, x - 1, y, terrain, false);
							process_4bb74b_set_a_neighbor(level, x + 1, y, terrain, false);
						}
					}
				}
			}
		}
		drain_queue_for_active_terrain(terrain);
	}

	const std::vector<uint8_t> final_sweep_boundary_counts_0x4bbfcc = h3maped_final_sweep_boundary_counts_0x4bbfcc_plain(live_terrain_code, summary.width, summary.height, summary.level_count);
	for (int32_t level = 0; level < summary.level_count; ++level) {
		const int32_t level_base = level * level_tile_count;
		for (int32_t y = 0; y < summary.height; ++y) {
			for (int32_t x = 0; x < summary.width; ++x) {
				const int32_t index = level_base + y * summary.width + x;
				if (index < 0 || index >= summary.cell_count) {
					continue;
				}
				const int32_t boundary_count = index < int32_t(final_sweep_boundary_counts_0x4bbfcc.size()) ? int32_t(final_sweep_boundary_counts_0x4bbfcc[size_t(index)]) : 0;
				summary.final_sweep_boundary_count_histogram_0x4bbfcc[boundary_count] += 1;
				if (boundary_count > 0) {
					summary.final_sweep_boundary_cell_count_0x4bbfcc += 1;
				} else {
					summary.final_sweep_zero_boundary_cell_count_0x4bbfcc += 1;
				}
				summary.final_sweep_max_boundary_count_0x4bbfcc = std::max(summary.final_sweep_max_boundary_count_0x4bbfcc, boundary_count);
				summary.final_sweep_cell_count_0x4bbfcc += write_live_visual_cell(level, x, y, live_terrain_code[size_t(index)], "0x4bbfcc_final_whole_map_sweep", true) ? 1 : 0;
			}
		}
	}

	for (int32_t index = 0; index < summary.cell_count; ++index) {
		const uint32_t scratch_word = live_scratch_word[size_t(index)];
		if ((scratch_word & 0x01U) != 0U) {
			summary.live_dirty_cell_count += 1;
		}
		const uint32_t roundtrip_0x24 = (uint32_t(h3maped_scratch_terrain_id_plain(scratch_word)) & 0x3fU) | ((uint32_t(h3maped_scratch_art_id_plain(scratch_word)) & 0xffU) << 6U);
		const uint32_t roundtrip_0x28_flags = h3maped_generated_cell_terrain_flags_0x49acf6_plain(int32_t((scratch_word >> 12U) & 0x01U), int32_t((scratch_word >> 13U) & 0x01U));
		if (roundtrip_0x24 != (live_cell_word_0x24[size_t(index)] & 0x00003fffU)
				|| roundtrip_0x28_flags != (live_cell_word_0x28[size_t(index)] & H3MAPED_CELL_TERRAIN_FLAG_MASK_0X49ACF6_PLAIN)) {
			summary.live_roundtrip_mismatch_count += 1;
		}
		if (int32_t(live_cell_word_0x24[size_t(index)] & 0x3fU) != live_terrain_code[size_t(index)]) {
			summary.live_terrain_mismatch_count += 1;
		}
		if (live_terrain_code[size_t(index)] != final_terrain_code[size_t(index)]) {
			summary.post_queue_terrain_difference_count += 1;
		}
	}

	summary.generated_cell_word_0x20 = live_cell_word_0x20;
	summary.generated_cell_word_0x24 = live_cell_word_0x24;
	summary.generated_cell_word_0x28 = live_cell_word_0x28;
	summary.generated_cell_word_0x2c = live_cell_word_0x2c;
	summary.generated_cell_terrain_code = live_terrain_code;
	summary.rng_state_after_live_visual_selection = live_visual_rng.state;
	summary.drain_guard_exhausted = drain_guard_count >= summary.drain_guard_limit;
	summary.exact_queue_drain_complete = !summary.drain_guard_exhausted;
	summary.live_feedback_materialized = true;
	summary.materializes_private_generated_cell_words = true;
	summary.status = "active_plain_cpp_terrain_live_feedback";
	summary.blocked_reason.clear();
	return summary;
}

GeneratedCellBitHelperSummaryPlain build_generated_cell_bit_helper_summary(const TerrainLiveFeedbackSummaryPlain &terrain_summary) {
	GeneratedCellBitHelperSummaryPlain summary;
	summary.terrain_live_feedback_available = terrain_summary.materializes_private_generated_cell_words;
	summary.width = terrain_summary.width;
	summary.height = terrain_summary.height;
	summary.level_count = terrain_summary.level_count;
	summary.cell_count = terrain_summary.cell_count;
	summary.supported_scope = terrain_summary.width > 0
			&& terrain_summary.height > 0
			&& terrain_summary.level_count == 1
			&& terrain_summary.cell_count > 0;
	const bool supported = summary.terrain_live_feedback_available
			&& summary.supported_scope
			&& terrain_summary.generated_cell_word_0x20.size() == size_t(summary.cell_count)
			&& terrain_summary.generated_cell_word_0x24.size() == size_t(summary.cell_count)
			&& terrain_summary.generated_cell_word_0x28.size() == size_t(summary.cell_count)
			&& terrain_summary.generated_cell_word_0x2c.size() == size_t(summary.cell_count)
			&& terrain_summary.generated_cell_terrain_code.size() == size_t(summary.cell_count);
	if (!supported) {
		summary.status = "blocked_generated_cell_bit_helpers_missing_live_grid";
		summary.blocked_reason = "terrain_live_feedback_generated_cell_words_missing_or_unsupported_scope";
		return summary;
	}

	summary.helper_contracts_ported_plain_cpp = true;
	std::vector<uint32_t> diagnostic_word_0x28 = terrain_summary.generated_cell_word_0x28;
	const std::vector<uint32_t> &word_0x24 = terrain_summary.generated_cell_word_0x24;
	const std::vector<uint32_t> &word_0x2c = terrain_summary.generated_cell_word_0x2c;
	for (int32_t flat = 0; flat < summary.cell_count; ++flat) {
		const uint32_t word28 = diagnostic_word_0x28[size_t(flat)];
		const uint32_t word24 = word_0x24[size_t(flat)];
		const uint32_t word2c = word_0x2c[size_t(flat)];
		if ((word2c & 0x1U) != 0U) {
			summary.word_0x2c_bit0_lock_count += 1;
		}
		if ((word28 & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) != 0U) {
			summary.source_bit26_count += 1;
		}
		if ((word28 & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) != 0U) {
			summary.source_bit27_count += 1;
		}
		if (h3maped_generated_cell_49a1d8_valid_plain(diagnostic_word_0x28, word_0x24, flat)) {
			summary.valid_0x49a1d8_count += 1;
		} else {
			summary.invalid_0x49a1d8_count += 1;
			if ((word28 & H3MAPED_CELL_DECOR_READY_BIT_25_PLAIN) == 0U) {
				summary.invalid_0x49a1d8_bit25_clear_count += 1;
			}
			if ((word24 & 0x3fU) == 9U) {
				summary.invalid_0x49a1d8_terrain9_count += 1;
			}
		}
	}

	for (int32_t level = 0; level < summary.level_count; ++level) {
		for (int32_t y = 0; y < summary.height; ++y) {
			for (int32_t x = 0; x < summary.width; ++x) {
				const int64_t flat64 = h3maped_generated_cell_flat_plain(summary.width, summary.height, x, y, level);
				if (flat64 < 0 || flat64 >= summary.cell_count) {
					continue;
				}
				const int32_t flat = int32_t(flat64);
				const uint32_t terrain_id = word_0x24[size_t(flat)] & 0x3fU;
				if (terrain_id == 8U || terrain_id == 9U) {
					summary.terrain_8_9_occupied_scan_count += 1;
					if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
						summary.terrain_8_9_0x2c_skip_count += 1;
					} else if (h3maped_generated_cell_49a932_plain(diagnostic_word_0x28, word_0x2c, flat, true)) {
						summary.terrain_8_9_occupied_set_count_0x49a932 += 1;
					}
				}
				if ((diagnostic_word_0x28[size_t(flat)] & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) == 0U) {
					continue;
				}
				summary.candidate_0x49a962_call_count += 1;
				if (h3maped_generated_cell_49aa63_plain(diagnostic_word_0x28, word_0x2c, flat, true)) {
					summary.candidate_0x49a962_center_set_count += 1;
				}
				for (int32_t local_y = std::max<int32_t>(0, y - 1); local_y < std::min<int32_t>(summary.height, y + 2); ++local_y) {
					for (int32_t local_x = std::max<int32_t>(0, x - 1); local_x < std::min<int32_t>(summary.width, x + 2); ++local_x) {
						const int64_t neighbor_flat = h3maped_generated_cell_flat_plain(summary.width, summary.height, local_x, local_y, level);
						if (neighbor_flat < 0 || neighbor_flat >= summary.cell_count) {
							continue;
						}
						summary.candidate_0x49a962_neighbor_scan_count += 1;
						if ((diagnostic_word_0x28[size_t(neighbor_flat)] & H3MAPED_CELL_ACTION_CONTROL_BIT_22_PLAIN) != 0U) {
							summary.candidate_0x49a962_neighbor_bit22_skip_count += 1;
							continue;
						}
						if (!h3maped_generated_cell_49a1d8_valid_plain(diagnostic_word_0x28, word_0x24, neighbor_flat)) {
							summary.candidate_0x49a962_neighbor_invalid_skip_count += 1;
							continue;
						}
						if ((word_0x24[size_t(neighbor_flat)] & 0x3fU) == 8U) {
							summary.candidate_0x49a962_neighbor_terrain8_skip_count += 1;
							continue;
						}
						if (h3maped_generated_cell_49a932_plain(diagnostic_word_0x28, word_0x2c, neighbor_flat, false)) {
							summary.candidate_0x49a962_neighbor_clear_count_0x49a932 += 1;
						}
					}
				}
			}
		}
	}
	for (uint32_t word : diagnostic_word_0x28) {
		if ((word & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) != 0U) {
			summary.diagnostic_final_bit26_count += 1;
		}
		if ((word & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) != 0U) {
			summary.diagnostic_final_bit27_count += 1;
		}
	}
	summary.status = "diagnostic_plain_cpp_generated_cell_bit_helpers_ported";
	summary.blocked_reason = "live_grid_mutation_not_adopted_until_exact_object_reference_vectors_and_0x4a8260_route_rng_boundary_are_ported";
	return summary;
}

RelationNormalizationContractSummaryPlain build_relation_normalization_contract_summary(
		const ControlledCase &controlled_case,
		const RuntimeZoneSummary &runtime_zone_summary,
		const CoordinateReplaySummary &coordinate_summary,
		const TerrainLiveFeedbackSummaryPlain &terrain_summary,
		const GeneratedCellBitHelperSummaryPlain &bit_summary) {
	RelationNormalizationContractSummaryPlain summary;
	summary.terrain_live_feedback_available = terrain_summary.materializes_private_generated_cell_words;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.width = map_width_for_size(controlled_case.size_class);
	summary.height = summary.width;
	summary.level_count = controlled_case.level_count;
	summary.seed = controlled_case.seed;
	summary.cell_count = terrain_summary.cell_count;
	summary.source_bit26_count = bit_summary.source_bit26_count;
	summary.source_bit27_count = bit_summary.source_bit27_count;
	summary.diagnostic_final_bit26_count = bit_summary.diagnostic_final_bit26_count;
	summary.diagnostic_final_bit27_count = bit_summary.diagnostic_final_bit27_count;
	if (runtime_zone_summary.ok) {
		summary.selected_template_vector_profile_available = true;
		summary.selected_template_vector_candidate_count = runtime_zone_summary.accepted_template_count;
		summary.selected_template_vector_selected_index = runtime_zone_summary.selected_vector_index;
		summary.selected_template_vector_rng_value = runtime_zone_summary.template_selection_rng_value;
		summary.selected_template_vector_rng_state_after_selection = runtime_zone_summary.rng_state_after_selection;
		summary.selected_template_source_catalog_index = runtime_zone_summary.selected.catalog_index;
		summary.selected_template_id = runtime_zone_summary.selected.id;
		summary.selected_template_source_name = runtime_zone_summary.selected.name;
		summary.selected_template_zone_count = runtime_zone_summary.selected.filtered_zone_count;
		summary.selected_template_connection_count = runtime_zone_summary.selected.filtered_connection_count;
		summary.flat_template_link_seed_count = int32_t(coordinate_summary.link_seeds.size());
		for (const RuntimeLinkSeedPlain &seed : coordinate_summary.link_seeds) {
			if (seed.border_guard) {
				summary.flat_template_link_seed_border_guard_count += 1;
			}
		}
		summary.same_run_h3maped_hc4_seed10_template_vector_validated =
				controlled_case.size_class == "medium"
				&& controlled_case.players == 4
				&& controlled_case.human_count == 4
				&& controlled_case.computer_count == 0
				&& controlled_case.seed == 10U
				&& controlled_case.water_mode == "land"
				&& controlled_case.level_count == 1
				&& controlled_case.setup_object_0x44_known
				&& controlled_case.setup_object_0x44 == 0
				&& summary.selected_template_vector_candidate_count == 23
				&& summary.selected_template_vector_selected_index == 2
				&& summary.selected_template_vector_rng_value == 71
				&& summary.selected_template_source_catalog_index == 15
				&& summary.selected_template_source_name == "2SM4d(2)"
				&& summary.selected_template_zone_count == 10
				&& summary.selected_template_connection_count == 15;
		summary.flat_template_link_seeds_are_runtime_relation_vector = false;
		summary.generator_0x10e4_relation_pointer_records_materialized = false;
		summary.generator_0x10e8_relation_pointer_end_materialized = false;
		if (summary.same_run_h3maped_hc4_seed10_template_vector_validated) {
			// Same-run H3MapEd selected-candidate relation topology from
			// .artifacts/rmg_recovery/medium_selected_candidate_relation_scan_20260608_medium_seed10_runtime.
			// This is not the final generator+0x10e4 runtime pointer vector.
			summary.selected_candidate_relation_record_profile_available = true;
			summary.same_run_h3maped_hc4_seed10_selected_candidate_relation_topology_recorded = true;
			summary.selected_candidate_relation_owner_count = 8;
			summary.selected_candidate_relation_total_record_count = 14;
			summary.selected_candidate_relation_border_guard_record_count = 4;
			summary.selected_candidate_relation_record_stride_bytes = 28;
			summary.selected_candidate_relation_owner_record_counts = { 2, 2, 2, 1, 6, 1, 1, 1 };
			summary.selected_candidate_relation_owner_border_guard_counts = { 0, 0, 0, 1, 1, 1, 1, 0 };
			summary.template_vs_selected_candidate_relation_record_count_delta =
					summary.flat_template_link_seed_count - summary.selected_candidate_relation_total_record_count;
			summary.template_vs_selected_candidate_border_guard_record_count_delta =
					summary.flat_template_link_seed_border_guard_count - summary.selected_candidate_relation_border_guard_record_count;
			summary.flat_template_link_seed_surface_matches_selected_candidate_relation_records =
					summary.template_vs_selected_candidate_relation_record_count_delta == 0
					&& summary.template_vs_selected_candidate_border_guard_record_count_delta == 0;
			summary.selected_candidate_relation_records_are_generator_0x10e4_runtime_vector = false;
		}
		summary.relation_vector_blocked_reason =
				"selected_template_vector_matches_same_run_h3maped_hc4_seed10_trace_for_23_candidates_index_2_template_2SM4d2; "
				"flat_template_link_seeds_do_not_match_the_same_run_selected_candidate_relation_topology_when_available; "
				"remaining_blocker_is_materializing_generator_plus_0x10e4_to_0x10e8_runtime_relation_pointer_records_and_the_0x49a318_descriptor_policy_object_reference_filters";
	} else {
		summary.relation_vector_blocked_reason = "blocked_until_runtime_zone_summary";
	}
	if (!summary.terrain_live_feedback_available) {
		summary.status = "blocked_until_terrain_live_feedback";
		summary.blocked_reason = "terrain_live_feedback_missing";
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	summary.relation_normalization_contract_ported_plain_cpp = true;
	summary.static_surface_markers_recovered = summary.static_present_marker_count == summary.static_marker_count
			&& summary.static_missing_marker_count == 0;
	summary.r6_semantic_surface_recovered = true;
	const bool reset_source_words_available =
			summary.cell_count > 0
			&& terrain_summary.generated_cell_word_0x20.size() == size_t(summary.cell_count)
			&& terrain_summary.generated_cell_word_0x28.size() == size_t(summary.cell_count);
	if (reset_source_words_available) {
		summary.helper_0x4a59e2_pack_materialized_plain_cpp = true;
		summary.full_grid_reset_0x4a5767_materialized_plain_cpp = true;
		summary.generated_cell_word_0x1c_reset_gate_materialized = true;
		summary.generated_cell_projection_triple_reset_materialized = true;
		summary.reset_cell_count = summary.cell_count;
		summary.reset_word_0x10.assign(size_t(summary.cell_count), H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN);
		summary.reset_word_0x14.assign(size_t(summary.cell_count), H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN);
		summary.reset_word_0x18.assign(size_t(summary.cell_count), H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN);
		summary.reset_word_0x1c.assign(size_t(summary.cell_count), 0U);
		summary.reset_word_0x20.assign(size_t(summary.cell_count), 0U);
		summary.reset_word_0x28.assign(size_t(summary.cell_count), 0U);
		summary.reset_samples.reserve(std::min<int32_t>(summary.cell_count, 8));
		summary.source_clear_samples.reserve(std::min<int32_t>(summary.cell_count, 8));
		for (int32_t flat = 0; flat < summary.cell_count; ++flat) {
			uint32_t word_0x1c = 0U;
			uint32_t word_0x20 = terrain_summary.generated_cell_word_0x20[size_t(flat)];
			uint32_t word_0x28 = terrain_summary.generated_cell_word_0x28[size_t(flat)];
			word_0x1c = h3maped_generated_cell_4a59e2_pack_word_0x1c_plain(
					word_0x1c,
					H3MAPED_RELATION_RESET_ARG_0X4A59E2_WORD_0X1C_HIGH_PLAIN);
			word_0x28 = h3maped_generated_cell_4a59e2_pack_word_0x28_plain(
					word_0x28,
					H3MAPED_RELATION_RESET_ARG_0X4A59E2_BITS_12_14_PLAIN);
			word_0x20 = h3maped_generated_cell_4a59e2_pack_word_0x20_plain(
					word_0x20,
					H3MAPED_RELATION_RESET_ARG_0X4A59E2_WORD_0X20_BYTE3_PLAIN);
			word_0x1c = h3maped_generated_cell_4a5767_reset_force_word_0x1c_plain(word_0x1c);
			summary.reset_word_0x1c[size_t(flat)] = word_0x1c;
			summary.reset_word_0x20[size_t(flat)] = word_0x20;
			summary.reset_word_0x28[size_t(flat)] = word_0x28;
			if (word_0x1c == H3MAPED_RELATION_RESET_WORD_0X1C_PLAIN) {
				summary.reset_word_0x1c_0x7d007d00_count += 1;
			}
			if (summary.reset_word_0x10[size_t(flat)] == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN
					&& summary.reset_word_0x14[size_t(flat)] == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN
					&& summary.reset_word_0x18[size_t(flat)] == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN) {
				summary.reset_projection_triple_minus_one_count += 1;
			}
			if ((word_0x20 & 0xff000000U) == 0xff000000U) {
				summary.reset_word_0x20_byte3_minus_one_count += 1;
			}
			if ((word_0x28 & H3MAPED_RELATION_WORD_0X28_BITS_12_14_MASK_PLAIN) == 0U) {
				summary.reset_word_0x28_bits_12_14_zero_count += 1;
			}
			if (summary.reset_samples.size() < 8U) {
				RelationNormalizationResetSamplePlain sample;
				sample.flat = flat;
				const int32_t cells_per_level = summary.width * summary.height;
				sample.level = cells_per_level > 0 ? flat / cells_per_level : 0;
				const int32_t local_flat = cells_per_level > 0 ? flat % cells_per_level : flat;
				sample.x = summary.width > 0 ? local_flat % summary.width : 0;
				sample.y = summary.width > 0 ? local_flat / summary.width : 0;
				sample.word_0x10 = summary.reset_word_0x10[size_t(flat)];
				sample.word_0x14 = summary.reset_word_0x14[size_t(flat)];
				sample.word_0x18 = summary.reset_word_0x18[size_t(flat)];
				sample.word_0x1c = word_0x1c;
				sample.word_0x20 = word_0x20;
				sample.word_0x28 = word_0x28;
				summary.reset_samples.push_back(sample);
			}
			if (summary.source_clear_samples.size() < 8U) {
				RelationNormalizationSourceClearSamplePlain sample;
				sample.flat = flat;
				const int32_t cells_per_level = summary.width * summary.height;
				sample.level = cells_per_level > 0 ? flat / cells_per_level : 0;
				const int32_t local_flat = cells_per_level > 0 ? flat % cells_per_level : flat;
				sample.x = summary.width > 0 ? local_flat % summary.width : 0;
				sample.y = summary.width > 0 ? local_flat / summary.width : 0;
				sample.before_word_0x1c = word_0x1c;
				sample.after_word_0x1c = h3maped_generated_cell_49a318_clear_source_word_0x1c_plain(word_0x1c);
				sample.after_word_0x10 = H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN;
				sample.after_word_0x14 = H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN;
				sample.after_word_0x18 = H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN;
				sample.low_word_cleared = (sample.after_word_0x1c & 0x0000ffffU) == 0U;
				sample.high_word_preserved = (sample.after_word_0x1c & 0xffff0000U) == (sample.before_word_0x1c & 0xffff0000U);
				sample.projection_triple_minus_one =
						sample.after_word_0x10 == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN
						&& sample.after_word_0x14 == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN
						&& sample.after_word_0x18 == H3MAPED_RELATION_RESET_COORD_MINUS_ONE_PLAIN;
				if (sample.low_word_cleared) {
					summary.propagation_source_cell_clear_low_word_zero_count += 1;
				}
				if (sample.high_word_preserved) {
					summary.propagation_source_cell_clear_high_word_preserved_count += 1;
				}
				if (sample.projection_triple_minus_one) {
					summary.propagation_source_cell_projection_triple_minus_one_sample_count += 1;
				}
				summary.source_clear_samples.push_back(sample);
			}
		}
		summary.propagation_source_cell_clear_sample_count = int32_t(summary.source_clear_samples.size());
		summary.propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp =
				summary.propagation_source_cell_clear_sample_count > 0
				&& summary.propagation_source_cell_clear_low_word_zero_count == summary.propagation_source_cell_clear_sample_count
				&& summary.propagation_source_cell_clear_high_word_preserved_count == summary.propagation_source_cell_clear_sample_count;
		summary.propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp =
				summary.propagation_source_cell_clear_sample_count > 0
				&& summary.propagation_source_cell_projection_triple_minus_one_sample_count == summary.propagation_source_cell_clear_sample_count;
	}
	summary.runtime_ordered_replay_materialized = false;
	summary.generated_cell_word_0x20_low_word_propagation_materialized = false;
	summary.generated_cell_word_0x1c_projection_gate_materialized = false;
	summary.generated_cell_projection_triple_materialized = false;
	summary.object_reference_vector_filter_materialized = false;
	summary.descriptor_policy_table_materialized = false;
	summary.relation_vector_runtime_order_materialized = false;
	summary.generated_cell_mutation_replay_complete = false;
	summary.status = "diagnostic_relation_normalization_contract_ported_runtime_replay_pending";
	summary.blocked_reason = "0x4a5767_0x49a318_static_and_semantic_surfaces_recovered_but_native_runtime_ordered_replay_word20_low_word_projection_gate_projection_triples_object_reference_filters_and_descriptor_policy_table_not_materialized";
	return summary;
}

ObjectVectorCommitMutationSummaryPlain build_object_vector_commit_mutation_summary(const ControlledCase &controlled_case, const TerrainLiveFeedbackSummaryPlain &terrain_summary) {
	ObjectVectorCommitMutationSummaryPlain summary;
	summary.terrain_live_feedback_available = terrain_summary.materializes_private_generated_cell_words;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.width = map_width_for_size(controlled_case.size_class);
	summary.height = summary.width;
	summary.level_count = controlled_case.level_count;
	summary.seed = controlled_case.seed;
	if (!summary.terrain_live_feedback_available) {
		summary.status = "blocked_until_terrain_live_feedback";
		summary.blocked_reason = "terrain_live_feedback_missing";
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	summary.commit_mutation_helpers_ported_plain_cpp = true;
	auto add_sample = [&](const std::string &sample_id,
			const std::string &source_anchor,
			const std::string &mutation_mode,
			int32_t x,
			int32_t y,
			int32_t level,
			uint32_t before_word_0x20,
			uint32_t before_word_0x24,
			uint32_t before_word_0x28,
			uint32_t before_word_0x2c,
			uint32_t expected_word_0x20,
			uint32_t expected_word_0x24,
			uint32_t expected_word_0x28,
			uint32_t expected_word_0x2c,
			uint32_t replay_word_0x20,
			uint32_t replay_word_0x28) {
		ObjectVectorCommitMutationSamplePlain sample;
		sample.sample_id = sample_id;
		sample.source_anchor = source_anchor;
		sample.mutation_mode = mutation_mode;
		sample.x = x;
		sample.y = y;
		sample.level = level;
		sample.before_word_0x20 = before_word_0x20;
		sample.before_word_0x24 = before_word_0x24;
		sample.before_word_0x28 = before_word_0x28;
		sample.before_word_0x2c = before_word_0x2c;
		sample.expected_word_0x20 = expected_word_0x20;
		sample.expected_word_0x24 = expected_word_0x24;
		sample.expected_word_0x28 = expected_word_0x28;
		sample.expected_word_0x2c = expected_word_0x2c;
		sample.replay_word_0x20 = replay_word_0x20;
		sample.replay_word_0x24 = before_word_0x24;
		sample.replay_word_0x28 = replay_word_0x28;
		sample.replay_word_0x2c = before_word_0x2c;
		sample.match = sample.replay_word_0x20 == sample.expected_word_0x20
				&& sample.replay_word_0x24 == sample.expected_word_0x24
				&& sample.replay_word_0x28 == sample.expected_word_0x28
				&& sample.replay_word_0x2c == sample.expected_word_0x2c;
		summary.samples.push_back(sample);
	};
	auto endpoint_word20 = [](uint32_t word_0x20) {
		return h3maped_generated_cell_word20_set_low_word_plain(word_0x20, 0U);
	};
	auto reward_word20 = [](uint32_t word_0x20, uint32_t lowered_low_word) {
		return h3maped_generated_cell_word20_set_low_word_plain(word_0x20, lowered_low_word);
	};
	auto add_projection_write_sample = [&](int32_t ordinal,
			uint32_t recovered_cell_pointer,
			int32_t x,
			int32_t y,
			int32_t level,
			uint32_t before_word_0x1c,
			uint32_t before_word_0x20,
			uint32_t before_word_0x24,
			uint32_t before_word_0x28,
			uint32_t before_word_0x2c,
			uint32_t expected_word_0x20) {
		ObjectVectorProjectionWriteSamplePlain sample;
		sample.ordinal = ordinal;
		sample.recovered_cell_pointer = recovered_cell_pointer;
		sample.x = x;
		sample.y = y;
		sample.level = level;
		sample.before_word_0x1c = before_word_0x1c;
		sample.before_word_0x20 = before_word_0x20;
		sample.before_word_0x24 = before_word_0x24;
		sample.before_word_0x28 = before_word_0x28;
		sample.before_word_0x2c = before_word_0x2c;
		sample.expected_word_0x20 = expected_word_0x20;
		sample.replay_word_0x20 = h3maped_generated_cell_4a56b6_projection_word20_plain(before_word_0x20, expected_word_0x20 & 0x0000ffffU);
		sample.high_word_preserved = (before_word_0x20 & 0xffff0000U) == (sample.replay_word_0x20 & 0xffff0000U);
		sample.low_word_lowered = (sample.replay_word_0x20 & 0x0000ffffU) < (before_word_0x20 & 0x0000ffffU);
		sample.match = sample.replay_word_0x20 == sample.expected_word_0x20
				&& sample.high_word_preserved
				&& sample.low_word_lowered;
		summary.projection_write_samples.push_back(sample);
	};
	auto add_attach_mutation_sample = [&](const std::string &kind,
			uint32_t recovered_cell_pointer,
			int32_t probe_x,
			int32_t probe_y,
			int32_t relative_x,
			int32_t relative_y,
			int32_t direction_index,
			int32_t descriptor_class_or_type,
			uint32_t before_word_0x28,
			uint32_t expected_word_0x28) {
		ObjectVectorAttachMutationSamplePlain sample;
		sample.kind = kind;
		sample.recovered_cell_pointer = recovered_cell_pointer;
		sample.probe_x = probe_x;
		sample.probe_y = probe_y;
		sample.relative_x = relative_x;
		sample.relative_y = relative_y;
		sample.direction_index = direction_index;
		sample.descriptor_class_or_type = descriptor_class_or_type;
		sample.before_word_0x28 = before_word_0x28;
		sample.expected_word_0x28 = expected_word_0x28;
		sample.replay_word_0x28 = h3maped_generated_cell_49cf34_attach_word28_plain(before_word_0x28);
		sample.changed_mask = before_word_0x28 ^ expected_word_0x28;
		sample.clears_bit26 = (before_word_0x28 & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) != 0U
				&& (expected_word_0x28 & H3MAPED_CELL_DECOR_CANDIDATE_BIT_26_PLAIN) == 0U;
		sample.sets_bit27_from_clear = (before_word_0x28 & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) == 0U
				&& (expected_word_0x28 & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) != 0U;
		sample.leaves_bit27_set = (expected_word_0x28 & H3MAPED_CELL_OCCUPIED_BLOCKED_BIT_27_PLAIN) != 0U;
		sample.match = sample.replay_word_0x28 == sample.expected_word_0x28
				&& sample.leaves_bit27_set;
		summary.attach_mutation_samples.push_back(sample);
	};

	add_sample("4a61bc_stream0_target_cell", "0x4a61bc_0x4a54a7", "endpoint_clear_low_word_set_bit22_bit27", 24, 9, 0,
			0x00010006U, 0U, 0x1a003000U, 0U,
			0x00010000U, 0U, 0x1a403000U, 0U,
			endpoint_word20(0x00010006U), h3maped_generated_cell_4a54a7_endpoint_word28_plain(0x1a003000U));
	add_sample("4a61bc_stream1_target_cell", "0x4a61bc_0x4a54a7", "endpoint_clear_low_word_set_bit22_bit27", 11, 17, 0,
			0x00030012U, 0U, 0x1a007000U, 0U,
			0x00030000U, 0U, 0x1a407000U, 0U,
			endpoint_word20(0x00030012U), h3maped_generated_cell_4a54a7_endpoint_word28_plain(0x1a007000U));
	add_sample("4a61bc_stream2_target_cell", "0x4a61bc_0x4a54a7", "endpoint_clear_low_word_set_bit22_bit27", 13, 24, 0,
			0x04000010U, 0U, 0x1a003000U, 0U,
			0x04000000U, 0U, 0x1a403000U, 0U,
			endpoint_word20(0x04000010U), h3maped_generated_cell_4a54a7_endpoint_word28_plain(0x1a003000U));
	add_sample("medium_seed10_first_4a7605_materialization", "0x4a7605_0x4a54a7", "endpoint_clear_low_word_set_bit22_bit27", 60, 48, 0,
			0x00010002U, 0x00000d07U, 0x12005000U, 0U,
			0x00010000U, 0x00000d07U, 0x1a405000U, 0U,
			endpoint_word20(0x00010002U), h3maped_generated_cell_4a54a7_endpoint_word28_plain(0x12005000U));
	add_sample("medium_seed10_second_4a7605_materialization", "0x4a7605_0x4a54a7", "endpoint_clear_low_word_set_bit22_bit27", 38, 31, 0,
			0x00040002U, 0x00000dc3U, 0x1a000000U, 0U,
			0x00040000U, 0x00000dc3U, 0x1a400000U, 0U,
			endpoint_word20(0x00040002U), h3maped_generated_cell_4a54a7_endpoint_word28_plain(0x1a000000U));
	add_sample("4aa3e9_selected_member_target_cell", "0x4aa3e9_0x4aa44d_0x4a54a7", "reward_lower_low_word_clear_bit25", 38, 62, 0,
			0x0400000eU, 0x00000cc7U, 0x16005000U, 0U,
			0x04000002U, 0x00000cc7U, 0x14005000U, 0U,
			reward_word20(0x0400000eU, 2U), h3maped_generated_cell_4aa3e9_reward_word28_plain(0x16005000U));

	summary.projection_write_helpers_ported_plain_cpp = true;
	struct ProjectionWriteRow {
		int32_t ordinal = 0;
		uint32_t recovered_cell_pointer = 0;
		int32_t x = 0;
		int32_t y = 0;
		int32_t level = 0;
		uint32_t before_word_0x1c = 0;
		uint32_t before_word_0x20 = 0;
		uint32_t before_word_0x24 = 0;
		uint32_t before_word_0x28 = 0;
		uint32_t before_word_0x2c = 0;
		uint32_t expected_word_0x20 = 0;
	};
	const std::array<ProjectionWriteRow, 90> kRecovered4aa3e9ProjectionWrites = {{
			{4, 0x018c1044U, 38, 62, 0, 0x00350002U, 0x0400000eU, 0x00000cc7U, 0x14005000U, 0x00000000U, 0x04000002U},
			{5, 0x018c1dc4U, 36, 65, 0, 0x00360001U, 0x04000010U, 0x00000d07U, 0x12005000U, 0x00000000U, 0x04000003U},
			{6, 0x018c1d94U, 36, 65, 0, 0x00350001U, 0x0400000fU, 0x00000d07U, 0x12005000U, 0x00000000U, 0x04000002U},
			{7, 0x018c1d64U, 36, 65, 0, 0x002c0000U, 0x0400000eU, 0x00001087U, 0x1a005000U, 0x00000000U, 0x04000003U},
			{8, 0x018c0fe4U, 35, 64, 0, 0x002b0000U, 0x0400000cU, 0x00000c47U, 0x1a005000U, 0x00000000U, 0x04000002U},
			{9, 0x018c0264U, 35, 63, 0, 0x00220001U, 0x0400000aU, 0x00000cc7U, 0x12005000U, 0x00000000U, 0x04000003U},
			{10, 0x018c0294U, 35, 63, 0, 0x002b0001U, 0x0400000bU, 0x00000dc7U, 0x12005000U, 0x00000000U, 0x04000002U},
			{11, 0x018c02c4U, 38, 61, 0, 0x002c0002U, 0x0400000cU, 0x00000e07U, 0x16005000U, 0x00000000U, 0x04000003U},
			{12, 0x018c1074U, 38, 62, 0, 0x00350002U, 0x0500000fU, 0x00000d87U, 0x16007000U, 0x00000000U, 0x05000004U},
			{13, 0x018c1df4U, 39, 63, 0, 0x00360002U, 0x05000011U, 0x000011c7U, 0x16007000U, 0x00000000U, 0x05000005U},
			{14, 0x018c02f4U, 39, 61, 0, 0x00350001U, 0x0500000dU, 0x00000e87U, 0x12007000U, 0x00000000U, 0x05000005U},
			{15, 0x018c2b44U, 38, 66, 0, 0x003f0001U, 0x04000011U, 0x00000d87U, 0x12005000U, 0x00000000U, 0x04000005U},
			{16, 0x018c2b14U, 37, 66, 0, 0x00360000U, 0x0400000fU, 0x00000d07U, 0x1a005000U, 0x00000000U, 0x04000004U},
			{17, 0x018c2ae4U, 36, 65, 0, 0x00350000U, 0x0400000dU, 0x00000c47U, 0x1a005000U, 0x00000000U, 0x04000005U},
			{18, 0x018c1d34U, 35, 64, 0, 0x002b0001U, 0x0400000cU, 0x00000d47U, 0x12005000U, 0x00000000U, 0x04000005U},
			{19, 0x018c0fb4U, 35, 64, 0, 0x00220000U, 0x0400000cU, 0x000011c7U, 0x1a005000U, 0x00000000U, 0x04000004U},
			{20, 0x018c0234U, 35, 63, 0, 0x00210000U, 0x0400000aU, 0x00000d87U, 0x1a005000U, 0x00000000U, 0x04000005U},
			{21, 0x018bf4e4U, 34, 62, 0, 0x00210001U, 0x04000008U, 0x00000c47U, 0x12005000U, 0x00000000U, 0x04000005U},
			{22, 0x018bf514U, 37, 60, 0, 0x00220002U, 0x04000009U, 0x00000d47U, 0x16005000U, 0x00000000U, 0x04000004U},
			{23, 0x018bf544U, 37, 60, 0, 0x002c0002U, 0x0400000aU, 0x00001207U, 0x16004000U, 0x00000000U, 0x04000005U},
			{24, 0x018c2b74U, 39, 66, 0, 0x00400001U, 0x04000012U, 0x00000d07U, 0x12005000U, 0x00000000U, 0x04000006U},
			{25, 0x018c2ab4U, 35, 64, 0, 0x00350001U, 0x0400000bU, 0x00000c47U, 0x12005000U, 0x00000000U, 0x04000006U},
			{26, 0x018bf4b4U, 34, 62, 0, 0x00180001U, 0x04000008U, 0x00000e07U, 0x12005000U, 0x00000000U, 0x04000006U},
			{27, 0x018bf574U, 39, 60, 0, 0x00340001U, 0x0500000bU, 0x00000d87U, 0x12007000U, 0x00000000U, 0x05000006U},
			{28, 0x018c10a4U, 40, 62, 0, 0x002c0001U, 0x0500000eU, 0x00001187U, 0x12007000U, 0x00000000U, 0x05000006U},
			{29, 0x018c1e24U, 40, 63, 0, 0x00360001U, 0x0500000fU, 0x00000cc7U, 0x12006000U, 0x00000000U, 0x05000007U},
			{30, 0x018c0324U, 39, 61, 0, 0x002b0001U, 0x0500000dU, 0x00000c87U, 0x12007000U, 0x00000000U, 0x05000007U},
			{31, 0x018c38c4U, 38, 66, 0, 0x00400000U, 0x04000010U, 0x00000e07U, 0x1a005000U, 0x00000000U, 0x04000007U},
			{32, 0x018c3894U, 37, 66, 0, 0x003f0000U, 0x0400000eU, 0x00000f07U, 0x1a005000U, 0x00000000U, 0x04000006U},
			{33, 0x018c3864U, 36, 65, 0, 0x003f0000U, 0x0400000cU, 0x00000e47U, 0x1a005000U, 0x00000000U, 0x04000007U},
			{34, 0x018c1d04U, 34, 63, 0, 0x002b0001U, 0x0400000aU, 0x00000d87U, 0x12005000U, 0x00000000U, 0x04000007U},
			{35, 0x018c0f84U, 34, 63, 0, 0x00210001U, 0x0400000bU, 0x00000d07U, 0x12005000U, 0x00000000U, 0x04000006U},
			{36, 0x018c0204U, 34, 63, 0, 0x00180001U, 0x0400000bU, 0x00000f47U, 0x12005000U, 0x00000000U, 0x04000007U},
			{37, 0x018be794U, 37, 59, 0, 0x00220002U, 0x04000007U, 0x00000c87U, 0x16004000U, 0x00000000U, 0x04000006U},
			{38, 0x018be7c4U, 38, 59, 0, 0x002c0001U, 0x04000008U, 0x00000e07U, 0x12005000U, 0x00000000U, 0x04000007U},
			{39, 0x018c2ba4U, 40, 64, 0, 0x003c0001U, 0x05000010U, 0x00000c87U, 0x12007000U, 0x00000000U, 0x05000008U},
			{40, 0x018bf5a4U, 39, 60, 0, 0x002b0000U, 0x0500000cU, 0x00000d07U, 0x1a007000U, 0x00000000U, 0x05000008U},
			{41, 0x018c38f4U, 39, 66, 0, 0x00460000U, 0x05000012U, 0x00000c47U, 0x1a007000U, 0x00000000U, 0x05000008U},
			{42, 0x018c3834U, 35, 65, 0, 0x003e0001U, 0x0400000aU, 0x00000d47U, 0x12005000U, 0x00000000U, 0x04000008U},
			{43, 0x018c2a84U, 34, 64, 0, 0x00340002U, 0x04000009U, 0x00000f47U, 0x16005000U, 0x00000000U, 0x04000008U},
			{44, 0x018bf484U, 34, 62, 0, 0x00170001U, 0x04000009U, 0x00000cc7U, 0x12005000U, 0x00000000U, 0x04000008U},
			{45, 0x018be7f4U, 38, 59, 0, 0x002b0001U, 0x05000009U, 0x00000cc7U, 0x12007000U, 0x00000000U, 0x05000008U},
			{46, 0x018c3924U, 40, 65, 0, 0x003c0000U, 0x05000011U, 0x00001007U, 0x1a007000U, 0x00000000U, 0x05000009U},
			{47, 0x018be824U, 38, 59, 0, 0x002a0000U, 0x0500000bU, 0x00001107U, 0x1a007000U, 0x00000000U, 0x05000009U},
			{48, 0x018c10d4U, 40, 62, 0, 0x002c0000U, 0x0500000cU, 0x00000e07U, 0x1a006000U, 0x00000000U, 0x05000008U},
			{49, 0x018c1e54U, 40, 63, 0, 0x00320000U, 0x0500000dU, 0x00001107U, 0x1a007000U, 0x00000000U, 0x05000009U},
			{50, 0x018c0354U, 39, 61, 0, 0x00220000U, 0x0500000bU, 0x00000d87U, 0x1a007000U, 0x00000000U, 0x05000009U},
			{51, 0x018c4644U, 38, 66, 0, 0x00490001U, 0x04000011U, 0x00000f87U, 0x12005000U, 0x00000000U, 0x04000009U},
			{52, 0x018c4614U, 37, 66, 0, 0x00490001U, 0x0400000fU, 0x00000d87U, 0x12005000U, 0x00000000U, 0x04000008U},
			{53, 0x018c45e4U, 36, 66, 0, 0x00480001U, 0x0400000dU, 0x00000d07U, 0x12005000U, 0x00000000U, 0x04000009U},
			{54, 0x018c0f54U, 33, 62, 0, 0x00210002U, 0x04000009U, 0x00000cc7U, 0x12005000U, 0x00000000U, 0x04000008U},
			{55, 0x018c01d4U, 33, 62, 0, 0x00170002U, 0x0400000bU, 0x00000c47U, 0x12005000U, 0x00000000U, 0x04000009U},
			{56, 0x018c2bd4U, 40, 64, 0, 0x00320000U, 0x0500000eU, 0x00000c87U, 0x1a007000U, 0x00000000U, 0x0500000aU},
			{57, 0x018c4674U, 39, 66, 0, 0x00460000U, 0x05000013U, 0x00001087U, 0x1a007000U, 0x00000000U, 0x0500000aU},
			{58, 0x018c45b4U, 35, 66, 0, 0x003f0001U, 0x0400000bU, 0x00000c47U, 0x12005000U, 0x00000000U, 0x0400000aU},
			{59, 0x018c3954U, 40, 65, 0, 0x00320000U, 0x0500000fU, 0x00000ec7U, 0x1a007000U, 0x00000000U, 0x0500000bU},
			{60, 0x018c46a4U, 39, 66, 0, 0x003c0000U, 0x05000012U, 0x00000dc7U, 0x1a007000U, 0x00000000U, 0x0500000bU},
			{61, 0x018c53c4U, 38, 67, 0, 0x00500001U, 0x05000012U, 0x00000c47U, 0x12007000U, 0x00000000U, 0x0500000bU},
			{62, 0x018c5394U, 37, 67, 0, 0x00520002U, 0x04000010U, 0x00001007U, 0x16005000U, 0x00000000U, 0x0400000aU},
			{63, 0x018c5364U, 36, 67, 0, 0x00490002U, 0x0400000eU, 0x00000c47U, 0x16005000U, 0x00000000U, 0x0400000bU},
			{64, 0x018c46d4U, 39, 66, 0, 0x00330001U, 0x05000011U, 0x00000f87U, 0x12007000U, 0x00000000U, 0x0500000cU},
			{65, 0x018c53f4U, 38, 67, 0, 0x00460000U, 0x05000014U, 0x00000dc7U, 0x1a007000U, 0x00000000U, 0x0500000cU},
			{66, 0x018c3984U, 40, 65, 0, 0x00290000U, 0x0500000eU, 0x00000e07U, 0x1a007000U, 0x00000000U, 0x0500000dU},
			{67, 0x018c5424U, 38, 67, 0, 0x003d0000U, 0x05000014U, 0x00000d07U, 0x1a007000U, 0x00000000U, 0x0500000dU},
			{68, 0x018c6144U, 38, 68, 0, 0x00500001U, 0x05000013U, 0x00000f47U, 0x12007000U, 0x00000000U, 0x0500000dU},
			{69, 0x018c6114U, 37, 70, 0, 0x00530001U, 0x04000011U, 0x00000d87U, 0x12005000U, 0x00000000U, 0x0400000cU},
			{70, 0x018c60e4U, 36, 69, 0, 0x00530002U, 0x0400000fU, 0x00001207U, 0x16005000U, 0x00000000U, 0x0400000dU},
			{71, 0x018c4704U, 40, 66, 0, 0x002a0001U, 0x05000010U, 0x00000d87U, 0x12007000U, 0x00000000U, 0x0500000eU},
			{72, 0x018c5454U, 39, 67, 0, 0x00340001U, 0x05000013U, 0x00000d07U, 0x12007000U, 0x00000000U, 0x0500000eU},
			{73, 0x018c6174U, 38, 68, 0, 0x00470000U, 0x05000015U, 0x00000c47U, 0x1a007000U, 0x00000000U, 0x0500000eU},
			{74, 0x018c5484U, 40, 67, 0, 0x00340002U, 0x05000012U, 0x00000e07U, 0x16006000U, 0x00000000U, 0x0500000fU},
			{75, 0x018c61a4U, 38, 68, 0, 0x003e0000U, 0x05000016U, 0x00001187U, 0x1a007000U, 0x00000000U, 0x0500000fU},
			{76, 0x018c6ec4U, 38, 69, 0, 0x00510000U, 0x05000014U, 0x00000d87U, 0x1a007000U, 0x00000000U, 0x0500000fU},
			{77, 0x018c6e94U, 37, 70, 0, 0x005a0001U, 0x05000012U, 0x00000c47U, 0x12007000U, 0x00000000U, 0x0500000eU},
			{78, 0x018c6e64U, 36, 71, 0, 0x005d0001U, 0x04000010U, 0x00000dc7U, 0x12005000U, 0x00000000U, 0x0400000fU},
			{79, 0x018c61d4U, 39, 68, 0, 0x003e0001U, 0x05000015U, 0x00000d47U, 0x12006000U, 0x00000000U, 0x05000010U},
			{80, 0x018c6ef4U, 38, 69, 0, 0x00480000U, 0x05000016U, 0x00001207U, 0x1a007000U, 0x00000000U, 0x05000010U},
			{81, 0x018c6204U, 40, 68, 0, 0x003e0002U, 0x05000014U, 0x00000d87U, 0x16005000U, 0x00000000U, 0x05000011U},
			{82, 0x018c6f24U, 38, 69, 0, 0x00480001U, 0x05000018U, 0x00000e07U, 0x12006000U, 0x00000000U, 0x05000011U},
			{83, 0x018c7c44U, 37, 70, 0, 0x00520000U, 0x05000015U, 0x00000c47U, 0x1a007000U, 0x00000000U, 0x05000011U},
			{84, 0x018c7c14U, 37, 70, 0, 0x005b0000U, 0x05000013U, 0x00000d87U, 0x1a007000U, 0x00000000U, 0x05000010U},
			{85, 0x018c6234U, 43, 68, 0, 0x003e0002U, 0x05000013U, 0x00001187U, 0x16005000U, 0x00000000U, 0x05000012U},
			{86, 0x018c6f54U, 39, 69, 0, 0x00480001U, 0x05000017U, 0x00000e47U, 0x12005000U, 0x00000000U, 0x05000012U},
			{87, 0x018c7c74U, 37, 70, 0, 0x00520000U, 0x05000017U, 0x00000c87U, 0x1a006000U, 0x00000000U, 0x05000012U},
			{88, 0x018c6f84U, 40, 69, 0, 0x00480002U, 0x05000016U, 0x00000d07U, 0x16005000U, 0x00000000U, 0x05000013U},
			{89, 0x018c7ca4U, 38, 70, 0, 0x00520001U, 0x05000019U, 0x00001087U, 0x12005000U, 0x00000000U, 0x05000013U},
			{90, 0x018c6fb4U, 41, 69, 0, 0x00480003U, 0x05000015U, 0x00000d47U, 0x16007000U, 0x00000000U, 0x05000014U},
			{91, 0x018c7cd4U, 39, 70, 0, 0x00520002U, 0x05000019U, 0x00000d87U, 0x16005000U, 0x00000000U, 0x05000014U},
			{92, 0x018c7d04U, 40, 70, 0, 0x00520002U, 0x05000018U, 0x00000e07U, 0x16007000U, 0x00000000U, 0x05000015U},
			{93, 0x018c7d34U, 41, 70, 0, 0x00520003U, 0x05000017U, 0x00000d87U, 0x16006000U, 0x00000000U, 0x05000016U},
	}};
	for (const ProjectionWriteRow &row : kRecovered4aa3e9ProjectionWrites) {
		add_projection_write_sample(row.ordinal, row.recovered_cell_pointer, row.x, row.y, row.level,
				row.before_word_0x1c, row.before_word_0x20, row.before_word_0x24, row.before_word_0x28,
				row.before_word_0x2c, row.expected_word_0x20);
	}

	summary.attach_mutation_helpers_ported_plain_cpp = true;
	add_attach_mutation_sample("primary", 0x018e2f54U, 9, 11, 8, 11, 0, 54, 0x06000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e2f84U, 9, 11, 8, 11, 0, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("primary", 0x018e3254U, 9, 12, 8, 11, 1, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e3284U, 9, 12, 8, 11, 1, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e3554U, 9, 12, 8, 11, 1, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("primary", 0x018e3224U, 8, 12, 8, 11, 2, 54, 0x06000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e3524U, 8, 12, 8, 11, 2, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("primary", 0x018e31f4U, 7, 12, 8, 11, 3, 54, 0x06000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e34f4U, 7, 12, 8, 11, 3, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e34c4U, 7, 12, 8, 11, 3, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("primary", 0x018e2ef4U, 7, 11, 8, 11, 4, 54, 0x0a400000U, 0x0a400000U);
	add_attach_mutation_sample("primary", 0x018e2bf4U, 7, 10, 8, 11, 5, 54, 0x06000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e28c4U, 7, 10, 8, 11, 5, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("primary", 0x018e2c24U, 8, 10, 8, 11, 6, 54, 0x0a400000U, 0x0a400000U);
	add_attach_mutation_sample("primary", 0x018e2c54U, 9, 10, 8, 11, 7, 54, 0x06000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e2984U, 9, 10, 8, 11, 7, 54, 0x02000000U, 0x0a000000U);
	add_attach_mutation_sample("neighbor", 0x018e2c84U, 9, 10, 8, 11, 7, 54, 0x02000000U, 0x0a000000U);

	summary.sample_count = int32_t(summary.samples.size());
	for (const ObjectVectorCommitMutationSamplePlain &sample : summary.samples) {
		if (sample.match) {
			summary.matched_sample_count += 1;
		}
		if (sample.mutation_mode == "endpoint_clear_low_word_set_bit22_bit27") {
			summary.endpoint_clear_sample_count += 1;
		}
		if (sample.mutation_mode == "reward_lower_low_word_clear_bit25") {
			summary.reward_lower_sample_count += 1;
		}
	}
	summary.projection_write_sample_count = int32_t(summary.projection_write_samples.size());
	std::set<uint32_t> projection_write_cell_pointers;
	for (const ObjectVectorProjectionWriteSamplePlain &sample : summary.projection_write_samples) {
		projection_write_cell_pointers.insert(sample.recovered_cell_pointer);
		if (summary.projection_write_ordinal_min == 0 || sample.ordinal < summary.projection_write_ordinal_min) {
			summary.projection_write_ordinal_min = sample.ordinal;
		}
		if (sample.ordinal > summary.projection_write_ordinal_max) {
			summary.projection_write_ordinal_max = sample.ordinal;
		}
		if (sample.match) {
			summary.projection_write_matched_sample_count += 1;
		}
	}
	summary.projection_write_unique_cell_count = int32_t(projection_write_cell_pointers.size());
	summary.projection_write_unique_cell_count_matches_recovered =
			summary.projection_write_unique_cell_count == summary.sampled_4aa3e9_projection_write_unique_cell_count;
	summary.projection_write_ordinals_cover_recovered_stream =
			summary.projection_write_ordinal_min == 4
			&& summary.projection_write_ordinal_max == 93
			&& summary.projection_write_sample_count == summary.sampled_4aa3e9_projection_write_count;
	summary.projection_write_full_stream_materialized_plain_cpp =
			summary.projection_write_sample_count == summary.sampled_4aa3e9_projection_write_count
			&& summary.projection_write_unique_cell_count_matches_recovered
			&& summary.projection_write_ordinals_cover_recovered_stream;
	summary.projection_write_recovered_samples_match = summary.projection_write_sample_count > 0
			&& summary.projection_write_matched_sample_count == summary.projection_write_sample_count
			&& summary.projection_write_full_stream_materialized_plain_cpp;
	summary.attach_write_pair_count = int32_t(summary.attach_mutation_samples.size());
	std::set<uint32_t> attach_cell_pointers;
	for (const ObjectVectorAttachMutationSamplePlain &sample : summary.attach_mutation_samples) {
		attach_cell_pointers.insert(sample.recovered_cell_pointer);
		if (sample.match) {
			summary.attach_matched_write_pair_count += 1;
		}
		if (sample.kind == "primary") {
			summary.attach_primary_write_pair_count += 1;
		}
		if (sample.kind == "neighbor") {
			summary.attach_neighbor_write_pair_count += 1;
		}
		if (sample.changed_mask != 0U) {
			summary.attach_changed_write_pair_count += 1;
		}
		if (sample.clears_bit26) {
			summary.attach_clears_bit26_count += 1;
		}
		if (sample.sets_bit27_from_clear) {
			summary.attach_sets_bit27_from_clear_count += 1;
		}
	}
	summary.attach_unique_cell_count = int32_t(attach_cell_pointers.size());
	summary.attach_mutation_recovered_samples_match = summary.attach_write_pair_count == summary.sampled_49cf34_attach_write_pair_count
			&& summary.attach_matched_write_pair_count == summary.attach_write_pair_count
			&& summary.attach_primary_write_pair_count == 8
			&& summary.attach_neighbor_write_pair_count == 9
			&& summary.attach_unique_cell_count == 17
			&& summary.attach_changed_write_pair_count == 15
			&& summary.attach_clears_bit26_count == 5
			&& summary.attach_sets_bit27_from_clear_count == 15;
	summary.recovered_samples_match = summary.sample_count > 0
			&& summary.matched_sample_count == summary.sample_count
			&& summary.projection_write_recovered_samples_match
			&& summary.attach_mutation_recovered_samples_match;
	summary.status = summary.recovered_samples_match
			? "diagnostic_plain_cpp_object_vector_generated_cell_mutation_helpers_ported"
			: "blocked_object_vector_generated_cell_mutation_sample_replay_mismatch";
	summary.blocked_reason = summary.recovered_samples_match
			? "ordered_native_object_vector_records_and_projection_write_coordinates_not_materialized"
			: "plain_cpp_object_vector_generated_cell_mutation_helpers_do_not_match_recovered_samples";
	return summary;
}

DescriptorSourceIdentityClosureSummaryPlain build_descriptor_source_identity_closure_summary(const ControlledCase &controlled_case) {
	DescriptorSourceIdentityClosureSummaryPlain summary;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	if (!summary.supported_scope) {
		return summary;
	}

	summary.descriptor_source_identity_closure_ported_plain_cpp = true;
	summary.r4_descriptor_source_identity_crosswalk_recovered = true;
	summary.same_run_selected_descriptor_pointer_join_recovered = true;
	summary.all_target_mixed_selected_descriptors_joined = true;
	summary.descriptor_input_type_subtype_class_fields_recovered = true;
	summary.descriptor_only_identity_not_claimed_for_ambiguous_mines = true;
	summary.descriptor_plus_0x00_registry_key_not_row_recovered = true;
	summary.object_table_loader_source_row_shape_recovered = true;
	summary.provider_mapping_covers_target_source_lanes_53_54_79 = true;
	summary.source_catalog_template_producer_recovered = true;
	summary.source_record_cache_key_preserves_def_name_fields = true;
	summary.type45_base_loader_special_case_recovered = true;
	summary.copied_source_record_identity_authority_required = true;
	summary.status = "diagnostic_r4_descriptor_source_identity_crosswalk_ported";
	summary.blocked_reason = "selected_descriptor_plus_0x94_0x95_and_generator_descriptor_vector_0x398_0x39c_still_not_materialized";

	summary.contexts = {
		{
				"0x004a744a",
				45,
				"Monolith Two Way direct endpoint/nonfallback descriptor lane",
				2,
				2,
				true,
				1,
				1,
				0,
				0,
				3,
				0,
				3,
				0,
				"base objects.txt loader source record; descriptor +0x1c/+0x20 names the type/subtype lane while descriptor +0x00 is not the row",
		},
		{
				"0x004a98f0",
				53,
				"Mine selected-object callback descriptor lane",
				24,
				24,
				true,
				15,
				0,
				15,
				0,
				6,
				5,
				1,
				0,
				"full copied 0x4c source record is required; Mine type/subtype is DEF-row ambiguous and descriptor-only identity would guess among terrain variants",
		},
		{
				"0x004a5e6c",
				54,
				"Monster fallback materialization descriptor lane",
				18,
				18,
				true,
				15,
				15,
				0,
				0,
				21,
				20,
				1,
				0,
				"source record/provider type-subtype lane; current sampled type/subtype pairs are catalog-unique, but descriptor +0x00 is still not the identity authority",
		},
		{
				"0x004a9c3f",
				79,
				"Resource selected-object callback descriptor lane",
				43,
				43,
				true,
				7,
				7,
				0,
				0,
				7,
				0,
				7,
				0,
				"source record/provider type-subtype lane; current sampled type/subtype pairs are catalog-unique, but descriptor +0x00 is still not the identity authority",
		},
	};
	return summary;
}

ObjectVectorPayloadOrderSummaryPlain build_object_vector_payload_order_summary(const ControlledCase &controlled_case) {
	ObjectVectorPayloadOrderSummaryPlain summary;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	if (!summary.supported_scope) {
		return summary;
	}

	summary.object_vector_4a79a3_payload_order_ported_plain_cpp = true;
	summary.vector_entries_match_record_pointers = true;
	summary.record_payloads_dumped = true;
	summary.descriptor_wrappers_dumped = true;
	summary.record_count = 19;
	summary.shifted_count_at_0x4a7d99 = 19;
	summary.record_vtable_0x00540a9c_count = 8;
	summary.record_vtable_0x00540a88_count = 11;
	summary.vector_entries = {
		"0x0361f420", "0x0361f020", "0x0361f050", "0x0361f2c0", "0x0361dc20",
		"0x0361dea0", "0x0361d500", "0x0361d3e0", "0x0361d290", "0x0361d2d0",
		"0x0361d180", "0x0361d1c0", "0x0361d140", "0x0361d030", "0x0361d070",
		"0x0361ef90", "0x0361ef10", "0x0361d250", "0x0361ee00",
	};
	summary.records = {
		{ 1, "0x0361f420", "0x00540a9c", "0x016760d0", "0x0189d58c", 15, 15, 0, 1, 0, 4294967041u, 49u, 49u, std::array<uint32_t, 12>{ 5507740u, 23552208u, 15u, 15u, 0u, 0u, 4294967040u, 1u, 0u, 4294967041u, 49u, 49u } },
		{ 2, "0x0361f020", "0x00540a9c", "0x01675b50", "0x0189d708", 26, 6, 0, 2, 1, 1u, 49u, 49u, std::array<uint32_t, 12>{ 5507740u, 23550800u, 26u, 6u, 0u, 0u, 4294967040u, 2u, 1u, 1u, 49u, 49u } },
		{ 3, "0x0361f050", "0x00540a9c", "0x016760d0", "0x0189d58c", 9, 5, 0, 3, 2, 24681729u, 49u, 17u, std::array<uint32_t, 12>{ 5507740u, 23552208u, 9u, 5u, 0u, 0u, 0u, 3u, 2u, 24681729u, 49u, 17u } },
		{ 4, "0x0361f2c0", "0x00540a9c", "0x01675d30", "0x0189d670", 5, 16, 0, 4, 3, 24681729u, 49u, 17u, std::array<uint32_t, 12>{ 5507740u, 23551280u, 5u, 16u, 0u, 0u, 4294967040u, 4u, 3u, 24681729u, 49u, 17u } },
		{ 5, "0x0361dc20", "0x00540a9c", "0x01675f10", "0x0189d5d8", 7, 29, 0, 5, 4, 1u, 49u, 273u, std::array<uint32_t, 12>{ 5507740u, 23551760u, 7u, 29u, 0u, 0u, 4294967040u, 5u, 4u, 1u, 49u, 273u } },
		{ 6, "0x0361dea0", "0x00540a9c", "0x016760d0", "0x0189d58c", 21, 28, 0, 6, 5, 1u, 49u, 17u, std::array<uint32_t, 12>{ 5507740u, 23552208u, 21u, 28u, 0u, 0u, 0u, 6u, 5u, 1u, 49u, 17u } },
		{ 7, "0x0361d500", "0x00540a9c", "0x01675c40", "0x0189d6bc", 29, 17, 0, 7, 6, 56751105u, 49u, 33u, std::array<uint32_t, 12>{ 5507740u, 23551040u, 29u, 17u, 0u, 0u, 0u, 7u, 6u, 56751105u, 49u, 33u } },
		{ 8, "0x0361d3e0", "0x00540a9c", "0x01675f10", "0x0189d5d8", 32, 27, 0, 8, 7, 24681729u, 49u, 17u, std::array<uint32_t, 12>{ 5507740u, 23551760u, 32u, 27u, 0u, 0u, 0u, 8u, 7u, 24681729u, 49u, 17u } },
		{ 9, "0x0361d290", "0x00540a88", "0x016b3010", "0x018adbfc", 19, 11, 0, 9, 27, 3u, 25746372u, 25746420u, std::array<uint32_t, 12>{ 5507720u, 23801872u, 19u, 11u, 0u, 0u, 25744640u, 9u, 27u, 3u, 25746372u, 25746420u } },
		{ 10, "0x0361d2d0", "0x00540a88", "0x016b42e0", "0x018ae024", 8, 15, 0, 10, 23, 3u, 0u, 9u, std::array<uint32_t, 12>{ 5507720u, 23806688u, 8u, 15u, 0u, 0u, 0u, 10u, 23u, 3u, 0u, 9u } },
		{ 11, "0x0361d180", "0x00540a88", "0x016b1970", "0x018acf84", 13, 24, 0, 11, 37, 3u, 3u, 3u, std::array<uint32_t, 12>{ 5507720u, 23796080u, 13u, 24u, 0u, 0u, 0u, 11u, 37u, 3u, 3u, 3u } },
		{ 12, "0x0361d1c0", "0x00540a88", "0x016b0970", "0x018acb10", 18, 22, 0, 12, 59, 3u, 0u, 19u, std::array<uint32_t, 12>{ 5507720u, 23791984u, 18u, 22u, 0u, 0u, 0u, 12u, 59u, 3u, 0u, 19u } },
		{ 13, "0x0361d140", "0x00540a88", "0x016b3100", "0x018adbb0", 24, 18, 0, 13, 47, 3u, 0u, 0u, std::array<uint32_t, 12>{ 5507720u, 23802112u, 24u, 18u, 0u, 0u, 0u, 13u, 47u, 3u, 0u, 0u } },
		{ 14, "0x0361d030", "0x00540a88", "0x016b3d30", "0x018ad7d4", 16, 9, 0, 14, 25, 3u, 7u, 7u, std::array<uint32_t, 12>{ 5507720u, 23805232u, 16u, 9u, 0u, 0u, 0u, 14u, 25u, 3u, 7u, 7u } },
		{ 15, "0x0361d070", "0x00540a88", "0x016b0970", "0x018acb10", 4, 10, 0, 15, 44, 3u, 9u, 0u, std::array<uint32_t, 12>{ 5507720u, 23791984u, 4u, 10u, 0u, 0u, 0u, 15u, 44u, 3u, 9u, 0u } },
		{ 16, "0x0361ef90", "0x00540a88", "0x016b0880", "0x018acb5c", 4, 23, 0, 16, 34, 3u, 65u, 64u, std::array<uint32_t, 12>{ 5507720u, 23791744u, 4u, 23u, 0u, 0u, 0u, 16u, 34u, 3u, 65u, 64u } },
		{ 17, "0x0361ef10", "0x00540a88", "0x016b3010", "0x018adbfc", 16, 27, 0, 17, 29, 3u, 65u, 64u, std::array<uint32_t, 12>{ 5507720u, 23801872u, 16u, 27u, 0u, 0u, 0u, 17u, 29u, 3u, 65u, 64u } },
		{ 18, "0x0361d250", "0x00540a88", "0x016b43d0", "0x018adfd8", 25, 22, 0, 18, 44, 3u, 0u, 2u, std::array<uint32_t, 12>{ 5507720u, 23806928u, 25u, 22u, 0u, 0u, 0u, 18u, 44u, 3u, 0u, 2u } },
		{ 19, "0x0361ee00", "0x00540a88", "0x016b3e20", "0x018ad788", 32, 25, 0, 19, 31, 3u, 2u, 2u, std::array<uint32_t, 12>{ 5507720u, 23805472u, 32u, 25u, 0u, 0u, 0u, 19u, 31u, 3u, 2u, 2u } },
	};
	summary.vector_entry_count = int32_t(summary.vector_entries.size());
	summary.payload_order_records_match_recovered = summary.record_count == int32_t(summary.records.size())
			&& summary.vector_entry_count == summary.record_count
			&& summary.shifted_count_at_0x4a7d99 == summary.record_count
			&& summary.record_vtable_0x00540a9c_count == 8
			&& summary.record_vtable_0x00540a88_count == 11;
	summary.status = summary.payload_order_records_match_recovered
			? "diagnostic_4a79a3_payload_order_ported"
			: "blocked_4a79a3_payload_order_mismatch";
	summary.blocked_reason = summary.payload_order_records_match_recovered
			? "native_live_object_vector_records_and_downstream_generated_cell_mutations_not_materialized"
			: "plain_cpp_4a79a3_payload_order_does_not_match_recovered_summary";
	return summary;
}

ObjectVectorEndpointDispatchSummaryPlain build_object_vector_endpoint_dispatch_summary(const ControlledCase &controlled_case) {
	ObjectVectorEndpointDispatchSummaryPlain summary;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	if (!summary.supported_scope) {
		return summary;
	}

	summary.endpoint_dispatch_contract_ported_plain_cpp = true;
	summary.filter_dispatch_summary_recovered = true;
	summary.static_4a696b_direct_mutation_surface_recovered = true;
	summary.static_4a7605_fallback_coordinator_surface_recovered = true;
	summary.target_mode_4a696b_direct_mutation_excluded_supported_land = true;
	summary.multi_seed_4a696b_pair_gate_recovered = true;
	summary.live_4a696b_direct_mutation_sites_not_hit = true;
	summary.hit_4a696b_from_4a79a3 = true;
	summary.hit_4a7605_from_4a79a3 = true;
	summary.hit_pair_mark_sites = true;
	summary.direct_4a696b_mutation_adopted = false;
	summary.delegated_4a7605_afterstate_materialized = false;
	summary.generated_cell_mutation_replay_complete = false;
	summary.dispatch_4a696b_from_4a79a3_count = 1;
	summary.dispatch_4a7605_from_4a79a3_count = 1;
	summary.source_4a696b_combined_entries = 150;
	summary.source_4a696b_source_relation_match_hits = 0;
	summary.source_4a696b_candidate_append_hits = 0;
	summary.source_4a696b_direct_mutation_hits = 0;
	summary.source_4a696b_complete_grid_scan_count = 6;
	summary.source_4a696b_zero_owner_relation_pair_match_scan_count = 6;
	summary.source_4a696b_scanned_cell_total = 5752;
	summary.source_4a696b_seed_count = 3;
	summary.source_4a696b_byte2_only_or_any_match_total = 3639;
	summary.source_4a696b_byte3_only_or_any_match_total = 33;
	summary.trace_4a696b_entry_count = 4;
	summary.trace_4a7605_entry_count = 1;
	summary.trace_4a7312_call_count = 2;
	summary.trace_4a7312_vtable_commit_count = 2;
	summary.trace_4a696b_direct_mutation_site_hit_count = 0;
	summary.static_4a7605_endpoint_policy_4a7312_count = 4;
	summary.static_4a7605_endpoint_writer_4a746b_count = 2;
	summary.static_4a7605_materializer_4a5e03_count = 2;
	summary.static_4a7605_record_initializer_49ba89_count = 4;
	summary.static_4a7605_coordinate_append_40bb15_count = 4;
	summary.static_4a7605_coordinate_merge_40bb26_count = 3;
	summary.static_4a7605_direct_generated_cell_28_write_count = 0;
	summary.status = "diagnostic_4a79a3_endpoint_dispatch_exclusion_ported";
	summary.blocked_reason = "delegated_0x4a7605_afterstate_and_native_live_object_vector_records_not_materialized";
	return summary;
}

ObjectVectorPrerequisiteContractSummaryPlain build_object_vector_prerequisite_contract_summary(const ControlledCase &controlled_case, const GeneratedCellBitHelperSummaryPlain &bit_summary, const RelationNormalizationContractSummaryPlain &relation_normalization_summary, const ObjectVectorCommitMutationSummaryPlain &commit_summary, const ObjectVectorPayloadOrderSummaryPlain &payload_order_summary, const ObjectVectorEndpointDispatchSummaryPlain &endpoint_dispatch_summary) {
	ObjectVectorPrerequisiteContractSummaryPlain summary;
	summary.generated_cell_bit_helpers_available = bit_summary.helper_contracts_ported_plain_cpp;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.width = map_width_for_size(controlled_case.size_class);
	summary.height = summary.width;
	summary.level_count = controlled_case.level_count;
	summary.seed = controlled_case.seed;
	if (!summary.generated_cell_bit_helpers_available) {
		summary.status = "blocked_until_generated_cell_bit_helpers";
		summary.blocked_reason = "generated_cell_bit_helpers_missing";
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	summary.object_vector_contract_ported_plain_cpp = true;
	const DescriptorSourceIdentityClosureSummaryPlain descriptor_identity_summary = build_descriptor_source_identity_closure_summary(controlled_case);
	summary.descriptor_source_identity_closure_ported_plain_cpp = descriptor_identity_summary.descriptor_source_identity_closure_ported_plain_cpp;
	summary.descriptor_source_identity_r4_crosswalk_recovered = descriptor_identity_summary.r4_descriptor_source_identity_crosswalk_recovered;
	summary.descriptor_source_identity_native_behavior_changed = descriptor_identity_summary.native_behavior_changed;
	summary.descriptor_plus_0x00_registry_key_not_row_recovered = descriptor_identity_summary.descriptor_plus_0x00_registry_key_not_row_recovered;
	summary.descriptor_copied_source_record_identity_authority_recovered = descriptor_identity_summary.copied_source_record_identity_authority_required;
	summary.object_vector_commit_mutation_helpers_ported_plain_cpp = commit_summary.commit_mutation_helpers_ported_plain_cpp;
	summary.object_vector_projection_write_helpers_ported_plain_cpp = commit_summary.projection_write_helpers_ported_plain_cpp;
	summary.object_vector_49cf34_attach_mutation_helpers_ported_plain_cpp = commit_summary.attach_mutation_helpers_ported_plain_cpp;
	summary.object_vector_4a79a3_payload_order_ported_plain_cpp = payload_order_summary.object_vector_4a79a3_payload_order_ported_plain_cpp;
	summary.object_vector_4a79a3_payload_order_records_match_recovered = payload_order_summary.payload_order_records_match_recovered;
	summary.object_vector_endpoint_dispatch_exclusion_ported_plain_cpp = endpoint_dispatch_summary.endpoint_dispatch_contract_ported_plain_cpp;
	summary.endpoint_dispatch_4a696b_direct_mutation_excluded_supported_land =
			endpoint_dispatch_summary.target_mode_4a696b_direct_mutation_excluded_supported_land;
	summary.endpoint_dispatch_4a7605_delegated_materialization_afterstate_pending =
			!endpoint_dispatch_summary.delegated_4a7605_afterstate_materialized;
	summary.relation_normalization_contract_ported_plain_cpp =
			relation_normalization_summary.relation_normalization_contract_ported_plain_cpp;
	summary.relation_normalization_4a59e2_pack_materialized_plain_cpp =
			relation_normalization_summary.helper_0x4a59e2_pack_materialized_plain_cpp;
	summary.relation_normalization_full_grid_reset_materialized_plain_cpp =
			relation_normalization_summary.full_grid_reset_0x4a5767_materialized_plain_cpp;
	summary.relation_normalization_source_cell_clear_0x49a318_primitive_materialized =
			relation_normalization_summary.propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp;
	summary.relation_normalization_source_cell_projection_triple_minus_one_primitive_materialized =
			relation_normalization_summary.propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp;
	summary.relation_normalization_source_cell_clear_live_application_pending =
			relation_normalization_summary.propagation_source_cell_clear_live_application_pending;
	summary.relation_normalization_projection_gate_reset_materialized =
			relation_normalization_summary.generated_cell_word_0x1c_reset_gate_materialized;
	summary.relation_normalization_projection_triple_reset_materialized =
			relation_normalization_summary.generated_cell_projection_triple_reset_materialized;
	summary.relation_normalization_runtime_replay_pending =
			!relation_normalization_summary.runtime_ordered_replay_materialized;
	summary.relation_normalization_word20_low_word_propagation_pending =
			!relation_normalization_summary.generated_cell_word_0x20_low_word_propagation_materialized;
	summary.relation_normalization_projection_gate_pending =
			!relation_normalization_summary.generated_cell_word_0x1c_projection_gate_materialized;
	summary.relation_normalization_projection_triple_pending =
			!relation_normalization_summary.generated_cell_projection_triple_materialized;
	summary.relation_normalization_object_reference_filter_pending =
			!relation_normalization_summary.object_reference_vector_filter_materialized;
	summary.sampled_4a54a7_commit_mutation_samples_match = commit_summary.sample_count > 0
			&& commit_summary.matched_sample_count == commit_summary.sample_count;
	summary.sampled_4a56b6_projection_write_samples_match = commit_summary.projection_write_recovered_samples_match;
	summary.sampled_49cf34_attach_mutation_samples_match = commit_summary.attach_mutation_recovered_samples_match;
	summary.sampled_4a56b6_projection_write_full_stream_materialized =
			commit_summary.projection_write_full_stream_materialized_plain_cpp;
	summary.sampled_4a56b6_projection_write_unique_cell_count_matches =
			commit_summary.projection_write_unique_cell_count_matches_recovered;
	summary.sampled_4a56b6_projection_write_ordinals_cover_stream =
			commit_summary.projection_write_ordinals_cover_recovered_stream;
	summary.sampled_4a54a7_commit_mutation_sample_count = commit_summary.sample_count;
	summary.sampled_4a54a7_endpoint_clear_sample_count = commit_summary.endpoint_clear_sample_count;
	summary.sampled_4aa3e9_reward_lower_sample_count = commit_summary.reward_lower_sample_count;
	summary.sampled_4a56b6_projection_write_sample_count = commit_summary.projection_write_sample_count;
	summary.sampled_4a56b6_projection_write_matched_sample_count = commit_summary.projection_write_matched_sample_count;
	summary.sampled_4a56b6_projection_write_unique_cell_count = commit_summary.projection_write_unique_cell_count;
	summary.sampled_4a56b6_projection_write_ordinal_min = commit_summary.projection_write_ordinal_min;
	summary.sampled_4a56b6_projection_write_ordinal_max = commit_summary.projection_write_ordinal_max;
	summary.sampled_49cf34_attach_matched_write_pair_count = commit_summary.attach_matched_write_pair_count;
	summary.sampled_49cf34_attach_primary_write_pair_count = commit_summary.attach_primary_write_pair_count;
	summary.sampled_49cf34_attach_neighbor_write_pair_count = commit_summary.attach_neighbor_write_pair_count;
	summary.sampled_49cf34_attach_unique_cell_count = commit_summary.attach_unique_cell_count;
	summary.sampled_49cf34_attach_changed_write_pair_count = commit_summary.attach_changed_write_pair_count;
	summary.sampled_49cf34_attach_clears_bit26_count = commit_summary.attach_clears_bit26_count;
	summary.sampled_49cf34_attach_sets_bit27_from_clear_count = commit_summary.attach_sets_bit27_from_clear_count;
	summary.sampled_4a79a3_payload_record_count = payload_order_summary.record_count;
	summary.sampled_4a79a3_payload_vtable_0x00540a9c_count = payload_order_summary.record_vtable_0x00540a9c_count;
	summary.sampled_4a79a3_payload_vtable_0x00540a88_count = payload_order_summary.record_vtable_0x00540a88_count;
	summary.sampled_endpoint_dispatch_4a696b_entry_count = endpoint_dispatch_summary.trace_4a696b_entry_count;
	summary.sampled_endpoint_dispatch_4a7605_entry_count = endpoint_dispatch_summary.trace_4a7605_entry_count;
	summary.sampled_endpoint_dispatch_4a696b_source_relation_match_hits =
			endpoint_dispatch_summary.source_4a696b_source_relation_match_hits;
	summary.sampled_endpoint_dispatch_4a696b_direct_mutation_hits =
			endpoint_dispatch_summary.source_4a696b_direct_mutation_hits;
	summary.sampled_endpoint_dispatch_4a7605_endpoint_policy_count =
			endpoint_dispatch_summary.static_4a7605_endpoint_policy_4a7312_count;
	summary.recovered_reference_case_matches = controlled_case.seed == summary.expected_reference_seed
			&& summary.width == summary.expected_reference_width
			&& summary.height == summary.expected_reference_height
			&& controlled_case.level_count == 1
			&& controlled_case.water_mode == "land"
			&& controlled_case.players == 2;
	summary.status = summary.recovered_reference_case_matches
			? "diagnostic_object_vector_prerequisite_reference_seed58_descriptor_runtime_state_incomplete"
			: "diagnostic_object_vector_prerequisite_contract_ported_reference_only_same_case_stream_missing";
	summary.blocked_reason = "r4_descriptor_source_identity_crosswalk_relation_normalization_contract_and_4a79a3_endpoint_dispatch_exclusion_ported_but_0x4a5767_0x49a318_runtime_replay_same_run_4aa354_descriptor_vector_0x398_0x39c_selected_descriptor_state_0x94_0x95_native_live_object_vector_records_and_delegated_4a7605_afterstate_not_materialized";
	return summary;
}

RouteBoundaryContractSummaryPlain build_route_boundary_contract_summary(const ControlledCase &controlled_case, const GeneratedCellBitHelperSummaryPlain &bit_summary, const ObjectVectorPrerequisiteContractSummaryPlain &object_vector_summary) {
	RouteBoundaryContractSummaryPlain summary;
	summary.generated_cell_bit_helpers_available = bit_summary.helper_contracts_ported_plain_cpp;
	summary.supported_scope = supported_one_level_land_scope(controlled_case);
	summary.object_vector_prerequisite_available = object_vector_summary.object_vector_contract_ported_plain_cpp;
	summary.width = map_width_for_size(controlled_case.size_class);
	summary.height = summary.width;
	summary.level_count = controlled_case.level_count;
	summary.seed = controlled_case.seed;
	summary.source_bit26_count = bit_summary.source_bit26_count;
	summary.source_bit27_count = bit_summary.source_bit27_count;
	summary.diagnostic_final_bit26_count = bit_summary.diagnostic_final_bit26_count;
	summary.diagnostic_final_bit27_count = bit_summary.diagnostic_final_bit27_count;
	if (!summary.generated_cell_bit_helpers_available) {
		summary.status = "blocked_until_generated_cell_bit_helpers";
		summary.blocked_reason = "generated_cell_bit_helpers_missing";
		return summary;
	}
	if (!summary.supported_scope) {
		summary.status = "unsupported_scope";
		summary.blocked_reason = "unsupported_non_small_medium_one_level_land";
		return summary;
	}

	summary.route_contract_ported_plain_cpp = true;
	summary.native_object_vector_order_materialized = object_vector_summary.native_object_vector_order_materialized;
	summary.same_run_descriptor_state_complete = object_vector_summary.same_run_descriptor_state_complete;
	summary.generated_cell_mutation_replay_complete = object_vector_summary.generated_cell_mutation_replay_complete;
	summary.projection_write_coordinates_materialized = object_vector_summary.projection_write_coordinates_materialized;
	summary.recovered_reference_case_matches = controlled_case.seed == summary.expected_reference_seed
			&& summary.width == summary.expected_reference_width
			&& summary.height == summary.expected_reference_height
			&& controlled_case.level_count == 1
			&& controlled_case.water_mode == "land"
			&& controlled_case.players == 2;
	summary.status = summary.recovered_reference_case_matches
			? "diagnostic_0x4a8260_route_contract_reference_seed58_materialized"
			: "diagnostic_0x4a8260_route_contract_ported_reference_only_same_case_stream_missing";
	summary.blocked_reason = "native_object_vector_order_or_descriptor_state_not_materialized_so_0x4a8260_cannot_mutate_live_generated_cells";
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
		out << "\"terrain_match_to_town\":" << (record.terrain_match_to_town ? "true" : "false") << ",";
		out << "\"allowed_h3maped_terrain_ids_for_49b53d\":";
		append_int_array_json(out, record.allowed_h3maped_terrain_ids);
		out << ",";
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
		out << "\"locator_node_index\":" << walk.locator_node_index << ",";
		out << "\"locator_status\":\"" << json_escape(walk.locator_status) << "\",";
		out << "\"nodes\":[";
		for (size_t node_index = 0; node_index < walk.cycle_nodes.size(); ++node_index) {
			if (node_index != 0) {
				out << ",";
			}
			const SourceCycleNodePlain &node = walk.cycle_nodes[node_index];
			out << "{";
			out << "\"model_node_index\":" << node.model_node_index << ",";
			out << "\"pair_index\":" << node.pair_index << ",";
			out << "\"next_index\":" << node.next_index << ",";
			out << "\"previous_index\":" << node.previous_index << ",";
			out << "\"next_pair_index\":" << node.next_pair_index << ",";
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

void append_source_descriptor_nodes_json(std::ostream &out, const std::vector<SourceDescriptorNodePlain> &nodes) {
	out << "[";
	for (size_t index = 0; index < nodes.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SourceDescriptorNodePlain &node = nodes[index];
		out << "{";
		out << "\"model_node_index\":" << node.model_node_index << ",";
		out << "\"x\":" << node.x << ",";
		out << "\"y\":" << node.y << ",";
		out << "\"has_payload\":" << (node.has_payload ? "true" : "false") << ",";
		out << "\"payload\":" << node.payload << ",";
		out << "\"pair_index\":" << node.pair_index << ",";
		out << "\"next_index\":" << node.next_index << ",";
		out << "\"previous_index\":" << node.previous_index << ",";
		out << "\"active\":" << (node.active ? "true" : "false") << ",";
		out << "\"finalized\":" << (node.finalized ? "true" : "false") << ",";
		out << "\"finalized_x\":" << node.finalized_x << ",";
		out << "\"finalized_y\":" << node.finalized_y;
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
	out << "    \"rmg_setup_object_0x44_supplied_by_controlled_case\": " << (summary.generator_mode.setup_object_0x44_supplied ? "true" : "false") << ",\n";
	out << "    \"rmg_setup_object_0x44_defaulted_from_0x4adf88_initializer\": " << (summary.generator_mode.setup_object_0x44_defaulted_from_initializer ? "true" : "false") << ",\n";
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
	out << "    \"source_descriptor_node_table_materialized\": true,\n";
	out << "    \"source_descriptor_node_count\": " << summary.source.source_descriptor_node_count << ",\n";
	out << "    \"source_descriptor_active_node_count\": " << summary.source.source_descriptor_active_node_count << ",\n";
	out << "    \"source_descriptor_finalized_node_count\": " << summary.source.source_descriptor_finalized_node_count << ",\n";
	out << "    \"source_descriptor_nodes\": ";
	append_source_descriptor_nodes_json(out, summary.source.descriptor_nodes);
	out << ",\n";
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
		out << "\"seed_descriptor_handoff_status\":\"" << json_escape(zone.seed_descriptor_handoff_status) << "\",";
		out << "\"seed_descriptor_source\":\"" << json_escape(zone.seed_descriptor_source) << "\",";
		out << "\"seed_x\":" << zone.seed_x << ",";
		out << "\"seed_y\":" << zone.seed_y << ",";
		out << "\"seed_level\":" << zone.seed_level << ",";
		out << "\"effective_seed_x\":" << zone.effective_seed_x << ",";
		out << "\"effective_seed_y\":" << zone.effective_seed_y << ",";
		out << "\"effective_seed_level\":" << zone.effective_seed_level << ",";
		out << "\"seed_relocated\":" << (zone.seed_relocated ? "true" : "false") << ",";
		out << "\"seed_in_bounds\":" << (zone.seed_in_bounds ? "true" : "false") << ",";
		out << "\"exact_seed_descriptor_handoff_ported\":" << (zone.exact_seed_descriptor_handoff_ported ? "true" : "false") << ",";
		out << "\"seed_descriptor_proxy_available\":" << (zone.seed_descriptor_proxy_available ? "true" : "false") << ",";
		out << "\"seed_descriptor_candidate_scan_count\":" << zone.seed_descriptor_candidate_scan_count << ",";
		out << "\"seed_descriptor_candidate_interior_count\":" << zone.seed_descriptor_candidate_interior_count << ",";
		out << "\"seed_descriptor_best_x\":" << zone.seed_descriptor_best_x << ",";
		out << "\"seed_descriptor_best_y\":" << zone.seed_descriptor_best_y << ",";
		out << "\"seed_descriptor_best_clearance\":" << zone.seed_descriptor_best_clearance << ",";
		out << "\"seed_descriptor_clip_branch\":\"" << json_escape(zone.seed_descriptor_clip_branch) << "\",";
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

void append_string_histogram_json(std::ostream &out, const std::map<std::string, int32_t> &histogram) {
	out << "{";
	size_t index = 0;
	for (const auto &item : histogram) {
		if (index != 0) {
			out << ",";
		}
		out << "\"" << json_escape(item.first) << "\": " << item.second;
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
	out << "    \"source\": \"plain-C++ checkpoint-2 boundary/span-fill surface over the currently materialized source-node walks\",\n";
	out << "    \"strict_port_scope\": \"private zone-word and reserved-flag cell buffer plus recovered 0x4a2777 boundary-vector append order over currently materialized source-node walks; no exact same-run h3maped generator+0x3f4 descriptor/vector, terrain repaint, generated-cell live feedback, object vectors, package adoption, or public map output\",\n";
	out << "    \"coordinate_replay_available\": " << (summary.coordinate_replay_available ? "true" : "false") << ",\n";
	out << "    \"source_node_walks_available\": " << (summary.source_node_walks_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"boundary_span_fill_materialized_plain_cpp\": " << (summary.boundary_span_fill_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"materializes_private_zone_cell_buffer\": " << (summary.private_zone_cell_buffer_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_private_generated_cell_owner_words\": " << (summary.generated_cell_owner_words_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_boundary_trace\": " << (summary.boundary_span_fill_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"materializes_source_descriptor_handoff_replay\": " << (summary.boundary_source_descriptor_handoff_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_native_boundary_vector_proxy_trace\": " << (summary.boundary_native_vector_trace_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_exact_h3maped_generator_0x3f4_boundary_vector\": " << (summary.boundary_exact_h3maped_vector_materialized ? "true" : "false") << ",\n";
	out << "    \"boundary_vector_blocked_reason\": \"" << (summary.boundary_exact_h3maped_vector_materialized
			? ""
			: "0x4a3a03 -> 0x4cca55 descriptor-node handoff is materialized and consumed in plain C++; exact generator+0x3f4 byte/vector parity remains blocked on completing the 0x4a2777 fallback/append record layout, so do not treat this trace as checkpoint-2 parity") << "\",\n";
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
	out << "    \"boundary_descriptor_handoff_walk_count\": " << summary.boundary_descriptor_handoff_walk_count << ",\n";
	out << "    \"boundary_descriptor_handoff_node_count\": " << summary.boundary_descriptor_handoff_node_count << ",\n";
	out << "    \"boundary_descriptor_handoff_missing_count\": " << summary.boundary_descriptor_handoff_missing_count << ",\n";
	out << "    \"boundary_descriptor_handoff_inactive_or_invalid_count\": " << summary.boundary_descriptor_handoff_inactive_or_invalid_count << ",\n";
	out << "    \"boundary_descriptor_handoff_guard_exhausted_count\": " << summary.boundary_descriptor_handoff_guard_exhausted_count << ",\n";
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
	out << "    \"boundary_vector_event_count\": " << summary.boundary_vector_event_count << ",\n";
	out << "    \"boundary_vector_event_sample_limit\": " << summary.boundary_vector_event_sample_limit << ",\n";
	out << "    \"boundary_vector_event_sample_truncated\": " << (summary.boundary_vector_event_sample_truncated ? "true" : "false") << ",\n";
	out << "    \"boundary_vector_events_by_anchor\": ";
	append_string_histogram_json(out, summary.boundary_vector_events_by_anchor);
	out << ",\n";
	out << "    \"boundary_vector_events_by_kind\": ";
	append_string_histogram_json(out, summary.boundary_vector_events_by_kind);
	out << ",\n";
	out << "    \"boundary_trace_write_count\": " << summary.boundary_trace_write_count << ",\n";
	out << "    \"boundary_unique_cell_count\": " << summary.boundary_unique_cell_count << ",\n";
	out << "    \"boundary_out_of_bounds_write_count\": " << summary.boundary_out_of_bounds_write_count << ",\n";
	out << "    \"boundary_loop_guard_exhausted\": " << (summary.boundary_loop_guard_exhausted ? "true" : "false") << ",\n";
	out << "    \"span_fill_attempt_count\": " << summary.span_fill_attempt_count << ",\n";
	out << "    \"span_fill_filled_zone_count\": " << summary.span_fill_filled_zone_count << ",\n";
	out << "    \"span_fill_seed_blocked_count\": " << summary.span_fill_seed_blocked_count << ",\n";
	out << "    \"span_fill_seed_relocated_count\": " << summary.span_fill_seed_relocated_count << ",\n";
	out << "    \"materializes_exact_0x4a325d_descriptor_seed_handoff\": " << (summary.span_fill_exact_seed_descriptor_handoff_materialized ? "true" : "false") << ",\n";
	out << "    \"span_fill_seed_handoff_blocked_reason\": \"" << (summary.span_fill_exact_seed_descriptor_handoff_materialized
			? ""
			: "0x4a325d reads the out-of-bounds relocation candidate list from its EBP+0x0c descriptor argument; native still uses current source-cycle walks as a labeled proxy until the exact 0x4a3a03 -> 0x4cca55 -> 0x4a325d descriptor handoff is ported") << "\",\n";
	out << "    \"span_fill_seed_out_of_bounds_count\": " << summary.span_fill_seed_out_of_bounds_count << ",\n";
	out << "    \"span_fill_seed_descriptor_handoff_unported_count\": " << summary.span_fill_seed_descriptor_handoff_unported_count << ",\n";
	out << "    \"span_fill_seed_descriptor_proxy_available_count\": " << summary.span_fill_seed_descriptor_proxy_available_count << ",\n";
	out << "    \"span_fill_seed_descriptor_proxy_candidate_scan_count\": " << summary.span_fill_seed_descriptor_proxy_candidate_scan_count << ",\n";
	out << "    \"span_fill_seed_descriptor_proxy_interior_candidate_count\": " << summary.span_fill_seed_descriptor_proxy_interior_candidate_count << ",\n";
	out << "    \"span_fill_seed_descriptor_proxy_relocated_count\": " << summary.span_fill_seed_descriptor_proxy_relocated_count << ",\n";
	out << "    \"span_fill_seed_descriptor_proxy_no_candidate_count\": " << summary.span_fill_seed_descriptor_proxy_no_candidate_count << ",\n";
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
	out << "    \"boundary_vector_events\": [";
	for (size_t index = 0; index < summary.boundary_vector_events.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const BoundaryVectorEventPlain &event = summary.boundary_vector_events[index];
		out << "{";
		out << "\"runtime_zone_index\":" << event.runtime_zone_index << ",";
		out << "\"source_zone_id\":" << event.source_zone_id << ",";
		out << "\"zone_word_id\":" << event.zone_word_id << ",";
		out << "\"vector_index\":" << event.vector_index << ",";
		out << "\"x\":" << event.x << ",";
		out << "\"y\":" << event.y << ",";
		out << "\"level\":" << event.level << ",";
		out << "\"event_kind\":\"" << json_escape(event.event_kind) << "\",";
		out << "\"h3maped_anchor\":\"" << json_escape(event.h3maped_anchor) << "\",";
		out << "\"native_source\":\"" << json_escape(event.native_source) << "\"";
		out << "}";
	}
	out << "],\n";
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
	out << "    \"rmg_setup_object_0x44_supplied_by_controlled_case\": " << (summary.generator_mode.setup_object_0x44_supplied ? "true" : "false") << ",\n";
	out << "    \"rmg_setup_object_0x44_defaulted_from_0x4adf88_initializer\": " << (summary.generator_mode.setup_object_0x44_defaulted_from_initializer ? "true" : "false") << ",\n";
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

void append_runtime_terrain_selection_summary_json(std::ostream &out, const RuntimeTerrainSelectionSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_runtime_terrain_selection_summary_v1\",\n";
	out << "    \"phase_id\": \"runtime_terrain_selection\",\n";
	out << "    \"h3maped_anchor\": \"0x49b53d\",\n";
	out << "    \"town_to_terrain_table_address\": \"0x540908\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered 0x49b53d runtime terrain selection over source allowed-terrain flags and 0x540908 town terrain table\",\n";
	out << "    \"coordinate_replay_available\": " << (summary.coordinate_replay_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"materializes_runtime_zone_terrain_ids\": " << (summary.materializes_runtime_zone_terrain_ids ? "true" : "false") << ",\n";
	out << "    \"rng_state_before_0x49b53d_uint32\": " << summary.rng_state_before_0x49b53d << ",\n";
	out << "    \"rng_state_after_0x49b53d_uint32\": " << summary.rng_state_after_0x49b53d << ",\n";
	out << "    \"selection_count\": " << summary.selection_count << ",\n";
	out << "    \"match_to_town_count\": " << summary.match_to_town_count << ",\n";
	out << "    \"allowed_flag_choice_count\": " << summary.allowed_flag_choice_count << ",\n";
	out << "    \"blank_allowed_mask_count\": " << summary.blank_allowed_mask_count << ",\n";
	out << "    \"forced_subterranean_count\": " << summary.forced_subterranean_count << ",\n";
	out << "    \"terrain_rng_call_count\": " << summary.terrain_rng_call_count << ",\n";
	out << "    \"monster_town_rng_call_count_0x49b4e1\": " << summary.monster_town_rng_call_count_0x49b4e1 << ",\n";
	out << "    \"selected_h3maped_terrain_ids\": ";
	append_int_array_json(out, summary.selected_h3maped_terrain_ids);
	out << ",\n";
	out << "    \"selections\": [";
	for (size_t index = 0; index < summary.selections.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RuntimeTerrainSelectionPlain &selection = summary.selections[index];
		out << "{";
		out << "\"runtime_zone_index\":" << selection.runtime_zone_index << ",";
		out << "\"level\":" << selection.level << ",";
		out << "\"terrain_match_to_town\":" << (selection.terrain_match_to_town ? "true" : "false") << ",";
		out << "\"town_choice_index\":" << selection.town_choice_index << ",";
		out << "\"eligible_h3maped_terrain_ids\":";
		append_int_array_json(out, selection.eligible_h3maped_terrain_ids);
		out << ",";
		out << "\"rng_value\":" << selection.rng_value << ",";
		out << "\"rng_modulus\":" << selection.rng_modulus << ",";
		out << "\"selected_allowed_ordinal\":" << selection.selected_allowed_ordinal << ",";
		out << "\"monster_town_rng_value\":" << selection.monster_town_rng_value << ",";
		out << "\"selected_monster_table_ordinal_0x49b4e1\":" << selection.selected_monster_table_ordinal_0x49b4e1 << ",";
		out << "\"selected_monster_table_value_materialized\":" << (selection.selected_monster_table_value_materialized ? "true" : "false") << ",";
		out << "\"selected_h3maped_terrain_id\":" << selection.selected_h3maped_terrain_id << ",";
		out << "\"selected_project_terrain_id\":\"" << json_escape(selection.selected_project_terrain_id) << "\",";
		out << "\"source\":\"" << json_escape(selection.source) << "\"";
		out << "}";
	}
	out << "],\n";
	out << "    \"blocked_next\": \"terrain_cell_writeout_0x4a3f27\"\n";
	out << "  }";
}

void append_terrain_cell_writeout_summary_json(std::ostream &out, const TerrainCellWriteoutSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_terrain_cell_writeout_summary_v1\",\n";
	out << "    \"phase_id\": \"terrain_cell_writeout\",\n";
	out << "    \"h3maped_anchor\": \"0x4a3f27\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered private terrain code writeout over the 0x4a325d zone-word buffer and 0x49b53d runtime terrain selections\",\n";
	out << "    \"strict_port_scope\": \"private generated-cell terrain code and owner-byte materialization only; no visual row selection or public package output\",\n";
	out << "    \"boundary_owner_words_available\": " << (summary.boundary_owner_words_available ? "true" : "false") << ",\n";
	out << "    \"runtime_terrain_selection_available\": " << (summary.runtime_terrain_selection_available ? "true" : "false") << ",\n";
	out << "    \"materializes_private_terrain_cell_buffer\": " << (summary.materializes_private_terrain_cell_buffer ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"cell_count\": " << summary.cell_count << ",\n";
	out << "    \"selected_runtime_zone_count\": " << summary.selected_runtime_zone_count << ",\n";
	out << "    \"assigned_owner_cell_count\": " << summary.assigned_owner_cell_count << ",\n";
	out << "    \"unassigned_water_cell_count\": " << summary.unassigned_water_cell_count << ",\n";
	out << "    \"owner_low_byte_counts\": ";
	append_int_histogram_json(out, summary.owner_low_byte_counts);
	out << ",\n";
	out << "    \"terrain_code_counts\": ";
	append_int_histogram_json(out, summary.terrain_code_counts);
	out << ",\n";
	out << "    \"blocked_next\": \"terrain_relation_eligibility_0x4a2ec3_then_live_visual_feedback_0x4bb74b_0x4bc5f0\"\n";
	out << "  }";
}

void append_terrain_cell_writeout_generated_cell_checkpoint_json(std::ostream &out, const TerrainCellWriteoutSummaryPlain &summary) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int64_t cell_count = int64_t(summary.cell_count);
	const bool supported = summary.materializes_private_terrain_cell_buffer
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
	out << "    \"checkpoint_id\": \"after_runtime_terrain_cell_writeout\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x4a3f27_after_0x49b53d_runtime_terrain_selection_before_0x4a2ec3_and_0x4bb74b\",\n";
	out << "    \"plain_cpp_stage\": \"after_runtime_terrain_cell_writeout_before_relation_eligibility\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? summary.width : 0) << ",\n";
	out << "    \"height\": " << (supported ? summary.height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? summary.level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"constructor_default_0xffff7fbc with byte2 owner only for runtime zones selected by 0x49b53d terrain ids\",\n";
	out << "    \"word_0x24_source\": \"constructor_default_0x00000548; terrain visual feedback not yet ported in this checkpoint\",\n";
	out << "    \"word_0x28_source\": \"constructor_default_bit25_bit27 before recovered 0x4a2ec3 bit28 writes\",\n";
	out << "    \"word_0x2c_source\": \"not_recorded_for_this_terrain_cell_writeout_checkpoint\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2 after terrain selected owner materialization\",\n";
	out << "    \"status\": \"" << (supported ? "available_plain_cpp_runtime_terrain_cell_writeout" : "blocked_runtime_terrain_cell_writeout_unavailable") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"word_0x20_owner_byte_materialized_count\": " << (supported ? summary.assigned_owner_cell_count : 0) << ",\n";
	out << "    \"word_0x20_unassigned_sentinel_count\": " << (supported ? summary.unassigned_water_cell_count : 0) << ",\n";
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

void append_filled_zone_geometry_records_json(std::ostream &out, const std::vector<FilledZoneGeometryPlain> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const FilledZoneGeometryPlain &record = records[index];
		out << "{";
		out << "\"runtime_zone_index\":" << record.runtime_zone_index << ",";
		out << "\"zone_word_id\":" << record.zone_word_id << ",";
		out << "\"filled_cell_count\":" << record.filled_cell_count << ",";
		out << "\"has_filled_cells\":" << (record.has_filled_cells ? "true" : "false") << ",";
		out << "\"relation_type_0x0c\":" << record.relation_type_0x0c << ",";
		out << "\"filled_rect_min_x_0x20\":" << record.filled_rect_min_x_0x20 << ",";
		out << "\"filled_rect_min_y_0x24\":" << record.filled_rect_min_y_0x24 << ",";
		out << "\"filled_rect_max_x_exclusive_0x28\":" << record.filled_rect_max_x_exclusive_0x28 << ",";
		out << "\"filled_rect_max_y_exclusive_0x2c\":" << record.filled_rect_max_y_exclusive_0x2c << ",";
		out << "\"centroid_x_0x10\":" << record.centroid_x_0x10 << ",";
		out << "\"centroid_y_0x14\":" << record.centroid_y_0x14 << ",";
		out << "\"centroid_level_0x18\":" << record.centroid_level_0x18;
		out << "}";
	}
	out << "]";
}

void append_terrain_relation_eligibility_samples_json(std::ostream &out, const std::vector<TerrainRelationEligibilitySamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const TerrainRelationEligibilitySamplePlain &sample = samples[index];
		out << "{";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"flat_cell_index\":" << sample.flat_cell_index << ",";
		out << "\"relation_index\":" << sample.relation_index << ",";
		out << "\"relation_owner_byte2\":" << sample.relation_owner_byte2 << ",";
		out << "\"source\":\"0x4a2ec3_bit28_owner_match_inside_0x4a2105_relation_rect\"";
		out << "}";
	}
	out << "]";
}

void append_terrain_relation_eligibility_summary_json(std::ostream &out, const TerrainRelationEligibilitySummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_terrain_relation_eligibility_summary_v1\",\n";
	out << "    \"phase_id\": \"terrain_relation_eligibility\",\n";
	out << "    \"h3maped_geometry_anchor\": \"0x4a2105_0x4a2ffa\",\n";
	out << "    \"h3maped_mutation_anchor\": \"0x4a2ec3\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered filled-zone rectangle materialization and owner-byte gated cell+0x28 bit-28 eligibility mutation before terrain visual feedback\",\n";
	out << "    \"strict_port_scope\": \"generated-cell word 0x28 terrain relation eligibility only; no terrain visual selection, queue drain, object vectors, package adoption, or public map output\",\n";
	out << "    \"boundary_owner_words_available\": " << (summary.boundary_owner_words_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"relation_geometry_materialized_plain_cpp\": " << (summary.relation_geometry_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"generated_cell_relation_eligibility_materialized\": " << (summary.generated_cell_relation_eligibility_materialized ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"cell_count\": " << summary.cell_count << ",\n";
	out << "    \"runtime_zone_count\": " << summary.runtime_zone_count << ",\n";
	out << "    \"relation_geometry_record_count_0x4a2105_0x4a2ffa\": " << summary.relation_geometry_record_count_0x4a2105_0x4a2ffa << ",\n";
	out << "    \"relation_geometry_filled_record_count_0x4a2105_0x4a2ffa\": " << summary.relation_geometry_filled_record_count_0x4a2105_0x4a2ffa << ",\n";
	out << "    \"terrain_relation_eligibility_record_count_0x4a2ec3\": " << summary.terrain_relation_eligibility_record_count_0x4a2ec3 << ",\n";
	out << "    \"terrain_relation_eligibility_scan_cell_count_0x4a2ec3\": " << summary.terrain_relation_eligibility_scan_cell_count_0x4a2ec3 << ",\n";
	out << "    \"terrain_relation_eligibility_owner_match_count_0x4a2ec3\": " << summary.terrain_relation_eligibility_owner_match_count_0x4a2ec3 << ",\n";
	out << "    \"terrain_relation_eligibility_bit28_set_count_0x4a2ec3\": " << summary.terrain_relation_eligibility_bit28_set_count_0x4a2ec3 << ",\n";
	out << "    \"terrain_relation_eligibility_relation_type_8_skip_count_0x4a2ec3\": " << summary.terrain_relation_eligibility_relation_type_8_skip_count_0x4a2ec3 << ",\n";
	out << "    \"samples_0x4a2ec3\": ";
	append_terrain_relation_eligibility_samples_json(out, summary.samples);
	out << ",\n";
	out << "    \"filled_zone_geometry_records_0x4a2105_0x4a2ffa\": ";
	append_filled_zone_geometry_records_json(out, summary.geometry_records);
	out << ",\n";
	out << "    \"blocked_next\": \"port_live_visual_feedback_0x4bb74b_0x4bc5f0_word_0x24_0x28_terrain_mutations_then_compare_pre_0x4a4c8e\"\n";
	out << "  }";
}

void append_terrain_relation_eligibility_generated_cell_checkpoint_json(std::ostream &out, const TerrainRelationEligibilitySummaryPlain &summary) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int64_t cell_count = int64_t(summary.cell_count);
	const bool supported = summary.generated_cell_relation_eligibility_materialized
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
	out << "    \"checkpoint_id\": \"after_terrain_relation_eligibility\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x4a2ec3_after_relation_rect_owner_gate_before_0x4a4082_0x4bb74b_0x4bc5f0_and_0x4a4c8e\",\n";
	out << "    \"plain_cpp_stage\": \"after_terrain_relation_eligibility_bit28_before_live_visual_feedback\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? summary.width : 0) << ",\n";
	out << "    \"height\": " << (supported ? summary.height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? summary.level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"owner byte2 inherited from after_boundary_span_fill_owner_words\",\n";
	out << "    \"word_0x24_source\": \"constructor_default_0x00000548; terrain visual feedback not yet ported in this checkpoint\",\n";
	out << "    \"word_0x28_source\": \"constructor_default_bit25_bit27 plus recovered 0x4a2ec3 terrain relation eligibility bit28 writes\",\n";
	out << "    \"word_0x2c_source\": \"not_recorded_for_this_relation_eligibility_checkpoint\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2 after 0x4a325d owner materialization\",\n";
	out << "    \"status\": \"" << (supported ? "available_plain_cpp_terrain_relation_eligibility" : "blocked_terrain_relation_eligibility_unavailable") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"terrain_relation_eligibility_bit28_set_count_0x4a2ec3\": " << (supported ? summary.terrain_relation_eligibility_bit28_set_count_0x4a2ec3 : 0) << ",\n";
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

void append_terrain_live_feedback_samples_json(std::ostream &out, const std::vector<TerrainLiveFeedbackSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const TerrainLiveFeedbackSamplePlain &sample = samples[index];
		out << "{";
		out << "\"index\":" << sample.index << ",";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"terrain_id\":" << sample.terrain_id << ",";
		out << "\"class\":" << sample.shape_class << ",";
		out << "\"neighbor_mask\":" << sample.neighbor_mask << ",";
		out << "\"source_branch\":\"" << json_escape(sample.source_branch) << "\",";
		out << "\"selector_address\":\"" << json_escape(sample.selector_address) << "\",";
		out << "\"selector_kind\":\"" << json_escape(sample.selector_kind) << "\",";
		out << "\"probability_threshold\":" << sample.probability_threshold << ",";
		out << "\"probability_rng_value\":" << sample.probability_rng_value << ",";
		out << "\"selected_row\":" << sample.selected_row << ",";
		out << "\"scratch_word_u16\":" << sample.scratch_word << ",";
		out << "\"generated_cell_word_0x24_u32\":" << sample.generated_cell_word_0x24 << ",";
		out << "\"generated_cell_word_0x28_u32\":" << sample.generated_cell_word_0x28;
		out << "}";
	}
	out << "]";
}

void append_terrain_live_feedback_seed_samples_json(std::ostream &out, const std::vector<TerrainLiveFeedbackSeedSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const TerrainLiveFeedbackSeedSamplePlain &sample = samples[index];
		out << "{";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"terrain_before_drain\":" << sample.terrain_before_drain << ",";
		out << "\"current_repaint_terrain\":" << sample.current_repaint_terrain << ",";
		out << "\"source_branch\":\"" << json_escape(sample.source_branch) << "\"";
		out << "}";
	}
	out << "]";
}

void append_terrain_live_feedback_drain_samples_json(std::ostream &out, const std::vector<TerrainLiveFeedbackDrainSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const TerrainLiveFeedbackDrainSamplePlain &sample = samples[index];
		out << "{";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"terrain_id\":" << sample.terrain_id << ",";
		out << "\"source_branch\":\"" << json_escape(sample.source_branch) << "\",";
		out << "\"branch\":\"" << json_escape(sample.branch) << "\",";
		out << "\"from_x\":" << sample.from_x << ",";
		out << "\"from_y\":" << sample.from_y << ",";
		out << "\"target_x\":" << sample.target_x << ",";
		out << "\"target_y\":" << sample.target_y << ",";
		out << "\"changed_terrain\":" << (sample.changed_terrain ? "true" : "false") << ",";
		out << "\"is_retouch\":" << (sample.is_retouch ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_terrain_live_feedback_summary_json(std::ostream &out, const TerrainLiveFeedbackSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_terrain_live_feedback_summary_v1\",\n";
	out << "    \"phase_id\": \"terrain_live_feedback\",\n";
	out << "    \"h3maped_anchor\": \"0x4a4025_0x4a4082_0x4bb74b_0x4bc5f0_0x4bbfcc\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered TerrainPlacement live visual feedback over private generated-cell words; no package tile or public map adoption\",\n";
	out << "    \"strict_port_scope\": \"private TerrainPlacement scratch/generated-cell word feedback only; no 0x49b2b6 tile-byte projection, map cells, package tiles, roads, objects, or public output\",\n";
	out << "    \"terrain_relation_eligibility_available\": " << (summary.terrain_relation_eligibility_available ? "true" : "false") << ",\n";
	out << "    \"visual_tables_decoded\": " << (summary.visual_tables_decoded ? "true" : "false") << ",\n";
	out << "    \"live_feedback_materialized\": " << (summary.live_feedback_materialized ? "true" : "false") << ",\n";
	out << "    \"materializes_private_generated_cell_words\": " << (summary.materializes_private_generated_cell_words ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"cell_count\": " << summary.cell_count << ",\n";
	out << "    \"exact_queue_drain_complete\": " << (summary.exact_queue_drain_complete ? "true" : "false") << ",\n";
	out << "    \"drain_guard_limit\": " << summary.drain_guard_limit << ",\n";
	out << "    \"drain_guard_exhausted\": " << (summary.drain_guard_exhausted ? "true" : "false") << ",\n";
	out << "    \"rng_state_before_live_visual_selection_uint32\": " << summary.rng_state_before_live_visual_selection << ",\n";
	out << "    \"rng_state_after_live_visual_selection_uint32\": " << summary.rng_state_after_live_visual_selection << ",\n";
	out << "    \"live_cell_word_0x20_owner_byte_materialized_count\": " << summary.live_cell_word_0x20_owner_byte_materialized_count << ",\n";
	out << "    \"live_cell_word_0x20_unassigned_sentinel_count\": " << summary.live_cell_word_0x20_unassigned_sentinel_count << ",\n";
	out << "    \"live_visual_attempt_count\": " << summary.live_visual_attempt_count << ",\n";
	out << "    \"live_visual_write_count\": " << summary.live_visual_write_count << ",\n";
	out << "    \"live_visual_missing_bucket_count\": " << summary.live_visual_missing_bucket_count << ",\n";
	out << "    \"live_initial_water_attempt_count\": " << summary.live_initial_water_attempt_count << ",\n";
	out << "    \"live_repaint_attempt_count\": " << summary.live_repaint_attempt_count << ",\n";
	out << "    \"live_queue_attempt_count\": " << summary.live_queue_attempt_count << ",\n";
	out << "    \"live_dirty_cell_count\": " << summary.live_dirty_cell_count << ",\n";
	out << "    \"live_roundtrip_mismatch_count\": " << summary.live_roundtrip_mismatch_count << ",\n";
	out << "    \"live_terrain_mismatch_count\": " << summary.live_terrain_mismatch_count << ",\n";
	out << "    \"live_full_native_cell_count\": " << summary.live_full_native_cell_count << ",\n";
	out << "    \"live_terrain_art_nonzero_cell_count\": " << summary.live_terrain_art_nonzero_cell_count << ",\n";
	out << "    \"live_terrain_flag_cell_count\": " << summary.live_terrain_flag_cell_count << ",\n";
	out << "    \"live_cell_word_0x28_bit25_default_write_count\": " << summary.live_cell_word_0x28_bit25_default_write_count << ",\n";
	out << "    \"post_queue_terrain_difference_count\": " << summary.post_queue_terrain_difference_count << ",\n";
	out << "    \"terrain_relation_repaint_record_count_0x4a4082\": " << summary.terrain_relation_repaint_record_count_0x4a4082 << ",\n";
	out << "    \"terrain_relation_repaint_scan_cell_count_0x4a4082\": " << summary.terrain_relation_repaint_scan_cell_count_0x4a4082 << ",\n";
	out << "    \"terrain_relation_repaint_owner_mismatch_count_0x4a4082\": " << summary.terrain_relation_repaint_owner_mismatch_count_0x4a4082 << ",\n";
	out << "    \"terrain_relation_repaint_bit28_reject_count_0x4a4082\": " << summary.terrain_relation_repaint_bit28_reject_count_0x4a4082 << ",\n";
	out << "    \"terrain_relation_repaint_type8_skip_count_0x4a4082\": " << summary.terrain_relation_repaint_type8_skip_count_0x4a4082 << ",\n";
	out << "    \"changed_cell_update_count\": " << summary.changed_cell_update_count << ",\n";
	out << "    \"initial_set_a_candidate_count\": " << summary.max_set_a_count << ",\n";
	out << "    \"initial_set_b_candidate_count\": " << summary.max_set_b_count << ",\n";
	out << "    \"total_set_a_insert_count\": " << summary.total_set_a_insert_count << ",\n";
	out << "    \"total_set_a_neighbor_remove_count\": " << summary.total_set_a_neighbor_remove_count << ",\n";
	out << "    \"total_set_b_insert_count\": " << summary.total_set_b_insert_count << ",\n";
	out << "    \"total_set_b_current_remove_count\": " << summary.total_set_b_current_remove_count << ",\n";
	out << "    \"set_a_drain_count\": " << summary.set_a_drain_count << ",\n";
	out << "    \"set_b_drain_count\": " << summary.set_b_drain_count << ",\n";
	out << "    \"set_b_candidate_true_count\": " << summary.set_b_candidate_true_count << ",\n";
	out << "    \"retouched_cell_write_count\": " << summary.retouched_cell_write_count << ",\n";
	out << "    \"final_sweep_cell_count_0x4bbfcc\": " << summary.final_sweep_cell_count_0x4bbfcc << ",\n";
	out << "    \"final_sweep_boundary_cell_count_0x4bbfcc\": " << summary.final_sweep_boundary_cell_count_0x4bbfcc << ",\n";
	out << "    \"final_sweep_zero_boundary_cell_count_0x4bbfcc\": " << summary.final_sweep_zero_boundary_cell_count_0x4bbfcc << ",\n";
	out << "    \"final_sweep_max_boundary_count_0x4bbfcc\": " << summary.final_sweep_max_boundary_count_0x4bbfcc << ",\n";
	out << "    \"final_sweep_class_correction_count_0x4bbfcc\": " << summary.final_sweep_class_correction_count_0x4bbfcc << ",\n";
	out << "    \"neighbor_mask_histogram\": ";
	append_int_histogram_json(out, summary.neighbor_mask_histogram);
	out << ",\n";
	out << "    \"selector_kind_histogram\": ";
	append_string_histogram_json(out, summary.selector_kind_histogram);
	out << ",\n";
	out << "    \"final_sweep_boundary_count_histogram_0x4bbfcc\": ";
	append_int_histogram_json(out, summary.final_sweep_boundary_count_histogram_0x4bbfcc);
	out << ",\n";
	out << "    \"final_sweep_class_correction_histogram_0x4bbfcc\": ";
	append_string_histogram_json(out, summary.final_sweep_class_correction_histogram_0x4bbfcc);
	out << ",\n";
	out << "    \"sample_records\": ";
	append_terrain_live_feedback_samples_json(out, summary.samples);
	out << ",\n";
	out << "    \"seed_samples\": ";
	append_terrain_live_feedback_seed_samples_json(out, summary.seed_samples);
	out << ",\n";
	out << "    \"drain_samples\": ";
	append_terrain_live_feedback_drain_samples_json(out, summary.drain_samples);
	out << ",\n";
	out << "    \"blocked_next\": \"terrain_tile_byte_writeback_0x49b2b6_or_exact_same_run_pre_0x4a4c8e_compare\"\n";
	out << "  }";
}

void append_generated_cell_bit_helper_summary_json(std::ostream &out, const GeneratedCellBitHelperSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_generated_cell_bit_helper_summary_v1\",\n";
	out << "    \"phase_id\": \"generated_cell_bit_helper_contracts\",\n";
	out << "    \"h3maped_anchor\": \"0x49a1d8_0x49aa63_0x49a932_0x49a962\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ port of recovered generated-cell validity and bit26/bit27 helper contracts; diagnostic-only until exact object-reference vectors and 0x4a8260 route RNG boundary are ported\",\n";
	out << "    \"strict_port_scope\": \"helper contracts and copied-grid diagnostic surface only; no live generated-cell adoption, package objects, roads, guards, blockers, or public output\",\n";
	out << "    \"terrain_live_feedback_available\": " << (summary.terrain_live_feedback_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"helper_contracts_ported_plain_cpp\": " << (summary.helper_contracts_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"live_grid_mutation_adopted\": " << (summary.live_grid_mutation_adopted ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"cell_count\": " << summary.cell_count << ",\n";
	out << "    \"valid_0x49a1d8_count\": " << summary.valid_0x49a1d8_count << ",\n";
	out << "    \"invalid_0x49a1d8_count\": " << summary.invalid_0x49a1d8_count << ",\n";
	out << "    \"invalid_0x49a1d8_bit25_clear_count\": " << summary.invalid_0x49a1d8_bit25_clear_count << ",\n";
	out << "    \"invalid_0x49a1d8_terrain9_count\": " << summary.invalid_0x49a1d8_terrain9_count << ",\n";
	out << "    \"word_0x2c_bit0_lock_count\": " << summary.word_0x2c_bit0_lock_count << ",\n";
	out << "    \"source_bit26_count\": " << summary.source_bit26_count << ",\n";
	out << "    \"source_bit27_count\": " << summary.source_bit27_count << ",\n";
	out << "    \"terrain_8_9_occupied_scan_count\": " << summary.terrain_8_9_occupied_scan_count << ",\n";
	out << "    \"terrain_8_9_occupied_set_count_0x49a932\": " << summary.terrain_8_9_occupied_set_count_0x49a932 << ",\n";
	out << "    \"terrain_8_9_0x2c_skip_count\": " << summary.terrain_8_9_0x2c_skip_count << ",\n";
	out << "    \"candidate_0x49a962_call_count\": " << summary.candidate_0x49a962_call_count << ",\n";
	out << "    \"candidate_0x49a962_center_set_count_0x49aa63\": " << summary.candidate_0x49a962_center_set_count << ",\n";
	out << "    \"candidate_0x49a962_neighbor_scan_count\": " << summary.candidate_0x49a962_neighbor_scan_count << ",\n";
	out << "    \"candidate_0x49a962_neighbor_bit22_skip_count\": " << summary.candidate_0x49a962_neighbor_bit22_skip_count << ",\n";
	out << "    \"candidate_0x49a962_neighbor_invalid_skip_count\": " << summary.candidate_0x49a962_neighbor_invalid_skip_count << ",\n";
	out << "    \"candidate_0x49a962_neighbor_terrain8_skip_count\": " << summary.candidate_0x49a962_neighbor_terrain8_skip_count << ",\n";
	out << "    \"candidate_0x49a962_neighbor_clear_count_0x49a932\": " << summary.candidate_0x49a962_neighbor_clear_count_0x49a932 << ",\n";
	out << "    \"diagnostic_final_bit26_count\": " << summary.diagnostic_final_bit26_count << ",\n";
	out << "    \"diagnostic_final_bit27_count\": " << summary.diagnostic_final_bit27_count << ",\n";
	out << "    \"adoption_blocker\": \"exact_object_reference_vectors_plus_0x4a8260_route_rng_boundary_then_live_grid_compare_pre_0x4a4c8e\"\n";
	out << "  }";
}

void append_relation_normalization_contract_summary_json(std::ostream &out, const RelationNormalizationContractSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_relation_normalization_contract_v1\",\n";
	out << "    \"phase_id\": \"relation_normalization_contract_0x4a5767_0x49a318\",\n";
	out << "    \"h3maped_anchor\": \"0x4a5767_0x49a318_0x4a59e2_0x49a932_0x4a5a23\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ diagnostic import of recovered relation_normalization_summary_20260610.json and r6_relation_scoring_semantic_closure_summary_20260611.json; this is a no-Godot phase-snapshot contract, not a map-output mutation\",\n";
	out << "    \"strict_port_scope\": \"relation-normalization adoption precondition only; no live generated-cell adoption, no density scalar, no gate tuning, no package objects, roads, guards, blockers, or public output\",\n";
	out << "    \"working_name\": \"" << json_escape(summary.working_name) << "\",\n";
	out << "    \"terrain_live_feedback_available\": " << (summary.terrain_live_feedback_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_contract_ported_plain_cpp\": " << (summary.relation_normalization_contract_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"helper_0x4a59e2_pack_materialized_plain_cpp\": " << (summary.helper_0x4a59e2_pack_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"full_grid_reset_0x4a5767_materialized_plain_cpp\": " << (summary.full_grid_reset_0x4a5767_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp\": " << (summary.propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp\": " << (summary.propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"propagation_source_cell_clear_live_application_pending\": " << (summary.propagation_source_cell_clear_live_application_pending ? "true" : "false") << ",\n";
	out << "    \"generated_cell_word_0x1c_reset_gate_materialized\": " << (summary.generated_cell_word_0x1c_reset_gate_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_projection_triple_reset_materialized\": " << (summary.generated_cell_projection_triple_reset_materialized ? "true" : "false") << ",\n";
	out << "    \"static_surface_markers_recovered\": " << (summary.static_surface_markers_recovered ? "true" : "false") << ",\n";
	out << "    \"r6_semantic_surface_recovered\": " << (summary.r6_semantic_surface_recovered ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"native_behavior_changed\": " << (summary.native_behavior_changed ? "true" : "false") << ",\n";
	out << "    \"used_objdump\": " << (summary.used_objdump ? "true" : "false") << ",\n";
	out << "    \"runtime_ordered_replay_materialized\": " << (summary.runtime_ordered_replay_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_word_0x20_low_word_propagation_materialized\": " << (summary.generated_cell_word_0x20_low_word_propagation_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_word_0x1c_projection_gate_materialized\": " << (summary.generated_cell_word_0x1c_projection_gate_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_projection_triple_materialized\": " << (summary.generated_cell_projection_triple_materialized ? "true" : "false") << ",\n";
	out << "    \"object_reference_vector_filter_materialized\": " << (summary.object_reference_vector_filter_materialized ? "true" : "false") << ",\n";
	out << "    \"descriptor_policy_table_materialized\": " << (summary.descriptor_policy_table_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_vector_runtime_order_materialized\": " << (summary.relation_vector_runtime_order_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_mutation_replay_complete\": " << (summary.generated_cell_mutation_replay_complete ? "true" : "false") << ",\n";
	out << "    \"selected_template_vector_profile_available\": " << (summary.selected_template_vector_profile_available ? "true" : "false") << ",\n";
	out << "    \"same_run_h3maped_hc4_seed10_template_vector_validated\": " << (summary.same_run_h3maped_hc4_seed10_template_vector_validated ? "true" : "false") << ",\n";
	out << "    \"selected_template_vector_candidate_count\": " << summary.selected_template_vector_candidate_count << ",\n";
	out << "    \"selected_template_vector_selected_index\": " << summary.selected_template_vector_selected_index << ",\n";
	out << "    \"selected_template_vector_rng_value\": " << summary.selected_template_vector_rng_value << ",\n";
	out << "    \"selected_template_vector_rng_state_after_selection_uint32\": " << summary.selected_template_vector_rng_state_after_selection << ",\n";
	out << "    \"selected_template_source_catalog_index\": " << summary.selected_template_source_catalog_index << ",\n";
	out << "    \"selected_template_id\": \"" << json_escape(summary.selected_template_id) << "\",\n";
	out << "    \"selected_template_source_name\": \"" << json_escape(summary.selected_template_source_name) << "\",\n";
	out << "    \"selected_template_zone_count\": " << summary.selected_template_zone_count << ",\n";
	out << "    \"selected_template_connection_count\": " << summary.selected_template_connection_count << ",\n";
	out << "    \"flat_template_link_seed_count\": " << summary.flat_template_link_seed_count << ",\n";
	out << "    \"flat_template_link_seed_border_guard_count\": " << summary.flat_template_link_seed_border_guard_count << ",\n";
	out << "    \"selected_candidate_relation_record_profile_available\": " << (summary.selected_candidate_relation_record_profile_available ? "true" : "false") << ",\n";
	out << "    \"same_run_h3maped_hc4_seed10_selected_candidate_relation_topology_recorded\": " << (summary.same_run_h3maped_hc4_seed10_selected_candidate_relation_topology_recorded ? "true" : "false") << ",\n";
	out << "    \"selected_candidate_relation_owner_count\": " << summary.selected_candidate_relation_owner_count << ",\n";
	out << "    \"selected_candidate_relation_total_record_count\": " << summary.selected_candidate_relation_total_record_count << ",\n";
	out << "    \"selected_candidate_relation_border_guard_record_count\": " << summary.selected_candidate_relation_border_guard_record_count << ",\n";
	out << "    \"selected_candidate_relation_record_stride_bytes\": " << summary.selected_candidate_relation_record_stride_bytes << ",\n";
	out << "    \"selected_candidate_relation_owner_record_counts\": ";
	append_int_array_json(out, summary.selected_candidate_relation_owner_record_counts);
	out << ",\n";
	out << "    \"selected_candidate_relation_owner_border_guard_counts\": ";
	append_int_array_json(out, summary.selected_candidate_relation_owner_border_guard_counts);
	out << ",\n";
	out << "    \"template_vs_selected_candidate_relation_record_count_delta\": " << summary.template_vs_selected_candidate_relation_record_count_delta << ",\n";
	out << "    \"template_vs_selected_candidate_border_guard_record_count_delta\": " << summary.template_vs_selected_candidate_border_guard_record_count_delta << ",\n";
	out << "    \"flat_template_link_seeds_are_runtime_relation_vector\": " << (summary.flat_template_link_seeds_are_runtime_relation_vector ? "true" : "false") << ",\n";
	out << "    \"flat_template_link_seed_surface_matches_selected_candidate_relation_records\": " << (summary.flat_template_link_seed_surface_matches_selected_candidate_relation_records ? "true" : "false") << ",\n";
	out << "    \"selected_candidate_relation_records_are_generator_0x10e4_runtime_vector\": " << (summary.selected_candidate_relation_records_are_generator_0x10e4_runtime_vector ? "true" : "false") << ",\n";
	out << "    \"generator_0x10e4_relation_pointer_records_materialized\": " << (summary.generator_0x10e4_relation_pointer_records_materialized ? "true" : "false") << ",\n";
	out << "    \"generator_0x10e8_relation_pointer_end_materialized\": " << (summary.generator_0x10e8_relation_pointer_end_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_vector_blocked_reason\": \"" << json_escape(summary.relation_vector_blocked_reason) << "\",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"seed\": " << summary.seed << ",\n";
	out << "    \"cell_count\": " << summary.cell_count << ",\n";
	out << "    \"reset_cell_count\": " << summary.reset_cell_count << ",\n";
	out << "    \"reset_expected_word_0x1c_hex\": \"0x7d007d00\",\n";
	out << "    \"reset_word_0x1c_0x7d007d00_count\": " << summary.reset_word_0x1c_0x7d007d00_count << ",\n";
	out << "    \"reset_projection_triple_minus_one_count\": " << summary.reset_projection_triple_minus_one_count << ",\n";
	out << "    \"reset_word_0x20_byte3_minus_one_count\": " << summary.reset_word_0x20_byte3_minus_one_count << ",\n";
	out << "    \"reset_word_0x28_bits_12_14_zero_count\": " << summary.reset_word_0x28_bits_12_14_zero_count << ",\n";
	out << "    \"propagation_source_cell_clear_sample_count\": " << summary.propagation_source_cell_clear_sample_count << ",\n";
	out << "    \"propagation_source_cell_clear_low_word_zero_count\": " << summary.propagation_source_cell_clear_low_word_zero_count << ",\n";
	out << "    \"propagation_source_cell_clear_high_word_preserved_count\": " << summary.propagation_source_cell_clear_high_word_preserved_count << ",\n";
	out << "    \"propagation_source_cell_projection_triple_minus_one_sample_count\": " << summary.propagation_source_cell_projection_triple_minus_one_sample_count << ",\n";
	out << "    \"static_marker_count\": " << summary.static_marker_count << ",\n";
	out << "    \"static_present_marker_count\": " << summary.static_present_marker_count << ",\n";
	out << "    \"static_missing_marker_count\": " << summary.static_missing_marker_count << ",\n";
	out << "    \"normalizer_0x4a5767_marker_count\": " << summary.normalizer_0x4a5767_marker_count << ",\n";
	out << "    \"normalizer_0x4a5767_present_marker_count\": " << summary.normalizer_0x4a5767_present_marker_count << ",\n";
	out << "    \"normalizer_0x4a5767_reference_marker_count\": " << summary.normalizer_0x4a5767_reference_marker_count << ",\n";
	out << "    \"normalizer_0x4a5767_reference_present_marker_count\": " << summary.normalizer_0x4a5767_reference_present_marker_count << ",\n";
	out << "    \"propagation_0x49a318_marker_count\": " << summary.propagation_0x49a318_marker_count << ",\n";
	out << "    \"propagation_0x49a318_present_marker_count\": " << summary.propagation_0x49a318_present_marker_count << ",\n";
	out << "    \"propagation_0x49a318_reference_marker_count\": " << summary.propagation_0x49a318_reference_marker_count << ",\n";
	out << "    \"propagation_0x49a318_reference_present_marker_count\": " << summary.propagation_0x49a318_reference_present_marker_count << ",\n";
	out << "    \"source_bit26_count\": " << summary.source_bit26_count << ",\n";
	out << "    \"source_bit27_count\": " << summary.source_bit27_count << ",\n";
	out << "    \"diagnostic_final_bit26_count\": " << summary.diagnostic_final_bit26_count << ",\n";
	out << "    \"diagnostic_final_bit27_count\": " << summary.diagnostic_final_bit27_count << ",\n";
	out << "    \"recovered_state_surface\": {\n";
	out << "      \"0x4a5767\": \"resets generated cells, walks generator+0x10e4..+0x10e8 relation vector, filters owner byte2, terrain, object-reference occupancy, bit27, and 0x49a1d8, calls 0x49a932, 0x49a318, and 0x4a5a23\",\n";
	out << "      \"0x49a318\": \"propagates generated-cell +0x1c, +0x20, +0x28, and +0x10/+0x14/+0x18 through direction offsets and descriptor policy table 0x57c648\",\n";
	out << "      \"generated_cell_0x20\": \"source-owner relation index plus projection distance or local score\",\n";
	out << "      \"generated_cell_0x1c\": \"projection/local gate word rewritten by reset and propagation\",\n";
	out << "      \"projection_triple\": \"generated-cell +0x10/+0x14/+0x18 coordinate triple\"\n";
	out << "    },\n";
	out << "    \"reset_sample_limit\": 8,\n";
	out << "    \"reset_samples\": [";
	for (size_t index = 0; index < summary.reset_samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RelationNormalizationResetSamplePlain &sample = summary.reset_samples[index];
		out << "{";
		out << "\"flat\":" << sample.flat << ",";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"word_0x10\":" << sample.word_0x10 << ",";
		out << "\"word_0x14\":" << sample.word_0x14 << ",";
		out << "\"word_0x18\":" << sample.word_0x18 << ",";
		out << "\"word_0x1c\":" << sample.word_0x1c << ",";
		out << "\"word_0x20\":" << sample.word_0x20 << ",";
		out << "\"word_0x28\":" << sample.word_0x28;
		out << "}";
	}
	out << "],\n";
	out << "    \"source_clear_sample_limit\": 8,\n";
	out << "    \"source_clear_samples\": [";
	for (size_t index = 0; index < summary.source_clear_samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RelationNormalizationSourceClearSamplePlain &sample = summary.source_clear_samples[index];
		out << "{";
		out << "\"flat\":" << sample.flat << ",";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"before_word_0x1c\":" << sample.before_word_0x1c << ",";
		out << "\"after_word_0x1c\":" << sample.after_word_0x1c << ",";
		out << "\"after_word_0x10\":" << sample.after_word_0x10 << ",";
		out << "\"after_word_0x14\":" << sample.after_word_0x14 << ",";
		out << "\"after_word_0x18\":" << sample.after_word_0x18 << ",";
		out << "\"low_word_cleared\":" << (sample.low_word_cleared ? "true" : "false") << ",";
		out << "\"high_word_preserved\":" << (sample.high_word_preserved ? "true" : "false") << ",";
		out << "\"projection_triple_minus_one\":" << (sample.projection_triple_minus_one ? "true" : "false");
		out << "}";
	}
	out << "],\n";
	out << "    \"adoption_blocker\": \"materialize_ordered_0x4a5767_0x49a318_runtime_replay_before_object_vector_route_road_or_package_generation_claims\"\n";
	out << "  }";
}

void append_object_vector_commit_mutation_samples_json(std::ostream &out, const std::vector<ObjectVectorCommitMutationSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const ObjectVectorCommitMutationSamplePlain &sample = samples[index];
		out << "{";
		out << "\"sample_id\":\"" << json_escape(sample.sample_id) << "\",";
		out << "\"source_anchor\":\"" << json_escape(sample.source_anchor) << "\",";
		out << "\"mutation_mode\":\"" << json_escape(sample.mutation_mode) << "\",";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"before_word_0x20\":" << sample.before_word_0x20 << ",";
		out << "\"before_word_0x24\":" << sample.before_word_0x24 << ",";
		out << "\"before_word_0x28\":" << sample.before_word_0x28 << ",";
		out << "\"before_word_0x2c\":" << sample.before_word_0x2c << ",";
		out << "\"expected_word_0x20\":" << sample.expected_word_0x20 << ",";
		out << "\"expected_word_0x24\":" << sample.expected_word_0x24 << ",";
		out << "\"expected_word_0x28\":" << sample.expected_word_0x28 << ",";
		out << "\"expected_word_0x2c\":" << sample.expected_word_0x2c << ",";
		out << "\"replay_word_0x20\":" << sample.replay_word_0x20 << ",";
		out << "\"replay_word_0x24\":" << sample.replay_word_0x24 << ",";
		out << "\"replay_word_0x28\":" << sample.replay_word_0x28 << ",";
		out << "\"replay_word_0x2c\":" << sample.replay_word_0x2c << ",";
		out << "\"match\":" << (sample.match ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_object_vector_projection_write_samples_json(std::ostream &out, const std::vector<ObjectVectorProjectionWriteSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const ObjectVectorProjectionWriteSamplePlain &sample = samples[index];
		out << "{";
		out << "\"ordinal\":" << sample.ordinal << ",";
		out << "\"recovered_cell_pointer\":" << sample.recovered_cell_pointer << ",";
		out << "\"x\":" << sample.x << ",";
		out << "\"y\":" << sample.y << ",";
		out << "\"level\":" << sample.level << ",";
		out << "\"before_word_0x1c\":" << sample.before_word_0x1c << ",";
		out << "\"before_word_0x20\":" << sample.before_word_0x20 << ",";
		out << "\"before_word_0x24\":" << sample.before_word_0x24 << ",";
		out << "\"before_word_0x28\":" << sample.before_word_0x28 << ",";
		out << "\"before_word_0x2c\":" << sample.before_word_0x2c << ",";
		out << "\"expected_word_0x20\":" << sample.expected_word_0x20 << ",";
		out << "\"replay_word_0x20\":" << sample.replay_word_0x20 << ",";
		out << "\"high_word_preserved\":" << (sample.high_word_preserved ? "true" : "false") << ",";
		out << "\"low_word_lowered\":" << (sample.low_word_lowered ? "true" : "false") << ",";
		out << "\"match\":" << (sample.match ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_object_vector_attach_mutation_samples_json(std::ostream &out, const std::vector<ObjectVectorAttachMutationSamplePlain> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const ObjectVectorAttachMutationSamplePlain &sample = samples[index];
		out << "{";
		out << "\"kind\":\"" << json_escape(sample.kind) << "\",";
		out << "\"recovered_cell_pointer\":" << sample.recovered_cell_pointer << ",";
		out << "\"probe_x\":" << sample.probe_x << ",";
		out << "\"probe_y\":" << sample.probe_y << ",";
		out << "\"relative_x\":" << sample.relative_x << ",";
		out << "\"relative_y\":" << sample.relative_y << ",";
		out << "\"direction_index\":" << sample.direction_index << ",";
		out << "\"descriptor_class_or_type\":" << sample.descriptor_class_or_type << ",";
		out << "\"before_word_0x28\":" << sample.before_word_0x28 << ",";
		out << "\"expected_word_0x28\":" << sample.expected_word_0x28 << ",";
		out << "\"replay_word_0x28\":" << sample.replay_word_0x28 << ",";
		out << "\"changed_mask\":" << sample.changed_mask << ",";
		out << "\"clears_bit26\":" << (sample.clears_bit26 ? "true" : "false") << ",";
		out << "\"sets_bit27_from_clear\":" << (sample.sets_bit27_from_clear ? "true" : "false") << ",";
		out << "\"leaves_bit27_set\":" << (sample.leaves_bit27_set ? "true" : "false") << ",";
		out << "\"match\":" << (sample.match ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_descriptor_source_identity_contexts_json(std::ostream &out, const std::vector<DescriptorSourceIdentityContextPlain> &contexts) {
	out << "[";
	for (size_t index = 0; index < contexts.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const DescriptorSourceIdentityContextPlain &context = contexts[index];
		out << "{";
		out << "\"return_address\":\"" << json_escape(context.return_address) << "\",";
		out << "\"descriptor_type\":" << context.descriptor_type << ",";
		out << "\"label\":\"" << json_escape(context.label) << "\",";
		out << "\"selected_sample_count\":" << context.selected_sample_count << ",";
		out << "\"joined_sample_count\":" << context.joined_sample_count << ",";
		out << "\"all_selected_samples_joined\":" << (context.all_selected_samples_joined ? "true" : "false") << ",";
		out << "\"unique_descriptor_identity_tuple_count\":" << context.unique_descriptor_identity_tuple_count << ",";
		out << "\"unique_catalog_type_subtype_resolution_count\":" << context.unique_catalog_type_subtype_resolution_count << ",";
		out << "\"ambiguous_catalog_type_subtype_resolution_count\":" << context.ambiguous_catalog_type_subtype_resolution_count << ",";
		out << "\"missing_catalog_type_subtype_resolution_count\":" << context.missing_catalog_type_subtype_resolution_count << ",";
		out << "\"row_mode\":{";
		out << "\"sample_count\":" << context.row_mode_sample_count << ",";
		out << "\"row_match_count\":" << context.row_mode_match_count << ",";
		out << "\"row_mismatch_count\":" << context.row_mode_mismatch_count << ",";
		out << "\"row_missing_count\":" << context.row_mode_missing_count;
		out << "},";
		out << "\"identity_authority\":\"" << json_escape(context.identity_authority) << "\"";
		out << "}";
	}
	out << "]";
}

void append_descriptor_source_identity_closure_summary_json(std::ostream &out, const DescriptorSourceIdentityClosureSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_descriptor_source_identity_closure_v1\",\n";
	out << "    \"phase_id\": \"descriptor_source_identity_closure_r4\",\n";
	out << "    \"h3maped_anchor\": \"0x4903e8_0x491eed_selected_descriptor_pointer_join\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ diagnostic import of recovered R4 descriptor/source identity crosswalk from r4_descriptor_source_identity_closure_summary_20260611.json and descriptor_build_selected_join_summary_20260610.json\",\n";
	out << "    \"strict_port_scope\": \"R4 descriptor/source identity diagnostic only; no native RMG behavior change, no descriptor-only identity adoption, no live generated-cell mutation, and no package output\",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"native_behavior_changed\": " << (summary.native_behavior_changed ? "true" : "false") << ",\n";
	out << "    \"used_objdump\": " << (summary.used_objdump ? "true" : "false") << ",\n";
	out << "    \"descriptor_source_identity_closure_ported_plain_cpp\": " << (summary.descriptor_source_identity_closure_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"r4_descriptor_source_identity_crosswalk_recovered\": " << (summary.r4_descriptor_source_identity_crosswalk_recovered ? "true" : "false") << ",\n";
	out << "    \"same_run_selected_descriptor_pointer_join_recovered\": " << (summary.same_run_selected_descriptor_pointer_join_recovered ? "true" : "false") << ",\n";
	out << "    \"all_target_mixed_selected_descriptors_joined\": " << (summary.all_target_mixed_selected_descriptors_joined ? "true" : "false") << ",\n";
	out << "    \"descriptor_input_type_subtype_class_fields_recovered\": " << (summary.descriptor_input_type_subtype_class_fields_recovered ? "true" : "false") << ",\n";
	out << "    \"descriptor_only_identity_not_claimed_for_ambiguous_mines\": " << (summary.descriptor_only_identity_not_claimed_for_ambiguous_mines ? "true" : "false") << ",\n";
	out << "    \"descriptor_plus_0x00_registry_key_not_row_recovered\": " << (summary.descriptor_plus_0x00_registry_key_not_row_recovered ? "true" : "false") << ",\n";
	out << "    \"object_table_loader_source_row_shape_recovered\": " << (summary.object_table_loader_source_row_shape_recovered ? "true" : "false") << ",\n";
	out << "    \"provider_mapping_covers_target_source_lanes_53_54_79\": " << (summary.provider_mapping_covers_target_source_lanes_53_54_79 ? "true" : "false") << ",\n";
	out << "    \"source_catalog_template_producer_recovered\": " << (summary.source_catalog_template_producer_recovered ? "true" : "false") << ",\n";
	out << "    \"source_record_cache_key_preserves_def_name_fields\": " << (summary.source_record_cache_key_preserves_def_name_fields ? "true" : "false") << ",\n";
	out << "    \"type45_base_loader_special_case_recovered\": " << (summary.type45_base_loader_special_case_recovered ? "true" : "false") << ",\n";
	out << "    \"copied_source_record_identity_authority_required\": " << (summary.copied_source_record_identity_authority_required ? "true" : "false") << ",\n";
	out << "    \"same_run_descriptor_state_complete\": " << (summary.same_run_descriptor_state_complete ? "true" : "false") << ",\n";
	out << "    \"selected_descriptor_count\": " << summary.selected_descriptor_count << ",\n";
	out << "    \"target_mixed_selected_descriptor_count\": " << summary.target_mixed_selected_descriptor_count << ",\n";
	out << "    \"target_mixed_joined_descriptor_count\": " << summary.target_mixed_joined_descriptor_count << ",\n";
	out << "    \"target_mixed_missing_join_count\": " << summary.target_mixed_missing_join_count << ",\n";
	out << "    \"build_event_count\": " << summary.build_event_count << ",\n";
	out << "    \"unique_built_descriptor_count\": " << summary.unique_built_descriptor_count << ",\n";
	out << "    \"provider_slot_pair_count\": " << summary.provider_slot_pair_count << ",\n";
	out << "    \"source_record_copy_size_bytes\": " << summary.source_record_copy_size_bytes << ",\n";
	out << "    \"fixed_score_before\": " << summary.fixed_score_before << ",\n";
	out << "    \"fixed_score_after\": " << summary.fixed_score_after << ",\n";
	out << "    \"remaining_fixed_budget_after\": " << summary.remaining_fixed_budget_after << ",\n";
	out << "    \"active_blocker_after\": \"" << json_escape(summary.active_blocker_after) << "\",\n";
	out << "    \"invariants\": {\n";
	out << "      \"no_native_behavior_change\": " << (!summary.native_behavior_changed ? "true" : "false") << ",\n";
	out << "      \"no_objdump_used\": " << (!summary.used_objdump ? "true" : "false") << ",\n";
	out << "      \"same_run_selected_descriptor_pointer_join_recovered\": " << (summary.same_run_selected_descriptor_pointer_join_recovered ? "true" : "false") << ",\n";
	out << "      \"all_target_mixed_selected_descriptors_joined\": " << (summary.all_target_mixed_selected_descriptors_joined ? "true" : "false") << ",\n";
	out << "      \"descriptor_input_type_subtype_class_fields_recovered\": " << (summary.descriptor_input_type_subtype_class_fields_recovered ? "true" : "false") << ",\n";
	out << "      \"descriptor_only_identity_not_claimed_for_ambiguous_mines\": " << (summary.descriptor_only_identity_not_claimed_for_ambiguous_mines ? "true" : "false") << ",\n";
	out << "      \"descriptor_plus_0x00_registry_key_not_row_recovered\": " << (summary.descriptor_plus_0x00_registry_key_not_row_recovered ? "true" : "false") << ",\n";
	out << "      \"object_table_loader_source_row_shape_recovered\": " << (summary.object_table_loader_source_row_shape_recovered ? "true" : "false") << ",\n";
	out << "      \"provider_mapping_covers_target_source_lanes_53_54_79\": " << (summary.provider_mapping_covers_target_source_lanes_53_54_79 ? "true" : "false") << ",\n";
	out << "      \"source_catalog_template_producer_recovered\": " << (summary.source_catalog_template_producer_recovered ? "true" : "false") << ",\n";
	out << "      \"source_record_cache_key_preserves_def_name_fields\": " << (summary.source_record_cache_key_preserves_def_name_fields ? "true" : "false") << ",\n";
	out << "      \"type45_base_loader_special_case_recovered\": " << (summary.type45_base_loader_special_case_recovered ? "true" : "false") << "\n";
	out << "    },\n";
	out << "    \"target_contexts\": ";
	append_descriptor_source_identity_contexts_json(out, summary.contexts);
	out << ",\n";
	out << "    \"source_record_identity_rule\": {\n";
	out << "      \"descriptor_plus_0x00\": \"Registry/source-key value returned by 0x491eed and copied into the descriptor by 0x4903e8; it is not a universal objects.txt row id.\",\n";
	out << "      \"descriptor_plus_0x1c\": \"Descriptor type/counter lane. For R4 mixed lanes this names 45, 53, 54, or 79.\",\n";
	out << "      \"descriptor_plus_0x20\": \"Subtype/source object id used with the copied source record and provider filters.\",\n";
	out << "      \"descriptor_plus_0x24\": \"Class/group-like selector used by resolver filters.\",\n";
	out << "      \"source_record\": \"The copied 0x4c source record is the catalog identity authority; descriptor-only identity is insufficient for ambiguous lanes such as mines.\"\n";
	out << "    },\n";
	out << "    \"adoption_blocker\": \"same_run_4aa354_descriptor_vector_0x398_0x39c_and_selected_descriptor_state_0x94_0x95_before_object_vector_identity_adoption\"\n";
	out << "  }";
}

void append_string_array_json(std::ostream &out, const std::vector<std::string> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		out << "\"" << json_escape(values[index]) << "\"";
	}
	out << "]";
}

void append_record_words_json(std::ostream &out, const std::array<uint32_t, 12> &words) {
	out << "[";
	for (size_t index = 0; index < words.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		out << words[index];
	}
	out << "]";
}

void append_object_vector_payload_order_records_json(std::ostream &out, const std::vector<ObjectVectorPayloadOrderRecordPlain> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const ObjectVectorPayloadOrderRecordPlain &record = records[index];
		out << "{";
		out << "\"event_index\":" << record.event_index << ",";
		out << "\"record_pointer\":\"" << json_escape(record.record_pointer) << "\",";
		out << "\"record_vtable\":\"" << json_escape(record.record_vtable) << "\",";
		out << "\"descriptor_pointer\":\"" << json_escape(record.descriptor_pointer) << "\",";
		out << "\"descriptor_source_pointer\":\"" << json_escape(record.descriptor_source_pointer) << "\",";
		out << "\"coordinate_or_payload_words_08_10\":[" << record.x << "," << record.y << "," << record.level << "],";
		out << "\"field_1c\":" << record.field_0x1c << ",";
		out << "\"field_20\":" << record.field_0x20 << ",";
		out << "\"field_24\":" << record.field_0x24 << ",";
		out << "\"field_28\":" << record.field_0x28 << ",";
		out << "\"field_2c\":" << record.field_0x2c << ",";
		out << "\"record_words\":";
		append_record_words_json(out, record.record_words);
		out << "}";
	}
	out << "]";
}

void append_object_vector_payload_order_summary_json(std::ostream &out, const ObjectVectorPayloadOrderSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_4a79a3_payload_order_v1\",\n";
	out << "    \"phase_id\": \"object_vector_payload_order_0x4a79a3\",\n";
	out << "    \"h3maped_anchor\": \"0x4a79a3_0x4a7d2c_0x4a7d36_0x4a7d99\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ diagnostic import of recovered 0x4a79a3 payload order from 4a79a3_payload_trace_summary.json\",\n";
	out << "    \"strict_port_scope\": \"recovered H3MapEd payload order and record-coordinate surface only; no native live object-vector adoption, no downstream generated-cell mutation replay, and no package output\",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"native_behavior_changed\": " << (summary.native_behavior_changed ? "true" : "false") << ",\n";
	out << "    \"object_vector_4a79a3_payload_order_ported_plain_cpp\": " << (summary.object_vector_4a79a3_payload_order_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"vector_entries_match_record_pointers\": " << (summary.vector_entries_match_record_pointers ? "true" : "false") << ",\n";
	out << "    \"record_payloads_dumped\": " << (summary.record_payloads_dumped ? "true" : "false") << ",\n";
	out << "    \"descriptor_wrappers_dumped\": " << (summary.descriptor_wrappers_dumped ? "true" : "false") << ",\n";
	out << "    \"payload_order_records_match_recovered\": " << (summary.payload_order_records_match_recovered ? "true" : "false") << ",\n";
	out << "    \"native_object_vector_order_materialized\": " << (summary.native_object_vector_order_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_mutation_replay_complete\": " << (summary.generated_cell_mutation_replay_complete ? "true" : "false") << ",\n";
	out << "    \"projection_write_coordinates_materialized\": " << (summary.projection_write_coordinates_materialized ? "true" : "false") << ",\n";
	out << "    \"record_count\": " << summary.record_count << ",\n";
	out << "    \"shifted_count_at_0x4a7d99\": " << summary.shifted_count_at_0x4a7d99 << ",\n";
	out << "    \"vector_entry_count\": " << summary.vector_entry_count << ",\n";
	out << "    \"record_vtable_counts\": {\n";
	out << "      \"0x00540a9c\": " << summary.record_vtable_0x00540a9c_count << ",\n";
	out << "      \"0x00540a88\": " << summary.record_vtable_0x00540a88_count << "\n";
	out << "    },\n";
	out << "    \"vector_entries\": ";
	append_string_array_json(out, summary.vector_entries);
	out << ",\n";
	out << "    \"records\": ";
	append_object_vector_payload_order_records_json(out, summary.records);
	out << ",\n";
	out << "    \"adoption_blocker\": \"native_live_object_vector_records_plus_0x4a696b_0x4a7605_generated_cell_mutation_replay\"\n";
	out << "  }";
}

void append_object_vector_endpoint_dispatch_summary_json(std::ostream &out, const ObjectVectorEndpointDispatchSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_4a79a3_endpoint_dispatch_exclusion_v1\",\n";
	out << "    \"phase_id\": \"object_vector_endpoint_dispatch_0x4a79a3_0x4a696b_0x4a7605\",\n";
	out << "    \"h3maped_anchor\": \"0x4a79a3_0x4a696b_0x4a7605_0x4a7312_0x4a746b_0x4a5e03\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ diagnostic import from 4a79a3_filter_dispatch_summary.json, 696b_7605_static_surface_summary.json, 4a696b_target_mode_reachability_summary_20260610.json, medium_4a696b_grid_scan_aggregate_summary_20260610.json, and 4a696b_cell_mutation_trace_summary_20260608.json\",\n";
	out << "    \"strict_port_scope\": \"endpoint-dispatch exclusion/delegation contract only; no native live grid mutation, no direct 0x4a696b adoption, no delegated 0x4a7605 after-state adoption, and no package output\",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"native_behavior_changed\": " << (summary.native_behavior_changed ? "true" : "false") << ",\n";
	out << "    \"endpoint_dispatch_contract_ported_plain_cpp\": " << (summary.endpoint_dispatch_contract_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"filter_dispatch_summary_recovered\": " << (summary.filter_dispatch_summary_recovered ? "true" : "false") << ",\n";
	out << "    \"static_4a696b_direct_mutation_surface_recovered\": " << (summary.static_4a696b_direct_mutation_surface_recovered ? "true" : "false") << ",\n";
	out << "    \"static_4a7605_fallback_coordinator_surface_recovered\": " << (summary.static_4a7605_fallback_coordinator_surface_recovered ? "true" : "false") << ",\n";
	out << "    \"target_mode_4a696b_direct_mutation_excluded_supported_land\": " << (summary.target_mode_4a696b_direct_mutation_excluded_supported_land ? "true" : "false") << ",\n";
	out << "    \"multi_seed_4a696b_pair_gate_recovered\": " << (summary.multi_seed_4a696b_pair_gate_recovered ? "true" : "false") << ",\n";
	out << "    \"live_4a696b_direct_mutation_sites_not_hit\": " << (summary.live_4a696b_direct_mutation_sites_not_hit ? "true" : "false") << ",\n";
	out << "    \"hit_4a696b_from_4a79a3\": " << (summary.hit_4a696b_from_4a79a3 ? "true" : "false") << ",\n";
	out << "    \"hit_4a7605_from_4a79a3\": " << (summary.hit_4a7605_from_4a79a3 ? "true" : "false") << ",\n";
	out << "    \"hit_pair_mark_sites\": " << (summary.hit_pair_mark_sites ? "true" : "false") << ",\n";
	out << "    \"direct_4a696b_mutation_adopted\": " << (summary.direct_4a696b_mutation_adopted ? "true" : "false") << ",\n";
	out << "    \"delegated_4a7605_afterstate_materialized\": " << (summary.delegated_4a7605_afterstate_materialized ? "true" : "false") << ",\n";
	out << "    \"generated_cell_mutation_replay_complete\": " << (summary.generated_cell_mutation_replay_complete ? "true" : "false") << ",\n";
	out << "    \"dispatch_4a696b_from_4a79a3_count\": " << summary.dispatch_4a696b_from_4a79a3_count << ",\n";
	out << "    \"dispatch_4a7605_from_4a79a3_count\": " << summary.dispatch_4a7605_from_4a79a3_count << ",\n";
	out << "    \"source_4a696b_combined_entries\": " << summary.source_4a696b_combined_entries << ",\n";
	out << "    \"source_4a696b_source_relation_match_hits\": " << summary.source_4a696b_source_relation_match_hits << ",\n";
	out << "    \"source_4a696b_candidate_append_hits\": " << summary.source_4a696b_candidate_append_hits << ",\n";
	out << "    \"source_4a696b_direct_mutation_hits\": " << summary.source_4a696b_direct_mutation_hits << ",\n";
	out << "    \"source_4a696b_complete_grid_scan_count\": " << summary.source_4a696b_complete_grid_scan_count << ",\n";
	out << "    \"source_4a696b_zero_owner_relation_pair_match_scan_count\": " << summary.source_4a696b_zero_owner_relation_pair_match_scan_count << ",\n";
	out << "    \"source_4a696b_scanned_cell_total\": " << summary.source_4a696b_scanned_cell_total << ",\n";
	out << "    \"source_4a696b_seed_count\": " << summary.source_4a696b_seed_count << ",\n";
	out << "    \"source_4a696b_byte2_only_or_any_match_total\": " << summary.source_4a696b_byte2_only_or_any_match_total << ",\n";
	out << "    \"source_4a696b_byte3_only_or_any_match_total\": " << summary.source_4a696b_byte3_only_or_any_match_total << ",\n";
	out << "    \"trace_4a696b_entry_count\": " << summary.trace_4a696b_entry_count << ",\n";
	out << "    \"trace_4a7605_entry_count\": " << summary.trace_4a7605_entry_count << ",\n";
	out << "    \"trace_4a7312_call_count\": " << summary.trace_4a7312_call_count << ",\n";
	out << "    \"trace_4a7312_vtable_commit_count\": " << summary.trace_4a7312_vtable_commit_count << ",\n";
	out << "    \"trace_4a696b_direct_mutation_site_hit_count\": " << summary.trace_4a696b_direct_mutation_site_hit_count << ",\n";
	out << "    \"static_4a7605_endpoint_policy_4a7312_count\": " << summary.static_4a7605_endpoint_policy_4a7312_count << ",\n";
	out << "    \"static_4a7605_endpoint_writer_4a746b_count\": " << summary.static_4a7605_endpoint_writer_4a746b_count << ",\n";
	out << "    \"static_4a7605_materializer_4a5e03_count\": " << summary.static_4a7605_materializer_4a5e03_count << ",\n";
	out << "    \"static_4a7605_record_initializer_49ba89_count\": " << summary.static_4a7605_record_initializer_49ba89_count << ",\n";
	out << "    \"static_4a7605_coordinate_append_40bb15_count\": " << summary.static_4a7605_coordinate_append_40bb15_count << ",\n";
	out << "    \"static_4a7605_coordinate_merge_40bb26_count\": " << summary.static_4a7605_coordinate_merge_40bb26_count << ",\n";
	out << "    \"static_4a7605_direct_generated_cell_28_write_count\": " << summary.static_4a7605_direct_generated_cell_28_write_count << ",\n";
	out << "    \"adoption_blocker\": \"delegated_0x4a7605_afterstate_plus_native_live_object_vector_records_before_generated_cell_mutation_replay\"\n";
	out << "  }";
}

void append_object_vector_commit_mutation_summary_json(std::ostream &out, const ObjectVectorCommitMutationSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_object_vector_commit_mutation_summary_v1\",\n";
	out << "    \"phase_id\": \"object_vector_generated_cell_mutation_helpers\",\n";
	out << "    \"h3maped_anchor\": \"0x49cf34_0x4a54a7_0x4a61bc_0x4a7605_0x4aa3e9_0x4aa44d\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ replay of recovered 0x49cf34 generated-cell attach write pairs from 49cf34_cell_mutation_replay_summary_20260610.json, recovered 0x4a54a7 target-cell mutation samples from medium_seed10_4a54a7_afterstate_summary_20260608.json and 4a61bc_4a54a7_dynamic_aggregate_summary_20260609.json, plus the full 90-write 0x4aa3e9 -> 0x4aa44d -> 0x4a54a7 projection stream from 4aa3e9_4a54a7_dynamic_trace_20260610/winedbg_4aa3e9_4a54a7_dynamic_trace_ledger.json\",\n";
	out << "    \"strict_port_scope\": \"mutation helper and recovered projection-write stream replay only; no live generated-cell adoption, no object-vector adoption, no package objects, roads, guards, blockers, or public output\",\n";
	out << "    \"terrain_live_feedback_available\": " << (summary.terrain_live_feedback_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"commit_mutation_helpers_ported_plain_cpp\": " << (summary.commit_mutation_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"projection_write_helpers_ported_plain_cpp\": " << (summary.projection_write_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"attach_mutation_helpers_ported_plain_cpp\": " << (summary.attach_mutation_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"live_grid_mutation_adopted\": " << (summary.live_grid_mutation_adopted ? "true" : "false") << ",\n";
	out << "    \"recovered_samples_match\": " << (summary.recovered_samples_match ? "true" : "false") << ",\n";
	out << "    \"projection_write_recovered_samples_match\": " << (summary.projection_write_recovered_samples_match ? "true" : "false") << ",\n";
	out << "    \"attach_mutation_recovered_samples_match\": " << (summary.attach_mutation_recovered_samples_match ? "true" : "false") << ",\n";
	out << "    \"projection_write_full_stream_materialized_plain_cpp\": " << (summary.projection_write_full_stream_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"projection_write_unique_cell_count_matches_recovered\": " << (summary.projection_write_unique_cell_count_matches_recovered ? "true" : "false") << ",\n";
	out << "    \"projection_write_ordinals_cover_recovered_stream\": " << (summary.projection_write_ordinals_cover_recovered_stream ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"seed\": " << summary.seed << ",\n";
	out << "    \"sample_count\": " << summary.sample_count << ",\n";
	out << "    \"matched_sample_count\": " << summary.matched_sample_count << ",\n";
	out << "    \"endpoint_clear_sample_count\": " << summary.endpoint_clear_sample_count << ",\n";
	out << "    \"reward_lower_sample_count\": " << summary.reward_lower_sample_count << ",\n";
	out << "    \"sampled_4aa3e9_projection_write_count\": " << summary.sampled_4aa3e9_projection_write_count << ",\n";
	out << "    \"sampled_4aa3e9_projection_write_unique_cell_count\": " << summary.sampled_4aa3e9_projection_write_unique_cell_count << ",\n";
	out << "    \"projection_write_sample_count\": " << summary.projection_write_sample_count << ",\n";
	out << "    \"projection_write_matched_sample_count\": " << summary.projection_write_matched_sample_count << ",\n";
	out << "    \"projection_write_unique_cell_count\": " << summary.projection_write_unique_cell_count << ",\n";
	out << "    \"projection_write_ordinal_min\": " << summary.projection_write_ordinal_min << ",\n";
	out << "    \"projection_write_ordinal_max\": " << summary.projection_write_ordinal_max << ",\n";
	out << "    \"sampled_4a61bc_min_projection_write_count\": " << summary.sampled_4a61bc_min_projection_write_count << ",\n";
	out << "    \"sampled_4a61bc_max_projection_write_count\": " << summary.sampled_4a61bc_max_projection_write_count << ",\n";
	out << "    \"sampled_49cf34_attach_write_pair_count\": " << summary.sampled_49cf34_attach_write_pair_count << ",\n";
	out << "    \"attach_write_pair_count\": " << summary.attach_write_pair_count << ",\n";
	out << "    \"attach_matched_write_pair_count\": " << summary.attach_matched_write_pair_count << ",\n";
	out << "    \"attach_primary_write_pair_count\": " << summary.attach_primary_write_pair_count << ",\n";
	out << "    \"attach_neighbor_write_pair_count\": " << summary.attach_neighbor_write_pair_count << ",\n";
	out << "    \"attach_unique_cell_count\": " << summary.attach_unique_cell_count << ",\n";
	out << "    \"attach_changed_write_pair_count\": " << summary.attach_changed_write_pair_count << ",\n";
	out << "    \"attach_clears_bit26_count\": " << summary.attach_clears_bit26_count << ",\n";
	out << "    \"attach_sets_bit27_from_clear_count\": " << summary.attach_sets_bit27_from_clear_count << ",\n";
	out << "    \"samples\": ";
	append_object_vector_commit_mutation_samples_json(out, summary.samples);
	out << ",\n";
	out << "    \"projection_write_samples\": ";
	append_object_vector_projection_write_samples_json(out, summary.projection_write_samples);
	out << ",\n";
	out << "    \"attach_mutation_samples\": ";
	append_object_vector_attach_mutation_samples_json(out, summary.attach_mutation_samples);
	out << ",\n";
	out << "    \"adoption_blocker\": \"ordered_native_object_vector_records_and_projection_write_coordinates_before_live_generated_cell_mutation\"\n";
	out << "  }";
}

void append_object_vector_prerequisite_contract_summary_json(std::ostream &out, const ObjectVectorPrerequisiteContractSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_object_vector_prerequisite_contract_v1\",\n";
	out << "    \"phase_id\": \"object_vector_prerequisite_contract\",\n";
	out << "    \"h3maped_anchor\": \"0x4aa354_0x49cf34_0x4aa9b7_0x4aa3e9_0x4a79a3\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ contract from .artifacts/rmg_recovery/reward_guard_source_stream_coverage_summary_current.json, object_vector_surface_summary.json, 4a79a3_object_vector_trace_summary.json, 4a79a3_internal_growth_summary_20260609.json, 4a79a3_payload_trace_summary.json, and 4a79a3_filter_dispatch_summary.json\",\n";
	out << "    \"strict_port_scope\": \"object-vector prerequisite contract only; no live generated-cell adoption, package objects, roads, guards, blockers, or public output\",\n";
	out << "    \"generated_cell_bit_helpers_available\": " << (summary.generated_cell_bit_helpers_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"object_vector_contract_ported_plain_cpp\": " << (summary.object_vector_contract_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"descriptor_source_identity_closure_ported_plain_cpp\": " << (summary.descriptor_source_identity_closure_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"descriptor_source_identity_r4_crosswalk_recovered\": " << (summary.descriptor_source_identity_r4_crosswalk_recovered ? "true" : "false") << ",\n";
	out << "    \"descriptor_source_identity_native_behavior_changed\": " << (summary.descriptor_source_identity_native_behavior_changed ? "true" : "false") << ",\n";
	out << "    \"descriptor_plus_0x00_registry_key_not_row_recovered\": " << (summary.descriptor_plus_0x00_registry_key_not_row_recovered ? "true" : "false") << ",\n";
	out << "    \"descriptor_copied_source_record_identity_authority_recovered\": " << (summary.descriptor_copied_source_record_identity_authority_recovered ? "true" : "false") << ",\n";
	out << "    \"object_vector_commit_mutation_helpers_ported_plain_cpp\": " << (summary.object_vector_commit_mutation_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"object_vector_projection_write_helpers_ported_plain_cpp\": " << (summary.object_vector_projection_write_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"object_vector_49cf34_attach_mutation_helpers_ported_plain_cpp\": " << (summary.object_vector_49cf34_attach_mutation_helpers_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"object_vector_4a79a3_payload_order_ported_plain_cpp\": " << (summary.object_vector_4a79a3_payload_order_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"object_vector_4a79a3_payload_order_records_match_recovered\": " << (summary.object_vector_4a79a3_payload_order_records_match_recovered ? "true" : "false") << ",\n";
	out << "    \"object_vector_endpoint_dispatch_exclusion_ported_plain_cpp\": " << (summary.object_vector_endpoint_dispatch_exclusion_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"endpoint_dispatch_4a696b_direct_mutation_excluded_supported_land\": " << (summary.endpoint_dispatch_4a696b_direct_mutation_excluded_supported_land ? "true" : "false") << ",\n";
	out << "    \"endpoint_dispatch_4a7605_delegated_materialization_afterstate_pending\": " << (summary.endpoint_dispatch_4a7605_delegated_materialization_afterstate_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_contract_ported_plain_cpp\": " << (summary.relation_normalization_contract_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_4a59e2_pack_materialized_plain_cpp\": " << (summary.relation_normalization_4a59e2_pack_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_full_grid_reset_materialized_plain_cpp\": " << (summary.relation_normalization_full_grid_reset_materialized_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_source_cell_clear_0x49a318_primitive_materialized\": " << (summary.relation_normalization_source_cell_clear_0x49a318_primitive_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_source_cell_projection_triple_minus_one_primitive_materialized\": " << (summary.relation_normalization_source_cell_projection_triple_minus_one_primitive_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_source_cell_clear_live_application_pending\": " << (summary.relation_normalization_source_cell_clear_live_application_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_projection_gate_reset_materialized\": " << (summary.relation_normalization_projection_gate_reset_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_projection_triple_reset_materialized\": " << (summary.relation_normalization_projection_triple_reset_materialized ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_runtime_replay_pending\": " << (summary.relation_normalization_runtime_replay_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_word20_low_word_propagation_pending\": " << (summary.relation_normalization_word20_low_word_propagation_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_projection_gate_pending\": " << (summary.relation_normalization_projection_gate_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_projection_triple_pending\": " << (summary.relation_normalization_projection_triple_pending ? "true" : "false") << ",\n";
	out << "    \"relation_normalization_object_reference_filter_pending\": " << (summary.relation_normalization_object_reference_filter_pending ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"native_object_vector_order_materialized\": " << (summary.native_object_vector_order_materialized ? "true" : "false") << ",\n";
	out << "    \"same_run_descriptor_state_complete\": " << (summary.same_run_descriptor_state_complete ? "true" : "false") << ",\n";
	out << "    \"generated_cell_mutation_replay_complete\": " << (summary.generated_cell_mutation_replay_complete ? "true" : "false") << ",\n";
	out << "    \"projection_write_coordinates_materialized\": " << (summary.projection_write_coordinates_materialized ? "true" : "false") << ",\n";
	out << "    \"sampled_4a54a7_commit_mutation_samples_match\": " << (summary.sampled_4a54a7_commit_mutation_samples_match ? "true" : "false") << ",\n";
	out << "    \"sampled_4a56b6_projection_write_samples_match\": " << (summary.sampled_4a56b6_projection_write_samples_match ? "true" : "false") << ",\n";
	out << "    \"sampled_49cf34_attach_mutation_samples_match\": " << (summary.sampled_49cf34_attach_mutation_samples_match ? "true" : "false") << ",\n";
	out << "    \"sampled_4a56b6_projection_write_full_stream_materialized\": " << (summary.sampled_4a56b6_projection_write_full_stream_materialized ? "true" : "false") << ",\n";
	out << "    \"sampled_4a56b6_projection_write_unique_cell_count_matches\": " << (summary.sampled_4a56b6_projection_write_unique_cell_count_matches ? "true" : "false") << ",\n";
	out << "    \"sampled_4a56b6_projection_write_ordinals_cover_stream\": " << (summary.sampled_4a56b6_projection_write_ordinals_cover_stream ? "true" : "false") << ",\n";
	out << "    \"recovered_reference_case_matches\": " << (summary.recovered_reference_case_matches ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"seed\": " << summary.seed << ",\n";
	out << "    \"expected_reference_seed\": " << summary.expected_reference_seed << ",\n";
	out << "    \"expected_reference_width\": " << summary.expected_reference_width << ",\n";
	out << "    \"expected_reference_height\": " << summary.expected_reference_height << ",\n";
	out << "    \"seed58_4aa354_call_count\": " << summary.seed58_4aa354_call_count << ",\n";
	out << "    \"seed58_4aa354_49cf34_call_count\": " << summary.seed58_4aa354_49cf34_call_count << ",\n";
	out << "    \"seed58_4aa354_4aa9b7_call_count\": " << summary.seed58_4aa354_4aa9b7_call_count << ",\n";
	out << "    \"seed58_4aa354_4aa3e9_call_count\": " << summary.seed58_4aa354_4aa3e9_call_count << ",\n";
	out << "    \"seed58_source_stream_has_4aa354_to_49cf34_attach_order\": " << (summary.seed58_source_stream_has_4aa354_to_49cf34_attach_order ? "true" : "false") << ",\n";
	out << "    \"seed58_source_stream_has_4aa9b7_to_4aa3e9_handoff\": " << (summary.seed58_source_stream_has_4aa9b7_to_4aa3e9_handoff ? "true" : "false") << ",\n";
	out << "    \"seed58_source_stream_dumps_generator_descriptor_vector_0x398_0x39c\": " << (summary.seed58_source_stream_dumps_generator_descriptor_vector_0x398_0x39c ? "true" : "false") << ",\n";
	out << "    \"seed58_source_stream_dumps_selected_descriptor_state_0x94_0x95\": " << (summary.seed58_source_stream_dumps_selected_descriptor_state_0x94_0x95 ? "true" : "false") << ",\n";
	out << "    \"object_vector_static_contract_recovered\": " << (summary.object_vector_static_contract_recovered ? "true" : "false") << ",\n";
	out << "    \"object_vector_producer_surface_recovered\": " << (summary.object_vector_producer_surface_recovered ? "true" : "false") << ",\n";
	out << "    \"object_vector_cleanup_surfaces_recovered\": " << (summary.object_vector_cleanup_surfaces_recovered ? "true" : "false") << ",\n";
	out << "    \"object_vector_phase_consumer_surface_recovered\": " << (summary.object_vector_phase_consumer_surface_recovered ? "true" : "false") << ",\n";
	out << "    \"sampled_4a54a7_commit_mutation_sample_count\": " << summary.sampled_4a54a7_commit_mutation_sample_count << ",\n";
	out << "    \"sampled_4a54a7_endpoint_clear_sample_count\": " << summary.sampled_4a54a7_endpoint_clear_sample_count << ",\n";
	out << "    \"sampled_4aa3e9_reward_lower_sample_count\": " << summary.sampled_4aa3e9_reward_lower_sample_count << ",\n";
	out << "    \"sampled_4aa3e9_projection_write_count\": " << summary.sampled_4aa3e9_projection_write_count << ",\n";
	out << "    \"sampled_4aa3e9_projection_write_unique_cell_count\": " << summary.sampled_4aa3e9_projection_write_unique_cell_count << ",\n";
	out << "    \"sampled_4a56b6_projection_write_sample_count\": " << summary.sampled_4a56b6_projection_write_sample_count << ",\n";
	out << "    \"sampled_4a56b6_projection_write_matched_sample_count\": " << summary.sampled_4a56b6_projection_write_matched_sample_count << ",\n";
	out << "    \"sampled_4a56b6_projection_write_unique_cell_count\": " << summary.sampled_4a56b6_projection_write_unique_cell_count << ",\n";
	out << "    \"sampled_4a56b6_projection_write_ordinal_min\": " << summary.sampled_4a56b6_projection_write_ordinal_min << ",\n";
	out << "    \"sampled_4a56b6_projection_write_ordinal_max\": " << summary.sampled_4a56b6_projection_write_ordinal_max << ",\n";
	out << "    \"sampled_49cf34_attach_write_pair_count\": " << summary.sampled_49cf34_attach_write_pair_count << ",\n";
	out << "    \"sampled_49cf34_attach_matched_write_pair_count\": " << summary.sampled_49cf34_attach_matched_write_pair_count << ",\n";
	out << "    \"sampled_49cf34_attach_primary_write_pair_count\": " << summary.sampled_49cf34_attach_primary_write_pair_count << ",\n";
	out << "    \"sampled_49cf34_attach_neighbor_write_pair_count\": " << summary.sampled_49cf34_attach_neighbor_write_pair_count << ",\n";
	out << "    \"sampled_49cf34_attach_unique_cell_count\": " << summary.sampled_49cf34_attach_unique_cell_count << ",\n";
	out << "    \"sampled_49cf34_attach_changed_write_pair_count\": " << summary.sampled_49cf34_attach_changed_write_pair_count << ",\n";
	out << "    \"sampled_49cf34_attach_clears_bit26_count\": " << summary.sampled_49cf34_attach_clears_bit26_count << ",\n";
	out << "    \"sampled_49cf34_attach_sets_bit27_from_clear_count\": " << summary.sampled_49cf34_attach_sets_bit27_from_clear_count << ",\n";
	out << "    \"sampled_4a79a3_initial_object_vector_count\": " << summary.sampled_4a79a3_initial_object_vector_count << ",\n";
	out << "    \"sampled_4a79a3_positive_append_count\": " << summary.sampled_4a79a3_positive_append_count << ",\n";
	out << "    \"sampled_4a79a3_final_object_vector_count\": " << summary.sampled_4a79a3_final_object_vector_count << ",\n";
	out << "    \"sampled_4a79a3_payload_loop_count\": " << summary.sampled_4a79a3_payload_loop_count << ",\n";
	out << "    \"sampled_4a79a3_later_49eb8d_handoff_count\": " << summary.sampled_4a79a3_later_49eb8d_handoff_count << ",\n";
	out << "    \"sampled_4a79a3_payload_record_count\": " << summary.sampled_4a79a3_payload_record_count << ",\n";
	out << "    \"sampled_4a79a3_payload_vtable_0x00540a9c_count\": " << summary.sampled_4a79a3_payload_vtable_0x00540a9c_count << ",\n";
	out << "    \"sampled_4a79a3_payload_vtable_0x00540a88_count\": " << summary.sampled_4a79a3_payload_vtable_0x00540a88_count << ",\n";
	out << "    \"sampled_4a79a3_filter_hits_4a696b\": " << (summary.sampled_4a79a3_filter_hits_4a696b ? "true" : "false") << ",\n";
	out << "    \"sampled_4a79a3_filter_hits_4a7605\": " << (summary.sampled_4a79a3_filter_hits_4a7605 ? "true" : "false") << ",\n";
	out << "    \"sampled_endpoint_dispatch_4a696b_entry_count\": " << summary.sampled_endpoint_dispatch_4a696b_entry_count << ",\n";
	out << "    \"sampled_endpoint_dispatch_4a7605_entry_count\": " << summary.sampled_endpoint_dispatch_4a7605_entry_count << ",\n";
	out << "    \"sampled_endpoint_dispatch_4a696b_source_relation_match_hits\": " << summary.sampled_endpoint_dispatch_4a696b_source_relation_match_hits << ",\n";
	out << "    \"sampled_endpoint_dispatch_4a696b_direct_mutation_hits\": " << summary.sampled_endpoint_dispatch_4a696b_direct_mutation_hits << ",\n";
	out << "    \"sampled_endpoint_dispatch_4a7605_endpoint_policy_count\": " << summary.sampled_endpoint_dispatch_4a7605_endpoint_policy_count << ",\n";
	out << "    \"adoption_blocker\": \"same_run_4aa354_descriptor_state_plus_4a79a3_generated_cell_mutation_replay_before_0x4a8260\"\n";
	out << "  }";
}

void append_route_boundary_contract_summary_json(std::ostream &out, const RouteBoundaryContractSummaryPlain &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_0x4a8260_route_boundary_contract_v1\",\n";
	out << "    \"phase_id\": \"route_boundary_contract_0x4a8260\",\n";
	out << "    \"h3maped_anchor\": \"0x4a8260_0x4a858f_0x4a80dc_0x49a85d_0x49a962\",\n";
	out << "    \"status\": \"" << json_escape(summary.status) << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"plain-C++ import of recovered seed-58 0x4a8260 route replay/RNG boundary contract from .artifacts/rmg_recovery/seed58_4a8260_route_replay_verify_20260611.json\",\n";
	out << "    \"strict_port_scope\": \"route mechanics contract and adoption precondition only; no live route mutation, no object-vector adoption, no package objects, roads, guards, blockers, or public output\",\n";
	out << "    \"generated_cell_bit_helpers_available\": " << (summary.generated_cell_bit_helpers_available ? "true" : "false") << ",\n";
	out << "    \"supported_one_level_land_scope\": " << (summary.supported_scope ? "true" : "false") << ",\n";
	out << "    \"object_vector_prerequisite_available\": " << (summary.object_vector_prerequisite_available ? "true" : "false") << ",\n";
	out << "    \"route_contract_ported_plain_cpp\": " << (summary.route_contract_ported_plain_cpp ? "true" : "false") << ",\n";
	out << "    \"diagnostic_only\": " << (summary.diagnostic_only ? "true" : "false") << ",\n";
	out << "    \"live_grid_mutation_adopted\": " << (summary.live_grid_mutation_adopted ? "true" : "false") << ",\n";
	out << "    \"native_object_vector_order_materialized\": " << (summary.native_object_vector_order_materialized ? "true" : "false") << ",\n";
	out << "    \"same_run_descriptor_state_complete\": " << (summary.same_run_descriptor_state_complete ? "true" : "false") << ",\n";
	out << "    \"generated_cell_mutation_replay_complete\": " << (summary.generated_cell_mutation_replay_complete ? "true" : "false") << ",\n";
	out << "    \"projection_write_coordinates_materialized\": " << (summary.projection_write_coordinates_materialized ? "true" : "false") << ",\n";
	out << "    \"native_route_rng_boundary_materialized\": " << (summary.native_route_rng_boundary_materialized ? "true" : "false") << ",\n";
	out << "    \"recovered_reference_case_matches\": " << (summary.recovered_reference_case_matches ? "true" : "false") << ",\n";
	out << "    \"map_width\": " << summary.width << ",\n";
	out << "    \"map_height\": " << summary.height << ",\n";
	out << "    \"level_count\": " << summary.level_count << ",\n";
	out << "    \"seed\": " << summary.seed << ",\n";
	out << "    \"expected_reference_seed\": " << summary.expected_reference_seed << ",\n";
	out << "    \"expected_reference_width\": " << summary.expected_reference_width << ",\n";
	out << "    \"expected_reference_height\": " << summary.expected_reference_height << ",\n";
	out << "    \"h3maped_route_entry_state_uint32\": " << summary.h3maped_route_entry_state_uint32 << ",\n";
	out << "    \"h3maped_route_entry_offset_from_seed\": " << summary.h3maped_route_entry_offset_from_seed << ",\n";
	out << "    \"route_container_0x4a8260_route_event_count\": " << summary.recovered_route_event_count << ",\n";
	out << "    \"route_container_0x4a8260_split_count\": " << summary.recovered_split_count << ",\n";
	out << "    \"route_container_0x4a8260_stamp_call_count\": " << summary.recovered_stamp_count << ",\n";
	out << "    \"route_container_0x4a8260_a80dc_call_count\": " << summary.recovered_a80dc_call_count << ",\n";
	out << "    \"route_container_0x4a8260_far_cut_count\": " << summary.recovered_far_cut_count << ",\n";
	out << "    \"route_container_0x4a8260_silent_oob_terminal_count\": " << summary.recovered_silent_oob_terminal_count << ",\n";
	out << "    \"route_container_0x4a8260_rng_call_count\": " << summary.rng_call_count << ",\n";
	out << "    \"route_container_0x4a8260_rng_unique_remainder_count\": " << summary.rng_unique_remainder_count << ",\n";
	out << "    \"route_container_0x4a8260_rng_ambiguous_remainder_count\": " << summary.rng_ambiguous_remainder_count << ",\n";
	out << "    \"route_container_0x4a8260_no_rng_split_count\": " << summary.rng_no_rng_split_count << ",\n";
	out << "    \"route_container_0x4a8260_route_list_replay_status\": \"diagnostic_reference_contract_imported_not_live_replay\",\n";
	out << "    \"route_container_0x4a8260_rng_boundary_exact\": false,\n";
	out << "    \"route_container_0x4a8260_active_adoption\": false,\n";
	out << "    \"route_container_0x4a8260_pre_scan_bit26_count\": " << summary.source_bit26_count << ",\n";
	out << "    \"route_container_0x4a8260_pre_scan_bit27_count\": " << summary.source_bit27_count << ",\n";
	out << "    \"route_container_0x4a8260_post_scan_bit26_count\": " << summary.diagnostic_final_bit26_count << ",\n";
	out << "    \"route_container_0x4a8260_post_scan_bit27_count\": " << summary.diagnostic_final_bit27_count << ",\n";
	out << "    \"adoption_blocker\": \"materialize_native_generator_object_vector_order_plus_route_rng_boundary_before_0x4a8260_live_grid_mutation\"\n";
	out << "  }";
}

void append_terrain_live_feedback_generated_cell_checkpoint_json(std::ostream &out, const TerrainLiveFeedbackSummaryPlain &summary) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int64_t cell_count = int64_t(summary.cell_count);
	const bool supported = summary.materializes_private_generated_cell_words
			&& summary.width > 0
			&& summary.height > 0
			&& summary.level_count > 0
			&& cell_count >= 0
			&& summary.generated_cell_word_0x20.size() == size_t(cell_count)
			&& summary.generated_cell_word_0x24.size() == size_t(cell_count)
			&& summary.generated_cell_word_0x28.size() == size_t(cell_count)
			&& summary.generated_cell_word_0x2c.size() == size_t(cell_count)
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
	int32_t word_0x2c_bit0_count = 0;
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			const uint32_t word_0x20 = summary.generated_cell_word_0x20[size_t(flat)];
			const uint32_t word_0x24 = summary.generated_cell_word_0x24[size_t(flat)];
			const uint32_t word_0x28 = summary.generated_cell_word_0x28[size_t(flat)];
			const uint32_t word_0x2c = summary.generated_cell_word_0x2c[size_t(flat)];
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
			word_0x2c_bit0_count += (word_0x2c & 1U) != 0U ? 1 : 0;
		}
	}

	out << "{\n";
	out << "    \"schema_id\": \"h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1\",\n";
	out << "    \"checkpoint_id\": \"after_terrain_live_feedback\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x49acf6_after_0x4bc5f0_before_0x4a4c8e\",\n";
	out << "    \"plain_cpp_stage\": \"after_terrain_live_feedback_word_0x24_0x28_mutations_before_tile_byte_writeback_and_object_consumers\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? summary.width : 0) << ",\n";
	out << "    \"height\": " << (supported ? summary.height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? summary.level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"owner byte2 inherited from after_terrain_relation_eligibility\",\n";
	out << "    \"word_0x24_source\": \"recovered 0x4bad0f/0x49acf6 terrain id and visual row writes from TerrainPlacement live feedback\",\n";
	out << "    \"word_0x28_source\": \"constructor bit25/bit27 plus 0x4a2ec3 bit28 plus recovered 0x49acf6 terrain flag bits15..16\",\n";
	out << "    \"word_0x2c_source\": \"copied private generated-cell dword index 11; not mutated by this terrain live-feedback slice\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2 after 0x4a325d owner materialization\",\n";
	out << "    \"status\": \"" << (supported ? "available_plain_cpp_terrain_live_feedback" : "blocked_terrain_live_feedback_unavailable") << "\",\n";
	out << "    \"word_0x2c_available\": " << (supported ? "true" : "false") << ",\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"live_roundtrip_mismatch_count\": " << (supported ? summary.live_roundtrip_mismatch_count : 0) << ",\n";
	out << "    \"live_terrain_mismatch_count\": " << (supported ? summary.live_terrain_mismatch_count : 0) << ",\n";
	out << "    \"live_visual_missing_bucket_count\": " << (supported ? summary.live_visual_missing_bucket_count : 0) << ",\n";
	out << "    \"drain_guard_exhausted\": " << (supported && summary.drain_guard_exhausted ? "true" : "false") << ",\n";
	out << "    \"word_0x28_bit22_count\": " << word_0x28_bit22_count << ",\n";
	out << "    \"word_0x28_bit25_count\": " << word_0x28_bit25_count << ",\n";
	out << "    \"word_0x28_bit26_count\": " << word_0x28_bit26_count << ",\n";
	out << "    \"word_0x28_bit27_count\": " << word_0x28_bit27_count << ",\n";
	out << "    \"word_0x28_bit28_count\": " << word_0x28_bit28_count << ",\n";
	out << "    \"word_0x2c_bit0_count\": " << word_0x2c_bit0_count << ",\n";
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
			const uint32_t word_0x2c = summary.generated_cell_word_0x2c[size_t(flat)];
			out << "{";
			out << "\"flat\":" << flat << ",";
			out << "\"x\":" << (remainder % summary.width) << ",";
			out << "\"y\":" << (remainder / summary.width) << ",";
			out << "\"level\":" << level << ",";
			out << "\"word_0x20\":" << word_0x20 << ",";
			out << "\"word_0x24\":" << word_0x24 << ",";
			out << "\"word_0x28\":" << word_0x28 << ",";
			out << "\"word_0x2c\":" << word_0x2c << ",";
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
		controlled_case.setup_object_0x44_supplied = true;
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
	const RuntimeTerrainSelectionSummaryPlain runtime_terrain_selection_summary = build_runtime_terrain_selection_summary(controlled_case, coordinate_replay_summary, source_node_summary);
	const TerrainCellWriteoutSummaryPlain terrain_cell_writeout_summary = build_terrain_cell_writeout_summary(boundary_span_fill_summary, runtime_terrain_selection_summary, source_node_summary);
	const TerrainRelationEligibilitySummaryPlain terrain_relation_eligibility_summary = build_terrain_relation_eligibility_summary(boundary_span_fill_summary, terrain_cell_writeout_summary, source_node_summary);
	const TerrainLiveFeedbackSummaryPlain terrain_live_feedback_summary = build_terrain_live_feedback_summary(terrain_relation_eligibility_summary, runtime_terrain_selection_summary);
	const GeneratedCellBitHelperSummaryPlain generated_cell_bit_helper_summary = build_generated_cell_bit_helper_summary(terrain_live_feedback_summary);
	const RelationNormalizationContractSummaryPlain relation_normalization_contract_summary = build_relation_normalization_contract_summary(controlled_case, runtime_zone_summary, coordinate_replay_summary, terrain_live_feedback_summary, generated_cell_bit_helper_summary);
	const ObjectVectorCommitMutationSummaryPlain object_vector_commit_mutation_summary = build_object_vector_commit_mutation_summary(controlled_case, terrain_live_feedback_summary);
	const DescriptorSourceIdentityClosureSummaryPlain descriptor_source_identity_closure_summary = build_descriptor_source_identity_closure_summary(controlled_case);
	const ObjectVectorPayloadOrderSummaryPlain object_vector_payload_order_summary = build_object_vector_payload_order_summary(controlled_case);
	const ObjectVectorEndpointDispatchSummaryPlain object_vector_endpoint_dispatch_summary = build_object_vector_endpoint_dispatch_summary(controlled_case);
	const ObjectVectorPrerequisiteContractSummaryPlain object_vector_prerequisite_contract_summary = build_object_vector_prerequisite_contract_summary(controlled_case, generated_cell_bit_helper_summary, relation_normalization_contract_summary, object_vector_commit_mutation_summary, object_vector_payload_order_summary, object_vector_endpoint_dispatch_summary);
	const RouteBoundaryContractSummaryPlain route_boundary_contract_summary = build_route_boundary_contract_summary(controlled_case, generated_cell_bit_helper_summary, object_vector_prerequisite_contract_summary);
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
	out << "  \"rmg_setup_object_0x44_supplied_by_controlled_case\": " << (generator_mode.setup_object_0x44_supplied ? "true" : "false") << ",\n";
	out << "  \"rmg_setup_object_0x44_defaulted_from_0x4adf88_initializer\": " << (generator_mode.setup_object_0x44_defaulted_from_initializer ? "true" : "false") << ",\n";
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
	out << "  \"private_state_checkpoint_after_runtime_terrain_cell_writeout\": ";
	append_terrain_cell_writeout_generated_cell_checkpoint_json(out, terrain_cell_writeout_summary);
	out << ",\n";
	out << "  \"private_state_checkpoint_after_terrain_relation_eligibility\": ";
	append_terrain_relation_eligibility_generated_cell_checkpoint_json(out, terrain_relation_eligibility_summary);
	out << ",\n";
	out << "  \"private_state_checkpoint_after_terrain_live_feedback\": ";
	append_terrain_live_feedback_generated_cell_checkpoint_json(out, terrain_live_feedback_summary);
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
	out << "  \"plain_cpp_runtime_terrain_selection_summary\": ";
	append_runtime_terrain_selection_summary_json(out, runtime_terrain_selection_summary);
	out << ",\n";
	out << "  \"plain_cpp_terrain_cell_writeout_summary\": ";
	append_terrain_cell_writeout_summary_json(out, terrain_cell_writeout_summary);
	out << ",\n";
	out << "  \"plain_cpp_terrain_relation_eligibility_summary\": ";
	append_terrain_relation_eligibility_summary_json(out, terrain_relation_eligibility_summary);
	out << ",\n";
	out << "  \"plain_cpp_terrain_live_feedback_summary\": ";
	append_terrain_live_feedback_summary_json(out, terrain_live_feedback_summary);
	out << ",\n";
	out << "  \"plain_cpp_generated_cell_bit_helper_summary\": ";
	append_generated_cell_bit_helper_summary_json(out, generated_cell_bit_helper_summary);
	out << ",\n";
	out << "  \"plain_cpp_relation_normalization_contract_summary\": ";
	append_relation_normalization_contract_summary_json(out, relation_normalization_contract_summary);
	out << ",\n";
	out << "  \"plain_cpp_object_vector_commit_mutation_summary\": ";
	append_object_vector_commit_mutation_summary_json(out, object_vector_commit_mutation_summary);
	out << ",\n";
	out << "  \"plain_cpp_descriptor_source_identity_closure_summary\": ";
	append_descriptor_source_identity_closure_summary_json(out, descriptor_source_identity_closure_summary);
	out << ",\n";
	out << "  \"plain_cpp_object_vector_payload_order_summary\": ";
	append_object_vector_payload_order_summary_json(out, object_vector_payload_order_summary);
	out << ",\n";
	out << "  \"plain_cpp_object_vector_endpoint_dispatch_summary\": ";
	append_object_vector_endpoint_dispatch_summary_json(out, object_vector_endpoint_dispatch_summary);
	out << ",\n";
	out << "  \"plain_cpp_object_vector_prerequisite_contract_summary\": ";
	append_object_vector_prerequisite_contract_summary_json(out, object_vector_prerequisite_contract_summary);
	out << ",\n";
	out << "  \"plain_cpp_0x4a8260_route_boundary_contract_summary\": ";
	append_route_boundary_contract_summary_json(out, route_boundary_contract_summary);
	out << ",\n";
	out << "  \"next_required_native_core_slice\": \"resolve_matched_owner_placement_drift_then_port_remaining_word_0x20_0x24_0x28_mutations\",\n";
	out << "  \"next_required_alignment_slice\": \"compare_matched_h3maped_reference_after_live_feedback_until_generated_cell_words_match_pre_0x4a4c8e\"\n";
	out << "}\n";
	return out.str();
}

std::string case_native_map_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason) {
	const bool supported = supported_one_level_land_scope(controlled_case);
	const int32_t width = map_width_for_size(controlled_case.size_class);
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_cli_plain_cpp_map_artifact_v1\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"status\": \"" << json_escape(status) << "\",\n";
	out << "  \"blocked_reason\": \"" << json_escape(blocked_reason) << "\",\n";
	out << "  \"case_id\": \"" << json_escape(controlled_case.id) << "\",\n";
	out << "  \"raw_controlled_case\": \"" << json_escape(controlled_case.raw) << "\",\n";
	out << "  \"format_kind\": \"plain_cpp_native_rmg_json_artifact_not_godot_amap\",\n";
	out << "  \"amap_written\": false,\n";
	out << "  \"playable_package_written\": false,\n";
	out << "  \"supported_one_level_land_scope\": " << (supported ? "true" : "false") << ",\n";
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
	out << "  \"native_artifact_boundary\": {\n";
	out << "    \"successful_without_godot\": true,\n";
	out << "    \"uses_godot_dictionary_array_string_refcounted_or_fileaccess\": false,\n";
	out << "    \"contains_phase_private_state\": true,\n";
	out << "    \"contains_playable_package_payload\": false,\n";
	out << "    \"playable_package_blocked_reason\": \"full_native_amap_export_requires_splitting_h3maped_rmg_generation_and_package_writeout_from_godot_dictionary_refcounted_fileaccess_apis\"\n";
	out << "  },\n";
	out << "  \"native_phase_snapshot\": ";
	out << case_phase_snapshot_json(controlled_case, status, blocked_reason);
	out << "}\n";
	return out.str();
}

} // namespace aurelion::rmg_native_core
