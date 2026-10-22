// Slice 10b: the text a battle spell's effect prints on the battle screen: the effect summary, a status's terms and
// rules, the turns it lasts, the cleansed statuses and the signed modifiers.

#include "aurelion_rules/port/spell_rules.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::spell_rules {

using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

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

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// ", ".join(parts) of a local Array of Strings.
Atom join_with_comma(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(key::comma_space);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// ", ".join(labels) of an Array: String.join takes it as a PackedStringArray, String(item) of every item.
Atom join_array_with_comma(State &state, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(key::comma_space);
		}
		const Atom part = gd::stringify(state, state.at(parts, index));
		joined += state.text(part);
	}
	return state.intern(joined);
}

// The modifiers _modifier_summary names first, in its order.
constexpr Atom kOrderedModifierKeys[] = { key::attack, key::defense, key::initiative, key::speed, key::cohesion, key::momentum };

bool is_ordered_modifier_key(Atom field) {
	for (const Atom ordered : kOrderedModifierKeys) {
		if (ordered == field) {
			return true;
		}
	}
	return false;
}

// "%s %s" % [_signed_modifier_label(int(modifiers[field])), field]
Atom modifier_part(State &state, DictRef modifiers, Atom field) {
	const Atom label = _signed_modifier_label(state, gd::to_int(state, gd::index(state, modifiers, str(field))));
	return gd::format(state, key::s_s, { str(label), str(field) });
}

} // namespace

Atom _battle_spell_effect_summary(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef active_stack, DictRef target_stack) {
	(void)battle;
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Atom effect_type = gd::to_string(state.get(effect, str(key::type), str(key::empty)));
	if (effect_type == key::damage_enemy) {
		const int64_t damage = _battle_spell_damage(state, hero_state, spell, target_stack);
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		Atom summary = gd::format(state, key::damage_to_text, { int_value(damage), str(target_label) });
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		if (!gd::is_empty(state, status_effect)) {
			const Atom label = gd::string_field(state, status_effect, key::label, key::effect);
			const Atom terms = _status_terms(state, status_effect);
			const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, status_effect, key::duration_rounds, int_value(1)), spell, key::debuff);
			const Atom turns = _turns_label(state, rounds);
			summary = concat(state, summary, gd::format(state, key::leaves_it_for_text, { str(label), str(terms), str(turns) }));
		}
		if (_wounded_bonus_applies(state, effect, target_stack)) {
			summary = concat(state, summary, key::wounded_target_bonus_text);
		}
		return summary;
	}
	if (effect_type == key::control_enemy) {
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		const Atom label = gd::string_field(state, status_effect, key::label, key::control);
		const Atom terms = _status_terms(state, status_effect);
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, status_effect, key::duration_rounds, int_value(1)), spell, key::debuff);
		const Atom turns = _turns_label(state, rounds);
		return gd::format(state, key::status_on_for_text, { str(label), str(terms), str(target_label), str(turns) });
	}
	if (effect_type == key::recover_ally) {
		const Atom target_label = gd::string_field(state, active_stack, key::name, key::active_stack_text);
		const int64_t recovery_amount = _battle_spell_recovery_amount(state, hero_state, spell);
		Atom summary = gd::format(state, key::restores_up_to_health_text, { int_value(recovery_amount), str(target_label) });
		const DictRef modifiers = battle_spell_modifiers(state, spell);
		if (!gd::is_empty(state, modifiers)) {
			const Atom modifier_text = _modifier_summary(state, modifiers);
			const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff);
			const Atom turns = _turns_label(state, rounds);
			summary = concat(state, summary, gd::format(state, key::modifiers_for_text, { str(modifier_text), str(turns) }));
		}
		return summary;
	}
	if (effect_type == key::cleanse_ally) {
		const ArrayRef cleanse_labels = _cleanse_labels(state, effect);
		const Atom cleansed = state.array_size(cleanse_labels) != 0 ? join_array_with_comma(state, cleanse_labels) : static_cast<Atom>(key::battle_pressure_text);
		const Atom target_label = gd::string_field(state, active_stack, key::name, key::active_stack_text);
		Atom cleanse_summary = gd::format(state, key::cleanses_from_text, { str(cleansed), str(target_label) });
		const DictRef cleanse_modifiers = battle_spell_modifiers(state, spell);
		if (!gd::is_empty(state, cleanse_modifiers)) {
			const Atom modifier_text = _modifier_summary(state, cleanse_modifiers);
			const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff);
			const Atom turns = _turns_label(state, rounds);
			cleanse_summary = concat(state, cleanse_summary, gd::format(state, key::modifiers_for_text, { str(modifier_text), str(turns) }));
		}
		return cleanse_summary;
	}
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff) {
		const Atom target_label = gd::string_field(state, active_stack, key::name, key::active_stack_text);
		const Atom modifier_text = _modifier_summary(state, battle_spell_modifiers(state, spell));
		const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff);
		const Atom turns = _turns_label(state, rounds);
		return gd::format(state, key::modifiers_to_for_text, { str(modifier_text), str(target_label), str(turns) });
	}
	return key::no_supported_battle_effect_text;
}

Atom status_rules_text(State &state, Atom status_id) {
	(void)state;
	// STATUS_RULES.get(status_id, "")
	if (status_id == key::status_harried) {
		return key::harried_rules_text;
	}
	if (status_id == key::status_staggered) {
		return key::cannot_strike_back_phrase_text;
	}
	if (status_id == key::status_rooted) {
		return key::cannot_move_text;
	}
	return key::empty;
}

Atom _turns_label(State &state, int64_t turns) {
	if (turns == 1) {
		return key::its_next_turn_text;
	}
	return gd::format(state, key::its_next_turns_text, { int_value(turns) });
}

ArrayRef _cleanse_labels(State &state, DictRef effect) {
	const ArrayRef labels = state.new_array();
	const ArrayRef effect_ids = _normalize_string_array(state, get_or_new_array(state, effect, key::cleanse_effect_ids));
	const int64_t size = state.array_size(effect_ids);
	for (int64_t index = 0; index < size; ++index) {
		const Atom effect_id = gd::to_string(state.at(effect_ids, index));
		if (effect_id == key::status_harried) {
			state.append(labels, str(key::harried_label));
		} else if (effect_id == key::status_staggered) {
			state.append(labels, str(key::staggered_label));
		} else {
			const Atom stripped = gd::replace(state, effect_id, key::status_, key::empty);
			const Atom spaced = gd::replace(state, stripped, key::_, key::space);
			state.append(labels, str(gd::capitalize(state, spaced)));
		}
	}
	return labels;
}

Atom _status_terms(State &state, DictRef status_effect) {
	std::vector<Atom> parts;
	Value modifiers;
	if (state.lookup(status_effect, str(key::modifiers), modifiers) && gd::is_dict(modifiers) && !gd::is_empty(state, modifiers.ref)) {
		parts.push_back(_modifier_summary(state, modifiers.ref));
	}
	const Value id_fallback = state.get(status_effect, str(key::status_id), str(key::empty));
	const Atom rules = status_rules_text(state, gd::to_string(state.get(status_effect, str(key::effect_id), id_fallback)));
	if (rules != key::empty) {
		parts.push_back(rules);
	}
	return join_with_comma(state, parts);
}

Atom _modifier_summary(State &state, DictRef modifiers) {
	if (gd::is_empty(state, modifiers)) {
		return key::no_battlefield_bonus_text;
	}
	std::vector<Atom> parts;
	for (const Atom field : kOrderedModifierKeys) {
		if (state.has(modifiers, str(field))) {
			parts.push_back(modifier_part(state, modifiers, field));
		}
	}
	const ArrayRef modifier_keys = gd::keys(state, modifiers);
	const int64_t size = state.array_size(modifier_keys);
	for (int64_t index = 0; index < size; ++index) {
		const Atom field = gd::stringify(state, state.at(modifier_keys, index));
		if (is_ordered_modifier_key(field)) {
			continue;
		}
		parts.push_back(modifier_part(state, modifiers, field));
	}
	return join_with_comma(state, parts);
}

Atom _signed_modifier_label(State &state, int64_t amount) {
	if (amount > 0) {
		return gd::format(state, key::plus_d_text, { int_value(amount) });
	}
	return gd::format(state, key::d_text, { int_value(amount) });
}

} // namespace aurelion::rules::port::spell_rules
