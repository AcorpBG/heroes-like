// WaterTravelRules for the human seat's move (Phase 7, slice 7.2): embarking,
// disembarking, the boat following the hero, and whirlpools, with
// OverworldRules._whirlpool_throw.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// WaterTravelRules.NEIGHBORS.
constexpr Vector2i kNeighbors[] = {{0, 1}, {-1, 0}, {1, 0}, {0, -1}, {-1, 1}, {1, 1}, {-1, -1}, {1, -1}};

// session.overworld of a WaterTravelRules session (the view as a Value).
DictRef overworld_of(State &state, const Value &session) {
	return session_view::overworld(state, gd::as_dict(session));
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(field, []) if d.get(field, []) is Array else [].
ArrayRef array_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found)) {
		return found.ref;
	}
	return state.new_array();
}

// String(list[index].get("id", "")) of an untyped item.
Atom item_id(State &state, const Value &item) {
	return gd::stringify(state, ai::vget(state, item, key::id, str(key::empty)));
}

// session.overworld.get("hero", {}) passed on to hero_boat_id.
Atom active_boat_id(State &state, DictRef overworld) {
	Value hero;
	if (!state.lookup(overworld, str(key::hero), hero)) {
		return key::empty;
	}
	return water_travel_rules::hero_boat_id(state, hero);
}

} // namespace

namespace overworld_rules {

ArrayRef _whirlpool_throw(State &state, DictRef session, DictRef node) {
	const ArrayRef messages = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef army = dict_field_or_new(state, overworld, key::army);
	Value stacks_value;
	const ArrayRef stacks = state.lookup(army, str(key::stacks), stacks_value) && gd::is_array(stacks_value)
			? gd::as_array(gd::engine_duplicate(state, stacks_value, true))
			: state.new_array();
	const DictRef loss = water_travel_rules::whirlpool_losses(state, stacks);
	if (!gd::is_empty(state, loss)) {
		const int64_t index = gd::to_int(state, gd::index(state, loss, str(key::index)));
		const Value stack = state.at(stacks, index);
		const int64_t lost = gd::to_int(state, gd::index(state, loss, str(key::lost)));
		const int64_t count = gd::to_int(state, ai::vget(state, stack, key::count, int_value(0)));
		state.set(gd::as_dict(stack), str(key::count), int_value(gd::sub(count, lost)));
		state.set(army, str(key::stacks), array_value(stacks));
		state.set(session_view::overworld(state, session), str(key::army), dict_value(army));
		const Value unit_id = gd::index(state, loss, str(key::unit_id));
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::stringify(state, unit_id));
		const Atom unit_name = gd::stringify(state, state.get(unit, str(key::name), unit_id));
		state.append(messages, str(gd::format(state, key::the_current_drags_away_d_s, {int_value(lost), str(unit_name)})));
	}
	const DictRef exit = water_travel_rules::whirlpool_exit(state, dict_value(session), node, [&state, session](Vector2i tile, int64_t level) {
		return state.has(_blocked_tile_index(state, session, level), str(_tile_key(state, tile)));
	});
	if (gd::is_empty(state, exit)) {
		state.append(messages, str(key::no_other_whirlpool_lets_the_boat));
	} else {
		const Vector2i tile = Vector2i::of(gd::to_int(state, gd::index(state, exit, str(key::x))), gd::to_int(state, gd::index(state, exit, str(key::y))));
		_set_active_hero_position(state, session, tile, gd::to_int(state, gd::index(state, exit, str(key::level))));
		water_travel_rules::follow_active_hero(state, dict_value(session), tile, gd::to_int(state, gd::index(state, exit, str(key::level))));
		const ArrayRef traversed = state.new_array();
		state.append(traversed, Value::of_vector2i(tile.x, tile.y));
		_reveal_route_fog(state, session, traversed);
		state.append(messages, str(key::the_whirlpool_throws_the_boat_out));
	}
	hero_command_rules::commit_active_hero(state, session);
	return messages;
}

} // namespace overworld_rules

namespace water_travel_rules {

void embark(State &state, const Value &session, DictRef boat) {
	const Atom hero_id = ai::string_or_empty(state, overworld_of(state, session), key::active_hero_id);
	const ArrayRef list = gd::as_array(gd::engine_duplicate(state, array_value(boats(state, session)), true));
	for (int64_t index = 0; index < state.array_size(list); ++index) {
		const Value item = state.at(list, index);
		if (item_id(state, item) == ai::string_or_empty(state, boat, key::id)) {
			state.set(gd::as_dict(item), str(key::hero_id), str(hero_id));
		}
	}
	state.set(overworld_of(state, session), str(key::boats), array_value(list));
	_set_active_hero_boat(state, session, ai::string_or_empty(state, boat, key::id));
}

void disembark(State &state, const Value &session, Vector2i mooring, int64_t level) {
	const Atom boat_id = active_boat_id(state, overworld_of(state, session));
	const ArrayRef list = gd::as_array(gd::engine_duplicate(state, array_value(boats(state, session)), true));
	for (int64_t index = 0; index < state.array_size(list); ++index) {
		const Value item = state.at(list, index);
		if (item_id(state, item) == boat_id) {
			const DictRef boat = gd::as_dict(item);
			state.set(boat, str(key::hero_id), str(key::empty));
			state.set(boat, str(key::x), int_value(mooring.x));
			state.set(boat, str(key::y), int_value(mooring.y));
			state.set(boat, str(key::level), int_value(level));
		}
	}
	state.set(overworld_of(state, session), str(key::boats), array_value(list));
	_set_active_hero_boat(state, session, key::empty);
}

void follow_active_hero(State &state, const Value &session, Vector2i tile, int64_t level) {
	const Atom boat_id = active_boat_id(state, overworld_of(state, session));
	if (boat_id == key::empty) {
		return;
	}
	const ArrayRef list = gd::as_array(gd::engine_duplicate(state, array_value(boats(state, session)), true));
	for (int64_t index = 0; index < state.array_size(list); ++index) {
		const Value item = state.at(list, index);
		if (item_id(state, item) == boat_id) {
			const DictRef boat = gd::as_dict(item);
			state.set(boat, str(key::x), int_value(tile.x));
			state.set(boat, str(key::y), int_value(tile.y));
			state.set(boat, str(key::level), int_value(level));
		}
	}
	state.set(overworld_of(state, session), str(key::boats), array_value(list));
}

void _set_active_hero_boat(State &state, const Value &session, Atom boat_id) {
	const DictRef overworld = overworld_of(state, session);
	const Atom active_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	const DictRef active = dict_field_or_new(state, overworld, key::hero);
	if (boat_id == key::empty) {
		state.erase(active, str(key::boat_id));
	} else {
		state.set(active, str(key::boat_id), str(boat_id));
	}
	state.set(overworld, str(key::hero), dict_value(active));
	const ArrayRef heroes = array_field_or_new(state, overworld, key::player_heroes);
	for (int64_t index = 0; index < state.array_size(heroes); ++index) {
		const Value hero = state.at(heroes, index);
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) == active_id) {
			if (boat_id == key::empty) {
				state.erase(hero.ref, str(key::boat_id));
			} else {
				state.set(hero.ref, str(key::boat_id), str(boat_id));
			}
		}
	}
	state.set(overworld, str(key::player_heroes), array_value(heroes));
}

DictRef whirlpool_exit(State &state, const Value &session, DictRef node, const std::function<bool(Vector2i, int64_t)> &blocked) {
	const int64_t level = level_rules::level_of(state, dict_value(node));
	const Atom source_id = ai::string_or_empty(state, node, key::placement_id);
	const ArrayRef others = state.new_array();
	for (const Value &other : gd::field_items(state, overworld_of(state, session), str(key::resource_nodes))) {
		if (gd::is_dict(other) && ai::string_or_empty(state, other.ref, key::site_id) == key::site_whirlpool && ai::string_or_empty(state, other.ref, key::placement_id) != source_id && level_rules::level_of(state, other) == level) {
			state.append(others, other);
		}
	}
	if (state.array_size(others) == 0) {
		return state.new_dict();
	}
	gd::sort_custom(state, others, [&state](const Value &a, const Value &b) {
		const Atom left = ai::string_or_empty(state, gd::as_dict(a), key::placement_id);
		const Atom right = ai::string_or_empty(state, gd::as_dict(b), key::placement_id);
		return state.text(left) < state.text(right);
	});
	const DictRef view = gd::as_dict(session);
	const int64_t day = gd::to_int(state, gd::index(state, view, str(key::day)));
	const Atom hero_id = ai::string_or_empty(state, overworld_of(state, session), key::active_hero_id);
	const Atom throw_key = gd::format(state, key::s_d_s_3, {str(source_id), int_value(day), str(hero_id)});
	const int64_t size = state.array_size(others);
	const int64_t start = compat::posmod(gd::hash(state, str(throw_key)), size);
	for (int64_t offset = 0; offset < size; ++offset) {
		const DictRef target = gd::as_dict(state.at(others, (start + offset) % size));
		Value visit;
		const bool has_visit = state.lookup(target, str(key::visit_tile), visit) && gd::is_dict(visit);
		const Value target_x = gd::field_or(state, target, key::x, int_value(0));
		const int64_t center_x = gd::to_int(state, has_visit ? state.get(visit.ref, str(key::x), target_x) : target_x);
		const Value target_y = gd::field_or(state, target, key::y, int_value(0));
		const int64_t center_y = gd::to_int(state, has_visit ? state.get(visit.ref, str(key::y), target_y) : target_y);
		const Vector2i center = Vector2i::of(center_x, center_y);
		for (const Vector2i delta : kNeighbors) {
			const Vector2i tile = center + delta;
			if (is_water(state, session, tile.x, tile.y, level) && !any_boat_at(state, session, tile, level) && !hero_at(state, session, tile, level) && !blocked(tile, level)) {
				const DictRef exit = state.new_dict();
				state.set(exit, str(key::x), int_value(tile.x));
				state.set(exit, str(key::y), int_value(tile.y));
				state.set(exit, str(key::level), int_value(level));
				state.set(exit, str(key::whirlpool), str(ai::string_or_empty(state, target, key::placement_id)));
				return exit;
			}
		}
	}
	return state.new_dict();
}

DictRef whirlpool_losses(State &state, ArrayRef stacks) {
	int64_t weakest = -1;
	int64_t weakest_health = int64_t{1} << 30;
	int64_t total = 0;
	for (int64_t index = 0; index < state.array_size(stacks); ++index) {
		const Value stack = state.at(stacks, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		total = gd::add(total, count);
		if (count <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, stack.ref, key::unit_id));
		const int64_t health = gd::mul(count, compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::hp, 1)));
		if (health < weakest_health) {
			weakest_health = health;
			weakest = index;
		}
	}
	if (weakest < 0) {
		return state.new_dict();
	}
	const Value weakest_stack = state.at(stacks, weakest);
	int64_t lost = compat::int_div(gd::to_int(state, ai::vget(state, weakest_stack, key::count, int_value(0))), 2);
	lost = compat::engine_min<int64_t>(lost, gd::sub(total, 1));
	if (lost <= 0) {
		return state.new_dict();
	}
	const DictRef loss = state.new_dict();
	state.set(loss, str(key::index), int_value(weakest));
	state.set(loss, str(key::unit_id), str(gd::stringify(state, ai::vget(state, weakest_stack, key::unit_id, str(key::empty)))));
	state.set(loss, str(key::lost), int_value(lost));
	return loss;
}

} // namespace water_travel_rules

} // namespace aurelion::rules::port
