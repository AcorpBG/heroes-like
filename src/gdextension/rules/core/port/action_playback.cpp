// Slice 10: BattleActionPlayback.capture, the render snapshot of one event of a
// presented action, taken only while the battle holds the capture key.

#include "aurelion_rules/port/battle_action_playback.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"

namespace aurelion::rules::port::battle_action_playback {

using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// key in [CAPTURE_KEY, "battle_animation_events", "stack_animation_states"]:
// Array.has, where a String or StringName of the text matches and nothing else
// matches a String.
bool skipped_key(const Value &field) {
	return field.is_string_like()
			&& (field.ref == key::_live_action_playback_capture
					|| field.ref == key::battle_animation_events
					|| field.ref == key::stack_animation_states);
}

} // namespace

void capture(State &state, DictRef battle, DictRef event) {
	if (!state.has(battle, str(key::_live_action_playback_capture))) {
		return;
	}
	const ArrayRef frames = gd::as_array(gd::index(state, battle, str(key::_live_action_playback_capture)));
	// previous_frame is {} without a frame: every read of it misses, so it is
	// not made.
	const bool has_previous = state.array_size(frames) != 0;
	const DictRef previous_frame = has_previous ? gd::as_dict(state.at(frames, -1)) : 0;
	const DictRef snapshot = state.new_dict();
	for (const Value &field : gd::items(state, dict_value(battle))) {
		if (skipped_key(field)) {
			continue;
		}
		const Value value = gd::index(state, battle, field);
		if (value.kind == Kind::Dict || value.kind == Kind::Array) {
			const Value previous_value = has_previous ? state.get(previous_frame, field, Value()) : Value();
			// typeof(previous_value) == typeof(value): only a Dictionary has
			// TYPE_DICTIONARY and only an Array TYPE_ARRAY. An unchanged value
			// is the previous frame's very container.
			const bool unchanged = previous_value.kind == value.kind && gd::equal(state, previous_value, value);
			state.set(snapshot, field, unchanged ? previous_value : gd::duplicate_value(state, value, true));
		} else {
			state.set(snapshot, field, value);
		}
	}
	const DictRef record = gd::deep_duplicate_dict(state, event);
	// The damage of a hit inferred from the previous frame, when the event
	// does not carry it.
	if (!state.has(record, str(key::damage)) && has_previous) {
		const Atom event_id = string_or_empty(state, record, key::event_id);
		if (event_id == key::battle_unit_hit || event_id == key::battle_unit_death) {
			for (const Value &previous : gd::field_items(state, previous_frame, str(key::stacks))) {
				const Atom previous_id = gd::to_string(ai::vget(state, previous, key::battle_id, str(key::empty)));
				if (previous_id != string_or_empty(state, record, key::battle_id)) {
					continue;
				}
				for (const Value &current : gd::field_items(state, snapshot, str(key::stacks))) {
					const Value current_id = ai::vget(state, current, key::battle_id);
					if (!gd::equal(state, current_id, ai::vget(state, previous, key::battle_id))) {
						continue;
					}
					const int64_t health_before = gd::to_int(state, ai::vget(state, previous, key::total_health, int_value(0)));
					const int64_t health_after = gd::to_int(state, ai::vget(state, current, key::total_health, int_value(0)));
					state.set(record, str(key::damage), int_value(engine_max<int64_t>(0, gd::sub(health_before, health_after))));
					const int64_t hp = engine_max<int64_t>(1, gd::to_int(state, ai::vget(state, current, key::unit_hp, int_value(1))));
					const double total_before = gd::to_float(ai::vget(state, previous, key::total_health, int_value(0)));
					const int64_t units_before = compat::float_to_int(compat::godot_ceil(total_before / static_cast<double>(hp)));
					const double total_after = gd::to_float(ai::vget(state, current, key::total_health, int_value(0)));
					const int64_t units_after = compat::float_to_int(compat::godot_ceil(total_after / static_cast<double>(hp)));
					state.set(record, str(key::casualties), int_value(engine_max<int64_t>(0, gd::sub(units_before, units_after))));
				}
			}
		}
	}
	state.set(record, str(key::serial), int_value(gd::add(1000000, state.array_size(frames))));
	state.set(snapshot, str(key::playback_event), dict_value(record));
	// The two queues the loop skips, each with this one event.
	const ArrayRef events = state.new_array();
	state.append(events, dict_value(record));
	state.set(snapshot, str(key::battle_animation_events), array_value(events));
	const DictRef animation_states = state.new_dict();
	state.set(animation_states, str(string_or_empty(state, record, key::battle_id)), dict_value(record));
	state.set(snapshot, str(key::stack_animation_states), dict_value(animation_states));
	const Atom source_id = string_or_empty(state, record, key::source_battle_id);
	const Atom actor_id = source_id != key::empty ? source_id : string_or_empty(state, record, key::battle_id);
	// A hero's cast ("hero:<side>") is not a stack: the active stack stays lit.
	if (!gd::begins_with(state, actor_id, key::hero_actor_prefix)) {
		state.set(snapshot, str(key::active_stack_id), str(actor_id));
	}
	state.set(snapshot, str(key::selected_target_id), str(string_or_empty(state, record, key::target_battle_id)));
	state.append(frames, dict_value(snapshot));
}

} // namespace aurelion::rules::port::battle_action_playback
