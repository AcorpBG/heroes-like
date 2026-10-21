#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 1's battle port has the
// in-battle functions under the same namespace on its branch.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A list of spell ids, the empty ones dropped (spell_rules.cpp).
ArrayRef _normalize_spell_ids(State &state, const Value &value);

// Shared with the battle port: a spell's school, tier and roles, its mana cost
// for a hero, and the hero's mana and known spells (spell_rules.cpp).
int64_t adjusted_spell_mana_cost(State &state, DictRef hero_state, const Value &spell);
Atom spell_school_id(State &state, DictRef spell);
int64_t spell_tier(State &state, DictRef spell);
Atom spell_primary_role(State &state, DictRef spell);
ArrayRef spell_role_categories(State &state, DictRef spell);
ArrayRef _normalize_string_array(State &state, const Value &value);
bool _has_mana(State &state, DictRef hero_state, int64_t cost);
bool _knows_spell(State &state, DictRef hero_state, Atom spell_id);

// A hero's mana at the start of a day (day_economy.cpp).
gd::DictRef refresh_daily_mana(State &state, gd::DictRef hero_state);

} // namespace aurelion::rules::port::spell_rules
