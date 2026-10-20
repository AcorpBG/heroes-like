#pragma once

// The battle board's walking searches, ported from BattleRules.gd (2026-10-20):
// _reachable_empty_hexes, _walk_steps_to_target, _obstacle_field_stays_open and
// the two-hex half of _hex_fit_mask. Integer only; no state, no allocation
// outside the returned vectors, safe on any thread.
//
// A hex id is q * kRows + r. An open mask has one byte per hex id: 1 where no
// blocker stands (BattleRules._hex_open_mask), 0 where one does.

#include <cstdint>
#include <vector>

namespace aurelion::rules::battle_hex {

constexpr int64_t kColumns = 11; // BattleRules.BATTLE_HEX_COLUMNS
constexpr int64_t kRows = 9; // BattleRules.BATTLE_HEX_ROWS
constexpr int64_t kCellCount = kColumns * kRows;
constexpr int64_t kMaxNeighbors = 6;
constexpr int64_t kFarDistance = 999; // BattleFootprint.distance with no hex

// The hexes a stack stands on: its anchor, and for a two-hex body a tail one
// column behind it (+1 for the enemy side, -1 for the player side).
struct Body {
	int64_t width = 1; // 1 or 2 (BattleFootprint.width)
	int64_t tail_step = -1; // +1 or -1; unused for width 1
};

// A placed body as BattleFootprint.distance reads it. q or r below 0 means no
// hex, which is kFarDistance from everything.
struct PlacedBody {
	int64_t q = -1;
	int64_t r = -1;
	int64_t tail_q = -1; // == q for a one-hex body
};

struct CellSteps {
	int32_t id;
	int32_t steps;
};

struct NeighborList {
	int32_t count;
	int32_t ids[kMaxNeighbors];
};

// Per hex id, the in-bounds neighbours in BattleRules._hex_neighbors order.
const NeighborList *neighbor_table();

// 1 where the body fits (anchor and tail open and on the board), else 0.
// For width 1 this is the open mask itself.
void fit_mask(const uint8_t *open, Body body, uint8_t *fit_out);

// BattleFootprint.distance(mover at anchor_id, target).
int64_t body_distance(int64_t anchor_id, Body mover, PlacedBody target);

// Every hex the body reaches from start_id within max_steps, in the order the
// breadth-first walk finds them, with its step count. The start is not listed.
std::vector<CellSteps> reachable(const uint8_t *open, Body body, int64_t start_id, int64_t max_steps);

// Walking steps from every hex the body can reach to the nearest hex gap hexes
// from target, in the walk's order (the start hexes first, by id).
std::vector<CellSteps> walk_steps(const uint8_t *open, Body mover, PlacedBody target, int64_t gap);

// Whether a two-hex body of either side can walk from its own edge to the other.
bool field_stays_open(const uint8_t *open);

} // namespace aurelion::rules::battle_hex
