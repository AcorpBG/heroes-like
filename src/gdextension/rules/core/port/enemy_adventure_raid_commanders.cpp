// EnemyAdventureRules ports shared by the computer players' day (Phase 4) and the
// payload of a battle (Phase 2a): the name of a raid's commander. Phase 4's code
// (enemy_adventure_rules_turn.cpp), unchanged.

#include "aurelion_rules/port/enemy_adventure_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(key, {}): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// String(record.get("encounter_id", record.get("id", fallback))).
Atom encounter_id_of(State &state, DictRef record, Atom fallback) {
	const Value id = state.get(record, str(key::id), str(fallback));
	return text_or(state, record, key::encounter_id, id);
}

// value is Dictionary and not value.is_empty().
bool filled_dict(const State &state, const Value &value) {
	return gd::is_dict(value) && !gd::is_empty(state, value.ref);
}

} // namespace

namespace enemy_adventure_rules {

Atom raid_commander_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	const Value commander_state = get_or_new_dict(state, encounter, key::enemy_commander_state);
	if (gd::is_dict(commander_state)) {
		const Atom commander_name = text(state, commander_state.ref, key::name, key::empty);
		if (commander_name != key::empty) {
			return commander_name;
		}
	}
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, encounter, key::empty));
	const Value enemy_commander = get_or_new_dict(state, encounter_template, key::enemy_commander);
	return gd::stringify(state, ai::vget(state, enemy_commander, key::name, str(key::empty)));
}

Atom raid_commander_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	const Value commander_state = get_or_new_dict(state, encounter, key::enemy_commander_state);
	if (filled_dict(state, commander_state)) {
		return commander_display_name(state, commander_state, true);
	}
	return raid_commander_name(state, encounter);
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
