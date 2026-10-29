// AiHeroRules: how a computer player's heroes move outside their errands:
// gates, boats, portals, parking at home, stepping aside and evading.

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include <cstddef>
#include <initializer_list>
#include <limits>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace enemy_adventure_rules {
// Defined in enemy_states.cpp (Phase 5); no header declares it.
gd::DictRef sync_commander_army_continuity(state::State &state, gd::DictRef commander_state, const state::Value &army_source, gd::Atom encounter_id);
} // namespace enemy_adventure_rules

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
namespace player_rules = player_identity_rules;

constexpr double kInf = std::numeric_limits<double>::infinity();
// AiHeroRules.STOP_ENCOUNTER.
constexpr int64_t kStopEncounter = 4;
// AiHeroRules.NEIGHBOR_DX and NEIGHBOR_DY.
constexpr int64_t kNeighborDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
constexpr int64_t kNeighborDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};

double tunable_float(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

int64_t tunable_int(State &state, Atom name) {
	return ai::static_int(state, key::ai_hero_rules_script, name);
}

// var x: Dictionary = d.get(field, {}) and var x: Array = d.get(field, []):
// the container, or a new one when the field is missing.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

ArrayRef array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_array(found) : state.new_array();
}

// d.get(field, []) passed on: the value, or a new empty Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// holder.get(path[0], {}).get(path[1], {})...get(field, fallback): the {}
// only read, so a missing step answers the fallback.
Value nested_get(State &state, const Value &holder, std::initializer_list<Atom> path, Atom field, const Value &fallback) {
	Value current = holder;
	for (const Atom step : path) {
		if (!gd::is_dict(current)) {
			return ai::vget(state, current, step);
		}
		Value next;
		if (!state.lookup(current.ref, str(step), next)) {
			return fallback;
		}
		current = next;
	}
	return ai::vget(state, current, field, fallback);
}

// int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get(field, fallback)).
int64_t movement_int(State &state, DictRef entry, Atom field, int64_t fallback) {
	return gd::to_int(state, nested_get(state, dict_value(entry), {key::ai_hero, key::movement}, field, int_value(fallback)));
}

// entry.get("enemy_army", {}).get("stacks", []) passed on.
Value army_stacks(State &state, DictRef entry) {
	return nested_get(state, dict_value(entry), {key::enemy_army}, key::stacks, array_value(state.new_array()));
}

// army_power(stacks) with its default commander {}.
double power_of(State &state, const Value &stacks) {
	return ai_hero_rules::army_power(state, stacks, dict_value(state.new_dict()));
}

// String(context.controller).
Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

// context.state.
Value context_state(State &state, DictRef context) {
	return gd::index(state, context, str(key::state));
}

// context.state.treasury.
Value context_treasury(State &state, DictRef context) {
	return ai::vmember(state, context_state(state, context), key::treasury);
}

// var v: Vector2i = value and var v: Vector3i = value.
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return Vector2i::of(value.vx(), value.vy());
}

Value as_vector3i(const Value &value) {
	if (!gd::is_vector3i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector3i'.");
	}
	return value;
}

// var size: Vector2i = context.map_size.
Vector2i context_map_size(State &state, DictRef context) {
	return as_vector2i(gd::index(state, context, str(key::map_size)));
}

// session.overworld.encounters[index] as a Dictionary.
DictRef encounter_at(State &state, DictRef session, int64_t index) {
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	return gd::as_dict(ai::vindex(state, encounters, int_value(index)));
}

// int(search.dist[tile_index]).
int64_t dist_at(State &state, DictRef search, int64_t tile_index) {
	return gd::to_int(state, ai::vindex(state, gd::index(state, search, str(key::dist)), int_value(tile_index)));
}

// tile.y * size.x + tile.x of an untyped tile.
Value tile_key(State &state, const Value &tile, Vector2i size) {
	const Value y = ai::vmember(state, tile, key::y);
	const Value x = ai::vmember(state, tile, key::x);
	return gd::op_add(gd::op_mul(y, int_value(size.x)), x);
}

// y * size.x + x of ints.
int64_t index_of(int64_t x, int64_t y, Vector2i size) {
	return gd::add(gd::mul(y, size.x), x);
}

// a % b and a / b of ints.
int64_t checked_mod(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '%'.");
	}
	return compat::int_mod(a, b);
}

int64_t checked_div(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '/'.");
	}
	return compat::int_div(a, b);
}

// maxi(absi(dx), absi(dy)).
int64_t chebyshev(int64_t dx, int64_t dy) {
	return compat::engine_max<int64_t>(compat::absi(dx), compat::absi(dy));
}

// {"kind": kind, "id": id, "index": tile, "value": 0.0, "tile_index": tile, "distance": distance}.
DictRef tile_plan(State &state, Atom kind, Atom id, int64_t tile, int64_t distance) {
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::kind), str(kind));
	state.set(plan, str(key::id), str(id));
	state.set(plan, str(key::index), int_value(tile));
	state.set(plan, str(key::value), float_value(0.0));
	state.set(plan, str(key::tile_index), int_value(tile));
	state.set(plan, str(key::distance), int_value(distance));
	return plan;
}

// {"arrived": true, "acted": false}.
DictRef not_acted(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(true));
	state.set(result, str(key::acted), bool_value(false));
	return result;
}

// var x: PackedByteArray = search.get(field, PackedByteArray()): false when
// the field is missing (an empty array).
bool bytes_field(State &state, DictRef dict, Atom field, PackedRef &out) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return false;
	}
	out = gd::as_bytes(found);
	return true;
}

// var order: PackedInt32Array = search.get("order", PackedInt32Array()).
PackedRef order_of(State &state, DictRef search) {
	Value found;
	return state.lookup(search, str(key::order), found) ? gd::as_ints(found) : gd::new_ints(state);
}

} // namespace

namespace ai_hero_rules {

DictRef _nearest_owned_town(State &state, DictRef session, Atom controller, Vector2i tile, int64_t level) {
	DictRef best = state.new_dict();
	int64_t best_distance = int64_t(1) << 30;
	const ArrayRef towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	for (int64_t index = 0; index < state.array_size(towns); ++index) {
		const Value town = state.at(towns, index);
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != key::enemy || player_rules::town_controller_id(state, town.ref) != controller) {
			continue;
		}
		const int64_t dx = compat::absi(gd::sub(gd::int_field(state, town.ref, key::x, 0), tile.x));
		const int64_t dy = compat::absi(gd::sub(gd::int_field(state, town.ref, key::y, 0), tile.y));
		const int64_t distance = gd::add(gd::add(dx, dy), level_rules::level_of(state, town) == level ? 0 : 1000);
		if (distance < best_distance) {
			best_distance = distance;
			best = state.new_dict();
			state.set(best, str(key::index), int_value(index));
			state.set(best, str(key::placement_id), str(ai::string_or_empty(state, town.ref, key::placement_id)));
			state.set(best, str(key::town), town);
		}
	}
	return best;
}

bool _holds_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, bool is_main) {
	const DictRef threat = _strongest_threat(state, session, context, town);
	if (gd::is_empty(state, threat)) {
		return false;
	}
	const double threat_attack = gd::to_float(gd::index(state, threat, str(key::power))) * tunable_float(state, key::HERO_ATTACK_RATIO);
	if (threat_attack > hero_power(state, entry)) {
		// Holding the gate is worth it while the hero and the garrison make
		// the town too strong to storm; against more, the hero keeps out of reach.
		const double hero = hero_power(state, entry);
		const double garrison = power_of(state, field_or_new_array(state, town, key::garrison));
		const double defense = hero + garrison;
		if (!is_main) {
			return false;
		}
		const double threat_power = gd::to_float(gd::index(state, threat, str(key::power)));
		return threat_power < defense * tunable_float(state, key::TOWN_ATTACK_RATIO);
	}
	const int64_t dx = gd::sub(gd::to_int(state, gd::index(state, threat, str(key::x))), gd::int_field(state, entry, key::x, 0));
	const int64_t dy = gd::sub(gd::to_int(state, gd::index(state, threat, str(key::y))), gd::int_field(state, entry, key::y, 0));
	const int64_t distance = chebyshev(dx, dy);
	if (distance <= movement_int(state, entry, key::current, 0)) {
		return false;
	}
	const double needed = gd::to_float(gd::index(state, threat, str(key::power))) * tunable_float(state, key::THREAT_RATIO);
	return !_leave_guard(state, session, context, entry, town, needed);
}

bool _leave_guard(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, double needed) {
	const double needed_left = needed - power_of(state, field_or_new_array(state, town, key::garrison));
	if (needed_left <= 0.0) {
		return true;
	}
	const DictRef army = dict_or_new(state, entry, key::enemy_army);
	// A missing "stacks" is a new [] (its duplicate), anything not an Array too.
	Value army_stack_list;
	const bool has_stacks = state.lookup(army, str(key::stacks), army_stack_list);
	const ArrayRef stacks = has_stacks && gd::is_array(army_stack_list) ? gd::deep_duplicate_array(state, army_stack_list.ref) : state.new_array();
	const double total = power_of(state, array_value(stacks));
	int64_t best = -1;
	int64_t best_count = 0;
	double best_cost = kInf;
	for (int64_t index = 0; index < state.array_size(stacks); ++index) {
		const DictRef stack = gd::as_dict(state.at(stacks, index));
		const DictRef one = gd::deep_duplicate_dict(state, stack);
		state.set(one, str(key::count), int_value(1));
		const ArrayRef single = state.new_array();
		state.append(single, dict_value(one));
		const double unit = power_of(state, array_value(single));
		if (unit <= 0.0) {
			continue;
		}
		const int64_t count = compat::float_to_int(compat::godot_ceil(needed_left / unit));
		const int64_t available = gd::int_field(state, stack, key::count, 0);
		if (count > available || (count == available && state.array_size(stacks) == 1)) {
			continue;
		}
		if (static_cast<double>(count) * unit < best_cost) {
			best_cost = static_cast<double>(count) * unit;
			best = index;
			best_count = count;
		}
	}
	if (best < 0 || best_cost > total * tunable_float(state, key::GUARD_SHARE_MAX)) {
		return false;
	}
	const DictRef guard = gd::deep_duplicate_dict(state, gd::as_dict(state.at(stacks, best)));
	state.set(guard, str(key::count), int_value(best_count));
	state.erase(guard, str(key::slot_index));
	const ArrayRef guards = state.new_array();
	state.append(guards, dict_value(guard));
	const DictRef placed = _merge_stacks_into(state, field_or_new_array(state, town, key::garrison), array_value(guards));
	Value left;
	if (state.lookup(placed, str(key::left), left) && !ai::vempty(state, left)) {
		return false;
	}
	const DictRef best_stack = gd::as_dict(state.at(stacks, best));
	const int64_t remaining = gd::sub(gd::int_field(state, best_stack, key::count, 0), best_count);
	state.set(best_stack, str(key::count), int_value(remaining));
	if (gd::to_int(state, gd::index(state, best_stack, str(key::count))) <= 0) {
		gd::remove_at(state, stacks, best);
	}
	const int64_t index = _entry_index(state, session, ai::string_or_empty(state, entry, key::placement_id));
	const int64_t town_index = gd::int_field(state, _find_town(state, session, ai::string_or_empty(state, town, key::placement_id)), key::index, -1);
	if (index < 0 || town_index < 0) {
		return false;
	}
	state.set(army, str(key::stacks), array_value(stacks));
	state.set(entry, str(key::enemy_army), dict_value(army));
	const DictRef commander = dict_or_new(state, entry, key::enemy_commander_state);
	state.set(entry, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(army), key::encounter_mire_raid)));
	_store_entry(state, session, index, entry);
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef towns = array_or_new(state, overworld, key::towns);
	const DictRef town_state = gd::as_dict(state.at(towns, town_index));
	state.set(town_state, str(key::garrison), field_or_new_array(state, placed, key::stacks));
	state.set(overworld, str(key::towns), array_value(towns));
	state.set(context, str(key::decision), dict_value(state.new_dict()));
	return true;
}

DictRef _visit_own_town_if_inside(State &state, DictRef session, DictRef context, int64_t index) {
	DictRef entry = encounter_at(state, session, index);
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	if (gd::int_field(state, block, key::visited_town_day, -1) == ai::session_int(state, session, key::day)) {
		return state.new_dict();
	}
	const DictRef town = _own_town_at(state, session, context_controller(state, context), entry);
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const int64_t count_before = _creature_total(state, army_stacks(state, entry));
	entry = _take_garrison(state, session, entry, town, context);
	const int64_t gold_before = gd::to_int(state, ai::vget(state, context_treasury(state, context), key::gold, int_value(0)));
	const double power_before = power_of(state, army_stacks(state, entry));
	const DictRef treasury = gd::as_dict(context_treasury(state, context));
	const int64_t day = ai::session_int(state, session, key::day);
	enemy_town_services::visit(state, town, entry, treasury, day, context_controller(state, context));
	const Atom controller = context_controller(state, context);
	const int64_t gold_after = gd::to_int(state, ai::vget(state, context_treasury(state, context), key::gold, int_value(0)));
	_economy_add(state, session, controller, key::service_gold, static_cast<double>(gd::sub(gold_before, gold_after)));
	const Atom upgrade_controller = context_controller(state, context);
	const double power_after = power_of(state, army_stacks(state, entry));
	_economy_add(state, session, upgrade_controller, key::upgraded_power, power_after - power_before);
	state.set(block, str(key::visited_town_day), int_value(ai::session_int(state, session, key::day)));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
	const int64_t gained = gd::sub(_creature_total(state, army_stacks(state, entry)), count_before);
	if (gained <= 0) {
		return state.new_dict();
	}
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(key::town));
	state.set(target, str(key::target_placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
	state.set(target, str(key::target_label), str(enemy_turn_rules::_town_name(state, town)));
	state.set(target, str(key::target_x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(target, str(key::target_y), int_value(gd::int_field(state, town, key::y, 0)));
	state.set(target, str(key::target_public_importance), str(key::low));
	const Atom name = hero_name(state, entry);
	const Atom town_name = enemy_turn_rules::_town_name(state, town);
	const Atom summary = gd::format(state, key::s_gathers_d_troops_at_s, {str(name), int_value(gained), str(town_name)});
	const ArrayRef reasons = state.new_array();
	state.append(reasons, str(key::garrison_taken));
	const DictRef event = _event(state, session, context, key::ai_hero_reinforced, entry, target, summary, reasons);
	const ArrayRef events = state.new_array();
	state.append(events, dict_value(event));
	const DictRef result = state.new_dict();
	state.set(result, str(key::events), array_value(events));
	return result;
}

DictRef _own_town_at(State &state, DictRef session, Atom controller, DictRef entry) {
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != key::enemy || player_rules::town_controller_id(state, town.ref) != controller) {
			continue;
		}
		const DictRef entrance = level_rules::town_entrance(state, town.ref);
		if (level_rules::same_level(state, dict_value(entrance), dict_value(entry)) && gd::int_field(state, entrance, key::x, -1) == gd::int_field(state, entry, key::x, -2)
				&& gd::int_field(state, entrance, key::y, -1) == gd::int_field(state, entry, key::y, -2)) {
			return town.ref;
		}
	}
	return state.new_dict();
}

DictRef _gate_home(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef town) {
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const DictRef surface = _level_surface(state, session, context, level);
	Value found;
	if (!state.lookup(surface, str(key::gates), found)) {
		return state.new_dict();
	}
	const DictRef gates = gd::as_dict(found);
	if (gd::is_empty(state, gates) || !state.has(search, str(key::dist))) {
		return state.new_dict();
	}
	const DictRef door = level_rules::town_entrance(state, town);
	const Vector2i size = context_map_size(state, context);
	const int64_t door_index = index_of(gd::int_field(state, door, key::x, 0), gd::int_field(state, door, key::y, 0), size);
	const DictRef stops = dict_or_new(state, search, key::stops);
	const PackedRef dist = gd::as_ints(gd::index(state, search, str(key::dist)));
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef encounters = array_or_new(state, overworld, key::encounters);
	const ArrayRef nodes = array_or_new(state, overworld, key::resource_nodes);
	const double power = hero_power(state, entry);
	const int64_t movement_max = compat::engine_max<int64_t>(1, movement_int(state, entry, key::max, 1));
	const ArrayRef reachable = state.new_array();
	const ArrayRef gate_tiles = gd::keys(state, gates);
	for (int64_t at = 0; at < state.array_size(gate_tiles); ++at) {
		const Value gate_tile = state.at(gate_tiles, at);
		const int64_t tile = gd::to_int(state, gate_tile);
		const Value gate_exit = as_vector3i(ai::vmember(state, gd::index(state, gates, gate_tile), key::exit));
		if (gate_exit.vz() != level_rules::level_of(state, dict_value(door)) || tile >= gd::packed_size(state, dist) || gd::packed_int(state, dist, tile) < 0 || _in_hero_zone(state, search, tile)) {
			continue;
		}
		const DictRef option = state.new_dict();
		state.set(option, str(key::tile), int_value(tile));
		state.set(option, str(key::distance), int_value(gd::packed_int(state, dist, tile)));
		state.set(option, str(key::gate), gd::index(state, gates, gate_tile));
		state.append(reachable, dict_value(option));
	}
	gd::sort_custom(state, reachable, [&state](const Value &a, const Value &b) {
		return gd::to_int(state, ai::vmember(state, a, key::distance)) < gd::to_int(state, ai::vmember(state, b, key::distance));
	});
	DictRef best = state.new_dict();
	const ArrayRef weighed = gd::slice(state, reachable, 0, tunable_int(state, key::MAX_GATES_WEIGHED));
	for (int64_t at = 0; at < state.array_size(weighed); ++at) {
		const Value option = state.at(weighed, at);
		int64_t guard_index = -1;
		const int64_t option_tile = gd::to_int(state, ai::vmember(state, option, key::tile));
		for (const Value &ref : gd::field_items(state, stops, int_value(option_tile))) {
			if (gd::to_int(state, ai::vmember(state, ref, key::kind)) == kStopEncounter) {
				guard_index = gd::to_int(state, ai::vmember(state, ref, key::index));
				break;
			}
		}
		if (guard_index >= 0) {
			const double guard_power = _guard_power(state, gd::as_dict(state.at(encounters, guard_index)));
			if (power < guard_power * tunable_float(state, key::GUARD_WIN_RATIO)) {
				continue;
			}
		}
		const Value exit = as_vector3i(ai::vmember(state, ai::vmember(state, option, key::gate), key::exit));
		const DictRef far_guard = overworld_rules::_find_guard_engagement_at_tile(state, session, exit.vx(), exit.vy(), exit.vz(), false);
		const int64_t far_index = gd::int_field(state, far_guard, key::index, -1);
		if (far_index >= 0) {
			const double far_power = _guard_power(state, gd::as_dict(gd::index(state, far_guard, str(key::encounter))));
			if (power < far_power * tunable_float(state, key::GUARD_WIN_RATIO)) {
				continue;
			}
		}
		const DictRef traveller = gd::duplicate_dict(state, entry);
		state.set(traveller, str(key::ai_traveller), bool_value(true));
		state.set(traveller, str(key::x), int_value(exit.vx()));
		state.set(traveller, str(key::y), int_value(exit.vy()));
		state.set(traveller, str(key::level), int_value(exit.vz()));
		const DictRef far_search = _search(state, session, context, traveller, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)));
		// Where guards keep the doorway out of reach for now, the hero still
		// goes up and waits nearer home; the straight way counts double.
		int64_t far_distance = -1;
		if (door_index >= 0 && door_index < ai::vsize(state, gd::index(state, far_search, str(key::dist)))) {
			far_distance = dist_at(state, far_search, door_index);
		}
		if (far_distance < 0) {
			const int64_t span = chebyshev(gd::sub(exit.vx(), gd::int_field(state, door, key::x, 0)), gd::sub(exit.vy(), gd::int_field(state, door, key::y, 0)));
			const int64_t detour = gd::mul(tunable_int(state, key::GATE_HOME_DETOUR), span);
			far_distance = gd::add(detour, gd::mul(movement_max, tunable_int(state, key::FAR_SEARCH_DAYS)));
		}
		const int64_t distance = gd::add(gd::to_int(state, ai::vmember(state, option, key::distance)), far_distance);
		if (!gd::is_empty(state, best) && distance >= gd::to_int(state, gd::index(state, best, str(key::distance)))) {
			continue;
		}
		const Atom town_id = ai::string_or_empty(state, town, key::placement_id);
		const Value gate = ai::vmember(state, option, key::gate);
		const Value node = state.at(nodes, gd::to_int(state, ai::vmember(state, gate, key::node)));
		const Atom gate_id = gd::format(state, key::gate_s, {str(gd::stringify(state, ai::vget(state, node, key::placement_id, str(key::empty))))});
		best = state.new_dict();
		state.set(best, str(key::kind), str(key::gate));
		state.set(best, str(key::id), str(gate_id));
		state.set(best, str(key::index), int_value(gd::to_int(state, ai::vmember(state, ai::vmember(state, option, key::gate), key::node))));
		state.set(best, str(key::value), float_value(0.0));
		state.set(best, str(key::tile_index), int_value(option_tile));
		state.set(best, str(key::distance), int_value(distance));
		const DictRef beyond = state.new_dict();
		state.set(beyond, str(key::kind), str(key::park));
		state.set(beyond, str(key::id), str(town_id));
		state.set(best, str(key::beyond), dict_value(beyond));
		if (guard_index >= 0) {
			const Value guard = state.at(encounters, guard_index);
			const double guard_power = _guard_power(state, gd::as_dict(guard));
			const DictRef fight = state.new_dict();
			state.set(fight, str(key::kind), str(key::encounter));
			state.set(fight, str(key::id), str(gd::stringify(state, ai::vget(state, state.at(encounters, guard_index), key::placement_id, str(key::empty)))));
			state.set(fight, str(key::index), int_value(guard_index));
			state.set(fight, str(key::value), float_value(1.0));
			state.set(fight, str(key::fight_power), float_value(guard_power));
			state.set(fight, str(key::estimated_loss), float_value(_expected_loss_value(state, power, guard_power)));
			gd::merge(state, best, fight, true);
		} else if (far_index >= 0) {
			const DictRef fight = state.new_dict();
			state.set(fight, str(key::value), float_value(1.0));
			state.set(fight, str(key::far_guard), int_value(far_index));
			state.set(fight, str(key::far_fight_power), float_value(_guard_power(state, gd::as_dict(gd::index(state, far_guard, str(key::encounter))))));
			gd::merge(state, best, fight, true);
		}
	}
	if (gd::is_empty(state, best) || !_gate_fight_looks_good(state, session, context, entry, best)) {
		return state.new_dict();
	}
	return best;
}

DictRef _evade(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	const ArrayRef dangers = _dangers(state, session, context, entry);
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	if (state.array_size(dangers) == 0 || !_in_danger(state, dangers, gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0), level)) {
		return state.new_dict();
	}
	const Vector2i size = context_map_size(state, context);
	const int64_t today = movement_int(state, entry, key::current, 0);
	const PackedRef order = order_of(state, search);
	const DictRef stops = dict_or_new(state, search, key::stops);
	int64_t best_tile = -1;
	int64_t best_gap = _danger_gap(state, dangers, gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0), level);
	const int64_t order_count = gd::int_field(state, search, key::order_count, 0);
	for (int64_t position = 1; position < order_count; ++position) {
		const int64_t tile_index = gd::packed_int(state, order, position);
		if (dist_at(state, search, tile_index) > today || state.has(stops, int_value(tile_index))) {
			continue;
		}
		const int64_t gap = _danger_gap(state, dangers, checked_mod(tile_index, size.x), checked_div(tile_index, size.x), level);
		if (gap > best_gap) {
			best_gap = gap;
			best_tile = tile_index;
		}
	}
	if (best_tile < 0) {
		return state.new_dict();
	}
	const Atom id = gd::format(state, key::evade_d, {int_value(best_tile)});
	return tile_plan(state, key::wait, id, best_tile, dist_at(state, search, best_tile));
}

int64_t _danger_gap(State &state, ArrayRef dangers, int64_t x, int64_t y, int64_t level) {
	int64_t gap = int64_t(1) << 20;
	for (const Value &threat : gd::items(state, array_value(dangers))) {
		if (gd::to_int(state, ai::vget(state, threat, key::level, int_value(0))) != level) {
			continue;
		}
		const int64_t dx = gd::sub(gd::to_int(state, ai::vmember(state, threat, key::x)), x);
		const int64_t dy = gd::sub(gd::to_int(state, ai::vmember(state, threat, key::y)), y);
		const int64_t reach = gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10)));
		gap = compat::engine_min<int64_t>(gap, gd::sub(gd::sub(chebyshev(dx, dy), reach), 1));
	}
	return gap;
}

bool _clear_way(State &state, DictRef session, DictRef context, DictRef entry, int64_t radius, int64_t movement_max) {
	const Atom controller = context_controller(state, context);
	const DictRef past = _search(state, session, context, entry, radius, true);
	const DictRef best = _vetted_candidate(state, session, context, entry, past, movement_max);
	if (gd::is_empty(state, best)) {
		return false;
	}
	const Vector2i size = context_map_size(state, context);
	const DictRef keep_clear = state.new_dict();
	const ArrayRef path = _path_to(state, past, gd::to_int(state, gd::index(state, best, str(key::tile_index))));
	for (int64_t at = 0; at < state.array_size(path); ++at) {
		state.set(keep_clear, tile_key(state, state.at(path, at), size), bool_value(true));
	}
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const DictRef doors = _own_town_doors(state, session, controller, level, size);
	bool moved = false;
	const ArrayRef others = active_hero_entries(state, session, controller);
	for (int64_t at = 0; at < state.array_size(others); ++at) {
		const Value other = state.at(others, at);
		const Atom other_id = gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty)));
		if (other_id == ai::string_or_empty(state, entry, key::placement_id) || level_rules::level_of(state, other) != level) {
			continue;
		}
		const int64_t other_y = gd::to_int(state, ai::vget(state, other, key::y, int_value(0)));
		const int64_t other_index = index_of(gd::to_int(state, ai::vget(state, other, key::x, int_value(0))), other_y, size);
		if (!state.has(keep_clear, int_value(other_index)) || state.has(doors, int_value(other_index))) {
			continue;
		}
		// A hero busy with its own errand moves on by itself.
		const Atom goal_kind = gd::stringify(state, nested_get(state, other, {key::ai_hero, key::goal}, key::kind, str(key::empty)));
		if (goal_kind != key::empty && goal_kind != key::wait && goal_kind != key::park) {
			continue;
		}
		if (_make_way(state, session, context, gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty))), keep_clear)) {
			moved = true;
		}
	}
	return moved;
}

DictRef _gate_walk(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan, DictRef search) {
	if (!state.has(plan, str(key::past_path))) {
		state.set(plan, str(key::path), array_value(_path_to(state, search, gd::to_int(state, gd::index(state, plan, str(key::tile_index))))));
		return plan;
	}
	const ArrayRef path = gd::as_array(gd::index(state, plan, str(key::past_path)));
	const Vector2i size = context_map_size(state, context);
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const DictRef keep_clear = state.new_dict();
	for (int64_t at = 0; at < state.array_size(path); ++at) {
		state.set(keep_clear, tile_key(state, state.at(path, at), size), bool_value(true));
	}
	const DictRef doors = _own_town_doors(state, session, context_controller(state, context), level, size);
	const ArrayRef others = active_hero_entries(state, session, context_controller(state, context));
	for (int64_t at = 0; at < state.array_size(others); ++at) {
		const Value other = state.at(others, at);
		const Atom other_id = gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty)));
		if (other_id == ai::string_or_empty(state, entry, key::placement_id) || level_rules::level_of(state, other) != level) {
			continue;
		}
		const int64_t other_y = gd::to_int(state, ai::vget(state, other, key::y, int_value(0)));
		const int64_t other_index = index_of(gd::to_int(state, ai::vget(state, other, key::x, int_value(0))), other_y, size);
		if (state.has(keep_clear, int_value(other_index)) && !state.has(doors, int_value(other_index))) {
			_make_way(state, session, context, gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty))), keep_clear);
		}
	}
	const DictRef standing = state.new_dict();
	const ArrayRef heroes = active_hero_entries(state, session, context_controller(state, context));
	for (int64_t at = 0; at < state.array_size(heroes); ++at) {
		const Value other = state.at(heroes, at);
		const Atom other_id = gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty)));
		if (other_id != ai::string_or_empty(state, entry, key::placement_id) && level_rules::level_of(state, other) == level) {
			const int64_t other_y = gd::to_int(state, ai::vget(state, other, key::y, int_value(0)));
			const int64_t other_index = index_of(gd::to_int(state, ai::vget(state, other, key::x, int_value(0))), other_y, size);
			state.set(standing, int_value(other_index), bool_value(true));
		}
	}
	for (int64_t step = 0; step < state.array_size(path); ++step) {
		const Vector2i tile = as_vector2i(state.at(path, step));
		const int64_t tile_index = index_of(tile.x, tile.y, size);
		if (state.has(standing, int_value(tile_index)) && !state.has(doors, int_value(tile_index))) {
			if (step == 0) {
				return state.new_dict();
			}
			const Vector2i stop = as_vector2i(state.at(path, step - 1));
			const int64_t stop_index = index_of(stop.x, stop.y, size);
			const Atom id = gd::format(state, key::wait_d, {int_value(stop_index)});
			const DictRef waiting = tile_plan(state, key::wait, id, stop_index, step);
			state.set(waiting, str(key::path), array_value(gd::slice(state, path, 0, step)));
			return waiting;
		}
	}
	state.set(plan, str(key::path), array_value(path));
	return plan;
}

bool _make_way(State &state, DictRef session, DictRef context, Atom placement_id, DictRef keep_clear) {
	const int64_t index = _entry_index(state, session, placement_id);
	if (index < 0) {
		return false;
	}
	DictRef entry = encounter_at(state, session, index);
	if (movement_int(state, entry, key::current, 0) > 0) {
		const int64_t movement_max = compat::engine_max<int64_t>(1, movement_int(state, entry, key::max, 1));
		const int64_t radius = compat::engine_max<int64_t>(tunable_int(state, key::MIN_SEARCH_RADIUS), gd::mul(movement_max, tunable_int(state, key::SEARCH_DAYS)));
		const DictRef search = _search(state, session, context, entry, radius);
		const DictRef plan = _wait_by_home(state, session, context, entry, search, keep_clear);
		if (!gd::is_empty(state, plan)) {
			state.set(plan, str(key::path), array_value(_path_to(state, search, gd::to_int(state, gd::index(state, plan, str(key::tile_index))))));
			_follow_plan(state, session, context, index, plan);
			entry = encounter_at(state, session, index);
		}
	}
	const Vector2i size = context_map_size(state, context);
	const int64_t entry_y = gd::int_field(state, entry, key::y, 0);
	if (!state.has(keep_clear, int_value(index_of(gd::int_field(state, entry, key::x, 0), entry_y, size)))) {
		return true;
	}
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	const DictRef request = state.new_dict();
	state.set(request, str(key::until_day), int_value(gd::add(ai::session_int(state, session, key::day), 1)));
	state.set(request, str(key::tiles), array_value(gd::keys(state, keep_clear)));
	state.set(block, str(key::make_way), dict_value(request));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
	return false;
}

DictRef _pending_make_way(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	Value make_way;
	if (!state.lookup(block, str(key::make_way), make_way) || !gd::is_dict(make_way) || gd::is_empty(state, make_way.ref)) {
		return state.new_dict();
	}
	const DictRef request = gd::as_dict(gd::index(state, block, str(key::make_way)));
	state.erase(block, str(key::make_way));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, _entry_index(state, session, ai::string_or_empty(state, entry, key::placement_id)), entry);
	if (gd::int_field(state, request, key::until_day, -1) < ai::session_int(state, session, key::day)) {
		return state.new_dict();
	}
	const DictRef keep_clear = state.new_dict();
	for (const Value &tile_index : gd::field_items(state, request, str(key::tiles))) {
		state.set(keep_clear, int_value(gd::to_int(state, tile_index)), bool_value(true));
	}
	const Vector2i size = context_map_size(state, context);
	const int64_t entry_y = gd::int_field(state, entry, key::y, 0);
	if (!state.has(keep_clear, int_value(index_of(gd::int_field(state, entry, key::x, 0), entry_y, size)))) {
		return state.new_dict();
	}
	return _wait_by_home(state, session, context, entry, search, keep_clear);
}

DictRef _wait_by_home(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef keep_clear) {
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const Atom controller = context_controller(state, context);
	const Vector2i size = context_map_size(state, context);
	const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
	const DictRef doors = _own_town_doors(state, session, controller, level, size);
	const ArrayRef friends = state.new_array();
	const ArrayRef others = active_hero_entries(state, session, controller);
	for (int64_t at = 0; at < state.array_size(others); ++at) {
		const Value other = state.at(others, at);
		if (gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty))) == placement_id || level_rules::level_of(state, other) != level) {
			continue;
		}
		const int64_t other_x = gd::to_int(state, ai::vget(state, other, key::x, int_value(0)));
		const int64_t other_y = gd::to_int(state, ai::vget(state, other, key::y, int_value(0)));
		const Vector2i other_tile = Vector2i::of(other_x, other_y);
		// Heroes inside a town stand in no one's way.
		if (!state.has(doors, int_value(index_of(other_tile.x, other_tile.y, size)))) {
			state.append(friends, Value::of_vector2i(other_tile.x, other_tile.y));
		}
	}
	const Vector2i here = Vector2i::of(gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
	const int64_t here_index = index_of(here.x, here.y, size);
	Vector2i home = here;
	const Atom home_town_id = gd::stringify(state, nested_get(state, dict_value(entry), {key::ai_hero}, key::home_town_id, str(key::empty)));
	DictRef home_town = gd::as_dict(gd::index(state, _find_town(state, session, home_town_id), str(key::town)));
	if (gd::is_empty(state, home_town) || ai::string_or_empty(state, home_town, key::owner) != key::enemy || player_rules::town_controller_id(state, home_town) != controller
			|| level_rules::level_of(state, dict_value(level_rules::town_entrance(state, home_town))) != level) {
		home_town = dict_or_new(state, _nearest_owned_town(state, session, controller, here, level), key::town);
	}
	if (!gd::is_empty(state, home_town) && level_rules::level_of(state, dict_value(level_rules::town_entrance(state, home_town))) != level && gd::is_empty(state, keep_clear)) {
		// Every town of the player stands on the other level: home is through
		// a gate.
		const DictRef homeward = _gate_home(state, session, context, entry, search, home_town);
		if (!gd::is_empty(state, homeward)) {
			return homeward;
		}
	}
	if (!gd::is_empty(state, home_town)) {
		const DictRef entrance = level_rules::town_entrance(state, home_town);
		home = Vector2i::of(gd::int_field(state, entrance, key::x, here.x), gd::int_field(state, entrance, key::y, here.y));
		const int64_t door_index = index_of(home.x, home.y, size);
		const Atom town_id = ai::string_or_empty(state, home_town, key::placement_id);
		const Atom parked_id = _parked_hero_id(state, session, controller, town_id);
		if (level_rules::same_level(state, dict_value(entrance), dict_value(entry)) && (parked_id == key::empty || parked_id == placement_id)) {
			if (here_index == door_index) {
				_park(state, session, placement_id, town_id);
				return state.new_dict();
			}
			if (dist_at(state, search, door_index) >= 0 && !_in_hero_zone(state, search, door_index)) {
				return tile_plan(state, key::park, town_id, door_index, dist_at(state, search, door_index));
			}
		}
	}
	if (state.has(doors, int_value(here_index)) && !state.has(keep_clear, int_value(here_index))) {
		return state.new_dict();
	}
	const bool here_free = !state.has(keep_clear, int_value(here_index)) && !_next_to_any(state, here, friends) && !_cuts_a_way(state, search, here_index, size);
	const int64_t here_span = chebyshev(gd::sub(here.x, home.x), gd::sub(here.y, home.y));
	if (here_span <= tunable_int(state, key::HOME_WAIT_RADIUS) && here_free) {
		return state.new_dict();
	}
	const PackedRef order = order_of(state, search);
	const DictRef stops = dict_or_new(state, search, key::stops);
	int64_t best_tile = -1;
	double best_key = kInf;
	const int64_t order_count = gd::int_field(state, search, key::order_count, 0);
	for (int64_t position = 1; position < order_count; ++position) {
		const int64_t tile_index = gd::packed_int(state, order, position);
		if (state.has(stops, int_value(tile_index)) || state.has(keep_clear, int_value(tile_index))) {
			continue;
		}
		const Vector2i tile = Vector2i::of(checked_mod(tile_index, size.x), checked_div(tile_index, size.x));
		if (_next_to_any(state, tile, friends)) {
			continue;
		}
		const double span = static_cast<double>(chebyshev(gd::sub(tile.x, home.x), gd::sub(tile.y, home.y)));
		const double tile_key_value = span * 1000.0 + gd::to_float(ai::vindex(state, gd::index(state, search, str(key::dist)), int_value(tile_index)));
		if (tile_key_value < best_key && !_cuts_a_way(state, search, tile_index, size)) {
			best_key = tile_key_value;
			best_tile = tile_index;
		}
	}
	if (best_tile < 0 || (static_cast<double>(chebyshev(gd::sub(here.x, home.x), gd::sub(here.y, home.y))) * 1000.0 <= best_key && here_free)) {
		return state.new_dict();
	}
	const Atom id = gd::format(state, key::wait_d, {int_value(best_tile)});
	return tile_plan(state, key::wait, id, best_tile, dist_at(state, search, best_tile));
}

Atom _parked_hero_id(State &state, DictRef session, Atom controller, Atom town_id) {
	if (town_id == key::empty) {
		return key::empty;
	}
	const DictRef town = gd::as_dict(gd::index(state, _find_town(state, session, town_id), str(key::town)));
	if (gd::is_empty(state, town) || ai::string_or_empty(state, town, key::owner) != key::enemy || player_rules::town_controller_id(state, town) != controller) {
		return key::empty;
	}
	const DictRef entrance = level_rules::town_entrance(state, town);
	const ArrayRef others = active_hero_entries(state, session, controller);
	for (int64_t at = 0; at < state.array_size(others); ++at) {
		const Value other = state.at(others, at);
		if (gd::stringify(state, nested_get(state, other, {key::ai_hero}, key::parked, str(key::empty))) == town_id && level_rules::same_level(state, other, dict_value(entrance))
				&& gd::to_int(state, ai::vget(state, other, key::x, int_value(-1))) == gd::int_field(state, entrance, key::x, -2)
				&& gd::to_int(state, ai::vget(state, other, key::y, int_value(-1))) == gd::int_field(state, entrance, key::y, -2)) {
			return gd::stringify(state, ai::vget(state, other, key::placement_id, str(key::empty)));
		}
	}
	return key::empty;
}

void _park(State &state, DictRef session, Atom placement_id, Atom town_id) {
	const int64_t index = _entry_index(state, session, placement_id);
	if (index < 0) {
		return;
	}
	const DictRef entry = encounter_at(state, session, index);
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	state.set(block, str(key::parked), str(town_id));
	state.set(block, str(key::goal), dict_value(state.new_dict()));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
}

bool _cuts_a_way(State &state, DictRef search, int64_t tile_index, Vector2i size) {
	PackedRef blocked = 0;
	PackedRef stop_mask = 0;
	PackedRef pass_mask = 0;
	const bool has_blocked = bytes_field(state, search, key::blocked, blocked);
	const bool has_stop_mask = bytes_field(state, search, key::stop_mask, stop_mask);
	const bool has_pass_mask = bytes_field(state, search, key::pass_mask, pass_mask);
	if (!has_blocked || gd::packed_is_empty(state, blocked) || !has_stop_mask || gd::packed_is_empty(state, stop_mask) || !has_pass_mask || gd::packed_is_empty(state, pass_mask)) {
		return false;
	}
	const bool native_corners = gd::to_bool(state.get(search, str(key::native_corners), bool_value(true)));
	const Vector2i center = Vector2i::of(checked_mod(tile_index, size.x), checked_div(tile_index, size.x));
	std::vector<Vector2i> open;
	for (int direction = 0; direction < 8; ++direction) {
		const Vector2i tile = center + Vector2i::of(kNeighborDx[direction], kNeighborDy[direction]);
		if (tile.x < 0 || tile.y < 0 || tile.x >= size.x || tile.y >= size.y) {
			continue;
		}
		const int64_t index = index_of(tile.x, tile.y, size);
		if (gd::packed_int(state, blocked, index) != 0 || (gd::packed_int(state, stop_mask, index) != 0 && gd::packed_int(state, pass_mask, index) == 0)) {
			continue;
		}
		open.push_back(tile);
	}
	if (open.size() < 2) {
		return false;
	}
	std::vector<int64_t> group(open.size(), -1);
	int64_t groups = 0;
	for (size_t first = 0; first < open.size(); ++first) {
		if (group[first] >= 0) {
			continue;
		}
		group[first] = groups;
		std::vector<size_t> queue = {first};
		while (!queue.empty()) {
			const size_t current = queue.back();
			queue.pop_back();
			const Vector2i a = open[current];
			for (size_t other = 0; other < open.size(); ++other) {
				if (group[other] >= 0) {
					continue;
				}
				const Vector2i b = open[other];
				if (chebyshev(gd::sub(a.x, b.x), gd::sub(a.y, b.y)) != 1) {
					continue;
				}
				// A diagonal step between two blocked corners (the hero's own
				// tile counts as one) needs the native eight-way rule.
				if (a.x != b.x && a.y != b.y && !native_corners) {
					const Vector2i corner_a = Vector2i::of(a.x, b.y);
					const Vector2i corner_b = Vector2i::of(b.x, a.y);
					if ((corner_a == center || gd::packed_int(state, blocked, index_of(corner_a.x, corner_a.y, size)) != 0)
							&& (corner_b == center || gd::packed_int(state, blocked, index_of(corner_b.x, corner_b.y, size)) != 0)) {
						continue;
					}
				}
				group[other] = groups;
				queue.push_back(other);
			}
		}
		groups += 1;
	}
	return groups > 1;
}

bool _next_to_any(State &state, Vector2i tile, ArrayRef others) {
	for (const Value &other : gd::items(state, array_value(others))) {
		const int64_t dx = gd::to_int(state, gd::op_sub(ai::vmember(state, other, key::x), int_value(tile.x)));
		const int64_t dy = gd::to_int(state, gd::op_sub(ai::vmember(state, other, key::y), int_value(tile.y)));
		if (chebyshev(dx, dy) <= 1) {
			return true;
		}
	}
	return false;
}

void _reveal(State &state, DictRef session, DictRef context, DictRef point, int64_t radius) {
	const int64_t level = level_rules::level_of(state, dict_value(point));
	const PackedRef tiles = _explored(state, session, context, level);
	const Vector2i size = context_map_size(state, context);
	const int64_t cx = gd::int_field(state, point, key::x, 0);
	const int64_t cy = gd::int_field(state, point, key::y, 0);
	for (int64_t dy = gd::neg(radius); dy < gd::add(radius, 1); ++dy) {
		const int64_t y = gd::add(cy, dy);
		if (y < 0 || y >= size.y) {
			continue;
		}
		const int64_t half = hero_command_rules::scout_row_half_width(state, dy, radius);
		if (half < 0) {
			continue;
		}
		const int64_t from = compat::engine_max<int64_t>(0, gd::sub(cx, half));
		const int64_t to = gd::add(compat::engine_min<int64_t>(static_cast<int64_t>(size.x) - 1, gd::add(cx, half)), 1);
		for (int64_t x = from; x < to; ++x) {
			gd::packed_set(state, tiles, index_of(x, y, size), 1);
		}
	}
	state.set(gd::as_dict(gd::index(state, context, str(key::explored))), int_value(level), gd::bytes_value(tiles));
}

int64_t _sight_radius(State &state, DictRef entry) {
	return hero_command_rules::scouting_radius_for_hero(state, dict_or_new(state, entry, key::enemy_commander_state));
}

bool _cross_shore(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level) {
	const Atom boat_id = water_travel_rules::hero_boat_id(state, dict_value(entry));
	if (boat_id != key::empty) {
		const Vector2i here = Vector2i::of(gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
		water_travel_rules::place_boat(state, dict_value(session), boat_id, key::empty, here, level);
		state.erase(entry, str(key::boat_id));
		return true;
	}
	DictRef boat = water_travel_rules::free_boat_at(state, dict_value(session), tile, level);
	if (gd::is_empty(state, boat)) {
		boat = _launch_boat(state, session, context, entry, tile, level);
	}
	if (gd::is_empty(state, boat)) {
		return false;
	}
	water_travel_rules::place_boat(state, dict_value(session), ai::string_or_empty(state, boat, key::id), ai::string_or_empty(state, entry, key::placement_id), tile, level);
	state.set(entry, str(key::boat_id), str(ai::string_or_empty(state, boat, key::id)));
	return true;
}

DictRef _launch_boat(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level) {
	const Vector2i size = context_map_size(state, context);
	const DictRef surface = _level_surface(state, session, context, level);
	Value shipyards;
	const bool has_shipyards = state.lookup(surface, str(key::shipyards), shipyards);
	const int64_t entry_tile = _tile_index_of(state, entry, size);
	if (!has_shipyards) {
		return state.new_dict();
	}
	if (!gd::is_dict(shipyards)) {
		ai::vget(state, shipyards, int_value(entry_tile));
	}
	Value found;
	if (!state.lookup(shipyards.ref, int_value(entry_tile), found)) {
		return state.new_dict();
	}
	const DictRef yard = gd::as_dict(found);
	if (gd::is_empty(state, yard) || gd::to_int(state, gd::index(state, yard, str(key::dock))) != index_of(tile.x, tile.y, size)) {
		return state.new_dict();
	}
	const DictRef cost = dict_or_new(state, surface, key::boat_cost);
	const DictRef treasury = gd::as_dict(context_treasury(state, context));
	const DictRef market = _boat_market(state, session, context, cost);
	if (gd::is_empty(state, market)) {
		return state.new_dict();
	}
	const ArrayRef nodes = array_or_new(state, session_view::overworld(state, session), key::resource_nodes);
	if (gd::to_int(state, gd::index(state, yard, str(key::node))) >= state.array_size(nodes)) {
		return state.new_dict();
	}
	const DictRef dock_node = gd::as_dict(state.at(nodes, gd::to_int(state, gd::index(state, yard, str(key::node)))));
	if (water_travel_rules::dock_blocker(state, dict_value(session), dock_node) != key::empty) {
		return state.new_dict();
	}
	if (state.has(market, str(key::town_index))) {
		const DictRef overworld = session_view::overworld(state, session);
		const ArrayRef towns = array_or_new(state, overworld, key::towns);
		const int64_t town_index = gd::to_int(state, gd::index(state, market, str(key::town_index)));
		const DictRef town = gd::as_dict(state.at(towns, town_index));
		if (!_market_cover(state, session, town, treasury, cost, true)) {
			return state.new_dict();
		}
		state.set_at(towns, gd::to_int(state, gd::index(state, market, str(key::town_index))), dict_value(town));
		state.set(overworld, str(key::towns), array_value(towns));
	}
	const DictRef yard_node = gd::as_dict(state.at(nodes, gd::to_int(state, gd::index(state, yard, str(key::node)))));
	if (water_travel_rules::build_boat(state, dict_value(session), yard_node) != key::empty) {
		return state.new_dict();
	}
	enemy_turn_rules::_spend_from_pool(state, treasury, dict_value(cost));
	_economy_add(state, session, context_controller(state, context), key::boat_gold, gd::float_field(state, cost, key::gold, 0.0));
	overworld_turn_playback::action(state, dict_value(session), entry, key::builds_a_boat);
	return water_travel_rules::free_boat_at(state, dict_value(session), tile, level);
}

void _note_boat_need(State &state, DictRef session, DictRef context, DictRef entry) {
	const int64_t wanted_day = gd::to_int(state, ai::vget(state, context_state(state, context), key::ai_boat_wanted_day, int_value(-1000)));
	if (wanted_day == ai::session_int(state, session, key::day) || water_travel_rules::hero_boat_id(state, dict_value(entry)) != key::empty) {
		return;
	}
	if (!_plans_far(state, session, context, entry)) {
		return;
	}
	const DictRef surface = _level_surface(state, session, context, level_rules::level_of(state, dict_value(entry)));
	const DictRef shipyards = dict_or_new(state, surface, key::shipyards);
	if (gd::is_empty(state, shipyards) || !gd::is_empty(state, _boat_market(state, session, context, dict_or_new(state, surface, key::boat_cost)))) {
		return;
	}
	const DictRef search = _search(state, session, context, entry, gd::mul(_movement_max(state, entry), tunable_int(state, key::FAR_SEARCH_DAYS)));
	for (const Value &visit_index : gd::items(state, array_value(gd::keys(state, shipyards)))) {
		if (dist_at(state, search, gd::to_int(state, visit_index)) >= 0) {
			state.set(gd::as_dict(context_state(state, context)), str(key::ai_boat_wanted_day), int_value(ai::session_int(state, session, key::day)));
			return;
		}
	}
}

DictRef _portal_step(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level) {
	const Vector2i here = Vector2i::of(gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
	if (chebyshev(gd::sub(tile.x, here.x), gd::sub(tile.y, here.y)) <= 1) {
		return state.new_dict();
	}
	const Vector2i size = context_map_size(state, context);
	const DictRef portals = dict_or_new(state, _level_surface(state, session, context, level), key::portals);
	Value found;
	if (!state.lookup(portals, int_value(index_of(here.x, here.y, size)), found)) {
		return state.new_dict();
	}
	const DictRef portal = gd::as_dict(found);
	if (gd::is_empty(state, portal)) {
		return state.new_dict();
	}
	if (gd::packed_size(state, gd::as_ints(gd::index(state, portal, str(key::exits)))) < 2) {
		// A fixed portal leads where the route says; scouting one, it leads to
		// its single exit.
		if (tile.x < 0) {
			const int64_t only = gd::packed_int(state, gd::as_ints(gd::index(state, portal, str(key::exits))), 0);
			const Vector2i exit = Vector2i::of(checked_mod(only, size.x), checked_div(only, size.x));
			const DictRef result = state.new_dict();
			state.set(result, str(key::exit), Value::of_vector2i(exit.x, exit.y));
			return result;
		}
		return state.new_dict();
	}
	const ArrayRef nodes = array_or_new(state, session_view::overworld(state, session), key::resource_nodes);
	const int64_t node_index = gd::to_int(state, gd::index(state, portal, str(key::node)));
	const DictRef node = node_index < state.array_size(nodes) ? gd::as_dict(state.at(nodes, gd::to_int(state, gd::index(state, portal, str(key::node))))) : state.new_dict();
	const Atom actor_id = ai::string_or_empty(state, entry, key::placement_id);
	const DictRef check = overworld_rules::native_random_exit_check(state, session, node, gd::vector3i(here.x, here.y, static_cast<int32_t>(level)), actor_id);
	if (!gd::bool_field(state, check, key::ok, false)) {
		return state.new_dict();
	}
	overworld_rules::note_native_trip(state, session, actor_id);
	const Value exit = as_vector3i(state.get(check, str(key::exit), gd::vector3i(tile.x, tile.y, static_cast<int32_t>(level))));
	const DictRef result = state.new_dict();
	state.set(result, str(key::exit), Value::of_vector2i(exit.vx(), exit.vy()));
	return result;
}

bool _tile_blocked_for_standing(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level, Atom actor_id) {
	const Atom controller = gd::stringify(state, state.get(context, str(key::controller), str(key::empty)));
	const Vector2i size = state.has(context, str(key::map_size)) ? context_map_size(state, context) : overworld_rules::derive_map_size(state, session);
	const bool own_door = controller != key::empty && state.has(_own_town_doors(state, session, controller, level, size), int_value(index_of(tile.x, tile.y, size)));
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &entry : gd::field_items(state, overworld, str(key::encounters))) {
		if (gd::is_dict(entry) && ai::string_or_empty(state, entry.ref, key::placement_id) != actor_id && level_rules::level_of(state, entry) == level
				&& gd::int_field(state, entry.ref, key::x, -1) == tile.x && gd::int_field(state, entry.ref, key::y, -1) == tile.y
				&& !_is_resolved(state, session, ai::string_or_empty(state, entry.ref, key::placement_id))) {
			if (own_door && is_ai_hero(state, entry) && player_rules::raid_controller_id(state, entry.ref) == controller) {
				continue;
			}
			return true;
		}
	}
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		Value found;
		const DictRef position = gd::is_dict(hero) && state.lookup(hero.ref, str(key::position), found) && gd::is_dict(found) ? found.ref : state.new_dict();
		if (level_rules::level_of(state, dict_value(position)) == level && gd::int_field(state, position, key::x, -1) == tile.x && gd::int_field(state, position, key::y, -1) == tile.y) {
			return true;
		}
	}
	return false;
}

DictRef _hostile_hero_beside(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level) {
	const ArrayRef guards = _hero_guards(state, session, context, level);
	for (int64_t at = 0; at < state.array_size(guards); ++at) {
		const Value guard = state.at(guards, at);
		if (!gd::to_bool(ai::vmember(state, guard, key::hostile))) {
			continue;
		}
		const Value guard_tile = ai::vmember(state, guard, key::tile);
		const int64_t dx = gd::sub(gd::to_int(state, ai::vmember(state, guard_tile, key::x)), tile.x);
		const int64_t dy = gd::sub(gd::to_int(state, ai::vmember(state, ai::vmember(state, guard, key::tile), key::y)), tile.y);
		if (chebyshev(dx, dy) != 1) {
			continue;
		}
		const ArrayRef zone = _hero_zone_tiles(state, session, context, as_vector2i(ai::vmember(state, guard, key::tile)), level);
		if (gd::array_has(state, zone, Value::of_vector2i(tile.x, tile.y))) {
			const DictRef plan = state.new_dict();
			state.set(plan, str(key::kind), str(gd::stringify(state, ai::vmember(state, guard, key::ref_kind))));
			state.set(plan, str(key::id), str(gd::stringify(state, ai::vmember(state, guard, key::id))));
			state.set(plan, str(key::index), int_value(gd::to_int(state, ai::vmember(state, guard, key::index))));
			return plan;
		}
	}
	return state.new_dict();
}

DictRef _cross_gate(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const DictRef entry = encounter_at(state, session, index);
	const ArrayRef nodes = array_or_new(state, session_view::overworld(state, session), key::resource_nodes);
	const int64_t node_index = gd::int_field(state, plan, key::index, -1);
	const DictRef surface = _level_surface(state, session, context, level_rules::level_of(state, dict_value(entry)));
	Value gates;
	const bool has_gates = state.lookup(surface, str(key::gates), gates);
	const int64_t entry_tile = _tile_index_of(state, entry, context_map_size(state, context));
	if (!has_gates) {
		return not_acted(state);
	}
	if (!gd::is_dict(gates)) {
		ai::vget(state, gates, int_value(entry_tile));
	}
	Value found;
	if (!state.lookup(gates.ref, int_value(entry_tile), found)) {
		return not_acted(state);
	}
	const DictRef gate = gd::as_dict(found);
	if (gd::is_empty(state, gate) || gd::to_int(state, gd::index(state, gate, str(key::node))) != node_index) {
		return not_acted(state);
	}
	const Value far = as_vector3i(gd::index(state, gate, str(key::exit)));
	const DictRef guard = overworld_rules::_find_guard_engagement_at_tile(state, session, far.vx(), far.vy(), far.vz(), false);
	const int64_t guard_index = gd::int_field(state, guard, key::index, -1);
	if (guard_index >= 0) {
		const double power = hero_power(state, entry);
		const double guard_power = _guard_power(state, gd::as_dict(gd::index(state, guard, str(key::encounter))));
		if (power < guard_power * tunable_float(state, key::GUARD_WIN_RATIO)) {
			return not_acted(state);
		}
	}
	const DictRef gate_node = gd::as_dict(state.at(nodes, node_index));
	const Value actor_position = native_transit_rules::point(state, dict_value(entry));
	const DictRef check = overworld_rules::native_passage_travel_check(state, session, gate_node, actor_position, ai::string_or_empty(state, entry, key::placement_id), key::empty, guard_index >= 0);
	if (!gd::bool_field(state, check, key::ok, false)) {
		return not_acted(state);
	}
	const Value exit = as_vector3i(gd::index(state, check, str(key::exit)));
	const DictRef before = level_rules::position(state, entry);
	state.set(entry, str(key::x), int_value(exit.vx()));
	state.set(entry, str(key::y), int_value(exit.vy()));
	state.set(entry, str(key::level), int_value(exit.vz()));
	const DictRef block = dict_or_new(state, entry, key::ai_hero);
	Value beyond;
	const DictRef goal = state.lookup(plan, str(key::beyond), beyond) ? gd::duplicate_dict(state, gd::as_dict(beyond)) : state.new_dict();
	state.set(block, str(key::goal), dict_value(goal));
	state.set(block, str(key::crossed_day), int_value(ai::session_int(state, session, key::day)));
	state.set(entry, str(key::ai_hero), dict_value(block));
	overworld_turn_playback::move(state, dict_value(session), entry, before);
	_store_entry(state, session, index, entry);
	overworld_rules::invalidate_spatial_lookup(state, session);
	const DictRef sight_point = level_rules::position(state, entry);
	_reveal(state, session, context, sight_point, _sight_radius(state, entry));
	const DictRef ambushed = _hostile_hero_beside(state, session, context, Vector2i::of(exit.vx(), exit.vy()), exit.vz());
	if (!gd::is_empty(state, ambushed)) {
		return _interact(state, session, context, index, ambushed);
	}
	if (guard_index >= 0) {
		const DictRef fight = state.new_dict();
		state.set(fight, str(key::kind), str(key::encounter));
		state.set(fight, str(key::index), int_value(guard_index));
		return _fight_neutral(state, session, context, index, fight);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(false));
	state.set(result, str(key::rerouted), bool_value(true));
	return result;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
