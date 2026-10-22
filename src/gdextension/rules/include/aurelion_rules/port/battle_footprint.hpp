#pragma once

// scripts/core/BattleFootprint.gd, ported function by function. An anchor of
// Nil is the GDScript default `{}`.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::battle_footprint {

using gd::ArrayRef;
using gd::DictRef;
using state::State;
using state::Value;

int64_t width(const State &state, DictRef stack);
ArrayRef cells(State &state, DictRef stack, const Value &anchor);
bool fits(State &state, DictRef stack, const Value &anchor, DictRef occupied, int64_t columns, int64_t rows);
// placed_columns() as its three ints: anchor q, r and tail q.
void placed_columns(const State &state, DictRef stack, int64_t &q, int64_t &r, int64_t &tail);
ArrayRef placed_columns(State &state, DictRef stack);
int64_t distance(const State &state, DictRef lhs, DictRef rhs, const Value &lhs_anchor);

} // namespace aurelion::rules::port::battle_footprint
