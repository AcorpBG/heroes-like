// OverworldRules: a town taken after a battle (capture, its claim, a front
// stabilized), the town front state and the town readiness reads it needs;
// TownRules.teach_visiting_heroes, which a capture by the player runs.

#include "aurelion_rules/port/battle_ends.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <string>

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

// d.get(field, {}) where the result is passed on: the value, or a new Dictionary.
Value field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// var x: Dictionary = d.get(field, {}): the field (another type is a
// ScriptError), or a new empty Dictionary when it is missing.
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef dict_field_or_empty(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// String(town.get("owner", "neutral")).
Atom town_owner(State &state, DictRef town) {
	return gd::stringify(state, gd::field_or(state, town, key::owner, str(key::neutral)));
}

// container[index] = value of an untyped Array or Dictionary.
void set_index(State &state, const Value &container, int64_t index, const Value &value) {
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

// {"ok": false, "town": {}, "front": {}}.
DictRef no_front(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	state.set(result, str(key::front), dict_value(state.new_dict()));
	return result;
}

// _town_logistics_state(session, town) of a session that may be null: a null
// session has no read-scope key, and _compute_town_logistics_state answers the
// empty state for it.
DictRef logistics_for(State &state, const Value &session, DictRef town) {
	if (session.kind == Kind::Nil) {
		return overworld_rules::_empty_town_logistics_state(state);
	}
	return overworld_rules::_town_logistics_state(state, gd::as_dict(session), town);
}

// _town_recovery_state(session, town, logistics) and _town_occupation_state(
// session, town) of a session that may be null: a town's base readiness and
// quality (town_battle_readiness(town) and the others without a session).
DictRef recovery_for(State &state, const Value &session, DictRef town, DictRef logistics) {
	return overworld_rules::_town_recovery_state(state, session, town, logistics);
}

DictRef occupation_for(State &state, const Value &session, DictRef town) {
	return overworld_rules::_town_occupation_state(state, session, town);
}

} // namespace

namespace overworld_rules {

void _teach_visiting_town_spells(State &state, DictRef session, DictRef town) {
	town_rules::teach_visiting_heroes(state, session, town);
}

DictRef town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics) {
	const Atom extra = gd::is_empty(state, precomputed_development_metrics)
			? key::empty
			: state.intern(compat::sha256_text(gd::json_stringify(state, dict_value(precomputed_development_metrics))));
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::front, town, extra);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_front_state(state, session, town, precomputed_development_metrics);
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

Atom capture_town_by_placement(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	return _claim_town(state, session, town_result);
}

DictRef stabilize_town_front(State &state, DictRef session, Atom placement_id, Atom faction_id, Atom source, int64_t bonus_days) {
	if (placement_id == key::empty || faction_id == key::empty) {
		return no_front(state);
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return no_front(state);
	}
	const Value town = field_or_new(state, town_result, key::town);
	const Value towns = state.get(session_view::overworld(state, session), str(key::towns), array_value(state.new_array()));
	const DictRef town_dict = gd::as_dict(town);
	state.set(town_dict, str(key::front), dict_value(_town_front_stabilizing_state(state, session, town_dict, faction_id, source, key::empty, bonus_days)));
	set_index(state, towns, gd::int_field(state, town_result, key::index, -1), town);
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	const DictRef front = _town_front_state(state, session, town_dict, state.new_dict());
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::town), town);
	state.set(result, str(key::front), dict_value(front));
	return result;
}

int64_t _town_reinforcement_quality(State &state, DictRef town, const Value &session, DictRef metric_context) {
	static const char *const where = "OverworldRules._town_reinforcement_quality";
	int64_t quality = _weighted_recruit_value(state, dict_value(_town_weekly_growth(state, town, session, metric_context)));
	quality = gd::add(quality, _town_role_quality_bonus(state, _town_strategic_role(state, town)));
	DictRef logistics = typed_dict_field(state, metric_context, key::logistics);
	if (gd::is_empty(state, logistics)) {
		logistics = logistics_for(state, session, town);
	}
	quality = gd::add(quality, gd::int_field(state, logistics, key::quality_bonus, 0));
	quality = gd::add(quality, gd::int_field(state, logistics, key::response_quality_bonus, 0));
	quality = gd::sub(quality, gd::int_field(state, logistics, key::gap_quality_penalty, 0));
	DictRef recovery = typed_dict_field(state, metric_context, key::recovery);
	if (gd::is_empty(state, recovery)) {
		recovery = recovery_for(state, session, town, logistics);
	}
	quality = gd::sub(quality, gd::int_field(state, recovery, key::quality_penalty, 0));
	DictRef capital_project = typed_dict_field(state, metric_context, key::capital_project);
	if (gd::is_empty(state, capital_project)) {
		capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	}
	quality = gd::add(quality, gd::int_field(state, capital_project, key::quality_bonus, 0));
	quality = gd::sub(quality, gd::int_field(state, capital_project, key::quality_penalty, 0));
	DictRef occupation = typed_dict_field(state, metric_context, key::occupation);
	if (gd::is_empty(state, occupation)) {
		occupation = occupation_for(state, session, town);
	}
	quality = gd::sub(quality, gd::int_field(state, occupation, key::quality_penalty, 0));
	return compat::engine_max<int64_t>(0, quality);
}

int64_t _town_battle_readiness(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality) {
	static const char *const where = "OverworldRules._town_battle_readiness";
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	int64_t readiness = compat::float_to_int(compat::godot_round(static_cast<double>(_town_garrison_strength(state, town)) / 12.0));
	const int64_t quality = reinforcement_quality >= 0 ? reinforcement_quality : _town_reinforcement_quality(state, town, session, metric_context);
	readiness = gd::add(readiness, compat::float_to_int(compat::godot_round(static_cast<double>(quality) / 6.0)));
	readiness = gd::add(readiness, _readiness_bonus_from_profile(state, field_or_new(state, faction, key::recruitment)));
	readiness = gd::add(readiness, _readiness_bonus_from_profile(state, field_or_new(state, town_template, key::recruitment)));
	readiness = gd::add(readiness, _town_building_bonus_total(state, town, key::readiness_bonus));
	readiness = gd::add(readiness, gd::mul(_town_spell_tier(state, town), 6));
	readiness = gd::add(readiness, _town_role_readiness_bonus(state, _town_strategic_role(state, town)));
	DictRef logistics = typed_dict_field(state, metric_context, key::logistics);
	if (gd::is_empty(state, logistics)) {
		logistics = logistics_for(state, session, town);
	}
	readiness = gd::add(readiness, gd::int_field(state, logistics, key::readiness_bonus, 0));
	readiness = gd::add(readiness, gd::int_field(state, logistics, key::response_readiness_bonus, 0));
	readiness = gd::sub(readiness, gd::int_field(state, logistics, key::gap_readiness_penalty, 0));
	DictRef recovery = typed_dict_field(state, metric_context, key::recovery);
	if (gd::is_empty(state, recovery)) {
		recovery = recovery_for(state, session, town, logistics);
	}
	readiness = gd::sub(readiness, gd::int_field(state, recovery, key::readiness_penalty, 0));
	DictRef capital_project = typed_dict_field(state, metric_context, key::capital_project);
	if (gd::is_empty(state, capital_project)) {
		capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	}
	readiness = gd::add(readiness, compat::float_to_int(compat::godot_round(static_cast<double>(gd::int_field(state, capital_project, key::defense_bonus, 0)) / 8.0)));
	readiness = gd::sub(readiness, gd::int_field(state, capital_project, key::readiness_penalty, 0));
	DictRef occupation = typed_dict_field(state, metric_context, key::occupation);
	if (gd::is_empty(state, occupation)) {
		occupation = occupation_for(state, session, town);
	}
	readiness = gd::sub(readiness, gd::int_field(state, occupation, key::readiness_penalty, 0));
	return compat::engine_max<int64_t>(0, readiness);
}

DictRef _town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics) {
	DictRef front = _normalize_town_front_state(state, field_or_new(state, town, key::front));
	front = _retake_front_from_legacy_state(state, session, town, front);
	const Atom faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	const Atom state_id = ai::string_or_empty(state, front, key::state);
	const Atom owner = town_owner(state, town);
	const bool objective_anchor = _town_is_objective_anchor(state, session, ai::string_or_empty(state, town, key::placement_id));
	const Atom role = _town_strategic_role(state, town);
	Atom enemy_label = key::empty;
	if (faction_id != key::empty) {
		const DictRef faction = gd::content_row(state, ContentTable::Faction, player_identity_rules::faction_id(state, session, faction_id));
		enemy_label = gd::stringify(state, gd::field_or(state, faction, key::name, str(faction_id)));
	}
	const int64_t base_priority = _town_front_priority_seed(state, role, objective_anchor);
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days_since_change = compat::engine_max<int64_t>(0, gd::sub(day, gd::int_field(state, front, key::last_change_day, 0)));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(false));
	state.set(result, str(key::mode), str(key::empty));
	state.set(result, str(key::faction_id), str(faction_id));
	state.set(result, str(key::enemy_label), str(enemy_label));
	state.set(result, str(key::priority_bonus), int_value(0));
	state.set(result, str(key::pressure_bonus), int_value(0));
	state.set(result, str(key::threshold_reduction), int_value(0));
	state.set(result, str(key::garrison_bonus), int_value(0));
	state.set(result, str(key::build_bonus), int_value(0));
	state.set(result, str(key::days_since_change), int_value(days_since_change));
	state.set(result, str(key::days_remaining), int_value(0));
	state.set(result, str(key::summary), str(key::empty));
	state.set(result, str(key::compact_summary), str(key::empty));
	state.set(result, str(key::public_clause), str(key::empty));
	state.set(result, str(key::state), dict_value(front));
	gd::merge(state, result, player_identity_rules::identity_fields(state, session, faction_id), true);
	if (faction_id == key::empty) {
		return result;
	}
	if (state_id != key::retake && state_id != key::stabilizing && state_id != key::defend) {
		return result;
	}
	if (state_id == key::retake && owner != key::player) {
		return result;
	}
	if ((state_id == key::stabilizing || state_id == key::defend) && owner != key::enemy) {
		return result;
	}
	DictRef logistics = dict_field_or_empty(state, precomputed_development_metrics, key::logistics);
	if (gd::is_empty(state, logistics)) {
		logistics = _town_logistics_state(state, session, town);
	}
	DictRef recovery = dict_field_or_empty(state, precomputed_development_metrics, key::recovery);
	if (gd::is_empty(state, recovery)) {
		recovery = _town_recovery_state(state, session, town, logistics);
	}
	DictRef capital_project = dict_field_or_empty(state, precomputed_development_metrics, key::capital_project);
	if (gd::is_empty(state, capital_project)) {
		capital_project = _town_capital_project_state(state, town, dict_value(session), logistics, recovery);
	}
	if (state_id == key::retake) {
		if (owner != key::player) {
			return result;
		}
		const int64_t recency_bonus = compat::engine_max<int64_t>(0, gd::sub(54, gd::mul(gd::int_field(state, result, key::days_since_change, 0), 8)));
		const int64_t battle_readiness = state.has(precomputed_development_metrics, str(key::battle_readiness))
				? gd::int_field(state, precomputed_development_metrics, key::battle_readiness, 0)
				: _town_battle_readiness(state, town, dict_value(session), state.new_dict(), -1);
		int64_t weakness_bonus = compat::engine_max<int64_t>(0, gd::sub(34, battle_readiness));
		weakness_bonus = gd::add(weakness_bonus, gd::mul(gd::int_field(state, recovery, key::pressure, 0), 8));
		weakness_bonus = gd::add(weakness_bonus, gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 14));
		if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
			weakness_bonus = gd::add(weakness_bonus, 18);
		}
		const int64_t priority_bonus = gd::add(gd::add(base_priority, recency_bonus), weakness_bonus);
		int64_t threshold_reduction = priority_bonus >= 140 ? 1 : 0;
		if (role == key::capital || objective_anchor) {
			threshold_reduction += 1;
		}
		state.set(result, str(key::active), bool_value(true));
		state.set(result, str(key::mode), str(key::retake));
		state.set(result, str(key::priority_bonus), int_value(priority_bonus));
		state.set(result, str(key::pressure_bonus), int_value(compat::engine_clamp<int64_t>(compat::float_to_int(compat::godot_floor(static_cast<double>(priority_bonus) / 115.0)), 1, 4)));
		state.set(result, str(key::threshold_reduction), int_value(compat::engine_clamp<int64_t>(threshold_reduction, 0, 2)));
		state.set(result, str(key::summary), str(gd::format(state, key::s_still_treats_s_as_a, {str(enemy_label), str(_town_name(state, town))})));
		state.set(result, str(key::compact_summary), str(gd::format(state, key::retake_s, {str(_town_name(state, town))})));
		state.set(result, str(key::public_clause), str(key::retake_orders_still_center_on_the));
		return result;
	}
	if (state_id == key::stabilizing) {
		if (owner != key::enemy) {
			return result;
		}
		const int64_t stabilize_until_day = gd::int_field(state, front, key::stabilize_until_day, 0);
		const int64_t days_remaining = compat::engine_max<int64_t>(0, gd::add(gd::sub(stabilize_until_day, ai::session_int(state, session, key::day)), 1));
		if (days_remaining <= 0 && !gd::bool_field(state, recovery, key::active, false)) {
			return result;
		}
		int64_t pressure_bonus = gd::mul(gd::int_field(state, recovery, key::pressure, 0), 10);
		pressure_bonus = gd::add(pressure_bonus, gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 14));
		pressure_bonus = gd::add(pressure_bonus, gd::mul(gd::int_field(state, logistics, key::threatened_count, 0), 8));
		pressure_bonus = gd::add(pressure_bonus, gd::mul(compat::engine_max<int64_t>(0, gd::sub(days_remaining, 1)), 12));
		if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
			pressure_bonus = gd::add(pressure_bonus, 14);
		}
		state.set(result, str(key::active), bool_value(true));
		state.set(result, str(key::mode), str(key::stabilizing));
		state.set(result, str(key::days_remaining), int_value(days_remaining));
		state.set(result, str(key::priority_bonus), int_value(gd::add(base_priority, pressure_bonus)));
		state.set(result, str(key::garrison_bonus), int_value(gd::add(65, pressure_bonus)));
		state.set(result, str(key::build_bonus), int_value(gd::add(gd::add(45, gd::mul(gd::int_field(state, recovery, key::pressure, 0), 10)), gd::mul(compat::engine_max<int64_t>(0, gd::sub(days_remaining, 1)), 8))));
		state.set(result, str(key::summary), str(gd::format(state, key::s_is_still_stabilizing_s, {str(enemy_label), str(_town_name(state, town))})));
		state.set(result, str(key::compact_summary), str(gd::format(state, key::stabilize_s, {str(_town_name(state, town))})));
		state.set(result, str(key::public_clause), str(days_remaining > 0
						? gd::format(state, key::the_reclaimed_walls_stay_on_stabilization, {int_value(days_remaining), str(days_remaining == 1 ? key::empty : key::s)})
						: key::the_reclaimed_walls_are_still_being));
		return result;
	}
	// "defend"
	if (owner != key::enemy) {
		return result;
	}
	const int64_t defend_until_day = compat::engine_max<int64_t>(
			gd::int_field(state, front, key::defense_until_day, 0),
			gd::int_field(state, front, key::stabilize_until_day, 0));
	const int64_t defend_days_remaining = compat::engine_max<int64_t>(0, gd::add(gd::sub(defend_until_day, ai::session_int(state, session, key::day)), 1));
	if (defend_days_remaining <= 0 && !gd::bool_field(state, recovery, key::active, false)) {
		return result;
	}
	int64_t defense_pressure_bonus = gd::mul(gd::int_field(state, recovery, key::pressure, 0), 8);
	defense_pressure_bonus = gd::add(defense_pressure_bonus, gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 10));
	defense_pressure_bonus = gd::add(defense_pressure_bonus, gd::mul(gd::int_field(state, logistics, key::threatened_count, 0), 12));
	defense_pressure_bonus = gd::add(defense_pressure_bonus, gd::mul(compat::engine_max<int64_t>(0, gd::sub(defend_days_remaining, 1)), 10));
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		defense_pressure_bonus = gd::add(defense_pressure_bonus, 14);
	}
	state.set(result, str(key::active), bool_value(true));
	state.set(result, str(key::mode), str(key::stabilizing));
	state.set(result, str(key::days_remaining), int_value(defend_days_remaining));
	state.set(result, str(key::priority_bonus), int_value(gd::add(base_priority, defense_pressure_bonus)));
	state.set(result, str(key::garrison_bonus), int_value(gd::add(70, defense_pressure_bonus)));
	state.set(result, str(key::build_bonus), int_value(gd::add(gd::add(42, gd::mul(gd::int_field(state, recovery, key::pressure, 0), 8)), gd::mul(compat::engine_max<int64_t>(0, gd::sub(defend_days_remaining, 1)), 8))));
	state.set(result, str(key::summary), str(gd::format(state, key::s_is_holding_s_after_a, {str(enemy_label), str(_town_name(state, town))})));
	state.set(result, str(key::compact_summary), str(gd::format(state, key::defend_s, {str(_town_name(state, town))})));
	state.set(result, str(key::public_clause), str(defend_days_remaining > 0
					? gd::format(state, key::the_reclaimed_walls_stay_under_defender, {int_value(defend_days_remaining), str(defend_days_remaining == 1 ? key::empty : key::s)})
					: key::the_reclaimed_walls_are_still_under));
	return result;
}

Atom _normalized_enemy_front_faction_id(State &state, DictRef session, DictRef front, DictRef town) {
	const Atom faction_id = player_identity_rules::controller_id(state, front, key::empty);
	if (faction_id != key::empty && !gd::is_empty(state, _enemy_state_for_faction(state, session, faction_id))) {
		return faction_id;
	}
	const Atom template_faction_id = _town_faction_id(state, town);
	if (template_faction_id != key::empty && !gd::is_empty(state, _enemy_state_for_faction(state, session, template_faction_id))) {
		return template_faction_id;
	}
	return key::empty;
}

DictRef _retake_front_from_legacy_state(State &state, DictRef session, DictRef town, DictRef front) {
	if (gd::is_empty(state, town)) {
		return front;
	}
	if (ai::string_or_empty(state, front, key::state) != key::empty) {
		return front;
	}
	const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
	if (town_owner(state, town) != key::player || !_scenario_town_started_enemy(state, session, placement_id)) {
		return front;
	}
	const Atom faction_id = _town_faction_id(state, town);
	if (faction_id == key::empty || gd::is_empty(state, _enemy_state_for_faction(state, session, faction_id))) {
		return front;
	}
	const DictRef inferred = gd::deep_duplicate_dict(state, front);
	state.set(inferred, str(key::state), str(key::retake));
	gd::merge(state, inferred, player_identity_rules::identity_fields(state, session, faction_id), true);
	const DictRef recovery = _normalize_town_recovery_state(state, field_or_new(state, town, key::recovery));
	const int64_t last_event_day = gd::int_field(state, recovery, key::last_event_day, ai::session_int(state, session, key::day));
	state.set(inferred, str(key::last_change_day), int_value(compat::engine_max<int64_t>(0, last_event_day)));
	state.set(inferred, str(key::last_owner), str(key::enemy));
	state.set(inferred, str(key::capture_count), int_value(compat::engine_max<int64_t>(1, gd::int_field(state, inferred, key::capture_count, 0))));
	return inferred;
}

int64_t _town_front_priority_seed(State &, Atom role, bool objective_anchor) {
	int64_t priority = 88;
	if (role == key::capital) {
		priority += 92;
	} else if (role == key::stronghold) {
		priority += 54;
	}
	if (objective_anchor) {
		priority += 30;
	}
	return priority;
}

int64_t _town_occupation_seed_pressure(State &state, DictRef session, DictRef town) {
	int64_t pressure = 3;
	const Atom role = _town_strategic_role(state, town);
	if (role == key::capital) {
		pressure += 4;
	} else if (role == key::stronghold) {
		pressure += 2;
	} else {
		pressure += 1;
	}
	if (_town_is_objective_anchor(state, session, ai::string_or_empty(state, town, key::placement_id))) {
		pressure += 1;
	}
	if (_town_garrison_headcount(state, town) > 0) {
		pressure += 1;
	}
	return compat::engine_clamp<int64_t>(pressure, 4, 10);
}

int64_t _town_role_quality_bonus(State &, Atom role) {
	if (role == key::capital) {
		return 10;
	}
	if (role == key::stronghold) {
		return 5;
	}
	return 0;
}

int64_t _town_role_readiness_bonus(State &, Atom role) {
	if (role == key::capital) {
		return 12;
	}
	if (role == key::stronghold) {
		return 6;
	}
	return 0;
}

int64_t _readiness_bonus_from_profile(State &state, const Value &profile) {
	if (!gd::is_dict(profile)) {
		return 0;
	}
	return compat::engine_max<int64_t>(0, gd::int_field(state, profile.ref, key::readiness_bonus, 0));
}

int64_t _town_spell_tier(State &state, DictRef town) {
	int64_t max_tier = 0;
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		max_tier = compat::engine_max<int64_t>(max_tier, gd::int_field(state, building, key::spell_tier, 0));
	}
	return max_tier;
}

int64_t _town_garrison_strength(State &state, DictRef town) {
	int64_t total_strength = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, stack.ref, key::unit_id));
		const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
		int64_t strength = gd::int_field(state, unit, key::hp, 1);
		strength = gd::add(strength, gd::int_field(state, unit, key::min_damage, 1));
		strength = gd::add(strength, gd::int_field(state, unit, key::max_damage, 1));
		strength = gd::add(strength, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
		total_strength = gd::add(total_strength, gd::mul(count, compat::engine_max<int64_t>(6, strength)));
	}
	return total_strength;
}

Atom _claim_town(State &state, DictRef session, DictRef town_result) {
	Value town = field_or_new(state, town_result, key::town);
	if (gd::int_field(state, town_result, key::index, -1) < 0 || ai::vempty(state, town)) {
		return key::empty;
	}
	const Atom placement_id = gd::stringify(state, ai::vget(state, town, key::placement_id, str(key::empty)));
	const DictRef transition = transition_town_control(state, session, placement_id, key::player, key::empty, key::captured_town);
	town = state.get(transition, str(key::town), town);
	const DictRef town_dict = gd::as_dict(town);
	state.set(town_dict, str(key::recovery), dict_value(_normalize_town_recovery_state(state, field_or_new(state, town_dict, key::recovery))));
	state.set(town_dict, str(key::occupation), dict_value(_normalize_town_occupation_state(state, field_or_new(state, town_dict, key::occupation))));
	const Value towns = state.get(session_view::overworld(state, session), str(key::towns), array_value(state.new_array()));
	set_index(state, towns, gd::int_field(state, town_result, key::index, -1), town);
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	return gd::format(state, key::captured_s, {str(_town_name(state, town_dict))});
}

int64_t _town_garrison_headcount(State &state, DictRef town) {
	int64_t headcount = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (gd::is_dict(stack)) {
			headcount = gd::add(headcount, compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0)));
		}
	}
	return headcount;
}

DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id) {
	for (const Value &enemy_state : gd::field_items(state, session_view::overworld(state, session), str(key::enemy_states))) {
		if (gd::is_dict(enemy_state) && player_identity_rules::controller_id(state, enemy_state.ref, key::empty) == faction_id) {
			return enemy_state.ref;
		}
	}
	return state.new_dict();
}

bool _scenario_town_started_enemy(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return false;
	}
	const Atom scenario_id = gd::to_string(gd::index(state, session, str(key::scenario_id)));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
	for (const Value &town : gd::field_items(state, scenario, str(key::towns))) {
		if (gd::is_dict(town) && ai::string_or_empty(state, town.ref, key::placement_id) == placement_id) {
			return town_owner(state, town.ref) == key::enemy;
		}
	}
	return false;
}

} // namespace overworld_rules

namespace town_rules {

DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town) {
	// Explicit arrival/build mutation: learning has no mana, gold or mastery
	// cost. session == null cannot happen: a session is its view.
	const DictRef learned = state.new_dict();
	const auto result = [&](int64_t count) {
		const DictRef out = state.new_dict();
		state.set(out, str(key::learned), dict_value(learned));
		state.set(out, str(key::count), int_value(count));
		return out;
	};
	if (gd::is_empty(state, town) || gd::stringify(state, state.get(town, str(key::owner), str(key::empty))) != key::player) {
		return result(0);
	}
	const ArrayRef spell_ids = accessible_spell_ids(state, town);
	if (state.array_size(spell_ids) == 0) {
		return result(0);
	}
	hero_command_rules::commit_active_hero(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_id = gd::stringify(state, state.get(overworld, str(key::active_hero_id), str(key::empty)));
	// var heroes: Array = session.overworld.get("player_heroes", [])
	const ArrayRef heroes = gd::as_array(state.get(overworld, str(key::player_heroes), array_value(state.new_array())));
	int64_t count = 0;
	for (int64_t index = 0; index < static_cast<int64_t>(state.array_size(heroes)); ++index) {
		// var hero: Dictionary = heroes[index]
		DictRef hero = gd::as_dict(state.at(heroes, index));
		if (!hero_command_rules::_hero_is_stationed_at_town(state, hero, town)) {
			continue;
		}
		const ArrayRef learned_ids = state.new_array();
		for (const Value &spell_id_value : gd::items(state, array_value(spell_ids))) {
			const Atom spell_id = gd::to_string(spell_id_value);
			if (spell_rules::knows_spell(state, hero, spell_id)) {
				continue;
			}
			const DictRef learn = spell_rules::learn_spell(state, hero, spell_id);
			if (gd::bool_field(state, learn, key::ok, false)) {
				hero = gd::as_dict(gd::index(state, learn, str(key::hero)));
				state.append(learned_ids, str(spell_id));
			}
		}
		if (state.array_size(learned_ids) == 0) {
			continue;
		}
		state.set_at(heroes, index, dict_value(hero));
		if (gd::stringify(state, state.get(hero, str(key::id), str(key::empty))) == active_id) {
			state.set(overworld, str(key::hero), dict_value(hero));
		}
		state.set(learned, str(gd::stringify(state, gd::index(state, hero, str(key::id)))), array_value(learned_ids));
		count += static_cast<int64_t>(state.array_size(learned_ids));
	}
	state.set(overworld, str(key::player_heroes), array_value(heroes));
	return result(count);
}

} // namespace town_rules

} // namespace aurelion::rules::port
