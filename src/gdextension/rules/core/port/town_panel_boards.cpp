// TownBuildingPanel and TownConstructionBoard for the town screen (Phase 7,
// slice 7.8): the guild and market buildings and the board's slots.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
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

// value.get(field, []) of an untyped value, read only: false when the field is
// missing (the empty Array), else the field's value. A value that is no
// Dictionary has no get() (a ScriptError, as in GDScript).
bool lookup_untyped(State &state, const Value &value, Atom field, Value &out) {
	if (!gd::is_dict(value)) {
		out = ai::vget(state, value, field);
		return true;
	}
	return state.lookup(value.ref, str(field), out);
}

} // namespace

namespace town_building_panel {

Atom market_building_id(State &state, DictRef town) {
	if (gd::is_empty(state, town)) {
		return key::empty;
	}
	return string_of(state, state.get(overworld_rules::town_market_state(state, town), str(key::building_id), str(key::empty)));
}

Atom guild_building_id(State &state, DictRef town) {
	Atom best_id = key::empty;
	int64_t best_tier = 0;
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, string_of(state, building_id_value));
		if (gd::int_field(state, building, key::spell_tier, 0) > best_tier) {
			best_tier = gd::int_field(state, building, key::spell_tier, 0);
			best_id = string_of(state, building_id_value);
		}
	}
	return best_id;
}

} // namespace town_building_panel

namespace town_construction_board {

DictRef slot_by_id(State &state, DictRef board, Atom slot_id) {
	for (const Value &row : gd::field_items(state, board, str(key::rows))) {
		Value slots;
		if (!lookup_untyped(state, row, key::slots, slots)) {
			continue;
		}
		for (const Value &slot : gd::items(state, slots)) {
			if (string_of(state, ai::vget(state, slot, key::id, str(key::empty))) == slot_id) {
				return gd::as_dict(slot);
			}
		}
	}
	return state.new_dict();
}

ArrayRef ordered_slots(State &state, DictRef board) {
	const ArrayRef slots = state.new_array();
	for (const Value &row : gd::field_items(state, board, str(key::rows))) {
		Value row_slots;
		if (!lookup_untyped(state, row, key::slots, row_slots)) {
			continue;
		}
		ai::append_array(state, slots, gd::as_array(row_slots));
	}
	return slots;
}

} // namespace town_construction_board

} // namespace aurelion::rules::port
