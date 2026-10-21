// Layer 4: presentation: the animation states and events and the presentation event queue.

#include "aurelion_rules/port/battle_rules.hpp"

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// ANIMATION_EVENT_QUEUE_LIMIT and PRESENTATION_EVENT_QUEUE_LIMIT.
constexpr int64_t ANIMATION_EVENT_QUEUE_LIMIT = 24;
constexpr int64_t PRESENTATION_EVENT_QUEUE_LIMIT = 48;

// ANIMATION_STATE_BY_EVENT.get(event_id): true with the state when the const
// Dictionary has the key. Equal texts share one atom, so the key's atom is the
// whole lookup.
bool animation_state_by_event(Atom event_id, Atom &found) {
	switch (event_id) {
		case key::battle_unit_move:
			found = key::move_path_step;
			return true;
		case key::battle_unit_melee_attack:
			found = key::melee_windup_release;
			return true;
		case key::battle_unit_ranged_attack:
			found = key::ranged_aim_release;
			return true;
		case key::battle_unit_hit:
			found = key::hit_stagger;
			return true;
		case key::battle_unit_death:
			found = key::death_rout_remove;
			return true;
		case key::battle_unit_cast:
			found = key::cast_support_anchor;
			return true;
		case key::battle_status_applied:
			found = key::status_applied;
			return true;
		case key::battle_status_expired:
			found = key::status_expired;
			return true;
		case key::battle_unit_defend:
			found = key::defend_brace;
			return true;
		case key::battle_unit_wait:
			found = key::wait_hold;
			return true;
		case key::battle_retaliation:
			found = key::retaliation_release;
			return true;
		case key::battle_unit_retreat:
			found = key::retreat_withdraw_column;
			return true;
		case key::battle_unit_surrender:
			found = key::surrender_stand_down;
			return true;
		default:
			return false;
	}
}

// ANIMATION_STATE_PRIORITY.get(state): true with the priority (an int) when
// the const Dictionary has the key.
bool animation_state_priority(Atom state_id, int64_t &found) {
	switch (state_id) {
		case key::death_rout_remove:
			found = 100;
			return true;
		case key::retreat_withdraw_column:
			found = 95;
			return true;
		case key::surrender_stand_down:
			found = 95;
			return true;
		case key::retaliation_release:
			found = 86;
			return true;
		case key::status_expired:
			found = 85;
			return true;
		case key::status_applied:
			found = 84;
			return true;
		case key::hit_stagger:
			found = 80;
			return true;
		case key::melee_windup_release:
			found = 60;
			return true;
		case key::ranged_aim_release:
			found = 60;
			return true;
		case key::cast_support_anchor:
			found = 60;
			return true;
		case key::move_path_step:
			found = 58;
			return true;
		case key::defend_brace:
			found = 55;
			return true;
		case key::wait_hold:
			found = 54;
			return true;
		default:
			return false;
	}
}

// ANIMATION_STATE_PRIORITY.get(state, fallback) as a Value (the stored ints,
// or the fallback as it is).
Value animation_state_priority_or(Atom state_id, const Value &fallback) {
	int64_t priority = 0;
	return animation_state_priority(state_id, priority) ? int_value(priority) : fallback;
}

// var x: Dictionary = d.get(k, {}) if d.get(k, {}) is Dictionary else {}: the
// stored Dictionary, else a new empty one (a missing key's default {} is new
// too, as is the else branch's {}).
DictRef stored_dict_or_new(State &state, DictRef dict, const Value &field) {
	Value found;
	if (state.lookup(dict, field, found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// BattleActionPlayback.capture(battle, event): it returns at once without
// CAPTURE_KEY ("_live_action_playback_capture") in the battle; the capture
// itself goes with slice 10.
void action_playback_capture(State &state, DictRef battle) {
	if (state.has(battle, str(key::_live_action_playback_capture))) {
		throw state::ScriptError("BattleActionPlayback.capture is not ported (slice 10)");
	}
}

} // namespace

void _mark_stack_animation_event(State &state, DictRef battle, Atom battle_id, Atom event_id, DictRef context) {
	if (gd::is_empty(state, battle) || battle_id == key::empty) {
		return;
	}
	Atom mapped_state = key::empty;
	if (!animation_state_by_event(event_id, mapped_state)) {
		mapped_state = key::empty;
	}
	const Atom animation_state = gd::strip_edges(state, mapped_state);
	if (animation_state == key::empty) {
		return;
	}
	const DictRef event_states = stored_dict_or_new(state, battle, str(key::stack_animation_states));
	const DictRef existing = stored_dict_or_new(state, event_states, str(battle_id));
	const Atom existing_state = gd::strip_edges(state, gd::string_field(state, existing, key::state, key::empty));
	const int64_t existing_priority = gd::to_int(state, animation_state_priority_or(existing_state, int_value(0)));
	const int64_t priority = gd::to_int(state, animation_state_priority_or(animation_state, int_value(1)));
	const int64_t serial = gd::add(gd::int_field(state, battle, key::animation_event_serial, 0), 1);
	// The literal's entries in its order.
	const DictRef record = state.new_dict();
	state.set(record, str(key::event_id), str(event_id));
	state.set(record, str(key::state), str(animation_state));
	state.set(record, str(key::battle_id), str(battle_id));
	state.set(record, str(key::target_battle_id), str(gd::string_field(state, context, key::target_battle_id, key::empty)));
	state.set(record, str(key::source_battle_id), str(gd::string_field(state, context, key::source_battle_id, key::empty)));
	state.set(record, str(key::from_q), int_value(gd::int_field(state, context, key::from_q, -1)));
	state.set(record, str(key::from_r), int_value(gd::int_field(state, context, key::from_r, -1)));
	state.set(record, str(key::to_q), int_value(gd::int_field(state, context, key::to_q, -1)));
	state.set(record, str(key::to_r), int_value(gd::int_field(state, context, key::to_r, -1)));
	state.set(record, str(key::spell_id), str(gd::string_field(state, context, key::spell_id, key::empty)));
	state.set(record, str(key::resolution_type), str(gd::string_field(state, context, key::resolution_type, key::empty)));
	state.set(record, str(key::priority), int_value(priority));
	state.set(record, str(key::serial), int_value(serial));
	state.set(record, str(key::round), int_value(gd::int_field(state, battle, key::round, 1)));
	state.set(record, str(key::turn_index), int_value(gd::int_field(state, battle, key::turn_index, 0)));
	if (event_id != key::battle_unit_move) {
		if (state.has(context, str(key::_playback_applied_damage))) {
			// The playback-only copy (record.duplicate() with "damage" and
			// "casualties") goes nowhere but into the capture, which is not
			// ported: only its int() conversions, which can stop the script,
			// are kept, in their order.
			static_cast<void>(gd::int_field(state, context, key::_playback_applied_damage, 0));
			static_cast<void>(gd::int_field(state, context, key::_playback_applied_casualties, 0));
		}
		action_playback_capture(state, battle);
	}
	if (existing_state != key::empty && existing_priority > priority) {
		return;
	}
	state.set(battle, str(key::animation_event_serial), int_value(serial));
	state.set(event_states, str(battle_id), dict_value(gd::deep_duplicate_dict(state, record)));
	state.set(battle, str(key::stack_animation_states), dict_value(event_states));
	_append_animation_event_record(state, battle, record);
}

void _append_animation_event_record(State &state, DictRef battle, DictRef record) {
	Value queue;
	if (!state.lookup(battle, str(key::battle_animation_events), queue)) {
		queue = array_value(state.new_array()); // the default []
	}
	const ArrayRef events = _normalize_animation_event_queue(state, queue);
	state.append(events, dict_value(gd::deep_duplicate_dict(state, record)));
	while (state.array_size(events) > ANIMATION_EVENT_QUEUE_LIMIT) {
		gd::pop_front(state, events);
	}
	state.set(battle, str(key::battle_animation_events), array_value(events));
}

void _append_presentation_event(State &state, DictRef battle, Atom event_type, Atom visible_text, DictRef context) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	const Atom text = gd::strip_edges(state, visible_text);
	if (gd::strip_edges(state, event_type) == key::empty || text == key::empty) {
		return;
	}
	const Atom actor_id = gd::string_field(state, context, key::actor_battle_id, key::empty);
	const Atom target_id = gd::string_field(state, context, key::target_battle_id, key::empty);
	const DictRef actor = _get_stack_by_id(state, battle, actor_id);
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	const Atom spell_id = gd::strip_edges(state, gd::string_field(state, context, key::spell_id, key::empty));
	Atom spell_name = gd::strip_edges(state, gd::string_field(state, context, key::spell_name, key::empty));
	if (spell_id != key::empty && spell_name == key::empty) {
		const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
		spell_name = gd::to_string(gd::field_or(state, spell, key::name, str(spell_id)));
	}
	const int64_t serial = gd::add(gd::int_field(state, battle, key::battle_presentation_event_serial, 0), 1);
	state.set(battle, str(key::battle_presentation_event_serial), int_value(serial));
	// The literal's entries in its order; each get's fallback is evaluated
	// before the get.
	const DictRef record = state.new_dict();
	state.set(record, str(key::serial), int_value(serial));
	state.set(record, str(key::event_type), str(event_type));
	state.set(record, str(key::action_id), str(gd::string_field(state, context, key::action_id, key::empty)));
	state.set(record, str(key::visible_text), str(text));
	state.set(record, str(key::detail_text), str(gd::string_field(state, context, key::detail_text, key::empty)));
	{
		const Value actor_side = gd::field_or(state, actor, key::side, str(key::empty));
		state.set(record, str(key::side), str(gd::to_string(gd::field_or(state, context, key::side, actor_side))));
	}
	state.set(record, str(key::actor_battle_id), str(actor_id));
	{
		const Atom actor_label = !gd::is_empty(state, actor) ? _stack_label(state, actor) : static_cast<Atom>(key::empty);
		state.set(record, str(key::actor_name), str(gd::string_field(state, context, key::actor_name, actor_label)));
	}
	state.set(record, str(key::target_battle_id), str(target_id));
	{
		const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::empty);
		state.set(record, str(key::target_name), str(gd::string_field(state, context, key::target_name, target_label)));
	}
	state.set(record, str(key::damage), int_value(engine_max<int64_t>(0, gd::int_field(state, context, key::damage, 0))));
	state.set(record, str(key::healing), int_value(engine_max<int64_t>(0, gd::int_field(state, context, key::healing, 0))));
	state.set(record, str(key::units_lost), int_value(engine_max<int64_t>(0, gd::int_field(state, context, key::units_lost, 0))));
	state.set(record, str(key::prevented_damage), int_value(engine_max<int64_t>(0, gd::int_field(state, context, key::prevented_damage, 0))));
	state.set(record, str(key::resisted), gd::bool_value(gd::bool_field(state, context, key::resisted, false)));
	state.set(record, str(key::immune), gd::bool_value(gd::bool_field(state, context, key::immune, false)));
	state.set(record, str(key::spell_id), str(spell_id));
	state.set(record, str(key::spell_name), str(spell_name));
	state.set(record, str(key::round), int_value(gd::int_field(state, battle, key::round, 1)));
	state.set(record, str(key::turn_index), int_value(gd::int_field(state, battle, key::turn_index, 0)));
	{
		const Value battle_serial = gd::field_or(state, battle, key::animation_event_serial, int_value(0));
		const int64_t animation_serial = gd::to_int(state, gd::field_or(state, context, key::animation_serial, battle_serial));
		state.set(record, str(key::animation_serial), int_value(engine_max<int64_t>(0, animation_serial)));
	}
	if (state.has(context, str(key::cleansed_effect_count))) {
		state.set(record, str(key::cleansed_effect_count), int_value(engine_max<int64_t>(0, gd::int_field(state, context, key::cleansed_effect_count, 0))));
	}
	Value queue;
	if (!state.lookup(battle, str(key::battle_presentation_events), queue)) {
		queue = array_value(state.new_array()); // the default []
	}
	// _presentation_queue_written, the queue this function wrote last: its
	// entries are normalized already, so only the last one is again.
	ArrayRef events;
	if (gd::is_array(queue) && state.array_size(queue.ref) > 0
			&& gd::is_same(state, queue, gd::static_var(state, key::battle_rules_script, key::_presentation_queue_written))) {
		const int64_t size = state.array_size(queue.ref);
		events = gd::slice(state, queue.ref, 0, size - 1);
		const ArrayRef last = state.new_array();
		state.append(last, state.at(queue.ref, size - 1));
		const ArrayRef normalized = _normalize_presentation_event_queue(state, array_value(last));
		for (const Value &entry : gd::items(state, array_value(normalized))) {
			state.append(events, entry);
		}
	} else {
		events = _normalize_presentation_event_queue(state, queue);
	}
	state.append(events, dict_value(record));
	while (state.array_size(events) > PRESENTATION_EVENT_QUEUE_LIMIT) {
		gd::pop_front(state, events);
	}
	state.set(battle, str(key::battle_presentation_events), array_value(events));
	gd::set_static_var(state, key::battle_rules_script, key::_presentation_queue_written, array_value(events));
}

ArrayRef _normalize_presentation_event_queue(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &entry_value : gd::items(state, value)) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const DictRef entry = entry_value.ref;
		const Atom event_type = gd::strip_edges(state, gd::string_field(state, entry, key::event_type, key::empty));
		const Value text_fallback = gd::field_or(state, entry, key::text, str(key::empty));
		const Atom text = gd::strip_edges(state, gd::to_string(gd::field_or(state, entry, key::visible_text, text_fallback)));
		if (event_type == key::empty || text == key::empty) {
			continue;
		}
		// The literal's entries in its order.
		const DictRef normalized_entry = state.new_dict();
		state.set(normalized_entry, str(key::serial), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::serial, 0))));
		state.set(normalized_entry, str(key::event_type), str(event_type));
		state.set(normalized_entry, str(key::action_id), str(gd::string_field(state, entry, key::action_id, key::empty)));
		state.set(normalized_entry, str(key::visible_text), str(text));
		state.set(normalized_entry, str(key::detail_text), str(gd::string_field(state, entry, key::detail_text, key::empty)));
		state.set(normalized_entry, str(key::side), str(gd::string_field(state, entry, key::side, key::empty)));
		state.set(normalized_entry, str(key::actor_battle_id), str(gd::string_field(state, entry, key::actor_battle_id, key::empty)));
		state.set(normalized_entry, str(key::actor_name), str(gd::string_field(state, entry, key::actor_name, key::empty)));
		state.set(normalized_entry, str(key::target_battle_id), str(gd::string_field(state, entry, key::target_battle_id, key::empty)));
		state.set(normalized_entry, str(key::target_name), str(gd::string_field(state, entry, key::target_name, key::empty)));
		state.set(normalized_entry, str(key::damage), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::damage, 0))));
		state.set(normalized_entry, str(key::healing), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::healing, 0))));
		state.set(normalized_entry, str(key::units_lost), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::units_lost, 0))));
		state.set(normalized_entry, str(key::prevented_damage), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::prevented_damage, 0))));
		state.set(normalized_entry, str(key::resisted), gd::bool_value(gd::bool_field(state, entry, key::resisted, false)));
		state.set(normalized_entry, str(key::immune), gd::bool_value(gd::bool_field(state, entry, key::immune, false)));
		state.set(normalized_entry, str(key::spell_id), str(gd::string_field(state, entry, key::spell_id, key::empty)));
		state.set(normalized_entry, str(key::spell_name), str(gd::string_field(state, entry, key::spell_name, key::empty)));
		state.set(normalized_entry, str(key::round), int_value(engine_max<int64_t>(1, gd::int_field(state, entry, key::round, 1))));
		state.set(normalized_entry, str(key::turn_index), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::turn_index, 0))));
		state.set(normalized_entry, str(key::animation_serial), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::animation_serial, 0))));
		if (state.has(entry, str(key::cleansed_effect_count))) {
			state.set(normalized_entry, str(key::cleansed_effect_count), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::cleansed_effect_count, 0))));
		}
		state.append(normalized, dict_value(normalized_entry));
	}
	while (state.array_size(normalized) > PRESENTATION_EVENT_QUEUE_LIMIT) {
		gd::pop_front(state, normalized);
	}
	return normalized;
}

ArrayRef _normalize_animation_event_queue(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &entry_value : gd::items(state, value)) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const DictRef entry = entry_value.ref;
		const Atom battle_id = gd::strip_edges(state, gd::string_field(state, entry, key::battle_id, key::empty));
		const Atom event_id = gd::strip_edges(state, gd::string_field(state, entry, key::event_id, key::empty));
		const Atom animation_state = gd::strip_edges(state, gd::string_field(state, entry, key::state, key::empty));
		if (battle_id == key::empty || event_id == key::empty || animation_state == key::empty) {
			continue;
		}
		// The literal's entries in its order.
		const DictRef normalized_entry = state.new_dict();
		state.set(normalized_entry, str(key::battle_id), str(battle_id));
		state.set(normalized_entry, str(key::event_id), str(event_id));
		state.set(normalized_entry, str(key::state), str(animation_state));
		state.set(normalized_entry, str(key::target_battle_id), str(gd::string_field(state, entry, key::target_battle_id, key::empty)));
		state.set(normalized_entry, str(key::source_battle_id), str(gd::string_field(state, entry, key::source_battle_id, key::empty)));
		state.set(normalized_entry, str(key::from_q), int_value(gd::int_field(state, entry, key::from_q, -1)));
		state.set(normalized_entry, str(key::from_r), int_value(gd::int_field(state, entry, key::from_r, -1)));
		state.set(normalized_entry, str(key::to_q), int_value(gd::int_field(state, entry, key::to_q, -1)));
		state.set(normalized_entry, str(key::to_r), int_value(gd::int_field(state, entry, key::to_r, -1)));
		state.set(normalized_entry, str(key::spell_id), str(gd::string_field(state, entry, key::spell_id, key::empty)));
		state.set(normalized_entry, str(key::resolution_type), str(gd::string_field(state, entry, key::resolution_type, key::empty)));
		{
			const Value priority_fallback = animation_state_priority_or(animation_state, int_value(1));
			state.set(normalized_entry, str(key::priority), int_value(gd::to_int(state, gd::field_or(state, entry, key::priority, priority_fallback))));
		}
		state.set(normalized_entry, str(key::serial), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::serial, 0))));
		state.set(normalized_entry, str(key::round), int_value(engine_max<int64_t>(1, gd::int_field(state, entry, key::round, 1))));
		state.set(normalized_entry, str(key::turn_index), int_value(engine_max<int64_t>(0, gd::int_field(state, entry, key::turn_index, 0))));
		state.append(normalized, dict_value(normalized_entry));
	}
	while (state.array_size(normalized) > ANIMATION_EVENT_QUEUE_LIMIT) {
		gd::pop_front(state, normalized);
	}
	return normalized;
}

} // namespace aurelion::rules::port::battle_rules
