// SpellRules for the human seat's overworld spells (Phase 7, slice 7.4): the
// spell actions, validation and casting, the target contract, the preview and
// the texts the actions show.

#include "aurelion_rules/port/overworld_rules_spells.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}): the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(effect.get("type", "")) of an untyped effect.
Atom effect_type_of(State &state, const Value &effect) {
	return string_of(state, ai::vget(state, effect, key::type, str(key::empty)));
}

// int(effect.get("amount", effect.get("radius", 0))).
int64_t amount_or_radius(State &state, const Value &effect) {
	const Value radius = ai::vget(state, effect, key::radius, int_value(0));
	return gd::to_int(state, ai::vget(state, effect, key::amount, radius));
}

// hero.get("spellbook", {}).get("mana", {}).get(field, fallback).
Value mana_field(State &state, DictRef hero, Atom field, const Value &fallback) {
	Value spellbook;
	if (!state.lookup(hero, str(key::spellbook), spellbook)) {
		return fallback;
	}
	if (!gd::is_dict(spellbook)) {
		return ai::vget(state, spellbook, key::mana); // GDScript's error on get() of no Dictionary
	}
	Value mana;
	if (!state.lookup(spellbook.ref, str(key::mana), mana)) {
		return fallback;
	}
	return ai::vget(state, mana, field, fallback);
}

// ensure_hero_spellbook(hero_state.duplicate(true)).
DictRef spellbook_copy(State &state, DictRef hero_state) {
	return spell_rules::ensure_hero_spellbook(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)), state.new_dict());
}

// var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell)).
DictRef spell_dict_of(State &state, const Value &spell) {
	return gd::is_dict(spell) ? spell.ref : gd::content_row(state, ContentTable::Spell, string_of(state, spell));
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// separator.join(pieces) of Strings.
Atom join(State &state, Atom separator, const std::vector<Atom> &pieces) {
	std::string text;
	for (size_t at = 0; at < pieces.size(); ++at) {
		if (at > 0) {
			text += state.text(separator);
		}
		text += state.text(pieces[at]);
	}
	return state.intern(text);
}

// s.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &whole = state.text(text);
	return state.intern(std::string_view(whole).substr(0, whole.size() - state.text(suffix).size()));
}

// timing.trim_prefix("Best ").trim_suffix(".") if timing != "" else fallback.
Atom timing_or(State &state, Atom timing, Atom fallback) {
	if (timing == key::empty) {
		return fallback;
	}
	return trim_suffix(state, gd::trim_prefix(state, timing, key::best_2), key::period);
}

// An Array literal of Strings.
ArrayRef strings(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"ok": true}.
DictRef approval(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	return result;
}

// {"ok": false, "hero": hero, "movement": movement, "message": message}.
DictRef cast_refusal(State &state, DictRef hero, DictRef movement, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::movement), dict_value(movement));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

namespace spell_rules {

bool cast_overworld_spell_on_day(State &state, DictRef hero, int64_t day) {
	return day > 0 && gd::int_field(state, hero, key::overworld_spell_cast_day, 0) == day;
}

Atom spell_category_label(State &state, DictRef spell) {
	const Atom context = text_or(state, spell, key::context, key::empty);
	const Atom effect_type = effect_type_of(state, field_or_new_dict(state, spell, key::effect));
	if (context == key::overworld) {
		if (effect_type == key::restore_movement) {
			return key::field_route;
		}
		if (effect_type == key::reveal_radius) {
			return key::field_survey;
		}
		return key::field_utility;
	}
	if (context == key::battle) {
		if (effect_type == key::damage_enemy) {
			return key::battle_strike;
		}
		if (effect_type == key::defense_buff) {
			return key::battle_ward;
		}
		if (effect_type == key::initiative_buff) {
			return key::battle_tempo;
		}
		if (effect_type == key::attack_buff) {
			return key::battle_assault;
		}
		return key::battle_utility;
	}
	return key::unsorted_magic;
}

DictRef adventure_spell_target_contract(State &state, DictRef hero_state, DictRef movement_state, const Value &spell) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef spell_dict = spell_dict_of(state, spell);
	if (gd::is_empty(state, spell_dict)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::spell_id), str(string_of(state, spell)));
		state.set(result, str(key::spell_name), str(key::unknown_spell));
		state.set(result, str(key::target_kind), str(key::none));
		state.set(result, str(key::target_requirement), str(key::known_overworld_spell));
		state.set(result, str(key::selectable), bool_value(false));
		state.set(result, str(key::blocked_reason), str(key::spell_not_known_text));
		state.set(result, str(key::public_text), str(key::spell_not_known_text));
		return result;
	}
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell_dict));
	const DictRef validation = validate_overworld_spell(state, hero, movement_state, dict_value(spell_dict));
	const Atom target_requirement = _overworld_target_requirement(state, spell_dict);
	const Atom public_text = gd::format(state, key::s_targets_the_active_hero_s, {
			str(text_or(state, spell_dict, key::name, key::spell_word)),
			str(target_requirement),
	});
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(gd::bool_field(state, validation, key::ok, false)));
	state.set(result, str(key::spell_id), str(text_or(state, spell_dict, key::id, key::empty)));
	state.set(result, str(key::spell_name), str(text_or(state, spell_dict, key::name, key::spell_word)));
	state.set(result, str(key::target_kind), str(text_or(state, spell_dict, key::target_mode, key::self) == key::self ? static_cast<Atom>(key::self_hero) : static_cast<Atom>(key::unsupported)));
	state.set(result, str(key::target_mode), str(text_or(state, spell_dict, key::target_mode, key::empty)));
	state.set(result, str(key::target_requirement), str(target_requirement));
	state.set(result, str(key::selectable), bool_value(gd::bool_field(state, validation, key::ok, false)));
	state.set(result, str(key::blocked_reason), str(gd::bool_field(state, validation, key::ok, false) ? static_cast<Atom>(key::empty) : text_or(state, validation, key::message, key::cannot_cast_now)));
	state.set(result, str(key::mana_cost), int_value(mana_cost));
	state.set(result, str(key::movement_current), int_value(gd::int_field(state, movement_state, key::current, 0)));
	state.set(result, str(key::movement_max), int_value(gd::int_field(state, movement_state, key::max, 0)));
	state.set(result, str(key::public_text), str(public_text));
	return result;
}

DictRef adventure_spell_consequence_preview(State &state, DictRef hero_state, DictRef movement_state, const Value &spell) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef spell_dict = spell_dict_of(state, spell);
	if (gd::is_empty(state, spell_dict)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::spell_id), str(string_of(state, spell)));
		state.set(result, str(key::spell_name), str(key::unknown_spell));
		state.set(result, str(key::public_text), str(key::that_spell_has_no_supported_adventure));
		return result;
	}
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell_dict));
	const Value effect = field_or_new_dict(state, spell_dict, key::effect);
	const Atom effect_type = gd::is_dict(effect) ? effect_type_of(state, effect) : static_cast<Atom>(key::empty);
	const DictRef preview = _movement_restore_preview(state, movement_state, spell_dict, hero);
	const bool supported = text_or(state, spell_dict, key::context, key::empty) == key::overworld
			&& (effect_type == key::restore_movement || effect_type == key::reveal_radius);
	Atom public_text = key::empty;
	if (supported && effect_type == key::restore_movement) {
		public_text = gd::format(state, key::s_restores_d_movement_now_capped, {
				str(text_or(state, spell_dict, key::name, key::spell_word)),
				int_value(gd::int_field(state, preview, key::restored, 0)),
				int_value(gd::int_field(state, preview, key::movement_max, 0)),
				int_value(mana_cost),
		});
	} else if (supported && effect_type == key::reveal_radius) {
		public_text = gd::format(state, key::s_reveals_a_scouting_ring_of, {
				str(text_or(state, spell_dict, key::name, key::spell_word)),
				int_value(compat::engine_max<int64_t>(1, amount_or_radius(state, effect))),
				int_value(mana_cost),
		});
	} else {
		public_text = key::that_spell_has_no_supported_adventure;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(supported));
	state.set(result, str(key::spell_id), str(text_or(state, spell_dict, key::id, key::empty)));
	state.set(result, str(key::spell_name), str(text_or(state, spell_dict, key::name, key::spell_word)));
	state.set(result, str(key::effect_type), str(effect_type));
	state.set(result, str(key::movement_before), int_value(gd::int_field(state, preview, key::movement_before, gd::int_field(state, movement_state, key::current, 0))));
	state.set(result, str(key::movement_after), int_value(gd::int_field(state, preview, key::movement_after, gd::int_field(state, movement_state, key::current, 0))));
	state.set(result, str(key::movement_restored), int_value(gd::int_field(state, preview, key::restored, 0)));
	state.set(result, str(key::movement_max), int_value(gd::int_field(state, preview, key::movement_max, gd::int_field(state, movement_state, key::max, 0))));
	state.set(result, str(key::reveal_radius), int_value(effect_type == key::reveal_radius ? compat::engine_max<int64_t>(0, amount_or_radius(state, effect)) : 0));
	state.set(result, str(key::mana_cost), int_value(mana_cost));
	state.set(result, str(key::public_text), str(public_text));
	state.set(result, str(key::changes_fog), bool_value(effect_type == key::reveal_radius));
	state.set(result, str(key::changes_site_state), bool_value(false));
	state.set(result, str(key::changes_resources), bool_value(false));
	return result;
}

Atom _best_use_line(State &state, DictRef spell, DictRef context, DictRef active_stack, DictRef target_stack) {
	const Value effect = field_or_new_dict(state, spell, key::effect);
	const Atom effect_type = effect_type_of(state, effect);
	if (effect_type == key::restore_movement) {
		if (!gd::is_empty(state, context)) {
			const int64_t current = gd::int_field(state, context, key::current, 0);
			const int64_t max_movement = gd::int_field(state, context, key::max, 0);
			if (current >= max_movement) {
				return key::save_until_movement_has_room;
			}
		}
		return key::recover_route_tempo_after_spending_movement;
	}
	if (effect_type == key::reveal_radius) {
		return key::open_nearby_fog_before_committing_movement;
	}
	if (effect_type == key::damage_enemy) {
		const Atom damage_timing = battle_spell_timing_summary(state, state.new_dict(), context, active_stack, target_stack, spell);
		return timing_or(state, damage_timing, key::soften_the_selected_enemy_before_a);
	}
	if (effect_type == key::control_enemy) {
		return key::pin_the_selected_enemy_before_it;
	}
	if (effect_type == key::recover_ally) {
		return key::stabilize_a_wounded_active_stack_before;
	}
	if (effect_type == key::cleanse_ally) {
		return key::clear_harry_or_stagger_pressure_before;
	}
	if (effect_type == key::defense_buff) {
		const Atom defense_timing = battle_spell_timing_summary(state, state.new_dict(), context, active_stack, target_stack, spell);
		return timing_or(state, defense_timing, key::hold_the_stack_that_must_absorb);
	}
	if (effect_type == key::initiative_buff) {
		const Atom initiative_timing = battle_spell_timing_summary(state, state.new_dict(), context, active_stack, target_stack, spell);
		return timing_or(state, initiative_timing, key::win_a_contested_activation_window);
	}
	if (effect_type == key::attack_buff) {
		const Atom attack_timing = battle_spell_timing_summary(state, state.new_dict(), context, active_stack, target_stack, spell);
		return timing_or(state, attack_timing, key::cast_before_an_immediate_damage_order);
	}
	const Atom description = gd::strip_edges(state, text_or(state, spell, key::description, key::empty));
	return description != key::empty ? description : static_cast<Atom>(key::use_when_the_current_board_state);
}

ArrayRef get_overworld_actions(State &state, DictRef hero_state, DictRef movement_state, int64_t today) {
	const ArrayRef actions = state.new_array();
	const DictRef hero = spellbook_copy(state, hero_state);
	const ArrayRef spells = known_spells(state, hero, key::overworld);
	for (const Value &spell_value : gd::items(state, array_value(spells))) {
		const DictRef spell = gd::as_dict(spell_value);
		const DictRef validation = validate_overworld_spell(state, hero, movement_state, spell_value, today);
		const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, spell_value);
		const Atom summary = _overworld_spell_action_summary(state, hero, movement_state, spell, validation, mana_cost);
		const Atom category = spell_category_label(state, spell);
		const Atom effect_summary = _overworld_spell_effect_summary(state, spell, movement_state, hero);
		const DictRef target_contract = adventure_spell_target_contract(state, hero, movement_state, spell_value);
		const DictRef consequence_preview = adventure_spell_consequence_preview(state, hero, movement_state, spell_value);
		const bool ok = gd::bool_field(state, validation, key::ok, false);
		const Atom readiness = ok ? static_cast<Atom>(key::Ready) : gd::format(state, key::blocked_s, {str(text_or(state, validation, key::message, key::cannot_cast_now))});
		const int64_t mana_current = gd::to_int(state, mana_field(state, hero, key::current, int_value(0)));
		const int64_t mana_shortfall = compat::engine_max<int64_t>(0, gd::sub(mana_cost, mana_current));
		const Atom why_cast = _best_use_line(state, spell, movement_state, state.new_dict(), state.new_dict());

		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::cast_spell_s, {str(text_or(state, spell, key::id, key::empty))})));
		state.set(action, str(key::label), str(gd::format(state, key::cast_s_d_mana, {str(text_or(state, spell, key::name, key::spell_word)), int_value(mana_cost)})));
		state.set(action, str(key::spell_name), str(text_or(state, spell, key::name, key::spell_word)));
		state.set(action, str(key::disabled), bool_value(!gd::bool_field(state, validation, key::ok, false)));
		state.set(action, str(key::summary), str(summary));
		state.set(action, str(key::cost), int_value(mana_cost));
		state.set(action, str(key::category), str(category));
		state.set(action, str(key::effect), str(effect_summary));
		state.set(action, str(key::readiness), str(readiness));
		state.set(action, str(key::best_use), str(why_cast));
		state.set(action, str(key::target), str(_target_mode_label(state, text_or(state, spell, key::target_mode, key::self))));
		state.set(action, str(key::target_requirement), str(_overworld_target_requirement(state, spell)));
		state.set(action, str(key::target_contract), dict_value(target_contract));
		state.set(action, str(key::mana_state), str(gd::format(state, key::mana_d_d_need_d, {
				int_value(mana_current),
				int_value(gd::to_int(state, mana_field(state, hero, key::max, int_value(mana_current)))),
				int_value(mana_cost),
		})));
		state.set(action, str(key::mana_ready), bool_value(mana_shortfall <= 0));
		state.set(action, str(key::mana_shortfall), int_value(mana_shortfall));
		state.set(action, str(key::consequence), str(effect_summary));
		state.set(action, str(key::consequence_preview), dict_value(consequence_preview));
		state.set(action, str(key::why_cast), str(why_cast));
		state.set(action, str(key::availability), str(gd::bool_field(state, validation, key::ok, false) ? static_cast<Atom>(key::ready) : static_cast<Atom>(key::blocked)));
		state.set(action, str(key::invalid_reason), str(!gd::bool_field(state, validation, key::ok, false) ? text_or(state, validation, key::message, key::empty) : static_cast<Atom>(key::empty)));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef cast_overworld_spell(State &state, DictRef hero_state, DictRef movement_state, Atom spell_id, int64_t today) {
	DictRef hero = spellbook_copy(state, hero_state);
	const DictRef movement = gd::as_dict(gd::engine_duplicate(state, dict_value(movement_state), true));
	if (!_knows_spell(state, hero, spell_id)) {
		return cast_refusal(state, hero, movement, key::spell_not_in_spellbook_text);
	}
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	if (gd::is_empty(state, spell)) {
		return cast_refusal(state, hero, movement, key::spell_not_known_text);
	}
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell));

	const DictRef validation = validate_overworld_spell(state, hero, movement, dict_value(spell), today);
	if (!gd::bool_field(state, validation, key::ok, false)) {
		return cast_refusal(state, hero, movement, text_or(state, validation, key::message, key::spell_cannot_be_cast_now_text));
	}
	if (today > 0) {
		state.set(hero, str(key::overworld_spell_cast_day), int_value(today));
	}

	const Value effect = field_or_new_dict(state, spell, key::effect);
	const Atom effect_type = effect_type_of(state, effect);
	if (effect_type == key::restore_movement) {
		const DictRef preview = adventure_spell_consequence_preview(state, hero, movement, dict_value(spell));
		const DictRef target_contract = adventure_spell_target_contract(state, hero, movement, dict_value(spell));
		const int64_t current = gd::to_int(state, state.get(preview, str(key::movement_before), state.get(movement, str(key::current), int_value(0))));
		const int64_t restored = gd::int_field(state, preview, key::movement_restored, 0);
		state.set(movement, str(key::current), int_value(gd::to_int(state, state.get(preview, str(key::movement_after), state.get(movement, str(key::current), int_value(0))))));
		hero = _consume_mana(state, hero, mana_cost);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::movement), dict_value(movement));
		state.set(result, str(key::spell_id), str(spell_id));
		state.set(result, str(key::spell_name), str(text_or(state, spell, key::name, spell_id)));
		state.set(result, str(key::target_contract), dict_value(target_contract));
		state.set(result, str(key::consequence_preview), dict_value(preview));
		state.set(result, str(key::message), str(gd::format(state, key::s_restores_d_movement_d_d, {
				str(text_or(state, spell, key::name, spell_id)),
				int_value(restored),
				int_value(current),
				int_value(gd::int_field(state, movement, key::current, 0)),
				int_value(mana_cost),
		})));
		return result;
	}
	if (effect_type == key::reveal_radius) {
		const DictRef preview = adventure_spell_consequence_preview(state, hero, movement, dict_value(spell));
		const DictRef target_contract = adventure_spell_target_contract(state, hero, movement, dict_value(spell));
		hero = _consume_mana(state, hero, mana_cost);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::movement), dict_value(movement));
		state.set(result, str(key::spell_id), str(spell_id));
		state.set(result, str(key::spell_name), str(text_or(state, spell, key::name, spell_id)));
		state.set(result, str(key::fog_reveal_radius), int_value(gd::int_field(state, preview, key::reveal_radius, 0)));
		state.set(result, str(key::target_contract), dict_value(target_contract));
		state.set(result, str(key::consequence_preview), dict_value(preview));
		state.set(result, str(key::message), str(gd::format(state, key::s_reveals_a_scouting_ring_of_2, {
				str(text_or(state, spell, key::name, spell_id)),
				int_value(gd::int_field(state, preview, key::reveal_radius, 0)),
				int_value(mana_cost),
		})));
		return result;
	}
	return cast_refusal(state, hero, movement, key::that_overworld_spell_has_no_supported);
}

DictRef validate_overworld_spell(State &state, DictRef hero_state, DictRef movement_state, const Value &spell, int64_t today) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef spell_dict = spell_dict_of(state, spell);
	if (gd::is_empty(state, spell_dict)) {
		return refusal(state, key::spell_not_known_text);
	}
	if (text_or(state, spell_dict, key::context, key::empty) != key::overworld) {
		return refusal(state, key::that_spell_cannot_be_used_on);
	}
	if (cast_overworld_spell_on_day(state, hero, today)) {
		return refusal(state, gd::format(state, key::s_has_already_cast_an_overworld, {str(text_or(state, hero, key::name, key::this_hero))}));
	}
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell_dict));
	if (!_has_mana(state, hero, mana_cost)) {
		const int64_t current_mana = gd::to_int(state, mana_field(state, hero, key::current, int_value(0)));
		return refusal(state, gd::format(state, key::need_d_mana_only_d_available, {int_value(mana_cost), int_value(current_mana)}));
	}

	const Value effect = field_or_new_dict(state, spell_dict, key::effect);
	const Atom effect_type = effect_type_of(state, effect);
	if (effect_type == key::restore_movement) {
		if (text_or(state, spell_dict, key::target_mode, key::self) != key::self) {
			return refusal(state, key::that_field_spell_target_is_not);
		}
		if (gd::int_field(state, movement_state, key::current, 0) >= gd::int_field(state, movement_state, key::max, 0)) {
			return refusal(state, key::movement_is_already_full);
		}
		return approval(state);
	}
	if (effect_type == key::reveal_radius) {
		if (text_or(state, spell_dict, key::target_mode, key::self) != key::self) {
			return refusal(state, key::that_field_spell_target_is_not);
		}
		if (compat::engine_max<int64_t>(0, amount_or_radius(state, effect)) <= 0) {
			return refusal(state, key::that_scouting_spell_has_no_reveal);
		}
		return approval(state);
	}
	return refusal(state, key::that_overworld_spell_effect_is_unsupported);
}

Atom effect_summary(State &state, DictRef stack, DictRef battle) {
	std::vector<Atom> tags;
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef effects = active_effects_for_round(state, stack, current_round);
	for (const Value &effect : gd::items(state, array_value(effects))) {
		const Value kind = ai::vget(state, effect, key::kind, str(key::Effect));
		Atom label = string_of(state, ai::vget(state, effect, key::label, kind));
		const Atom rules = status_rules_text(state, string_of(state, ai::vget(state, effect, key::effect_id, str(key::empty))));
		if (rules != key::empty) {
			label = concat(state, label, gd::format(state, key::s_3, {str(rules)}));
		}
		if (ai::vhas(state, effect, str(key::turns_left))) {
			const int64_t turns = gd::to_int(state, ai::vget(state, effect, key::turns_left, int_value(1)));
			tags.push_back(gd::format(state, key::s_d_turn_s, {
					str(label),
					int_value(turns),
					str(turns == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s)),
			}));
		} else {
			const int64_t expires = gd::to_int(state, ai::vget(state, effect, key::expires_after_round, int_value(current_round)));
			const int64_t rounds_left = gd::add(gd::sub(expires, current_round), 1);
			tags.push_back(gd::format(state, key::s_dr, {str(label), int_value(compat::engine_max<int64_t>(1, rounds_left))}));
		}
	}
	return join(state, key::comma_space, tags);
}

Atom battle_spell_timing_summary(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	(void)hero_state;
	if (gd::is_empty(state, spell) || gd::is_empty(state, active_stack)) {
		return key::empty;
	}
	const Value effect = field_or_new_dict(state, spell, key::effect);
	const Atom effect_type = effect_type_of(state, effect);
	if (effect_type == key::damage_enemy) {
		const Value status_effect = ai::vget(state, effect, key::status_effect, dict_value(state.new_dict()));
		const Value status_id = ai::vget(state, status_effect, key::status_id, str(key::empty));
		const Atom effect_id = string_of(state, ai::vget(state, status_effect, key::effect_id, status_id));
		if (effect_id == key::status_harried) {
			if (_side_has_any_ability(state, battle, text_or(state, active_stack, key::side, key::empty), strings(state, {key::backstab, key::bloodrush, key::shielding}))) {
				return key::best_before_your_finisher_stacks_close;
			}
			if (gd::int_field(state, battle, key::distance, 1) > 0) {
				return key::best_while_the_firing_lane_stays;
			}
		} else if (effect_id == key::status_staggered) {
			if (_side_has_any_ability(state, battle, text_or(state, active_stack, key::side, key::empty), strings(state, {key::formation_guard, key::reach, key::brace}))) {
				return key::best_on_a_fast_anchor_before;
			}
			return key::best_on_the_next_high_initiative;
		}
		if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, battle, key::distance, 1) > 0) {
			return key::best_while_range_still_buys_a;
		}
		return key::best_when_the_selected_target_must;
	}
	if (effect_type == key::control_enemy) {
		if (!gd::is_empty(state, target_stack) && _health_ratio(state, target_stack) > 0.5) {
			return key::best_before_a_healthy_threat_converts;
		}
		return key::best_to_pin_the_selected_enemy;
	}
	if (effect_type == key::recover_ally) {
		if (_health_ratio(state, active_stack) <= 0.65) {
			return key::best_when_the_acting_stack_is;
		}
		return key::best_when_the_stack_must_hold;
	}
	if (effect_type == key::cleanse_ally) {
		const Value cleanse_ids = ai::vget(state, effect, key::cleanse_effect_ids, array_value(state.new_array()));
		if (has_any_effect_ids(state, active_stack, battle, array_value(_normalize_string_array(state, cleanse_ids)))) {
			return key::best_before_the_cleansed_stack_spends;
		}
		return key::best_when_harry_or_stagger_pressure;
	}
	if (effect_type == key::defense_buff) {
		if (has_any_effect_ids(state, active_stack, battle, array_value(strings(state, {key::status_harried, key::status_staggered})))) {
			return key::best_when_the_acting_stack_is_2;
		}
		if (_health_ratio(state, active_stack) <= 0.65) {
			return key::best_when_the_acting_stack_is_3;
		}
		if (gd::int_field(state, battle, key::distance, 1) <= 0) {
			return key::best_once_contact_is_live_and;
		}
		return key::best_on_turns_where_this_stack;
	}
	if (effect_type == key::initiative_buff) {
		if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, active_stack, key::shots_remaining, 0) > 0) {
			return key::best_before_the_next_volley_or;
		}
		if (!gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, battle, key::distance, 1) > 0) {
			return key::best_before_the_close_so_this;
		}
		return key::best_before_a_contested_activation_window;
	}
	if (effect_type == key::attack_buff) {
		if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, active_stack, key::shots_remaining, 0) > 0) {
			return key::best_before_spending_the_next_volley;
		}
		if (!gd::is_empty(state, target_stack) && _health_ratio(state, target_stack) <= 0.75) {
			return key::best_while_the_selected_target_is;
		}
		if (gd::int_field(state, battle, key::distance, 1) <= 0) {
			return key::best_once_contact_is_open_and;
		}
		return key::best_immediately_before_a_damage_trade;
	}
	return key::empty;
}

Atom _overworld_spell_action_summary(State &state, DictRef hero_state, DictRef movement_state, DictRef spell, DictRef validation, int64_t mana_cost) {
	const Atom target_label = _target_mode_label(state, text_or(state, spell, key::target_mode, key::self));
	const Atom availability = gd::bool_field(state, validation, key::ok, false)
			? static_cast<Atom>(key::ready_now_2)
			: gd::format(state, key::blocked_s, {str(text_or(state, validation, key::message, key::cannot_cast_now))});
	const Atom description = gd::strip_edges(state, text_or(state, spell, key::description, key::empty));
	const Atom consequence = _overworld_spell_effect_summary(state, spell, movement_state, hero_state);
	const Atom why_cast = _best_use_line(state, spell, movement_state, state.new_dict(), state.new_dict());
	std::vector<Atom> pieces;
	pieces.push_back(gd::format(state, key::s_consequence_s, {str(spell_category_label(state, spell)), str(consequence)}));
	pieces.push_back(gd::format(state, key::cost_d_mana_target_s_s, {int_value(mana_cost), str(target_label), str(_overworld_target_requirement(state, spell))}));
	pieces.push_back(availability);
	pieces.push_back(gd::format(state, key::why_cast_s, {str(why_cast)}));
	if (description != key::empty) {
		pieces.push_back(description);
	}
	return join(state, key::space, pieces);
}

DictRef _movement_restore_preview(State &state, DictRef movement_state, DictRef spell, DictRef hero_state) {
	const Value effect = field_or_new_dict(state, spell, key::effect);
	if (!gd::is_dict(effect) || effect_type_of(state, effect) != key::restore_movement) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::movement_before), int_value(gd::int_field(state, movement_state, key::current, 0)));
		state.set(result, str(key::movement_after), int_value(gd::int_field(state, movement_state, key::current, 0)));
		state.set(result, str(key::movement_max), int_value(gd::int_field(state, movement_state, key::max, 0)));
		state.set(result, str(key::restored), int_value(0));
		return result;
	}
	const int64_t amount = compat::engine_max<int64_t>(1, gd::add(gd::int_field(state, effect.ref, key::amount, 0), artifact_rules::spell_effect_amount_delta(state, hero_state, spell)));
	const int64_t current = gd::int_field(state, movement_state, key::current, 0);
	const int64_t max_movement = gd::int_field(state, movement_state, key::max, 0);
	const int64_t restored = compat::engine_min<int64_t>(amount, compat::engine_max<int64_t>(0, gd::sub(max_movement, current)));
	const DictRef result = state.new_dict();
	state.set(result, str(key::movement_before), int_value(current));
	state.set(result, str(key::movement_after), int_value(compat::engine_min<int64_t>(max_movement, gd::add(current, restored))));
	state.set(result, str(key::movement_max), int_value(max_movement));
	state.set(result, str(key::restored), int_value(restored));
	return result;
}

Atom _overworld_spell_effect_summary(State &state, DictRef spell, DictRef movement_state, DictRef hero_state) {
	const Value effect = field_or_new_dict(state, spell, key::effect);
	const Atom effect_type = effect_type_of(state, effect);
	if (effect_type == key::restore_movement) {
		const DictRef preview = _movement_restore_preview(state, movement_state, spell, hero_state);
		const int64_t amount = compat::engine_max<int64_t>(1, gd::add(gd::int_field(state, effect.ref, key::amount, 0), artifact_rules::spell_effect_amount_delta(state, hero_state, spell)));
		if (gd::int_field(state, preview, key::restored, 0) > 0) {
			return gd::format(state, key::restores_up_to_d_movement_d, {int_value(amount), int_value(gd::int_field(state, preview, key::restored, 0))});
		}
		return gd::format(state, key::restores_up_to_d_movement, {int_value(amount)});
	}
	if (effect_type == key::reveal_radius) {
		return gd::format(state, key::reveals_unexplored_tiles_in_radius_d, {int_value(compat::engine_max<int64_t>(1, amount_or_radius(state, effect)))});
	}
	return key::no_supported_overworld_effect;
}

Atom _overworld_target_requirement(State &state, DictRef spell) {
	if (text_or(state, spell, key::target_mode, key::self) == key::self) {
		return key::no_map_target_affects_active_hero;
	}
	return gd::format(state, key::choose_s_before_casting, {str(_target_mode_label(state, text_or(state, spell, key::target_mode, key::empty)))});
}

Atom _target_mode_label(State &state, Atom target_mode) {
	if (target_mode == key::self) {
		return key::active_hero_2;
	}
	if (target_mode == key::ally_active) {
		return key::active_allied_stack;
	}
	if (target_mode == key::enemy_selected) {
		return key::selected_enemy_text;
	}
	return gd::replace(state, target_mode, key::_, key::space);
}

DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id) {
	if (ability_id == key::empty) {
		return state.new_dict();
	}
	for (const Value &ability : gd::field_items(state, stack, str(key::abilities))) {
		if (gd::is_dict(ability) && text_or(state, ability.ref, key::id, key::empty) == ability_id) {
			return ability.ref;
		}
	}
	return state.new_dict();
}

bool _has_ability(State &state, DictRef stack, Atom ability_id) {
	return !gd::is_empty(state, _ability_by_id(state, stack, ability_id));
}

ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side) {
	const ArrayRef stacks = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		if (text_or(state, stack.ref, key::side, key::empty) != side) {
			continue;
		}
		if (_alive_count(state, stack.ref) <= 0) {
			continue;
		}
		state.append(stacks, stack);
	}
	return stacks;
}

bool _side_has_any_ability(State &state, DictRef battle, Atom side, ArrayRef ability_ids) {
	const ArrayRef stacks = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		for (const Value &ability_id_value : gd::items(state, array_value(ability_ids))) {
			if (_has_ability(state, gd::as_dict(stack), string_of(state, ability_id_value))) {
				return true;
			}
		}
	}
	return false;
}

} // namespace spell_rules

} // namespace aurelion::rules::port
