// Layer 8: the battle spells. A spell's battle behavior, the cast and target checks, spell and control resistance,
// the damage, recovery and duration of a cast, the effect payloads and the status resistance roll.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::spell_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
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
constexpr int64_t MAX_POWER_EXTRA_ROUNDS = 3;
constexpr int64_t TURN_EFFECT_ROUND_SENTINEL = 1000000;

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
	} else if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff) {
		resolution_type = key::effect;
		state.append(hooks, str(key::ally_status_effect));
		public_effect = key::ally_modifier_effect_text;
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
		const ArrayRef cleanse_effect_ids = _normalize_string_array(state, get_or_new_array(state, two_argument_get_target(effect), key::cleanse_effect_ids));
		if (state.array_size(cleanse_effect_ids) == 0) {
			return refusal(state, key::cleanse_spell_no_target_text);
		}
		if (!has_any_effect_ids(state, cleanse_target, battle, array_value(cleanse_effect_ids)) && gd::is_empty(state, battle_spell_modifiers(state, spell_dict))) {
			return refusal(state, key::no_matching_pressure_text);
		}
		return accepted(state);
	}
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff) {
		const DictRef buff_target = _battle_spell_ally_target(state, active_stack, target_stack, acting_side);
		if (gd::is_empty(state, buff_target) || side_of(state, buff_target) != acting_side) {
			return refusal(state, key::select_allied_target_text);
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
	const int64_t raw_damage = _battle_spell_damage(state, hero_state, spell, target_stack);
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
	return engine_min<int64_t>(MAX_POWER_EXTRA_ROUNDS, compat::int_div(spell_power(state, hero_state), POWER_PER_EXTRA_ROUND));
}

int64_t spell_duration_rounds(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind) {
	int64_t rounds = engine_max<int64_t>(1, gd::to_int(state, base_rounds));
	rounds = gd::add(rounds, spell_duration_bonus(state, hero_state));
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
	} else {
		return state.new_dict();
	}
	return _spell_effect_modifiers(state, effect.ref, kind, gd::int_field(state, effect.ref, key::amount, 0));
}

DictRef _effect_payload(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state) {
	const DictRef modifiers = battle_spell_modifiers(state, spell);
	// build_battle_effect's arguments in their order, then the second duration.
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const Atom effect_id = gd::format(state, key::spell_effect_id_format, { str(spell_id), str(gd::string_field(state, effect, key::type, key::empty)) });
	const Atom label = gd::string_field(state, spell, key::name, key::spell_word);
	const int64_t duration = spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff);
	const Atom source_id = gd::string_field(state, spell, key::id, key::empty);
	const Value immunity_ids = get_or_new_array(state, effect, key::status_immunity_ids);
	const DictRef built = build_battle_effect(state, effect_id, label, dict_value(modifiers), duration, battle, key::spell, source_id, immunity_ids);
	return _counted_in_turns(state, built, spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff));
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
	const DictRef fallback = state.new_dict();
	state.set(fallback, str(default_kind), int_value(engine_max<int64_t>(1, default_amount)));
	return _normalize_effect_modifiers(state, dict_value(fallback));
}

DictRef _status_effect_from_spell_effect(State &state, DictRef spell, DictRef battle, DictRef hero_state) {
	const Value effect = get_or_new_dict(state, spell, key::effect);
	const Value status_effect = get_or_new_dict(state, two_argument_get_target(effect), key::status_effect);
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
	const int64_t duration = spell_duration_rounds(state, hero_state, gd::field_or(state, status, key::duration_rounds, int_value(1)), spell, key::debuff);
	const Atom source_id = gd::string_field(state, spell, key::id, key::empty);
	const Value immunity_ids = get_or_new_array(state, status, key::status_immunity_ids);
	const DictRef built = build_battle_effect(state, effect_id, label, modifiers, duration, battle, key::spell, source_id, immunity_ids);
	return _counted_in_turns(state, built, spell_duration_rounds(state, hero_state, gd::field_or(state, status, key::duration_rounds, int_value(1)), spell, key::debuff));
}

int64_t _battle_spell_damage(State &state, DictRef hero_state, DictRef spell, DictRef target_stack) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const int64_t base_damage = gd::int_field(state, effect, key::base_damage, 0);
	const int64_t power = spell_power(state, hero_state);
	const int64_t power_scale = gd::int_field(state, effect, key::power_scale, 0);
	int64_t damage = engine_max<int64_t>(1, gd::add(base_damage, gd::mul(power, power_scale)));
	if (_wounded_bonus_applies(state, effect, target_stack)) {
		damage = gd::add(damage, engine_max<int64_t>(0, gd::int_field(state, effect, key::wounded_bonus_damage, 0)));
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

} // namespace aurelion::rules::port::spell_rules
