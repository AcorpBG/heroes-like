// SpellRules ports shared by the computer players' day (Phase 4) and the ends of a
// battle (Phase 5): a hero learning a spell. Phase 4's port (branch
// native-phase4-faction-turn), moved unchanged by Phase 5's slice 09.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace spell_rules {

DictRef learn_spell(State &state, DictRef hero_state, Atom spell_id) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
	const DictRef result = state.new_dict();
	if (gd::is_empty(state, spell)) {
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::message), str(key::that_spell_is_not_known_to));
		return result;
	}
	if (_knows_spell(state, hero, spell_id)) {
		const Atom hero_name = gd::stringify(state, gd::field_or(state, hero, key::name, str(key::the_hero_text)));
		const Atom spell_name = gd::stringify(state, gd::field_or(state, spell, key::name, str(spell_id)));
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::message), str(gd::format(state, key::s_already_knows_s, { str(hero_name), str(spell_name) })));
		return result;
	}
	// var spellbook = hero.get("spellbook", {}); var known_spell_ids: Array = spellbook.get("known_spell_ids", [])
	Value spellbook;
	if (!state.lookup(hero, str(key::spellbook), spellbook)) {
		spellbook = dict_value(state.new_dict());
	}
	const ArrayRef known_spell_ids = gd::as_array(ai::vget(state, spellbook, key::known_spell_ids, array_value(state.new_array())));
	state.append(known_spell_ids, str(spell_id));
	state.set(spellbook.ref, str(key::known_spell_ids), array_value(_normalize_spell_ids(state, array_value(known_spell_ids))));
	state.set(hero, str(key::spellbook), spellbook);
	const Atom hero_name = gd::stringify(state, gd::field_or(state, hero, key::name, str(key::the_hero_text)));
	const Atom spell_name = gd::stringify(state, gd::field_or(state, spell, key::name, str(spell_id)));
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(gd::format(state, key::s_learns_s, { str(hero_name), str(spell_name) })));
	return result;
}

} // namespace spell_rules

} // namespace aurelion::rules::port
