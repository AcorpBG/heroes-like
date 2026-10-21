#pragma once

// scripts/core/OverworldRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp). Phase 5's ports of the script are in overworld_rules.hpp.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using state::State;
using state::Value;

// Read scopes, passability, the spatial lookup and guard engagement (overworld_rules_ai_lookup.cpp).
int64_t _collection_size(State &state, const Value &value);
Atom _town_content_read_scope_key(State &state, Atom kind, DictRef town, Atom extra = state::key::empty);
bool _town_read_scope_cache_has(State &state, Atom key);
bool terrain_id_is_passable(State &state, Atom terrain_id);
bool _terrain_id_is_passable_uncached(State &state, Atom terrain_id);
DictRef _spatial_lookup_index(State &state, DictRef session, int64_t level = -1);
ArrayRef _spatial_lookup_signature(State &state, DictRef session);
DictRef _build_spatial_lookup_index(State &state, DictRef session, int64_t level = 0);
ArrayRef _spatial_resource_section(State &state, DictRef session, ArrayRef resources, int64_t level);
ArrayRef _build_spatial_resource_section(State &state, ArrayRef resources, int64_t level);
void _append_spatial_lookup_entry(State &state, const Value &index_value, Atom key, int64_t entry_index);
DictRef _find_guard_engagement_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1, bool include_heroes = true);
bool _encounter_has_guard_engagement_surface(State &state, DictRef encounter);
ArrayRef hero_guard_zone_tiles(State &state, DictRef session, Vector2i tile, int64_t level);
bool _ai_hero_guards_against_player(State &state, DictRef session, DictRef encounter);
bool _town_entrance_at(State &state, DictRef session, Vector2i tile, int64_t level);
ArrayRef _guard_engagement_world_tiles(State &state, DictRef encounter);
ArrayRef _spatial_lookup_entries(State &state, DictRef index, Atom name, Vector2i tile);

// The town market and resource sets (overworld_rules_ai_market.cpp).
DictRef _apply_resource_percent_scale(State &state, const Value &resources, int64_t percent);
DictRef _town_market_state(State &state, DictRef town);
int64_t _market_rate_adjustment(State &state, DictRef adjustments, Atom resource_key);
double _market_value_scale(State &state, Atom resource_key);
DictRef _market_caps_for_profile(State &state, DictRef profile);
ArrayRef _market_bulk_resources(State &state, DictRef state_);
DictRef _empty_market_usage_bucket(State &state, int64_t default_value = 0);
DictRef _normalize_market_usage_bucket(State &state, const Value &value);
DictRef _normalize_town_market_usage_state(State &state, const Value &value, int64_t current_day = -1);
DictRef _market_cap_state_for_quote(State &state, DictRef town, DictRef state_, DictRef quote, int64_t current_day = -1);
int64_t _market_resource_abundance_score(State &state, const Value &faction_economy, const Value &town_economy, Atom resource_key);
DictRef _market_quote_from_state(State &state, DictRef state_, Atom action_type, Atom resource_key, int64_t amount);
ArrayRef _normalize_built_buildings_for_town_state(State &state, DictRef town);
DictRef _add_resource_sets(State &state, const Value &base, const Value &delta);
DictRef _normalize_resource_dict(State &state, const Value &value);
DictRef _empty_live_resource_stockpile(State &state);
int64_t _recruit_payload_total(State &state, const Value &value);

// Interaction tiles, build status, income and occupation (overworld_rules_ai_towns.cpp).
ArrayRef _resource_node_world_interaction_tiles(State &state, DictRef map_object, DictRef placement);
bool _resource_node_has_runtime_visit_tile(State &state, DictRef node);
int64_t _week_of_day(State &state, int64_t day);
DictRef town_income(State &state, DictRef town, const Value &session = Value());
DictRef town_market_state(State &state, DictRef town);
DictRef get_town_build_status(State &state, DictRef town, Atom building_id, int64_t current_day = -1);
DictRef _town_build_status(State &state, DictRef town, Atom building_id, int64_t current_day = -1);
DictRef _town_build_context(State &state, DictRef town);
DictRef _town_build_status_in(State &state, DictRef context, DictRef town, Atom building_id, int64_t current_day);
ArrayRef _missing_build_requirements_among(State &state, DictRef building, DictRef satisfied);
ArrayRef get_town_build_options(State &state, DictRef town, int64_t current_day = -1);
DictRef resource_site_blocking_guard(State &state, DictRef session, DictRef node, DictRef site, const Value &positions = Value());
DictRef _resource_site_guard_link_for_encounter(State &state, DictRef encounter);
DictRef _encounter_neutral_metadata(State &state, DictRef encounter);
ArrayRef _resource_site_spell_ids(State &state, DictRef site);
DictRef _calculate_town_income(State &state, DictRef town, const Value &session = Value());
DictRef _normalize_town_occupation_state(State &state, const Value &value);
DictRef _town_occupation_state(State &state, DictRef session, DictRef town);

// Town recruits seeding, economy income, building categories, read-scope caches (overworld_rules_ai_economy.cpp).
DictRef _seed_scenario_recruits_for_town_state(State &state, DictRef town);
Atom _town_read_scope_cache_key(State &state, DictRef session, Atom kind, DictRef town, Atom extra = state::key::empty);
Atom _read_scope_town_digest(State &state, DictRef town);
Value _town_read_scope_cache_get(State &state, Atom key);
void _town_read_scope_cache_store(State &state, Atom key, const Value &value);
DictRef _build_status_copy(State &state, DictRef status);
DictRef _seed_recruits_for_town(State &state, DictRef town);
void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail);
DictRef _economy_profile_income(State &state, const Value &profile, ArrayRef built_buildings);
DictRef _building_category_counts(State &state, ArrayRef built_buildings);
Atom _building_category(State &state, Atom building_id);
DictRef _multiply_cost(State &state, const Value &cost, int64_t multiplier);
DictRef resource_definition(State &state, Atom resource_id);

// Town logistics: the support plan, its state and its gaps (overworld_rules_ai_logistics.cpp).
DictRef _town_logistics_state(State &state, DictRef session, DictRef town);
DictRef _compute_town_logistics_state(State &state, DictRef session, DictRef town);
Atom _town_strategic_role(State &state, DictRef town);
Atom _town_controller_id(State &state, DictRef town);
DictRef _town_logistics_plan(State &state, DictRef town);
int64_t _default_logistics_support_radius(State &state, Atom role);
DictRef _default_logistics_requirements_for_role(State &state, Atom role);
DictRef _normalize_support_requirements(State &state, const Value &value);
DictRef _support_requirement_progress(State &state, const Value &family_counts, const Value &requirements);
DictRef _empty_town_logistics_state(State &state);
DictRef _town_logistics_gap_penalties(State &state, DictRef town, int64_t support_gap);

// Town recovery, occupation pressure and linked sites under threat (overworld_rules_ai_recovery.cpp).
DictRef _resource_node_linked_town(State &state, DictRef session, DictRef node, Atom controller_id);
DictRef _town_recovery_state(State &state, DictRef session, DictRef town, DictRef logistics_state);
DictRef _town_occupation_front_proxy(State &state, DictRef session, DictRef town, Atom faction_id);
int64_t _town_occupation_relief_per_day(State &state, DictRef session, DictRef town, DictRef logistics, DictRef recovery, DictRef front);
bool _resource_site_under_threat(State &state, DictRef session, DictRef node, Atom controller_id);
Atom _town_name(State &state, DictRef town);
Atom _town_faction_id(State &state, DictRef town);
Atom _town_pressure_label(State &state, DictRef town);

// Resource site response and delivery, town support and interaction tiles (overworld_rules_ai_sites.cpp).
ArrayRef _map_object_world_interaction_tiles(State &state, DictRef map_object, DictRef placement);
DictRef _resource_site_response_state(State &state, DictRef session, DictRef node, DictRef site);
DictRef _resource_site_delivery_state(State &state, DictRef session, DictRef node, DictRef _site);
Atom _resource_site_delivery_line(State &state, DictRef session, DictRef node, DictRef site);
DictRef _resource_site_town_support(State &state, DictRef site);
Atom _resource_site_family_short_label(State &state, Atom family_id);

} // namespace aurelion::rules::port::overworld_rules
