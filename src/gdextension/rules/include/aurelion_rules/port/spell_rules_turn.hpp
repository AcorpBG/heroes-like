#pragma once

// scripts/core/SpellRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in hero_rules_turn.cpp.
DictRef build_spellbook(State &state, DictRef hero_template);
DictRef learn_spell(State &state, DictRef hero_state, Atom spell_id);

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
DictRef mana_state(State &state, DictRef hero_state);

} // namespace aurelion::rules::port::spell_rules
