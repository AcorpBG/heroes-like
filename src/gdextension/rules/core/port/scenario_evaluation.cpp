// ScenarioRules.evaluate_session: the scenario state normalized (its script
// state, the computer players' states), its script hooks run and its
// objectives checked. Generated maps have no script hooks and one objective,
// defeating every rival, which counts only for a human player. The paths AI
// matches never run are left to GDScript (state::NotPorted): script hooks and
// pending reinforcements (authored scenarios), any other objective type, a
// finished scenario, the rival count of a human game, a script state whose
// hook list is not yet a typed Array[String] (built anew once a session).

#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

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

[[noreturn]] void not_ported(const char *path) {
	throw state::NotPorted(std::string("left to GDScript: ") + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// {"status": status, "message": message}.
DictRef status_result(State &state, Atom status, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::status), str(status));
	state.set(result, str(key::message), str(message));
	return result;
}

// ScenarioScriptRules.EVENT_LOG_LIMIT.
constexpr int64_t kEventLogLimit = 24;

} // namespace

namespace scenario_script_rules {
void normalize_script_state(State &state, DictRef session);
DictRef process_hooks(State &state, DictRef session);
DictRef _retry_pending_reinforcements(State &state, DictRef session);
ArrayRef _sorted_hooks(State &state, const Value &raw_hooks);
Atom _join_messages(State &state, const Value &messages);
} // namespace scenario_script_rules

namespace generated_scenario_objective_rules {
bool uses_kind(State &state, DictRef scenario);
Value definitions(State &state, DictRef scenario);
DictRef progress(State &state, DictRef session);
} // namespace generated_scenario_objective_rules

namespace scenario_rules {
void normalize_scenario_state(State &state, DictRef session, bool normalize_enemies);
DictRef scenario_record_for_session(State &state, DictRef session);
Value objective_definitions(State &state, DictRef scenario);
bool _objective_met(State &state, DictRef session, DictRef objective);
} // namespace scenario_rules

// ScenarioRules.

namespace scenario_rules {

void normalize_scenario_state(State &state, DictRef session, bool normalize_enemies) {
	if (text(state, session, key::scenario_status, key::empty) == key::empty) {
		state.set(session, str(key::scenario_status), str(key::in_progress));
	}
	// An empty summary is set to "" again: nothing changes.
	scenario_script_rules::normalize_script_state(state, session);
	if (normalize_enemies) {
		enemy_turn_rules::normalize_enemy_states(state, session);
	}
}

DictRef evaluate_session(State &state, DictRef session) {
	normalize_scenario_state(state, session, true);
	if (text(state, session, key::scenario_id, key::empty) == key::empty) {
		return status_result(state, key::invalid, key::empty);
	}
	const Atom status = text(state, session, key::scenario_status, key::empty);
	if (status != key::in_progress) {
		return status_result(state, status, text(state, session, key::scenario_summary, key::empty));
	}

	const DictRef scenario = scenario_record_for_session(state, session);
	const DictRef script_result = scenario_script_rules::process_hooks(state, session);
	const Atom script_message = text(state, script_result, key::message, key::empty);
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return status_result(state, key::in_progress, script_message);
	}

	const Value defeat_objectives = state.get(objectives.ref, str(key::defeat), array_value(state.new_array()));
	if (gd::is_array(defeat_objectives)) {
		for (const Value &objective : gd::items(state, defeat_objectives)) {
			if (gd::is_dict(objective) && _objective_met(state, session, objective.ref)) {
				// _complete_session, _resolution_text, _merge_result_messages.
				not_ported("a scenario defeat");
			}
		}
	}

	const Value victory_objectives = state.get(objectives.ref, str(key::victory), array_value(state.new_array()));
	if (gd::is_array(victory_objectives) && state.array_size(victory_objectives.ref) > 0) {
		bool all_met = true;
		for (const Value &objective : gd::items(state, victory_objectives)) {
			if (!gd::is_dict(objective) || !_objective_met(state, session, objective.ref)) {
				all_met = false;
				break;
			}
		}
		if (all_met) {
			// _complete_session, _resolution_text, _merge_result_messages.
			not_ported("a scenario victory");
		}
	}

	return status_result(state, key::in_progress, script_message);
}

DictRef scenario_record_for_session(State &state, DictRef session) {
	const Atom scenario_id = text(state, session, key::scenario_id, key::empty);
	if (scenario_id == key::empty) {
		return state.new_dict();
	}
	const DictRef flags = gd::as_dict(gd::field(state, session, key::flags));
	DictRef runtime_record = dict_field_or_new(state, flags, key::native_random_map_runtime_scenario_record);
	if (!gd::is_empty(state, runtime_record) && text(state, runtime_record, key::id, key::empty) == scenario_id) {
		return runtime_record;
	}
	runtime_record = dict_field_or_new(state, session_view::overworld(state, session), key::native_random_map_runtime_scenario_record);
	if (!gd::is_empty(state, runtime_record) && text(state, runtime_record, key::id, key::empty) == scenario_id) {
		return runtime_record;
	}
	return gd::content_row(state, state::ContentTable::Scenario, scenario_id);
}

Value objective_definitions(State &state, DictRef scenario) {
	return generated_scenario_objective_rules::definitions(state, scenario);
}

bool _objective_met(State &state, DictRef session, DictRef objective) {
	if (text(state, objective, key::type, key::empty) == key::defeat_generated_rivals) {
		return gd::bool_field(state, generated_scenario_objective_rules::progress(state, session), key::complete, false);
	}
	// The authored scenarios' objective types and unknown ones.
	not_ported("an objective other than defeating the generated rivals");
}

} // namespace scenario_rules

// ScenarioScriptRules.

namespace scenario_script_rules {

void normalize_script_state(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value script_state_value = state.get(overworld, str(key::scenario_script_state), dict_value(state.new_dict()));
	if (!gd::is_dict(script_state_value)) {
		// build_script_state(): its hook list is untyped.
		not_ported("a session without a script state");
	}
	const DictRef script_state = script_state_value.ref;

	// var fired_hook_ids: Array[String] = []: a new Array of the saved list's
	// element type, which must be String; an untyped one (a new or loaded
	// session's) is left to GDScript, which types it.
	const Value saved_ids = state.get(script_state, str(key::fired_hook_ids), array_value(state.new_array()));
	if (!gd::is_array(saved_ids) || state.type_builtin(state.array(saved_ids.ref).element_type) != state::variant_type::STRING) {
		not_ported("a script state whose hook list is not an Array[String]");
	}
	const ArrayRef fired_hook_ids = gd::slice(state, saved_ids.ref, 0, 0);
	for (const Value &hook_id_value : gd::items(state, saved_ids)) {
		const Atom hook_id = gd::stringify_or_fallback(state, hook_id_value);
		if (hook_id != key::empty && !gd::array_has(state, fired_hook_ids, str(hook_id))) {
			state.append(fired_hook_ids, str(hook_id));
		}
	}

	const ArrayRef event_log = state.new_array();
	const int64_t day = gd::int_field(state, session, key::day, 0);
	for (const Value &entry : gd::items(state, state.get(script_state, str(key::event_log), array_value(state.new_array())))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const DictRef record = state.new_dict();
		state.set(record, str(key::hook_id), str(text(state, entry.ref, key::hook_id, key::empty)));
		state.set(record, str(key::day), int_value(compat::engine_max<int64_t>(1, gd::int_field(state, entry.ref, key::day, day))));
		state.set(record, str(key::message), str(text(state, entry.ref, key::message, key::empty)));
		state.append(event_log, dict_value(record));
	}
	while (state.array_size(event_log) > kEventLogLimit) {
		gd::remove_at(state, event_log, 0);
	}

	state.set(script_state, str(key::fired_hook_ids), array_value(fired_hook_ids));
	state.set(script_state, str(key::event_log), array_value(event_log));
	state.set(overworld, str(key::scenario_script_state), dict_value(script_state));
}

DictRef process_hooks(State &state, DictRef session) {
	normalize_script_state(state, session);
	const DictRef result = state.new_dict();
	if (text(state, session, key::scenario_id, key::empty) == key::empty) {
		state.set(result, str(key::fired_ids), array_value(state.new_array()));
		state.set(result, str(key::messages), array_value(state.new_array()));
		state.set(result, str(key::message), str(key::empty));
		return result;
	}

	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, text(state, session, key::scenario_id, key::empty));
	const ArrayRef hooks = _sorted_hooks(state, state.get(scenario, str(key::script_hooks), array_value(state.new_array())));
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef script_state = gd::as_dict(state.get(overworld, str(key::scenario_script_state), dict_value(state.new_dict())));
	const ArrayRef fired_hook_ids = gd::as_array(state.get(script_state, str(key::fired_hook_ids), array_value(state.new_array())));
	const ArrayRef fired_ids = state.new_array();
	const ArrayRef messages = state.new_array();
	const DictRef retry_result = _retry_pending_reinforcements(state, session);
	for (const Value &message : gd::field_items(state, retry_result, str(key::messages))) {
		state.append(messages, message);
	}
	// Each retried hook is processed this pass; with no hooks that is all.
	if (state.array_size(hooks) > 0) {
		// _hook_sorts_before, _conditions_met, _apply_effects, _append_event_log.
		not_ported("scenario script hooks");
	}

	state.set(script_state, str(key::fired_hook_ids), array_value(fired_hook_ids));
	state.set(overworld, str(key::scenario_script_state), dict_value(script_state));

	state.set(result, str(key::fired_ids), array_value(fired_ids));
	state.set(result, str(key::messages), array_value(messages));
	state.set(result, str(key::message), str(_join_messages(state, array_value(messages))));
	return result;
}

DictRef _retry_pending_reinforcements(State &state, DictRef session) {
	const DictRef script_state = gd::as_dict(state.get(session_view::overworld(state, session), str(key::scenario_script_state), dict_value(state.new_dict())));
	const Value pending = state.get(script_state, str(key::pending_reinforcements), dict_value(state.new_dict()));
	if (gd::is_dict(pending) && !gd::is_empty(state, pending.ref)) {
		// Hook grants waiting for their army or garrison (authored scenarios).
		not_ported("pending reinforcements");
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::messages), array_value(state.new_array()));
	state.set(result, str(key::hook_ids), array_value(state.new_array()));
	return result;
}

ArrayRef _sorted_hooks(State &state, const Value &raw_hooks) {
	const ArrayRef hooks = state.new_array();
	if (gd::is_array(raw_hooks)) {
		for (const Value &hook : gd::items(state, raw_hooks)) {
			if (gd::is_dict(hook)) {
				state.append(hooks, hook);
			}
		}
	}
	if (state.array_size(hooks) > 1) {
		// The selection sort by _hook_sorts_before.
		not_ported("sorting scenario script hooks");
	}
	return hooks;
}

Atom _join_messages(State &state, const Value &messages) {
	std::string joined;
	bool first = true;
	if (gd::is_array(messages)) {
		for (const Value &value : gd::items(state, messages)) {
			const Atom message = gd::stringify_or_fallback(state, value);
			if (message == key::empty) {
				continue;
			}
			if (!first) {
				joined += " ";
			}
			joined += state.text(message);
			first = false;
		}
	}
	return state.intern(joined);
}

} // namespace scenario_script_rules

// GeneratedScenarioObjectiveRules.

namespace generated_scenario_objective_rules {

bool uses_kind(State &state, DictRef scenario) {
	const Value value = state.get(scenario, str(key::objectives), dict_value(state.new_dict()));
	return gd::is_dict(value) && text(state, value.ref, key::kind, key::empty) == key::defeat_generated_rivals &&
			!state.has(value.ref, str(key::victory)) && !state.has(value.ref, str(key::defeat));
}

Value definitions(State &state, DictRef scenario) {
	const Value original = state.get(scenario, str(key::objectives), dict_value(state.new_dict()));
	if (!uses_kind(state, scenario)) {
		return original;
	}
	// A derived rule view only. Never amend package documents or saved records.
	const DictRef result = gd::duplicate_dict(state, original.ref);
	const DictRef objective = state.new_dict();
	state.set(objective, str(key::id), str(key::defeat_generated_rivals));
	state.set(objective, str(key::type), str(key::defeat_generated_rivals));
	state.set(objective, str(key::label), str(key::defeat_every_rival_commander));
	const ArrayRef victory = state.new_array();
	state.append(victory, dict_value(objective));
	state.set(result, str(key::victory), array_value(victory));
	state.set(result, str(key::defeat), array_value(state.new_array()));
	state.set(result, str(key::victory_text), str(key::all_rival_commanders_defeated));
	return dict_value(result);
}

DictRef progress(State &state, DictRef session) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::known), gd::bool_value(false));
	state.set(result, str(key::complete), gd::bool_value(false));
	state.set(result, str(key::total), int_value(0));
	state.set(result, str(key::defeated), int_value(0));
	state.set(result, str(key::remaining), array_value(state.new_array()));
	state.set(result, str(key::reason), str(key::player_ownership_unavailable));
	const DictRef overworld = session_view::overworld(state, session);
	for (const Atom bucket : { key::towns, key::encounters, key::resource_nodes, key::resolved_encounters }) {
		if (!gd::is_array(gd::field(state, overworld, bucket))) {
			return result;
		}
	}
	const Value players = state.get(overworld, str(key::players), array_value(state.new_array()));
	if (!gd::is_array(players)) {
		return result;
	}
	const DictRef catalog = state.new_dict();
	const Atom active = text(state, overworld, key::active_player_id, key::empty);
	const DictRef flags = gd::as_dict(gd::field(state, session, key::flags));
	Value source = state.get(flags, str(key::native_random_map_runtime_scenario_record), dict_value(state.new_dict()));
	if (!gd::is_dict(source) || text(state, source.ref, key::id, key::empty) != text(state, session, key::scenario_id, key::empty)) {
		source = state.get(overworld, str(key::native_random_map_runtime_scenario_record), dict_value(state.new_dict()));
	}
	if (!gd::is_dict(source)) {
		return result;
	}
	if (state.array_size(players.ref) == 0) {
		if (text(state, overworld, key::player_identity_mode, key::empty) != key::legacy_generated_faction_v0) {
			return result;
		}
		// Pre-controller saves' legacy rivals.
		not_ported("the rivals of a pre-controller save");
	}
	for (const Value &player : gd::items(state, players)) {
		if (!gd::is_dict(player)) {
			return result;
		}
		const Atom id = text(state, player.ref, key::player_id, key::empty);
		if (id == key::empty || state.has(catalog, str(id)) || text(state, player.ref, key::faction_id, key::empty) == key::empty ||
				text(state, player.ref, key::team_id, key::empty) == key::empty) {
			return result;
		}
		state.set(catalog, str(id), player);
	}
	Value active_player;
	if (!state.lookup(catalog, str(active), active_player) || !gd::bool_field(state, active_player.ref, key::human, false)) {
		return result;
	}
	// The package's player slots, then the rivals' towns, field hosts and
	// defenders (a human game).
	not_ported("the rival count of a human game");
}

} // namespace generated_scenario_objective_rules

} // namespace aurelion::rules::port
