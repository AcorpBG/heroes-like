// Layer 4: round effects: foundry repair, town healing, pressure shifts, cohesion and momentum.

#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <string>

namespace aurelion::rules::port {

namespace key = state::key;

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::Kind;
using state::State;
using state::Value;

// x.size() of an untyped value: an Array or a Dictionary has one; Nil, a
// number, a String or a bool has no size() method.
int64_t untyped_size(const State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		return state.array_size(value.ref);
	}
	if (value.kind == Kind::Dict) {
		return state.dict_size(value.ref);
	}
	if (value.kind == Kind::Opaque) {
		throw state::ScriptError("size() of an opaque value is not ported");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'size' in base '") + gd::type_name(value) + "'.");
}

// x[index] of an untyped value with an int index: an Array's item (out of
// range is an error), a Dictionary's value of the int key (missing is an error).
Value untyped_at(const State &state, const Value &value, int64_t index) {
	if (value.kind == Kind::Array) {
		return state.at(value.ref, index);
	}
	if (value.kind == Kind::Dict) {
		return gd::index(state, value.ref, gd::int_value(index));
	}
	throw state::ScriptError(std::string("Invalid access of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x[index] = item of an untyped value with an int index.
void untyped_set_at(State &state, const Value &value, int64_t index, const Value &item) {
	if (value.kind == Kind::Array) {
		state.set_at(value.ref, index, item);
		return;
	}
	if (value.kind == Kind::Dict) {
		state.set(value.ref, gd::int_value(index), item);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x.get(field, fallback) of an untyped value: Dictionary.get. No other type
// GDScript can hold here has a get(key, default) (Nil, a number or a String
// has no get, an Array's or an Object's takes one argument): a runtime error.
Value variant_get(const State &state, const Value &base, Atom field, const Value &fallback) {
	if (base.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return state.get(base.ref, gd::str(field), fallback);
}

// var value: Dictionary = x: only a Dictionary assigns (Nil does not convert
// to Dictionary), anything else stops the script.
DictRef assign_dictionary(const Value &value) {
	if (value.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Dictionary'.");
	}
	return value.ref;
}

// d.get(key, []): the stored value, or a new empty Array when the key is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, gd::str(field), found)) {
		return found;
	}
	return gd::array_value(state.new_array());
}

// [a, b]: a new Array of two Strings.
ArrayRef string_pair(State &state, Atom a, Atom b) {
	const ArrayRef pair = state.new_array();
	state.append(pair, gd::str(a));
	state.append(pair, gd::str(b));
	return pair;
}

// `for x in value` as the VM runs it: an Array is walked live by index, its
// size read again at each step (OPCODE_ITERATE_ARRAY), so a body that writes
// into the Array keeps no reference into its items. Anything else goes
// through gd::items, copied first.
class Loop {
public:
	Loop(State &state, const Value &value) :
			state_(state), value_(value) {
		if (value.kind != Kind::Array) {
			snapshot_ = gd::items(state, value).list();
		}
	}
	bool next(Value &out) {
		if (value_.kind == Kind::Array) {
			if (index_ >= state_.array_size(value_.ref)) {
				return false;
			}
			out = state_.at(value_.ref, index_++);
			return true;
		}
		if (static_cast<size_t>(index_) >= snapshot_.size()) {
			return false;
		}
		out = snapshot_[static_cast<size_t>(index_++)];
		return true;
	}

private:
	State &state_;
	Value value_;
	state::ValueList snapshot_;
	int64_t index_ = 0;
};

} // namespace

} // namespace aurelion::rules::port

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::int_value;
using gd::str;

namespace {

// BattleRules consts.
constexpr int64_t COHESION_MIN = 0;
constexpr int64_t COHESION_MAX = 10;
constexpr int64_t MOMENTUM_MAX = 4;

} // namespace

int64_t _apply_foundry_aura_round_repair(State &state, DictRef battle) {
	int64_t total_restored = 0;
	static constexpr Atom kSides[] = { key::player, key::enemy };
	for (const Atom side : kSides) {
		DictRef aura_source = state.new_dict();
		const ArrayRef candidates = _alive_stacks_for_side(state, battle, side);
		for (const Value &candidate : gd::items(state, array_value(candidates))) {
			if (!gd::is_empty(state, _ability_by_id(state, gd::as_dict(candidate), key::foundry_aura))) {
				aura_source = gd::as_dict(candidate);
				break;
			}
		}
		if (gd::is_empty(state, aura_source)) {
			continue;
		}
		const double repair_pct = _side_max_ability_float(state, battle, side, key::foundry_aura, key::round_repair_pct, 0.0);
		const double overheated_bonus_pct = _side_max_ability_float(state, battle, side, key::foundry_aura, key::overheated_repair_bonus_pct, 0.0);
		if (repair_pct <= 0.0) {
			continue;
		}
		int64_t side_restored = 0;
		// A new Array of the side's stacks: the body writes into the battle's
		// stacks, not into it.
		const ArrayRef allies = _alive_stacks_for_side(state, battle, side);
		for (const Value &ally_value : gd::items(state, array_value(allies))) {
			const DictRef ally = gd::as_dict(ally_value);
			if (gd::string_field(state, ally, key::faction_id, key::empty) != key::faction_brasshollow) {
				continue;
			}
			// max(1, int) and max(0, int): ints.
			const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, ally, key::unit_hp, 1));
			const int64_t current_health = engine_max<int64_t>(0, gd::int_field(state, ally, key::total_health, 0));
			const int64_t max_recoverable_health = gd::mul(_alive_count(state, ally), unit_hp);
			if (current_health >= max_recoverable_health) {
				continue;
			}
			double active_repair_pct = repair_pct;
			const bool repairing_overheat = spell_rules::has_effect_id(state, ally, battle, key::status_overheated);
			if (repairing_overheat) {
				active_repair_pct += overheated_bonus_pct;
			}
			const int64_t base_max_health = engine_max<int64_t>(1, gd::mul(gd::int_field(state, ally, key::base_count, 1), unit_hp));
			// floor() of a float stays a float; int() truncates it.
			const int64_t requested_repair = engine_max<int64_t>(1, compat::float_to_int(compat::godot_floor(static_cast<double>(base_max_health) * active_repair_pct)));
			const int64_t restored = _restore_stack_health(state, battle, gd::string_field(state, ally, key::battle_id, key::empty), requested_repair);
			if (restored <= 0) {
				continue;
			}
			total_restored = gd::add(total_restored, restored);
			side_restored = gd::add(side_restored, restored);
			// The call's arguments in order: the text, then the context literal.
			const Atom ally_label = _stack_label(state, ally);
			const Atom source_label = _stack_label(state, aura_source);
			const Atom text = gd::format(state, state.intern("%s repairs %d health under %s."), { str(ally_label), int_value(restored), str(source_label) });
			const DictRef context = state.new_dict();
			state.set(context, str(key::action_id), str(key::foundry_aura));
			state.set(context, str(key::actor_battle_id), str(gd::string_field(state, aura_source, key::battle_id, key::empty)));
			state.set(context, str(key::target_battle_id), str(gd::string_field(state, ally, key::battle_id, key::empty)));
			state.set(context, str(key::healing), int_value(restored));
			state.set(context, str(key::overheated_priority), bool_value(repairing_overheat));
			_append_presentation_event(state, battle, key::heal, text, context);
		}
		if (side_restored > 0) {
			const Atom source_label = _stack_label(state, aura_source);
			_record_event(state, battle, gd::format(state, state.intern("%s repairs %d allied health as the pressure cycle resets."), { str(source_label), int_value(side_restored) }));
		}
	}
	return total_restored;
}

void _apply_round_pressure_shifts(State &state, DictRef battle) {
	// _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + extra,
	// the left side first.
	const auto cohesion_below_base = [&state, battle](DictRef stack, int64_t extra) {
		const int64_t total = _stack_cohesion_total(state, stack, battle);
		return total < gd::add(gd::int_field(state, stack, key::cohesion_base, 5), extra);
	};
	// _stack_cohesion_total(stack, battle) < max(6, int(stack.get("cohesion_base", 5))):
	// max of two ints is an int.
	const auto cohesion_below_linekeeper_floor = [&state, battle](DictRef stack) {
		const int64_t total = _stack_cohesion_total(state, stack, battle);
		return total < engine_max<int64_t>(6, gd::int_field(state, stack, key::cohesion_base, 5));
	};
	// _side_positive_effect_count(battle, side) >= int(relay.get("minimum_calibrated_stacks", 2)).
	const auto relay_calibrated = [&state, battle](Atom side, DictRef relay) {
		const int64_t count = _side_positive_effect_count(state, battle, side);
		return count >= gd::int_field(state, relay, key::minimum_calibrated_stacks, 2);
	};
	Loop loop(state, field_or_new_array(state, battle, key::stacks));
	Value stack_value;
	while (loop.next(stack_value)) {
		if (!gd::is_dict(stack_value) || _alive_count(state, stack_value.ref) <= 0) {
			continue;
		}
		const DictRef stack = stack_value.ref;
		const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
		const Atom side = gd::string_field(state, stack, key::side, key::empty);
		const int64_t round_number = gd::int_field(state, battle, key::round, 1);
		if (_stack_is_isolated(state, battle, stack)) {
			_adjust_stack_cohesion(state, battle, battle_id, -1);
		}
		if (spell_rules::has_any_effect_ids(state, stack, battle, array_value(string_pair(state, key::status_harried, key::status_staggered)))) {
			_adjust_stack_cohesion(state, battle, battle_id, -1);
		}
		if (_battle_has_tag(state, battle, key::fortress_lane)
				&& _stack_is_anchor_side(state, stack, battle)
				&& (gd::bool_field(state, stack, key::defending, false) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))
				&& cohesion_below_base(stack, 1)) {
			_adjust_stack_cohesion(state, battle, battle_id, 1);
		}
		if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
			if (cohesion_below_base(stack, 1)) {
				_adjust_stack_cohesion(state, battle, battle_id, 1);
			}
			_adjust_stack_momentum(state, battle, battle_id, 1);
		}
		if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && gd::bool_field(state, stack, key::ranged, false)) {
			if (cohesion_below_base(stack, 1)) {
				_adjust_stack_cohesion(state, battle, battle_id, 1);
			}
			if (_stack_has_positive_effect(state, stack, battle) || round_number <= 2) {
				_adjust_stack_momentum(state, battle, battle_id, 1);
			}
		}
		if (_battle_has_tag(state, battle, key::wall_pressure) && round_number >= 3) {
			if (_stack_is_assault_side(state, stack, battle) && !gd::bool_field(state, stack, key::ranged, false)) {
				_adjust_stack_momentum(state, battle, battle_id, 1);
			} else if (_stack_is_anchor_side(state, stack, battle) && gd::bool_field(state, stack, key::ranged, false) && _stack_is_isolated(state, battle, stack)) {
				_adjust_stack_cohesion(state, battle, battle_id, -1);
			}
		}
		if (_hero_has_trait(state, battle, side, key::linekeeper) && cohesion_below_linekeeper_floor(stack)) {
			if (gd::bool_field(state, stack, key::defending, false)
					|| _battle_has_any_tags(state, battle, string_pair(state, key::chokepoint, key::fortified_line))
					|| _brace_available(state, stack, battle)
					|| _has_ability(state, stack, key::formation_guard)) {
				_adjust_stack_cohesion(state, battle, battle_id, 1);
			}
		}
		if (_hero_has_trait(state, battle, side, key::bogwise)
				&& (_battle_has_tag(state, battle, key::bog_channels) || gd::string_field(state, battle, key::terrain, key::empty) == key::mire)
				&& cohesion_below_base(stack, 1)) {
			_adjust_stack_cohesion(state, battle, battle_id, 1);
		}
		if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_embercourt
				&& gd::int_field(state, battle, key::round, 1) >= 3
				&& _side_has_role_mix(state, battle, side)
				&& !_stack_is_isolated(state, battle, stack)
				&& cohesion_below_base(stack, 2)) {
			_adjust_stack_cohesion(state, battle, battle_id, 1);
		}
		if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_mireclaw
				&& _enemy_wounded_count(state, battle, side) > 0
				&& (_has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::bloodrush) || !gd::bool_field(state, stack, key::ranged, false))) {
			_adjust_stack_momentum(state, battle, battle_id, 1);
		}
		if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle)) {
			if (!_stack_is_isolated(state, battle, stack) && cohesion_below_base(stack, 2)) {
				_adjust_stack_cohesion(state, battle, battle_id, 1);
			}
			const DictRef resonance_relay = _side_resonance_relay(state, battle, side);
			if (!gd::is_empty(state, resonance_relay)
					&& relay_calibrated(side, resonance_relay)
					&& _battle_has_any_tags(state, battle, string_pair(state, key::elevated_fire, key::fortified_line))) {
				_adjust_stack_momentum(state, battle, battle_id, gd::int_field(state, resonance_relay, key::terrain_momentum_bonus, 0));
			}
		}
	}
	_apply_field_objective_round_effects(state, battle);
}

void _adjust_stack_cohesion(State &state, DictRef battle, Atom battle_id, int64_t amount) {
	if (amount == 0) {
		return;
	}
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	// range(stacks.size()): the size read once.
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && gd::string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			// The inner get (the fallback) is evaluated first; clamp of ints is an int.
			const Value fallback = state.get(stack.ref, str(key::cohesion_base), int_value(5));
			const int64_t cohesion = gd::to_int(state, state.get(stack.ref, str(key::cohesion), fallback));
			state.set(stack.ref, str(key::cohesion), int_value(engine_clamp<int64_t>(gd::add(cohesion, amount), COHESION_MIN, COHESION_MAX)));
			untyped_set_at(state, stacks, index, stack);
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
}

void _adjust_stack_momentum(State &state, DictRef battle, Atom battle_id, int64_t amount) {
	if (amount == 0) {
		return;
	}
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	// range(stacks.size()): the size read once.
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && gd::string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			const int64_t momentum = gd::int_field(state, stack.ref, key::momentum, 0);
			state.set(stack.ref, str(key::momentum), int_value(engine_clamp<int64_t>(gd::add(momentum, amount), 0, MOMENTUM_MAX)));
			untyped_set_at(state, stacks, index, stack);
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
}

void _apply_field_objective_round_effects(State &state, DictRef battle) {
	// _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 1,
	// the left side first.
	const auto cohesion_below_base = [&state, battle](DictRef stack) {
		const int64_t total = _stack_cohesion_total(state, stack, battle);
		return total < gd::add(gd::int_field(state, stack, key::cohesion_base, 5), 1);
	};
	// int(battle.get("round", 1)) >= int(objective.get("urgency_round", fallback)).
	const auto urgent = [&state, battle](DictRef objective, int64_t fallback) {
		const int64_t round_number = gd::int_field(state, battle, key::round, 1);
		return round_number >= gd::int_field(state, objective, key::urgency_round, fallback);
	};
	Loop loop(state, array_value(_field_objectives(state, battle)));
	Value objective_value;
	while (loop.next(objective_value)) {
		if (!gd::is_dict(objective_value)) {
			continue;
		}
		const DictRef objective = objective_value.ref;
		const Atom controller = gd::string_field(state, objective, key::control_side, key::neutral);
		// controller not in ["player", "enemy"]: a String matches by its text.
		if (!(controller == key::player || controller == key::enemy)) {
			continue;
		}
		const Atom objective_type = gd::string_field(state, objective, key::type, key::empty);
		if (objective_type == key::cover_line) {
			DictRef screened = _weakest_stack_by_role(state, battle, controller, true);
			if (gd::is_empty(state, screened)) {
				screened = _weakest_stack_by_cohesion(state, battle, controller);
			}
			if (!gd::is_empty(state, screened) && cohesion_below_base(screened)) {
				_adjust_stack_cohesion(state, battle, gd::string_field(state, screened, key::battle_id, key::empty), 1);
			}
		} else if (objective_type == key::obstruction_line) {
			const DictRef blocking_line = _weakest_stack_by_role(state, battle, controller, false);
			if (!gd::is_empty(state, blocking_line) && cohesion_below_base(blocking_line)) {
				_adjust_stack_cohesion(state, battle, gd::string_field(state, blocking_line, key::battle_id, key::empty), 1);
			}
			if (gd::int_field(state, battle, key::distance, 1) > 0) {
				const DictRef stalled = _highest_momentum_stack_for_side(state, battle, _opposing_side(controller));
				if (!gd::is_empty(state, stalled) && !gd::bool_field(state, stalled, key::ranged, false)) {
					_adjust_stack_momentum(state, battle, gd::string_field(state, stalled, key::battle_id, key::empty), -1);
				}
			}
		} else if (objective_type == key::ritual_pylon) {
			if (urgent(objective, 2)) {
				const DictRef pressured = _weakest_stack_by_cohesion(state, battle, _opposing_side(controller));
				if (!gd::is_empty(state, pressured)) {
					_adjust_stack_cohesion(state, battle, gd::string_field(state, pressured, key::battle_id, key::empty), -1);
				}
			}
		} else if (objective_type == key::supply_post) {
			const DictRef steadied = _weakest_stack_by_cohesion(state, battle, controller);
			if (!gd::is_empty(state, steadied) && cohesion_below_base(steadied)) {
				_adjust_stack_cohesion(state, battle, gd::string_field(state, steadied, key::battle_id, key::empty), 1);
			}
		} else if (objective_type == key::breach_point) {
			if (urgent(objective, 3)) {
				const DictRef surge_stack = _highest_momentum_stack_for_side(state, battle, controller);
				if (!gd::is_empty(state, surge_stack) && !gd::bool_field(state, surge_stack, key::ranged, false)) {
					_adjust_stack_momentum(state, battle, gd::string_field(state, surge_stack, key::battle_id, key::empty), 1);
				}
				const DictRef pressured_line = _weakest_stack_by_cohesion(state, battle, _opposing_side(controller));
				if (!gd::is_empty(state, pressured_line)) {
					_adjust_stack_cohesion(state, battle, gd::string_field(state, pressured_line, key::battle_id, key::empty), -1);
				}
			}
		} else if (objective_type == key::hazard_zone) {
			if (urgent(objective, 2)) {
				const DictRef exposed = _weakest_stack_by_cohesion(state, battle, _opposing_side(controller));
				if (!gd::is_empty(state, exposed)) {
					_adjust_stack_cohesion(state, battle, gd::string_field(state, exposed, key::battle_id, key::empty), -1);
				}
			}
		}
	}
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::town_battle_rules {

using compat::engine_max;
using compat::engine_min;
using gd::dict_value;
using gd::int_value;
using gd::str;

ArrayRef heal_round(State &state, DictRef battle) {
	const ArrayRef restored = state.new_array();
	const DictRef ward = effect(state, battle, key::root_ward);
	const int64_t round_number = gd::int_field(state, battle, key::round, 1);
	if (gd::is_empty(state, ward) || round_number < 2) {
		return restored;
	}
	// var state: Dictionary = battle.get("town_defenses", {}): the stored
	// Dictionary itself, or a new one when the key is missing.
	Value defenses_value;
	const DictRef defenses = state.lookup(battle, str(key::town_defenses), defenses_value) ? assign_dictionary(defenses_value) : state.new_dict();
	if (gd::int_field(state, defenses, key::last_healing_round, 0) >= round_number) {
		return restored;
	}
	state.set(defenses, str(key::last_healing_round), int_value(round_number));
	Loop loop(state, field_or_new_array(state, battle, key::stacks));
	Value stack;
	while (loop.next(stack)) {
		const int64_t health = gd::to_int(state, variant_get(state, stack, key::total_health, int_value(0)));
		if (!defends(state, battle, gd::as_dict(stack)) || health <= 0) {
			continue;
		}
		const int64_t hp = engine_max<int64_t>(1, gd::to_int(state, variant_get(state, stack, key::unit_hp, int_value(1))));
		// float / int is a float; ceil() of a float stays a float; int() truncates.
		const int64_t living = compat::float_to_int(compat::godot_ceil(static_cast<double>(health) / static_cast<double>(hp)));
		const int64_t missing = gd::sub(gd::mul(living, hp), health);
		const double heal_pct = gd::to_float(gd::field_or(state, ward, key::heal_pct, int_value(25)));
		const int64_t per_round = engine_max<int64_t>(1, compat::float_to_int(compat::godot_ceil(static_cast<double>(hp) * heal_pct / 100.0)));
		const int64_t amount = engine_min<int64_t>(missing, per_round);
		if (amount <= 0) {
			continue;
		}
		// stack["total_health"] = ...: stack is a Dictionary (its get() worked).
		state.set(stack.ref, str(key::total_health), int_value(gd::add(health, amount)));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::stack), stack);
		state.set(entry, str(key::amount), int_value(amount));
		state.append(restored, dict_value(entry));
	}
	return restored;
}

} // namespace aurelion::rules::port::town_battle_rules
