#pragma once

// scripts/core/AiHeroRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// The best candidate and its kinds (ai_hero_rules_candidates.cpp).
void _profile_add(State &state, DictRef context, Atom key, int64_t started);
DictRef _best_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, int64_t reach = -1, bool far_kinds = false);
bool _zone_guarded(State &state, ArrayRef refs);
bool _guards_tile(State &state, DictRef ref);
bool _in_hero_zone(State &state, DictRef search, int64_t tile_index);
DictRef _exploration_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
DictRef _candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef ref, double power, DictRef needs, DictRef search, int64_t tile_index = -1);
double _hero_war_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef needs, Atom ref_kind, int64_t index);
DictRef _meet_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t other_index);

// The main army, defense and threats (ai_hero_rules_defense.cpp).
ArrayRef _field_hero_ids(State &state, DictRef session, Atom controller);
// Gives the field roles out for the day, before the heroes move.
void _assign_field_heroes(State &state, DictRef session, Atom controller);
ArrayRef _decision_field_ids(State &state, DictRef session, DictRef context);
double _main_shortfall(State &state, DictRef session, DictRef context, DictRef main);
int64_t _towns_held_by(State &state, DictRef session, Atom owner, Atom controller);
double _last_stand_share(State &state, DictRef session, Atom owner, Atom controller);
double _burst_share(State &state, DictRef entry, const Value &commander);
double _spell_burst(State &state, DictRef commander);
Atom _main_hero_id(State &state, DictRef session, Atom controller);
int64_t _weakest_stack_index(State &state, ArrayRef stacks);
bool _town_threatened(State &state, DictRef session, DictRef context, DictRef town);
DictRef _strongest_threat(State &state, DictRef session, DictRef context, DictRef town);
bool _would_hold_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, bool is_main);
DictRef _leave_defense(State &state, DictRef session, DictRef context, DictRef town, ArrayRef stacks, ArrayRef garrison, bool is_main);
double _unit_power(State &state, DictRef stack);
double _town_defense_need(State &state, DictRef session, DictRef context, DictRef town);
double _townless_raider(State &state, DictRef session, DictRef context);
double _town_worth(State &state, DictRef session, DictRef context, DictRef town);
double _threatened_town_share(State &state, DictRef session, DictRef context, DictRef other);
Atom _decision_main_id(State &state, DictRef session, DictRef context);

// Hero entries, guards, recruits and the market (ai_hero_rules_entries.cpp;
// active_hero_entries and _resolved_lookup are in ai_hero_rules.cpp).
int64_t _entry_index(State &state, DictRef session, Atom placement_id);
int64_t _movement_max(State &state, DictRef entry);
bool _resource_guarded(State &state, DictRef session, DictRef node, DictRef site);
DictRef _artifact_guard(State &state, DictRef session, DictRef node);
DictRef _encounter_guard_index(State &state, DictRef session);
void _add_guard_position(State &state, DictRef lookup, Atom key, int64_t position);
ArrayRef _guard_positions(State &state, ArrayRef lists);
DictRef _trial_growth(State &state, DictRef town);
DictRef _recruit_dict(State &state, const Value &value);
double _recruit_set_value(State &state, DictRef recruits);
double _build_value(State &state, DictRef payload);
bool _market_cover(State &state, DictRef session, DictRef town, DictRef pool, DictRef cost, bool apply, const Value &market_memo = Value());
bool _market_trade(State &state, DictRef quote, DictRef stock, DictRef usage);
int64_t _town_hero_defender_index(State &state, DictRef session, DictRef town, Atom controller);
// The town whose entry a hero (kind hero: player_heroes[index]; ai_hero:
// encounters[index]) holds for its own side, or -1.
int64_t _entry_town_index(State &state, DictRef session, Atom kind, int64_t hero_index);
bool _town_entrance_free(State &state, DictRef session, DictRef town, Atom own_controller = state::key::empty);
DictRef _garrison_pickup(State &state, ArrayRef stacks, ArrayRef garrison);
bool _ferries_from(State &state, DictRef session, DictRef context, DictRef town, Atom main_id);

// The explored tiles and the site-pass memo (ai_hero_rules_knowledge.cpp).
PackedRef _explored(State &state, DictRef session, DictRef context, int64_t level);
void _sync_site_pass_memo(State &state);
ArrayRef _site_pass_class(State &state, Atom site_id);

// Army power, needs and stacks (ai_hero_rules_power.cpp).
void _note_alternative(State &state, DictRef context, DictRef candidate, double score, int64_t distance);
DictRef _neutral_army(State &state, DictRef encounter);
double army_power(State &state, const Value &stacks, const Value &commander);
double _spell_damage_per_round(State &state, DictRef commander);
ArrayRef _unit_power_figures(State &state, Atom unit_id);
ArrayRef _damage_spell_figures(State &state, Atom spell_id);
void _sync_power_memos(State &state);
double hero_power(State &state, DictRef entry);
DictRef _resource_needs(State &state, DictRef session, DictRef context);
double _payload_value(State &state, const Value &payload, DictRef needs);
DictRef _merge_stacks_into(State &state, const Value &destination, const Value &additions);
bool _can_afford(State &state, DictRef pool, DictRef cost);

// Level regions, stretches and dangers (ai_hero_rules_regions.cpp).
DictRef _level_regions(State &state, DictRef session, DictRef context, int64_t level);
PackedRef _level_stretches(State &state, DictRef session, DictRef context, int64_t level, double power, double loss_limit, DictRef entry);
int64_t _patch_root(State &state, ArrayRef parent, int64_t patch);
Atom _stretch_key(State &state, DictRef session, DictRef context, int64_t level, int64_t tile, double power, double loss_limit, DictRef entry);
DictRef _avoided_today(State &state, DictRef session, DictRef entry);
DictRef _beyond_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef gate, int64_t movement_max, int64_t radius);
Atom _beyond_key(State &state, DictRef entry, DictRef gate, int64_t radius);
PackedRef _gate_far_dist(State &state, DictRef context, DictRef entry, DictRef gate, int64_t radius);
ArrayRef _dangers(State &state, DictRef session, DictRef context, DictRef entry);
bool _deters(State &state, DictRef session, DictRef entry, DictRef town, ArrayRef dangers);
bool _in_danger(State &state, ArrayRef dangers, int64_t x, int64_t y, int64_t level);
DictRef _own_town_doors(State &state, DictRef session, Atom controller, int64_t level, Vector2i size);

// Gates and the routes past them (ai_hero_rules_routes.cpp).
bool _plans_far(State &state, DictRef session, DictRef context, DictRef entry);
// any_errand: the last way out when nothing on the level is worth doing, open
// also in the days after a crossing.
DictRef _gate_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, int64_t beyond_radius, bool any_errand = false);
DictRef _gate_routes(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max);
double _route_loss_limit(State &state, double value);
void _route_through(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, DictRef map, double power, double limit, ArrayRef towns, bool explore, DictRef result);
bool _route_gate_open(State &state, DictRef gate, double power, double limit);
DictRef _route_map(State &state, DictRef session, DictRef context);
ArrayRef _route_towns(State &state, DictRef session, DictRef context, DictRef entry, double power, DictRef map);
void _route_unseen(State &state, DictRef session, DictRef context, DictRef entry, DictRef map, double power, double limit, Atom home_key, DictRef targets);
double _tile_span(State &state, int64_t from_tile, int64_t to_tile, Vector2i size);

// The search and its tables (ai_hero_rules_search.cpp).
void _add_stop(State &state, DictRef stops, Vector2i tile, Vector2i size, DictRef ref);
DictRef _search_tables(State &state, DictRef surface, DictRef resolved);
DictRef _search(State &state, DictRef session, DictRef context, DictRef entry, int64_t radius, bool past_own_heroes = false);
double _boat_price(State &state, DictRef session, DictRef context, DictRef search, int64_t tile_index);
int64_t _tile_index_of(State &state, DictRef point, Vector2i size);
PackedRef _step_offsets(State &state, int64_t width);
void _add_stop_index(State &state, DictRef stops, int64_t tile_index, DictRef ref);
ArrayRef _path_to(State &state, DictRef search, int64_t tile_index);

// Exploring, hunting, rival towns and sight (ai_hero_rules_sight.cpp).
double _explore_value(State &state, DictRef session, DictRef context);
double _hunt_value(State &state, DictRef session, DictRef context);
// What a chart of a whole level is worth: unseen ground by the share of the
// level's open ground still unseen.
double _chart_value(State &state, DictRef session, DictRef context, int64_t level);
bool _rival_towns_unknown(State &state, DictRef session, DictRef context);
DictRef _town_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power);
// What a hero beats with `after` strength and not with `before`: the best rival
// or neutral town it knows, or rival hero in sight, on the level of `place`
// within twelve days of it, less the expected losses, per day of travel from
// there. A garrison that turns a small army into one that takes towns is worth
// what it lets the army take.
double _newly_beatable_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef place, double before, double after);
bool _position_seen(State &state, DictRef session, DictRef context, DictRef position);
DictRef _sight_context(State &state, Atom controller);
ArrayRef _hostile_heroes(State &state, DictRef session, Atom controller);
bool _far_ahead(State &state, DictRef session, DictRef context);
bool _town_seen(State &state, PackedRef known, DictRef town, Vector2i size);

// The level surface, hero zones and site stops (ai_hero_rules_surface.cpp).
DictRef _boat_market(State &state, DictRef session, DictRef context, DictRef cost);
ArrayRef _hero_guards(State &state, DictRef session, DictRef context, int64_t level);
ArrayRef _hero_zone_tiles(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level);
DictRef _level_surface(State &state, DictRef session, DictRef context, int64_t level);
ArrayRef _open_guard_zones(State &state, DictRef surface);
PackedRef _portal_exits(State &state, DictRef portal, PackedRef seen_map);
bool _portal_leads_unseen(State &state, DictRef session, DictRef context, DictRef portal, PackedRef seen_map);
bool _site_stop_passable(State &state, DictRef session, Atom controller, DictRef ref, ArrayRef nodes, ArrayRef artifacts, DictRef allies);
PackedRef _decision_site_pass(State &state, DictRef context, int64_t level, ArrayRef sites);

// What sites, guards and doors are worth (ai_hero_rules_values.cpp).
DictRef _resource_candidate(State &state, DictRef session, DictRef context, Atom controller, DictRef entry, int64_t index, double power, DictRef needs, DictRef treasury, double opens = 0.0);
bool _can_hire_any(State &state, DictRef session, DictRef node, DictRef site, DictRef treasury);
DictRef _encounter_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power, DictRef needs, DictRef search);
double _guard_fight_value(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power, DictRef needs, DictRef search);
double _guard_power(State &state, DictRef guard);
double _expected_loss_value(State &state, double power, double enemy_power);
double _guarded_object_value(State &state, DictRef session, DictRef guard, DictRef needs, DictRef search, int64_t guard_index = -1, Atom controller = state::key::empty);
double _guarded_node_value(State &state, DictRef session, DictRef node, DictRef needs, Atom controller);
double _site_spell_value(State &state, DictRef site, DictRef entry);
double _site_artifact_value(State &state, DictRef site);
double _passage_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t guard_index, DictRef needs);
double _site_door_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t tile_index, DictRef needs);
int64_t _site_door_key(State &state, int64_t tile_index);
int64_t _hero_war_key(State &state, Atom ref_kind, int64_t index);
DictRef _site_doors(State &state, DictRef search);

// Opened ground and war paths (ai_hero_rules_war.cpp).
double _opened_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t key, ArrayRef origin, DictRef needs);
DictRef _war_paths(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef needs);

// A player's hero in sight (ai_hero_rules_sight.cpp).
bool _player_hero_seen(State &state, DictRef session, DictRef context, DictRef hero);

// The army power terms from content (ai_hero_rules_power.cpp).
void _apply_power_terms(State &state);

} // namespace aurelion::rules::port::ai_hero_rules
