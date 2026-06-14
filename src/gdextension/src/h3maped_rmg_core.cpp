#include "h3maped_rmg_core.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <queue>
#include <vector>

namespace aurelion::h3maped_rmg_core {
namespace {

struct Coord {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct ScoreFrontierNode {
	int32_t score = 0;
	Coord coord;
};

struct ScoreFrontierCompare {
	bool operator()(const ScoreFrontierNode &left, const ScoreFrontierNode &right) const {
		return left.score > right.score;
	}
};

constexpr std::array<std::array<int32_t, 2>, 8> DIRECTION_TABLE_0X5A2658 = { {
	{ 1, 0 },
	{ 1, 1 },
	{ 0, 1 },
	{ -1, 1 },
	{ -1, 0 },
	{ -1, -1 },
	{ 0, -1 },
	{ 1, -1 },
} };

} // namespace

int64_t cell_index(int32_t width, int32_t height, int32_t x, int32_t y, int32_t level) {
	if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height || level < 0) {
		return -1;
	}
	return int64_t(level) * int64_t(width) * int64_t(height) + int64_t(y) * int64_t(width) + int64_t(x);
}

uint32_t generated_cell_word20_set_low_word(uint32_t word_0x20, uint32_t low_word) {
	return (word_0x20 & 0xffff0000U) | (low_word & 0x0000ffffU);
}

uint32_t generated_cell_4a54a7_endpoint_word28(uint32_t word_0x28) {
	return word_0x28 | CELL_ACTION_CONTROL_BIT_22 | CELL_OCCUPIED_BLOCKED_BIT_27;
}

uint32_t generated_cell_4aa3e9_reward_word28(uint32_t word_0x28) {
	return word_0x28 & ~CELL_DECOR_READY_BIT_25;
}

uint32_t generated_cell_49cf34_attach_word28(uint32_t word_0x28) {
	return (word_0x28 | CELL_OCCUPIED_BLOCKED_BIT_27) & ~CELL_DECOR_CANDIDATE_BIT_26;
}

uint32_t generated_cell_4a56b6_projection_word20(uint32_t word_0x20, uint32_t lowered_low_word) {
	return generated_cell_word20_set_low_word(word_0x20, lowered_low_word);
}

uint32_t generated_cell_terrain_flags_0x49acf6(int32_t flag_a, int32_t flag_b) {
	return (((uint32_t(flag_a) & 0x01U) | ((uint32_t(flag_b) & 0x01U) << 1U)) << CELL_TERRAIN_FLAG_SHIFT_0X49ACF6);
}

bool generated_cell_index_valid(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	return flat >= 0
			&& flat < int64_t(word_0x28.size())
			&& flat < int64_t(word_0x24.size());
}

bool generated_cell_49a1d8_valid_word24(const std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x24, int64_t flat) {
	if (!generated_cell_index_valid(word_0x28, word_0x24, flat)) {
		return false;
	}
	return (word_0x28[size_t(flat)] & CELL_DECOR_READY_BIT_25) != 0U
			&& (word_0x24[size_t(flat)] & 0x3fU) != 9U;
}

bool generated_cell_49a1d8_valid_terrain(const std::vector<uint32_t> &word_0x28, const std::vector<int32_t> &terrain_code, int64_t flat) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(terrain_code.size())) {
		return false;
	}
	return (word_0x28[size_t(flat)] & CELL_DECOR_READY_BIT_25) != 0U
			&& (terrain_code[size_t(flat)] & 0x3f) != 9;
}

bool generated_cell_49aa63(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_candidate) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & CELL_DECOR_CANDIDATE_BIT_26) != 0U;
	if (set_candidate) {
		word_0x28[size_t(flat)] |= CELL_DECOR_CANDIDATE_BIT_26;
		word_0x28[size_t(flat)] &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~CELL_DECOR_CANDIDATE_BIT_26;
	return was_set;
}

bool generated_cell_49a932(std::vector<uint32_t> &word_0x28, const std::vector<uint32_t> &word_0x2c, int64_t flat, bool set_occupied) {
	if (flat < 0 || flat >= int64_t(word_0x28.size()) || flat >= int64_t(word_0x2c.size())) {
		return false;
	}
	if ((word_0x2c[size_t(flat)] & 0x1U) != 0U) {
		return false;
	}
	const bool was_set = (word_0x28[size_t(flat)] & CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
	if (set_occupied) {
		word_0x28[size_t(flat)] |= CELL_OCCUPIED_BLOCKED_BIT_27;
		word_0x28[size_t(flat)] &= ~CELL_DECOR_CANDIDATE_BIT_26;
		return !was_set;
	}
	word_0x28[size_t(flat)] &= ~CELL_OCCUPIED_BLOCKED_BIT_27;
	return was_set;
}

int32_t deplete_generated_cell_scores_4a54a7(std::vector<uint32_t> &generated_cell_word_0x20, int32_t width, int32_t height, int32_t level_count, int32_t anchor_x, int32_t anchor_y, int32_t anchor_level) {
	if (width <= 0 || height <= 0 || level_count <= 0 || anchor_level < 0 || anchor_level >= level_count || generated_cell_word_0x20.empty()) {
		return 0;
	}
	const int64_t anchor_flat = cell_index(width, height, anchor_x, anchor_y, anchor_level);
	if (anchor_flat < 0 || anchor_flat >= int64_t(generated_cell_word_0x20.size())) {
		return 0;
	}

	int32_t mutation_count = 0;
	if ((generated_cell_word_0x20[size_t(anchor_flat)] & 0xffffU) != 0U) {
		mutation_count += 1;
	}
	generated_cell_word_0x20[size_t(anchor_flat)] &= 0xffff0000U;

	std::priority_queue<ScoreFrontierNode, std::vector<ScoreFrontierNode>, ScoreFrontierCompare> frontier;
	frontier.push(ScoreFrontierNode { 0, Coord { anchor_x, anchor_y, anchor_level } });
	while (!frontier.empty()) {
		const ScoreFrontierNode node = frontier.top();
		frontier.pop();
		const Coord current = node.coord;
		const int64_t current_flat = cell_index(width, height, current.x, current.y, current.level);
		if (current_flat < 0 || current_flat >= int64_t(generated_cell_word_0x20.size())) {
			continue;
		}
		const int32_t base_score = int32_t(generated_cell_word_0x20[size_t(current_flat)] & 0xffffU);
		if (node.score != base_score) {
			continue;
		}
		for (int32_t direction_index = 0; direction_index < int32_t(DIRECTION_TABLE_0X5A2658.size()); ++direction_index) {
			const int32_t next_x = current.x + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][0];
			const int32_t next_y = current.y + DIRECTION_TABLE_0X5A2658[size_t(direction_index)][1];
			const int64_t next_flat = cell_index(width, height, next_x, next_y, current.level);
			if (next_flat < 0 || next_flat >= int64_t(generated_cell_word_0x20.size())) {
				continue;
			}
			const int32_t candidate_score = base_score + ((direction_index & 1) != 0 ? 3 : 2);
			const uint32_t next_word = generated_cell_word_0x20[size_t(next_flat)];
			const int32_t current_score = int32_t(next_word & 0xffffU);
			if (candidate_score >= current_score || candidate_score > 0xffff) {
				continue;
			}
			generated_cell_word_0x20[size_t(next_flat)] = (next_word & 0xffff0000U) | uint32_t(candidate_score);
			frontier.push(ScoreFrontierNode { candidate_score, Coord { next_x, next_y, current.level } });
			mutation_count += 1;
		}
	}
	return mutation_count;
}

} // namespace aurelion::h3maped_rmg_core
