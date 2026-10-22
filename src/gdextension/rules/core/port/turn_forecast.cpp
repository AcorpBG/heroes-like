// Slice 10b: the turn order the battle screen shows: the actors still to come this round, and the forecast of the
// round's rest, the stacks waiting at its end and the next round's order, projected on a copy of the battle.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// a.find(value, from) (Array::find): from is the engine's 32-bit int, and a
// negative one finds nothing.
int64_t array_find_from(const State &state, ArrayRef array, const Value &value, int64_t from) {
	const int64_t first = static_cast<int32_t>(from);
	if (first < 0) {
		return -1;
	}
	const int64_t size = state.array_size(array);
	for (int64_t index = first; index < size; ++index) {
		if (gd::string_like_equal(state, state.at(array, index), value)) {
			return index;
		}
	}
	return -1;
}

// key in [PRESENTATION_EVENT_QUEUE_KEY, ANIMATION_EVENT_QUEUE_KEY,
// STACK_ANIMATION_STATES_KEY, "recent_events", ActionPlayback.CAPTURE_KEY]:
// Array.has matches a String or a StringName of the same text, nothing else.
bool projection_skips_key(const Value &field) {
	if (!field.is_string_like()) {
		return false;
	}
	return field.ref == key::battle_presentation_events || field.ref == key::battle_animation_events
			|| field.ref == key::stack_animation_states || field.ref == key::recent_events
			|| field.ref == key::_live_action_playback_capture;
}

} // namespace

ArrayRef upcoming_actor_ids(State &state, DictRef battle, int64_t limit) {
	const ArrayRef result = state.new_array();
	// battle.get("turn_order", []): a missing key's default is a new empty Array.
	Value order;
	if (!state.lookup(battle, str(key::turn_order), order)) {
		order = array_value(state.new_array());
	}
	if (!gd::is_array(order) || limit <= 0) {
		return result;
	}
	int64_t start = engine_max<int64_t>(0, gd::int_field(state, battle, key::turn_index, 0));
	const Atom active_id = gd::string_field(state, battle, key::active_stack_id, key::empty);
	const int64_t active_index = array_find_from(state, order.ref, str(active_id), start);
	if (active_index >= 0) {
		start = active_index;
	}
	// range(start, order.size()): both bounds evaluated once.
	const int64_t end = state.array_size(order.ref);
	for (int64_t index = start; index < end; ++index) {
		const DictRef stack = _get_stack_by_id(state, battle, gd::to_string(state.at(order.ref, index)));
		if (!gd::is_empty(state, stack) && _alive_count(state, stack) > 0) {
			state.append(result, str(gd::to_string(state.at(order.ref, index))));
			if (state.array_size(result) >= limit) {
				break;
			}
		}
	}
	return result;
}

DictRef turn_order_forecast(State &state, DictRef battle) {
	// The literal's entries in its order.
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef current = state.new_array();
	const ArrayRef waiting = state.new_array();
	const DictRef forecast = state.new_dict();
	state.set(forecast, str(key::round), int_value(round));
	state.set(forecast, str(key::current), array_value(current));
	state.set(forecast, str(key::waiting), array_value(waiting));
	state.set(forecast, str(key::next_round), array_value(state.new_array()));
	// The stored Array, else []: only read below, so anything else is an empty one.
	Value turn_order;
	const bool has_turn_order = state.lookup(battle, str(key::turn_order), turn_order) && gd::is_array(turn_order);
	if (gd::is_empty(state, battle) || !has_turn_order || state.array_size(turn_order.ref) == 0) {
		return forecast;
	}
	const Atom active_id = gd::string_field(state, battle, key::active_stack_id, key::empty);
	int64_t start = gd::array_find(state, turn_order.ref, str(active_id));
	if (start < 0) {
		start = engine_clamp<int64_t>(gd::int_field(state, battle, key::turn_index, 0), 0, state.array_size(turn_order.ref));
	}
	const ArrayRef waited = waited_stack_ids(state, battle);
	const ArrayRef still_to_act = state.new_array();
	const int64_t end = state.array_size(turn_order.ref);
	for (int64_t index = start; index < end; ++index) {
		const Atom battle_id = gd::to_string(state.at(turn_order.ref, index));
		if (_alive_count(state, _get_stack_by_id(state, battle, battle_id)) <= 0) {
			continue;
		}
		state.append(still_to_act, str(battle_id));
		// forecast["waiting"] and forecast["current"] are the literal's own Arrays.
		if (battle_id != active_id && gd::array_has(state, waited, str(battle_id))) {
			state.append(waiting, str(battle_id));
		} else {
			state.append(current, str(battle_id));
		}
	}
	state.set(forecast, str(key::next_round), array_value(_projected_next_round_order(state, battle, still_to_act)));
	return forecast;
}

ArrayRef _projected_next_round_order(State &state, DictRef battle, ArrayRef still_to_act) {
	DictRef projection = state.new_dict();
	// battle.keys() is a new Array the loop does not change.
	const ArrayRef battle_keys = gd::keys(state, battle);
	for (const Value &field : gd::items(state, array_value(battle_keys))) {
		if (projection_skips_key(field)) {
			continue;
		}
		state.set(projection, field, gd::index(state, battle, field));
	}
	projection = gd::deep_duplicate_dict(state, projection);
	// for battle_id in still_to_act: read live, as GDScript's loop reads it.
	for (int64_t index = 0; index < state.array_size(still_to_act); ++index) {
		spend_effect_turns(state, projection, gd::to_string(state.at(still_to_act, index)));
	}
	_prepare_round(state, projection, gd::add(gd::int_field(state, battle, key::round, 1), 1));
	// (order as Array).duplicate() if order is Array else []: a missing key's
	// default [] duplicates to a new empty Array too.
	Value order;
	if (state.lookup(projection, str(key::turn_order), order) && gd::is_array(order)) {
		return gd::duplicate_array(state, order.ref);
	}
	return state.new_array();
}

} // namespace aurelion::rules::port::battle_rules
