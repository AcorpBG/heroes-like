#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 1's battle port has the
// in-battle functions under the same namespace on its branch.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using state::State;
using state::Value;

// A list of spell ids, the empty ones dropped (spell_rules.cpp).
ArrayRef _normalize_spell_ids(State &state, const Value &value);


// A hero's mana at the start of a day (day_economy.cpp).
gd::DictRef refresh_daily_mana(State &state, gd::DictRef hero_state);

} // namespace aurelion::rules::port::spell_rules
