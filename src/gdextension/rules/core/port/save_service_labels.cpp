// SaveService's labels: player text, slot names, badges, tooltips, resume
// targets and the save's structure report.

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <cstdint>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// SaveService's constants.
constexpr Atom kSlotTypeFile = key::file;
constexpr Atom kSlotTypeAutosave = key::autosave;
constexpr Atom kSaveMetadataTimestampKey = key::saved_at_unix;
constexpr Atom kSaveMetadataSlotTypeKey = key::save_slot_type;
constexpr Atom kSaveMetadataManualNameKey = key::manual_slot_name;
constexpr int64_t kManualSlotNameMaxLength = 32;
constexpr int64_t kManualSlotIds[] = {1, 2, 3};
constexpr Atom kMainMenuActionLabel = key::main_menu;

// String(x): str() of the engine for a float or a container.
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
Atom text_field(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// session.<field> of a String field of the session's view.
Atom session_string(State &state, DictRef view, Atom field) {
	return gd::to_string(gd::index(state, view, gd::str(field)));
}

// session.flags.
DictRef session_flags(State &state, DictRef view) {
	return gd::as_dict(gd::index(state, view, gd::str(key::flags)));
}

// s.length(): the code points of the UTF-8.
int64_t code_point_count(const std::string &text) {
	int64_t count = 0;
	for (const char c : text) {
		if ((static_cast<unsigned char>(c) & 0xC0u) != 0x80u) {
			++count;
		}
	}
	return count;
}

// s.left(count) (String::left).
Atom left(State &state, Atom atom, int32_t count) {
	const std::string text = state.text(atom);
	const int64_t length = code_point_count(text);
	int64_t wanted = count;
	if (wanted < 0) {
		wanted = length + wanted;
	}
	if (wanted <= 0) {
		return key::empty;
	}
	if (wanted >= length) {
		return atom;
	}
	size_t end = 0;
	int64_t seen = 0;
	while (end < text.size()) {
		if ((static_cast<unsigned char>(text[end]) & 0xC0u) != 0x80u) {
			if (seen == wanted) {
				break;
			}
			++seen;
		}
		++end;
	}
	return state.intern(text.substr(0, end));
}

// while text.find("  ") >= 0: text = text.replace("  ", " ")
Atom collapse_double_spaces(State &state, Atom text) {
	while (state.text(text).find("  ") != std::string::npos) {
		text = gd::replace(state, text, key::text_3, key::space);
	}
	return text;
}

// text.split("\n", false): the non-empty pieces, in order.
std::vector<Atom> split_lines(State &state, Atom text) {
	const std::string source = state.text(text);
	std::vector<Atom> pieces;
	size_t from = 0;
	while (true) {
		size_t end = source.find('\n', from);
		if (end == std::string::npos) {
			end = source.size();
		}
		if (end > from) {
			pieces.push_back(state.intern(source.substr(from, end - from)));
		}
		if (end == source.size()) {
			break;
		}
		from = end + 1;
	}
	return pieces;
}

// "\n".join(lines) of an Array of Strings.
Atom join_lines(State &state, const std::vector<Atom> &lines) {
	std::string joined;
	for (size_t index = 0; index < lines.size(); ++index) {
		if (index != 0) {
			joined += '\n';
		}
		joined += state.text(lines[index]);
	}
	return state.intern(joined);
}

// separator.join(array): each item as String() converts it.
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::string joined;
	const int64_t size = state.array_size(array);
	for (int64_t index = 0; index < size; ++index) {
		if (index != 0) {
			joined += state.text(separator);
		}
		joined += state.text(string_of(state, state.at(array, index)));
	}
	return state.intern(joined);
}

// {"ok": ok, "name": name, "message": message}
DictRef name_check(State &state, bool ok, Atom name, Atom message) {
	const DictRef check = state.new_dict();
	state.set(check, gd::str(key::ok), gd::bool_value(ok));
	state.set(check, gd::str(key::name), gd::str(name));
	state.set(check, gd::str(key::message), gd::str(message));
	return check;
}

// {"resume_target": current_target, "valid": true, "loadable": true, "payload": {"scenario_id": "active"}}
DictRef continue_probe(State &state, Atom current_target) {
	const DictRef payload = state.new_dict();
	state.set(payload, gd::str(key::scenario_id), gd::str(key::active));
	const DictRef probe = state.new_dict();
	state.set(probe, gd::str(key::resume_target), gd::str(current_target));
	state.set(probe, gd::str(key::valid), gd::bool_value(true));
	state.set(probe, gd::str(key::loadable), gd::bool_value(true));
	state.set(probe, gd::str(key::payload), gd::dict_value(payload));
	return probe;
}

// {"ok": false, "validity": "invalid_payload", "message": message, "warnings": warnings}
DictRef invalid_structure(State &state, Atom message, ArrayRef warnings) {
	const DictRef report = state.new_dict();
	state.set(report, gd::str(key::ok), gd::bool_value(false));
	state.set(report, gd::str(key::validity), gd::str(key::invalid_payload));
	state.set(report, gd::str(key::message), gd::str(message));
	state.set(report, gd::str(key::warnings), gd::array_value(warnings));
	return report;
}

} // namespace

namespace save_service {

Atom _battle_aftermath_summary(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return key::empty;
	}
	const DictRef flags = session_flags(state, gd::object_view(state, session));
	Value report;
	// A missing report is {}: each of its lines is "".
	if (!state.lookup(flags, gd::str(key::last_battle_aftermath), report)) {
		return key::empty;
	}
	if (!gd::is_dict(report)) {
		return key::empty;
	}
	for (const Atom field : {key::return_summary, key::result_summary, key::reward_summary, key::world_summary, key::summary}) {
		const Atom line = _safe_player_text(state, text_field(state, report.ref, field, key::empty), 220);
		if (line != key::empty) {
			return line;
		}
	}
	return key::empty;
}

Atom _safe_player_text(State &state, Atom value, int64_t max_chars) {
	Atom text = gd::replace(state, gd::strip_edges(state, value), key::newline, key::space);
	text = collapse_double_spaces(state, text);
	if (_contains_blocked_debug_token(state, text)) {
		return key::empty;
	}
	if (code_point_count(state.text(text)) <= max_chars) {
		return text;
	}
	// max(1, max_chars - 3), passed to left()'s 32-bit int.
	const int64_t shortened = gd::sub(max_chars, 3);
	const int64_t count = 1 < shortened ? shortened : 1;
	const Atom kept = gd::strip_edges(state, left(state, text, static_cast<int32_t>(count)));
	return gd::format(state, key::s_5, {gd::str(kept)});
}

bool _contains_blocked_debug_token(State &state, Atom text) {
	// text.to_lower(): outside ASCII only U+0130 lowers to an ASCII letter ("i")
	// and U+212A ("k"); every other character stays outside ASCII, where no
	// token can match, so its bytes are kept as they are.
	const std::string &source = state.text(text);
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
		if (c == 0xE2 && index + 2 < source.size() && static_cast<unsigned char>(source[index + 1]) == 0x84 && static_cast<unsigned char>(source[index + 2]) == 0xAA) {
			normalized += 'k';
			index += 2;
			continue;
		}
		normalized += static_cast<char>(c);
	}
	static const char *const kTokens[] = {
		"final_priority",
		"base_value",
		"resource_affinity_value",
		"weighted_claim_value",
		"weighted_income_value",
		"assignment_penalty",
		"final_score",
		"income_value",
		"growth_value",
		"pressure_value",
		"category_bonus",
		"raid_score",
		"debug_reason",
		"raid_target_weights",
		"ai_score",
		"weight",
	};
	for (const char *token : kTokens) {
		if (normalized.find(token) != std::string::npos) {
			return true;
		}
	}
	return false;
}

Atom _line_with_prefix(State &state, Atom text, Atom prefix) {
	for (const Atom raw_line : split_lines(state, text)) {
		const Atom line = gd::strip_edges(state, raw_line);
		if (gd::begins_with(state, line, prefix)) {
			return line;
		}
	}
	return key::empty;
}

Atom _first_meaningful_line(State &state, Atom text, ArrayRef ignored_lines) {
	for (const Atom raw_line : split_lines(state, text)) {
		const Atom line = gd::strip_edges(state, raw_line);
		if (line == key::empty) {
			continue;
		}
		const Atom normalized = gd::strip_edges(state, gd::trim_prefix(state, line, key::text_2));
		if (gd::array_has(state, ignored_lines, gd::str(normalized))) {
			continue;
		}
		return normalized;
	}
	return key::empty;
}

Atom _slot_label(State &state, DictRef summary) {
	if (text_field(state, summary, key::slot_type, key::empty) == kSlotTypeFile) {
		return text_field(state, summary, key::slot_id, key::empty);
	}
	if (text_field(state, summary, key::slot_type, key::empty) == kSlotTypeAutosave) {
		return key::Autosave;
	}
	const Atom manual_name = gd::strip_edges(state, text_field(state, summary, key::manual_slot_name, key::empty));
	if (manual_name != key::empty) {
		return gd::format(state, key::s_manual_s, {gd::str(manual_name), gd::str(text_field(state, summary, key::slot_id, key::n1))});
	}
	return gd::format(state, key::manual_s, {gd::str(text_field(state, summary, key::slot_id, key::n1))});
}

Atom _manual_slot_name_from_payload(State &state, DictRef payload) {
	const DictRef check = _validate_manual_slot_name(state, text_field(state, payload, kSaveMetadataManualNameKey, key::empty));
	return gd::bool_field(state, check, key::ok, false) ? text_field(state, check, key::name, key::empty) : key::empty;
}

DictRef _validate_manual_slot_name(State &state, Atom value) {
	Atom normalized = gd::strip_edges(state, value);
	normalized = gd::replace(state, normalized, key::text_4, key::space);
	normalized = gd::replace(state, normalized, key::newline, key::space);
	normalized = gd::replace(state, normalized, key::tab, key::space);
	normalized = collapse_double_spaces(state, normalized);
	if (code_point_count(state.text(normalized)) > kManualSlotNameMaxLength) {
		return name_check(state, false, key::empty, gd::format(state, key::save_names_can_use_at_most, {gd::int_value(kManualSlotNameMaxLength)}));
	}
	// unicode_at(index) < 32: those code points are single bytes in UTF-8.
	for (const char c : state.text(normalized)) {
		if (static_cast<unsigned char>(c) < 32) {
			return name_check(state, false, key::empty, key::save_names_cannot_contain_control_characters);
		}
	}
	return name_check(state, true, normalized, key::empty);
}

Atom _summary_status_badge(State &state, DictRef summary) {
	if (!gd::bool_field(state, summary, key::valid, false)) {
		return key::Blocked;
	}
	if (text_field(state, summary, key::resume_target, key::overworld) == key::outcome) {
		return key::Outcome;
	}
	const Atom validity = text_field(state, summary, key::validity, key::ok);
	if (validity == key::degraded) {
		return key::Recovered;
	}
	if (validity == key::legacy) {
		return key::Legacy;
	}
	return key::Ready;
}

Atom _runtime_save_message(State &state, Atom slot_type, DictRef summary) {
	if (slot_type == kSlotTypeAutosave) {
		const Atom brief = describe_resume_brief(state, summary);
		const Atom hint = _main_menu_continue_hint(state, summary);
		return gd::format(state, key::autosaved_s_s, {gd::str(brief), gd::str(hint)});
	}
	const Atom label = _slot_label(state, summary);
	const Atom brief = describe_resume_brief(state, summary);
	const Atom hint = _main_menu_continue_hint(state, summary);
	return gd::format(state, key::saved_s_s_s, {gd::str(label), gd::str(brief), gd::str(hint)});
}

Atom _main_menu_continue_hint(State &state, DictRef summary) {
	if (gd::is_empty(state, summary) || !can_load_summary(state, summary)) {
		return key::main_menu_continue_is_unavailable_for;
	}
	const Atom target = text_field(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		const Atom battle_context = _resume_context_label(state, summary);
		if (battle_context != key::Battle) {
			return gd::format(state, key::continue_latest_will_resume_s, {gd::str(battle_context)});
		}
		return key::continue_latest_will_resume_the_active;
	}
	if (target == key::town) {
		return gd::format(state, key::continue_latest_will_resume_s, {gd::str(_resume_context_label(state, summary))});
	}
	if (target == key::outcome) {
		return gd::format(state, key::continue_latest_will_review_s, {gd::str(_resume_context_label(state, summary))});
	}
	if (target == key::overworld) {
		return gd::format(state, key::continue_latest_will_resume_s, {gd::str(_resume_context_label(state, summary))});
	}
	return key::this_snapshot_cannot_be_resumed_safely;
}

Atom _resume_target_noun(State &state, Atom target) {
	(void)state;
	if (target == key::battle) {
		return key::battle;
	}
	if (target == key::town) {
		return key::town;
	}
	if (target == key::outcome) {
		return key::outcome;
	}
	return key::expedition;
}

Atom _return_to_menu_label(State &state, Atom current_target, const Value &session) {
	(void)current_target;
	if (session.kind != Kind::Nil && gd::bool_field(state, session_flags(state, gd::object_view(state, session)), key::editor_working_copy, false)) {
		return key::Editor;
	}
	return kMainMenuActionLabel;
}

Atom _in_session_save_label(State &state, Atom current_target, int64_t selected_slot) {
	if (current_target == key::battle) {
		return gd::format(state, key::save_battle_to_manual_d, {gd::int_value(selected_slot)});
	}
	if (current_target == key::town) {
		return gd::format(state, key::save_town_to_manual_d, {gd::int_value(selected_slot)});
	}
	if (current_target == key::outcome) {
		return gd::format(state, key::save_outcome_to_manual_d, {gd::int_value(selected_slot)});
	}
	return gd::format(state, key::save_expedition_to_manual_d, {gd::int_value(selected_slot)});
}

Atom _in_session_save_tooltip(State &state, Atom current_target, DictRef slot_summary, Atom current_context) {
	const Atom written = current_context != key::empty
			? current_context
			: gd::format(state, key::a_safe_s_snapshot, {gd::str(_resume_target_noun(state, current_target))});
	const Atom slot_label = _slot_label(state, slot_summary);
	std::vector<Atom> lines;
	lines.push_back(gd::format(state, key::write_s_into_s, {gd::str(written), gd::str(slot_label)}));
	lines.push_back(_main_menu_continue_hint(state, continue_probe(state, current_target)));
	const Atom existing_status = text_field(state, slot_summary, key::status_text, key::empty);
	if (existing_status != key::empty) {
		lines.push_back(gd::format(state, key::current_slot_s, {gd::str(existing_status)}));
	}
	return join_lines(state, lines);
}

Atom _latest_context_line(State &state, DictRef latest_summary, Atom current_target) {
	if (gd::is_empty(state, latest_summary) || !can_load_summary(state, latest_summary)) {
		return key::latest_ready_save_none;
	}
	Atom prefix = key::latest_ready;
	if (current_target != key::empty && text_field(state, latest_summary, key::resume_target, key::empty) == current_target) {
		prefix = gd::format(state, key::latest_ready_s_snapshot, {gd::str(_resume_target_noun(state, current_target))});
	}
	const Atom slot_label = _slot_label(state, latest_summary);
	const Atom brief = describe_resume_brief(state, latest_summary);
	const Atom modified = format_modified_timestamp(state, compat::float_to_int(_summary_sort_timestamp(state, latest_summary)));
	return gd::format(state, key::s_s_s_s_3, {gd::str(prefix), gd::str(slot_label), gd::str(brief), gd::str(modified)});
}

Atom _return_to_menu_tooltip(State &state, Atom current_target, DictRef latest_summary, Atom current_context, Atom return_handoff) {
	const Atom refreshed = current_context != key::empty
			? current_context
			: gd::format(state, key::this_s_state, {gd::str(_resume_target_noun(state, current_target))});
	std::vector<Atom> lines;
	lines.push_back(gd::format(state, key::return_to_the_main_menu_after, {gd::str(refreshed)}));
	if (return_handoff != key::empty) {
		lines.push_back(return_handoff);
	}
	if (gd::is_empty(state, latest_summary)) {
		lines.push_back(key::a_fresh_autosave_will_become_the);
	} else {
		lines.push_back(_main_menu_continue_hint(state, continue_probe(state, current_target)));
		lines.push_back(gd::format(state, key::latest_before_return_s, {gd::str(_slot_label(state, latest_summary))}));
	}
	return join_lines(state, lines);
}

Atom _resume_preserved_context(State &state, DictRef summary) {
	const Atom target = text_field(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		return key::round_order_active_stack_selected_target;
	}
	if (target == key::town) {
		return key::build_recruit_spell_town_defense_and;
	}
	if (target == key::outcome) {
		return key::scenario_result_progress_recap_and_follow;
	}
	if (target == key::overworld) {
		return key::hero_position_movement_map_control_resources;
	}
	return key::available_expedition_state;
}

Atom _resume_target_label(State &state, DictRef summary) {
	const Atom target = text_field(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		return key::battle_resume;
	}
	if (target == key::town) {
		return key::town_resume;
	}
	if (target == key::outcome) {
		return key::outcome_review;
	}
	if (target == key::overworld) {
		return key::overworld_resume;
	}
	return key::Blocked;
}

Atom _resume_context_label(State &state, DictRef summary) {
	const Atom location = gd::strip_edges(state, text_field(state, summary, key::resume_location, key::empty));
	const Atom target = text_field(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		return location != key::empty ? gd::format(state, key::battle_s, {gd::str(location)}) : key::Battle;
	}
	if (target == key::town) {
		return location != key::empty ? gd::format(state, key::town_s_2, {gd::str(location)}) : key::Town;
	}
	if (target == key::outcome) {
		const Atom result = _humanize_label(state, text_field(state, summary, key::scenario_status, key::outcome));
		return result != key::empty ? gd::format(state, key::outcome_s, {gd::str(result)}) : key::Outcome;
	}
	if (target == key::overworld) {
		return location != key::empty ? location : key::Overworld;
	}
	return key::Blocked;
}

Atom _status_text_for_summary(State &state, DictRef summary) {
	if (!gd::bool_field(state, summary, key::valid, false)) {
		return text_field(state, summary, key::status_text, key::Unavailable);
	}
	const Atom target = text_field(state, summary, key::resume_target, key::blocked);
	if (target == key::battle) {
		const Atom battle_context = _resume_context_label(state, summary);
		if (battle_context != key::Battle) {
			return gd::format(state, key::ready_to_resume_s, {gd::str(battle_context)});
		}
		return key::ready_to_resume_the_active_battle;
	}
	if (target == key::town) {
		return gd::format(state, key::ready_to_resume_s, {gd::str(_resume_context_label(state, summary))});
	}
	if (target == key::outcome) {
		return gd::format(state, key::s_is_ready_to_review, {gd::str(_resume_context_label(state, summary))});
	}
	if (target == key::overworld) {
		const Atom validity = text_field(state, summary, key::validity, key::ok);
		if (validity == key::degraded) {
			return gd::format(state, key::recovered_s_is_ready_to_resume, {gd::str(_resume_context_label(state, summary))});
		}
		if (validity == key::legacy) {
			return gd::format(state, key::legacy_s_is_ready_to_resume, {gd::str(_resume_context_label(state, summary))});
		}
		return gd::format(state, key::ready_to_resume_s, {gd::str(_resume_context_label(state, summary))});
	}
	return key::this_save_cannot_be_loaded;
}

int64_t _normalize_manual_slot(State &state, int64_t slot) {
	(void)state;
	for (const int64_t slot_id : kManualSlotIds) {
		if (slot_id == slot) {
			return slot;
		}
	}
	return kManualSlotIds[0];
}

Atom _resume_target_for_session(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return key::blocked;
	}
	const DictRef view = gd::object_view(state, session);
	if (session_string(state, view, key::scenario_id) == key::empty) {
		return key::blocked;
	}
	if (session_string(state, view, key::scenario_status) != key::in_progress) {
		return key::outcome;
	}
	if (!gd::is_empty(state, gd::as_dict(gd::index(state, view, gd::str(key::battle)))) && battle_rules::battle_payload_can_resume(state, session)) {
		return key::battle;
	}
	if (string_of(state, gd::index(state, view, gd::str(key::game_state))) == key::town) {
		if (town_rules::can_visit_active_town(state, gd::object_view(state, session))) {
			return key::town;
		}
	}
	return key::overworld;
}

int64_t _recorded_timestamp_from_payload(State &state, DictRef payload, int64_t fallback) {
	// max(0, int(...)) and max(0, fallback).
	const int64_t raw = gd::to_int(state, gd::field_or(state, payload, kSaveMetadataTimestampKey, gd::int_value(0)));
	const int64_t recorded = 0 < raw ? raw : 0;
	if (recorded > 0) {
		return recorded;
	}
	return 0 < fallback ? fallback : 0;
}

double _recorded_timestamp_precise_from_payload(State &state, DictRef payload) {
	return compat::engine_max(0.0, gd::to_float(gd::field_or(state, payload, kSaveMetadataTimestampKey, gd::float_value(0.0))));
}

DictRef _payload_structure_report(State &state, DictRef payload, Atom slot_type) {
	const ArrayRef warnings = state.new_array();
	Atom validity = key::ok;
	const Atom scenario_id = text_field(state, payload, key::scenario_id, key::empty);
	if (scenario_id == key::empty) {
		return invalid_structure(state, key::missing_scenario_id, warnings);
	}

	Value overworld;
	// A missing overworld is {}, which is empty.
	if (!state.lookup(payload, gd::str(key::overworld), overworld) || !gd::is_dict(overworld) || gd::is_empty(state, overworld.ref)) {
		return invalid_structure(state, key::missing_overworld_expedition_state, warnings);
	}
	if (!_has_core_overworld_state(state, overworld.ref)) {
		return invalid_structure(state, key::the_save_is_missing_core_expedition, warnings);
	}

	if (!state.has(payload, gd::str(key::save_version))) {
		validity = key::legacy;
		state.append(warnings, gd::str(key::save_version_marker_was_missing_and));
	}
	if (!state.has(payload, gd::str(key::session_id)) || text_field(state, payload, key::session_id, key::empty) == key::empty) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::session_id_was_missing_and_a));
	}
	if (!state.has(payload, gd::str(key::hero_id)) || text_field(state, payload, key::hero_id, key::empty) == key::empty) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::commander_id_was_missing_and_will));
	}
	// payload.get("flags", {}) is Dictionary: a missing one is {}.
	Value flags;
	if (state.lookup(payload, gd::str(key::flags), flags) && !gd::is_dict(flags)) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::session_flags_were_missing_or_invalid));
	}

	const ArrayRef missing_overworld_fields = _missing_overworld_fields(state, overworld.ref);
	if (state.array_size(missing_overworld_fields) != 0) {
		validity = _degraded_validity(state, validity);
		const Atom joined = join_array(state, key::comma_space, missing_overworld_fields);
		state.append(warnings, gd::str(gd::format(state, key::overworld_save_fields_were_incomplete_s, {gd::str(joined)})));
	}

	const Atom raw_difficulty = text_field(state, payload, key::difficulty, key::empty);
	if (raw_difficulty == key::empty || scenario_select_rules::normalize_difficulty(state, gd::str(raw_difficulty)) != raw_difficulty) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::difficulty_metadata_was_missing_or_invalid));
	}
	const Atom raw_launch_mode = text_field(state, payload, key::launch_mode, key::empty);
	if (raw_launch_mode == key::empty || session_state_store::normalize_launch_mode(state, gd::str(raw_launch_mode)) != raw_launch_mode) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::launch_mode_metadata_was_missing_or));
	}
	// SessionStateStore.SUPPORTED_GAME_STATES and SUPPORTED_SCENARIO_STATUSES.
	const Atom raw_game_state = text_field(state, payload, key::game_state, key::empty);
	const bool supported_game_state = raw_game_state == key::overworld || raw_game_state == key::town || raw_game_state == key::battle || raw_game_state == key::outcome;
	if (raw_game_state == key::empty || !supported_game_state) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::scene_state_metadata_was_missing_or));
	}
	const Atom raw_scenario_status = text_field(state, payload, key::scenario_status, key::empty);
	const bool supported_status = raw_scenario_status == key::in_progress || raw_scenario_status == key::victory || raw_scenario_status == key::defeat;
	if (raw_scenario_status == key::empty || !supported_status) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::scenario_status_metadata_was_missing_or));
	}

	const Atom recorded_slot_type = text_field(state, payload, kSaveMetadataSlotTypeKey, key::empty);
	if (recorded_slot_type != key::empty && slot_type != key::empty && recorded_slot_type != slot_type) {
		validity = _degraded_validity(state, validity);
		state.append(warnings, gd::str(key::recorded_slot_metadata_no_longer_matches));
	}

	const DictRef report = state.new_dict();
	state.set(report, gd::str(key::ok), gd::bool_value(true));
	state.set(report, gd::str(key::validity), gd::str(validity));
	state.set(report, gd::str(key::warnings), gd::array_value(warnings));
	return report;
}

bool _has_core_overworld_state(State &state, DictRef overworld) {
	bool has_world_state = false;
	for (const Atom field : {key::resources, key::towns, key::encounters, key::map}) {
		if (state.has(overworld, gd::str(field))) {
			has_world_state = true;
			break;
		}
	}
	bool has_commander_state = false;
	for (const Atom field : {key::hero, key::player_heroes, key::hero_position, key::active_hero_id}) {
		if (state.has(overworld, gd::str(field))) {
			has_commander_state = true;
			break;
		}
	}
	return has_world_state && has_commander_state;
}

ArrayRef _missing_overworld_fields(State &state, DictRef overworld) {
	const ArrayRef missing = state.new_array();
	for (const Atom field : {key::resources, key::towns, key::resource_nodes, key::artifact_nodes, key::encounters, key::resolved_encounters, key::map, key::map_size}) {
		if (!state.has(overworld, gd::str(field))) {
			state.append(missing, gd::str(field));
		}
	}
	if (!state.has(overworld, gd::str(key::hero)) && !state.has(overworld, gd::str(key::player_heroes))) {
		state.append(missing, gd::str(key::hero_roster));
	}
	return missing;
}

Atom _degraded_validity(State &state, Atom current_validity) {
	(void)state;
	return current_validity == key::ok || current_validity == key::legacy ? key::degraded : current_validity;
}

Atom _humanize_label(State &state, Atom value) {
	return gd::capitalize(state, gd::replace(state, value, key::_, key::space));
}

Atom _validity_label(State &state, Atom validity) {
	if (validity == key::ok) {
		return key::Valid;
	}
	if (validity == key::legacy) {
		return key::legacy_save_normalized;
	}
	if (validity == key::degraded) {
		return key::recovered_with_fallback;
	}
	if (validity == key::missing) {
		return key::empty_slot_2;
	}
	if (validity == key::corrupt_json) {
		return key::corrupt_or_unreadable_json;
	}
	if (validity == key::invalid_payload) {
		return key::invalid_session_payload;
	}
	if (validity == key::missing_scenario) {
		return key::missing_scenario_content;
	}
	if (validity == key::newer_version) {
		return key::written_by_a_newer_build;
	}
	return _humanize_label(state, validity);
}

} // namespace save_service

} // namespace aurelion::rules::port
