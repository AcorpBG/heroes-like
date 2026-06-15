#pragma once

#include <cstdint>
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
constexpr uint32_t RELATION_RESET_WORD_0X1C = 0x7d007d00U;
constexpr uint32_t RELATION_RESET_COORD_MINUS_ONE = 0xffffffffU;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_WORD_0X1C_HIGH = 0x7d00U;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_BITS_12_14 = 0U;
constexpr uint32_t RELATION_RESET_ARG_0X4A59E2_WORD_0X20_BYTE3 = 0xffffffffU;
constexpr uint32_t RELATION_WORD_0X28_BITS_12_14_MASK = 0x7U << 12U;

struct RelationResetCell {
	uint32_t word_0x10 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x14 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x18 = RELATION_RESET_COORD_MINUS_ONE;
	uint32_t word_0x1c = RELATION_RESET_WORD_0X1C;
	uint32_t word_0x20 = 0U;
	uint32_t word_0x28 = 0U;
};

int64_t cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level);

uint32_t generated_cell_word20_set_low_word(uint32_t word_0x20, uint32_t low_word);
uint32_t generated_cell_4a54a7_endpoint_word28(uint32_t word_0x28);
uint32_t generated_cell_4aa3e9_reward_word28(uint32_t word_0x28);
uint32_t generated_cell_49cf34_attach_word28(uint32_t word_0x28);
uint32_t generated_cell_4a56b6_projection_word20(uint32_t word_0x20, uint32_t lowered_low_word);
uint32_t generated_cell_terrain_flags_0x49acf6(int32_t flag_a, int32_t flag_b);
uint32_t generated_cell_4a59e2_pack_word_0x1c(uint32_t word_0x1c, uint32_t arg_word_0x1c_high);
uint32_t generated_cell_4a59e2_pack_word_0x20(uint32_t word_0x20, uint32_t arg_byte3);
uint32_t generated_cell_4a59e2_pack_word_0x28(uint32_t word_0x28, uint32_t arg_bits_12_14);
uint32_t generated_cell_4a5767_reset_force_word_0x1c(uint32_t word_0x1c_after_4a59e2);
uint32_t generated_cell_49a318_clear_source_word_0x1c(uint32_t word_0x1c);
RelationResetCell generated_cell_4a5767_reset_cell(uint32_t source_word_0x20, uint32_t source_word_0x28);

bool generated_cell_index_valid(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat);
bool generated_cell_49a1d8_valid_word24(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat);
bool generated_cell_49a1d8_valid_terrain(const std::vector<uint32_t> &word_0x28, const std::vector<int32_t> &terrain_code, int64_t flat);
bool generated_cell_49aa63(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_candidate);
bool generated_cell_49a932(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_occupied);
bool generated_cell_49abd6_action_stamp(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat);

int32_t deplete_generated_cell_scores_4a54a7(std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t level_count, int32_t anchor_x, int32_t anchor_y, int32_t anchor_level);

} // namespace aurelion::h3maped_rmg_core
