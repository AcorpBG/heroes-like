#pragma once

// scripts/core/AiHeroRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 3's AI targets port
// keeps its functions of this namespace in files of its own (ai_hero_rules_*).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::ai_hero_rules {

using state::State;
using state::Value;

// Whether an encounter is an AI hero: a Dictionary with an "ai_hero" block
// (ai_hero_rules.cpp).
bool is_ai_hero(State &state, const Value &entry);

// The AI heroes on the map, unresolved, of one controller or ("") all; each
// entry is the encounter itself (ai_hero_rules.cpp). The session is its view.
gd::ArrayRef active_hero_entries(State &state, gd::DictRef session, gd::Atom controller);
int64_t active_hero_count(State &state, gd::DictRef session, gd::Atom controller);
gd::DictRef _resolved_lookup(State &state, gd::DictRef session);

} // namespace aurelion::rules::port::ai_hero_rules
