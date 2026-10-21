// SpellRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/spell_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::DictRef;
using gd::str;
using state::State;
namespace key = state::key;

} // namespace

namespace spell_rules {

bool knows_spell(State &state, DictRef hero_state, Atom spell_id) {
	// The list ensure_hero_spellbook gives a copy of the hero, read in place:
	// without a template it is the stored list, normalized, or none.
	Value spellbook;
	if (!state.lookup(hero_state, str(key::spellbook), spellbook)) {
		return false;
	}
	if (!gd::is_dict(spellbook) || !state.has(spellbook.ref, str(key::known_spell_ids))) {
		return false;
	}
	return gd::array_has(state, _normalize_spell_ids(state, gd::index(state, spellbook.ref, str(key::known_spell_ids))), str(spell_id));
}

} // namespace spell_rules

} // namespace aurelion::rules::port
