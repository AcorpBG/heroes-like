// OverworldRules and ScenarioScriptRules texts the outcome screen and the
// progress recap show (Phase 7, slice 7.7): the hero, army, stack and resource
// lines and the recent script events.

#include "aurelion_rules/port/scenario_outcome.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// ScenarioScriptRules.EVENT_LOG_LIMIT.
constexpr int64_t kEventLogLimit = 24;

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

// max(0, x) and max(1, x) of ints.
int64_t at_least(int64_t floor_value, int64_t value) {
	return compat::engine_max<int64_t>(floor_value, value);
}

// int(stack.get("unit_hp", unit.get("hp", 1))), at least 1.
int64_t stack_unit_hp(State &state, DictRef stack, DictRef unit) {
	const Value unit_hp_fallback = state.get(unit, str(key::hp), int_value(1));
	return at_least(1, gd::to_int(state, state.get(stack, str(key::unit_hp), unit_hp_fallback)));
}

} // namespace

// OverworldRules.

namespace overworld_rules {

Atom describe_resources(State &state, DictRef session) {
	return describe_resource_stockpile(state, state.get(session_view::overworld(state, session), str(key::resources), dict_value(state.new_dict())));
}

Atom describe_resource_stockpile(State &state, const Value &resources, bool include_zero_rare) {
	const DictRef normalized = _normalize_live_resource_stockpile(state, resources);
	std::vector<Atom> parts;
	const ArrayRef resource_keys = _resource_keys_for_payload(state, dict_value(normalized));
	for (int64_t index = 0; index < state.array_size(resource_keys); ++index) {
		const Value resource_key = state.at(resource_keys, index);
		const int64_t amount = gd::to_int(state, state.get(normalized, resource_key, int_value(0)));
		const Atom resource_id = gd::to_string(resource_key);
		const bool common_resource = resource_id == key::gold || resource_id == key::wood || resource_id == key::ore;
		if (common_resource || include_zero_rare || amount > 0) {
			parts.push_back(gd::format(state, key::s_d_6, { str(_resource_display_name(state, resource_id)), int_value(amount) }));
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom describe_hero(State &state, DictRef session) {
	const DictRef hero = gd::as_dict(state.get(session_view::overworld(state, session), str(key::hero), dict_value(state.new_dict())));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::index(state, session, str(key::scenario_id))));
	std::vector<Atom> lines;
	lines.push_back(hero_command_rules::hero_identity_context_line(state, hero, text_or(state, scenario, key::player_faction_id, str(key::empty))));
	lines.push_back(hero_command_rules::hero_progress_context_line(state, hero));
	lines.push_back(hero_command_rules::hero_readiness_context_line(state, hero, true));
	return join_atoms(state, key::newline, lines);
}

Atom describe_army(State &state, DictRef session) {
	// session == null: a view is never null.
	const Value army = state.get(session_view::overworld(state, session), str(key::army), dict_value(state.new_dict()));
	std::vector<Atom> lines;
	int64_t headcount = 0;
	int64_t strength = 0;
	for (const Value &stack : gd::items(state, ai::vget(state, army, key::stacks, array_value(state.new_array())))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		if (count <= 0) {
			continue;
		}
		headcount = gd::add(headcount, count);
		strength = gd::add(strength, unit_stack_strength_value(state, text_or(state, stack.ref, key::unit_id, str(key::empty)), count));
		lines.push_back(gd::format(state, key::dash_space_s, { str(describe_stack_inspection_line(state, stack.ref, state.new_dict())) }));
	}
	const Atom listed = !lines.empty() ? join_atoms(state, key::newline, lines) : static_cast<Atom>(key::no_standing_force);
	return gd::format(state, key::marching_army_d_troops_in_d,
			{ int_value(headcount), int_value(static_cast<int64_t>(lines.size())), int_value(strength), str(listed) });
}

Atom describe_stack_inspection_line(State &state, DictRef stack, DictRef options) {
	const Atom unit_id = text_or(state, stack, key::unit_id, str(key::empty));
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const Atom unit_name = text_or(state, unit, key::name, str(unit_id));
	const int64_t count = _stack_display_count(state, stack, unit);
	const int64_t health = _stack_display_health(state, stack, unit, count);
	const int64_t max_health = _stack_display_max_health(state, stack, unit, count);
	const Atom health_text = max_health > health ? gd::format(state, key::d_d_2, { int_value(health), int_value(max_health) })
												 : gd::format(state, key::d_text, { int_value(health) });
	const bool include_name = gd::bool_field(state, options, key::include_name, true);
	std::vector<Atom> parts;
	if (include_name) {
		parts.push_back(gd::format(state, key::s_x_d, { str(unit_name), int_value(count) }));
	} else {
		parts.push_back(gd::format(state, key::count_d, { int_value(count) }));
	}
	const Atom tier_label = unit_tier_label(state, unit);
	const Atom role_label = unit_role_label(state, unit);
	parts.push_back(gd::format(state, key::s_s, { str(tier_label), str(role_label) }));
	parts.push_back(gd::format(state, key::hp_s, { str(health_text) }));
	parts.push_back(gd::format(state, key::strength_d, { int_value(unit_stack_strength_value(state, unit_id, count)) }));
	parts.push_back(_stack_readiness_label(state, stack, health, max_health));
	return join_atoms(state, key::space_bar_space, parts);
}

int64_t _stack_display_count(State &state, DictRef stack, DictRef unit) {
	if (state.has(stack, str(key::total_health))) {
		const int64_t unit_hp = stack_unit_hp(state, stack, unit);
		const double total_health = static_cast<double>(at_least(0, gd::int_field(state, stack, key::total_health, 0)));
		return at_least(0, compat::float_to_int(compat::godot_ceil(total_health / static_cast<double>(unit_hp))));
	}
	if (state.has(stack, str(key::count))) {
		return at_least(0, gd::int_field(state, stack, key::count, 0));
	}
	return at_least(0, gd::int_field(state, stack, key::base_count, 0));
}

int64_t _stack_display_health(State &state, DictRef stack, DictRef unit, int64_t count) {
	if (state.has(stack, str(key::total_health))) {
		return at_least(0, gd::int_field(state, stack, key::total_health, 0));
	}
	return gd::mul(at_least(0, count), at_least(1, gd::int_field(state, unit, key::hp, 1)));
}

int64_t _stack_display_max_health(State &state, DictRef stack, DictRef unit, int64_t count) {
	const int64_t unit_hp = stack_unit_hp(state, stack, unit);
	if (state.has(stack, str(key::base_count))) {
		return gd::mul(at_least(0, gd::int_field(state, stack, key::base_count, 0)), unit_hp);
	}
	return gd::mul(at_least(0, count), unit_hp);
}

Atom _stack_readiness_label(State &state, DictRef stack, int64_t health, int64_t max_health) {
	if (health <= 0) {
		return key::Broken;
	}
	if (gd::bool_field(state, stack, key::defending, false)) {
		return key::Braced;
	}
	if (max_health <= 0) {
		return key::Ready;
	}
	const double ratio = static_cast<double>(health) / static_cast<double>(max_health);
	if (ratio < 0.35) {
		return key::Critical;
	}
	if (ratio < 0.70) {
		return key::Wounded;
	}
	return key::Ready;
}

Atom _resource_display_name(State &state, Atom resource_key) {
	const Atom production_name = text_or(state, resource_definition(state, resource_key), key::display_name, str(key::empty));
	if (production_name != key::empty) {
		return production_name;
	}
	if (resource_key == key::gold) {
		return key::Gold;
	}
	if (resource_key == key::wood) {
		return key::Wood;
	}
	if (resource_key == key::ore) {
		return key::Ore;
	}
	if (resource_key == key::aetherglass) {
		return key::Aetherglass;
	}
	if (resource_key == key::embergrain) {
		return key::Embergrain;
	}
	if (resource_key == key::peatwax) {
		return key::Peatwax;
	}
	if (resource_key == key::verdant_grafts) {
		return key::verdant_grafts_2;
	}
	if (resource_key == key::brass_scrip) {
		return key::brass_scrip_2;
	}
	if (resource_key == key::memory_salt) {
		return key::memory_salt_2;
	}
	return gd::capitalize(state, gd::replace(state, resource_key, key::_, key::space));
}

} // namespace overworld_rules

// ScenarioScriptRules.

namespace scenario_script_rules {

Atom describe_recent_events(State &state, DictRef session, int64_t limit) {
	normalize_script_state(state, session);
	// session == null: a view is never null.
	const DictRef script_state = gd::as_dict(state.get(session_view::overworld(state, session), str(key::scenario_script_state), dict_value(state.new_dict())));
	Value event_log = state.get(script_state, str(key::event_log), array_value(state.new_array()));
	if (!gd::is_array(event_log)) {
		event_log = array_value(state.new_array());
	}
	const int64_t event_count = state.array_size(event_log.ref);
	const int64_t count = compat::engine_clamp<int64_t>(limit, 1, kEventLogLimit);
	const int64_t start_index = compat::engine_max<int64_t>(0, event_count - count);
	std::vector<Atom> parts;
	Value pending;
	if (state.lookup(script_state, str(key::pending_reinforcements), pending) && gd::is_dict(pending) && !gd::is_empty(state, pending.ref)) {
		parts.push_back(gd::format(state, key::d_earned_reinforcement_grant_s_wait, { int_value(static_cast<int64_t>(state.dict_size(pending.ref))) }));
	}
	for (int64_t index = start_index; index < event_count; ++index) {
		const Value entry = state.at(event_log.ref, index);
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom message = text_or(state, entry.ref, key::message, str(key::empty));
		if (message == key::empty) {
			continue;
		}
		const int64_t day = gd::to_int(state, state.get(entry.ref, str(key::day), gd::index(state, session, str(key::day))));
		parts.push_back(gd::format(state, key::day_d_s, { int_value(day), str(message) }));
	}
	return join_atoms(state, key::space_bar_space, parts);
}

} // namespace scenario_script_rules

} // namespace aurelion::rules::port
