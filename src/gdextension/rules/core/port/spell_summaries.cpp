// Slice 10b: the text a battle spell's effect prints on the battle screen: the effect summary, a status's terms and
// rules, the turns it lasts, the cleansed statuses and the signed modifiers.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
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

// The ally a support spell's text names: the stack, else "one of your stacks"
// for a spell the hero aims at any of them, else "active stack".
Atom ally_label(State &state, DictRef spell, DictRef stack) {
	const Atom fallback = gd::string_field(state, spell, key::target_mode, key::empty) == key::ally_selected ? key::one_of_your_stacks_text : key::active_stack_text;
	return gd::string_field(state, stack, key::name, fallback);
}

// "" for one, "s" for more.
Atom plural_s(int64_t count) {
	return count == 1 ? key::empty : key::s;
}

} // namespace

Atom _battle_spell_effect_summary(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef active_stack, DictRef target_stack) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Atom effect_type = gd::to_string(state.get(effect, str(key::type), str(key::empty)));
	if (effect_type == key::damage_enemy) {
		// Harmful numbers at the caster's power less the target hero's Knowledge
		// (all of the power without a target).
		const int64_t damage = _battle_spell_damage_at(state, hero_state, spell, target_stack, spell_power_against(state, hero_state, battle, target_stack));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		Atom summary = gd::format(state, key::damage_to_text, { int_value(damage), str(target_label) });
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		if (!gd::is_empty(state, status_effect)) {
			const Atom label = gd::string_field(state, status_effect, key::label, key::effect);
			const int64_t power_against = spell_power_against(state, hero_state, battle, target_stack);
			const Atom terms = harmful_status_terms(state, status_effect, power_against);
			const Atom turns = _turns_label(state, harmful_status_turns(state, hero_state, spell, status_effect, power_against));
			summary = concat(state, summary, gd::format(state, key::leaves_it_for_text, { str(label), str(terms), str(turns) }));
		}
		if (_wounded_bonus_applies(state, effect, target_stack)) {
			summary = concat(state, summary, key::wounded_target_bonus_text);
		}
		return concat(state, summary, clauses_as_phrase(state, spell_extra_clauses(state, hero_state, spell, battle, target_stack)));
	}
	if (effect_type == key::control_enemy) {
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		const Atom label = gd::string_field(state, status_effect, key::label, key::control);
		const int64_t power_against = spell_power_against(state, hero_state, battle, target_stack);
		const Atom terms = harmful_status_terms(state, status_effect, power_against);
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		const Atom turns = gd::bool_field(state, status_effect, key::battle_long, false)
				? static_cast<Atom>(key::rest_of_battle_text)
				: _turns_label(state, harmful_status_turns(state, hero_state, spell, status_effect, power_against));
		const Atom summary = gd::format(state, key::status_on_for_text, { str(label), str(terms), str(target_label), str(turns) });
		return concat(state, summary, clauses_as_phrase(state, spell_extra_clauses(state, hero_state, spell, battle, target_stack)));
	}
	if (effect_type == key::recover_ally) {
		const Atom target_label = ally_label(state, spell, active_stack);
		const int64_t recovery_amount = _battle_spell_recovery_amount(state, hero_state, spell);
		Atom summary = gd::format(state, key::restores_up_to_health_text, { int_value(recovery_amount), str(target_label) });
		const DictRef modifiers = battle_spell_modifiers(state, spell);
		if (!gd::is_empty(state, modifiers)) {
			const Atom modifier_text = _modifier_summary(state, modifiers);
			const int64_t rounds = spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff);
			const Atom turns = _turns_label(state, rounds);
			summary = concat(state, summary, gd::format(state, key::modifiers_for_text, { str(modifier_text), str(turns) }));
		}
		return concat(state, summary, clauses_as_phrase(state, spell_extra_clauses(state, hero_state, spell, battle, active_stack)));
	}
	if (effect_type == key::cleanse_ally && cleanse_takes_any_harm(state, effect)) {
		const int64_t count = spell_effect_count(state, spell, spell_power(state, hero_state));
		return gd::format(state, key::removes_harmful_effects_text, { int_value(count), str(plural_s(count)), str(ally_label(state, spell, active_stack)) });
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
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff || effect_type == key::ally_effect) {
		const Atom target_label = ally_label(state, spell, active_stack);
		const Atom modifier_text = helpful_effect_terms(state, hero_state, spell, battle, gd::string_field(state, active_stack, key::side, key::player));
		const Atom turns = _turns_label(state, helpful_effect_turns(state, hero_state, spell));
		const Atom summary = gd::format(state, key::modifiers_to_for_text, { str(modifier_text), str(target_label), str(turns) });
		return concat(state, summary, clauses_as_phrase(state, spell_extra_clauses(state, hero_state, spell, battle, active_stack)));
	}
	if (effect_type == key::dispel_enemy) {
		// At the caster's power less the target hero's Knowledge when a target
		// is known (a battle without one reads none).
		const int64_t count = spell_effect_count(state, spell, spell_power_against(state, hero_state, battle, target_stack));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		return gd::format(state, key::removes_helpful_effects_text, { int_value(count), str(plural_s(count)), str(target_label) });
	}
	if (effect_type == key::move_ally) {
		const int64_t reach = spell_move_reach(state, spell, spell_power(state, hero_state));
		return gd::format(state, key::moves_up_to_hexes_text, { str(ally_label(state, spell, active_stack)), int_value(reach) });
	}
	// The two-stack spells (spell_pairs.cpp).
	if (effect_type == key::graft_allies) {
		const Atom turns = _turns_label(state, helpful_effect_turns(state, hero_state, spell));
		return gd::format(state, key::grafts_for_text, { str(turns) });
	}
	if (effect_type == key::transfer_ally) {
		return gd::format(state, key::moves_health_into_text, { int_value(_battle_spell_recovery_amount(state, hero_state, spell)) });
	}
	if (effect_type == key::swap_allies) {
		const int64_t range = spell_move_reach(state, spell, spell_power(state, hero_state));
		return gd::format(state, key::swaps_allies_text, { int_value(range) });
	}
	if (effect_type == key::swap_enemy) {
		const int64_t range = spell_move_reach(state, spell, spell_power_against(state, hero_state, battle, target_stack));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		return gd::format(state, key::swaps_enemy_text, { str(target_label), int_value(range) });
	}
	// The spells that take a hex (spell_ground.cpp).
	if (effect_type == key::ground_effect) {
		return ground_spell_summary(state, hero_state, spell, battle, target_stack, false);
	}
	// The tier-3 kinds (spell_tier3.cpp).
	if (effect_type == key::sacrifice) {
		const int64_t pct = gd::add(gd::int_field(state, effect, key::damage_pct, 0),
				gd::mul(gd::int_field(state, effect, key::damage_pct_power_scale, 0), spell_power_against(state, hero_state, battle, target_stack)));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		return gd::format(state, key::sacrifice_summary_text, { int_value(gd::int_field(state, effect, key::cost_pct, 0)), str(target_label), int_value(pct) });
	}
	if (effect_type == key::doom_enemy) {
		const int64_t damage = _battle_spell_damage_at(state, hero_state, spell, target_stack, spell_power_against(state, hero_state, battle, target_stack));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		const int64_t turns = engine_max<int64_t>(1, gd::int_field(state, effect, key::duration_rounds, 2));
		return gd::format(state, key::doom_summary_text, { str(target_label), int_value(damage), str(_turns_label(state, turns)) });
	}
	if (effect_type == key::free_volley) {
		const int64_t pct = gd::add(gd::int_field(state, effect, key::volley_pct, 0),
				gd::mul(gd::int_field(state, effect, key::volley_pct_power_scale, 0), spell_power(state, hero_state)));
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		return gd::format(state, key::volley_summary_text, { str(target_label), int_value(pct) });
	}
	if (effect_type == key::temp_creatures) {
		return gd::format(state, key::bud_summary_text, { int_value(_battle_spell_recovery_amount(state, hero_state, spell)), str(ally_label(state, spell, active_stack)) });
	}
	if (effect_type == key::damage_around) {
		// Harmful numbers at the caster's power less the other side's Knowledge.
		const Atom caster_side = gd::string_field(state, active_stack, key::side, key::player);
		const int64_t against = engine_max<int64_t>(0, gd::sub(spell_power(state, hero_state), opposing_side_knowledge(state, battle, caster_side)));
		const int64_t damage = _battle_spell_damage_at(state, hero_state, spell, state.new_dict(), against);
		return gd::format(state, key::around_summary_text, { int_value(damage), str(ally_label(state, spell, active_stack)) });
	}
	if (effect_type == key::battle_aura) {
		const int64_t rounds = spell_effect_turns(state, hero_state, effect, spell, key::buff, spell_power(state, hero_state));
		const Atom rounds_label = rounds == 1 ? static_cast<Atom>(key::one_round_text) : gd::format(state, key::rounds_count_text, { int_value(rounds) });
		return gd::format(state, key::watch_summary_text, { int_value(_battle_spell_recovery_amount(state, hero_state, spell)), str(rounds_label) });
	}
	// Goad and Uproot (spell_tier3_control.cpp).
	if (effect_type == key::taunt_enemy || effect_type == key::pull_enemy) {
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		const int64_t power_against = spell_power_against(state, hero_state, battle, target_stack);
		const Atom target_label = gd::string_field(state, target_stack, key::name, key::selected_enemy_text);
		const Atom turns = _turns_label(state, harmful_status_turns(state, hero_state, spell, status_effect, power_against));
		if (effect_type == key::taunt_enemy) {
			const Value bonus = gd::field(state, status_effect, key::modifiers);
			const Atom bonus_text = gd::is_dict(bonus) ? _modifier_summary(state, bonus.ref) : static_cast<Atom>(key::empty);
			return gd::format(state, key::goad_summary_text, { str(target_label), str(bonus_text), str(turns) });
		}
		return gd::format(state, key::drag_summary_text, { str(target_label), int_value(spell_move_reach(state, spell, power_against)), str(turns) });
	}
	return key::no_supported_battle_effect_text;
}

Atom ground_spell_summary(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef target_stack, bool sentence) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Atom ground = gd::string_field(state, effect, key::ground, key::empty);
	const int64_t power = spell_power(state, hero_state);
	// Harmful numbers at the caster's power less the target hero's Knowledge
	// (all of the power without a target), its rounds at the caster's power.
	const int64_t against = spell_power_against(state, hero_state, battle, target_stack);
	const auto rounds_label = [&](Atom kind) {
		const int64_t rounds = spell_effect_turns(state, hero_state, effect, spell, kind, power);
		return rounds == 1 ? static_cast<Atom>(key::one_round_text) : gd::format(state, key::rounds_count_text, { int_value(rounds) });
	};
	const int64_t damage = gd::int_field(state, effect, key::base_damage, 0) > 0 ? _battle_spell_damage_at(state, hero_state, spell, state.new_dict(), against) : 0;
	if (ground == key::fire_ground) {
		return gd::format(state, sentence ? key::burn_hexes_sentence : key::burns_ground_text, { str(rounds_label(key::debuff)), int_value(damage) });
	}
	if (ground == key::bramble_ground) {
		return gd::format(state, sentence ? key::grow_brambles_sentence : key::brambles_ground_text, { str(rounds_label(key::debuff)), int_value(damage) });
	}
	if (ground == key::pillar) {
		return gd::format(state, sentence ? key::raise_pillar_sentence : key::pillar_ground_text, { str(rounds_label(key::buff)), int_value(gd::int_field(state, effect, key::defense, 0)) });
	}
	if (ground == key::murk) {
		return gd::format(state, sentence ? key::lay_murk_sentence : key::murk_ground_text, { str(rounds_label(key::debuff)) });
	}
	if (ground == key::trap) {
		const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
		const Atom turns = _turns_label(state, harmful_status_turns(state, hero_state, spell, status_effect, against));
		return gd::format(state, sentence ? key::plant_seed_sentence : key::seed_ground_text, { int_value(damage), str(turns) });
	}
	// Tier 3: Living Wall, Boundary Line, Prism Array and Bog Pool.
	if (ground == key::wall) {
		return gd::format(state, sentence ? key::grow_wall_sentence : key::wall_ground_text, { str(rounds_label(key::buff)) });
	}
	if (ground == key::barrier) {
		const int64_t length = engine_max<int64_t>(1, gd::int_field(state, effect, key::length, 3));
		return gd::format(state, sentence ? key::mark_barrier_sentence : key::barrier_ground_text, { int_value(length), str(rounds_label(key::debuff)) });
	}
	if (ground == key::prism) {
		return gd::format(state, sentence ? key::raise_prism_sentence : key::prism_ground_text, { str(rounds_label(key::buff)), int_value(damage) });
	}
	if (ground == key::mire) {
		const int64_t count = engine_max<int64_t>(1, power_count(state, effect, key::count, key::count_power_divisor, power));
		return gd::format(state, sentence ? key::lay_mire_sentence : key::mire_ground_text, { int_value(count) });
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
	if (status_id == key::status_dazed) {
		return key::dazed_rules_text;
	}
	if (status_id == key::status_asleep) {
		return key::asleep_rules_text;
	}
	if (status_id == key::status_blinded) {
		return key::blinded_rules_text;
	}
	if (status_id == key::status_afraid) {
		return key::afraid_rules_text;
	}
	if (status_id == key::status_confused) {
		return key::confused_rules_text;
	}
	if (status_id == key::status_fleeing) {
		return key::fleeing_rules_text;
	}
	if (status_id == key::status_goaded) {
		return key::goaded_rules_text;
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
	return status_id_labels(state, get_or_new_array(state, effect, key::cleanse_effect_ids));
}

ArrayRef status_id_labels(State &state, const Value &ids) {
	const ArrayRef labels = state.new_array();
	const ArrayRef effect_ids = _normalize_string_array(state, ids);
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

// --- The new spells' words (docs/magic-system-spells.md, Mechanics) ----------

Atom mechanic_terms(State &state, DictRef mechanic) {
	if (gd::is_empty(state, mechanic)) {
		return key::empty;
	}
	const auto has = [&](Atom field) { return state.has(mechanic, str(field)); };
	const auto amount = [&](Atom field) { return int_value(gd::int_field(state, mechanic, field, 0)); };
	std::vector<Atom> parts;
	if (has(key::plate)) {
		parts.push_back(gd::format(state, key::plate_term_text, { amount(key::plate) }));
	}
	if (has(key::stationary_attack)) {
		parts.push_back(gd::format(state, key::stationary_attack_term_text, { amount(key::stationary_attack) }));
	}
	if (has(key::momentum_per_blow)) {
		parts.push_back(gd::format(state, key::momentum_term_text, { amount(key::momentum_per_blow), amount(key::momentum_cap) }));
	}
	if (has(key::lifesteal_pct)) {
		parts.push_back(gd::format(state, key::lifesteal_term_text, { amount(key::lifesteal_pct) }));
	}
	if (has(key::thorns)) {
		parts.push_back(gd::format(state, key::thorns_term_text, { amount(key::thorns) }));
	}
	if (has(key::regrowth)) {
		parts.push_back(gd::format(state, key::regrowth_term_text, { amount(key::regrowth) }));
	}
	if (has(key::shot_shield)) {
		parts.push_back(key::shot_shield_term_text);
	}
	if (has(key::reflect_spell)) {
		parts.push_back(key::reflect_term_text);
	}
	if (has(key::act_next)) {
		parts.push_back(key::act_next_term_text);
	}
	if (has(key::backlash_pct)) {
		parts.push_back(gd::format(state, key::backlash_term_text, { amount(key::backlash_pct) }));
	}
	if (has(key::damage_taken_pct)) {
		parts.push_back(gd::format(state, key::damage_taken_term_text, { amount(key::damage_taken_pct) }));
	}
	if (has(key::tightening)) {
		parts.push_back(gd::format(state, key::tightening_term_text, { amount(key::tightening) }));
	}
	if (has(key::curse_damage)) {
		parts.push_back(gd::format(state, key::curse_term_text, { amount(key::curse_damage) }));
	}
	if (has(key::heal_block)) {
		parts.push_back(key::heal_block_term_text);
	}
	// Tier 3.
	if (has(key::on_hit_burning)) {
		const int64_t turns = gd::int_field(state, mechanic, key::burning_turns, 2);
		parts.push_back(gd::format(state, key::on_hit_burning_term_text, { amount(key::on_hit_burning), int_value(turns) }));
	}
	if (has(key::burning_damage)) {
		parts.push_back(gd::format(state, key::burning_term_text, { amount(key::burning_damage) }));
	}
	if (has(key::damage_cap_pct)) {
		parts.push_back(gd::format(state, key::damage_cap_term_text, { amount(key::damage_cap_pct) }));
	}
	if (has(key::death_save_pct)) {
		parts.push_back(gd::format(state, key::death_save_term_text, { amount(key::death_save_pct) }));
	}
	if (has(key::deathless)) {
		parts.push_back(gd::format(state, key::deathless_term_text, { amount(key::deathless_heal) }));
	}
	if (has(key::heal_inversion_pct)) {
		parts.push_back(gd::format(state, key::heal_inversion_term_text, { amount(key::heal_inversion_pct) }));
	}
	if (has(key::spell_shield)) {
		parts.push_back(key::spell_shield_term_text);
	}
	if (has(key::cohesion_lock)) {
		parts.push_back(key::cohesion_lock_term_text);
	}
	if (has(key::phase)) {
		parts.push_back(key::phase_term_text);
	}
	if (has(key::no_strike_back)) {
		parts.push_back(key::no_strike_back_term_text);
	}
	if (has(key::doom_damage)) {
		parts.push_back(gd::format(state, key::doom_term_text, { amount(key::doom_damage) }));
	}
	return join_with_comma(state, parts);
}

Atom helpful_effect_terms(State &state, DictRef hero_state, DictRef spell, DictRef battle, Atom caster_side) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const int64_t power = spell_power(state, hero_state);
	std::vector<Atom> parts;
	const DictRef modifiers = battle_spell_modifiers(state, spell);
	if (!gd::is_empty(state, modifiers)) {
		parts.push_back(_modifier_summary(state, scaled_spell_modifiers(state, effect, modifiers, power)));
	}
	Value raw;
	if (state.lookup(effect, str(key::mechanic), raw) && gd::is_dict(raw)) {
		// Thorns cut at power less the other side's Knowledge, as the cast resolves them.
		const bool against_enemy = gd::bool_field(state, raw.ref, key::uses_enemy_power, false);
		const int64_t mechanic_power = against_enemy ? gd::sub(power, opposing_side_knowledge(state, battle, caster_side)) : power;
		const Atom terms = mechanic_terms(state, resolve_mechanic(state, raw, mechanic_power < 0 ? 0 : mechanic_power));
		if (terms != key::empty) {
			parts.push_back(terms);
		}
	}
	return parts.empty() ? _modifier_summary(state, modifiers) : join_with_comma(state, parts);
}

int64_t helpful_effect_turns(State &state, DictRef hero_state, DictRef spell) {
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	return spell_effect_turns(state, hero_state, effect, spell, key::buff, spell_power(state, hero_state));
}

Atom harmful_status_terms(State &state, DictRef status_effect, int64_t power_against) {
	std::vector<Atom> parts;
	const Atom terms = _status_terms(state, status_effect);
	if (terms != key::empty) {
		parts.push_back(terms);
	}
	Value raw;
	if (state.lookup(status_effect, str(key::mechanic), raw) && gd::is_dict(raw)) {
		const Atom mechanic = mechanic_terms(state, resolve_mechanic(state, raw, power_against));
		if (mechanic != key::empty) {
			parts.push_back(mechanic);
		}
	}
	return join_with_comma(state, parts);
}

int64_t harmful_status_turns(State &state, DictRef hero_state, DictRef spell, DictRef status_effect, int64_t power_against) {
	return spell_effect_turns(state, hero_state, status_effect, spell, key::debuff, power_against);
}

ArrayRef spell_extra_clauses(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef target_stack) {
	const ArrayRef clauses = state.new_array();
	const DictRef effect = two_argument_get_target(get_or_new_dict(state, spell, key::effect));
	const Atom effect_type = gd::to_string(state.get(effect, str(key::type), str(key::empty)));
	const int64_t power_against = spell_power_against(state, hero_state, battle, target_stack);
	if (effect_type == key::damage_enemy) {
		const int64_t heat = gd::int_field(state, effect, key::heat, 0);
		if (heat > 0) {
			state.append(clauses, str(gd::format(state, key::heat_clause_text, { int_value(heat), int_value(heat_burst_damage(power_against)) })));
		}
		const int64_t rooted_bonus = gd::int_field(state, effect, key::rooted_bonus_pct, 0);
		if (rooted_bonus > 0) {
			state.append(clauses, str(gd::format(state, key::rooted_bonus_clause_text, { int_value(rooted_bonus) })));
		}
		if (gd::bool_field(state, effect, key::heat_burst, false)) {
			state.append(clauses, str(key::heat_burst_clause_text));
		}
		const int64_t push = gd::int_field(state, effect, key::push, 0);
		if (push == 1) {
			state.append(clauses, str(key::push_one_clause_text));
		} else if (push > 1) {
			state.append(clauses, str(gd::format(state, key::push_clause_text, { int_value(push) })));
		}
	} else if (effect_type == key::control_enemy) {
		const DictRef follow = gd::as_dict(get_or_new_dict(state, effect, key::follow_status_effect));
		if (!gd::is_empty(state, follow)) {
			const Atom label = gd::string_field(state, follow, key::label, key::effect);
			const Atom turns = _turns_label(state, harmful_status_turns(state, hero_state, spell, follow, power_against));
			state.append(clauses, str(gd::format(state, key::follow_status_clause_text, { str(label), str(harmful_status_terms(state, follow, power_against)), str(turns) })));
		}
	} else if (effect_type == key::recover_ally) {
		const int64_t block_turns = gd::int_field(state, effect, key::heal_block_turns, 0);
		if (block_turns > 0) {
			state.append(clauses, str(gd::format(state, key::heal_block_clause_text, { str(_turns_label(state, block_turns)) })));
		}
		const int64_t statuses = gd::int_field(state, effect, key::cleanse_statuses, 0);
		if (statuses == 1) {
			state.append(clauses, str(key::cleanse_status_clause_text));
		} else if (statuses > 1) {
			state.append(clauses, str(gd::format(state, key::cleanse_statuses_clause_text, { int_value(statuses) })));
		}
		if (gd::bool_field(state, effect, key::raise, false)) {
			state.append(clauses, str(key::raise_clause_text));
		}
	}
	// The stacks it reaches beyond the target (spell_reach.cpp).
	if (effect_type == key::damage_enemy) {
		int64_t sparks = gd::int_field(state, effect, key::random_hits, 0);
		const int64_t spark_divisor = gd::int_field(state, effect, key::random_hits_power_divisor, 0);
		if (sparks > 0 && spark_divisor > 0) {
			sparks = gd::add(sparks, compat::int_div(spell_power(state, hero_state), spark_divisor));
		}
		if (sparks > 1) {
			state.append(clauses, str(gd::format(state, key::sparks_clause_text, { int_value(sparks) })));
		}
		if (gd::string_field(state, effect, key::splash, key::empty) == key::adjacent) {
			state.append(clauses, str(key::splash_clause_text));
		}
		if (gd::bool_field(state, effect, key::line, false)) {
			state.append(clauses, str(key::line_clause_text));
		}
		const int64_t drain_pct = gd::int_field(state, effect, key::drain_pct, 0);
		if (drain_pct > 0) {
			state.append(clauses, str(gd::format(state, key::drain_clause_text, { int_value(drain_pct) })));
		}
		if (gd::string_field(state, effect, key::status_splash, key::empty) == key::adjacent) {
			const DictRef status_effect = gd::as_dict(get_or_new_dict(state, effect, key::status_effect));
			state.append(clauses, str(gd::format(state, key::status_splash_clause_text, { str(gd::string_field(state, status_effect, key::label, key::effect)) })));
		}
		std::string jumps;
		for (const Value &pct : gd::field_items(state, effect, str(key::chain))) {
			if (!jumps.empty()) {
				jumps += state.text(key::then_separator_text);
			}
			jumps += state.text(gd::format(state, key::percent_text, { int_value(gd::to_int(state, pct)) }));
		}
		if (!jumps.empty()) {
			state.append(clauses, str(gd::format(state, key::chain_clause_text, { str(state.intern(jumps)) })));
		}
		for (const Value &entry : gd::field_items(state, effect, str(key::mastery_chain))) {
			if (gd::is_dict(entry)) {
				state.append(clauses, str(gd::format(state, key::mastery_chain_clause_text,
						{ int_value(gd::int_field(state, entry.ref, key::rank, 0)), int_value(gd::int_field(state, entry.ref, key::pct, 0)) })));
			}
		}
	}
	const Atom reach = gd::string_field(state, effect, key::reach, key::empty);
	if (effect_type == key::recover_ally && reach == key::all) {
		state.append(clauses, str(key::heal_all_clause_text));
	}
	if (effect_type == key::recover_ally && reach == key::adjacent) {
		state.append(clauses, str(gd::format(state, key::heal_beside_clause_text, { int_value(gd::int_field(state, effect, key::reach_pct, 100)) })));
	} else if (reach == key::adjacent && (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff || effect_type == key::ally_effect)) {
		state.append(clauses, str(key::reach_beside_clause_text));
	}
	const ArrayRef immune = status_id_labels(state, get_or_new_array(state, effect, key::status_immunity_ids));
	if (state.array_size(immune) > 0) {
		state.append(clauses, str(gd::format(state, key::keeps_off_clause_text, { str(join_array_with_comma(state, immune)) })));
	}
	for (const Value &entry : gd::field_items(state, spell, str(key::mastery_reach))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom reach = gd::string_field(state, entry.ref, key::reach, key::empty);
		const Value rank = int_value(gd::int_field(state, entry.ref, key::rank, 0));
		if (reach == key::adjacent) {
			state.append(clauses, str(gd::format(state, key::mastery_adjacent_clause_text, { rank })));
		} else if (reach == key::all) {
			state.append(clauses, str(gd::format(state, key::mastery_all_clause_text, { rank })));
		}
	}
	return clauses;
}

Atom clauses_as_phrase(State &state, ArrayRef clauses) {
	std::string joined;
	const int64_t size = state.array_size(clauses);
	for (int64_t index = 0; index < size; ++index) {
		joined += state.text(key::semicolon_space);
		joined += state.text(gd::to_string(state.at(clauses, index)));
	}
	return state.intern(joined);
}

Atom clauses_as_sentence(State &state, ArrayRef clauses) {
	if (state.array_size(clauses) == 0) {
		return key::empty;
	}
	// The phrase without its leading "; ", first letter raised, as a sentence.
	std::string sentence = state.text(clauses_as_phrase(state, clauses)).substr(state.text(key::semicolon_space).size());
	if (!sentence.empty() && sentence[0] >= 'a' && sentence[0] <= 'z') {
		sentence[0] = static_cast<char>(sentence[0] - 'a' + 'A');
	}
	return state.intern(" " + sentence + ".");
}

} // namespace aurelion::rules::port::spell_rules
