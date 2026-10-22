#pragma once

// scripts/core/EnemyAdventureRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::enemy_adventure_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
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

// Phase 4's ports shared with Phase 5's battle ends (enemy_adventure_rules_shared.cpp).
Atom _ai_hero_task_actor_id_from_raid(State &state, DictRef raid);
void _ai_hero_task_finish_live_assignment(State &state, DictRef session, Atom faction_id, DictRef raid, Atom task_status, Atom validation);
DictRef _award_enemy_commander_experience(State &state, DictRef commander_state, int64_t amount);
Atom _commander_memory_target_kind_for_outcome(State &state, Atom outcome_id, DictRef memory);
Atom _commander_name_from_source(State &state, const Value &source);
DictRef _record_commander_adaptive_task_memory(State &state, DictRef commander_state, Atom outcome_id);
DictRef _with_runtime_spellbook_state(State &state, DictRef base_state, const Value &runtime_state);
DictRef advance_commander_record(State &state, DictRef commander_state, Atom outcome_id);
Atom commander_display_name(State &state, const Value &source, bool include_veterancy = true);
DictRef commander_live_role_state(State &state, const Value &source);
DictRef commander_target_memory(State &state, const Value &source);
void sync_commander_state_to_roster(State &state, DictRef session, Atom faction_id, const Value &commander_state, Atom status_override = state::key::empty, Atom active_placement_id = state::key::empty, int64_t recovery_day = -1, Atom last_outcome = state::key::empty);

// Not ported yet: each throws state::NotPorted (phase4_shared_stubs.cpp) until Phase 5's
// slice 09 ports it.
ArrayRef _ai_hero_task_prune_live_tasks(State &state, ArrayRef tasks, int64_t day);

} // namespace aurelion::rules::port::enemy_adventure_rules
