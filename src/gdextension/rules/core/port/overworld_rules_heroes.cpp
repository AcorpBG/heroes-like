// OverworldRules for the human seat's hero actions on the map (Phase 7, slice
// 7.5): the artifact action, rendezvous and switching heroes.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <initializer_list>
#include <string>
#include <string_view>
#include <vector>

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

// String(d.get(field, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) of a value that may be stored: the field, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// text.split(":"): every piece between the colons, empty ones too.
std::vector<Atom> split_colons(State &state, Atom text) {
	const std::string source = state.text(text);
	std::vector<Atom> parts;
	size_t from = 0;
	while (true) {
		const size_t end = source.find(':', from);
		if (end == std::string::npos) {
			parts.push_back(state.intern(std::string_view(source).substr(from)));
			break;
		}
		parts.push_back(state.intern(std::string_view(source).substr(from, end - from)));
		from = end + 1;
	}
	return parts;
}

// A new Array of the field names: the literal result_keys the GDScript passes.
ArrayRef key_array(State &state, std::initializer_list<Atom> names) {
	const ArrayRef keys = state.new_array();
	for (const Atom name : names) {
		state.append(keys, str(name));
	}
	return keys;
}

// for key in [...]: if result.has(key): finalized[key] = result.get(key)
void copy_present_keys(State &state, DictRef finalized, DictRef result, std::initializer_list<Atom> names) {
	for (const Atom name : names) {
		if (state.has(result, str(name))) {
			state.set(finalized, str(name), state.get(result, str(name), Value()));
		}
	}
}

} // namespace

namespace overworld_rules {

DictRef perform_artifact_action(State &state, DictRef session, Atom action_id) {
	normalize_overworld_state(state, session);
	const DictRef previous_hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const int64_t previous_max = _movement_max_from_hero(state, previous_hero, dict_value(session));
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const DictRef result = artifact_rules::perform_management_action(state, hero, action_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, string_of_field(state, result, key::message, key::unable_to_manage_artifact));
	}

	const Value fallback = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	state.set(session_view::overworld(state, session), str(key::hero), state.get(result, str(key::hero), fallback));
	_sync_movement_to_hero(state, session, previous_max);
	return _finalize_action_result(state, session, true, string_of_field(state, result, key::message, key::empty), true, false, state.new_dict());
}

DictRef perform_rendezvous_transfer_action(State &state, DictRef session, Atom action_id) {
	normalize_overworld_state_for_runtime(state, session);
	const std::vector<Atom> parts = split_colons(state, action_id);
	if (parts.size() != 5 || parts[0] != key::field_transfer) {
		return refusal(state, key::that_field_transfer_order_is_invalid);
	}
	const DictRef result = hero_command_rules::transfer_field_stack(state, session, parts[1], parts[2], parts[3], parts[4]);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const DictRef finalized = _finalize_action_result(state, session, true, string_of_field(state, result, key::message, key::troops_transferred), false, false, state.new_dict());
	copy_present_keys(state, finalized, result, {key::source_hero_id, key::target_hero_id, key::unit_id, key::transferred_count});
	return finalized;
}

DictRef perform_rendezvous_action(State &state, DictRef session, Atom action_id) {
	if (gd::begins_with(state, action_id, key::field_transfer_2)) {
		return perform_rendezvous_transfer_action(state, session, action_id);
	}
	// Hero meeting screen orders (HeroCommandRules.field_*_action_id).
	if (gd::begins_with(state, action_id, key::field_slot)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 6 || !gd::is_valid_int(state, parts[2]) || !gd::is_valid_int(state, parts[4])) {
			return refusal(state, key::that_army_slot_order_is_invalid);
		}
		const int64_t source_slot_index = gd::to_int(state, str(parts[2]));
		const int64_t target_slot_index = gd::to_int(state, str(parts[4]));
		const DictRef result = hero_command_rules::manage_army_slots(state, session, state.new_dict(), parts[1], source_slot_index, parts[3], target_slot_index, parts[5]);
		const ArrayRef result_keys = key_array(state, {
			key::operation,
			key::source_holder_id,
			key::source_slot_index,
			key::target_holder_id,
			key::target_slot_index,
			key::unit_id,
			key::moved_count,
		});
		return _finalize_rendezvous_exchange(state, session, result, key::troops_rearranged, result_keys);
	}
	if (gd::begins_with(state, action_id, key::field_troops_all)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 3) {
			return refusal(state, key::that_troop_order_is_invalid);
		}
		const DictRef result = hero_command_rules::move_all_field_troops(state, session, parts[1], parts[2]);
		const ArrayRef result_keys = key_array(state, {key::source_hero_id, key::target_hero_id, key::moved_count, key::kept_unit_id});
		return _finalize_rendezvous_exchange(state, session, result, key::troops_transferred, result_keys);
	}
	if (gd::begins_with(state, action_id, key::field_artifact_place)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 5) {
			return refusal(state, key::that_artifact_handoff_order_is_invalid);
		}
		const DictRef result = hero_command_rules::place_field_artifact(state, session, parts[1], parts[2], parts[3], parts[4]);
		const ArrayRef result_keys = key_array(state, {
			key::source_hero_id,
			key::target_hero_id,
			key::artifact_id,
			key::source_previous_location,
			key::source_previous_slot,
			key::target_location,
			key::target_slot,
			key::auto_equipped,
			key::displaced_artifact_id,
		});
		return _finalize_rendezvous_exchange(state, session, result, key::artifact_transferred, result_keys);
	}
	if (gd::begins_with(state, action_id, key::field_artifacts_all)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 3) {
			return refusal(state, key::that_artifact_handoff_order_is_invalid);
		}
		const DictRef result = hero_command_rules::move_all_field_artifacts(state, session, parts[1], parts[2]);
		const ArrayRef result_keys = key_array(state, {key::source_hero_id, key::target_hero_id, key::moved_artifact_ids, key::kept_artifact_ids});
		return _finalize_rendezvous_exchange(state, session, result, key::artifacts_transferred, result_keys);
	}
	if (gd::begins_with(state, action_id, key::field_artifact_transfer)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 4) {
			return refusal(state, key::that_artifact_handoff_order_is_invalid);
		}
		const DictRef result = hero_command_rules::transfer_field_artifact(state, session, parts[1], parts[2], parts[3]);
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		const DictRef finalized = _finalize_action_result(state, session, true, string_of_field(state, result, key::message, key::artifact_transferred), false, false, state.new_dict());
		copy_present_keys(state, finalized, result, {
			key::source_hero_id,
			key::target_hero_id,
			key::artifact_id,
			key::source_previous_location,
			key::source_previous_slot,
			key::target_location,
			key::target_slot,
			key::auto_equipped,
		});
		return finalized;
	}
	if (gd::begins_with(state, action_id, key::field_spell_share)) {
		normalize_overworld_state_for_runtime(state, session);
		const std::vector<Atom> parts = split_colons(state, action_id);
		if (parts.size() != 4) {
			return refusal(state, key::that_spell_teaching_order_is_invalid);
		}
		const DictRef result = hero_command_rules::teach_field_spell(state, session, parts[1], parts[2], parts[3]);
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		const DictRef finalized = _finalize_action_result(state, session, true, string_of_field(state, result, key::message, key::spell_taught), false, false, state.new_dict());
		copy_present_keys(state, finalized, result, {key::source_hero_id, key::target_hero_id, key::spell_id});
		return finalized;
	}
	return refusal(state, key::that_rendezvous_order_is_invalid);
}

DictRef _finalize_rendezvous_exchange(State &state, DictRef session, DictRef result, Atom fallback_message, ArrayRef result_keys) {
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const DictRef finalized = _finalize_action_result(state, session, true, string_of_field(state, result, key::message, fallback_message), false, false, state.new_dict());
	for (const Value &result_key : gd::items(state, array_value(result_keys))) {
		if (state.has(result, result_key)) {
			state.set(finalized, result_key, state.get(result, result_key, Value()));
		}
	}
	return finalized;
}

ArrayRef get_artifact_actions(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	return artifact_rules::get_management_actions(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
}

ArrayRef get_hero_actions(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	return hero_command_rules::get_overworld_switch_actions(state, session);
}

DictRef switch_active_hero(State &state, DictRef session, Atom hero_id) {
	normalize_overworld_state(state, session);
	const DictRef result = hero_command_rules::set_active_hero(state, session, hero_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, string_of_field(state, result, key::message, key::unable_to_change_command));
	}
	return _finalize_action_result(state, session, true, string_of_field(state, result, key::message, key::empty), true, false, state.new_dict());
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
