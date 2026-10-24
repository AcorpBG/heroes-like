// OverworldRules' command risk forecast (Phase 5 slice 06b, group "forecast"):
// the next-day risk items of the player's towns, their logistics, the defeat
// objectives, the computer players' postures and the active command's field
// position, reduced to the forecast whose signature gates the end of a turn;
// the daybreak projection of a player town (occupation and recovery relief),
// a town's capital project state, the fog grid reads it needs, and the
// EnemyAdventureRules / ScenarioRules helpers on those paths.
//
// A player town under threat, a raid on it, a town front, the computer players'
// raid limits and the authored enemy_pressure_at_least and encounter_resolved
// defeat objectives call the AI turn's ports (Phase 4 slice 4.4). Those two
// objective types belong to the archived authored scenarios alone, and
// ScenarioRules._objective_met leaves them to GDScript. An open fog read scope
// throws state::NotPorted, so the GDScript body runs instead.

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

// A new SessionData's get_instance_id(): each projected view its own, -1, -2
// and on, which no object's id is (an object's is positive, a RefCounted's
// has bit 63 and a slot's validator above bit 24), so the read scopes' caches
// keep its entries apart, as GDScript's keep the new SessionData's.
int64_t projected_instance_id() {
	static std::atomic<int64_t> last{ 0 };
	return -(++last);
}

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

[[noreturn]] void not_ported(const std::string &what) {
	throw state::NotPorted("left to GDScript: " + what);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback = key::empty) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}): the field, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// d.get(key, []): the field, or a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// session.scenario_id and the session's other String fields (the view holds them).
Atom session_text(State &state, DictRef session, Atom field) {
	return gd::to_string(gd::index(state, session, str(field)));
}

// session.day.
int64_t session_day(State &state, DictRef session) {
	return gd::to_int(state, gd::index(state, session, str(key::day)));
}

// ContentService.get_scenario_readonly(session.scenario_id).
DictRef session_scenario(State &state, DictRef session) {
	return gd::content_row(state, ContentTable::Scenario, session_text(state, session, key::scenario_id));
}

// "" if count == 1 else "s".
Value plural_s(int64_t count) {
	return str(count == 1 ? key::empty : key::s);
}

// role in ["capital", "stronghold"].
bool capital_or_stronghold(Atom role) {
	return role == key::capital || role == key::stronghold;
}

// separator.join(parts) of Strings a function keeps to itself.
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

// separator.join(values.slice(0, count)) of an Array: the Array becomes a
// PackedStringArray, each item as String() converts it.
Atom join_first(State &state, Atom separator, ArrayRef values, int64_t count) {
	std::string joined;
	const int64_t size = compat::engine_min<int64_t>(count, state.array_size(values));
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify_or_fallback(state, state.at(values, index)));
	}
	return state.intern(joined);
}

// value not in parts (an Array of Strings kept as atoms).
bool has_atom(const std::vector<Atom> &parts, Atom value) {
	return std::find(parts.begin(), parts.end(), value) != parts.end();
}

// s.to_lower() of ASCII text (the Unicode case tables are not ported).
Atom ascii_lower(State &state, Atom text_atom, const char *where) {
	std::string lowered = state.text(text_atom);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			not_ported(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// {"index": -1, "town": {}}.
DictRef no_town(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

// {"index": index, "town": town}.
DictRef town_at(State &state, int64_t index, const Value &town) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::town), town);
	return result;
}

// {"town": town, "message": message}.
DictRef town_message(State &state, DictRef town, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::town), dict_value(town));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"session": session, "town": town}.
DictRef session_town(State &state, DictRef session, DictRef town) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::session), dict_value(session));
	state.set(result, str(key::town), dict_value(town));
	return result;
}

// --- JSON.stringify(value): JSON._stringify with no indent and sorted keys,
// as overworld_rules_ai_economy.cpp (Phase 3) ports it: null, bools, ints,
// floats, Strings, StringNames, Vector2i, Vector3i, Arrays and Dictionaries whose
// keys are all Strings or all ints. Packed arrays, other key sets, control
// characters and circular structures are left to GDScript.

[[noreturn]] void json_not_ported(const std::string &what) {
	not_ported("OverworldRules._command_risk_forecast_from_normalized_session: JSON.stringify of " + what);
}

// String::json_escape(): the backslash, \b \f \n \r \t \v and the quote.
void append_json_escaped(const std::string &source, std::string &out) {
	for (const char c : source) {
		switch (c) {
			case '\\':
				out += "\\\\";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			case '\v':
				out += "\\v";
				break;
			case '"':
				out += "\\\"";
				break;
			default:
				if (static_cast<unsigned char>(c) < 0x20) {
					json_not_ported("a control character");
				}
				out += c;
				break;
		}
	}
}

void append_json_string(const std::string &source, std::string &out) {
	out += '"';
	append_json_escaped(source, out);
	out += '"';
}

bool json_open(const std::vector<Value> &open, const Value &value) {
	for (const Value &container : open) {
		if (container.kind == value.kind && container.ref == value.ref) {
			return true;
		}
	}
	return false;
}

void append_json(const State &state, const Value &value, int depth, std::vector<Value> &open, std::string &out) {
	if (depth > 1024) {
		json_not_ported("a structure nested too deep");
	}
	switch (value.kind) {
		case Kind::Nil:
			out += "null";
			return;
		case Kind::Bool:
			out += value.b ? "true" : "false";
			return;
		case Kind::Int:
			out += compat::itos(value.i);
			return;
		case Kind::Float:
			out += compat::json_float(value.f);
			return;
		case Kind::String:
		case Kind::StringName:
			append_json_string(state.text(value.ref), out);
			return;
		case Kind::Vector2i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ")", out);
			return;
		case Kind::Vector3i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ", " + compat::itos(value.vz()) + ")", out);
			return;
		case Kind::Array: {
			if (json_open(open, value)) {
				json_not_ported("a circular Array");
			}
			open.push_back(value);
			out += '[';
			const int64_t size = state.array_size(value.ref);
			for (int64_t index = 0; index < size; ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json(state, state.at(value.ref, index), depth + 1, open, out);
			}
			out += ']';
			open.pop_back();
			return;
		}
		case Kind::Dict: {
			if (json_open(open, value)) {
				json_not_ported("a circular Dictionary");
			}
			const state::DictNode &node = state.dict(value.ref);
			const state::ValueList keys = node.keys.list();
			const state::ValueList values = node.values;
			bool string_keys = true;
			bool int_keys = true;
			for (const Value &entry_key : keys) {
				string_keys = string_keys && entry_key.kind == Kind::String;
				int_keys = int_keys && entry_key.kind == Kind::Int;
			}
			if (!string_keys && !int_keys) {
				json_not_ported("a Dictionary with keys other than all Strings or all ints");
			}
			// Keys are distinct, so any sort gives Godot's order.
			std::vector<size_t> order(keys.size());
			for (size_t index = 0; index < order.size(); ++index) {
				order[index] = index;
			}
			if (string_keys) {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return state.text(keys.begin()[a].ref) < state.text(keys.begin()[b].ref); });
			} else {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return keys.begin()[a].i < keys.begin()[b].i; });
			}
			open.push_back(value);
			out += '{';
			for (size_t position = 0; position < order.size(); ++position) {
				if (position > 0) {
					out += ',';
				}
				const Value &entry_key = keys.begin()[order[position]];
				append_json_string(string_keys ? state.text(entry_key.ref) : compat::itos(entry_key.i), out);
				out += ':';
				append_json(state, values.begin()[order[position]], depth + 1, open, out);
			}
			out += '}';
			open.pop_back();
			return;
		}
		default:
			json_not_ported(gd::type_name(value));
	}
}

Atom json_stringify(State &state, const Value &value) {
	std::string json;
	std::vector<Value> open;
	append_json(state, value, 0, open, json);
	return state.intern(json);
}

// The daybreak projection of the town at an index: its session and town, or
// the live ones.
struct Projection {
	DictRef session;
	DictRef town;
};
Projection projection_at(State &state, DictRef session, ArrayRef daybreak_contexts, int64_t town_index, DictRef town) {
	DictRef projection;
	if (town_index < state.array_size(daybreak_contexts) && gd::is_dict(state.at(daybreak_contexts, town_index))) {
		projection = state.at(daybreak_contexts, town_index).ref;
	} else {
		projection = state.new_dict();
	}
	const DictRef projected_session = gd::as_dict(state.get(projection, str(key::session), dict_value(session)));
	const DictRef projected_town = gd::as_dict(state.get(projection, str(key::town), dict_value(town)));
	return {projected_session, projected_town};
}

// A risk item's first fields: {"key", "severity", "gate", "summary"}, with
// "town_placement_id" after the key when it has one.
DictRef new_item(State &state, Atom item_key, int64_t severity, bool gate, Atom summary) {
	const DictRef item = state.new_dict();
	state.set(item, str(key::key), str(item_key));
	state.set(item, str(key::severity), int_value(severity));
	state.set(item, str(key::gate), bool_value(gate));
	state.set(item, str(key::summary), str(summary));
	return item;
}

// items.append_array(other).
void append_all(State &state, ArrayRef items, ArrayRef other) {
	const int64_t count = state.array_size(other);
	for (int64_t index = 0; index < count; ++index) {
		state.append(items, state.at(other, index));
	}
}

// OverworldRules.COMMAND_RISK_FORECAST_KEY.
constexpr Atom kCommandRiskForecastKey = key::command_risk_forecast;

} // namespace

// ---------------------------------------------------------------------------
// OverworldRules.
// ---------------------------------------------------------------------------

namespace overworld_rules {

void _normalize_enemy_states(State &state, DictRef session) {
	enemy_turn_rules::normalize_enemy_states(state, session);
}

bool _raid_is_public(State &state, DictRef session, DictRef encounter) {
	return enemy_adventure_rules::_raid_is_public(state, session, encounter);
}

void _normalize_command_risk_forecast(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	if (session_text(state, session, key::scenario_id) == key::empty) {
		return;
	}
	const DictRef overworld = session_view::overworld(state, session);
	Value forecast_state = field_or_new_dict(state, overworld, kCommandRiskForecastKey);
	if (!gd::is_dict(forecast_state)) {
		forecast_state = dict_value(state.new_dict());
	}
	const DictRef forecast = _command_risk_forecast(state, session);
	const Atom signature = text(state, forecast, key::signature);
	const DictRef next = state.new_dict();
	if (signature == key::empty) {
		state.set(next, str(key::signature), str(key::empty));
		state.set(next, str(key::shown), bool_value(true));
		state.set(next, str(key::shown_day), int_value(session_day(state, session)));
	} else if (text(state, forecast_state.ref, key::signature) != signature) {
		state.set(next, str(key::signature), str(signature));
		state.set(next, str(key::shown), bool_value(false));
		state.set(next, str(key::shown_day), int_value(0));
	} else {
		state.set(next, str(key::signature), str(signature));
		state.set(next, str(key::shown), bool_value(gd::bool_field(state, forecast_state.ref, key::shown, false)));
		state.set(next, str(key::shown_day), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, forecast_state.ref, key::shown_day, 0))));
	}
	state.set(session_view::overworld(state, session), str(kCommandRiskForecastKey), dict_value(next));
}

DictRef _command_risk_forecast(State &state, DictRef session) {
	_normalize_enemy_states(state, session);
	return _command_risk_forecast_from_normalized_session(state, session);
}

DictRef _command_risk_forecast_from_normalized_session(State &state, DictRef session) {
	const DictRef reduction = _reduce_command_risk_items(state, _command_risk_items(state, session, true));
	if (!gd::bool_field(state, reduction, key::has_risk, false)) {
		const DictRef none = state.new_dict();
		state.set(none, str(key::has_risk), bool_value(false));
		state.set(none, str(key::severity), int_value(0));
		state.set(none, str(key::summary), str(key::empty));
		state.set(none, str(key::lines), array_value(state.new_array()));
		state.set(none, str(key::signature), str(key::empty));
		state.set(none, str(key::gate_end_turn), bool_value(false));
		return none;
	}
	const ArrayRef selected_items = gd::as_array(field_or_new_array(state, reduction, key::selected_items));
	const Atom summary_text = text(state, reduction, key::summary);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::next_day_posture_s, {str(summary_text)})));
	const DictRef signature_payload = state.new_dict();
	state.set(signature_payload, str(key::day), int_value(session_day(state, session)));
	state.set(signature_payload, str(key::summary), str(summary_text));
	const ArrayRef details = state.new_array();
	state.set(signature_payload, str(key::details), array_value(details));
	for (const Value &item : gd::items(state, array_value(selected_items))) {
		const Atom detail = text(state, gd::as_dict(item), key::detail);
		if (detail == key::empty) {
			continue;
		}
		state.append(lines, str(gd::format(state, key::dash_space_s, {str(detail)})));
		state.append(details, str(detail));
	}
	const DictRef forecast = state.new_dict();
	state.set(forecast, str(key::has_risk), bool_value(true));
	state.set(forecast, str(key::severity), int_value(gd::int_field(state, reduction, key::severity, 0)));
	state.set(forecast, str(key::summary), str(summary_text));
	state.set(forecast, str(key::lines), array_value(lines));
	state.set(forecast, str(key::signature), str(json_stringify(state, dict_value(signature_payload))));
	state.set(forecast, str(key::gate_end_turn), bool_value(gd::bool_field(state, reduction, key::gate_end_turn, false)));
	return forecast;
}

DictRef _reduce_command_risk_items(State &state, ArrayRef items) {
	if (state.array_size(items) == 0) {
		const DictRef none = state.new_dict();
		state.set(none, str(key::has_risk), bool_value(false));
		state.set(none, str(key::severity), int_value(0));
		state.set(none, str(key::summary), str(key::empty));
		state.set(none, str(key::selected_items), array_value(state.new_array()));
		state.set(none, str(key::gate_end_turn), bool_value(false));
		return none;
	}
	gd::sort_custom(state, items, [&state](const Value &a, const Value &b) {
		const int64_t severity_a = gd::int_field(state, gd::as_dict(a), key::severity, 0);
		const int64_t severity_b = gd::int_field(state, gd::as_dict(b), key::severity, 0);
		if (severity_a == severity_b) {
			return state.text(text(state, gd::as_dict(a), key::key)) < state.text(text(state, gd::as_dict(b), key::key));
		}
		return severity_a > severity_b;
	});
	const ArrayRef selected_items = state.new_array();
	for (const Value &item : gd::items(state, array_value(items))) {
		if (!gd::is_dict(item)) {
			continue;
		}
		state.append(selected_items, item);
		if (state.array_size(selected_items) >= 3) {
			break;
		}
	}
	const int64_t severity = gd::int_field(state, gd::as_dict(state.at(selected_items, 0)), key::severity, 0);
	std::vector<Atom> summary_parts;
	bool gate_end_turn = false;
	for (const Value &item : gd::items(state, array_value(selected_items))) {
		const Atom summary = text(state, item.ref, key::summary);
		if (summary != key::empty && !has_atom(summary_parts, summary)) {
			summary_parts.push_back(summary);
		}
		gate_end_turn = gate_end_turn || gd::bool_field(state, item.ref, key::gate, false);
	}
	Atom summary_text = gd::format(state, key::s_risk, {str(_command_risk_grade_label(state, severity))});
	if (!summary_parts.empty()) {
		summary_text = gd::format(state, key::s_s_text, {str(summary_text), str(join_atoms(state, key::space_bar_space, summary_parts))});
	}
	const DictRef reduction = state.new_dict();
	state.set(reduction, str(key::has_risk), bool_value(true));
	state.set(reduction, str(key::severity), int_value(severity));
	state.set(reduction, str(key::summary), str(summary_text));
	state.set(reduction, str(key::selected_items), array_value(selected_items));
	state.set(reduction, str(key::gate_end_turn), bool_value(gate_end_turn || severity >= 3));
	return reduction;
}

ArrayRef _command_risk_items(State &state, DictRef session, bool include_details) {
	const ArrayRef items = state.new_array();
	const DictRef pressured_town_ids = state.new_dict();
	const ArrayRef daybreak_contexts = _command_risk_player_town_daybreak_contexts(state, session);
	const ArrayRef town_items = _command_risk_town_items(state, session, daybreak_contexts, include_details);
	for (const Value &item : gd::items(state, array_value(town_items))) {
		state.append(items, item);
		const Atom town_id = text(state, gd::as_dict(item), key::town_placement_id);
		if (town_id != key::empty) {
			state.set(pressured_town_ids, str(town_id), bool_value(true));
		}
	}
	append_all(state, items, _command_risk_logistics_items(state, session, pressured_town_ids, daybreak_contexts, include_details));
	append_all(state, items, _command_risk_objective_items(state, session, pressured_town_ids, include_details));
	append_all(state, items, _command_risk_posture_items(state, session, include_details));
	const DictRef field_item = _command_risk_field_item(state, session, include_details);
	if (!gd::is_empty(state, field_item)) {
		state.append(items, dict_value(field_item));
	}
	return items;
}

ArrayRef _command_risk_player_town_daybreak_contexts(State &state, DictRef session) {
	const ArrayRef contexts = state.new_array();
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	if (!gd::is_array(towns)) {
		return contexts;
	}
	// contexts.resize(towns.size()), then every index set in order.
	const int64_t town_count = state.array_size(towns.ref);
	for (int64_t town_index = 0; town_index < town_count; ++town_index) {
		const Value town = state.at(towns.ref, town_index);
		if (!gd::is_dict(town) || text(state, town.ref, key::owner, key::neutral) != key::player) {
			state.append(contexts, dict_value(state.new_dict()));
			continue;
		}
		state.append(contexts, dict_value(_project_player_town_at_daybreak(state, session, town.ref, town_index, gd::add(session_day(state, session), 1))));
	}
	return contexts;
}

ArrayRef _command_risk_town_items(State &state, DictRef session, ArrayRef daybreak_contexts, bool include_details) {
	const ArrayRef items = state.new_array();
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	if (!gd::is_array(towns)) {
		return items;
	}
	const int64_t town_count = state.array_size(towns.ref);
	for (int64_t town_index = 0; town_index < town_count; ++town_index) {
		const Value town_value = state.at(towns.ref, town_index);
		if (!gd::is_dict(town_value) || text(state, town_value.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const DictRef town = town_value.ref;
		const DictRef threat_state = _town_command_risk_state(state, session, town, false);
		if (gd::int_field(state, threat_state, key::visible_pressuring, 0) <= 0
				&& gd::int_field(state, threat_state, key::visible_marching, 0) <= 0
				&& !gd::bool_field(state, threat_state, key::hidden_targeting, false)
				&& gd::int_field(state, threat_state, key::siege_progress, 0) <= 0) {
			continue;
		}
		const Projection projection = projection_at(state, session, daybreak_contexts, town_index, town);
		const DictRef development = town_development_metrics(state, projection.town, dict_value(projection.session));
		const int64_t readiness = gd::int_field(state, development, key::battle_readiness, 0);
		const Atom defense = overworld_rules::_town_defense_summary(state, projection.town);
		const DictRef logistics = dict_field(state, development, key::logistics);
		const DictRef recovery = dict_field(state, development, key::recovery);
		const DictRef capital_project = dict_field(state, development, key::capital_project);
		const bool objective_anchor = _raid_target_is_objective_anchor(state, session, key::town, text(state, town, key::placement_id));
		int64_t severity = 2;
		if (gd::int_field(state, threat_state, key::visible_pressuring, 0) > 0 || gd::int_field(state, threat_state, key::siege_progress, 0) > 0) {
			severity = 5;
		} else if (gd::int_field(state, threat_state, key::nearest_goal_distance, 9999) <= 1) {
			severity = 4;
		} else if (gd::int_field(state, threat_state, key::nearest_goal_distance, 9999) <= 2 || gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
			severity = 3;
		}
		if (readiness <= 18 || defense == key::thin_watch) {
			severity = gd::add(severity, 1);
		}
		if (gd::int_field(state, logistics, key::support_gap, 0) > 0 || gd::bool_field(state, recovery, key::active, false) || gd::bool_field(state, capital_project, key::vulnerable, false)) {
			severity = gd::add(severity, 1);
		}
		if (objective_anchor || capital_or_stronghold(town_strategic_role(state, projection.town))) {
			severity = gd::add(severity, 1);
		}
		severity = compat::engine_clamp<int64_t>(severity, 2, 5);
		const DictRef item = state.new_dict();
		state.set(item, str(key::key), str(gd::format(state, key::town_s, {str(text(state, town, key::placement_id))})));
		state.set(item, str(key::town_placement_id), str(text(state, town, key::placement_id)));
		state.set(item, str(key::severity), int_value(severity));
		state.set(item, str(key::gate), bool_value(severity >= 3));
		state.set(item, str(key::summary), str(gd::format(state, key::s_exposed, {str(_town_name(state, town))})));
		if (include_details) {
			std::vector<Atom> threat_clauses;
			const int64_t visible_pressuring = gd::int_field(state, threat_state, key::visible_pressuring, 0);
			if (visible_pressuring > 0) {
				threat_clauses.push_back(gd::format(state, key::d_known_enemy_force_s_already, {int_value(visible_pressuring), plural_s(visible_pressuring)}));
			}
			const int64_t visible_marching = gd::int_field(state, threat_state, key::visible_marching, 0);
			if (visible_marching > 0) {
				const int64_t days_to_contact = compat::engine_max<int64_t>(1, gd::int_field(state, threat_state, key::nearest_goal_distance, 9999));
				if (days_to_contact <= 2) {
					threat_clauses.push_back(gd::format(state, key::d_known_host_s_can_reach, {int_value(visible_marching), plural_s(visible_marching), int_value(days_to_contact), plural_s(days_to_contact)}));
				} else {
					threat_clauses.push_back(gd::format(state, key::d_known_host_s_are_marching, {int_value(visible_marching), plural_s(visible_marching)}));
				}
			}
			if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
				threat_clauses.push_back(key::scouts_report_hostile_movement_beyond_the);
			}
			const int64_t siege_progress = gd::int_field(state, threat_state, key::siege_progress, 0);
			if (siege_progress > 0) {
				threat_clauses.push_back(gd::format(state, key::siege_pressure_d_d_is_already, {int_value(siege_progress), int_value(compat::engine_max<int64_t>(1, gd::int_field(state, threat_state, key::siege_capture_progress, 1)))}));
			}
			std::vector<Atom> front_parts;
			front_parts.push_back(gd::format(state, key::readiness_d_text, {int_value(readiness)}));
			if (defense != key::empty) {
				front_parts.push_back(defense);
			}
			if (text(state, logistics, key::summary) != key::empty
					&& (gd::int_field(state, logistics, key::support_gap, 0) > 0
							|| gd::int_field(state, logistics, key::threatened_count, 0) > 0
							|| gd::int_field(state, logistics, key::disrupted_count, 0) > 0)) {
				front_parts.push_back(text(state, logistics, key::summary));
			}
			if (gd::bool_field(state, recovery, key::active, false)) {
				front_parts.push_back(text(state, recovery, key::summary));
			}
			if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
				front_parts.push_back(key::capital_project_vulnerable);
			}
			if (objective_anchor) {
				front_parts.push_back(key::objective_anchor);
			}
			const Atom town_name = _town_name(state, town);
			const Atom threats = join_atoms(state, key::semicolon_space, threat_clauses);
			const Atom fronts = join_atoms(state, key::space_bar_space, front_parts);
			const Atom consequence = overworld_rules::_town_command_risk_consequence(state, projection.town, readiness, logistics, recovery, capital_project, objective_anchor);
			state.set(item, str(key::detail), str(gd::format(state, key::s_s_s_s, {str(town_name), str(threats), str(fronts), str(consequence)})));
		}
		state.append(items, dict_value(item));
	}
	return items;
}

ArrayRef _command_risk_logistics_items(State &state, DictRef session, DictRef pressured_town_ids, ArrayRef daybreak_contexts, bool include_details) {
	const ArrayRef items = state.new_array();
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	if (!gd::is_array(towns)) {
		return items;
	}
	const int64_t town_count = state.array_size(towns.ref);
	for (int64_t town_index = 0; town_index < town_count; ++town_index) {
		const Value town_value = state.at(towns.ref, town_index);
		if (!gd::is_dict(town_value) || text(state, town_value.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const DictRef town = town_value.ref;
		const Atom placement_id = text(state, town, key::placement_id);
		if (state.has(pressured_town_ids, str(placement_id))) {
			continue;
		}
		const Projection projection = projection_at(state, session, daybreak_contexts, town_index, town);
		const DictRef logistics = _town_logistics_state(state, projection.session, projection.town);
		if (gd::int_field(state, logistics, key::disrupted_count, 0) <= 0
				&& gd::int_field(state, logistics, key::threatened_count, 0) <= 0
				&& gd::int_field(state, logistics, key::support_gap, 0) <= 0) {
			continue;
		}
		const DictRef recovery = _town_recovery_state(state, projection.session, projection.town, logistics);
		const DictRef capital_project = _town_capital_project_state(state, projection.town, dict_value(projection.session), logistics, recovery);
		int64_t severity_score = gd::add(gd::add(
												 gd::mul(gd::int_field(state, logistics, key::disrupted_count, 0), 2),
												 gd::int_field(state, logistics, key::threatened_count, 0)),
				gd::int_field(state, logistics, key::support_gap, 0));
		if (gd::int_field(state, logistics, key::response_count, 0) <= 0 && gd::int_field(state, logistics, key::threatened_count, 0) > 0) {
			severity_score = gd::add(severity_score, 1);
		}
		if (capital_or_stronghold(town_strategic_role(state, projection.town))) {
			severity_score = gd::add(severity_score, 1);
		}
		if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
			severity_score = gd::add(severity_score, 1);
		}
		int64_t severity = 2;
		if (severity_score >= 6) {
			severity = 5;
		} else if (severity_score >= 4) {
			severity = 4;
		} else if (severity_score >= 2) {
			severity = 3;
		}
		const DictRef item = new_item(state, gd::format(state, key::logistics_s, {str(placement_id)}), severity, severity >= 4,
				gd::format(state, key::s_routes_straining, {str(_town_name(state, town))}));
		if (include_details) {
			Atom route_clause = key::empty;
			const Value disrupted = field_or_new_array(state, logistics, key::disrupted_site_labels);
			const Value threatened = field_or_new_array(state, logistics, key::threatened_site_labels);
			const Value missing = field_or_new_array(state, logistics, key::missing_family_labels);
			if (gd::is_array(disrupted) && state.array_size(disrupted.ref) > 0) {
				route_clause = gd::format(state, key::denied_routes_s, {str(join_first(state, key::comma_space, disrupted.ref, 2))});
			} else if (gd::is_array(threatened) && state.array_size(threatened.ref) > 0) {
				route_clause = gd::format(state, key::threatened_routes_s, {str(join_first(state, key::comma_space, threatened.ref, 2))});
			} else if (gd::is_array(missing) && state.array_size(missing.ref) > 0) {
				route_clause = gd::format(state, key::missing_anchors_s, {str(join_first(state, key::comma_space, missing.ref, 2))});
			}
			std::vector<Atom> consequence_parts;
			if (gd::int_field(state, logistics, key::gap_readiness_penalty, 0) > 0) {
				consequence_parts.push_back(gd::format(state, key::readiness_minus_d, {int_value(gd::int_field(state, logistics, key::gap_readiness_penalty, 0))}));
			}
			if (gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0) > 0) {
				consequence_parts.push_back(gd::format(state, key::recruits_d_text, {int_value(gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0))}));
			}
			if (gd::int_field(state, logistics, key::gap_pressure_penalty, 0) > 0) {
				const Atom label = ascii_lower(state, _town_pressure_label(state, projection.town), "OverworldRules._command_risk_logistics_items");
				consequence_parts.push_back(gd::format(state, key::s_d_text, {str(label), int_value(gd::int_field(state, logistics, key::gap_pressure_penalty, 0))}));
			}
			if (gd::bool_field(state, recovery, key::active, false)) {
				consequence_parts.push_back(gd::format(state, key::d_recovery_pressure_remains, {int_value(gd::int_field(state, recovery, key::pressure, 0))}));
			}
			if (gd::bool_field(state, capital_project, key::vulnerable, false) && text(state, capital_project, key::vulnerability_summary) != key::empty) {
				consequence_parts.push_back(text(state, capital_project, key::vulnerability_summary));
			}
			const Atom town_name = _town_name(state, town);
			const Atom summary = text(state, logistics, key::summary);
			const Atom route_part = route_clause != key::empty ? gd::format(state, key::space_bar_space_s, {str(route_clause)}) : key::empty;
			const Atom holds = !consequence_parts.empty() ? join_atoms(state, key::comma_space, consequence_parts) : key::the_same_exposed_chain_unless_new;
			state.set(item, str(key::detail), str(gd::format(state, key::s_logistics_s_s_next_day, {str(town_name), str(summary), str(route_part), str(holds)})));
		}
		state.append(items, dict_value(item));
	}
	return items;
}

ArrayRef _command_risk_objective_items(State &state, DictRef session, DictRef pressured_town_ids, bool include_details) {
	const ArrayRef items = state.new_array();
	const DictRef scenario = session_scenario(state, session);
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return items;
	}
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::defeat))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom type = text(state, objective.ref, key::type);
		if (type == key::enemy_pressure_at_least) {
			const DictRef pressure_item = _command_risk_pressure_objective_item(state, session, scenario, objective.ref, include_details);
			if (!gd::is_empty(state, pressure_item)) {
				state.append(items, dict_value(pressure_item));
			}
		} else if (type == key::encounter_resolved) {
			const DictRef encounter_item = _command_risk_encounter_objective_item(state, session, objective.ref, include_details);
			if (!gd::is_empty(state, encounter_item)) {
				state.append(items, dict_value(encounter_item));
			}
		} else if (type == key::town_not_owned_by_player || type == key::town_owned_by_player) {
			const Atom placement_id = text(state, objective.ref, key::placement_id);
			if (placement_id == key::empty || state.has(pressured_town_ids, str(placement_id))) {
				continue;
			}
			const DictRef town_result = _find_town_by_placement(state, session, placement_id);
			if (gd::int_field(state, town_result, key::index, -1) < 0) {
				continue;
			}
			const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
			if (text(state, town, key::owner, key::neutral) != key::player) {
				const DictRef item = new_item(state, gd::format(state, key::objective_town_s, {str(placement_id)}), 5, true,
						gd::format(state, key::s_objective_slipping, {str(_town_name(state, town))}));
				if (include_details) {
					const Value label = state.get(objective.ref, str(key::label), state.get(objective.ref, str(key::id), str(key::objective)));
					state.set(item, str(key::detail), str(gd::format(state, key::s_is_already_off_the_banner, {str(_town_name(state, town)), str(gd::stringify_or_fallback(state, label))})));
				}
				state.append(items, dict_value(item));
			}
		}
	}
	return items;
}

ArrayRef _command_risk_posture_items(State &state, DictRef session, bool include_details) {
	const ArrayRef items = state.new_array();
	const DictRef scenario = session_scenario(state, session);
	for (const Value &config : gd::field_items(state, scenario, str(key::enemy_factions))) {
		if (!gd::is_dict(config)) {
			continue;
		}
		const Atom faction_id = text(state, config.ref, key::faction_id);
		const DictRef enemy_state = overworld_rules::_enemy_state_for_faction(state, session, faction_id);
		const int64_t current_pressure = gd::int_field(state, enemy_state, key::pressure, 0);
		const int64_t threshold = _enemy_raid_threshold_for_strategy(state, session, config.ref, faction_id);
		const int64_t active_raids = _enemy_active_raids(state, session, faction_id);
		const int64_t max_raids = _enemy_max_active_raids_for_strategy(state, session, config.ref, faction_id);
		const Atom posture = text(state, enemy_state, key::posture, key::probing);
		if (active_raids >= max_raids) {
			continue;
		}
		if (current_pressure < compat::engine_max<int64_t>(1, gd::sub(threshold, 1)) && posture != key::massing && posture != key::raiding) {
			continue;
		}
		// config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)).
		const Value faction_name = state.get(gd::content_row(state, ContentTable::Faction, faction_id), str(key::name), str(faction_id));
		const Atom label = gd::stringify_or_fallback(state, state.get(config.ref, str(key::label), faction_name));
		int64_t severity = 2;
		if (posture == key::raiding || current_pressure >= threshold) {
			severity = 4;
		} else if (posture == key::massing || gd::add(current_pressure, overworld_rules::_public_enemy_pressure_gain(state, session, config.ref)) >= threshold) {
			severity = 3;
		}
		const DictRef item = new_item(state, gd::format(state, key::posture_s, {str(faction_id)}), severity, false,
				gd::format(state, key::s_is_gathering_strength, {str(label)}));
		if (include_details) {
			state.set(item, str(key::detail), str(gd::format(state, key::s_sits_at_d_d_pressure, {str(label), int_value(current_pressure), int_value(threshold), int_value(active_raids), int_value(max_raids), str(overworld_rules::_posture_label(state, posture))})));
		}
		state.append(items, dict_value(item));
	}
	return items;
}

DictRef _command_risk_field_item(State &state, DictRef session, bool include_details) {
	const Vector2i pos = hero_position(state, session);
	int64_t local_public_contacts = 0;
	int64_t nearest_distance = 9999;
	for (const Value &encounter : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(encounter) || is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		if (!_raid_is_public(state, session, encounter.ref)) {
			continue;
		}
		const int64_t distance = gd::add(
				compat::absi(gd::sub(gd::int_field(state, encounter.ref, key::x, 0), pos.x)),
				compat::absi(gd::sub(gd::int_field(state, encounter.ref, key::y, 0), pos.y)));
		if (distance <= 2) {
			local_public_contacts = gd::add(local_public_contacts, 1);
		}
		nearest_distance = compat::engine_min<int64_t>(nearest_distance, distance);
	}
	if (local_public_contacts <= 0) {
		return state.new_dict();
	}
	const DictRef nearest_town_result = _nearest_town_for_controller(state, session, key::player, pos.x, pos.y, -1);
	const DictRef nearest_town = gd::as_dict(field_or_new_dict(state, nearest_town_result, key::town));
	const int64_t nearest_town_distance = gd::is_empty(state, nearest_town)
			? 9999
			: gd::add(
					  compat::absi(gd::sub(pos.x, gd::int_field(state, nearest_town, key::x, 0))),
					  compat::absi(gd::sub(pos.y, gd::int_field(state, nearest_town, key::y, 0))));
	if (gd::int_field(state, overworld_rules::_find_active_town(state, session), key::index, -1) >= 0) {
		return state.new_dict();
	}
	if (nearest_town_distance <= 2 && local_public_contacts <= 1) {
		return state.new_dict();
	}
	const int64_t severity = local_public_contacts > 1 || nearest_distance <= 1 ? 3 : 2;
	const DictRef item = new_item(state, gd::format(state, key::field_d_d, {int_value(pos.x), int_value(pos.y)}), severity, severity >= 3, key::active_command_exposed);
	if (include_details) {
		const Atom terrain = overworld_rules::_terrain_name_at(state, session, pos.x, pos.y);
		Atom town_clause = key::no_owned_town_anchors_the_current;
		if (!gd::is_empty(state, nearest_town)) {
			town_clause = gd::format(state, key::s_d_tile_s_away, {str(_town_name(state, nearest_town)), int_value(nearest_town_distance), plural_s(nearest_town_distance)});
		}
		state.set(item, str(key::detail), str(gd::format(state, key::the_active_command_ends_on_s, {str(terrain), int_value(pos.x), int_value(pos.y), int_value(local_public_contacts), plural_s(local_public_contacts), str(town_clause)})));
	}
	return item;
}

Atom _command_risk_grade_label(State &state, int64_t severity) {
	(void)state;
	switch (compat::engine_clamp<int64_t>(severity, 0, 5)) {
		case 5:
			return key::Severe;
		case 4:
			return key::High;
		case 3:
			return key::Elevated;
		case 2:
			return key::Guarded;
		case 1:
			return key::Low;
		default:
			return key::Steady;
	}
}

DictRef _town_command_risk_state(State &state, DictRef session, DictRef town, bool include_front) {
	const DictRef risk = state.new_dict();
	state.set(risk, str(key::visible_marching), int_value(0));
	state.set(risk, str(key::visible_pressuring), int_value(0));
	state.set(risk, str(key::hidden_targeting), bool_value(false));
	state.set(risk, str(key::nearest_goal_distance), int_value(9999));
	state.set(risk, str(key::marching_commanders), array_value(state.new_array()));
	state.set(risk, str(key::pressuring_commanders), array_value(state.new_array()));
	state.set(risk, str(key::siege_progress), int_value(0));
	state.set(risk, str(key::siege_capture_progress), int_value(1));
	state.set(risk, str(key::front_active), bool_value(false));
	state.set(risk, str(key::front_mode), str(key::empty));
	state.set(risk, str(key::front_faction_id), str(key::empty));
	state.set(risk, str(key::front_enemy_label), str(key::empty));
	state.set(risk, str(key::front_summary), str(key::empty));
	state.set(risk, str(key::front_public_clause), str(key::empty));
	const DictRef scenario = session_scenario(state, session);
	const Atom placement_id = text(state, town, key::placement_id);
	if (placement_id == key::empty) {
		return risk;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved_encounters = field_or_new_array(state, overworld, key::resolved_encounters);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (text(state, encounter.ref, key::spawned_by_faction_id) == key::empty) {
			continue;
		}
		if (text(state, encounter.ref, key::target_kind) != key::town || text(state, encounter.ref, key::target_placement_id) != placement_id) {
			continue;
		}
		if (gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, str(text(state, encounter.ref, key::placement_id)))) {
			continue;
		}
		const bool is_public = _raid_is_public(state, session, encounter.ref);
		const int64_t goal_distance = gd::int_field(state, encounter.ref, key::goal_distance, 9999);
		const bool is_pressuring = gd::bool_field(state, encounter.ref, key::arrived, false) || goal_distance <= 0;
		const Atom commander_name = encounter_commander_threat_label(state, encounter.ref);
		if (is_public) {
			if (is_pressuring) {
				state.set(risk, str(key::visible_pressuring), int_value(gd::add(gd::int_field(state, risk, key::visible_pressuring, 0), 1)));
				const Value listed = field_or_new_array(state, risk, key::pressuring_commanders);
				if (commander_name != key::empty && !gd::in(state, str(commander_name), listed)) {
					const ArrayRef pressuring_commanders = gd::as_array(field_or_new_array(state, risk, key::pressuring_commanders));
					state.append(pressuring_commanders, str(commander_name));
					state.set(risk, str(key::pressuring_commanders), array_value(pressuring_commanders));
				}
			} else {
				state.set(risk, str(key::visible_marching), int_value(gd::add(gd::int_field(state, risk, key::visible_marching, 0), 1)));
				state.set(risk, str(key::nearest_goal_distance), int_value(compat::engine_min<int64_t>(gd::int_field(state, risk, key::nearest_goal_distance, 9999), goal_distance)));
				const Value listed = field_or_new_array(state, risk, key::marching_commanders);
				if (commander_name != key::empty && !gd::in(state, str(commander_name), listed)) {
					const ArrayRef marching_commanders = gd::as_array(field_or_new_array(state, risk, key::marching_commanders));
					state.append(marching_commanders, str(commander_name));
					state.set(risk, str(key::marching_commanders), array_value(marching_commanders));
				}
			}
		} else {
			state.set(risk, str(key::hidden_targeting), bool_value(true));
		}
	}
	for (const Value &config : gd::field_items(state, scenario, str(key::enemy_factions))) {
		if (!gd::is_dict(config)) {
			continue;
		}
		if (text(state, config.ref, key::siege_target_placement_id) != placement_id) {
			continue;
		}
		const DictRef faction_state = overworld_rules::_enemy_state_for_faction(state, session, text(state, config.ref, key::faction_id));
		state.set(risk, str(key::siege_progress), int_value(compat::engine_max<int64_t>(gd::int_field(state, risk, key::siege_progress, 0), gd::int_field(state, faction_state, key::siege_progress, 0))));
		state.set(risk, str(key::siege_capture_progress), int_value(compat::engine_max<int64_t>(1, gd::int_field(state, config.ref, key::siege_capture_progress, 1))));
	}
	if (gd::int_field(state, risk, key::nearest_goal_distance, 9999) == 9999 && gd::int_field(state, risk, key::visible_pressuring, 0) > 0) {
		state.set(risk, str(key::nearest_goal_distance), int_value(0));
	}
	if (include_front) {
		const DictRef front_state = _town_front_state(state, session, town, state.new_dict());
		state.set(risk, str(key::front_active), bool_value(gd::bool_field(state, front_state, key::active, false)));
		state.set(risk, str(key::front_mode), str(text(state, front_state, key::mode)));
		state.set(risk, str(key::front_faction_id), str(text(state, front_state, key::faction_id)));
		state.set(risk, str(key::front_enemy_label), str(text(state, front_state, key::enemy_label)));
		state.set(risk, str(key::front_summary), str(text(state, front_state, key::summary)));
		state.set(risk, str(key::front_public_clause), str(text(state, front_state, key::public_clause)));
	}
	return risk;
}

DictRef _project_player_town_at_daybreak(State &state, DictRef session, DictRef town, int64_t town_index, int64_t next_day) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value live_towns = field_or_new_array(state, overworld, key::towns);
	if (!gd::is_array(live_towns) || town_index < 0 || town_index >= state.array_size(live_towns.ref)) {
		return session_town(state, session, town);
	}

	// SessionStateStore.SessionData.new() with its fields set: a new view, its
	// fields in SessionData's order (DayEngine.SESSION_FIELDS), no metadata, and
	// its own instance id.
	const DictRef projected_session = state.new_dict();
	state.set(projected_session, str(key::save_version), gd::index(state, session, str(key::save_version)));
	state.set(projected_session, str(key::session_id), gd::index(state, session, str(key::session_id)));
	state.set(projected_session, str(key::scenario_id), gd::index(state, session, str(key::scenario_id)));
	state.set(projected_session, str(key::hero_id), gd::index(state, session, str(key::hero_id)));
	state.set(projected_session, str(key::day), int_value(next_day));
	state.set(projected_session, str(key::difficulty), gd::index(state, session, str(key::difficulty)));
	state.set(projected_session, str(key::launch_mode), gd::index(state, session, str(key::launch_mode)));
	state.set(projected_session, str(key::game_state), gd::index(state, session, str(key::game_state)));
	state.set(projected_session, str(key::scenario_status), gd::index(state, session, str(key::scenario_status)));
	state.set(projected_session, str(key::scenario_summary), gd::index(state, session, str(key::scenario_summary)));
	const DictRef projected_overworld = gd::duplicate_dict(state, overworld);
	state.set(projected_session, str(key::overworld), dict_value(projected_overworld));
	state.set(projected_session, str(key::battle), dict_value(gd::duplicate_dict(state, gd::as_dict(gd::index(state, session, str(key::battle))))));
	state.set(projected_session, str(key::flags), dict_value(gd::duplicate_dict(state, gd::as_dict(gd::index(state, session, str(key::flags))))));
	state.set(projected_session, str(key::meta), dict_value(state.new_dict()));
	state.set(projected_session, str(key::instance_id), int_value(projected_instance_id()));

	const ArrayRef projected_towns = gd::duplicate_array(state, live_towns.ref);
	DictRef projected_town = gd::deep_duplicate_dict(state, town);
	state.set_at(projected_towns, town_index, dict_value(projected_town));
	state.set(projected_overworld, str(key::towns), array_value(projected_towns));

	const DictRef occupation_result = _advance_town_occupation(state, projected_session, projected_town);
	projected_town = gd::as_dict(state.get(occupation_result, str(key::town), dict_value(projected_town)));
	state.set_at(projected_towns, town_index, dict_value(projected_town));
	state.set(projected_overworld, str(key::towns), array_value(projected_towns));

	const DictRef recovery_result = _advance_town_recovery(state, projected_session, projected_town);
	projected_town = gd::as_dict(state.get(recovery_result, str(key::town), dict_value(projected_town)));
	state.set_at(projected_towns, town_index, dict_value(projected_town));
	state.set(projected_overworld, str(key::towns), array_value(projected_towns));
	return session_town(state, projected_session, projected_town);
}

DictRef _advance_town_occupation(State &state, DictRef session, DictRef town) {
	const DictRef occupation = _normalize_town_occupation_state(state, field_or_new_dict(state, town, key::occupation));
	if (text(state, town, key::owner, key::neutral) != key::player) {
		state.set(town, str(key::occupation), dict_value(_normalize_town_occupation_state(state, dict_value(state.new_dict()))));
		return town_message(state, town, key::empty);
	}
	if (text(state, occupation, key::state) != key::pacifying || gd::int_field(state, occupation, key::pressure, 0) <= 0) {
		state.set(town, str(key::occupation), dict_value(occupation));
		return town_message(state, town, key::empty);
	}
	const DictRef occupation_state = _town_occupation_state(state, session, town);
	const int64_t relief_per_day = compat::engine_max<int64_t>(1, gd::int_field(state, occupation_state, key::relief_per_day, 1));
	const int64_t pressure = compat::engine_max<int64_t>(0, gd::int_field(state, occupation, key::pressure, 0));
	const int64_t relieved = compat::engine_min<int64_t>(pressure, relief_per_day);
	state.set(occupation, str(key::pressure), int_value(compat::engine_max<int64_t>(0, gd::sub(pressure, relieved))));
	// session != null: a session is its view.
	state.set(occupation, str(key::last_event_day), int_value(session_day(state, session)));
	state.set(town, str(key::occupation), dict_value(occupation));
	if (gd::int_field(state, occupation, key::pressure, 0) <= 0) {
		const int64_t locked_headcount = _recruit_payload_total(state, field_or_new_dict(state, occupation, key::locked_recruits));
		const DictRef released = overworld_rules::_release_town_occupation_reserves(state, town);
		Atom release_clause = key::empty;
		if (locked_headcount > 0) {
			release_clause = gd::format(state, key::d_held_levy_s_now_answer, {int_value(locked_headcount), str(locked_headcount == 1 ? key::y : key::ies)});
		}
		return town_message(state, released, gd::format(state, key::s_pacifies_into_secure_control_s, {str(_town_name(state, released)), str(release_clause)}));
	}
	return town_message(state, town, gd::format(state, key::s_pacification_sheds_d_unrest, {str(_town_name(state, town)), int_value(relieved)}));
}

DictRef _advance_town_recovery(State &state, DictRef session, DictRef town) {
	const DictRef recovery = _normalize_town_recovery_state(state, field_or_new_dict(state, town, key::recovery));
	const int64_t pressure = gd::int_field(state, recovery, key::pressure, 0);
	if (pressure <= 0) {
		state.set(town, str(key::recovery), dict_value(recovery));
		return town_message(state, town, key::empty);
	}
	const DictRef recovery_state = _town_recovery_state(state, session, town, state.new_dict());
	const int64_t relief_per_day = compat::engine_max<int64_t>(1, gd::int_field(state, recovery_state, key::relief_per_day, 1));
	const int64_t relieved = compat::engine_min<int64_t>(pressure, relief_per_day);
	state.set(recovery, str(key::pressure), int_value(compat::engine_max<int64_t>(0, gd::sub(pressure, relieved))));
	if (gd::int_field(state, recovery, key::pressure, 0) <= 0) {
		state.set(recovery, str(key::source), str(key::empty));
	}
	state.set(town, str(key::recovery), dict_value(recovery));
	if (text(state, town, key::owner, key::neutral) != key::player) {
		return town_message(state, town, key::empty);
	}
	if (gd::int_field(state, recovery, key::pressure, 0) <= 0) {
		return town_message(state, town, gd::format(state, key::s_stabilize, {str(_town_name(state, town))}));
	}
	return town_message(state, town, gd::format(state, key::s_shed_d_recovery_pressure, {str(_town_name(state, town)), int_value(relieved)}));
}

DictRef _town_capital_project_state(State &state, DictRef town, const Value &session, DictRef logistics_state, DictRef recovery_state) {
	const ArrayRef project_ids = _town_capital_project_ids(state, town);
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	const ArrayRef active_ids = state.new_array();
	int64_t pressure_bonus = 0;
	int64_t defense_bonus = 0;
	int64_t threshold_reduction = 0;
	int64_t max_active_raids_bonus = 0;
	int64_t recovery_guard = 0;
	Atom summary = key::empty;
	DictRef support_requirements = state.new_dict();
	const DictRef vulnerability_penalties = _blank_project_vulnerability_penalties(state);
	const Atom vulnerability_summary = text(state, _town_logistics_plan(state, town), key::vulnerability_summary);
	for (const Value &project_id : gd::items(state, array_value(project_ids))) {
		const DictRef project_building = gd::content_row(state, ContentTable::Building, gd::to_string(project_id));
		const Value capital_project = field_or_new_dict(state, project_building, key::capital_project);
		if (gd::is_dict(capital_project) && gd::is_empty(state, support_requirements)) {
			support_requirements = _normalize_support_requirements(state, field_or_new_dict(state, capital_project.ref, key::support_requirements));
			const Value authored_penalties = field_or_new_dict(state, capital_project.ref, key::vulnerability_penalties);
			if (gd::is_dict(authored_penalties)) {
				const ArrayRef penalty_keys = gd::keys(state, vulnerability_penalties);
				for (const Value &penalty_key : gd::items(state, array_value(penalty_keys))) {
					const Value fallback = gd::index(state, vulnerability_penalties, penalty_key);
					const int64_t authored = gd::to_int(state, state.get(authored_penalties.ref, penalty_key, fallback));
					state.set(vulnerability_penalties, penalty_key, int_value(compat::engine_max<int64_t>(0, authored)));
				}
			}
		}
		if (!gd::array_has(state, built_buildings, project_id)) {
			continue;
		}
		state.append(active_ids, project_id);
		if (gd::is_dict(capital_project)) {
			pressure_bonus = gd::add(pressure_bonus, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::pressure_bonus, 0)));
			defense_bonus = gd::add(defense_bonus, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::defense_bonus, 0)));
			threshold_reduction = gd::add(threshold_reduction, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::raid_threshold_reduction, 0)));
			max_active_raids_bonus = gd::add(max_active_raids_bonus, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::max_active_raids_bonus, 0)));
			recovery_guard = gd::add(recovery_guard, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::recovery_guard, 0)));
			if (summary == key::empty) {
				summary = text(state, capital_project.ref, key::summary);
			}
		}
	}
	const Atom primary_project_id = state.array_size(project_ids) > 0 ? gd::stringify_or_fallback(state, state.at(project_ids, 0)) : key::empty;
	const ArrayRef dependency_ids = _project_dependency_ids(state, primary_project_id);
	int64_t dependency_complete = 0;
	const ArrayRef missing_dependency_labels = state.new_array();
	for (const Value &dependency_id : gd::items(state, array_value(dependency_ids))) {
		if (gd::array_has(state, built_buildings, dependency_id)) {
			dependency_complete = gd::add(dependency_complete, 1);
			continue;
		}
		const DictRef dependency = gd::content_row(state, ContentTable::Building, gd::to_string(dependency_id));
		state.append(missing_dependency_labels, str(gd::stringify_or_fallback(state, state.get(dependency, str(key::name), dependency_id))));
	}
	const bool primary_built = gd::array_has(state, built_buildings, str(primary_project_id));
	const int64_t progress_total = gd::add(state.array_size(dependency_ids), primary_project_id == key::empty ? 0 : 1);
	const int64_t progress_complete = gd::add(dependency_complete, primary_built ? 1 : 0);
	Atom next_label = key::empty;
	if (primary_project_id != key::empty && !primary_built && state.array_size(missing_dependency_labels) == 0) {
		const DictRef primary = gd::content_row(state, ContentTable::Building, primary_project_id);
		next_label = gd::stringify_or_fallback(state, state.get(primary, str(key::name), str(primary_project_id)));
	} else if (state.array_size(missing_dependency_labels) > 0) {
		next_label = gd::stringify_or_fallback(state, state.at(missing_dependency_labels, 0));
	}
	int64_t support_met = 0;
	int64_t support_total = 0;
	int64_t support_gap = 0;
	Value missing_support_labels = array_value(state.new_array());
	bool vulnerable = false;
	int64_t quality_penalty = 0;
	int64_t readiness_penalty = 0;
	int64_t pressure_penalty = 0;
	int64_t growth_penalty_percent = 0;
	if (session.kind != Kind::Nil) {
		const DictRef session_dict = gd::as_dict(session);
		if (gd::is_empty(state, support_requirements)) {
			support_requirements = _normalize_support_requirements(state, field_or_new_dict(state, _town_logistics_plan(state, town), key::support_requirements));
		}
		const DictRef logistics = !gd::is_empty(state, logistics_state) ? logistics_state : _town_logistics_state(state, session_dict, town);
		const DictRef recovery = !gd::is_empty(state, recovery_state) ? recovery_state : _town_recovery_state(state, session_dict, town, logistics);
		const DictRef requirement_progress = _support_requirement_progress(state, field_or_new_dict(state, logistics, key::family_counts), dict_value(support_requirements));
		support_met = gd::int_field(state, requirement_progress, key::met_requirements, 0);
		support_total = gd::int_field(state, requirement_progress, key::required_total, 0);
		support_gap = gd::int_field(state, requirement_progress, key::support_gap, 0);
		missing_support_labels = field_or_new_array(state, requirement_progress, key::missing_family_labels);
		vulnerable = state.array_size(active_ids) > 0 && (support_gap > 0 || gd::bool_field(state, recovery, key::active, false));
		if (vulnerable) {
			const int64_t vulnerability_steps = compat::engine_max<int64_t>(1, gd::add(support_gap, gd::bool_field(state, recovery, key::active, false) ? 1 : 0));
			quality_penalty = gd::mul(gd::int_field(state, vulnerability_penalties, key::quality_penalty, 0), vulnerability_steps);
			readiness_penalty = gd::mul(gd::int_field(state, vulnerability_penalties, key::readiness_penalty, 0), vulnerability_steps);
			pressure_penalty = gd::mul(gd::int_field(state, vulnerability_penalties, key::pressure_penalty, 0), vulnerability_steps);
			growth_penalty_percent = gd::mul(gd::int_field(state, vulnerability_penalties, key::growth_penalty_percent, 0), vulnerability_steps);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::total), int_value(state.array_size(project_ids)));
	state.set(result, str(key::active), bool_value(state.array_size(active_ids) > 0));
	state.set(result, str(key::active_ids), array_value(active_ids));
	state.set(result, str(key::pressure_bonus), int_value(pressure_bonus));
	state.set(result, str(key::defense_bonus), int_value(defense_bonus));
	state.set(result, str(key::quality_bonus), int_value(gd::mul(state.array_size(active_ids), 12)));
	state.set(result, str(key::recovery_guard), int_value(recovery_guard));
	state.set(result, str(key::raid_threshold_reduction), int_value(threshold_reduction));
	state.set(result, str(key::max_active_raids_bonus), int_value(max_active_raids_bonus));
	state.set(result, str(key::summary), str(summary));
	state.set(result, str(key::primary_project_id), str(primary_project_id));
	state.set(result, str(key::progress_complete), int_value(progress_complete));
	state.set(result, str(key::progress_total), int_value(progress_total));
	state.set(result, str(key::missing_dependency_labels), array_value(missing_dependency_labels));
	state.set(result, str(key::next_label), str(next_label));
	state.set(result, str(key::support_requirements), dict_value(support_requirements));
	state.set(result, str(key::support_met), int_value(support_met));
	state.set(result, str(key::support_total), int_value(support_total));
	state.set(result, str(key::support_gap), int_value(support_gap));
	state.set(result, str(key::missing_support_labels), missing_support_labels);
	state.set(result, str(key::vulnerable), bool_value(vulnerable));
	state.set(result, str(key::quality_penalty), int_value(quality_penalty));
	state.set(result, str(key::readiness_penalty), int_value(readiness_penalty));
	state.set(result, str(key::pressure_penalty), int_value(pressure_penalty));
	state.set(result, str(key::growth_penalty_percent), int_value(growth_penalty_percent));
	state.set(result, str(key::vulnerability_summary), str(vulnerability_summary));
	return result;
}

ArrayRef _town_capital_project_ids(State &state, DictRef town) {
	const ArrayRef ids = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text(state, town, key::town_id));
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		const Atom building_id = gd::stringify_or_fallback(state, building_id_value);
		if (building_id == key::empty) {
			continue;
		}
		const Value capital_project = gd::field(state, gd::content_row(state, ContentTable::Building, building_id), key::capital_project);
		if (gd::is_dict(capital_project) && !gd::is_empty(state, capital_project.ref)) {
			state.append(ids, str(building_id));
		}
	}
	return ids;
}

int64_t _town_capital_project_recovery_relief(State &state, DictRef town) {
	int64_t total = 0;
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify_or_fallback(state, building_id_value));
		// A missing capital_project is {}: its recovery_guard adds 0.
		const Value capital_project = gd::field(state, building, key::capital_project);
		if (gd::is_dict(capital_project)) {
			total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, capital_project.ref, key::recovery_guard, 0)));
		}
	}
	return total;
}

ArrayRef _project_dependency_ids(State &state, Atom project_id) {
	const ArrayRef dependency_ids = state.new_array();
	const DictRef building = gd::content_row(state, ContentTable::Building, project_id);
	if (gd::is_empty(state, building)) {
		return dependency_ids;
	}
	for (const Value &dependency_id_value : gd::field_items(state, building, str(key::requires_))) {
		const Atom dependency_id = gd::stringify_or_fallback(state, dependency_id_value);
		if (dependency_id != key::empty && !gd::array_has(state, dependency_ids, str(dependency_id))) {
			state.append(dependency_ids, str(dependency_id));
		}
	}
	const Atom upgrade_from = text(state, building, key::upgrade_from);
	if (upgrade_from != key::empty && !gd::array_has(state, dependency_ids, str(upgrade_from))) {
		state.append(dependency_ids, str(upgrade_from));
	}
	return dependency_ids;
}

DictRef _blank_project_vulnerability_penalties(State &state) {
	const DictRef penalties = state.new_dict();
	state.set(penalties, str(key::quality_penalty), int_value(0));
	state.set(penalties, str(key::readiness_penalty), int_value(0));
	state.set(penalties, str(key::pressure_penalty), int_value(0));
	state.set(penalties, str(key::growth_penalty_percent), int_value(0));
	return penalties;
}

int64_t _town_recovery_relief_rating(State &state, DictRef session, DictRef town, DictRef logistics_state) {
	return _town_recovery_relief_rating(state, dict_value(session), town, logistics_state);
}

int64_t _town_recovery_relief_rating(State &state, const Value &session, DictRef town, DictRef logistics_state) {
	int64_t relief = gd::int_field(state, _town_logistics_plan(state, town), key::recovery_relief, 0);
	if (gd::is_empty(state, logistics_state) && session.kind == state::Kind::Nil) {
		// _town_logistics_state(null, town): no caller passes a null session without its logistics.
		throw state::NotPorted("OverworldRules._town_recovery_relief_rating: a null session without a logistics state");
	}
	const DictRef logistics = !gd::is_empty(state, logistics_state) ? logistics_state : _town_logistics_state(state, gd::as_dict(session), town);
	relief = gd::add(relief, _town_building_bonus_total(state, town, key::recovery_relief));
	relief = gd::add(relief, gd::int_field(state, logistics, key::recovery_relief_bonus, 0));
	relief = gd::add(relief, gd::int_field(state, logistics, key::response_recovery_relief_bonus, 0));
	relief = gd::add(relief, _town_capital_project_recovery_relief(state, town));
	return compat::engine_max<int64_t>(0, relief);
}

int64_t _town_building_bonus_total(State &state, DictRef town, Atom bonus_key) {
	int64_t total = 0;
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify_or_fallback(state, building_id_value));
		total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, building, bonus_key, 0)));
	}
	return total;
}

DictRef _nearest_town_for_controller(State &state, DictRef session, Atom controller_id, int64_t x, int64_t y, int64_t level) {
	level = overworld_level_rules::query_level(state, session, level);
	int64_t best_index = -1;
	int64_t best_distance = 9999;
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	const int64_t count = ai::vsize(state, towns);
	for (int64_t index = 0; index < count; ++index) {
		const Value town = ai::vindex(state, towns, int_value(index));
		if (!gd::is_dict(town) || !overworld_level_rules::on_level(state, town, level) || !_town_matches_controller(state, town.ref, controller_id)) {
			continue;
		}
		const int64_t distance = gd::add(
				compat::absi(gd::sub(x, gd::int_field(state, town.ref, key::x, 0))),
				compat::absi(gd::sub(y, gd::int_field(state, town.ref, key::y, 0))));
		if (distance < best_distance) {
			best_distance = distance;
			best_index = index;
		}
	}
	if (best_index < 0) {
		return no_town(state);
	}
	return town_at(state, best_index, ai::vindex(state, towns, int_value(best_index)));
}

bool _town_matches_controller(State &state, DictRef town, Atom controller_id) {
	if (controller_id == key::player) {
		return text(state, town, key::owner, key::neutral) == key::player;
	}
	return text(state, town, key::owner, key::neutral) == key::enemy && _town_faction_id(state, town) == controller_id;
}

Vector2i hero_position(State &state, DictRef session) {
	Value pos;
	if (!state.lookup(session_view::overworld(state, session), str(key::hero_position), pos)) {
		// The fallback {"x": 0, "y": 0}.
		return Vector2i::of(0, 0);
	}
	const DictRef position = gd::as_dict(pos);
	return Vector2i::of(gd::int_field(state, position, key::x, 0), gd::int_field(state, position, key::y, 0));
}

Atom town_strategic_role(State &state, DictRef town) {
	return _town_strategic_role(state, town);
}

bool _fog_state_ready(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const Value fog = field_or_new_dict(state, session_view::overworld(state, session), key::fog);
	if (!gd::is_dict(fog)) {
		return false;
	}
	if (gd::int_field(state, fog.ref, key::active_level, 0) != hero_level(state, session)) {
		return false;
	}
	const Value visible_tiles = field_or_new_array(state, fog.ref, key::visible_tiles);
	const Value explored_tiles = field_or_new_array(state, fog.ref, key::explored_tiles);
	const Vector2i map_size = derive_map_size(state, session);
	return gd::is_array(visible_tiles)
			&& gd::is_array(explored_tiles)
			&& state.array_size(visible_tiles.ref) == map_size.y
			&& state.array_size(explored_tiles.ref) == map_size.y;
}

ArrayRef _fog_grids(State &state, DictRef session, int64_t level) {
	if (gd::to_int(state, gd::static_var(state, key::overworld_rules_script, key::_fog_read_scope_depth)) > 0) {
		// The read scope's session.get_instance_id() and Engine.get_process_frames().
		not_ported("OverworldRules._fog_grids with a fog read scope open");
	}
	return _fog_grids_uncached(state, session, level);
}

ArrayRef _fog_grids_uncached(State &state, DictRef session, int64_t level) {
	if (!_fog_state_ready(state, session)) {
		normalize_overworld_state(state, session);
	}
	const DictRef fog = fog_for_level(state, session, level);
	const ArrayRef grids = state.new_array();
	state.append(grids, field_or_new_array(state, fog, key::explored_tiles));
	// fog.get(EXPLORED_TILES_KEY, fog.get(VISIBLE_TILES_KEY, [])).
	Value visible;
	if (!state.lookup(fog, str(key::explored_tiles), visible)) {
		visible = field_or_new_array(state, fog, key::visible_tiles);
	}
	state.append(grids, visible);
	return grids;
}

bool _grid_cell(State &state, const Value &grid, int64_t x, int64_t y) {
	if (!gd::is_array(grid) || y < 0 || y >= state.array_size(grid.ref)) {
		return false;
	}
	const Value row = state.at(grid.ref, y);
	if (!gd::is_array(row) || x < 0 || x >= state.array_size(row.ref)) {
		return false;
	}
	return gd::to_bool(state.at(row.ref, x));
}

bool is_tile_visible(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	// session == null cannot happen: a session is its view.
	return _grid_cell(state, state.at(_fog_grids(state, session, level), 1), x, y);
}

} // namespace overworld_rules

// ---------------------------------------------------------------------------
// EnemyAdventureRules.
// ---------------------------------------------------------------------------

namespace enemy_adventure_rules {

bool _raid_is_public(State &state, DictRef session, DictRef encounter) {
	// session == null cannot happen: a session is its view.
	if (gd::bool_field(state, encounter, key::arrived, false)) {
		if (text(state, encounter, key::target_kind) == key::town) {
			const DictRef town_result = enemy_adventure_rules::_find_town_by_placement(state, session, text(state, encounter, key::target_placement_id));
			if (gd::int_field(state, town_result, key::index, -1) >= 0
					&& text(state, gd::as_dict(field_or_new_dict(state, town_result, key::town)), key::owner, key::neutral) == key::player) {
				return true;
			}
		}
	}
	if (overworld_rules::is_tile_visible(state, session,
				gd::int_field(state, encounter, key::x, 0),
				gd::int_field(state, encounter, key::y, 0),
				overworld_level_rules::level_of(state, dict_value(encounter)))) {
		return true;
	}
	return false;
}

void _sync_unit_strength_memo(State &state) {
	const ArrayRef sources = state.new_array();
	state.append(sources, int_value(gd::content_revision(state)));
	state.append(sources, dict_value(gd::content_file(state, key::units_path)));
	const ArrayRef kept = gd::as_array(gd::static_var(state, key::enemy_adventure_rules_script, key::_unit_strength_sources));
	if (state.array_size(kept) != state.array_size(sources)
			|| !gd::equal(state, state.at(kept, 0), state.at(sources, 0))
			|| !gd::is_same(state, state.at(kept, 1), state.at(sources, 1))) {
		gd::set_static_var(state, key::enemy_adventure_rules_script, key::_unit_strength_memo, dict_value(state.new_dict()));
		gd::set_static_var(state, key::enemy_adventure_rules_script, key::_unit_strength_sources, array_value(sources));
	}
}

} // namespace enemy_adventure_rules

// ---------------------------------------------------------------------------
// ScenarioRules.
// ---------------------------------------------------------------------------

namespace scenario_rules {

Value objectives_for_session(State &state, DictRef session) {
	return objective_definitions(state, scenario_record_for_session(state, session));
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
