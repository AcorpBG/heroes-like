#include "aurelion_rules/battle_hex.hpp"

#include <array>
#include <cstdlib>

namespace aurelion::rules::battle_hex {
namespace {

constexpr bool in_bounds(int64_t q, int64_t r) {
	return q >= 0 && q < kColumns && r >= 0 && r < kRows;
}

// BattleRules._hex_neighbors: the offsets for even and odd rows, in order.
constexpr int64_t kEvenOffsets[kMaxNeighbors][2] = { { 1, 0 }, { 0, -1 }, { -1, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } };
constexpr int64_t kOddOffsets[kMaxNeighbors][2] = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 1 } };

constexpr std::array<NeighborList, kCellCount> build_neighbor_table() {
	std::array<NeighborList, kCellCount> table{};
	for (int64_t q = 0; q < kColumns; ++q) {
		for (int64_t r = 0; r < kRows; ++r) {
			NeighborList &list = table[static_cast<size_t>(q * kRows + r)];
			list.count = 0;
			for (int64_t i = 0; i < kMaxNeighbors; ++i) {
				const int64_t next_q = q + (r % 2 == 0 ? kEvenOffsets[i][0] : kOddOffsets[i][0]);
				const int64_t next_r = r + (r % 2 == 0 ? kEvenOffsets[i][1] : kOddOffsets[i][1]);
				if (in_bounds(next_q, next_r)) {
					list.ids[list.count] = static_cast<int32_t>(next_q * kRows + next_r);
					list.count += 1;
				}
			}
		}
	}
	return table;
}

constexpr std::array<NeighborList, kCellCount> kNeighborTable = build_neighbor_table();

// Cube distance of two hexes on the same pair of rows (BattleFootprint.distance).
int64_t row_pair_distance(int64_t a_q, int64_t a_shift, int64_t b_q, int64_t b_shift, int64_t dz) {
	const int64_t dx = (a_q - a_shift) - (b_q - b_shift);
	return (std::llabs(dx) + std::llabs(dz) + std::llabs(dx + dz)) / 2;
}

} // namespace

const NeighborList *neighbor_table() {
	return kNeighborTable.data();
}

void fit_mask(const uint8_t *open, Body body, uint8_t *fit_out) {
	if (body.width != 2) {
		for (int64_t id = 0; id < kCellCount; ++id) {
			fit_out[id] = open[id];
		}
		return;
	}
	for (int64_t id = 0; id < kCellCount; ++id) {
		fit_out[id] = 0;
	}
	for (int64_t q = 0; q < kColumns; ++q) {
		const int64_t tail_q = q + body.tail_step;
		if (tail_q < 0 || tail_q >= kColumns) {
			continue;
		}
		for (int64_t r = 0; r < kRows; ++r) {
			if (open[q * kRows + r] == 1 && open[tail_q * kRows + r] == 1) {
				fit_out[q * kRows + r] = 1;
			}
		}
	}
}

int64_t body_distance(int64_t anchor_id, Body mover, PlacedBody target) {
	const int64_t a_q = anchor_id / kRows;
	const int64_t a_r = anchor_id % kRows;
	if (a_q < 0 || a_r < 0) {
		return kFarDistance;
	}
	const int64_t a_tail = mover.width == 2 ? a_q + mover.tail_step : a_q;
	const int64_t b_q = target.q;
	const int64_t b_r = target.r;
	if (b_q < 0 || b_r < 0) {
		return kFarDistance;
	}
	const int64_t b_tail = target.tail_q;
	// Both cells of a body share its row, so the row shift is shared too.
	const int64_t a_shift = (a_r - a_r % 2) / 2;
	const int64_t b_shift = (b_r - b_r % 2) / 2;
	const int64_t dz = a_r - b_r;
	int64_t nearest = row_pair_distance(a_q, a_shift, b_q, b_shift, dz);
	if (nearest > kFarDistance) {
		nearest = kFarDistance;
	}
	if (b_tail != b_q) {
		const int64_t d = row_pair_distance(a_q, a_shift, b_tail, b_shift, dz);
		nearest = d < nearest ? d : nearest;
	}
	if (a_tail != a_q) {
		const int64_t d = row_pair_distance(a_tail, a_shift, b_q, b_shift, dz);
		nearest = d < nearest ? d : nearest;
		if (b_tail != b_q) {
			const int64_t d_tails = row_pair_distance(a_tail, a_shift, b_tail, b_shift, dz);
			nearest = d_tails < nearest ? d_tails : nearest;
		}
	}
	return nearest;
}

std::vector<CellSteps> reachable(const uint8_t *open, Body body, int64_t start_id, int64_t max_steps) {
	std::vector<CellSteps> found;
	if (max_steps <= 0 || start_id < 0 || start_id >= kCellCount) {
		return found;
	}
	uint8_t fit[kCellCount];
	fit_mask(open, body, fit);
	int32_t steps_by_id[kCellCount];
	for (int64_t id = 0; id < kCellCount; ++id) {
		steps_by_id[id] = -1;
	}
	int32_t frontier[kCellCount];
	int64_t frontier_size = 0;
	steps_by_id[start_id] = 0;
	frontier[frontier_size++] = static_cast<int32_t>(start_id);
	found.reserve(kCellCount);
	for (int64_t index = 0; index < frontier_size; ++index) {
		const int32_t current_id = frontier[index];
		const int32_t steps = steps_by_id[current_id];
		if (steps >= max_steps) {
			continue;
		}
		const NeighborList &neighbors = kNeighborTable[static_cast<size_t>(current_id)];
		for (int32_t i = 0; i < neighbors.count; ++i) {
			const int32_t neighbor_id = neighbors.ids[i];
			if (steps_by_id[neighbor_id] >= 0 || fit[neighbor_id] == 0) {
				continue;
			}
			const int32_t next_steps = steps + 1;
			steps_by_id[neighbor_id] = next_steps;
			found.push_back({ neighbor_id, next_steps });
			frontier[frontier_size++] = neighbor_id;
		}
	}
	return found;
}

std::vector<CellSteps> walk_steps(const uint8_t *open, Body mover, PlacedBody target, int64_t gap) {
	uint8_t fit[kCellCount];
	fit_mask(open, mover, fit);
	int32_t steps_by_id[kCellCount];
	int32_t frontier[kCellCount];
	int64_t frontier_size = 0;
	for (int64_t id = 0; id < kCellCount; ++id) {
		steps_by_id[id] = -1;
	}
	for (int64_t id = 0; id < kCellCount; ++id) {
		if (fit[id] == 1 && body_distance(id, mover, target) == gap) {
			steps_by_id[id] = 0;
			frontier[frontier_size++] = static_cast<int32_t>(id);
		}
	}
	for (int64_t index = 0; index < frontier_size; ++index) {
		const int32_t current_id = frontier[index];
		const int32_t next_steps = steps_by_id[current_id] + 1;
		const NeighborList &neighbors = kNeighborTable[static_cast<size_t>(current_id)];
		for (int32_t i = 0; i < neighbors.count; ++i) {
			const int32_t neighbor_id = neighbors.ids[i];
			if (steps_by_id[neighbor_id] >= 0 || fit[neighbor_id] == 0) {
				continue;
			}
			steps_by_id[neighbor_id] = next_steps;
			frontier[frontier_size++] = neighbor_id;
		}
	}
	std::vector<CellSteps> steps;
	steps.reserve(static_cast<size_t>(frontier_size));
	for (int64_t index = 0; index < frontier_size; ++index) {
		steps.push_back({ frontier[index], steps_by_id[frontier[index]] });
	}
	return steps;
}

bool field_stays_open(const uint8_t *open) {
	const int64_t tail_steps[2] = { -1, 1 }; // player, enemy
	const int64_t start_columns[2] = { 1, kColumns - 2 };
	const int64_t goal_columns[2] = { kColumns - 1, 0 };
	for (int64_t side = 0; side < 2; ++side) {
		uint8_t fit[kCellCount];
		fit_mask(open, Body{ 2, tail_steps[side] }, fit);
		uint8_t seen[kCellCount] = {};
		int32_t frontier[kCellCount];
		int64_t frontier_size = 0;
		for (int64_t r = 0; r < kRows; ++r) {
			const int64_t start_id = start_columns[side] * kRows + r;
			if (fit[start_id] == 1) {
				frontier[frontier_size++] = static_cast<int32_t>(start_id);
				seen[start_id] = 1;
			}
		}
		bool crossed = false;
		for (int64_t index = 0; index < frontier_size; ++index) {
			const int32_t cell_id = frontier[index];
			if (cell_id / kRows == goal_columns[side]) {
				crossed = true;
				break;
			}
			const NeighborList &neighbors = kNeighborTable[static_cast<size_t>(cell_id)];
			for (int32_t i = 0; i < neighbors.count; ++i) {
				const int32_t neighbor_id = neighbors.ids[i];
				if (seen[neighbor_id] == 1 || fit[neighbor_id] == 0) {
					continue;
				}
				seen[neighbor_id] = 1;
				frontier[frontier_size++] = neighbor_id;
			}
		}
		if (!crossed) {
			return false;
		}
	}
	return true;
}

} // namespace aurelion::rules::battle_hex
