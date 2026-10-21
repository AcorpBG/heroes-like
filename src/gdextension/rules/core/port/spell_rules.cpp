// SpellRules outside battles: a list of spell ids.

#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port::spell_rules {

namespace {

using gd::str;
namespace key = state::key;

} // namespace

ArrayRef _normalize_spell_ids(State &state, const Value &value) {
	const ArrayRef ids = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &spell_id_value : gd::items(state, value)) {
			const gd::Atom spell_id = gd::stringify_or_fallback(state, spell_id_value);
			if (spell_id != key::empty) {
				state.append(ids, str(spell_id));
			}
		}
	}
	return ids;
}

} // namespace aurelion::rules::port::spell_rules
