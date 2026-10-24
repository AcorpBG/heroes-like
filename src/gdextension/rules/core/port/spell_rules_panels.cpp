// SpellRules for the panels (Phase 7, slice 7.8): the spellbook and the
// overworld spell rail.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>

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

// ensure_hero_spellbook(hero_state.duplicate(true)).
DictRef spellbook_copy(State &state, DictRef hero_state) {
	return spell_rules::ensure_hero_spellbook(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)), state.new_dict());
}

// var mana: Dictionary = hero.get("spellbook", {}).get("mana", {}): a missing
// level is a new {}; a spellbook that is no Dictionary has no get() (a
// ScriptError), and a mana that is none fails the typed assignment.
DictRef mana_of(State &state, DictRef hero) {
	Value spellbook;
	if (!state.lookup(hero, str(key::spellbook), spellbook)) {
		return state.new_dict();
	}
	return gd::as_dict(ai::vget(state, spellbook, key::mana, dict_value(state.new_dict())));
}

// "\n".join(lines) of an Array of Strings.
Atom join_lines(State &state, ArrayRef lines) {
	std::string joined;
	const int64_t size = state.array_size(lines);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(key::newline);
		}
		joined += state.text(gd::stringify(state, state.at(lines, index)));
	}
	return state.intern(joined);
}

// String(d.get(field, d.get(fallback_field, fallback))) of a Dictionary.
Atom text_or_field(State &state, DictRef dict, Atom field, Atom fallback_field, Atom fallback) {
	const Value inner = state.get(dict, str(fallback_field), str(fallback));
	return string_of(state, state.get(dict, str(field), inner));
}

} // namespace

namespace spell_rules {

Atom spell_id_for_action(State &state, Atom action_id) {
	Atom spell_id = key::empty;
	if (gd::begins_with(state, action_id, key::cast_spell_prefix_text)) {
		spell_id = gd::trim_prefix(state, action_id, key::cast_spell_prefix_text);
	} else if (gd::begins_with(state, action_id, key::learn_spell)) {
		spell_id = gd::trim_prefix(state, action_id, key::learn_spell);
	}
	return !gd::is_empty(state, gd::content_row(state, ContentTable::Spell, spell_id)) ? spell_id : static_cast<Atom>(key::empty);
}

Atom describe_spellbook(State &state, DictRef hero_state, Atom context_filter) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef mana = mana_of(state, hero);
	Atom label = key::Spellbook;
	if (context_filter == key::overworld) {
		label = key::field_spells;
	} else if (context_filter == key::battle) {
		label = key::battle_spells;
	}
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::s_mana_d_d, {str(label), int_value(gd::int_field(state, mana, key::current, 0)), int_value(gd::int_field(state, mana, key::max, 0))})));
	const ArrayRef spell_lines = state.new_array();
	const ArrayRef spells = known_spells(state, hero, context_filter);
	for (const Value &spell : gd::items(state, array_value(spells))) {
		const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, spell);
		const Value id_or_spell = ai::vget(state, spell, key::id, str(key::spell_word));
		const Atom name = string_of(state, ai::vget(state, spell, key::name, id_or_spell));
		const Atom category = spell_category_label(state, gd::as_dict(spell));
		const Atom readiness = _mana_readiness_label(state, hero, mana_cost);
		const Atom effect = _spell_effect_summary(state, gd::as_dict(spell), hero);
		const Atom best_use = _best_use_line(state, gd::as_dict(spell), state.new_dict(), state.new_dict(), state.new_dict());
		state.append(spell_lines, str(gd::format(state, key::s_s_cost_d_s_s_2, {str(name), str(category), int_value(mana_cost), str(readiness), str(effect), str(best_use)})));
	}
	if (state.array_size(spell_lines) == 0) {
		state.append(lines, str(key::no_known_spells));
	} else {
		ai::append_array(state, lines, spell_lines);
	}
	return join_lines(state, lines);
}

Atom describe_overworld_spellbook(State &state, DictRef hero_state, DictRef movement_state) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef mana = mana_of(state, hero);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::field_spells_mana_d_d, {int_value(gd::int_field(state, mana, key::current, 0)), int_value(gd::int_field(state, mana, key::max, 0))})));
	const ArrayRef spell_lines = state.new_array();
	const ArrayRef spells = known_spells(state, hero, key::overworld);
	for (const Value &spell : gd::items(state, array_value(spells))) {
		const DictRef validation = validate_overworld_spell(state, hero, movement_state, spell, 0);
		const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, spell);
		const Atom line = _overworld_spell_readability_line(state, hero, movement_state, gd::as_dict(spell), validation, mana_cost);
		state.append(spell_lines, str(gd::format(state, key::dash_space_s, {str(line)})));
	}
	if (state.array_size(spell_lines) == 0) {
		state.append(lines, str(key::no_field_spells_known));
	} else {
		ai::append_array(state, lines, spell_lines);
	}
	return join_lines(state, lines);
}

Atom describe_overworld_spell_rail(State &state, DictRef hero_state, DictRef movement_state) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef mana = mana_of(state, hero);
	const ArrayRef actions = get_overworld_actions(state, hero, movement_state, 0);
	if (state.array_size(actions) == 0) {
		return gd::format(state, key::field_magic_mana_d_d_no, {int_value(gd::int_field(state, mana, key::current, 0)), int_value(gd::int_field(state, mana, key::max, 0))});
	}
	DictRef focus = state.new_dict();
	for (const Value &action_value : gd::items(state, array_value(actions))) {
		if (!gd::is_dict(action_value)) {
			continue;
		}
		if (!gd::to_bool(state.get(action_value.ref, str(key::disabled), bool_value(false)))) {
			focus = action_value.ref;
			break;
		}
	}
	if (gd::is_empty(state, focus)) {
		focus = gd::as_dict(state.at(actions, 0));
	}
	const Atom readiness = !gd::to_bool(state.get(focus, str(key::disabled), bool_value(false))) ? static_cast<Atom>(key::Ready) : static_cast<Atom>(key::Blocked);
	const Atom spell_name = text_or_field(state, focus, key::spell_name, key::label, key::spell_word);
	const Atom target = text_or_field(state, focus, key::target_requirement, key::target, key::empty);
	const Atom consequence = text_or_field(state, focus, key::consequence, key::effect, key::empty);
	return gd::format(state, key::field_magic_mana_d_d_s, {int_value(gd::int_field(state, mana, key::current, 0)), int_value(gd::int_field(state, mana, key::max, 0)), str(readiness), str(spell_name), str(target), str(consequence)});
}

Atom _overworld_spell_readability_line(State &state, DictRef hero_state, DictRef movement_state, DictRef spell, DictRef validation, int64_t mana_cost) {
	const DictRef hero = spellbook_copy(state, hero_state);
	const DictRef mana = mana_of(state, hero);
	const Atom readiness = gd::to_bool(state.get(validation, str(key::ok), bool_value(false)))
			? static_cast<Atom>(key::Ready)
			: gd::format(state, key::blocked_s, {str(string_of(state, state.get(validation, str(key::message), str(key::cannot_cast_now))))});
	const Atom name = string_of(state, state.get(spell, str(key::name), str(key::spell_word)));
	const Atom category = spell_category_label(state, spell);
	const int64_t current = gd::int_field(state, mana, key::current, 0);
	const int64_t maximum = gd::int_field(state, mana, key::max, 0);
	const Atom target = _overworld_target_requirement(state, spell);
	const Atom effect = _overworld_spell_effect_summary(state, spell, movement_state, hero);
	const Atom best_use = _best_use_line(state, spell, movement_state, state.new_dict(), state.new_dict());
	return gd::format(state, key::s_s_s_mana_d_d, {str(name), str(category), str(readiness), int_value(current), int_value(maximum), int_value(mana_cost), str(target), str(effect), str(best_use)});
}

} // namespace spell_rules

} // namespace aurelion::rules::port
