// AiHeroRules: what exploring and hunting for rivals' unseen towns is worth,
// what a town is worth as a target, and what a computer player can see.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

// The AI's tunables are AiHeroRules static vars.
double tunable(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

int64_t tunable_int(State &state, Atom name) {
	return ai::static_int(state, key::ai_hero_rules_script, name);
}

// String(context.controller).
Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

// var size: Vector2i = context.map_size
Vector2i context_map_size(State &state, DictRef context) {
	const Value size = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size) + "' to a variable of type 'Vector2i'.");
	}
	return Vector2i::of(size.vx(), size.vy());
}

// var cache: Dictionary = context.get("decision", {}): a new one is kept.
DictRef decision_cache(State &state, DictRef context) {
	Value found;
	return state.lookup(context, str(key::decision), found) ? gd::as_dict(found) : state.new_dict();
}

// x.get(name, {}) and x.get(name, []) of an untyped value, the fallback made
// only when the key is missing (get() of anything but a Dictionary is
// GDScript's error).
Value get_or_new_dict(State &state, const Value &object, Atom name) {
	if (!gd::is_dict(object)) {
		return ai::vget(state, object, name);
	}
	Value found;
	return state.lookup(object.ref, str(name), found) ? found : dict_value(state.new_dict());
}

Value get_or_new_array(State &state, const Value &object, Atom name) {
	if (!gd::is_dict(object)) {
		return ai::vget(state, object, name);
	}
	Value found;
	return state.lookup(object.ref, str(name), found) ? found : array_value(state.new_array());
}

// entry.get("enemy_army", {}).get("stacks", []).
Value army_stacks(State &state, DictRef entry) {
	Value army;
	if (!state.lookup(entry, str(key::enemy_army), army)) {
		return array_value(state.new_array());
	}
	return get_or_new_array(state, army, key::stacks);
}

// String(d.get(name, fallback)).
Atom string_or(State &state, DictRef dict, Atom name, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(name), str(fallback)));
}

// army_power(stacks), with its {} commander default.
double army_power_of(State &state, const Value &stacks) {
	return ai_hero_rules::army_power(state, stacks, dict_value(state.new_dict()));
}

// session.overworld.encounters[index], passed as a Dictionary.
DictRef encounter_at(State &state, DictRef session, int64_t index) {
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	return gd::as_dict(ai::vindex(state, encounters, int_value(index)));
}

} // namespace

namespace ai_hero_rules {

double _explore_value(State &state, DictRef session, DictRef context) {
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t start = tunable_int(state, key::HUNT_START_DAY);
	const int64_t full = tunable_int(state, key::HUNT_FULL_DAY);
	const double since = static_cast<double>(gd::sub(day, start));
	const double span = static_cast<double>(gd::sub(full, start));
	const double ramp = compat::engine_clamp(since / span, 0.0, 1.0);
	// Unseen ground is worth more as the game goes on: late in a game it is
	// where the last rivals' heroes and towns are. From HUNT_FULL_DAY it grows
	// with the day (twice as much at twice that day).
	const double late = full > 0 ? compat::engine_max(1.0, static_cast<double>(day) / static_cast<double>(full)) : 1.0;
	const double explore = tunable(state, key::EXPLORE_VALUE) * late;
	if (ramp <= 0.0 || !_rival_towns_unknown(state, session, context)) {
		return explore;
	}
	const double hunt = _hunt_value(state, session, context);
	return explore + hunt * ramp;
}

double _hunt_value(State &state, DictRef session, DictRef context) {
	const bool far_ahead = _far_ahead(state, session, context);
	const DictRef cache = decision_cache(state, context);
	Value cached;
	if (state.lookup(cache, str(key::hunt_value), cached)) {
		return gd::to_float(cached);
	}
	double hunt = tunable(state, key::HUNT_EXPLORE_VALUE);
	if (far_ahead) {
		double total = 0.0;
		int64_t count = 0;
		const ArrayRef owned_entries = enemy_turn_rules::_owned_town_entries(state, session, context_controller(state, context));
		for (const Value &owned : gd::items(state, array_value(owned_entries))) {
			total += _town_worth(state, session, context, gd::as_dict(get_or_new_dict(state, owned, key::town)));
			count += 1;
		}
		if (count > 0) {
			hunt = compat::engine_max(hunt, total / static_cast<double>(count));
		}
	}
	state.set(cache, str(key::hunt_value), float_value(hunt));
	state.set(context, str(key::decision), dict_value(cache));
	return hunt;
}

bool _rival_towns_unknown(State &state, DictRef session, DictRef context) {
	const DictRef cache = decision_cache(state, context);
	Value cached;
	if (state.lookup(cache, str(key::rival_towns_unknown), cached)) {
		return gd::to_bool(cached);
	}
	const Atom controller = context_controller(state, context);
	const Vector2i size = context_map_size(state, context);
	bool result = false;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town)) {
			continue;
		}
		const Atom owner = string_or(state, town.ref, key::owner, key::neutral);
		if (owner == key::neutral) {
			continue;
		}
		const Atom rival = owner == key::player ? key::player : player_rules::town_controller_id(state, town.ref);
		if (rival == controller || player_rules::allied(state, dict_value(session), controller, rival)) {
			continue;
		}
		if (!_town_seen(state, _explored(state, session, context, level_rules::level_of(state, town)), town.ref, size)) {
			result = true;
			break;
		}
	}
	state.set(cache, str(key::rival_towns_unknown), gd::bool_value(result));
	state.set(context, str(key::decision), dict_value(cache));
	return result;
}

DictRef _town_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power) {
	const Atom controller = context_controller(state, context);
	Value found;
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef towns = state.lookup(overworld, str(key::towns), found) ? gd::as_array(found) : state.new_array();
	const DictRef town = gd::as_dict(state.at(towns, index));
	const Atom owner = string_or(state, town, key::owner, key::neutral);
	if (owner != key::player && owner != key::enemy && owner != key::neutral) {
		return state.new_dict();
	}
	const Atom town_controller = owner != key::neutral ? player_rules::town_controller_id(state, town) : key::empty;
	const Atom id = ai::string_or_empty(state, town, key::placement_id);
	// _decision_field_ids(session, context).has(String(entry.get("placement_id", ""))).
	const auto field_hero = [&]() {
		const ArrayRef field_ids = _decision_field_ids(state, session, context);
		return gd::array_has(state, field_ids, str(ai::string_or_empty(state, entry, key::placement_id)));
	};
	if (owner == key::enemy && town_controller == controller) {
		int64_t visited_day = -1;
		Value block;
		if (state.lookup(entry, str(key::ai_hero), block)) {
			visited_day = gd::int_field(state, gd::as_dict(block), key::visited_town_day, -1);
		}
		if (visited_day == ai::session_int(state, session, key::day)) {
			return state.new_dict();
		}
		const DictRef entrance = level_rules::town_entrance(state, town);
		bool standing_here = false;
		const int64_t door_x = gd::int_field(state, entrance, key::x, -1);
		if (door_x == gd::int_field(state, entry, key::x, -2)) {
			const int64_t door_y = gd::int_field(state, entrance, key::y, -1);
			standing_here = door_y == gd::int_field(state, entry, key::y, -2);
		}
		if (!standing_here && !_town_entrance_free(state, session, town, controller)) {
			return state.new_dict();
		}
		double value = 0.0;
		const Atom main_id = _decision_main_id(state, session, context);
		// Only what the hero takes along and keeps counts: a full army leaves
		// creatures of other kinds behind, and the defence it leaves stays.
		const ArrayRef own_stacks = gd::as_array(gd::duplicate_value(state, army_stacks(state, entry), true));
		const ArrayRef pickup_stacks = gd::deep_duplicate_array(state, own_stacks);
		const Value pickup_garrison = gd::duplicate_value(state, get_or_new_array(state, dict_value(town), key::garrison), true);
		const DictRef pickup = _garrison_pickup(state, pickup_stacks, gd::as_array(pickup_garrison));
		const Value kept_stacks = gd::index(state, pickup, str(key::stacks));
		const Value left_stacks = gd::index(state, pickup, str(key::left));
		const bool leave_as_main = main_id == key::empty || main_id == ai::string_or_empty(state, entry, key::placement_id);
		const DictRef after = _leave_defense(state, session, context, town, gd::as_array(kept_stacks), gd::as_array(left_stacks), leave_as_main);
		const double after_power = army_power_of(state, gd::index(state, after, str(key::stacks)));
		const double own_power = army_power_of(state, array_value(own_stacks));
		const double gain = after_power - own_power;
		if (main_id == key::empty || main_id == ai::string_or_empty(state, entry, key::placement_id) || field_hero()) {
			const double per_power = tunable(state, key::TROOP_VALUE_PER_POWER);
			const double share = tunable(state, key::GARRISON_PICKUP_SHARE);
			value = gain * per_power * share;
		} else if (_ferries_from(state, session, context, town, main_id)) {
			const double per_power = tunable(state, key::TROOP_VALUE_PER_POWER);
			const double share = tunable(state, key::COURIER_TROOP_SHARE);
			const double cap = tunable(state, key::MEET_VALUE_CAP);
			value = compat::engine_min(gain * per_power * share, cap);
		} else {
			const ArrayRef stacks = gd::as_array(army_stacks(state, entry));
			if (state.array_size(stacks) > 1) {
				const double all_power = army_power_of(state, array_value(stacks));
				const int64_t weakest = _weakest_stack_index(state, stacks);
				const ArrayRef weakest_only = state.new_array();
				state.append(weakest_only, state.at(stacks, weakest));
				const double weakest_power = army_power_of(state, array_value(weakest_only));
				const double per_power = tunable(state, key::TROOP_VALUE_PER_POWER);
				const double share = tunable(state, key::COURIER_TROOP_SHARE);
				value = (all_power - weakest_power) * per_power * share;
			}
		}
		if (_town_threatened(state, session, context, town)) {
			const bool is_main = main_id == ai::string_or_empty(state, entry, key::placement_id) || field_hero();
			if (_would_hold_gate(state, session, context, entry, town, is_main)) {
				const double base = tunable(state, key::TOWN_BASE_VALUE);
				const double worth = _town_worth(state, session, context, town);
				const double kill_share = tunable(state, key::THREAT_KILL_SHARE);
				value += compat::engine_max(base, worth * kill_share);
			}
		}
		if (value <= tunable(state, key::MIN_TROOP_ERRAND_VALUE)) {
			return state.new_dict();
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::kind), str(key::town_own));
		state.set(result, str(key::id), str(id));
		state.set(result, str(key::index), int_value(index));
		state.set(result, str(key::value), float_value(value));
		return result;
	}
	if (owner != key::neutral && player_rules::allied(state, dict_value(session), controller, owner == key::enemy ? town_controller : key::player)) {
		return state.new_dict();
	}
	double defense = army_power_of(state, get_or_new_array(state, dict_value(town), key::garrison));
	const int64_t defender_index = _town_hero_defender_index(state, session, town, controller);
	if (defender_index >= 0) {
		defense += hero_power(state, encounter_at(state, session, defender_index));
	}
	if (owner == key::player) {
		const DictRef force = hero_command_rules::town_defense_force(state, session, town);
		const double garrison_power = army_power_of(state, get_or_new_array(state, dict_value(town), key::garrison));
		const Value hero_army = get_or_new_dict(state, get_or_new_dict(state, dict_value(force), key::hero), key::army);
		const Value hero_stacks = get_or_new_array(state, hero_army, key::stacks);
		const Value hero = get_or_new_dict(state, dict_value(force), key::hero);
		const double hero_power_value = army_power(state, hero_stacks, hero);
		defense = garrison_power + hero_power_value;
	}
	if (defense > 0.0 && power < defense * tunable(state, key::TOWN_ATTACK_RATIO)) {
		return state.new_dict();
	}
	// A town is worth its income and troops, the human's most of all; a faction
	// with no town left needs one to recruit at all.
	const double worth = _town_worth(state, session, context, town);
	double value = worth + (owner == key::player ? tunable(state, key::HUMAN_TOWN_BONUS) : 0.0);
	if (state.array_size(enemy_turn_rules::_owned_town_entries(state, session, controller)) == 0) {
		value *= tunable(state, key::HOMELESS_TOWN_MULTIPLIER);
	}
	if (owner != key::neutral) {
		const double elimination = tunable(state, key::ELIMINATION_VALUE);
		const int64_t held = _towns_held_by(state, session, owner, town_controller);
		value += elimination / static_cast<double>(compat::engine_max<int64_t>(1, held));
	}
	const double loss = _expected_loss_value(state, power, defense);
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(owner != key::neutral ? key::town_hostile : key::town_neutral));
	state.set(result, str(key::id), str(id));
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::value), float_value(value - loss));
	state.set(result, str(key::fight_power), float_value(defense));
	return result;
}

bool _position_seen(State &state, DictRef session, DictRef context, DictRef position) {
	const Value radii = state.get(context, str(key::scout_radii), Value());
	ArrayRef own;
	const Value listed = state.get(context, str(key::sight_heroes), Value());
	if (gd::is_array(listed)) {
		own = listed.ref;
	} else {
		own = active_hero_entries(state, session, context_controller(state, context));
		if (state.has(context, str(key::sight_heroes))) {
			state.set(context, str(key::sight_heroes), array_value(own));
		}
	}
	const int64_t own_count = state.array_size(own);
	for (int64_t own_index = 0; own_index < own_count; ++own_index) {
		const DictRef entry = gd::as_dict(state.at(own, own_index));
		if (!level_rules::same_level(state, dict_value(entry), dict_value(position))) {
			continue;
		}
		int64_t radius = -1;
		if (gd::is_dict(radii)) {
			radius = gd::to_int(state, state.get(radii.ref, int_value(own_index), int_value(-1)));
		}
		if (radius < 0) {
			radius = hero_command_rules::scouting_radius_for_hero(state, gd::as_dict(get_or_new_dict(state, dict_value(entry), key::enemy_commander_state)));
			if (gd::is_dict(radii)) {
				state.set(radii.ref, int_value(own_index), int_value(radius));
			}
		}
		const int64_t position_x = gd::int_field(state, position, key::x, 0);
		const int64_t entry_x = gd::int_field(state, entry, key::x, 0);
		const int64_t position_y = gd::int_field(state, position, key::y, 0);
		const int64_t entry_y = gd::int_field(state, entry, key::y, 0);
		if (hero_command_rules::within_scout_radius(state, gd::sub(position_x, entry_x), gd::sub(position_y, entry_y), radius)) {
			return true;
		}
	}
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || string_or(state, town.ref, key::owner, key::empty) != key::enemy) {
			continue;
		}
		const Atom town_controller = player_rules::town_controller_id(state, town.ref);
		if (town_controller != context_controller(state, context) || !level_rules::same_level(state, town, dict_value(position))) {
			continue;
		}
		const int64_t position_x = gd::int_field(state, position, key::x, 0);
		const int64_t town_x = gd::int_field(state, town.ref, key::x, 0);
		const int64_t position_y = gd::int_field(state, position, key::y, 0);
		const int64_t town_y = gd::int_field(state, town.ref, key::y, 0);
		// TOWN_SIGHT_RADIUS
		if (hero_command_rules::within_scout_radius(state, gd::sub(position_x, town_x), gd::sub(position_y, town_y), 8)) {
			return true;
		}
	}
	return false;
}

DictRef _sight_context(State &state, Atom controller) {
	const DictRef radii = state.new_dict();
	const DictRef context = state.new_dict();
	state.set(context, str(key::controller), str(controller));
	state.set(context, str(key::scout_radii), dict_value(radii));
	state.set(context, str(key::sight_heroes), Value());
	return context;
}

ArrayRef _hostile_heroes(State &state, DictRef session, Atom controller) {
	const ArrayRef result = state.new_array();
	const DictRef context = _sight_context(state, controller);
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero) || player_rules::allied(state, dict_value(session), controller, key::player)) {
			continue;
		}
		if (!_player_hero_seen(state, session, context, hero.ref)) {
			continue;
		}
		const DictRef position = gd::as_dict(get_or_new_dict(state, hero, key::position));
		Value found;
		const DictRef movement = state.lookup(hero.ref, str(key::movement), found) && gd::is_dict(found) ? found.ref : state.new_dict();
		const Atom id = ai::string_or_empty(state, hero.ref, key::id);
		const int64_t x = gd::int_field(state, position, key::x, 0);
		const int64_t y = gd::int_field(state, position, key::y, 0);
		const int64_t level = level_rules::level_of(state, dict_value(position));
		const Value stacks = get_or_new_array(state, get_or_new_dict(state, hero, key::army), key::stacks);
		const double power = army_power(state, stacks, hero);
		const int64_t min_reach = tunable_int(state, key::THREAT_MIN_REACH);
		const int64_t reach = compat::engine_max(min_reach, gd::int_field(state, movement, key::max, 10));
		const DictRef hostile = state.new_dict();
		state.set(hostile, str(key::id), str(id));
		state.set(hostile, str(key::owner), str(key::player));
		state.set(hostile, str(key::x), int_value(x));
		state.set(hostile, str(key::y), int_value(y));
		state.set(hostile, str(key::level), int_value(level));
		state.set(hostile, str(key::power), float_value(power));
		state.set(hostile, str(key::reach), int_value(reach));
		state.append(result, dict_value(hostile));
	}
	// Other computer players' heroes threaten towns just as the human's do.
	for (const Value &entry_value : gd::items(state, array_value(active_hero_entries(state, session, key::empty)))) {
		const DictRef entry = gd::as_dict(entry_value);
		const Atom other = player_rules::raid_controller_id(state, entry);
		if (other == controller || player_rules::allied(state, dict_value(session), controller, other)) {
			continue;
		}
		if (!_position_seen(state, session, context, level_rules::position(state, entry))) {
			continue;
		}
		const Atom id = ai::string_or_empty(state, entry, key::placement_id);
		const int64_t x = gd::int_field(state, entry, key::x, 0);
		const int64_t y = gd::int_field(state, entry, key::y, 0);
		const int64_t level = level_rules::level_of(state, entry_value);
		const double power = hero_power(state, entry);
		const int64_t min_reach = tunable_int(state, key::THREAT_MIN_REACH);
		const int64_t reach = compat::engine_max(min_reach, _movement_max(state, entry));
		const DictRef hostile = state.new_dict();
		state.set(hostile, str(key::id), str(id));
		state.set(hostile, str(key::owner), str(other));
		state.set(hostile, str(key::x), int_value(x));
		state.set(hostile, str(key::y), int_value(y));
		state.set(hostile, str(key::level), int_value(level));
		state.set(hostile, str(key::power), float_value(power));
		state.set(hostile, str(key::reach), int_value(reach));
		state.append(result, dict_value(hostile));
	}
	return result;
}

bool _far_ahead(State &state, DictRef session, DictRef context) {
	const Atom main_id = _decision_main_id(state, session, context);
	const DictRef cache = decision_cache(state, context);
	Value cached;
	if (state.lookup(cache, str(key::far_ahead), cached)) {
		return gd::to_bool(cached);
	}
	const int64_t main_index = _entry_index(state, session, main_id);
	const double main_power = main_index >= 0 ? hero_power(state, encounter_at(state, session, main_index)) : 0.0;
	const DictRef known = state.new_dict();
	// context.state.get(SIGHTINGS_KEY, {}): a missing memory is no memory.
	const Value memory = ai::vget(state, gd::index(state, context, str(key::state)), key::ai_sightings, Value());
	if (gd::is_dict(memory)) {
		for (const Value &id : gd::items(state, memory)) {
			const Value seen = gd::index(state, memory.ref, id);
			if (gd::is_dict(seen)) {
				const Atom owner = ai::string_or_empty(state, seen.ref, key::owner);
				const double known_power = gd::to_float(state.get(known, str(owner), float_value(0.0)));
				const double seen_power = gd::float_field(state, seen.ref, key::power, 0.0);
				state.set(known, str(owner), float_value(known_power + seen_power));
			}
		}
	}
	const Atom controller = context_controller(state, context);
	const Vector2i size = context_map_size(state, context);
	bool town_found = false;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || string_or(state, town.ref, key::owner, key::neutral) == key::neutral) {
			continue;
		}
		const Atom rival = ai::string_or_empty(state, town.ref, key::owner) == key::player ? key::player : player_rules::town_controller_id(state, town.ref);
		if (rival == controller || player_rules::allied(state, dict_value(session), controller, rival)) {
			continue;
		}
		if (_town_seen(state, _explored(state, session, context, level_rules::level_of(state, town)), town.ref, size)) {
			town_found = true;
			const double known_power = gd::to_float(state.get(known, str(rival), float_value(0.0)));
			const double garrison_power = army_power_of(state, get_or_new_array(state, town, key::garrison));
			state.set(known, str(rival), float_value(known_power + garrison_power));
		}
	}
	double strongest = 0.0;
	for (const Value &rival : gd::items(state, dict_value(known))) {
		strongest = compat::engine_max(strongest, gd::to_float(gd::index(state, known, rival)));
	}
	const bool far_ahead = town_found && main_power > strongest * tunable(state, key::HERO_ATTACK_RATIO);
	state.set(cache, str(key::far_ahead), gd::bool_value(far_ahead));
	state.set(context, str(key::decision), dict_value(cache));
	return far_ahead;
}

bool _town_seen(State &state, PackedRef known, DictRef town, Vector2i size) {
	const DictRef entrance = level_rules::town_entrance(state, town);
	const int64_t town_x = gd::int_field(state, town, key::x, -1);
	const int64_t town_y = gd::int_field(state, town, key::y, -1);
	const int64_t door_x = gd::int_field(state, entrance, key::x, -1);
	const int64_t door_y = gd::int_field(state, entrance, key::y, -1);
	const Vector2i tiles[2] = {Vector2i::of(town_x, town_y), Vector2i::of(door_x, door_y)};
	for (const Vector2i tile : tiles) {
		const int64_t index = static_cast<int64_t>(tile.y) * size.x + tile.x;
		if (tile.x >= 0 && tile.y >= 0 && tile.x < size.x && tile.y < size.y && index < gd::packed_size(state, known) && gd::packed_int(state, known, index) != 0) {
			return true;
		}
	}
	return false;
}

bool _player_hero_seen(State &state, DictRef session, DictRef context, DictRef hero) {
	// hero.get("position", {}) if it is a Dictionary, else {}.
	Value position;
	const bool listed = state.lookup(hero, str(key::position), position);
	const DictRef seen_at = listed && gd::is_dict(position) ? position.ref : state.new_dict();
	return _position_seen(state, session, context, seen_at);
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
