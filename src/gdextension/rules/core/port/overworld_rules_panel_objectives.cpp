// OverworldRules for the overworld panels (Phase 7, slice 7.8): objectives,
// their boards and stakes, frontier threats and defense readiness warnings.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

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

// String(d.get(field, "")).
Atom text_of(State &state, DictRef dict, Atom field) {
	return text_or(state, dict, field, str(key::empty));
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

// separator.join(array): each item as String(item).
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> parts;
	for (int64_t index = 0; index < state.array_size(array); ++index) {
		parts.push_back(string_of(state, state.at(array, index)));
	}
	return join_atoms(state, separator, parts);
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

bool has_atom(const std::vector<Atom> &atoms, Atom atom) {
	return std::find(atoms.begin(), atoms.end(), atom) != atoms.end();
}

// "" if n == 1 else "s".
Value plural_s(int64_t n) {
	return str(n == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s));
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

// var x: Array = d.get(field, []).
ArrayRef array_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_array(found);
	}
	return state.new_array();
}

} // namespace

namespace overworld_rules {

Atom _scenario_opening_objective_summary(State &state, DictRef session, DictRef scenario) {
	return scenario_rules::_opening_objective_summary(state, session, scenario);
}

ArrayRef _scenario_enemy_operational_lines(State &state, DictRef session, DictRef scenario) {
	return scenario_rules::_enemy_operational_lines(state, session, scenario);
}

Atom _scenario_first_contact_summary(State &state, DictRef scenario) {
	return scenario_rules::_first_contact_summary(state, scenario);
}

ArrayRef _scenario_objective_labels_from_bucket(State &state, DictRef session, const Value &bucket, int64_t limit) {
	return scenario_rules::_objective_labels_from_bucket(state, session, bucket, limit);
}

bool _scenario_is_objective_met(State &state, DictRef session, Atom objective_id, Atom bucket) {
	return scenario_rules::is_objective_met(state, session, objective_id, bucket);
}

Atom _scenario_describe_objectives(State &state, DictRef session) {
	return scenario_rules::describe_objectives(state, session);
}

Atom _describe_recent_events(State &state, DictRef session, int64_t limit) {
	return scenario_script_rules::describe_recent_events(state, session, limit);
}

Atom _describe_enemy_threats(State &state, DictRef session) {
	return enemy_turn_rules::describe_threats(state, session);
}

DictRef describe_objective_header_surfaces(State &state, DictRef session) {
	const DictRef surface = _objective_stakes_surface(state, session);
	Atom progress_recap = key::empty;
	if (!gd::is_empty(state, surface)) {
		progress_recap = scenario_rules::describe_session_progress_recap_from_normalized_session(state, session, false, surface);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::objective_brief), str(_describe_objective_brief_from_surface(state, surface)));
	const DictRef preloaded_progress = state.new_dict();
	state.set(preloaded_progress, str(key::progress_recap), str(progress_recap));
	state.set(result, str(key::objective_stakes), str(_describe_objective_stakes_board_from_surface(state, session, surface, preloaded_progress)));
	state.set(result, str(key::progress_recap), str(progress_recap));
	return result;
}

Atom _describe_objective_brief_from_surface(State &state, DictRef surface) {
	if (gd::is_empty(state, surface)) {
		return key::objectives_unavailable;
	}

	Atom line = gd::format(state, key::s_objectives_d_d,
			{ str(text_or(state, surface, key::mode_label, str(key::Scenario))), int_value(gd::int_field(state, surface, key::victory_met, 0)),
					int_value(gd::int_field(state, surface, key::victory_total, 0)) });
	const Atom next_objective = text_of(state, surface, key::next_objective);
	if (next_objective != key::empty) {
		line = concat(state, line, gd::format(state, key::next_s_2, { str(_short_player_text(state, next_objective, 32)) }));
	} else if (gd::int_field(state, surface, key::victory_total, 0) > 0) {
		line = concat(state, line, key::victory_ready);
	}
	const Atom watch_objective = text_of(state, surface, key::watch_objective);
	if (watch_objective != key::empty) {
		line = concat(state, line, gd::format(state, key::watch_s_2, { str(_short_player_text(state, watch_objective, 28)) }));
	}
	return line;
}

Atom describe_objective_stakes_board(State &state, DictRef session) {
	return _describe_objective_stakes_board_from_surface(state, session, _objective_stakes_surface(state, session), state.new_dict());
}

Atom _describe_objective_stakes_board_from_surface(State &state, DictRef session, DictRef surface, DictRef preloaded_progress) {
	if (gd::is_empty(state, surface)) {
		return key::objective_stakes_no_authored_scenario_objectives;
	}

	std::vector<Atom> lines;
	lines.push_back(key::objective_stakes_2);
	lines.push_back(text_or(state, surface, key::context_line, str(key::scenario_context_unavailable)));
	lines.push_back(gd::format(state, key::progress_d_d_victory_complete_d,
			{ int_value(gd::int_field(state, surface, key::victory_met, 0)), int_value(gd::int_field(state, surface, key::victory_total, 0)),
					int_value(gd::int_field(state, surface, key::defeat_triggered, 0)), int_value(gd::int_field(state, surface, key::defeat_total, 0)) }));
	const Atom campaign_stakes = text_of(state, surface, key::campaign_stakes);
	if (campaign_stakes != key::empty) {
		lines.push_back(gd::format(state, key::campaign_stakes_s, { str(campaign_stakes) }));
	} else {
		lines.push_back(key::skirmish_context_self_contained_run_no);
	}
	const Atom next_objective = text_of(state, surface, key::next_objective);
	lines.push_back(gd::format(state, key::next_objective_s,
			{ str(next_objective != key::empty ? next_objective : static_cast<Atom>(key::all_victory_objectives_are_complete)) }));

	const ArrayRef completed = array_field(state, surface, key::completed_objectives);
	const ArrayRef incomplete = array_field(state, surface, key::incomplete_objectives);
	lines.push_back(gd::format(state, key::complete_s, { str(_join_limited_labels(state, completed, 3, key::none)) }));
	lines.push_back(gd::format(state, key::incomplete_s, { str(_join_limited_labels(state, incomplete, 3, key::none)) }));
	const ArrayRef defeat_watch = array_field(state, surface, key::defeat_watch);
	lines.push_back(gd::format(state, key::defeat_watch_s, { str(_join_limited_labels(state, defeat_watch, 2, key::clear)) }));

	const Atom victory_text = text_of(state, surface, key::victory_text);
	if (victory_text != key::empty) {
		lines.push_back(gd::format(state, key::win_s, { str(victory_text) }));
	}
	const Atom defeat_text = text_of(state, surface, key::defeat_text);
	if (defeat_text != key::empty) {
		lines.push_back(gd::format(state, key::lose_s, { str(defeat_text) }));
	}
	const Atom campaign_arc = text_of(state, surface, key::campaign_arc);
	if (campaign_arc != key::empty) {
		lines.push_back(gd::format(state, key::campaign_arc_s, { str(campaign_arc) }));
	}
	Atom progress_recap = key::empty;
	if (state.has(preloaded_progress, str(key::progress_recap))) {
		progress_recap = text_of(state, preloaded_progress, key::progress_recap);
	} else {
		progress_recap = scenario_rules::describe_session_progress_recap(state, session, false);
	}
	if (progress_recap != key::empty) {
		lines.push_back(progress_recap);
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_objective_board(State &state, DictRef session) {
	scenario_rules::normalize_scenario_state(state, session, true);
	// var scenario := ContentService.get_scenario_readonly(session.scenario_id), unused.
	(void)gd::content_row(state, ContentTable::Scenario, session_text(state, session, key::scenario_id));
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return key::objectives_no_authored_objectives;
	}

	int64_t victory_total = 0;
	int64_t victory_met = 0;
	int64_t defeat_total = 0;
	int64_t defeat_triggered = 0;
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (gd::is_dict(objective)) {
			victory_total += 1;
			if (_scenario_is_objective_met(state, session, text_of(state, objective.ref, key::id), key::victory)) {
				victory_met += 1;
			}
		}
	}
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::defeat))) {
		if (gd::is_dict(objective)) {
			defeat_total += 1;
			if (_scenario_is_objective_met(state, session, text_of(state, objective.ref, key::id), key::defeat)) {
				defeat_triggered += 1;
			}
		}
	}
	const Atom described = _scenario_describe_objectives(state, session);
	const Atom progress_recap = scenario_rules::describe_session_progress_recap(state, session, false);
	return gd::format(state, key::objective_board_victory_d_d_defeat,
			{ int_value(victory_met), int_value(victory_total), int_value(defeat_triggered), int_value(defeat_total),
					str(gd::format(state, key::s_s_12, { str(described), str(progress_recap) })) });
}

Atom describe_objectives(State &state, DictRef session) {
	return describe_objective_board(state, session);
}

DictRef _objective_stakes_surface(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	// session == null: a view is never null.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return state.new_dict();
	}
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, session_text(state, session, key::scenario_id));
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return state.new_dict();
	}

	int64_t victory_total = 0;
	int64_t victory_met = 0;
	int64_t defeat_total = 0;
	int64_t defeat_triggered = 0;
	const ArrayRef completed = state.new_array();
	const ArrayRef incomplete = state.new_array();
	const ArrayRef defeat_watch = state.new_array();
	Atom next_objective = key::empty;
	Atom watch_objective = key::empty;

	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		victory_total += 1;
		const Atom label = _scenario_objective_player_label(state, session, objective.ref);
		if (_scenario_objective_met(state, session, objective.ref)) {
			victory_met += 1;
			if (label != key::empty) {
				state.append(completed, str(label));
			}
		} else {
			if (label != key::empty) {
				state.append(incomplete, str(label));
				if (next_objective == key::empty) {
					next_objective = label;
				}
			}
		}
	}

	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::defeat))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		defeat_total += 1;
		const Atom label = _scenario_objective_player_label(state, session, objective.ref);
		if (_scenario_objective_met(state, session, objective.ref)) {
			defeat_triggered += 1;
		}
		if (label != key::empty) {
			state.append(defeat_watch, str(label));
			if (watch_objective == key::empty) {
				watch_objective = label;
			}
		}
	}

	const DictRef campaign_context = _campaign_context_for_session(state, session, scenario);
	const DictRef surface = state.new_dict();
	state.set(surface, str(key::mode_label), str(text_or(state, campaign_context, key::mode_label, str(key::Scenario))));
	state.set(surface, str(key::context_line), str(text_of(state, campaign_context, key::context_line)));
	state.set(surface, str(key::campaign_stakes), str(text_of(state, campaign_context, key::campaign_stakes)));
	state.set(surface, str(key::campaign_arc), str(text_of(state, campaign_context, key::campaign_arc)));
	state.set(surface, str(key::victory_total), int_value(victory_total));
	state.set(surface, str(key::victory_met), int_value(victory_met));
	state.set(surface, str(key::defeat_total), int_value(defeat_total));
	state.set(surface, str(key::defeat_triggered), int_value(defeat_triggered));
	state.set(surface, str(key::next_objective), str(next_objective));
	state.set(surface, str(key::watch_objective), str(watch_objective));
	state.set(surface, str(key::completed_objectives), array_value(completed));
	state.set(surface, str(key::incomplete_objectives), array_value(incomplete));
	state.set(surface, str(key::defeat_watch), array_value(defeat_watch));
	state.set(surface, str(key::victory_text), str(text_of(state, objectives.ref, key::victory_text)));
	state.set(surface, str(key::defeat_text), str(text_of(state, objectives.ref, key::defeat_text)));
	return surface;
}

DictRef _campaign_context_for_session(State &state, DictRef session, DictRef scenario) {
	const Atom scenario_name = text_or(state, scenario, key::name, str(session_text(state, session, key::scenario_id)));
	const Atom launch_mode = session_state_store::normalize_launch_mode(state, gd::index(state, session, str(key::launch_mode)));
	if (launch_mode != key::campaign) {
		const DictRef context = state.new_dict();
		state.set(context, str(key::mode_label), str(key::Skirmish));
		state.set(context, str(key::context_line), str(gd::format(state, key::skirmish_s_day_d, { str(scenario_name), int_value(session_day(state, session)) })));
		state.set(context, str(key::campaign_stakes), str(key::empty));
		state.set(context, str(key::campaign_arc), str(key::empty));
		return context;
	}

	Atom campaign_id = text_of(state, session_flags(state, session), key::campaign_id);
	if (campaign_id == key::empty) {
		// CampaignRules stays GDScript (D-f): a host call.
		campaign_id = gd::to_string(gd::call_static(state, key::campaign_rules_script, key::get_campaign_id_for_scenario,
				{ str(session_text(state, session, key::scenario_id)) }));
	}
	const DictRef campaign = gd::content_row(state, ContentTable::Campaign, campaign_id);
	const DictRef entry = _campaign_scenario_entry(state, campaign, session_text(state, session, key::scenario_id));
	const DictRef flags = session_flags(state, session);
	const Atom campaign_name = text_or(state, flags, key::campaign_name, state.get(campaign, str(key::name), str(campaign_id)));
	const Atom chapter_label = text_or(state, flags, key::campaign_chapter_label, state.get(entry, str(key::label), str(scenario_name)));
	const DictRef context = state.new_dict();
	state.set(context, str(key::mode_label), str(key::Campaign));
	state.set(context, str(key::context_line),
			str(gd::format(state, key::campaign_s_s_day_d, { str(campaign_name), str(chapter_label), int_value(session_day(state, session)) })));
	state.set(context, str(key::campaign_stakes), str(text_of(state, entry, key::stakes)));
	state.set(context, str(key::campaign_arc), str(text_of(state, campaign, key::arc_goal)));
	return context;
}

DictRef _campaign_scenario_entry(State &state, DictRef campaign, Atom scenario_id) {
	for (const Value &entry : gd::field_items(state, campaign, str(key::scenarios))) {
		if (gd::is_dict(entry) && text_of(state, entry.ref, key::scenario_id) == scenario_id) {
			return entry.ref;
		}
	}
	return state.new_dict();
}

Atom _join_limited_labels(State &state, ArrayRef labels, int64_t limit, Atom fallback) {
	if (state.array_size(labels) == 0) {
		return fallback;
	}
	std::vector<Atom> visible;
	const int64_t shown = compat::engine_min<int64_t>(compat::engine_max<int64_t>(1, limit), state.array_size(labels));
	for (int64_t index = 0; index < shown; ++index) {
		visible.push_back(string_of(state, state.at(labels, index)));
	}
	const int64_t visible_size = static_cast<int64_t>(visible.size());
	if (state.array_size(labels) > visible_size) {
		visible.push_back(gd::format(state, key::d_more_2, { int_value(state.array_size(labels) - visible_size) }));
	}
	return join_atoms(state, key::semicolon_space, visible);
}

Atom describe_frontier_threats(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	std::vector<Atom> lines;
	lines.push_back(key::frontier_watch);
	const Atom global_threats = _describe_enemy_threats(state, session);
	if (global_threats == key::empty) {
		lines.push_back(key::no_hostile_factions_are_active_2);
	} else {
		lines.push_back(global_threats);
	}
	const Atom local_warning = _local_visible_threat_summary(state, session, key::empty);
	if (local_warning != key::empty) {
		lines.push_back(gd::format(state, key::local_watch_s, { str(local_warning) }));
	}
	const Atom occupation_watch = _occupied_town_watch_summary(state, session);
	if (occupation_watch != key::empty) {
		lines.push_back(gd::format(state, key::occupation_watch_s, { str(occupation_watch) }));
	}
	lines.push_back(gd::format(state, key::defense_readiness_s, { str(describe_defense_readiness_warnings(state, session, 2)) }));
	return join_atoms(state, key::newline, lines);
}

Atom describe_defense_readiness_warnings(State &state, DictRef session, int64_t limit) {
	normalize_overworld_state(state, session);
	const ArrayRef items = _defense_readiness_warning_items(state, session);
	if (state.array_size(items) == 0) {
		return key::no_exposed_town_or_route_defense;
	}
	std::vector<Atom> fragments;
	const int64_t max_items = compat::engine_clamp<int64_t>(limit, 1, 4);
	const int64_t shown = compat::engine_min<int64_t>(max_items, state.array_size(items));
	for (int64_t index = 0; index < shown; ++index) {
		const DictRef item = gd::as_dict(state.at(items, index));
		const Atom label = text_or(state, item, key::label, str(key::town_front));
		const Atom context = _short_player_text(state, text_of(state, item, key::context), 128);
		const Atom why = _short_player_text(state, text_of(state, item, key::why), 112);
		const Atom next_step = _short_player_text(state, text_of(state, item, key::next_step_2), 112);
		fragments.push_back(gd::format(state, key::s_s_why_s_next_s, { str(label), str(context), str(why), str(next_step) }));
	}
	if (state.array_size(items) > max_items) {
		const int64_t more = state.array_size(items) - max_items;
		fragments.push_back(gd::format(state, key::d_more_town_front_warning_s, { int_value(more), plural_s(more) }));
	}
	return join_atoms(state, key::space_bar_space, fragments);
}

Atom describe_town_defense_readiness_warning(State &state, DictRef session, DictRef town) {
	normalize_overworld_state(state, session);
	if (gd::is_empty(state, town)) {
		return key::no_town_front_is_selected;
	}
	const DictRef item = _defense_readiness_warning_item(state, session, town, true);
	if (gd::is_empty(state, item)) {
		return key::no_town_front_is_selected;
	}
	const Atom label = text_or(state, item, key::label, str(_town_name(state, town)));
	const Atom context = _short_player_text(state, text_of(state, item, key::context), 132);
	const Atom why = _short_player_text(state, text_of(state, item, key::why), 112);
	const Atom next_step = _short_player_text(state, text_of(state, item, key::next_step_2), 112);
	return gd::format(state, key::s_s_why_s_next_s, { str(label), str(context), str(why), str(next_step) });
}

ArrayRef _defense_readiness_warning_items(State &state, DictRef session) {
	const ArrayRef items = state.new_array();
	// session == null: a view is never null.
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || text_or(state, town.ref, key::owner, str(key::neutral)) != key::player) {
			continue;
		}
		const DictRef item = _defense_readiness_warning_item(state, session, town.ref, false);
		if (!gd::is_empty(state, item)) {
			state.append(items, dict_value(item));
		}
	}
	gd::sort_custom(state, items, [&state](const Value &a, const Value &b) {
		return gd::int_field(state, gd::as_dict(a), key::severity, 0) > gd::int_field(state, gd::as_dict(b), key::severity, 0);
	});
	return items;
}

DictRef _defense_readiness_warning_item(State &state, DictRef session, DictRef town, bool include_steady) {
	// session == null: a view is never null.
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const Value session_value = dict_value(session);
	const int64_t readiness = town_battle_readiness(state, town, session_value);
	const Atom defense = _town_defense_summary(state, town);
	const DictRef logistics = town_logistics_state(state, session, town);
	const DictRef recovery = town_recovery_state(state, session, town);
	const DictRef capital_project = town_capital_project_state(state, town, session_value);
	const DictRef occupation = town_occupation_state(state, session, town);
	const DictRef front = _town_front_state(state, session, town, state.new_dict());
	const DictRef threat_state = _town_command_risk_state(state, session, town, true);
	const bool objective_anchor = _raid_target_is_objective_anchor(state, session, key::town, text_of(state, town, key::placement_id));
	const ArrayRef pressure_parts = _defense_readiness_pressure_parts(state, threat_state, front, occupation);
	const bool logistics_alert = gd::int_field(state, logistics, key::disrupted_count, 0) > 0
			|| gd::int_field(state, logistics, key::threatened_count, 0) > 0
			|| gd::int_field(state, logistics, key::support_gap, 0) > 0;
	const bool recovery_alert = gd::bool_field(state, recovery, key::active, false);
	const bool capital_alert = gd::bool_field(state, capital_project, key::vulnerable, false);
	const bool low_readiness = readiness <= 18 || defense == key::thin_watch;
	const bool strained_readiness = readiness <= 30;
	const bool has_pressure = state.array_size(pressure_parts) != 0;
	const bool has_warning = has_pressure
			|| logistics_alert
			|| recovery_alert
			|| capital_alert
			|| low_readiness
			|| gd::bool_field(state, occupation, key::active, false);
	if (!has_warning && !include_steady) {
		return state.new_dict();
	}
	int64_t severity = 0;
	if (gd::int_field(state, threat_state, key::visible_pressuring, 0) > 0 || gd::int_field(state, threat_state, key::siege_progress, 0) > 0) {
		severity += 5;
	} else if (gd::int_field(state, threat_state, key::visible_marching, 0) > 0) {
		severity += 3;
	}
	if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
		severity += 2;
	}
	if (gd::bool_field(state, front, key::active, false)) {
		severity += text_of(state, front, key::mode) == key::retake ? 2 : 1;
	}
	if (gd::bool_field(state, occupation, key::active, false)) {
		severity += 2;
	}
	if (low_readiness) {
		severity += 2;
	} else if (strained_readiness) {
		severity += 1;
	}
	if (logistics_alert) {
		severity += 2;
	}
	if (recovery_alert || capital_alert || objective_anchor) {
		severity += 1;
	}
	Atom status = key::ready;
	if (low_readiness) {
		status = key::under_defended;
	} else if (has_warning) {
		status = key::pressured;
	} else if (strained_readiness) {
		status = key::guarded;
	}
	std::vector<Atom> context_parts;
	if (has_pressure) {
		context_parts.push_back(gd::format(state, key::pressure_s, { str(join_array(state, key::semicolon_space, pressure_parts)) }));
	}
	context_parts.push_back(gd::format(state, key::readiness_d_text, { int_value(readiness) }));
	if (defense != key::empty) {
		context_parts.push_back(defense);
	}
	if (text_of(state, logistics, key::summary) != key::empty) {
		context_parts.push_back(gd::format(state, key::routes_s, { str(text_of(state, logistics, key::summary)) }));
	}
	if (text_of(state, logistics, key::impact_summary) != key::empty && (logistics_alert || include_steady)) {
		context_parts.push_back(gd::format(state, key::economy_frontier_s, { str(text_of(state, logistics, key::impact_summary)) }));
	}
	if (recovery_alert) {
		context_parts.push_back(text_of(state, recovery, key::summary));
	}
	if (capital_alert && text_of(state, capital_project, key::vulnerability_summary) != key::empty) {
		context_parts.push_back(text_of(state, capital_project, key::vulnerability_summary));
	}
	if (objective_anchor) {
		context_parts.push_back(key::objective_anchor);
	}
	const DictRef item = state.new_dict();
	state.set(item, str(key::label), str(gd::format(state, key::s_s, { str(_town_name(state, town)), str(status) })));
	state.set(item, str(key::context), str(join_atoms(state, key::space_bar_space, context_parts)));
	state.set(item, str(key::why),
			str(_defense_readiness_warning_why(state, objective_anchor, has_pressure, logistics_alert, recovery_alert, capital_alert, low_readiness)));
	state.set(item, str(key::next_step_2),
			str(_defense_readiness_next_step(state, has_pressure, logistics_alert, recovery_alert, capital_alert, low_readiness,
					gd::bool_field(state, front, key::active, false), readiness)));
	state.set(item, str(key::severity), int_value(severity));
	return item;
}

ArrayRef _defense_readiness_pressure_parts(State &state, DictRef threat_state, DictRef front, DictRef occupation) {
	const ArrayRef parts = state.new_array();
	if (gd::int_field(state, threat_state, key::visible_pressuring, 0) > 0) {
		const ArrayRef pressuring = array_field(state, threat_state, key::pressuring_commanders);
		if (gd::int_field(state, threat_state, key::visible_pressuring, 0) == 1 && state.array_size(pressuring) != 0) {
			state.append(parts, str(gd::format(state, key::s_at_the_approaches, { str(string_of(state, state.at(pressuring, 0))) })));
		} else {
			state.append(parts, str(gd::format(state, key::d_enemy_heroes_at_the_approaches, { int_value(gd::int_field(state, threat_state, key::visible_pressuring, 0)) })));
		}
	}
	if (gd::int_field(state, threat_state, key::visible_marching, 0) > 0) {
		const ArrayRef marching = array_field(state, threat_state, key::marching_commanders);
		const int64_t distance = compat::engine_max<int64_t>(1, gd::int_field(state, threat_state, key::nearest_goal_distance, 9999));
		if (gd::int_field(state, threat_state, key::visible_marching, 0) == 1 && state.array_size(marching) != 0) {
			state.append(parts, str(gd::format(state, key::s_can_reach_in_d_day, { str(string_of(state, state.at(marching, 0))), int_value(distance), plural_s(distance) })));
		} else {
			state.append(parts, str(gd::format(state, key::d_enemy_heroes_marching, { int_value(gd::int_field(state, threat_state, key::visible_marching, 0)) })));
		}
	}
	if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
		state.append(parts, str(key::hostile_movement_beyond_the_fog));
	}
	if (gd::int_field(state, threat_state, key::siege_progress, 0) > 0) {
		state.append(parts, str(gd::format(state, key::siege_d_d,
				{ int_value(gd::int_field(state, threat_state, key::siege_progress, 0)),
						int_value(compat::engine_max<int64_t>(1, gd::int_field(state, threat_state, key::siege_capture_progress, 1))) })));
	}
	if (gd::bool_field(state, front, key::active, false) && text_of(state, front, key::summary) != key::empty) {
		state.append(parts, str(text_of(state, front, key::summary)));
	}
	if (gd::bool_field(state, occupation, key::active, false) && text_of(state, occupation, key::summary) != key::empty) {
		state.append(parts, str(text_of(state, occupation, key::summary)));
	}
	return parts;
}

Atom _defense_readiness_warning_why(State &state, bool objective_anchor, bool has_pressure, bool logistics_alert, bool recovery_alert, bool capital_alert, bool low_readiness) {
	(void)state;
	if (objective_anchor) {
		return key::this_front_anchors_an_objective_while;
	}
	if (has_pressure) {
		return key::enemy_heroes_can_take_the_town;
	}
	if (logistics_alert) {
		return key::route_and_economy_pressure_weakens_readiness;
	}
	if (recovery_alert) {
		return key::recovery_pressure_keeps_troops_and_routes;
	}
	if (capital_alert) {
		return key::the_capital_chain_needs_linked_support;
	}
	if (low_readiness) {
		return key::low_readiness_leaves_the_garrison_brittle;
	}
	return key::control_income_recruitment_and_route_cover;
}

Atom _defense_readiness_next_step(State &state, bool has_pressure, bool logistics_alert, bool recovery_alert, bool capital_alert, bool low_readiness, bool front_active, int64_t readiness) {
	(void)state;
	if (has_pressure && low_readiness) {
		return key::recruit_reserves_or_build_readiness_then;
	}
	if (has_pressure) {
		return key::intercept_the_enemy_hero_before_ending;
	}
	if (logistics_alert || recovery_alert) {
		return key::send_a_town_response_order_or;
	}
	if (capital_alert) {
		return key::restore_linked_route_support_or_hold;
	}
	if (low_readiness || readiness <= 30) {
		return key::build_readiness_or_recruit_reserves_before;
	}
	if (front_active) {
		return key::hold_the_watch_and_keep_a;
	}
	return key::hold_the_watch_build_or_recruit;
}

Atom _local_visible_threat_summary(State &state, DictRef session, Atom fallback) {
	const Vector2i pos = hero_position(state, session);
	int64_t visible_contacts = 0;
	int64_t local_contacts = 0;
	Atom nearest_contact_name = key::empty;
	Atom nearest_contact_reason = key::empty;
	int64_t nearest_contact_distance = 99999;
	int64_t visible_enemy_towns = 0;
	int64_t visible_denied_sites = 0;
	int64_t visible_contested_fronts = 0;
	std::vector<Atom> visible_commander_names;
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter) || !overworld_level_rules::on_level(state, encounter, hero_level(state, session))) {
			continue;
		}
		if (is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		const int64_t x = gd::int_field(state, encounter.ref, key::x, -1);
		const int64_t y = gd::int_field(state, encounter.ref, key::y, -1);
		if (!is_tile_visible(state, session, x, y)) {
			continue;
		}
		visible_contacts += 1;
		const int64_t distance = gd::add(compat::absi(gd::sub(x, pos.x)), compat::absi(gd::sub(y, pos.y)));
		if (distance <= 3) {
			local_contacts += 1;
		}
		if (distance < nearest_contact_distance) {
			nearest_contact_distance = distance;
			nearest_contact_name = encounter_display_name(state, encounter.ref);
			nearest_contact_reason = text_of(state, encounter.ref, key::target_public_reason);
		}
		const Atom commander_name = encounter_commander_threat_label(state, encounter.ref);
		if (commander_name != key::empty && !has_atom(visible_commander_names, commander_name)) {
			visible_commander_names.push_back(commander_name);
		}
		if (text_of(state, encounter.ref, key::contested_by_faction_id) != key::empty) {
			visible_contested_fronts += 1;
		}
	}
	for (const Value &town : gd::field_items(state, overworld, str(key::towns))) {
		if (!gd::is_dict(town) || !overworld_level_rules::on_level(state, town, hero_level(state, session))) {
			continue;
		}
		if (text_or(state, town.ref, key::owner, str(key::neutral)) != key::enemy) {
			continue;
		}
		const int64_t town_x = gd::int_field(state, town.ref, key::x, -1);
		const int64_t town_y = gd::int_field(state, town.ref, key::y, -1);
		if (is_tile_visible(state, session, town_x, town_y)) {
			visible_enemy_towns += 1;
		}
	}
	for (const Atom nodes_key : { static_cast<Atom>(key::resource_nodes), static_cast<Atom>(key::artifact_nodes) }) {
		for (const Value &node : gd::field_items(state, overworld, str(nodes_key))) {
			if (!gd::is_dict(node) || !overworld_level_rules::on_level(state, node, hero_level(state, session))) {
				continue;
			}
			const Atom collector = text_of(state, node.ref, key::collected_by_faction_id);
			if (collector == key::empty || collector == key::player) {
				continue;
			}
			if (is_tile_visible(state, session, gd::int_field(state, node.ref, key::x, -1), gd::int_field(state, node.ref, key::y, -1))) {
				visible_denied_sites += 1;
			}
		}
	}
	std::vector<Atom> parts;
	if (local_contacts > 0) {
		Atom local_clause = gd::format(state, key::d_hostile_contact_s_operating_within, { int_value(local_contacts), plural_s(local_contacts) });
		if (nearest_contact_reason != key::empty) {
			local_clause = concat(state, local_clause, gd::format(state, key::s_3, { str(nearest_contact_reason) }));
		}
		parts.push_back(local_clause);
	} else if (nearest_contact_name != key::empty) {
		Atom nearest_clause = gd::format(state, key::nearest_hostile_contact_s_at_d, { str(nearest_contact_name), int_value(nearest_contact_distance) });
		if (nearest_contact_reason != key::empty) {
			nearest_clause = concat(state, nearest_clause, gd::format(state, key::s_3, { str(nearest_contact_reason) }));
		}
		parts.push_back(nearest_clause);
	} else if (visible_contacts > 0) {
		parts.push_back(gd::format(state, key::d_hostile_contact_s_visible_on, { int_value(visible_contacts), plural_s(visible_contacts) }));
	}
	if (visible_enemy_towns > 0) {
		parts.push_back(gd::format(state, key::d_enemy_held_town_s_currently, { int_value(visible_enemy_towns), plural_s(visible_enemy_towns) }));
	}
	if (visible_denied_sites > 0) {
		parts.push_back(gd::format(state, key::d_frontier_site_s_already_denied, { int_value(visible_denied_sites), plural_s(visible_denied_sites) }));
	}
	if (visible_contested_fronts > 0) {
		parts.push_back(gd::format(state, key::d_neutral_front_s_under_hostile, { int_value(visible_contested_fronts), plural_s(visible_contested_fronts) }));
	}
	if (!visible_commander_names.empty()) {
		const size_t shown_count = std::min<size_t>(2, visible_commander_names.size());
		const std::vector<Atom> shown_names(visible_commander_names.begin(), visible_commander_names.begin() + static_cast<std::ptrdiff_t>(shown_count));
		Atom commander_summary = gd::format(state, key::commanders_sighted_s, { str(join_atoms(state, key::comma_space, shown_names)) });
		if (visible_commander_names.size() > shown_names.size()) {
			commander_summary = concat(state, commander_summary,
					gd::format(state, key::d_more_3, { int_value(static_cast<int64_t>(visible_commander_names.size() - shown_names.size())) }));
		}
		parts.push_back(commander_summary);
	}
	if (parts.empty()) {
		return fallback;
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _occupied_town_watch_summary(State &state, DictRef session) {
	// session == null: a view is never null.
	std::vector<Atom> clauses;
	for (const Value &town_value : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town_value) || text_or(state, town_value.ref, key::owner, str(key::neutral)) != key::player) {
			continue;
		}
		const DictRef occupation = _town_occupation_state(state, session, town_value.ref);
		if (!gd::bool_field(state, occupation, key::active, false)) {
			continue;
		}
		Atom clause = text_or(state, occupation, key::compact_summary, str(_town_name(state, town_value.ref)));
		const DictRef front = _town_front_state(state, session, town_value.ref, state.new_dict());
		if (gd::bool_field(state, front, key::active, false) && text_of(state, front, key::mode) == key::retake) {
			clause = concat(state, clause, key::under_retake_pressure);
		}
		clauses.push_back(clause);
	}
	if (clauses.empty()) {
		return key::empty;
	}
	const size_t shown_count = std::min<size_t>(2, clauses.size());
	const std::vector<Atom> shown(clauses.begin(), clauses.begin() + static_cast<std::ptrdiff_t>(shown_count));
	Atom summary = join_atoms(state, key::semicolon_space, shown);
	if (clauses.size() > shown.size()) {
		const int64_t more = static_cast<int64_t>(clauses.size() - shown.size());
		summary = concat(state, summary, gd::format(state, key::d_more_holding_s, { int_value(more), plural_s(more) }));
	}
	return summary;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
