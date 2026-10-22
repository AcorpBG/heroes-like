#pragma once

// scripts/core/GeneratedRewardRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::generated_reward_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The transit subset of a random map object's translation by meaning
// (overworld_transit_normalize.cpp); resolve() of any other object throws
// state::NotPorted.
DictRef resolve(State &state, DictRef object, ArrayRef towns, ArrayRef terrain_rows);
bool is_skipped(State &state, DictRef object);
DictRef boat_tile(State &state, DictRef object);
Atom _gate_site(State &state, DictRef object, Atom key_text, ArrayRef terrain_rows);
DictRef _node(State &state, DictRef object, Atom site_id, Atom kind, DictRef payload, Atom resource_id = state::key::empty);
Atom _pick(State &state, ArrayRef options, Atom key_text, Atom salt);
int64_t _roll(State &state, Atom key_text, Atom salt, int64_t count);
int64_t _hash32(State &state, Atom text);

} // namespace aurelion::rules::port::generated_reward_rules
