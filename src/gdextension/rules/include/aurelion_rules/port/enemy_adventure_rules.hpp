#pragma once

// scripts/core/EnemyAdventureRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::enemy_adventure_rules {

using gd::Atom;
using state::State;
using state::Value;

// Whether a placement is resolved: resolved_encounters is the session's list,
// or a lookup Dictionary of it (enemy_adventure_rules.cpp).
bool _placement_resolved(State &state, Atom placement_id, const Value &resolved_encounters);

// A raid the player can see, and the unit strengths' memo kept current
// (overworld_forecast.cpp).
bool _raid_is_public(State &state, gd::DictRef session, gd::DictRef encounter);
void _sync_unit_strength_memo(State &state);


// An Array of Strings from a value (enemy_states.cpp).
gd::ArrayRef _normalize_string_array(State &state, const Value &value);

// The computer players' public event log, checked for hidden facts
// (day_boundary.cpp).
gd::ArrayRef ai_public_event_log(State &state, const Value &events_value, int64_t limit = 6);
gd::DictRef ai_public_event_log_entry(State &state, gd::DictRef event);
gd::DictRef ai_public_event_log_leak_check(State &state, const Value &public_surfaces);
Atom _public_reason_from_codes(State &state, gd::ArrayRef reason_codes);
Atom _public_event_log_text(State &state, Atom text);
Atom _ai_event_summary(State &state, Atom event_type, Atom faction_label, Atom actor_label, Atom target_label, Atom public_reason, Atom summary_prefix = state::key::empty);

} // namespace aurelion::rules::port::enemy_adventure_rules
