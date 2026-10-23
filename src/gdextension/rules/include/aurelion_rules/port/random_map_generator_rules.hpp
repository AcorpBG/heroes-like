#pragma once

// scripts/core/RandomMapGeneratorRules.gd: the player's random map config
// normalized, the template and profile chosen and the seats assigned
// (docs/native-rules-engine-transition.md, Phase 7, 7.11, owner decision D-g;
// random_map_generator_rules.cpp), ported function by function under the
// GDScript names. `template` is the GDScript parameters' name (template_
// here).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::random_map_generator_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

DictRef normalize_config(State &state, DictRef input_config);
DictRef _load_template_catalog(State &state);
DictRef _select_template_profile(State &state, DictRef input_config, DictRef size, DictRef player_constraints, Atom seed, DictRef input_profile);
bool _player_filter_allows_record(State &state, DictRef record, DictRef player_constraints);
ArrayRef _template_active_zones(State &state, DictRef template_, DictRef player_constraints);
ArrayRef _template_active_links(State &state, DictRef template_, DictRef player_constraints, ArrayRef zones);
DictRef _template_constraint_report(State &state, DictRef template_, DictRef size, DictRef player_constraints);
DictRef _template_start_capacity(State &state, ArrayRef zones);
ArrayRef _selection_rejection_reasons(State &state, Atom failure_code, Atom requested_template_id, Atom requested_profile_id, ArrayRef candidate_rejections);
int64_t _map_size_score(State &state, DictRef size);
int64_t _template_map_size_score(State &state, DictRef template_, DictRef size);
bool _water_mode_supported(State &state, Atom requested_water_mode, ArrayRef supported_water_modes);
Atom _normalize_water_mode(State &state, const Value &value);
int64_t _stable_choice_index(State &state, int64_t size, Atom seed_text);
DictRef _merge_profile_with_catalog(State &state, DictRef input_profile, DictRef catalog_profile, DictRef player_constraints);
DictRef _build_player_assignment(State &state, DictRef template_, DictRef profile, DictRef player_constraints, Atom seed);
ArrayRef _allowed_factions_for_owner_slot(State &state, DictRef template_, int64_t owner_slot);
ArrayRef _intersection_string_arrays(State &state, ArrayRef left, ArrayRef right);
ArrayRef _inactive_owner_slots(State &state, ArrayRef fixed_owner_slots, ArrayRef active_owner_slots);
DictRef _normalize_size(State &state, const Value &size_value);
DictRef _normalize_player_constraints(State &state, const Value &value);
DictRef _normalize_profile(State &state, const Value &value, DictRef player_constraints);
ArrayRef _normalized_string_array(State &state, const Value &value, ArrayRef fallback);
ArrayRef _sorted_keys(State &state, DictRef value);
ArrayRef _sorted_int_keys(State &state, DictRef value);
int64_t _positive_seed(State &state, Atom seed_text);
Atom _hash32_hex(State &state, Atom text);
int64_t _hash32_int(State &state, Atom text);
Atom _stable_stringify(State &state, const Value &value);

} // namespace aurelion::rules::port::random_map_generator_rules
