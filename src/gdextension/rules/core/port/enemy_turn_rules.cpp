// EnemyTurnRules: a computer faction's towns.

#include "aurelion_rules/port/enemy_turn_rules.hpp"

#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port::enemy_turn_rules {

namespace {

using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Value;
namespace key = state::key;

} // namespace

ArrayRef _owned_town_entries(State &state, DictRef session, Atom faction_id) {
	const ArrayRef entries = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	// towns.size() and towns[index] of an untyped value: an Array here.
	const ArrayRef towns = gd::as_array(state.get(overworld, str(key::towns), gd::array_value(state.new_array())));
	for (int64_t index = 0; index < state.array_size(towns); ++index) {
		const Value town = state.at(towns, index);
		if (!gd::is_dict(town)) {
			continue;
		}
		if (gd::stringify_or_fallback(state, state.get(town.ref, str(key::owner), str(key::neutral))) != key::enemy) {
			continue;
		}
		if (_town_controller_faction_id(state, town.ref) != faction_id) {
			continue;
		}
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::index), int_value(index));
		state.set(entry, str(key::town), town);
		state.append(entries, dict_value(entry));
	}
	return entries;
}

Atom _town_controller_faction_id(State &state, DictRef town_state) {
	return player_identity_rules::town_controller_id(state, town_state);
}

} // namespace aurelion::rules::port::enemy_turn_rules
