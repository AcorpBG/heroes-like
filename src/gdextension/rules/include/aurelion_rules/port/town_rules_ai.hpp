#pragma once

// scripts/core/TownRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in town_rules_ai.cpp.
Atom market_trade_mode(State &state, DictRef market, Atom give_id, Atom receive_id);
ArrayRef market_resource_ids(State &state, DictRef market);
DictRef market_conversion_rate(State &state, DictRef market, Atom give_id, Atom receive_id);
int64_t market_conversion_give_amount(State &state, DictRef rate, int64_t receive_amount);
DictRef market_trade_quote(State &state, DictRef market, DictRef usage, DictRef stock, Atom give_id, Atom receive_id, int64_t amount, bool with_text = true);
int64_t market_sale_gold(State &state, DictRef market, Atom give_id, int64_t count);

Atom _market_pair_reason(State &state, DictRef market, Atom give_id, Atom receive_id);
Atom _market_ratio_text(State &state, double value);
Atom _market_limit_reason(State &state, Atom action_type, Atom resource_id, DictRef cap, int64_t reset_day);
Atom _market_bulk_text(State &state, DictRef market, Atom action_type, Atom resource_id);
Atom _market_resource_title(State &state, Atom resource_id);
Atom _market_resource_name(State &state, Atom resource_id);
Atom _format_market_amount(State &state, int64_t value);

} // namespace aurelion::rules::port::town_rules
