// Layer 8: the battle spells. A spell's battle behavior, the cast and target checks, spell and control resistance,
// the damage, recovery and duration of a cast, the effect payloads and the status resistance roll; a hero's known
// spells, the validation and resolution of a cast and the mana it spends.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::spell_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// SpellRules consts.
constexpr int64_t MAX_SPELL_RESISTANCE_PCT = 75;
constexpr int64_t MAX_CONTROL_RESISTANCE_PCT = 80;
constexpr int64_t POWER_PER_EXTRA_ROUND = 4;
constexpr int64_t TURN_EFFECT_ROUND_SENTINEL = 1000000;
// Heat's burst: {25+12E} (docs/magic-system-spells.md, Damage).
constexpr int64_t HEAT_BURST_BASE = 25;
constexpr int64_t HEAT_BURST_PER_POWER = 12;

// One more turn per POWER_PER_EXTRA_ROUND spell power, with no limit.
int64_t duration_bonus_at(int64_t power) {
	return compat::int_div(engine_max<int64_t>(0, power), POWER_PER_EXTRA_ROUND);
}

// d.get(key, {}) and d.get(key, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument get (Array.get and Object.get take
// one), so anything else stops the script.
DictRef two_argument_get_target(const Value &target) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
	}
	return target.ref;
}

// String(stack.get("side", "")).
Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

DictRef accepted(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	return result;
}

// {"ok": false, "hero": hero, "message": message}.
DictRef hero_refusal(State &state, DictRef hero, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(message));
	return result;
}

// The head of every resolved cast: {"ok": true, "hero": hero, "resolution_type": ..., "target_battle_id": ...}.
DictRef cast_result(State &state, DictRef hero, Atom resolution_type, Atom target_battle_id) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::resolution_type), str(resolution_type));
	state.set(result, str(key::target_battle_id), str(target_battle_id));
	return result;
}

// A cast Prism Ward turned aside: the warded stack it left, and its line before the cast's own.
Atom with_reflection(State &state, DictRef result, Atom reflected_from, Atom reflect_text, Atom message) {
	if (reflected_from == key::empty) {
		return message;
	}
	state.set(result, str(key::reflected_from_battle_id), str(reflected_from));
	return state.intern(state.text(reflect_text) + state.text(message));
}

// "%s casts %s on %s." of a cast on an ally.
Atom ally_cast_message(State &state, Atom caster_name, DictRef spell, Atom spell_id, DictRef ally_target) {
	return gd::format(state, key::casts_on_format, { str(caster_name), str(gd::string_field(state, spell, key::name, spell_id)), str(gd::string_field(state, ally_target, key::name, key::the_line_text)) });
}

// The literal battle_spell_status_resolution returns, in its order.
DictRef status_resolution(State &state, bool blocked, bool immune, bool resisted, Atom blocked_status_id, int64_t resistance_pct, int64_t roll) {
	const DictRef resolution = state.new_dict();
	state.set(resolution, str(key::blocked), bool_value(blocked));
	state.set(resolution, str(key::immune), bool_value(immune));
	state.set(resolution, str(key::resisted), bool_value(resisted));
	state.set(resolution, str(key::blocked_status_id), str(blocked_status_id));
	state.set(resolution, str(key::control_resistance_pct), int_value(resistance_pct));
	state.set(resolution, str(key::resistance_roll), int_value(roll));
	return resolution;
}

// s.to_lower() of ASCII text (other text throws: the Unicode case tables are not ported).
Atom to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::ScriptError("to_lower() of non-ASCII text is not ported");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// RandomNumberGenerator.new(), then .seed = seed: its .state as GDScript's int.
int64_t seeded_rng_state(int64_t seed) {
	compat::GodotPcg pcg;
	pcg.seed(static_cast<uint64_t>(seed));
	return static_cast<int64_t>(pcg.state());
}

} // namespace

DictRef battle_spell_behavior(State &state, DictRef spell) {
	if (gd::is_empty(state, spell) || gd::string_field(state, spell, key::context, key::empty) != key::battle) {
		return state.new_dict();
	}
	const Value effect = get_or_new_dict(state, spell, key::effect);
	if (!gd::is_dict(effect)) {
		return state.new_dict();
	}
	const Atom effect_type = gd::string_field(state, effect.ref, key::type, key::empty);
	const ArrayRef hooks = state.new_array();
	Atom resolution_type = key::empty;
	Atom public_effect = key::empty;
	if (effect_type == key::damage_enemy) {
		resolution_type = key::damage;
		state.append(hooks, str(key::battle_damage));
		const Value status_effect = get_or_new_dict(state, effect.ref, key::status_effect);
		if (gd::is_dict(status_effect) && !gd::is_empty(state, status_effect.ref)) {
			state.append(hooks, str(key::battle_status_effect));
		}
		if (gd::int_field(state, effect.ref, key::wounded_bonus_damage, 0) > 0) {
			state.append(hooks, str(key::wounded_priority_bonus));
		}
		public_effect = key::enemy_damage_text;
	} else if (effect_type == key::control_enemy) {
		resolution_type = key::effect;
		state.append(hooks, str(key::enemy_status_control));
		public_effect = key::enemy_control_status_text;
	} else if (effect_type == key::recover_ally) {
		resolution_type = key::recover_effect;
		state.append(hooks, str(key::ally_health_recovery));
		if (!gd::is_empty(state, battle_spell_modifiers(state, spell))) {
			state.append(hooks, str(key::ally_status_effect));
		}
		public_effect = key::ally_recovery_and_ward_text;
	} else if (effect_type == key::cleanse_ally) {
		resolution_type = key::cleanse_effect;
		state.append(hooks, str(key::ally_status_cleanse));
		if (!gd::is_empty(state, battle_spell_modifiers(state, spell))) {
			state.append(hooks, str(key::ally_status_effect));
		}
		public_effect = key::ally_cleanse_and_ward_text;
	} else if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff || effect_type == key::ally_effect) {
		resolution_type = key::effect;
		state.append(hooks, str(key::ally_status_effect));
		public_effect = key::ally_modifier_effect_text;
	} else if (effect_type == key::dispel_enemy) {
		resolution_type = key::dispel_effect;
		state.append(hooks, str(key::enemy_spell_dispel));
		public_effect = key::enemy_dispel_text;
	} else if (effect_type == key::move_ally) {
		resolution_type = key::move_effect;
		state.append(hooks, str(key::ally_reposition));
		public_effect = key::ally_reposition_text;
	} else if (effect_type == key::graft_allies) {
		resolution_type = key::effect;
		state.append(hooks, str(key::ally_status_effect));
		public_effect = key::ally_modifier_effect_text;
	} else if (effect_type == key::transfer_ally) {
		resolution_type = key::transfer_effect;
		state.append(hooks, str(key::ally_health_recovery));
		public_effect = key::ally_recovery_and_ward_text;
	} else if (effect_type == key::swap_allies || effect_type == key::swap_enemy) {
		resolution_type = key::swap_effect;
		state.append(hooks, str(key::ally_reposition));
		public_effect = key::ally_reposition_text;
	} else {
		resolution_type = key::unsupported;
		public_effect = key::unsupported_battle_effect_text;
	}
	// The literal's values in its order.
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const Atom name = gd::string_field(state, spell, key::name, key::empty);
	const Atom school_id = spell_school_id(state, spell);
	const int64_t tier = spell_tier(state, spell);
	const Atom primary_role = spell_primary_role(state, spell);
	const ArrayRef role_categories = spell_role_categories(state, spell);
	const Atom target_mode = gd::string_field(state, spell, key::target_mode, key::empty);
	const DictRef behavior = state.new_dict();
	state.set(behavior, str(key::spell_id), str(spell_id));
	state.set(behavior, str(key::name), str(name));
	state.set(behavior, str(key::school_id), str(school_id));
	state.set(behavior, str(key::tier), int_value(tier));
	state.set(behavior, str(key::primary_role), str(primary_role));
	state.set(behavior, str(key::role_categories), array_value(role_categories));
	state.set(behavior, str(key::effect_type), str(effect_type));
	state.set(behavior, str(key::target_mode), str(target_mode));
	state.set(behavior, str(key::resolution_type), str(resolution_type));
	state.set(behavior, str(key::runtime_hooks), array_value(hooks));
	state.set(behavior, str(key::public_effect), str(public_effect));
	return behavior;
}

DictRef _battle_spell_ally_target(State &state, DictRef active_stack, DictRef target_stack, Atom acting_side) {
	if (!gd::is_empty(state, target_stack) && side_of(state, target_stack) == acting_side) {
		return target_stack;
	}
	return active_stack;
}

DictRef battle_spell_cast_check(State &state, DictRef hero, DictRef spell_dict, DictRef active_stack, Atom acting_side) {
	if (gd::is_empty(state, spell_dict)) {
		return refusal(state, key::spell_not_known_text);
	}
	if (gd::string_field(state, spell_dict, key::context, key::empty) != key::battle) {
		return refusal(state, key::spell_not_for_battle_text);
	}
	if (gd::is_empty(state, active_stack) || side_of(state, active_stack) != acting_side) {
		return refusal(state, key::not_this_sides_turn_text);
	}
	if (!_has_mana(state, hero, adjusted_spell_mana_cost(state, hero, dict_value(spell_dict)))) {
		return refusal(state, key::insufficient_mana_text);
	}
	return accepted(state);
}

DictRef battle_spell_target_check(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell_dict, Atom acting_side) {
	const Value effect = get_or_new_dict(state, spell_dict, key::effect);
	const Atom effect_type = gd::to_string(state.get(two_argument_get_target(effect), str(key::type), str(key::empty)));
	if (effect_type == key::damage_enemy) {
		if (gd::is_empty(state, target_stack) || side_of(state, target_stack) == acting_side) {
			return refusal(state, key::select_enemy_target_text);
		}
		return accepted(state);
	}
	if (effect_type == key::control_enemy) {
		if (gd::is_empty(state, target_stack) || side_of(state, target_stack) == acting_side) {
			return refusal(state, key::select_enemy_target_text);
		}
		if (gd::is_empty(state, _status_effect_from_spell_effect(state, spell_dict, battle, state.new_dict()))) {
			return refusal(state, key::control_spell_no_status_text);
		}
		return accepted(state);
	}
	if (effect_type == key::recover_ally) {
		const DictRef recover_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, recover_target) || side_of(state, recover_target) != acting_side) {
			return refusal(state, key::select_allied_target_text);
		}
		return accepted(state);
	}
	if (effect_type == key::cleanse_ally) {
		const DictRef cleanse_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, cleanse_target) || side_of(state, cleanse_target) != acting_side) {
			return refusal(state, key::select_allied_target_text);
		}
		// A cleanse that names no status takes any harmful effect (Cleanse).
		if (cleanse_takes_any_harm(state, two_argument_get_target(effect))) {
			if (state.array_size(newest_effect_ids(state, cleanse_target, battle, false, 1)) == 0) {
				return refusal(state, key::no_matching_pressure_text);
			}
			return accepted(state);
		}
		const ArrayRef cleanse_effect_ids = _normalize_string_array(state, get_or_new_array(state, two_argument_get_target(effect), key::cleanse_effect_ids));
		if (state.array_size(cleanse_effect_ids) == 0) {
			return refusal(state, key::cleanse_spell_no_target_text);
		}
		if (!has_any_effect_ids(state, cleanse_target, battle, array_value(cleanse_effect_ids)) && gd::is_empty(state, battle_spell_modifiers(state, spell_dict))) {
			return refusal(state, key::no_matching_pressure_text);
		}
		return accepted(state);
	}
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff || effect_type == key::ally_effect) {
		const DictRef buff_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, buff_target) || side_of(state, buff_target) != acting_side) {
			return refusal(state, key::select_allied_target_text);
		}
		return accepted(state);
	}
	if (effect_type == key::dispel_enemy) {
		if (gd::is_empty(state, target_stack) || side_of(state, target_stack) == acting_side) {
			return refusal(state, key::select_enemy_target_text);
		}
		if (state.array_size(newest_effect_ids(state, target_stack, battle, true, 1)) == 0) {
			return refusal(state, key::no_helpful_spell_effect_text);
		}
		return accepted(state);
	}
	if (effect_type == key::move_ally) {
		const DictRef move_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, move_target) || side_of(state, move_target) != acting_side || _alive_count(state, move_target) <= 0) {
			return refusal(state, key::select_allied_target_text);
		}
		if (battle_rules::_stack_is_rooted(state, move_target, battle)) {
			return refusal(state, gd::format(state, key::rooted_cannot_move_text, { str(battle_rules::_stack_label(state, move_target)) }));
		}
		return accepted(state);
	}
	// Two stacks: the first is checked here, the second when the cast names it.
	if (effect_type == key::graft_allies || effect_type == key::transfer_ally || effect_type == key::swap_allies) {
		const DictRef first = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, first) || side_of(state, first) != acting_side || _alive_count(state, first) <= 0) {
			return refusal(state, key::select_allied_target_text);
		}
		if (effect_type == key::swap_allies && battle_rules::_stack_is_rooted(state, first, battle)) {
			return refusal(state, gd::format(state, key::rooted_cannot_move_text, { str(battle_rules::_stack_label(state, first)) }));
		}
		if (effect_type == key::transfer_ally) {
			if (heal_blocked(state, first, battle)) {
				return refusal(state, gd::format(state, key::wound_sealed_text, { str(battle_rules::_stack_label(state, first)) }));
			}
			if (stack_full_health(state, first) <= gd::int_field(state, first, key::total_health, 0)) {
				return refusal(state, gd::format(state, key::no_health_missing_text, { str(battle_rules::_stack_label(state, first)) }));
			}
		}
		return accepted(state);
	}
	if (effect_type == key::swap_enemy) {
		if (gd::is_empty(state, target_stack) || side_of(state, target_stack) == acting_side || _alive_count(state, target_stack) <= 0) {
			return refusal(state, key::select_enemy_target_text);
		}
		if (battle_rules::_stack_is_rooted(state, target_stack, battle)) {
			return refusal(state, gd::format(state, key::rooted_cannot_move_text, { str(battle_rules::_stack_label(state, target_stack)) }));
		}
		return accepted(state);
	}
	return refusal(state, key::battle_spell_unsupported_text);
}

int64_t spell_damage_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell) {
	const Atom school_id = gd::string_field(state, spell, key::school_id, key::empty);
	int64_t total = gd::int_field(state, target_stack, key::spell_resistance_pct, 0);
	total = gd::add(total, town_battle_rules::spell_resistance(state, battle, target_stack));
	const DictRef stack_schools = normalize_school_resistance(state, get_or_new_dict(state, target_stack, key::spell_school_resistance_pct));
	total = gd::add(total, gd::int_field(state, stack_schools, school_id, 0));
	const DictRef hero = _hero_payload_for_target_side(state, battle, target_stack);
	total = gd::add(total, gd::int_field(state, hero, key::battle_spell_resistance_pct, 0));
	const DictRef hero_schools = normalize_school_resistance(state, get_or_new_dict(state, hero, key::battle_school_resistance_pct));
	total = gd::add(total, gd::int_field(state, hero_schools, school_id, 0));
	return engine_clamp<int64_t>(total, 0, MAX_SPELL_RESISTANCE_PCT);
}

int64_t control_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell) {
	const Atom school_id = gd::string_field(state, spell, key::school_id, key::empty);
	int64_t total = gd::int_field(state, target_stack, key::control_resistance_pct, 0);
	const DictRef stack_schools = normalize_school_resistance(state, get_or_new_dict(state, target_stack, key::spell_school_resistance_pct));
	total = gd::add(total, gd::int_field(state, stack_schools, school_id, 0));
	const DictRef hero = _hero_payload_for_target_side(state, battle, target_stack);
	total = gd::add(total, gd::int_field(state, hero, key::battle_control_resistance_pct, 0));
	const DictRef hero_schools = normalize_school_resistance(state, get_or_new_dict(state, hero, key::battle_school_resistance_pct));
	total = gd::add(total, gd::int_field(state, hero_schools, school_id, 0));
	return engine_clamp<int64_t>(total, 0, MAX_CONTROL_RESISTANCE_PCT);
}

DictRef battle_spell_damage_projection(State &state, DictRef hero_state, DictRef battle, DictRef target_stack, DictRef spell) {
	const int64_t raw_damage = _battle_spell_damage_at(state, hero_state, spell, target_stack, spell_power_against(state, hero_state, battle, target_stack));
	const int64_t resistance_pct = spell_damage_resistance_pct(state, battle, target_stack, spell);
	const double scaled = static_cast<double>(raw_damage) * static_cast<double>(gd::sub(100, resistance_pct)) / 100.0;
	const int64_t final_damage = engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(scaled)));
	const DictRef projection = state.new_dict();
	state.set(projection, str(key::raw_damage), int_value(raw_damage));
	state.set(projection, str(key::final_damage), int_value(final_damage));
	state.set(projection, str(key::damage), int_value(final_damage));
	state.set(projection, str(key::resistance_pct), int_value(resistance_pct));
	state.set(projection, str(key::prevented_damage), int_value(engine_max<int64_t>(0, gd::sub(raw_damage, final_damage))));
	return projection;
}

DictRef battle_spell_status_resolution(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, DictRef effect_payload) {
	const Atom status_id = gd::string_field(state, effect_payload, key::effect_id, key::empty);
	if (status_id == key::empty) {
		return status_resolution(state, false, false, false, key::empty, 0, -1);
	}
	if (target_is_immune_to_status(state, target_stack, battle, status_id)) {
		return status_resolution(state, true, true, false, status_id, control_resistance_pct(state, battle, target_stack, spell), -1);
	}
	const int64_t resistance_pct = control_resistance_pct(state, battle, target_stack, spell);
	int64_t roll = -1;
	Atom rng_state = key::empty;
	if (resistance_pct > 0) {
		const DictRef draw = _status_resistance_roll(state, battle, active_stack, target_stack, spell, status_id);
		roll = gd::int_field(state, draw, key::roll, -1);
		rng_state = gd::string_field(state, draw, key::rng_state, key::empty);
	}
	const bool resisted = resistance_pct > 0 && roll < resistance_pct;
	const DictRef resolution = status_resolution(state, resisted, false, resisted, resisted ? status_id : static_cast<Atom>(key::empty), resistance_pct, roll);
	if (rng_state != key::empty) {
		state.set(resolution, str(key::resistance_rng_state), str(rng_state));
	}
	return resolution;
}

int64_t spell_duration_bonus(State &state, DictRef hero_state) {
	return duration_bonus_at(spell_power(state, hero_state));
}

int64_t spell_duration_rounds(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind) {
	return _spell_duration_rounds_at(state, hero_state, base_rounds, spell, kind, spell_power(state, hero_state));
}

int64_t _spell_duration_rounds_at(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind, int64_t power) {
	int64_t rounds = engine_max<int64_t>(1, gd::to_int(state, base_rounds));
	rounds = gd::add(rounds, duration_bonus_at(power));
	const DictRef bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	rounds = gd::add(rounds, gd::int_field(state, bonuses, kind == key::debuff ? key::debuff_duration_bonus : key::buff_duration_bonus, 0));
	rounds = gd::add(rounds, _school_bonus(state, bonuses, key::school_duration_bonus, spell));
	return rounds;
}

int64_t spell_power(State &state, DictRef hero_state) {
	const Value command = get_or_new_dict(state, hero_state, key::command);
	const int64_t power = gd::is_dict(command) ? engine_max<int64_t>(0, gd::int_field(state, command.ref, key::power, 0)) : 0;
	const DictRef bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	return gd::add(power, engine_max<int64_t>(0, gd::int_field(state, bonuses, key::battle_power, 0)));
}

int64_t target_side_knowledge(State &state, DictRef battle, DictRef target_stack) {
	if (gd::is_empty(state, target_stack)) {
		return 0;
	}
	const DictRef hero = _hero_payload_for_target_side(state, battle, target_stack);
	return engine_max<int64_t>(0, gd::int_field(state, hero, key::knowledge, 0));
}

int64_t spell_power_against(State &state, DictRef hero_state, DictRef battle, DictRef target_stack) {
	return engine_max<int64_t>(0, gd::sub(spell_power(state, hero_state), target_side_knowledge(state, battle, target_stack)));
}

int64_t _school_bonus(State &state, DictRef bonuses, Atom field, DictRef spell) {
	const Value by_school = get_or_new_dict(state, bonuses, field);
	if (!gd::is_dict(by_school) || gd::is_empty(state, spell)) {
		return 0;
	}
	return gd::int_field(state, by_school.ref, gd::string_field(state, spell, key::school_id, key::empty), 0);
}

DictRef _counted_in_turns(State &state, DictRef effect, int64_t turns) {
	state.set(effect, str(key::turns_left), int_value(engine_max<int64_t>(1, turns)));
	state.set(effect, str(key::expires_after_round), int_value(TURN_EFFECT_ROUND_SENTINEL));
	return effect;
}

DictRef battle_spell_modifiers(State &state, DictRef spell) {
	const Value effect = get_or_new_dict(state, spell, key::effect);
	const Atom effect_type = gd::to_string(state.get(two_argument_get_target(effect), str(key::type), str(key::empty)));
	Atom kind = key::empty;
	if (effect_type == key::defense_buff || effect_type == key::recover_ally || effect_type == key::cleanse_ally) {
		kind = key::defense;
	} else if (effect_type == key::initiative_buff) {
		kind = key::initiative;
	} else if (effect_type == key::attack_buff) {
		kind = key::attack;
	} else if (effect_type == key::ally_effect) {
		// An ally effect's modifiers are its own; it may have none (a mechanic only).
		const Value modifiers = get_or_new_dict(state, effect.ref, key::modifiers);
		return gd::is_dict(modifiers) ? _normalize_effect_modifiers(state, modifiers) : state.new_dict();
	} else {
		return state.new_dict();
	}
	return _spell_effect_modifiers(state, effect.ref, kind, gd::int_field(state, effect.ref, key::amount, 0));
}

int64_t heat_burst_damage(int64_t power_against) {
	return gd::add(HEAT_BURST_BASE, gd::mul(HEAT_BURST_PER_POWER, engine_max<int64_t>(0, power_against)));
}

DictRef scaled_spell_modifiers(State &state, DictRef effect, DictRef modifiers, int64_t power) {
	const int64_t scale = gd::int_field(state, effect, key::modifiers_power_scale, 0);
	const int64_t divisor = gd::int_field(state, effect, key::modifiers_power_divisor, 0);
	if (scale == 0 && divisor <= 0) {
		return modifiers;
	}
	// Each modifier grows away from zero by scale x power and power / divisor.
	const int64_t extra = gd::add(gd::mul(scale, engine_max<int64_t>(0, power)), divisor > 0 ? compat::int_div(engine_max<int64_t>(0, power), divisor) : 0);
	const DictRef scaled = state.new_dict();
	const state::ValueList names = state.dict(modifiers).keys.list();
	for (const Value &name : names) {
		const int64_t amount = gd::to_int(state, gd::index(state, modifiers, name));
		state.set(scaled, name, int_value(amount < 0 ? gd::sub(amount, extra) : gd::add(amount, extra)));
	}
	return scaled;
}

int64_t spell_effect_turns(State &state, DictRef hero_state, DictRef effect, DictRef spell, Atom kind, int64_t power) {
	if (gd::bool_field(state, effect, key::fixed_duration, false)) {
		return engine_max<int64_t>(1, gd::int_field(state, effect, key::duration_rounds, 1));
	}
	return _spell_duration_rounds_at(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, kind, power);
}

void set_effect_mechanic(State &state, DictRef built, DictRef holder, int64_t power) {
	Value raw_mechanic;
	if (state.lookup(holder, str(key::mechanic), raw_mechanic) && gd::is_dict(raw_mechanic)) {
		state.set(built, str(key::mechanic), dict_value(resolve_mechanic(state, raw_mechanic, power)));
	}
}

DictRef _effect_payload(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state) {
	return _effect_payload_for(state, spell, effect, battle, hero_state, state.new_dict());
}

DictRef _effect_payload_for(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state, DictRef target_stack) {
	const int64_t power = spell_power(state, hero_state);
	const DictRef modifiers = scaled_spell_modifiers(state, effect, battle_spell_modifiers(state, spell), power);
	// build_battle_effect's arguments in their order, then the second duration.
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const Atom effect_id = gd::format(state, key::spell_effect_id_format, { str(spell_id), str(gd::string_field(state, effect, key::type, key::empty)) });
	const Atom label = gd::string_field(state, spell, key::name, key::spell_word);
	const int64_t duration = spell_effect_turns(state, hero_state, effect, spell, key::buff, power);
	const Atom source_id = gd::string_field(state, spell, key::id, key::empty);
	const Value immunity_ids = get_or_new_array(state, effect, key::status_immunity_ids);
	const DictRef built = build_battle_effect(state, effect_id, label, dict_value(modifiers), duration, battle, key::spell, source_id, immunity_ids);
	// A mechanic's harmful numbers (thorns) grow with power less the other side's Knowledge.
	Value raw_mechanic;
	const bool against_enemy = state.lookup(effect, str(key::mechanic), raw_mechanic) && gd::is_dict(raw_mechanic)
			&& gd::bool_field(state, raw_mechanic.ref, key::uses_enemy_power, false) && !gd::is_empty(state, target_stack);
	const int64_t mechanic_power = against_enemy ? engine_max<int64_t>(0, gd::sub(power, opposing_side_knowledge(state, battle, side_of(state, target_stack)))) : power;
	set_effect_mechanic(state, built, effect, mechanic_power);
	return _counted_in_turns(state, built, duration);
}

DictRef heal_block_payload(State &state, DictRef spell, DictRef battle, int64_t turns) {
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const Atom effect_id = gd::format(state, key::spell_effect_id_format, { str(spell_id), str(key::heal_block) });
	const DictRef built = build_battle_effect(state, effect_id, key::sealed_wound_text, dict_value(state.new_dict()), turns, battle, key::spell, spell_id, array_value(state.new_array()));
	const DictRef mechanic = state.new_dict();
	state.set(mechanic, str(key::heal_block), int_value(1));
	state.set(built, str(key::mechanic), dict_value(mechanic));
	return _counted_in_turns(state, built, turns);
}

DictRef _hero_payload_for_target_side(State &state, DictRef battle, DictRef target_stack) {
	const Atom side = side_of(state, target_stack);
	Value payload;
	if (side == key::player) {
		payload = get_or_new_dict(state, battle, key::player_hero);
	} else if (side == key::enemy) {
		const Value fallback = get_or_new_dict(state, battle, key::enemy_hero);
		payload = state.get(battle, str(key::enemy_hero_payload), fallback);
	} else if (side == key::side_a) {
		payload = get_or_new_dict(state, battle, key::side_a_hero);
	} else if (side == key::side_b) {
		payload = get_or_new_dict(state, battle, key::side_b_hero);
	} else {
		return state.new_dict();
	}
	return gd::is_dict(payload) ? payload.ref : state.new_dict();
}

DictRef _status_resistance_roll(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, Atom status_id) {
	const Value rng = _battle_stream_rng(state, battle);
	const DictRef draw = state.new_dict();
	if (rng.kind != Kind::Nil) {
		const int64_t roll = gd::rng_randi_range(state, rng, 0, 99);
		state.set(draw, str(key::roll), int_value(roll));
		state.set(draw, str(key::rng_state), str(state.intern(compat::itos(gd::rng_state(state, rng)))));
		return draw;
	}
	const ArrayRef parts = state.new_array();
	state.append(parts, int_value(gd::int_field(state, battle, key::round, 1)));
	state.append(parts, str(gd::string_field(state, active_stack, key::battle_id, key::empty)));
	state.append(parts, str(gd::string_field(state, target_stack, key::battle_id, key::empty)));
	state.append(parts, str(gd::string_field(state, spell, key::id, key::empty)));
	state.append(parts, str(status_id));
	state.append(parts, str(gd::stringify(state, gd::field_or(state, battle, key::resistance_seed, str(key::empty)))));
	state.set(draw, str(key::roll), int_value(_stable_percent(state, parts)));
	return draw;
}

Value _battle_stream_rng(State &state, DictRef battle) {
	const int64_t seed = gd::int_field(state, battle, key::combat_seed, 0);
	const Atom state_text = gd::strip_edges(state, gd::string_field(state, battle, key::damage_rng_state, key::empty));
	const bool has_state = gd::is_valid_int(state, state_text);
	if (seed == 0 && !has_state) {
		return Value();
	}
	// Same construction as the damage stream: seed, then the persisted state.
	const int64_t used_seed = seed != 0 ? seed : 1;
	const int64_t rng_state = has_state ? compat::to_int(state.text(state_text)) : seeded_rng_state(used_seed);
	return gd::rng_new(state, used_seed, rng_state);
}

int64_t _stable_percent(State &state, ArrayRef parts) {
	const ArrayRef text_parts = state.new_array();
	for (const Value &part : gd::items(state, array_value(parts))) {
		state.append(text_parts, str(gd::stringify(state, part)));
	}
	return compat::posmod(gd::hash(state, array_value(text_parts)), 100);
}

Atom _append_status_resolution_message(State &state, Atom message, DictRef target_stack, DictRef effect_payload, DictRef status_resolution) {
	if (gd::is_empty(state, effect_payload) || !gd::bool_field(state, status_resolution, key::blocked, false)) {
		return message;
	}
	const Value label_fallback = state.get(effect_payload, str(key::effect_id), str(key::the_effect_text));
	const Atom label = to_lower(state, gd::to_string(state.get(effect_payload, str(key::label), label_fallback)));
	const Atom target_name = gd::string_field(state, target_stack, key::name, key::the_target_capital_text);
	if (gd::bool_field(state, status_resolution, key::immune, false)) {
		return gd::format(state, key::message_target_immune_format, { str(message), str(target_name), str(label) });
	}
	if (gd::bool_field(state, status_resolution, key::resisted, false)) {
		return gd::format(state, key::message_target_resists_format, { str(message), str(target_name), str(label) });
	}
	return message;
}

DictRef _spell_effect_modifiers(State &state, DictRef effect, Atom default_kind, int64_t default_amount) {
	const Value modifiers = get_or_new_dict(state, effect, key::modifiers);
	if (gd::is_dict(modifiers) && !gd::is_empty(state, modifiers.ref)) {
		return _normalize_effect_modifiers(state, modifiers);
	}
	// An effect with neither modifiers nor an amount carries no boost (Mend's
	// heal, Cleanse): only an amount stands for the kind's modifier.
	if (!state.has(effect, str(key::amount))) {
		return state.new_dict();
	}
	const DictRef fallback = state.new_dict();
	state.set(fallback, str(default_kind), int_value(engine_max<int64_t>(1, default_amount)));
	return _normalize_effect_modifiers(state, dict_value(fallback));
}

DictRef _status_effect_from_spell_effect(State &state, DictRef spell, DictRef battle, DictRef hero_state) {
	return _status_effect_from_spell_effect_at(state, spell, battle, hero_state, spell_power(state, hero_state));
}

DictRef _status_effect_from_spell_effect_at(State &state, DictRef spell, DictRef battle, DictRef hero_state, int64_t power) {
	const Value effect = get_or_new_dict(state, spell, key::effect);
	const Value status_effect = get_or_new_dict(state, two_argument_get_target(effect), key::status_effect);
	return _status_payload(state, spell, status_effect, battle, hero_state, power, 0);
}

DictRef _status_payload(State &state, DictRef spell, const Value &status_effect, DictRef battle, DictRef hero_state, int64_t power, int64_t extra_turns) {
	if (!gd::is_dict(status_effect) || gd::is_empty(state, status_effect.ref)) {
		return state.new_dict();
	}
	const DictRef status = status_effect.ref;
	const Value id_fallback = state.get(status, str(key::status_id), str(key::empty));
	const Atom effect_id = gd::to_string(state.get(status, str(key::effect_id), id_fallback));
	if (effect_id == key::empty) {
		return state.new_dict();
	}
	// build_battle_effect's arguments in their order, then the second duration.
	const Atom label = gd::to_string(state.get(status, str(key::label), str(gd::capitalize(state, effect_id))));
	const Value modifiers = get_or_new_dict(state, status, key::modifiers);
	const int64_t duration = gd::add(spell_effect_turns(state, hero_state, status, spell, key::debuff, power), engine_max<int64_t>(0, extra_turns));
	const Atom source_id = gd::string_field(state, spell, key::id, key::empty);
	const Value immunity_ids = get_or_new_array(state, status, key::status_immunity_ids);
	const DictRef built = build_battle_effect(state, effect_id, label, modifiers, duration, battle, key::spell, source_id, immunity_ids);
	set_effect_mechanic(state, built, status, power);
	return _counted_in_turns(state, built, duration);
}

int64_t _battle_spell_damage(State &state, DictRef hero_state, DictRef spell, DictRef target_stack) {
	return _battle_spell_damage_at(state, hero_state, spell, target_stack, spell_power(state, hero_state));
}

int64_t _battle_spell_damage_at(State &state, DictRef hero_state, DictRef spell, DictRef target_stack, int64_t power) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const int64_t base_damage = gd::int_field(state, effect, key::base_damage, 0);
	const int64_t power_scale = gd::int_field(state, effect, key::power_scale, 0);
	int64_t damage = engine_max<int64_t>(1, gd::add(base_damage, gd::mul(power, power_scale)));
	if (_wounded_bonus_applies(state, effect, target_stack)) {
		damage = gd::add(damage, engine_max<int64_t>(0, gd::int_field(state, effect, key::wounded_bonus_damage, 0)));
	}
	// Against the Rooted (Thornshot): a share more on a Rooted stack.
	const int64_t rooted_bonus_pct = gd::int_field(state, effect, key::rooted_bonus_pct, 0);
	if (rooted_bonus_pct > 0 && !gd::is_empty(state, target_stack) && !gd::is_empty(state, stack_status_effect(state, target_stack, state.new_dict(), key::status_rooted))) {
		damage = gd::add(damage, compat::int_div(gd::mul(damage, rooted_bonus_pct), 100));
	}
	const DictRef bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	const int64_t potency = gd::add(gd::int_field(state, bonuses, key::spell_damage_pct, 0), _school_bonus(state, bonuses, key::school_potency_pct, spell));
	return engine_max<int64_t>(1, gd::add(damage, compat::int_div(gd::mul(damage, potency), 100)));
}

bool _wounded_bonus_applies(State &state, DictRef effect, DictRef target_stack) {
	if (gd::is_empty(state, target_stack)) {
		return false;
	}
	if (gd::int_field(state, effect, key::wounded_bonus_damage, 0) <= 0) {
		return false;
	}
	const double threshold = engine_clamp(gd::float_field(state, effect, key::wounded_threshold_ratio, 0.5), 0.0, 1.0);
	return _health_ratio(state, target_stack) <= threshold;
}

int64_t _battle_spell_recovery_amount(State &state, DictRef hero_state, DictRef spell) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Value amount_fallback = state.get(effect, str(key::amount), int_value(0));
	const int64_t base_restore = gd::to_int(state, state.get(effect, str(key::base_restore), amount_fallback));
	const int64_t power = spell_power(state, hero_state);
	const int64_t power_scale = gd::int_field(state, effect, key::power_scale, 0);
	const int64_t amount = engine_max<int64_t>(1, gd::add(base_restore, gd::mul(power, power_scale)));
	const int64_t potency = _school_bonus(state, hero_progression_rules::aggregate_bonuses(state, hero_state), key::school_potency_pct, spell);
	return gd::add(amount, compat::int_div(gd::mul(amount, potency), 100));
}

int64_t _alive_count(State &state, DictRef stack) {
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
	const double health = static_cast<double>(engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0)));
	return compat::float_to_int(compat::godot_ceil(health / static_cast<double>(unit_hp)));
}

double _health_ratio(State &state, DictRef stack) {
	if (gd::is_empty(state, stack)) {
		return 0.0;
	}
	// Measured against the stack's starting size, as BattleRules._health_ratio.
	const int64_t count = engine_max<int64_t>(1, engine_max<int64_t>(gd::int_field(state, stack, key::base_count, 0), _alive_count(state, stack)));
	const int64_t max_health = engine_max<int64_t>(1, gd::mul(gd::int_field(state, stack, key::unit_hp, 1), count));
	const double health = static_cast<double>(gd::int_field(state, stack, key::total_health, 0));
	return engine_clamp(health / static_cast<double>(max_health), 0.0, 1.0);
}

ArrayRef learned_spells(State &state, DictRef hero_state, Atom context_filter) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const ArrayRef results = state.new_array();
	// for spell_id_value in hero.get("spellbook", {}).get("known_spell_ids", [])
	const DictRef spellbook = two_argument_get_target(get_or_new_dict(state, hero, key::spellbook));
	for (const Value &spell_id_value : gd::field_items(state, spellbook, str(key::known_spell_ids))) {
		const Atom spell_id = gd::stringify_or_fallback(state, spell_id_value);
		if (spell_id == key::empty) {
			continue;
		}
		const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
		if (gd::is_empty(state, spell)) {
			continue;
		}
		if (context_filter != key::empty && gd::string_field(state, spell, key::context, key::empty) != context_filter) {
			continue;
		}
		state.append(results, dict_value(spell));
	}
	return results;
}

ArrayRef known_spells(State &state, DictRef hero_state, Atom context_filter) {
	const ArrayRef results = learned_spells(state, hero_state, context_filter);
	// The spells worn scrolls lend follow the learned ones (docs/magic-system.md).
	for (const Value &spell_id_value : gd::items(state, array_value(worn_scroll_spell_ids(state, hero_state)))) {
		const Atom spell_id = gd::stringify(state, spell_id_value);
		if (_knows_spell(state, hero_state, spell_id)) {
			continue;
		}
		const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
		if (context_filter != key::empty && gd::string_field(state, spell, key::context, key::empty) != context_filter) {
			continue;
		}
		state.append(results, dict_value(spell));
	}
	return results;
}

DictRef resolve_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, Atom spell_id, Atom acting_side) {
	return resolve_battle_spell(state, hero_state, battle, active_stack, target_stack, spell_id, acting_side, Value());
}

DictRef resolve_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, Atom spell_id, Atom acting_side, const Value &destination) {
	DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	if (!can_cast_spell(state, hero, spell_id)) {
		return hero_refusal(state, hero, key::spell_not_in_spellbook_text);
	}
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
	if (gd::is_empty(state, spell)) {
		return hero_refusal(state, hero, key::spell_not_known_text);
	}
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell));

	const DictRef validation = validate_battle_spell(state, hero, battle, active_stack, target_stack, dict_value(spell), acting_side);
	if (!gd::bool_field(state, validation, key::ok, false)) {
		return hero_refusal(state, hero, gd::string_field(state, validation, key::message, key::spell_cannot_be_cast_now_text));
	}

	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Atom effect_type = gd::to_string(state.get(effect, str(key::type), str(key::empty)));
	const DictRef ally_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
	// A move finds its hex before the mana is spent: within its reach of the
	// stack's walk over empty hexes, or none named yet.
	int64_t move_reach = 0;
	DictRef move_cell = state.new_dict();
	bool needs_destination = false;
	if (effect_type == key::move_ally) {
		move_reach = spell_move_reach(state, spell, spell_power(state, hero));
		const ArrayRef cells = move_destinations(state, battle, ally_target, move_reach);
		if (state.array_size(cells) == 0) {
			return hero_refusal(state, hero, gd::format(state, key::no_open_hex_text, { str(battle_rules::_stack_label(state, ally_target)) }));
		}
		if (!gd::is_dict(destination) || gd::is_empty(state, destination.ref)) {
			needs_destination = true;
		} else {
			move_cell = move_destination_in_reach(state, cells, destination);
			if (gd::is_empty(state, move_cell)) {
				return hero_refusal(state, hero, key::destination_out_of_reach_text);
			}
		}
	}
	// A two-stack spell finds its second stack before the mana is spent, or
	// none is named yet.
	DictRef second_stack = state.new_dict();
	bool needs_second = false;
	if (takes_second_stack(state, spell)) {
		const DictRef first = effect_type == key::swap_enemy ? target_stack : ally_target;
		const Atom spell_name = gd::string_field(state, spell, key::name, spell_id);
		const ArrayRef options = second_stack_ids(state, hero, battle, first, spell, acting_side);
		if (state.array_size(options) == 0) {
			return hero_refusal(state, hero, gd::format(state, key::no_second_stack_text, { str(spell_name) }));
		}
		const DictRef picked = second_stack_pick(state, battle, destination);
		if (gd::is_empty(state, picked)) {
			needs_second = true;
		} else if (!gd::array_has(state, options, str(gd::string_field(state, picked, key::battle_id, key::empty)))) {
			return hero_refusal(state, hero, gd::format(state, key::second_stack_refused_text, { str(battle_rules::_stack_label(state, picked)), str(spell_name) }));
		} else {
			second_stack = picked;
		}
	}
	hero = _consume_mana(state, hero, mana_cost);
	const Atom caster_name = gd::string_field(state, hero, key::name, key::the_hero_text);
	// Prism Ward: a harmful spell cast on a warded stack lands on a random stack
	// of the caster's side instead; the ward is spent when the cast resolves.
	Atom reflected_from = key::empty;
	Atom reflect_text = key::empty;
	if (effect_type == key::damage_enemy || effect_type == key::control_enemy) {
		const DictRef bounce = reflected_spell_target(state, battle, target_stack, spell_id);
		if (!gd::is_empty(state, bounce)) {
			reflected_from = gd::string_field(state, target_stack, key::battle_id, key::empty);
			reflect_text = gd::format(state, key::prism_turns_spell_text, {
				str(battle_rules::_stack_label(state, target_stack)),
				str(gd::string_field(state, spell, key::name, spell_id)),
				str(battle_rules::_stack_label(state, bounce)),
			});
			target_stack = bounce;
		}
	}
	if (effect_type == key::damage_enemy) {
		const DictRef damage_projection = battle_spell_damage_projection(state, hero, battle, target_stack, spell);
		const DictRef post_damage_effect = _status_effect_from_spell_effect_at(state, spell, battle, hero, spell_power_against(state, hero, battle, target_stack));
		const DictRef status_resolution = battle_spell_status_resolution(state, battle, active_stack, target_stack, spell, post_damage_effect);
		DictRef resolved_post_damage_effect = post_damage_effect;
		if (gd::bool_field(state, status_resolution, key::blocked, false)) {
			resolved_post_damage_effect = state.new_dict();
		}
		Atom message = gd::format(state, key::casts_on_for_damage_format, {
			str(caster_name),
			str(gd::string_field(state, spell, key::name, spell_id)),
			str(gd::string_field(state, target_stack, key::name, key::the_enemy_text)),
			int_value(gd::int_field(state, damage_projection, key::final_damage, 0)),
		});
		if (gd::int_field(state, damage_projection, key::prevented_damage, 0) > 0) {
			const Atom resists = gd::format(state, key::resists_damage_suffix_format, {
				str(gd::string_field(state, target_stack, key::name, key::the_target_capital_text)),
				int_value(gd::int_field(state, damage_projection, key::prevented_damage, 0)),
			});
			message = state.intern(state.text(message) + state.text(resists));
		}
		message = _append_status_resolution_message(state, message, target_stack, post_damage_effect, status_resolution);
		const DictRef result = cast_result(state, hero, key::damage, gd::string_field(state, target_stack, key::battle_id, key::empty));
		state.set(result, str(key::damage), int_value(gd::int_field(state, damage_projection, key::final_damage, 0)));
		state.set(result, str(key::raw_damage), int_value(gd::int_field(state, damage_projection, key::raw_damage, 0)));
		state.set(result, str(key::final_damage), int_value(gd::int_field(state, damage_projection, key::final_damage, 0)));
		state.set(result, str(key::resistance_pct), int_value(gd::int_field(state, damage_projection, key::resistance_pct, 0)));
		state.set(result, str(key::prevented_damage), int_value(gd::int_field(state, damage_projection, key::prevented_damage, 0)));
		state.set(result, str(key::post_damage_effect), dict_value(resolved_post_damage_effect));
		state.set(result, str(key::post_damage_resisted), bool_value(gd::bool_field(state, status_resolution, key::resisted, false)));
		state.set(result, str(key::post_damage_immune), bool_value(gd::bool_field(state, status_resolution, key::immune, false)));
		state.set(result, str(key::blocked_status_id), str(gd::string_field(state, status_resolution, key::blocked_status_id, key::empty)));
		state.set(result, str(key::control_resistance_pct), int_value(gd::int_field(state, status_resolution, key::control_resistance_pct, 0)));
		state.set(result, str(key::resistance_roll), int_value(gd::int_field(state, status_resolution, key::resistance_roll, -1)));
		state.set(result, str(key::resistance_rng_state), str(gd::string_field(state, status_resolution, key::resistance_rng_state, key::empty)));
		// Heat (Ember Lash): the Heat it adds, and its burst at power less Knowledge.
		const int64_t heat = gd::int_field(state, effect, key::heat, 0);
		if (heat > 0) {
			state.set(result, str(key::heat), int_value(heat));
			state.set(result, str(key::heat_burst_damage), int_value(heat_burst_damage(spell_power_against(state, hero, battle, target_stack))));
		}
		message = with_reflection(state, result, reflected_from, reflect_text, message);
		state.set(result, str(key::message), str(message));
		add_reach_resolutions(state, hero, battle, target_stack, spell, result, destination);
		return result;
	}
	if (effect_type == key::control_enemy) {
		const DictRef control_effect = _status_effect_from_spell_effect_at(state, spell, battle, hero, spell_power_against(state, hero, battle, target_stack));
		const DictRef control_resolution = battle_spell_status_resolution(state, battle, active_stack, target_stack, spell, control_effect);
		DictRef resolved_control_effect = control_effect;
		if (gd::bool_field(state, control_resolution, key::blocked, false)) {
			resolved_control_effect = state.new_dict();
		}
		Atom control_message = gd::format(state, key::casts_on_format, {
			str(caster_name),
			str(gd::string_field(state, spell, key::name, spell_id)),
			str(gd::string_field(state, target_stack, key::name, key::the_enemy_text)),
		});
		control_message = _append_status_resolution_message(state, control_message, target_stack, control_effect, control_resolution);
		const DictRef result = cast_result(state, hero, key::effect, gd::string_field(state, target_stack, key::battle_id, key::empty));
		state.set(result, str(key::effect), dict_value(resolved_control_effect));
		// A follow-up status starts as the first one ends (Cooling Slag's slow after its root).
		Value follow_status;
		if (!gd::is_empty(state, resolved_control_effect) && state.lookup(effect, str(key::follow_status_effect), follow_status) && gd::is_dict(follow_status)) {
			const int64_t first_turns = gd::int_field(state, resolved_control_effect, key::turns_left, 1);
			state.set(result, str(key::follow_effect), dict_value(_status_payload(state, spell, follow_status, battle, hero, spell_power_against(state, hero, battle, target_stack), first_turns)));
		}
		state.set(result, str(key::resisted), bool_value(gd::bool_field(state, control_resolution, key::resisted, false)));
		state.set(result, str(key::immune), bool_value(gd::bool_field(state, control_resolution, key::immune, false)));
		state.set(result, str(key::blocked_status_id), str(gd::string_field(state, control_resolution, key::blocked_status_id, key::empty)));
		state.set(result, str(key::control_resistance_pct), int_value(gd::int_field(state, control_resolution, key::control_resistance_pct, 0)));
		state.set(result, str(key::resistance_roll), int_value(gd::int_field(state, control_resolution, key::resistance_roll, -1)));
		state.set(result, str(key::resistance_rng_state), str(gd::string_field(state, control_resolution, key::resistance_rng_state, key::empty)));
		control_message = with_reflection(state, result, reflected_from, reflect_text, control_message);
		state.set(result, str(key::message), str(control_message));
		add_reach_resolutions(state, hero, battle, target_stack, spell, result, destination);
		return result;
	}
	if (effect_type == key::recover_ally) {
		const DictRef result = cast_result(state, hero, key::recover_effect, gd::string_field(state, ally_target, key::battle_id, key::empty));
		state.set(result, str(key::recovery_amount), int_value(_battle_spell_recovery_amount(state, hero, spell)));
		const DictRef recover_payload = !gd::is_empty(state, battle_spell_modifiers(state, spell)) ? _effect_payload(state, spell, effect, battle, hero) : state.new_dict();
		state.set(result, str(key::effect), dict_value(recover_payload));
		// Hot Iron: no other healing reaches the stack for a while after this one.
		const int64_t block_turns = gd::int_field(state, effect, key::heal_block_turns, 0);
		if (block_turns > 0) {
			state.set(result, str(key::heal_block_effect), dict_value(heal_block_payload(state, spell, battle, block_turns)));
		}
		// Radiant Mend: the newest harmful statuses go too.
		const int64_t status_count = gd::int_field(state, effect, key::cleanse_statuses, 0);
		if (status_count > 0) {
			state.set(result, str(key::cleanse_status_ids), array_value(newest_status_ids(state, ally_target, battle, status_count)));
		}
		state.set(result, str(key::message), str(ally_cast_message(state, caster_name, spell, spell_id, ally_target)));
		add_reach_resolutions(state, hero, battle, ally_target, spell, result, destination);
		return result;
	}
	if (effect_type == key::cleanse_ally && cleanse_takes_any_harm(state, effect)) {
		// Cleanse: the newest harmful effects, one more per 3 spell power.
		const int64_t count = spell_effect_count(state, spell, spell_power(state, hero));
		const DictRef result = cast_result(state, hero, key::cleanse_effect, gd::string_field(state, ally_target, key::battle_id, key::empty));
		state.set(result, str(key::cleanse_effect_ids), array_value(newest_effect_ids(state, ally_target, battle, false, count)));
		state.set(result, str(key::effect), dict_value(state.new_dict()));
		state.set(result, str(key::message), str(ally_cast_message(state, caster_name, spell, spell_id, ally_target)));
		return result;
	}
	if (effect_type == key::cleanse_ally) {
		const DictRef result = cast_result(state, hero, key::cleanse_effect, gd::string_field(state, ally_target, key::battle_id, key::empty));
		state.set(result, str(key::cleanse_effect_ids), array_value(_normalize_string_array(state, get_or_new_array(state, effect, key::cleanse_effect_ids))));
		const bool with_payload = !gd::is_empty(state, battle_spell_modifiers(state, spell)) || state.array_size(normalize_status_immunity_ids(state, get_or_new_array(state, effect, key::status_immunity_ids))) > 0;
		const DictRef cleanse_payload = with_payload ? _effect_payload(state, spell, effect, battle, hero) : state.new_dict();
		state.set(result, str(key::effect), dict_value(cleanse_payload));
		state.set(result, str(key::message), str(ally_cast_message(state, caster_name, spell, spell_id, ally_target)));
		return result;
	}
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff || effect_type == key::ally_effect) {
		const DictRef result = cast_result(state, hero, key::effect, gd::string_field(state, ally_target, key::battle_id, key::empty));
		state.set(result, str(key::effect), dict_value(_effect_payload_for(state, spell, effect, battle, hero, ally_target)));
		state.set(result, str(key::message), str(ally_cast_message(state, caster_name, spell, spell_id, ally_target)));
		add_reach_resolutions(state, hero, battle, ally_target, spell, result, destination);
		return result;
	}
	if (effect_type == key::dispel_enemy) {
		// Unweave: the newest helpful spell effects, one more per 3 of the
		// caster's power less the target hero's Knowledge.
		const int64_t count = spell_effect_count(state, spell, spell_power_against(state, hero, battle, target_stack));
		const DictRef result = cast_result(state, hero, key::dispel_effect, gd::string_field(state, target_stack, key::battle_id, key::empty));
		state.set(result, str(key::cleanse_effect_ids), array_value(newest_effect_ids(state, target_stack, battle, true, count)));
		const Atom dispel_message = gd::format(state, key::casts_on_format, {
			str(caster_name),
			str(gd::string_field(state, spell, key::name, spell_id)),
			str(gd::string_field(state, target_stack, key::name, key::the_enemy_text)),
		});
		state.set(result, str(key::message), str(dispel_message));
		return result;
	}
	if (effect_type == key::move_ally) {
		const DictRef result = cast_result(state, hero, key::move_effect, gd::string_field(state, ally_target, key::battle_id, key::empty));
		state.set(result, str(key::range), int_value(move_reach));
		if (needs_destination) {
			state.set(result, str(key::needs_destination), bool_value(true));
			state.set(result, str(key::message), str(gd::format(state, key::choose_destination_hex_text, { str(battle_rules::_stack_label(state, ally_target)) })));
		} else {
			state.set(result, str(key::destination), dict_value(move_cell));
			state.set(result, str(key::message), str(ally_cast_message(state, caster_name, spell, spell_id, ally_target)));
		}
		return result;
	}
	if (takes_second_stack(state, spell)) {
		const DictRef first = effect_type == key::swap_enemy ? target_stack : ally_target;
		const Atom first_id = gd::string_field(state, first, key::battle_id, key::empty);
		const Atom resolution_type = effect_type == key::graft_allies ? static_cast<Atom>(key::effect)
				: (effect_type == key::transfer_ally ? static_cast<Atom>(key::transfer_effect) : static_cast<Atom>(key::swap_effect));
		const DictRef result = cast_result(state, hero, resolution_type, first_id);
		if (needs_second) {
			state.set(result, str(key::needs_second_target), bool_value(true));
			state.set(result, str(key::message), str(gd::format(state, key::choose_second_stack_text, { str(gd::string_field(state, spell, key::name, spell_id)) })));
			return result;
		}
		const Atom second_id = gd::string_field(state, second_stack, key::battle_id, key::empty);
		state.set(result, str(key::source_battle_id), str(second_id));
		if (effect_type == key::graft_allies) {
			// Each end of the graft names the other.
			const auto graft_payload = [&](DictRef stack, Atom partner_id) {
				const DictRef payload = _effect_payload_for(state, spell, effect, battle, hero, stack);
				const DictRef mechanic = state.new_dict();
				state.set(mechanic, str(key::graft_partner), str(partner_id));
				state.set(payload, str(key::mechanic), dict_value(mechanic));
				return payload;
			};
			state.set(result, str(key::effect), dict_value(graft_payload(first, second_id)));
			const DictRef joined = state.new_dict();
			state.set(joined, str(key::resolution_type), str(key::effect));
			state.set(joined, str(key::target_battle_id), str(second_id));
			state.set(joined, str(key::effect), dict_value(graft_payload(second_stack, first_id)));
			state.set(joined, str(key::message), str(gd::format(state, key::graft_joins_text, { str(battle_rules::_stack_label(state, second_stack)) })));
			const ArrayRef extra = state.new_array();
			state.append(extra, dict_value(joined));
			state.set(result, str(key::extra_resolutions), array_value(extra));
		} else if (effect_type == key::transfer_ally) {
			state.set(result, str(key::transfer_amount), int_value(transfer_amount(state, hero, spell, first, second_stack)));
		}
		const Atom cast_message = effect_type == key::swap_enemy
				? gd::format(state, key::casts_on_format, { str(caster_name), str(gd::string_field(state, spell, key::name, spell_id)), str(gd::string_field(state, first, key::name, key::the_enemy_text)) })
				: ally_cast_message(state, caster_name, spell, spell_id, first);
		state.set(result, str(key::message), str(cast_message));
		return result;
	}
	return hero_refusal(state, hero, key::battle_spell_no_supported_effect_text);
}

DictRef validate_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, const Value &spell, Atom acting_side) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const DictRef spell_dict = gd::is_dict(spell) ? spell.ref : gd::content_row(state, state::ContentTable::Spell, gd::stringify_or_fallback(state, spell));
	const DictRef cast_check = battle_spell_cast_check(state, hero, spell_dict, active_stack, acting_side);
	if (!gd::bool_field(state, cast_check, key::ok, false)) {
		return cast_check;
	}
	return battle_spell_target_check(state, battle, active_stack, target_stack, spell_dict, acting_side);
}

DictRef _consume_mana(State &state, DictRef hero_state, int64_t cost) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const Value spellbook = get_or_new_dict(state, hero, key::spellbook);
	const Value mana = get_or_new_dict(state, two_argument_get_target(spellbook), key::mana);
	const int64_t current = engine_max<int64_t>(0, gd::sub(gd::int_field(state, two_argument_get_target(mana), key::current, 0), engine_max<int64_t>(0, cost)));
	state.set(mana.ref, str(key::current), int_value(current));
	state.set(spellbook.ref, str(key::mana), mana);
	state.set(hero, str(key::spellbook), spellbook);
	return hero;
}

} // namespace aurelion::rules::port::spell_rules
