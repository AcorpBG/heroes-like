#pragma once

// scripts/core/AiHeroRules.gd, the functions the AI targets port moves
// (docs/native-rules-engine-transition.md, Phase 3), ported function by
// function under the GDScript names in core/port/ai_hero_rules_*.cpp. A
// session is its view (session_view.hpp); the script's static vars are read and
// set through the host (gd::static_var), so a memo the GDScript also keeps is
// one memo.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using state::State;
using state::Value;

// Knowledge: the explored tiles of a level, a bitset kept in the enemy state
// (ai_hero_rules_knowledge.cpp).
PackedRef _explored(State &state, DictRef session, DictRef context, int64_t level);

// The site-pass memo: [known site, walk-across family, persistent or
// repeatable] by site id, dropped when the content reloads
// (ai_hero_rules_knowledge.cpp).
void _sync_site_pass_memo(State &state);
ArrayRef _site_pass_class(State &state, Atom site_id);

} // namespace aurelion::rules::port::ai_hero_rules
