// SaveService.gd: the load and continue actions, the describe_* texts, slot
// details, the save paths and the summary-to-save write (Phase 7, 7.12).

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace aurelion::rules::port::save_service {

namespace {

using state::Kind;
namespace key = state::key;

// MANUAL_SLOT_IDS [1, 2, 3]; MANUAL_SLOT_IDS[0].
constexpr int64_t kFirstManualSlot = 1;
constexpr int64_t kLastManualSlot = 3;
// Error.OK and Error.ERR_ALREADY_EXISTS.
constexpr int64_t kOk = 0;
constexpr int64_t kErrAlreadyExists = 32;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// String(x): stringify(), and the engine's for a float or a container.
Atom string_of_value(State &state, const Value &value) {
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
Atom string_of(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of_value(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// String(d.get(name, d.get(inner, fallback))).
Atom string_of_either(State &state, DictRef dict, Atom name, Atom inner, Atom fallback) {
	const Value second = state.get(dict, gd::str(inner), gd::str(fallback));
	return string_of_value(state, state.get(dict, gd::str(name), second));
}

// separator.join(parts) of an untyped Array's items (each as String(x)).
Atom join(State &state, Atom separator, const std::vector<Value> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(string_of_value(state, parts[index]));
	}
	return state.intern(joined);
}

Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Value> parts;
	const int64_t size = state.array_size(array);
	for (int64_t index = 0; index < size; ++index) {
		parts.push_back(state.at(array, index));
	}
	return join(state, separator, parts);
}

// d.clear() (Dictionary::clear): a read-only Dictionary prints an error and stays.
void dict_clear(State &state, DictRef dict) {
	if (state.dict(dict).read_only) {
		state.print_error("Dictionary is in read-only state.");
		return;
	}
	const ArrayRef keys = gd::keys(state, dict);
	const int64_t size = state.array_size(keys);
	for (int64_t index = 0; index < size; ++index) {
		state.erase(dict, state.at(keys, index));
	}
}

// session == null or session.scenario_id == "".
bool no_active_expedition(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return true;
	}
	const DictRef view = gd::object_view(state, session);
	return gd::to_string(gd::index(state, view, gd::str(key::scenario_id))) == key::empty;
}

// The session object a host call takes.
Value session_object(State &state, const Value &session) {
	return session.kind == Kind::Dict ? gd::view_object(state, session.ref) : session;
}

// ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", "campaign"))).
Atom summary_launch_mode_label(State &state, DictRef summary) {
	return scenario_select_rules::launch_mode_label(state, string_of(state, summary, key::launch_mode, key::campaign));
}

// ScenarioSelectRulesScript.difficulty_label(String(summary.get("difficulty",
// ScenarioSelectRulesScript.default_difficulty_id()))).
Atom summary_difficulty_label(State &state, DictRef summary) {
	const Atom fallback = scenario_select_rules::default_difficulty_id(state);
	return scenario_select_rules::difficulty_label(state, string_of(state, summary, key::difficulty, fallback));
}

// profile[name] = int(profile.get(name, 0)) + amount.
void profile_add(State &state, DictRef profile, Atom name, int64_t amount) {
	put(state, profile, name, gd::int_value(gd::add(gd::int_field(state, profile, name, 0), amount)));
}

} // namespace

Atom resume_target_for_session(State &state, const Value &session) {
	return _resume_target_for_session(state, session);
}

bool can_load_summary(State &state, DictRef summary) {
	Value payload;
	const bool has_inline_payload = state.lookup(summary, gd::str(key::payload), payload) && payload.kind == Kind::Dict && !gd::is_empty(state, payload.ref);
	return gd::bool_field(state, summary, key::valid, false) && gd::bool_field(state, summary, key::loadable, false) && (has_inline_payload || gd::bool_field(state, summary, key::payload_deferred, false));
}

Atom load_action_label(State &state, DictRef summary) {
	if (gd::is_empty(state, summary) || !can_load_summary(state, summary)) {
		return key::load_selected;
	}
	const Atom target = string_of(state, summary, key::resume_target, key::overworld);
	if (target == key::battle) {
		return key::resume_battle;
	}
	if (target == key::town) {
		return key::resume_town;
	}
	if (target == key::outcome) {
		return key::review_outcome;
	}
	return key::resume_expedition;
}

Atom continue_action_label(State &state, DictRef summary) {
	if (gd::is_empty(state, summary) || !can_load_summary(state, summary)) {
		return key::continue_latest;
	}
	const Atom target = string_of(state, summary, key::resume_target, key::overworld);
	if (target == key::battle) {
		return key::resume_latest_battle;
	}
	if (target == key::town) {
		return key::resume_latest_town;
	}
	if (target == key::outcome) {
		return key::review_latest_outcome;
	}
	return key::continue_latest;
}

Atom load_action_tooltip(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::no_loadable_saves_are_available;
	}
	if (!can_load_summary(state, summary)) {
		return string_of(state, summary, key::status_text, key::this_save_cannot_be_resumed);
	}
	const Atom scenario_name = _safe_player_text(state, string_of_either(state, summary, key::scenario_name, key::scenario_id, key::this_expedition), 48);
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	Atom timing = key::empty;
	if (day > 0) {
		timing = gd::format(state, key::on_day_d, {gd::int_value(day)});
	}
	return gd::format(state, key::s_s_at_s_loading_does, {
			gd::str(gd::format(state, key::resume_the_saved_expedition_in_s, {gd::str(scenario_name)})),
			gd::str(timing),
			gd::str(_load_destination_label(state, summary)),
	});
}

Atom describe_summary_resume_recap(State &state, DictRef summary) {
	return _describe_summary_resume_recap_with_context(state, summary, state.new_dict());
}

Atom _describe_summary_resume_recap_with_context(State &state, DictRef summary, DictRef profile) {
	if (gd::is_empty(state, summary)) {
		return key::empty;
	}
	if (!can_load_summary(state, summary)) {
		return gd::format(state, key::saved_state_s, {gd::str(string_of(state, summary, key::status_text, key::this_save_cannot_be_resumed))});
	}
	// Only exact copies of an existing, file-verified summary can reuse text.
	DictRef cached = state.new_dict();
	Value inline_payload;
	if (state.lookup(summary, gd::str(key::payload), inline_payload) && inline_payload.kind == Kind::Dict && !gd::is_empty(state, inline_payload.ref)) {
		const Atom slot_type = string_of(state, summary, key::slot_type, key::empty);
		const Atom slot_id = string_of(state, summary, key::slot_id, key::empty);
		const Atom path = string_of(state, summary, key::path, key::empty);
		cached = _cached_slot_summary_entry(state, slot_type, slot_id, path);
	}
	// cached.get("summary", {}) != summary: a missing one is {}.
	Value cached_summary;
	const bool same_summary = state.lookup(cached, gd::str(key::summary), cached_summary)
			? gd::equal(state, cached_summary, gd::dict_value(summary))
			: gd::is_empty(state, summary);
	if (!same_summary) {
		cached = state.new_dict();
	}
	if (state.has(cached, gd::str(key::resume_recap)) && gd::int_field(state, cached, key::recap_content_revision, -1) == gd::content_revision(state)) {
		profile_add(state, profile, key::text_cache_hits, 1);
		return string_of_value(state, gd::index(state, cached, gd::str(key::resume_recap)));
	}
	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	if (no_active_expedition(state, session)) {
		return key::saved_state_this_save_cannot_be;
	}
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	const Value object = session_object(state, session);
	gd::call_static(state, key::overworld_rules_script, key::begin_normalized_read_scope, {object});
	town_rules::begin_read_scope(state, gd::object_view(state, session));
	const DictRef recap_context = _session_save_recap_context(state, session, summary, key::empty, false, state.new_dict());
	const Atom result = _session_save_resume_recap_from_context(state, session, summary, recap_context);
	town_rules::end_read_scope(state, gd::object_view(state, session));
	gd::call_static(state, key::overworld_rules_script, key::end_normalized_read_scope, {object});
	profile_add(state, profile, key::context_build_count, 1);
	profile_add(state, profile, key::context_reuse_count, 3);
	if (!gd::is_empty(state, cached)) {
		put(state, cached, key::resume_recap, gd::str(result));
		put(state, cached, key::recap_content_revision, gd::int_value(gd::content_revision(state)));
	}
	return result;
}

Atom describe_summary_next_play_action(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::next_play_action_select_a_loadable;
	}
	if (!can_load_summary(state, summary)) {
		return key::next_play_action_select_a_loadable_2;
	}
	const Atom action = load_action_label(state, summary);
	const Atom target = string_of(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		return gd::format(state, key::next_play_action_s_finish_the, {gd::str(action)});
	}
	if (target == key::town) {
		return gd::format(state, key::next_play_action_s_make_the, {gd::str(action)});
	}
	if (target == key::outcome) {
		return gd::format(state, key::next_play_action_s_save_if, {gd::str(action)});
	}
	if (target == key::overworld) {
		return gd::format(state, key::next_play_action_s_choose_the, {gd::str(action)});
	}
	return key::next_play_action_select_a_loadable_2;
}

Atom describe_summary_play_check(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::play_check_no_loadable_save_start;
	}
	if (!can_load_summary(state, summary)) {
		return key::play_check_save_unavailable_select_a;
	}
	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	const Atom resume_context = _safe_player_text(state, _resume_context_label(state, summary), 34);
	const Atom next_play_action = gd::strip_edges(state, gd::trim_prefix(state, describe_summary_next_play_action(state, summary), key::next_play_action));
	const Atom next_action = _safe_player_text(state, next_play_action, 72);
	const Atom state_line = _summary_play_check_state_line(state, session, summary);
	std::vector<Value> parts;
	if (resume_context != key::empty) {
		parts.push_back(gd::str(gd::format(state, key::s_ready, {gd::str(resume_context)})));
	}
	if (next_action != key::empty) {
		parts.push_back(gd::str(next_action));
	}
	if (state_line != key::empty) {
		parts.push_back(gd::str(state_line));
	}
	// parts.slice(0, min(3, parts.size())).
	if (parts.size() > 3) {
		parts.resize(3);
	}
	return gd::format(state, key::play_check_s, {gd::str(join(state, key::space_bar_space, parts))});
}

Atom describe_summary_resume_handoff(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::resume_handoff_select_a_loadable_save;
	}
	if (!can_load_summary(state, summary)) {
		return key::resume_handoff_this_save_cannot_be;
	}
	const Atom target = _resume_context_label(state, summary);
	const Atom preserved = _resume_preserved_context(state, summary);
	return gd::format(state, key::resume_handoff_s_opens_s_with, {
			gd::str(load_action_label(state, summary)),
			gd::str(target),
			gd::str(preserved),
	});
}

Atom describe_resume_brief(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::no_save_selected;
	}
	if (!can_load_summary(state, summary)) {
		return string_of(state, summary, key::status_text, key::this_save_cannot_be_resumed);
	}
	std::vector<Value> parts;
	parts.push_back(gd::str(summary_launch_mode_label(state, summary)));
	const Atom scenario_name = string_of_either(state, summary, key::scenario_name, key::scenario_id, key::unknown_scenario);
	if (scenario_name != key::empty) {
		parts.push_back(gd::str(scenario_name));
	}
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		parts.push_back(gd::str(gd::format(state, key::day_d, {gd::int_value(day)})));
	}
	parts.push_back(gd::str(_resume_context_label(state, summary)));
	const Atom scenario_status = string_of(state, summary, key::scenario_status, key::in_progress);
	if (scenario_status != key::in_progress) {
		parts.push_back(gd::str(_humanize_label(state, scenario_status)));
	}
	return join(state, key::space_bar_space, parts);
}

Atom describe_slot(State &state, DictRef summary) {
	const Atom slot_label = _slot_label(state, summary);
	if (!gd::bool_field(state, summary, key::valid, false)) {
		return gd::format(state, key::s_blocked_s, {gd::str(slot_label), gd::str(string_of(state, summary, key::status_text, key::Unavailable))});
	}

	std::vector<Value> parts;
	parts.push_back(gd::str(slot_label));
	parts.push_back(gd::str(_summary_status_badge(state, summary)));
	const Atom modified_label = format_modified_timestamp(state, compat::float_to_int(_summary_sort_timestamp(state, summary)));
	if (modified_label != key::empty) {
		parts.push_back(gd::str(modified_label));
	}
	const Atom scenario_name = string_of_either(state, summary, key::scenario_name, key::scenario_id, key::unknown_scenario);
	if (scenario_name != key::empty) {
		parts.push_back(gd::str(scenario_name));
	}
	parts.push_back(gd::str(summary_launch_mode_label(state, summary)));
	parts.push_back(gd::str(summary_difficulty_label(state, summary)));
	parts.push_back(gd::str(_resume_target_label(state, summary)));
	const Atom battle_name = string_of(state, summary, key::battle_name, key::empty);
	if (battle_name != key::empty && string_of(state, summary, key::resume_target, key::empty) == key::battle) {
		parts.push_back(gd::str(battle_name));
	}
	const Atom resume_location = string_of(state, summary, key::resume_location, key::empty);
	if (resume_location != key::empty && string_of(state, summary, key::resume_target, key::empty) != key::battle) {
		parts.push_back(gd::str(resume_location));
	}
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		parts.push_back(gd::str(gd::format(state, key::day_d, {gd::int_value(day)})));
	}
	return join(state, key::space_bar_space, parts);
}

Atom describe_slot_browser_row(State &state, DictRef summary) {
	const Atom slot_label = _slot_label(state, summary);
	if (!gd::bool_field(state, summary, key::valid, false)) {
		return gd::format(state, key::s_unavailable, {gd::str(slot_label)});
	}

	std::vector<Value> parts;
	parts.push_back(gd::str(slot_label));
	const Atom scenario_name = _safe_player_text(state, string_of_either(state, summary, key::scenario_name, key::scenario_id, key::unknown_scenario), 34);
	if (scenario_name != key::empty) {
		parts.push_back(gd::str(scenario_name));
	}
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		parts.push_back(gd::str(gd::format(state, key::day_d, {gd::int_value(day)})));
	}
	parts.push_back(gd::str(_load_destination_label(state, summary)));
	return join(state, key::space_bar_space, parts);
}

Atom describe_load_preview(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::no_saved_expedition_selected;
	}
	if (!can_load_summary(state, summary)) {
		return gd::format(state, key::s_unavailable_s, {
				gd::str(_slot_label(state, summary)),
				gd::str(string_of(state, summary, key::status_text, key::this_save_cannot_be_opened)),
		});
	}

	const Atom scenario_name = _safe_player_text(state, string_of_either(state, summary, key::scenario_name, key::scenario_id, key::saved_expedition), 64);
	const Atom mode_label = summary_launch_mode_label(state, summary);
	const Atom difficulty_label = summary_difficulty_label(state, summary);
	std::vector<Value> lines;
	lines.push_back(gd::str(_slot_label(state, summary)));
	lines.push_back(gd::str(scenario_name));
	std::vector<Value> expedition_parts;
	expedition_parts.push_back(gd::str(mode_label));
	expedition_parts.push_back(gd::str(difficulty_label));
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		expedition_parts.push_back(gd::str(gd::format(state, key::day_d, {gd::int_value(day)})));
	}
	lines.push_back(gd::str(join(state, key::space_bar_space, expedition_parts)));

	const Atom hero_name = _safe_player_text(state, string_of(state, summary, key::hero_name, key::empty), 48);
	if (hero_name != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::commander_s, {gd::str(hero_name)})));
	}
	const Atom modified_label = format_modified_timestamp(state, compat::float_to_int(_summary_sort_timestamp(state, summary)));
	if (modified_label != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::saved_s, {gd::str(modified_label)})));
	}
	lines.push_back(gd::str(gd::format(state, key::returns_to_s, {gd::str(_load_destination_label(state, summary))})));

	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	Atom next_decision = _safe_player_text(state, _session_next_decision_line(state, session, summary), 96);
	if (next_decision == key::empty) {
		next_decision = _fallback_resume_decision(state, string_of(state, summary, key::resume_target, key::blocked));
	}
	if (next_decision != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::next_s, {gd::str(next_decision)})));
	}
	return join(state, key::newline, lines);
}

Atom _load_destination_label(State &state, DictRef summary) {
	const Atom location = _safe_player_text(state, gd::strip_edges(state, string_of(state, summary, key::resume_location, key::empty)), 48);
	const Atom target = string_of(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		return location != key::empty ? location : key::active_battle;
	}
	if (target == key::town) {
		return location != key::empty ? location : key::Town;
	}
	if (target == key::outcome) {
		const Atom result = _humanize_label(state, string_of(state, summary, key::scenario_status, key::outcome));
		return result != key::empty ? gd::format(state, key::s_review, {gd::str(result)}) : key::result_review;
	}
	if (target == key::overworld) {
		return key::adventure_map;
	}
	return key::Unavailable;
}

Atom describe_slot_continuity_cue(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return key::cue_select_a_saved_expedition;
	}
	if (!can_load_summary(state, summary)) {
		return key::cue_this_save_cannot_be_resumed;
	}

	Atom target = _safe_player_text(state, _resume_target_label(state, summary), 28);
	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	Atom next_decision = _safe_player_text(state, _session_next_decision_line(state, session, summary), 56);
	if (next_decision == key::empty) {
		next_decision = _fallback_resume_decision(state, string_of(state, summary, key::resume_target, key::blocked));
	}
	if (target == key::empty) {
		target = _safe_player_text(state, _resume_context_label(state, summary), 28);
	}
	return gd::format(state, key::cue_s_s, {gd::str(target), gd::str(next_decision)});
}

Atom describe_slot_details(State &state, DictRef summary) {
	return _describe_slot_details(state, summary, Value(), state.new_dict(), key::empty);
}

Atom _describe_slot_details(State &state, DictRef summary, const Value &trusted_normalized_session, DictRef recap_context, Atom progress_recap) {
	std::vector<Value> lines;
	lines.push_back(gd::str(_slot_label(state, summary)));
	const Atom modified_label = format_modified_timestamp(state, gd::int_field(state, summary, key::modified_timestamp, 0));
	if (modified_label != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::updated_s, {gd::str(modified_label)})));
	}
	const Atom recorded_label = format_modified_timestamp(state, gd::int_field(state, summary, key::recorded_timestamp, 0));
	if (recorded_label != key::empty && recorded_label != modified_label) {
		lines.push_back(gd::str(gd::format(state, key::recorded_in_save_s, {gd::str(recorded_label)})));
	}

	const Atom scenario_id = string_of(state, summary, key::scenario_id, key::empty);
	if (scenario_id != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::scenario_s_s, {gd::str(string_of(state, summary, key::scenario_name, scenario_id)), gd::str(scenario_id)})));
	}
	const Atom mode_label = summary_launch_mode_label(state, summary);
	const Atom difficulty_label = summary_difficulty_label(state, summary);
	lines.push_back(gd::str(gd::format(state, key::mode_s_difficulty_s, {gd::str(mode_label), gd::str(difficulty_label)})));

	const Atom campaign_name = string_of(state, summary, key::campaign_name, key::empty);
	const Atom chapter_label = string_of(state, summary, key::chapter_label, key::empty);
	if (campaign_name != key::empty && chapter_label != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::campaign_s_s, {gd::str(campaign_name), gd::str(chapter_label)})));
	} else if (campaign_name != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::campaign_s, {gd::str(campaign_name)})));
	} else if (chapter_label != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::chapter_s, {gd::str(chapter_label)})));
	}

	const Atom hero_name = string_of(state, summary, key::hero_name, key::empty);
	const Atom hero_id = string_of(state, summary, key::hero_id, key::empty);
	if (hero_name != key::empty && hero_id != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::hero_s_s, {gd::str(hero_name), gd::str(hero_id)})));
	} else if (hero_name != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::hero_s, {gd::str(hero_name)})));
	} else if (hero_id != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::hero_s, {gd::str(hero_id)})));
	}
	const Atom hero_specialties_summary = string_of(state, summary, key::hero_specialties_summary, key::empty);
	if (hero_specialties_summary != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::specialties_s, {gd::str(hero_specialties_summary)})));
	}
	const Atom battle_name = string_of(state, summary, key::battle_name, key::empty);
	if (battle_name != key::empty && string_of(state, summary, key::resume_target, key::empty) == key::battle) {
		lines.push_back(gd::str(gd::format(state, key::battle_s, {gd::str(battle_name)})));
	}

	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		lines.push_back(gd::str(gd::format(state, key::day_d_2, {gd::int_value(day)})));
	}
	lines.push_back(gd::str(gd::format(state, key::resume_target_s, {gd::str(_resume_context_label(state, summary))})));
	const Atom scenario_summary = string_of(state, summary, key::scenario_summary, key::empty);
	if (scenario_summary != key::empty) {
		lines.push_back(gd::str(gd::format(state, key::recent_result_s, {gd::str(scenario_summary)})));
	}
	lines.push_back(gd::str(gd::format(state, key::integrity_s, {gd::str(_validity_label(state, string_of(state, summary, key::validity, key::missing)))})));
	lines.push_back(gd::str(gd::format(state, key::load_state_s, {gd::str(_resume_target_label(state, summary))})));

	if (!gd::bool_field(state, summary, key::valid, false)) {
		lines.push_back(gd::str(gd::format(state, key::status_s, {gd::str(string_of(state, summary, key::status_text, key::Unavailable))})));
		Value invalid_warnings;
		if (state.lookup(summary, gd::str(key::warnings), invalid_warnings) && invalid_warnings.kind == Kind::Array && state.array_size(invalid_warnings.ref) > 0) {
			lines.push_back(gd::str(gd::format(state, key::notes_s, {gd::str(join_array(state, key::semicolon_space, invalid_warnings.ref))})));
		}
		return join(state, key::newline, lines);
	}

	lines.push_back(gd::str(gd::format(state, key::scenario_status_s, {gd::str(_humanize_label(state, string_of(state, summary, key::scenario_status, key::in_progress)))})));
	lines.push_back(gd::str(gd::format(state, key::scene_state_s, {gd::str(_humanize_label(state, string_of(state, summary, key::game_state, key::overworld)))})));
	lines.push_back(gd::str(gd::format(state, key::resume_s, {gd::str(string_of(state, summary, key::status_text, key::Unavailable))})));
	const bool use_trusted_context = trusted_normalized_session.kind != Kind::Nil && !gd::is_empty(state, recap_context);
	const Atom resume_recap = use_trusted_context
			? _session_save_resume_recap_from_context(state, trusted_normalized_session, summary, recap_context)
			: describe_summary_resume_recap(state, summary);
	if (resume_recap != key::empty) {
		lines.push_back(gd::str(resume_recap));
	}
	const ArrayRef continuity_lines = use_trusted_context
			? _summary_continuity_lines_from_context(state, summary, recap_context)
			: _summary_continuity_lines(state, summary);
	const int64_t continuity_count = state.array_size(continuity_lines);
	for (int64_t index = 0; index < continuity_count; ++index) {
		lines.push_back(state.at(continuity_lines, index));
	}
	const Atom resolved_progress_recap = use_trusted_context ? progress_recap : _summary_progress_recap(state, summary);
	if (resolved_progress_recap != key::empty) {
		lines.push_back(gd::str(resolved_progress_recap));
	}

	Value warnings;
	if (state.lookup(summary, gd::str(key::warnings), warnings) && warnings.kind == Kind::Array && state.array_size(warnings.ref) > 0) {
		lines.push_back(gd::str(gd::format(state, key::notes_s, {gd::str(join_array(state, key::semicolon_space, warnings.ref))})));
	}

	return join(state, key::newline, lines);
}

Atom format_modified_timestamp(State &state, int64_t timestamp) {
	if (timestamp <= 0) {
		return key::empty;
	}
	const DictRef datetime = gd::as_dict(gd::call_method(state, gd::engine_singleton(state, key::Time), key::get_datetime_dict_from_unix_time, {gd::int_value(timestamp)}));
	if (gd::is_empty(state, datetime)) {
		return gd::stringify(state, gd::int_value(timestamp));
	}
	return gd::engine_format(state, key::n04d_02d_02d_02d_02d, {
			gd::int_value(gd::int_field(state, datetime, key::year, 0)),
			gd::int_value(gd::int_field(state, datetime, key::month, 0)),
			gd::int_value(gd::int_field(state, datetime, key::day, 0)),
			gd::int_value(gd::int_field(state, datetime, key::hour, 0)),
			gd::int_value(gd::int_field(state, datetime, key::minute, 0)),
	});
}

Atom _slot_path(State &state, int64_t slot) {
	return gd::format(state, key::s_s_d_json, {gd::str(key::user_saves), gd::str(key::slot), gd::int_value(_normalize_manual_slot(state, slot))});
}

Atom _autosave_path(State &state) {
	return gd::format(state, key::s_s_9, {gd::str(key::user_saves), gd::str(key::autosave_json)});
}

Atom _progression_path(State &state) {
	return gd::format(state, key::s_s_9, {gd::str(key::user_saves), gd::str(key::campaign_progression_json)});
}

DictRef _deletable_slot_identity(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return state.new_dict();
	}
	const Atom slot_type = string_of(state, summary, key::slot_type, key::empty);
	const Atom slot_id = string_of(state, summary, key::slot_id, key::empty);
	if (slot_type == key::file) {
		const DictRef identity = save_file_identity(state, slot_id);
		return gd::bool_field(state, identity, key::ok, false) ? identity : state.new_dict();
	}
	if (slot_type == key::autosave && slot_id == key::autosave) {
		const DictRef identity = state.new_dict();
		put(state, identity, key::slot_type, gd::str(key::autosave));
		put(state, identity, key::slot_id, gd::str(key::autosave));
		put(state, identity, key::path, gd::str(_autosave_path(state)));
		return identity;
	}
	if (slot_type != key::manual || !gd::is_valid_int(state, slot_id)) {
		return state.new_dict();
	}
	const int64_t manual_slot = gd::to_int(state, gd::str(slot_id));
	if (manual_slot < kFirstManualSlot || manual_slot > kLastManualSlot || gd::stringify(state, gd::int_value(manual_slot)) != slot_id) {
		return state.new_dict();
	}
	const DictRef identity = state.new_dict();
	put(state, identity, key::slot_type, gd::str(key::manual));
	put(state, identity, key::slot_id, gd::str(gd::stringify(state, gd::int_value(manual_slot))));
	put(state, identity, key::path, gd::str(_slot_path(state, manual_slot)));
	return identity;
}

DictRef _summary_for_slot_identity(State &state, DictRef identity) {
	const Atom slot_type = string_of(state, identity, key::slot_type, key::empty);
	if (slot_type == key::file) {
		return inspect_save_file(state, string_of(state, identity, key::slot_id, key::empty));
	}
	if (slot_type == key::autosave) {
		return inspect_autosave(state);
	}
	if (slot_type == key::manual) {
		return inspect_manual_slot(state, gd::int_field(state, identity, key::slot_id, kFirstManualSlot));
	}
	return state.new_dict();
}

bool _ensure_save_dir(State &state) {
	const Atom absolute_path = gd::to_string(gd::call_method(state, gd::engine_singleton(state, key::ProjectSettings), key::globalize_path, {gd::str(key::user_saves)}));
	const int64_t error = gd::to_int(state, gd::class_call_static(state, key::DirAccess, key::make_dir_recursive_absolute, {gd::str(absolute_path)}));
	if (error != kOk && error != kErrAlreadyExists) {
		state.print_error(state.text(gd::format(state, key::unable_to_create_save_directory_s, {gd::str(absolute_path)})));
		return false;
	}
	return true;
}

Atom _save_payload(State &state, DictRef payload, Atom file_path, Atom slot_type, DictRef saved_payload_out, DictRef profile, bool payload_is_prepared) {
	const int64_t recovery_started = profile_begin_usec(state);
	DictRef recovery = _verified_cached_manual_save_recovery(state, file_path, slot_type);
	if (gd::is_empty(state, recovery)) {
		recovery = _verified_receipt_recovery(state, file_path);
	}
	const bool recovery_cache_hit = !gd::is_empty(state, recovery);
	if (!recovery_cache_hit) {
		recovery = _recover_save_transaction(state, file_path, false);
	}
	_runtime_save_profile_bucket(state, profile, key::recovery, profile_elapsed_ms(state, recovery_started));
	if (!gd::is_empty(state, profile)) {
		profile_add(state, profile, key::recovery_count, 1);
		put(state, profile, key::recovery_parse_count, gd::int_value(recovery_cache_hit ? 0 : 1));
		put(state, profile, key::recovery_cache_hit, gd::bool_value(recovery_cache_hit));
		put(state, profile, key::recovery_reason, gd::str(string_of(state, recovery, key::reason, key::verified_live)));
	}
	const int64_t normalize_started = profile_begin_usec(state);
	Atom retained_manual_name = key::empty;
	if (slot_type == key::manual && gd::bool_field(state, recovery, key::live_valid, false)) {
		retained_manual_name = string_of(state, recovery, key::retained_manual_name, key::empty);
	}
	const DictRef normalized = payload_is_prepared ? payload : session_state_store::normalize_payload(state, gd::dict_value(payload));
	put(state, normalized, key::save_version, gd::int_value(session_state_store::kSaveVersion));
	put(state, normalized, key::saved_at_unix, gd::float_value(gd::engine_unix_time(state)));
	put(state, normalized, key::save_slot_type, gd::str(slot_type));
	put(state, normalized, key::saved_from_game_state, gd::str(string_of(state, normalized, key::game_state, key::overworld)));
	put(state, normalized, key::saved_from_scenario_status, gd::str(string_of(state, normalized, key::scenario_status, key::in_progress)));
	put(state, normalized, key::saved_from_launch_mode, gd::str(string_of(state, normalized, key::launch_mode, key::campaign)));
	if (retained_manual_name != key::empty) {
		put(state, normalized, key::manual_slot_name, gd::str(retained_manual_name));
	}
	_runtime_save_profile_bucket(state, profile, key::save_normalize, profile_elapsed_ms(state, normalize_started));
	if (!gd::is_empty(state, profile)) {
		put(state, profile, key::save_normalize_skipped, gd::bool_value(payload_is_prepared));
		if (payload_is_prepared && gd::bool_field(state, profile, key::trusted_live_payload, false)) {
			put(state, profile, key::save_normalize_skip_reason, gd::str(key::trusted_live_normalized_autosave));
		} else if (payload_is_prepared) {
			put(state, profile, key::save_normalize_skip_reason, gd::str(key::prepared_normalized_manual_payload));
		} else {
			put(state, profile, key::save_normalize_skip_reason, gd::str(key::empty));
		}
	}
	dict_clear(state, saved_payload_out);
	const ArrayRef keys = gd::keys(state, normalized);
	const int64_t key_count = state.array_size(keys);
	for (int64_t index = 0; index < key_count; ++index) {
		const Value held = state.at(keys, index);
		state.set(saved_payload_out, held, gd::index(state, normalized, held));
	}
	const DictRef stored = session_state_store::payload_for_storage(state, normalized);
	return _save_raw_dictionary(state, stored, file_path, profile, recovery);
}

} // namespace aurelion::rules::port::save_service
