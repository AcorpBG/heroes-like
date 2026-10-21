// Layer 2: abilities, battle tags, traits and the side counts the bonuses read.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::Number;
using compat::variant_max;
using gd::array_value;
using gd::dict_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// container.has(item) on an untyped value: Array.has (StringLikeVariantComparator),
// Dictionary.has or PackedStringArray.has. Nil and the other modelled types have
// no has() for a String: GDScript stops there too.
bool variant_has(const State &state, const Value &container, const Value &item) {
	if (container.kind == Kind::Array) {
		return gd::array_has(state, container.ref, item);
	}
	if (container.kind == Kind::Dict) {
		return state.has(container.ref, item);
	}
	if (container.kind == Kind::PackedString) {
		return gd::packed_find(state, container, item) >= 0;
	}
	if (container.kind == Kind::Opaque) {
		throw state::ScriptError("has() on an opaque value is not ported");
	}
	if (container.kind == Kind::Nil) {
		throw state::ScriptError("Cannot call method 'has' on a null value.");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'has' in base '") + gd::type_name(container) + "'.");
}

// `for objective_type in values: if _side_controls_field_objective_type(battle,
// side, String(objective_type)): return true`, then false.
bool any_controlled_objective_type(State &state, DictRef battle, Atom side, const Value &values) {
	for (const Value &objective_type : gd::items(state, values)) {
		if (_side_controls_field_objective_type(state, battle, side, gd::to_string(objective_type))) {
			return true;
		}
	}
	return false;
}

DictRef source_ability_context(State &state, const Value &source, DictRef ability) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::source), source);
	state.set(context, str(key::ability), dict_value(ability));
	return context;
}

} // namespace

DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id) {
	if (ability_id == key::empty) {
		return state.new_dict();
	}
	for (const Value &ability : gd::field_items(state, stack, str(key::abilities))) {
		if (gd::is_dict(ability) && gd::string_field(state, ability.ref, key::id, key::empty) == ability_id) {
			return ability.ref;
		}
	}
	return state.new_dict();
}

DictRef _authored_ability_by_id(State &state, DictRef stack, Atom ability_id) {
	const DictRef unit = gd::content_row(state, state::ContentTable::Unit, gd::string_field(state, stack, key::unit_id, key::empty));
	const DictRef authored = _ability_by_id(state, unit, ability_id);
	return !gd::is_empty(state, authored) ? authored : _ability_by_id(state, stack, ability_id);
}

bool _has_ability(State &state, DictRef stack, Atom ability_id) {
	return !gd::is_empty(state, _ability_by_id(state, stack, ability_id));
}

ArrayRef _side_ability_payloads(State &state, DictRef battle, Atom side, Atom ability_id) {
	const ArrayRef payloads = state.new_array();
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(stack), ability_id);
		if (!gd::is_empty(state, ability)) {
			state.append(payloads, dict_value(ability));
		}
	}
	return payloads;
}

bool _side_has_ability(State &state, DictRef battle, Atom side, Atom ability_id) {
	return state.array_size(_side_ability_payloads(state, battle, side, ability_id)) != 0;
}

double _side_max_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom key_name, double default_value) {
	// var best = default_value: a float, and max() of two floats stays one.
	double best = default_value;
	const ArrayRef payloads = _side_ability_payloads(state, battle, side, ability_id);
	for (const Value &ability : gd::items(state, array_value(payloads))) {
		const double value = gd::float_field(state, gd::as_dict(ability), key_name, default_value);
		best = variant_max({ Number::of_float(best), Number::of_float(value) }).f;
	}
	return best;
}

int64_t _side_max_ability_int(State &state, DictRef battle, Atom side, Atom ability_id, Atom key_name) {
	// var best = 0: an int, and max() of two ints stays one.
	int64_t best = 0;
	const ArrayRef payloads = _side_ability_payloads(state, battle, side, ability_id);
	for (const Value &ability : gd::items(state, array_value(payloads))) {
		const int64_t value = gd::int_field(state, gd::as_dict(ability), key_name, 0);
		best = variant_max({ Number::of_int(best), Number::of_int(value) }).i;
	}
	return best;
}

int64_t _side_max_authored_ability_int(State &state, DictRef battle, Atom side, Atom ability_id, Atom key_name) {
	int64_t best = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (gd::is_empty(state, _ability_by_id(state, gd::as_dict(stack), ability_id))) {
			continue;
		}
		const DictRef ability = _authored_ability_by_id(state, gd::as_dict(stack), ability_id);
		const int64_t value = gd::int_field(state, ability, key_name, 0);
		best = variant_max({ Number::of_int(best), Number::of_int(value) }).i;
	}
	return best;
}

bool _side_ability_bool(State &state, DictRef battle, Atom side, Atom ability_id, Atom key_name, bool default_value) {
	// The loop returns on its first payload.
	const ArrayRef payloads = _side_ability_payloads(state, battle, side, ability_id);
	if (state.array_size(payloads) != 0) {
		return gd::bool_field(state, gd::as_dict(state.at(payloads, 0)), key_name, default_value);
	}
	return default_value;
}

DictRef _normalize_ability_modifiers(State &state, const Value &value) {
	const DictRef modifiers = state.new_dict();
	if (gd::is_dict(value)) {
		const ArrayRef keys = gd::keys(state, value.ref);
		for (const Value &modifier : gd::items(state, array_value(keys))) {
			const Atom modifier_key = gd::to_string(modifier);
			if (modifier_key == key::empty) {
				continue;
			}
			const int64_t amount = gd::to_int(state, gd::index(state, value.ref, modifier));
			state.set(modifiers, str(modifier_key), gd::int_value(amount));
		}
	}
	return modifiers;
}

DictRef _charter_retaliation_aura_context(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || gd::bool_field(state, stack, key::ranged, false)) {
		return state.new_dict();
	}
	const ArrayRef sources = _alive_stacks_for_side(state, battle, gd::string_field(state, stack, key::side, key::empty));
	for (const Value &source : gd::items(state, array_value(sources))) {
		const DictRef source_stack = gd::as_dict(source);
		const Atom source_id = gd::string_field(state, source_stack, key::battle_id, key::empty);
		const Atom stack_id = gd::string_field(state, stack, key::battle_id, key::empty);
		if (source_id == stack_id) {
			continue;
		}
		const DictRef brace = _ability_by_id(state, source_stack, key::brace);
		if (gd::float_field(state, brace, key::ally_retaliation_multiplier, 1.0) <= 1.0) {
			continue;
		}
		const int64_t tier = gd::int_field(state, stack, key::tier, 1);
		const int64_t min_tier = gd::int_field(state, brace, key::ally_retaliation_min_tier, 1);
		if (tier < min_tier) {
			continue;
		}
		const Atom role = gd::string_field(state, brace, key::ally_retaliation_role, key::empty);
		if (role != key::empty && gd::bool_field(state, stack, key::ranged, false) != (role == key::ranged)) {
			continue;
		}
		return source_ability_context(state, source, brace);
	}
	return state.new_dict();
}

DictRef _counter_ambush_flare_context(State &state, DictRef battle, DictRef protected_stack, Atom ambush_ability_id) {
	if (gd::is_empty(state, protected_stack) || ambush_ability_id == key::empty) {
		return state.new_dict();
	}
	const ArrayRef sources = _alive_stacks_for_side(state, battle, gd::string_field(state, protected_stack, key::side, key::empty));
	for (const Value &source : gd::items(state, array_value(sources))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(source), key::counter_ambush_flare);
		if (gd::is_empty(state, ability)) {
			continue;
		}
		Value countered;
		if (!state.lookup(ability, str(key::countered_ability_ids), countered)) {
			continue; // the default [] has nothing
		}
		if (variant_has(state, countered, str(ambush_ability_id))) {
			return source_ability_context(state, source, ability);
		}
	}
	return state.new_dict();
}

DictRef _side_resonance_relay(State &state, DictRef battle, Atom side) {
	const ArrayRef payloads = _side_ability_payloads(state, battle, side, key::resonance_relay);
	if (state.array_size(payloads) != 0 && gd::is_dict(state.at(payloads, 0))) {
		return state.at(payloads, 0).ref;
	}
	return state.new_dict();
}

bool _battle_has_tag(State &state, DictRef battle, Atom tag) {
	if (tag == key::empty) {
		return false;
	}
	for (const Value &value : gd::field_items(state, battle, str(key::battlefield_tags))) {
		if (gd::to_string(value) == tag) {
			return true;
		}
	}
	return false;
}

bool _battle_has_any_tags(State &state, DictRef battle, ArrayRef tags) {
	for (const Value &tag_value : gd::items(state, array_value(tags))) {
		if (_battle_has_tag(state, battle, gd::to_string(tag_value))) {
			return true;
		}
	}
	return false;
}

Atom _capital_front_anchor_side(State &state, DictRef battle) {
	// battle.get("context", {}): the default {} is no town defense context, so
	// a missing context skips the check without building it.
	Value context;
	if (state.lookup(battle, str(key::context), context) && _is_town_defense_context(state, context)) {
		return key::player;
	}
	// _battle_has_any_tags(battle, [...]) over the literal's Strings.
	static constexpr Atom kAnchorTags[] = { key::fortress_lane, key::reserve_wave, key::battery_nest, key::wall_pressure };
	for (const Atom tag : kAnchorTags) {
		if (_battle_has_tag(state, battle, tag)) {
			return key::enemy;
		}
	}
	return key::empty;
}

Atom _capital_front_assault_side(State &state, DictRef battle) {
	const Atom anchor_side = _capital_front_anchor_side(state, battle);
	if (anchor_side == key::player) {
		return key::enemy;
	}
	if (anchor_side == key::enemy) {
		return key::player;
	}
	return key::empty;
}

bool _stack_is_anchor_side(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	return side == _capital_front_anchor_side(state, battle);
}

bool _stack_is_assault_side(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	return side == _capital_front_assault_side(state, battle);
}

bool _is_town_defense_context(State &state, const Value &context) {
	return gd::is_dict(context) && gd::string_field(state, context.ref, key::type, key::empty) == key::town_defense;
}

bool _reach_available(State &state, DictRef stack, DictRef battle) {
	const DictRef reach = _ability_by_id(state, stack, key::reach);
	if (gd::is_empty(state, reach)) {
		return false;
	}
	Value held_objective_types;
	if (!state.lookup(reach, str(key::held_objective_types), held_objective_types)) {
		return true; // the default [] is an empty Array
	}
	if (!gd::is_array(held_objective_types) || state.array_size(held_objective_types.ref) == 0) {
		return true;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	return any_controlled_objective_type(state, battle, side, held_objective_types);
}

bool _hookline_available(State &state, DictRef stack, DictRef battle) {
	const DictRef hookline = _ability_by_id(state, stack, key::hookline);
	if (gd::is_empty(state, hookline)) {
		return false;
	}
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const int64_t available_from = gd::int_field(state, hookline, key::available_from_round, 1);
	if (current_round < available_from) {
		return false;
	}
	Value ability_uses;
	if (!state.lookup(stack, str(key::ability_uses), ability_uses)) {
		ability_uses = dict_value(state.new_dict()); // the default {}
	}
	if (!gd::is_dict(ability_uses)) {
		return false;
	}
	const int64_t used = gd::int_field(state, ability_uses.ref, key::hookline, 0);
	return used < gd::int_field(state, hookline, key::uses_per_battle, 1);
}

bool _brace_has_held_objective(State &state, DictRef stack, DictRef battle, DictRef brace) {
	if (gd::is_empty(state, stack) || gd::is_empty(state, brace) || gd::float_field(state, brace, key::held_objective_retaliation_multiplier, 1.0) <= 1.0) {
		return false;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	Value held_objective_types;
	if (!state.lookup(brace, str(key::held_objective_types), held_objective_types)) {
		return false; // the default [] has nothing to walk
	}
	return any_controlled_objective_type(state, battle, side, held_objective_types);
}

bool _brace_available(State &state, DictRef stack, DictRef battle) {
	const DictRef brace = _ability_by_id(state, stack, key::brace);
	if (gd::is_empty(state, brace)) {
		return false;
	}
	Value held_objective_types;
	if (!state.lookup(brace, str(key::held_objective_types), held_objective_types)) {
		return true; // the default [] is an empty Array
	}
	if (!gd::is_array(held_objective_types) || state.array_size(held_objective_types.ref) == 0) {
		return true;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	return any_controlled_objective_type(state, battle, side, held_objective_types);
}

DictRef _bramble_ground_ability(State &state, DictRef stack) {
	return _authored_ability_by_id(state, stack, key::bramble_ground);
}

bool _bramble_ground_available(State &state, DictRef stack, DictRef battle, DictRef ability) {
	const DictRef bramble_ground = !gd::is_empty(state, ability) ? ability : _bramble_ground_ability(state, stack);
	if (gd::is_empty(state, stack) || gd::is_empty(state, bramble_ground)) {
		return false;
	}
	Value objective_types;
	if (!state.lookup(bramble_ground, str(key::held_objective_types), objective_types)) {
		return false; // the default [] is an empty Array
	}
	if (!gd::is_array(objective_types) || state.array_size(objective_types.ref) == 0) {
		return false;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	return any_controlled_objective_type(state, battle, side, objective_types);
}

DictRef _fog_screen_ability(State &state, DictRef stack) {
	return _authored_ability_by_id(state, stack, key::fog_screen);
}

bool _fog_screen_available(State &state, DictRef stack, DictRef battle, DictRef ability) {
	const DictRef fog_screen = !gd::is_empty(state, ability) ? ability : _fog_screen_ability(state, stack);
	if (gd::is_empty(state, stack) || gd::is_empty(state, fog_screen)) {
		return false;
	}
	Value required_tags;
	if (!state.lookup(fog_screen, str(key::required_battlefield_tags), required_tags)) {
		return false; // the default [] is an empty Array
	}
	if (!gd::is_array(required_tags) || state.array_size(required_tags.ref) == 0) {
		return false;
	}
	for (const Value &tag : gd::items(state, required_tags)) {
		if (_battle_has_tag(state, battle, gd::to_string(tag))) {
			return true;
		}
	}
	return false;
}

bool _volley_has_protected_lane(State &state, DictRef stack, DictRef battle, DictRef volley) {
	if (gd::is_empty(state, stack) || gd::is_empty(state, volley)) {
		return false;
	}
	if (!gd::bool_field(state, volley, key::requires_protected_lane, false)) {
		return true;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
	const ArrayRef allies = _alive_stacks_for_side(state, battle, side);
	for (const Value &ally : gd::items(state, array_value(allies))) {
		const DictRef ally_stack = gd::as_dict(ally);
		if (gd::string_field(state, ally_stack, key::battle_id, key::empty) != battle_id && gd::bool_field(state, ally_stack, key::defending, false) && _stack_hex_distance(state, stack, ally_stack) <= 1) {
			return true;
		}
	}
	Value objective_types;
	if (!state.lookup(volley, str(key::protected_lane_objective_types), objective_types)) {
		return false; // the default [] has nothing to walk
	}
	return any_controlled_objective_type(state, battle, side, objective_types);
}

bool _side_has_linked_unit(State &state, DictRef battle, Atom side, const Value &unit_ids) {
	if (!gd::is_array(unit_ids)) {
		return false;
	}
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		const Atom unit_id = gd::string_field(state, gd::as_dict(stack), key::unit_id, key::empty);
		if (gd::array_has(state, unit_ids.ref, str(unit_id))) {
			return true;
		}
	}
	return false;
}

int64_t _side_defending_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (gd::bool_field(state, gd::as_dict(stack), key::defending, false)) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

int64_t _allied_melee_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (!gd::bool_field(state, gd::as_dict(stack), key::ranged, false)) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

bool _side_has_role_mix(State &state, DictRef battle, Atom side) {
	bool has_ranged = false;
	bool has_melee = false;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (gd::bool_field(state, gd::as_dict(stack), key::ranged, false)) {
			has_ranged = true;
		} else {
			has_melee = true;
		}
		if (has_ranged && has_melee) {
			return true;
		}
	}
	return false;
}

int64_t _enemy_wounded_count(State &state, DictRef battle, Atom side) {
	const Atom target_side = side == key::player ? key::enemy : key::player;
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, target_side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (_health_ratio(state, gd::as_dict(stack)) <= 0.75) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

bool _stack_is_isolated(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, stack)) {
		return false;
	}
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const ArrayRef living_allies = _alive_stacks_for_side(state, battle, side);
	if (state.array_size(living_allies) <= 1) {
		return true;
	}
	if (gd::bool_field(state, stack, key::ranged, false)) {
		return _allied_melee_count(state, battle, side) <= 0;
	}
	return false;
}

bool _stack_is_hex_isolated(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, stack)) {
		return false;
	}
	const DictRef stack_hex = _stack_hex(state, stack);
	if (gd::is_empty(state, stack_hex)) {
		return _stack_is_isolated(state, battle, stack);
	}
	const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
	const ArrayRef allies = _alive_stacks_for_side(state, battle, gd::string_field(state, stack, key::side, key::empty));
	for (const Value &ally : gd::items(state, array_value(allies))) {
		const DictRef ally_stack = gd::as_dict(ally);
		if (gd::string_field(state, ally_stack, key::battle_id, key::empty) == battle_id) {
			continue;
		}
		const DictRef ally_hex = _stack_hex(state, ally_stack);
		if (!gd::is_empty(state, ally_hex) && _stack_hex_distance(state, stack, ally_stack) <= 1) {
			return false;
		}
	}
	return true;
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::battle_ai_rules {

using gd::str;
namespace key = state::key;

ArrayRef faction_brought_tags(State &state, DictRef stack) {
	const Atom faction_id = gd::string_field(state, stack, key::faction_id, key::empty);
	if (faction_id == key::empty) {
		return state.new_array();
	}
	const DictRef faction = gd::content_row(state, state::ContentTable::Faction, faction_id);
	Value tags;
	if (!state.lookup(faction, str(key::brings_battlefield_tags), tags)) {
		return state.new_array(); // the default [], returned as it is
	}
	// The faction row's own Array, not a copy.
	return gd::is_array(tags) ? tags.ref : state.new_array();
}

bool faction_brings_tag(State &state, DictRef stack, Atom tag) {
	return gd::array_has(state, faction_brought_tags(state, stack), str(tag));
}

} // namespace aurelion::rules::port::battle_ai_rules
