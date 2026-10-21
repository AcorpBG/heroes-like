// MineRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/mine_rules_ai.hpp"

#include "aurelion_rules/port/common_mine_rules.hpp"

namespace aurelion::rules::port {

namespace {

using gd::DictRef;
using state::State;

} // namespace

namespace mine_rules {

Vector2i entry_tile(State &state, DictRef node) {
	return common_mine_rules::entry_tile(state, node);
}

} // namespace mine_rules

} // namespace aurelion::rules::port
