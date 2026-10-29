// AiHeroRules: errands past the subterranean gates a hero can walk to, and the
// routes through any number of gates to towns and unseen ground elsewhere.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cmath>
#include <limits>
#include <string>
#include <unordered_map>
#include <vector>

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

constexpr int64_t kStopEncounter = 4; // STOP_ENCOUNTER
// Days after crossing a gate a hero takes another only toward its errand.
constexpr int64_t kGateCommitDays = 3;
constexpr double kInf = std::numeric_limits<double>::infinity();

// A Dictionary local whose `{}` fallback GDScript only reads: not present
// stands for that empty Dictionary.
struct Dict {
	DictRef ref = 0;
	bool present = false;

	bool empty(const State &state) const { return !present || state.dict_size(ref) == 0; }
};

// var x: Dictionary = dict.get(name, {})
Dict typed_dict(const State &state, DictRef dict, const Value &name) {
	Dict result;
	Value found;
	if (state.lookup(dict, name, found)) {
		result.ref = gd::as_dict(found);
		result.present = true;
	}
	return result;
}

// dict.get(name, {}) if dict.get(name, {}) is Dictionary else {}
Dict dict_if_dict(const State &state, const Dict &dict, Atom name) {
	Dict result;
	Value found;
	if (dict.present && state.lookup(dict.ref, str(name), found) && gd::is_dict(found)) {
		result.ref = found.ref;
		result.present = true;
	}
	return result;
}

// var x: Array = dict.get(name, []), only indexed: a new empty one when missing.
ArrayRef typed_array(State &state, DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? gd::as_array(found) : state.new_array();
}

// int(avoid.get(id, -1))
int64_t avoided_until(const State &state, const Dict &avoid, Atom id) {
	return avoid.present ? gd::to_int(state, state.get(avoid.ref, str(id), int_value(-1))) : -1;
}

// var size: Vector2i = context.map_size
Vector2i map_size(const State &state, DictRef context) {
	const Value size = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size) + "' to a variable of type 'Vector2i'.");
	}
	return Vector2i::of(size.vx(), size.vy());
}

// var v: Vector3i = value
Value as_vector3i(const Value &value) {
	if (!gd::is_vector3i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector3i'.");
	}
	return value;
}

// tile % width and tile / width of GDScript ints.
int64_t tile_x(int64_t tile, int64_t width) {
	if (width == 0) {
		throw state::ScriptError("Modulo by zero error in operator '%'.");
	}
	return compat::int_mod(tile, width);
}

int64_t tile_y(int64_t tile, int64_t width) {
	if (width == 0) {
		throw state::ScriptError("Division by zero error in operator '/'.");
	}
	return compat::int_div(tile, width);
}

// for ref in refs: the int(ref.index) of the first STOP_ENCOUNTER, or -1.
int64_t first_guard(State &state, const Value &refs) {
	for (const Value &ref : gd::items(state, refs)) {
		if (gd::to_int(state, ai::vmember(state, ref, key::kind)) == kStopEncounter) {
			return gd::to_int(state, ai::vmember(state, ref, key::index));
		}
	}
	return -1;
}

// String(encounters[index].get("placement_id", ""))
Atom encounter_id(State &state, ArrayRef encounters, int64_t index) {
	return gd::stringify(state, ai::vget(state, state.at(encounters, index), key::placement_id, str(key::empty)));
}

// "gate:%s" % String(nodes[int(gate.node)].get("placement_id", ""))
Atom gate_id(State &state, ArrayRef nodes, const Value &gate) {
	const int64_t node = gd::to_int(state, ai::vmember(state, gate, key::node));
	const Atom placement_id = gd::stringify(state, ai::vget(state, state.at(nodes, node), key::placement_id, str(key::empty)));
	return gd::format(state, key::gate_s, {str(placement_id)});
}

} // namespace

namespace ai_hero_rules {

bool _plans_far(State &state, DictRef session, DictRef context, DictRef entry) {
	const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
	return placement_id == _decision_main_id(state, session, context) || gd::array_has(state, _decision_field_ids(state, session, context), str(placement_id));
}

DictRef _gate_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, int64_t beyond_radius, bool any_errand) {
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const Dict gates = typed_dict(state, _level_surface(state, session, context, level), str(key::gates));
	if (gates.empty(state) || !state.has(search, str(key::dist))) {
		return state.new_dict();
	}
	const Dict block = typed_dict(state, entry, str(key::ai_hero));
	const Dict avoid = dict_if_dict(state, block, key::avoid);
	const Dict goal = dict_if_dict(state, block, key::goal);
	const ArrayRef dangers = _dangers(state, session, context, entry);
	const Vector2i size = map_size(state, context);
	const Dict stops = typed_dict(state, search, str(key::stops));
	// For a few days after crossing a gate a hero takes another only toward the
	// errand it crossed for: what lies beyond changes faster than it walks there
	// (a garrison another hero empties, a rival hero that moves off, a threat
	// that passes), and re-weighing every day it crossed back and forth.
	const Atom errand_id = goal.present ? ai::string_or_empty(state, goal.ref, key::id) : key::empty;
	const int64_t crossed_day = block.present ? gd::int_field(state, block.ref, key::crossed_day, -1) : -1;
	const bool committed = !any_errand && crossed_day >= 0 && errand_id != key::empty && ai::session_int(state, session, key::day) < gd::add(crossed_day, kGateCommitDays);
	const PackedRef dist = gd::as_ints(gd::index(state, search, str(key::dist)));
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef nodes = typed_array(state, overworld, key::resource_nodes);
	const ArrayRef encounters = typed_array(state, overworld, key::encounters);
	const double power = hero_power(state, entry);
	const int64_t day = ai::session_int(state, session, key::day);
	const ArrayRef reachable = state.new_array();
	for (const Value &gate_tile : gd::items(state, dict_value(gates.ref))) {
		const int64_t tile = gd::to_int(state, gate_tile);
		if (tile >= gd::packed_size(state, dist) || gd::packed_int(state, dist, tile) < 0 || _in_hero_zone(state, search, tile)) {
			continue;
		}
		if (state.array_size(dangers) != 0 && _in_danger(state, dangers, tile_x(tile, size.x), tile_y(tile, size.x), level)) {
			continue;
		}
		const Value gate = gd::index(state, gates.ref, gate_tile);
		const Atom id = gate_id(state, nodes, gate);
		if (avoided_until(state, avoid, id) >= day) {
			continue;
		}
		int64_t guard_index = -1;
		Value refs;
		if (stops.present && state.lookup(stops.ref, int_value(tile), refs)) {
			guard_index = first_guard(state, refs);
		}
		if (guard_index >= 0 && avoided_until(state, avoid, encounter_id(state, encounters, guard_index)) >= day) {
			continue;
		}
		const DictRef option = state.new_dict();
		state.set(option, str(key::tile), int_value(tile));
		state.set(option, str(key::distance), int_value(gd::packed_int(state, dist, tile)));
		state.set(option, str(key::id), str(id));
		state.set(option, str(key::gate), gate);
		state.set(option, str(key::guard), int_value(guard_index));
		state.append(reachable, dict_value(option));
	}
	gd::sort_custom(state, reachable, [&state](const Value &a, const Value &b) {
		return gd::to_int(state, ai::vmember(state, a, key::distance)) < gd::to_int(state, ai::vmember(state, b, key::distance));
	});
	// The gates that start a longer way to a town or to unseen ground are
	// weighed too, however far they lie: for every hero to its own towns
	// holding troops, for the main and field armies to the rest as well.
	Dict routes;
	routes.ref = _gate_routes(state, session, context, entry, search, movement_max);
	routes.present = true;
	const int64_t max_gates = ai::static_int(state, key::ai_hero_rules_script, key::MAX_GATES_WEIGHED);
	const ArrayRef options = gd::slice(state, reachable, 0, max_gates);
	// A gate past the player's own heroes is weighed at the walk with them
	// stepped aside (`_gate_walk`).
	if (!routes.empty(state)) {
		DictRef past = 0;
		bool past_made = false;
		const state::ValueList route_tiles = state.dict(routes.ref).keys.list();
		for (const Value &route_tile : route_tiles) {
			const int64_t tile = gd::to_int(state, route_tile);
			if (tile >= gd::packed_size(state, dist) || gd::packed_int(state, dist, tile) >= 0 || !state.has(gates.ref, int_value(tile))) {
				continue;
			}
			if (!past_made || gd::is_empty(state, past)) {
				const int64_t radius = gd::to_int(state, state.get(search, str(key::radius), int_value(gd::mul(movement_max, ai::static_int(state, key::ai_hero_rules_script, key::STRATEGIC_DAYS)))));
				past = _search(state, session, context, entry, radius, true);
				past_made = true;
			}
			const PackedRef past_dist = gd::as_ints(gd::index(state, past, str(key::dist)));
			if (gd::packed_int(state, past_dist, tile) < 0 || _in_hero_zone(state, past, tile)) {
				continue;
			}
			if (state.array_size(dangers) != 0 && _in_danger(state, dangers, tile_x(tile, size.x), tile_y(tile, size.x), level)) {
				continue;
			}
			const Value gate = gd::index(state, gates.ref, int_value(tile));
			const Atom id = gate_id(state, nodes, gate);
			if (avoided_until(state, avoid, id) >= day) {
				continue;
			}
			int64_t guard_index = -1;
			Value past_stops;
			if (state.lookup(past, str(key::stops), past_stops)) {
				if (!gd::is_dict(past_stops)) {
					(void)ai::vget(state, past_stops, int_value(tile));
				}
				Value refs;
				if (state.lookup(past_stops.ref, int_value(tile), refs)) {
					guard_index = first_guard(state, refs);
				}
			}
			if (guard_index >= 0 && avoided_until(state, avoid, encounter_id(state, encounters, guard_index)) >= day) {
				continue;
			}
			const DictRef option = state.new_dict();
			state.set(option, str(key::tile), int_value(tile));
			state.set(option, str(key::distance), int_value(gd::packed_int(state, past_dist, tile)));
			state.set(option, str(key::id), str(id));
			state.set(option, str(key::gate), gate);
			state.set(option, str(key::guard), int_value(guard_index));
			state.set(option, str(key::past_path), array_value(_path_to(state, past, tile)));
			state.append(options, dict_value(option));
		}
		const ArrayRef rest = gd::slice(state, reachable, max_gates);
		for (const Value &option : gd::items(state, array_value(rest))) {
			if (state.has(routes.ref, int_value(gd::to_int(state, ai::vmember(state, option, key::tile))))) {
				state.append(options, option);
			}
		}
	}
	const DictRef needs = _resource_needs(state, session, context);
	DictRef best = 0;
	bool has_best = false;
	double best_score = 0.0;
	for (const Value &option : gd::items(state, array_value(options))) {
		const int64_t option_guard = gd::to_int(state, ai::vmember(state, option, key::guard));
		double near = 0.0;
		if (option_guard >= 0) {
			near = _guard_fight_value(state, session, context, entry, option_guard, power, needs, search);
			if (std::isnan(near)) {
				continue;
			}
		}
		const Value option_gate = ai::vmember(state, option, key::gate);
		const DictRef beyond = _beyond_gate(state, session, context, entry, gd::as_dict(option_gate), movement_max, beyond_radius);
		// What lies beyond is kept for the turn; the hero may have given it up since.
		bool beyond_empty = gd::is_empty(state, beyond);
		if (!beyond_empty && avoided_until(state, avoid, gd::stringify(state, gd::index(state, beyond, str(key::id)))) >= day) {
			beyond_empty = true;
		}
		// A hostile hero beyond is there only for a hero that reaches it the day
		// it crosses: by the next day it has moved on, often away from the army
		// that came through, which would then cross back and forth after it.
		if (!beyond_empty) {
			const Atom beyond_kind = ai::string_or_empty(state, beyond, key::kind);
			if (beyond_kind == key::ai_hero || beyond_kind == key::hero) {
				const Dict movement = dict_if_dict(state, block, key::movement);
				const int64_t moves_left = movement.present ? gd::int_field(state, movement.ref, key::current, 0) : 0;
				const int64_t way = gd::add(gd::add(gd::to_int(state, ai::vmember(state, option, key::distance)), 1), gd::int_field(state, beyond, key::distance, 0));
				if (way > moves_left) {
					beyond_empty = true;
				}
			}
		}
		const int64_t option_tile = gd::to_int(state, ai::vmember(state, option, key::tile));
		Dict route;
		if (routes.present) {
			route = typed_dict(state, routes.ref, int_value(option_tile));
		}
		const bool route_empty = route.empty(state);
		if (beyond_empty && route_empty) {
			continue;
		}
		double value = near + (beyond_empty ? 0.0 : gd::float_field(state, beyond, key::value, 0.0));
		const int64_t option_distance = gd::to_int(state, ai::vmember(state, option, key::distance));
		int64_t distance = gd::add(option_distance, beyond_empty ? 0 : gd::int_field(state, beyond, key::distance, 0));
		Atom target_kind = beyond_empty ? key::empty : ai::string_or_empty(state, beyond, key::kind);
		Atom target_id = beyond_empty ? key::empty : ai::string_or_empty(state, beyond, key::id);
		if (!route_empty) {
			const double route_value = near + gd::to_float(gd::index(state, route.ref, str(key::value)));
			int64_t route_distance = compat::engine_max<int64_t>(option_distance, gd::to_int(state, gd::index(state, route.ref, str(key::distance))));
			// Past this one gate the way is walked from its exit, as the hero
			// will walk it there.
			const PackedRef far_dist = _gate_far_dist(state, context, entry, gd::as_dict(option_gate), beyond_radius);
			if (gd::to_bool(gd::field_or(state, route.ref, key::direct, bool_value(false)))) {
				const int64_t route_tile = gd::to_int(state, gd::index(state, route.ref, str(key::tile)));
				if (route_tile >= 0 && route_tile < gd::packed_size(state, far_dist) && gd::packed_int(state, far_dist, route_tile) >= 0) {
					route_distance = gd::add(gd::add(option_distance, 1), gd::packed_int(state, far_dist, route_tile));
				}
			}
			if (beyond_empty || route_value / (1.0 + static_cast<double>(route_distance) / static_cast<double>(movement_max)) > value / (1.0 + static_cast<double>(distance) / static_cast<double>(movement_max))) {
				value = route_value;
				distance = route_distance;
				target_kind = gd::stringify(state, gd::index(state, route.ref, str(key::kind)));
				target_id = gd::stringify(state, gd::index(state, route.ref, str(key::id)));
			}
		}
		if (value <= 0.0) {
			continue;
		}
		if (committed && target_id != errand_id && gd::stringify(state, ai::vmember(state, option, key::id)) != errand_id) {
			continue;
		}
		double score = value / (1.0 + static_cast<double>(distance) / static_cast<double>(movement_max));
		const DictRef target = state.new_dict();
		state.set(target, str(key::kind), str(target_kind));
		state.set(target, str(key::id), str(target_id));
		const DictRef plan = state.new_dict();
		state.set(plan, str(key::kind), str(key::gate));
		state.set(plan, str(key::id), str(gd::stringify(state, ai::vmember(state, option, key::id))));
		state.set(plan, str(key::index), int_value(gd::to_int(state, ai::vmember(state, option_gate, key::node))));
		state.set(plan, str(key::value), float_value(value));
		state.set(plan, str(key::tile_index), int_value(option_tile));
		state.set(plan, str(key::distance), int_value(distance));
		state.set(plan, str(key::beyond), dict_value(target));
		if (ai::vhas(state, option, str(key::past_path))) {
			state.set(plan, str(key::past_path), ai::vmember(state, option, key::past_path));
		}
		// beyond = {"far_guard": ..., "far_fight_power": ...} when nothing lies beyond.
		int64_t far_guard = -1;
		double far_fight_power = 0.0;
		if (beyond_empty) {
			const Value exit = as_vector3i(ai::vmember(state, option_gate, key::exit));
			const DictRef engagement = overworld_rules::_find_guard_engagement_at_tile(state, session, exit.vx(), exit.vy(), exit.vz(), false);
			far_guard = gd::int_field(state, engagement, key::index, -1);
			far_fight_power = gd::int_field(state, engagement, key::index, -1) >= 0 ? _guard_power(state, gd::as_dict(gd::index(state, engagement, str(key::encounter)))) : 0.0;
		}
		if (option_guard >= 0) {
			const DictRef guard = gd::as_dict(state.at(encounters, option_guard));
			const double guard_power = _guard_power(state, guard);
			const Atom guard_id = ai::string_or_empty(state, guard, key::placement_id);
			const double estimated_loss = _expected_loss_value(state, power, guard_power);
			state.set(plan, str(key::kind), str(key::encounter));
			state.set(plan, str(key::id), str(guard_id));
			state.set(plan, str(key::index), int_value(option_guard));
			state.set(plan, str(key::fight_power), float_value(guard_power));
			state.set(plan, str(key::estimated_loss), float_value(estimated_loss));
		} else {
			const int64_t beyond_far_guard = beyond_empty ? far_guard : gd::to_int(state, gd::index(state, beyond, str(key::far_guard)));
			if (beyond_far_guard >= 0) {
				const double beyond_far_power = beyond_empty ? far_fight_power : gd::to_float(gd::index(state, beyond, str(key::far_fight_power)));
				state.set(plan, str(key::far_guard), int_value(beyond_far_guard));
				state.set(plan, str(key::far_fight_power), float_value(beyond_far_power));
			}
		}
		const Atom goal_id = goal.present ? ai::string_or_empty(state, goal.ref, key::id) : key::empty;
		if (goal_id != key::empty) {
			const Atom option_id = gd::stringify(state, ai::vmember(state, option, key::id));
			const Atom plan_id = gd::stringify(state, gd::index(state, plan, str(key::id)));
			if (goal_id == option_id || goal_id == plan_id || goal_id == target_id) {
				score *= ai::static_float(state, key::ai_hero_rules_script, key::GOAL_CONTINUITY_BONUS);
			}
		}
		if (score > best_score) {
			best_score = score;
			state.set(plan, str(key::score), float_value(score));
			best = plan;
			has_best = true;
		}
	}
	if (has_best && state.has(context, str(key::decision_alternatives))) {
		_note_alternative(state, context, best, best_score, gd::to_int(state, gd::index(state, best, str(key::distance))));
	}
	return has_best ? best : state.new_dict();
}

DictRef _gate_routes(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max) {
	const Vector2i size = map_size(state, context);
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const int64_t start_tile = _tile_index_of(state, entry, size);
	// Only from where the hero stands, not as if at a gate's exit (`_beyond_gate`).
	if (gd::to_bool(gd::field_or(state, entry, key::ai_traveller, bool_value(false))) || start_tile < 0 || !state.has(search, str(key::dist))) {
		return state.new_dict();
	}
	Value found;
	const DictRef cache = state.lookup(context, str(key::decision), found) ? gd::as_dict(found) : state.new_dict();
	const Atom cache_key = gd::format(state, key::gate_routes_s_d_d, {str(ai::string_or_empty(state, entry, key::placement_id)), int_value(level), int_value(start_tile)});
	if (state.lookup(cache, str(cache_key), found)) {
		return gd::as_dict(found);
	}
	const DictRef result = state.new_dict();
	state.set(cache, str(cache_key), dict_value(result));
	state.set(context, str(key::decision), dict_value(cache));
	const DictRef map = _route_map(state, session, context);
	Value map_gates;
	if (!state.lookup(map, str(key::gates), map_gates) || ai::vempty(state, map_gates)) {
		return result;
	}
	const double power = hero_power(state, entry);
	// The objectives, by the losses a fight on the way to each may cost.
	const DictRef by_limit = state.new_dict();
	const ArrayRef towns = _route_towns(state, session, context, entry, power, map);
	for (const Value &town : gd::items(state, array_value(towns))) {
		const Value limit = float_value(_route_loss_limit(state, gd::to_float(ai::vmember(state, town, key::value))));
		if (!state.has(by_limit, limit)) {
			state.set(by_limit, limit, array_value(state.new_array()));
		}
		state.append(gd::as_array(gd::index(state, by_limit, limit)), town);
	}
	double explore_limit = -1.0;
	if (_plans_far(state, session, context, entry) && _rival_towns_unknown(state, session, context)) {
		explore_limit = _route_loss_limit(state, _explore_value(state, session, context));
		if (!state.has(by_limit, float_value(explore_limit))) {
			state.set(by_limit, float_value(explore_limit), array_value(state.new_array()));
		}
	}
	for (const Value &limit : gd::items(state, dict_value(by_limit))) {
		const double limit_value = gd::to_float(limit);
		_route_through(state, session, context, entry, search, movement_max, map, power, limit_value, gd::as_array(gd::index(state, by_limit, limit)), limit_value == explore_limit, result);
	}
	return result;
}

double _route_loss_limit(State &state, double value) {
	const double share = value * ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_KNOWN_SITE_SHARE);
	if (share < 1.0) {
		return 0.0;
	}
	return gd::math_pow(state, 2.0, compat::godot_floor(gd::math_log(state, share) / gd::math_log(state, 2.0)));
}

void _route_through(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, DictRef map, double power, double limit, ArrayRef towns, bool explore, DictRef result) {
	const Dict goal = dict_if_dict(state, typed_dict(state, entry, str(key::ai_hero)), key::goal);
	const Atom goal_id = goal.present ? ai::string_or_empty(state, goal.ref, key::id) : key::empty;
	const Vector2i size = map_size(state, context);
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const int64_t start_tile = _tile_index_of(state, entry, size);
	const ArrayRef gates = gd::as_array(gd::index(state, map, str(key::gates)));
	const Atom home_key = _stretch_key(state, session, context, level, start_tile, power, limit, entry);
	if (home_key == key::empty) {
		return;
	}
	// The gates out of each stretch, and where each comes out.
	std::unordered_map<Atom, std::vector<int64_t>> by_region;
	std::vector<Atom> exit_keys;
	const int64_t count = state.array_size(gates);
	for (int64_t gate_index = 0; gate_index < count; ++gate_index) {
		const DictRef gate = gd::as_dict(state.at(gates, gate_index));
		const Atom region_key = _stretch_key(state, session, context, gd::to_int(state, gd::index(state, gate, str(key::level))), gd::to_int(state, gd::index(state, gate, str(key::tile))), power, limit, entry);
		exit_keys.push_back(_stretch_key(state, session, context, gd::to_int(state, gd::index(state, gate, str(key::exit_level))), gd::to_int(state, gd::index(state, gate, str(key::exit_tile))), power, limit, entry));
		if (region_key == key::empty || exit_keys[static_cast<size_t>(gate_index)] == key::empty) {
			continue;
		}
		by_region[region_key].push_back(gate_index);
	}
	const DictRef targets = state.new_dict();
	for (const Value &town : gd::items(state, array_value(towns))) {
		const Atom town_key = _stretch_key(state, session, context, gd::to_int(state, ai::vmember(state, town, key::level)), gd::to_int(state, ai::vmember(state, town, key::tile)), power, limit, entry);
		if (town_key == key::empty || town_key == home_key) {
			continue;
		}
		if (!state.has(targets, str(town_key))) {
			state.set(targets, str(town_key), array_value(state.new_array()));
		}
		state.append(gd::as_array(gd::index(state, targets, str(town_key))), town);
	}
	if (explore) {
		_route_unseen(state, session, context, entry, map, power, limit, home_key, targets);
	}
	if (gd::is_empty(state, targets)) {
		return;
	}
	// Shortest ways out through the gates whose guards it beats, cheapest first.
	std::vector<double> cost(static_cast<size_t>(count), kInf);
	std::vector<int64_t> first(static_cast<size_t>(count), -1);
	std::vector<char> settled(static_cast<size_t>(count), 0);
	const PackedRef dist = gd::as_ints(gd::index(state, search, str(key::dist)));
	const double detour = ai::static_float(state, key::ai_hero_rules_script, key::ROUTE_DETOUR);
	const auto home_gates = by_region.find(home_key);
	if (home_gates != by_region.end()) {
		for (const int64_t gate_index : home_gates->second) {
			const Value gate = state.at(gates, gate_index);
			const int64_t tile = gd::to_int(state, ai::vmember(state, gate, key::tile));
			if (!_route_gate_open(state, gd::as_dict(gate), power, limit)) {
				continue;
			}
			cost[static_cast<size_t>(gate_index)] = tile < gd::packed_size(state, dist) && gd::packed_int(state, dist, tile) >= 0 ? static_cast<double>(gd::packed_int(state, dist, tile)) : _tile_span(state, start_tile, tile, size) * detour;
			first[static_cast<size_t>(gate_index)] = gate_index;
		}
	}
	while (true) {
		int64_t current = -1;
		for (int64_t gate_index = 0; gate_index < count; ++gate_index) {
			const size_t at = static_cast<size_t>(gate_index);
			if (!settled[at] && cost[at] < kInf && (current < 0 || cost[at] < cost[static_cast<size_t>(current)])) {
				current = gate_index;
			}
		}
		if (current < 0) {
			break;
		}
		const size_t here = static_cast<size_t>(current);
		settled[here] = 1;
		// A way back onto the hero's own stretch leads nowhere its own gates do not.
		const Atom exit_key = exit_keys[here];
		if (exit_key == home_key) {
			continue;
		}
		const DictRef gate = gd::as_dict(state.at(gates, current));
		const double arrived = cost[here] + 1.0;
		const DictRef start_gate = gd::as_dict(state.at(gates, first[here]));
		for (const Value &target : gd::field_items(state, targets, str(exit_key))) {
			const double total = arrived + (gd::to_int(state, ai::vmember(state, target, key::tile)) >= 0 ? _tile_span(state, gd::to_int(state, gd::index(state, gate, str(key::exit_tile))), gd::to_int(state, ai::vmember(state, target, key::tile)), size) * detour : 0.0);
			double score = gd::to_float(ai::vmember(state, target, key::value)) / (1.0 + total / static_cast<double>(movement_max));
			// The hero's errand keeps its way through a gate against a slightly
			// better one there, as it does everywhere else.
			if (goal_id != key::empty && gd::stringify(state, ai::vmember(state, target, key::id)) == goal_id) {
				score *= ai::static_float(state, key::ai_hero_rules_script, key::GOAL_CONTINUITY_BONUS);
			}
			const int64_t start_gate_tile = gd::to_int(state, gd::index(state, start_gate, str(key::tile)));
			bool better = true;
			Value known;
			if (state.lookup(result, int_value(start_gate_tile), known)) {
				const DictRef known_route = gd::as_dict(known);
				better = gd::is_empty(state, known_route) || score > gd::to_float(gd::index(state, known_route, str(key::score)));
			}
			if (better) {
				const DictRef route = state.new_dict();
				state.set(route, str(key::kind), str(gd::stringify(state, ai::vmember(state, target, key::kind))));
				state.set(route, str(key::id), str(gd::stringify(state, ai::vmember(state, target, key::id))));
				state.set(route, str(key::value), float_value(gd::to_float(ai::vmember(state, target, key::value))));
				state.set(route, str(key::distance), int_value(compat::float_to_int(compat::godot_ceil(total))));
				state.set(route, str(key::score), float_value(score));
				state.set(route, str(key::tile), int_value(gd::to_int(state, ai::vmember(state, target, key::tile))));
				state.set(route, str(key::direct), bool_value(first[here] == current));
				state.set(result, int_value(start_gate_tile), dict_value(route));
			}
		}
		const auto next_gates = by_region.find(exit_key);
		if (next_gates == by_region.end()) {
			continue;
		}
		for (const int64_t next_index : next_gates->second) {
			const size_t next = static_cast<size_t>(next_index);
			if (settled[next] || !_route_gate_open(state, gd::as_dict(state.at(gates, next_index)), power, limit)) {
				continue;
			}
			const double through = arrived + _tile_span(state, gd::to_int(state, gd::index(state, gate, str(key::exit_tile))), gd::to_int(state, ai::vmember(state, state.at(gates, next_index), key::tile)), size) * detour;
			if (through < cost[next]) {
				cost[next] = through;
				first[next] = first[here];
			}
		}
	}
}

bool _route_gate_open(State &state, DictRef gate, double power, double limit) {
	const double guard_power = gd::to_float(gd::index(state, gate, str(key::guard_power)));
	return guard_power * ai::static_float(state, key::ai_hero_rules_script, key::GUARD_WIN_RATIO) <= power && _expected_loss_value(state, power, guard_power) <= limit;
}

DictRef _route_map(State &state, DictRef session, DictRef context) {
	Value found;
	if (state.lookup(context, str(key::route_map), found)) {
		return gd::as_dict(found);
	}
	const DictRef map = state.new_dict();
	const ArrayRef map_gates = state.new_array();
	const ArrayRef map_towns = state.new_array();
	const DictRef map_unseen = state.new_dict();
	state.set(map, str(key::gates), array_value(map_gates));
	state.set(map, str(key::towns), array_value(map_towns));
	state.set(map, str(key::unseen), dict_value(map_unseen));
	state.set(context, str(key::route_map), dict_value(map));
	const int64_t levels = level_rules::level_count(state, session);
	if (levels < 2) {
		return map;
	}
	const Vector2i size = map_size(state, context);
	for (int64_t gate_level = 0; gate_level < levels; ++gate_level) {
		const Dict level_gates = typed_dict(state, _level_surface(state, session, context, gate_level), str(key::gates));
		if (!level_gates.present) {
			continue;
		}
		for (const Value &gate_tile : gd::items(state, dict_value(level_gates.ref))) {
			const Value exit = as_vector3i(ai::vmember(state, gd::index(state, level_gates.ref, gate_tile), key::exit));
			if (exit.vz() < 0 || exit.vz() >= levels) {
				continue;
			}
			const int64_t exit_tile = gd::add(gd::mul(exit.vy(), size.x), exit.vx());
			double guard_power = 0.0;
			const int64_t tile = gd::to_int(state, gate_tile);
			const Value spots[2] = {gd::vector3i(static_cast<int32_t>(tile_x(tile, size.x)), static_cast<int32_t>(tile_y(tile, size.x)), static_cast<int32_t>(gate_level)), exit};
			for (const Value &spot : spots) {
				const DictRef guard = overworld_rules::_find_guard_engagement_at_tile(state, session, spot.vx(), spot.vy(), spot.vz(), false);
				if (gd::int_field(state, guard, key::index, -1) >= 0) {
					guard_power = compat::engine_max(guard_power, _guard_power(state, gd::as_dict(gd::index(state, guard, str(key::encounter)))));
				}
			}
			const DictRef gate = state.new_dict();
			state.set(gate, str(key::tile), int_value(tile));
			state.set(gate, str(key::level), int_value(gate_level));
			state.set(gate, str(key::exit_tile), int_value(exit_tile));
			state.set(gate, str(key::exit_level), int_value(exit.vz()));
			state.set(gate, str(key::guard_power), float_value(guard_power));
			state.append(map_gates, dict_value(gate));
		}
	}
	Value towns_value;
	if (state.lookup(session_view::overworld(state, session), str(key::towns), towns_value)) {
		const ArrayRef towns = gd::as_array(towns_value);
		const int64_t town_count = state.array_size(towns);
		for (int64_t index = 0; index < town_count; ++index) {
			const Value town = state.at(towns, index);
			if (!gd::is_dict(town)) {
				continue;
			}
			const int64_t town_level = level_rules::level_of(state, town);
			const int64_t door = _tile_index_of(state, level_rules::town_entrance(state, town.ref), size);
			if (door < 0 || town_level < 0 || town_level >= levels) {
				continue;
			}
			if (_town_seen(state, _explored(state, session, context, town_level), town.ref, size)) {
				const DictRef seen = state.new_dict();
				state.set(seen, str(key::index), int_value(index));
				state.set(seen, str(key::level), int_value(town_level));
				state.set(seen, str(key::door), int_value(door));
				state.append(map_towns, dict_value(seen));
			}
		}
	}
	for (int64_t target_level = 0; target_level < levels; ++target_level) {
		const PackedRef patches = gd::as_ints(gd::index(state, _level_regions(state, session, context, target_level), str(key::patches)));
		const PackedRef known = _explored(state, session, context, target_level);
		const DictRef unseen = state.new_dict();
		const int64_t tile_count = compat::engine_min(gd::packed_size(state, patches), gd::packed_size(state, known));
		// unseen[patch] = int(unseen.get(patch, 0)) + 1, counted here and
		// written in the order the patches first appear.
		std::vector<int32_t> order;
		std::unordered_map<int32_t, int64_t> counts;
		const int32_t *patch_of = gd::packed_ints(state, patches);
		const uint8_t *known_of = gd::packed_bytes(state, known);
		for (int64_t tile = 0; tile < tile_count; ++tile) {
			if (known_of[tile] == 0 && patch_of[tile] >= 0) {
				const auto counted = counts.try_emplace(patch_of[tile], 0);
				if (counted.second) {
					order.push_back(patch_of[tile]);
				}
				counted.first->second += 1;
			}
		}
		for (const int32_t patch : order) {
			state.set(unseen, int_value(patch), int_value(counts[patch]));
		}
		state.set(map_unseen, int_value(target_level), dict_value(unseen));
	}
	return map;
}

ArrayRef _route_towns(State &state, DictRef session, DictRef context, DictRef entry, double power, DictRef map) {
	const ArrayRef towns = state.new_array();
	const Dict block = typed_dict(state, entry, str(key::ai_hero));
	const Dict avoid = dict_if_dict(state, block, key::avoid);
	const ArrayRef dangers = _dangers(state, session, context, entry);
	const Vector2i size = map_size(state, context);
	// Every hero goes to its own towns holding troops; only the main and
	// field armies go for the rest.
	const bool plans_far = _plans_far(state, session, context, entry);
	for (const Value &town_ref : gd::items(state, gd::index(state, map, str(key::towns)))) {
		const DictRef candidate = _town_candidate(state, session, context, entry, gd::to_int(state, ai::vmember(state, town_ref, key::index)), power);
		const Atom kind = ai::string_or_empty(state, candidate, key::kind);
		const bool target = kind == key::town_own || (plans_far && (kind == key::town_hostile || kind == key::town_neutral));
		if (!target || gd::float_field(state, candidate, key::value, 0.0) <= 0.0) {
			continue;
		}
		if (avoided_until(state, avoid, gd::stringify(state, gd::index(state, candidate, str(key::id)))) >= ai::session_int(state, session, key::day)) {
			continue;
		}
		// Within a much stronger hostile hero's reach it is left alone there
		// (`_best_candidate`), so no way leads to it either.
		if (state.array_size(dangers) != 0) {
			const int64_t door = gd::to_int(state, ai::vmember(state, town_ref, key::door));
			if (_in_danger(state, dangers, tile_x(door, size.x), tile_y(door, size.x), gd::to_int(state, ai::vmember(state, town_ref, key::level)))) {
				continue;
			}
		}
		const DictRef town = state.new_dict();
		state.set(town, str(key::kind), str(gd::stringify(state, gd::index(state, candidate, str(key::kind)))));
		state.set(town, str(key::id), str(gd::stringify(state, gd::index(state, candidate, str(key::id)))));
		state.set(town, str(key::value), float_value(gd::to_float(gd::index(state, candidate, str(key::value)))));
		state.set(town, str(key::level), int_value(gd::to_int(state, ai::vmember(state, town_ref, key::level))));
		state.set(town, str(key::tile), int_value(gd::to_int(state, ai::vmember(state, town_ref, key::door))));
		state.append(towns, dict_value(town));
	}
	return towns;
}

void _route_unseen(State &state, DictRef session, DictRef context, DictRef entry, DictRef map, double power, double limit, Atom home_key, DictRef targets) {
	const Dict block = typed_dict(state, entry, str(key::ai_hero));
	const Dict visits = dict_if_dict(state, block, key::route_visits);
	const double explore_value = _explore_value(state, session, context);
	// unseen[stretch_key] = int(unseen.get(stretch_key, 0)) + tiles, in the
	// order the stretches first appear.
	std::vector<Atom> order;
	std::unordered_map<Atom, int64_t> unseen;
	const DictRef map_unseen = gd::as_dict(gd::index(state, map, str(key::unseen)));
	for (const Value &target_level : gd::items(state, dict_value(map_unseen))) {
		const int64_t level = gd::to_int(state, target_level);
		const PackedRef stretches = _level_stretches(state, session, context, level, power, limit, entry);
		const DictRef level_unseen = gd::as_dict(gd::index(state, map_unseen, target_level));
		for (const Value &patch : gd::items(state, dict_value(level_unseen))) {
			const Atom stretch_key = gd::format(state, key::d_d, {int_value(level), int_value(gd::packed_int(state, stretches, gd::to_int(state, patch)))});
			const int64_t tiles = gd::to_int(state, gd::index(state, level_unseen, patch));
			const auto counted = unseen.try_emplace(stretch_key, 0);
			if (counted.second) {
				order.push_back(stretch_key);
			}
			counted.first->second = gd::add(counted.first->second, tiles);
		}
	}
	for (const Atom region_key : order) {
		const int64_t tiles = unseen[region_key];
		if (region_key == home_key || tiles < ai::static_int(state, key::ai_hero_rules_script, key::ROUTE_UNEXPLORED_MIN)) {
			continue;
		}
		if (visits.present && state.has(visits.ref, str(region_key)) && gd::add(gd::to_int(state, gd::index(state, visits.ref, str(region_key))), ai::static_int(state, key::ai_hero_rules_script, key::ROUTE_REVISIT_DAYS)) > ai::session_int(state, session, key::day)) {
			continue;
		}
		const double scaled = ai::static_float(state, key::ai_hero_rules_script, key::ELIMINATION_VALUE) * ai::static_float(state, key::ai_hero_rules_script, key::HIDDEN_RIVAL_SHARE);
		const double share = compat::engine_min(1.0, static_cast<double>(tiles) / static_cast<double>(ai::static_int(state, key::ai_hero_rules_script, key::HIDDEN_RIVAL_TILES)));
		const double value = explore_value + scaled * share;
		if (!state.has(targets, str(region_key))) {
			state.set(targets, str(region_key), array_value(state.new_array()));
		}
		const DictRef target = state.new_dict();
		state.set(target, str(key::kind), str(key::explore));
		state.set(target, str(key::id), str(gd::format(state, key::region_s, {str(region_key)})));
		state.set(target, str(key::value), float_value(value));
		state.set(target, str(key::tile), int_value(-1));
		state.append(gd::as_array(gd::index(state, targets, str(region_key))), dict_value(target));
	}
}

double _tile_span(State &state, int64_t from_tile, int64_t to_tile, Vector2i size) {
	(void)state;
	const int64_t across = compat::absi(gd::sub(tile_x(from_tile, size.x), tile_x(to_tile, size.x)));
	const int64_t down = compat::absi(gd::sub(tile_y(from_tile, size.x), tile_y(to_tile, size.x)));
	return static_cast<double>(compat::engine_max(across, down));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
