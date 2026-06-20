#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace aurelion::h3maped_rmg_core {

constexpr uint32_t UNASSIGNED_ZONE_WORD = 0x00ff0000U;
constexpr uint32_t CELL_ACTION_CONTROL_BIT_22 = 1U << 22U;
constexpr uint32_t CELL_DECOR_READY_BIT_25 = 1U << 25U;
constexpr uint32_t CELL_DECOR_CANDIDATE_BIT_26 = 1U << 26U;
constexpr uint32_t CELL_OCCUPIED_BLOCKED_BIT_27 = 1U << 27U;
constexpr uint32_t CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28 = 1U << 28U;
constexpr uint32_t CELL_TERRAIN_FLAG_SHIFT_0X49ACF6 = 15U;
constexpr uint32_t CELL_TERRAIN_FLAG_MASK_0X49ACF6 = 0x03U << CELL_TERRAIN_FLAG_SHIFT_0X49ACF6;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X10 = 0xffffffffU;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X1C = 0x7fbc7fbcU;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X20 = 0xffff7fbcU;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X24_MASK = 0xc0000548U;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X24_VALUE = 0x00000548U;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X28_PRESERVED_MASK = 0x01000000U;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X28_VALUE = CELL_DECOR_READY_BIT_25 | CELL_OCCUPIED_BLOCKED_BIT_27;
constexpr uint32_t GENERATED_CELL_INITIAL_WORD_0X2C_CLEAR_MASK = ~uint32_t(0x01U);
constexpr int32_t GENERATED_CELL_RECORD_STRIDE_BYTES = 0x30;
constexpr int32_t SOURCE_OBJECT_RECORD_COPY_SIZE_BYTES_0X4C = 0x4c;
constexpr int32_t SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8 = 0xe8;
constexpr uint32_t RELATION_RESET_WORD_0X1C = 0x7d007d00U;
constexpr uint32_t RELATION_RESET_COORD_MINUS_ONE = 0xffffffffU;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_WORD_0X1C_HIGH = 0x7d00U;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_BITS_12_14 = 0U;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_WORD_0X20_BYTE3 = 0xffffffffU;
constexpr uint32_t RELATION_WORD_0X28_BITS_12_14_MASK = 0x7U << 12U;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_0 = 0x004a28c8U;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_1 = 0x004a28dcU;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_2 = 0x004a28f3U;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_RECTANGLE_VERTEX_3 = 0x004a2907U;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_SELECTED_CLIPPED_ENDPOINT = 0x004a2990U;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_WRAP_CONTINUATION_ENDPOINT = 0x004a2adcU;
constexpr uint32_t BOUNDARY_VECTOR_APPEND_4A2777_FINAL_CLIPPED_ENDPOINT = 0x004a2b1eU;

struct RelationResetCell {
	uint32_t word_0x10 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x14 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x18 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x1c = RELATION_RESET_WORD_0X1C;
	uint32_t word_0x20 = 0U;
	uint32_t word_0x28 = 0U;
};

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next();
};

struct GeneratedCellInitialWords {
	uint32_t word_0x10 = GENERATED_CELL_INITIAL_WORD_0X10;
	uint32_t word_0x1c = GENERATED_CELL_INITIAL_WORD_0X1C;
	uint32_t word_0x20 = GENERATED_CELL_INITIAL_WORD_0X20;
	uint32_t word_0x24 = GENERATED_CELL_INITIAL_WORD_0X24_VALUE;
	uint32_t word_0x28 = GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
	uint32_t word_0x2c = 0U;
};

struct GeneratedCellWordGrid {
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	std::vector<uint32_t> word_0x10;
	std::vector<uint32_t> word_0x1c;
	std::vector<uint32_t> word_0x20;
	std::vector<uint32_t> word_0x24;
	std::vector<uint32_t> word_0x28;
	std::vector<uint32_t> word_0x2c;
};

struct GeneratedCellRecord0x30 {
	int32_t stride_bytes = GENERATED_CELL_RECORD_STRIDE_BYTES;
	bool object_reference_vector_fields_0x04_0x08_present = true;
	bool object_reference_vector_contents_known = false;
	int32_t object_reference_count = 0;
	bool word_0x10_known = true;
	uint32_t word_0x10 = GENERATED_CELL_INITIAL_WORD_0X10;
	bool word_0x14_known = false;
	uint32_t word_0x14 = 0U;
	bool word_0x18_known = false;
	uint32_t word_0x18 = 0U;
	bool word_0x1c_known = true;
	uint32_t word_0x1c = GENERATED_CELL_INITIAL_WORD_0X1C;
	bool word_0x20_known = true;
	uint32_t word_0x20 = GENERATED_CELL_INITIAL_WORD_0X20;
	bool word_0x24_known = true;
	uint32_t word_0x24 = GENERATED_CELL_INITIAL_WORD_0X24_VALUE;
	bool word_0x28_known = true;
	uint32_t word_0x28 = GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
	bool byte_0x2b_known = false;
	uint8_t byte_0x2b_known_mask = 0U;
	uint8_t byte_0x2b = 0U;
	bool word_0x2c_known = true;
	uint32_t word_0x2c = 0U;
};

struct GeneratedCellRecordGrid0x30 {
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t stride_bytes = GENERATED_CELL_RECORD_STRIDE_BYTES;
	std::vector<GeneratedCellRecord0x30> records;
};

struct SourceObjectRecord0x4c {
	int32_t source_row = -1;
	std::string source;
	std::string def_name;
	int32_t type_id_0x1c = 0;
	std::string type_name;
	int32_t metadata_bucket_index_0x08 = 0;
	int32_t subtype_0x20 = 0;
	int32_t group_0x24 = 0;
	int32_t last_flag_0x28 = 0;
	int32_t pass_count = 0;
	int32_t action_count = 0;
	uint16_t terrain_mask_a_0x14 = 0U;
	uint16_t terrain_mask_b_0x18 = 0U;
	std::string terrain_a_names;
	std::string terrain_b_names;
	bool rand_trn_backed = false;
};

struct SourceObjectCatalogSummary0x49da08 {
	int32_t record_count = 0;
	int32_t source_record_copy_size_bytes = SOURCE_OBJECT_RECORD_COPY_SIZE_BYTES_0X4C;
	int32_t objects_txt_record_count = 0;
	int32_t rand_trn_backed_record_count = 0;
	int32_t mine_type53_record_count = 0;
	int32_t mine_type53_ambiguous_subtype_count = 0;
	bool descriptor_only_mine_identity_ambiguous = false;
};

struct SourceObjectWrapperBucket0xe8 {
	int32_t bucket_index_0x08 = -1;
	int32_t first_type_id_0x1c = -1;
	std::string first_type_name;
	bool initialized_by_0x49db76 = false;
	int32_t record_count = 0;
	int32_t first_source_record_index = -1;
	int32_t last_source_record_index = -1;
	std::vector<int32_t> source_record_indices;
};

struct SourceObjectWrapperBucketSummary0xe8 {
	int32_t bucket_count = SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8;
	int32_t initialized_bucket_count = 0;
	int32_t non_empty_bucket_count = 0;
	int32_t total_source_record_references = 0;
	int32_t out_of_range_source_record_count = 0;
	int32_t max_bucket_record_count = 0;
	int32_t max_bucket_index_0x08 = -1;
};

struct SourceObjectMaskLaneResult4af89f {
	int32_t selected_lane = 9;
	bool selected_by_mask = false;
	int32_t scanned_lane_count = 0;
	uint32_t mask_word_0x18 = 0U;
};

struct SourceObjectSelectorResult4a9e40 {
	int32_t requested_lane = 0;
	int32_t requested_bucket_index_0x08 = -1;
	int32_t requested_source_field_0x20 = 0;
	bool bucket_found = false;
	int32_t scanned_record_count = 0;
	int32_t source_0x20_reject_count = 0;
	int32_t group_lane8_reject_count = 0;
	int32_t mask_reject_count = 0;
	int32_t accepted_count = 0;
	std::vector<int32_t> accepted_source_record_indices;
	bool selected = false;
	int32_t selected_candidate_index = -1;
	int32_t selected_source_record_index = -1;
	int32_t selected_type_id_0x1c = -1;
	int32_t selected_subtype_0x20 = 0;
	int32_t selected_group_0x24 = 0;
	std::string selected_def_name;
	uint32_t rng_state_before = 0U;
	uint32_t rng_state_after = 0U;
	bool rng_consumed = false;
	int32_t rng_value = -1;
};

struct SourceObjectResolvedWrapper4af785 {
	int32_t wrapper_index = -1;
	int32_t source_catalog_index = -1;
	SourceObjectRecord0x4c source_record_copy;
	int32_t metadata_bucket_index_0x08 = -1;
	int32_t resolver_lane_0x04 = 9;
	int32_t wrapper_0x04 = -1;
	bool wrapper_0x10_known = false;
	int32_t wrapper_0x10 = 0;
	bool initialized_by_0x49db76 = false;
	bool copied_source_record = false;
};

struct SourceObjectResolverSourcePair4af785 {
	int32_t copied_source_catalog_index = -1;
	int32_t wrapper_index = -1;
};

struct SourceObjectResolverState4af785 {
	std::vector<SourceObjectResolvedWrapper4af785> wrappers;
	std::vector<SourceObjectResolverSourcePair4af785> source_pairs_0xedc;
	int32_t next_wrapper_index = 0;
};

struct SourceObjectResolverResult4af785 {
	int32_t input_source_catalog_index = -1;
	int32_t input_source_row = -1;
	std::string input_def_name;
	int32_t input_type_id_0x1c = -1;
	int32_t input_subtype_0x20 = 0;
	int32_t metadata_bucket_index_0x08 = -1;
	int32_t resolver_lane_0x04 = 9;
	bool reused_existing_wrapper = false;
	bool created_new_wrapper = false;
	int32_t selected_wrapper_index = -1;
	int32_t scanned_bucket_wrapper_count = 0;
	int32_t lane_reject_count = 0;
	int32_t source_0x20_reject_count = 0;
	int32_t source_copy_mismatch_count = 0;
	int32_t bucket_size_before = 0;
	int32_t bucket_size_after = 0;
	int32_t source_pair_count_before = 0;
	int32_t source_pair_count_after = 0;
	bool appended_source_pair_0xedc = false;
	bool appended_wrapper_to_bucket = false;
	bool copied_source_record = false;
	bool wrapper_0x10_known = false;
	int32_t wrapper_0x10 = 0;
};

int32_t map_width_for_size_class(const std::string &size_class);
int32_t water_mode_code(const std::string &water_mode);
int32_t size_score(int32_t width, int32_t height, int32_t level_count, int32_t water_mode_code);
bool supports_one_level_land_scope(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class);
std::string strict_scope_id(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class);
std::string strict_scope_label(int32_t width, int32_t height, int32_t level_count, const std::string &water_mode, const std::string &size_class);
GeneratedCellInitialWords generated_cell_initializer_0x499ea3(uint32_t old_word_0x24 = 0U, uint32_t old_word_0x28 = 0U, uint32_t old_word_0x2c = 0U);
GeneratedCellRecordGrid0x30 generated_cell_record_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count);
GeneratedCellWordGrid generated_cell_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count);
void generated_cell_grid_reset_0x49a072(int32_t width, int32_t height, int32_t level_count, std::vector<uint32_t> &word_0x20, std::vector<uint32_t> &word_0x24, std::vector<uint32_t> &word_0x28, std::vector<uint32_t> &word_0x2c);
const std::vector<SourceObjectRecord0x4c> &source_object_catalog_0x49da08();
SourceObjectCatalogSummary0x49da08 source_object_catalog_summary_0x49da08();
std::vector<SourceObjectRecord0x4c> source_object_records_by_type_0x49da08(int32_t type_id);
std::vector<SourceObjectRecord0x4c> source_object_records_by_type_subtype_0x49da08(int32_t type_id, int32_t subtype);
const std::vector<SourceObjectWrapperBucket0xe8> &source_object_wrapper_buckets_0x49db76();
SourceObjectWrapperBucketSummary0xe8 source_object_wrapper_bucket_summary_0x49db76();
bool source_object_wrapper_bucket_by_index_0x49db76(int32_t bucket_index, SourceObjectWrapperBucket0xe8 &out_bucket);
SourceObjectMaskLaneResult4af89f source_object_mask_lane_selector_0x4af89f(const SourceObjectRecord0x4c &record);
SourceObjectSelectorResult4a9e40 source_object_wrapper_selector_0x4a9e40(uint32_t rng_state, int32_t requested_lane, int32_t bucket_index_0x08, int32_t requested_source_field_0x20);
bool same_source_object_record_0x4c(const SourceObjectRecord0x4c &left, const SourceObjectRecord0x4c &right);
int32_t source_object_catalog_index_0x49da08(const SourceObjectRecord0x4c &record);
SourceObjectResolverResult4af785 source_object_descriptor_resolver_0x4af785(SourceObjectResolverState4af785 &state, const SourceObjectRecord0x4c &record);

struct GeneratedCell49a85dStampResult {
	bool center_in_bounds = false;
	bool center_set = false;
	int32_t covered_cell_count = 0;
	int32_t covered_set_count = 0;
};

struct GeneratedCell49a962SweepResult {
	bool center_in_bounds = false;
	bool center_candidate_set = false;
	int32_t neighbor_scan_count = 0;
	int32_t neighbor_bit22_skip_count = 0;
	int32_t neighbor_invalid_skip_count = 0;
	int32_t neighbor_terrain8_skip_count = 0;
	int32_t neighbor_clear_count = 0;
};

struct BoundaryLineCellWrite {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
	int32_t zone_id = 0;
	bool reserved = false;
};

struct BoundaryLineWriteResult {
	std::vector<BoundaryLineCellWrite> trace;
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

struct BoundaryVectorRecord4a2777 {
	int32_t x = 0;
	int32_t y = 0;
	uint32_t append_callsite = 0;
	std::string append_label;
};

struct BoundaryVector4a2777 {
	std::vector<BoundaryVectorRecord4a2777> records;
	std::map<uint32_t, int32_t> append_counts_by_callsite;
	int32_t rejected_unknown_callsite_count = 0;
};

struct BoundaryCyclePoint4a2777 {
	int32_t model_node_index = -1;
	int32_t pair_index = -1;
	int32_t next_index = -1;
	int32_t previous_index = -1;
	int32_t next_pair_index = -1;
	int32_t raw_x_0x00 = 0;
	int32_t raw_y_0x04 = 0;
	int32_t finalized_x_0x1c = 0;
	int32_t finalized_y_0x20 = 0;
	int32_t x = 0;
	int32_t y = 0;
	bool finalized = true;
	bool has_payload = false;
	int32_t payload = 0;
	bool next_pair_has_payload = false;
	int32_t next_pair_payload = 0;
};

struct SourceNodeCyclePoint4a2777 {
	int32_t model_node_index = -1;
	int32_t pair_index = -1;
	int32_t next_index = -1;
	int32_t previous_index = -1;
	int32_t next_pair_index = -1;
	int32_t raw_x_0x00 = 0;
	int32_t raw_y_0x04 = 0;
	int32_t finalized_x_0x1c = 0;
	int32_t finalized_y_0x20 = 0;
	bool finalized = true;
	bool has_payload = false;
	int32_t payload = 0;
	bool next_pair_has_payload = false;
	int32_t next_pair_payload = 0;
};

struct BoundarySourceCycleHandoff4a2777 {
	int32_t runtime_zone_index = -1;
	int32_t zone_word = 0;
	int32_t level = 0;
	int32_t random_span_limit = 1;
	int32_t source_record_vector_index_4a3e9c = -1;
	bool has_source_record_seed_0x10 = false;
	SpanRecord source_record_seed_0x10;
	std::vector<SourceNodeCyclePoint4a2777> source_nodes;
};

struct RuntimeZoneFootprintInput4a3a03 {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t x_after_bbox_rescale = 0;
	int32_t y_after_bbox_rescale = 0;
	int32_t level = 0;
};

struct RuntimeZoneBoundaryInput4a3a03 {
	RuntimeZoneFootprintInput4a3a03 footprint;
	int32_t zone_word = 0;
	int32_t random_span_limit = 1;
	int32_t source_record_vector_index_4a3e9c = -1;
	bool has_source_record_seed_0x10 = false;
	SpanRecord source_record_seed_0x10;
	uint16_t allowed_town_mask_0x41_0x49 = 0U;
	int32_t selected_town_choice_index_0x49b3c1 = -1;
	bool terrain_match_to_town_0x84 = false;
	uint16_t allowed_terrain_mask_0x85_0x8c = 0U;
};

struct SourceTownRules4a218c {
	int32_t min_towns = 0;
	int32_t min_castles = 0;
	int32_t town_density = 0;
	int32_t castle_density = 0;
};

struct SourceMineRules4a218c {
	int32_t minimum_wood = 0;
	int32_t minimum_mercury = 0;
	int32_t minimum_ore = 0;
	int32_t minimum_sulfur = 0;
	int32_t minimum_crystal = 0;
	int32_t minimum_gems = 0;
	int32_t minimum_gold = 0;
	int32_t density_wood = 0;
	int32_t density_mercury = 0;
	int32_t density_ore = 0;
	int32_t density_sulfur = 0;
	int32_t density_crystal = 0;
	int32_t density_gems = 0;
	int32_t density_gold = 0;
};

struct SourceTreasureBand4a218c {
	int32_t density = 0;
	int32_t low = 0;
	int32_t high = 0;
};

struct SourceZonePayload4a218c {
	int32_t source_row = -1;
	int32_t source_type_code = 0;
	int32_t source_ownership = -1;
	bool same_town_type = false;
	bool monster_match_to_town = false;
	int32_t monster_strength_mode = 3;
	uint16_t allowed_monster_town_mask = 0U;
	SourceTownRules4a218c player_towns;
	SourceTownRules4a218c neutral_towns;
	SourceMineRules4a218c mines;
	SourceTreasureBand4a218c treasure_band_0;
	SourceTreasureBand4a218c treasure_band_1;
	SourceTreasureBand4a218c treasure_band_2;
};

struct RuntimeZoneSeedInput4a218c {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t source_index = -1;
	int32_t h3maped_zone_word_id = -1;
	int32_t source_bucket = -1;
	int32_t actual_player_color = -1;
	int32_t source_base_size = 0;
	uint16_t allowed_town_mask_0x41_0x49 = 0U;
	int32_t selected_town_choice_index_0x49b3c1 = -1;
	bool terrain_match_to_town_0x84 = false;
	uint16_t allowed_terrain_mask_0x85_0x8c = 0U;
	SourceZonePayload4a218c source_payload;
};

struct RuntimeLinkSeedInput4a218c {
	int32_t from_index = -1;
	int32_t to_index = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
};

struct PlayerSlotAssignmentRecord4ac62a {
	int32_t source_owner_index = -1;
	int32_t actual_player_color = -1;
	bool human = false;
};

struct PlayerSlotAssignmentResult4ac62a {
	bool complete = false;
	int32_t requested_human_count = 0;
	int32_t requested_player_count = 0;
	int32_t assigned_player_count = 0;
	std::vector<int32_t> selected_color_order_ed8;
	std::vector<int32_t> raw_ee0_slots;
	std::vector<int32_t> mapped_ee4_slots;
	std::vector<PlayerSlotAssignmentRecord4ac62a> assignments;
};

struct TemplateZoneRecord4a218c {
	int32_t source_zone_id = -1;
	int32_t source_index = -1;
	int32_t h3maped_zone_word_id = -1;
	int32_t source_bucket = -1;
	int32_t source_owner_index = -1;
	int32_t source_base_size = 0;
	int32_t player_filter_min_human = 0;
	int32_t player_filter_max_human = 8;
	int32_t player_filter_min_total = 0;
	int32_t player_filter_max_total = 8;
	uint16_t allowed_town_mask_0x41_0x49 = 0U;
	bool terrain_match_to_town_0x84 = false;
	uint16_t allowed_terrain_mask_0x85_0x8c = 0U;
	SourceZonePayload4a218c source_payload;
};

struct TemplateLinkRecord4a1f3b {
	int32_t source_zone_a = -1;
	int32_t source_zone_b = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
	int32_t player_filter_min_human = 0;
	int32_t player_filter_max_human = 8;
	int32_t player_filter_min_total = 0;
	int32_t player_filter_max_total = 8;
};

struct RuntimeSeedBuildResult4a218c {
	bool blocked = false;
	int32_t skipped_zone_filter_count = 0;
	int32_t skipped_link_filter_count = 0;
	int32_t missing_link_endpoint_count = 0;
	std::vector<RuntimeZoneSeedInput4a218c> runtime_zone_seeds;
	std::vector<RuntimeLinkSeedInput4a218c> runtime_links;
};

struct TemplateCandidateContainerRecord4ac552 {
	int32_t vector_index = -1;
	int32_t source_catalog_index = -1;
	std::string template_name;
	int32_t zone_count = 0;
	int32_t link_count = 0;
};

struct TemplateSelectionRuntimeResult4ac552 {
	bool blocked = false;
	int32_t size_score = 0;
	int32_t human_count = 0;
	int32_t player_count = 0;
	int32_t accepted_template_count = 0;
	int32_t selected_vector_index = -1;
	int32_t selected_source_catalog_index = -1;
	std::string selected_template_name;
	std::vector<TemplateCandidateContainerRecord4ac552> accepted_candidate_containers_10d4_10d8;
	uint32_t rng_state_before_template_selection = 0;
	uint32_t rng_state_after_template_selection = 0;
	int32_t rng_value = -1;
	uint8_t human_capable_source_owner_mask = 0;
	uint8_t player_capable_source_owner_mask = 0;
	int32_t source_zone_record_count = 0;
	int32_t source_link_record_count = 0;
	PlayerSlotAssignmentResult4ac62a player_assignment;
	RuntimeSeedBuildResult4a218c runtime_seed;
};

struct GeneratorSetupModeResult49ecf2 {
	int32_t setup_object_0x44 = 0;
	int32_t generator_mode_0x10b8 = 0;
	bool randomized_setup_sentinel_3 = false;
	int32_t setup_rng_value = -1;
	int32_t setup_rng_call_count = 0;
	uint32_t rng_state_before_setup = 0;
	uint32_t rng_state_before_template_selection = 0;
};

struct CoordinatePlacementStep4a1f3b {
	int32_t runtime_zone_index = -1;
	std::string pass_id;
	std::string candidate_source;
	int32_t candidate_count_before_prune = 0;
	int32_t candidate_count_after_prune = 0;
	int32_t explicit_link_base_count = 0;
	int32_t selected_candidate_index = -1;
	int32_t rng_value = -1;
	bool blocked = false;
};

struct CoordinateSeedResult4a218c {
	bool blocked = false;
	uint32_t rng_state_before = 0;
	uint32_t rng_state_after = 0;
	int32_t rng_call_count = 0;
	int32_t town_choice_rng_call_count_0x49b3c1 = 0;
	int32_t generator_mode_0x10b8 = 0;
	int32_t minimum_source_base_size = 0;
	int32_t coordinate_prune_divisor_4a218c = 0;
	int32_t coordinate_prune_span_budget_4a218c = 0;
	int32_t level_count = 0;
	int32_t map_width = 0;
	int32_t map_height = 0;
	int32_t min_y_before_rescale = 0;
	int32_t min_x_before_rescale = 0;
	int32_t max_y_before_rescale = 0;
	int32_t max_x_before_rescale = 0;
	int32_t bbox_span = 0;
	int32_t map_span = 0;
	int32_t offset_y = 0;
	int32_t offset_x = 0;
	std::vector<CoordinatePlacementStep4a1f3b> placement_steps;
	std::vector<RuntimeZoneBoundaryInput4a3a03> boundary_inputs;
	std::vector<RuntimeZoneSeedInput4a218c> runtime_zone_records_after_0x49b3c1;
};

struct SourceSplitStep4ccb64 {
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

struct SourceDescriptorNode4cca55 {
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

struct SourceWalk4cca55 {
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t start_x = 0;
	int32_t start_y = 0;
	int32_t locator_node_index = -1;
	std::string locator_status;
	std::vector<SourceNodeCyclePoint4a2777> source_nodes;
};

struct SourceNodeFootprintResult4a3a03 {
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
	std::vector<SourceSplitStep4ccb64> split_steps;
	std::vector<SourceDescriptorNode4cca55> descriptor_nodes;
	std::vector<SourceWalk4cca55> walks;
};

struct BoundaryCycleInput4a2777 {
	int32_t runtime_zone_index = -1;
	int32_t zone_word = 0;
	int32_t level = 0;
	int32_t random_span_limit = 1;
	int32_t source_record_vector_index_4a3e9c = -1;
	bool has_span_seed_4a325d = false;
	SpanRecord span_seed_4a325d;
	std::vector<BoundaryCyclePoint4a2777> cycle_nodes;
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
	std::string branch;
	bool input_inside = false;
};

struct BoundarySegment4a2777 {
	std::string id;
	std::string branch;
	std::string writer;
	int32_t from_x = 0;
	int32_t from_y = 0;
	int32_t to_x = 0;
	int32_t to_y = 0;
	bool randomized = false;
	BoundaryLineWriteResult line;
};

struct BoundaryZoneMaterialization4a2777 {
	int32_t runtime_zone_index = -1;
	int32_t zone_word = 0;
	int32_t level = 0;
	int32_t source_record_vector_index_4a3e9c = -1;
	int32_t selected_segment_index = -1;
	std::string status;
	std::vector<BoundaryCyclePoint4a2777> finalized_points;
	std::vector<BoundaryVectorRecord4a2777> appended_vertices;
	std::vector<BoundarySegment4a2777> segments;
	bool has_span_seed_4a325d = false;
	SpanRecord span_seed_4a325d;
	SpanRecord effective_span_seed_4a325d;
	bool span_seed_relocated_4a325d = false;
	std::string span_seed_relocation_status_4a325d;
	bool span_fill_executed_4a325d = false;
	SpanFillResult span_fill_4a325d;
};

struct BoundaryMaterialization4a2777 {
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t generator_mode_0x10b8 = 0;
	uint32_t rng_state_before = 0;
	uint32_t rng_state_after = 0;
	std::vector<uint32_t> private_zone_words;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint8_t> cell_flags;
	BoundaryVector4a2777 boundary_vector;
	std::vector<BoundaryZoneMaterialization4a2777> zones;
	int32_t runtime_zone_walk_count = 0;
	int32_t blocked_zone_count = 0;
	int32_t fallback_zone_count = 0;
	int32_t connector_segment_count = 0;
	int32_t wrap_segment_count = 0;
	int32_t final_segment_count = 0;
	int32_t rectangle_edge_segment_count = 0;
	int32_t appended_vertex_count = 0;
	int32_t skipped_unfinalized_node_count = 0;
	int32_t skipped_out_of_bounds_clip_count = 0;
	int32_t owner_gate_skipped_segment_count = 0;
	int32_t flagged_writer_segment_count = 0;
	int32_t deterministic_writer_segment_count = 0;
	int32_t randomized_rng_call_count = 0;
	int32_t randomized_inserted_midpoint_count = 0;
	int32_t randomized_max_pending_point_count = 0;
	int32_t trace_write_count = 0;
	int32_t unique_cell_count = 0;
	int32_t out_of_bounds_write_count = 0;
	int32_t span_fill_zone_count = 0;
	int32_t span_fill_trace_write_count = 0;
	int32_t span_fill_unique_cell_count = 0;
	int32_t span_fill_seed_blocked_count = 0;
	int32_t span_fill_seed_relocated_count = 0;
	int32_t span_fill_out_of_bounds_span_count = 0;
	int32_t span_fill_pushed_span_count = 0;
	int32_t span_fill_popped_span_count = 0;
	int32_t span_fill_max_pending_span_count = 0;
	int32_t span_fill_blocked_initial_span_count = 0;
	int32_t source_handoff_count = 0;
	int32_t source_handoff_point_count = 0;
	int32_t source_handoff_finalized_point_count = 0;
	int32_t source_handoff_descriptor_indexed_point_count = 0;
	int32_t source_handoff_raw_coordinate_point_count = 0;
	int32_t source_handoff_source_record_seed_count = 0;
	int32_t source_handoff_missing_source_record_seed_count = 0;
	bool loop_guard_exhausted = false;
};

struct RuntimeTerrainSelectionRecord49b53d {
	int32_t runtime_zone_index = -1;
	int32_t level = 0;
	int32_t selected_town_choice_index_0x49b3c1 = -1;
	bool terrain_match_to_town_0x84 = false;
	uint16_t allowed_terrain_mask_0x85_0x8c = 0U;
	int32_t selected_terrain_id_0x49b53d = 0;
	std::string selection_source;
	int32_t rng_value = -1;
	int32_t rng_modulus = 0;
	int32_t selected_allowed_ordinal = -1;
	bool forced_subterranean_0x49b5c3 = false;
};

struct RuntimeTerrainSelectionResult49b53d {
	uint32_t rng_state_before = 0;
	uint32_t rng_state_after = 0;
	int32_t rng_call_count = 0;
	int32_t match_to_town_count = 0;
	int32_t allowed_flag_choice_count = 0;
	int32_t no_eligible_default_zero_count = 0;
	int32_t forced_subterranean_count = 0;
	std::vector<RuntimeTerrainSelectionRecord49b53d> records;
};

struct TerrainVisualMissingBucketSample4bcfc3 {
	int32_t level = 0;
	int32_t x = 0;
	int32_t y = 0;
	int32_t terrain_id = 0;
	int32_t shape_class = 0;
	int32_t flag_a = 0;
	int32_t flag_b = 0;
	int32_t neighbor_mask = 0;
	int32_t row_table_count = 0;
	bool final_sweep = false;
};

struct TerrainRepaintResult4a3f27 {
	bool executed = false;
	std::string status;
	int32_t full_map_water_repaint_count_0x4a4025 = 0;
	int32_t zone_repaint_candidate_count_0x4a4082 = 0;
	int32_t zone_repaint_write_count_0x4a4163 = 0;
	int32_t water_zone_skip_count = 0;
	int32_t owner_gate_skip_count_0x4a4142 = 0;
	int32_t member_gate_skip_count_0x4a4150 = 0;
	uint32_t terrain_visual_rng_state_before_0x4bb74b = 0;
	uint32_t terrain_visual_rng_state_after_0x4bb74b = 0;
	int32_t terrain_visual_attempt_count_0x4bb74b = 0;
	int32_t terrain_visual_write_count_0x4bb74b = 0;
	int32_t terrain_visual_missing_bucket_count_0x4bcfc3 = 0;
	int32_t terrain_visual_initial_water_write_count_0x4a4025 = 0;
	int32_t terrain_visual_repaint_write_count_0x4a4082 = 0;
	int32_t terrain_visual_queue_write_count_0x4bb74b = 0;
	int32_t terrain_visual_art_nonzero_cell_count = 0;
	int32_t terrain_visual_flag_cell_count = 0;
	int32_t terrain_visual_dirty_cell_count_0x4bad0f = 0;
	int32_t terrain_visual_roundtrip_mismatch_count = 0;
	int32_t terrain_visual_terrain_mismatch_count = 0;
	int32_t terrain_visual_post_queue_terrain_difference_count = 0;
	int32_t terrain_visual_set_a_insert_count = 0;
	int32_t terrain_visual_set_b_insert_count = 0;
	int32_t terrain_visual_set_a_drain_count = 0;
	int32_t terrain_visual_set_b_drain_count = 0;
	int32_t terrain_visual_set_b_candidate_true_count = 0;
	int32_t terrain_visual_retouch_write_count_0x4bbd01 = 0;
	int32_t terrain_visual_final_sweep_cell_count_0x4bbfcc = 0;
	int32_t terrain_visual_final_sweep_class_correction_count_0x4bbfcc = 0;
	int32_t terrain_visual_preserved_current_record_count_0x4bc5a3 = 0;
	bool terrain_visual_queue_drain_complete_0x4bc5f0 = false;
	std::vector<uint32_t> generated_cell_word_0x10;
	std::vector<uint32_t> generated_cell_word_0x1c;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	std::vector<uint32_t> terrain_scratch_word_0x4bad0f;
	std::vector<int32_t> terrain_code;
	std::vector<TerrainVisualMissingBucketSample4bcfc3> terrain_visual_missing_bucket_samples_0x4bcfc3;
};

struct FootprintFinalizerResult4a3710 {
	bool executed = false;
	bool blocked = false;
	std::string status;
	int32_t level_count = 0;
	int32_t water_mode_code = 0;
	bool synthetic_branch_allowed_by_0x4a3a9d = false;
	int32_t original_same_level_runtime_zone_count = 0;
	int32_t final_runtime_zone_count = 0;
	int32_t appended_runtime_zone_count = 0;
	int32_t adjacency_insert_count = 0;
	int32_t zone_order_reset_call_count = 0;
	int32_t per_zone_order_helper_call_count = 0;
	bool materializes_generated_cells = false;
	bool relation_order_vectors_required_for_downstream_consumers = true;
	bool relation_order_vectors_materialized = false;
	std::string downstream_relation_order_blocker;
};

struct BoundaryOwnerGridResult4a3a03 {
	SourceNodeFootprintResult4a3a03 source_footprints;
	std::vector<BoundarySourceCycleHandoff4a2777> handoffs;
	BoundaryMaterialization4a2777 materialization;
	FootprintFinalizerResult4a3710 footprint_finalizer;
	bool source_blocked = false;
	bool materialization_executed = false;
	bool footprint_finalizer_executed = false;
	int32_t missing_boundary_input_count = 0;
	int32_t missing_source_walk_count = 0;
};

struct CoordinateOwnerGridResult4a218c {
	CoordinateSeedResult4a218c coordinate_seed;
	BoundaryOwnerGridResult4a3a03 owner_grid;
	RuntimeTerrainSelectionResult49b53d terrain_selection;
	TerrainRepaintResult4a3f27 terrain_repaint;
	bool coordinate_seed_blocked = false;
	bool owner_grid_executed = false;
	bool terrain_selection_executed = false;
	bool terrain_repaint_executed = false;
};

struct GeneratorObjectVectorState {
	std::string label;
	uint32_t begin_offset = 0U;
	uint32_t end_offset = 0U;
	uint32_t capacity_offset = 0U;
	bool present = false;
	bool contents_known = false;
	bool count_known = false;
	int32_t count = 0;
};

struct GeneratorObjectPrivateState {
	uint32_t generated_cell_buffer_offset_0x14 = 0x14U;
	uint32_t width_offset_0x18 = 0x18U;
	uint32_t height_offset_0x1c = 0x1cU;
	uint32_t level_count_offset_0x20 = 0x20U;
	bool generated_cell_buffer_owned = false;
	GeneratedCellRecordGrid0x30 generated_cell_buffer;
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	GeneratorObjectVectorState endpoint_vector_c8_cc;
	GeneratorObjectVectorState endpoint_vector_d8_dc;
	GeneratorObjectVectorState object_record_vector_ec4_ecc;
	GeneratorObjectVectorState source_pair_vector_edc;
	GeneratorObjectVectorState pending_entry_vector_eec_ef0_ef4;
	GeneratorObjectVectorState candidate_container_vector_10d4_10d8;
	GeneratorObjectVectorState relation_vector_10e4_10e8;
	GeneratorObjectVectorState endpoint_byte_state_vector_1104_1108;
	bool endpoint_cursor_0xf5c_present = false;
	bool endpoint_cursor_0xf5c_known = false;
	int32_t endpoint_cursor_0xf5c = 0;
	bool descriptor_counter_table_0x1110_present = false;
	bool descriptor_counter_table_0x1110_contents_known = false;
	int32_t descriptor_counter_table_0x1110_known_count = 0;
	bool source_owner_player_slots_ed8_ee0_ee4_present = false;
	int32_t selected_color_order_ed8_count = 0;
	int32_t raw_source_owner_slots_ee0_count = 0;
	int32_t mapped_source_owner_slots_ee4_count = 0;
	std::vector<std::string> remaining_private_state_blockers;
};

int64_t cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level);
int64_t generated_cell_flat_key_4a325d(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level);
uint32_t generated_cell_zone_word_4a325d(uint32_t existing_word, int32_t zone_id);
void generated_cell_apply_owner_word_4a2777(std::vector<uint32_t> &private_zone_words, std::vector<uint32_t> &generated_cell_word_0x20, int64_t key, int32_t zone_id);

uint32_t generated_cell_word20_set_low_word(uint32_t word_0x20, uint32_t low_word);
uint32_t generated_cell_4a54a7_endpoint_word28(uint32_t word_0x28);
uint32_t generated_cell_4aa3e9_reward_word28(uint32_t word_0x28);
uint32_t generated_cell_49cf34_attach_word28(uint32_t word_0x28);
uint32_t generated_cell_4a56b6_projection_word20(uint32_t word_0x20, uint32_t lowered_low_word);
uint32_t generated_cell_49acf6_word24(uint32_t word_0x24, int32_t terrain_arg, int32_t art_arg);
uint32_t generated_cell_49acf6_word28(uint32_t word_0x28, int32_t flag_a, int32_t flag_b);
uint32_t generated_cell_terrain_flags_0x49acf6(int32_t flag_a, int32_t flag_b);
uint32_t generated_cell_4a59e2_pack_word_0x1c(uint32_t word_0x1c, uint32_t arg_word_0x1c_high);
uint32_t generated_cell_4a59e2_pack_word_0x20(uint32_t word_0x20, uint32_t arg_byte3);
uint32_t generated_cell_4a59e2_pack_word_0x28(uint32_t word_0x28, uint32_t arg_bits_12_14);
uint32_t generated_cell_4a5767_reset_force_word_0x1c(uint32_t word_0x1c_after_4a59e2);
uint32_t generated_cell_49a318_clear_source_word_0x1c(uint32_t word_0x1c);
RelationResetCell generated_cell_4a5767_reset_cell(uint32_t source_word_0x20, uint32_t source_word_0x28);
bool generated_cell_4a5767_reset_projection(GeneratedCellRecord0x30 &record);
bool generated_cell_49a318_clear_source_projection(GeneratedCellRecord0x30 &record);

bool generated_cell_index_valid(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat);
bool generated_cell_49a1d8_valid_record(const GeneratedCellRecord0x30 &record);
bool generated_cell_49a1d8_valid_word24(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat);
bool generated_cell_49a1d8_valid_terrain(const std::vector<uint32_t> &word_0x28, const std::vector<int32_t> &terrain_code, int64_t flat);
bool generated_cell_49aa63(GeneratedCellRecord0x30 &record, bool set_candidate);
bool generated_cell_49aa63(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_candidate);
bool generated_cell_49a932(GeneratedCellRecord0x30 &record, bool set_occupied);
bool generated_cell_49a932(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_occupied);
bool generated_cell_49abd6_action_stamp(GeneratedCellRecord0x30 &record);
bool generated_cell_49abd6_action_stamp(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat);
bool generated_cell_49abd6_body_reject_stamp(GeneratedCellRecord0x30 &record);
bool generated_cell_49abd6_body_reject_stamp(std::vector<uint32_t> &word_0x28, int64_t flat);
GeneratedCell49a85dStampResult generated_cell_49a85d_stamp(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level);
GeneratedCell49a962SweepResult generated_cell_49a962_word24(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, const std::vector<uint32_t> &word_0x24, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level);
GeneratedCell49a962SweepResult generated_cell_49a962_terrain(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, const std::vector<int32_t> &terrain_code, int32_t width, int32_t height, int32_t level_count, int32_t x, int32_t y, int32_t level);
bool span_cell_in_bounds_4a325d(int32_t width, int32_t height, int32_t level_count, const SpanRecord &span);
bool generated_cell_owner_unassigned_4a325d(const std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level);
bool private_zone_word_unassigned_4a325d(const std::vector<uint32_t> &zone_words, int32_t width, int32_t height, int32_t x, int32_t y, int32_t level);
ClipResult clip_point_4a2b33(int32_t x1, int32_t y1, int32_t x2, int32_t y2, const ClipBounds &bounds);
bool point_inside_bounds_4a2777(const ClipResult &point, const ClipBounds &bounds);
const char *boundary_vector_append_callsite_label_4a2777(uint32_t callsite);
bool boundary_vector_append_callsite_recovered_4a2777(uint32_t callsite);
bool boundary_vector_append_4a2777(BoundaryVector4a2777 &vector, int32_t x, int32_t y, uint32_t callsite);
GeneratorSetupModeResult49ecf2 generator_setup_mode_49ecf2(uint32_t seed, int32_t setup_object_0x44);
bool player_filter_allows_4a218c(int32_t min_human, int32_t max_human, int32_t min_total, int32_t max_total, int32_t human_count, int32_t player_count);
PlayerSlotAssignmentResult4ac62a player_slot_assignment_4ac62a_4ac6ec(int32_t human_count, int32_t player_count, uint8_t human_capable_source_owner_mask, uint8_t player_capable_source_owner_mask, uint8_t selected_color_mask = 0xffU);
RuntimeSeedBuildResult4a218c runtime_seed_inputs_from_template_records_4a218c_4a1f3b(const std::vector<TemplateZoneRecord4a218c> &zones, const std::vector<TemplateLinkRecord4a1f3b> &links, const PlayerSlotAssignmentResult4ac62a &assignment, int32_t human_count, int32_t player_count);
TemplateSelectionRuntimeResult4ac552 template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(uint32_t seed, int32_t size_score, int32_t human_count, int32_t player_count, uint8_t selected_color_mask = 0xffU);
CoordinateSeedResult4a218c coordinate_seed_runtime_zone_boundary_inputs_4a218c_4a1f3b_4a19ed(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state_after_template_selection, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones, const std::vector<RuntimeLinkSeedInput4a218c> &links);
RuntimeTerrainSelectionResult49b53d runtime_terrain_selection_49b53d(uint32_t rng_state_after_coordinate_replay, const std::vector<RuntimeZoneBoundaryInput4a3a03> &runtime_zones);
TerrainRepaintResult4a3f27 terrain_repaint_4a3f27(int32_t width, int32_t height, int32_t level_count, const BoundaryMaterialization4a2777 &owner_materialization, const RuntimeTerrainSelectionResult49b53d &terrain_selection);
GeneratorObjectPrivateState generator_object_private_state_from_recovered_partial_chain(int32_t width, int32_t height, int32_t level_count, const TemplateSelectionRuntimeResult4ac552 &template_selection, const CoordinateOwnerGridResult4a218c &coordinate_result);
SourceNodeFootprintResult4a3a03 build_source_node_footprints_4a3a03_4ccb64_4cca55(const std::vector<RuntimeZoneFootprintInput4a3a03> &runtime_zones);
FootprintFinalizerResult4a3710 footprint_finalizer_4a3710(int32_t level_count, int32_t water_mode_code, int32_t original_same_level_runtime_zone_count, int32_t final_runtime_zone_count);
BoundaryOwnerGridResult4a3a03 materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d_4a3710(int32_t width, int32_t height, int32_t level_count, int32_t water_mode_code, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<RuntimeZoneBoundaryInput4a3a03> &runtime_zones);
CoordinateOwnerGridResult4a218c coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(int32_t width, int32_t height, int32_t level_count, int32_t water_mode_code, int32_t generator_mode_0x10b8, uint32_t rng_state_after_template_selection, const std::vector<RuntimeZoneSeedInput4a218c> &runtime_zones, const std::vector<RuntimeLinkSeedInput4a218c> &links);
std::vector<BoundaryCycleInput4a2777> boundary_cycles_from_source_handoffs_4a2777(const std::vector<BoundarySourceCycleHandoff4a2777> &handoffs);
BoundaryMaterialization4a2777 materialize_boundary_cycles_4a2777(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<BoundaryCycleInput4a2777> &cycles);
BoundaryMaterialization4a2777 materialize_boundary_source_handoffs_4a2777_4a325d(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, uint32_t rng_state, const std::vector<BoundarySourceCycleHandoff4a2777> &handoffs);
BoundaryLineWriteResult boundary_line_writer_4a261a(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level);
BoundaryLineWriteResult boundary_randomized_line_writer_4a2413(int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t zone_id, int32_t level, int32_t random_span_limit, H3MapedRng &rng, int32_t &rng_call_count, int32_t &inserted_midpoint_count, int32_t &max_pending_point_count);
void apply_line_trace_to_zone_buffer_4a2777(const BoundaryLineWriteResult &line, std::vector<uint32_t> &zone_words, std::vector<uint32_t> &generated_cell_word_0x20, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count);
SpanFillResult span_fill_4a325d(std::vector<uint32_t> &zone_words, std::vector<uint32_t> &generated_cell_word_0x20, std::vector<uint8_t> &cell_flags, int32_t width, int32_t height, int32_t level_count, int32_t generator_mode_0x10b8, int32_t zone_id, const SpanRecord &seed);

int32_t deplete_generated_cell_scores_4a54a7(std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t level_count, int32_t anchor_x, int32_t anchor_y, int32_t anchor_level);

} // namespace aurelion::h3maped_rmg_core
