#pragma once

// scripts/core/BattleActionPlayback.gd, ported under the GDScript names
// (docs/native-rules-engine-transition.md, Phase 1, slice 10): capture, the
// render snapshot of one event of a presented action. begin and finish stay
// GDScript (perform_presented_action calls them).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::battle_action_playback {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

void capture(State &state, DictRef battle, DictRef event);

} // namespace aurelion::rules::port::battle_action_playback
