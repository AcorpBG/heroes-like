// ScenarioRules.evaluate_session: the scenario state normalized (its script
// state, the computer players' states), its script hooks run and its
// objectives checked. Generated maps have no script hooks and one objective,
// defeating every rival, which counts only for a human player. The battle ends
// run it too (Phase 5 slice 09), so a human game's rival count and a won or
// lost scenario are ported. Left to GDScript (state::NotPorted): script hooks
// and pending reinforcements (authored scenarios), any other objective type, a
// campaign chapter's completion, a script state whose hook list is not yet a
// typed Array[String] (built anew once a session).

#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
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
DictRef _complete_session(State &state, DictRef session, Atom status, Atom summary);
DictRef _merge_result_messages(State &state, DictRef result, Atom prefix_message);
Atom _resolution_text(State &state, DictRef scenario, Atom status);
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
				return _merge_result_messages(state, _complete_session(state, session, key::defeat, _resolution_text(state, scenario, key::defeat)), script_message);
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
			return _merge_result_messages(state, _complete_session(state, session, key::victory, _resolution_text(state, scenario, key::victory)), script_message);
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

DictRef _complete_session(State &state, DictRef session, Atom status, Atom summary) {
	// session.to_dict(), the snapshot a campaign's failed completion restores,
	// changes nothing.
	state.set(session, str(key::scenario_status), str(status));
	state.set(session, str(key::scenario_summary), str(summary));
	state.set(gd::as_dict(gd::field(state, session, key::flags)), str(key::scenario_result), str(status));
	if (session_state_store::normalize_launch_mode(state, gd::field(state, session, key::launch_mode)) == key::campaign) {
		// CampaignProgression.record_session_completion (campaigns are archived).
		not_ported("a campaign chapter's completion");
	}
	return status_result(state, status, summary);
}

DictRef _merge_result_messages(State &state, DictRef result, Atom prefix_message) {
	const DictRef merged = gd::deep_duplicate_dict(state, result);
	std::string joined;
	if (prefix_message != key::empty) {
		joined = state.text(prefix_message);
	}
	const Atom result_message = text(state, result, key::message, key::empty);
	if (result_message != key::empty) {
		if (prefix_message != key::empty) {
			joined += " ";
		}
		joined += state.text(result_message);
	}
	state.set(merged, str(key::message), str(state.intern(joined)));
	return merged;
}

Atom _resolution_text(State &state, DictRef scenario, Atom status) {
	const Value objectives = objective_definitions(state, scenario);
	if (gd::is_dict(objectives)) {
		const Atom explicit_text = text(state, objectives.ref, state.intern(state.text(status) + "_text"), key::empty);
		if (explicit_text != key::empty) {
			return explicit_text;
		}
	}
	return gd::format(state, key::scenario_s, { str(status) });
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

	// var fired_hook_ids: Array[String] = [], filled from the saved list, typed
	// or not (a new or loaded session's is untyped).
	const Value saved_ids = state.get(script_state, str(key::fired_hook_ids), array_value(state.new_array()));
	if (!gd::is_array(saved_ids)) {
		not_ported("a script state whose hook list is not an Array");
	}
	const ArrayRef fired_hook_ids = gd::new_typed_array(state, state::variant_type::STRING);
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
	const Atom active_id = text(state, overworld, key::active_player_id, key::empty);
	const DictRef flags = gd::as_dict(gd::field(state, session, key::flags));
	Value source = state.get(flags, str(key::native_random_map_runtime_scenario_record), dict_value(state.new_dict()));
	if (!gd::is_dict(source) || text(state, source.ref, key::id, key::empty) != text(state, session, key::scenario_id, key::empty)) {
		source = state.get(overworld, str(key::native_random_map_runtime_scenario_record), dict_value(state.new_dict()));
	}
	if (!gd::is_dict(source)) {
		return result;
	}
	const bool no_players = state.array_size(players.ref) == 0;
	Atom active = active_id;
	if (!no_players) {
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
		// Native package slots are immutable identity, unlike Town ownership.
		// A dropped rival row or altered team must not manufacture a victory.
		if (state.has(source.ref, str(key::player_slots))) {
			const Value slots = state.get(source.ref, str(key::player_slots), Value());
			if (!gd::is_array(slots) || state.array_size(slots.ref) != state.array_size(players.ref)) {
				return result;
			}
			const DictRef seen = state.new_dict();
			for (const Value &original : gd::items(state, array_value(player_identity_rules::from_slots(state, slots.ref)))) {
				const Atom id = text(state, original.ref, key::player_id, key::empty);
				Value listed;
				if (state.has(seen, str(id)) || !state.lookup(catalog, str(id), listed)) {
					return result;
				}
				state.set(seen, str(id), gd::bool_value(true));
				for (const Atom field : { key::faction_id, key::team_id, key::human }) {
					if (!gd::equal(state, state.get(original.ref, str(field), Value()), state.get(listed.ref, str(field), Value()))) {
						return result;
					}
				}
			}
			if (state.dict_size(seen) != state.array_size(players.ref)) {
				return result;
			}
		}
	} else {
		// Pre-controller saves cannot recover same-faction ownership that was
		// already pooled. Accept only their explicit, distinct legacy controllers.
		if (text(state, overworld, key::player_identity_mode, key::empty) != key::legacy_generated_faction_v0) {
			return result;
		}
		const Value enemies = state.get(source.ref, str(key::enemy_factions), array_value(state.new_array()));
		if (!gd::is_array(enemies) || state.array_size(enemies.ref) == 0) {
			return result;
		}
		active = key::player;
		state.set(catalog, str(active), dict_value(state.new_dict()));
		const DictRef hero = gd::as_dict(state.get(overworld, str(key::hero), dict_value(state.new_dict())));
		for (const Value &enemy : gd::items(state, enemies)) {
			const Atom id = gd::is_dict(enemy) ? player_identity_rules::controller_id(state, enemy.ref, key::empty) : gd::stringify(state, enemy);
			if (id == key::empty || state.has(catalog, str(id)) || id == text(state, hero, key::faction_id, key::empty)) {
				return result;
			}
			state.set(catalog, str(id), dict_value(state.new_dict()));
		}
	}

	const DictRef rivals = state.new_dict();
	for (const Value &id_value : gd::items(state, array_value(gd::keys(state, catalog)))) {
		const Atom id = gd::stringify(state, id_value);
		if (id != active && !player_identity_rules::allied(state, dict_value(session), active, id)) {
			const DictRef presence = state.new_dict();
			state.set(presence, str(key::towns), int_value(0));
			state.set(presence, str(key::field_hosts), int_value(0));
			state.set(presence, str(key::defenders), int_value(0));
			state.set(rivals, str(id), dict_value(presence));
		}
	}
	// rivals[controller].<field> += 1.
	const auto count = [&](Atom controller, Atom field) {
		Value presence;
		if (state.lookup(rivals, str(controller), presence)) {
			state.set(presence.ref, str(field), gd::op_add(state.get(presence.ref, str(field), Value()), int_value(1)));
		}
	};

	for (const Value &town : gd::items(state, state.get(overworld, str(key::towns), array_value(state.new_array())))) {
		if (!gd::is_dict(town)) {
			return result;
		}
		const Atom owner = text(state, town.ref, key::owner, key::neutral);
		if (owner == key::neutral) {
			continue;
		}
		Atom controller = player_identity_rules::town_controller_id(state, town.ref);
		if (owner == key::player && no_players) {
			controller = active;
		}
		if ((owner != key::player && owner != key::enemy) || !state.has(catalog, str(controller))) {
			return result;
		}
		if (owner == key::player && controller != active) {
			return result;
		}
		if (owner == key::enemy && controller == active) {
			return result;
		}
		count(controller, key::towns);
	}
	const Value resolved = state.get(overworld, str(key::resolved_encounters), array_value(state.new_array()));
	if (!gd::is_array(resolved)) {
		return result;
	}
	for (const Value &encounter : gd::items(state, state.get(overworld, str(key::encounters), array_value(state.new_array())))) {
		if (!gd::is_dict(encounter)) {
			return result;
		}
		if (!gd::array_has(state, resolved.ref, str(text(state, encounter.ref, key::placement_id, key::empty))) &&
				!gd::bool_field(state, encounter.ref, key::raid_retired_to_rebuild, false)) {
			const Value commander = state.get(encounter.ref, str(key::enemy_commander_state), dict_value(state.new_dict()));
			if (gd::is_dict(commander) && text(state, commander.ref, key::player_id, key::empty) != key::empty &&
					player_identity_rules::raid_controller_id(state, encounter.ref) == key::empty) {
				return result;
			}
		}
		if (!enemy_adventure_rules::is_active_pressure_host(state, encounter, key::empty, resolved)) {
			continue;
		}
		const Atom controller = player_identity_rules::raid_controller_id(state, encounter.ref);
		if (!state.has(catalog, str(controller))) {
			return result;
		}
		count(controller, key::field_hosts);
	}
	for (const Value &node : gd::items(state, state.get(overworld, str(key::resource_nodes), array_value(state.new_array())))) {
		if (!gd::is_dict(node)) {
			return result;
		}
		if (!state.has(node.ref, str(key::ai_defender_commander_state))) {
			continue;
		}
		if (gd::is_empty(state, enemy_adventure_rules::_active_resource_defender_entry(state, session, node.ref, key::empty))) {
			continue;
		}
		const Atom controller = player_identity_rules::defender_controller_id(state, node.ref);
		if (!state.has(catalog, str(controller))) {
			return result;
		}
		count(controller, key::defenders);
	}

	state.set(result, str(key::known), gd::bool_value(true));
	state.set(result, str(key::reason), str(key::empty));
	state.set(result, str(key::total), int_value(state.dict_size(rivals)));
	const ArrayRef remaining = gd::as_array(state.get(result, str(key::remaining), Value()));
	for (const Value &id_value : gd::items(state, array_value(gd::keys(state, rivals)))) {
		const DictRef presence = gd::as_dict(state.get(rivals, id_value, Value()));
		const int64_t present = gd::add(gd::add(gd::int_field(state, presence, key::towns, 0), gd::int_field(state, presence, key::field_hosts, 0)),
				gd::int_field(state, presence, key::defenders, 0));
		if (present > 0) {
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::player_id), id_value);
			state.set(entry, str(key::presence), dict_value(presence));
			state.append(remaining, dict_value(entry));
		} else {
			state.set(result, str(key::defeated), gd::op_add(state.get(result, str(key::defeated), Value()), int_value(1)));
		}
	}
	state.set(result, str(key::complete), gd::bool_value(state.array_size(remaining) == 0));
	return result;
}

} // namespace generated_scenario_objective_rules

// PlayerIdentityRules and EnemyAdventureRules: what a human game's rival count
// reads that no port had (Phase 4 declares them, battle_ends.hpp).

namespace player_identity_rules {

Atom defender_controller_id(State &state, DictRef record) {
	Atom player_id = text(state, record, key::ai_defended_by_player_id, key::empty);
	const Value commander_value = state.get(record, str(key::ai_defender_commander_state), dict_value(state.new_dict()));
	const DictRef commander = gd::is_dict(commander_value) ? commander_value.ref : state.new_dict();
	if (player_id == key::empty) {
		player_id = text(state, commander, key::player_id, key::empty);
	}
	if (player_id != key::empty) {
		return player_id;
	}
	const Atom faction = text(state, record, key::ai_defended_by_faction_id, key::empty);
	return faction != key::empty ? faction : text(state, commander, key::faction_id, key::empty);
}

ArrayRef from_slots(State &state, ArrayRef slots) {
	const ArrayRef result = state.new_array();
	for (const Value &value : gd::items(state, array_value(slots))) {
		if (!gd::is_dict(value)) {
			continue;
		}
		const int64_t slot = gd::int_field(state, value.ref, key::slot, 0);
		if (slot <= 0) {
			continue;
		}
		const DictRef record = gd::deep_duplicate_dict(state, value.ref);
		Atom id = text(state, record, key::player_id, key::empty);
		if (id == key::empty) {
			id = gd::format(state, key::player_d, { int_value(slot) });
		}
		state.set(record, str(key::player_id), str(id));
		if (text(state, record, key::team_id, key::empty) == key::empty) {
			// Older packages did not carry teams. Do not invent alliances from
			// faction equality or the requested (not source-assigned) team count.
			state.set(record, str(key::team_id), str(id));
		}
		state.append(result, dict_value(record));
	}
	return result;
}

} // namespace player_identity_rules

namespace enemy_adventure_rules {

bool is_active_pressure_host(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters) {
	if (!_is_active_raid(state, encounter, faction_id, resolved_encounters)) {
		return false;
	}
	const DictRef raid = gd::as_dict(encounter);
	if (text(state, raid, key::difficulty, key::empty) == key::pressure) {
		return true;
	}
	if (state.has(raid, str(key::days_active))) {
		return true;
	}
	if (text(state, raid, key::target_kind, key::empty) != key::empty && text(state, raid, key::target_placement_id, key::empty) != key::empty) {
		return true;
	}
	if (gd::bool_field(state, raid, key::commanderless_support_column, false)) {
		return true;
	}
	const Value commander_state = state.get(raid, str(key::enemy_commander_state), dict_value(state.new_dict()));
	if (gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		return true;
	}
	return text(state, raid, key::delivery_intercept_node_placement_id, key::empty) != key::empty;
}

DictRef _active_resource_defender_entry(State &state, DictRef session, DictRef node, Atom faction_filter) {
	// session == null: a view is never null.
	if (gd::is_empty(state, node)) {
		return state.new_dict();
	}
	const Value commander_state = state.get(node, str(key::ai_defender_commander_state), dict_value(state.new_dict()));
	if (!gd::is_dict(commander_state) || gd::is_empty(state, commander_state.ref)) {
		return state.new_dict();
	}
	const Atom roster_hero_id = gd::stringify_or_fallback(state,
			state.get(commander_state.ref, str(key::roster_hero_id), state.get(node, str(key::ai_defender_roster_hero_id), str(key::empty))));
	if (roster_hero_id == key::empty) {
		return state.new_dict();
	}
	const Atom faction_id = player_identity_rules::defender_controller_id(state, node);
	if (faction_filter != key::empty && faction_id != faction_filter) {
		return state.new_dict();
	}
	const DictRef site = gd::content_row(state, state::ContentTable::ResourceSite, text(state, node, key::site_id, key::empty));
	if (!_resource_site_is_persistent(state, site)) {
		return state.new_dict();
	}
	if (faction_id == key::empty || player_identity_rules::resource_controller_id(state, node) != faction_id) {
		return state.new_dict();
	}
	const Value front_value = state.get(node, str(key::front), dict_value(state.new_dict()));
	const DictRef front = gd::is_dict(front_value) ? front_value.ref : state.new_dict();
	const Atom raw_front_state = text(state, front, key::state, key::empty);
	const int64_t defense_until = compat::engine_max<int64_t>(gd::int_field(state, node, key::ai_defense_until_day, 0), gd::int_field(state, front, key::defense_until_day, 0));
	if (defense_until < gd::to_int(state, gd::field(state, session, key::day))) {
		return state.new_dict();
	}
	if (raw_front_state != key::empty && raw_front_state != key::defend && raw_front_state != key::stabilizing) {
		return state.new_dict();
	}
	const DictRef entry_state = gd::deep_duplicate_dict(state, commander_state.ref);
	state.set(entry_state, str(key::roster_hero_id), str(roster_hero_id));
	gd::merge(state, entry_state, player_identity_rules::identity_fields(state, session, faction_id), true);
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::placement_id), str(gd::format(state, key::resource_defense_s, { str(text(state, node, key::placement_id, key::empty)) })));
	state.set(entry, str(key::commander_state), dict_value(entry_state));
	return entry;
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
