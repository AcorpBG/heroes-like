#pragma once

// scripts/persistence/GeneratedNeutralEncounterRules.gd, ported function by
// function under the GDScript names (docs/native-rules-engine-transition.md,
// Phase 7, 7.11; generated_neutral_encounter_rules.cpp): a random map's
// monster guard as a neutral company the content can draw.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::generated_neutral_encounter_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

DictRef resolve(State &state, DictRef placement);
DictRef _pick_company(State &state, DictRef catalog, int64_t tier, Atom placement_id, int64_t quantity);
DictRef _company_families(State &state, DictRef catalog);
DictRef _apply_company(State &state, DictRef placement, DictRef company, double power);
bool _company_art_ready(State &state, Atom asset_id, Atom unit_id);
ArrayRef stacks_for_native_budget(State &state, ArrayRef native_stacks, ArrayRef unit_ids);
double _unit_power(State &state, Atom unit_id);
double _army_power(State &state, ArrayRef stacks);
DictRef resolve_supplemental(State &state, DictRef placement, Atom site_id);
int64_t _army_strength(State &state, DictRef army);
DictRef with_authored_guard_art(State &state, DictRef placement);
DictRef with_lead_unit_art(State &state, DictRef placement, Atom quantity_policy);
int64_t _unit_strength(State &state, Atom unit_id);
DictRef _apply_profile(State &state, DictRef placement, DictRef profile, int64_t quantity);
int64_t _stable_key(State &state, Atom value);

} // namespace aurelion::rules::port::generated_neutral_encounter_rules
