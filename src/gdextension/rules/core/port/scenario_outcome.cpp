// ScenarioRules for the outcome screen (Phase 7, slice 7.7): the outcome model,
// its actions, their cue and handoff lines, and the progress recap.

#include "aurelion_rules/port/scenario_outcome.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Declared only in scenario_evaluation.cpp, which defines them.
namespace scenario_rules {
bool _objective_met(state::State &state, gd::DictRef session, gd::DictRef objective);
gd::Atom _resolution_text(state::State &state, gd::DictRef scenario, gd::Atom status);
} // namespace scenario_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

[[noreturn]] void not_ported(const std::string &what) {
	throw state::NotPorted("not ported: " + what);
}

// ScenarioSelectRules.start_skirmish_session: a maps-folder package starts as
// the setup port starts it. Any other id is an authored skirmish, archived:
// the game offers none.
Value start_skirmish_session(State &state, Atom scenario_id, Atom difficulty_id) {
	if (scenario_select_rules::maps_folder_package_id_is_valid(state, scenario_id)) {
		return scenario_select_rules::start_maps_folder_package_skirmish_session(state, scenario_id, difficulty_id);
	}
	not_ported("ScenarioSelectRules.start_skirmish_session: an authored skirmish (archived)");
}

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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// session.<field> of SessionData's String fields.
Atom session_text(State &state, DictRef session, Atom field) {
	return gd::to_string(gd::index(state, session, str(field)));
}

int64_t session_day(State &state, DictRef session) {
	return gd::to_int(state, gd::index(state, session, str(key::day)));
}

DictRef session_flags(State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::flags)));
}

Atom session_launch_mode(State &state, DictRef session) {
	return session_state_store::normalize_launch_mode(state, gd::index(state, session, str(key::launch_mode)));
}

// separator.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

bool has_atom(const std::vector<Atom> &atoms, Atom atom) {
	return std::find(atoms.begin(), atoms.end(), atom) != atoms.end();
}

// {"ok": ok, "route": route, "message": message}.
DictRef route_result(State &state, bool ok, Atom route, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::route), str(route));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"id": id, "label": label, "summary": summary, "disabled": false}.
DictRef action_entry(State &state, Atom id, Atom label, Atom summary) {
	const DictRef action = state.new_dict();
	state.set(action, str(key::id), str(id));
	state.set(action, str(key::label), str(label));
	state.set(action, str(key::summary), str(summary));
	state.set(action, str(key::disabled), bool_value(false));
	return action;
}

// The lines of the report's fields, each String(report.get(field, "")).strip_edges()
// once, joined by separator; at most `limit` lines (0: all).
Atom aftermath_lines(State &state, DictRef session, std::initializer_list<Atom> fields, size_t limit, Atom separator) {
	Value report;
	if (!state.lookup(session_flags(state, session), str(key::last_battle_aftermath), report) || !gd::is_dict(report) ||
			gd::is_empty(state, report.ref)) {
		return key::empty;
	}
	std::vector<Atom> lines;
	for (const Atom field : fields) {
		const Atom line = gd::strip_edges(state, text_or(state, report.ref, field, str(key::empty)));
		if (line != key::empty && !has_atom(lines, line)) {
			lines.push_back(line);
		}
		if (limit > 0 && lines.size() >= limit) {
			break;
		}
	}
	return join_atoms(state, separator, lines);
}

} // namespace

namespace scenario_rules {

Atom describe_session_progress_recap(State &state, DictRef session, bool include_header) {
	// session == null: a view is never null.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return include_header ? static_cast<Atom>(key::progress_recap_no_active_scenario_progress) : static_cast<Atom>(key::empty);
	}
	overworld_rules::normalize_overworld_state(state, session);
	normalize_scenario_state(state, session, true);
	return describe_session_progress_recap_from_normalized_session(state, session, include_header, state.new_dict());
}

Atom describe_session_progress_recap_from_normalized_session(State &state, DictRef session, bool include_header, DictRef preloaded_objective_surface) {
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return include_header ? static_cast<Atom>(key::progress_recap_no_active_scenario_progress) : static_cast<Atom>(key::empty);
	}
	const DictRef scenario = scenario_record_for_session(state, session);
	if (gd::is_empty(state, scenario)) {
		return include_header ? static_cast<Atom>(key::progress_recap_scenario_progress_is_unavailable) : static_cast<Atom>(key::empty);
	}

	std::vector<Atom> lines;
	const DictRef objective_surface = _objective_progress_surface_is_complete(state, preloaded_objective_surface) ? preloaded_objective_surface : state.new_dict();
	if (include_header) {
		lines.push_back(key::progress_recap_3);
	}
	const Atom context_line = _progress_recap_context_line(state, session, scenario);
	if (context_line != key::empty) {
		lines.push_back(context_line);
	}
	const Atom status_line = _progress_recap_status_line(state, session, objective_surface);
	if (status_line != key::empty) {
		lines.push_back(status_line);
	}
	const Atom recent_line = _progress_recap_recent_line(state, session, scenario, objective_surface);
	if (recent_line != key::empty) {
		lines.push_back(recent_line);
	}
	const Atom next_step_line = _progress_recap_next_step_line(state, session, scenario, objective_surface);
	if (next_step_line != key::empty) {
		lines.push_back(next_step_line);
	}
	return join_atoms(state, key::newline, lines);
}

DictRef build_outcome_model(State &state, DictRef session) {
	normalize_scenario_state(state, session, true);
	// session == null: a view is never null.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		const DictRef empty_model = state.new_dict();
		state.set(empty_model, str(key::header), str(key::no_scenario_outcome));
		state.set(empty_model, str(key::summary), str(key::no_resolved_scenario_is_active));
		state.set(empty_model, str(key::mode_summary), str(key::empty));
		state.set(empty_model, str(key::hero_summary), str(key::empty));
		state.set(empty_model, str(key::army_summary), str(key::empty));
		state.set(empty_model, str(key::resource_summary), str(key::empty));
		state.set(empty_model, str(key::progression_summary), str(key::empty));
		state.set(empty_model, str(key::campaign_arc_summary), str(key::empty));
		state.set(empty_model, str(key::carryover_summary), str(key::empty));
		state.set(empty_model, str(key::aftermath_summary), str(key::empty));
		state.set(empty_model, str(key::journal_summary), str(key::empty));
		state.set(empty_model, str(key::post_result_handoff_summary), str(key::post_result_handoff_no_resolved_scenario));
		state.set(empty_model, str(key::action_cue_summary), str(key::action_cue_return_to_the_menu));
		const ArrayRef menu_actions = state.new_array();
		state.append(menu_actions, dict_value(action_entry(state, key::return_to_menu, key::return_to_menu_2, key::return_to_the_main_menu)));
		state.set(empty_model, str(key::actions), array_value(menu_actions));
		return empty_model;
	}

	overworld_rules::normalize_overworld_state(state, session);
	const DictRef scenario = scenario_record_for_session(state, session);
	const Atom launch_mode = session_launch_mode(state, session);
	const Atom status_label = gd::capitalize(state, session_text(state, session, key::scenario_status));
	const Atom scenario_id = session_text(state, session, key::scenario_id);
	Atom display_name = gd::strip_edges(state, text_or(state, scenario, key::name, str(key::empty)));
	if (gd::bool_field(state, session_flags(state, session), key::generated_random_map, false) && (display_name == key::empty || display_name == scenario_id)) {
		display_name = scenario_select_rules::generated_skirmish_display_name(state, dict_value(session));
	} else if (display_name == key::empty) {
		display_name = scenario_id;
	}

	const Atom header = gd::format(state, key::s_s_text, { str(status_label), str(display_name) });
	const Atom scenario_summary = session_text(state, session, key::scenario_summary);
	const Atom summary = scenario_summary != key::empty ? scenario_summary : static_cast<Atom>(key::scenario_resolution_recorded);
	const Atom mode_label = scenario_select_rules::launch_mode_label(state, launch_mode);
	const Atom difficulty_text = scenario_select_rules::difficulty_label(state, session_text(state, session, key::difficulty));
	const Atom mode_summary = gd::format(state, key::s_s_day_d, { str(mode_label), str(difficulty_text), int_value(session_day(state, session)) });
	const Atom hero_summary = overworld_rules::describe_hero(state, session);
	const Atom army_summary = overworld_rules::describe_army(state, session);
	const Atom resource_summary = overworld_rules::describe_resources(state, session);
	const DictRef model = state.new_dict();
	state.set(model, str(key::header), str(header));
	state.set(model, str(key::summary), str(summary));
	state.set(model, str(key::mode_summary), str(mode_summary));
	state.set(model, str(key::hero_summary), str(hero_summary));
	state.set(model, str(key::army_summary), str(army_summary));
	state.set(model, str(key::resource_summary), str(resource_summary));
	state.set(model, str(key::progression_summary), str(key::empty));
	state.set(model, str(key::campaign_arc_summary), str(key::empty));
	state.set(model, str(key::carryover_summary), str(key::empty));
	state.set(model, str(key::aftermath_summary), str(key::empty));
	state.set(model, str(key::journal_summary), str(key::empty));
	state.set(model, str(key::next_step_summary), str(key::empty));
	state.set(model, str(key::next_play_action_summary), str(key::empty));
	state.set(model, str(key::continuity_choice_summary), str(key::empty));
	state.set(model, str(key::post_result_handoff_summary), str(key::empty));
	state.set(model, str(key::action_cue_summary), str(key::empty));
	state.set(model, str(key::actions), array_value(state.new_array()));

	const Atom progress_recap = describe_session_progress_recap(state, session, true);
	const Atom next_step = _progress_recap_next_step_line(state, session, scenario, state.new_dict());
	state.set(model, str(key::next_step_summary), str(next_step));
	state.set(model, str(key::next_play_action_summary), str(_outcome_next_play_action_line(state, session, scenario)));

	if (launch_mode == key::campaign) {
		// CampaignProgression.outcome_recap, outcome_continuity_choice and outcome_actions.
		not_ported("ScenarioRules.build_outcome_model: the campaign runtime (7.14)");
	}
	std::vector<Atom> skirmish_lines;
	if (progress_recap != key::empty) {
		skirmish_lines.push_back(progress_recap);
	}
	skirmish_lines.push_back(key::skirmish_results_are_self_contained_and);
	skirmish_lines.push_back(gd::format(state, key::final_state_s_hero_army_and, { str(status_label) }));
	state.set(model, str(key::progression_summary), str(join_atoms(state, key::newline, skirmish_lines)));
	state.set(model, str(key::campaign_arc_summary), str(key::campaign_arc_closure_is_only_tracked));
	state.set(model, str(key::carryover_summary), str(key::skirmish_runs_do_not_import_or));
	state.set(model, str(key::aftermath_summary), str(_build_skirmish_aftermath_summary(state, session, scenario)));
	state.set(model, str(key::journal_summary), str(key::campaign_chronicle_updates_are_only_recorded));
	state.set(model, str(key::continuity_choice_summary), str(_skirmish_outcome_continuity_choice_line(state, session)));
	state.set(model, str(key::actions), array_value(_build_skirmish_outcome_actions(state, session)));

	state.set(model, str(key::actions), array_value(_decorate_outcome_actions(state, session, scenario, gd::as_array(gd::index(state, model, str(key::actions))))));
	state.set(model, str(key::post_result_handoff_summary),
			str(_outcome_post_result_handoff_line(state, session, scenario, gd::as_array(gd::index(state, model, str(key::actions))))));
	state.set(model, str(key::action_cue_summary), str(_outcome_action_cue_line(state, session, scenario, gd::as_array(gd::index(state, model, str(key::actions))))));
	return model;
}

DictRef perform_outcome_action(State &state, DictRef session, Atom action_id) {
	if (action_id == key::empty || action_id == key::return_to_menu) {
		return route_result(state, true, key::main_menu_2, key::empty);
	}

	if (gd::begins_with(state, action_id, key::campaign_start)) {
		// CampaignProgression.campaign_id_for_session and start_scenario.
		not_ported("ScenarioRules.perform_outcome_action: the campaign runtime (7.14)");
	}

	if (gd::begins_with(state, action_id, key::skirmish_start)) {
		if (gd::bool_field(state, session_flags(state, session), key::generated_random_map, false) &&
				action_id == state.joined_atom(key::skirmish_start, session_text(state, session, key::scenario_id))) {
			return scenario_select_rules::restart_generated_skirmish_session(state, dict_value(session));
		}
		const Value skirmish_session = start_skirmish_session(state, gd::trim_prefix(state, action_id, key::skirmish_start), session_text(state, session, key::difficulty));
		if (session_text(state, gd::object_view(state, skirmish_session), key::scenario_id) == key::empty) {
			return route_result(state, false, key::stay, key::the_requested_skirmish_could_not_be);
		}
		return route_result(state, true, key::overworld, key::empty);
	}

	return route_result(state, false, key::stay, key::that_outcome_action_is_not_supported);
}

ArrayRef _build_skirmish_outcome_actions(State &state, DictRef session) {
	Atom retry_summary = gd::format(state, key::launch_this_authored_scenario_again_at,
			{ str(scenario_select_rules::difficulty_label(state, session_text(state, session, key::difficulty))) });
	if (gd::bool_field(state, session_flags(state, session), key::generated_random_map, false)) {
		retry_summary = gd::format(state, key::restart_this_same_generated_map_with,
				{ str(scenario_select_rules::difficulty_label(state, session_text(state, session, key::difficulty))) });
	}
	const ArrayRef actions = state.new_array();
	const Atom retry_id = gd::format(state, key::skirmish_start_s, { str(session_text(state, session, key::scenario_id)) });
	state.append(actions, dict_value(action_entry(state, retry_id, key::retry_skirmish, retry_summary)));
	state.append(actions, dict_value(action_entry(state, key::return_to_menu, key::return_to_menu_2, key::return_to_the_play_guide_settings)));
	return actions;
}

ArrayRef _decorate_outcome_actions(State &state, DictRef session, DictRef scenario, ArrayRef actions) {
	const ArrayRef decorated = state.new_array();
	for (int64_t index = 0; index < state.array_size(actions); ++index) {
		const Value action = state.at(actions, index);
		if (!gd::is_dict(action)) {
			continue;
		}
		const DictRef action_copy = gd::as_dict(gd::engine_duplicate(state, action, true));
		const Atom cue = _outcome_action_cue_text(state, session, scenario, action_copy);
		if (cue != key::empty) {
			state.set(action_copy, str(key::action_cue), str(cue));
			const Atom summary = gd::strip_edges(state, text_or(state, action_copy, key::summary, str(key::empty)));
			const Atom decorated_summary = summary != key::empty ? gd::format(state, key::s_action_cue_s, { str(summary), str(cue) })
																 : gd::format(state, key::action_cue_s, { str(cue) });
			state.set(action_copy, str(key::summary), str(decorated_summary));
		}
		state.append(decorated, dict_value(action_copy));
	}
	return decorated;
}

Atom _outcome_action_cue_text(State &state, DictRef session, DictRef scenario, DictRef action) {
	(void)scenario;
	if (gd::bool_field(state, action, key::disabled, false)) {
		return key::this_is_informational_choose_another_available;
	}
	const Atom action_id = text_or(state, action, key::id, str(key::empty));
	if (action_id == key::empty || action_id == key::return_to_menu) {
		return key::autosaves_this_outcome_then_opens_the;
	}
	if (gd::begins_with(state, action_id, key::skirmish_start)) {
		return key::starts_this_skirmish_fresh_save_first;
	}
	if (gd::begins_with(state, action_id, key::campaign_start)) {
		const Atom target_scenario_id = gd::trim_prefix(state, action_id, key::campaign_start);
		if (target_scenario_id == session_text(state, session, key::scenario_id)) {
			if (session_text(state, session, key::scenario_status) == key::victory) {
				return key::replays_this_chapter_fresh_save_first;
			}
			return key::retries_this_chapter_fresh_save_first;
		}
		const DictRef target_scenario = gd::content_row(state, ContentTable::Scenario, target_scenario_id);
		const Atom target_name = text_or(state, target_scenario, key::name, str(target_scenario_id));
		if (target_name != key::empty) {
			return gd::format(state, key::starts_s_at_current_difficulty_save, { str(target_name) });
		}
		return key::starts_the_next_campaign_chapter_save;
	}
	return key::empty;
}

Atom _outcome_action_cue_line(State &state, DictRef session, DictRef scenario, ArrayRef actions) {
	bool any_enabled = false;
	for (int64_t index = 0; index < state.array_size(actions); ++index) {
		const Value action = state.at(actions, index);
		if (!gd::is_dict(action) || gd::bool_field(state, action.ref, key::disabled, false)) {
			continue;
		}
		const Atom label = gd::strip_edges(state, text_or(state, action.ref, key::label, str(key::empty)));
		if (label != key::empty) {
			any_enabled = true;
		}
	}
	if (!any_enabled) {
		return key::action_cue_no_follow_up_action;
	}
	const Atom status = session_text(state, session, key::scenario_status);
	if (session_launch_mode(state, session) == key::campaign) {
		const Atom next_chapter = _next_campaign_chapter_label(state, session, scenario);
		if (status == key::victory && next_chapter != key::empty) {
			return gd::format(state, key::action_cue_save_first_start_s, { str(next_chapter) });
		}
		if (status == key::victory) {
			return key::action_cue_save_first_replay_this;
		}
		return key::action_cue_save_first_retry_this;
	}
	if (status == key::victory) {
		return key::action_cue_save_first_return_to;
	}
	return key::action_cue_save_first_retry_skirmish;
}

Atom _outcome_post_result_handoff_line(State &state, DictRef session, DictRef scenario, ArrayRef actions) {
	const Atom launch_mode = session_launch_mode(state, session);
	const Atom save_label = key::save_outcome;
	if (launch_mode == key::campaign) {
		const Atom primary_label = _first_enabled_outcome_action_label(state, actions, key::return_to_menu);
		if (session_text(state, session, key::scenario_status) == key::victory) {
			const Atom next_chapter = _next_campaign_chapter_label(state, session, scenario);
			if (next_chapter != key::empty) {
				const Atom start_label = primary_label != key::empty ? primary_label : gd::format(state, key::start_s, { str(next_chapter) });
				return gd::format(state, key::post_result_handoff_campaign_progression_is, { str(save_label), str(start_label) });
			}
			return gd::format(state, key::post_result_handoff_campaign_progression_is_2, { str(save_label) });
		}
		const Atom retry_label = primary_label != key::empty ? primary_label : static_cast<Atom>(key::retry_chapter);
		return gd::format(state, key::post_result_handoff_defeat_is_review, { str(save_label), str(retry_label) });
	}
	Atom retry_label = _first_enabled_outcome_action_label(state, actions, key::return_to_menu);
	if (retry_label == key::empty) {
		retry_label = key::retry_skirmish;
	}
	return gd::format(state, key::post_result_handoff_this_skirmish_result, { str(save_label), str(retry_label) });
}

Atom _first_enabled_outcome_action_label(State &state, ArrayRef actions, Atom excluded_id) {
	for (int64_t index = 0; index < state.array_size(actions); ++index) {
		const Value action = state.at(actions, index);
		if (!gd::is_dict(action) || gd::bool_field(state, action.ref, key::disabled, false)) {
			continue;
		}
		const Atom action_id = text_or(state, action.ref, key::id, str(key::empty));
		if (excluded_id != key::empty && action_id == excluded_id) {
			continue;
		}
		const Atom label = gd::strip_edges(state, text_or(state, action.ref, key::label, str(key::empty)));
		if (label != key::empty) {
			return label;
		}
	}
	return key::empty;
}

Atom _skirmish_outcome_continuity_choice_line(State &state, DictRef session) {
	if (session_text(state, session, key::scenario_status) == key::victory) {
		return key::continuity_choice_skirmish_result_stays_self;
	}
	return key::continuity_choice_retry_starts_this_skirmish;
}

Atom _build_skirmish_aftermath_summary(State &state, DictRef session, DictRef scenario) {
	std::vector<Atom> lines;
	const Atom battle_aftermath = _last_battle_aftermath_text(state, session);
	if (battle_aftermath != key::empty) {
		lines.push_back(battle_aftermath);
	}
	const Atom outcome_text = _resolution_text(state, scenario, session_text(state, session, key::scenario_status));
	if (outcome_text != key::empty) {
		lines.push_back(outcome_text);
	}
	const Atom recent_events = scenario_script_rules::describe_recent_events(state, session, 3);
	if (recent_events != key::empty) {
		lines.push_back(gd::format(state, key::field_report_s, { str(recent_events) }));
	}
	return join_atoms(state, key::newline, lines);
}

Atom _progress_recap_context_line(State &state, DictRef session, DictRef scenario) {
	const Atom scenario_id = session_text(state, session, key::scenario_id);
	const Atom scenario_name = text_or(state, scenario, key::name, str(scenario_id));
	const Atom launch_mode = session_launch_mode(state, session);
	if (launch_mode == key::campaign) {
		const DictRef flags = session_flags(state, session);
		Atom campaign_id = text_or(state, flags, key::campaign_id, str(key::empty));
		if (campaign_id == key::empty) {
			campaign_id = _campaign_id_for_scenario(state, scenario_id);
		}
		const DictRef campaign = gd::content_row(state, ContentTable::Campaign, campaign_id);
		const Atom campaign_name = string_of(state, state.get(flags, str(key::campaign_name), state.get(campaign, str(key::name), str(campaign_id))));
		Atom chapter_label = text_or(state, flags, key::campaign_chapter_label, str(key::empty));
		if (chapter_label == key::empty) {
			chapter_label = _campaign_chapter_label(state, campaign, scenario_id, scenario_name);
		}
		if (campaign_name != key::empty && chapter_label != key::empty) {
			return gd::format(state, key::campaign_s_s_day_d, { str(campaign_name), str(chapter_label), int_value(session_day(state, session)) });
		}
		if (campaign_name != key::empty) {
			return gd::format(state, key::campaign_s_day_d, { str(campaign_name), int_value(session_day(state, session)) });
		}
	}
	return gd::format(state, key::s_s_day_d_2,
			{ str(scenario_select_rules::launch_mode_label(state, launch_mode)), str(scenario_name), int_value(session_day(state, session)) });
}

Atom _progress_recap_status_line(State &state, DictRef session, DictRef preloaded_objective_surface) {
	DictRef objective_counts = _objective_progress_counts_from_surface(state, preloaded_objective_surface);
	if (gd::is_empty(state, objective_counts)) {
		objective_counts = _objective_progress_counts(state, session);
	}
	if (gd::is_empty(state, objective_counts)) {
		return key::empty;
	}
	Atom status_text = gd::format(state, key::current_progress_d_d_victory_complete, {
			int_value(gd::int_field(state, objective_counts, key::victory_met, 0)),
			int_value(gd::int_field(state, objective_counts, key::victory_total, 0)),
			int_value(gd::int_field(state, objective_counts, key::defeat_met, 0)),
			int_value(gd::int_field(state, objective_counts, key::defeat_total, 0)),
	});
	const Atom status = session_text(state, session, key::scenario_status);
	if (status != key::in_progress) {
		const Atom result = gd::format(state, key::result_s_2, { str(gd::capitalize(state, status)) });
		status_text = state.intern(state.text(status_text) + state.text(result));
	}
	return status_text;
}

Atom _progress_recap_recent_line(State &state, DictRef session, DictRef scenario, DictRef preloaded_objective_surface) {
	const Atom recent_events = scenario_script_rules::describe_recent_events(state, session, 2);
	if (recent_events != key::empty) {
		return gd::format(state, key::recently_resolved_s, { str(recent_events) });
	}
	const Atom battle_aftermath = _last_battle_aftermath_compact_text(state, session);
	if (battle_aftermath != key::empty) {
		return gd::format(state, key::recently_resolved_s, { str(battle_aftermath) });
	}
	const Atom status = session_text(state, session, key::scenario_status);
	if (status != key::in_progress) {
		const Atom scenario_summary = session_text(state, session, key::scenario_summary);
		const Atom summary = scenario_summary != key::empty ? scenario_summary : _resolution_text(state, scenario, status);
		if (summary != key::empty) {
			return gd::format(state, key::recently_resolved_s, { str(summary) });
		}
	}
	std::vector<Atom> completed;
	if (_objective_progress_surface_is_complete(state, preloaded_objective_surface)) {
		// completed = surface.completed_objectives.duplicate(true), its first two
		// items: the copy is only joined.
		const ArrayRef source = gd::as_array(gd::index(state, preloaded_objective_surface, str(key::completed_objectives)));
		const int64_t count = std::min<int64_t>(state.array_size(source), 2);
		for (int64_t index = 0; index < count; ++index) {
			completed.push_back(string_of(state, state.at(source, index)));
		}
	} else {
		const ArrayRef labels = _completed_objective_labels(state, session, 2);
		for (int64_t index = 0; index < state.array_size(labels); ++index) {
			completed.push_back(string_of(state, state.at(labels, index)));
		}
	}
	if (!completed.empty()) {
		return gd::format(state, key::recently_resolved_s, { str(join_atoms(state, key::semicolon_space, completed)) });
	}
	return key::empty;
}

Atom _progress_recap_next_step_line(State &state, DictRef session, DictRef scenario, DictRef preloaded_objective_surface) {
	if (session_text(state, session, key::scenario_status) != key::in_progress) {
		return gd::format(state, key::next_step_s, { str(_resolved_next_step_text(state, session, scenario)) });
	}
	const bool objective_surface_complete = _objective_progress_surface_is_complete(state, preloaded_objective_surface);
	const Atom next_objective = objective_surface_complete ? text_or(state, preloaded_objective_surface, key::next_objective, str(key::empty))
														   : _next_unmet_victory_objective_label(state, session);
	if (next_objective != key::empty) {
		return gd::format(state, key::next_step_push_toward_s, { str(next_objective) });
	}
	const DictRef objective_counts = objective_surface_complete ? _objective_progress_counts_from_surface(state, preloaded_objective_surface)
																: _objective_progress_counts(state, session);
	if (gd::int_field(state, objective_counts, key::victory_total, 0) > 0) {
		return key::next_step_all_victory_objectives_are;
	}
	return key::next_step_scout_the_nearest_lane;
}

bool _objective_progress_surface_is_complete(State &state, DictRef surface) {
	for (const Atom field : { key::victory_total, key::victory_met, key::defeat_total, key::defeat_triggered, key::next_objective, key::completed_objectives }) {
		if (!state.has(surface, str(field))) {
			return false;
		}
	}
	Value completed;
	return !state.lookup(surface, str(key::completed_objectives), completed) || gd::is_array(completed);
}

DictRef _objective_progress_counts_from_surface(State &state, DictRef surface) {
	if (!_objective_progress_surface_is_complete(state, surface)) {
		return state.new_dict();
	}
	const DictRef counts = state.new_dict();
	state.set(counts, str(key::victory_total), int_value(gd::int_field(state, surface, key::victory_total, 0)));
	state.set(counts, str(key::victory_met), int_value(gd::int_field(state, surface, key::victory_met, 0)));
	state.set(counts, str(key::defeat_total), int_value(gd::int_field(state, surface, key::defeat_total, 0)));
	state.set(counts, str(key::defeat_met), int_value(gd::int_field(state, surface, key::defeat_triggered, 0)));
	return counts;
}

DictRef _objective_progress_counts(State &state, DictRef session) {
	// session == null: a view is never null.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return state.new_dict();
	}
	const DictRef scenario = scenario_record_for_session(state, session);
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return state.new_dict();
	}
	const DictRef counts = state.new_dict();
	state.set(counts, str(key::victory_total), int_value(0));
	state.set(counts, str(key::victory_met), int_value(0));
	state.set(counts, str(key::defeat_total), int_value(0));
	state.set(counts, str(key::defeat_met), int_value(0));
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		state.set(counts, str(key::victory_total), int_value(gd::add(gd::int_field(state, counts, key::victory_total, 0), 1)));
		if (_objective_met(state, session, objective.ref)) {
			state.set(counts, str(key::victory_met), int_value(gd::add(gd::int_field(state, counts, key::victory_met, 0), 1)));
		}
	}
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::defeat))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		state.set(counts, str(key::defeat_total), int_value(gd::add(gd::int_field(state, counts, key::defeat_total, 0), 1)));
		if (_objective_met(state, session, objective.ref)) {
			state.set(counts, str(key::defeat_met), int_value(gd::add(gd::int_field(state, counts, key::defeat_met, 0), 1)));
		}
	}
	return counts;
}

Atom _next_unmet_victory_objective_label(State &state, DictRef session) {
	const DictRef scenario = scenario_record_for_session(state, session);
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return key::empty;
	}
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		if (!_objective_met(state, session, objective.ref)) {
			return _objective_label(state, session, objective.ref);
		}
	}
	return key::empty;
}

ArrayRef _completed_objective_labels(State &state, DictRef session, int64_t limit) {
	const DictRef scenario = scenario_record_for_session(state, session);
	const Value objectives = objective_definitions(state, scenario);
	const ArrayRef labels = state.new_array();
	if (!gd::is_dict(objectives)) {
		return labels;
	}
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (!gd::is_dict(objective) || !_objective_met(state, session, objective.ref)) {
			continue;
		}
		const Atom label = _objective_label(state, session, objective.ref);
		if (label != key::empty && !gd::array_has(state, labels, str(label))) {
			state.append(labels, str(label));
		}
		if (state.array_size(labels) >= limit) {
			break;
		}
	}
	return labels;
}

Atom _last_battle_aftermath_compact_text(State &state, DictRef session) {
	// session == null: a view is never null.
	return aftermath_lines(state, session, { key::headline, key::result_summary, key::reward_summary, key::world_summary, key::summary }, 2,
			key::space_bar_space);
}

Atom _resolved_next_step_text(State &state, DictRef session, DictRef scenario) {
	const Atom launch_mode = session_launch_mode(state, session);
	if (session_text(state, session, key::scenario_status) == key::victory) {
		if (launch_mode == key::campaign) {
			const Atom next_chapter = _next_campaign_chapter_label(state, session, scenario);
			if (next_chapter != key::empty) {
				return gd::format(state, key::open_s_or_replay_this_chapter, { str(next_chapter) });
			}
			return key::return_to_the_campaign_board_this;
		}
		return key::return_to_the_menu_or_retry;
	}
	if (launch_mode == key::campaign) {
		return key::retry_this_chapter_from_the_outcome;
	}
	return key::retry_this_skirmish_from_the_outcome;
}

Atom _outcome_next_play_action_line(State &state, DictRef session, DictRef scenario) {
	const Atom launch_mode = session_launch_mode(state, session);
	if (session_text(state, session, key::scenario_status) == key::victory) {
		if (launch_mode == key::campaign) {
			const Atom next_chapter = _next_campaign_chapter_label(state, session, scenario);
			if (next_chapter != key::empty) {
				return gd::format(state, key::next_play_action_save_this_outcome, { str(next_chapter) });
			}
			return key::next_play_action_save_this_outcome_2;
		}
		return key::next_play_action_save_this_outcome_3;
	}
	if (launch_mode == key::campaign) {
		return key::next_play_action_save_this_outcome_4;
	}
	return key::next_play_action_save_this_outcome_5;
}

Atom _campaign_id_for_scenario(State &state, Atom scenario_id) {
	if (scenario_id == key::empty) {
		return key::empty;
	}
	// ContentService.load_json(ContentService.CAMPAIGNS_PATH).
	const DictRef campaigns = gd::content_file(state, key::res_archive_authored_scenarios_2026_10);
	for (const Value &campaign : gd::field_items(state, campaigns, str(key::items))) {
		if (!gd::is_dict(campaign)) {
			continue;
		}
		for (const Value &entry : gd::field_items(state, campaign.ref, str(key::scenarios))) {
			if (gd::is_dict(entry) && text_or(state, entry.ref, key::scenario_id, str(key::empty)) == scenario_id) {
				return text_or(state, campaign.ref, key::id, str(key::empty));
			}
		}
	}
	return key::empty;
}

Atom _campaign_chapter_label(State &state, DictRef campaign, Atom scenario_id, Atom fallback) {
	for (const Value &entry : gd::field_items(state, campaign, str(key::scenarios))) {
		if (!gd::is_dict(entry) || text_or(state, entry.ref, key::scenario_id, str(key::empty)) != scenario_id) {
			continue;
		}
		const int64_t chapter_index = gd::int_field(state, entry.ref, key::chapter_index, 0);
		const Atom chapter_title = text_or(state, entry.ref, key::chapter_title, str(key::empty));
		if (chapter_index > 0 && chapter_title != key::empty) {
			return gd::format(state, key::chapter_d_s, { int_value(chapter_index), str(chapter_title) });
		}
		if (chapter_title != key::empty) {
			return chapter_title;
		}
		return text_or(state, entry.ref, key::label, str(fallback));
	}
	return fallback;
}

Atom _next_campaign_chapter_label(State &state, DictRef session, DictRef scenario) {
	(void)scenario;
	const Atom session_scenario_id = session_text(state, session, key::scenario_id);
	Atom campaign_id = text_or(state, session_flags(state, session), key::campaign_id, str(key::empty));
	if (campaign_id == key::empty) {
		campaign_id = _campaign_id_for_scenario(state, session_scenario_id);
	}
	const DictRef campaign = gd::content_row(state, ContentTable::Campaign, campaign_id);
	bool found_current = false;
	for (const Value &entry : gd::field_items(state, campaign, str(key::scenarios))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom scenario_id = text_or(state, entry.ref, key::scenario_id, str(key::empty));
		if (found_current && scenario_id != key::empty) {
			const DictRef next_scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
			return _campaign_chapter_label(state, campaign, scenario_id, text_or(state, next_scenario, key::name, str(scenario_id)));
		}
		if (scenario_id == session_scenario_id) {
			found_current = true;
		}
	}
	return key::empty;
}

Atom _last_battle_aftermath_text(State &state, DictRef session) {
	// session == null: a view is never null.
	return aftermath_lines(state, session,
			{ key::headline, key::result_summary, key::reward_summary, key::artifact_summary, key::force_summary, key::world_summary, key::summary,
					key::resource_summary, key::army_summary, key::pressure_summary, key::recovery_summary, key::front_summary,
					key::logistics_summary, key::commander_summary },
			0, key::newline);
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
