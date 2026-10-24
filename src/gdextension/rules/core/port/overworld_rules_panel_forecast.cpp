// OverworldRules for the overworld panels (Phase 7, slice 7.8): the command
// briefing, commitments, the end-of-turn forecast and the management watch.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

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

// String(x): stringify(), the engine's str() for a float, a container or an
// object.
Atom value_text(State &state, const Value &value) {
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
Atom field_text(State &state, DictRef dict, Atom field, Atom fallback) {
	return value_text(state, gd::field_or(state, dict, field, str(fallback)));
}

// String(x.get(field, fallback)) of an untyped value.
Atom value_field_text(State &state, const Value &object, Atom field, Atom fallback) {
	return value_text(state, ai::vget(state, object, field, str(fallback)));
}

// d.get(field, {}) and d.get(field, []) where the answer is kept or passed on:
// a new container when the key is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// session.day and the session's String fields.
int64_t session_day(State &state, DictRef session) {
	return gd::to_int(state, gd::index(state, session, str(key::day)));
}

Atom session_text(State &state, DictRef session, Atom field) {
	return gd::to_string(gd::index(state, session, str(field)));
}

// separator.join(parts) of Strings built here.
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

// separator.join(value[0 .. limit)) of an Array (its items as String(item),
// as the Array converts to a PackedStringArray) or a PackedStringArray; limit
// -1 joins all of them. Anything else is GDScript's invalid argument.
Atom join_values(State &state, Atom separator, const Value &value, int64_t limit = -1) {
	std::vector<Atom> parts;
	if (gd::is_array(value)) {
		const int64_t size = state.array_size(value.ref);
		const int64_t count = limit < 0 ? size : compat::engine_min<int64_t>(limit, size);
		for (int64_t index = 0; index < count; ++index) {
			parts.push_back(value_text(state, state.at(value.ref, index)));
		}
	} else if (value.kind == Kind::PackedString) {
		const int64_t size = gd::packed_size(state, value.ref);
		const int64_t count = limit < 0 ? size : compat::engine_min<int64_t>(limit, size);
		for (int64_t index = 0; index < count; ++index) {
			parts.push_back(gd::packed_string(state, value.ref, index));
		}
	} else {
		throw state::ScriptError("String.join: the argument is not an Array or a PackedStringArray");
	}
	return join_atoms(state, separator, parts);
}

// text.split(delimiter, allow_empty) (String::split with no maxsplit).
std::vector<Atom> split_text(State &state, Atom text, const std::string &delimiter, bool allow_empty) {
	std::vector<Atom> pieces;
	const std::string source = state.text(text);
	if (source.empty()) {
		if (allow_empty) {
			pieces.push_back(key::empty);
		}
		return pieces;
	}
	size_t from = 0;
	while (true) {
		size_t end = source.find(delimiter, from);
		if (end == std::string::npos) {
			end = source.size();
		}
		if (allow_empty || end > from) {
			pieces.push_back(state.intern(source.substr(from, end - from)));
		}
		if (end == source.size()) {
			break;
		}
		from = end + delimiter.size();
	}
	return pieces;
}

bool text_contains(State &state, Atom text, Atom part) {
	return state.text(text).find(state.text(part)) != std::string::npos;
}

// value is Array and not value.is_empty() of d.get(field, []).
bool has_labels(State &state, DictRef dict, Atom field) {
	Value labels;
	return state.lookup(dict, str(field), labels) && gd::is_array(labels) && state.array_size(labels.ref) > 0;
}

// text.to_lower() of ASCII text (the Unicode case tables are not ported; every
// response action label in the content is ASCII).
Atom ascii_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted("OverworldRules._nearest_logistics_plan: to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

Atom plural_s(int64_t count) {
	return count == 1 ? key::empty : key::s;
}

// abs(a.x - b.x) + abs(a.y - b.y) of ints.
int64_t tile_distance(int64_t ax, int64_t ay, int64_t bx, int64_t by) {
	return gd::add(compat::absi(gd::sub(ax, bx)), compat::absi(gd::sub(ay, by)));
}

// var x = session.overworld.get(field, {}), {} unless a Dictionary; x["shown"]
// = true; x["shown_day"] = session.day; session.overworld[field] = x.
void mark_panel_shown(State &state, DictRef session, Atom field) {
	Value found;
	const DictRef panel_state = state.lookup(session_view::overworld(state, session), str(field), found) && gd::is_dict(found)
			? found.ref
			: state.new_dict();
	state.set(panel_state, str(key::shown), bool_value(true));
	state.set(panel_state, str(key::shown_day), int_value(session_day(state, session)));
	state.set(session_view::overworld(state, session), str(field), dict_value(panel_state));
}

// var x = session.overworld.get(field, {}); return x is Dictionary and not
// bool(x.get("shown", false)).
bool panel_not_shown(State &state, DictRef session, Atom field) {
	Value found;
	if (!state.lookup(session_view::overworld(state, session), str(field), found)) {
		return true;
	}
	return gd::is_dict(found) && !gd::bool_field(state, found.ref, key::shown, false);
}

// The last piece of text.split("\n", false), as lines[lines.size() - 1].
Atom last_line(State &state, Atom text) {
	const std::vector<Atom> lines = split_text(state, text, "\n", false);
	if (lines.empty()) {
		throw state::ScriptError("PackedStringArray index -1 is out of bounds");
	}
	return lines.back();
}

} // namespace

namespace overworld_rules {

Atom describe_command_briefing(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	if (!_should_surface_command_briefing(state, session)) {
		return key::empty;
	}
	return join_values(state, key::newline, array_value(_command_briefing_lines(state, session)));
}

Atom consume_command_briefing(State &state, DictRef session) {
	const Atom briefing_text = describe_command_briefing(state, session);
	if (briefing_text == key::empty) {
		return key::empty;
	}
	mark_panel_shown(state, session, key::command_briefing);
	return briefing_text;
}

Atom describe_command_risk(State &state, DictRef session) {
	return field_text(state, describe_command_risk_surfaces(state, session), key::risk, key::empty);
}

Atom describe_command_risk_summary_from_normalized_session(State &state, DictRef session) {
	const DictRef reduction = _reduce_command_risk_items(state, _command_risk_items(state, session, false));
	if (!gd::bool_field(state, reduction, key::has_risk, false)) {
		return key::steady_watch_no_concrete_next_day;
	}
	return field_text(state, reduction, key::summary, key::empty);
}

DictRef _refresh_watch_observation_context(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	return _refresh_watch_observation_context_from_normalized_session(state, session);
}

DictRef _refresh_watch_observation_context_from_normalized_session(State &state, DictRef session) {
	const DictRef command_risk_forecast = _command_risk_forecast_from_normalized_session(state, session);
	const DictRef context = state.new_dict();
	state.set(context, str(key::command_risk_forecast), gd::engine_duplicate(state, dict_value(command_risk_forecast), true));
	const DictRef surfaces = _command_risk_surfaces_from_forecast(state, command_risk_forecast);
	state.set(context, str(key::command_risk_surfaces), gd::engine_duplicate(state, dict_value(surfaces), true));
	state.set(context, str(key::local_pressure), str(_local_visible_threat_summary(state, session, key::empty)));
	state.set(context, str(key::management_watch), str(_describe_management_watch_from_normalized_session(state, session)));
	return gd::as_dict(gd::engine_duplicate(state, dict_value(context), true));
}

Atom describe_commitment_board(State &state, DictRef session, DictRef refresh_watch_context) {
	Atom hold_line = key::empty;
	if (gd::is_empty(state, refresh_watch_context)) {
		normalize_overworld_state(state, session);
		hold_line = _command_commitment_hold_line(state, session);
	} else {
		hold_line = _command_commitment_hold_line_from_watch_context(state, session, refresh_watch_context);
	}
	std::vector<Atom> lines;
	lines.push_back(key::command_commitment);
	lines.push_back(gd::format(state, key::immediate_order_s, {str(_command_commitment_action_line(state, session))}));
	lines.push_back(gd::format(state, key::route_pressure_s, {str(_command_commitment_route_line(state, session))}));
	lines.push_back(gd::format(state, key::coverage_s, {str(_command_commitment_coverage_line(state, session))}));
	lines.push_back(gd::format(state, key::if_you_hold_s, {str(hold_line)}));
	return join_atoms(state, key::newline, lines);
}

Atom describe_command_risk_forecast(State &state, DictRef session) {
	return field_text(state, describe_command_risk_surfaces(state, session), key::forecast, key::empty);
}

Atom describe_end_turn_forecast(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	const int64_t next_day = gd::add(session_day(state, session), 1);
	std::vector<Atom> lines;
	const Atom income_line = _end_turn_income_forecast_line(state, session, next_day);
	const Atom muster_line = _end_turn_muster_forecast_line(state, session, next_day);
	lines.push_back(gd::format(state, key::next_day_day_d_s_s, {int_value(next_day), str(income_line), str(muster_line)}));
	lines.push_back(gd::format(state, key::movement_s, {str(_end_turn_movement_forecast_line(state, session))}));
	const Atom risk_line = _end_turn_risk_forecast_line(state, session);
	if (risk_line != key::empty) {
		lines.push_back(gd::format(state, key::pressure_s_2, {str(risk_line)}));
	}
	const Atom management_line = describe_management_watch(state, session);
	if (management_line != key::empty) {
		lines.push_back(gd::format(state, key::town_lines_s, {str(management_line)}));
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_end_turn_forecast_compact(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	const int64_t next_day = gd::add(session_day(state, session), 1);
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::day_d, {int_value(next_day)}));
	parts.push_back(_end_turn_income_forecast_line(state, session, next_day));
	parts.push_back(_end_turn_movement_forecast_line(state, session));
	const Atom risk_line = _end_turn_risk_forecast_line(state, session);
	if (risk_line != key::empty) {
		parts.push_back(risk_line);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef describe_end_turn_forecast_surfaces(State &state, DictRef session, DictRef refresh_watch_context) {
	const bool no_context = gd::is_empty(state, refresh_watch_context);
	if (no_context) {
		normalize_overworld_state(state, session);
	}
	const int64_t next_day = gd::add(session_day(state, session), 1);
	const Atom income_line = _end_turn_income_forecast_line(state, session, next_day);
	const Atom muster_line = _end_turn_muster_forecast_line(state, session, next_day);
	const Atom movement_line = _end_turn_movement_forecast_line(state, session);
	Atom risk_line = key::empty;
	Atom management_line = key::empty;
	if (no_context) {
		risk_line = _end_turn_risk_forecast_line(state, session);
		management_line = describe_management_watch(state, session);
	} else {
		risk_line = _end_turn_risk_forecast_line_from_watch_context(state, refresh_watch_context);
		management_line = field_text(state, refresh_watch_context, key::management_watch, key::empty);
	}
	std::vector<Atom> full_lines;
	full_lines.push_back(gd::format(state, key::next_day_day_d_s_s, {int_value(next_day), str(income_line), str(muster_line)}));
	full_lines.push_back(gd::format(state, key::movement_s, {str(movement_line)}));
	if (risk_line != key::empty) {
		full_lines.push_back(gd::format(state, key::pressure_s_2, {str(risk_line)}));
	}
	if (management_line != key::empty) {
		full_lines.push_back(gd::format(state, key::town_lines_s, {str(management_line)}));
	}
	std::vector<Atom> compact_parts;
	compact_parts.push_back(gd::format(state, key::day_d, {int_value(next_day)}));
	compact_parts.push_back(income_line);
	compact_parts.push_back(movement_line);
	if (risk_line != key::empty) {
		compact_parts.push_back(risk_line);
	}
	const DictRef surfaces = state.new_dict();
	state.set(surfaces, str(key::forecast), str(join_atoms(state, key::newline, full_lines)));
	state.set(surfaces, str(key::forecast_compact), str(join_atoms(state, key::space_bar_space, compact_parts)));
	return surfaces;
}

DictRef describe_command_risk_surfaces(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	return _command_risk_surfaces_from_forecast(state, _command_risk_forecast(state, session));
}

DictRef _command_risk_surfaces_from_forecast(State &state, DictRef forecast) {
	const DictRef surfaces = state.new_dict();
	if (!gd::bool_field(state, forecast, key::has_risk, false)) {
		state.set(surfaces, str(key::risk), str(key::command_risk_steady_watch_no_concrete));
		state.set(surfaces, str(key::forecast), str(key::empty));
		state.set(surfaces, str(key::forecast_data), dict_value(forecast));
		return surfaces;
	}
	state.set(surfaces, str(key::risk), str(gd::format(state, key::command_risk_s, {str(field_text(state, forecast, key::summary, key::empty))})));
	state.set(surfaces, str(key::forecast), str(join_values(state, key::newline, field_or_new_array(state, forecast, key::lines))));
	state.set(surfaces, str(key::forecast_data), dict_value(forecast));
	return surfaces;
}

Atom consume_command_risk_forecast(State &state, DictRef session) {
	const Atom forecast_text = describe_command_risk_forecast(state, session);
	if (forecast_text == key::empty || !_should_surface_command_risk_forecast(state, session)) {
		return key::empty;
	}
	mark_panel_shown(state, session, key::command_risk_forecast);
	return forecast_text;
}

Atom _end_turn_income_forecast_line(State &state, DictRef session, int64_t next_day) {
	const Atom income_summary = _describe_resource_delta(state, dict_value(_player_daily_income_projection(state, session, next_day)));
	if (income_summary == key::empty) {
		return key::income_steady;
	}
	return gd::format(state, key::income_s_2, {str(income_summary)});
}

Atom _end_turn_muster_forecast_line(State &state, DictRef session, int64_t next_day) {
	if (is_weekly_growth_day(state, next_day)) {
		std::vector<Atom> previews;
		const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
		const int64_t count = ai::vsize(state, towns);
		for (int64_t index = 0; index < count; ++index) {
			const Value town = ai::vindex(state, towns, int_value(index));
			if (!gd::is_dict(town) || field_text(state, town.ref, key::owner, key::neutral) != key::player) {
				continue;
			}
			const DictRef projection = _project_player_town_at_daybreak(state, session, town.ref, index, next_day);
			const Value projected_session = state.get(projection, str(key::session), dict_value(session));
			const DictRef projected_town = gd::as_dict(state.get(projection, str(key::town), town));
			const DictRef growth = town_weekly_growth(state, projected_town, projected_session);
			const Atom growth_summary = _describe_recruit_delta(state, dict_value(growth));
			if (growth_summary != key::empty) {
				previews.push_back(gd::format(state, key::s_s, {str(_town_name(state, town.ref)), str(growth_summary)}));
			}
			if (previews.size() >= 2) {
				break;
			}
		}
		if (previews.empty()) {
			return key::weekly_muster_resolves;
		}
		return gd::format(state, key::weekly_muster_s_2, {str(join_atoms(state, key::semicolon_space, previews))});
	}
	const int64_t days_until = compat::engine_max<int64_t>(1, gd::sub(next_weekly_growth_day(state, session_day(state, session)), next_day));
	return gd::format(state, key::muster_day_d_in_d_day, {
			int_value(next_weekly_growth_day(state, session_day(state, session))),
			int_value(days_until),
			str(plural_s(days_until)),
	});
}

Atom _end_turn_movement_forecast_line(State &state, DictRef session) {
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const int64_t max_movement = _movement_max_from_hero(state, hero, dict_value(session));
	return gd::format(state, key::move_resets_d_d, {int_value(max_movement), int_value(max_movement)});
}

Atom _end_turn_risk_forecast_line(State &state, DictRef session) {
	const DictRef risk_surface = describe_command_risk_surfaces(state, session);
	const Atom risk_text = gd::strip_edges(state, field_text(state, risk_surface, key::risk, key::empty));
	if (risk_text == key::empty || text_contains(state, risk_text, key::steady_watch_2)) {
		const Atom local_pressure = _local_visible_threat_summary(state, session, key::empty);
		return local_pressure != key::empty ? local_pressure : key::watch_steady;
	}
	return _short_player_text(state, last_line(state, risk_text), 96);
}

Atom _end_turn_risk_forecast_line_from_watch_context(State &state, DictRef refresh_watch_context) {
	Value risk_surface_value;
	const bool has_surface = state.lookup(refresh_watch_context, str(key::command_risk_surfaces), risk_surface_value) && gd::is_dict(risk_surface_value);
	// risk_surface.get("risk", ""), the surface {} when missing or not a Dictionary.
	const Atom risk_text = gd::strip_edges(state, has_surface ? field_text(state, risk_surface_value.ref, key::risk, key::empty) : key::empty);
	if (risk_text == key::empty || text_contains(state, risk_text, key::steady_watch_2)) {
		const Atom local_pressure = field_text(state, refresh_watch_context, key::local_pressure, key::empty);
		return local_pressure != key::empty ? local_pressure : key::watch_steady;
	}
	return _short_player_text(state, last_line(state, risk_text), 96);
}

Atom describe_management_watch(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	return _describe_management_watch_from_normalized_session(state, session);
}

Atom _describe_management_watch_from_normalized_session(State &state, DictRef session) {
	Atom project_summary = key::empty;
	Atom disruption_summary = key::empty;
	Atom recovery_summary = key::empty;
	Atom delivery_summary = key::empty;
	int64_t project_score = -1;
	int64_t disruption_score = -1;
	int64_t recovery_score = -1;
	int64_t delivery_score = -1;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || field_text(state, town.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const Atom town_name = _town_name(state, town.ref);
		const DictRef logistics = town_logistics_state(state, session, town.ref);
		const DictRef recovery = town_recovery_state(state, session, town.ref);
		const DictRef capital_project = town_capital_project_state(state, town.ref, dict_value(session));
		const Atom role = town_strategic_role(state, town.ref);
		int64_t local_project_score = gd::int_field(state, capital_project, key::progress_complete, 0);
		if (role == key::capital) {
			local_project_score = gd::add(local_project_score, 4);
		} else if (role == key::stronghold) {
			local_project_score = gd::add(local_project_score, 2);
		}
		if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
			local_project_score = gd::add(local_project_score, 6);
		}
		if (local_project_score > project_score
				&& (role == key::capital || role == key::stronghold || gd::int_field(state, capital_project, key::total, 0) > 0)) {
			project_score = local_project_score;
			project_summary = gd::format(state, key::s_project_d_d_s, {
					str(town_name),
					int_value(gd::int_field(state, capital_project, key::progress_complete, 0)),
					int_value(gd::int_field(state, capital_project, key::progress_total, 0)),
					str(gd::bool_field(state, capital_project, key::vulnerable, false) ? key::vulnerable_2 : key::empty),
			});
		}
		const int64_t local_disruption_score = gd::add(gd::mul(gd::int_field(state, logistics, key::disrupted_count, 0), 2), gd::int_field(state, logistics, key::threatened_count, 0));
		if (local_disruption_score > disruption_score && local_disruption_score > 0) {
			disruption_score = local_disruption_score;
			disruption_summary = gd::format(state, key::s_logistics_s, {str(town_name), str(field_text(state, logistics, key::summary, key::empty))});
		}
		const int64_t local_recovery_score = gd::int_field(state, recovery, key::pressure, 0);
		if (local_recovery_score > recovery_score) {
			recovery_score = local_recovery_score;
			if (gd::bool_field(state, recovery, key::active, false)) {
				recovery_summary = gd::format(state, key::s_s, {str(town_name), str(field_text(state, recovery, key::summary, key::empty))});
			}
		}
		const int64_t local_delivery_score = gd::add(gd::mul(gd::int_field(state, logistics, key::delivery_count, 0), 2), gd::int_field(state, logistics, key::threatened_count, 0));
		if (local_delivery_score > delivery_score && gd::int_field(state, logistics, key::delivery_count, 0) > 0) {
			delivery_score = local_delivery_score;
			Value delivery_labels;
			if (state.lookup(logistics, str(key::delivery_site_labels), delivery_labels) && gd::is_array(delivery_labels) && state.array_size(delivery_labels.ref) > 0) {
				delivery_summary = gd::format(state, key::s_s, {str(town_name), str(value_text(state, state.at(delivery_labels.ref, 0)))});
			}
		}
	}
	std::vector<Atom> parts;
	if (project_summary != key::empty) {
		parts.push_back(project_summary);
	}
	if (disruption_summary != key::empty) {
		parts.push_back(disruption_summary);
	}
	if (recovery_summary != key::empty) {
		parts.push_back(recovery_summary);
	}
	if (delivery_summary != key::empty) {
		parts.push_back(delivery_summary);
	}
	if (parts.empty()) {
		return key::town_lines_are_stable;
	}
	return join_atoms(state, key::space_bar_space, parts);
}

bool _should_surface_command_briefing(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return false;
	}
	if (session_text(state, session, key::scenario_status) != key::in_progress
			|| value_text(state, gd::index(state, session, str(key::game_state))) != key::overworld) {
		return false;
	}
	if (session_day(state, session) != 1
			|| field_text(state, gd::as_dict(gd::index(state, session, str(key::flags))), key::last_action, key::empty) != key::empty) {
		return false;
	}
	return panel_not_shown(state, session, key::command_briefing);
}

bool _should_surface_command_risk_forecast(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return false;
	}
	if (session_text(state, session, key::scenario_status) != key::in_progress
			|| value_text(state, gd::index(state, session, str(key::game_state))) != key::overworld) {
		return false;
	}
	const DictRef forecast = _command_risk_forecast(state, session);
	if (!gd::bool_field(state, forecast, key::gate_end_turn, false)) {
		return false;
	}
	return panel_not_shown(state, session, key::command_risk_forecast);
}

ArrayRef _command_briefing_lines(State &state, DictRef session) {
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, session_text(state, session, key::scenario_id));
	const ArrayRef lines = state.new_array();
	const Atom posture_line = _command_briefing_posture_line(state, session);
	if (posture_line != key::empty) {
		state.append(lines, str(posture_line));
	}
	if (!gd::is_empty(state, scenario)) {
		const Atom objective_summary = _scenario_opening_objective_summary(state, session, scenario);
		if (objective_summary != key::empty) {
			for (const Atom piece : split_text(state, objective_summary, "\n", true)) {
				state.append(lines, str(piece));
			}
		}
	}
	const Atom logistics_line = _command_briefing_logistics_line(state, session);
	if (logistics_line != key::empty) {
		state.append(lines, str(logistics_line));
	}
	const Atom pressure_line = _command_briefing_pressure_line(state, session, scenario);
	if (pressure_line != key::empty) {
		state.append(lines, str(pressure_line));
	}
	const Atom orders_line = _command_briefing_orders_line(state, session, scenario);
	if (orders_line != key::empty) {
		state.append(lines, str(orders_line));
	}
	return lines;
}

Atom _command_briefing_posture_line(State &state, DictRef session) {
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	if (ai::vempty(state, hero)) {
		return key::empty;
	}
	const Vector2i pos = hero_position(state, session);
	const Atom terrain = _terrain_name_at(state, session, pos.x, pos.y);
	const Value movement = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	const Value spellbook = ai::vget(state, hero, key::spellbook, dict_value(state.new_dict()));
	const Value mana = ai::vget(state, spellbook, key::mana, dict_value(state.new_dict()));
	const DictRef army_totals = _army_totals(state, gd::as_dict(ai::vget(state, hero, key::army, dict_value(state.new_dict()))));
	return gd::format(state, key::command_posture_s_deploys_on_s, {
			str(value_field_text(state, hero, key::name, key::Hero)),
			str(terrain),
			int_value(pos.x),
			int_value(pos.y),
			int_value(gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)))),
			int_value(gd::to_int(state, ai::vget(state, movement, key::max, int_value(0)))),
			int_value(hero_command_rules::scouting_radius_for_hero(state, gd::as_dict(hero))),
			int_value(gd::to_int(state, ai::vget(state, mana, key::current, int_value(0)))),
			int_value(gd::to_int(state, ai::vget(state, mana, key::max, int_value(0)))),
			int_value(gd::int_field(state, army_totals, key::headcount, 0)),
			int_value(gd::int_field(state, army_totals, key::groups, 0)),
	});
}

Atom _command_briefing_logistics_line(State &state, DictRef session) {
	const Vector2i pos = hero_position(state, session);
	const DictRef town_result = _nearest_town_for_controller(state, session, key::player, pos.x, pos.y);
	const DictRef site_plan = _nearest_logistics_plan(state, session);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		if (gd::is_empty(state, site_plan)) {
			return key::logistics_watch_no_owned_town_anchors;
		}
		return gd::format(state, key::logistics_watch_no_owned_town_anchors_2, {str(field_text(state, site_plan, key::summary, key::empty))});
	}
	const Value town = field_or_new_dict(state, town_result, key::town);
	const int64_t distance = tile_distance(
			pos.x, pos.y,
			gd::to_int(state, ai::vget(state, town, key::x, int_value(0))),
			gd::to_int(state, ai::vget(state, town, key::y, int_value(0))));
	const DictRef logistics = town_logistics_state(state, session, gd::as_dict(town));
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::s_d_tile_s_away, {str(_town_name(state, gd::as_dict(town))), int_value(distance), str(plural_s(distance))}));
	parts.push_back(field_text(state, logistics, key::summary, key::empty));
	if (gd::int_field(state, logistics, key::disrupted_count, 0) > 0 && has_labels(state, logistics, key::disrupted_site_labels)) {
		parts.push_back(gd::format(state, key::denied_s, {str(join_values(state, key::comma_space, gd::field(state, logistics, key::disrupted_site_labels), 2))}));
	} else if (gd::int_field(state, logistics, key::threatened_count, 0) > 0 && has_labels(state, logistics, key::threatened_site_labels)) {
		parts.push_back(gd::format(state, key::threatened_s, {str(join_values(state, key::comma_space, gd::field(state, logistics, key::threatened_site_labels), 2))}));
	} else if (has_labels(state, logistics, key::missing_family_labels)) {
		parts.push_back(gd::format(state, key::missing_s_5, {str(join_values(state, key::comma_space, gd::field(state, logistics, key::missing_family_labels), 2))}));
	}
	if (!gd::is_empty(state, site_plan)) {
		parts.push_back(field_text(state, site_plan, key::summary, key::empty));
	}
	return gd::format(state, key::logistics_watch_s, {str(join_atoms(state, key::space_bar_space, parts))});
}

Atom _command_briefing_pressure_line(State &state, DictRef session, DictRef scenario) {
	const Atom local_summary = _local_visible_threat_summary(state, session, key::empty);
	if (local_summary != key::empty) {
		return gd::format(state, key::pressure_watch_s, {str(local_summary)});
	}
	if (gd::is_empty(state, scenario)) {
		return key::pressure_watch_no_hostile_lane_is;
	}
	const ArrayRef operational_lines = _scenario_enemy_operational_lines(state, session, scenario);
	if (state.array_size(operational_lines) > 0) {
		const Atom line = value_text(state, state.at(operational_lines, 0));
		if (gd::begins_with(state, line, key::enemy_posture)) {
			return gd::format(state, key::pressure_watch_s, {str(gd::trim_prefix(state, line, key::enemy_posture))});
		}
		return gd::format(state, key::pressure_watch_s, {str(line)});
	}
	return key::pressure_watch_no_hostile_lane_is;
}

Atom _command_briefing_orders_line(State &state, DictRef session, DictRef scenario) {
	const ArrayRef context_actions = get_context_actions(state, session);
	if (state.array_size(context_actions) > 0) {
		const Value action = state.at(context_actions, 0);
		const DictRef context = get_active_context(state, session);
		return gd::format(state, key::immediate_orders_s, {str(_context_action_briefing(state, session, action, context))});
	}
	const DictRef site_plan = _nearest_logistics_plan(state, session);
	if (!gd::is_empty(state, site_plan)) {
		return gd::format(state, key::immediate_orders_s, {str(field_text(state, site_plan, key::order, key::advance_to_stabilize_the_nearest_logistics))});
	}
	const DictRef encounter_plan = _nearest_visible_encounter_plan(state, session);
	if (!gd::is_empty(state, encounter_plan)) {
		return gd::format(state, key::immediate_orders_s, {str(field_text(state, encounter_plan, key::order, key::advance_on_the_nearest_hostile_contact))});
	}
	if (!gd::is_empty(state, scenario)) {
		const Atom first_contact = _scenario_first_contact_summary(state, scenario);
		if (first_contact != key::empty) {
			const std::vector<Atom> contact_lines = split_text(state, first_contact, "\n", true);
			if (!contact_lines.empty()) {
				return gd::format(state, key::immediate_orders_s, {str(gd::trim_prefix(state, contact_lines[0], key::likely_first_contact))});
			}
		}
	}
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (gd::is_dict(objectives)) {
		const Value bucket = state.get(objectives.ref, str(key::victory), array_value(state.new_array()));
		const ArrayRef victory_labels = _scenario_objective_labels_from_bucket(state, session, bucket, 1);
		if (state.array_size(victory_labels) > 0) {
			return gd::format(state, key::immediate_orders_advance_on_s_while, {str(value_text(state, state.at(victory_labels, 0)))});
		}
	}
	return key::immediate_orders_expand_the_scout_ring;
}

Atom _command_commitment_action_line(State &state, DictRef session) {
	const ArrayRef context_actions = get_context_actions(state, session);
	if (state.array_size(context_actions) > 0) {
		const Value action = state.at(context_actions, 0);
		if (gd::is_dict(action)) {
			return _command_commitment_action_summary(state, session, action.ref);
		}
	}
	const DictRef site_plan = _nearest_logistics_plan(state, session);
	if (!gd::is_empty(state, site_plan)) {
		return field_text(state, site_plan, key::order, key::advance_to_stabilize_the_nearest_logistics);
	}
	const DictRef encounter_plan = _nearest_visible_encounter_plan(state, session);
	if (!gd::is_empty(state, encounter_plan)) {
		return field_text(state, encounter_plan, key::order, key::advance_on_the_nearest_hostile_contact);
	}
	// var scenario := ContentService.get_scenario_readonly(session.scenario_id):
	// a read the body never uses.
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (gd::is_dict(objectives)) {
		const Value bucket = state.get(objectives.ref, str(key::victory), array_value(state.new_array()));
		const ArrayRef victory_labels = _scenario_objective_labels_from_bucket(state, session, bucket, 1);
		if (state.array_size(victory_labels) > 0) {
			return gd::format(state, key::advance_on_s_while_the_front, {str(value_text(state, state.at(victory_labels, 0)))});
		}
	}
	return key::expand_the_scout_ring_secure_the;
}

Atom _command_commitment_action_summary(State &state, DictRef session, DictRef action) {
	if (state.has(action, str(key::summary))) {
		return field_text(state, action, key::summary, key::empty);
	}
	const DictRef context = get_active_context(state, session);
	return _context_action_briefing(state, session, dict_value(action), context);
}

Atom _command_commitment_route_line(State &state, DictRef session) {
	const DictRef context = get_active_context(state, session);
	const Atom context_type = field_text(state, context, key::type, key::empty_2);
	if (context_type == key::town) {
		const Value town = field_or_new_dict(state, context, key::town);
		if (value_field_text(state, town, key::owner, key::neutral) == key::player) {
			const DictRef logistics = town_logistics_state(state, session, gd::as_dict(town));
			const DictRef recovery = town_recovery_state(state, session, gd::as_dict(town));
			std::vector<Atom> parts;
			parts.push_back(gd::format(state, key::s_anchors_this_lane, {str(_town_name(state, gd::as_dict(town)))}));
			parts.push_back(gd::format(state, key::readiness_d_text, {int_value(town_battle_readiness(state, gd::as_dict(town), dict_value(session)))}));
			if (field_text(state, logistics, key::summary, key::empty) != key::empty) {
				parts.push_back(field_text(state, logistics, key::summary, key::empty));
			}
			if (gd::bool_field(state, recovery, key::active, false)) {
				parts.push_back(field_text(state, recovery, key::summary, key::empty));
			}
			return join_atoms(state, key::space_bar_space, parts);
		}
		return gd::format(state, key::s_is_still_off_the_banner, {str(_town_name(state, gd::as_dict(town)))});
	}
	if (context_type == key::resource) {
		const Value node = field_or_new_dict(state, context, key::node);
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, value_field_text(state, node, key::site_id, key::empty));
		const Atom site_name = field_text(state, site, key::name, key::frontier_site);
		const DictRef response_state = _resource_site_response_state(state, session, gd::as_dict(node), site);
		const DictRef linked_town_result = _resource_node_linked_town(state, session, gd::as_dict(node), key::player);
		const Value linked_town = field_or_new_dict(state, linked_town_result, key::town);
		Atom linked_clause = key::empty;
		if (!ai::vempty(state, linked_town)) {
			linked_clause = gd::format(state, key::linked_s_2, {str(_town_name(state, gd::as_dict(linked_town)))});
		}
		if (gd::bool_field(state, response_state, key::active, false)) {
			const int64_t remaining_days = gd::int_field(state, response_state, key::remaining_days, 0);
			std::string response_line = state.text(gd::format(state, key::s_escorted_for_d_day_s, {str(site_name), int_value(remaining_days), str(plural_s(remaining_days))}));
			const Atom commander_name = field_text(state, response_state, key::commander_name, key::empty);
			if (commander_name != key::empty) {
				response_line += state.text(gd::format(state, key::s_detached_2, {str(commander_name)}));
			}
			const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
			if (impact_summary != key::empty) {
				response_line += state.text(gd::format(state, key::space_bar_space_s, {str(impact_summary)}));
			}
			return state.intern(response_line + state.text(linked_clause));
		}
		if (_resource_site_is_persistent(state, site)) {
			if (value_field_text(state, node, key::collected_by_faction_id, key::empty) == key::player
					&& _resource_site_under_threat(state, session, gd::as_dict(node), key::player)) {
				return gd::format(state, key::s_is_under_threat_s_leaving, {str(site_name), str(linked_clause)});
			}
			return gd::format(state, key::s_can_s_s, {str(site_name), str(_resource_site_opening_value(state, site)), str(linked_clause)});
		}
		return gd::format(state, key::s_remains_claimable_on_the_active, {str(site_name)});
	}
	if (context_type == key::encounter) {
		const Value encounter = field_or_new_dict(state, context, key::encounter);
		return gd::format(state, key::s_blocks_the_active_march_line, {str(encounter_display_name(state, gd::as_dict(encounter)))});
	}
	if (context_type == key::artifact) {
		const Value artifact_node = field_or_new_dict(state, context, key::node);
		return gd::format(state, key::s_lies_exposed_on_the_active, {
				str(artifact_rules::artifact_name(state, value_field_text(state, artifact_node, key::artifact_id, key::empty))),
				str(artifact_rules::describe_artifact_short(state, value_field_text(state, artifact_node, key::artifact_id, key::empty))),
		});
	}
	const DictRef site_plan = _nearest_logistics_plan(state, session);
	if (!gd::is_empty(state, site_plan)) {
		return field_text(state, site_plan, key::summary, key::the_nearest_logistics_lane_needs_attention);
	}
	const Atom local_pressure = _local_visible_threat_summary(state, session, key::empty);
	if (local_pressure != key::empty) {
		return local_pressure;
	}
	const Atom management_watch = describe_management_watch(state, session);
	if (management_watch != key::empty) {
		return management_watch;
	}
	return key::no_visible_hostile_pressure_is_crowding;
}

Atom _command_commitment_coverage_line(State &state, DictRef session) {
	std::vector<Atom> parts;
	const Value movement = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	parts.push_back(gd::format(state, key::move_d_d_2, {
			int_value(gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)))),
			int_value(gd::to_int(state, ai::vget(state, movement, key::max, int_value(0)))),
	}));
	const DictRef reserve_support = _nearest_reserve_hero_support(state, session);
	if (gd::is_empty(state, reserve_support)) {
		parts.push_back(key::no_reserve_commander_covers_the_active);
	} else {
		const int64_t reserve_distance = gd::int_field(state, reserve_support, key::distance, 0);
		const Atom reserve_name = field_text(state, reserve_support, key::name, key::reserve_commander);
		if (reserve_distance <= 0) {
			parts.push_back(gd::format(state, key::reserve_s_is_already_on_this, {str(reserve_name)}));
		} else {
			parts.push_back(gd::format(state, key::reserve_s_d_tile_s_s, {
					str(reserve_name),
					int_value(reserve_distance),
					str(plural_s(reserve_distance)),
					str(field_text(state, reserve_support, key::direction, key::away)),
			}));
		}
	}
	const Vector2i pos = hero_position(state, session);
	const DictRef nearest_town_result = _nearest_town_for_controller(state, session, key::player, pos.x, pos.y);
	if (gd::int_field(state, nearest_town_result, key::index, -1) >= 0) {
		const Value town = field_or_new_dict(state, nearest_town_result, key::town);
		const int64_t town_x = gd::to_int(state, ai::vget(state, town, key::x, int_value(0)));
		const int64_t town_y = gd::to_int(state, ai::vget(state, town, key::y, int_value(0)));
		const int64_t distance = tile_distance(pos.x, pos.y, town_x, town_y);
		if (distance <= 0) {
			parts.push_back(gd::format(state, key::s_anchors_this_tile, {str(_town_name(state, gd::as_dict(town)))}));
		} else {
			parts.push_back(gd::format(state, key::s_d_tile_s_s, {
					str(_town_name(state, gd::as_dict(town))),
					int_value(distance),
					str(plural_s(distance)),
					str(_direction_from_to(state, pos, Vector2i::of(town_x, town_y))),
			}));
		}
	} else {
		parts.push_back(key::no_owned_town_anchors_the_current_2);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _command_commitment_hold_line(State &state, DictRef session) {
	const DictRef forecast = _command_risk_forecast(state, session);
	return _command_commitment_hold_line_from_forecast(state, session, forecast);
}

Atom _command_commitment_hold_line_from_watch_context(State &state, DictRef session, DictRef refresh_watch_context) {
	Value forecast_value;
	if (state.lookup(refresh_watch_context, str(key::command_risk_forecast), forecast_value) && gd::is_dict(forecast_value)) {
		return _command_commitment_hold_line_from_forecast(state, session, forecast_value.ref);
	}
	return _command_commitment_hold_line_from_forecast(state, session, state.new_dict());
}

Atom _command_commitment_hold_line_from_forecast(State &state, DictRef session, DictRef forecast) {
	if (gd::bool_field(state, forecast, key::has_risk, false)) {
		Value lines;
		if (state.lookup(forecast, str(key::lines), lines) && gd::is_array(lines) && state.array_size(lines.ref) > 1) {
			return gd::trim_prefix(state, value_text(state, state.at(lines.ref, 1)), key::text_2);
		}
		return field_text(state, forecast, key::summary, key::the_frontier_stays_strained);
	}
	if (state.array_size(get_context_actions(state, session)) > 0) {
		return key::no_concrete_next_day_break_is;
	}
	return key::no_concrete_next_day_break_is_2;
}

DictRef _nearest_reserve_hero_support(State &state, DictRef session) {
	const Vector2i pos = hero_position(state, session);
	const Atom active_hero_id = field_text(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	DictRef best = state.new_dict();
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (field_text(state, hero.ref, key::id, key::empty) == active_hero_id) {
			continue;
		}
		const Value hero_pos = field_or_new_dict(state, hero.ref, key::position);
		const Vector2i target = Vector2i::of(
				gd::to_int(state, ai::vget(state, hero_pos, key::x, int_value(0))),
				gd::to_int(state, ai::vget(state, hero_pos, key::y, int_value(0))));
		const int64_t distance = tile_distance(pos.x, pos.y, target.x, target.y);
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::id), str(field_text(state, hero.ref, key::id, key::empty)));
		state.set(candidate, str(key::name), str(field_text(state, hero.ref, key::name, key::reserve_commander)));
		state.set(candidate, str(key::distance), int_value(distance));
		state.set(candidate, str(key::direction), str(_direction_from_to(state, pos, target)));
		if (gd::is_empty(state, best) || distance < gd::int_field(state, best, key::distance, 9999)) {
			best = candidate;
		}
	}
	return best;
}

DictRef _nearest_logistics_plan(State &state, DictRef session) {
	const Vector2i pos = hero_position(state, session);
	DictRef best = state.new_dict();
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node) || !overworld_level_rules::on_level(state, node, hero_level(state, session))) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, field_text(state, node.ref, key::site_id, key::empty));
		if (!_resource_site_is_persistent(state, site)) {
			continue;
		}
		const int64_t x = gd::int_field(state, node.ref, key::x, -1);
		const int64_t y = gd::int_field(state, node.ref, key::y, -1);
		if (!is_tile_visible(state, session, x, y)) {
			continue;
		}
		const Atom controller = player_identity_rules::resource_controller_id(state, node.ref);
		const int64_t distance = tile_distance(pos.x, pos.y, x, y);
		const Vector2i tile = Vector2i::of(x, y);
		int64_t priority = 99;
		Atom summary = key::empty;
		Atom order = key::empty;
		if (controller == key::player) {
			if (_resource_site_under_threat(state, session, node.ref, key::player)) {
				const DictRef response_state = _resource_site_response_state(state, session, node.ref, site);
				priority = 0;
				summary = gd::format(state, key::s_is_threatened_d_tile_s, {
						str(field_text(state, site, key::name, key::frontier_site)),
						int_value(distance),
						str(plural_s(distance)),
						str(_direction_from_to(state, pos, tile)),
				});
				if (gd::bool_field(state, response_state, key::active, false) && field_text(state, response_state, key::commander_name, key::empty) != key::empty) {
					const Atom contested = gd::format(state, key::escort_by_s_is_being_contested, {str(field_text(state, response_state, key::commander_name, key::empty))});
					summary = state.intern(state.text(summary) + state.text(contested));
				}
				order = gd::format(state, key::march_d_tile_s_s_to, {
						int_value(distance),
						str(plural_s(distance)),
						str(_direction_from_to(state, pos, tile)),
						str(field_text(state, site, key::name, key::the_route_2)),
				});
			} else {
				const DictRef response_state = _resource_site_response_state(state, session, node.ref, site);
				if (gd::int_field(state, response_state, key::watch_days, 0) > 0 && !gd::bool_field(state, response_state, key::active, false)) {
					priority = 2;
					summary = gd::format(state, key::s_is_ready_for_s_d, {
							str(field_text(state, site, key::name, key::frontier_site)),
							str(ascii_lower(state, field_text(state, response_state, key::action_label, key::route_security_2))),
							int_value(distance),
							str(plural_s(distance)),
							str(_direction_from_to(state, pos, tile)),
					});
					order = gd::format(state, key::march_d_tile_s_s_and, {
							int_value(distance),
							str(plural_s(distance)),
							str(_direction_from_to(state, pos, tile)),
							str(field_text(state, response_state, key::action_label, key::route_security_2)),
							str(field_text(state, site, key::name, key::the_site)),
					});
				}
			}
		} else {
			priority = 1;
			summary = gd::format(state, key::s_lies_d_tile_s_s, {
					str(field_text(state, site, key::name, key::frontier_site)),
					int_value(distance),
					str(plural_s(distance)),
					str(_direction_from_to(state, pos, tile)),
					str(_resource_site_opening_value(state, site)),
			});
			order = gd::format(state, key::claim_s_d_tile_s_s, {
					str(field_text(state, site, key::name, key::the_frontier_site)),
					int_value(distance),
					str(plural_s(distance)),
					str(_direction_from_to(state, pos, tile)),
					str(_resource_site_opening_value(state, site)),
			});
		}
		if (priority >= 99) {
			continue;
		}
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::priority), int_value(priority));
		state.set(candidate, str(key::distance), int_value(distance));
		state.set(candidate, str(key::summary), str(summary));
		state.set(candidate, str(key::order), str(order));
		if (gd::is_empty(state, best)
				|| gd::int_field(state, candidate, key::priority, 99) < gd::int_field(state, best, key::priority, 99)
				|| (gd::int_field(state, candidate, key::priority, 99) == gd::int_field(state, best, key::priority, 99)
						&& gd::int_field(state, candidate, key::distance, 9999) < gd::int_field(state, best, key::distance, 9999))) {
			best = candidate;
		}
	}
	return best;
}

DictRef _nearest_visible_encounter_plan(State &state, DictRef session) {
	const Vector2i pos = hero_position(state, session);
	DictRef best = state.new_dict();
	for (const Value &encounter : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(encounter)
				|| !overworld_level_rules::on_level(state, encounter, hero_level(state, session))
				|| is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		const int64_t x = gd::int_field(state, encounter.ref, key::x, -1);
		const int64_t y = gd::int_field(state, encounter.ref, key::y, -1);
		if (!is_tile_visible(state, session, x, y)) {
			continue;
		}
		const int64_t distance = tile_distance(pos.x, pos.y, x, y);
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::distance), int_value(distance));
		state.set(candidate, str(key::order), str(gd::format(state, key::advance_d_tile_s_s_and, {
				int_value(distance),
				str(plural_s(distance)),
				str(_direction_from_to(state, pos, Vector2i::of(x, y))),
				str(encounter_display_name(state, encounter.ref)),
				str(_terrain_name_at(state, session, x, y)),
		})));
		if (gd::is_empty(state, best) || gd::int_field(state, candidate, key::distance, 9999) < gd::int_field(state, best, key::distance, 9999)) {
			best = candidate;
		}
	}
	return best;
}

Atom _direction_from_to(State &state, Vector2i origin, Vector2i target) {
	Atom vertical = key::empty;
	Atom horizontal = key::empty;
	if (target.y < origin.y) {
		vertical = key::north;
	} else if (target.y > origin.y) {
		vertical = key::south;
	}
	if (target.x < origin.x) {
		horizontal = key::west;
	} else if (target.x > origin.x) {
		horizontal = key::east;
	}
	if (vertical != key::empty && horizontal != key::empty) {
		return gd::format(state, key::s_s_8, {str(vertical), str(horizontal)});
	}
	if (vertical != key::empty) {
		return vertical;
	}
	if (horizontal != key::empty) {
		return horizontal;
	}
	return key::here;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
