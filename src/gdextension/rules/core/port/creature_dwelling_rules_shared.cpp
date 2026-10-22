// CreatureDwellingRules ports shared by the computer players' day (Phase 4) and the
// ends of a battle (Phase 5): a dwelling guard's result.

#include "aurelion_rules/port/creature_dwelling_rules.hpp"

#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// `d.get(field, {}) if d.get(field, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) && gd::is_dict(found) ? found.ref : state.new_dict();
}

} // namespace

namespace creature_dwelling_rules {

void record_guard_result(State &state, DictRef node, Atom side, ArrayRef survivor_stacks, bool won, int64_t day) {
	const DictRef survivors = dict_field_or_new(state, node, key::dwelling_guard_survivors);
	if (won) {
		const DictRef beaten = dict_field_or_new(state, node, key::dwelling_guard_beaten);
		state.set(beaten, str(side), int_value(day));
		state.set(node, str(key::dwelling_guard_beaten), dict_value(beaten));
		state.erase(survivors, str(side));
	} else {
		const DictRef record = state.new_dict();
		state.set(record, str(key::week), int_value(week_index(state, day)));
		state.set(record, str(key::stacks), array_value(gd::deep_duplicate_array(state, survivor_stacks)));
		state.set(survivors, str(side), dict_value(record));
	}
	if (gd::is_empty(state, survivors)) {
		state.erase(node, str(key::dwelling_guard_survivors));
	} else {
		state.set(node, str(key::dwelling_guard_survivors), dict_value(survivors));
	}
}

} // namespace creature_dwelling_rules

} // namespace aurelion::rules::port
