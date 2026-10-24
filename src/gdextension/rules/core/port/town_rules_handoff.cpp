// TownRules for the town panels (Phase 7, slice 7.8): the event feed, the order
// ledger, recommendations, the action recap and the departure handoff.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <cstddef>
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
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// d.get(field, {}) and d.get(field, []) of a value that may be stored or
// passed on: the field, or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

void set_text(State &state, DictRef dict, Atom field, Atom value) {
	state.set(dict, str(field), str(value));
}

void set_int(State &state, DictRef dict, Atom field, int64_t value) {
	state.set(dict, str(field), int_value(value));
}

void set_bool(State &state, DictRef dict, Atom field, bool value) {
	state.set(dict, str(field), bool_value(value));
}

// sep.join(parts) of Strings.
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

// s.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string source = state.text(text);
	return state.intern(source.substr(0, source.size() - state.text(suffix).size()));
}

// s.length(): Godot's Strings count code points.
int64_t code_point_count(const std::string &text) {
	int64_t count = 0;
	for (const char c : text) {
		if ((static_cast<unsigned char>(c) & 0xC0u) != 0x80u) {
			++count;
		}
	}
	return count;
}

// s.left(count) for count > 0: the first count code points, all of them when
// there are fewer.
Atom left(State &state, Atom atom, int64_t count) {
	const std::string text = state.text(atom);
	int64_t seen = 0;
	for (size_t index = 0; index < text.size(); ++index) {
		if ((static_cast<unsigned char>(text[index]) & 0xC0u) != 0x80u) {
			if (seen == count) {
				return state.intern(text.substr(0, index));
			}
			++seen;
		}
	}
	return atom;
}

// s.to_lower() of text whose characters are ASCII, Latin-1 or general
// punctuation (U+2000 to U+206F, which has no case); other text throws, as the
// Unicode case tables are not ported.
Atom to_lower(State &state, Atom atom, const char *where) {
	const std::string text = state.text(atom);
	std::string lowered;
	lowered.reserve(text.size());
	for (size_t at = 0; at < text.size(); ++at) {
		const unsigned char c = static_cast<unsigned char>(text[at]);
		if (c < 0x80) {
			lowered += (c >= 'A' && c <= 'Z') ? static_cast<char>(c - 'A' + 'a') : static_cast<char>(c);
			continue;
		}
		if ((c == 0xC2 || c == 0xC3) && at + 1 < text.size()) {
			const unsigned char next = static_cast<unsigned char>(text[at + 1]);
			const unsigned code = ((c & 0x1Fu) << 6) | (next & 0x3Fu);
			// U+00C0 to U+00DE but U+00D7 lower by 0x20; the rest of Latin-1 stays.
			const unsigned lower_code = (code >= 0xC0 && code <= 0xDE && code != 0xD7) ? code + 0x20 : code;
			lowered += static_cast<char>(0xC0u | (lower_code >> 6));
			lowered += static_cast<char>(0x80u | (lower_code & 0x3Fu));
			at += 1;
			continue;
		}
		if (c == 0xE2 && at + 2 < text.size()) {
			const unsigned char second = static_cast<unsigned char>(text[at + 1]);
			if (second == 0x80 || second == 0x81) {
				lowered += text.substr(at, 3);
				at += 2;
				continue;
			}
		}
		throw state::NotPorted(std::string(where) + ": to_lower() of text outside ASCII, Latin-1 and punctuation");
	}
	return state.intern(lowered);
}

// s.split(delimiter, allow_empty) of a non-empty delimiter.
std::vector<Atom> split_text(State &state, Atom text, Atom delimiter, bool allow_empty) {
	const std::string source = state.text(text);
	const std::string separator = state.text(delimiter);
	std::vector<Atom> parts;
	size_t from = 0;
	while (true) {
		const size_t at = source.find(separator, from);
		const std::string piece = at == std::string::npos ? source.substr(from) : source.substr(from, at - from);
		if (allow_empty || !piece.empty()) {
			parts.push_back(state.intern(piece));
		}
		if (at == std::string::npos) {
			return parts;
		}
		from = at + separator.size();
	}
}

// a.sort() of an Array that holds only Strings (code point order).
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0.
bool logistics_alert(State &state, DictRef logistics) {
	return gd::int_field(state, logistics, key::disrupted_count, 0) > 0 || gd::int_field(state, logistics, key::threatened_count, 0) > 0;
}

} // namespace

namespace town_rules {

Atom describe_event_feed(State &state, DictRef session, Atom last_message, DictRef action_recap) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::town_dispatch_no_active_town;
	}
	const int64_t open_builds = state.array_size(get_build_actions(state, session));
	const int64_t open_recruits = state.array_size(get_recruit_actions(state, session));
	const int64_t open_study = state.array_size(get_spell_learning_actions(state, session));
	const Atom recap_text = text_or(state, action_recap, key::text, str(key::empty));
	Atom lead_line = recap_text;
	if (recap_text == key::empty) {
		lead_line = last_message != key::empty ? gd::format(state, key::latest_order_s, {str(last_message)}) : static_cast<Atom>(key::the_council_chamber_awaits_fresh_orders);
	}
	const Atom pressure_line = _pressure_brief(state, session, town);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const int64_t market_actions = state.array_size(get_market_actions(state, session));
	const int64_t response_actions = state.array_size(get_response_actions(state, session));
	const DictRef handoff = town_handoff_recap(state, session);
	std::vector<Atom> lines;
	lines.push_back(key::town_dispatch);
	lines.push_back(recap_text != key::empty ? lead_line : gd::format(state, key::dash_space_s, {str(text_or(state, handoff, key::visible_text, str(lead_line)))}));
	lines.push_back(gd::format(state, key::construction_d_recruitment_d_study_d, {int_value(open_builds), int_value(open_recruits), int_value(open_study)}));
	if (gd::bool_field(state, handoff, key::active, false)) {
		lines.push_back(gd::format(state, key::affected_s, {str(text_or(state, handoff, key::affected, str(key::empty)))}));
		lines.push_back(gd::format(state, key::why_it_matters_s, {str(text_or(state, handoff, key::why_it_matters, str(key::empty)))}));
		lines.push_back(gd::format(state, key::next_practical_action_s, {str(text_or(state, handoff, key::next_step_2, str(key::empty)))}));
	}
	if (pressure_line != key::empty) {
		lines.push_back(gd::format(state, key::dash_space_s, {str(pressure_line)}));
	}
	lines.push_back(gd::format(state, key::defense_readiness_s_2, {str(overworld_rules::describe_town_defense_readiness_warning(state, session, town))}));
	if (gd::bool_field(state, recovery, key::active, false)) {
		lines.push_back(gd::format(state, key::recovery_watch_s, {str(text_or(state, recovery, key::summary, str(key::empty)))}));
	} else if (logistics_alert(state, logistics)) {
		lines.push_back(gd::format(state, key::logistics_watch_s_2, {str(_logistics_watch_summary(state, logistics))}));
	}
	if (market_actions > 0) {
		lines.push_back(gd::format(state, key::exchange_orders_d, {int_value(market_actions)}));
	}
	if (response_actions > 0) {
		lines.push_back(gd::format(state, key::strategic_response_orders_d, {int_value(response_actions)}));
	}
	return join_atoms(state, key::newline, lines);
}

DictRef town_handoff_recap(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const DictRef result = state.new_dict();
		set_bool(state, result, key::active, false);
		set_text(state, result, key::visible_text, key::handoff_no_active_town);
		set_text(state, result, key::affected, key::empty);
		set_text(state, result, key::why_it_matters, key::empty);
		set_text(state, result, key::next_step_2, key::return_to_the_overworld);
		set_text(state, result, key::tooltip_text, key::town_handoff_no_active_town);
		return result;
	}
	const Atom town_name = _town_name(state, town);
	const DictRef front = overworld_rules::town_front_state(state, session, town, state.new_dict());
	const DictRef occupation = overworld_rules::town_occupation_state(state, session, town);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const ArrayRef response_actions = get_response_actions(state, session);
	const DictRef ready_response = _first_ready_action(state, response_actions);
	const DictRef movement = _active_hero_movement_state(state, session);
	const Atom affected = _town_handoff_affected_line(state, town_name, front, occupation, logistics, ready_response);
	const Atom why = _town_handoff_why_line(state, town, front, occupation, logistics, recovery, ready_response);
	const Atom next = _town_handoff_next_line(state, session, town, ready_response, movement);
	const Atom visible = gd::format(state, key::handoff_s_why_s_next_s, {
		str(_short_town_handoff_text(state, affected, 58)),
		str(_short_town_handoff_text(state, why, 70)),
		str(_short_town_handoff_text(state, next, 72)),
	});
	const Atom tooltip = gd::format(state, key::town_handoff_affected_s_why_it, {str(affected), str(why), str(next)});
	const DictRef result = state.new_dict();
	set_bool(state, result, key::active, true);
	set_text(state, result, key::town_name, town_name);
	set_text(state, result, key::affected, affected);
	set_text(state, result, key::why_it_matters, why);
	set_text(state, result, key::next_step_2, next);
	set_text(state, result, key::visible_text, visible);
	set_text(state, result, key::tooltip_text, tooltip);
	set_int(state, result, key::ready_response_action_count, !gd::is_empty(state, ready_response) ? 1 : 0);
	set_int(state, result, key::movement_current, gd::int_field(state, movement, key::current, 0));
	set_int(state, result, key::movement_max, gd::int_field(state, movement, key::max, 0));
	return result;
}

DictRef town_departure_confirmation(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const DictRef result = state.new_dict();
		set_bool(state, result, key::active, false);
		set_text(state, result, key::button_label, key::return_to_field);
		set_text(state, result, key::visible_text, key::ready_check_no_active_town);
		set_text(state, result, key::tooltip_text, key::departure_check_no_active_town);
		set_text(state, result, key::next_step_2, key::return_to_the_overworld);
		return result;
	}
	const DictRef handoff = town_handoff_recap(state, session);
	const DictRef movement = _active_hero_movement_state(state, session);
	const int64_t move_current = gd::int_field(state, movement, key::current, 0);
	const int64_t move_max = gd::int_field(state, movement, key::max, 0);
	const Atom recommendation = _town_recommendation_line(state, session, town);
	// The fallback is evaluated whether the handoff has a next step or not.
	const Atom next_fallback = _next_town_action_line(state, session, town);
	const Atom next_step = text_or(state, handoff, key::next_step_2, str(next_fallback));
	const Atom button_label = key::return_to_field;
	Atom visible_text = key::empty;
	if (gd::int_field(state, handoff, key::ready_response_action_count, 0) > 0) {
		visible_text = key::ready_check_response_order_is_open;
	} else if (move_current <= 0) {
		visible_text = key::ready_check_movement_is_spent_return;
	} else {
		visible_text = gd::format(state, key::ready_check_finish_town_orders_then, {int_value(move_current), int_value(move_max)});
	}
	const Atom tooltip = gd::format(state, key::departure_check_town_readiness_s_affected, {
		str(recommendation),
		str(text_or(state, handoff, key::affected, str(key::empty))),
		str(text_or(state, handoff, key::why_it_matters, str(key::empty))),
		str(next_step),
	});
	const DictRef result = state.new_dict();
	set_bool(state, result, key::active, true);
	set_text(state, result, key::button_label, button_label);
	set_text(state, result, key::visible_text, visible_text);
	set_text(state, result, key::tooltip_text, tooltip);
	set_text(state, result, key::town_readiness, recommendation);
	set_text(state, result, key::affected, text_or(state, handoff, key::affected, str(key::empty)));
	set_text(state, result, key::why_it_matters, text_or(state, handoff, key::why_it_matters, str(key::empty)));
	set_text(state, result, key::next_step_2, next_step);
	set_int(state, result, key::movement_current, move_current);
	set_int(state, result, key::movement_max, move_max);
	set_int(state, result, key::ready_response_action_count, gd::int_field(state, handoff, key::ready_response_action_count, 0));
	return result;
}

DictRef town_order_target_handoff(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const DictRef result = state.new_dict();
		set_bool(state, result, key::active, false);
		set_text(state, result, key::visible_text, key::order_target_no_active_town);
		set_text(state, result, key::tooltip_text, key::town_order_target_no_active_town);
		set_text(state, result, key::next_step_2, key::return_to_the_overworld);
		return result;
	}
	const DictRef action = _town_order_target_action(state, session, town);
	const DictRef departure = town_departure_confirmation(state, session);
	if (gd::is_empty(state, action)) {
		const Atom fallback_next = _next_town_action_line(state, session, town);
		const Atom fallback_visible = gd::format(state, key::order_target_no_open_order_next, {str(_short_town_handoff_text(state, fallback_next, 64))});
		const DictRef result = state.new_dict();
		set_bool(state, result, key::active, false);
		set_text(state, result, key::visible_text, fallback_visible);
		set_text(state, result, key::tooltip_text, gd::format(state, key::town_order_target_target_no_open, {
			str(fallback_next),
			str(text_or(state, departure, key::visible_text, str(key::empty))),
		}));
		set_text(state, result, key::next_step_2, fallback_next);
		return result;
	}
	const Atom lane = text_or(state, action, key::lane, str(key::order));
	const Atom label = _short_action_label(state, action, key::town_order);
	const Atom where = _town_order_ui_surface_for_lane(state, lane);
	const Atom readiness = _town_order_readiness_line(state, action, lane);
	const Atom impact = _town_order_impact_line(state, action, lane);
	const Atom next_step = _town_order_next_step(state, action, lane, label, where, readiness);
	const Atom visible = gd::format(state, key::order_target_s_s_s, {
		str(_short_town_handoff_text(state, label, 36)),
		str(_short_town_handoff_text(state, readiness, 34)),
		str(where),
	});
	const Atom tooltip = gd::format(state, key::town_order_target_target_s_lane, {
		str(label),
		str(_town_order_lane_label(state, lane)),
		str(where),
		str(readiness),
		str(impact),
		str(next_step),
		str(text_or(state, departure, key::visible_text, str(key::empty))),
	});
	const DictRef result = state.new_dict();
	set_bool(state, result, key::active, true);
	set_text(state, result, key::action_id, text_or(state, action, key::id, str(key::empty)));
	set_text(state, result, key::lane, lane);
	set_text(state, result, key::target_label, label);
	set_text(state, result, key::ui_surface, where);
	set_text(state, result, key::readiness, readiness);
	set_text(state, result, key::why_it_matters, impact);
	set_text(state, result, key::next_step_2, next_step);
	set_text(state, result, key::visible_text, visible);
	set_text(state, result, key::tooltip_text, tooltip);
	set_bool(state, result, key::disabled, gd::bool_field(state, action, key::disabled, false));
	return result;
}

DictRef town_action_consequence_signature(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const Value session_value = dict_value(session);
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef front = overworld_rules::town_front_state(state, session, town, state.new_dict());
	const DictRef recipient = hero_command_rules::town_recruitment_destination(state, session, town);
	// The literal's entries are evaluated in order.
	const DictRef result = state.new_dict();
	set_text(state, result, key::town_name, _town_name(state, town));
	set_text(state, result, key::recruitment_holder_id, gd::stringify(state, gd::index(state, recipient, str(key::holder_id))));
	set_text(state, result, key::recruitment_holder_label, gd::stringify(state, gd::index(state, recipient, str(key::label))));
	const DictRef holder_army = state.new_dict();
	state.set(holder_army, str(key::stacks), gd::index(state, recipient, str(key::stacks)));
	state.set(result, str(key::recruitment_holder_counts), dict_value(_army_unit_counts(state, dict_value(holder_army))));
	state.set(result, str(key::resources), dict_value(_duplicate_dictionary(state, field_or_new_dict(state, overworld, key::resources))));
	state.set(result, str(key::built_buildings), array_value(_normalize_string_array(state, field_or_new_array(state, town, key::built_buildings))));
	state.set(result, str(key::available_recruits), dict_value(_duplicate_dictionary(state, field_or_new_dict(state, town, key::available_recruits))));
	state.set(result, str(key::army_counts), dict_value(_army_unit_counts(state, field_or_new_dict(state, overworld, key::army))));
	state.set(result, str(key::income), dict_value(overworld_rules::town_income(state, town, session_value)));
	state.set(result, str(key::weekly_growth), dict_value(overworld_rules::town_weekly_growth(state, town, session_value)));
	set_int(state, result, key::battle_readiness, overworld_rules::town_battle_readiness(state, town, session_value));
	set_int(state, result, key::reinforcement_quality, overworld_rules::town_reinforcement_quality(state, town, session_value));
	set_int(state, result, key::pressure_output, overworld_rules::town_pressure_output(state, town, session_value));
	set_text(state, result, key::logistics_summary, text_or(state, logistics, key::summary, str(key::empty)));
	set_text(state, result, key::logistics_impact, text_or(state, logistics, key::impact_summary, str(key::empty)));
	set_text(state, result, key::recovery_summary, text_or(state, recovery, key::summary, str(key::empty)));
	set_text(state, result, key::front_summary, text_or(state, front, key::summary, str(key::empty)));
	set_bool(state, result, key::front_active, gd::bool_field(state, front, key::active, false));
	set_int(state, result, key::build_action_count, state.array_size(get_build_actions(state, session)));
	set_int(state, result, key::recruit_action_count, state.array_size(get_recruit_actions(state, session)));
	set_int(state, result, key::market_action_count, state.array_size(get_market_actions(state, session)));
	set_int(state, result, key::response_action_count, state.array_size(get_response_actions(state, session)));
	const DictRef hero = gd::as_dict(field_or_new_dict(state, overworld, key::hero));
	state.set(result, str(key::artifact_ids), array_value(artifact_rules::owned_artifact_ids(state, hero)));
	return result;
}

DictRef build_town_action_recap(State &state, DictRef session, Atom lane, Atom action_id, DictRef action, DictRef result, DictRef before, DictRef after_signature) {
	const Atom message = text_or(state, result, key::message, str(key::empty));
	if (!gd::bool_field(state, result, key::ok, false)) {
		const DictRef recap = state.new_dict();
		set_bool(state, recap, key::active, false);
		set_text(state, recap, key::kind, lane);
		set_text(state, recap, key::action_id, action_id);
		set_text(state, recap, key::message, message);
		set_text(state, recap, key::text, message);
		return recap;
	}
	// A caller that already read the post-order signature passes it in.
	const DictRef after = !gd::is_empty(state, after_signature) ? after_signature : town_action_consequence_signature(state, session);
	const Atom happened = _town_action_happened_line(state, lane, action_id, action, message);
	const Atom affected = _town_action_affected_line(state, lane, action_id, action, before, after);
	const Atom matters = _town_action_matters_line(state, session, lane, before, after);
	const Atom next = _town_action_next_line(state, session);
	const Atom text = gd::format(state, key::after_order_s_affected_s_why, {str(happened), str(affected), str(matters), str(next)});
	const Atom tooltip = gd::format(state, key::action_recap_happened_s_affected_s, {str(happened), str(affected), str(matters), str(next)});
	const DictRef recap = state.new_dict();
	set_bool(state, recap, key::active, true);
	set_text(state, recap, key::kind, lane);
	set_text(state, recap, key::action_id, action_id);
	set_text(state, recap, key::label, text_or(state, action, key::label, str(action_id)));
	set_text(state, recap, key::happened, happened);
	set_text(state, recap, key::affected, affected);
	set_text(state, recap, key::why_it_matters, matters);
	set_text(state, recap, key::next_step_2, next);
	set_text(state, recap, key::matters, matters);
	set_text(state, recap, key::next, next);
	set_text(state, recap, key::text, text);
	set_text(state, recap, key::tooltip_text, tooltip);
	set_text(state, recap, key::message, message);
	return recap;
}

Atom _build_order_ledger_line(State &state, DictRef session, DictRef town) {
	const ArrayRef build_actions = get_build_actions(state, session);
	// String(action.get("ledger_line", action.get("label", "Build order"))).
	const auto ledger_label = [&state](DictRef action) {
		return text_or(state, action, key::ledger_line, state.get(action, str(key::label), str(key::build_order)));
	};
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return gd::format(state, key::s_is_ready_now, {str(ledger_label(action.ref))});
		}
	}
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::market_coverable, false)) {
			return gd::format(state, key::s_waits_on_stores_exchange_path, {
				str(ledger_label(action.ref)),
				str(text_or(state, action.ref, key::market_summary, str(key::trade_through_the_exchange))),
			});
		}
	}
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (gd::is_dict(action)) {
			const Atom shortfall = text_or(state, action.ref, key::shortfall_summary, str(key::empty));
			if (shortfall != key::empty) {
				return gd::format(state, key::s_is_blocked_by_reserves_s, {str(ledger_label(action.ref)), str(shortfall)});
			}
		}
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_or(state, town, key::town_id, str(key::empty)));
	Value built_buildings;
	const bool has_built = state.lookup(town, str(key::built_buildings), built_buildings);
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		const Atom building_id = gd::stringify(state, building_id_value);
		if (building_id == key::empty || (has_built && gd::in(state, str(building_id), built_buildings))) {
			continue;
		}
		const DictRef build_status = overworld_rules::get_town_build_status(state, town, building_id);
		if (gd::bool_field(state, build_status, key::buildable, false)) {
			continue;
		}
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		return gd::format(state, key::s_stays_deferred_s, {
			str(text_or(state, building, key::name, str(building_id))),
			str(text_or(state, build_status, key::blocked_message, str(key::no_opening_order_is_available))),
		});
	}
	return key::no_new_works_are_open_in;
}

Atom _recruit_order_ledger_line(State &state, DictRef session, DictRef town) {
	const ArrayRef recruit_actions = get_recruit_actions(state, session);
	DictRef best_ready = state.new_dict();
	DictRef best_market = state.new_dict();
	DictRef best_blocked = state.new_dict();
	for (const Value &action : gd::items(state, array_value(recruit_actions))) {
		if (!gd::is_dict(action)) {
			continue;
		}
		if (gd::int_field(state, action.ref, key::direct_affordable_count, 0) > gd::int_field(state, best_ready, key::direct_affordable_count, 0)) {
			best_ready = action.ref;
		}
		if (gd::int_field(state, action.ref, key::market_affordable_count, 0) > gd::int_field(state, best_market, key::market_affordable_count, 0)) {
			best_market = action.ref;
		}
		if (gd::int_field(state, action.ref, key::available_count, 0) > gd::int_field(state, best_blocked, key::available_count, 0)) {
			best_blocked = action.ref;
		}
	}
	const auto unit_label = [&state](DictRef action) {
		return gd::trim_prefix(state, text_or(state, action, key::label, str(key::recruit_order)), key::recruit_3);
	};
	if (!gd::is_empty(state, best_ready) && gd::int_field(state, best_ready, key::direct_affordable_count, 0) > 0) {
		return gd::format(state, key::s_can_field_d_now_from, {
			str(unit_label(best_ready)),
			int_value(gd::int_field(state, best_ready, key::direct_affordable_count, 0)),
		});
	}
	if (!gd::is_empty(state, best_market) && gd::int_field(state, best_market, key::market_affordable_count, 0) > 0) {
		return gd::format(state, key::s_x_d_wait_in_reserve, {
			str(unit_label(best_market)),
			int_value(gd::int_field(state, best_market, key::available_count, 0)),
			int_value(gd::int_field(state, best_market, key::market_affordable_count, 0)),
			str(text_or(state, best_market, key::market_summary, str(key::trade_through_the_exchange))),
		});
	}
	if (!gd::is_empty(state, best_blocked) && gd::int_field(state, best_blocked, key::available_count, 0) > 0) {
		const Atom blocker = text_or(state, best_blocked, key::shortfall_summary, str(key::stores_are_too_thin));
		return gd::format(state, key::s_x_d_wait_in_reserve_2, {
			str(unit_label(best_blocked)),
			int_value(gd::int_field(state, best_blocked, key::available_count, 0)),
			str(blocker),
		});
	}
	const int64_t next_levy_day = overworld_rules::next_weekly_growth_day(state, ai::session_int(state, session, key::day));
	const Value session_value = dict_value(session);
	Atom best_empty_unit_id = key::empty;
	int64_t best_empty_growth = 0;
	for (const Value &unit_id : gd::items(state, array_value(_town_unit_ids(state, town)))) {
		if (!_unit_is_unlocked_in_town(state, town, gd::to_string(unit_id))) {
			continue;
		}
		int64_t available = 0;
		Value recruits;
		if (state.lookup(town, str(key::available_recruits), recruits)) {
			available = gd::to_int(state, ai::vget(state, recruits, unit_id, int_value(0)));
		}
		const DictRef growth_table = overworld_rules::town_weekly_growth(state, town, session_value);
		const int64_t growth = gd::to_int(state, state.get(growth_table, unit_id, int_value(0)));
		if (available <= 0 && growth > best_empty_growth) {
			best_empty_growth = growth;
			best_empty_unit_id = gd::to_string(unit_id);
		}
	}
	if (best_empty_unit_id != key::empty) {
		const Atom sources = _growth_source_summary(state, town, best_empty_unit_id);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, best_empty_unit_id);
		return gd::format(state, key::s_reserve_is_empty_next_levy, {
			str(text_or(state, unit, key::name, str(best_empty_unit_id))),
			int_value(next_levy_day),
			int_value(best_empty_growth),
			str(sources != key::empty ? gd::format(state, key::via_s, {str(sources)}) : static_cast<Atom>(key::empty)),
		});
	}
	for (const Value &unit_id_value : gd::items(state, array_value(_town_unit_ids(state, town)))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		if (_unit_is_unlocked_in_town(state, town, unit_id)) {
			continue;
		}
		const Atom unlock_building_id = _unlock_building_for_unit(state, town, unit_id);
		if (unlock_building_id == key::empty) {
			continue;
		}
		const DictRef build_status = overworld_rules::get_town_build_status(state, town, unlock_building_id);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		return gd::format(state, key::s_stays_locked_until_s, {
			str(text_or(state, unit, key::name, unit_id_value)),
			str(text_or(state, build_status, key::blocked_message, str(key::the_proper_works_are_raised))),
		});
	}
	return key::no_levy_option_is_currently_open;
}

Atom _response_order_ledger_line(State &state, DictRef session, DictRef town) {
	const ArrayRef response_actions = get_response_actions(state, session);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef movement_state = _active_hero_movement_state(state, session);
	for (const Value &action : gd::items(state, array_value(response_actions))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			Atom movement_clause = key::empty;
			if (gd::int_field(state, action.ref, key::movement_cost, 0) > 0) {
				movement_clause = gd::format(state, key::d_move_left_after_dispatch, {int_value(gd::int_field(state, action.ref, key::remaining_movement_after_order, 0))});
			}
			Atom delivery_clause = key::empty;
			if (text_or(state, action.ref, key::delivery_summary, str(key::empty)) != key::empty) {
				delivery_clause = gd::format(state, key::space_bar_space_s, {str(text_or(state, action.ref, key::delivery_summary, str(key::empty)))});
			}
			return gd::format(state, key::s_is_ready_now_s_s, {
				str(text_or(state, action.ref, key::label, str(key::response_order_2))),
				str(movement_clause),
				str(delivery_clause),
			});
		}
	}
	for (const Value &action : gd::items(state, array_value(response_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::market_coverable, false)) {
			return gd::format(state, key::s_waits_on_stores_exchange_path, {
				str(text_or(state, action.ref, key::label, str(key::response_order_2))),
				str(text_or(state, action.ref, key::market_summary, str(key::trade_through_the_exchange))),
			});
		}
	}
	for (const Value &action : gd::items(state, array_value(response_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::movement_blocked, false)) {
			return gd::format(state, key::s_needs_d_move_but_the, {
				str(text_or(state, action.ref, key::label, str(key::response_order_2))),
				int_value(gd::int_field(state, action.ref, key::movement_cost, 0)),
				int_value(gd::int_field(state, movement_state, key::current, 0)),
				int_value(gd::int_field(state, movement_state, key::max, 0)),
			});
		}
	}
	for (const Value &action : gd::items(state, array_value(response_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::resource_blocked, false)) {
			const Atom label = text_or(state, action.ref, key::label, str(key::response_order_2));
			const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::resources));
			const Value cost = field_or_new_dict(state, action.ref, key::resource_cost);
			const DictRef readiness = overworld_rules::town_cost_readiness(state, town, pool, cost, ai::session_int(state, session, key::day));
			return gd::format(state, key::s_is_blocked_by_reserves_s, {str(label), str(_cost_shortfall_line(state, readiness))});
		}
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		const int64_t days_to_clear = gd::int_field(state, recovery, key::days_to_clear, 0);
		return gd::format(state, key::s_stabilization_still_needs_d_day, {
			str(text_or(state, logistics, key::summary, str(key::routes_are_strained))),
			int_value(days_to_clear),
			str(gd::int_field(state, recovery, key::days_to_clear, 0) == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s)),
			int_value(gd::int_field(state, recovery, key::relief_per_day, 1)),
		});
	}
	if (logistics_alert(state, logistics)) {
		return gd::format(state, key::s_no_linked_response_order_is, {str(_logistics_watch_summary(state, logistics))});
	}
	return key::no_immediate_route_or_recovery_order;
}

Atom _coverage_order_ledger_line(State &state, DictRef session, DictRef town) {
	const ArrayRef stationed = hero_command_rules::stationed_heroes(state, session, town);
	std::vector<Atom> reserve_names;
	const Atom active_hero_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, str(key::empty));
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (text_or(state, hero.ref, key::id, str(key::empty)) == active_hero_id) {
			continue;
		}
		reserve_names.push_back(text_or(state, hero.ref, key::name, str(key::reserve_commander)));
	}
	const DictRef movement_state = _active_hero_movement_state(state, session);
	if (reserve_names.empty()) {
		return gd::format(state, key::no_reserve_commander_covers_the_walls, {
			int_value(gd::int_field(state, movement_state, key::current, 0)),
			int_value(gd::int_field(state, movement_state, key::max, 0)),
		});
	}
	const size_t shown = reserve_names.size() < 2 ? reserve_names.size() : 2;
	const std::vector<Atom> shown_names(reserve_names.begin(), reserve_names.begin() + static_cast<std::ptrdiff_t>(shown));
	Atom names = join_atoms(state, key::comma_space, shown_names);
	if (reserve_names.size() > shown_names.size()) {
		const Atom more = gd::format(state, key::and_d_more, {int_value(static_cast<int64_t>(reserve_names.size() - shown_names.size()))});
		names = state.intern(state.text(names) + state.text(more));
	}
	return gd::format(state, key::s_cover_the_walls_while_active, {
		str(names),
		int_value(gd::int_field(state, movement_state, key::current, 0)),
		int_value(gd::int_field(state, movement_state, key::max, 0)),
	});
}

Atom _town_recommendation_line(State &state, DictRef session, DictRef town) {
	const DictRef recommendation = _town_recommendation_action(state, session, town);
	if (gd::is_empty(state, recommendation)) {
		return _next_town_action_line(state, session, town);
	}
	const Atom label = _short_action_label(state, recommendation, key::town_order);
	const Atom impact = trim_suffix(state, text_or(state, recommendation, key::impact_line, str(key::empty)), key::period);
	Atom readiness = text_or(state, recommendation, key::affordability_label, str(key::empty));
	if (readiness == key::empty) {
		readiness = text_or(state, recommendation, key::disabled_reason, str(key::empty));
	}
	if (impact != key::empty && readiness != key::empty) {
		return gd::format(state, key::s_s_s_6, {str(label), str(readiness), str(impact)});
	}
	if (impact != key::empty) {
		return gd::format(state, key::s_s_text, {str(label), str(impact)});
	}
	if (readiness != key::empty) {
		return gd::format(state, key::s_s_text, {str(label), str(readiness)});
	}
	return gd::format(state, key::s_is_the_clearest_town_order, {str(label)});
}

DictRef _town_recommendation_action(State &state, DictRef session, DictRef town) {
	DictRef best_action = state.new_dict();
	int64_t best_score = -999999;
	for (const Value &action : gd::items(state, array_value(get_build_actions(state, session)))) {
		if (!gd::is_dict(action)) {
			continue;
		}
		const int64_t score = _town_build_recommendation_score(state, town, action.ref);
		if (score > best_score) {
			best_score = score;
			best_action = action.ref;
		}
	}
	for (const Value &action : gd::items(state, array_value(get_recruit_actions(state, session)))) {
		if (!gd::is_dict(action)) {
			continue;
		}
		const int64_t score = _town_recruit_recommendation_score(state, action.ref);
		if (score > best_score) {
			best_score = score;
			best_action = action.ref;
		}
	}
	return best_action;
}

DictRef _town_order_target_action(State &state, DictRef session, DictRef town) {
	// action.duplicate(true) with "lane" set.
	const auto with_lane = [&state](DictRef action, Atom lane) {
		const DictRef copy = gd::as_dict(gd::engine_duplicate(state, dict_value(action), true));
		set_text(state, copy, key::lane, lane);
		return copy;
	};
	for (const Value &action : gd::items(state, array_value(get_response_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return with_lane(action.ref, key::response);
		}
	}
	const DictRef recommendation = _town_recommendation_action(state, session, town);
	if (!gd::is_empty(state, recommendation)) {
		const DictRef recommended = gd::as_dict(gd::engine_duplicate(state, dict_value(recommendation), true));
		const Atom recommended_id = text_or(state, recommended, key::id, str(key::empty));
		if (gd::begins_with(state, recommended_id, key::build)) {
			set_text(state, recommended, key::lane, key::build_2);
		} else if (gd::begins_with(state, recommended_id, key::recruit_2)) {
			set_text(state, recommended, key::lane, key::recruit);
		} else {
			set_text(state, recommended, key::lane, key::order);
		}
		return recommended;
	}
	for (const Value &action : gd::items(state, array_value(get_spell_learning_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return with_lane(action.ref, key::study);
		}
	}
	for (const Value &action : gd::items(state, array_value(get_market_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return with_lane(action.ref, key::market);
		}
	}
	for (const Value &action : gd::items(state, array_value(get_build_actions(state, session)))) {
		if (gd::is_dict(action)) {
			return with_lane(action.ref, key::build_2);
		}
	}
	for (const Value &action : gd::items(state, array_value(get_recruit_actions(state, session)))) {
		if (gd::is_dict(action)) {
			return with_lane(action.ref, key::recruit);
		}
	}
	return state.new_dict();
}

Atom _town_order_ui_surface_for_lane(State &state, Atom lane) {
	(void)state;
	if (lane == key::build_2) {
		return key::build_tab;
	}
	if (lane == key::recruit || lane == key::hero || lane == key::tavern || lane == key::transfer || lane == key::specialty) {
		return key::muster_tab;
	}
	if (lane == key::study || lane == key::artifact) {
		return key::spells_tab;
	}
	if (lane == key::market) {
		return key::trade_tab;
	}
	if (lane == key::response) {
		return key::log_tab;
	}
	return key::town_orders;
}

Atom _town_order_lane_label(State &state, Atom lane) {
	(void)state;
	if (lane == key::build_2) {
		return key::Construction;
	}
	if (lane == key::recruit) {
		return key::Recruitment;
	}
	if (lane == key::response) {
		return key::strategic_response;
	}
	if (lane == key::study) {
		return key::spell_study;
	}
	if (lane == key::market) {
		return key::Exchange;
	}
	if (lane == key::hero) {
		return key::Commander;
	}
	if (lane == key::tavern) {
		return key::hero_hire;
	}
	if (lane == key::transfer) {
		return key::Transfer;
	}
	if (lane == key::artifact) {
		return key::Artifact;
	}
	if (lane == key::specialty) {
		return key::Specialty;
	}
	return key::town_order;
}

Atom _town_order_readiness_line(State &state, DictRef action, Atom lane) {
	if (lane == key::build_2) {
		if (gd::bool_field(state, action, key::direct_affordable, false)) {
			return key::ready_now_3;
		}
		if (gd::bool_field(state, action, key::market_coverable, false)) {
			const Atom market_summary = text_or(state, action, key::market_summary, str(key::empty));
			return gd::format(state, key::needs_exchange_first_s, {str(market_summary != key::empty ? gd::format(state, key::s_7, {str(market_summary)}) : static_cast<Atom>(key::empty))});
		}
		return text_or(state, action, key::disabled_reason, str(key::blocked_by_current_town_state));
	}
	if (lane == key::recruit) {
		const int64_t direct_count = gd::int_field(state, action, key::direct_affordable_count, 0);
		if (direct_count > 0) {
			return gd::format(state, key::ready_x_d, {int_value(direct_count)});
		}
		const int64_t market_count = gd::int_field(state, action, key::market_affordable_count, 0);
		if (market_count > 0) {
			const Atom recruit_market_summary = text_or(state, action, key::market_summary, str(key::empty));
			return gd::format(state, key::needs_exchange_x_d_s, {
				int_value(market_count),
				str(recruit_market_summary != key::empty ? gd::format(state, key::s_7, {str(recruit_market_summary)}) : static_cast<Atom>(key::empty)),
			});
		}
		return text_or(state, action, key::disabled_reason, str(key::blocked_by_current_town_state));
	}
	if (gd::bool_field(state, action, key::disabled, false)) {
		return text_or(state, action, key::disabled_reason, str(key::blocked_by_current_town_state));
	}
	const Atom affordability = text_or(state, action, key::affordability_label, str(key::empty));
	if (affordability != key::empty) {
		return affordability;
	}
	return key::ready_now_3;
}

Atom _town_order_impact_line(State &state, DictRef action, Atom lane) {
	const Atom impact = gd::strip_edges(state, text_or(state, action, key::impact_line, str(key::empty)));
	if (impact != key::empty) {
		return trim_suffix(state, impact, key::period);
	}
	const Atom recommendation = gd::strip_edges(state, text_or(state, action, key::recommendation_line, str(key::empty)));
	if (recommendation != key::empty) {
		return trim_suffix(state, recommendation, key::period);
	}
	const Atom delivery = gd::strip_edges(state, text_or(state, action, key::delivery_summary, str(key::empty)));
	if (delivery != key::empty) {
		return trim_suffix(state, delivery, key::period);
	}
	const Atom summary = gd::strip_edges(state, text_or(state, action, key::summary, str(key::empty)));
	if (summary != key::empty) {
		for (const Atom line_value : split_text(state, summary, key::newline, false)) {
			const Atom line = gd::strip_edges(state, line_value);
			if (line != key::empty) {
				return trim_suffix(state, line, key::period);
			}
		}
	}
	return gd::format(state, key::s_keeps_the_town_plan_moving, {str(to_lower(state, _town_order_lane_label(state, lane), "TownRules._town_order_impact_line"))});
}

Atom _town_order_next_step(State &state, DictRef action, Atom lane, Atom label, Atom where, Atom readiness) {
	if (gd::bool_field(state, action, key::disabled, false)) {
		return gd::format(state, key::resolve_s_before_pressing_s_in, {str(to_lower(state, readiness, "TownRules._town_order_next_step")), str(label), str(where)});
	}
	if (lane == key::build_2 && gd::bool_field(state, action, key::market_coverable, false) && !gd::bool_field(state, action, key::direct_affordable, false)) {
		return gd::format(state, key::use_the_exchange_path_then_press, {str(label), str(where)});
	}
	if (lane == key::recruit && gd::int_field(state, action, key::direct_affordable_count, 0) <= 0 && gd::int_field(state, action, key::market_affordable_count, 0) > 0) {
		return gd::format(state, key::use_the_exchange_path_then_press, {str(label), str(where)});
	}
	return gd::format(state, key::press_s_in_s_or_leave, {str(label), str(where)});
}

int64_t _town_build_recommendation_score(State &state, DictRef town, DictRef action) {
	const Atom building_id = gd::trim_prefix(state, text_or(state, action, key::id, str(key::empty)), key::build);
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	int64_t score = 0;
	if (gd::bool_field(state, action, key::direct_affordable, false)) {
		score = gd::add(score, 120);
	} else if (gd::bool_field(state, action, key::market_coverable, false)) {
		score = gd::add(score, 70);
	} else {
		score = gd::add(score, 20);
	}
	const Atom category = text_or(state, building, key::category, str(key::empty));
	if (category == key::dwelling) {
		score = gd::add(score, 28);
	} else if (category == key::support) {
		score = gd::add(score, 24);
	} else if (category == key::economy) {
		score = gd::add(score, 18);
	} else if (category == key::magic) {
		score = gd::add(score, 12);
	} else if (category == key::civic) {
		score = gd::add(score, 10);
	}
	if (text_or(state, building, key::unlock_unit_id, str(key::empty)) != key::empty) {
		score = gd::add(score, 18);
	}
	Value growth;
	if (state.lookup(building, str(key::growth_bonus), growth) && gd::is_dict(growth)) {
		const ArrayRef unit_ids = gd::keys(state, growth.ref);
		for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
			score = gd::add(score, gd::mul(compat::engine_max<int64_t>(0, gd::to_int(state, state.get(growth.ref, unit_id, int_value(0)))), 3));
		}
	}
	score = gd::add(score, gd::mul(compat::engine_max<int64_t>(0, gd::int_field(state, building, key::readiness_bonus, 0)), 2));
	score = gd::add(score, gd::mul(compat::engine_max<int64_t>(0, gd::int_field(state, building, key::pressure_bonus, 0)), 8));
	Value income;
	if (state.lookup(building, str(key::income), income) && gd::is_dict(income)) {
		const double gold = static_cast<double>(gd::int_field(state, income.ref, key::gold, 0));
		score = gd::add(score, compat::engine_min<int64_t>(18, compat::float_to_int(compat::godot_floor(gold / 50.0))));
	}
	if (overworld_rules::town_strategic_role(state, town) == key::stronghold) {
		score = gd::add(score, compat::engine_max<int64_t>(0, gd::int_field(state, building, key::readiness_bonus, 0)));
	}
	return score;
}

int64_t _town_recruit_recommendation_score(State &state, DictRef action) {
	const int64_t ready_count = gd::int_field(state, action, key::direct_affordable_count, 0);
	const int64_t market_count = gd::int_field(state, action, key::market_affordable_count, 0);
	const Atom unit_id = gd::trim_prefix(state, text_or(state, action, key::id, str(key::empty)), key::recruit_2);
	int64_t score = 0;
	if (ready_count > 0) {
		score = gd::add(score, 105);
	} else if (market_count > 0) {
		score = gd::add(score, 62);
	} else {
		score = gd::add(score, 15);
	}
	const int64_t strength = overworld_rules::unit_stack_strength_value(state, unit_id, compat::engine_max<int64_t>(ready_count, 1));
	score = gd::add(score, compat::engine_min<int64_t>(40, compat::float_to_int(compat::godot_floor(static_cast<double>(strength) / 6.0))));
	score = gd::add(score, compat::engine_min<int64_t>(16, gd::mul(gd::int_field(state, action, key::available_count, 0), 2)));
	score = gd::add(score, compat::engine_min<int64_t>(12, gd::mul(gd::int_field(state, action, key::weekly_growth, 0), 2)));
	return score;
}

Atom _next_town_action_line(State &state, DictRef session, DictRef town) {
	const ArrayRef build_actions = get_build_actions(state, session);
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (!gd::is_dict(action) || gd::bool_field(state, action.ref, key::disabled, false)) {
			continue;
		}
		const Atom projection = _action_projection_line(state, action.ref);
		if (projection != key::empty) {
			return gd::format(state, key::s_colon_s_text, {str(_short_action_label(state, action.ref, key::build_order)), str(projection)});
		}
		return gd::format(state, key::s_is_ready, {str(_short_action_label(state, action.ref, key::build_order))});
	}
	const ArrayRef recruit_actions = get_recruit_actions(state, session);
	for (const Value &action : gd::items(state, array_value(recruit_actions))) {
		if (!gd::is_dict(action) || gd::int_field(state, action.ref, key::direct_affordable_count, 0) <= 0) {
			continue;
		}
		return gd::format(state, key::s_fields_d_now, {
			str(_short_action_label(state, action.ref, key::recruit_order)),
			int_value(gd::int_field(state, action.ref, key::direct_affordable_count, 0)),
		});
	}
	for (const Value &action : gd::items(state, array_value(get_response_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return gd::format(state, key::s_secures_the_frontier_chain, {str(_short_action_label(state, action.ref, key::response_order_2))});
		}
	}
	for (const Value &action : gd::items(state, array_value(get_spell_learning_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return gd::format(state, key::s_expands_the_hero_spellbook, {str(_short_action_label(state, action.ref, key::study_order))});
		}
	}
	for (const Value &action : gd::items(state, array_value(get_market_actions(state, session)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return gd::format(state, key::s_converts_stores_for_blocked_orders, {str(_short_action_label(state, action.ref, key::Exchange))});
		}
	}
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::market_coverable, false)) {
			return gd::format(state, key::trade_first_for_s, {str(_short_action_label(state, action.ref, key::build_order))});
		}
	}
	for (const Value &action : gd::items(state, array_value(recruit_actions))) {
		if (gd::is_dict(action) && gd::bool_field(state, action.ref, key::market_coverable, false)) {
			return gd::format(state, key::trade_first_for_s, {str(_short_action_label(state, action.ref, key::recruit_order))});
		}
	}
	for (const Value &action : gd::items(state, array_value(build_actions))) {
		if (gd::is_dict(action)) {
			return gd::format(state, key::s_blocked_s_2, {
				str(_short_action_label(state, action.ref, key::build_order)),
				str(gd::trim_prefix(state, text_or(state, action.ref, key::disabled_reason, str(key::stores_are_too_thin)), key::blocked_2)),
			});
		}
	}
	for (const Value &action : gd::items(state, array_value(recruit_actions))) {
		if (gd::is_dict(action)) {
			return gd::format(state, key::s_blocked_s_2, {
				str(_short_action_label(state, action.ref, key::recruit_order)),
				str(gd::trim_prefix(state, text_or(state, action.ref, key::disabled_reason, str(key::stores_are_too_thin)), key::blocked_2)),
			});
		}
	}
	const Atom weekly_growth = _describe_recruit_delta(state, dict_value(overworld_rules::town_weekly_growth(state, town, dict_value(session))));
	if (weekly_growth != key::none) {
		return gd::format(state, key::hold_for_day_d_muster_s, {
			int_value(overworld_rules::next_weekly_growth_day(state, ai::session_int(state, session, key::day))),
			str(weekly_growth),
		});
	}
	return key::leave_town_no_production_order_is;
}

DictRef _first_ready_action(State &state, ArrayRef actions) {
	for (const Value &action : gd::items(state, array_value(actions))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			return action.ref;
		}
	}
	return state.new_dict();
}

Atom _town_handoff_affected_line(State &state, Atom town_name, DictRef front, DictRef occupation, DictRef logistics, DictRef ready_response) {
	if (gd::bool_field(state, occupation, key::active, false)) {
		return gd::format(state, key::s_occupation_and_recovery_front, {str(town_name)});
	}
	if (gd::bool_field(state, front, key::active, false)) {
		const Atom enemy_label = text_or(state, front, key::enemy_label, str(key::empty));
		if (enemy_label != key::empty) {
			return gd::format(state, key::s_s_front_against_s, {
				str(town_name),
				str(gd::capitalize(state, text_or(state, front, key::mode, str(key::front)))),
				str(enemy_label),
			});
		}
		return gd::format(state, key::s_active_front, {str(town_name)});
	}
	if (!gd::is_empty(state, ready_response)) {
		return gd::format(state, key::s_response_order_s, {str(town_name), str(_short_action_label(state, ready_response, key::response_order_2))});
	}
	if (logistics_alert(state, logistics)) {
		return gd::format(state, key::s_frontier_support_chain, {str(town_name)});
	}
	return gd::format(state, key::s_town_order_queue_and_return, {str(town_name)});
}

Atom _town_handoff_why_line(State &state, DictRef town, DictRef front, DictRef occupation, DictRef logistics, DictRef recovery, DictRef ready_response) {
	if (gd::bool_field(state, occupation, key::active, false) && text_or(state, occupation, key::summary, str(key::empty)) != key::empty) {
		return text_or(state, occupation, key::summary, str(key::empty));
	}
	if (gd::bool_field(state, front, key::active, false) && text_or(state, front, key::summary, str(key::empty)) != key::empty) {
		return text_or(state, front, key::summary, str(key::empty));
	}
	if (!gd::is_empty(state, ready_response)) {
		const Atom delivery_summary = text_or(state, ready_response, key::delivery_summary, str(key::empty));
		if (delivery_summary != key::empty) {
			return gd::format(state, key::dispatch_can_carry_reserves_into_the, {str(delivery_summary)});
		}
		return key::dispatch_can_steady_a_linked_frontier;
	}
	const Atom logistics_summary = _logistics_watch_summary(state, logistics);
	if (logistics_alert(state, logistics) || gd::int_field(state, logistics, key::support_gap, 0) > 0) {
		return logistics_summary;
	}
	if (gd::bool_field(state, recovery, key::active, false) && text_or(state, recovery, key::summary, str(key::empty)) != key::empty) {
		return text_or(state, recovery, key::summary, str(key::empty));
	}
	return gd::format(state, key::s_orders_shape_the_army_walls, {str(_town_name(state, town))});
}

Atom _town_handoff_next_line(State &state, DictRef session, DictRef town, DictRef ready_response, DictRef movement) {
	if (!gd::is_empty(state, ready_response)) {
		const Atom label = _short_action_label(state, ready_response, key::response_order_2);
		const int64_t move_left = gd::to_int(state, state.get(ready_response, str(key::remaining_movement_after_order), state.get(movement, str(key::current), int_value(0))));
		return gd::format(state, key::use_s_in_logistics_then_return, {str(label), int_value(move_left)});
	}
	const Atom next_town_action = _next_town_action_line(state, session, town);
	if (gd::int_field(state, movement, key::current, 0) <= 0) {
		return gd::format(state, key::s_then_return_to_the_field, {str(next_town_action)});
	}
	return gd::format(state, key::s_then_return_to_the_field_2, {
		str(next_town_action),
		int_value(gd::int_field(state, movement, key::current, 0)),
		int_value(gd::int_field(state, movement, key::max, 0)),
	});
}

Atom _short_town_handoff_text(State &state, Atom text, int64_t max_chars) {
	const Atom trimmed = gd::replace(state, gd::strip_edges(state, text), key::newline, key::space);
	if (max_chars <= 3 || code_point_count(state.text(trimmed)) <= max_chars) {
		return trimmed;
	}
	return gd::format(state, key::s_5, {str(left(state, trimmed, max_chars - 3))});
}

Atom _short_action_label(State &state, DictRef action, Atom fallback) {
	const Atom label = text_or(state, action, key::label, str(fallback));
	for (const Atom prefix : {static_cast<Atom>(key::build_3), static_cast<Atom>(key::recruit_3), static_cast<Atom>(key::learn)}) {
		if (gd::begins_with(state, label, prefix)) {
			return gd::trim_prefix(state, label, prefix);
		}
	}
	return label;
}

Atom _action_projection_line(State &state, DictRef action) {
	for (const Atom line_value : split_text(state, text_or(state, action, key::summary, str(key::empty)), key::newline, false)) {
		Atom line = gd::strip_edges(state, line_value);
		if (!gd::begins_with(state, line, key::projection)) {
			continue;
		}
		line = trim_suffix(state, gd::strip_edges(state, gd::trim_prefix(state, line, key::projection)), key::period);
		if (code_point_count(state.text(line)) > 72) {
			line = gd::format(state, key::s_5, {str(left(state, line, 69))});
		}
		return line;
	}
	return key::empty;
}

Atom _town_action_happened_line(State &state, Atom lane, Atom action_id, DictRef action, Atom message) {
	const Atom first_sentence = _first_sentence(state, message);
	if (first_sentence != key::empty) {
		return first_sentence;
	}
	const Atom label = _short_action_label(state, action, action_id);
	if (lane == key::build_2) {
		return gd::format(state, key::built_s, {str(label)});
	}
	if (lane == key::recruit) {
		return gd::format(state, key::recruited_s, {str(label)});
	}
	if (lane == key::market) {
		return gd::format(state, key::s_resolved_through_the_exchange, {str(label)});
	}
	if (lane == key::response) {
		return gd::format(state, key::s_resolved_as_a_frontier_order, {str(label)});
	}
	return gd::format(state, key::s_resolved, {str(label)});
}

Atom _town_action_affected_line(State &state, Atom lane, Atom action_id, DictRef action, DictRef before, DictRef after) {
	std::vector<Atom> parts;
	if (lane == key::build_2) {
		const Atom building_id = gd::trim_prefix(state, action_id, key::build);
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		parts.push_back(gd::format(state, key::building_s, {str(text_or(state, building, key::name, str(_short_action_label(state, action, building_id))))}));
	} else if (lane == key::recruit) {
		const Atom unit_id = gd::trim_prefix(state, action_id, key::recruit_2);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		parts.push_back(gd::format(state, key::unit_s, {str(text_or(state, unit, key::name, str(_short_action_label(state, action, unit_id))))}));
	} else if (lane == key::market) {
		parts.push_back(_market_action_target_line(state, action_id, action));
	} else {
		parts.push_back(gd::format(state, key::order_s, {str(_short_action_label(state, action, action_id))}));
	}
	const Atom built_delta = _built_delta_summary(state, field_or_new_array(state, before, key::built_buildings), field_or_new_array(state, after, key::built_buildings));
	if (built_delta != key::empty) {
		parts.push_back(built_delta);
	}
	const Atom resource_delta = _signed_resource_delta_summary(state, field_or_new_dict(state, before, key::resources), field_or_new_dict(state, after, key::resources), key::Stores);
	if (resource_delta != key::empty) {
		parts.push_back(resource_delta);
	}
	const Atom artifact_delta = _artifact_delta_summary(state, field_or_new_array(state, before, key::artifact_ids), field_or_new_array(state, after, key::artifact_ids));
	if (artifact_delta != key::empty) {
		parts.push_back(artifact_delta);
	}
	const Atom reserve_delta = _signed_recruit_delta_summary(state, field_or_new_dict(state, before, key::available_recruits), field_or_new_dict(state, after, key::available_recruits), key::Reserve);
	if (reserve_delta != key::empty) {
		parts.push_back(reserve_delta);
	}
	const Atom army_delta = _signed_recruit_delta_summary(state, field_or_new_dict(state, before, key::army_counts), field_or_new_dict(state, after, key::army_counts), key::Field);
	if (army_delta != key::empty) {
		parts.push_back(army_delta);
	}
	if (lane == key::recruit &&
			gd::equal(state, state.get(before, str(key::recruitment_holder_id), str(key::empty)), state.get(after, str(key::recruitment_holder_id), str(key::empty)))) {
		const Atom destination_delta = _signed_recruit_delta_summary(state, field_or_new_dict(state, before, key::recruitment_holder_counts), field_or_new_dict(state, after, key::recruitment_holder_counts),
				text_or(state, after, key::recruitment_holder_label, str(key::local_recipient)));
		if (destination_delta != key::empty) {
			parts.push_back(destination_delta);
		}
	}
	if (parts.size() <= 1) {
		parts.push_back(key::town_queue_and_stores_updated);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _town_action_matters_line(State &state, DictRef session, Atom lane, DictRef before, DictRef after) {
	std::vector<Atom> parts;
	const int64_t readiness_delta = gd::sub(gd::int_field(state, after, key::battle_readiness, 0), gd::int_field(state, before, key::battle_readiness, 0));
	if (readiness_delta != 0) {
		parts.push_back(gd::format(state, key::readiness_s, {str(_signed_int(state, readiness_delta))}));
	}
	const int64_t quality_delta = gd::sub(gd::int_field(state, after, key::reinforcement_quality, 0), gd::int_field(state, before, key::reinforcement_quality, 0));
	if (quality_delta != 0) {
		parts.push_back(gd::format(state, key::muster_quality_s, {str(_signed_int(state, quality_delta))}));
	}
	const int64_t pressure_delta = gd::sub(gd::int_field(state, after, key::pressure_output, 0), gd::int_field(state, before, key::pressure_output, 0));
	if (pressure_delta != 0) {
		const DictRef town = get_active_town(state, session);
		parts.push_back(gd::format(state, key::s_s, {
			str(to_lower(state, _town_pressure_label(state, town), "TownRules._town_action_matters_line")),
			str(_signed_int(state, pressure_delta)),
		}));
	}
	const Atom income_delta = _signed_resource_delta_summary(state, field_or_new_dict(state, before, key::income), field_or_new_dict(state, after, key::income), key::Income);
	if (income_delta != key::empty) {
		parts.push_back(income_delta);
	}
	const Atom growth_delta = _signed_recruit_delta_summary(state, field_or_new_dict(state, before, key::weekly_growth), field_or_new_dict(state, after, key::weekly_growth), key::weekly_muster_2);
	if (growth_delta != key::empty) {
		parts.push_back(growth_delta);
	}
	const Atom logistics_summary = text_or(state, after, key::logistics_summary, str(key::empty));
	if (logistics_summary != key::empty && logistics_summary != text_or(state, before, key::logistics_summary, str(key::empty))) {
		parts.push_back(gd::format(state, key::logistics_s_2, {str(logistics_summary)}));
	}
	if (gd::bool_field(state, after, key::front_active, false) && text_or(state, after, key::front_summary, str(key::empty)) != key::empty) {
		parts.push_back(text_or(state, after, key::front_summary, str(key::empty)));
	}
	if (!parts.empty()) {
		return gd::format(state, key::production_defense_now_shows_s, {str(join_atoms(state, key::space_bar_space, parts))});
	}
	if (lane == key::market) {
		return key::stores_shifted_so_the_next_blocked;
	}
	if (lane == key::recruit) {
		return key::the_marching_army_is_stronger_while;
	}
	if (lane == key::build_2) {
		return key::the_town_engine_changed_even_if;
	}
	if (lane == key::response) {
		return key::the_frontier_chain_was_acted_on;
	}
	return key::the_town_state_changed_review_the;
}

Atom _town_action_next_line(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::return_to_the_overworld;
	}
	return _next_town_action_line(state, session, town);
}

Atom _first_sentence(State &state, Atom text) {
	const Atom trimmed = gd::strip_edges(state, text);
	if (trimmed == key::empty) {
		return key::empty;
	}
	// find(".") and left(index + 1): "." is one byte, so the byte offset cuts
	// at the same code point.
	const std::string source = state.text(trimmed);
	const size_t period_index = source.find('.');
	if (period_index == std::string::npos) {
		return trimmed;
	}
	return state.intern(source.substr(0, period_index + 1));
}

Atom _market_action_target_line(State &state, Atom action_id, DictRef action) {
	const std::vector<Atom> parts = split_text(state, action_id, key::colon, true);
	if (parts.size() == 4 && parts[0] == key::market) {
		return gd::format(state, key::exchange_s_d_s, {
			str(parts[1]),
			int_value(compat::to_int(state.text(parts[3]))),
			str(parts[2]),
		});
	}
	if (parts.size() == 5 && parts[0] == key::market && parts[1] == key::convert) {
		return gd::format(state, key::exchange_s_into_d_s, {str(parts[2]), int_value(compat::to_int(state.text(parts[4]))), str(parts[3])});
	}
	return gd::format(state, key::exchange_s, {str(_short_action_label(state, action, action_id))});
}

Atom _built_delta_summary(State &state, const Value &before_value, const Value &after_value) {
	const ArrayRef before = _normalize_string_array(state, before_value);
	const ArrayRef after = _normalize_string_array(state, after_value);
	std::vector<Atom> added;
	for (const Value &building_id : gd::items(state, array_value(after))) {
		if (gd::array_has(state, before, building_id)) {
			continue;
		}
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::to_string(building_id));
		added.push_back(text_or(state, building, key::name, building_id));
	}
	if (added.empty()) {
		return key::empty;
	}
	return gd::format(state, key::built_s_2, {str(join_atoms(state, key::comma_space, added))});
}

Atom _signed_resource_delta_summary(State &state, const Value &before_value, const Value &after_value, Atom label) {
	const DictRef before = _duplicate_dictionary(state, before_value);
	const DictRef after = _duplicate_dictionary(state, after_value);
	std::vector<Atom> parts;
	const ArrayRef resource_keys = _resource_keys_for_payload(state, dict_value(after));
	for (const Value &resource_key : gd::items(state, array_value(resource_keys))) {
		const int64_t delta = gd::sub(gd::to_int(state, state.get(after, resource_key, int_value(0))), gd::to_int(state, state.get(before, resource_key, int_value(0))));
		if (delta == 0) {
			continue;
		}
		parts.push_back(gd::format(state, key::s_s, {resource_key, str(_signed_int(state, delta))}));
	}
	return !parts.empty() ? gd::format(state, key::s_s, {str(label), str(join_atoms(state, key::comma_space, parts))}) : static_cast<Atom>(key::empty);
}

Atom _artifact_delta_summary(State &state, const Value &before_value, const Value &after_value) {
	const ArrayRef before = _normalize_string_array(state, before_value);
	const ArrayRef after = _normalize_string_array(state, after_value);
	std::vector<Atom> added;
	for (const Value &artifact_id : gd::items(state, array_value(after))) {
		if (!gd::array_has(state, before, artifact_id)) {
			added.push_back(artifact_rules::artifact_name(state, gd::to_string(artifact_id)));
		}
	}
	return !added.empty() ? gd::format(state, key::artifact_s_2, {str(join_atoms(state, key::comma_space, added))}) : static_cast<Atom>(key::empty);
}

Atom _signed_recruit_delta_summary(State &state, const Value &before_value, const Value &after_value, Atom label) {
	const DictRef before = _duplicate_dictionary(state, before_value);
	const DictRef after = _duplicate_dictionary(state, after_value);
	const ArrayRef unit_ids = state.new_array();
	for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, before)))) {
		const Atom before_unit_id = gd::stringify(state, unit_id_value);
		if (!gd::array_has(state, unit_ids, str(before_unit_id))) {
			state.append(unit_ids, str(before_unit_id));
		}
	}
	for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, after)))) {
		const Atom after_unit_id = gd::stringify(state, unit_id_value);
		if (!gd::array_has(state, unit_ids, str(after_unit_id))) {
			state.append(unit_ids, str(after_unit_id));
		}
	}
	sort_strings(state, unit_ids);
	std::vector<Atom> parts;
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		const int64_t delta = gd::sub(gd::to_int(state, state.get(after, unit_id, int_value(0))), gd::to_int(state, state.get(before, unit_id, int_value(0))));
		if (delta == 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id));
		parts.push_back(gd::format(state, key::s_s, {str(text_or(state, unit, key::name, unit_id)), str(_signed_int(state, delta))}));
	}
	return !parts.empty() ? gd::format(state, key::s_s, {str(label), str(join_atoms(state, key::comma_space, parts))}) : static_cast<Atom>(key::empty);
}

Atom _describe_recruit_delta(State &state, const Value &delta) {
	if (!gd::is_dict(delta)) {
		return key::none;
	}
	std::vector<Atom> parts;
	const ArrayRef unit_ids = state.new_array();
	for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, delta.ref)))) {
		state.append(unit_ids, str(gd::stringify(state, unit_id_value)));
	}
	sort_strings(state, unit_ids);
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		const int64_t amount = gd::to_int(state, state.get(delta.ref, unit_id, int_value(0)));
		if (amount <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id));
		parts.push_back(gd::format(state, key::d_s_2, {int_value(amount), str(text_or(state, unit, key::name, unit_id))}));
	}
	return !parts.empty() ? join_atoms(state, key::comma_space, parts) : static_cast<Atom>(key::none);
}

int64_t _recruit_pool_total(State &state, const Value &recruits) {
	int64_t total = 0;
	if (gd::is_dict(recruits)) {
		for (const Value &value : gd::items(state, array_value(gd::values(state, recruits.ref)))) {
			total = gd::add(total, compat::engine_max<int64_t>(0, gd::to_int(state, value)));
		}
	}
	return total;
}

} // namespace town_rules

} // namespace aurelion::rules::port
