// OverworldRules for the human seat's town actions (Phase 7, slice 7.6): the
// read-scope wrappers of a town's quality, readiness and pressure, the build
// projection, the recruit options and briefs, the market and response actions,
// and ScenarioRules.objective_artifact_ids.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
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
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(field, {}) and d.get(field, []) of a value that may be stored: the
// field, or a new container.
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

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
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

// int(d.get(field, {}).get(entry, 0)), read only.
int64_t nested_int(State &state, DictRef dict, Atom field, Atom entry) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, entry, int_value(0)));
}

// "buy" and "sell", in the order the market lists them.
constexpr Atom kMarketActionTypes[] = {key::buy, key::sell};

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(town.get("owner", "neutral")) == "player".
bool player_owned(State &state, DictRef town) {
	return text_or(state, town, key::owner, key::neutral) == key::player;
}

// sep.join(array) of an Array of Strings (the Array as a PackedStringArray).
Atom join_array_values(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	bool first = true;
	for (const Value &part : gd::items(state, array_value(parts))) {
		if (!first) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify(state, part));
		first = false;
	}
	return state.intern(joined);
}

// " | Missing %s" % ", ".join(labels) when d.get(field, []) is a non-empty
// Array, else nothing (read only).
std::string missing_labels_text(State &state, DictRef dict, Atom field) {
	Value labels;
	if (!state.lookup(dict, str(field), labels) || !gd::is_array(labels) || state.array_size(labels.ref) == 0) {
		return std::string();
	}
	return state.text(gd::format(state, key::missing_s_4, {str(join_array_values(state, key::comma_space, labels.ref))}));
}

// s.split(delimiter) (allow_empty): the pieces between the delimiters.
std::vector<Atom> split_atoms(State &state, Atom text, Atom delimiter) {
	const std::string source = state.text(text);
	const std::string separator = state.text(delimiter);
	std::vector<Atom> parts;
	size_t from = 0;
	while (true) {
		const size_t at = source.find(separator, from);
		if (at == std::string::npos) {
			parts.push_back(state.intern(source.substr(from)));
			return parts;
		}
		parts.push_back(state.intern(source.substr(from, at - from)));
		from = at + separator.size();
	}
}

// String(result.get("town", {}).get("placement_id", "")), read only.
Atom linked_town_placement(State &state, DictRef result) {
	Value town;
	if (!state.lookup(result, str(key::town), town)) {
		return key::empty;
	}
	return gd::stringify(state, ai::vget(state, town, key::placement_id, str(key::empty)));
}

} // namespace

namespace overworld_rules {

namespace {

// _town_read_scope_cache_key(session, kind, town): "" (no cache) for a null session.
Atom read_scope_cache_key(State &state, const Value &session, Atom kind, DictRef town) {
	return session.kind == state::Kind::Nil ? key::empty : _town_read_scope_cache_key(state, gd::as_dict(session), kind, town);
}

} // namespace

int64_t town_reinforcement_quality(State &state, DictRef town, const Value &session) {
	const Atom cache_key = read_scope_cache_key(state, session, key::reinforcement_quality, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::to_int(state, _town_read_scope_cache_get(state, cache_key));
	}
	const int64_t result = _town_reinforcement_quality(state, town, session, state.new_dict());
	_town_read_scope_cache_store(state, cache_key, int_value(result));
	return result;
}

int64_t town_battle_readiness(State &state, DictRef town, const Value &session) {
	const Atom cache_key = read_scope_cache_key(state, session, key::battle_readiness, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::to_int(state, _town_read_scope_cache_get(state, cache_key));
	}
	const int64_t result = _town_battle_readiness(state, town, session, state.new_dict(), -1);
	_town_read_scope_cache_store(state, cache_key, int_value(result));
	return result;
}

int64_t town_pressure_output(State &state, DictRef town, const Value &session) {
	const Atom cache_key = read_scope_cache_key(state, session, key::pressure_output, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::to_int(state, _town_read_scope_cache_get(state, cache_key));
	}
	const int64_t result = _town_pressure_output(state, town, session, state.new_dict(), -1);
	_town_read_scope_cache_store(state, cache_key, int_value(result));
	return result;
}

DictRef town_logistics_state(State &state, DictRef session, DictRef town) {
	return _town_logistics_state(state, session, town);
}

ArrayRef get_town_market_actions(State &state, DictRef session, DictRef town) {
	return _town_market_actions(state, session, town);
}

DictRef perform_town_market_action(State &state, DictRef session, DictRef town, Atom action_id) {
	return _execute_town_market_action(state, session, town, action_id);
}

bool can_afford_cost_with_town_market(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day) {
	const DictRef coverage = _town_market_cost_coverage(state, town, pool, cost, current_day);
	return gd::to_bool(state.get(coverage, str(key::affordable), bool_value(false)));
}

Atom describe_town_build_projection(State &state, DictRef session, DictRef town, Atom building_id) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	if (gd::is_empty(state, building)) {
		return key::projection_unavailable;
	}
	const Value session_value = dict_value(session);
	const DictRef current_growth = town_weekly_growth(state, town, session_value);
	const DictRef current_logistics = town_logistics_state(state, session, town);
	const int64_t current_quality = town_reinforcement_quality(state, town, session_value);
	const int64_t current_readiness = town_battle_readiness(state, town, session_value);
	const int64_t current_pressure = town_pressure_output(state, town, session_value);
	const DictRef current_recovery = town_recovery_state(state, session, town);
	const DictRef current_project = town_capital_project_state(state, town, session_value);
	const DictRef projected_town = gd::as_dict(gd::engine_duplicate(state, dict_value(town), true));
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, projected_town);
	if (!gd::array_has(state, built_buildings, str(building_id))) {
		state.append(built_buildings, str(building_id));
	}
	state.set(projected_town, str(key::built_buildings), array_value(built_buildings));
	const DictRef projected_growth = town_weekly_growth(state, projected_town, session_value);
	const DictRef projected_logistics = town_logistics_state(state, session, projected_town);
	const int64_t projected_quality = town_reinforcement_quality(state, projected_town, session_value);
	const int64_t projected_readiness = town_battle_readiness(state, projected_town, session_value);
	const int64_t projected_pressure = town_pressure_output(state, projected_town, session_value);
	const DictRef projected_recovery = town_recovery_state(state, session, projected_town);
	const DictRef projected_project = town_capital_project_state(state, projected_town, session_value);
	std::vector<Atom> parts;
	const Atom growth_projection = _describe_recruit_projection(state, dict_value(current_growth), dict_value(projected_growth));
	if (growth_projection != key::empty) {
		parts.push_back(gd::format(state, key::weekly_s_2, {str(growth_projection)}));
	}
	const int64_t quality_delta = gd::sub(projected_quality, current_quality);
	if (quality_delta != 0) {
		parts.push_back(gd::format(state, key::quality_s, {str(_describe_signed_int(state, quality_delta))}));
	}
	const int64_t readiness_delta = gd::sub(projected_readiness, current_readiness);
	if (readiness_delta != 0) {
		parts.push_back(gd::format(state, key::readiness_s_2, {str(_describe_signed_int(state, readiness_delta))}));
	}
	const int64_t pressure_delta = gd::sub(projected_pressure, current_pressure);
	if (pressure_delta != 0) {
		const Atom pressure_label = _town_pressure_label(state, town);
		parts.push_back(gd::format(state, key::s_s, {str(pressure_label), str(_describe_signed_int(state, pressure_delta))}));
	}
	const int64_t relief_delta = gd::sub(gd::int_field(state, projected_recovery, key::relief_per_day, 1), gd::int_field(state, current_recovery, key::relief_per_day, 1));
	if (relief_delta != 0) {
		parts.push_back(gd::format(state, key::recovery_s_day, {str(_describe_signed_int(state, relief_delta))}));
	}
	const int64_t projected_complete = gd::int_field(state, projected_project, key::progress_complete, 0);
	const int64_t current_complete = gd::int_field(state, current_project, key::progress_complete, 0);
	if (projected_complete != current_complete) {
		parts.push_back(gd::format(state, key::project_d_d, {int_value(projected_complete), int_value(gd::int_field(state, projected_project, key::progress_total, 0))}));
	}
	if (gd::int_field(state, projected_project, key::support_total, 0) > 0 &&
			(projected_complete != current_complete || gd::bool_field(state, projected_project, key::active, false))) {
		std::string anchor_summary = state.text(gd::format(state, key::anchor_watch_d_d, {int_value(gd::int_field(state, projected_project, key::support_met, 0)), int_value(gd::int_field(state, projected_project, key::support_total, 0))}));
		anchor_summary += missing_labels_text(state, projected_project, key::missing_support_labels);
		if (gd::int_field(state, projected_project, key::recovery_guard, 0) > 0) {
			anchor_summary += state.text(gd::format(state, key::recovery_d_day_3, {int_value(gd::int_field(state, projected_project, key::recovery_guard, 0))}));
		}
		parts.push_back(state.intern(anchor_summary));
	}
	const int64_t logistics_required_total = compat::engine_max<int64_t>(gd::int_field(state, current_logistics, key::required_total, 0), gd::int_field(state, projected_logistics, key::required_total, 0));
	if (logistics_required_total > 0 &&
			(gd::int_field(state, projected_logistics, key::support_gap, 0) != gd::int_field(state, current_logistics, key::support_gap, 0) ||
					gd::int_field(state, projected_logistics, key::met_requirements, 0) != gd::int_field(state, current_logistics, key::met_requirements, 0))) {
		std::string logistics_summary = state.text(gd::format(state, key::logistics_d_d_anchors, {int_value(gd::int_field(state, projected_logistics, key::met_requirements, 0)), int_value(gd::int_field(state, projected_logistics, key::required_total, 0))}));
		logistics_summary += missing_labels_text(state, projected_logistics, key::missing_family_labels);
		parts.push_back(state.intern(logistics_summary));
	}
	const bool projected_vulnerable = gd::bool_field(state, projected_project, key::vulnerable, false);
	const bool current_vulnerable = gd::bool_field(state, current_project, key::vulnerable, false);
	if (projected_vulnerable && !current_vulnerable) {
		parts.push_back(key::vulnerability_window_opens);
	} else if (!projected_vulnerable && current_vulnerable) {
		parts.push_back(key::closes_vulnerability_window);
	}
	if (parts.empty()) {
		return key::projection_steadies_current_output;
	}
	return gd::format(state, key::projection_s, {str(join_atoms(state, key::space_bar_space, parts))});
}

Atom describe_unit_recruit_brief(State &state, Atom unit_id, int64_t count) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return key::unknown_unit;
	}
	const int64_t strength_count = compat::engine_max<int64_t>(1, count);
	const Atom strength_label = count > 0 ? key::reserve : key::each;
	const Atom tier_label = unit_tier_label(state, unit);
	const Atom role_label = unit_role_label(state, unit);
	const int64_t hp = compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::hp, 1));
	const int64_t strength = unit_stack_strength_value(state, unit_id, strength_count);
	return gd::format(state, key::s_s_hp_d_each_strength, {str(tier_label), str(role_label), int_value(hp), int_value(strength), str(strength_label)});
}

Atom unit_tier_label(State &state, DictRef unit) {
	return gd::format(state, key::t_d, {int_value(compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::tier, 1)))});
}

Atom unit_role_label(State &state, DictRef unit) {
	Atom role = gd::strip_edges(state, text_or(state, unit, key::role, key::empty));
	if (role == key::empty) {
		role = gd::bool_field(state, unit, key::ranged, false) ? key::ranged : key::melee;
	}
	return gd::capitalize(state, role);
}

int64_t unit_stack_strength_value(State &state, Atom unit_id, int64_t count) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit) || count <= 0) {
		return 0;
	}
	return gd::mul(compat::engine_max<int64_t>(0, count), unit_strength_value(state, unit_id));
}

int64_t unit_strength_value(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return 0;
	}
	// float(min_damage + max_damage) / 2.0, rounded.
	const int64_t damage_sum = gd::add(gd::int_field(state, unit, key::min_damage, 1), gd::int_field(state, unit, key::max_damage, 1));
	const int64_t damage_average = compat::float_to_int(compat::godot_round(static_cast<double>(damage_sum) / 2.0));
	int64_t total = compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::hp, 1));
	total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, unit, key::attack, 0)));
	total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, unit, key::defense, 0)));
	total = gd::add(total, compat::engine_max<int64_t>(1, damage_average));
	total = gd::add(total, compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::speed, 1)));
	total = gd::add(total, compat::engine_max<int64_t>(1, gd::int_field(state, unit, key::initiative, 1)));
	total = gd::add(total, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
	total = gd::add(total, compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, unit, key::tier, 1), 1)));
	return total;
}

ArrayRef get_town_recruit_options(State &state, DictRef town) {
	const ArrayRef options = state.new_array();
	// var available_recruits = town.get("available_recruits", {}): read only.
	Value available_recruits;
	if (!state.lookup(town, str(key::available_recruits), available_recruits) || !gd::is_dict(available_recruits)) {
		return options;
	}
	// for unit_id in available_recruits.keys(): a copy of the keys.
	const ArrayRef unit_ids = gd::keys(state, available_recruits.ref);
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		if (gd::to_int(state, gd::index(state, available_recruits.ref, unit_id)) > 0) {
			state.append(options, str(gd::stringify(state, unit_id)));
		}
	}
	return options;
}

ArrayRef _town_market_actions(State &state, DictRef session, DictRef town) {
	const ArrayRef actions = state.new_array();
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town) || !player_owned(state, town)) {
		return actions;
	}
	const DictRef market_state = _town_market_state(state, town);
	if (!gd::to_bool(state.get(market_state, str(key::active), bool_value(false)))) {
		return actions;
	}
	const ArrayRef resource_order = _market_buy_resources(state, market_state);
	const ArrayRef bulk_resources = _market_bulk_resources(state, market_state);
	for (int64_t index = state.array_size(bulk_resources) - 1; index > -1; --index) {
		const Atom bulk_resource = gd::stringify(state, state.at(bulk_resources, index));
		if (gd::array_has(state, resource_order, str(bulk_resource))) {
			ai::array_erase(state, resource_order, str(bulk_resource));
			gd::push_front(state, resource_order, str(bulk_resource));
		}
	}
	for (const Value &resource_value : gd::items(state, array_value(resource_order))) {
		const Atom resource_key = gd::to_string(resource_value);
		for (const Atom action_type : kMarketActionTypes) {
			const DictRef quote = _market_quote_from_state(state, market_state, action_type, resource_key, 1);
			if (gd::is_empty(state, quote)) {
				continue;
			}
			state.append(actions, dict_value(_market_action_entry(state, session, town, market_state, quote)));
		}
	}
	if (gd::int_field(state, market_state, key::bulk_amount, 0) > 1) {
		for (const Value &bulk_resource_value : gd::items(state, array_value(bulk_resources))) {
			const Atom bulk_resource = gd::stringify(state, bulk_resource_value);
			for (const Atom action_type : kMarketActionTypes) {
				const DictRef bulk_quote = _market_quote_from_state(state, market_state, action_type, bulk_resource, gd::int_field(state, market_state, key::bulk_amount, 0));
				if (gd::is_empty(state, bulk_quote)) {
					continue;
				}
				state.append(actions, dict_value(_market_action_entry(state, session, town, market_state, bulk_quote)));
			}
		}
	}
	return actions;
}

DictRef _market_action_entry(State &state, DictRef session, DictRef town, DictRef market_state, DictRef quote) {
	const Atom action_type = ai::string_or_empty(state, quote, key::action_type);
	const Atom resource_key = ai::string_or_empty(state, quote, key::resource);
	const int64_t amount = gd::int_field(state, quote, key::amount, 0);
	// int(session.day) if session != null else -1: a view is never null.
	const DictRef cap_state = _market_cap_state_for_quote(state, town, market_state, quote, ai::session_int(state, session, key::day));
	bool disabled = gd::int_field(state, cap_state, key::remaining, 0) < amount;
	Atom disabled_reason = disabled ? gd::format(state, key::weekly_market_cap_reached_for_s, {str(resource_key), str(action_type)}) : static_cast<Atom>(key::empty);
	Atom summary = gd::format(state, key::s_s_s_6, {
			str(ai::string_or_empty(state, quote, key::summary)),
			str(ai::string_or_empty(state, quote, key::rate_summary)),
			str(ai::string_or_empty(state, quote, key::building_summary)),
	});
	summary = gd::format(state, key::s_weekly_cap_d_d, {str(summary), int_value(gd::int_field(state, cap_state, key::used, 0)), int_value(gd::int_field(state, cap_state, key::limit, 0))});
	if (!_can_afford(state, session, field_or_new_dict(state, quote, key::cost))) {
		disabled = true;
		disabled_reason = key::insufficient_reserves_for_this_exchange;
	}
	const Atom resource_label = gd::capitalize(state, gd::replace(state, resource_key, key::_, key::space));
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::id), str(gd::format(state, key::market_s_s_d, {str(action_type), str(resource_key), int_value(amount)})));
	state.set(entry, str(key::label), str(gd::format(state, key::s_d_s_4, {str(action_type == key::buy ? key::Buy : key::Sell), int_value(amount), str(resource_label)})));
	state.set(entry, str(key::summary), str(summary));
	state.set(entry, str(key::disabled), bool_value(disabled));
	state.set(entry, str(key::disabled_reason), str(disabled_reason));
	state.set(entry, str(key::cap_week), int_value(gd::int_field(state, cap_state, key::week, 1)));
	state.set(entry, str(key::cap_used), int_value(gd::int_field(state, cap_state, key::used, 0)));
	state.set(entry, str(key::cap_limit), int_value(gd::int_field(state, cap_state, key::limit, 0)));
	state.set(entry, str(key::cap_remaining), int_value(gd::int_field(state, cap_state, key::remaining, 0)));
	state.set(entry, str(key::refresh_cadence), str(text_or(state, cap_state, key::refresh_cadence, key::weekly)));
	return entry;
}

DictRef _execute_town_market_action(State &state, DictRef session, DictRef town, Atom action_id) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_exchange);
	}
	const std::vector<Atom> parts = split_atoms(state, action_id, key::colon);
	if (parts.size() != 4 || parts[0] != key::market) {
		return refusal(state, key::that_exchange_order_is_invalid);
	}
	const Atom action_type = parts[1];
	const Atom resource_key = parts[2];
	const int64_t amount = compat::engine_max<int64_t>(0, compat::to_int(state.text(parts[3])));
	const DictRef town_result = _find_town_by_placement(state, session, text_or(state, town, key::placement_id, key::empty));
	// town_result.get("town", town) if it is a Dictionary, else town.
	const Value result_town = state.get(town_result, str(key::town), dict_value(town));
	const DictRef live_town = gd::is_dict(result_town) ? result_town.ref : town;
	const DictRef market_state = _town_market_state(state, live_town);
	const DictRef quote = _market_quote_from_state(state, market_state, action_type, resource_key, amount);
	if (gd::is_empty(state, quote)) {
		return refusal(state, gd::format(state, key::that_exchange_order_is_not_available, {str(_town_name(state, live_town))}));
	}
	const DictRef cap_state = _market_cap_state_for_quote(state, live_town, market_state, quote, ai::session_int(state, session, key::day));
	if (gd::int_field(state, cap_state, key::remaining, 0) < amount) {
		return refusal(state, gd::format(state, key::weekly_market_cap_reached_for_s_2, {str(resource_key), str(action_type), str(_town_name(state, live_town))}));
	}
	const Value cost = field_or_new_dict(state, quote, key::cost);
	if (!_can_afford(state, session, cost)) {
		const Atom verb = action_type == key::buy ? key::buy : key::sell;
		return refusal(state, gd::format(state, key::insufficient_reserves_to_s_through_s, {str(verb), str(_town_name(state, live_town))}));
	}
	_spend_resources(state, session, cost);
	_add_resources(state, session, field_or_new_dict(state, quote, key::gain));
	// live_town.get("market_usage", {}): a missing usage normalizes as {} does (as null).
	const DictRef usage = _normalize_town_market_usage_state(state, gd::field(state, live_town, key::market_usage), ai::session_int(state, session, key::day));
	// usage.get(action_type, {}) if it is a Dictionary, else _empty_market_usage_bucket().
	DictRef bucket = 0;
	Value found_bucket;
	if (!state.lookup(usage, str(action_type), found_bucket)) {
		bucket = state.new_dict();
	} else {
		bucket = gd::is_dict(found_bucket) ? found_bucket.ref : _empty_market_usage_bucket(state, 0);
	}
	state.set(bucket, str(resource_key), int_value(gd::add(gd::int_field(state, bucket, resource_key, 0), amount)));
	state.set(usage, str(action_type), dict_value(bucket));
	state.set(live_town, str(key::market_usage), dict_value(usage));
	const int64_t town_index = gd::int_field(state, town_result, key::index, -1);
	if (town_index >= 0) {
		const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
		if (gd::is_array(towns)) {
			state.set_at(towns.ref, town_index, dict_value(live_town));
			state.set(session_view::overworld(state, session), str(key::towns), towns);
		}
	}
	const Atom amount_label = gd::format(state, key::_d_s, {int_value(amount), str(resource_key)});
	const Atom town_name = _town_name(state, live_town);
	const int64_t gold_value = gd::int_field(state, quote, key::gold_value, 0);
	const Atom building_name = text_or(state, quote, key::building_name, key::the_exchange);
	if (action_type == key::buy) {
		return _finalize_action_result(state, session, true, gd::format(state, key::bought_s_in_s_for_d, {str(amount_label), str(town_name), int_value(gold_value), str(building_name)}), true, false, state.new_dict());
	}
	return _finalize_action_result(state, session, true, gd::format(state, key::sold_s_in_s_for_d, {str(amount_label), str(town_name), int_value(gold_value), str(building_name)}), true, false, state.new_dict());
}

ArrayRef get_town_response_actions(State &state, DictRef session, DictRef town) {
	return _town_response_actions(state, session, town);
}

DictRef perform_town_response_action(State &state, DictRef session, DictRef town, Atom action_id) {
	return _execute_town_response_action(state, session, town, action_id);
}

ArrayRef _town_response_actions(State &state, DictRef session, DictRef town) {
	const ArrayRef actions = state.new_array();
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town) || !player_owned(state, town)) {
		return actions;
	}
	const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
	const DictRef logistics = _town_logistics_state(state, session, town);
	const DictRef capital_project = _town_capital_project_state(state, town, dict_value(session), state.new_dict(), state.new_dict());
	const DictRef stabilize_profile = _town_recovery_stabilize_profile(state, town);
	const int64_t movement_left = nested_int(state, session_view::overworld(state, session), key::movement, key::current);
	if (gd::to_bool(state.get(recovery, str(key::active), bool_value(false)))) {
		const Value stabilize_cost = field_or_new_dict(state, stabilize_profile, key::resource_cost);
		const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::resources));
		const DictRef stabilize_readiness = town_cost_readiness(state, town, pool, stabilize_cost, ai::session_int(state, session, key::day));
		const bool market_affordable = gd::to_bool(state.get(stabilize_readiness, str(key::market_affordable), bool_value(false)));
		const bool direct_affordable = gd::to_bool(state.get(stabilize_readiness, str(key::direct_affordable), bool_value(false)));
		Atom stabilize_market_summary = key::empty;
		if (market_affordable && !direct_affordable) {
			stabilize_market_summary = _summarize_market_actions(state, field_or_new_array(state, stabilize_readiness, key::market_actions), 2);
		}
		const int64_t movement_cost = gd::int_field(state, stabilize_profile, key::movement_cost, 0);
		const Atom summary = gd::format(state, key::s_s_cost_s_move_d, {
				str(text_or(state, stabilize_profile, key::summary, key::push_reserve_labor_back_onto_the)),
				str(gd::format(state, key::recovery_d_3, {int_value(gd::int_field(state, stabilize_profile, key::relief_amount, 1))})),
				str(_describe_resource_delta(state, stabilize_cost)),
				int_value(movement_cost),
		});
		const bool disabled = !_can_afford(state, session, stabilize_cost) || movement_left < movement_cost;
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(key::stabilize_recovery));
		state.set(action, str(key::label), str(text_or(state, stabilize_profile, key::label, key::stabilize_recovery_2)));
		state.set(action, str(key::summary), str(summary));
		state.set(action, str(key::disabled), bool_value(disabled));
		state.set(action, str(key::resource_cost), stabilize_cost);
		state.set(action, str(key::movement_cost), int_value(movement_cost));
		state.set(action, str(key::remaining_movement_after_order), int_value(compat::engine_max<int64_t>(0, gd::sub(movement_left, movement_cost))));
		state.set(action, str(key::market_coverable), bool_value(market_affordable && !direct_affordable));
		state.set(action, str(key::market_summary), str(stabilize_market_summary));
		state.set(action, str(key::resource_blocked), bool_value(!direct_affordable));
		state.set(action, str(key::movement_blocked), bool_value(movement_left < movement_cost));
		state.append(actions, dict_value(action));
	}

	// for node in session.overworld.get("resource_nodes", []): the loop changes no node list.
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node)) {
			continue;
		}
		const DictRef node_dict = node.ref;
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_or(state, node_dict, key::site_id, key::empty));
		if (!_resource_site_is_persistent(state, site) || text_or(state, node_dict, key::collected_by_faction_id, key::empty) != key::player) {
			continue;
		}
		const DictRef linked_town_result = _resource_node_linked_town(state, session, node_dict, key::player);
		if (linked_town_placement(state, linked_town_result) != text_or(state, town, key::placement_id, key::empty)) {
			continue;
		}
		const DictRef response_state = _resource_site_response_state(state, session, node_dict, site);
		if (gd::int_field(state, response_state, key::watch_days, 0) <= 0 || gd::to_bool(state.get(response_state, str(key::active), bool_value(false)))) {
			continue;
		}
		const bool threatened = _resource_site_under_threat(state, session, node_dict, key::player);
		if (!threatened && !gd::to_bool(state.get(recovery, str(key::active), bool_value(false))) && gd::int_field(state, logistics, key::support_gap, 0) <= 0 &&
				!gd::to_bool(state.get(capital_project, str(key::vulnerable), bool_value(false)))) {
			continue;
		}
		const Value cost = field_or_new_dict(state, response_state, key::resource_cost);
		const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::resources));
		const DictRef readiness = town_cost_readiness(state, town, pool, cost, ai::session_int(state, session, key::day));
		const bool market_affordable = gd::to_bool(state.get(readiness, str(key::market_affordable), bool_value(false)));
		const bool direct_affordable = gd::to_bool(state.get(readiness, str(key::direct_affordable), bool_value(false)));
		Atom market_summary = key::empty;
		if (market_affordable && !direct_affordable) {
			market_summary = _summarize_market_actions(state, field_or_new_array(state, readiness, key::market_actions), 2);
		}
		const DictRef delivery_plan = _player_reserve_delivery_plan(state, session, town, response_state);
		Atom delivery_summary = key::empty;
		if (!gd::is_empty(state, delivery_plan)) {
			const int64_t eta_days = gd::int_field(state, delivery_plan, key::eta_days, 1);
			delivery_summary = gd::format(state, key::load_s_for_s_d_day, {
					str(_describe_recruit_delta(state, field_or_new_dict(state, delivery_plan, key::manifest))),
					str(text_or(state, delivery_plan, key::target_label, key::the_front)),
					int_value(eta_days),
					str(eta_days == 1 ? key::empty : key::s),
			});
		}
		const Atom site_name = text_or(state, site, key::name, key::frontier_site);
		std::vector<Atom> site_summary_parts;
		site_summary_parts.push_back(ai::string_or_empty(state, response_state, key::summary));
		site_summary_parts.push_back(gd::format(state, key::site_s, {str(site_name)}));
		if (delivery_summary != key::empty) {
			site_summary_parts.push_back(delivery_summary);
		}
		const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
		if (impact_summary != key::empty) {
			site_summary_parts.push_back(impact_summary);
		}
		const Atom cost_summary = _describe_resource_delta(state, cost);
		if (cost_summary != key::empty) {
			site_summary_parts.push_back(gd::format(state, key::cost_s_2, {str(cost_summary)}));
		}
		const int64_t movement_cost = gd::int_field(state, response_state, key::movement_cost, 0);
		site_summary_parts.push_back(gd::format(state, key::move_d_2, {int_value(movement_cost)}));
		const int64_t watch_days = gd::int_field(state, response_state, key::watch_days, 0);
		site_summary_parts.push_back(gd::format(state, key::d_day_s, {int_value(watch_days), str(watch_days == 1 ? key::empty : key::s)}));
		const bool disabled = !_can_afford(state, session, cost) || movement_left < movement_cost;
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::site_response_s, {str(text_or(state, node_dict, key::placement_id, key::empty))})));
		state.set(action, str(key::label), str(gd::format(state, key::s_colon_s_text, {str(text_or(state, response_state, key::action_label, key::secure_route)), str(site_name)})));
		state.set(action, str(key::summary), str(join_atoms(state, key::space_bar_space, site_summary_parts)));
		state.set(action, str(key::disabled), bool_value(disabled));
		state.set(action, str(key::resource_cost), cost);
		state.set(action, str(key::movement_cost), int_value(movement_cost));
		state.set(action, str(key::remaining_movement_after_order), int_value(compat::engine_max<int64_t>(0, gd::sub(movement_left, movement_cost))));
		state.set(action, str(key::market_coverable), bool_value(market_affordable && !direct_affordable));
		state.set(action, str(key::market_summary), str(market_summary));
		state.set(action, str(key::delivery_summary), str(delivery_summary));
		state.set(action, str(key::resource_blocked), bool_value(!direct_affordable));
		state.set(action, str(key::movement_blocked), bool_value(movement_left < movement_cost));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef _execute_town_response_action(State &state, DictRef session, DictRef town, Atom action_id) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_strategic);
	}
	if (action_id == key::stabilize_recovery) {
		return _stabilize_town_recovery(state, session, town);
	}
	if (gd::begins_with(state, action_id, key::site_response_2)) {
		const Atom placement_id = gd::trim_prefix(state, action_id, key::site_response_2);
		const DictRef node_result = _find_resource_node_by_placement(state, session, placement_id);
		if (gd::int_field(state, node_result, key::index, -1) < 0) {
			return refusal(state, key::that_route_order_no_longer_has);
		}
		const DictRef node = gd::as_dict(field_or_new_dict(state, node_result, key::node));
		const DictRef linked_town_result = _resource_node_linked_town(state, session, node, key::player);
		if (linked_town_placement(state, linked_town_result) != text_or(state, town, key::placement_id, key::empty)) {
			return refusal(state, gd::format(state, key::that_site_is_no_longer_linked, {str(_town_name(state, town))}));
		}
		return _issue_resource_site_response(state, session, placement_id, key::town);
	}
	return refusal(state, key::that_response_order_is_not_recognized);
}

DictRef _town_recovery_stabilize_profile(State &state, DictRef town) {
	const Atom role = _town_strategic_role(state, town);
	const DictRef profile = state.new_dict();
	const DictRef resource_cost = state.new_dict();
	state.set(profile, str(key::label), str(key::stabilize_recovery_2));
	if (role == key::capital) {
		state.set(profile, str(key::summary), str(key::pull_charter_labor_reserve_wagons_and));
		state.set(profile, str(key::movement_cost), int_value(4));
		state.set(resource_cost, str(key::gold), int_value(220));
		state.set(resource_cost, str(key::wood), int_value(1));
		state.set(resource_cost, str(key::ore), int_value(1));
		state.set(profile, str(key::resource_cost), dict_value(resource_cost));
		state.set(profile, str(key::relief_amount), int_value(2));
	} else if (role == key::stronghold) {
		state.set(profile, str(key::summary), str(key::cycle_garrison_crews_and_line_labor));
		state.set(profile, str(key::movement_cost), int_value(3));
		state.set(resource_cost, str(key::gold), int_value(170));
		state.set(resource_cost, str(key::wood), int_value(1));
		state.set(profile, str(key::resource_cost), dict_value(resource_cost));
		state.set(profile, str(key::relief_amount), int_value(1));
	} else {
		state.set(profile, str(key::summary), str(key::push_local_labor_and_reserve_stores));
		state.set(profile, str(key::movement_cost), int_value(2));
		state.set(resource_cost, str(key::gold), int_value(140));
		state.set(profile, str(key::resource_cost), dict_value(resource_cost));
		state.set(profile, str(key::relief_amount), int_value(1));
	}
	return profile;
}

DictRef _stabilize_town_recovery(State &state, DictRef session, DictRef town) {
	const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
	if (!gd::to_bool(state.get(recovery, str(key::active), bool_value(false)))) {
		return refusal(state, gd::format(state, key::s_has_no_active_recovery_pressure, {str(_town_name(state, town))}));
	}
	const DictRef profile = _town_recovery_stabilize_profile(state, town);
	const Value cost = field_or_new_dict(state, profile, key::resource_cost);
	if (!_can_afford(state, session, cost)) {
		return refusal(state, gd::format(state, key::insufficient_resources_to_stabilize_s, {str(_town_name(state, town))}));
	}
	const DictRef movement_result = hero_command_rules::spend_active_hero_movement(state, session, gd::int_field(state, profile, key::movement_cost, 0), key::recovery_stabilization);
	if (!gd::to_bool(state.get(movement_result, str(key::ok), bool_value(false)))) {
		return movement_result;
	}
	if (gd::is_dict(cost) && !gd::is_empty(state, cost.ref)) {
		_spend_resources(state, session, cost);
	}
	const Atom placement_id = text_or(state, town, key::placement_id, key::empty);
	const int64_t relief_amount = gd::int_field(state, profile, key::relief_amount, 1);
	const Atom relief_source = _town_name(state, town);
	const Atom relief_message = relieve_town_recovery_pressure(state, session, placement_id, relief_amount, relief_source);
	std::vector<Atom> messages;
	messages.push_back(gd::format(state, key::ordered_recovery_stabilization_in_s, {str(_town_name(state, town))}));
	const Atom cost_summary = _describe_resource_delta(state, cost);
	if (cost_summary != key::empty) {
		messages.push_back(gd::format(state, key::spent_s, {str(cost_summary)}));
	}
	if (relief_message != key::empty) {
		messages.push_back(relief_message);
	}
	return _finalize_action_result(state, session, true, join_atoms(state, key::space, messages), true, false, state.new_dict());
}

Atom _summarize_market_actions(State &state, const Value &actions, int64_t max_steps) {
	if (!gd::is_array(actions) || state.array_size(actions.ref) == 0) {
		return key::empty;
	}
	const int64_t size = state.array_size(actions.ref);
	std::vector<Atom> shown;
	const int64_t shown_count = compat::engine_min<int64_t>(max_steps, size);
	for (int64_t index = 0; index < shown_count; ++index) {
		shown.push_back(gd::stringify(state, state.at(actions.ref, index)));
	}
	std::string summary = state.text(join_atoms(state, key::semicolon_space, shown));
	if (size > max_steps) {
		const int64_t more = gd::sub(size, max_steps);
		summary += state.text(gd::format(state, key::d_more_step_s, {int_value(more), str(more == 1 ? key::empty : key::s)}));
	}
	return state.intern(summary);
}

} // namespace overworld_rules

namespace scenario_rules {

ArrayRef objective_artifact_ids(State &state, DictRef session) {
	// Artifacts this scenario's objectives name, including every piece of a
	// required set. Town commerce must not sell or buy them back.
	const ArrayRef ids = state.new_array();
	const Value objectives = objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return ids;
	}
	constexpr Atom kBuckets[] = {key::victory, key::defeat};
	for (const Atom bucket_name : kBuckets) {
		// var bucket = objectives.get(bucket_name, []): read only.
		Value bucket;
		if (!state.lookup(objectives.ref, str(bucket_name), bucket) || !gd::is_array(bucket)) {
			continue;
		}
		for (const Value &objective : gd::items(state, bucket)) {
			if (!gd::is_dict(objective)) {
				continue;
			}
			const DictRef dependency = _scenario_objective_dependency(state, objective.ref, state.new_dict(), state.new_dict());
			for (const Value &artifact_id : gd::field_items(state, dependency, str(key::artifact_ids))) {
				const Atom id = gd::stringify(state, artifact_id);
				if (!gd::array_has(state, ids, str(id))) {
					state.append(ids, str(id));
				}
			}
		}
	}
	return ids;
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
