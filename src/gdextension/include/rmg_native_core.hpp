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
};

struct SharedRuntimeLinkInput {
	int32_t from_index = -1;
	int32_t to_index = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
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
	int32_t recovered_template_rng_value = -1;
	int32_t recovered_template_source_zone_record_count = 0;
	int32_t recovered_template_source_link_record_count = 0;
	bool recovered_template_player_assignment_complete = false;
	int32_t recovered_template_runtime_zone_seed_count = 0;
	int32_t recovered_template_runtime_link_count = 0;
	int32_t recovered_template_skipped_zone_filter_count = 0;
	int32_t recovered_template_skipped_link_filter_count = 0;
	int32_t recovered_template_missing_link_endpoint_count = 0;
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
	std::vector<std::string> missing_terrain_selection_inputs;
	std::vector<std::string> missing_terrain_repaint_inputs;
	std::vector<TerrainVisualMissingBucketSample> terrain_visual_missing_bucket_samples_0x4bcfc3;
	std::vector<uint32_t> generated_cell_word_0x10;
	std::vector<uint32_t> generated_cell_word_0x1c;
	std::vector<uint32_t> generated_cell_word_0x20;
	std::vector<uint32_t> generated_cell_word_0x24;
	std::vector<uint32_t> generated_cell_word_0x28;
	std::vector<uint32_t> generated_cell_word_0x2c;
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
