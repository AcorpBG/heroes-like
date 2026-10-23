// The day boundary (Phase 5 slice 07, the "boundary" group): the second half of
// OverworldRules.end_turn after the computer players' turn
// (_end_turn_close_day: the elimination check, _finalize_action_result, the
// closing normalize and the turn summaries), _finalize_action_result for every
// caller, and what they run: the public event log of the computer players'
// turn (EnemyAdventureRules.ai_public_event_log and its leak check) and the
// summary texts.
//
// The paths AI matches never run are left to GDScript (state::NotPorted): the
// end of turn while the rules profile records (a debug capture), and a public
// event JSON.stringify would write with a float, a control character or a key
// that is not a String. An action's scenario check narrowed to its event facts
// (ScenarioRules.evaluate_session_for_event) is ported (Phase 7, slice 7.2).

#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <cstdint>
#include <iterator>
#include <string>
#include <utility>
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

// d.get(key, []): the field as it is, or a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// OverworldRules' rules profile (_rules_profile_timer, _rules_profile_add_ms,
// _rules_profile_set) records only while _movement_rules_profile_active is set
// (a debug capture); otherwise its calls do nothing. Checked once per entry:
// the static cannot change during the call.
void refuse_recording_profile(State &state) {
	if (gd::truthy(state, gd::static_var(state, key::overworld_rules_script, key::_movement_rules_profile_active))) {
		not_ported("the rules profile is recording");
	}
}

// s.strip_edges(): the code points up to 32 (single bytes in UTF-8) at both ends.
std::string strip_edges_text(const std::string &source) {
	size_t begin = 0;
	size_t end = source.size();
	while (begin < end && static_cast<unsigned char>(source[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(source[end - 1]) <= 32) {
		--end;
	}
	return source.substr(begin, end - begin);
}

// s.replace(what, with) for a non-empty what: left to right, without overlaps.
// A byte search finds what Godot's code point search finds in valid UTF-8.
std::string replace_text(const std::string &source, const std::string &what, const std::string &with) {
	std::string result;
	size_t from = 0;
	size_t found = source.find(what, from);
	if (found == std::string::npos) {
		return source;
	}
	while (found != std::string::npos) {
		result.append(source, from, found - from);
		result += with;
		from = found + what.size();
		found = source.find(what, from);
	}
	result.append(source, from, std::string::npos);
	return result;
}

// The compaction _short_player_text, _enemy_activity_public_text and
// _public_event_log_text share:
//   var output := text.strip_edges().replace("\n", " ")
//   while output.find("  ") >= 0: output = output.replace("  ", " ")
std::string compact_text(const std::string &source) {
	std::string output = replace_text(strip_edges_text(source), "\n", " ");
	while (output.find("  ") != std::string::npos) {
		output = replace_text(output, "  ", " ");
	}
	return output;
}

// s.length(): Godot's Strings count code points.
int64_t code_point_count(const std::string &text) {
	int64_t count = 0;
	for (const char c : text) {
		if ((static_cast<unsigned char>(c) & 0xC0) != 0x80) {
			++count;
		}
	}
	return count;
}

// s.left(count) for count > 0: the first count code points, all of them when
// there are fewer.
std::string left_code_points(const std::string &text, int64_t count) {
	int64_t seen = 0;
	for (size_t index = 0; index < text.size(); ++index) {
		if ((static_cast<unsigned char>(text[index]) & 0xC0) != 0x80) {
			if (seen == count) {
				return text.substr(0, index);
			}
			++seen;
		}
	}
	return text;
}

// separator.join(parts).
std::string join_texts(const std::vector<std::string> &parts, const char *separator) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += parts[index];
	}
	return joined;
}

// separator.join(array) of an untyped Array: PackedStringArray(array) converts
// each item as String() does.
Atom join_array(State &state, const char *separator, ArrayRef array) {
	std::vector<std::string> parts;
	for (const Value &item : gd::items(state, array_value(array))) {
		parts.push_back(state.text(gd::stringify_or_fallback(state, item)));
	}
	return state.intern(join_texts(parts, separator));
}

// _short_player_text on UTF-8 text.
std::string short_player_text(const std::string &text, int64_t max_chars) {
	const std::string compact = compact_text(text);
	if (code_point_count(compact) <= max_chars) {
		return compact;
	}
	// "%s..." % compact.left(max(1, max_chars - 3)).strip_edges()
	return strip_edges_text(left_code_points(compact, compat::engine_max<int64_t>(1, gd::sub(max_chars, 3)))) + "...";
}

// String(x).strip_edges().
std::string stripped_text(State &state, const Value &value) {
	return strip_edges_text(state.text(gd::stringify_or_fallback(state, value)));
}

bool atom_in(Atom value, const Atom *first, const Atom *last) {
	return std::find(first, last, value) != last;
}

// OverworldRules._enemy_activity_public_text's tokens.
constexpr const char *kActivityHiddenTokens[] = {
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"raid_score",
	"debug_reason",
};

// EnemyAdventureRules.AI_PUBLIC_EVENT_LOG_KEYS, in order.
constexpr Atom kPublicEventLogKeys[] = {
	key::day,
	key::event_type,
	key::faction_id,
	key::player_id,
	key::faction_label,
	key::actor_label,
	key::target_kind,
	key::target_id,
	key::target_label,
	key::visibility,
	key::public_importance,
	key::summary,
	key::reason_codes,
	key::public_reason,
};

// EnemyAdventureRules.AI_PUBLIC_EVENT_LOG_TYPES, in order.
constexpr Atom kPublicEventLogTypes[] = {
	key::ai_target_assigned,
	key::ai_pressure_summary,
	key::ai_commander_task_planned,
	key::ai_site_seized,
	key::ai_site_contested,
	key::ai_site_defended,
	key::ai_town_captured,
	key::ai_town_defended,
	key::ai_town_built,
	key::ai_town_recruited,
	key::ai_garrison_reinforced,
	key::ai_raid_reinforced,
	key::ai_commander_rebuilt,
	key::ai_commander_prepared,
	key::ai_commander_role_observed,
	key::ai_raid_moved,
	key::ai_raid_arrived,
	key::ai_raid_regrouped,
	key::ai_raid_grouped,
	key::ai_adventure_spell_cast,
	key::ai_artifact_secured,
	key::ai_hero_hired,
	key::ai_guard_defeated,
	key::ai_hero_defeated,
};

// EnemyAdventureRules.AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS, in order (the leak
// check names the first one it finds).
constexpr const char *kPublicEventLogBlockedTokens[] = {
	"event_id",
	"sequence",
	"target_x",
	"target_y",
	"from_x",
	"from_y",
	"to_x",
	"to_y",
	"phase_id",
	"state_policy",
	"debug_reason",
	"target_debug_reason",
	"score_ref",
	"score",
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"object_metadata_value",
	"object_route_pressure_value",
	"priority_without_object_metadata",
	"priority_with_object_metadata",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"garrison_score",
	"raid_score",
	"resource_score_breakdown",
	"resource_breakdown",
	"priority_table",
	"breakdown",
	"target_memory",
	"commander_role_state",
	"hero_task_state",
	"fixture_state",
	"internal",
	"saved",
	"durable",
	"migration",
	"SAVE_VERSION",
};

constexpr int64_t kPublicEventLogKeyCount = static_cast<int64_t>(sizeof(kPublicEventLogKeys) / sizeof(kPublicEventLogKeys[0]));
constexpr int64_t kPublicEventLogBlockedTokenCount = static_cast<int64_t>(sizeof(kPublicEventLogBlockedTokens) / sizeof(kPublicEventLogBlockedTokens[0]));

// "\"" + text.json_escape() + "\"". json_escape turns \ and " into \\ and \",
// which no token holds; the control characters it also escapes are left to
// GDScript rather than guessed (a tab's "\t" adds a 't' a token could match).
void append_json_string(const std::string &text, std::string &out) {
	out += '"';
	for (const char c : text) {
		if (static_cast<unsigned char>(c) < 0x20) {
			not_ported("JSON.stringify of a control character");
		}
		if (c == '\\' || c == '"') {
			out += '\\';
		}
		out += c;
	}
	out += '"';
}

// JSON.stringify(value) with its defaults (no indent, keys sorted as Strings),
// for what a public event holds: null, bools, ints, Strings, Arrays and
// Dictionaries with String keys. A float (Godot's shortest text) or anything
// else is left to GDScript.
void append_json(State &state, const Value &value, std::string &out) {
	switch (value.kind) {
		case state::Kind::Nil:
			out += "null";
			return;
		case state::Kind::Bool:
			out += value.b ? "true" : "false";
			return;
		case state::Kind::Int:
			out += compat::itos(value.i);
			return;
		case state::Kind::String:
		case state::Kind::StringName:
			append_json_string(state.text(value.ref), out);
			return;
		case state::Kind::Array: {
			const state::ValueList items = state.array(value.ref).items;
			out += '[';
			for (size_t index = 0; index < items.size(); ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json(state, items[index], out);
			}
			out += ']';
			return;
		}
		case state::Kind::Dict: {
			// keys.sort_custom<StringLikeVariantOrder>(): String keys by their
			// text; UTF-8 byte order is code point order.
			std::vector<std::pair<std::string, Value>> entries;
			{
				const state::DictNode &node = state.dict(value.ref);
				entries.reserve(node.keys.size());
				for (size_t index = 0; index < node.keys.size(); ++index) {
					const Value &entry_key = node.keys[index];
					if (!entry_key.is_string_like()) {
						not_ported("JSON.stringify of a Dictionary key that is not a String");
					}
					entries.emplace_back(state.text(entry_key.ref), node.values[index]);
				}
			}
			std::sort(entries.begin(), entries.end(), [](const std::pair<std::string, Value> &a, const std::pair<std::string, Value> &b) {
				return a.first < b.first;
			});
			out += '{';
			for (size_t index = 0; index < entries.size(); ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json_string(entries[index].first, out);
				out += ':';
				append_json(state, entries[index].second, out);
			}
			out += '}';
			return;
		}
		default:
			not_ported("JSON.stringify of a float or another value");
	}
}

// {"ok": false, "error": error}.
DictRef leak_result(State &state, const std::string &error) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::error), str(state.intern(error)));
	return result;
}

// OverworldRules._finalize_action_result__gd. The end of turn calls it too,
// with no event facts, once it has refused a recording profile.
DictRef finalize_action_result_body(State &state, DictRef session, bool ok, Atom base_message, bool refresh_fog, bool incremental_fog, DictRef scenario_event_facts) {
	const int64_t finalize_started_usec = overworld_rules::_rules_profile_timer(state);
	const int64_t commit_before_started_usec = overworld_rules::_rules_profile_timer(state);
	hero_command_rules::commit_active_hero(state, session);
	overworld_rules::_rules_profile_add_ms(state, key::finalize_commit_before_ms, commit_before_started_usec);
	const int64_t fog_before_started_usec = overworld_rules::_rules_profile_timer(state);
	if (refresh_fog) {
		overworld_rules::refresh_fog_of_war(state, session);
	} else if (incremental_fog) {
		overworld_rules::_reveal_current_fog_sources(state, session);
	}
	overworld_rules::_rules_profile_add_ms(state, key::finalize_fog_before_ms, fog_before_started_usec);

	int64_t objective_count = 0;
	int64_t hook_count = 0;
	const bool without_event_facts = gd::is_empty(state, scenario_event_facts);
	if (without_event_facts) {
		// ContentService.get_scenario_readonly(session.scenario_id).
		const DictRef scenario = gd::content_row(state, ContentTable::Scenario, text(state, session, key::scenario_id, key::empty));
		const Value objectives = scenario_rules::objectives_for_session(state, session);
		if (gd::is_dict(objectives)) {
			const Value victory_objectives = field_or_new_array(state, objectives.ref, key::victory);
			const Value defeat_objectives = field_or_new_array(state, objectives.ref, key::defeat);
			objective_count = gd::add(objective_count, gd::is_array(victory_objectives) ? state.array_size(victory_objectives.ref) : 0);
			objective_count = gd::add(objective_count, gd::is_array(defeat_objectives) ? state.array_size(defeat_objectives.ref) : 0);
		}
		const Value hooks = field_or_new_array(state, scenario, key::script_hooks);
		hook_count = gd::is_array(hooks) ? state.array_size(hooks.ref) : 0;
		overworld_rules::_rules_profile_set(state, key::scenario_eval, key::objective_count, int_value(objective_count));
		overworld_rules::_rules_profile_set(state, key::scenario_eval, key::hook_count, int_value(hook_count));
	}
	const int64_t scenario_started_usec = overworld_rules::_rules_profile_timer(state);
	const DictRef scenario_result = without_event_facts
			? overworld_rules::_evaluate_scenario_state(state, session)
			: overworld_rules::_evaluate_scenario_state_for_event(state, session, scenario_event_facts);
	overworld_rules::_rules_profile_add_ms(state, key::finalize_scenario_eval_ms, scenario_started_usec);
	// var scenario_profile: Dictionary = scenario_result.get("profile", {}) if ... is Dictionary else {}
	Value profile_value;
	DictRef scenario_profile = state.lookup(scenario_result, str(key::profile), profile_value) && gd::is_dict(profile_value) ? profile_value.ref : state.new_dict();
	if (gd::is_empty(state, scenario_profile)) {
		scenario_profile = state.new_dict();
		state.set(scenario_profile, str(key::dependency_mode), str(key::full));
		state.set(scenario_profile, str(key::fallback_reason), str(key::empty));
		state.set(scenario_profile, str(key::objective_count), int_value(objective_count));
		state.set(scenario_profile, str(key::hook_count), int_value(hook_count));
		state.set(scenario_profile, str(key::objectives_checked), int_value(objective_count));
		state.set(scenario_profile, str(key::objectives_skipped), int_value(0));
		state.set(scenario_profile, str(key::hooks_checked), int_value(hook_count));
		state.set(scenario_profile, str(key::hooks_skipped), int_value(0));
	}
	{
		const ArrayRef profile_keys = gd::keys(state, scenario_profile);
		for (const Value &profile_key : gd::items(state, array_value(profile_keys))) {
			overworld_rules::_rules_profile_set(state, key::scenario_eval, gd::stringify_or_fallback(state, profile_key), state.get(scenario_profile, profile_key, Value()));
		}
	}
	const Atom scenario_message = text(state, scenario_result, key::message, key::empty);
	const int64_t commit_after_started_usec = overworld_rules::_rules_profile_timer(state);
	hero_command_rules::commit_active_hero(state, session);
	overworld_rules::_rules_profile_add_ms(state, key::finalize_commit_after_ms, commit_after_started_usec);
	const int64_t fog_after_started_usec = overworld_rules::_rules_profile_timer(state);
	if (refresh_fog) {
		overworld_rules::refresh_fog_of_war(state, session);
	} else if (incremental_fog) {
		overworld_rules::_reveal_current_fog_sources(state, session);
	}
	overworld_rules::_rules_profile_add_ms(state, key::finalize_fog_after_ms, fog_after_started_usec);
	overworld_rules::_mark_runtime_normalized(state, session);
	overworld_rules::_rules_profile_add_ms(state, key::finalize_action_total_ms, finalize_started_usec);

	// " ".join(messages): base_message, then scenario_message, each when not "".
	std::vector<std::string> messages;
	if (base_message != key::empty) {
		messages.push_back(state.text(base_message));
	}
	if (scenario_message != key::empty) {
		messages.push_back(state.text(scenario_message));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(state.intern(join_texts(messages, " "))));
	state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
	return result;
}

} // namespace

// OverworldRules.

namespace overworld_rules {

Atom describe_enemy_activity(State &state, const Value &events_value, int64_t limit) {
	std::vector<Atom> lines;
	const ArrayRef events = _compact_enemy_activity_events(state, events_value, compat::engine_max<int64_t>(1, gd::mul(limit, 2)));
	for (const Value &event_value : gd::items(state, array_value(events))) {
		if (!gd::is_dict(event_value)) {
			continue;
		}
		const Atom line = _enemy_activity_line(state, event_value.ref);
		// seen.has(line): seen holds exactly the lines kept.
		if (line == key::empty || std::find(lines.begin(), lines.end(), line) != lines.end()) {
			continue;
		}
		lines.push_back(line);
		if (static_cast<int64_t>(lines.size()) >= compat::engine_max<int64_t>(1, limit)) {
			break;
		}
	}
	std::vector<std::string> parts;
	for (const Atom line : lines) {
		parts.push_back(state.text(line));
	}
	return state.intern(join_texts(parts, " | "));
}

ArrayRef _compact_enemy_activity_events(State &state, const Value &events_value, int64_t limit) {
	return enemy_adventure_rules::ai_public_event_log(state, events_value, limit);
}

Atom _enemy_activity_line(State &state, DictRef event) {
	const Atom summary = _enemy_activity_public_text(state, text(state, event, key::summary, key::empty));
	if (summary != key::empty) {
		return summary;
	}
	const Atom actor = gd::stringify_or_fallback(state, state.get(event, str(key::actor_label), state.get(event, str(key::faction_label), str(key::Enemy))));
	const Atom target = gd::stringify_or_fallback(state, state.get(event, str(key::target_label), state.get(event, str(key::target_id), str(key::the_frontier))));
	const Atom reason = _enemy_activity_public_text(state, text(state, event, key::public_reason, key::empty));
	// " (%s)" % reason if reason != "" else ""
	const std::string suffix = reason != key::empty ? " (" + state.text(reason) + ")" : std::string();
	const Atom event_type = text(state, event, key::event_type, key::empty);
	const char *verb = nullptr;
	if (event_type == key::ai_target_assigned) {
		verb = " targets ";
	} else if (event_type == key::ai_pressure_summary) {
		// "%s pressure centers on %s%s." % [String(event.get("faction_label", actor)), target, suffix]
		const Atom faction = gd::stringify_or_fallback(state, state.get(event, str(key::faction_label), str(actor)));
		return state.intern(state.text(faction) + " pressure centers on " + state.text(target) + suffix + ".");
	} else if (event_type == key::ai_commander_task_planned) {
		verb = " plans pressure on ";
	} else if (event_type == key::ai_site_seized) {
		verb = " seizes ";
	} else if (event_type == key::ai_site_contested) {
		verb = " contests ";
	} else if (event_type == key::ai_town_built) {
		verb = " builds ";
	} else if (event_type == key::ai_town_recruited) {
		verb = " recruits ";
	} else if (event_type == key::ai_garrison_reinforced) {
		verb = " reinforces ";
	} else if (event_type == key::ai_raid_reinforced) {
		verb = " feeds ";
	} else if (event_type == key::ai_commander_rebuilt) {
		verb = " rebuilds ";
	} else {
		return key::empty;
	}
	// "%s <verb> %s%s." % [actor, target, suffix]
	return state.intern(state.text(actor) + verb + state.text(target) + suffix + ".");
}

Atom _enemy_activity_public_text(State &state, Atom text) {
	const std::string output = compact_text(state.text(text));
	for (const char *token : kActivityHiddenTokens) {
		if (output.find(token) != std::string::npos) {
			return key::empty;
		}
	}
	return state.intern(output);
}

Atom _short_player_text(State &state, Atom text, int64_t max_chars) {
	return state.intern(short_player_text(state.text(text), max_chars));
}

Atom _end_turn_muster_summary(State &state, ArrayRef weekly_growth_messages, ArrayRef site_muster_messages) {
	std::vector<std::string> parts;
	for (const ArrayRef source : { weekly_growth_messages, site_muster_messages }) {
		for (const Value &message : gd::items(state, array_value(source))) {
			std::string part = stripped_text(state, message);
			if (!part.empty()) {
				parts.push_back(std::move(part));
			}
		}
	}
	if (parts.empty()) {
		return key::empty;
	}
	return state.intern(join_texts(parts, "; "));
}

Atom _end_turn_town_economy_summary(State &state, ArrayRef occupation_messages, ArrayRef recovery_messages, ArrayRef delivery_messages) {
	std::vector<std::string> parts;
	for (const ArrayRef source : { occupation_messages, recovery_messages, delivery_messages }) {
		for (const Value &message : gd::items(state, array_value(source))) {
			std::string part = stripped_text(state, message);
			if (!part.empty()) {
				parts.push_back(std::move(part));
			}
			if (parts.size() >= 3) {
				return state.intern(join_texts(parts, "; "));
			}
		}
	}
	return state.intern(join_texts(parts, "; "));
}

Atom _end_turn_resolution_summary(State &state, DictRef session, DictRef result) {
	std::vector<std::string> parts;
	// "Day %d" % session.day (SessionData.day is an int).
	parts.push_back("Day " + compat::itos(gd::to_int(state, gd::field(state, session, key::day))));
	const std::string income_summary = stripped_text(state, state.get(result, str(key::resource_income_summary), str(key::empty)));
	if (!income_summary.empty()) {
		parts.push_back("income " + income_summary);
	}
	const std::string movement_summary = stripped_text(state, state.get(result, str(key::movement_reset_summary), str(key::empty)));
	if (!movement_summary.empty()) {
		parts.push_back(movement_summary);
	}
	const std::string muster_summary = stripped_text(state, state.get(result, str(key::weekly_muster_summary), str(key::empty)));
	if (!muster_summary.empty()) {
		parts.push_back("muster " + short_player_text(muster_summary, 72));
	}
	const std::string town_summary = stripped_text(state, state.get(result, str(key::town_economy_summary), str(key::empty)));
	if (!town_summary.empty()) {
		parts.push_back("towns " + short_player_text(town_summary, 72));
	}
	const std::string enemy_summary = stripped_text(state, state.get(result, str(key::enemy_activity_summary), str(key::empty)));
	if (!enemy_summary.empty()) {
		parts.push_back("enemy " + short_player_text(enemy_summary, 96));
	}
	return state.intern(join_texts(parts, " | "));
}

DictRef _evaluate_scenario_state(State &state, DictRef session) {
	return scenario_rules::evaluate_session(state, session);
}

void _reveal_current_fog_sources(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	if (overworld_level_rules::level_count(state, session) > 1) {
		_normalize_fog_of_war(state, session);
		return;
	}
	if (!_fog_state_ready(state, session)) {
		_normalize_fog_of_war(state, session);
		return;
	}
	const Vector2i map_size = derive_map_size(state, session);
	// var fog: Dictionary = session.overworld.get(FOG_KEY, {})
	Value fog_value;
	const DictRef fog = state.lookup(session_view::overworld(state, session), str(key::fog), fog_value) ? gd::as_dict(fog_value) : state.new_dict();
	const ArrayRef explored_tiles = _normalize_visibility_grid(state, field_or_new_array(state, fog, key::explored_tiles), map_size);
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, -1);
	const DictRef payload = _build_fog_payload(state, _duplicate_visibility_grid(state, explored_tiles), explored_tiles, map_size);
	state.set(session_view::overworld(state, session), str(key::fog), dict_value(payload));
}

DictRef _finalize_action_result(State &state, DictRef session, bool ok, Atom base_message, bool refresh_fog, bool incremental_fog, DictRef scenario_event_facts) {
	return finalize_action_result_body(state, session, ok, base_message, refresh_fog, incremental_fog, scenario_event_facts);
}

DictRef _end_turn_close_day(State &state, DictRef session, DictRef opened, DictRef enemy_turn_result) {
	refuse_recording_profile(state);
	// What _end_turn_open_day returned: its very containers.
	const ArrayRef messages = gd::as_array(gd::index(state, opened, str(key::messages)));
	const ArrayRef occupation_messages = gd::as_array(gd::index(state, opened, str(key::occupation_messages)));
	const ArrayRef recovery_messages = gd::as_array(gd::index(state, opened, str(key::recovery_messages)));
	const ArrayRef weekly_growth_messages = gd::as_array(gd::index(state, opened, str(key::weekly_growth_messages)));
	const ArrayRef site_muster_messages = gd::as_array(gd::index(state, opened, str(key::site_muster_messages)));
	const ArrayRef delivery_messages = gd::as_array(gd::index(state, opened, str(key::delivery_messages)));
	const DictRef total_income = gd::as_dict(gd::index(state, opened, str(key::total_income)));
	const Value movement_after = gd::index(state, opened, str(key::movement_after));

	const Atom enemy_activity_summary = describe_enemy_activity(state, field_or_new_array(state, enemy_turn_result, key::events), 4);
	const Atom enemy_message = text(state, enemy_turn_result, key::message, key::empty);
	if (enemy_message != key::empty) {
		state.append(messages, str(enemy_message));
	}
	// A player with no town for a week, or with nothing left, is out.
	// messages.append_array(PlayerEliminationRules.apply_daily(session))
	{
		const ArrayRef eliminations = player_elimination_rules::apply_daily(state, session);
		const state::ValueList items = state.array(eliminations).items;
		for (const Value &item : items) {
			state.append(messages, item);
		}
	}
	// _finalize_action_result(session, true, " ".join(messages)): no event facts.
	const Atom closing_message = join_array(state, " ", messages);
	const DictRef result = finalize_action_result_body(state, session, true, closing_message, true, false, state.new_dict());
	normalize_overworld_state(state, session);
	// session.set_meta(CLOSING_NORMALIZE_DAY_META, int(session.day))
	state.set(session_view::meta(state, session), gd::name_value(key::_overworld_end_turn_closing_normalize_day), int_value(gd::to_int(state, gd::field(state, session, key::day))));
	state.set(result, str(key::enemy_activity_summary), str(enemy_activity_summary));
	state.set(result, str(key::enemy_activity_events), array_value(_compact_enemy_activity_events(state, field_or_new_array(state, enemy_turn_result, key::events), 10)));
	{
		// The profile Dictionary itself, when it is one and not empty.
		Value profile;
		if (state.lookup(enemy_turn_result, str(key::profile), profile) && gd::is_dict(profile) && !gd::is_empty(state, profile.ref)) {
			state.set(result, str(key::enemy_turn_profile), profile);
		}
	}
	state.set(result, str(key::resource_income_summary), str(_describe_resource_delta(state, dict_value(total_income))));
	state.set(result, str(key::weekly_muster_summary), str(_end_turn_muster_summary(state, weekly_growth_messages, site_muster_messages)));
	{
		// "Move %d/%d ready" % [int(movement_after.get("current", 0)), int(movement_after.get("max", 0))]
		const DictRef movement = gd::as_dict(movement_after);
		const int64_t current = gd::int_field(state, movement, key::current, 0);
		const int64_t maximum = gd::int_field(state, movement, key::max, 0);
		const Atom movement_reset_summary = state.intern("Move " + compat::itos(current) + "/" + compat::itos(maximum) + " ready");
		state.set(result, str(key::movement_reset_summary), str(movement_reset_summary));
	}
	state.set(result, str(key::town_economy_summary), str(_end_turn_town_economy_summary(state, occupation_messages, recovery_messages, delivery_messages)));
	state.set(result, str(key::turn_resolution_summary), str(_end_turn_resolution_summary(state, session, result)));
	return result;
}

DictRef end_turn(State &state, DictRef session) {
	const DictRef opened = _end_turn_open_day(state, session);
	// _run_enemy_turn_cycle: the rosters are not settled, since the close
	// evaluates the scenario, which normalizes them again.
	const DictRef enemy_turn_result = enemy_turn_rules::run_enemy_turn(state, session, false);
	return _end_turn_close_day(state, session, opened, enemy_turn_result);
}

} // namespace overworld_rules

// EnemyAdventureRules.

namespace enemy_adventure_rules {

ArrayRef ai_public_event_log(State &state, const Value &events_value, int64_t limit) {
	const ArrayRef public_events = state.new_array();
	if (!gd::is_array(events_value)) {
		return public_events;
	}
	for (const Value &event_value : gd::items(state, events_value)) {
		if (!gd::is_dict(event_value)) {
			continue;
		}
		const DictRef public_event = ai_public_event_log_entry(state, event_value.ref);
		if (gd::is_empty(state, public_event)) {
			continue;
		}
		// ai_public_event_log_leak_check([public_event])
		const ArrayRef surfaces = state.new_array();
		state.append(surfaces, dict_value(public_event));
		const DictRef leak_check = ai_public_event_log_leak_check(state, array_value(surfaces));
		if (!gd::bool_field(state, leak_check, key::ok, false)) {
			continue;
		}
		state.append(public_events, dict_value(public_event));
		if (state.array_size(public_events) >= compat::engine_max<int64_t>(1, limit)) {
			break;
		}
	}
	return public_events;
}

DictRef ai_public_event_log_entry(State &state, DictRef event) {
	const Atom event_type = text(state, event, key::event_type, key::empty);
	if (!atom_in(event_type, std::begin(kPublicEventLogTypes), std::end(kPublicEventLogTypes))) {
		return state.new_dict();
	}
	const Atom visibility = text(state, event, key::visibility, key::empty);
	if (visibility == key::hidden_debug) {
		return state.new_dict();
	}
	const ArrayRef reason_codes = _normalize_string_array(state, field_or_new_array(state, event, key::reason_codes));
	Atom public_reason = _public_event_log_text(state, text(state, event, key::public_reason, key::empty));
	if (public_reason == key::empty) {
		public_reason = _public_event_log_text(state, _public_reason_from_codes(state, reason_codes));
	}
	// String(event.get("faction_label", event.get("faction_id", "")))
	const Atom faction_label = _public_event_log_text(state, gd::stringify_or_fallback(state, state.get(event, str(key::faction_label), state.get(event, str(key::faction_id), str(key::empty)))));
	const Atom actor_label = _public_event_log_text(state, text(state, event, key::actor_label, key::empty));
	// String(event.get("target_label", event.get("target_id", "")))
	const Atom target_label = _public_event_log_text(state, gd::stringify_or_fallback(state, state.get(event, str(key::target_label), state.get(event, str(key::target_id), str(key::empty)))));
	Atom summary = _public_event_log_text(state, text(state, event, key::summary, key::empty));
	if (summary == key::empty) {
		summary = _public_event_log_text(state, _ai_event_summary(state, event_type, faction_label, actor_label, target_label, public_reason, key::empty));
	}
	if (summary == key::empty && target_label == key::empty) {
		return state.new_dict();
	}
	const DictRef public_event = state.new_dict();
	state.set(public_event, str(key::day), int_value(gd::int_field(state, event, key::day, 0)));
	state.set(public_event, str(key::event_type), str(event_type));
	state.set(public_event, str(key::faction_id), str(_public_event_log_text(state, text(state, event, key::faction_id, key::empty))));
	state.set(public_event, str(key::faction_label), str(faction_label));
	state.set(public_event, str(key::actor_label), str(actor_label));
	state.set(public_event, str(key::target_kind), str(_public_event_log_text(state, text(state, event, key::target_kind, key::empty))));
	state.set(public_event, str(key::target_id), str(_public_event_log_text(state, text(state, event, key::target_id, key::empty))));
	state.set(public_event, str(key::target_label), str(target_label));
	state.set(public_event, str(key::visibility), str(visibility));
	state.set(public_event, str(key::public_importance), str(_public_event_log_text(state, text(state, event, key::public_importance, key::low))));
	state.set(public_event, str(key::summary), str(summary));
	state.set(public_event, str(key::reason_codes), array_value(reason_codes));
	state.set(public_event, str(key::public_reason), str(public_reason));
	if (text(state, event, key::player_id, key::empty) != key::empty) {
		// String(event.player_id)
		const Value player_id = gd::index(state, event, str(key::player_id));
		state.set(public_event, str(key::player_id), str(_public_event_log_text(state, gd::stringify_or_fallback(state, player_id))));
	}
	return public_event;
}

DictRef ai_public_event_log_leak_check(State &state, const Value &public_surfaces) {
	std::vector<Value> stack;
	stack.push_back(public_surfaces);
	int64_t checked_events = 0;
	while (!stack.empty()) {
		const Value value = stack.back();
		stack.pop_back();
		if (gd::is_array(value)) {
			for (const Value &item : gd::items(state, value)) {
				stack.push_back(item);
			}
			continue;
		}
		if (gd::is_dict(value)) {
			const DictRef dict = value.ref;
			if (text(state, dict, key::event_type, key::empty) != key::empty) {
				checked_events = gd::add(checked_events, 1);
				const state::ValueList keys = state.dict(dict).keys.list();
				for (const Value &entry_key : keys) {
					if (!atom_in(gd::stringify_or_fallback(state, entry_key), std::begin(kPublicEventLogKeys), std::end(kPublicEventLogKeys))) {
						// "%s leaked public-log key %s" % [value.get("event_type", "event"), key]
						const Atom event_name = gd::stringify_or_fallback(state, state.get(dict, str(key::event_type), str(key::event)));
						const Atom key_name = gd::stringify_or_fallback(state, entry_key);
						return leak_result(state, state.text(event_name) + " leaked public-log key " + state.text(key_name));
					}
				}
			}
			std::string json;
			append_json(state, value, json);
			for (const char *token : kPublicEventLogBlockedTokens) {
				if (json.find(token) != std::string::npos) {
					// "%s leaked blocked public-log token %s" % [value.get("event_type", "event"), token]
					const Atom event_name = gd::stringify_or_fallback(state, state.get(dict, str(key::event_type), str(key::event)));
					return leak_result(state, state.text(event_name) + " leaked blocked public-log token " + token);
				}
			}
			const state::ValueList nested_keys = state.dict(dict).keys.list();
			for (const Value &nested_key : nested_keys) {
				const Value nested = gd::index(state, dict, nested_key);
				if (gd::is_array(nested) || gd::is_dict(nested)) {
					stack.push_back(nested);
				}
			}
			continue;
		}
		const std::string value_text = state.text(gd::stringify_or_fallback(state, value));
		for (const char *token : kPublicEventLogBlockedTokens) {
			if (value_text.find(token) != std::string::npos) {
				return leak_result(state, std::string("public log leaked token ") + token);
			}
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::checked_events), int_value(checked_events));
	state.set(result, str(key::allowed_public_key_count), int_value(kPublicEventLogKeyCount));
	state.set(result, str(key::blocked_token_count), int_value(kPublicEventLogBlockedTokenCount));
	return result;
}

Atom _public_reason_from_codes(State &state, ArrayRef reason_codes) {
	const ArrayRef codes = _normalize_string_array(state, array_value(reason_codes));
	// code in codes (Array.has).
	const auto has = [&](Atom code) { return gd::array_has(state, codes, str(code)); };
	if (has(key::regroup_understrength)) {
		return key::regrouping_understrength_host;
	}
	if (has(key::town_defense)) {
		return key::defending_threatened_town;
	}
	if (has(key::site_defense)) {
		return key::defending_held_site;
	}
	if (has(key::front_stabilization)) {
		return key::front_stabilization_text;
	}
	if (has(key::frontier_scouting) || has(key::search_contact) || has(key::no_known_targets)) {
		return key::scouting_the_frontier;
	}
	if (has(key::retake_front)) {
		return key::retaking_captured_town;
	}
	if (has(key::town_expansion) || has(key::neutral_town_claim)) {
		return key::neutral_town_expansion;
	}
	if (has(key::resource_risk_staging) || has(key::resource_risk_regroup)) {
		return key::gathering_strength_for_resource_claim;
	}
	if (has(key::town_siege)) {
		return key::town_siege_remains_the_main_front;
	}
	if (has(key::persistent_income_denial) && has(key::recruit_denial)) {
		return key::recruit_and_income_denial;
	}
	if (has(key::persistent_income_denial) && has(key::route_vision)) {
		return key::income_and_route_vision_denial;
	}
	if (has(key::persistent_income_denial)) {
		return key::income_denial;
	}
	if (has(key::resource_scarcity)) {
		return key::seeking_scarce_resources;
	}
	if (has(key::recruit_denial)) {
		return key::recruit_denial_text;
	}
	if (has(key::route_vision)) {
		return key::route_vision_denial;
	}
	if (has(key::route_pressure)) {
		return key::route_pressure_text;
	}
	if (has(key::objective_front)) {
		return key::objective_front_text;
	}
	if (has(key::site_seized)) {
		return key::site_seized_text;
	}
	if (has(key::site_contested)) {
		return key::site_contested_text;
	}
	if (has(key::artifact_secured)) {
		return key::artifact_secured_text;
	}
	if (has(key::commander_memory)) {
		return key::known_commander_focus;
	}
	if (has(key::enemy_scouting)) {
		return key::scouted_target;
	}
	return key::empty;
}

Atom _public_event_log_text(State &state, Atom text) {
	const std::string output = compact_text(state.text(text));
	for (const char *token : kPublicEventLogBlockedTokens) {
		if (output.find(token) != std::string::npos) {
			return key::empty;
		}
	}
	return state.intern(output);
}

Atom _ai_event_summary(State &state, Atom event_type, Atom faction_label, Atom actor_label, Atom target_label, Atom public_reason, Atom summary_prefix) {
	const std::string actor_clause = state.text(actor_label != key::empty ? actor_label : faction_label);
	// " (%s)" % public_reason if public_reason != "" else ""
	const std::string reason_suffix = public_reason != key::empty ? " (" + state.text(public_reason) + ")" : std::string();
	const std::string target = state.text(target_label);
	std::string summary;
	if (event_type == key::ai_target_assigned) {
		const std::string verb = summary_prefix != key::empty ? state.text(summary_prefix) : std::string("targets");
		// "%s %s %s%s." % [actor_clause, verb, target_label, reason_suffix]
		summary = actor_clause + " " + verb + " " + target + reason_suffix + ".";
	} else if (event_type == key::ai_site_seized) {
		summary = actor_clause + " seizes " + target + reason_suffix + ".";
	} else if (event_type == key::ai_site_contested) {
		summary = actor_clause + " contests " + target + reason_suffix + ".";
	} else if (event_type == key::ai_site_defended) {
		summary = actor_clause + " defends " + target + reason_suffix + ".";
	} else if (event_type == key::ai_town_captured) {
		summary = actor_clause + " claims " + target + reason_suffix + ".";
	} else if (event_type == key::ai_pressure_summary) {
		summary = state.text(faction_label) + " pressure centers on " + target + reason_suffix + ".";
	} else if (event_type == key::ai_raid_grouped) {
		summary = actor_clause + " consolidates on " + target + reason_suffix + ".";
	} else {
		summary = actor_clause + " marks " + target + reason_suffix + ".";
	}
	return state.intern(summary);
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
