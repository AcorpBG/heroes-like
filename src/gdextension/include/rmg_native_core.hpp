#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace aurelion::rmg_native_core {

struct ControlledCase {
	std::string raw;
	std::string id;
	std::string size_class;
	int32_t players = 0;
	uint32_t seed = 0;
	std::string water_mode;
	int32_t level_count = 0;
	int32_t human_count = 0;
	int32_t computer_count = 0;
	bool setup_object_0x44_known = false;
	bool setup_object_0x44_supplied = false;
	int32_t setup_object_0x44 = 0;
	bool parse_ok = false;
	std::string parse_error;
};

struct SharedSourceTownRules {
	int32_t min_towns = 0;
	int32_t min_castles = 0;
	int32_t town_density = 0;
	int32_t castle_density = 0;
};

struct SharedSourceMineRules {
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

struct SharedSourceTreasureBand {
	int32_t density = 0;
	int32_t low = 0;
	int32_t high = 0;
};

struct SharedSourceZonePayload {
	int32_t source_row = -1;
	int32_t source_type_code = 0;
	int32_t source_ownership = -1;
	bool same_town_type = false;
	bool monster_match_to_town = false;
	int32_t monster_strength_mode = 3;
	uint16_t allowed_monster_town_mask = 0U;
	SharedSourceTownRules player_towns;
	SharedSourceTownRules neutral_towns;
	SharedSourceMineRules mines;
	SharedSourceTreasureBand treasure_band_0;
	SharedSourceTreasureBand treasure_band_1;
	SharedSourceTreasureBand treasure_band_2;
};

struct SharedSourceObjectRecord0x4c {
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

struct SharedSourceObjectWrapperBucket0xe8 {
	int32_t bucket_index_0x08 = -1;
	int32_t first_type_id_0x1c = -1;
	std::string first_type_name;
	bool initialized_by_0x49db76 = false;
	int32_t record_count = 0;
	int32_t first_source_record_index = -1;
	int32_t last_source_record_index = -1;
	std::vector<int32_t> source_record_index_sample;
};

struct SharedSourceObjectSelectorResult4a9e40 {
	int32_t requested_lane = 0;
	int32_t requested_bucket_index_0x08 = -1;
	int32_t requested_source_field_0x20 = 0;
	bool bucket_found = false;
	int32_t scanned_record_count = 0;
	int32_t source_0x20_reject_count = 0;
	int32_t group_lane8_reject_count = 0;
	int32_t mask_reject_count = 0;
	int32_t accepted_count = 0;
	std::vector<int32_t> accepted_source_record_index_sample;
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

struct SharedSourceObjectResolverResult4af785 {
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

struct SharedRuntimeZoneSeedInput {
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
	SharedSourceZonePayload source_payload;
};

struct SharedRuntimeLinkInput {
	int32_t from_index = -1;
	int32_t to_index = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
};

struct SharedPlayerSlotAssignmentRecord {
	int32_t source_owner_index = -1;
	int32_t actual_player_color = -1;
	bool human = false;
};

struct SharedTemplateCandidateContainerRecord {
	int32_t vector_index = -1;
	int32_t source_catalog_index = -1;
	std::string template_name;
	int32_t zone_count = 0;
	int32_t link_count = 0;
};

struct SharedRuntimeChainInput {
	std::string input_source;
	bool recovered_template_selection_known = false;
	bool recovered_template_selection_blocked = false;
	bool recovered_setup_mode_known = false;
	bool recovered_setup_mode_randomized_sentinel_3 = false;
	int32_t recovered_setup_object_0x44 = 0;
	int32_t recovered_setup_rng_value = -1;
	int32_t recovered_setup_rng_call_count = 0;
	uint32_t recovered_setup_rng_state_before = 0;
	uint32_t recovered_template_rng_state_before = 0;
	int32_t recovered_generator_mode_0x10b8 = 0;
	int32_t recovered_template_size_score = 0;
	int32_t recovered_template_accepted_count = 0;
	int32_t recovered_template_selected_vector_index = -1;
	int32_t recovered_template_source_catalog_index = -1;
	std::string recovered_template_name;
	std::vector<SharedTemplateCandidateContainerRecord> recovered_candidate_containers_10d4_10d8;
	int32_t recovered_template_rng_value = -1;
	int32_t recovered_template_source_zone_record_count = 0;
	int32_t recovered_template_source_link_record_count = 0;
	bool recovered_template_player_assignment_complete = false;
	int32_t recovered_template_runtime_zone_seed_count = 0;
	int32_t recovered_template_runtime_link_count = 0;
	int32_t recovered_template_skipped_zone_filter_count = 0;
	int32_t recovered_template_skipped_link_filter_count = 0;
	int32_t recovered_template_missing_link_endpoint_count = 0;
	bool recovered_player_slot_assignment_known = false;
	int32_t recovered_player_slot_requested_human_count = 0;
	int32_t recovered_player_slot_requested_player_count = 0;
	int32_t recovered_player_slot_assigned_player_count = 0;
	std::vector<int32_t> recovered_selected_color_order_ed8;
	std::vector<int32_t> recovered_raw_source_owner_slots_ee0;
	std::vector<int32_t> recovered_mapped_source_owner_slots_ee4;
	std::vector<SharedPlayerSlotAssignmentRecord> recovered_player_slot_assignments;
	bool rng_state_after_template_selection_known = false;
	uint32_t rng_state_after_template_selection = 0;
	bool generator_mode_0x10b8_known = false;
	int32_t generator_mode_0x10b8 = 0;
	std::vector<SharedRuntimeZoneSeedInput> runtime_zone_seeds;
	std::vector<SharedRuntimeLinkInput> runtime_links;
};

struct CaseReport {
	ControlledCase input;
	std::string status;
	std::string blocked_reason;
	bool supported_scope = false;
	bool shared_chain_executed = false;
	std::string shared_chain_input_status;
	bool phase_snapshot_written = false;
	std::filesystem::path phase_snapshot_path;
	bool native_map_json_written = false;
	std::filesystem::path native_map_json_path;
};

struct TerrainVisualMissingBucketSample {
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

struct SharedGeneratedCellRecord0x30 {
	int32_t flat = -1;
	int32_t x = -1;
	int32_t y = -1;
	int32_t level = -1;
	int32_t stride_bytes = 0x30;
	bool object_reference_vector_fields_0x04_0x08_present = true;
	bool object_reference_vector_contents_known = false;
	int32_t object_reference_count = 0;
	bool word_0x10_known = false;
	uint32_t word_0x10 = 0U;
	bool word_0x14_known = false;
	uint32_t word_0x14 = 0U;
	bool word_0x18_known = false;
	uint32_t word_0x18 = 0U;
	bool word_0x1c_known = false;
	uint32_t word_0x1c = 0U;
	bool word_0x20_known = false;
	uint32_t word_0x20 = 0U;
	bool word_0x24_known = false;
	uint32_t word_0x24 = 0U;
	bool word_0x28_known = false;
	uint32_t word_0x28 = 0U;
	bool byte_0x2b_known = false;
	uint8_t byte_0x2b_known_mask = 0U;
	uint8_t byte_0x2b = 0U;
	bool word_0x2c_known = false;
	uint32_t word_0x2c = 0U;
};

struct SharedGeneratorObjectVectorState {
	std::string label;
	uint32_t begin_offset = 0U;
	uint32_t end_offset = 0U;
	uint32_t capacity_offset = 0U;
	bool present = false;
	bool contents_known = false;
	bool count_known = false;
	int32_t count = 0;
};

struct SharedGeneratorRelationRecordState {
	int32_t source_link_index = -1;
	int32_t owner_runtime_zone_index = -1;
	int32_t owner_source_zone_id = -1;
	int32_t target_runtime_zone_index = -1;
	int32_t target_source_zone_id = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
	bool reciprocal = false;
	uint32_t control_dword_0x08 = 0U;
};

struct SharedGeneratorRelationOwnerState {
	int32_t owner_vector_index = -1;
	int32_t runtime_zone_index = -1;
	int32_t source_zone_id = -1;
	int32_t source_index = -1;
	int32_t relation_record_count = 0;
	std::vector<SharedGeneratorRelationRecordState> relation_records;
};

struct SharedGeneratorObjectPrivateState {
	bool present = false;
	uint32_t generated_cell_buffer_offset_0x14 = 0x14U;
	uint32_t width_offset_0x18 = 0x18U;
	uint32_t height_offset_0x1c = 0x1cU;
	uint32_t level_count_offset_0x20 = 0x20U;
	bool generated_cell_buffer_owned = false;
	int32_t generated_cell_buffer_record_count = 0;
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	SharedGeneratorObjectVectorState endpoint_vector_c8_cc;
	SharedGeneratorObjectVectorState endpoint_vector_d8_dc;
	SharedGeneratorObjectVectorState object_record_vector_ec4_ecc;
	SharedGeneratorObjectVectorState source_pair_vector_edc;
	SharedGeneratorObjectVectorState pending_entry_vector_eec_ef0_ef4;
	SharedGeneratorObjectVectorState candidate_container_vector_10d4_10d8;
	SharedGeneratorObjectVectorState relation_vector_10e4_10e8;
	SharedGeneratorObjectVectorState endpoint_byte_state_vector_1104_1108;
	bool endpoint_cursor_0xf58_present = false;
	bool endpoint_cursor_0xf58_known = false;
	int32_t endpoint_cursor_0xf58 = 0;
	bool endpoint_cursor_0xf5c_present = false;
	bool endpoint_cursor_0xf5c_known = false;
	int32_t endpoint_cursor_0xf5c = 0;
	bool descriptor_counter_table_0x1110_present = false;
	bool descriptor_counter_table_0x1110_contents_known = false;
	int32_t descriptor_counter_table_0x1110_known_count = 0;
	int32_t descriptor_counter_table_0x1110_zero_count = 0;
	bool source_owner_player_slots_ed8_ee0_ee4_present = false;
	int32_t selected_color_order_ed8_count = 0;
	int32_t raw_source_owner_slots_ee0_count = 0;
	int32_t mapped_source_owner_slots_ee4_count = 0;
	bool relation_owner_records_10e4_10e8_partial_known = false;
	int32_t relation_owner_vector_count_10e4_10e8 = 0;
	int32_t relation_record_count_10e4_10e8 = 0;
	int32_t relation_record_missing_endpoint_count_10e4_10e8 = 0;
	std::vector<SharedGeneratorRelationOwnerState> relation_owner_vectors_10e4_10e8;
	std::vector<std::string> remaining_private_state_blockers;
};

struct RecoveredOwnerGridPayload {
	SharedRuntimeChainInput input;
	std::vector<std::string> missing_inputs;
	bool executable = false;
	bool built = false;
	bool coordinate_seed_blocked = false;
	bool owner_grid_executed = false;
	bool footprint_finalizer_executed = false;
	bool footprint_finalizer_blocked = false;
	std::string footprint_finalizer_status;
	bool source_blocked = false;
	bool generated_cell_private_state_comparable = false;
	std::string generated_cell_private_state_status;
	std::string terrain_selection_repaint_status;
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	int32_t coordinate_rng_call_count = 0;
	int32_t coordinate_generator_mode_0x10b8 = 0;
	int32_t coordinate_minimum_source_base_size = 0;
	int32_t coordinate_prune_divisor_4a218c = 0;
	int32_t coordinate_prune_span_budget_4a218c = 0;
	int32_t town_choice_rng_call_count_0x49b3c1 = 0;
	int32_t terrain_selection_rng_call_count_0x49b53d = 0;
	int32_t terrain_selection_match_to_town_count = 0;
	int32_t terrain_selection_allowed_flag_choice_count = 0;
	int32_t terrain_selection_no_eligible_default_zero_count = 0;
	int32_t terrain_repaint_write_count_0x4a4163 = 0;
	int32_t terrain_visual_write_count_0x4bb74b = 0;
	int32_t terrain_visual_missing_bucket_count_0x4bcfc3 = 0;
	int32_t terrain_visual_art_nonzero_cell_count = 0;
	int32_t terrain_visual_flag_cell_count = 0;
	int32_t terrain_visual_final_sweep_cell_count_0x4bbfcc = 0;
	int32_t terrain_visual_preserved_current_record_count_0x4bc5a3 = 0;
	int32_t terrain_visual_roundtrip_mismatch_count = 0;
	uint32_t coordinate_rng_state_before = 0;
	uint32_t coordinate_rng_state_after = 0;
	uint32_t terrain_selection_rng_state_after = 0;
	uint32_t terrain_visual_rng_state_after_0x4bb74b = 0;
	int32_t coordinate_placement_step_count = 0;
	int32_t coordinate_boundary_input_count = 0;
	int32_t source_descriptor_node_count = 0;
	int32_t source_descriptor_active_node_count = 0;
	int32_t source_node_walk_count = 0;
	int32_t source_handoff_count = 0;
	int32_t missing_boundary_input_count = 0;
	int32_t missing_source_walk_count = 0;
	int32_t materialization_source_handoff_count = 0;
	int32_t materialization_source_handoff_descriptor_indexed_point_count = 0;
	int32_t materialization_source_handoff_raw_coordinate_point_count = 0;
	int32_t materialization_source_record_seed_count = 0;
	int32_t materialization_missing_source_record_seed_count = 0;
	int32_t materialization_runtime_zone_walk_count = 0;
	int32_t materialization_appended_vertex_count = 0;
	int32_t materialization_span_fill_zone_count = 0;
	int32_t footprint_finalizer_original_same_level_runtime_zone_count = 0;
	int32_t footprint_finalizer_final_runtime_zone_count = 0;
	int32_t footprint_finalizer_appended_runtime_zone_count = 0;
	int32_t footprint_finalizer_zone_order_reset_call_count = 0;
	int32_t footprint_finalizer_per_zone_order_helper_call_count = 0;
	std::vector<std::string> missing_generated_cell_mutation_phases;
	std::vector<std::string> terrain_selection_parity_blockers;
	std::vector<std::string> terrain_repaint_parity_blockers;
	std::vector<TerrainVisualMissingBucketSample> terrain_visual_missing_bucket_samples_0x4bcfc3;
	bool generated_cell_record_shape_0x30_present = false;
	int32_t generated_cell_record_stride_bytes = 0x30;
	std::string generated_cell_record_surface_status;
	SharedGeneratorObjectPrivateState generator_object_private_state;
	std::vector<SharedGeneratedCellRecord0x30> generated_cell_records_0x30;
	std::vector<uint32_t> generated_cell_word_0x10;
	std::vector<uint32_t> generated_cell_word_0x1c;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
	bool source_object_catalog_0x49da08_present = false;
	int32_t source_object_catalog_0x49da08_record_count = 0;
	int32_t source_object_catalog_0x4c_copy_size_bytes = 0;
	int32_t source_object_catalog_objects_txt_record_count = 0;
	int32_t source_object_catalog_rand_trn_backed_record_count = 0;
	int32_t source_object_catalog_type53_record_count = 0;
	int32_t source_object_catalog_type53_ambiguous_subtype_count = 0;
	bool source_object_catalog_descriptor_only_mine_identity_ambiguous = false;
	std::vector<SharedSourceObjectRecord0x4c> source_object_catalog_samples;
	bool source_object_wrapper_buckets_0x49db76_present = false;
	int32_t source_object_wrapper_bucket_count_0xe8 = 0;
	int32_t source_object_wrapper_initialized_bucket_count = 0;
	int32_t source_object_wrapper_non_empty_bucket_count = 0;
	int32_t source_object_wrapper_total_source_record_references = 0;
	int32_t source_object_wrapper_out_of_range_source_record_count = 0;
	int32_t source_object_wrapper_max_bucket_record_count = 0;
	int32_t source_object_wrapper_max_bucket_index_0x08 = -1;
	std::vector<SharedSourceObjectWrapperBucket0xe8> source_object_wrapper_bucket_samples;
	std::vector<SharedSourceObjectSelectorResult4a9e40> source_object_selector_samples_0x4a9e40;
	std::vector<SharedSourceObjectResolverResult4af785> source_object_resolver_samples_0x4af785;
};

ControlledCase parse_controlled_case(const std::string &raw);
std::vector<std::string> split_case_filter(const std::string &case_filter);
bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters);
SharedRuntimeChainInput resolved_shared_runtime_chain_input(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input);
RecoveredOwnerGridPayload build_recovered_owner_grid_payload(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input);
std::string shared_runtime_chain_input_status(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input);
bool shared_runtime_chain_input_executable(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input);
std::string case_shared_h3maped_state_chain_blocked_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason, const SharedRuntimeChainInput &shared_input);
std::string safe_case_filename(const std::string &case_id);

} // namespace aurelion::rmg_native_core
