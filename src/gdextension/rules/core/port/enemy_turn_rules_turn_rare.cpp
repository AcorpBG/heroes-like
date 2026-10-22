// EnemyTurnRules: the paths of the computer players' day the six seeds do not run (Phase 4, slice 4.2): saved hero
// task boards, the capital and front states behind the raid limits, and the older configs' helpers.

#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/difficulty_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) and declared only there.
namespace enemy_turn_rules {
DictRef _find_state(State &state, const Value &states, Atom faction_id);
ArrayRef _normalize_string_array(State &state, const Value &value);
} // namespace enemy_turn_rules

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
namespace player_rules = player_identity_rules;

// max() and clamp() of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}
int64_t iclamp(int64_t x, int64_t lo, int64_t hi) {
	return compat::engine_clamp<int64_t>(x, lo, hi);
}

// String(d.get(field, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(field, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), fallback));
}

// d.get(field, {}) and d.get(field, []) where the value is kept or passed on:
// a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// value in [ids...] of a String.
bool one_of(Atom value, std::initializer_list<Atom> ids) {
	for (const Atom id : ids) {
		if (id == value) {
			return true;
		}
	}
	return false;
}

// separator.join(values.slice(0, count)) of an Array of Strings.
Atom join_first(State &state, const char *separator, ArrayRef values, int64_t count) {
	std::string joined;
	for (int64_t index = 0; index < count; ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += gd::text(state, state.at(values, index));
	}
	return state.intern(joined);
}

// {"ok": false, "invalid_reason": reason, "sanitized_field_count": count}.
DictRef invalid_task_report(State &state, Atom reason, int64_t sanitized_field_count) {
	const DictRef report = state.new_dict();
	state.set(report, str(key::ok), bool_value(false));
	state.set(report, str(key::invalid_reason), str(reason));
	state.set(report, str(key::sanitized_field_count), int_value(sanitized_field_count));
	return report;
}

// The report of a hero task board that is dropped.
DictRef dropped_board_report(State &state, Atom reason, int64_t sanitized_field_count) {
	const DictRef report = state.new_dict();
	state.set(report, str(key::ok), bool_value(false));
	state.set(report, str(key::normalized_present), bool_value(false));
	state.set(report, str(key::invalid_reason), str(reason));
	state.set(report, str(key::input_task_count), int_value(0));
	state.set(report, str(key::normalized_task_count), int_value(0));
	state.set(report, str(key::dropped_task_count), int_value(0));
	state.set(report, str(key::sanitized_field_count), int_value(sanitized_field_count));
	state.set(report, str(key::observed_policy), str(key::dropped_invalid_board));
	return report;
}

// d[field] = int(d.get(field, 0)) + amount.
void add_count(State &state, DictRef dict, Atom field, int64_t amount) {
	state.set(dict, str(field), int_value(gd::add(gd::int_field(state, dict, field, 0), amount)));
}

} // namespace

namespace enemy_turn_rules {

DictRef normalize_optional_hero_task_state(State &state, const Value &value) {
	if (!gd::is_dict(value)) {
		return dropped_board_report(state, key::hero_task_state_not_dictionary, 0);
	}
	const DictRef source = value.ref;
	Value tasks_value;
	const bool has_tasks = state.lookup(source, str(key::tasks), tasks_value);
	if (has_tasks && !gd::is_array(tasks_value)) {
		return dropped_board_report(state, key::hero_task_state_tasks_not_array, imax(0, state.dict_size(source)));
	}
	const ArrayRef normalized_tasks = state.new_array();
	int64_t dropped_count = 0;
	int64_t sanitized_count = _hero_task_state_board_sanitized_field_count(state, source);
	int64_t input_task_count = 0;
	if (has_tasks) {
		for (const Value &task_value : gd::items(state, tasks_value)) {
			const DictRef task_report = _normalize_hero_task_record(state, task_value);
			sanitized_count = gd::add(sanitized_count, gd::int_field(state, task_report, key::sanitized_field_count, 0));
			if (gd::bool_field(state, task_report, key::ok, false)) {
				state.append(normalized_tasks, get_or_new_dict(state, task_report, key::task));
			} else {
				dropped_count += 1;
			}
		}
		input_task_count = state.array_size(tasks_value.ref);
	}
	const DictRef report = state.new_dict();
	state.set(report, str(key::ok), bool_value(true));
	state.set(report, str(key::normalized_present), bool_value(true));
	const DictRef task_state = state.new_dict();
	state.set(task_state, str(key::schema_version), int_value(iclamp(imax(1, gd::int_field(state, source, key::schema_version, 1)), 1, 1)));
	state.set(task_state, str(key::planner_epoch), int_value(imax(0, gd::int_field(state, source, key::planner_epoch, 0))));
	state.set(task_state, str(key::tasks), array_value(normalized_tasks));
	state.set(report, str(key::task_state), dict_value(task_state));
	state.set(report, str(key::input_task_count), int_value(input_task_count));
	state.set(report, str(key::normalized_task_count), int_value(state.array_size(normalized_tasks)));
	state.set(report, str(key::dropped_task_count), int_value(dropped_count));
	state.set(report, str(key::sanitized_field_count), int_value(sanitized_count));
	state.set(report, str(key::observed_policy), str(key::preserved_and_normalized));
	return report;
}

int64_t get_pressure(State &state, DictRef session, Atom faction_id) {
	normalize_enemy_states(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	return gd::int_field(state, _find_state(state, get_or_new_array(state, overworld, key::enemy_states), faction_id), key::pressure, 0);
}

int64_t active_raid_count(State &state, DictRef session, Atom faction_id) {
	int64_t count = 0;
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved_encounters = get_or_new_array(state, overworld, key::resolved_encounters);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!enemy_adventure_rules::is_active_pressure_host(state, encounter, faction_id, resolved_encounters)) {
			continue;
		}
		count = gd::add(count, 1);
	}
	return count;
}

DictRef _faction_front_state(State &state, DictRef session, Atom faction_id) {
	const ArrayRef retake_labels = state.new_array();
	const ArrayRef stabilizing_labels = state.new_array();
	int64_t pressure_bonus = 0;
	int64_t threshold_reduction = 0;
	int64_t garrison_bonus = 0;
	int64_t build_bonus = 0;
	int64_t retake_count = 0;
	int64_t stabilizing_count = 0;
	int64_t top_front_priority = 0;
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &town_value : gd::field_items(state, overworld, str(key::towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		const DictRef front = overworld_rules::town_front_state(state, session, town, state.new_dict());
		if (!gd::bool_field(state, front, key::active, false) || player_rules::controller_id(state, front, key::empty) != faction_id) {
			continue;
		}
		const Atom compact_summary = text_or(state, front, key::compact_summary, str(_town_name(state, town)));
		top_front_priority = imax(top_front_priority, gd::int_field(state, front, key::priority_bonus, 0));
		const Atom mode = text(state, front, key::mode, key::empty);
		if (mode == key::retake) {
			retake_count = gd::add(retake_count, 1);
			pressure_bonus = gd::add(pressure_bonus, gd::int_field(state, front, key::pressure_bonus, 0));
			threshold_reduction = imax(threshold_reduction, gd::int_field(state, front, key::threshold_reduction, 0));
			if (compact_summary != key::empty && !gd::array_has(state, retake_labels, str(compact_summary))) {
				state.append(retake_labels, str(compact_summary));
			}
		} else if (mode == key::stabilizing) {
			stabilizing_count = gd::add(stabilizing_count, 1);
			garrison_bonus = gd::add(garrison_bonus, gd::int_field(state, front, key::garrison_bonus, 0));
			build_bonus = gd::add(build_bonus, gd::int_field(state, front, key::build_bonus, 0));
			if (compact_summary != key::empty && !gd::array_has(state, stabilizing_labels, str(compact_summary))) {
				state.append(stabilizing_labels, str(compact_summary));
			}
		}
	}
	std::vector<std::string> parts;
	if (state.array_size(retake_labels) > 0) {
		const Atom labels = join_first(state, ", ", retake_labels, compat::engine_min<int64_t>(2, state.array_size(retake_labels)));
		parts.push_back(state.text(gd::format(state, key::retake_fronts_s, { str(labels) })));
	}
	if (state.array_size(stabilizing_labels) > 0) {
		const Atom labels = join_first(state, ", ", stabilizing_labels, compat::engine_min<int64_t>(2, state.array_size(stabilizing_labels)));
		parts.push_back(state.text(gd::format(state, key::stabilizing_s, { str(labels) })));
	}
	std::string summary;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			summary += " | ";
		}
		summary += parts[index];
	}
	const DictRef front_state = state.new_dict();
	state.set(front_state, str(key::retake_count), int_value(retake_count));
	state.set(front_state, str(key::stabilizing_count), int_value(stabilizing_count));
	state.set(front_state, str(key::pressure_bonus), int_value(iclamp(pressure_bonus, 0, 4)));
	state.set(front_state, str(key::threshold_reduction), int_value(iclamp(threshold_reduction, 0, 2)));
	state.set(front_state, str(key::garrison_bonus), int_value(iclamp(garrison_bonus, 0, 180)));
	state.set(front_state, str(key::build_bonus), int_value(iclamp(build_bonus, 0, 160)));
	state.set(front_state, str(key::top_front_priority), int_value(top_front_priority));
	state.set(front_state, str(key::summary), str(state.intern(summary)));
	return front_state;
}

ArrayRef _valid_enemy_faction_configs(State &state, ArrayRef configs) {
	const ArrayRef result = state.new_array();
	for (const Value &config_value : gd::items(state, array_value(configs))) {
		if (!gd::is_dict(config_value)) {
			continue;
		}
		const DictRef config = config_value.ref;
		if (gd::is_empty(state, gd::content_row(state, ContentTable::Faction, text(state, config, key::faction_id, key::empty)))) {
			continue;
		}
		state.append(result, dict_value(gd::deep_duplicate_dict(state, config)));
	}
	return result;
}

bool _config_was_runtime_defaulted(State &state, DictRef source, DictRef normalized) {
	for (const Atom field : { key::pressure_per_day, key::pressure_per_enemy_town, key::raid_threshold, key::max_active_raids, key::raid_pillage_delay, key::raid_pillage, key::raid_encounter_ids, key::spawn_points }) {
		if (!state.has(source, str(field)) && state.has(normalized, str(field))) {
			return true;
		}
	}
	return false;
}

DictRef _faction_capital_state(State &state, DictRef session, Atom faction_id) {
	const DictRef overworld = session_view::overworld(state, session);
	return _faction_capital_state_from_towns(state, session, gd::as_array(get_or_new_array(state, overworld, key::towns)), faction_id);
}

DictRef _faction_capital_state_from_towns(State &state, DictRef session, ArrayRef towns, Atom faction_id) {
	const DictRef capital_state = state.new_dict();
	const ArrayRef anchor_labels = state.new_array();
	const ArrayRef active_project_labels = state.new_array();
	const ArrayRef dormant_project_labels = state.new_array();
	state.set(capital_state, str(key::capital_count), int_value(0));
	state.set(capital_state, str(key::stronghold_count), int_value(0));
	state.set(capital_state, str(key::anchor_labels), array_value(anchor_labels));
	state.set(capital_state, str(key::active_project_labels), array_value(active_project_labels));
	state.set(capital_state, str(key::dormant_project_labels), array_value(dormant_project_labels));
	state.set(capital_state, str(key::pressure_bonus), int_value(0));
	state.set(capital_state, str(key::defense_bonus), int_value(0));
	state.set(capital_state, str(key::raid_threshold_reduction), int_value(0));
	state.set(capital_state, str(key::max_active_raids_bonus), int_value(0));
	state.set(capital_state, str(key::active_projects), int_value(0));
	state.set(capital_state, str(key::support_gap), int_value(0));
	state.set(capital_state, str(key::recovery_pressure), int_value(0));
	for (const Value &town_value : gd::items(state, array_value(towns))) {
		if (!gd::is_dict(town_value) || text(state, town_value.ref, key::owner, key::neutral) != key::enemy) {
			continue;
		}
		const DictRef town = town_value.ref;
		if (_town_controller_faction_id(state, town) != faction_id) {
			continue;
		}
		const Atom role = overworld_rules::town_strategic_role(state, town);
		const Atom town_name = _town_name(state, town);
		if (role == key::capital) {
			add_count(state, capital_state, key::capital_count, 1);
			state.append(anchor_labels, str(town_name));
		} else if (role == key::stronghold) {
			add_count(state, capital_state, key::stronghold_count, 1);
			state.append(anchor_labels, str(town_name));
		}
		const DictRef capital_project = overworld_rules::town_capital_project_state(state, town, dict_value(session));
		if (gd::int_field(state, capital_project, key::active, 0) > 0) {
			add_count(state, capital_state, key::active_projects, gd::int_field(state, capital_project, key::active, 0));
			state.append(active_project_labels, str(town_name));
			add_count(state, capital_state, key::pressure_bonus, gd::int_field(state, capital_project, key::pressure_bonus, 0));
			add_count(state, capital_state, key::defense_bonus, gd::int_field(state, capital_project, key::defense_bonus, 0));
			add_count(state, capital_state, key::raid_threshold_reduction, gd::int_field(state, capital_project, key::raid_threshold_reduction, 0));
			add_count(state, capital_state, key::max_active_raids_bonus, gd::int_field(state, capital_project, key::max_active_raids_bonus, 0));
			add_count(state, capital_state, key::support_gap, gd::int_field(state, capital_project, key::support_gap, 0));
		} else if (gd::int_field(state, capital_project, key::total, 0) > 0) {
			state.append(dormant_project_labels, str(town_name));
		}
		const int64_t recovery_pressure = gd::int_field(state, capital_state, key::recovery_pressure, 0);
		const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
		state.set(capital_state, str(key::recovery_pressure), int_value(gd::add(recovery_pressure, gd::int_field(state, recovery, key::pressure, 0))));
	}
	return capital_state;
}

int64_t _raid_threshold_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id, DictRef launch_policy_context) {
	const DictRef strategy = enemy_adventure_rules::enemy_strategy(state, config, faction_id);
	const int64_t base_threshold = difficulty_rules::adjust_raid_threshold(state, session, imax(1, gd::int_field(state, config, key::raid_threshold, 1)));
	const compat::Number scale = compat::Number::of_float(enemy_adventure_rules::strategy_scalar(state, strategy, key::raid, key::threshold_scale, 1.0));
	// clamp() of three floats: a float.
	const double threshold_scale = compat::variant_clamp(scale, compat::Number::of_float(0.65), compat::Number::of_float(1.5)).f;
	int64_t threshold = imax(1, compat::float_to_int(compat::godot_round(static_cast<double>(base_threshold) * threshold_scale)));
	const DictRef capital_state = _launch_policy_capital_state(state, session, faction_id, launch_policy_context);
	threshold = gd::sub(threshold, gd::int_field(state, capital_state, key::raid_threshold_reduction, 0));
	threshold = gd::sub(threshold, gd::int_field(state, _launch_policy_front_state(state, session, faction_id, launch_policy_context), key::threshold_reduction, 0));
	if (ai::session_int(state, session, key::day) >= 5 && gd::int_field(state, capital_state, key::active_projects, 0) > 0) {
		threshold = gd::sub(threshold, 1);
	}
	return imax(1, threshold);
}

int64_t _max_active_raids_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id, DictRef launch_policy_context) {
	const DictRef strategy = enemy_adventure_rules::enemy_strategy(state, config, faction_id);
	const DictRef capital_state = _launch_policy_capital_state(state, session, faction_id, launch_policy_context);
	const int64_t configured = gd::int_field(state, config, key::max_active_raids, 1);
	const int64_t strategy_bonus = enemy_adventure_rules::strategy_int(state, strategy, key::raid, key::max_active_bonus, 0);
	return imax(1, gd::add(gd::add(configured, strategy_bonus), gd::int_field(state, capital_state, key::max_active_raids_bonus, 0)));
}

DictRef _launch_policy_capital_state(State &state, DictRef session, Atom faction_id, DictRef launch_policy_context) {
	const Value cached = state.get(launch_policy_context, str(key::capital_state), Value());
	if (gd::is_dict(cached)) {
		return cached.ref;
	}
	const DictRef loaded = _faction_capital_state(state, session, faction_id);
	state.set(launch_policy_context, str(key::capital_state), dict_value(loaded));
	return loaded;
}

DictRef _launch_policy_front_state(State &state, DictRef session, Atom faction_id, DictRef launch_policy_context) {
	const Value cached = state.get(launch_policy_context, str(key::front_state), Value());
	if (gd::is_dict(cached)) {
		return cached.ref;
	}
	const DictRef loaded = _faction_front_state(state, session, faction_id);
	state.set(launch_policy_context, str(key::front_state), dict_value(loaded));
	return loaded;
}

DictRef _normalize_hero_task_record(State &state, const Value &value) {
	if (!gd::is_dict(value)) {
		return invalid_task_report(state, key::task_not_dictionary, 0);
	}
	const DictRef task = value.ref;
	for (const Atom required_key : { key::task_id, key::owner_faction_id, key::actor_id, key::task_class, key::target_id }) {
		if (text(state, task, required_key, key::empty) == key::empty) {
			const Atom reason = gd::format(state, key::missing_s_2, { str(required_key) });
			return invalid_task_report(state, reason, _hero_task_record_sanitized_field_count(state, task));
		}
	}
	const Atom task_class = _normalize_hero_task_class(state, state.get(task, str(key::task_class), str(key::empty)));
	const Atom task_status = _normalize_hero_task_status(state, state.get(task, str(key::task_status), str(key::planned)));
	const Atom target_kind = _normalize_hero_task_target_kind(state, state.get(task, str(key::target_kind), str(key::empty)));
	const Atom validation = _normalize_hero_task_validation_code(state, state.get(task, str(key::last_validation), str(key::valid)));
	if (task_class == key::empty || task_status == key::empty || target_kind == key::empty || validation == key::empty) {
		return invalid_task_report(state, key::unsupported_task_enum, _hero_task_record_sanitized_field_count(state, task));
	}
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::task_id), str(text(state, task, key::task_id, key::empty)));
	state.set(normalized, str(key::owner_faction_id), str(text(state, task, key::owner_faction_id, key::empty)));
	state.set(normalized, str(key::actor_kind), str(_normalize_hero_task_actor_kind(state, state.get(task, str(key::actor_kind), str(key::commander_roster)))));
	state.set(normalized, str(key::actor_id), str(text(state, task, key::actor_id, key::empty)));
	state.set(normalized, str(key::source_kind), str(_normalize_hero_task_source_kind(state, state.get(task, str(key::source_kind), str(key::commander_role_adapter)))));
	state.set(normalized, str(key::source_id), str(text(state, task, key::source_id, key::empty)));
	state.set(normalized, str(key::task_class), str(task_class));
	state.set(normalized, str(key::task_status), str(task_status));
	state.set(normalized, str(key::target_kind), str(target_kind));
	state.set(normalized, str(key::target_id), str(text(state, task, key::target_id, key::empty)));
	state.set(normalized, str(key::front_id), str(text(state, task, key::front_id, key::empty)));
	state.set(normalized, str(key::origin_kind), str(_normalize_hero_task_origin_kind(state, state.get(task, str(key::origin_kind), str(key::town)))));
	state.set(normalized, str(key::origin_id), str(text(state, task, key::origin_id, key::empty)));
	state.set(normalized, str(key::priority_reason_codes), array_value(_normalize_string_array(state, get_or_new_array(state, task, key::priority_reason_codes))));
	state.set(normalized, str(key::assigned_day), int_value(imax(0, gd::int_field(state, task, key::assigned_day, 0))));
	state.set(normalized, str(key::expires_day), int_value(imax(0, gd::int_field(state, task, key::expires_day, 0))));
	state.set(normalized, str(key::continuity_policy), str(_normalize_hero_task_continuity_policy(state, state.get(task, str(key::continuity_policy), str(key::persist_until_invalid)))));
	state.set(normalized, str(key::route_policy), str(_normalize_hero_task_route_policy(state, state.get(task, str(key::route_policy), str(key::derive_route_on_turn)))));
	state.set(normalized, str(key::last_validation), str(validation));
	if (text(state, task, key::owner_player_id, key::empty) != key::empty) {
		state.set(normalized, str(key::owner_player_id), str(gd::stringify_or_fallback(state, gd::index(state, task, str(key::owner_player_id)))));
	}
	if (state.has(task, str(key::invalidated_by_task_id))) {
		state.set(normalized, str(key::invalidated_by_task_id), str(text(state, task, key::invalidated_by_task_id, key::empty)));
	}
	// task.get("reservation", {}) is Dictionary: a missing reservation is one.
	const Value reservation = get_or_new_dict(state, task, key::reservation);
	if (gd::is_dict(reservation)) {
		state.set(normalized, str(key::reservation), dict_value(_normalize_hero_task_reservation(state, reservation)));
	}
	const DictRef report = state.new_dict();
	state.set(report, str(key::ok), bool_value(true));
	state.set(report, str(key::task), dict_value(normalized));
	state.set(report, str(key::sanitized_field_count), int_value(_hero_task_record_sanitized_field_count(state, task)));
	return report;
}

int64_t _hero_task_state_board_sanitized_field_count(State &state, DictRef board) {
	int64_t sanitized = 0;
	for (const Value &board_key : gd::items(state, dict_value(board))) {
		if (!one_of(gd::stringify_or_fallback(state, board_key), { key::schema_version, key::planner_epoch, key::tasks })) {
			sanitized = gd::add(sanitized, 1);
		}
	}
	return sanitized;
}

int64_t _hero_task_record_sanitized_field_count(State &state, DictRef task) {
	int64_t sanitized = 0;
	for (const Value &task_key : gd::items(state, dict_value(task))) {
		const Atom field = gd::stringify_or_fallback(state, task_key);
		if (!one_of(field, {
								   key::task_id,
								   key::owner_faction_id,
								   key::owner_player_id,
								   key::actor_kind,
								   key::actor_id,
								   key::source_kind,
								   key::source_id,
								   key::task_class,
								   key::task_status,
								   key::target_kind,
								   key::target_id,
								   key::front_id,
								   key::origin_kind,
								   key::origin_id,
								   key::priority_reason_codes,
								   key::assigned_day,
								   key::expires_day,
								   key::continuity_policy,
								   key::route_policy,
								   key::last_validation,
								   key::reservation,
								   key::invalidated_by_task_id,
						   })) {
			sanitized = gd::add(sanitized, 1);
		}
	}
	return sanitized;
}

Atom _normalize_hero_task_class(State &state, const Value &value) {
	const Atom task_class = gd::stringify_or_fallback(state, value);
	if (one_of(task_class, { key::raid_town, key::retake_site, key::contest_site, key::stabilize_front, key::defend_front, key::scout_frontier, key::recover_commander, key::rebuild_host, key::reserve })) {
		return task_class;
	}
	return key::empty;
}

Atom _normalize_hero_task_status(State &state, const Value &value) {
	const Atom task_status = gd::stringify_or_fallback(state, value);
	if (one_of(task_status, { key::candidate, key::planned, key::reserved, key::active, key::suspended, key::blocked, key::completed, key::failed, key::cancelled, key::invalid })) {
		return task_status;
	}
	return key::empty;
}

Atom _normalize_hero_task_target_kind(State &state, const Value &value) {
	const Atom target_kind = gd::stringify_or_fallback(state, value);
	if (one_of(target_kind, { key::resource, key::town, key::artifact, key::encounter, key::hero, key::regroup, key::commander, key::front })) {
		return target_kind;
	}
	if (target_kind == key::explore) {
		return target_kind;
	}
	return key::empty;
}

Atom _normalize_hero_task_actor_kind(State &state, const Value &value) {
	const Atom actor_kind = gd::stringify_or_fallback(state, value);
	return one_of(actor_kind, { key::commander_roster, key::active_encounter, key::ai_hero }) ? actor_kind : key::commander_roster;
}

Atom _normalize_hero_task_source_kind(State &state, const Value &value) {
	const Atom source_kind = gd::stringify_or_fallback(state, value);
	return one_of(source_kind, { key::commander_role_adapter, key::saved_task_state }) ? source_kind : key::commander_role_adapter;
}

Atom _normalize_hero_task_origin_kind(State &state, const Value &value) {
	const Atom origin_kind = gd::stringify_or_fallback(state, value);
	return one_of(origin_kind, { key::town, key::front, key::encounter }) ? origin_kind : key::town;
}

Atom _normalize_hero_task_continuity_policy(State &state, const Value &value) {
	const Atom policy = gd::stringify_or_fallback(state, value);
	return one_of(policy, { key::persist_until_invalid, key::expire_on_day, key::derive_each_turn }) ? policy : key::persist_until_invalid;
}

Atom _normalize_hero_task_route_policy(State &state, const Value &value) {
	const Atom policy = gd::stringify_or_fallback(state, value);
	return one_of(policy, { key::derive_route_on_turn, key::hold_position, key::route_deferred }) ? policy : key::derive_route_on_turn;
}

Atom _normalize_hero_task_validation_code(State &state, const Value &value) {
	const Atom code = gd::stringify_or_fallback(state, value);
	if (one_of(code, {
							 key::valid,
							 key::invalid_target_missing,
							 key::invalid_target_resolved,
							 key::invalid_controller_changed,
							 key::invalid_target_reserved,
							 key::invalid_front_quiet,
							 key::invalid_actor_missing,
							 key::invalid_actor_recovering,
							 key::invalid_actor_rebuilding,
							 key::invalid_actor_active_elsewhere,
							 key::invalid_actor_defeated,
							 key::invalid_battle_defeat,
							 key::invalid_battle_withdrawal,
							 key::invalid_origin_missing,
							 key::invalid_origin_controller_changed,
							 key::invalid_route_unreachable,
							 key::invalid_approach_unavailable,
							 key::invalid_task_expired,
							 key::battle_stalemate,
							 key::cancelled_by_retask,
							 key::invalid_script_lock,
							 key::invalid_scenario_complete,
					 })) {
		return code;
	}
	return key::empty;
}

DictRef _normalize_hero_task_reservation(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (!gd::is_dict(value)) {
		state.set(normalized, str(key::reservation_status), str(key::none));
		state.set(normalized, str(key::reservation_scope), str(key::none));
		state.set(normalized, str(key::reservation_key), str(key::empty));
		return normalized;
	}
	const DictRef reservation = value.ref;
	Atom status = text(state, reservation, key::reservation_status, key::none);
	if (!one_of(status, { key::none, key::primary, key::shared, key::released, key::rejected_duplicate })) {
		status = key::none;
	}
	Atom scope = text(state, reservation, key::reservation_scope, key::none);
	if (!one_of(scope, { key::none, key::exclusive_target, key::shared_front })) {
		scope = key::none;
	}
	state.set(normalized, str(key::reservation_status), str(status));
	state.set(normalized, str(key::reservation_scope), str(scope));
	state.set(normalized, str(key::reservation_key), str(text(state, reservation, key::reservation_key, key::empty)));
	return normalized;
}

void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail) {
	if (building_id == key::empty || gd::array_has(state, target, str(building_id)) || gd::array_has(state, trail, str(building_id))) {
		return;
	}
	const ArrayRef next_trail = gd::deep_duplicate_array(state, trail);
	state.append(next_trail, str(building_id));
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom upgrade_from = text(state, building, key::upgrade_from, key::empty);
	if (upgrade_from != key::empty) {
		_append_building_with_requirements(state, target, upgrade_from, next_trail);
	}
	for (const Value &requirement_value : gd::field_items(state, building, str(key::requires_))) {
		_append_building_with_requirements(state, target, gd::stringify_or_fallback(state, requirement_value), next_trail);
	}
	state.append(target, str(building_id));
}

} // namespace enemy_turn_rules

} // namespace aurelion::rules::port
