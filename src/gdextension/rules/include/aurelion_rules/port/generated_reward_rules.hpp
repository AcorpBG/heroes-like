#pragma once

// scripts/persistence/GeneratedRewardRules.gd, ported function by function
// under the GDScript names (docs/native-rules-engine-transition.md, Phase 7,
// 7.11; generated_reward_rules.cpp): a random map object's translation by
// meaning into the runtime's sites, dwellings, banks and guards. Phase 5's
// transit subset (resolve, is_skipped, boat_tile and the helpers they reach)
// is part of it. `key` is the GDScript parameters' name (key_text here: `key`
// names the string keys).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::generated_reward_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

DictRef resolve(State &state, DictRef object, ArrayRef towns, ArrayRef terrain_rows);
DictRef _visit_building(State &state, DictRef object, Atom key_text, int64_t type_id);
bool is_skipped(State &state, DictRef object);
DictRef boat_tile(State &state, DictRef object);
Atom _gate_site(State &state, DictRef object, Atom key_text, ArrayRef terrain_rows);
DictRef _dwelling(State &state, DictRef object, Atom key_text, int64_t tier, Atom faction_id);
DictRef _dwelling_pools(State &state);
Atom _nearest_town_faction(State &state, DictRef object, ArrayRef towns);
int64_t _weighted_tier(State &state, Atom key_text);
ArrayRef _visit_fallback_sites(State &state);
Atom _tier_spell_id(State &state, Atom key_text, int64_t tier);
ArrayRef treasure_chest_choices(State &state, int64_t gold, int64_t experience);
Atom bank_key(State &state, int64_t type_id, int64_t subtype);
DictRef _creature_bank(State &state, DictRef object, Atom key_text, Atom bank_id);
int64_t bank_level_roll(State &state, Atom key_text, Atom bank_id);
ArrayRef native_guard_stacks(State &state, Atom key_text, Atom bank_id, int64_t level);
ArrayRef bank_guard_stacks(State &state, DictRef node);
DictRef _troops_for_native(State &state, ArrayRef native_stacks, DictRef units);
ArrayRef _rare_order(State &state, Atom key_text);
DictRef _warriors_tomb(State &state, DictRef object, Atom key_text);
DictRef _pandora(State &state, DictRef object, Atom key_text);
int64_t experience_for_h3m(State &state, int64_t amount);
ArrayRef _pandora_spell_ids(State &state, DictRef contents, Atom key_text);
Atom _neutral_unit_for_tier(State &state, Atom key_text, int64_t tier, int64_t index);
DictRef _pile(State &state, DictRef object, Atom key_text, Atom resource_id);
DictRef _node(State &state, DictRef object, Atom site_id, Atom kind, DictRef payload, Atom resource_id = state::key::empty);
Atom _random_resource_id(State &state, Atom key_text);
Atom _scroll_spell_id(State &state, Atom key_text);
Atom _pick(State &state, ArrayRef options, Atom key_text, Atom salt);
int64_t _roll_range(State &state, Atom key_text, Atom salt, int64_t low, int64_t high);
int64_t _roll(State &state, Atom key_text, Atom salt, int64_t count);
int64_t _hash32(State &state, Atom text);
Atom _thousands(State &state, int64_t value);

} // namespace aurelion::rules::port::generated_reward_rules
