// AiHeroRules: one computer hero's day: the plan it chooses (Phase 3's native
// candidate scoring under it), the walk that follows and what it does on arrival.

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_spells.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include <cstdint>
#include <limits>
#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

constexpr int64_t kStopResource = 1;
constexpr int64_t kStopArtifact = 2;
constexpr int64_t kStopTown = 3;
constexpr int64_t kStopEncounter = 4;
constexpr int64_t kStopHero = 5;
constexpr int64_t kStopAiHero = 6;
constexpr int64_t kDecisionLogAlternatives = 3;

int64_t tunable_int(State &state, Atom name) {
	return ai::static_int(state, key::ai_hero_rules_script, name);
}

double tunable_float(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

[[noreturn]] void no_get(const Value &value) {
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(value) + "'.");
}

// var v: Vector2i = value
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return {value.vx(), value.vy()};
}

// var size: Vector2i = context.map_size
Vector2i context_size(const State &state, DictRef context) {
	return as_vector2i(gd::index(state, context, str(key::map_size)));
}

// String(context.controller)
Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

// session.flags
DictRef session_flags(const State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::flags)));
}

// session.overworld.<field>[index], untyped and as a Dictionary.
Value overworld_item(const State &state, DictRef session, Atom field, int64_t index) {
	const Value list = gd::index(state, session_view::overworld(state, session), str(field));
	return ai::vindex(state, list, int_value(index));
}

DictRef overworld_dict(const State &state, DictRef session, Atom field, int64_t index) {
	return gd::as_dict(overworld_item(state, session, field, index));
}

// var d: Dictionary = dict.get(field, {}) that is written or stored.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}, only read: true
// with the Dictionary in out, false for the empty one.
bool dict_field(const State &state, DictRef dict, Atom field, Value &out) {
	return state.lookup(dict, str(field), out) && gd::is_dict(out);
}

// d.get(outer, {}).get(inner, ...) without making the {}: false when either key
// is missing.
bool nested_lookup(const State &state, DictRef dict, Atom outer, Atom inner, Value &out) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return false;
	}
	if (!gd::is_dict(found)) {
		no_get(found);
	}
	return state.lookup(found.ref, str(inner), out);
}

// var movement: Dictionary = entry.get(AI_HERO_KEY, {}).get("movement", {}),
// then int(movement.get(field, fallback)).
int64_t movement_int(const State &state, DictRef entry, Atom field, int64_t fallback) {
	Value movement;
	if (!nested_lookup(state, entry, key::ai_hero, key::movement, movement)) {
		return fallback;
	}
	return gd::int_field(state, gd::as_dict(movement), field, fallback);
}

// d.get(field, []) handed on or stored: a missing field is a new empty Array.
Value list_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// int(search.dist[tile_index])
int64_t search_distance(const State &state, DictRef search, int64_t tile_index) {
	return gd::to_int(state, ai::vindex(state, gd::index(state, search, str(key::dist)), int_value(tile_index)));
}

// int(search.get("passage_unexplored", {}).get(key, 0))
int64_t passage_unexplored(const State &state, DictRef search, int64_t passage_key) {
	Value found;
	if (!state.lookup(search, str(key::passage_unexplored), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, int_value(passage_key), int_value(0)));
}

// best["path"] = _path_to(search, int(best.tile_index))
void set_path(State &state, DictRef plan, DictRef search) {
	const int64_t tile_index = gd::to_int(state, gd::index(state, plan, str(key::tile_index)));
	state.set(plan, str(key::path), array_value(ai_hero_rules::_path_to(state, search, tile_index)));
}

// {"arrived": true, "acted": true}
DictRef arrived_acted(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(true));
	state.set(result, str(key::acted), bool_value(true));
	return result;
}

// s.get_slice(splitter, slice) (String::get_slice): the whole text when the
// splitter does not occur, "" when the slice does not exist.
Atom get_slice(State &state, Atom text, Atom splitter, int64_t slice) {
	const std::string whole = state.text(text);
	const std::string separator = state.text(splitter);
	if (whole.empty() || separator.empty() || slice < 0) {
		return key::empty;
	}
	if (whole.find(separator) == std::string::npos) {
		return text;
	}
	size_t pos = 0;
	size_t prev_pos = 0;
	for (int64_t index = 0;; ++index) {
		pos = whole.find(separator, pos);
		if (pos == std::string::npos) {
			pos = whole.size();
		}
		if (index == slice) {
			return state.intern(std::string_view(whole).substr(prev_pos, pos - prev_pos));
		}
		if (pos == whole.size()) {
			break;
		}
		pos += separator.size();
		prev_pos = pos;
	}
	return key::empty;
}

} // namespace

namespace ai_hero_rules {

// Out of steps, a hero casts the movement spell that gives it the most, once a
// day as a human hero can: mana is full again in the morning. One holding a
// town's gate tonight keeps its mana for the fight.
static bool _cast_movement_spell(State &state, DictRef session, DictRef context, int64_t index, Atom placement_id) {
	const DictRef entry = overworld_dict(state, session, key::encounters, index);
	const DictRef home = _own_town_at(state, session, context_controller(state, context), entry);
	if (!gd::is_empty(state, home)) {
		const bool is_main = placement_id == _decision_main_id(state, session, context) || gd::array_has(state, _decision_field_ids(state, session, context), str(placement_id));
		if (_holds_gate(state, session, context, entry, home, is_main)) {
			return false;
		}
	}
	const DictRef commander = dict_or_new(state, entry, key::enemy_commander_state);
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	const DictRef movement = dict_or_new(state, block, key::movement);
	const int64_t day = ai::session_int(state, session, key::day);
	Atom best = key::empty;
	int64_t best_restored = 0;
	int64_t best_cost = 0;
	for (const Value &spell : gd::items(state, array_value(spell_rules::known_spells(state, commander, key::overworld)))) {
		if (!gd::bool_field(state, spell_rules::validate_overworld_spell(state, commander, movement, spell, day), key::ok, false)) {
			continue;
		}
		const int64_t restored = gd::int_field(state, spell_rules::adventure_spell_consequence_preview(state, commander, movement, spell), key::movement_restored, 0);
		const int64_t cost = spell_rules::adjusted_spell_mana_cost(state, commander, spell);
		if (restored > best_restored || (restored > 0 && restored == best_restored && cost < best_cost)) {
			best = ai::string_or_empty(state, gd::as_dict(spell), key::id);
			best_restored = restored;
			best_cost = cost;
		}
	}
	if (best == key::empty) {
		return false;
	}
	const DictRef cast = spell_rules::cast_overworld_spell(state, commander, movement, best, day);
	if (!gd::bool_field(state, cast, key::ok, false)) {
		return false;
	}
	state.set(entry, str(key::enemy_commander_state), gd::index(state, cast, str(key::hero)));
	state.set(block, str(key::movement), gd::index(state, cast, str(key::movement)));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
	return true;
}

DictRef _run_hero_day(State &state, DictRef session, DictRef context, Atom placement_id) {
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	const int64_t decisions = tunable_int(state, key::MAX_DECISIONS_PER_DAY);
	for (int64_t decision = 0; decision < decisions; ++decision) {
		const int64_t index = _entry_index(state, session, placement_id);
		if (index < 0 || _is_resolved(state, session, placement_id)) {
			break;
		}
		DictRef entry = overworld_dict(state, session, key::encounters, index);
		if (movement_int(state, entry, key::current, 0) <= 0) {
			state.set(context, str(key::decision), dict_value(state.new_dict()));
			if (!_cast_movement_spell(state, session, context, index, placement_id)) {
				break;
			}
			entry = overworld_dict(state, session, key::encounters, index);
		}
		state.set(context, str(key::decision), dict_value(state.new_dict()));
		const DictRef visit = _visit_own_town_if_inside(state, session, context, index);
		_append_all(state, events, list_field(state, visit, key::events));
		entry = overworld_dict(state, session, key::encounters, index);
		state.set(context, str(key::decision), dict_value(state.new_dict()));
		const DictRef home = _own_town_at(state, session, context_controller(state, context), entry);
		if (!gd::is_empty(state, home)) {
			const bool is_main = placement_id == _decision_main_id(state, session, context) || gd::array_has(state, _decision_field_ids(state, session, context), str(placement_id));
			if (_holds_gate(state, session, context, entry, home, is_main)) {
				// A hostile hero is a day away: the hero holds the gate, unless it
				// can catch and beat that hero today. The goal says so.
				entry = overworld_dict(state, session, key::encounters, index);
				const DictRef holding = dict_or_new(state, entry, key::ai_hero);
				const DictRef goal = state.new_dict();
				state.set(goal, str(key::kind), str(key::hold));
				state.set(goal, str(key::id), str(ai::string_or_empty(state, home, key::placement_id)));
				state.set(holding, str(key::goal), dict_value(goal));
				state.set(entry, str(key::ai_hero), dict_value(holding));
				_store_entry(state, session, index, entry);
				break;
			}
		}
		const bool logging = gd::bool_field(state, session_flags(state, session), key::ai_battle_log_enabled, false);
		if (logging) {
			state.set(context, str(key::decision_alternatives), array_value(state.new_array()));
		}
		const DictRef plan = _choose_plan(state, session, context, entry);
		if (logging) {
			_log_decision(state, session, context, entry, plan);
			state.erase(context, str(key::decision_alternatives));
		}
		if (gd::is_empty(state, plan) || ai::string_or_empty(state, plan, key::kind) == key::wait) {
			_note_boat_need(state, session, context, entry);
		}
		if (gd::is_empty(state, plan)) {
			break;
		}
		const int64_t act_started = gd::ticks_usec();
		const DictRef step = _follow_plan(state, session, context, index, plan);
		_profile_add(state, context, key::act_ms, act_started);
		_append_all(state, messages, list_field(state, step, key::messages));
		_append_all(state, events, list_field(state, step, key::events));
		if (gd::bool_field(state, step, key::battle_started, false)) {
			const DictRef result = state.new_dict();
			state.set(result, str(key::messages), array_value(messages));
			state.set(result, str(key::events), array_value(events));
			state.set(result, str(key::battle_started), bool_value(true));
			return result;
		}
		if (!gd::bool_field(state, step, key::arrived, false)) {
			if (gd::bool_field(state, step, key::rerouted, false)) {
				continue;
			}
			// Out of steps on the way: the top of the loop casts or ends the day.
			const int64_t walked = _entry_index(state, session, placement_id);
			if (walked >= 0 && movement_int(state, overworld_dict(state, session, key::encounters, walked), key::current, 0) <= 0) {
				continue;
			}
			break;
		}
		Value step_events;
		const bool no_events = state.lookup(step, str(key::events), step_events) ? ai::vempty(state, step_events) : true;
		const bool acted_fallback = !no_events || ai::string_or_empty(state, plan, key::kind) == key::town_own;
		const bool acted = gd::to_bool(state.get(step, str(key::acted), bool_value(acted_fallback)));
		if (acted) {
			_forget_beyond(state, context, ai::string_or_empty(state, plan, key::id));
		}
		if (!acted) {
			// Nothing came of it (a site that cannot serve this hero today):
			// leave it alone for a few days instead of returning every turn.
			const Atom target_id = ai::string_or_empty(state, plan, key::id);
			_avoid_target(state, session, placement_id, target_id, gd::add(ai::session_int(state, session, key::day), tunable_int(state, key::AVOID_DAYS)));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::messages), array_value(messages));
	state.set(result, str(key::events), array_value(events));
	return result;
}

DictRef _choose_plan(State &state, DictRef session, DictRef context, DictRef entry) {
	_open_decision_memos(state, context);
	const DictRef plan = _decide_plan(state, session, context, entry);
	_close_decision_memos(state, context);
	return plan;
}

void _open_decision_memos(State &state, DictRef context) {
	state.set(context, str(key::decision_site_pass), dict_value(state.new_dict()));
	state.set(context, str(key::scout_radii), dict_value(state.new_dict()));
}

void _close_decision_memos(State &state, DictRef context) {
	state.erase(context, str(key::decision_site_pass));
	state.erase(context, str(key::scout_radii));
}

DictRef _decide_plan(State &state, DictRef session, DictRef context, DictRef entry) {
	const int64_t movement_max = compat::engine_max<int64_t>(1, movement_int(state, entry, key::max, 1));
	const int64_t min_radius = tunable_int(state, key::MIN_SEARCH_RADIUS);
	const int64_t radius = compat::engine_max<int64_t>(min_radius, gd::mul(movement_max, tunable_int(state, key::SEARCH_DAYS)));
	state.set(context, str(key::decision), dict_value(state.new_dict()));
	int64_t started = gd::ticks_usec();
	DictRef search = _search(state, session, context, entry, radius);
	_profile_add(state, context, key::search_ms, started);
	// Another of the player's heroes asked this one to step out of its way.
	const DictRef step_aside = _pending_make_way(state, session, context, entry, search);
	if (!gd::is_empty(state, step_aside)) {
		set_path(state, step_aside, search);
		return step_aside;
	}
	// A guard it beats without losing a creature costs the hero nothing but
	// the walk: it fights it first.
	const DictRef free_fight = _free_fight(state, session, context, entry, search);
	if (!gd::is_empty(state, free_fight)) {
		set_path(state, free_fight, search);
		return free_fight;
	}
	started = gd::ticks_usec();
	DictRef best = _vetted_candidate(state, session, context, entry, search, movement_max);
	_profile_add(state, context, key::choose_ms, started);
	// Main and field armies weigh what decides the game anywhere on the map
	// against the best thing near them, and what lies past the gates.
	if (_plans_far(state, session, context, entry)) {
		started = gd::ticks_usec();
		const DictRef wide = _search(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::STRATEGIC_DAYS)));
		_note_route_visit(state, session, context, entry);
		const DictRef far = _strategic_candidate(state, session, context, entry, movement_max, radius, wide);
		_profile_add(state, context, key::strategic_ms, started);
		started = gd::ticks_usec();
		const DictRef gate = _gate_candidate(state, session, context, entry, wide, movement_max, gd::mul(movement_max, tunable_int(state, key::STRATEGIC_DAYS)));
		_profile_add(state, context, key::gate_ms, started);
		const double near_score = gd::float_field(state, best, key::score, 0.0);
		if (!gd::is_empty(state, gate)) {
			const double gate_score = gd::to_float(gd::index(state, gate, str(key::score)));
			const double far_score = gd::float_field(state, far, key::score, 0.0);
			if (gate_score > compat::engine_max(near_score, far_score) && _gate_fight_looks_good(state, session, context, entry, gate)) {
				_close_decision_memos(state, context);
				return _gate_walk(state, session, context, entry, gate, wide);
			}
		}
		if (!gd::is_empty(state, far) && gd::float_field(state, far, key::score, 0.0) > near_score) {
			return _by_the_way(state, session, context, entry, search, far, wide, movement_max);
		}
	} else {
		// A courier looks as far for troops to carry: an own town holding them,
		// or the main army to hand them to.
		started = gd::ticks_usec();
		const DictRef wide = _search(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::STRATEGIC_DAYS)));
		const DictRef far = _strategic_candidate(state, session, context, entry, movement_max, radius, wide, true);
		_profile_add(state, context, key::strategic_ms, started);
		// Or past a gate, on the other level.
		started = gd::ticks_usec();
		const DictRef gate = _gate_candidate(state, session, context, entry, wide, movement_max, gd::mul(movement_max, tunable_int(state, key::STRATEGIC_DAYS)));
		_profile_add(state, context, key::gate_ms, started);
		const double near_score = gd::float_field(state, best, key::score, 0.0);
		const double far_score = gd::float_field(state, far, key::score, 0.0);
		if (!gd::is_empty(state, gate)) {
			const Atom target = ai::string_or_empty(state, dict_or_new(state, gate, key::beyond), key::kind);
			const bool troops = target == key::town_own || target == key::meet;
			if (troops && gd::float_field(state, gate, key::score, 0.0) > compat::engine_max(near_score, far_score) && _gate_fight_looks_good(state, session, context, entry, gate)) {
				_close_decision_memos(state, context);
				return _gate_walk(state, session, context, entry, gate, wide);
			}
		}
		if (!gd::is_empty(state, far) && far_score > near_score) {
			return _by_the_way(state, session, context, entry, search, far, wide, movement_max);
		}
	}
	if (gd::is_empty(state, best)) {
		// Nothing worth doing nearby: look a week out before standing still.
		started = gd::ticks_usec();
		search = _search(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)));
		_profile_add(state, context, key::search_ms, started);
		started = gd::ticks_usec();
		best = _vetted_candidate(state, session, context, entry, search, movement_max);
		_profile_add(state, context, key::choose_ms, started);
	}
	if (gd::is_empty(state, best)) {
		_close_decision_memos(state, context);
		const bool cleared = _clear_way(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)), movement_max);
		_open_decision_memos(state, context);
		if (cleared) {
			// A hero of the player's own stepped aside: look again.
			search = _search(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)));
			best = _vetted_candidate(state, session, context, entry, search, movement_max);
		}
	}
	if (gd::is_empty(state, best)) {
		// Nothing left on this level: the other one, through a gate.
		started = gd::ticks_usec();
		best = _gate_candidate(state, session, context, entry, search, movement_max, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)), true);
		if (!gd::is_empty(state, best) && !_gate_fight_looks_good(state, session, context, entry, best)) {
			best = state.new_dict();
		}
		if (!gd::is_empty(state, best) && state.has(best, str(key::past_path))) {
			_close_decision_memos(state, context);
			return _gate_walk(state, session, context, entry, best, search);
		}
		_profile_add(state, context, key::gate_ms, started);
	}
	if (gd::is_empty(state, best)) {
		best = _evade(state, session, context, entry, search);
	}
	if (gd::is_empty(state, best)) {
		best = _cornered_fight(state, session, entry, search, context);
	}
	if (gd::is_empty(state, best)) {
		best = _idle_fight(state, session, context, entry, search);
	}
	if (gd::is_empty(state, best)) {
		best = _wait_by_home(state, session, context, entry, search, state.new_dict());
	}
	if (gd::is_empty(state, best)) {
		return state.new_dict();
	}
	set_path(state, best, search);
	return _by_the_way(state, session, context, entry, search, best, search, movement_max);
}

DictRef _by_the_way(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef plan, DictRef plan_search, int64_t movement_max) {
	const DictRef detour = _on_the_way(state, session, context, entry, search, plan, plan_search, movement_max);
	if (gd::is_empty(state, detour)) {
		return plan;
	}
	set_path(state, detour, search);
	return detour;
}

DictRef _on_the_way(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef plan, DictRef plan_search, int64_t movement_max) {
	const Atom kind = ai::string_or_empty(state, plan, key::kind);
	const int64_t distance = gd::int_field(state, plan, key::distance, 0);
	if ((kind != key::meet && kind != key::town_own) || distance <= 0 || !state.has(plan, str(key::tile_index))) {
		return state.new_dict();
	}
	// The way there: each tile and how far along it lies.
	const ArrayRef path = _path_to(state, plan_search, gd::to_int(state, gd::index(state, plan, str(key::tile_index))));
	if (state.array_size(path) == 0) {
		return state.new_dict();
	}
	const int64_t width = context_size(state, context).x;
	const ArrayRef way = state.new_array();
	for (const Value &step : gd::items(state, array_value(path))) {
		const Vector2i tile = as_vector2i(step);
		state.append(way, int_value(tile.x));
		state.append(way, int_value(tile.y));
		state.append(way, int_value(search_distance(state, plan_search, gd::add(gd::mul(tile.y, width), tile.x))));
	}
	const DictRef errand = state.new_dict();
	state.set(errand, str(key::value), float_value(gd::float_field(state, plan, key::value, 0.0)));
	state.set(errand, str(key::distance), int_value(distance));
	state.set(errand, str(key::way), array_value(way));
	// The detours are not this decision's alternatives.
	const Value logged = state.get(context, str(key::decision_alternatives), Value());
	state.erase(context, str(key::decision_alternatives));
	state.set(context, str(key::on_the_way), dict_value(errand));
	const DictRef detour = _vetted_candidate(state, session, context, entry, search, movement_max);
	state.erase(context, str(key::on_the_way));
	if (logged.kind != state::Kind::Nil) {
		state.set(context, str(key::decision_alternatives), logged);
	}
	return detour;
}

DictRef _strategic_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t movement_max, int64_t local_radius, DictRef wide, bool troops_only) {
	const DictRef search = !gd::is_empty(state, wide) ? wide : _search(state, session, context, entry, gd::mul(movement_max, tunable_int(state, key::STRATEGIC_DAYS)));
	const PackedRef known = _explored(state, session, context, level_rules::level_of(state, dict_value(entry)));
	const double power = hero_power(state, entry);
	const DictRef needs = _resource_needs(state, session, context);
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	Value found;
	const bool has_avoid = dict_field(state, block, key::avoid, found);
	const DictRef avoid = has_avoid ? found.ref : 0;
	const bool has_goal = dict_field(state, block, key::goal, found);
	const DictRef goal = has_goal ? found.ref : 0;
	const DictRef war = troops_only ? state.new_dict() : _war_paths(state, session, context, entry, search, needs);
	// While a rival's towns are unseen, a guard whose fight opens unexplored
	// ground is the way to them (`_passage_value`), however far.
	const bool hunting = !troops_only && _rival_towns_unknown(state, session, context) && ai::session_int(state, session, key::day) >= tunable_int(state, key::HUNT_START_DAY);
	const DictRef guard_candidates = state.new_dict();
	Value stops;
	const bool has_stops = state.lookup(search, str(key::stops), stops);
	if (has_stops) {
		gd::as_dict(stops);
	}
	DictRef best = state.new_dict();
	double best_score = 0.0;
	double blocked_need = std::numeric_limits<double>::infinity();
	if (has_stops) {
		for (const Value &tile_key : gd::items(state, stops)) {
			const int64_t tile_index = gd::to_int(state, tile_key);
			const int64_t distance = search_distance(state, search, tile_index);
			if (distance <= local_radius) {
				continue;
			}
			// A town beside a hostile hero is reached through that hero.
			const bool hero_guarded = _in_hero_zone(state, search, tile_index);
			for (const Value &ref : gd::items(state, gd::index(state, stops.ref, tile_key))) {
				if (hero_guarded && !gd::to_bool(ai::vget(state, ref, key::zone, bool_value(false)))) {
					continue;
				}
				DictRef candidate = 0;
				bool filled = false;
				const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
				// A courier looks only for troops: its own towns and the main army.
				if (troops_only && kind != kStopTown && kind != kStopAiHero) {
					continue;
				}
				if (kind == kStopTown) {
					const int64_t town_index = gd::to_int(state, ai::vmember(state, ref, key::index));
					if (!_town_seen(state, known, overworld_dict(state, session, key::towns, town_index), context_size(state, context))) {
						continue;
					}
				} else if (kind == kStopHero || kind == kStopAiHero) {
				} else if (kind == kStopResource || kind == kStopArtifact) {
					// A site in the way to a known town, or to unexplored ground
					// while a rival's towns are unseen.
					const int64_t door = _site_door_key(state, tile_index);
					if (!state.has(_site_doors(state, search), int_value(tile_index)) || gd::packed_int(state, known, tile_index) == 0 || !(state.has(war, int_value(door)) || hunting)) {
						continue;
					}
					if (_site_door_value(state, session, context, entry, search, tile_index, needs) <= 0.0 || !(state.has(war, int_value(door)) || passage_unexplored(state, search, door) > 0)) {
						continue;
					}
					candidate = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, search, tile_index);
					filled = true;
					if (gd::is_empty(state, candidate)) {
						continue;
					}
				} else if (kind == kStopEncounter) {
					const bool on_war_path = state.has(war, int_value(gd::to_int(state, ai::vmember(state, ref, key::index))));
					if (!on_war_path && !(hunting && gd::packed_int(state, known, tile_index) != 0)) {
						continue;
					}
					if (on_war_path) {
						const DictRef guard = overworld_dict(state, session, key::encounters, gd::to_int(state, ai::vmember(state, ref, key::index)));
						const double guard_need = _guard_power(state, guard) * tunable_float(state, key::GUARD_WIN_RATIO);
						if (guard_need > power) {
							blocked_need = compat::engine_min(blocked_need, guard_need);
						}
					}
					// One guard covers several tiles: weigh it once.
					const int64_t guard_index = gd::to_int(state, ai::vmember(state, ref, key::index));
					if (!state.has(guard_candidates, int_value(guard_index))) {
						DictRef weighed = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, search);
						if (!on_war_path && passage_unexplored(state, search, gd::to_int(state, ai::vmember(state, ref, key::index))) <= 0) {
							weighed = state.new_dict();
						}
						state.set(guard_candidates, int_value(gd::to_int(state, ai::vmember(state, ref, key::index))), dict_value(weighed));
					}
					const Value kept = gd::index(state, guard_candidates, int_value(gd::to_int(state, ai::vmember(state, ref, key::index))));
					candidate = gd::as_dict(gd::duplicate_value(state, kept, false));
					filled = true;
					if (gd::is_empty(state, candidate)) {
						continue;
					}
				} else {
					continue;
				}
				if (!filled) {
					candidate = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, search);
				}
				if (gd::is_empty(state, candidate)) {
					continue;
				}
				// An own town holding troops and the main army count however far:
				// troops recruited where no hero passes stayed there for months.
				const Atom candidate_kind = ai::string_or_empty(state, candidate, key::kind);
				if (troops_only && candidate_kind != key::town_own && candidate_kind != key::meet) {
					continue;
				}
				const Atom candidate_id = ai::string_or_empty(state, candidate, key::id);
				const int64_t avoided_until = has_avoid ? gd::to_int(state, state.get(avoid, str(candidate_id), int_value(-1))) : -1;
				if (avoided_until >= ai::session_int(state, session, key::day)) {
					continue;
				}
				const double candidate_value = gd::float_field(state, candidate, key::value, 0.0);
				const double value = candidate_value - _boat_price(state, session, context, search, tile_index);
				if (value <= 0.0) {
					continue;
				}
				double score = value / (1.0 + static_cast<double>(distance) / static_cast<double>(movement_max));
				if (has_goal) {
					const Atom goal_id = ai::string_or_empty(state, goal, key::id);
					if (goal_id != key::empty && goal_id == ai::string_or_empty(state, candidate, key::id)) {
						score *= tunable_float(state, key::GOAL_CONTINUITY_BONUS);
					}
				}
				if (state.has(context, str(key::decision_alternatives))) {
					_note_alternative(state, context, candidate, score, distance);
				}
				if (score > best_score) {
					best_score = score;
					state.set(candidate, str(key::tile_index), int_value(tile_index));
					state.set(candidate, str(key::distance), int_value(distance));
					state.set(candidate, str(key::score), float_value(score));
					best = candidate;
				}
			}
		}
	}
	if (!troops_only && _rival_towns_unknown(state, session, context)) {
		const DictRef explore = _exploration_candidate(state, session, context, entry, search);
		if (!gd::is_empty(state, explore) && gd::to_int(state, gd::index(state, explore, str(key::distance))) > local_radius) {
			const double explore_value = gd::to_float(gd::index(state, explore, str(key::value)));
			const double explore_distance = gd::to_float(gd::index(state, explore, str(key::distance)));
			const double explore_score = explore_value / (1.0 + explore_distance / static_cast<double>(movement_max));
			if (explore_score > best_score) {
				state.set(explore, str(key::score), float_value(explore_score));
				best = explore;
			}
		} else if (gd::is_empty(state, explore)) {
			// Shut in with the rivals unseen and no ground left to scout: the
			// guards around are the way out, and the weakest it cannot beat
			// says how much stronger the main army must grow.
			if (has_stops) {
				for (const Value &tile_key : gd::items(state, stops)) {
					for (const Value &ref : gd::items(state, gd::index(state, stops.ref, tile_key))) {
						if (gd::to_int(state, ai::vmember(state, ref, key::kind)) != kStopEncounter) {
							continue;
						}
						const DictRef guard = overworld_dict(state, session, key::encounters, gd::to_int(state, ai::vmember(state, ref, key::index)));
						const double way_out = _guard_power(state, guard) * tunable_float(state, key::GUARD_WIN_RATIO);
						if (way_out > power) {
							blocked_need = compat::engine_min(blocked_need, way_out);
						}
					}
				}
			}
		}
	}
	if (!gd::is_empty(state, best)) {
		set_path(state, best, search);
	}
	// Remember what strength the way to a rival town needs, for the field armies.
	if (placement_is_main(state, session, context, entry)) {
		state.set(block, str(key::blocked_need), float_value(blocked_need == std::numeric_limits<double>::infinity() ? 0.0 : blocked_need));
		state.set(entry, str(key::ai_hero), dict_value(block));
	}
	return best;
}

void _note_route_visit(State &state, DictRef session, DictRef context, DictRef entry) {
	const int64_t tile = _tile_index_of(state, entry, context_size(state, context));
	if (level_rules::level_count(state, session) < 2 || tile < 0) {
		return;
	}
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	const DictRef visits = state.new_dict();
	Value known;
	if (dict_field(state, block, key::route_visits, known)) {
		for (const Value &region_key : gd::items(state, known)) {
			const int64_t seen_day = gd::to_int(state, gd::index(state, known.ref, region_key));
			if (gd::add(seen_day, tunable_int(state, key::ROUTE_REVISIT_DAYS)) > ai::session_int(state, session, key::day)) {
				state.set(visits, region_key, int_value(gd::to_int(state, gd::index(state, known.ref, region_key))));
			}
		}
	}
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const double power = hero_power(state, entry);
	const double explore_value = _explore_value(state, session, context);
	const double loss_limit = _route_loss_limit(state, explore_value);
	const Atom here = _stretch_key(state, session, context, level, tile, power, loss_limit, entry);
	if (here != key::empty) {
		state.set(visits, str(here), int_value(ai::session_int(state, session, key::day)));
	}
	state.set(block, str(key::route_visits), dict_value(visits));
	state.set(entry, str(key::ai_hero), dict_value(block));
}

void _forget_beyond(State &state, DictRef context, Atom target_id) {
	Value found;
	const bool has_cache = state.lookup(context, str(key::gate_beyond), found);
	const DictRef cache = has_cache ? gd::as_dict(found) : 0;
	if (target_id == key::empty || !has_cache || gd::is_empty(state, cache)) {
		return;
	}
	const ArrayRef cache_keys = gd::keys(state, cache);
	for (const Value &cache_key : gd::items(state, array_value(cache_keys))) {
		const DictRef kept = gd::as_dict(gd::index(state, cache, cache_key));
		if (ai::string_or_empty(state, kept, key::id) == target_id) {
			state.erase(cache, cache_key);
		}
	}
}

bool placement_is_main(State &state, DictRef session, DictRef context, DictRef entry) {
	const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
	return placement_id == _decision_main_id(state, session, context);
}

DictRef _vetted_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max) {
	DictRef best = _best_candidate(state, session, context, entry, search, movement_max);
	const int64_t vetoes = tunable_int(state, key::MAX_FIGHT_VETOES);
	for (int64_t veto = 0; veto < vetoes; ++veto) {
		if (gd::is_empty(state, best)) {
			return best;
		}
		const bool looks_good = _fight_looks_good(state, session, context, entry, best);
		_note_vetoed_need(state, session, context, entry, best, looks_good);
		if (looks_good) {
			return best;
		}
		const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
		const Atom target_id = ai::string_or_empty(state, best, key::id);
		_avoid_target(state, session, placement_id, target_id, gd::add(ai::session_int(state, session, key::day), tunable_int(state, key::AVOID_DAYS)));
		best = _best_candidate(state, session, context, entry, search, movement_max);
	}
	if (gd::is_empty(state, best)) {
		return best;
	}
	const bool looks_good = _fight_looks_good(state, session, context, entry, best);
	_note_vetoed_need(state, session, context, entry, best, looks_good);
	if (looks_good) {
		return best;
	}
	return state.new_dict();
}

DictRef _follow_plan(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const DictRef entry = overworld_dict(state, session, key::encounters, index);
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	const DictRef movement = dict_or_new(state, block, key::movement);
	Value path_value;
	const bool has_path = state.lookup(plan, str(key::path), path_value);
	const ArrayRef path = has_path ? ai::typed_array(path_value, "AiHeroRules._follow_plan") : 0;
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	// The goal stays private to the AI (no raid-style target fields that the
	// human's threat forecasts would read). On the way to a gate it is what lies
	// beyond, as once the hero has crossed (`_cross_gate`): the errand is the
	// destination, whichever gate leads there.
	const DictRef goal = state.new_dict();
	Value beyond;
	if (state.lookup(plan, str(key::beyond), beyond) && gd::is_dict(beyond) && ai::string_or_empty(state, beyond.ref, key::id) != key::empty) {
		state.set(goal, str(key::kind), str(ai::string_or_empty(state, beyond.ref, key::kind)));
		state.set(goal, str(key::id), str(ai::string_or_empty(state, beyond.ref, key::id)));
	} else {
		state.set(goal, str(key::kind), str(ai::string_or_empty(state, plan, key::kind)));
		state.set(goal, str(key::id), str(ai::string_or_empty(state, plan, key::id)));
	}
	state.set(block, str(key::goal), dict_value(goal));
	const int64_t path_size = has_path ? state.array_size(path) : 0;
	if (path_size == 0) {
		state.set(entry, str(key::ai_hero), dict_value(block));
		_store_entry(state, session, index, entry);
		return _interact(state, session, context, index, plan);
	}
	// Walking out of the town ends a parked hero's wait there.
	state.erase(block, str(key::parked));
	const int64_t last = path_size - 1;
	bool arrived = false;
	bool rerouted = false;
	bool sailing = water_travel_rules::hero_boat_id(state, dict_value(entry)) != key::empty;
	for (int64_t step_index = 0; step_index < path_size; ++step_index) {
		if (gd::int_field(state, movement, key::current, 0) <= 0) {
			break;
		}
		const Vector2i tile = as_vector2i(state.at(path, step_index));
		state.set(movement, str(key::current), int_value(gd::sub(gd::int_field(state, movement, key::current, 0), 1)));
		if (step_index == last && _tile_blocked_for_standing(state, session, context, tile, level, ai::string_or_empty(state, entry, key::placement_id))) {
			arrived = true;
			break;
		}
		const DictRef before = level_rules::position(state, entry);
		// Boarding a boat or stepping ashore ends the day's movement.
		const bool shore = water_travel_rules::is_water(state, dict_value(session), tile.x, tile.y, level) != sailing;
		if (shore) {
			if (!_cross_shore(state, session, context, entry, tile, level)) {
				state.set(movement, str(key::current), int_value(gd::add(gd::int_field(state, movement, key::current, 0), 1)));
				break;
			}
			state.erase(plan, str(key::retreat_tile));
		} else {
			const Vector2i retreat = Vector2i::of(gd::int_field(state, before, key::x, 0), gd::int_field(state, before, key::y, 0));
			state.set(plan, str(key::retreat_tile), Value::of_vector2i(retreat.x, retreat.y));
		}
		Vector2i landed = tile;
		int64_t landed_level = level;
		if (!shore) {
			const DictRef through = _portal_step(state, session, context, entry, tile, level);
			landed = as_vector2i(state.get(through, str(key::exit), Value::of_vector2i(tile.x, tile.y)));
			landed_level = gd::int_field(state, through, key::level, level);
		}
		state.set(entry, str(key::x), int_value(landed.x));
		state.set(entry, str(key::y), int_value(landed.y));
		if (landed_level != level) {
			state.set(entry, str(key::level), int_value(landed_level));
		}
		if (water_travel_rules::hero_boat_id(state, dict_value(entry)) != key::empty) {
			const Atom boat_id = water_travel_rules::hero_boat_id(state, dict_value(entry));
			const Atom hero_id = ai::string_or_empty(state, entry, key::placement_id);
			water_travel_rules::place_boat(state, dict_value(session), boat_id, hero_id, landed, landed_level);
		}
		overworld_turn_playback::move(state, dict_value(session), entry, before);
		const DictRef point = level_rules::position(state, entry);
		_reveal(state, session, context, point, _sight_radius(state, entry));
		// Next to a hostile hero the walk ends in a fight with it, whatever the
		// hero set out to do (a portal can put it there unplanned).
		const DictRef beside = _hostile_hero_beside(state, session, context, landed, landed_level);
		if (!gd::is_empty(state, beside)) {
			const Atom beside_kind = gd::stringify(state, gd::index(state, beside, str(key::kind)));
			if (beside_kind != ai::string_or_empty(state, plan, key::kind) || gd::to_int(state, gd::index(state, beside, str(key::index))) != gd::int_field(state, plan, key::index, -1)) {
				plan = beside;
			}
			arrived = true;
			break;
		}
		if (shore) {
			sailing = !sailing;
			state.set(movement, str(key::current), int_value(0));
			arrived = step_index == last;
			break;
		}
		if (!(landed == tile) || landed_level != level) {
			// A random portal sent the hero elsewhere: it plans again from there.
			rerouted = true;
			break;
		}
		if (step_index == last) {
			arrived = true;
		}
	}
	// A hero that came to scout a portal steps through it to see where it leads.
	if (arrived && ai::string_or_empty(state, plan, key::kind) == key::explore && gd::int_field(state, movement, key::current, 0) > 0) {
		const DictRef scouted = _portal_step(state, session, context, entry, Vector2i::of(-1000, -1000), level);
		if (state.has(scouted, str(key::exit))) {
			const DictRef before = level_rules::position(state, entry);
			state.set(movement, str(key::current), int_value(gd::sub(gd::int_field(state, movement, key::current, 0), 1)));
			state.set(entry, str(key::x), ai::vmember(state, gd::index(state, scouted, str(key::exit)), key::x));
			state.set(entry, str(key::y), ai::vmember(state, gd::index(state, scouted, str(key::exit)), key::y));
			const int64_t scouted_level = gd::int_field(state, scouted, key::level, level);
			if (scouted_level != level) {
				state.set(entry, str(key::level), int_value(scouted_level));
			}
			overworld_turn_playback::move(state, dict_value(session), entry, before);
			const DictRef point = level_rules::position(state, entry);
			_reveal(state, session, context, point, _sight_radius(state, entry));
			rerouted = true;
			arrived = false;
			const DictRef ambushed = _hostile_hero_beside(state, session, context, as_vector2i(gd::index(state, scouted, str(key::exit))), scouted_level);
			if (!gd::is_empty(state, ambushed)) {
				plan = ambushed;
				rerouted = false;
				arrived = true;
			}
		}
	}
	state.set(block, str(key::movement), dict_value(movement));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
	overworld_rules::invalidate_spatial_lookup(state, session);
	if (!arrived) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::arrived), bool_value(false));
		state.set(result, str(key::rerouted), bool_value(rerouted));
		return result;
	}
	return _interact(state, session, context, index, plan);
}

DictRef _interact(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const Atom kind = ai::string_or_empty(state, plan, key::kind);
	if (kind == key::resource) {
		return _claim_resource(state, session, context, index, plan);
	}
	if (kind == key::artifact) {
		return _take_artifact(state, session, context, index, plan);
	}
	if (kind == key::encounter) {
		return _fight_neutral(state, session, context, index, plan);
	}
	if (kind == key::town_own) {
		const DictRef entry = overworld_dict(state, session, key::encounters, index);
		const DictRef block = dict_or_new(state, entry, key::ai_hero);
		state.erase(block, str(key::visited_town_day));
		state.set(entry, str(key::ai_hero), dict_value(block));
		_store_entry(state, session, index, entry);
		const DictRef visit = _visit_own_town_if_inside(state, session, context, index);
		const DictRef result = arrived_acted(state);
		state.set(result, str(key::events), list_field(state, visit, key::events));
		return result;
	}
	if (kind == key::town_neutral || kind == key::town_hostile) {
		return _attack_town(state, session, context, index, plan);
	}
	if (kind == key::hero || kind == key::ai_hero) {
		// A hero holding its own town's entry defends with the garrison: the fight
		// is the town's (_attack_town), however the attacker came to it.
		const int64_t town_index = _entry_town_index(state, session, kind, gd::int_field(state, plan, key::index, -1));
		if (town_index >= 0) {
			const DictRef town_plan = state.new_dict();
			state.set(town_plan, str(key::kind), str(key::town_hostile));
			state.set(town_plan, str(key::index), int_value(town_index));
			return _attack_town(state, session, context, index, town_plan);
		}
	}
	if (kind == key::hero) {
		return _attack_player_hero(state, session, context, index, plan);
	}
	if (kind == key::ai_hero) {
		return _fight_ai_hero(state, session, context, index, plan);
	}
	if (kind == key::meet) {
		return _meet_hero(state, session, context, index, plan);
	}
	if (kind == key::explore) {
		return arrived_acted(state);
	}
	if (kind == key::gate) {
		return _cross_gate(state, session, context, index, plan);
	}
	if (kind == key::wait) {
		const DictRef waiting = overworld_dict(state, session, key::encounters, index);
		const DictRef waiting_block = dict_or_new(state, waiting, key::ai_hero);
		state.set(waiting_block, str(key::goal), dict_value(state.new_dict()));
		state.set(waiting, str(key::ai_hero), dict_value(waiting_block));
		_store_entry(state, session, index, waiting);
		return arrived_acted(state);
	}
	if (kind == key::park) {
		const Value parked = overworld_item(state, session, key::encounters, index);
		const Atom placement_id = gd::stringify(state, ai::vget(state, parked, key::placement_id, str(key::empty)));
		_park(state, session, placement_id, ai::string_or_empty(state, plan, key::id));
		return arrived_acted(state);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(true));
	return result;
}

void _log_decision(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan) {
	Value found;
	const ArrayRef log = state.lookup(session_flags(state, session), str(key::ai_decision_log), found) ? ai::typed_array(found, "AiHeroRules._log_decision") : state.new_array();
	const Atom chosen = get_slice(state, ai::string_or_empty(state, plan, key::id), key::_object_, 1);
	const ArrayRef alternatives = state.new_array();
	for (const Value &alternative : gd::field_items(state, context, str(key::decision_alternatives))) {
		if (!gd::equal(state, ai::vindex(state, alternative, int_value(2)), str(chosen)) && state.array_size(alternatives) < kDecisionLogAlternatives) {
			state.append(alternatives, alternative);
		}
	}
	const DictRef row = state.new_dict();
	state.set(row, str(key::player_id), str(context_controller(state, context)));
	state.set(row, str(key::hero), str(hero_name(state, entry)));
	const ArrayRef at = state.new_array();
	state.append(at, int_value(gd::int_field(state, entry, key::x, 0)));
	state.append(at, int_value(gd::int_field(state, entry, key::y, 0)));
	state.set(row, str(key::at), array_value(at));
	state.set(row, str(key::level), int_value(level_rules::level_of(state, dict_value(entry))));
	state.set(row, str(key::aboard), bool_value(water_travel_rules::hero_boat_id(state, dict_value(entry)) != key::empty));
	state.set(row, str(key::power), float_value(compat::snappedf(hero_power(state, entry), 1.0)));
	Value movement;
	const int64_t move = nested_lookup(state, entry, key::ai_hero, key::movement, movement) ? gd::to_int(state, ai::vget(state, movement, key::current, int_value(0))) : 0;
	state.set(row, str(key::move_), int_value(move));
	const ArrayRef planned = state.new_array();
	state.append(planned, str(ai::string_or_empty(state, plan, key::kind)));
	state.append(planned, str(chosen));
	state.append(planned, float_value(compat::snappedf(gd::float_field(state, plan, key::value, 0.0), 1.0)));
	state.append(planned, int_value(gd::int_field(state, plan, key::distance, -1)));
	state.set(row, str(key::plan), array_value(planned));
	double blocked_need = 0.0;
	Value block;
	if (state.lookup(entry, str(key::ai_hero), block)) {
		blocked_need = gd::to_float(ai::vget(state, block, key::blocked_need, float_value(0.0)));
	}
	state.set(row, str(key::blocked_need), float_value(compat::snappedf(blocked_need, 1.0)));
	state.set(row, str(key::alternatives), array_value(alternatives));
	state.append(log, dict_value(row));
	state.set(session_flags(state, session), str(key::ai_decision_log), array_value(log));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
