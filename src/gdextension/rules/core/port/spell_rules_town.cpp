// SpellRules for the human seat's town (Phase 7, slice 7.6): spell icons and
// the inspection line the guild shows.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) of a value that may be passed on: the field, or a new
// Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// x in SPELL_SCHOOL_IDS of a String.
bool is_spell_school_id(Atom school_id) {
	return school_id == key::beacon || school_id == key::mire || school_id == key::lens || school_id == key::root ||
			school_id == key::furnace || school_id == key::veil || school_id == key::old_measure;
}

// value.get(field, {}) read only: false when the field is missing (the empty
// Dictionary), else the field's value. A value that is no Dictionary has no
// get() (a ScriptError, as in GDScript).
bool lookup_untyped(State &state, const Value &value, Atom field, Value &out) {
	if (!gd::is_dict(value)) {
		out = ai::vget(state, value, field);
		return true;
	}
	return state.lookup(value.ref, str(field), out);
}

} // namespace

namespace spell_rules {

Atom spell_school_icon_path(State &state, Atom spell_id) {
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	const Atom school_id = gd::strip_edges(state, text_or(state, spell, key::school_id, key::empty));
	if (!is_spell_school_id(school_id)) {
		return key::empty;
	}
	const DictRef icon = gd::content_row(state, ContentTable::SpellSchoolIcon, school_id);
	const Atom icon_path = gd::strip_edges(state, text_or(state, icon, key::icon_path, key::empty));
	if (text_or(state, icon, key::id, key::empty) != school_id) {
		return key::empty;
	}
	if (text_or(state, icon, key::icon_id, key::empty) != gd::format(state, key::spell_school_sigil_s, {str(school_id)})) {
		return key::empty;
	}
	if (!gd::begins_with(state, icon_path, key::res_art_magic_runtime_schools) || !gd::resource_exists(state, icon_path)) {
		return key::empty;
	}
	return icon_path;
}

Atom spell_icon_path(State &state, Atom spell_id) {
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	if (gd::is_empty(state, spell)) {
		return key::empty;
	}
	const DictRef icon = gd::content_row(state, ContentTable::SpellIcon, spell_id);
	const Atom icon_path = gd::strip_edges(state, text_or(state, icon, key::icon_path, key::empty));
	const Atom school_id = gd::strip_edges(state, text_or(state, spell, key::school_id, key::empty));
	if (text_or(state, icon, key::id, key::empty) == spell_id &&
			text_or(state, icon, key::spell_id, key::empty) == spell_id &&
			text_or(state, icon, key::school_id, key::empty) == school_id &&
			text_or(state, icon, key::icon_id, key::empty) == gd::format(state, key::spell_signature_icon_s, {str(gd::trim_prefix(state, spell_id, key::spell_))}) &&
			gd::begins_with(state, icon_path, key::res_art_magic_runtime_spells) &&
			gd::resource_exists(state, icon_path)) {
		return icon_path;
	}
	return spell_school_icon_path(state, spell_id);
}

Atom describe_spell_inspection_line(State &state, DictRef hero_state, DictRef spell, DictRef context_state) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const int64_t mana_cost = adjusted_spell_mana_cost(state, hero, dict_value(spell));
	Atom readiness = _mana_readiness_label(state, hero, mana_cost);
	const Atom context = text_or(state, spell, key::context, key::empty);
	if (context == key::overworld) {
		const DictRef movement = gd::as_dict(field_or_new_dict(state, context_state, key::movement));
		if (!gd::is_empty(state, movement)) {
			const DictRef validation = validate_overworld_spell(state, hero, movement, dict_value(spell), 0);
			readiness = gd::bool_field(state, validation, key::ok, false) ? key::Ready : gd::format(state, key::blocked_s, {str(text_or(state, validation, key::message, key::cannot_cast_now))});
		}
		const Atom name = text_or(state, spell, key::name, key::spell_word);
		const Atom category = spell_category_label(state, spell);
		const Atom effect = _overworld_spell_effect_summary(state, spell, movement, hero);
		const Atom best_use = _best_use_line(state, spell, movement, state.new_dict(), state.new_dict());
		return gd::format(state, key::s_s_cost_d_s_s, {str(name), str(category), int_value(mana_cost), str(readiness), str(effect), str(best_use)});
	}
	if (context == key::battle) {
		const DictRef battle = gd::as_dict(field_or_new_dict(state, context_state, key::battle));
		const DictRef active_stack = gd::as_dict(field_or_new_dict(state, context_state, key::active_stack));
		const DictRef target_stack = gd::as_dict(field_or_new_dict(state, context_state, key::target_stack));
		if (!gd::is_empty(state, battle)) {
			const DictRef validation = validate_battle_spell(state, hero, battle, active_stack, target_stack, dict_value(spell), key::player);
			readiness = gd::bool_field(state, validation, key::ok, false) ? key::Ready : gd::format(state, key::blocked_s, {str(text_or(state, validation, key::message, key::cannot_cast_now))});
		}
		const Atom name = text_or(state, spell, key::name, key::spell_word);
		const Atom category = spell_category_label(state, spell);
		const Atom effect = _battle_spell_effect_summary(state, hero, spell, battle, active_stack, target_stack);
		const Atom best_use = _best_use_line(state, spell, battle, active_stack, target_stack);
		return gd::format(state, key::s_s_cost_d_s_s, {str(name), str(category), int_value(mana_cost), str(readiness), str(effect), str(best_use)});
	}
	const Atom name = text_or(state, spell, key::name, key::spell_word);
	const Atom category = spell_category_label(state, spell);
	const Atom effect = _spell_effect_summary(state, spell, hero);
	const Atom best_use = _best_use_line(state, spell, state.new_dict(), state.new_dict(), state.new_dict());
	return gd::format(state, key::s_s_cost_d_s_s, {str(name), str(category), int_value(mana_cost), str(readiness), str(effect), str(best_use)});
}

Atom _mana_readiness_label(State &state, DictRef hero_state, int64_t mana_cost) {
	// int(hero_state.get("spellbook", {}).get("mana", {}).get("current", 0)), read only.
	int64_t current_mana = 0;
	Value spellbook;
	Value mana;
	if (state.lookup(hero_state, str(key::spellbook), spellbook) && lookup_untyped(state, spellbook, key::mana, mana)) {
		current_mana = gd::to_int(state, ai::vget(state, mana, key::current, int_value(0)));
	}
	if (current_mana >= compat::engine_max<int64_t>(0, mana_cost)) {
		return key::ready_mana;
	}
	return gd::format(state, key::need_d_mana, {int_value(compat::engine_max<int64_t>(0, gd::sub(mana_cost, current_mana)))});
}

Atom _spell_effect_summary(State &state, DictRef spell, DictRef hero_state) {
	const Atom context = text_or(state, spell, key::context, key::empty);
	if (context == key::overworld) {
		return _overworld_spell_effect_summary(state, spell, state.new_dict(), state.new_dict());
	}
	if (context == key::battle) {
		return _battle_spell_effect_summary(state, hero_state, spell, state.new_dict(), state.new_dict(), state.new_dict());
	}
	return key::no_supported_effect;
}

} // namespace spell_rules

} // namespace aurelion::rules::port
