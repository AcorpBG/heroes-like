// OverworldRules for the human seat's site response order (Phase 7, slice 7.3):
// the response action, its effect, and the reserve delivery a town sends.
// HeroCommandRules.spend_active_hero_movement is here too.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

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

// String(v.get(field, fallback)) of an untyped value.
Atom vfield_text(State &state, const Value &value, Atom field, Atom fallback) {
	return value_text(state, ai::vget(state, value, field, str(fallback)));
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

// {"ok": ok, "message": message}.
DictRef ok_message(State &state, bool ok, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	return result;
}

// d.get(field, []) where the answer is kept: a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// d.get(field, {}) where the answer is kept: a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// for x in d.get(field, []): a copy of the items, as the loop bodies call code
// that allocates.
state::ValueList field_list(State &state, DictRef dict, Atom field) {
	return gd::field_items(state, dict, str(field)).list();
}

// int(d.get("position", {}).get(axis, 0)).
int64_t position_axis(State &state, DictRef dict, Atom axis) {
	Value position;
	if (!state.lookup(dict, str(key::position), position)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, position, axis, int_value(0)));
}

// x[index] = value of an untyped value.
void set_indexed(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index on a base of type '") + gd::type_name(container) + "'.");
}

// x[field] = value of an untyped value.
void set_keyed(State &state, const Value &container, Atom field, const Value &value) {
	if (gd::is_dict(container)) {
		state.set(container.ref, str(field), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of property or key '") + state.text(field) + "' on a base object of type '" + gd::type_name(container) + "'.");
}

// "" if count == 1 else "s".
Atom plural_s(int64_t count) {
	return count == 1 ? key::empty : key::s;
}

// s.to_lower(): ASCII text here, any other by the engine (String::to_lower and
// its Unicode case tables), through an Expression parsed once per caller.
Atom to_lower(State &state, Atom text, Value &expression) {
	std::string lowered = state.text(text);
	bool ascii = true;
	for (const char c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			ascii = false;
			break;
		}
	}
	if (ascii) {
		for (char &c : lowered) {
			if (c >= 'A' && c <= 'Z') {
				c = static_cast<char>(c - 'A' + 'a');
			}
		}
		return state.intern(lowered);
	}
	if (expression.kind == Kind::Nil) {
		expression = gd::class_instantiate(state, key::Expression);
		const gd::PackedRef names = gd::new_strings(state);
		gd::packed_append_string(state, names, key::text);
		gd::call_method(state, expression, key::parse, {str(key::text_to_lower), gd::strings_value(names)});
	}
	const ArrayRef inputs = state.new_array();
	state.append(inputs, str(text));
	return gd::to_string(gd::call_method(state, expression, key::execute, {array_value(inputs)}));
}

} // namespace

namespace hero_command_rules {
DictRef _normalize_movement(State &state, const Value &value, int64_t movement_max);
} // namespace hero_command_rules

namespace overworld_rules {

Atom _resource_site_response_effect_summary(State &state, DictRef response_state) {
	std::vector<Atom> parts;
	if (gd::int_field(state, response_state, key::quality_bonus, 0) > 0) {
		parts.push_back(gd::format(state, key::quality_d, {int_value(gd::int_field(state, response_state, key::quality_bonus, 0))}));
	}
	if (gd::int_field(state, response_state, key::readiness_bonus, 0) > 0) {
		parts.push_back(gd::format(state, key::readiness_d, {int_value(gd::int_field(state, response_state, key::readiness_bonus, 0))}));
	}
	if (gd::int_field(state, response_state, key::pressure_bonus, 0) > 0) {
		parts.push_back(gd::format(state, key::pressure_d, {int_value(gd::int_field(state, response_state, key::pressure_bonus, 0))}));
	}
	if (gd::int_field(state, response_state, key::recovery_relief, 0) > 0) {
		parts.push_back(gd::format(state, key::recovery_d, {int_value(gd::int_field(state, response_state, key::recovery_relief, 0))}));
	}
	if (gd::int_field(state, response_state, key::growth_bonus_percent, 0) > 0) {
		parts.push_back(gd::format(state, key::musters_d, {int_value(gd::int_field(state, response_state, key::growth_bonus_percent, 0))}));
	}
	if (gd::int_field(state, response_state, key::pressure_guard_bonus, 0) > 0) {
		parts.push_back(gd::format(state, key::pressure_guard_d, {int_value(gd::int_field(state, response_state, key::pressure_guard_bonus, 0))}));
	}
	return join_atoms(state, key::comma_space, parts);
}

int64_t _estimate_reserve_delivery_eta(State &state, Vector2i origin, Vector2i target, int64_t security_rating, int64_t max_days) {
	(void)state;
	const int64_t distance = gd::add(
			compat::absi(static_cast<int64_t>(origin.x) - static_cast<int64_t>(target.x)),
			compat::absi(static_cast<int64_t>(origin.y) - static_cast<int64_t>(target.y)));
	const int64_t travel_speed = compat::engine_max<int64_t>(2, gd::add(security_rating, 1));
	const double days = static_cast<double>(compat::engine_max<int64_t>(distance, 1)) / static_cast<double>(travel_speed);
	const int64_t eta = compat::float_to_int(compat::godot_ceil(days));
	return compat::engine_clamp<int64_t>(eta, 1, compat::engine_max<int64_t>(1, max_days));
}

DictRef _player_reserve_delivery_plan(State &state, DictRef session, DictRef source_town, DictRef response_state) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, source_town)) {
		return state.new_dict();
	}
	const DictRef available_recruits = _normalize_recruit_payload(state, field_or_new_dict(state, source_town, key::available_recruits));
	if (gd::is_empty(state, available_recruits)) {
		return state.new_dict();
	}
	const ArrayRef candidates = _player_reserve_delivery_candidates(state, session, source_town, response_state);
	if (state.array_size(candidates) == 0) {
		return state.new_dict();
	}
	gd::sort_custom(state, candidates, [&state](const Value &a_value, const Value &b_value) {
		const DictRef a = gd::as_dict(a_value);
		const DictRef b = gd::as_dict(b_value);
		const int64_t a_priority = gd::int_field(state, a, key::priority, 0);
		const int64_t b_priority = gd::int_field(state, b, key::priority, 0);
		if (a_priority == b_priority) {
			const int64_t a_eta = gd::int_field(state, a, key::eta_days, 999);
			const int64_t b_eta = gd::int_field(state, b, key::eta_days, 999);
			if (a_eta == b_eta) {
				return state.text(field_text(state, a, key::label, key::empty)) < state.text(field_text(state, b, key::label, key::empty));
			}
			return a_eta < b_eta;
		}
		return a_priority > b_priority;
	});
	const DictRef best_candidate = gd::as_dict(state.at(candidates, 0));
	const DictRef manifest = _reserve_delivery_manifest_for_candidate(state, session, source_town, best_candidate, response_state);
	if (gd::is_empty(state, manifest)) {
		return state.new_dict();
	}
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::target_kind), str(field_text(state, best_candidate, key::target_kind, key::empty)));
	state.set(plan, str(key::target_id), str(field_text(state, best_candidate, key::target_id, key::empty)));
	state.set(plan, str(key::target_label), str(field_text(state, best_candidate, key::label, key::empty)));
	state.set(plan, str(key::eta_days), int_value(gd::int_field(state, best_candidate, key::eta_days, 1)));
	state.set(plan, str(key::manifest), dict_value(manifest));
	state.set(plan, str(key::priority), int_value(gd::int_field(state, best_candidate, key::priority, 0)));
	return plan;
}

ArrayRef _player_reserve_delivery_candidates(State &state, DictRef session, DictRef source_town, DictRef response_state) {
	const ArrayRef candidates = state.new_array();
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, source_town)) {
		return candidates;
	}
	const Vector2i source_position = Vector2i::of(gd::int_field(state, source_town, key::x, 0), gd::int_field(state, source_town, key::y, 0));
	const int64_t support_radius = compat::engine_max<int64_t>(1, gd::int_field(state, _town_logistics_plan(state, source_town), key::support_radius, 0));
	const int64_t range_bonus = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, response_state, key::security_rating, 1), 1));
	const int64_t max_range = gd::add(support_radius, range_bonus);
	const Atom source_placement_id = field_text(state, source_town, key::placement_id, key::empty);
	const state::ValueList towns = field_list(state, session_view::overworld(state, session), key::towns);
	for (const Value &town_value : towns) {
		if (!gd::is_dict(town_value) || !overworld_level_rules::same_level(state, town_value, dict_value(source_town)) ||
				field_text(state, town_value.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const DictRef town = town_value.ref;
		const Atom placement_id = field_text(state, town, key::placement_id, key::empty);
		if (placement_id == key::empty || placement_id == source_placement_id) {
			continue;
		}
		const Vector2i target_position = Vector2i::of(gd::int_field(state, town, key::x, 0), gd::int_field(state, town, key::y, 0));
		const int64_t distance = gd::add(
				compat::absi(static_cast<int64_t>(source_position.x) - static_cast<int64_t>(target_position.x)),
				compat::absi(static_cast<int64_t>(source_position.y) - static_cast<int64_t>(target_position.y)));
		const DictRef front = _town_front_state(state, session, town, state.new_dict());
		const DictRef occupation = _town_occupation_state(state, session, town);
		int64_t emergency_range_bonus = 0;
		if (gd::bool_field(state, front, key::active, false) && field_text(state, front, key::mode, key::empty) == key::retake) {
			emergency_range_bonus = gd::add(emergency_range_bonus, 2);
		}
		if (gd::bool_field(state, occupation, key::active, false)) {
			emergency_range_bonus = gd::add(emergency_range_bonus, 2);
		}
		if (distance > gd::add(max_range, emergency_range_bonus)) {
			continue;
		}
		const DictRef threat_state = _town_command_risk_state(state, session, town, true);
		const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
		const DictRef logistics = _town_logistics_state(state, session, town);
		const DictRef capital_project = _town_capital_project_state(state, town, dict_value(session), state.new_dict(), state.new_dict());
		int64_t priority = gd::mul(gd::int_field(state, threat_state, key::visible_pressuring, 0), 52);
		priority = gd::add(priority, gd::mul(gd::int_field(state, threat_state, key::visible_marching, 0), 22));
		if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
			priority = gd::add(priority, 10);
		}
		if (gd::bool_field(state, front, key::active, false) && field_text(state, front, key::mode, key::empty) == key::retake) {
			const double bonus = static_cast<double>(gd::int_field(state, front, key::priority_bonus, 0)) / 8.0;
			priority = gd::add(priority, gd::add(26, compat::float_to_int(compat::godot_round(bonus))));
		}
		if (gd::bool_field(state, occupation, key::active, false)) {
			const int64_t headcount = compat::engine_min<int64_t>(28, gd::mul(gd::int_field(state, occupation, key::locked_headcount, 0), 2));
			priority = gd::add(priority, gd::add(gd::add(18, gd::mul(gd::int_field(state, occupation, key::pressure, 0), 12)), headcount));
		}
		priority = gd::add(priority, gd::mul(gd::int_field(state, recovery, key::pressure, 0), 18));
		priority = gd::add(priority, gd::mul(gd::int_field(state, logistics, key::disrupted_count, 0), 18));
		priority = gd::add(priority, gd::mul(gd::int_field(state, logistics, key::threatened_count, 0), 10));
		priority = gd::add(priority, gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 14));
		const Atom role = _town_strategic_role(state, town);
		if (role == key::capital) {
			priority = gd::add(priority, 24);
		} else if (role == key::stronghold) {
			priority = gd::add(priority, 12);
		}
		if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
			priority = gd::add(priority, 18);
		} else if (gd::bool_field(state, capital_project, key::active, false)) {
			priority = gd::add(priority, 8);
		}
		if (priority <= 0) {
			continue;
		}
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::target_kind), str(key::town));
		state.set(candidate, str(key::target_id), str(placement_id));
		state.set(candidate, str(key::label), str(_town_name(state, town)));
		state.set(candidate, str(key::priority), int_value(priority));
		state.set(candidate, str(key::eta_days), int_value(_estimate_reserve_delivery_eta(state, source_position, target_position,
				gd::int_field(state, response_state, key::security_rating, 1),
				gd::int_field(state, response_state, key::watch_days, 1))));
		state.append(candidates, dict_value(candidate));
	}
	const state::ValueList heroes = field_list(state, session_view::overworld(state, session), key::player_heroes);
	for (const Value &hero_value : heroes) {
		if (!gd::is_dict(hero_value) || !overworld_level_rules::same_level(state, hero_value, dict_value(source_town))) {
			continue;
		}
		const DictRef hero = hero_value.ref;
		const Atom hero_id = field_text(state, hero, key::id, key::empty);
		if (hero_id == key::empty) {
			continue;
		}
		const Vector2i hero_position = Vector2i::of(position_axis(state, hero, key::x), position_axis(state, hero, key::y));
		if (hero_position == source_position) {
			continue;
		}
		const int64_t hero_distance = gd::add(
				compat::absi(static_cast<int64_t>(source_position.x) - static_cast<int64_t>(hero_position.x)),
				compat::absi(static_cast<int64_t>(source_position.y) - static_cast<int64_t>(hero_position.y)));
		if (hero_distance > max_range) {
			continue;
		}
		const int64_t hero_priority = _player_hero_delivery_priority(state, session, hero);
		if (hero_priority <= 0) {
			continue;
		}
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::target_kind), str(key::hero));
		state.set(candidate, str(key::target_id), str(hero_id));
		state.set(candidate, str(key::label), str(field_text(state, hero, key::name, key::the_hero)));
		state.set(candidate, str(key::priority), int_value(hero_priority));
		state.set(candidate, str(key::eta_days), int_value(_estimate_reserve_delivery_eta(state, source_position, hero_position,
				gd::int_field(state, response_state, key::security_rating, 1),
				gd::int_field(state, response_state, key::watch_days, 1))));
		state.append(candidates, dict_value(candidate));
	}
	return candidates;
}

int64_t _player_hero_delivery_priority(State &state, DictRef session, DictRef hero) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, hero)) {
		return 0;
	}
	const Vector2i hero_position = Vector2i::of(position_axis(state, hero, key::x), position_axis(state, hero, key::y));
	int64_t priority = 0;
	const Atom active_hero_id = field_text(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	if (field_text(state, hero, key::id, key::empty) == active_hero_id) {
		priority = gd::add(priority, 16);
	}
	if (gd::bool_field(state, hero, key::is_primary, false)) {
		priority = gd::add(priority, 10);
	}
	// hero.get("army", {}).get("stacks", []): a missing army has no stacks.
	Value stacks = array_value(state.new_array());
	{
		Value army;
		if (state.lookup(hero, str(key::army), army)) {
			stacks = ai::vget(state, army, key::stacks, stacks);
		}
	}
	const int64_t army_strength = _army_strength_value(state, stacks);
	if (army_strength <= 90) {
		priority = gd::add(priority, 28);
	} else if (army_strength <= 140) {
		priority = gd::add(priority, 18);
	} else if (army_strength <= 200) {
		priority = gd::add(priority, 8);
	}
	const state::ValueList encounters = field_list(state, session_view::overworld(state, session), key::encounters);
	for (const Value &encounter_value : encounters) {
		if (!gd::is_dict(encounter_value) || !overworld_level_rules::same_level(state, encounter_value, dict_value(hero)) ||
				is_encounter_resolved(state, session, encounter_value.ref)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		const int64_t encounter_x = gd::int_field(state, encounter, key::x, -1);
		const int64_t encounter_y = gd::int_field(state, encounter, key::y, -1);
		if (!is_tile_visible(state, session, encounter_x, encounter_y, overworld_level_rules::level_of(state, dict_value(hero)))) {
			continue;
		}
		const int64_t distance = gd::add(
				compat::absi(gd::sub(hero_position.x, encounter_x)),
				compat::absi(gd::sub(hero_position.y, encounter_y)));
		if (distance <= 1) {
			priority = gd::add(priority, 38);
		} else if (distance <= 3) {
			priority = gd::add(priority, 20);
		}
		if (field_text(state, encounter, key::target_kind, key::empty) == key::hero && gd::bool_field(state, encounter, key::arrived, false)) {
			priority = gd::add(priority, 10);
		}
	}
	const state::ValueList towns = field_list(state, session_view::overworld(state, session), key::towns);
	for (const Value &town_value : towns) {
		if (!gd::is_dict(town_value) || !overworld_level_rules::same_level(state, town_value, dict_value(hero)) ||
				field_text(state, town_value.ref, key::owner, key::neutral) != key::enemy) {
			continue;
		}
		const DictRef town = town_value.ref;
		if (!is_tile_visible(state, session, gd::int_field(state, town, key::x, -1), gd::int_field(state, town, key::y, -1), overworld_level_rules::level_of(state, dict_value(hero)))) {
			continue;
		}
		const int64_t town_distance = gd::add(
				compat::absi(gd::sub(hero_position.x, gd::int_field(state, town, key::x, 0))),
				compat::absi(gd::sub(hero_position.y, gd::int_field(state, town, key::y, 0))));
		if (town_distance <= 2) {
			priority = gd::add(priority, 16);
		} else if (town_distance <= 4) {
			priority = gd::add(priority, 8);
		}
	}
	return priority;
}

DictRef _reserve_delivery_manifest_for_candidate(State &state, DictRef session, DictRef source_town, DictRef candidate, DictRef response_state) {
	const DictRef recruits = _normalize_recruit_payload(state, field_or_new_dict(state, source_town, key::available_recruits));
	if (gd::is_empty(state, recruits)) {
		return state.new_dict();
	}
	int64_t capacity = gd::add(10, gd::mul(compat::engine_max<int64_t>(1, gd::int_field(state, response_state, key::security_rating, 1)), 6));
	capacity = gd::add(capacity, gd::mul(gd::int_field(state, response_state, key::quality_bonus, 0), 2));
	capacity = gd::add(capacity, gd::mul(gd::int_field(state, response_state, key::readiness_bonus, 0), 2));
	if (field_text(state, candidate, key::target_kind, key::empty) == key::town) {
		capacity = gd::add(capacity, 6);
	}
	if (gd::int_field(state, candidate, key::priority, 0) >= 70) {
		capacity = gd::add(capacity, 8);
	} else if (gd::int_field(state, candidate, key::priority, 0) >= 40) {
		capacity = gd::add(capacity, 4);
	}
	const bool hold_back = _town_should_hold_back_reserves(state, session, source_town);
	const ArrayRef unit_ids = state.new_array();
	const ArrayRef recruit_keys = gd::keys(state, recruits);
	for (const Value &unit_id_value : gd::items(state, array_value(recruit_keys))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const int64_t available = gd::to_int(state, state.get(recruits, unit_id_value, int_value(0)));
		const int64_t keep_count = hold_back && available > 2 ? 1 : 0;
		if (compat::engine_max<int64_t>(0, gd::sub(available, keep_count)) <= 0) {
			continue;
		}
		state.append(unit_ids, str(unit_id));
	}
	gd::sort_custom(state, unit_ids, [&state, candidate](const Value &a_value, const Value &b_value) {
		const Atom a = gd::to_string(a_value);
		const Atom b = gd::to_string(b_value);
		const int64_t a_priority = _reserve_delivery_unit_priority(state, a, field_text(state, candidate, key::target_kind, key::empty));
		const int64_t b_priority = _reserve_delivery_unit_priority(state, b, field_text(state, candidate, key::target_kind, key::empty));
		if (a_priority == b_priority) {
			return state.text(a) < state.text(b);
		}
		return a_priority > b_priority;
	});
	const DictRef manifest = state.new_dict();
	int64_t remaining_capacity = compat::engine_max<int64_t>(1, capacity);
	const state::ValueList sorted_ids = state.array(unit_ids).items;
	for (const Value &unit_id_value : sorted_ids) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const int64_t available_count = gd::to_int(state, state.get(recruits, unit_id_value, int_value(0)));
		const int64_t keep_count = hold_back && available_count > 2 ? 1 : 0;
		const int64_t sendable = compat::engine_max<int64_t>(0, gd::sub(available_count, keep_count));
		if (sendable <= 0) {
			continue;
		}
		const int64_t unit_value = _reserve_delivery_unit_value(state, unit_id);
		const double by_capacity = static_cast<double>(compat::engine_max<int64_t>(remaining_capacity, unit_value)) / static_cast<double>(unit_value);
		const int64_t max_by_capacity = compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_floor(by_capacity)));
		const int64_t send_count = compat::engine_min<int64_t>(sendable, max_by_capacity);
		if (send_count <= 0) {
			continue;
		}
		state.set(manifest, unit_id_value, int_value(send_count));
		remaining_capacity = gd::sub(remaining_capacity, gd::mul(send_count, unit_value));
		if (remaining_capacity <= 0) {
			break;
		}
	}
	if (gd::is_empty(state, manifest) && state.array_size(unit_ids) > 0) {
		state.set(manifest, state.at(unit_ids, 0), int_value(1));
	}
	return manifest;
}

int64_t _reserve_delivery_unit_priority(State &state, Atom unit_id, Atom target_kind) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	int64_t priority = gd::mul(compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::tier, 1)), 10);
	priority = gd::add(priority, gd::add(gd::int_field(state, unit, key::attack, 0), gd::int_field(state, unit, key::defense, 0)));
	if (gd::bool_field(state, unit, key::ranged, false)) {
		priority = gd::add(priority, target_kind == key::town ? 6 : 3);
	}
	return priority;
}

int64_t _reserve_delivery_unit_value(State &state, Atom unit_id) {
	const DictRef recruits = state.new_dict();
	state.set(recruits, str(unit_id), int_value(1));
	return compat::engine_max<int64_t>(1, _weighted_recruit_value(state, dict_value(recruits)));
}

bool _town_should_hold_back_reserves(State &state, DictRef session, DictRef town) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town)) {
		return false;
	}
	const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
	const DictRef threat_state = _town_command_risk_state(state, session, town, true);
	if (gd::bool_field(state, recovery, key::active, false)) {
		return true;
	}
	if (gd::int_field(state, threat_state, key::visible_pressuring, 0) > 0 || gd::int_field(state, threat_state, key::visible_marching, 0) > 0 ||
			gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
		return true;
	}
	const Atom role = _town_strategic_role(state, town);
	return role == key::capital || role == key::stronghold;
}

DictRef _consume_recruit_payload(State &state, const Value &recruits, const Value &manifest) {
	const DictRef remaining = _normalize_recruit_payload(state, recruits);
	const DictRef shipment = _normalize_recruit_payload(state, manifest);
	const ArrayRef shipment_keys = gd::keys(state, shipment);
	for (const Value &unit_id_value : gd::items(state, array_value(shipment_keys))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const int64_t held = gd::to_int(state, state.get(remaining, str(unit_id), int_value(0)));
		const int64_t shipped = gd::to_int(state, state.get(shipment, unit_id_value, int_value(0)));
		state.set(remaining, str(unit_id), int_value(compat::engine_max<int64_t>(0, gd::sub(held, shipped))));
		if (gd::to_int(state, state.get(remaining, str(unit_id), int_value(0))) <= 0) {
			state.erase(remaining, str(unit_id));
		}
	}
	return remaining;
}

DictRef _resource_site_response_action(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (gd::int_field(state, response_state, key::watch_days, 0) <= 0) {
		return state.new_dict();
	}
	if (gd::bool_field(state, response_state, key::active, false)) {
		return state.new_dict();
	}
	const DictRef linked_town_result = _resource_node_linked_town(state, session, node, key::player);
	const Value cost = field_or_new_dict(state, response_state, key::resource_cost);
	const int64_t movement_cost = gd::int_field(state, response_state, key::movement_cost, 0);
	// int(session.overworld.get("movement", {}).get("current", 0)); a session is never null.
	int64_t movement_left = 0;
	{
		Value movement;
		if (state.lookup(session_view::overworld(state, session), str(key::movement), movement)) {
			movement_left = gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)));
		}
	}
	const bool disabled = !_can_afford(state, session, cost) || movement_left < movement_cost;
	std::vector<Atom> summary_parts;
	const Atom summary = field_text(state, response_state, key::summary, key::empty);
	if (summary != key::empty) {
		summary_parts.push_back(summary);
	}
	const Atom commander_name = field_text(state, response_state, key::commander_name, key::empty);
	if (commander_name != key::empty) {
		summary_parts.push_back(gd::format(state, key::commander_s_2, {str(commander_name)}));
	}
	if (gd::int_field(state, linked_town_result, key::index, -1) >= 0) {
		const DictRef linked_town = gd::as_dict(field_or_new_dict(state, linked_town_result, key::town));
		summary_parts.push_back(gd::format(state, key::linked_s, {str(_town_name(state, linked_town))}));
	}
	DictRef delivery_plan = state.new_dict();
	if (gd::int_field(state, linked_town_result, key::index, -1) >= 0) {
		const DictRef linked_town = gd::as_dict(field_or_new_dict(state, linked_town_result, key::town));
		delivery_plan = _player_reserve_delivery_plan(state, session, linked_town, response_state);
	}
	if (!gd::is_empty(state, delivery_plan)) {
		const Atom recruit_summary = _describe_recruit_delta(state, field_or_new_dict(state, delivery_plan, key::manifest));
		summary_parts.push_back(gd::format(state, key::load_s_for_s, {str(recruit_summary), str(field_text(state, delivery_plan, key::target_label, key::the_front))}));
		const int64_t eta_days = gd::int_field(state, delivery_plan, key::eta_days, 1);
		summary_parts.push_back(gd::format(state, key::eta_d_day_s, {int_value(eta_days), str(plural_s(gd::int_field(state, delivery_plan, key::eta_days, 1)))}));
	}
	const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
	if (impact_summary != key::empty) {
		summary_parts.push_back(impact_summary);
	}
	summary_parts.push_back(gd::format(state, key::escort_d, {int_value(gd::int_field(state, response_state, key::security_rating, 1))}));
	const Atom cost_summary = _describe_resource_delta(state, cost);
	if (cost_summary != key::empty) {
		summary_parts.push_back(gd::format(state, key::cost_s_2, {str(cost_summary)}));
	}
	if (movement_cost > 0) {
		summary_parts.push_back(gd::format(state, key::move_d_2, {int_value(movement_cost)}));
	}
	const int64_t watch_days = gd::int_field(state, response_state, key::watch_days, 0);
	summary_parts.push_back(gd::format(state, key::d_day_s, {int_value(watch_days), str(plural_s(gd::int_field(state, response_state, key::watch_days, 0)))}));
	const DictRef action = state.new_dict();
	state.set(action, str(key::id), str(key::site_response));
	state.set(action, str(key::label), str(field_text(state, response_state, key::action_label, key::secure_route)));
	state.set(action, str(key::summary), str(join_atoms(state, key::space_bar_space, summary_parts)));
	state.set(action, str(key::disabled), bool_value(disabled));
	return action;
}

DictRef _issue_active_site_response(State &state, DictRef session) {
	const DictRef node_result = _find_context_resource_node(state, session);
	if (gd::int_field(state, node_result, key::index, -1) < 0) {
		return ok_message(state, false, key::no_logistics_site_is_ready_for);
	}
	const Value node = field_or_new_dict(state, node_result, key::node);
	return _issue_resource_site_response(state, session, vfield_text(state, node, key::placement_id, key::empty), key::field);
}

DictRef _issue_resource_site_response(State &state, DictRef session, Atom placement_id, Atom origin) {
	normalize_overworld_state(state, session);
	const DictRef node_result = _find_resource_node_by_placement(state, session, placement_id);
	if (gd::int_field(state, node_result, key::index, -1) < 0) {
		return ok_message(state, false, key::that_logistics_site_is_no_longer);
	}
	// var node = node_result.get("node", {}): the live entry of resource_nodes.
	DictRef node = gd::as_dict(field_or_new_dict(state, node_result, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, field_text(state, node, key::site_id, key::empty));
	if (!_resource_site_is_persistent(state, site) || field_text(state, node, key::collected_by_faction_id, key::empty) != key::player) {
		return ok_message(state, false, key::only_player_controlled_logistics_sites_can);
	}
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (gd::int_field(state, response_state, key::watch_days, 0) <= 0) {
		return ok_message(state, false, key::this_site_has_no_authored_response);
	}
	if (gd::bool_field(state, response_state, key::active, false)) {
		return ok_message(state, false, gd::format(state, key::s_is_already_active_here, {str(field_text(state, response_state, key::action_label, key::route_security))}));
	}
	const Value cost = field_or_new_dict(state, response_state, key::resource_cost);
	if (!_can_afford(state, session, cost)) {
		return ok_message(state, false, gd::format(state, key::insufficient_resources_for_s, {str(field_text(state, response_state, key::action_label, key::that_response))}));
	}
	Value lower_expression;
	const DictRef movement_result = hero_command_rules::spend_active_hero_movement(
			state,
			session,
			gd::int_field(state, response_state, key::movement_cost, 0),
			to_lower(state, field_text(state, response_state, key::action_label, key::response_order), lower_expression));
	if (!gd::bool_field(state, movement_result, key::ok, false)) {
		return movement_result;
	}
	if (gd::is_dict(cost) && !gd::is_empty(state, cost.ref)) {
		_spend_resources(state, session, cost);
	}

	const DictRef active_hero = hero_command_rules::active_hero(state, session);
	const Atom commander_id = field_text(state, active_hero, key::id, key::empty);
	const Atom commander_name = field_text(state, active_hero, key::name, key::the_commander);
	const int64_t security_rating = _route_security_rating_for_hero(state, active_hero);
	const DictRef linked_town_result = _resource_node_linked_town(state, session, node, key::player);
	const int64_t linked_index = gd::int_field(state, linked_town_result, key::index, -1);
	DictRef delivery_plan = state.new_dict();
	if (linked_index >= 0) {
		delivery_plan = _player_reserve_delivery_plan(state, session, gd::as_dict(field_or_new_dict(state, linked_town_result, key::town)), response_state);
	}
	const int64_t day = ai::session_int(state, session, key::day);
	state.set(node, str(key::response_origin), str(origin));
	state.set(node, str(key::response_source_town_id), str(vfield_text(state, field_or_new_dict(state, linked_town_result, key::town), key::placement_id, key::empty)));
	state.set(node, str(key::response_last_day), int_value(day));
	state.set(node, str(key::response_until_day), int_value(gd::sub(gd::add(day, compat::engine_max<int64_t>(1, gd::int_field(state, response_state, key::watch_days, 0))), 1)));
	state.set(node, str(key::response_commander_id), str(commander_id));
	state.set(node, str(key::response_security_rating), int_value(security_rating));
	node = _clear_resource_site_delivery(state, node);
	if (!gd::is_empty(state, delivery_plan)) {
		const Value source_town = field_or_new_dict(state, linked_town_result, key::town);
		const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
		const Value available_recruits = ai::vget(state, source_town, key::available_recruits, dict_value(state.new_dict()));
		const DictRef remaining = _consume_recruit_payload(state, available_recruits, field_or_new_dict(state, delivery_plan, key::manifest));
		set_keyed(state, source_town, key::available_recruits, dict_value(remaining));
		set_indexed(state, towns, linked_index, source_town);
		state.set(session_view::overworld(state, session), str(key::towns), towns);
		state.set(node, str(key::delivery_controller_id), str(key::player));
		state.set(node, str(key::delivery_origin_town_id), str(vfield_text(state, source_town, key::placement_id, key::empty)));
		state.set(node, str(key::delivery_target_kind), str(field_text(state, delivery_plan, key::target_kind, key::empty)));
		state.set(node, str(key::delivery_target_id), str(field_text(state, delivery_plan, key::target_id, key::empty)));
		state.set(node, str(key::delivery_target_label), str(field_text(state, delivery_plan, key::target_label, key::empty)));
		state.set(node, str(key::delivery_arrival_day), int_value(gd::add(ai::session_int(state, session, key::day), compat::engine_max<int64_t>(1, gd::int_field(state, delivery_plan, key::eta_days, 1)))));
		state.set(node, str(key::delivery_manifest), dict_value(_normalize_recruit_payload(state, field_or_new_dict(state, delivery_plan, key::manifest))));
	}
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	set_indexed(state, nodes, gd::int_field(state, node_result, key::index, -1), dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);

	std::vector<Atom> messages;
	const int64_t watch_days = gd::int_field(state, response_state, key::watch_days, 0);
	messages.push_back(gd::format(state, key::s_commits_s_at_s_for, {
			str(commander_name),
			str(to_lower(state, field_text(state, response_state, key::action_label, key::route_security_2), lower_expression)),
			str(field_text(state, site, key::name, key::the_site)),
			int_value(watch_days),
			str(plural_s(gd::int_field(state, response_state, key::watch_days, 0))),
	}));
	const Atom cost_summary = _describe_resource_delta(state, cost);
	if (cost_summary != key::empty) {
		messages.push_back(gd::format(state, key::spent_s, {str(cost_summary)}));
	}
	const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
	if (impact_summary != key::empty) {
		messages.push_back(gd::format(state, key::escort_line_s_while_active, {str(impact_summary)}));
	}
	messages.push_back(gd::format(state, key::route_escort_strength_d, {int_value(security_rating)}));
	if (!gd::is_empty(state, delivery_plan)) {
		const Atom site_name = field_text(state, site, key::name, key::the_route);
		const Atom recruit_summary = _describe_recruit_delta(state, field_or_new_dict(state, delivery_plan, key::manifest));
		const Atom target_label = field_text(state, delivery_plan, key::target_label, key::the_front);
		const int64_t eta_days = gd::int_field(state, delivery_plan, key::eta_days, 1);
		messages.push_back(gd::format(state, key::s_loads_s_for_s_d, {
				str(site_name),
				str(recruit_summary),
				str(target_label),
				int_value(eta_days),
				str(plural_s(gd::int_field(state, delivery_plan, key::eta_days, 1))),
		}));
	}
	Atom relief_message = key::empty;
	if (linked_index >= 0 && gd::int_field(state, response_state, key::recovery_relief, 0) > 0) {
		relief_message = relieve_town_recovery_pressure(
				state,
				session,
				vfield_text(state, field_or_new_dict(state, linked_town_result, key::town), key::placement_id, key::empty),
				gd::int_field(state, response_state, key::recovery_relief, 0),
				field_text(state, site, key::name, key::frontier_route_2));
	}
	if (relief_message != key::empty) {
		messages.push_back(relief_message);
	}
	const DictRef result = _finalize_action_result(state, session, true, join_atoms(state, key::space, messages), true, false, state.new_dict());
	const DictRef context = state.new_dict();
	state.set(context, str(key::placement_id), str(field_text(state, node, key::placement_id, key::empty)));
	state.set(context, str(key::site_id), str(field_text(state, node, key::site_id, key::empty)));
	state.set(context, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
	state.set(context, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
	return _attach_post_action_recap(state, result, session, key::site_response, context);
}

int64_t _army_unit_count(State &state, const Value &stacks, Atom unit_id) {
	int64_t total = 0;
	if (gd::is_array(stacks)) {
		for (const Value &stack_value : gd::items(state, stacks)) {
			if (gd::is_dict(stack_value) && field_text(state, stack_value.ref, key::unit_id, key::empty) == unit_id) {
				total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, stack_value.ref, key::count, 0)));
			}
		}
	}
	return total;
}

} // namespace overworld_rules

namespace hero_command_rules {

DictRef spend_active_hero_movement(State &state, DictRef session, int64_t amount, Atom reason) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	if (amount <= 0) {
		// int(session.overworld.get("movement", {}).get("current", 0))
		int64_t remaining = 0;
		Value movement;
		if (state.lookup(session_view::overworld(state, session), str(key::movement), movement)) {
			remaining = gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)));
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::message), str(key::empty));
		state.set(result, str(key::remaining_movement), int_value(remaining));
		return result;
	}
	commit_active_hero(state, session);
	const DictRef hero = active_hero(state, session);
	if (gd::is_empty(state, hero)) {
		return ok_message(state, false, key::no_active_commander_is_available);
	}
	const Value heroes = field_or_new_array(state, session_view::overworld(state, session), key::player_heroes);
	const Atom hero_id = field_text(state, hero, key::id, key::empty);
	const int64_t hero_index = _hero_index_by_id(state, gd::as_array(heroes), hero_id);
	if (hero_index < 0) {
		return ok_message(state, false, key::the_active_commander_could_not_be);
	}

	const Value hero_movement = field_or_new_dict(state, hero, key::movement);
	const DictRef movement = _normalize_movement(state, hero_movement, movement_max_for_hero(state, hero, dict_value(session)));
	const int64_t current = gd::int_field(state, movement, key::current, 0);
	if (current < amount) {
		const Atom reason_clause = reason != key::empty ? gd::format(state, key::for_s, {str(reason)}) : key::empty;
		return ok_message(state, false, gd::format(state, key::s_needs_d_movement_s_but, {
				str(field_text(state, hero, key::name, key::the_commander)),
				int_value(amount),
				str(reason_clause),
				int_value(current),
		}));
	}

	state.set(movement, str(key::current), int_value(gd::sub(current, amount)));
	state.set(hero, str(key::movement), dict_value(movement));
	set_indexed(state, heroes, hero_index, dict_value(hero));
	state.set(session_view::overworld(state, session), str(key::player_heroes), heroes);
	_sync_active_hero_mirror(state, session);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(key::empty));
	state.set(result, str(key::remaining_movement), int_value(gd::int_field(state, movement, key::current, 0)));
	return result;
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
