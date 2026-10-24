// OverworldRules for the overworld panels (Phase 7, slice 7.8): the dispatch, the
// event feed, route interception and the encounter and site surfaces.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x): stringify(), and the engine's for a float, a container or an object.
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

// String(d.get(name, fallback)).
Atom text_of(State &state, DictRef dict, Atom name, Atom fallback = key::empty) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

// String(x.get(name, fallback)) of an untyped receiver.
Atom vtext_of(State &state, const Value &object, Atom name, Atom fallback = key::empty) {
	return string_of(state, ai::vget(state, object, name, str(fallback)));
}

// String(d.get(name, "")).strip_edges().
Atom stripped(State &state, DictRef dict, Atom name) {
	return gd::strip_edges(state, text_of(state, dict, name));
}

// session.<name> of a SessionData String field.
Atom session_text(State &state, DictRef session, Atom name) {
	return gd::to_string(gd::index(state, session, str(name)));
}

// session.scenario_status != "in_progress" and session.scenario_summary != "".
bool outcome_pending(State &state, DictRef session) {
	return session_text(state, session, key::scenario_status) != key::in_progress
			&& session_text(state, session, key::scenario_summary) != key::empty;
}

// What `for x in value` visits, copied: the loop bodies make calls.
std::vector<Value> items_of(State &state, const Value &value) {
	const gd::Items listed = gd::items(state, value);
	return std::vector<Value>(listed.begin(), listed.end());
}

// What `for x in d.get(name, [])` visits, copied.
std::vector<Value> field_items_of(State &state, DictRef dict, Atom name) {
	const gd::Items listed = gd::field_items(state, dict, str(name));
	return std::vector<Value>(listed.begin(), listed.end());
}

// d.get(name, {}) passed on: the value, or a new Dictionary when missing.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// separator.join(strings) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &strings) {
	std::string joined;
	for (size_t index = 0; index < strings.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(strings[index]);
	}
	return state.intern(joined);
}

// separator.join(strings) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef strings) {
	std::vector<Atom> parts;
	const int64_t count = state.array_size(strings);
	for (int64_t index = 0; index < count; ++index) {
		parts.push_back(gd::to_string(state.at(strings, index)));
	}
	return join_atoms(state, separator, parts);
}

// parts.slice(0, min(limit, parts.size())).
void keep_first(std::vector<Atom> &parts, size_t limit) {
	if (parts.size() > limit) {
		parts.resize(limit);
	}
}

// "" if count == 1 else "s".
Atom plural(int64_t count) {
	return count == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
}

// text.to_lower() of ASCII text (ids humanized, the response labels of the
// shipped sites). Other text needs the engine's Unicode case tables.
Atom to_lower_ascii(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// text.to_lower() for finding ASCII words in it: outside ASCII only U+0130
// lowers to an ASCII letter ("i") and U+212A ("k"); every other character
// stays outside ASCII, where no ASCII word can match, so its bytes are kept.
std::string lower_for_find(const std::string &source) {
	std::string normalized;
	normalized.reserve(source.size());
	for (size_t index = 0; index < source.size(); ++index) {
		const unsigned char c = static_cast<unsigned char>(source[index]);
		if (c < 0x80) {
			normalized += static_cast<char>(c >= 'A' && c <= 'Z' ? c - 'A' + 'a' : c);
			continue;
		}
		if (c == 0xC4 && index + 1 < source.size() && static_cast<unsigned char>(source[index + 1]) == 0xB0) {
			normalized += 'i';
			++index;
			continue;
		}
		if (c == 0xE2 && index + 2 < source.size() && static_cast<unsigned char>(source[index + 1]) == 0x84
				&& static_cast<unsigned char>(source[index + 2]) == 0xAA) {
			normalized += 'k';
			index += 2;
			continue;
		}
		normalized += static_cast<char>(c);
	}
	return normalized;
}

// lower.find(word) >= 0.
bool has_word(State &state, const std::string &lower, Atom word) {
	return lower.find(state.text(word)) != std::string::npos;
}

} // namespace

namespace overworld_rules {

Atom describe_encounter_pressure(State &state, DictRef session, DictRef encounter, bool for_battle_prompt) {
	return _encounter_pressure_summary(state, session, encounter, for_battle_prompt);
}

Atom describe_encounter_readability_surface(State &state, DictRef session, DictRef encounter) {
	std::vector<Atom> lines;
	const ArrayRef role_parts = state.new_array();
	state.append(role_parts, str(_encounter_role_label(state, encounter)));
	state.append(role_parts, str(_encounter_risk_label(state, encounter)));
	state.append(role_parts, str(_encounter_difficulty_label(state, encounter)));
	const Atom role_line = join_array(state, key::space_bar_space, _non_empty_strings(state, role_parts));
	if (role_line != key::empty) {
		lines.push_back(gd::format(state, key::role_s, {str(role_line)}));
	}
	const Atom army_line = _encounter_army_surface(state, encounter, true);
	if (army_line != key::empty) {
		lines.push_back(gd::format(state, key::army_s, {str(army_line)}));
	}
	const Atom readiness_line = _encounter_readiness_surface(state, session, encounter, false);
	if (readiness_line != key::empty) {
		lines.push_back(readiness_line);
	}
	const Atom reward_line = _encounter_reward_surface(state, encounter);
	if (reward_line != key::empty) {
		lines.push_back(gd::format(state, key::reward_s_2, {str(reward_line)}));
	}
	const Atom guard_line = _encounter_guard_summary(state, encounter, dict_value(session));
	if (guard_line != key::empty) {
		lines.push_back(guard_line);
	}
	const Atom consequence_line = describe_encounter_consequence_surface(state, session, encounter, false);
	if (consequence_line != key::empty) {
		lines.push_back(consequence_line);
	}
	const Atom field_line = _encounter_field_objective_surface(state, encounter);
	if (field_line != key::empty) {
		lines.push_back(gd::format(state, key::field_s_2, {str(field_line)}));
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_encounter_guard_link_surface(State &state, DictRef session, DictRef encounter) {
	const DictRef guard = _encounter_guard_link(state, encounter);
	if (gd::is_empty(state, guard)) {
		return key::empty;
	}
	const Atom role = stripped(state, guard, key::guard_role);
	if (role == key::empty || role == key::none) {
		return key::empty;
	}
	const Atom target_label = _encounter_guard_target_label(state, dict_value(session), guard);
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::guard_s_2, {str(_humanize_id(state, role))}));
	if (target_label != key::empty) {
		parts.push_back(gd::format(state, key::target_s, {str(target_label)}));
	}
	if (gd::bool_field(state, guard, key::clear_required_for_target, false)) {
		parts.push_back(key::clear_required);
	} else if (gd::bool_field(state, guard, key::blocks_approach, false)) {
		parts.push_back(key::blocks_approach_3);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom describe_dispatch(State &state, DictRef session, Atom last_message) {
	normalize_overworld_state(state, session);
	const DictRef observation_context = _event_dispatch_observation_context(state, session, state.new_dict());
	return _describe_dispatch_from_observation_context(state, session, last_message, observation_context);
}

Atom _describe_dispatch_from_observation_context(State &state, DictRef session, Atom last_message, DictRef observation_context) {
	const Atom lead_line = last_message != key::empty
			? gd::format(state, key::latest_order_s, {str(last_message)})
			: static_cast<Atom>(key::the_field_table_is_waiting_on);
	Atom local_pressure = text_of(state, observation_context, key::local_pressure);
	if (local_pressure == key::empty) {
		local_pressure = key::no_visible_hostile_pressure_is_crowding_2;
	}
	std::vector<Atom> lines;
	lines.push_back(key::field_dispatch);
	lines.push_back(gd::format(state, key::dash_space_s, {str(lead_line)}));
	lines.push_back(gd::format(state, key::active_tile_s, {str(text_of(state, observation_context, key::dispatch_context))}));
	lines.push_back(gd::format(state, key::dash_space_s, {str(local_pressure)}));
	const Atom management_watch = text_of(state, observation_context, key::management_watch);
	if (management_watch != key::empty) {
		lines.push_back(gd::format(state, key::management_watch_s, {str(management_watch)}));
	}
	const Atom defense_watch = text_of(state, observation_context, key::defense_watch);
	if (defense_watch != key::no_exposed_town_or_route_defense) {
		lines.push_back(gd::format(state, key::defense_readiness_s_2, {str(defense_watch)}));
	}
	const Atom recent_events = text_of(state, observation_context, key::recent_events);
	if (recent_events != key::empty) {
		lines.push_back(gd::format(state, key::scenario_pulse_s, {str(recent_events)}));
	}
	if (outcome_pending(state, session)) {
		lines.push_back(gd::format(state, key::outcome_pending_s, {str(session_text(state, session, key::scenario_summary))}));
	}
	return join_atoms(state, key::newline, lines);
}

DictRef describe_event_dispatch_surfaces(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value, DictRef refresh_watch_context) {
	if (gd::is_empty(state, refresh_watch_context)) {
		normalize_overworld_state(state, session);
	}
	const DictRef observation_context = _event_dispatch_observation_context(state, session, refresh_watch_context);
	const DictRef event_feed = _describe_event_feed_surface_from_observation_context(
			state,
			session,
			last_message,
			turn_resolution_summary,
			enemy_activity_summary,
			enemy_activity_events_value,
			action_recap_value,
			observation_context);
	const Atom dispatch = _describe_dispatch_from_observation_context(state, session, last_message, observation_context);
	const DictRef result = state.new_dict();
	state.set(result, str(key::event_feed), dict_value(event_feed));
	state.set(result, str(key::dispatch), str(dispatch));
	return result;
}

DictRef _event_dispatch_observation_context(State &state, DictRef session, DictRef refresh_watch_context) {
	Atom local_pressure = key::empty;
	Atom management_watch = key::empty;
	if (gd::is_empty(state, refresh_watch_context)) {
		local_pressure = _local_visible_threat_summary(state, session, key::empty);
		management_watch = describe_management_watch(state, session);
	} else {
		local_pressure = text_of(state, refresh_watch_context, key::local_pressure);
		management_watch = text_of(state, refresh_watch_context, key::management_watch);
	}
	const Atom recent_events = _describe_recent_events(state, session, 2);
	const DictRef route_pressure = describe_route_interception_surface(state, session, -1, -1, 0, true);
	const Atom defense_watch = describe_defense_readiness_warnings(state, session, 1);
	const Atom dispatch_context = _dispatch_context_brief(state, session);
	const DictRef result = state.new_dict();
	state.set(result, str(key::recent_events), str(recent_events));
	state.set(result, str(key::route_pressure), dict_value(route_pressure));
	state.set(result, str(key::local_pressure), str(local_pressure));
	state.set(result, str(key::management_watch), str(management_watch));
	state.set(result, str(key::defense_watch), str(defense_watch));
	state.set(result, str(key::dispatch_context), str(dispatch_context));
	return result;
}

DictRef describe_event_feed_surface(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value) {
	normalize_overworld_state(state, session);
	const DictRef observation_context = _event_dispatch_observation_context(state, session, state.new_dict());
	return _describe_event_feed_surface_from_observation_context(
			state,
			session,
			last_message,
			turn_resolution_summary,
			enemy_activity_summary,
			enemy_activity_events_value,
			action_recap_value,
			observation_context);
}

DictRef _describe_event_feed_surface_from_observation_context(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value, DictRef observation_context) {
	const Atom recent_events = text_of(state, observation_context, key::recent_events);
	const DictRef action_recap = _normalize_post_action_recap(state, action_recap_value);
	const bool use_action_recap = gd::strip_edges(state, turn_resolution_summary) == key::empty
			&& gd::strip_edges(state, enemy_activity_summary) == key::empty
			&& !gd::is_empty(state, action_recap);
	const Atom happened = use_action_recap
			? text_of(state, action_recap, key::happened)
			: _event_feed_happened_line(state, last_message, turn_resolution_summary, enemy_activity_summary, recent_events);
	const Atom affected = use_action_recap
			? text_of(state, action_recap, key::affected)
			: _event_feed_affected_line(state, session, enemy_activity_summary, enemy_activity_events_value);
	const Atom why = use_action_recap
			? text_of(state, action_recap, key::why_it_matters)
			: _event_feed_why_line(state, last_message, turn_resolution_summary, enemy_activity_summary, recent_events);
	const Atom next_step = use_action_recap
			? text_of(state, action_recap, key::next_step_2)
			: _event_feed_next_step_line(state, session);
	const Atom watch = _event_feed_watch_line_from_observation_context(state, observation_context);
	const Atom visible = _event_feed_visible_line(state, happened, turn_resolution_summary, enemy_activity_summary);
	std::vector<Atom> tooltip_lines;
	tooltip_lines.push_back(key::field_feed);
	tooltip_lines.push_back(gd::format(state, key::happened_s, {str(happened)}));
	if (gd::strip_edges(state, turn_resolution_summary) != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::daybreak_result_s, {str(gd::strip_edges(state, turn_resolution_summary))}));
	}
	if (gd::strip_edges(state, enemy_activity_summary) != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::recent_enemy_activity_s, {str(gd::strip_edges(state, enemy_activity_summary))}));
	}
	if (recent_events != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::scenario_pulse_s, {str(_short_player_text(state, recent_events, 180))}));
	}
	if (affected != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::affected_s, {str(affected)}));
	}
	if (why != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::why_it_matters_s, {str(why)}));
	}
	if (next_step != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::next_s_3, {str(next_step)}));
	}
	if (watch != key::empty) {
		tooltip_lines.push_back(gd::format(state, key::watch_s_3, {str(watch)}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::visible_text), str(visible));
	state.set(result, str(key::tooltip_text), str(join_atoms(state, key::newline, tooltip_lines)));
	state.set(result, str(key::happened), str(happened));
	state.set(result, str(key::affected), str(affected));
	state.set(result, str(key::why_it_matters), str(why));
	state.set(result, str(key::next_step_2), str(next_step));
	state.set(result, str(key::watch), str(watch));
	state.set(result, str(key::recent_events), str(recent_events));
	state.set(result, str(key::enemy_activity_summary), str(enemy_activity_summary));
	state.set(result, str(key::turn_resolution_summary), str(turn_resolution_summary));
	state.set(result, str(key::post_action_recap), dict_value(action_recap));
	return result;
}

Atom _event_feed_visible_line(State &state, Atom happened, Atom turn_resolution_summary, Atom enemy_activity_summary) {
	if (gd::strip_edges(state, turn_resolution_summary) != key::empty) {
		return gd::format(state, key::turn_s, {str(_short_player_text(state, turn_resolution_summary, 72))});
	}
	if (gd::strip_edges(state, enemy_activity_summary) != key::empty) {
		return gd::format(state, key::enemy_s, {str(_short_player_text(state, enemy_activity_summary, 72))});
	}
	Atom action_text = happened;
	if (gd::begins_with(state, action_text, key::order_resolved_2)) {
		action_text = gd::trim_prefix(state, action_text, key::order_resolved_2);
	} else if (gd::begins_with(state, action_text, key::scenario_pulse)) {
		action_text = gd::trim_prefix(state, action_text, key::scenario_pulse);
	}
	return gd::format(state, key::event_s, {str(_short_player_text(state, action_text, 72))});
}

Atom _event_feed_happened_line(State &state, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, Atom recent_events) {
	const Atom turn_text = _enemy_activity_public_text(state, turn_resolution_summary);
	if (turn_text != key::empty) {
		return gd::format(state, key::daybreak_resolved_s, {str(_short_player_text(state, turn_text, 160))});
	}
	const Atom message_text = _enemy_activity_public_text(state, last_message);
	if (message_text != key::empty) {
		return gd::format(state, key::order_resolved_s, {str(_short_player_text(state, message_text, 160))});
	}
	const Atom enemy_text = _enemy_activity_public_text(state, enemy_activity_summary);
	if (enemy_text != key::empty) {
		return gd::format(state, key::enemy_movement_reported_s, {str(_short_player_text(state, enemy_text, 160))});
	}
	if (recent_events != key::empty) {
		return gd::format(state, key::scenario_pulse_s_2, {str(_short_player_text(state, recent_events, 160))});
	}
	return key::no_new_report_the_frontier_watch;
}

Atom _event_feed_affected_line(State &state, DictRef session, Atom enemy_activity_summary, const Value &enemy_activity_events_value) {
	std::vector<Atom> affected;
	if (gd::strip_edges(state, enemy_activity_summary) != key::empty && gd::is_array(enemy_activity_events_value)) {
		for (const Value &event_value : items_of(state, enemy_activity_events_value)) {
			if (!gd::is_dict(event_value)) {
				continue;
			}
			const DictRef event = event_value.ref;
			const Atom target_label = stripped(state, event, key::target_label);
			if (target_label == key::empty) {
				continue;
			}
			const Atom target_kind = stripped(state, event, key::target_kind);
			const Atom faction_label = stripped(state, event, key::faction_label);
			Atom label = target_label;
			if (target_kind != key::empty) {
				const Atom kind_text = to_lower_ascii(state, _humanize_id(state, target_kind), "OverworldRules._event_feed_affected_line");
				label = state.intern(state.text(label) + state.text(gd::format(state, key::space_s_text, {str(kind_text)})));
			}
			if (faction_label != key::empty) {
				label = gd::format(state, key::s_colon_s_text, {str(faction_label), str(label)});
			}
			if (std::find(affected.begin(), affected.end(), label) == affected.end()) {
				affected.push_back(label);
			}
			if (affected.size() >= 2) {
				break;
			}
		}
	}
	const Atom convoy_line = _event_feed_convoy_line(state, session);
	if (convoy_line != key::empty) {
		affected.push_back(convoy_line);
	}
	if (affected.empty()) {
		affected.push_back(_dispatch_context_brief(state, session));
	}
	keep_first(affected, 3);
	return join_atoms(state, key::space_bar_space, affected);
}

Atom _event_feed_why_line(State &state, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, Atom recent_events) {
	const Atom combined = gd::format(state, key::s_s_s_s_5, {str(last_message), str(turn_resolution_summary), str(enemy_activity_summary), str(recent_events)});
	const std::string lower = lower_for_find(state.text(combined));
	if (gd::strip_edges(state, enemy_activity_summary) != key::empty) {
		return key::enemy_moves_can_close_routes_contest;
	}
	if (has_word(state, lower, key::convoy) || has_word(state, lower, key::escort) || has_word(state, lower, key::route)) {
		return key::route_orders_move_reinforcements_and_may;
	}
	if (recent_events != key::empty) {
		return key::scenario_pulses_can_open_rewards_spawn;
	}
	if (has_word(state, lower, key::claim) || has_word(state, lower, key::control) || has_word(state, lower, key::captur)) {
		return key::control_changes_affect_income_recruitment_routes;
	}
	if (has_word(state, lower, key::recruit) || has_word(state, lower, key::muster)) {
		return key::fresh_troops_change_the_next_battle;
	}
	return key::use_the_next_order_to_turn;
}

Atom _event_feed_next_step_line(State &state, DictRef session) {
	const DictRef surface = _objective_stakes_surface(state, session);
	const Atom next_objective = stripped(state, surface, key::next_objective);
	if (next_objective != key::empty) {
		return gd::format(state, key::push_toward_s, {str(_short_player_text(state, next_objective, 92))});
	}
	const Atom watch_objective = stripped(state, surface, key::watch_objective);
	if (watch_objective != key::empty) {
		return gd::format(state, key::keep_watch_on_s, {str(_short_player_text(state, watch_objective, 92))});
	}
	if (outcome_pending(state, session)) {
		return key::resolve_the_pending_scenario_outcome;
	}
	return key::scout_consolidate_or_end_the_turn;
}

Atom _event_feed_watch_line_from_observation_context(State &state, DictRef observation_context) {
	std::vector<Atom> parts;
	// observation_context.get("route_pressure", {}) when a Dictionary, else {}.
	Value route_pressure;
	if (state.lookup(observation_context, str(key::route_pressure), route_pressure) && gd::is_dict(route_pressure)) {
		if (gd::bool_field(state, route_pressure.ref, key::active, false)) {
			parts.push_back(text_of(state, route_pressure.ref, key::cue_text));
		}
	}
	const Atom local_pressure = text_of(state, observation_context, key::local_pressure);
	if (local_pressure != key::empty) {
		parts.push_back(local_pressure);
	}
	const Atom management_watch = text_of(state, observation_context, key::management_watch);
	if (management_watch != key::empty && management_watch != key::town_lines_are_stable) {
		parts.push_back(management_watch);
	}
	const Atom defense_watch = text_of(state, observation_context, key::defense_watch);
	if (defense_watch != key::no_exposed_town_or_route_defense) {
		parts.push_back(gd::format(state, key::defense_readiness_s, {str(defense_watch)}));
	}
	if (parts.empty()) {
		return key::no_urgent_enemy_convoy_or_town;
	}
	keep_first(parts, 3);
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef describe_route_interception_surface(State &state, DictRef session, int64_t destination_x, int64_t destination_y, int64_t route_steps, bool include_global_fallback) {
	// `if session == null`: a view is never null.
	if (include_global_fallback) {
		normalize_overworld_state_for_runtime(state, session);
	}
	if (destination_x >= 0 && destination_y >= 0) {
		const DictRef selected = _selected_route_interception_surface(state, session, Vector2i::of(destination_x, destination_y), route_steps);
		if (gd::bool_field(state, selected, key::active, false)) {
			return selected;
		}
	}
	if (!include_global_fallback) {
		return _route_interception_empty_surface(state);
	}
	const DictRef convoy = _best_convoy_interception_surface(state, session);
	if (gd::bool_field(state, convoy, key::active, false)) {
		return convoy;
	}
	const DictRef raid = _best_raid_interception_surface(state, session);
	if (gd::bool_field(state, raid, key::active, false)) {
		return raid;
	}
	return _route_interception_empty_surface(state);
}

DictRef _route_interception_empty_surface(State &state) {
	const DictRef surface = state.new_dict();
	state.set(surface, str(key::active), bool_value(false));
	state.set(surface, str(key::kind), str(key::empty));
	state.set(surface, str(key::cue_text), str(key::empty));
	state.set(surface, str(key::visible_text), str(key::empty));
	state.set(surface, str(key::tooltip_text), str(key::empty));
	state.set(surface, str(key::affected), str(key::empty));
	state.set(surface, str(key::why_it_matters), str(key::empty));
	state.set(surface, str(key::next_step_2), str(key::empty));
	state.set(surface, str(key::importance), str(key::normal));
	return surface;
}

DictRef _route_interception_payload(State &state, Atom kind, Atom affected, Atom why_it_matters, Atom next_step, Atom cue_text, Atom importance) {
	const Atom cleaned_affected = _short_player_text(state, _enemy_activity_public_text(state, affected), 150);
	const Atom cleaned_why = _short_player_text(state, _enemy_activity_public_text(state, why_it_matters), 160);
	const Atom cleaned_next = _short_player_text(state, _enemy_activity_public_text(state, next_step), 140);
	const Atom cleaned_cue = _short_player_text(state, _enemy_activity_public_text(state, cue_text), 96);
	if (cleaned_affected == key::empty || cleaned_why == key::empty || cleaned_next == key::empty || cleaned_cue == key::empty) {
		return _route_interception_empty_surface(state);
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::active), bool_value(true));
	state.set(payload, str(key::kind), str(kind));
	state.set(payload, str(key::cue_text), str(cleaned_cue));
	state.set(payload, str(key::visible_text), str(cleaned_cue));
	state.set(payload, str(key::tooltip_text), str(gd::format(state, key::interception_watch_affected_s_why_it, {str(cleaned_affected), str(cleaned_why), str(cleaned_next)})));
	state.set(payload, str(key::affected), str(cleaned_affected));
	state.set(payload, str(key::why_it_matters), str(cleaned_why));
	state.set(payload, str(key::next_step_2), str(cleaned_next));
	state.set(payload, str(key::importance), str(importance));
	return payload;
}

DictRef _selected_route_interception_surface(State &state, DictRef session, Vector2i tile, int64_t route_steps) {
	const DictRef encounter = _encounter_at_tile(state, session, tile.x, tile.y);
	if (!gd::is_empty(state, encounter)) {
		return _raid_interception_surface(state, session, encounter, route_steps, true);
	}
	const DictRef node = _resource_node_at_tile(state, session, tile.x, tile.y);
	if (gd::is_empty(state, node)) {
		return _route_interception_empty_surface(state);
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, node, key::site_id));
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (gd::bool_field(state, delivery_state, key::active, false)) {
		return _convoy_interception_surface(state, session, node, site, true);
	}
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (gd::bool_field(state, response_state, key::active, false)) {
		const Atom impact = _resource_site_response_effect_summary(state, response_state);
		const Atom affected = gd::format(state, key::s_response_holds_s_for_d, {
				str(text_of(state, site, key::name, key::route_site)),
				str(to_lower_ascii(state, text_of(state, response_state, key::action_label, key::route_security_2), "OverworldRules._selected_route_interception_surface")),
				int_value(gd::int_field(state, response_state, key::remaining_days, 0)),
				str(plural(gd::int_field(state, response_state, key::remaining_days, 0))),
				str(impact == key::empty ? static_cast<Atom>(key::empty) : gd::format(state, key::s_3, {str(impact)})),
		});
		const Atom cue = gd::format(state, key::s_response_active, {str(text_of(state, site, key::name, key::Route))});
		return _route_interception_payload(
				state,
				key::route_response,
				affected,
				key::active_response_orders_protect_economy_links,
				key::use_the_protected_lane_to_intercept,
				cue,
				key::normal);
	}
	if (text_of(state, node, key::collected_by_faction_id) == key::player && gd::int_field(state, response_state, key::watch_days, 0) > 0) {
		const Atom affected = gd::format(state, key::s_can_receive_s, {
				str(text_of(state, site, key::name, key::route_site)),
				str(to_lower_ascii(state, text_of(state, response_state, key::action_label, key::route_security_2), "OverworldRules._selected_route_interception_surface")),
		});
		const Atom cue = gd::format(state, key::s_response_ready, {str(text_of(state, site, key::name, key::Route))});
		return _route_interception_payload(
				state,
				key::route_response_ready,
				affected,
				key::response_orders_spend_movement_and_stores,
				key::stand_on_the_site_or_use,
				cue,
				key::normal);
	}
	return _route_interception_empty_surface(state);
}

DictRef _best_convoy_interception_surface(State &state, DictRef session) {
	DictRef best = _route_interception_empty_surface(state);
	int64_t best_score = -99999;
	for (const Value &node_value : field_items_of(state, session_view::overworld(state, session), key::resource_nodes)) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, node, key::site_id));
		const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
		if (!gd::bool_field(state, delivery_state, key::active, false) || text_of(state, delivery_state, key::controller_id) != key::player) {
			continue;
		}
		const DictRef interception = _resource_site_delivery_interception(state, session, node, site);
		int64_t score = gd::int_field(state, delivery_state, key::manifest_value, 0);
		score = gd::add(score, gd::bool_field(state, interception, key::blocks_delivery, false) ? 10000 : 0);
		score = gd::add(score, gd::bool_field(state, interception, key::active, false) ? 4000 : 0);
		score = gd::add(score, gd::mul(compat::engine_max<int64_t>(0, gd::sub(20, gd::int_field(state, delivery_state, key::days_remaining, 0))), 10));
		if (score <= best_score) {
			continue;
		}
		best_score = score;
		best = _convoy_interception_surface(state, session, node, site, false);
	}
	return best;
}

DictRef _convoy_interception_surface(State &state, DictRef session, DictRef node, DictRef site, bool selected) {
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false)) {
		return _route_interception_empty_surface(state);
	}
	const DictRef interception = _resource_site_delivery_interception(state, session, node, site);
	const Atom site_name = text_of(state, site, key::name, key::frontier_route);
	const Atom target_label = text_of(state, delivery_state, key::target_label, key::the_front);
	const Atom recruit_summary = text_of(state, delivery_state, key::recruit_summary, key::the_convoy_2);
	const Atom route_label = gd::format(state, key::s_convoy_to_s, {str(site_name), str(target_label)});
	const Atom delivery_line = _resource_site_delivery_line(state, session, node, site);
	const Atom affected = gd::format(state, key::s_carries_s_s, {str(route_label), str(recruit_summary), str(delivery_line)});
	const Atom why = _convoy_interception_why(state, text_of(state, delivery_state, key::target_kind), target_label);
	Atom next_step = key::keep_the_convoy_route_covered_until;
	Atom cue = gd::format(state, key::convoy_s_to_s, {str(site_name), str(target_label)});
	Atom importance = key::normal;
	if (gd::bool_field(state, interception, key::blocks_delivery, false)) {
		const Atom blocker = text_of(state, interception, key::encounter_name, key::enemy_army_3);
		next_step = gd::format(state, key::break_s_before_ending_the_day, {str(blocker)});
		cue = gd::format(state, key::convoy_blocked_s, {str(blocker)});
		importance = key::high;
	} else if (gd::bool_field(state, interception, key::active, false)) {
		const Atom hunter = text_of(state, interception, key::encounter_name, key::enemy_army_3);
		next_step = gd::format(state, key::intercept_s_or_reinforce_s_before, {str(hunter), str(target_label)});
		const int64_t goal_distance = gd::int_field(state, interception, key::goal_distance, 0);
		cue = gd::format(state, key::convoy_threatened_s_d_tile_s, {str(hunter), int_value(goal_distance), str(plural(goal_distance))});
		importance = gd::int_field(state, interception, key::goal_distance, 9999) <= 1 ? static_cast<Atom>(key::high) : static_cast<Atom>(key::normal);
	} else if (selected) {
		next_step = gd::format(state, key::hold_this_route_response_or_move, {str(target_label)});
		cue = gd::format(state, key::convoy_active_s, {str(target_label)});
	}
	return _route_interception_payload(state, key::convoy, affected, why, next_step, cue, importance);
}

Atom _convoy_interception_why(State &state, Atom target_kind, Atom target_label) {
	if (target_kind == key::town) {
		return gd::format(state, key::those_reserves_change_s_defense_recovery, {str(target_label)});
	}
	if (target_kind == key::hero) {
		return key::those_reserves_change_the_field_army;
	}
	if (target_kind == key::raid) {
		return key::those_reserves_help_answer_the_enemy;
	}
	return key::convoys_turn_controlled_sites_into_practical;
}

DictRef _best_raid_interception_surface(State &state, DictRef session) {
	DictRef best = _route_interception_empty_surface(state);
	int64_t best_score = -99999;
	for (const Value &encounter_value : field_items_of(state, session_view::overworld(state, session), key::encounters)) {
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		if (text_of(state, encounter, key::spawned_by_faction_id) == key::empty || is_encounter_resolved(state, session, encounter)) {
			continue;
		}
		if (!_raid_is_public(state, session, encounter)) {
			continue;
		}
		const int64_t goal_distance = gd::int_field(state, encounter, key::goal_distance, 9999);
		int64_t score = gd::bool_field(state, encounter, key::arrived, false) || goal_distance <= 0 ? 2000 : 0;
		score = gd::add(score, gd::mul(compat::engine_max<int64_t>(0, gd::sub(20, goal_distance)), 20));
		if (_raid_target_is_objective_anchor(
					state,
					session,
					text_of(state, encounter, key::target_kind),
					text_of(state, encounter, key::target_placement_id))) {
			score = gd::add(score, 1000);
		}
		if (score <= best_score) {
			continue;
		}
		best_score = score;
		best = _raid_interception_surface(state, session, encounter, 0, false);
	}
	return best;
}

DictRef _raid_interception_surface(State &state, DictRef session, DictRef encounter, int64_t route_steps, bool selected) {
	if (gd::is_empty(state, encounter) || is_encounter_resolved(state, session, encounter)) {
		return _route_interception_empty_surface(state);
	}
	const Atom encounter_name = encounter_display_name(state, encounter);
	const Atom target_kind = text_of(state, encounter, key::target_kind);
	const Atom target_label = text_of(state, encounter, key::target_label, key::the_frontier);
	const int64_t goal_distance = gd::int_field(state, encounter, key::goal_distance, 9999);
	const bool objective_anchor = _raid_target_is_objective_anchor(state, session, target_kind, text_of(state, encounter, key::target_placement_id));
	const Atom affected = describe_encounter_pressure(state, session, encounter, false);
	const Atom why = _raid_interception_why(state, target_kind, target_label, objective_anchor);
	Atom next_step = key::select_the_hostile_contact_or_a;
	Atom cue = gd::format(state, key::enemy_s_toward_s, {str(encounter_name), str(target_label)});
	Atom importance = key::normal;
	if (selected) {
		next_step = key::enter_battle_now_if_this_route;
		if (route_steps > 0) {
			next_step = gd::format(state, key::advance_d_step_s_toward_s, {int_value(route_steps), str(plural(route_steps)), str(encounter_name)});
		}
		cue = gd::format(state, key::intercept_s, {str(encounter_name)});
	} else if (gd::bool_field(state, encounter, key::arrived, false) || goal_distance <= 0) {
		next_step = gd::format(state, key::break_s_now_or_it_can, {str(encounter_name)});
		cue = gd::format(state, key::enemy_arrived_s, {str(encounter_name)});
		importance = key::high;
	} else if (goal_distance <= 2) {
		next_step = gd::format(state, key::move_to_intercept_s_before_it, {str(encounter_name), str(target_label)});
		cue = gd::format(state, key::enemy_close_s_d_tile_s, {str(encounter_name), int_value(goal_distance), str(plural(goal_distance))});
		importance = key::high;
	}
	return _route_interception_payload(state, key::raid, affected, why, next_step, cue, importance);
}

Atom _raid_interception_why(State &state, Atom target_kind, Atom target_label, bool objective_anchor) {
	const Atom objective_clause = objective_anchor ? static_cast<Atom>(key::it_is_tied_to_objective_pressure) : static_cast<Atom>(key::empty);
	if (target_kind == key::town) {
		return gd::format(state, key::enemy_attacks_threaten_control_recruitment_income, {str(target_label), str(objective_clause)});
	}
	if (target_kind == key::resource) {
		return gd::format(state, key::enemy_attacks_threaten_linked_economy_route, {str(target_label), str(objective_clause)});
	}
	if (target_kind == key::hero) {
		return gd::format(state, key::hero_hunts_can_force_a_field, {str(objective_clause)});
	}
	if (target_kind == key::artifact) {
		return gd::format(state, key::enemy_heroes_can_deny_a_field, {str(objective_clause)});
	}
	if (target_kind == key::encounter) {
		return gd::format(state, key::enemy_pressure_on_this_guard_can, {str(objective_clause)});
	}
	return gd::format(state, key::enemy_pressure_can_become_economy_control, {str(objective_clause)});
}

Atom _event_feed_convoy_line(State &state, DictRef session) {
	for (const Value &node_value : field_items_of(state, session_view::overworld(state, session), key::resource_nodes)) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, node, key::site_id));
		const Atom delivery_line = _resource_site_delivery_line(state, session, node, site);
		if (delivery_line != key::empty) {
			return gd::format(state, key::convoy_s, {str(_short_player_text(state, delivery_line, 120))});
		}
	}
	return key::empty;
}

Atom _dispatch_context_brief(State &state, DictRef session) {
	const DictRef context = get_active_context(state, session);
	const Vector2i pos = hero_position(state, session);
	const Atom terrain = _terrain_name_at(state, session, pos.x, pos.y);
	const Atom type = text_of(state, context, key::type, key::empty_2);
	if (type == key::town) {
		const Value town = field_or_new_dict(state, context, key::town);
		return gd::format(state, key::s_on_s, {str(_town_name(state, gd::as_dict(town))), str(terrain)});
	}
	if (type == key::resource) {
		const Value node = field_or_new_dict(state, context, key::node);
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, vtext_of(state, node, key::site_id));
		return gd::format(state, key::s_on_s, {str(text_of(state, site, key::name, key::resource_site_3)), str(terrain)});
	}
	if (type == key::artifact) {
		const Value artifact_node = field_or_new_dict(state, context, key::node);
		const Atom artifact_text = artifact_rules::describe_artifact_short(state, vtext_of(state, artifact_node, key::artifact_id));
		return gd::format(state, key::s_on_s, {str(artifact_text), str(terrain)});
	}
	if (type == key::encounter) {
		const Value encounter_placement = field_or_new_dict(state, context, key::encounter);
		return gd::format(state, key::s_on_s, {str(encounter_display_name(state, gd::as_dict(encounter_placement))), str(terrain)});
	}
	return gd::format(state, key::open_ground_at_d_d_on, {int_value(pos.x), int_value(pos.y), str(terrain)});
}

Atom describe_recruit_source_compact(State &state, DictRef session, DictRef node, DictRef site) {
	if (!resource_site_is_recruit_source(state, site)) {
		return key::empty;
	}
	const ArrayRef parts = state.new_array();
	const Atom claim_line = _recruit_source_roster_line(state, key::Ready, dict_value(_resource_site_claim_recruits(state, site)), 2, false);
	if (claim_line != key::empty) {
		state.append(parts, str(claim_line));
	}
	const DictRef weekly_recruits = _resource_site_weekly_recruits(state, site);
	const Atom weekly_line = _recruit_source_roster_line(state, key::Weekly, dict_value(weekly_recruits), 1, creature_dwelling_rules::is_dwelling(state, site));
	if (weekly_line != key::empty) {
		state.append(parts, str(weekly_line));
	}
	const Atom guard_line = _resource_site_guard_or_contest_line(state, dict_value(session), node, site);
	if (guard_line != key::empty) {
		state.append(parts, str(guard_line));
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, parts));
}

Atom describe_resource_site_control_summary(State &state, DictRef session, DictRef node, DictRef site) {
	const ArrayRef parts = state.new_array();
	const Atom control_line = _resource_site_control_brief(state, node, site);
	if (control_line != key::empty) {
		state.append(parts, str(control_line));
	}
	const Atom yield_line = _resource_site_yield_line(state, session, node, site);
	if (yield_line != key::empty) {
		state.append(parts, str(yield_line));
	}
	const Atom guard_line = _resource_site_guard_or_contest_line(state, dict_value(session), node, site);
	if (guard_line != key::empty) {
		state.append(parts, str(guard_line));
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, parts));
}

Atom describe_encounter_object_surface(State &state, DictRef encounter) {
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, text_of(state, encounter, key::object_id));
	// encounter.get("neutral_encounter", {}): a missing one is an empty Dictionary.
	Value neutral_metadata;
	const bool has_metadata = state.lookup(encounter, str(key::neutral_encounter), neutral_metadata);
	const Value primary_fallback = state.get(encounter, str(key::primary_class), str(key::empty));
	Atom primary_class = gd::strip_edges(state, string_of(state, state.get(map_object, str(key::primary_class), primary_fallback)));
	if (primary_class == key::empty && has_metadata && gd::is_dict(neutral_metadata)) {
		primary_class = gd::strip_edges(state, vtext_of(state, neutral_metadata, key::primary_class));
	}
	const ArrayRef parts = state.new_array();
	if (primary_class != key::empty) {
		state.append(parts, str(_humanize_id(state, primary_class)));
	}
	const Atom tag_summary = _encounter_object_tag_summary(state, encounter, map_object);
	if (tag_summary != key::empty) {
		state.append(parts, str(tag_summary));
	}
	const Atom risk_summary = _encounter_risk_label(state, encounter);
	if (risk_summary != key::empty) {
		state.append(parts, str(risk_summary));
	}
	const Atom difficulty_summary = _encounter_difficulty_label(state, encounter);
	if (difficulty_summary != key::empty) {
		state.append(parts, str(difficulty_summary));
	}
	const Atom interaction_mode = _encounter_object_interaction_label(state, encounter, map_object);
	if (interaction_mode != key::empty) {
		state.append(parts, str(interaction_mode));
	}
	const Atom guard_summary = _encounter_guard_summary(state, encounter, Value());
	if (guard_summary != key::empty) {
		state.append(parts, str(guard_summary));
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, parts));
}

Atom _encounter_object_tag_summary(State &state, DictRef encounter, DictRef map_object) {
	// A missing secondary_tags ([]) gives no strings, as Nil does.
	ArrayRef tags = _string_array(state, state.get(map_object, str(key::secondary_tags), Value()));
	Value neutral_metadata;
	// A missing neutral_encounter ({}) has no secondary_tags: tags stay empty.
	if (state.array_size(tags) == 0 && state.lookup(encounter, str(key::neutral_encounter), neutral_metadata) && gd::is_dict(neutral_metadata)) {
		tags = _string_array(state, state.get(neutral_metadata.ref, str(key::secondary_tags), Value()));
	}
	std::vector<Atom> visible;
	for (const Value &tag : items_of(state, array_value(tags))) {
		const Atom label = _humanize_id(state, gd::to_string(tag));
		if (label != key::empty && std::find(visible.begin(), visible.end(), label) == visible.end()) {
			visible.push_back(label);
		}
		if (visible.size() >= 3) {
			break;
		}
	}
	if (visible.empty()) {
		return key::empty;
	}
	return gd::format(state, key::tags_s, {str(join_atoms(state, key::comma_space, visible))});
}

Atom _encounter_object_interaction_label(State &state, DictRef encounter, DictRef map_object) {
	// map_object.get("interaction", {}): a missing one has no cadence.
	Value interaction;
	if (state.lookup(map_object, str(key::interaction), interaction) && gd::is_dict(interaction)) {
		const Atom cadence = gd::strip_edges(state, text_of(state, interaction.ref, key::cadence));
		if (cadence != key::empty) {
			return _interaction_cadence_label(state, cadence);
		}
	}
	Value neutral_metadata;
	if (state.lookup(encounter, str(key::neutral_encounter), neutral_metadata) && gd::is_dict(neutral_metadata)) {
		Value passability;
		if (state.lookup(neutral_metadata.ref, str(key::passability), passability) && gd::is_dict(passability)) {
			const Atom mode = gd::strip_edges(state, text_of(state, passability.ref, key::interaction_mode));
			if (mode != key::empty) {
				return gd::format(state, key::interaction_s, {str(_humanize_id(state, mode))});
			}
		}
	}
	return key::interaction_enter_battle;
}

Atom _encounter_role_label(State &state, DictRef encounter) {
	const DictRef metadata = _encounter_neutral_metadata(state, encounter);
	// metadata.get("representation", {}): a missing one has no mode.
	Value representation;
	if (state.lookup(metadata, str(key::representation), representation) && gd::is_dict(representation)) {
		const Atom mode = gd::strip_edges(state, text_of(state, representation.ref, key::mode));
		if (mode != key::empty) {
			return _humanize_id(state, mode);
		}
	}
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, text_of(state, encounter, key::object_id));
	const Atom subtype = stripped(state, map_object, key::subtype);
	if (subtype != key::empty) {
		return _humanize_id(state, subtype);
	}
	const ArrayRef tags = _encounter_tags(state, encounter, map_object);
	if (gd::array_has(state, tags, str(key::route_block))) {
		return key::route_block_2;
	}
	if (gd::array_has(state, tags, str(key::guarded_reward))) {
		return key::guarded_reward_2;
	}
	if (gd::array_has(state, tags, str(key::visible_army))) {
		return key::visible_stack;
	}
	return key::hostile_contact_2;
}

Atom _encounter_field_objective_surface(State &state, DictRef encounter) {
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, string_of(state, state.get(encounter, str(key::encounter_id), id_fallback)));
	std::vector<Atom> labels;
	for (const Value &objective : field_items_of(state, encounter_def, key::field_objectives)) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom label = stripped(state, objective.ref, key::label);
		if (label != key::empty) {
			labels.push_back(label);
		}
		if (labels.size() >= 2) {
			break;
		}
	}
	return join_atoms(state, key::comma_space, labels);
}

ArrayRef _encounter_tags(State &state, DictRef encounter, DictRef map_object) {
	// A missing secondary_tags ([]) gives no strings, as Nil does.
	ArrayRef tags = _string_array(state, state.get(map_object, str(key::secondary_tags), Value()));
	const DictRef metadata = _encounter_neutral_metadata(state, encounter);
	if (state.array_size(tags) == 0) {
		tags = _string_array(state, state.get(metadata, str(key::secondary_tags), Value()));
	}
	// Array[String], as GDScript's _string_array answers it (the port's is untyped).
	const ArrayRef typed = gd::new_typed_array(state, state::variant_type::STRING);
	const int64_t count = state.array_size(tags);
	for (int64_t index = 0; index < count; ++index) {
		state.append(typed, state.at(tags, index));
	}
	return typed;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
