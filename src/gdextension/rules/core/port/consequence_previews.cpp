// Slice 10b: the battle screen's consequence previews: an attack's forecast (its damage range, kills, strike-back and
// walk, as the badge's lines), an advance's and a spell's, and the damage and loss ranges they print.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>
#include <unordered_set>

namespace aurelion::rules::port::battle_rules {

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

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// session.battle: SessionData.battle is a typed Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// {"ok": false, "message": message}
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"text": text, "detail": detail, "tone": tone}: one line of a forecast badge.
DictRef forecast_line(State &state, Atom text, Atom detail, Atom tone) {
	const DictRef line = state.new_dict();
	state.set(line, str(key::text), str(text));
	state.set(line, str(key::detail), str(detail));
	state.set(line, str(key::tone), str(tone));
	return line;
}

// var x: Dictionary = d.get(field, {}): the field, which must be a Dictionary,
// or a new empty one when it is missing.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// d.clear(): every key erased, in order.
void clear_dict(State &state, DictRef dict) {
	const ArrayRef keys = gd::keys(state, dict);
	const int64_t size = state.array_size(keys);
	for (int64_t index = 0; index < size; ++index) {
		state.erase(dict, state.at(keys, index));
	}
}

// _consequence_cache: the previews of the battle in _consequence_cache_battle,
// by action, target and approach.
DictRef consequence_cache(State &state) {
	return gd::as_dict(gd::static_var(state, key::battle_rules_script, key::_consequence_cache));
}

// int(value.get(field, fallback)) of an untyped value: GDScript stops on a
// base without get().
int64_t untyped_int_get(const State &state, const Value &base, Atom field, int64_t fallback) {
	if (!gd::is_dict(base)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return gd::int_field(state, base.ref, field, fallback);
}

} // namespace

DictRef attack_consequence_preview(State &state, DictRef battle, Atom action, Atom target_id, DictRef approach) {
	// The memo holds the previews of one battle as it stood: any change to it
	// empties the memo.
	const Value cached_battle = gd::static_var(state, key::battle_rules_script, key::_consequence_cache_battle);
	if (!gd::equal(state, cached_battle, dict_value(battle))) {
		gd::set_static_var(state, key::battle_rules_script, key::_consequence_cache_battle, dict_value(gd::deep_duplicate_dict(state, battle)));
		clear_dict(state, consequence_cache(state));
	}
	const Atom approach_key = !gd::is_empty(state, approach) ? _hex_key(state, approach) : static_cast<Atom>(key::empty);
	const Atom cache_key = gd::format(state, key::consequence_cache_key_text, { str(action), str(target_id), str(approach_key) });
	{
		const DictRef cache = consequence_cache(state);
		if (state.has(cache, str(cache_key))) {
			return gd::as_dict(gd::duplicate_value(state, gd::index(state, cache, str(cache_key)), true));
		}
	}
	const DictRef attacker = get_active_stack(state, battle);
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	const DictRef rejected = state.new_dict();
	state.set(rejected, str(key::ok), bool_value(false));
	state.set(rejected, str(key::action), str(action));
	state.set(rejected, str(key::target_id), str(target_id));
	state.set(rejected, str(key::message), str(key::no_legal_attack_text));
	if ((action != key::strike && action != key::shoot) || gd::is_empty(state, attacker) || gd::is_empty(state, target)) {
		return rejected;
	}
	if (_alive_count(state, target) <= 0 || string_or_empty(state, attacker, key::side) == string_or_empty(state, target, key::side)) {
		return rejected;
	}
	const bool ranged = action == key::shoot;
	if (ranged && !_can_make_ranged_attack(state, attacker, battle, target)) {
		return rejected;
	}
	// var strike_from := {}: a shot keeps it empty.
	DictRef strike_from = state.new_dict();
	if (!ranged) {
		if (!gd::is_empty(state, approach)) {
			strike_from = _matching_melee_approach(state, battle, attacker, target, approach);
			if (gd::is_empty(state, strike_from)) {
				const Atom message = gd::format(state, key::cannot_strike_from_text, { str(_stack_label(state, attacker)), str(_stack_label(state, target)), str(_hex_label(state, approach)) });
				state.set(rejected, str(key::message), str(message));
				return rejected;
			}
		} else if (_can_make_melee_attack(state, attacker, battle, target)) {
			strike_from = _melee_approach_entry(state, attacker, target, _stack_hex(state, attacker), 0);
		} else {
			const DictRef nearest = melee_approach_destination(state, battle, attacker, target);
			if (gd::is_empty(state, nearest)) {
				return rejected;
			}
			strike_from = _matching_melee_approach(state, battle, attacker, target, nearest);
			if (gd::is_empty(state, strike_from)) {
				strike_from = _melee_approach_entry(state, attacker, target, nearest, gd::int_field(state, nearest, key::steps, 0));
			}
		}
	}
	const int64_t steps = gd::int_field(state, strike_from, key::steps, 0);
	const DictRef prepared = gd::deep_duplicate_dict(state, battle);
	state.erase(prepared, str(key::_live_action_playback_capture));
	const Atom actor_id = string_or_empty(state, attacker, key::battle_id);
	const ArrayRef path = state.new_array();
	if (steps > 0) {
		const ArrayRef walk = _presentation_walk_path(state, prepared, _stack_hex(state, attacker), strike_from);
		const int64_t walk_size = state.array_size(walk);
		for (int64_t index = 0; index < walk_size; ++index) {
			const Value cell = state.at(walk, index);
			const DictRef step = state.new_dict();
			state.set(step, str(key::q), int_value(untyped_int_get(state, cell, key::q, -1)));
			state.set(step, str(key::r), int_value(untyped_int_get(state, cell, key::r, -1)));
			state.append(path, dict_value(step));
		}
		_apply_melee_approach(state, prepared, _get_stack_by_id(state, prepared, actor_id), strike_from);
	}
	const DictRef moved = _get_stack_by_id(state, prepared, actor_id);
	const DictRef defender = _get_stack_by_id(state, prepared, target_id);
	const int64_t distance = _attack_distance_for_action(state, moved, defender, prepared, ranged);
	const DictRef outgoing = _damage_range_preview(state, moved, defender, prepared, ranged, false, distance);
	// incoming's four fields, as ints until its literal is built below (with
	// the same keys in the same order).
	int64_t incoming_min_damage = 2147483647;
	int64_t incoming_max_damage = 0;
	int64_t incoming_min_units = 2147483647;
	int64_t incoming_max_units = 0;
	bool any_retaliation = false;
	bool every_retaliation = true;
	bool every_kill = true;
	int64_t shots_after = gd::int_field(state, moved, key::shots_remaining, 0);
	const int64_t min_roll = gd::int_field(state, moved, key::min_damage, 1);
	const int64_t max_roll = engine_max(min_roll, gd::int_field(state, moved, key::max_damage, 1));
	// Every roll starts from the same prepared state, so the damage modifier is
	// resolved once (as in _damage_for_roll) and rolls that land on the same
	// damage share one trial. Each distinct damage is still simulated in full.
	const int64_t attacker_count = engine_max<int64_t>(1, _alive_count(state, moved));
	const double damage_modifier = _damage_modifier(state, moved, defender, prepared, ranged, false, distance);
	std::unordered_set<int64_t> simulated_damage;
	const int64_t roll_end = gd::add(max_roll, 1);
	for (int64_t roll = min_roll; roll < roll_end; ++roll) {
		const int64_t damage = engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(static_cast<double>(gd::mul(attacker_count, roll)) * damage_modifier)));
		if (!simulated_damage.insert(damage).second) {
			continue;
		}
		const DictRef trial = gd::deep_duplicate_dict(state, prepared);
		DictRef a = _get_stack_by_id(state, trial, actor_id);
		DictRef d = _get_stack_by_id(state, trial, target_id);
		const DictRef before = gd::deep_duplicate_dict(state, d);
		_apply_damage_to_stack(state, trial, target_id, damage);
		if (ranged) {
			_consume_shot(state, trial, actor_id);
		}
		_apply_attack_ability_effects(state, trial, a, d, ranged, distance, before);
		_apply_damage_pressure(state, trial, a, before, d, ranged, key::attack);
		_apply_ranged_damage_return(state, trial, actor_id, before, ranged, key::attack);
		a = _get_stack_by_id(state, trial, actor_id);
		d = _get_stack_by_id(state, trial, target_id);
		if (ranged) {
			shots_after = gd::int_field(state, a, key::shots_remaining, 0);
		}
		every_kill = every_kill && _alive_count(state, d) <= 0;
		const bool eligible = !ranged
				&& _alive_count(state, d) > 0
				&& gd::int_field(state, d, key::retaliations_left, 0) > 0
				&& _can_make_retaliation(state, d, distance, trial);
		any_retaliation = any_retaliation || eligible;
		every_retaliation = every_retaliation && eligible;
		const int64_t reflection = engine_max<int64_t>(0, gd::sub(gd::int_field(state, moved, key::total_health, 0), gd::int_field(state, a, key::total_health, 0)));
		// reply is {} without a strike-back: its fields read 0.
		int64_t reply_min_damage = 0;
		int64_t reply_max_damage = 0;
		if (eligible) {
			const DictRef reply = _damage_range_preview(state, d, a, trial, false, true, distance);
			reply_min_damage = gd::int_field(state, reply, key::min_damage, 0);
			reply_max_damage = gd::int_field(state, reply, key::max_damage, 0);
		}
		const int64_t low = gd::add(reflection, reply_min_damage);
		const int64_t high = gd::add(reflection, reply_max_damage);
		const DictRef losses = _unit_loss_range(state, moved, low, high);
		incoming_min_damage = engine_min(incoming_min_damage, low);
		incoming_max_damage = engine_max(incoming_max_damage, high);
		incoming_min_units = engine_min(incoming_min_units, gd::to_int(state, gd::index(state, losses, str(key::min_units))));
		incoming_max_units = engine_max(incoming_max_units, gd::to_int(state, gd::index(state, losses, str(key::max_units))));
	}
	Atom no_reply_reason = key::empty;
	if (!any_retaliation) {
		no_reply_reason = _no_retaliation_reason(state, defender, prepared, ranged, distance, every_kill);
	}
	const DictRef final_hex = gd::deep_duplicate_dict(state, _stack_hex(state, moved));
	const DictRef incoming = state.new_dict();
	state.set(incoming, str(key::min_damage), int_value(incoming_min_damage));
	state.set(incoming, str(key::max_damage), int_value(incoming_max_damage));
	state.set(incoming, str(key::min_units), int_value(incoming_min_units));
	state.set(incoming, str(key::max_units), int_value(incoming_max_units));
	// The literal's entries in its order.
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::ok), bool_value(true));
	state.set(preview, str(key::action), str(action));
	state.set(preview, str(key::actor_id), str(actor_id));
	state.set(preview, str(key::target_id), str(target_id));
	state.set(preview, str(key::destination), dict_value(final_hex));
	state.set(preview, str(key::moved), bool_value(steps > 0));
	state.set(preview, str(key::damage), dict_value(outgoing));
	state.set(preview, str(key::incoming), dict_value(incoming));
	state.set(preview, str(key::retaliation_possible), bool_value(any_retaliation));
	state.set(preview, str(key::retaliation_certain), bool_value(every_retaliation));
	state.set(preview, str(key::no_retaliation_reason), str(no_reply_reason));
	state.set(preview, str(key::approach), dict_value(gd::deep_duplicate_dict(state, strike_from)));
	state.set(preview, str(key::steps), int_value(steps));
	state.set(preview, str(key::path), array_value(path));
	state.set(preview, str(key::strike_part), str(string_or_empty(state, strike_from, key::strike_part)));
	state.set(preview, str(key::shots_before), int_value(ranged ? gd::int_field(state, moved, key::shots_remaining, 0) : 0));
	state.set(preview, str(key::shots_after), int_value(ranged ? shots_after : 0));
	state.set(preview, str(key::penalised), bool_value(ranged && _stack_is_engaged(state, moved, prepared)));
	state.set(preview, str(key::forecast_lines), array_value(_attack_forecast_lines(state, preview, target)));
	{
		const Atom verb = ranged ? key::Shoot : key::Strike;
		const Atom target_label = _stack_label(state, target);
		const Atom lines_text = forecast_text(state, gd::as_array(gd::index(state, preview, str(key::forecast_lines))));
		state.set(preview, str(key::message), str(gd::format(state, key::attack_forecast_message_text, { str(verb), str(target_label), str(lines_text) })));
	}
	const DictRef cache = consequence_cache(state);
	if (state.dict_size(cache) >= 32) {
		clear_dict(state, cache);
	}
	state.set(cache, str(cache_key), dict_value(gd::deep_duplicate_dict(state, preview)));
	return preview;
}

Atom _no_retaliation_reason(State &state, DictRef defender, DictRef battle, bool ranged, int64_t distance, bool always_destroyed) {
	if (ranged) {
		return key::a_shot_text;
	}
	if (always_destroyed) {
		return key::it_is_destroyed_text;
	}
	if (gd::int_field(state, defender, key::retaliations_left, 0) <= 0) {
		return key::struck_back_this_round_text;
	}
	if (spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
		return key::staggered_label;
	}
	if (distance > 0) {
		return key::out_of_its_reach_text;
	}
	return key::cannot_strike_back_text;
}

ArrayRef _attack_forecast_lines(State &state, DictRef preview, DictRef target) {
	const DictRef damage = dict_field_or_new(state, preview, key::damage);
	const DictRef incoming = dict_field_or_new(state, preview, key::incoming);
	const bool ranged = string_or_empty(state, preview, key::action) == key::shoot;
	const int64_t count = _alive_count(state, target);
	const int64_t min_kills = gd::int_field(state, damage, key::min_units, 0);
	const int64_t max_kills = gd::int_field(state, damage, key::max_units, 0);
	Atom kills = key::destroys_the_stack_text;
	if (min_kills < count) {
		const Atom kill_range = _range_text(state, min_kills, max_kills);
		const Atom may_destroy = max_kills >= count ? key::may_destroy_suffix_text : key::empty;
		kills = gd::format(state, key::kills_range_text, { str(kill_range), str(may_destroy) });
	}
	const ArrayRef lines = state.new_array();
	{
		const Atom damage_range = _range_text(state, gd::int_field(state, damage, key::min_damage, 0), gd::int_field(state, damage, key::max_damage, 0));
		const Atom detail = gd::format(state, key::s_damage_text, { str(damage_range) });
		state.append(lines, dict_value(forecast_line(state, kills, detail, key::empty)));
	}
	const Atom shots = gd::format(state, key::shots_arrow_text, { int_value(gd::int_field(state, preview, key::shots_before, 0)), int_value(gd::int_field(state, preview, key::shots_after, 0)) });
	if (gd::int_field(state, incoming, key::max_damage, 0) > 0) {
		const bool certain = gd::bool_field(state, preview, key::retaliation_certain, false);
		const Atom reply = ranged ? key::damage_return_text : key::strikes_back_text;
		const Atom unit_range = _range_text(state, gd::int_field(state, incoming, key::min_units, 0), gd::int_field(state, incoming, key::max_units, 0));
		const Atom text = gd::format(state, key::lose_units_text, { str(reply), str(unit_range) });
		const Atom damage_range = _range_text(state, gd::int_field(state, incoming, key::min_damage, 0), gd::int_field(state, incoming, key::max_damage, 0));
		const Atom caveat = (certain || ranged) ? key::empty : key::if_any_survive_text;
		const Atom detail = gd::format(state, key::incoming_damage_detail_text, { str(damage_range), str(caveat) });
		state.append(lines, dict_value(forecast_line(state, text, detail, key::red)));
		if (ranged) {
			state.append(lines, dict_value(forecast_line(state, gd::format(state, key::shots_s_text, { str(shots) }), key::empty, key::muted)));
		}
	} else if (ranged) {
		state.append(lines, dict_value(forecast_line(state, gd::format(state, key::no_retaliation_shots_text, { str(shots) }), key::empty, key::green)));
	} else {
		const Atom reason = gd::string_field(state, preview, key::no_retaliation_reason, key::cannot_strike_back_text);
		state.append(lines, dict_value(forecast_line(state, key::no_retaliation_text, gd::format(state, key::parenthesized_text, { str(reason) }), key::green)));
	}
	if (ranged) {
		if (gd::bool_field(state, preview, key::penalised, false)) {
			state.append(lines, dict_value(forecast_line(state, key::point_blank_penalty_text, key::empty, key::amber)));
		}
	} else {
		const int64_t steps = gd::int_field(state, preview, key::steps, 0);
		Atom walk = key::strikes_from_where_it_stands_text;
		if (steps > 0) {
			const Atom plural = steps == 1 ? key::empty : key::es;
			walk = gd::format(state, key::moves_hexes_first_text, { int_value(steps), str(plural) });
		}
		if (string_or_empty(state, preview, key::strike_part) == key::tail) {
			walk = concat(state, walk, key::tail_strikes_suffix_text);
		}
		state.append(lines, dict_value(forecast_line(state, walk, key::empty, key::muted)));
	}
	return lines;
}

Atom forecast_text(State &state, ArrayRef lines) {
	// ". ".join(parts) of the PackedStringArray of the non-empty sentences.
	std::string joined;
	bool first = true;
	const int64_t size = state.array_size(lines);
	for (int64_t index = 0; index < size; ++index) {
		const Value line = state.at(lines, index);
		if (!gd::is_dict(line)) {
			continue;
		}
		Atom text = gd::strip_edges(state, string_or_empty(state, line.ref, key::text));
		const Atom detail = gd::strip_edges(state, string_or_empty(state, line.ref, key::detail));
		if (detail != key::empty) {
			const bool bracketed = gd::begins_with(state, detail, key::open_paren_text) || gd::begins_with(state, detail, key::middle_dot_text);
			const Atom separator = bracketed ? key::space : key::comma_space;
			text = gd::format(state, key::s_s_s_text, { str(text), str(separator), str(detail) });
		}
		if (text != key::empty) {
			if (!first) {
				joined += state.text(key::period_space_text);
			}
			joined += state.text(text);
			first = false;
		}
	}
	return state.intern(joined);
}

Atom _range_text(State &state, int64_t low, int64_t high) {
	if (low == high) {
		return gd::stringify(state, int_value(low));
	}
	return gd::format(state, key::range_low_high_text, { int_value(low), int_value(high) });
}

Atom consequence_range_text(State &state, DictRef value) {
	return gd::format(state, key::damage_lost_range_text, {
			int_value(gd::int_field(state, value, key::min_damage, 0)),
			int_value(gd::int_field(state, value, key::max_damage, 0)),
			int_value(gd::int_field(state, value, key::min_units, 0)),
			int_value(gd::int_field(state, value, key::max_units, 0)),
	});
}

DictRef advance_consequence_preview(State &state, DictRef battle) {
	if (!gd::bool_field(state, action_availability(state, battle), key::advance, false)) {
		return refusal(state, key::no_advance_available_text);
	}
	const DictRef copy = gd::deep_duplicate_dict(state, battle);
	state.erase(copy, str(key::_live_action_playback_capture));
	const DictRef actor = get_active_stack(state, copy);
	_apply_auto_advance_movement(state, copy, actor);
	const DictRef destination = gd::deep_duplicate_dict(state, _stack_hex(state, actor));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::action), str(key::move_));
	state.set(result, str(key::destination), dict_value(destination));
	state.set(result, str(key::message), str(gd::format(state, key::advance_preview_message_text, { str(_hex_label(state, destination)) })));
	return result;
}

DictRef spell_consequence_preview(State &state, const Value &session, Atom spell_id, Atom target_id) {
	if (session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session))) {
		return refusal(state, key::no_battle_is_active_text);
	}
	const DictRef battle = session_battle(state, session);
	if (_commander_spell_cast_this_round(state, battle, key::player)) {
		return refusal(state, key::commander_already_cast_short_text);
	}
	const DictRef active = get_active_stack(state, battle);
	const DictRef hero = _player_commander_state(state, session);
	const DictRef resolution = _player_spell_resolution(state, session, spell_id, target_id);
	if (!gd::bool_field(state, resolution, key::ok, false)) {
		return resolution;
	}
	const DictRef target = _get_stack_by_id(state, battle, string_or_empty(state, resolution, key::target_battle_id));
	const int64_t damage = gd::int_field(state, resolution, key::damage, 0);
	const DictRef losses = _unit_loss_range(state, target, damage, damage);
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
	const int64_t cost = spell_rules::adjusted_spell_mana_cost(state, hero, dict_value(spell));
	// The legacy summary calls allied recipients the active stack; pass the
	// resolved recipient so an explicitly selected ally keeps its own identity.
	Atom effect = spell_rules::_battle_spell_effect_summary(state, hero, spell, battle, target, target);
	const Atom spell_name = gd::string_field(state, spell, key::name, spell_id);
	// The badge: the spell and its cost, what it does to the target, then that
	// the stack keeps its turn (lines as in _attack_forecast_lines).
	const ArrayRef lines = state.new_array();
	state.append(lines, dict_value(forecast_line(state, spell_name, gd::format(state, key::d_mana_text, { int_value(cost) }), key::empty)));
	if (string_or_empty(state, resolution, key::resolution_type) == key::damage) {
		// int(losses.min_units): _unit_loss_range's int.
		const int64_t kills = gd::to_int(state, gd::index(state, losses, str(key::min_units)));
		effect = gd::format(state, key::spell_damage_effect_text, { int_value(damage), int_value(kills) });
		const Atom destroyed = kills >= _alive_count(state, target) ? key::destroyed_suffix_text : key::empty;
		const Atom text = gd::format(state, key::spell_damage_kills_text, { int_value(damage), int_value(kills), str(destroyed) });
		state.append(lines, dict_value(forecast_line(state, text, key::empty, key::red)));
		state.append(lines, dict_value(forecast_line(state, gd::format(state, key::no_retaliation_keeps_turn_text, { str(_stack_label(state, active)) }), key::empty, key::muted)));
	} else {
		// The left operand is converted first, as GDScript evaluates it.
		const Atom target_side = string_or_empty(state, target, key::side);
		const bool hostile = target_side != string_or_empty(state, active, key::side);
		const Atom text = gd::format(state, key::s_colon_s_text, { str(_stack_label(state, target)), str(effect) });
		state.append(lines, dict_value(forecast_line(state, text, key::empty, hostile ? key::amber : key::green)));
		state.append(lines, dict_value(forecast_line(state, gd::format(state, key::keeps_its_turn_text, { str(_stack_label(state, active)) }), key::empty, key::muted)));
	}
	// The literal's entries in its order.
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::action), str(concat(state, key::cast_spell_prefix_text, spell_id)));
	state.set(result, str(key::target_id), str(string_or_empty(state, target, key::battle_id)));
	state.set(result, str(key::destination), dict_value(gd::deep_duplicate_dict(state, _stack_hex(state, active))));
	state.set(result, str(key::mana_cost), int_value(cost));
	state.set(result, str(key::damage), int_value(damage));
	state.set(result, str(key::casualties), int_value(gd::to_int(state, gd::index(state, losses, str(key::min_units)))));
	state.set(result, str(key::forecast_lines), array_value(lines));
	{
		const Atom target_label = _stack_label(state, target);
		const Atom active_label = _stack_label(state, active);
		const Atom message = gd::format(state, key::spell_preview_message_text, { str(spell_name), str(target_label), int_value(cost), str(active_label), str(effect) });
		state.set(result, str(key::message), str(message));
	}
	return result;
}

DictRef _damage_range_preview(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	if (gd::is_empty(state, attacker) || gd::is_empty(state, defender)) {
		return state.new_dict();
	}
	const int64_t attacker_count = _alive_count(state, attacker);
	if (attacker_count <= 0) {
		return state.new_dict();
	}
	const int64_t min_roll = gd::int_field(state, attacker, key::min_damage, 1);
	// Untyped max() of two ints: an int.
	const int64_t max_roll = engine_max(min_roll, gd::int_field(state, attacker, key::max_damage, 1));
	const double modifier = _damage_modifier(state, attacker, defender, battle, is_ranged, is_retaliation, attack_distance);
	const int64_t min_damage = engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(static_cast<double>(gd::mul(attacker_count, min_roll)) * modifier)));
	const int64_t max_damage = engine_max(min_damage, compat::float_to_int(compat::godot_round(static_cast<double>(gd::mul(attacker_count, max_roll)) * modifier)));
	const DictRef losses = _unit_loss_range(state, defender, min_damage, max_damage);
	const DictRef result = state.new_dict();
	state.set(result, str(key::min_damage), int_value(min_damage));
	state.set(result, str(key::max_damage), int_value(max_damage));
	state.set(result, str(key::min_units), int_value(gd::int_field(state, losses, key::min_units, 0)));
	state.set(result, str(key::max_units), int_value(gd::int_field(state, losses, key::max_units, 0)));
	return result;
}

DictRef _unit_loss_range(State &state, DictRef defender, int64_t min_damage, int64_t max_damage) {
	if (gd::is_empty(state, defender)) {
		const DictRef none = state.new_dict();
		state.set(none, str(key::min_units), int_value(0));
		state.set(none, str(key::max_units), int_value(0));
		return none;
	}
	const int64_t total_health = engine_max<int64_t>(0, gd::int_field(state, defender, key::total_health, 0));
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, defender, key::unit_hp, 1));
	const int64_t before = _alive_count(state, defender);
	const int64_t shield = engine_max<int64_t>(0, gd::int_field(state, defender, key::town_shield_hp, 0));
	min_damage = engine_max<int64_t>(0, gd::sub(min_damage, shield));
	max_damage = engine_max<int64_t>(0, gd::sub(max_damage, shield));
	const int64_t after_min = compat::float_to_int(compat::godot_ceil(static_cast<double>(engine_max<int64_t>(0, gd::sub(total_health, min_damage))) / static_cast<double>(unit_hp)));
	const int64_t after_max = compat::float_to_int(compat::godot_ceil(static_cast<double>(engine_max<int64_t>(0, gd::sub(total_health, max_damage))) / static_cast<double>(unit_hp)));
	const DictRef result = state.new_dict();
	state.set(result, str(key::min_units), int_value(engine_max<int64_t>(0, gd::sub(before, after_min))));
	state.set(result, str(key::max_units), int_value(engine_max<int64_t>(0, gd::sub(before, after_max))));
	return result;
}

} // namespace aurelion::rules::port::battle_rules
