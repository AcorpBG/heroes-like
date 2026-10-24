#pragma once

// The human seat's overworld spells (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.4), ported function by function under the GDScript names:
// casting a spell on the map, its action list, its target contract, preview
// and texts. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_spells.cpp.
DictRef cast_overworld_spell(State &state, DictRef session, Atom spell_id);
ArrayRef get_spell_actions(State &state, DictRef session);
int64_t _reveal_spell_fog(State &state, DictRef session, int64_t radius);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// spell_rules_overworld.cpp.
bool cast_overworld_spell_on_day(State &state, DictRef hero, int64_t day);
Atom spell_category_label(State &state, DictRef spell);
DictRef adventure_spell_target_contract(State &state, DictRef hero_state, DictRef movement_state, const Value &spell);
DictRef adventure_spell_consequence_preview(State &state, DictRef hero_state, DictRef movement_state, const Value &spell);
Atom _best_use_line(State &state, DictRef spell, DictRef context, DictRef active_stack, DictRef target_stack);
ArrayRef get_overworld_actions(State &state, DictRef hero_state, DictRef movement_state, int64_t today = 0);
DictRef cast_overworld_spell(State &state, DictRef hero_state, DictRef movement_state, Atom spell_id, int64_t today = 0);
DictRef validate_overworld_spell(State &state, DictRef hero_state, DictRef movement_state, const Value &spell, int64_t today = 0);
Atom effect_summary(State &state, DictRef stack, DictRef battle);
Atom battle_spell_timing_summary(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell);
Atom _overworld_spell_action_summary(State &state, DictRef hero_state, DictRef movement_state, DictRef spell, DictRef validation, int64_t mana_cost);
DictRef _movement_restore_preview(State &state, DictRef movement_state, DictRef spell, DictRef hero_state);
Atom _overworld_spell_effect_summary(State &state, DictRef spell, DictRef movement_state, DictRef hero_state);
Atom _overworld_target_requirement(State &state, DictRef spell);
Atom _target_mode_label(State &state, Atom target_mode);
DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id);
bool _has_ability(State &state, DictRef stack, Atom ability_id);
ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side);
bool _side_has_any_ability(State &state, DictRef battle, Atom side, ArrayRef ability_ids);

} // namespace aurelion::rules::port::spell_rules

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_spells.cpp.
int64_t spell_effect_amount_delta(State &state, DictRef hero_state, DictRef spell);

} // namespace aurelion::rules::port::artifact_rules
